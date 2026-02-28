--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Network = require(ReplicatedStorage.Shared.Network.Network)
local FastCast = require(ReplicatedStorage.Shared.ThirdParty.FastCast)

local Shotgun = {}
Shotgun.__index = Shotgun

Shotgun.Name = "Shotgun"

local PELLETS = 8
local RANGE = 400
local MUZZLE_VELOCITY = 800
local SPREAD_DEGREES = 6

local function applySpread(direction: Vector3, spreadDegrees: number): Vector3
	local spreadRad = math.rad(spreadDegrees)
	local yaw = (math.random() - 0.5) * 2 * spreadRad
	local pitch = (math.random() - 0.5) * 2 * spreadRad
	local cf = CFrame.lookAt(Vector3.zero, direction)
	local spread = CFrame.Angles(pitch, yaw, 0)
	return (cf * spread).LookVector
end

local function makeCosmeticBulletTemplate(): BasePart
	local p = Instance.new("Part")
	p.Size = Vector3.new(0.1, 0.1, 1)
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 225, 150)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Name = "Pellet"
	return p
end

function Shotgun.new(localPlayer: Player, camera: Camera)
	local self = setmetatable({}, Shotgun)
	self._player = localPlayer
	self._camera = camera
	self._caster = FastCast.new()
	self._behavior = FastCast.newBehavior()
	self._behavior.MaxDistance = RANGE
	self._behavior.Acceleration = Vector3.new(0, 0, 0)
	self._behavior.HighFidelityBehavior = FastCast.HighFidelityBehavior.Default
	self._behavior.HighFidelitySegmentSize = 1
	self._behavior.CanPierceFunction = function()
		return false
	end

	self._cosmeticFolder = Instance.new("Folder")
	self._cosmeticFolder.Name = "ShotgunCosmetics"
	self._cosmeticFolder.Parent = camera

	self._behavior.CosmeticBulletContainer = self._cosmeticFolder
	self._behavior.CosmeticBulletTemplate = makeCosmeticBulletTemplate()

	-- Cosmetic updates
	self._caster.LengthChanged:Connect(function(_cast, lastPoint: Vector3, rayDir: Vector3, rayDisplacement: number, _segVel: Vector3, bullet: Instance?)
		if bullet and bullet:IsA("BasePart") then
			bullet.CFrame = CFrame.new(lastPoint, lastPoint + rayDir) * CFrame.new(0, 0, -rayDisplacement / 2)
		end
	end)
	self._caster.CastTerminating:Connect(function(activeCast)
		local bullet = activeCast.RayInfo and activeCast.RayInfo.CosmeticBulletObject
		if bullet then
			bullet:Destroy()
		end
	end)

	return self
end

function Shotgun:PrimaryFire()
	local origin = self._camera.CFrame.Position
	local direction = self._camera.CFrame.LookVector

	-- Authoritative damage on server
	Network:FireRemoteToServer("ShotgunFire", origin, direction)

	-- Cosmetic pellets locally (FastCast)
	if RunService:IsClient() then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = {}
		if self._player.Character then
			ignore[1] = self._player.Character
		end
		params.FilterDescendantsInstances = ignore
		params.IgnoreWater = true
		self._behavior.RaycastParams = params

		for _ = 1, PELLETS do
			local dir = applySpread(direction, SPREAD_DEGREES)
			self._caster:Fire(origin, dir, MUZZLE_VELOCITY, self._behavior)
		end
	end
end

function Shotgun:Destroy()
	if self._cosmeticFolder then
		self._cosmeticFolder:Destroy()
	end
end

return Shotgun
