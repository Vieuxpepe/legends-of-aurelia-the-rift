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

	bf.get_tree().paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 200
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.color = Color(0.06, 0.06, 0.10, 0.68)
	dimmer.size = vp
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "RAIN OF ARROWS"
	title.position = Vector2(0, 85)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "MEMORIZE THEN REPEAT THE PATTERN"
	help.position = Vector2(0, 130)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var panel: ColorRect = ColorRect.new()
	panel.color = Color(0.08, 0.08, 0.08, 0.96)
	panel.size = Vector2(640, 220)
	panel.position = Vector2((vp.x - panel.size.x) * 0.5, (vp.y - panel.size.y) * 0.5 - 20.0)
	qte_layer.add_child(panel)

	var big_prompt: Label = Label.new()
	big_prompt.text = "-"
	big_prompt.position = Vector2(0, 28)
	big_prompt.size = Vector2(panel.size.x, 72)
	big_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_prompt.add_theme_font_size_override("font_size", 54)
	big_prompt.add_theme_color_override("font_color", Color.WHITE)
	big_prompt.add_theme_constant_override("outline_size", 8)
	big_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	panel.add_child(big_prompt)

	var status: Label = Label.new()
	status.text = "WATCH"
	status.position = Vector2(0, 100)
	status.size = Vector2(panel.size.x, 32)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 24)
	status.add_theme_color_override("font_color", Color(0.80, 0.85, 1.0))
	status.add_theme_constant_override("outline_size", 6)
	status.add_theme_color_override("font_outline_color", Color.BLACK)
	panel.add_child(status)

	var slot_labels: Array[Label] = []
	var slot_names: Array[String] = ["1", "2", "3", "4", "5"]
	for i in range(5):
		var slot: Label = Label.new()
		slot.text = slot_names[i]
		slot.position = Vector2(90 + (i * 95), 150)
		slot.size = Vector2(70, 32)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", 24)
		slot.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
		slot.add_theme_constant_override("outline_size", 5)
		slot.add_theme_color_override("font_outline_color", Color.BLACK)
		panel.add_child(slot)
		slot_labels.append(slot)

	var action_names: Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right"]
	var display_names: Array[String] = ["UP", "DOWN", "LEFT", "RIGHT"]

	var sequence: Array[int] = []
	for i in range(5):
		sequence.append(randi() % 4)

	Input.flush_buffered_events()

	for i in range(sequence.size()):
		var start_show: int = Time.get_ticks_msec()
		big_prompt.text = display_names[sequence[i]]
		big_prompt.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
		slot_labels[i].add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))

		while Time.get_ticks_msec() - start_show < 360:
			await bf.get_tree().process_frame

		var start_gap: int = Time.get_ticks_msec()
		big_prompt.text = "-"
		slot_labels[i].add_theme_color_override("font_color", Color(0.70, 0.70, 0.70))

		while Time.get_ticks_msec() - start_gap < 120:
			await bf.get_tree().process_frame

		if bf.select_sound and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.0 + (i * 0.05)
			bf.select_sound.play()

	# THE FIX: Do not reveal the first move!
	status.text = "REPEAT"
	status.add_theme_color_override("font_color", Color(0.30, 1.0, 0.35))
	big_prompt.text = "INPUT"
	big_prompt.add_theme_color_override("font_color", Color.WHITE)

	var correct_count: int = 0
	var total_input_window_ms: int = 3600
	var input_start_ms: int = Time.get_ticks_msec()

	while true:
		await bf.get_tree().process_frame

		var now: int = Time.get_ticks_msec()
		if now - input_start_ms >= total_input_window_ms:
			status.text = "TOO SLOW"
			status.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			break

		var pressed_index: int = -1
		for i in range(action_names.size()):
			if Input.is_action_just_pressed(action_names[i]):
				pressed_index = i
				break

		if pressed_index == -1: continue

		if pressed_index == sequence[correct_count]:
			slot_labels[correct_count].add_theme_color_override("font_color", Color(0.30, 1.0, 0.35))
			correct_count += 1

			if bf.select_sound and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.12 + (correct_count * 0.06)
				bf.select_sound.play()

			if correct_count >= sequence.size():
				status.text = "PATTERN COMPLETE"
				status.add_theme_color_override("font_color", Color(1.0, 0.86, 0.20))
				big_prompt.text = "DONE"
				if bf.crit_sound and bf.crit_sound.stream != null: bf.crit_sound.play()
				bf.screen_shake(12.0, 0.20)
				break
		else:
			status.text = "SEQUENCE BROKEN"
			status.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			big_prompt.text = "X"
			if bf.miss_sound and bf.miss_sound.stream != null: bf.miss_sound.play()
			bf.screen_shake(8.0, 0.12)
			break

	if correct_count >= 5: result = 2
	elif correct_count >= 3: result = 1
	else: result = 0

	var resolve_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - resolve_start < 420:
		await bf.get_tree().process_frame

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result
	
# =========================================================
# CLERIC QTE 1: DIVINE PROTECTION
# Shrinking rings timing minigame
# =========================================================
func run_divine_protection_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender):
		return 0

	bf.get_tree().paused = true

	var qte_layer := CanvasLayer.new()
	qte_layer.layer = 200
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp := bf.get_viewport_rect().size

	var dimmer := ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.05, 0.08, 0.16, 0.60)
	qte_layer.add_child(dimmer)

	var title := Label.new()
	title.text = "DIVINE PROTECTION"
	title.position = Vector2(0, 90)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help := Label.new()
	help.text = "PRESS SPACE WHEN THE RINGS ALIGN"
	help.position = Vector2(0, 135)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var center := vp * 0.5 + Vector2(0, 20)

	var target := Panel.new()
	target.size = Vector2(96, 96)
	target.position = center - target.size * 0.5
	var target_style := StyleBoxFlat.new()
	target_style.bg_color = Color(0, 0, 0, 0)
	target_style.border_width_left = 6
	target_style.border_width_top = 6
	target_style.border_width_right = 6
	target_style.border_width_bottom = 6
	target_style.border_color = Color(1.0, 0.85, 0.25, 1.0)
	target_style.corner_radius_top_left = 64
	target_style.corner_radius_top_right = 64
	target_style.corner_radius_bottom_left = 64
	target_style.corner_radius_bottom_right = 64
	target.add_theme_stylebox_override("panel", target_style)
	qte_layer.add_child(target)

	var ring := Panel.new()
	ring.size = Vector2(240, 240)
	ring.position = center - ring.size * 0.5
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0, 0, 0, 0)
	ring_style.border_width_left = 8
	ring_style.border_width_top = 8
	ring_style.border_width_right = 8
	ring_style.border_width_bottom = 8
	ring_style.border_color = Color(0.60, 0.85, 1.0, 1.0)
	ring_style.corner_radius_top_left = 128
	ring_style.corner_radius_top_right = 128
	ring_style.corner_radius_bottom_left = 128
	ring_style.corner_radius_bottom_right = 128
	ring.add_theme_stylebox_override("panel", ring_style)
	qte_layer.add_child(ring)

	Input.flush_buffered_events()

	var result := 0
	var total_ms := 1100
	var start_ms := Time.get_ticks_msec()
	var end_hold_ms := -1
	var start_size := 240.0
	var end_size := 78.0

	while true:
		await bf.get_tree().process_frame

		var now := Time.get_ticks_msec()

		if end_hold_ms > 0:
			if now >= end_hold_ms:
				break
			continue

		var elapsed := now - start_ms
		if elapsed >= total_ms:
			help.text = "FAILED"
			help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			if bf.miss_sound and bf.miss_sound.stream != null:
				bf.miss_sound.play()
			end_hold_ms = now + 320
			continue

		var t := float(elapsed) / float(total_ms)
		var current_size: float = lerp(start_size, end_size, t)
		ring.size = Vector2(current_size, current_size)
		ring.position = center - ring.size * 0.5

		if Input.is_action_just_pressed("ui_accept"):
			var diff: float = abs(ring.size.x - target.size.x)

			if diff <= 8.0:
				result = 2
				help.text = "PERFECT"
				help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
				ring_style.border_color = Color.WHITE
				target_style.border_color = Color.WHITE
				if bf.crit_sound and bf.crit_sound.stream != null:
					bf.crit_sound.play()
				bf.screen_shake(14.0, 0.22)
			elif diff <= 22.0:
				result = 1
				help.text = "GOOD"
				help.add_theme_color_override("font_color", Color(0.3, 1.0, 0.35))
				ring_style.border_color = Color(0.3, 1.0, 0.35)
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.18
					bf.select_sound.play()
				bf.screen_shake(7.0, 0.12)
			else:
				result = 0
				help.text = "MISS"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				ring_style.border_color = Color(1.0, 0.25, 0.25)
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()

			end_hold_ms = now + 320

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result


# =========================================================
# CLERIC QTE 2: HEALING LIGHT
# Mash Meter minigame
# =========================================================
func run_healing_light_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker):
		return 0

	bf.get_tree().paused = true

	var qte_layer := CanvasLayer.new()
	qte_layer.layer = 200
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp := bf.get_viewport_rect().size

	var dimmer := ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.02, 0.08, 0.04, 0.58)
	qte_layer.add_child(dimmer)

	var title := Label.new()
	title.text = "HEALING LIGHT"
	title.position = Vector2(0, 90)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help := Label.new()
	help.text = "MASH SPACE TO AMPLIFY THE HEAL"
	help.position = Vector2(0, 135)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var bar_bg := ColorRect.new()
	bar_bg.size = Vector2(520, 34)
	bar_bg.position = Vector2((vp.x - 520) * 0.5, vp.y * 0.5 - 10)
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.96)
	qte_layer.add_child(bar_bg)

	var fill := ColorRect.new()
	fill.size = Vector2(0, 34)
	fill.position = Vector2.ZERO
	fill.color = Color(0.45, 1.0, 0.6, 1.0)
	bar_bg.add_child(fill)

	var good_line := ColorRect.new()
	good_line.size = Vector2(4, 34)
	good_line.position = Vector2(bar_bg.size.x * 0.58, 0)
	good_line.color = Color(0.35, 1.0, 0.35, 0.95)
	bar_bg.add_child(good_line)

	var perfect_line := ColorRect.new()
	perfect_line.size = Vector2(4, 34)
	perfect_line.position = Vector2(bar_bg.size.x * 0.84, 0)
	perfect_line.color = Color(1.0, 0.86, 0.2, 0.98)
	bar_bg.add_child(perfect_line)

	var mult_1 := Label.new()
	mult_1.text = "x1.0"
	mult_1.position = Vector2(bar_bg.position.x + 18, bar_bg.position.y + 50)
	mult_1.add_theme_font_size_override("font_size", 20)
	mult_1.add_theme_color_override("font_color", Color.WHITE)
	mult_1.add_theme_constant_override("outline_size", 5)
	mult_1.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(mult_1)

	var mult_2 := Label.new()
	mult_2.text = "x1.5"
	mult_2.position = Vector2(bar_bg.position.x + 270, bar_bg.position.y + 50)
	mult_2.add_theme_font_size_override("font_size", 20)
	mult_2.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	mult_2.add_theme_constant_override("outline_size", 5)
	mult_2.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(mult_2)

	var mult_3 := Label.new()
	mult_3.text = "x2.0"
	mult_3.position = Vector2(bar_bg.position.x + 438, bar_bg.position.y + 50)
	mult_3.add_theme_font_size_override("font_size", 20)
	mult_3.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
	mult_3.add_theme_constant_override("outline_size", 5)
	mult_3.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(mult_3)

	Input.flush_buffered_events()

	var meter := 24.0
	var total_ms := 2200
	var start_ms := Time.get_ticks_msec()
	var last_ms := start_ms
	var end_hold_ms := -1
	var result := 0

	while true:
		await bf.get_tree().process_frame

		var now := Time.get_ticks_msec()

		if end_hold_ms > 0:
			if now >= end_hold_ms:
				break
			continue

		var elapsed_total := now - start_ms
		if elapsed_total >= total_ms:
			if meter >= 84.0:
				result = 2
				help.text = "PERFECT HEAL"
				help.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
				if bf.crit_sound and bf.crit_sound.stream != null:
					bf.crit_sound.play()
				bf.screen_shake(10.0, 0.18)
			elif meter >= 58.0:
				result = 1
				help.text = "BOOSTED HEAL"
				help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.15
					bf.select_sound.play()
				bf.screen_shake(5.0, 0.10)
			else:
				result = 0
				help.text = "NORMAL HEAL"
				help.add_theme_color_override("font_color", Color.WHITE)
			end_hold_ms = now + 320
			continue

		var dt := float(now - last_ms) / 1000.0
		last_ms = now

		meter -= 20.0 * dt
		meter = clamp(meter, 0.0, 100.0)

		if Input.is_action_just_pressed("ui_accept"):
			meter += 12.0
			meter = clamp(meter, 0.0, 100.0)

			if bf.select_sound and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = randf_range(1.1, 1.3)
				bf.select_sound.play()

		fill.size.x = (meter / 100.0) * bar_bg.size.x

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result


# =========================================================
# CLERIC QTE 3: MIRACLE
# Sweeping Pendulum minigame
# =========================================================
func run_miracle_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender):
		return 0

	bf.get_tree().paused = true

	var qte_layer := CanvasLayer.new()
	qte_layer.layer = 200
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp := bf.get_viewport_rect().size

	var dimmer := ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.20, 0.00, 0.00, 0.72)
	qte_layer.add_child(dimmer)

	var title := Label.new()
	title.text = "MIRACLE"
	title.position = Vector2(0, 70)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help := Label.new()
	help.text = "STOP THE PENDULUM IN THE GOLD"
	help.position = Vector2(0, 115)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var dial := Panel.new()
	dial.size = Vector2(280, 280)
	dial.position = Vector2((vp.x - 280) * 0.5, (vp.y - 280) * 0.5 - 10)
	var dial_style := StyleBoxFlat.new()
	dial_style.bg_color = Color(0.06, 0.06, 0.06, 0.94)
	dial_style.border_width_left = 4
	dial_style.border_width_top = 4
	dial_style.border_width_right = 4
	dial_style.border_width_bottom = 4
	dial_style.border_color = Color(0.8, 0.8, 0.8, 0.8)
	dial_style.corner_radius_top_left = 160
	dial_style.corner_radius_top_right = 160
	dial_style.corner_radius_bottom_left = 160
	dial_style.corner_radius_bottom_right = 160
	dial.add_theme_stylebox_override("panel", dial_style)
	qte_layer.add_child(dial)

	var pivot := ColorRect.new()
	pivot.size = Vector2(12, 12)
	pivot.position = dial.size * 0.5 - Vector2(6, 6)
	pivot.color = Color.WHITE
	dial.add_child(pivot)

	var target_angle := randf_range(-58.0, 58.0)
	var target_dot := ColorRect.new()
	target_dot.size = Vector2(16, 16)
	var target_radius := 104.0
	var target_rad := deg_to_rad(target_angle - 90.0)
	var target_center := dial.size * 0.5 + Vector2(cos(target_rad), sin(target_rad)) * target_radius
	target_dot.position = target_center - target_dot.size * 0.5
	target_dot.color = Color(1.0, 0.86, 0.2, 1.0)
	dial.add_child(target_dot)

	var needle := ColorRect.new()
	needle.size = Vector2(6, 112)
	needle.position = dial.size * 0.5 - Vector2(3, 100)
	needle.pivot_offset = Vector2(3, 100)
	needle.color = Color(1.0, 0.3, 0.3, 1.0)
	dial.add_child(needle)

	Input.flush_buffered_events()

	var result := 0
	var total_ms := 1500
	var start_ms := Time.get_ticks_msec()
	var end_hold_ms := -1

	while true:
		await bf.get_tree().process_frame

		var now := Time.get_ticks_msec()

		if end_hold_ms > 0:
			if now >= end_hold_ms:
				break
			continue

		var elapsed := now - start_ms
		if elapsed >= total_ms:
			help.text = "TOO LATE"
			help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			if bf.miss_sound and bf.miss_sound.stream != null:
				bf.miss_sound.play()
			end_hold_ms = now + 340
			continue

		var swing_t: float = float(elapsed) / 1000.0
		var current_angle: float = sin(swing_t * 9.6) * 70.0
		needle.rotation_degrees = current_angle

		if Input.is_action_just_pressed("ui_accept"):
			var diff: float = abs(current_angle - target_angle)

			if diff <= 4.0:
				result = 2
				help.text = "PERFECT MIRACLE"
				help.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
				needle.color = Color.WHITE
				target_dot.color = Color.WHITE
				if bf.crit_sound and bf.crit_sound.stream != null:
					bf.crit_sound.play()
				bf.screen_shake(16.0, 0.24)
			elif diff <= 10.0:
				result = 1
				help.text = "SAVED"
				help.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
				needle.color = Color(1.0, 1.0, 0.6)
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.2
					bf.select_sound.play()
				bf.screen_shake(8.0, 0.12)
			else:
				result = 0
				help.text = "FAILED"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()

			end_hold_ms = now + 340

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result


# =========================================================
# KNIGHT QTE 1: CHARGE
# Hold and Release minigame
# =========================================================
func run_charge_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker):
		return 0

	bf.get_tree().paused = true

	var qte_layer := CanvasLayer.new()
	qte_layer.layer = 200
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp := bf.get_viewport_rect().size

	var dimmer := ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.10, 0.06, 0.02, 0.60)
	qte_layer.add_child(dimmer)

	var title := Label.new()
	title.text = "CHARGE"
	title.position = Vector2(0, 90)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.80, 0.40))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help := Label.new()
	help.text = "HOLD SPACE, RELEASE IN GREEN"
	help.position = Vector2(0, 135)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var bar_bg := ColorRect.new()
	bar_bg.size = Vector2(520, 34)
	bar_bg.position = Vector2((vp.x - 520) * 0.5, vp.y * 0.5 - 10)
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.96)
	qte_layer.add_child(bar_bg)

	var green_zone := ColorRect.new()
	green_zone.size = Vector2(70, 34)
	green_zone.position = Vector2(365, 0)
	green_zone.color = Color(0.25, 0.9, 0.25, 0.9)
	bar_bg.add_child(green_zone)

	var perfect_zone := ColorRect.new()
	perfect_zone.size = Vector2(22, 34)
	perfect_zone.position = Vector2((green_zone.size.x - 22) * 0.5, 0)
	perfect_zone.color = Color(1.0, 0.86, 0.2, 0.95)
	green_zone.add_child(perfect_zone)

	var fill := ColorRect.new()
	fill.size = Vector2(0, 34)
	fill.position = Vector2.ZERO
	fill.color = Color(1.0, 0.7, 0.25, 1.0)
	bar_bg.add_child(fill)

	Input.flush_buffered_events()

	var result := 0
	var charging := false
	var start_charge_ms := 0
	var fill_ms := 1400
	var wait_start_ms := Time.get_ticks_msec()
	var end_hold_ms := -1

	while true:
		await bf.get_tree().process_frame

		var now := Time.get_ticks_msec()

		if end_hold_ms > 0:
			if now >= end_hold_ms:
				break
			continue

		if not charging:
			if now - wait_start_ms > 1800:
				help.text = "TOO SLOW"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()
				end_hold_ms = now + 320
				continue

			if Input.is_action_just_pressed("ui_accept"):
				charging = true
				start_charge_ms = now
		else:
			var elapsed: int = now - start_charge_ms
			var progress: float = clamp(float(elapsed) / float(fill_ms), 0.0, 1.0)
			fill.size.x = progress * bar_bg.size.x

			if fill.size.x >= green_zone.position.x:
				green_zone.color = Color(0.4 + randf() * 0.4, 1.0, 0.4 + randf() * 0.2, 1.0)
			else:
				green_zone.color = Color(0.25, 0.9, 0.25, 0.9)

			if Input.is_action_just_released("ui_accept"):
				var tip: float = fill.size.x
				var good_start: float = green_zone.position.x
				var good_end: float = green_zone.position.x + green_zone.size.x
				var perfect_start: float = good_start + perfect_zone.position.x
				var perfect_end: float = perfect_start + perfect_zone.size.x

				if tip >= perfect_start and tip <= perfect_end:
					result = 2
					help.text = "PERFECT CHARGE"
					help.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
					if bf.crit_sound and bf.crit_sound.stream != null:
						bf.crit_sound.play()
					bf.screen_shake(14.0, 0.22)
				elif tip >= good_start and tip <= good_end:
					result = 1
					help.text = "GOOD CHARGE"
					help.add_theme_color_override("font_color", Color(0.3, 1.0, 0.35))
					if bf.select_sound and bf.select_sound.stream != null:
						bf.select_sound.pitch_scale = 1.18
						bf.select_sound.play()
					bf.screen_shake(7.0, 0.12)
				else:
					result = 0
					help.text = "BAD RELEASE"
					help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
					if bf.miss_sound and bf.miss_sound.stream != null:
						bf.miss_sound.play()

				end_hold_ms = now + 320

			elif progress >= 1.0:
				help.text = "OVERCHARGED"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()
				end_hold_ms = now + 320

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result


