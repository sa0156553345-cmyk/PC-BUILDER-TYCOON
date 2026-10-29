-- PointerTracker.lua
-- Place in: ReplicatedStorage > Shared (ModuleScript "PointerTracker")
-- PURE. Decides which pointer may drive a drag. Only one pointer is active at a time.
-- Touch: only the touch that started the drag can move or end it. Other fingers are ignored.
-- Mouse: any mouse movement moves the drag. Releasing the mouse button ends it.
-- A handle is an identity object. In Roblox it is the InputObject that began the press.

local PointerTracker = {}

function PointerTracker.new()
	return { active = nil }
end

-- Starts tracking. Returns false when another pointer is already active, or the kind is unknown.
function PointerTracker.begin(t, handle, kind)
	if t.active ~= nil then
		return false
	end
	if kind ~= "touch" and kind ~= "mouse" then
		return false
	end
	t.active = { handle = handle, kind = kind }
	return true
end

function PointerTracker.acceptsMove(t, handle, kind)
	local a = t.active
	if a == nil then
		return false
	end
	if a.kind == "mouse" then
		return kind == "mouse"
	end
	return kind == "touch" and handle ~= nil and handle == a.handle
end

function PointerTracker.acceptsEnd(t, handle, kind)
	local a = t.active
	if a == nil then
		return false
	end
	if a.kind == "mouse" then
		return kind == "mouse"
	end
	return kind == "touch" and handle ~= nil and handle == a.handle
end

function PointerTracker.finish(t)
	t.active = nil
end

function PointerTracker.isActive(t)
	return t.active ~= nil
end

return PointerTracker
