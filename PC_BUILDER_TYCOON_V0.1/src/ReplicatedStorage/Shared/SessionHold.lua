-- SessionHold.lua
-- Place in: ReplicatedStorage > Shared (ModuleScript "SessionHold")
-- PURE state for "which part this player is holding" on the server. One part at a time.
-- Rules that protect the player:
--   * pick replaces any earlier hold (the client never starts a second pick during a drag),
--   * release always takes effect, and is idempotent,
--   * every proposal ends the hold, whatever the outcome, so a rejected drop never leaves a part in hand.

local SessionHold = {}

function SessionHold.new()
	return { held = nil }
end

-- Returns the previously held id, or nil.
function SessionHold.pick(h, id)
	local previous = h.held
	h.held = id
	return previous
end

function SessionHold.heldId(h)
	return h.held
end

-- Clears the hold only if it is this part. Returns true when something was cleared.
function SessionHold.release(h, id)
	if id ~= nil and h.held == id then
		h.held = nil
		return true
	end
	return false
end

-- Called by every proposal. Returns true when the part was held (the proposal is for the held part).
function SessionHold.consume(h, id)
	local was = id ~= nil and h.held == id
	if was then
		h.held = nil
	end
	return was
end

return SessionHold
