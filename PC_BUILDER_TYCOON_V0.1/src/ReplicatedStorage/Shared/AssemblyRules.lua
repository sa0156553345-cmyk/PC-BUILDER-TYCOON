-- AssemblyRules.lua
-- Place in: ReplicatedStorage > Shared (ModuleScript "AssemblyRules")
-- PURE rule logic. No Roblox APIs. The SERVER runs these checks. Clients may run them for preview only.
-- Rules return codes and parameters, never display text. Text is produced by Locale.lua (language-specific).
-- validate* functions return true, or false plus { code = <CODE_NAME>, params = { ... } }.

local AssemblyRules = {}

local function fail(code, params)
	return false, { code = code, params = params or {} }
end

local function listContains(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

-- state: { caseId, slots = {slotId -> instanceId}, instances = {instanceId -> {componentId, slotId}}, screws = {} }
function AssemblyRules.newState(caseId)
	return { caseId = caseId, slots = {}, instances = {}, screws = {} }
end

local function installedComponent(state, catalog, slotId)
	local instanceId = state.slots[slotId]
	if instanceId == nil then
		return nil
	end
	return catalog.Components[state.instances[instanceId].componentId]
end

function AssemblyRules.validateInstall(state, catalog, componentId, instanceId, slotId)
	local comp = catalog.Components[componentId]
	if comp == nil then
		return fail("UNKNOWN_COMPONENT", { part = componentId })
	end
	local slot = catalog.Slots[slotId]
	if slot == nil then
		return fail("UNKNOWN_SLOT", { slot = slotId })
	end
	if state.instances[instanceId] ~= nil then
		return fail("ALREADY_INSTALLED", { part = componentId })
	end
	if state.slots[slotId] ~= nil then
		return fail("SLOT_OCCUPIED", { slot = slotId })
	end
	if not listContains(slot.accepts, comp.kind) then
		return fail("WRONG_PART_FOR_SLOT", { part = componentId, slot = slotId, kind = slot.accepts[1] })
	end
	for _, requiredSlot in ipairs(slot.requires) do
		if state.slots[requiredSlot] == nil then
			return fail("PARENT_NOT_INSTALLED", { slot = requiredSlot })
		end
	end

	if comp.kind == "Motherboard" then
		local caseComp = catalog.Components[state.caseId]
		if not listContains(caseComp.formFactors, comp.formFactor) then
			return fail("FORMFACTOR_MISMATCH", {
				part = componentId, formFactor = comp.formFactor, caseForm = table.concat(caseComp.formFactors, ", "),
			})
		end
	end

	-- Safe: the requires lists above guarantee the motherboard exists for these checks.
	local board = installedComponent(state, catalog, "CASE_MB")
	if comp.kind == "CPU" and comp.socket ~= board.cpuSocket then
		return fail("SOCKET_MISMATCH", { part = componentId, socket = board.cpuSocket })
	end
	if comp.kind == "RAM" and comp.ramType ~= board.ramType then
		return fail("RAM_TYPE_MISMATCH", { part = componentId, ramType = board.ramType })
	end

	if comp.kind == "Cable" then
		if slot.cableType ~= comp.cableType then
			return fail("CABLE_WRONG_PORT", { part = componentId, slot = slotId })
		end
		local psu = installedComponent(state, catalog, "CASE_PSU")
		if not listContains(psu.cables, comp.cableType) then
			return fail("PSU_CABLE_UNAVAILABLE", { cableType = comp.cableType })
		end
	end

	return true
end

function AssemblyRules.applyInstall(state, componentId, instanceId, slotId)
	state.instances[instanceId] = { componentId = componentId, slotId = slotId }
	state.slots[slotId] = instanceId
	state.screws[instanceId] = 0
end

function AssemblyRules.validateUninstall(state, catalog, instanceId)
	local inst = state.instances[instanceId]
	if inst == nil then
		return fail("NOT_INSTALLED", {})
	end
	for otherSlot, otherInstanceId in pairs(state.slots) do
		for _, requiredSlot in ipairs(catalog.Slots[otherSlot].requires) do
			if requiredSlot == inst.slotId then
				local other = state.instances[otherInstanceId].componentId
				return fail("HAS_DEPENDENTS", { part = inst.componentId, other = other })
			end
		end
	end
	return true
end

-- V0.1 simplification: removing a part also removes its screws.
function AssemblyRules.applyUninstall(state, instanceId)
	local inst = state.instances[instanceId]
	state.slots[inst.slotId] = nil
	state.instances[instanceId] = nil
	state.screws[instanceId] = nil
end

function AssemblyRules.validateTighten(state, catalog, instanceId)
	local inst = state.instances[instanceId]
	if inst == nil then
		return fail("NOT_INSTALLED", {})
	end
	local comp = catalog.Components[inst.componentId]
	if (state.screws[instanceId] or 0) >= (comp.screwsRequired or 0) then
		return fail("NO_SCREWS_NEEDED", { part = inst.componentId })
	end
	return true
end

function AssemblyRules.applyTighten(state, instanceId)
	state.screws[instanceId] = (state.screws[instanceId] or 0) + 1
end

function AssemblyRules.requiredWatts(state, catalog)
	local pm = catalog.PowerModel
	local total = pm.HeadroomWatts
	for _, inst in pairs(state.instances) do
		local comp = catalog.Components[inst.componentId]
		if comp.kind == "CPU" then
			total = total + (comp.tdp or 0)
		elseif comp.kind == "Motherboard" then
			total = total + pm.MotherboardWatts
		elseif comp.kind == "RAM" then
			total = total + pm.RamWattsPerStick
		elseif comp.kind == "Storage" then
			total = total + pm.StorageWatts
		end
	end
	return total
end

-- Boot test. Collects EVERY problem, so players see all of them at once.
function AssemblyRules.evaluateBoot(state, catalog)
	local diagnostics = {}
	local function add(code, params)
		table.insert(diagnostics, { code = code, params = params or {} })
	end

	local board = installedComponent(state, catalog, "CASE_MB")
	local psu = installedComponent(state, catalog, "CASE_PSU")

	if board == nil then
		add("NO_MOTHERBOARD")
	end
	if psu == nil then
		add("NO_PSU")
	end

	if board ~= nil then
		if state.slots["MB_CPU"] == nil then
			add("NO_CPU")
		end
		if state.slots["MB_RAM1"] == nil and state.slots["MB_RAM2"] == nil then
			add("NO_RAM")
		end
		if state.slots["MB_M2"] == nil then
			add("NO_STORAGE")
		end
		for _, port in ipairs(board.requiredPorts) do
			if state.slots[port] == nil then
				add("MISSING_CABLE", { slot = port })
			end
		end
	end

	for instanceId, inst in pairs(state.instances) do
		local comp = catalog.Components[inst.componentId]
		local need = comp.screwsRequired or 0
		local have = state.screws[instanceId] or 0
		if have < need then
			add("SCREWS_INCOMPLETE", { part = inst.componentId, have = have, need = need })
		end
	end

	if board ~= nil and psu ~= nil then
		local needed = AssemblyRules.requiredWatts(state, catalog)
		if psu.watts < needed then
			add("PSU_INSUFFICIENT", { needW = needed, watts = psu.watts })
		end
	end

	return { ok = (#diagnostics == 0), diagnostics = diagnostics }
end

-- Order check. The PC must boot first, then meet RAM and storage minimums.
function AssemblyRules.evaluateOrder(state, catalog, order)
	local boot = AssemblyRules.evaluateBoot(state, catalog)
	if not boot.ok then
		return false, boot.diagnostics
	end

	local ramGB = 0
	for _, slotId in ipairs({ "MB_RAM1", "MB_RAM2" }) do
		local comp = installedComponent(state, catalog, slotId)
		if comp ~= nil then
			ramGB = ramGB + (comp.capacityGB or 0)
		end
	end
	local storage = installedComponent(state, catalog, "MB_M2")
	local storageGB = 0
	if storage ~= nil then
		storageGB = storage.capacityGB or 0
	end

	local diagnostics = {}
	if ramGB < order.minRamGB then
		table.insert(diagnostics, { code = "ORDER_RAM_TOO_LOW", params = { need = order.minRamGB, have = ramGB } })
	end
	if storageGB < order.minStorageGB then
		table.insert(diagnostics, { code = "ORDER_STORAGE_TOO_SMALL", params = { need = order.minStorageGB, have = storageGB } })
	end
	return #diagnostics == 0, diagnostics
end

return AssemblyRules
