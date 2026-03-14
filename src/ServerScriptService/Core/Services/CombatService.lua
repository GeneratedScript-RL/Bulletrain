--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network.Network)

local PlayerStateService = require(script.Parent.PlayerStateService)
local ScoreService = require(script.Parent.ScoreService)
local DataService = require(script.Parent.DataService)

local CombatService = {}
CombatService.__index = CombatService

local PACKET_SHOTGUN = "ShotgunFire"
local PACKET_KNIFE = "KnifeSwing"
local PACKET_PARRY_START = "KnifeParryStart"

local SHOTGUN_PELLETS = 8
local SHOTGUN_RANGE = 400
local SHOTGUN_PELLET_DAMAGE = 12
local SHOTGUN_SPREAD_DEGREES = 6

local KNIFE_RANGE = 7
local KNIFE_DAMAGE = 55

local PARRY_WINDOW = 0.3 -- seconds the parry deflection is active

local ASSIST_WINDOW = 8 -- seconds since last damage to count as an assist
local XP_PER_KILL = 25
local XP_PER_ASSIST = 10
local CREDITS_PER_KILL = 50

type ParryState = { startTime: number, successFired: boolean }

function CombatService.new()
	local self = setmetatable({}, CombatService)
	self._lastDamager = {} :: {[Humanoid]: Player}
	self._damageLog = {} :: {[Humanoid]: {[Player]: number}}
	self._parryingPlayers = {} :: {[Player]: ParryState}
	return self
end

local singleton = CombatService.new()

local function isAliveCharacter(character: Model?): boolean
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function getHumanoidFromHit(instance: Instance): Humanoid?
	local model = instance:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	return model:FindFirstChildOfClass("Humanoid")
end

function singleton:_tagDamage(victimHumanoid: Humanoid, attacker: Player)
	self._lastDamager[victimHumanoid] = attacker
end

function singleton:_recordDamage(victimHumanoid: Humanoid, attacker: Player)
	self:_tagDamage(victimHumanoid, attacker)
	local log = self._damageLog[victimHumanoid]
	if not log then
		log = {}
		self._damageLog[victimHumanoid] = log
	end
	log[attacker] = os.clock()
end

local function getPlayerFromHumanoid(h: Humanoid): Player?
	local character = h.Parent
	if character and character:IsA("Model") then
		return Players:GetPlayerFromCharacter(character)
	end
	return nil
end

function singleton:_onHumanoidDied(victimHumanoid: Humanoid)
	local victimPlayer = getPlayerFromHumanoid(victimHumanoid)
	if victimPlayer then
		DataService:AddDeath(victimPlayer)
	end

	local killer = self._lastDamager[victimHumanoid]
	if killer and killer.Parent == Players and killer ~= victimPlayer then
		ScoreService:IncrementKills(killer)
		DataService:AddKill(killer)
		DataService:AddXP(killer, XP_PER_KILL)
		DataService:AddCredits(killer, CREDITS_PER_KILL)
	end

	-- Assists: anyone (except killer) who damaged victim recently.
	local log = self._damageLog[victimHumanoid]
	if log then
		local now = os.clock()
		for assister, t in pairs(log) do
			if assister ~= killer and assister.Parent == Players then
				if (now - t) <= ASSIST_WINDOW then
					DataService:AddAssist(assister)
					DataService:AddXP(assister, XP_PER_ASSIST)
				end
			end
		end
	end

	self._lastDamager[victimHumanoid] = nil
	self._damageLog[victimHumanoid] = nil
end

function singleton:_wireCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	humanoid.Died:Connect(function()
		self:_onHumanoidDied(humanoid)
	end)
end

local function makeParamsForShooter(shooterCharacter: Model): RaycastParams
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { shooterCharacter }
	rp.IgnoreWater = true
	return rp
end

local function applySpread(direction: Vector3, spreadDegrees: number): Vector3
	local spreadRad = math.rad(spreadDegrees)
	local yaw = (math.random() - 0.5) * 2 * spreadRad
	local pitch = (math.random() - 0.5) * 2 * spreadRad
	local cf = CFrame.lookAt(Vector3.zero, direction)
	local spread = CFrame.Angles(pitch, yaw, 0)
	return (cf * spread).LookVector
