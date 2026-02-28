-- local ContextActionService = game:GetService("ContextActionService")
-- local TweenService = game:GetService("TweenService")
-- local RunService = game:GetService("RunService")
-- local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local Players = game:GetService("Players")

-- local SlideComponent = {}

-- local NetworkSubscriptionService = require(ReplicatedStorage.Framework.Client.Services.NetworkSubscriptionService)
-- local AnimationService = require(ReplicatedStorage.Framework.Client.Services.AnimationService)

-- local Config = require(ReplicatedStorage.Framework.Shared.MovementSettings)

-- -- Action names for ContextActionService
-- local ACTIONS = {
-- 	SlideOrCrouch = "SlideOrCrouch",
-- 	MoveForward = "MoveForward",
-- 	MoveBackward = "MoveBackward",
-- 	MoveLeft = "MoveLeft",
-- 	MoveRight = "MoveRight"
-- }

-- local player = game.Players.LocalPlayer
-- local character
-- local humanoid
-- local humanoidRootPart
-- local camera

-- local isEnabled = false
-- _G.Sliding = false
-- _G.Crouching = false
-- local currentTween = nil
-- local currentFOVTween = nil
-- local currentTiltTween = nil
-- local slideVelocity = nil
-- local slideConnection = nil
-- local lastDecelerationTime = 0
-- local fovUpdateConnection = nil
-- local cameraRollConnection = nil
-- local currentCameraRoll = 0
-- local targetCameraRoll = 0
-- local lastPosition = nil
-- local frozenSlideVelocity = nil
-- local positionCheckInterval = 0.2 -- Check less frequently for more stability
-- local lastPositionCheckTime = 0
-- local minPositionChange = 0.4
-- local slideStartTime = 0

-- local keysPressed = {
-- 	[Enum.KeyCode.W] = false,
-- 	[Enum.KeyCode.A] = false,
-- 	[Enum.KeyCode.S] = false,
-- 	[Enum.KeyCode.D] = false
-- }

-- local permanentConnections = {}
-- local characterConnections = {}

-- local PlayerGui = player.PlayerGui
-- local MobileHUD = PlayerGui:WaitForChild("MobileHUD")
-- local Crouch = MobileHUD:WaitForChild("Crouch")

-- ---

-- local function cancelCurrentTween()
-- 	if currentTween then
-- 		currentTween:Cancel()
-- 		currentTween = nil
-- 	end
-- end

-- local function cancelFOVTween()
-- 	if currentFOVTween then
-- 		currentFOVTween:Cancel()
-- 		currentFOVTween = nil
-- 	end
-- end

-- local function cancelTiltTween()
-- 	if currentTiltTween then
-- 		currentTiltTween:Cancel()
-- 		currentTiltTween = nil
-- 	end
-- end

-- local function setCameraRoll(rollAngle)
-- 	targetCameraRoll = rollAngle
-- end

-- local function tweenFOV(targetFOV, tweenTime)
-- 	cancelFOVTween()

-- 	local tweenInfo = TweenInfo.new(
-- 		tweenTime,
-- 		Enum.EasingStyle.Quad,
-- 		Enum.EasingDirection.Out
-- 	)

-- 	currentFOVTween = TweenService:Create(camera, tweenInfo, {FieldOfView = targetFOV})
-- 	currentFOVTween:Play()

-- 	return currentFOVTween
-- end

-- local function tweenCameraOffset(targetOffset)
-- 	cancelCurrentTween()

-- 	local tweenInfo = TweenInfo.new(
-- 		Config.TWEEN_TIME,
-- 		Enum.EasingStyle.Quad,
-- 		Enum.EasingDirection.Out
-- 	)

-- 	currentTween = TweenService:Create(humanoid, tweenInfo, {CameraOffset = targetOffset})
-- 	currentTween:Play()

-- 	return currentTween
-- end

-- local function getMovementDirection()
-- 	local cameraCFrame = camera.CFrame
-- 	local forward = Vector3.new(cameraCFrame.LookVector.X, 0, cameraCFrame.LookVector.Z).Unit
-- 	local right = Vector3.new(cameraCFrame.RightVector.X, 0, cameraCFrame.RightVector.Z).Unit

-- 	local direction = Vector3.new(0, 0, 0)

