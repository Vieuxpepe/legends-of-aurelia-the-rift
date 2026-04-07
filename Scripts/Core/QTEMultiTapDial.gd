extends CanvasLayer
class_name QTEMultiTapDial

signal qte_finished(result: int)

var bf: Node2D
var sweep_speed: float
var duration_limit: float
var timer: float = 0.0
var result: int = 0
var is_done: bool = false
var end_hold_timer: float = -1.0

var help_lbl: Label
var needle: ColorRect
var target_dots: Array[ColorRect] = []
var hit_flags: Array[bool] = []
var target_angles: Array[float] = []
var hits: int = 0

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	angles: Array,
	speed: float,
	max_duration_ms: int,
	theme: Dictionary = {}
) -> QTEMultiTapDial:
	var qte = QTEMultiTapDial.new()
	qte.bf = parent_bf
	qte.sweep_speed = speed
	qte.duration_limit = max_duration_ms / 1000.0
	for a in angles:
		qte.target_angles.append(float(a))
		qte.hit_flags.append(false)
	
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

	var dial := Panel.new()
	dial.name = "Dial"
	dial.size = Vector2(320, 320)
	dial.position = Vector2((vp.x - dial.size.x) * 0.5, (vp.y - dial.size.y) * 0.5 + 40)
	var dial_style := StyleBoxFlat.new()
	dial_style.bg_color = Color(0.02, 0.02, 0.03, 0.95)
	dial_style.border_width_left = 6
	dial_style.border_width_top = 6
	dial_style.border_width_right = 6
	dial_style.border_width_bottom = 6
	dial_style.border_color = accent
	dial_style.corner_radius_top_left = 180
	dial_style.corner_radius_top_right = 180
	dial_style.corner_radius_bottom_left = 180
	dial_style.corner_radius_bottom_right = 180
	dial.add_theme_stylebox_override("panel", dial_style)
	qte.add_child(dial)

	var pivot := ColorRect.new()
	pivot.name = "Pivot"
	pivot.size = Vector2(16, 16)
	pivot.position = dial.size * 0.5 - Vector2(8, 8)
	pivot.color = Color.WHITE
	dial.add_child(pivot)

	var radius := 118.0
	for angle_deg in qte.target_angles:
		var dot := ColorRect.new()
		dot.name = "TargetDot"
		dot.size = Vector2(24, 24)
		var rad := deg_to_rad(angle_deg - 90.0)
		var center_pos := dial.size * 0.5 + Vector2(cos(rad), sin(rad)) * radius
		dot.position = center_pos - dot.size * 0.5
		dot.color = secondary
		dial.add_child(dot)
		qte.target_dots.append(dot)

	qte.needle = ColorRect.new()
	qte.needle.name = "Needle"
	qte.needle.size = Vector2(8, 128)
	qte.needle.position = dial.size * 0.5 - Vector2(4, 114)
	qte.needle.pivot_offset = Vector2(4, 114)
	qte.needle.color = accent
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
	if timer >= duration_limit:
		_finish_qte()
		return

	var angle: float = wrapf(timer * sweep_speed, 0.0, 360.0)
	needle.rotation_degrees = angle
	
	if Input.is_action_just_pressed("ui_accept"):
		var found := false
		for i in range(target_angles.size()):
			if hit_flags[i]:
				continue
			var diff: float = float(abs(wrapf(angle - target_angles[i], -180.0, 180.0)))
			if diff <= 12.0:
				hit_flags[i] = true
				hits += 1
				target_dots[i].color = Color(0.35, 1.0, 0.35, 1.0)
				found = true
				if bf.get("select_sound") and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.15 + float(hits) * 0.08
					bf.select_sound.play()
				break
		
		if not found:
			if bf.get("miss_sound") and bf.miss_sound.stream != null:
				bf.miss_sound.play()

		if hits >= target_angles.size():
			_finish_qte()

func _finish_qte() -> void:
	is_done = true
	end_hold_timer = 0.40
	
	if hits >= target_angles.size():
		result = 2
		help_lbl.text = "PERFECT TEMPEST"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		if bf.has_method("screen_shake"):
			bf.screen_shake(14.0, 0.20)
	elif hits >= target_angles.size() - 1:
		result = 1
		help_lbl.text = "GOOD TEMPEST"
		help_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		if bf.get("select_sound") and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.2
			bf.select_sound.play()
		if bf.has_method("screen_shake"):
			bf.screen_shake(7.0, 0.10)
	else:
		result = 0
		help_lbl.text = "FAILED"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.get("miss_sound") and bf.miss_sound.stream != null:
			bf.miss_sound.play()
