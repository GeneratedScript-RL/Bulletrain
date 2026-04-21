--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local root = script.Parent.Parent.Parent.Parent
local CombatConfig = require(root.Systems.CombatService.Shared.Config)
local Spring = require(root.Libraries.Spring.Spring)
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
type ShotgunFired = () -> ()

local DEFAULT_VIEWMODEL_ROTATION = CFrame.Angles(math.rad(180), 0, math.rad(180))
local RENDER_STEP_NAME = "Bulletrain_Viewmodel"
local RECOIL_RENDER_PRIORITY = Enum.RenderPriority.Camera.Value + 1

local function getLerpAlpha(speed: number, deltaTime: number): number
	if speed <= 0 then
		return 1
	end

	return math.clamp(1 - math.exp(-speed * math.max(deltaTime, 0)), 0, 1)
end

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

local function getArmSide(partName: string): string?
	local normalized = string.lower(partName):gsub("[%s_%-]", "")
	if normalized == "leftarm"
		or normalized == "leftupperarm"
		or normalized == "leftlowerarm"
		or normalized == "lefthand"
		or normalized == "larm"
		or normalized == "lhand"
		or string.match(normalized, "^left.*arm$") ~= nil
		or string.match(normalized, "^left.*hand$") ~= nil
	then
		return "Left"
	end

	if normalized == "rightarm"
		or normalized == "rightupperarm"
		or normalized == "rightlowerarm"
		or normalized == "righthand"
		or normalized == "rarm"
		or normalized == "rhand"
		or string.match(normalized, "^right.*arm$") ~= nil
		or string.match(normalized, "^right.*hand$") ~= nil
	then
		return "Right"
	end

	return nil
end

local function findCharacterPartColor(character: Model, names: { string }): Color3?
	for _, partName in names do
		local instance = character:FindFirstChild(partName, true)
		if instance and instance:IsA("BasePart") then
			return instance.Color
		end
	end

	return nil
end

local function getCharacterArmColor(character: Model, side: string): Color3?
	local bodyColors = character:FindFirstChildOfClass("BodyColors") :: BodyColors?
	if bodyColors then
		return if side == "Left" then bodyColors.LeftArmColor3 else bodyColors.RightArmColor3
	end

	if side == "Left" then
		return findCharacterPartColor(character, {
			"Left Arm",
			"LeftUpperArm",
			"LeftLowerArm",
			"LeftHand",
		})
	end

	return findCharacterPartColor(character, {
		"Right Arm",
		"RightUpperArm",
		"RightLowerArm",
		"RightHand",
	})
end

local function clearCharacterAppearanceInstances(model: Model)
	for _, child in model:GetChildren() do
		if child:IsA("BodyColors") or child:IsA("Shirt") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end
end

local function cloneCharacterAppearanceInstances(character: Model, model: Model)
	local bodyColors = character:FindFirstChildOfClass("BodyColors") :: BodyColors?
	if bodyColors then
		bodyColors:Clone().Parent = model
	end

	local shirt = character:FindFirstChildOfClass("Shirt")
	if shirt then
		shirt:Clone().Parent = model
	end

	local shirtGraphic = character:FindFirstChildOfClass("ShirtGraphic")
	if shirtGraphic then
		shirtGraphic:Clone().Parent = model
	end
end

