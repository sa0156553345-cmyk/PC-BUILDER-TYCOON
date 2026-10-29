-- Locale.lua
-- Place in: ReplicatedStorage > Shared (ModuleScript "Locale")
-- ALL translated text lives here. Codes, component ids, slot ids and protocol names never change with language.
-- PURE: no Roblox APIs. describe() takes the catalog as an argument.
-- Arabic text: Modern Standard Arabic. Brand names stay in Latin script. Arabic rendering is NOT TESTED IN ROBLOX STUDIO.

local Locale = {}

function Locale.isRtl(lang)
	return lang == "ar"
end

local UI = {
	en = {
		["ui.camera"] = "Camera",
		["ui.rotL"] = "Rotate -",
		["ui.rotR"] = "Rotate +",
		["ui.drop"] = "Drop",
		["ui.screw"] = "Screw",
		["ui.remove"] = "Remove",
		["ui.boot"] = "Boot",
		["ui.lang_to_ar"] = "عربي",
		["ui.lang_to_en"] = "English",
		["ui.start"] = "Tap a part to pick it up. Drag to move it, then release on a glowing socket to install.",
		["ui.selectFirst"] = "Tap a part first.",
		["ui.selectInstalled"] = "Tap an installed part first.",
		["ui.holdFirst"] = "Pick a part up first, then rotate it.",
		["ui.installedHint"] = "This part is installed. Use Screw or Remove.",
		["ui.more"] = "(+{n} more)",
		["ui.sent"] = "Sent. Waiting for the server...",
		["ui.preview_free"] = "Free placement on the bench. It will not be installed.",
		["ui.preview_snap"] = "Release to install in {slot}.",
		["ui.selected"] = "Selected. Drag it to move, or use the buttons.",
		["ui.waitingPickup"] = "Picking up...",
		["ui.stillPending"] = "This part is still being placed. Wait a moment.",
		["ui.pickupTimeout"] = "No answer from the server. Try again.",
		["ui.wallet"] = "Wallet: {amount}$",
		["ui.order_line"] = "Order: {order} · needs {ram} GB RAM, {storage} GB storage · {state}",
		["ui.order_open"] = "in progress",
		["ui.order_done"] = "complete",
		["ui.selected_part"] = "Selected: {part}",
		["ui.diag_title"] = "Boot diagnostics",
		["ui.close"] = "Close",
		["ui.gone"] = "That part is no longer in the workshop.",
	},
	ar = {
		["ui.camera"] = "الكاميرا",
		["ui.rotL"] = "تدوير -",
		["ui.rotR"] = "تدوير +",
		["ui.drop"] = "إفلات",
		["ui.screw"] = "شدّ برغي",
		["ui.remove"] = "إزالة",
		["ui.boot"] = "تشغيل",
		["ui.lang_to_ar"] = "عربي",
		["ui.lang_to_en"] = "English",
		["ui.start"] = "اضغط على قطعة لالتقاطها. اسحبها للتحريك، ثم أفلتها على مقبس مضيء لتركيبها.",
		["ui.selectFirst"] = "اضغط على قطعة أولاً.",
		["ui.selectInstalled"] = "اضغط على قطعة مُركّبة أولاً.",
		["ui.holdFirst"] = "التقط قطعة أولاً، ثم أدرها.",
		["ui.installedHint"] = "هذه القطعة مُركّبة. استخدم «شدّ برغي» أو «إزالة».",
		["ui.more"] = "(+{n} أخرى)",
		["ui.sent"] = "أُرسل الطلب. بانتظار تأكيد الخادم...",
		["ui.preview_free"] = "وضع حر على الطاولة. لن تُركَّب القطعة.",
		["ui.preview_snap"] = "أفلت للتركيب في {slot}.",
		["ui.selected"] = "تم تحديد القطعة. اسحبها للتحريك، أو استخدم الأزرار.",
		["ui.waitingPickup"] = "جارٍ الالتقاط...",
		["ui.stillPending"] = "هذه القطعة ما زالت قيد الوضع. انتظر لحظة.",
		["ui.pickupTimeout"] = "لم يصل ردّ من الخادم. حاول مرة أخرى.",
		["ui.wallet"] = "الرصيد: {amount}$",
		["ui.order_line"] = "الطلب: {order} · يحتاج {ram} غيغابايت ذاكرة و{storage} غيغابايت تخزين · {state}",
		["ui.order_open"] = "قيد التنفيذ",
		["ui.order_done"] = "مكتمل",
		["ui.selected_part"] = "المحدد: {part}",
		["ui.diag_title"] = "تشخيص التشغيل",
		["ui.close"] = "إغلاق",
		["ui.gone"] = "هذه القطعة لم تعد في الورشة.",
	},
}

