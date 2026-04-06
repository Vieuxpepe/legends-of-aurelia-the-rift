extends CanvasLayer
class_name QTEOscillationStop

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var sweep_duration: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var needle: ColorRect
var sweet_dot: ColorRect

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int
) -> QTEOscillationStop:
	var qte = QTEOscillationStop.new()
	qte.bf = parent_bf
	qte.sweep_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.14, 0.03, 0.02, 0.84)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 70)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.25))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.text = help_text
	qte.help_lbl.position = Vector2(0, 115)
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

	var dial := Panel.new()
	dial.size = Vector2(340, 340)
	dial.position = Vector2((vp.x - 340) * 0.5, (vp.y - 340) * 0.5 - 10)
	var dial_style := StyleBoxFlat.new()
	dial_style.bg_color = Color(0.08, 0.08, 0.08, 0.96)
	dial_style.border_width_left = 4; dial_style.border_width_top = 4
	dial_style.border_width_right = 4; dial_style.border_width_bottom = 4
	dial_style.border_color = Color(0.70, 0.70, 0.75, 0.85)
	dial_style.corner_radius_top_left = 180; dial_style.corner_radius_top_right = 180
	dial_style.corner_radius_bottom_left = 180; dial_style.corner_radius_bottom_right = 180
	dial.add_theme_stylebox_override("panel", dial_style)
	qte.add_child(dial)

	var pivot := ColorRect.new()
	pivot.size = Vector2(12, 12); pivot.position = Vector2(170-6, 170-6); pivot.color = Color.WHITE
	dial.add_child(pivot)

	qte.sweet_dot = ColorRect.new()
	qte.sweet_dot.size = Vector2(22, 22); qte.sweet_dot.position = Vector2(170-11, 18); qte.sweet_dot.color = Color(1.0, 0.85, 0.2, 1.0)
	dial.add_child(qte.sweet_dot)

	qte.needle = ColorRect.new()
	qte.needle.size = Vector2(8, 132); qte.needle.position = Vector2(170-4, 170-118); qte.needle.pivot_offset = Vector2(4, 118); qte.needle.color = Color(1.0, 0.72, 0.28, 1.0)
	dial.add_child(qte.needle)

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
		_fail_qte("TOO SLOW")
		return

	var current_angle := sin(timer * 12.5) * 82.0
	needle.rotation_degrees = current_angle

	if Input.is_action_just_pressed("ui_accept"):
		is_done = true
		end_hold_timer = 0.36
		var diff := absf(current_angle)
		
		if diff <= 4.0:
			result = 3; help_lbl.text = "MAX TOSS"; help_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			needle.color = Color.WHITE; sweet_dot.color = Color.WHITE
			if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(18.0, 0.26)
		elif diff <= 10.0:
			result = 2; help_lbl.text = "HEAVY TOSS"; help_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
			needle.color = Color(0.35, 1.0, 0.35)
			if bf.get("select_sound") and bf.select_sound.stream != null: 
				bf.select_sound.pitch_scale = 1.18; bf.select_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(10.0, 0.14)
		elif diff <= 18.0:
			result = 1; help_lbl.text = "LIGHT TOSS"; help_lbl.add_theme_color_override("font_color", Color(1.0, 0.70, 0.30))
			needle.color = Color(1.0, 0.70, 0.30)
			if bf.get("select_sound") and bf.select_sound.stream != null: 
				bf.select_sound.pitch_scale = 1.08; bf.select_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(6.0, 0.08)
		else:
			_fail_qte("WHIFFED")

func _fail_qte(reason: String) -> void:
	result = 0
	is_done = true
	end_hold_timer = 0.36
	help_lbl.text = reason
	help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
