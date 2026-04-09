--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkServer = require(root) :: any

local DefaultProfile = require(root.Shared.Database.DefaultProfile)
local DailyTaskTypes = require(root.Shared.DailyTasks.Types)
local InventorySkins = require(root.Shared.Inventory.Skins)
local Leveling = require(root.Shared.Database.Leveling)
local SettingsDefaults = require(root.Shared.Settings.Defaults)
local SettingsTypes = require(root.Shared.Settings.Types)
local ProfileTypes = require(root.Shared.Database.TypeDef.Profile)

type DailyTaskProfile = DailyTaskTypes.DailyTaskProfile
type Profile = ProfileTypes.Profile
type OwnedCases = ProfileTypes.OwnedCases
type SettingsProfile = SettingsTypes.SettingsProfile
type SkinCategory = "Shotgun" | "Knife"

local DATASTORE_NAME = "Bulletrain_PlayerData_v1"
local AUTOSAVE_INTERVAL = 60

local ATTRIBUTE = {
	Credits = "Credits",
	XP = "XP",
	Level = "Level",
	CareerKills = "CareerKills",
	CareerDeaths = "CareerDeaths",
	CareerAssists = "CareerAssists",
	EquippedShotgunSkin = "EquippedShotgunSkin",
	EquippedKnifeSkin = "EquippedKnifeSkin",
}

local DataService = framework.CreateService({
	Name = "DataService",
	Client = {
		LevelUp = framework.CreateSignal(),
	},
})

DataService._store = nil :: GlobalDataStore?
DataService._profiles = {} :: { [Player]: Profile }
DataService._dirty = {} :: { [Player]: boolean }
DataService._loading = {} :: { [Player]: boolean }

local function keyForUserId(userId: number): string
	return `Player_{userId}`
end

local function clampNumber(value: any, minimum: number, maximum: number): number
	if type(value) ~= "number" or value ~= value then
		return minimum
	end

	return math.clamp(value, minimum, maximum)
end

local function sanitizeDailyTasks(raw: any): DailyTaskProfile
	local dailyTasks: DailyTaskProfile = {
		DayKey = "",
		Tasks = {},
	}

	if type(raw) ~= "table" then
		return dailyTasks
	end

	if type(raw.DayKey) == "string" then
		dailyTasks.DayKey = raw.DayKey
	end

	if type(raw.Tasks) == "table" then
		for taskId, taskState in raw.Tasks do
			if type(taskId) == "string" and type(taskState) == "table" then
				dailyTasks.Tasks[taskId] = {
					Progress = clampNumber(taskState.Progress, 0, 1e12),
					RewardClaimed = taskState.RewardClaimed == true,
				}
			end
		end
	end

	return dailyTasks
end

local function sanitizeSettings(raw: any): SettingsProfile
	return SettingsDefaults.Sanitize(raw)
end

local function sanitizeOwnedCases(raw: any): OwnedCases
	local ownedCases: OwnedCases = {}

	if type(raw) ~= "table" then
		return ownedCases
	end

	for caseId, amount in raw do
		if type(caseId) == "string" then
			local sanitizedAmount = math.floor(clampNumber(amount, 0, 1e6))
			if sanitizedAmount > 0 then
				ownedCases[caseId] = sanitizedAmount
			end
		end
	end

	return ownedCases
end

local function sanitizeOwnedSkins(raw: any, category: SkinCategory): { string }
	local ownedSkins = {}
	local seen = {}
	local defaultSkin = InventorySkins.GetDefaultSkin(category)

	if type(raw) == "table" then
		for _, skinName in ipairs(raw :: { any }) do
			if type(skinName) == "string" and not seen[skinName] and InventorySkins.IsValid(category, skinName) then
				seen[skinName] = true
				table.insert(ownedSkins, skinName)
			end
		end
	end

	if not seen[defaultSkin] then
		table.insert(ownedSkins, 1, defaultSkin)
	end

	return ownedSkins
end

local function hasOwnedSkin(ownedSkins: { string }, skinName: string): boolean
	return table.find(ownedSkins, skinName) ~= nil
end

