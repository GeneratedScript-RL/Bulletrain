--!strict

local UserInputService = game:GetService("UserInputService")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local matchService: any
local playerStateService: any

local MatchJoinController = framework.CreateController({
	Name = "MatchJoinController",
})

MatchJoinController._matchRunning = false

function MatchJoinController:Init()
	matchService = framework.GetService("MatchService")
	playerStateService = framework.GetService("PlayerStateService")
end

function MatchJoinController:Start()
	local initialMatchRunning = matchService.MatchRunning:OnReady(5)
	if type(initialMatchRunning) == "boolean" then
		self._matchRunning = initialMatchRunning
	end

	matchService.MatchRunning:Observe(function(isRunning: boolean)
		self._matchRunning = isRunning
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or input.KeyCode ~= Enum.KeyCode.Space or not self._matchRunning then
			return
		end

		if playerStateService.CurrentState:Get() ~= "Menu" then
			return
		end

		matchService.RequestJoin:Fire()
	end)
end

return MatchJoinController
