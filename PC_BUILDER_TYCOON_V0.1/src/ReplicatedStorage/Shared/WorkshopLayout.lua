-- WorkshopLayout.lua
-- Place in: ReplicatedStorage > Shared (ModuleScript "WorkshopLayout")
-- PURE DATA. Placeholder workshop geometry in studs. The origin is the workshop origin at ground level.
-- Points and sizes are arrays {x, y, z}. Sizes are full extents. Geometry is PLACEHOLDER (plain blocks).
-- Replacing art later must keep these numbers consistent with the rules, or the tests will say so.
-- Lua 5.1 subset.

local L = {}

L.TableTopY = 3
L.Floor = { center = { 0, -0.5, 0 }, size = { 80, 1, 80 } }
L.Table = { center = { 0, 1.5, -1.5 }, size = { 44, 3, 13 } }

-- The case is open at the front and top. Its base rests on the table.
L.Case = { center = { 0, 9, -1.5 }, size = { 12, 12, 9 } }
L.CaseWalls = {
	{ center = { 0, 3.2, -1.5 }, size = { 12, 0.4, 9 } },
	{ center = { -5.8, 9, -1.5 }, size = { 0.4, 12, 9 } },
	{ center = { 5.8, 9, -1.5 }, size = { 0.4, 12, 9 } },
	{ center = { 0, 9, -5.8 }, size = { 12, 12, 0.4 } },
}

-- Case install points, absolute workshop coordinates.
L.CaseSockets = {
	CASE_MB = { 0, 9, -5.0 },
	CASE_PSU = { 0, 4.65, -4.0 },
}

-- Board install points, offsets from the motherboard centre (board-local).
L.BoardSockets = {
	MB_CPU = { -1.5, 2.8, 0.4 },
	MB_RAM1 = { 2.0, 2.0, 0.45 },
	MB_RAM2 = { 2.7, 2.0, 0.45 },
	MB_M2 = { -2.8, -2.5, 0.35 },
	MB_PWR24 = { 3.8, 3.5, 0.35 },
	MB_CPU8 = { 3.8, 1.0, 0.35 },
}

L.Light = { center = { 6.3, 13, 2.5 }, size = { 0.6, 0.6, 0.3 } }

-- The player stands here and faces the bench. Every interaction point must be in reach from here.
L.StandPoint = { 0, 3, 7 }
L.BenchFocus = { 0, 6, -1.5 }

-- Bin spots on the table as {x, z}. Spot i is for the i-th starter item (kit order, then extras).
-- Parts sit on the table, so their centre height is TableTopY + sizeY / 2.
L.BinSpots = {
	{ -11, -5 },    -- 1 PSU
	{ 12.5, -1 },   -- 2 motherboard: its own spot, because it is 10 studs wide
	{ -8.5, -1 },   -- 3 CPU (kit)
	{ -11, 2 },     -- 4 RAM (kit)
	{ -8.5, 2 },    -- 5 SSD (kit)
	{ -11, 4.5 },   -- 6 cable, 24-pin (kit)
	{ -8.5, 4.5 },  -- 7 cable, 8-pin CPU (kit)
	{ 8.5, 2 },     -- 8 CPU, wrong socket (extra)
	{ 11, 2 },      -- 9 RAM, wrong type (extra)
}

-- Placeholder geometry per product. Colours are RGB in 0..1. Labels are short, language-neutral model names.
L.Components = {
	case_corsair_4000d = { kind = "Case", size = { 12, 12, 9 }, color = { 0.12, 0.12, 0.14 }, label = "4000D" },
	psu_corsair_rm550 = { kind = "PSU", size = { 4, 2.5, 3 }, color = { 0.10, 0.10, 0.12 }, label = "RM550" },
	mb_asus_b760m = { kind = "Motherboard", size = { 10, 10, 0.4 }, color = { 0.10, 0.30, 0.20 }, label = "B760M" },
	cpu_intel_i5_12400f = { kind = "CPU", size = { 2.2, 2.2, 0.4 }, color = { 0.70, 0.72, 0.78 }, label = "i5-12400F" },
	cpu_amd_ryzen5_5600 = { kind = "CPU", size = { 2.2, 2.2, 0.4 }, color = { 0.70, 0.72, 0.78 }, label = "R5 5600" },
	ram_corsair_lpx_8_ddr4 = { kind = "RAM", size = { 0.5, 3, 0.5 }, color = { 0.20, 0.45, 0.85 }, label = "8GB DDR4" },
	ram_corsair_vengeance_8_ddr5 = { kind = "RAM", size = { 0.5, 3, 0.5 }, color = { 0.20, 0.45, 0.85 }, label = "8GB DDR5" },
	ssd_samsung_980_500 = { kind = "Storage", size = { 2.8, 0.9, 0.3 }, color = { 0.18, 0.18, 0.20 }, label = "980 500GB" },
	cable_rm550_mb24 = { kind = "Cable", size = { 0.5, 1.6, 0.3 }, color = { 0.92, 0.92, 0.92 }, label = "24-pin" },
	cable_rm550_cpu8 = { kind = "Cable", size = { 0.5, 1.6, 0.3 }, color = { 0.92, 0.92, 0.92 }, label = "8-pin CPU" },
}

return L
