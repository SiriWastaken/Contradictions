--!strict
-- Turns instruction expressions and outcomes into player-facing English. Pure Luau.

-- selene: allow(incorrect_standard_library_use)
local Rules = require("./Rules")
type Expr = Rules.Expr

local Render = {}

local WHEN = { "last round", "two rounds ago", "three rounds ago" }
local WHICH = {
	"the previous instruction",
	"the instruction two rounds ago",
	"the instruction three rounds ago",
}

local function cap(s: string): string
	return s:sub(1, 1):upper() .. s:sub(2)
end

local function atom(e: Expr, neg: boolean): string?
	local op = e.op
	if op == "fact" then
		return if neg then "it is not true that " .. (e.text :: string) else e.text :: string
	elseif op == "press" then
		return if neg then "you do not press the button" else "you press the button"
	elseif op == "prev" then
		return (if neg then "you did not press the button " else "you pressed the button ")
			.. WHEN[e.k :: number]
	elseif op == "told" then
		return WHICH[e.k :: number]
			.. " told you "
			.. (if neg then "not to press" else "to press")
			.. " the button"
	elseif op == "this" then
		return "this statement is " .. (if neg then "false" else "true")
	elseif op == "stmt" then
		return "the statement below is " .. (if neg then "false" else "true")
	end
	return nil
end

local function phrase(e: Expr, neg: boolean, nested: boolean): string
	local a = atom(e, neg)
	if a then
		return a
	end
	if e.op == "not" then
		return phrase(e.a :: Expr, not neg, nested)
	end
	local text: string
	if e.op == "xor" then
		text = "exactly one of these is true: "
			.. phrase(e.a :: Expr, false, true)
			.. "; "
			.. phrase(e.b :: Expr, false, true)
	else
		text = phrase(e.a :: Expr, false, true)
			.. " "
			.. e.op
			.. " "
			.. phrase(e.b :: Expr, false, true)
	end
	if neg then
		return "it is not the case that (" .. text .. ")"
	end
	return if nested then "(" .. text .. ")" else text
end

function Render.directive(f: Expr): string
	if f.op == "const" then
		return if f.v then "Press the button." else "Do not press the button."
	end
	return "Press the button if " .. phrase(f, false, false) .. "."
end

-- The quoted statement shown under the directive, or nil when the instruction has none.
function Render.statement(f: Expr): string?
	local stmt = Rules.findStmt(f)
	if not stmt then
		return nil
	end
	return cap(phrase(stmt.a :: Expr, false, false)) .. "."
end

local function collectFacts(e: Expr, out: { Expr }, seen: { [string]: boolean })
	local key = e.op .. tostring(e.k) .. tostring(e.text)
	if (e.op == "fact" or e.op == "prev" or e.op == "told") and not seen[key] then
		seen[key] = true
		table.insert(out, e)
	end
	if e.op ~= "stmt" then
		if e.a then
			collectFacts(e.a, out, seen)
		end
		if e.b then
			collectFacts(e.b, out, seen)
		end
	end
end

-- Explanation lines shown after a round. Lines come from the solver's own result, never from a script.
function Render.explain(f: Expr, hist: Rules.History, outcome: Rules.Outcome): { string }
	local lines = {}
	if f.op == "const" then
		table.insert(lines, "The instruction is unconditional.")
	elseif Rules.findStmt(f) or Rules.uses(f, "press") then
		table.insert(
			lines,
			("Pressing: %s."):format(
				if outcome.press then "consistent with the rule" else "contradicts the rule"
			)
		)
		table.insert(
			lines,
			("Doing nothing: %s."):format(
				if outcome.hold then "consistent with the rule" else "contradicts the rule"
			)
		)
	else
		local facts: { Expr } = {}
		collectFacts(f, facts, {})
		for _, fact in facts do
			local value = Rules.eval(fact, hist, false, false)
			table.insert(
				lines,
				("%s: %s"):format(
					cap(atom(fact, false) :: string),
					if value then "true" else "false"
				)
			)
		end
		table.insert(
			lines,
			if outcome.press
				then "So the condition holds: press."
				else "So the condition fails: do not press."
		)
	end
	if outcome.kind == "multiple" then
		table.insert(lines, "Both decisions are consistent, so either one is correct.")
	elseif outcome.kind == "none" then
		table.insert(lines, "No decision is consistent. This is a paradox: nothing is deducted.")
	elseif f.op ~= "const" and (Rules.findStmt(f) or Rules.uses(f, "press")) then
		table.insert(
			lines,
			("Only %s is consistent."):format(if outcome.press then "pressing" else "doing nothing")
		)
	end
	return lines
end

return Render
