--!strict
-- Pure judging rules, kept out of SessionService so they can be tested without Roblox.
-- A timeout is just `pressed = false`; nothing here treats it specially.

-- selene: allow(incorrect_standard_library_use)
local Rules = require("./Rules")

export type Verdict = "correct" | "wrong" | "paradox"

local Judge = {}

-- Correct iff the chosen decision is logically consistent. If no decision is, nothing can be wrong.
function Judge.verdict(outcome: Rules.Outcome, pressed: boolean): Verdict
	if outcome.kind == "none" then
		return "paradox"
	end
	local acceptable = if pressed then outcome.press else outcome.hold
	return if acceptable then "correct" else "wrong"
end

-- Only a wrong decision in a scored run ends it. Practice rounds and paradoxes never kill.
function Judge.isFatal(verdict: Verdict, scored: boolean): boolean
	return scored and verdict == "wrong"
end

-- Points for a correct answer that makes the streak `streak` long (1 = first in a row).
function Judge.points(streak: number, base: number, bonus: number, bonusCap: number): number
	return base + bonus * math.min(math.max(streak - 1, 0), bonusCap)
end

return Judge
