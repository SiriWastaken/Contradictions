--!strict
-- Tunable gameplay values. Replicated to clients: nothing secret here.

return table.freeze({
	ROUND_SECONDS = 5,
	GRACE_SECONDS = 0.15, -- server waits this long past the deadline for in-flight clicks
	LOCKOUT_SECONDS = 0.2, -- clicks this soon after a round starts are ignored (stray double-clicks)
	TRANSITION_SECONDS = 0.9, -- pause after a correct answer before the next round
	PARADOX_TRANSITION_SECONDS = 2.6, -- longer, so the "no answer existed" note can be read
	REVIEW_MIN_SECONDS = 0.6, -- tutorial CONTINUE is ignored for this long after a result
	POINTS = 100,
	STREAK_BONUS = 25,
	STREAK_BONUS_CAP = 4,
	STORE_NAME = "ContradictionsOnboarding",
})
