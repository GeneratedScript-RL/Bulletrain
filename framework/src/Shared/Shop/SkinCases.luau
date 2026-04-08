--!strict

export type CurrencyType = "Coins" | "Robux"
export type CaseReward = {
	Name: string,
	Icon: string,
	Rarity: string,
}

export type SkinCaseDefinition = {
	Id: string,
	Name: string,
	Icon: string,
	PrimaryCurrency: CurrencyType,
	CoinPrice: number?,
	RobuxPrice: number?,
	DevProductId: number,
	Rewards: { CaseReward },
	RarityChances: { [string]: number },
}

local CASES: { SkinCaseDefinition } = {
	{
		Id = "StarterCase",
		Name = "Starter Case",
		Icon = "",
		PrimaryCurrency = "Coins",
		CoinPrice = 500,
		RobuxPrice = 39,
		DevProductId = 0,
		Rewards = {
			{ Name = "Default Bronze", Icon = "", Rarity = "Common" },
			{ Name = "Default Slate", Icon = "", Rarity = "Common" },
			{ Name = "Default Arctic", Icon = "", Rarity = "Rare" },
			{ Name = "Default Ember", Icon = "", Rarity = "Epic" },
			{ Name = "Default Gold", Icon = "", Rarity = "Legendary" },
		},
		RarityChances = {
			Common = 55,
			Rare = 28,
			Epic = 12,
			Legendary = 5,
		},
	},
	{
		Id = "TacticalCase",
		Name = "Tactical Case",
		Icon = "",
		PrimaryCurrency = "Robux",
		CoinPrice = 1_250,
		RobuxPrice = 79,
		DevProductId = 0,
		Rewards = {
			{ Name = "Urban Fade", Icon = "", Rarity = "Common" },
			{ Name = "Olive Burst", Icon = "", Rarity = "Rare" },
			{ Name = "Signal Red", Icon = "", Rarity = "Rare" },
			{ Name = "Night Ops", Icon = "", Rarity = "Epic" },
			{ Name = "Royal Guard", Icon = "", Rarity = "Legendary" },
		},
		RarityChances = {
			Common = 45,
			Rare = 32,
			Epic = 16,
			Legendary = 7,
		},
	},
	{
		Id = "EliteCase",
		Name = "Elite Case",
		Icon = "",
		PrimaryCurrency = "Robux",
		CoinPrice = 2_500,
		RobuxPrice = 149,
		DevProductId = 0,
		Rewards = {
			{ Name = "Carbon Pulse", Icon = "", Rarity = "Rare" },
			{ Name = "Frostbite", Icon = "", Rarity = "Rare" },
			{ Name = "Hyperwave", Icon = "", Rarity = "Epic" },
			{ Name = "Solar Bloom", Icon = "", Rarity = "Epic" },
			{ Name = "Neon Crown", Icon = "", Rarity = "Legendary" },
		},
		RarityChances = {
			Common = 0,
			Rare = 50,
			Epic = 35,
			Legendary = 15,
		},
	},
}

local SkinCases = {}

local function copyRewards(rewards: { CaseReward }): { CaseReward }
	local out = table.create(#rewards)

	for index, reward in ipairs(rewards) do
		out[index] = {
			Name = reward.Name,
			Icon = reward.Icon,
			Rarity = reward.Rarity,
		}
	end

	return out
end

local function copyRarityChances(rarityChances: { [string]: number }): { [string]: number }
	return table.clone(rarityChances)
end

local function copyDefinition(definition: SkinCaseDefinition): SkinCaseDefinition
	return {
		Id = definition.Id,
		Name = definition.Name,
		Icon = definition.Icon,
		PrimaryCurrency = definition.PrimaryCurrency,
		CoinPrice = definition.CoinPrice,
		RobuxPrice = definition.RobuxPrice,
		DevProductId = definition.DevProductId,
		Rewards = copyRewards(definition.Rewards),
		RarityChances = copyRarityChances(definition.RarityChances),
	}
end

function SkinCases.GetAll(): { SkinCaseDefinition }
	local out = table.create(#CASES)

	for index, definition in ipairs(CASES) do
		out[index] = copyDefinition(definition)
	end

	return out
end

function SkinCases.GetById(caseId: string): SkinCaseDefinition?
	for _, definition in ipairs(CASES) do
		if definition.Id == caseId then
			return copyDefinition(definition)
		end
	end

	return nil
end

return SkinCases
