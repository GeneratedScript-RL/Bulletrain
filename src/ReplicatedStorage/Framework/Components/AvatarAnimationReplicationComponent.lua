--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network.Network)

local AnimationService = require(script.Parent.Parent.Services.AnimationService)

local AvatarAnimationReplicationComponent = {}
AvatarAnimationReplicationComponent.__index = AvatarAnimationReplicationComponent

local function findPlayerByUserId(userId: number): Player?
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == userId then
			return p
		end
	end
	return nil
end

function AvatarAnimationReplicationComponent:Initialize()
	local player = Players.LocalPlayer :: Player
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	
	player.CharacterAdded:Connect(function(char)
		character = char
		humanoid = char:WaitForChild("Humanoid")
	end)
	
	Network:SubscribeToPacket("AnimateAvatar"):Connect(function(animName: string, priority: Enum.AnimationPriority?, fadeTime: number?)
		AnimationService:PlayAnimation(humanoid, animName, priority or Enum.AnimationPriority.Action, fadeTime)
	end)
end

return setmetatable({}, AvatarAnimationReplicationComponent)
