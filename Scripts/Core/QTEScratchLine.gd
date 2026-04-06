extends CanvasLayer
class_name QTEScratchLine

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var duration: float = 0.68
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var cursor: ColorRect
var start_pos: Vector2
var end_pos: Vector2
var sweet_t: float

static func run(parent_bf: Node2D, title_text: String, help_text: String) -> QTEScratchLine:
	var qte = QTEScratchLine.new()
	qte.bf = parent_bf; qte.layer = 220; qte.process_mode = Node.PROCESS_MODE_ALWAYS; parent_bf.add_child(qte)
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new(); dimmer.size = vp; dimmer.color = Color(0.1, 0.02, 0.02, 0.78); qte.add_child(dimmer)
	
	var title := Label.new(); title.text = title_text; title.position = Vector2(0, 74); title.size = Vector2(vp.x, 42); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40); title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	title.add_theme_constant_override("outline_size", 8); title.add_theme_color_override("font_outline_color", Color.BLACK); qte.add_child(title)
	
	qte.help_lbl = Label.new(); qte.help_lbl.text = help_text; qte.help_lbl.position = Vector2(0, 118); qte.help_lbl.size = Vector2(vp.x, 30); qte.help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.help_lbl.add_theme_font_size_override("font_size", 22); qte.help_lbl.add_theme_color_override("font_color", Color.WHITE)
	qte.help_lbl.add_theme_constant_override("outline_size", 6); qte.help_lbl.add_theme_color_override("font_outline_color", Color.BLACK); qte.add_child(qte.help_lbl)
	
	if parent_bf.has_node("/root/QTEManager"):
		var mgr = parent_bf.get_node("/root/QTEManager"); mgr._apply_qte_visual_overhaul(qte, title, qte.help_lbl)
	
	var line := ColorRect.new(); line.size = Vector2(420, 8); line.position = vp*0.5 - Vector2(210,0); line.rotation_degrees = 38.0; line.color = Color(0.85,0.85,0.85,0.95); qte.add_child(line)
	qte.start_pos = vp*0.5 - Vector2(170, 135); qte.end_pos = vp*0.5 + Vector2(170, 135)
	qte.sweet_t = randf_range(0.58, 0.82); var sp := qte.start_pos.lerp(qte.end_pos, qte.sweet_t)
	var sb := ColorRect.new(); sb.size = Vector2(28,28); sb.position = sp - Vector2(14,14); sb.color = Color(1, 0.86, 0.2); qte.add_child(sb)
	qte.cursor = ColorRect.new(); qte.cursor.size = Vector2(22,22); qte.cursor.color = Color.WHITE; qte.add_child(qte.cursor)
	
	parent_bf.get_tree().paused = true; Input.flush_buffered_events(); return qte

func _process(delta: float) -> void:
	if is_done:
		end_hold_timer -= delta
		if end_hold_timer <= 0: bf.get_tree().paused = false; qte_finished.emit(result); queue_free()
		return
	
	timer += delta
	if timer >= duration: _resolve(0, "MISSED"); return
	
	var t := timer / duration; cursor.position = start_pos.lerp(end_pos, t) - Vector2(11,11)
	if Input.is_action_just_pressed("ui_accept"):
		var diff := absf(t - sweet_t)
		if diff <= 0.025: _resolve(2, "PERFECT TEAR")
		elif diff <= 0.060: _resolve(1, "GOOD TEAR")
		else: _resolve(0, "BAD ANGLE")

func _resolve(res: int, msg: String):
	result = res; is_done = true; end_hold_timer = 0.36; help_lbl.text = msg
	if res == 2: help_lbl.add_theme_color_override("font_color", Color(1,0.86,0.2)); bf.screen_shake(12, 0.18); if bf.get("crit_sound") and bf.crit_sound.stream: bf.crit_sound.play()
	elif res == 1: help_lbl.add_theme_color_override("font_color", Color(0.35,1,0.35)); cursor.color = Color(0.35,1,0.35); if bf.get("select_sound") and bf.select_sound.stream: bf.select_sound.play()
	else: help_lbl.add_theme_color_override("font_color", Color(1,0.3,0.3)); cursor.color = Color(1,0.3,0.3); if bf.get("miss_sound") and bf.miss_sound.stream: bf.miss_sound.play()\n