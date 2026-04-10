--!strict

export type RewardId = "Kill" | "Assist" | "DoubleKill" | "TripleKill" | "QuadraKill" | "Pentakill"

export type RewardDefinition = {
	Label: string,
	XP: number,
	Coins: number,
	TitleColor: Color3,
}

export type RewardConfig = {
	KillComboTimeDistanceMaximum: number,
	Rewards: { [RewardId]: RewardDefinition },
	ComboRewardsByCount: { [number]: RewardId },
}

local Config: RewardConfig = {
	KillComboTimeDistanceMaximum = 5,
	Rewards = {
		Kill = {
			Label = "Killed Player",
			XP = 25,
			Coins = 50,
			TitleColor = Color3.fromRGB(255, 255, 255),
		},
		Assist = {
			Label = "Assist",
			XP = 10,
			Coins = 0,
			TitleColor = Color3.fromRGB(145, 225, 255),
		},
		DoubleKill = {
			Label = "Double Kill",
			XP = 15,
			Coins = 25,
			TitleColor = Color3.fromRGB(255, 184, 92),
		},
		TripleKill = {
			Label = "Triple Kill",
			XP = 25,
			Coins = 40,
			TitleColor = Color3.fromRGB(255, 140, 79),
		},
		QuadraKill = {
			Label = "Quadra Kill",
			XP = 40,
			Coins = 60,
			TitleColor = Color3.fromRGB(255, 102, 102),
		},
		Pentakill = {
			Label = "Pentakill",
			XP = 60,
			Coins = 100,
			TitleColor = Color3.fromRGB(255, 218, 92),
		},
	},
	ComboRewardsByCount = {
		[2] = "DoubleKill",
		[3] = "TripleKill",
		[4] = "QuadraKill",
		[5] = "Pentakill",
	},
}

return Config
