--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network.Network)

local PlayerStateService = require(script.Parent.PlayerStateService)
local VotingService = require(script.Parent.VotingService)
local MapService = require(script.Parent.MapService)
local SpawnService = require(script.Parent.SpawnService)
local ScoreService = require(script.Parent.ScoreService)

local GameLoopService = {}
GameLoopService.__index = GameLoopService

local VOTING_DURATION = 1
local MATCH_DURATION = 180
local END_DURATION = 8
local KILL_LIMIT = 100000
local RESPAWN_DELAY = 2

local JOIN_PACKET = "RequestJoinMatch"

local LOBBY_CFRAME = workspace.SpawnLocation.CFrame * CFrame.new(0, 3, 0)

function GameLoopService.new()
	local self = setmetatable({}, GameLoopService)
	self._matchRunning = false
	self._selectedMap = nil :: string?
	self._selectedMode = nil :: string?
	self._respawnConnections = {} :: {[Player]: RBXScriptConnection}
	return self
end

local singleton = GameLoopService.new()

local function setAllStates(state: any)
	for _, p in ipairs(Players:GetPlayers()) do
		PlayerStateService:SetState(p, state)
	end
end

function singleton:_disconnectRespawnHooks()
	for p, conn in pairs(self._respawnConnections) do
		conn:Disconnect()
		self._respawnConnections[p] = nil
	end
end

function singleton:_hookRespawnsForPlayer(player: Player)
	if self._respawnConnections[player] then
		return
	end

	self._respawnConnections[player] = player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			-- Only respawn during match if player is in Combat
			if self._matchRunning and PlayerStateService:GetState(player) == "Combat" then
				task.delay(RESPAWN_DELAY, function()
					if self._matchRunning and player.Parent == Players and PlayerStateService:GetState(player) == "Combat" then
						SpawnService:SpawnPlayer(player)
					end
				end)
			end
		end)
	end)
end

function singleton:_tryJoinMatch(player: Player)
	if not self._matchRunning then
		return
	end
	if not self._selectedMap or not self._selectedMode then
		return
	end
	if PlayerStateService:GetState(player) ~= "Menu" then
		return
	end

	PlayerStateService:SetState(player, "Combat")
	self:_hookRespawnsForPlayer(player)
	SpawnService:SpawnPlayer(player)
end

function singleton:_startMatch(mapName: string, modeName: string)
	self._matchRunning = true
	self._selectedMap = mapName
	self._selectedMode = modeName

	ScoreService:ResetAll()
	MapService:LoadMap(mapName)

	-- Players must manually join the match by pressing Space while in Menu.
	setAllStates("Menu")
	for _, player in ipairs(Players:GetPlayers()) do
		player:LoadCharacter()
		if player.Character then
			player.Character:PivotTo(LOBBY_CFRAME)
		end
	end

	Network:FireRemoteToAllClients("MatchStarted", {
		map = mapName,
		mode = modeName,
		duration = MATCH_DURATION,
		killLimit = KILL_LIMIT,
		-- need ui implementation here ("Press Space to Join")
	})
end

function singleton:_endMatch(reason: string)
	self._matchRunning = false

	local topPlayer, topKills = ScoreService:GetTopPlayer()

	-- Immediately return everyone to lobby and disable combat.
	setAllStates("Menu")
	self:_disconnectRespawnHooks()
	MapService:UnloadCurrentMap()

	-- Menu = default Roblox movement (no viewmodels/weapons/slide on client)
	for _, player in ipairs(Players:GetPlayers()) do
		player:LoadCharacter()
		if player.Character then
			player.Character:PivotTo(LOBBY_CFRAME)
		end
	end

	Network:FireRemoteToAllClients("MatchEnded", {
		reason = reason,
		topUserId = topPlayer and topPlayer.UserId or nil,
		topKills = topKills,
	})

	task.wait(END_DURATION)
end

function singleton:_runMatchTimer()
	local startTime = os.clock()
	while self._matchRunning do
		local elapsed = os.clock() - startTime
		local _topPlayer, topKills = ScoreService:GetTopPlayer()
		if topKills >= KILL_LIMIT then
			self:_endMatch("KillLimit")
			return
		end
		if elapsed >= MATCH_DURATION then
			self:_endMatch("Time")
			return
		end
		task.wait(1)
	end
end

function singleton:Initialize()
	-- Ensure state defaults to Menu.
	setAllStates("Menu")

	Players.PlayerAdded:Connect(function(player)
		PlayerStateService:SetState(player, "Menu")
		-- Always spawn to lobby initially; match join is manual.
		player:LoadCharacter()
		if player.Character then
			player.Character:PivotTo(LOBBY_CFRAME)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local conn = self._respawnConnections[player]
		if conn then
			conn:Disconnect()
			self._respawnConnections[player] = nil
		end
	end)

	Network:SubscribeToPacket(JOIN_PACKET):Connect(function(player: Player)
		self:_tryJoinMatch(player)
	end)

	task.spawn(function()
		while true do
			setAllStates("Menu")
			for _, player in ipairs(Players:GetPlayers()) do
				player:LoadCharacter()
				if player.Character then
					player.Character:PivotTo(LOBBY_CFRAME)
				end
			end
			Network:FireRemoteToAllClients("Intermission", { duration = VOTING_DURATION })

			local mapName, modeName = VotingService:StartVoting(VOTING_DURATION)
			if not mapName or not modeName then
				warn("[GameLoopService] Voting returned nil selection; retrying")
				task.wait(2)
				continue
			end

			self:_startMatch(mapName, modeName)
			self:_runMatchTimer()
		end
	end)
end

return singleton