-- 	if keysPressed[Enum.KeyCode.W] then direction += forward end
-- 	if keysPressed[Enum.KeyCode.S] then direction -= forward end
-- 	if keysPressed[Enum.KeyCode.A] then direction -= right end
-- 	if keysPressed[Enum.KeyCode.D] then direction += right end

-- 	return (direction.Magnitude > 0) and direction.Unit or Vector3.zero
-- end

-- local function isWallNearby()
-- 	if not humanoidRootPart then return false end

-- 	local raycastParams = RaycastParams.new()
-- 	raycastParams.FilterDescendantsInstances = {character}
-- 	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

-- 	local position = humanoidRootPart.Position
-- 	local checkDistance = 3 -- 3 studs for more generous detection

-- 	-- Check multiple directions around the player (not just left/right)
-- 	local directions = {
-- 		humanoidRootPart.CFrame.RightVector, -- Right
-- 		-humanoidRootPart.CFrame.RightVector, -- Left
-- 		humanoidRootPart.CFrame.LookVector, -- Forward
-- 		-humanoidRootPart.CFrame.LookVector, -- Backward
-- 		(humanoidRootPart.CFrame.RightVector + humanoidRootPart.CFrame.LookVector).Unit, -- Forward-Right diagonal
-- 		(-humanoidRootPart.CFrame.RightVector + humanoidRootPart.CFrame.LookVector).Unit, -- Forward-Left diagonal
-- 		(humanoidRootPart.CFrame.RightVector - humanoidRootPart.CFrame.LookVector).Unit, -- Backward-Right diagonal
-- 		(-humanoidRootPart.CFrame.RightVector - humanoidRootPart.CFrame.LookVector).Unit, -- Backward-Left diagonal
-- 	}

-- 	for _, direction in ipairs(directions) do
-- 		local rayResult = workspace:Raycast(position, direction * checkDistance, raycastParams)
-- 		if rayResult then
-- 			return true
-- 		end
-- 	end

-- 	-- Also check if we're inside a wall using GetPartBoundsInBox
-- 	local overlapParams = OverlapParams.new()
-- 	overlapParams.FilterDescendantsInstances = {character}
-- 	overlapParams.FilterType = Enum.RaycastFilterType.Exclude

-- 	local hrpSize = humanoidRootPart.Size * 1.5 -- Expand the check area
-- 	local partsInBox = workspace:GetPartBoundsInBox(humanoidRootPart.CFrame, hrpSize, overlapParams)

-- 	if #partsInBox > 0 then
-- 		return true
-- 	end

-- 	return false
-- end

-- local function isPerfectSlideCondition()
-- 	if not humanoid or not humanoidRootPart then return false end

-- 	-- Check if in air
-- 	local inAir = humanoid.FloorMaterial == Enum.Material.Air

-- 	-- Check if wall is nearby or inside
-- 	local wallNearby = isWallNearby()

-- 	return inAir and wallNearby
-- end

-- local function crouch()
-- 	if not isEnabled or _G.Crouching or _G.Sliding then return end

-- 	_G.Crouching = true
-- 	tweenCameraOffset(Config.CROUCH_OFFSET)

-- 	AnimationService:playAnimation("Crouch")
-- end

-- local function stopSlide()
-- 	if not _G.Sliding then return end

-- 	_G.Sliding = false

-- 	if slideConnection then slideConnection:Disconnect(); slideConnection = nil end
-- 	if fovUpdateConnection then fovUpdateConnection:Disconnect(); fovUpdateConnection = nil end

-- 	-- Get the current slide velocity before destroying BodyVelocity
-- 	local currentSlideVelocity = slideVelocity

-- 	local bodyVelocity = humanoidRootPart:FindFirstChild("SlideVelocity")
-- 	if bodyVelocity then 
-- 		-- Use the actual BodyVelocity if it exists (more accurate)
-- 		currentSlideVelocity = bodyVelocity.Velocity
-- 		bodyVelocity:Destroy() 
-- 	end
	
-- 	local function preserve()
-- 		humanoidRootPart.AssemblyLinearVelocity = Vector3.new(
-- 			currentSlideVelocity.X * Config.MOMENTUM_PRESERVATION,
-- 			humanoidRootPart.AssemblyLinearVelocity.Y,
-- 			currentSlideVelocity.Z * Config.MOMENTUM_PRESERVATION
-- 		)
-- 	end

-- 	preserve()
	
-- 	task.spawn(function()
		
-- 		local times = 0
-- 		local targettimes = 4
		
-- 		repeat
-- 			times += 1
-- 			preserve()
-- 			task.wait(0.05)
-- 		until times >= targettimes
-- 	end)

