--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type MarkerCallbacks = {[string]: (...any) -> ()}

local AnimationService = {}
AnimationService.__index = AnimationService

local function getOrCreateAnimator(container: Instance): Animator?
	if container:IsA("Humanoid") then
		return container:FindFirstChildOfClass("Animator")
	end
	if container:IsA("AnimationController") then
		local animator = container:FindFirstChildOfClass("Animator")
		if animator then
			return animator
		end
		animator = Instance.new("Animator")
		animator.Parent = container
		return animator
	end
	return nil
end

local function findAnimation(folder: Instance, animName: string): Animation?
	local inst = folder:FindFirstChild(animName)
	if inst and inst:IsA("Animation") then
		return inst
	end
	return nil
end

function AnimationService:PlayAnimation(target: Instance, animName: string, priority: Enum.AnimationPriority, fadeTime: number?, markerCallbacks: MarkerCallbacks?)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		warn("[AnimationService] ReplicatedStorage.Assets missing")
		return nil
	end

	local isViewmodel = target:IsDescendantOf(workspace.CurrentCamera)
	local folderName = isViewmodel and "ViewmodelAnimations" or "AvatarAnimations"
	local animFolder = assets:FindFirstChild(folderName)
	if not animFolder then
		warn(("[AnimationService] Assets.%s missing"):format(folderName))
		return nil
	end

	local animation = findAnimation(animFolder, animName)
	if not animation then
		warn(("[AnimationService] Animation '%s' not found in Assets.%s"):format(animName, folderName))
		return nil
	end

	local animator = getOrCreateAnimator(target)
	if not animator then
		warn("[AnimationService] Could not resolve Animator for target")
		return nil
	end

	local track = animator:LoadAnimation(animation)
	track.Priority = priority
	track:Play(fadeTime or 0.1)

	if markerCallbacks then
		for markerName, cb in pairs(markerCallbacks) do
			track:GetMarkerReachedSignal(markerName):Connect(cb)
		end
	end

	return track
end

return setmetatable({}, AnimationService)
