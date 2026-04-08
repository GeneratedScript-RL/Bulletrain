--!strict

local ContextActionService = game:GetService("ContextActionService")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local viewmodelController: any

local CombatInputController = framework.CreateController({
	Name = "CombatInputController",
	Dependencies = { "ViewmodelController" },
})

CombatInputController._enabled = false

local ACTION_FIRE = "Combat_Fire"
local ACTION_EQUIP1 = "Combat_Equip1"
local ACTION_EQUIP2 = "Combat_Equip2"
local ACTION_SWITCH = "Combat_Switch"
local ACTION_INSPECT = "Combat_Inspect"
local ACTION_RELOAD = "Combat_Reload"
local ACTION_PARRY = "Combat_Parry"

local function onFire(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		viewmodelController:PrimaryFire()
	end

	return Enum.ContextActionResult.Sink
end

local function onEquipShotgun(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		viewmodelController:Equip("Shotgun")
	end

	return Enum.ContextActionResult.Sink
end

local function onInspect(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		viewmodelController:Inspect()
	end

	return Enum.ContextActionResult.Sink
end

local function onEquipKnife(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		viewmodelController:Equip("Knife")
	end

	return Enum.ContextActionResult.Sink
end

local function onSwitch(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Change then
		if viewmodelController:GetEquippedWeaponName() == "Knife" then
			viewmodelController:Equip("Shotgun")
		else
			viewmodelController:Equip("Knife")
		end
	end

	return Enum.ContextActionResult.Sink
end

local function onReload(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		viewmodelController:Reload()
	end

	return Enum.ContextActionResult.Sink
end

local function onParry(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		viewmodelController:Parry()
	end

	return Enum.ContextActionResult.Sink
end

function CombatInputController:Enable()
	if self._enabled then
		return
	end

	self._enabled = true
	ContextActionService:BindAction(ACTION_FIRE, onFire, false, Enum.UserInputType.MouseButton1)
	ContextActionService:BindAction(ACTION_EQUIP1, onEquipShotgun, false, Enum.KeyCode.One)
	ContextActionService:BindAction(ACTION_EQUIP2, onEquipKnife, false, Enum.KeyCode.Two)
	ContextActionService:BindAction(ACTION_SWITCH, onSwitch, false, Enum.UserInputType.MouseWheel)
	ContextActionService:BindAction(ACTION_INSPECT, onInspect, false, Enum.KeyCode.T)
	ContextActionService:BindAction(ACTION_RELOAD, onReload, false, Enum.KeyCode.R)
	ContextActionService:BindAction(ACTION_PARRY, onParry, false, Enum.KeyCode.F)
end

function CombatInputController:Disable()
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

function CombatInputController:Init()
	viewmodelController = framework.GetController("ViewmodelController")
end

return CombatInputController
