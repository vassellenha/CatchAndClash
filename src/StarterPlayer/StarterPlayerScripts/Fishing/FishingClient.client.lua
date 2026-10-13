--[[
	FishingClient

	Builds a minimal fishing UI and talks to FishingService through the
	FishingRemotes. The client never decides success/fail on its own - it
	only renders whatever the server (authoritative) tells it, and reports
	whether the reel button is currently held.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Fishing.Remotes)
local RarityData = require(ReplicatedStorage.Fishing.RarityData)

local CastRod = Remotes.get("CastRod")
local FishBite = Remotes.get("FishBite")
local ReelInput = Remotes.get("ReelInput")
local ReelUpdate = Remotes.get("ReelUpdate")
local CatchResult = Remotes.get("CatchResult")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ===== UI =====

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FishingGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Cast button (always visible, bottom-right).
local castButton = Instance.new("TextButton")
castButton.Name = "CastButton"
castButton.Size = UDim2.fromOffset(140, 48)
castButton.Position = UDim2.new(1, -160, 1, -68)
castButton.AnchorPoint = Vector2.new(0, 0)
castButton.Text = "Lempar Pancing"
castButton.Font = Enum.Font.GothamBold
castButton.TextScaled = true
castButton.BackgroundColor3 = Color3.fromRGB(45, 130, 210)
castButton.TextColor3 = Color3.fromRGB(255, 255, 255)
castButton.Parent = screenGui

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.fromOffset(300, 32)
statusLabel.Position = UDim2.new(1, -320, 1, -108)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.TextStrokeTransparency = 0.4
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextScaled = true
statusLabel.Text = ""
statusLabel.Visible = false
statusLabel.Parent = screenGui

-- Reel minigame frame (hidden until a fish bites).
local reelFrame = Instance.new("Frame")
reelFrame.Name = "ReelFrame"
reelFrame.Size = UDim2.fromOffset(60, 360)
reelFrame.Position = UDim2.new(0.5, -30, 0.5, -180)
reelFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
reelFrame.BackgroundTransparency = 0.2
reelFrame.Visible = false
reelFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 10)
uiCorner.Parent = reelFrame

-- Progress bar (fills from the bottom as the player reels in).
local progressBarBg = Instance.new("Frame")
progressBarBg.Name = "ProgressBarBg"
progressBarBg.Size = UDim2.new(1, -16, 1, -16)
progressBarBg.Position = UDim2.fromOffset(8, 8)
progressBarBg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
progressBarBg.Parent = reelFrame

