# Server-authoritative assembly (V0.1, milestone 4)

## 1. Principle
**The client predicts. The server decides.** The client shows a ghost at once. It sends one proposal on release. The server validates it against its own copy of the build, then installs it, places it, or rejects it with a code. The client never sends money, a result or a completion claim.

## 2. Modules
| Module | Where | Runs on | Purpose |
|---|---|---|---|
| `Config` | Shared | both | Tuning values (PLACEHOLDER). Pure. |
| `Catalog` | Shared | both | Products, slots, starter PC, order |
| `AssemblyRules` | Shared | both | Install, removal, screws, boot, order. Codes and params only. |
| `PlacementRules` | Shared | both | Reach, bounds, alignment, free-placement layout (table, case, overlap) |
| `Decisions` | Shared | both | The one install and free-placement decision. The server decides with it, and the client preview calls the same functions. |
| `WorkshopLayout` | Shared | both | Placeholder geometry: sizes, colours, sockets, bin spots, stand point |
| `RateLimit` | Shared | server | Fixed one-second window per action |
| `RequestGuard` | Shared | server | Validates ids, numbers, points, slots |
| `SessionHold` | Shared | server | Which part a player holds; every proposal ends the hold |
| `Ledger` | Shared | server | Each order paid once |
| `RemoteLayout` | Shared | server | Plans the RemoteEvent folder, stops on conflict |
| `PointerTracker` | Shared | client | One pointer drives a drag |
| `DragSequence` | Shared | client | Order of requests for one drag |
| `Locale` | Shared | client | Every EN and AR message and interface string |
| `WorkshopBuilder` | ServerScriptService | server | Builds the workshop and products at runtime |
| `AssemblyServer` | ServerScriptService | server | Authoritative state and replies |
| `InteractionController` | StarterPlayerScripts | client | Input, ghost, preview, HUD, language |

## 3. Remote folder (`RemoteLayout`)
The server reuses one valid folder named `AssemblyRemotes` and creates missing RemoteEvents. It stops, and changes nothing, on any conflict: a duplicate folder, a non-folder with the same name, a duplicate RemoteEvent, or a RemoteEvent of the wrong class. After setup it verifies all seven RemoteEvents. The client waits up to 10 seconds for each.

## 4. Remote protocol
| Remote | Direction | Arguments | Server behaviour |
|---|---|---|---|
| `PickUp` | client to server | instanceId | Validates the id, rate limit, ownership, not installed, reach. On success replies `PICKED_UP`. A new pick replaces an earlier hold. |
| `ProposePlacement` | client to server | instanceId, pose, slotId (empty means free placement) | The rate limit comes first and counts every proposal, malformed ones included. Then the id, slot and pose are checked (finite position and orientation). **Every proposal ends the hold**, whatever the outcome. Then: held, ownership, and the checks in section 5. |
| `ReleaseHold` | client to server | instanceId | Releases the hold if held. Never refused: the limiter only counts it. |
| `RequestUninstall` | client to server | instanceId | Validates, ownership, reach, dependents (R10). Clears screws and the screw label. |
| `TightenScrew` | client to server | instanceId | Validates, ownership, reach, screw count (R11). Updates the screw label. |
| `RequestBoot` | client to server | none | Rate limit, boot checks, order checks, then pays once. Sets the light and the workshop attributes. |
| `Feedback` | server to client | kind, ok, code, params, instanceId, diagnostics, final | Server only. |

Every reply carries a code and params. The client translates them. Malformed requests get `REQUEST_INVALID` and change nothing.

## 5. Placement pipeline (`ProposePlacement`)
Free placement (empty slot):
1. Validate, consume the hold, rate limit, held, ownership.
2. Bench bounds and reach (`checkFreePose`).
3. Layout (`PlacementRules.checkFreeLayout`, run through `Decisions.free`): not below the table top, not past the table edge (`OFF_TABLE`), not inside the case, not overlapping another part. The layout size comes from `WorkshopLayout`, and each part's pivot gives its position in workshop coordinates.
4. Place at the proposed pose. Reply `PLACED_FREE`.

Install (slot):
1. Validate, consume the hold, rate limit, held, ownership.
2. Install rules R1 to R9 (`validateInstall`).
3. Proposal inside the bench bounds. The socket exists. The player is in reach of the socket.
4. Proposal within 3 studs of the socket and aligned within 15 degrees (`checkInstallPose`).
5. Move the part to the socket's exact pose, anchor it, set `SlotId` and `Installed`, show the screw label if needed. Reply `INSTALLED` with the final pose.

## 6. Boot and money
- `evaluateBoot` returns every problem at once. The light turns red on failure.
- `evaluateOrder` runs only after a successful boot.
- `Ledger.complete` pays once per order id. A second call returns `ALREADY_PAID`, which the server reports as `ORDER_ALREADY_DONE` with no new money.

## 7. Ownership and leaving
Each workshop and each part carries an `Owner` attribute with the player's UserId. The server checks the session and the attribute on every request. On leaving, the server removes the session and destroys the workshop.

## 8. Client prediction and reconciliation
- Pick: the ghost appears at once and the real part is hidden locally. The server's answer decides whether the drag continues.
- Drag: no network traffic. The preview calls the same shared decisions as the server (`Decisions`), including free placement and the snap choice.
- Release: DragSequence sends one decision. A tap sends `ReleaseHold` only. A drop waits for the pickup acknowledgement. A red spot sends `ReleaseHold` only.
- Pending: the ghost stays until the server confirms and the real part reaches the confirmed pose, or until the 3-second timeout.
- Cache: socket candidates and the state mirror are rebuilt only on pickup, reply, placement or cancel.

## 9. Threats and mitigations
| Threat | Mitigation | Verification |
|---|---|---|
| Client claims money or completion | No remote carries money. Payout only in the boot handler, once per order. | Ledger tests; ORDER_ALREADY_DONE; not run in Studio |
| Malformed arguments (bad ids, NaN, unknown slots, huge numbers) | `RequestGuard` on every handler | Guard tests; not run in Studio |
| Rejected drop leaves the part in hand | Every proposal consumes the hold | Regression test; not run in Studio |
| Refused release leaves a stale hold | Release is never refused | Hold tests; not run in Studio |
| Install a wrong part, wrong port, wrong socket | Rules R1 to R9 on the server | Rules tests |
| Install a part that is not aligned or not in reach | `checkInstallPose`, reach checks | Geometry tests |
| Place a part below the table, past its edge, inside the case, or over another part | `checkFreeLayout` on the server | Layout tests; not run in Studio |
| Act on another player's parts | Session and `Owner` checks | Not run (needs two players) |
| Spam | Per-player, per-action rate limits | Limiter tests; not run in Studio |
| Tap installs a part by accident | Movement threshold; a tap only selects | DragSequence tests |
| Second finger drives the drag | `PointerTracker` | Pointer tests; device UNVERIFIED |
| Remote folder conflicts | `RemoteLayout` stops and reports | Plan tests; not run in Studio |

## 10. Known gaps
See `docs/KNOWN_LIMITATIONS.md`. The most important are: nothing has run in Roblox, touch identity is UNVERIFIED on a device (the Drop button is the way out), free-placement boxes are axis-aligned, and nothing is saved.
