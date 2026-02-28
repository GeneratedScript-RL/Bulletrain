--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network.Network)

local AnimationService = require(script.Parent.Parent.Services.AnimationService)
local ViewmodelService = require(script.Parent.Parent.Services.ViewmodelService)

local ViewmodelAnimationReplicationComponent = {}
ViewmodelAnimationReplicationComponent.__index = ViewmodelAnimationReplicationComponent

function ViewmodelAnimationReplicationComponent:Initialize()
	Network:SubscribeToPacket("AnimateViewmodel"):Connect(function(animName: string, priority: Enum.AnimationPriority?, fadeTime: number?)
		local target = ViewmodelService:GetAnimationTarget()
		if not target then
			return
		end
		AnimationService:PlayAnimation(target, animName, priority or Enum.AnimationPriority.Action, fadeTime)
	end)
end

return setmetatable({}, ViewmodelAnimationReplicationComponent)
