--!strict

local Players = game:GetService("Players")

local root = script.Parent.Parent.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local ObjectComponents = require(script.Parent.Parent.ObjectComponents)
local ProfileSnapshot = require(script.Parent.Parent.ProfileSnapshot)
local Trove = Dependencies.GetTrove()

type StatRow = {
	Label: string,
	Value: string,
}

type StatsComponent = {
	Frame: GuiObject,
	ExitButton: GuiButton?,
	ListFrame: GuiObject?,
	Template: GuiObject?,
	_trove: Types.Trove,
	_itemTrove: Types.Trove?,
	Destroy: (self: StatsComponent) -> (),
}

local Stats = {}

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

local function clearRenderedStats(component: StatsComponent)
	local itemTrove = component._itemTrove
	if itemTrove then
		itemTrove:Clean()
		component._itemTrove = nil
	end
end

local function prepareTemplate(listFrame: GuiObject): GuiObject?
	local template: GuiObject? = nil

	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("GuiObject") and child.Name:match("^Stat") then
			if template == nil then
				template = child
				template.Name = "StatTemplate"
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

local function buildStatRows(snapshot: ProfileSnapshot.ProfileSnapshot): { StatRow }
	return {
		{ Label = "Coins", Value = ProfileSnapshot.FormatInteger(snapshot.Credits) },
		{ Label = "Level", Value = tostring(snapshot.Level) },
		{
			Label = "XP",
			Value = ("%s / %s"):format(
				ProfileSnapshot.FormatInteger(snapshot.XP),
				ProfileSnapshot.FormatInteger(snapshot.RequiredXP)
			),
		},
		{ Label = "Eliminations", Value = ProfileSnapshot.FormatInteger(snapshot.CareerKills) },
		{ Label = "Deaths", Value = ProfileSnapshot.FormatInteger(snapshot.CareerDeaths) },
		{ Label = "Assists", Value = ProfileSnapshot.FormatInteger(snapshot.CareerAssists) },
	}
end

local function renderStats(component: StatsComponent, statRows: { StatRow })
	local listFrame = component.ListFrame
	local template = component.Template
	if not listFrame or not template then
		return
	end

	clearRenderedStats(component)

	local itemTrove = Trove.new()
	component._itemTrove = itemTrove

	for index, statRow in ipairs(statRows) do
		local row = template:Clone()
		row.Name = ("Stat_%d"):format(index)
		row.LayoutOrder = index
		row.Visible = true
		row.Parent = listFrame
		itemTrove:Add(row)

		local amountLabel = findTextLabel(row, "Amount")
		local statNameLabel = findTextLabel(row, "StatName")

		if amountLabel then
			amountLabel.Text = statRow.Value
		end

		if statNameLabel then
			statNameLabel.Text = statRow.Label
		end
	end
end

local function applyPlayerHeader(statsFrame: GuiObject)
	local displayName = findTextLabel(statsFrame, "DisplayName")
	local userName = findTextLabel(statsFrame, "UserName")
	local avatar = statsFrame:FindFirstChildWhichIsA("ImageLabel", true)

	if displayName then
		displayName.Text = localPlayer.DisplayName
	end

	if userName then
		userName.Text = ("@%s"):format(localPlayer.Name)
	end

	if avatar then
		task.spawn(function()
			local ok, image = pcall(function()
				return Players:GetUserThumbnailAsync(
					localPlayer.UserId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size150x150
				)
			end)

			if ok and avatar.Parent and image ~= "" then
				avatar.Image = image
			end
		end)
	end
end

function Stats.Destroy(self: StatsComponent)
	clearRenderedStats(self)
	self._trove:Clean()
end

function Stats.init(statsFrame: GuiObject): StatsComponent
	local statsController = framework.GetController("StatsController")
	local trove = Trove.new()

	local component: StatsComponent = {
		Frame = statsFrame,
		ExitButton = nil,
		ListFrame = nil,
		Template = nil,
		_trove = trove,
		_itemTrove = nil,
		Destroy = Stats.Destroy,
	}

	statsFrame:SetAttribute("OpenOverride", false)
	statsController:RegisterFrame(statsFrame)

	local exitFrame = statsFrame:FindFirstChild("ExitButton")
	local listFrame = statsFrame:FindFirstChild("Frame")

	component.ExitButton = findButton(exitFrame, "ButtonHitbox")
	component.ListFrame = if listFrame and listFrame:IsA("GuiObject") then listFrame else nil

	if component.ListFrame then
		component.Template = prepareTemplate(component.ListFrame)
		if component.Template then
			trove:Add(component.Template)
		end
	else
		warn("[UIController] Stats.Frame not found")
	end

	if component.ExitButton then
		trove:Add(ObjectComponents.ButtonHoverTween.apply(
			component.ExitButton,
			component.ExitButton.Size + UDim2.fromScale(0.06, 0.06),
			component.ExitButton.Size,
			0.12
		))

		trove:Connect(component.ExitButton.Activated, function()
			statsController:Close()
		end)
	end

	applyPlayerHeader(statsFrame)

	ProfileSnapshot.Observe(localPlayer, trove, function(snapshot: ProfileSnapshot.ProfileSnapshot)
		renderStats(component, buildStatRows(snapshot))
	end)

	return component
end

return Stats
