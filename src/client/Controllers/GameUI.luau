--!strict
-- The whole game, as seen by the player: HUD, instruction card, the red button, feedback, tutorial and menus.
-- The server decides everything that matters; this module only renders and forwards presses.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Theme = require(script.Parent.Parent.Theme)

local c, font, new = Theme.color, Theme.font, Theme.new

local CAMERA_POS = Vector3.new(0, 9.5, 21)
local CAMERA_AIM = Vector3.new(0, 7.2, 0)
local BUTTON_FILL = 0.8 -- GUI cap diameter relative to the 3D cap, so the 3D rim stays visible and clickable

local GameUI = {}

local function tween(
	inst: Instance,
	seconds: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
)
	TweenService:Create(
		inst,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	):Play()
end

local function label(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or c.text
	props.FontFace = props.FontFace or font.label
	return new("TextLabel", props)
end

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
	local roundEvent = remotes:WaitForChild("Round") :: RemoteEvent
	local resultEvent = remotes:WaitForChild("Result") :: RemoteEvent
	local finishedEvent = remotes:WaitForChild("Finished") :: RemoteEvent

	for _ = 1, 10 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false) then
			break
		end
		task.wait(0.2)
	end

	-- Fixed camera on the stage; the UI is the game.
	local camera = workspace.CurrentCamera :: Camera
	local cap = workspace:WaitForChild("Stage"):WaitForChild("RedButton") :: Part
	local capHome = cap.Position
	local function pinCamera()
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 40
		camera.CFrame = CFrame.lookAt(CAMERA_POS, CAMERA_AIM)
	end
	pinCamera()
	camera:GetPropertyChangedSignal("CameraType"):Connect(function()
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			pinCamera()
		end
	end)

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

	local roundCaption = label({
		Size = UDim2.fromOffset(160, 16),
		Position = UDim2.fromOffset(20, 10),
		Text = "ROUND",
		TextSize = 13,
		TextColor3 = c.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = hud,
	})
	local roundValue = label({
		Size = UDim2.fromOffset(200, 32),
		Position = UDim2.fromOffset(20, 24),
		Text = "",
		TextSize = 28,
		FontFace = font.mono,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
		Parent = hud,
	})
	local scoreCaption = label({
		Size = UDim2.fromOffset(160, 16),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 10),
		Text = "SCORE",
		TextSize = 13,
		TextColor3 = c.dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = hud,
	})
	local scoreValue = label({
		Size = UDim2.fromOffset(200, 32),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 24),
		Text = "0",
		TextSize = 28,
		FontFace = font.mono,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = hud,
	})
	local timerValue = label({
		Size = UDim2.fromOffset(160, 44),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Text = "5.0",
		TextSize = 40,
		FontFace = font.mono,
		Parent = hud,
	})
	local timerTrack = new("Frame", {
		Size = UDim2.new(1, 0, 0, 4),
		Position = UDim2.fromOffset(0, 62),
		BackgroundColor3 = c.hairline,
		BorderSizePixel = 0,
		Parent = hud,
	})
	local timerFill = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = c.text,
		BorderSizePixel = 0,
		Parent = timerTrack,
	})

	------------------------------------------------------------------ Card
	local card = new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.new(0.92, 0, 0.36, 0),
		BackgroundColor3 = c.panel,
		BackgroundTransparency = 0.06,
		Visible = false,
		Parent = hud,
	}, {
		Theme.corner(UDim.new(0, 4)),
		Theme.stroke(c.hairline, 1),
		new("UISizeConstraint", { MaxSize = Vector2.new(780, 9999) }),
		new("UIPadding", {
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 22),
			PaddingRight = UDim.new(0, 22),
		}),
	})
	new("Frame", {
		Size = UDim2.new(0, 3, 1, 28),
		Position = UDim2.fromOffset(-22, -14),
		BackgroundColor3 = c.red,
		BorderSizePixel = 0,
		Parent = card,
	})

	local tagChip = label({
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "",
		TextSize = 13,
		TextColor3 = c.dim,
		Parent = card,
	})
	new(
		"UIPadding",
		{ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = tagChip }
	)
	Theme.stroke(c.hairline, 1).Parent = tagChip
	local skipButton = new("TextButton", {
		Size = UDim2.fromOffset(160, 22),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		Text = "SKIP TUTORIAL",
		TextSize = 13,
		FontFace = font.label,
		TextColor3 = c.dim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		Parent = card,
	})

	local body = new("Frame", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 1, -32),
		BackgroundTransparency = 1,
		Parent = card,
	})
	local instruction =
		new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = body })
	local directive = label({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextWrapped = true,
		TextScaled = true,
		FontFace = font.body,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = instruction,
	})
	new("UITextSizeConstraint", { MaxTextSize = 34, MinTextSize = 12, Parent = directive })
	local quote = new("Frame", {
		Position = UDim2.fromScale(0, 0.58),
		Size = UDim2.fromScale(1, 0.42),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = instruction,
	})
	new("Frame", {
		Size = UDim2.new(0, 2, 1, -6),
		Position = UDim2.fromOffset(0, 3),
		BackgroundColor3 = c.red,
		BorderSizePixel = 0,
		Parent = quote,
	})
	local quoteText = label({
		Size = UDim2.new(1, -18, 1, 0),
		Position = UDim2.fromOffset(18, 0),
		Text = "",
		TextWrapped = true,
		TextScaled = true,
		FontFace = font.bodyBold,
		TextColor3 = c.amber,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = quote,
	})
	new("UITextSizeConstraint", { MaxTextSize = 28, MinTextSize = 11, Parent = quoteText })

	local feedback = new("Frame", {
		Position = UDim2.fromScale(0, 0.38),
		Size = UDim2.fromScale(1, 0.62),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = body,
	})
	new("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = c.hairline,
		BorderSizePixel = 0,
		Parent = feedback,
	})
	local verdictLabel = label({
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, -150, 0.26, 0),
		Text = "",
		TextScaled = true,
		FontFace = font.display,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = feedback,
	})
	new("UITextSizeConstraint", { MaxTextSize = 28, MinTextSize = 14, Parent = verdictLabel })
	local detail = label({
		Position = UDim2.fromScale(0, 0.32),
		Size = UDim2.new(1, 0, 0.7, -36),
		Text = "",
		TextWrapped = true,
		TextScaled = true,
		RichText = true,
		FontFace = font.body,
		TextColor3 = c.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = feedback,
	})
	new("UITextSizeConstraint", { MaxTextSize = 17, MinTextSize = 11, Parent = detail })
	local continueButton = new("TextButton", {
		Size = UDim2.fromOffset(132, 28),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "CONTINUE",
		TextSize = 15,
		FontFace = font.label,
		TextColor3 = c.text,
		Parent = feedback,
	}, { Theme.stroke(c.hairline, 1), Theme.corner(UDim.new(0, 2)) })
	continueButton.MouseEnter:Connect(function()
		tween(continueButton, 0.12, { BackgroundTransparency = 0.85 })
	end)
	continueButton.MouseLeave:Connect(function()
		tween(continueButton, 0.12, { BackgroundTransparency = 1 })
	end)
	local autoTrack = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, -22, 1, 14),
		Size = UDim2.new(1, 44, 0, 2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = card,
	})
	local autoFill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = c.red,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Parent = autoTrack,
	})

	local coach = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.36, 90),
		Size = UDim2.new(0.8, 0, 0, 44),
		Text = "",
		TextWrapped = true,
		TextScaled = true,
		FontFace = font.bodyBold,
		TextColor3 = c.amber,
		Visible = false,
		Parent = hud,
	})
	new("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 11, Parent = coach })

	------------------------------------------------------------------ The red button
	local pressLabel = label({
		Size = UDim2.fromScale(1, 0.3),
		Position = UDim2.fromScale(0, 0.36),
		Text = "PRESS",
		TextScaled = true,
		FontFace = font.display,
		TextColor3 = Color3.fromRGB(255, 244, 240),
		Parent = nil,
	})
	new("UITextSizeConstraint", { MaxTextSize = 64, Parent = pressLabel })
	local flash = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		Parent = nil,
	}, { Theme.corner(UDim.new(1, 0)) })
	local capGradient = new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 92, 82), Color3.fromRGB(170, 14, 20)),
		Rotation = 90,
	})
	local capStroke = Theme.stroke(Color3.fromRGB(70, 6, 8), 4)
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
		Theme.corner(UDim.new(1, 0)),
		capGradient,
		capStroke,
		new("Frame", {
			Size = UDim2.fromScale(0.84, 0.84),
			Position = UDim2.fromScale(0.08, 0.08),
			BackgroundTransparency = 1,
			Active = false,
		}, { Theme.corner(UDim.new(1, 0)), Theme.stroke(Color3.new(1, 1, 1), 1.5, 0.82) }),
		new("Frame", {
			Size = UDim2.fromScale(0.56, 0.26),
			Position = UDim2.fromScale(0.22, 0.09),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.88,
			Active = false,
		}, { Theme.corner(UDim.new(1, 0)) }),
	})
	pressLabel.Parent = button
	flash.Parent = button
	local buttonSize = 200

	local function layoutButton()
		local r = cap.Size.Y / 2
		local top = cap.Position + Vector3.new(0, cap.Size.X / 2, 0)
		local centre = camera:WorldToViewportPoint(top)
		local edge = camera:WorldToViewportPoint(top + Vector3.new(r, 0, 0))
		buttonSize = math.floor(math.abs(edge.X - centre.X) * 2 * BUTTON_FILL)
		button.Size = UDim2.fromOffset(buttonSize, buttonSize)
		button.Position = UDim2.fromOffset(centre.X, centre.Y)
	end
	layoutButton()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutButton)

	------------------------------------------------------------------ Panels (menu / ready / results)
	local panel = new("Frame", {
		Name = "Panel",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = c.void,
		BackgroundTransparency = 0.12,
		Active = true,
		Visible = false,
		Parent = gui,
	})
	local panelColumn = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.9, 0),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		new("UISizeConstraint", { MaxSize = Vector2.new(520, 9999) }),
		new("UIListLayout", {
			Padding = UDim.new(0, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- forward declarations of flow helpers
	local startMode: (string) -> ()
	local showMenu: () -> ()

	local function showPanel(spec: {
		title: string,
		sub: string?,
		stats: { { string } }?,
		buttons: { { text: string, primary: boolean?, run: () -> () } },
	})
		for _, child in panelColumn:GetChildren() do
			if not child:IsA("UIListLayout") and not child:IsA("UISizeConstraint") then
				child:Destroy()
			end
		end
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		local title = label({
			Size = UDim2.new(1, 0, 0, 78),
			Text = spec.title,
			TextScaled = true,
			FontFace = font.display,
			LayoutOrder = nextOrder(),
			Parent = panelColumn,
		})
		new("UITextSizeConstraint", { MaxTextSize = 76, MinTextSize = 24, Parent = title })
		new("Frame", {
			Size = UDim2.fromOffset(56, 3),
			BackgroundColor3 = c.red,
			BorderSizePixel = 0,
			LayoutOrder = nextOrder(),
			Parent = panelColumn,
		})
		if spec.sub then
			local sub = label({
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = spec.sub,
				TextSize = 17,
				TextWrapped = true,
				FontFace = font.body,
				TextColor3 = c.dim,
				LayoutOrder = nextOrder(),
				Parent = panelColumn,
			})
			new(
				"UIPadding",
				{ PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12), Parent = sub }
			)
		end
		for _, row in spec.stats or {} do
			local line = new("Frame", {
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				LayoutOrder = nextOrder(),
				Parent = panelColumn,
			})
			label({
				Size = UDim2.fromScale(0.6, 1),
				Text = row[1],
				TextSize = 14,
				TextColor3 = c.dim,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = line,
			})
			label({
				Size = UDim2.fromScale(0.4, 1),
				Position = UDim2.fromScale(0.6, 0),
				Text = row[2],
				TextSize = 22,
				FontFace = font.mono,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = line,
			})
			new("Frame", {
				Size = UDim2.new(1, 0, 0, 1),
				Position = UDim2.fromScale(0, 1),
				BackgroundColor3 = c.hairline,
				BorderSizePixel = 0,
				Parent = line,
			})
		end
		new("Frame", {
			Size = UDim2.fromOffset(1, 10),
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
			Parent = panelColumn,
		})
		for _, b in spec.buttons do
			local btn = new("TextButton", {
				Size = UDim2.new(1, 0, 0, if b.primary then 58 else 46),
				BackgroundColor3 = if b.primary then c.red else c.panel,
				BackgroundTransparency = if b.primary then 0 else 0.2,
				AutoButtonColor = false,
				Text = b.text,
				TextSize = if b.primary then 24 else 18,
				FontFace = font.display,
				TextColor3 = c.text,
				LayoutOrder = nextOrder(),
				Parent = panelColumn,
			}, {
				Theme.corner(UDim.new(0, 3)),
				Theme.stroke(if b.primary then c.redDeep else c.hairline, 1),
			})
			btn.MouseEnter:Connect(function()
				tween(btn, 0.12, {
					BackgroundColor3 = if b.primary
						then Color3.fromRGB(255, 62, 60)
						else c.hairline,
				})
			end)
			btn.MouseLeave:Connect(function()
				tween(btn, 0.12, { BackgroundColor3 = if b.primary then c.red else c.panel })
			end)
			btn.Activated:Connect(b.run)
		end
		hud.Visible = false
		panel.Visible = true
	end

	------------------------------------------------------------------ Round state
	local current: { [string]: any }? = nil
	local state = "menu" -- menu | active | review | waiting
	local locked = false
	local tutorialSeen = false

	local function pulse()
		tween(button, 0.05, { Size = UDim2.fromOffset(buttonSize * 0.9, buttonSize * 0.9) })
		flash.BackgroundTransparency = 0.55
		tween(flash, 0.35, { BackgroundTransparency = 1 })
		tween(cap, 0.05, { Position = capHome - Vector3.new(0, 0.6, 0) })
		task.delay(0.07, function()
			tween(
				button,
				0.28,
				{ Size = UDim2.fromOffset(buttonSize, buttonSize) },
				Enum.EasingStyle.Back
			)
			tween(cap, 0.28, { Position = capHome }, Enum.EasingStyle.Back)
		end)
	end

	local function setButtonLook(mode: string)
		if mode == "ready" then
			pressLabel.Text = "PRESS"
			tween(button, 0.15, { BackgroundTransparency = 0 })
			capStroke.Color = Color3.fromRGB(70, 6, 8)
		elseif mode == "locked" then
			tween(button, 0.15, { BackgroundTransparency = 0.5 })
		end
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
		setButtonLook("locked")
		decideEvent:FireServer(round.token)
	end

	button.Activated:Connect(decide)
	button.MouseEnter:Connect(function()
		if state == "active" and not locked then
			tween(capStroke, 0.12, { Thickness = 7 })
			capStroke.Color = c.amber
		end
	end)
	button.MouseLeave:Connect(function()
		tween(capStroke, 0.12, { Thickness = 4 })
		capStroke.Color = Color3.fromRGB(70, 6, 8)
	end)

	local function advance()
		local round = current
		if state == "review" and round then
			nextEvent:FireServer(round.token)
		end
	end
	continueButton.Activated:Connect(advance)
	skipButton.Activated:Connect(function()
		tutorialSeen = true
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

	RunService.RenderStepped:Connect(function()
		local round = current
		if state ~= "active" or not round then
			return
		end
		local left = round.endsAt - workspace:GetServerTimeNow()
		timerValue.Text = string.format("%.1f", math.max(left, 0))
		timerFill.Size = UDim2.fromScale(math.clamp(left / Config.ROUND_SECONDS, 0, 1), 1)
		local color = if left > 3 then c.text elseif left > 1.5 then c.amber else c.red
		timerValue.TextColor3 = color
		timerFill.BackgroundColor3 = color
		if left <= 0 and not locked then
			locked = true
			setButtonLook("locked")
		end
	end)

	local function showRound(r: { [string]: any })
		current = r
		state = "active"
		locked = false
		panel.Visible = false
		hud.Visible = true
		card.Visible = true
		button.Visible = true
		feedback.Visible = false
		autoTrack.Visible = false
		instruction.Size = UDim2.fromScale(1, 1)
		directive.Size = UDim2.fromScale(1, if r.statement then 0.55 else 1)
		directive.Text = r.directive
		quote.Visible = r.statement ~= nil
		quoteText.Text = if r.statement then "“" .. r.statement .. "”" else ""
		local tutorial = r.mode == "tutorial"
		tagChip.Text = if tutorial
			then ("PRACTICE  %d / %d"):format(r.index, r.total)
			else (r.tag or "INSTRUCTION")
		tagChip.TextColor3 = if tutorial then c.amber else c.dim
		skipButton.Visible = tutorial
		coach.Visible = tutorial
		coach.Text = r.coach or ""
		roundCaption.Text = if tutorial then "TUTORIAL" else "ROUND"
		roundValue.Text = if tutorial
			then string.format("%d / %d", r.index, r.total)
			else string.format(
				"%02d <font size='16' color='#8A8680'>/ %d</font>",
				r.index,
				r.total
			)
		scoreCaption.Text = if tutorial
			then "NOT SCORED"
			else (r.streak > 1 and ("SCORE   ×%d STREAK"):format(r.streak) or "SCORE")
		scoreValue.Text = if tutorial then "—" else thousands(r.score)
		timerValue.Text = string.format("%.1f", Config.ROUND_SECONDS)
		timerFill.Size = UDim2.fromScale(1, 1)
		setButtonLook("ready")
		pressLabel.Text = "PRESS"
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
		setButtonLook("locked")
		pressLabel.Text = if r.pressed then "PRESSED" else "HELD"
		coach.Visible = false
		timerFill.Size = UDim2.fromScale(0, 1)
		timerValue.TextColor3 = c.dim

		local verdictColor, verdict
		if r.verdict == "correct" then
			verdictColor = c.green
			verdict = if r.delta > 0 then ("CORRECT  +%d"):format(r.delta) else "CORRECT"
		elseif r.verdict == "paradox" then
			verdictColor = c.amber
			verdict = "PARADOX  ·  NO CORRECT ANSWER"
		else
			verdictColor = c.red
			verdict = if r.timedOut then "TIME'S UP  ·  INCORRECT" else "INCORRECT"
		end
		verdictLabel.Text = verdict
		verdictLabel.TextColor3 = verdictColor
		local decision = if r.pressed
			then "You pressed the button."
			elseif r.timedOut then "You did nothing."
			else "You held."
		detail.Text = "<b>" .. decision .. "</b>\n" .. table.concat(r.lines, "\n")
		scoreValue.Text = if r.mode == "tutorial" then "—" else thousands(r.score)

		feedback.Visible = true
		instruction.Size = UDim2.fromScale(1, 0.34)
		continueButton.Text = if r.last then "FINISH" else "CONTINUE"
		if r.reviewSeconds then
			autoTrack.Visible = true
			autoFill.Size = UDim2.fromScale(0, 1)
			tween(
				autoFill,
				r.reviewSeconds,
				{ Size = UDim2.fromScale(1, 1) },
				Enum.EasingStyle.Linear
			)
		end
	end

	local function showFinished(r: { [string]: any })
		state = "menu"
		current = nil
		button.Visible = false
		card.Visible = false
		if r.mode == "tutorial" then
			tutorialSeen = true
			showPanel({
				title = "YOU'RE READY",
				sub = "From here the instructions get harder. Some refer to themselves. Some have two right answers. A few have none.",
				buttons = {
					{
						text = "START",
						primary = true,
						run = function()
							startMode("run")
						end,
					},
					{
						text = "PRACTICE AGAIN",
						run = function()
							startMode("tutorial")
						end,
					},
				},
			})
		else
			showPanel({
				title = "RUN COMPLETE",
				sub = "Decisions made. Some of them could not be wrong.",
				stats = {
					{ "SCORE", thousands(r.score) },
					{ "BEST", thousands(r.best) },
					{ "CORRECT", ("%d / %d"):format(r.correct, r.scored) },
					{ "PARADOXES MET", tostring(r.paradoxes) },
				},
				buttons = {
					{
						text = "PLAY AGAIN",
						primary = true,
						run = function()
							startMode("run")
						end,
					},
					{
						text = "HOW TO PLAY",
						run = function()
							startMode("tutorial")
						end,
					},
					{
						text = "MAIN MENU",
						run = function()
							showMenu()
						end,
					},
				},
			})
		end
	end

	startMode = function(mode: string)
		state = "waiting"
		panel.Visible = false
		startEvent:FireServer(mode)
	end

	showMenu = function()
		startEvent:FireServer("menu")
		state = "menu"
		current = nil
		button.Visible = false
		card.Visible = false
		showPanel({
			title = "CONTRADICTIONS",
			sub = "Read the instruction. Press the button, or don't. You have five seconds.",
			buttons = {
				{
					text = "PLAY",
					primary = true,
					run = function()
						startMode(if tutorialSeen then "run" else "tutorial")
					end,
				},
				{
					text = "HOW TO PLAY",
					run = function()
						startMode("tutorial")
					end,
				},
			},
		})
	end

	roundEvent.OnClientEvent:Connect(showRound)
	resultEvent.OnClientEvent:Connect(showResult)
	finishedEvent.OnClientEvent:Connect(showFinished)
	showMenu()
end

return GameUI
