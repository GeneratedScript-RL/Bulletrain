--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationService = require(ReplicatedStorage.Framework.Services.AnimationService)
local MovementSettings = require(ReplicatedStorage.Shared.MovementSettings)
local ViewmodelService = require(ReplicatedStorage.Framework.Services.ViewmodelService)

local Player = Players.LocalPlayer :: Player
local camera = workspace.CurrentCamera

local SlideService = {}
SlideService.__index = SlideService

local ACTION_SLIDE = "Combat_Slide"

local POSITION_CHECK_INTERVAL = 0.15
local MIN_POSITION_CHANGE = 0.05

function SlideService.new()
	local self = setmetatable({}, SlideService)
	
	self._enabled = false
	self._sliding = false
	self._conn = nil :: RBXScriptConnection?
	self._fovConn = nil :: RBXScriptConnection?
	self._jumpConn = nil :: RBXScriptConnection?
	self._cameraOffsetTween = nil :: Tween?
	self._slideVelocity = Vector3.zero
	self._slideStartTime = 0
	self._frozenSlideVelocity = nil :: Vector3?
	self._lastPosition = nil :: Vector3?
	self._lastPositionCheckTime = 0
	self.SlideAnim = nil :: AnimationTrack?
	self.SlideAnimAvatar = nil :: AnimationTrack?
	
	return self
end

local singleton = SlideService.new()

local function getCharacterParts(): (Model, Humanoid, BasePart)
	local character = Player.Character or Player.CharacterAdded:Wait() :: Model
	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid
	local hrp = character:WaitForChild("HumanoidRootPart") :: BasePart
	return character, humanoid, hrp
end

local function isPerfectSlideCondition(hrp: BasePart, slideVelocity: Vector3): boolean
	local onSlope = hrp.AssemblyLinearVelocity.Y < -1
	local fastEnough = slideVelocity.Magnitude >= MovementSettings.SLIDE_INITIAL_SPEED * 0.9
	return onSlope and fastEnough
end

function singleton:_stopSlide()
	if not self._sliding then return end
	self._sliding = false

	if self._conn then self._conn:Disconnect(); self._conn = nil end
	if self._fovConn then self._fovConn:Disconnect(); self._fovConn = nil end
	if self._jumpConn then self._jumpConn:Disconnect(); self._jumpConn = nil end

	self._frozenSlideVelocity = nil
	self._lastPosition = nil
	self._lastPositionCheckTime = 0

	local _character, humanoid, hrp = getCharacterParts()

	local bodyVelocity = hrp:FindFirstChild("SlideVelocity")
	if bodyVelocity then bodyVelocity:Destroy() end

	if self._cameraOffsetTween then self._cameraOffsetTween:Cancel(); self._cameraOffsetTween = nil end
	self._cameraOffsetTween = TweenService:Create(humanoid, TweenInfo.new(MovementSettings.TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CameraOffset = MovementSettings.STAND_OFFSET,
	})
	self._cameraOffsetTween:Play()

	TweenService:Create(camera, TweenInfo.new(MovementSettings.FOV_TWEEN_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = MovementSettings.DEFAULT_FOV,
	}):Play()
	
	local name

	if _G.Viewmodel and _G.Viewmodel[1] == "Knife" then
		name = "KnifeSlide"
	else
		name = "ShotgunSlide"
	end
	
	local Anims = AnimationService:GetCache()
	if Anims.Viewmodel[name] then
		Anims.Viewmodel[name]:Stop()
	end
	if Anims.Avatar[name] then
		Anims.Avatar[name]:Stop()
	end
end

