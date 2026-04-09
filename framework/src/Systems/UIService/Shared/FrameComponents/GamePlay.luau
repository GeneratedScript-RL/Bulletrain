--!strict

local Players = game:GetService("Players")

local root = script.Parent.Parent.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local Trove = Dependencies.GetTrove()

local MAX_TOP_PLAYERS = 5
local MAX_KILLFEED_ENTRIES = 4
local KILLFEED_ENTRY_LIFETIME = 6

type WeaponSlotState = {
	Frame: GuiObject,
	ImageLabel: ImageLabel?,
	KeybindFrame: GuiObject?,
	OriginalFrameTransparency: number,
	OriginalImageTransparency: number,
	OriginalImageColor: Color3,
	OriginalKeybindTransparency: number,
}

type KillFeedEntry = {
	Id: number,
	KillerName: string,
	VictimName: string,
	WeaponName: string,
}

type RankedPlayer = {
	Player: Player,
	Kills: number,
}

type GamePlayComponent = {
	Frame: GuiObject,
	HealthAmountLabel: TextLabel?,
	HealthBar: GuiObject?,
	HealthBarFullSize: UDim2,
	KillFeedFrame: GuiObject?,
	KillFeedTemplate: GuiObject?,
	KillFeedEntries: { KillFeedEntry },
	DynamicKillFeedFrames: { GuiObject },
	NextKillFeedId: number,
	DefaultKillFeedImage: string,
	ShotgunKillImage: string,
	KnifeKillImage: string,
	ShotgunSlot: WeaponSlotState?,
	KnifeSlot: WeaponSlotState?,
	TimerLabel: TextLabel?,
	PlayerListFrame: GuiObject?,
	PlayerListTemplate: GuiObject?,
	DynamicTopEntries: { GuiObject },
	KillCounts: { [number]: number },
	ThumbnailCache: { [number]: string },
	_characterTrove: Types.Trove?,
	_destroyed: boolean,
	_trove: Types.Trove,
	Destroy: (self: GamePlayComponent) -> (),
}

local GamePlay = {}

local localPlayer = Players.LocalPlayer

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

local function findGuiObject(container: Instance?, childName: string): GuiObject?
	if not container then
		return nil
	end

	local child = container:FindFirstChild(childName)
	if child and child:IsA("GuiObject") then
		return child
	end

	return nil
end

local function findUIStroke(container: Instance?, childName: string?): UIStroke?
	if not container then
		return nil
	end

	if childName then
		local namedChild = container:FindFirstChild(childName)
		if namedChild and namedChild:IsA("UIStroke") then
			return namedChild
		end
	end

	return container:FindFirstChildWhichIsA("UIStroke", true)
end

local function findUIGradient(container: Instance?, childName: string?): UIGradient?
	if not container then
		return nil
	end

	if childName then
		local namedChild = container:FindFirstChild(childName)
		if namedChild and namedChild:IsA("UIGradient") then
			return namedChild
		end
	end

	return container:FindFirstChildWhichIsA("UIGradient", true)
end

local function findChildWithPrefix(container: Instance?, prefix: string): GuiObject?
	if not container then
		return nil
	end

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") and string.sub(child.Name, 1, #prefix) == prefix then
			return child
		end
	end

	return nil
end

local function destroyChildrenWithPrefix(container: Instance?, prefix: string)
	if not container then
		return
	end

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") and string.sub(child.Name, 1, #prefix) == prefix then
			child:Destroy()
		end
	end
end

local function prepareTemplateFromPrefix(container: GuiObject?, prefix: string, templateName: string): GuiObject?
	if not container then
		return nil
	end

	local template: GuiObject? = nil

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") and string.sub(child.Name, 1, #prefix) == prefix then
			if template == nil then
				template = child
				template.Name = templateName
				template.Visible = false
				template.Archivable = true
				template.Parent = nil
			else
				child:Destroy()
			end
		end
	end

	return template
end

local function destroyGuiObjects(guiObjects: { GuiObject })
	for _, guiObject in ipairs(guiObjects) do
		guiObject:Destroy()
	end

	table.clear(guiObjects)
end

local function formatTimer(secondsRemaining: number): string
	local totalSeconds = math.max(math.floor(secondsRemaining + 0.5), 0)
	local minutes = math.floor(totalSeconds / 60)
	local seconds = totalSeconds % 60
	return ("%d:%02d"):format(minutes, seconds)
