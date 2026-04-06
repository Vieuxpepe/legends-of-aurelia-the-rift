extends Node
# =========================================================
# QTE STATE HELPERS (Prevents global pause bugs and sound pitch leaking)
# =========================================================
func _begin_qte(bf: Node2D) -> Dictionary:
	var tree: SceneTree = bf.get_tree()
	var was_paused: bool = tree.paused
	var old_select_pitch: float = 1.0
	
	if bf.select_sound and bf.select_sound.stream != null:
		old_select_pitch = bf.select_sound.pitch_scale
		
	tree.paused = true
	return {"was_paused": was_paused, "old_pitch": old_select_pitch}

func _end_qte(bf: Node2D, qte_layer: CanvasLayer, state: Dictionary, restore_select_pitch: bool = true) -> void:
	if is_instance_valid(qte_layer):
		qte_layer.queue_free()
		
	var tree: SceneTree = bf.get_tree()
	tree.paused = state["was_paused"]
	
	if restore_select_pitch and bf.select_sound and bf.select_sound.stream != null:
		bf.select_sound.pitch_scale = state["old_pitch"]


func begin_battlefield_qte(
	bf: Node2D,
	dimmer_color: Color,
	layer: int = 100,
	with_letterbox: bool = false,
	letterbox_height: float = 56.0
) -> Dictionary:
	var state: Dictionary = _begin_qte(bf)
	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = layer
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp_size: Vector2 = bf.get_viewport_rect().size
	var screen_dimmer: ColorRect = ColorRect.new()
	screen_dimmer.name = "qte_dimmer"
	screen_dimmer.size = vp_size
	screen_dimmer.color = dimmer_color
	qte_layer.add_child(screen_dimmer)

	var top_bar: ColorRect = null
	var bottom_bar: ColorRect = null
	if with_letterbox:
		top_bar = ColorRect.new()
		top_bar.name = "qte_letterbox_top"
		top_bar.color = Color(0, 0, 0, 0.85)
		top_bar.size = Vector2(vp_size.x, 0.0)
		qte_layer.add_child(top_bar)

		bottom_bar = ColorRect.new()
		bottom_bar.name = "qte_letterbox_bottom"
		bottom_bar.color = Color(0, 0, 0, 0.85)
		bottom_bar.position = Vector2(0.0, vp_size.y)
		bottom_bar.size = Vector2(vp_size.x, 0.0)
		qte_layer.add_child(bottom_bar)

		var lb_in: Tween = qte_layer.create_tween().set_parallel(true)
		lb_in.tween_property(top_bar, "size:y", letterbox_height, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		lb_in.tween_property(bottom_bar, "size:y", letterbox_height, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		lb_in.tween_property(bottom_bar, "position:y", vp_size.y - letterbox_height, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	return {
		"state": state,
		"qte_layer": qte_layer,
		"vp_size": vp_size,
		"screen_dimmer": screen_dimmer,
		"top_bar": top_bar,
		"bottom_bar": bottom_bar,
		"letterbox_height": letterbox_height
	}


func create_qte_flash_rect(qte_layer: CanvasLayer, vp_size: Vector2, flash_color: Color) -> ColorRect:
	var flash_rect: ColorRect = ColorRect.new()
	flash_rect.name = "qte_flash"
	flash_rect.size = vp_size
	flash_rect.color = flash_color
	flash_rect.modulate = Color(1, 1, 1, 0)
	qte_layer.add_child(flash_rect)
	return flash_rect


func create_qte_pop_bar(
	qte_layer: CanvasLayer,
	vp_size: Vector2,
	bar_size: Vector2,
	y_offset: float,
	bar_color: Color,
	start_scale: Vector2,
	center_pivot: bool = false
) -> ColorRect:
	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.name = "bar_bg"
	bar_bg.size = bar_size
	if center_pivot:
		bar_bg.pivot_offset = bar_bg.size / 2.0
	bar_bg.position = (vp_size - bar_bg.size) / 2.0
	bar_bg.position.y += y_offset
	bar_bg.color = bar_color
	bar_bg.scale = start_scale
	bar_bg.modulate.a = 0.0
	qte_layer.add_child(bar_bg)

	var bar_pop: Tween = qte_layer.create_tween().set_parallel(true)
	bar_pop.tween_property(bar_bg, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bar_pop.tween_property(bar_bg, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return bar_bg


func wait_pause_safe_qte_hold(bf: Node2D, duration: float) -> void:
	await bf.get_tree().create_timer(duration, true, false, true).timeout


func close_battlefield_qte(
	bf: Node2D,
	qte_host: Dictionary,
	animate_letterbox_out: bool = true,
	letterbox_out_duration: float = 0.10
) -> void:
	var qte_layer: CanvasLayer = qte_host.get("qte_layer", null)
	var state: Dictionary = qte_host.get("state", {})
	var top_bar: ColorRect = qte_host.get("top_bar", null)
	var bottom_bar: ColorRect = qte_host.get("bottom_bar", null)
	var vp_size: Vector2 = qte_host.get("vp_size", Vector2.ZERO)

	if animate_letterbox_out and is_instance_valid(qte_layer) and is_instance_valid(top_bar) and is_instance_valid(bottom_bar):
		var lb_out: Tween = qte_layer.create_tween().set_parallel(true)
		lb_out.tween_property(top_bar, "size:y", 0.0, letterbox_out_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		lb_out.tween_property(bottom_bar, "size:y", 0.0, letterbox_out_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		lb_out.tween_property(bottom_bar, "position:y", vp_size.y, letterbox_out_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await lb_out.finished

	_end_qte(bf, qte_layer, state, false)


func _apply_qte_visual_overhaul(qte_layer: CanvasLayer, title: Label, help: Label) -> void:
	if qte_layer == null or not is_instance_valid(qte_layer):
		return
	var vp: Vector2 = qte_layer.get_viewport().get_visible_rect().size
	var accent: Color = Color(0.96, 0.82, 0.32, 1.0)
	if title != null and is_instance_valid(title):
		var sample := title.get_theme_color("font_color", "Label")
		if sample.a > 0.0:
			accent = sample

	var dimmer := qte_layer.get_child(0) as ColorRect if qte_layer.get_child_count() > 0 else null
	if dimmer != null and dimmer.size.x >= vp.x * 0.95 and dimmer.size.y >= vp.y * 0.95:
		dimmer.color = Color(0.015, 0.02, 0.035, 0.70)

	var atmosphere := ColorRect.new()
	atmosphere.name = "QteAtmosphere"
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere.size = vp
	atmosphere.color = Color(accent.r * 0.12, accent.g * 0.08, accent.b * 0.16, 0.16)
	atmosphere.z_index = -4
	qte_layer.add_child(atmosphere)
	qte_layer.move_child(atmosphere, 1)

	var frame := Panel.new()
	frame.name = "QteBackdropPanel"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = Vector2(minf(vp.x * 0.76, 980.0), minf(vp.y * 0.46, 360.0))
	frame.position = Vector2((vp.x - frame.size.x) * 0.5, (vp.y - frame.size.y) * 0.5 - 36.0)
	frame.z_index = -3
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.04, 0.05, 0.08, 0.78)
	frame_style.border_color = Color(accent.r, accent.g, accent.b, 0.70)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(16)
	frame_style.shadow_size = 26
	frame_style.shadow_color = Color(0, 0, 0, 0.55)
	frame.add_theme_stylebox_override("panel", frame_style)
	qte_layer.add_child(frame)
	qte_layer.move_child(frame, 2)

	var top_glow := ColorRect.new()
	top_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_glow.size = Vector2(frame.size.x - 26.0, 5.0)
	top_glow.position = Vector2(13.0, 11.0)
	top_glow.color = Color(accent.r, accent.g, accent.b, 0.55)
	frame.add_child(top_glow)

	if title != null and is_instance_valid(title):
		title.add_theme_font_size_override("font_size", max(42, int(title.get_theme_font_size("font_size", "Label"))))
		title.add_theme_color_override("font_color", Color(minf(accent.r + 0.10, 1.0), minf(accent.g + 0.08, 1.0), minf(accent.b + 0.08, 1.0), 1.0))
		title.add_theme_constant_override("outline_size", 7)
		title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
		title.position.y = frame.position.y - 72.0
		title.size.x = vp.x

	if help != null and is_instance_valid(help):
		help.add_theme_font_size_override("font_size", max(24, int(help.get_theme_font_size("font_size", "Label"))))
		help.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 0.96))
		help.add_theme_constant_override("outline_size", 5)
		help.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.86))
		help.position.y = frame.position.y - 30.0
		help.size.x = vp.x

	frame.scale = Vector2(0.965, 0.965)
	frame.modulate.a = 0.0
	var open_tw := qte_layer.create_tween()
	open_tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	open_tw.tween_property(frame, "modulate:a", 1.0, 0.18)
	open_tw.parallel().tween_property(frame, "scale", Vector2.ONE, 0.20)

	if title != null and is_instance_valid(title):
		var title_tw := qte_layer.create_tween().set_loops()
		title_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		title_tw.tween_property(title, "modulate:a", 0.88, 0.62)
		title_tw.tween_property(title, "modulate:a", 1.0, 0.62)
	if help != null and is_instance_valid(help):
		var help_tw := qte_layer.create_tween().set_loops()
		help_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		help_tw.tween_property(help, "modulate:a", 0.74, 0.48)
		help_tw.tween_property(help, "modulate:a", 0.96, 0.48)

	call_deferred("_polish_qte_controls_deferred", qte_layer, accent)


func apply_battlefield_qte_ui_polish(
	bf: Node2D,
	qte_layer: CanvasLayer,
	screen_dimmer: ColorRect,
	bar_bg: ColorRect,
	help_text: Label,
	top_bar: ColorRect,
	bottom_bar: ColorRect,
	accent: Color,
	title_text: String
) -> void:
	if qte_layer == null or not is_instance_valid(qte_layer):
		return
	var vp_size: Vector2 = bf.get_viewport_rect().size

	if screen_dimmer != null and is_instance_valid(screen_dimmer):
		screen_dimmer.color = Color(
			clampf(accent.r * 0.12, 0.0, 0.25),
			clampf(accent.g * 0.08, 0.0, 0.20),
			clampf(accent.b * 0.15, 0.0, 0.30),
			0.66
		)

	var atmosphere := ColorRect.new()
	atmosphere.name = "QteBattleAtmosphere"
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere.size = vp_size
	atmosphere.color = Color(
		clampf(accent.r * 0.10, 0.0, 0.18),
		clampf(accent.g * 0.08, 0.0, 0.14),
		clampf(accent.b * 0.12, 0.0, 0.20),
		0.28
	)
	atmosphere.z_index = -3
	qte_layer.add_child(atmosphere)
	qte_layer.move_child(atmosphere, 1)

	if top_bar != null:
		top_bar.color = Color(0.0, 0.0, 0.0, 0.90)
	if bottom_bar != null:
		bottom_bar.color = Color(0.0, 0.0, 0.0, 0.90)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0.0, bar_bg.position.y - 124.0)
	title.size = Vector2(vp_size.x, 52.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(minf(accent.r + 0.10, 1.0), minf(accent.g + 0.10, 1.0), minf(accent.b + 0.10, 1.0), 1.0))
	title.add_theme_constant_override("outline_size", 7)
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	qte_layer.add_child(title)

	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.position = bar_bg.position + Vector2(-26.0, -20.0)
	frame.size = bar_bg.size + Vector2(52.0, 40.0)
	frame.z_index = -1
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.05, 0.06, 0.09, 0.80)
	frame_style.border_color = Color(accent.r, accent.g, accent.b, 0.72)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(14)
	frame_style.shadow_size = 20
	frame_style.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	frame.add_theme_stylebox_override("panel", frame_style)
	qte_layer.add_child(frame)

	var frame_glow := ColorRect.new()
	frame_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_glow.size = Vector2(frame.size.x - 22.0, 4.0)
	frame_glow.position = Vector2(11.0, 10.0)
	frame_glow.color = Color(accent.r, accent.g, accent.b, 0.56)
	frame.add_child(frame_glow)

	if help_text != null and is_instance_valid(help_text):
		help_text.add_theme_font_size_override("font_size", 28)
		help_text.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 0.98))
		help_text.add_theme_constant_override("outline_size", 5)
		help_text.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
		var help_tw := qte_layer.create_tween().set_loops()
		help_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		help_tw.tween_property(help_text, "modulate:a", 0.74, 0.45)
		help_tw.tween_property(help_text, "modulate:a", 0.98, 0.45)

	var title_tw := qte_layer.create_tween().set_loops()
	title_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	title_tw.tween_property(title, "modulate:a", 0.86, 0.66)
	title_tw.tween_property(title, "modulate:a", 1.0, 0.66)


