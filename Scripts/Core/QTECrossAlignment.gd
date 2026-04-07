extends CanvasLayer
class_name QTECrossAlignment

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var h_cursor: ColorRect
var v_cursor: ColorRect
var h_bar: ColorRect
var v_bar: ColorRect

var h_locked := false
var v_locked := false
var h_pos := 0.0
var v_pos := 0.0

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	theme: Dictionary = {}
) -> QTECrossAlignment:
	var qte = QTECrossAlignment.new()
	qte.bf = parent_bf
	qte.layer = 240
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

	var center := vp * 0.5 + Vector2(0, 18)
	qte.h_bar = ColorRect.new(); qte.h_bar.size = Vector2(520, 28); qte.h_bar.position = Vector2(center.x-260, center.y-14); qte.h_bar.color = Color(0.04, 0.04, 0.05, 0.96); qte.add_child(qte.h_bar)
	qte.v_bar = ColorRect.new(); qte.v_bar.size = Vector2(28, 320); qte.v_bar.position = Vector2(center.x-14, center.y-160); qte.v_bar.color = Color(0.04, 0.04, 0.05, 0.96); qte.add_child(qte.v_bar)
	
	var hc := ColorRect.new(); hc.size = Vector2(4, 28); hc.position = Vector2(258, 0); hc.color = accent.lerp(Color.WHITE, 0.5); qte.h_bar.add_child(hc)
	var vc := ColorRect.new(); vc.size = Vector2(28, 4); vc.position = Vector2(0, 158); vc.color = accent.lerp(Color.WHITE, 0.5); qte.v_bar.add_child(vc)

	qte.h_cursor = ColorRect.new(); qte.h_cursor.size = Vector2(10, 40); qte.h_cursor.position = Vector2(0,-6); qte.h_cursor.color = secondary; qte.h_bar.add_child(qte.h_cursor)
	qte.v_cursor = ColorRect.new(); qte.v_cursor.size = Vector2(40, 10); qte.v_cursor.position = Vector2(-6,0); qte.v_cursor.color = secondary; qte.v_bar.add_child(qte.v_cursor)
	
	if parent_bf.has_node("/root/QTEManager"):
		var mgr = parent_bf.get_node("/root/QTEManager")
		mgr._decorate_qte_indicator(qte.h_cursor, theme)
		mgr._decorate_qte_indicator(qte.v_cursor, theme)

	parent_bf.get_tree().paused = true; Input.flush_buffered_events(); return qte

func _process(delta: float) -> void:
	if is_done:
		end_hold_timer -= delta
		if end_hold_timer <= 0.0:
			bf.get_tree().paused = false; qte_finished.emit(result); queue_free()
		return
		
	timer += delta
	if not h_locked:
		h_pos = (sin(timer * 4.5) * 0.5 + 0.5) * h_bar.size.x
		h_cursor.position.x = h_pos - 5
		if Input.is_action_just_pressed("ui_accept"):
			h_locked = true; h_cursor.color = Color.WHITE
			if bf.get("select_sound") and bf.select_sound.stream != null: bf.select_sound.play()
	elif not v_locked:
		v_pos = (sin(timer * 5.5) * 0.5 + 0.5) * v_bar.size.y
		v_cursor.position.y = v_pos - 5
		if Input.is_action_just_pressed("ui_accept"):
			v_locked = true; v_cursor.color = Color.WHITE
			_evaluate()
	
	if timer > 6.0: _evaluate()

func _evaluate() -> void:
	if is_done: return
	is_done = true; end_hold_timer = 0.40
	var h_diff := absf(h_pos - h_bar.size.x * 0.5)
	var v_diff := absf(v_pos - v_bar.size.y * 0.5)
	
	if h_diff <= 14.0 and v_diff <= 14.0:
		result = 2; help_lbl.text = "PERFECT CROSS"; help_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
		bf.screen_shake(16.0, 0.25)
	elif h_diff <= 40.0 and v_diff <= 40.0:
		result = 1; help_lbl.text = "PARTIAL ALIGNMENT"; help_lbl.add_theme_color_override("font_color", Color(0.35, 1, 0.35))
		if bf.get("select_sound") and bf.select_sound.stream != null: bf.select_sound.play()
		bf.screen_shake(8.0, 0.12)
	else:
		result = 0; help_lbl.text = "MISSED"; help_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
