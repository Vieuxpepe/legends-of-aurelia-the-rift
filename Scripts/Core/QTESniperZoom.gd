extends CanvasLayer
class_name QTESniperZoom

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var total_duration: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var target_dot: ColorRect
var cross_h: ColorRect
var cross_v: ColorRect
var status_lbl: Label

var target_pos: Vector2
var target_vel: Vector2
var cross_pos: Vector2
var cross_size: float = 76.0
var next_dir_timer: float = 0.26
var shot_fired: bool = false
var arena_size := Vector2(700, 380)

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int
) -> QTESniperZoom:
	var qte = QTESniperZoom.new()
	qte.bf = parent_bf
	qte.total_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.08, 0.08, 0.10, 0.96); dimmer.size = vp; qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text; title.position = Vector2(0, 80); title.size = Vector2(vp.x, 40); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42); title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_constant_override("outline_size", 8); title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.text = help_text; qte.help_lbl.position = Vector2(0, 130); qte.help_lbl.size = Vector2(vp.x, 30); qte.help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.help_lbl.add_theme_font_size_override("font_size", 22); qte.help_lbl.add_theme_color_override("font_color", Color.WHITE)
	qte.help_lbl.add_theme_constant_override("outline_size", 6); qte.help_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.help_lbl)

	if parent_bf.has_node("/root/QTEManager"):
		var mgr = parent_bf.get_node("/root/QTEManager")
		if mgr.has_method("_apply_qte_visual_overhaul"):
			mgr._apply_qte_visual_overhaul(qte, title, qte.help_lbl)

	var arena := ColorRect.new()
	arena.size = qte.arena_size; arena.position = (vp - qte.arena_size)*0.5 - Vector2(0,10); arena.color = Color(0.08, 0.08, 0.10, 1.0)
	qte.add_child(arena)

	qte.target_dot = ColorRect.new(); qte.target_dot.size = Vector2(10, 10); qte.target_dot.color = Color(1, 0.2, 0.2); arena.add_child(qte.target_dot)
	qte.cross_h = ColorRect.new(); qte.cross_h.color = Color.WHITE; arena.add_child(qte.cross_h)
	qte.cross_v = ColorRect.new(); qte.cross_v.color = Color.WHITE; arena.add_child(qte.cross_v)

	qte.status_lbl = Label.new(); qte.status_lbl.position = Vector2(0, arena.position.y+qte.arena_size.y+16); qte.status_lbl.size = Vector2(vp.x, 30); qte.status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.status_lbl.add_theme_font_size_override("font_size", 24); qte.status_lbl.add_theme_color_override("font_color", Color.WHITE); qte.add_child(qte.status_lbl)

	qte.target_pos = qte.arena_size * Vector2(0.65, 0.40); qte.target_vel = Vector2(155, 105); qte.cross_pos = qte.arena_size * 0.5
	parent_bf.get_tree().paused = true; Input.flush_buffered_events()
	
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
	if timer >= total_duration:
		_fail_qte("NO SHOT FIRED"); return

	next_dir_timer -= delta
	if next_dir_timer <= 0.0:
		target_vel = Vector2(randf_range(-210, 210), randf_range(-160, 160)); next_dir_timer = 0.24

	target_pos += target_vel * delta
	if target_pos.x <= 8 or target_pos.x >= arena_size.x-8: target_vel.x *= -1.0
	if target_pos.y <= 8 or target_pos.y >= arena_size.y-8: target_vel.y *= -1.0
	target_dot.position = target_pos - Vector2(5, 5)

	var move_input := Vector2.ZERO
	if Input.is_action_pressed("ui_left"): move_input.x -= 1
	if Input.is_action_pressed("ui_right"): move_input.x += 1
	if Input.is_action_pressed("ui_up"): move_input.y -= 1
	if Input.is_action_pressed("ui_down"): move_input.y += 1

	var is_zooming := Input.is_action_pressed("ui_accept")
	var move_speed := 180.0 if is_zooming else 320.0
	var target_cross_size := 30.0 if is_zooming else 76.0
	cross_size = lerpf(cross_size, target_cross_size, 0.18)

	cross_pos += move_input.normalized() * move_speed * delta
	cross_pos.x = clampf(cross_pos.x, cross_size*0.5, arena_size.x - cross_size*0.5)
	cross_pos.y = clampf(cross_pos.y, cross_size*0.5, arena_size.y - cross_size*0.5)

	cross_h.size = Vector2(cross_size, 2); cross_h.position = Vector2(cross_pos.x - cross_size*0.5, cross_pos.y - 1)
	cross_v.size = Vector2(2, cross_size); cross_v.position = Vector2(cross_pos.x - 1, cross_pos.y - cross_size*0.5)
	status_lbl.text = "TARGET DISTANCE: %0.1f" % cross_pos.distance_to(target_pos)

	if Input.is_action_just_released("ui_accept"):
		_fire_shot()

func _fire_shot() -> void:
	if is_done: return
	is_done = true; end_hold_timer = 0.40
	var dist := cross_pos.distance_to(target_pos)
	if cross_size <= 40.0 and dist <= 8.0:
		result = 2; help_lbl.text = "BULLSEYE"; help_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
		bf.screen_shake(14.0, 0.18)
	elif cross_size <= 52.0 and dist <= 22.0:
		result = 1; help_lbl.text = "GLANCING HIT"; help_lbl.add_theme_color_override("font_color", Color(0.35, 1, 0.35))
		if bf.get("select_sound") and bf.select_sound.stream != null: 
			bf.select_sound.pitch_scale = 1.18; bf.select_sound.play()
		bf.screen_shake(7.0, 0.1)
	else:
		_fail_qte("MISSED SHOT")

func _fail_qte(reason: String) -> void:
	result = 0; is_done = true; end_hold_timer = 0.40; help_lbl.text = reason
	help_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
