extends RefCounted

# Tactical camera pan/zoom, screen shake, hit-stop, impact offset, fullscreen flash.
# Extracted from `BattleField.gd`.

static func handle_camera_panning(field, delta: float) -> void:
	if field.current_state != field.player_state and field.current_state != field.pre_battle_state:
		return

	var viewport_size = field.get_viewport().get_visible_rect().size
	var mouse_pos = field.get_viewport().get_mouse_position()
	var move_vec_mouse := Vector2.ZERO
	var move_vec_keys := Vector2.ZERO

	if mouse_pos.x < field.edge_margin:
		move_vec_mouse.x = -1
	elif mouse_pos.x > viewport_size.x - field.edge_margin:
		move_vec_mouse.x = 1

	if mouse_pos.y < field.edge_margin:
		move_vec_mouse.y = -1
	elif mouse_pos.y > viewport_size.y - field.edge_margin:
		move_vec_mouse.y = 1

	# Keyboard pan (WASD) mirrors edge-pan behavior for players who prefer keys.
	if Input.is_key_pressed(KEY_A):
		move_vec_keys.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move_vec_keys.x += 1.0
	if Input.is_key_pressed(KEY_W):
		move_vec_keys.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		move_vec_keys.y += 1.0

	var move_vec: Vector2 = move_vec_mouse + move_vec_keys

	if move_vec != Vector2.ZERO:
		field.main_camera.position += move_vec.normalized() * CampaignManager.camera_pan_speed * delta

		var extra_scroll_margin = 400

		var map_limit_x: int = field.GRID_SIZE.x * field.CELL_SIZE.x
		var map_limit_y: int = field.GRID_SIZE.y * field.CELL_SIZE.y

		field.main_camera.position.x = clamp(field.main_camera.position.x, -extra_scroll_margin, map_limit_x + extra_scroll_margin)
		field.main_camera.position.y = clamp(field.main_camera.position.y, -extra_scroll_margin, map_limit_y + extra_scroll_margin)


static func clamp_camera_position(field) -> void:
	if field.main_camera == null:
		return

	var extra_scroll_margin := 400

	var map_limit_x: int = field.GRID_SIZE.x * field.CELL_SIZE.x
	var map_limit_y: int = field.GRID_SIZE.y * field.CELL_SIZE.y

	field.main_camera.position.x = clamp(field.main_camera.position.x, -extra_scroll_margin, map_limit_x + extra_scroll_margin)
	field.main_camera.position.y = clamp(field.main_camera.position.y, -extra_scroll_margin, map_limit_y + extra_scroll_margin)


static func _find_custom_avatar_unit(field) -> Node2D:
	for container in [field.player_container, field.ally_container]:
		if container == null:
			continue
		for child in container.get_children():
			var unit: Node2D = child as Node2D
			if unit == null or not is_instance_valid(unit) or unit.is_queued_for_deletion():
				continue
			if unit.get("is_custom_avatar") == true:
				if unit.get("current_hp") != null and int(unit.current_hp) <= 0:
					continue
				if unit.visible == false:
					continue
				return unit
	return null


## Keyboard QoL: center camera on the custom avatar (Kaelen avatar unit) when requested.
## Returns true if a jump was performed and input should be consumed.
static func try_jump_camera_to_custom_avatar(field, duration: float = 0.22) -> bool:
	if field == null or field.main_camera == null:
		return false
	# Keep deployment Space/Enter behavior unchanged.
	if field.current_state == field.pre_battle_state:
		return false
	var avatar: Node2D = _find_custom_avatar_unit(field)
	if avatar == null:
		return false

	var target_cam_pos: Vector2 = avatar.global_position + Vector2(32, 32)
	if field.main_camera.anchor_mode == Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT:
		var vp_size: Vector2 = field.get_viewport_rect().size
		target_cam_pos -= (vp_size * 0.5) / field.main_camera.zoom

	var tw: Tween = field.create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(field.main_camera, "global_position", target_cam_pos, duration)
	tw.finished.connect(func() -> void:
		clamp_camera_position(field)
	)
	return true


