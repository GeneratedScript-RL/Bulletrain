--!strict

local DailyTaskTypes = require(script.Parent.Parent.Types)

type DailyTaskDefinition = DailyTaskTypes.DailyTaskDefinition

local function processEvent(_context, eventName, _payload, state)
	if eventName ~= "Kill" then
		return nil
	end

	return state.Progress + 1
end

local Task: DailyTaskDefinition = {
	Id = "daily_eliminations",
	Title = "Land 5 eliminations",
	Target = 5,
	RewardCredits = 150,
	ProcessEvent = processEvent,
}

return Task
