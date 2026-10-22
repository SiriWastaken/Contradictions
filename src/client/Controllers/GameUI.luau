--!strict
-- The game as the player sees it: HUD, instruction, the red button, tutorial, menu, death and game over.
-- The server decides everything that matters; this module renders and forwards presses.
-- Composition rule: fire (ember) owns the command and the clock, water (acid/mint) owns statements and
-- survival. The left-hand rule beside the instruction is split the same way: command above, answer below.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Jumpscare = require(script.Parent.Jumpscare)
local Scene = require(script.Parent.Scene)
local Theme = require(script.Parent.Parent.Theme)

local c, font, new, text, tween = Theme.color, Theme.font, Theme.new, Theme.text, Theme.tween

local BUTTON_FILL = 0.8 -- GUI cap diameter relative to the 3D cap, so the 3D rim stays visible and clickable

local GameUI = {}

local function thousands(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function rich(color: Color3, s: string): string
	return ('<font color="%s">%s</font>'):format(Theme.hex(color), s)
end

-- Press commands burn; "do not press" is water. The condition stays bone.
local function styleDirective(s: string): string
	local hold = s:match("^Do not press the button%.?$")
	if hold then
		return rich(c.mint, s)
	end
	local rest = s:match("^Press the button(.*)$")
	if rest then
		return rich(c.ember, "Press the button") .. rest
	end
	return s
end

function GameUI.start()
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local startEvent = remotes:WaitForChild("Start") :: RemoteEvent
	local decideEvent = remotes:WaitForChild("Decide") :: RemoteEvent
	local nextEvent = remotes:WaitForChild("Next") :: RemoteEvent
	local onboardEvent = remotes:WaitForChild("Onboard") :: RemoteEvent
	local roundEvent = remotes:WaitForChild("Round") :: RemoteEvent
	local resultEvent = remotes:WaitForChild("Result") :: RemoteEvent
	local finishedEvent = remotes:WaitForChild("Finished") :: RemoteEvent
	local getProfile = remotes:WaitForChild("GetProfile") :: RemoteFunction

	for _ = 1, 10 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false) then
			break
		end
		task.wait(0.2)
	end
	Scene.attach()

	local gui = new("ScreenGui", {
		Name = "Contradictions",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	------------------------------------------------------------------ HUD
	local hud = new(
		"Frame",
		{
			Name = "HUD",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = gui,
		}
	)

	-- The fuse: fire burning down across a toxic track. It is the countdown's shape; the number is its value.
	local fuseTrack = new(
		"Frame",
		{
			Size = UDim2.new(1, 0, 0, 4),
			BackgroundColor3 = c.forest,
			BorderSizePixel = 0,
			Parent = hud,
		}
	)
	local fuseFill = new(
		"Frame",
		{
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = c.ember,
			BorderSizePixel = 0,
			Parent = fuseTrack,
		}
	)
	local fuseTip = new(
		"Frame",
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(10, 12),
			Position = UDim2.fromScale(1, 0.5),
			BackgroundColor3 = c.bone,
			BorderSizePixel = 0,
			Parent = fuseTrack,
		}
	)

	local leftCaption = text({
		Position = UDim2.fromOffset(24, 16),
		Size = UDim2.fromOffset(200, 16),
		Text = "ROUND",
		TextSize = 14,
		TextColor3 = c.ash,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = hud,
	})
	local leftValue = text({
		Position = UDim2.fromOffset(24, 30),
		Size = UDim2.fromOffset(240, 56),
		Text = "",
		TextSize = 56,
		FontFace = font.displayBold,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = hud,
	})
	local rightCaption = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 16),
		Size = UDim2.fromOffset(240, 16),
		Text = "SCORE",
		TextSize = 14,
		TextColor3 = c.ash,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = hud,
	})
	local rightValue = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 30),
		Size = UDim2.fromOffset(300, 56),
		Text = "0",
		TextSize = 56,
		FontFace = font.displayBold,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = hud,
	})
	local skipButton = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 30),
		Size = UDim2.fromOffset(160, 40),
		BackgroundTransparency = 1,
		Text = "SKIP",
		TextSize = 22,
		FontFace = font.type,
		TextColor3 = c.ash,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		Parent = hud,
	})
	skipButton.MouseEnter:Connect(function()
		skipButton.TextColor3 = c.ember
	end)
	skipButton.MouseLeave:Connect(function()
		skipButton.TextColor3 = c.ash
	end)
	local timerLabel = text({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.fromOffset(200, 64),
		Text = "5.0",
		TextSize = 56,
		Parent = hud,
	})

	------------------------------------------------------------------ Instruction block
	local block = new("Frame", {
		Name = "Instruction",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.new(0.84, 0, 0.38, 0),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = hud,
	}, { new("UISizeConstraint", { MaxSize = Vector2.new(900, 9999) }) })
	local note = text({
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
		TextSize = 14,
		TextColor3 = c.ash,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = block,
	})
	local body = new(
		"Frame",
		{
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.new(1, 0, 1, -28),
			BackgroundTransparency = 1,
			Parent = block,
		}
	)
	new(
		"Frame",
		{
			Size = UDim2.new(0, 2, 0.5, -6),
			BackgroundColor3 = c.ember,
			BorderSizePixel = 0,
			Parent = body,
		}
	)
	new(
		"Frame",
		{
			Position = UDim2.new(0, 0, 0.5, 6),
			Size = UDim2.new(0, 2, 0.5, -6),
			BackgroundColor3 = c.acid,
			BorderSizePixel = 0,
			Parent = body,
		}
	)

	local directive = text({
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -24, 0.5, -6),
		Text = "",
		TextScaled = true,
		TextWrapped = true,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = body,
	})
	new("UITextSizeConstraint", { MaxTextSize = 40, MinTextSize = 14, Parent = directive })

	local lower = new(
		"Frame",
		{
			Position = UDim2.new(0, 24, 0.5, 6),
			Size = UDim2.new(1, -24, 0.5, -6),
			BackgroundTransparency = 1,
			Parent = body,
		}
	)
	local quote = text({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = c.acid,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Visible = false,
		Parent = lower,
	})
	new("UITextSizeConstraint", { MaxTextSize = 30, MinTextSize = 12, Parent = quote })
	local coach = text({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = c.mint,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Visible = false,
		Parent = lower,
	})
	new("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 12, Parent = coach })
	local verdict = text({
		Size = UDim2.new(1, -150, 0.36, 0),
		Text = "",
		TextScaled = true,
		FontFace = font.displayBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		Parent = lower,
	})
	new("UITextSizeConstraint", { MaxTextSize = 36, MinTextSize = 16, Parent = verdict })
	local detail = text({
		Position = UDim2.fromScale(0, 0.4),
		Size = UDim2.fromScale(1, 0.6),
		Text = "",
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = c.ash,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Visible = false,
		Parent = lower,
	})
	new("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 11, Parent = detail })
	local continueButton = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(140, 32),
		BackgroundTransparency = 1,
		Text = "CONTINUE",
		TextSize = 18,
		FontFace = font.type,
		TextColor3 = c.bone,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		Parent = lower,
	})
	continueButton.MouseEnter:Connect(function()
		continueButton.TextColor3 = c.ember
	end)
	continueButton.MouseLeave:Connect(function()
		continueButton.TextColor3 = c.bone
	end)

	------------------------------------------------------------------ The button
	local capStroke = new(
		"UIStroke",
		{
			Color = Color3.fromRGB(58, 6, 6),
			Thickness = 4,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}
	)
	local heartbeat = new(
		"UIStroke",
		{
			Color = c.ember,
			Thickness = 2,
			Transparency = 0.7,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}
	)
	local button = new("TextButton", {
		Name = "PressButton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(200, 200),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = hud,
	}, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, c.ember),
				ColorSequenceKeypoint.new(0.45, c.molten),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(88, 8, 8)),
			}),
			Rotation = 90,
		}),
		capStroke,
	})
	-- Inner ring: the heartbeat. Slow when calm, frantic as the clock dies.
	new(
		"Frame",
		{
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.78, 0.78),
			BackgroundTransparency = 1,
			Active = false,
			Parent = button,
		},
		{
			new("UICorner", { CornerRadius = UDim.new(1, 0) }),
			heartbeat,
		}
	)
	local pressLabel = text({
		Size = UDim2.fromScale(1, 0.3),
		Position = UDim2.fromScale(0, 0.34),
		Text = "PRESS",
		TextScaled = true,
		FontFace = font.displayBold,
		TextColor3 = c.bone,
		Parent = button,
	})
	new("UITextSizeConstraint", { MaxTextSize = 72, Parent = pressLabel })
	local flash = new(
		"Frame",
		{
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = c.bone,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Active = false,
			Parent = button,
		},
		{ new("UICorner", { CornerRadius = UDim.new(1, 0) }) }
	)
	local buttonSize = 200

	local function layoutButton()
		local centre, diameter = Scene.buttonRect()
		buttonSize = math.floor(diameter * BUTTON_FILL)
		button.Size = UDim2.fromOffset(buttonSize, buttonSize)
		button.Position = UDim2.fromOffset(centre.X, centre.Y)
	end
	layoutButton()
	Scene.onViewportChanged(layoutButton)

	------------------------------------------------------------------ Screens (menu, offer, game over, ...)
	local screen = new(
		"Frame",
		{
			Name = "Screen",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = c.ink,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Active = true,
			Visible = false,
			Parent = gui,
		}
	)
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

	local function clearColumn(dim: number)
		for _, child in column:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		order = 0
		screen.BackgroundTransparency = dim
		hud.Visible = false
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
	local function paragraph(s: string, color: Color3?, size: number?): TextLabel
		return text({
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
		local row = new(
			"Frame",
			{
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
				LayoutOrder = nextOrder(),
				Parent = column,
			}
		)
		text({
			Size = UDim2.new(0.5, 0, 1, 0),
			Text = label,
			TextSize = 14,
			TextColor3 = c.ash,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			Parent = row,
		})
		text({
			Size = UDim2.new(0.5, 0, 1, 0),
			Position = UDim2.fromScale(0.5, 0),
			Text = value,
			TextSize = 40,
			FontFace = font.displayBold,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
	end

	-- Text-first option: no box. A bar and the ember colour say "this one".
	local function option(label: string, run: () -> ()): TextButton
		local btn = new(
			"TextButton",
			{
				Size = UDim2.new(1, 0, 0, 56),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = nextOrder(),
				Parent = column,
			}
		)
		local bar = new(
			"Frame",
			{
				Size = UDim2.new(0, 3, 0, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				BackgroundColor3 = c.ember,
				BorderSizePixel = 0,
				Parent = btn,
			}
		)
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
			tween(bar, 0.12, { Size = UDim2.new(0, 3, 0, 36) })
		end)
		btn.MouseLeave:Connect(function()
			t.TextColor3 = c.bone
			tween(bar, 0.12, { Size = UDim2.new(0, 3, 0, 0) })
		end)
		btn.Activated:Connect(run)
		return btn
	end

	-- The one solid slab in the interface: reserved for the action that matters most after dying.
	local function slab(label: string, run: () -> ())
		local btn = new(
			"TextButton",
			{
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
			},
			{
				new(
					"UIStroke",
					{
						Color = c.crimson,
						Thickness = 3,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}
				),
				new("UIGradient", { Color = ColorSequence.new(c.ember, c.molten), Rotation = 90 }),
			}
		)
		btn.MouseEnter:Connect(function()
			tween(btn, 0.1, { BackgroundColor3 = c.ember })
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, 0.1, { BackgroundColor3 = c.molten })
		end)
		btn.Activated:Connect(run)
	end

	------------------------------------------------------------------ Round state
	local current: { [string]: any }? = nil
	local state = "menu" -- menu | active | review | waiting | dead
	local locked = false
	local profile: { [string]: any }? = nil
	local startMode: (string) -> ()
	local showMenu: () -> ()

	local function setButton(label: string, dim: boolean, labelColor: Color3?)
		pressLabel.Text = label
		pressLabel.TextColor3 = labelColor or c.bone
		tween(button, 0.15, { BackgroundTransparency = if dim then 0.55 else 0 })
	end

	local function pulse()
		Scene.pressCap()
		tween(button, 0.05, { Size = UDim2.fromOffset(buttonSize * 0.9, buttonSize * 0.9) })
		flash.BackgroundTransparency = 0.5
		tween(flash, 0.35, { BackgroundTransparency = 1 })
		task.delay(0.07, function()
			tween(
				button,
				0.28,
				{ Size = UDim2.fromOffset(buttonSize, buttonSize) },
				Enum.EasingStyle.Back
			)
		end)
	end

	local function decide()
		local round = current
		if state ~= "active" or locked or not round then
			return
		end
		if workspace:GetServerTimeNow() < round.startedAt + round.lockout then
			return
		end
		locked = true
		pulse()
		setButton("PRESSED", true)
		decideEvent:FireServer(round.token)
	end
	button.Activated:Connect(decide)
	button.MouseEnter:Connect(function()
		if state == "active" and not locked then
			capStroke.Color = c.bone
		end
	end)
	button.MouseLeave:Connect(function()
		capStroke.Color = Color3.fromRGB(58, 6, 6)
	end)

	local function advance()
		local round = current
		if state == "review" and round and round.mode == "tutorial" then
			nextEvent:FireServer(round.token)
		end
	end
	continueButton.Activated:Connect(advance)
	skipButton.Activated:Connect(function()
		startMode("run")
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space then
			decide()
		elseif input.KeyCode == Enum.KeyCode.Return then
			advance()
		end
	end)

	local rng = Random.new()
	RunService.RenderStepped:Connect(function()
		local round = current
		if state ~= "active" or not round then
			Scene.setHeat(0, false)
			return
		end
		local left = round.endsAt - workspace:GetServerTimeNow()
		local frac = math.clamp(left / Config.ROUND_SECONDS, 0, 1)
		timerLabel.Text = string.format("%.1f", math.max(left, 0))
		fuseFill.Size = UDim2.fromScale(frac, 1)
		fuseTip.Position = UDim2.fromScale(frac, 0.5)
		fuseTip.BackgroundTransparency = rng:NextNumber(0, 0.45)
		local urgent = if left > 3 then c.bone elseif left > 1.5 then c.ember else c.molten
		timerLabel.TextColor3 = urgent
		fuseFill.BackgroundColor3 = if left > 1.5 then c.ember else c.molten
		Scene.setHeat(1 - frac, true)
		if not locked then
			local speed = 2.4 + (1 - frac) * 7
			heartbeat.Transparency = 0.8 - 0.45 * (0.5 + 0.5 * math.sin(os.clock() * speed))
		end
		if left <= 0 and not locked then
			locked = true
			setButton("TIME", true)
		end
	end)

	local function setLower(which: string?)
		quote.Visible = which == "quote"
		coach.Visible = which == "coach"
		verdict.Visible = which == "result"
		detail.Visible = which == "result"
		continueButton.Visible = which == "result" and current ~= nil and current.mode == "tutorial"
	end

	local function showRound(r: { [string]: any })
		current = r
		state = "active"
		locked = false
		screen.Visible = false
		hud.Visible = true
		block.Visible = true
		button.Visible = true
		local tutorial = r.mode == "tutorial"
		note.Text = if r.tag then "— " .. r.tag else ""
		directive.Text = styleDirective(r.directive)
		if r.statement then
			quote.Text = "“" .. r.statement .. "”"
			setLower("quote")
		elseif r.coach then
			coach.Text = r.coach
			setLower("coach")
		else
			setLower(nil)
		end
		leftCaption.Text = if tutorial then "PRACTICE" else "ROUND"
		local fraction =
			string.format("<font size='28' color='%s'>/%d</font>", Theme.hex(c.ash), r.total)
		if tutorial then
			leftValue.Text = string.format("%d", r.index) .. fraction
			rightCaption.Visible = false
			rightValue.Visible = false
		else
			leftValue.Text = string.format("%02d", r.index) .. fraction
			rightCaption.Visible = true
			rightValue.Visible = true
			rightCaption.Text = if r.streak > 1 then ("SCORE   x%d"):format(r.streak) else "SCORE"
			rightValue.Text = thousands(r.score)
		end
		skipButton.Visible = tutorial
		timerLabel.Text = string.format("%.1f", Config.ROUND_SECONDS)
		timerLabel.TextColor3 = c.bone
		fuseFill.Size = UDim2.fromScale(1, 1)
		fuseFill.BackgroundColor3 = c.ember
		setButton("PRESS", false)
	end

	local function showGameOver(r: { [string]: any }, round: { [string]: any })
		clearColumn(0.12)
		local t = title("GAME OVER", c.molten, 96)
		-- Ragged flicker as it lands, then steady.
		task.spawn(function()
			for _, tr in { 1, 0, 1, 0.4, 1, 0 } do
				t.TextTransparency = tr
				task.wait(0.06)
			end
		end)
		Theme.rule(column, UDim.new(0, 160), nextOrder())
		paragraph(("Round %d of %d."):format(r.index, round.total), c.ash)
		paragraph(styleDirective(round.directive), c.bone, 22)
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
		slab("RESTART", function()
			startMode("run")
		end)
		option("MENU", function()
			showMenu()
		end)
		state = "dead"
	end

	local function showResult(r: { [string]: any })
		local round = current
		if not round or r.token ~= round.token then
			return
		end
		state = "review"
		if r.pressed and not locked then
			pulse() -- the press came from the world button
		end
		locked = true
		setButton(
			if r.pressed then "PRESSED" else "HELD",
			true,
			if r.pressed then c.bone else c.mint
		)

		if r.died then
			-- One death, one jumpscare: state leaves "review" for "dead" before anything can run again.
			state = "dead"
			Jumpscare.play(gui, function()
				showGameOver(r, round)
			end)
			return
		end

		local tutorial = r.mode == "tutorial"
		if r.verdict == "correct" then
			verdict.TextColor3 = c.acid
			verdict.Text = if r.delta > 0 then ("SURVIVED  +%d"):format(r.delta) else "CORRECT"
		elseif r.verdict == "paradox" then
			verdict.TextColor3 = c.mint
			verdict.Text = "NO ANSWER EXISTED"
		else
			verdict.TextColor3 = c.molten
			verdict.Text = "WRONG"
		end
		if tutorial then
			local lines = table.clone(r.lines)
			if r.verdict == "wrong" then
				table.insert(lines, 1, "In a real run, that would have killed you.")
			end
			detail.Text = table.concat(lines, "\n")
			continueButton.Text = if r.last then "FINISH" else "CONTINUE"
		elseif r.verdict == "paradox" then
			detail.Text = r.lines[#r.lines - 1] .. "\n" .. r.lines[#r.lines]
			rightValue.Text = thousands(r.score)
		else
			detail.Text = ""
			rightValue.Text = thousands(r.score)
		end
		setLower("result")
	end

	local function showFinished(r: { [string]: any })
		state = "menu"
		current = nil
		button.Visible = false
		block.Visible = false
		if r.mode == "tutorial" then
			if profile then
				profile.hasCompletedTutorial = true
			end
			clearColumn(0.3)
			title("READY", c.acid, 88)
			Theme.rule(column, UDim.new(0, 160), nextOrder())
			paragraph(
				"From here the instructions get harder. Some refer to themselves. Some have two right answers. A few have none. A wrong decision ends the run.",
				c.ash
			)
			option("START", function()
				startMode("run")
			end)
			option("PRACTICE AGAIN", function()
				startMode("tutorial")
			end)
		else
			clearColumn(0.2)
			title("SURVIVED", c.acid, 88)
			Theme.rule(column, UDim.new(0, 160), nextOrder())
			paragraph("Every round answered. Some of them could not be answered at all.", c.ash)
			stat("SCORE", thousands(r.score))
			stat("BEST", thousands(r.best))
			stat("PARADOXES MET", tostring(r.paradoxes))
			slab("PLAY AGAIN", function()
				startMode("run")
			end)
			option("MENU", function()
				showMenu()
			end)
		end
	end

	startMode = function(mode: string)
		state = "waiting"
		current = nil
		screen.Visible = false
		block.Visible = false
		button.Visible = false
		startEvent:FireServer(mode)
	end

	local function showOffer()
		clearColumn(0.3)
		title("FIRST TIME?", c.ember, 80)
		Theme.rule(column, UDim.new(0, 160), nextOrder())
		paragraph(
			"Four practice rounds teach the rules: the five seconds, press or hold, and what a wrong decision costs. Nothing in them is scored and nothing in them can kill you.",
			c.ash
		)
		option("PLAY TUTORIAL", function()
			if profile then
				profile.status = "returning"
			end
			startMode("tutorial")
		end)
		option("SKIP TUTORIAL", function()
			if profile then
				profile.status = "returning"
			end
			onboardEvent:FireServer("skip")
			startMode("run")
		end)
	end

	showMenu = function()
		startEvent:FireServer("menu")
		state = "menu"
		current = nil
		button.Visible = false
		block.Visible = false
		clearColumn(0.3)
		title("CONTRADICTIONS", c.bone, 84)
		Theme.rule(column, UDim.new(1, 0), nextOrder())
		paragraph(
			"Read the instruction. Press the button, or don't.\nYou have five seconds.",
			c.ash,
			20
		)
		local p = profile
		if not p then
			paragraph("reading the record...", c.ash, 16)
			return
		end
		option("PLAY", function()
			if p.status == "new" then
				showOffer()
			else
				startMode("run")
			end
		end)
		option("HOW TO PLAY", function()
			startMode("tutorial")
		end)
		if p.status == "unavailable" then
			paragraph(
				"Saved progress could not be loaded, so the tutorial will not be offered or remembered this session.",
				c.ash,
				14
			)
		end
	end

	roundEvent.OnClientEvent:Connect(showRound)
	resultEvent.OnClientEvent:Connect(showResult)
	finishedEvent.OnClientEvent:Connect(showFinished)

	showMenu()
	task.spawn(function()
		profile = getProfile:InvokeServer()
		if state == "menu" and screen.Visible then
			showMenu()
		end
	end)
end

return GameUI
