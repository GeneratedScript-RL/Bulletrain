--!strict

local SettingTypes = require(script.Parent.Types)

type SettingDefinition = SettingTypes.SettingDefinition

local orderedDefinitions = {
	{
		Key = "ShadowsEnabled",
		Label = "Shadow",
		Kind = "toggle",
		DefaultValue = true,
	},
	{
		Key = "MasterVolume",
		Label = "Volume",
		Kind = "slider",
		DefaultValue = 100,
		Min = 0,
		Max = 100,
	},
	{
		Key = "SFXVolume",
		Label = "SFX",
		Kind = "slider",
		DefaultValue = 100,
		Min = 0,
		Max = 100,
	},
	{
		Key = "EffectsEnabled",
		Label = "Effects",
		Kind = "toggle",
		DefaultValue = true,
	},
	{
		Key = "FOV",
		Label = "FOV",
		Kind = "slider",
		DefaultValue = 80,
		Min = 60,
		Max = 110,
	},
	{
		Key = "MaterialsEnabled",
		Label = "Materials",
		Kind = "toggle",
		DefaultValue = true,
	},
} :: { SettingDefinition }

local byKey = {}
local byLabel = {}

for _, definition in ipairs(orderedDefinitions) do
	byKey[definition.Key] = definition
	byLabel[definition.Label] = definition
end

return {
	Ordered = orderedDefinitions,
	ByKey = byKey,
	ByLabel = byLabel,
}
