extends CanvasLayer
class_name QTEReactionFlash

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var wait_limit: float = 0.0
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0
var phase := 0 # 0=Wait, 1=Flash

var help_lbl: Label
var dimmer: ColorRect
var flash_time: float = 0.0

static func run(parent_bf: Node2D, title_text: String, help_text: String) -> QTEReactionFlash:
	var qte = QTEReactionFlash.new()
	qte.bf = parent_bf; qte.layer = 220; qte.process_mode = Node.PROCESS_MODE_ALWAYS; parent_bf.add_child(qte)
	var vp := parent_bf.get_viewport_rect().size
	qte.dimmer = ColorRect.new(); qte.dimmer.size = vp; qte.dimmer.color = Color(0, 0, 0, 0.95); qte.add_child(qte.dimmer)
	
	qte.help_lbl = Label.new(); qte.help_lbl.text = help_text; qte.help_lbl.position = vp*0.5 - Vector2(vp.x*0.5, 20); qte.help_lbl.size = Vector2(vp.x, 40); qte.help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.help_lbl.add_theme_font_size_override("font_size", 28); qte.help_lbl.add_theme_color_override("font_color", Color(0.6,0.6,0.7)); qte.add_child(qte.help_lbl)
	
	if parent_bf.has_node("/root/QTEManager"):
		var mgr = parent_bf.get_node("/root/QTEManager"); mgr._apply_qte_visual_overhaul(qte, null, qte.help_lbl)
	
	qte.wait_limit = randf_range(1.2, 3.2); parent_bf.get_tree().paused = true; Input.flush_buffered_events(); return qte

func _process(delta: float) -> void:
	if is_done:
		end_hold_timer -= delta
		if end_hold_timer <= 0: bf.get_tree().paused = false; qte_finished.emit(result); queue_free()
		return
	
	timer += delta
	if phase == 0:
		if timer >= wait_limit: phase = 1; timer = 0.0; dimmer.color = Color(0.8, 0.2, 1, 0.8); help_lbl.text = "NOW!"; help_lbl.add_theme_color_override("font_color", Color.WHITE); help_lbl.add_theme_font_size_override("font_size", 50); if bf.get("select_sound") and bf.select_sound.stream: bf.select_sound.pitch_scale = 1.5; bf.select_sound.play()
		elif Input.is_action_just_pressed("ui_accept"): _resolve(0, "FALSE START!")
	else:
		if timer > 0.6: _resolve(0, "TOO SLOW!")
		elif Input.is_action_just_pressed("ui_accept"):
			var ms := int(timer * 1000)
			if timer <= 0.28: _resolve(2, "PERFECT REFLEX! (" + str(ms) + "ms)")
			else: _resolve(1, "GOOD BLINK (" + str(ms) + "ms)")

func _resolve(res: int, msg: String):
	result = res; is_done = true; end_hold_timer = 0.8; help_lbl.text = msg
	if res == 2: help_lbl.add_theme_color_override("font_color", Color(1,0.85,0.2)); bf.screen_shake(12, 0.15); if bf.get("crit_sound") and bf.crit_sound.stream: bf.crit_sound.play()
	elif res == 1: help_lbl.add_theme_color_override("font_color", Color(0.4, 1, 0.4)); bf.screen_shake(6, 0.1); if bf.get("select_sound") and bf.select_sound.stream: bf.select_sound.pitch_scale = 1.8; bf.select_sound.play()
	else: help_lbl.add_theme_color_override("font_color", Color(1,0.3,0.3)); dimmer.color = Color(0,0,0,0.95); if bf.get("miss_sound") and bf.miss_sound.stream: bf.miss_sound.play()\n