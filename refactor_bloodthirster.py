import os
import re

combo_sweep_code = """extends CanvasLayer
class_name QTEComboSweepBar

signal qte_finished(hits: int)

var bf: Node2D
var sweep_duration: float
var timer: float = 0.0
var is_done: bool = false
var end_hold_timer: float = -1.0

var active_zone: int = 0
var hits: int = 0
var broken: bool = false

var help_lbl: Label
var cursor: ColorRect
var target_rects: Array[ColorRect] = []
var target_positions: Array[float] = []
var zone_width: float = 30.0
var bar_w: float = 420.0

static func run(
	parent_bf: Node2D,
	title_text: String,
	help_text: String,
	positions: Array,
	duration_ms: int
) -> QTEComboSweepBar:
	var qte = QTEComboSweepBar.new()
	qte.bf = parent_bf
	qte.sweep_duration = duration_ms / 1000.0
	for p in positions:
		qte.target_positions.append(float(p))
	
	qte.layer = 200
	qte.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_bf.add_child(qte)
	
	var vp := parent_bf.get_viewport_rect().size
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.2, 0.0, 0.0, 0.4)
	dimmer.size = vp
	qte.add_child(dimmer)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(title)

	qte.help_lbl = Label.new()
	qte.help_lbl.text = help_text
	qte.help_lbl.position = Vector2(0, 125)
	qte.help_lbl.size = Vector2(vp.x, 30)
	qte.help_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte.help_lbl.add_theme_font_size_override("font_size", 26)
	qte.help_lbl.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
	qte.help_lbl.add_theme_constant_override("outline_size", 6)
	qte.help_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	qte.add_child(qte.help_lbl)

	if parent_bf.has_node("/root/QTEManager"):
		var mgr = parent_bf.get_node("/root/QTEManager")
		if mgr.has_method("_apply_qte_visual_overhaul"):
			mgr._apply_qte_visual_overhaul(qte, title, qte.help_lbl)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.95)
	bar_bg.size = Vector2(qte.bar_w, 34)
	bar_bg.position = Vector2((vp.x - qte.bar_w) * 0.5, vp.y * 0.5 - 10)
	qte.add_child(bar_bg)

	for pos in qte.target_positions:
		var tz := ColorRect.new()
		tz.size = Vector2(qte.zone_width, 34)
		tz.position = Vector2(pos, 0)
		tz.color = Color(0.4, 0.0, 0.0, 0.8)
		bar_bg.add_child(tz)
		qte.target_rects.append(tz)

	qte.cursor = ColorRect.new()
	qte.cursor.size = Vector2(8, 56)
	qte.cursor.position = Vector2(0, -11)
	qte.cursor.color = Color.WHITE
	bar_bg.add_child(qte.cursor)
	
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
	var progress := timer / sweep_duration
	cursor.position.x = progress * bar_w
	
	if timer >= sweep_duration:
		_finish_qte()
		return
		
	if not broken and active_zone < target_positions.size():
		var current_tz = target_rects[active_zone]
		var c_center = cursor.position.x + (cursor.size.x * 0.5)
		var tz_start = current_tz.position.x
		var tz_end = tz_start + current_tz.size.x
		
		# Missed passed zone
		if c_center > tz_end + 5.0:
			_break_combo()
		elif Input.is_action_just_pressed("ui_accept"):
			if c_center >= tz_start - 8.0 and c_center <= tz_end + 8.0:
				hits += 1
				active_zone += 1
				current_tz.color = Color(1.0, 0.1, 0.1, 1.0)
				if bf.has_method("screen_shake"): bf.screen_shake(12.0, 0.15)
				var clang = bf.get_node_or_null("ClangSound") if bf else null
				if clang and clang.stream:
					clang.pitch_scale = 0.8 + (hits * 0.25)
					clang.play()
			else:
				_break_combo()

func _break_combo() -> void:
	broken = true
	cursor.color = Color(0.4, 0.4, 0.4)
	if active_zone < target_rects.size():
		target_rects[active_zone].color = Color(0.2, 0.0, 0.0, 0.8)
	help_lbl.text = "COMBO DROPPED!"
	help_lbl.add_theme_color_override("font_color", Color.GRAY)
	if bf.get("miss_sound") and bf.miss_sound.stream != null:
		bf.miss_sound.play()
	if bf.has_method("screen_shake"): bf.screen_shake(8.0, 0.2)

func _finish_qte() -> void:
	is_done = true
	end_hold_timer = 0.45
	
	if hits == target_positions.size():
		help_lbl.text = "MAXIMUM BLOODSHED!"
		help_lbl.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
		if bf.has_method("screen_shake"): bf.screen_shake(20.0, 0.4)
		if bf.get("crit_sound") and bf.crit_sound.stream != null:
			if bf.has_method("play_attack_hit_sound"):
				bf.play_attack_hit_sound(bf.crit_sound)
			else:
				bf.crit_sound.play()
	elif hits > 0 and not broken:
		# If somehow timer ran out exactly after last hit, treat as whatever current hits are.
		pass
"""

def write_file(path, content):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content.strip() + "\n")
    print(f"Created {path}")

write_file('Scripts/Core/QTEComboSweepBar.gd', combo_sweep_code)

def replace_bloodthirster(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    pattern = r"static func run_bloodthirster_minigame\(field, attacker: Node2D\) -> int:.*?(?=\nstatic func run_[a-zA-Z_]+\(field, attacker|\Z)"
    match = re.search(pattern, content, re.DOTALL)
    
    new_code = """static func run_bloodthirster_minigame(field, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	
	field.screen_shake(8.0, 0.3)
	var clang = field.get_node_or_null("ClangSound")
	if clang != null and clang.stream != null:
		clang.pitch_scale = 0.6
		clang.play()
	field.spawn_loot_text("BLOODTHIRSTER!", Color(0.8, 0.1, 0.1), attacker.global_position + Vector2(32, -48), {"stack_anchor": attacker})
	await field.get_tree().create_timer(0.6).timeout
	
	var qte = QTEComboSweepBar.run(field, "BLOODTHIRSTER", "TAP 3 TIMES!", [80.0, 200.0, 320.0], 1400)
	var res = await qte.qte_finished
	return res
"""
    
    if match:
        content = content[:match.start()] + new_code + "\n" + content[match.end():]
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Replaced run_bloodthirster_minigame")
        return True
    else:
        print(f"Could not find run_bloodthirster_minigame")
        return False

replace_bloodthirster("Scripts/Core/BattleField/BattleFieldQteMinigameHelpers.gd")
