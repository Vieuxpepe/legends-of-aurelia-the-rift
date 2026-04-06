import os
import re

# 1. QTEPartingShot.gd (Shrinking Ring -> Reaction Arrow)
parting_shot_code = """extends CanvasLayer
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
"""

# 2. QTECatcherPaddle.gd (Aether Bind)
catcher_paddle_code = """extends CanvasLayer
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

static func run(parent_bf: Node2D, title_text: String, help_text: String) -> QTECatcherPaddle:
	var qte = QTECatcherPaddle.new()
	qte.bf = parent_bf; qte.layer = 230; qte.process_mode = Node.PROCESS_MODE_ALWAYS; parent_bf.add_child(qte)
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new(); dimmer.size = vp; dimmer.color = Color(0.04, 0.03, 0.09, 0.84); qte.add_child(dimmer)

	var title := Label.new(); title.text = title_text; title.position = Vector2(0, 60); title.size = Vector2(vp.x, 42); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42); title.add_theme_color_override("font_color", Color(0.75, 0.55, 1.0))
	title.add_theme_constant_override("outline_size", 8); title.add_theme_color_override("font_outline_color", Color.BLACK); qte.add_child(title)

	qte.help_lbl = Label.new(); qte.help_lbl.text = help_text; qte.help_lbl.position = Vector2(0, 105); qte.help_lbl.size = Vector2(vp.x, 30); qte.help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.help_lbl.add_theme_font_size_override("font_size", 22); qte.help_lbl.add_theme_color_override("font_color", Color.WHITE)
	qte.help_lbl.add_theme_constant_override("outline_size", 6); qte.help_lbl.add_theme_color_override("font_outline_color", Color.BLACK); qte.add_child(qte.help_lbl)

	var arena := ColorRect.new(); arena.size = qte.arena_size; arena.position = (vp - qte.arena_size)*0.5 - Vector2(0,10); arena.color = Color(0.08,0.08,0.12,0.96); qte.add_child(arena)
	qte.paddle = ColorRect.new(); qte.paddle.size = Vector2(96, 18); qte.paddle.position = Vector2(232, 310); qte.paddle.color = Color.WHITE; arena.add_child(qte.paddle)

	for i in range(5):
		var s := ColorRect.new(); s.size = Vector2(16,16); s.color = Color(1, 0.85, 0.2); s.visible = false; arena.add_child(s)
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
"""

# 3. QTERhythmLanes.gd (Celestial Choir)
rhythm_lanes_code = """extends CanvasLayer
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
"""

# 4. QTEHeatBalance.gd (Hellfire)
heat_balance_code = """extends CanvasLayer
class_name QTEHeatBalance

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var accum_time: float = 0.0
var total_duration: float = 5.0
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var bar_fill: ColorRect
var meter: float = 30.0

static func run(parent_bf: Node2D, title_text: String, help_text: String) -> QTEHeatBalance:
	var qte = QTEHeatBalance.new()
	qte.bf = parent_bf; qte.layer = 240; qte.process_mode = Node.PROCESS_MODE_ALWAYS; parent_bf.add_child(qte)
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new(); dimmer.size = vp; dimmer.color = Color(0.12, 0.02, 0.0, 0.85); qte.add_child(dimmer)

	var title := Label.new(); title.text = title_text; title.position = Vector2(0, 60); title.size = Vector2(vp.x, 42); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42); title.add_theme_color_override("font_color", Color(1, 0.3, 0.1))
	title.add_theme_constant_override("outline_size", 8); title.add_theme_color_override("font_outline_color", Color.BLACK); qte.add_child(title)

	qte.help_lbl = Label.new(); qte.help_lbl.text = help_text; qte.help_lbl.position = Vector2(0, 105); qte.help_lbl.size = Vector2(vp.x, 30); qte.help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.help_lbl.add_theme_font_size_override("font_size", 22); qte.help_lbl.add_theme_color_override("font_color", Color.WHITE)
	qte.help_lbl.add_theme_constant_override("outline_size", 6); qte.help_lbl.add_theme_color_override("font_outline_color", Color.BLACK); qte.add_child(qte.help_lbl)

	var bg := ColorRect.new(); bg.size = Vector2(40, 300); bg.position = (vp - Vector2(40,300))*0.5; bg.color = Color(0.1, 0.1, 0.1, 0.9); qte.add_child(bg)
	qte.bar_fill = ColorRect.new(); qte.bar_fill.size = Vector2(40, 0); qte.bar_fill.position = Vector2(0, 300); qte.bar_fill.color = Color(1, 0.4, 0.2); bg.add_child(qte.bar_fill)
	var zone := ColorRect.new(); zone.size = Vector2(40, 45); zone.position = Vector2(0, 0); zone.color = Color(1, 1, 1, 0.3); bg.add_child(zone)

	parent_bf.get_tree().paused = true; Input.flush_buffered_events(); return qte

func _process(delta: float) -> void:
	if is_done:
		end_hold_timer -= delta
		if end_hold_timer <= 0.0:
			bf.get_tree().paused = false; qte_finished.emit(result); queue_free()
		return
	
	timer += delta
	if timer >= total_duration: _resolve(0)
	
	meter -= 120.0 * delta
	if Input.is_action_pressed("ui_accept"): meter += 240.0 * delta
	meter = clampf(meter, 0, 100)
	bar_fill.size.y = (meter/100)*300; bar_fill.position.y = 300 - bar_fill.size.y
	
	if meter >= 85: 
		accum_time += delta
		bar_fill.color = Color(1, 1, 1)
		if accum_time >= 1.5: _resolve(2)
	else: bar_fill.color = Color(1, 0.4, 0.2)

func _resolve(res: int):
	is_done = true; end_hold_timer = 0.4
	result = res; help_lbl.text = "HELLFIRE IGNITED" if res == 2 else "EXPIRED"
	if res == 2:
		help_lbl.add_theme_color_override("font_color", Color(1,0.85,0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
	else:
		help_lbl.add_theme_color_override("font_color", Color(1,0.3,0.3))
		if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
"""

