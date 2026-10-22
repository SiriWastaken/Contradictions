# Contradictions

A full-screen Roblox logic game about one decision: **press the red button, or don't.** Each round shows an instruction. You have five seconds. Instructions start as "Press the button" and grow into conditions, memory of earlier rounds, statements that refer to themselves, and a few paradoxes with no correct answer.

There is no avatar and nothing to walk to. The game is a ScreenGui over a fixed camera on a stage holding the physical red button.

Docs: `GAME_DESIGN.md` (experience and round loop), `LOGIC_SPEC.md` (exact semantics), `TEST_PLAN.md`, `DEVELOPMENT.md`.

## Layout

| Path | Purpose |
|---|---|
| `src/shared/Logic/Rules.luau` | Pure-Luau rule engine: evaluate, solve, validate |
| `src/shared/Logic/Render.luau` | Instruction text and explanations generated from the rule tree |
| `src/shared/Rounds.luau` | Handcrafted tutorial and scored rounds |
| `src/server/Systems/SessionService.luau` | Server-authoritative round loop, timer, scoring |
| `src/server/Systems/StageService.luau` | The stage, the red button and its `ClickDetector` |
| `src/client/Controllers/GameUI.luau` | HUD, card, GUI button, tutorial, menus |
| `tests/` | `luau tests/run.luau` |
| `place/`, `backups/` | Place snapshots |

## Run

`rojo serve`, connect the Rojo plugin in Studio, press Play (F5). Tests: `luau tests/run.luau`. Lint: `stylua --check src tests && selene src`.