# =========================================================
# KNIGHT QTE 2: SHIELD BASH
# 3-Arrow Sequence minigame
# =========================================================
func run_shield_bash_minigame(bf: Node2D, defender: Node2D) -> int:
	var result: int = 0
	if defender == null or not is_instance_valid(defender): return result

	bf.get_tree().paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 200
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.04, 0.05, 0.08, 0.66)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "SHIELD BASH"
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "MEMORIZE THE 3 ARROWS, THEN INPUT FAST"
	help.position = Vector2(0, 125)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var panel: ColorRect = ColorRect.new()
	panel.size = Vector2(560, 210)
	panel.position = Vector2((vp.x - 560) * 0.5, vp.y * 0.5 - 20)
	panel.color = Color(0.08, 0.08, 0.08, 0.96)
	qte_layer.add_child(panel)

	var prompt: Label = Label.new()
	prompt.text = "-"
	prompt.position = Vector2(0, 24)
	prompt.size = Vector2(panel.size.x, 70)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 54)
	prompt.add_theme_color_override("font_color", Color.WHITE)
	prompt.add_theme_constant_override("outline_size", 8)
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	panel.add_child(prompt)

	var status: Label = Label.new()
	status.text = "WATCH"
	status.position = Vector2(0, 98)
	status.size = Vector2(panel.size.x, 32)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 24)
	status.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	status.add_theme_constant_override("outline_size", 6)
	status.add_theme_color_override("font_outline_color", Color.BLACK)
	panel.add_child(status)

	var action_names: Array[String] = ["ui_up", "ui_left", "ui_right", "ui_down"]
	var display_names: Array[String] = ["UP", "LEFT", "RIGHT", "DOWN"]

	var sequence: Array[int] = []
	for i in range(3): sequence.append(randi() % 4)

	Input.flush_buffered_events()

	for i in range(sequence.size()):
		var show_start: int = Time.get_ticks_msec()
		prompt.text = display_names[sequence[i]]
		prompt.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))

		while Time.get_ticks_msec() - show_start < 320:
			await bf.get_tree().process_frame

		var gap_start: int = Time.get_ticks_msec()
		prompt.text = "-"
		prompt.add_theme_color_override("font_color", Color.WHITE)

		while Time.get_ticks_msec() - gap_start < 100:
			await bf.get_tree().process_frame

		if bf.select_sound and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.0 + float(i) * 0.05
			bf.select_sound.play()

	# THE FIX: Hide the prompt
	status.text = "REPEAT"
	status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.35))
	prompt.text = "INPUT"

	var correct_count: int = 0
	var input_start_ms: int = Time.get_ticks_msec()
	var total_input_ms: int = 2600

	while true:
		await bf.get_tree().process_frame

		var now: int = Time.get_ticks_msec()
		if now - input_start_ms >= total_input_ms:
			status.text = "TOO SLOW"
			status.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			break

		var pressed_index: int = -1
		for i in range(action_names.size()):
			if Input.is_action_just_pressed(action_names[i]):
				pressed_index = i
				break

		if pressed_index == -1: continue

		if pressed_index == sequence[correct_count]:
			correct_count += 1
			if bf.select_sound and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.14 + float(correct_count) * 0.05
				bf.select_sound.play()

			if correct_count >= sequence.size():
				break
		else:
			status.text = "FAILED"
			status.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			if bf.miss_sound and bf.miss_sound.stream != null: bf.miss_sound.play()
			correct_count = 0
			break

	if correct_count >= 3:
		var elapsed_input: int = Time.get_ticks_msec() - input_start_ms
		result = 2 if elapsed_input <= 1400 else 1

		if result == 2:
			status.text = "PERFECT COUNTER"
			status.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
			if bf.crit_sound and bf.crit_sound.stream != null: bf.crit_sound.play()
			bf.screen_shake(12.0, 0.20)
		else:
			status.text = "COUNTER READY"
			status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.35))
			if bf.select_sound and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.18
				bf.select_sound.play()
			bf.screen_shake(6.0, 0.10)

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 340:
		await bf.get_tree().process_frame

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result

# =========================================================
# KNIGHT QTE 3: UNBREAKABLE BASTION
# Left/Right Alternating minigame
# =========================================================
func run_unbreakable_bastion_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender):
		return 0

	var tree := bf.get_tree()
	var was_paused: bool = tree.paused
	var old_select_pitch: float = 1.0
	if bf.select_sound:
		old_select_pitch = bf.select_sound.pitch_scale

	tree.paused = true

	var qte_layer := CanvasLayer.new()
	qte_layer.layer = 200
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp := bf.get_viewport_rect().size

	var dimmer := ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.02, 0.03, 0.06, 0.72)
	qte_layer.add_child(dimmer)

	var title := Label.new()
	title.text = "UNBREAKABLE BASTION"
	title.position = Vector2(0, 70)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help := Label.new()
	help.text = "ALTERNATE LEFT / RIGHT TO BRACE"
	help.position = Vector2(0, 115)
	title.size = Vector2(vp.x, 42)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var bar_bg := ColorRect.new()
	bar_bg.size = Vector2(540, 36)
	bar_bg.position = Vector2((vp.x - 540) * 0.5, vp.y * 0.5 - 8)
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.96)
	qte_layer.add_child(bar_bg)

	var fill := ColorRect.new()
	fill.size = Vector2(0, 36)
	fill.position = Vector2.ZERO
	fill.color = Color(0.70, 0.85, 1.0, 1.0)
	bar_bg.add_child(fill)

	var good_line := ColorRect.new()
	good_line.size = Vector2(4, 36)
	good_line.position = Vector2(bar_bg.size.x * 0.70, 0)
	good_line.color = Color(0.35, 1.0, 0.35, 0.95)
	bar_bg.add_child(good_line)

	var perfect_line := ColorRect.new()
	perfect_line.size = Vector2(4, 36)
	perfect_line.position = Vector2(bar_bg.size.x * 0.92, 0)
	perfect_line.color = Color(1.0, 0.86, 0.2, 0.98)
	bar_bg.add_child(perfect_line)

	var left_label := Label.new()
	left_label.text = "LEFT"
	left_label.position = Vector2(bar_bg.position.x + 90, bar_bg.position.y + 55)
	left_label.add_theme_font_size_override("font_size", 24)
	left_label.add_theme_color_override("font_color", Color.WHITE)
	left_label.add_theme_constant_override("outline_size", 5)
	left_label.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(left_label)

	var right_label := Label.new()
	right_label.text = "RIGHT"
	right_label.position = Vector2(bar_bg.position.x + 360, bar_bg.position.y + 55)
	right_label.add_theme_font_size_override("font_size", 24)
	right_label.add_theme_color_override("font_color", Color.WHITE)
	right_label.add_theme_constant_override("outline_size", 5)
	right_label.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(right_label)

	Input.flush_buffered_events()

	var meter := 18.0
	var total_ms := 2200
	var start_ms := Time.get_ticks_msec()
	var last_ms := start_ms
	var expect_left := true
	var end_hold_ms := -1
	var result := 0

	while true:
		await tree.process_frame

		var now := Time.get_ticks_msec()

		if end_hold_ms > 0:
			if now >= end_hold_ms:
				break
			continue

		var elapsed_total := now - start_ms
		if elapsed_total >= total_ms:
			if meter >= 92.0:
				result = 2
				help.text = "PERFECT BASTION"
				help.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
				if bf.crit_sound and bf.crit_sound.stream != null:
					bf.crit_sound.play()
				bf.screen_shake(12.0, 0.20)
			elif meter >= 70.0:
				result = 1
				help.text = "STRONG BRACE"
				help.add_theme_color_override("font_color", Color(0.3, 1.0, 0.35))
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.16
					bf.select_sound.play()
				bf.screen_shake(6.0, 0.10)
			else:
				result = 0
				help.text = "NOT ENOUGH"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()
			end_hold_ms = now + 340
			continue

		var dt := float(now - last_ms) / 1000.0
		last_ms = now

		meter -= 18.0 * dt
		meter = clampf(meter, 0.0, 100.0)

		var left_pressed: bool = Input.is_action_just_pressed("ui_left")
		var right_pressed: bool = Input.is_action_just_pressed("ui_right")

		if left_pressed and right_pressed:
			meter -= 8.0
			if bf.miss_sound and bf.miss_sound.stream != null:
				bf.miss_sound.play()
		elif left_pressed:
			if expect_left:
				meter += 14.0
				expect_left = false
				left_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
				right_label.add_theme_color_override("font_color", Color.WHITE)
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.12
					bf.select_sound.play()
			else:
				meter -= 8.0
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()
		elif right_pressed:
			if not expect_left:
				meter += 14.0
				expect_left = true
				right_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
				left_label.add_theme_color_override("font_color", Color.WHITE)
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.12
					bf.select_sound.play()
			else:
				meter -= 8.0
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()

		meter = clampf(meter, 0.0, 100.0)
		fill.size.x = (meter / 100.0) * bar_bg.size.x

	qte_layer.queue_free()
	tree.paused = was_paused
	if bf.select_sound:
		bf.select_sound.pitch_scale = old_select_pitch
	return result
		
# =========================================================
# MAGE QTE 1: FIREBALL
# Target box overlap timing minigame
# =========================================================
func run_fireball_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker): return result

	bf.get_tree().paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 210
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.16, 0.05, 0.02, 0.66)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "FIREBALL"
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.28))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "PRESS SPACE WHEN THE BOX FITS THE TARGET"
	help.position = Vector2(0, 125)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var center: Vector2 = vp * 0.5 + Vector2(0, 10)

	var enemy_box: ColorRect = ColorRect.new()
	enemy_box.size = Vector2(128, 128)
	enemy_box.position = center - enemy_box.size * 0.5
	enemy_box.color = Color(0.35, 0.10, 0.10, 0.9)
	qte_layer.add_child(enemy_box)

	var enemy_inner: ColorRect = ColorRect.new()
	enemy_inner.size = Vector2(64, 64)
	enemy_inner.position = enemy_box.position + Vector2(32, 32)
	enemy_inner.color = Color(1.0, 0.86, 0.20, 0.75)
	qte_layer.add_child(enemy_inner)

	var shrinking_box: Panel = Panel.new()
	shrinking_box.size = Vector2(280, 280)
	shrinking_box.position = center - shrinking_box.size * 0.5
	var shrink_style: StyleBoxFlat = StyleBoxFlat.new()
	shrink_style.bg_color = Color(0, 0, 0, 0)
	shrink_style.border_width_left = 6
	shrink_style.border_width_top = 6
	shrink_style.border_width_right = 6
	shrink_style.border_width_bottom = 6
	shrink_style.border_color = Color(1.0, 0.55, 0.15, 1.0)
	shrink_style.corner_radius_top_left = 4
	shrink_style.corner_radius_top_right = 4
	shrink_style.corner_radius_bottom_left = 4
	shrink_style.corner_radius_bottom_right = 4
	shrinking_box.add_theme_stylebox_override("panel", shrink_style)
	qte_layer.add_child(shrinking_box)

	Input.flush_buffered_events()

	var total_ms: int = 850
	var start_ms: int = Time.get_ticks_msec()
	var end_hold_ms: int = -1
	var start_size: float = 280.0
	
	# THE FIX: End size must be smaller than the 64x64 target box to allow a Perfect score!
	var end_size: float = 52.0

	while true:
		await bf.get_tree().process_frame
		var now: int = Time.get_ticks_msec()

		if end_hold_ms > 0:
			if now >= end_hold_ms: break
			continue

		var elapsed: int = now - start_ms
		if elapsed >= total_ms:
			help.text = "MISSED"
			help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			if bf.miss_sound and bf.miss_sound.stream != null: bf.miss_sound.play()
			end_hold_ms = now + 320
			continue

		var t: float = float(elapsed) / float(total_ms)
		var size_now: float = lerp(start_size, end_size, t)
		shrinking_box.size = Vector2(size_now, size_now)
		shrinking_box.position = center - shrinking_box.size * 0.5

		if Input.is_action_just_pressed("ui_accept"):
			var good_ok: bool = shrinking_box.position.x >= enemy_box.position.x \
				and shrinking_box.position.y >= enemy_box.position.y \
				and shrinking_box.position.x + shrinking_box.size.x <= enemy_box.position.x + enemy_box.size.x \
				and shrinking_box.position.y + shrinking_box.size.y <= enemy_box.position.y + enemy_box.size.y

			var perfect_ok: bool = shrinking_box.position.x >= enemy_inner.position.x \
				and shrinking_box.position.y >= enemy_inner.position.y \
				and shrinking_box.position.x + shrinking_box.size.x <= enemy_inner.position.x + enemy_inner.size.x \
				and shrinking_box.position.y + shrinking_box.size.y <= enemy_inner.position.y + enemy_inner.size.y

			if perfect_ok:
				result = 2
				help.text = "PERFECT"
				help.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
				shrink_style.border_color = Color.WHITE
				if bf.crit_sound and bf.crit_sound.stream != null: bf.crit_sound.play()
				bf.screen_shake(14.0, 0.20)
			elif good_ok:
				result = 1
				help.text = "DIRECT HIT"
				help.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.18
					bf.select_sound.play()
				bf.screen_shake(8.0, 0.12)
			else:
				result = 0
				help.text = "GLANCING"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				if bf.miss_sound and bf.miss_sound.stream != null: bf.miss_sound.play()

			end_hold_ms = now + 320

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result
	
# =========================================================
# MAGE QTE 2: ARCANE SHIFT
# Alternating Phase minigame
# =========================================================
func run_arcane_shift_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender):
		return 0

	var tree := bf.get_tree()
	var was_paused: bool = tree.paused
	var old_select_pitch: float = 1.0
	if bf.select_sound:
		old_select_pitch = bf.select_sound.pitch_scale

	tree.paused = true

	var qte_layer := CanvasLayer.new()
	qte_layer.layer = 210
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp := bf.get_viewport_rect().size

	var dimmer := ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.04, 0.02, 0.10, 0.70)
	qte_layer.add_child(dimmer)

	var title := Label.new()
	title.text = "ARCANE SHIFT"
	title.position = Vector2(0, 75)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.78, 0.72, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help := Label.new()
	help.text = "ALTERNATE UP / DOWN TO PHASE OUT"
	help.position = Vector2(0, 120)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var bar_bg := ColorRect.new()
	bar_bg.size = Vector2(520, 36)
	bar_bg.position = Vector2((vp.x - 520) * 0.5, vp.y * 0.5 - 10)
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.96)
	qte_layer.add_child(bar_bg)

	var fill := ColorRect.new()
	fill.size = Vector2(0, 36)
	fill.position = Vector2.ZERO
	fill.color = Color(0.7, 0.5, 1.0, 1.0)
	bar_bg.add_child(fill)

	var good_line := ColorRect.new()
	good_line.size = Vector2(4, 36)
	good_line.position = Vector2(bar_bg.size.x * 0.66, 0)
	good_line.color = Color(0.3, 1.0, 0.35, 0.95)
	bar_bg.add_child(good_line)

	var perfect_line := ColorRect.new()
	perfect_line.size = Vector2(4, 36)
	perfect_line.position = Vector2(bar_bg.size.x * 0.90, 0)
	perfect_line.color = Color(1.0, 0.86, 0.2, 0.98)
	bar_bg.add_child(perfect_line)

	Input.flush_buffered_events()

	var meter: float = 18.0
	var expect_up := true
	var total_ms := 2200
	var start_ms := Time.get_ticks_msec()
	var last_ms := start_ms
	var end_hold_ms := -1
	var result := 0

	while true:
		await tree.process_frame

		var now := Time.get_ticks_msec()

		if end_hold_ms > 0:
			if now >= end_hold_ms:
				break
			continue

		var elapsed_total := now - start_ms
		if elapsed_total >= total_ms:
			if meter >= 90.0:
				result = 2
				help.text = "PERFECT SHIFT"
				help.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
				if bf.crit_sound and bf.crit_sound.stream != null:
					bf.crit_sound.play()
				bf.screen_shake(12.0, 0.18)
			elif meter >= 66.0:
				result = 1
				help.text = "PHASED"
				help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.16
					bf.select_sound.play()
				bf.screen_shake(6.0, 0.10)
			else:
				result = 0
				help.text = "FAILED"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()
			end_hold_ms = now + 340
			continue

		var dt: float = float(now - last_ms) / 1000.0
		last_ms = now

		meter -= 18.0 * dt
		meter = clampf(meter, 0.0, 100.0)

		var up_pressed: bool = Input.is_action_just_pressed("ui_up")
		var down_pressed: bool = Input.is_action_just_pressed("ui_down")

		if up_pressed and down_pressed:
			meter -= 8.0
			if bf.miss_sound and bf.miss_sound.stream != null:
				bf.miss_sound.play()
		elif up_pressed:
			if expect_up:
				meter += 14.0
				expect_up = false
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.12
					bf.select_sound.play()
			else:
				meter -= 8.0
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()
		elif down_pressed:
			if not expect_up:
				meter += 14.0
				expect_up = true
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.12
					bf.select_sound.play()
			else:
				meter -= 8.0
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()

		meter = clampf(meter, 0.0, 100.0)
		fill.size.x = (meter / 100.0) * bar_bg.size.x

	qte_layer.queue_free()
	tree.paused = was_paused
	if bf.select_sound:
		bf.select_sound.pitch_scale = old_select_pitch
	return result

# =========================================================
# MAGE QTE 3: METEOR STORM
# Memory Sequence minigame
# =========================================================
func run_meteor_storm_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker):
		return 0

	bf.get_tree().paused = true

	var qte_layer := CanvasLayer.new()
	qte_layer.layer = 210
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp := bf.get_viewport_rect().size

	var dimmer := ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.12, 0.04, 0.02, 0.74)
	qte_layer.add_child(dimmer)

	var title := Label.new()
	title.text = "METEOR STORM"
	title.position = Vector2(0, 70)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.30))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help := Label.new()
	help.text = "MEMORIZE THE 5 ARROWS — THEY VANISH AFTER 1 SECOND"
	help.position = Vector2(0, 115)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var panel := ColorRect.new()
	panel.size = Vector2(700, 240)
	panel.position = Vector2((vp.x - 700) * 0.5, vp.y * 0.5 - 20)
	panel.color = Color(0.08, 0.08, 0.08, 0.96)
	qte_layer.add_child(panel)

	var action_names := ["ui_up", "ui_down", "ui_left", "ui_right"]
	var display_names := ["UP", "DOWN", "LEFT", "RIGHT"]

	var sequence: Array[int] = []
	for i in range(5):
		sequence.append(randi() % 4)

	var labels: Array[Label] = []
	for i in range(5):
		var lbl := Label.new()
		lbl.text = display_names[sequence[i]]
		lbl.position = Vector2(40 + i * 130, 74)
		lbl.size = Vector2(120, 48)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 32)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		panel.add_child(lbl)
		labels.append(lbl)

	Input.flush_buffered_events()

	var reveal_start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - reveal_start < 1000:
		await bf.get_tree().process_frame

	for lbl in labels:
		lbl.text = "?"
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	var status := Label.new()
	status.text = "INPUT"
	status.position = Vector2(0, 150)
	status.size = Vector2(panel.size.x, 36)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 28)
	status.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
	status.add_theme_constant_override("outline_size", 6)
	status.add_theme_color_override("font_outline_color", Color.BLACK)
	panel.add_child(status)

	var correct_count := 0
	var input_start_ms := Time.get_ticks_msec()
	var total_input_ms := 3600

	while true:
		await bf.get_tree().process_frame

		var now := Time.get_ticks_msec()
		if now - input_start_ms >= total_input_ms:
			status.text = "TOO SLOW"
			status.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			break

		var pressed_index := -1
		for i in range(action_names.size()):
			if Input.is_action_just_pressed(action_names[i]):
				pressed_index = i
				break

		if pressed_index == -1:
			continue

		if pressed_index == sequence[correct_count]:
			labels[correct_count].text = display_names[sequence[correct_count]]
			labels[correct_count].add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
			correct_count += 1

			if bf.select_sound and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.14 + correct_count * 0.05
				bf.select_sound.play()

			if correct_count >= sequence.size():
				break
		else:
			status.text = "BROKEN"
			status.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			if bf.miss_sound and bf.miss_sound.stream != null:
				bf.miss_sound.play()
			break

	var result := 0
	if correct_count >= 5:
		result = 2
		status.text = "PERFECT MEMORY"
		status.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
		if bf.crit_sound and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		bf.screen_shake(14.0, 0.20)
	elif correct_count >= 3:
		result = 1
		status.text = "GOOD MEMORY"
		status.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		if bf.select_sound and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.18
			bf.select_sound.play()
		bf.screen_shake(7.0, 0.10)

	var hold_start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 360:
		await bf.get_tree().process_frame

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result

# =========================================================
# MERCENARY QTE 1: FLURRY STRIKE
# Time Trial Mash minigame
# =========================================================
func run_flurry_strike_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker):
		return 0

	bf.get_tree().paused = true

	var qte_layer := CanvasLayer.new()
	qte_layer.layer = 210
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp := bf.get_viewport_rect().size

	var dimmer := ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.05, 0.05, 0.08, 0.66)
	qte_layer.add_child(dimmer)

	var title := Label.new()
	title.text = "FLURRY STRIKE"
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help := Label.new()
	help.text = "TAP SPACE AS FAST AS POSSIBLE"
	help.position = Vector2(0, 125)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var counter := Label.new()
	counter.text = "TAPS: 0"
	counter.position = Vector2(0, vp.y * 0.5 - 40)
	counter.size = Vector2(vp.x, 50)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.add_theme_font_size_override("font_size", 44)
	counter.add_theme_color_override("font_color", Color.WHITE)
	counter.add_theme_constant_override("outline_size", 8)
	counter.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(counter)

	var timer_label := Label.new()
	timer_label.text = "2.00"
	timer_label.position = Vector2(0, vp.y * 0.5 + 20)
	timer_label.size = Vector2(vp.x, 40)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 30)
	timer_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	timer_label.add_theme_constant_override("outline_size", 6)
	timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(timer_label)

	Input.flush_buffered_events()

	var taps := 0
	var total_ms := 2000
	var start_ms := Time.get_ticks_msec()

	while true:
		await bf.get_tree().process_frame

		var now := Time.get_ticks_msec()
		var elapsed := now - start_ms
		if elapsed >= total_ms:
			break

		var remaining: float = float(max(0.0, float(total_ms - elapsed) / 1000.0))
		timer_label.text = "%0.2f" % remaining

		if Input.is_action_just_pressed("ui_accept"):
			taps += 1
			counter.text = "TAPS: " + str(taps)

			if bf.select_sound and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = min(1.05 + float(taps) * 0.015, 1.9)
				bf.select_sound.play()

	var result_hits := 0
	if taps >= 30:
		result_hits = 5
		counter.text = "5 HITS"
		counter.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
		if bf.crit_sound and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		bf.screen_shake(14.0, 0.20)
	elif taps >= 24:
		result_hits = 4
		counter.text = "4 HITS"
		counter.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
	elif taps >= 18:
		result_hits = 3
		counter.text = "3 HITS"
		counter.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
	elif taps >= 12:
		result_hits = 2
		counter.text = "2 HITS"
		counter.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
	elif taps >= 6:
		result_hits = 1
		counter.text = "1 HIT"
		counter.add_theme_color_override("font_color", Color.WHITE)
	else:
		result_hits = 0
		counter.text = "NO COMBO"
		counter.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

	var hold_start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 350:
		await bf.get_tree().process_frame

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result_hits
	
