--!strict

local DailyTaskTypes = require(script.Parent.Parent.Types)

type DailyTaskDefinition = DailyTaskTypes.DailyTaskDefinition

local function processEvent(_context, eventName, _payload, state)
	if eventName ~= "MatchCompleted" then
		return nil
	end

	return state.Progress + 1
end

local Task: DailyTaskDefinition = {
	Id = "daily_complete_matches",
	Title = "Finish 1 full match",
	Target = 1,
	RewardCredits = 200,
	ProcessEvent = processEvent,
}

return Task
