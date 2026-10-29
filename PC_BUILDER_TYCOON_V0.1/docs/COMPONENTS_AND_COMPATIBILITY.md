# Component Catalog and Compatibility Rules (V0.1)

Source files: `src/ReplicatedStorage/Shared/Catalog.lua` (data) and `AssemblyRules.lua` (rules).
Product names are real and used only for identification. No sponsorship or affiliation is implied. Trademarks belong to their owners.

## 1. Products used in the starter PC and the distractors
| ID | Product | Relevant specs used by the game | Public sources checked |
|---|---|---|---|
| `case_corsair_4000d` | Corsair 4000D Airflow (mid-tower) | Motherboard support: ATX, Micro-ATX, Mini-ITX, E-ATX | corsair.com product page (CC-9011200-WW): https://www.corsair.com/ww/es/p/pc-cases/cc-9011200-ww/4000d-airflow-tempered-glass-mid-tower-atx-case-black-cc-9011200-ww |
| `psu_corsair_rm550` | Corsair RM550 | 550 W, 80 PLUS Gold, fully modular; one 24-pin ATX and one 8-pin EPS/CPU connector | corsair.com RM550 page: https://www.corsair.com/ww/ko/p/psu/cp-9020053-na/rm-series-rm550-550-watt-80-plus-gold-certified-fully-modular-psu-cp-9020053-na ; BT Business Direct listing: https://www.businessdirect.bt.com/products/corsair-550w-rm550-rm-series-power-supply-cp-9020053-uk-8XVN.html |
| `mb_asus_b760m` | ASUS PRIME B760M-A WIFI D4 | Micro-ATX; LGA1700 socket; Intel B760; DDR4; 2× M.2; 24-pin + 8-pin power | Galaxus: https://galaxus.be/en/s1/product/asus-prime-b760m-a-wifi-d4-lga-1700-intel-b760-matx-motherboards-23621342 ; JIB listing (24+8 pin): https://www.jib.co.th/web/product/readProduct/57137/MAINBOARD--เมนบอร์ด--ASUS-PRIME-B760M-A-WIFI-D4--DDR4---SOCKET-LGA-1700---MICRO-ATX- |
| `cpu_intel_i5_12400f` | Intel Core i5-12400F | LGA1700; 6 cores; base power 65 W; supports DDR4 and DDR5 | TechPowerUp: https://techpowerup.com/cpu-specs/core-i5-12400f.c2550 ; JB Hi-Fi: https://www.jbhifi.com.au/products/intel-core-i5-12400f-6-core-lga-1700-cpu-processor-bx8071512400f |
| `ram_corsair_lpx_8_ddr4` | Corsair Vengeance LPX 8GB DDR4-3200 (CMK8GX4M1E3200C16) | DDR4; 1×8 GB; 288-pin DIMM; 3200 MHz; CL16 | Panacompu: https://www.panacompu.com/peru/en/product-information/corsair-vengeance-lpx-ram-memory-module-8gb-1x-8gb-288-pin-ddr4-ram-dimm-desktop-3200mhz-cl16 |
| `ssd_samsung_980_500` | Samsung 980 500GB (MZ-V8V500BW) | M.2 2280; PCIe 3.0 x4 NVMe; 500 GB | Samsung: https://www.samsung.com/au/memory-storage/nvme-ssd/980-500gb-nvme-pcie-gen-3-mz-v8v500bw |
| `cpu_amd_ryzen5_5600` | AMD Ryzen 5 5600 (**wrong on purpose**) | AM4 socket; 65 W TDP | TechPowerUp: https://techpowerup.com/cpu-specs/ryzen-5-5600.c2743 ; B&H: https://www.bhphotovideo.com/c/product/1695217-REG/amd_100_100000927box_ryzen_5_5600_3_5.html |
| `ram_corsair_vengeance_8_ddr5` | Corsair Vengeance DDR5-5200 8GB (CMK8GX5M1B5200C40) (**wrong on purpose**) | DDR5; 288-pin DIMM; 5200 MT/s; CL40 | Proshop: https://www.proshop.dk/RAM/Corsair-Vengeance-DDR5-5200-8GB-CL40-Single-Channel-1-pcs-Intel-XMP-Black/3429249 |

The two cables are modeled as separate parts that come from the RM550 kit. Real PSU cables are supplied with the power supply.

