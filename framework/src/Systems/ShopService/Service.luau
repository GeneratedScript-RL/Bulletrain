--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkServer = require(root) :: any

local CoinProducts = require(root.Shared.Shop.CoinProducts)
local Packs = require(root.Shared.Shop.Packs)
local SkinCases = require(root.Shared.Shop.SkinCases)

type CoinOffer = CoinProducts.CoinOffer
type PackOffer = Packs.PackOffer
type ReceiptInfo = {
	PlayerId: number,
	ProductId: number,
}
type SkinCaseDefinition = SkinCases.SkinCaseDefinition

local dataService: any

local ShopService = framework.CreateService({
	Name = "ShopService",
	Dependencies = { "DataService" },
	Client = {},
})

ShopService._productHandlers = {} :: { [number]: (Player) -> boolean }

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

function ShopService:_grantPackRewards(player: Player, packOffer: PackOffer)
	if packOffer.Rewards.Credits > 0 then
		dataService:AddCredits(player, packOffer.Rewards.Credits)
	end

	for _, caseGrant in ipairs(packOffer.Rewards.Cases) do
		dataService:GrantCase(player, caseGrant.CaseId, caseGrant.Amount)
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

		dataService:GrantCase(player, caseDefinition.Id, 1)
		return true, nil
	end

	if currency == "Robux" then
		return self:_promptCasePurchase(player, caseDefinition)
	end

	return false, "Unsupported purchase currency."
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

function ShopService:Init()
	dataService = framework.GetService("DataService")

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
			dataService:GrantCase(player, caseDefinition.Id, 1)
			return true
		end)
	end

	MarketplaceService.ProcessReceipt = function(receiptInfo: ReceiptInfo)
		return self:ProcessReceipt(receiptInfo)
	end
end

return ShopService
