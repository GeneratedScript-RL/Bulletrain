--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local root = script.Parent.Parent.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local MatchStates = require(script.Parent.Parent.Parent.Parent.MatchService.Shared.MatchStates)
local Trove = Dependencies.GetTrove()

local CONTAINER_MAP_PREFIX = "ContainerMap"
local MAP_IMAGE_KEYS = { "PreviewImage", "MapImage", "Thumbnail", "Image", "Preview" }

type MapCardRecord = {
	Frame: GuiObject,
	Button: GuiButton?,
	Glow: GuiObject?,
	CheckMark: GuiObject?,
	NameLabel: TextLabel?,
	ImageLabel: ImageLabel?,
	VoteAvatarFrame: GuiObject?,
	VoteAvatarImage: ImageLabel?,
	BaseImage: string,
	MapName: string,
}

type MapSelectionComponent = {
	Frame: GuiObject,
	TemplateCard: GuiObject?,
	CardRecords: { MapCardRecord },
	MapOptions: { string },
	LocalVote: string,
	MatchState: string,
	PlayerThumbnail: string,
	MapImageCache: { [string]: string },
	_cardTrove: Types.Trove?,
	_trove: Types.Trove,
	Destroy: (self: MapSelectionComponent) -> (),
}

local MapSelection = {}

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

local function destroyCardFrames(cardRecords: { MapCardRecord })
	for _, cardRecord in ipairs(cardRecords) do
		cardRecord.Frame:Destroy()
	end

	table.clear(cardRecords)
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

local function resolveMapImage(component: MapSelectionComponent, mapName: string, fallbackImage: string): string
	local cachedImage = component.MapImageCache[mapName]
	if cachedImage ~= nil then
		return cachedImage
	end

	local resolvedImage = fallbackImage
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

local function applyCardState(component: MapSelectionComponent, cardRecord: MapCardRecord)
	local isVoting = component.MatchState == MatchStates.Voting
	local isSelected = component.LocalVote == cardRecord.MapName

	cardRecord.Frame.Visible = true
	cardRecord.Frame:SetAttribute("MapName", cardRecord.MapName)
	cardRecord.Frame:SetAttribute("Selected", isSelected)
	cardRecord.Frame:SetAttribute("Voting", isVoting)

	if cardRecord.Button then
		cardRecord.Button.Active = isVoting
		cardRecord.Button.Selectable = isVoting
		cardRecord.Button.AutoButtonColor = isVoting
	end

	if cardRecord.NameLabel then
		cardRecord.NameLabel.Text = cardRecord.MapName
	end

	if cardRecord.ImageLabel then
		local resolvedImage = resolveMapImage(component, cardRecord.MapName, cardRecord.BaseImage)
		if resolvedImage ~= "" then
			cardRecord.ImageLabel.Image = resolvedImage
		end
	end

	if cardRecord.Glow then
		cardRecord.Glow.Visible = isSelected
	end

	if cardRecord.CheckMark then
		cardRecord.CheckMark.Visible = isSelected
	end

	if cardRecord.VoteAvatarFrame then
		cardRecord.VoteAvatarFrame.Visible = isSelected
	end

	if isSelected and cardRecord.VoteAvatarImage and component.PlayerThumbnail ~= "" then
		cardRecord.VoteAvatarImage.Image = component.PlayerThumbnail
	end
end

