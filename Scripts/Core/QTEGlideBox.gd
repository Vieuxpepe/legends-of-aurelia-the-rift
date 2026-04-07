extends CanvasLayer
class_name QTEGlideBox

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var total_duration: float = 2.5
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var target_box: ColorRect
var cursor: ColorRect
var heat_fill: ColorRect
var heat: float = 0.0
var cursor_y: float = 280.0
var gravity: float = 220.0
var fly_power: float = -280.0

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	theme: Dictionary = {}
) -> QTEGlideBox:
	var qte = QTEGlideBox.new()
	qte.bf = parent_bf
	qte.layer = 220
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
	
	var bg := ColorRect.new(); bg.size = Vector2(40,300); bg.position = vp*0.5 - Vector2(20, 150); bg.color = Color(0.05,0.05,0.06,0.96); qte.add_child(bg)
	qte.target_box = ColorRect.new(); qte.target_box.size = Vector2(40, 80); qte.target_box.position = Vector2(0, 110); qte.target_box.color = Color(accent.r, accent.g, accent.b, 0.45); bg.add_child(qte.target_box)
	qte.cursor = ColorRect.new(); qte.cursor.size = Vector2(30,12); qte.cursor.position = Vector2(5,280); qte.cursor.color = secondary; bg.add_child(qte.cursor)
	
	if parent_bf.has_node("/root/QTEManager"):
		var mgr = parent_bf.get_node("/root/QTEManager")
		mgr._decorate_qte_indicator(qte.cursor, theme)
		mgr._decorate_qte_indicator(qte.target_box, theme)
	
	var hbg := ColorRect.new(); hbg.size = Vector2(300, 20); hbg.position = Vector2((vp.x-300)*0.5, bg.position.y + 330); hbg.color = Color(0.05,0.05,0.06,0.92); qte.add_child(hbg)
	qte.heat_fill = ColorRect.new(); qte.heat_fill.size = Vector2(0,20); qte.heat_fill.color = accent; hbg.add_child(qte.heat_fill)
	
	parent_bf.get_tree().paused = true; Input.flush_buffered_events(); return qte

func _process(delta: float) -> void:
	if is_done:
		end_hold_timer -= delta
		if end_hold_timer <= 0: bf.get_tree().paused = false; qte_finished.emit(result); queue_free()
		return
	
	timer += delta
	if timer >= total_duration: _resolve()
	
	target_box.position.y = 110.0 + sin(timer * 3.5) * 90.0
	if Input.is_action_pressed("ui_accept"): cursor_y += fly_power * delta
	else: cursor_y += gravity * delta
	cursor_y = clampf(cursor_y, 0, 290); cursor.position.y = cursor_y
	
	var mid := cursor_y + 5.0
	if mid >= target_box.position.y and mid <= target_box.position.y + 80.0:
		heat += 65.0 * delta; cursor.color = Color(1, 0.8, 0.2)
	else: heat -= 25.0 * delta; cursor.color = Color.WHITE
	heat = clampf(heat, 0, 100); heat_fill.size.x = (heat/100.0) * 300.0

func _resolve():
	is_done = true; end_hold_timer = 0.4
	if heat >= 85: result = 2; help_lbl.text = "MAXIMUM IGNITION!"; help_lbl.add_theme_color_override("font_color", Color(1,0.5,0.1)); bf.screen_shake(14, 0.2); if bf.get("crit_sound") and bf.crit_sound.stream: bf.crit_sound.play()
	elif heat >= 40: result = 1; help_lbl.text = "BLADE IGNITED"; help_lbl.add_theme_color_override("font_color", Color(1,0.8,0.3)); bf.screen_shake(6, 0.1); if bf.get("select_sound") and bf.select_sound.stream: bf.select_sound.play()
	else: result = 0; help_lbl.text = "FIZZLED"; help_lbl.add_theme_color_override("font_color", Color(0.6,0.6,0.6)); if bf.get("miss_sound") and bf.miss_sound.stream: bf.miss_sound.play()\n