-- 	tweenFOV(Config.DEFAULT_FOV, Config.FOV_TWEEN_OUT)
-- 	setCameraRoll(0)
-- 	tweenCameraOffset(Config.STAND_OFFSET)

-- 	AnimationService:stopAnimation("Slide")

-- 	ReplicatedStorage.Events.Slide:Fire(false)
-- end

-- local function startSlide()
-- 	if not isEnabled or _G.Sliding then return end

-- 	if humanoid.FloorMaterial == Enum.Material.Air then
-- 		crouch()
-- 		return
-- 	end

-- 	local moveDirection = getMovementDirection()

-- 	if moveDirection.Magnitude == 0 then
-- 		local currentVelocity = humanoidRootPart.AssemblyLinearVelocity
-- 		moveDirection = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)
-- 		if moveDirection.Magnitude > 0 then
-- 			moveDirection = moveDirection.Unit
-- 		else
-- 			moveDirection = humanoidRootPart.CFrame.LookVector
-- 		end
-- 	end

-- 	_G.Sliding = true
-- 	_G.Crouching = false

-- 	slideVelocity = moveDirection * Config.SLIDE_INITIAL_SPEED
-- 	slideStartTime = tick()  -- Initialize start time
-- 	lastDecelerationTime = tick()

-- 	-- ... rest of the function stays the same

-- 	tweenFOV(Config.SLIDE_FOV, Config.FOV_TWEEN_IN)
-- 	setCameraRoll(Config.SLIDE_TILT_ANGLE)

-- 	cancelCurrentTween()

-- 	local tweenInfo = TweenInfo.new(
-- 		Config.SLIDE_TWEEN_TIME,
-- 		Enum.EasingStyle.Quad,
-- 		Enum.EasingDirection.Out
-- 	)

-- 	currentTween = TweenService:Create(humanoid, tweenInfo, {CameraOffset = Config.SLIDE_OFFSET})
-- 	currentTween:Play()

-- 	local bodyVelocity = Instance.new("BodyVelocity")
-- 	bodyVelocity.Name = "SlideVelocity"
-- 	bodyVelocity.MaxForce = Vector3.new(100000, 0, 100000)
-- 	bodyVelocity.Velocity = slideVelocity
-- 	bodyVelocity.Parent = humanoidRootPart

-- 	AnimationService:stopAnimation("Crouch")
-- 	AnimationService:playAnimation("Slide")

-- 	ReplicatedStorage.Events.Slide:Fire(true)

-- 	if fovUpdateConnection then
-- 		fovUpdateConnection:Disconnect()
-- 	end

-- 	fovUpdateConnection = RunService.Heartbeat:Connect(function()
-- 		if not _G.Sliding then return end

-- 		local speedRatio = math.clamp(slideVelocity.Magnitude / Config.SLIDE_INITIAL_SPEED, 0, 1)
-- 		local targetFOV = Config.DEFAULT_FOV + (Config.SLIDE_FOV - Config.DEFAULT_FOV) * speedRatio

-- 		camera.FieldOfView = camera.FieldOfView + (targetFOV - camera.FieldOfView) * 0.1
-- 	end)

