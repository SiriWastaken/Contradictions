--!strict
-- The round screen and the game's client-side flow: HUD, instruction, the red button, tutorial feedback,
-- death. Full-screen text screens live in Ui/Screens. The server decides everything that matters; this
-- module renders and forwards presses.
-- Composition rule: fire (ember) owns the command and the clock, water (acid/mint) owns statements and
-- survival. The rule beside the instruction is split the same way: command above, answer below.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Layout = require(Shared.Logic.Layout)
local Jumpscare = require(script.Parent.Jumpscare)
local Scene = require(script.Parent.Scene)
local Screens = require(script.Parent.Parent.Ui.Screens)
local Theme = require(script.Parent.Parent.Ui.Theme)

local c, font, new, text, tween = Theme.color, Theme.font, Theme.new, Theme.text, Theme.tween

local BUTTON_FILL = 0.8 -- GUI cap diameter relative to the 3D cap, so the 3D rim stays visible and clickable
local FLICKER_INTERVAL = 0.08 -- the fuse tip re-rolls this often, not every frame

local GameUI = {}

local function thousands(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
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
	local hud = new("Frame", {
		Name = "HUD",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})

	-- The fuse: fire burning down across a toxic track. It is the countdown's shape; the number is its value.
	local fuseTrack = new("Frame", {
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = c.forest,
		BorderSizePixel = 0,
		Parent = hud,
	})
	local fuseFill = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = c.ember,
		BorderSizePixel = 0,
		Parent = fuseTrack,
	})
	local fuseTip = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(10, 12),
		Position = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = c.bone,
		BorderSizePixel = 0,
		Parent = fuseTrack,
	})

	-- Round, timer and score share one bar so narrow screens can scale it as a unit (see Layout.barScale).
	local barScale = new("UIScale", {})
	local bar = new("Frame", {
		Name = "Bar",
		Size = UDim2.new(1, 0, 0, Layout.BAR_HEIGHT),
		BackgroundTransparency = 1,
		Parent = hud,
	}, { barScale })
	local leftCaption = text({
		Position = UDim2.fromOffset(24, 16),
		Size = UDim2.fromOffset(200, 16),
		Text = "ROUND",
		TextSize = 14,
		TextColor3 = c.ash,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bar,
	})
	local leftValue = text({
		Position = UDim2.fromOffset(24, 30),
		Size = UDim2.fromOffset(240, 56),
		Text = "",
		TextSize = 56,
		FontFace = font.displayBold,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bar,
	})
	local rightCaption = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 16),
		Size = UDim2.fromOffset(240, 16),
		Text = "SCORE",
		TextSize = 14,
		TextColor3 = c.ash,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = bar,
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
		Parent = bar,
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
		Parent = bar,
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
		Parent = bar,
	})

	------------------------------------------------------------------ Instruction block
	local block = new("Frame", {
		Name = "Instruction",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.new(0.84, 0, 0, 300),
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
	local body = new("Frame", {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 1, -28),
		BackgroundTransparency = 1,
		Parent = block,
	})
	new("Frame", {
		Size = UDim2.new(0, 2, 0.5, -6),
		BackgroundColor3 = c.ember,
		BorderSizePixel = 0,
		Parent = body,
	})
	local acidRule = new("Frame", {
		Position = UDim2.new(0, 0, 0.5, 6),
		Size = UDim2.new(0, 2, 0.5, -6),
		BackgroundColor3 = c.acid,
		BorderSizePixel = 0,
		Parent = body,
	})

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

	local lower = new("Frame", {
		Position = UDim2.new(0, 24, 0.5, 6),
		Size = UDim2.new(1, -24, 0.5, -6),
		BackgroundTransparency = 1,
		Parent = body,
	})
	local function lowerText(
		color: Color3,
		maxSize: number,
		minSize: number,
		face: Font?
	): TextLabel
		local t = text({
			Size = UDim2.fromScale(1, 1),
			Text = "",
			TextScaled = true,
			TextWrapped = true,
			FontFace = face,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Visible = false,
			Parent = lower,
		})
		new("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = minSize, Parent = t })
		return t
	end
	local quote = lowerText(c.acid, 30, 12, nil)
	local coach = lowerText(c.mint, 20, 12, nil)
	local verdict = lowerText(c.bone, 36, 16, font.displayBold)
	verdict.Size = UDim2.new(1, -150, 0.36, 0)
	local detail = lowerText(c.ash, 18, 11, nil)
	detail.Position = UDim2.fromScale(0, 0.4)
	detail.Size = UDim2.fromScale(1, 0.6)
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
	local capStroke = new("UIStroke", {
		Color = Color3.fromRGB(58, 6, 6),
		Thickness = 4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	local heartbeat = new("UIStroke", {
		Color = c.ember,
		Thickness = 2,
		Transparency = 0.7,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
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
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.78, 0.78),
		BackgroundTransparency = 1,
		Active = false,
		Parent = button,
	}, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		heartbeat,
	})
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
	local flash = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = c.bone,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		Parent = button,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local buttonSize = 200

	-- Everything below the bar is placed relative to the 3D button, so it stays in step with the camera.
	local function layout()
		local viewport = Scene.viewport()
		local centre, diameter = Scene.buttonRect()
		buttonSize = math.floor(diameter * BUTTON_FILL)
		button.Size = UDim2.fromOffset(buttonSize, buttonSize)
		button.Position = UDim2.fromOffset(centre.X, centre.Y)

		local scale = Layout.barScale(viewport.X)
		barScale.Scale = scale
		bar.Size = UDim2.new(1 / scale, 0, 0, Layout.BAR_HEIGHT) -- UIScale shrinks the bar; widen it back
		local top = Layout.blockTop(scale)
		block.Position = UDim2.new(0.5, 0, 0, top)
		block.Size =
			UDim2.new(0.84, 0, 0, Layout.blockHeight(viewport.Y, top, centre.Y - buttonSize / 2))
	end
	layout()
	Scene.onViewportChanged(layout)

	------------------------------------------------------------------ Round state
	local current: { [string]: any }? = nil
	local state = "menu" -- menu | active | review | waiting | dead
	local locked = false
	local profile: { [string]: any }? = nil
	local reducedFlashing = false
	local screens: Screens.Screens
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

	-- Per-frame work only while a round is live; text and colours are touched only when they change.
	local rng = Random.new()
	local lastTenths = -1
	local lastBand = 0
	local sinceFlicker = 0
	RunService.RenderStepped:Connect(function(dt)
		local round = current
		if state ~= "active" or not round then
			Scene.setHeat(0, false)
			return
		end
		local left = round.endsAt - workspace:GetServerTimeNow()
		local frac = math.clamp(left / Config.ROUND_SECONDS, 0, 1)
		fuseFill.Size = UDim2.fromScale(frac, 1)
		fuseTip.Position = UDim2.fromScale(frac, 0.5)
		sinceFlicker += dt
		if sinceFlicker >= FLICKER_INTERVAL then
			sinceFlicker = 0
			fuseTip.BackgroundTransparency = if reducedFlashing
				then 0.2
				else rng:NextNumber(0, 0.45)
		end
		local tenths = math.max(math.floor(left * 10), 0)
		if tenths ~= lastTenths then
			lastTenths = tenths
			timerLabel.Text = string.format("%.1f", tenths / 10)
		end
		local band = if left > 3 then 1 elseif left > 1.5 then 2 else 3
		if band ~= lastBand then
			lastBand = band
			timerLabel.TextColor3 = if band == 1
				then c.bone
				elseif band == 2 then c.ember
				else c.molten
			fuseFill.BackgroundColor3 = if band == 3 then c.molten else c.ember
		end
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
		acidRule.Visible = which ~= nil
		continueButton.Visible = which == "result" and current ~= nil and current.mode == "tutorial"
	end

	local function showRound(r: { [string]: any })
		current = r
		state = "active"
		locked = false
		lastTenths, lastBand = -1, 0
		screens.hide()
		hud.Visible = true
		block.Visible = true
		button.Visible = true
		local tutorial = r.mode == "tutorial"
		note.Text = if r.tag then "— " .. r.tag else ""
		directive.Text = Screens.styleDirective(r.directive)
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
		else
			leftValue.Text = string.format("%02d", r.index) .. fraction
			rightCaption.Text = if r.streak > 1 then ("SCORE   x%d"):format(r.streak) else "SCORE"
			rightValue.Text = thousands(r.score)
		end
		rightCaption.Visible = not tutorial
		rightValue.Visible = not tutorial
		skipButton.Visible = tutorial
		timerLabel.Text = string.format("%.1f", Config.ROUND_SECONDS)
		timerLabel.TextColor3 = c.bone
		fuseFill.Size = UDim2.fromScale(1, 1)
		fuseFill.BackgroundColor3 = c.ember
		setButton("PRESS", false)
	end

	local function showResult(r: { [string]: any })
		local round = current
		if not round or r.token ~= round.token then
			return -- a result for a round that is no longer on screen
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
				screens.gameOver(r, round, reducedFlashing)
			end, reducedFlashing)
			return
		end

		local tutorial = r.mode == "tutorial"
		if r.verdict == "correct" then
			verdict.TextColor3 = c.acid
			verdict.Text = if r.delta > 0 then ("Survived  +%d"):format(r.delta) else "Correct"
		elseif r.verdict == "paradox" then
			verdict.TextColor3 = c.mint
			verdict.Text = "No answer existed"
		else
			verdict.TextColor3 = c.molten
			verdict.Text = "Wrong"
		end
		if tutorial then
			local lines = table.clone(r.lines)
			if r.verdict == "wrong" then
				table.insert(lines, 1, "In a real run, that would have killed you.")
			end
			detail.Text = table.concat(lines, "\n")
			continueButton.Text = if r.last then "FINISH" else "CONTINUE"
		else
			detail.Text = if r.verdict == "paradox"
				then r.lines[#r.lines - 1] .. "\n" .. r.lines[#r.lines]
				else ""
			rightValue.Text = thousands(r.score)
		end
		setLower("result")
	end

	local function leaveRound()
		state = "menu"
		current = nil
		button.Visible = false
		block.Visible = false
	end

	local function showFinished(r: { [string]: any })
		leaveRound()
		if r.faulted then
			showMenu() -- the server could not evaluate a round; it logged why
		elseif r.mode == "tutorial" then
			screens.ready()
		else
			screens.survived(r)
		end
	end

	startMode = function(mode: string)
		state = "waiting"
		current = nil
		screens.hide()
		block.Visible = false
		button.Visible = false
		startEvent:FireServer(mode)
	end

	showMenu = function()
		startEvent:FireServer("menu")
		leaveRound()
		screens.menu(if profile then profile.status else nil, reducedFlashing)
	end

	-- A new player is only marked "returning" locally; the server decides what is stored.
	local function markReturning()
		if profile then
			profile.status = "returning"
		end
	end

	screens = Screens.new(gui, {
		play = function()
			-- Ask the server again at the moment of choosing; it is the only authority on onboarding.
			profile = getProfile:InvokeServer() or profile
			if profile and profile.status == "new" then
				screens.offer()
			else
				startMode("run")
			end
		end,
		tutorial = function()
			markReturning()
			startMode("tutorial")
		end,
		skipTutorial = function()
			markReturning()
			onboardEvent:FireServer("skip")
			startMode("run")
		end,
		run = function()
			startMode("run")
		end,
		menu = function()
			showMenu()
		end,
		toggleFlashing = function()
			reducedFlashing = not reducedFlashing
			Scene.setReduced(reducedFlashing)
			return reducedFlashing
		end,
	}, function()
		hud.Visible = false
	end)

	roundEvent.OnClientEvent:Connect(showRound)
	resultEvent.OnClientEvent:Connect(showResult)
	finishedEvent.OnClientEvent:Connect(showFinished)

	showMenu()
	task.spawn(function()
		profile = getProfile:InvokeServer()
		if state == "menu" and screens.isOpen() then
			showMenu()
		end
	end)
end

return GameUI
