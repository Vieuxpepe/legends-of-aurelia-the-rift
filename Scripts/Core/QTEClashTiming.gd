extends CanvasLayer
class_name QTEClashTiming

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var sweep_duration: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var track: ColorRect
var left_block: ColorRect
var right_block: ColorRect

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int
) -> QTEClashTiming:
	var qte = QTEClashTiming.new()
	qte.bf = parent_bf
	qte.sweep_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.05, 0.06, 0.08, 0.86)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.text = help_text
	qte.help_lbl.position = Vector2(0, 125)
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

	qte.track = ColorRect.new()
	qte.track.size = Vector2(620, 120)
	qte.track.position = Vector2((vp.x - 620) * 0.5, (vp.y - 120) * 0.5 - 10)
	qte.track.color = Color(0.10, 0.10, 0.10, 0.96)
	qte.add_child(qte.track)

	var center_line := ColorRect.new()
	center_line.size = Vector2(6, 120)
	center_line.position = Vector2((620 - 6) * 0.5, 0)
	center_line.color = Color.WHITE
	qte.track.add_child(center_line)

	qte.left_block = ColorRect.new()
	qte.left_block.size = Vector2(110, 120)
	qte.left_block.color = Color(0.55, 0.60, 0.68, 1.0)
	qte.track.add_child(qte.left_block)

	qte.right_block = ColorRect.new()
	qte.right_block.size = Vector2(110, 120)
	qte.right_block.color = Color(0.55, 0.60, 0.68, 1.0)
	qte.track.add_child(qte.right_block)

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
		_fail_qte("MISSED THE CLASH")
		return

	var t := timer / sweep_duration
	left_block.position.x = lerpf(-110.0, 310.0 - 110.0, t)
	right_block.position.x = lerpf(620.0, 310.0, t)

	if Input.is_action_just_pressed("ui_accept"):
		is_done = true
		end_hold_timer = 0.36
		var gap := absf((left_block.position.x + 110.0) - right_block.position.x)
		
		if gap <= 10.0:
			result = 2
			help_lbl.text = "SHATTERED"
			help_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			left_block.color = Color.WHITE
			right_block.color = Color.WHITE
			if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(18.0, 0.24)
		else:
			_fail_qte("FAILED")

func _fail_qte(reason: String) -> void:
	result = 0
	is_done = true
	end_hold_timer = 0.36
	help_lbl.text = reason
	help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
