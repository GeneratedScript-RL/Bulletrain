--!strict

local DailyTaskTypes = require(script.Parent.Parent.Parent.DailyTasks.Types)
local SettingTypes = require(script.Parent.Parent.Parent.Settings.Types)

export type CareerStats = {
	Kills: number,
	Deaths: number,
	Assists: number,
}

export type DailyTaskEntry = DailyTaskTypes.DailyTaskEntry
export type DailyTaskProfile = DailyTaskTypes.DailyTaskProfile
export type SettingsProfile = SettingTypes.SettingsProfile

export type Profile = {
	Credits: number,
	ShotgunSkins: {string},
	KnifeSkins: {string},
	Career: CareerStats,
	XP: number,
	Level: number,
	CurrentlyEquippedShotgunSkin: string,
	CurrentlyEquippedKnifeSkin: string,
	DailyTasks: DailyTaskProfile,
	Settings: SettingsProfile,
}

return {}
