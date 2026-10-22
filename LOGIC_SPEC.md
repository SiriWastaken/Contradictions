# Logic Specification

## Instruction model
An instruction is an expression **F**. The standing convention, taught in the tutorial: *press the button if and only if F is true*. "Press the button if C" means F = C; "Press the button." is F = true; "Do not press the button." is F = false.

## Expression nodes
| op | meaning |
|---|---|
| `const` {v} | true / false |
| `fact` {text, v} | a labelled constant ("7 is greater than 4") |
| `press` | you press the button this round (self-reference) |
| `prev` {k} | you pressed the button k rounds ago (k = 1..3), from the session history |
| `told` {k} | the instruction k rounds ago required pressing; defined only if that round had exactly one acceptable decision |
| `not`, `and`, `or`, `xor` | connectives (`or` is inclusive) |
| `stmt` {a} | the on-screen statement (body `a`); its truth value is the unknown **x** |
| `this` | inside a statement body: the statement itself (value **x**) |

At most one `stmt` per instruction, not nested; `this` is only valid inside a statement body; depth is at most 6. Instruction text is rendered from the tree and **never executed**.

## Semantics
Unknowns: **d** (this round's decision, true = press) and **x** (truth value of the statement, if any). A pair (d, x) is consistent iff
1. statement: `x == eval(body, d, x)` (the statement is true exactly when what it says holds), and
2. instruction: `d == eval(F, d, x)`.

A decision d is **acceptable** iff some x makes (d, x) consistent. The solver tries all four pairs and returns `{ kind, press, hold, required }`.

| acceptable decisions | kind | scoring |
|---|---|---|
| exactly one | unique | that decision is correct |
| both | multiple | either is correct |
| neither | none (paradox) | no decision is correct; 0 points, no penalty, streak kept |

Examples: `stmt(this)` "this statement is true": both (multiple). `stmt(not this)` "this statement is false": none. `not press` "press if you do not press": none. `press` "press if you press": both. `stmt(not this and prev1)`: none if you pressed last round, otherwise unique hold, so the kind depends on history.

## History
After each round the session stores `{ pressed, required }`, where `required` is set only when the round was unique. A timeout is `pressed = false`. `prev` and `told` read this list; the engine asserts if a reference is out of range or points at a non-unique round. Tests walk every possible sequence of decisions through both round lists to prove no player can reach such a state.

## Timing and authority
The server starts a 5 s window per round, rejects decisions before 0.2 s (stray clicks) and after resolution, and resolves at deadline + 0.15 s (in-flight click grace) as a hold if nothing arrived. A round resolves exactly once: state moves `active` to `review` synchronously, and timers carry a token that is discarded once the round has resolved. Clients send only a token-stamped press; the server computes verdict, score and explanation.

## Data validation
`Rules.validate` rejects unknown ops, a `this` outside a statement, nested or multiple statements, `prev`/`told` outside 1..3, malformed facts, and depth over 6.
