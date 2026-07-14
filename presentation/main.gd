extends Control

const CHARGE_SWEET_SPOT := 0.6
const BLOCK_SIZE_MIN := 80.0
const BLOCK_SIZE_RANGE := 140.0
const TOWER_ZONE_SIZE := Vector2(320, 320)
const TOWER_BLOCK_HEIGHT := 40.0
const TILT_PER_FAIL := 6.0

var session: GameSession
var block_buttons: Array = []
var last_chosen_button: Button = null

var charging_button: Button = null
var charge_time := 0.0

var score_label: Label
var pips_row: HBoxContainer
var blocks_row: HBoxContainer
var tower_zone: Control
var tower_blocks: Array = []
var tower_height := 0.0
var start_overlay: Control
var end_overlay: Control
var end_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

	session = GameSession.new()
	session.round_ready.connect(_on_round_ready)
	session.round_resolved.connect(_on_round_resolved)
	session.run_ended.connect(_on_run_ended)


func _process(delta: float) -> void:
	if charging_button == null:
		return
	charge_time += delta
	var pulse := 1.0 + 0.25 * sin(charge_time * 10.0)
	charging_button.scale = Vector2(pulse, pulse)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.078, 0.086, 0.114)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 20)
	add_child(layout)

	score_label = Label.new()
	score_label.text = "0"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 28)
	layout.add_child(score_label)

	pips_row = HBoxContainer.new()
	pips_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pips_row.add_theme_constant_override("separation", 14)
	layout.add_child(pips_row)

	var tower_center := CenterContainer.new()
	layout.add_child(tower_center)

	tower_zone = Control.new()
	tower_zone.custom_minimum_size = TOWER_ZONE_SIZE
	tower_zone.pivot_offset = Vector2(TOWER_ZONE_SIZE.x / 2.0, TOWER_ZONE_SIZE.y)
	tower_center.add_child(tower_zone)

	blocks_row = HBoxContainer.new()
	blocks_row.alignment = BoxContainer.ALIGNMENT_CENTER
	blocks_row.add_theme_constant_override("separation", 36)
	blocks_row.custom_minimum_size = Vector2(0, 160)
	layout.add_child(blocks_row)

	var start_label := Label.new()
	start_label.text = "三個選擇,五個回合,最多失敗 %d 次。" % GameRules.MAX_FAILS
	start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_label.add_theme_font_size_override("font_size", 22)

	var start_button := Button.new()
	start_button.text = "開始"
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.custom_minimum_size = Vector2(160, 56)
	start_button.pressed.connect(_on_start_pressed)

	start_overlay = _wrap_overlay([start_label, start_button])
	add_child(start_overlay)

	end_label = Label.new()
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size", 22)

	var restart_button := Button.new()
	restart_button.text = "再來一局"
	restart_button.add_theme_font_size_override("font_size", 22)
	restart_button.custom_minimum_size = Vector2(160, 56)
	restart_button.pressed.connect(_on_restart_pressed)

	end_overlay = _wrap_overlay([end_label, restart_button])
	end_overlay.hide()
	add_child(end_overlay)


func _wrap_overlay(children: Array) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 18)
	overlay.add_child(panel)

	for child in children:
		panel.add_child(child)

	return overlay


func _block_width(size_hint: float) -> float:
	return BLOCK_SIZE_MIN + size_hint * BLOCK_SIZE_RANGE


func _risk_color(risk: float) -> Color:
	return Color.WHITE.lerp(Color(1.0, 0.3, 0.3), risk)


func _on_start_pressed() -> void:
	start_overlay.hide()
	_reset_tower()
	session.start_run()


func _on_restart_pressed() -> void:
	end_overlay.hide()
	_reset_tower()
	session.start_run()


func _reset_tower() -> void:
	for block in tower_blocks:
		block.queue_free()
	tower_blocks.clear()
	tower_height = 0.0
	tower_zone.rotation_degrees = 0.0


func _on_round_ready(round_index: int, options: Array) -> void:
	_refresh_pips(round_index)

	for child in blocks_row.get_children():
		child.queue_free()
	block_buttons.clear()

	for option in options:
		var side := _block_width(option.size_hint)
		var block := Button.new()
		block.custom_minimum_size = Vector2(side, side)
		block.pivot_offset = Vector2(side, side) / 2.0
		block.modulate = _risk_color(option.risk)
		block.focus_mode = Control.FOCUS_NONE
		block.button_down.connect(_on_block_down.bind(block))
		block.button_up.connect(_on_block_up.bind(block, option))
		blocks_row.add_child(block)
		block_buttons.append(block)


