--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local root = script.Parent.Parent.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local CoinProducts = require(root.Shared.Shop.CoinProducts)
local Packs = require(root.Shared.Shop.Packs)
local SkinCases = require(root.Shared.Shop.SkinCases)
local ObjectComponents = require(script.Parent.Parent.ObjectComponents)
local ProfileSnapshot = require(script.Parent.Parent.ProfileSnapshot)
local Trove = Dependencies.GetTrove()

type CoinOffer = CoinProducts.CoinOffer
type CurrencyType = SkinCases.CurrencyType
type PackOffer = Packs.PackOffer
type ShopTab = "Packs" | "Cases" | "Coins"
type SkinCaseDefinition = SkinCases.SkinCaseDefinition

type TabControl = {
	Frame: GuiObject,
	Button: GuiButton?,
	Label: TextLabel?,
	Tab: ShopTab,
}

type ShopComponent = {
	Frame: GuiObject,
	BackButtonFrame: GuiObject?,
	BackButton: GuiButton?,
	ExitButton: GuiButton?,
	Tabs: { [ShopTab]: TabControl },
	SelectedTab: ShopTab,
	SelectedCaseId: string?,
	MainFrame: GuiObject?,
	CoinsHolder: GuiObject?,
	PacksScrollingFrame: ScrollingFrame?,
	CasesScrollingFrame: ScrollingFrame?,
	CaseView: GuiObject?,
	CoinTemplate: GuiObject?,
	PackTemplate: GuiObject?,
	CaseCoinsTemplate: GuiObject?,
	CaseRobuxTemplate: GuiObject?,
	CaseRewardTemplate: GuiObject?,
	_trove: Types.Trove,
	_detailTrove: Types.Trove?,
	Destroy: (self: ShopComponent) -> (),
}

local Shop = {}

local TAB_ORDER = {
	"Packs" :: ShopTab,
	"Cases" :: ShopTab,
	"Coins" :: ShopTab,
}

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

local function ensureButtonHitbox(itemHolder: GuiObject): GuiButton
	local existingButton = itemHolder:FindFirstChild("ButtonHitbox")
	if existingButton and existingButton:IsA("GuiButton") then
		return existingButton
	end

	local button = Instance.new("ImageButton")
	button.Name = "ButtonHitbox"
	button.BackgroundTransparency = 1
	button.ImageTransparency = 1
	button.AutoButtonColor = false
	button.Size = UDim2.fromScale(1, 1)
	button.Position = UDim2.fromScale(0, 0)
	button.ZIndex = itemHolder.ZIndex + 1
	button.Parent = itemHolder

	return button
end

local function applyHoverTween(trove: Types.Trove, target: GuiObject?, hoverScale: number, duration: number)
	if not target then
		return
	end

	trove:Add(ObjectComponents.ButtonHoverTween.apply(
		target,
		target.Size + UDim2.fromScale(hoverScale, hoverScale),
		target.Size,
		duration
	))
end

local function setOptionalImage(imageLabel: ImageLabel?, image: string)
	if imageLabel and image ~= "" then
		imageLabel.Image = image
	end
end

local function formatRobuxPrice(price: number): string
	return ("R$ %d"):format(price)
end

local function formatCoinPrice(price: number): string
	return ProfileSnapshot.FormatInteger(price)
end

local function updateScrollingCanvas(scrollingFrame: ScrollingFrame)
	local layout = scrollingFrame:FindFirstChildWhichIsA("UIListLayout") or scrollingFrame:FindFirstChildWhichIsA("UIGridLayout")

	if not layout then
		return
	end

	local absoluteContentSize = (layout :: any).AbsoluteContentSize
	scrollingFrame.CanvasSize = UDim2.fromOffset(0, absoluteContentSize.Y + 12)
end

