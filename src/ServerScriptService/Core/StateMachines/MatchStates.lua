--!strict

export type MatchState = "Intermission" | "Voting" | "Match" | "PostMatch"

local MatchStates = {
	Intermission = "Intermission" :: MatchState,
	Voting = "Voting" :: MatchState,
	Match = "Match" :: MatchState,
	PostMatch = "PostMatch" :: MatchState,
}

return MatchStates
