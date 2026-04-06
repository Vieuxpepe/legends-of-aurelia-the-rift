import os
import re

# 1. QTEExpandingRing.gd
expanding_ring_code = """extends CanvasLayer
class_name QTEExpandingRing

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var total_duration: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var target_ring: Panel
var core: ColorRect
var target_style: StyleBoxFlat

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int
) -> QTEExpandingRing:
	var qte = QTEExpandingRing.new()
	qte.bf = parent_bf
	qte.total_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.15, 0.05, 0.0, 0.7)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
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

	var center := vp * 0.5 + Vector2(0, 30)

	qte.target_ring = Panel.new()
	qte.target_ring.size = Vector2(240, 240)
	qte.target_ring.position = center - qte.target_ring.size * 0.5
	qte.target_style = StyleBoxFlat.new()
	qte.target_style.bg_color = Color(0, 0, 0, 0)
	qte.target_style.border_width_left = 6
	qte.target_style.border_width_top = 6
	qte.target_style.border_width_right = 6
	qte.target_style.border_width_bottom = 6
	qte.target_style.border_color = Color(1.0, 0.6, 0.2, 0.8)
	qte.target_style.corner_radius_top_left = 120
	qte.target_style.corner_radius_top_right = 120
	qte.target_style.corner_radius_bottom_left = 120
	qte.target_style.corner_radius_bottom_right = 120
	qte.target_ring.add_theme_stylebox_override("panel", qte.target_style)
	qte.add_child(qte.target_ring)

	qte.core = ColorRect.new()
	qte.core.size = Vector2(40, 40)
	qte.core.position = center - qte.core.size * 0.5
	qte.core.color = Color(1.0, 0.9, 0.5, 1.0)
	qte.add_child(qte.core)

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
		
	if Input.is_action_just_pressed("ui_accept"):
		_resolve_qte()
		return

	timer += delta
	if timer >= total_duration:
		_fail_qte("OVERCHARGED")
		return

	var progress := clampf(timer / total_duration, 0.0, 1.0)
	var current_size := lerpf(40.0, 300.0, progress)
	core.size = Vector2(current_size, current_size)
	var center := bf.get_viewport_rect().size * 0.5 + Vector2(0, 30)
	core.position = center - core.size * 0.5

	if Input.is_action_just_released("ui_accept"):
		_resolve_qte()

func _resolve_qte() -> void:
	if is_done: return
	is_done = true
	end_hold_timer = 0.40
	
	var diff := absf(core.size.x - 240.0)
	if diff <= 15.0:
		result = 2
		help_lbl.text = "PERFECT SHATTER!"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		target_style.border_color = Color.WHITE
		core.color = Color.WHITE
		if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(20.0, 0.35)
	elif diff <= 45.0:
		result = 1
		help_lbl.text = "HEAVY IMPACT"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		if bf.get("select_sound") and bf.select_sound.stream != null: 
			bf.select_sound.pitch_scale = 0.7
			bf.select_sound.play()
		if bf.has_method("screen_shake"): bf.screen_shake(10.0, 0.2)
	else:
		_fail_qte("WEAK IMPACT")

func _fail_qte(reason: String) -> void:
	result = 0
	is_done = true
	end_hold_timer = 0.40
	help_lbl.text = reason
	help_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
"""

