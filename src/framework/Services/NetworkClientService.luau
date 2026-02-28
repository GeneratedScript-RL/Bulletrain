--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network.Network)

local NetworkClientService = {}
NetworkClientService.__index = NetworkClientService

function NetworkClientService:Initialize()
	Network:Init()
end

return setmetatable({}, NetworkClientService)
