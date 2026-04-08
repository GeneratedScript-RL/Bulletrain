--!strict

local root = script.Parent.Parent.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local InventorySkins = require(root.Shared.Inventory.Skins)
local ObjectComponents = require(script.Parent.Parent.ObjectComponents)
local Trove = Dependencies.GetTrove()

type SkinCategory = "Shotgun" | "Knife"

type InventoryState = {
	ShotgunSkins: { string },
	KnifeSkins: { string },
	CurrentlyEquippedShotgunSkin: string,
	CurrentlyEquippedKnifeSkin: string,
}

type TabControl = {
	Frame: GuiObject,
	Button: GuiButton?,
	Label: TextLabel?,
	Category: SkinCategory,
}

type InventoryComponent = {
	Frame: GuiObject,
	ExitButton: GuiButton?,
	ScrollingFrame: ScrollingFrame?,
	GridLayout: UIGridLayout?,
	Template: GuiObject?,
	Tabs: { [SkinCategory]: TabControl },
	SelectedCategory: SkinCategory,
	_trove: Types.Trove,
	_itemTrove: Types.Trove?,
	Destroy: (self: InventoryComponent) -> (),
}

local Inventory = {}

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

local function findFirstLabel(container: Instance?): TextLabel?
	if not container then
		return nil
	end

	local label = container:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		return label
	end

	return nil
end

local function updateScrollingCanvas(scrollingFrame: ScrollingFrame, layout: UIGridLayout)
	scrollingFrame.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 12)
end

local function getOwnedSkins(inventoryState: InventoryState, category: SkinCategory): { string }
	if category == "Knife" then
		return inventoryState.KnifeSkins
	end

	return inventoryState.ShotgunSkins
end

local function getEquippedSkin(inventoryState: InventoryState, category: SkinCategory): string
	if category == "Knife" then
		return inventoryState.CurrentlyEquippedKnifeSkin
	end

	return inventoryState.CurrentlyEquippedShotgunSkin
end

local function ensureItemButton(itemHolder: GuiObject): GuiButton
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

local function prepareTemplate(scrollingFrame: ScrollingFrame): GuiObject?
	local template: GuiObject? = nil

	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:IsA("GuiObject") and child.Name:match("^ItemHolder") then
			if template == nil then
				template = child
				template.Name = "InventoryItemTemplate"
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

local function applyTabState(tabControl: TabControl, selected: boolean)
	tabControl.Frame.BackgroundTransparency = if selected then 0 else 0.2
	tabControl.Frame:SetAttribute("Selected", selected)

	local label = tabControl.Label
	if label then
		label.TextTransparency = if selected then 0 else 0.2
	end
end

local function refreshTabs(component: InventoryComponent)
	for category, tabControl in component.Tabs do
		applyTabState(tabControl, category == component.SelectedCategory)
	end
end

local function clearRenderedItems(component: InventoryComponent)
	local itemTrove = component._itemTrove
	if itemTrove then
		itemTrove:Clean()
		component._itemTrove = nil
	end
end

local function applyItemVisuals(itemHolder: GuiObject, itemName: TextLabel?, equipped: boolean, skinName: string)
	itemHolder.Visible = true
	itemHolder.BackgroundTransparency = if equipped then 0 else 0.15
	itemHolder:SetAttribute("Equipped", equipped)

	if itemName then
		itemName.Text = if equipped then `{skinName} [Equipped]` else skinName
	end

	local innerStroke = itemHolder:FindFirstChild("Inner")
	if innerStroke and innerStroke:IsA("UIStroke") then
		innerStroke.Transparency = if equipped then 0 else 0.3
	end

	local outerStroke = itemHolder:FindFirstChild("Outer")
	if outerStroke and outerStroke:IsA("UIStroke") then
		outerStroke.Transparency = if equipped then 0 else 0.3
	end
end

local function buildItemList(component: InventoryComponent, inventoryController: any, inventoryState: InventoryState)
	local scrollingFrame = component.ScrollingFrame
	local template = component.Template
	if not scrollingFrame or not template then
		return
	end

	clearRenderedItems(component)

	local itemTrove = Trove.new()
	component._itemTrove = itemTrove

	local ownedSkins = getOwnedSkins(inventoryState, component.SelectedCategory)
	local equippedSkin = getEquippedSkin(inventoryState, component.SelectedCategory)
	local ownedSkinLookup: { [string]: boolean } = {}

	for _, skinName in ipairs(ownedSkins) do
		ownedSkinLookup[skinName] = true
	end

	local orderedDefinitions = InventorySkins.GetDefinitions(component.SelectedCategory)
	local renderedDefinitions = {}
	local renderedLookup: { [string]: boolean } = {}

	for _, definition in ipairs(orderedDefinitions) do
		if ownedSkinLookup[definition.Name] then
			table.insert(renderedDefinitions, definition)
			renderedLookup[definition.Name] = true
		end
	end

	for _, skinName in ipairs(ownedSkins) do
		if not renderedLookup[skinName] then
			table.insert(renderedDefinitions, {
				Name = skinName,
				Icon = "",
			})
		end
	end

	for index, definition in ipairs(renderedDefinitions) do
		local itemHolder = template:Clone()
		itemHolder.Name = `InventoryItem_{index}`
		itemHolder.LayoutOrder = index
		itemHolder.Parent = scrollingFrame
		itemTrove:Add(itemHolder)

		local itemName = itemHolder:FindFirstChild("ItemName")
		if itemName and not itemName:IsA("TextLabel") then
			itemName = nil
		end

		local iconLabel = itemHolder:FindFirstChild("Item")
		if iconLabel and iconLabel:IsA("ImageLabel") then
			iconLabel.Image = definition.Icon
		end

		local button = ensureItemButton(itemHolder)
		local isEquipped = definition.Name == equippedSkin

		applyItemVisuals(itemHolder, itemName :: TextLabel?, isEquipped, definition.Name)

		itemTrove:Connect(button.Activated, function()
			inventoryController:EquipSkin(component.SelectedCategory, definition.Name)
		end)
	end
