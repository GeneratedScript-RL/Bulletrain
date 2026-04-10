--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local MovementSettings = require(root.Shared.Config.MovementSettings)

local Player = Players.LocalPlayer

local animationController: any
local viewmodelController: any

local SlideController = framework.CreateController({
	Name = "SlideController",
	Dependencies = { "AnimationController", "ViewmodelController" },
})

SlideController._enabled = false
SlideController._sliding = false
SlideController._connection = nil :: RBXScriptConnection?
SlideController._fovConnection = nil :: RBXScriptConnection?
SlideController._jumpConnection = nil :: RBXScriptConnection?
SlideController._cameraOffsetTween = nil :: Tween?
SlideController._slideVelocity = Vector3.zero
SlideController._slideStartTime = 0
SlideController._frozenSlideVelocity = nil :: Vector3?
SlideController._lastPosition = nil :: Vector3?
SlideController._lastPositionCheckTime = 0

local ACTION_SLIDE = "Combat_Slide"
local POSITION_CHECK_INTERVAL = 0.15
local MIN_POSITION_CHANGE = 0.05

local function getCurrentCamera(): Camera?
	return workspace.CurrentCamera
end

local function getCharacterParts(): (Model, Humanoid, BasePart)
	local character = Player.Character or Player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	return character, humanoid, rootPart
end

local function isPerfectSlideCondition(rootPart: BasePart, slideVelocity: Vector3): boolean
	local onSlope = rootPart.AssemblyLinearVelocity.Y < -1
	local fastEnough = slideVelocity.Magnitude >= MovementSettings.SLIDE_INITIAL_SPEED * 0.9
	return onSlope and fastEnough
end

function SlideController:_getSlideAnimationName(): string
	if viewmodelController:GetEquippedWeaponName() == "Knife" then
		return "KnifeSlide"
	end

	return "ShotgunSlide"
end

function SlideController:_stopSlide()
	if not self._sliding then
		viewmodelController:SetAimBlocked(false)
		return
	end

	self._sliding = false
	viewmodelController:SetAimBlocked(false)

	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end

	if self._fovConnection then
		self._fovConnection:Disconnect()
		self._fovConnection = nil
	end

	if self._jumpConnection then
		self._jumpConnection:Disconnect()
		self._jumpConnection = nil
	end

	self._frozenSlideVelocity = nil
	self._lastPosition = nil
	self._lastPositionCheckTime = 0

	local _, humanoid, rootPart = getCharacterParts()
	local bodyVelocity = rootPart:FindFirstChild("SlideVelocity")
	if bodyVelocity then
		bodyVelocity:Destroy()
	end

	if self._cameraOffsetTween then
		self._cameraOffsetTween:Cancel()
		self._cameraOffsetTween = nil
	end

	self._cameraOffsetTween = TweenService:Create(humanoid, TweenInfo.new(MovementSettings.TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CameraOffset = MovementSettings.STAND_OFFSET,
	})
	self._cameraOffsetTween:Play()

	local camera = getCurrentCamera()
	if camera then
		TweenService:Create(camera, TweenInfo.new(MovementSettings.FOV_TWEEN_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			FieldOfView = MovementSettings.DEFAULT_FOV,
		}):Play()
	end

	local animationName = self:_getSlideAnimationName()
	local cache = animationController:GetCache()
	if cache.Viewmodel[animationName] then
		cache.Viewmodel[animationName]:Stop()
	end

	if cache.Avatar[animationName] then
		cache.Avatar[animationName]:Stop()
	end
end

