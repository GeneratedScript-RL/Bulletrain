--!strict

local SettingDefinitions = require(script.Parent.Definitions)
local SettingTypes = require(script.Parent.Types)

type SettingDefinition = SettingTypes.SettingDefinition
type SettingKey = SettingTypes.SettingKey
type SettingsProfile = SettingTypes.SettingsProfile

local SettingsDefaults = {}

function SettingsDefaults.New(): SettingsProfile
	local settings = {} :: any

	for _, definition: SettingDefinition in ipairs(SettingDefinitions.Ordered) do
		settings[definition.Key] = definition.DefaultValue
	end

	return settings :: SettingsProfile
end

function SettingsDefaults.CoerceValue(key: string, rawValue: any): (SettingKey?, boolean | number?)
	local definition = SettingDefinitions.ByKey[key] :: SettingDefinition?
	if not definition then
		return nil, nil
	end

	if definition.Kind == "toggle" then
		if type(rawValue) ~= "boolean" then
			return definition.Key, nil
		end

		return definition.Key, rawValue
	end

	local numericValue = if type(rawValue) == "number"
		then rawValue
		elseif type(rawValue) == "string"
			then tonumber(rawValue)
			else nil

	if type(numericValue) ~= "number" or numericValue ~= numericValue then
		return definition.Key, nil
	end

	local minimum = definition.Min or numericValue
	local maximum = definition.Max or numericValue

	return definition.Key, math.clamp(math.round(numericValue), minimum, maximum)
end

function SettingsDefaults.Sanitize(raw: any): SettingsProfile
	local settings = SettingsDefaults.New()

	if type(raw) ~= "table" then
		return settings
	end

	for _, definition: SettingDefinition in ipairs(SettingDefinitions.Ordered) do
		local _, coercedValue = SettingsDefaults.CoerceValue(definition.Key, raw[definition.Key])
		if coercedValue ~= nil then
			(settings :: any)[definition.Key] = coercedValue
		end
	end

	return settings
end

return SettingsDefaults
