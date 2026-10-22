--!strict
-- Art direction: FIRE against WATER on near-black.
--   Fire  = action. The command to press, the heat of the timer, danger, death.
--   Water = restraint and truth. Holding, quoted statements, survival.
-- Two typefaces: a blackletter display face for names and verdicts, a typewriter face for everything read
-- or counted. No rounded corners except the button itself; edges are hard and lines are hairlines.
-- Spacing is multiples of 8.

local Theme = {}

Theme.color = {
	ink = Color3.fromRGB(7, 8, 10),
	bone = Color3.fromRGB(232, 226, 214),
	ash = Color3.fromRGB(128, 122, 112),
	-- fire
	ember = Color3.fromRGB(255, 106, 26),
	molten = Color3.fromRGB(224, 42, 20),
	crimson = Color3.fromRGB(122, 15, 15),
	-- water
	acid = Color3.fromRGB(112, 255, 96),
	mint = Color3.fromRGB(188, 255, 226),
	forest = Color3.fromRGB(14, 52, 36),
	teal = Color3.fromRGB(10, 44, 48),
}

Theme.font = {
	displayBold = Font.new(Font.fromEnum(Enum.Font.GrenzeGotisch).Family, Enum.FontWeight.Bold),
	type = Font.fromEnum(Enum.Font.SpecialElite),
}

-- new("Frame", { Size = ... }, { child, child }) -> Instance
function Theme.new(class: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		(inst :: any)[k] = v
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

function Theme.hex(c: Color3): string
	return ("#%02X%02X%02X"):format(
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5)
	)
end

function Theme.tween(
	inst: Instance,
	seconds: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
)
	game:GetService("TweenService")
		:Create(
			inst,
			TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
			props
		)
		:Play()
end

-- Transparent TextLabel with the house defaults.
function Theme.text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or Theme.color.bone
	props.FontFace = props.FontFace or Theme.font.type
	props.BorderSizePixel = 0
	return Theme.new("TextLabel", props)
end

-- Divider under titles: ember on the left half, acid on the right.
function Theme.rule(parent: Instance, width: UDim, order: number?): Frame
	local f = Theme.new("Frame", {
		Size = UDim2.new(width.Scale, width.Offset, 0, 2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = order or 0,
		Parent = parent,
	})
	Theme.new("Frame", {
		Size = UDim2.fromScale(0.5, 1),
		BackgroundColor3 = Theme.color.ember,
		BorderSizePixel = 0,
		Parent = f,
	})
	Theme.new("Frame", {
		Size = UDim2.fromScale(0.5, 1),
		Position = UDim2.fromScale(0.5, 0),
		BackgroundColor3 = Theme.color.acid,
		BorderSizePixel = 0,
		Parent = f,
	})
	return f
end

return Theme
