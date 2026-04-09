--!strict

local root = script.Parent.Parent.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local ObjectComponents = require(script.Parent.Parent.ObjectComponents)
local Trove = Dependencies.GetTrove()

type MatchResultEntry = {
	UserId: number,
	Name: string,
	DisplayName: string,
	Kills: number,
	Deaths: number,
	Assists: number,
	Damage: number,
}

type StatDefinition = {
	Label: string,
	Value: string,
}

type PlaceCard = {
	Frame: GuiObject?,
	DisplayNameLabel: TextLabel?,
	RankLabel: TextLabel?,
	StatFrames: { GuiObject },
}

type MatchEndComponent = {
	Frame: GuiObject,
	ExitButton: GuiButton?,
	PlaceCards: { PlaceCard },
	_trove: Types.Trove,
	Destroy: (self: MatchEndComponent) -> (),
}

local MatchEnd = {}

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

local function getStatSortIndex(statFrame: GuiObject): number
	if statFrame.Name == "Stat" then
		return 1
	end

	local explicitLayoutOrder = statFrame.LayoutOrder
	if explicitLayoutOrder ~= 0 then
		return explicitLayoutOrder
	end

	local numericSuffix = string.match(statFrame.Name, "%((%d+)%)")
	if numericSuffix then
		return tonumber(numericSuffix) or math.huge
	end

	return math.huge
end

local function buildPlaceCard(placeFrame: GuiObject?): PlaceCard
	local statFrames = {} :: { GuiObject }
	local statsHolder = findGuiObject(placeFrame, "StatsHolder")

	if statsHolder then
		for _, child in ipairs(statsHolder:GetChildren()) do
			if child:IsA("GuiObject") and string.match(child.Name, "^Stat") then
				table.insert(statFrames, child)
			end
		end

		table.sort(statFrames, function(a: GuiObject, b: GuiObject): boolean
			return getStatSortIndex(a) < getStatSortIndex(b)
		end)
	end

	return {
		Frame = placeFrame,
		DisplayNameLabel = findTextLabel(placeFrame, "DisplayName"),
		RankLabel = findTextLabel(placeFrame, "Rank"),
		StatFrames = statFrames,
	}
end

local function setMatchEndOpen(frame: GuiObject, isOpen: boolean)
	frame:SetAttribute("OpenOverride", isOpen)
end

local function getEntryStatDefinitions(entry: MatchResultEntry): { StatDefinition }
	return {
		{ Label = "Eliminations", Value = tostring(entry.Kills) },
		{ Label = "Damage", Value = tostring(entry.Damage) },
		{ Label = "Deaths", Value = tostring(entry.Deaths) },
	}
end

local function renderPlaceCard(placeCard: PlaceCard, entry: MatchResultEntry?, rank: number)
	local frame = placeCard.Frame
	if not frame then
		return
	end

	if not entry then
		frame.Visible = false
		return
	end

	frame.Visible = true

	if placeCard.DisplayNameLabel then
		local displayName = if entry.DisplayName ~= "" then entry.DisplayName else entry.Name
		placeCard.DisplayNameLabel.Text = displayName
	end

	if placeCard.RankLabel then
		placeCard.RankLabel.Text = ("#%d"):format(rank)
	end

	local statDefinitions = getEntryStatDefinitions(entry)
	for index, statFrame in ipairs(placeCard.StatFrames) do
		local statDefinition = statDefinitions[index]
		statFrame.Visible = statDefinition ~= nil

		if statDefinition then
			local amountLabel = findTextLabel(statFrame, "Amount")
			local statNameLabel = findTextLabel(statFrame, "StatName")

			if amountLabel then
				amountLabel.Text = statDefinition.Value
			end

			if statNameLabel then
				statNameLabel.Text = statDefinition.Label
			end
		end
	end
end

local function extractTopPlayers(payload: any): { MatchResultEntry }
	local entries = {} :: { MatchResultEntry }
	if type(payload) ~= "table" or type(payload.topPlayers) ~= "table" then
		return entries
	end

	for index = 1, 3 do
		local rawEntry = payload.topPlayers[index]
		if type(rawEntry) == "table" then
			table.insert(entries, {
				UserId = tonumber(rawEntry.UserId) or 0,
				Name = tostring(rawEntry.Name or ""),
				DisplayName = tostring(rawEntry.DisplayName or rawEntry.Name or ""),
				Kills = tonumber(rawEntry.Kills) or 0,
				Deaths = tonumber(rawEntry.Deaths) or 0,
				Assists = tonumber(rawEntry.Assists) or 0,
				Damage = tonumber(rawEntry.Damage) or 0,
			})
		end
	end

	return entries
end

function MatchEnd.Destroy(self: MatchEndComponent)
	self._trove:Clean()
end

function MatchEnd.init(matchEndFrame: GuiObject): MatchEndComponent
	local matchService = framework.GetService("MatchService")
	local trove = Trove.new()

	local rankList = matchEndFrame:FindFirstChild("RankList")

	local component: MatchEndComponent = {
		Frame = matchEndFrame,
		ExitButton = findButton(matchEndFrame:FindFirstChild("ExitButton"), "ButtonHitbox"),
		PlaceCards = {
			buildPlaceCard(if rankList and rankList:IsA("GuiObject") then findGuiObject(rankList, "FirstPlace") else nil),
			buildPlaceCard(if rankList and rankList:IsA("GuiObject") then findGuiObject(rankList, "SecondPlace") else nil),
			buildPlaceCard(if rankList and rankList:IsA("GuiObject") then findGuiObject(rankList, "ThirdPlace") else nil),
		},
		_trove = trove,
		Destroy = MatchEnd.Destroy,
	}

	setMatchEndOpen(matchEndFrame, false)

	for _, placeCard in ipairs(component.PlaceCards) do
		if placeCard.Frame then
			placeCard.Frame.Visible = false
		end
	end

	if component.ExitButton then
		trove:Add(ObjectComponents.ButtonHoverTween.apply(
			component.ExitButton,
			component.ExitButton.Size + UDim2.fromScale(0.06, 0.06),
			component.ExitButton.Size,
			0.12
		))

		trove:Connect(component.ExitButton.Activated, function()
			setMatchEndOpen(matchEndFrame, false)
		end)
	end

	trove:Add(matchService.CurrentState:Observe(function(matchState: string)
		if matchState ~= "PostMatch" then
			setMatchEndOpen(matchEndFrame, false)
		end
	end))

	trove:Add(matchService.MatchEnded:Connect(function(payload: any)
		local topPlayers = extractTopPlayers(payload)

		for index, placeCard in ipairs(component.PlaceCards) do
			renderPlaceCard(placeCard, topPlayers[index], index)
		end

		setMatchEndOpen(matchEndFrame, #topPlayers > 0)
	end))

	return component
end

return MatchEnd
