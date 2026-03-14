--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DefaultProfile = require(ReplicatedStorage.Shared.Database.DefaultProfile)
local Leveling = require(ReplicatedStorage.Shared.Database.Leveling)
local ProfileTypes = require(ReplicatedStorage.Shared.Database.TypeDef.Profile)

type Profile = ProfileTypes.Profile

local DataService = {}
DataService.__index = DataService

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

function DataService.new()
	local self = setmetatable({}, DataService)
	self._store = DataStoreService:GetDataStore(DATASTORE_NAME)
	self._profiles = {} :: {[Player]: Profile}
	self._dirty = {} :: {[Player]: boolean}
	self._loading = {} :: {[Player]: boolean}
	return self
end

local singleton = DataService.new()

local function keyForUserId(userId: number): string
	return (`Player_{userId}`)
end

local function clampNumber(n: any, minV: number, maxV: number): number
	if type(n) ~= "number" then
		return minV
	end
	if n ~= n then
		return minV
	end
	return math.clamp(n, minV, maxV)
end

local function sanitizeProfile(raw: any): Profile
	local p: Profile = DefaultProfile.New()
	if type(raw) ~= "table" then
		return p
	end

	p.Credits = clampNumber(raw.Credits, 0, 1e12)
	p.XP = clampNumber(raw.XP, 0, 1e12)
	p.Level = clampNumber(raw.Level, 1, 1e6)

	if type(raw.ShotgunSkins) == "table" then
		p.ShotgunSkins = raw.ShotgunSkins :: any
	end
	if type(raw.KnifeSkins) == "table" then
		p.KnifeSkins = raw.KnifeSkins :: any
	end

	if type(raw.Career) == "table" then
		p.Career.Kills = clampNumber(raw.Career.Kills, 0, 1e12)
		p.Career.Deaths = clampNumber(raw.Career.Deaths, 0, 1e12)
		p.Career.Assists = clampNumber(raw.Career.Assists, 0, 1e12)
	end

	if type(raw.CurrentlyEquippedShotgunSkin) == "string" then
		p.CurrentlyEquippedShotgunSkin = raw.CurrentlyEquippedShotgunSkin
	end
	if type(raw.CurrentlyEquippedKnifeSkin) == "string" then
		p.CurrentlyEquippedKnifeSkin = raw.CurrentlyEquippedKnifeSkin
	end

	return p
end

function singleton:_replicateAttributes(player: Player, profile: Profile)
	player:SetAttribute(ATTRIBUTE.Credits, profile.Credits)
	player:SetAttribute(ATTRIBUTE.XP, profile.XP)
	player:SetAttribute(ATTRIBUTE.Level, profile.Level)
	player:SetAttribute(ATTRIBUTE.CareerKills, profile.Career.Kills)
	player:SetAttribute(ATTRIBUTE.CareerDeaths, profile.Career.Deaths)
	player:SetAttribute(ATTRIBUTE.CareerAssists, profile.Career.Assists)
	player:SetAttribute(ATTRIBUTE.EquippedShotgunSkin, profile.CurrentlyEquippedShotgunSkin)
	player:SetAttribute(ATTRIBUTE.EquippedKnifeSkin, profile.CurrentlyEquippedKnifeSkin)
end

function singleton:_markDirty(player: Player)
	self._dirty[player] = true
end

function singleton:GetProfile(player: Player): Profile
	local profile = self._profiles[player]
	if not profile then
		profile = DefaultProfile.New()
		self._profiles[player] = profile
	end
	return profile
end

function singleton:SetEquippedShotgunSkin(player: Player, skinName: string)
	local profile = self:GetProfile(player)
	profile.CurrentlyEquippedShotgunSkin = skinName
	self:_replicateAttributes(player, profile)
	self:_markDirty(player)
end

function singleton:SetEquippedKnifeSkin(player: Player, skinName: string)
	local profile = self:GetProfile(player)
	profile.CurrentlyEquippedKnifeSkin = skinName
	self:_replicateAttributes(player, profile)
	self:_markDirty(player)
end

function singleton:AddCredits(player: Player, amount: number)
	local profile = self:GetProfile(player)
	profile.Credits = math.max(0, profile.Credits + amount)
	self:_replicateAttributes(player, profile)
	self:_markDirty(player)
end

function singleton:AddXP(player: Player, amount: number)
	local profile = self:GetProfile(player)
	local newLevel, newXP = Leveling.ApplyXP(profile.Level, profile.XP, amount)
	profile.Level = newLevel
	profile.XP = newXP
	self:_replicateAttributes(player, profile)
	self:_markDirty(player)
end

function singleton:AddKill(player: Player)
	local profile = self:GetProfile(player)
	profile.Career.Kills += 1
	self:_replicateAttributes(player, profile)
	self:_markDirty(player)
end

function singleton:AddDeath(player: Player)
	local profile = self:GetProfile(player)
	profile.Career.Deaths += 1
	self:_replicateAttributes(player, profile)
	self:_markDirty(player)
end

function singleton:AddAssist(player: Player)
	local profile = self:GetProfile(player)
	profile.Career.Assists += 1
	self:_replicateAttributes(player, profile)
	self:_markDirty(player)
end

function singleton:_savePlayer(player: Player)
	local profile = self._profiles[player]
	if not profile then
		return
	end
	if not self._dirty[player] then
		return
	end

	self._dirty[player] = false

	local key = keyForUserId(player.UserId)
	local dataToSave = profile

	local ok, err = pcall(function()
		self._store:SetAsync(key, dataToSave)
	end)

	if not ok then
		warn(("[DataService] Save failed for %s: %s"):format(player.Name, tostring(err)))
		self._dirty[player] = true
	end
end

function singleton:_loadPlayer(player: Player)
	if self._loading[player] then
		return
	end
	self._loading[player] = true

	local key = keyForUserId(player.UserId)
	local raw
	local ok, err = pcall(function()
		raw = self._store:GetAsync(key)
	end)

	local profile: Profile
	if ok then
		profile = sanitizeProfile(raw)
	else
		warn(("[DataService] Load failed for %s: %s"):format(player.Name, tostring(err)))
		profile = DefaultProfile.New()
	end

	self._profiles[player] = profile
	self._dirty[player] = false
	self:_replicateAttributes(player, profile)

	self._loading[player] = false
end

function singleton:Initialize()
	Players.PlayerAdded:Connect(function(player)
		self:_loadPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_savePlayer(player)
		self._profiles[player] = nil
		self._dirty[player] = nil
		self._loading[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:_loadPlayer(player)
		end)
	end

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			self:_savePlayer(player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				self:_savePlayer(player)
			end
		end
	end)
end

return singleton
