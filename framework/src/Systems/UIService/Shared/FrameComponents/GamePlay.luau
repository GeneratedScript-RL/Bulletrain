--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local root = script.Parent.Parent.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local Trove = Dependencies.GetTrove()

local MAX_TOP_PLAYERS = 5
local MAX_KILLFEED_ENTRIES = 4
local KILLFEED_ENTRY_LIFETIME = 6
local ELIMINATION_BAR_LIFETIME = 2.5
local ELIMINATION_POP_DURATION = 0.18
local ELIMINATION_SETTLE_DURATION = 0.12
local ELIMINATION_FADE_DURATION = 0.38
local ELIMINATION_HOLD_DURATION =
	math.max(ELIMINATION_BAR_LIFETIME - ELIMINATION_POP_DURATION - ELIMINATION_SETTLE_DURATION - ELIMINATION_FADE_DURATION, 0)
local ELIMINATION_POP_TWEEN_INFO = TweenInfo.new(ELIMINATION_POP_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local ELIMINATION_SETTLE_TWEEN_INFO = TweenInfo.new(ELIMINATION_SETTLE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ELIMINATION_FADE_TWEEN_INFO = TweenInfo.new(ELIMINATION_FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local ELIMINATION_SKULL_START_SCALE = 0.82
local ELIMINATION_SKULL_POP_SCALE = 1.22
local ELIMINATION_SKULL_START_OFFSET_Y = 12
local ELIMINATION_SKULL_POP_OFFSET_Y = -14
local ELIMINATION_SKULL_FADE_OFFSET_Y = -22
local CROSSHAIR_DOT_SIZE = 4
local CROSSHAIR_THICKNESS = 2
local CROSSHAIR_MIN_GAP = 8
local CROSSHAIR_MAX_GAP = 30
local CROSSHAIR_MIN_LENGTH = 8
local CROSSHAIR_MAX_LENGTH = 18
local CROSSHAIR_SPEED_FOR_MAX_SPREAD = 36
local CROSSHAIR_SHOT_BLOOM_GAP = 18
local CROSSHAIR_SHOT_BLOOM_LENGTH = 6
local CROSSHAIR_SHOT_BLOOM_DECAY = 7
local CROSSHAIR_AIM_CONVERGE_SPEED = 14
local CROSSHAIR_AIM_FADE_START = 0.72
local CROSSHAIR_COLOR = Color3.fromRGB(245, 245, 245)
local CROSSHAIR_SHADOW_COLOR = Color3.fromRGB(16, 18, 20)
local CROSSHAIR_TRANSPARENCY = 0.08
local CROSSHAIR_SHADOW_TRANSPARENCY = 0.45

type WeaponSlotState = {
	Frame: GuiObject,
	ImageLabel: ImageLabel?,
	KeybindFrame: GuiObject?,
	OriginalFrameTransparency: number,
	OriginalImageTransparency: number,
	OriginalImageColor: Color3,
	OriginalKeybindTransparency: number,
}

type KillFeedEntry = {
	Id: number,
	KillerName: string,
	VictimName: string,
	WeaponName: string,
}

type RankedPlayer = {
	Player: Player,
	Kills: number,
}

type TransparencyRecord = {
	Instance: Instance,
	BackgroundTransparency: number?,
	TextTransparency: number?,
	TextStrokeTransparency: number?,
	ImageTransparency: number?,
	ScrollBarImageTransparency: number?,
	StrokeTransparency: number?,
}

type CrosshairState = {
	Root: Frame,
	Dot: Frame,
	Top: Frame,
	Bottom: Frame,
	Left: Frame,
	Right: Frame,
	ShotBloom: number,
	AimAlpha: number,
}

type CooldownBarState = {
	Frame: GuiObject,
	Fill: GuiObject?,
	FillFullSize: UDim2,
	ActiveTween: Tween?,
	ActiveTweenConnection: RBXScriptConnection?,
	RequestId: number,
}

type GamePlayComponent = {
	Frame: GuiObject,
	HealthAmountLabel: TextLabel?,
	HealthBar: GuiObject?,
	HealthBarFullSize: UDim2,
	MiddleFrame: GuiObject?,
	EliminatedBar: GuiObject?,
	EliminatedNameLabel: TextLabel?,
	Skull: GuiObject?,
	SkullBasePosition: UDim2,
	SkullBaseSize: UDim2,
	EliminationTransparencyRecords: { TransparencyRecord },
	EliminationDriver: NumberValue?,
	EliminationDriverConnection: RBXScriptConnection?,
	ActiveEliminationTweens: { Tween },
	NextEliminationBarId: number,
	KillFeedFrame: GuiObject?,
	KillFeedTemplate: GuiObject?,
	KillFeedEntries: { KillFeedEntry },
	DynamicKillFeedFrames: { GuiObject },
	NextKillFeedId: number,
	DefaultKillFeedImage: string,
	ShotgunKillImage: string,
	KnifeKillImage: string,
	ShotgunSlot: WeaponSlotState?,
	KnifeSlot: WeaponSlotState?,
	TimerLabel: TextLabel?,
	PlayerListFrame: GuiObject?,
	PlayerListTemplate: GuiObject?,
	DynamicTopEntries: { GuiObject },
	KillCounts: { [number]: number },
	ThumbnailCache: { [number]: string },
	Crosshair: CrosshairState?,
	CooldownBar: CooldownBarState?,
	_characterTrove: Types.Trove?,
	_destroyed: boolean,
	_trove: Types.Trove,
	Destroy: (self: GamePlayComponent) -> (),
}

local GamePlay = {}

local localPlayer = Players.LocalPlayer

local function getLerpAlpha(speed: number, deltaTime: number): number
	if speed <= 0 then
		return 1
	end

	return math.clamp(1 - math.exp(-speed * math.max(deltaTime, 0)), 0, 1)
end

local function addCrosshairStroke(guiObject: GuiObject)
	local stroke = Instance.new("UIStroke")
	stroke.Color = CROSSHAIR_SHADOW_COLOR
	stroke.Transparency = CROSSHAIR_SHADOW_TRANSPARENCY
	stroke.Thickness = 1
	stroke.Parent = guiObject
end

local function createCrosshairPart(name: string, parent: Instance): Frame
	local part = Instance.new("Frame")
	part.Name = name
	part.BackgroundColor3 = CROSSHAIR_COLOR
	part.BackgroundTransparency = CROSSHAIR_TRANSPARENCY
	part.BorderSizePixel = 0
	part.ZIndex = 101
	part.Parent = parent
	addCrosshairStroke(part)
	return part
end

local function createCrosshair(gamePlayFrame: GuiObject): CrosshairState
	local existingCrosshair = gamePlayFrame:FindFirstChild("DynamicCrosshair")
	if existingCrosshair then
		existingCrosshair:Destroy()
	end

	local root = Instance.new("Frame")
	root.Name = "DynamicCrosshair"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(0, 0)
	root.ZIndex = 100
	root.Parent = gamePlayFrame

	local dot = createCrosshairPart("Dot", root)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromOffset(0, 0)
	dot.Size = UDim2.fromOffset(CROSSHAIR_DOT_SIZE, CROSSHAIR_DOT_SIZE)

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	local top = createCrosshairPart("Top", root)
	top.AnchorPoint = Vector2.new(0.5, 1)

	local bottom = createCrosshairPart("Bottom", root)
	bottom.AnchorPoint = Vector2.new(0.5, 0)

	local left = createCrosshairPart("Left", root)
	left.AnchorPoint = Vector2.new(1, 0.5)

	local right = createCrosshairPart("Right", root)
	right.AnchorPoint = Vector2.new(0, 0.5)

	return {
		Root = root,
		Dot = dot,
		Top = top,
		Bottom = bottom,
		Left = left,
		Right = right,
		ShotBloom = 0,
		AimAlpha = 0,
	}
end

local function getLocalHorizontalSpeed(): number
	local character = localPlayer.Character
	if not character then
		return 0
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return 0
	end

	return (rootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
end

local function pulseCrosshair(crosshair: CrosshairState)
	crosshair.ShotBloom = 1
	crosshair.Root:SetAttribute("ShotBloom", crosshair.ShotBloom)
end

local function setCrosshairPartTransparency(part: Frame, backgroundTransparency: number, strokeTransparency: number)
	part.BackgroundTransparency = backgroundTransparency

	local stroke = part:FindFirstChildWhichIsA("UIStroke")
	if stroke then
		stroke.Transparency = strokeTransparency
	end
end

local function updateCrosshair(crosshair: CrosshairState, deltaTime: number?, isAiming: boolean)
	local targetAimAlpha = if isAiming then 1 else 0
	if deltaTime then
		local aimLerpAlpha = getLerpAlpha(CROSSHAIR_AIM_CONVERGE_SPEED, deltaTime)
		crosshair.AimAlpha = math.clamp(crosshair.AimAlpha + (targetAimAlpha - crosshair.AimAlpha) * aimLerpAlpha, 0, 1)
	else
		crosshair.AimAlpha = targetAimAlpha
	end

	local speed = getLocalHorizontalSpeed()
	local spreadAlpha = math.clamp(speed / CROSSHAIR_SPEED_FOR_MAX_SPREAD, 0, 1)
	local shotBloom = crosshair.ShotBloom
	local aimAlpha = crosshair.AimAlpha
	local hideAlpha = math.clamp((aimAlpha - CROSSHAIR_AIM_FADE_START) / (1 - CROSSHAIR_AIM_FADE_START), 0, 1)
	local baseGap =
		CROSSHAIR_MIN_GAP
		+ (CROSSHAIR_MAX_GAP - CROSSHAIR_MIN_GAP) * spreadAlpha
		+ CROSSHAIR_SHOT_BLOOM_GAP * shotBloom
	local baseLength =
		CROSSHAIR_MIN_LENGTH
		+ (CROSSHAIR_MAX_LENGTH - CROSSHAIR_MIN_LENGTH) * spreadAlpha
		+ CROSSHAIR_SHOT_BLOOM_LENGTH * shotBloom
	local gap = math.floor(baseGap * (1 - aimAlpha) + 0.5)
	local length = math.floor(baseLength * (1 - hideAlpha) + 0.5)
	local backgroundTransparency = CROSSHAIR_TRANSPARENCY + (1 - CROSSHAIR_TRANSPARENCY) * hideAlpha
	local strokeTransparency = CROSSHAIR_SHADOW_TRANSPARENCY + (1 - CROSSHAIR_SHADOW_TRANSPARENCY) * hideAlpha

	crosshair.Root:SetAttribute("Speed", speed)
	crosshair.Root:SetAttribute("SpreadAlpha", spreadAlpha)
	crosshair.Root:SetAttribute("ShotBloom", shotBloom)
	crosshair.Root:SetAttribute("AimAlpha", aimAlpha)
	crosshair.Root:SetAttribute("HideAlpha", hideAlpha)

	setCrosshairPartTransparency(crosshair.Dot, backgroundTransparency, strokeTransparency)
	setCrosshairPartTransparency(crosshair.Top, backgroundTransparency, strokeTransparency)
	setCrosshairPartTransparency(crosshair.Bottom, backgroundTransparency, strokeTransparency)
	setCrosshairPartTransparency(crosshair.Left, backgroundTransparency, strokeTransparency)
	setCrosshairPartTransparency(crosshair.Right, backgroundTransparency, strokeTransparency)

	crosshair.Top.Position = UDim2.fromOffset(0, -gap)
	crosshair.Top.Size = UDim2.fromOffset(CROSSHAIR_THICKNESS, length)

	crosshair.Bottom.Position = UDim2.fromOffset(0, gap)
	crosshair.Bottom.Size = UDim2.fromOffset(CROSSHAIR_THICKNESS, length)

	crosshair.Left.Position = UDim2.fromOffset(-gap, 0)
	crosshair.Left.Size = UDim2.fromOffset(length, CROSSHAIR_THICKNESS)

	crosshair.Right.Position = UDim2.fromOffset(gap, 0)
	crosshair.Right.Size = UDim2.fromOffset(length, CROSSHAIR_THICKNESS)

	if deltaTime and shotBloom > 0 then
		crosshair.ShotBloom = math.max(shotBloom - deltaTime * CROSSHAIR_SHOT_BLOOM_DECAY, 0)
	end
end

local function findTextLabel(container: Instance?, childName: string?): TextLabel?
	if not container then
		return nil
	end

	if childName then
		local namedChild = container:FindFirstChild(childName)
		if namedChild and namedChild:IsA("TextLabel") then
			return namedChild
		end
	end

	return container:FindFirstChildWhichIsA("TextLabel", true)
end

local function findImageLabel(container: Instance?, childName: string?): ImageLabel?
	if not container then
		return nil
	end

	if childName then
		local namedChild = container:FindFirstChild(childName)
		if namedChild and namedChild:IsA("ImageLabel") then
			return namedChild
		end
	end

	return container:FindFirstChildWhichIsA("ImageLabel", true)
end

local function findGuiObject(container: Instance?, childName: string, recursive: boolean?): GuiObject?
	if not container then
		return nil
	end

	local child = container:FindFirstChild(childName, recursive == true)
	if child and child:IsA("GuiObject") then
		return child
	end

	return nil
end

local function offsetUDim2(value: UDim2, xOffset: number, yOffset: number): UDim2
	return UDim2.new(value.X.Scale, value.X.Offset + xOffset, value.Y.Scale, value.Y.Offset + yOffset)
end

local function scaleUDim2(value: UDim2, scaleFactor: number): UDim2
	return UDim2.new(
		value.X.Scale * scaleFactor,
		math.floor(value.X.Offset * scaleFactor + 0.5),
		value.Y.Scale * scaleFactor,
		math.floor(value.Y.Offset * scaleFactor + 0.5)
	)
end

local function captureTransparencyRecord(records: { TransparencyRecord }, instance: Instance)
	local record: TransparencyRecord = {
		Instance = instance,
		BackgroundTransparency = nil,
		TextTransparency = nil,
		TextStrokeTransparency = nil,
		ImageTransparency = nil,
		ScrollBarImageTransparency = nil,
		StrokeTransparency = nil,
	}
	local didCapture = false

	if instance:IsA("GuiObject") then
		record.BackgroundTransparency = instance.BackgroundTransparency
		didCapture = true
	end

	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		local textObject = instance :: any
		record.TextTransparency = textObject.TextTransparency
		record.TextStrokeTransparency = textObject.TextStrokeTransparency
		didCapture = true
	end

	if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		local imageObject = instance :: any
		record.ImageTransparency = imageObject.ImageTransparency
		didCapture = true
	end

	if instance:IsA("ScrollingFrame") then
		record.ScrollBarImageTransparency = instance.ScrollBarImageTransparency
		didCapture = true
	end

	if instance:IsA("UIStroke") then
		record.StrokeTransparency = instance.Transparency
		didCapture = true
	end

	if didCapture then
		table.insert(records, record)
	end
end

local function appendTransparencyRecords(records: { TransparencyRecord }, rootInstance: Instance?)
	if not rootInstance then
		return
	end

	captureTransparencyRecord(records, rootInstance)

	for _, descendant in ipairs(rootInstance:GetDescendants()) do
		captureTransparencyRecord(records, descendant)
	end
end

local function blendTransparency(baseTransparency: number, alpha: number): number
	return baseTransparency + (1 - baseTransparency) * math.clamp(alpha, 0, 1)
end

local function applyTransparencyRecords(records: { TransparencyRecord }, alpha: number)
	for _, record in ipairs(records) do
		local instance = record.Instance
		local backgroundTransparency = record.BackgroundTransparency
		local textTransparency = record.TextTransparency
		local textStrokeTransparency = record.TextStrokeTransparency
		local imageTransparency = record.ImageTransparency
		local scrollBarImageTransparency = record.ScrollBarImageTransparency
		local strokeTransparency = record.StrokeTransparency

		if backgroundTransparency ~= nil and instance:IsA("GuiObject") then
			instance.BackgroundTransparency = blendTransparency(backgroundTransparency, alpha)
		end

		if textTransparency ~= nil and (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")) then
			local textObject = instance :: any
			textObject.TextTransparency = blendTransparency(textTransparency, alpha)
		end

		if textStrokeTransparency ~= nil and (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")) then
			local textObject = instance :: any
			textObject.TextStrokeTransparency = blendTransparency(textStrokeTransparency, alpha)
		end

		if imageTransparency ~= nil and (instance:IsA("ImageLabel") or instance:IsA("ImageButton")) then
			local imageObject = instance :: any
			imageObject.ImageTransparency = blendTransparency(imageTransparency, alpha)
		end

		if scrollBarImageTransparency ~= nil and instance:IsA("ScrollingFrame") then
			instance.ScrollBarImageTransparency = blendTransparency(scrollBarImageTransparency, alpha)
		end

		if strokeTransparency ~= nil and instance:IsA("UIStroke") then
			instance.Transparency = blendTransparency(strokeTransparency, alpha)
		end
	end
end

local function createCooldownBarState(reloadFrame: Instance?): CooldownBarState?
	if not reloadFrame or not reloadFrame:IsA("GuiObject") then
		return nil
	end

	local fill = findGuiObject(reloadFrame, "Reload")

	return {
		Frame = reloadFrame,
		Fill = fill,
		FillFullSize = if fill then fill.Size else UDim2.fromScale(1, 1),
		ActiveTween = nil,
		ActiveTweenConnection = nil,
		RequestId = 0,
	}
end

local function findUIStroke(container: Instance?, childName: string?): UIStroke?
	if not container then
		return nil
	end

	if childName then
		local namedChild = container:FindFirstChild(childName)
		if namedChild and namedChild:IsA("UIStroke") then
			return namedChild
		end
	end

	return container:FindFirstChildWhichIsA("UIStroke", true)
end

local function findUIGradient(container: Instance?, childName: string?): UIGradient?
	if not container then
		return nil
	end

	if childName then
		local namedChild = container:FindFirstChild(childName)
		if namedChild and namedChild:IsA("UIGradient") then
			return namedChild
		end
	end

	return container:FindFirstChildWhichIsA("UIGradient", true)
end

local function findChildWithPrefix(container: Instance?, prefix: string): GuiObject?
	if not container then
		return nil
	end

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") and string.sub(child.Name, 1, #prefix) == prefix then
			return child
		end
	end

	return nil
end

local function destroyChildrenWithPrefix(container: Instance?, prefix: string)
	if not container then
		return
	end

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") and string.sub(child.Name, 1, #prefix) == prefix then
			child:Destroy()
		end
	end
end

local function prepareTemplateFromPrefix(container: GuiObject?, prefix: string, templateName: string): GuiObject?
	if not container then
		return nil
	end

	local template: GuiObject? = nil

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") and string.sub(child.Name, 1, #prefix) == prefix then
			if template == nil then
				template = child
				template.Name = templateName
				template.Visible = false
				template.Archivable = true
				template.Parent = nil
			else
				child:Destroy()
			end
		end
	end

	return template
end

local function destroyGuiObjects(guiObjects: { GuiObject })
	for _, guiObject in ipairs(guiObjects) do
		guiObject:Destroy()
	end

	table.clear(guiObjects)
end

local function formatTimer(secondsRemaining: number): string
	local totalSeconds = math.max(math.floor(secondsRemaining + 0.5), 0)
	local minutes = math.floor(totalSeconds / 60)
	local seconds = totalSeconds % 60
	return ("%d:%02d"):format(minutes, seconds)
end

local function getKillFeedIcon(component: GamePlayComponent, weaponName: string): string
	if weaponName == "Knife" and component.KnifeKillImage ~= "" then
		return component.KnifeKillImage
	end

	if weaponName == "Shotgun" and component.ShotgunKillImage ~= "" then
		return component.ShotgunKillImage
	end

	if component.DefaultKillFeedImage ~= "" then
		return component.DefaultKillFeedImage
	end

	return if component.ShotgunKillImage ~= "" then component.ShotgunKillImage else component.KnifeKillImage
end

local function setHealth(component: GamePlayComponent, currentHealth: number, maxHealth: number)
	local safeMaxHealth = if maxHealth > 0 then maxHealth else 100
	local safeHealth = math.clamp(currentHealth, 0, safeMaxHealth)

	if component.HealthAmountLabel then
		component.HealthAmountLabel.Text = tostring(math.floor(safeHealth + 0.5))
	end

	if component.HealthBar then
		local ratio = if safeMaxHealth > 0 then safeHealth / safeMaxHealth else 0
		local fullSize = component.HealthBarFullSize
		component.HealthBar.Size = UDim2.new(
			fullSize.X.Scale * ratio,
			math.floor(fullSize.X.Offset * ratio + 0.5),
			fullSize.Y.Scale,
			fullSize.Y.Offset
		)
	end

	component.Frame:SetAttribute("Health", safeHealth)
	component.Frame:SetAttribute("MaxHealth", safeMaxHealth)
end

local function bindCharacter(component: GamePlayComponent, character: Model)
	if component._characterTrove then
		component._characterTrove:Clean()
	end

	local characterTrove = Trove.new()
	component._characterTrove = characterTrove

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if not humanoid or not humanoid:IsA("Humanoid") then
		setHealth(component, 0, 100)
		return
	end

	local function refreshHealth()
		setHealth(component, humanoid.Health, humanoid.MaxHealth)
	end

	refreshHealth()
	characterTrove:Connect(humanoid.HealthChanged, refreshHealth)
	characterTrove:Connect(humanoid:GetPropertyChangedSignal("MaxHealth"), refreshHealth)
end

local function createWeaponSlotState(slotFrame: Instance?): WeaponSlotState?
	if not slotFrame or not slotFrame:IsA("GuiObject") then
		return nil
	end

	local imageLabel = findImageLabel(slotFrame, "ImageLabel")
	local keybindFrame = findGuiObject(slotFrame, "Keybind")

	return {
		Frame = slotFrame,
		ImageLabel = imageLabel,
		KeybindFrame = keybindFrame,
		OriginalFrameTransparency = slotFrame.BackgroundTransparency,
		OriginalImageTransparency = if imageLabel then imageLabel.ImageTransparency else 0,
		OriginalImageColor = if imageLabel then imageLabel.ImageColor3 else Color3.new(1, 1, 1),
		OriginalKeybindTransparency = if keybindFrame then keybindFrame.BackgroundTransparency else 0.2,
	}
end

local function applyWeaponSlotState(slotState: WeaponSlotState?, isEquipped: boolean)
	if not slotState then
		return
	end

	slotState.Frame.BackgroundTransparency = if isEquipped
		then math.min(slotState.OriginalFrameTransparency, 0.7)
		else slotState.OriginalFrameTransparency
	slotState.Frame:SetAttribute("Equipped", isEquipped)

	if slotState.ImageLabel then
		slotState.ImageLabel.ImageTransparency = if isEquipped
			then slotState.OriginalImageTransparency
			else math.clamp(slotState.OriginalImageTransparency + 0.35, 0, 1)
		slotState.ImageLabel.ImageColor3 = if isEquipped
			then slotState.OriginalImageColor
			else slotState.OriginalImageColor:Lerp(Color3.fromRGB(110, 110, 110), 0.45)
	end

	if slotState.KeybindFrame then
		slotState.KeybindFrame.BackgroundTransparency = if isEquipped
			then math.max(slotState.OriginalKeybindTransparency - 0.08, 0)
			else math.min(slotState.OriginalKeybindTransparency + 0.18, 1)
	end
end

local function refreshWeaponSlots(component: GamePlayComponent, equippedWeaponName: string?)
	applyWeaponSlotState(component.ShotgunSlot, equippedWeaponName == "Shotgun")
	applyWeaponSlotState(component.KnifeSlot, equippedWeaponName == "Knife")
	component.Frame:SetAttribute("EquippedWeapon", equippedWeaponName)
end

local function setCooldownBarFill(cooldownBar: CooldownBarState, alpha: number)
	local fill = cooldownBar.Fill
	if not fill then
		return
	end

	local fullSize = cooldownBar.FillFullSize
	local clampedAlpha = math.clamp(alpha, 0, 1)
	fill.Size = UDim2.new(
		fullSize.X.Scale * clampedAlpha,
		math.floor(fullSize.X.Offset * clampedAlpha + 0.5),
		fullSize.Y.Scale,
		fullSize.Y.Offset
	)
end

local function stopCooldownBarTween(cooldownBar: CooldownBarState)
	if cooldownBar.ActiveTweenConnection then
		cooldownBar.ActiveTweenConnection:Disconnect()
		cooldownBar.ActiveTweenConnection = nil
	end

	if cooldownBar.ActiveTween then
		cooldownBar.ActiveTween:Cancel()
		cooldownBar.ActiveTween = nil
	end
end

local function resetCooldownBar(component: GamePlayComponent)
	local cooldownBar = component.CooldownBar
	if not cooldownBar then
		return
	end

	stopCooldownBarTween(cooldownBar)
	setCooldownBarFill(cooldownBar, 1)
	cooldownBar.Frame.Visible = false
	component.Frame:SetAttribute("CooldownWeapon", "")
	component.Frame:SetAttribute("CooldownAction", "")
	component.Frame:SetAttribute("CooldownDuration", 0)
end

local function playCooldownBar(component: GamePlayComponent, weaponName: string, actionName: string, duration: number)
	local cooldownBar = component.CooldownBar
	local fill = if cooldownBar then cooldownBar.Fill else nil
	if not cooldownBar or not fill then
		return
	end

	cooldownBar.RequestId += 1
	local requestId = cooldownBar.RequestId

	stopCooldownBarTween(cooldownBar)

	component.Frame:SetAttribute("CooldownWeapon", weaponName)
	component.Frame:SetAttribute("CooldownAction", actionName)
	component.Frame:SetAttribute("CooldownDuration", duration)

	cooldownBar.Frame.Visible = true
	setCooldownBarFill(cooldownBar, 0)

	if duration <= 0 then
		resetCooldownBar(component)
		return
	end

	local tween = TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = cooldownBar.FillFullSize,
	})
	cooldownBar.ActiveTween = tween
	cooldownBar.ActiveTweenConnection = tween.Completed:Connect(function()
		if cooldownBar.ActiveTweenConnection then
			cooldownBar.ActiveTweenConnection:Disconnect()
			cooldownBar.ActiveTweenConnection = nil
		end

		if cooldownBar.ActiveTween == tween then
			cooldownBar.ActiveTween = nil
		end

		if component._destroyed or cooldownBar.RequestId ~= requestId then
			return
		end

		resetCooldownBar(component)
	end)

	tween:Play()
end

local function renderKillFeed(component: GamePlayComponent)
	destroyGuiObjects(component.DynamicKillFeedFrames)

	local killFeedFrame = component.KillFeedFrame
	local killFeedTemplate = component.KillFeedTemplate
	if not killFeedFrame or not killFeedTemplate then
		return
	end

	for index, killFeedEntry in ipairs(component.KillFeedEntries) do
		local row = killFeedTemplate:Clone()
		row.Name = ("DeathLog_%d"):format(killFeedEntry.Id)
		row.LayoutOrder = index
		row.Visible = true

		local killerLabel = findTextLabel(row, "Killer")
		local killedLabel = findTextLabel(row, "Killed")
		local imageLabel = findImageLabel(row, "ImageLabel")

		if killerLabel then
			killerLabel.Text = killFeedEntry.KillerName
		end

		if killedLabel then
			killedLabel.Text = killFeedEntry.VictimName
		end

		if imageLabel then
			local icon = getKillFeedIcon(component, killFeedEntry.WeaponName)
			if icon ~= "" then
				imageLabel.Image = icon
			end
		end

		row.Parent = killFeedFrame
		table.insert(component.DynamicKillFeedFrames, row)
	end
end

local function setEliminationVisible(component: GamePlayComponent, isVisible: boolean)
	local middleFrame = component.MiddleFrame
	if middleFrame then
		middleFrame.Visible = isVisible
	end

	local eliminatedBar = component.EliminatedBar
	if eliminatedBar then
		eliminatedBar.Visible = isVisible
	end

	local skull = component.Skull
	if skull then
		skull.Visible = isVisible
	end
end

local function stopEliminationTweens(component: GamePlayComponent)
	for _, tween in ipairs(component.ActiveEliminationTweens) do
		tween:Cancel()
	end

	table.clear(component.ActiveEliminationTweens)
end

local function ensureEliminationDriver(component: GamePlayComponent): NumberValue
	local driver = component.EliminationDriver
	if driver then
		return driver
	end

	driver = Instance.new("NumberValue")
	driver.Name = "EliminationAlpha"
	driver.Value = 0
	component.EliminationDriver = driver
	component.EliminationDriverConnection = driver:GetPropertyChangedSignal("Value"):Connect(function()
		applyTransparencyRecords(component.EliminationTransparencyRecords, driver.Value)
	end)
	applyTransparencyRecords(component.EliminationTransparencyRecords, driver.Value)
	return driver
end

local function resetEliminationVisuals(component: GamePlayComponent)
	local driver = ensureEliminationDriver(component)
	driver.Value = 0

	local skull = component.Skull
	if skull then
		skull.Size = scaleUDim2(component.SkullBaseSize, ELIMINATION_SKULL_START_SCALE)
		skull.Position = offsetUDim2(component.SkullBasePosition, 0, ELIMINATION_SKULL_START_OFFSET_Y)
	end
end

local function finalizeEliminationVisuals(component: GamePlayComponent)
	stopEliminationTweens(component)

	local driver = component.EliminationDriver
	if driver then
		driver.Value = 1
	else
		applyTransparencyRecords(component.EliminationTransparencyRecords, 1)
	end

	local skull = component.Skull
	if skull then
		skull.Size = component.SkullBaseSize
		skull.Position = component.SkullBasePosition
	end

	setEliminationVisible(component, false)
end

local function trackEliminationTween(component: GamePlayComponent, tween: Tween): Tween
	table.insert(component.ActiveEliminationTweens, tween)
	return tween
end

local function showEliminationBar(component: GamePlayComponent, victimName: string)
	if not component.MiddleFrame and not component.EliminatedBar and not component.Skull then
		return
	end

	component.NextEliminationBarId += 1
	local eliminationBarId = component.NextEliminationBarId

	if component.EliminatedNameLabel then
		component.EliminatedNameLabel.Text = victimName
	end

	component.Frame:SetAttribute("LastEliminatedPlayer", victimName)

	stopEliminationTweens(component)
	setEliminationVisible(component, true)
	resetEliminationVisuals(component)

	local skull = component.Skull

	task.spawn(function()
		if skull then
			local popTween = trackEliminationTween(component, TweenService:Create(skull, ELIMINATION_POP_TWEEN_INFO, {
				Size = scaleUDim2(component.SkullBaseSize, ELIMINATION_SKULL_POP_SCALE),
				Position = offsetUDim2(component.SkullBasePosition, 0, ELIMINATION_SKULL_POP_OFFSET_Y),
			}))
			popTween:Play()
			popTween.Completed:Wait()

			if component._destroyed or component.NextEliminationBarId ~= eliminationBarId then
				return
			end

			table.clear(component.ActiveEliminationTweens)

			local settleTween = trackEliminationTween(component, TweenService:Create(skull, ELIMINATION_SETTLE_TWEEN_INFO, {
				Size = component.SkullBaseSize,
				Position = component.SkullBasePosition,
			}))
			settleTween:Play()
			settleTween.Completed:Wait()

			if component._destroyed or component.NextEliminationBarId ~= eliminationBarId then
				return
			end

			table.clear(component.ActiveEliminationTweens)
		end

		if ELIMINATION_HOLD_DURATION > 0 then
			task.wait(ELIMINATION_HOLD_DURATION)
		end

		if component._destroyed or component.NextEliminationBarId ~= eliminationBarId then
			return
		end

		local driver = ensureEliminationDriver(component)
		local alphaTween = trackEliminationTween(component, TweenService:Create(driver, ELIMINATION_FADE_TWEEN_INFO, {
			Value = 1,
		}))
		alphaTween:Play()

		if skull then
			local skullFadeTween = trackEliminationTween(component, TweenService:Create(skull, ELIMINATION_FADE_TWEEN_INFO, {
				Position = offsetUDim2(component.SkullBasePosition, 0, ELIMINATION_SKULL_FADE_OFFSET_Y),
			}))
			skullFadeTween:Play()
		end

		alphaTween.Completed:Wait()

		if component._destroyed or component.NextEliminationBarId ~= eliminationBarId then
			return
		end

		finalizeEliminationVisuals(component)
	end)
end

local function removeKillFeedEntry(component: GamePlayComponent, entryId: number)
	for index, killFeedEntry in ipairs(component.KillFeedEntries) do
		if killFeedEntry.Id == entryId then
			table.remove(component.KillFeedEntries, index)
			renderKillFeed(component)
			return
		end
	end
end

local function pushKillFeedEntry(component: GamePlayComponent, killerName: string, victimName: string, weaponName: string)
	component.NextKillFeedId += 1

	local killFeedEntry: KillFeedEntry = {
		Id = component.NextKillFeedId,
		KillerName = killerName,
		VictimName = victimName,
		WeaponName = weaponName,
	}

	table.insert(component.KillFeedEntries, 1, killFeedEntry)
	while #component.KillFeedEntries > MAX_KILLFEED_ENTRIES do
		table.remove(component.KillFeedEntries)
	end

	renderKillFeed(component)

	task.delay(KILLFEED_ENTRY_LIFETIME, function()
		if component._destroyed then
			return
		end

		removeKillFeedEntry(component, killFeedEntry.Id)
	end)
end

local function getPlayerAccentColor(player: Player): Color3?
	local team = player.Team
	if team then
		return team.TeamColor.Color
	end

	if not player.Neutral then
		return player.TeamColor.Color
	end

	return nil
end

local function applyPlayerCardTheme(player: Player, row: GuiObject)
	local accentColor = getPlayerAccentColor(player)
	if not accentColor then
		return
	end

	row.BackgroundColor3 = accentColor:Lerp(Color3.new(0, 0, 0), 0.24)

	local imageLabel = findImageLabel(row, "ImageLabel")
	if imageLabel then
		imageLabel.BackgroundColor3 = accentColor:Lerp(Color3.new(1, 1, 1), 0.18)
	end

	local innerStroke = findUIStroke(row, "Inner")
	if innerStroke then
		innerStroke.Color = accentColor:Lerp(Color3.new(1, 1, 1), 0.5)
	end

	local outerStroke = findUIStroke(row, "Outer")
	if outerStroke then
		outerStroke.Color = accentColor:Lerp(Color3.new(0, 0, 0), 0.08)
	end

	local gradient = findUIGradient(row, "UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, accentColor:Lerp(Color3.new(1, 1, 1), 0.2)),
			ColorSequenceKeypoint.new(1, accentColor:Lerp(Color3.new(0, 0, 0), 0.22)),
		})
	end
end

local function getRankedPlayers(component: GamePlayComponent): { RankedPlayer }
	local rankedPlayers: { RankedPlayer } = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local kills = component.KillCounts[player.UserId] or 0
		local playerState = player:GetAttribute("State")

		if playerState == "Combat" or kills > 0 then
			table.insert(rankedPlayers, {
				Player = player,
				Kills = kills,
			})
		end
	end

	table.sort(rankedPlayers, function(a: RankedPlayer, b: RankedPlayer): boolean
		if a.Kills ~= b.Kills then
			return a.Kills > b.Kills
		end

		return a.Player.Name < b.Player.Name
	end)

	while #rankedPlayers > MAX_TOP_PLAYERS do
		table.remove(rankedPlayers)
	end

	return rankedPlayers
end

local function applyThumbnail(component: GamePlayComponent, player: Player, imageLabel: ImageLabel)
	local cachedThumbnail = component.ThumbnailCache[player.UserId]
	if cachedThumbnail then
		imageLabel.Image = cachedThumbnail
		return
	end

	imageLabel:SetAttribute("ThumbnailUserId", player.UserId)

	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size150x150
			)
		end)

		if not ok or component._destroyed then
			return
		end

		component.ThumbnailCache[player.UserId] = image
		if imageLabel.Parent and imageLabel:GetAttribute("ThumbnailUserId") == player.UserId then
			imageLabel.Image = image
		end
	end)
