extends CanvasLayer
class_name QTEShrinkingRing

signal qte_finished(result: int)

var bf: Node2D
var sweep_duration: float
var timer: float = 0.0
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var target: Panel
var ring: Panel
var target_style: StyleBoxFlat
var ring_style: StyleBoxFlat

var start_size: float = 260.0
var end_size: float = 60.0
var target_size_f: float = 80.0

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int,
	theme: Dictionary = {}
) -> QTEShrinkingRing:
	var qte = QTEShrinkingRing.new()
	qte.bf = parent_bf
	qte.sweep_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var accent: Color = theme.get("accent", Color(1.0, 0.9, 0.4))
	var vp := parent_bf.get_viewport_rect().size
	
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.color = theme.get("bg_mod", Color(0.12, 0.08, 0.0, 0.6))
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.name = "Title"
	title.text = title_text
	title.position = Vector2(0, 90)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", accent)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.name = "Help"
	qte.help_lbl.text = help_text
	qte.help_lbl.position = Vector2(0, 145)
	qte.help_lbl.size = Vector2(vp.x, 30)
	qte.help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.help_lbl.add_theme_font_size_override("font_size", 24)
	qte.help_lbl.add_theme_color_override("font_color", Color.WHITE)
	qte.help_lbl.add_theme_constant_override("outline_size", 6)
	qte.help_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.help_lbl)

	if parent_bf.has_node("/root/QTEManager"):
		var mgr = parent_bf.get_node("/root/QTEManager")
		if mgr.has_method("_apply_qte_visual_overhaul"):
			mgr._apply_qte_visual_overhaul(qte, title, qte.help_lbl, theme)

	var center := vp * 0.5 + Vector2(0, 20)

	qte.target = Panel.new()
	qte.target.name = "TargetCircle"
	qte.target.size = Vector2(qte.target_size_f, qte.target_size_f)
	qte.target.position = center - qte.target.size * 0.5
	qte.target_style = StyleBoxFlat.new()
	qte.target_style.bg_color = Color(0, 0, 0, 0.2)
	qte.target_style.border_width_left = 6
	qte.target_style.border_width_top = 6
	qte.target_style.border_width_right = 6
	qte.target_style.border_width_bottom = 6
	qte.target_style.border_color = accent
	qte.target_style.corner_radius_top_left = 64
	qte.target_style.corner_radius_top_right = 64
	qte.target_style.corner_radius_bottom_left = 64
	qte.target_style.corner_radius_bottom_right = 64
	qte.target.add_theme_stylebox_override("panel", qte.target_style)
	qte.add_child(qte.target)

	qte.ring = Panel.new()
	qte.ring.name = "ShrinkingRing"
	qte.ring.size = Vector2(qte.start_size, qte.start_size)
	qte.ring.position = center - qte.ring.size * 0.5
	qte.ring_style = StyleBoxFlat.new()
	qte.ring_style.bg_color = Color(0, 0, 0, 0)
	qte.ring_style.border_width_left = 10
	qte.ring_style.border_width_top = 10
	qte.ring_style.border_width_right = 10
	qte.ring_style.border_width_bottom = 10
	qte.ring_style.border_color = theme.get("secondary", Color.WHITE)
	qte.ring_style.corner_radius_top_left = 140
	qte.ring_style.corner_radius_top_right = 140
	qte.ring_style.corner_radius_bottom_left = 140
	qte.ring_style.corner_radius_bottom_right = 140
	qte.ring.add_theme_stylebox_override("panel", qte.ring_style)
	qte.add_child(qte.ring)

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
		_fail_qte("FAILED")
		return

	var t := timer / sweep_duration
	var current_size := lerpf(start_size, end_size, t)
	ring.size = Vector2(current_size, current_size)
	var center := bf.get_viewport_rect().size * 0.5 + Vector2(0, 20)
	ring.position = center - ring.size * 0.5

	if Input.is_action_just_pressed("ui_accept"):
		var diff := absf(ring.size.x - target.size.x)
		is_done = true
		end_hold_timer = 0.36
		if diff <= 12.0:
			result = 2
			help_lbl.text = "PERFECT ALIGNMENT"
			help_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			ring_style.border_color = Color.WHITE
			target_style.border_color = Color.WHITE
			if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(16.0, 0.22)
		elif diff <= 30.0:
			result = 1
			help_lbl.text = "GOOD ALIGNMENT"
			help_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.35))
			if bf.get("select_sound") and bf.select_sound.stream != null: 
				bf.select_sound.pitch_scale = 1.2
				bf.select_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(8.0, 0.12)
		else:
			_fail_qte("MISS")

func _fail_qte(reason: String) -> void:
	result = 0
	is_done = true
	end_hold_timer = 0.36
	help_lbl.text = reason
	help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
