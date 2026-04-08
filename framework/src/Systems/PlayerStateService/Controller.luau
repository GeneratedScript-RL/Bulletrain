--!strict

local Players = game:GetService("Players")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local combatInputController: any
local slideController: any
local viewmodelController: any
local playerStateService: any

local PlayerStateController = framework.CreateController({
	Name = "PlayerStateController",
	Dependencies = { "CombatInputController", "SlideController", "ViewmodelController" },
})

PlayerStateController._currentState = nil :: string?

function PlayerStateController:_applyState(state: string)
	if self._currentState == state then
		return
	end

	self._currentState = state

	local player = Players.LocalPlayer
	if state == "Combat" then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		viewmodelController:Enable()
		combatInputController:Enable()
		slideController:Enable()
	else
		player.CameraMode = Enum.CameraMode.Classic
		slideController:Disable()
		combatInputController:Disable()
		viewmodelController:Disable()
	end
end

function PlayerStateController:Init()
	combatInputController = framework.GetController("CombatInputController")
	slideController = framework.GetController("SlideController")
	viewmodelController = framework.GetController("ViewmodelController")
	playerStateService = framework.GetService("PlayerStateService")
end

function PlayerStateController:Start()
	local initialState = playerStateService.CurrentState:OnReady(5) or "Menu"
	self:_applyState(initialState)

	playerStateService.CurrentState:Observe(function(state: string)
		self:_applyState(state)
	end)
end

return PlayerStateController
