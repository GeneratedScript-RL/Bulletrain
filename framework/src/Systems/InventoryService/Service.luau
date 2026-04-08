--!strict

local Players = game:GetService("Players")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkServer = require(root) :: any

local InventorySkins = require(root.Shared.Inventory.Skins)

type SkinCategory = "Shotgun" | "Knife"

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

local dataService: any

local InventoryService = framework.CreateService({
	Name = "InventoryService",
	Dependencies = { "DataService" },
	Client = {
		Inventory = framework.CreateProperty(DEFAULT_INVENTORY_STATE),
	},
})

local function copyStringArray(values: { string }): { string }
	local out = table.create(#values)

	for index, value in ipairs(values) do
		out[index] = value
	end

	return out
end

local function normalizeCategory(rawCategory: any): SkinCategory?
	if rawCategory == "Shotgun" or rawCategory == "Gun" or rawCategory == "Guns" then
		return "Shotgun"
	end

	if rawCategory == "Knife" or rawCategory == "Knifes" then
		return "Knife"
	end

	return nil
end

local function hasSkin(ownedSkins: { string }, skinName: string): boolean
	return table.find(ownedSkins, skinName) ~= nil
end

local function snapshotInventory(profile: any): InventoryState
	return {
		ShotgunSkins = copyStringArray(profile.ShotgunSkins),
		KnifeSkins = copyStringArray(profile.KnifeSkins),
		CurrentlyEquippedShotgunSkin = profile.CurrentlyEquippedShotgunSkin,
		CurrentlyEquippedKnifeSkin = profile.CurrentlyEquippedKnifeSkin,
	}
end

local function getOwnedSkins(profile: any, category: SkinCategory): { string }
	if category == "Knife" then
		return profile.KnifeSkins
	end

	return profile.ShotgunSkins
end

function InventoryService:_syncPlayer(player: Player)
	if player.Parent ~= Players then
		return
	end

	local profile = dataService:WaitForProfile(player)
	if player.Parent ~= Players then
		return
	end

	self.Client.Inventory:SetFor(player, snapshotInventory(profile))
end

function InventoryService:EquipSkin(player: Player, rawCategory: string, skinName: string): (boolean, InventoryState, string?)
	local profile = dataService:WaitForProfile(player)
	local inventoryState = snapshotInventory(profile)
	local category = normalizeCategory(rawCategory)

	if category == nil or type(skinName) ~= "string" then
		return false, inventoryState, "Invalid inventory equip request."
	end

	if not InventorySkins.IsValid(category, skinName) then
		return false, inventoryState, "Unknown skin."
	end

	local ownedSkins = getOwnedSkins(profile, category)
	if not hasSkin(ownedSkins, skinName) then
		return false, inventoryState, "Skin is not owned."
	end

	if category == "Knife" then
		dataService:SetEquippedKnifeSkin(player, skinName)
	else
		dataService:SetEquippedShotgunSkin(player, skinName)
	end

	local updatedInventory = snapshotInventory(dataService:GetProfile(player))
	self.Client.Inventory:SetFor(player, updatedInventory)

	return true, updatedInventory, nil
end

function InventoryService:GrantSkin(player: Player, rawCategory: string, skinName: string): boolean
	local category = normalizeCategory(rawCategory)
	if category == nil or not InventorySkins.IsValid(category, skinName) then
		return false
	end

	local profile = dataService:WaitForProfile(player)
	local ownedSkins = getOwnedSkins(profile, category)
	if hasSkin(ownedSkins, skinName) then
		return false
	end

	table.insert(ownedSkins, skinName)
	dataService:MarkDirty(player)
	self:_syncPlayer(player)

	return true
end

function InventoryService.Client:EquipSkin(player: Player, category: string, skinName: string)
	return self.Server:EquipSkin(player, category, skinName)
end

function InventoryService:Init()
	dataService = framework.GetService("DataService")

	framework.OnPlayerAdded(function(player: Player)
		self:_syncPlayer(player)
	end)
end

return InventoryService
