--[[
	FishingService

	Owns the entire fishing loop server-side:
		1. Player casts (CastRod) -> wait a random bite time.
		2. A fish "bites" (FishBite) -> start an authoritative reel minigame.
		3. Every tick, the server advances the minigame (zone drift, indicator,
		   progress) and replicates the state to the client for rendering
		   (ReelUpdate). The client only ever tells the server whether the
		   reel button is currently held (ReelInput) - it cannot report its
		   own progress, so there is nothing for an exploiter to fake their
		   way past.
		4. On success/failure, reward (if any) is applied via DataManager and
		   CatchResult is sent to the client.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Fishing.Config)
local FishData = require(ReplicatedStorage.Fishing.FishData)
local RarityData = require(ReplicatedStorage.Fishing.RarityData)
local Remotes = require(ReplicatedStorage.Fishing.Remotes).init()

local DataManager = require(script.Parent.DataManager)
local RodTool = require(script.Parent.RodTool)

local CastRod = Remotes.get("CastRod")
local FishBite = Remotes.get("FishBite")
local ReelInput = Remotes.get("ReelInput")
local ReelUpdate = Remotes.get("ReelUpdate")
local CatchResult = Remotes.get("CatchResult")

-- Per-player session state. "state" is one of: "idle" | "waiting" | "reeling".
local sessions = {}

local function getSession(player)
	local session = sessions[player]
	if not session then
		session = { state = "idle", holding = false }
		sessions[player] = session
	end
	return session
end

local function pickFish()
	local totalWeight = 0
	for _, fish in ipairs(FishData) do
		totalWeight += fish.weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, fish in ipairs(FishData) do
		cumulative += fish.weight
		if roll <= cumulative then
			return fish
		end
	end

	return FishData[1]
end

local function clamp(value, min, max)
	return math.clamp(value, min, max)
end

local function runReelMinigame(player, fish)
	local session = getSession(player)
	session.state = "reeling"
	session.holding = false

	local difficulty = fish.difficulty or 0.3
	local zoneSize = Config.ZoneMaxSize - (Config.ZoneMaxSize - Config.ZoneMinSize) * difficulty
	local zoneSpeed = Config.ZoneSpeed * (1 + difficulty)

	local progress = Config.BarStart
	local indicator = Config.BarStart
	local zoneCenter = Config.BarStart
	local zoneVelocity = 0
	local elapsed = 0

	local success = false

	while true do
		local dt = Config.TickRate
		task.wait(dt)
		elapsed += dt

		-- Bail out cleanly if the player left or got disconnected mid-reel.
		if not player or not player.Parent then
			return false
		end

		-- Random-walk the zone center so it drifts unpredictably.
		zoneVelocity += (math.random() * 2 - 1) * zoneSpeed * dt
		zoneVelocity = clamp(zoneVelocity, -zoneSpeed, zoneSpeed)
		zoneCenter = clamp(zoneCenter + zoneVelocity * dt, zoneSize / 2, Config.BarMax - zoneSize / 2)

		if session.holding then
			indicator += Config.IndicatorRise * dt
		else
			indicator -= Config.IndicatorFall * dt
		end
		indicator = clamp(indicator, 0, Config.BarMax)

		local inside = indicator >= (zoneCenter - zoneSize / 2) and indicator <= (zoneCenter + zoneSize / 2)
		if inside then
			progress += Config.FillRate * dt
		else
			progress -= Config.DrainRate * dt
		end
		progress = clamp(progress, 0, Config.BarMax)

		ReelUpdate:FireClient(player, {
			progress = progress,
			zoneCenter = zoneCenter,
			zoneSize = zoneSize,
			indicator = indicator,
		})

		if progress >= Config.BarMax then
			success = true
			break
		elseif progress <= 0 then
			success = false
			break
		elseif elapsed >= Config.ReelTimeLimit then
			success = false
			break
		end
	end

	return success
end

local function beginFishing(player)
	local session = getSession(player)
	if session.state ~= "idle" then
		return
	end

	session.state = "casting"

	RodTool.equip(player)
	RodTool.playCastSwing(player)

	if not player.Parent or session.state ~= "casting" then
		return
	end
	session.state = "waiting"

	local biteTime = Config.MinBiteTime + math.random() * (Config.MaxBiteTime - Config.MinBiteTime)
	task.wait(biteTime)

	if not player.Parent or session.state ~= "waiting" then
		return
	end

	local fish = pickFish()
	FishBite:FireClient(player)

	local success = runReelMinigame(player, fish)

	if not player.Parent then
		return
	end

	if success then
		DataManager.addCash(player, fish.value)
		DataManager.addFish(player, fish.name)
	end

	local rarityInfo = RarityData.info[fish.rarity]
	RodTool.playCatchFlourish(player, success, rarityInfo and rarityInfo.color)

	if not player.Parent then
		return
	end

	CatchResult:FireClient(player, {
		success = success,
		fishName = fish.name,
		rarity = fish.rarity,
		value = fish.value,
	})

	session.state = "idle"
	session.holding = false
end

CastRod.OnServerEvent:Connect(function(player)
	task.spawn(beginFishing, player)
end)

ReelInput.OnServerEvent:Connect(function(player, payload)
	local session = sessions[player]
	if not session or session.state ~= "reeling" then
		return
	end
	if typeof(payload) ~= "table" then
		return
	end
	session.holding = payload.holding == true
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
end)

Players.PlayerAdded:Connect(function(player)
	RodTool.give(player)
	player.CharacterAdded:Connect(function()
		RodTool.give(player)
	end)
end)
