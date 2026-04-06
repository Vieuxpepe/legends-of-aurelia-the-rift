extends CanvasLayer
class_name QTEWhackAMole

signal qte_finished(result: int)

var bf: Node2D
var hits: int = 0
var rounds: int = 8
var current_round: int = 0
var is_done: bool = false
var end_hold_timer: float = -1.0

var help_lbl: Label
var hit_counter: Label
var boxes: Array[ColorRect] = []
var action_names := ["ui_up", "ui_down", "ui_left", "ui_right"]
var active_index: int = -1
var round_timer: float = 0.0
var round_limit: float = 0.0

static func run(parent_bf: Node2D, title_text: String, help_text: String) -> CanvasLayer:
	var qte = load("res://" + get_script().resource_path.trim_prefix("res://")).new()
	qte.bf = parent_bf; qte.layer = 220; qte.process_mode = Node.PROCESS_MODE_ALWAYS; parent_bf.add_child(qte)
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new(); dimmer.size = vp; dimmer.color = Color(0.12, 0.02, 0.02, 0.78); qte.add_child(dimmer)
	
	var title := Label.new(); title.text = title_text; title.position = Vector2(0, 72); title.size = Vector2(vp.x, 42); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40); title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	title.add_theme_constant_override("outline_size", 8); title.add_theme_color_override("font_outline_color", Color.BLACK); qte.add_child(title)
	
	qte.help_lbl = Label.new(); qte.help_lbl.text = help_text; qte.help_lbl.position = Vector2(0, 116); qte.help_lbl.size = Vector2(vp.x, 30); qte.help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.help_lbl.add_theme_font_size_override("font_size", 22); qte.help_lbl.add_theme_color_override("font_color", Color.WHITE)
	qte.help_lbl.add_theme_constant_override("outline_size", 6); qte.help_lbl.add_theme_color_override("font_outline_color", Color.BLACK); qte.add_child(qte.help_lbl)
	
	if parent_bf.has_node("/root/QTEManager"):
		var mgr = parent_bf.get_node("/root/QTEManager"); mgr._apply_qte_visual_overhaul(qte, title, qte.help_lbl)
	
	var cx := vp.x * 0.5; var cy := vp.y * 0.5
	var pos := [Vector2(cx-60, cy-185), Vector2(cx-60, cy+65), Vector2(cx-185, cy-60), Vector2(cx+65, cy-60)]
	var lbls := ["UP", "DOWN", "LEFT", "RIGHT"]
	for i in range(4):
		var box := ColorRect.new(); box.size = Vector2(120, 120); box.position = pos[i]; box.color = Color(0.18,0.18,0.18,0.96); qte.add_child(box); qte.boxes.append(box)
		var l := Label.new(); l.text = lbls[i]; l.size = box.size; l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 34); l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_constant_override("outline_size", 6); l.add_theme_color_override("font_outline_color", Color.BLACK); box.add_child(l)
		
	qte.hit_counter = Label.new(); qte.hit_counter.text = "HITS: 0"; qte.hit_counter.position = Vector2(0, vp.y - 130); qte.hit_counter.size = Vector2(vp.x, 36); qte.hit_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.hit_counter.add_theme_font_size_override("font_size", 30); qte.hit_counter.add_theme_color_override("font_color", Color.WHITE); qte.hit_counter.add_theme_constant_override("outline_size", 6); qte.hit_counter.add_theme_color_override("font_outline_color", Color.BLACK); qte.add_child(qte.hit_counter)
	
	parent_bf.get_tree().paused = true; Input.flush_buffered_events(); qte._start_next_round(); return qte

func _start_next_round():
	if current_round >= rounds: _resolve(); return
	current_round += 1; for b in boxes: b.color = Color(0.18,0.18,0.18,0.96)
	active_index = randi() % 4; boxes[active_index].color = Color(1, 0.86, 0.2)
	round_timer = 0.0; round_limit = maxf(0.21, 0.42 - (current_round - 1) * 0.018)

func _process(delta: float) -> void:
	if is_done:
		end_hold_timer -= delta
		if end_hold_timer <= 0: bf.get_tree().paused = false; qte_finished.emit(hits); queue_free()
		return
	
	round_timer += delta
	if round_timer >= round_limit:
		if bf.get("miss_sound") and bf.miss_sound.stream: bf.miss_sound.play()
		_start_next_round(); return
		
	for i in range(4):
		if Input.is_action_just_pressed(action_names[i]):
			if i == active_index:
				hits += 1; hit_counter.text = "HITS: " + str(hits); boxes[i].color = Color(0.35, 1, 0.35)
				if bf.get("select_sound") and bf.select_sound.stream: bf.select_sound.pitch_scale = 1.1 + hits * 0.04; bf.select_sound.play()
				_start_next_round()
			else:
				boxes[active_index].color = Color(1, 0.3, 0.3)
				if bf.get("miss_sound") and bf.miss_sound.stream: bf.miss_sound.play()
				_start_next_round()

func _resolve():
	is_done = true; end_hold_timer = 0.36
	if hits >= 6: help_lbl.text = "PERFECT FRENZY"; help_lbl.add_theme_color_override("font_color", Color(1,0.86,0.2)); bf.screen_shake(12, 0.18)
	elif hits >= 3: help_lbl.text = "FRENZY BUILDS"; help_lbl.add_theme_color_override("font_color", Color(0.35,1,0.35))
	else: help_lbl.text = "WILD AND SLOPPY"; help_lbl.add_theme_color_override("font_color", Color(1,0.3,0.3))\n