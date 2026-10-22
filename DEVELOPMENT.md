# Development

## Workflow decision
**Rojo source-first.** Files in `src/` are the single source of truth; `rojo serve` syncs them into the open Studio place. Do not edit scripts inside Studio (they are overwritten on sync). Studio is for non-script content (map, models, UI layout), which lives in the saved place.

Changed from the earlier direct-MCP plan at the user's request. The Studio MCP integration is still not connected; if added later, use it read-only or for non-script instances only.

## One-time setup
1. In Claude Code run `/plugin`, search **Roblox Studio**, install it, then restart the session. (Official: https://github.com/Roblox/roblox-studio-agent-plugin)
2. Open Roblox Studio, sign in, create a **new Baseplate** place. Do not publish it.
3. In Studio: Assistant > ... > Settings > MCP Servers > turn on **Enable Studio as MCP server**.
4. In Claude Code run `/mcp`: `plugin:roblox-studio:macos` should be connected (the `windows` entry failing is expected).

## Each session
1. Open Studio with the Contradictions test place.
2. `cd ~/Developer/Contradictions && claude`
3. Ask Claude to list the open Studio windows and confirm it sees the Contradictions place before any edit.

## Playtesting
Press Play (F5). The menu appears over the stage; PLAY starts the tutorial the first time. Logic and round data are tested outside Studio with `luau tests/run.luau`. `StreamingEnabled` is forced off in `default.project.json` (the stage must replicate to a character-less client).

## Backups and commits
After each working milestone:
1. File > Save to File As... `place/Contradictions.rbxl` (overwrite).
2. Also save a dated copy: `backups/Contradictions-YYYYMMDD-HHMM.rbxl` (git-ignored).
3. Scripts are already in `src/`; nothing to mirror.
4. `git add -A && git commit`.

`place/Contradictions.rbxl` is a binary, so Git history of it is a restore point, not a diff. Review changes in `src/`.

## Safety rules
- Never point Claude at a published game's place during development.
- Confirm the target Studio window before every batch of edits.
