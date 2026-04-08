--!strict

local root = script.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local Signal = Dependencies.GetSignal()
local Trove = Dependencies.GetTrove()

type InventoryState = {
	ShotgunSkins: { string },
	KnifeSkins: { string },
	CurrentlyEquippedShotgunSkin: string,
	CurrentlyEquippedKnifeSkin: string,
}

local DEFAULT_INVENTORY_STATE: InventoryState = {
	ShotgunSkins = { "Default" },
	KnifeSkins = { "Default" },
	CurrentlyEquippedShotgunSkin = "Default",
	CurrentlyEquippedKnifeSkin = "Default",
}

local InventoryController = framework.CreateController({
	Name = "InventoryController",
})

InventoryController._inventory = DEFAULT_INVENTORY_STATE :: InventoryState
InventoryController._open = false
InventoryController._frame = nil :: GuiObject?
InventoryController._changed = Signal.new()
InventoryController._inventoryService = nil :: any
InventoryController._playerStateService = nil :: any
InventoryController._trove = nil :: Types.Trove?

local function copyStringArray(values: { string }): { string }
	local out = table.create(#values)

	for index, value in ipairs(values) do
		out[index] = value
	end

	return out
end

local function copyInventoryState(inventory: InventoryState): InventoryState
	return {
		ShotgunSkins = copyStringArray(inventory.ShotgunSkins),
		KnifeSkins = copyStringArray(inventory.KnifeSkins),
		CurrentlyEquippedShotgunSkin = inventory.CurrentlyEquippedShotgunSkin,
		CurrentlyEquippedKnifeSkin = inventory.CurrentlyEquippedKnifeSkin,
	}
end

function InventoryController:_setInventory(inventory: InventoryState)
	self._inventory = copyInventoryState(inventory)
	self._changed:Fire(self:GetInventory())
end

function InventoryController:_applyFrameOpenState()
	local frame = self._frame
	if not frame then
		return
	end

	frame:SetAttribute("OpenOverride", self._open)
end

function InventoryController:RegisterFrame(frame: GuiObject)
	self._frame = frame
	self:_applyFrameOpenState()
end

function InventoryController:Open()
	self._open = true
	self:_applyFrameOpenState()
end

function InventoryController:Close()
	self._open = false
	self:_applyFrameOpenState()
end

function InventoryController:Toggle()
	if self._open then
		self:Close()
	else
		self:Open()
	end
end

function InventoryController:GetInventory(): InventoryState
	return copyInventoryState(self._inventory)
end

function InventoryController:ObserveInventory(callback: (inventory: InventoryState) -> ()): Types.Connection
	callback(self:GetInventory())
	return self._changed:Connect(callback)
end

function InventoryController:EquipSkin(category: string, skinName: string): boolean
	local success, updatedInventory = self._inventoryService:EquipSkin(category, skinName)
	if success and type(updatedInventory) == "table" then
		self:_setInventory(updatedInventory)
		return true
	end

	return false
end

function InventoryController:Init()
	self._inventoryService = framework.GetService("InventoryService")
	self._playerStateService = framework.GetService("PlayerStateService")
end

function InventoryController:Start()
	local trove = Trove.new()
	self._trove = trove

	trove:Add(self._inventoryService.Inventory:Observe(function(inventory: InventoryState)
		self:_setInventory(inventory)
	end))

	trove:Add(self._playerStateService.CurrentState:Observe(function(playerState: string)
		if playerState == "Combat" then
			self:Close()
		end
	end))
end

return InventoryController
