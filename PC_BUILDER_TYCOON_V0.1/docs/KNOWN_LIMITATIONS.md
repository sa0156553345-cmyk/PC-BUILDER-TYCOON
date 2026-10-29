# Known limitations (V0.1, milestone 4)

Status words: **verified** means run automatically outside Roblox. **UNVERIFIED** means the code exists but was never run where it matters.

## Environment limits (the biggest ones)
1. **Roblox Studio has not been run.** Every server and client script, and the procedural workshop, is UNVERIFIED in Roblox.
2. **No real device.** Touch behaviour, the camera sink while dragging, the thumbstick overlap with the button bar, phone layout and text size are UNVERIFIED.
3. **No multiplayer test.** Per-player workshops, remote folder creation with two players, and cross-player isolation are UNVERIFIED.
4. **No performance test.** Frame cost of the scene cache, the layout checks and the socket search is unmeasured.
5. **The author works from an Android phone without a computer.** Roblox Studio cannot run there, so the team cannot test in Studio without a Windows or macOS computer.

## Touch and camera
6. **Touch identity.** The drag relies on Roblox giving one `InputObject` per finger for its lifetime (the documented pattern). If that is not true on a device, a drag can stay open. The **Drop** button is the player's way out.
7. **Camera.** While a touch drags a part, `ContextActionService` sinks touch input at high priority to stop the default camera rotating. This may also block other touch controls during the drag. UNVERIFIED.
8. **Second finger.** A second finger can still press buttons (Rotate, Drop). It cannot move the ghost or end the drag. UNVERIFIED on device.

## Interface
9. **Arabic.** Translations were written by the assistant. They need review by a native speaker. Rendering of Arabic text, font coverage and the right-to-left layout are UNVERIFIED in Roblox. Brand and model names stay in Latin script.
10. **Diagnostics panel** covers the bench while open. It is closed with its Close button.
11. **Labels** use short English model names on the placeholder blocks.

## Gameplay
12. **One order, one starter PC, one workshop.** No shop, no progression, no second order.
13. **Compatibility is simplified** (see COMPONENTS_AND_COMPATIBILITY.md). Socket, RAM type, form factor, cable type and power are checked. Coolers, GPUs, BIOS and memory lists are not.
14. **Power and screw counts are game values**, not manufacturer data.
15. **Two of four memory slots and one of two M.2 slots** are modelled.
16. **Free placement** uses axis-aligned boxes. A tilted part is approximated by its unrotated box, so overlap and the table edge can be slightly wrong near corners.
17. **Pending placement** waits for the server. On a slow connection the ghost stays visible longer, up to the 3-second timeout.

## Server and data
18. **Nothing is saved.** Wallet and completed orders live in server memory and are lost when the server stops. DataStore is deferred, as approved.
19. **Rate limits and timeouts are placeholders**, chosen without measurement.
20. **Legacy template path** is kept for compatibility. It has no layout checks, because its sizes are not known in advance.
21. **Overlap and reach values** (for example the 18-stud reach) are tuning guesses until tested on a device.

## Assets
22. **No art, sound, icons or custom fonts.** Geometry is generated blocks. This is deliberate: it removes the manual modelling step, but the game looks like a prototype.

## Testing tools
23. **The syntax checker uses Lua 5.3 rules, not Luau.** It catches syntax errors, not Roblox API misuse.
24. **The static checks use patterns, not a full parser.** They catch the classes of error in docs/TESTING_CHECKLIST.md section A. They do not prove the absence of other errors.
25. **Mutation checks.** `tests/mutation_check.lua` plants 15 faults, one at a time, in a copy of the project, and checks that a suite catches each one. It uses `cp`, `rm` and `/tmp`, so it runs on macOS and Linux; on Windows it needs adapting. The 18 faults of the earlier round were checked by hand, and their harness was not kept.

## Protocol
26. **The protocol does not rely on the order of different RemoteEvents.** The client waits for the pickup acknowledgement before sending a drop. Roblox's ordering guarantees across remotes are not verified.

## Audit r5 (added)
27. **Table geometry is defined twice.** `WorkshopLayout` (tested) and `WorkshopBuilder` (builds the table in Roblox, UNVERIFIED) must agree on the table's position and size. Nothing compares them automatically.
28. **Preview and server may see different neighbours.** The client builds the list of other parts from the workshop's children; the server builds it from its own part table. If replication lags, the two lists can differ for a moment, so a drop can be green in the preview and refused by the server. UNVERIFIED.
29. **Malformed requests use up the rate limit.** A player who sends malformed requests may be answered RATE_LIMITED where earlier versions answered REQUEST_INVALID. This is intended: it stops free flooding. The limits themselves are still placeholders (item 19).
30. **No type checker was run.** `luau-analyze` is not installed here and could not be installed without network access. A type checker would flag values used without a nil check. The client's proposal path now checks the snap socket by hand; nothing automated covers it.
31. **Bench box and table differ.** The bench box is 20 studs either side of its centre on X, and the table is 22. The outer 2 studs of the table on X cannot hold a free part. Recorded, not changed.
32. **Orientation is checked for validity, not for appearance.** The server rejects NaN and infinite orientations. Whether an unusual but valid orientation looks right on screen is not tested.
