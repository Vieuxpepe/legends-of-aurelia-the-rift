extends CanvasLayer
class_name QTEStealthBar

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var sweep_duration: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var cursor: ColorRect
var bar_bg: ColorRect
var shadow_band: ColorRect
var perfect_zone: ColorRect

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int,
	theme: Dictionary = {}
) -> QTEStealthBar:
	var qte = QTEStealthBar.new()
	qte.bf = parent_bf
	qte.sweep_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var accent: Color = theme.get("accent", Color(0.65, 0.2, 1.0))
	var secondary: Color = theme.get("secondary", Color(0.1, 0.9, 0.95))
	var vp := parent_bf.get_viewport_rect().size
	
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.color = theme.get("bg_mod", Color(0.02, 0.01, 0.05, 0.85))
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.name = "Title"
	title.text = title_text
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 42)
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
	qte.help_lbl.size = Vector2(vp.x, 30)
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
	qte.bar_bg.size = Vector2(500, 32)
	qte.bar_bg.position = Vector2((vp.x - 500) * 0.5, vp.y * 0.5 - 16)
	qte.bar_bg.color = Color(0.02, 0.02, 0.03, 0.95)
	qte.add_child(qte.bar_bg)

	qte.shadow_band = ColorRect.new()
	qte.shadow_band.name = "ShadowBand"
	qte.shadow_band.size = Vector2(80, 32)
	qte.shadow_band.position = Vector2(randf_range(100.0, 320.0), 0)
	qte.shadow_band.color = Color(accent.r, accent.g, accent.b, 0.7)
	qte.bar_bg.add_child(qte.shadow_band)

	qte.perfect_zone = ColorRect.new()
	qte.perfect_zone.name = "PerfectZone"
	qte.perfect_zone.size = Vector2(20, 32)
	qte.perfect_zone.position = Vector2((qte.shadow_band.size.x - 20) * 0.5, 0)
	qte.perfect_zone.color = secondary
	qte.shadow_band.add_child(qte.perfect_zone)

	qte.cursor = ColorRect.new()
	qte.cursor.name = "Cursor"
	qte.cursor.size = Vector2(8, 52)
	qte.cursor.position = Vector2(0, -10)
	qte.cursor.color = Color.WHITE
	qte.bar_bg.add_child(qte.cursor)

	parent_bf.get_tree().paused = true
	Input.flush_buffered_events()
	
	return qte

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
		_fail_qte("SPOTTED!")
		return

	var t := timer / sweep_duration
	cursor.position.x = t * (bar_bg.size.x - cursor.size.x)

	if Input.is_action_just_pressed("ui_accept"):
		is_done = true
		end_hold_timer = 0.36
		
		var cursor_center := cursor.position.x + (cursor.size.x * 0.5)
		var band_start := shadow_band.position.x
		var band_end := band_start + shadow_band.size.x
		var perfect_start := band_start + perfect_zone.position.x
		var perfect_end := perfect_start + perfect_zone.size.x

		if cursor_center >= perfect_start and cursor_center <= perfect_end:
			result = 2
			help_lbl.text = "PERFECT STRIKE"
			help_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(14.0, 0.20)
		elif cursor_center >= band_start and cursor_center <= band_end:
			result = 1
			help_lbl.text = "HIDDEN STRIKE"
			help_lbl.add_theme_color_override("font_color", Color(0.6, 0.3, 0.9))
			if bf.get("select_sound") and bf.select_sound.stream != null: 
				bf.select_sound.pitch_scale = 1.2
				bf.select_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(6.0, 0.1)
		else:
			_fail_qte("DEFLECTED")

func _fail_qte(reason: String) -> void:
	result = 0
	is_done = true
	end_hold_timer = 0.36
	help_lbl.text = reason
	help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
