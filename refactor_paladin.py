import os
import re

shrinking_ring_code = """extends CanvasLayer
class_name QTEShrinkingRing

signal qte_finished(result: int)

var bf: Node2D
var sweep_duration: float
var timer: float = 0.0
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var target: Panel
var ring: Panel
var target_style: StyleBoxFlat
var ring_style: StyleBoxFlat

var start_size: float = 260.0
var end_size: float = 60.0
var target_size_f: float = 80.0

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int
) -> QTEShrinkingRing:
	var qte = QTEShrinkingRing.new()
	qte.bf = parent_bf
	qte.sweep_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.12, 0.08, 0.0, 0.6)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 90)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.text = help_text
	qte.help_lbl.position = Vector2(0, 140)
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

	var center := vp * 0.5 + Vector2(0, 20)

	qte.target = Panel.new()
	qte.target.size = Vector2(qte.target_size_f, qte.target_size_f)
	qte.target.position = center - qte.target.size * 0.5
	qte.target_style = StyleBoxFlat.new()
	qte.target_style.bg_color = Color(0, 0, 0, 0)
	qte.target_style.border_width_left = 6
	qte.target_style.border_width_top = 6
	qte.target_style.border_width_right = 6
	qte.target_style.border_width_bottom = 6
	qte.target_style.border_color = Color(1.0, 0.4, 0.1, 1.0)
	qte.target_style.corner_radius_top_left = 64
	qte.target_style.corner_radius_top_right = 64
	qte.target_style.corner_radius_bottom_left = 64
	qte.target_style.corner_radius_bottom_right = 64
	qte.target.add_theme_stylebox_override("panel", qte.target_style)
	qte.add_child(qte.target)

	qte.ring = Panel.new()
	qte.ring.size = Vector2(qte.start_size, qte.start_size)
	qte.ring.position = center - qte.ring.size * 0.5
	qte.ring_style = StyleBoxFlat.new()
	qte.ring_style.bg_color = Color(0, 0, 0, 0)
	qte.ring_style.border_width_left = 8
	qte.ring_style.border_width_top = 8
	qte.ring_style.border_width_right = 8
	qte.ring_style.border_width_bottom = 8
	qte.ring_style.border_color = Color(1.0, 0.9, 0.4, 1.0)
	qte.ring_style.corner_radius_top_left = 140
	qte.ring_style.corner_radius_top_right = 140
	qte.ring_style.corner_radius_bottom_left = 140
	qte.ring_style.corner_radius_bottom_right = 140
	qte.ring.add_theme_stylebox_override("panel", qte.ring_style)
	qte.add_child(qte.ring)

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
		_fail_qte("FAILED")
		return

	var t := timer / sweep_duration
	var current_size := lerpf(start_size, end_size, t)
	ring.size = Vector2(current_size, current_size)
	var center := bf.get_viewport_rect().size * 0.5 + Vector2(0, 20)
	ring.position = center - ring.size * 0.5

	if Input.is_action_just_pressed("ui_accept"):
		var diff := absf(ring.size.x - target.size.x)
		is_done = true
		end_hold_timer = 0.36
		if diff <= 12.0:
			result = 2
			help_lbl.text = "PERFECT ALIGNMENT"
			help_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			ring_style.border_color = Color.WHITE
			target_style.border_color = Color.WHITE
			if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(16.0, 0.22)
		elif diff <= 30.0:
			result = 1
			help_lbl.text = "GOOD ALIGNMENT"
			help_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.35))
			if bf.get("select_sound") and bf.select_sound.stream != null: 
				bf.select_sound.pitch_scale = 1.2
				bf.select_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(8.0, 0.12)
		else:
			_fail_qte("MISS")

func _fail_qte(reason: String) -> void:
	result = 0
	is_done = true
	end_hold_timer = 0.36
	help_lbl.text = reason
	help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
"""

