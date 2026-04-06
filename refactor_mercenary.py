import os
import re

hold_release_code = """extends CanvasLayer
class_name QTEHoldReleaseBar

signal qte_finished(result: int)

var bf: Node2D
var fill_duration: float
var timer: float = 0.0
var wait_timer: float = 0.0
var result: int = 0
var is_done: bool = false
var end_hold_timer: float = -1.0
var started_charging: bool = false

var help_lbl: Label
var fill: ColorRect
var outer_good: ColorRect
var perfect_zone: ColorRect

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	fill_ms: int
) -> QTEHoldReleaseBar:
	var qte = QTEHoldReleaseBar.new()
	qte.bf = parent_bf
	qte.fill_duration = fill_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.12, 0.05, 0.02, 0.68)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30))
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

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.96)
	bar_bg.size = Vector2(520, 34)
	bar_bg.position = Vector2((vp.x - bar_bg.size.x) * 0.5, vp.y * 0.5 - 10.0)
	qte.add_child(bar_bg)

	qte.outer_good = ColorRect.new()
	qte.outer_good.color = Color(0.25, 0.9, 0.25, 0.95)
	qte.outer_good.size = Vector2(40, 34)
	qte.outer_good.position = Vector2(410, 0)
	bar_bg.add_child(qte.outer_good)

	qte.perfect_zone = ColorRect.new()
	qte.perfect_zone.color = Color(1.0, 0.86, 0.2, 0.98)
	qte.perfect_zone.size = Vector2(14, 34)
	qte.perfect_zone.position = Vector2((qte.outer_good.size.x - qte.perfect_zone.size.x) * 0.5, 0)
	qte.outer_good.add_child(qte.perfect_zone)

	qte.fill = ColorRect.new()
	qte.fill.color = Color(1.0, 0.74, 0.25, 1.0)
	qte.fill.size = Vector2(0, 34)
	bar_bg.add_child(qte.fill)
	
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
		
	if not started_charging:
		wait_timer += delta
		if Input.is_action_pressed("ui_accept"):
			started_charging = true
		elif wait_timer > 2.0:
			_finish_qte(0)
		return

	timer += delta
	var t := clampf(timer / fill_duration, 0.0, 1.0)
	var bar_w = 520.0
	fill.size.x = t * bar_w
	
	if Input.is_action_just_released("ui_accept") or t >= 1.0:
		var fill_end := fill.size.x
		var good_start := outer_good.position.x
		var good_end := good_start + outer_good.size.x
		var perfect_start := good_start + perfect_zone.position.x
		var perfect_end := perfect_start + perfect_zone.size.x

		if fill_end >= perfect_start and fill_end <= perfect_end:
			_finish_qte(2)
		elif fill_end >= good_start and fill_end <= good_end:
			_finish_qte(1)
		else:
			_finish_qte(0)

func _finish_qte(res: int) -> void:
	result = res
	is_done = true
	end_hold_timer = 0.35
	
	if result == 2:
		help_lbl.text = "PERFECT SHOUT"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.20))
		fill.color = Color(1.0, 0.85, 0.20)
		if bf.get("crit_sound") and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		if bf.has_method("screen_shake"):
			bf.screen_shake(15.0, 0.22)
	elif result == 1:
		help_lbl.text = "GOOD SHOUT"
		help_lbl.add_theme_color_override("font_color", Color(0.30, 1.0, 0.35))
		if bf.get("select_sound") and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.25
			bf.select_sound.play()
		if bf.has_method("screen_shake"):
			bf.screen_shake(8.0, 0.12)
	else:
		help_lbl.text = "FAILED"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
		fill.color = Color(0.90, 0.20, 0.20)
		if bf.get("miss_sound") and bf.miss_sound.stream != null:
			bf.miss_sound.play()
"""