-- 	slideConnection = RunService.Heartbeat:Connect(function()
-- 		if not _G.Sliding then return end

-- 		-- Check for perfect slide condition
-- 		local perfectCondition = isPerfectSlideCondition()

-- 		if perfectCondition then
-- 			-- Freeze the velocity on first frame of perfect condition
-- 			if not frozenSlideVelocity then
-- 				frozenSlideVelocity = slideVelocity
-- 				lastPosition = humanoidRootPart.Position
-- 				lastPositionCheckTime = tick()
-- 			end

-- 			-- Check if we've hit a wall (position change is too low)
-- 			local currentTime = tick()
-- 			if currentTime - lastPositionCheckTime >= positionCheckInterval then
-- 				local currentPosition = humanoidRootPart.Position
-- 				local positionChange = (currentPosition - lastPosition).Magnitude

-- 				if positionChange < minPositionChange then
-- 					-- Wall hit detected, stop the slide
-- 					stopSlide()
-- 					return
-- 				end

-- 				lastPosition = currentPosition
-- 				lastPositionCheckTime = currentTime
-- 			end

-- 			-- Keep the velocity completely frozen
-- 			slideVelocity = frozenSlideVelocity

-- 			if bodyVelocity and bodyVelocity.Parent then
-- 				bodyVelocity.Velocity = frozenSlideVelocity
-- 			end
-- 		else
-- 			-- Reset frozen velocity when conditions are no longer met
-- 			frozenSlideVelocity = nil
-- 			lastPosition = nil
-- 			lastPositionCheckTime = 0

-- 			-- POWER CURVE DECELERATION (replaces exponential decay)
-- 			local elapsedTime = tick() - slideStartTime
-- 			local slideProgress = math.min(elapsedTime / Config.SLIDE_DURATION, 1)

-- 			-- Power curve: maintains speed, then drops sharply near the end
-- 			local speedFactor = (1 - slideProgress) ^ Config.SLIDE_POWER
-- 			local targetSpeed = Config.SLIDE_END_SPEED + (Config.SLIDE_INITIAL_SPEED - Config.SLIDE_END_SPEED) * speedFactor

-- 			-- Update slide velocity magnitude while maintaining direction
-- 			local slideDirection = slideVelocity.Unit
-- 			slideVelocity = slideDirection * targetSpeed

-- 			-- Camera direction influence
-- 			local cameraCFrame = camera.CFrame
-- 			local cameraDirection = Vector3.new(cameraCFrame.LookVector.X, 0, cameraCFrame.LookVector.Z).Unit

-- 			if slideVelocity.Unit:Dot(cameraDirection) > 0.3 then
-- 				slideVelocity = slideVelocity:Lerp(cameraDirection * slideVelocity.Magnitude, 0.05)
-- 			end

-- 			-- Stop slide when duration is reached or speed is too low
-- 			if slideProgress >= 1 or slideVelocity.Magnitude < Config.SLIDE_END_SPEED then
-- 				stopSlide()
-- 				return
-- 			end

-- 			if bodyVelocity and bodyVelocity.Parent then
-- 				bodyVelocity.Velocity = slideVelocity
-- 			end
-- 		end
-- 	end)
-- end

-- local function standUp()
-- 	if not isEnabled or not _G.Crouching or _G.Sliding then return end
-- 	_G.Crouching = false
-- 	tweenCameraOffset(Config.STAND_OFFSET)

-- 	AnimationService:stopAnimation("Crouch")
-- end

-- local function cleanupSlideState()
-- 	if _G.Sliding then stopSlide() end

-- 	if _G.Crouching then
-- 		_G.Crouching = false
-- 		tweenCameraOffset(Config.STAND_OFFSET)
-- 		AnimationService:stopAnimation("Crouch")
-- 	end

-- 	cancelCurrentTween()
-- 	cancelFOVTween()
-- 	cancelTiltTween()

-- 	if fovUpdateConnection then fovUpdateConnection:Disconnect(); fovUpdateConnection = nil end

-- 	camera.FieldOfView = Config.DEFAULT_FOV
-- 	currentCameraRoll = 0
-- 	targetCameraRoll = 0
-- 	lastPosition = nil
-- 	frozenSlideVelocity = nil
-- 	lastPositionCheckTime = 0

-- 	AnimationService:stopAnimation("Slide")
-- 	AnimationService:stopAnimation("Crouch")
-- end

-- local function disconnectCharacterConnections()
-- 	for _, connection in ipairs(characterConnections) do
-- 		connection:Disconnect()
-- 	end
-- 	characterConnections = {}
-- end

-- local function setupCharacter(char)
-- 	disconnectCharacterConnections()
-- 	cleanupSlideState()

-- 	character = char
-- 	humanoid = character:WaitForChild("Humanoid")
-- 	humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- 	table.insert(characterConnections, humanoid.Jumping:Connect(function()
-- 		if _G.Sliding and isEnabled then stopSlide() end
-- 	end))

-- 	table.insert(characterConnections, humanoid.Died:Connect(cleanupSlideState))
-- end

