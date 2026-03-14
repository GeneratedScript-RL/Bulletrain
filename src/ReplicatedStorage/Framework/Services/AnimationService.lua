--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

export type MarkerCallbacks = {[string]: (...any) -> ()}
export type AnimationCache = {
	Avatar: {[string]: AnimationTrack},
	Viewmodel: {[string]: AnimationTrack},
}

local AnimationService = {}
AnimationService.__index = AnimationService

-- Cache table stored on the service itself
local self_data = {
	AnimationTracks = {
		Avatar = {} :: {[string]: AnimationTrack},
		Viewmodel = {} :: {[string]: AnimationTrack},
	} :: AnimationCache,
}

local function findAnimation(folder: Instance, animName: string): Animation?
	local inst = folder:FindFirstChild(animName)
	if inst and inst:IsA("Animation") then
		return inst
	end
	return nil
end

local function getAnimFolder(target: Instance): (Instance?, boolean)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		warn("[AnimationService] ReplicatedStorage.Assets missing")
		return nil, false
	end
	local isViewmodel = target:IsDescendantOf(workspace.CurrentCamera)
	local folderName = isViewmodel and "ViewmodelAnimations" or "AvatarAnimations"
	local animFolder = assets:FindFirstChild(folderName)
	if not animFolder then
		warn(("[AnimationService] Assets.%s missing"):format(folderName))
		return nil, isViewmodel
	end
	return animFolder, isViewmodel
end

local function resolveAnimator(target: Instance): (Animator | AnimationController)?
	local animator = target:FindFirstChildOfClass("Animator") or target:FindFirstChildWhichIsA("Humanoid") or target:FindFirstChildWhichIsA("AnimationController")
	if not animator then
		warn("[AnimationService] Could not resolve Animator for target")
		return nil
	end
	if animator:IsA("Humanoid") then
		animator = animator:FindFirstChildOfClass("Animator") or animator:FindFirstChildWhichIsA("AnimationController")
	end
	if not animator then
		warn("[AnimationService] Could not resolve Animator from Humanoid")
		return nil
	end
	return animator :: Animator | AnimationController
end

-- Internal helper that plays and caches a track
local function loadAndPlay(
	target: Instance,
	animName: string,
	priority: Enum.AnimationPriority,
	looped: boolean?,
	markerCallbacks: MarkerCallbacks?,
	isViewmodel: boolean,
	animation: Animation,
	animator: Animator | AnimationController
): AnimationTrack?
	-- Check cache first
	local cacheKey = animName
	local cache = isViewmodel and self_data.AnimationTracks.Viewmodel or self_data.AnimationTracks.Avatar

	local cached = cache[cacheKey]
	if cached then
		-- Reuse existing track if still valid
		cached.Priority = priority
		cached.Looped = looped or false
		cached:Play()
		return cached
	end

	local track = (animator :: any):LoadAnimation(animation)
	track.Priority = priority
	track.Looped = looped or false
	track:Play()

	-- Store in cache
	cache[cacheKey] = track

	-- Clean up cache entry when track is destroyed/stopped
	track.Stopped:Connect(function()
		if cache[cacheKey] == track then
			cache[cacheKey] = nil
		end
	end)

	if markerCallbacks then
		for markerName, cb in pairs(markerCallbacks) do
			track:GetMarkerReachedSignal(markerName):Connect(cb)
		end
	end

	return track
end

function AnimationService:PlayAnimation(
	target: Instance,
	animName: string,
	priority: Enum.AnimationPriority,
	looped: boolean?,
	markerCallbacks: MarkerCallbacks?
): AnimationTrack?
	
	local animFolder, isViewmodel = getAnimFolder(target)
	if not animFolder then return nil end

	local animation = findAnimation(animFolder :: Instance, animName)
	if not animation then
		warn(("[AnimationService] Animation '%s' not found"):format(animName))
		return nil
	end

	local animator = resolveAnimator(target)
	if not animator then return nil end

	return loadAndPlay(target, animName, priority, looped, markerCallbacks, isViewmodel, animation, animator)
end

-- Plays an animation on the local player's character avatar
function AnimationService:PlayAnimationToAvatar(
	animName: string,
	priority: Enum.AnimationPriority,
	looped: boolean?,
	markerCallbacks: MarkerCallbacks?
): AnimationTrack?
	
	local player = Players.LocalPlayer
	local character = player and player.Character
	if not character then
		warn("[AnimationService] LocalPlayer character not found")
		return nil
	end
	
	return self:PlayAnimation(character, animName, priority, looped, markerCallbacks)
end

-- Plays an animation on the viewmodel (CurrentCamera child named "Viewmodel")
function AnimationService:PlayAnimationToViewmodel(
	animName: string,
	priority: Enum.AnimationPriority,
	looped: boolean?,
	markerCallbacks: MarkerCallbacks?
): AnimationTrack?
	
	local viewmodel = workspace.CurrentCamera:FindFirstChild("Viewmodel")
	if not viewmodel then
		warn("[AnimationService] Viewmodel not found in CurrentCamera")
		return nil
	end
	return self:PlayAnimation(viewmodel, animName, priority, looped, markerCallbacks)
end

function AnimationService:GetAnimation(
	target: Instance,
	animName: string,
	priority: Enum.AnimationPriority?,
	looped: boolean?
): AnimationTrack?
	
	local animFolder, isViewmodel = getAnimFolder(target)
	if not animFolder then return nil end

	local animation = findAnimation(animFolder :: Instance, animName)
	if not animation then
		warn(("[AnimationService] Animation '%s' not found"):format(animName))
		return nil
	end

	local animator = target:FindFirstChildOfClass("Animator")
	if not animator then
		warn("[AnimationService] Could not resolve Animator for target")
		return nil
	end

	-- Check cache
	local cache = isViewmodel and self_data.AnimationTracks.Viewmodel or self_data.AnimationTracks.Avatar
	local cached = cache[animName]
	if cached then
		return cached
	end

	local track = animator:LoadAnimation(animation)
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

-- Read-only access to the cache for external inspection
function AnimationService:GetCache(): AnimationCache
	return self_data.AnimationTracks
end

return setmetatable(self_data, AnimationService)