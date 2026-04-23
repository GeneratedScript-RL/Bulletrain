--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local root = script.Parent.Parent.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any
local SharedConfig = require(root.Shared.common.Config)

local MatchStates = require(script.Parent.Parent.Parent.Parent.MatchService.Shared.MatchStates)
local Trove = Dependencies.GetTrove()

local CONTAINER_MAP_PREFIX = "ContainerMap"
local MAP_IMAGE_KEYS = { "PreviewImage", "MapImage", "Thumbnail", "Image", "Preview" }
local VOTING_SCREEN_COUNT = SharedConfig.Match.MapVoteOptionCount
local VOTING_SCREEN_GUI_NAME = "BulletrainVotingScreen"
local VOTING_SCREEN_FACE = Enum.NormalId.Left
local VOTING_SCREEN_CANVAS_SIZE = Vector2.new(960, 540)
local HEADER_HEIGHT = 86
local VOTE_HIGHLIGHT_COLOR = Color3.fromRGB(54, 255, 118)
local VOTE_HIGHLIGHT_PULSE_TRANSPARENCY = 0.35
local VOTE_HIGHLIGHT_REST_TRANSPARENCY = 0.9
local VOTE_HIGHLIGHT_TWEEN_INFO = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type ScreenRecord = {
	Slot: number,
	ScreenPart: BasePart,
	SurfaceGui: SurfaceGui,
	NameLabel: TextLabel,
	ImageLabel: ImageLabel,
	EmptyLabel: TextLabel,
	HighlightFrame: Frame,
	HighlightTween: Tween?,
}

type MapSelectionComponent = {
	Frame: GuiObject,
	MatchService: any,
	MapOptions: { string },
	MatchState: string,
	LocalVoteSlot: number?,
	LocalVoteMap: string,
	FallbackImage: string,
	MapImageCache: { [string]: string },
	ScreenRecords: { ScreenRecord },
	VotingPads: { [number]: BasePart },
	_warnedMissingScreens: boolean,
	_warnedMissingPads: boolean,
	_destroyed: boolean,
	_screenTrove: Types.Trove?,
	_padTrove: Types.Trove?,
	_trove: Types.Trove,
	Destroy: (self: MapSelectionComponent) -> (),
}

local MapSelection = {}
local localPlayer = Players.LocalPlayer

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