func _polish_qte_controls_deferred(qte_layer: CanvasLayer, accent: Color) -> void:
	if qte_layer == null or not is_instance_valid(qte_layer):
		return
	var stack: Array[Node] = [qte_layer]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for child in n.get_children():
			if child is Node:
				stack.append(child)
		_apply_polish_to_qte_node(n, accent)


func _apply_polish_to_qte_node(n: Node, accent: Color) -> void:
	if n == null or not is_instance_valid(n):
		return
	var lname: String = String(n.name).to_lower()
	if n is ColorRect:
		var rect: ColorRect = n as ColorRect
		if lname.contains("dimmer") or lname.contains("atmosphere"):
			return
		if lname.contains("bar_bg"):
			rect.color = Color(0.055, 0.065, 0.095, 0.95)
		elif lname.contains("fill"):
			rect.color = Color(
				clampf(accent.r * 0.85 + 0.08, 0.0, 1.0),
				clampf(accent.g * 0.95 + 0.08, 0.0, 1.0),
				clampf(accent.b * 1.05 + 0.10, 0.0, 1.0),
				0.96
			)
		elif lname.contains("perfect"):
			rect.color = Color(1.0, 0.84, 0.26, 0.96)
		elif lname.contains("good") or lname.contains("green_zone"):
			rect.color = Color(0.44, 0.98, 0.56, 0.92)
		elif lname.contains("cursor") or lname.contains("needle") or lname.contains("target_dot"):
			rect.color = Color(0.95, 0.97, 1.0, 0.98)
		elif lname.contains("line"):
			rect.color = Color(0.88, 0.92, 1.0, 0.84)
		elif lname.contains("pivot"):
			rect.color = Color(0.92, 0.94, 1.0, 0.78)
	elif n is Panel:
		var panel: Panel = n as Panel
		if lname.contains("qtebackdroppanel"):
			return
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.07, 0.10, 0.90)
		style.border_color = Color(
			clampf(accent.r * 0.85 + 0.12, 0.0, 1.0),
			clampf(accent.g * 0.85 + 0.12, 0.0, 1.0),
			clampf(accent.b * 0.85 + 0.12, 0.0, 1.0),
			0.90
		)
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		style.shadow_size = 12
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.44)
		panel.add_theme_stylebox_override("panel", style)
	elif n is Label:
		var lbl: Label = n as Label
		if lname.contains("title"):
			return
		if lname.contains("status") or lname.contains("counter") or lname.contains("prompt"):
			lbl.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0, 0.98))
			lbl.add_theme_constant_override("outline_size", max(lbl.get_theme_constant("outline_size", "Label"), 5))
		
