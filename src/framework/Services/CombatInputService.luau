--!strict

local ContextActionService = game:GetService("ContextActionService")

local ViewmodelService = require(script.Parent.ViewmodelService)

local CombatInputService = {}
CombatInputService.__index = CombatInputService

local ACTION_FIRE = "Combat_Fire"
local ACTION_EQUIP1 = "Combat_Equip1"
local ACTION_EQUIP2 = "Combat_Equip2"

function CombatInputService.new()
	local self = setmetatable({}, CombatInputService)
	self._enabled = false
	return self
end

local singleton = CombatInputService.new()

local function onFire(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		ViewmodelService:PrimaryFire()
	end
	return Enum.ContextActionResult.Sink
end

local function onEquipShotgun(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		ViewmodelService:Equip("Shotgun")
	end
	return Enum.ContextActionResult.Sink
end

local function onEquipKnife(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		ViewmodelService:Equip("Knife")
	end
	return Enum.ContextActionResult.Sink
end

function singleton:Enable()
	if self._enabled then
		return
	end
	self._enabled = true

	ContextActionService:BindAction(ACTION_FIRE, onFire, false, Enum.UserInputType.MouseButton1)
	ContextActionService:BindAction(ACTION_EQUIP1, onEquipShotgun, false, Enum.KeyCode.One)
	ContextActionService:BindAction(ACTION_EQUIP2, onEquipKnife, false, Enum.KeyCode.Two)
end

function singleton:Disable()
	if not self._enabled then
		return
	end
	self._enabled = false

	ContextActionService:UnbindAction(ACTION_FIRE)
	ContextActionService:UnbindAction(ACTION_EQUIP1)
	ContextActionService:UnbindAction(ACTION_EQUIP2)
end

function singleton:Initialize()
	-- No auto-enable; PlayerStateController controls this.
end

return singleton