local progressFill = Instance.new("Frame")
progressFill.Name = "ProgressFill"
progressFill.AnchorPoint = Vector2.new(0, 1)
progressFill.Position = UDim2.new(0, 0, 1, 0)
progressFill.Size = UDim2.new(1, 0, 0.5, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(70, 200, 90)
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBarBg

-- Fish zone (the moving target window).
local zoneFrame = Instance.new("Frame")
zoneFrame.Name = "ZoneFrame"
zoneFrame.BackgroundColor3 = Color3.fromRGB(230, 200, 60)
zoneFrame.BackgroundTransparency = 0.3
zoneFrame.BorderSizePixel = 0
zoneFrame.Parent = reelFrame

-- Indicator (controlled by holding the reel button).
local indicatorFrame = Instance.new("Frame")
indicatorFrame.Name = "Indicator"
indicatorFrame.Size = UDim2.new(1, 0, 0, 6)
indicatorFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
indicatorFrame.BorderSizePixel = 0
indicatorFrame.Parent = reelFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "HintLabel"
hintLabel.Size = UDim2.new(1, 0, 0, 24)
hintLabel.Position = UDim2.new(0, 0, 0, -30)
hintLabel.BackgroundTransparency = 1
hintLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
hintLabel.TextStrokeTransparency = 0.4
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextScaled = true
hintLabel.Text = "Tahan klik buat narik!"
hintLabel.Parent = reelFrame

-- Catch popup (hidden until a fish is actually caught). Built entirely out
-- of UI shapes - a rounded "body" blob + angled "tail" blob + eye dot - so
-- it doesn't depend on any external image/icon asset.
local catchPopup = Instance.new("Frame")
catchPopup.Name = "CatchPopup"
catchPopup.AnchorPoint = Vector2.new(0.5, 0)
catchPopup.Position = UDim2.new(0.5, 0, 0, 24)
catchPopup.Size = UDim2.fromOffset(360, 104)
catchPopup.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
catchPopup.BackgroundTransparency = 0.08
catchPopup.Visible = false
catchPopup.Parent = screenGui

local catchPopupCorner = Instance.new("UICorner")
catchPopupCorner.CornerRadius = UDim.new(0, 14)
catchPopupCorner.Parent = catchPopup

local catchPopupStroke = Instance.new("UIStroke")
catchPopupStroke.Name = "RarityStroke"
catchPopupStroke.Thickness = 2.5
catchPopupStroke.Color = Color3.fromRGB(255, 255, 255)
catchPopupStroke.Parent = catchPopup

local catchPopupScale = Instance.new("UIScale")
catchPopupScale.Scale = 0.6
catchPopupScale.Parent = catchPopup

local iconHolder = Instance.new("Frame")
iconHolder.Name = "IconHolder"
iconHolder.Size = UDim2.fromOffset(72, 72)
iconHolder.Position = UDim2.fromOffset(16, 16)
iconHolder.BackgroundTransparency = 1
iconHolder.Parent = catchPopup

local fishTail = Instance.new("Frame")
fishTail.Name = "FishTail"
fishTail.AnchorPoint = Vector2.new(0.5, 0.5)
fishTail.Size = UDim2.fromOffset(26, 26)
fishTail.Position = UDim2.new(0, 14, 0.5, 0)
fishTail.Rotation = 45
fishTail.BackgroundColor3 = Color3.fromRGB(190, 190, 190)
fishTail.Parent = iconHolder

local fishTailCorner = Instance.new("UICorner")
fishTailCorner.CornerRadius = UDim.new(0.2, 0)
fishTailCorner.Parent = fishTail

local fishBody = Instance.new("Frame")
fishBody.Name = "FishBody"
fishBody.AnchorPoint = Vector2.new(0.5, 0.5)
fishBody.Size = UDim2.fromOffset(52, 34)
fishBody.Position = UDim2.new(0.5, 6, 0.5, 0)
fishBody.BackgroundColor3 = Color3.fromRGB(190, 190, 190)
fishBody.Parent = iconHolder

local fishBodyCorner = Instance.new("UICorner")
fishBodyCorner.CornerRadius = UDim.new(1, 0)
fishBodyCorner.Parent = fishBody

local fishEye = Instance.new("Frame")
fishEye.Name = "FishEye"
fishEye.AnchorPoint = Vector2.new(0.5, 0.5)
fishEye.Size = UDim2.fromOffset(6, 6)
fishEye.Position = UDim2.new(1, -12, 0.5, -4)
fishEye.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
fishEye.Parent = fishBody

local fishEyeCorner = Instance.new("UICorner")
fishEyeCorner.CornerRadius = UDim.new(1, 0)
fishEyeCorner.Parent = fishEye

local rarityLabel = Instance.new("TextLabel")
rarityLabel.Name = "RarityLabel"
rarityLabel.Size = UDim2.new(1, -108, 0, 22)
rarityLabel.Position = UDim2.fromOffset(100, 14)
rarityLabel.BackgroundTransparency = 1
rarityLabel.Font = Enum.Font.GothamBold
rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
rarityLabel.TextScaled = true
rarityLabel.Text = "RARITY"
rarityLabel.Parent = catchPopup

local fishNameLabel = Instance.new("TextLabel")
fishNameLabel.Name = "FishNameLabel"
fishNameLabel.Size = UDim2.new(1, -108, 0, 28)
fishNameLabel.Position = UDim2.fromOffset(100, 38)
fishNameLabel.BackgroundTransparency = 1
fishNameLabel.Font = Enum.Font.GothamBold
fishNameLabel.TextXAlignment = Enum.TextXAlignment.Left
fishNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
fishNameLabel.TextScaled = true
fishNameLabel.Text = "Nama Ikan"
fishNameLabel.Parent = catchPopup

local valueLabel = Instance.new("TextLabel")
valueLabel.Name = "ValueLabel"
valueLabel.Size = UDim2.new(1, -108, 0, 22)
valueLabel.Position = UDim2.fromOffset(100, 68)
valueLabel.BackgroundTransparency = 1
valueLabel.Font = Enum.Font.Gotham
valueLabel.TextXAlignment = Enum.TextXAlignment.Left
valueLabel.TextColor3 = Color3.fromRGB(140, 230, 150)
valueLabel.TextScaled = true
valueLabel.Text = "+0 uang"
valueLabel.Parent = catchPopup

-- ===== Helpers =====

local function percentToYOffset(percent)
	-- percent is 0-100 on the 0-100 scale used by the server; frame is
	-- oriented bottom-to-top, so invert it.
	return 1 - (percent / 100)
end

local function setStatus(text, seconds, color)
	statusLabel.Text = text
	statusLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	statusLabel.Visible = true
	if seconds then
		task.delay(seconds, function()
			if statusLabel.Text == text then
				statusLabel.Visible = false
			end
		end)
	end
end

local popupShowToken = 0

local function showCatchPopup(rarityInfo, fishName, value)
	popupShowToken += 1
	local myToken = popupShowToken

	fishTail.BackgroundColor3 = rarityInfo.color
	fishBody.BackgroundColor3 = rarityInfo.color
	catchPopupStroke.Color = rarityInfo.color
	rarityLabel.Text = string.upper(rarityInfo.displayName)
	rarityLabel.TextColor3 = rarityInfo.color
	fishNameLabel.Text = fishName
	valueLabel.Text = ("+%d uang"):format(value)

	catchPopup.Visible = true
	catchPopupScale.Scale = 0.6
	catchPopup.BackgroundTransparency = 0.08
	catchPopupStroke.Transparency = 0

	local popIn = TweenService:Create(
		catchPopupScale,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	)
	popIn:Play()

	task.delay(2.6, function()
		if popupShowToken ~= myToken then
			return
		end
		local fadeOut = TweenService:Create(
			catchPopupScale,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Scale = 0.6 }
		)
		fadeOut:Play()
		fadeOut.Completed:Wait()
		if popupShowToken == myToken then
			catchPopup.Visible = false
		end
	end)
