# Development

## Workflow decision
Rojo, source first. `src/` is the source of truth and `rojo serve` syncs it into the open Studio place, so don't edit scripts in Studio; the next sync overwrites them. Use Studio for non-script content (map, models, UI layout), which lives in the saved place.

The Studio MCP integration isn't connected. If you add it, keep it read-only or limit it to non-script instances.

## One-time setup
1. In Claude Code run `/plugin`, search for Roblox Studio, install it, then restart the session. (Official: https://github.com/Roblox/roblox-studio-agent-plugin)
2. Open Roblox Studio, sign in, create a new Baseplate place. Don't publish it.
3. In Studio: Assistant > ... > Settings > MCP Servers > turn on Enable Studio as MCP server.
4. In Claude Code run `/mcp`: `plugin:roblox-studio:macos` should be connected (the `windows` entry will fail, which is fine).

## Each session
1. Open Studio with the Contradictions test place.
2. `cd ~/Developer/Contradictions && claude`
3. Before any edit, ask Claude to list the open Studio windows and check that it sees the Contradictions place.

## Playtesting
Press Play (F5). The menu appears over the stage; a new player pressing Play is offered the tutorial or a skip, a returning player starts a run. Logic and round data are tested outside Studio with `luau tests/run.luau`. `default.project.json` turns `StreamingEnabled` off, because the stage has to replicate to a client with no character.

## Onboarding persistence (DataStore)
`ProfileService` stores `{ version, hasSeenOnboarding, hasCompletedTutorial, onboardingChoice }` per player in DataStore `ContradictionsOnboarding`, key `player_<UserId>`. `hasSeenOnboarding` means they were offered the choice and made one; `hasCompletedTutorial` is only set when all four practice rounds finish; a skip records `onboardingChoice = "skipped"` and never `hasCompletedTutorial`. At most two writes per player ever. Reads and writes are retried (3 attempts, 1 s then 2 s), writes use `UpdateAsync` with a monotonic merge (flags only go false to true, first choice wins, unknown fields kept), pending saves are flushed on `PlayerRemoving` and `BindToClose`. A failed read gives status `unavailable`, never `new`: the menu says so, and the tutorial is not offered this session. The read is retried in the background (every 15 s, 4 times); if it recovers, the stored record and anything chosen meanwhile are combined and nothing is lost.

**Studio prerequisite:** DataStores only work in Studio with Game Settings > Security > "Enable Studio Access to API Services" turned on (this is a per-experience setting; it has not been changed). Without it the real store fails and the game runs in the `unavailable` fallback. To exercise the flows without it, set the `ServerStorage` attribute `DevStore` at runtime to `"empty"` (new player), `"returning"`, `"failload"`, `"failsave"` or `"flaky"` (first two reads fail, then recover; exercises the background retry every 15 s, 4 times); any other string is a fresh empty store. The in-memory store (`src/server/DevStore.luau`, Studio only) mirrors its contents to attribute `DevStoreData`.

## If Studio looks stale
Rojo can occasionally miss a file change. If behaviour does not match `src/`, compare the script's `Source` in Studio with the file; touching the file does nothing (Rojo thinks it is in sync), so change its content and change it back, or paste the source. One such miss happened to `Config.luau` during this work.

## Backups and commits
After each working milestone:
1. File > Save to File As... `place/Contradictions.rbxl` (overwrite).
2. Also save a dated copy: `backups/Contradictions-YYYYMMDD-HHMM.rbxl` (git-ignored).
3. Scripts are already in `src/`; nothing to mirror.
4. `git add -A && git commit`.

`place/Contradictions.rbxl` is a binary, so its Git history is a restore point, not a diff. Review changes in `src/`.

## Safety rules
- Never point Claude at the place of a published game.
- Check the target Studio window before every batch of edits.