# 2. QTEClashTiming.gd
clash_timing_code = """extends CanvasLayer
class_name QTEClashTiming

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var sweep_duration: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var track: ColorRect
var left_block: ColorRect
var right_block: ColorRect

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int
) -> QTEClashTiming:
	var qte = QTEClashTiming.new()
	qte.bf = parent_bf
	qte.sweep_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.05, 0.06, 0.08, 0.86)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
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

	qte.track = ColorRect.new()
	qte.track.size = Vector2(620, 120)
	qte.track.position = Vector2((vp.x - 620) * 0.5, (vp.y - 120) * 0.5 - 10)
	qte.track.color = Color(0.10, 0.10, 0.10, 0.96)
	qte.add_child(qte.track)

	var center_line := ColorRect.new()
	center_line.size = Vector2(6, 120)
	center_line.position = Vector2((620 - 6) * 0.5, 0)
	center_line.color = Color.WHITE
	qte.track.add_child(center_line)

	qte.left_block = ColorRect.new()
	qte.left_block.size = Vector2(110, 120)
	qte.left_block.color = Color(0.55, 0.60, 0.68, 1.0)
	qte.track.add_child(qte.left_block)

	qte.right_block = ColorRect.new()
	qte.right_block.size = Vector2(110, 120)
	qte.right_block.color = Color(0.55, 0.60, 0.68, 1.0)
	qte.track.add_child(qte.right_block)

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
		_fail_qte("MISSED THE CLASH")
		return

	var t := timer / sweep_duration
	left_block.position.x = lerpf(-110.0, 310.0 - 110.0, t)
	right_block.position.x = lerpf(620.0, 310.0, t)

	if Input.is_action_just_pressed("ui_accept"):
		is_done = true
		end_hold_timer = 0.36
		var gap := absf((left_block.position.x + 110.0) - right_block.position.x)
		
		if gap <= 10.0:
			result = 2
			help_lbl.text = "SHATTERED"
			help_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			left_block.color = Color.WHITE
			right_block.color = Color.WHITE
			if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(18.0, 0.24)
		else:
			_fail_qte("FAILED")

func _fail_qte(reason: String) -> void:
	result = 0
	is_done = true
	end_hold_timer = 0.36
	help_lbl.text = reason
	help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
"""

# 3. QTEOscillationStop.gd
oscillation_stop_code = """extends CanvasLayer
class_name QTEOscillationStop

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var sweep_duration: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var needle: ColorRect
var sweet_dot: ColorRect

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int
) -> QTEOscillationStop:
	var qte = QTEOscillationStop.new()
	qte.bf = parent_bf
	qte.sweep_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.14, 0.03, 0.02, 0.84)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 70)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.25))
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

	var dial := Panel.new()
	dial.size = Vector2(340, 340)
	dial.position = Vector2((vp.x - 340) * 0.5, (vp.y - 340) * 0.5 - 10)
	var dial_style := StyleBoxFlat.new()
	dial_style.bg_color = Color(0.08, 0.08, 0.08, 0.96)
	dial_style.border_width_left = 4; dial_style.border_width_top = 4
	dial_style.border_width_right = 4; dial_style.border_width_bottom = 4
	dial_style.border_color = Color(0.70, 0.70, 0.75, 0.85)
	dial_style.corner_radius_top_left = 180; dial_style.corner_radius_top_right = 180
	dial_style.corner_radius_bottom_left = 180; dial_style.corner_radius_bottom_right = 180
	dial.add_theme_stylebox_override("panel", dial_style)
	qte.add_child(dial)

	var pivot := ColorRect.new()
	pivot.size = Vector2(12, 12); pivot.position = Vector2(170-6, 170-6); pivot.color = Color.WHITE
	dial.add_child(pivot)

	qte.sweet_dot = ColorRect.new()
	qte.sweet_dot.size = Vector2(22, 22); qte.sweet_dot.position = Vector2(170-11, 18); qte.sweet_dot.color = Color(1.0, 0.85, 0.2, 1.0)
	dial.add_child(qte.sweet_dot)

	qte.needle = ColorRect.new()
	qte.needle.size = Vector2(8, 132); qte.needle.position = Vector2(170-4, 170-118); qte.needle.pivot_offset = Vector2(4, 118); qte.needle.color = Color(1.0, 0.72, 0.28, 1.0)
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
	if timer >= sweep_duration:
		_fail_qte("TOO SLOW")
		return

	var current_angle := sin(timer * 12.5) * 82.0
	needle.rotation_degrees = current_angle

	if Input.is_action_just_pressed("ui_accept"):
		is_done = true
		end_hold_timer = 0.36
		var diff := absf(current_angle)
		
		if diff <= 4.0:
			result = 3; help_lbl.text = "MAX TOSS"; help_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			needle.color = Color.WHITE; sweet_dot.color = Color.WHITE
			if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(18.0, 0.26)
		elif diff <= 10.0:
			result = 2; help_lbl.text = "HEAVY TOSS"; help_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
			needle.color = Color(0.35, 1.0, 0.35)
			if bf.get("select_sound") and bf.select_sound.stream != null: 
				bf.select_sound.pitch_scale = 1.18; bf.select_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(10.0, 0.14)
		elif diff <= 18.0:
			result = 1; help_lbl.text = "LIGHT TOSS"; help_lbl.add_theme_color_override("font_color", Color(1.0, 0.70, 0.30))
			needle.color = Color(1.0, 0.70, 0.30)
			if bf.get("select_sound") and bf.select_sound.stream != null: 
				bf.select_sound.pitch_scale = 1.08; bf.select_sound.play()
			if bf.has_method("screen_shake"): bf.screen_shake(6.0, 0.08)
		else:
			_fail_qte("WHIFFED")

func _fail_qte(reason: String) -> void:
	result = 0
	is_done = true
	end_hold_timer = 0.36
	help_lbl.text = reason
	help_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
"""

