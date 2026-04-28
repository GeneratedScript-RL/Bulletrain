--!strict

local TweenService = game:GetService("TweenService")

local ButtonHoverTween = {}

type HoverTweenHandle = {
	Destroy: (self: HoverTweenHandle) -> (),
}

type TweenSettings = {
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
	RepeatCount: number?,
	Reverses: boolean?,
	DelayTime: number?,
	VisualTarget: GuiObject?,
	HoverOffset: Vector2?,
	HoverRotation: number?,
	HoverScaleMultiplier: number?,
	PressScaleMultiplier: number?,
}

local DEFAULT_TWEEN_SETTINGS: TweenSettings = {
	EasingStyle = Enum.EasingStyle.Quad,
	EasingDirection = Enum.EasingDirection.Out,
	RepeatCount = 0,
	Reverses = false,
	DelayTime = 0,
	VisualTarget = nil,
	HoverOffset = Vector2.new(0, -3),
	HoverRotation = 0,
	HoverScaleMultiplier = 0,
	PressScaleMultiplier = 0.97,
}

local HOVER_SCALE_NAME = "ButtonHoverTweenScale"

local function resolveSettings(tweenSettings: TweenSettings?): TweenSettings
	local settings = tweenSettings or {}

	return {
		EasingStyle = settings.EasingStyle or DEFAULT_TWEEN_SETTINGS.EasingStyle,
		EasingDirection = settings.EasingDirection or DEFAULT_TWEEN_SETTINGS.EasingDirection,
		RepeatCount = settings.RepeatCount or DEFAULT_TWEEN_SETTINGS.RepeatCount,
		Reverses = if settings.Reverses ~= nil then settings.Reverses else DEFAULT_TWEEN_SETTINGS.Reverses,
		DelayTime = settings.DelayTime or DEFAULT_TWEEN_SETTINGS.DelayTime,
		VisualTarget = settings.VisualTarget,
		HoverOffset = settings.HoverOffset or DEFAULT_TWEEN_SETTINGS.HoverOffset,
		HoverRotation = settings.HoverRotation or DEFAULT_TWEEN_SETTINGS.HoverRotation,
		HoverScaleMultiplier = settings.HoverScaleMultiplier or DEFAULT_TWEEN_SETTINGS.HoverScaleMultiplier,
		PressScaleMultiplier = settings.PressScaleMultiplier or DEFAULT_TWEEN_SETTINGS.PressScaleMultiplier,
	}
end

local function isInvisibleHitbox(target: GuiObject): boolean
	local imageTransparency = 1
	if target:IsA("ImageButton") or target:IsA("ImageLabel") then
		imageTransparency = target.ImageTransparency
	end

	return target.BackgroundTransparency >= 0.99 and imageTransparency >= 0.99
end

local function resolveVisualTarget(button: GuiObject, overrideTarget: GuiObject?): GuiObject
	if overrideTarget then
		return overrideTarget
	end

	local parent = button.Parent
	if parent and parent:IsA("GuiObject") and isInvisibleHitbox(button) then
		return parent
	end

	return button
end

local function getOrCreateScale(target: GuiObject): UIScale
	local existing = target:FindFirstChild(HOVER_SCALE_NAME)
	if existing and existing:IsA("UIScale") then
		return existing
	end

	local scale = Instance.new("UIScale")
	scale.Name = HOVER_SCALE_NAME
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

local function getAxisSizeValue(axis: UDim): number
	if math.abs(axis.Scale) > 0.001 then
		return axis.Scale * 1000 + axis.Offset
	end

	return axis.Offset
end

