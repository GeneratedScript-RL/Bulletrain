--!strict

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local root = script.Parent.Parent.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local ObjectComponents = require(script.Parent.Parent.ObjectComponents)
local Trove = Dependencies.GetTrove()

local SPIN_TWEEN_INFO = TweenInfo.new(5.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

type SpinningComponent = {
	Frame: GuiObject,
	MainFrame: GuiObject?,
	ScrollingFrame: ScrollingFrame?,
	SkipButtonFrame: GuiObject?,
	SkipButton: GuiButton?,
	TemplateCard: GuiObject?,
	DynamicCards: { GuiObject },
	ActiveTween: Tween?,
	ActiveOpeningId: number?,
	TargetCanvasPosition: Vector2,
	RevealScheduled: boolean,
	_trove: Types.Trove,
	Destroy: (self: SpinningComponent) -> (),
}

local Spinning = {}

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

local function findGuiObject(container: Instance?, childName: string): GuiObject?
	if not container then
		return nil
	end

	local child = container:FindFirstChild(childName)
	if child and child:IsA("GuiObject") then
		return child
	end

	return nil
end

local function clearDynamicCards(component: SpinningComponent)
	for _, card in ipairs(component.DynamicCards) do
		card:Destroy()
	end

	table.clear(component.DynamicCards)
end

local function cancelActiveTween(component: SpinningComponent)
	local activeTween = component.ActiveTween
	if activeTween then
		activeTween:Cancel()
		component.ActiveTween = nil
	end
end

local function updateCanvasSize(scrollingFrame: ScrollingFrame)
	local layout = scrollingFrame:FindFirstChildWhichIsA("UIListLayout") or scrollingFrame:FindFirstChildWhichIsA("UIGridLayout")
	if not layout then
		return
	end

	local absoluteContentSize = (layout :: any).AbsoluteContentSize
	if layout:IsA("UIListLayout") and layout.FillDirection == Enum.FillDirection.Horizontal then
		scrollingFrame.CanvasSize = UDim2.fromOffset(absoluteContentSize.X + 12, 0)
	else
		scrollingFrame.CanvasSize = UDim2.fromOffset(0, absoluteContentSize.Y + 12)
	end
end

local function resolveTargetCanvasPosition(scrollingFrame: ScrollingFrame, winnerCard: GuiObject): Vector2
	local layout = scrollingFrame:FindFirstChildWhichIsA("UIListLayout")
	local isHorizontal = layout ~= nil and layout.FillDirection == Enum.FillDirection.Horizontal
	local currentCanvasPosition = scrollingFrame.CanvasPosition

	if isHorizontal then
		local currentOffset = winnerCard.AbsolutePosition.X - scrollingFrame.AbsolutePosition.X
		local targetX = currentCanvasPosition.X + currentOffset - (scrollingFrame.AbsoluteSize.X - winnerCard.AbsoluteSize.X) / 2
		local maxX = math.max(scrollingFrame.AbsoluteCanvasSize.X - scrollingFrame.AbsoluteWindowSize.X, 0)
		return Vector2.new(math.clamp(targetX, 0, maxX), currentCanvasPosition.Y)
	end

	local currentOffset = winnerCard.AbsolutePosition.Y - scrollingFrame.AbsolutePosition.Y
	local targetY = currentCanvasPosition.Y + currentOffset - (scrollingFrame.AbsoluteSize.Y - winnerCard.AbsoluteSize.Y) / 2
	local maxY = math.max(scrollingFrame.AbsoluteCanvasSize.Y - scrollingFrame.AbsoluteWindowSize.Y, 0)
	return Vector2.new(currentCanvasPosition.X, math.clamp(targetY, 0, maxY))
end

local function revealOpening(component: SpinningComponent)
	if component.RevealScheduled then
		return
	end

	component.RevealScheduled = true

	local shopController = framework.GetController("ShopController")
	local openingState = shopController:GetOpeningState()
	local payload = openingState.Payload
	local openingId = if payload then payload.openingId else component.ActiveOpeningId
	shopController:RevealCurrentOpening(openingId)
end

local function populateSpinCards(component: SpinningComponent, payload: any)
	clearDynamicCards(component)

	local scrollingFrame = component.ScrollingFrame
	local templateCard = component.TemplateCard
	local spinItems = payload.spinItems
	if not scrollingFrame or not templateCard or type(spinItems) ~= "table" then
		return nil
	end

	for index, spinItem in ipairs(spinItems) do
		local card = templateCard:Clone()
		card.Name = ("SpinItem_%d"):format(index)
		card.Visible = true
		card.LayoutOrder = index
		card.Parent = scrollingFrame

		local itemNameLabel = findTextLabel(card, "ItemName")
		local itemIcon = findImageLabel(card, "Item")
		local itemName = tostring(spinItem.name or "Unknown")
		local itemRarity = tostring(spinItem.rarity or "Common")

		if itemNameLabel then
			itemNameLabel.Text = ("%s [%s]"):format(itemName, itemRarity)
		end

		if itemIcon and type(spinItem.icon) == "string" and spinItem.icon ~= "" then
			itemIcon.Image = spinItem.icon
		end

		table.insert(component.DynamicCards, card)
	end

	updateCanvasSize(scrollingFrame)
	return component.DynamicCards[payload.winningIndex]
end

local function playOpening(component: SpinningComponent, payload: any)
	local scrollingFrame = component.ScrollingFrame
	if not scrollingFrame then
		return
	end

	component.RevealScheduled = false
	component.Frame:SetAttribute("OpenOverride", true)
	component.Frame:SetAttribute("CaseName", tostring(payload.caseName or "Case"))
	component.Frame:SetAttribute("WinningIndex", payload.winningIndex or 0)
	component.ActiveOpeningId = payload.openingId

	cancelActiveTween(component)
	scrollingFrame.CanvasPosition = Vector2.zero

	local winnerCard = populateSpinCards(component, payload)
	if not winnerCard then
		revealOpening(component)
		return
	end

	RunService.Heartbeat:Wait()
	RunService.Heartbeat:Wait()

	component.TargetCanvasPosition = resolveTargetCanvasPosition(scrollingFrame, winnerCard)

	local tween = TweenService:Create(scrollingFrame, SPIN_TWEEN_INFO, {
		CanvasPosition = component.TargetCanvasPosition,
	})
	component.ActiveTween = tween
	tween:Play()

	tween.Completed:Connect(function()
		if component.ActiveTween == tween then
			component.ActiveTween = nil
		end

		revealOpening(component)
	end)
end

function Spinning.Destroy(self: SpinningComponent)
	cancelActiveTween(self)
	clearDynamicCards(self)
	self._trove:Clean()
end

function Spinning.init(spinningFrame: GuiObject): SpinningComponent
	local shopController = framework.GetController("ShopController")
	local trove = Trove.new()
	local mainFrame = findGuiObject(spinningFrame, "Main")
	local itemListFrame = if mainFrame then findGuiObject(mainFrame, "ItemList") else nil
	local scrollingFrame = if itemListFrame then itemListFrame:FindFirstChildWhichIsA("ScrollingFrame", true) else nil
	local templateSource = if scrollingFrame then findGuiObject(scrollingFrame, "ItemHolder") else nil
	local templateCard = if templateSource then templateSource:Clone() else nil
	local skipButtonFrame = findGuiObject(spinningFrame, "SkipButton")

	if scrollingFrame then
		for _, child in ipairs(scrollingFrame:GetChildren()) do
			if child:IsA("GuiObject") and child.Name:match("^ItemHolder") then
				child:Destroy()
			end
		end
	end

	local component: SpinningComponent = {
		Frame = spinningFrame,
		MainFrame = mainFrame,
		ScrollingFrame = if scrollingFrame and scrollingFrame:IsA("ScrollingFrame") then scrollingFrame else nil,
		SkipButtonFrame = skipButtonFrame,
		SkipButton = findButton(skipButtonFrame, "ButtonHitbox"),
		TemplateCard = templateCard,
		DynamicCards = {},
		ActiveTween = nil,
		ActiveOpeningId = nil,
		TargetCanvasPosition = Vector2.zero,
		RevealScheduled = false,
		_trove = trove,
		Destroy = Spinning.Destroy,
	}

	spinningFrame:SetAttribute("OpenOverride", false)

	if component.SkipButtonFrame then
		trove:Add(ObjectComponents.ButtonHoverTween.apply(
			component.SkipButtonFrame,
			component.SkipButtonFrame.Size + UDim2.fromScale(0.03, 0.03),
			component.SkipButtonFrame.Size,
			0.12
		))
	end

	if component.SkipButton and component.ScrollingFrame then
		trove:Connect(component.SkipButton.Activated, function()
			cancelActiveTween(component)
			component.ScrollingFrame.CanvasPosition = component.TargetCanvasPosition
			revealOpening(component)
		end)
	end

	trove:Add(shopController:ObserveOpeningState(function(openingState: any)
		local status = if type(openingState) == "table" then openingState.Status else "Idle"
		local payload = if type(openingState) == "table" then openingState.Payload else nil

		if status == "Spinning" and type(payload) == "table" then
			if component.ActiveOpeningId ~= payload.openingId then
				playOpening(component, payload)
			end
		else
			cancelActiveTween(component)
			clearDynamicCards(component)
			component.ActiveOpeningId = nil
			component.RevealScheduled = false
			component.Frame:SetAttribute("OpenOverride", false)
		end
	end))

	return component
end

return Spinning