end

local function getKillFeedIcon(component: GamePlayComponent, weaponName: string): string
	if weaponName == "Knife" and component.KnifeKillImage ~= "" then
		return component.KnifeKillImage
	end

	if weaponName == "Shotgun" and component.ShotgunKillImage ~= "" then
		return component.ShotgunKillImage
	end

	if component.DefaultKillFeedImage ~= "" then
		return component.DefaultKillFeedImage
	end

	return if component.ShotgunKillImage ~= "" then component.ShotgunKillImage else component.KnifeKillImage
end

local function setHealth(component: GamePlayComponent, currentHealth: number, maxHealth: number)
	local safeMaxHealth = if maxHealth > 0 then maxHealth else 100
	local safeHealth = math.clamp(currentHealth, 0, safeMaxHealth)

	if component.HealthAmountLabel then
		component.HealthAmountLabel.Text = tostring(math.floor(safeHealth + 0.5))
	end

	if component.HealthBar then
		local ratio = if safeMaxHealth > 0 then safeHealth / safeMaxHealth else 0
		local fullSize = component.HealthBarFullSize
		component.HealthBar.Size = UDim2.new(
			fullSize.X.Scale * ratio,
			math.floor(fullSize.X.Offset * ratio + 0.5),
			fullSize.Y.Scale,
			fullSize.Y.Offset
		)
	end

	component.Frame:SetAttribute("Health", safeHealth)
	component.Frame:SetAttribute("MaxHealth", safeMaxHealth)
end

local function bindCharacter(component: GamePlayComponent, character: Model)
	if component._characterTrove then
		component._characterTrove:Clean()
	end

	local characterTrove = Trove.new()
	component._characterTrove = characterTrove

	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if not humanoid or not humanoid:IsA("Humanoid") then
		setHealth(component, 0, 100)
		return
	end

	local function refreshHealth()
		setHealth(component, humanoid.Health, humanoid.MaxHealth)
	end

	refreshHealth()
	characterTrove:Connect(humanoid.HealthChanged, refreshHealth)
	characterTrove:Connect(humanoid:GetPropertyChangedSignal("MaxHealth"), refreshHealth)
end

local function createWeaponSlotState(slotFrame: Instance?): WeaponSlotState?
	if not slotFrame or not slotFrame:IsA("GuiObject") then
		return nil
	end

	local imageLabel = findImageLabel(slotFrame, "ImageLabel")
	local keybindFrame = findGuiObject(slotFrame, "Keybind")

	return {
		Frame = slotFrame,
		ImageLabel = imageLabel,
		KeybindFrame = keybindFrame,
		OriginalFrameTransparency = slotFrame.BackgroundTransparency,
		OriginalImageTransparency = if imageLabel then imageLabel.ImageTransparency else 0,
		OriginalImageColor = if imageLabel then imageLabel.ImageColor3 else Color3.new(1, 1, 1),
		OriginalKeybindTransparency = if keybindFrame then keybindFrame.BackgroundTransparency else 0.2,
	}
end

local function applyWeaponSlotState(slotState: WeaponSlotState?, isEquipped: boolean)
	if not slotState then
		return
	end

	slotState.Frame.BackgroundTransparency = if isEquipped
		then math.min(slotState.OriginalFrameTransparency, 0.7)
		else slotState.OriginalFrameTransparency
	slotState.Frame:SetAttribute("Equipped", isEquipped)

	if slotState.ImageLabel then
		slotState.ImageLabel.ImageTransparency = if isEquipped
			then slotState.OriginalImageTransparency
			else math.clamp(slotState.OriginalImageTransparency + 0.35, 0, 1)
		slotState.ImageLabel.ImageColor3 = if isEquipped
			then slotState.OriginalImageColor
			else slotState.OriginalImageColor:Lerp(Color3.fromRGB(110, 110, 110), 0.45)
	end

	if slotState.KeybindFrame then
		slotState.KeybindFrame.BackgroundTransparency = if isEquipped
			then math.max(slotState.OriginalKeybindTransparency - 0.08, 0)
			else math.min(slotState.OriginalKeybindTransparency + 0.18, 1)
	end
end

