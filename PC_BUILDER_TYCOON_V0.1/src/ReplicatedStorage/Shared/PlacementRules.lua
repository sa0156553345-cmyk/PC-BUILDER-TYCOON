-- PlacementRules.lua
-- Place in: ReplicatedStorage > Shared (ModuleScript "PlacementRules")
-- PURE geometry on plain tables {x, y, z}. No Roblox APIs. Server authoritative; client uses it for preview only.
-- Poses are { pos = point, up = point, look = point }. point() reads .X/.Y/.Z, so Vector3 values work directly.

local PlacementRules = {}

function PlacementRules.point(v)
	return { x = v.X, y = v.Y, z = v.Z }
end

function PlacementRules.poseFromVectors(pos, up, look)
	return { pos = PlacementRules.point(pos), up = PlacementRules.point(up), look = PlacementRules.point(look) }
end

function PlacementRules.distance(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function dot(a, b)
	return a.x * b.x + a.y * b.y + a.z * b.z
end

function PlacementRules.cosLimit(degrees)
	return math.cos(math.rad(degrees))
end

-- NaN fails every comparison, so NaN positions are rejected.
function PlacementRules.inBounds(pos, origin, half)
	return math.abs(pos.x - origin.x) <= half.x
		and math.abs(pos.y - origin.y) <= half.y
		and math.abs(pos.z - origin.z) <= half.z
end

function PlacementRules.inReach(player, pos, maxDist)
	return PlacementRules.distance(player, pos) <= maxDist
end

function PlacementRules.aligned(pose, target, cosLimit)
	return dot(pose.up, target.up) >= cosLimit and dot(pose.look, target.look) >= cosLimit
end

-- cfg = { installReach, cosLimit }. Returns true, or false plus a code.
function PlacementRules.checkInstallPose(pose, target, cfg)
	if not (PlacementRules.distance(pose.pos, target.pos) <= cfg.installReach) then
		return false, "TOO_FAR"
	end
	if not PlacementRules.aligned(pose, target, cfg.cosLimit) then
		return false, "NOT_ALIGNED"
	end
	return true, nil
end

function PlacementRules.checkFreePose(pose, playerPos, origin, half, maxDist)
	if not PlacementRules.inBounds(pose.pos, origin, half) then
		return false, "OUT_OF_BOUNDS"
	end
	if not PlacementRules.inReach(playerPos, pose.pos, maxDist) then
		return false, "TOO_FAR"
	end
	return true, nil
end

-- candidates: list of { slotId, pose }. Returns the nearest one within radius, or nil.
function PlacementRules.nearest(candidates, pos, radius)
	local best, bestD = nil, radius
	for _, c in ipairs(candidates) do
		local d = PlacementRules.distance(pos, c.pose.pos)
		if d <= bestD then
			best = c
			bestD = d
		end
	end
	return best
end

-- Snap target choice. candidates: list of { slotId, pose }, where pose is the socket pose. pos: the proposed point.
-- Each candidate within radius is tried from nearest to farthest with evaluate(candidate) -> ok, code, params.
-- Returns the first candidate that passes, as candidate, true, nil, {}. When none passes, returns the nearest
-- in-range candidate with its refusal, as candidate, false, code, params. When nothing is in range, returns nil.
function PlacementRules.chooseSnap(candidates, pos, radius, evaluate)
	local inRange = {}
	for _, c in ipairs(candidates) do
		local d = PlacementRules.distance(pos, c.pose.pos)
		if d <= radius then
			table.insert(inRange, { candidate = c, d = d })
		end
	end
	table.sort(inRange, function(a, b) return a.d < b.d end)
	local firstRefusal = nil
	for _, entry in ipairs(inRange) do
		local ok, code, params = evaluate(entry.candidate)
		if ok then
			return entry.candidate, true, nil, {}
		end
		if firstRefusal == nil then
			firstRefusal = { candidate = entry.candidate, code = code, params = params or {} }
		end
	end
	if firstRefusal ~= nil then
		return firstRefusal.candidate, false, firstRefusal.code, firstRefusal.params
	end
	return nil, false, nil, {}
end

-- Converts a layout array {x, y, z} into a point {x = , y = , z = }.
function PlacementRules.fromArray(a)
	return { x = a[1], y = a[2], z = a[3] }
end

local function overlapAxis(a, b, sa, sb, margin)
	return math.abs(a - b) < (sa + sb) / 2 - margin
end

-- Axis-aligned overlap in one shared space. Centres are points, sizes are arrays {x, y, z}.
-- margin lets touching boxes pass. NaN never overlaps, so callers check finiteness first.
function PlacementRules.boxesOverlap(centerA, sizeA, centerB, sizeB, margin)
	local m = margin or 0
	return overlapAxis(centerA.x, centerB.x, sizeA[1], sizeB[1], m)
		and overlapAxis(centerA.y, centerB.y, sizeA[2], sizeB[2], m)
		and overlapAxis(centerA.z, centerB.z, sizeA[3], sizeB[3], m)
end

-- True when the box bottom is at or above the surface, within tolerance.
function PlacementRules.bottomAbove(center, size, surfaceY, tolerance)
	return (center.y - size[2] / 2) >= surfaceY - tolerance
end

-- True when the box lies fully on the table top in x and z. A part may touch the table edge, not overhang it.
-- Height is checked separately by bottomAbove.
function PlacementRules.insideFootprint(center, size, tableCenter, tableSize)
	local hx, hz = size[1] / 2, size[3] / 2
	local tx, tz = tableSize[1] / 2, tableSize[3] / 2
	return center.x - hx >= tableCenter.x - tx
		and center.x + hx <= tableCenter.x + tx
		and center.z - hz >= tableCenter.z - tz
		and center.z + hz <= tableCenter.z + tz
end

-- candidate and others: { id, componentId, center = point, size = array }.
-- caseBox: { center = point, size = array } or nil.
-- tableBox: { center = point, size = array } or nil. When given, the part must stay on the table top (OFF_TABLE).
-- Returns true, or false with a code and params.
function PlacementRules.checkFreeLayout(candidate, others, caseBox, surfaceY, tableBox)
	if not PlacementRules.bottomAbove(candidate.center, candidate.size, surfaceY, 0.6) then
		return false, "BELOW_TABLE", {}
	end
	if tableBox ~= nil and not PlacementRules.insideFootprint(candidate.center, candidate.size, tableBox.center, tableBox.size) then
		return false, "OFF_TABLE", {}
	end
	if caseBox ~= nil and PlacementRules.boxesOverlap(candidate.center, candidate.size, caseBox.center, caseBox.size, 0.05) then
		return false, "OVERLAPS_CASE", {}
	end
	for _, other in ipairs(others) do
		if PlacementRules.boxesOverlap(candidate.center, candidate.size, other.center, other.size, 0.05) then
			return false, "OVERLAPS_PART", { part = other.componentId }
		end
	end
	return true, nil, {}
end

return PlacementRules
