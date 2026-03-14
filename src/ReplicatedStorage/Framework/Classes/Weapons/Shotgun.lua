--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local AnimationService = require(ReplicatedStorage.Framework.Services.AnimationService)

local Network = require(ReplicatedStorage.Shared.Network.Network)
local FastCast = require(ReplicatedStorage.Shared.ThirdParty.FastCast)

local Shotgun = {}
Shotgun.__index = Shotgun

Shotgun.Name = "Shotgun"

local PELLETS = 8
local RANGE = 400
local MUZZLE_VELOCITY = 1500
local SPREAD_DEGREES = 6
local SHELL_CAPACITY = 6

local function applySpread(direction: Vector3, spreadDegrees: number): Vector3
	local spreadRad = math.rad(spreadDegrees)
	local yaw = (math.random() - 0.5) * 2 * spreadRad
	local pitch = (math.random() - 0.5) * 2 * spreadRad
	local cf = CFrame.lookAt(Vector3.zero, direction)
	local spread = CFrame.Angles(pitch, yaw, 0)
	return (cf * spread).LookVector
end

-- Plays both viewmodel + avatar tracks simultaneously, waits on the viewmodel
-- track as the timing authority. Returns false if cancelled mid-play.
local function playPhase(
	animator: AnimationController,
	animName: string,
	priority: Enum.AnimationPriority,
	cancelled: () -> boolean
): boolean
	local vmTrack = AnimationService:PlayAnimation(animator, animName, priority, false)
	local avTrack = AnimationService:PlayAnimationToAvatar(animName, priority, false)

	if not vmTrack then
		if avTrack then avTrack:Stop(0) end
		return not cancelled()
	end

	repeat
		task.wait(0.05)
		if cancelled() then
			vmTrack:Stop(0.1)
			if avTrack then avTrack:Stop(0.1) end
			return false
		end
	until not vmTrack.IsPlaying

	if avTrack then avTrack:Stop(0.1) end
	return true
end