-- Message templates. {name} placeholders are filled from params. "hint" is optional.
local CODES = {
	en = {
		UNKNOWN_COMPONENT = { msg = "Unknown part: {part}." },
		UNKNOWN_SLOT = { msg = "Unknown install point: {slot}." },
		ALREADY_INSTALLED = { msg = "{part} is already installed.", hint = "Remove it first to move it." },
		SLOT_OCCUPIED = { msg = "{slot} is already taken.", hint = "Remove the part in that spot first." },
		WRONG_PART_FOR_SLOT = { msg = "{part} does not fit this spot.", hint = "This spot takes: {kind}." },
		PARENT_NOT_INSTALLED = { msg = "Install the base part first.", hint = "Missing: {slot}." },
		FORMFACTOR_MISMATCH = { msg = "{part} ({formFactor}) does not fit this case.", hint = "This case supports: {caseForm}." },
		SOCKET_MISMATCH = { msg = "{part} does not fit this motherboard socket.", hint = "This board uses the {socket} socket." },
		RAM_TYPE_MISMATCH = { msg = "{part} is the wrong memory type for this board.", hint = "This board takes {ramType} memory." },
		CABLE_WRONG_PORT = { msg = "{part} goes to a different port.", hint = "Match the cable to the port label." },
		PSU_CABLE_UNAVAILABLE = { msg = "The power supply has no {cableType} cable.", hint = "Use a power supply that provides it." },
		HAS_DEPENDENTS = { msg = "Cannot remove {part} yet.", hint = "{other} depends on it. Remove that first." },
		NOT_INSTALLED = { msg = "Nothing is installed there." },
		NO_SCREWS_NEEDED = { msg = "{part} has no screws left to tighten." },
		NO_MOTHERBOARD = { msg = "No motherboard installed.", hint = "Mount the motherboard in the case." },
		NO_PSU = { msg = "No power supply installed.", hint = "Install it in the PSU bay." },
		NO_CPU = { msg = "No CPU installed.", hint = "Install a CPU on the motherboard." },
		NO_RAM = { msg = "No memory installed.", hint = "Install at least one memory module." },
		NO_STORAGE = { msg = "No storage drive installed.", hint = "The PC has nothing to boot from." },
		MISSING_CABLE = { msg = "Missing cable: {slot} is not connected.", hint = "Connect the matching cable." },
		SCREWS_INCOMPLETE = { msg = "{part} is loose ({have}/{need} screws).", hint = "Tighten all of its screws." },
		PSU_INSUFFICIENT = { msg = "Power supply too weak: needs about {needW}W, has {watts}W.", hint = "Install a stronger power supply." },
		ORDER_RAM_TOO_LOW = { msg = "The order needs {need}GB of RAM. This build has {have}GB.", hint = "Add more memory." },
		ORDER_STORAGE_TOO_SMALL = { msg = "The order needs {need}GB of storage. This build has {have}GB.", hint = "Install a larger drive." },
		INSTALLED = { msg = "{part} installed in {slot}." },
		PICKED_UP = { msg = "Picked up." },
		REMOVED = { msg = "{part} removed.", hint = "Its screws came out with it." },
		PLACED_FREE = { msg = "{part} placed on the bench." },
		SCREW_ADDED = { msg = "Screw {have}/{need} tightened on {part}." },
		NOT_HELD = { msg = "Pick the part up first." },
		NOT_IN_WORKSHOP = { msg = "That part is not in your workshop." },
		LOCKED_INSTALLED = { msg = "Installed parts are locked.", hint = "Use Screw or Remove." },
		TOO_FAR = { msg = "Too far away.", hint = "Walk closer to the bench." },
		OUT_OF_BOUNDS = { msg = "That spot is outside the workbench area." },
		NOT_ALIGNED = { msg = "Rotate the part to match the socket." },
		NO_SOCKET = { msg = "Socket missing in the workshop model.", hint = "Check the Studio setup." },
		RATE_LIMITED = { msg = "Too many requests.", hint = "Wait a moment." },
		BOOT_FAILED = { msg = "The PC does not boot.", hint = "Read the diagnostics below." },
		ORDER_NOT_MET = { msg = "The PC boots, but it does not meet the order yet." },
		ORDER_DONE = { msg = "{order} complete. +${payout}. Wallet: ${wallet}." },
		ORDER_ALREADY_DONE = { msg = "The PC boots. This order is already complete." },
		WORKSHOP_READY = { msg = "Workshop ready. Tap a part to pick it up." },
		WORKSHOP_NOT_SET = { msg = "The workshop is not set up yet (Studio setup missing)." },
		OVERLAPS_PART = { msg = "{part} would overlap another part.", hint = "Find an empty spot on the table." },
		OVERLAPS_CASE = { msg = "Parts cannot be placed inside the case.", hint = "Use a socket to install it." },
		BELOW_TABLE = { msg = "That spot is below the table top.", hint = "Lift the part above the table." },
		OFF_TABLE = { msg = "That spot is past the edge of the table.", hint = "Move the part back onto the table top." },
		REQUEST_INVALID = { msg = "That request was not valid.", hint = "Try the action again." },
	},
	ar = {
		UNKNOWN_COMPONENT = { msg = "قطعة غير معروفة: {part}." },
		UNKNOWN_SLOT = { msg = "نقطة تركيب غير معروفة: {slot}." },
		ALREADY_INSTALLED = { msg = "{part} مُركّبة بالفعل.", hint = "أزِلها أولاً لنقلها." },
		SLOT_OCCUPIED = { msg = "{slot} مشغول.", hint = "أزِل القطعة الموجودة في هذا الموضع أولاً." },
		WRONG_PART_FOR_SLOT = { msg = "{part} لا يناسب هذا الموضع.", hint = "هذا الموضع يستقبل: {kind}." },
		PARENT_NOT_INSTALLED = { msg = "ركّب القطعة الأساسية أولاً.", hint = "الناقص: {slot}." },
		FORMFACTOR_MISMATCH = { msg = "{part} ({formFactor}) لا يناسب هذا الهيكل.", hint = "هذا الهيكل يدعم: {caseForm}." },
		SOCKET_MISMATCH = { msg = "{part} لا يناسب مقبس هذه اللوحة الأم.", hint = "هذه اللوحة تستخدم المقبس {socket}." },
		RAM_TYPE_MISMATCH = { msg = "{part} من نوع ذاكرة غير مناسب لهذه اللوحة.", hint = "هذه اللوحة تستخدم ذاكرة {ramType}." },
		CABLE_WRONG_PORT = { msg = "{part} يُوصَل بمنفذ آخر.", hint = "طابِق الكابل مع اسم المنفذ." },
		PSU_CABLE_UNAVAILABLE = { msg = "مزود الطاقة لا يوفّر كابل {cableType}.", hint = "استخدم مزود طاقة يوفّره." },
		HAS_DEPENDENTS = { msg = "لا يمكن إزالة {part} الآن.", hint = "{other} تعتمد عليها. أزِلها أولاً." },
		NOT_INSTALLED = { msg = "لا توجد قطعة مُركّبة هنا." },
		NO_SCREWS_NEEDED = { msg = "لا توجد براغٍ متبقية لشدّها في {part}." },
		NO_MOTHERBOARD = { msg = "لا توجد لوحة أم مُركّبة.", hint = "ركّب اللوحة الأم في الهيكل." },
		NO_PSU = { msg = "لا يوجد مزود طاقة مُركّب.", hint = "ركّبه في حاضنته." },
		NO_CPU = { msg = "لا يوجد معالج مُركّب.", hint = "ركّب معالجاً على اللوحة الأم." },
		NO_RAM = { msg = "لا توجد ذاكرة مُركّبة.", hint = "ركّب وحدة ذاكرة واحدة على الأقل." },
		NO_STORAGE = { msg = "لا يوجد قرص تخزين مُركّب.", hint = "الجهاز لا يملك ما يقلع منه." },
		MISSING_CABLE = { msg = "كابل مفقود: {slot} غير متصل.", hint = "وصّل الكابل المناسب." },
		SCREWS_INCOMPLETE = { msg = "{part} غير مثبّتة جيداً ({have}/{need} براغٍ).", hint = "اشدّ جميع براغيها." },
		PSU_INSUFFICIENT = { msg = "مزود الطاقة ضعيف: يحتاج نحو {needW} واط، والمتوفر {watts} واط.", hint = "ركّب مزود طاقة أقوى." },
		ORDER_RAM_TOO_LOW = { msg = "الطلب يحتاج ذاكرة بسعة {need} غيغابايت، وهذا التجميع فيه {have} غيغابايت.", hint = "أضف ذاكرة." },
		ORDER_STORAGE_TOO_SMALL = { msg = "الطلب يحتاج تخزيناً بسعة {need} غيغابايت، وهذا التجميع فيه {have} غيغابايت.", hint = "ركّب قرصاً أكبر." },
		INSTALLED = { msg = "تم تركيب {part} في {slot}." },
		PICKED_UP = { msg = "تم الالتقاط." },
		REMOVED = { msg = "أُزيلت {part}.", hint = "أُزيلت براغيها معها." },
		PLACED_FREE = { msg = "وُضعت {part} على الطاولة." },
		SCREW_ADDED = { msg = "تم شدّ البرغي {have}/{need} في {part}." },
		NOT_HELD = { msg = "التقط القطعة أولاً." },
		NOT_IN_WORKSHOP = { msg = "هذه القطعة ليست في ورشتك." },
		LOCKED_INSTALLED = { msg = "القطع المُركّبة مقفلة.", hint = "استخدم «شدّ برغي» أو «إزالة»." },
		TOO_FAR = { msg = "بعيد جداً.", hint = "اقترب من طاولة العمل." },
		OUT_OF_BOUNDS = { msg = "هذا الموضع خارج منطقة طاولة العمل." },
		NOT_ALIGNED = { msg = "أدِر القطعة لتطابق المقبس." },
		NO_SOCKET = { msg = "المقبس غير موجود في نموذج الورشة.", hint = "راجع إعداد Studio." },
		RATE_LIMITED = { msg = "طلبات كثيرة جداً.", hint = "انتظر لحظة." },
		BOOT_FAILED = { msg = "الجهاز لا يقلع.", hint = "اقرأ التشخيص أدناه." },
		ORDER_NOT_MET = { msg = "الجهاز يقلع، لكنه لا يحقق الطلب بعد." },
		ORDER_DONE = { msg = "اكتمل طلب {order}. +{payout}$ الرصيد: {wallet}$." },
		ORDER_ALREADY_DONE = { msg = "الجهاز يقلع. هذا الطلب مكتمل بالفعل." },
		WORKSHOP_READY = { msg = "الورشة جاهزة. اضغط على قطعة لالتقاطها." },
		WORKSHOP_NOT_SET = { msg = "الورشة غير مُعدّة بعد (إعداد Studio ناقص)." },
		OVERLAPS_PART = { msg = "{part} سيتداخل مع قطعة أخرى.", hint = "ابحث عن مكان فارغ على الطاولة." },
		OVERLAPS_CASE = { msg = "لا يمكن وضع القطع داخل الهيكل.", hint = "استخدم مقبساً لتركيبها." },
		BELOW_TABLE = { msg = "هذا الموضع أسفل سطح الطاولة.", hint = "ارفع القطعة فوق الطاولة." },
		OFF_TABLE = { msg = "هذا الموضع خارج حافة الطاولة.", hint = "أعد القطعة إلى سطح الطاولة." },
		REQUEST_INVALID = { msg = "الطلب غير صالح.", hint = "أعد المحاولة." },
	},
}

