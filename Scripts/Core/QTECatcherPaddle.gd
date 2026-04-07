extends CanvasLayer
class_name QTECatcherPaddle

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var total_duration: float = 3.0
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var paddle: ColorRect
var sparks: Array[ColorRect] = []
var spark_xs: Array[float] = []
var spark_speeds: Array[float] = []
var spark_delays: Array[float] = []
var spark_resolved: Array[bool] = []
var arena_size := Vector2(560, 340)

static func run(parent_bf: Node2D, title_text: String, help_text: String, theme: Dictionary = {}) -> QTECatcherPaddle:
	var qte = QTECatcherPaddle.new()
	qte.bf = parent_bf; qte.layer = 230; qte.process_mode = Node.PROCESS_MODE_ALWAYS; parent_bf.add_child(qte)
	
	var accent: Color = theme.get("accent", Color(0.96, 0.82, 0.32))
	var secondary: Color = theme.get("secondary", Color(1.0, 1.0, 1.0))
	var vp := parent_bf.get_viewport_rect().size
	
	var dimmer := ColorRect.new(); dimmer.size = vp; dimmer.color = theme.get("bg_mod", Color(0.04, 0.03, 0.09, 0.84)); qte.add_child(dimmer)

	var title := Label.new(); title.text = title_text; title.position = Vector2(0, 60); title.size = Vector2(vp.x, 42); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42); title.add_theme_color_override("font_color", accent)
	title.add_theme_constant_override("outline_size", 8); title.add_theme_color_override("font_outline_color", Color.BLACK); qte.add_child(title)

	qte.help_lbl = Label.new(); qte.help_lbl.text = help_text; qte.help_lbl.position = Vector2(0, 105); qte.help_lbl.size = Vector2(vp.x, 30); qte.help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.help_lbl.add_theme_font_size_override("font_size", 22); qte.help_lbl.add_theme_color_override("font_color", secondary)
	qte.help_lbl.add_theme_constant_override("outline_size", 6); qte.help_lbl.add_theme_color_override("font_outline_color", Color.BLACK); qte.add_child(qte.help_lbl)

	if parent_bf.has_node("/root/QTEManager"):
		var mgr = parent_bf.get_node("/root/QTEManager")
		if mgr.has_method("_apply_qte_visual_overhaul"):
			mgr._apply_qte_visual_overhaul(qte, title, qte.help_lbl, theme)

	var arena := ColorRect.new(); arena.size = qte.arena_size; arena.position = (vp - qte.arena_size)*0.5 - Vector2(0,10); arena.color = Color(0.02,0.02,0.03,0.96); qte.add_child(arena)
	qte.paddle = ColorRect.new(); qte.paddle.size = Vector2(96, 20); qte.paddle.position = Vector2(232, 310); qte.paddle.color = secondary; arena.add_child(qte.paddle)

	if parent_bf.has_node("/root/QTEManager"):
		parent_bf.get_node("/root/QTEManager")._decorate_qte_indicator(qte.paddle, theme)

	for i in range(5):
		var s := ColorRect.new(); s.size = Vector2(16,16); s.color = accent; s.visible = false; arena.add_child(s)
		if parent_bf.has_node("/root/QTEManager"):
			parent_bf.get_node("/root/QTEManager")._decorate_qte_indicator(s, theme)
		qte.sparks.append(s); qte.spark_xs.append(randf_range(20, 524)); qte.spark_speeds.append(randf_range(170, 240))
		qte.spark_delays.append(0.18 + i * 0.52); qte.spark_resolved.append(false)

	parent_bf.get_tree().paused = true; Input.flush_buffered_events(); return qte

func _process(delta: float) -> void:
	if is_done:
		end_hold_timer -= delta
		if end_hold_timer <= 0.0:
			bf.get_tree().paused = false; qte_finished.emit(result); queue_free()
		return
	
	timer += delta
	if timer >= total_duration: _resolve()

	var move := 0.0
	if Input.is_action_pressed("ui_left"): move -= 1.0
	if Input.is_action_pressed("ui_right"): move += 1.0
	paddle.position.x = clampf(paddle.position.x + move * 420.0 * delta, 0, 464)

	for i in range(5):
		if spark_resolved[i] or timer < spark_delays[i]: continue
		var s := sparks[i]
		s.visible = true; s.position = Vector2(spark_xs[i], -18.0 + (spark_speeds[i] * (timer - spark_delays[i])))
		if Rect2(s.position, s.size).intersects(Rect2(paddle.position, paddle.size)):
			result += 1; spark_resolved[i] = true; s.visible = false
			if bf.get("select_sound") and bf.select_sound.stream != null: bf.select_sound.play()
		elif s.position.y > 360: spark_resolved[i] = true; s.visible = false

func _resolve():
	is_done = true; end_hold_timer = 0.34
	if result >= 5:
		help_lbl.text = "PERFECT BIND"; help_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
	elif result >= 2: help_lbl.text = "SPARKS GATHERED"; help_lbl.add_theme_color_override("font_color", Color(0.35, 1, 0.35))
	else: help_lbl.text = "AETHER SLIPPED AWAY"; help_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
