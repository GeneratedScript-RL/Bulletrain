--!strict

local root = script.Parent.Parent.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local MatchStates = require(script.Parent.Parent.Parent.Parent.MatchService.Shared.MatchStates)
local ObjectComponents = require(script.Parent.Parent.ObjectComponents)
local Trove = Dependencies.GetTrove()

type LobbyComponent = {
	Frame: GuiObject,
	PlayButton: ImageButton?,
	CanJoin: boolean,
	MatchRunning: boolean,
	MatchState: string,
	PlayerState: string,
	Countdown: number,
	SelectedMap: string,
	SelectedMode: string,
	PlayButtonTransparency: number,
	_trove: Types.Trove,
	Destroy: (self: LobbyComponent) -> (),
}

local Lobby = {}

local function findPlayButton(lobbyFrame: GuiObject): ImageButton?
	local playFrame = lobbyFrame:FindFirstChild("Play")
	if playFrame then
		local playButtonHolder = playFrame:FindFirstChild("Button")
		if playButtonHolder then
			local nestedPlayButton = playButtonHolder:FindFirstChild("ImageButton")
			if nestedPlayButton and nestedPlayButton:IsA("ImageButton") then
				return nestedPlayButton
			end
		end

		local fallbackPlayButton = playFrame:FindFirstChildWhichIsA("ImageButton", true)
		if fallbackPlayButton then
			return fallbackPlayButton
		end
	end

	return lobbyFrame:FindFirstChildWhichIsA("ImageButton", true)
end

local function getLobbyStatusText(component: LobbyComponent): string
	if component.PlayerState == "Combat" then
		return "In match"
	end

	if component.MatchRunning then
		return "Match in progress"
	end

	if component.MatchState == MatchStates.Voting then
		return if component.Countdown > 0
			then ("Voting ends in %ds"):format(component.Countdown)
			else "Voting in progress"
	end

	if component.MatchState == MatchStates.PostMatch then
		return if component.Countdown > 0
			then ("Next round in %ds"):format(component.Countdown)
			else "Match ended"
	end

	return if component.Countdown > 0
		then ("Next match in %ds"):format(component.Countdown)
		else "Waiting for next match"
end

local function refreshLobby(component: LobbyComponent)
	local canJoin = component.PlayerState == "Menu" and component.MatchRunning
	local statusText = getLobbyStatusText(component)

	component.CanJoin = canJoin
	component.Frame:SetAttribute("CanJoin", canJoin)
	component.Frame:SetAttribute("MatchState", component.MatchState)
	component.Frame:SetAttribute("PlayerState", component.PlayerState)
	component.Frame:SetAttribute("Countdown", component.Countdown)
	component.Frame:SetAttribute("SelectedMap", component.SelectedMap)
	component.Frame:SetAttribute("SelectedMode", component.SelectedMode)
	component.Frame:SetAttribute("StatusText", statusText)

	local playButton = component.PlayButton
	if not playButton then
		return
	end

	playButton.Active = canJoin
	playButton.Selectable = canJoin
	playButton.AutoButtonColor = canJoin
	playButton.ImageTransparency = if canJoin
		then component.PlayButtonTransparency
		else math.clamp(component.PlayButtonTransparency + 0.35, 0, 1)
	playButton:SetAttribute("CanJoin", canJoin)
	playButton:SetAttribute("StatusText", statusText)
end

local function setupPlayButton(playButton: ImageButton, component: LobbyComponent, matchService: any)
	-- Apply hover tween effect to the play button
	component._trove:Add(ObjectComponents.ButtonHoverTween.apply(
		playButton,
		playButton.Size + UDim2.new(0.1, 0, 0.1, 0), -- Hover size (10% larger)
		playButton.Size, -- Original size
		0.2 -- Duration in seconds
	))

	component._trove:Connect(playButton.Activated, function()
		if not component.CanJoin then
			return
		end

		matchService.RequestJoin:Fire()
	end)
end

function Lobby.Destroy(self: LobbyComponent)
	self._trove:Clean()
end

function Lobby.init(lobbyFrame: GuiObject): LobbyComponent
	local matchService = framework.GetService("MatchService")
	local playerStateService = framework.GetService("PlayerStateService")
	local trove = Trove.new()

	local component: LobbyComponent = {
		Frame = lobbyFrame,
		PlayButton = nil :: ImageButton?,
		CanJoin = false,
		MatchRunning = false,
		MatchState = MatchStates.Intermission,
		PlayerState = "Menu",
		Countdown = 0,
		SelectedMap = "",
		SelectedMode = "",
		PlayButtonTransparency = 0,
		_trove = trove,
		Destroy = Lobby.Destroy,
	}

	local playButton = findPlayButton(lobbyFrame)

	if playButton then
		component.PlayButton = playButton
		component.PlayButtonTransparency = playButton.ImageTransparency
		setupPlayButton(playButton, component, matchService)
	else
		warn("[UIController] Play button not found at expected path: Lobby.Play.Button.ImageButton")
	end

	trove:Add(matchService.MatchRunning:Observe(function(isRunning: boolean)
		component.MatchRunning = isRunning
		refreshLobby(component)
	end))

	trove:Add(matchService.CurrentState:Observe(function(matchState: string)
		component.MatchState = matchState
		refreshLobby(component)
	end))

	trove:Add(matchService.Countdown:Observe(function(countdown: number)
		component.Countdown = countdown
		refreshLobby(component)
	end))

	trove:Add(matchService.SelectedMap:Observe(function(selectedMap: string)
		component.SelectedMap = selectedMap
		refreshLobby(component)
	end))

	trove:Add(matchService.SelectedMode:Observe(function(selectedMode: string)
		component.SelectedMode = selectedMode
		refreshLobby(component)
	end))

	trove:Add(playerStateService.CurrentState:Observe(function(playerState: string)
		component.PlayerState = playerState
		refreshLobby(component)
	end))

	refreshLobby(component)

	return component
end

return Lobby