## 2. Install slots
| Slot | Accepts | Requires installed first | Owner (socket lives on) | Cable type |
|---|---|---|---|---|
| `CASE_MB` | Motherboard | none | Case | |
| `CASE_PSU` | PSU | none | Case | |
| `MB_CPU` | CPU | `CASE_MB` | Motherboard | |
| `MB_RAM1`, `MB_RAM2` | RAM | `CASE_MB` | Motherboard | |
| `MB_M2` | Storage | `CASE_MB` | Motherboard | |
| `MB_PWR24` | Cable | `CASE_MB`, `CASE_PSU` | Motherboard | MB24 |
| `MB_CPU8` | Cable | `CASE_MB`, `CASE_PSU` | Motherboard | CPU8 |

## 3. Rules and codes
Install and removal rules run as the player acts. Boot and order rules run when the player presses Boot.

| # | Rule | When | Code (params) |
|---|---|---|---|
| R1 | Slot accepts this kind of part | install | `WRONG_PART_FOR_SLOT` (part, slot, kind) |
| R2 | Slot is empty | install | `SLOT_OCCUPIED` (slot) |
| R3 | Part is not already installed | install | `ALREADY_INSTALLED` (part) |
| R4 | Required slots are filled | install | `PARENT_NOT_INSTALLED` (slot) |
| R5 | Board form factor fits the case | install | `FORMFACTOR_MISMATCH` (part, formFactor, caseForm) |
| R6 | CPU socket matches the board | install | `SOCKET_MISMATCH` (part, socket) |
| R7 | RAM type matches the board | install | `RAM_TYPE_MISMATCH` (part, ramType) |
| R8 | Cable type matches the port | install | `CABLE_WRONG_PORT` (part, slot) |
| R9 | PSU provides this cable type | install | `PSU_CABLE_UNAVAILABLE` (cableType) |
| R10 | Nothing installed depends on the removed part | remove | `HAS_DEPENDENTS` (part, other) |
| R11 | Screw count does not exceed the requirement | tighten | `NO_SCREWS_NEEDED` (part) |
| B1 | Motherboard installed | boot | `NO_MOTHERBOARD` |
| B2 | PSU installed | boot | `NO_PSU` |
| B3 | CPU installed | boot | `NO_CPU` |
| B4 | At least one RAM module | boot | `NO_RAM` |
| B5 | Storage drive installed | boot | `NO_STORAGE` |
| B6 | Every required port has its cable | boot | `MISSING_CABLE` (slot) |
| B7 | Every part has all its screws | boot | `SCREWS_INCOMPLETE` (part, have, need) |
| B8 | PSU watts at least the required watts | boot | `PSU_INSUFFICIENT` (needW, watts) |
| O2 | Total RAM at least the order minimum | order | `ORDER_RAM_TOO_LOW` (need, have) |
| O3 | Storage at least the order minimum | order | `ORDER_STORAGE_TOO_SMALL` (need, have) |

Placement rules (server and client preview, `PlacementRules.lua`): bench bounds, reach from the player, install distance (3 studs), alignment (15 degrees on both up and look vectors). Codes: `OUT_OF_BOUNDS`, `TOO_FAR`, `NOT_ALIGNED`.

## 4. Simplifications (game values, not vendor guarantees)
- **Power.** Required watts = 50 headroom + 40 per board + 5 per RAM module + 5 per drive + CPU **base** TDP. Turbo power is not modeled. With the starter parts the requirement is 165 W. The 550 W PSU passes. No real distractor triggers `PSU_INSUFFICIENT`, so that rule is tested with a fixture only.
- **Memory slots.** The board has 4 DIMM slots. The game models 2 of them.
- **M.2 slots.** The board has 2 M.2 slots. The game models 1.
- **Screws.** Counts (6 for the board, 4 for the PSU) are gameplay values. They are not taken from a manual.
- **Compatibility.** The rules check socket, RAM type, form factor, cable type and power only. They do not check cooler clearance, GPU length, BIOS support, or memory QVL lists.
- **Cables.** Modeled as separate parts. Power ports and cable types follow the board and PSU data above.
- **PSU CPU connector.** The RM550 listing used here shows one 8-pin EPS/CPU connector. Other sources disagree for other RM550x SKUs. Verify against the exact SKU before any release.

## 5. Starter PC and order
- **Correct kit (7):** `psu_corsair_rm550`, `mb_asus_b760m`, `cpu_intel_i5_12400f`, `ram_corsair_lpx_8_ddr4`, `ssd_samsung_980_500`, `cable_rm550_mb24`, `cable_rm550_cpu8`.
- **Wrong on purpose (2):** `cpu_amd_ryzen5_5600` (fails R6), `ram_corsair_vengeance_8_ddr5` (fails R7).
- **Order `office_01` "Office PC":** at least 8 GB RAM (O2), at least 250 GB storage (O3), and the boot test must pass. Payout 250 (placeholder).
