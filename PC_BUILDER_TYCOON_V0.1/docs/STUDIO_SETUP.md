# Roblox Studio setup (V0.1, milestone 4)

**Requirement:** Roblox Studio runs only on Windows and macOS. It does not run on Android or iOS.
Nothing below has been run inside Roblox Studio by the author. See docs/TESTING_CHECKLIST.md.

## What changed for setup
- No hand-built models are needed. The workshop, the table, the case, the sockets and every product are built by code at runtime.
- Earlier versions asked you to build templates in ServerStorage. That path still works if BOTH templates exist, but it is no longer required.
- The place can start empty. A default Baseplate overlaps the workshop floor (both at height 0), so delete it or start from an empty place.

## Steps
1. Open Roblox Studio on Windows or macOS and create an empty place (or a Baseplate, then delete the Baseplate).
2. In **ReplicatedStorage**, create a **Folder** named exactly `Shared`. Inside it, create 14 **ModuleScripts**, each named exactly as its file, and paste the whole file into each:
   `Config`, `Catalog`, `AssemblyRules`, `PlacementRules`, `RateLimit`, `RemoteLayout`, `DragSequence`, `Locale`, `PointerTracker`, `RequestGuard`, `SessionHold`, `Ledger`, `WorkshopLayout`, `Decisions`.
3. In **ServerScriptService**:
   - create a **Script** named exactly `AssemblyServer` and paste `AssemblyServer.server.lua` into it;
   - create a **ModuleScript** named exactly `WorkshopBuilder` and paste `WorkshopBuilder.lua` into it.
4. In **StarterPlayer > StarterPlayerScripts**, create a **LocalScript** named exactly `InteractionController` and paste `InteractionController.client.lua` into it.
5. Press **Play**. Open the **Output** window.
   - Expected: no warning that starts with `[AssemblyServer]` or `[InteractionController]`.
   - If you see `Remote setup STOPPED`, a Folder or RemoteEvent with the same name already exists and conflicts. The message names the object. Fix it, then press Play again. Nothing was changed.
6. For two players, use Studio's **Test > Players** setting (or a local server with two clients). Each player gets their own workshop, 80 studs apart.

## Manual steps that remain (cannot be done by the code)
- Creating the 18 instances above (the `Shared` folder, 14 modules, the server Script, the builder module, the client LocalScript). The code cannot create its own scripts.
- Checking the layout visually in Studio (floor, table, case and labels). Geometry is placeholder.
- Choosing fonts, colours and sounds (none are included).
- Running the checklist on a phone (touch behaviour and layout are unverified).

## Common mistakes
- A name that differs by one letter or by case: the scripts will fail at `WaitForChild`.
- `WorkshopBuilder` placed in the wrong container. It must be a ModuleScript in ServerScriptService, next to the server Script.
- Pasting only part of a file. Each file must be pasted completely.
