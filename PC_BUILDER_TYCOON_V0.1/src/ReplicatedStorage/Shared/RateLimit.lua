-- RateLimit.lua
-- Place in: ReplicatedStorage > Shared (ModuleScript "RateLimit")
-- PURE fixed-window limiter. The server creates one per player. Time is passed in, so it is testable.

local RateLimit = {}
RateLimit.__index = RateLimit

function RateLimit.new(limits)
	return setmetatable({ limits = limits, buckets = {} }, RateLimit)
end

-- Returns true if the action is allowed now. Unknown actions are always refused.
function RateLimit:allow(action, now)
	local limit = self.limits[action]
	if limit == nil then
		return false
	end
	local bucket = self.buckets[action]
	if bucket == nil or now - bucket.start >= 1 then
		self.buckets[action] = { start = now, count = 1 }
		return true
	end
	if bucket.count >= limit then
		return false
	end
	bucket.count = bucket.count + 1
	return true
end

return RateLimit
