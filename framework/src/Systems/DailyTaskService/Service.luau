--!strict

local Players = game:GetService("Players")

local root = script.Parent.Parent.Parent
local Types = require(root.Types)
local framework: Types.frameworkServer = require(root) :: any

local DailyTaskRegistry = require(root.Shared.DailyTasks.Tasks)
local DailyTaskTypes = require(root.Shared.DailyTasks.Types)

type DailyTaskContext = DailyTaskTypes.DailyTaskContext
type DailyTaskDefinition = DailyTaskTypes.DailyTaskDefinition
type DailyTaskProfile = DailyTaskTypes.DailyTaskProfile
type DailyTaskSnapshot = DailyTaskTypes.DailyTaskSnapshot
type DailyTaskSnapshotEntry = DailyTaskTypes.DailyTaskSnapshotEntry

local ACTIVE_TASK_COUNT = 3
local EMPTY_SNAPSHOT: DailyTaskSnapshot = {
	DayKey = "",
	ResetAtUnix = 0,
	Tasks = {} :: { DailyTaskSnapshotEntry },
}

local dataService: any

local DailyTaskService = framework.CreateService({
	Name = "DailyTaskService",
	Dependencies = { "DataService" },
	Client = {
		Snapshot = framework.CreateProperty(EMPTY_SNAPSHOT),
	},
})

DailyTaskService._taskDefinitions = {} :: { [string]: DailyTaskDefinition }
DailyTaskService._taskOrder = {} :: { string }
DailyTaskService._dailyTaskCache = {} :: { [string]: { string } }

local function getCurrentUnixTimestamp(): number
	return DateTime.now().UnixTimestamp
end

local function getDayKeyFromUnixTimestamp(unixTimestamp: number): string
	return os.date("!%Y-%m-%d", unixTimestamp)
end

local function getCurrentDayKey(): string
	return getDayKeyFromUnixTimestamp(getCurrentUnixTimestamp())
end

local function getNextResetUnixTimestamp(unixTimestamp: number): number
	return (math.floor(unixTimestamp / 86400) + 1) * 86400
end

local function hashString(value: string): number
	local hash = 2166136261
	for i = 1, #value do
		hash = bit32.bxor(hash, string.byte(value, i))
		hash = (hash * 16777619) % 4294967296
	end

	return hash
end

function DailyTaskService:_registerTasks()
	for _, taskDefinition in ipairs(DailyTaskRegistry) do
		assert(taskDefinition.Id ~= "", "[DailyTaskService] Task definition is missing an Id")
		assert(
			not self._taskDefinitions[taskDefinition.Id],
			("[DailyTaskService] Duplicate daily task id '%s'"):format(taskDefinition.Id)
		)

		self._taskDefinitions[taskDefinition.Id] = taskDefinition
		table.insert(self._taskOrder, taskDefinition.Id)
	end
end

