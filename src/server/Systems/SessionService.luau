--!strict
-- Server-authoritative round loop. Owns the rules, the 5 second deadline, the score and death.
-- Every decision (GUI or world button) funnels into decide(); every round resolves exactly once.
-- A wrong decision in a scored run ends it: the session is dropped, so no late click, timer or
-- callback can touch it, and Start("run") builds a brand new one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Util.Remotes)
local Judge = require(Shared.Logic.Judge)
local Render = require(Shared.Logic.Render)
local Rounds = require(Shared.Rounds)
local Rules = require(Shared.Logic.Rules)

type Session = {
	mode: string,
	list: { Rounds.Round },
	index: number,
	state: string, -- "active" | "review"
	token: number,
	startedAt: number,
	reviewAt: number,
	outcome: Rules.Outcome,
	hist: Rules.History,
	score: number,
	streak: number,
	correct: number,
	paradoxes: number,
	scored: number,
}

local SessionService = {}

local sessions: { [Player]: Session } = {}
local best: { [Player]: number } = {}
local lastStart: { [Player]: number } = {}
local tokenCounter = 0
local roundEvent: RemoteEvent
local resultEvent: RemoteEvent
local finishedEvent: RemoteEvent

local function finish(player: Player, s: Session)
	if s.mode == "run" then
		best[player] = math.max(best[player] or 0, s.score)
	else
		ServerStorage:WaitForChild("TutorialCompleted"):Fire(player) -- ProfileService records it
	end
	sessions[player] = nil
	finishedEvent:FireClient(player, {
		mode = s.mode,
		score = s.score,
		best = best[player] or 0,
		correct = s.correct,
		scored = s.scored,
		paradoxes = s.paradoxes,
		total = #s.list,
	})
end

local function startRound(player: Player, s: Session)
	if sessions[player] ~= s then
		return
	end
	s.index += 1
	if s.index > #s.list then
		finish(player, s)
		return
	end

	local round = s.list[s.index]
	tokenCounter += 1
	local token = tokenCounter
	local now = workspace:GetServerTimeNow()
	s.token = token
	s.state = "active"
	s.startedAt = now
	local solved, outcome = pcall(Rules.solve, round.f, s.hist)
	if not solved then
		-- A round the engine cannot evaluate is a data bug, never a paradox: end the session visibly instead of guessing.
		warn(
			("[Contradictions] round %d could not be evaluated: %s"):format(
				s.index,
				tostring(outcome)
			)
		)
		sessions[player] = nil
		finishedEvent:FireClient(player, { mode = s.mode, faulted = true })
		return
	end
	s.outcome = outcome

	roundEvent:FireClient(player, {
		token = token,
		mode = s.mode,
		index = s.index,
		total = #s.list,
		directive = Render.directive(round.f),
		statement = Render.statement(round.f),
		tag = round.tag,
		coach = round.coach,
		startedAt = now,
		endsAt = now + Config.ROUND_SECONDS,
		lockout = Config.LOCKOUT_SECONDS,
		score = s.score,
		streak = s.streak,
	})

	-- Timeout is a decision: holding. Identity and token checks discard timers from finished rounds or runs.
	task.delay(Config.ROUND_SECONDS + Config.GRACE_SECONDS, function()
		if sessions[player] == s and s.token == token then
			SessionService.resolve(player, s, false, true)
		end
	end)
end

