class_name RoundOption
extends RefCounted

var id: int
var risk: float
var reward: int
var size_hint: float


func _init(p_id: int, p_risk: float, p_reward: int, p_size_hint: float) -> void:
	id = p_id
	risk = p_risk
	reward = p_reward
	size_hint = p_size_hint
