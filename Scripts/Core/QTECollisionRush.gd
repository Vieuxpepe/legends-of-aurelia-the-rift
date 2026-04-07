extends CanvasLayer
class_name QTECollisionRush

signal qte_finished(result: int)

var bf: Node2D
var result: int = 0
var rounds: int = 3
var current_round: int = 0
var is_done: bool = false
var end_hold_timer: float = -1.0

var help_lbl: Label
var round_lbl: Label
var target_ring: Panel
var cursor: ColorRect
var target_center: Vector2
var start_pos: Vector2
var phase_timer: float = 0.0
var phase_limit := 0.72

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	theme: Dictionary = {}
) -> QTECollisionRush:
	var qte = QTECollisionRush.new()
	qte.bf = parent_bf
	
	qte.layer = 230
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

	var arena := ColorRect.new()
	arena.name = "Arena"
	arena.size = Vector2(640, 340)
	arena.position = vp * 0.5 - Vector2(320, 170)
	arena.color = Color(0.02, 0.02, 0.03, 0.95)
	qte.add_child(arena)

	qte.round_lbl = Label.new()
	qte.round_lbl.name = "RoundLabel"
	qte.round_lbl.position = Vector2(0, arena.position.y + arena.size.y + 10)
	qte.round_lbl.size = Vector2(vp.x, 28)
	qte.round_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.round_lbl.add_theme_font_size_override("font_size", 24)
	qte.round_lbl.add_theme_color_override("font_color", secondary)
	qte.round_lbl.add_theme_constant_override("outline_size", 5)
	qte.round_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.round_lbl)

	qte.target_ring = Panel.new()
	qte.target_ring.name = "TargetRing"
	qte.target_ring.size = Vector2(80, 80)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_width_left = 6
	s.border_width_top = 6
	s.border_width_right = 6
	s.border_width_bottom = 6
	s.border_color = accent
	s.corner_radius_top_left = 40
	s.corner_radius_top_right = 40
	s.corner_radius_bottom_left = 40
	s.corner_radius_bottom_right = 40
	qte.target_ring.add_theme_stylebox_override("panel", s)
	arena.add_child(qte.target_ring)

	qte.cursor = ColorRect.new()
	qte.cursor.name = "Cursor"
	qte.cursor.size = Vector2(16, 16)
	qte.cursor.color = Color.WHITE
	arena.add_child(qte.cursor)

	parent_bf.get_tree().paused = true
	Input.flush_buffered_events()
	qte._start_round()
	
	return qte

func _start_round():
	if current_round >= rounds: _resolve(); return
	current_round += 1; round_lbl.text = "HITS: " + str(result) + " / 3   |   TARGET " + str(current_round)
	target_center = Vector2(randf_range(90, 550), randf_range(80, 260)); target_ring.position = target_center - Vector2(34,34)
	target_ring.get_theme_stylebox("panel").border_color = Color(1, 0.85, 0.2)
	var edge := randi() % 4
	if edge == 0: start_pos = Vector2(-30, randf_range(30, 310))
	elif edge == 1: start_pos = Vector2(670, randf_range(30, 310))
	elif edge == 2: start_pos = Vector2(randf_range(30, 610), -30)
	else: start_pos = Vector2(randf_range(30, 610), 370)
	phase_timer = 0.0

func _process(delta: float) -> void:
	if is_done:
		end_hold_timer -= delta
		if end_hold_timer <= 0: bf.get_tree().paused = false; qte_finished.emit(result); queue_free()
		return
	
	phase_timer += delta
	if phase_timer >= phase_limit:
		if bf.get("miss_sound") and bf.miss_sound.stream: bf.miss_sound.play()
		_hold_and_next(false); return
		
	var t := phase_timer / phase_limit; cursor.position = start_pos.lerp(target_center, t) - Vector2(7,7)
	if Input.is_action_just_pressed("ui_accept"):
		if cursor.position.distance_to(target_center-Vector2(7,7)) <= 30.0:
			result += 1; if bf.get("select_sound") and bf.select_sound.stream: bf.select_sound.pitch_scale = 1.1 + result*0.08; bf.select_sound.play()
			bf.screen_shake(6, 0.08); _hold_and_next(true)
		else:
			if bf.get("miss_sound") and bf.miss_sound.stream: bf.miss_sound.play()
			_hold_and_next(false)

func _hold_and_next(hit: bool):
	var color := Color(0.35, 1, 0.35) if hit else Color(1, 0.3, 0.3)
	target_ring.get_theme_stylebox("panel").border_color = color; cursor.color = color; help_lbl.text = "SLASH CONNECTED" if hit else "MISSED THE WINDOW"; help_lbl.add_theme_color_override("font_color", color)
	set_process(false); await bf.get_tree().create_timer(0.18).timeout
	if not is_queued_for_deletion(): set_process(true); cursor.color = Color.WHITE; _start_round()

func _resolve():
	is_done = true; end_hold_timer = 0.32
	if result >= 3: help_lbl.text = "PERFECT SEVERING"; help_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2)); if bf.get("crit_sound") and bf.crit_sound.stream: bf.crit_sound.play(); bf.screen_shake(12, 0.18)
	elif result >= 1: help_lbl.text = str(result) + " CLEAN HIT(S)"; help_lbl.add_theme_color_override("font_color", Color(0.35, 1, 0.35))
	else: help_lbl.text = "NO OPENING FOUND"; help_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))\n