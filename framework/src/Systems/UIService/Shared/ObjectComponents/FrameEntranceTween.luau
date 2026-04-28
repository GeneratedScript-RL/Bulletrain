--!strict

local TweenService = game:GetService("TweenService")

local FrameEntranceTween = {}

type FrameEntranceHandle = {
	Destroy: (self: FrameEntranceHandle) -> (),
}

type EntranceSettings = {
	Duration: number?,
	StartScale: number?,
	Offset: Vector2?,
	Stagger: number?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
}

local ENTRANCE_SCALE_NAME = "FrameEntranceTweenScale"

local function getOrCreateScale(target: GuiObject): UIScale
	local existing = target:FindFirstChild(ENTRANCE_SCALE_NAME)
	if existing and existing:IsA("UIScale") then
		return existing
	end

	local scale = Instance.new("UIScale")
	scale.Name = ENTRANCE_SCALE_NAME
	scale.Scale = 1
	scale.Parent = target
	return scale
end

local function canOffsetTarget(target: GuiObject): boolean
	local parent = target.Parent
	if not parent then
		return true
	end

	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("UIListLayout") or child:IsA("UIGridLayout") or child:IsA("UITableLayout") then
			return false
		end
	end

	return true
end

function FrameEntranceTween.apply(frame: GuiObject, targets: { GuiObject }, entranceSettings: EntranceSettings?): FrameEntranceHandle
	local settings = entranceSettings or {}
	local duration = settings.Duration or 0.22
	local startScale = settings.StartScale or 0.95
	local offset = settings.Offset or Vector2.new(0, 18)
	local stagger = settings.Stagger or 0.035
	local easingStyle = settings.EasingStyle or Enum.EasingStyle.Quint
	local easingDirection = settings.EasingDirection or Enum.EasingDirection.Out
	local connections = {} :: { RBXScriptConnection }
	local currentTweens = {} :: { Tween }
	local destroyed = false

	local function clearTweens()
		for _, tween in ipairs(currentTweens) do
			tween:Cancel()
		end

		table.clear(currentTweens)
	end

	local function playEntrance()
		clearTweens()

		for index, target in ipairs(targets) do
			if not target.Parent then
				continue
			end

			local scale = getOrCreateScale(target)
			local basePosition = target.Position
			local shouldOffset = canOffsetTarget(target)
			local delayedTweenInfo = TweenInfo.new(
				duration,
				easingStyle,
				easingDirection,
				0,
				false,
				(index - 1) * stagger
			)

			scale.Scale = startScale
			if shouldOffset then
				target.Position = basePosition + UDim2.fromOffset(offset.X, offset.Y)
			end

			local scaleTween = TweenService:Create(scale, delayedTweenInfo, {
				Scale = 1,
			})
			table.insert(currentTweens, scaleTween)
			scaleTween:Play()

			if shouldOffset then
				local positionTween = TweenService:Create(target, delayedTweenInfo, {
					Position = basePosition,
				})
				table.insert(currentTweens, positionTween)
				positionTween:Play()
			end
		end
	end

	table.insert(connections, frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if destroyed or not frame.Visible then
			return
		end

		playEntrance()
	end))

	if frame.Visible then
		task.defer(function()
			if destroyed or not frame.Parent or not frame.Visible then
				return
			end

			playEntrance()
		end)
	end

	return {
		Destroy = function(_self: FrameEntranceHandle)
			destroyed = true
			clearTweens()

			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end

			table.clear(connections)
		end,
	}
end

return FrameEntranceTween