function SessionService.resolve(player: Player, s: Session, pressed: boolean, timedOut: boolean)
	if sessions[player] ~= s or s.state ~= "active" then
		return
	end
	s.state = "review"
	s.reviewAt = os.clock()

	local round = s.list[s.index]
	local o = s.outcome
	local verdict = Judge.verdict(o, pressed)
	local died = Judge.isFatal(verdict, s.mode == "run")
	local delta = 0

	if verdict == "paradox" then
		s.paradoxes += 1
	elseif verdict == "correct" and s.mode == "run" then
		s.streak += 1
		delta = Judge.points(s.streak, Config.POINTS, Config.STREAK_BONUS, Config.STREAK_BONUS_CAP)
		s.score += delta
		s.correct += 1
	elseif verdict == "wrong" then
		s.streak = 0
	end
	if s.mode == "run" and verdict ~= "paradox" then
		s.scored += 1
	end

	local lines = Render.explain(round.f, s.hist, o)
	if round.lesson then
		table.insert(lines, round.lesson)
	end
	table.insert(s.hist, { pressed = pressed, required = o.required })

	local token = s.token
	local transition = if died or s.mode == "tutorial"
		then nil
		elseif verdict == "paradox" then Config.PARADOX_TRANSITION_SECONDS
		else Config.TRANSITION_SECONDS

	if died then
		-- The run is over. Dropping the session invalidates every pending timer and rejects every later click.
		best[player] = math.max(best[player] or 0, s.score)
		sessions[player] = nil
	end

	resultEvent:FireClient(player, {
		token = token,
		mode = s.mode,
		index = s.index,
		verdict = verdict,
		died = died,
		kind = o.kind,
		pressed = pressed,
		timedOut = timedOut,
		delta = delta,
		score = s.score,
		best = best[player] or 0,
		correct = s.correct,
		scored = s.scored,
		streak = s.streak,
		lines = lines,
		last = s.index == #s.list,
		transition = transition,
	})

	if transition then
		task.delay(transition, function()
			if sessions[player] == s and s.token == token and s.state == "review" then
				startRound(player, s)
			end
		end)
	end
end

-- The single entry point for a press, from the GUI (token supplied) or the world button (no token).
function SessionService.decide(player: Player, token: any)
	local s = sessions[player]
	if not s or s.state ~= "active" then
		return
	end
	if token ~= nil and token ~= s.token then
		return
	end
	if workspace:GetServerTimeNow() < s.startedAt + Config.LOCKOUT_SECONDS then
		return
	end
	SessionService.resolve(player, s, true, false)
end

local function onStart(player: Player, mode: any)
	if mode ~= "tutorial" and mode ~= "run" and mode ~= "menu" then
		return
	end
	if mode == "menu" then
		sessions[player] = nil
		return
	end
	local now = os.clock()
	if now - (lastStart[player] or 0) < 0.3 then
		return
	end
	lastStart[player] = now
	local s: Session = {
		mode = mode,
		list = if mode == "tutorial" then Rounds.tutorial else Rounds.run,
		index = 0,
		state = "review",
		token = 0,
		startedAt = 0,
		reviewAt = 0,
		outcome = { kind = "unique", press = false, hold = true },
		hist = {},
		score = 0,
		streak = 0,
		correct = 0,
		paradoxes = 0,
		scored = 0,
	}
	sessions[player] = s -- replaces (abandons) any session in progress
	startRound(player, s)
end

-- Tutorial only: continue after reading the explanation. Scored rounds advance on their own.
local function onNext(player: Player, token: any)
	local s = sessions[player]
	if not s or s.mode ~= "tutorial" or s.state ~= "review" or token ~= s.token then
		return
	end
	if os.clock() - s.reviewAt < Config.REVIEW_MIN_SECONDS then
		return
	end
	startRound(player, s)
end

function SessionService.init()
	roundEvent = Remotes.get("Round", "RemoteEvent")
	resultEvent = Remotes.get("Result", "RemoteEvent")
	finishedEvent = Remotes.get("Finished", "RemoteEvent")
	Remotes.get("Start", "RemoteEvent").OnServerEvent:Connect(onStart)
	Remotes.get("Decide", "RemoteEvent").OnServerEvent:Connect(function(player, token: any)
		if typeof(token) == "number" then -- a missing token is reserved for the world button
			SessionService.decide(player, token)
		end
	end)
	Remotes.get("Next", "RemoteEvent").OnServerEvent:Connect(onNext)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player], best[player], lastStart[player] = nil, nil, nil
	end)
end

return SessionService