multi_tap_code = """extends CanvasLayer
class_name QTEMultiTapDial

signal qte_finished(result: int)

var bf: Node2D
var sweep_speed: float
var duration_limit: float
var timer: float = 0.0
var result: int = 0
var is_done: bool = false
var end_hold_timer: float = -1.0

var help_lbl: Label
var needle: ColorRect
var target_dots: Array[ColorRect] = []
var hit_flags: Array[bool] = []
var target_angles: Array[float] = []
var hits: int = 0

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	angles: Array,
	speed: float,
	max_duration_ms: int
) -> QTEMultiTapDial:
	var qte = QTEMultiTapDial.new()
	qte.bf = parent_bf
	qte.sweep_speed = speed
	qte.duration_limit = max_duration_ms / 1000.0
	for a in angles:
		qte.target_angles.append(float(a))
		qte.hit_flags.append(false)
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.04, 0.06, 0.10, 0.72)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 60)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.text = help_text
	qte.help_lbl.position = Vector2(0, 105)
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

	var dial := Panel.new()
	dial.size = Vector2(320, 320)
	dial.position = Vector2((vp.x - 320) * 0.5, (vp.y - 320) * 0.5 - 10)
	var dial_style := StyleBoxFlat.new()
	dial_style.bg_color = Color(0.06, 0.06, 0.06, 0.96)
	dial_style.border_width_left = 4
	dial_style.border_width_top = 4
	dial_style.border_width_right = 4
	dial_style.border_width_bottom = 4
	dial_style.border_color = Color(0.75, 0.75, 0.8, 0.85)
	dial_style.corner_radius_top_left = 180
	dial_style.corner_radius_top_right = 180
	dial_style.corner_radius_bottom_left = 180
	dial_style.corner_radius_bottom_right = 180
	dial.add_theme_stylebox_override("panel", dial_style)
	qte.add_child(dial)

	var pivot := ColorRect.new()
	pivot.size = Vector2(12, 12)
	pivot.position = dial.size * 0.5 - Vector2(6, 6)
	pivot.color = Color.WHITE
	dial.add_child(pivot)

	var radius := 118.0
	for angle_deg in qte.target_angles:
		var dot := ColorRect.new()
		dot.size = Vector2(18, 18)
		var rad := deg_to_rad(angle_deg - 90.0)
		var center_pos := dial.size * 0.5 + Vector2(cos(rad), sin(rad)) * radius
		dot.position = center_pos - dot.size * 0.5
		dot.color = Color(1.0, 0.86, 0.2, 1.0)
		dial.add_child(dot)
		qte.target_dots.append(dot)

	qte.needle = ColorRect.new()
	qte.needle.size = Vector2(6, 128)
	qte.needle.position = dial.size * 0.5 - Vector2(3, 114)
	qte.needle.pivot_offset = Vector2(3, 114)
	qte.needle.color = Color(0.85, 0.95, 1.0, 1.0)
	dial.add_child(qte.needle)
	
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
	if timer >= duration_limit:
		_finish_qte()
		return

	var angle: float = wrapf(timer * sweep_speed, 0.0, 360.0)
	needle.rotation_degrees = angle
	
	if Input.is_action_just_pressed("ui_accept"):
		var found := false
		for i in range(target_angles.size()):
			if hit_flags[i]:
				continue
			var diff: float = float(abs(wrapf(angle - target_angles[i], -180.0, 180.0)))
			if diff <= 12.0:
				hit_flags[i] = true
				hits += 1
				target_dots[i].color = Color(0.35, 1.0, 0.35, 1.0)
				found = true
				if bf.get("select_sound") and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.15 + float(hits) * 0.08
					bf.select_sound.play()
				break
		
		if not found:
			if bf.get("miss_sound") and bf.miss_sound.stream != null:
				bf.miss_sound.play()

		if hits >= target_angles.size():
			_finish_qte()

func _finish_qte() -> void:
	is_done = true
	end_hold_timer = 0.40
	
	if hits >= target_angles.size():
		result = 2
		help_lbl.text = "PERFECT TEMPEST"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		if bf.has_method("screen_shake"):
			bf.screen_shake(14.0, 0.20)
	elif hits >= target_angles.size() - 1:
		result = 1
		help_lbl.text = "GOOD TEMPEST"
		help_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		if bf.get("select_sound") and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.2
			bf.select_sound.play()
		if bf.has_method("screen_shake"):
			bf.screen_shake(7.0, 0.10)
	else:
		result = 0
		help_lbl.text = "FAILED"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.get("miss_sound") and bf.miss_sound.stream != null:
			bf.miss_sound.play()
"""


def write_file(path, content):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content.strip() + "\\n")
    print(f"Created {path}")

write_file('Scripts/Core/QTEHoldReleaseBar.gd', hold_release_code)
write_file('Scripts/Core/QTEMultiTapDial.gd', multi_tap_code)

def replace_function(file_path, func_name, new_code):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    pattern = r"func " + func_name + r"\(bf: Node2D, attacker: Node2D\) -> int:.*?(?=\nfunc [a-zA-Z_]+\(bf: Node2D|\Z)"
    match = re.search(pattern, content, re.DOTALL)
    
    if match:
        content = content[:match.start()] + new_code + "\\n" + content[match.end():]
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Replaced {func_name}")
        return True
    else:
        print(f"Could not find {func_name}")
        return False

# Flurry Strike Replacement -> QTEMashMeter
flurry_strike_code = """func run_flurry_strike_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEMashMeter.run(bf, "FLURRY STRIKE", "TAP SPACE AS FAST AS POSSIBLE", 1500, 10, 14)
	var res = await qte.qte_finished
	return res
"""
replace_function("QTEManager.gd", "run_flurry_strike_minigame", flurry_strike_code)

# Battle Cry Replacement -> QTEHoldReleaseBar
battle_cry_code = """func run_battle_cry_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEHoldReleaseBar.run(bf, "BATTLE CRY", "HOLD SPACE — RELEASE IN THE TINY GREEN WINDOW", 1500)
	var res = await qte.qte_finished
	return res
"""
replace_function("QTEManager.gd", "run_battle_cry_minigame", battle_cry_code)

# Blade Tempest Replacement -> QTEMultiTapDial
blade_tempest_code = """func run_blade_tempest_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEMultiTapDial.run(bf, "BLADE TEMPEST", "TAP SPACE AS THE NEEDLE PASSES THE 3 GOLD ZONES", [20.0, 150.0, 285.0], 420.0, 2600)
	var res = await qte.qte_finished
	return res
"""
replace_function("QTEManager.gd", "run_blade_tempest_minigame", blade_tempest_code)

# Power Strike Replacement -> QTETimingBar
power_strike_code = """func run_power_strike_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTETimingBar.run(bf, "POWER STRIKE", "PRESS SPACE AT MAX POWER", 1300)
	
	# Override position
	qte.outer_good.position.x = 520.0 - 120.0 # From original bar width
	qte.outer_good.size.x = 120.0
	qte.perfect_zone.position.x = 90.0
	qte.perfect_zone.size.x = 24.0
	
	var res = await qte.qte_finished
	return res
"""
replace_function("QTEManager.gd", "run_power_strike_minigame", power_strike_code)
