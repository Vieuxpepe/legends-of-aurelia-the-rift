extends CanvasLayer
class_name QTEExpandingRing

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var total_duration: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var target_ring: Panel
var core: ColorRect
var target_style: StyleBoxFlat

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int
) -> QTEExpandingRing:
	var qte = QTEExpandingRing.new()
	qte.bf = parent_bf
	qte.total_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.15, 0.05, 0.0, 0.7)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
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

	var center := vp * 0.5 + Vector2(0, 30)

	qte.target_ring = Panel.new()
	qte.target_ring.size = Vector2(240, 240)
	qte.target_ring.position = center - qte.target_ring.size * 0.5
	qte.target_style = StyleBoxFlat.new()
	qte.target_style.bg_color = Color(0, 0, 0, 0)
	qte.target_style.border_width_left = 6
	qte.target_style.border_width_top = 6
	qte.target_style.border_width_right = 6
	qte.target_style.border_width_bottom = 6
	qte.target_style.border_color = Color(1.0, 0.6, 0.2, 0.8)
	qte.target_style.corner_radius_top_left = 120
	qte.target_style.corner_radius_top_right = 120
	qte.target_style.corner_radius_bottom_left = 120
	qte.target_style.corner_radius_bottom_right = 120
	qte.target_ring.add_theme_stylebox_override("panel", qte.target_style)
	qte.add_child(qte.target_ring)

	qte.core = ColorRect.new()
	qte.core.size = Vector2(40, 40)
	qte.core.position = center - qte.core.size * 0.5
	qte.core.color = Color(1.0, 0.9, 0.5, 1.0)
	qte.add_child(qte.core)

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
		
	if Input.is_action_just_pressed("ui_accept"):
		_resolve_qte()
		return

	timer += delta
	if timer >= total_duration:
		_fail_qte("OVERCHARGED")
		return

	var progress := clampf(timer / total_duration, 0.0, 1.0)
	var current_size := lerpf(40.0, 300.0, progress)
	core.size = Vector2(current_size, current_size)
	var center := bf.get_viewport_rect().size * 0.5 + Vector2(0, 30)
	core.position = center - core.size * 0.5

	if Input.is_action_just_released("ui_accept"):
		_resolve_qte()

func _resolve_qte() -> void:
	if is_done: return
	is_done = true
	end_hold_timer = 0.40
	
	var diff := absf(core.size.x - 240.0)
	if diff <= 15.0:
		result = 2
		help_lbl.text = "PERFECT SHATTER!"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		target_style.border_color = Color.WHITE
		core.color = Color.WHITE
		if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(20.0, 0.35)
	elif diff <= 45.0:
		result = 1
		help_lbl.text = "HEAVY IMPACT"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		if bf.get("select_sound") and bf.select_sound.stream != null: 
			bf.select_sound.pitch_scale = 0.7
			bf.select_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(10.0, 0.2)
	else:
		_fail_qte("WEAK IMPACT")

func _fail_qte(reason: String) -> void:
	result = 0
	is_done = true
	end_hold_timer = 0.40
	help_lbl.text = reason
	help_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
