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

local SHELL_CAPACITY = 6
local DEFAULT_RELOAD_PHASE_DURATION = 0.15

type ReloadStateChanged = (isReloading: boolean, progress: number, tweenDuration: number?) -> ()

local function getTrackPlaybackDuration(track: AnimationTrack?): number
	if not track then
		return DEFAULT_RELOAD_PHASE_DURATION
	end

	local speed = math.abs(track.Speed)
	if speed <= 0 then
		speed = 1
	end

	return math.max(track.Length / speed, DEFAULT_RELOAD_PHASE_DURATION)
end

local function applySpread(direction: Vector3, spreadDegrees: number): Vector3
	local spreadRadians = math.rad(spreadDegrees)
	local yaw = (math.random() - 0.5) * 2 * spreadRadians
	local pitch = (math.random() - 0.5) * 2 * spreadRadians
	local base = CFrame.lookAt(Vector3.zero, direction)
	return (base * CFrame.Angles(pitch, yaw, 0)).LookVector
end

local function playPhase(
	animationController: any,
	animator: AnimationController,
	animName: string,
	priority: Enum.AnimationPriority,
	cancelled: () -> boolean
): boolean
	local viewmodelTrack = animationController:PlayAnimation(animator, animName, priority, false)
	local avatarTrack = animationController:PlayAnimationToAvatar(animName, priority, false)

	if not viewmodelTrack then
		if avatarTrack then
			avatarTrack:Stop(0)
		end

		return not cancelled()
	end

	repeat
		RunService.Heartbeat:Wait()
		if cancelled() then
			viewmodelTrack:Stop(0.1)
			if avatarTrack then
				avatarTrack:Stop(0.1)
			end
			return false
		end
	until not viewmodelTrack.IsPlaying

	if avatarTrack then
		avatarTrack:Stop(0.1)
	end

	return true
end

function Shotgun.new(
	localPlayer: Player,
	camera: Camera,
	viewmodel: Model,
	animationController: any,
	combatService: any,
	onReloadStateChanged: ReloadStateChanged?
)
	local self = setmetatable({}, Shotgun)
	self._player = localPlayer
	self._camera = camera
	self._animationController = animationController
	self._combatService = combatService
	self._onReloadStateChanged = onReloadStateChanged
	self._caster = FastCast.new()
	self._behavior = FastCast.newBehavior()
	self._behavior.MaxDistance = CombatConfig.Shotgun.Range
	self._viewmodel = viewmodel
	self.Animator = viewmodel:FindFirstChildWhichIsA("AnimationController") :: AnimationController
	self.character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	self.OnCooldown = false
	self._shells = SHELL_CAPACITY
	self._reloading = false
	self._reloadCancelled = false
	self._runConnection = nil :: RBXScriptConnection?
	self._characterAddedConnection = nil :: RBXScriptConnection?
	self._cosmeticFolder = nil :: Folder?
	self.IdleTrack = nil :: AnimationTrack?
	self.IdleTrackAvatar = nil :: AnimationTrack?
	self.RunTrack = nil :: AnimationTrack?
	self.RunTrackAvatar = nil :: AnimationTrack?
	self.InspectTrack = nil :: AnimationTrack?

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

	return self
end

function Shotgun:_setReloadState(isReloading: boolean, progress: number, tweenDuration: number?)
	local callback = self._onReloadStateChanged
	if not callback then
		return
	end

	callback(isReloading, math.clamp(progress, 0, 1), tweenDuration or 0)
end

function Shotgun:_getReloadPhaseDuration(animName: string): number
	local track = self._animationController:GetAnimation(self.Animator, animName, Enum.AnimationPriority.Action3, false)
	return getTrackPlaybackDuration(track)
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

function Shotgun:_updateRunAnimation()
	local character = self.character
	if not character or not self.RunTrack or not self.RunTrackAvatar then
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

		if not self.RunTrackAvatar.IsPlaying then
			self.RunTrackAvatar:Play()
		end
	else
		self.RunTrack:Stop()
		self.RunTrackAvatar:Stop()
	end
end

