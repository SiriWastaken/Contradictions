# Test Plan

## Automated: `luau tests/run.luau` (42 cases)
| # | Case | Expect |
|---|---|---|
| L1 | `const` true/false | unique, required true/false |
| L2 | truth tables for and / or / xor / not | match |
| L3 | truth-teller `stmt(this)` | multiple |
| L4 | liar `stmt(not this)` and its negation | none |
| L5 | `not press` | none |
| L6 | `press` | multiple |
| L7 | `prev` reads the right history entry | correct |
| L8 | `stmt(not this and prev1)` | none after a press, unique hold after a hold |
| L9 | `told` on a non-unique round | asserts |
| L10 | validation: stray `this`, nested/multiple statements, bad lookback, bad fact, unknown op, depth 7 | rejected |
| L11 | determinism | identical |
| L12 | rendering of directive, statement and explanation | exact strings |
| R1 | every round passes validation (tutorial, run) | ok |
| R2 | every possible decision history is playable (no out-of-range `prev`, no `told` at a non-unique round) | ok |
| R3 | perfect-play path matches the hand-solved kinds and decisions | ok |
| R4 | round 14 is none after a press, unique after a hold | ok |
| R5 | tutorial has no self-reference | ok |
| J1-J8 | Judge: press/hold correctness, timeout judged by the rule (not assumed wrong), multiple = either, none = nothing wrong and nothing fatal, practice never kills, points 100 +25/step capped, every decision path through the 18 rounds ends at the first wrong answer | ok |
| U1-U4 | Layout: top bar scales on narrow screens to a floor, instruction block never overlaps the button from 1920x1080 down to 360x640, capped at 38% height | ok |
| P11 | stored and session records are unioned without losing either side | ok |
| P1-P10 | onboarding persistence against fake stores: new vs loaded, read failure is `failed` not new, transient read failure recovers with backoff, damaged record, write creates record, monotonic merge cannot clobber progress after a failed load, unknown fields preserved, write failure retries then reports false without touching the store, transient write failure recovers | ok |

## Studio (Play mode), scripted clients and the real Studio client
All observed in this project's Studio session. Onboarding flows used the Studio-only `DevStore` (see DEVELOPMENT.md); the real DataStore was never reachable (API access disabled), which also exercised the load-failure path for real.

| # | Case | Result |
|---|---|---|
| G1 | Full 18-round run, perfect play, spammed presses (earlier build, same session loop) | 2950 pts, one result per round |
| G2 | Wrong press kills: exactly one `died` result despite 4 spammed presses; no further round or finish event for 8 s | verified |
| G3 | Restart after death: fresh round 1, score 0; the dead run's timers never touch the new run | verified |
| G4 | Wrong timeout kills (round 2 left unpressed) and nothing fires afterwards (7 s) | verified |
| G5 | Correct press, correct hold (timeout) | verified (G1, G3) |
| G6 | Late, stale-token, non-numeric-token, malformed presses | ignored (earlier build; token rule unchanged) |
| G7 | New player, tutorial chosen, finished: record `{seen, completed, choice=tutorial}` | verified (dev store) |
| G8 | New player skips: `{seen, completed=false, choice=skipped}` | verified (dev store) |
| G9 | Returning player: status `returning`, `Play` goes straight to a run | status verified; click path unverified |
| G10 | Read failure (real DataStore, API disabled): status `unavailable`, warning logged, never `new` | verified |
| G11 | Write failure: warning logged, session continues, retry on leave | verified (dev store) |
| G12 | Menu, active round, game over, jumpscare face rendered and inspected | screenshots |
| G14 | Read fails twice then recovers (`flaky`): player skips during the outage, record is written, within the retry window status becomes `returning`, nothing lost | verified (dev store) |
| G15 | Refactored build (Screens/Layout/Judge split): game over screen, active round and bar layout inspected; full death/restart cycle re-run | verified |
| G13 | World `ClickDetector` and GUI mouse clicks | verified earlier; GUI path re-clicked this session |

## Not verified
A possible duplicate round event when a scripted test and live clicks hit the same session (seen once while someone was also clicking in Studio; not reproduced in a clean run). Reduced-flashing toggle (built, never toggled).
Real DataStore reads/writes (needs the Studio API setting or a published server); `BindToClose`/`PlayerRemoving` flush; replaying the tutorial as a returning player through the menu click; touch input on a device; any viewport other than the Studio window (layout is scale-based but unchecked at phone sizes); jumpscare audio (two client-bundled sounds, never heard); the jumpscare in real time (only a held frame was inspected).
