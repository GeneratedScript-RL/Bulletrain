--!strict

local Players = game:GetService("Players")

local ScoreService = {}
ScoreService.__index = ScoreService

function ScoreService.new()
	local self = setmetatable({}, ScoreService)
	self._kills = {} :: {[Player]: number}
	self.KillsChanged = Instance.new("BindableEvent")
	return self
end

local singleton = ScoreService.new()

function singleton:Initialize()
	for _, player in ipairs(Players:GetPlayers()) do
		self._kills[player] = 0
		self.KillsChanged:Fire(player, 0)
	end
	Players.PlayerAdded:Connect(function(player)
		self._kills[player] = 0
		self.KillsChanged:Fire(player, 0)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._kills[player] = nil
	end)
end

function singleton:GetKills(player: Player): number
	return self._kills[player] or 0
end

function singleton:IncrementKills(player: Player)
	self._kills[player] = (self._kills[player] or 0) + 1
	self.KillsChanged:Fire(player, self._kills[player])
end

function singleton:ResetAll()
	-- ensure entries exist for all current players
	for _, player in ipairs(Players:GetPlayers()) do
		self._kills[player] = 0
		self.KillsChanged:Fire(player, 0)
	end
	-- clear any stale entries
	for player, _ in pairs(self._kills) do
		if player.Parent ~= Players then
			self._kills[player] = nil
		end
	end
end

function singleton:GetTopPlayer(): (Player?, number)
	local bestPlayer: Player? = nil
	local bestKills = -1
	for p, k in pairs(self._kills) do
		if k > bestKills then
			bestKills = k
			bestPlayer = p
		end
	end
	return bestPlayer, bestKills
end

return singleton