local SLOTS = {
	en = {
		CASE_MB = "Motherboard mount", CASE_PSU = "PSU bay", MB_CPU = "CPU socket",
		MB_RAM1 = "RAM slot 1", MB_RAM2 = "RAM slot 2", MB_M2 = "M.2 slot",
		MB_PWR24 = "24-pin power port", MB_CPU8 = "CPU power port (8-pin)",
	},
	ar = {
		CASE_MB = "حامل اللوحة الأم", CASE_PSU = "حاضنة مزود الطاقة", MB_CPU = "مقبس المعالج",
		MB_RAM1 = "فتحة الذاكرة 1", MB_RAM2 = "فتحة الذاكرة 2", MB_M2 = "فتحة M.2",
		MB_PWR24 = "منفذ الطاقة 24 سن", MB_CPU8 = "منفذ طاقة المعالج (8 سن)",
	},
}

local KINDS = {
	en = { Case = "Case", PSU = "Power supply", Motherboard = "Motherboard", CPU = "CPU", RAM = "Memory", Storage = "Storage", Cable = "Cable" },
	ar = { Case = "هيكل", PSU = "مزود الطاقة", Motherboard = "اللوحة الأم", CPU = "المعالج", RAM = "الذاكرة", Storage = "التخزين", Cable = "كابل" },
}

