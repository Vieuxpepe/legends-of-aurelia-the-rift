extends CanvasLayer
class_name QTEPingPongBar

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0
var ping_pong_speed: float = 2.4

var help_lbl: Label
var val_label: Label
var bar_bg: ColorRect
var fill: ColorRect

var charging: bool = false
var wait_timer: float = 0.0
var wait_timeout: float = 2.0
var charge_timer: float = 0.0
var charge_timeout: float = 2.4

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	speed: float
) -> QTEPingPongBar:
	var qte = QTEPingPongBar.new()
	qte.bf = parent_bf
	qte.ping_pong_speed = speed
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.12, 0.10, 0.05, 0.76)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 75)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.text = help_text
	qte.help_lbl.position = Vector2(0, 120)
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
	qte.bar_bg.size = Vector2(560, 40)
	qte.bar_bg.position = Vector2((vp.x - 560.0) * 0.5, vp.y * 0.5 - 20.0)
	qte.bar_bg.color = Color(0.08, 0.08, 0.08, 0.96)
	qte.add_child(qte.bar_bg)

	qte.fill = ColorRect.new()
	qte.fill.size = Vector2(0, 40)
	qte.fill.color = Color(1.0, 0.85, 0.3, 1.0)
	qte.bar_bg.add_child(qte.fill)

	var hundred_line := ColorRect.new()
	hundred_line.size = Vector2(6, 40)
	hundred_line.position = Vector2(qte.bar_bg.size.x - 6, 0)
	hundred_line.color = Color.WHITE
	qte.bar_bg.add_child(hundred_line)

	qte.val_label = Label.new()
	qte.val_label.text = "0%"
	qte.val_label.position = Vector2(0, qte.bar_bg.position.y + 50)
	qte.val_label.size = Vector2(vp.x, 40)
	qte.val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.val_label.add_theme_font_size_override("font_size", 34)
	qte.val_label.add_theme_color_override("font_color", Color.WHITE)
	qte.val_label.add_theme_constant_override("outline_size", 8)
	qte.val_label.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.val_label)
	
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
		
	if not charging:
		wait_timer += delta
		if wait_timer > wait_timeout:
			_fail_qte("TOO SLOW")
			return
		if Input.is_action_just_pressed("ui_accept"):
			charging = true
	else:
		charge_timer += delta
		if charge_timer >= charge_timeout:
			_fail_qte("LOST FOCUS")
			return
			
		var progress := absf(sin(charge_timer * ping_pong_speed))
		fill.size.x = progress * bar_bg.size.x
		val_label.text = str(int(progress * 100.0)) + "%"

		if Input.is_action_just_released("ui_accept"):
			var final_val := int(progress * 100.0)
			is_done = true
			end_hold_timer = 0.36
			
			if final_val >= 95:
				result = 2
				help_lbl.text = "ABSOLUTE JUDGMENT"
				help_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
				if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
				if bf.has_method("screen_shake"): bf.screen_shake(16.0, 0.22)
			elif final_val >= 60:
				result = 1
				help_lbl.text = "GOOD JUDGMENT"
				help_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
				if bf.get("select_sound") and bf.select_sound.stream != null: 
					bf.select_sound.pitch_scale = 1.15
					bf.select_sound.play()
				if bf.has_method("screen_shake"): bf.screen_shake(8.0, 0.12)
			else:
				_fail_qte("WEAK")

func _fail_qte(reason: String) -> void:
	result = 0
	is_done = true
	end_hold_timer = 0.36
	help_lbl.text = reason
	help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