func apply_camera_zoom(field, direction: int) -> void:
	if field.main_camera == null:
		return

	if field._hit_stop_active:
		return

	var old_target: float = field._camera_zoom_target
	field._camera_zoom_target = clampf(
		field._camera_zoom_target + field.zoom_step * float(direction),
		field.min_zoom,
		field.max_zoom
	)

	if is_equal_approx(old_target, field._camera_zoom_target):
		return

	var before_mouse_world: Vector2 = Vector2.ZERO
	if field.zoom_to_cursor:
		before_mouse_world = field.get_global_mouse_position()

	if field._camera_zoom_tween != null and field._camera_zoom_tween.is_valid():
		field._camera_zoom_tween.kill()

	field._camera_zoom_tween = field.create_tween()
	field._camera_zoom_tween.set_parallel(true)
	field._camera_zoom_tween.set_trans(Tween.TRANS_SINE)
	field._camera_zoom_tween.set_ease(Tween.EASE_OUT)

	field._camera_zoom_tween.tween_property(
		field.main_camera,
		"zoom",
		Vector2(field._camera_zoom_target, field._camera_zoom_target),
		0.12
	)

	if field.zoom_to_cursor:
		await field.get_tree().process_frame
		var after_mouse_world: Vector2 = field.get_global_mouse_position()
		field.main_camera.global_position += (before_mouse_world - after_mouse_world)
		clamp_camera_position(field)

	field._camera_zoom_tween.finished.connect(func():
		clamp_camera_position(field)
	)


static func screen_shake(field, intensity: float = 12.0, duration: float = 0.4) -> void:
	if field.main_camera == null:
		return

	if field._screen_shake_tween:
		field._screen_shake_tween.kill()

	field.main_camera.offset = Vector2.ZERO

	field._screen_shake_tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	var steps: int = 8
	var step_time: float = duration / float(steps)

	for i in range(steps):
		var random_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		field._screen_shake_tween.tween_property(field.main_camera, "offset", random_offset, step_time)

	field._screen_shake_tween.tween_property(field.main_camera, "offset", Vector2.ZERO, step_time)


func do_hit_stop(field, freeze_duration: float, slow_scale: float = 0.12, slow_duration: float = 0.10) -> void:
	if field._hit_stop_active:
		return

	field._hit_stop_active = true
	var old_scale: float = Engine.time_scale

	Engine.time_scale = 0.01
	await field.get_tree().create_timer(freeze_duration, true, false, true).timeout

	Engine.time_scale = slow_scale
	await field.get_tree().create_timer(slow_duration, true, false, true).timeout

	Engine.time_scale = old_scale
	field._hit_stop_active = false


static func start_impact_camera(field, focus_world: Vector2, _zoom_mult: float, snap_t: float, restore_t: float) -> void:
	if field.main_camera == null:
		return

	if field._impact_snap_tween:
		field._impact_snap_tween.kill()
	if field._impact_restore_tween:
		field._impact_restore_tween.kill()

	var old_offset: Vector2 = field.main_camera.offset
	var camera_center: Vector2 = field.main_camera.get_screen_center_position()
	var dir_to_impact: Vector2 = focus_world - camera_center

	var punch_offset := Vector2.ZERO
	if dir_to_impact.length() > 0.001:
		var punch_strength: float = clamp(dir_to_impact.length() * 0.08, 10.0, 24.0)
		punch_offset = dir_to_impact.normalized() * punch_strength

	field._impact_snap_tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	field._impact_snap_tween.tween_property(field.main_camera, "offset", old_offset + punch_offset, snap_t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var restore_offset: Vector2 = old_offset
	field._impact_snap_tween.finished.connect(func():
		field._impact_restore_tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		field._impact_restore_tween.tween_property(field.main_camera, "offset", restore_offset, restore_t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)


static func spawn_fullscreen_impact_flash(field, color: Color, alpha: float, duration: float) -> void:
	var flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = color
	flash.modulate.a = 0.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.get_node("UI").add_child(flash)

	var tw = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(flash, "modulate:a", alpha, duration * 0.16)
	tw.tween_property(flash, "modulate:a", alpha * 0.35, duration * 0.18)
	tw.tween_property(flash, "modulate:a", 0.0, duration * 0.66)
	tw.finished.connect(flash.queue_free)
