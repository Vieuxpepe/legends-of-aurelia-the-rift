extends CanvasLayer
class_name QTEBalanceMeter

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var sweep_duration: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var cursor: ColorRect
var cursor_velocity: float = 0.0
var cursor_x: float = 0.0
var drift_target: float = 0.0

var bar_size_x: float = 560.0
var green_width: float = 160.0
var perfect_width: float = 70.0

var next_drift_timer: float = 0.260

var in_green_timer: float = 0.0
var in_perfect_timer: float = 0.0

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int
) -> QTEBalanceMeter:
	var qte = QTEBalanceMeter.new()
	qte.bf = parent_bf
	qte.sweep_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.03, 0.08, 0.04, 0.72)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 78)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.text = help_text
	qte.help_lbl.position = Vector2(0, 122)
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

	var bar_bg := ColorRect.new()
	bar_bg.size = Vector2(qte.bar_size_x, 34)
	bar_bg.position = Vector2((vp.x - qte.bar_size_x) * 0.5, vp.y * 0.5 - 14.0)
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.96)
	qte.add_child(bar_bg)

	var green_zone := ColorRect.new()
	green_zone.size = Vector2(qte.green_width, 34)
	green_zone.position = Vector2((qte.bar_size_x - qte.green_width) * 0.5, 0)
	green_zone.color = Color(0.25, 0.9, 0.25, 0.85)
	bar_bg.add_child(green_zone)

	var perfect_zone := ColorRect.new()
	perfect_zone.size = Vector2(qte.perfect_width, 34)
	perfect_zone.position = Vector2((qte.green_width - qte.perfect_width) * 0.5, 0)
	perfect_zone.color = Color(1.0, 0.86, 0.2, 0.95)
	green_zone.add_child(perfect_zone)

	qte.cursor = ColorRect.new()
	qte.cursor.size = Vector2(12, 48)
	qte.cursor.position.y = -7
	qte.cursor.color = Color.WHITE
	bar_bg.add_child(qte.cursor)

	qte.cursor_x = qte.bar_size_x * 0.5
	qte.drift_target = randf_range(-145.0, 145.0)

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

	next_drift_timer -= delta
	if next_drift_timer <= 0.0:
		drift_target = randf_range(-145.0, 145.0)
		next_drift_timer = 0.260

	cursor_velocity = lerpf(cursor_velocity, drift_target, 0.08)

	if Input.is_action_pressed("ui_left"): cursor_velocity -= 600.0 * delta
	if Input.is_action_pressed("ui_right"): cursor_velocity += 600.0 * delta

	cursor_x += cursor_velocity * delta
	cursor_x = clampf(cursor_x, 0.0, bar_size_x - cursor.size.x)
	cursor.position.x = cursor_x

	var c_mid := cursor_x + cursor.size.x * 0.5
	var dist := absf(c_mid - bar_size_x * 0.5)

	if dist <= perfect_width * 0.5:
		in_perfect_timer += delta
		in_green_timer += delta
	elif dist <= green_width * 0.5:
		in_green_timer += delta

func _finish_qte() -> void:
	is_done = true
	end_hold_timer = 0.40
	
	var in_green_ratio := in_green_timer / sweep_duration
	var in_perfect_ratio := in_perfect_timer / sweep_duration

	if in_perfect_ratio >= 0.70:
		result = 2
		help_lbl.text = "PERFECT HARMONY"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(12.0, 0.18)
	elif in_green_ratio >= 0.60:
		result = 1
		help_lbl.text = "FOCUSED"
		help_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		if bf.get("select_sound") and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.15
			bf.select_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(6.0, 0.10)
	else:
		result = 0
		help_lbl.text = "BALANCE LOST"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