local function refreshComponent(component: MapSelectionComponent)
	local isVoting = component.MatchState == MatchStates.Voting and #component.MapOptions > 0

	component.Frame:SetAttribute("OpenOverride", isVoting)
	component.Frame:SetAttribute("MatchState", component.MatchState)
	component.Frame:SetAttribute("SelectedMap", component.LocalVote)
	component.Frame:SetAttribute("MapCount", #component.MapOptions)

	for _, cardRecord in ipairs(component.CardRecords) do
		applyCardState(component, cardRecord)
	end
end

local function rebuildCards(component: MapSelectionComponent, matchService: any)
	if component._cardTrove then
		component._cardTrove:Clean()
	end

	component._cardTrove = Trove.new()
	local cardTrove = component._cardTrove :: Types.Trove
	destroyCardFrames(component.CardRecords)

	local templateCard = component.TemplateCard
	if not templateCard then
		refreshComponent(component)
		return
	end

	for index, mapName in ipairs(component.MapOptions) do
		local cardFrame = templateCard:Clone()
		cardFrame.Name = ("ContainerMapDynamic%d"):format(index)
		cardFrame.LayoutOrder = index
		cardFrame.Visible = true
		cardFrame.Parent = component.Frame

		local mapFrame = findGuiObject(cardFrame, "Map")
		local voteAvatarFrame = if mapFrame then findGuiObject(mapFrame, "Pfp") else nil
		local voteAvatarImage = if voteAvatarFrame then findImageLabel(voteAvatarFrame, "Pfp") else nil
		local imageLabel = if mapFrame then findImageLabel(mapFrame, "MapImage") else nil
		local cardRecord: MapCardRecord = {
			Frame = cardFrame,
			Button = findButton(cardFrame, "ButtonHitbox"),
			Glow = findGuiObject(cardFrame, "Glow"),
			CheckMark = if mapFrame then findGuiObject(mapFrame, "CheckMark") else nil,
			NameLabel = if mapFrame then findTextLabel(mapFrame, "MapName") else nil,
			ImageLabel = imageLabel,
			VoteAvatarFrame = voteAvatarFrame,
			VoteAvatarImage = voteAvatarImage,
			BaseImage = if imageLabel then imageLabel.Image else "",
			MapName = mapName,
		}

		if cardRecord.Button then
			cardTrove:Connect(cardRecord.Button.Activated, function()
				if component.MatchState ~= MatchStates.Voting then
					return
				end

				component.LocalVote = mapName
				refreshComponent(component)
				matchService.SubmitVote:Fire("map", mapName)
			end)
		end

		table.insert(component.CardRecords, cardRecord)
	end

	refreshComponent(component)
end

function MapSelection.Destroy(self: MapSelectionComponent)
	if self._cardTrove then
		self._cardTrove:Clean()
		self._cardTrove = nil
	end

	destroyCardFrames(self.CardRecords)
	self._trove:Clean()
end

function MapSelection.init(mapSelectionFrame: GuiObject): MapSelectionComponent
	local matchService = framework.GetService("MatchService")
	local trove = Trove.new()
	local templateCards = getTemplateCards(mapSelectionFrame)
	local templateCard = if templateCards[1] then templateCards[1]:Clone() else nil

	for _, template in ipairs(templateCards) do
		template:Destroy()
	end

	local component: MapSelectionComponent = {
		Frame = mapSelectionFrame,
		TemplateCard = templateCard,
		CardRecords = {},
		MapOptions = {},
		LocalVote = "",
		MatchState = MatchStates.Intermission,
		PlayerThumbnail = "",
		MapImageCache = {},
		_cardTrove = nil,
		_trove = trove,
		Destroy = MapSelection.Destroy,
	}

	mapSelectionFrame:SetAttribute("OpenOverride", false)

	local initialMatchState = matchService.CurrentState:OnReady(5)
	if type(initialMatchState) == "string" then
		component.MatchState = initialMatchState
	end

	local initialMapOptions = matchService.MapOptions:OnReady(5)
	if type(initialMapOptions) == "table" then
		component.MapOptions = table.clone(initialMapOptions)
	end

	if not component.TemplateCard then
		warn("[UIController] MapSelection placeholder template not found")
	else
		rebuildCards(component, matchService)
	end

	trove:Add(matchService.CurrentState:Observe(function(matchState: string)
		component.MatchState = matchState
		if matchState ~= MatchStates.Voting then
			component.LocalVote = ""
		end
		refreshComponent(component)
	end))

	trove:Add(matchService.MapOptions:Observe(function(mapOptions: { string })
		component.MapOptions = table.clone(mapOptions)
		if component.LocalVote ~= "" and not table.find(component.MapOptions, component.LocalVote) then
			component.LocalVote = ""
		end
		rebuildCards(component, matchService)
	end))

	trove:Add(matchService.VotingStarted:Connect(function(_payload: any)
		component.LocalVote = ""
		refreshComponent(component)
	end))

	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(
				localPlayer.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size150x150
			)
		end)

		if ok and mapSelectionFrame.Parent then
			component.PlayerThumbnail = image
			refreshComponent(component)
		end
	end)

	refreshComponent(component)

	return component
end

return MapSelection
