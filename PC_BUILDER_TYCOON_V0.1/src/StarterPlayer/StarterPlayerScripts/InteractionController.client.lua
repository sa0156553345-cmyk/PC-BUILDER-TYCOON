-- InteractionController.client.lua
-- Place in: StarterPlayer > StarterPlayerScripts (LocalScript named "InteractionController")
-- ROLE: input (touch and mouse), ghost prediction, placement preview with valid and invalid states,
--       EN and AR interface with RTL, the full boot diagnostics panel, the order and wallet display,
--       and the close-up camera. It sends requests only. The server decides every result.
-- STATUS: NOT YET RUN INSIDE ROBLOX STUDIO. Touch identity, the camera sink and Arabic rendering are UNVERIFIED.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local AssemblyRules = require(Shared:WaitForChild("AssemblyRules"))
local PlacementRules = require(Shared:WaitForChild("PlacementRules"))
local Locale = require(Shared:WaitForChild("Locale"))
local DragSequence = require(Shared:WaitForChild("DragSequence"))
local PointerTracker = require(Shared:WaitForChild("PointerTracker"))
local WorkshopLayout = require(Shared:WaitForChild("WorkshopLayout"))
local Decisions = require(Shared:WaitForChild("Decisions"))

local remotes = ReplicatedStorage:WaitForChild(Config.RemoteFolderName, 10)
if remotes == nil or not remotes:IsA("Folder") then
	warn("[InteractionController] Folder '" .. Config.RemoteFolderName .. "' was not found within 10 seconds. The server setup did not complete. Read the [AssemblyServer] messages in the Output window.")
	return
end
local Remote = {}
for _, name in ipairs(Config.RemoteNames) do
	local event = remotes:WaitForChild(name, 10)
	if event == nil or not event:IsA("RemoteEvent") then
		warn("[InteractionController] RemoteEvent '" .. name .. "' is missing or is not a RemoteEvent. Read the [AssemblyServer] messages in the Output window.")
		return
	end
	Remote[name] = event
end

local workshopsFolder = Workspace:WaitForChild("Workshops", 15)
local workshop = workshopsFolder and workshopsFolder:WaitForChild(tostring(LocalPlayer.UserId), 15)
if workshop == nil then
	warn("[InteractionController] Workshop not found for this player. Check the server setup and the Output window.")
	return
end

local COS_LIMIT = PlacementRules.cosLimit(Config.SnapAngleDegrees)
local INSTALL_CFG = { installReach = Config.InstallReachStuds, cosLimit = COS_LIMIT }
local BENCH_HALF = Config.BenchHalfExtents
local SELECT_COLOR = Color3.fromRGB(80, 150, 255)
local GHOST_COLORS = {
	snap = Color3.fromRGB(70, 220, 110),
	free = Color3.fromRGB(120, 170, 255),
	invalid = Color3.fromRGB(235, 70, 70),
}
local DRAG_ACTION = "PCBuilderDragSink"

local lang = Config.DefaultLanguage
if string.sub(LocalPlayer.LocaleId or "", 1, 2) == "ar" then
	lang = "ar"
end

local function tr(key)
	return Locale.text(lang, key)
end

local function describeCode(code, params)
	return Locale.describe(lang, code, params, Catalog)
end

-- ---------- HUD: top bar, order line, message, buttons, diagnostics panel ----------

local hud = Instance.new("ScreenGui")
hud.Name = "AssemblyHUD"
hud.ResetOnSpawn = false
hud.Parent = LocalPlayer:WaitForChild("PlayerGui")

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(0.96, 0, 0, 36)
topBar.Position = UDim2.new(0.02, 0, 0, 6)
topBar.BackgroundTransparency = 1
topBar.Parent = hud

local walletLabel = Instance.new("TextLabel")
walletLabel.Name = "Wallet"
walletLabel.Size = UDim2.new(0.6, 0, 1, 0)
walletLabel.Position = UDim2.new(0, 0, 0, 0)
walletLabel.BackgroundTransparency = 0.35
walletLabel.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
walletLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
walletLabel.TextScaled = true
walletLabel.Font = Enum.Font.GothamBold
walletLabel.Parent = topBar

