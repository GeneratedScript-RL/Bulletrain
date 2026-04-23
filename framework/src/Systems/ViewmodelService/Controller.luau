--!strict

local Players = game:GetService("Players")

local root = script.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local Viewmodel = require(script.Parent.Shared.Viewmodel)
local Signal = Dependencies.GetSignal()

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
ViewmodelController._equippedWeaponName = nil :: string?
ViewmodelController._isAiming = false
ViewmodelController._aimBlocked = false
ViewmodelController.WeaponChanged = nil :: any
ViewmodelController.ShotgunFired = nil :: any

function ViewmodelController:_setEquippedWeaponName(weaponName: string?)
	if self._equippedWeaponName == weaponName then
		return
	end

	self._equippedWeaponName = weaponName
	if self.WeaponChanged then
		self.WeaponChanged:Fire(weaponName)
	end
end

function ViewmodelController:Enable()
	if self._enabled then
		return
	end

	self._enabled = true
	self._aimBlocked = false

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

	self._vm = Viewmodel.new(
		Players.LocalPlayer,
		camera,
		self._animationController,
		self._combatService,
		function()
			if self.ShotgunFired then
				self.ShotgunFired:Fire()
			end
		end
	)
	self._vm:Equip("Shotgun")
	self._vm:SetAiming(self._isAiming)
	self._vm:Start()
	self:_setEquippedWeaponName(self._vm:GetEquippedWeaponName())
end

function ViewmodelController:Disable()
	self._enabled = false
	self._isAiming = false
	self._aimBlocked = false

	if self._vm then
		self._vm:Destroy()
		self._vm = nil
	end

	clearCameraViewmodels(workspace.CurrentCamera)
	self:_setEquippedWeaponName(nil)
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
		return self._equippedWeaponName
	end

	return self._vm:GetEquippedWeaponName()
end

function ViewmodelController:IsAiming(): boolean
	return self._isAiming
end

function ViewmodelController:CanAim(): boolean
	if not self._vm or self._aimBlocked then
		return false
	end

	return self._vm:CanAim()
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

function ViewmodelController:Parry()
	if self._vm then
		self._vm:Parry()
	end
end

function ViewmodelController:Equip(name: string, force: boolean?)
	if self._vm then
		if not force and self._vm:GetEquippedWeaponName() == name then
			return
		end

		self._vm:Equip(name, force)
		self._vm:SetAiming(self._isAiming)
		self:_setEquippedWeaponName(self._vm:GetEquippedWeaponName())
	end
end

function ViewmodelController:SetAiming(isAiming: boolean)
	if isAiming and not self:CanAim() then
		return
	end

	if self._isAiming == isAiming then
		return
	end

	self._isAiming = isAiming

	if self._vm then
		self._vm:SetAiming(isAiming)
	end
end

function ViewmodelController:SetAimBlocked(isBlocked: boolean)
	if self._aimBlocked == isBlocked then
		return
	end

	self._aimBlocked = isBlocked

	if isBlocked and self._isAiming then
		self:SetAiming(false)
	end
end

function ViewmodelController:Init()
	self._animationController = framework.GetController("AnimationController")
	self._combatService = framework.GetService("CombatService")
	self.WeaponChanged = Signal.new()
	self.ShotgunFired = Signal.new()
end

return ViewmodelController
