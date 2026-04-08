--!strict

local Players = game:GetService("Players")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkServer = require(root) :: any

local Config = require(script.Parent.Shared.Config)

type ParryState = {
	startTime: number,
	successFired: boolean,
}

local playerStateService: any
local scoreService: any
local dataService: any
local dailyTaskService: any

local CombatService = framework.CreateService({
	Name = "CombatService",
	Dependencies = { "PlayerStateService", "ScoreService", "DataService", "DailyTaskService" },
	Client = {
		ShotgunFire = framework.CreateSignal(),
		KnifeSwing = framework.CreateSignal(),
		ParryStart = framework.CreateSignal(),
		ParrySuccess = framework.CreateSignal(),
		KillFeedEntryAdded = framework.CreateSignal(),
		ReplicateShotgunBullet = framework.CreateUnreliableSignal(),
	},
})

CombatService._lastDamager = {} :: { [Humanoid]: Player }
CombatService._lastDamageWeapon = {} :: { [Humanoid]: string }
CombatService._damageLog = {} :: { [Humanoid]: { [Player]: number } }
CombatService._parryingPlayers = {} :: { [Player]: ParryState }

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

local function getPlayerFromHumanoid(humanoid: Humanoid): Player?
	local character = humanoid.Parent
	if character and character:IsA("Model") then
		return Players:GetPlayerFromCharacter(character)
	end

	return nil
end

local function getPlayerFeedName(player: Player): string
	return player.Name
end

