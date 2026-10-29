-- RequestGuard.lua
-- Place in: ReplicatedStorage > Shared (ModuleScript "RequestGuard")
-- PURE checks for every argument a client can send. Malformed input is rejected before any state changes.
-- Points may be tables with x, y, z OR Vector3 values with X, Y, Z. Both are accepted.

local RequestGuard = {}

local MAX_ID_LENGTH = 64
local MAX_COORD = 1000000

function RequestGuard.isId(value)
	return type(value) == "string"
		and #value >= 1
		and #value <= MAX_ID_LENGTH
		and string.find(value, "^[%w_#]+$") ~= nil
end

-- Rejects NaN (n ~= n), infinities and absurdly large values.
function RequestGuard.isFiniteNumber(n)
	return type(n) == "number" and n == n and n > -MAX_COORD and n < MAX_COORD
end

function RequestGuard.isFinitePoint(p)
	if p == nil then
		return false
	end
	local ok, x, y, z = pcall(function()
		return p.X or p.x, p.Y or p.y, p.Z or p.z
	end)
	return ok and RequestGuard.isFiniteNumber(x) and RequestGuard.isFiniteNumber(y) and RequestGuard.isFiniteNumber(z)
end

function RequestGuard.isComponentId(value, catalog)
	return type(value) == "string" and catalog.Components[value] ~= nil
end

-- A slot id, or the empty string, which means free placement on the bench.
function RequestGuard.isSlotOrFree(value, catalog)
	if value == "" then
		return true
	end
	return type(value) == "string" and catalog.Slots[value] ~= nil
end

-- A pose is a position plus two direction vectors (pos, look, up). All three must be finite: a NaN orientation
-- reaches PivotTo just as a NaN position would. Points may be tables or Vector3 values.
function RequestGuard.isFinitePose(pose)
	if type(pose) ~= "table" then
		return false
	end
	return RequestGuard.isFinitePoint(pose.pos)
		and RequestGuard.isFinitePoint(pose.look)
		and RequestGuard.isFinitePoint(pose.up)
end

-- Every remote handler goes through here. The limiter runs first, so a malformed request also uses a token and
-- cannot flood the server with free replies. valid is the handler's own argument check.
-- Returns nil when the request may proceed, otherwise the code to reply with.
function RequestGuard.admit(limiter, action, now, valid)
	if not limiter:allow(action, now) then
		return "RATE_LIMITED"
	end
	if not valid then
		return "REQUEST_INVALID"
	end
	return nil
end

return RequestGuard