local function resolveHoverScaleMultiplier(hoverSize: UDim2, unhoverSize: UDim2, settings: TweenSettings): number
	local overrideMultiplier = settings.HoverScaleMultiplier or 0
	if overrideMultiplier > 0 then
		return overrideMultiplier
	end

	local ratios = {}

	local baseX = getAxisSizeValue(unhoverSize.X)
	local hoverX = getAxisSizeValue(hoverSize.X)
	if math.abs(baseX) > 0.001 then
		table.insert(ratios, hoverX / baseX)
	end

	local baseY = getAxisSizeValue(unhoverSize.Y)
	local hoverY = getAxisSizeValue(hoverSize.Y)
	if math.abs(baseY) > 0.001 then
		table.insert(ratios, hoverY / baseY)
	end

	if #ratios == 0 then
		return 1.05
	end

	local ratioSum = 0
	for _, ratio in ipairs(ratios) do
		ratioSum += ratio
	end

	return math.clamp(ratioSum / #ratios, 1, 1.16)
end

--[[
	Applies a hover/press tween effect to a button or hoverable GuiObject.
	The visible target can be overridden to support transparent hitboxes.

	@param button: GuiObject - The input target to observe for hover/click
	@param hoverSize: UDim2 - Previous API value used to infer the hover scale
	@param unhoverSize: UDim2 - Previous API value used to infer the base scale
	@param duration: number - Duration of the tween in seconds
	@param tweenSettings: TweenSettings? - Optional tween settings
]]
function ButtonHoverTween.apply(
	button: GuiObject,
	hoverSize: UDim2,
	unhoverSize: UDim2,
	duration: number,
	tweenSettings: TweenSettings?
): HoverTweenHandle
	local settings = resolveSettings(tweenSettings)
	local visualTarget = resolveVisualTarget(button, settings.VisualTarget)
	local hoverScaleMultiplier = resolveHoverScaleMultiplier(hoverSize, unhoverSize, settings)
	local pressScaleMultiplier = math.clamp(settings.PressScaleMultiplier or 0.97, 0.85, hoverScaleMultiplier)
	local canOffset = canOffsetTarget(visualTarget)
	local hoverOffset = settings.HoverOffset or Vector2.zero
	local hoverRotation = settings.HoverRotation or 0
	local basePosition = visualTarget.Position
	local baseRotation = visualTarget.Rotation
	local scaleObject = getOrCreateScale(visualTarget)
	local currentTweens = {} :: { Tween }
	local connections = {} :: { RBXScriptConnection }
	local isHovered = false
	local isPressed = false

	local tweenInfo = TweenInfo.new(
		duration,
		settings.EasingStyle or Enum.EasingStyle.Quad,
		settings.EasingDirection or Enum.EasingDirection.Out,
		settings.RepeatCount or 0,
		settings.Reverses == true,
		settings.DelayTime or 0
	)

	local function clearTweens()
		for _, tween in ipairs(currentTweens) do
			tween:Cancel()
		end

		table.clear(currentTweens)
	end

	local function rememberIdleState()
		if isHovered or isPressed then
			return
		end

		basePosition = visualTarget.Position
		baseRotation = visualTarget.Rotation
	end

	local function playTween(instance: Instance, properties: { [string]: any })
		local tween = TweenService:Create(instance, tweenInfo, properties)
		table.insert(currentTweens, tween)
		tween:Play()
	end

	local function refreshVisualState()
		clearTweens()

		local targetScale = if isPressed then pressScaleMultiplier else if isHovered then hoverScaleMultiplier else 1
		local targetPosition = basePosition
		local targetRotation = baseRotation

		if isHovered and canOffset then
			targetPosition = basePosition + UDim2.fromOffset(hoverOffset.X, hoverOffset.Y)
		end

		if isPressed and canOffset then
			targetPosition = basePosition + UDim2.fromOffset(hoverOffset.X * 0.35, hoverOffset.Y * 0.35)
		end

		if isHovered then
			targetRotation = baseRotation + hoverRotation
		end

		if isPressed then
			targetRotation = baseRotation + hoverRotation * 0.35
		end

		playTween(scaleObject, {
			Scale = targetScale,
		})

		if canOffset then
			playTween(visualTarget, {
				Position = targetPosition,
				Rotation = targetRotation,
			})
		elseif hoverRotation ~= 0 then
			playTween(visualTarget, {
				Rotation = targetRotation,
			})
		end
	end

	table.insert(connections, button.MouseEnter:Connect(function()
		if not isHovered then
			rememberIdleState()
		end

		isHovered = true
		refreshVisualState()
	end))

	table.insert(connections, button.MouseLeave:Connect(function()
		isHovered = false
		isPressed = false
		refreshVisualState()
	end))

	table.insert(connections, button.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		if not isHovered then
			rememberIdleState()
			isHovered = true
		end

		isPressed = true
		refreshVisualState()
	end))

	table.insert(connections, button.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		isPressed = false
		refreshVisualState()
	end))

	if button:IsA("GuiButton") then
		table.insert(connections, button.SelectionGained:Connect(function()
			if not isHovered then
				rememberIdleState()
			end

			isHovered = true
			refreshVisualState()
		end))

		table.insert(connections, button.SelectionLost:Connect(function()
			isHovered = false
			isPressed = false
			refreshVisualState()
		end))

		table.insert(connections, button.Activated:Connect(function()
			isPressed = false
			refreshVisualState()
		end))
	end

	return {
		Destroy = function(_self: HoverTweenHandle)
			clearTweens()

			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end

			table.clear(connections)
		end,
	}
end

return ButtonHoverTween