end

-- ===== State =====

local isFishing = false
local isReeling = false
local holding = false

local function setHolding(newHolding)
	if not isReeling or holding == newHolding then
		return
	end
	holding = newHolding
	ReelInput:FireServer({ holding = holding })
end

-- ===== Input =====

castButton.MouseButton1Click:Connect(function()
	if isFishing then
		return
	end
	isFishing = true
	castButton.Visible = false
	setStatus("Melempar kail...")
	CastRod:FireServer()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.Space then
		setHolding(true)
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.Space then
		setHolding(false)
	end
end)

-- ===== Remote handlers =====

FishBite.OnClientEvent:Connect(function()
	isReeling = true
	holding = false
	statusLabel.Visible = false
	reelFrame.Visible = true
	progressFill.Size = UDim2.new(1, 0, 0.5, 0)
end)

ReelUpdate.OnClientEvent:Connect(function(data)
	if not isReeling then
		return
	end

	progressFill.Size = UDim2.new(1, 0, data.progress / 100, 0)

	local zoneHeight = data.zoneSize / 100
	local zoneTop = percentToYOffset(data.zoneCenter + data.zoneSize / 2)
	zoneFrame.Size = UDim2.new(1, 0, zoneHeight, 0)
	zoneFrame.Position = UDim2.new(0, 0, zoneTop, 0)

	local indicatorTop = percentToYOffset(data.indicator)
	indicatorFrame.Position = UDim2.new(0, 0, indicatorTop, 0)
end)

CatchResult.OnClientEvent:Connect(function(result)
	isReeling = false
	isFishing = false
	holding = false
	reelFrame.Visible = false
	castButton.Visible = true

	if result.success then
		local rarityInfo = RarityData.info[result.rarity] or RarityData.info.Common
		showCatchPopup(rarityInfo, result.fishName, result.value)
	else
		setStatus("Ikannya kabur...", 2.5, Color3.fromRGB(255, 255, 255))
	end
end)
