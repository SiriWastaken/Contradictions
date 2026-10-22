--!strict
-- Run from the repo root: luau tests/run.luau
local failed = 0
local total = 0

local function test(name: string, fn: () -> ())
	total += 1
	local ok, err = pcall(fn)
	if not ok then
		failed += 1
		print(("FAIL %s: %s"):format(name, tostring(err)))
	end
end

require("./Rules.spec")(test)
require("./Rounds.spec")(test)
require("./Profile.spec")(test)

print(("%d/%d passed"):format(total - failed, total))
if failed > 0 then
	error("tests failed")
end
