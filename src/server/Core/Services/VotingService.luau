--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network.Network)

local VotingService = {}
VotingService.__index = VotingService

local VOTE_PACKET = "SubmitVote"

export type VoteData = {
	map: string?,
	mode: string?,
}

function VotingService.new()
	local self = setmetatable({}, VotingService)
	self._votes = {} :: {[Player]: VoteData}
	return self
end

local singleton = VotingService.new()

local function getMapOptions(): {string}
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local mapsFolder = assets and assets:FindFirstChild("Maps")
	if not mapsFolder or not mapsFolder:IsA("Folder") then
		return {}
	end
	local opts = {}
	for _, child in ipairs(mapsFolder:GetChildren()) do
		if child:IsA("Model") then
			table.insert(opts, child.Name)
		end
	end
	table.sort(opts)
	return opts
end

function singleton:Initialize()
	Network:SubscribeToPacket(VOTE_PACKET):Connect(function(player: Player, voteType: string, value: string)
		local vd = self._votes[player]
		if not vd then
			vd = {}
			self._votes[player] = vd
		end
		if voteType == "map" then
			vd.map = value
		elseif voteType == "mode" then
			vd.mode = value
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._votes[player] = nil
	end)
end

local function tallyVotes(votes: {[Player]: VoteData}, key: "map" | "mode"): string?
	local counts: {[string]: number} = {}
	for _, data in pairs(votes) do
		local v = data[key]
		if v then
			counts[v] = (counts[v] or 0) + 1
		end
	end
	local best: string? = nil
	local bestCount = -1
	for option, count in pairs(counts) do
		if count > bestCount then
			best = option
			bestCount = count
		end
	end
	return best
end

function singleton:StartVoting(durationSeconds: number): (string?, string?)
	self._votes = {}

	local mapOptions = getMapOptions()
	local modeOptions = {"FFA"}

	Network:FireRemoteToAllClients("VotingStarted", {
		mapOptions = mapOptions,
		modeOptions = modeOptions,
		endsIn = durationSeconds,
	})

	-- need ui implementation here (client voting)
	task.wait(durationSeconds)

	local chosenMap = tallyVotes(self._votes, "map")
	local chosenMode = tallyVotes(self._votes, "mode")

	if not chosenMap then
		chosenMap = mapOptions[1]
	end
	if not chosenMode then
		chosenMode = "FFA"
	end

	Network:FireRemoteToAllClients("VotingEnded", {
		map = chosenMap,
		mode = chosenMode,
	})

	return chosenMap, chosenMode
end

return singleton
