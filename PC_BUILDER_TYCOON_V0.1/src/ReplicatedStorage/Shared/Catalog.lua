-- Catalog.lua
-- Place in: ReplicatedStorage > Shared (ModuleScript "Catalog")
-- Pure data. Product names are real and used only for identification. They imply no sponsorship or affiliation.
-- Specs were checked against public retailer and manufacturer pages. Sources: docs/COMPONENTS_AND_COMPATIBILITY.md.
-- Game rules are SIMPLIFIED approximations. They are not vendor compatibility guarantees.
-- Lua 5.1 subset: loads under standard Lua for tests.

local Catalog = {}

-- Install points. ownerSlot is the slot whose installed part carries this socket (nil = the case).
Catalog.Slots = {
	CASE_MB  = { accepts = { "Motherboard" }, requires = {} },
	CASE_PSU = { accepts = { "PSU" }, requires = {} },
	MB_CPU   = { accepts = { "CPU" }, requires = { "CASE_MB" }, ownerSlot = "CASE_MB" },
	MB_RAM1  = { accepts = { "RAM" }, requires = { "CASE_MB" }, ownerSlot = "CASE_MB" },
	MB_RAM2  = { accepts = { "RAM" }, requires = { "CASE_MB" }, ownerSlot = "CASE_MB" },
	MB_M2    = { accepts = { "Storage" }, requires = { "CASE_MB" }, ownerSlot = "CASE_MB" },
	MB_PWR24 = { accepts = { "Cable" }, requires = { "CASE_MB", "CASE_PSU" }, ownerSlot = "CASE_MB", cableType = "MB24" },
	MB_CPU8  = { accepts = { "Cable" }, requires = { "CASE_MB", "CASE_PSU" }, ownerSlot = "CASE_MB", cableType = "CPU8" },
}

-- Game approximation for the boot power check. Not vendor guidance. Uses base TDP only.
Catalog.PowerModel = {
	HeadroomWatts = 50,
	MotherboardWatts = 40,
	RamWattsPerStick = 5,
	StorageWatts = 5,
}

Catalog.Components = {
	case_corsair_4000d = {
		id = "case_corsair_4000d", name = "Corsair 4000D Airflow", kind = "Case",
		formFactors = { "ATX", "MATX", "ITX" }, screwsRequired = 0,
	},
	psu_corsair_rm550 = {
		id = "psu_corsair_rm550", name = "Corsair RM550", kind = "PSU",
		watts = 550, cables = { "MB24", "CPU8" }, screwsRequired = 4,
	},
	mb_asus_b760m = {
		id = "mb_asus_b760m", name = "ASUS PRIME B760M-A WIFI D4", kind = "Motherboard",
		formFactor = "MATX", cpuSocket = "LGA1700", ramType = "DDR4",
		requiredPorts = { "MB_PWR24", "MB_CPU8" }, screwsRequired = 6,
	},
	cpu_intel_i5_12400f = {
		id = "cpu_intel_i5_12400f", name = "Intel Core i5-12400F", kind = "CPU",
		socket = "LGA1700", tdp = 65, screwsRequired = 0,
	},
	cpu_amd_ryzen5_5600 = {
		id = "cpu_amd_ryzen5_5600", name = "AMD Ryzen 5 5600", kind = "CPU",
		socket = "AM4", tdp = 65, screwsRequired = 0,
	},
	ram_corsair_lpx_8_ddr4 = {
		id = "ram_corsair_lpx_8_ddr4", name = "Corsair Vengeance LPX 8GB DDR4-3200", kind = "RAM",
		ramType = "DDR4", capacityGB = 8, screwsRequired = 0,
	},
	ram_corsair_vengeance_8_ddr5 = {
		id = "ram_corsair_vengeance_8_ddr5", name = "Corsair Vengeance 8GB DDR5-5200", kind = "RAM",
		ramType = "DDR5", capacityGB = 8, screwsRequired = 0,
	},
	ssd_samsung_980_500 = {
		id = "ssd_samsung_980_500", name = "Samsung 980 500GB NVMe M.2", kind = "Storage",
		capacityGB = 500, screwsRequired = 0,
	},
	cable_rm550_mb24 = {
		id = "cable_rm550_mb24", name = "RM550 modular 24-pin cable", kind = "Cable",
		cableType = "MB24", screwsRequired = 0,
	},
	cable_rm550_cpu8 = {
		id = "cable_rm550_cpu8", name = "RM550 modular 8-pin CPU cable", kind = "Cable",
		cableType = "CPU8", screwsRequired = 0,
	},
}

-- The starter PC. "kit" is the correct build. "extras" are real but WRONG parts, so players learn from mistakes.
Catalog.StarterPC = {
	caseId = "case_corsair_4000d",
	orderId = "office_01",
	kit = {
		"psu_corsair_rm550", "mb_asus_b760m", "cpu_intel_i5_12400f", "ram_corsair_lpx_8_ddr4",
		"ssd_samsung_980_500", "cable_rm550_mb24", "cable_rm550_cpu8",
	},
	extras = { "cpu_amd_ryzen5_5600", "ram_corsair_vengeance_8_ddr5" },
}

-- The single customer order. Payout is decided and paid on the server only. Amount is a placeholder.
Catalog.Orders = {
	office_01 = { id = "office_01", minRamGB = 8, minStorageGB = 250, payout = 250 },
}

return Catalog