# =========================================================
# MERCENARY QTE 2: BATTLE CRY
# Hold & Release minigame
# =========================================================
func run_battle_cry_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker):
		return 0

	bf.get_tree().paused = true

	var qte_layer := CanvasLayer.new()
	qte_layer.layer = 210
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp := bf.get_viewport_rect().size

	var dimmer := ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.12, 0.05, 0.02, 0.68)
	qte_layer.add_child(dimmer)

	var title := Label.new()
	title.text = "BATTLE CRY"
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help := Label.new()
	help.text = "HOLD SPACE — RELEASE IN THE TINY GREEN WINDOW"
	help.position = Vector2(0, 125)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var bar_bg := ColorRect.new()
	bar_bg.size = Vector2(520, 34)
	bar_bg.position = Vector2((vp.x - 520) * 0.5, vp.y * 0.5 - 10)
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.96)
	qte_layer.add_child(bar_bg)

	var green_zone := ColorRect.new()
	green_zone.size = Vector2(40, 34)
	green_zone.position = Vector2(410, 0)
	green_zone.color = Color(0.25, 0.9, 0.25, 0.95)
	bar_bg.add_child(green_zone)

	var perfect_zone := ColorRect.new()
	perfect_zone.size = Vector2(14, 34)
	perfect_zone.position = Vector2((green_zone.size.x - 14) * 0.5, 0)
	perfect_zone.color = Color(1.0, 0.86, 0.2, 0.98)
	green_zone.add_child(perfect_zone)

	var fill := ColorRect.new()
	fill.size = Vector2(0, 34)
	fill.position = Vector2.ZERO
	fill.color = Color(1.0, 0.74, 0.25, 1.0)
	bar_bg.add_child(fill)

	Input.flush_buffered_events()

	var charging := false
	var charge_start_ms := 0
	var fill_ms := 1500
	var wait_start_ms := Time.get_ticks_msec()
	var end_hold_ms := -1
	var result := 0

	while true:
		await bf.get_tree().process_frame

		var now := Time.get_ticks_msec()

		if end_hold_ms > 0:
			if now >= end_hold_ms:
				break
			continue

		if not charging:
			if now - wait_start_ms > 1800:
				help.text = "TOO SLOW"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()
				end_hold_ms = now + 320
				continue

			if Input.is_action_just_pressed("ui_accept"):
				charging = true
				charge_start_ms = now
		else:
			var elapsed: int = now - charge_start_ms
			var progress: float = clamp(float(elapsed) / float(fill_ms), 0.0, 1.0)
			fill.size.x = progress * bar_bg.size.x

			if Input.is_action_just_released("ui_accept"):
				var tip: float = fill.size.x
				var good_start: float = green_zone.position.x
				var good_end: float = green_zone.position.x + green_zone.size.x
				var perfect_start: float = good_start + perfect_zone.position.x
				var perfect_end: float = perfect_start + perfect_zone.size.x

				if tip >= perfect_start and tip <= perfect_end:
					result = 2
					help.text = "PERFECT CRY"
					help.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
					if bf.crit_sound and bf.crit_sound.stream != null:
						bf.crit_sound.play()
					bf.screen_shake(14.0, 0.20)
				elif tip >= good_start and tip <= good_end:
					result = 1
					help.text = "GOOD CRY"
					help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
					if bf.select_sound and bf.select_sound.stream != null:
						bf.select_sound.pitch_scale = 1.18
						bf.select_sound.play()
					bf.screen_shake(7.0, 0.10)
				else:
					result = 0
					help.text = "WEAK CRY"
					help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
					if bf.miss_sound and bf.miss_sound.stream != null:
						bf.miss_sound.play()

				end_hold_ms = now + 320

			elif progress >= 1.0:
				help.text = "OVERHELD"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()
				end_hold_ms = now + 320

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result

# =========================================================
# MERCENARY QTE 3: BLADE TEMPEST
# Radar Dial minigame
# =========================================================
func run_blade_tempest_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker):
		return 0

	bf.get_tree().paused = true

	var qte_layer := CanvasLayer.new()
	qte_layer.layer = 210
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp := bf.get_viewport_rect().size

	var dimmer := ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.04, 0.06, 0.10, 0.72)
	qte_layer.add_child(dimmer)

	var title := Label.new()
	title.text = "BLADE TEMPEST"
	title.position = Vector2(0, 60)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help := Label.new()
	help.text = "TAP SPACE AS THE NEEDLE PASSES THE 3 GOLD ZONES"
	help.position = Vector2(0, 105)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

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
	qte_layer.add_child(dial)

	var pivot := ColorRect.new()
	pivot.size = Vector2(12, 12)
	pivot.position = dial.size * 0.5 - Vector2(6, 6)
	pivot.color = Color.WHITE
	dial.add_child(pivot)

	var target_angles := [20.0, 150.0, 285.0]
	var target_dots: Array[ColorRect] = []
	var radius := 118.0

	for angle_deg in target_angles:
		var dot := ColorRect.new()
		dot.size = Vector2(18, 18)
		var rad := deg_to_rad(angle_deg - 90.0)
		var center_pos := dial.size * 0.5 + Vector2(cos(rad), sin(rad)) * radius
		dot.position = center_pos - dot.size * 0.5
		dot.color = Color(1.0, 0.86, 0.2, 1.0)
		dial.add_child(dot)
		target_dots.append(dot)

	var needle := ColorRect.new()
	needle.size = Vector2(6, 128)
	needle.position = dial.size * 0.5 - Vector2(3, 114)
	needle.pivot_offset = Vector2(3, 114)
	needle.color = Color(0.85, 0.95, 1.0, 1.0)
	dial.add_child(needle)

	Input.flush_buffered_events()

	var hit_flags := [false, false, false]
	var hits := 0
	var total_ms := 2600
	var start_ms := Time.get_ticks_msec()

	while true:
		await bf.get_tree().process_frame

		var now := Time.get_ticks_msec()
		var elapsed := now - start_ms
		if elapsed >= total_ms:
			break

		var angle: float = fmod(float(elapsed) * 0.42, 360.0)
		needle.rotation_degrees = angle

		if Input.is_action_just_pressed("ui_accept"):
			var found := false

			for i in range(target_angles.size()):
				if hit_flags[i]:
					continue

				var diff: float = float(abs(wrapf(angle - target_angles[i], -180.0, 180.0)))
				if diff <= 8.0:
					hit_flags[i] = true
					hits += 1
					target_dots[i].color = Color(0.35, 1.0, 0.35, 1.0)
					found = true

					if bf.select_sound and bf.select_sound.stream != null:
						bf.select_sound.pitch_scale = 1.15 + float(hits) * 0.08
						bf.select_sound.play()
					break

			if not found:
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()

			if hits >= 3:
				break

	var result: int = 0
	if hits >= 3:
		result = 2
		help.text = "PERFECT TEMPEST"
		help.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
		if bf.crit_sound and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		bf.screen_shake(14.0, 0.20)
	elif hits >= 2:
		result = 1
		help.text = "GOOD TEMPEST"
		help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		if bf.select_sound and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.2
			bf.select_sound.play()
		bf.screen_shake(7.0, 0.10)
	else:
		result = 0
		help.text = "FAILED"
		help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

	var hold_start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 360:
		await bf.get_tree().process_frame

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result	
	
# =========================================================
# MONK QTE 1: CHAKRA
# Balancing Bar minigame
# =========================================================
func run_chakra_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0

	if attacker == null or not is_instance_valid(attacker):
		return result

	bf.get_tree().paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 220
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.03, 0.08, 0.04, 0.72)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "CHAKRA"
	title.position = Vector2(0, 78)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "USE LEFT / RIGHT TO KEEP THE MIND CENTERED"
	help.position = Vector2(0, 122)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.size = Vector2(560, 34)
	bar_bg.position = Vector2((vp.x - 560.0) * 0.5, vp.y * 0.5 - 14.0)
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.96)
	qte_layer.add_child(bar_bg)

	var green_zone: ColorRect = ColorRect.new()
	green_zone.size = Vector2(160, 34)
	green_zone.position = Vector2((bar_bg.size.x - green_zone.size.x) * 0.5, 0)
	green_zone.color = Color(0.25, 0.9, 0.25, 0.85)
	bar_bg.add_child(green_zone)

	var perfect_zone: ColorRect = ColorRect.new()
	perfect_zone.size = Vector2(70, 34)
	perfect_zone.position = Vector2((green_zone.size.x - perfect_zone.size.x) * 0.5, 0)
	perfect_zone.color = Color(1.0, 0.86, 0.2, 0.95)
	green_zone.add_child(perfect_zone)

	var cursor: ColorRect = ColorRect.new()
	cursor.size = Vector2(12, 48)
	cursor.color = Color.WHITE
	bar_bg.add_child(cursor)

	Input.flush_buffered_events()

	var cursor_x: float = bar_bg.size.x * 0.5
	var cursor_velocity: float = 0.0
	var drift_target: float = randf_range(-120.0, 120.0)

	var total_ms: int = 2500
	var start_ms: int = Time.get_ticks_msec()
	var last_ms: int = start_ms
	var next_drift_ms: int = start_ms + 260

	var in_green_ms: int = 0
	var in_perfect_ms: int = 0

	while true:
		await bf.get_tree().process_frame

		var now: int = Time.get_ticks_msec()
		var elapsed_total: int = now - start_ms
		if elapsed_total >= total_ms:
			break

		var delta_ms: int = now - last_ms
		last_ms = now

		if now >= next_drift_ms:
			drift_target = randf_range(-145.0, 145.0)
			next_drift_ms = now + 260

		cursor_velocity = lerpf(cursor_velocity, drift_target, 0.08)

		if Input.is_action_pressed("ui_left"):
			cursor_velocity -= 18.0
		if Input.is_action_pressed("ui_right"):
			cursor_velocity += 18.0

		cursor_velocity *= 0.97
		cursor_x += cursor_velocity * (float(delta_ms) / 1000.0)
		cursor_x = clampf(cursor_x, 0.0, bar_bg.size.x)

		cursor.position = Vector2(cursor_x - cursor.size.x * 0.5, -7.0)

		var green_start: float = green_zone.position.x
		var green_end: float = green_zone.position.x + green_zone.size.x
		var perfect_start: float = green_start + perfect_zone.position.x
		var perfect_end: float = perfect_start + perfect_zone.size.x

		if cursor_x >= green_start and cursor_x <= green_end:
			in_green_ms += delta_ms
		if cursor_x >= perfect_start and cursor_x <= perfect_end:
			in_perfect_ms += delta_ms

	var green_ratio: float = float(in_green_ms) / float(total_ms)
	var perfect_ratio: float = float(in_perfect_ms) / float(total_ms)

	if green_ratio >= 0.72 and perfect_ratio >= 0.28:
		result = 2
		help.text = "PERFECT BALANCE"
		help.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
		if bf.crit_sound and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		bf.screen_shake(12.0, 0.18)
	elif green_ratio >= 0.48:
		result = 1
		help.text = "CENTERED"
		help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		if bf.select_sound and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.15
			bf.select_sound.play()
		bf.screen_shake(6.0, 0.10)
	else:
		result = 0
		help.text = "UNBALANCED"
		help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 360:
		await bf.get_tree().process_frame

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result

# =========================================================
# MONK QTE 2: INNER PEACE
# Multi-hold Meditation minigame
# =========================================================
func run_inner_peace_minigame(bf: Node2D, defender: Node2D) -> int:
	var result: int = 0

	if defender == null or not is_instance_valid(defender):
		return result

	var tree := bf.get_tree()
	var was_paused: bool = tree.paused
	var old_select_pitch: float = 1.0
	if bf.select_sound:
		old_select_pitch = bf.select_sound.pitch_scale

	tree.paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 220
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.05, 0.05, 0.10, 0.76)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "INNER PEACE"
	title.position = Vector2(0, 70)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "INPUT THE 4-ARROW MANTRA BEFORE TIME RUNS OUT"
	help.position = Vector2(0, 115)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var panel: ColorRect = ColorRect.new()
	panel.size = Vector2(680, 220)
	panel.position = Vector2((vp.x - 680.0) * 0.5, vp.y * 0.5 - 25.0)
	panel.color = Color(0.08, 0.08, 0.08, 0.96)
	qte_layer.add_child(panel)

	var status: Label = Label.new()
	status.text = "MEMORIZE"
	status.position = Vector2(0, 22)
	status.size = Vector2(panel.size.x, 36)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 28)
	status.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	status.add_theme_constant_override("outline_size", 6)
	status.add_theme_color_override("font_outline_color", Color.BLACK)
	panel.add_child(status)

	var action_names: Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right"]
	var display_names: Array[String] = ["UP", "DOWN", "LEFT", "RIGHT"]
	var sequence: Array[int] = []
	for i in range(4):
		sequence.append(randi() % 4)

	var labels: Array[Label] = []
	for i in range(4):
		var lbl: Label = Label.new()
		lbl.text = display_names[sequence[i]]
		lbl.position = Vector2(40 + i * 155, 90)
		lbl.size = Vector2(130, 56)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 34)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		panel.add_child(lbl)
		labels.append(lbl)

	var timer_label: Label = Label.new()
	timer_label.text = "2.50"
	timer_label.position = Vector2(0, 162)
	timer_label.size = Vector2(panel.size.x, 34)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 26)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.add_theme_constant_override("outline_size", 6)
	timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	panel.add_child(timer_label)

	Input.flush_buffered_events()

	var reveal_start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - reveal_start_ms < 850:
		await tree.process_frame

	status.text = "INPUT"
	status.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
	labels[0].add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))

	var input_start_ms: int = Time.get_ticks_msec()
	var total_input_ms: int = 2500
	var correct_count: int = 0
	var failed: bool = false

	while true:
		await tree.process_frame
		var now: int = Time.get_ticks_msec()
		var elapsed_input: int = now - input_start_ms
		var remaining_sec: float = maxf(0.0, float(total_input_ms - elapsed_input) / 1000.0)
		timer_label.text = "%0.2f" % remaining_sec

		if elapsed_input >= total_input_ms:
			status.text = "TOO SLOW"
			status.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			failed = true
			if bf.miss_sound and bf.miss_sound.stream != null:
				bf.miss_sound.play()
			break

		var pressed_index: int = -1
		for i in range(action_names.size()):
			if Input.is_action_just_pressed(action_names[i]):
				pressed_index = i
				break

		if pressed_index == -1:
			continue

		if pressed_index == sequence[correct_count]:
			labels[correct_count].add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
			correct_count += 1

			if bf.select_sound and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.10 + float(correct_count) * 0.08
				bf.select_sound.play()

			if correct_count < sequence.size():
				labels[correct_count].add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
			else:
				var final_input_ms: int = now - input_start_ms
				if final_input_ms <= 1250:
					result = 2
					status.text = "PERFECT STILLNESS"
					status.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
					if bf.crit_sound and bf.crit_sound.stream != null:
						bf.crit_sound.play()
					bf.screen_shake(12.0, 0.18)
				else:
					result = 1
					status.text = "CALM"
					status.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
					if bf.select_sound and bf.select_sound.stream != null:
						bf.select_sound.pitch_scale = 1.15
						bf.select_sound.play()
					bf.screen_shake(6.0, 0.10)
				break
		else:
			status.text = "BROKEN FOCUS"
			status.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			failed = true
			if bf.miss_sound and bf.miss_sound.stream != null:
				bf.miss_sound.play()
			break

	if failed:
		result = 0

	var hold_end: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_end < 380:
		await tree.process_frame

	qte_layer.queue_free()
	tree.paused = was_paused
	if bf.select_sound:
		bf.select_sound.pitch_scale = old_select_pitch
	return result
	
# =========================================================
# MONK QTE 3: CHI BURST
# Growing/Shrinking Circle minigame
# =========================================================
func run_chi_burst_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0

	if attacker == null or not is_instance_valid(attacker):
		return result

	bf.get_tree().paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 220
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.08, 0.03, 0.12, 0.76)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "CHI BURST"
	title.position = Vector2(0, 75)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.85, 0.65, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "PRESS SPACE AT THE ABSOLUTE PEAK"
	help.position = Vector2(0, 120)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var circle: Panel = Panel.new()
	var circle_style: StyleBoxFlat = StyleBoxFlat.new()
	circle_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	circle_style.border_width_left = 6
	circle_style.border_width_top = 6
	circle_style.border_width_right = 6
	circle_style.border_width_bottom = 6
	circle_style.border_color = Color(0.85, 0.65, 1.0, 1.0)
	circle_style.corner_radius_top_left = 300
	circle_style.corner_radius_top_right = 300
	circle_style.corner_radius_bottom_left = 300
	circle_style.corner_radius_bottom_right = 300
	circle.add_theme_stylebox_override("panel", circle_style)
	qte_layer.add_child(circle)

	var center: Vector2 = vp * 0.5 + Vector2(0, 20)
	var min_size: float = 60.0
	var max_size: float = 280.0

	Input.flush_buffered_events()

	var total_ms: int = 920
	var peak_ms: int = 460
	var start_ms: int = Time.get_ticks_msec()
	var pressed: bool = false

	while true:
		await bf.get_tree().process_frame

		var now: int = Time.get_ticks_msec()
		var elapsed: int = now - start_ms
		if elapsed >= total_ms:
			break

		var current_size: float = 0.0
		if elapsed <= peak_ms:
			current_size = lerpf(min_size, max_size, float(elapsed) / float(peak_ms))
		else:
			current_size = lerpf(max_size, min_size, float(elapsed - peak_ms) / float(total_ms - peak_ms))

		circle.size = Vector2(current_size, current_size)
		circle.position = center - circle.size * 0.5

		if Input.is_action_just_pressed("ui_accept"):
			pressed = true
			var diff_ms: int = abs(elapsed - peak_ms)

			if diff_ms <= 35:
				result = 2
				help.text = "PERFECT RELEASE"
				help.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
				circle_style.border_color = Color.WHITE
				if bf.crit_sound and bf.crit_sound.stream != null:
					bf.crit_sound.play()
				bf.screen_shake(12.0, 0.18)
			elif diff_ms <= 95:
				result = 1
				help.text = "GOOD RELEASE"
				help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.16
					bf.select_sound.play()
				bf.screen_shake(6.0, 0.10)
			else:
				result = 0
				help.text = "MISTIMED"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()
			break

	if not pressed:
		result = 0
		help.text = "TOO LATE"
		help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 360:
		await bf.get_tree().process_frame

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result

# =========================================================
# MONSTER QTE 1: ROAR
# Shockwave Mash minigame
# =========================================================
func run_roar_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0

	if attacker == null or not is_instance_valid(attacker):
		return result

	bf.get_tree().paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 220
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.14, 0.05, 0.02, 0.78)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "ROAR"
	title.position = Vector2(0, 75)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.65, 0.25))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "MASH SPACE TO EXPAND THE SHOCKWAVE"
	help.position = Vector2(0, 120)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var wave: Panel = Panel.new()
	var wave_style: StyleBoxFlat = StyleBoxFlat.new()
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
	wave.add_theme_stylebox_override("panel", wave_style)
	qte_layer.add_child(wave)

	var counter: Label = Label.new()
	counter.text = "POWER: 0"
	counter.position = Vector2(0, vp.y - 140.0)
	counter.size = Vector2(vp.x, 36)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.add_theme_font_size_override("font_size", 30)
	counter.add_theme_color_override("font_color", Color.WHITE)
	counter.add_theme_constant_override("outline_size", 6)
	counter.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(counter)

	Input.flush_buffered_events()

	var center: Vector2 = vp * 0.5 + Vector2(0, 10)
	var radius: float = 40.0
	var peak_radius: float = radius

	var total_ms: int = 2000
	var start_ms: int = Time.get_ticks_msec()
	var last_ms: int = start_ms

	while true:
		await bf.get_tree().process_frame

		var now: int = Time.get_ticks_msec()
		var elapsed: int = now - start_ms
		if elapsed >= total_ms:
			break

		var delta_sec: float = float(now - last_ms) / 1000.0
		last_ms = now

		radius -= 24.0 * delta_sec
		radius = maxf(36.0, radius)

		if Input.is_action_just_pressed("ui_accept"):
			radius += 18.0
			peak_radius = maxf(peak_radius, radius)

			if bf.select_sound and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = min(1.05 + (radius - 40.0) / 180.0, 1.8)
				bf.select_sound.play()

		wave.size = Vector2(radius * 2.0, radius * 2.0)
		wave.position = center - wave.size * 0.5
		counter.text = "POWER: " + str(int(round(peak_radius - 40.0)))

	if peak_radius >= 220.0:
		result = 2
		help.text = "PERFECT ROAR"
		help.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
		if bf.crit_sound and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		bf.screen_shake(14.0, 0.20)
	elif peak_radius >= 145.0:
		result = 1
		help.text = "GOOD ROAR"
		help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		if bf.select_sound and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.18
			bf.select_sound.play()
		bf.screen_shake(6.0, 0.10)
	else:
		result = 0
		help.text = "WEAK ROAR"
		help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 360:
		await bf.get_tree().process_frame

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result

# =========================================================
# MONSTER QTE 2: FRENZY
# Whack-A-Mole minigame
# =========================================================
func run_frenzy_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0

	if attacker == null or not is_instance_valid(attacker):
		return result

	bf.get_tree().paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 220
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.12, 0.02, 0.02, 0.78)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "FRENZY"
	title.position = Vector2(0, 72)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "HIT THE YELLOW DIRECTION IMMEDIATELY"
	help.position = Vector2(0, 116)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var center_x: float = vp.x * 0.5
	var center_y: float = vp.y * 0.5

	var up_box: ColorRect = ColorRect.new()
	up_box.size = Vector2(120, 120)
	up_box.position = Vector2(center_x - 60.0, center_y - 185.0)
	up_box.color = Color(0.18, 0.18, 0.18, 0.96)
	qte_layer.add_child(up_box)

	var down_box: ColorRect = ColorRect.new()
	down_box.size = Vector2(120, 120)
	down_box.position = Vector2(center_x - 60.0, center_y + 65.0)
	down_box.color = Color(0.18, 0.18, 0.18, 0.96)
	qte_layer.add_child(down_box)

	var left_box: ColorRect = ColorRect.new()
	left_box.size = Vector2(120, 120)
	left_box.position = Vector2(center_x - 185.0, center_y - 60.0)
	left_box.color = Color(0.18, 0.18, 0.18, 0.96)
	qte_layer.add_child(left_box)

	var right_box: ColorRect = ColorRect.new()
	right_box.size = Vector2(120, 120)
	right_box.position = Vector2(center_x + 65.0, center_y - 60.0)
	right_box.color = Color(0.18, 0.18, 0.18, 0.96)
	qte_layer.add_child(right_box)

	var up_label: Label = Label.new()
	up_label.text = "UP"
	up_label.size = up_box.size
	up_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	up_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	up_label.add_theme_font_size_override("font_size", 34)
	up_label.add_theme_color_override("font_color", Color.WHITE)
	up_label.add_theme_constant_override("outline_size", 6)
	up_label.add_theme_color_override("font_outline_color", Color.BLACK)
	up_box.add_child(up_label)

	var down_label: Label = Label.new()
	down_label.text = "DOWN"
	down_label.size = down_box.size
	down_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	down_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	down_label.add_theme_font_size_override("font_size", 34)
	down_label.add_theme_color_override("font_color", Color.WHITE)
	down_label.add_theme_constant_override("outline_size", 6)
	down_label.add_theme_color_override("font_outline_color", Color.BLACK)
	down_box.add_child(down_label)

	var left_label: Label = Label.new()
	left_label.text = "LEFT"
	left_label.size = left_box.size
	left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left_label.add_theme_font_size_override("font_size", 34)
	left_label.add_theme_color_override("font_color", Color.WHITE)
	left_label.add_theme_constant_override("outline_size", 6)
	left_label.add_theme_color_override("font_outline_color", Color.BLACK)
	left_box.add_child(left_label)

	var right_label: Label = Label.new()
	right_label.text = "RIGHT"
	right_label.size = right_box.size
	right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right_label.add_theme_font_size_override("font_size", 34)
	right_label.add_theme_color_override("font_color", Color.WHITE)
	right_label.add_theme_constant_override("outline_size", 6)
	right_label.add_theme_color_override("font_outline_color", Color.BLACK)
	right_box.add_child(right_label)

	var boxes: Array[ColorRect] = [up_box, down_box, left_box, right_box]
	var actions: Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right"]

	var hit_counter: Label = Label.new()
	hit_counter.text = "HITS: 0"
	hit_counter.position = Vector2(0, vp.y - 130.0)
	hit_counter.size = Vector2(vp.x, 36)
	hit_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hit_counter.add_theme_font_size_override("font_size", 30)
	hit_counter.add_theme_color_override("font_color", Color.WHITE)
	hit_counter.add_theme_constant_override("outline_size", 6)
	hit_counter.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(hit_counter)

	Input.flush_buffered_events()

	var hits: int = 0
	var rounds: int = 8

	for round_index in range(rounds):
		for box in boxes:
			box.color = Color(0.18, 0.18, 0.18, 0.96)

		var active_index: int = randi() % 4
		boxes[active_index].color = Color(1.0, 0.86, 0.2, 1.0)

		var round_start_ms: int = Time.get_ticks_msec()
		var round_window_ms: int = max(210, 420 - round_index * 18)
		var resolved: bool = false

		while true:
			await bf.get_tree().process_frame

			var now: int = Time.get_ticks_msec()
			if now - round_start_ms >= round_window_ms:
				break

			var pressed_index: int = -1
			for i in range(actions.size()):
				if Input.is_action_just_pressed(actions[i]):
					pressed_index = i
					break

			if pressed_index == -1:
				continue

			resolved = true
			if pressed_index == active_index:
				hits += 1
				hit_counter.text = "HITS: " + str(hits)
				boxes[active_index].color = Color(0.35, 1.0, 0.35, 1.0)
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.10 + float(hits) * 0.04
					bf.select_sound.play()
			else:
				boxes[active_index].color = Color(1.0, 0.3, 0.3, 1.0)
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()
			break

		if not resolved and bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

		var short_hold_start: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - short_hold_start < 80:
			await bf.get_tree().process_frame

	result = hits

	if result >= 6:
		help.text = "PERFECT FRENZY"
		help.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
		if bf.crit_sound and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		bf.screen_shake(12.0, 0.18)
	elif result >= 3:
		help.text = "FRENZY BUILDS"
		help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		if bf.select_sound and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.18
			bf.select_sound.play()
	else:
		help.text = "WILD AND SLOPPY"
		help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 360:
		await bf.get_tree().process_frame

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result

