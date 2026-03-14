--!strict

local Players = game:GetService("Players")

export type PlayerState = "Menu" | "Combat"

local PlayerStateService = {}
PlayerStateService.__index = PlayerStateService

local ATTRIBUTE_NAME = "State"

function PlayerStateService:SetState(player: Player, state: PlayerState)
	player:SetAttribute(ATTRIBUTE_NAME, state)
end

function PlayerStateService:GetState(player: Player): PlayerState
	local value = player:GetAttribute(ATTRIBUTE_NAME)
	if value == "Combat" then
		return "Combat"
	end
	return "Menu"
end

function PlayerStateService:handleCharacter(Character : Model)
	for _, part in pairs(Character:GetDescendants()) do
		if part:IsA("BasePart") or part:IsA("MeshPart") then
			if part.Name == "HumanoidRootPart" then continue end
			
			part.CollisionGroup = "Players"
		end
	end
end

function PlayerStateService:Initialize()
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute(ATTRIBUTE_NAME) == nil then
			self:SetState(player, "Menu")
		end
	end
	Players.PlayerAdded:Connect(function(player)
		if player:GetAttribute(ATTRIBUTE_NAME) == nil then
			self:SetState(player, "Menu")
		end
		
		player.CharacterAdded:Connect(function(char)
			self:handleCharacter(char)
		end)
	end)
end

return setmetatable({}, PlayerStateService)
