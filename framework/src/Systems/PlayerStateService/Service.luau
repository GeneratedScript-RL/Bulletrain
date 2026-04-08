--!strict

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkServer = require(root) :: any

local StateTypes = require(script.Parent.Shared.Types)

type PlayerState = StateTypes.PlayerState

local ATTRIBUTE_NAME = "State"

local PlayerStateService = framework.CreateService({
	Name = "PlayerStateService",
	Client = {
		CurrentState = framework.CreateProperty("Menu" :: PlayerState),
	},
})

local function sanitizeState(state: any): PlayerState
	if state == "Combat" then
		return "Combat"
	end

	return "Menu"
end

function PlayerStateService:SetState(player: Player, state: PlayerState)
	local safeState = sanitizeState(state)
	player:SetAttribute(ATTRIBUTE_NAME, safeState)
	self.Client.CurrentState:SetFor(player, safeState)
end

function PlayerStateService:GetState(player: Player): PlayerState
	return sanitizeState(self.Client.CurrentState:GetFor(player))
end

function PlayerStateService:_handleCharacter(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			descendant.CollisionGroup = "Players"
		end
	end
end

function PlayerStateService:Init()
	framework.OnPlayerAdded(function(player: Player, trove: Types.Trove)
		self:SetState(player, sanitizeState(player:GetAttribute(ATTRIBUTE_NAME)))

		trove:Connect(player.CharacterAdded, function(character: Model)
			self:_handleCharacter(character)
		end)

		if player.Character then
			self:_handleCharacter(player.Character)
		end
	end)
end

return PlayerStateService
