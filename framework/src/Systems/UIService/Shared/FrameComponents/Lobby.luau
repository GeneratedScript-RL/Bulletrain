--!strict

local Players = game:GetService("Players")

local root = script.Parent.Parent.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local LobbyDailyTasks = require(script.Parent.LobbyDailyTasks)
local MatchStates = require(script.Parent.Parent.Parent.Parent.MatchService.Shared.MatchStates)
local ObjectComponents = require(script.Parent.Parent.ObjectComponents)
local ProfileSnapshot = require(script.Parent.Parent.ProfileSnapshot)
local Trove = Dependencies.GetTrove()

type LobbyComponent = {
	Frame: GuiObject,
	PlayButton: ImageButton?,
	SettingsButton: GuiButton?,
	InventoryButton: GuiButton?,
	ShopButton: GuiButton?,
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

local localPlayer = Players.LocalPlayer

local function findButton(container: Instance?, childName: string?): GuiButton?
	if not container then
		return nil
	end

	if childName then
		local namedChild = container:FindFirstChild(childName)
		if namedChild and namedChild:IsA("GuiButton") then
			return namedChild
		end
	end

	local imageButton = container:FindFirstChildWhichIsA("ImageButton", true)
	if imageButton then
		return imageButton
	end

	return container:FindFirstChildWhichIsA("TextButton", true)
end

local function findTextLabel(container: Instance?, childName: string?): TextLabel?
	if not container then
		return nil
	end

	if childName then
		local namedChild = container:FindFirstChild(childName)
		if namedChild and namedChild:IsA("TextLabel") then
			return namedChild
		end
	end

	return container:FindFirstChildWhichIsA("TextLabel", true)
end

local function findImageLabel(container: Instance?, childName: string?): ImageLabel?
	if not container then
		return nil
	end

	if childName then
		local namedChild = container:FindFirstChild(childName)
		if namedChild and namedChild:IsA("ImageLabel") then
			return namedChild
		end
	end

	return container:FindFirstChildWhichIsA("ImageLabel", true)
end

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

local function findTopTabButton(lobbyFrame: GuiObject, tabName: string): GuiButton?
	local topTabs = lobbyFrame:FindFirstChild("TopTabs")
	if not topTabs then
		return nil
	end

	local tabFrame = topTabs:FindFirstChild(tabName)
	if not tabFrame then
		return nil
	end

	return findButton(tabFrame, "ImageButton")
end

local function applyHoverTween(
	trove: Types.Trove,
	target: GuiObject?,
	hoverScale: number,
	duration: number,
	tweenSettings: { [string]: any }?
)
	if not target then
		return
	end

	trove:Add(ObjectComponents.ButtonHoverTween.apply(
		target,
		target.Size + UDim2.fromScale(hoverScale, hoverScale),
		target.Size,
		duration,
		tweenSettings
	))
end

local function setOptionalImage(imageLabel: ImageLabel?, image: string)
	if imageLabel and image ~= "" then
		imageLabel.Image = image
	end
end

local function bindTopRight(
	lobbyFrame: GuiObject,
	trove: Types.Trove,
	shopController: any,
	statsController: any
)
	local topRight = lobbyFrame:FindFirstChild("TopRight")
	if not topRight or not topRight:IsA("GuiObject") then
		warn("[UIController] Lobby.TopRight not found")
		return
	end

	local currencyFrame = topRight:FindFirstChild("CurrencyFrame")
	local levelFrame = topRight:FindFirstChild("LevelFrame")
	local currencyHolder = if currencyFrame then currencyFrame:FindFirstChild("CurrencyHolder") else nil
	local levelHolder = if levelFrame then levelFrame:FindFirstChild("CurrencyHolder") else nil
	local currencyPlusFrame = if currencyFrame then (currencyFrame:FindFirstChild("PlusButton") :: GuiObject?) else nil
	local levelPlusFrame = if levelFrame then (levelFrame:FindFirstChild("PlusButton") :: GuiObject?) else nil

	local coinsAmountLabel = findTextLabel(currencyHolder, "Amount")
	local coinsPlusButton = findButton(currencyPlusFrame, "ImageButton")
	local levelLabel = findTextLabel(levelHolder, "Level")
	local profileHolder = if levelHolder then levelHolder:FindFirstChild("ProfileHolder") else nil
	local profileImage = findImageLabel(profileHolder, "ImageLabel")
	local barFrame = if levelHolder then levelHolder:FindFirstChild("Bar") else nil
	local fullBar = if barFrame then (barFrame:FindFirstChild("FullBar") :: GuiObject?) else nil
	local xpLabel = findTextLabel(barFrame, "Level")
	local levelStatsButton = findButton(levelPlusFrame, "ImageButton")

	local originalBarYScale = if fullBar then fullBar.Size.Y.Scale else 1
	local originalBarYOffset = if fullBar then fullBar.Size.Y.Offset else 0

	applyHoverTween(trove, coinsPlusButton, 0.04, 0.12, {
		VisualTarget = currencyPlusFrame,
		HoverOffset = Vector2.new(0, -4),
	})
	applyHoverTween(trove, levelStatsButton, 0.03, 0.12, {
		VisualTarget = levelPlusFrame,
		HoverOffset = Vector2.new(0, -4),
	})

	if coinsPlusButton then
		trove:Connect(coinsPlusButton.Activated, function()
			shopController:Open("Coins")
		end)
	else
		warn("[UIController] Lobby.TopRight.CurrencyFrame.PlusButton.ImageButton not found")
	end

	if levelStatsButton then
		trove:Connect(levelStatsButton.Activated, function()
			statsController:Open()
		end)
	else
		warn("[UIController] Lobby.TopRight.LevelFrame.PlusButton.ImageButton not found")
	end

	ProfileSnapshot.Observe(localPlayer, trove, function(snapshot: ProfileSnapshot.ProfileSnapshot)
		if coinsAmountLabel then
			coinsAmountLabel.Text = ProfileSnapshot.FormatInteger(snapshot.Credits)
		end

		if levelLabel then
			levelLabel.Text = ("LVL %d"):format(snapshot.Level)
		end

		if xpLabel then
			xpLabel.Text = ("%s/%s EXP"):format(
				ProfileSnapshot.FormatInteger(snapshot.XP),
				ProfileSnapshot.FormatInteger(snapshot.RequiredXP)
			)
		end

		if fullBar then
			fullBar.Size = UDim2.new(snapshot.Progress, 0, originalBarYScale, originalBarYOffset)
		end
	end)

	if profileImage then
		task.spawn(function()
			local ok, image = pcall(function()
				return Players:GetUserThumbnailAsync(
					localPlayer.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size150x150
				)
			end)

			if ok and profileImage.Parent then
				setOptionalImage(profileImage, image)
			end
		end)
	end
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
	applyHoverTween(component._trove, playButton, 0.1, 0.2, {
		VisualTarget = playButton,
		HoverOffset = Vector2.new(0, -6),
		HoverRotation = -1,
		PressScaleMultiplier = 0.95,
	})

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
	local settingsController = framework.GetController("SettingsController")
	local inventoryController = framework.GetController("InventoryController")
	local shopController = framework.GetController("ShopController")
	local statsController = framework.GetController("StatsController")
	local trove = Trove.new()

	local component: LobbyComponent = {
		Frame = lobbyFrame,
		PlayButton = nil :: ImageButton?,
		SettingsButton = nil :: GuiButton?,
		InventoryButton = nil :: GuiButton?,
		ShopButton = nil :: GuiButton?,
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
	local settingsButton = findTopTabButton(lobbyFrame, "Settings")
	local inventoryButton = findTopTabButton(lobbyFrame, "Inventory")
	local shopButton = findTopTabButton(lobbyFrame, "Shop")
	local dailyTasksFrame = lobbyFrame:FindFirstChild("DailyTasks")
	local entranceTargets = {} :: { GuiObject }
	local topTabsFrame = lobbyFrame:FindFirstChild("TopTabs")
	local playFrame = lobbyFrame:FindFirstChild("Play")
	local topRightFrame = lobbyFrame:FindFirstChild("TopRight")

	if topTabsFrame and topTabsFrame:IsA("GuiObject") then
		table.insert(entranceTargets, topTabsFrame)
	end

	if playFrame and playFrame:IsA("GuiObject") then
		table.insert(entranceTargets, playFrame)
	end

	if topRightFrame and topRightFrame:IsA("GuiObject") then
		table.insert(entranceTargets, topRightFrame)
	end

	if #entranceTargets > 0 then
		trove:Add(ObjectComponents.FrameEntranceTween.apply(lobbyFrame, entranceTargets, {
			StartScale = 0.97,
			Offset = Vector2.new(0, 14),
			Stagger = 0.04,
		}))
	end

	if playButton then
		component.PlayButton = playButton
		component.PlayButtonTransparency = playButton.ImageTransparency
		setupPlayButton(playButton, component, matchService)
	else
		warn("[UIController] Play button not found at expected path: Lobby.Play.Button.ImageButton")
	end

	if settingsButton then
		component.SettingsButton = settingsButton
		applyHoverTween(trove, settingsButton, 0.05, 0.15, {
			VisualTarget = settingsButton.Parent :: GuiObject?,
			HoverOffset = Vector2.new(0, -4),
			HoverRotation = -1,
		})

		trove:Connect(settingsButton.Activated, function()
			settingsController:Toggle()
		end)
	else
		warn("[UIController] Settings button not found at expected path: Lobby.TopTabs.Settings.ImageButton")
	end

	if inventoryButton then
		component.InventoryButton = inventoryButton
		applyHoverTween(trove, inventoryButton, 0.05, 0.15, {
			VisualTarget = inventoryButton.Parent :: GuiObject?,
			HoverOffset = Vector2.new(0, -4),
		})

		trove:Connect(inventoryButton.Activated, function()
			inventoryController:Open()
		end)
	else
		warn("[UIController] Inventory button not found at expected path: Lobby.TopTabs.Inventory.ImageButton")
	end

	if shopButton then
		component.ShopButton = shopButton
		applyHoverTween(trove, shopButton, 0.05, 0.15, {
			VisualTarget = shopButton.Parent :: GuiObject?,
			HoverOffset = Vector2.new(0, -4),
			HoverRotation = 1,
		})

		trove:Connect(shopButton.Activated, function()
			shopController:Open()
		end)
	else
		warn("[UIController] Shop button not found at expected path: Lobby.TopTabs.Shop.ImageButton")
	end

	bindTopRight(lobbyFrame, trove, shopController, statsController)

	if dailyTasksFrame and dailyTasksFrame:IsA("GuiObject") then
		local dailyTasksComponent = LobbyDailyTasks.bind(dailyTasksFrame)
		if dailyTasksComponent then
			trove:Add(dailyTasksComponent)
		end
	else
		warn("[UIController] DailyTasks frame not found at expected path: Lobby.DailyTasks")
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