function Shotgun:PrimaryFire()
	if self.OnCooldown or self._shells <= 0 then
		return
	end

	if self._reloading then
		self._reloadCancelled = true
		self:_setReloadState(false, 0, 0)
	end

	self.OnCooldown = true
	self._shells -= 1

	local originCFrame = self._camera.CFrame * CFrame.new(2, -1, -2.5)
	local direction = self._camera.CFrame.LookVector

	if self.InspectTrack then
		self.InspectTrack:Stop()
	end

	self._combatService.ShotgunFire:Fire(originCFrame.Position, direction)

	local viewmodelAnimation = self._animationController:PlayAnimation(self.Animator, "ShotgunFire", Enum.AnimationPriority.Action3)
	self._animationController:PlayAnimationToAvatar("ShotgunFire", Enum.AnimationPriority.Action3)

	task.defer(function()
		if viewmodelAnimation then
			viewmodelAnimation.Stopped:Wait()
		end
		self.OnCooldown = false
	end)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self._player.Character }
	params.IgnoreWater = true
	self._behavior.RaycastParams = params

	for _ = 1, CombatConfig.Shotgun.Pellets do
		local rayDirection = applySpread(direction, CombatConfig.Shotgun.SpreadDegrees)
		self._caster:Fire(originCFrame.Position, rayDirection, CombatConfig.Shotgun.MuzzleVelocity, self._behavior)
	end
end

function Shotgun:Reload()
	if self._shells >= SHELL_CAPACITY or self._reloading then
		return
	end

	self._reloading = true
	self._reloadCancelled = false

	local shellsNeeded = SHELL_CAPACITY - self._shells
	local reloadStartDuration = self:_getReloadPhaseDuration("ShotgunReloadStart")
	local reloadShellDuration = self:_getReloadPhaseDuration("ShotgunReloadShell")
	local reloadEndDuration = self:_getReloadPhaseDuration("ShotgunReloadEnd")
	local totalDuration = reloadStartDuration + (reloadShellDuration * shellsNeeded) + reloadEndDuration
	local elapsedDuration = 0
	local cancelled = function(): boolean
		return self._reloadCancelled
	end

	self:_setReloadState(true, 0, 0)
	self:_setReloadState(
		true,
		reloadStartDuration / totalDuration,
		reloadStartDuration
	)
	local completed = playPhase(
		self._animationController,
		self.Animator,
		"ShotgunReloadStart",
		Enum.AnimationPriority.Action3,
		cancelled
	)
	if not completed then
		self._reloading = false
		self:_setReloadState(false, 0, 0)
		return
	end

	elapsedDuration += reloadStartDuration
	self:_setReloadState(true, elapsedDuration / totalDuration, 0)

	for _ = 1, shellsNeeded do
		if self._reloadCancelled then
			break
		end

		local targetDuration = elapsedDuration + reloadShellDuration
		self:_setReloadState(
			true,
			targetDuration / totalDuration,
			reloadShellDuration
		)
		completed = playPhase(
			self._animationController,
			self.Animator,
			"ShotgunReloadShell",
			Enum.AnimationPriority.Action3,
			cancelled
		)
		if not completed then
			break
		end

		elapsedDuration = targetDuration
		self:_setReloadState(true, elapsedDuration / totalDuration, 0)
		self._shells += 1
	end

	if not self._reloadCancelled then
		local targetDuration = elapsedDuration + reloadEndDuration
		self:_setReloadState(
			true,
			targetDuration / totalDuration,
			reloadEndDuration
		)
		local endCompleted = playPhase(
			self._animationController,
			self.Animator,
			"ShotgunReloadEnd",
			Enum.AnimationPriority.Action3,
			cancelled
		)
		if endCompleted then
			elapsedDuration = targetDuration
			self:_setReloadState(true, elapsedDuration / totalDuration, 0)
		end
	end

	self._reloading = false
	self._reloadCancelled = false
	self:_setReloadState(false, 0, 0)
end

function Shotgun:Inspect()
	if self.InspectTrack then
		self.InspectTrack:Play()
	end
end

function Shotgun:Parry()
end

function Shotgun:Destroy()
	self:_setReloadState(false, 0, 0)

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