local function refreshWeaponSlots(component: GamePlayComponent, equippedWeaponName: string?)
	applyWeaponSlotState(component.ShotgunSlot, equippedWeaponName == "Shotgun")
	applyWeaponSlotState(component.KnifeSlot, equippedWeaponName == "Knife")
	component.Frame:SetAttribute("EquippedWeapon", equippedWeaponName)
end

local function renderKillFeed(component: GamePlayComponent)
	destroyGuiObjects(component.DynamicKillFeedFrames)

	local killFeedFrame = component.KillFeedFrame
	local killFeedTemplate = component.KillFeedTemplate
	if not killFeedFrame or not killFeedTemplate then
		return
	end

	for index, killFeedEntry in ipairs(component.KillFeedEntries) do
		local row = killFeedTemplate:Clone()
		row.Name = ("DeathLog_%d"):format(killFeedEntry.Id)
		row.LayoutOrder = index
		row.Visible = true

		local killerLabel = findTextLabel(row, "Killer")
		local killedLabel = findTextLabel(row, "Killed")
		local imageLabel = findImageLabel(row, "ImageLabel")

		if killerLabel then
			killerLabel.Text = killFeedEntry.KillerName
		end

		if killedLabel then
			killedLabel.Text = killFeedEntry.VictimName
		end

		if imageLabel then
			local icon = getKillFeedIcon(component, killFeedEntry.WeaponName)
			if icon ~= "" then
				imageLabel.Image = icon
			end
		end

		row.Parent = killFeedFrame
		table.insert(component.DynamicKillFeedFrames, row)
	end
end

local function removeKillFeedEntry(component: GamePlayComponent, entryId: number)
	for index, killFeedEntry in ipairs(component.KillFeedEntries) do
		if killFeedEntry.Id == entryId then
			table.remove(component.KillFeedEntries, index)
			renderKillFeed(component)
			return
		end
	end
end

local function pushKillFeedEntry(component: GamePlayComponent, killerName: string, victimName: string, weaponName: string)
	component.NextKillFeedId += 1

	local killFeedEntry: KillFeedEntry = {
		Id = component.NextKillFeedId,
		KillerName = killerName,
		VictimName = victimName,
		WeaponName = weaponName,
	}

	table.insert(component.KillFeedEntries, 1, killFeedEntry)
	while #component.KillFeedEntries > MAX_KILLFEED_ENTRIES do
		table.remove(component.KillFeedEntries)
	end

	renderKillFeed(component)

	task.delay(KILLFEED_ENTRY_LIFETIME, function()
		if component._destroyed then
			return
		end

		removeKillFeedEntry(component, killFeedEntry.Id)
	end)
end

local function getPlayerAccentColor(player: Player): Color3?
	local team = player.Team
	if team then
		return team.TeamColor.Color
	end

	if not player.Neutral then
		return player.TeamColor.Color
	end

	return nil
end

local function applyPlayerCardTheme(player: Player, row: GuiObject)
	local accentColor = getPlayerAccentColor(player)
	if not accentColor then
		return
	end

	row.BackgroundColor3 = accentColor:Lerp(Color3.new(0, 0, 0), 0.24)

	local imageLabel = findImageLabel(row, "ImageLabel")
	if imageLabel then
		imageLabel.BackgroundColor3 = accentColor:Lerp(Color3.new(1, 1, 1), 0.18)
	end

	local innerStroke = findUIStroke(row, "Inner")
	if innerStroke then
		innerStroke.Color = accentColor:Lerp(Color3.new(1, 1, 1), 0.5)
	end

	local outerStroke = findUIStroke(row, "Outer")
	if outerStroke then
		outerStroke.Color = accentColor:Lerp(Color3.new(0, 0, 0), 0.08)
	end

	local gradient = findUIGradient(row, "UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, accentColor:Lerp(Color3.new(1, 1, 1), 0.2)),
			ColorSequenceKeypoint.new(1, accentColor:Lerp(Color3.new(0, 0, 0), 0.22)),
		})
	end
end

local function getRankedPlayers(component: GamePlayComponent): { RankedPlayer }
	local rankedPlayers: { RankedPlayer } = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local kills = component.KillCounts[player.UserId] or 0
		local playerState = player:GetAttribute("State")

		if playerState == "Combat" or kills > 0 then
			table.insert(rankedPlayers, {
				Player = player,
				Kills = kills,
			})
		end
	end

	table.sort(rankedPlayers, function(a: RankedPlayer, b: RankedPlayer): boolean
		if a.Kills ~= b.Kills then
			return a.Kills > b.Kills
		end

		return a.Player.Name < b.Player.Name
	end)

	while #rankedPlayers > MAX_TOP_PLAYERS do
		table.remove(rankedPlayers)
	end

	return rankedPlayers