# =========================================================
# MONSTER QTE 3: RENDING CLAW
# Scratch Line minigame
# =========================================================
func run_rending_claw_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0

	if attacker == null or not is_instance_valid(attacker):
		return result

	bf.get_tree().paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 220
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.10, 0.02, 0.02, 0.78)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "RENDING CLAW"
	title.position = Vector2(0, 74)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "PRESS SPACE ON THE GOLD SCRATCH POINT"
	help.position = Vector2(0, 118)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var scratch_line: ColorRect = ColorRect.new()
	scratch_line.size = Vector2(420, 8)
	scratch_line.position = Vector2(vp.x * 0.5 - 210.0, vp.y * 0.5)
	scratch_line.rotation_degrees = 38.0
	scratch_line.color = Color(0.85, 0.85, 0.85, 0.95)
	qte_layer.add_child(scratch_line)

	var line_start: Vector2 = Vector2(vp.x * 0.5 - 170.0, vp.y * 0.5 - 135.0)
	var line_end: Vector2 = Vector2(vp.x * 0.5 + 170.0, vp.y * 0.5 + 135.0)

	var sweet_t: float = randf_range(0.58, 0.82)
	var sweet_pos: Vector2 = line_start.lerp(line_end, sweet_t)

	var sweet_box: ColorRect = ColorRect.new()
	sweet_box.size = Vector2(28, 28)
	sweet_box.position = sweet_pos - sweet_box.size * 0.5
	sweet_box.color = Color(1.0, 0.86, 0.2, 1.0)
	qte_layer.add_child(sweet_box)

	var cursor: ColorRect = ColorRect.new()
	cursor.size = Vector2(22, 22)
	cursor.color = Color.WHITE
	qte_layer.add_child(cursor)

	Input.flush_buffered_events()

	var total_ms: int = 680
	var start_ms: int = Time.get_ticks_msec()
	var pressed: bool = false

	while true:
		await bf.get_tree().process_frame

		var now: int = Time.get_ticks_msec()
		var elapsed: int = now - start_ms
		if elapsed >= total_ms:
			break

		var cursor_t: float = clampf(float(elapsed) / float(total_ms), 0.0, 1.0)
		var cursor_pos: Vector2 = line_start.lerp(line_end, cursor_t)
		cursor.position = cursor_pos - cursor.size * 0.5

		if Input.is_action_just_pressed("ui_accept"):
			pressed = true
			var diff: float = abs(cursor_t - sweet_t)

			if diff <= 0.025:
				result = 2
				help.text = "PERFECT TEAR"
				help.add_theme_color_override("font_color", Color(1.0, 0.86, 0.2))
				cursor.color = Color.WHITE
				if bf.crit_sound and bf.crit_sound.stream != null:
					bf.crit_sound.play()
				bf.screen_shake(12.0, 0.18)
			elif diff <= 0.060:
				result = 1
				help.text = "GOOD TEAR"
				help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
				cursor.color = Color(0.35, 1.0, 0.35)
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.16
					bf.select_sound.play()
				bf.screen_shake(6.0, 0.10)
			else:
				result = 0
				help.text = "BAD ANGLE"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				cursor.color = Color(1.0, 0.3, 0.3)
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()
			break

	if not pressed:
		result = 0
		help.text = "MISSED"
		help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 360:
		await bf.get_tree().process_frame

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result	
	
# =========================================================
# PALADIN QTE 1: SMITE
# Fast Shrinking Target Minigame
# =========================================================
func run_smite_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker): return result

	bf.get_tree().paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 220
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.12, 0.08, 0.0, 0.6)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "SMITE"
	title.position = Vector2(0, 90)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "PRESS SPACE WHEN THE RING ALIGNS"
	help.position = Vector2(0, 140)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var center: Vector2 = vp * 0.5 + Vector2(0, 20)

	var target: Panel = Panel.new()
	target.size = Vector2(80, 80)
	target.position = center - target.size * 0.5
	var target_style: StyleBoxFlat = StyleBoxFlat.new()
	target_style.bg_color = Color(0, 0, 0, 0)
	target_style.border_width_left = 6
	target_style.border_width_top = 6
	target_style.border_width_right = 6
	target_style.border_width_bottom = 6
	target_style.border_color = Color(1.0, 0.4, 0.1, 1.0)
	target_style.corner_radius_top_left = 64
	target_style.corner_radius_top_right = 64
	target_style.corner_radius_bottom_left = 64
	target_style.corner_radius_bottom_right = 64
	target.add_theme_stylebox_override("panel", target_style)
	qte_layer.add_child(target)

	var ring: Panel = Panel.new()
	ring.size = Vector2(260, 260)
	ring.position = center - ring.size * 0.5
	var ring_style: StyleBoxFlat = StyleBoxFlat.new()
	ring_style.bg_color = Color(0, 0, 0, 0)
	ring_style.border_width_left = 8
	ring_style.border_width_top = 8
	ring_style.border_width_right = 8
	ring_style.border_width_bottom = 8
	ring_style.border_color = Color(1.0, 0.9, 0.4, 1.0)
	ring_style.corner_radius_top_left = 140
	ring_style.corner_radius_top_right = 140
	ring_style.corner_radius_bottom_left = 140
	ring_style.corner_radius_bottom_right = 140
	ring.add_theme_stylebox_override("panel", ring_style)
	qte_layer.add_child(ring)

	Input.flush_buffered_events()

	var total_ms: int = 750
	var start_ms: int = Time.get_ticks_msec()
	var start_size: float = 260.0
	var end_size: float = 60.0

	while true:
		await bf.get_tree().process_frame
		var now: int = Time.get_ticks_msec()
		var elapsed: int = now - start_ms

		if elapsed >= total_ms:
			help.text = "FAILED"
			help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			if bf.miss_sound and bf.miss_sound.stream: bf.miss_sound.play()
			break

		var t: float = float(elapsed) / float(total_ms)
		var current_size: float = lerp(start_size, end_size, t)
		ring.size = Vector2(current_size, current_size)
		ring.position = center - ring.size * 0.5

		if Input.is_action_just_pressed("ui_accept"):
			var diff: float = abs(ring.size.x - target.size.x)
			if diff <= 12.0:
				result = 2
				help.text = "PERFECT SMITE"
				help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
				ring_style.border_color = Color.WHITE
				target_style.border_color = Color.WHITE
				if bf.crit_sound and bf.crit_sound.stream: bf.crit_sound.play()
				bf.screen_shake(16.0, 0.22)
			elif diff <= 30.0:
				result = 1
				help.text = "GOOD SMITE"
				help.add_theme_color_override("font_color", Color(0.3, 1.0, 0.35))
				if bf.select_sound and bf.select_sound.stream: 
					bf.select_sound.pitch_scale = 1.2
					bf.select_sound.play()
				bf.screen_shake(8.0, 0.12)
			else:
				result = 0
				help.text = "MISS"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				if bf.miss_sound and bf.miss_sound.stream: bf.miss_sound.play()
			break

	var hold_end: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_end < 360:
		await bf.get_tree().process_frame

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result

# =========================================================
# PALADIN QTE 2: HOLY WARD
# Rapid 4-Arrow Sequence minigame
# =========================================================
func run_holy_ward_minigame(bf: Node2D, defender: Node2D) -> int:
	var result: int = 0
	if defender == null or not is_instance_valid(defender): return result

	bf.get_tree().paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 220
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.02, 0.05, 0.10, 0.70)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "HOLY WARD"
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "INPUT THE 4 ARROWS FAST TO BLOCK MAGIC"
	help.position = Vector2(0, 125)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var panel: ColorRect = ColorRect.new()
	panel.size = Vector2(600, 180)
	panel.position = Vector2((vp.x - 600) * 0.5, vp.y * 0.5 - 20)
	panel.color = Color(0.08, 0.08, 0.08, 0.96)
	qte_layer.add_child(panel)

	var action_names: Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right"]
	var display_names: Array[String] = ["UP", "DOWN", "LEFT", "RIGHT"]
	var sequence: Array[int] = []
	for i in range(4): sequence.append(randi() % 4)

	var labels: Array[Label] = []
	for i in range(4):
		var lbl: Label = Label.new()
		lbl.text = display_names[sequence[i]]
		lbl.position = Vector2(30 + i * 140, 60)
		lbl.size = Vector2(120, 60)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 34)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		panel.add_child(lbl)
		labels.append(lbl)

	Input.flush_buffered_events()

	var correct_count: int = 0
	var input_start_ms: int = Time.get_ticks_msec()
	var total_input_ms: int = 2400

	while true:
		await bf.get_tree().process_frame
		var now: int = Time.get_ticks_msec()

		if now - input_start_ms >= total_input_ms:
			help.text = "TOO SLOW"
			help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			if bf.miss_sound and bf.miss_sound.stream: bf.miss_sound.play()
			break

		var pressed_index: int = -1
		for i in range(action_names.size()):
			if Input.is_action_just_pressed(action_names[i]):
				pressed_index = i
				break

		if pressed_index == -1: continue

		if pressed_index == sequence[correct_count]:
			labels[correct_count].add_theme_color_override("font_color", Color(0.3, 1.0, 0.35))
			correct_count += 1
			if bf.select_sound and bf.select_sound.stream:
				bf.select_sound.pitch_scale = 1.1 + correct_count * 0.08
				bf.select_sound.play()

			if correct_count >= 4:
				var elapsed_input: int = Time.get_ticks_msec() - input_start_ms
				if elapsed_input <= 1000:
					result = 2
					help.text = "PERFECT WARD"
					help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
					if bf.crit_sound and bf.crit_sound.stream: bf.crit_sound.play()
					bf.screen_shake(12.0, 0.20)
				else:
					result = 1
					help.text = "GOOD WARD"
					help.add_theme_color_override("font_color", Color(0.3, 1.0, 0.35))
					bf.screen_shake(6.0, 0.10)
				break
		else:
			help.text = "SEQUENCE BROKEN"
			help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			if bf.miss_sound and bf.miss_sound.stream: bf.miss_sound.play()
			bf.screen_shake(8.0, 0.12)
			break

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 360:
		await bf.get_tree().process_frame

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result

# =========================================================
# PALADIN QTE 3: SACRED JUDGMENT
# Ping-pong power bar minigame
# =========================================================
func run_sacred_judgment_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker):
		return result

	var tree := bf.get_tree()
	var was_paused: bool = tree.paused
	var old_select_pitch: float = 1.0
	if bf.select_sound:
		old_select_pitch = bf.select_sound.pitch_scale

	tree.paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 220
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.12, 0.10, 0.05, 0.76)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "SACRED JUDGMENT"
	title.position = Vector2(0, 75)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "RELEASE NEAR MAX"
	help.position = Vector2(0, 120)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.size = Vector2(560, 40)
	bar_bg.position = Vector2((vp.x - 560.0) * 0.5, vp.y * 0.5 - 20.0)
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.96)
	qte_layer.add_child(bar_bg)

	var fill: ColorRect = ColorRect.new()
	fill.size = Vector2(0, 40)
	fill.position = Vector2.ZERO
	fill.color = Color(1.0, 0.85, 0.3, 1.0)
	bar_bg.add_child(fill)

	var hundred_line: ColorRect = ColorRect.new()
	hundred_line.size = Vector2(6, 40)
	hundred_line.position = Vector2(bar_bg.size.x - 6, 0)
	hundred_line.color = Color.WHITE
	bar_bg.add_child(hundred_line)

	var val_label: Label = Label.new()
	val_label.text = "0%"
	val_label.position = Vector2(0, bar_bg.position.y + 50)
	val_label.size = Vector2(vp.x, 40)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_label.add_theme_font_size_override("font_size", 34)
	val_label.add_theme_color_override("font_color", Color.WHITE)
	val_label.add_theme_constant_override("outline_size", 8)
	val_label.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(val_label)

	Input.flush_buffered_events()

	var charging: bool = false
	var wait_start_ms: int = Time.get_ticks_msec()
	var charge_start_ms: int = 0
	var ping_pong_speed: float = 2.4
	var wait_timeout_ms: int = 2000
	var charge_timeout_ms: int = 2400

	while true:
		await tree.process_frame
		var now: int = Time.get_ticks_msec()

		if not charging:
			if now - wait_start_ms > wait_timeout_ms:
				help.text = "TOO SLOW"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()
				break

			if Input.is_action_just_pressed("ui_accept"):
				charging = true
				charge_start_ms = now
		else:
			if now - charge_start_ms >= charge_timeout_ms:
				result = 0
				help.text = "LOST FOCUS"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()
				break

			var elapsed: float = float(now - charge_start_ms) / 1000.0
			var progress: float = abs(sin(elapsed * ping_pong_speed))

			fill.size.x = progress * bar_bg.size.x
			val_label.text = str(int(progress * 100.0)) + "%"

			if Input.is_action_just_released("ui_accept"):
				var final_val: int = int(progress * 100.0)

				if final_val >= 95:
					result = 2
					help.text = "ABSOLUTE JUDGMENT"
					help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
					if bf.crit_sound and bf.crit_sound.stream != null:
						bf.crit_sound.play()
					bf.screen_shake(16.0, 0.25)
				elif final_val >= 70:
					result = 1
					help.text = "STRONG JUDGMENT"
					help.add_theme_color_override("font_color", Color(0.3, 1.0, 0.35))
					if bf.select_sound and bf.select_sound.stream != null:
						bf.select_sound.pitch_scale = 1.15
						bf.select_sound.play()
					bf.screen_shake(8.0, 0.12)
				else:
					result = 0
					help.text = "WEAK RELEASE"
					help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
					if bf.miss_sound and bf.miss_sound.stream != null:
						bf.miss_sound.play()
				break

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 400:
		await tree.process_frame

	qte_layer.queue_free()
	tree.paused = was_paused
	if bf.select_sound:
		bf.select_sound.pitch_scale = old_select_pitch
	return result
	
# =========================================================
# SPELLBLADE QTE 1: FLAME BLADE
# Hovering Heat Gauge Minigame
# =========================================================
func run_flame_blade_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker): return result

	bf.get_tree().paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 220
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.12, 0.03, 0.03, 0.70)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "FLAME BLADE"
	title.position = Vector2(0, 60)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "HOLD SPACE TO FLY. STAY IN THE MOVING BOX!"
	help.position = Vector2(0, 105)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.size = Vector2(40, 300)
	bar_bg.position = Vector2((vp.x - 40) * 0.5, vp.y * 0.5 - 150)
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.96)
	qte_layer.add_child(bar_bg)

	var target_box: ColorRect = ColorRect.new()
	target_box.size = Vector2(40, 80)
	target_box.position = Vector2(0, 110)
	target_box.color = Color(1.0, 0.6, 0.1, 0.6)
	bar_bg.add_child(target_box)

	var cursor: ColorRect = ColorRect.new()
	cursor.size = Vector2(30, 10)
	cursor.position = Vector2(5, 280)
	cursor.color = Color.WHITE
	bar_bg.add_child(cursor)

	var heat_bg: ColorRect = ColorRect.new()
	heat_bg.size = Vector2(300, 20)
	heat_bg.position = Vector2((vp.x - 300) * 0.5, bar_bg.position.y + 330)
	heat_bg.color = Color(0.1, 0.1, 0.1, 0.9)
	qte_layer.add_child(heat_bg)

	var heat_fill: ColorRect = ColorRect.new()
	heat_fill.size = Vector2(0, 20)
	heat_fill.position = Vector2.ZERO
	heat_fill.color = Color(1.0, 0.4, 0.1)
	heat_bg.add_child(heat_fill)

	Input.flush_buffered_events()

	var total_ms: int = 2500
	var start_ms: int = Time.get_ticks_msec()
	var last_ms: int = start_ms
	var heat: float = 0.0

	var cursor_y: float = 280.0
	var gravity: float = 220.0
	var fly_power: float = -280.0
	
	var target_base_y: float = 110.0
	var target_speed: float = 3.5

	while true:
		await bf.get_tree().process_frame

		var now: int = Time.get_ticks_msec()
		var elapsed_total: int = now - start_ms
		if elapsed_total >= total_ms:
			break

		var delta_sec: float = float(now - last_ms) / 1000.0
		last_ms = now

		# Move Target (Sine wave pattern)
		var t: float = float(elapsed_total) / 1000.0
		target_box.position.y = target_base_y + float(sin(t * target_speed)) * 90.0

		# Move Cursor
		if Input.is_action_pressed("ui_accept"):
			cursor_y += fly_power * delta_sec
		else:
			cursor_y += gravity * delta_sec

		cursor_y = clampf(cursor_y, 0.0, bar_bg.size.y - cursor.size.y)
		cursor.position.y = cursor_y

		# Check Overlap
		var cursor_center: float = cursor_y + cursor.size.y * 0.5
		var t_top: float = target_box.position.y
		var t_bot: float = t_top + target_box.size.y

		if cursor_center >= t_top and cursor_center <= t_bot:
			heat += 65.0 * delta_sec
			cursor.color = Color(1.0, 0.8, 0.2)
		else:
			heat -= 25.0 * delta_sec
			cursor.color = Color.WHITE

		heat = clampf(heat, 0.0, 100.0)
		heat_fill.size.x = (heat / 100.0) * heat_bg.size.x

	if heat >= 85.0:
		result = 2
		help.text = "MAXIMUM IGNITION!"
		help.add_theme_color_override("font_color", Color(1.0, 0.5, 0.1))
		if bf.crit_sound and bf.crit_sound.stream: bf.crit_sound.play()
		bf.screen_shake(14.0, 0.20)
	elif heat >= 40.0:
		result = 1
		help.text = "BLADE IGNITED"
		help.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		if bf.select_sound and bf.select_sound.stream: 
			bf.select_sound.pitch_scale = 1.15
			bf.select_sound.play()
		bf.screen_shake(6.0, 0.10)
	else:
		result = 0
		help.text = "FIZZLED"
		help.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		if bf.miss_sound and bf.miss_sound.stream: bf.miss_sound.play()

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 400:
		await bf.get_tree().process_frame

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result

# =========================================================
# SPELLBLADE QTE 2: BLINK STEP
# Pure Reaction Time minigame
# =========================================================
func run_blink_step_minigame(bf: Node2D, defender: Node2D) -> int:
	var result: int = 0
	if defender == null or not is_instance_valid(defender):
		return result

	var tree := bf.get_tree()
	var was_paused: bool = tree.paused
	var old_select_pitch: float = 1.0
	if bf.select_sound:
		old_select_pitch = bf.select_sound.pitch_scale

	tree.paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 220
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.0, 0.0, 0.0, 0.95)
	qte_layer.add_child(dimmer)

	var help: Label = Label.new()
	help.text = "WAIT FOR THE FLASH... THEN PRESS SPACE!"
	help.position = Vector2(0, vp.y * 0.5 - 20)
	help.size = Vector2(vp.x, 40)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 28)
	help.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, null, help)

	Input.flush_buffered_events()

	var wait_ms: int = int(randf_range(1200.0, 3200.0))
	var start_ms: int = Time.get_ticks_msec()
	var false_start: bool = false
	var flash_ms: int = 0

	while true:
		await tree.process_frame
		var now: int = Time.get_ticks_msec()

		# Fairness fix: if the flash should happen on this frame, trigger it before
		# checking for a false start on the same frame.
		if now - start_ms >= wait_ms:
			flash_ms = now
			break

		if Input.is_action_just_pressed("ui_accept"):
			false_start = true
			break

	if false_start:
		result = 0
		help.text = "FALSE START!"
		help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()
	else:
		dimmer.color = Color(0.8, 0.2, 1.0, 0.8)
		help.text = "NOW!"
		help.add_theme_color_override("font_color", Color.WHITE)
		help.add_theme_font_size_override("font_size", 50)
		if bf.select_sound and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.5
			bf.select_sound.play()

		while true:
			await tree.process_frame
			var now: int = Time.get_ticks_msec()
			var reaction_time: int = now - flash_ms

			if reaction_time > 600:
				result = 0
				help.text = "TOO SLOW!"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				dimmer.color = Color(0.0, 0.0, 0.0, 0.95)
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()
				break

			if Input.is_action_just_pressed("ui_accept"):
				if reaction_time <= 280:
					result = 2
					help.text = "PERFECT REFLEX! (" + str(reaction_time) + "ms)"
					help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
					if bf.crit_sound and bf.crit_sound.stream != null:
						bf.crit_sound.play()
					bf.screen_shake(12.0, 0.15)
				else:
					result = 1
					help.text = "GOOD BLINK (" + str(reaction_time) + "ms)"
					help.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
					if bf.select_sound and bf.select_sound.stream != null:
						bf.select_sound.pitch_scale = 1.8
						bf.select_sound.play()
					bf.screen_shake(6.0, 0.10)
				break

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 800:
		await tree.process_frame

	qte_layer.queue_free()
	tree.paused = was_paused
	if bf.select_sound:
		bf.select_sound.pitch_scale = old_select_pitch
	return result

