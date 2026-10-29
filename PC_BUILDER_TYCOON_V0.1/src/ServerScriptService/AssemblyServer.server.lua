-- AssemblyServer.server.lua
-- Place in: ServerScriptService (Script named "AssemblyServer")
-- ROLE: the authoritative workshop. Validates every request, enforces ownership, places parts,
--       runs the boot and order checks, and pays each order once. Clients send requests only.
-- Replies carry codes and params, never display text. The client translates them.
-- STATUS: NOT YET RUN INSIDE ROBLOX STUDIO.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local AssemblyRules = require(Shared:WaitForChild("AssemblyRules"))
local PlacementRules = require(Shared:WaitForChild("PlacementRules"))
local RateLimit = require(Shared:WaitForChild("RateLimit"))
local RemoteLayout = require(Shared:WaitForChild("RemoteLayout"))
local RequestGuard = require(Shared:WaitForChild("RequestGuard"))
local SessionHold = require(Shared:WaitForChild("SessionHold"))
local Ledger = require(Shared:WaitForChild("Ledger"))
local WorkshopLayout = require(Shared:WaitForChild("WorkshopLayout"))
local Decisions = require(Shared:WaitForChild("Decisions"))
local WorkshopBuilder = require(script.Parent:WaitForChild("WorkshopBuilder"))

local INSTALL_CFG = {
	installReach = Config.InstallReachStuds,
	cosLimit = PlacementRules.cosLimit(Config.SnapAngleDegrees),
}
local BENCH_HALF = Config.BenchHalfExtents
local TABLE_TOP = WorkshopLayout.TableTopY
local CASE_BOX = {
	center = PlacementRules.fromArray(WorkshopLayout.Case.center),
	size = WorkshopLayout.Case.size,
}
local TABLE_BOX = {
	center = PlacementRules.fromArray(WorkshopLayout.Table.center),
	size = WorkshopLayout.Table.size,
}
local BOOT_COLORS = {
	idle = Color3.fromRGB(120, 120, 120),
	ok = Color3.fromRGB(60, 220, 110),
	fail = Color3.fromRGB(230, 70, 70),
}

-- Legacy path: hand-built templates. Used only when BOTH templates exist in ServerStorage.
local templates = ServerStorage:FindFirstChild("ComponentTemplates")
local workshopTemplate = ServerStorage:FindFirstChild("WorkshopTemplate")
local useLegacy = templates ~= nil and workshopTemplate ~= nil
if useLegacy then
	print("[AssemblyServer] Using the hand-built templates in ServerStorage.")
end

local workshopsFolder = Workspace:FindFirstChild("Workshops")
if workshopsFolder == nil then
	workshopsFolder = Instance.new("Folder")
	workshopsFolder.Name = "Workshops"
	workshopsFolder.Parent = Workspace
end

-- Remote setup. Deterministic: reuse one valid folder, create only what is missing, STOP on any conflict.
local function describeIssue(issue)
	local p = issue.params
	if issue.code == "DUPLICATE_FOLDER" then
		return "Found " .. p.count .. " objects named '" .. p.name .. "' directly under ReplicatedStorage. Keep exactly one Folder with that name."
	elseif issue.code == "NAME_TAKEN_BY_NON_FOLDER" then
		return "'" .. p.name .. "' under ReplicatedStorage is a " .. p.className .. ", not a Folder. Rename or remove it."
	elseif issue.code == "DUPLICATE_REMOTE" then
		return "'" .. p.name .. "' appears " .. p.count .. " times inside the Folder. Keep exactly one RemoteEvent with that name."
	elseif issue.code == "WRONG_REMOTE_CLASS" then
		return "'" .. p.name .. "' inside the Folder is a " .. p.className .. ", but it must be a RemoteEvent."
	end
	return "Unknown remote setup issue: " .. tostring(issue.code)
end

local function collectTopLevel(folderName)
	local list = {}
	for _, child in ipairs(ReplicatedStorage:GetChildren()) do
		if child.Name == folderName then
			local entry = { name = child.Name, className = child.ClassName, children = {} }
			for _, grandchild in ipairs(child:GetChildren()) do
				table.insert(entry.children, { name = grandchild.Name, className = grandchild.ClassName })
			end
			table.insert(list, entry)
		end
	end
	return list
