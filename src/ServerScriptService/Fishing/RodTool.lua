--[[
	RodTool

	Builds a procedural fishing rod Tool (no external mesh/animation assets
	needed) - a tapered, slightly bent rod with a reel, line, and hook -
	grants it to players, and plays a "cast" swing using a tween on the
	tool's hand-grip joint. Animating the grip joint (rather than the
	shoulder) moves just the rod relative to the hand, so it doesn't fight
	with the character's default walk/idle animations.
]]

local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local RodTool = {}

local function weldTo(base, part)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = part
	weld.Parent = base
end

local function buildTemplate()
	local tool = Instance.new("Tool")
	tool.Name = "FishingRod"
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	-- Handle = the grip (this is the part Roblox actually welds into the hand).
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.22, 1.0, 0.22)
	handle.Color = Color3.fromRGB(35, 30, 28)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.CastShadow = false
	handle.CFrame = CFrame.new(0, 0, 0)
	handle.Parent = tool

	-- Reel, stuck to the side of the grip.
	local reel = Instance.new("Part")
	reel.Name = "Reel"
	reel.Shape = Enum.PartType.Cylinder
	reel.Size = Vector3.new(0.4, 0.4, 0.4)
	reel.Color = Color3.fromRGB(50, 50, 55)
	reel.Material = Enum.Material.Metal
	reel.CanCollide = false
	reel.CastShadow = false
	reel.CFrame = handle.CFrame * CFrame.new(0, -0.25, 0.28)
	reel.Parent = tool
	weldTo(handle, reel)

	-- Tapered shaft: a few stacked, shrinking segments with a slight
	-- progressive bend, so it reads as a curved fishing rod rather than a
	-- straight stick.
	local segmentDefs = {
		{ size = Vector3.new(0.17, 1.3, 0.17), tilt = 3, color = Color3.fromRGB(40, 40, 45) },
		{ size = Vector3.new(0.13, 1.3, 0.13), tilt = 5, color = Color3.fromRGB(65, 65, 72) },
		{ size = Vector3.new(0.09, 1.2, 0.09), tilt = 6, color = Color3.fromRGB(95, 95, 100) },
		{ size = Vector3.new(0.05, 1.0, 0.05), tilt = 7, color = Color3.fromRGB(130, 130, 135) },
	}

	local topCFrame = handle.CFrame * CFrame.new(0, handle.Size.Y / 2, 0)
	local lastSegment = handle

	for i, def in ipairs(segmentDefs) do
		topCFrame = topCFrame * CFrame.Angles(math.rad(def.tilt), 0, 0)
		local segCFrame = topCFrame * CFrame.new(0, def.size.Y / 2, 0)

		local segment = Instance.new("Part")
		segment.Name = "Segment" .. i
		segment.Size = def.size
		segment.Color = def.color
		segment.Material = Enum.Material.SmoothPlastic
		segment.CanCollide = false
		segment.CastShadow = false
		segment.CFrame = segCFrame
		segment.Parent = tool
		weldTo(handle, segment)

		topCFrame = segCFrame * CFrame.new(0, def.size.Y / 2, 0)
		lastSegment = segment
	end

	local tipCFrame = topCFrame

	-- Hook, dangling out past the rod tip.
	local hook = Instance.new("Part")
	hook.Name = "Hook"
	hook.Shape = Enum.PartType.Ball
	hook.Size = Vector3.new(0.14, 0.14, 0.14)
	hook.Color = Color3.fromRGB(40, 40, 40)
	hook.Material = Enum.Material.Metal
	hook.CanCollide = false
	hook.CastShadow = false
	hook.CFrame = tipCFrame * CFrame.new(0.35, -1.3, 0.25)
	hook.Parent = tool
	weldTo(handle, hook)

	-- Fishing line, drawn as a thin Beam between the rod tip and the hook.
	local tipAttachment = Instance.new("Attachment")
	tipAttachment.Name = "LineStart"
	tipAttachment.Parent = lastSegment
	tipAttachment.CFrame = lastSegment.CFrame:ToObjectSpace(tipCFrame)

	local hookAttachment = Instance.new("Attachment")
	hookAttachment.Name = "LineEnd"
	hookAttachment.Parent = hook

	local line = Instance.new("Beam")
	line.Name = "Line"
	line.Attachment0 = tipAttachment
	line.Attachment1 = hookAttachment
	line.Width0 = 0.025
	line.Width1 = 0.025
	line.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235))
	line.Transparency = NumberSequence.new(0.3)
	line.FaceCamera = true
	line.Parent = lastSegment

	return tool
end

local template = buildTemplate()
template.Parent = ServerStorage

