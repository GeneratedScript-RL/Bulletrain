--!strict

export type DailyTaskEntry = {
	Progress: number,
	RewardClaimed: boolean,
}

export type DailyTaskProfile = {
	DayKey: string,
	Tasks: { [string]: DailyTaskEntry },
}

export type DailyTaskSnapshotEntry = {
	Id: string,
	Title: string,
	RewardCredits: number,
	Progress: number,
	Target: number,
	IsComplete: boolean,
	RewardClaimed: boolean,
}

export type DailyTaskSnapshot = {
	DayKey: string,
	ResetAtUnix: number,
	Tasks: { DailyTaskSnapshotEntry },
}

export type DailyTaskContext = {
	Player: Player,
	Services: { [string]: any },
}

export type DailyTaskDefinition = {
	Id: string,
	Title: string,
	Target: number,
	RewardCredits: number,
	ProcessEvent: (context: DailyTaskContext, eventName: string, payload: any, state: DailyTaskEntry) -> number?,
}

return {}
