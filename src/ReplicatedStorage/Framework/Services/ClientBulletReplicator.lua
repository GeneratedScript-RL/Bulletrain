--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Network = require(ReplicatedStorage.Shared.Network.Network)
local FastCast = require(ReplicatedStorage.Shared.ThirdParty.FastCast)

local PELLETS = 8
local RANGE = 400
local MUZZLE_VELOCITY = 1500
local SPREAD_DEGREES = 6

local function applySpread(direction: Vector3, spreadDegrees: number): Vector3
	local spreadRad = math.rad(spreadDegrees)
	local yaw = (math.random() - 0.5) * 2 * spreadRad
	local pitch = (math.random() - 0.5) * 2 * spreadRad
	local cf = CFrame.lookAt(Vector3.zero, direction)
	local spread = CFrame.Angles(pitch, yaw, 0)
	return (cf * spread).LookVector
end

local ClientBulletReplicator = {}
ClientBulletReplicator.__index = ClientBulletReplicator

function ClientBulletReplicator:Initialize()
	assert(RunService:IsClient(), "ClientBulletReplicator must run on the client")

	local caster = FastCast.new()
	local behavior = FastCast.newBehavior()
	behavior.MaxDistance = RANGE

	local camera = workspace.CurrentCamera
	local cosmeticFolder = Instance.new("Folder")
	cosmeticFolder.Name = "ReplicatedBulletCosmetics"
	cosmeticFolder.Parent = camera

	behavior.CosmeticBulletContainer = cosmeticFolder
	behavior.CosmeticBulletTemplate = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Bullet")

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	behavior.RaycastParams = params

	caster.LengthChanged:Connect(function(_cast, lastPoint: Vector3, rayDir: Vector3, rayDisplacement: number, _segVel: Vector3, bullet: Instance?)
		if bullet and bullet:IsA("BasePart") then
			bullet.CFrame = CFrame.new(lastPoint, lastPoint + rayDir) * CFrame.new(0, 0, -rayDisplacement / 2)
		end
	end)

	caster.RayHit:Connect(function(_activeCast, _result, _vel, bullet)
		if bullet and bullet:IsA("BasePart") then
			Debris:AddItem(bullet, 1)
		end
	end)

	local localPlayer = Players.LocalPlayer

	Network:SubscribeToUnreliablePacket("ReplicateShotgunBullet"):Connect(function(shooterUserId: number, origin: Vector3, direction: Vector3)
		-- Skip our own shots — they are already rendered locally by Shotgun.lua
		if shooterUserId == localPlayer.UserId then
			return
		end

		-- Exclude local player and shooter from the cosmetic raycast
		local filterList = {}
		local char = localPlayer.Character
		if char then
			table.insert(filterList, char)
		end
		for _, p in ipairs(Players:GetPlayers()) do
			if p.UserId == shooterUserId and p.Character then
				table.insert(filterList, p.Character)
				break
			end
		end
		params.FilterDescendantsInstances = filterList

		for _ = 1, PELLETS do
			local dir = applySpread(direction, SPREAD_DEGREES)
			caster:Fire(origin, dir, MUZZLE_VELOCITY, behavior)
		end
	end)
end

return setmetatable({}, ClientBulletReplicator)
