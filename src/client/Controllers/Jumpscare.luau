--!strict
-- The death sting. One face, split down the middle: a burning half and a drowned half with mismatched eyes
-- (one slit upright, one lying flat). The contradiction is the monster. ~0.9 s, then it hands off.
-- Sound is the two engine sounds that ship with the client, layered: an explosion hitting water.

local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Parent.Theme)
local c, new = Theme.color, Theme.new

local Jumpscare = {}

local playing = false
local runId = 0

local function circle(props: { [string]: any }, children: { Instance }?): Frame
	props.BorderSizePixel = 0
	local f = new("Frame", props, children)
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = f })
	return f
end

local function eye(parent: Instance, x: number, glow: Color3, deep: Color3, slitVertical: boolean)
	local socket = circle({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, 0.36),
		Size = UDim2.fromScale(0.3, 0),
		BackgroundColor3 = Color3.fromRGB(5, 5, 6),
		Parent = parent,
	}, { new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width }) })
	new("UIStroke", { Color = deep, Thickness = 6, Parent = socket })
	local iris = circle({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		BackgroundColor3 = glow,
		Parent = socket,
	})
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = if slitVertical then UDim2.fromScale(0.12, 0.92) else UDim2.fromScale(0.92, 0.12),
		BackgroundColor3 = Color3.fromRGB(3, 3, 3),
		BorderSizePixel = 0,
		Parent = iris,
	})
end

local function buildFace(parent: Instance): Frame
	local face = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0, 0.7),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = parent,
	}, { new("UIAspectRatioConstraint", { AspectRatio = 0.86, DominantAxis = Enum.DominantAxis.Height }) })

	new("Frame", {
		Size = UDim2.fromScale(0.5, 1),
		BackgroundColor3 = c.molten,
		BorderSizePixel = 0,
		Parent = face,
	}, { new("UIGradient", { Color = ColorSequence.new(c.ember, c.crimson), Rotation = 90 }) })
	new("Frame", {
		Size = UDim2.fromScale(0.5, 1),
		Position = UDim2.fromScale(0.5, 0),
		BackgroundColor3 = c.acid,
		BorderSizePixel = 0,
		Parent = face,
	}, { new("UIGradient", { Color = ColorSequence.new(c.acid, c.teal), Rotation = 90 }) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = Color3.fromRGB(2, 2, 2), BorderSizePixel = 0, Parent = face })

	eye(face, 0.27, c.ember, c.crimson, true)
	eye(face, 0.73, c.acid, c.forest, false)

	local mouth = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromScale(0.86, 0.34),
		BackgroundColor3 = Color3.fromRGB(3, 2, 2),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = face,
	})
	local teeth = 9
	for i = 1, teeth do
		local x = (i - 0.5) / teeth
		local size = if i % 2 == 0 then 0.17 else 0.22
		for _, top in { true, false } do
			new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(x, if top then 0 else 1),
				Size = UDim2.fromScale(size, 0),
				Rotation = 45,
				BackgroundColor3 = c.bone,
				BorderSizePixel = 0,
				Parent = mouth,
			}, { new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width }) })
		end
	end
	return face
end

local function sound(parent: Instance, id: string, volume: number, speed: number)
	local s = new("Sound", { SoundId = id, Volume = volume, PlaybackSpeed = speed, Parent = parent })
	s:Play()
	return s
end

-- onDone runs once, after the face has cut to black. Calling play() while one is running does nothing.
function Jumpscare.play(gui: ScreenGui, onDone: () -> ())
	if playing then
		return
	end
	playing = true
	runId += 1
	local myRun = runId

	local overlay = new("Frame", {
		Name = "Jumpscare",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(2, 0, 0),
		BorderSizePixel = 0,
		Active = true, -- swallow every click while it plays
		ZIndex = 100,
		Parent = gui,
	})
	local face = buildFace(overlay)
	local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = c.ember, BorderSizePixel = 0, ZIndex = 101, Parent = overlay })

	sound(overlay, "rbxasset://sounds/impact_explosion_03.mp3", 1, 0.7)
	task.delay(0.04, function()
		if runId == myRun then
			sound(overlay, "rbxasset://sounds/impact_water.mp3", 1, 0.6)
		end
	end)

	Theme.tween(flash, 0.14, { BackgroundTransparency = 1 })
	Theme.tween(face, 0.1, { Size = UDim2.fromScale(0, 1.1) }, Enum.EasingStyle.Quad)
	task.delay(0.1, function()
		if runId == myRun then
			Theme.tween(face, 0.7, { Size = UDim2.fromScale(0, 1.24) }, Enum.EasingStyle.Linear) -- slow creep
		end
	end)

	local start = os.clock()
	local rng = Random.new()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local amp = math.max(3, 20 * (1 - t / 0.8))
		face.Position = UDim2.new(0.5, rng:NextInteger(-amp, amp), 0.5, rng:NextInteger(-amp, amp))
		-- two hard flashes in the first third of a second, then dark
		flash.BackgroundTransparency = if t > 0.2 and t < 0.27 then 0.55 else flash.BackgroundTransparency
	end)

	task.delay(0.8, function()
		if runId ~= myRun then
			return
		end
		conn:Disconnect()
		face.Visible = false
		overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		task.delay(0.18, function()
			if runId ~= myRun then
				return
			end
			overlay:Destroy()
			playing = false
			onDone()
		end)
	end)
end

return Jumpscare