local function sanitizeProfile(raw: any): Profile
	local profile: Profile = DefaultProfile.New()
	if type(raw) ~= "table" then
		return profile
	end

	profile.Credits = clampNumber(raw.Credits, 0, 1e12)
	profile.XP = clampNumber(raw.XP, 0, 1e12)
	profile.Level = clampNumber(raw.Level, 1, 1e6)

	profile.ShotgunSkins = sanitizeOwnedSkins(raw.ShotgunSkins, "Shotgun")
	profile.KnifeSkins = sanitizeOwnedSkins(raw.KnifeSkins, "Knife")
	profile.Cases = sanitizeOwnedCases(raw.Cases)

	if type(raw.Career) == "table" then
		profile.Career.Kills = clampNumber(raw.Career.Kills, 0, 1e12)
		profile.Career.Deaths = clampNumber(raw.Career.Deaths, 0, 1e12)
		profile.Career.Assists = clampNumber(raw.Career.Assists, 0, 1e12)
	end

	if type(raw.CurrentlyEquippedShotgunSkin) == "string"
		and hasOwnedSkin(profile.ShotgunSkins, raw.CurrentlyEquippedShotgunSkin)
	then
		profile.CurrentlyEquippedShotgunSkin = raw.CurrentlyEquippedShotgunSkin
	end

	if type(raw.CurrentlyEquippedKnifeSkin) == "string"
		and hasOwnedSkin(profile.KnifeSkins, raw.CurrentlyEquippedKnifeSkin)
	then
		profile.CurrentlyEquippedKnifeSkin = raw.CurrentlyEquippedKnifeSkin
	end

	profile.DailyTasks = sanitizeDailyTasks(raw.DailyTasks)
	profile.Settings = sanitizeSettings(raw.Settings)

	return profile
end

function DataService:_replicateAttributes(player: Player, profile: Profile)
	player:SetAttribute(ATTRIBUTE.Credits, profile.Credits)
	player:SetAttribute(ATTRIBUTE.XP, profile.XP)
	player:SetAttribute(ATTRIBUTE.Level, profile.Level)
	player:SetAttribute(ATTRIBUTE.CareerKills, profile.Career.Kills)
	player:SetAttribute(ATTRIBUTE.CareerDeaths, profile.Career.Deaths)
	player:SetAttribute(ATTRIBUTE.CareerAssists, profile.Career.Assists)
	player:SetAttribute(ATTRIBUTE.EquippedShotgunSkin, profile.CurrentlyEquippedShotgunSkin)
	player:SetAttribute(ATTRIBUTE.EquippedKnifeSkin, profile.CurrentlyEquippedKnifeSkin)
end

function DataService:_markDirty(player: Player)
	self._dirty[player] = true
end

function DataService:MarkDirty(player: Player)
	self:_markDirty(player)
end

function DataService:GetProfile(player: Player): Profile
	local profile = self._profiles[player]
	if profile then
		return profile
	end

	profile = DefaultProfile.New()
	self._profiles[player] = profile
	return profile
end

function DataService:IsProfileLoaded(player: Player): boolean
	return self._profiles[player] ~= nil and not self._loading[player]
end

function DataService:WaitForProfile(player: Player, timeoutSeconds: number?): Profile
	local deadline = if timeoutSeconds then os.clock() + timeoutSeconds else nil

	while player.Parent == Players do
		local profile = self._profiles[player]
		if profile and not self._loading[player] then
			return profile
		end

		if deadline and os.clock() >= deadline then
			break
		end

		task.wait()
	end

	return self:GetProfile(player)
end

function DataService:SetEquippedShotgunSkin(player: Player, skinName: string)
	local profile = self:GetProfile(player)
	profile.CurrentlyEquippedShotgunSkin = skinName
	self:_replicateAttributes(player, profile)
	self:_markDirty(player)
end

function DataService:SetEquippedKnifeSkin(player: Player, skinName: string)
	local profile = self:GetProfile(player)
	profile.CurrentlyEquippedKnifeSkin = skinName
	self:_replicateAttributes(player, profile)
	self:_markDirty(player)
end

function DataService:AddCredits(player: Player, amount: number)
	local profile = self:GetProfile(player)
	profile.Credits = math.max(0, profile.Credits + amount)
	self:_replicateAttributes(player, profile)
	self:_markDirty(player)
end

