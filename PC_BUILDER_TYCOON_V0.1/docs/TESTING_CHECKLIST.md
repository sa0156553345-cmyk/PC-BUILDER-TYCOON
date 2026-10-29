# Testing checklist (V0.1, milestone 4)

**Read first.** Section A ran in this environment, outside Roblox. Everything else is **NOT RUN**. Studio-only items are marked NOT TESTED IN ROBLOX STUDIO, and device items NOT TESTED ON A PHONE.

## A. Executed in this environment (outside Roblox)
| Check | Command | Result |
|---|---|---|
| Lua syntax of all 17 files in `src/` (Lua 5.3 rules, not Luau) | `texlua tests/syntax_check.lua` | 17 of 17 pass, 0 errors |
| Pure logic: catalog, rules, placement geometry and free-placement layout, workshop layout and reach, rate limit, remote plan, drag ordering, pointer arbitration, request validation, hold rules, payout ledger, EN and AR messages | `texlua tests/run_pure_tests.lua` | **202 passed, 0 failed**, exit 0 |
| Static gates: module purity (14 modules), member names across modules, remote names on both sides, EN and AR parity of codes and keys, every code and key the scripts use is translated, require paths, declaration order (client 96 names, server 57, builder 9), rate limit before argument checks in each request handler, one shared placement decision for preview and server, no leftovers, no HTTP | `texlua tests/static_checks.lua` | **115 passed, 0 failed**, exit 0 |
| Earlier round (r4), by hand: 18 deliberate faults in temporary copies (13 in pure modules, 5 in the static gates); the harness was not kept | edit a copy, run the suite | **all 18 detected**; the real project stayed green |
| Mutation check (automated, r5): 15 deliberate faults, each planted in a fresh copy (10 in pure modules, 5 in the server and client wiring) | `texlua tests/mutation_check.lua` | **15 of 15 detected**; the real project is never changed |

r4 faults, for the record: second finger accepted for moves; second pointer allowed to start; long ids accepted; NaN accepted as a number; consume not clearing the hold; new pick not replacing the hold; repeated order paid again; fractional payouts accepted; overlap margin sign wrong; case interior not protected; bin spot moved out of reach; board socket moved off the board; duplicate folders accepted; untranslated code; member used but not defined; remote name typo; pure module calling a Roblox type; local used before declaration.

r5 faults, for the record: free placement past the table edge; a part exactly on the table edge refused; snap using only the nearest socket; install ignoring reach or bench bounds; free placement ignoring the table box; pose check ignoring the look vector; argument check before the rate limit; English OFF_TABLE message missing; AMD CPU accepted on the LGA1700 board; server argument check before the rate limit; server proposals without a rate limit; server installs bypassing Decisions; client snap using only the nearest socket; client proposing a snap without its socket.

**What section A does NOT prove:** that the server or client runs in Roblox; that the procedural workshop builds; that RemoteEvents are created in a real place; that replies arrive; that touch, the camera sink or the Drop button work on a phone; that Arabic renders; that the drag feels right; multiplayer; performance.

## B. Studio setup (NOT TESTED IN ROBLOX STUDIO)
- [ ] Roblox Studio is open on Windows or macOS.
- [ ] The place is empty, or the default Baseplate was deleted.
- [ ] `ReplicatedStorage/Shared` contains 14 ModuleScripts with exact names, including `Decisions` (see docs/STUDIO_SETUP.md).
- [ ] `ServerScriptService` contains the Script `AssemblyServer` and the ModuleScript `WorkshopBuilder`.
- [ ] `StarterPlayer/StarterPlayerScripts` contains the LocalScript `InteractionController`.
- [ ] Press Play. The Output window shows no `[AssemblyServer]` or `[InteractionController]` warning.
- [ ] `ReplicatedStorage/AssemblyRemotes` exists with the 7 RemoteEvents.
- [ ] Press Play again. The same folder is reused, nothing is duplicated.
- [ ] Delete one RemoteEvent, press Play: exactly that one is recreated.
- [ ] Add a second Folder named `AssemblyRemotes` at the top level: the server prints `DUPLICATE_FOLDER`, changes nothing, and the client prints its warning after 10 seconds.
- [ ] A Model named `AssemblyRemotes` at the top level: `NAME_TAKEN_BY_NON_FOLDER`, nothing created.
- [ ] A Folder where a RemoteEvent should be: `WRONG_REMOTE_CLASS`, nothing created.
- [ ] The character appears on the floor in front of the table, facing the case.
- [ ] The workshop, table, case, sockets, nine bin products and the power light are all visible and labelled.

