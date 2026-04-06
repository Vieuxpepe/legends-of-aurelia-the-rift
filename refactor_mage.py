import os
import re

bubble_expansion_code = """extends CanvasLayer
class_name QTEBubbleExpansion

signal qte_finished(result: int)

var bf: Node2D
var sweep_duration: float
var timer: float = 0.0
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var wave: Panel
var counter: Label

var radius: float = 40.0
var peak_radius: float = 40.0

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int
) -> QTEBubbleExpansion:
	var qte = QTEBubbleExpansion.new()
	qte.bf = parent_bf
	qte.sweep_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.12, 0.04, 0.02, 0.74)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 70)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.15))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.text = help_text
	qte.help_lbl.position = Vector2(0, 115)
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

	qte.wave = Panel.new()
	var wave_style := StyleBoxFlat.new()
	wave_style.bg_color = Color(0, 0, 0, 0)
	wave_style.border_width_left = 8
	wave_style.border_width_top = 8
	wave_style.border_width_right = 8
	wave_style.border_width_bottom = 8
	wave_style.border_color = Color(1.0, 0.55, 0.15, 1.0)
	wave_style.corner_radius_top_left = 500
	wave_style.corner_radius_top_right = 500
	wave_style.corner_radius_bottom_left = 500
	wave_style.corner_radius_bottom_right = 500
	qte.wave.add_theme_stylebox_override("panel", wave_style)
	qte.add_child(qte.wave)

	qte.counter = Label.new()
	qte.counter.text = "POWER: 0"
	qte.counter.position = Vector2(0, vp.y - 140.0)
	qte.counter.size = Vector2(vp.x, 36)
	qte.counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.counter.add_theme_font_size_override("font_size", 30)
	qte.counter.add_theme_color_override("font_color", Color.WHITE)
	qte.counter.add_theme_constant_override("outline_size", 6)
	qte.counter.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.counter)
	
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
		_finish_qte()
		return

	radius -= 24.0 * delta
	radius = maxf(36.0, radius)

	if Input.is_action_just_pressed("ui_accept"):
		radius += 18.0
		peak_radius = maxf(peak_radius, radius)
		
		if bf.get("select_sound") and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = min(1.05 + (radius - 40.0) / 180.0, 1.8)
			bf.select_sound.play()

	var center := bf.get_viewport_rect().size * 0.5 + Vector2(0, 10)
	wave.size = Vector2(radius * 2.0, radius * 2.0)
	wave.position = center - wave.size * 0.5
	counter.text = "POWER: " + str(int(round(peak_radius - 40.0)))

func _finish_qte() -> void:
	is_done = true
	end_hold_timer = 0.40
	
	if peak_radius >= 220.0:
		result = 2
		help_lbl.text = "PERFECT CAST"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(14.0, 0.20)
	elif peak_radius >= 145.0:
		result = 1
		help_lbl.text = "GOOD CAST"
		help_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		if bf.get("select_sound") and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.18
			bf.select_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(6.0, 0.10)
	else:
		result = 0
		help_lbl.text = "FAILED"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.get("miss_sound") and bf.miss_sound.stream != null:
			bf.miss_sound.play()
"""

