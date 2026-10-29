-- WorkshopBuilder.lua
-- Place in: ServerScriptService (ModuleScript named "WorkshopBuilder")
-- Builds the workshop and every product at runtime from WorkshopLayout (pure data).
-- No manual modelling is needed in Studio. Geometry is PLACEHOLDER: labelled blocks.
-- Socket markers are faint and cannot be picked, so players can see where parts go.
-- STATUS: NOT YET RUN INSIDE ROBLOX STUDIO.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorkshopLayout = require(Shared:WaitForChild("WorkshopLayout"))

local WorkshopBuilder = {}

local function vec(a)
	return Vector3.new(a[1], a[2], a[3])
end

local function colorOf(a)
	return Color3.new(a[1], a[2], a[3])
end

local function newPart(name, size, cf, color, transparency, collide, query)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = collide
	p.CanQuery = query
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Transparency = transparency
	return p
end

local function socketMarker(slotId, centre)
	return newPart(slotId, Vector3.new(0.6, 0.6, 0.6), CFrame.new(vec(centre)), Color3.fromRGB(120, 255, 150), 0.7, false, false)
end

local function addLabel(host, text, heightAbove)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(120, 22)
	gui.StudsOffset = Vector3.new(0, heightAbove, 0)
	gui.MaxDistance = 40
	gui.Parent = host
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 0.25
	t.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.Text = text
	t.Parent = gui
end

-- One product as a Model whose PrimaryPart (the body) is centred on the model pivot.
-- A motherboard also gets its install points as child markers, in board-local offsets.
function WorkshopBuilder.buildComponent(componentId)
	local entry = WorkshopLayout.Components[componentId]
	if entry == nil then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = componentId
	local body = newPart("Body", vec(entry.size), CFrame.new(), colorOf(entry.color), 0, true, true)
	body.Parent = model
	model.PrimaryPart = body
	addLabel(body, entry.label, entry.size[2] / 2 + 1.2)
	if entry.kind == "Motherboard" then
		for slotId, centre in pairs(WorkshopLayout.BoardSockets) do
			socketMarker(slotId, centre).Parent = model
		end
	end
	return model
end

-- Where a product waits in the bin. spot is the table spot number (1-based). origin is the workshop origin.
function WorkshopBuilder.binHome(index, componentId, origin)
	local spot = WorkshopLayout.BinSpots[index]
	local entry = WorkshopLayout.Components[componentId]
	if spot == nil or entry == nil then
		return nil
	end
	local y = WorkshopLayout.TableTopY + entry.size[2] / 2
	return origin * CFrame.new(spot[1], y, spot[2])
end

-- The whole workshop: a pivot origin, floor, table, open-fronted case with its install points, and a power LED.
-- Returns the Model and the LED part (the server changes its colour to show the boot state).
function WorkshopBuilder.buildWorkshop()
	local ws = Instance.new("Model")
	ws.Name = "Workshop"
	local origin = newPart("Origin", Vector3.new(1, 1, 1), CFrame.new(), Color3.new(1, 1, 1), 1, false, false)
	origin.Parent = ws
	ws.PrimaryPart = origin

	local floor = WorkshopLayout.Floor
	newPart("Floor", vec(floor.size), CFrame.new(vec(floor.center)), Color3.fromRGB(56, 58, 66), 0, true, true).Parent = ws
	local tb = WorkshopLayout.Table
	newPart("Table", vec(tb.size), CFrame.new(vec(tb.center)), Color3.fromRGB(110, 74, 42), 0, true, true).Parent = ws

	local case = Instance.new("Model")
	case.Name = "Case"
	case.Parent = ws
	for i, wall in ipairs(WorkshopLayout.CaseWalls) do
		newPart("Wall" .. i, vec(wall.size), CFrame.new(vec(wall.center)), Color3.fromRGB(34, 36, 44), 0, true, true).Parent = case
	end
	for slotId, centre in pairs(WorkshopLayout.CaseSockets) do
		socketMarker(slotId, centre).Parent = case
	end

	local light = WorkshopLayout.Light
	local led = newPart("PowerLED", vec(light.size), CFrame.new(vec(light.center)), Color3.fromRGB(120, 120, 120), 0, false, true)
	led.Parent = ws
	return ws, led
end

return WorkshopBuilder
