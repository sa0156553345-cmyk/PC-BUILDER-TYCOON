-- DragSequence.lua
-- Place in: ReplicatedStorage > Shared (ModuleScript "DragSequence")
-- PURE state machine for ONE drag. It fixes the ORDER of requests so that:
--   * a drop is never sent before the server has acknowledged the pickup,
--   * a short movement is a TAP (select only). A tap never installs anything,
--   * exactly one terminal decision is made per drag,
--   * an answer for a different part is ignored.
-- It makes no network calls. The client executes the actions it returns.
-- Lua 5.1 subset: loads under standard Lua for tests.

local DragSequence = {}

-- Phases: "picking" (PickUp sent, no answer yet), "holding" (acknowledged),
--         "awaiting_eval" (the drop needs the client's geometry check), "done" (terminal).

function DragSequence.new(instanceId, thresholdPx)
	return { id = instanceId, threshold = thresholdPx, phase = "picking", dragged = false, released = false }
end

-- Distance is measured from the press point, in pixels. Movement after release does not count.
function DragSequence.pointerMoved(seq, distancePx)
	if seq.released or seq.phase == "done" then
		return
	end
	if distancePx > seq.threshold then
		seq.dragged = true
	end
end

local function decide(seq)
	if not seq.dragged then
		seq.phase = "done"
		return { { type = "tap" } }
	end
	seq.phase = "awaiting_eval"
	return { { type = "evaluate" } }
end

-- The server's answer to the pickup. Answers for other parts are ignored.
function DragSequence.ack(seq, instanceId, ok)
	if seq.phase ~= "picking" or instanceId ~= seq.id then
		return {}
	end
	if not ok then
		seq.phase = "done"
		return { { type = "cancel" } }
	end
	seq.phase = "holding"
	if seq.released then
		return decide(seq)
	end
	return {}
end

-- Pointer released. Before the acknowledgement, the decision waits for it.
function DragSequence.release(seq)
	if seq.phase == "picking" then
		seq.released = true
		return {}
	end
	if seq.phase == "holding" then
		seq.released = true
		return decide(seq)
	end
	return {}
end

-- evaluation = { kind = "snap" | "free" | "invalid", slotId = ... } from the client's geometry check.
function DragSequence.resolve(seq, evaluation)
	if seq.phase ~= "awaiting_eval" then
		return {}
	end
	seq.phase = "done"
	if evaluation.kind == "snap" then
		return { { type = "propose", slotId = evaluation.slotId } }
	elseif evaluation.kind == "free" then
		return { { type = "propose", slotId = "" } }
	end
	return { { type = "release" } }
end

-- No pickup answer in time: release defensively. Any late answer is ignored from now on.
function DragSequence.timeout(seq)
	if seq.phase ~= "picking" then
		return {}
	end
	seq.phase = "done"
	return { { type = "release" } }
end

return DragSequence
