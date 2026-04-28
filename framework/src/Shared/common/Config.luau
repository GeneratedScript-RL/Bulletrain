--!strict

export type MapDefinition = {
	DisplayName: string?,
	Icon: string?,
	Enabled: boolean?,
}

local Shotgun = {
	Pellets = 16,
	Range = 400,
	PelletDamage = 12,
	FireCooldown = 0.9,
	SpreadDegrees = 6,
	AimSpreadMultiplier = 0.8,
	AimSightsDistance = 4,
	AimLerpSpeed = 14,
	AimFOVReduction = 20,
	MuzzleVelocity = 1500,
	CameraRecoil = {
		PitchDegrees = 0.675,
		YawDegrees = 0.1875,
		AimMultiplier = 0.65,
		Damping = 0.45,
		Speed = 18,
	},
}

local Knife = {
	Range = 7,
	Damage = 55,
	SwingCooldown = 0.45,
	ParryCooldown = 2,
}

local Config = {
	Maps = {
		["Baseplate"] = {
			DisplayName = "Baseplate",
			Icon = "rbxassetid://0",
		},
		["Cargo Map"] = {
			DisplayName = "Cargo Map",
			Icon = "rbxassetid://0",
		},
		["Construction Map"] = {
			DisplayName = "Construction Map",
			Icon = "rbxassetid://0",
		},
		["Sci-Fi Map"] = {
			DisplayName = "Sci-Fi Map",
			Icon = "rbxassetid://0",
		},
	} :: { [string]: MapDefinition },

	Combat = {
		PacketNames = {
			ShotgunFire = "ShotgunFire",
			KnifeSwing = "KnifeSwing",
			ParryStart = "KnifeParryStart",
			ParrySuccess = "KnifeParrySuccess",
			HitConfirmed = "HitConfirmed",
			ReplicateShotgunBullet = "ReplicateShotgunBullet",
		},
		Shotgun = Shotgun,
		Knife = Knife,
		ParryWindow = 0.3,
		AssistWindow = 8,
	},

	Match = {
		IntermissionDuration = 3,
		MatchDuration = 180,
		EndDuration = 8,
		KillLimit = 100000,
		RespawnDelay = 2,
		DefaultMode = "FFA",
		StateAttribute = "State",
		MapVoteOptionCount = 3,
	},

	WeaponStats = {
		Shotgun = {
			Pellets = Shotgun.Pellets,
			Range = Shotgun.Range,
			PelletDamage = Shotgun.PelletDamage,
			SpreadDegrees = Shotgun.SpreadDegrees,
			MuzzleVelocity = Shotgun.MuzzleVelocity,
			FireCooldown = Shotgun.FireCooldown,
		},
		Knife = {
			Range = Knife.Range,
			Damage = Knife.Damage,
			SwingCooldown = Knife.SwingCooldown,
			ParryCooldown = Knife.ParryCooldown,
		},
	},

	Movement = {
		SLIDE_SPEED_THRESHOLD = 20,
		SLIDE_INITIAL_SPEED = 70,
		SLIDE_END_SPEED = 0,
		SLIDE_DURATION = 1,
		SLIDE_POWER = 1.3,
		CROUCH_OFFSET = Vector3.new(0, -0.65, 0),
		SLIDE_OFFSET = Vector3.new(0, -0.65, 0),
		STAND_OFFSET = Vector3.new(0, 0, 0),
		TWEEN_TIME = 0.12,
		SLIDE_TWEEN_TIME = 0.2,
		MOMENTUM_PRESERVATION = 0.5,
		DEFAULT_FOV = 80,
		SLIDE_FOV = 90,
		FOV_TWEEN_IN = 0.2,
		FOV_TWEEN_OUT = 0.5,
		SLIDE_RISE_START_PROGRESS = 0.8,
		SLIDE_TILT_ANGLE = 0,
		TILT_TWEEN_TIME = 0.3,
	},

	Rewards = {
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
	},
}

return Config