# 4. QTEComboRush.gd
combo_rush_code = """extends CanvasLayer
class_name QTEComboRush

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var total_duration: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var combos_completed: int = 0

var help_lbl: Label
var labels: Array[Label] = []
var sequence: Array[int] = []
var current_step: int = 0

var actions := ["ui_up", "ui_down", "ui_left", "ui_right"]
var names := ["UP", "DOWN", "LEFT", "RIGHT"]

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int
) -> QTEComboRush:
	var qte = QTEComboRush.new()
	qte.bf = parent_bf
	qte.total_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.06, 0.08, 0.12, 0.84)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text; title.position = Vector2(0, 60); title.size = Vector2(vp.x, 42); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42); title.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	title.add_theme_constant_override("outline_size", 8); title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.text = help_text; qte.help_lbl.position = Vector2(0, 105); qte.help_lbl.size = Vector2(vp.x, 30); qte.help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.help_lbl.add_theme_font_size_override("font_size", 22); qte.help_lbl.add_theme_color_override("font_color", Color.WHITE)
	qte.help_lbl.add_theme_constant_override("outline_size", 6); qte.help_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.help_lbl)

	if parent_bf.has_node("/root/QTEManager"):
		var mgr = parent_bf.get_node("/root/QTEManager")
		if mgr.has_method("_apply_qte_visual_overhaul"):
			mgr._apply_qte_visual_overhaul(qte, title, qte.help_lbl)

	var panel := ColorRect.new()
	panel.size = Vector2(760, 230); panel.position = Vector2((vp.x-760)*0.5, (vp.y-230)*0.5-10); panel.color = Color(0.08, 0.08, 0.08, 0.96)
	qte.add_child(panel)

	for i in range(4):
		var lbl := Label.new()
		lbl.position = Vector2(30 + i * 180, 50); lbl.size = Vector2(160, 60); lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; lbl.add_theme_font_size_override("font_size", 34)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25)); lbl.add_theme_constant_override("outline_size", 6)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		panel.add_child(lbl); qte.labels.append(lbl)

	qte._generate_sequence()
	parent_bf.get_tree().paused = true
	Input.flush_buffered_events()
	
	return qte

func _generate_sequence() -> void:
	sequence.clear()
	for i in range(4):
		var idx := randi() % 4
		sequence.append(idx)
		labels[i].text = names[idx]
		labels[i].add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	current_step = 0

func _process(delta: float) -> void:
	if is_done:
		end_hold_timer -= delta
		if end_hold_timer <= 0.0:
			bf.get_tree().paused = false
			qte_finished.emit(combos_completed)
			queue_free()
		return
		
	timer += delta
	if timer >= total_duration:
		is_done = true; end_hold_timer = 0.40
		help_lbl.text = "TIME EXPIRED"; return

	var pressed := -1
	for i in range(4):
		if Input.is_action_just_pressed(actions[i]): pressed = i; break
		
	if pressed != -1:
		if pressed == sequence[current_step]:
			labels[current_step].add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
			current_step += 1
			if bf.get("select_sound") and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.0 + current_step * 0.15; bf.select_sound.play()
			
			if current_step >= 4:
				combos_completed += 1
				help_lbl.text = "COMBOS: " + str(combos_completed)
				if combos_completed % 2 == 0: bf.screen_shake(8.0, 0.1)
				_generate_sequence()
		else:
			if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
			_generate_sequence()
"""

