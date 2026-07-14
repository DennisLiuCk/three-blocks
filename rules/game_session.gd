class_name GameSession
extends RefCounted

signal round_ready(round_index: int, options: Array)
signal round_resolved(result: Dictionary)
signal run_ended(final_score: int, history: Array)

var rules := GameRules.new()
var state := RunState.new()
var rng := RandomNumberGenerator.new()


func start_run() -> void:
	state = RunState.new()
	rng.randomize()
	_announce_round()


func choose(option: RoundOption, influence: float) -> void:
	var result := rules.resolve(option, influence, rng)
	result["round_index"] = state.round_index
	result["option"] = option
	state.history.append(result)
	if result["success"]:
		state.score += int(result["score_delta"])
	round_resolved.emit(result)


# Presentation calls this once its feedback animation finishes, so round
# pacing stays a view concern instead of a rules concern.
func advance() -> void:
	state.round_index += 1
	if state.round_index > GameRules.TOTAL_ROUNDS:
		run_ended.emit(state.score, state.history)
	else:
		_announce_round()


func _announce_round() -> void:
	round_ready.emit(state.round_index, rules.generate_round(state.round_index))
