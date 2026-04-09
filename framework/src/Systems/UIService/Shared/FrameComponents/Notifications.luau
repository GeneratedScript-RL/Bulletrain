--!strict

local TweenService = game:GetService("TweenService")

local root = script.Parent.Parent.Parent.Parent.Parent
local Dependencies = require(root.Dependencies)
local Types = require(root.Types)
local framework: Types.frameworkClient = require(root) :: any

local Trove = Dependencies.GetTrove()

local DISPLAY_DURATION = 3
local SLIDE_OFFSET = UDim2.fromOffset(36, 0)
local ENTER_TWEEN_INFO = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local EXIT_TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

type NotificationKind = "Daily" | "LevelUp"

type NotificationPayload = {
	Kind: NotificationKind,
	Title: string,
	Subtitle: string,
	Level: number?,
}

type NotificationsComponent = {
	Frame: GuiObject,
	DailyTemplate: GuiObject?,
	LevelTemplate: GuiObject?,
	Queue: { NotificationPayload },
	ActiveToast: GuiObject?,
	IsPlaying: boolean,
	_destroyed: boolean,
	_trove: Types.Trove,
	Destroy: (self: NotificationsComponent) -> (),
}

local Notifications = {}

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

local function applyPayload(toast: GuiObject, payload: NotificationPayload)
	local primaryLabel = findTextLabel(toast, "LevelUp")
	local secondaryLabel = findTextLabel(toast, "LevelUp (2)")

	toast:SetAttribute("NotificationKind", payload.Kind)
	toast:SetAttribute("NotificationTitle", payload.Title)
	toast:SetAttribute("NotificationSubtitle", payload.Subtitle)

	if payload.Kind == "LevelUp" then
		toast:SetAttribute("Level", payload.Level or 0)
		if primaryLabel then
			primaryLabel.Text = tostring(payload.Level or payload.Title)
		end

		if secondaryLabel then
			secondaryLabel.Text = payload.Subtitle
		end
	else
		if primaryLabel then
			primaryLabel.Text = payload.Title
		end

		if secondaryLabel then
			secondaryLabel.Text = payload.Subtitle
		end
	end
end

local function getToastTemplate(component: NotificationsComponent, kind: NotificationKind): GuiObject?
	if kind == "Daily" then
		return component.DailyTemplate or component.LevelTemplate
	end

	return component.LevelTemplate or component.DailyTemplate
end

local function clearActiveToast(component: NotificationsComponent)
	local activeToast = component.ActiveToast
	if activeToast then
		activeToast:Destroy()
		component.ActiveToast = nil
	end
end

local function playQueue(component: NotificationsComponent)
	if component.IsPlaying or component._destroyed then
		return
	end

	component.IsPlaying = true

	task.spawn(function()
		while not component._destroyed and #component.Queue > 0 do
			local payload = table.remove(component.Queue, 1)
			if not payload then
				break
			end

			component.Frame:SetAttribute("QueuedNotifications", #component.Queue)

			local template = getToastTemplate(component, payload.Kind)
			if not template then
				continue
			end

			clearActiveToast(component)

			local toast = template:Clone()
			toast.Name = ("Notification%s"):format(payload.Kind)
			toast.Visible = true
			toast.Parent = component.Frame
			applyPayload(toast, payload)

			component.ActiveToast = toast
			component.Frame:SetAttribute("OpenOverride", true)
			component.Frame:SetAttribute("NotificationKind", payload.Kind)

			local basePosition = toast.Position
			toast.Position = basePosition + SLIDE_OFFSET

			local enterTween = TweenService:Create(toast, ENTER_TWEEN_INFO, {
				Position = basePosition,
			})
			enterTween:Play()
			enterTween.Completed:Wait()

			if component._destroyed or component.ActiveToast ~= toast then
				break
			end

			task.wait(DISPLAY_DURATION)

			if component._destroyed or component.ActiveToast ~= toast then
				break
			end

			local exitTween = TweenService:Create(toast, EXIT_TWEEN_INFO, {
				Position = basePosition + SLIDE_OFFSET,
			})
			exitTween:Play()
			exitTween.Completed:Wait()

			if component.ActiveToast == toast then
				clearActiveToast(component)
			end
		end

		if not component._destroyed then
			component.Frame:SetAttribute("OpenOverride", false)
			component.Frame:SetAttribute("QueuedNotifications", #component.Queue)
		end

		component.IsPlaying = false
	end)
end

local function enqueue(component: NotificationsComponent, payload: NotificationPayload)
	table.insert(component.Queue, payload)
	component.Frame:SetAttribute("QueuedNotifications", #component.Queue)
	playQueue(component)
end

function Notifications.Destroy(self: NotificationsComponent)
	self._destroyed = true
	self.Frame:SetAttribute("OpenOverride", false)
	clearActiveToast(self)
	self._trove:Clean()
end

function Notifications.init(notificationsFrame: GuiObject): NotificationsComponent
	local dataService = framework.GetService("DataService")
	local dailyTaskService = framework.GetService("DailyTaskService")
	local trove = Trove.new()
	local dailyTemplateSource = notificationsFrame:FindFirstChild("Daily")
	local levelTemplateSource = notificationsFrame:FindFirstChild("LvlUP")
	local dailyTemplate = if dailyTemplateSource and dailyTemplateSource:IsA("GuiObject")
		then dailyTemplateSource:Clone()
		else nil
	local levelTemplate = if levelTemplateSource and levelTemplateSource:IsA("GuiObject")
		then levelTemplateSource:Clone()
		else nil

	if dailyTemplateSource then
		dailyTemplateSource:Destroy()
	end

	if levelTemplateSource then
		levelTemplateSource:Destroy()
	end

	local component: NotificationsComponent = {
		Frame = notificationsFrame,
		DailyTemplate = dailyTemplate,
		LevelTemplate = levelTemplate,
		Queue = {},
		ActiveToast = nil,
		IsPlaying = false,
		_destroyed = false,
		_trove = trove,
		Destroy = Notifications.Destroy,
	}

	notificationsFrame:SetAttribute("OpenOverride", false)
	notificationsFrame:SetAttribute("QueuedNotifications", 0)

	if not dailyTemplate and not levelTemplate then
		warn("[UIController] Notifications placeholder templates not found")
		return component
	end

	trove:Add(dataService.LevelUp:Connect(function(payload: any)
		if type(payload) ~= "table" then
			return
		end

		local level = payload.level
		if type(level) ~= "number" then
			return
		end

		enqueue(component, {
			Kind = "LevelUp",
			Title = tostring(level),
			Subtitle = "LEVEL UP",
			Level = math.floor(level),
		})
	end))

	trove:Add(dailyTaskService.TaskCompleted:Connect(function(payload: any)
		if type(payload) ~= "table" then
			return
		end

		local title = payload.title
		local rewardCredits = payload.rewardCredits
		if type(title) ~= "string" or type(rewardCredits) ~= "number" then
			return
		end

		enqueue(component, {
			Kind = "Daily",
			Title = ("[DAILY] %s"):format(title),
			Subtitle = ("You earned %d Coins"):format(math.floor(rewardCredits + 0.5)),
		})
	end))

	return component
end

return Notifications