local function makeParamsForShooter(shooterCharacter: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { shooterCharacter }
	params.IgnoreWater = true
	return params
end

local function applySpread(direction: Vector3, spreadDegrees: number): Vector3
	local spreadRadians = math.rad(spreadDegrees)
	local yaw = (math.random() - 0.5) * 2 * spreadRadians
	local pitch = (math.random() - 0.5) * 2 * spreadRadians
	local base = CFrame.lookAt(Vector3.zero, direction)
	return (base * CFrame.Angles(pitch, yaw, 0)).LookVector
end

function CombatService:_tagDamage(victimHumanoid: Humanoid, attacker: Player, weaponName: string)
	self._lastDamager[victimHumanoid] = attacker
	self._lastDamageWeapon[victimHumanoid] = weaponName
end

function CombatService:_recordDamage(victimHumanoid: Humanoid, attacker: Player, weaponName: string)
	self:_tagDamage(victimHumanoid, attacker, weaponName)

	local log = self._damageLog[victimHumanoid]
	if not log then
		log = {}
		self._damageLog[victimHumanoid] = log
	end

	log[attacker] = os.clock()
end

function CombatService:_onHumanoidDied(victimHumanoid: Humanoid)
	local victimPlayer = getPlayerFromHumanoid(victimHumanoid)
	if victimPlayer then
		dataService:AddDeath(victimPlayer)
		dailyTaskService:RecordEvent(victimPlayer, "Death", {
			Victim = victimPlayer,
		})
	end

	local killer = self._lastDamager[victimHumanoid]
	if killer and killer.Parent == Players and killer ~= victimPlayer then
		scoreService:IncrementKills(killer)
		dataService:AddKill(killer)
		dataService:AddXP(killer, Config.XPPerKill)
		dataService:AddCredits(killer, Config.CreditsPerKill)
		dailyTaskService:RecordEvent(killer, "Kill", {
			Killer = killer,
			Victim = victimPlayer,
		})

		if victimPlayer then
			self.Client.KillFeedEntryAdded:FireAll({
				killerUserId = killer.UserId,
				killerName = getPlayerFeedName(killer),
				victimUserId = victimPlayer.UserId,
				victimName = getPlayerFeedName(victimPlayer),
				weaponName = self._lastDamageWeapon[victimHumanoid] or "Shotgun",
			})
		end
	end

	local log = self._damageLog[victimHumanoid]
	if log then
		local now = os.clock()
		for assister, timestamp in log do
			if assister ~= killer and assister.Parent == Players and (now - timestamp) <= Config.AssistWindow then
				dataService:AddAssist(assister)
				dataService:AddXP(assister, Config.XPPerAssist)
				dailyTaskService:RecordEvent(assister, "Assist", {
					Assister = assister,
					Killer = killer,
					Victim = victimPlayer,
				})
			end
		end
	end

	self._lastDamager[victimHumanoid] = nil
	self._lastDamageWeapon[victimHumanoid] = nil
	self._damageLog[victimHumanoid] = nil
end

function CombatService:_wireCharacter(character: Model, trove: Types.Trove)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	trove:Add(humanoid.Died:Connect(function()
		self:_onHumanoidDied(humanoid)
	end))
end

function CombatService:_fireShotgun(player: Player, origin: Vector3, direction: Vector3)
	local character = player.Character
	if not isAliveCharacter(character) then
		return
	end

	if playerStateService:GetState(player) ~= "Combat" then
		return
	end

	local params = makeParamsForShooter(character :: Model)

	for _ = 1, Config.Shotgun.Pellets do
		local rayDirection = applySpread(direction, Config.Shotgun.SpreadDegrees)
		local result = workspace:Raycast(origin, rayDirection.Unit * Config.Shotgun.Range, params)
		if result then
			local humanoid = getHumanoidFromHit(result.Instance)
			if humanoid and humanoid.Health > 0 then
				local victimPlayer = getPlayerFromHumanoid(humanoid)
				local parryState = if victimPlayer then self._parryingPlayers[victimPlayer] else nil

				if parryState and victimPlayer and (os.clock() - parryState.startTime) <= Config.ParryWindow then
					local victimCharacter = victimPlayer.Character
					if victimCharacter then
						local redirectParams = makeParamsForShooter(victimCharacter)
						local redirectResult = workspace:Raycast(result.Position, (-rayDirection.Unit) * Config.Shotgun.Range, redirectParams)
						if redirectResult then
							local redirectHumanoid = getHumanoidFromHit(redirectResult.Instance)
							if redirectHumanoid and redirectHumanoid.Health > 0 then
								self:_recordDamage(redirectHumanoid, victimPlayer, "Knife")
								redirectHumanoid:TakeDamage(Config.Shotgun.PelletDamage)
							end
						end
					end

					if not parryState.successFired then
						parryState.successFired = true
						self.Client.ParrySuccess:Fire(victimPlayer)
					end
				else
					self:_recordDamage(humanoid, player, "Shotgun")
					humanoid:TakeDamage(Config.Shotgun.PelletDamage)
				end
			end
		end
	end

	self.Client.ReplicateShotgunBullet:FireAll(player.UserId, origin, direction)
end

function CombatService:_knifeSwing(player: Player)
	local character = player.Character
	if not isAliveCharacter(character) then
		return
	end

	if playerStateService:GetState(player) ~= "Combat" then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	local params = makeParamsForShooter(character :: Model)
	local result = workspace:Raycast(rootPart.Position, rootPart.CFrame.LookVector * Config.Knife.Range, params)
	if result then
		local humanoid = getHumanoidFromHit(result.Instance)
		if humanoid and humanoid.Health > 0 then
			self:_recordDamage(humanoid, player, "Knife")
			humanoid:TakeDamage(Config.Knife.Damage)
		end
	end
end

function CombatService:Init()
	playerStateService = framework.GetService("PlayerStateService")
	scoreService = framework.GetService("ScoreService")
	dataService = framework.GetService("DataService")
	dailyTaskService = framework.GetService("DailyTaskService")

	self.Client.ShotgunFire:Connect(function(player: Player, origin: Vector3, direction: Vector3)
		self:_fireShotgun(player, origin, direction)
	end)

	self.Client.KnifeSwing:Connect(function(player: Player)
		self:_knifeSwing(player)
	end)

	self.Client.ParryStart:Connect(function(player: Player)
		if playerStateService:GetState(player) ~= "Combat" then
			return
		end

		self._parryingPlayers[player] = {
			startTime = os.clock(),
			successFired = false,
		}
	end)

	framework.OnCharacterAdded(function(_player: Player, character: Model, trove: Types.Trove)
		self:_wireCharacter(character, trove)
	end)

	framework.OnPlayerRemoving(function(player: Player)
		self._parryingPlayers[player] = nil
	end)
end

return CombatService