local ORDERS = {
	en = { office_01 = "Office PC" },
	ar = { office_01 = "حاسوب مكتب" },
}

function Locale.text(lang, key)
	local table_ = UI[lang] or UI.en
	return table_[key] or UI.en[key] or key
end

function Locale.slotLabel(lang, slotId)
	return (SLOTS[lang] or SLOTS.en)[slotId] or tostring(slotId)
end

local function resolve(lang, name, value, catalog)
	if name == "part" or name == "other" then
		local comp = catalog and catalog.Components[value]
		if comp ~= nil then
			return comp.name
		end
		return tostring(value)
	elseif name == "slot" then
		return Locale.slotLabel(lang, value)
	elseif name == "kind" then
		return (KINDS[lang] or KINDS.en)[value] or tostring(value)
	elseif name == "order" then
		return (ORDERS[lang] or ORDERS.en)[value] or tostring(value)
	end
	return tostring(value)
end

-- Returns (message, hint). hint is "" when the code has none. Unknown codes never crash.
function Locale.describe(lang, code, params, catalog)
	local entry = (CODES[lang] or CODES.en)[code] or CODES.en[code]
	if entry == nil then
		return "[" .. tostring(code) .. "]", ""
	end
	params = params or {}
	local function fill(template)
		local out = string.gsub(template, "{(%w+)}", function(name)
			return resolve(lang, name, params[name], catalog)
		end)
		return out
	end
	local hint = ""
	if entry.hint ~= nil then
		hint = fill(entry.hint)
	end
	return fill(entry.msg), hint
