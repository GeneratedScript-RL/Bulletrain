--!strict

local DailyTaskTypes = require(script.Parent.Parent.Types)

type DailyTaskDefinition = DailyTaskTypes.DailyTaskDefinition

local function processEvent(_context, eventName, _payload, state)
	if eventName ~= "Assist" then
		return nil
	end

	return state.Progress + 1
end

local Task: DailyTaskDefinition = {
	Id = "daily_assists",
	Title = "Help secure 3 assists",
	Target = 3,
	RewardCredits = 100,
	ProcessEvent = processEvent,
}

return Task