function singleton:_startSlide()
	if self._sliding then return end
	
	local _vm = ViewmodelService._vm
	local viewmodel = _vm._vmModel
	
	local name
	
	if _G.Viewmodel and _G.Viewmodel[1] == "Knife" then
		name = "KnifeSlide"
	else
		name = "ShotgunSlide"
	end
	
	self.SlideAnim = AnimationService:PlayAnimationToViewmodel(name, Enum.AnimationPriority.Action2, true)
	self.SlideAnimAvatar = AnimationService:PlayAnimationToAvatar(name, Enum.AnimationPriority.Action2, true)

	local _character, humanoid, hrp = getCharacterParts()

	if humanoid.FloorMaterial == Enum.Material.Air then return end

	if self._jumpConn then self._jumpConn:Disconnect(); self._jumpConn = nil end
	self._jumpConn = humanoid.Jumping:Connect(function()
		singleton:_stopSlide()
	end)

	local vel = hrp.AssemblyLinearVelocity
	local moveDir = Vector3.new(vel.X, 0, vel.Z)
	if moveDir.Magnitude > 0 then
		moveDir = moveDir.Unit
	else
		moveDir = hrp.CFrame.LookVector
	end

	self._sliding = true
	self._slideVelocity = moveDir * MovementSettings.SLIDE_INITIAL_SPEED
	self._slideStartTime = os.clock()
	self._frozenSlideVelocity = nil
	self._lastPosition = nil
	self._lastPositionCheckTime = 0

	if self._cameraOffsetTween then self._cameraOffsetTween:Cancel(); self._cameraOffsetTween = nil end
	self._cameraOffsetTween = TweenService:Create(humanoid, TweenInfo.new(MovementSettings.SLIDE_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CameraOffset = MovementSettings.SLIDE_OFFSET,
	})
	
	self._cameraOffsetTween:Play()

	TweenService:Create(camera, TweenInfo.new(MovementSettings.FOV_TWEEN_IN, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = MovementSettings.SLIDE_FOV,
	}):Play()

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Name = "SlideVelocity"
	bodyVelocity.MaxForce = Vector3.new(100000, 0, 100000)
	bodyVelocity.Velocity = self._slideVelocity
	bodyVelocity.Parent = hrp

	self._fovConn = RunService.Heartbeat:Connect(function()
		if not self._sliding then return end
		local speedRatio = math.clamp(self._slideVelocity.Magnitude / MovementSettings.SLIDE_INITIAL_SPEED, 0, 1)
		local targetFOV = MovementSettings.DEFAULT_FOV + (MovementSettings.SLIDE_FOV - MovementSettings.DEFAULT_FOV) * speedRatio
		camera.FieldOfView = camera.FieldOfView + (targetFOV - camera.FieldOfView) * 0.1
	end)

	self._conn = RunService.Heartbeat:Connect(function()
		if not self._sliding then return end

		local bv = hrp:FindFirstChild("SlideVelocity")

		if isPerfectSlideCondition(hrp, self._slideVelocity) then
			if not self._frozenSlideVelocity then
				self._frozenSlideVelocity = self._slideVelocity
				self._lastPosition = hrp.Position
				self._lastPositionCheckTime = os.clock()
			end

			local now = os.clock()
			if now - self._lastPositionCheckTime >= POSITION_CHECK_INTERVAL then
				local moved = (hrp.Position - (self._lastPosition :: Vector3)).Magnitude
				if moved < MIN_POSITION_CHANGE then
					self:_stopSlide()
					return
				end
				self._lastPosition = hrp.Position
				self._lastPositionCheckTime = now
			end

			self._slideVelocity = self._frozenSlideVelocity :: Vector3
			if bv and bv.Parent then
				(bv :: BodyVelocity).Velocity = self._slideVelocity
			end
		else
			self._frozenSlideVelocity = nil
			self._lastPosition = nil
			self._lastPositionCheckTime = 0

			local progress = math.min((os.clock() - self._slideStartTime) / MovementSettings.SLIDE_DURATION, 1)
			local speedFactor = (1 - progress) ^ MovementSettings.SLIDE_POWER
			local targetSpeed = MovementSettings.SLIDE_END_SPEED + (MovementSettings.SLIDE_INITIAL_SPEED - MovementSettings.SLIDE_END_SPEED) * speedFactor

			self._slideVelocity = self._slideVelocity.Unit * targetSpeed

			local camDir = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit
			if self._slideVelocity.Unit:Dot(camDir) > 0.3 then
				self._slideVelocity = self._slideVelocity:Lerp(camDir * self._slideVelocity.Magnitude, 0.05)
			end

			if progress >= 1 or self._slideVelocity.Magnitude < MovementSettings.SLIDE_END_SPEED then
				self:_stopSlide()
				return
			end

			if bv and bv.Parent then
				(bv :: BodyVelocity).Velocity = self._slideVelocity
			end
		end
	end)
end

local function onSlide(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		singleton:_startSlide()
	end
	return Enum.ContextActionResult.Sink
end

function singleton:Enable()
	if self._enabled then return end
	self._enabled = true
	ContextActionService:BindAction(ACTION_SLIDE, onSlide, false, Enum.KeyCode.C)
end

function singleton:Disable()
	if not self._enabled then return end
	self._enabled = false
	ContextActionService:UnbindAction(ACTION_SLIDE)
	self:_stopSlide()
end

function singleton:Initialize()
	assert(RunService:IsClient())
end

return singleton