-- Decisions.lua
-- Place in: ReplicatedStorage > Shared (ModuleScript "Decisions")
-- PURE. The one place where a placement is decided. The server uses it to decide, and the client uses it for the
-- green/red preview. Both pass the same inputs in the same order, so the preview cannot promise what the server refuses.

local AssemblyRules = require(script.Parent:WaitForChild("AssemblyRules"))
local PlacementRules = require(script.Parent:WaitForChild("PlacementRules"))

local Decisions = {}

-- Install into a socket. Order: rules, bench bounds, socket present, reach, alignment.
-- ctx: state, catalog, componentId, instanceId, slotId, proposed (pose), socket (pose or nil),
--      player (point or nil), benchOrigin, benchHalf, maxReach, cfg = { installReach, cosLimit }.
-- Returns ok, code, params.
function Decisions.install(ctx)
	local rulesOk, diag = AssemblyRules.validateInstall(ctx.state, ctx.catalog, ctx.componentId, ctx.instanceId, ctx.slotId)
	if not rulesOk then
		return false, diag.code, diag.params or {}
	end
	if not PlacementRules.inBounds(ctx.proposed.pos, ctx.benchOrigin, ctx.benchHalf) then
		return false, "OUT_OF_BOUNDS", {}
	end
	if ctx.socket == nil then
		return false, "NO_SOCKET", {}
	end
	if ctx.player == nil or not PlacementRules.inReach(ctx.player, ctx.socket.pos, ctx.maxReach) then
		return false, "TOO_FAR", {}
	end
	local poseOk, poseCode = PlacementRules.checkInstallPose(ctx.proposed, ctx.socket, ctx.cfg)
	if not poseOk then
		return false, poseCode, {}
	end
	return true, nil, {}
end

-- Free placement on the bench. Order: reach and bench bounds, then the layout rules (height, table, case, other parts).
-- ctx: player (point or nil), proposed (pose), benchOrigin, benchHalf, maxReach,
--      layout = nil (a part without a size, legacy) or { candidate, others, caseBox, surfaceY, tableBox }.
-- Returns ok, code, params.
function Decisions.free(ctx)
	if ctx.player == nil then
		return false, "TOO_FAR", {}
	end
	local poseOk, poseCode = PlacementRules.checkFreePose(ctx.proposed, ctx.player, ctx.benchOrigin, ctx.benchHalf, ctx.maxReach)
	if not poseOk then
		return false, poseCode, {}
	end
	local L = ctx.layout
	if L == nil then
		return true, nil, {}
	end
	local layoutOk, layoutCode, layoutParams = PlacementRules.checkFreeLayout(L.candidate, L.others, L.caseBox, L.surfaceY, L.tableBox)
	if not layoutOk then
		return false, layoutCode, layoutParams or {}
	end
	return true, nil, {}
end

return Decisions
