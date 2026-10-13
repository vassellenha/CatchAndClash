-- Minimal DataStore wrapper for per-player fishing progress.
-- For a production game with many concurrent players, consider upgrading to
-- a session-locking library (e.g. ProfileService) to avoid duplication from
-- multi-server data races. This version is deliberately simple to get you
-- started and is safe for small/medium player counts.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local STORE_NAME = "FishingPlayerData_v1"

-- GetDataStore() itself throws (not just GetAsync/SetAsync) when the place
-- has never been published, or when Studio API access isn't enabled - so it
-- has to be pcall'd too. Without this, that single error bubbles up through
-- `require(DataManager)` and takes the entire FishingService script down
-- with it, since Luau module errors propagate to every require() call site.
local store
do
	local success, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if success then
		store = result
	else
		warn("[DataManager] DataStore unavailable (place not published yet, or Studio API access is off). Progress will not be saved this session: " .. tostring(result))
	end
end

local DEFAULT_DATA = {
	Cash = 0,
	FishCaught = {}, -- { [fishName] = count }
}

local DataManager = {}
local cache = {} -- [player] = data table

local function deepCopy(tbl)
	local copy = {}
	for k, v in pairs(tbl) do
		copy[k] = type(v) == "table" and deepCopy(v) or v
	end
	return copy
end

function DataManager.load(player)
	local data

	if store then
		local key = "Player_" .. player.UserId
		local success, result = pcall(function()
			return store:GetAsync(key)
		end)

		if success and result then
			data = result
		elseif not success then
			warn(("[DataManager] Failed to load data for %s: %s"):format(player.Name, tostring(result)))
		end
	end

	data = data or deepCopy(DEFAULT_DATA)

	cache[player] = data

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = data.Cash
	cash.Parent = leaderstats

	return data
end

function DataManager.get(player)
	return cache[player]
end

function DataManager.addCash(player, amount)
	local data = cache[player]
	if not data then
		return
	end
	data.Cash += amount

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash then
		cash.Value = data.Cash
	end
end

function DataManager.addFish(player, fishName)
	local data = cache[player]
	if not data then
		return
	end
	data.FishCaught[fishName] = (data.FishCaught[fishName] or 0) + 1
end

function DataManager.save(player)
	local data = cache[player]
	if not data or not store then
		return
	end

	local key = "Player_" .. player.UserId
	local success, err = pcall(function()
		store:SetAsync(key, data)
	end)

	if not success then
		warn(("[DataManager] Failed to save data for %s: %s"):format(player.Name, tostring(err)))
	end
end

function DataManager.release(player)
	DataManager.save(player)
	cache[player] = nil
end

Players.PlayerAdded:Connect(DataManager.load)
Players.PlayerRemoving:Connect(DataManager.release)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		DataManager.save(player)
	end
end)

return DataManager
