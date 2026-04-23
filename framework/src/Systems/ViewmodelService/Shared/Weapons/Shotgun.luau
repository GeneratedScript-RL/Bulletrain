--!strict

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local root = script.Parent.Parent.Parent.Parent.Parent
local FastCast = require(root.Shared.ThirdParty.FastCast)
local CombatConfig = require(root.Systems.CombatService.Shared.Config)

local Shotgun = {}
Shotgun.__index = Shotgun

Shotgun.Name = "Shotgun"

type FireSucceeded = () -> ()

local function applySpread(direction: Vector3, spreadDegrees: number): Vector3
	local spreadRadians = math.rad(spreadDegrees)
	local yaw = (math.random() - 0.5) * 2 * spreadRadians
	local pitch = (math.random() - 0.5) * 2 * spreadRadians
	local base = CFrame.lookAt(Vector3.zero, direction)
	return (base * CFrame.Angles(pitch, yaw, 0)).LookVector
end

local function getSpreadDegrees(isAiming: boolean): number
	local spreadMultiplier = if isAiming then CombatConfig.Shotgun.AimSpreadMultiplier else 1
	return CombatConfig.Shotgun.SpreadDegrees * spreadMultiplier
end

local function findAttachmentByName(container: Instance, targetName: string): Attachment?
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("Attachment") and string.lower(descendant.Name) == string.lower(targetName) then
			return descendant
		end
	end

	return nil
end

local function findDescendantByName(container: Instance, targetName: string): Instance?
	for _, descendant in container:GetDescendants() do
		if string.lower(descendant.Name) == string.lower(targetName) then
			return descendant
		end
	end

	return nil
end

function Shotgun.new(
	localPlayer: Player,
	camera: Camera,
	viewmodel: Model,
	animationController: any,
	combatService: any,
	onFireSucceeded: FireSucceeded?
)
	local self = setmetatable({}, Shotgun)
	self._player = localPlayer
	self._camera = camera
	self._animationController = animationController
	self._combatService = combatService
	self._onFireSucceeded = onFireSucceeded
	self._caster = FastCast.new()
	self._behavior = FastCast.newBehavior()
	self._behavior.MaxDistance = CombatConfig.Shotgun.Range
	self._viewmodel = viewmodel
	self.Animator = viewmodel:FindFirstChildWhichIsA("AnimationController") :: AnimationController
	self.character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	self.OnCooldown = false
	self._isAiming = false
	self._muzzleAttachment = nil :: Attachment?
	self._runConnection = nil :: RBXScriptConnection?
	self._characterAddedConnection = nil :: RBXScriptConnection?
	self._cosmeticFolder = nil :: Folder?
	self.IdleTrack = nil :: AnimationTrack?
	self.IdleTrackAvatar = nil :: AnimationTrack?
	self.RunTrack = nil :: AnimationTrack?
	self.RunTrackAvatar = nil :: AnimationTrack?
	self.InspectTrack = nil :: AnimationTrack?
	self.FireTrack = nil :: AnimationTrack?
	self.FireTrackAvatar = nil :: AnimationTrack?

	self.InspectTrack = animationController:GetAnimation(self.Animator, "ShotgunInspect", Enum.AnimationPriority.Action2)
	self.IdleTrack = animationController:PlayAnimation(self.Animator, "ShotgunIdle", Enum.AnimationPriority.Action, true)
	self.RunTrack = animationController:GetAnimation(self.Animator, "ShotgunRun", Enum.AnimationPriority.Action2, true)
	self:_refreshAvatarTracks()

	self._runConnection = RunService.RenderStepped:Connect(function()
		self:_updateRunAnimation()
	end)

	self._characterAddedConnection = localPlayer.CharacterAdded:Connect(function(newCharacter)
		self.character = newCharacter
		self:_refreshAvatarTracks()
	end)

	self._cosmeticFolder = Instance.new("Folder")
	self._cosmeticFolder.Name = "ShotgunCosmetics"
	self._cosmeticFolder.Parent = camera

	self._behavior.CosmeticBulletContainer = self._cosmeticFolder
	self._behavior.CosmeticBulletTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Bullet")

	self._caster.LengthChanged:Connect(function(_cast, lastPoint: Vector3, rayDirection: Vector3, rayDisplacement: number, _segmentVelocity: Vector3, bullet: Instance?)
		if bullet and bullet:IsA("BasePart") then
			bullet.CFrame = CFrame.new(lastPoint, lastPoint + rayDirection) * CFrame.new(0, 0, -rayDisplacement / 2)
		end
	end)

	self._caster.RayHit:Connect(function(_activeCast, _result, _velocity, bullet)
		if bullet and bullet:IsA("BasePart") then
			Debris:AddItem(bullet, 1)
		end
	end)

	self:_refreshMuzzleAttachment()

	return self
end

function Shotgun:_getCharacterHumanoid(): Humanoid?
	local character = self.character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

function Shotgun:_refreshAvatarTracks()
	if self.IdleTrackAvatar then
		self.IdleTrackAvatar:Stop()
	end

	if self.RunTrackAvatar then
		self.RunTrackAvatar:Stop()
	end

	self.IdleTrackAvatar = self._animationController:PlayAnimationToAvatar("ShotgunIdle", Enum.AnimationPriority.Action, true)

	local humanoid = self:_getCharacterHumanoid()
	if humanoid then
		self.RunTrackAvatar = self._animationController:GetAnimation(humanoid, "ShotgunRun", Enum.AnimationPriority.Action2, true)
	end
end

function Shotgun:_stopTrack(track: AnimationTrack?)
	if track and track.IsPlaying then
		track:Stop()
	end
end

