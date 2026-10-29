-- tests/mutation_check.lua
-- Mutation check. Plants one known fault at a time into a COPY of the project and confirms that a suite catches it.
-- A fault that no suite catches is reported as SURVIVED and makes this script fail. A fault whose target text is
-- not found is reported as INVALID, which also fails, because then the check proved nothing.
-- Run from the project root:   texlua tests/mutation_check.lua
-- The project itself is never changed: every mutant is applied to a fresh copy in a temporary folder.

local WORK = "/tmp/pc_builder_mutant"
local SHARED = "src/ReplicatedStorage/Shared/"
local SERVER = "src/ServerScriptService/"
local CLIENT = "src/StarterPlayer/StarterPlayerScripts/"

local MUTANTS = {
	{ name = "free layout ignores the table top (OFF_TABLE disabled)", file = SHARED .. "PlacementRules.lua",
		find = "if tableBox ~= nil and not PlacementRules.insideFootprint(",
		replace = "if false and tableBox ~= nil and not PlacementRules.insideFootprint(" },
	{ name = "table edge: a part exactly on the edge is refused", file = SHARED .. "PlacementRules.lua",
		find = "center.x + hx <= tableCenter.x + tx", replace = "center.x + hx < tableCenter.x + tx" },
	{ name = "snap considers only the nearest socket", file = SHARED .. "PlacementRules.lua",
		find = "for _, entry in ipairs(inRange) do", replace = "for _, entry in ipairs({ inRange[1] }) do" },
	{ name = "install ignores reach from the player", file = SHARED .. "Decisions.lua",
		find = "if ctx.player == nil or not PlacementRules.inReach(ctx.player, ctx.socket.pos, ctx.maxReach) then",
		replace = "if ctx.player == nil then" },
	{ name = "install ignores the bench bounds", file = SHARED .. "Decisions.lua",
		find = "if not PlacementRules.inBounds(ctx.proposed.pos, ctx.benchOrigin, ctx.benchHalf) then",
		replace = "if false then" },
	{ name = "free placement ignores the table box", file = SHARED .. "Decisions.lua",
		find = "L.caseBox, L.surfaceY, L.tableBox)", replace = "L.caseBox, L.surfaceY, nil)" },
	{ name = "pose check ignores the look vector", file = SHARED .. "RequestGuard.lua",
		find = "and RequestGuard.isFinitePoint(pose.look)", replace = "and true" },
	{ name = "argument check runs before the rate limit (admit)", file = SHARED .. "RequestGuard.lua",
		find = "function RequestGuard.admit(limiter, action, now, valid)",
		replace = 'function RequestGuard.admit(limiter, action, now, valid)\n\tif not valid then return "REQUEST_INVALID" end' },
	{ name = "English OFF_TABLE message missing", file = SHARED .. "Locale.lua",
		find = 'OFF_TABLE = { msg = "That spot is past', replace = 'OFF_TABLE_MISSING = { msg = "That spot is past' },
	{ name = "socket rule disabled: AMD CPU fits any board", file = SHARED .. "AssemblyRules.lua",
		find = 'if comp.kind == "CPU" and comp.socket ~= board.cpuSocket then',
		replace = 'if comp.kind == "CPU" and false then' },
	{ name = "server: PickUp checks arguments before the rate limit", file = SERVER .. "AssemblyServer.server.lua",
		find = 'local admitCode = RequestGuard.admit(s.limiter, "PickUp", os.clock(), RequestGuard.isId(instanceId))',
		replace = 'if not RequestGuard.isId(instanceId) then return notifyInvalid(player, "pickup", instanceId) end\n\tlocal admitCode = RequestGuard.admit(s.limiter, "PickUp", os.clock(), true)' },
	{ name = "server: ProposePlacement has no rate limit", file = SERVER .. "AssemblyServer.server.lua",
		find = 'local admitCode = RequestGuard.admit(s.limiter, "ProposePlacement", os.clock(), validArgs)',
		replace = 'local admitCode = (not validArgs) and "REQUEST_INVALID" or nil' },
	{ name = "server: installs bypass Decisions.install", file = SERVER .. "AssemblyServer.server.lua",
		find = "local okInstall, codeInstall, paramsInstall = Decisions.install({",
		replace = 'local okInstall, codeInstall, paramsInstall = (function(t) return false, "NO_SOCKET", {} end)({' },
	{ name = "client: snap picks the nearest socket alone", file = CLIENT .. "InteractionController.client.lua",
		find = "PlacementRules.chooseSnap(candidatesFor(h.componentId)",
		replace = "PlacementRules.nearest(candidatesFor(h.componentId)" },
	{ name = "client: a snap is proposed without its socket", file = CLIENT .. "InteractionController.client.lua",
		find = "if snapCF == nil then", replace = "if false then" },
}

-- texlua's os.execute returns the exit code itself; plain Lua 5.3 returns true|nil, "exit", code. Accept both.
local function exitCodeOf(first, _, third)
	if type(first) == "number" then return first end
	if type(third) == "number" then return third end
	return first and 0 or 1
end

-- Fresh copy of the project's src and tests folders. Returns true on success.
local function copyProject()
	local code = exitCodeOf(os.execute("rm -rf " .. WORK .. " && mkdir -p " .. WORK .. " && cp -r src tests " .. WORK .. "/"))
	return code == 0
end

-- Runs one suite inside the copy and returns its exit code (0 = every check passed).
local function suite(script)
	local code = exitCodeOf(os.execute("cd " .. WORK .. " && texlua " .. script .. " > " .. WORK .. "_out.txt 2>&1"))
	return code
end

-- Replaces the first occurrence of the target text in the copy. Returns false when the text is not there.
local function applyMutant(m)
	local path = WORK .. "/" .. m.file
	local f = io.open(path, "rb")
	if f == nil then return false end
	local text = f:read("*a")
	f:close()
	local i, j = string.find(text, m.find, 1, true)
	if i == nil then return false end
	text = string.sub(text, 1, i - 1) .. m.replace .. string.sub(text, j + 1)
	f = assert(io.open(path, "wb"))
	f:write(text)
	f:close()
	return true
end

-- The unmutated copy must pass both suites, or the mutation results would mean nothing.
if not copyProject() then
	print("could not copy the project")
	os.exit(1)
end
if suite("tests/run_pure_tests.lua") ~= 0 or suite("tests/static_checks.lua") ~= 0 then
	print("BASELINE FAILED: the unmutated copy does not pass the suites, so mutation results would mean nothing.")
	os.exit(1)
end
print("baseline: the unmutated copy passes the pure and static suites")

local killed, survived, invalid = 0, {}, {}
for _, m in ipairs(MUTANTS) do
	copyProject()
	if not applyMutant(m) then
		invalid[#invalid + 1] = m.name
		print(string.format("INVALID   %s  (target text not found)", m.name))
	elseif suite("tests/run_pure_tests.lua") ~= 0 then
		killed = killed + 1
		print(string.format("KILLED    %s  [pure tests]", m.name))
	elseif suite("tests/static_checks.lua") ~= 0 then
		killed = killed + 1
		print(string.format("KILLED    %s  [static gates]", m.name))
	else
		survived[#survived + 1] = m.name
		print(string.format("SURVIVED  %s", m.name))
	end
end
os.execute("rm -rf " .. WORK .. " " .. WORK .. "_out.txt")
print(string.format("\n%d of %d mutants killed, %d survived, %d invalid", killed, #MUTANTS, #survived, #invalid))
os.exit((killed == #MUTANTS) and 0 or 1)
