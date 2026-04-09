--!strict

local root = script.Parent.Parent.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local ObjectComponents = require(script.Parent.Parent.ObjectComponents)
local Trove = Dependencies.GetTrove()

type OpenedComponent = {
	Frame: GuiObject,
	ClaimButtonFrame: GuiObject?,
	ClaimButton: GuiButton?,
	TemplateCard: GuiObject?,
	ActiveCard: GuiObject?,
	YouOpenedLabel: TextLabel?,
	_trove: Types.Trove,
	Destroy: (self: OpenedComponent) -> (),
}

local Opened = {}

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

local function clearActiveCard(component: OpenedComponent)
	local activeCard = component.ActiveCard
	if activeCard then
		activeCard:Destroy()
		component.ActiveCard = nil
	end
end

local function renderResult(component: OpenedComponent, openingState: any)
	local payload = if type(openingState) == "table" then openingState.Payload else nil
	local reward = if type(payload) == "table" then payload.reward else nil
	if type(reward) ~= "table" then
		clearActiveCard(component)
		component.Frame:SetAttribute("OpenOverride", false)
		return
	end

	local templateCard = component.TemplateCard
	if not templateCard then
		component.Frame:SetAttribute("OpenOverride", false)
		return
	end

	clearActiveCard(component)

	local rewardCard = templateCard:Clone()
	rewardCard.Name = "OpenedReward"
	rewardCard.Visible = true
	rewardCard.Parent = component.Frame

	local itemNameLabel = findTextLabel(rewardCard, "ItemName")
	local itemIcon = findImageLabel(rewardCard, "Item")
	local duplicateCreditsAwarded = reward.duplicateCreditsAwarded
	local isDuplicate = reward.isDuplicate == true
	local name = tostring(reward.name or "Unknown")
	local rarity = tostring(reward.rarity or "Common")

	if itemNameLabel then
		if type(duplicateCreditsAwarded) == "number" and duplicateCreditsAwarded > 0 then
			itemNameLabel.Text = ("%s [%s] +%d Coins"):format(name, rarity, math.floor(duplicateCreditsAwarded + 0.5))
		else
			itemNameLabel.Text = ("%s [%s]"):format(name, rarity)
		end
	end

	if itemIcon and type(reward.icon) == "string" and reward.icon ~= "" then
		itemIcon.Image = reward.icon
	end

	if component.YouOpenedLabel then
		component.YouOpenedLabel.Text = if isDuplicate and type(duplicateCreditsAwarded) == "number" and duplicateCreditsAwarded > 0
			then "Duplicate converted to coins:"
			else "You opened:"
	end

	component.ActiveCard = rewardCard
	component.Frame:SetAttribute("OpenOverride", true)
	component.Frame:SetAttribute("RewardName", name)
	component.Frame:SetAttribute("RewardRarity", rarity)
	component.Frame:SetAttribute("IsDuplicate", isDuplicate)
	component.Frame:SetAttribute("DuplicateCreditsAwarded", if type(duplicateCreditsAwarded) == "number" then duplicateCreditsAwarded else 0)
end

function Opened.Destroy(self: OpenedComponent)
	clearActiveCard(self)
	self._trove:Clean()
end

function Opened.init(openedFrame: GuiObject): OpenedComponent
	local shopController = framework.GetController("ShopController")
	local trove = Trove.new()
	local claimButtonFrame = openedFrame:FindFirstChild("ClaimButton")
	local templateSource = openedFrame:FindFirstChild("ItemHolder")
	local templateCard = if templateSource and templateSource:IsA("GuiObject") then templateSource:Clone() else nil

	if templateSource then
		templateSource:Destroy()
	end

	local component: OpenedComponent = {
		Frame = openedFrame,
		ClaimButtonFrame = if claimButtonFrame and claimButtonFrame:IsA("GuiObject") then claimButtonFrame else nil,
		ClaimButton = findButton(claimButtonFrame, "ButtonHitbox"),
		TemplateCard = templateCard,
		ActiveCard = nil,
		YouOpenedLabel = findTextLabel(openedFrame, "YouOpened"),
		_trove = trove,
		Destroy = Opened.Destroy,
	}

	openedFrame:SetAttribute("OpenOverride", false)

	if component.ClaimButtonFrame then
		trove:Add(ObjectComponents.ButtonHoverTween.apply(
			component.ClaimButtonFrame,
			component.ClaimButtonFrame.Size + UDim2.fromScale(0.03, 0.03),
			component.ClaimButtonFrame.Size,
			0.12
		))
	end

	if component.ClaimButton then
		trove:Connect(component.ClaimButton.Activated, function()
			local openingState = shopController:GetOpeningState()
			local payload = openingState.Payload
			local openingId = if payload then payload.openingId else nil
			shopController:ClaimCurrentOpening(openingId)
		end)
	end

	trove:Add(shopController:ObserveOpeningState(function(openingState: any)
		local status = if type(openingState) == "table" then openingState.Status else "Idle"
		if status == "Opened" then
			renderResult(component, openingState)
		else
			clearActiveCard(component)
			openedFrame:SetAttribute("OpenOverride", false)
		end
	end))

	return component
end

return Opened
