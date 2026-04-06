extends CanvasLayer
class_name QTEBubbleExpansion

signal qte_finished(result: int)

var bf: Node2D
var sweep_duration: float
var timer: float = 0.0
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var wave: Panel
var counter: Label

var radius: float = 40.0
var peak_radius: float = 40.0

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int
) -> QTEBubbleExpansion:
	var qte = QTEBubbleExpansion.new()
	qte.bf = parent_bf
	qte.sweep_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.12, 0.04, 0.02, 0.74)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 70)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.15))
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

	qte.wave = Panel.new()
	var wave_style := StyleBoxFlat.new()
	wave_style.bg_color = Color(0, 0, 0, 0)
	wave_style.border_width_left = 8
	wave_style.border_width_top = 8
	wave_style.border_width_right = 8
	wave_style.border_width_bottom = 8
	wave_style.border_color = Color(1.0, 0.55, 0.15, 1.0)
	wave_style.corner_radius_top_left = 500
	wave_style.corner_radius_top_right = 500
	wave_style.corner_radius_bottom_left = 500
	wave_style.corner_radius_bottom_right = 500
	qte.wave.add_theme_stylebox_override("panel", wave_style)
	qte.add_child(qte.wave)

	qte.counter = Label.new()
	qte.counter.text = "POWER: 0"
	qte.counter.position = Vector2(0, vp.y - 140.0)
	qte.counter.size = Vector2(vp.x, 36)
	qte.counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.counter.add_theme_font_size_override("font_size", 30)
	qte.counter.add_theme_color_override("font_color", Color.WHITE)
	qte.counter.add_theme_constant_override("outline_size", 6)
	qte.counter.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.counter)
	
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
		_finish_qte()
		return

	radius -= 24.0 * delta
	radius = maxf(36.0, radius)

	if Input.is_action_just_pressed("ui_accept"):
		radius += 18.0
		peak_radius = maxf(peak_radius, radius)
		
		if bf.get("select_sound") and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = min(1.05 + (radius - 40.0) / 180.0, 1.8)
			bf.select_sound.play()

	var center := bf.get_viewport_rect().size * 0.5 + Vector2(0, 10)
	wave.size = Vector2(radius * 2.0, radius * 2.0)
	wave.position = center - wave.size * 0.5
	counter.text = "POWER: " + str(int(round(peak_radius - 40.0)))

func _finish_qte() -> void:
	is_done = true
	end_hold_timer = 0.40
	
	if peak_radius >= 220.0:
		result = 2
		help_lbl.text = "PERFECT CAST"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(14.0, 0.20)
	elif peak_radius >= 145.0:
		result = 1
		help_lbl.text = "GOOD CAST"
		help_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		if bf.get("select_sound") and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.18
			bf.select_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(6.0, 0.10)
	else:
		result = 0
		help_lbl.text = "FAILED"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.get("miss_sound") and bf.miss_sound.stream != null:
			bf.miss_sound.play()