function SlideController:_startSlide()
	if self._sliding or not viewmodelController:HasViewmodel() then
		return
	end

	local _, humanoid, rootPart = getCharacterParts()
	if humanoid.FloorMaterial == Enum.Material.Air then
		return
	end

	viewmodelController:SetAimBlocked(true)

	local animationName = self:_getSlideAnimationName()
	animationController:PlayAnimationToViewmodel(animationName, Enum.AnimationPriority.Action2, true)
	animationController:PlayAnimationToAvatar(animationName, Enum.AnimationPriority.Action2, true)

	if self._jumpConnection then
		self._jumpConnection:Disconnect()
	end

	self._jumpConnection = humanoid.Jumping:Connect(function()
		self:_stopSlide()
	end)

	local velocity = rootPart.AssemblyLinearVelocity
	local moveDirection = Vector3.new(velocity.X, 0, velocity.Z)
	if moveDirection.Magnitude > 0 then
		moveDirection = moveDirection.Unit
	else
		moveDirection = rootPart.CFrame.LookVector
	end

	self._sliding = true
	self._slideVelocity = moveDirection * MovementSettings.SLIDE_INITIAL_SPEED
	self._slideStartTime = os.clock()
	self._frozenSlideVelocity = nil
	self._lastPosition = nil
	self._lastPositionCheckTime = 0

	if self._cameraOffsetTween then
		self._cameraOffsetTween:Cancel()
	end

	self._cameraOffsetTween = TweenService:Create(humanoid, TweenInfo.new(MovementSettings.SLIDE_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CameraOffset = MovementSettings.SLIDE_OFFSET,
	})
	self._cameraOffsetTween:Play()

	local camera = getCurrentCamera()
	if camera then
		TweenService:Create(camera, TweenInfo.new(MovementSettings.FOV_TWEEN_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			FieldOfView = MovementSettings.SLIDE_FOV,
		}):Play()
	end

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Name = "SlideVelocity"
	bodyVelocity.MaxForce = Vector3.new(100000, 0, 100000)
	bodyVelocity.Velocity = self._slideVelocity
	bodyVelocity.Parent = rootPart

	self._fovConnection = RunService.Heartbeat:Connect(function()
		if not self._sliding then
			return
		end

		local activeCamera = getCurrentCamera()
		if not activeCamera then
			return
		end

		local speedRatio = math.clamp(self._slideVelocity.Magnitude / MovementSettings.SLIDE_INITIAL_SPEED, 0, 1)
		local targetFieldOfView = MovementSettings.DEFAULT_FOV + (MovementSettings.SLIDE_FOV - MovementSettings.DEFAULT_FOV) * speedRatio
		activeCamera.FieldOfView = activeCamera.FieldOfView + (targetFieldOfView - activeCamera.FieldOfView) * 0.1
	end)

	self._connection = RunService.Heartbeat:Connect(function()
		if not self._sliding then
			return
		end

		local currentBodyVelocity = rootPart:FindFirstChild("SlideVelocity")
		if isPerfectSlideCondition(rootPart, self._slideVelocity) then
			if not self._frozenSlideVelocity then
				self._frozenSlideVelocity = self._slideVelocity
				self._lastPosition = rootPart.Position
				self._lastPositionCheckTime = os.clock()
			end

			local now = os.clock()
			if now - self._lastPositionCheckTime >= POSITION_CHECK_INTERVAL then
				local moved = (rootPart.Position - (self._lastPosition :: Vector3)).Magnitude
				if moved < MIN_POSITION_CHANGE then
					self:_stopSlide()
					return
				end

				self._lastPosition = rootPart.Position
				self._lastPositionCheckTime = now
			end

			self._slideVelocity = self._frozenSlideVelocity :: Vector3
			if currentBodyVelocity and currentBodyVelocity.Parent then
				(currentBodyVelocity :: BodyVelocity).Velocity = self._slideVelocity
			end
		else
			self._frozenSlideVelocity = nil
			self._lastPosition = nil
			self._lastPositionCheckTime = 0

			local progress = math.min((os.clock() - self._slideStartTime) / MovementSettings.SLIDE_DURATION, 1)
			local speedFactor = (1 - progress) ^ MovementSettings.SLIDE_POWER
			local targetSpeed = MovementSettings.SLIDE_END_SPEED
				+ (MovementSettings.SLIDE_INITIAL_SPEED - MovementSettings.SLIDE_END_SPEED) * speedFactor

			self._slideVelocity = self._slideVelocity.Unit * targetSpeed

			local activeCamera = getCurrentCamera()
			if activeCamera then
				local flatLook = Vector3.new(activeCamera.CFrame.LookVector.X, 0, activeCamera.CFrame.LookVector.Z)
				if flatLook.Magnitude > 0 then
					local cameraDirection = flatLook.Unit
					if self._slideVelocity.Unit:Dot(cameraDirection) > 0.3 then
						self._slideVelocity = self._slideVelocity:Lerp(cameraDirection * self._slideVelocity.Magnitude, 0.05)
					end
				end
			end

			if progress >= 1 or self._slideVelocity.Magnitude < MovementSettings.SLIDE_END_SPEED then
				self:_stopSlide()
				return
			end

			if currentBodyVelocity and currentBodyVelocity.Parent then
				(currentBodyVelocity :: BodyVelocity).Velocity = self._slideVelocity
			end
		end
	end)
end

local function onSlide(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		SlideController:_startSlide()
	end

	return Enum.ContextActionResult.Sink
end

function SlideController:Enable()
	if self._enabled then
		return
	end

	self._enabled = true
	ContextActionService:BindAction(ACTION_SLIDE, onSlide, false, Enum.KeyCode.C)
end

function SlideController:Disable()
	if not self._enabled then
		return
	end

	self._enabled = false
	ContextActionService:UnbindAction(ACTION_SLIDE)
	self:_stopSlide()
end

function SlideController:Init()
	animationController = framework.GetController("AnimationController")
	viewmodelController = framework.GetController("ViewmodelController")
end

return SlideController
