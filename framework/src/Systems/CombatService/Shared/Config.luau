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
		SpreadDegrees = 6,
		MuzzleVelocity = 1500,
	},
	Knife = {
		Range = 7,
		Damage = 55,
	},
	ParryWindow = 0.3,
	AssistWindow = 8,
}