# =========================================================
# SPELLBLADE QTE 3: ELEMENTAL CONVERGENCE
# Multi-Color Mash minigame
# =========================================================
func run_elemental_convergence_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker): return result

	bf.get_tree().paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 220
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.05, 0.02, 0.08, 0.76)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "ELEMENTAL CONVERGENCE"
	title.position = Vector2(0, 70)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "MASH SPACE TO FUSE THE ELEMENTS!"
	help.position = Vector2(0, 115)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.size = Vector2(560, 40)
	bar_bg.position = Vector2((vp.x - 560) * 0.5, vp.y * 0.5 - 10)
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.96)
	qte_layer.add_child(bar_bg)

	var fill: ColorRect = ColorRect.new()
	fill.size = Vector2(0, 40)
	fill.position = Vector2.ZERO
	fill.color = Color(1.0, 0.2, 0.2) # Starts Red (Fire)
	bar_bg.add_child(fill)

	# Tiers
	var ice_line: ColorRect = ColorRect.new()
	ice_line.size = Vector2(4, 40)
	ice_line.position = Vector2(bar_bg.size.x * 0.40, 0)
	ice_line.color = Color.WHITE
	bar_bg.add_child(ice_line)

	var lightning_line: ColorRect = ColorRect.new()
	lightning_line.size = Vector2(4, 40)
	lightning_line.position = Vector2(bar_bg.size.x * 0.85, 0)
	lightning_line.color = Color.WHITE
	bar_bg.add_child(lightning_line)

	Input.flush_buffered_events()

	var meter: float = 15.0
	var total_ms: int = 2500
	var start_ms: int = Time.get_ticks_msec()
	var last_ms: int = start_ms

	while true:
		await bf.get_tree().process_frame

		var now: int = Time.get_ticks_msec()
		var elapsed: int = now - start_ms
		if elapsed >= total_ms:
			break

		var dt: float = float(now - last_ms) / 1000.0
		last_ms = now

		meter -= 28.0 * dt
		meter = clampf(meter, 0.0, 100.0)

		if Input.is_action_just_pressed("ui_accept"):
			meter += 12.0
			meter = clampf(meter, 0.0, 100.0)
			
			if bf.select_sound and bf.select_sound.stream:
				bf.select_sound.pitch_scale = 1.0 + (meter / 100.0)
				bf.select_sound.play()

		fill.size.x = (meter / 100.0) * bar_bg.size.x
		
		# Change colors dynamically as it builds!
		if meter < 40.0:
			fill.color = Color(1.0, 0.2, 0.2) # Fire
		elif meter < 85.0:
			fill.color = Color(0.2, 0.8, 1.0) # Ice
		else:
			fill.color = Color(1.0, 0.85, 0.2) # Lightning

	if meter >= 85.0:
		result = 2
		help.text = "ULTIMATE CONVERGENCE"
		help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		if bf.crit_sound and bf.crit_sound.stream: bf.crit_sound.play()
		bf.screen_shake(18.0, 0.3)
	elif meter >= 40.0:
		result = 1
		help.text = "FUSED MAGIC"
		help.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
		bf.screen_shake(8.0, 0.15)
	else:
		result = 0
		help.text = "FAILED TO FUSE"
		help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.miss_sound and bf.miss_sound.stream: bf.miss_sound.play()

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 400:
		await bf.get_tree().process_frame

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result
	
# =========================================================
# THIEF QTE 1: SHADOW STRIKE
# Sweet spot timing (Moving target inside a band)
# =========================================================
func run_shadow_strike_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker): return result

	bf.get_tree().paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 220
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.02, 0.01, 0.05, 0.85) # Very dark!
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "SHADOW STRIKE"
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.6, 0.3, 0.9))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "PRESS SPACE INSIDE THE SHADOW BAND"
	help.position = Vector2(0, 130)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.size = Vector2(500, 30)
	bar_bg.position = Vector2((vp.x - 500) * 0.5, vp.y * 0.5 - 15)
	bar_bg.color = Color(0.15, 0.15, 0.15, 0.9)
	qte_layer.add_child(bar_bg)

	var shadow_band: ColorRect = ColorRect.new()
	shadow_band.size = Vector2(70, 30)
	var rand_start: float = randf_range(100.0, 330.0)
	shadow_band.position = Vector2(rand_start, 0)
	shadow_band.color = Color(0.4, 0.1, 0.8, 0.8) # Purple target zone
	bar_bg.add_child(shadow_band)

	var perfect_zone: ColorRect = ColorRect.new()
	perfect_zone.size = Vector2(16, 30)
	perfect_zone.position = Vector2((shadow_band.size.x - 16) * 0.5, 0)
	perfect_zone.color = Color(1.0, 0.85, 0.2, 0.9)
	shadow_band.add_child(perfect_zone)

	var cursor: ColorRect = ColorRect.new()
	cursor.size = Vector2(6, 46)
	cursor.position = Vector2(0, -8)
	cursor.color = Color.WHITE
	bar_bg.add_child(cursor)

	Input.flush_buffered_events()

	var sweep_ms: int = 700 # Very fast!
	var start_ms: int = Time.get_ticks_msec()
	var end_hold_ms: int = -1

	while true:
		await bf.get_tree().process_frame
		var now: int = Time.get_ticks_msec()

		if end_hold_ms > 0:
			if now >= end_hold_ms: break
			continue

		var elapsed: int = now - start_ms
		if elapsed >= sweep_ms:
			help.text = "SPOTTED!"
			help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			if bf.miss_sound and bf.miss_sound.stream: bf.miss_sound.play()
			end_hold_ms = now + 320
			continue

		var t: float = float(elapsed) / float(sweep_ms)
		cursor.position.x = t * float(bar_bg.size.x - cursor.size.x)

		if Input.is_action_just_pressed("ui_accept"):
			var cursor_center: float = cursor.position.x + (cursor.size.x * 0.5)
			var band_start: float = shadow_band.position.x
			var band_end: float = band_start + shadow_band.size.x
			var perfect_start: float = band_start + perfect_zone.position.x
			var perfect_end: float = perfect_start + perfect_zone.size.x

			if cursor_center >= perfect_start and cursor_center <= perfect_end:
				result = 2
				help.text = "PERFECT STRIKE"
				help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
				if bf.crit_sound and bf.crit_sound.stream: bf.crit_sound.play()
				bf.screen_shake(14.0, 0.20)
			elif cursor_center >= band_start and cursor_center <= band_end:
				result = 1
				help.text = "HIDDEN STRIKE"
				help.add_theme_color_override("font_color", Color(0.6, 0.3, 0.9))
				if bf.select_sound and bf.select_sound.stream: 
					bf.select_sound.pitch_scale = 1.2
					bf.select_sound.play()
				bf.screen_shake(6.0, 0.1)
			else:
				result = 0
				help.text = "REVEALED!"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				if bf.miss_sound and bf.miss_sound.stream: bf.miss_sound.play()
				
			end_hold_ms = now + 320

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result

# =========================================================
# THIEF QTE 2: ASSASSINATE
# 3-Point Vital Lockpick Minigame
# =========================================================
func run_assassinate_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker): return result

	bf.get_tree().paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 220
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.15, 0.02, 0.02, 0.8) # Deep blood red
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "ASSASSINATE"
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "TAP SPACE ON THE 3 VITAL POINTS!"
	help.position = Vector2(0, 130)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.size = Vector2(600, 20)
	bar_bg.position = Vector2((vp.x - 600) * 0.5, vp.y * 0.5 - 10)
	bar_bg.color = Color(0.05, 0.05, 0.05, 0.9)
	qte_layer.add_child(bar_bg)

	var vitals: Array[ColorRect] = []
	var vital_positions: Array[float] = [100.0, 300.0, 500.0]
	var vital_hit: Array[bool] = [false, false, false]

	for pos_x in vital_positions:
		var v_dot: ColorRect = ColorRect.new()
		v_dot.size = Vector2(16, 36)
		v_dot.position = Vector2(pos_x, -8)
		v_dot.color = Color(1.0, 0.85, 0.2)
		bar_bg.add_child(v_dot)
		vitals.append(v_dot)

	var cursor: ColorRect = ColorRect.new()
	cursor.size = Vector2(6, 40)
	cursor.position = Vector2(0, -10)
	cursor.color = Color.WHITE
	bar_bg.add_child(cursor)

	Input.flush_buffered_events()

	var hits: int = 0
	var total_ms: int = 1500
	var start_ms: int = Time.get_ticks_msec()

	while true:
		await bf.get_tree().process_frame
		var now: int = Time.get_ticks_msec()
		var elapsed: int = now - start_ms

		if elapsed >= total_ms:
			break

		var t: float = float(elapsed) / float(total_ms)
		cursor.position.x = t * float(bar_bg.size.x - cursor.size.x)

		if Input.is_action_just_pressed("ui_accept"):
			var c_center: float = cursor.position.x + (cursor.size.x * 0.5)
			var matched: bool = false
			
			for i in range(3):
				if vital_hit[i]: continue
				var v_start: float = vital_positions[i]
				var v_end: float = v_start + 16.0
				
				# Very strict tolerance (12 pixels on either side)
				if c_center >= v_start - 12.0 and c_center <= v_end + 12.0:
					vital_hit[i] = true
					hits += 1
					matched = true
					vitals[i].color = Color(1.0, 0.2, 0.2) # Turns blood red on hit!
					
					if bf.select_sound and bf.select_sound.stream:
						bf.select_sound.pitch_scale = 1.0 + float(hits) * 0.2
						bf.select_sound.play()
					bf.screen_shake(8.0, 0.1)
					break
					
			if not matched:
				if bf.miss_sound and bf.miss_sound.stream: bf.miss_sound.play()

	result = hits
	
	if result == 3:
		help.text = "LETHAL ASSASSINATION!"
		help.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		if bf.crit_sound and bf.crit_sound.stream: bf.crit_sound.play()
		bf.screen_shake(20.0, 0.3)
	elif result > 0:
		help.text = str(result) + " VITALS HIT"
		help.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	else:
		help.text = "FAILED"
		help.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 400:
		await bf.get_tree().process_frame

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result

# =========================================================
# THIEF QTE 3: ULTIMATE SHADOW STEP
# Rapid Reaction Sequence Minigame
# =========================================================
func run_ultimate_shadow_step_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker): return result

	bf.get_tree().paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 220
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.01, 0.01, 0.03, 0.90) # Almost completely dark
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "ULTIMATE SHADOW STEP"
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "PRESS THE ARROW AS SOON AS IT APPEARS!"
	help.position = Vector2(0, 130)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var arrow_label: Label = Label.new()
	arrow_label.text = ""
	arrow_label.position = Vector2(0, vp.y * 0.5 - 50)
	arrow_label.size = Vector2(vp.x, 100)
	arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow_label.add_theme_font_size_override("font_size", 80)
	arrow_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	arrow_label.add_theme_constant_override("outline_size", 10)
	arrow_label.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(arrow_label)

	var actions: Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right"]
	var arrows: Array[String] = ["UP ↑", "DOWN ↓", "LEFT ←", "RIGHT →"]

	Input.flush_buffered_events()
	var hits: int = 0
	
	for stage in range(4):
		var wait_ms: int = int(randf_range(300.0, 700.0))
		var wait_start: int = Time.get_ticks_msec()
		arrow_label.text = ""
		
		# Waiting in the dark...
		while Time.get_ticks_msec() - wait_start < wait_ms:
			await bf.get_tree().process_frame
			
		var target_idx: int = randi() % 4
		arrow_label.text = arrows[target_idx]
		
		if bf.select_sound and bf.select_sound.stream:
			bf.select_sound.pitch_scale = 1.0 + (stage * 0.1)
			bf.select_sound.play()
			
		var react_start: int = Time.get_ticks_msec()
		var react_window: int = 550 # Only half a second to press it!
		var pressed: bool = false
		
		while Time.get_ticks_msec() - react_start < react_window:
			await bf.get_tree().process_frame
			
			var pressed_idx: int = -1
			for i in range(4):
				if Input.is_action_just_pressed(actions[i]):
					pressed_idx = i
					break
					
			if pressed_idx != -1:
				pressed = true
				if pressed_idx == target_idx:
					hits += 1
					arrow_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
					bf.screen_shake(6.0, 0.1)
				else:
					arrow_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
					if bf.miss_sound and bf.miss_sound.stream: bf.miss_sound.play()
				break
				
		if not pressed:
			arrow_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
			if bf.miss_sound and bf.miss_sound.stream: bf.miss_sound.play()
			
		var show_result_start: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - show_result_start < 200:
			await bf.get_tree().process_frame
			
		arrow_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))

	if hits == 4:
		result = 2
		help.text = "PERFECT SHADOW STEP!"
		help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		if bf.crit_sound and bf.crit_sound.stream: bf.crit_sound.play()
		bf.screen_shake(16.0, 0.25)
	elif hits >= 2:
		result = 1
		help.text = "SUCCESSFUL STEP"
		help.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	else:
		result = 0
		help.text = "STUMBLED"
		help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 400:
		await bf.get_tree().process_frame

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result

# =========================================================
# WARRIOR QTE 1: POWER STRIKE
# Power Bar Minigame (Left to Right Sweep)
# =========================================================
func run_power_strike_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker): return result

	bf.get_tree().paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 220
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.1, 0.05, 0.01, 0.7)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "POWER STRIKE"
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.1))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "PRESS SPACE AT MAX POWER"
	help.position = Vector2(0, 130)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.size = Vector2(500, 30)
	bar_bg.position = Vector2((vp.x - 500) * 0.5, vp.y * 0.5 - 15)
	bar_bg.color = Color(0.1, 0.1, 0.1, 0.9)
	qte_layer.add_child(bar_bg)
	
	# Gradient style zone
	var ok_zone: ColorRect = ColorRect.new()
	ok_zone.size = Vector2(120, 30)
	ok_zone.position = Vector2(bar_bg.size.x - 160, 0)
	ok_zone.color = Color(1.0, 0.6, 0.2, 0.8)
	bar_bg.add_child(ok_zone)

	var perfect_zone: ColorRect = ColorRect.new()
	perfect_zone.size = Vector2(40, 30)
	perfect_zone.position = Vector2(bar_bg.size.x - 40, 0) # Dead end!
	perfect_zone.color = Color(1.0, 0.1, 0.1, 0.95)
	bar_bg.add_child(perfect_zone)

	var cursor: ColorRect = ColorRect.new()
	cursor.size = Vector2(8, 46)
	cursor.position = Vector2(0, -8)
	cursor.color = Color.WHITE
	bar_bg.add_child(cursor)

	Input.flush_buffered_events()

	var sweep_ms: int = 800
	var start_ms: int = Time.get_ticks_msec()
	var end_hold_ms: int = -1

	while true:
		await bf.get_tree().process_frame
		var now: int = Time.get_ticks_msec()

		if end_hold_ms > 0:
			if now >= end_hold_ms: break
			continue

		var elapsed: int = now - start_ms
		if elapsed >= sweep_ms:
			help.text = "SWUNG TOO WIDE!"
			help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			if bf.miss_sound and bf.miss_sound.stream: bf.miss_sound.play()
			end_hold_ms = now + 300
			continue

		var t: float = float(elapsed) / float(sweep_ms)
		cursor.position.x = t * float(bar_bg.size.x - cursor.size.x)

		if Input.is_action_just_pressed("ui_accept"):
			var c_center: float = cursor.position.x + (cursor.size.x * 0.5)
			var perfect_start: float = perfect_zone.position.x
			var ok_start: float = ok_zone.position.x

			if c_center >= perfect_start:
				result = 2
				help.text = "MAXIMUM POWER!"
				help.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
				if bf.crit_sound and bf.crit_sound.stream: bf.crit_sound.play()
				bf.screen_shake(18.0, 0.25)
			elif c_center >= ok_start:
				result = 1
				help.text = "HEAVY SWING"
				help.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
				if bf.select_sound and bf.select_sound.stream: 
					bf.select_sound.pitch_scale = 0.8
					bf.select_sound.play()
				bf.screen_shake(8.0, 0.15)
			else:
				result = 0
				help.text = "WEAK SWING"
				help.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
				if bf.miss_sound and bf.miss_sound.stream: bf.miss_sound.play()
				
			end_hold_ms = now + 300

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result

# =========================================================
# WARRIOR QTE 2: ADRENALINE RUSH
# Alternating Mash Minigame
# =========================================================
func run_adrenaline_rush_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker):
		return result

	var tree := bf.get_tree()
	var was_paused: bool = tree.paused
	var old_select_pitch: float = 1.0
	if bf.select_sound:
		old_select_pitch = bf.select_sound.pitch_scale

	tree.paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 220
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.12, 0.01, 0.01, 0.70)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "ADRENALINE RUSH"
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "ALTERNATE LEFT / RIGHT FAST TO PUMP BLOOD"
	help.position = Vector2(0, 130)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.size = Vector2(500, 30)
	bar_bg.position = Vector2((vp.x - 500) * 0.5, vp.y * 0.5 - 15)
	bar_bg.color = Color(0.1, 0.1, 0.1, 0.9)
	qte_layer.add_child(bar_bg)

	var fill: ColorRect = ColorRect.new()
	fill.size = Vector2(0, 30)
	fill.position = Vector2.ZERO
	fill.color = Color(1.0, 0.2, 0.2)
	bar_bg.add_child(fill)

	var threshold: ColorRect = ColorRect.new()
	threshold.size = Vector2(4, 30)
	threshold.position = Vector2(bar_bg.size.x * 0.85, 0)
	threshold.color = Color.WHITE
	bar_bg.add_child(threshold)

	Input.flush_buffered_events()

	var meter: float = 20.0
	var expect_left: bool = true
	var total_ms: int = 2000
	var start_ms: int = Time.get_ticks_msec()
	var last_ms: int = start_ms

	while true:
		await tree.process_frame
		var now: int = Time.get_ticks_msec()

		if now - start_ms >= total_ms:
			break

		var dt: float = float(now - last_ms) / 1000.0
		last_ms = now

		meter -= 35.0 * dt
		meter = clampf(meter, 0.0, 100.0)

		var left_pressed: bool = Input.is_action_just_pressed("ui_left")
		var right_pressed: bool = Input.is_action_just_pressed("ui_right")

		if left_pressed and right_pressed:
			meter -= 5.0
			if bf.miss_sound and bf.miss_sound.stream != null:
				bf.miss_sound.play()
		elif left_pressed:
			if expect_left:
				meter += 12.0
				expect_left = false
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 0.8 + (meter / 100.0)
					bf.select_sound.play()
			else:
				meter -= 5.0
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()
		elif right_pressed:
			if not expect_left:
				meter += 12.0
				expect_left = true
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 0.8 + (meter / 100.0)
					bf.select_sound.play()
			else:
				meter -= 5.0
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()

		meter = clampf(meter, 0.0, 100.0)
		fill.size.x = (meter / 100.0) * bar_bg.size.x
		fill.color = Color(1.0, float(100.0 - meter) / 100.0, float(100.0 - meter) / 100.0)

	if meter >= 85.0:
		result = 2
		help.text = "BLOOD BOILING!"
		help.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		if bf.crit_sound and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		bf.screen_shake(16.0, 0.3)
	elif meter >= 40.0:
		result = 1
		help.text = "HEART PUMPING"
		help.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
		bf.screen_shake(6.0, 0.15)
	else:
		result = 0
		help.text = "FAILED TO IGNITE"
		help.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 400:
		await tree.process_frame

	qte_layer.queue_free()
	tree.paused = was_paused
	if bf.select_sound:
		bf.select_sound.pitch_scale = old_select_pitch
	return result
	
# =========================================================
# WARRIOR QTE 3: EARTHSHATTER
# Hold and Release Shrinking Circle Minigame
# =========================================================
func run_earthshatter_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker): return result

	bf.get_tree().paused = true

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 220
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.15, 0.05, 0.0, 0.7) # Earthy orange
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "EARTHSHATTER"
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "HOLD SPACE TO CHARGE, RELEASE IN THE RING"
	help.position = Vector2(0, 130)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var center: Vector2 = vp * 0.5 + Vector2(0, 30)
	
	var target_ring: Panel = Panel.new()
	target_ring.size = Vector2(240, 240)
	target_ring.position = center - target_ring.size * 0.5
	var target_style: StyleBoxFlat = StyleBoxFlat.new()
	target_style.bg_color = Color(0, 0, 0, 0)
	target_style.border_width_left = 6
	target_style.border_width_top = 6
	target_style.border_width_right = 6
	target_style.border_width_bottom = 6
	target_style.border_color = Color(1.0, 0.6, 0.2, 0.8)
	target_style.corner_radius_top_left = 120
	target_style.corner_radius_top_right = 120
	target_style.corner_radius_bottom_left = 120
	target_style.corner_radius_bottom_right = 120
	target_ring.add_theme_stylebox_override("panel", target_style)
	qte_layer.add_child(target_ring)

	var core: ColorRect = ColorRect.new()
	core.size = Vector2(40, 40)
	core.position = center - core.size * 0.5
	core.color = Color(1.0, 0.9, 0.5, 1.0)
	qte_layer.add_child(core)

	Input.flush_buffered_events()

	var charging: bool = false
	var start_ms: int = 0
	var max_time_ms: int = 1600
	var end_hold_ms: int = -1
	var waited_too_long_ms: int = Time.get_ticks_msec()

	while true:
		await bf.get_tree().process_frame
		var now: int = Time.get_ticks_msec()

		if end_hold_ms > 0:
			if now >= end_hold_ms: break
			continue

		if not charging:
			if now - waited_too_long_ms > 2000:
				help.text = "TOO SLOW"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				if bf.miss_sound and bf.miss_sound.stream: bf.miss_sound.play()
				end_hold_ms = now + 400
				continue

			if Input.is_action_just_pressed("ui_accept"):
				charging = true
				start_ms = now
		else:
			var elapsed: int = now - start_ms
			var progress: float = clampf(float(elapsed) / float(max_time_ms), 0.0, 1.0)
			
			# Core grows visually to match ring
			var current_size: float = lerpf(40.0, 300.0, progress)
			core.size = Vector2(current_size, current_size)
			core.position = center - core.size * 0.5
			
			if Input.is_action_just_released("ui_accept"):
				var diff: float = abs(current_size - 240.0)
				
				if diff <= 15.0:
					result = 2
					help.text = "PERFECT SHATTER!"
					help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
					target_style.border_color = Color.WHITE
					core.color = Color.WHITE
					if bf.crit_sound and bf.crit_sound.stream: bf.crit_sound.play()
					bf.screen_shake(20.0, 0.35)
				elif diff <= 45.0:
					result = 1
					help.text = "HEAVY IMPACT"
					help.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
					if bf.select_sound and bf.select_sound.stream: 
						bf.select_sound.pitch_scale = 0.7
						bf.select_sound.play()
					bf.screen_shake(10.0, 0.2)
				else:
					result = 0
					help.text = "WEAK IMPACT"
					help.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
					if bf.miss_sound and bf.miss_sound.stream: bf.miss_sound.play()
					
				end_hold_ms = now + 400

			elif progress >= 1.0:
				result = 0
				help.text = "OVERCHARGED"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				if bf.miss_sound and bf.miss_sound.stream: bf.miss_sound.play()
				end_hold_ms = now + 400

	qte_layer.queue_free()
	bf.get_tree().paused = false
	return result

