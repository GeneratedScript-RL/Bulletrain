--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local root = script.Parent.Parent.Parent.Parent
local CombatConfig = require(root.Systems.CombatService.Shared.Config)
local Shotgun = require(script.Parent.Weapons.Shotgun)
local Knife = require(script.Parent.Weapons.Knife)

export type Weapon = {
	Name: string,
	PrimaryFire: (self: Weapon) -> (),
	Inspect: (self: Weapon) -> (),
	Reload: (self: Weapon) -> (),
	Parry: (self: Weapon) -> (),
	CanAim: (self: Weapon) -> boolean,
	SetAiming: (self: Weapon, isAiming: boolean) -> (),
	Destroy: (self: Weapon) -> (),
}

local Viewmodel = {}
Viewmodel.__index = Viewmodel

type ReloadStateChanged = (isReloading: boolean, progress: number, tweenDuration: number?) -> ()

local DEFAULT_VIEWMODEL_ROTATION = CFrame.Angles(math.rad(180), 0, math.rad(180))

local function getAssetsFolder(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets and assets:IsA("Folder") then
		return assets
	end

	return nil
end

local function setModelNoCollide(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Anchored = true
		end
	end
end

function Viewmodel.new(
	localPlayer: Player,
	camera: Camera,
	animationController: any,
	combatService: any,
	onReloadStateChanged: ReloadStateChanged?
)
	local self = setmetatable({}, Viewmodel)
	self._player = localPlayer
	self._camera = camera
	self._animationController = animationController
	self._combatService = combatService
	self._onReloadStateChanged = onReloadStateChanged
	self._vmModel = nil :: Model?
	self._weapon = nil :: Weapon?
	self._connection = nil :: RBXScriptConnection?
	self._equippedKnifeSkinConnection = nil :: RBXScriptConnection?
	self._equippedShotgunSkinConnection = nil :: RBXScriptConnection?
	self._sightsAttachment = nil :: Attachment?
	self._aimRequested = false
	self._isAiming = false

	self._equippedKnifeSkinConnection = localPlayer:GetAttributeChangedSignal("EquippedKnifeSkin"):Connect(function()
		local weapon = self._weapon
		if weapon and weapon.Name == "Knife" then
			self:Equip("Knife", true)
		end
	end)

	self._equippedShotgunSkinConnection = localPlayer:GetAttributeChangedSignal("EquippedShotgunSkin"):Connect(function()
		local weapon = self._weapon
		if weapon and weapon.Name == "Shotgun" then
			self:Equip("Shotgun", true)
		end
	end)

	return self
end

function Viewmodel:_getDefaultPivot(): CFrame
	return self._camera.CFrame * DEFAULT_VIEWMODEL_ROTATION
end

function Viewmodel:_refreshSightsAttachment()
	self._sightsAttachment = nil

	local vmModel = self._vmModel
	if not vmModel then
		return
	end

	local attachment = vmModel:FindFirstChild("Sights", true)
	if attachment and attachment:IsA("Attachment") then
		self._sightsAttachment = attachment
	end
end

function Viewmodel:_getAimPivot(): CFrame?
	local vmModel = self._vmModel
	local sightsAttachment = self._sightsAttachment
	if not vmModel or not sightsAttachment or not sightsAttachment:IsDescendantOf(vmModel) then
		return nil
	end

	local targetSightCFrame = self._camera.CFrame * CFrame.new(0, 0, -CombatConfig.Shotgun.AimSightsDistance)
	local sightOffset = vmModel:GetPivot():ToObjectSpace(sightsAttachment.WorldCFrame)
	return targetSightCFrame * sightOffset:Inverse()
end

function Viewmodel:_resolveAimState(): boolean
	local weapon = self._weapon
	return self._aimRequested and weapon ~= nil and weapon:CanAim()
end

function Viewmodel:_applyAimState()
	local resolvedAiming = self:_resolveAimState()
	if self._isAiming == resolvedAiming then
		return
	end

	self._isAiming = resolvedAiming

	if self._weapon then
		self._weapon:SetAiming(resolvedAiming)
	end
end

function Viewmodel:_ensureModelForWeapon(weaponName: string)
	if self._vmModel then
		self._vmModel:Destroy()
		self._vmModel = nil
	end

	local assets = getAssetsFolder()
	if not assets then
		warn("[Viewmodel] ReplicatedStorage.Assets missing")
		return
	end

	local viewmodels = assets:FindFirstChild("Viewmodels")
	if not viewmodels or not viewmodels:IsA("Folder") then
		warn("[Viewmodel] Assets.Viewmodels missing")
		return
	end

	local folderName = if weaponName == "Knife" then "Knifes" else "Shotguns"
	local weaponFolder = viewmodels:FindFirstChild(folderName)
	if not weaponFolder or not weaponFolder:IsA("Folder") then
		warn(("[Viewmodel] Assets.Viewmodels.%s missing"):format(folderName))
		return
	end

	local equippedAttribute = if weaponName == "Knife" then "EquippedKnifeSkin" else "EquippedShotgunSkin"
	local equippedSkin = self._player:GetAttribute(equippedAttribute)

	local template: Instance? = nil
	if type(equippedSkin) == "string" then
		local byName = weaponFolder:FindFirstChild(equippedSkin)
		if byName and byName:IsA("Model") then
			template = byName
		end
	end

	if not template then
		local defaultTemplate = weaponFolder:FindFirstChild("Default")
		if defaultTemplate and defaultTemplate:IsA("Model") then
			template = defaultTemplate
		end
	end

	if not template then
		for _, child in ipairs(weaponFolder:GetChildren()) do
			if child:IsA("Model") then
				template = child
				break
			end
		end
	end

	if not template or not template:IsA("Model") then
		warn(("[Viewmodel] No viewmodel model found in %s"):format(weaponFolder:GetFullName()))
		return
	end

	local clone = template:Clone()
	clone.Name = "Viewmodel"
	setModelNoCollide(clone)
	clone.Parent = self._camera
	clone:PivotTo(self:_getDefaultPivot())
	self._vmModel = clone
	self:_refreshSightsAttachment()
end

function Viewmodel:GetAnimationTarget(): Instance?
	local vmModel = self._vmModel
	if not vmModel then
		return nil
	end

	local controller = vmModel:FindFirstChildOfClass("AnimationController")
	if controller then
		return controller
	end

	return vmModel:FindFirstChildOfClass("Humanoid")
end

function Viewmodel:GetEquippedWeaponName(): string?
	local weapon = self._weapon
	if weapon then
		return weapon.Name
	end

	return nil
end

function Viewmodel:Start()
	if self._connection then
		return
	end

	self._connection = RunService.RenderStepped:Connect(function()
		if self._vmModel then
			local targetPivot = self:_getDefaultPivot()
			if self._isAiming then
				local aimPivot = self:_getAimPivot()
				if aimPivot then
					targetPivot = aimPivot
				end
			end

			self._vmModel:PivotTo(targetPivot)
		end
	end)
end

function Viewmodel:Equip(weaponName: string, force: boolean?)
	if not force and self:GetEquippedWeaponName() == weaponName then
		return
	end

	if self._onReloadStateChanged then
		self._onReloadStateChanged(false, 0, 0)
	end

	if self._weapon then
		self._weapon:Destroy()
		self._weapon = nil
	end

	self:_ensureModelForWeapon(weaponName)
	if not self._vmModel then
		return
	end

	if weaponName == "Knife" then
		self._weapon = Knife.new(self._player, self._camera, self._vmModel, self._animationController, self._combatService)
	else
		self._weapon = Shotgun.new(
			self._player,
			self._camera,
			self._vmModel,
			self._animationController,
			self._combatService,
			self._onReloadStateChanged
		)
	end

	self:_applyAimState()
end

function Viewmodel:PrimaryFire()
	if self._weapon then
		self._weapon:PrimaryFire()
	end
end

function Viewmodel:Inspect()
	if self._weapon then
		self._weapon:Inspect()
	end
end

function Viewmodel:Reload()
	if self._weapon then
		if self._aimRequested then
			self:SetAiming(false)
		end

		self._weapon:Reload()
	end
end

function Viewmodel:Parry()
	if self._weapon then
		self._weapon:Parry()
	end
end

function Viewmodel:SetAiming(isAiming: boolean)
	if self._aimRequested == isAiming then
		return
	end

	self._aimRequested = isAiming
	self:_applyAimState()
end

function Viewmodel:CanAim(): boolean
	local weapon = self._weapon
	if not weapon then
		return false
	end

	return weapon:CanAim()
end

function Viewmodel:Destroy()
	if self._onReloadStateChanged then
		self._onReloadStateChanged(false, 0, 0)
	end

	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end

	if self._equippedKnifeSkinConnection then
		self._equippedKnifeSkinConnection:Disconnect()
		self._equippedKnifeSkinConnection = nil
	end

	if self._equippedShotgunSkinConnection then
		self._equippedShotgunSkinConnection:Disconnect()
		self._equippedShotgunSkinConnection = nil
	end

	if self._weapon then
		self._weapon:Destroy()
		self._weapon = nil
	end

	self._sightsAttachment = nil

	if self._vmModel then
		self._vmModel:Destroy()
		self._vmModel = nil
	end
end

return Viewmodel