end

local function detectCategoryFromTab(tabFrame: GuiObject): SkinCategory?
	local label = findFirstLabel(tabFrame)
	if not label then
		return nil
	end

	local lowerLabel = string.lower(label.Text)
	if string.find(lowerLabel, "gun", 1, true) then
		return "Shotgun"
	end

	if string.find(lowerLabel, "knife", 1, true) then
		return "Knife"
	end

	return nil
end

function Inventory.Destroy(self: InventoryComponent)
	clearRenderedItems(self)
	self._trove:Clean()
end

function Inventory.init(inventoryFrame: GuiObject): InventoryComponent
	local inventoryController = framework.GetController("InventoryController")
	local trove = Trove.new()

	local component: InventoryComponent = {
		Frame = inventoryFrame,
		ExitButton = nil,
		ScrollingFrame = nil,
		GridLayout = nil,
		Template = nil,
		Tabs = {},
		SelectedCategory = "Shotgun",
		_trove = trove,
		_itemTrove = nil,
		Destroy = Inventory.Destroy,
	}

	inventoryFrame:SetAttribute("OpenOverride", false)
	inventoryController:RegisterFrame(inventoryFrame)

	local exitFrame = inventoryFrame:FindFirstChild("ExitButton")
	local mainFrame = inventoryFrame:FindFirstChild("Main")
	local itemList = if mainFrame then mainFrame:FindFirstChild("ItemList") else nil
	local scrollingFrame = if itemList then itemList:FindFirstChild("ScrollingFrame") else nil
	local tabsFrame = inventoryFrame:FindFirstChild("Tabs")

	component.ExitButton = findButton(exitFrame, "ButtonHitbox")

	if scrollingFrame and scrollingFrame:IsA("ScrollingFrame") then
		component.ScrollingFrame = scrollingFrame
		component.GridLayout = scrollingFrame:FindFirstChildWhichIsA("UIGridLayout")
		component.Template = prepareTemplate(scrollingFrame)
		if component.Template then
			trove:Add(component.Template)
		end
	else
		warn("[UIController] Inventory.Main.ItemList.ScrollingFrame not found")
	end

	if tabsFrame and tabsFrame:IsA("GuiObject") then
		for _, child in ipairs(tabsFrame:GetChildren()) do
			if not child:IsA("GuiObject") or not child.Name:match("^Tab") then
				continue
			end

			local category = detectCategoryFromTab(child)
			if category == nil then
				continue
			end

			local tabControl: TabControl = {
				Frame = child,
				Button = findButton(child, "ButtonHitbox"),
				Label = findFirstLabel(child),
				Category = category,
			}

			component.Tabs[category] = tabControl
		end
	end

	if component.ExitButton then
		trove:Add(ObjectComponents.ButtonHoverTween.apply(
			component.ExitButton,
			component.ExitButton.Size + UDim2.fromScale(0.06, 0.06),
			component.ExitButton.Size,
			0.12
		))

		trove:Connect(component.ExitButton.Activated, function()
			inventoryController:Close()
		end)
	end

	for category, tabControl in component.Tabs do
		local button = tabControl.Button
		if not button then
			continue
		end

		trove:Add(ObjectComponents.ButtonHoverTween.apply(
			button,
			button.Size + UDim2.fromScale(0.04, 0.04),
			button.Size,
			0.12
		))

		trove:Connect(button.Activated, function()
			component.SelectedCategory = category
			refreshTabs(component)
			buildItemList(component, inventoryController, inventoryController:GetInventory())
		end)
	end

	local gridLayout = component.GridLayout
	local activeScrollingFrame = component.ScrollingFrame
	if gridLayout and activeScrollingFrame then
		updateScrollingCanvas(activeScrollingFrame, gridLayout)
		trove:Connect(gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
			updateScrollingCanvas(activeScrollingFrame, gridLayout)
		end)
	end

	trove:Add(inventoryController:ObserveInventory(function(inventoryState: InventoryState)
		refreshTabs(component)
		buildItemList(component, inventoryController, inventoryState)
	end))

	refreshTabs(component)

	return component
end

return Inventory