-- local function setupContextActions()
-- 	-- Slide/Crouch action
-- 	ContextActionService:BindAction(
-- 		ACTIONS.SlideOrCrouch,
-- 		function(actionName, inputState, inputObject)
-- 			if not isEnabled then return Enum.ContextActionResult.Pass end

-- 			if inputState == Enum.UserInputState.Begin then
-- 				if not humanoidRootPart then return Enum.ContextActionResult.Pass end
-- 				local currentSpeed = humanoidRootPart.AssemblyLinearVelocity.Magnitude

-- 				if currentSpeed >= Config.SLIDE_SPEED_THRESHOLD and not _G.Sliding then
-- 					startSlide()
-- 				elseif not _G.Sliding and not _G.Crouching then
-- 					crouch()
-- 				end
-- 			elseif inputState == Enum.UserInputState.End then
-- 				if _G.Crouching and not _G.Sliding then
-- 					standUp()
-- 				end
-- 			end

-- 			return Enum.ContextActionResult.Sink
-- 		end,
-- 		false,
-- 		Enum.KeyCode.C,
-- 		Enum.KeyCode.ButtonL3
-- 	)
	
-- 	Crouch.Activated:Connect(function()
-- 		local currentSpeed = humanoidRootPart.AssemblyLinearVelocity.Magnitude

-- 		if currentSpeed >= Config.SLIDE_SPEED_THRESHOLD and not _G.Sliding then
-- 			startSlide()
-- 		elseif not _G.Sliding and not _G.Crouching then
-- 			crouch()
-- 		end
-- 	end)
	
-- 	Crouch.MouseButton1Up:Connect(function()
-- 		if _G.Crouching and not _G.Sliding then
-- 			standUp()
-- 		end
-- 	end)

-- 	local function createMovementAction(actionName, keyCode, direction)
-- 		ContextActionService:BindAction(
-- 			actionName,
-- 			function(actionName, inputState, inputObject)
-- 				if not isEnabled then return Enum.ContextActionResult.Pass end

-- 				if inputState == Enum.UserInputState.Begin then
-- 					keysPressed[keyCode] = true
-- 				elseif inputState == Enum.UserInputState.End then
-- 					keysPressed[keyCode] = false
-- 				end

-- 				return Enum.ContextActionResult.Pass
-- 			end,
-- 			false, 
-- 			keyCode
-- 		)
-- 	end

-- 	createMovementAction(ACTIONS.MoveForward, Enum.KeyCode.W, "forward")
-- 	createMovementAction(ACTIONS.MoveBackward, Enum.KeyCode.S, "backward")
-- 	createMovementAction(ACTIONS.MoveLeft, Enum.KeyCode.A, "left")
-- 	createMovementAction(ACTIONS.MoveRight, Enum.KeyCode.D, "right")
-- end

-- local function unbindContextActions()
-- 	for _, actionName in pairs(ACTIONS) do
-- 		ContextActionService:UnbindAction(actionName)
-- 	end
-- end

-- function SlideComponent:Enable()
-- 	isEnabled = true
-- 	setupContextActions()
-- end

-- function SlideComponent:Disable()
-- 	isEnabled = false
-- 	unbindContextActions()
-- 	cleanupSlideState()
-- end

-- function SlideComponent:IsEnabled()
-- 	return isEnabled
-- end

-- function SlideComponent:Initialize()
-- 	player = Players.LocalPlayer
-- 	camera = workspace.CurrentCamera

-- 	setupCharacter(player.Character or player.CharacterAdded:Wait())

-- 	table.insert(permanentConnections, player.CharacterAdded:Connect(function(char)
-- 		setupCharacter(char)
-- 		if isEnabled then
-- 			unbindContextActions()
-- 			setupContextActions()
-- 		end
-- 	end))

-- 	table.insert(permanentConnections, RunService.RenderStepped:Connect(function()
-- 		currentCameraRoll += (targetCameraRoll - currentCameraRoll) * 0.3
-- 		if math.abs(currentCameraRoll) > 0.01 then
-- 			camera.CFrame *= CFrame.Angles(0, 0, math.rad(currentCameraRoll))
-- 		end
-- 	end))

-- 	table.insert(permanentConnections, NetworkSubscriptionService:Subscribe("CreateViewmodel"):Connect(function()
-- 		SlideComponent:Enable()
-- 	end))

-- 	table.insert(permanentConnections, NetworkSubscriptionService:Subscribe("DestroyViewmodel"):Connect(function()
-- 		SlideComponent:Disable()
-- 	end))
-- end

-- function SlideComponent:Destroy()
-- 	unbindContextActions()

-- 	for _, connection in ipairs(permanentConnections) do
-- 		connection:Disconnect()
-- 	end
-- 	permanentConnections = {}

-- 	disconnectCharacterConnections()
-- 	cleanupSlideState()
-- end

-- return SlideComponent