end

local function renderTopPlayers(component: GamePlayComponent)
	destroyGuiObjects(component.DynamicTopEntries)

	local playerListFrame = component.PlayerListFrame
	local playerListTemplate = component.PlayerListTemplate
	if not playerListFrame or not playerListTemplate then
		return
	end

	for index, rankedPlayer in ipairs(getRankedPlayers(component)) do
		local row = playerListTemplate:Clone()
		row.Name = ("TopPlayer_%d"):format(rankedPlayer.Player.UserId)
		row.LayoutOrder = index
		row.Visible = true

		local killsLabel = findTextLabel(row, "Kills")
		local positionLabel = findTextLabel(row, "Position")
		local imageLabel = findImageLabel(row, "ImageLabel")

		if killsLabel then
			killsLabel.Text = tostring(rankedPlayer.Kills)
		end

		if positionLabel then
			positionLabel.Text = ("#%d"):format(index)
		end

		if imageLabel then
			applyThumbnail(component, rankedPlayer.Player, imageLabel)
		end

		applyPlayerCardTheme(rankedPlayer.Player, row)

		row.Parent = playerListFrame
		table.insert(component.DynamicTopEntries, row)
	end

	component.Frame:SetAttribute("TopPlayerCount", #component.DynamicTopEntries)
end

function GamePlay.Destroy(self: GamePlayComponent)
	self._destroyed = true

	if self.CooldownBar then
		stopCooldownBarTween(self.CooldownBar)
	end

	stopEliminationTweens(self)

	if self.EliminationDriverConnection then
		self.EliminationDriverConnection:Disconnect()
		self.EliminationDriverConnection = nil
	end

	if self.EliminationDriver then
		self.EliminationDriver:Destroy()
		self.EliminationDriver = nil
	end

	if self._characterTrove then
		self._characterTrove:Clean()
		self._characterTrove = nil
	end

	destroyGuiObjects(self.DynamicKillFeedFrames)
	destroyGuiObjects(self.DynamicTopEntries)
	self._trove:Clean()
end

function GamePlay.init(gamePlayFrame: GuiObject): GamePlayComponent
	local matchService = framework.GetService("MatchService")
	local scoreService = framework.GetService("ScoreService")
	local combatService = framework.GetService("CombatService")
	local viewmodelController = framework.GetController("ViewmodelController")
	local trove = Trove.new()

	local healthFrame = findGuiObject(gamePlayFrame, "Health")
	local healthBarHolder = findGuiObject(healthFrame, "BarHolder")
	local healthBar = findGuiObject(healthBarHolder, "Bar")
	local cooldownBar = createCooldownBarState(findGuiObject(gamePlayFrame, "Reload"))
	local middleFrame = findGuiObject(gamePlayFrame, "Middle")
	local eliminatedBar = findGuiObject(middleFrame, "EliminatedBar")
	local skull = findGuiObject(middleFrame, "Skull", true)
	local eliminationTransparencyRecords: { TransparencyRecord } = {}
	appendTransparencyRecords(eliminationTransparencyRecords, eliminatedBar)
	appendTransparencyRecords(eliminationTransparencyRecords, skull)

	local killFeedFrame = findGuiObject(gamePlayFrame, "KillFeed")
	local killFeedTemplateSource = findChildWithPrefix(killFeedFrame, "DeathLog")
	local killFeedTemplate = if killFeedTemplateSource then killFeedTemplateSource:Clone() else nil

	local topFrame = findGuiObject(gamePlayFrame, "Top")
	local playerListFrame = findGuiObject(topFrame, "PlayerList")
	local playerListTemplate = prepareTemplateFromPrefix(playerListFrame, "Player", "PlayerTemplate")
	local timerFrame = findGuiObject(topFrame, "Timer")

	local shotgunSlot = createWeaponSlotState(gamePlayFrame:FindFirstChild("ShotgunSlot"))
	local knifeSlot = createWeaponSlotState(gamePlayFrame:FindFirstChild("KnifeSlot"))
	local killFeedImageLabel = findImageLabel(killFeedTemplate, "ImageLabel")
	local crosshair = createCrosshair(gamePlayFrame)

	local component: GamePlayComponent = {
		Frame = gamePlayFrame,
		HealthAmountLabel = findTextLabel(healthBarHolder, "Amount"),
		HealthBar = healthBar,
		HealthBarFullSize = if healthBar then healthBar.Size else UDim2.fromScale(1, 1),
		MiddleFrame = middleFrame,
		EliminatedBar = eliminatedBar,
		EliminatedNameLabel = findTextLabel(eliminatedBar, "PlayerName") or findTextLabel(eliminatedBar, "Amount"),
		Skull = skull,
		SkullBasePosition = if skull then skull.Position else UDim2.fromOffset(0, 0),
		SkullBaseSize = if skull then skull.Size else UDim2.fromOffset(0, 0),
		EliminationTransparencyRecords = eliminationTransparencyRecords,
		EliminationDriver = nil,
		EliminationDriverConnection = nil,
		ActiveEliminationTweens = {},
		NextEliminationBarId = 0,
		KillFeedFrame = killFeedFrame,
		KillFeedTemplate = killFeedTemplate,
		KillFeedEntries = {},
		DynamicKillFeedFrames = {},
		NextKillFeedId = 0,
		DefaultKillFeedImage = if killFeedImageLabel then killFeedImageLabel.Image else "",
		ShotgunKillImage = if shotgunSlot and shotgunSlot.ImageLabel then shotgunSlot.ImageLabel.Image else "",
		KnifeKillImage = if knifeSlot and knifeSlot.ImageLabel then knifeSlot.ImageLabel.Image else "",
		ShotgunSlot = shotgunSlot,
		KnifeSlot = knifeSlot,
		TimerLabel = findTextLabel(timerFrame, "Amount"),
		PlayerListFrame = playerListFrame,
		PlayerListTemplate = playerListTemplate,
		DynamicTopEntries = {},
		KillCounts = {},
		ThumbnailCache = {},
		Crosshair = crosshair,
		CooldownBar = cooldownBar,
		_characterTrove = nil,
		_destroyed = false,
		_trove = trove,
		Destroy = GamePlay.Destroy,
	}

	trove:Add(crosshair.Root)
	updateCrosshair(crosshair, nil, viewmodelController:IsAiming())
	trove:Connect(RunService.RenderStepped, function(deltaTime: number)
		updateCrosshair(crosshair, deltaTime, viewmodelController:IsAiming())
	end)
	resetCooldownBar(component)

	destroyChildrenWithPrefix(killFeedFrame, "DeathLog")

	if component.KillFeedTemplate then
		component.KillFeedTemplate.Visible = true
	end

	setEliminationVisible(component, false)
	applyTransparencyRecords(component.EliminationTransparencyRecords, 1)
	if component.EliminatedNameLabel then
		component.EliminatedNameLabel.Text = ""
	end

	if component.PlayerListTemplate then
		component.PlayerListTemplate.Visible = false
		trove:Add(component.PlayerListTemplate)
	end

	local initialCountdown = matchService.Countdown:OnReady(5)
	if type(initialCountdown) == "number" and component.TimerLabel then
		component.TimerLabel.Text = formatTimer(initialCountdown)
	end

	trove:Add(matchService.Countdown:Observe(function(countdown: number)
		if component.TimerLabel then
			component.TimerLabel.Text = formatTimer(countdown)
		end
	end))

	local function refreshLeaderboard()
		renderTopPlayers(component)
	end

	local initialKillCounts = scoreService.KillCounts:OnReady(5)
	if type(initialKillCounts) == "table" then
		component.KillCounts = initialKillCounts
	end

	trove:Add(scoreService.KillCounts:Observe(function(killCounts: { [number]: number })
		component.KillCounts = killCounts
		refreshLeaderboard()
	end))

	local function bindPlayerStateSignals(player: Player)
		trove:Connect(player:GetAttributeChangedSignal("State"), refreshLeaderboard)
		trove:Connect(player:GetPropertyChangedSignal("Team"), refreshLeaderboard)
		trove:Connect(player:GetPropertyChangedSignal("TeamColor"), refreshLeaderboard)
		trove:Connect(player:GetPropertyChangedSignal("Neutral"), refreshLeaderboard)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		bindPlayerStateSignals(player)
	end

	trove:Connect(Players.PlayerAdded, function(player: Player)
		bindPlayerStateSignals(player)
		refreshLeaderboard()
	end)

	trove:Connect(Players.PlayerRemoving, function()
		task.defer(function()
			if not component._destroyed then
				refreshLeaderboard()
			end
		end)
	end)

	trove:Add(combatService.KillFeedEntryAdded:Connect(function(payload: any)
		if type(payload) ~= "table" then
			return
		end

		local killerUserId = tonumber(payload.killerUserId)
		local killerName = tostring(payload.killerName or "Unknown")
		local victimName = tostring(payload.victimName or "Unknown")
		local weaponName = tostring(payload.weaponName or "Shotgun")
		pushKillFeedEntry(component, killerName, victimName, weaponName)

		if killerUserId == localPlayer.UserId then
			showEliminationBar(component, victimName)
		end
	end))

	if viewmodelController.WeaponChanged then
		trove:Add(viewmodelController.WeaponChanged:Connect(function(weaponName: string?)
			refreshWeaponSlots(component, weaponName)
		end))
	end

	if viewmodelController.ShotgunFired then
		trove:Add(viewmodelController.ShotgunFired:Connect(function()
			pulseCrosshair(crosshair)
		end))
	end

	if viewmodelController.CooldownStarted then
		trove:Add(viewmodelController.CooldownStarted:Connect(function(weaponName: string, actionName: string, duration: number)
			playCooldownBar(component, weaponName, actionName, duration)
		end))
	end

	refreshWeaponSlots(component, viewmodelController:GetEquippedWeaponName())

	trove:Connect(localPlayer.CharacterAdded, function(character: Model)
		bindCharacter(component, character)
	end)

	trove:Connect(localPlayer.CharacterRemoving, function()
		if component._characterTrove then
			component._characterTrove:Clean()
			component._characterTrove = nil
		end

		setHealth(component, 0, 100)
	end)

	if localPlayer.Character then
		bindCharacter(component, localPlayer.Character)
	else
		setHealth(component, 0, 100)
	end

	refreshLeaderboard()

	return component
end

return GamePlay
