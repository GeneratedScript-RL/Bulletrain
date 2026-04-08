--!strict

export type SettingKey =
	"ShadowsEnabled"
	| "MasterVolume"
	| "SFXVolume"
	| "EffectsEnabled"
	| "FOV"
	| "MaterialsEnabled"

export type SettingKind = "toggle" | "slider"

export type SettingsProfile = {
	ShadowsEnabled: boolean,
	MasterVolume: number,
	SFXVolume: number,
	EffectsEnabled: boolean,
	FOV: number,
	MaterialsEnabled: boolean,
}

export type SettingDefinition = {
	Key: SettingKey,
	Label: string,
	Kind: SettingKind,
	DefaultValue: boolean | number,
	Min: number?,
	Max: number?,
}

return {}
