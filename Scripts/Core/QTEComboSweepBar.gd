extends CanvasLayer
class_name QTEComboSweepBar

signal qte_finished(hits: int)

var bf: Node2D
var sweep_duration: float
var timer: float = 0.0
var is_done: bool = false
var end_hold_timer: float = -1.0

var active_zone: int = 0
var hits: int = 0
var broken: bool = false

var help_lbl: Label
var cursor: ColorRect
var target_rects: Array[ColorRect] = []
var target_positions: Array[float] = []
var zone_width: float = 30.0
var bar_w: float = 420.0

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	positions: Array,
	duration_ms: int,
	theme: Dictionary = {}
) -> QTEComboSweepBar:
	var qte = QTEComboSweepBar.new()
	qte.bf = parent_bf
	qte.sweep_duration = duration_ms / 1000.0
	for p in positions:
		qte.target_positions.append(float(p))
	
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

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.04, 0.04, 0.05, 0.95)
	bar_bg.size = Vector2(qte.bar_w, 36)
	bar_bg.position = Vector2((vp.x - qte.bar_w) * 0.5, vp.y * 0.5 - 10)
	qte.add_child(bar_bg)

	for pos in qte.target_positions:
		var tz := ColorRect.new()
		tz.size = Vector2(qte.zone_width, 36)
		tz.position = Vector2(pos, 0)
		tz.color = Color(accent.r * 0.6, accent.g * 0.2, accent.b * 0.2, 0.75)
		bar_bg.add_child(tz)
		qte.target_rects.append(tz)

	qte.cursor = ColorRect.new()
	qte.cursor.size = Vector2(8, 60)
	qte.cursor.position = Vector2(0, -12)
	qte.cursor.color = secondary
	bar_bg.add_child(qte.cursor)
	
	if parent_bf.has_node("/root/QTEManager"):
		parent_bf.get_node("/root/QTEManager")._decorate_qte_indicator(qte.cursor, theme)
	
	parent_bf.get_tree().paused = true
	Input.flush_buffered_events()
	
	return qte

func _process(delta: float) -> void:
	if is_done:
		end_hold_timer -= delta
		if end_hold_timer <= 0.0:
			bf.get_tree().paused = false
			qte_finished.emit(hits)
			queue_free()
		return
		
	timer += delta
	var progress := timer / sweep_duration
	cursor.position.x = progress * bar_w
	
	if timer >= sweep_duration:
		_finish_qte()
		return
		
	if not broken and active_zone < target_positions.size():
		var current_tz = target_rects[active_zone]
		var c_center = cursor.position.x + (cursor.size.x * 0.5)
		var tz_start = current_tz.position.x
		var tz_end = tz_start + current_tz.size.x
		
		# Missed passed zone
		if c_center > tz_end + 5.0:
			_break_combo()
		elif Input.is_action_just_pressed("ui_accept"):
			if c_center >= tz_start - 8.0 and c_center <= tz_end + 8.0:
				hits += 1
				active_zone += 1
				current_tz.color = Color(1.0, 0.1, 0.1, 1.0)
				if bf.has_method("screen_shake"): bf.screen_shake(12.0, 0.15)
				var clang = bf.get_node_or_null("ClangSound") if bf else null
				if clang and clang.stream:
					clang.pitch_scale = 0.8 + (hits * 0.25)
					clang.play()
			else:
				_break_combo()

func _break_combo() -> void:
	broken = true
	cursor.color = Color(0.4, 0.4, 0.4)
	if active_zone < target_rects.size():
		target_rects[active_zone].color = Color(0.2, 0.0, 0.0, 0.8)
	help_lbl.text = "COMBO DROPPED!"
	help_lbl.add_theme_color_override("font_color", Color.GRAY)
	if bf.get("miss_sound") and bf.miss_sound.stream != null:
		bf.miss_sound.play()
	if bf.has_method("screen_shake"): bf.screen_shake(8.0, 0.2)

func _finish_qte() -> void:
	is_done = true
	end_hold_timer = 0.45
	
	if hits == target_positions.size():
		help_lbl.text = "MAXIMUM BLOODSHED!"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
		if bf.has_method("screen_shake"): bf.screen_shake(20.0, 0.4)
		if bf.get("crit_sound") and bf.crit_sound.stream != null:
			if bf.has_method("play_attack_hit_sound"):
				bf.play_attack_hit_sound(bf.crit_sound)
			else:
				bf.crit_sound.play()
	elif hits > 0 and not broken:
		# If somehow timer ran out exactly after last hit, treat as whatever current hits are.
		pass
