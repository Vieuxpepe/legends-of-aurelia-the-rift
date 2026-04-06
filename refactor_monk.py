import os
import re

balance_meter_code = """extends CanvasLayer
class_name QTEBalanceMeter

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var sweep_duration: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var cursor: ColorRect
var cursor_velocity: float = 0.0
var cursor_x: float = 0.0
var drift_target: float = 0.0

var bar_size_x: float = 560.0
var green_width: float = 160.0
var perfect_width: float = 70.0

var next_drift_timer: float = 0.260

var in_green_timer: float = 0.0
var in_perfect_timer: float = 0.0

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int
) -> QTEBalanceMeter:
	var qte = QTEBalanceMeter.new()
	qte.bf = parent_bf
	qte.sweep_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.03, 0.08, 0.04, 0.72)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 78)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.text = help_text
	qte.help_lbl.position = Vector2(0, 122)
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

	var bar_bg := ColorRect.new()
	bar_bg.size = Vector2(qte.bar_size_x, 34)
	bar_bg.position = Vector2((vp.x - qte.bar_size_x) * 0.5, vp.y * 0.5 - 14.0)
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.96)
	qte.add_child(bar_bg)

	var green_zone := ColorRect.new()
	green_zone.size = Vector2(qte.green_width, 34)
	green_zone.position = Vector2((qte.bar_size_x - qte.green_width) * 0.5, 0)
	green_zone.color = Color(0.25, 0.9, 0.25, 0.85)
	bar_bg.add_child(green_zone)

	var perfect_zone := ColorRect.new()
	perfect_zone.size = Vector2(qte.perfect_width, 34)
	perfect_zone.position = Vector2((qte.green_width - qte.perfect_width) * 0.5, 0)
	perfect_zone.color = Color(1.0, 0.86, 0.2, 0.95)
	green_zone.add_child(perfect_zone)

	qte.cursor = ColorRect.new()
	qte.cursor.size = Vector2(12, 48)
	qte.cursor.position.y = -7
	qte.cursor.color = Color.WHITE
	bar_bg.add_child(qte.cursor)

	qte.cursor_x = qte.bar_size_x * 0.5
	qte.drift_target = randf_range(-145.0, 145.0)

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

	next_drift_timer -= delta
	if next_drift_timer <= 0.0:
		drift_target = randf_range(-145.0, 145.0)
		next_drift_timer = 0.260

	cursor_velocity = lerpf(cursor_velocity, drift_target, 0.08)

	if Input.is_action_pressed("ui_left"): cursor_velocity -= 600.0 * delta
	if Input.is_action_pressed("ui_right"): cursor_velocity += 600.0 * delta

	cursor_x += cursor_velocity * delta
	cursor_x = clampf(cursor_x, 0.0, bar_size_x - cursor.size.x)
	cursor.position.x = cursor_x

	var c_mid := cursor_x + cursor.size.x * 0.5
	var dist := absf(c_mid - bar_size_x * 0.5)

	if dist <= perfect_width * 0.5:
		in_perfect_timer += delta
		in_green_timer += delta
	elif dist <= green_width * 0.5:
		in_green_timer += delta

func _finish_qte() -> void:
	is_done = true
	end_hold_timer = 0.40
	
	var in_green_ratio := in_green_timer / sweep_duration
	var in_perfect_ratio := in_perfect_timer / sweep_duration

	if in_perfect_ratio >= 0.70:
		result = 2
		help_lbl.text = "PERFECT HARMONY"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(12.0, 0.18)
	elif in_green_ratio >= 0.60:
		result = 1
		help_lbl.text = "FOCUSED"
		help_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		if bf.get("select_sound") and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.15
			bf.select_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(6.0, 0.10)
	else:
		result = 0
		help_lbl.text = "BALANCE LOST"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
"""

