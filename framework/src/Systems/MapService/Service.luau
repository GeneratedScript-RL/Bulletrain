--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkServer = require(root) :: any

local MAP_CONTAINER_NAME = "ActiveMap"

local MapService = framework.CreateService({
	Name = "MapService",
})

MapService._currentMap = nil :: Model?

local function getMapsFolder(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		warn("[MapService] ReplicatedStorage.Assets not found")
		return nil
	end

	local maps = assets:FindFirstChild("Maps")
	if not maps or not maps:IsA("Folder") then
		warn("[MapService] ReplicatedStorage.Assets.Maps not found")
		return nil
	end

	return maps
end

function MapService:UnloadCurrentMap()
	if self._currentMap then
		self._currentMap:Destroy()
		self._currentMap = nil
	end
end

function MapService:LoadMap(mapName: string): Model?
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

function MapService:GetCurrentMap(): Model?
	return self._currentMap
end

function MapService:GetSpawnPoints(): { BasePart }
	local currentMap = self._currentMap
	if not currentMap then
		return {}
	end

	local spawns = currentMap:FindFirstChild("Spawns")
	if not spawns or not spawns:IsA("Folder") then
		warn("[MapService] Current map missing Folder 'Spawns'")
		return {}
	end

	local points: { BasePart } = {}
	for _, descendant in spawns:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(points, descendant)
		end
	end

	return points
end

return MapService
