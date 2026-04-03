--!strict

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local root = script.Parent.Parent.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local SettingDefinitions = require(root.Shared.Settings.Definitions)
local SettingTypes = require(root.Shared.Settings.Types)
local ObjectComponents = require(script.Parent.Parent.ObjectComponents)
local Trove = Dependencies.GetTrove()

type SettingDefinition = SettingTypes.SettingDefinition
type SettingKey = SettingTypes.SettingKey
type SettingsProfile = SettingTypes.SettingsProfile

type ToggleControl = {
	Definition: SettingDefinition,
	Row: GuiObject,
	SwitchFrame: GuiObject?,
	Button: GuiButton?,
	Circle: GuiObject?,
}

type SliderControl = {
	Definition: SettingDefinition,
	Row: GuiObject,
	BarFrame: GuiObject?,
	Button: GuiButton?,
	Tab: GuiObject?,
	ValueBox: TextBox?,
}

type SettingsComponent = {
	Frame: GuiObject,
	ExitButton: GuiButton?,
	ResetButton: GuiButton?,
	ScrollingFrame: ScrollingFrame?,
	ListLayout: UIListLayout?,
	ToggleControls: { [SettingKey]: ToggleControl },
	SliderControls: { [SettingKey]: SliderControl },
	DraggingSlider: SliderControl?,
	_trove: Types.Trove,
	Destroy: (self: SettingsComponent) -> (),
}

local Settings = {}

local function findButton(container: Instance?, childName: string?): GuiButton?
	if not container then
		return nil
	end

	if childName then
		local namedChild = container:FindFirstChild(childName)
		if namedChild and namedChild:IsA("GuiButton") then
			return namedChild
		end
	end

	local imageButton = container:FindFirstChildWhichIsA("ImageButton", true)
	if imageButton then
		return imageButton
	end

	return container:FindFirstChildWhichIsA("TextButton", true)
end

local function updateScrollingCanvas(scrollingFrame: ScrollingFrame, layout: UIListLayout)
	scrollingFrame.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
end

local function getSliderValue(definition: SettingDefinition, alpha: number): number
	local minimum = definition.Min or 0
	local maximum = definition.Max or 100
	local clampedAlpha = math.clamp(alpha, 0, 1)
	return math.round(minimum + (maximum - minimum) * clampedAlpha)
end

local function getSliderAlpha(definition: SettingDefinition, value: number): number
	local minimum = definition.Min or 0
	local maximum = definition.Max or 100
	if maximum <= minimum then
		return 0
	end

	return math.clamp((value - minimum) / (maximum - minimum), 0, 1)
end

local function applyToggleControl(control: ToggleControl, enabled: boolean)
	local row = control.Row
	row:SetAttribute("Value", enabled)

	local switchFrame = control.SwitchFrame
	if switchFrame then
		switchFrame:SetAttribute("Enabled", enabled)
	end

	local circle = control.Circle
	if circle then
		circle.AnchorPoint = Vector2.new(0, 0.5)
		local xOffset = if enabled then -circle.AbsoluteSize.X else 0
		local targetPosition = UDim2.new(if enabled then 1 else 0, xOffset, 0.5, 0)
		TweenService:Create(circle, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = targetPosition,
		}):Play()
	end
end

local function applySliderControl(control: SliderControl, value: number)
	local alpha = getSliderAlpha(control.Definition, value)
	control.Row:SetAttribute("Value", value)

	local tab = control.Tab
	if tab then
		tab.AnchorPoint = Vector2.new(0.5, 0.5)
		tab.Position = UDim2.fromScale(alpha, 0.5)
	end

	local valueBox = control.ValueBox
	if valueBox and not valueBox:IsFocused() then
		valueBox.Text = tostring(value)
	end
end

local function applyPreferences(component: SettingsComponent, preferences: SettingsProfile)
	for key, control in component.ToggleControls do
		applyToggleControl(control, (preferences :: any)[key] == true)
	end

	for key, control in component.SliderControls do
		applySliderControl(control, ((preferences :: any)[key] :: number))
	end
end

local function getPointerPosition(): Vector2
	local guiInset = GuiService:GetGuiInset()
	return UserInputService:GetMouseLocation() - guiInset
end

local function updateSliderFromPointer(control: SliderControl, settingsController: any)
	local barFrame = control.BarFrame
	if not barFrame or barFrame.AbsoluteSize.X <= 0 then
		return
	end

	local pointerPosition = getPointerPosition()
	local alpha = (pointerPosition.X - barFrame.AbsolutePosition.X) / barFrame.AbsoluteSize.X
	local value = getSliderValue(control.Definition, alpha)
	settingsController:SetPreference(control.Definition.Key, value)
end

local function bindToggleControl(control: ToggleControl, trove: Types.Trove, settingsController: any)
	local button = control.Button
	if not button then
		return
	end

	trove:Add(ObjectComponents.ButtonHoverTween.apply(
		button,
		button.Size + UDim2.fromScale(0.04, 0.04),
		button.Size,
		0.12
	))

	trove:Connect(button.Activated, function()
		local currentValue = settingsController:GetPreference(control.Definition.Key) == true
		settingsController:SetPreference(control.Definition.Key, not currentValue)
	end)
end

local function bindSliderControl(control: SliderControl, trove: Types.Trove, settingsController: any, component: SettingsComponent)
	local button = control.Button
	local valueBox = control.ValueBox

	if button then
		trove:Connect(button.InputBegan, function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end

			component.DraggingSlider = control
			updateSliderFromPointer(control, settingsController)
		end)
	end

	if valueBox then
		trove:Connect(valueBox.FocusLost, function(enterPressed: boolean)
			if not enterPressed then
				applySliderControl(control, settingsController:GetPreference(control.Definition.Key) :: number)
				return
			end

			local numericValue = tonumber(valueBox.Text)
			if numericValue == nil then
				applySliderControl(control, settingsController:GetPreference(control.Definition.Key) :: number)
				return
			end

			settingsController:SetPreference(control.Definition.Key, numericValue)
		end)
	end
