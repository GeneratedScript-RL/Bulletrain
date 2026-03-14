--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network.Network)

local AnimationService = require(script.Parent.Parent.Services.AnimationService)

local AvatarAnimationReplicationComponent = {}
AvatarAnimationReplicationComponent.__index = AvatarAnimationReplicationComponent

function AvatarAnimationReplicationComponent:Initialize()
	local player = Players.LocalPlayer :: Player
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	
	player.CharacterAdded:Connect(function(char)
		character = char
		humanoid = char:WaitForChild("Humanoid") :: Humanoid
	end)
	
	Network:SubscribeToPacket("AnimateAvatar"):Connect(function(animName: string, priority: Enum.AnimationPriority?, looped: boolean?)
		AnimationService:PlayAnimation(humanoid, animName, priority or Enum.AnimationPriority.Action, looped)
	end)
end

return setmetatable({}, AvatarAnimationReplicationComponent)
