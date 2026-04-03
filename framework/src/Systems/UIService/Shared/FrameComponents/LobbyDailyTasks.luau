--!strict

local root = script.Parent.Parent.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local DailyTaskTypes = require(root.Shared.DailyTasks.Types)
local Trove = Dependencies.GetTrove()

type DailyTaskSnapshot = DailyTaskTypes.DailyTaskSnapshot
type DailyTaskSnapshotEntry = DailyTaskTypes.DailyTaskSnapshotEntry

type DailyTasksComponent = {
	Frame: GuiObject,
	ListHolder: GuiObject,
	TimerLabel: TextLabel?,
	HideButton: GuiButton?,
	HideLabel: TextLabel?,
	TaskRows: { GuiObject },
	TemplateRow: GuiObject?,
	Snapshot: DailyTaskSnapshot?,
	Collapsed: boolean,
	_trove: Types.Trove,
	Destroy: (self: DailyTasksComponent) -> (),
}

local DailyTasks = {}

local function formatCountdown(secondsRemaining: number): string
	local clampedSeconds = math.max(0, math.floor(secondsRemaining))
	local hours = math.floor(clampedSeconds / 3600)
	local minutes = math.floor((clampedSeconds % 3600) / 60)
	local seconds = clampedSeconds % 60

	return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

local function getTaskRows(listHolder: GuiObject): { GuiObject }
	local rows = {} :: { GuiObject }
	for _, child in ipairs(listHolder:GetChildren()) do
		if child:IsA("GuiObject") and child.Name:match("^Task") then
			table.insert(rows, child)
		end
	end

	table.sort(rows, function(left: GuiObject, right: GuiObject): boolean
		if left.LayoutOrder == right.LayoutOrder then
			return left.Name < right.Name
		end

		return left.LayoutOrder < right.LayoutOrder
	end)

	return rows
end

local function findHideButton(panelFrame: GuiObject): GuiButton?
	local hideButtonFrame = panelFrame:FindFirstChild("HideButton")
	if not hideButtonFrame then
		return nil
	end

	local buttonHitbox = hideButtonFrame:FindFirstChild("ButtonHitbox")
	if buttonHitbox and buttonHitbox:IsA("GuiButton") then
		return buttonHitbox
	end

	local imageButton = hideButtonFrame:FindFirstChildWhichIsA("ImageButton", true)
	if imageButton then
		return imageButton
	end

	return hideButtonFrame:FindFirstChildWhichIsA("TextButton", true)
end

local function setRowVisible(row: GuiObject, isVisible: boolean)
	row.Visible = isVisible
	row:SetAttribute("IsTemplate", not isVisible)
end

local function setCollapsed(component: DailyTasksComponent, collapsed: boolean)
	component.Collapsed = collapsed
	component.ListHolder.Visible = not collapsed
	component.Frame:SetAttribute("Collapsed", collapsed)

	local hideLabel = component.HideLabel
	if hideLabel then
		hideLabel.Text = if collapsed then "<" else ">"
	end
end