def write_f(path, content):
    with open(path, 'w', encoding='utf-8') as f: f.write(content.strip() + "\n")

# Create templates
write_f('Scripts/Core/QTEPartingShot.gd', parting_shot_code)
write_f('Scripts/Core/QTECatcherPaddle.gd', catcher_paddle_code)
write_f('Scripts/Core/QTERhythmLanes.gd', rhythm_lanes_code)
write_f('Scripts/Core/QTEHeatBalance.gd', heat_balance_code)

def replace_func(file_path, func_name, new_code):
	with open(file_path, 'r', encoding='utf-8') as f: content = f.read()
	pattern = r"func " + func_name + r"\(bf: Node2D, (attacker|defender): Node2D\) -> int:.*?(?=\nfunc [a-zA-Z_]+\(bf: Node2D|\Z)"
	match = re.search(pattern, content, re.DOTALL)
	if match:
		content = content[:match.start()] + new_code + "\n" + content[match.end():]
		with open(file_path, 'w', encoding='utf-8') as f: f.write(content)
		return True
	return False

# REFACTORS
# ARCHER
replace_func("QTEManager.gd", "run_parting_shot_minigame", """func run_parting_shot_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEPartingShot.run(bf, "PARTING SHOT", "PRESS SPACE WHEN THE RINGS ALIGN")
	var res = await qte.qte_finished
	return res
""")
replace_func("QTEManager.gd", "run_ballista_shot_minigame", """func run_ballista_shot_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTESniperZoom.run(bf, "BALLISTA SHOT", "MOVE WITH ARROWS • HOLD SPACE TO ZOOM • RELEASE TO FIRE", 4200)
	var res = await qte.qte_finished
	return res
""")
# CLERIC
replace_func("QTEManager.gd", "run_divine_protection_minigame", """func run_divine_protection_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte = QTEShrinkingRing.run(bf, "DIVINE PROTECTION", "PRESS SPACE WHEN THE RINGS ALIGN", 1100)
	var res = await qte.qte_finished
	return res
""")
replace_func("QTEManager.gd", "run_healing_light_minigame", """func run_healing_light_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEMashMeter.run(bf, "HEALING LIGHT", "MASH SPACE TO AMPLIFY THE HEAL", 2200, 24.0)
	var res = await qte.qte_finished
	return res
""")
replace_func("QTEManager.gd", "run_miracle_minigame", """func run_miracle_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte = QTEOscillationStop.run(bf, "MIRACLE", "STOP THE PENDULUM IN THE GOLD", 1500)
	var res = await qte.qte_finished
	return res
""")
replace_func("QTEManager.gd", "run_aether_bind_minigame", """func run_aether_bind_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTECatcherPaddle.run(bf, "AETHER BIND", "MOVE LEFT / RIGHT TO CATCH THE FALLING SPARKS")
	var res = await qte.qte_finished
	return res
""")
replace_func("QTEManager.gd", "run_soul_harvest_minigame", """func run_soul_harvest_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEMashMeter.run(bf, "SOUL HARVEST", "MASH SPACE TO HOLD THE BAR ABOVE THE DARK PULL", 2500, 55.0)
	var res = await qte.qte_finished
	return res
""")
replace_func("QTEManager.gd", "run_celestial_choir_minigame", """func run_celestial_choir_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTERhythmLanes.run(bf, "CELESTIAL CHOIR", "LEFT / DOWN / RIGHT — HIT WHEN NOTES REACH THE LINE")
	var res = await qte.qte_finished
	return res
""")
replace_func("QTEManager.gd", "run_hellfire_minigame", """func run_hellfire_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEHeatBalance.run(bf, "HELLFIRE", "KEEP HEAT INSIDE THE TOP 15% RED ZONE")
	var res = await qte.qte_finished
	return res
""")

# DEAD CODE PURGE
with open("QTEManager.gd", "r", encoding="utf-8") as f: content = f.read()
content = re.sub(r"bf\.get_tree\(\)\.paused = true\n\tvar qte_layer: CanvasLayer = CanvasLayer\.new\(\).*?return result\n\t", "", content, flags=re.DOTALL)
with open("QTEManager.gd", "w", encoding="utf-8") as f: f.write(content)
print("Purged dead code.")
