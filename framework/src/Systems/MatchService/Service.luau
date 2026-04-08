--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkServer = require(root) :: any

local Config = require(script.Parent.Shared.Config)
local MatchStates = require(script.Parent.Shared.MatchStates)

local playerStateService: any
local scoreService: any
local mapService: any
local spawnService: any
local dailyTaskService: any

type VoteData = {
	map: string?,
	mode: string?,
}

local MatchService = framework.CreateService({
	Name = "MatchService",
	Dependencies = { "PlayerStateService", "ScoreService", "MapService", "SpawnService", "DailyTaskService" },
	Client = {
		RequestJoin = framework.CreateSignal(),
		SubmitVote = framework.CreateSignal(),
		IntermissionStarted = framework.CreateSignal(),
		VotingStarted = framework.CreateSignal(),
		VotingEnded = framework.CreateSignal(),
		MatchStarted = framework.CreateSignal(),
		MatchEnded = framework.CreateSignal(),
		CurrentState = framework.CreateProperty(MatchStates.Intermission),
		MatchRunning = framework.CreateProperty(false),
		Countdown = framework.CreateProperty(0),
		MapOptions = framework.CreateProperty({} :: { string }),
		ModeOptions = framework.CreateProperty({} :: { string }),
		SelectedMap = framework.CreateProperty(""),
		SelectedMode = framework.CreateProperty(""),
	},
})

MatchService._matchRunning = false
MatchService._selectedMap = nil :: string?
MatchService._selectedMode = nil :: string?
MatchService._respawnConnections = {} :: { [Player]: RBXScriptConnection }
MatchService._votes = {} :: { [Player]: VoteData }
MatchService._matchParticipants = {} :: { [Player]: boolean }

local function getLobbyCFrame(): CFrame
	local spawnLocation = workspace:WaitForChild("SpawnLocation") :: BasePart
	return spawnLocation.CFrame * CFrame.new(0, 3, 0)
end

local function loadCharacterAtLobby(player: Player)
	player:LoadCharacter()
	local character = player.Character or player.CharacterAdded:Wait()
	if character then
		character:PivotTo(getLobbyCFrame())
	end
end

function MatchService:_setAllStates(state: string)
	for _, player in Players:GetPlayers() do
		playerStateService:SetState(player, state)
	end
end

function MatchService:_setCountdown(value: number)
	self.Client.Countdown:Set(math.max(value, 0))
end

function MatchService:_clearSelections()
	self._selectedMap = nil
	self._selectedMode = nil
	self.Client.SelectedMap:Set("")
	self.Client.SelectedMode:Set("")
end

function MatchService:_disconnectRespawnHooks()
	for player, connection in self._respawnConnections do
		connection:Disconnect()
		self._respawnConnections[player] = nil
	end
end

function MatchService:_hookRespawnsForPlayer(player: Player)
	if self._respawnConnections[player] then
		return
	end

	self._respawnConnections[player] = player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			if self._matchRunning and playerStateService:GetState(player) == "Combat" then
				task.delay(Config.RespawnDelay, function()
					if self._matchRunning and player.Parent == Players and playerStateService:GetState(player) == "Combat" then
						spawnService:SpawnPlayer(player)
					end
				end)
			end
		end)
	end)
end

function MatchService:_tryJoinMatch(player: Player)
	if not self._matchRunning or not self._selectedMap or not self._selectedMode then
		return
	end

	if playerStateService:GetState(player) ~= "Menu" then
		return
	end

	playerStateService:SetState(player, "Combat")
	self._matchParticipants[player] = true
	self:_hookRespawnsForPlayer(player)
	spawnService:SpawnPlayer(player)
end

function MatchService:_getMapOptions(): { string }
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local mapsFolder = if assets then assets:FindFirstChild("Maps") else nil
	if not mapsFolder or not mapsFolder:IsA("Folder") then
		return {}
	end

	local options: { string } = {}
	for _, child in mapsFolder:GetChildren() do
		if child:IsA("Model") then
			table.insert(options, child.Name)
		end
	end

	table.sort(options)
	return options
end

function MatchService:_getModeOptions(): { string }
	return { Config.DefaultMode }
end

function MatchService:_resetVotes()
	table.clear(self._votes)
end

function MatchService:_recordVote(player: Player, voteType: string, value: string)
	if self.Client.CurrentState:Get() ~= MatchStates.Voting or value == "" then
		return
	end

	local voteData = self._votes[player]
	if not voteData then
		voteData = {}
		self._votes[player] = voteData
	end

	if voteType == "map" then
		voteData.map = value
	elseif voteType == "mode" then
		voteData.mode = value
	end
end

function MatchService:_tallyVotes(key: "map" | "mode"): string?
	local counts: { [string]: number } = {}
	for _, voteData in self._votes do
		local value = voteData[key]
		if value then
			counts[value] = (counts[value] or 0) + 1
		end
	end

	local bestValue: string? = nil
	local bestCount = -1
	for option, count in counts do
		if count > bestCount then
			bestValue = option
			bestCount = count
		end
	end

	return bestValue
end

function MatchService:_runCountdown(durationSeconds: number, heartbeat: (() -> boolean)?): boolean
	local endTime = os.clock() + durationSeconds
	while true do
		local remaining = math.max(math.ceil(endTime - os.clock()), 0)
		self:_setCountdown(remaining)

		if heartbeat and heartbeat() then
			return false
		end

		if remaining <= 0 then
			break
		end

		task.wait(1)
	end

	self:_setCountdown(0)
	return true