# =========================================================
# ARCHER QTE 1: DEADEYE SHOT
# Sweet spot timing bar
# Returns: 0 = fail, 1 = good, 2 = perfect
# =========================================================
func run_deadeye_shot_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker):
		return 0

	var qte_bar = load("res://Scripts/Core/QTETimingBar.gd")
	var qte = qte_bar.run(bf, "DEADEYE SHOT", "PRESS SPACE INSIDE THE CENTER", 920)
	var result: int = await qte.qte_finished
	return result

# =========================================================
# ARCHER QTE 2: VOLLEY
# Mash meter
# Returns: 0 = weak volley, 1 = good volley, 2 = perfect volley
# =========================================================
func run_volley_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker):
		return 0

	var qte_mash = load("res://Scripts/Core/QTEMashMeter.gd")
	var qte = qte_mash.run(bf, "VOLLEY", "MASH SPACE TO LOOSE MORE ARROWS", 2200, 28.0)
	var result: int = await qte.qte_finished
	return result

# =========================================================
# ARCHER QTE 3: RAIN OF ARROWS
# Simon Says directional sequence
# Returns: 0 = fail, 1 = good barrage, 2 = perfect barrage
# =========================================================
func run_rain_of_arrows_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_seq = load("res://Scripts/Core/QTESequenceMemory.gd")
	var qte = qte_seq.run(bf, "RAIN OF ARROWS", "MEMORIZE THEN REPEAT THE PATTERN", 5)
	var result: int = await qte.qte_finished
	return result

