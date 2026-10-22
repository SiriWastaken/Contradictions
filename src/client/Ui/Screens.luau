--!strict
-- Full-screen text screens: main menu, first-time offer, ready, survived and game over.
-- One composition for all of them: a left-hand column over the dimmed stage, title first, the fire/water
-- rule under it, text, then options. Options are type with a bar, not boxes; the single solid slab is
-- reserved for the action that matters most.

local Theme = require(script.Parent.Theme)

local c, font, new, text, tween = Theme.color, Theme.font, Theme.new, Theme.text, Theme.tween

export type Actions = {
	play: () -> (), -- Play on the menu
	tutorial: () -> (), -- start the tutorial (How to play, Play tutorial, Practice again)
	skipTutorial: () -> (), -- skip it and start a run
	run: () -> (), -- start a run (Start, Restart, Play again)
	menu: () -> (),
	toggleFlashing: () -> boolean, -- returns the new "reduce flashing" state
}

export type Screens = {
	hide: () -> (),
	isOpen: () -> boolean,
	menu: (status: string?, reducedFlashing: boolean) -> (),
	offer: () -> (),
	ready: () -> (),
	survived: (result: { [string]: any }) -> (),
	gameOver: (result: { [string]: any }, round: { [string]: any }, reducedFlashing: boolean) -> (),
}

local Screens = {}