breathing_circle_code = """extends CanvasLayer
class_name QTEBreathingCircle

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var total_duration: float
var peak_timer: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var circle: Panel
var circle_style: StyleBoxFlat

var min_size: float = 60.0
var max_size: float = 280.0

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int,
	peak_ms: int
) -> QTEBreathingCircle:
	var qte = QTEBreathingCircle.new()
	qte.bf = parent_bf
	qte.total_duration = duration_ms / 1000.0
	qte.peak_timer = peak_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.08, 0.03, 0.12, 0.76)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 75)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.85, 0.65, 1.0))
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

	qte.circle = Panel.new()
	qte.circle_style = StyleBoxFlat.new()
	qte.circle_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	qte.circle_style.border_width_left = 6
	qte.circle_style.border_width_top = 6
	qte.circle_style.border_width_right = 6
	qte.circle_style.border_width_bottom = 6
	qte.circle_style.border_color = Color(0.85, 0.65, 1.0, 1.0)
	qte.circle_style.corner_radius_top_left = 300
	qte.circle_style.corner_radius_top_right = 300
	qte.circle_style.corner_radius_bottom_left = 300
	qte.circle_style.corner_radius_bottom_right = 300
	qte.circle.add_theme_stylebox_override("panel", qte.circle_style)
	qte.add_child(qte.circle)

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
	if timer >= total_duration:
		_fail_qte("TOO LATE")
		return

	var current_size := 0.0
	if timer <= peak_timer:
		current_size = lerpf(min_size, max_size, timer / peak_timer)
	else:
		current_size = lerpf(max_size, min_size, (timer - peak_timer) / (total_duration - peak_timer))

	var center := bf.get_viewport_rect().size * 0.5 + Vector2(0, 20)
	circle.size = Vector2(current_size, current_size)
	circle.position = center - circle.size * 0.5

	if Input.is_action_just_pressed("ui_accept"):
		is_done = true
		end_hold_timer = 0.36
		var diff := absf(timer - peak_timer)
		
		if diff <= 0.035: # 35ms
			result = 2
			help_lbl.text = "PERFECT RELEASE"
			help_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
			circle_style.border_color = Color.WHITE
			if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(12.0, 0.18)
		elif diff <= 0.095: # 95ms
			result = 1
			help_lbl.text = "GOOD RELEASE"
			help_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
			if bf.get("select_sound") and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.16
				bf.select_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(6.0, 0.10)
		else:
			_fail_qte("MISTIMED")

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

write_f('Scripts/Core/QTEBalanceMeter.gd', balance_meter_code)
write_f('Scripts/Core/QTEBreathingCircle.gd', breathing_circle_code)

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

# 1. Chakra
replace_function("QTEManager.gd", "run_chakra_minigame", """func run_chakra_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEBalanceMeter.run(bf, "CHAKRA", "USE LEFT / RIGHT TO KEEP THE MIND CENTERED", 2500)
	var res = await qte.qte_finished
	return res
""")

# 2. Inner Peace
replace_function("QTEManager.gd", "run_inner_peace_minigame", """func run_inner_peace_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte = QTEFastSequence.run(bf, "INNER PEACE", "INPUT THE 4-ARROW MANTRA BEFORE TIME RUNS OUT", 4, 3350, 850) # 850ms reveal + 2500ms input = 3350
	var res = await qte.qte_finished
	return res
""")

# 3. Chi Burst
replace_function("QTEManager.gd", "run_chi_burst_minigame", """func run_chi_burst_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEBreathingCircle.run(bf, "CHI BURST", "PRESS SPACE AT THE ABSOLUTE PEAK", 920, 460)
	var res = await qte.qte_finished
	return res
""")

# Fix the Meteor Storm parameter bug from earlier
with open("QTEManager.gd", 'r', encoding='utf-8') as f:
    text = f.read()
text = text.replace('QTESequenceMemory.run(bf, "METEOR STORM", "MEMORIZE THE 5 ARROWS", 5, 1000)', 'QTESequenceMemory.run(bf, "METEOR STORM", "MEMORIZE THE 5 ARROWS", 5)')
with open("QTEManager.gd", 'w', encoding='utf-8') as f:
    f.write(text)
print("Patched run_meteor_storm_minigame")