end

-- Used by tests: every code known in one language must exist in the other.
local function specText(lang, comp)
	local ar = lang == "ar"
	if comp.kind == "CPU" then
		return (ar and "مقبس " or "Socket ") .. comp.socket .. " · " .. tostring(comp.tdp) .. (ar and " واط" or " W")
	elseif comp.kind == "Motherboard" then
		return comp.formFactor .. " · " .. comp.cpuSocket .. " · " .. comp.ramType
	elseif comp.kind == "RAM" then
		return tostring(comp.capacityGB) .. (ar and " غيغابايت " or " GB ") .. comp.ramType
	elseif comp.kind == "Storage" then
		return tostring(comp.capacityGB) .. (ar and " غيغابايت" or " GB")
	elseif comp.kind == "PSU" then
		return tostring(comp.watts) .. (ar and " واط" or " W")
	elseif comp.kind == "Case" then
		return table.concat(comp.formFactors, ", ")
	elseif comp.kind == "Cable" then
		return comp.cableType
	end
	return ""
end

-- One line describing a product: kind, name and its key spec. Brand and model names stay in Latin script.
function Locale.partLine(lang, componentId, catalog)
	local comp = catalog.Components[componentId]
	if comp == nil then
		return tostring(componentId)
	end
	local kind = (KINDS[lang] or KINDS.en)[comp.kind] or comp.kind
	local spec = specText(lang, comp)
	if spec == "" then
		return kind .. ": " .. comp.name
	end
	return kind .. ": " .. comp.name .. " (" .. spec .. ")"
end

-- The order status line. order is a catalog order entry. done is a boolean.
function Locale.orderLine(lang, order, done)
	if order == nil then
		return ""
	end
	local name = (ORDERS[lang] or ORDERS.en)[order.id] or order.id
	local state = Locale.text(lang, done and "ui.order_done" or "ui.order_open")
	local line = Locale.text(lang, "ui.order_line")
	line = string.gsub(line, "{order}", name)
	line = string.gsub(line, "{ram}", tostring(order.minRamGB))
	line = string.gsub(line, "{storage}", tostring(order.minStorageGB))
	line = string.gsub(line, "{state}", state)
	return line
end

function Locale.codeList(lang)
	local list = {}
	for code in pairs(CODES[lang] or {}) do
		table.insert(list, code)
	end
	table.sort(list)
	return list
end

function Locale.uiKeys(lang)
	local list = {}
	for key in pairs(UI[lang] or {}) do
		table.insert(list, key)
	end
	table.sort(list)
	return list
end

return Locale
