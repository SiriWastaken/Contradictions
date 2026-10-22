--!strict
-- Every handcrafted round is structurally valid, and every possible player history is playable.
local Render = require("../src/shared/Logic/Render")
local Rounds = require("../src/shared/Rounds")
local Rules = require("../src/shared/Logic/Rules")

-- Walk every sequence of decisions (press/hold at each round, correct or not) through the list.
local function walk(
	list: { Rounds.Round },
	visit: (index: number, outcome: Rules.Outcome, hist: Rules.History) -> ()
)
	local function go(i: number, hist: Rules.History)
		if i > #list then
			return
		end
		local o = Rules.solve(list[i].f, hist)
		visit(i, o, hist)
		for _, pressed in { false, true } do
			local entry: Rules.Entry = { pressed = pressed, required = o.required }
			table.insert(hist, entry)
			go(i + 1, hist)
			table.remove(hist)
		end
	end
	go(1, {})
end

return function(test: (string, () -> ()) -> ())
	for name, list in Rounds do
		test(name .. ": structure", function()
			for i, r in list do
				local ok, err = Rules.validate(r.f)
				assert(ok, ("round %d: %s"):format(i, tostring(err)))
				assert(#Render.directive(r.f) > 0)
			end
		end)
		test(name .. ": every decision history is playable", function()
			-- solve asserts when prev/told reach outside history or at a non-unique round.
			local visited = 0
			walk(list, function(_, _, _)
				visited += 1
			end)
			assert(visited > 0)
		end)
	end

	-- Hand-solved expectations for the first run of the game with no mistakes.
	test("run: perfect-play path matches hand solution", function()
		local want: { [number]: string } = {
			[1] = "unique:false",
			[2] = "unique:true",
			[3] = "unique:true",
			[4] = "unique:false",
			[5] = "unique:true",
			[6] = "unique:false",
			[7] = "unique:true",
			[8] = "unique:true", -- pressed round 7 (required true)
			[9] = "unique:false", -- round 8 required press -> told(1) true -> not -> hold
			[10] = "unique:false", -- pressed 9? no: hold -> prev false -> and false
			[11] = "multiple",
			[12] = "none",
			[13] = "none",
		}
		local hist: Rules.History = {}
		for i, r in Rounds.run do
			local o = Rules.solve(r.f, hist)
			local got = if o.kind == "unique"
				then "unique:" .. tostring(o.required)
				elseif o.kind == "multiple" then "multiple"
				else "none"
			if want[i] then
				assert(got == want[i], ("round %d: got %s want %s"):format(i, got, want[i]))
			end
			-- perfect play: follow the required decision, press on multiple, hold on none
			table.insert(hist, {
				pressed = if o.kind == "unique" then o.required :: boolean else o.press,
				required = o.required,
			})
		end
	end)

	test("run: round 14 depends on round 13's decision", function()
		local f = Rounds.run[14].f
		assert(Rules.solve(f, { { pressed = true } }).kind == "none")
		assert(Rules.solve(f, { { pressed = false } }).kind == "unique")
	end)

	test("tutorial contains no self-reference", function()
		for _, r in Rounds.tutorial do
			assert(not Rules.findStmt(r.f) and not Rules.uses(r.f, "press"))
		end
	end)
end