alt_mash_code = """extends CanvasLayer
class_name QTEAlternatingMashMeter

signal qte_finished(result: int)

var bf: Node2D
var sweep_duration: float
var timer: float = 0.0
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var bar_bg: ColorRect
var fill: ColorRect

var meter: float = 18.0
var expect_up: bool = true

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int
) -> QTEAlternatingMashMeter:
	var qte = QTEAlternatingMashMeter.new()
	qte.bf = parent_bf
	qte.sweep_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.04, 0.02, 0.10, 0.70)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 75)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.78, 0.72, 1.0))
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
	qte.bar_bg.size = Vector2(520, 36)
	qte.bar_bg.position = Vector2((vp.x - 520) * 0.5, vp.y * 0.5 - 10)
	qte.bar_bg.color = Color(0.08, 0.08, 0.08, 0.96)
	qte.add_child(qte.bar_bg)

	qte.fill = ColorRect.new()
	qte.fill.size = Vector2(0, 36)
	qte.fill.color = Color(0.7, 0.5, 1.0, 1.0)
	qte.bar_bg.add_child(qte.fill)

	var good_line := ColorRect.new()
	good_line.size = Vector2(4, 36)
	good_line.position = Vector2(520.0 * 0.66, 0)
	good_line.color = Color(0.3, 1.0, 0.35, 0.95)
	qte.bar_bg.add_child(good_line)

	var perfect_line := ColorRect.new()
	perfect_line.size = Vector2(4, 36)
	perfect_line.position = Vector2(520.0 * 0.90, 0)
	perfect_line.color = Color(1.0, 0.86, 0.2, 0.98)
	qte.bar_bg.add_child(perfect_line)
	
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
		_finish_qte()
		return

	meter -= 35.0 * delta
	meter = clampf(meter, 0.0, 100.0)

	if Input.is_action_just_pressed("ui_up"):
		if expect_up:
			meter += 9.0
			expect_up = false
			_play_tick()
		else:
			meter -= 5.0
	elif Input.is_action_just_pressed("ui_down"):
		if not expect_up:
			meter += 9.0
			expect_up = true
			_play_tick()
		else:
			meter -= 5.0
			
	meter = clampf(meter, 0.0, 100.0)
	fill.size.x = (meter / 100.0) * bar_bg.size.x

func _play_tick() -> void:
	if bf.get("select_sound") and bf.select_sound.stream != null:
		bf.select_sound.pitch_scale = min(1.0 + (meter / 100.0) * 0.8, 1.8)
		bf.select_sound.play()

func _finish_qte() -> void:
	is_done = true
	end_hold_timer = 0.40
	
	if meter >= 90.0:
		result = 2
		help_lbl.text = "PERFECT SHIFT"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(12.0, 0.18)
	elif meter >= 66.0:
		result = 1
		help_lbl.text = "PHASED"
		help_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		if bf.get("select_sound") and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.16
			bf.select_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(6.0, 0.10)
	else:
		result = 0
		help_lbl.text = "FAILED"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.get("miss_sound") and bf.miss_sound.stream != null:
			bf.miss_sound.play()
"""

reaction_strike_code = """extends CanvasLayer
class_name QTEReactionStrike

signal qte_finished(result: int)

var bf: Node2D
var is_done: bool = false
var stages: int = 4
var current_stage: int = 0
var hits: int = 0
var result: int = 0

var help_lbl: Label
var arrow_label: Label
var end_hold_timer: float = -1.0

var state: String = "WAITING"
var wait_timer: float = 0.0
var react_timer: float = 0.0
var react_window: float = 0.55
var target_idx: int = 0
var arrows: Array[String] = ["UP \u2191", "DOWN \u2193", "LEFT \u2190", "RIGHT \u2192"]
var actions: Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right"]

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	num_stages: int,
	react_ms: int
) -> QTEReactionStrike:
	var qte = QTEReactionStrike.new()
	qte.bf = parent_bf
	qte.stages = num_stages
	qte.react_window = react_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.04, 0.04, 0.08, 0.70)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 75)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.30))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.text = help_text
	qte.help_lbl.position = Vector2(0, 130)
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

	qte.arrow_label = Label.new()
	qte.arrow_label.text = ""
	qte.arrow_label.position = Vector2(0, vp.y * 0.5 - 50)
	qte.arrow_label.size = Vector2(vp.x, 100)
	qte.arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.arrow_label.add_theme_font_size_override("font_size", 80)
	qte.arrow_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	qte.arrow_label.add_theme_constant_override("outline_size", 10)
	qte.arrow_label.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.arrow_label)
	
	parent_bf.get_tree().paused = true
	Input.flush_buffered_events()
	qte._start_next_stage()
	
	return qte

func _start_next_stage() -> void:
	if current_stage >= stages:
		_finish_qte()
		return
		
	state = "WAITING"
	arrow_label.text = ""
	wait_timer = randf_range(0.3, 0.7)

func _process(delta: float) -> void:
	if is_done:
		end_hold_timer -= delta
		if end_hold_timer <= 0.0:
			bf.get_tree().paused = false
			qte_finished.emit(result)
			queue_free()
		return
		
	if state == "WAITING":
		wait_timer -= delta
		if wait_timer <= 0.0:
			state = "REACTION"
			react_timer = react_window
			target_idx = randi() % 4
			arrow_label.text = arrows[target_idx]
			arrow_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			if bf.get("select_sound") and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.0 + (current_stage * 0.1)
				bf.select_sound.play()
				
	elif state == "REACTION":
		react_timer -= delta
		
		var pressed_idx := -1
		for i in range(4):
			if Input.is_action_just_pressed(actions[i]):
				pressed_idx = i
				break
				
		if pressed_idx != -1:
			if pressed_idx == target_idx:
				hits += 1
				arrow_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
				if bf.has_method("screen_shake"): bf.screen_shake(6.0, 0.1)
			else:
				arrow_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
				if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
			_end_stage_show_result()
		elif react_timer <= 0.0:
			arrow_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
			if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
			_end_stage_show_result()

	elif state == "SHOWING":
		wait_timer -= delta
		if wait_timer <= 0.0:
			current_stage += 1
			_start_next_stage()

func _end_stage_show_result() -> void:
	state = "SHOWING"
	wait_timer = 0.20

func _finish_qte() -> void:
	is_done = true
	end_hold_timer = 0.40
	
	if hits == stages:
		result = 2
		help_lbl.text = "PERFECT CAST"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(16.0, 0.25)
	elif hits >= stages / 2:
		result = 1
		help_lbl.text = "SUCCESSFUL CAST"
		help_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	else:
		result = 0
		help_lbl.text = "STUMBLED"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
"""

