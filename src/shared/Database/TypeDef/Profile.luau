--!strict

export type CareerStats = {
	Kills: number,
	Deaths: number,
	Assists: number,
}

export type Profile = {
	Credits: number,
	ShotgunSkins: {string},
	KnifeSkins: {string},
	Career: CareerStats,
	XP: number,
	Level: number,
	CurrentlyEquippedShotgunSkin: string,
	CurrentlyEquippedKnifeSkin: string,
}

return {}
