extends CanvasLayer
class_name QTEMultiTargetBar

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var sweep_duration: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var hits: int = 0

var help_lbl: Label
var cursor: ColorRect
var bar_bg: ColorRect

var vitals: Array[ColorRect] = []
var vital_positions: Array[float] = [100.0, 300.0, 500.0]
var vital_hit: Array[bool] = [false, false, false]

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int
) -> QTEMultiTargetBar:
	var qte = QTEMultiTargetBar.new()
	qte.bf = parent_bf
	qte.sweep_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.15, 0.02, 0.02, 0.8)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.text = help_text
	qte.help_lbl.position = Vector2(0, 130)
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

	qte.bar_bg = ColorRect.new()
	qte.bar_bg.size = Vector2(600, 20)
	qte.bar_bg.position = Vector2((vp.x - 600) * 0.5, vp.y * 0.5 - 10)
	qte.bar_bg.color = Color(0.05, 0.05, 0.05, 0.9)
	qte.add_child(qte.bar_bg)

	for pos_x in qte.vital_positions:
		var v_dot := ColorRect.new()
		v_dot.size = Vector2(16, 36)
		v_dot.position = Vector2(pos_x, -8)
		v_dot.color = Color(1.0, 0.85, 0.2)
		qte.bar_bg.add_child(v_dot)
		qte.vitals.append(v_dot)

	qte.cursor = ColorRect.new()
	qte.cursor.size = Vector2(6, 40)
	qte.cursor.position = Vector2(0, -10)
	qte.cursor.color = Color.WHITE
	qte.bar_bg.add_child(qte.cursor)

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
	if timer >= sweep_duration:
		_end_qte()
		return

	var t := timer / sweep_duration
	cursor.position.x = t * (bar_bg.size.x - cursor.size.x)

	if Input.is_action_just_pressed("ui_accept"):
		var c_center := cursor.position.x + (cursor.size.x * 0.5)
		var matched := false
		
		for i in range(3):
			if vital_hit[i]: continue
			var v_start := vital_positions[i]
			var v_end := v_start + 16.0
			
			if c_center >= v_start - 12.0 and c_center <= v_end + 12.0:
				vital_hit[i] = true
				hits += 1
				matched = true
				vitals[i].color = Color(1.0, 0.2, 0.2)
				
				if bf.get("select_sound") and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.0 + float(hits) * 0.2
					bf.select_sound.play()
				if bf.has_method("screen_shake"): bf.screen_shake(8.0, 0.1)
				break
				
		if not matched:
			if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()

func _end_qte() -> void:
	is_done = true
	end_hold_timer = 0.40
	
	if hits == 3:
		help_lbl.text = "LETHAL ASSASSINATION!"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(20.0, 0.3)
	elif hits > 0:
		help_lbl.text = str(hits) + " VITALS HIT"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	else:
		help_lbl.text = "FAILED"
		help_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
