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
type CaseReward = SkinCases.CaseReward
type OpeningStatus = "Idle" | "Spinning" | "Opened"
type ShopTab = "Packs" | "Cases" | "Coins"
type SkinCaseDefinition = SkinCases.SkinCaseDefinition

type OwnedCases = { [string]: number }
type CaseOpeningPayload = {
	openingId: number?,
	caseId: string,
	caseName: string,
	remainingCases: number,
	winningIndex: number,
	spinItems: { { [string]: any } },
	reward: { [string]: any },
}
type CaseOpeningState = {
	Status: OpeningStatus,
	Payload: CaseOpeningPayload?,
}

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
ShopController._ownedCases = {} :: OwnedCases
ShopController._openingState = {
	Status = "Idle" :: OpeningStatus,
	Payload = nil :: CaseOpeningPayload?,
} :: CaseOpeningState
ShopController._nextOpeningId = 0
ShopController._tabChanged = Signal.new()
ShopController._ownedCasesChanged = Signal.new()
ShopController._openingChanged = Signal.new()
ShopController._shopService = nil :: any
ShopController._playerStateService = nil :: any
ShopController._trove = nil :: Types.Trove?

local function copyOwnedCases(ownedCases: OwnedCases): OwnedCases
	return table.clone(ownedCases)
end

local function copySpinItems(spinItems: { { [string]: any } }): { { [string]: any } }
	local out = table.create(#spinItems)

	for index, item in ipairs(spinItems) do
		out[index] = table.clone(item)
	end

	return out
end

local function copyOpeningPayload(payload: CaseOpeningPayload?): CaseOpeningPayload?
	if not payload then
		return nil
	end

	local copiedPayload = table.clone(payload)
	copiedPayload.spinItems = copySpinItems(payload.spinItems)
	copiedPayload.reward = table.clone(payload.reward)
	return copiedPayload
end

local function copyOpeningState(openingState: CaseOpeningState): CaseOpeningState
	return {
		Status = openingState.Status,
		Payload = copyOpeningPayload(openingState.Payload),
	}
end

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

function ShopController:_setOwnedCases(ownedCases: OwnedCases)
	self._ownedCases = copyOwnedCases(ownedCases)
	self._ownedCasesChanged:Fire(self:GetOwnedCases())
end

function ShopController:_setOpeningState(status: OpeningStatus, payload: CaseOpeningPayload?)
	self._openingState = {
		Status = status,
		Payload = copyOpeningPayload(payload),
	}

	self._openingChanged:Fire(self:GetOpeningState())
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

function ShopController:GetOwnedCases(): OwnedCases
	return copyOwnedCases(self._ownedCases)
end

function ShopController:GetOwnedCaseCount(caseId: string): number
	return self._ownedCases[caseId] or 0
end

function ShopController:ObserveOwnedCases(callback: (ownedCases: OwnedCases) -> ()): Connection
	callback(self:GetOwnedCases())
	return self._ownedCasesChanged:Connect(callback)
end

function ShopController:GetOpeningState(): CaseOpeningState
	return copyOpeningState(self._openingState)
end

function ShopController:ObserveOpeningState(callback: (openingState: CaseOpeningState) -> ()): Connection
	callback(self:GetOpeningState())
	return self._openingChanged:Connect(callback)
end

function ShopController:OpenCase(caseId: string): (boolean, string?)
	if self._openingState.Status ~= "Idle" then
		return false, "Finish the current case opening first."
	end

	local success, payload, errorMessage = self._shopService:OpenCase(caseId)
	if not success then
		return false, errorMessage
	end

	if type(payload) ~= "table" then
		return false, "Case opening payload missing."
	end

	self._nextOpeningId += 1
	local resolvedPayload = payload :: CaseOpeningPayload
	resolvedPayload.openingId = self._nextOpeningId
	self:_setOpeningState("Spinning", resolvedPayload)

	return true, nil
end

function ShopController:RevealCurrentOpening(openingId: number?)
	local payload = self._openingState.Payload
	if self._openingState.Status ~= "Spinning" or not payload then
		return
	end

	if openingId ~= nil and payload.openingId ~= openingId then
		return
	end

	self:_setOpeningState("Opened", payload)
end

function ShopController:ClaimCurrentOpening(openingId: number?)
	local payload = self._openingState.Payload
	if self._openingState.Status == "Idle" then
		return
	end

	if openingId ~= nil and payload and payload.openingId ~= openingId then
		return
	end

	self:_setOpeningState("Idle", nil)
end

function ShopController:Init()
	self._shopService = framework.GetService("ShopService")
	self._playerStateService = framework.GetService("PlayerStateService")
	self._selectedTab = self:GetDefaultTab()
end

function ShopController:Start()
	local trove = Trove.new()
	self._trove = trove

	trove:Add(self._shopService.OwnedCases:Observe(function(ownedCases: OwnedCases)
		self:_setOwnedCases(ownedCases)
	end))

	trove:Add(self._playerStateService.CurrentState:Observe(function(playerState: string)
		if playerState == "Combat" then
			self:Close()
		end
	end))
end

return ShopController
