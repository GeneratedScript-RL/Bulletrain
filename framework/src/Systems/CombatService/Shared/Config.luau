--!strict

return {
	PacketNames = {
		ShotgunFire = "ShotgunFire",
		KnifeSwing = "KnifeSwing",
		ParryStart = "KnifeParryStart",
		ParrySuccess = "KnifeParrySuccess",
		HitConfirmed = "HitConfirmed",
		ReplicateShotgunBullet = "ReplicateShotgunBullet",
	},
	Shotgun = {
		Pellets = 8,
		Range = 400,
		PelletDamage = 12,
		FireCooldown = 0.9,
		SpreadDegrees = 6,
		AimSpreadMultiplier = 0.8,
		AimSightsDistance = 4,
		AimLerpSpeed = 14,
		MuzzleVelocity = 1500,
		CameraRecoil = {
			PitchDegrees = 0.675,
			YawDegrees = 0.1875,
			AimMultiplier = 0.65,
			Damping = 0.45,
			Speed = 18,
		},
	},
	Knife = {
		Range = 7,
		Damage = 55,
	},
	ParryWindow = 0.3,
	AssistWindow = 8,
}
