--!strict
-- Pure-Luau rule engine. No Roblox APIs, so tests run under the plain luau CLI. See LOGIC_SPEC.md.
--
-- An instruction is an expression F meaning "press the button iff F is true". Two unknowns are
-- solved by brute force: d (this round's decision) and x (the truth value of the on-screen
-- statement, if the instruction has one). A decision d is acceptable iff some x makes both hold:
--   statement body:  x == eval(body, d, x)       (the statement is true exactly when what it says holds)
--   instruction:     d == eval(F, d, x)

export type Expr = {
	op: string,
	v: boolean?,
	k: number?,
	text: string?,
	a: Expr?,
	b: Expr?,
}
export type Entry = { pressed: boolean, required: boolean? }
export type History = { Entry }
export type Kind = "unique" | "multiple" | "none"
-- press/hold: that decision is logically consistent. required: the one acceptable decision when unique.
export type Outcome = { kind: Kind, press: boolean, hold: boolean, required: boolean? }

local Rules = {}

Rules.MAX_DEPTH = 6
Rules.MAX_LOOKBACK = 3

local function entryAt(hist: History, k: number): Entry
	local e = hist[#hist + 1 - k]
	assert(e, "history reference out of range")
	return e
end

local function eval(e: Expr, hist: History, d: boolean, x: boolean): boolean
	local op = e.op
	if op == "const" or op == "fact" then
		return e.v :: boolean
	elseif op == "press" then
		return d
	elseif op == "this" or op == "stmt" then
		return x
	elseif op == "prev" then
		return entryAt(hist, e.k :: number).pressed
	elseif op == "told" then
		local required = entryAt(hist, e.k :: number).required
		assert(required ~= nil, "told() refers to a round with no single required decision")
		return required :: boolean
	elseif op == "not" then
		return not eval(e.a :: Expr, hist, d, x)
	end
	local a, b = eval(e.a :: Expr, hist, d, x), eval(e.b :: Expr, hist, d, x)
	if op == "and" then
		return a and b
	elseif op == "or" then
		return a or b
	elseif op == "xor" then
		return a ~= b
	end
	error("unknown op " .. tostring(op))
end

-- The (single) statement node in F, if any.
local function findStmt(e: Expr): Expr?
	if e.op == "stmt" then
		return e
	end
	if e.a then
		local found = findStmt(e.a)
		if found then
			return found
		end
	end
	if e.b then
		return findStmt(e.b)
	end
	return nil
end

local function uses(e: Expr, op: string): boolean
	return e.op == op or (e.a ~= nil and uses(e.a, op)) or (e.b ~= nil and uses(e.b, op))
end

-- Error string, or nil if well formed. Leaves have depth 0.
local function check(e: any, depth: number, inBody: boolean, counts: { stmt: number }): string?
	if typeof(e) ~= "table" or typeof(e.op) ~= "string" then
		return "malformed expression"
	end
	local op = e.op
	if op == "const" then
		return if typeof(e.v) == "boolean" then nil else "const needs v"
	elseif op == "fact" then
		return if typeof(e.v) == "boolean" and typeof(e.text) == "string"
			then nil
			else "fact needs v and text"
	elseif op == "press" then
		return nil
	elseif op == "this" then
		return if inBody then nil else "'this' outside a statement"
	elseif op == "prev" or op == "told" then
		local k = e.k
		if typeof(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > Rules.MAX_LOOKBACK then
			return op .. " lookback out of range"
		end
		return nil
	end
	if depth + 1 > Rules.MAX_DEPTH then
		return "expression too deep"
	end
	if op == "stmt" then
		if inBody then
			return "nested statement"
		end
		counts.stmt += 1
		if counts.stmt > 1 then
			return "more than one statement"
		end
		return check(e.a, depth + 1, true, counts)
	elseif op == "not" then
		return check(e.a, depth + 1, inBody, counts)
	elseif op == "and" or op == "or" or op == "xor" then
		return check(e.a, depth + 1, inBody, counts) or check(e.b, depth + 1, inBody, counts)
	end
	return "unknown op " .. op
end

function Rules.validate(f: Expr): (boolean, string?)
	local err = check(f, 0, false, { stmt = 0 })
	return err == nil, err
end

-- Brute force over (d, x). Deterministic; never runs instruction text as code.
function Rules.solve(f: Expr, hist: History): Outcome
	local stmt = findStmt(f)
	local body = if stmt then stmt.a else nil
	local ok = { [false] = false, [true] = false }
	for _, d in { false, true } do
		for _, x in if body then { false, true } else { false } do
			local statementHolds = body == nil or eval(body, hist, d, x) == x
			if statementHolds and eval(f, hist, d, x) == d then
				ok[d] = true
			end
		end
	end
	local kind: Kind = if ok[true] and ok[false]
		then "multiple"
		elseif ok[true] or ok[false] then "unique"
		else "none"
	return {
		kind = kind,
		press = ok[true],
		hold = ok[false],
		required = if kind == "unique" then ok[true] else nil,
	}
end

Rules.eval = eval
Rules.findStmt = findStmt
Rules.uses = uses

return Rules
