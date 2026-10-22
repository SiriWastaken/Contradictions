# Contradictions

A full-screen Roblox logic game about one decision: press the red button, or don't. Each round shows an instruction and gives you five seconds. The early ones are plain ("Press the button"). Later ones add conditions, ask about your earlier rounds, refer to themselves, and sometimes have no correct answer.

There is no avatar. The game is a ScreenGui over a fixed camera pointed at a stage with the physical red button on it.

Docs: `GAME_DESIGN.md` (experience and round loop), `LOGIC_SPEC.md` (exact semantics), `TEST_PLAN.md`, `DEVELOPMENT.md`.

## Layout

| Path | Purpose |
|---|---|
| `src/shared/Logic/Rules.luau` | Pure-Luau rule engine: evaluate, solve, validate |
| `src/shared/Logic/Render.luau` | Instruction text and explanations generated from the rule tree |
| `src/shared/Logic/Judge.luau` | Verdict, fatality and points rules (pure, tested) |
| `src/shared/Logic/Layout.luau` | Responsive viewport maths (pure, tested) |
| `src/shared/Logic/Profile.luau` | Onboarding record, merge and retry logic (pure, tested) |
| `src/shared/Rounds.luau` | Handcrafted tutorial and scored rounds |
| `src/server/Systems/SessionService.luau` | Server-authoritative round loop, timer, scoring |
| `src/server/Systems/StageService.luau` | The stage (plinth, toxic water, embers), the red button and its `ClickDetector` |
| `src/server/Systems/ProfileService.luau` | DataStore-backed onboarding record (new vs returning player) |
| `src/client/Controllers/GameUI.luau` | Round screen and client flow: HUD, instruction, GUI button, tutorial feedback |
| `src/client/Ui/Screens.luau`, `Ui/Theme.luau` | Menu, offer, ready, survived and game-over screens; palette, type and builders |
| `src/client/Controllers/Jumpscare.luau`, `Scene.luau` | The death sting; camera and stage animation |
| `tests/` | `luau tests/run.luau` |
| `place/`, `backups/` | Place snapshots |

## Run

`rojo serve`, connect the Rojo plugin in Studio, press Play (F5). Tests: `luau tests/run.luau`. Lint: `stylua --check src tests && selene src`.
