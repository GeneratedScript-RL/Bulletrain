--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network.Network)

local Knife = {}
Knife.__index = Knife

Knife.Name = "Knife"

function Knife.new(localPlayer: Player, camera: Camera)
	local self = setmetatable({}, Knife)
	self._player = localPlayer
	self._camera = camera
	return self
end

function Knife:PrimaryFire()
	Network:FireRemoteToServer("KnifeSwing")
end

function Knife:Destroy() end

return Knife
