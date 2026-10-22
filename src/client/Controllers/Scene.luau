--!strict
-- The fixed camera and the stage behind the UI. Everything here is purely visual and local: the water
-- climbs as the timer drains, the button's light flickers harder as it runs out, and the cap dips on a press.

local RunService = game:GetService("RunService")

local Scene = {}

local CAMERA_POS = Vector3.new(0, 9.5, 21)
local CAMERA_AIM = Vector3.new(0, 7.2, 0)
local WATER_LOW, WATER_HIGH = 0.4, 1.35

local camera: Camera
local cap: Part
local water: Part
local light: PointLight
local capHome: Vector3
local heat = 0 -- 0 calm .. 1 out of time
local active = false
local reduced = false -- photosensitivity: no light flicker
local shown = 0 -- heat eased toward its target so the water never snaps

function Scene.attach()
	camera = workspace.CurrentCamera :: Camera
	local stage = workspace:WaitForChild("Stage")
	cap = stage:WaitForChild("RedButton") :: Part
	water = stage:WaitForChild("Water") :: Part
	light = cap:WaitForChild("PointLight") :: PointLight
	capHome = cap.Position

	local function pin()
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 40
		camera.CFrame = CFrame.lookAt(CAMERA_POS, CAMERA_AIM)
	end
	pin()
	camera:GetPropertyChangedSignal("CameraType"):Connect(function()
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			pin()
		end
	end)

	local rng = Random.new()
	RunService.RenderStepped:Connect(function(dt)
		local target = if active then heat else 0
		shown += (target - shown) * math.min(1, dt * (if target > shown then 12 else 3))
		local y = WATER_LOW + (WATER_HIGH - WATER_LOW) * shown
		water.Position = Vector3.new(0, y + math.sin(os.clock() * 1.3) * 0.03, 0)
		-- Steady glow when calm; a ragged flicker only in the last second and a half.
		local base = 0.8
		light.Brightness = if active
				and heat > 0.7
				and not reduced
			then base + rng:NextNumber(-0.35, 0.5)
			else base
	end)
end

-- Centre and diameter (pixels) of the 3D cap's top face, so the GUI button can sit exactly on it.
function Scene.buttonRect(): (Vector2, number)
	local top = cap.Position + Vector3.new(0, cap.Size.X / 2, 0)
	local centre = camera:WorldToViewportPoint(top)
	local edge = camera:WorldToViewportPoint(top + Vector3.new(cap.Size.Y / 2, 0, 0))
	return Vector2.new(centre.X, centre.Y), math.abs(edge.X - centre.X) * 2
end

function Scene.onViewportChanged(fn: () -> ())
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(fn)
end

function Scene.setReduced(value: boolean)
	reduced = value
end

function Scene.viewport(): Vector2
	return camera.ViewportSize
end

function Scene.setHeat(value: number, isActive: boolean)
	heat = math.clamp(value, 0, 1)
	active = isActive
end

local function setCap(y: number, seconds: number, style: Enum.EasingStyle)
	game:GetService("TweenService")
		:Create(
			cap,
			TweenInfo.new(seconds, style),
			{ Position = Vector3.new(capHome.X, y, capHome.Z) }
		)
		:Play()
end

function Scene.pressCap()
	setCap(capHome.Y - 0.6, 0.05, Enum.EasingStyle.Quad)
	task.delay(0.07, function()
		setCap(capHome.Y, 0.28, Enum.EasingStyle.Back)
	end)
end

return Scene
