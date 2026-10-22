--!strict
-- Viewport maths for the UI, kept pure so the responsive rules can be tested outside Studio.

local Layout = {}

Layout.BAR_HEIGHT = 96 -- design height of the top bar at scale 1
Layout.DESIGN_WIDTH = 960 -- below this width the top bar shrinks to fit
Layout.MIN_SCALE = 0.55
Layout.MIN_BLOCK = 120
Layout.MARGIN = 16

-- The top bar (round, timer, score) is laid out for 960 px; narrower screens scale it down.
function Layout.barScale(viewportWidth: number): number
	return math.clamp(viewportWidth / Layout.DESIGN_WIDTH, Layout.MIN_SCALE, 1)
end

-- Where the instruction block starts, just under the scaled bar.
function Layout.blockTop(scale: number): number
	return math.floor(Layout.BAR_HEIGHT * scale) + 8
end

-- The instruction block takes up to 38% of the height, but never runs into the button below it.
function Layout.blockHeight(viewportHeight: number, top: number, buttonTop: number): number
	local room = buttonTop - top - Layout.MARGIN
	return math.floor(math.max(Layout.MIN_BLOCK, math.min(viewportHeight * 0.38, room)))
end

return Layout
