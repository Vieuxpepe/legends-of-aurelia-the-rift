extends CanvasLayer
class_name QTEComboRush

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var total_duration: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var combos_completed: int = 0

var help_lbl: Label
var labels: Array[Label] = []
var sequence: Array[int] = []
var current_step: int = 0

var actions := ["ui_up", "ui_down", "ui_left", "ui_right"]
var names := ["UP", "DOWN", "LEFT", "RIGHT"]

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int,
	theme: Dictionary = {}
) -> QTEComboRush:
	var qte = QTEComboRush.new()
	qte.bf = parent_bf
	qte.total_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var accent: Color = theme.get("accent", Color(0.96, 0.82, 0.32))
	var secondary: Color = theme.get("secondary", Color(1.0, 1.0, 1.0))
	var vp := parent_bf.get_viewport_rect().size
	
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.color = theme.get("bg_mod", Color(0.0, 0.0, 0.0, 0.65))
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.name = "Title"
	title.text = title_text
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 52)
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
	qte.help_lbl.size = Vector2(vp.x, 32)
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

	var panel := ColorRect.new()
	panel.name = "Arena"
	panel.size = Vector2(760, 230)
	panel.position = vp * 0.5 - Vector2(380, 115)
	panel.color = Color(0.02, 0.02, 0.03, 0.95)
	qte.add_child(panel)

	for i in range(4):
		var lbl := Label.new()
		lbl.name = "Label" + str(i)
		lbl.position = Vector2(30 + i * 180, 60)
		lbl.size = Vector2(160, 60)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 42)
		lbl.add_theme_color_override("font_color", accent)
		lbl.add_theme_constant_override("outline_size", 8)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		panel.add_child(lbl)
		qte.labels.append(lbl)

	qte._generate_sequence()
	parent_bf.get_tree().paused = true
	Input.flush_buffered_events()
	
	return qte

func _generate_sequence() -> void:
	sequence.clear()
	for i in range(4):
		var idx := randi() % 4
		sequence.append(idx)
		labels[i].text = names[idx]
		labels[i].add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	current_step = 0

func _process(delta: float) -> void:
	if is_done:
		end_hold_timer -= delta
		if end_hold_timer <= 0.0:
			bf.get_tree().paused = false
			qte_finished.emit(combos_completed)
			queue_free()
		return
		
	timer += delta
	if timer >= total_duration:
		is_done = true; end_hold_timer = 0.40
		help_lbl.text = "TIME EXPIRED"; return

	var pressed := -1
	for i in range(4):
		if Input.is_action_just_pressed(actions[i]): pressed = i; break
		
	if pressed != -1:
		if pressed == sequence[current_step]:
			labels[current_step].add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
			current_step += 1
			if bf.get("select_sound") and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.0 + current_step * 0.15; bf.select_sound.play()
			
			if current_step >= 4:
				combos_completed += 1
				help_lbl.text = "COMBOS: " + str(combos_completed)
				if combos_completed % 2 == 0: bf.screen_shake(8.0, 0.1)
				_generate_sequence()
		else:
			if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
			_generate_sequence()