end

function MatchService:_startMatch(mapName: string, modeName: string): boolean
	self._matchRunning = true
	self._selectedMap = mapName
	self._selectedMode = modeName
	table.clear(self._matchParticipants)

	self.Client.CurrentState:Set(MatchStates.Match)
	self.Client.MatchRunning:Set(true)
	self.Client.SelectedMap:Set(mapName)
	self.Client.SelectedMode:Set(modeName)

	scoreService:ResetAll()

	local loadedMap = mapService:LoadMap(mapName)
	if not loadedMap then
		self._matchRunning = false
		self.Client.MatchRunning:Set(false)
		self:_clearSelections()
		return false
	end

	self:_setAllStates("Menu")
	for _, player in Players:GetPlayers() do
		loadCharacterAtLobby(player)
	end

	self.Client.MatchStarted:FireAll({
		map = mapName,
		mode = modeName,
		duration = Config.MatchDuration,
		killLimit = Config.KillLimit,
	})

	return true
end

function MatchService:_reportCompletedMatches(reason: string)
	for player in self._matchParticipants do
		if player.Parent == Players then
			dailyTaskService:RecordEvent(player, "MatchCompleted", {
				Reason = reason,
				Map = self._selectedMap,
				Mode = self._selectedMode,
			})
		end
	end

	table.clear(self._matchParticipants)
end

function MatchService:_endMatch(reason: string)
	self._matchRunning = false
	self.Client.MatchRunning:Set(false)
	self.Client.CurrentState:Set(MatchStates.PostMatch)

	self:_reportCompletedMatches(reason)

	local topPlayer, topKills = scoreService:GetTopPlayer()

	self:_setAllStates("Menu")
	self:_disconnectRespawnHooks()
	mapService:UnloadCurrentMap()

	for _, player in Players:GetPlayers() do
		loadCharacterAtLobby(player)
	end

	self.Client.MatchEnded:FireAll({
		reason = reason,
		topUserId = if topPlayer then topPlayer.UserId else nil,
		topKills = topKills,
	})

	self:_runCountdown(Config.EndDuration)
	self:_clearSelections()
end

function MatchService:_runMatchTimer()
	local startTime = os.clock()
	self:_runCountdown(Config.MatchDuration, function()
		local _, topKills = scoreService:GetTopPlayer()
		if topKills >= Config.KillLimit then
			self:_endMatch("KillLimit")
			return true
		end

		if (os.clock() - startTime) >= Config.MatchDuration then
			self:_endMatch("Time")
			return true
		end

		return not self._matchRunning
	end)

	if self._matchRunning then
		self:_endMatch("Time")
	end
end

function MatchService:Init()
	playerStateService = framework.GetService("PlayerStateService")
	scoreService = framework.GetService("ScoreService")
	mapService = framework.GetService("MapService")
	spawnService = framework.GetService("SpawnService")
	dailyTaskService = framework.GetService("DailyTaskService")

	self.Client.RequestJoin:Connect(function(player: Player)
		self:_tryJoinMatch(player)
	end)

	self.Client.SubmitVote:Connect(function(player: Player, voteType: string, value: string)
		self:_recordVote(player, voteType, value)
	end)

	framework.OnPlayerAdded(function(player: Player)
		playerStateService:SetState(player, "Menu")
		loadCharacterAtLobby(player)
	end)

	framework.OnPlayerRemoving(function(player: Player)
		local connection = self._respawnConnections[player]
		if connection then
			connection:Disconnect()
			self._respawnConnections[player] = nil
		end

		self._votes[player] = nil
		self._matchParticipants[player] = nil
	end)
end

function MatchService:Start()
	task.spawn(function()
		while true do
			self._matchRunning = false
			self.Client.MatchRunning:Set(false)
			self.Client.CurrentState:Set(MatchStates.Intermission)
			self.Client.MapOptions:Set({})
			self.Client.ModeOptions:Set({})
			self:_clearSelections()
			self:_resetVotes()
			table.clear(self._matchParticipants)
			self:_setAllStates("Menu")

			for _, player in Players:GetPlayers() do
				loadCharacterAtLobby(player)
			end

			self.Client.IntermissionStarted:FireAll({
				duration = Config.IntermissionDuration,
			})

			self:_runCountdown(Config.IntermissionDuration)

			local mapOptions = self:_getMapOptions()
			local modeOptions = self:_getModeOptions()

			self.Client.CurrentState:Set(MatchStates.Voting)
			self.Client.MapOptions:Set(mapOptions)
			self.Client.ModeOptions:Set(modeOptions)
			self:_resetVotes()

			self.Client.VotingStarted:FireAll({
				mapOptions = mapOptions,
				modeOptions = modeOptions,
				endsIn = Config.IntermissionDuration,
			})

			self:_runCountdown(Config.IntermissionDuration)

			local chosenMap = self:_tallyVotes("map") or mapOptions[1]
			local chosenMode = self:_tallyVotes("mode") or modeOptions[1]

			self.Client.VotingEnded:FireAll({
				map = chosenMap,
				mode = chosenMode,
			})

			if not chosenMap or not chosenMode then
				warn("[MatchService] Voting produced no map/mode; retrying loop")
				task.wait(2)
				continue
			end

			if not self:_startMatch(chosenMap, chosenMode) then
				warn(("[MatchService] Failed to start match for map '%s'"):format(chosenMap))
				task.wait(2)
				continue
			end

			self:_runMatchTimer()
		end
	end)
end

return MatchService