# =========================================================
# ASSASSIN QTE: SHADOW PIN
# Crosshair tracking minigame
# Returns: 2 = perfect pin, 1 = glancing pin, 0 = miss
# =========================================================
func run_shadow_pin_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker):
		return result

	var state: Dictionary = self._begin_qte(bf)

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 230
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var tree: SceneTree = bf.get_tree()
	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.02, 0.02, 0.05, 0.82)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "SHADOW PIN"
	title.position = Vector2(0, 60)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.75, 0.55, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "TRACK THE DOT WITH ARROWS — PRESS SPACE ON TARGET"
	help.position = Vector2(0, 105)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var arena: ColorRect = ColorRect.new()
	arena.size = Vector2(560, 320)
	arena.position = Vector2((vp.x - arena.size.x) * 0.5, (vp.y - arena.size.y) * 0.5 - 10.0)
	arena.color = Color(0.06, 0.06, 0.10, 0.95)
	qte_layer.add_child(arena)

	var target: ColorRect = ColorRect.new()
	target.size = Vector2(18, 18)
	target.color = Color(1.0, 0.2, 0.2, 1.0)
	arena.add_child(target)

	var cursor_h: ColorRect = ColorRect.new()
	cursor_h.size = Vector2(34, 4)
	cursor_h.color = Color.WHITE
	arena.add_child(cursor_h)

	var cursor_v: ColorRect = ColorRect.new()
	cursor_v.size = Vector2(4, 34)
	cursor_v.color = Color.WHITE
	arena.add_child(cursor_v)

	var status: Label = Label.new()
	status.text = "TIME: 2.60"
	status.position = Vector2(0, arena.position.y + arena.size.y + 18.0)
	status.size = Vector2(vp.x, 30)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 22)
	status.add_theme_color_override("font_color", Color.WHITE)
	status.add_theme_constant_override("outline_size", 5)
	status.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(status)

	Input.flush_buffered_events()

	var cursor_pos: Vector2 = arena.size * 0.5
	var cursor_speed: float = 280.0

	var target_pos: Vector2 = Vector2(
		randf_range(40.0, arena.size.x - 40.0),
		randf_range(40.0, arena.size.y - 40.0)
	)
	var target_vel: Vector2 = Vector2(
		randf_range(-180.0, 180.0),
		randf_range(-180.0, 180.0)
	)
	var retarget_ms: int = Time.get_ticks_msec() + 420

	var total_ms: int = 2600
	var start_ms: int = Time.get_ticks_msec()
	var last_ms: int = start_ms
	var resolved: bool = false

	while true:
		await tree.process_frame

		var now: int = Time.get_ticks_msec()
		var elapsed_ms: int = now - start_ms
		if elapsed_ms >= total_ms:
			break

		var dt: float = float(now - last_ms) / 1000.0
		last_ms = now

		var move_dir: Vector2 = Vector2.ZERO
		if Input.is_action_pressed("ui_left"):
			move_dir.x -= 1.0
		if Input.is_action_pressed("ui_right"):
			move_dir.x += 1.0
		if Input.is_action_pressed("ui_up"):
			move_dir.y -= 1.0
		if Input.is_action_pressed("ui_down"):
			move_dir.y += 1.0

		if move_dir.length() > 0.0:
			move_dir = move_dir.normalized()

		cursor_pos += move_dir * cursor_speed * dt
		cursor_pos.x = clampf(cursor_pos.x, 12.0, arena.size.x - 12.0)
		cursor_pos.y = clampf(cursor_pos.y, 12.0, arena.size.y - 12.0)

		if now >= retarget_ms:
			target_vel = target_vel.normalized() * randf_range(140.0, 230.0)
			target_vel = target_vel.rotated(randf_range(-0.75, 0.75))
			retarget_ms = now + int(randf_range(280.0, 520.0))

		target_pos += target_vel * dt

		if target_pos.x <= 9.0 or target_pos.x >= arena.size.x - 9.0:
			target_vel.x *= -1.0
			target_pos.x = clampf(target_pos.x, 9.0, arena.size.x - 9.0)
		if target_pos.y <= 9.0 or target_pos.y >= arena.size.y - 9.0:
			target_vel.y *= -1.0
			target_pos.y = clampf(target_pos.y, 9.0, arena.size.y - 9.0)

		target.position = target_pos - target.size * 0.5
		cursor_h.position = Vector2(cursor_pos.x - cursor_h.size.x * 0.5, cursor_pos.y - cursor_h.size.y * 0.5)
		cursor_v.position = Vector2(cursor_pos.x - cursor_v.size.x * 0.5, cursor_pos.y - cursor_v.size.y * 0.5)

		var remaining_sec: float = maxf(0.0, float(total_ms - elapsed_ms) / 1000.0)
		status.text = "TIME: %0.2f" % remaining_sec

		if Input.is_action_just_pressed("ui_accept"):
			var dist: float = cursor_pos.distance_to(target_pos)

			if dist <= 12.0:
				result = 2
				help.text = "PERFECT PIN"
				help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
				target.color = Color.WHITE
				cursor_h.color = Color.WHITE
				cursor_v.color = Color.WHITE
				if bf.crit_sound and bf.crit_sound.stream != null:
					bf.crit_sound.play()
				bf.screen_shake(14.0, 0.20)
			elif dist <= 28.0:
				result = 1
				help.text = "GLANCING PIN"
				help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
				target.color = Color(0.35, 1.0, 0.35)
				cursor_h.color = Color(0.35, 1.0, 0.35)
				cursor_v.color = Color(0.35, 1.0, 0.35)
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.18
					bf.select_sound.play()
				bf.screen_shake(7.0, 0.10)
			else:
				result = 0
				help.text = "MISS"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				target.color = Color(1.0, 0.3, 0.3)
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()

			resolved = true
			break

	if not resolved:
		result = 0
		help.text = "TOO SLOW"
		help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 360:
		await tree.process_frame

	self._end_qte(bf, qte_layer, state)
	return result


# =========================================================
# GENERAL QTE: WEAPON SHATTER
# Collision timing minigame
# Returns: 2 = shatter, 0 = fail
# =========================================================
func run_weapon_shatter_minigame(bf: Node2D, defender: Node2D) -> int:
	var result: int = 0
	if defender == null or not is_instance_valid(defender):
		return result

	var state: Dictionary = self._begin_qte(bf)

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 230
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var tree: SceneTree = bf.get_tree()
	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.05, 0.06, 0.08, 0.86)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "WEAPON SHATTER"
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "PRESS SPACE EXACTLY ON IMPACT"
	help.position = Vector2(0, 125)
	title.size = Vector2(vp.x, 42)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var track: ColorRect = ColorRect.new()
	track.size = Vector2(620, 120)
	track.position = Vector2((vp.x - track.size.x) * 0.5, (vp.y - track.size.y) * 0.5 - 10.0)
	track.color = Color(0.10, 0.10, 0.10, 0.96)
	qte_layer.add_child(track)

	var center_line: ColorRect = ColorRect.new()
	center_line.size = Vector2(6, track.size.y)
	center_line.position = Vector2((track.size.x - center_line.size.x) * 0.5, 0.0)
	center_line.color = Color.WHITE
	track.add_child(center_line)

	var left_block: ColorRect = ColorRect.new()
	left_block.size = Vector2(110, 120)
	left_block.position = Vector2(-left_block.size.x, 0.0)
	left_block.color = Color(0.55, 0.60, 0.68, 1.0)
	track.add_child(left_block)

	var right_block: ColorRect = ColorRect.new()
	right_block.size = Vector2(110, 120)
	right_block.position = Vector2(track.size.x, 0.0)
	right_block.color = Color(0.55, 0.60, 0.68, 1.0)
	track.add_child(right_block)

	Input.flush_buffered_events()

	var total_ms: int = 900
	var start_ms: int = Time.get_ticks_msec()
	var resolved: bool = false

	while true:
		await tree.process_frame

		var now: int = Time.get_ticks_msec()
		var elapsed_ms: int = now - start_ms
		if elapsed_ms >= total_ms:
			break

		var t: float = float(elapsed_ms) / float(total_ms)
		var left_x: float = lerpf(-left_block.size.x, (track.size.x * 0.5) - left_block.size.x, t)
		var right_x: float = lerpf(track.size.x, track.size.x * 0.5, t)

		left_block.position.x = left_x
		right_block.position.x = right_x

		if Input.is_action_just_pressed("ui_accept"):
			var impact_gap: float = abs((left_block.position.x + left_block.size.x) - right_block.position.x)

			if impact_gap <= 10.0:
				result = 2
				help.text = "SHATTERED"
				help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
				left_block.color = Color.WHITE
				right_block.color = Color.WHITE
				if bf.crit_sound and bf.crit_sound.stream != null:
					bf.crit_sound.play()
				bf.screen_shake(18.0, 0.24)
			else:
				result = 0
				help.text = "FAILED"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()

			resolved = true
			break

	if not resolved:
		result = 0
		help.text = "MISSED THE CLASH"
		help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 340:
		await tree.process_frame

	self._end_qte(bf, qte_layer, state)
	return result


# =========================================================
# BERSERKER QTE: SAVAGE TOSS
# Fast golf-swing arc meter
# Returns: 3 = max distance, 2 = strong, 1 = light, 0 = fail
# =========================================================
func run_savage_toss_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker):
		return result

	var state: Dictionary = self._begin_qte(bf)

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 230
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var tree: SceneTree = bf.get_tree()
	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.14, 0.03, 0.02, 0.84)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "SAVAGE TOSS"
	title.position = Vector2(0, 70)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.25))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "STOP THE NEEDLE IN THE TINY TOP SWEET SPOT"
	help.position = Vector2(0, 115)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var dial: Panel = Panel.new()
	dial.size = Vector2(340, 340)
	dial.position = Vector2((vp.x - dial.size.x) * 0.5, (vp.y - dial.size.y) * 0.5 - 10.0)

	var dial_style: StyleBoxFlat = StyleBoxFlat.new()
	dial_style.bg_color = Color(0.08, 0.08, 0.08, 0.96)
	dial_style.border_width_left = 4
	dial_style.border_width_top = 4
	dial_style.border_width_right = 4
	dial_style.border_width_bottom = 4
	dial_style.border_color = Color(0.70, 0.70, 0.75, 0.85)
	dial_style.corner_radius_top_left = 180
	dial_style.corner_radius_top_right = 180
	dial_style.corner_radius_bottom_left = 180
	dial_style.corner_radius_bottom_right = 180
	dial.add_theme_stylebox_override("panel", dial_style)
	qte_layer.add_child(dial)

	var pivot: ColorRect = ColorRect.new()
	pivot.size = Vector2(12, 12)
	pivot.position = dial.size * 0.5 - Vector2(6, 6)
	pivot.color = Color.WHITE
	dial.add_child(pivot)

	var sweet_dot: ColorRect = ColorRect.new()
	sweet_dot.size = Vector2(22, 22)
	sweet_dot.position = Vector2(dial.size.x * 0.5 - 11.0, 18.0)
	sweet_dot.color = Color(1.0, 0.85, 0.2, 1.0)
	dial.add_child(sweet_dot)

	var needle: ColorRect = ColorRect.new()
	needle.size = Vector2(8, 132)
	needle.position = dial.size * 0.5 - Vector2(4, 118)
	needle.pivot_offset = Vector2(4, 118)
	needle.color = Color(1.0, 0.72, 0.28, 1.0)
	dial.add_child(needle)

	Input.flush_buffered_events()

	var total_ms: int = 1800
	var start_ms: int = Time.get_ticks_msec()
	var resolved: bool = false

	while true:
		await tree.process_frame

		var now: int = Time.get_ticks_msec()
		var elapsed_ms: int = now - start_ms
		if elapsed_ms >= total_ms:
			break

		var t: float = float(elapsed_ms) / 1000.0
		var current_angle: float = sin(t * 12.5) * 82.0
		needle.rotation_degrees = current_angle

		if Input.is_action_just_pressed("ui_accept"):
			var diff: float = abs(current_angle)

			if diff <= 4.0:
				result = 3
				help.text = "MAX TOSS"
				help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
				needle.color = Color.WHITE
				sweet_dot.color = Color.WHITE
				if bf.crit_sound and bf.crit_sound.stream != null:
					bf.crit_sound.play()
				bf.screen_shake(18.0, 0.26)
			elif diff <= 10.0:
				result = 2
				help.text = "HEAVY TOSS"
				help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
				needle.color = Color(0.35, 1.0, 0.35)
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.18
					bf.select_sound.play()
				bf.screen_shake(10.0, 0.14)
			elif diff <= 18.0:
				result = 1
				help.text = "LIGHT TOSS"
				help.add_theme_color_override("font_color", Color(1.0, 0.70, 0.30))
				needle.color = Color(1.0, 0.70, 0.30)
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.08
					bf.select_sound.play()
				bf.screen_shake(6.0, 0.08)
			else:
				result = 0
				help.text = "WHIFFED"
				help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()

			resolved = true
			break

	if not resolved:
		result = 0
		help.text = "TOO SLOW"
		help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 360:
		await tree.process_frame

	self._end_qte(bf, qte_layer, state)
	return result


# =========================================================
# HERO QTE: VANGUARD'S RALLY
# Fighting-game combo rush
# Returns: total successful 4-button combos completed
# =========================================================
func run_vanguards_rally_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker):
		return result

	var state: Dictionary = self._begin_qte(bf)

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 230
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var tree: SceneTree = bf.get_tree()
	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.06, 0.08, 0.12, 0.84)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "VANGUARD'S RALLY"
	title.position = Vector2(0, 60)
	title.size = Vector2(vp.x, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "COMPLETE AS MANY 4-BUTTON COMBOS AS POSSIBLE"
	help.position = Vector2(0, 105)
	help.size = Vector2(vp.x, 30)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var panel: ColorRect = ColorRect.new()
	panel.size = Vector2(760, 230)
	panel.position = Vector2((vp.x - panel.size.x) * 0.5, (vp.y - panel.size.y) * 0.5 - 10.0)
	panel.color = Color(0.08, 0.08, 0.08, 0.96)
	qte_layer.add_child(panel)

	var combo_labels: Array[Label] = []
	for i in range(4):
		var lbl: Label = Label.new()
		lbl.position = Vector2(30.0 + float(i) * 180.0, 50.0)
		lbl.size = Vector2(160, 60)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 34)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		panel.add_child(lbl)
		combo_labels.append(lbl)

	var progress_label: Label = Label.new()
	progress_label.text = "COMBOS: 0"
	progress_label.position = Vector2(0, 132)
	progress_label.size = Vector2(panel.size.x, 36)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 28)
	progress_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
	progress_label.add_theme_constant_override("outline_size", 6)
	progress_label.add_theme_color_override("font_outline_color", Color.BLACK)
	panel.add_child(progress_label)

	var timer_label: Label = Label.new()
	timer_label.text = "3.00"
	timer_label.position = Vector2(0, 172)
	timer_label.size = Vector2(panel.size.x, 36)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 30)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.add_theme_constant_override("outline_size", 6)
	timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	panel.add_child(timer_label)

	var action_names: Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept"]
	var display_names: Array[String] = ["UP", "DOWN", "LEFT", "RIGHT", "SPACE"]

	Input.flush_buffered_events()

	var combo_sequence: Array[int] = []
	var current_index_ref: Array = [0]
	var combo_count: int = 0
	var total_ms: int = 3000
	var start_ms: int = Time.get_ticks_msec()

	var _reroll_combo: Callable = func() -> void:
		combo_sequence.clear()
		for j in range(4):
			combo_sequence.append(randi() % action_names.size())
		current_index_ref[0] = 0
		for j in range(4):
			combo_labels[j].text = display_names[combo_sequence[j]]
			combo_labels[j].add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))

	_reroll_combo.call()

	while true:
		await tree.process_frame

		var now: int = Time.get_ticks_msec()
		var elapsed_ms: int = now - start_ms
		if elapsed_ms >= total_ms:
			break

		var remaining_sec: float = maxf(0.0, float(total_ms - elapsed_ms) / 1000.0)
		timer_label.text = "%0.2f" % remaining_sec
		progress_label.text = "COMBOS: " + str(combo_count)

		var pressed_index: int = -1
		for i in range(action_names.size()):
			if Input.is_action_just_pressed(action_names[i]):
				pressed_index = i
				break

		if pressed_index == -1:
			continue

		if pressed_index == combo_sequence[current_index_ref[0]]:
			combo_labels[current_index_ref[0]].add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
			current_index_ref[0] += 1

			if bf.select_sound and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.05 + (float(current_index_ref[0]) * 0.08)
				bf.select_sound.play()

			if current_index_ref[0] >= 4:
				combo_count += 1
				progress_label.text = "COMBOS: " + str(combo_count)
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.35
					bf.select_sound.play()
				_reroll_combo.call()
		else:
			if bf.miss_sound and bf.miss_sound.stream != null:
				bf.miss_sound.play()
			_reroll_combo.call()

	result = combo_count

	if result >= 4:
		help.text = "LEGENDARY RALLY"
		help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		if bf.crit_sound and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		bf.screen_shake(14.0, 0.18)
	elif result >= 2:
		help.text = "STRONG RALLY"
		help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		if bf.select_sound and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.18
			bf.select_sound.play()
		bf.screen_shake(7.0, 0.10)
	elif result >= 1:
		help.text = "RALLY"
		help.add_theme_color_override("font_color", Color(1.0, 0.80, 0.35))
		if bf.select_sound and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.08
			bf.select_sound.play()
	else:
		help.text = "NO MOMENTUM"
		help.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 380:
		await tree.process_frame

	self._end_qte(bf, qte_layer, state)
	return result

# =========================================================
# BLADE MASTER QTE: SEVERING STRIKE
# 3 sequential target circles. Press Space while cursor is inside.
# Returns: number of successful hits (0 to 3)
# =========================================================
func run_severing_strike_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker):
		return result

	var state: Dictionary = _begin_qte(bf)

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 230
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var tree: SceneTree = bf.get_tree()
	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.03, 0.02, 0.06, 0.84)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "SEVERING STRIKE"
	title.position = Vector2(0.0, 60.0)
	title.size = Vector2(vp.x, 42.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "PRESS SPACE WHEN THE CURSOR ENTERS THE TARGET"
	help.position = Vector2(0.0, 105.0)
	help.size = Vector2(vp.x, 30.0)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var arena: ColorRect = ColorRect.new()
	arena.size = Vector2(640.0, 340.0)
	arena.position = Vector2((vp.x - arena.size.x) * 0.5, (vp.y - arena.size.y) * 0.5 - 8.0)
	arena.color = Color(0.08, 0.08, 0.10, 0.96)
	qte_layer.add_child(arena)

	var round_label: Label = Label.new()
	round_label.position = Vector2(0.0, arena.position.y + arena.size.y + 16.0)
	round_label.size = Vector2(vp.x, 28.0)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.add_theme_font_size_override("font_size", 24)
	round_label.add_theme_color_override("font_color", Color.WHITE)
	round_label.add_theme_constant_override("outline_size", 5)
	round_label.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(round_label)

	var target_ring: Panel = Panel.new()
	target_ring.size = Vector2(68.0, 68.0)
	var target_style: StyleBoxFlat = StyleBoxFlat.new()
	target_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	target_style.border_width_left = 5
	target_style.border_width_top = 5
	target_style.border_width_right = 5
	target_style.border_width_bottom = 5
	target_style.border_color = Color(1.0, 0.85, 0.2, 1.0)
	target_style.corner_radius_top_left = 40
	target_style.corner_radius_top_right = 40
	target_style.corner_radius_bottom_left = 40
	target_style.corner_radius_bottom_right = 40
	target_ring.add_theme_stylebox_override("panel", target_style)
	arena.add_child(target_ring)

	var cursor: ColorRect = ColorRect.new()
	cursor.size = Vector2(14.0, 14.0)
	cursor.color = Color.WHITE
	arena.add_child(cursor)

	Input.flush_buffered_events()

	var target_radius: float = 34.0

	for round_index: int in range(3):
		round_label.text = "HITS: " + str(result) + " / 3   |   TARGET " + str(round_index + 1)

		var target_center: Vector2 = Vector2(
			randf_range(90.0, arena.size.x - 90.0),
			randf_range(80.0, arena.size.y - 80.0)
		)
		target_ring.position = target_center - (target_ring.size * 0.5)
		target_style.border_color = Color(1.0, 0.85, 0.2, 1.0)

		var edge_pick: int = randi() % 4
		var start_pos: Vector2 = Vector2.ZERO
		if edge_pick == 0:
			start_pos = Vector2(-30.0, randf_range(30.0, arena.size.y - 30.0))
		elif edge_pick == 1:
			start_pos = Vector2(arena.size.x + 30.0, randf_range(30.0, arena.size.y - 30.0))
		elif edge_pick == 2:
			start_pos = Vector2(randf_range(30.0, arena.size.x - 30.0), -30.0)
		else:
			start_pos = Vector2(randf_range(30.0, arena.size.x - 30.0), arena.size.y + 30.0)

		var end_pos: Vector2 = target_center
		var phase_ms: int = 720
		var phase_start_ms: int = Time.get_ticks_msec()
		var pressed: bool = false
		var hit_this_round: bool = false

		while true:
			await tree.process_frame

			var now: int = Time.get_ticks_msec()
			var elapsed_ms: int = now - phase_start_ms
			if elapsed_ms >= phase_ms:
				break

			var t: float = clampf(float(elapsed_ms) / float(phase_ms), 0.0, 1.0)
			var cursor_pos: Vector2 = start_pos.lerp(end_pos, t)
			cursor.position = cursor_pos - (cursor.size * 0.5)

			if Input.is_action_just_pressed("ui_accept"):
				pressed = true
				var dist: float = cursor_pos.distance_to(target_center)
				if dist <= target_radius - 4.0:
					hit_this_round = true
					result += 1
					target_style.border_color = Color(0.35, 1.0, 0.35, 1.0)
					cursor.color = Color(0.35, 1.0, 0.35, 1.0)
					if bf.select_sound and bf.select_sound.stream != null:
						bf.select_sound.pitch_scale = 1.10 + (float(result) * 0.08)
						bf.select_sound.play()
					bf.screen_shake(6.0, 0.08)
				else:
					hit_this_round = false
					target_style.border_color = Color(1.0, 0.30, 0.30, 1.0)
					cursor.color = Color(1.0, 0.30, 0.30, 1.0)
					if bf.miss_sound and bf.miss_sound.stream != null:
						bf.miss_sound.play()
				break

		if not pressed:
			target_style.border_color = Color(1.0, 0.30, 0.30, 1.0)
			cursor.color = Color(1.0, 0.30, 0.30, 1.0)
			if bf.miss_sound and bf.miss_sound.stream != null:
				bf.miss_sound.play()

		if hit_this_round:
			help.text = "SLASH CONNECTED"
			help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		else:
			help.text = "MISSED THE WINDOW"
			help.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))

		var hold_ms: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - hold_ms < 180:
			await tree.process_frame

		cursor.color = Color.WHITE

	if result >= 3:
		help.text = "PERFECT SEVERING"
		help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		if bf.crit_sound and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		bf.screen_shake(12.0, 0.18)
	elif result >= 1:
		help.text = str(result) + " CLEAN HIT(S)"
		help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
	else:
		help.text = "NO OPENING FOUND"
		help.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))

	var finish_hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - finish_hold_start < 320:
		await tree.process_frame

	_end_qte(bf, qte_layer, state)
	return result


