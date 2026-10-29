# Audit r5 (V0.1, milestone 4)

**Status:** the fixes below are in the code, and every check that can run outside Roblox passes. Nothing here ran inside Roblox Studio or on a device.

## 1. Scope and method
- Scope: the authoritative server (`AssemblyServer.server.lua`), the client preview and drop logic (`InteractionController.client.lua`), and the pure shared modules they use.
- Starting point: the r4 project, copied to a backup before this audit began.
- Method: read the server and client line by line. Confirm each suspected defect with a probe that calls the real pure functions. Write regression tests that encode each defect before fixing it, and confirm they fail on the r4 code. Fix. Re-run every check. Finally, plant each fault back into a copy of the project and confirm that a suite catches it.
- The probe scripts ran from `/tmp` and are not part of the project. The regression tests encode the same cases.

## 2. Defects

| ID | Defect in r4 | Evidence | Fix | Tests |
|---|---|---|---|---|
| D1 | A free-placed part could overhang the table edge. The layout rule checked height, case and other parts, but not the table footprint. | Probe: a part centred at z = 10, with the table's front edge at z = 5, was accepted. | `PlacementRules.insideFootprint`. `checkFreeLayout` takes an optional table box and returns `OFF_TABLE`. Server and client both pass the table box. Messages added in English and Arabic. | audit 1 |
| D2 | The snap chose the nearest socket and validated only that one. A free socket in range was never considered. | Probe: MB_RAM1 was occupied and nearest. MB_RAM2 was free, 0.9 studs away, inside the 2.5-stud radius. The preview showed red SLOT_OCCUPIED. | `PlacementRules.chooseSnap` tries in-range sockets from nearest to farthest. It reports the nearest refusal only when none passes. | audit 2 |
| D3 | The preview did not check reach or bench bounds for snaps. A green preview could be refused by the server with TOO_FAR. | Probe with a valid build state: rules passed, alignment passed, and the reach check failed for a player 60 studs away. (A first probe had an empty build state, so its result was wrong. It was corrected and re-run.) | One shared decision, `Decisions.install` (rules, bounds, socket, reach, alignment), used by the server and the preview. `Decisions.free` covers free placement. | audit 3, audit 6 |
| D4 | Only the position of a proposed pose was checked. A NaN or infinite orientation could reach `PivotTo`. | Code reading: the argument check tested `pose.Position` only. | `RequestGuard.isFinitePose` checks the position, the look vector and the up vector. | audit 4 |
| D5 | Malformed requests were answered before the rate limit ran. A flood of malformed requests used no quota and got a free reply each time. | Code reading of PickUp, ProposePlacement, RequestUninstall and TightenScrew. | `RequestGuard.admit`: the limiter runs first, so malformed requests use a token. They get REQUEST_INVALID, or RATE_LIMITED once the allowance is used. | audit 5, static gate 8 |
| D6 | Hardening: the client's proposal branch read `lastEval.socketCF` without a nil check. | Code reading. It does not look reachable in the current flow, so this is not a confirmed defect. | If the preview has no socket to send, the drag is cancelled locally and NO_SOCKET is shown. Nothing is sent. | static gate 9 |
| AMD | The wording of the socket tests was reviewed and is accurate. The socket rule compares socket names, not brands, and no test showed that directly. | Reading of the socket tests. | Symmetry test: the Intel CPU is refused on an AM4 board, and the AMD CPU is accepted on it, with the same geometry. | audit 6 |

## 3. Changes

- **New:** `src/ReplicatedStorage/Shared/Decisions.lua`, the one place where an install or a free placement is decided.
- **Changed:**
  - `PlacementRules.lua`: `insideFootprint`, the optional table box in `checkFreeLayout`, and `chooseSnap`.
  - `RequestGuard.lua`: `isFinitePose` and `admit`.
  - `Locale.lua`: `OFF_TABLE` in English and Arabic.
  - `AssemblyServer.server.lua`: `admit` in the four request handlers. ProposePlacement uses `Decisions`. `layoutFor` replaces `checkFreeLayout`. `TABLE_BOX` is added.
  - `InteractionController.client.lua`: `freeLayout` and `evaluateDrop` use `Decisions` and `chooseSnap`. The proposal branch has the socket guard.
