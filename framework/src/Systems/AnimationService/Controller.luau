--!strict

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

export type MarkerCallbacks = { [string]: (...any) -> () }
export type AnimationCache = {
	Avatar: { [string]: AnimationTrack },
	Viewmodel: { [string]: AnimationTrack },
}

local AnimationServiceController = framework.CreateController({
	Name = "AnimationController",
})

AnimationServiceController._animationTracks = {
	Avatar = {} :: { [string]: AnimationTrack },
	Viewmodel = {} :: { [string]: AnimationTrack },
} :: AnimationCache

local function findAnimation(folder: Instance, animName: string): Animation?
	local instance = folder:FindFirstChild(animName)
	if instance and instance:IsA("Animation") then
		return instance
	end

	return nil
end

local function getAnimFolder(target: Instance): (Instance?, boolean)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		warn("[AnimationController] ReplicatedStorage.Assets missing")
		return nil, false
	end

	local currentCamera = workspace.CurrentCamera
	local isViewmodel = currentCamera ~= nil and target:IsDescendantOf(currentCamera)
	local folderName = if isViewmodel then "ViewmodelAnimations" else "AvatarAnimations"
	local animFolder = assets:FindFirstChild(folderName)
	if not animFolder then
		warn(("[AnimationController] Assets.%s missing"):format(folderName))
		return nil, isViewmodel
	end

	return animFolder, isViewmodel
end

local function resolveAnimator(target: Instance): (Animator | AnimationController)?
	if target:IsA("AnimationController") then
		return target
	end

	if target:IsA("Humanoid") then
		return target:FindFirstChildOfClass("Animator") or target:FindFirstChildWhichIsA("AnimationController")
	end

	local animator = target:FindFirstChildOfClass("Animator")
	if animator then
		return animator
	end

	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid:FindFirstChildOfClass("Animator") or humanoid:FindFirstChildWhichIsA("AnimationController")
	end

	return target:FindFirstChildWhichIsA("AnimationController")
end

local function loadAndPlay(
	self: typeof(AnimationServiceController),
	animName: string,
	priority: Enum.AnimationPriority,
	looped: boolean?,
	markerCallbacks: MarkerCallbacks?,
	isViewmodel: boolean,
	animation: Animation,
	animator: Animator | AnimationController
): AnimationTrack?
	local cache = if isViewmodel then self._animationTracks.Viewmodel else self._animationTracks.Avatar
	local cached = cache[animName]
	if cached then
		cached.Priority = priority
		cached.Looped = looped or false
		cached:Play()
		return cached
	end

	local track = (animator :: any):LoadAnimation(animation)
	track.Priority = priority
	track.Looped = looped or false
	track:Play()

	cache[animName] = track
	track.Stopped:Connect(function()
		if cache[animName] == track then
			cache[animName] = nil
		end
	end)

	if markerCallbacks then
		for markerName, callback in markerCallbacks do
			track:GetMarkerReachedSignal(markerName):Connect(callback)
		end
	end

	return track
end

function AnimationServiceController:PlayAnimation(
	target: Instance,
	animName: string,
	priority: Enum.AnimationPriority,
	looped: boolean?,
	markerCallbacks: MarkerCallbacks?
): AnimationTrack?
	local animFolder, isViewmodel = getAnimFolder(target)
	if not animFolder then
		return nil
	end

	local animation = findAnimation(animFolder, animName)
	if not animation then
		warn(("[AnimationController] Animation '%s' not found"):format(animName))
		return nil
	end

	local animator = resolveAnimator(target)
	if not animator then
		warn("[AnimationController] Could not resolve animator for target")
		return nil
	end

	return loadAndPlay(self, animName, priority, looped, markerCallbacks, isViewmodel, animation, animator)
end

function AnimationServiceController:PlayAnimationToAvatar(
	animName: string,
	priority: Enum.AnimationPriority,
	looped: boolean?,
	markerCallbacks: MarkerCallbacks?
): AnimationTrack?
	local character = Players.LocalPlayer.Character
	if not character then
		warn("[AnimationController] LocalPlayer character not found")
		return nil
	end

	return self:PlayAnimation(character, animName, priority, looped, markerCallbacks)
end

function AnimationServiceController:PlayAnimationToViewmodel(
	animName: string,
	priority: Enum.AnimationPriority,
	looped: boolean?,
	markerCallbacks: MarkerCallbacks?
): AnimationTrack?
	local currentCamera = workspace.CurrentCamera
	if not currentCamera then
		warn("[AnimationController] CurrentCamera missing")
		return nil
	end

	local viewmodel = currentCamera:FindFirstChild("Viewmodel")
	if not viewmodel then
		warn("[AnimationController] Viewmodel not found in CurrentCamera")
		return nil
	end

	return self:PlayAnimation(viewmodel, animName, priority, looped, markerCallbacks)
end

function AnimationServiceController:GetAnimation(
	target: Instance,
	animName: string,
	priority: Enum.AnimationPriority?,
	looped: boolean?
): AnimationTrack?
	local animFolder, isViewmodel = getAnimFolder(target)
	if not animFolder then
		return nil
	end

	local animation = findAnimation(animFolder, animName)
	if not animation then
		warn(("[AnimationController] Animation '%s' not found"):format(animName))
		return nil
	end

	local animator = resolveAnimator(target)
	if not animator then
		warn("[AnimationController] Could not resolve animator for target")
		return nil
	end

	local cache = if isViewmodel then self._animationTracks.Viewmodel else self._animationTracks.Avatar
	local cached = cache[animName]
	if cached then
		return cached
	end

	local track = (animator :: any):LoadAnimation(animation)
	track.Priority = priority or Enum.AnimationPriority.Core
	track.Looped = looped or false

	cache[animName] = track
	track.Stopped:Connect(function()
		if cache[animName] == track then
			cache[animName] = nil
		end
	end)

	return track
end

function AnimationServiceController:GetCache(): AnimationCache
	return self._animationTracks
end

local function preloadFromFolder(folder: Instance)
	task.spawn(function()
		for _, descendant in folder:GetDescendants() do
			if descendant:IsA("Animation") then
				ContentProvider:PreloadAsync({ descendant })
			end
		end
	end)
end

function AnimationServiceController:Start()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		warn("[AnimationController] ReplicatedStorage.Assets missing, cannot preload animations")
		return
	end

	local avatarFolder = assets:FindFirstChild("AvatarAnimations")
	if avatarFolder then
		preloadFromFolder(avatarFolder)
	else
		warn("[AnimationController] Assets.AvatarAnimations missing")
	end

	local viewmodelFolder = assets:FindFirstChild("ViewmodelAnimations")
	if viewmodelFolder then
		preloadFromFolder(viewmodelFolder)
	else
		warn("[AnimationController] Assets.ViewmodelAnimations missing")
	end
end

return AnimationServiceController
