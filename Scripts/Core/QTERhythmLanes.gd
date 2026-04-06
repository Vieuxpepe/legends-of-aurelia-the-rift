extends CanvasLayer
class_name QTERhythmLanes

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var total_duration: float = 3.0
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var notes: Array[ColorRect] = []
var note_lanes: Array[int] = []
var note_hit_times: Array[float] = []
var note_resolved: Array[bool] = []
var arena_size := Vector2(420, 360)
var actions := ["ui_left", "ui_down", "ui_right"]

static func run(parent_bf: Node2D, title_text: String, help_text: String) -> QTERhythmLanes:
	var qte = QTERhythmLanes.new()
	qte.bf = parent_bf; qte.layer = 240; qte.process_mode = Node.PROCESS_MODE_ALWAYS; parent_bf.add_child(qte)
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new(); dimmer.size = vp; dimmer.color = Color(0.04, 0.04, 0.1, 0.88); qte.add_child(dimmer)

	var title := Label.new(); title.text = title_text; title.position = Vector2(0, 54); title.size = Vector2(vp.x, 42); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40); title.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
	title.add_theme_constant_override("outline_size", 8); title.add_theme_color_override("font_outline_color", Color.BLACK); qte.add_child(title)

	qte.help_lbl = Label.new(); qte.help_lbl.text = help_text; qte.help_lbl.position = Vector2(0, 98); qte.help_lbl.size = Vector2(vp.x, 28); qte.help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.help_lbl.add_theme_font_size_override("font_size", 22); qte.help_lbl.add_theme_color_override("font_color", Color.WHITE)
	qte.help_lbl.add_theme_constant_override("outline_size", 6); qte.help_lbl.add_theme_color_override("font_outline_color", Color.BLACK); qte.add_child(qte.help_lbl)

	var arena := ColorRect.new(); arena.size = qte.arena_size; arena.position = (vp - qte.arena_size)*0.5 - Vector2(0,8); arena.color = Color(0.08,0.08,0.12,0.96); qte.add_child(arena)
	var line := ColorRect.new(); line.size = Vector2(420,4); line.position = Vector2(0, 304); line.color = Color.WHITE; arena.add_child(line)

	var colors := [Color(0.55, 0.8, 1), Color(0.85, 1, 0.55), Color(1, 0.7, 0.9)]
	var base_times := [0.7, 1.12, 1.54, 1.96, 2.38, 2.8]
	for i in range(6):
		var lane := randi() % 3
		var n := ColorRect.new(); n.size = Vector2(52, 24); n.color = colors[lane]; n.visible = false; arena.add_child(n)
		qte.notes.append(n); qte.note_lanes.append(lane); qte.note_hit_times.append(base_times[i] + randf_range(-0.045, 0.045)); qte.note_resolved.append(false)

	parent_bf.get_tree().paused = true; Input.flush_buffered_events(); return qte

func _process(delta: float) -> void:
	if is_done:
		end_hold_timer -= delta
		if end_hold_timer <= 0.0:
			bf.get_tree().paused = false; qte_finished.emit(result); queue_free()
		return
	
	timer += delta
	if timer >= total_duration: _resolve()

	for i in range(6):
		if note_resolved[i]: continue
		var t_hit := note_hit_times[i]
		if timer < t_hit - 0.9: continue
		if timer > t_hit + 0.095: note_resolved[i] = true; notes[i].visible = false; continue
		var t := (timer - (t_hit - 0.9)) / 0.9
		notes[i].visible = true; notes[i].position = Vector2(70 + note_lanes[i]*140 - 26, lerpf(-26, 304-12, t))

	for i in range(3):
		if Input.is_action_just_pressed(actions[i]):
			var best := -1; var best_d := 0.095
			for j in range(6):
				if not note_resolved[j] and note_lanes[j] == i:
					var d := absf(timer - note_hit_times[j])
					if d < best_d: best_d = d; best = j
			if best != -1:
				result += 1; note_resolved[best] = true; notes[best].visible = false
				if bf.get("select_sound") and bf.select_sound.stream != null: bf.select_sound.play()
			else:
				if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()

func _resolve():
	is_done = true; end_hold_timer = 0.36
	if result >= 6: help_lbl.text = "PERFECT CHOIR"; help_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	elif result >= 3: help_lbl.text = "GOOD HARMONY"; help_lbl.add_theme_color_override("font_color", Color(0.35, 1, 0.35))
	else: help_lbl.text = "RHYTHM BROKEN"; help_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
