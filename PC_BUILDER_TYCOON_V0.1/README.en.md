# PC BUILDER TYCOON: V0.1 (prototype, milestone 4)

A Roblox game about building PCs and running a workshop. The code now covers the whole play loop: select, drag, install, screws and cables, boot, order, wallet. It has **not been run yet inside Roblox Studio, and not on a real device**.

## 1. Honest status
- Checked outside Roblox: 202 pure-logic tests, 115 static checks, a syntax check of 17 files, and a mutation check (15 of 15 planted faults detected). All pass.
- Deliberate faults used to check that the tests catch errors: 15 in `tests/mutation_check.lua`, all detected. The 18 faults of the earlier round were checked by hand; their harness was not kept.
- Not tested: everything that runs inside Roblox (server, client, the generated workshop, looks, touch, Arabic rendering, multiplayer).
- Measured completion: about 55 of 100, using a rubric fixed before the score was computed. Details in `docs/COMPLETION_REPORT.md`. The 76% target cannot be measured as reached until Studio and device tests are run.

## 2. Major blocker: Roblox Studio does not run on Android
Roblox Studio runs only on Windows and macOS. This package cannot be run or tested from an Android phone alone. You need a computer for setup and testing.

## 3. What is new in milestone 4
- **A workshop built by code.** No manual modelling. The old templates still work if both exist.
- **Isolated touch.** Only the finger that began a drag can move or end it. The **Drop** button ends a drag through the same release, as a safety net.
- **Preview with reasons.** Green to install, blue for free placement, red with the reason (wrong socket, below the table, inside the case, overlapping a part).
- **A stricter server.** Every identifier, number and position is checked. Ownership is checked. Request rates are limited. A payout is made once per order.
- **Full diagnostics.** A panel lists every problem when a boot fails. A power light turns green or red. Screw counts show above each part. The wallet and order line show progress.
- **Bilingual.** Every message and label is translated. Arabic uses right-to-left alignment. Arabic rendering has not been tested in Roblox.
- **Quality gates.** `tests/static_checks.lua` checks names, translations, remote names and pure modules.

## 4. How to play
- Tap a part to select it. Its line shows its kind, name and key spec.
- Drag it. The ghost follows your finger at once.
- Release on a **green socket** to install it, on **blue bench space** to place it free, or on **red** to cancel. A red release does nothing and the reason is shown.
- Press **Drop** if a drag does not end on its own.
- Tighten screws with **Screw**, connect the cables, then press **Boot**.

## 5. Setting up in Roblox Studio
Full steps are in `docs/STUDIO_SETUP.md`. In short:
1. Create an empty place on Windows or macOS. Delete the Baseplate if there is one.
2. Create 14 ModuleScripts in `ReplicatedStorage/Shared`, named as their files, including `Decisions`.
3. Create a Script `AssemblyServer` and a ModuleScript `WorkshopBuilder` in `ServerScriptService`.
4. Create a LocalScript `InteractionController` in `StarterPlayer/StarterPlayerScripts`.
5. Press Play. Check that the Output window shows no `[AssemblyServer]` or `[InteractionController]` warning.

## 6. Running the tests outside Roblox
From the project root, with a Lua 5.3 interpreter (for example `texlua` from TeX Live):
```
texlua tests/syntax_check.lua
texlua tests/run_pure_tests.lua
texlua tests/static_checks.lua
```

## 7. Limits and documents
- `docs/KNOWN_LIMITATIONS.md`: the limits in full. The most important: nothing in Roblox has been run.
- `docs/TESTING_CHECKLIST.md`: what ran, and what did not.
- `docs/COMPLETION_REPORT.md`: the completion rubric and how it was computed.
- `docs/GAME_DESIGN.md` and `docs/ASSEMBLY_VALIDATION.md`: design and server validation.

## 8. Decisions needed from you
1. Currency name and the order payout (250 is a placeholder).
2. Whether Arabic text should keep Latin product names.
3. When to approve the saving design (DataStore).
4. Whether the coloured blocks stay as placeholders, or real art is added.
5. Who will open Studio and try the game on a phone (see section 2).