# 5. QTESniperZoom.gd
sniper_zoom_code = """extends CanvasLayer
class_name QTESniperZoom

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var total_duration: float
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var target_dot: ColorRect
var cross_h: ColorRect
var cross_v: ColorRect
var status_lbl: Label

var target_pos: Vector2
var target_vel: Vector2
var cross_pos: Vector2
var cross_size: float = 76.0
var next_dir_timer: float = 0.26
var shot_fired: bool = false
var arena_size := Vector2(700, 380)

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	duration_ms: int
) -> QTESniperZoom:
	var qte = QTESniperZoom.new()
	qte.bf = parent_bf
	qte.total_duration = duration_ms / 1000.0
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.08, 0.08, 0.10, 0.96); dimmer.size = vp; qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text; title.position = Vector2(0, 80); title.size = Vector2(vp.x, 40); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42); title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_constant_override("outline_size", 8); title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.text = help_text; qte.help_lbl.position = Vector2(0, 130); qte.help_lbl.size = Vector2(vp.x, 30); qte.help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.help_lbl.add_theme_font_size_override("font_size", 22); qte.help_lbl.add_theme_color_override("font_color", Color.WHITE)
	qte.help_lbl.add_theme_constant_override("outline_size", 6); qte.help_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.help_lbl)

	if parent_bf.has_node("/root/QTEManager"):
		var mgr = parent_bf.get_node("/root/QTEManager")
		if mgr.has_method("_apply_qte_visual_overhaul"):
			mgr._apply_qte_visual_overhaul(qte, title, qte.help_lbl)

	var arena := ColorRect.new()
	arena.size = qte.arena_size; arena.position = (vp - qte.arena_size)*0.5 - Vector2(0,10); arena.color = Color(0.08, 0.08, 0.10, 1.0)
	qte.add_child(arena)

	qte.target_dot = ColorRect.new(); qte.target_dot.size = Vector2(10, 10); qte.target_dot.color = Color(1, 0.2, 0.2); arena.add_child(qte.target_dot)
	qte.cross_h = ColorRect.new(); qte.cross_h.color = Color.WHITE; arena.add_child(qte.cross_h)
	qte.cross_v = ColorRect.new(); qte.cross_v.color = Color.WHITE; arena.add_child(qte.cross_v)

	qte.status_lbl = Label.new(); qte.status_lbl.position = Vector2(0, arena.position.y+qte.arena_size.y+16); qte.status_lbl.size = Vector2(vp.x, 30); qte.status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.status_lbl.add_theme_font_size_override("font_size", 24); qte.status_lbl.add_theme_color_override("font_color", Color.WHITE); qte.add_child(qte.status_lbl)

	qte.target_pos = qte.arena_size * Vector2(0.65, 0.40); qte.target_vel = Vector2(155, 105); qte.cross_pos = qte.arena_size * 0.5
	parent_bf.get_tree().paused = true; Input.flush_buffered_events()
	
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
		_fail_qte("NO SHOT FIRED"); return

	next_dir_timer -= delta
	if next_dir_timer <= 0.0:
		target_vel = Vector2(randf_range(-210, 210), randf_range(-160, 160)); next_dir_timer = 0.24

	target_pos += target_vel * delta
	if target_pos.x <= 8 or target_pos.x >= arena_size.x-8: target_vel.x *= -1.0
	if target_pos.y <= 8 or target_pos.y >= arena_size.y-8: target_vel.y *= -1.0
	target_dot.position = target_pos - Vector2(5, 5)

	var move_input := Vector2.ZERO
	if Input.is_action_pressed("ui_left"): move_input.x -= 1
	if Input.is_action_pressed("ui_right"): move_input.x += 1
	if Input.is_action_pressed("ui_up"): move_input.y -= 1
	if Input.is_action_pressed("ui_down"): move_input.y += 1

	var is_zooming := Input.is_action_pressed("ui_accept")
	var move_speed := 180.0 if is_zooming else 320.0
	var target_cross_size := 30.0 if is_zooming else 76.0
	cross_size = lerpf(cross_size, target_cross_size, 0.18)

	cross_pos += move_input.normalized() * move_speed * delta
	cross_pos.x = clampf(cross_pos.x, cross_size*0.5, arena_size.x - cross_size*0.5)
	cross_pos.y = clampf(cross_pos.y, cross_size*0.5, arena_size.y - cross_size*0.5)

	cross_h.size = Vector2(cross_size, 2); cross_h.position = Vector2(cross_pos.x - cross_size*0.5, cross_pos.y - 1)
	cross_v.size = Vector2(2, cross_size); cross_v.position = Vector2(cross_pos.x - 1, cross_pos.y - cross_size*0.5)
	status_lbl.text = "TARGET DISTANCE: %0.1f" % cross_pos.distance_to(target_pos)

	if Input.is_action_just_released("ui_accept"):
		_fire_shot()

func _fire_shot() -> void:
	if is_done: return
	is_done = true; end_hold_timer = 0.40
	var dist := cross_pos.distance_to(target_pos)
	if cross_size <= 40.0 and dist <= 8.0:
		result = 2; help_lbl.text = "BULLSEYE"; help_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
		bf.screen_shake(14.0, 0.18)
	elif cross_size <= 52.0 and dist <= 22.0:
		result = 1; help_lbl.text = "GLANCING HIT"; help_lbl.add_theme_color_override("font_color", Color(0.35, 1, 0.35))
		if bf.get("select_sound") and bf.select_sound.stream != null: 
			bf.select_sound.pitch_scale = 1.18; bf.select_sound.play()
		bf.screen_shake(7.0, 0.1)
	else:
		_fail_qte("MISSED SHOT")

func _fail_qte(reason: String) -> void:
	result = 0; is_done = true; end_hold_timer = 0.40; help_lbl.text = reason
	help_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
"""