fast_sequence_code = """extends CanvasLayer
class_name QTEFastSequence

signal qte_finished(result: int)

var bf: Node2D
var sweep_duration: float
var timer: float = 0.0
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var labels: Array[Label] = []
var sequence: Array[int] = []
var correct_count: int = 0
var max_perfect_timer: float = 1.0

var action_names: Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right"]
var display_names: Array[String] = ["UP", "DOWN", "LEFT", "RIGHT"]

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	num_stages: int,
	total_ms: int,
	perfect_ms: int
) -> QTEFastSequence:
	var qte = QTEFastSequence.new()
	qte.bf = parent_bf
	qte.sweep_duration = total_ms / 1000.0
	qte.max_perfect_timer = perfect_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.02, 0.05, 0.10, 0.70)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
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

	var panel := ColorRect.new()
	panel.size = Vector2(150 * num_stages, 180)
	panel.position = Vector2((vp.x - panel.size.x) * 0.5, vp.y * 0.5 - 20)
	panel.color = Color(0.08, 0.08, 0.08, 0.96)
	qte.add_child(panel)

	for i in range(num_stages): qte.sequence.append(randi() % 4)

	for i in range(num_stages):
		var lbl := Label.new()
		lbl.text = qte.display_names[qte.sequence[i]]
		lbl.position = Vector2(30 + i * 140, 60)
		lbl.size = Vector2(120, 60)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 34)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		panel.add_child(lbl)
		qte.labels.append(lbl)

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
		_end_qte(0, "TOO SLOW", Color(1.0, 0.3, 0.3), true)
		return

	var pressed_index: int = -1
	for i in range(action_names.size()):
		if Input.is_action_just_pressed(action_names[i]):
			pressed_index = i
			break

	if pressed_index == -1: return

	if pressed_index == sequence[correct_count]:
		labels[correct_count].add_theme_color_override("font_color", Color(0.3, 1.0, 0.35))
		correct_count += 1
		if bf.get("select_sound") and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.1 + correct_count * 0.08
			bf.select_sound.play()

		if correct_count >= sequence.size():
			if timer <= max_perfect_timer:
				_end_qte(2, "PERFECT", Color(1.0, 0.85, 0.2), false)
			else:
				_end_qte(1, "GOOD", Color(0.3, 1.0, 0.35), false)
	else:
		_end_qte(0, "SEQUENCE BROKEN", Color(1.0, 0.3, 0.3), true)

func _end_qte(res: int, msg: String, color: Color, shook: bool) -> void:
	result = res
	is_done = true
	end_hold_timer = 0.36
	help_lbl.text = msg
	help_lbl.add_theme_color_override("font_color", color)
	
	if res == 2:
		if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(12.0, 0.20)
	elif res == 1:
		if bf.has_method("screen_shake"): bf.screen_shake(6.0, 0.10)
	else:
		if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(8.0, 0.12)
"""

ping_pong_code = """extends CanvasLayer
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
"""

def write_f(path, content):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content.strip() + "\n")
    print("Wrote " + path)

write_f('Scripts/Core/QTEShrinkingRing.gd', shrinking_ring_code)
write_f('Scripts/Core/QTEFastSequence.gd', fast_sequence_code)
write_f('Scripts/Core/QTEPingPongBar.gd', ping_pong_code)

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

# 1. Smite
replace_function("QTEManager.gd", "run_smite_minigame", """func run_smite_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEShrinkingRing.run(bf, "SMITE", "PRESS SPACE WHEN THE RING ALIGNS", 750)
	var res = await qte.qte_finished
	return res
""")

# 2. Holy Ward
replace_function("QTEManager.gd", "run_holy_ward_minigame", """func run_holy_ward_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte = QTEFastSequence.run(bf, "HOLY WARD", "INPUT THE 4 ARROWS FAST TO BLOCK MAGIC", 4, 2400, 1000)
	var res = await qte.qte_finished
	return res
""")

# 3. Sacred Judgment
replace_function("QTEManager.gd", "run_sacred_judgment_minigame", """func run_sacred_judgment_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEPingPongBar.run(bf, "SACRED JUDGMENT", "RELEASE NEAR MAX", 2.4)
	var res = await qte.qte_finished
	return res
""")
