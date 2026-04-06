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
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEHoldReleaseBar.run(bf, "CHARGE", "HOLD SPACE, RELEASE IN GREEN", 1400)
	qte.green_zone.position.x = 365.0; qte.green_zone.size.x = 70.0
	qte.perfect_zone.size.x = 22.0
	var res = await qte.qte_finished
	return res


func run_shield_bash_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte = QTESequenceMemory.run(bf, "SHIELD BASH", "MEMORIZE THE 3 ARROWS, THEN INPUT FAST", 3)
	var res = await qte.qte_finished
	return res


func run_unbreakable_bastion_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte = QTEAlternatingMashMeter.run(bf, "UNBREAKABLE BASTION", "ALTERNATE LEFT / RIGHT TO BRACE", 2500)
	var res = await qte.qte_finished
	return res


func run_fireball_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEBubbleExpansion.run(bf, "FIREBALL", "TAP SPACE REPEATEDLY TO GROW THE BUBBLE", 2000)
	var res = await qte.qte_finished
	return res


func run_arcane_shift_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte = QTEAlternatingMashMeter.run(bf, "ARCANE SHIFT", "ALTERNATE UP / DOWN TO PHASE OUT", 2200)
	var res = await qte.qte_finished
	return res


func run_meteor_storm_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTESequenceMemory.run(bf, "METEOR STORM", "MEMORIZE THE 5 ARROWS", 5)
	var res = await qte.qte_finished
	return res


func run_flurry_strike_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEMashMeter.run(bf, "FLURRY STRIKE", "TAP SPACE AS FAST AS POSSIBLE", 1500, 14)
	var res = await qte.qte_finished
	return res

func run_battle_cry_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEHoldReleaseBar.run(bf, "BATTLE CRY", "HOLD SPACE — RELEASE IN THE TINY GREEN WINDOW", 1500)
	var res = await qte.qte_finished
	return res

func run_blade_tempest_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEMultiTapDial.run(bf, "BLADE TEMPEST", "TAP SPACE AS THE NEEDLE PASSES THE 3 GOLD ZONES", [20.0, 150.0, 285.0], 420.0, 2600)
	var res = await qte.qte_finished
	return res

func run_chakra_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEBalanceMeter.run(bf, "CHAKRA", "USE LEFT / RIGHT TO KEEP THE MIND CENTERED", 2500)
	var res = await qte.qte_finished
	return res


func run_inner_peace_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte = QTEFastSequence.run(bf, "INNER PEACE", "INPUT THE 4-ARROW MANTRA BEFORE TIME RUNS OUT", 4, 3350, 850) # 850ms reveal + 2500ms input = 3350
	var res = await qte.qte_finished
	return res


func run_chi_burst_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEBreathingCircle.run(bf, "CHI BURST", "PRESS SPACE AT THE ABSOLUTE PEAK", 920, 460)
	var res = await qte.qte_finished
	return res


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
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEShrinkingRing.run(bf, "SMITE", "PRESS SPACE WHEN THE RING ALIGNS", 750)
	var res = await qte.qte_finished
	return res


func run_holy_ward_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte = QTEFastSequence.run(bf, "HOLY WARD", "INPUT THE 4 ARROWS FAST TO BLOCK MAGIC", 4, 2400, 1000)
	var res = await qte.qte_finished
	return res


func run_sacred_judgment_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEPingPongBar.run(bf, "SACRED JUDGMENT", "RELEASE NEAR MAX", 2.4)
	var res = await qte.qte_finished
	return res


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
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEReactionStrike.run(bf, "ELEMENTAL CONVERGENCE", "PRESS THE ARROW AS SOON AS IT APPEARS!", 4, 550)
	var res = await qte.qte_finished
	return res


func run_shadow_strike_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEStealthBar.run(bf, "SHADOW STRIKE", "PRESS SPACE INSIDE THE SHADOW BAND", 700)
	var res = await qte.qte_finished
	return res


func run_assassinate_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEMultiTargetBar.run(bf, "ASSASSINATE", "TAP SPACE ON THE 3 VITAL POINTS!", 1500)
	var res = await qte.qte_finished
	return res


func run_ultimate_shadow_step_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEReactionStrike.run(bf, "ULTIMATE SHADOW STEP", "PRESS THE ARROW AS SOON AS IT APPEARS!", 4, 550)
	var res = await qte.qte_finished
	return res


func run_power_strike_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTETimingBar.run(bf, "POWER STRIKE", "PRESS SPACE AT MAX POWER", 1300)
	
	# Override position
	qte.outer_good.position.x = 520.0 - 120.0 # From original bar width
	qte.outer_good.size.x = 120.0
	qte.perfect_zone.position.x = 90.0
	qte.perfect_zone.size.x = 24.0
	
	var res = await qte.qte_finished
	return res

func run_adrenaline_rush_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEAlternatingMashMeter.run(bf, "ADRENALINE RUSH", "ALTERNATE LEFT / RIGHT FAST TO PUMP BLOOD", 2000)
	var res = await qte.qte_finished
	return res


func run_earthshatter_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEExpandingRing.run(bf, "EARTHSHATTER", "HOLD SPACE TO CHARGE, RELEASE IN THE RING", 1600)
	var res = await qte.qte_finished
	return res


func run_shadow_pin_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTECrosshairPin.run(bf, "SHADOW PIN", "TRACK THE DOT WITH ARROWS — PRESS SPACE ON TARGET", 2600)
	var res = await qte.qte_finished
	return res


func run_weapon_shatter_minigame(bf: Node2D, defender: Node2D) -> int:
	if defender == null or not is_instance_valid(defender): return 0
	var qte = QTEClashTiming.run(bf, "WEAPON SHATTER", "PRESS SPACE EXACTLY ON IMPACT", 900)
	var res = await qte.qte_finished
	return res


func run_savage_toss_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEOscillationStop.run(bf, "SAVAGE TOSS", "STOP THE NEEDLE IN THE TINY TOP SWEET SPOT", 1800)
	var res = await qte.qte_finished
	return res


func run_vanguards_rally_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTEComboRush.run(bf, "VANGUARD'S RALLY", "COMPLETE AS MANY 4-BUTTON COMBOS AS POSSIBLE", 3500)
	var res = await qte.qte_finished
	return res


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
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTESniperZoom.run(bf, "PHALANX", "HOLD SPACE TO ZOOM AND AIM", 4200)
	var res = await qte.qte_finished
	return res


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
	if attacker == null or not is_instance_valid(attacker): return 0
	var qte = QTECrossAlignment.run(bf, "AEGIS STRIKE", "SPACE TO LOCK HORIZONTAL, SPACE AGAIN TO LOCK VERTICAL")
	var res = await qte.qte_finished
	return res