# 6. QTECrossAlignment.gd
cross_alignment_code = """extends CanvasLayer
class_name QTECrossAlignment

signal qte_finished(result: int)

var bf: Node2D
var timer: float = 0.0
var is_done: bool = false
var end_hold_timer: float = -1.0
var result: int = 0

var help_lbl: Label
var h_cursor: ColorRect
var v_cursor: ColorRect
var h_bar: ColorRect
var v_bar: ColorRect

var h_locked := false
var v_locked := false
var h_pos := 0.0
var v_pos := 0.0

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String
) -> QTECrossAlignment:
	var qte = QTECrossAlignment.new()
	qte.bf = parent_bf
	qte.layer = 240; qte.process_mode = Node.PROCESS_MODE_ALWAYS; parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new(); dimmer.color = Color(0.06, 0.06, 0.10, 0.88); dimmer.size = vp; qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text; title.position = Vector2(0, 58); title.size = Vector2(vp.x, 42); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42); title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	title.add_theme_constant_override("outline_size", 8); title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.text = help_text; qte.help_lbl.position = Vector2(0, 102); qte.help_lbl.size = Vector2(vp.x, 28); qte.help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.help_lbl.add_theme_font_size_override("font_size", 22); qte.help_lbl.add_theme_color_override("font_color", Color.WHITE)
	qte.help_lbl.add_theme_constant_override("outline_size", 6); qte.help_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.help_lbl)

	if parent_bf.has_node("/root/QTEManager"):
		var mgr = parent_bf.get_node("/root/QTEManager")
		if mgr.has_method("_apply_qte_visual_overhaul"):
			mgr._apply_qte_visual_overhaul(qte, title, qte.help_lbl)

	var center := vp * 0.5 + Vector2(0, 18)
	qte.h_bar = ColorRect.new(); qte.h_bar.size = Vector2(520, 28); qte.h_bar.position = Vector2(center.x-260, center.y-14); qte.h_bar.color = Color(0.08, 0.08, 0.08, 0.96); qte.add_child(qte.h_bar)
	qte.v_bar = ColorRect.new(); qte.v_bar.size = Vector2(28, 320); qte.v_bar.position = Vector2(center.x-14, center.y-160); qte.v_bar.color = Color(0.08, 0.08, 0.08, 0.96); qte.add_child(qte.v_bar)
	
	var hc := ColorRect.new(); hc.size = Vector2(4, 28); hc.position = Vector2(258, 0); hc.color = Color.WHITE; qte.h_bar.add_child(hc)
	var vc := ColorRect.new(); vc.size = Vector2(28, 4); vc.position = Vector2(0, 158); vc.color = Color.WHITE; qte.v_bar.add_child(vc)

	qte.h_cursor = ColorRect.new(); qte.h_cursor.size = Vector2(10, 36); qte.h_cursor.position = Vector2(0,-4); qte.h_cursor.color = Color(1, 0.8, 0.3); qte.h_bar.add_child(qte.h_cursor)
	qte.v_cursor = ColorRect.new(); qte.v_cursor.size = Vector2(36, 10); qte.v_cursor.position = Vector2(-4,0); qte.v_cursor.color = Color(1, 0.8, 0.3); qte.v_bar.add_child(qte.v_cursor)

	parent_bf.get_tree().paused = true; Input.flush_buffered_events(); return qte

func _process(delta: float) -> void:
	if is_done:
		end_hold_timer -= delta
		if end_hold_timer <= 0.0:
			bf.get_tree().paused = false; qte_finished.emit(result); queue_free()
		return
		
	timer += delta
	if not h_locked:
		h_pos = (sin(timer * 4.5) * 0.5 + 0.5) * h_bar.size.x
		h_cursor.position.x = h_pos - 5
		if Input.is_action_just_pressed("ui_accept"):
			h_locked = true; h_cursor.color = Color.WHITE
			if bf.get("select_sound") and bf.select_sound.stream != null: bf.select_sound.play()
	elif not v_locked:
		v_pos = (sin(timer * 5.5) * 0.5 + 0.5) * v_bar.size.y
		v_cursor.position.y = v_pos - 5
		if Input.is_action_just_pressed("ui_accept"):
			v_locked = true; v_cursor.color = Color.WHITE
			_evaluate()
	
	if timer > 6.0: _evaluate()

func _evaluate() -> void:
	if is_done: return
	is_done = true; end_hold_timer = 0.40
	var h_diff := absf(h_pos - h_bar.size.x * 0.5)
	var v_diff := absf(v_pos - v_bar.size.y * 0.5)
	
	if h_diff <= 14.0 and v_diff <= 14.0:
		result = 2; help_lbl.text = "PERFECT CROSS"; help_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		if bf.get("crit_sound") and bf.crit_sound.stream != null: bf.crit_sound.play()
		bf.screen_shake(16.0, 0.25)
	elif h_diff <= 40.0 and v_diff <= 40.0:
		result = 1; help_lbl.text = "PARTIAL ALIGNMENT"; help_lbl.add_theme_color_override("font_color", Color(0.35, 1, 0.35))
		if bf.get("select_sound") and bf.select_sound.stream != null: bf.select_sound.play()
		bf.screen_shake(8.0, 0.12)
	else:
		result = 0; help_lbl.text = "MISSED"; help_lbl.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		if bf.get("miss_sound") and bf.miss_sound.stream != null: bf.miss_sound.play()
"""

