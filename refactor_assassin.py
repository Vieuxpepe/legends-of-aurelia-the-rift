import os
import re

stealth_bar_code = """extends CanvasLayer
class_name QTEStealthBar

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var sweep_duration: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var cursor: ColorRect
var bar_bg: ColorRect
var shadow_band: ColorRect
var perfect_zone: ColorRect

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int
) -> QTEStealthBar:
	var qte = QTEStealthBar.new()
	qte.bf = parent_bf
	qte.sweep_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.02, 0.01, 0.05, 0.85)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.6, 0.3, 0.9))
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

	qte.bar_bg = ColorRect.new()
	qte.bar_bg.size = Vector2(500, 30)
	qte.bar_bg.position = Vector2((vp.x - 500) * 0.5, vp.y * 0.5 - 15)
	qte.bar_bg.color = Color(0.15, 0.15, 0.15, 0.9)
	qte.add_child(qte.bar_bg)

	qte.shadow_band = ColorRect.new()
	qte.shadow_band.size = Vector2(70, 30)
	qte.shadow_band.position = Vector2(randf_range(100.0, 330.0), 0)
	qte.shadow_band.color = Color(0.4, 0.1, 0.8, 0.8)
	qte.bar_bg.add_child(qte.shadow_band)

	qte.perfect_zone = ColorRect.new()
	qte.perfect_zone.size = Vector2(16, 30)
	qte.perfect_zone.position = Vector2((qte.shadow_band.size.x - 16) * 0.5, 0)
	qte.perfect_zone.color = Color(1.0, 0.85, 0.2, 0.9)
	qte.shadow_band.add_child(qte.perfect_zone)

	qte.cursor = ColorRect.new()
	qte.cursor.size = Vector2(6, 46)
	qte.cursor.position = Vector2(0, -8)
	qte.cursor.color = Color.WHITE
	qte.bar_bg.add_child(qte.cursor)

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
		_fail_qte("SPOTTED!")
		return

	var t := timer / sweep_duration
	cursor.position.x = t * (bar_bg.size.x - cursor.size.x)

	if Input.is_action_just_pressed("ui_accept"):
		is_done = true
		end_hold_timer = 0.36
		
		var cursor_center := cursor.position.x + (cursor.size.x * 0.5)
		var band_start := shadow_band.position.x
		var band_end := band_start + shadow_band.size.x
		var perfect_start := band_start + perfect_zone.position.x
		var perfect_end := perfect_start + perfect_zone.size.x

		if cursor_center >= perfect_start and cursor_center <= perfect_end:
			result = 2
			help_lbl.text = "PERFECT STRIKE"
			help_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(14.0, 0.20)
		elif cursor_center >= band_start and cursor_center <= band_end:
			result = 1
			help_lbl.text = "HIDDEN STRIKE"
			help_lbl.add_theme_color_override("font_color", Color(0.6, 0.3, 0.9))
			if bf.get("select_sound") and bf.select_sound.stream != null: 
				bf.select_sound.pitch_scale = 1.2
				bf.select_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(6.0, 0.1)
		else:
			_fail_qte("DEFLECTED")

func _fail_qte(reason: String) -> void:
	result = 0
	is_done = true
	end_hold_timer = 0.36
	help_lbl.text = reason
	help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
"""

