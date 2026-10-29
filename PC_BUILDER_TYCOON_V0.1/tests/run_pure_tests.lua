-- tests/run_pure_tests.lua
-- Runs the PURE modules with standard Lua 5.3 (texlua): Catalog, AssemblyRules, PlacementRules, RateLimit, Locale.
-- It does NOT run Roblox code: no server, no client, no workshop models, no remotes, no real input, no rendering.
-- Run from the project root:   texlua tests/run_pure_tests.lua
-- Exit code 0 = every test passed.

package.path = "./src/ReplicatedStorage/Shared/?.lua;" .. package.path
-- Shared modules written for Roblox load siblings with require(script.Parent:WaitForChild(name)). Outside Roblox,
-- WaitForChild returns the module name, which require accepts. Only this test runner defines the shim.
script = { Parent = { WaitForChild = function(_, name) return name end } }

local Catalog = require("Catalog")
local AssemblyRules = require("AssemblyRules")
local PlacementRules = require("PlacementRules")
local RateLimit = require("RateLimit")
local Locale = require("Locale")
local RemoteLayout = require("RemoteLayout")
local DragSequence = require("DragSequence")
local PointerTracker = require("PointerTracker")
local RequestGuard = require("RequestGuard")
local SessionHold = require("SessionHold")
local Ledger = require("Ledger")
local WorkshopLayout = require("WorkshopLayout")
local Config = require("Config")

local passed, failed = 0, 0
local seenCodes = {}  -- every diagnostic code produced during the run; checked against Locale at the end

local function check(name, condition, detail)
	if condition then
		passed = passed + 1
		print("PASS  " .. name)
	else
		failed = failed + 1
		print("FAIL  " .. name .. (detail and ("  [" .. detail .. "]") or ""))
	end
end

local function codeOf(diag)
	if diag == nil then return "nil" end
	seenCodes[diag.code] = true
	return diag.code
end

local function hasCode(list, code)
	for _, d in ipairs(list) do
		seenCodes[d.code] = true
		if d.code == code then return true end
	end
	return false
end

local function install(state, catalog, componentId, instanceId, slotId)
	local ok, diag = AssemblyRules.validateInstall(state, catalog, componentId, instanceId, slotId)
	if ok then
		AssemblyRules.applyInstall(state, componentId, instanceId, slotId)
	end
	return ok, diag
end

local function mustInstall(state, catalog, componentId, instanceId, slotId)
	local ok, diag = install(state, catalog, componentId, instanceId, slotId)
	if not ok then
		error("setup install failed: " .. componentId .. " -> " .. slotId .. " (" .. codeOf(diag) .. ")")
	end
end

local function tighten(state, catalog, instanceId, times)
	for _ = 1, times do
		local ok = AssemblyRules.validateTighten(state, catalog, instanceId)
		if not ok then error("setup tighten failed for " .. instanceId) end
		AssemblyRules.applyTighten(state, instanceId)
	end
end

-- The starter PC. opts can skip a step or swap in a different PSU or CPU.
local function buildStarter(catalog, opts)
	opts = opts or {}
	local s = AssemblyRules.newState(catalog.StarterPC.caseId)
	mustInstall(s, catalog, "psu_corsair_rm550", "i_psu", "CASE_PSU")
	mustInstall(s, catalog, "mb_asus_b760m", "i_mb", "CASE_MB")
	mustInstall(s, catalog, opts.cpu or "cpu_intel_i5_12400f", "i_cpu", "MB_CPU")
	mustInstall(s, catalog, "ram_corsair_lpx_8_ddr4", "i_ram", "MB_RAM1")
	mustInstall(s, catalog, "ssd_samsung_980_500", "i_ssd", "MB_M2")
	if not opts.skipCab24 then mustInstall(s, catalog, "cable_rm550_mb24", "i_cab24", "MB_PWR24") end
	if not opts.skipCab8 then mustInstall(s, catalog, "cable_rm550_cpu8", "i_cab8", "MB_CPU8") end
	if not opts.skipScrews then
		tighten(s, catalog, "i_mb", 6)
		tighten(s, catalog, "i_psu", 4)
	end
	return s
end

-- Copies the catalog and replaces some components or slots. Originals stay untouched.
local function variant(componentOverrides, slotOverrides)
	local v = { Components = {}, Slots = {}, PowerModel = Catalog.PowerModel, StarterPC = Catalog.StarterPC, Orders = Catalog.Orders }
	for k, val in pairs(Catalog.Components) do v.Components[k] = val end
	for k, val in pairs(Catalog.Slots) do v.Slots[k] = val end
	for k, val in pairs(componentOverrides or {}) do v.Components[k] = val end
	for k, val in pairs(slotOverrides or {}) do v.Slots[k] = val end
	return v
end

local C = Catalog

