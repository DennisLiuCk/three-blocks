extends Control

const CHARGE_SWEET_SPOT := 0.6

var session: GameSession
var block_buttons: Array = []
var last_chosen_button: Button = null

var charging_button: Button = null
var charge_time := 0.0

var score_label: Label
var pips_row: HBoxContainer
var blocks_row: HBoxContainer
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
	layout.add_theme_constant_override("separation", 28)
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

	blocks_row = HBoxContainer.new()
	blocks_row.alignment = BoxContainer.ALIGNMENT_CENTER
	blocks_row.add_theme_constant_override("separation", 36)
	blocks_row.custom_minimum_size = Vector2(0, 240)
	layout.add_child(blocks_row)

	var start_label := Label.new()
	start_label.text = "三個選擇,五個回合。"
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


func _on_start_pressed() -> void:
	start_overlay.hide()
	session.start_run()


func _on_restart_pressed() -> void:
	end_overlay.hide()
	session.start_run()


func _on_round_ready(round_index: int, options: Array) -> void:
	_refresh_pips(round_index)

	for child in blocks_row.get_children():
		child.queue_free()
	block_buttons.clear()

	for option in options:
		var side := 80.0 + option.size_hint * 120.0
		var block := Button.new()
		block.custom_minimum_size = Vector2(side, side)
		block.pivot_offset = Vector2(side, side) / 2.0
		block.modulate = Color.WHITE.lerp(Color(1.0, 0.3, 0.3), option.risk)
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
	var flash_color := Color(0.4, 1.0, 0.5) if result["success"] else Color(1.0, 0.35, 0.35)
	var tween := create_tween()
	tween.tween_property(last_chosen_button, "modulate", flash_color, 0.15)
	tween.parallel().tween_property(last_chosen_button, "scale", Vector2(1.15, 1.15), 0.15)
	await tween.finished
	last_chosen_button = null
	session.advance()


func _on_run_ended(final_score: int, history: Array) -> void:
	var successes := 0
	for entry in history:
		if entry["success"]:
			successes += 1
	score_label.text = str(final_score)
	end_label.text = "成功 %d / %d" % [successes, history.size()]
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