# =========================================================
# BLADE WEAVER QTE: AETHER BIND
# Catch falling sparks over 3 seconds.
# Returns: number of caught sparks (0 to 5)
# =========================================================
func run_aether_bind_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker):
		return result

	var state: Dictionary = _begin_qte(bf)

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 230
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var tree: SceneTree = bf.get_tree()
	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.04, 0.03, 0.09, 0.84)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "AETHER BIND"
	title.position = Vector2(0.0, 60.0)
	title.size = Vector2(vp.x, 42.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.75, 0.55, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "MOVE LEFT / RIGHT TO CATCH THE FALLING SPARKS"
	help.position = Vector2(0.0, 105.0)
	help.size = Vector2(vp.x, 30.0)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var arena: ColorRect = ColorRect.new()
	arena.size = Vector2(560.0, 340.0)
	arena.position = Vector2((vp.x - arena.size.x) * 0.5, (vp.y - arena.size.y) * 0.5 - 10.0)
	arena.color = Color(0.08, 0.08, 0.12, 0.96)
	qte_layer.add_child(arena)

	var paddle: ColorRect = ColorRect.new()
	paddle.size = Vector2(96.0, 18.0)
	paddle.position = Vector2((arena.size.x - paddle.size.x) * 0.5, arena.size.y - 30.0)
	paddle.color = Color.WHITE
	arena.add_child(paddle)

	var timer_label: Label = Label.new()
	timer_label.position = Vector2(0.0, arena.position.y + arena.size.y + 16.0)
	timer_label.size = Vector2(vp.x, 28.0)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 24)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.add_theme_constant_override("outline_size", 5)
	timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(timer_label)

	var spark_nodes: Array[ColorRect] = []
	var spark_xs: Array[float] = []
	var spark_speeds: Array[float] = []
	var spark_delays_ms: Array[int] = []
	var spark_caught: Array[bool] = []
	var spark_resolved: Array[bool] = []

	for i: int in range(5):
		var spark: ColorRect = ColorRect.new()
		spark.size = Vector2(16.0, 16.0)
		spark.color = Color(1.0, 0.85, 0.2, 1.0)
		spark.visible = false
		arena.add_child(spark)

		spark_nodes.append(spark)
		spark_xs.append(randf_range(20.0, arena.size.x - 36.0))
		spark_speeds.append(randf_range(170.0, 240.0))
		spark_delays_ms.append(180 + (i * 520))
		spark_caught.append(false)
		spark_resolved.append(false)

	Input.flush_buffered_events()

	var paddle_speed: float = 420.0
	var total_ms: int = 3000
	var start_ms: int = Time.get_ticks_msec()
	var last_ms: int = start_ms

	while true:
		await tree.process_frame

		var now: int = Time.get_ticks_msec()
		var elapsed_ms: int = now - start_ms
		if elapsed_ms >= total_ms:
			break

		var dt: float = float(now - last_ms) / 1000.0
		last_ms = now

		var move_x: float = 0.0
		if Input.is_action_pressed("ui_left"):
			move_x -= 1.0
		if Input.is_action_pressed("ui_right"):
			move_x += 1.0

		paddle.position.x += move_x * paddle_speed * dt
		paddle.position.x = clampf(paddle.position.x, 0.0, arena.size.x - paddle.size.x)

		for i: int in range(5):
			if spark_resolved[i]:
				continue
			if elapsed_ms < spark_delays_ms[i]:
				continue

			var spark: ColorRect = spark_nodes[i]
			var fall_time_ms: int = elapsed_ms - spark_delays_ms[i]
			var y_pos: float = -18.0 + (spark_speeds[i] * (float(fall_time_ms) / 1000.0))

			spark.visible = true
			spark.position = Vector2(spark_xs[i], y_pos)

			var spark_rect: Rect2 = Rect2(spark.position, spark.size)
			var paddle_rect: Rect2 = Rect2(paddle.position, paddle.size)

			if spark_rect.intersects(paddle_rect):
				spark_caught[i] = true
				spark_resolved[i] = true
				spark.visible = false
				result += 1
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.06 + (float(result) * 0.06)
					bf.select_sound.play()
			elif spark.position.y > arena.size.y + 20.0:
				spark_resolved[i] = true
				spark.visible = false
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()

		var remaining_sec: float = maxf(0.0, float(total_ms - elapsed_ms) / 1000.0)
		timer_label.text = "CAUGHT: " + str(result) + " / 5   |   TIME: %0.2f" % remaining_sec

	if result >= 5:
		help.text = "PERFECT BIND"
		help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		if bf.crit_sound and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		bf.screen_shake(12.0, 0.18)
	elif result >= 2:
		help.text = "SPARKS GATHERED"
		help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		if bf.select_sound and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.16
			bf.select_sound.play()
	else:
		help.text = "AETHER SLIPPED AWAY"
		help.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 340:
		await tree.process_frame

	_end_qte(bf, qte_layer, state)
	return result


# =========================================================
# BOW KNIGHT QTE: PARTING SHOT
# Phase 1: shrinking ring timing
# Phase 2: immediate arrow reaction if phase 1 succeeds
# Returns: 2 = perfect shot + correct arrow, 1 = shot only, 0 = fail
# =========================================================
func run_parting_shot_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker):
		return result

	var state: Dictionary = _begin_qte(bf)

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 230
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var tree: SceneTree = bf.get_tree()
	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.02, 0.04, 0.08, 0.84)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "PARTING SHOT"
	title.position = Vector2(0.0, 68.0)
	title.size = Vector2(vp.x, 42.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "PRESS SPACE WHEN THE RINGS ALIGN"
	help.position = Vector2(0.0, 112.0)
	help.size = Vector2(vp.x, 30.0)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var center: Vector2 = vp * 0.5 + Vector2(0.0, 25.0)

	var inner_ring: Panel = Panel.new()
	inner_ring.size = Vector2(92.0, 92.0)
	inner_ring.position = center - (inner_ring.size * 0.5)
	var inner_style: StyleBoxFlat = StyleBoxFlat.new()
	inner_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	inner_style.border_width_left = 6
	inner_style.border_width_top = 6
	inner_style.border_width_right = 6
	inner_style.border_width_bottom = 6
	inner_style.border_color = Color(1.0, 0.85, 0.2, 1.0)
	inner_style.corner_radius_top_left = 60
	inner_style.corner_radius_top_right = 60
	inner_style.corner_radius_bottom_left = 60
	inner_style.corner_radius_bottom_right = 60
	inner_ring.add_theme_stylebox_override("panel", inner_style)
	qte_layer.add_child(inner_ring)

	var outer_ring: Panel = Panel.new()
	outer_ring.size = Vector2(240.0, 240.0)
	outer_ring.position = center - (outer_ring.size * 0.5)
	var outer_style: StyleBoxFlat = StyleBoxFlat.new()
	outer_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	outer_style.border_width_left = 7
	outer_style.border_width_top = 7
	outer_style.border_width_right = 7
	outer_style.border_width_bottom = 7
	outer_style.border_color = Color(0.70, 0.92, 1.0, 1.0)
	outer_style.corner_radius_top_left = 140
	outer_style.corner_radius_top_right = 140
	outer_style.corner_radius_bottom_left = 140
	outer_style.corner_radius_bottom_right = 140
	outer_ring.add_theme_stylebox_override("panel", outer_style)
	qte_layer.add_child(outer_ring)

	Input.flush_buffered_events()

	var phase_one_success: bool = false
	var _phase_one_perfect: bool = false
	var total_ms: int = 950
	var start_ms: int = Time.get_ticks_msec()
	var phase_one_resolved: bool = false

	while true:
		await tree.process_frame

		var now: int = Time.get_ticks_msec()
		var elapsed_ms: int = now - start_ms
		if elapsed_ms >= total_ms:
			break

		var t: float = float(elapsed_ms) / float(total_ms)
		var current_size: float = lerpf(240.0, 72.0, t)
		outer_ring.size = Vector2(current_size, current_size)
		outer_ring.position = center - (outer_ring.size * 0.5)

		if Input.is_action_just_pressed("ui_accept"):
			phase_one_resolved = true
			var diff: float = abs(outer_ring.size.x - inner_ring.size.x)
			if diff <= 10.0:
				phase_one_success = true
				_phase_one_perfect = true
				help.text = "SHOT LANDED — REACT!"
				help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
				outer_style.border_color = Color.WHITE
				inner_style.border_color = Color.WHITE
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.24
					bf.select_sound.play()
			elif diff <= 24.0:
				phase_one_success = true
				_phase_one_perfect = false
				help.text = "SHOT LANDED — REACT!"
				help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
				outer_style.border_color = Color(0.35, 1.0, 0.35, 1.0)
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.14
					bf.select_sound.play()
			else:
				phase_one_success = false
				_phase_one_perfect = false
				help.text = "SHOT MISSED"
				help.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()
			break

	if not phase_one_resolved:
		phase_one_success = false
		help.text = "TOO LATE"
		help.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

	if not phase_one_success:
		result = 0
	else:
		result = 1

		var arrow_label: Label = Label.new()
		arrow_label.position = Vector2(0.0, center.y + 130.0)
		arrow_label.size = Vector2(vp.x, 90.0)
		arrow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		arrow_label.add_theme_font_size_override("font_size", 68)
		arrow_label.add_theme_color_override("font_color", Color.WHITE)
		arrow_label.add_theme_constant_override("outline_size", 8)
		arrow_label.add_theme_color_override("font_outline_color", Color.BLACK)
		qte_layer.add_child(arrow_label)

		var action_names: Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right"]
		var display_names: Array[String] = ["UP ↑", "DOWN ↓", "LEFT ←", "RIGHT →"]
		var target_index: int = randi() % 4

		arrow_label.text = display_names[target_index]
		Input.flush_buffered_events()

		var react_start_ms: int = Time.get_ticks_msec()
		var react_window_ms: int = 500
		var reaction_done: bool = false

		while true:
			await tree.process_frame

			var now_react: int = Time.get_ticks_msec()
			if now_react - react_start_ms >= react_window_ms:
				break

			var pressed_index: int = -1
			for i: int in range(action_names.size()):
				if Input.is_action_just_pressed(action_names[i]):
					pressed_index = i
					break

			if pressed_index == -1:
				continue

			reaction_done = true
			if pressed_index == target_index:
				result = 2
				arrow_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
				help.text = "PERFECT PARTING SHOT"
				help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
				if bf.crit_sound and bf.crit_sound.stream != null:
					bf.crit_sound.play()
				bf.screen_shake(12.0, 0.16)
			else:
				result = 1
				arrow_label.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
				help.text = "SHOT ONLY"
				help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()
			break

		if not reaction_done and result == 1:
			help.text = "SHOT ONLY"
			help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
			if bf.select_sound and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.08
				bf.select_sound.play()

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 360:
		await tree.process_frame

	_end_qte(bf, qte_layer, state)
	return result


# =========================================================
# DEATH KNIGHT QTE: SOUL HARVEST
# Tug-of-war mash meter for 2.5 seconds.
# Returns: 2 if ends above 85%, 1 if ends above 50%, 0 otherwise
# =========================================================
func run_soul_harvest_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker):
		return result

	var state: Dictionary = _begin_qte(bf)

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 230
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var tree: SceneTree = bf.get_tree()
	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.08, 0.01, 0.01, 0.88)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "SOUL HARVEST"
	title.position = Vector2(0.0, 68.0)
	title.size = Vector2(vp.x, 42.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "MASH SPACE TO HOLD THE BAR ABOVE THE DARK PULL"
	help.position = Vector2(0.0, 112.0)
	help.size = Vector2(vp.x, 30.0)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.size = Vector2(580.0, 40.0)
	bar_bg.position = Vector2((vp.x - bar_bg.size.x) * 0.5, (vp.y - bar_bg.size.y) * 0.5 - 12.0)
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.96)
	qte_layer.add_child(bar_bg)

	var fill: ColorRect = ColorRect.new()
	fill.size = Vector2(0.0, 40.0)
	fill.position = Vector2.ZERO
	fill.color = Color(1.0, 0.20, 0.20, 1.0)
	bar_bg.add_child(fill)

	var line_50: ColorRect = ColorRect.new()
	line_50.size = Vector2(4.0, 40.0)
	line_50.position = Vector2(bar_bg.size.x * 0.5, 0.0)
	line_50.color = Color.WHITE
	bar_bg.add_child(line_50)

	var line_85: ColorRect = ColorRect.new()
	line_85.size = Vector2(4.0, 40.0)
	line_85.position = Vector2(bar_bg.size.x * 0.85, 0.0)
	line_85.color = Color(1.0, 0.85, 0.2, 1.0)
	bar_bg.add_child(line_85)

	var value_label: Label = Label.new()
	value_label.position = Vector2(0.0, bar_bg.position.y + 54.0)
	value_label.size = Vector2(vp.x, 36.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 32)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	value_label.add_theme_constant_override("outline_size", 6)
	value_label.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(value_label)

	Input.flush_buffered_events()

	var meter: float = 55.0
	var total_ms: int = 2500
	var start_ms: int = Time.get_ticks_msec()
	var last_ms: int = start_ms

	while true:
		await tree.process_frame

		var now: int = Time.get_ticks_msec()
		var elapsed_ms: int = now - start_ms
		if elapsed_ms >= total_ms:
			break

		var dt: float = float(now - last_ms) / 1000.0
		last_ms = now

		meter -= 34.0 * dt

		if Input.is_action_just_pressed("ui_accept"):
			meter += 10.5
			if bf.select_sound and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.00 + (meter / 100.0) * 0.35
				bf.select_sound.play()

		meter = clampf(meter, 0.0, 100.0)
		fill.size.x = (meter / 100.0) * bar_bg.size.x
		value_label.text = str(int(round(meter))) + "%"

		if meter >= 85.0:
			fill.color = Color(1.0, 0.85, 0.2, 1.0)
		elif meter >= 50.0:
			fill.color = Color(0.85, 0.25, 0.25, 1.0)
		else:
			fill.color = Color(0.45, 0.12, 0.12, 1.0)

	if meter >= 85.0:
		result = 2
		help.text = "SOULS DOMINATED"
		help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		if bf.crit_sound and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		bf.screen_shake(14.0, 0.20)
	elif meter >= 50.0:
		result = 1
		help.text = "SOUL GRIP HELD"
		help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		if bf.select_sound and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.12
			bf.select_sound.play()
		bf.screen_shake(6.0, 0.10)
	else:
		result = 0
		help.text = "HARVEST COLLAPSED"
		help.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

	var hold_start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start < 360:
		await tree.process_frame

	_end_qte(bf, qte_layer, state)
	return result

# =========================================================
# DIVINE SAGE QTE: CELESTIAL CHOIR
# Mini rhythm game with 3 lanes and 6 falling notes.
# Returns: number of perfectly caught notes (0 to 6)
# =========================================================
func run_celestial_choir_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker):
		return result

	var state: Dictionary = self._begin_qte(bf)

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 240
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var tree: SceneTree = bf.get_tree()
	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.04, 0.04, 0.10, 0.88)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "CELESTIAL CHOIR"
	title.position = Vector2(0.0, 54.0)
	title.size = Vector2(vp.x, 42.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "LEFT / DOWN / RIGHT — HIT WHEN NOTES REACH THE LINE"
	help.position = Vector2(0.0, 98.0)
	help.size = Vector2(vp.x, 28.0)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var arena: ColorRect = ColorRect.new()
	arena.size = Vector2(420.0, 360.0)
	arena.position = Vector2((vp.x - arena.size.x) * 0.5, (vp.y - arena.size.y) * 0.5 - 8.0)
	arena.color = Color(0.08, 0.08, 0.12, 0.96)
	qte_layer.add_child(arena)

	var lane_width: float = arena.size.x / 3.0
	var lane_xs: Array[float] = [lane_width * 0.5, lane_width * 1.5, lane_width * 2.5]
	var lane_labels_text: Array[String] = ["LEFT", "DOWN", "RIGHT"]
	var lane_note_colors: Array[Color] = [
		Color(0.55, 0.80, 1.0, 1.0),
		Color(0.85, 1.0, 0.55, 1.0),
		Color(1.0, 0.70, 0.90, 1.0)
	]

	for i: int in range(1, 3):
		var divider: ColorRect = ColorRect.new()
		divider.size = Vector2(2.0, arena.size.y)
		divider.position = Vector2((lane_width * float(i)) - 1.0, 0.0)
		divider.color = Color(0.20, 0.20, 0.26, 1.0)
		arena.add_child(divider)

	var hit_line_y: float = arena.size.y - 56.0

	var hit_line: ColorRect = ColorRect.new()
	hit_line.size = Vector2(arena.size.x, 4.0)
	hit_line.position = Vector2(0.0, hit_line_y)
	hit_line.color = Color.WHITE
	arena.add_child(hit_line)

	var lane_boxes: Array[ColorRect] = []
	for lane_i: int in range(3):
		var lane_box: ColorRect = ColorRect.new()
		lane_box.size = Vector2(lane_width - 12.0, 34.0)
		lane_box.position = Vector2((lane_width * float(lane_i)) + 6.0, hit_line_y + 12.0)
		lane_box.color = Color(0.18, 0.18, 0.24, 0.96)
		arena.add_child(lane_box)
		lane_boxes.append(lane_box)

		var lane_label: Label = Label.new()
		lane_label.text = lane_labels_text[lane_i]
		lane_label.size = lane_box.size
		lane_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lane_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lane_label.add_theme_font_size_override("font_size", 20)
		lane_label.add_theme_color_override("font_color", Color.WHITE)
		lane_label.add_theme_constant_override("outline_size", 5)
		lane_label.add_theme_color_override("font_outline_color", Color.BLACK)
		lane_box.add_child(lane_label)

	var counter: Label = Label.new()
	counter.position = Vector2(0.0, arena.position.y + arena.size.y + 16.0)
	counter.size = Vector2(vp.x, 30.0)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.add_theme_font_size_override("font_size", 24)
	counter.add_theme_color_override("font_color", Color.WHITE)
	counter.add_theme_constant_override("outline_size", 5)
	counter.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(counter)

	var note_nodes: Array[ColorRect] = []
	var note_lane_indexes: Array[int] = []
	var note_hit_times_ms: Array[int] = []
	var note_resolved: Array[bool] = []
	var note_hit: Array[bool] = []

	var base_hit_times_ms: Array[int] = [700, 1120, 1540, 1960, 2380, 2800]
	for i: int in range(6):
		var lane_index: int = randi() % 3
		var note: ColorRect = ColorRect.new()
		note.size = Vector2(52.0, 24.0)
		note.color = lane_note_colors[lane_index]
		note.visible = false
		arena.add_child(note)

		var offset_ms: int = int(randf_range(-45.0, 45.0))
		var hit_time_ms: int = base_hit_times_ms[i] + offset_ms

		note_nodes.append(note)
		note_lane_indexes.append(lane_index)
		note_hit_times_ms.append(hit_time_ms)
		note_resolved.append(false)
		note_hit.append(false)

	Input.flush_buffered_events()

	var action_names: Array[String] = ["ui_left", "ui_down", "ui_right"]
	var note_fall_duration_ms: int = 900
	var perfect_window_ms: int = 95
	var total_ms: int = 3000
	var start_ms: int = Time.get_ticks_msec()

	while true:
		await tree.process_frame

		var now: int = Time.get_ticks_msec()
		var elapsed_ms: int = now - start_ms
		if elapsed_ms >= total_ms:
			break

		for lane_flash_i: int in range(3):
			lane_boxes[lane_flash_i].color = Color(0.18, 0.18, 0.24, 0.96)

		for note_i: int in range(6):
			if note_resolved[note_i]:
				continue

			var note_hit_time_ms: int = note_hit_times_ms[note_i]
			var note_visible_start_ms: int = note_hit_time_ms - note_fall_duration_ms
			var note: ColorRect = note_nodes[note_i]

			if elapsed_ms < note_visible_start_ms:
				note.visible = false
				continue

			if elapsed_ms > note_hit_time_ms + perfect_window_ms:
				note.visible = false
				note_resolved[note_i] = true
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()
				continue

			var t: float = clampf(float(elapsed_ms - note_visible_start_ms) / float(note_fall_duration_ms), 0.0, 1.0)
			var lane_index_now: int = note_lane_indexes[note_i]
			var x_pos: float = lane_xs[lane_index_now] - (note.size.x * 0.5)
			var y_pos: float = lerpf(-26.0, hit_line_y - (note.size.y * 0.5), t)

			note.position = Vector2(x_pos, y_pos)
			note.visible = true
		counter.text = "PERFECT NOTES: " + str(result) + " / 6"

		var pressed_lane: int = -1
		for lane_check_i: int in range(3):
			if Input.is_action_just_pressed(action_names[lane_check_i]):
				pressed_lane = lane_check_i
				break

		if pressed_lane == -1:
			continue

		lane_boxes[pressed_lane].color = Color(0.35, 1.0, 0.35, 0.96)

		var best_note_index: int = -1
		var best_diff_ms: int = 999999

		for note_match_i: int in range(6):
			if note_resolved[note_match_i]:
				continue
			if note_lane_indexes[note_match_i] != pressed_lane:
				continue

			var diff_ms: int = abs(elapsed_ms - note_hit_times_ms[note_match_i])
			if diff_ms < best_diff_ms:
				best_diff_ms = diff_ms
				best_note_index = note_match_i

		if best_note_index != -1 and best_diff_ms <= perfect_window_ms:
			note_resolved[best_note_index] = true
			note_hit[best_note_index] = true
			note_nodes[best_note_index].visible = false
			result += 1

			if bf.select_sound and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.04 + (float(result) * 0.06)
				bf.select_sound.play()
		else:
			if bf.miss_sound and bf.miss_sound.stream != null:
				bf.miss_sound.play()

	if result >= 6:
		help.text = "PERFECT CHOIR"
		help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		if bf.crit_sound and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		bf.screen_shake(12.0, 0.16)
	elif result >= 3:
		help.text = "GOOD HARMONY"
		help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
		if bf.select_sound and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.14
			bf.select_sound.play()
	else:
		help.text = "RHYTHM BROKEN"
		help.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

	var hold_start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start_ms < 360:
		await tree.process_frame

	self._end_qte(bf, qte_layer, state)
	return result


# =========================================================
# FIRE SAGE QTE: HELLFIRE
# Keep heat inside the top 15% red zone for 1.5 accumulated seconds.
# Returns: 2 for success, 0 for failure
# =========================================================
func run_hellfire_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker):
		return result

	var state: Dictionary = self._begin_qte(bf)

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 240
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var tree: SceneTree = bf.get_tree()
	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.10, 0.02, 0.01, 0.90)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "HELLFIRE"
	title.position = Vector2(0.0, 58.0)
	title.size = Vector2(vp.x, 42.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.50, 0.15))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "MASH SPACE TO HOLD THE HEAT IN THE RED ZONE"
	help.position = Vector2(0.0, 102.0)
	title.size = Vector2(vp.x, 42.0)
	help.size = Vector2(vp.x, 28.0)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var gauge_bg: ColorRect = ColorRect.new()
	gauge_bg.size = Vector2(76.0, 340.0)
	gauge_bg.position = Vector2((vp.x - gauge_bg.size.x) * 0.5, (vp.y - gauge_bg.size.y) * 0.5 - 8.0)
	gauge_bg.color = Color(0.08, 0.08, 0.08, 0.96)
	qte_layer.add_child(gauge_bg)

	var red_zone_height: float = gauge_bg.size.y * 0.15

	var red_zone: ColorRect = ColorRect.new()
	red_zone.size = Vector2(gauge_bg.size.x, red_zone_height)
	red_zone.position = Vector2(0.0, 0.0)
	red_zone.color = Color(1.0, 0.20, 0.10, 0.70)
	gauge_bg.add_child(red_zone)

	var fill: ColorRect = ColorRect.new()
	fill.size = Vector2(gauge_bg.size.x, 0.0)
	fill.position = Vector2(0.0, gauge_bg.size.y)
	fill.color = Color(1.0, 0.50, 0.15, 1.0)
	gauge_bg.add_child(fill)

	var percent_label: Label = Label.new()
	percent_label.position = Vector2(0.0, gauge_bg.position.y + gauge_bg.size.y + 16.0)
	percent_label.size = Vector2(vp.x, 32.0)
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	percent_label.add_theme_font_size_override("font_size", 28)
	percent_label.add_theme_color_override("font_color", Color.WHITE)
	percent_label.add_theme_constant_override("outline_size", 6)
	percent_label.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(percent_label)

	var progress_label: Label = Label.new()
	progress_label.position = Vector2(0.0, percent_label.position.y + 34.0)
	progress_label.size = Vector2(vp.x, 30.0)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 24)
	progress_label.add_theme_color_override("font_color", Color.WHITE)
	progress_label.add_theme_constant_override("outline_size", 5)
	progress_label.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(progress_label)

	Input.flush_buffered_events()

	var total_ms: int = 3500
	var success_goal_ms: int = 1500
	var start_ms: int = Time.get_ticks_msec()
	var last_ms: int = start_ms
	var heat: float = 52.0
	var red_zone_accum_ms: int = 0

	while true:
		await tree.process_frame

		var now: int = Time.get_ticks_msec()
		var elapsed_ms: int = now - start_ms
		if elapsed_ms >= total_ms:
			break

		var dt: float = float(now - last_ms) / 1000.0
		last_ms = now

		heat -= 27.0 * dt

		if Input.is_action_just_pressed("ui_accept"):
			heat += 10.5
			if bf.select_sound and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.00 + ((heat / 100.0) * 0.30)
				bf.select_sound.play()

		heat = clampf(heat, 0.0, 100.0)

		if heat >= 85.0:
			red_zone_accum_ms += int((now - last_ms) + 0.5)
			fill.color = Color(1.0, 0.12, 0.08, 1.0)
		elif heat >= 55.0:
			fill.color = Color(1.0, 0.45, 0.15, 1.0)
		else:
			fill.color = Color(0.75, 0.28, 0.10, 1.0)

		var fill_height: float = (heat / 100.0) * gauge_bg.size.y
		fill.size = Vector2(gauge_bg.size.x, fill_height)
		fill.position = Vector2(0.0, gauge_bg.size.y - fill_height)

		percent_label.text = str(int(round(heat))) + "%"
		progress_label.text = "RED ZONE TIME: %0.2f / 1.50" % (float(red_zone_accum_ms) / 1000.0)

		if red_zone_accum_ms >= success_goal_ms:
			result = 2
			break

	if result == 2:
		help.text = "HELLFIRE UNLEASHED"
		help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		if bf.crit_sound and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		bf.screen_shake(14.0, 0.20)
	else:
		result = 0
		help.text = "THE FLAME FELL"
		help.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

	var hold_start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start_ms < 360:
		await tree.process_frame

	self._end_qte(bf, qte_layer, state)
	return result


