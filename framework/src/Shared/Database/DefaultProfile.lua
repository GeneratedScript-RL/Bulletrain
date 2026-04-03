--!strict

local ProfileTypes = require(script.Parent.TypeDef.Profile)

type Profile = ProfileTypes.Profile

local DefaultProfile = {}

DefaultProfile.Data = {
	Credits = 0,
	ShotgunSkins = { "Default" },
	KnifeSkins = { "Default" },
	Career = {
		Kills = 0,
		Deaths = 0,
		Assists = 0,
	},
	XP = 0,
	Level = 1,
	CurrentlyEquippedShotgunSkin = "Default",
	CurrentlyEquippedKnifeSkin = "Default",
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
