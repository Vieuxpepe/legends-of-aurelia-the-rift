extends CanvasLayer
class_name QTECrosshairPin

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var total_duration: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var arena: ColorRect
var target: ColorRect
var cursor_h: ColorRect
var cursor_v: ColorRect
var status: Label

var cursor_pos: Vector2
var cursor_speed: float = 280.0
var target_pos: Vector2
var target_vel: Vector2
var retarget_timer: float = 0.420

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int,
	theme: Dictionary = {}
) -> QTECrosshairPin:
	var qte = QTECrosshairPin.new()
	qte.bf = parent_bf
	qte.total_duration = duration_ms / 1000.0
	
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

	qte.arena = ColorRect.new()
	qte.arena.name = "Arena"
	qte.arena.size = Vector2(560, 320)
	qte.arena.position = vp * 0.5 - Vector2(280, 160)
	qte.arena.color = Color(0.02, 0.02, 0.03, 0.95)
	qte.add_child(qte.arena)

	qte.target = ColorRect.new()
	qte.target.name = "Target"
	qte.target.size = Vector2(28, 28)
	qte.target.color = Color(1.0, 0.2, 0.2, 0.8)
	qte.arena.add_child(qte.target)

	qte.cursor_h = ColorRect.new()
	qte.cursor_h.name = "CursorH"
	qte.cursor_h.size = Vector2(40, 4)
	qte.cursor_h.color = Color.WHITE
	qte.arena.add_child(qte.cursor_h)

	qte.cursor_v = ColorRect.new()
	qte.cursor_v.name = "CursorV"
	qte.cursor_v.size = Vector2(4, 40)
	qte.cursor_v.color = Color.WHITE
	qte.arena.add_child(qte.cursor_v)

	qte.status = Label.new()
	qte.status.name = "Status"
	qte.status.text = "TIME: " + str(qte.total_duration)
	qte.status.position = Vector2(0, qte.arena.position.y + qte.arena.size.y + 10.0)
	qte.status.size = Vector2(vp.x, 30)
	qte.status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.status.add_theme_font_size_override("font_size", 22)
	qte.status.add_theme_color_override("font_color", secondary)
	qte.status.add_theme_constant_override("outline_size", 5)
	qte.status.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.status)

	qte.cursor_pos = qte.arena.size * 0.5
	qte.target_pos = Vector2(
		randf_range(40.0, qte.arena.size.x - 40.0),
		randf_range(40.0, qte.arena.size.y - 40.0)
	)
	qte.target_vel = Vector2(
		randf_range(-180.0, 180.0),
		randf_range(-180.0, 180.0)
	)

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
	status.text = "TIME: %0.2f" % maxf(0.0, total_duration - timer)
	if timer >= total_duration:
		_fail_qte("TOO LATE")
		return

	var move_dir := Vector2.ZERO
	if Input.is_action_pressed("ui_left"): move_dir.x -= 1.0
	if Input.is_action_pressed("ui_right"): move_dir.x += 1.0
	if Input.is_action_pressed("ui_up"): move_dir.y -= 1.0
	if Input.is_action_pressed("ui_down"): move_dir.y += 1.0

	if move_dir.length() > 0.0:
		move_dir = move_dir.normalized()

	cursor_pos += move_dir * cursor_speed * delta
	cursor_pos.x = clampf(cursor_pos.x, 12.0, arena.size.x - 12.0)
	cursor_pos.y = clampf(cursor_pos.y, 12.0, arena.size.y - 12.0)

	retarget_timer -= delta
	if retarget_timer <= 0.0:
		target_vel = target_vel.normalized() * randf_range(140.0, 230.0)
		target_vel = target_vel.rotated(randf_range(-0.75, 0.75))
		retarget_timer = randf_range(0.28, 0.52)

	target_pos += target_vel * delta

	if target_pos.x <= 9.0 or target_pos.x >= arena.size.x - 9.0:
		target_vel.x *= -1.0
		target_pos.x = clampf(target_pos.x, 9.0, arena.size.x - 9.0)
	if target_pos.y <= 9.0 or target_pos.y >= arena.size.y - 9.0:
		target_vel.y *= -1.0
		target_pos.y = clampf(target_pos.y, 9.0, arena.size.y - 9.0)

	target.position = target_pos - target.size * 0.5
	cursor_h.position = cursor_pos - cursor_h.size * 0.5
	cursor_v.position = cursor_pos - cursor_v.size * 0.5

	if Input.is_action_just_pressed("ui_accept"):
		is_done = true
		end_hold_timer = 0.40
		
		var dist := cursor_pos.distance_to(target_pos)

		if dist <= 18.0:
			result = 2
			help_lbl.text = "PERFECT PIN"
			help_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(16.0, 0.22)
		elif dist <= 45.0:
			result = 1
			help_lbl.text = "GLANCING PIN"
			help_lbl.add_theme_color_override("font_color", Color(0.75, 0.55, 1.0))
			if bf.get("select_sound") and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.15
				bf.select_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(6.0, 0.1)
		else:
			_fail_qte("MISSED")

func _fail_qte(reason: String) -> void:
	result = 0
	is_done = true
	end_hold_timer = 0.40
	help_lbl.text = reason
	help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
