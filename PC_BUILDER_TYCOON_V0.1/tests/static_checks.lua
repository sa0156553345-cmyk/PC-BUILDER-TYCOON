-- tests/static_checks.lua
-- Static quality gates. No Roblox and no network are needed.
-- Run from the project root:   texlua tests/static_checks.lua
-- Checks: shared modules are pure and return a table, every member used across modules is defined,
-- remote names agree between config, server and client, EN and AR define the same messages and interface keys,
-- every reply code the code can send is translated, require paths resolve, Roblox top-level locals are declared
-- before use, and earlier designs are not left behind. Exit code 0 means every check passed.

local passes, failures = 0, 0

local function report(ok, name, detail)
	if ok then
		passes = passes + 1
		print("PASS  " .. name)
	else
		failures = failures + 1
		print("FAIL  " .. name .. (detail and ("  [" .. detail .. "]") or ""))
	end
end

local function readFile(path)
	local f = io.open(path, "r")
	if f == nil then
		return nil
	end
	local s = f:read("*a")
	f:close()
	return s
end

local function splitLines(s)
	local out = {}
	for line in (s .. "\n"):gmatch("(.-)\n") do
		table.insert(out, line)
	end
	return out
end

local function listSources()
	local out = {}
	local p = io.popen('find src -name "*.lua" | sort')
	for line in p:lines() do
		table.insert(out, line)
	end
	p:close()
	return out
end

local SHARED = "src/ReplicatedStorage/Shared/"
local SERVER = "src/ServerScriptService/"
local CLIENT = "src/StarterPlayer/StarterPlayerScripts/"
local CLIENT_FILE = CLIENT .. "InteractionController.client.lua"
local SERVER_FILE = SERVER .. "AssemblyServer.server.lua"

-- rawSources keeps comments (used for the leftover check). sources has comments removed, so that
-- file names mentioned in headers (for example "Config.lua") are not mistaken for code.
local rawSources = {}
for _, path in ipairs(listSources()) do
	rawSources[path] = readFile(path) or ""
end
local sources = {}
for path, text in pairs(rawSources) do
	local out = {}
	for _, ln in ipairs(splitLines(text)) do
		table.insert(out, (string.gsub(ln, "%-%-.*$", "")))
	end
	sources[path] = table.concat(out, "\n")
end

local PURE = { "Config", "Catalog", "AssemblyRules", "PlacementRules", "RateLimit", "RemoteLayout",
	"DragSequence", "Locale", "PointerTracker", "RequestGuard", "SessionHold", "Ledger", "WorkshopLayout", "Decisions" }

print("== 1. Shared modules are pure and return a table ==")
local ROBLOX_WORDS = { "game:", "game%.", "Instance%.new", "Vector3%.", "Vector2%.", "CFrame%.", "Color3%.",
	"UDim2%.", "Enum%.", "[Ww]orkspace", "typeof%(", "script%.", "Players", "RunService", "ReplicatedStorage", "HttpService" }
for _, name in ipairs(PURE) do
	local text = sources[SHARED .. name .. ".lua"]
	report(text ~= nil, "module file exists: " .. name)
	if text ~= nil then
		-- Shared modules may load their siblings with require(script.Parent:WaitForChild("Name")). That is the only use of
		-- script. allowed here, so those lines are removed before the Roblox-word scan. Everything else is still scanned.
		local scan = string.gsub(text, "[^\n]*require%(script%.Parent:WaitForChild%([^\n]*", "")
		local hit = nil
		for _, pat in ipairs(ROBLOX_WORDS) do
			if string.find(scan, pat) then
				hit = pat
				break
			end
		end
		report(hit == nil, "pure, no Roblox API: " .. name, hit)
		report(string.find(text, "\nreturn [%w_]+%s*$") ~= nil, "returns its module table: " .. name)
	end
end

print("== 2. Members used across modules are defined ==")
local MODULES = { "Config", "Catalog", "AssemblyRules", "PlacementRules", "RateLimit", "RemoteLayout",
	"DragSequence", "Locale", "PointerTracker", "RequestGuard", "SessionHold", "Ledger", "WorkshopLayout", "WorkshopBuilder", "Decisions" }
local DEFINED_AS = { WorkshopLayout = "L" }  -- that module declares its members on a local named L
local function definedMembers(name)
	local path = SHARED .. name .. ".lua"
	if name == "WorkshopBuilder" then
		path = SERVER .. "WorkshopBuilder.lua"
	end
	local text = sources[path] or ""
	local alias = DEFINED_AS[name] or name
	local set = {}
	for m in string.gmatch(text, "function " .. alias .. "%.([%w_]+)") do
		set[m] = true
	end
	for m in string.gmatch(text, "%f[%w_]" .. alias .. "%.([%w_]+)%s*=[^=]") do
		set[m] = true
	end
	return set