- **Tests:**
  - `tests/run_pure_tests.lua`: a test-only `script` shim, the regression block (audit 1 to audit 6), and `OFF_TABLE` in the message check.
  - `tests/static_checks.lua`: `Decisions` in the purity and member checks. The one allowed `script.Parent:WaitForChild` line is exempt from the Roblox-word scan, and nothing else is. Sibling requires resolve in the folder of the file that asks for them. Gates 8 and 9 are new.
  - `tests/mutation_check.lua`: new.
- **Documentation:** the counts, module lists and rule codes in the README files, `docs/` and `KNOWN_LIMITATIONS.md` (items 25 and 27 to 32) are updated.

## 4. Behaviour changes (intended)

1. A free drop past the table edge is refused with `OFF_TABLE`.
2. A drop near an occupied socket snaps to a valid free socket in range, if there is one.
3. The preview turns red with `TOO_FAR` when the server would refuse for reach. Before, it could show green.
4. Malformed requests use the rate limit, and can be answered `RATE_LIMITED`.
5. A proposal with a NaN or infinite orientation is refused.

## 5. Results (this environment, outside Roblox)

| Command | Result |
|---|---|
| `texlua tests/syntax_check.lua` | 17 of 17 files OK, 0 errors |
| `texlua tests/run_pure_tests.lua` | 202 passed, 0 failed. Before the fixes, the 27 regression checks gave 25 failed and 2 passed; after the fixes all 27 pass. |
| `texlua tests/static_checks.lua` | 115 passed, 0 failed |
| `texlua tests/mutation_check.lua` | 15 of 15 planted faults detected. The unmutated copy passes first. |

The static gate count moved from 88 to 115. Seven checks were added for `Decisions` (purity, members, and its sibling requires). Twenty checks come from gates 8 and 9.

The fifteen planted faults are: free placement past the table edge; a part exactly on the edge refused; snap using only the nearest socket; install ignoring reach; install ignoring bench bounds; free placement ignoring the table box; pose check ignoring the look vector; argument check before the rate limit; English OFF_TABLE message missing; AMD CPU accepted on the LGA1700 board; PickUp checking arguments before the rate limit; ProposePlacement without a rate limit; server installs bypassing `Decisions`; client snap using only the nearest socket; client proposing a snap without its socket. Ten are caught by the pure tests and five by the static gates.

## 6. Not verified

- Anything inside Roblox Studio: the server, the client, the workshop builder, remote creation, replication and the real geometry.
- Touch, the camera sink, device behaviour, and Arabic rendering.
- Whether the client and the server see the same neighbours during replication. This is an open risk (KNOWN_LIMITATIONS item 28).
- Whether `WorkshopBuilder` builds the table at the position and size that `WorkshopLayout` records (item 27).
- Type checking: `luau-analyze` is not available here, and it was not run.
- Performance.

## 7. Scores

The readiness measure in `COMPLETION_REPORT.md` is unchanged. It counts runs in Roblox, and none were made in r5. The pure-logic credit was not raised either, because the pure logic changed, and the added tests are evidence for the change, not a new score.

## 8. Open decisions for the owner

1. **Version.** `Config.Version` is still `0.1.4`. Change it to `0.1.5` if this is released as r5.
2. **Mutation check portability.** `tests/mutation_check.lua` uses `cp`, `rm` and `/tmp`. Decide whether a Windows version is needed.
3. **Bench box and table width** (item 31). The bench box is narrower than the table on X. Decide whether to widen the bench or accept the 2 unused studs.
