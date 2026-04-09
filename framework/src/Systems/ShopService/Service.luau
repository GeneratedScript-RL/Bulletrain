--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkServer = require(root) :: any

local InventorySkins = require(root.Shared.Inventory.Skins)
local CoinProducts = require(root.Shared.Shop.CoinProducts)
local Packs = require(root.Shared.Shop.Packs)
local SkinCases = require(root.Shared.Shop.SkinCases)

type CaseReward = SkinCases.CaseReward
type CaseRarity = SkinCases.CaseRarity
type CoinOffer = CoinProducts.CoinOffer
type PackOffer = Packs.PackOffer
type ReceiptInfo = {
	PlayerId: number,
	ProductId: number,
}
type SkinCaseDefinition = SkinCases.SkinCaseDefinition
type SkinCategory = InventorySkins.SkinCategory

local dataService: any
local inventoryService: any

local SPIN_ITEM_COUNT = 45
local SPIN_RESULT_MIN_INDEX = 34
local SPIN_RESULT_MAX_INDEX = 40

local ShopService = framework.CreateService({
	Name = "ShopService",
	Dependencies = { "DataService", "InventoryService" },
	Client = {
		OwnedCases = framework.CreateProperty({} :: { [string]: number }),
	},
})

ShopService._productHandlers = {} :: { [number]: (Player) -> boolean }
ShopService._random = Random.new()

local function copyOwnedCases(ownedCases: { [string]: number }): { [string]: number }
	local out = {} :: { [string]: number }

	for caseId, amount in ownedCases do
		out[caseId] = amount
	end

	return out
end

local function isRewardOwned(profile: any, reward: CaseReward): boolean
	local ownedSkins = if reward.Category == "Knife" then profile.KnifeSkins else profile.ShotgunSkins
	return table.find(ownedSkins, reward.SkinName) ~= nil
end

local function serializeReward(reward: CaseReward): { [string]: any }
	return {
		category = reward.Category,
		skinName = reward.SkinName,
		name = reward.Name,
		icon = reward.Icon,
		rarity = reward.Rarity,
		chance = reward.Chance,
		duplicateCredits = reward.DuplicateCredits,
	}
end

local function promptProductPurchase(player: Player, productId: number): (boolean, string?)
	if productId <= 0 then
		return false, "Set a valid DevProductId in the shop database first."
	end

	local ok, errorMessage = pcall(function()
		MarketplaceService:PromptProductPurchase(player, productId)
	end)

	if not ok then
		return false, tostring(errorMessage)
	end

	return true, nil
end

function ShopService:_registerProductHandler(productId: number, handler: (Player) -> boolean)
	if productId > 0 then
		self._productHandlers[productId] = handler
	end
end

function ShopService:_snapshotOwnedCases(player: Player): { [string]: number }
	local profile = dataService:WaitForProfile(player)
	return copyOwnedCases(profile.Cases)
end

function ShopService:_syncOwnedCases(player: Player)
	if player.Parent ~= Players then
		return
	end

	self.Client.OwnedCases:SetFor(player, self:_snapshotOwnedCases(player))
end

function ShopService:_grantCaseOwnership(player: Player, caseId: string, amount: number?): number
	local total = dataService:GrantCase(player, caseId, amount)
	self:_syncOwnedCases(player)
	return total
end

function ShopService:_consumeCaseOwnership(player: Player, caseId: string, amount: number?): (boolean, number)
	local success, remainingAmount = dataService:ConsumeCase(player, caseId, amount)
	if success then
		self:_syncOwnedCases(player)
	end

	return success, remainingAmount
end

function ShopService:_grantPackRewards(player: Player, packOffer: PackOffer)
	if packOffer.Rewards.Credits > 0 then
		dataService:AddCredits(player, packOffer.Rewards.Credits)
	end

	for _, caseGrant in ipairs(packOffer.Rewards.Cases) do
		self:_grantCaseOwnership(player, caseGrant.CaseId, caseGrant.Amount)
	end
end

function ShopService:_promptCoinOfferPurchase(player: Player, offer: CoinOffer): (boolean, string?)
	return promptProductPurchase(player, offer.DevProductId)
end

function ShopService:_promptPackPurchase(player: Player, packOffer: PackOffer): (boolean, string?)
	return promptProductPurchase(player, packOffer.DevProductId)
end

function ShopService:_promptCasePurchase(player: Player, caseDefinition: SkinCaseDefinition): (boolean, string?)
	return promptProductPurchase(player, caseDefinition.DevProductId)
end

function ShopService:PurchaseCoinOffer(player: Player, offerId: string): (boolean, string?)
	local offer = CoinProducts.GetById(offerId)
	if not offer then
		return false, "Unknown coin offer."
	end

	return self:_promptCoinOfferPurchase(player, offer)
end

function ShopService:PurchasePack(player: Player, packId: string): (boolean, string?)
	local packOffer = Packs.GetById(packId)
	if not packOffer then
		return false, "Unknown shop pack."
	end

	return self:_promptPackPurchase(player, packOffer)
end

function ShopService:PurchaseCase(player: Player, caseId: string, requestedCurrency: string?): (boolean, string?)
	local caseDefinition = SkinCases.GetById(caseId)
	if not caseDefinition then
		return false, "Unknown skin case."
	end

	local currency = requestedCurrency or caseDefinition.PrimaryCurrency
	if currency == "Coins" then
		local coinPrice = caseDefinition.CoinPrice
		if coinPrice == nil then
			return false, "This case is not sold for coins."
		end

		if not dataService:SpendCredits(player, coinPrice) then
			return false, "Not enough coins."
		end

		self:_grantCaseOwnership(player, caseDefinition.Id, 1)
		return true, nil
	end

	if currency == "Robux" then
		return self:_promptCasePurchase(player, caseDefinition)
	end

	return false, "Unsupported purchase currency."