# =========================================================
# GREAT KNIGHT QTE: PHALANX
# Memorize and input the 4-button sequence in order.
# Returns: 2 for perfect sequence, 0 for fail
# =========================================================
func run_phalanx_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker):
		return result

	var state: Dictionary = self._begin_qte(bf)

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 240
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var tree: SceneTree = bf.get_tree()
	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.03, 0.05, 0.08, 0.88)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "PHALANX"
	title.position = Vector2(0.0, 58.0)
	title.size = Vector2(vp.x, 42.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "MEMORIZE THE SHIELD ORDER, THEN INPUT IT"
	help.position = Vector2(0.0, 102.0)
	help.size = Vector2(vp.x, 28.0)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var center_x: float = vp.x * 0.5
	var center_y: float = vp.y * 0.5

	var up_box: ColorRect = ColorRect.new()
	up_box.size = Vector2(120.0, 120.0)
	up_box.position = Vector2(center_x - 60.0, center_y - 190.0)
	up_box.color = Color(0.20, 0.20, 0.24, 0.96)
	qte_layer.add_child(up_box)

	var down_box: ColorRect = ColorRect.new()
	down_box.size = Vector2(120.0, 120.0)
	down_box.position = Vector2(center_x - 60.0, center_y + 70.0)
	down_box.color = Color(0.20, 0.20, 0.24, 0.96)
	qte_layer.add_child(down_box)

	var left_box: ColorRect = ColorRect.new()
	left_box.size = Vector2(120.0, 120.0)
	left_box.position = Vector2(center_x - 190.0, center_y - 60.0)
	left_box.color = Color(0.20, 0.20, 0.24, 0.96)
	qte_layer.add_child(left_box)

	var right_box: ColorRect = ColorRect.new()
	right_box.size = Vector2(120.0, 120.0)
	right_box.position = Vector2(center_x + 70.0, center_y - 60.0)
	right_box.color = Color(0.20, 0.20, 0.24, 0.96)
	qte_layer.add_child(right_box)

	var box_labels_text: Array[String] = ["UP", "DOWN", "LEFT", "RIGHT"]
	var boxes: Array[ColorRect] = [up_box, down_box, left_box, right_box]

	for i: int in range(4):
		var lbl: Label = Label.new()
		lbl.text = box_labels_text[i]
		lbl.size = boxes[i].size
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 34)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		boxes[i].add_child(lbl)

	var action_names: Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right"]
	var sequence: Array[int] = []
	for i: int in range(4):
		sequence.append(randi() % 4)

	Input.flush_buffered_events()

	for seq_i: int in range(4):
		for reset_i: int in range(4):
			boxes[reset_i].color = Color(0.20, 0.20, 0.24, 0.96)

		boxes[sequence[seq_i]].color = Color(1.0, 0.85, 0.2, 1.0)

		if bf.select_sound and bf.select_sound.stream != null:
			bf.select_sound.pitch_scale = 1.00 + (float(seq_i) * 0.04)
			bf.select_sound.play()

		var show_start_ms: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - show_start_ms < 280:
			await tree.process_frame

		for reset_after_i: int in range(4):
			boxes[reset_after_i].color = Color(0.20, 0.20, 0.24, 0.96)

		var gap_start_ms: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - gap_start_ms < 90:
			await tree.process_frame

	help.text = "REPEAT THE ORDER"
	help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
	Input.flush_buffered_events()

	var correct_count: int = 0
	var input_start_ms: int = Time.get_ticks_msec()
	var total_input_ms: int = 2000

	while true:
		await tree.process_frame

		var now: int = Time.get_ticks_msec()
		if now - input_start_ms >= total_input_ms:
			break

		var pressed_index: int = -1
		for input_i: int in range(4):
			if Input.is_action_just_pressed(action_names[input_i]):
				pressed_index = input_i
				break

		if pressed_index == -1:
			continue

		if pressed_index == sequence[correct_count]:
			boxes[pressed_index].color = Color(0.35, 1.0, 0.35, 1.0)
			correct_count += 1
			if bf.select_sound and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.08 + (float(correct_count) * 0.05)
				bf.select_sound.play()

			if correct_count >= 4:
				result = 2
				break
		else:
			boxes[pressed_index].color = Color(1.0, 0.30, 0.30, 1.0)
			if bf.miss_sound and bf.miss_sound.stream != null:
				bf.miss_sound.play()
			result = 0
			break

	if result == 2:
		help.text = "PERFECT PHALANX"
		help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		if bf.crit_sound and bf.crit_sound.stream != null:
			bf.crit_sound.play()
		bf.screen_shake(12.0, 0.16)
	else:
		result = 0
		help.text = "FORMATION BROKEN"
		help.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

	var hold_start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start_ms < 360:
		await tree.process_frame

	self._end_qte(bf, qte_layer, state)
	return result


# =========================================================
# HEAVY ARCHER QTE: BALLISTA SHOT
# Move crosshair with arrows. Hold SPACE to zoom and slow the crosshair.
# Release SPACE while aligned over the moving target.
# Returns: 2 for bullseye, 1 for glancing, 0 for miss
# =========================================================
func run_ballista_shot_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker):
		return result

	var state: Dictionary = self._begin_qte(bf)

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 240
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var tree: SceneTree = bf.get_tree()
	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.02, 0.02, 0.02, 0.90)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "BALLISTA SHOT"
	title.position = Vector2(0.0, 54.0)
	title.size = Vector2(vp.x, 42.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "MOVE WITH ARROWS • HOLD SPACE TO ZOOM • RELEASE TO FIRE"
	help.position = Vector2(0.0, 98.0)
	help.size = Vector2(vp.x, 28.0)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var arena: ColorRect = ColorRect.new()
	arena.size = Vector2(700.0, 380.0)
	arena.position = Vector2((vp.x - arena.size.x) * 0.5, (vp.y - arena.size.y) * 0.5 - 10.0)
	arena.color = Color(0.08, 0.08, 0.10, 0.96)
	qte_layer.add_child(arena)

	var target_dot: ColorRect = ColorRect.new()
	target_dot.size = Vector2(10.0, 10.0)
	target_dot.color = Color(1.0, 0.20, 0.20, 1.0)
	arena.add_child(target_dot)

	var crosshair_h: ColorRect = ColorRect.new()
	crosshair_h.color = Color.WHITE
	arena.add_child(crosshair_h)

	var crosshair_v: ColorRect = ColorRect.new()
	crosshair_v.color = Color.WHITE
	arena.add_child(crosshair_v)

	var status_label: Label = Label.new()
	status_label.position = Vector2(0.0, arena.position.y + arena.size.y + 16.0)
	status_label.size = Vector2(vp.x, 30.0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.add_theme_constant_override("outline_size", 5)
	status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(status_label)

	Input.flush_buffered_events()

	var total_ms: int = 4200
	var start_ms: int = Time.get_ticks_msec()
	var last_ms: int = start_ms

	var target_pos: Vector2 = Vector2(arena.size.x * 0.65, arena.size.y * 0.40)
	var target_vel: Vector2 = Vector2(155.0, 105.0)
	var next_dir_change_ms: int = start_ms + 260

	var crosshair_pos: Vector2 = arena.size * 0.5
	var crosshair_size: float = 76.0
	var shot_fired: bool = false

	while true:
		await tree.process_frame

		var now: int = Time.get_ticks_msec()
		var elapsed_ms: int = now - start_ms
		if elapsed_ms >= total_ms:
			break

		var dt: float = float(now - last_ms) / 1000.0
		last_ms = now

		if now >= next_dir_change_ms:
			target_vel = Vector2(
				randf_range(-210.0, 210.0),
				randf_range(-160.0, 160.0)
			)
			next_dir_change_ms = now + 240

		target_pos += target_vel * dt

		if target_pos.x <= 8.0:
			target_pos.x = 8.0
			target_vel.x = abs(target_vel.x)
		elif target_pos.x >= arena.size.x - 8.0:
			target_pos.x = arena.size.x - 8.0
			target_vel.x = -abs(target_vel.x)

		if target_pos.y <= 8.0:
			target_pos.y = 8.0
			target_vel.y = abs(target_vel.y)
		elif target_pos.y >= arena.size.y - 8.0:
			target_pos.y = arena.size.y - 8.0
			target_vel.y = -abs(target_vel.y)

		target_dot.position = target_pos - (target_dot.size * 0.5)

		var move_input: Vector2 = Vector2.ZERO
		if Input.is_action_pressed("ui_left"):
			move_input.x -= 1.0
		if Input.is_action_pressed("ui_right"):
			move_input.x += 1.0
		if Input.is_action_pressed("ui_up"):
			move_input.y -= 1.0
		if Input.is_action_pressed("ui_down"):
			move_input.y += 1.0

		var is_zooming: bool = Input.is_action_pressed("ui_accept")
		var move_speed: float = 320.0
		var target_crosshair_size: float = 76.0
		if is_zooming:
			move_speed = 180.0
			target_crosshair_size = 30.0

		crosshair_size = lerpf(crosshair_size, target_crosshair_size, 0.18)
		crosshair_pos += move_input.normalized() * move_speed * dt
		crosshair_pos.x = clampf(crosshair_pos.x, crosshair_size * 0.5, arena.size.x - crosshair_size * 0.5)
		crosshair_pos.y = clampf(crosshair_pos.y, crosshair_size * 0.5, arena.size.y - crosshair_size * 0.5)

		crosshair_h.size = Vector2(crosshair_size, 2.0)
		crosshair_h.position = Vector2(crosshair_pos.x - (crosshair_size * 0.5), crosshair_pos.y - 1.0)

		crosshair_v.size = Vector2(2.0, crosshair_size)
		crosshair_v.position = Vector2(crosshair_pos.x - 1.0, crosshair_pos.y - (crosshair_size * 0.5))

		status_label.text = "TARGET DISTANCE: %0.1f" % crosshair_pos.distance_to(target_pos)

		if Input.is_action_just_released("ui_accept"):
			shot_fired = true
			var dist: float = crosshair_pos.distance_to(target_pos)
			if crosshair_size <= 40.0 and dist <= 8.0:
				result = 2
				help.text = "BULLSEYE"
				help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
				if bf.crit_sound and bf.crit_sound.stream != null:
					bf.crit_sound.play()
				bf.screen_shake(14.0, 0.18)
			elif crosshair_size <= 52.0 and dist <= 22.0:
				result = 1
				help.text = "GLANCING HIT"
				help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.18
					bf.select_sound.play()
				bf.screen_shake(7.0, 0.10)
			else:
				result = 0
				help.text = "MISSED SHOT"
				help.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
				if bf.miss_sound and bf.miss_sound.stream != null:
					bf.miss_sound.play()
			break

	if not shot_fired:
		result = 0
		help.text = "NO SHOT FIRED"
		help.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

	var hold_start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start_ms < 360:
		await tree.process_frame

	self._end_qte(bf, qte_layer, state)
	return result


# =========================================================
# HIGH PALADIN QTE: AEGIS STRIKE
# Lock horizontal cursor, then vertical cursor, near center.
# Returns: 2 for perfect cross, 1 for partial alignment, 0 for miss
# =========================================================
func run_aegis_strike_minigame(bf: Node2D, attacker: Node2D) -> int:
	var result: int = 0
	if attacker == null or not is_instance_valid(attacker):
		return result

	var state: Dictionary = self._begin_qte(bf)

	var qte_layer: CanvasLayer = CanvasLayer.new()
	qte_layer.layer = 240
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	bf.add_child(qte_layer)

	var tree: SceneTree = bf.get_tree()
	var vp: Vector2 = bf.get_viewport_rect().size

	var dimmer: ColorRect = ColorRect.new()
	dimmer.size = vp
	dimmer.color = Color(0.06, 0.06, 0.10, 0.88)
	qte_layer.add_child(dimmer)

	var title: Label = Label.new()
	title.text = "AEGIS STRIKE"
	title.position = Vector2(0.0, 58.0)
	title.size = Vector2(vp.x, 42.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(title)

	var help: Label = Label.new()
	help.text = "SPACE TO LOCK HORIZONTAL, SPACE AGAIN TO LOCK VERTICAL"
	help.position = Vector2(0.0, 102.0)
	help.size = Vector2(vp.x, 28.0)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.add_theme_color_override("font_color", Color.WHITE)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(help)
	_apply_qte_visual_overhaul(qte_layer, title, help)

	var center: Vector2 = vp * 0.5 + Vector2(0.0, 18.0)

	var h_bar: ColorRect = ColorRect.new()
	h_bar.size = Vector2(520.0, 28.0)
	h_bar.position = Vector2(center.x - (h_bar.size.x * 0.5), center.y - 14.0)
	h_bar.color = Color(0.08, 0.08, 0.08, 0.96)
	qte_layer.add_child(h_bar)

	var v_bar: ColorRect = ColorRect.new()
	v_bar.size = Vector2(28.0, 320.0)
	v_bar.position = Vector2(center.x - 14.0, center.y - (v_bar.size.y * 0.5))
	v_bar.color = Color(0.08, 0.08, 0.08, 0.96)
	qte_layer.add_child(v_bar)

	var h_center_line: ColorRect = ColorRect.new()
	h_center_line.size = Vector2(4.0, h_bar.size.y)
	h_center_line.position = Vector2((h_bar.size.x * 0.5) - 2.0, 0.0)
	h_center_line.color = Color.WHITE
	h_bar.add_child(h_center_line)

	var v_center_line: ColorRect = ColorRect.new()
	v_center_line.size = Vector2(v_bar.size.x, 4.0)
	v_center_line.position = Vector2(0.0, (v_bar.size.y * 0.5) - 2.0)
	v_center_line.color = Color.WHITE
	v_bar.add_child(v_center_line)

	var h_cursor: ColorRect = ColorRect.new()
	h_cursor.size = Vector2(12.0, 40.0)
	h_cursor.color = Color(0.75, 0.92, 1.0, 1.0)
	qte_layer.add_child(h_cursor)

	var v_cursor: ColorRect = ColorRect.new()
	v_cursor.size = Vector2(40.0, 12.0)
	v_cursor.color = Color(1.0, 0.85, 0.2, 1.0)
	qte_layer.add_child(v_cursor)

	var status_label: Label = Label.new()
	status_label.position = Vector2(0.0, v_bar.position.y + v_bar.size.y + 18.0)
	status_label.size = Vector2(vp.x, 30.0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.add_theme_constant_override("outline_size", 5)
	status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_layer.add_child(status_label)

	Input.flush_buffered_events()

	var total_ms: int = 2800
	var start_ms: int = Time.get_ticks_msec()
	var horizontal_locked: bool = false
	var vertical_locked: bool = false

	var h_locked_x: float = center.x
	var v_locked_y: float = center.y

	while true:
		await tree.process_frame

		var now: int = Time.get_ticks_msec()
		var elapsed_ms: int = now - start_ms
		if elapsed_ms >= total_ms:
			break

		var time_sec: float = float(elapsed_ms) / 1000.0

		var h_progress: float = (sin(time_sec * 4.1) + 1.0) * 0.5
		var v_progress: float = (sin((time_sec * 4.9) + 1.15) + 1.0) * 0.5

		var h_x: float = h_bar.position.x + (h_progress * h_bar.size.x)
		var v_y: float = v_bar.position.y + (v_progress * v_bar.size.y)

		if not horizontal_locked:
			h_cursor.position = Vector2(h_x - (h_cursor.size.x * 0.5), center.y - (h_cursor.size.y * 0.5))
		else:
			h_cursor.position = Vector2(h_locked_x - (h_cursor.size.x * 0.5), center.y - (h_cursor.size.y * 0.5))

		if not vertical_locked:
			v_cursor.position = Vector2(center.x - (v_cursor.size.x * 0.5), v_y - (v_cursor.size.y * 0.5))
		else:
			v_cursor.position = Vector2(center.x - (v_cursor.size.x * 0.5), v_locked_y - (v_cursor.size.y * 0.5))

		if not horizontal_locked:
			status_label.text = "LOCK HORIZONTAL"
		elif not vertical_locked:
			status_label.text = "LOCK VERTICAL"
		else:
			status_label.text = "EVALUATING"

		if Input.is_action_just_pressed("ui_accept"):
			if not horizontal_locked:
				horizontal_locked = true
				h_locked_x = h_x
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.08
					bf.select_sound.play()
			elif not vertical_locked:
				vertical_locked = true
				v_locked_y = v_y
				if bf.select_sound and bf.select_sound.stream != null:
					bf.select_sound.pitch_scale = 1.16
					bf.select_sound.play()
				break

	if horizontal_locked and vertical_locked:
		var dx: float = abs(h_locked_x - center.x)
		var dy: float = abs(v_locked_y - center.y)

		if dx <= 10.0 and dy <= 10.0:
			result = 2
			help.text = "PERFECT CROSS"
			help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			if bf.crit_sound and bf.crit_sound.stream != null:
				bf.crit_sound.play()
			bf.screen_shake(14.0, 0.18)
		elif dx <= 28.0 and dy <= 28.0:
			result = 1
			help.text = "PARTIAL ALIGNMENT"
			help.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35))
			if bf.select_sound and bf.select_sound.stream != null:
				bf.select_sound.pitch_scale = 1.18
				bf.select_sound.play()
			bf.screen_shake(7.0, 0.10)
		else:
			result = 0
			help.text = "MISALIGNED"
			help.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
			if bf.miss_sound and bf.miss_sound.stream != null:
				bf.miss_sound.play()
	else:
		result = 0
		help.text = "TOO SLOW"
		help.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
		if bf.miss_sound and bf.miss_sound.stream != null:
			bf.miss_sound.play()

	var hold_start_ms: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - hold_start_ms < 360:
		await tree.process_frame

	self._end_qte(bf, qte_layer, state)
	return result
