extends CanvasLayer
class_name QTEMashMeter

signal qte_finished(result: int)

var bf: Node2D
var total_duration: float
var timer: float = 0.0
var result: int = 0
var is_done: bool = false
var end_hold_timer: float = -1.0

var meter: float = 28.0
var decay_rate: float = 24.0
var fill_per_press: float = 13.0

var help_lbl: Label
var bar_bg: ColorRect
var fill: ColorRect

var arrow_1: Label
var arrow_2: Label
var arrow_3: Label

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	total_ms: int,
	start_meter: float = 28.0
) -> QTEMashMeter:
	var qte = QTEMashMeter.new()
	qte.bf = parent_bf
	qte.total_duration = total_ms / 1000.0
	qte.meter = start_meter
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.02, 0.04, 0.08, 0.60)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 100)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.70, 0.92, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.text = help_text
	qte.help_lbl.position = Vector2(0, 145)
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

	qte.bar_bg = ColorRect.new()
	qte.bar_bg.color = Color(0.08, 0.08, 0.08, 0.96)
	qte.bar_bg.size = Vector2(520, 34)
	qte.bar_bg.position = Vector2((vp.x - qte.bar_bg.size.x) * 0.5, (vp.y - qte.bar_bg.size.y) * 0.5 - 18.0)
	qte.add_child(qte.bar_bg)

	var good_line := ColorRect.new()
	good_line.color = Color(0.30, 0.95, 0.35, 0.95)
	good_line.size = Vector2(4, 34)
	good_line.position = Vector2(qte.bar_bg.size.x * 0.58, 0)
	qte.bar_bg.add_child(good_line)

	var perfect_line := ColorRect.new()
	perfect_line.color = Color(1.0, 0.86, 0.20, 0.98)
	perfect_line.size = Vector2(4, 34)
	perfect_line.position = Vector2(qte.bar_bg.size.x * 0.84, 0)
	qte.bar_bg.add_child(perfect_line)

	qte.fill = ColorRect.new()
	qte.fill.color = Color(0.55, 0.85, 1.0, 1.0)
	qte.fill.size = Vector2(0, 34)
	qte.fill.position = Vector2.ZERO
	qte.bar_bg.add_child(qte.fill)

	qte.arrow_1 = Label.new()
	qte.arrow_1.text = "ARROW I"
	qte.arrow_1.position = Vector2(qte.bar_bg.position.x + 30, qte.bar_bg.position.y + 55)
	qte.arrow_1.add_theme_font_size_override("font_size", 20)
	qte.arrow_1.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	qte.arrow_1.add_theme_constant_override("outline_size", 5)
	qte.arrow_1.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.arrow_1)

	qte.arrow_2 = Label.new()
	qte.arrow_2.text = "ARROW II"
	qte.arrow_2.position = Vector2(qte.bar_bg.position.x + 210, qte.bar_bg.position.y + 55)
	qte.arrow_2.add_theme_font_size_override("font_size", 20)
	qte.arrow_2.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	qte.arrow_2.add_theme_constant_override("outline_size", 5)
	qte.arrow_2.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.arrow_2)

	qte.arrow_3 = Label.new()
	qte.arrow_3.text = "ARROW III"
	qte.arrow_3.position = Vector2(qte.bar_bg.position.x + 395, qte.bar_bg.position.y + 55)
	qte.arrow_3.add_theme_font_size_override("font_size", 20)
	qte.arrow_3.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	qte.arrow_3.add_theme_constant_override("outline_size", 5)
	qte.arrow_3.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.arrow_3)

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
	if timer >= total_duration:
		_evaluate_finish()
		return
		
	meter -= decay_rate * delta
	meter = clamp(meter, 0.0, 100.0)

	if Input.is_action_just_pressed("ui_accept"):
		meter += fill_per_press
		meter = clamp(meter, 0.0, 100.0)
		fill.color = Color(0.85, 0.96, 1.0, 1.0)
		if bf.get("select_sound") and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = randf_range(1.15, 1.35)
			bf.select_sound.play()
	else:
		fill.color = Color(0.55, 0.85, 1.0, 1.0)

	fill.size.x = (meter / 100.0) * bar_bg.size.x

	if meter >= 20.0:
		arrow_1.add_theme_color_override("font_color", Color.WHITE)
	if meter >= 58.0:
		arrow_2.add_theme_color_override("font_color", Color(0.30, 1.0, 0.35))
	if meter >= 84.0:
		arrow_3.add_theme_color_override("font_color", Color(1.0, 0.86, 0.20))

func _evaluate_finish() -> void:
	is_done = true
	end_hold_timer = 0.35
	
	if meter >= 84.0:
		result = 2
		help_lbl.text = "PERFECT VOLLEY"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.20))
		if bf.get("crit_sound") and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		if bf.has_method("screen_shake"):
			bf.screen_shake(12.0, 0.20)
	elif meter >= 58.0:
		result = 1
		help_lbl.text = "GOOD VOLLEY"
		help_lbl.add_theme_color_override("font_color", Color(0.30, 1.0, 0.35))
		if bf.get("select_sound") and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.18
			bf.select_sound.play()
		if bf.has_method("screen_shake"):
			bf.screen_shake(6.0, 0.10)
	else:
		result = 0
		help_lbl.text = "WEAK VOLLEY"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		if bf.get("miss_sound") and bf.miss_sound.stream != null:
			bf.miss_sound.play()