local function bindCanvasSizeUpdates(trove: Types.Trove, scrollingFrame: ScrollingFrame?)
	if not scrollingFrame then
		return
	end

	local layout = scrollingFrame:FindFirstChildWhichIsA("UIListLayout") or scrollingFrame:FindFirstChildWhichIsA("UIGridLayout")

	if not layout then
		return
	end

	updateScrollingCanvas(scrollingFrame)
	trove:Connect((layout :: any):GetPropertyChangedSignal("AbsoluteContentSize"), function()
		updateScrollingCanvas(scrollingFrame)
	end)
end

local function getAssetsFolder(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets and assets:IsA("Folder") then
		return assets
	end

	return nil
end

local function cloneAssetTemplate(assetName: string): GuiObject?
	local assets = getAssetsFolder()
	if not assets then
		return nil
	end

	local template = assets:FindFirstChild(assetName)
	if template and template:IsA("GuiObject") then
		local clone = template:Clone()
		clone.Name = assetName .. "Template"
		clone.Visible = false
		clone.Archivable = true
		clone.Parent = nil
		return clone
	end

	return nil
end

local function extractContainerTemplate(container: Instance?, pattern: string, templateName: string): GuiObject?
	if not container then
		return nil
	end

	local template: GuiObject? = nil

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") and child.Name:match(pattern) then
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

local function cloneTemplate(template: GuiObject?): GuiObject?
	if not template then
		return nil
	end

	local clone = template:Clone()
	clone.Visible = false
	clone.Archivable = true
	clone.Parent = nil
	return clone
end

local function applyTabState(tabControl: TabControl, selected: boolean)
	tabControl.Frame.BackgroundTransparency = if selected then 0 else 0.2
	tabControl.Frame:SetAttribute("Selected", selected)

	if tabControl.Label then
		tabControl.Label.TextTransparency = if selected then 0 else 0.2
	end
end

local function refreshTabs(component: ShopComponent)
	for _, rawTabName in ipairs(TAB_ORDER) do
		local tabName = rawTabName :: ShopTab
		local tabControl = component.Tabs[tabName]
		if tabControl then
			applyTabState(tabControl, tabName == component.SelectedTab)
		end
	end
end

local function getQuickCaseCurrency(caseDefinition: SkinCaseDefinition): CurrencyType
	return caseDefinition.PrimaryCurrency
end

local function getQuickCasePrice(caseDefinition: SkinCaseDefinition): number?
	if caseDefinition.PrimaryCurrency == "Coins" then
		return caseDefinition.CoinPrice
	end

	return caseDefinition.RobuxPrice
end

local function formatCasePrice(currency: CurrencyType, price: number): string
	if currency == "Coins" then
		return formatCoinPrice(price)
	end

	return formatRobuxPrice(price)
end

local function formatChance(chance: number): string
	local roundedChance = math.round(chance * 100) / 100
	if math.abs(roundedChance - math.floor(roundedChance)) < 0.001 then
		return ("%d%%"):format(math.floor(roundedChance))
	end

	return ("%.2f%%"):format(roundedChance)
end

local function getCaseDefinitionById(shopController: any, caseId: string?): SkinCaseDefinition?
	if type(caseId) ~= "string" or caseId == "" then
		return nil
	end

	for _, caseDefinition in ipairs(shopController:GetCaseDefinitions()) do
		if caseDefinition.Id == caseId then
			return caseDefinition
		end
	end

	return nil
end

local function attemptPurchase(success: boolean, errorMessage: string?): boolean
	if not success and errorMessage then
		warn(("[ShopUI] %s"):format(errorMessage))
	end

	return success
end

local function clearCaseDetail(component: ShopComponent)
	local detailTrove = component._detailTrove
	if detailTrove then
		detailTrove:Clean()
		component._detailTrove = nil
	end
end

local function refreshVisiblePanels(component: ShopComponent)
	local mainFrame = component.MainFrame
	if not mainFrame then
		return
	end

	local packsScroll = if mainFrame then (mainFrame:FindFirstChild("PacksScroll") :: GuiObject?) else nil
	local coinsHolder = component.CoinsHolder
	local caseView = component.CaseView
	local casesHolder = if mainFrame then (mainFrame:FindFirstChild("CasesHolder") :: GuiObject?) else nil

	local showingCaseDetail = component.SelectedTab == "Cases" and component.SelectedCaseId ~= nil

	if packsScroll then
		packsScroll.Visible = component.SelectedTab == "Packs"
	end

	if coinsHolder then
		coinsHolder.Visible = component.SelectedTab == "Coins"
	end

	if caseView then
		caseView.Visible = showingCaseDetail
	end

	if casesHolder then
		casesHolder.Visible = component.SelectedTab == "Cases" and not showingCaseDetail
	end

	if component.BackButtonFrame then
		component.BackButtonFrame.Visible = showingCaseDetail
	end
end

local function renderCaseRewards(component: ShopComponent, caseDefinition: SkinCaseDefinition)
	local caseView = component.CaseView
	local rewardTemplate = component.CaseRewardTemplate
	if not caseView or not rewardTemplate then
		return
	end

	local rightSide = caseView:FindFirstChild("RightSide")
	local scrollingFrame = if rightSide then rightSide:FindFirstChildWhichIsA("ScrollingFrame", true) else nil
	if not scrollingFrame or not scrollingFrame:IsA("ScrollingFrame") then
		return
	end

	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:IsA("GuiObject") and child.Name:match("^CaseReward_") then
			child:Destroy()
		end
	end

	for index, reward in ipairs(caseDefinition.Rewards) do
		local rewardCard = rewardTemplate:Clone()
		rewardCard.Name = ("CaseReward_%d"):format(index)
		rewardCard.Visible = true
		rewardCard.LayoutOrder = index
		rewardCard.Parent = scrollingFrame

		local nameLabel = findTextLabel(rewardCard, "ItemName")
		local iconLabel = findImageLabel(rewardCard, "Item")

		if nameLabel then
			nameLabel.Text = ("%s [%s • %s]"):format(reward.Name, reward.Rarity, formatChance(reward.Chance))
		end

		setOptionalImage(iconLabel, reward.Icon)
	end

	updateScrollingCanvas(scrollingFrame)
end

local function renderCaseDetail(component: ShopComponent, shopController: any)
	clearCaseDetail(component)

	local caseView = component.CaseView
	local caseDefinition = getCaseDefinitionById(shopController, component.SelectedCaseId)
	if not caseView or not caseDefinition then
		return
	end

	local detailTrove = Trove.new()
	component._detailTrove = detailTrove

	local leftSide = caseView:FindFirstChild("LeftSide")
	local purchaseButtonFrame = if leftSide then (leftSide:FindFirstChild("BuyButton") :: GuiObject?) else nil
	local caseCard = if leftSide then (leftSide:FindFirstChild("Case") :: GuiObject?) else nil
	local openButtonFrame = if caseCard then (caseCard:FindFirstChild("BuyButton") :: GuiObject?) else nil

	local caseNameLabel = findTextLabel(caseCard, "CaseName")
	local caseIcon = findImageLabel(caseCard, "CaseIcon")
	local openAmountLabel = if openButtonFrame then findTextLabel(openButtonFrame, "Amount") else nil
	local purchaseAmountLabel = if purchaseButtonFrame then findTextLabel(purchaseButtonFrame, "Amount") else nil
	local openButton = if openButtonFrame then ensureButtonHitbox(openButtonFrame) else nil
	local purchaseButton = if purchaseButtonFrame then findButton(purchaseButtonFrame, "ButtonHitbox") else nil
	local ownedCaseCount = shopController:GetOwnedCaseCount(caseDefinition.Id)
	local primaryCurrency = caseDefinition.PrimaryCurrency
	local primaryPrice = if primaryCurrency == "Coins" then caseDefinition.CoinPrice else caseDefinition.RobuxPrice
	local raritiesFrame = if caseCard then caseCard:FindFirstChild("Rarities") else nil

	if caseNameLabel then
		caseNameLabel.Text = if ownedCaseCount > 0
			then ("%s x%d"):format(caseDefinition.Name, ownedCaseCount)
			else caseDefinition.Name
	end

	setOptionalImage(caseIcon, caseDefinition.Icon)

	if openButtonFrame and openAmountLabel then
		local canOpen = ownedCaseCount > 0
		openButtonFrame.Visible = canOpen
		if canOpen then
			openAmountLabel.Text = ("OPEN x%d"):format(ownedCaseCount)
		end
	end

	if purchaseButtonFrame and purchaseAmountLabel then
		local hasPurchasePrice = type(primaryPrice) == "number"
		purchaseButtonFrame.Visible = hasPurchasePrice
		if hasPurchasePrice then
			purchaseAmountLabel.Text = formatCasePrice(primaryCurrency, primaryPrice :: number)
		end
	end

	if openButtonFrame and openButton and ownedCaseCount > 0 then
		applyHoverTween(detailTrove, openButtonFrame, 0.03, 0.1)
		detailTrove:Connect(openButton.Activated, function()
			local success, errorMessage = shopController:OpenCase(caseDefinition.Id)
			if not success and errorMessage then
				warn(("[ShopUI] %s"):format(errorMessage))
			end
		end)
	end

	if purchaseButtonFrame and purchaseButton and primaryPrice ~= nil then
		applyHoverTween(detailTrove, purchaseButtonFrame, 0.03, 0.1)
		detailTrove:Connect(purchaseButton.Activated, function()
			if attemptPurchase(shopController:PurchaseCase(caseDefinition.Id, primaryCurrency)) then
				renderCaseDetail(component, shopController)
			end
		end)
	end

	if raritiesFrame then
		for _, rarityName in ipairs({ "Common", "Rare", "Epic", "Legendary" }) do
			local chance = caseDefinition.RarityChances[rarityName] or 0
			local rarityFrame = raritiesFrame:FindFirstChild(rarityName)
			if rarityFrame and rarityFrame:IsA("GuiObject") then
				local chanceLabel = findTextLabel(rarityFrame, "Chance")
				local rarityLabel = findTextLabel(rarityFrame, "Rarity")
				rarityFrame.Visible = chance > 0

				if chanceLabel then
					chanceLabel.Text = ("%d%%"):format(chance)
				end

				if rarityLabel then
					rarityLabel.Text = rarityName .. ":"
				end
			end
		end
	end

	renderCaseRewards(component, caseDefinition)
end

local function setSelectedTab(component: ShopComponent, shopController: any, tabName: ShopTab)
	component.SelectedTab = tabName
	if tabName ~= "Cases" then
		component.SelectedCaseId = nil
	end

	refreshTabs(component)
	renderCaseDetail(component, shopController)
	refreshVisiblePanels(component)
end

local function renderCoinOffers(component: ShopComponent, shopController: any)
	local coinsHolder = component.CoinsHolder
	local template = component.CoinTemplate
	if not coinsHolder or not template then
		return
	end

	for index, offer in ipairs(shopController:GetCoinOffers() :: { CoinOffer }) do
		local card = template:Clone()
		card.Name = ("CoinPack_%d"):format(index)
		card.Visible = true
		card.LayoutOrder = index
		card.Parent = coinsHolder

		local amountLabel = findTextLabel(card, "Amount")
		local iconLabel = findImageLabel(card, "CoinIcon")
		local dealLabel = findTextLabel(card, "Deal")
		local buyButtonFrame = card:FindFirstChild("BuyButton") :: GuiObject?
		local buyAmountLabel = findTextLabel(buyButtonFrame, "Amount")
		local buyButton = if buyButtonFrame and buyButtonFrame:IsA("GuiObject")
			then ensureButtonHitbox(buyButtonFrame)
			else nil

		if amountLabel then
			amountLabel.Text = ("%s Coins"):format(ProfileSnapshot.FormatInteger(offer.Coins))
		end

		setOptionalImage(iconLabel, offer.Icon)

		if dealLabel then
			dealLabel.Visible = offer.BonusText ~= nil
			dealLabel.Text = offer.BonusText or ""
		end

		if buyAmountLabel then
			buyAmountLabel.Text = formatRobuxPrice(offer.RobuxPrice)
		end

		applyHoverTween(component._trove, card, 0.02, 0.1)
		if buyButtonFrame and buyButton then
			applyHoverTween(component._trove, buyButtonFrame :: GuiObject, 0.03, 0.1)
			component._trove:Connect(buyButton.Activated, function()
				attemptPurchase(shopController:PurchaseCoinOffer(offer.Id))
			end)
		end
	end
end

local function renderPackOffers(component: ShopComponent, shopController: any)
	local scrollingFrame = component.PacksScrollingFrame
	local template = component.PackTemplate
	if not scrollingFrame or not template then
		return
	end

	for index, packOffer in ipairs(shopController:GetPackOffers() :: { PackOffer }) do
		local card = template:Clone()
		card.Name = ("Pack_%d"):format(index)
		card.Visible = true
		card.LayoutOrder = index
		card.Parent = scrollingFrame

		local nameLabel = findTextLabel(card, "Amount")
		local iconLabel = findImageLabel(card, "CoinIcon")
		local buyButtonFrame = card:FindFirstChild("BuyButton") :: GuiObject?
		local buyAmountLabel = findTextLabel(buyButtonFrame, "Amount")
		local buyButton = if buyButtonFrame and buyButtonFrame:IsA("GuiObject")
			then ensureButtonHitbox(buyButtonFrame)
			else nil

		if nameLabel then
			nameLabel.Text = packOffer.Name
		end

		setOptionalImage(iconLabel, packOffer.Icon)

		if buyAmountLabel then
			buyAmountLabel.Text = formatRobuxPrice(packOffer.RobuxPrice)
		end

		applyHoverTween(component._trove, card, 0.02, 0.1)
		if buyButtonFrame and buyButton then
			applyHoverTween(component._trove, buyButtonFrame :: GuiObject, 0.03, 0.1)
			component._trove:Connect(buyButton.Activated, function()
				attemptPurchase(shopController:PurchasePack(packOffer.Id))
			end)
		end
	end

	updateScrollingCanvas(scrollingFrame)
end

local function renderCaseGrid(component: ShopComponent, shopController: any)
	local scrollingFrame = component.CasesScrollingFrame
	if not scrollingFrame then
		return
	end

	for index, caseDefinition in ipairs(shopController:GetCaseDefinitions() :: { SkinCaseDefinition }) do
		local currency = getQuickCaseCurrency(caseDefinition) :: CurrencyType
		local template = if currency == "Coins" then component.CaseCoinsTemplate else component.CaseRobuxTemplate
		if not template then
			continue
		end

		local card = template:Clone()
		card.Name = ("Case_%d"):format(index)
		card.Visible = true
		card.LayoutOrder = index
		card.Parent = scrollingFrame

		local openButton = findButton(card, "ButtonHitbox")
		local buyButtonFrame = card:FindFirstChild("BuyButton") :: GuiObject?
		local buyButton = nil :: GuiButton?
		if buyButtonFrame then
			buyButton = ensureButtonHitbox(buyButtonFrame)
		end
		local caseNameLabel = findTextLabel(card, "CaseName")
		local caseIcon = findImageLabel(card, "CaseIcon")
		local buyAmountLabel = findTextLabel(buyButtonFrame, "Amount")
		local price = getQuickCasePrice(caseDefinition)
		local ownedCaseCount = shopController:GetOwnedCaseCount(caseDefinition.Id)

		if caseNameLabel then
			caseNameLabel.Text = if ownedCaseCount > 0
				then ("%s x%d"):format(caseDefinition.Name, ownedCaseCount)
				else caseDefinition.Name
		end

		setOptionalImage(caseIcon, caseDefinition.Icon)

		if buyButtonFrame and buyAmountLabel and price ~= nil then
			buyButtonFrame.Visible = true
			buyAmountLabel.Text = formatCasePrice(currency, price)
		elseif buyButtonFrame then
			buyButtonFrame.Visible = false
		end

		applyHoverTween(component._trove, card, 0.02, 0.1)

		if openButton then
			component._trove:Connect(openButton.Activated, function()
				component.SelectedCaseId = caseDefinition.Id
				renderCaseDetail(component, shopController)
				refreshVisiblePanels(component)
			end)
		end

		if buyButtonFrame and buyButton then
			applyHoverTween(component._trove, buyButtonFrame :: GuiObject, 0.03, 0.1)
			component._trove:Connect(buyButton.Activated, function()
				if attemptPurchase(shopController:PurchaseCase(caseDefinition.Id, currency)) then
					component.SelectedCaseId = caseDefinition.Id
					renderCaseDetail(component, shopController)
					refreshVisiblePanels(component)
				end
			end)
		end
	end

	updateScrollingCanvas(scrollingFrame)
end

function Shop.Destroy(self: ShopComponent)
	clearCaseDetail(self)
	self._trove:Clean()
end

function Shop.init(shopFrame: GuiObject): ShopComponent
	local shopController = framework.GetController("ShopController")
	local trove = Trove.new()

	local component: ShopComponent = {
		Frame = shopFrame,
		BackButtonFrame = nil,
		BackButton = nil,
		ExitButton = nil,
		Tabs = {},
		SelectedTab = shopController:GetSelectedTab(),
		SelectedCaseId = nil,
		MainFrame = nil,
		CoinsHolder = nil,
		PacksScrollingFrame = nil,
		CasesScrollingFrame = nil,
		CaseView = nil,
		CoinTemplate = nil,
		PackTemplate = nil,
		CaseCoinsTemplate = nil,
		CaseRobuxTemplate = nil,
		CaseRewardTemplate = nil,
		_trove = trove,
		_detailTrove = nil,
		Destroy = Shop.Destroy,
	}

	shopFrame:SetAttribute("OpenOverride", false)
	shopController:RegisterFrame(shopFrame)

	local backButtonFrame = shopFrame:FindFirstChild("BackButton")
	local exitButtonFrame = shopFrame:FindFirstChild("ExitButton")
	local mainFrame = shopFrame:FindFirstChild("Main")
	local tabsFrame = shopFrame:FindFirstChild("Tabs")

	component.BackButtonFrame = if backButtonFrame and backButtonFrame:IsA("GuiObject") then backButtonFrame else nil
	component.BackButton = findButton(backButtonFrame, "ButtonHitbox")
	component.ExitButton = findButton(exitButtonFrame, "ButtonHitbox")
	component.MainFrame = if mainFrame and mainFrame:IsA("GuiObject") then mainFrame else nil

	if component.MainFrame then
		local packsScroll = component.MainFrame:FindFirstChild("PacksScroll")
		local casesHolder = component.MainFrame:FindFirstChild("CasesHolder")
		local coinsHolder = component.MainFrame:FindFirstChild("CoinsHolder")
		local caseView = component.MainFrame:FindFirstChild("CaseView")
		local casesFrame = if casesHolder then casesHolder:FindFirstChild("Cases") else nil
		local casesScrollingFrame = if casesFrame then casesFrame:FindFirstChildWhichIsA("ScrollingFrame", true) else nil
		local packsScrollingFrame = if packsScroll then packsScroll:FindFirstChildWhichIsA("ScrollingFrame", true) else nil
		local rewardsScrollingFrame = if caseView then caseView:FindFirstChildWhichIsA("ScrollingFrame", true) else nil

		component.CoinsHolder = if coinsHolder and coinsHolder:IsA("GuiObject") then coinsHolder else nil
		component.CasesScrollingFrame = if casesScrollingFrame and casesScrollingFrame:IsA("ScrollingFrame")
			then casesScrollingFrame
			else nil
		component.PacksScrollingFrame = if packsScrollingFrame and packsScrollingFrame:IsA("ScrollingFrame")
			then packsScrollingFrame
			else nil
		component.CaseView = if caseView and caseView:IsA("GuiObject") then caseView else nil

		local coinsFallback = extractContainerTemplate(component.CoinsHolder, "^Pack", "CoinTemplate")
		local packsFallback = extractContainerTemplate(component.PacksScrollingFrame, "^Pack", "PackTemplate")
		local casesFallback = extractContainerTemplate(component.CasesScrollingFrame, "^Case", "CaseTemplate")
		local rewardsFallback = extractContainerTemplate(rewardsScrollingFrame, "^ItemHolder", "CaseRewardTemplate")

		component.CoinTemplate = cloneAssetTemplate("CoinsPack") or coinsFallback
		component.PackTemplate = cloneAssetTemplate("Pack") or packsFallback
		component.CaseCoinsTemplate = cloneAssetTemplate("CaseCoins") or casesFallback
		component.CaseRobuxTemplate = cloneAssetTemplate("CaseRobux") or cloneTemplate(casesFallback) or cloneTemplate(component.CaseCoinsTemplate)
		component.CaseRewardTemplate = rewardsFallback

		if component.CoinTemplate then
			trove:Add(component.CoinTemplate)
		end

		if component.PackTemplate then
			trove:Add(component.PackTemplate)
		end

		if component.CaseCoinsTemplate then
			trove:Add(component.CaseCoinsTemplate)
		end

		if component.CaseRobuxTemplate and component.CaseRobuxTemplate ~= component.CaseCoinsTemplate then
			trove:Add(component.CaseRobuxTemplate)
		end

		if component.CaseRewardTemplate then
			trove:Add(component.CaseRewardTemplate)
		end

		renderCoinOffers(component, shopController)
		renderPackOffers(component, shopController)
		renderCaseGrid(component, shopController)

		bindCanvasSizeUpdates(trove, component.PacksScrollingFrame)
		bindCanvasSizeUpdates(trove, component.CasesScrollingFrame)
		if rewardsScrollingFrame and rewardsScrollingFrame:IsA("ScrollingFrame") then
			bindCanvasSizeUpdates(trove, rewardsScrollingFrame)
		end
	else
		warn("[UIController] ShopHolder.Main not found")
	end

	if tabsFrame and tabsFrame:IsA("GuiObject") then
		for _, rawTabName in ipairs(TAB_ORDER) do
			local tabName = rawTabName :: ShopTab
			local tabFrame = tabsFrame:FindFirstChild(tabName)
			if tabFrame and tabFrame:IsA("GuiObject") then
				local tabControl: TabControl = {
					Frame = tabFrame,
					Button = findButton(tabFrame, "ButtonHitbox"),
					Label = findTextLabel(tabFrame, tabName),
					Tab = tabName,
				}

				component.Tabs[tabName] = tabControl
			end
		end
	end

	if component.ExitButton then
		applyHoverTween(trove, exitButtonFrame :: GuiObject?, 0.04, 0.12)
		trove:Connect(component.ExitButton.Activated, function()
			shopController:Close()
		end)
	end

	if component.BackButton then
		applyHoverTween(trove, backButtonFrame :: GuiObject?, 0.04, 0.12)
		trove:Connect(component.BackButton.Activated, function()
			component.SelectedCaseId = nil
			renderCaseDetail(component, shopController)
			refreshVisiblePanels(component)
		end)
	end

	for _, rawTabName in ipairs(TAB_ORDER) do
		local tabName = rawTabName :: ShopTab
		local tabControl = component.Tabs[tabName]
		if tabControl and tabControl.Button then
			applyHoverTween(trove, tabControl.Frame, 0.03, 0.12)
			trove:Connect(tabControl.Button.Activated, function()
				shopController:Open(tabName)
			end)
		end
	end

	trove:Add(shopController:ObserveSelectedTab(function(tabName: ShopTab)
		setSelectedTab(component, shopController, tabName)
	end))

	trove:Add(shopController:ObserveOwnedCases(function(_ownedCases: { [string]: number })
		renderCaseDetail(component, shopController)
	end))

	setSelectedTab(component, shopController, shopController:GetSelectedTab())

	return component
end

return Shop
