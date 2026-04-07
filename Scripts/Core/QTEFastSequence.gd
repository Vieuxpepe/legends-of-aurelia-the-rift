extends CanvasLayer
class_name QTEFastSequence

signal qte_finished(result: int)

var bf: Node2D
var sweep_duration: float
var timer: float = 0.0
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var labels: Array[Label] = []
var sequence: Array[int] = []
var correct_count: int = 0
var max_perfect_timer: float = 1.0

var action_names: Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right"]
var display_names: Array[String] = ["UP", "DOWN", "LEFT", "RIGHT"]

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	num_stages: int,
	total_ms: int,
	perfect_ms: int,
	theme: Dictionary = {}
) -> QTEFastSequence:
	var qte = QTEFastSequence.new()
	qte.bf = parent_bf
	qte.sweep_duration = total_ms / 1000.0
	qte.max_perfect_timer = perfect_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var accent: Color = theme.get("accent", Color(1.0, 0.88, 0.35))
	var secondary: Color = theme.get("secondary", Color.WHITE)
	var vp := parent_bf.get_viewport_rect().size
	
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.color = theme.get("bg_mod", Color(0.02, 0.05, 0.10, 0.70))
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.name = "Title"
	title.text = title_text
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", accent)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.name = "Help"
	qte.help_lbl.text = help_text
	qte.help_lbl.position = Vector2(0, 130)
	qte.help_lbl.size = Vector2(vp.x, 30)
	qte.help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.help_lbl.add_theme_font_size_override("font_size", 24)
	qte.help_lbl.add_theme_color_override("font_color", secondary)
	qte.help_lbl.add_theme_constant_override("outline_size", 6)
	qte.help_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.help_lbl)

	if parent_bf.has_node("/root/QTEManager"):
		var mgr = parent_bf.get_node("/root/QTEManager")
		if mgr.has_method("_apply_qte_visual_overhaul"):
			mgr._apply_qte_visual_overhaul(qte, title, qte.help_lbl, theme)

	var panel := Panel.new()
	panel.name = "SequencePanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.92)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.6)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.size = Vector2(maxf(600, 150 * num_stages), 200)
	panel.position = Vector2((vp.x - panel.size.x) * 0.5, vp.y * 0.5 - 20)
	qte.add_child(panel)

	for i in range(num_stages): qte.sequence.append(randi() % 4)

	for i in range(num_stages):
		var lbl := Label.new()
		lbl.name = "Stage" + str(i+1)
		lbl.text = qte.display_names[qte.sequence[i]]
		lbl.position = Vector2((panel.size.x / num_stages) * i, 70)
		lbl.size = Vector2(panel.size.x / num_stages, 60)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 38)
		lbl.add_theme_color_override("font_color", accent)
		lbl.add_theme_constant_override("outline_size", 7)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		panel.add_child(lbl)
		qte.labels.append(lbl)

	parent_bf.get_tree().paused = true
	Input.flush_buffered_events()
	
	return qte

	parent_bf.get_tree().paused = true
	Input.flush_buffered_events()
	
	return qte

func _process(delta: float) -> void:
	if is_done:
		end_hold_timer -= delta
		if end_hold_timer <= 0.0:
			bf.get_tree().paused = false
			qte_finished.emit(result)
			queue_free()
		return
		
	timer += delta
	if timer >= sweep_duration:
		_end_qte(0, "TOO SLOW", Color(1.0, 0.3, 0.3), true)
		return

	var pressed_index: int = -1
	for i in range(action_names.size()):
		if Input.is_action_just_pressed(action_names[i]):
			pressed_index = i
			break

	if pressed_index == -1: return

	if pressed_index == sequence[correct_count]:
		labels[correct_count].add_theme_color_override("font_color", Color(0.3, 1.0, 0.35))
		correct_count += 1
		if bf.get("select_sound") and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.1 + correct_count * 0.08
			bf.select_sound.play()

		if correct_count >= sequence.size():
			if timer <= max_perfect_timer:
				_end_qte(2, "PERFECT", Color(1.0, 0.85, 0.2), false)
			else:
				_end_qte(1, "GOOD", Color(0.3, 1.0, 0.35), false)
	else:
		_end_qte(0, "SEQUENCE BROKEN", Color(1.0, 0.3, 0.3), true)

func _end_qte(res: int, msg: String, color: Color, shook: bool) -> void:
	result = res
	is_done = true
	end_hold_timer = 0.36
	help_lbl.text = msg
	help_lbl.add_theme_color_override("font_color", color)
	
	if res == 2:
		if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(12.0, 0.20)
	elif res == 1:
		if bf.has_method("screen_shake"): bf.screen_shake(6.0, 0.10)
	else:
		if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(8.0, 0.12)
