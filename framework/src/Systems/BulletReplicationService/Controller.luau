--!strict

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local FastCast = require(root.Shared.ThirdParty.FastCast)
local CombatConfig = require(root.Systems.CombatService.Shared.Config)

local combatService: any

local BulletReplicationController = framework.CreateController({
	Name = "BulletReplicationController",
})

local function getCurrentCamera(): Camera
	local currentCamera = workspace.CurrentCamera
	while not currentCamera do
		workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
		currentCamera = workspace.CurrentCamera
	end

	return currentCamera
end

local function applySpread(direction: Vector3, spreadDegrees: number): Vector3
	local spreadRadians = math.rad(spreadDegrees)
	local yaw = (math.random() - 0.5) * 2 * spreadRadians
	local pitch = (math.random() - 0.5) * 2 * spreadRadians
	local base = CFrame.lookAt(Vector3.zero, direction)
	return (base * CFrame.Angles(pitch, yaw, 0)).LookVector
end

function BulletReplicationController:Init()
	combatService = framework.GetService("CombatService")
end

function BulletReplicationController:Start()
	assert(RunService:IsClient(), "BulletReplicationController must run on the client")

	local caster = FastCast.new()
	local behavior = FastCast.newBehavior()
	behavior.MaxDistance = CombatConfig.Shotgun.Range

	local camera = getCurrentCamera()
	local cosmeticFolder = Instance.new("Folder")
	cosmeticFolder.Name = "ReplicatedBulletCosmetics"
	cosmeticFolder.Parent = camera

	behavior.CosmeticBulletContainer = cosmeticFolder
	behavior.CosmeticBulletTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Bullet")

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	behavior.RaycastParams = params

	caster.LengthChanged:Connect(function(_cast, lastPoint: Vector3, rayDirection: Vector3, rayDisplacement: number, _segmentVelocity: Vector3, bullet: Instance?)
		if bullet and bullet:IsA("BasePart") then
			bullet.CFrame = CFrame.new(lastPoint, lastPoint + rayDirection) * CFrame.new(0, 0, -rayDisplacement / 2)
		end
	end)

	caster.RayHit:Connect(function(_activeCast, _result, _velocity, bullet)
		if bullet and bullet:IsA("BasePart") then
			Debris:AddItem(bullet, 1)
		end
	end)

	local localPlayer = Players.LocalPlayer
	combatService.ReplicateShotgunBullet:Connect(function(shooterUserId: number, origin: Vector3, direction: Vector3)
		if shooterUserId == localPlayer.UserId then
			return
		end

		local filterList = {}
		local localCharacter = localPlayer.Character
		if localCharacter then
			table.insert(filterList, localCharacter)
		end

		for _, player in Players:GetPlayers() do
			if player.UserId == shooterUserId and player.Character then
				table.insert(filterList, player.Character)
				break
			end
		end

		params.FilterDescendantsInstances = filterList

		for _ = 1, CombatConfig.Shotgun.Pellets do
			local rayDirection = applySpread(direction, CombatConfig.Shotgun.SpreadDegrees)
			caster:Fire(origin, rayDirection, CombatConfig.Shotgun.MuzzleVelocity, behavior)
		end
	end)
end

return BulletReplicationController
