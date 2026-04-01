extends RefCounted


static func capture_ui_visibility_snapshot(field) -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	if field.ui_root == null:
		return snapshot
	for child in field.ui_root.get_children():
		if child is CanvasItem:
			snapshot.append({
				"node": child,
				"visible": (child as CanvasItem).visible,
			})
	return snapshot


static func set_ui_children_visible(field, visible: bool) -> void:
	if field.ui_root == null:
		return
	for child in field.ui_root.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = visible


static func restore_ui_visibility_snapshot(field, snapshot: Array[Dictionary]) -> void:
	for entry in snapshot:
		var node_variant: Variant = entry.get("node")
		if node_variant is CanvasItem and is_instance_valid(node_variant):
			(node_variant as CanvasItem).visible = bool(entry.get("visible", true))


static func play_cinematic_dialogue(
	field,
	speaker_name: String,
	portrait_tex: Texture2D,
	lines: Array,
	hide_gameplay_ui: bool = false
) -> void:
	var prev_tree_paused: bool = field.get_tree().paused
	var prev_cam_process_mode: Node.ProcessMode = field.main_camera.process_mode if field.main_camera != null else Node.PROCESS_MODE_INHERIT

	# 1. Freeze the game so nothing moves in the background
	field.get_tree().paused = true
	var vp_size = field.get_viewport_rect().size
	var ui_visibility_snapshot: Array[Dictionary] = []
	if hide_gameplay_ui:
		ui_visibility_snapshot = capture_ui_visibility_snapshot(field)
		set_ui_children_visible(field, false)

	# ==========================================
	# --- FIX: ROBUST NAME MATCHING & CAMERA WAKEUP ---
	# ==========================================
	# Force the camera to stay awake while the game is paused!
	field.main_camera.process_mode = Node.PROCESS_MODE_ALWAYS

	var target_unit: Node2D = null
	var all_units = field.player_container.get_children()
	if field.ally_container:
		all_units += field.ally_container.get_children()
	if field.enemy_container:
		all_units += field.enemy_container.get_children()

	var s_name_lower = speaker_name.to_lower()

	# Find the speaker on the board
	for u in all_units:
		if not is_instance_valid(u):
			continue

		# Check both the custom RPG name and the internal Node name
		var u_name = ""
		if u.get("unit_name") != null:
			u_name = str(u.get("unit_name")).to_lower()

		var node_name = u.name.to_lower()

		# Smarter check: Matches "Malakor" even if the node is called "EnemyUnit"
		if u_name == s_name_lower or s_name_lower in u_name or s_name_lower in node_name:
			target_unit = u
			break

	# Fallback for Bartholomew! (Point the camera at the Donkey Cart)
	if target_unit == null and "bartholomew" in s_name_lower and is_instance_valid(field.vip_target):
		target_unit = field.vip_target

	var highlight: ColorRect = null
	if target_unit != null:
		# Pan Camera to the speaker
		var target_cam_pos = target_unit.global_position + Vector2(32, 32)
		if field.main_camera.anchor_mode == Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT:
			target_cam_pos -= (vp_size * 0.5) / field.main_camera.zoom

		var cam_tw = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		cam_tw.tween_property(field.main_camera, "global_position", target_cam_pos, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		# Flash their tile (Red for enemies, Blue for players, Green for Allies)
		highlight = ColorRect.new()
		highlight.size = Vector2(64, 64)
		highlight.position = target_unit.global_position
		highlight.z_index = 50 # <-- FIX: Make sure it draws ABOVE the map tiles!

		if target_unit.get_parent() == field.enemy_container:
			highlight.color = Color(1.0, 0.2, 0.2)
		elif target_unit.get_parent() == field.ally_container:
			highlight.color = Color(0.2, 1.0, 0.2)
		else:
			highlight.color = Color(0.2, 0.6, 1.0)

		highlight.modulate.a = 0.0
		highlight.process_mode = Node.PROCESS_MODE_ALWAYS # Run while paused
		field.add_child(highlight)

		# Make it pulse!
		# --- THE FIX: Attach the tween directly to the highlight node! ---
		var hl_tw = highlight.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_loops()
		hl_tw.tween_property(highlight, "modulate:a", 0.6, 0.5).set_trans(Tween.TRANS_SINE)
		hl_tw.tween_property(highlight, "modulate:a", 0.1, 0.5).set_trans(Tween.TRANS_SINE)

	# 2. Setup the Canvas Layer
	var cine_layer = CanvasLayer.new()
	cine_layer.layer = 120 # Put it above everything!
	cine_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	field.add_child(cine_layer)

	# 3. The Dimmer Background
	var dimmer = ColorRect.new()
	dimmer.size = vp_size
	dimmer.color = Color(0, 0, 0, 0.4)
	dimmer.modulate.a = 0.0
	cine_layer.add_child(dimmer)

	# 4. The Portrait
	var portrait = TextureRect.new()
	portrait.texture = portrait_tex
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(500, 500) # Make it huge!
	portrait.position = Vector2(-200, vp_size.y - 650)
	portrait.modulate.a = 0.0
	cine_layer.add_child(portrait)

	# 5. The Dialogue Box
	var box_h = 220.0
	var box = ColorRect.new()
	box.color = Color(0.05, 0.05, 0.05, 0.95)
	box.size = Vector2(vp_size.x, box_h)
	box.position = Vector2(0, vp_size.y) # Start off-screen at the bottom
	cine_layer.add_child(box)

	var border = ColorRect.new()
	border.color = Color(0.8, 0.6, 0.2) # Gold border
	border.size = Vector2(vp_size.x, 4)
	box.add_child(border)

	# 6. Speaker Name Label
	var name_lbl = Label.new()
	name_lbl.text = speaker_name
	name_lbl.add_theme_font_size_override("font_size", 42)
	name_lbl.add_theme_color_override("font_color", Color.CYAN)
	name_lbl.position = Vector2(400, 20) # Push text right to make room for portrait
	box.add_child(name_lbl)

	# 7. Dialogue Text
	var text_lbl = RichTextLabel.new()
	text_lbl.bbcode_enabled = true
	text_lbl.size = Vector2(vp_size.x - 450, 100)
	text_lbl.position = Vector2(400, 80)
	box.add_child(text_lbl)

	# Invisible Full-Screen Button to catch clicks to advance text
	var click_catcher = Button.new()
	click_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_catcher.flat = true
	click_catcher.pressed.connect(func(): field.emit_signal("dialogue_advanced"))
	cine_layer.add_child(click_catcher)

	# The Skip Button
	var skip_flag = [false]
	var skip_btn = Button.new()
	skip_btn.text = "Skip >>"
	skip_btn.add_theme_font_size_override("font_size", 24)
	skip_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	skip_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	skip_btn.flat = true
	skip_btn.position = Vector2(vp_size.x - 120, 20)
	skip_btn.pressed.connect(func():
		skip_flag[0] = true
		field.emit_signal("dialogue_advanced")
	)
	cine_layer.add_child(skip_btn)

	# 3. Animate Everything In
	var intro_tw = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	intro_tw.tween_property(dimmer, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(portrait, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(portrait, "position:x", 50.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(box, "position:y", vp_size.y - box_h, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await intro_tw.finished

	# 4. Loop through the Dialogue Lines
	for line in lines:
		if skip_flag[0]:
			break

		text_lbl.text = "[font_size=36]" + line + "[/font_size]"
		text_lbl.visible_ratio = 0.0

		if field.select_sound and field.select_sound.stream != null:
			field.select_sound.pitch_scale = 0.9
			field.select_sound.play()

		var type_speed = line.length() * 0.025
		var type_tw = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		type_tw.tween_property(text_lbl, "visible_ratio", 1.0, type_speed)

		await field.dialogue_advanced
		if skip_flag[0]:
			type_tw.kill()
			break

		# If they clicked while typing, skip to the end of the line
		if type_tw.is_running():
			type_tw.kill()
			text_lbl.visible_ratio = 1.0
			await field.dialogue_advanced
			if skip_flag[0]:
				break

		if field.select_sound and field.select_sound.stream != null:
			field.select_sound.pitch_scale = 1.1
			field.select_sound.play()

	# 5. Animate Everything Out
	skip_btn.visible = false
	var outro_tw = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	outro_tw.tween_property(dimmer, "modulate:a", 0.0, 0.3)
	outro_tw.tween_property(portrait, "modulate:a", 0.0, 0.3)
	outro_tw.tween_property(portrait, "position:x", -200.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	outro_tw.tween_property(box, "position:y", vp_size.y, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await outro_tw.finished

	# ==========================================
	# --- CLEANUP ---
	# ==========================================
	if highlight != null:
		highlight.queue_free()

	cine_layer.queue_free()
	if hide_gameplay_ui:
		restore_ui_visibility_snapshot(field, ui_visibility_snapshot)
	field.get_tree().paused = prev_tree_paused
	if field.main_camera != null:
		field.main_camera.process_mode = prev_cam_process_mode

