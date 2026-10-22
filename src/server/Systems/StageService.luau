--!strict
-- The physical stage the UI sits on: a dark void, a lit plinth and the red button with its ClickDetector.
-- It is a representation of the UI button, not a place to walk. No characters are spawned.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

-- selene: allow(incorrect_standard_library_use)
local Session = require(script.Parent.SessionService)

local StageService = {}

local function cylinder(
	name: string,
	diameter: number,
	height: number,
	y: number,
	color: Color3,
	parent: Instance
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90))
	p.Color = color
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function slab(name: string, size: Vector3, pos: Vector3, color: Color3, parent: Instance)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Anchored = true
	p.CanQuery = false
	p.Parent = parent
end

function StageService.init()
	Players.CharacterAutoLoads = false

	-- Edit-mode leftovers from the Baseplate template.
	for _, name in { "Baseplate", "SpawnLocation" } do
		local leftover = workspace:FindFirstChild(name)
		if leftover then
			leftover:Destroy()
		end
	end

	Lighting.ClockTime = 0
	Lighting.Brightness = 0
	Lighting.Ambient = Color3.fromRGB(10, 10, 12)
	Lighting.OutdoorAmbient = Color3.fromRGB(10, 10, 12)
	Lighting.FogColor = Color3.new(0, 0, 0)
	Lighting.FogStart = 40
	Lighting.FogEnd = 110
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.2
	bloom.Size = 20
	bloom.Threshold = 1.1
	bloom.Parent = Lighting
end

function StageService.start()
	local stage = Instance.new("Folder")
	stage.Name = "Stage"

	slab(
		"Floor",
		Vector3.new(160, 1, 160),
		Vector3.new(0, -0.5, 0),
		Color3.fromRGB(12, 12, 14),
		stage
	)
	slab(
		"Backdrop",
		Vector3.new(160, 80, 1),
		Vector3.new(0, 40, -30),
		Color3.fromRGB(7, 7, 9),
		stage
	)

	local housing = cylinder("Housing", 9.6, 1.6, 0.8, Color3.fromRGB(22, 22, 26), stage)
	housing.Material = Enum.Material.Metal
	local amber = cylinder("WarningRing", 8.6, 0.06, 1.63, Color3.fromRGB(196, 104, 0), stage)
	amber.Material = Enum.Material.Neon
	cylinder("WellInset", 8.0, 0.08, 1.66, Color3.fromRGB(10, 10, 12), stage)

	-- Toxic water pooled around the plinth. The client raises it as the timer runs down.
	local water = cylinder("Water", 60, 0.3, 0.4, Color3.fromRGB(8, 64, 46), stage)
	water.Material = Enum.Material.Glass
	water.Transparency = 0.2
	water.Reflectance = 0.3
	water.CanQuery = false

	local cap = cylinder("RedButton", 6.4, 1.5, 2.45, Color3.fromRGB(200, 24, 30), stage)
	cap.Material = Enum.Material.SmoothPlastic
	cap.Reflectance = 0.08

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 40, 40)
	glow.Brightness = 0.8
	glow.Range = 12
	glow.Parent = cap

	-- Sparse embers lifting off the housing; the only particles in the scene.
	local source = Instance.new("Part")
	source.Name = "EmberSource"
	source.Anchored, source.CanCollide, source.CanQuery, source.Transparency = true, false, false, 1
	source.Size = Vector3.new(8.4, 0.2, 8.4)
	source.Position = Vector3.new(0, 1.8, 0)
	source.Parent = stage
	local embers = Instance.new("ParticleEmitter")
	embers.Rate = 6
	embers.Lifetime = NumberRange.new(2, 4)
	embers.Speed = NumberRange.new(1.5, 3)
	embers.Acceleration = Vector3.new(0, 1.5, 0)
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.LightEmission = 1
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 120, 30), Color3.fromRGB(200, 30, 10))
	embers.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 0),
	})
	embers.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	embers.Shape = Enum.ParticleEmitterShape.Box
	embers.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Parent = source

	local key = Instance.new("Part")
	key.Name = "KeyLight"
	key.Anchored, key.CanCollide, key.CanQuery, key.Transparency = true, false, false, 1
	key.Position = Vector3.new(0, 20, 6)
	key.Parent = stage
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 55
	spot.Range = 40
	spot.Brightness = 3
	spot.Color = Color3.fromRGB(255, 232, 214)
	spot.Parent = key

	-- World path to the same decision handler the GUI uses. Range is generous: nobody walks here.
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 1000
	click.Parent = cap
	click.MouseClick:Connect(function(player)
		Session.decide(player, nil)
	end)

	stage.Parent = workspace
end

return StageService
