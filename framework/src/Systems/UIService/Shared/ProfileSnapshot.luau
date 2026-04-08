--!strict

local root = script.Parent.Parent.Parent.Parent
local Types = require(root.Types)

local Leveling = require(root.Shared.Database.Leveling)

export type ProfileSnapshot = {
	Credits: number,
	XP: number,
	Level: number,
	CareerKills: number,
	CareerDeaths: number,
	CareerAssists: number,
	RequiredXP: number,
	Progress: number,
}

local ATTRIBUTE = {
	Credits = "Credits",
	XP = "XP",
	Level = "Level",
	CareerKills = "CareerKills",
	CareerDeaths = "CareerDeaths",
	CareerAssists = "CareerAssists",
}

local ProfileSnapshot = {}

local function getNumberAttribute(player: Player, attributeName: string, defaultValue: number): number
	local value = player:GetAttribute(attributeName)
	if type(value) ~= "number" or value ~= value then
		return defaultValue
	end

	return value
end

local function roundPositiveNumber(value: number): number
	if value >= 0 then
		return math.floor(value + 0.5)
	end

	return math.ceil(value - 0.5)
end

function ProfileSnapshot.Get(player: Player): ProfileSnapshot
	local level = math.max(getNumberAttribute(player, ATTRIBUTE.Level, 1), 1)
	local xp = math.max(getNumberAttribute(player, ATTRIBUTE.XP, 0), 0)
	local requiredXP = math.max(Leveling.RequiredXPForLevel(level), 1)

	return {
		Credits = math.max(getNumberAttribute(player, ATTRIBUTE.Credits, 0), 0),
		XP = xp,
		Level = level,
		CareerKills = math.max(getNumberAttribute(player, ATTRIBUTE.CareerKills, 0), 0),
		CareerDeaths = math.max(getNumberAttribute(player, ATTRIBUTE.CareerDeaths, 0), 0),
		CareerAssists = math.max(getNumberAttribute(player, ATTRIBUTE.CareerAssists, 0), 0),
		RequiredXP = requiredXP,
		Progress = math.clamp(xp / requiredXP, 0, 1),
	}
end

function ProfileSnapshot.Observe(player: Player, trove: Types.Trove, callback: (snapshot: ProfileSnapshot) -> ())
	local function emit()
		callback(ProfileSnapshot.Get(player))
	end

	emit()

	for _, attributeName in ATTRIBUTE do
		trove:Connect(player:GetAttributeChangedSignal(attributeName), emit)
	end
end

function ProfileSnapshot.FormatInteger(value: number): string
	local rounded = roundPositiveNumber(value)
	local digits = tostring(math.abs(rounded))
	local groups = {}

	while #digits > 3 do
		table.insert(groups, 1, string.sub(digits, -3))
		digits = string.sub(digits, 1, #digits - 3)
	end

	table.insert(groups, 1, digits)

	local prefix = if rounded < 0 then "-" else ""
	return prefix .. table.concat(groups, ",")
end

return ProfileSnapshot