end

local remoteFolder = nil
local layout = RemoteLayout.plan(Config.RemoteFolderName, Config.RemoteNames, collectTopLevel(Config.RemoteFolderName))
for _, issue in ipairs(layout.issues) do
	warn("[AssemblyServer] Remote setup conflict: " .. describeIssue(issue))
end
if layout.action == "stop" then
	warn("[AssemblyServer] Remote setup STOPPED. Nothing was created or changed in ReplicatedStorage. Fix the conflict above, then press Play again.")
else
	if layout.action == "create_folder" then
		local created = Instance.new("Folder")
		created.Name = Config.RemoteFolderName
		created.Parent = ReplicatedStorage
	end
	local folder = ReplicatedStorage:FindFirstChild(Config.RemoteFolderName)
	for _, name in ipairs(layout.create) do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
	local verified = folder ~= nil
	for _, name in ipairs(Config.RemoteNames) do
		local event = folder and folder:FindFirstChild(name)
		if event == nil or not event:IsA("RemoteEvent") then
			verified = false
			warn("[AssemblyServer] Could not verify RemoteEvent '" .. name .. "' after setup.")
		end
	end
	if verified then
		remoteFolder = folder
	else
		warn("[AssemblyServer] Remote setup did not verify. Workshops stay disabled until this is fixed.")
	end
end

local sessions = {}
local workshopCount = 0

-- kind: "system" | "pickup" | "placement" | "uninstall" | "screw" | "boot"
local function notify(player, kind, ok, code, params, extra)
	if remoteFolder == nil then
		return
	end
	extra = extra or {}
	remoteFolder.Feedback:FireClient(player, {
		kind = kind,
		ok = ok,
		code = code,
		params = params or {},
		instanceId = extra.instanceId,
		diagnostics = extra.diagnostics or {},
		final = extra.final,
	})
end

local function notifyInvalid(player, kind, instanceId)
	notify(player, kind, false, "REQUEST_INVALID", {}, { instanceId = RequestGuard.isId(instanceId) and instanceId or nil })
end