function RodTool.give(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	if backpack:FindFirstChild("FishingRod") then
		return
	end
	if player.Character and player.Character:FindFirstChild("FishingRod") then
		return
	end
	template:Clone().Parent = backpack
end

-- Roblox welds the hand to the tool's Handle with either a Weld (R6) or a
-- Motor6D (R15), and doesn't document a fixed name/location for it - so
-- instead of guessing, search the character for whichever joint actually
-- references the Handle.
local function findGripWeld(character)
	local tool = character:FindFirstChild("FishingRod")
	local handle = tool and tool:FindFirstChild("Handle")
	if not handle then
		return nil
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Weld") or descendant:IsA("Motor6D") then
			if descendant.Part0 == handle or descendant.Part1 == handle then
				return descendant
			end
		end
	end
	return nil
end

function RodTool.equip(player)
	local character = player.Character
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = backpack and backpack:FindFirstChild("FishingRod")

	if not humanoid then
		return false
	end
	if not character:FindFirstChild("FishingRod") and tool then
		humanoid:EquipTool(tool)
	end
	return character:FindFirstChild("FishingRod") ~= nil
end

local function waitForGripJoint(character)
	local joint
	for _ = 1, 20 do
		joint = findGripWeld(character)
		if joint then
			break
		end
		task.wait(0.05)
	end
	return joint
end

function RodTool.playCastSwing(player)
	local character = player.Character
	if not character then
		return
	end

	local joint = waitForGripJoint(character)
	if not joint then
		warn("[RodTool] Could not find the hand<->rod grip joint; skipping cast animation.")
		return
	end

	local originalC0 = joint.C0
	local backC0 = originalC0 * CFrame.Angles(math.rad(-50), 0, 0)
	local forwardC0 = originalC0 * CFrame.Angles(math.rad(30), 0, 0)

	-- Sine easing (rather than Quad) and slightly longer, overlapping-feeling
	-- durations read as a smooth, fluid cast instead of a snappy mechanical one.
	local windUp = TweenService:Create(joint, TweenInfo.new(0.32, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { C0 = backC0 })
	local cast = TweenService:Create(joint, TweenInfo.new(0.24, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { C0 = forwardC0 })
	local settle = TweenService:Create(joint, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { C0 = originalC0 })

	windUp:Play()
	windUp.Completed:Wait()

	-- The joint instance may have been destroyed (tool unequipped/character died) mid-swing.
	if joint.Parent then
		cast:Play()
		cast.Completed:Wait()
	end

	if joint.Parent then
		settle:Play()
	end
end

-- A small decorative fish that appears on the line after a successful catch,
-- wiggles once, then gets "reeled in" toward the player and shrinks away.
-- Purely cosmetic - the real catch bookkeeping already happened server-side.
local function spawnCaughtFishEffect(hookPosition, character, tintColor)
	local color = tintColor or Color3.fromRGB(255, 215, 90)

	local body = Instance.new("Part")
	body.Name = "CaughtFishEffect"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(0.5, 0.4, 0.9)
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CastShadow = false
	body.CFrame = CFrame.new(hookPosition)
	body.Parent = workspace

	local tail = Instance.new("Part")
	tail.Name = "Tail"
	tail.Size = Vector3.new(0.35, 0.3, 0.06)
	tail.Color = color
	tail.Material = Enum.Material.SmoothPlastic
	tail.Anchored = true
	tail.CanCollide = false
	tail.CanQuery = false
	tail.CastShadow = false
	tail.CFrame = body.CFrame * CFrame.new(0, 0, 0.55)
	tail.Parent = workspace

	local wiggleInfo = TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 4, true)
	local wiggleBody = TweenService:Create(body, wiggleInfo, { CFrame = body.CFrame * CFrame.Angles(0, math.rad(18), 0) })
	local wiggleTail = TweenService:Create(tail, wiggleInfo, { CFrame = tail.CFrame * CFrame.Angles(0, math.rad(18), 0) })
	wiggleBody:Play()
	wiggleTail:Play()
	wiggleBody.Completed:Wait()

	local humanoidRoot = character:FindFirstChild("HumanoidRootPart")
	local targetCFrame = humanoidRoot and (humanoidRoot.CFrame * CFrame.new(0, 1.5, -1)) or body.CFrame

	local reelInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local reelBody = TweenService:Create(body, reelInfo, { CFrame = targetCFrame, Size = Vector3.new(0.05, 0.05, 0.05) })
	local reelTail = TweenService:Create(tail, reelInfo, { CFrame = targetCFrame, Size = Vector3.new(0.05, 0.05, 0.05) })
	reelBody:Play()
	reelTail:Play()
	reelBody.Completed:Wait()

	body:Destroy()
	tail:Destroy()
end

-- Plays a short "set the hook" snap on success, or a disappointed droop on
-- failure, and - on success - shows a little fish dangling on the line that
-- gets reeled in. Runs synchronously (blocks ~0.4-0.6s) so callers can fire
-- the catch result message right after, in sync with the animation.
function RodTool.playCatchFlourish(player, success, tintColor)
	local character = player.Character
	if not character then
		return
	end

	local joint = findGripWeld(character)
	if joint then
		local originalC0 = joint.C0

		if success then
			local snapC0 = originalC0 * CFrame.Angles(math.rad(-22), 0, 0)
			local snap = TweenService:Create(joint, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { C0 = snapC0 })
			local back = TweenService:Create(joint, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { C0 = originalC0 })

			snap:Play()
			snap.Completed:Wait()
			if joint.Parent then
				back:Play()
			end
		else
			local dipC0 = originalC0 * CFrame.Angles(math.rad(14), 0, 0)
			local dip = TweenService:Create(joint, TweenInfo.new(0.22, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { C0 = dipC0 })
			local back = TweenService:Create(joint, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { C0 = originalC0 })

			dip:Play()
			dip.Completed:Wait()
			if joint.Parent then
				back:Play()
			end
		end
	end

	if success then
		local tool = character:FindFirstChild("FishingRod")
		local hook = tool and tool:FindFirstChild("Hook")
		if hook then
			spawnCaughtFishEffect(hook.Position, character, tintColor)
		end
	end
end

return RodTool