end
for _, name in ipairs(MODULES) do
	local defined = definedMembers(name)
	local missing = {}
	local seen = {}
	for path, text in pairs(sources) do
		for m in string.gmatch(text, "%f[%w_]" .. name .. "%.([%w_]+)") do
			if not defined[m] and not seen[name .. "." .. m] then
				seen[name .. "." .. m] = true
				table.insert(missing, name .. "." .. m .. " in " .. path:match("[^/]+$"))
			end
		end
	end
	table.sort(missing)
	report(#missing == 0, "every member used from " .. name .. " is defined", table.concat(missing, ", "))
end

print("== 3. Remote names agree between config, server and client ==")
local configBlock = string.match(sources[SHARED .. "Config.lua"], "Config%.RemoteNames%s*=%s*(%b{})") or ""
local remoteNames = {}
for n in string.gmatch(configBlock, '"([%w_]+)"') do
	remoteNames[n] = true
end
local serverRemotes, clientRemotes = {}, {}
for m in string.gmatch(sources[SERVER_FILE], "remoteFolder%.([%w_]+)") do
	serverRemotes[m] = true
end
for m in string.gmatch(sources[CLIENT_FILE], "Remote%.([%w_]+)") do
	clientRemotes[m] = true
end
local unknown = {}
for n in pairs(serverRemotes) do
	if not remoteNames[n] then table.insert(unknown, "server:" .. n) end
end
for n in pairs(clientRemotes) do
	if not remoteNames[n] then table.insert(unknown, "client:" .. n) end
end
table.sort(unknown)
report(#unknown == 0, "every remote used by server or client is configured", table.concat(unknown, ", "))
local onlyOneSide = {}
for n in pairs(remoteNames) do
	if not serverRemotes[n] or not clientRemotes[n] then table.insert(onlyOneSide, n) end
end
table.sort(onlyOneSide)
report(#onlyOneSide == 0, "every configured remote is used by both server and client", table.concat(onlyOneSide, ", "))

print("== 4. Translations: EN and AR match, and every code the source can send is translated ==")
local function parseLocale(text)
	local codes = { en = {}, ar = {} }
	local ui = { en = {}, ar = {} }
	local section, lang = nil, nil
	for _, ln in ipairs(splitLines(text)) do
		if string.find(ln, "^local CODES = {") then
			section = "codes"
		elseif string.find(ln, "^local UI = {") then
			section = "ui"
		elseif string.find(ln, "^local [%u_]+ = {") then
			section = "other"
		end
		local l = string.match(ln, "^%s*(en) = {") or string.match(ln, "^%s*(ar) = {")
		if l then
			lang = l
		end
		if section == "codes" and lang then
			local code = string.match(ln, "^%s*([A-Z][A-Z0-9_]+) = {")
			if code then
				codes[lang][code] = true
			end
		elseif section == "ui" and lang then
			local key = string.match(ln, '^%s*%["(ui%.[%w_]+)"%]%s*=')
			if key then
				ui[lang][key] = true
			end
		end
	end
	return codes, ui
end
local function sameSet(a, b)
	for k in pairs(a) do
		if not b[k] then return false, k end
	end
	for k in pairs(b) do
		if not a[k] then return false, k end
	end
	return true, nil
end
local codes, ui = parseLocale(sources[SHARED .. "Locale.lua"])
local sameCodes, diffCode = sameSet(codes.en, codes.ar)
report(sameCodes, "message codes: EN and AR define the same set", diffCode)
local sameUi, diffUi = sameSet(ui.en, ui.ar)
report(sameUi, "interface keys: EN and AR define the same set", diffUi)

local CODE_EXCLUDE = { DUPLICATE_FOLDER = true, NAME_TAKEN_BY_NON_FOLDER = true, DUPLICATE_REMOTE = true,
	WRONG_REMOTE_CLASS = true, MB24 = true, CPU8 = true }  -- the first four are developer warnings, English by design
local emitted, emittedFrom = {}, {}
for _, path in ipairs({ SERVER_FILE, CLIENT_FILE, SERVER .. "WorkshopBuilder.lua", SHARED .. "AssemblyRules.lua", SHARED .. "PlacementRules.lua" }) do
	for token in string.gmatch(sources[path], '"([A-Z][A-Z0-9_]+)"') do
		if #token >= 4 and not CODE_EXCLUDE[token] and not string.find(token, "^MB_") and not string.find(token, "^CASE_") then
			emitted[token] = true
			emittedFrom[token] = path:match("[^/]+$")
		end
	end
end
local untranslated = {}
for token in pairs(emitted) do
	if not codes.en[token] or not codes.ar[token] then
		table.insert(untranslated, token .. " (" .. emittedFrom[token] .. ")")
	end
end
table.sort(untranslated)
report(#untranslated == 0, "every reply or rule code in the source is translated in EN and AR", table.concat(untranslated, ", "))

local uiUsed = {}
for _, path in ipairs({ SERVER_FILE, CLIENT_FILE }) do
	for key in string.gmatch(sources[path], '"(ui%.[%w_]+)"') do
		uiUsed[key] = true
	end
end
local uiMissing = {}
for key in pairs(uiUsed) do
	if not ui.en[key] or not ui.ar[key] then table.insert(uiMissing, key) end
end
table.sort(uiMissing)
report(#uiMissing == 0, "every interface key the scripts use is translated in EN and AR", table.concat(uiMissing, ", "))

print("== 5. Require paths resolve to real files ==")
local seenRequire = {}
for path, text in pairs(sources) do
	for name in string.gmatch(text, 'require%(Shared:WaitForChild%("([%w_]+)"%)%)') do
		if not seenRequire[name] then
			seenRequire[name] = true
			report(sources[SHARED .. name .. ".lua"] ~= nil, "shared module required and present: " .. name)
		end
	end
	for name in string.gmatch(text, 'require%(script%.Parent:WaitForChild%("([%w_]+)"%)%)') do
		local folder = (string.find(path, SHARED, 1, true) == 1) and SHARED or SERVER
		if not seenRequire[folder .. name] then
			seenRequire[folder .. name] = true
			report(sources[folder .. name .. ".lua"] ~= nil, (folder == SHARED and "sibling shared module" or "server module") .. " required and present: " .. name)
		end
	end
end

print("== 6. Declaration order in the Roblox scripts: no top-level local is used before it is declared ==")
for path, text in pairs(sources) do
	if string.find(path, SERVER, 1, true) == 1 or string.find(path, CLIENT, 1, true) == 1 then
		local lines = splitLines(text)
		local top = {}
		for i, ln in ipairs(lines) do
			if not string.find(ln, "^%s") and not string.find(ln, "^%-%-") then
				local name = string.match(ln, "^local function ([%w_]+)") or string.match(ln, "^local ([%w_]+)%s*=")
				if name and top[name] == nil then
					top[name] = i
				end
			end
		end
		local bad = {}
		for name, decl in pairs(top) do
			for i = 1, decl - 1 do
				local code = string.gsub(lines[i], "%-%-.*$", "")
				if string.find(code, "%f[%w_]" .. name .. "%f[^%w_]") then
					table.insert(bad, name .. " used at line " .. i .. ", declared at " .. decl)
					break
				end
			end
		end
		table.sort(bad)
		report(#bad == 0, "declaration order: " .. path:match("[^/]+$") .. " (" .. (function()
			local n = 0
			for _ in pairs(top) do n = n + 1 end
			return n
		end)() .. " top-level locals)", table.concat(bad, "; "))
	end
end

print("== 7. Earlier designs and external services are not left behind ==")
local FORBIDDEN = { "HoldUpdate", "MaxHoldStepStuds", "ALREADY_HOLDING", "setGhostColor", "cancelHold",
	"sendProposal", "finishDrop", "PlacementRules.point(Config", "BenchHalfExtents)", "HttpService", "https://", "http://" }
for _, word in ipairs(FORBIDDEN) do
	local hitPath = nil
	for path, text in pairs(rawSources) do
		if string.find(text, word, 1, true) then
			hitPath = path
			break
		end
	end
	report(hitPath == nil, "absent from the source: " .. word, hitPath)
end

print("== 8. Server handlers spend the rate limit before any argument check ==")
local serverText = sources[SERVER_FILE]
for _, h in ipairs({ { "onPickUp", "PickUp" }, { "onProposePlacement", "ProposePlacement" },
	{ "onRequestUninstall", "RequestUninstall" }, { "onTightenScrew", "TightenScrew" } }) do
	local startAt = string.find(serverText, "local function " .. h[1] .. "(", 1, true)
	local admitAt = string.find(serverText, 'RequestGuard.admit(s.limiter, "' .. h[2] .. '"', 1, true)
	local ordered = startAt ~= nil and admitAt ~= nil and admitAt > startAt
	report(ordered, "handler " .. h[1] .. " calls RequestGuard.admit", nil)
	if ordered then
		local before = string.sub(serverText, startAt, admitAt - 1)
		report(string.find(before, "notifyInvalid(", 1, true) == nil, "no reply before the rate limit in " .. h[1], nil)
		report(string.find(before, "limiter:allow(", 1, true) == nil, "no direct limiter call before admit in " .. h[1], nil)
	end
end

print("== 9. The client preview and the server decide with the same shared functions ==")
local clientText = sources[CLIENT_FILE]
report(string.find(clientText, "Decisions.install(", 1, true) ~= nil, "client preview decides installs with Decisions.install", nil)
report(string.find(clientText, "Decisions.free(", 1, true) ~= nil, "client preview decides free placement with Decisions.free", nil)
report(string.find(clientText, "PlacementRules.chooseSnap(", 1, true) ~= nil, "client preview picks the snap socket with chooseSnap", nil)
report(string.find(clientText, "PlacementRules.nearest(", 1, true) == nil, "client preview does not pick the nearest socket alone", nil)
report(string.find(clientText, "if snapCF == nil then", 1, true) ~= nil, "client never proposes a snap without its socket", nil)
report(string.find(serverText, "Decisions.install(", 1, true) ~= nil, "server installs are decided by Decisions.install", nil)
report(string.find(serverText, "Decisions.free(", 1, true) ~= nil, "server free placement is decided by Decisions.free", nil)
report(string.find(serverText, "PlacementRules.checkFreeLayout(", 1, true) == nil, "server does not call the layout rule directly", nil)

print(string.format("\n%d passed, %d failed", passes, failures))
os.exit(failures == 0 and 0 or 1)