end

local function applyThumbnail(component: GamePlayComponent, player: Player, imageLabel: ImageLabel)
	local cachedThumbnail = component.ThumbnailCache[player.UserId]
	if cachedThumbnail then
		imageLabel.Image = cachedThumbnail
		return
	end

	imageLabel:SetAttribute("ThumbnailUserId", player.UserId)

	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(
				player.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size150x150
			)
		end)

		if not ok or component._destroyed then
			return
		end

		component.ThumbnailCache[player.UserId] = image
		if imageLabel.Parent and imageLabel:GetAttribute("ThumbnailUserId") == player.UserId then
			imageLabel.Image = image
		end
	end)
end

local function renderTopPlayers(component: GamePlayComponent)
	destroyGuiObjects(component.DynamicTopEntries)

	local playerListFrame = component.PlayerListFrame
	local playerListTemplate = component.PlayerListTemplate
	if not playerListFrame or not playerListTemplate then
		return
	end

	for index, rankedPlayer in ipairs(getRankedPlayers(component)) do
		local row = playerListTemplate:Clone()
		row.Name = ("TopPlayer_%d"):format(rankedPlayer.Player.UserId)
		row.LayoutOrder = index
		row.Visible = true

		local killsLabel = findTextLabel(row, "Kills")
		local positionLabel = findTextLabel(row, "Position")
		local imageLabel = findImageLabel(row, "ImageLabel")

		if killsLabel then
			killsLabel.Text = tostring(rankedPlayer.Kills)
		end

		if positionLabel then
			positionLabel.Text = ("#%d"):format(index)
		end

		if imageLabel then
			applyThumbnail(component, rankedPlayer.Player, imageLabel)
		end

		applyPlayerCardTheme(rankedPlayer.Player, row)

		row.Parent = playerListFrame
		table.insert(component.DynamicTopEntries, row)
	end

	component.Frame:SetAttribute("TopPlayerCount", #component.DynamicTopEntries)
end

function GamePlay.Destroy(self: GamePlayComponent)
	self._destroyed = true

	if self._characterTrove then
		self._characterTrove:Clean()
		self._characterTrove = nil
	end

	destroyGuiObjects(self.DynamicKillFeedFrames)
	destroyGuiObjects(self.DynamicTopEntries)
	self._trove:Clean()
end

function GamePlay.init(gamePlayFrame: GuiObject): GamePlayComponent
	local matchService = framework.GetService("MatchService")
	local scoreService = framework.GetService("ScoreService")
	local combatService = framework.GetService("CombatService")
	local viewmodelController = framework.GetController("ViewmodelController")
	local trove = Trove.new()

	local healthFrame = findGuiObject(gamePlayFrame, "Health")
	local healthBarHolder = findGuiObject(healthFrame, "BarHolder")
	local healthBar = findGuiObject(healthBarHolder, "Bar")

	local killFeedFrame = findGuiObject(gamePlayFrame, "KillFeed")
	local killFeedTemplateSource = findChildWithPrefix(killFeedFrame, "DeathLog")
	local killFeedTemplate = if killFeedTemplateSource then killFeedTemplateSource:Clone() else nil

	local topFrame = findGuiObject(gamePlayFrame, "Top")
	local playerListFrame = findGuiObject(topFrame, "PlayerList")
	local playerListTemplate = prepareTemplateFromPrefix(playerListFrame, "Player", "PlayerTemplate")
	local timerFrame = findGuiObject(topFrame, "Timer")

	local shotgunSlot = createWeaponSlotState(gamePlayFrame:FindFirstChild("ShotgunSlot"))
	local knifeSlot = createWeaponSlotState(gamePlayFrame:FindFirstChild("KnifeSlot"))
	local killFeedImageLabel = findImageLabel(killFeedTemplate, "ImageLabel")

	local component: GamePlayComponent = {
		Frame = gamePlayFrame,
		HealthAmountLabel = findTextLabel(healthBarHolder, "Amount"),
		HealthBar = healthBar,
		HealthBarFullSize = if healthBar then healthBar.Size else UDim2.fromScale(1, 1),
		KillFeedFrame = killFeedFrame,
		KillFeedTemplate = killFeedTemplate,
		KillFeedEntries = {},
		DynamicKillFeedFrames = {},
		NextKillFeedId = 0,
		DefaultKillFeedImage = if killFeedImageLabel then killFeedImageLabel.Image else "",
		ShotgunKillImage = if shotgunSlot and shotgunSlot.ImageLabel then shotgunSlot.ImageLabel.Image else "",
		KnifeKillImage = if knifeSlot and knifeSlot.ImageLabel then knifeSlot.ImageLabel.Image else "",
		ShotgunSlot = shotgunSlot,
		KnifeSlot = knifeSlot,
		TimerLabel = findTextLabel(timerFrame, "Amount"),
		PlayerListFrame = playerListFrame,
		PlayerListTemplate = playerListTemplate,
		DynamicTopEntries = {},
		KillCounts = {},
		ThumbnailCache = {},
		_characterTrove = nil,
		_destroyed = false,
		_trove = trove,
		Destroy = GamePlay.Destroy,
	}

	destroyChildrenWithPrefix(killFeedFrame, "DeathLog")

	if component.KillFeedTemplate then
		component.KillFeedTemplate.Visible = true
	end

	if component.PlayerListTemplate then
		component.PlayerListTemplate.Visible = false
		trove:Add(component.PlayerListTemplate)
	end

	local initialCountdown = matchService.Countdown:OnReady(5)
	if type(initialCountdown) == "number" and component.TimerLabel then
		component.TimerLabel.Text = formatTimer(initialCountdown)
	end

	trove:Add(matchService.Countdown:Observe(function(countdown: number)
		if component.TimerLabel then
			component.TimerLabel.Text = formatTimer(countdown)
		end
	end))

	local function refreshLeaderboard()
		renderTopPlayers(component)
	end

	local initialKillCounts = scoreService.KillCounts:OnReady(5)
	if type(initialKillCounts) == "table" then
		component.KillCounts = initialKillCounts
	end

	trove:Add(scoreService.KillCounts:Observe(function(killCounts: { [number]: number })
		component.KillCounts = killCounts
		refreshLeaderboard()
	end))

	local function bindPlayerStateSignals(player: Player)
		trove:Connect(player:GetAttributeChangedSignal("State"), refreshLeaderboard)
		trove:Connect(player:GetPropertyChangedSignal("Team"), refreshLeaderboard)
		trove:Connect(player:GetPropertyChangedSignal("TeamColor"), refreshLeaderboard)
		trove:Connect(player:GetPropertyChangedSignal("Neutral"), refreshLeaderboard)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		bindPlayerStateSignals(player)
	end

	trove:Connect(Players.PlayerAdded, function(player: Player)
		bindPlayerStateSignals(player)
		refreshLeaderboard()
	end)

	trove:Connect(Players.PlayerRemoving, function()
		task.defer(function()
			if not component._destroyed then
				refreshLeaderboard()
			end
		end)
	end)

	trove:Add(combatService.KillFeedEntryAdded:Connect(function(payload: any)
		if type(payload) ~= "table" then
			return
		end

		local killerName = tostring(payload.killerName or "Unknown")
		local victimName = tostring(payload.victimName or "Unknown")
		local weaponName = tostring(payload.weaponName or "Shotgun")
		pushKillFeedEntry(component, killerName, victimName, weaponName)
	end))

	if viewmodelController.WeaponChanged then
		trove:Add(viewmodelController.WeaponChanged:Connect(function(weaponName: string?)
			refreshWeaponSlots(component, weaponName)
		end))
	end

	refreshWeaponSlots(component, viewmodelController:GetEquippedWeaponName())

	trove:Connect(localPlayer.CharacterAdded, function(character: Model)
		bindCharacter(component, character)
	end)

	trove:Connect(localPlayer.CharacterRemoving, function()
		if component._characterTrove then
			component._characterTrove:Clean()
			component._characterTrove = nil
		end

		setHealth(component, 0, 100)
	end)

	if localPlayer.Character then
		bindCharacter(component, localPlayer.Character)
	else
		setHealth(component, 0, 100)
	end

	refreshLeaderboard()

	return component
end

return GamePlay
