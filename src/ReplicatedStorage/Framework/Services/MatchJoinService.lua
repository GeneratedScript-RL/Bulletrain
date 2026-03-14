--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network.Network)

local MatchJoinService = {}
MatchJoinService.__index = MatchJoinService

local ATTRIBUTE_NAME = "State"

function MatchJoinService.new()
	local self = setmetatable({}, MatchJoinService)
	self._matchRunning = false
	return self
end

local singleton = MatchJoinService.new()

local function getState(): string
	return (Players.LocalPlayer:GetAttribute(ATTRIBUTE_NAME) :: any) or "Menu"
end

function singleton:Initialize()
	Network:SubscribeToPacket("MatchStarted"):Connect(function(_data)
		self._matchRunning = true
	end)
	Network:SubscribeToPacket("MatchEnded"):Connect(function(_data)
		self._matchRunning = false
	end)
	Network:SubscribeToPacket("Intermission"):Connect(function(_data)
		self._matchRunning = false
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode ~= Enum.KeyCode.Space then
			return
		end
		if not self._matchRunning then
			return
		end
		if getState() ~= "Menu" then
			return
		end
		Network:FireRemoteToServer("RequestJoinMatch")
	end)
end

return singleton