# =========================================================
# CLERIC QTE 1: DIVINE PROTECTION
# Shrinking rings timing minigame
# =========================================================
func run_divine_protection_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte_script = load(\"res://Scripts/Core/QTEShrinkingRing.gd\")
	var qte = qte_script.run(bf, "DIVINE PROTECTION", "PRESS SPACE WHEN THE RINGS ALIGN", 1100)
	var res = await qte.qte_finished
	return res


func run_healing_light_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEMashMeter.gd\")
	var qte = qte_script.run(bf, "HEALING LIGHT", "MASH SPACE TO AMPLIFY THE HEAL", 2200, 24.0)
	var res = await qte.qte_finished
	return res


func run_miracle_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte_script = load(\"res://Scripts/Core/QTEOscillationStop.gd\")
	var qte = qte_script.run(bf, "MIRACLE", "STOP THE PENDULUM IN THE GOLD", 1500)
	var res = await qte.qte_finished
	return res


func run_charge_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEHoldReleaseBar.gd\")
	var qte = qte_script.run(bf, "CHARGE", "HOLD SPACE, RELEASE IN GREEN", 1400)
	qte.green_zone.position.x = 365.0; qte.green_zone.size.x = 70.0
	qte.perfect_zone.size.x = 22.0
	var res = await qte.qte_finished
	return res


func run_shield_bash_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte_script = load(\"res://Scripts/Core/QTESequenceMemory.gd\")
	var qte = qte_script.run(bf, "SHIELD BASH", "MEMORIZE THE 3 ARROWS, THEN INPUT FAST", 3)
	var res = await qte.qte_finished
	return res


func run_unbreakable_bastion_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte_script = load(\"res://Scripts/Core/QTEAlternatingMashMeter.gd\")
	var qte = qte_script.run(bf, "UNBREAKABLE BASTION", "ALTERNATE LEFT / RIGHT TO BRACE", 2500)
	var res = await qte.qte_finished
	return res


func run_fireball_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load("res://Scripts/Core/QTEBubbleExpansion.gd")
	var qte = qte_script.run(bf, "FIREBALL", "TAP SPACE REPEATEDLY TO GROW THE BUBBLE", 2000)
	var res = await qte.qte_finished
	return res


func run_arcane_shift_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte_script = load(\"res://Scripts/Core/QTEAlternatingMashMeter.gd\")
	var qte = qte_script.run(bf, "ARCANE SHIFT", "ALTERNATE UP / DOWN TO PHASE OUT", 2200)
	var res = await qte.qte_finished
	return res


func run_meteor_storm_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTESequenceMemory.gd\")
	var qte = qte_script.run(bf, "METEOR STORM", "MEMORIZE THE 5 ARROWS", 5)
	var res = await qte.qte_finished
	return res


func run_flurry_strike_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEMashMeter.gd\")
	var qte = qte_script.run(bf, "FLURRY STRIKE", "TAP SPACE AS FAST AS POSSIBLE", 1500, 14)
	var res = await qte.qte_finished
	return res

func run_battle_cry_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEHoldReleaseBar.gd\")
	var qte = qte_script.run(bf, "BATTLE CRY", "HOLD SPACE — RELEASE IN THE TINY GREEN WINDOW", 1500)
	var res = await qte.qte_finished
	return res

func run_blade_tempest_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEMultiTapDial.gd\")
	var qte = qte_script.run(bf, "BLADE TEMPEST", "TAP SPACE AS THE NEEDLE PASSES THE 3 GOLD ZONES", [20.0, 150.0, 285.0], 420.0, 2600)
	var res = await qte.qte_finished
	return res

func run_chakra_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEBalanceMeter.gd\")
	var qte = qte_script.run(bf, "CHAKRA", "USE LEFT / RIGHT TO KEEP THE MIND CENTERED", 2500)
	var res = await qte.qte_finished
	return res


func run_inner_peace_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte_script = load(\"res://Scripts/Core/QTEFastSequence.gd\")
	var qte = qte_script.run(bf, "INNER PEACE", "INPUT THE 4-ARROW MANTRA BEFORE TIME RUNS OUT", 4, 3350, 850) # 850ms reveal + 2500ms input = 3350
	var res = await qte.qte_finished
	return res


func run_chi_burst_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEBreathingCircle.gd\")
	var qte = qte_script.run(bf, "CHI BURST", "PRESS SPACE AT THE ABSOLUTE PEAK", 920, 460)
	var res = await qte.qte_finished
	return res


func run_roar_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load("res://Scripts/Core/QTEBubbleExpansion.gd")
	var qte = qte_script.run(bf, "ROAR", "MASH SPACE TO EXPAND THE SHOCKWAVE", 2000)
	var res = await qte.qte_finished
	return res


func run_frenzy_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load("res://Scripts/Core/QTEWhackAMole.gd")
	var qte = qte_script.run(bf, "FRENZY", "HIT THE YELLOW DIRECTION IMMEDIATELY")
	var res = await qte.qte_finished
	return res


func run_rending_claw_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load("res://Scripts/Core/QTEScratchLine.gd")
	var qte = qte_script.run(bf, "RENDING CLAW", "PRESS SPACE ON THE GOLD SCRATCH POINT")
	var res = await qte.qte_finished
	return res


func run_smite_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEShrinkingRing.gd\")
	var qte = qte_script.run(bf, "SMITE", "PRESS SPACE WHEN THE RING ALIGNS", 750)
	var res = await qte.qte_finished
	return res


func run_holy_ward_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte_script = load(\"res://Scripts/Core/QTEFastSequence.gd\")
	var qte = qte_script.run(bf, "HOLY WARD", "INPUT THE 4 ARROWS FAST TO BLOCK MAGIC", 4, 2400, 1000)
	var res = await qte.qte_finished
	return res


func run_sacred_judgment_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEPingPongBar.gd\")
	var qte = qte_script.run(bf, "SACRED JUDGMENT", "RELEASE NEAR MAX", 2.4)
	var res = await qte.qte_finished
	return res


func run_flame_blade_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load("res://Scripts/Core/QTEGlideBox.gd")
	var qte = qte_script.run(bf, "FLAME BLADE", "HOLD SPACE TO FLY. STAY IN THE MOVING BOX!")
	var res = await qte.qte_finished
	return res


func run_blink_step_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte_script = load("res://Scripts/Core/QTEReactionFlash.gd")
	var qte = qte_script.run(bf, "BLINK STEP", "WAIT FOR THE FLASH... THEN PRESS SPACE!")
	var res = await qte.qte_finished
	return res


func run_elemental_convergence_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEReactionStrike.gd\")
	var qte = qte_script.run(bf, "ELEMENTAL CONVERGENCE", "PRESS THE ARROW AS SOON AS IT APPEARS!", 4, 550)
	var res = await qte.qte_finished
	return res


func run_shadow_strike_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEStealthBar.gd\")
	var qte = qte_script.run(bf, "SHADOW STRIKE", "PRESS SPACE INSIDE THE SHADOW BAND", 700)
	var res = await qte.qte_finished
	return res


func run_assassinate_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEMultiTargetBar.gd\")
	var qte = qte_script.run(bf, "ASSASSINATE", "TAP SPACE ON THE 3 VITAL POINTS!", 1500)
	var res = await qte.qte_finished
	return res


func run_ultimate_shadow_step_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEReactionStrike.gd\")
	var qte = qte_script.run(bf, "ULTIMATE SHADOW STEP", "PRESS THE ARROW AS SOON AS IT APPEARS!", 4, 550)
	var res = await qte.qte_finished
	return res


func run_power_strike_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTETimingBar.gd\")
	var qte = qte_script.run(bf, "POWER STRIKE", "PRESS SPACE AT MAX POWER", 1300)
	
	# Override position
	qte.outer_good.position.x = 520.0 - 120.0 # From original bar width
	qte.outer_good.size.x = 120.0
	qte.perfect_zone.position.x = 90.0
	qte.perfect_zone.size.x = 24.0
	
	var res = await qte.qte_finished
	return res

func run_adrenaline_rush_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEAlternatingMashMeter.gd\")
	var qte = qte_script.run(bf, "ADRENALINE RUSH", "ALTERNATE LEFT / RIGHT FAST TO PUMP BLOOD", 2000)
	var res = await qte.qte_finished
	return res


func run_earthshatter_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEExpandingRing.gd\")
	var qte = qte_script.run(bf, "EARTHSHATTER", "HOLD SPACE TO CHARGE, RELEASE IN THE RING", 1600)
	var res = await qte.qte_finished
	return res


func run_shadow_pin_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTECrosshairPin.gd\")
	var qte = qte_script.run(bf, "SHADOW PIN", "TRACK THE DOT WITH ARROWS — PRESS SPACE ON TARGET", 2600)
	var res = await qte.qte_finished
	return res


func run_weapon_shatter_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte_script = load(\"res://Scripts/Core/QTEClashTiming.gd\")
	var qte = qte_script.run(bf, "WEAPON SHATTER", "PRESS SPACE EXACTLY ON IMPACT", 900)
	var res = await qte.qte_finished
	return res


func run_savage_toss_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEOscillationStop.gd\")
	var qte = qte_script.run(bf, "SAVAGE TOSS", "STOP THE NEEDLE IN THE TINY TOP SWEET SPOT", 1800)
	var res = await qte.qte_finished
	return res


func run_vanguards_rally_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEComboRush.gd\")
	var qte = qte_script.run(bf, "VANGUARD'S RALLY", "COMPLETE AS MANY 4-BUTTON COMBOS AS POSSIBLE", 3500)
	var res = await qte.qte_finished
	return res


func run_severing_strike_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load("res://Scripts/Core/QTECollisionRush.gd")
	var qte = qte_script.run(bf, "SEVERING STRIKE", "PRESS SPACE WHEN THE CURSOR ENTERS THE TARGET")
	var res = await qte.qte_finished
	return res


func run_aether_bind_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTECatcherPaddle.gd\")
	var qte = qte_script.run(bf, "AETHER BIND", "MOVE LEFT / RIGHT TO CATCH THE FALLING SPARKS")
	var res = await qte.qte_finished
	return res


func run_parting_shot_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEPartingShot.gd\")
	var qte = qte_script.run(bf, "PARTING SHOT", "PRESS SPACE WHEN THE RINGS ALIGN")
	var res = await qte.qte_finished
	return res


func run_soul_harvest_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEMashMeter.gd\")
	var qte = qte_script.run(bf, "SOUL HARVEST", "MASH SPACE TO HOLD THE BAR ABOVE THE DARK PULL", 2500, 55.0)
	var res = await qte.qte_finished
	return res


func run_celestial_choir_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTERhythmLanes.gd\")
	var qte = qte_script.run(bf, "CELESTIAL CHOIR", "LEFT / DOWN / RIGHT — HIT WHEN NOTES REACH THE LINE")
	var res = await qte.qte_finished
	return res


func run_hellfire_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTEHeatBalance.gd\")
	var qte = qte_script.run(bf, "HELLFIRE", "KEEP HEAT INSIDE THE TOP 15% RED ZONE")
	var res = await qte.qte_finished
	return res


func run_phalanx_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTESniperZoom.gd\")
	var qte = qte_script.run(bf, "PHALANX", "HOLD SPACE TO ZOOM AND AIM", 4200)
	var res = await qte.qte_finished
	return res


func run_ballista_shot_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTESniperZoom.gd\")
	var qte = qte_script.run(bf, "BALLISTA SHOT", "MOVE WITH ARROWS • HOLD SPACE TO ZOOM • RELEASE TO FIRE", 4200)
	var res = await qte.qte_finished
	return res


func run_aegis_strike_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte_script = load(\"res://Scripts/Core/QTECrossAlignment.gd\")
	var qte = qte_script.run(bf, "AEGIS STRIKE", "SPACE TO LOCK HORIZONTAL, SPACE AGAIN TO LOCK VERTICAL")
	var res = await qte.qte_finished
	return res
