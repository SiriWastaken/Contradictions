--!strict
-- TEST_PLAN L1-L12.
local Render = require("../src/shared/Logic/Render")
local Rules = require("../src/shared/Logic/Rules")
type Expr = Rules.Expr
type History = Rules.History

local function fact(v: boolean): Expr
	return { op = "fact", text = "x", v = v }
end
local function neg(a: Expr): Expr
	return { op = "not", a = a }
end
local function bin(op: string, a: Expr, b: Expr): Expr
	return { op = op, a = a, b = b }
end
local this: Expr = { op = "this" }
local function stmt(body: Expr): Expr
	return { op = "stmt", a = body }
end
local press: Expr = { op = "press" }
local none: History = {}

return function(test: (string, () -> ()) -> ())
	test("L1 const true/false", function()
		local t = Rules.solve({ op = "const", v = true }, none)
		assert(t.kind == "unique" and t.required == true)
		local f = Rules.solve({ op = "const", v = false }, none)
		assert(f.kind == "unique" and f.required == false)
	end)
	test("L2 truth tables for and/or/xor/not", function()
		local want = {
			["and"] = { [0] = false, false, false, true },
			["or"] = { [0] = false, true, true, true },
			xor = { [0] = false, true, true, false },
		}
		for op, rows in want do
			for i = 0, 3 do
				local f = bin(op, fact(i // 2 == 1), fact(i % 2 == 1))
				assert(Rules.solve(f, none).required == rows[i], op .. i)
			end
		end
		assert(Rules.solve(neg(fact(false)), none).required == true)
	end)
	test("L3 truth-teller: stmt(this) is multiple", function()
		local o = Rules.solve(stmt(this), none)
		assert(o.kind == "multiple" and o.press and o.hold)
	end)
	test("L4 liar: stmt(not this) is none, both ways", function()
		assert(Rules.solve(stmt(neg(this)), none).kind == "none")
		assert(Rules.solve(neg(stmt(neg(this))), none).kind == "none")
	end)
	test("L5 press if you do not press: none", function()
		assert(Rules.solve(neg(press), none).kind == "none")
	end)
	test("L6 press if you press: multiple", function()
		local o = Rules.solve(press, none)
		assert(o.kind == "multiple")
	end)
	test("L7 history: prev reads the right entry", function()
		local hist: History = { { pressed = true }, { pressed = false } }
		assert(Rules.solve({ op = "prev", k = 1 }, hist).required == false)
		assert(Rules.solve({ op = "prev", k = 2 }, hist).required == true)
	end)
	test("L8 history-dependent paradox", function()
		local f = stmt(bin("and", neg(this), { op = "prev", k = 1 }))
		local o1 = Rules.solve(f, { { pressed = true } })
		assert(o1.kind == "none")
		local o2 = Rules.solve(f, { { pressed = false } })
		assert(o2.kind == "unique" and o2.required == false)
	end)
	test("L9 told needs a unique round", function()
		local f: Expr = { op = "told", k = 1 }
		assert(Rules.solve(f, { { pressed = false, required = true } }).required == true)
		assert(not pcall(Rules.solve, f, { { pressed = false } }))
	end)
	test("L10 validation rejects bad data", function()
		assert(not Rules.validate(this))
		assert(not Rules.validate(stmt(stmt(this))))
		assert(not Rules.validate(bin("and", stmt(this), stmt(this))))
		assert(not Rules.validate({ op = "prev", k = 4 }))
		assert(not Rules.validate({ op = "fact", v = true }))
		assert(not Rules.validate({ op = "nope" }))
		local deep = fact(true)
		for _ = 1, 7 do
			deep = neg(deep)
		end
		assert(not Rules.validate(deep))
		assert(Rules.validate(stmt(neg(this))))
	end)
	test("L11 deterministic", function()
		local f = stmt(neg(this))
		assert(Rules.solve(f, none).kind == Rules.solve(f, none).kind)
	end)
	test("L12 rendering", function()
		assert(Render.directive({ op = "const", v = false }) == "Do not press the button.")
		assert(Render.directive(stmt(this)) == "Press the button if the statement below is true.")
		assert(
			Render.directive(neg(stmt(this))) == "Press the button if the statement below is false."
		)
		assert(Render.statement(stmt(neg(this))) == "This statement is false.")
		assert(Render.statement({ op = "const", v = true }) == nil)
		assert(Render.directive(neg(press)) == "Press the button if you do not press the button.")
		assert(
			Render.directive(neg({ op = "told", k = 1 }))
				== "Press the button if the previous instruction told you not to press the button."
		)
		assert(#Render.explain(stmt(neg(this)), none, Rules.solve(stmt(neg(this)), none)) == 3)
	end)
end
