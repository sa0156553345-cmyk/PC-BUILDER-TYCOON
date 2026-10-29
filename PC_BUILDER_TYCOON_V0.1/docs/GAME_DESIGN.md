# PC BUILDER TYCOON: game design (V0.1, milestone 4)

Status tags: **[BUILT]** code exists and is tested outside Roblox where it can be. **[SCRIPTED]** code exists but has NOT run in Roblox. **[NOT BUILT]** not started.

## 1. Vision
A realistic PC assembly simulator with a small business layer: build PCs for customers, earn money, learn from mistakes.

## 2. Scope of this milestone
- One workshop per player, built by code: floor, table, open-fronted case with its sockets, a parts bin with nine products (seven correct, two wrong), and a power light. [SCRIPTED]
- One starter PC and one order ("Office PC": at least 8 GB RAM and 250 GB storage). Payout 250, a placeholder. [SCRIPTED]
- Bilingual interface (English and Arabic), with right-to-left layout for Arabic. [SCRIPTED]
- Not in scope: saving (DataStore, deferred by approval), a shop, several orders, art, sound.

## 3. Core loop
1. Read the order line at the top. It names the requirements and whether the order is in progress or complete.
2. Tap a product to see its line: kind, name and key spec (for example "CPU: Intel Core i5-12400F (Socket LGA1700 · 65 W)").
3. Drag it. The ghost follows the finger. The preview says where it would go and why it cannot go there.
4. Release on a green socket to install, on blue bench space to place it freely, or on red to cancel (the part stays where it was).
5. Connect the cables, tighten the screws (each tap adds one; the label shows the count), then press **Boot**.
6. The light turns green when the PC boots and red when it does not. A failed boot opens the diagnostics panel with every problem.
7. A PC that boots and meets the order completes it once. The wallet grows once. Boot again: nothing is paid twice.

## 4. Controls
| Action | Phone (touch) | PC (mouse / keyboard) | Status |
|---|---|---|---|
| Select | Tap a part | Click a part | [SCRIPTED] |
| Move | Press and drag; the ghost follows at once | Press and drag | [SCRIPTED] |
| A tap only selects | Movement at or below 8 px never installs or places | Same | [SCRIPTED] |
| Install | Release on a green socket (sent after the server confirms the pickup) | Same | [SCRIPTED] |
| Free placement | Release on blue bench space | Same | [SCRIPTED] |
| Cancel | Release on red; the part stays where it was | Same | [SCRIPTED] |
| Drop | **Drop** button ends a drag through the normal release | Same | [SCRIPTED] |
| Rotate | Rotate - / Rotate + | Q / E | [SCRIPTED] |
| Screw, Remove | Buttons, after selecting | Same | [SCRIPTED] |
| Boot | Boot button | Same | [SCRIPTED] |
| Camera | Toggle close-up | Same | [SCRIPTED] |
| Language | EN / AR button | Same | [SCRIPTED] |

While a touch drags a part, the camera should not rotate with it (camera sink). UNVERIFIED on device.

## 5. Placement states (the preview)
- **Green:** over a socket that accepts the part, aligned within 15 degrees, in reach. Release installs it.
- **Blue:** free placement on the bench. It is on the table, not inside the case, and does not overlap another part.
- **Red:** invalid, with the reason. Reasons: wrong part for the spot, socket or RAM type mismatch, wrong cable port, missing base part, not aligned, too far, outside the bench, below the table, past the table edge, inside the case, overlapping another part.

The preview uses the same rules as the server. The server decides and can still reject.

## 6. Boot, order and money
- Boot checks every rule and reports every problem at once: motherboard, PSU, CPU, memory, storage, each required cable, every screw, power.
- The light: grey idle, green booted, red failed.
- The order checks RAM and storage after the boot passes.
- Money is paid by the server only, once per order.

## 7. Layout (placeholder)
- The table is 44 x 13 studs. The case is 12 x 12 x 9, open at the front and top.
- The player stands at a fixed point 7 studs in front of the table. Every bin spot and every socket is within 18 studs of that point.
- The motherboard has its own bin spot because it is 10 studs wide.

## 8. Open decisions
1. Currency name and the payout value (250 is a placeholder).
2. Whether to show the Arabic product names (today: Latin brand names inside Arabic text).
3. When to approve saving (DataStore).
4. Whether the placeholder blocks should stay, or art should replace them.
