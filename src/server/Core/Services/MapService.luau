--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapService = {}
MapService.__index = MapService

local MAP_CONTAINER_NAME = "ActiveMap"

function MapService.new()
	local self = setmetatable({}, MapService)
	self._currentMap = nil :: Model?
	return self
end

local singleton = MapService.new()

local function getMapsFolder(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		warn("[MapService] ReplicatedStorage.Assets not found (expected user-provided assets)")
		return nil
	end
	local maps = assets:FindFirstChild("Maps")
	if not maps or not maps:IsA("Folder") then
		warn("[MapService] ReplicatedStorage.Assets.Maps not found")
		return nil
	end
	return maps
end

function singleton:UnloadCurrentMap()
	if self._currentMap then
		self._currentMap:Destroy()
		self._currentMap = nil
	end
end

function singleton:LoadMap(mapName: string): Model?
	self:UnloadCurrentMap()

	local maps = getMapsFolder()
	if not maps then
		return nil
	end

	local template = maps:FindFirstChild(mapName)
	if not template or not template:IsA("Model") then
		warn(("[MapService] Map '%s' not found under Assets.Maps"):format(mapName))
		return nil
	end

	local mapClone = template:Clone()
	mapClone.Name = MAP_CONTAINER_NAME
	mapClone.Parent = Workspace
	self._currentMap = mapClone
	return mapClone
end

function singleton:GetCurrentMap(): Model?
	return self._currentMap
end

function singleton:GetSpawnPoints(): {BasePart}
	if not self._currentMap then
		return {}
	end
	local spawns = self._currentMap:FindFirstChild("spawns")
	if not spawns or not spawns:IsA("Folder") then
		warn("[MapService] Current map missing Folder 'spawns'")
		return {}
	end

	local points = {}
	for _, inst in ipairs(spawns:GetDescendants()) do
		if inst:IsA("BasePart") then
			table.insert(points, inst)
		end
	end
	return points
end

return singleton
