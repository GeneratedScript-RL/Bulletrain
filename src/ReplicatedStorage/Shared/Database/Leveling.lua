--!strict

local Leveling = {}

-- Simple scalable curve:
-- Level 1->2: 100
-- then increases by 25 per level (tweak anytime)
function Leveling.RequiredXPForLevel(level: number): number
	level = math.max(1, level)
	return 100 + (level - 1) * 25
end

function Leveling.ApplyXP(level: number, xp: number, amount: number): (number, number)
	level = math.max(1, level)
	xp = math.max(0, xp)
	amount = math.max(0, amount)

	xp += amount

	while true do
		local required = Leveling.RequiredXPForLevel(level)
		if xp < required then
			break
		end
		xp -= required
		level += 1
	end

	return level, xp
end

return Leveling