function Viewmodel.new(
	localPlayer: Player,
	camera: Camera,
	animationController: any,
	combatService: any,
	onReloadStateChanged: ReloadStateChanged?,
	onShotgunFired: ShotgunFired?
)
	local self = setmetatable({}, Viewmodel)
	self._player = localPlayer
	self._camera = camera
	self._animationController = animationController
	self._combatService = combatService
	self._onReloadStateChanged = onReloadStateChanged
	self._onShotgunFired = onShotgunFired
	self._vmModel = nil :: Model?
	self._weapon = nil :: Weapon?
	self._renderStepBound = false
	self._equippedKnifeSkinConnection = nil :: RBXScriptConnection?
	self._equippedShotgunSkinConnection = nil :: RBXScriptConnection?
	self._characterAddedConnection = nil :: RBXScriptConnection?
	self._characterAppearanceLoadedConnection = nil :: RBXScriptConnection?
	self._sightsAttachment = nil :: Attachment?
	self._aimRequested = false
	self._isAiming = false
	self._aimTransitionAlpha = 0
	self._cameraRecoilSpring = Spring.new(
		Vector2.zero,
		CombatConfig.Shotgun.CameraRecoil.Damping,
		CombatConfig.Shotgun.CameraRecoil.Speed
	)

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

	self._characterAddedConnection = localPlayer.CharacterAdded:Connect(function()
		task.defer(function()
			self:_applyCharacterAppearance()
		end)
	end)

	self._characterAppearanceLoadedConnection = localPlayer.CharacterAppearanceLoaded:Connect(function()
		self:_applyCharacterAppearance()
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

function Viewmodel:_applyCharacterAppearance()
	local vmModel = self._vmModel
	local character = self._player.Character
	if not vmModel or not character then
		return
	end

	clearCharacterAppearanceInstances(vmModel)
	cloneCharacterAppearanceInstances(character, vmModel)

	local leftArmColor = getCharacterArmColor(character, "Left")
	local rightArmColor = getCharacterArmColor(character, "Right")

	for _, descendant in vmModel:GetDescendants() do
		if descendant:IsA("BasePart") then
			local side = getArmSide(descendant.Name)
			if side == "Left" and leftArmColor then
				descendant.Color = leftArmColor
			elseif side == "Right" and rightArmColor then
				descendant.Color = rightArmColor
			end
		end
	end
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
	local defaultPivot = self:_getDefaultPivot()
	clone:PivotTo(defaultPivot)
	self._vmModel = clone
	self:_refreshSightsAttachment()
	self:_applyCharacterAppearance()
	self._aimTransitionAlpha = if self._isAiming then 1 else 0
	clone:PivotTo(self:_getBlendedViewmodelPivot())
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
	if self._renderStepBound then
		return
	end

	self._renderStepBound = true
	RunService:BindToRenderStep(RENDER_STEP_NAME, RECOIL_RENDER_PRIORITY, function(deltaTime: number)
		self:_updateCameraRecoil()

		if self._vmModel then
			self:_updateViewmodelPivot(deltaTime)
		end
	end)
end

function Viewmodel:_getBlendedViewmodelPivot(): CFrame
	local defaultPivot = self:_getDefaultPivot()
	local aimAlpha = self._aimTransitionAlpha
	if aimAlpha <= 0 then
		return defaultPivot
	end

	local aimPivot = self:_getAimPivot()
	if not aimPivot then
		return defaultPivot
	end

	return defaultPivot:Lerp(aimPivot, aimAlpha)
end

function Viewmodel:_updateViewmodelPivot(deltaTime: number)
	local vmModel = self._vmModel
	if not vmModel then
		return
	end

	local targetAimAlpha = if self._isAiming then 1 else 0
	local alpha = getLerpAlpha(CombatConfig.Shotgun.AimLerpSpeed, deltaTime)
	self._aimTransitionAlpha = math.clamp(
		self._aimTransitionAlpha + (targetAimAlpha - self._aimTransitionAlpha) * alpha,
		0,
		1
	)

	vmModel:PivotTo(self:_getBlendedViewmodelPivot())
end

function Viewmodel:_updateCameraRecoil()
	local recoilOffset = self._cameraRecoilSpring.Position
	if recoilOffset.Magnitude <= 0 then
		return
	end

	self._camera.CFrame = self._camera.CFrame * CFrame.Angles(recoilOffset.X, recoilOffset.Y, 0)
end

function Viewmodel:_applyShotgunRecoil()
	local recoilConfig = CombatConfig.Shotgun.CameraRecoil
	local multiplier = if self._isAiming then recoilConfig.AimMultiplier else 1
	local pitch = math.rad(recoilConfig.PitchDegrees) * multiplier
	local yaw = math.rad((math.random() - 0.5) * 2 * recoilConfig.YawDegrees) * multiplier
	local recoilSpring = self._cameraRecoilSpring

	recoilSpring.Damping = recoilConfig.Damping
	recoilSpring.Speed = recoilConfig.Speed
	recoilSpring.Target = Vector2.zero
	recoilSpring.Position = recoilSpring.Position + Vector2.new(pitch, yaw)
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
			self._onReloadStateChanged,
			function()
				self:_applyShotgunRecoil()
				if self._onShotgunFired then
					self._onShotgunFired()
				end
			end
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

	if self._renderStepBound then
		RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
		self._renderStepBound = false
	end

	if self._equippedKnifeSkinConnection then
		self._equippedKnifeSkinConnection:Disconnect()
		self._equippedKnifeSkinConnection = nil
	end

	if self._equippedShotgunSkinConnection then
		self._equippedShotgunSkinConnection:Disconnect()
		self._equippedShotgunSkinConnection = nil
	end

	if self._characterAddedConnection then
		self._characterAddedConnection:Disconnect()
		self._characterAddedConnection = nil
	end

	if self._characterAppearanceLoadedConnection then
		self._characterAppearanceLoadedConnection:Disconnect()
		self._characterAppearanceLoadedConnection = nil
	end

	if self._weapon then
		self._weapon:Destroy()
		self._weapon = nil
	end

	self._sightsAttachment = nil
	self._aimTransitionAlpha = 0

	if self._vmModel then
		self._vmModel:Destroy()
		self._vmModel = nil
	end
end

return Viewmodel