multi_target_bar_code = """extends CanvasLayer
class_name QTEMultiTargetBar

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var sweep_duration: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var hits: int = 0

var help_lbl: Label
var cursor: ColorRect
var bar_bg: ColorRect

var vitals: Array[ColorRect] = []
var vital_positions: Array[float] = [100.0, 300.0, 500.0]
var vital_hit: Array[bool] = [false, false, false]

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int
) -> QTEMultiTargetBar:
	var qte = QTEMultiTargetBar.new()
	qte.bf = parent_bf
	qte.sweep_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.15, 0.02, 0.02, 0.8)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
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

	qte.bar_bg = ColorRect.new()
	qte.bar_bg.size = Vector2(600, 20)
	qte.bar_bg.position = Vector2((vp.x - 600) * 0.5, vp.y * 0.5 - 10)
	qte.bar_bg.color = Color(0.05, 0.05, 0.05, 0.9)
	qte.add_child(qte.bar_bg)

	for pos_x in qte.vital_positions:
		var v_dot := ColorRect.new()
		v_dot.size = Vector2(16, 36)
		v_dot.position = Vector2(pos_x, -8)
		v_dot.color = Color(1.0, 0.85, 0.2)
		qte.bar_bg.add_child(v_dot)
		qte.vitals.append(v_dot)

	qte.cursor = ColorRect.new()
	qte.cursor.size = Vector2(6, 40)
	qte.cursor.position = Vector2(0, -10)
	qte.cursor.color = Color.WHITE
	qte.bar_bg.add_child(qte.cursor)

	parent_bf.get_tree().paused = true
	Input.flush_buffered_events()
	
	return qte

func _process(delta: float) -> void:
	if is_done:
		end_hold_timer -= delta
		if end_hold_timer <= 0.0:
			bf.get_tree().paused = false
			qte_finished.emit(hits)
			queue_free()
		return
		
	timer += delta
	if timer >= sweep_duration:
		_end_qte()
		return

	var t := timer / sweep_duration
	cursor.position.x = t * (bar_bg.size.x - cursor.size.x)

	if Input.is_action_just_pressed("ui_accept"):
		var c_center := cursor.position.x + (cursor.size.x * 0.5)
		var matched := false
		
		for i in range(3):
			if vital_hit[i]: continue
			var v_start := vital_positions[i]
			var v_end := v_start + 16.0
			
			if c_center >= v_start - 12.0 and c_center <= v_end + 12.0:
				vital_hit[i] = true
				hits += 1
				matched = true
				vitals[i].color = Color(1.0, 0.2, 0.2)
				
				if bf.get("select_sound") and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.0 + float(hits) * 0.2
					bf.select_sound.play()
				if bf.has_method("screen_shake"): bf.screen_shake(8.0, 0.1)
				break
				
		if not matched:
			if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()

func _end_qte() -> void:
	is_done = true
	end_hold_timer = 0.40
	
	if hits == 3:
		help_lbl.text = "LETHAL ASSASSINATION!"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(20.0, 0.3)
	elif hits > 0:
		help_lbl.text = str(hits) + " VITALS HIT"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	else:
		help_lbl.text = "FAILED"
		help_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
"""