end

function ShopService:_rollCaseReward(caseDefinition: SkinCaseDefinition): CaseReward
	local totalChance = 0
	for _, reward in ipairs(caseDefinition.Rewards) do
		totalChance += reward.Chance
	end

	local roll = self._random:NextNumber(0, totalChance)
	local runningChance = 0
	for _, reward in ipairs(caseDefinition.Rewards) do
		runningChance += reward.Chance
		if roll <= runningChance then
			return reward
		end
	end

	return caseDefinition.Rewards[#caseDefinition.Rewards]
end

function ShopService:_buildSpinSequence(caseDefinition: SkinCaseDefinition, winningReward: CaseReward): ({ any }, number)
	local spinItems = table.create(SPIN_ITEM_COUNT)
	local winningIndex = self._random:NextInteger(SPIN_RESULT_MIN_INDEX, SPIN_RESULT_MAX_INDEX)

	for index = 1, SPIN_ITEM_COUNT do
		local reward = if index == winningIndex then winningReward else self:_rollCaseReward(caseDefinition)
		spinItems[index] = serializeReward(reward)
	end

	return spinItems, winningIndex
end

function ShopService:OpenCase(player: Player, caseId: string): (boolean, any, string?)
	local caseDefinition = SkinCases.GetById(caseId)
	if not caseDefinition then
		return false, nil, "Unknown skin case."
	end

	local consumed, remainingAmount = self:_consumeCaseOwnership(player, caseDefinition.Id, 1)
	if not consumed then
		return false, nil, "You do not own that case."
	end

	local reward = self:_rollCaseReward(caseDefinition)
	local profile = dataService:WaitForProfile(player)
	local alreadyOwned = isRewardOwned(profile, reward)
	local granted = false
	local duplicateCreditsAwarded = 0

	if not alreadyOwned then
		granted = inventoryService:GrantSkin(player, reward.Category, reward.SkinName)
	elseif reward.DuplicateCredits > 0 then
		dataService:AddCredits(player, reward.DuplicateCredits)
		duplicateCreditsAwarded = reward.DuplicateCredits
	end

	local spinItems, winningIndex = self:_buildSpinSequence(caseDefinition, reward)

	return true, {
		caseId = caseDefinition.Id,
		caseName = caseDefinition.Name,
		remainingCases = remainingAmount,
		winningIndex = winningIndex,
		spinItems = spinItems,
		reward = {
			category = reward.Category,
			skinName = reward.SkinName,
			name = reward.Name,
			icon = reward.Icon,
			rarity = reward.Rarity,
			chance = reward.Chance,
			duplicateCredits = reward.DuplicateCredits,
			duplicateCreditsAwarded = duplicateCreditsAwarded,
			granted = granted,
			isDuplicate = alreadyOwned,
		},
	}, nil
end

function ShopService:ProcessReceipt(receiptInfo: ReceiptInfo): Enum.ProductPurchaseDecision
	local handler = self._productHandlers[receiptInfo.ProductId]
	if not handler then
		warn(("[ShopService] No receipt handler registered for product %d"):format(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not dataService:IsProfileLoaded(player) then
		dataService:WaitForProfile(player, 10)
	end

	local ok, granted = pcall(handler, player)
	if not ok then
		warn(("[ShopService] Receipt grant failed for product %d: %s"):format(receiptInfo.ProductId, tostring(granted)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if granted ~= true then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService.Client:PurchaseCoinOffer(player: Player, offerId: string)
	return self.Server:PurchaseCoinOffer(player, offerId)
end

function ShopService.Client:PurchasePack(player: Player, packId: string)
	return self.Server:PurchasePack(player, packId)
end

function ShopService.Client:PurchaseCase(player: Player, caseId: string, requestedCurrency: string?)
	return self.Server:PurchaseCase(player, caseId, requestedCurrency)
end

function ShopService.Client:OpenCase(player: Player, caseId: string)
	return self.Server:OpenCase(player, caseId)
end

function ShopService:Init()
	dataService = framework.GetService("DataService")
	inventoryService = framework.GetService("InventoryService")

	for _, offer in ipairs(CoinProducts.GetAll()) do
		self:_registerProductHandler(offer.DevProductId, function(player: Player): boolean
			dataService:AddCredits(player, offer.Coins)
			return true
		end)
	end

	for _, packOffer in ipairs(Packs.GetAll()) do
		self:_registerProductHandler(packOffer.DevProductId, function(player: Player): boolean
			self:_grantPackRewards(player, packOffer)
			return true
		end)
	end

	for _, caseDefinition in ipairs(SkinCases.GetAll()) do
		self:_registerProductHandler(caseDefinition.DevProductId, function(player: Player): boolean
			self:_grantCaseOwnership(player, caseDefinition.Id, 1)
			return true
		end)
	end

	framework.OnPlayerAdded(function(player: Player)
		self:_syncOwnedCases(player)
	end)

	framework.OnPlayerRemoving(function(player: Player)
		self.Client.OwnedCases:ClearFor(player)
	end)

	MarketplaceService.ProcessReceipt = function(receiptInfo: ReceiptInfo)
		return self:ProcessReceipt(receiptInfo)
	end
end

return ShopService
