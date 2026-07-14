class_name GameRules
extends RefCounted

const TOTAL_ROUNDS := 5
const INFLUENCE_STRENGTH := 0.35


func generate_round(round_index: int) -> Array[RoundOption]:
	var tension := float(round_index - 1) / float(TOTAL_ROUNDS - 1)
	var options: Array[RoundOption] = []
	options.append(RoundOption.new(0, lerpf(0.05, 0.20, tension), 1, 0.35))
	options.append(RoundOption.new(1, lerpf(0.20, 0.45, tension), 2, 0.65))
	options.append(RoundOption.new(2, lerpf(0.35, 0.70, tension), 3, 1.0))
	return options


func resolve(option: RoundOption, influence: float, rng: RandomNumberGenerator) -> Dictionary:
	var effective_risk := clampf(option.risk - influence * INFLUENCE_STRENGTH, 0.02, 0.98)
	var success := rng.randf() > effective_risk
	return {
		"success": success,
		"score_delta": option.reward if success else 0,
		"effective_risk": effective_risk,
	}