local langButton = Instance.new("TextButton")
langButton.Name = "LanguageButton"
langButton.Size = UDim2.new(0, 110, 1, 0)
langButton.BackgroundColor3 = Color3.fromRGB(45, 45, 70)
langButton.TextColor3 = Color3.new(1, 1, 1)
langButton.TextScaled = true
langButton.Font = Enum.Font.GothamBold
langButton.Parent = topBar

local orderLabel = Instance.new("TextLabel")
orderLabel.Name = "Order"
orderLabel.Size = UDim2.new(0.96, 0, 0, 26)
orderLabel.Position = UDim2.new(0.02, 0, 0, 46)
orderLabel.BackgroundTransparency = 0.35
orderLabel.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
orderLabel.TextColor3 = Color3.new(1, 1, 1)
orderLabel.TextScaled = true
orderLabel.Font = Enum.Font.GothamMedium
orderLabel.Parent = hud

local message = Instance.new("TextLabel")
message.Name = "Message"
message.Size = UDim2.new(0.92, 0, 0, 124)
message.Position = UDim2.new(0.04, 0, 0, 78)
message.BackgroundTransparency = 0.35
message.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
message.TextColor3 = Color3.new(1, 1, 1)
message.TextWrapped = true
message.TextYAlignment = Enum.TextYAlignment.Top
message.TextSize = 15
message.Font = Enum.Font.GothamMedium
message.Parent = hud

local bar = Instance.new("Frame")
bar.Name = "ButtonBar"
bar.Size = UDim2.new(0.96, 0, 0, 64)
bar.Position = UDim2.new(0.02, 0, 1, -76)
bar.BackgroundTransparency = 1
bar.Parent = hud

local barLayout = Instance.new("UIListLayout")
barLayout.FillDirection = Enum.FillDirection.Horizontal
barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
barLayout.Padding = UDim.new(0.01, 0)
barLayout.Parent = bar

local buttons = {}
local function addButton(key, onClick)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0.13, 0, 1, 0)
	button.BackgroundColor3 = Color3.fromRGB(35, 60, 110)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Parent = bar
	button.Activated:Connect(onClick)
	table.insert(buttons, { button = button, key = key })
end

local diag = Instance.new("Frame")
diag.Name = "Diagnostics"
diag.Size = UDim2.new(0.92, 0, 0.72, 0)
diag.Position = UDim2.new(0.04, 0, 0.14, 0)
diag.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
diag.BackgroundTransparency = 0.05
diag.Visible = false
diag.ZIndex = 10
diag.Parent = hud

local diagTitle = Instance.new("TextLabel")
diagTitle.Name = "Title"
diagTitle.Size = UDim2.new(1, -16, 0, 34)
diagTitle.Position = UDim2.new(0, 8, 0, 6)
diagTitle.BackgroundTransparency = 1
diagTitle.TextColor3 = Color3.new(1, 1, 1)
diagTitle.TextScaled = true
diagTitle.Font = Enum.Font.GothamBold
diagTitle.ZIndex = 11
diagTitle.Parent = diag

local diagList = Instance.new("ScrollingFrame")
diagList.Name = "List"
diagList.Size = UDim2.new(1, -16, 1, -100)
diagList.Position = UDim2.new(0, 8, 0, 44)
diagList.BackgroundTransparency = 1
diagList.BorderSizePixel = 0
diagList.ScrollBarThickness = 6
diagList.CanvasSize = UDim2.new(0, 0, 0, 0)
diagList.AutomaticCanvasSize = Enum.AutomaticSize.Y
diagList.ZIndex = 11
diagList.Parent = diag

local diagLayout = Instance.new("UIListLayout")
diagLayout.SortOrder = Enum.SortOrder.LayoutOrder
diagLayout.Padding = UDim.new(0, 6)
diagLayout.Parent = diagList

local diagClose = Instance.new("TextButton")
diagClose.Name = "Close"
diagClose.Size = UDim2.new(0.5, 0, 0, 40)
diagClose.Position = UDim2.new(0.25, 0, 1, -48)
diagClose.BackgroundColor3 = Color3.fromRGB(35, 60, 110)
diagClose.TextColor3 = Color3.new(1, 1, 1)
diagClose.TextScaled = true
diagClose.Font = Enum.Font.GothamBold
diagClose.ZIndex = 11
diagClose.Parent = diag
diagClose.Activated:Connect(function()
	diag.Visible = false
end)

