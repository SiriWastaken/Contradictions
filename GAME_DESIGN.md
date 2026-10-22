# Game Design — Contradictions

## The game
One interaction, repeated: read the instruction, decide whether to press the red button, commit within **5 seconds**. Not pressing is a valid decision; whether it is correct depends on the instruction.

The question every round: *am I supposed to press, or resist?*

## Presentation
Entirely UI. A ScreenGui sits over a fixed camera aimed at a dark stage with a physical red button. No character is spawned; there is no movement, exploration, doors or multiplayer.

Round screen, top to bottom: round number, 5-second timer (numeric and a depleting bar), score and streak; the instruction card; the large red button. After the decision the card expands to show the verdict and a logical explanation, then the game moves on (auto after 8 s, or CONTINUE / Enter).

Visual language: near-black, one signal red, amber reserved for warnings and paradoxes, green only for "correct". Oswald for labels and the button, Merriweather for the instruction (it should read like a notice), Roboto Mono for anything that counts.

## Input
- GUI button: mouse and touch (`Activated`), Space as a keyboard shortcut.
- Physical button: a `ClickDetector` on the red cap in the world. The GUI cap is drawn over the 3D cap, slightly smaller, so the 3D rim stays visible and clickable. Both paths call the same server handler.

## Tutorial
Skippable, replayable from the menu, unscored, same 5-second timer. Four practice rounds with a coach line each: press; do not press; a true/false condition with OR and NOT; a rule that looks back at your last decision. No self-reference or paradox appears before it ends; its closing screen announces that later instructions refer to themselves, can have two answers, or none.

## Progression (18 scored rounds)
1-2 plain commands. 3-7 facts, NOT, AND, OR. 8-10 memory of your own decisions and of what previous instructions required. 11-14 self-reference: a truth-teller (two acceptable answers), "press if you do not press" (none), the liar (none), and a paradox that only exists if you pressed last round. 15-17 memory again, including exactly-one. 18 a final mix. Handcrafted; procedural generation is out of scope until the semantics are settled.

## Scoring
Correct: 100 plus 25 per consecutive correct answer beyond the first (streak bonus capped at +100). Wrong: 0, streak resets. Paradox (no consistent decision): 0, streak untouched, nothing deducted. Multiple consistent decisions: any is correct. Score is computed on the server.

## Out of scope
Persistence of best score and tutorial-seen flag (DataStores are not reachable from Studio testing here), sound, multiplayer, procedural puzzles, monetisation.
