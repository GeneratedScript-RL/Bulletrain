--!strict

local Players = game:GetService("Players")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local Viewmodel = require(script.Parent.Shared.Viewmodel)

local ViewmodelController = framework.CreateController({
	Name = "ViewmodelController",
	Dependencies = { "AnimationController" },
})

local function clearCameraViewmodels(camera: Camera?)
	if not camera then
		return
	end

	for _, child in camera:GetChildren() do
		if child:IsA("Model") and child.Name == "Viewmodel" then
			child:Destroy()
		end
	end
end

ViewmodelController._enabled = false
ViewmodelController._vm = nil :: any
ViewmodelController._animationController = nil :: any
ViewmodelController._combatService = nil :: any

function ViewmodelController:Enable()
	if self._enabled then
		return
	end

	self._enabled = true

	if self._vm then
		self._vm:Destroy()
		self._vm = nil
	end

	local camera = workspace.CurrentCamera
	if not camera then
		warn("[ViewmodelController] CurrentCamera missing")
		self._enabled = false
		return
	end

	clearCameraViewmodels(camera)

	self._vm = Viewmodel.new(Players.LocalPlayer, camera, self._animationController, self._combatService)
	self._vm:Equip("Shotgun")
	self._vm:Start()
end

function ViewmodelController:Disable()
	self._enabled = false

	if self._vm then
		self._vm:Destroy()
		self._vm = nil
	end

	clearCameraViewmodels(workspace.CurrentCamera)
end

function ViewmodelController:IsEnabled(): boolean
	return self._enabled
end

function ViewmodelController:HasViewmodel(): boolean
	return self._vm ~= nil
end

function ViewmodelController:GetAnimationTarget(): Instance?
	if not self._vm then
		return nil
	end

	return self._vm:GetAnimationTarget()
end

function ViewmodelController:GetEquippedWeaponName(): string?
	if not self._vm then
		return nil
	end

	return self._vm:GetEquippedWeaponName()
end

function ViewmodelController:PrimaryFire()
	if self._vm then
		self._vm:PrimaryFire()
	end
end

function ViewmodelController:Inspect()
	if self._vm then
		self._vm:Inspect()
	end
end

function ViewmodelController:Reload()
	if self._vm then
		self._vm:Reload()
	end
end

function ViewmodelController:Parry()
	if self._vm then
		self._vm:Parry()
	end
end

function ViewmodelController:Equip(name: string)
	if self._vm then
		self._vm:Equip(name)
	end
end

function ViewmodelController:Init()
	self._animationController = framework.GetController("AnimationController")
	self._combatService = framework.GetService("CombatService")
end

return ViewmodelController
