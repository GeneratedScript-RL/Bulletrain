--!strict

local Players = game:GetService("Players")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkServer = require(root) :: any

local SettingsDefaults = require(root.Shared.Settings.Defaults)
local SettingTypes = require(root.Shared.Settings.Types)

type SettingsProfile = SettingTypes.SettingsProfile

local dataService: any

local SettingsService = framework.CreateService({
	Name = "SettingsService",
	Dependencies = { "DataService" },
	Client = {
		Preferences = framework.CreateProperty(SettingsDefaults.New()),
	},
})

local function copySettings(settings: SettingsProfile): SettingsProfile
	return SettingsDefaults.Sanitize(settings)
end

function SettingsService:_getSettings(player: Player): SettingsProfile
	local profile = dataService:GetProfile(player)
	profile.Settings = SettingsDefaults.Sanitize(profile.Settings)
	return profile.Settings
end

function SettingsService:_syncPlayer(player: Player)
	if player.Parent ~= Players then
		return
	end

	self.Client.Preferences:SetFor(player, copySettings(self:_getSettings(player)))
end

function SettingsService:UpdatePreference(player: Player, key: string, rawValue: any): (boolean, SettingsProfile)
	local normalizedKey, coercedValue = SettingsDefaults.CoerceValue(key, rawValue)
	local settings = self:_getSettings(player)

	if not normalizedKey or coercedValue == nil then
		return false, copySettings(settings)
	end

	if (settings :: any)[normalizedKey] == coercedValue then
		return true, copySettings(settings)
	end

	(settings :: any)[normalizedKey] = coercedValue
	dataService:MarkDirty(player)
	self:_syncPlayer(player)

	return true, copySettings(settings)
end

function SettingsService:ResetPreferences(player: Player): SettingsProfile
	local profile = dataService:GetProfile(player)
	local defaults = SettingsDefaults.New()

	profile.Settings = defaults
	dataService:MarkDirty(player)
	self:_syncPlayer(player)

	return copySettings(defaults)
end

function SettingsService.Client:UpdatePreference(player: Player, key: string, rawValue: any)
	return self.Server:UpdatePreference(player, key, rawValue)
end

function SettingsService.Client:ResetPreferences(player: Player)
	return true, self.Server:ResetPreferences(player)
end

function SettingsService:Init()
	dataService = framework.GetService("DataService")

	framework.OnPlayerAdded(function(player: Player)
		self:_syncPlayer(player)
	end)
end

return SettingsService
