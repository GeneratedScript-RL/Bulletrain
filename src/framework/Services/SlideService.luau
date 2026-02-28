--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementSettings = require(ReplicatedStorage.Shared.MovementSettings)

local SlideService = {}
SlideService.__index = SlideService

local ACTION_SLIDE = "Combat_Slide"

function SlideService.new()
	local self = setmetatable({}, SlideService)
	self._enabled = false
	self._sliding = false
	self._conn = nil :: RBXScriptConnection?
	self._lv = nil :: LinearVelocity?
	self._att = nil :: Attachment?
	self._cameraOffsetTween = nil :: Tween?
	return self
end

local singleton = SlideService.new()

local function getCharacterParts()
	local character = Players.LocalPlayer.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not hrp then
		return nil
	end
	return character, humanoid, hrp
end

function singleton:_stopSlide()
	self._sliding = false
	if self._conn then
		self._conn:Disconnect()
		self._conn = nil
	end
	if self._lv then
		self._lv:Destroy()
		self._lv = nil
	end
	if self._att then
		self._att:Destroy()
		self._att = nil
	end

	local parts = getCharacterParts()
	if parts then
		local _character, humanoid, _hrp = parts
		if self._cameraOffsetTween then
			self._cameraOffsetTween:Cancel()
			self._cameraOffsetTween = nil
		end
		self._cameraOffsetTween = TweenService:Create(humanoid, TweenInfo.new(MovementSettings.TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CameraOffset = MovementSettings.STAND_OFFSET,
		})
		self._cameraOffsetTween:Play()
	end
end

function singleton:_startSlide()
	if self._sliding then
		return
	end

	local parts = getCharacterParts()
	if not parts then
		return
	end

	local _character, humanoid, hrp = parts

	-- Must be moving fast enough
	local speed = hrp.AssemblyLinearVelocity.Magnitude
	if speed < MovementSettings.SLIDE_SPEED_THRESHOLD then
		return
	end

	self._sliding = true

	if self._cameraOffsetTween then
		self._cameraOffsetTween:Cancel()
		self._cameraOffsetTween = nil
	end
	self._cameraOffsetTween = TweenService:Create(humanoid, TweenInfo.new(MovementSettings.SLIDE_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CameraOffset = MovementSettings.SLIDE_OFFSET,
	})
	self._cameraOffsetTween:Play()

	self._att = Instance.new("Attachment")
	self._att.Name = "SlideAttachment"
	self._att.Parent = hrp

	self._lv = Instance.new("LinearVelocity")
	self._lv.Name = "SlideLinearVelocity"
	self._lv.Attachment0 = self._att
	self._lv.RelativeTo = Enum.ActuatorRelativeTo.World
	self._lv.MaxForce = math.huge
	self._lv.Parent = hrp

	local startTime = os.clock()
	local startSpeed = MovementSettings.SLIDE_INITIAL_SPEED
	local endSpeed = MovementSettings.SLIDE_END_SPEED
	local duration = MovementSettings.SLIDE_DURATION

	self._conn = RunService.RenderStepped:Connect(function()
		if not self._sliding then
			return
		end

		local t = (os.clock() - startTime) / duration
		if t >= 1 then
			self:_stopSlide()
			return
		end

		local eased = t ^ MovementSettings.SLIDE_POWER
		local currentSpeed = startSpeed + (endSpeed - startSpeed) * eased
		self._lv.VectorVelocity = hrp.CFrame.LookVector * currentSpeed
	end)
end

local function onSlide(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		singleton:_startSlide()
	elseif inputState == Enum.UserInputState.End then
		-- Allow releasing to end early
		singleton:_stopSlide()
	end
	return Enum.ContextActionResult.Sink
end

function singleton:Enable()
	if self._enabled then
		return
	end
	self._enabled = true
	ContextActionService:BindAction(ACTION_SLIDE, onSlide, false, Enum.KeyCode.LeftControl)
end

function singleton:Disable()
	if not self._enabled then
		return
	end
	self._enabled = false
	ContextActionService:UnbindAction(ACTION_SLIDE)
	self:_stopSlide()
end

function singleton:Initialize()
	assert(RunService:IsClient())
end

return singleton
