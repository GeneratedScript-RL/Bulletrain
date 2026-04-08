--!strict

local root = script.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local CoinProducts = require(root.Shared.Shop.CoinProducts)
local Packs = require(root.Shared.Shop.Packs)
local SkinCases = require(root.Shared.Shop.SkinCases)
local Signal = Dependencies.GetSignal()
local Trove = Dependencies.GetTrove()

type Connection = Types.Connection
type CoinOffer = CoinProducts.CoinOffer
type PackOffer = Packs.PackOffer
type ShopTab = "Packs" | "Cases" | "Coins"
type SkinCaseDefinition = SkinCases.SkinCaseDefinition

local VALID_TABS = {
	Packs = true,
	Cases = true,
	Coins = true,
}

local ShopController = framework.CreateController({
	Name = "ShopController",
})

ShopController._open = false
ShopController._frame = nil :: GuiObject?
ShopController._selectedTab = "Packs" :: ShopTab
ShopController._tabChanged = Signal.new()
ShopController._shopService = nil :: any
ShopController._playerStateService = nil :: any
ShopController._trove = nil :: Types.Trove?

function ShopController:_applyFrameOpenState()
	local frame = self._frame
	if not frame then
		return
	end

	frame:SetAttribute("OpenOverride", self._open)
end

function ShopController:_setSelectedTab(tabName: string?)
	local resolvedTab = tabName
	if type(resolvedTab) ~= "string" or VALID_TABS[resolvedTab] ~= true then
		resolvedTab = self:GetDefaultTab()
	end

	local typedTab = resolvedTab :: ShopTab
	if self._selectedTab == typedTab then
		return
	end

	self._selectedTab = typedTab
	self._tabChanged:Fire(typedTab)
end

function ShopController:RegisterFrame(frame: GuiObject)
	self._frame = frame
	self:_applyFrameOpenState()
end

function ShopController:GetDefaultTab(): ShopTab
	if #Packs.GetAll() > 0 then
		return "Packs"
	end

	if #SkinCases.GetAll() > 0 then
		return "Cases"
	end

	return "Coins"
end

function ShopController:Open(tabName: string?)
	self._open = true
	if tabName ~= nil then
		self:_setSelectedTab(tabName)
	elseif VALID_TABS[self._selectedTab] ~= true then
		self:_setSelectedTab(self:GetDefaultTab())
	end
	self:_applyFrameOpenState()
end

function ShopController:Close()
	self._open = false
	self:_applyFrameOpenState()
end

function ShopController:Toggle(tabName: string?)
	if self._open then
		if tabName and tabName ~= self._selectedTab then
			self:Open(tabName)
			return
		end

		self:Close()
	else
		self:Open(tabName)
	end
end

function ShopController:GetSelectedTab(): ShopTab
	return self._selectedTab
end

function ShopController:ObserveSelectedTab(callback: (tabName: ShopTab) -> ()): Connection
	callback(self:GetSelectedTab())
	return self._tabChanged:Connect(callback)
end

function ShopController:GetCoinOffers(): { CoinOffer }
	return CoinProducts.GetAll()
end

function ShopController:GetCaseDefinitions(): { SkinCaseDefinition }
	return SkinCases.GetAll()
end

function ShopController:GetPackOffers(): { PackOffer }
	return Packs.GetAll()
end

function ShopController:PurchaseCoinOffer(offerId: string): (boolean, string?)
	return self._shopService:PurchaseCoinOffer(offerId)
end

function ShopController:PurchaseCase(caseId: string, currency: string?): (boolean, string?)
	return self._shopService:PurchaseCase(caseId, currency)
end

function ShopController:PurchasePack(packId: string): (boolean, string?)
	return self._shopService:PurchasePack(packId)
end

function ShopController:Init()
	self._shopService = framework.GetService("ShopService")
	self._playerStateService = framework.GetService("PlayerStateService")
	self._selectedTab = self:GetDefaultTab()
end

function ShopController:Start()
	local trove = Trove.new()
	self._trove = trove

	trove:Add(self._playerStateService.CurrentState:Observe(function(playerState: string)
		if playerState == "Combat" then
			self:Close()
		end
	end))
end

return ShopController