-- Text shown in the message box. It is written only when it changes, to avoid relayout on every input event.
local shownText = nil
local lastPayload = nil
local lastLocalText = nil
local lastDiagnostics = {}

local function show(text)
	if text ~= shownText then
		shownText = text
		message.Text = text
	end
end

local function showPayload(payload)
	local msg, hint = describeCode(payload.code, payload.params)
	local text = msg
	if hint ~= "" then
		text = text .. " " .. hint
	end
	local diags = payload.diagnostics or {}
	for i = 1, math.min(#diags, 3) do
		local dm, dh = describeCode(diags[i].code, diags[i].params)
		text = text .. "\n- " .. dm
		if dh ~= "" then
			text = text .. " " .. dh
		end
	end
	if #diags > 3 then
		local more = string.gsub(tr("ui.more"), "{n}", tostring(#diags - 3))
		text = text .. "\n" .. more
	end
	show(text)
end

local function renderDiagnostics()
	local rtl = Locale.isRtl(lang)
	local align = rtl and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
	diagTitle.Text = tr("ui.diag_title")
	diagTitle.TextXAlignment = align
	diagClose.Text = tr("ui.close")
	for _, child in ipairs(diagList:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for i, d in ipairs(lastDiagnostics) do
		local msg, hint = describeCode(d.code, d.params)
		local row = Instance.new("TextLabel")
		row.LayoutOrder = i
		row.Size = UDim2.new(1, -12, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.BackgroundTransparency = 0.3
		row.BackgroundColor3 = Color3.fromRGB(28, 32, 46)
		row.TextColor3 = Color3.new(1, 1, 1)
		row.TextWrapped = true
		row.TextSize = 15
		row.Font = Enum.Font.GothamMedium
		row.TextXAlignment = align
		row.Text = (hint ~= "") and (msg .. "\n" .. hint) or msg
		row.ZIndex = 12
		row.Parent = diagList
	end
end

local function openDiagnostics(list)
	lastDiagnostics = list or {}
	renderDiagnostics()
	diag.Visible = true
end

-- Wallet and order line, read from the workshop attributes the server maintains.
local function refreshLabels()
	local amount = workshop:GetAttribute("Wallet") or 0
	walletLabel.Text = string.gsub(tr("ui.wallet"), "{amount}", tostring(amount))
	local order = nil
	local orderId = workshop:GetAttribute("OrderId")
	if orderId ~= nil then
		order = Catalog.Orders[orderId]
	end
	orderLabel.Text = Locale.orderLine(lang, order, workshop:GetAttribute("OrderDone") == true)
end

local function applyLanguage()
	local rtl = Locale.isRtl(lang)
	local align = rtl and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
	walletLabel.Position = rtl and UDim2.new(0.4, 0, 0, 0) or UDim2.new(0, 0, 0, 0)
	walletLabel.TextXAlignment = align
	langButton.Position = rtl and UDim2.new(0, 0, 0, 0) or UDim2.new(1, -110, 0, 0)
	langButton.Text = tr(lang == "ar" and "ui.lang_to_en" or "ui.lang_to_ar")
	orderLabel.TextXAlignment = align
	message.TextXAlignment = align
	for i, entry in ipairs(buttons) do
		entry.button.Text = tr(entry.key)
		entry.button.LayoutOrder = rtl and (#buttons - i + 1) or i
	end
	refreshLabels()
	if lastPayload ~= nil then
		showPayload(lastPayload)
	elseif lastLocalText ~= nil then
		show(lastLocalText)
	else
		show(tr("ui.start"))
	end
	if diag.Visible then
		renderDiagnostics()
	end
end

-- ---------- highlights and ghosts ----------

local selectionHighlight = Instance.new("Highlight")
selectionHighlight.Name = "SelectionHighlight"
selectionHighlight.FillTransparency = 0.6
selectionHighlight.OutlineColor = Color3.new(1, 1, 1)
selectionHighlight.Parent = workshop

local function highlightSelection(model, color)
	selectionHighlight.Adornee = model
	if model ~= nil and color ~= nil then
		selectionHighlight.FillColor = color
	end
end

local ghostFolder = Instance.new("Folder")
ghostFolder.Name = "AssemblyGhosts"
ghostFolder.Parent = Workspace

-- Client-only copy used for prediction. It has no instance attributes, so server lookups never find it.
local function makeGhost(model)
	local ghost = model:Clone()
	ghost.Name = "Ghost"
	ghost:SetAttribute("InstanceId", nil)
	ghost:SetAttribute("ComponentId", nil)
	ghost:SetAttribute("SlotId", nil)
	ghost:SetAttribute("Installed", nil)
	for _, part in ipairs(ghost:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Transparency = math.max(part.Transparency, 0.45)
		end
	end
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.Adornee = ghost
	highlight.Parent = ghost
	ghost.Parent = ghostFolder
	return ghost, highlight
end

-- The real part stays in place while it is held. Only the ghost moves.
local function setRealHidden(model, hidden)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

-- ---------- scene helpers ----------

local function modelFor(instanceId)
	for _, child in ipairs(workshop:GetChildren()) do
		if child:GetAttribute("InstanceId") == instanceId then
			return child
		end
	end
	return nil
end

local function instanceAt(screenPos)
	local ray = Camera:ScreenPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workshop }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if hit == nil then
		return nil
	end
	local node = hit.Instance
	while node ~= nil and node ~= workshop do
		local id = node:GetAttribute("InstanceId")
		if id ~= nil then
			return id
		end
		node = node.Parent
	end
	return nil
end

local function pointOnPlane(screenPos, planeY)
	local ray = Camera:ScreenPointToRay(screenPos.X, screenPos.Y)
	local dy = ray.Direction.Y
	if math.abs(dy) < 0.001 then
		return nil
	end
	local t = (planeY - ray.Origin.Y) / dy
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

local function listHas(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

-- Local mirror of the server state, read from replicated attributes. It only predicts. The server re-checks.
local function buildClientState()
	local state = { caseId = workshop:GetAttribute("CaseId"), slots = {}, instances = {}, screws = {} }
	for _, child in ipairs(workshop:GetChildren()) do
		local slotId = child:GetAttribute("SlotId")
		local instanceId = child:GetAttribute("InstanceId")
		if slotId ~= nil and instanceId ~= nil then
			state.slots[slotId] = instanceId
			state.instances[instanceId] = { componentId = child:GetAttribute("ComponentId"), slotId = slotId }
		end
	end
	return state
end

local function socketFor(slotId)
	local slot = Catalog.Slots[slotId]
	local owner = nil
	if slot.ownerSlot == nil then
		owner = workshop:FindFirstChild("Case")
	else
		for _, child in ipairs(workshop:GetChildren()) do
			if child:GetAttribute("SlotId") == slot.ownerSlot then
				owner = child
				break
			end
		end
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

-- Install points that accept this product kind. Board points exist only after the motherboard is installed.
local function socketCandidates(componentId)
	local comp = Catalog.Components[componentId]
	local list = {}
	if comp == nil then
		return list
	end
	for slotId, slot in pairs(Catalog.Slots) do
		if listHas(slot.accepts, comp.kind) then
			local socket = socketFor(slotId)
			if socket ~= nil then
				table.insert(list, {
					slotId = slotId,
					socketCF = socket.CFrame,
					pose = PlacementRules.poseFromVectors(socket.CFrame.Position, socket.CFrame.UpVector, socket.CFrame.LookVector),
				})
			end
		end
	end
	return list
end

-- Scene cache. Socket candidates and the state mirror are rebuilt only when something changed:
-- a pickup, a server reply, a finished placement, or a cancelled drag. Not on every input event.
local scene = { version = 0, state = nil, candidates = {} }

local function bumpScene()
	scene.version = scene.version + 1
	scene.state = nil
	scene.candidates = {}
end

local function currentState()
	if scene.state == nil then
		scene.state = buildClientState()
	end
	return scene.state
end

local function candidatesFor(componentId)
	local list = scene.candidates[componentId]
	if list == nil then
		list = socketCandidates(componentId)
		scene.candidates[componentId] = list
	end
	return list
end

-- Layout context for Decisions.free, in workshop coordinates. Same rules and data as the server's layoutFor.
-- Returns nil for a part without layout data.
local function freeLayout(h, cf)
	local entry = WorkshopLayout.Components[h.componentId]
	if entry == nil then
		return nil
	end
	local origin = workshop:GetPivot()
	local others = {}
	for _, child in ipairs(workshop:GetChildren()) do
		local otherId = child:GetAttribute("InstanceId")
		local otherComponent = child:GetAttribute("ComponentId")
		if otherId ~= nil and otherId ~= h.id and otherComponent ~= nil then
			local otherEntry = WorkshopLayout.Components[otherComponent]
			if otherEntry ~= nil then
				table.insert(others, {
					id = otherId,
					componentId = otherComponent,
					center = PlacementRules.point(origin:PointToObjectSpace(child:GetPivot().Position)),
					size = otherEntry.size,
				})
			end
		end
	end
	local caseBox = { center = PlacementRules.fromArray(WorkshopLayout.Case.center), size = WorkshopLayout.Case.size }
	local tableBox = { center = PlacementRules.fromArray(WorkshopLayout.Table.center), size = WorkshopLayout.Table.size }
	local candidate = {
		id = h.id,
		componentId = h.componentId,
		center = PlacementRules.point(origin:PointToObjectSpace(cf.Position)),
		size = entry.size,
	}
	return { candidate = candidate, others = others, caseBox = caseBox, surfaceY = WorkshopLayout.TableTopY, tableBox = tableBox }
end

-- Preview decision for the current drag pose. Returns { kind, slotId, socketCF, code, params }.
-- It calls the same shared decisions as the server (Decisions), so a green preview means the server accepts the drop.
local function evaluateDrop(h)
	local free = h.freeCF
	local posePt = PlacementRules.poseFromVectors(free.Position, free.UpVector, free.LookVector)
	local benchPt = PlacementRules.point(workshop:GetPivot().Position)
	local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local rootPt = rootPart and PlacementRules.point(rootPart.Position) or nil
	-- Snap: the nearest socket in range that passes the shared install decision. Taking only the nearest is not enough.
	local chosen, snapOk, snapCode, snapParams = PlacementRules.chooseSnap(candidatesFor(h.componentId), posePt.pos, Config.SnapRadiusStuds, function(c)
		return Decisions.install({
			state = currentState(),
			catalog = Catalog,
			componentId = h.componentId,
			instanceId = h.id,
			slotId = c.slotId,
			proposed = posePt,
			socket = c.pose,
			player = rootPt,
			benchOrigin = benchPt,
			benchHalf = BENCH_HALF,
			maxReach = Config.MaxInteractDistance,
			cfg = INSTALL_CFG,
		})
	end)
	if chosen ~= nil then
		if snapOk then
			return { kind = "snap", slotId = chosen.slotId, socketCF = chosen.socketCF }
		end
		return { kind = "invalid", code = snapCode, params = snapParams or {} }
	end
	-- Free placement on the bench: the same shared decision the server runs.
	local okFree, code, params = Decisions.free({
		player = rootPt,
		proposed = posePt,
		benchOrigin = benchPt,
		benchHalf = BENCH_HALF,
		maxReach = Config.MaxInteractDistance,
		layout = freeLayout(h, free),
	})
	if not okFree then
		return { kind = "invalid", code = code, params = params or {} }
	end
	return { kind = "free" }
end

local function previewText(st)
	if st.kind == "snap" then
		return string.gsub(tr("ui.preview_snap"), "{slot}", Locale.slotLabel(lang, st.slotId))
	elseif st.kind == "free" then
		return tr("ui.preview_free")
	end
	local msg, hint = describeCode(st.code, st.params)
	if hint ~= "" then
		msg = msg .. " " .. hint
	end
	return msg
end

local function selectionText(model)
	local componentId = model:GetAttribute("ComponentId")
	return string.gsub(tr("ui.selected_part"), "{part}", Locale.partLine(lang, componentId, Catalog))
end

-- ---------- drag: one pointer at a time, requests in a fixed order ----------

local pointer = PointerTracker.new()
local held = nil          -- one drag: { id, componentId, model, ghost, highlight, colorKind, baseRot, yaw, planeY, point, freeCF, input, startPx, pickedAt, seq, lastEval, stateConn }
local pending = {}        -- instanceId -> { ghost, model, final, deadline }: placements the server has not confirmed yet
local selectedId = nil

local function bindDragSink()
	ContextActionService:UnbindAction(DRAG_ACTION)
	ContextActionService:BindActionAtPriority(DRAG_ACTION, function()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.Touch)
end

local function unbindDragSink()
	ContextActionService:UnbindAction(DRAG_ACTION)
end

local function pointerKind(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		return "touch"
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseMovement then
		return "mouse"
	end
	return nil
end

local function refreshDrag()
	if held == nil then
		return nil
	end
	held.freeCF = CFrame.new(held.point) * held.baseRot * CFrame.Angles(0, held.yaw, 0)
	local st = evaluateDrop(held)
	held.lastEval = st
	local displayCF = held.freeCF
	if st.kind == "snap" then
		displayCF = st.socketCF
	end
	held.ghost:PivotTo(displayCF)
	if held.colorKind ~= st.kind then
		held.highlight.FillColor = GHOST_COLORS[st.kind] or GHOST_COLORS.invalid
		held.colorKind = st.kind
	end
	lastLocalText = previewText(st)
	show(lastLocalText)
	return st
end

local function finishPending(id)
	local p = pending[id]
	if p == nil then
		return
	end
	if p.ghost and p.ghost.Parent then
		p.ghost:Destroy()
	end
	if p.model and p.model.Parent then
		setRealHidden(p.model, false)
	end
	pending[id] = nil
	bumpScene()
end

local function disconnectHoldInput(h)
	if h.stateConn ~= nil then
		h.stateConn:Disconnect()
		h.stateConn = nil
	end
end

-- Ends the local drag completely: pointer, camera sink, ghost, and real part visibility.
local function cleanupHeld(h)
	disconnectHoldInput(h)
	unbindDragSink()
	PointerTracker.finish(pointer)
	if h.ghost and h.ghost.Parent then
		h.ghost:Destroy()
	end
	if h.model and h.model.Parent then
		setRealHidden(h.model, false)
	end
	if held == h then
		held = nil
	end
	bumpScene()
end

-- Performs the actions DragSequence returns. Each one is a single request or a single local step.
local function applyActions(h, actions)
	for _, action in ipairs(actions) do
		if action.type == "evaluate" then
			local st = refreshDrag() or { kind = "invalid", code = "TOO_FAR", params = {} }
			applyActions(h, DragSequence.resolve(h.seq, st))
		elseif action.type == "propose" then
			local poseCF = h.freeCF
			if action.slotId ~= "" then
				local snapCF = h.lastEval and h.lastEval.socketCF
					if snapCF == nil then
						cleanupHeld(h)
						show(describeCode("NO_SOCKET", {}))
						return
					end
					poseCF = snapCF
			end
			pending[h.id] = { ghost = h.ghost, model = h.model, final = nil, deadline = os.clock() + Config.PlacementTimeoutSec }
			if held == h then
				held = nil
			end
			Remote.ProposePlacement:FireServer(h.id, poseCF, action.slotId)
			lastLocalText = tr("ui.sent")
			show(lastLocalText)
		elseif action.type == "tap" then
			Remote.ReleaseHold:FireServer(h.id)
			cleanupHeld(h)
			highlightSelection(h.model, SELECT_COLOR)
			lastLocalText = selectionText(h.model)
			show(lastLocalText)
		elseif action.type == "release" then
			Remote.ReleaseHold:FireServer(h.id)
			cleanupHeld(h)
			if h.lastEval ~= nil then
				lastLocalText = previewText(h.lastEval)
				show(lastLocalText)
			end
		elseif action.type == "cancel" then
			cleanupHeld(h)
		end
	end
end

-- The pointer lifted or the touch ended. Only the pointer that started the drag can do this.
local function endPointer(input, kind)
	if held == nil then
		return
	end
	if not PointerTracker.acceptsEnd(pointer, input, kind) then
		return
	end
	PointerTracker.finish(pointer)
	local h = held
	disconnectHoldInput(h)
	unbindDragSink()
	local actions = DragSequence.release(h.seq)
	if h.seq.phase == "picking" then
		lastLocalText = tr("ui.waitingPickup")
		show(lastLocalText)
	end
	applyActions(h, actions)
end

-- The player's own way to end a drag. It is the same release as lifting the finger, and it works even if the
-- platform never reports the end of the touch. Only needed as a safety net, but it keeps the drag from getting stuck.
local function dropHeld()
	local h = held
	if h == nil then
		lastLocalText = tr("ui.holdFirst")
		show(lastLocalText)
		return
	end
	if PointerTracker.isActive(pointer) then
		PointerTracker.finish(pointer)
	end
	disconnectHoldInput(h)
	unbindDragSink()
	local actions = DragSequence.release(h.seq)
	if h.seq.phase == "picking" then
		lastLocalText = tr("ui.waitingPickup")
		show(lastLocalText)
	end
	applyActions(h, actions)
end

-- Starts a drag for one part. Returns false when the part is still being placed. The caller then ends the pointer.
local function beginHold(id, model, input, kind)
	if pending[id] ~= nil then
		lastLocalText = tr("ui.stillPending")
		show(lastLocalText)
		return false
	end
	local pivot = model:GetPivot()
	local ghost, highlight = makeGhost(model)
	held = {
		id = id,
		componentId = model:GetAttribute("ComponentId"),
		model = model,
		ghost = ghost,
		highlight = highlight,
		colorKind = nil,
		baseRot = pivot - pivot.Position,
		yaw = 0,
		planeY = pivot.Position.Y,
		point = pivot.Position,
		freeCF = pivot,
		input = input,
		startPx = Vector2.new(input.Position.X, input.Position.Y),
		pickedAt = os.clock(),
		seq = DragSequence.new(id, Config.DragThresholdPixels),
		lastEval = nil,
		stateConn = nil,
	}
	if kind == "touch" then
		-- The documented way to observe one touch: its InputObject changes to End when the finger lifts.
		held.stateConn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				endPointer(input, "touch")
			end
		end)
		bindDragSink()
	end
	setRealHidden(model, true)
	highlightSelection(nil)
	bumpScene()
	refreshDrag()
	lastLocalText = tr("ui.waitingPickup")
	show(lastLocalText)
	Remote.PickUp:FireServer(id)
	return true
end

local function rotateHeld(degrees)
	if held == nil then
		lastLocalText = tr("ui.holdFirst")
		show(lastLocalText)
		return
	end
	held.yaw = held.yaw + math.rad(degrees)
	refreshDrag()
end

-- ---------- server replies ----------

local function onPickupFeedback(payload)
	local h = held
	if h == nil or h.id ~= payload.instanceId then
		return -- an answer about a part the player is no longer holding
	end
	if payload.ok then
		applyActions(h, DragSequence.ack(h.seq, payload.instanceId, true))
	else
		applyActions(h, DragSequence.ack(h.seq, payload.instanceId, false))
		lastPayload = payload
		lastLocalText = nil
		showPayload(payload)
	end
end

local function onPlacementFeedback(payload)
	local p = pending[payload.instanceId]
	if p == nil then
		return
	end
	if payload.ok then
		p.final = payload.final
		p.deadline = os.clock() + Config.PlacementTimeoutSec
	else
		finishPending(payload.instanceId)
	end
end

Remote.Feedback.OnClientEvent:Connect(function(payload)
	bumpScene()
	if payload.kind == "pickup" then
		onPickupFeedback(payload)
		return
	end
	lastPayload = payload
	lastLocalText = nil
	if payload.kind == "placement" then
		onPlacementFeedback(payload)
	end
	showPayload(payload)
	if payload.kind == "boot" and not payload.ok and (payload.code == "BOOT_FAILED" or payload.code == "ORDER_NOT_MET") then
		openDiagnostics(payload.diagnostics)
	end
	refreshLabels()
end)

-- ---------- timers: pickup timeout, placement confirmation, lost parts ----------

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local h = held
	if h ~= nil then
		if h.model.Parent == nil then
			cleanupHeld(h)
			lastLocalText = tr("ui.gone")
			show(lastLocalText)
		elseif h.seq.phase == "picking" and now - h.pickedAt > Config.PickupTimeoutSec then
			applyActions(h, DragSequence.timeout(h.seq))
			lastLocalText = tr("ui.pickupTimeout")
			show(lastLocalText)
		end
	end
	for id, p in pairs(pending) do
		local done = false
		if p.final ~= nil and p.model.Parent ~= nil then
			local pivot = p.model:GetPivot()
			if (pivot.Position - p.final.Position).Magnitude < Config.ConfirmDistanceStuds then
				done = true
			end
		end
		if done or now > p.deadline then
			finishPending(id)
		end
	end
end)

-- ---------- input (touch and mouse) ----------

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	local isPress = input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
	if isPress then
		if held ~= nil then
			return -- a second finger or a second press does not start another drag
		end
		local kind = pointerKind(input)
		if not PointerTracker.begin(pointer, input, kind) then
			return
		end
		local id = instanceAt(Vector2.new(input.Position.X, input.Position.Y))
		if id == nil then
			PointerTracker.finish(pointer)
			selectedId = nil
			highlightSelection(nil)
			return
		end
		local model = modelFor(id)
		if model == nil then
			PointerTracker.finish(pointer)
			return
		end
		selectedId = id
		highlightSelection(model, SELECT_COLOR)
		if model:GetAttribute("Installed") then
			PointerTracker.finish(pointer)
			lastLocalText = selectionText(model) .. "\n" .. tr("ui.installedHint")
			show(lastLocalText)
			return
		end
		if not beginHold(id, model, input, kind) then
			PointerTracker.finish(pointer)
		end
	elseif input.KeyCode == Enum.KeyCode.Q then
		rotateHeld(-15)
	elseif input.KeyCode == Enum.KeyCode.E then
		rotateHeld(15)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if held == nil then
		return
	end
	local kind = pointerKind(input)
	if kind == nil or not PointerTracker.acceptsMove(pointer, input, kind) then
		return
	end
	local px = Vector2.new(input.Position.X, input.Position.Y)
	DragSequence.pointerMoved(held.seq, (px - held.startPx).Magnitude)
	local point = pointOnPlane(px, held.planeY)
	if point == nil then
		return
	end
	held.point = Vector3.new(point.X, held.planeY, point.Z)
	refreshDrag()
end)

UserInputService.InputEnded:Connect(function(input)
	if held == nil then
		return
	end
	local kind = pointerKind(input)
	if kind == nil then
		return
	end
	endPointer(input, kind)
end)

-- ---------- camera ----------

local closeUp = false
local function toggleCamera()
	closeUp = not closeUp
	if closeUp then
		local focus = workshop:GetPivot().Position
		local case = workshop:FindFirstChild("Case")
		if case ~= nil and case:IsA("Model") then
			focus = case:GetPivot().Position
		end
		Camera.CameraType = Enum.CameraType.Scriptable
		Camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 7, 10), focus)
	else
		Camera.CameraType = Enum.CameraType.Custom
	end
end

-- ---------- buttons and language ----------

addButton("ui.camera", toggleCamera)
addButton("ui.rotL", function()
	rotateHeld(-15)
end)
addButton("ui.rotR", function()
	rotateHeld(15)
end)
addButton("ui.drop", dropHeld)
addButton("ui.screw", function()
	if selectedId == nil then
		lastLocalText = tr("ui.selectFirst")
		show(lastLocalText)
		return
	end
	Remote.TightenScrew:FireServer(selectedId)
end)
addButton("ui.remove", function()
	if selectedId == nil then
		lastLocalText = tr("ui.selectInstalled")
		show(lastLocalText)
		return
	end
	Remote.RequestUninstall:FireServer(selectedId)
end)
addButton("ui.boot", function()
	Remote.RequestBoot:FireServer()
end)

langButton.Activated:Connect(function()
	lang = (lang == "ar") and "en" or "ar"
	applyLanguage()
end)

workshop:GetAttributeChangedSignal("Wallet"):Connect(refreshLabels)
workshop:GetAttributeChangedSignal("OrderDone"):Connect(refreshLabels)

applyLanguage()
