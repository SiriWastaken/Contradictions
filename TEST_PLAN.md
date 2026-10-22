# Test Plan

## Automated: `luau tests/run.luau` (19 cases)
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

## Studio (Play mode), verified with scripted clients
| # | Case | Result |
|---|---|---|
| G1 | Full 18-round run with perfect play, spamming presses | 2950 pts, 16/16 correct, 2 paradoxes, exactly one result per round |
| G2 | Timeout resolves as hold; holds score on hold rounds, fail on press rounds | verified |
| G3 | Press inside the 0.2 s lockout / after expiry / with a stale token / non-numeric token | ignored |
| G4 | World `ClickDetector` click (real mouse input, no character) | counts as a press |
| G5 | GUI button click, PLAY, SKIP TUTORIAL via real mouse input | works |
| G6 | Malformed `Start`/`Next`/`Decide` payloads | ignored, no error |

## Not yet covered
Touch input on a device; very narrow portrait viewports; Space/Enter shortcuts; audio; reconnect mid-round.
