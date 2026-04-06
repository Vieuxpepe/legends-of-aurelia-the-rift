extends CanvasLayer
class_name QTEPartingShot

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var ring_duration: float = 0.95
var reaction_duration: float = 0.50
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0
var phase := 1 # 1 = Ring, 2 = Reaction

var help_lbl: Label
var inner_ring: Panel
var outer_ring: Panel
var arrow_lbl: Label
var target_index: int = -1

var action_names := ["ui_up", "ui_down", "ui_left", "ui_right"]
var display_names := ["UP ↑", "DOWN ↓", "LEFT ←", "RIGHT →"]

static func run(parent_bf: Node2D, title_text: String, help_text: String) -> QTEPartingShot:
	var qte = QTEPartingShot.new()
	qte.bf = parent_bf; qte.layer = 230; qte.process_mode = Node.PROCESS_MODE_ALWAYS; parent_bf.add_child(qte)
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new(); dimmer.size = vp; dimmer.color = Color(0.02, 0.04, 0.08, 0.84); qte.add_child(dimmer)

	var title := Label.new(); title.text = title_text; title.position = Vector2(0, 68); title.size = Vector2(vp.x, 42); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42); title.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	title.add_theme_constant_override("outline_size", 8); title.add_theme_color_override("font_outline_color", Color.BLACK); qte.add_child(title)

	qte.help_lbl = Label.new(); qte.help_lbl.text = help_text; qte.help_lbl.position = Vector2(0, 112); qte.help_lbl.size = Vector2(vp.x, 30); qte.help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.help_lbl.add_theme_font_size_override("font_size", 22); qte.help_lbl.add_theme_color_override("font_color", Color.WHITE)
	qte.help_lbl.add_theme_constant_override("outline_size", 6); qte.help_lbl.add_theme_color_override("font_outline_color", Color.BLACK); qte.add_child(qte.help_lbl)

	if parent_bf.has_node("/root/QTEManager"):
		var mgr = parent_bf.get_node("/root/QTEManager"); mgr._apply_qte_visual_overhaul(qte, title, qte.help_lbl)

	var center := vp * 0.5 + Vector2(0, 25)
	qte.inner_ring = Panel.new(); qte.inner_ring.size = Vector2(92, 92); qte.inner_ring.position = center - Vector2(46,46)
	var istyle := StyleBoxFlat.new(); istyle.bg_color=Color(0,0,0,0); istyle.border_width_left=6; istyle.border_width_top=6; istyle.border_width_right=6; istyle.border_width_bottom=6; istyle.border_color=Color(1,0.85,0.2); istyle.corner_radius_top_left=60; istyle.corner_radius_top_right=60; istyle.corner_radius_bottom_left=60; istyle.corner_radius_bottom_right=60
	qte.inner_ring.add_theme_stylebox_override("panel", istyle); qte.add_child(qte.inner_ring)

	qte.outer_ring = Panel.new(); qte.outer_ring.size = Vector2(240, 240); qte.outer_ring.position = center - Vector2(120,120)
	var ostyle := StyleBoxFlat.new(); ostyle.bg_color=Color(0,0,0,0); ostyle.border_width_left=7; ostyle.border_width_top=7; ostyle.border_width_right=7; ostyle.border_width_bottom=7; ostyle.border_color=Color(0.7,0.92,1); ostyle.corner_radius_top_left=140; ostyle.corner_radius_top_right=140; ostyle.corner_radius_bottom_left=140; ostyle.corner_radius_bottom_right=140
	qte.outer_ring.add_theme_stylebox_override("panel", ostyle); qte.add_child(qte.outer_ring)

	qte.arrow_lbl = Label.new(); qte.arrow_lbl.position = Vector2(0, center.y+130); qte.arrow_lbl.size = Vector2(vp.x, 90); qte.arrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.arrow_lbl.add_theme_font_size_override("font_size", 68); qte.arrow_lbl.add_theme_color_override("font_color", Color.WHITE); qte.arrow_lbl.add_theme_constant_override("outline_size", 8); qte.arrow_lbl.add_theme_color_override("font_outline_color", Color.BLACK); qte.add_child(qte.arrow_lbl)

	parent_bf.get_tree().paused = true; Input.flush_buffered_events(); return qte

func _process(delta: float) -> void:
	if is_done:
		end_hold_timer -= delta
		if end_hold_timer <= 0.0:
			bf.get_tree().paused = false; qte_finished.emit(result); queue_free()
		return

	timer += delta
	if phase == 1:
		if timer >= ring_duration: _fail_ring("TOO LATE")
		var t := timer / ring_duration
		var cur := lerpf(240.0, 72.0, t)
		outer_ring.size = Vector2(cur, cur); outer_ring.position = (bf.get_viewport_rect().size * 0.5 + Vector2(0,25)) - Vector2(cur*0.5, cur*0.5)
		if Input.is_action_just_pressed("ui_accept"):
			var diff := absf(outer_ring.size.x - inner_ring.size.x)
			if diff <= 24.0:
				phase = 2; timer = 0.0; target_index = randi() % 4; arrow_lbl.text = display_names[target_index]; help_lbl.text = "SHOT LANDED — REACT!"
				if bf.get("select_sound") and bf.select_sound.stream != null: bf.select_sound.pitch_scale = 1.2; bf.select_sound.play()
			else: _fail_ring("SHOT MISSED")
	elif phase == 2:
		if timer >= reaction_duration: _resolve_final(1)
		for i in range(4):
			if Input.is_action_just_pressed(action_names[i]):
				if i == target_index: _resolve_final(2)
				else: _resolve_final(1)

func _fail_ring(reason: String) -> void:
	result = 0; is_done = true; end_hold_timer = 0.36; help_lbl.text = reason
	help_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()

func _resolve_final(final_res: int) -> void:
	result = final_res; is_done = true; end_hold_timer = 0.36
	if result == 2:
		help_lbl.text = "PERFECT PARTING SHOT"; help_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		arrow_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
		bf.screen_shake(12.0, 0.16)
	else:
		help_lbl.text = "SHOT ONLY"; help_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		arrow_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
