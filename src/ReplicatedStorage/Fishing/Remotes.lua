local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "FishingRemotes"
local EVENT_NAMES = {
	"CastRod",     -- client -> server: player cast the line
	"FishBite",    -- server -> client: a fish bit, start showing the reel UI
	"ReelInput",   -- client -> server: { holding = true/false }
	"ReelUpdate",  -- server -> client: { progress, zoneCenter, zoneSize, indicator }
	"CatchResult", -- server -> client: { success, fishName, value }
}

local Remotes = {}

local function getFolder()
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		if game:GetService("RunService"):IsServer() then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		else
			folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
		end
	end
	return folder
end

function Remotes.init()
	local folder = getFolder()
	for _, eventName in ipairs(EVENT_NAMES) do
		if not folder:FindFirstChild(eventName) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = eventName
			remote.Parent = folder
		end
	end
	return Remotes
end

function Remotes.get(name)
	local folder = getFolder()
	return folder:WaitForChild(name)
end

return Remotes