## C. Gameplay (NOT TESTED IN ROBLOX STUDIO)
- [ ] Tap a bin part: it is selected, its line (kind, name, key spec) appears, and it does not move or install.
- [ ] Press and drag: the ghost follows the finger at once.
- [ ] Over a green socket: the preview reads "Release to install in ...". Release: the part installs and its screw label appears if it needs screws.
- [ ] Over the wrong socket (the AMD CPU over the CPU socket): red, SOCKET_MISMATCH, with the socket named. Release: the part stays put, nothing is sent.
- [ ] The DDR5 module over a RAM slot: red, RAM_TYPE_MISMATCH.
- [ ] With the first RAM slot filled, drag a second module close to the first slot: the preview turns green on the free second slot, not red.
- [ ] A part rotated 90 degrees over a socket: red, NOT_ALIGNED. Rotate back: green.
- [ ] Release on the bench away from everything: blue, free placement, the part stays there. Not installed.
- [ ] Drag a part below the table top: red, BELOW_TABLE.
- [ ] Drag a part past the table's front or side edge, still above the table: red, OFF_TABLE. A part that only touches the edge is allowed.
- [ ] Drag a part into the case interior away from a socket: red, OVERLAPS_CASE.
- [ ] Drag a part onto another part on the table: red, OVERLAPS_PART, naming the other part.
- [ ] Drag a part far from the character: red, TOO_FAR. Release sends nothing.
- [ ] Press the Drop button during a drag: the drag ends through the normal release path.
- [ ] Tap, then press Drop with nothing held: "Hold a part first" style message.
- [ ] The cables install only after the PSU; a cable placed first shows PARENT_NOT_INSTALLED with the missing bay named.
- [ ] Tighten the screws with the Screw button: the label counts up to the requirement and stops.
- [ ] Remove the motherboard while the CPU is installed: HAS_DEPENDENTS, naming the CPU.
- [ ] Press Boot with a missing cable: the light turns red and the diagnostics panel lists every problem, with its close button working.
- [ ] Complete the starter build and press Boot: the light turns green, the order line shows "complete", the wallet shows 250$. Press Boot again: no second payment.
- [ ] Language button: Arabic layout mirrors, all labels and messages change, the last result is re-translated.
- [ ] Camera button: close-up on the case, and back to the default view.

## D. Mobile and device (NOT TESTED ON A PHONE)
- [ ] A drag that starts on a part keeps following the finger; lifting the finger drops it.
- [ ] A second finger tapping Rotate does not drop the part and does not move the ghost.
- [ ] While a part is held, the camera does not rotate with the same finger (camera sink, UNVERIFIED).
- [ ] If a drag ever stays open after the finger lifts, the Drop button ends it.
- [ ] The seven-button bar fits the screen, and the Roblox thumbstick does not cover it.
- [ ] Diagnostics text is readable, and the close button is reachable.
- [ ] Arabic text renders with the right font and direction (UNVERIFIED).

## E. Multiplayer and security (NOT TESTED, needs two players)
- [ ] Two players each see their own workshop; neither can pick up or place parts in the other's.
- [ ] A malformed id, a NaN position, or an unknown slot from a test client gets REQUEST_INVALID and changes nothing.
- [ ] A proposal without holding the part gets NOT_HELD.
- [ ] A rejected proposal releases the part, so the next pick works (regression).
- [ ] Twenty pickups in one second: only the allowed ones are processed.
- [ ] Malformed requests count toward the same limit: after the allowance is used, they are answered RATE_LIMITED.
- [ ] Repeated Boot after completion: ORDER_ALREADY_DONE, wallet unchanged.
- [ ] A player who leaves mid-build: their workshop is destroyed and the other player is unaffected.
- [ ] Parts are anchored and server-owned (check in Studio).

## F. Performance (NOT RUN)
- [ ] Dragging with all nine products on the table keeps a steady frame rate on a low-end phone.
- [ ] The socket candidates and layout checks run only on pickup, reply, placement or cancel (verify with a counter).
- [ ] Memory stays stable across several rebuilds in one session.
