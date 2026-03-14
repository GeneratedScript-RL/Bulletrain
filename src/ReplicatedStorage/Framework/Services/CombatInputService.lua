--!strict

local ContextActionService = game:GetService("ContextActionService")

local ViewmodelService = require(script.Parent.ViewmodelService)

local CombatInputService = {}
CombatInputService.__index = CombatInputService

local ACTION_FIRE = "Combat_Fire"
local ACTION_EQUIP1 = "Combat_Equip1"
local ACTION_EQUIP2 = "Combat_Equip2"
local ACTION_SWITCH = "Combat_Switch"
local ACTION_INSPECT = "INSPECT"
local ACTION_RELOAD = "Combat_Reload"
local ACTION_PARRY = "Combat_Parry"

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

local function Inspect(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		ViewmodelService:Inspect()
	end
	return Enum.ContextActionResult.Sink
end

local function onEquipKnife(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		ViewmodelService:Equip("Knife")
	end
	return Enum.ContextActionResult.Sink
end

local function switch(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Change then
		if ViewmodelService._vm._weapon.Name == "Knife" then
			ViewmodelService:Equip("Shotgun")
		else
			ViewmodelService:Equip("Knife")
		end
	end
	return Enum.ContextActionResult.Sink
end

local function reload(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		ViewmodelService._vm._weapon:Reload()
	end
	return Enum.ContextActionResult.Sink
end

local function onParry(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		ViewmodelService:Parry()
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
	ContextActionService:BindAction(ACTION_SWITCH, switch, false, Enum.UserInputType.MouseWheel)
	ContextActionService:BindAction(ACTION_INSPECT, Inspect, false, Enum.KeyCode.T)
	ContextActionService:BindAction(ACTION_RELOAD, reload, false, Enum.KeyCode.R)
	ContextActionService:BindAction(ACTION_PARRY, onParry, false, Enum.KeyCode.F)
end

function singleton:Disable()
	if not self._enabled then
		return
	end
	self._enabled = false

	ContextActionService:UnbindAction(ACTION_FIRE)
	ContextActionService:UnbindAction(ACTION_EQUIP1)
	ContextActionService:UnbindAction(ACTION_EQUIP2)
	ContextActionService:UnbindAction(ACTION_SWITCH)
	ContextActionService:UnbindAction(ACTION_INSPECT)
	ContextActionService:UnbindAction(ACTION_RELOAD)
	ContextActionService:UnbindAction(ACTION_PARRY)
end

function singleton:Initialize()
	-- No auto-enable; PlayerStateController controls this.
end

return singleton
