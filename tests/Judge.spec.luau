--!strict
-- TEST_PLAN J1-J7: correctness of press / hold / timeout decisions and scoring.
local Judge = require("../src/shared/Logic/Judge")
local Rounds = require("../src/shared/Rounds")
local Rules = require("../src/shared/Logic/Rules")

local function outcome(i: number, hist: Rules.History?): Rules.Outcome
	return Rules.solve(Rounds.run[i].f, hist or {})
end

return function(test: (string, () -> ()) -> ())
	test("J1 press on a press instruction is correct, hold is wrong", function()
		local o = outcome(2) -- "Press the button."
		assert(Judge.verdict(o, true) == "correct")
		assert(Judge.verdict(o, false) == "wrong")
	end)
	test("J2 hold (and so a timeout) on a do-not-press instruction is correct", function()
		local o = outcome(1) -- "Do not press the button."
		assert(Judge.verdict(o, false) == "correct")
		assert(Judge.verdict(o, true) == "wrong")
	end)
	test("J3 a timeout is judged by the rule, not assumed wrong", function()
		-- Timeout = pressed false. Correct when holding is acceptable, wrong when it is not.
		assert(Judge.verdict(outcome(1), false) == "correct")
		assert(Judge.verdict(outcome(2), false) == "wrong")
		assert(Judge.verdict(outcome(4), false) == "correct") -- 7 < 4 is false: hold
	end)
	test("J4 multiple: either decision is correct", function()
		local o = outcome(11) -- truth-teller
		assert(o.kind == "multiple")
		assert(Judge.verdict(o, true) == "correct" and Judge.verdict(o, false) == "correct")
	end)
	test("J5 none: nothing is wrong, nothing is fatal", function()
		local o = outcome(12) -- "press if you do not press"
		assert(o.kind == "none")
		assert(Judge.verdict(o, true) == "paradox" and Judge.verdict(o, false) == "paradox")
		assert(not Judge.isFatal("paradox", true))
	end)
	test("J6 only a wrong decision in a scored run is fatal", function()
		assert(Judge.isFatal("wrong", true))
		assert(not Judge.isFatal("wrong", false), "practice never kills")
		assert(not Judge.isFatal("correct", true))
	end)
	test("J7 points: 100, then +25 per streak step, capped at +100", function()
		local got = {}
		for streak = 1, 8 do
			table.insert(got, Judge.points(streak, 100, 25, 4))
		end
		assert(table.concat(got, ",") == "100,125,150,175,200,200,200,200", table.concat(got, ","))
		assert(Judge.points(0, 100, 25, 4) == 100)
	end)
	test(
		"J8 whole-run invariant: every first mistake on every path is fatal exactly once",
		function()
			-- Walk all decision sequences; the first non-paradox wrong answer ends the path.
			local deaths, survivors = 0, 0
			local function go(i: number, hist: Rules.History)
				if i > #Rounds.run then
					survivors += 1
					return
				end
				local o = Rules.solve(Rounds.run[i].f, hist)
				for _, pressed in { false, true } do
					local v = Judge.verdict(o, pressed)
					if Judge.isFatal(v, true) then
						deaths += 1
					else
						table.insert(hist, { pressed = pressed, required = o.required })
						go(i + 1, hist)
						table.remove(hist)
					end
				end
			end
			go(1, {})
			assert(deaths > 0 and survivors > 0)
		end
	)
end