local function getTemplateCards(frame: GuiObject): { GuiObject }
	local cards = {} :: { GuiObject }

	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("GuiObject") and string.sub(child.Name, 1, #CONTAINER_MAP_PREFIX) == CONTAINER_MAP_PREFIX then
			table.insert(cards, child)
		end
	end

	table.sort(cards, function(left: GuiObject, right: GuiObject): boolean
		if left.LayoutOrder == right.LayoutOrder then
			return left.Name < right.Name
		end

		return left.LayoutOrder < right.LayoutOrder
	end)

	return cards
end

local function getFallbackImageFromTemplate(frame: GuiObject): string
	local templateCards = getTemplateCards(frame)
	local fallbackImage = ""

	for _, template in ipairs(templateCards) do
		if fallbackImage == "" then
			local imageLabel = findImageLabel(template, "MapImage")
			if imageLabel then
				fallbackImage = imageLabel.Image
			end
		end

		template:Destroy()
	end

	return fallbackImage
end

local function getMapsFolder(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets or not assets:IsA("Folder") then
		return nil
	end

	local mapsFolder = assets:FindFirstChild("Maps")
	if mapsFolder and mapsFolder:IsA("Folder") then
		return mapsFolder
	end

	return nil
end

local function resolveImageValue(instance: Instance): string?
	if instance:IsA("StringValue") then
		return instance.Value
	end

	if instance:IsA("Decal") or instance:IsA("Texture") then
		return instance.Texture
	end

	return nil
end

local function getMapDisplayName(mapName: string): string
	local mapDefinition = SharedConfig.Maps[mapName]
	if mapDefinition then
		local displayName = mapDefinition.DisplayName
		if type(displayName) == "string" and displayName ~= "" then
			return displayName
		end
	end

	return mapName
end

local function resolveMapImage(component: MapSelectionComponent, mapName: string): string
	local cachedImage = component.MapImageCache[mapName]
	if cachedImage ~= nil then
		return cachedImage
	end

	local resolvedImage = component.FallbackImage
	local mapDefinition = SharedConfig.Maps[mapName]
	if mapDefinition then
		local icon = mapDefinition.Icon
		if type(icon) == "string" and icon ~= "" then
			resolvedImage = icon
			component.MapImageCache[mapName] = resolvedImage
			return resolvedImage
		end
	end

	local mapsFolder = getMapsFolder()
	local mapModel = if mapsFolder then mapsFolder:FindFirstChild(mapName) else nil

	if mapModel then
		for _, key in ipairs(MAP_IMAGE_KEYS) do
			local attributeValue = mapModel:GetAttribute(key)
			if type(attributeValue) == "string" and attributeValue ~= "" then
				resolvedImage = attributeValue
				break
			end

			local childValue = mapModel:FindFirstChild(key)
			if childValue then
				local imageValue = resolveImageValue(childValue)
				if imageValue and imageValue ~= "" then
					resolvedImage = imageValue
					break
				end
			end
		end
	end

	component.MapImageCache[mapName] = resolvedImage
	return resolvedImage
end

local function findNamedBasePart(container: Instance, partName: string): BasePart?
	local directChild = container:FindFirstChild(partName)
	if directChild and directChild:IsA("BasePart") then
		return directChild
	end

	for _, descendant in container:GetDescendants() do
		if descendant.Name == partName and descendant:IsA("BasePart") then
			return descendant
		end
	end

	return nil
end

local function createLabel(parent: Instance, name: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(246, 248, 250)
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function createVotingScreen(screenPart: BasePart, slot: number, trove: Types.Trove): ScreenRecord
	local existingGui = screenPart:FindFirstChild(VOTING_SCREEN_GUI_NAME)
	if existingGui then
		existingGui:Destroy()
	end

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = VOTING_SCREEN_GUI_NAME
	surfaceGui.Adornee = screenPart
	surfaceGui.Face = VOTING_SCREEN_FACE
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surfaceGui.CanvasSize = VOTING_SCREEN_CANVAS_SIZE
	surfaceGui.AlwaysOnTop = false
	surfaceGui.LightInfluence = 0
	surfaceGui.Enabled = false
	surfaceGui.Parent = screenPart
	trove:Add(surfaceGui)

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.BackgroundColor3 = Color3.fromRGB(8, 11, 14)
	background.BorderSizePixel = 0
	background.Size = UDim2.fromScale(1, 1)
	background.ZIndex = 1
	background.Parent = surfaceGui

	local mapImage = Instance.new("ImageLabel")
	mapImage.Name = "MapImage"
	mapImage.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
	mapImage.BorderSizePixel = 0
	mapImage.Position = UDim2.fromOffset(0, HEADER_HEIGHT)
	mapImage.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT)
	mapImage.ScaleType = Enum.ScaleType.Crop
	mapImage.ZIndex = 1
	mapImage.Parent = background

	local highlight = Instance.new("Frame")
	highlight.Name = "VoteHighlight"
	highlight.BackgroundColor3 = VOTE_HIGHLIGHT_COLOR
	highlight.BackgroundTransparency = 1
	highlight.BorderSizePixel = 0
	highlight.Size = UDim2.fromScale(1, 1)
	highlight.Visible = false
	highlight.ZIndex = 2
	highlight.Parent = background

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundColor3 = Color3.fromRGB(9, 14, 20)
	header.BackgroundTransparency = 0.05
	header.BorderSizePixel = 0
	header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	header.ZIndex = 3
	header.Parent = background

	local headerStroke = Instance.new("UIStroke")
	headerStroke.Name = "BottomLine"
	headerStroke.Color = Color3.fromRGB(95, 180, 255)
	headerStroke.Thickness = 2
	headerStroke.Transparency = 0.25
	headerStroke.Parent = header

	local nameLabel = createLabel(header, "MapName")
	nameLabel.Position = UDim2.fromOffset(24, 4)
	nameLabel.Size = UDim2.new(1, -48, 1, -8)
	nameLabel.ZIndex = 4

	local emptyLabel = createLabel(background, "Empty")
	emptyLabel.Font = Enum.Font.GothamMedium
	emptyLabel.TextColor3 = Color3.fromRGB(168, 178, 188)
	emptyLabel.Text = ""
	emptyLabel.Position = UDim2.fromOffset(40, HEADER_HEIGHT)
	emptyLabel.Size = UDim2.new(1, -80, 1, -HEADER_HEIGHT)
	emptyLabel.Visible = false
	emptyLabel.ZIndex = 4

	surfaceGui:SetAttribute("VotingSlot", slot)
	screenPart:SetAttribute("VotingSlot", slot)

	return {
		Slot = slot,
		ScreenPart = screenPart,
		SurfaceGui = surfaceGui,
		NameLabel = nameLabel,
		ImageLabel = mapImage,
		EmptyLabel = emptyLabel,
		HighlightFrame = highlight,
		HighlightTween = nil,
	}
end

local function getVotingScreensModel(): Instance?
	local lobby = Workspace:FindFirstChild("Lobby")
	if not lobby then
		return nil
	end

	return lobby:FindFirstChild("VotingScreens")
end

local function getVotingPadsModel(): Instance?
	local lobby = Workspace:FindFirstChild("Lobby")
	if not lobby then
		return nil
	end

	return lobby:FindFirstChild("VotingPads")
end

local function isLocalCharacterPart(part: BasePart): boolean
	local character = localPlayer.Character
	return character ~= nil and part:IsDescendantOf(character)
end

local function ensureScreenRecords(component: MapSelectionComponent)
	if component._screenTrove then
		return
	end

	local votingScreens = getVotingScreensModel()
	if not votingScreens then
		if not component._warnedMissingScreens then
			component._warnedMissingScreens = true
			warn("[MapSelection] workspace.Lobby.VotingScreens missing; map voting screens unavailable")
		end
		return
	end

	local screenTrove = Trove.new()
	component._screenTrove = screenTrove

	for slot = 1, VOTING_SCREEN_COUNT do
		local screenPart = findNamedBasePart(votingScreens, tostring(slot))
		if not screenPart then
			warn(("[MapSelection] Voting screen %d missing under workspace.Lobby.VotingScreens"):format(slot))
			continue
		end

		table.insert(component.ScreenRecords, createVotingScreen(screenPart, slot, screenTrove))
	end
end

local function cancelHighlightTween(record: ScreenRecord)
	local tween = record.HighlightTween
	if tween then
		tween:Cancel()
		record.HighlightTween = nil
	end
end

local function setHighlightRest(record: ScreenRecord, isSelected: boolean)
	cancelHighlightTween(record)
	record.HighlightFrame.Visible = isSelected
	record.HighlightFrame.BackgroundTransparency = if isSelected then VOTE_HIGHLIGHT_REST_TRANSPARENCY else 1
end

local function pulseHighlight(record: ScreenRecord)
	cancelHighlightTween(record)

	record.HighlightFrame.Visible = true
	record.HighlightFrame.BackgroundTransparency = VOTE_HIGHLIGHT_PULSE_TRANSPARENCY

	local tween = TweenService:Create(record.HighlightFrame, VOTE_HIGHLIGHT_TWEEN_INFO, {
		BackgroundTransparency = VOTE_HIGHLIGHT_REST_TRANSPARENCY,
	})

	record.HighlightTween = tween
	tween.Completed:Connect(function()
		if record.HighlightTween == tween then
			record.HighlightTween = nil
		end
	end)
	tween:Play()
end

local function refreshVoteHighlights(component: MapSelectionComponent, pulseSlot: number?)
	local isVoting = component.MatchState == MatchStates.Voting
	for _, record in ipairs(component.ScreenRecords) do
		local isSelected = isVoting and component.LocalVoteSlot == record.Slot
		if isSelected and pulseSlot == record.Slot then
			pulseHighlight(record)
		else
			setHighlightRest(record, isSelected)
		end
	end
end

local function clearLocalVote(component: MapSelectionComponent)
	component.LocalVoteSlot = nil
	component.LocalVoteMap = ""
	refreshVoteHighlights(component, nil)
end

local function submitLocalVote(component: MapSelectionComponent, slot: number)
	if component.MatchState ~= MatchStates.Voting then
		return
	end

	local mapName = component.MapOptions[slot]
	if type(mapName) ~= "string" or mapName == "" then
		return
	end

	local voteChanged = component.LocalVoteSlot ~= slot or component.LocalVoteMap ~= mapName
	component.LocalVoteSlot = slot
	component.LocalVoteMap = mapName
	if voteChanged then
		component.MatchService.SubmitVote:Fire("map", mapName)
	end
	refreshVoteHighlights(component, slot)
end

local function ensureVotingPadConnections(component: MapSelectionComponent)
	if component._padTrove then
		return
	end

	local votingPads = getVotingPadsModel()
	if not votingPads then
		if not component._warnedMissingPads then
			component._warnedMissingPads = true
			warn("[MapSelection] workspace.Lobby.VotingPads missing; local vote highlights unavailable")
		end
		return
	end

	local padTrove = Trove.new()
	component._padTrove = padTrove

	for slot = 1, VOTING_SCREEN_COUNT do
		local pad = findNamedBasePart(votingPads, tostring(slot))
		if not pad then
			warn(("[MapSelection] Voting pad %d missing under workspace.Lobby.VotingPads"):format(slot))
			continue
		end

		component.VotingPads[slot] = pad
		padTrove:Connect(pad.Touched, function(touchedPart: BasePart)
			if isLocalCharacterPart(touchedPart) then
				submitLocalVote(component, slot)
			end
		end)
	end
end

local function submitCurrentLocalVotingPadOccupants(component: MapSelectionComponent)
	ensureVotingPadConnections(component)

	if not component._padTrove or component.MatchState ~= MatchStates.Voting then
		return
	end

	for slot, pad in component.VotingPads do
		for _, touchingPart in ipairs(pad:GetTouchingParts()) do
			if isLocalCharacterPart(touchingPart) then
				submitLocalVote(component, slot)
				return
			end
		end
	end
end

local function refreshScreens(component: MapSelectionComponent)
	component.Frame.Visible = false
	component.Frame:SetAttribute("OpenOverride", false)
	component.Frame:SetAttribute("MatchState", component.MatchState)
	component.Frame:SetAttribute("MapCount", #component.MapOptions)

	ensureScreenRecords(component)
	ensureVotingPadConnections(component)

	local isVoting = component.MatchState == MatchStates.Voting
	if not isVoting then
		clearLocalVote(component)
	elseif component.LocalVoteSlot then
		local currentVoteMap = component.MapOptions[component.LocalVoteSlot]
		if currentVoteMap ~= component.LocalVoteMap then
			clearLocalVote(component)
		end
	end

	for _, record in ipairs(component.ScreenRecords) do
		local mapName = component.MapOptions[record.Slot]
		local resolvedMapName = if type(mapName) == "string" then mapName else ""
		local hasMap = isVoting and resolvedMapName ~= ""

		record.SurfaceGui.Enabled = hasMap
		record.SurfaceGui:SetAttribute("MapName", if hasMap then resolvedMapName else "")
		record.ScreenPart:SetAttribute("MapName", if hasMap then resolvedMapName else "")

		if hasMap then
			local image = resolveMapImage(component, resolvedMapName)
			record.NameLabel.Text = getMapDisplayName(resolvedMapName)
			record.ImageLabel.Image = image
			record.ImageLabel.Visible = image ~= ""
			record.EmptyLabel.Visible = image == ""
			record.EmptyLabel.Text = if image == "" then getMapDisplayName(resolvedMapName) else ""
		else
			record.NameLabel.Text = ""
			record.ImageLabel.Image = ""
			record.ImageLabel.Visible = false
			record.EmptyLabel.Visible = false
			record.EmptyLabel.Text = ""
		end
	end

	refreshVoteHighlights(component, nil)
end

function MapSelection.Destroy(self: MapSelectionComponent)
	self._destroyed = true

	if self._screenTrove then
		self._screenTrove:Clean()
		self._screenTrove = nil
	end

	if self._padTrove then
		self._padTrove:Clean()
		self._padTrove = nil
	end

	for _, record in ipairs(self.ScreenRecords) do
		cancelHighlightTween(record)
	end

	table.clear(self.ScreenRecords)
	table.clear(self.VotingPads)
	self._trove:Clean()
end

function MapSelection.init(mapSelectionFrame: GuiObject): MapSelectionComponent
	local matchService = framework.GetService("MatchService")
	local trove = Trove.new()

	local component: MapSelectionComponent = {
		Frame = mapSelectionFrame,
		MatchService = matchService,
		MapOptions = {},
		MatchState = MatchStates.Intermission,
		LocalVoteSlot = nil,
		LocalVoteMap = "",
		FallbackImage = getFallbackImageFromTemplate(mapSelectionFrame),
		MapImageCache = {},
		ScreenRecords = {},
		VotingPads = {},
		_warnedMissingScreens = false,
		_warnedMissingPads = false,
		_destroyed = false,
		_screenTrove = nil,
		_padTrove = nil,
		_trove = trove,
		Destroy = MapSelection.Destroy,
	}

	mapSelectionFrame.Visible = false
	mapSelectionFrame:SetAttribute("OpenOverride", false)

	local initialMatchState = matchService.CurrentState:OnReady(5)
	if type(initialMatchState) == "string" then
		component.MatchState = initialMatchState
	end

	local initialMapOptions = matchService.MapOptions:OnReady(5)
	if type(initialMapOptions) == "table" then
		component.MapOptions = table.clone(initialMapOptions)
	end

	trove:Add(matchService.CurrentState:Observe(function(matchState: string)
		component.MatchState = matchState
		refreshScreens(component)
		if matchState == MatchStates.Voting then
			task.defer(function()
				if not component._destroyed then
					submitCurrentLocalVotingPadOccupants(component)
				end
			end)
		end
	end))

	trove:Add(matchService.MapOptions:Observe(function(mapOptions: { string })
		component.MapOptions = table.clone(mapOptions)
		refreshScreens(component)
		if component.MatchState == MatchStates.Voting then
			task.defer(function()
				if not component._destroyed then
					submitCurrentLocalVotingPadOccupants(component)
				end
			end)
		end
	end))

	trove:Add(matchService.VotingStarted:Connect(function(_payload: any)
		clearLocalVote(component)
		refreshScreens(component)
		task.defer(function()
			if not component._destroyed then
				submitCurrentLocalVotingPadOccupants(component)
			end
		end)
	end))

	task.spawn(function()
		if not Workspace:FindFirstChild("Lobby") then
			Workspace:WaitForChild("Lobby", 10)
		end

		if component._destroyed then
			return
		end

		local lobby = Workspace:FindFirstChild("Lobby")
		if lobby and not lobby:FindFirstChild("VotingScreens") then
			lobby:WaitForChild("VotingScreens", 10)
		end

		if lobby and not lobby:FindFirstChild("VotingPads") then
			lobby:WaitForChild("VotingPads", 10)
		end

		if not component._destroyed then
			refreshScreens(component)
			submitCurrentLocalVotingPadOccupants(component)
		end
	end)

	refreshScreens(component)

	return component
end

return MapSelection
