extends CanvasLayer
class_name QTEReactionStrike

signal qte_finished(result: int)

var bf: Node2D
var is_done: bool = false
var stages: int = 4
var current_stage: int = 0
var hits: int = 0
var result: int = 0

var help_lbl: Label
var arrow_label: Label
var end_hold_timer: float = -1.0

var state: String = "WAITING"
var wait_timer: float = 0.0
var react_timer: float = 0.0
var react_window: float = 0.55
var target_idx: int = 0
var arrows: Array[String] = ["UP ↑", "DOWN ↓", "LEFT ←", "RIGHT →"]
var actions: Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right"]

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	num_stages: int,
	react_ms: int
) -> QTEReactionStrike:
	var qte = QTEReactionStrike.new()
	qte.bf = parent_bf
	qte.stages = num_stages
	qte.react_window = react_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.04, 0.04, 0.08, 0.70)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 75)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.30))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.text = help_text
	qte.help_lbl.position = Vector2(0, 130)
	qte.help_lbl.size = Vector2(vp.x, 30)
	qte.help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.help_lbl.add_theme_font_size_override("font_size", 22)
	qte.help_lbl.add_theme_color_override("font_color", Color.WHITE)
	qte.help_lbl.add_theme_constant_override("outline_size", 6)
	qte.help_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.help_lbl)

	if parent_bf.has_node("/root/QTEManager"):
		var mgr = parent_bf.get_node("/root/QTEManager")
		if mgr.has_method("_apply_qte_visual_overhaul"):
			mgr._apply_qte_visual_overhaul(qte, title, qte.help_lbl)

	qte.arrow_label = Label.new()
	qte.arrow_label.text = ""
	qte.arrow_label.position = Vector2(0, vp.y * 0.5 - 50)
	qte.arrow_label.size = Vector2(vp.x, 100)
	qte.arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.arrow_label.add_theme_font_size_override("font_size", 80)
	qte.arrow_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	qte.arrow_label.add_theme_constant_override("outline_size", 10)
	qte.arrow_label.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.arrow_label)
	
	parent_bf.get_tree().paused = true
	Input.flush_buffered_events()
	qte._start_next_stage()
	
	return qte

func _start_next_stage() -> void:
	if current_stage >= stages:
		_finish_qte()
		return
		
	state = "WAITING"
	arrow_label.text = ""
	wait_timer = randf_range(0.3, 0.7)

func _process(delta: float) -> void:
	if is_done:
		end_hold_timer -= delta
		if end_hold_timer <= 0.0:
			bf.get_tree().paused = false
			qte_finished.emit(result)
			queue_free()
		return
		
	if state == "WAITING":
		wait_timer -= delta
		if wait_timer <= 0.0:
			state = "REACTION"
			react_timer = react_window
			target_idx = randi() % 4
			arrow_label.text = arrows[target_idx]
			arrow_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			if bf.get("select_sound") and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.0 + (current_stage * 0.1)
				bf.select_sound.play()
				
	elif state == "REACTION":
		react_timer -= delta
		
		var pressed_idx := -1
		for i in range(4):
			if Input.is_action_just_pressed(actions[i]):
				pressed_idx = i
				break
				
		if pressed_idx != -1:
			if pressed_idx == target_idx:
				hits += 1
				arrow_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
				if bf.has_method("screen_shake"): bf.screen_shake(6.0, 0.1)
			else:
				arrow_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
				if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
			_end_stage_show_result()
		elif react_timer <= 0.0:
			arrow_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
			if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
			_end_stage_show_result()

	elif state == "SHOWING":
		wait_timer -= delta
		if wait_timer <= 0.0:
			current_stage += 1
			_start_next_stage()

func _end_stage_show_result() -> void:
	state = "SHOWING"
	wait_timer = 0.20

func _finish_qte() -> void:
	is_done = true
	end_hold_timer = 0.40
	
	if hits == stages:
		result = 2
		help_lbl.text = "PERFECT CAST"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(16.0, 0.25)
	elif hits >= stages / 2:
		result = 1
		help_lbl.text = "SUCCESSFUL CAST"
		help_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	else:
		result = 0
		help_lbl.text = "STUMBLED"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
