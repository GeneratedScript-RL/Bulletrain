--!strict

export type SkinCategory = "Shotgun" | "Knife"

export type SkinDefinition = {
	Name: string,
	Icon: string,
}

type SkinDefinitionList = { SkinDefinition }

local CATEGORY_DEFINITIONS: { [SkinCategory]: SkinDefinitionList } = {
	Shotgun = {
		{
			Name = "Default",
			Icon = "",
		},
		{
			Name = "Rustbite",
			Icon = "",
		},
		{
			Name = "Mossline",
			Icon = "",
		},
		{
			Name = "Frostline",
			Icon = "",
		},
		{
			Name = "Emberfall",
			Icon = "",
		},
		{
			Name = "Urban Fade",
			Icon = "",
		},
		{
			Name = "Signal Red",
			Icon = "",
		},
		{
			Name = "Night Ops",
			Icon = "",
		},
		{
			Name = "Carbon Pulse",
			Icon = "",
		},
		{
			Name = "Hyperwave",
			Icon = "",
		},
		{
			Name = "Solar Bloom",
			Icon = "",
		},
	},
	Knife = {
		{
			Name = "Default",
			Icon = "",
		},
		{
			Name = "Slate Fang",
			Icon = "",
		},
		{
			Name = "Gilded Fang",
			Icon = "",
		},
		{
			Name = "Olive Burst",
			Icon = "",
		},
		{
			Name = "Crimson Web",
			Icon = "",
		},
		{
			Name = "Aurora Edge",
			Icon = "",
		},
		{
			Name = "Frostbite",
			Icon = "",
		},
		{
			Name = "Obsidian Fang",
			Icon = "",
		},
		{
			Name = "Neon Crown",
			Icon = "",
		},
	},
}

local InventorySkins = {
	Categories = {
		Shotgun = "Shotgun" :: SkinCategory,
		Knife = "Knife" :: SkinCategory,
	},
}

local function copyDefinitions(definitions: SkinDefinitionList): SkinDefinitionList
	local out = table.create(#definitions)

	for index, definition in ipairs(definitions) do
		out[index] = {
			Name = definition.Name,
			Icon = definition.Icon,
		}
	end

	return out
end

function InventorySkins.GetDefinitions(category: SkinCategory): SkinDefinitionList
	return copyDefinitions(CATEGORY_DEFINITIONS[category])
end

function InventorySkins.GetDefinition(category: SkinCategory, skinName: string): SkinDefinition?
	for _, definition in ipairs(CATEGORY_DEFINITIONS[category]) do
		if definition.Name == skinName then
			return definition
		end
	end

	return nil
end

function InventorySkins.IsValid(category: SkinCategory, skinName: string): boolean
	return InventorySkins.GetDefinition(category, skinName) ~= nil
end

function InventorySkins.GetDefaultSkin(category: SkinCategory): string
	local definitions = CATEGORY_DEFINITIONS[category]
	return definitions[1].Name
end

return InventorySkins
