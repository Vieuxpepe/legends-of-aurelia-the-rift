extends CanvasLayer
class_name QTESequenceMemory

signal qte_finished(result: int)

var bf: Node2D
var result: int = 0
var sequence: Array[int] = []
var action_names: Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right"]
var display_names: Array[String] = ["UP", "DOWN", "LEFT", "RIGHT"]

var title_lbl: Label
var help_lbl: Label
var big_prompt: Label
var status_lbl: Label
var slot_labels: Array[Label] = []

var state: String = "SHOW"
var timer: float = 0.0
var show_index: int = 0
var correct_count: int = 0
var end_hold_timer: float = -1.0

# 0 = showing letter, 1 = gap between letters
var show_phase: int = 0 

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	sequence_length: int = 5,
	theme: Dictionary = {}
) -> QTESequenceMemory:
	var qte = QTESequenceMemory.new()
	qte.bf = parent_bf
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var accent: Color = theme.get("accent", Color(1.0, 0.9, 0.45))
	var secondary: Color = theme.get("secondary", Color.WHITE)
	
	for i in range(sequence_length):
		qte.sequence.append(randi() % 4)

	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.color = theme.get("bg_mod", Color(0.06, 0.06, 0.10, 0.68))
	dimmer.size = vp
	qte.add_child(dimmer)

	qte.title_lbl = Label.new()
	qte.title_lbl.name = "Title"
	qte.title_lbl.text = title_text
	qte.title_lbl.position = Vector2(0, 85)
	qte.title_lbl.size = Vector2(vp.x, 42)
	qte.title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.title_lbl.add_theme_font_size_override("font_size", 44)
	qte.title_lbl.add_theme_color_override("font_color", accent)
	qte.title_lbl.add_theme_constant_override("outline_size", 10)
	qte.title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.title_lbl)

	qte.help_lbl = Label.new()
	qte.help_lbl.name = "Help"
	qte.help_lbl.text = help_text
	qte.help_lbl.position = Vector2(0, 135)
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
			mgr._apply_qte_visual_overhaul(qte, qte.title_lbl, qte.help_lbl, theme)

	var panel := Panel.new()
	panel.name = "MemoryPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.92)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.6)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.size = Vector2(660, 240)
	panel.position = Vector2((vp.x - panel.size.x) * 0.5, (vp.y - panel.size.y) * 0.5 - 20.0)
	qte.add_child(panel)

	qte.big_prompt = Label.new()
	qte.big_prompt.name = "BigPrompt"
	qte.big_prompt.text = "-"
	qte.big_prompt.position = Vector2(0, 32)
	qte.big_prompt.size = Vector2(panel.size.x, 72)
	qte.big_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.big_prompt.add_theme_font_size_override("font_size", 58)
	qte.big_prompt.add_theme_color_override("font_color", secondary)
	qte.big_prompt.add_theme_constant_override("outline_size", 8)
	qte.big_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	panel.add_child(qte.big_prompt)

	qte.status_lbl = Label.new()
	qte.status_lbl.name = "StatusLabel"
	qte.status_lbl.text = "WATCH"
	qte.status_lbl.position = Vector2(0, 110)
	qte.status_lbl.size = Vector2(panel.size.x, 32)
	qte.status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.status_lbl.add_theme_font_size_override("font_size", 28)
	qte.status_lbl.add_theme_color_override("font_color", accent)
	qte.status_lbl.add_theme_constant_override("outline_size", 6)
	qte.status_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	panel.add_child(qte.status_lbl)

	var slot_names: Array[String] = ["1", "2", "3", "4", "5"]
	for i in range(sequence_length):
		var slot := Label.new()
		slot.name = "Slot" + str(i+1)
		slot.text = slot_names[i] if i < slot_names.size() else str(i+1)
		slot.position = Vector2(95 + (i * 100), 165)
		slot.size = Vector2(70, 32)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", 26)
		slot.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		slot.add_theme_constant_override("outline_size", 5)
		slot.add_theme_color_override("font_outline_color", Color.BLACK)
		panel.add_child(slot)
		qte.slot_labels.append(slot)

	parent_bf.get_tree().paused = true
	Input.flush_buffered_events()
	qte._start_show_phase()

	return qte

func _start_show_phase() -> void:
	big_prompt.text = display_names[sequence[show_index]]
	big_prompt.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	slot_labels[show_index].add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	show_phase = 0
	timer = 0.360 # Show duration

func _process(delta: float) -> void:
	if state == "DONE":
		end_hold_timer -= delta
		if end_hold_timer <= 0.0:
			bf.get_tree().paused = false
			qte_finished.emit(result)
			queue_free()
		return

	if state == "SHOW":
		timer -= delta
		if timer <= 0.0:
			if show_phase == 0:
				# enter gap phase
				big_prompt.text = "-"
				slot_labels[show_index].add_theme_color_override("font_color", Color(0.70, 0.70, 0.70))
				show_phase = 1
				timer = 0.120 # gap duration
			else:
				if bf.get("select_sound") and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.0 + (show_index * 0.05)
					bf.select_sound.play()
				
				show_index += 1
				if show_index >= sequence.size():
					state = "INPUT"
					status_lbl.text = "REPEAT"
					status_lbl.add_theme_color_override("font_color", Color(0.30, 1.0, 0.35))
					big_prompt.text = "INPUT"
					big_prompt.add_theme_color_override("font_color", Color.WHITE)
					timer = 3.600 # input window
				else:
					_start_show_phase()
		return

	if state == "INPUT":
		timer -= delta
		if timer <= 0.0:
			status_lbl.text = "TOO SLOW"
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			_finish_qte(0)
			return

		var pressed_index: int = -1
		for i in range(action_names.size()):
			if Input.is_action_just_pressed(action_names[i]):
				pressed_index = i
				break

		if pressed_index != -1:
			if pressed_index == sequence[correct_count]:
				slot_labels[correct_count].add_theme_color_override("font_color", Color(0.30, 1.0, 0.35))
				correct_count += 1
				
				if bf.get("select_sound") and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.12 + (correct_count * 0.06)
					bf.select_sound.play()
					
				if correct_count >= sequence.size():
					status_lbl.text = "PATTERN COMPLETE"
					status_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.20))
					big_prompt.text = "DONE"
					if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
					if bf.has_method("screen_shake"): bf.screen_shake(12.0, 0.20)
					
					if correct_count >= 5: _finish_qte(2)
					elif correct_count >= 3: _finish_qte(1)
					else: _finish_qte(0)
			else:
				status_lbl.text = "SEQUENCE BROKEN"
				status_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
				big_prompt.text = "X"
				if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
				if bf.has_method("screen_shake"): bf.screen_shake(8.0, 0.12)
				_finish_qte(0)

func _finish_qte(res: int) -> void:
	result = res
	state = "DONE"
	end_hold_timer = 0.420
