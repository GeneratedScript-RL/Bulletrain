--!strict

local RunService = game:GetService("RunService")

local Knife = {}
Knife.__index = Knife

Knife.Name = "Knife"

local PARRY_COOLDOWN = 2
local RUN_ANIMATION_SPEED = 0.6

function Knife.new(localPlayer: Player, _camera: Camera, viewmodel: Model, animationController: any, combatService: any)
	local self = setmetatable({}, Knife)
	self._player = localPlayer
	self._animationController = animationController
	self._combatService = combatService
	self._viewmodel = viewmodel
	self.Animator = viewmodel:FindFirstChildWhichIsA("AnimationController") :: AnimationController
	self.character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
	self.OnCooldown = false
	self.OnParryCooldown = false
	self._parrySuccessPlayed = false
	self._runConnection = nil :: RBXScriptConnection?
	self._characterAddedConnection = nil :: RBXScriptConnection?
	self._parrySuccessConnection = nil :: RBXScriptConnection?
	self.IdleTrack = nil :: AnimationTrack?
	self.IdleTrackAvatar = nil :: AnimationTrack?
	self.RunTrack = nil :: AnimationTrack?
	self.RunTrackAvatar = nil :: AnimationTrack?

	self.IdleTrack = animationController:PlayAnimation(self.Animator, "KnifeIdle", Enum.AnimationPriority.Action, true)
	self.RunTrack = animationController:GetAnimation(self.Animator, "KnifeRun", Enum.AnimationPriority.Action2, true)
	self:_refreshAvatarTracks()

	self._parrySuccessConnection = combatService.ParrySuccess:Connect(function()
		if self._parrySuccessPlayed then
			return
		end

		self._parrySuccessPlayed = true
		animationController:PlayAnimation(self.Animator, "KnifeParrySuccess", Enum.AnimationPriority.Action4)
		animationController:PlayAnimationToAvatar("KnifeParrySuccess", Enum.AnimationPriority.Action4)
	end)

	self._runConnection = RunService.RenderStepped:Connect(function()
		self:_updateRunAnimation()
	end)

	self._characterAddedConnection = localPlayer.CharacterAdded:Connect(function(newCharacter)
		self.character = newCharacter
		self:_refreshAvatarTracks()
	end)

	return self
end

function Knife:_getCharacterHumanoid(): Humanoid?
	local character = self.character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

function Knife:_refreshAvatarTracks()
	if self.IdleTrackAvatar then
		self.IdleTrackAvatar:Stop()
	end

	if self.RunTrackAvatar then
		self.RunTrackAvatar:Stop()
	end

	self.IdleTrackAvatar = self._animationController:PlayAnimationToAvatar("KnifeIdle", Enum.AnimationPriority.Action, true)

	local humanoid = self:_getCharacterHumanoid()
	if humanoid then
		self.RunTrackAvatar = self._animationController:GetAnimation(humanoid, "KnifeRun", Enum.AnimationPriority.Action2, true)
	end
end

function Knife:_updateRunAnimation()
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
		self.RunTrack:AdjustSpeed(RUN_ANIMATION_SPEED)

		if not self.RunTrackAvatar.IsPlaying then
			self.RunTrackAvatar:Play()
		end
		self.RunTrackAvatar:AdjustSpeed(RUN_ANIMATION_SPEED)
	else
		self.RunTrack:Stop()
		self.RunTrackAvatar:Stop()
	end
end

function Knife:PrimaryFire()
	if self.OnCooldown then
		return
	end

	self.OnCooldown = true

	local variant = tostring(math.random(1, 2))
	self._combatService.KnifeSwing:Fire()

	local viewmodelAnimation = self._animationController:PlayAnimation(self.Animator, "KnifeSwing" .. variant, Enum.AnimationPriority.Action3)
	self._animationController:PlayAnimationToAvatar("KnifeSwing" .. variant, Enum.AnimationPriority.Action3)

	task.defer(function()
		if viewmodelAnimation then
			viewmodelAnimation.Stopped:Wait()
		end
		self.OnCooldown = false
	end)
end

function Knife:Parry()
	if self.OnParryCooldown then
		return
	end

	self.OnParryCooldown = true
	self._parrySuccessPlayed = false

	self._animationController:PlayAnimation(self.Animator, "KnifeParry", Enum.AnimationPriority.Action3, false)
	self._animationController:PlayAnimationToAvatar("KnifeParry", Enum.AnimationPriority.Action3, false)
	self._combatService.ParryStart:Fire()

	task.delay(PARRY_COOLDOWN, function()
		self.OnParryCooldown = false
	end)
end

function Knife:Inspect()
end

function Knife:Reload()
end

function Knife:CanAim(): boolean
	return false
end

function Knife:SetAiming(_isAiming: boolean)
end

function Knife:Destroy()
	if self._runConnection then
		self._runConnection:Disconnect()
		self._runConnection = nil
	end

	if self._characterAddedConnection then
		self._characterAddedConnection:Disconnect()
		self._characterAddedConnection = nil
	end

	if self._parrySuccessConnection then
		self._parrySuccessConnection:Disconnect()
		self._parrySuccessConnection = nil
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
end

return Knife