def write_f(path, content):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content.strip() + "\n")
    print("Wrote " + path)

write_f('Scripts/Core/QTEBubbleExpansion.gd', bubble_expansion_code)
write_f('Scripts/Core/QTEAlternatingMashMeter.gd', alt_mash_code)
write_f('Scripts/Core/QTEReactionStrike.gd', reaction_strike_code)

def replace_function(file_path, func_name, new_code):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    pattern = r"func " + func_name + r"\(bf: Node2D, attacker: Node2D\) -> int:.*?(?=\nfunc [a-zA-Z_]+\(bf: Node2D|\Z)"
    p2 = r"func " + func_name + r"\(bf: Node2D, defender: Node2D\) -> int:.*?(?=\nfunc [a-zA-Z_]+\(bf: Node2D|\Z)"
    match = re.search(pattern, content, re.DOTALL)
    if not match: match = re.search(p2, content, re.DOTALL)
    
    if match:
        content = content[:match.start()] + new_code + "\n" + content[match.end():]
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Replaced {func_name}")
        return True
    return False

# 1. Fireball
replace_function("QTEManager.gd", "run_fireball_minigame", """func run_fireball_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEBubbleExpansion.run(bf, "FIREBALL", "TAP SPACE REPEATEDLY TO GROW THE BUBBLE", 2000)
	var res = await qte.qte_finished
	return res
""")

# 2. Meteor Storm
replace_function("QTEManager.gd", "run_meteor_storm_minigame", """func run_meteor_storm_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTESequenceMemory.run(bf, "METEOR STORM", "MEMORIZE THE 5 ARROWS", 5, 1000)
	var res = await qte.qte_finished
	return res
""")

# 3. Arcane Shift
replace_function("QTEManager.gd", "run_arcane_shift_minigame", """func run_arcane_shift_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte = QTEAlternatingMashMeter.run(bf, "ARCANE SHIFT", "ALTERNATE UP / DOWN TO PHASE OUT", 2200)
	var res = await qte.qte_finished
	return res
""")

# 4. Elemental Convergence
replace_function("QTEManager.gd", "run_elemental_convergence_minigame", """func run_elemental_convergence_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEReactionStrike.run(bf, "ELEMENTAL CONVERGENCE", "PRESS THE ARROW AS SOON AS IT APPEARS!", 4, 550)
	var res = await qte.qte_finished
	return res
""")
