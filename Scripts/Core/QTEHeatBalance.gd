extends CanvasLayer
class_name QTEHeatBalance

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var accum_time: float = 0.0
var total_duration: float = 5.0
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var bar_fill: ColorRect
var meter: float = 30.0

static func run(parent_bf: Node2D, title_text: String, help_text: String) -> QTEHeatBalance:
	var qte = QTEHeatBalance.new()
	qte.bf = parent_bf; qte.layer = 240; qte.process_mode = Node.PROCESS_MODE_ALWAYS; parent_bf.add_child(qte)
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new(); dimmer.size = vp; dimmer.color = Color(0.12, 0.02, 0.0, 0.85); qte.add_child(dimmer)

	var title := Label.new(); title.text = title_text; title.position = Vector2(0, 60); title.size = Vector2(vp.x, 42); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42); title.add_theme_color_override("font_color", Color(1, 0.3, 0.1))
	title.add_theme_constant_override("outline_size", 8); title.add_theme_color_override("font_outline_color", Color.BLACK); qte.add_child(title)

	qte.help_lbl = Label.new(); qte.help_lbl.text = help_text; qte.help_lbl.position = Vector2(0, 105); qte.help_lbl.size = Vector2(vp.x, 30); qte.help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.help_lbl.add_theme_font_size_override("font_size", 22); qte.help_lbl.add_theme_color_override("font_color", Color.WHITE)
	qte.help_lbl.add_theme_constant_override("outline_size", 6); qte.help_lbl.add_theme_color_override("font_outline_color", Color.BLACK); qte.add_child(qte.help_lbl)

	var bg := ColorRect.new(); bg.size = Vector2(40, 300); bg.position = (vp - Vector2(40,300))*0.5; bg.color = Color(0.1, 0.1, 0.1, 0.9); qte.add_child(bg)
	qte.bar_fill = ColorRect.new(); qte.bar_fill.size = Vector2(40, 0); qte.bar_fill.position = Vector2(0, 300); qte.bar_fill.color = Color(1, 0.4, 0.2); bg.add_child(qte.bar_fill)
	var zone := ColorRect.new(); zone.size = Vector2(40, 45); zone.position = Vector2(0, 0); zone.color = Color(1, 1, 1, 0.3); bg.add_child(zone)

	parent_bf.get_tree().paused = true; Input.flush_buffered_events(); return qte

func _process(delta: float) -> void:
	if is_done:
		end_hold_timer -= delta
		if end_hold_timer <= 0.0:
			bf.get_tree().paused = false; qte_finished.emit(result); queue_free()
		return
	
	timer += delta
	if timer >= total_duration: _resolve(0)
	
	meter -= 120.0 * delta
	if Input.is_action_pressed("ui_accept"): meter += 240.0 * delta
	meter = clampf(meter, 0, 100)
	bar_fill.size.y = (meter/100)*300; bar_fill.position.y = 300 - bar_fill.size.y
	
	if meter >= 85: 
		accum_time += delta
		bar_fill.color = Color(1, 1, 1)
		if accum_time >= 1.5: _resolve(2)
	else: bar_fill.color = Color(1, 0.4, 0.2)

func _resolve(res: int):
	is_done = true; end_hold_timer = 0.4
	result = res; help_lbl.text = "HELLFIRE IGNITED" if res == 2 else "EXPIRED"
	if res == 2:
		help_lbl.add_theme_color_override("font_color", Color(1,0.85,0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
	else:
		help_lbl.add_theme_color_override("font_color", Color(1,0.3,0.3))
		if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
