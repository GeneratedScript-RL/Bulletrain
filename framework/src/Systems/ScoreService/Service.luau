--!strict

local Players = game:GetService("Players")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkServer = require(root) :: any

export type MatchPlayerStats = {
	Kills: number,
	Deaths: number,
	Assists: number,
	Damage: number,
}

export type MatchResultEntry = {
	UserId: number,
	Name: string,
	DisplayName: string,
	Kills: number,
	Deaths: number,
	Assists: number,
	Damage: number,
}

local ScoreService = framework.CreateService({
	Name = "ScoreService",
	Client = {
		KillCounts = framework.CreateProperty({} :: { [number]: number }),
	},
})

ScoreService._stats = {} :: { [Player]: MatchPlayerStats }

local function newMatchPlayerStats(): MatchPlayerStats
	return {
		Kills = 0,
		Deaths = 0,
		Assists = 0,
		Damage = 0,
	}
end

local function cloneMatchPlayerStats(stats: MatchPlayerStats): MatchPlayerStats
	return {
		Kills = stats.Kills,
		Deaths = stats.Deaths,
		Assists = stats.Assists,
		Damage = stats.Damage,
	}
end

local function comparePlayers(a: { Player: Player, Stats: MatchPlayerStats }, b: { Player: Player, Stats: MatchPlayerStats }): boolean
	if a.Stats.Kills ~= b.Stats.Kills then
		return a.Stats.Kills > b.Stats.Kills
	end

	if a.Stats.Damage ~= b.Stats.Damage then
		return a.Stats.Damage > b.Stats.Damage
	end

	if a.Stats.Deaths ~= b.Stats.Deaths then
		return a.Stats.Deaths < b.Stats.Deaths
	end

	return a.Player.Name < b.Player.Name
end

function ScoreService:_getPlayerStats(player: Player): MatchPlayerStats
	local stats = self._stats[player]
	if stats then
		return stats
	end

	stats = newMatchPlayerStats()
	self._stats[player] = stats
	return stats
end

function ScoreService:_serializeKills(): { [number]: number }
	local result: { [number]: number } = {}
	for player, stats in self._stats do
		if player.Parent == Players then
			result[player.UserId] = stats.Kills
		end
	end

	return result
end

function ScoreService:_syncClient()
	self.Client.KillCounts:Set(self:_serializeKills())
end

function ScoreService:GetKills(player: Player): number
	return self:_getPlayerStats(player).Kills
end

function ScoreService:IncrementKills(player: Player)
	local stats = self:_getPlayerStats(player)
	stats.Kills += 1
	self:_syncClient()
end

function ScoreService:RecordDeath(player: Player)
	local stats = self:_getPlayerStats(player)
	stats.Deaths += 1
end

function ScoreService:RecordAssist(player: Player)
	local stats = self:_getPlayerStats(player)
	stats.Assists += 1
end

function ScoreService:RecordDamage(player: Player, damageAmount: number)
	if damageAmount <= 0 then
		return
	end

	local stats = self:_getPlayerStats(player)
	stats.Damage += damageAmount
end

function ScoreService:GetMatchStats(player: Player): MatchPlayerStats
	return cloneMatchPlayerStats(self:_getPlayerStats(player))
end

function ScoreService:GetTopPlayers(limit: number?): { MatchResultEntry }
	local rankedPlayers = {} :: { { Player: Player, Stats: MatchPlayerStats } }

	for player, stats in self._stats do
		if player.Parent == Players then
			table.insert(rankedPlayers, {
				Player = player,
				Stats = stats,
			})
		end
	end

	table.sort(rankedPlayers, comparePlayers)

	local results = {} :: { MatchResultEntry }
	local maxEntries = if limit and limit > 0 then math.floor(limit) else #rankedPlayers

	for index, rankedPlayer in ipairs(rankedPlayers) do
		if index > maxEntries then
			break
		end

		table.insert(results, {
			UserId = rankedPlayer.Player.UserId,
			Name = rankedPlayer.Player.Name,
			DisplayName = rankedPlayer.Player.DisplayName,
			Kills = rankedPlayer.Stats.Kills,
			Deaths = rankedPlayer.Stats.Deaths,
			Assists = rankedPlayer.Stats.Assists,
			Damage = math.floor(rankedPlayer.Stats.Damage + 0.5),
		})
	end

	return results
end

function ScoreService:ResetAll()
	for _, player in Players:GetPlayers() do
		self._stats[player] = newMatchPlayerStats()
	end

	for player in self._stats do
		if player.Parent ~= Players then
			self._stats[player] = nil
		end
	end

	self:_syncClient()
end

function ScoreService:GetTopPlayer(): (Player?, number)
	local topPlayers = self:GetTopPlayers(1)
	local topPlayer = topPlayers[1]
	if not topPlayer then
		return nil, 0
	end

	local player = Players:GetPlayerByUserId(topPlayer.UserId)
	return player, topPlayer.Kills
end

function ScoreService:Init()
	framework.OnPlayerAdded(function(player: Player)
		self._stats[player] = newMatchPlayerStats()
		self:_syncClient()
	end)

	framework.OnPlayerRemoving(function(player: Player)
		self._stats[player] = nil
		self:_syncClient()
	end)
end

return ScoreService
