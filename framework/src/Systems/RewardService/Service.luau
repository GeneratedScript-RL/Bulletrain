--!strict

local Players = game:GetService("Players")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkServer = require(root) :: any

local Config = require(script.Parent.Shared.Config)

type KillComboState = {
	Count: number,
	LastKillTime: number,
}

local dataService: any

type RewardDefinition = {
	Label: string,
	XP: number,
	Coins: number,
	TitleColor: Color3,
}

local RewardService = framework.CreateService({
	Name = "RewardService",
	Dependencies = { "DataService" },
	Client = {
		RewardGranted = framework.CreateSignal(),
	},
})

RewardService._killComboStates = {} :: { [Player]: KillComboState }

local function getRoundedNonNegative(value: number): number
	return math.max(math.floor(value + 0.5), 0)
end

local function getRewardDefinition(rewardId: string): RewardDefinition?
	return (Config.Rewards :: { [string]: RewardDefinition })[rewardId]
end

function RewardService:_grantReward(player: Player, rewardId: string)
	if player.Parent ~= Players then
		return
	end

	local rewardDefinition = getRewardDefinition(rewardId)
	if not rewardDefinition then
		warn(("[RewardService] Missing reward definition for '%s'"):format(rewardId))
		return
	end

	local xp = getRoundedNonNegative(rewardDefinition.XP)
	local coins = getRoundedNonNegative(rewardDefinition.Coins)

	if xp > 0 then
		dataService:AddXP(player, xp)
	end

	if coins > 0 then
		dataService:AddCredits(player, coins)
	end

	self.Client.RewardGranted:Fire(player, {
		rewardId = rewardId,
		label = rewardDefinition.Label,
		xp = xp,
		coins = coins,
		titleColor = rewardDefinition.TitleColor,
	})
end

function RewardService:AwardKill(player: Player)
	self:_grantReward(player, "Kill")

	local now = os.clock()
	local comboWindow = math.max(Config.KillComboTimeDistanceMaximum, 0)
	local comboState = self._killComboStates[player]

	if comboState and comboWindow > 0 and (now - comboState.LastKillTime) <= comboWindow then
		comboState.Count += 1
	else
		comboState = {
			Count = 1,
			LastKillTime = now,
		}
		self._killComboStates[player] = comboState
	end

	comboState.LastKillTime = now

	local comboRewardId = Config.ComboRewardsByCount[comboState.Count]
	if comboRewardId then
		self:_grantReward(player, comboRewardId)
	end
end

function RewardService:AwardAssist(player: Player)
	self:_grantReward(player, "Assist")
end

function RewardService:Init()
	dataService = framework.GetService("DataService")

	framework.OnPlayerRemoving(function(player: Player)
		self._killComboStates[player] = nil
	end)
end

return RewardService
