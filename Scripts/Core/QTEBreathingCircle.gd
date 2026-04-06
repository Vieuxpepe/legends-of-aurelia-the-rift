extends CanvasLayer
class_name QTEBreathingCircle

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var total_duration: float
var peak_timer: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var circle: Panel
var circle_style: StyleBoxFlat

var min_size: float = 60.0
var max_size: float = 280.0

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int,
	peak_ms: int
) -> QTEBreathingCircle:
	var qte = QTEBreathingCircle.new()
	qte.bf = parent_bf
	qte.total_duration = duration_ms / 1000.0
	qte.peak_timer = peak_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.08, 0.03, 0.12, 0.76)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 75)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.85, 0.65, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.text = help_text
	qte.help_lbl.position = Vector2(0, 120)
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

	qte.circle = Panel.new()
	qte.circle_style = StyleBoxFlat.new()
	qte.circle_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	qte.circle_style.border_width_left = 6
	qte.circle_style.border_width_top = 6
	qte.circle_style.border_width_right = 6
	qte.circle_style.border_width_bottom = 6
	qte.circle_style.border_color = Color(0.85, 0.65, 1.0, 1.0)
	qte.circle_style.corner_radius_top_left = 300
	qte.circle_style.corner_radius_top_right = 300
	qte.circle_style.corner_radius_bottom_left = 300
	qte.circle_style.corner_radius_bottom_right = 300
	qte.circle.add_theme_stylebox_override("panel", qte.circle_style)
	qte.add_child(qte.circle)

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
		_fail_qte("TOO LATE")
		return

	var current_size := 0.0
	if timer <= peak_timer:
		current_size = lerpf(min_size, max_size, timer / peak_timer)
	else:
		current_size = lerpf(max_size, min_size, (timer - peak_timer) / (total_duration - peak_timer))

	var center := bf.get_viewport_rect().size * 0.5 + Vector2(0, 20)
	circle.size = Vector2(current_size, current_size)
	circle.position = center - circle.size * 0.5

	if Input.is_action_just_pressed("ui_accept"):
		is_done = true
		end_hold_timer = 0.36
		var diff := absf(timer - peak_timer)
		
		if diff <= 0.035: # 35ms
			result = 2
			help_lbl.text = "PERFECT RELEASE"
			help_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
			circle_style.border_color = Color.WHITE
			if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(12.0, 0.18)
		elif diff <= 0.095: # 95ms
			result = 1
			help_lbl.text = "GOOD RELEASE"
			help_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
			if bf.get("select_sound") and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.16
				bf.select_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(6.0, 0.10)
		else:
			_fail_qte("MISTIMED")

func _fail_qte(reason: String) -> void:
	result = 0
	is_done = true
	end_hold_timer = 0.36
	help_lbl.text = reason
	help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
