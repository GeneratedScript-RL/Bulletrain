--!strict

local WeaponStats = {}

WeaponStats.Shotgun = {
	Pellets = 8,
	Range = 400,
	PelletDamage = 12,
	SpreadDegrees = 6,
	MuzzleVelocity = 800,
	FireCooldown = 0.9,
}

WeaponStats.Knife = {
	Range = 7,
	Damage = 55,
	SwingCooldown = 0.45,
}

return WeaponStats
