-- One-off editor script: paste this whole block into Studio's Command Bar
-- (the input strip at the very bottom of the Studio window) and press Enter.
-- It builds a flat grass terrain with a circular pond + sandy beach in the
-- middle, and a SpawnLocation on dry land so players don't spawn in water.

local Terrain = workspace.Terrain

local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end

Terrain:Clear()

-- Flat ground slab (top surface sits at y = 0).
Terrain:FillBlock(CFrame.new(0, -10, 0), Vector3.new(500, 20, 500), Enum.Material.Grass)

-- Carve the pond basin out of the ground.
Terrain:FillCylinder(CFrame.new(0, -4, 0), 10, 45, Enum.Material.Air)

-- Sandy basin floor.
Terrain:FillCylinder(CFrame.new(0, -8.5, 0), 1.5, 44, Enum.Material.Sand)

-- Fill the basin with water (surface sits slightly below ground level).
Terrain:FillCylinder(CFrame.new(0, -4.5, 0), 8, 42, Enum.Material.Water)

-- Sandy beach ring around the water's edge.
Terrain:FillCylinder(CFrame.new(0, -0.5, 0), 3, 50, Enum.Material.Sand)

-- A little nicer water look.
Terrain.WaterColor = Color3.fromRGB(35, 106, 140)
Terrain.WaterTransparency = 0.3
Terrain.WaterReflectance = 0.3
Terrain.WaterWaveSize = 0.15
Terrain.WaterWaveSpeed = 10

-- Spawn point on dry land, just outside the pond.
local spawn = Instance.new("SpawnLocation")
spawn.Name = "Spawn"
spawn.Size = Vector3.new(6, 1, 6)
spawn.Position = Vector3.new(0, 1, 60)
spawn.Anchored = true
spawn.CanCollide = true
spawn.BrickColor = BrickColor.new("Bright green")
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.Parent = workspace

print("Kolam & terrain selesai dibuat!")
