--!strict

export type MatchState = "Intermission" | "Voting" | "Match" | "PostMatch"

return {
	Intermission = "Intermission" :: MatchState,
	Voting = "Voting" :: MatchState,
	Match = "Match" :: MatchState,
	PostMatch = "PostMatch" :: MatchState,
}
