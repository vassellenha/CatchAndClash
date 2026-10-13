--[[
	PondAmbience

	Purely cosmetic eye-candy for the fishing spot: decorative fish that swim
	around inside the pond, and rising bubble particles. None of this is
	tied to the actual catch system (FishingService/FishingClient) - it's
	just there to make the water look alive and draw players in.

	Runs client-side only: each player simulates their own ambient fish
	locally, so there is no server replication cost. Minor desync between
	players is irrelevant since it's cosmetic.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Matches the pond built by scripts/BuildPondTerrain.lua. Tweak these if you
-- rebuild the pond somewhere else or at a different size.
local PondConfig = {
	Center = Vector3.new(0, 0, 0),
	SwimRadius = 36, -- keep a margin inside the ~42-stud water radius
	MinY = -7,
	MaxY = -1.5,
	FloorY = -8, -- where bubble spots sit, just above the sandy bottom
}

local FISH_COUNT = 10
local BUBBLE_SPOT_COUNT = 6

local FISH_COLORS = {
	Color3.fromRGB(255, 140, 60),
	Color3.fromRGB(225, 225, 230),
	Color3.fromRGB(255, 215, 90),
	Color3.fromRGB(90, 160, 255),
	Color3.fromRGB(235, 90, 90),
}

-- ===== Helpers =====

local function randomPondPoint()
	local angle = math.random() * math.pi * 2
	local radius = math.sqrt(math.random()) * PondConfig.SwimRadius
	local x = PondConfig.Center.X + math.cos(angle) * radius
	local z = PondConfig.Center.Z + math.sin(angle) * radius
	local y = PondConfig.MinY + math.random() * (PondConfig.MaxY - PondConfig.MinY)
	return Vector3.new(x, y, z)
end

local function randomFloorPoint()
	local angle = math.random() * math.pi * 2
	local radius = math.random() * (PondConfig.SwimRadius - 4)
	local x = PondConfig.Center.X + math.cos(angle) * radius
	local z = PondConfig.Center.Z + math.sin(angle) * radius
	return Vector3.new(x, PondConfig.FloorY, z)
end

-- ===== Ambient fish =====

local pondFolder = Instance.new("Folder")
pondFolder.Name = "PondAmbience"
pondFolder.Parent = Workspace

local function createFishParts(color)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(0.8, 0.7, 1.6) -- X=width, Y=height, Z=length (front is -Z)
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CastShadow = false
	body.Parent = pondFolder

	local tail = Instance.new("Part")
	tail.Name = "Tail"
	tail.Size = Vector3.new(0.6, 0.5, 0.06)
	tail.Color = color
	tail.Material = Enum.Material.SmoothPlastic
	tail.Anchored = true
	tail.CanCollide = false
	tail.CanQuery = false
	tail.CastShadow = false
	tail.Parent = pondFolder

	return body, tail
end

local fishList = {}

for _ = 1, FISH_COUNT do
	local color = FISH_COLORS[math.random(1, #FISH_COLORS)]
	local body, tail = createFishParts(color)
	local startPos = randomPondPoint()

	table.insert(fishList, {
		body = body,
		tail = tail,
		pos = startPos,
		target = randomPondPoint(),
		rot = CFrame.new(),
		speed = 3 + math.random() * 2.5,
	})
end

RunService.Heartbeat:Connect(function(dt)
	for _, fish in ipairs(fishList) do
		local toTarget = fish.target - fish.pos
		local distance = toTarget.Magnitude

		if distance < 1.5 then
			fish.target = randomPondPoint()
			toTarget = fish.target - fish.pos
			distance = toTarget.Magnitude
		end

		local direction = toTarget.Unit
		fish.pos = fish.pos + direction * fish.speed * dt

		local desiredRotation = CFrame.lookAt(Vector3.new(), direction).Rotation
		fish.rot = fish.rot:Lerp(desiredRotation, math.clamp(dt * 3, 0, 1))

		local finalCFrame = CFrame.new(fish.pos) * fish.rot
		fish.body.CFrame = finalCFrame
		fish.tail.CFrame = finalCFrame * CFrame.new(0, 0, 0.85)
	end
end)

-- ===== Bubbles =====

local function createBubbleSpot(position)
	local spot = Instance.new("Part")
	spot.Name = "BubbleSpot"
	spot.Size = Vector3.new(0.2, 0.2, 0.2)
	spot.Transparency = 1
	spot.Anchored = true
	spot.CanCollide = false
	spot.CanQuery = false
	spot.CastShadow = false
	spot.Position = position
	spot.Parent = pondFolder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Bubbles"
	emitter.Rate = 6 + math.random() * 4
	emitter.Lifetime = NumberRange.new(1.5, 3)
	emitter.Speed = NumberRange.new(2, 3.5)
	emitter.SpreadAngle = Vector2.new(8, 8)
	emitter.Acceleration = Vector3.new(0, 3, 0)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(1, 0.04),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.85, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	emitter.LightEmission = 0.2
	emitter.Parent = spot

	return spot
end

for _ = 1, BUBBLE_SPOT_COUNT do
	createBubbleSpot(randomFloorPoint())
end