local function rootPoint(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return nil
	end
	return PlacementRules.point(root.Position)
end

local function poseOf(cf)
	return PlacementRules.poseFromVectors(cf.Position, cf.UpVector, cf.LookVector)
end

local function setAnchored(model, anchored)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored
		end
	end
end

-- Socket parts live on the case, or on the installed owner part (the motherboard for board sockets).
local function findSocket(session, slotId)
	local slot = Catalog.Slots[slotId]
	if slot == nil then
		return nil
	end
	local owner
	if slot.ownerSlot == nil then
		owner = session.workshop:FindFirstChild("Case")
	else
		local ownerInstance = session.state.slots[slot.ownerSlot]
		owner = ownerInstance and session.parts[ownerInstance]
	end
	if owner == nil then
		return nil
	end
	local socket = owner:FindFirstChild(slotId, true)
	if socket and socket:IsA("BasePart") then
		return socket
	end
	return nil
end

-- Screw progress shown above an installed part that needs screws.
local function hostOf(model)
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

local function setScrewLabel(model, have, need)
	local host = hostOf(model)
	if host == nil or need <= 0 then
		return
	end
	local gui = host:FindFirstChild("ScrewLabel")
	if gui == nil then
		gui = Instance.new("BillboardGui")
		gui.Name = "ScrewLabel"
		gui.Size = UDim2.fromOffset(60, 18)
		gui.StudsOffset = Vector3.new(0, host.Size.Y / 2 + 3.4, 0)
		gui.MaxDistance = 40
		gui.Parent = host
		local t = Instance.new("TextLabel")
		t.Name = "Text"
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 0.2
		t.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
		t.TextColor3 = Color3.fromRGB(255, 220, 120)
		t.TextScaled = true
		t.Font = Enum.Font.GothamBold
		t.Parent = gui
	end
	local text = gui:FindFirstChild("Text")
	if text ~= nil then
		text.Text = tostring(have) .. "/" .. tostring(need)
	end
end

local function clearScrewLabel(model)
	local host = hostOf(model)
	local gui = host and host:FindFirstChild("ScrewLabel")
	if gui ~= nil then
		gui:Destroy()
	end
end

local function placeInstalled(session, componentId, instanceId, slotId, socket)
	local model = session.parts[instanceId]
	model:PivotTo(socket.CFrame)
	setAnchored(model, true)
	model:SetAttribute("SlotId", slotId)
	model:SetAttribute("Installed", true)
	AssemblyRules.applyInstall(session.state, componentId, instanceId, slotId)
end

local function setBootState(s, state)
	s.workshop:SetAttribute("BootState", state)
	if s.led ~= nil then
		s.led.Color = BOOT_COLORS[state] or BOOT_COLORS.idle
	end
end

-- Layout context for Decisions.free, in workshop coordinates: table top, case interior, and other parts.
-- Returns nil for legacy parts that have no size data.
local function layoutFor(s, instanceId, pose)
	local size = s.sizes[instanceId]
	if size == nil then
		return nil -- legacy templates: no layout data, so no layout checks
	end
	local model = s.parts[instanceId]
	local centre = PlacementRules.point(s.origin:PointToObjectSpace(pose.Position))
	local others = {}
	for otherId, otherModel in pairs(s.parts) do
		if otherId ~= instanceId and s.sizes[otherId] ~= nil then
			table.insert(others, {
				id = otherId,
				componentId = otherModel:GetAttribute("ComponentId"),
				center = PlacementRules.point(s.origin:PointToObjectSpace(otherModel:GetPivot().Position)),
				size = s.sizes[otherId],
			})
		end
	end
	local candidate = { id = instanceId, componentId = model:GetAttribute("ComponentId"), center = centre, size = size }
	return { candidate = candidate, others = others, caseBox = s.caseBox, surfaceY = TABLE_TOP, tableBox = TABLE_BOX }
end

local function starterList()
	local list = {}
	for _, id in ipairs(Catalog.StarterPC.kit) do
		table.insert(list, id)
	end
	for _, id in ipairs(Catalog.StarterPC.extras) do
		table.insert(list, id)
	end
	return list
end

local function spawnParts(session)
	for index, componentId in ipairs(starterList()) do
		local instanceId = componentId .. "#" .. index
		local model, home, size
		if session.legacy then
			local template = templates:FindFirstChild(componentId)
			if template == nil then
				warn("[AssemblyServer] Missing component template: " .. componentId)
			else
				model = template:Clone()
				local column = (index - 1) % 4
				local row = math.floor((index - 1) / 4)
				home = session.legacyBin * CFrame.new(column * Config.BinSpacing, 0, row * Config.BinSpacing)
				local ext = model:GetExtentsSize()
				size = { ext.X, ext.Y, ext.Z }
			end
		else
			model = WorkshopBuilder.buildComponent(componentId)
			home = WorkshopBuilder.binHome(index, componentId, session.origin)
			local entry = WorkshopLayout.Components[componentId]
			size = entry and { entry.size[1], entry.size[2], entry.size[3] } or nil
		end
		if model ~= nil and home ~= nil then
			model.Name = componentId
			model:SetAttribute("ComponentId", componentId)
			model:SetAttribute("InstanceId", instanceId)
			model:SetAttribute("Installed", false)
			model:SetAttribute("Owner", session.player.UserId)
			model:PivotTo(home)
			setAnchored(model, true)
			model.Parent = session.workshop
			session.parts[instanceId] = model
			session.homeCFrame[instanceId] = home
			session.sizes[instanceId] = size
		end
	end
end

local function placeCharacter(player)
	local s = sessions[player]
	local character = player.Character
	if s == nil or character == nil then
		return
	end
	local stand = WorkshopLayout.StandPoint
	local focus = WorkshopLayout.BenchFocus
	local standWorld = s.origin * CFrame.new(stand[1], stand[2], stand[3])
	local focusWorld = s.origin * CFrame.new(focus[1], focus[2], focus[3])
	character:PivotTo(CFrame.new(standWorld.Position, focusWorld.Position))
end

local function createSession(player)
	if remoteFolder == nil or sessions[player] ~= nil then
		return
	end
	workshopCount = workshopCount + 1
	local workshop, led
	if useLegacy then
		workshop = workshopTemplate:Clone()
	else
		workshop, led = WorkshopBuilder.buildWorkshop()
	end
	workshop.Name = tostring(player.UserId)
	workshop:PivotTo(CFrame.new(workshopCount * Config.WorkshopSpacing, 0, 0))
	workshop:SetAttribute("Owner", player.UserId)
	workshop:SetAttribute("CaseId", Catalog.StarterPC.caseId)
	workshop:SetAttribute("OrderId", Catalog.StarterPC.orderId)
	workshop:SetAttribute("OrderDone", false)
	workshop:SetAttribute("Wallet", 0)
	workshop:SetAttribute("BootState", "idle")
	workshop.Parent = workshopsFolder

	local origin = workshop:GetPivot()
	local legacyBin = origin
	if useLegacy then
		local bin = workshop:FindFirstChild("PartsBin")
		if bin ~= nil and bin:IsA("BasePart") then
			legacyBin = bin.CFrame
		end
	end
	local session = {
		player = player,
		workshop = workshop,
		origin = origin,
		benchOrigin = PlacementRules.point(origin.Position),
		legacy = useLegacy,
		legacyBin = legacyBin,
		caseBox = (not useLegacy) and CASE_BOX or nil,
		led = led,
		state = AssemblyRules.newState(Catalog.StarterPC.caseId),
		parts = {},
		homeCFrame = {},
		sizes = {},
		hold = SessionHold.new(),
		limiter = RateLimit.new(Config.RateLimit),
		ledger = Ledger.new(),
	}
	sessions[player] = session
	spawnParts(session)
	placeCharacter(player)
	notify(player, "system", true, "WORKSHOP_READY", {})
end

-- ---------- request handlers: every one validates its arguments first ----------

local function onPickUp(player, instanceId)
	local s = sessions[player]
	if s == nil then return end
	local admitCode = RequestGuard.admit(s.limiter, "PickUp", os.clock(), RequestGuard.isId(instanceId))
	if admitCode == "REQUEST_INVALID" then return notifyInvalid(player, "pickup", instanceId) end
	if admitCode == "RATE_LIMITED" then return notify(player, "pickup", false, "RATE_LIMITED", {}, { instanceId = instanceId }) end
	local model = s.parts[instanceId]
	if model == nil or model:GetAttribute("Owner") ~= player.UserId then
		return notify(player, "pickup", false, "NOT_IN_WORKSHOP", {}, { instanceId = instanceId })
	end
	if s.state.instances[instanceId] ~= nil then
		return notify(player, "pickup", false, "LOCKED_INSTALLED", {}, { instanceId = instanceId })
	end
	local root = rootPoint(player)
	if root == nil or not PlacementRules.inReach(root, PlacementRules.point(model:GetPivot().Position), Config.MaxInteractDistance) then
		return notify(player, "pickup", false, "TOO_FAR", {}, { instanceId = instanceId })
	end
	SessionHold.pick(s.hold, instanceId)
	return notify(player, "pickup", true, "PICKED_UP", {}, { instanceId = instanceId })
end

local function onReleaseHold(player, instanceId)
	local s = sessions[player]
	if s == nil then return end
	if not RequestGuard.isId(instanceId) then return end
	s.limiter:allow("ReleaseHold", os.clock()) -- counted only: a release always takes effect
	SessionHold.release(s.hold, instanceId)
end

-- The client proposes a pose. An empty slotId means free placement on the bench.
local function onProposePlacement(player, instanceId, pose, slotId)
	local s = sessions[player]
	if s == nil then return end
	local validArgs = RequestGuard.isId(instanceId)
		and RequestGuard.isSlotOrFree(slotId, Catalog)
		and typeof(pose) == "CFrame"
		and RequestGuard.isFinitePose({ pos = pose.Position, look = pose.LookVector, up = pose.UpVector })
	-- Every proposal ends the hold attempt, whatever the outcome. Only a well-formed id can own a hold.
	local wasHeld = RequestGuard.isId(instanceId) and SessionHold.consume(s.hold, instanceId) or false
	local admitCode = RequestGuard.admit(s.limiter, "ProposePlacement", os.clock(), validArgs)
	if admitCode == "REQUEST_INVALID" then
		return notifyInvalid(player, "placement", instanceId)
	end
	if admitCode == "RATE_LIMITED" then
		return notify(player, "placement", false, "RATE_LIMITED", {}, { instanceId = instanceId })
	end
	if not wasHeld then
		return notify(player, "placement", false, "NOT_HELD", {}, { instanceId = instanceId })
	end
	local model = s.parts[instanceId]
	if model == nil or model:GetAttribute("Owner") ~= player.UserId then
		return notify(player, "placement", false, "NOT_IN_WORKSHOP", {}, { instanceId = instanceId })
	end
	local root = rootPoint(player)
	if root == nil then
		return notify(player, "placement", false, "TOO_FAR", {}, { instanceId = instanceId })
	end
	local componentId = model:GetAttribute("ComponentId")
	local proposed = poseOf(pose)

	-- Free placement on the bench. The shared decision checks reach, bounds, height, table top, case and other parts.
	if slotId == "" then
		local okFree, codeFree, paramsFree = Decisions.free({
			player = root,
			proposed = proposed,
			benchOrigin = s.benchOrigin,
			benchHalf = BENCH_HALF,
			maxReach = Config.MaxInteractDistance,
			layout = layoutFor(s, instanceId, pose),
		})
		if not okFree then
			return notify(player, "placement", false, codeFree, paramsFree or {}, { instanceId = instanceId })
		end
		model:PivotTo(pose)
		setAnchored(model, true)
		return notify(player, "placement", true, "PLACED_FREE", { part = componentId }, { instanceId = instanceId, final = pose })
	end

	-- Install into a socket. The same shared decision the client preview uses: rules, bounds, socket, reach, alignment.
	local socket = findSocket(s, slotId)
	local okInstall, codeInstall, paramsInstall = Decisions.install({
		state = s.state,
		catalog = Catalog,
		componentId = componentId,
		instanceId = instanceId,
		slotId = slotId,
		proposed = proposed,
		socket = socket and poseOf(socket.CFrame) or nil,
		player = root,
		benchOrigin = s.benchOrigin,
		benchHalf = BENCH_HALF,
		maxReach = Config.MaxInteractDistance,
		cfg = INSTALL_CFG,
	})
	if not okInstall then
		return notify(player, "placement", false, codeInstall, paramsInstall or {}, { instanceId = instanceId })
	end
	placeInstalled(s, componentId, instanceId, slotId, socket)
	setScrewLabel(model, 0, Catalog.Components[componentId].screwsRequired or 0)
	return notify(player, "placement", true, "INSTALLED", { part = componentId, slot = slotId }, { instanceId = instanceId, final = socket.CFrame })
end

local function onRequestUninstall(player, instanceId)
	local s = sessions[player]
	if s == nil then return end
	local admitCode = RequestGuard.admit(s.limiter, "RequestUninstall", os.clock(), RequestGuard.isId(instanceId))
	if admitCode == "REQUEST_INVALID" then return notifyInvalid(player, "uninstall", instanceId) end
	if admitCode == "RATE_LIMITED" then return notify(player, "uninstall", false, "RATE_LIMITED", {}) end
	local model = s.parts[instanceId]
	if model == nil or model:GetAttribute("Owner") ~= player.UserId then
		return notify(player, "uninstall", false, "NOT_IN_WORKSHOP", {}, { instanceId = instanceId })
	end
	local root = rootPoint(player)
	if root == nil or not PlacementRules.inReach(root, PlacementRules.point(model:GetPivot().Position), Config.MaxInteractDistance) then
		return notify(player, "uninstall", false, "TOO_FAR", {}, { instanceId = instanceId })
	end
	local ok, diag = AssemblyRules.validateUninstall(s.state, Catalog, instanceId)
	if not ok then
		return notify(player, "uninstall", false, diag.code, diag.params, { instanceId = instanceId })
	end
	local componentId = model:GetAttribute("ComponentId")
	AssemblyRules.applyUninstall(s.state, instanceId)
	model:PivotTo(s.homeCFrame[instanceId])
	model:SetAttribute("SlotId", nil)
	model:SetAttribute("Installed", false)
	clearScrewLabel(model)
	return notify(player, "uninstall", true, "REMOVED", { part = componentId }, { instanceId = instanceId })
end

local function onTightenScrew(player, instanceId)
	local s = sessions[player]
	if s == nil then return end
	local admitCode = RequestGuard.admit(s.limiter, "TightenScrew", os.clock(), RequestGuard.isId(instanceId))
	if admitCode == "REQUEST_INVALID" then return notifyInvalid(player, "screw", instanceId) end
	if admitCode == "RATE_LIMITED" then return notify(player, "screw", false, "RATE_LIMITED", {}) end
	local model = s.parts[instanceId]
	if model == nil or model:GetAttribute("Owner") ~= player.UserId then
		return notify(player, "screw", false, "NOT_IN_WORKSHOP", {}, { instanceId = instanceId })
	end
	local root = rootPoint(player)
	if root == nil or not PlacementRules.inReach(root, PlacementRules.point(model:GetPivot().Position), Config.MaxInteractDistance) then
		return notify(player, "screw", false, "TOO_FAR", {}, { instanceId = instanceId })
	end
	local ok, diag = AssemblyRules.validateTighten(s.state, Catalog, instanceId)
	if not ok then
		return notify(player, "screw", false, diag.code, diag.params, { instanceId = instanceId })
	end
	AssemblyRules.applyTighten(s.state, instanceId)
	local inst = s.state.instances[instanceId]
	local need = Catalog.Components[inst.componentId].screwsRequired or 0
	local have = s.state.screws[instanceId]
	setScrewLabel(model, have, need)
	return notify(player, "screw", true, "SCREW_ADDED", { part = inst.componentId, have = have, need = need }, { instanceId = instanceId })
end

local function onRequestBoot(player)
	local s = sessions[player]
	if s == nil then return end
	if not s.limiter:allow("RequestBoot", os.clock()) then return notify(player, "boot", false, "RATE_LIMITED", {}) end

	-- Boot and order are both decided here. The client cannot declare either one passed.
	local boot = AssemblyRules.evaluateBoot(s.state, Catalog)
	if not boot.ok then
		setBootState(s, "fail")
		return notify(player, "boot", false, "BOOT_FAILED", {}, { diagnostics = boot.diagnostics })
	end
	local order = Catalog.Orders[Catalog.StarterPC.orderId]
	setBootState(s, "ok")
	local ok, diagnostics = AssemblyRules.evaluateOrder(s.state, Catalog, order)
	if not ok then
		return notify(player, "boot", false, "ORDER_NOT_MET", {}, { diagnostics = diagnostics })
	end
	local paid = Ledger.complete(s.ledger, order.id, order.payout)
	if not paid then
		return notify(player, "boot", true, "ORDER_ALREADY_DONE", {})
	end
	local balance = Ledger.balanceOf(s.ledger)
	s.workshop:SetAttribute("OrderDone", true)
	s.workshop:SetAttribute("Wallet", balance)
	return notify(player, "boot", true, "ORDER_DONE", { order = order.id, payout = order.payout, wallet = balance })
end

-- ---------- players ----------

local function onPlayerAdded(player)
	createSession(player)
	player.CharacterAdded:Connect(function()
		placeCharacter(player)
	end)
	if player.Character ~= nil then
		placeCharacter(player)
	end
end

local function onPlayerRemoving(player)
	local s = sessions[player]
	sessions[player] = nil
	if s ~= nil and s.workshop ~= nil then
		s.workshop:Destroy()
	end
end

if remoteFolder ~= nil then
	remoteFolder.PickUp.OnServerEvent:Connect(onPickUp)
	remoteFolder.ReleaseHold.OnServerEvent:Connect(onReleaseHold)
	remoteFolder.ProposePlacement.OnServerEvent:Connect(onProposePlacement)
	remoteFolder.RequestUninstall.OnServerEvent:Connect(onRequestUninstall)
	remoteFolder.TightenScrew.OnServerEvent:Connect(onTightenScrew)
	remoteFolder.RequestBoot.OnServerEvent:Connect(onRequestBoot)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
end
