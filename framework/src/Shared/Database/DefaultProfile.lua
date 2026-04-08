--!strict

local DailyTaskTypes = require(script.Parent.Parent.DailyTasks.Types)
local SettingsDefaults = require(script.Parent.Parent.Settings.Defaults)
local ProfileTypes = require(script.Parent.TypeDef.Profile)

type Profile = ProfileTypes.Profile
type DailyTaskEntry = DailyTaskTypes.DailyTaskEntry

local DefaultProfile = {}

DefaultProfile.Data = {
	Credits = 0,
	ShotgunSkins = { "Default" },
	KnifeSkins = { "Default" },
	Cases = {} :: { [string]: number },
	Career = {
		Kills = 0,
		Deaths = 0,
		Assists = 0,
	},
	XP = 0,
	Level = 1,
	CurrentlyEquippedShotgunSkin = "Default",
	CurrentlyEquippedKnifeSkin = "Default",
	DailyTasks = {
		DayKey = "",
		Tasks = {} :: { [string]: DailyTaskEntry },
	},
	Settings = SettingsDefaults.New(),
} :: Profile

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = deepCopy(v)
	end
	return out
end

function DefaultProfile.New(): Profile
	return deepCopy(DefaultProfile.Data) :: any
end

return DefaultProfile
