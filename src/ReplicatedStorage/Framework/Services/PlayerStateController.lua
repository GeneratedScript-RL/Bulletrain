--!strict

local Players = game:GetService("Players")

local ViewmodelService = require(script.Parent.ViewmodelService)
local CombatInputService = require(script.Parent.CombatInputService)
local SlideService = require(script.Parent.SlideService)

local PlayerStateController = {}
PlayerStateController.__index = PlayerStateController

local ATTRIBUTE_NAME = "State"

local function getState(player: Player): string
	return (player:GetAttribute(ATTRIBUTE_NAME) :: any) or "Menu"
end

function PlayerStateController:_applyState(state: string)
	local player = Players.LocalPlayer

	if state == "Combat" then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		ViewmodelService:Enable()
		CombatInputService:Enable()
		SlideService:Enable()
	else
		player.CameraMode = Enum.CameraMode.Classic
		SlideService:Disable()
		CombatInputService:Disable()
		ViewmodelService:Disable()
	end
end

function PlayerStateController:Initialize()
	local player = Players.LocalPlayer
	self:_applyState(getState(player))

	player:GetAttributeChangedSignal(ATTRIBUTE_NAME):Connect(function()
		self:_applyState(getState(player))
	end)
end

return setmetatable({}, PlayerStateController)