function Shotgun:_stopNonIdleAnimations()
	self:_stopTrack(self.RunTrack)
	self:_stopTrack(self.RunTrackAvatar)
	self:_stopTrack(self.InspectTrack)
	self:_stopTrack(self.FireTrack)
	self:_stopTrack(self.FireTrackAvatar)
end

function Shotgun:_refreshMuzzleAttachment()
	self._muzzleAttachment = nil

	local shotgunNode = findDescendantByName(self._viewmodel, "ShotGun")
	if not shotgunNode then
		shotgunNode = findDescendantByName(self._viewmodel, "Shotgun")
	end

	if shotgunNode then
		local exactMisspelled = shotgunNode:FindFirstChild("Attatchment", true)
		if exactMisspelled and exactMisspelled:IsA("Attachment") then
			self._muzzleAttachment = exactMisspelled
			return
		end

		local exactCorrect = shotgunNode:FindFirstChild("Attachment", true)
		if exactCorrect and exactCorrect:IsA("Attachment") then
			self._muzzleAttachment = exactCorrect
			return
		end
	end

	self._muzzleAttachment = findAttachmentByName(self._viewmodel, "Attatchment")
	if self._muzzleAttachment then
		return
	end

	self._muzzleAttachment = findAttachmentByName(self._viewmodel, "Attachment")
end

function Shotgun:_getFireOriginAndDirection(): (Vector3, Vector3)
	local origin = (self._camera.CFrame * CFrame.new(2, -1, -2.5)).Position
	local cameraLook = self._camera.CFrame.LookVector
	local targetPoint = self._camera.CFrame.Position + (cameraLook * CombatConfig.Shotgun.Range)
	local muzzleAttachment = self._muzzleAttachment

	if muzzleAttachment and muzzleAttachment:IsDescendantOf(self._viewmodel) then
		origin = muzzleAttachment.WorldPosition
	end

	local directionOffset = targetPoint - origin
	local direction = cameraLook
	if directionOffset.Magnitude > 0 then
		direction = directionOffset.Unit
	end

	return origin, direction
end

function Shotgun:_updateRunAnimation()
	if self._isAiming then
		self:_stopTrack(self.RunTrack)
		self:_stopTrack(self.RunTrackAvatar)
		return
	end

	local character = self.character
	if not character or not self.RunTrack then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	local speed = (rootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	if speed > 1 then
		if not self.RunTrack.IsPlaying then
			self.RunTrack:Play()
		end

		if self.RunTrackAvatar and not self.RunTrackAvatar.IsPlaying then
			self.RunTrackAvatar:Play()
		end
	else
		self.RunTrack:Stop()
		if self.RunTrackAvatar then
			self.RunTrackAvatar:Stop()
		end
	end
end

function Shotgun:PrimaryFire()
	if self.OnCooldown then
		return
	end

	self.OnCooldown = true

	local origin, direction = self:_getFireOriginAndDirection()
	local isAiming = self._isAiming

	if self.InspectTrack then
		self.InspectTrack:Stop()
	end

	self._combatService.ShotgunFire:Fire(origin, direction, isAiming)
	if self._onFireSucceeded then
		self._onFireSucceeded()
	end

	local viewmodelAnimation = nil :: AnimationTrack?
	local avatarFireTrack = nil :: AnimationTrack?
	viewmodelAnimation = self._animationController:PlayAnimation(self.Animator, "ShotgunFire", Enum.AnimationPriority.Action3)
	self.FireTrack = viewmodelAnimation
	avatarFireTrack = self._animationController:PlayAnimationToAvatar("ShotgunFire", Enum.AnimationPriority.Action3)
	self.FireTrackAvatar = avatarFireTrack

	task.defer(function()
		if viewmodelAnimation then
			viewmodelAnimation.Stopped:Wait()
			if self.FireTrack == viewmodelAnimation then
				self.FireTrack = nil
			end
		end

		if avatarFireTrack and self.FireTrackAvatar == avatarFireTrack and not avatarFireTrack.IsPlaying then
			self.FireTrackAvatar = nil
		end
	end)

	task.delay(CombatConfig.Shotgun.FireCooldown, function()
		self.OnCooldown = false
	end)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self._player.Character }
	params.IgnoreWater = true
	self._behavior.RaycastParams = params

	local spreadDegrees = getSpreadDegrees(isAiming)

	for _ = 1, CombatConfig.Shotgun.Pellets do
		local rayDirection = applySpread(direction, spreadDegrees)
		self._caster:Fire(origin, rayDirection, CombatConfig.Shotgun.MuzzleVelocity, self._behavior)
	end
end

function Shotgun:Inspect()
	if self._isAiming then
		return
	end

	if self.InspectTrack then
		self.InspectTrack:Play()
	end
end

function Shotgun:CanAim(): boolean
	return true
end

function Shotgun:SetAiming(isAiming: boolean)
	if self._isAiming == isAiming then
		return
	end

	self._isAiming = isAiming

	if isAiming then
		self:_stopNonIdleAnimations()
	end
end

function Shotgun:Parry()
end

function Shotgun:Destroy()
	if self._runConnection then
		self._runConnection:Disconnect()
		self._runConnection = nil
	end

	if self._characterAddedConnection then
		self._characterAddedConnection:Disconnect()
		self._characterAddedConnection = nil
	end

	if self.IdleTrack then
		self.IdleTrack:Stop()
	end

	if self.IdleTrackAvatar then
		self.IdleTrackAvatar:Stop()
	end

	if self.RunTrack then
		self.RunTrack:Stop()
	end

	if self.RunTrackAvatar then
		self.RunTrackAvatar:Stop()
	end

	if self._cosmeticFolder then
		self._cosmeticFolder:Destroy()
		self._cosmeticFolder = nil
	end
end

return Shotgun
