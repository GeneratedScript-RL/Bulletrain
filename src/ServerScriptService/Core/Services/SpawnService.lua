--!strict

local Players = game:GetService("Players")

local MapService = require(script.Parent.MapService)

local SpawnService = {}
SpawnService.__index = SpawnService

function SpawnService:Initialize()
	Players.CharacterAutoLoads = false
end

local function chooseSpawn(spawns: {BasePart}): BasePart?
	if #spawns == 0 then
		return nil
	end
	return spawns[math.random(1, #spawns)]
end

function SpawnService:SpawnPlayer(player: Player)
	local spawns = MapService:GetSpawnPoints()
	local spawnPart = chooseSpawn(spawns)

	player:LoadCharacter()
	local character = player.Character
	if not character then
		return
	end

	if spawnPart then
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
		end
	else
		warn("[SpawnService] No spawns available; spawned at default")
	end
end

function SpawnService:SpawnAll()
	for _, player in ipairs(Players:GetPlayers()) do
		self:SpawnPlayer(player)
	end
end

return setmetatable({}, SpawnService)
