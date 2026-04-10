--!strict

local TweenService = game:GetService("TweenService")

local ButtonHoverTween = {}

type HoverTweenHandle = {
	Destroy: (self: HoverTweenHandle) -> (),
}

type TweenSettings = {
	EasingStyle: Enum.EasingStyle,
	EasingDirection: Enum.EasingDirection,
	RepeatCount: number,
	Reverses: boolean,
	DelayTime: number,
}

local DEFAULT_TWEEN_SETTINGS: TweenSettings = {
	EasingStyle = Enum.EasingStyle.Quad,
	EasingDirection = Enum.EasingDirection.Out,
	RepeatCount = 0,
	Reverses = false,
	DelayTime = 0,
}

--[[
	Applies a size hover tween effect to a button.
	When the button is hovered, it tweens to hoverSize.
	When the button is unhovered or clicked, it tweens back to unhoverSize.

	@param button: GuiButton - The button to apply the effect to
	@param hoverSize: UDim2 - The size when hovered
	@param unhoverSize: UDim2 - The size when not hovered
	@param duration: number - Duration of the tween in seconds
	@param tweenSettings: TweenSettings? - Optional tween settings
]]
function ButtonHoverTween.apply(
	button: GuiButton,
	hoverSize: UDim2,
	unhoverSize: UDim2,
	duration: number,
	tweenSettings: TweenSettings?
): HoverTweenHandle
	local settings = tweenSettings or DEFAULT_TWEEN_SETTINGS

	local tweenInfo = TweenInfo.new(
		duration,
		settings.EasingStyle,
		settings.EasingDirection,
		settings.RepeatCount,
		settings.Reverses,
		settings.DelayTime
	)

	local currentTween: Tween? = nil
	local connections = {} :: { RBXScriptConnection }

	local function cancelCurrentTween()
		local tween = currentTween
		if tween == nil then
			return
		end

		tween:Cancel()
		currentTween = nil
	end

	local function tweenToSize(targetSize: UDim2)
		cancelCurrentTween()
		local tween = TweenService:Create(button, tweenInfo, { Size = targetSize })
		currentTween = tween
		tween:Play()
	end

	-- Mouse enter (hover)
	table.insert(connections, button.MouseEnter:Connect(function()
		tweenToSize(hoverSize)
	end))

	-- Mouse leave (unhover)
	table.insert(connections, button.MouseLeave:Connect(function()
		tweenToSize(unhoverSize)
	end))

	-- Activated (clicked)
	if button:IsA("GuiButton") then
		table.insert(connections, button.Activated:Connect(function()
			tweenToSize(unhoverSize)
		end))
	end

	return {
		Destroy = function(_self: HoverTweenHandle)
			cancelCurrentTween()

			for _, connection in connections do
				connection:Disconnect()
			end

			table.clear(connections)
		end,
	}
end

return ButtonHoverTween
