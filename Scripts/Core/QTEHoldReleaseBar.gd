extends CanvasLayer
class_name QTEHoldReleaseBar

signal qte_finished(result: int)

var bf: Node2D
var fill_duration: float
var timer: float = 0.0
var wait_timer: float = 0.0
var result: int = 0
var is_done: bool = false
var end_hold_timer: float = -1.0
var started_charging: bool = false

var help_lbl: Label
var fill: ColorRect
var outer_good: ColorRect
var perfect_zone: ColorRect

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	fill_ms: int
) -> QTEHoldReleaseBar:
	var qte = QTEHoldReleaseBar.new()
	qte.bf = parent_bf
	qte.fill_duration = fill_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.12, 0.05, 0.02, 0.68)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.text = help_text
	qte.help_lbl.position = Vector2(0, 125)
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
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.96)
	bar_bg.size = Vector2(520, 34)
	bar_bg.position = Vector2((vp.x - bar_bg.size.x) * 0.5, vp.y * 0.5 - 10.0)
	qte.add_child(bar_bg)

	qte.outer_good = ColorRect.new()
	qte.outer_good.color = Color(0.25, 0.9, 0.25, 0.95)
	qte.outer_good.size = Vector2(40, 34)
	qte.outer_good.position = Vector2(410, 0)
	bar_bg.add_child(qte.outer_good)

	qte.perfect_zone = ColorRect.new()
	qte.perfect_zone.color = Color(1.0, 0.86, 0.2, 0.98)
	qte.perfect_zone.size = Vector2(14, 34)
	qte.perfect_zone.position = Vector2((qte.outer_good.size.x - qte.perfect_zone.size.x) * 0.5, 0)
	qte.outer_good.add_child(qte.perfect_zone)

	qte.fill = ColorRect.new()
	qte.fill.color = Color(1.0, 0.74, 0.25, 1.0)
	qte.fill.size = Vector2(0, 34)
	bar_bg.add_child(qte.fill)
	
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
		
	if not started_charging:
		wait_timer += delta
		if Input.is_action_pressed("ui_accept"):
			started_charging = true
		elif wait_timer > 2.0:
			_finish_qte(0)
		return

	timer += delta
	var t := clampf(timer / fill_duration, 0.0, 1.0)
	var bar_w = 520.0
	fill.size.x = t * bar_w
	
	if Input.is_action_just_released("ui_accept") or t >= 1.0:
		var fill_end := fill.size.x
		var good_start := outer_good.position.x
		var good_end := good_start + outer_good.size.x
		var perfect_start := good_start + perfect_zone.position.x
		var perfect_end := perfect_start + perfect_zone.size.x

		if fill_end >= perfect_start and fill_end <= perfect_end:
			_finish_qte(2)
		elif fill_end >= good_start and fill_end <= good_end:
			_finish_qte(1)
		else:
			_finish_qte(0)

func _finish_qte(res: int) -> void:
	result = res
	is_done = true
	end_hold_timer = 0.35
	
	if result == 2:
		help_lbl.text = "PERFECT SHOUT"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.20))
		fill.color = Color(1.0, 0.85, 0.20)
		if bf.get("crit_sound") and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		if bf.has_method("screen_shake"):
			bf.screen_shake(15.0, 0.22)
	elif result == 1:
		help_lbl.text = "GOOD SHOUT"
		help_lbl.add_theme_color_override("font_color", Color(0.30, 1.0, 0.35))
		if bf.get("select_sound") and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.25
			bf.select_sound.play()
		if bf.has_method("screen_shake"):
			bf.screen_shake(8.0, 0.12)
	else:
		help_lbl.text = "FAILED"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
		fill.color = Color(0.90, 0.20, 0.20)
		if bf.get("miss_sound") and bf.miss_sound.stream != null:
			bf.miss_sound.play()