function Shotgun.new(localPlayer: Player, camera: Camera, vmodel: Model)
	local self = setmetatable({}, Shotgun)
	self._player   = localPlayer
	self._camera   = camera :: Camera
	self._caster   = FastCast.new()
	self._behavior = FastCast.newBehavior()
	self._behavior.MaxDistance = RANGE
	self._vmodel   = vmodel
	self.Animator  = vmodel:FindFirstChildWhichIsA("AnimationController") :: AnimationController
	self.character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	self.OnCooldown       = false
	self._shells          = SHELL_CAPACITY
	self._reloading       = false
	self._reloadCancelled = false

	-- Viewmodel-only inspect track
	self.InspectTrack    = AnimationService:GetAnimation(self.Animator, "ShotgunInspect", Enum.AnimationPriority.Action2)

	-- Idle: viewmodel + avatar
	self.IdleTrack       = AnimationService:PlayAnimation(self.Animator, "ShotgunIdle", Enum.AnimationPriority.Action, true) :: AnimationTrack
	self.IdleTrackAvatar = AnimationService:PlayAnimationToAvatar("ShotgunIdle", Enum.AnimationPriority.Action, true)

	-- Run: viewmodel + avatar (preloaded, not auto-playing)
	self.RunTrack        = AnimationService:GetAnimation(self.Animator, "ShotgunRun", Enum.AnimationPriority.Action2, true)
	self.RunTrackAvatar  = AnimationService:PlayAnimationToAvatar("ShotgunRun", Enum.AnimationPriority.Action, true)

	_G.Viewmodel = {"Shotgun", self}

	RunService.RenderStepped:Connect(function()
		if not (self.character and self.character:FindFirstChild("Humanoid") and self.character:FindFirstChild("HumanoidRootPart")) then return end
		if not self.RunTrack or not self.RunTrackAvatar then return end
		local HRP = self.character:FindFirstChild("HumanoidRootPart") :: BasePart
		local speed = (HRP.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude

		if speed > 1 then
			if self.RunTrack.IsPlaying then return end
			self.RunTrack:Play()
			self.RunTrackAvatar:Play()
		else
			self.RunTrack:Stop()
			self.RunTrackAvatar:Stop()
		end
	end)

	localPlayer.CharacterAdded:Connect(function(newchar)
		self.character = newchar
	end)

	self._cosmeticFolder = Instance.new("Folder")
	self._cosmeticFolder.Name = "ShotgunCosmetics"
	self._cosmeticFolder.Parent = camera

	self._behavior.CosmeticBulletContainer = self._cosmeticFolder
	self._behavior.CosmeticBulletTemplate  = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Bullet")

	self._caster.LengthChanged:Connect(function(_cast, lastPoint: Vector3, rayDir: Vector3, rayDisplacement: number, _segVel: Vector3, bullet: Instance?)
		if bullet and bullet:IsA("BasePart") then
			bullet.CFrame = CFrame.new(lastPoint, lastPoint + rayDir) * CFrame.new(0, 0, -rayDisplacement / 2)
		end
	end)

	self._caster.RayHit:Connect(function(_activeCast, _result, _vel, bullet)
		if bullet and bullet:IsA("BasePart") then
			Debris:AddItem(bullet, 1)
		end
	end)

	return self
end

function Shotgun:PrimaryFire()
	if self.OnCooldown then return end
	if self._shells <= 0 then return end

	-- Interrupt any in-progress reload
	if self._reloading then
		self._reloadCancelled = true
	end

	self.OnCooldown = true
	self._shells   -= 1

	local camera       = self._camera :: Camera
	local originCFrame = camera.CFrame * CFrame.new(2, -1, -2.5)
	local direction    = camera.CFrame.LookVector

	if self.InspectTrack then self.InspectTrack:Stop() end
	Network:FireRemoteToServer("ShotgunFire", originCFrame.Position, direction)

	-- Fire anim: viewmodel + avatar
	local vmAnim = AnimationService:PlayAnimation(self.Animator, "ShotgunFire", Enum.AnimationPriority.Action3)
	AnimationService:PlayAnimationToAvatar("ShotgunFire", Enum.AnimationPriority.Action3)

	task.defer(function()
		if vmAnim then
			vmAnim.Stopped:Wait()
		end
		self.OnCooldown = false
	end)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {self._player.Character}
	params.IgnoreWater = true
	self._behavior.RaycastParams = params

	for _ = 1, PELLETS do
		local dir = applySpread(direction, SPREAD_DEGREES)
		self._caster:Fire(originCFrame.Position, dir, MUZZLE_VELOCITY, self._behavior)
	end
end

function Shotgun:Reload()
	if self._shells >= SHELL_CAPACITY then return end
	if self._reloading then return end

	self._reloading       = true
	self._reloadCancelled = false

	local shellsNeeded = SHELL_CAPACITY - self._shells
	local cancelled    = function() return self._reloadCancelled end

	-- Open the action
	local ok = playPhase(self.Animator, "ShotgunReloadStart", Enum.AnimationPriority.Action3, cancelled)
	if not ok then
		self._reloading = false
		return
	end

	-- Insert one shell at a time; credit each shell as it lands
	for _ = 1, shellsNeeded do
		if self._reloadCancelled then break end

		ok = playPhase(self.Animator, "ShotgunReloadShell", Enum.AnimationPriority.Action3, cancelled)
		if not ok then break end

		self._shells += 1
		Network:FireRemoteToServer("ShotgunReloadShell", self._shells)
	end

	-- Close the action only if uninterrupted
	if not self._reloadCancelled then
		playPhase(self.Animator, "ShotgunReloadEnd", Enum.AnimationPriority.Action3, cancelled)
	end

	self._reloading       = false
	self._reloadCancelled = false
end

-- Viewmodel-only: no avatar inspect animation
function Shotgun:Inspect()
	if self.InspectTrack then self.InspectTrack:Play() end
end

function Shotgun:Parry()
	-- No-op: parry is Knife-only
end

function Shotgun:Destroy()
	-- Stop all looped tracks so they don't bleed into the next equipped weapon
	if self.IdleTrack then self.IdleTrack:Stop() end
	if self.IdleTrackAvatar then self.IdleTrackAvatar:Stop() end
	if self.RunTrack then self.RunTrack:Stop() end
	if self.RunTrackAvatar then self.RunTrackAvatar:Stop() end

	if self._cosmeticFolder then
		self._cosmeticFolder:Destroy()
	end
end

return Shotgun