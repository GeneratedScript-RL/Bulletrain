--!strict

local InventorySkins = require(script.Parent.Parent.Inventory.Skins)

export type CurrencyType = "Coins" | "Robux"
export type CaseRarity = "Common" | "Rare" | "Epic" | "Legendary"
type SkinCategory = InventorySkins.SkinCategory

export type CaseReward = {
	Category: SkinCategory,
	SkinName: string,
	Name: string,
	Icon: string,
	Rarity: CaseRarity,
	Chance: number,
	DuplicateCredits: number,
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
	RarityChances: { [CaseRarity]: number },
}

type CaseRewardSource = {
	Category: SkinCategory,
	SkinName: string,
	Rarity: CaseRarity,
	Chance: number,
	DuplicateCredits: number,
}

type SkinCaseDefinitionSource = {
	Id: string,
	Name: string,
	Icon: string,
	PrimaryCurrency: CurrencyType,
	CoinPrice: number?,
	RobuxPrice: number?,
	DevProductId: number,
	Rewards: { CaseRewardSource },
}

local CASES: { SkinCaseDefinitionSource } = {
	{
		Id = "StarterCase",
		Name = "Starter Case",
		Icon = "",
		PrimaryCurrency = "Coins",
		CoinPrice = 500,
		RobuxPrice = 39,
		DevProductId = 0,
		Rewards = {
			{ Category = "Shotgun", SkinName = "Rustbite", Rarity = "Common", Chance = 35, DuplicateCredits = 50 },
			{ Category = "Shotgun", SkinName = "Mossline", Rarity = "Common", Chance = 27, DuplicateCredits = 50 },
			{ Category = "Knife", SkinName = "Slate Fang", Rarity = "Rare", Chance = 18, DuplicateCredits = 90 },
			{ Category = "Shotgun", SkinName = "Frostline", Rarity = "Epic", Chance = 12, DuplicateCredits = 160 },
			{ Category = "Knife", SkinName = "Gilded Fang", Rarity = "Legendary", Chance = 8, DuplicateCredits = 300 },
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
			{ Category = "Shotgun", SkinName = "Urban Fade", Rarity = "Common", Chance = 24, DuplicateCredits = 70 },
			{ Category = "Knife", SkinName = "Olive Burst", Rarity = "Common", Chance = 20, DuplicateCredits = 70 },
			{ Category = "Shotgun", SkinName = "Signal Red", Rarity = "Rare", Chance = 18, DuplicateCredits = 110 },
			{ Category = "Knife", SkinName = "Crimson Web", Rarity = "Rare", Chance = 16, DuplicateCredits = 110 },
			{ Category = "Shotgun", SkinName = "Night Ops", Rarity = "Epic", Chance = 13, DuplicateCredits = 190 },
			{ Category = "Knife", SkinName = "Aurora Edge", Rarity = "Legendary", Chance = 9, DuplicateCredits = 350 },
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
			{ Category = "Shotgun", SkinName = "Carbon Pulse", Rarity = "Rare", Chance = 24, DuplicateCredits = 120 },
			{ Category = "Knife", SkinName = "Frostbite", Rarity = "Rare", Chance = 22, DuplicateCredits = 120 },
			{ Category = "Shotgun", SkinName = "Hyperwave", Rarity = "Epic", Chance = 18, DuplicateCredits = 220 },
			{ Category = "Shotgun", SkinName = "Solar Bloom", Rarity = "Epic", Chance = 14, DuplicateCredits = 220 },
			{ Category = "Knife", SkinName = "Obsidian Fang", Rarity = "Legendary", Chance = 12, DuplicateCredits = 400 },
			{ Category = "Knife", SkinName = "Neon Crown", Rarity = "Legendary", Chance = 10, DuplicateCredits = 500 },
		},
	},
}

local SkinCases = {}

local function resolveReward(source: CaseRewardSource): CaseReward
	local definition = InventorySkins.GetDefinition(source.Category, source.SkinName)
	assert(definition ~= nil, ("[SkinCases] Unknown skin '%s' for category '%s'"):format(source.SkinName, source.Category))

	return {
		Category = source.Category,
		SkinName = source.SkinName,
		Name = definition.Name,
		Icon = definition.Icon,
		Rarity = source.Rarity,
		Chance = source.Chance,
		DuplicateCredits = source.DuplicateCredits,
	}
end

local function copyRewards(rewards: { CaseRewardSource }): { CaseReward }
	local out = table.create(#rewards)

	for index, reward in ipairs(rewards) do
		out[index] = resolveReward(reward)
	end

	return out
end

local function buildRarityChances(rewards: { CaseRewardSource }): { [CaseRarity]: number }
	local rarityChances: { [CaseRarity]: number } = {
		Common = 0,
		Rare = 0,
		Epic = 0,
		Legendary = 0,
	}

	local totalChance = 0
	for _, reward in ipairs(rewards) do
		rarityChances[reward.Rarity] += reward.Chance
		totalChance += reward.Chance
	end

	assert(math.abs(totalChance - 100) < 0.001, "[SkinCases] Case reward chances must total 100%.")
	return rarityChances
end

local function copyDefinition(definition: SkinCaseDefinitionSource): SkinCaseDefinition
	return {
		Id = definition.Id,
		Name = definition.Name,
		Icon = definition.Icon,
		PrimaryCurrency = definition.PrimaryCurrency,
		CoinPrice = definition.CoinPrice,
		RobuxPrice = definition.RobuxPrice,
		DevProductId = definition.DevProductId,
		Rewards = copyRewards(definition.Rewards),
		RarityChances = buildRarityChances(definition.Rewards),
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