crosshair_pin_code = """extends CanvasLayer
class_name QTECrosshairPin

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var total_duration: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var arena: ColorRect
var target: ColorRect
var cursor_h: ColorRect
var cursor_v: ColorRect
var status: Label

var cursor_pos: Vector2
var cursor_speed: float = 280.0
var target_pos: Vector2
var target_vel: Vector2
var retarget_timer: float = 0.420

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int
) -> QTECrosshairPin:
	var qte = QTECrosshairPin.new()
	qte.bf = parent_bf
	qte.total_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.02, 0.02, 0.05, 0.82)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 60)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.75, 0.55, 1.0))
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

	qte.arena = ColorRect.new()
	qte.arena.size = Vector2(560, 320)
	qte.arena.position = Vector2((vp.x - qte.arena.size.x) * 0.5, (vp.y - qte.arena.size.y) * 0.5 - 10.0)
	qte.arena.color = Color(0.06, 0.06, 0.10, 0.95)
	qte.add_child(qte.arena)

	qte.target = ColorRect.new()
	qte.target.size = Vector2(18, 18)
	qte.target.color = Color(1.0, 0.2, 0.2, 1.0)
	qte.arena.add_child(qte.target)

	qte.cursor_h = ColorRect.new()
	qte.cursor_h.size = Vector2(34, 4)
	qte.cursor_h.color = Color.WHITE
	qte.arena.add_child(qte.cursor_h)

	qte.cursor_v = ColorRect.new()
	qte.cursor_v.size = Vector2(4, 34)
	qte.cursor_v.color = Color.WHITE
	qte.arena.add_child(qte.cursor_v)

	qte.status = Label.new()
	qte.status.text = "TIME: " + str(qte.total_duration)
	qte.status.position = Vector2(0, qte.arena.position.y + qte.arena.size.y + 18.0)
	qte.status.size = Vector2(vp.x, 30)
	qte.status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.status.add_theme_font_size_override("font_size", 22)
	qte.status.add_theme_color_override("font_color", Color.WHITE)
	qte.status.add_theme_constant_override("outline_size", 5)
	qte.status.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.status)

	qte.cursor_pos = qte.arena.size * 0.5
	qte.target_pos = Vector2(
		randf_range(40.0, qte.arena.size.x - 40.0),
		randf_range(40.0, qte.arena.size.y - 40.0)
	)
	qte.target_vel = Vector2(
		randf_range(-180.0, 180.0),
		randf_range(-180.0, 180.0)
	)

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
	status.text = "TIME: %0.2f" % maxf(0.0, total_duration - timer)
	if timer >= total_duration:
		_fail_qte("TOO LATE")
		return

	var move_dir := Vector2.ZERO
	if Input.is_action_pressed("ui_left"): move_dir.x -= 1.0
	if Input.is_action_pressed("ui_right"): move_dir.x += 1.0
	if Input.is_action_pressed("ui_up"): move_dir.y -= 1.0
	if Input.is_action_pressed("ui_down"): move_dir.y += 1.0

	if move_dir.length() > 0.0:
		move_dir = move_dir.normalized()

	cursor_pos += move_dir * cursor_speed * delta
	cursor_pos.x = clampf(cursor_pos.x, 12.0, arena.size.x - 12.0)
	cursor_pos.y = clampf(cursor_pos.y, 12.0, arena.size.y - 12.0)

	retarget_timer -= delta
	if retarget_timer <= 0.0:
		target_vel = target_vel.normalized() * randf_range(140.0, 230.0)
		target_vel = target_vel.rotated(randf_range(-0.75, 0.75))
		retarget_timer = randf_range(0.28, 0.52)

	target_pos += target_vel * delta

	if target_pos.x <= 9.0 or target_pos.x >= arena.size.x - 9.0:
		target_vel.x *= -1.0
		target_pos.x = clampf(target_pos.x, 9.0, arena.size.x - 9.0)
	if target_pos.y <= 9.0 or target_pos.y >= arena.size.y - 9.0:
		target_vel.y *= -1.0
		target_pos.y = clampf(target_pos.y, 9.0, arena.size.y - 9.0)

	target.position = target_pos - target.size * 0.5
	cursor_h.position = cursor_pos - cursor_h.size * 0.5
	cursor_v.position = cursor_pos - cursor_v.size * 0.5

	if Input.is_action_just_pressed("ui_accept"):
		is_done = true
		end_hold_timer = 0.40
		
		var dist := cursor_pos.distance_to(target_pos)

		if dist <= 18.0:
			result = 2
			help_lbl.text = "PERFECT PIN"
			help_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(16.0, 0.22)
		elif dist <= 45.0:
			result = 1
			help_lbl.text = "GLANCING PIN"
			help_lbl.add_theme_color_override("font_color", Color(0.75, 0.55, 1.0))
			if bf.get("select_sound") and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.15
				bf.select_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(6.0, 0.1)
		else:
			_fail_qte("MISSED")

func _fail_qte(reason: String) -> void:
	result = 0
	is_done = true
	end_hold_timer = 0.40
	help_lbl.text = reason
	help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
"""

def write_f(path, content):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content.strip() + "\n")
    print("Wrote " + path)

write_f('Scripts/Core/QTEStealthBar.gd', stealth_bar_code)
write_f('Scripts/Core/QTEMultiTargetBar.gd', multi_target_bar_code)
write_f('Scripts/Core/QTECrosshairPin.gd', crosshair_pin_code)

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

# 1. Shadow Strike
replace_function("QTEManager.gd", "run_shadow_strike_minigame", """func run_shadow_strike_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEStealthBar.run(bf, "SHADOW STRIKE", "PRESS SPACE INSIDE THE SHADOW BAND", 700)
	var res = await qte.qte_finished
	return res
""")

# 2. Assassinate
replace_function("QTEManager.gd", "run_assassinate_minigame", """func run_assassinate_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEMultiTargetBar.run(bf, "ASSASSINATE", "TAP SPACE ON THE 3 VITAL POINTS!", 1500)
	var res = await qte.qte_finished
	return res
""")

# 3. Shadow Pin
replace_function("QTEManager.gd", "run_shadow_pin_minigame", """func run_shadow_pin_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTECrosshairPin.run(bf, "SHADOW PIN", "TRACK THE DOT WITH ARROWS — PRESS SPACE ON TARGET", 2600)
	var res = await qte.qte_finished
	return res
""")

# 4. Ultimate Shadow Step
replace_function("QTEManager.gd", "run_ultimate_shadow_step_minigame", """func run_ultimate_shadow_step_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEReactionStrike.run(bf, "ULTIMATE SHADOW STEP", "PRESS THE ARROW AS SOON AS IT APPEARS!", 4, 550)
	var res = await qte.qte_finished
	return res
""")