def write_f(path, content):
    with open(path, 'w', encoding='utf-8') as f: f.write(content.strip() + "\n")
    print("Wrote " + path)

# Create templates
write_f('Scripts/Core/QTEExpandingRing.gd', expanding_ring_code)
write_f('Scripts/Core/QTEClashTiming.gd', clash_timing_code)
write_f('Scripts/Core/QTEOscillationStop.gd', oscillation_stop_code)
write_f('Scripts/Core/QTEComboRush.gd', combo_rush_code)
write_f('Scripts/Core/QTESniperZoom.gd', sniper_zoom_code)
write_f('Scripts/Core/QTECrossAlignment.gd', cross_alignment_code)

def replace_func(file_path, func_name, new_code):
	with open(file_path, 'r', encoding='utf-8') as f: content = f.read()
	# Standardize pattern for bf: Node2D, (attacker|defender): Node2D
	pattern = r"func " + func_name + r"\(bf: Node2D, (attacker|defender): Node2D\) -> int:.*?(?=\nfunc [a-zA-Z_]+\(bf: Node2D|\Z)"
	match = re.search(pattern, content, re.DOTALL)
	if match:
		content = content[:match.start()] + new_code + "\n" + content[match.end():]
		with open(file_path, 'w', encoding='utf-8') as f: f.write(content)
		print(f"Replaced {func_name}")
		return True
	return False

