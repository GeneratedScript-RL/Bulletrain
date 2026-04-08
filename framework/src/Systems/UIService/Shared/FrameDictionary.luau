--!strict

export type FrameDetails = {
	LobbyUI: boolean?,
	CombatUI: boolean?,
	VisibleStates: { [string]: boolean }?,
	DefaultVisible: boolean?,
}

--[[
	FrameDetails fields:
	- LobbyUI: visible while the player is not in "Combat"
	- CombatUI: visible only while the player is in "Combat"
	- VisibleStates: explicit per-state visibility map, e.g. { Menu = true, Combat = false }
	- DefaultVisible: fallback visibility when no other rule above applies
]]
local FrameDictionary: { [string]: FrameDetails } = {
	Default = {
		VisibleStates = {
			Menu = false,
			Combat = false,
		},
		DefaultVisible = false,
	},
	Lobby = {
		-- Visible while the player is outside combat.
		LobbyUI = true,
	},
	Settings = {
		LobbyUI = true,
	},
	Inventory = {
		LobbyUI = true,
	},
	ShopHolder = {
		LobbyUI = true,
	},
	Stats = {
		LobbyUI = true,
	},
}

return FrameDictionary
