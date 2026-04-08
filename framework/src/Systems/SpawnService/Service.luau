--!strict

local Players = game:GetService("Players")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkServer = require(root) :: any

local mapService: { GetSpawnPoints: (self: any) -> { BasePart } }

local SpawnService = framework.CreateService({
	Name = "SpawnService",
	Dependencies = { "MapService" },
})

local function chooseSpawn(spawns: { BasePart }): BasePart?
	if #spawns == 0 then
		return nil
	end

	return spawns[math.random(1, #spawns)]
end

function SpawnService:SpawnPlayer(player: Player)
	local spawnPart = chooseSpawn(mapService:GetSpawnPoints())

	player:LoadCharacter()
	local character = player.Character or player.CharacterAdded:Wait()
	if not character then
		return
	end

	if spawnPart then
		character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
	else
		warn("[SpawnService] No spawns available; spawned at default")
	end
end

function SpawnService:SpawnAll()
	for _, player in Players:GetPlayers() do
		self:SpawnPlayer(player)
	end
end

function SpawnService:Init()
	Players.CharacterAutoLoads = false
	mapService = framework.GetService("MapService") :: any
end

return SpawnService
