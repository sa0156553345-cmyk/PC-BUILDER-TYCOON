# Completion report (V0.1, milestone 4)

## 1. What "100%" means here
The reference is the V0.1 plan agreed so far, in full: one workshop, one starter PC, one order, the assembly loop, bilingual interface, server authority, tested logic, setup documentation, verified in Roblox Studio and on a real device, and persistence. Persistence was approved to wait until the prototype runs in Studio, so it is in the reference but not yet built.

## 2. The measure
Nine categories with fixed weights (sum 100). Each category gets a credit percentage based on the evidence that exists today. The rules were fixed before the score was computed.

| # | Category | Weight | Status today | Evidence | Credit |
|---|---|---:|---|---|---:|
| A | Pure logic and rules (catalog, compatibility, boot and order, placement geometry, layout, ledger, validation, pointer and drag ordering, remote plan, locale) | 20 | implemented, **tested** outside Roblox | 202 pure tests pass; 10 injected faults in pure modules are detected by `tests/mutation_check.lua` (r5) | 90% → **18.0** |
| B | Authoritative server (validation, ownership, rate limits, placement, boot, rewards, cleanup) | 15 | implemented, **untested** in Roblox (names and requires checked) | 115 static checks; 5 server and client wiring faults detected (r5); hold, ledger and validation logic tested | 60% → **9.0** |
| C | Client interaction (touch and mouse, drag ordering, ghost, preview, drop button, camera sink) | 15 | implemented, **untested** on device; logic partly tested | pointer arbitration and drag ordering tested; touch identity UNVERIFIED | 50% → **7.5** |
| D | Playable loop (select, place, cables, screws, boot, order, wallet, diagnostics) | 15 | implemented end to end in code, **untested** | code paths only; no run in Studio | 50% → **7.5** |
| E | Localization and interface | 10 | strings **tested** (EN and AR match, all codes and keys translated); layout and rendering **untested** | 202 + 115 checks cover keys and codes | 60% → **6.0** |
| F | Assets | 5 | placeholder geometry generated in code; no art, sound or fonts | docs/KNOWN_LIMITATIONS.md section 22 | 40% → **2.0** |
| G | Setup, documentation and quality gates | 5 | written; static gates and syntax checker in place | docs/STUDIO_SETUP.md, TESTING_CHECKLIST.md, KNOWN_LIMITATIONS.md | 90% → **4.5** |
| H | Runtime verification (Studio runs, device tests, multiplayer, performance) | 10 | **not run** (no Studio, no device, no second player here) | none | 0% → **0.0** |
| I | Persistence (DataStore) | 5 | **not started** (approved to wait) | none | 0% → **0.0** |

**Measured readiness: 54.5 of 100, about 55%.**

## 3. Implemented, tested, partial, untested
- **Implemented and tested outside Roblox:** AssemblyRules (install, removal, screws, boot, order), PlacementRules (reach, bounds, alignment, free-placement layout), RateLimit, RemoteLayout, DragSequence (exhaustive ordering), PointerTracker (one touch drives), RequestGuard, SessionHold (regression: rejected drop releases), Ledger (each order paid once), WorkshopLayout (fit, reach, table, case), Locale (EN and AR).
- **Implemented, partly tested:** multi-touch (arbitration tested, device behaviour untested); camera sink (untested); free-placement preview (layout rules tested, client preview untested).
- **Implemented, untested in Roblox:** the server script, the workshop builder, the client script, the diagnostics panel, the wallet and order line, the screw labels, the boot light, character placement.
- **Partial:** localization (text complete, reviewed by the assistant only), assets (placeholder only), setup (18 manual instances remain).
- **Not implemented:** saving (DataStore), art and sound, a second order, a shop.

## 4. What changed in this milestone (evidence in the repository)
- Pure modules added: PointerTracker, RequestGuard, SessionHold, Ledger, WorkshopLayout. Config made pure (it can be loaded by tests).
- Procedural workshop (WorkshopBuilder): removes the manual modelling step. Templates still work if both exist.
- Server rewritten around those modules: argument validation, ownership checks, free placement checks (table, case, overlap), hold rules, ledger, screw labels, boot light, character placement.
- Client rewritten: touch arbitration, camera sink, Drop button, ghost and preview with reasons, full diagnostics panel, wallet and order line, RTL alignment for both languages.
- Layout fixes found by the tests: the motherboard needed its own bin spot and a wider table; the screw label moved above the product label.
- r5 audit: free placement refused past the table edge; snap uses the nearest valid socket in range; preview and server share one placement decision (`Decisions`); rate limit before argument checks in every request handler; full pose check (position and orientation); automated mutation check. Details in `docs/AUDIT_R5.md`. No score changed: the readiness measure counts runs in Roblox, and none were made in r5.
- Quality gates: tests/static_checks.lua (115 checks in r5).

## 5. Remaining blockers
1. Roblox Studio is needed. It needs Windows or macOS, and the user has an Android phone only.
2. A real device is needed for touch, the camera, layout and Arabic rendering.
3. A second player is needed for multiplayer.
4. Persistence is deferred by approval.
5. Art, sound and a native review of the Arabic text.

## 6. How the number would move (not measured, projection only)
If the server and client ran correctly in Studio and on a phone, categories B, C and D would move toward their full credit, and H would start earning credit:
- B 60% → 90%: +4.5
- C 50% → 85%: +5.25
- D 50% → 85%: +5.25
- H 0% → 60%: +6.0
That projection reaches about 75%. Persistence (I) and art (F) would add the remainder. **The target of 76% cannot be measured as reached in this environment.** It needs the runs above, and the measure must be recomputed from their results.

## 7. Honesty statement
No Roblox Studio run, phone test, multiplayer test or performance test was performed for this milestone. Every claim about Roblox behaviour in this report is a claim about code that has not been executed in Roblox.