end

local function buildControls(component: SettingsComponent, settingsFrame: GuiObject, trove: Types.Trove, settingsController: any)
	local mainFrame = settingsFrame:FindFirstChild("Main")
	local itemList = if mainFrame then mainFrame:FindFirstChild("ItemList") else nil
	local scrollingFrame = if itemList then itemList:FindFirstChild("ScrollingFrame") else nil

	if not scrollingFrame or not scrollingFrame:IsA("ScrollingFrame") then
		warn("[UIController] Settings.Main.ItemList.ScrollingFrame not found")
		return
	end

	component.ScrollingFrame = scrollingFrame
	component.ListLayout = scrollingFrame:FindFirstChildWhichIsA("UIListLayout")

	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if not child:IsA("GuiObject") or not child.Name:match("^Setting") then
			continue
		end

		local settingNameLabel = child:FindFirstChild("SettingName")
		if not settingNameLabel or not settingNameLabel:IsA("TextLabel") then
			continue
		end

		local definition = SettingDefinitions.ByLabel[settingNameLabel.Text] :: SettingDefinition?
		if not definition then
			continue
		end

		if definition.Kind == "toggle" then
			local switchFrame = child:FindFirstChild("Switch")
			local toggleControl: ToggleControl = {
				Definition = definition,
				Row = child,
				SwitchFrame = if switchFrame and switchFrame:IsA("GuiObject") then switchFrame else nil,
				Button = findButton(switchFrame, "ImageButton"),
				Circle = if switchFrame then (switchFrame:FindFirstChild("Circle") :: GuiObject?) else nil,
			}

			component.ToggleControls[definition.Key] = toggleControl
			bindToggleControl(toggleControl, trove, settingsController)
		else
			local barFrame = child:FindFirstChild("Bar")
			local tab = if barFrame then barFrame:FindFirstChild("Tab") else nil
			local valueInsert = child:FindFirstChild("ValueInsert")
			local valueBox = if valueInsert then valueInsert:FindFirstChild("Value") else nil

			local sliderControl: SliderControl = {
				Definition = definition,
				Row = child,
				BarFrame = if barFrame and barFrame:IsA("GuiObject") then barFrame else nil,
				Button = if tab then findButton(tab, "ButtonHitbox") else nil,
				Tab = if tab and tab:IsA("GuiObject") then tab else nil,
				ValueBox = if valueBox and valueBox:IsA("TextBox") then valueBox else nil,
			}

			component.SliderControls[definition.Key] = sliderControl
			bindSliderControl(sliderControl, trove, settingsController, component)
		end
	end

	local layout = component.ListLayout
	if layout then
		updateScrollingCanvas(scrollingFrame, layout)
		trove:Connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
			updateScrollingCanvas(scrollingFrame, layout)
		end)
	end
end

function Settings.Destroy(self: SettingsComponent)
	self._trove:Clean()
end

function Settings.init(settingsFrame: GuiObject): SettingsComponent
	local settingsController = framework.GetController("SettingsController")
	local trove = Trove.new()

	local component: SettingsComponent = {
		Frame = settingsFrame,
		ExitButton = nil,
		ResetButton = nil,
		ScrollingFrame = nil,
		ListLayout = nil,
		ToggleControls = {},
		SliderControls = {},
		DraggingSlider = nil,
		_trove = trove,
		Destroy = Settings.Destroy,
	}

	settingsFrame:SetAttribute("OpenOverride", false)
	settingsController:RegisterFrame(settingsFrame)

	local exitFrame = settingsFrame:FindFirstChild("ExitButton")
	local resetFrame = settingsFrame:FindFirstChild("Main")
	if resetFrame then
		resetFrame = resetFrame:FindFirstChild("ResetButton")
	end

	component.ExitButton = findButton(exitFrame, "ButtonHitbox")
	component.ResetButton = findButton(resetFrame, "ButtonHitbox")

	buildControls(component, settingsFrame, trove, settingsController)

	if component.ExitButton then
		trove:Add(ObjectComponents.ButtonHoverTween.apply(
			component.ExitButton,
			component.ExitButton.Size + UDim2.fromScale(0.06, 0.06),
			component.ExitButton.Size,
			0.12
		))

		trove:Connect(component.ExitButton.Activated, function()
			settingsController:Close()
		end)
	end

	if component.ResetButton then
		trove:Add(ObjectComponents.ButtonHoverTween.apply(
			component.ResetButton,
			component.ResetButton.Size + UDim2.fromScale(0.04, 0.04),
			component.ResetButton.Size,
			0.12
		))

		trove:Connect(component.ResetButton.Activated, function()
			settingsController:ResetPreferences()
		end)
	end

	trove:Add(settingsController:ObservePreferences(function(preferences: SettingsProfile)
		applyPreferences(component, preferences)
	end))

	trove:Connect(UserInputService.InputChanged, function(input: InputObject)
		local draggingSlider = component.DraggingSlider
		if not draggingSlider then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		updateSliderFromPointer(draggingSlider, settingsController)
	end)

	trove:Connect(UserInputService.InputEnded, function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			component.DraggingSlider = nil
		end
	end)

	task.defer(function()
		applyPreferences(component, settingsController:GetPreferences())
	end)

	return component
end

return Settings