func _on_block_down(block: Button) -> void:
	if charging_button != null:
		return
	charging_button = block
	charge_time = 0.0


func _on_block_up(block: Button, option: RoundOption) -> void:
	if charging_button != block:
		return
	var influence := (
		1.0 - clampf(absf(charge_time - CHARGE_SWEET_SPOT) / CHARGE_SWEET_SPOT, 0.0, 1.0)
	)
	charging_button = null
	block.scale = Vector2.ONE
	last_chosen_button = block
	_lock_blocks()
	session.choose(option, influence)


func _lock_blocks() -> void:
	for block in block_buttons:
		block.disabled = true


func _on_round_resolved(result: Dictionary) -> void:
	if last_chosen_button == null:
		return
	var option: RoundOption = result["option"]
	var success: bool = result["success"]
	var flash_color := Color(0.4, 1.0, 0.5) if success else Color(1.0, 0.35, 0.35)

	var tween := create_tween()
	tween.tween_property(last_chosen_button, "modulate", flash_color, 0.15)
	tween.parallel().tween_property(last_chosen_button, "scale", Vector2(1.15, 1.15), 0.15)
	await tween.finished
	last_chosen_button = null

	if success:
		_land_block_on_tower(option)
	else:
		_tilt_tower(session.state.fails)

	if session.state.fails > GameRules.MAX_FAILS:
		_collapse_tower()
		await get_tree().create_timer(0.6).timeout

	session.advance()


func _land_block_on_tower(option: RoundOption) -> void:
	var width := _block_width(option.size_hint)
	var landed := ColorRect.new()
	landed.color = Color(0.55, 0.85, 0.6)
	landed.size = Vector2(width, TOWER_BLOCK_HEIGHT)
	landed.position = Vector2(
		(TOWER_ZONE_SIZE.x - width) / 2.0, TOWER_ZONE_SIZE.y - TOWER_BLOCK_HEIGHT - tower_height
	)
	landed.pivot_offset = Vector2(width, TOWER_BLOCK_HEIGHT) / 2.0
	tower_zone.add_child(landed)
	tower_blocks.append(landed)
	tower_height += TOWER_BLOCK_HEIGHT

	landed.scale = Vector2(1.0, 0.4)
	var settle_tween := create_tween()
	(
		settle_tween
		. tween_property(landed, "scale", Vector2.ONE, 0.18)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


func _tilt_tower(fails: int) -> void:
	var tilt_tween := create_tween()
	(
		tilt_tween
		. tween_property(tower_zone, "rotation_degrees", TILT_PER_FAIL * fails, 0.3)
		. set_trans(Tween.TRANS_ELASTIC)
		. set_ease(Tween.EASE_OUT)
	)


func _collapse_tower() -> void:
	for block in tower_blocks:
		var fall_tween := create_tween()
		fall_tween.set_parallel(true)
		var fall_offset := Vector2(randf_range(-260.0, 260.0), randf_range(180.0, 340.0))
		(
			fall_tween
			. tween_property(block, "position", block.position + fall_offset, 0.5)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN)
		)
		fall_tween.tween_property(block, "rotation_degrees", randf_range(-180.0, 180.0), 0.5)
		fall_tween.tween_property(block, "modulate:a", 0.0, 0.5)


func _on_run_ended(final_score: int, history: Array, survived: bool) -> void:
	var successes := 0
	for entry in history:
		if entry["success"]:
			successes += 1
	score_label.text = str(final_score)
	if survived:
		end_label.text = "撐完五回合!成功 %d / %d" % [successes, history.size()]
	else:
		end_label.text = "塔倒了(第 %d 回合)。成功 %d 次" % [history.size(), successes]
	end_overlay.show()


func _refresh_pips(round_index: int) -> void:
	for child in pips_row.get_children():
		child.queue_free()
	for i in GameRules.TOTAL_ROUNDS:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(18, 18)
		if i < round_index - 1:
			pip.color = Color(0.4, 0.8, 0.5)
		elif i == round_index - 1:
			pip.color = Color(0.9, 0.85, 0.3)
		else:
			pip.color = Color(0.3, 0.3, 0.36)
		pips_row.add_child(pip)
