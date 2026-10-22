# Game Design — Contradictions

## The game
Read the instruction, decide whether to press the red button, commit within **5 seconds**. Not pressing is a valid decision; whether it is right depends on the instruction. **A wrong decision kills you**: jumpscare, game over, restart. A paradox round (no consistent decision exists) cannot be answered wrongly, so it costs nothing.

## Art direction: fire against water
Near-black foundation. **Fire** (ember, molten, crimson) is action: the command to press, the clock, danger, death. **Water** (acid, mint, forest, teal) is restraint and truth: "do not press", quoted self-referential statements, survival.

- Type: GrenzeGotisch (blackletter, mixed case: it is illegible in capitals) for names, numbers and verdicts; Special Elite (typewriter) for everything read or counted.
- Shape: hard edges and hairlines. The only rounded things are the button and the eyes of the thing that kills you. No cards, chips, pills or icons.
- The fire/water rule (ember left, acid right) is the recurring motif: under every title, beside the instruction (command above, answer below), and in the timer, a fuse of fire burning down across a toxic track.
- The stage behind the UI: the red button on a plinth over a pool of toxic water, sparse embers rising. The water climbs as the clock drains and the button's light flickers only in the last second and a half. Nothing else moves.
- Motion is functional: the button's inner ring beats faster as time runs out; a press dips the cap; the jumpscare is the single loud moment.

## Flow
Main menu (Play, How to play) → [new players only: First time? Play tutorial / Skip tutorial] → tutorial or run → rounds → correct: 0.9 s and the next round (paradox: 2.6 s with a one-line note) → wrong: jumpscare (~0.9 s) → Game over (instruction that killed you, why, score, best, **Restart**, Menu) → new run.

## Tutorial
Optional and replayable (How to play). Four unscored practice rounds under the same 5 s timer: press; do not press; a true/false condition with OR and NOT; a rule that looks at your last decision. Coach lines say that in a real run one wrong decision ends it; a wrong answer in practice shows what it would have cost without killing you. No self-reference or paradox appears before it ends.

## Progression (18 scored rounds)
1-2 plain commands; 3-7 facts, NOT, AND, OR; 8-10 memory of your decisions and of what earlier instructions required; 11-14 self-reference (truth-teller: two answers; "press if you do not press": none; the liar: none; a paradox that exists only if you pressed last round); 15-17 memory again, including exactly-one; 18 a final mix.

## Scoring
Correct: 100 plus 25 per consecutive correct beyond the first (bonus capped at +100). Paradox: 0, streak kept. Score is computed on the server. Best score is per session (not persisted).

## Accessibility
The menu has a "Flashing effects: full / reduced" switch (per session). Reduced removes the death flashes and shake, the fuse-tip and button-light flicker and the Game Over title flicker; the sound, the face and the transitions stay.

## Input
GUI button: mouse, touch, Space. World button: a `ClickDetector` on the red cap; the GUI cap is drawn over it, slightly smaller, so the 3D rim stays clickable. Both call one server handler. Continue in the tutorial: button or Enter.

## Out of scope
Persisted scores, audio beyond the death sting, multiplayer, procedural puzzles, monetisation.