local function ensureRowCount(component: DailyTasksComponent, requiredCount: number): { GuiObject }
	local rows = component.TaskRows
	local templateRow = component.TemplateRow

	if not templateRow then
		return rows
	end

	while #rows < requiredCount do
		local clonedRow = templateRow:Clone()
		clonedRow.Name = ("TaskDynamic%d"):format(#rows + 1)
		clonedRow.Parent = component.ListHolder
		table.insert(rows, clonedRow)
	end

	return rows
end

local function applyTaskRow(row: GuiObject, taskSnapshot: DailyTaskSnapshotEntry, layoutOrder: number)
	local progressRatio = if taskSnapshot.Target > 0
		then math.clamp(taskSnapshot.Progress / taskSnapshot.Target, 0, 1)
		else 0

	row.Visible = true
	row.LayoutOrder = layoutOrder
	row:SetAttribute("IsTemplate", false)
	row:SetAttribute("TaskId", taskSnapshot.Id)
	row:SetAttribute("Completed", taskSnapshot.IsComplete)
	row:SetAttribute("RewardClaimed", taskSnapshot.RewardClaimed)
	row:SetAttribute("ProgressRatio", progressRatio)
	row:SetAttribute("RewardCredits", taskSnapshot.RewardCredits)

	local titleLabel = row:FindFirstChild("Quest")
	if titleLabel and titleLabel:IsA("TextLabel") then
		titleLabel.Text = taskSnapshot.Title
	end

	local rewardLabel = row:FindFirstChild("Amount")
	if rewardLabel and rewardLabel:IsA("TextLabel") then
		rewardLabel.Text = ("%d Coins"):format(taskSnapshot.RewardCredits)
	end

	local progressLabel = row:FindFirstChild("Progress")
	if progressLabel and progressLabel:IsA("TextLabel") then
		progressLabel.Text = ("%d/%d"):format(taskSnapshot.Progress, taskSnapshot.Target)
	end

	local progressBar = row:FindFirstChild("Bar")
	if progressBar and progressBar:IsA("GuiObject") then
		local fillFrame = progressBar:FindFirstChild("Frame")
		if fillFrame and fillFrame:IsA("GuiObject") then
			fillFrame.Size = UDim2.new(progressRatio, 0, fillFrame.Size.Y.Scale, fillFrame.Size.Y.Offset)
		end
	end
end

local function refreshTimer(component: DailyTasksComponent)
	local timerLabel = component.TimerLabel
	local snapshot = component.Snapshot
	if not timerLabel then
		return
	end

	if not snapshot or snapshot.ResetAtUnix <= 0 then
		timerLabel.Text = "--:--:--"
		component.Frame:SetAttribute("SecondsToReset", 0)
		return
	end

	local secondsRemaining = snapshot.ResetAtUnix - DateTime.now().UnixTimestamp
	timerLabel.Text = formatCountdown(secondsRemaining)
	component.Frame:SetAttribute("SecondsToReset", math.max(0, secondsRemaining))
end

local function renderSnapshot(component: DailyTasksComponent)
	local snapshot = component.Snapshot
	local rows = component.TaskRows

	if not snapshot then
		for _, row in ipairs(rows) do
			setRowVisible(row, false)
		end
		refreshTimer(component)
		return
	end

	rows = ensureRowCount(component, #snapshot.Tasks)
	for index, taskSnapshot in ipairs(snapshot.Tasks) do
		applyTaskRow(rows[index], taskSnapshot, index)
	end

	for index = #snapshot.Tasks + 1, #rows do
		setRowVisible(rows[index], false)
	end

	component.Frame:SetAttribute("TaskCount", #snapshot.Tasks)
	component.Frame:SetAttribute("DayKey", snapshot.DayKey)
	component.Frame:SetAttribute("ResetAtUnix", snapshot.ResetAtUnix)
	refreshTimer(component)
end

function DailyTasks.Destroy(self: DailyTasksComponent)
	self._trove:Clean()
end

function DailyTasks.bind(panelFrame: GuiObject): DailyTasksComponent?
	local listHolder = panelFrame:FindFirstChild("ListHolder")
	if not listHolder or not listHolder:IsA("GuiObject") then
		warn("[UIController] DailyTasks.ListHolder not found")
		return nil
	end

	local timerLabel = panelFrame:FindFirstChild("DailyTasks (2)")
	local hideButtonFrame = panelFrame:FindFirstChild("HideButton")
	local hideLabel = if hideButtonFrame then hideButtonFrame:FindFirstChild("Hide") else nil
	local dailyTaskService = framework.GetService("DailyTaskService")
	local trove = Trove.new()
	local existingRows = getTaskRows(listHolder)

	local component: DailyTasksComponent = {
		Frame = panelFrame,
		ListHolder = listHolder,
		TimerLabel = if timerLabel and timerLabel:IsA("TextLabel") then timerLabel else nil,
		HideButton = findHideButton(panelFrame),
		HideLabel = if hideLabel and hideLabel:IsA("TextLabel") then hideLabel else nil,
		TaskRows = existingRows,
		TemplateRow = existingRows[1],
		Snapshot = nil,
		Collapsed = false,
		_trove = trove,
		Destroy = DailyTasks.Destroy,
	}

	if not component.TemplateRow then
		warn("[UIController] DailyTasks task template not found inside DailyTasks.ListHolder")
	end

	for _, row in ipairs(existingRows) do
		setRowVisible(row, false)
	end

	if component.HideButton then
		trove:Connect(component.HideButton.Activated, function()
			setCollapsed(component, not component.Collapsed)
		end)
	end

	local timerThreadActive = true
	trove:Add(function()
		timerThreadActive = false
	end)

	task.spawn(function()
		while timerThreadActive do
			refreshTimer(component)
			task.wait(1)
		end
	end)

	trove:Add(dailyTaskService.Snapshot:Observe(function(snapshot: DailyTaskSnapshot)
		component.Snapshot = snapshot
		renderSnapshot(component)
	end))

	setCollapsed(component, false)
	renderSnapshot(component)

	return component
end

return DailyTasks
