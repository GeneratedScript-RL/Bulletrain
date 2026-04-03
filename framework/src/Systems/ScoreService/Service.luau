--!strict

local Players = game:GetService("Players")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkServer = require(root) :: any

local ScoreService = framework.CreateService({
	Name = "ScoreService",
	Client = {
		KillCounts = framework.CreateProperty({} :: { [number]: number }),
	},
})

ScoreService._kills = {} :: { [Player]: number }

function ScoreService:_serializeKills(): { [number]: number }
	local result: { [number]: number } = {}
	for player, killCount in self._kills do
		if player.Parent == Players then
			result[player.UserId] = killCount
		end
	end

	return result
end

function ScoreService:_syncClient()
	self.Client.KillCounts:Set(self:_serializeKills())
end

function ScoreService:GetKills(player: Player): number
	return self._kills[player] or 0
end

function ScoreService:IncrementKills(player: Player)
	self._kills[player] = (self._kills[player] or 0) + 1
	self:_syncClient()
end

function ScoreService:ResetAll()
	for _, player in Players:GetPlayers() do
		self._kills[player] = 0
	end

	for player in self._kills do
		if player.Parent ~= Players then
			self._kills[player] = nil
		end
	end

	self:_syncClient()
end

function ScoreService:GetTopPlayer(): (Player?, number)
	local bestPlayer: Player? = nil
	local bestKills = -1

	for player, killCount in self._kills do
		if killCount > bestKills then
			bestPlayer = player
			bestKills = killCount
		end
	end

	return bestPlayer, bestKills
end

function ScoreService:Init()
	framework.OnPlayerAdded(function(player: Player)
		self._kills[player] = 0
		self:_syncClient()
	end)

	framework.OnPlayerRemoving(function(player: Player)
		self._kills[player] = nil
		self:_syncClient()
	end)
end

return ScoreService
