--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationService = require(ReplicatedStorage.Framework.Services.AnimationService)
local Network = require(ReplicatedStorage.Shared.Network.Network)

local Knife = {}
Knife.__index = Knife

Knife.Name = "Knife"

local PARRY_COOLDOWN = 2

function Knife.new(localPlayer: Player, camera: Camera, vmodel: Model)
	local self = setmetatable({}, Knife)
	self._player   = localPlayer
	self._camera   = camera :: Camera
	self._vmodel   = vmodel
	self.Animator  = vmodel:FindFirstChildWhichIsA("AnimationController") :: AnimationController
	self.character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	self.OnCooldown = false
	self.OnParryCooldown = false
	self._parrySuccessPlayed = false

	-- Idle: viewmodel + avatar
	self.IdleTrack       = AnimationService:PlayAnimation(self.Animator, "KnifeIdle", Enum.AnimationPriority.Action, true) :: AnimationTrack
	self.IdleTrack.Looped = true
	self.IdleTrackAvatar = AnimationService:PlayAnimationToAvatar("KnifeIdle", Enum.AnimationPriority.Action, true)

	-- Run: viewmodel + avatar (preloaded, driven by RenderStepped)
	self.RunTrack        = AnimationService:GetAnimation(self.Animator, "KnifeRun", Enum.AnimationPriority.Action2, true)
	self.RunTrackAvatar  = AnimationService:GetAnimation(self.character:WaitForChild("Humanoid"), "KnifeRun", Enum.AnimationPriority.Action2, true)

	_G.Viewmodel = {"Knife", self}

	-- Listen for server-confirmed parry success
	self._parrySuccessConn = Network:SubscribeToPacket("KnifeParrySuccess"):Connect(function()
		if self._parrySuccessPlayed then return end
		self._parrySuccessPlayed = true
		AnimationService:PlayAnimation(self.Animator, "KnifeParrySuccess", Enum.AnimationPriority.Action4)
		AnimationService:PlayAnimationToAvatar("KnifeParrySuccess", Enum.AnimationPriority.Action4)
	end)

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

	return self
end

function Knife:PrimaryFire()
	if self.OnCooldown then return end
	self.OnCooldown = true

	-- Pick the same random variant for both tracks so they match
	local variant = tostring(math.random(1, 2))

	Network:FireRemoteToServer("KnifeSwing")

	-- Swing: viewmodel + avatar
	local vmAnim = AnimationService:PlayAnimation(self.Animator, "KnifeSwing" .. variant, Enum.AnimationPriority.Action3)
	AnimationService:PlayAnimationToAvatar("KnifeSwing" .. variant, Enum.AnimationPriority.Action3)

	task.defer(function()
		if vmAnim then
			vmAnim.Stopped:Wait()
		end
		self.OnCooldown = false
	end)
end

function Knife:Parry()
	if self.OnParryCooldown then return end
	self.OnParryCooldown = true
	self._parrySuccessPlayed = false

	-- Parry: viewmodel + avatar
	AnimationService:PlayAnimation(self.Animator, "KnifeParry", Enum.AnimationPriority.Action3, false)
	AnimationService:PlayAnimationToAvatar("KnifeParry", Enum.AnimationPriority.Action3, false)

	Network:FireRemoteToServer("KnifeParryStart")

	task.delay(PARRY_COOLDOWN, function()
		self.OnParryCooldown = false
	end)
end

-- Viewmodel-only: no avatar inspect animation
function Knife:Inspect()
end

function Knife:Reload()
end

function Knife:Destroy()
	if self._parrySuccessConn then
		self._parrySuccessConn:Disconnect()
		self._parrySuccessConn = nil
	end

	-- Stop all looped tracks so they don't bleed into the next equipped weapon
	if self.IdleTrack then self.IdleTrack:Stop() end
	if self.IdleTrackAvatar then self.IdleTrackAvatar:Stop() end
	if self.RunTrack then self.RunTrack:Stop() end
	if self.RunTrackAvatar then self.RunTrackAvatar:Stop() end
end

return Knife