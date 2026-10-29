-- Ledger.lua
-- Place in: ReplicatedStorage > Shared (ModuleScript "Ledger")
-- PURE. Pays each order once. The wallet only grows through complete(), and complete() refuses repeats.
-- In V0.1 this lives in server memory only. Saving (DataStore) is deferred.

local Ledger = {}

function Ledger.new()
	return { balance = 0, completed = {} }
end

-- Returns true, "PAID" on the first valid completion.
-- Returns false, "ALREADY_PAID" for a repeat, and false, "INVALID" for a bad order id or payout.
function Ledger.complete(l, orderId, payout)
	if type(orderId) ~= "string" or orderId == "" then
		return false, "INVALID"
	end
	if type(payout) ~= "number" or payout ~= payout or payout <= 0 or payout > 1000000 or payout ~= math.floor(payout) then
		return false, "INVALID"
	end
	if l.completed[orderId] then
		return false, "ALREADY_PAID"
	end
	l.completed[orderId] = true
	l.balance = l.balance + payout
	return true, "PAID"
end

function Ledger.isComplete(l, orderId)
	return l.completed[orderId] == true
end

function Ledger.balanceOf(l)
	return l.balance
end

return Ledger