end

function singleton:_fireShotgun(player: Player, origin: Vector3, direction: Vector3)
	local character = player.Character
	if not isAliveCharacter(character) then
		return
	end
	if PlayerStateService:GetState(player) ~= "Combat" then
		return
	end

	local params = makeParamsForShooter(character :: Model)

	for _ = 1, SHOTGUN_PELLETS do
		local dir = applySpread(direction, SHOTGUN_SPREAD_DEGREES)
		local result = workspace:Raycast(origin, dir.Unit * SHOTGUN_RANGE, params)
		if result then
			local humanoid = getHumanoidFromHit(result.Instance)
			if humanoid and humanoid.Health > 0 then
				local victimPlayer = getPlayerFromHumanoid(humanoid)
				local parryState = victimPlayer and self._parryingPlayers[victimPlayer]

				if parryState and (os.clock() - parryState.startTime) <= PARRY_WINDOW then
					-- Parry: redirect the pellet in the opposite direction
					local victimCharacter = (victimPlayer :: Player).Character
					if victimCharacter then
						local redirectParams = makeParamsForShooter(victimCharacter)
						local redirectResult = workspace:Raycast(result.Position, (-dir.Unit) * SHOTGUN_RANGE, redirectParams)
						if redirectResult then
							local redirectHumanoid = getHumanoidFromHit(redirectResult.Instance)
							if redirectHumanoid and redirectHumanoid.Health > 0 then
								self:_recordDamage(redirectHumanoid, victimPlayer :: Player)
								redirectHumanoid:TakeDamage(SHOTGUN_PELLET_DAMAGE)
							end
						end
					end
					-- Notify the parrying client once per parry activation
					if not parryState.successFired then
						parryState.successFired = true
						Network:FireRemoteToClient(victimPlayer :: Player, "KnifeParrySuccess")
					end
				else
					-- Normal damage
					self:_recordDamage(humanoid, player)
					humanoid:TakeDamage(SHOTGUN_PELLET_DAMAGE)
				end
			end
		end
	end

	-- Broadcast cosmetic tracers to all clients (visual only; each client filters its own)
	Network:FireUnreliableRemoteToAllClients("ReplicateShotgunBullet", player.UserId, origin, direction)
end

function singleton:_knifeSwing(player: Player)
	local character = player.Character
	if not isAliveCharacter(character) then
		return
	end
	if PlayerStateService:GetState(player) ~= "Combat" then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end

	local params = makeParamsForShooter(character :: Model)
	local result = workspace:Raycast(hrp.Position, hrp.CFrame.LookVector * KNIFE_RANGE, params)
	if result then
		local humanoid = getHumanoidFromHit(result.Instance)
		if humanoid and humanoid.Health > 0 then
			self:_recordDamage(humanoid, player)
			humanoid:TakeDamage(KNIFE_DAMAGE)
		end
	end

	--Network:FireRemoteToClient(player, VIEWMODEL_ANIM_PACKET, "FireKnife")
	--Network:FireRemoteToClient(player, AVATAR_ANIM_PACKET, "FireKnife")
end

function singleton:Initialize()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			self:_wireCharacter(char)
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			self:_wireCharacter(player.Character)
		end
		player.CharacterAdded:Connect(function(char)
			self:_wireCharacter(char)
		end)
	end

	-- Clean up parry state when a player leaves
	Players.PlayerRemoving:Connect(function(player)
		self._parryingPlayers[player] = nil
	end)

	Network:SubscribeToPacket(PACKET_SHOTGUN):Connect(function(player: Player, origin: Vector3, direction: Vector3)
		self:_fireShotgun(player, origin, direction)
	end)

	Network:SubscribeToPacket(PACKET_KNIFE):Connect(function(player: Player)
		self:_knifeSwing(player)
	end)

	-- Register a parry window for this player (server-side validation included)
	Network:SubscribeToPacket(PACKET_PARRY_START):Connect(function(player: Player)
		if PlayerStateService:GetState(player) ~= "Combat" then
			return
		end
		self._parryingPlayers[player] = { startTime = os.clock(), successFired = false }
	end)
end

return singleton
