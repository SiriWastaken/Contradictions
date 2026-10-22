--!strict
-- Handcrafted rounds. Kinds and acceptable decisions are proven in tests/Rounds.spec.luau.

-- selene: allow(incorrect_standard_library_use)
local Rules = require("./Logic/Rules")
type Expr = Rules.Expr

export type Round = { f: Expr, tag: string?, coach: string?, lesson: string? }

local function yes(): Expr
	return { op = "const", v = true }
end
local function no(): Expr
	return { op = "const", v = false }
end
local function fact(text: string, v: boolean): Expr
	return { op = "fact", text = text, v = v }
end
local function neg(a: Expr): Expr
	return { op = "not", a = a }
end
local function conj(a: Expr, b: Expr): Expr
	return { op = "and", a = a, b = b }
end
local function disj(a: Expr, b: Expr): Expr
	return { op = "or", a = a, b = b }
end
local function one(a: Expr, b: Expr): Expr
	return { op = "xor", a = a, b = b }
end
local function prev(k: number): Expr
	return { op = "prev", k = k }
end
local function told(k: number): Expr
	return { op = "told", k = k }
end
local function me(): Expr
	return { op = "press" }
end
local function stmt(body: Expr): Expr
	return { op = "stmt", a = body }
end
local this: Expr = { op = "this" }

local tutorial: { Round } = {
	{
		f = yes(),
		coach = "Read the instruction. This one is simple: press the button before the five seconds run out. In a real run, one wrong decision ends it.",
	},
	{
		f = no(),
		coach = "Not every instruction wants a press. Doing nothing is a decision too, so let the five seconds run out.",
	},
	{
		f = disj(fact("a week has eight days", false), neg(fact("fire is cold", false))),
		coach = "A condition is a test. If it's true, press. If it's false, hold. Work out each part first.",
	},
	{
		f = prev(1),
		coach = "Some instructions look back at what you did, so remember your last decision.",
	},
}

local run: { Round } = {
	{ f = no() },
	{ f = yes() },
	{ f = fact("7 is greater than 4", true), tag = "TRUE OR FALSE" },
	{ f = fact("7 is less than 4", false), tag = "TRUE OR FALSE" },
	{ f = neg(fact("a week has eight days", false)), tag = "NOT" },
	{
		f = conj(fact("9 is greater than 5", true), fact("a triangle has four sides", false)),
		tag = "AND",
	},
	{ f = disj(fact("a week has eight days", false), fact("the sun is a star", true)), tag = "OR" },
	{ f = prev(1), tag = "MEMORY" },
	{ f = neg(told(1)), tag = "RULES" },
	{ f = conj(prev(1), told(1)), tag = "MEMORY + RULES" },
	{
		f = stmt(this),
		tag = "SELF-REFERENCE",
		lesson = "A statement that only says it is true can be true or false without contradiction.",
	},
	{
		f = neg(me()),
		tag = "SELF-REFERENCE",
		lesson = '"Press if you do not press." Pressing makes the condition false and holding makes it true, so neither works.',
	},
	{
		f = stmt(neg(this)),
		tag = "SELF-REFERENCE",
		lesson = "The liar paradox. If the statement is true it must be false, and if it's false it must be true.",
	},
	{
		f = stmt(conj(neg(this), prev(1))),
		tag = "SELF-REFERENCE + MEMORY",
		lesson = "This paradox only exists if you pressed last round. What you did then decides whether it can be solved.",
	},
	{ f = prev(1), tag = "MEMORY" },
	{ f = told(1), tag = "RULES" },
	{ f = one(prev(1), told(1)), tag = "EXACTLY ONE" },
	{
		f = conj(neg(prev(1)), stmt(this)),
		tag = "FINAL",
		lesson = "If you pressed last round, the answer is forced. If you didn't, the self-referential part leaves you free.",
	},
}

return { tutorial = tutorial, run = run }
