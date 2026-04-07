extends CanvasLayer
class_name QTEAlternatingMashMeter

signal qte_finished(result: int)

var bf: Node2D
var sweep_duration: float
var timer: float = 0.0
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var bar_bg: ColorRect
var fill: ColorRect

var meter: float = 18.0
var expect_up: bool = true

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int,
	theme: Dictionary = {}
) -> QTEAlternatingMashMeter:
	var qte = QTEAlternatingMashMeter.new()
	qte.bf = parent_bf
	qte.sweep_duration = duration_ms / 1000.0
	
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

	qte.bar_bg = ColorRect.new()
	qte.bar_bg.name = "BarBackground"
	qte.bar_bg.color = Color(0.02, 0.02, 0.03, 0.95)
	qte.bar_bg.size = Vector2(520, 32)
	qte.bar_bg.position = Vector2((vp.x - 520) * 0.5, (vp.y - 32) * 0.5 - 16)
	qte.add_child(qte.bar_bg)

	qte.fill = ColorRect.new()
	qte.fill.name = "Fill"
	qte.fill.size = Vector2(0, 32)
	qte.fill.color = accent
	qte.bar_bg.add_child(qte.fill)

	var good_line := ColorRect.new()
	good_line.name = "GoodThreshold"
	good_line.size = Vector2(4, 48)
	good_line.position = Vector2(520.0 * 0.66, -8)
	good_line.color = Color(accent.r * 0.8, accent.g, accent.b * 0.8, 0.8)
	qte.bar_bg.add_child(good_line)

	var perfect_line := ColorRect.new()
	perfect_line.name = "PerfectThreshold"
	perfect_line.size = Vector2(4, 48)
	perfect_line.position = Vector2(520.0 * 0.90, -8)
	perfect_line.color = secondary
	qte.bar_bg.add_child(perfect_line)
	
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

	meter -= 35.0 * delta
	meter = clampf(meter, 0.0, 100.0)

	if Input.is_action_just_pressed("ui_up"):
		if expect_up:
			meter += 9.0
			expect_up = false
			_play_tick()
		else:
			meter -= 5.0
	elif Input.is_action_just_pressed("ui_down"):
		if not expect_up:
			meter += 9.0
			expect_up = true
			_play_tick()
		else:
			meter -= 5.0
			
	meter = clampf(meter, 0.0, 100.0)
	fill.size.x = (meter / 100.0) * bar_bg.size.x

func _play_tick() -> void:
	if bf.get("select_sound") and bf.select_sound.stream != null:
		bf.select_sound.pitch_scale = min(1.0 + (meter / 100.0) * 0.8, 1.8)
		bf.select_sound.play()

func _finish_qte() -> void:
	is_done = true
	end_hold_timer = 0.40
	
	if meter >= 90.0:
		result = 2
		help_lbl.text = "PERFECT SHIFT"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(12.0, 0.18)
	elif meter >= 66.0:
		result = 1
		help_lbl.text = "PHASED"
		help_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		if bf.get("select_sound") and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.16
			bf.select_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(6.0, 0.10)
	else:
		result = 0
		help_lbl.text = "FAILED"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.get("miss_sound") and bf.miss_sound.stream != null:
			bf.miss_sound.play()