function DailyTaskService:_getSelectedTaskIdsForDay(dayKey: string): { string }
	local cachedTaskIds = self._dailyTaskCache[dayKey]
	if cachedTaskIds then
		return cachedTaskIds
	end

	local taskIds = table.clone(self._taskOrder)
	local random = Random.new(hashString(dayKey))

	for index = #taskIds, 2, -1 do
		local swapIndex = random:NextInteger(1, index)
		taskIds[index], taskIds[swapIndex] = taskIds[swapIndex], taskIds[index]
	end

	local selectedTaskIds = {} :: { string }
	local selectedCount = math.min(ACTIVE_TASK_COUNT, #taskIds)
	for index = 1, selectedCount do
		table.insert(selectedTaskIds, taskIds[index])
	end

	self._dailyTaskCache[dayKey] = selectedTaskIds
	return selectedTaskIds
end

function DailyTaskService:_resetDailyState(dailyTaskProfile: DailyTaskProfile, dayKey: string)
	dailyTaskProfile.DayKey = dayKey
	table.clear(dailyTaskProfile.Tasks)

	for _, taskId in ipairs(self:_getSelectedTaskIdsForDay(dayKey)) do
		dailyTaskProfile.Tasks[taskId] = {
			Progress = 0,
			RewardClaimed = false,
		}
	end
end

function DailyTaskService:_reconcileDailyState(dailyTaskProfile: DailyTaskProfile, dayKey: string): boolean
	if dailyTaskProfile.DayKey ~= dayKey then
		self:_resetDailyState(dailyTaskProfile, dayKey)
		return true
	end

	local changed = false
	local activeTaskIds = self:_getSelectedTaskIdsForDay(dayKey)
	local activeTaskLookup = {} :: { [string]: boolean }

	for _, taskId in ipairs(activeTaskIds) do
		activeTaskLookup[taskId] = true

		local taskDefinition = self._taskDefinitions[taskId]
		local taskEntry = dailyTaskProfile.Tasks[taskId]
		if not taskDefinition then
			continue
		end

		if not taskEntry then
			dailyTaskProfile.Tasks[taskId] = {
				Progress = 0,
				RewardClaimed = false,
			}
			changed = true
		else
			local clampedProgress = math.clamp(taskEntry.Progress, 0, taskDefinition.Target)
			if clampedProgress ~= taskEntry.Progress then
				taskEntry.Progress = clampedProgress
				changed = true
			end
		end
	end

	for taskId in dailyTaskProfile.Tasks do
		if not activeTaskLookup[taskId] then
			dailyTaskProfile.Tasks[taskId] = nil
			changed = true
		end
	end

	return changed
end

function DailyTaskService:_finalizeCompletedTasks(player: Player, dailyTaskProfile: DailyTaskProfile): boolean
	local changed = false

	for taskId, taskEntry in dailyTaskProfile.Tasks do
		local taskDefinition = self._taskDefinitions[taskId]
		if not taskDefinition then
			continue
		end

		local clampedProgress = math.clamp(taskEntry.Progress, 0, taskDefinition.Target)
		if clampedProgress ~= taskEntry.Progress then
			taskEntry.Progress = clampedProgress
			changed = true
		end

		if taskEntry.Progress >= taskDefinition.Target and not taskEntry.RewardClaimed then
			taskEntry.RewardClaimed = true
			dataService:AddCredits(player, taskDefinition.RewardCredits)
			changed = true
		end
	end

	return changed
end

function DailyTaskService:_getDailyTaskProfile(player: Player): (DailyTaskProfile, boolean)
	local profile = dataService:GetProfile(player)
	local dailyTaskProfile = profile.DailyTasks
	local changed = self:_reconcileDailyState(dailyTaskProfile, getCurrentDayKey())

	if self:_finalizeCompletedTasks(player, dailyTaskProfile) then
		changed = true
	end

	if changed then
		dataService:MarkDirty(player)
	end

	return dailyTaskProfile, changed
end

function DailyTaskService:_createTaskContext(player: Player): DailyTaskContext
	return {
		Player = player,
		Services = {
			DataService = dataService,
			DailyTaskService = self,
		},
	}
end

function DailyTaskService:_buildSnapshot(dailyTaskProfile: DailyTaskProfile): DailyTaskSnapshot
	local snapshotTasks = {} :: { DailyTaskSnapshotEntry }
	local selectedTaskIds = self:_getSelectedTaskIdsForDay(dailyTaskProfile.DayKey)

	for _, taskId in ipairs(selectedTaskIds) do
		local taskDefinition = self._taskDefinitions[taskId]
		local taskEntry = dailyTaskProfile.Tasks[taskId]

		if taskDefinition and taskEntry then
			local progress = math.clamp(taskEntry.Progress, 0, taskDefinition.Target)
			table.insert(snapshotTasks, {
				Id = taskDefinition.Id,
				Title = taskDefinition.Title,
				RewardCredits = taskDefinition.RewardCredits,
				Progress = progress,
				Target = taskDefinition.Target,
				IsComplete = progress >= taskDefinition.Target,
				RewardClaimed = taskEntry.RewardClaimed,
			})
		end
	end

	return {
		DayKey = dailyTaskProfile.DayKey,
		ResetAtUnix = getNextResetUnixTimestamp(getCurrentUnixTimestamp()),
		Tasks = snapshotTasks,
	}
end

function DailyTaskService:_syncPlayer(player: Player, dailyTaskProfile: DailyTaskProfile?)
	if player.Parent ~= Players then
		return
	end

	local resolvedProfile = dailyTaskProfile
	if not resolvedProfile then
		local fetchedProfile, _ = self:_getDailyTaskProfile(player)
		resolvedProfile = fetchedProfile
	end

	self.Client.Snapshot:SetFor(player, self:_buildSnapshot(resolvedProfile :: DailyTaskProfile))
end

function DailyTaskService:RecordEvent(player: Player, eventName: string, payload: any?)
	if player.Parent ~= Players then
		return
	end

	local dailyTaskProfile, changed = self:_getDailyTaskProfile(player)
	local taskContext = self:_createTaskContext(player)

	for _, taskId in ipairs(self:_getSelectedTaskIdsForDay(dailyTaskProfile.DayKey)) do
		local taskDefinition = self._taskDefinitions[taskId]
		local taskEntry = dailyTaskProfile.Tasks[taskId]

		if taskDefinition and taskEntry and not taskEntry.RewardClaimed then
			local nextProgress = taskDefinition.ProcessEvent(taskContext, eventName, payload, taskEntry)
			if type(nextProgress) == "number" then
				local clampedProgress = math.clamp(nextProgress, 0, taskDefinition.Target)
				if clampedProgress ~= taskEntry.Progress then
					taskEntry.Progress = clampedProgress
					changed = true
				end
			end
		end
	end

	if self:_finalizeCompletedTasks(player, dailyTaskProfile) then
		changed = true
	end

	if changed then
		dataService:MarkDirty(player)
		self:_syncPlayer(player, dailyTaskProfile)
	end
end

function DailyTaskService:Init()
	dataService = framework.GetService("DataService")
	self:_registerTasks()

	framework.OnPlayerAdded(function(player: Player)
		self:_syncPlayer(player)
	end)
end

function DailyTaskService:Start()
	task.spawn(function()
		while true do
			local now = getCurrentUnixTimestamp()
			local waitTime = math.max(getNextResetUnixTimestamp(now) - now + 1, 1)
			task.wait(waitTime)

			for _, player in Players:GetPlayers() do
				self:_syncPlayer(player)
			end
		end
	end)
end

return DailyTaskService