-- ---------- Catalog data ----------
do
	local problems = {}
	for slotId, slot in pairs(C.Slots) do
		for _, req in ipairs(slot.requires) do
			if C.Slots[req] == nil then table.insert(problems, slotId .. " requires unknown slot " .. req) end
		end
		if slot.ownerSlot ~= nil and C.Slots[slot.ownerSlot] == nil then
			table.insert(problems, slotId .. " has unknown ownerSlot " .. slot.ownerSlot)
		end
	end
	for id, comp in pairs(C.Components) do
		if comp.id ~= id then table.insert(problems, "component key/id mismatch: " .. id) end
		if comp.kind == "Motherboard" then
			for _, port in ipairs(comp.requiredPorts) do
				if C.Slots[port] == nil then table.insert(problems, comp.id .. " requires unknown port " .. port) end
			end
		end
	end
	for _, id in ipairs(C.StarterPC.kit) do
		if C.Components[id] == nil then table.insert(problems, "kit unknown id " .. id) end
	end
	for _, id in ipairs(C.StarterPC.extras) do
		if C.Components[id] == nil then table.insert(problems, "extras unknown id " .. id) end
	end
	if C.Orders[C.StarterPC.orderId] == nil then table.insert(problems, "orderId has no order") end
	check("catalog references are consistent", #problems == 0, table.concat(problems, "; "))
end

do
	local board = C.Components.mb_asus_b760m
	local cpu = C.Components.cpu_intel_i5_12400f
	local ram = C.Components.ram_corsair_lpx_8_ddr4
	local case = C.Components.case_corsair_4000d
	local psu = C.Components.psu_corsair_rm550
	check("starter board socket matches the starter CPU (LGA1700)", board.cpuSocket == cpu.socket)
	check("starter RAM type matches the starter board (DDR4)", ram.ramType == board.ramType)
	check("starter case supports the board's form factor (MATX)", (function()
		for _, f in ipairs(case.formFactors) do if f == board.formFactor then return true end end
		return false
	end)())
	check("starter PSU provides both cables the board requires", (function()
		for _, port in ipairs(board.requiredPorts) do
			local needed = C.Slots[port].cableType
			local found = false
			for _, c in ipairs(psu.cables) do if c == needed then found = true end end
			if not found then return false end
		end
		return true
	end)())
	check("distractor CPU uses a different socket (AM4)", C.Components.cpu_amd_ryzen5_5600.socket ~= board.cpuSocket)
	check("distractor RAM uses a different type (DDR5)", C.Components.ram_corsair_vengeance_8_ddr5.ramType ~= board.ramType)
end

-- ---------- Boot ----------
do
	local s = buildStarter(C)
	local boot = AssemblyRules.evaluateBoot(s, C)
	check("starter build boots with zero diagnostics", boot.ok and #boot.diagnostics == 0, #boot.diagnostics .. " diagnostics")
	check("starter watt requirement is 165W (65+40+5+5+50)", AssemblyRules.requiredWatts(s, C) == 165, tostring(AssemblyRules.requiredWatts(s, C)))
end

do
	local s = buildStarter(C, { skipScrews = true })
	local boot = AssemblyRules.evaluateBoot(s, C)
	check("loose screws block boot (SCREWS_INCOMPLETE)", (not boot.ok) and hasCode(boot.diagnostics, "SCREWS_INCOMPLETE"))
end

do
	local s = buildStarter(C, { skipCab24 = true })
	local boot = AssemblyRules.evaluateBoot(s, C)
	local found = false
	for _, d in ipairs(boot.diagnostics) do
		if d.code == "MISSING_CABLE" and d.params.slot == "MB_PWR24" then found = true end
	end
	seenCodes["MISSING_CABLE"] = true
	check("missing 24-pin cable blocks boot (MISSING_CABLE with slot MB_PWR24)", (not boot.ok) and found)
end

do
	local s = buildStarter(C, { skipCab8 = true })
	local boot = AssemblyRules.evaluateBoot(s, C)
	check("missing CPU cable blocks boot (MISSING_CABLE with slot MB_CPU8)", (not boot.ok) and hasCode(boot.diagnostics, "MISSING_CABLE"))
end

do
	-- FIXTURE, not a real product: a CPU drawing 600 W makes the 550 W PSU insufficient.
	local hot = variant({ cpu_intel_i5_12400f = { id = "cpu_intel_i5_12400f", name = "Fixture hot CPU", kind = "CPU", socket = "LGA1700", tdp = 600, screwsRequired = 0 } })
	local s = buildStarter(hot)
	local boot = AssemblyRules.evaluateBoot(s, hot)
	local ok2 = (not boot.ok) and hasCode(boot.diagnostics, "PSU_INSUFFICIENT")
	check("PSU too weak is reported with needed and available watts (fixture)", ok2)
end

do
	local s = buildStarter(C, { skipCab24 = true, skipCab8 = true, skipScrews = true })
	local boot = AssemblyRules.evaluateBoot(s, C)
	check("several faults are all reported together", (not boot.ok) and #boot.diagnostics >= 3, tostring(#boot.diagnostics))
end

do
	local s = AssemblyRules.newState(C.StarterPC.caseId)
	local boot = AssemblyRules.evaluateBoot(s, C)
	check("empty workshop reports NO_MOTHERBOARD and NO_PSU", (not boot.ok) and hasCode(boot.diagnostics, "NO_MOTHERBOARD") and hasCode(boot.diagnostics, "NO_PSU"))
end

-- ---------- Install compatibility (real distractors) ----------
do
	local s = AssemblyRules.newState(C.StarterPC.caseId)
	mustInstall(s, C, "psu_corsair_rm550", "i_psu", "CASE_PSU")
	mustInstall(s, C, "mb_asus_b760m", "i_mb", "CASE_MB")
	local ok, diag = install(s, C, "cpu_amd_ryzen5_5600", "i_cpu_am4", "MB_CPU")
	check("AMD AM4 CPU is rejected on the LGA1700 board (SOCKET_MISMATCH)", (not ok) and codeOf(diag) == "SOCKET_MISMATCH", codeOf(diag))
	check("SOCKET_MISMATCH carries the board's socket as a parameter", diag and diag.params.socket == "LGA1700")
end

do
	local s = AssemblyRules.newState(C.StarterPC.caseId)
	mustInstall(s, C, "psu_corsair_rm550", "i_psu", "CASE_PSU")
	mustInstall(s, C, "mb_asus_b760m", "i_mb", "CASE_MB")
	local ok, diag = install(s, C, "ram_corsair_vengeance_8_ddr5", "i_ramb", "MB_RAM1")
	check("DDR5 module is rejected on the DDR4 board (RAM_TYPE_MISMATCH)", (not ok) and codeOf(diag) == "RAM_TYPE_MISMATCH", codeOf(diag))
end

do
	local micro = variant({
		case_corsair_4000d = { id = "case_corsair_4000d", name = "Fixture ITX-only case", kind = "Case", formFactors = { "ITX" }, screwsRequired = 0 },
	})
	local s = AssemblyRules.newState("case_corsair_4000d")
	mustInstall(s, micro, "psu_corsair_rm550", "i_psu", "CASE_PSU")
	local ok, diag = install(s, micro, "mb_asus_b760m", "i_mb", "CASE_MB")
	check("MATX board does not fit an ITX-only case (FORMFACTOR_MISMATCH, fixture)", (not ok) and codeOf(diag) == "FORMFACTOR_MISMATCH", codeOf(diag))
end

do
	local s = AssemblyRules.newState(C.StarterPC.caseId)
	mustInstall(s, C, "psu_corsair_rm550", "i_psu", "CASE_PSU")
	local ok, diag = install(s, C, "cpu_intel_i5_12400f", "i_cpu", "MB_CPU")
	check("CPU before motherboard is rejected (PARENT_NOT_INSTALLED)", (not ok) and codeOf(diag) == "PARENT_NOT_INSTALLED", codeOf(diag))
end

do
	local s = AssemblyRules.newState(C.StarterPC.caseId)
	mustInstall(s, C, "psu_corsair_rm550", "i_psu", "CASE_PSU")
	mustInstall(s, C, "mb_asus_b760m", "i_mb", "CASE_MB")
	local ok, diag = install(s, C, "cable_rm550_cpu8", "i_cab8", "MB_PWR24")
	check("CPU cable in the 24-pin port is rejected (CABLE_WRONG_PORT)", (not ok) and codeOf(diag) == "CABLE_WRONG_PORT", codeOf(diag))
end

do
	local s = AssemblyRules.newState(C.StarterPC.caseId)
	mustInstall(s, C, "mb_asus_b760m", "i_mb", "CASE_MB")
	local ok, diag = install(s, C, "cable_rm550_mb24", "i_cab24", "MB_PWR24")
	check("cable with no PSU installed is rejected (PARENT_NOT_INSTALLED)", (not ok) and codeOf(diag) == "PARENT_NOT_INSTALLED", codeOf(diag))
end

do
	local noCpu8 = variant({
		psu_corsair_rm550 = { id = "psu_corsair_rm550", name = "Fixture PSU without CPU8", kind = "PSU", watts = 550, cables = { "MB24" }, screwsRequired = 4 },
	})
	local s = AssemblyRules.newState(C.StarterPC.caseId)
	mustInstall(s, noCpu8, "psu_corsair_rm550", "i_psu", "CASE_PSU")
	mustInstall(s, noCpu8, "mb_asus_b760m", "i_mb", "CASE_MB")
	local ok, diag = install(s, noCpu8, "cable_rm550_cpu8", "i_cab8", "MB_CPU8")
	check("PSU without a CPU8 cable cannot feed that port (PSU_CABLE_UNAVAILABLE, fixture)", (not ok) and codeOf(diag) == "PSU_CABLE_UNAVAILABLE", codeOf(diag))
end

do
	local s = buildStarter(C)
	local ok, diag = install(s, C, "cpu_intel_i5_12400f", "i_cpu_dup", "MB_CPU")
	check("second CPU in an occupied socket is rejected (SLOT_OCCUPIED)", (not ok) and codeOf(diag) == "SLOT_OCCUPIED", codeOf(diag))
end

do
	local s = AssemblyRules.newState(C.StarterPC.caseId)
	local ok, diag = install(s, C, "ssd_samsung_980_500", "i_ssd2", "CASE_PSU")
	check("storage placed in the PSU bay is rejected (WRONG_PART_FOR_SLOT)", (not ok) and codeOf(diag) == "WRONG_PART_FOR_SLOT", codeOf(diag))
end

do
	local s = buildStarter(C)
	local ok, diag = install(s, C, "cpu_intel_i5_12400f", "i_cpu", "MB_RAM2")
	check("already-installed instance is rejected (ALREADY_INSTALLED)", (not ok) and codeOf(diag) == "ALREADY_INSTALLED", codeOf(diag))
end

do
	local s = buildStarter(C)
	local ok, diag = install(s, C, "does_not_exist", "i_x", "MB_CPU")
	check("unknown component id is rejected (UNKNOWN_COMPONENT)", (not ok) and codeOf(diag) == "UNKNOWN_COMPONENT", codeOf(diag))
end

do
	local s = buildStarter(C)
	local ok, diag = install(s, C, "ram_corsair_lpx_8_ddr4", "i_x", "MB_NOPE")
	check("unknown slot id is rejected (UNKNOWN_SLOT)", (not ok) and codeOf(diag) == "UNKNOWN_SLOT", codeOf(diag))
end

-- ---------- Uninstall and screws ----------
do
	local s = buildStarter(C)
	local ok, diag = AssemblyRules.validateUninstall(s, C, "i_mb")
	check("motherboard cannot be removed while parts depend on it (HAS_DEPENDENTS)", (not ok) and codeOf(diag) == "HAS_DEPENDENTS", codeOf(diag))
	check("HAS_DEPENDENTS names the blocking part", diag and diag.params.other ~= nil)
end

do
	local s = buildStarter(C)
	local ok, diag = AssemblyRules.validateUninstall(s, C, "i_psu")
	check("PSU cannot be removed while its cables are connected (HAS_DEPENDENTS)", (not ok) and codeOf(diag) == "HAS_DEPENDENTS", codeOf(diag))
end

do
	local s = buildStarter(C)
	local blockedAt = nil
	for _, id in ipairs({ "i_cab24", "i_cab8", "i_ssd", "i_ram", "i_cpu" }) do
		if not AssemblyRules.validateUninstall(s, C, id) then
			blockedAt = id
			break
		end
		AssemblyRules.applyUninstall(s, id)
	end
	check("dependents can be removed one by one", blockedAt == nil, tostring(blockedAt))
	check("motherboard can be removed once its dependents are gone", AssemblyRules.validateUninstall(s, C, "i_mb") == true)
end

do
	local s = buildStarter(C)
	local ok, diag = AssemblyRules.validateTighten(s, C, "i_mb")
	check("tightening beyond required screws is rejected (NO_SCREWS_NEEDED)", (not ok) and codeOf(diag) == "NO_SCREWS_NEEDED", codeOf(diag))
end

do
	local s = AssemblyRules.newState(C.StarterPC.caseId)
	local ok, diag = AssemblyRules.validateTighten(s, C, "i_ghost")
	check("cannot tighten a part that is not installed (NOT_INSTALLED)", (not ok) and codeOf(diag) == "NOT_INSTALLED", codeOf(diag))
end

-- ---------- Order ----------
do
	local s = buildStarter(C)
	local ok, diags = AssemblyRules.evaluateOrder(s, C, C.Orders.office_01)
	check("starter build completes office_01", ok == true and #diags == 0)
end

do
	local s = buildStarter(C)
	local big = { id = "x", minRamGB = 16, minStorageGB = 250, payout = 400 }
	local ok, diags = AssemblyRules.evaluateOrder(s, C, big)
	check("order needing 16GB RAM fails with ORDER_RAM_TOO_LOW", (not ok) and hasCode(diags, "ORDER_RAM_TOO_LOW"))
end

do
	local s = buildStarter(C, { skipScrews = true })
	local ok, diags = AssemblyRules.evaluateOrder(s, C, C.Orders.office_01)
	check("order is not complete while the PC fails boot (SCREWS_INCOMPLETE)", (not ok) and hasCode(diags, "SCREWS_INCOMPLETE"))
end

-- ---------- PlacementRules (pure geometry) ----------
local function V(x, y, z) return { X = x, Y = y, Z = z } end
do
	local origin = { x = 0, y = 0, z = 0 }
	local half = { x = 20, y = 20, z = 20 }
	check("inBounds accepts a point inside the bench box", PlacementRules.inBounds({ x = 5, y = 1, z = -5 }, origin, half))
	check("inBounds rejects a point outside the box", not PlacementRules.inBounds({ x = 21, y = 0, z = 0 }, origin, half))
	check("inBounds rejects NaN", not PlacementRules.inBounds({ x = 0 / 0, y = 0, z = 0 }, origin, half))
	check("inReach accepts 10 studs away at 14 max", PlacementRules.inReach({ x = 0, y = 0, z = 0 }, { x = 10, y = 0, z = 0 }, 14))
	check("inReach rejects 20 studs away at 14 max", not PlacementRules.inReach({ x = 0, y = 0, z = 0 }, { x = 20, y = 0, z = 0 }, 14))
	check("inReach rejects NaN", not PlacementRules.inReach({ x = 0, y = 0, z = 0 }, { x = 0 / 0, y = 0, z = 0 }, 14))

	local cosLim = PlacementRules.cosLimit(15)
	local target = PlacementRules.poseFromVectors(V(0, 0, 0), V(0, 1, 0), V(0, 0, 1))
	local same = PlacementRules.poseFromVectors(V(0.5, 0, 0), V(0, 1, 0), V(0, 0, 1))
	local rot90 = PlacementRules.poseFromVectors(V(0, 0, 0), V(0, 1, 0), V(1, 0, 0))
	local rot10 = PlacementRules.poseFromVectors(V(0, 0, 0), V(0, 1, 0), V(math.sin(math.rad(10)), 0, math.cos(math.rad(10))))
	check("aligned pose passes", PlacementRules.aligned(same, target, cosLim))
	check("pose rotated 90 degrees fails alignment", not PlacementRules.aligned(rot90, target, cosLim))
	check("pose rotated 10 degrees passes at a 15 degree limit", PlacementRules.aligned(rot10, target, cosLim))

	local ok1, c1 = PlacementRules.checkInstallPose(PlacementRules.poseFromVectors(V(9, 0, 0), V(0, 1, 0), V(0, 0, 1)), target, { installReach = 3, cosLimit = cosLim })
	check("install pose 9 studs from socket is TOO_FAR", (not ok1) and c1 == "TOO_FAR", tostring(c1))
	local ok2, c2 = PlacementRules.checkInstallPose(rot90, target, { installReach = 3, cosLimit = cosLim })
	check("install pose at the socket but rotated is NOT_ALIGNED", (not ok2) and c2 == "NOT_ALIGNED", tostring(c2))
	local ok3 = PlacementRules.checkInstallPose(same, target, { installReach = 3, cosLimit = cosLim })
	check("install pose at the socket and aligned is accepted", ok3 == true)

	local playerPos = { x = 0, y = 0, z = 0 }
	local okF, cF = PlacementRules.checkFreePose(PlacementRules.poseFromVectors(V(30, 0, 0), V(0, 1, 0), V(0, 0, 1)), playerPos, origin, half, 14)
	check("free pose outside the bench is OUT_OF_BOUNDS", (not okF) and cF == "OUT_OF_BOUNDS", tostring(cF))
	local okG, cG = PlacementRules.checkFreePose(PlacementRules.poseFromVectors(V(18, 0, 0), V(0, 1, 0), V(0, 0, 1)), playerPos, origin, half, 14)
	check("free pose inside the box but out of reach is TOO_FAR", (not okG) and cG == "TOO_FAR", tostring(cG))
	local okH = PlacementRules.checkFreePose(PlacementRules.poseFromVectors(V(3, 0, 0), V(0, 1, 0), V(0, 0, 1)), playerPos, origin, half, 14)
	check("free pose inside the box and in reach is accepted", okH == true)

	local candidates = {
		{ slotId = "A", pose = { pos = { x = 1, y = 0, z = 0 } } },
		{ slotId = "B", pose = { pos = { x = 0.5, y = 0, z = 0 } } },
		{ slotId = "C", pose = { pos = { x = 9, y = 0, z = 0 } } },
	}
	local near = PlacementRules.nearest(candidates, { x = 0, y = 0, z = 0 }, 2.5)
	check("nearest picks the closest socket within radius", near ~= nil and near.slotId == "B")
	check("nearest returns nil when nothing is within radius", PlacementRules.nearest(candidates, { x = 50, y = 0, z = 0 }, 2.5) == nil)
end

-- ---------- RateLimit ----------
do
	local rl = RateLimit.new({ PickUp = 2 })
	local a = rl:allow("PickUp", 10.0)
	local b = rl:allow("PickUp", 10.2)
	local c = rl:allow("PickUp", 10.4)
	check("rate limit allows 2 requests per second, refuses the 3rd", a and b and (not c))
	check("rate limit resets after one second", rl:allow("PickUp", 11.1) == true)
	check("unknown action is always refused", rl:allow("Hack", 11.2) == false)
end

-- ---------- Locale (EN / AR) ----------
do
	local en, ar = Locale.codeList("en"), Locale.codeList("ar")
	local enSet, arSet = {}, {}
	for _, c in ipairs(en) do enSet[c] = true end
	for _, c in ipairs(ar) do arSet[c] = true end
	local missing = {}
	for c in pairs(enSet) do if not arSet[c] then table.insert(missing, "ar:" .. c) end end
	for c in pairs(arSet) do if not enSet[c] then table.insert(missing, "en:" .. c) end end
	check("EN and AR define exactly the same message codes", #missing == 0, table.concat(missing, ", "))

	local ue, ua = Locale.uiKeys("en"), Locale.uiKeys("ar")
	check("EN and AR define the same UI keys", #ue == #ua and #ue > 0)
end

do
	-- describe() never returns nil (it falls back to "[CODE]"), so membership is checked against the real code lists.
	local known = {}
	for _, c in ipairs(Locale.codeList("en")) do known[c .. "|en"] = true end
	for _, c in ipairs(Locale.codeList("ar")) do known[c .. "|ar"] = true end
	local lacking = {}
	for code in pairs(seenCodes) do
		if not known[code .. "|en"] or not known[code .. "|ar"] then
			table.insert(lacking, code)
		end
	end
	local probe = {}
	for code in pairs(seenCodes) do table.insert(probe, code) end
	table.sort(probe)
	check("every diagnostic code produced in tests exists in Locale (" .. #probe .. " codes)", #lacking == 0, table.concat(lacking, ", "))
end

do
	local msg, hint = Locale.describe("en", "SOCKET_MISMATCH", { part = "cpu_amd_ryzen5_5600", socket = "LGA1700" }, C)
	check("EN message uses the real product name", msg == "AMD Ryzen 5 5600 does not fit this motherboard socket.", msg)
	check("EN hint fills the socket parameter", hint == "This board uses the LGA1700 socket.", hint)
	local amsg = Locale.describe("ar", "SOCKET_MISMATCH", { part = "cpu_amd_ryzen5_5600", socket = "LGA1700" }, C)
	check("AR message contains the same product name and no placeholders", amsg:find("AMD Ryzen 5 5600", 1, true) ~= nil and not amsg:find("{", 1, true))
	local m2 = Locale.describe("ar", "ORDER_DONE", { order = "office_01", payout = 250, wallet = 250 }, C)
	check("AR order message fills the order name, payout and wallet", m2:find("حاسوب مكتب", 1, true) ~= nil and m2:find("250", 1, true) ~= nil)
end

do
	local m, h = Locale.describe("en", "NO_SUCH_CODE", {}, C)
	check("unknown code falls back safely without crashing", m == "[NO_SUCH_CODE]" and h == "")
	check("RTL flag is set only for Arabic", Locale.isRtl("ar") and not Locale.isRtl("en"))
	check("slot labels localize", Locale.slotLabel("ar", "MB_CPU") == "مقبس المعالج" and Locale.slotLabel("en", "MB_CPU") == "CPU socket")
end


-- ---------- RemoteLayout (deterministic remote folder setup) ----------
do
	local p = RemoteLayout.plan("Folder", { "A", "B" }, {})
	check("no existing folder: create the folder and every RemoteEvent", p.ok and p.action == "create_folder" and #p.create == 2 and p.create[1] == "A" and p.create[2] == "B")
end
do
	local top = { { name = "Folder", className = "Folder", children = { { name = "A", className = "RemoteEvent" }, { name = "B", className = "RemoteEvent" } } } }
	local p = RemoteLayout.plan("Folder", { "A", "B" }, top)
	check("a complete valid folder is reused and nothing is created", p.ok and p.action == "use_existing" and #p.create == 0)
end
do
	local top = { { name = "Folder", className = "Folder", children = { { name = "A", className = "RemoteEvent" } } } }
	local p = RemoteLayout.plan("Folder", { "A", "B" }, top)
	check("a partial folder is reused and only the missing RemoteEvent is created", p.ok and p.action == "use_existing" and #p.create == 1 and p.create[1] == "B")
end
do
	local top = { { name = "Folder", className = "Folder", children = {} }, { name = "Folder", className = "Folder", children = {} } }
	local p = RemoteLayout.plan("Folder", { "A" }, top)
	check("two folders with the same name stop the setup (DUPLICATE_FOLDER)", (not p.ok) and p.action == "stop" and p.issues[1].code == "DUPLICATE_FOLDER" and #p.create == 0)
end
do
	local top = { { name = "Folder", className = "Model", children = {} } }
	local p = RemoteLayout.plan("Folder", { "A" }, top)
	check("a non-folder with the folder name stops the setup (NAME_TAKEN_BY_NON_FOLDER)", (not p.ok) and p.issues[1].code == "NAME_TAKEN_BY_NON_FOLDER")
end
do
	local top = { { name = "Folder", className = "Folder", children = { { name = "A", className = "Folder" } } } }
	local p = RemoteLayout.plan("Folder", { "A" }, top)
	check("a Folder where a RemoteEvent is required stops the setup (WRONG_REMOTE_CLASS)", (not p.ok) and p.issues[1].code == "WRONG_REMOTE_CLASS" and p.issues[1].params.className == "Folder")
end
do
	local top = { { name = "Folder", className = "Folder", children = { { name = "A", className = "RemoteEvent" }, { name = "A", className = "RemoteEvent" } } } }
	local p = RemoteLayout.plan("Folder", { "A" }, top)
	check("duplicate RemoteEvent children stop the setup (DUPLICATE_REMOTE)", (not p.ok) and p.issues[1].code == "DUPLICATE_REMOTE" and p.issues[1].params.count == 2)
end
do
	local top = { { name = "Folder", className = "Folder", children = { { name = "A", className = "RemoteEvent" }, { name = "Notes", className = "StringValue" } } } }
	local p = RemoteLayout.plan("Folder", { "A" }, top)
	check("unrelated children are ignored", p.ok and p.action == "use_existing" and #p.create == 0)
end
do
	local top = { { name = "Other", className = "Folder", children = {} } }
	local p = RemoteLayout.plan("Folder", { "A" }, top)
	check("objects with other names are ignored", p.ok and p.action == "create_folder")
end
do
	local top = { { name = "Folder", className = "Folder", children = { { name = "A", className = "RemoteEvent" } } } }
	local p1 = RemoteLayout.plan("Folder", { "A", "B" }, top)
	local p2 = RemoteLayout.plan("Folder", { "A", "B" }, top)
	check("the same input always produces the same plan", p1.action == p2.action and p1.create[1] == p2.create[1] and #p1.create == #p2.create)
end

-- ---------- DragSequence (request ORDER for one drag) ----------
do
	local seq = DragSequence.new("p1", 8)
	local a1 = DragSequence.release(seq)
	local a2 = DragSequence.ack(seq, "p1", true)
	check("released before the acknowledgement: nothing is sent until the ack, then only a tap", #a1 == 0 and #a2 == 1 and a2[1].type == "tap")
end
do
	local seq = DragSequence.new("p1", 8)
	DragSequence.pointerMoved(seq, 3)
	DragSequence.ack(seq, "p1", true)
	local a = DragSequence.release(seq)
	check("movement below the threshold is a tap, never an install", #a == 1 and a[1].type == "tap")
end
do
	local seq = DragSequence.new("p1", 8)
	DragSequence.pointerMoved(seq, 30)
	DragSequence.ack(seq, "p1", true)
	local a = DragSequence.release(seq)
	check("a drag acknowledged before release asks the client to evaluate", #a == 1 and a[1].type == "evaluate")
	local p = DragSequence.resolve(seq, { kind = "snap", slotId = "MB_CPU" })
	check("a snap evaluation proposes that slot exactly once", #p == 1 and p[1].type == "propose" and p[1].slotId == "MB_CPU")
	check("a second evaluation for the same drag does nothing", #DragSequence.resolve(seq, { kind = "free" }) == 0)
end
do
	local seq = DragSequence.new("p1", 8)
	DragSequence.pointerMoved(seq, 30)
	DragSequence.release(seq)
	local a = DragSequence.ack(seq, "p1", true)
	check("a drag released before the ack is evaluated when the ack arrives", #a == 1 and a[1].type == "evaluate")
	local p = DragSequence.resolve(seq, { kind = "free" })
	check("a free evaluation proposes free placement (empty slot)", #p == 1 and p[1].type == "propose" and p[1].slotId == "")
end
do
	local seq = DragSequence.new("p1", 8)
	DragSequence.pointerMoved(seq, 30)
	DragSequence.release(seq)
	local a = DragSequence.ack(seq, "p1", false)
	check("a rejected pickup after release cancels locally", #a == 1 and a[1].type == "cancel")
end
do
	local seq = DragSequence.new("p1", 8)
	local a = DragSequence.ack(seq, "other", true)
	check("an acknowledgement for another part is ignored", #a == 0 and seq.phase == "picking")
end
do
	local seq = DragSequence.new("p1", 8)
	DragSequence.ack(seq, "p1", true)
	DragSequence.pointerMoved(seq, 30)
	DragSequence.release(seq)
	local r = DragSequence.resolve(seq, { kind = "invalid" })
	check("an invalid evaluation releases and never proposes", #r == 1 and r[1].type == "release")
end
do
	local seq = DragSequence.new("p1", 8)
	local t = DragSequence.timeout(seq)
	local late = DragSequence.ack(seq, "p1", true)
	check("a timeout releases, and a late acknowledgement is ignored", #t == 1 and t[1].type == "release" and #late == 0)
end
do
	local seq = DragSequence.new("p1", 8)
	DragSequence.pointerMoved(seq, 30)
	DragSequence.ack(seq, "p1", true)
	DragSequence.release(seq)
	DragSequence.pointerMoved(seq, 99)
	check("movement after release does not change the decision", seq.phase == "awaiting_eval" and seq.dragged)
end
do
	-- Property: for every ordering of move, acknowledgement and release, exactly one terminal action is produced,
	-- and no drop or tap is ever produced before the acknowledgement.
	local orders = {
		{ "move", "ack", "release" }, { "move", "release", "ack" }, { "ack", "move", "release" },
		{ "ack", "release", "move" }, { "release", "move", "ack" }, { "release", "ack", "move" },
	}
	local allOk, detail = true, ""
	for _, order in ipairs(orders) do
		local seq = DragSequence.new("p1", 8)
		local acked, terminals, early = false, 0, false
		local function collect(actions)
			for _, a in ipairs(actions) do
				if a.type == "tap" or a.type == "propose" or a.type == "release" or a.type == "cancel" then
					terminals = terminals + 1
				end
				if (a.type == "tap" or a.type == "propose") and not acked then
					early = true
				end
				if a.type == "evaluate" then
					collect(DragSequence.resolve(seq, { kind = "snap", slotId = "MB_CPU" }))
				end
			end
		end
		for _, e in ipairs(order) do
			if e == "move" then
				DragSequence.pointerMoved(seq, 30)
			elseif e == "ack" then
				acked = true
				collect(DragSequence.ack(seq, "p1", true))
			else
				collect(DragSequence.release(seq))
			end
		end
		if terminals ~= 1 or early then
			allOk = false
			detail = detail .. table.concat(order, ">") .. "(" .. terminals .. ") "
		end
	end
	check("every ordering of move, acknowledgement and release gives one terminal action, never early", allOk, detail)
end


-- ---------- PointerTracker: multi-touch and mouse arbitration ----------
do
	local t = PointerTracker.new()
	local fingerA, fingerB = {}, {}
	check("a touch starts tracking", PointerTracker.begin(t, fingerA, "touch") == true)
	check("a second finger cannot start a second drag", PointerTracker.begin(t, fingerB, "touch") == false)
	check("the starting finger moves the drag", PointerTracker.acceptsMove(t, fingerA, "touch"))
	check("another finger's movement is ignored (multi-touch regression)", not PointerTracker.acceptsMove(t, fingerB, "touch"))
	check("another finger lifting does not end the drag", not PointerTracker.acceptsEnd(t, fingerB, "touch"))
	check("the starting finger lifting ends the drag", PointerTracker.acceptsEnd(t, fingerA, "touch"))
	PointerTracker.finish(t)
	check("after finish, no movement is accepted", not PointerTracker.acceptsMove(t, fingerA, "touch"))
end
do
	local t = PointerTracker.new()
	PointerTracker.begin(t, {}, "touch")
	check("while a touch drives, mouse movement is ignored", not PointerTracker.acceptsMove(t, nil, "mouse"))
	check("a mouse cannot start while a touch is active", PointerTracker.begin(t, {}, "mouse") == false)
	local u = PointerTracker.new()
	PointerTracker.begin(u, nil, "touch")
	check("a touch without a handle never matches", not PointerTracker.acceptsMove(u, nil, "touch"))
end
do
	local t = PointerTracker.new()
	check("a mouse drag starts with the mouse button", PointerTracker.begin(t, {}, "mouse") == true)
	check("mouse movement moves a mouse drag", PointerTracker.acceptsMove(t, {}, "mouse"))
	check("a touch cannot move a mouse drag", not PointerTracker.acceptsMove(t, {}, "touch"))
	check("releasing the mouse button ends a mouse drag", PointerTracker.acceptsEnd(t, nil, "mouse"))
	check("an unknown pointer kind is refused", PointerTracker.begin(PointerTracker.new(), {}, "pen") == false)
end

-- ---------- RequestGuard: every client argument is validated ----------
do
	check("ids: a well-formed instance id is accepted", RequestGuard.isId("cpu_intel_i5_12400f#3"))
	check("ids: an empty id is refused", not RequestGuard.isId(""))
	check("ids: an id over 64 characters is refused", not RequestGuard.isId(string.rep("a", 65)))
	check("ids: spaces are refused", not RequestGuard.isId("a b"))
	check("ids: injection-style text is refused", not RequestGuard.isId("x;DROP"))
	check("ids: nil and numbers are refused", (not RequestGuard.isId(nil)) and (not RequestGuard.isId(5)))
	check("numbers: finite values pass", RequestGuard.isFiniteNumber(1.5) and RequestGuard.isFiniteNumber(-3))
	check("numbers: NaN is refused", not RequestGuard.isFiniteNumber(0 / 0))
	check("numbers: infinity is refused", not RequestGuard.isFiniteNumber(math.huge))
	check("numbers: a string is refused", not RequestGuard.isFiniteNumber("1"))
	check("points: an x,y,z table passes", RequestGuard.isFinitePoint({ x = 1, y = 2, z = 3 }))
	check("points: a Vector3-style X,Y,Z table passes", RequestGuard.isFinitePoint({ X = 1, Y = 2, Z = 3 }))
	check("points: a NaN component is refused", not RequestGuard.isFinitePoint({ x = 0 / 0, y = 0, z = 0 }))
	check("points: a missing component is refused", not RequestGuard.isFinitePoint({ x = 1 }))
	check("points: nil and plain numbers are refused", (not RequestGuard.isFinitePoint(nil)) and (not RequestGuard.isFinitePoint(5)))
	check("component ids: a catalog id passes", RequestGuard.isComponentId("cpu_intel_i5_12400f", C))
	check("component ids: an unknown id is refused", not RequestGuard.isComponentId("cpu_fake", C))
	check("slots: the empty string (free placement) passes", RequestGuard.isSlotOrFree("", C))
	check("slots: a real slot passes", RequestGuard.isSlotOrFree("MB_CPU", C))
	check("slots: an unknown slot is refused", not RequestGuard.isSlotOrFree("MB_NOPE", C))
end

-- ---------- SessionHold: server-side hold rules (regression for the stuck-hold bug) ----------
do
	local h = SessionHold.new()
	check("a new session holds nothing", SessionHold.heldId(h) == nil)
	SessionHold.pick(h, "A#1")
	local previous = SessionHold.pick(h, "B#2")
	check("a new pick replaces the earlier hold", previous == "A#1" and SessionHold.heldId(h) == "B#2")
	check("releasing a different part does nothing", SessionHold.release(h, "A#1") == false and SessionHold.heldId(h) == "B#2")
	check("releasing the held part clears it", SessionHold.release(h, "B#2") == true and SessionHold.heldId(h) == nil)
	check("a repeated release is harmless", SessionHold.release(h, "B#2") == false)
end
do
	local h = SessionHold.new()
	SessionHold.pick(h, "A#1")
	check("regression: a proposal consumes the hold of the part it names", SessionHold.consume(h, "A#1") == true and SessionHold.heldId(h) == nil)
	SessionHold.pick(h, "B#2")
	check("regression: the next pick succeeds after a rejected proposal", SessionHold.heldId(h) == "B#2")
	check("a proposal for a part that is not held leaves the held part alone", SessionHold.consume(h, "A#1") == false and SessionHold.heldId(h) == "B#2")
end

-- ---------- Ledger: each order is paid once ----------
do
	local l = Ledger.new()
	local ok, why = Ledger.complete(l, "office_01", 250)
	check("the first completion pays", ok == true and why == "PAID" and Ledger.balanceOf(l) == 250)
	local ok2, why2 = Ledger.complete(l, "office_01", 250)
	check("regression: a repeated completion does NOT pay again", ok2 == false and why2 == "ALREADY_PAID" and Ledger.balanceOf(l) == 250)
	check("the order is recorded as complete", Ledger.isComplete(l, "office_01"))
	check("a different order pays independently", Ledger.complete(l, "gaming_01", 400) == true and Ledger.balanceOf(l) == 650)
	for _, bad in ipairs({ 0, -5, 1.5, 0 / 0, math.huge }) do
		local okBad, whyBad = Ledger.complete(Ledger.new(), "x", bad)
		check("an invalid payout (" .. tostring(bad) .. ") is refused", okBad == false and whyBad == "INVALID")
	end
	local okNoId, whyNoId = Ledger.complete(Ledger.new(), "", 100)
	check("an empty order id is refused", okNoId == false and whyNoId == "INVALID")
end

-- ---------- Placement geometry: free placement layout checks ----------
do
	local caseBox = { center = { x = 0, y = 9, z = -1.5 }, size = { 12, 12, 9 } }
	local ok1, c1 = PlacementRules.checkFreeLayout({ id = "a", componentId = "x", center = { x = 11, y = 1, z = 2 }, size = { 2, 2, 2 } }, {}, caseBox, 3)
	check("a part below the table top is refused (BELOW_TABLE)", (not ok1) and c1 == "BELOW_TABLE")
	local ok2, c2 = PlacementRules.checkFreeLayout({ id = "a", componentId = "x", center = { x = 0, y = 9, z = -1.5 }, size = { 1, 1, 1 } }, {}, caseBox, 3)
	check("a part inside the case is refused (OVERLAPS_CASE)", (not ok2) and c2 == "OVERLAPS_CASE")
	local others = { { id = "b", componentId = "cpu_intel_i5_12400f", center = { x = 11, y = 5, z = 0 }, size = { 2, 2, 2 } } }
	local ok3, c3, p3 = PlacementRules.checkFreeLayout({ id = "a", componentId = "x", center = { x = 9.5, y = 5, z = 0 }, size = { 2, 2, 2 } }, others, caseBox, 3)
	check("an overlapping part is refused and the other part is named (OVERLAPS_PART)", (not ok3) and c3 == "OVERLAPS_PART" and p3.part == "cpu_intel_i5_12400f")
	check("a part that only touches another is allowed", PlacementRules.checkFreeLayout({ id = "a", componentId = "x", center = { x = 9, y = 5, z = 0 }, size = { 2, 2, 2 } }, others, caseBox, 3) == true)
	check("a clear spot on the table is allowed", PlacementRules.checkFreeLayout({ id = "a", componentId = "x", center = { x = 12, y = 5, z = 2 }, size = { 2, 2, 2 } }, others, caseBox, 3) == true)
	check("NaN never overlaps, so callers must check finiteness first (documented)", PlacementRules.boxesOverlap({ x = 0 / 0, y = 0, z = 0 }, { 1, 1, 1 }, { x = 0, y = 0, z = 0 }, { 1, 1, 1 }, 0) == false)
end

-- ---------- WorkshopLayout: the placeholder workshop is consistent with the rules ----------
do
	local WL = WorkshopLayout
	local missing = {}
	for id in pairs(C.Components) do
		if WL.Components[id] == nil then table.insert(missing, id) end
	end
	check("every catalog product has a placeholder layout entry", #missing == 0, table.concat(missing, ","))

	local bad = {}
	for id, entry in pairs(WL.Components) do
		local cat = C.Components[id]
		if cat == nil or cat.kind ~= entry.kind then table.insert(bad, id .. " kind") end
		for i = 1, 3 do
			if not (entry.size[i] > 0) then table.insert(bad, id .. " size") end
			if entry.color[i] < 0 or entry.color[i] > 1 then table.insert(bad, id .. " colour") end
		end
		if entry.label == nil or entry.label == "" then table.insert(bad, id .. " label") end
	end
	check("layout entries agree with catalog kinds and have sizes, colours and labels", #bad == 0, table.concat(bad, ","))

	local board = WL.Components.mb_asus_b760m.size
	local partFor = {
		MB_CPU = "cpu_intel_i5_12400f", MB_RAM1 = "ram_corsair_lpx_8_ddr4", MB_RAM2 = "ram_corsair_lpx_8_ddr4",
		MB_M2 = "ssd_samsung_980_500", MB_PWR24 = "cable_rm550_mb24", MB_CPU8 = "cable_rm550_cpu8",
	}
	local outside = {}
	for slot, off in pairs(WL.BoardSockets) do
		local s = WL.Components[partFor[slot]].size
		if math.abs(off[1]) + s[1] / 2 > board[1] / 2 or math.abs(off[2]) + s[2] / 2 > board[2] / 2 then
			table.insert(outside, slot)
		end
	end
	check("every board socket's part fits on the motherboard", #outside == 0, table.concat(outside, ","))
	local ramWidth = WL.Components.ram_corsair_lpx_8_ddr4.size[1]
	check("the two memory sticks do not overlap", math.abs(WL.BoardSockets.MB_RAM1[1] - WL.BoardSockets.MB_RAM2[1]) >= ramWidth)

	local cc, cs = WL.Case.center, WL.Case.size
	local function insideCase(p, size)
		return math.abs(p[1] - cc[1]) + size[1] / 2 <= cs[1] / 2 - 0.4
			and p[2] + size[2] / 2 <= cc[2] + cs[2] / 2 - 0.4
			and p[2] - size[2] / 2 >= 3.4
			and math.abs(p[3] - cc[3]) + size[3] / 2 <= cs[3] / 2 - 0.4
	end
	check("the motherboard mount sits inside the case", insideCase(WL.CaseSockets.CASE_MB, board))
	check("the PSU bay sits inside the case on the base", insideCase(WL.CaseSockets.CASE_PSU, WL.Components.psu_corsair_rm550.size))

	local function dist(a, b)
		local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end
	local stand = WL.StandPoint
	local farSpots = {}
	for i, spot in ipairs(WL.BinSpots) do
		if dist({ spot[1], WL.TableTopY + 1, spot[2] }, stand) > Config.MaxInteractDistance then table.insert(farSpots, i) end
	end
	check("every bin spot is within interaction reach of the stand point", #farSpots == 0, table.concat(farSpots, ","))
	check("the bin has at least nine spots (seven kit parts and two wrong parts)", #WL.BinSpots >= 9)

	local center = WL.CaseSockets.CASE_MB
	local farPorts = {}
	for slot, off in pairs(WL.BoardSockets) do
		if dist({ center[1] + off[1], center[2] + off[2], center[3] + off[3] }, stand) > Config.MaxInteractDistance then
			table.insert(farPorts, slot)
		end
	end
	check("every board socket is within interaction reach of the stand point", #farPorts == 0, table.concat(farPorts, ","))
	check("the case mount and the PSU bay are within reach", dist(center, stand) <= Config.MaxInteractDistance and dist(WL.CaseSockets.CASE_PSU, stand) <= Config.MaxInteractDistance)

	local tb = WL.Table
	local offTable, nearCase = {}, {}
	for i, spot in ipairs(WL.BinSpots) do
		if math.abs(spot[1]) + 1.5 > tb.size[1] / 2 or spot[2] - 0.5 < tb.center[3] - tb.size[3] / 2 or spot[2] + 0.5 > tb.center[3] + tb.size[3] / 2 then
			table.insert(offTable, i)
		end
		if math.abs(spot[1]) - 1.5 <= cs[1] / 2 then table.insert(nearCase, i) end
	end
	check("bin spots sit on the table", #offTable == 0, table.concat(offTable, ","))
	check("bin spots are clear of the case footprint", #nearCase == 0, table.concat(nearCase, ","))

	local half = Config.BenchHalfExtents
	local outsideBench = {}
	for slot, p in pairs(WL.CaseSockets) do
		if math.abs(p[1]) > half.x or math.abs(p[2]) > half.y or math.abs(p[3]) > half.z then table.insert(outsideBench, slot) end
	end
	check("case sockets are inside the bench bounds", #outsideBench == 0)
	check("the bench bounds are a plain table in the config", type(half.x) == "number" and half.x == 20)
end


-- ---------- Bin fit: every starter item has its own spot and fits the table ----------
do
	local WL = WorkshopLayout
	local items = {}
	for _, id in ipairs(C.StarterPC.kit) do table.insert(items, id) end
	for _, id in ipairs(C.StarterPC.extras) do table.insert(items, id) end
	check("there is exactly one bin spot per starter item", #WL.BinSpots == #items, #WL.BinSpots .. " spots, " .. #items .. " items")

	local caseBox = { center = PlacementRules.fromArray(WL.Case.center), size = WL.Case.size }
	local tb = WL.Table
	local problems, edge, far = {}, {}, {}
	local stand = WL.StandPoint
	local function pivotOf(i, id)
		local size = WL.Components[id].size
		local spot = WL.BinSpots[i]
		return { x = spot[1], y = WL.TableTopY + size[2] / 2, z = spot[2] }, size
	end
	for i, id in ipairs(items) do
		local centre, size = pivotOf(i, id)
		local others = {}
		for j, oid in ipairs(items) do
			if j ~= i then
				local oc, osz = pivotOf(j, oid)
				table.insert(others, { id = oid, componentId = oid, center = oc, size = osz })
			end
		end
		local ok, code = PlacementRules.checkFreeLayout({ id = id, componentId = id, center = centre, size = size }, others, caseBox, WL.TableTopY)
		if not ok then table.insert(problems, i .. ":" .. tostring(code)) end
		if math.abs(centre.x) + size[1] / 2 > tb.size[1] / 2
			or centre.z - size[3] / 2 < tb.center[3] - tb.size[3] / 2
			or centre.z + size[3] / 2 > tb.center[3] + tb.size[3] / 2 then
			table.insert(edge, i)
		end
		local dx, dy, dz = centre.x - stand[1], centre.y - stand[2], centre.z - stand[3]
		if math.sqrt(dx * dx + dy * dy + dz * dz) > Config.MaxInteractDistance then table.insert(far, i) end
	end
	check("starter items do not overlap each other or the case, and sit above the table", #problems == 0, table.concat(problems, ","))
	check("starter items stay on the table top", #edge == 0, table.concat(edge, ","))
	check("starter items can all be reached from the stand point", #far == 0, table.concat(far, ","))
end

-- ---------- Locale: new interface and line builders ----------
do
	local needed = { "ui.wallet", "ui.order_line", "ui.order_open", "ui.order_done", "ui.selected_part", "ui.diag_title", "ui.close", "ui.gone" }
	local missingKey = {}
	for _, k in ipairs(needed) do
		if Locale.text("en", k) == k or Locale.text("ar", k) == k then table.insert(missingKey, k) end
	end
	check("the new interface keys exist in both languages", #missingKey == 0, table.concat(missingKey, ","))

	local line = Locale.partLine("en", "cpu_amd_ryzen5_5600", C)
	check("the part line names the product and its socket", line:find("AMD Ryzen 5 5600", 1, true) ~= nil and line:find("AM4", 1, true) ~= nil, line)
	check("the Arabic part line keeps the product name in Latin script", Locale.partLine("ar", "ram_corsair_vengeance_8_ddr5", C):find("Corsair Vengeance 8GB DDR5-5200", 1, true) ~= nil)
	check("an unknown product gives a safe fallback", Locale.partLine("en", "nope", C) == "nope")

	local open = Locale.orderLine("en", C.Orders.office_01, false)
	check("the English order line shows the requirements and the open status", open:find("8 GB RAM", 1, true) ~= nil and open:find("250 GB storage", 1, true) ~= nil and open:find("in progress", 1, true) ~= nil, open)
	local done = Locale.orderLine("ar", C.Orders.office_01, true)
	check("the Arabic order line shows completion and no placeholders", done:find("مكتمل", 1, true) ~= nil and done:find("{", 1, true) == nil)

	local allOk = true
	for _, code in ipairs({ "OVERLAPS_PART", "OVERLAPS_CASE", "BELOW_TABLE", "OFF_TABLE", "REQUEST_INVALID" }) do
		local m1 = Locale.describe("en", code, { part = "cpu_intel_i5_12400f" }, C)
		local m2 = Locale.describe("ar", code, { part = "cpu_intel_i5_12400f" }, C)
		if m1:sub(1, 1) == "[" or m2:sub(1, 1) == "[" then allOk = false end
	end
	check("the new rule codes have messages in both languages", allOk)
end

-- ---------- r5 audit regression tests ----------
-- Written before any fix. Each block fails on the r4 code it guards. Decisions is loaded with pcall, so when
-- the module is missing its checks FAIL instead of stopping the whole run.
local function try(fn, ...)
	if type(fn) ~= "function" then
		return false, "missing"
	end
	local res = table.pack(pcall(fn, ...))
	if not res[1] then
		return false, res[2]
	end
	return true, table.unpack(res, 2, res.n)
end

local okDec, Decisions = pcall(require, "Decisions")
local dec = okDec and Decisions or nil
local R_WL = WorkshopLayout
local R_NEAR = { x = 0, y = 3, z = 7 }    -- within MaxInteractDistance of the test socket
local R_FAR = { x = 0, y = 3, z = 60 }    -- well outside reach
local R_SOCKET = { pos = { x = -1.5, y = 11.8, z = -4.6 }, up = { x = 0, y = 1, z = 0 }, look = { x = 0, y = 0, z = -1 } }
local R_CFG = { installReach = Config.InstallReachStuds, cosLimit = PlacementRules.cosLimit(Config.SnapAngleDegrees) }
local R_TABLE = { center = PlacementRules.fromArray(R_WL.Table.center), size = R_WL.Table.size }
local R_CASE = { center = PlacementRules.fromArray(R_WL.Case.center), size = R_WL.Case.size }

-- Builds the case, PSU and board, then asks the shared install decision about one CPU install.
local function installAttempt(catalog, componentId, proposed, socket, player)
	local s = AssemblyRules.newState(catalog.StarterPC.caseId)
	mustInstall(s, catalog, "psu_corsair_rm550", "i_psu", "CASE_PSU")
	mustInstall(s, catalog, "mb_asus_b760m", "i_mb", "CASE_MB")
	return try(dec and dec.install, {
		state = s, catalog = catalog, componentId = componentId, instanceId = "probe", slotId = "MB_CPU",
		proposed = proposed, socket = socket, player = player,
		benchOrigin = { x = 0, y = 0, z = 0 }, benchHalf = Config.BenchHalfExtents,
		maxReach = Config.MaxInteractDistance, cfg = R_CFG,
	})
end

-- audit 1: a part must stay on the table top. The layout rule is shared by the preview and the server.
do
	local function part(center)
		return { id = "probe", componentId = "probe_part", center = center, size = { 2, 2, 2 } }
	end
	local c1, ok1, code1 = try(PlacementRules.checkFreeLayout, part({ x = 0, y = 4, z = 10 }), {}, R_CASE, R_WL.TableTopY, R_TABLE)
	check("audit 1: a part hanging past the table's front edge is refused (OFF_TABLE)", c1 and ok1 == false and code1 == "OFF_TABLE", tostring(code1))
	local c2, ok2 = try(PlacementRules.checkFreeLayout, part({ x = 21, y = 4, z = 0 }), {}, R_CASE, R_WL.TableTopY, R_TABLE)
	check("audit 1: a part whose edge sits exactly on the table's side edge is allowed", c2 and ok2 == true)
	local c3, ok3, code3 = try(PlacementRules.checkFreeLayout, part({ x = 21.5, y = 4, z = 0 }), {}, R_CASE, R_WL.TableTopY, R_TABLE)
	check("audit 1: a part overhanging the table's side edge is refused (OFF_TABLE)", c3 and ok3 == false and code3 == "OFF_TABLE", tostring(code3))
	local c4, ok4 = try(PlacementRules.checkFreeLayout, part({ x = 30, y = 4, z = 0 }), {}, R_CASE, R_WL.TableTopY)
	check("audit 1: a call without a table box keeps the old layout rule", c4 and ok4 == true)
	local c5, ok5, code5 = try(dec and dec.free, {
		player = R_NEAR, proposed = { pos = { x = 0, y = 4, z = 10 } },
		benchOrigin = { x = 0, y = 0, z = 0 }, benchHalf = Config.BenchHalfExtents, maxReach = Config.MaxInteractDistance,
		layout = { candidate = part({ x = 0, y = 4, z = 10 }), others = {}, caseBox = R_CASE, surfaceY = R_WL.TableTopY, tableBox = R_TABLE },
	})
	check("audit 1: the shared free-placement decision refuses a drop past the table edge (OFF_TABLE)", c5 and ok5 == false and code5 == "OFF_TABLE", tostring(code5))
	local c6, ok6 = try(dec and dec.free, {
		player = R_NEAR, proposed = { pos = { x = 12, y = 4, z = 0 } },
		benchOrigin = { x = 0, y = 0, z = 0 }, benchHalf = Config.BenchHalfExtents, maxReach = Config.MaxInteractDistance,
		layout = { candidate = part({ x = 12, y = 4, z = 0 }), others = {}, caseBox = R_CASE, surfaceY = R_WL.TableTopY, tableBox = R_TABLE },
	})
	check("audit 1: the shared free-placement decision accepts a part on the table, away from the case", c6 and ok6 == true)
	local m1 = Locale.describe("en", "OFF_TABLE", {}, C)
	local m2 = Locale.describe("ar", "OFF_TABLE", {}, C)
	check("audit 1: OFF_TABLE has an English message", m1:sub(1, 1) ~= "[", m1)
	check("audit 1: OFF_TABLE has an Arabic message", m2:sub(1, 1) ~= "[", m2)
end

-- audit 2: the snap target is the nearest candidate that is valid, not the nearest candidate whatever its state.
do
	local candidates = {
		{ slotId = "MB_RAM1", pose = { pos = { x = 2.0, y = 2.0, z = 0.45 } } },
		{ slotId = "MB_RAM2", pose = { pos = { x = 2.7, y = 2.0, z = 0.45 } } },
	}
	local taken = { MB_RAM1 = true }
	local function evaluateTaken(candidate)
		if taken[candidate.slotId] then return false, "SLOT_OCCUPIED", {} end
		return true, nil, {}
	end
	local near = { x = 1.8, y = 2.0, z = 0.45 }
	local c1, chosen1, ok1 = try(PlacementRules.chooseSnap, candidates, near, Config.SnapRadiusStuds, evaluateTaken)
	check("audit 2: with the nearest slot taken, the free slot in range is chosen", c1 and chosen1 ~= nil and chosen1.slotId == "MB_RAM2" and ok1 == true, tostring(chosen1 and chosen1.slotId))
	local c2, chosen2, ok2, code2 = try(PlacementRules.chooseSnap, candidates, near, Config.SnapRadiusStuds, function() return false, "SLOT_OCCUPIED", {} end)
	check("audit 2: when nothing in range is valid, the nearest candidate and its refusal are reported", c2 and chosen2 ~= nil and chosen2.slotId == "MB_RAM1" and ok2 == false and code2 == "SLOT_OCCUPIED", tostring(code2))
	local c3, chosen3 = try(PlacementRules.chooseSnap, candidates, { x = 9, y = 2.0, z = 0.45 }, Config.SnapRadiusStuds, evaluateTaken)
	check("audit 2: nothing inside the snap radius gives no candidate", c3 and chosen3 == nil)
end

-- audit 3: the install decision, shared by preview and server. Order: rules, bounds, socket, reach, alignment.
do
	local outside = { pos = { x = 30, y = 11.8, z = -4.6 }, up = R_SOCKET.up, look = R_SOCKET.look }
	local c1, ok1 = installAttempt(C, "cpu_intel_i5_12400f", R_SOCKET, R_SOCKET, R_NEAR)
	check("audit 3: the matching Intel CPU is accepted at its socket within reach", c1 and ok1 == true)
	local c2, ok2, code2, params2 = installAttempt(C, "cpu_amd_ryzen5_5600", R_SOCKET, R_SOCKET, R_NEAR)
	check("audit 3: the AM4 CPU is refused at the LGA1700 socket with SOCKET_MISMATCH", c2 and ok2 == false and code2 == "SOCKET_MISMATCH", tostring(code2))
	check("audit 3: the SOCKET_MISMATCH refusal carries the board's socket", c2 and params2 ~= nil and params2.socket == "LGA1700")
	local c3, ok3, code3 = installAttempt(C, "cpu_intel_i5_12400f", R_SOCKET, R_SOCKET, R_FAR)
	check("audit 3: a socket out of reach is refused with TOO_FAR (the preview uses this same decision)", c3 and ok3 == false and code3 == "TOO_FAR", tostring(code3))
	local rotated = { pos = R_SOCKET.pos, up = R_SOCKET.up, look = { x = 1, y = 0, z = 0 } }
	local c4, ok4, code4 = installAttempt(C, "cpu_intel_i5_12400f", rotated, R_SOCKET, R_NEAR)
	check("audit 3: a CPU turned 90 degrees at the socket is refused with NOT_ALIGNED", c4 and ok4 == false and code4 == "NOT_ALIGNED", tostring(code4))
	local c5, ok5, code5 = installAttempt(C, "cpu_intel_i5_12400f", outside, R_SOCKET, R_NEAR)
	check("audit 3: a proposal outside the bench is refused with OUT_OF_BOUNDS", c5 and ok5 == false and code5 == "OUT_OF_BOUNDS", tostring(code5))
	local c6, ok6, code6 = installAttempt(C, "cpu_intel_i5_12400f", R_SOCKET, nil, R_NEAR)
	check("audit 3: an install into a socket that is not there is refused with NO_SOCKET", c6 and ok6 == false and code6 == "NO_SOCKET", tostring(code6))
	local c7, ok7, code7 = installAttempt(C, "cpu_amd_ryzen5_5600", outside, R_SOCKET, R_FAR)
	check("audit 3: rules come first, so a misplaced, far AMD CPU still reports SOCKET_MISMATCH", c7 and ok7 == false and code7 == "SOCKET_MISMATCH", tostring(code7))
end

-- audit 4: a pose is checked as a whole. A NaN or infinite orientation is refused, not only a bad position.
do
	local goodPose = { pos = { x = 0, y = 3, z = 7 }, look = { x = 0, y = 0, z = -1 }, up = { x = 0, y = 1, z = 0 } }
	local nanLook = { pos = goodPose.pos, look = { x = 0 / 0, y = 0, z = -1 }, up = goodPose.up }
	local infUp = { pos = goodPose.pos, look = goodPose.look, up = { x = 0, y = math.huge, z = 0 } }
	local c1, v1 = try(RequestGuard.isFinitePose, goodPose)
	check("audit 4: a finite pose with its orientation is accepted", c1 and v1 == true)
	local c2, v2 = try(RequestGuard.isFinitePose, nanLook)
	check("audit 4: a NaN orientation is refused (checking the position alone is not enough)", c2 and v2 == false)
	local c3, v3 = try(RequestGuard.isFinitePose, infUp)
	check("audit 4: an infinite up vector is refused", c3 and v3 == false)
end

-- audit 5: the limiter runs before argument checks, so a malformed request also uses the window.
do
	local limiter = RateLimit.new({ PickUp = 1 })
	local c1, code1 = try(RequestGuard.admit, limiter, "PickUp", 5.0, false)
	local c2, code2 = try(RequestGuard.admit, limiter, "PickUp", 5.2, false)
	local c3, code3 = try(RequestGuard.admit, limiter, "PickUp", 6.5, true)
	check("audit 5: a malformed request is answered REQUEST_INVALID and uses the window", c1 and code1 == "REQUEST_INVALID", tostring(code1))
	check("audit 5: a second malformed request in the same window is RATE_LIMITED", c2 and code2 == "RATE_LIMITED", tostring(code2))
	check("audit 5: a valid request after the window is admitted", c3 and code3 == nil, tostring(code3))
end

-- audit 6: the socket rule compares socket names, not brands. With the same geometry the matching pair is accepted.
do
	local am4Board = {}
	for k, v in pairs(C.Components.mb_asus_b760m) do am4Board[k] = v end
	am4Board.cpuSocket = "AM4"
	local AM4 = variant({ mb_asus_b760m = am4Board })
	local c1, ok1, code1 = installAttempt(AM4, "cpu_intel_i5_12400f", R_SOCKET, R_SOCKET, R_NEAR)
	check("audit 6: the Intel CPU is refused on an AM4 board (SOCKET_MISMATCH)", c1 and ok1 == false and code1 == "SOCKET_MISMATCH", tostring(code1))
	local c2, ok2 = installAttempt(AM4, "cpu_amd_ryzen5_5600", R_SOCKET, R_SOCKET, R_NEAR)
	check("audit 6: the AM4 CPU is accepted on the AM4 board at the same geometry", c2 and ok2 == true)
end

-- ---------- Summary ----------
print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
