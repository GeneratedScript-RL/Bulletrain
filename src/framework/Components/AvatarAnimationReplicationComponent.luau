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
	Network:SubscribeToPacket("AnimateAvatar"):Connect(function(userId: number, animName: string, priority: Enum.AnimationPriority?, fadeTime: number?)
		local player = findPlayerByUserId(userId)
		if not player or not player.Character then
			return
		end
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		AnimationService:PlayAnimation(humanoid, animName, priority or Enum.AnimationPriority.Action, fadeTime)
	end)
end

return setmetatable({}, AvatarAnimationReplicationComponent)