local function thousands(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function rich(color: Color3, s: string): string
	return ('<font color="%s">%s</font>'):format(Theme.hex(color), s)
end

-- Press commands burn; "do not press" is water. The condition stays bone.
function Screens.styleDirective(s: string): string
	if s:match("^Do not press the button%.?$") then
		return rich(c.mint, s)
	end
	local rest = s:match("^Press the button(.*)$")
	if rest then
		return rich(c.ember, "Press the button") .. rest
	end
	return s
end

function Screens.new(gui: ScreenGui, actions: Actions, onShow: () -> ()): Screens
	local screen = new("Frame", {
		Name = "Screen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = c.ink,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Active = true, -- swallows clicks so nothing underneath can be pressed
		Visible = false,
		Parent = gui,
	})
	local column = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.08, 0.5),
		Size = UDim2.new(0.84, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		new("UISizeConstraint", { MaxSize = Vector2.new(600, 9999) }),
		new("UIListLayout", { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local function open(dim: number)
		for _, child in column:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		order = 0
		screen.BackgroundTransparency = dim
		onShow()
		screen.Visible = true
	end

	local function title(s: string, color: Color3, size: number): TextLabel
		local t = text({
			Size = UDim2.new(1, 0, 0, size + 8),
			Text = s,
			TextScaled = true,
			FontFace = font.displayBold,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = nextOrder(),
			Parent = column,
		})
		new("UITextSizeConstraint", { MaxTextSize = size, Parent = t })
		return t
	end

	local function rule(width: UDim)
		Theme.rule(column, width, nextOrder())
	end

	local function paragraph(s: string, color: Color3?, size: number?)
		text({
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = s,
			TextSize = size or 18,
			TextWrapped = true,
			RichText = true,
			TextColor3 = color or c.ash,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = nextOrder(),
			Parent = column,
		})
	end

	local function stat(label: string, value: string)
		local row = new("Frame", {
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
			Parent = column,
		})
		text({
			Size = UDim2.fromScale(0.5, 1),
			Text = label,
			TextSize = 14,
			TextColor3 = c.ash,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			Parent = row,
		})
		text({
			Size = UDim2.fromScale(0.5, 1),
			Position = UDim2.fromScale(0.5, 0),
			Text = value,
			TextSize = 40,
			FontFace = font.displayBold,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			Parent = row,
		})
	end

	local function option(label: string, run: () -> ())
		local btn = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = nextOrder(),
			Parent = column,
		})
		local bar = new("Frame", {
			Size = UDim2.fromOffset(3, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			BackgroundColor3 = c.ember,
			BorderSizePixel = 0,
			Parent = btn,
		})
		local t = text({
			Position = UDim2.fromOffset(20, 0),
			Size = UDim2.new(1, -20, 1, 0),
			Text = label,
			TextSize = 40,
			FontFace = font.displayBold,
			TextColor3 = c.bone,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = btn,
		})
		btn.MouseEnter:Connect(function()
			t.TextColor3 = c.ember
			tween(bar, 0.12, { Size = UDim2.fromOffset(3, 36) })
		end)
		btn.MouseLeave:Connect(function()
			t.TextColor3 = c.bone
			tween(bar, 0.12, { Size = UDim2.fromOffset(3, 0) })
		end)
		btn.Activated:Connect(run)
	end

	-- Flat fill on purpose: a gradient on a TextButton also tints its label.
	local function slab(label: string, run: () -> ())
		local btn = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 80),
			BackgroundColor3 = c.molten,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = label,
			TextSize = 56,
			FontFace = font.displayBold,
			TextColor3 = c.bone,
			LayoutOrder = nextOrder(),
			Parent = column,
		}, {
			new("UIStroke", {
				Color = c.crimson,
				Thickness = 3,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		})
		btn.MouseEnter:Connect(function()
			tween(btn, 0.1, { BackgroundColor3 = c.ember })
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, 0.1, { BackgroundColor3 = c.molten })
		end)
		btn.Activated:Connect(run)
	end

	local self = {} :: Screens

	function self.hide()
		screen.Visible = false
	end

	function self.isOpen(): boolean
		return screen.Visible
	end

	function self.menu(status: string?, reducedFlashing: boolean)
		open(0.3)
		title("Contradictions", c.bone, 84)
		rule(UDim.new(1, 0))
		paragraph(
			"Read the instruction. Press the button, or don't.\nYou have five seconds.",
			c.ash,
			20
		)
		if status == nil then
			paragraph("reading the record...", c.ash, 16)
			return
		end
		option("Play", actions.play)
		option("How to play", actions.tutorial)
		local toggle = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = nextOrder(),
			Parent = column,
		})
		local label = text({
			Size = UDim2.fromScale(1, 1),
			Text = "",
			TextSize = 16,
			TextColor3 = c.ash,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = toggle,
		})
		local function paint(reduced: boolean)
			label.Text = "Flashing effects: " .. (if reduced then "reduced" else "full")
		end
		paint(reducedFlashing)
		toggle.Activated:Connect(function()
			paint(actions.toggleFlashing())
		end)
		toggle.MouseEnter:Connect(function()
			label.TextColor3 = c.ember
		end)
		toggle.MouseLeave:Connect(function()
			label.TextColor3 = c.ash
		end)
		if status == "unavailable" then
			paragraph(
				"Saved progress could not be loaded, so the tutorial will not be offered or remembered this session.",
				c.ash,
				14
			)
		end
	end

	function self.offer()
		open(0.3)
		title("First time?", c.ember, 80)
		rule(UDim.new(0, 160))
		paragraph(
			"Four practice rounds teach the rules: the five seconds, press or hold, and what a wrong decision costs. Nothing in them is scored and nothing in them can kill you.",
			c.ash
		)
		option("Play tutorial", actions.tutorial)
		option("Skip tutorial", actions.skipTutorial)
	end

	function self.ready()
		open(0.3)
		title("Ready", c.acid, 88)
		rule(UDim.new(0, 160))
		paragraph(
			"From here the instructions get harder. Some refer to themselves. Some have two right answers. A few have none. A wrong decision ends the run.",
			c.ash
		)
		option("Start", actions.run)
		option("Practice again", actions.tutorial)
	end

	function self.survived(r: { [string]: any })
		open(0.2)
		title("Survived", c.acid, 88)
		rule(UDim.new(0, 160))
		paragraph("Every round answered. Some of them could not be answered at all.", c.ash)
		stat("SCORE", thousands(r.score))
		stat("BEST", thousands(r.best))
		stat("PARADOXES MET", tostring(r.paradoxes))
		slab("Play again", actions.run)
		option("Menu", actions.menu)
	end

	function self.gameOver(r: { [string]: any }, round: { [string]: any }, reducedFlashing: boolean)
		open(0.12)
		local t = title("Game over", c.molten, 96)
		if not reducedFlashing then
			-- Ragged flicker as it lands, then steady.
			task.spawn(function()
				for _, tr in { 1, 0, 1, 0.4, 1, 0 } do
					t.TextTransparency = tr
					task.wait(0.06)
				end
			end)
		end
		rule(UDim.new(0, 160))
		paragraph(("Round %d of %d."):format(r.index, round.total), c.ash)
		paragraph(Screens.styleDirective(round.directive), c.bone, 22)
		if round.statement then
			paragraph(rich(c.acid, "“" .. round.statement .. "”"), c.bone, 20)
		end
		local did = if r.pressed
			then "You pressed."
			elseif r.timedOut then "You did nothing."
			else "You held."
		paragraph(rich(c.molten, did) .. " " .. r.lines[#r.lines], c.ash, 16)
		stat("SCORE", thousands(r.score))
		stat("BEST", thousands(r.best))
		slab("Restart", actions.run)
		option("Menu", actions.menu)
	end

	return self
end

return Screens
