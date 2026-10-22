--!strict
-- TEST_PLAN U1-U4: the responsive rules, from desktop down to a small phone in portrait.
local Layout = require("../src/shared/Logic/Layout")

return function(test: (string, () -> ()) -> ())
	test("U1 bar is full size on desktop and shrinks to a floor on narrow screens", function()
		assert(Layout.barScale(1920) == 1 and Layout.barScale(960) == 1)
		assert(math.abs(Layout.barScale(480) - 0.55) < 1e-9, "floor")
		assert(math.abs(Layout.barScale(720) - 0.75) < 1e-9)
	end)
	test("U2 block starts below the scaled bar", function()
		assert(Layout.blockTop(1) == 104)
		assert(Layout.blockTop(0.55) < Layout.blockTop(1))
	end)
	test("U3 block never overlaps the button when there is room", function()
		for _, size in { { 1920, 1080 }, { 1366, 768 }, { 844, 390 }, { 390, 844 }, { 360, 640 } } do
			local w, h = size[1], size[2]
			local top = Layout.blockTop(Layout.barScale(w))
			local buttonTop = h * 0.52 -- the 3D button sits about here at the fixed camera
			local height = Layout.blockHeight(h, top, buttonTop)
			assert(height >= Layout.MIN_BLOCK)
			if buttonTop - top - Layout.MARGIN >= Layout.MIN_BLOCK then
				assert(
					top + height <= buttonTop - Layout.MARGIN + 1,
					("%dx%d overlaps"):format(w, h)
				)
			end
		end
	end)
	test("U4 block is capped at 38% of the height on tall screens", function()
		assert(Layout.blockHeight(1000, 104, 900) == 380)
	end)
end