# REFACTORS
# 1. Charge
replace_func("QTEManager.gd", "run_charge_minigame", """func run_charge_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEHoldReleaseBar.run(bf, "CHARGE", "HOLD SPACE, RELEASE IN GREEN", 1400)
	qte.green_zone.position.x = 365.0; qte.green_zone.size.x = 70.0
	qte.perfect_zone.size.x = 22.0
	var res = await qte.qte_finished
	return res
""")

# 2. Shield Bash
replace_func("QTEManager.gd", "run_shield_bash_minigame", """func run_shield_bash_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte = QTESequenceMemory.run(bf, "SHIELD BASH", "MEMORIZE THE 3 ARROWS, THEN INPUT FAST", 3)
	var res = await qte.qte_finished
	return res
""")

# 3. Unbreakable Bastion
replace_func("QTEManager.gd", "run_unbreakable_bastion_minigame", """func run_unbreakable_bastion_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte = QTEAlternatingMashMeter.run(bf, "UNBREAKABLE BASTION", "ALTERNATE LEFT / RIGHT TO BRACE", 2500)
	var res = await qte.qte_finished
	return res
""")

# 4. Adrenaline Rush
replace_func("QTEManager.gd", "run_adrenaline_rush_minigame", """func run_adrenaline_rush_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEAlternatingMashMeter.run(bf, "ADRENALINE RUSH", "ALTERNATE LEFT / RIGHT FAST TO PUMP BLOOD", 2000)
	var res = await qte.qte_finished
	return res
""")

# 5. Earthshatter
replace_func("QTEManager.gd", "run_earthshatter_minigame", """func run_earthshatter_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEExpandingRing.run(bf, "EARTHSHATTER", "HOLD SPACE TO CHARGE, RELEASE IN THE RING", 1600)
	var res = await qte.qte_finished
	return res
""")

# 6. Weapon Shatter
replace_func("QTEManager.gd", "run_weapon_shatter_minigame", """func run_weapon_shatter_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte = QTEClashTiming.run(bf, "WEAPON SHATTER", "PRESS SPACE EXACTLY ON IMPACT", 900)
	var res = await qte.qte_finished
	return res
""")

# 7. Savage Toss
replace_func("QTEManager.gd", "run_savage_toss_minigame", """func run_savage_toss_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEOscillationStop.run(bf, "SAVAGE TOSS", "STOP THE NEEDLE IN THE TINY TOP SWEET SPOT", 1800)
	var res = await qte.qte_finished
	return res
""")

# 8. Vanguard's Rally
replace_func("QTEManager.gd", "run_vanguards_rally_minigame", """func run_vanguards_rally_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEComboRush.run(bf, "VANGUARD'S RALLY", "COMPLETE AS MANY 4-BUTTON COMBOS AS POSSIBLE", 3500)
	var res = await qte.qte_finished
	return res
""")

# 9. Phalanx
replace_func("QTEManager.gd", "run_phalanx_minigame", """func run_phalanx_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTESniperZoom.run(bf, "PHALANX", "HOLD SPACE TO ZOOM AND AIM", 4200)
	var res = await qte.qte_finished
	return res
""")

# 10. Aegis Strike
replace_func("QTEManager.gd", "run_aegis_strike_minigame", """func run_aegis_strike_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTECrossAlignment.run(bf, "AEGIS STRIKE", "SPACE TO LOCK HORIZONTAL, SPACE AGAIN TO LOCK VERTICAL")
	var res = await qte.qte_finished
	return res
""")