function DataService:SpendCredits(player: Player, amount: number): boolean
	if amount <= 0 then
		return true
	end

	local profile = self:GetProfile(player)
	if profile.Credits < amount then
		return false
	end

	profile.Credits -= amount
	self:_replicateAttributes(player, profile)
	self:_markDirty(player)
	return true
end

function DataService:GrantCase(player: Player, caseId: string, amount: number?): number
	local resolvedAmount = math.max(math.floor(amount or 1), 1)
	local profile = self:GetProfile(player)
	profile.Cases[caseId] = (profile.Cases[caseId] or 0) + resolvedAmount
	self:_markDirty(player)
	return profile.Cases[caseId]
end

function DataService:ConsumeCase(player: Player, caseId: string, amount: number?): (boolean, number)
	local resolvedAmount = math.max(math.floor(amount or 1), 1)
	local profile = self:GetProfile(player)
	local currentAmount = profile.Cases[caseId] or 0
	if currentAmount < resolvedAmount then
		return false, currentAmount
	end

	local remainingAmount = currentAmount - resolvedAmount
	if remainingAmount > 0 then
		profile.Cases[caseId] = remainingAmount
	else
		profile.Cases[caseId] = nil
		remainingAmount = 0
	end

	self:_markDirty(player)
	return true, remainingAmount
end

function DataService:AddXP(player: Player, amount: number)
	local profile = self:GetProfile(player)
	local previousLevel = profile.Level
	local newLevel, newXP = Leveling.ApplyXP(profile.Level, profile.XP, amount)
	profile.Level = newLevel
	profile.XP = newXP
	self:_replicateAttributes(player, profile)
	self:_markDirty(player)

	if newLevel > previousLevel then
		self.Client.LevelUp:Fire(player, {
			previousLevel = previousLevel,
			level = newLevel,
			gainedLevels = newLevel - previousLevel,
			remainingXP = newXP,
		})
	end
end

function DataService:AddKill(player: Player)
	local profile = self:GetProfile(player)
	profile.Career.Kills += 1
	self:_replicateAttributes(player, profile)
	self:_markDirty(player)
end

function DataService:AddDeath(player: Player)
	local profile = self:GetProfile(player)
	profile.Career.Deaths += 1
	self:_replicateAttributes(player, profile)
	self:_markDirty(player)
end

function DataService:AddAssist(player: Player)
	local profile = self:GetProfile(player)
	profile.Career.Assists += 1
	self:_replicateAttributes(player, profile)
	self:_markDirty(player)
end

function DataService:_savePlayer(player: Player)
	local profile = self._profiles[player]
	if not profile or not self._dirty[player] then
		return
	end

	self._dirty[player] = false

	local store = self._store
	if not store then
		return
	end

	local success, errorMessage = pcall(function()
		store:SetAsync(keyForUserId(player.UserId), profile)
	end)

	if not success then
		warn(("[DataService] Save failed for %s: %s"):format(player.Name, tostring(errorMessage)))
		self._dirty[player] = true
	end
end

function DataService:_loadPlayer(player: Player)
	if self._loading[player] then
		return
	end

	self._loading[player] = true

	local rawProfile = nil
	local store = self._store
	local success, errorMessage = pcall(function()
		if store then
			rawProfile = store:GetAsync(keyForUserId(player.UserId))
		end
	end)

	local profile: Profile
	if success then
		profile = sanitizeProfile(rawProfile)
	else
		warn(("[DataService] Load failed for %s: %s"):format(player.Name, tostring(errorMessage)))
		profile = DefaultProfile.New()
	end

	self._profiles[player] = profile
	self._dirty[player] = false
	self._loading[player] = false
	self:_replicateAttributes(player, profile)
end

function DataService:Init()
	self._store = DataStoreService:GetDataStore(DATASTORE_NAME)

	framework.OnPlayerAdded(function(player: Player)
		self:_loadPlayer(player)
	end)

	framework.OnPlayerRemoving(function(player: Player)
		self:_savePlayer(player)
		self._profiles[player] = nil
		self._dirty[player] = nil
		self._loading[player] = nil
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			self:_savePlayer(player)
		end
	end)
end

function DataService:Start()
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				self:_savePlayer(player)
			end
		end
	end)
end

return DataService
