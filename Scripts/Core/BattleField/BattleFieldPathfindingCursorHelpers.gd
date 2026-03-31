extends RefCounted

# Pathfinding/cursor integration helpers extracted from `BattleField.gd`.
# These helpers delegate by calling back into `field` for any remaining
# internal functions/variables so we keep scene wiring unchanged.

static func is_neutral_inspect_unit(field, unit: Node2D) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	var data_variant: Variant = unit.get("data")
	var data_res: Resource = data_variant as Resource if data_variant is Resource else null
	if data_res == null:
		return false
	var res_path: String = String(data_res.resource_path)
	if res_path.contains("/Resources/Units/NeutralAllies/"):
		return true
	if res_path.contains("/Resources/Units/NeutralFactionAllies/"):
		return true
	return false


static func get_inspect_cursor_tint(field, unit: Node2D) -> Color:
	if unit == null or not is_instance_valid(unit):
		return Color(1.0, 0.85, 0.34, 1.0)
	if is_neutral_inspect_unit(field, unit):
		return Color(0.36, 0.96, 0.50, 1.0)

	var is_flagged_enemy: bool = unit.get("is_enemy") == true
	if field._is_friendly_unit_on_field(unit) or unit.get_parent() == field.ally_container or unit.get("is_enemy") == false:
		return Color(0.36, 0.96, 0.50, 1.0)
	if is_flagged_enemy or unit.get_parent() == field.enemy_container:
		return Color(1.0, 0.28, 0.28, 1.0)
	return Color(1.0, 0.85, 0.34, 1.0)


static func set_cursor_state(field, cursor_node: Node, state_name: String) -> void:
	if cursor_node == null or not is_instance_valid(cursor_node):
		return
	if cursor_node.has_method("set_state_by_name"):
		cursor_node.call("set_state_by_name", state_name)


static func apply_cursor_accessibility_settings(field) -> void:
	var cursor_scale: float = CampaignManager.get_cursor_scale_float()
	var use_high_contrast: bool = CampaignManager.interface_cursor_high_contrast
	if is_instance_valid(field.cursor) and field.cursor.has_method("apply_accessibility"):
		field.cursor.call("apply_accessibility", cursor_scale, use_high_contrast)
	if is_instance_valid(field.target_cursor) and field.target_cursor.has_method("apply_accessibility"):
		field.target_cursor.call("apply_accessibility", cursor_scale, use_high_contrast)


static func update_cursor_pos(field) -> void:
	var m = field.get_global_mouse_position()
	var new_grid_pos = Vector2i(
		clamp(m.x / field.CELL_SIZE.x, 0, field.GRID_SIZE.x - 1),
		clamp(m.y / field.CELL_SIZE.y, 0, field.GRID_SIZE.y - 1)
	)

	if new_grid_pos != field.cursor_grid_pos:
		field.cursor_grid_pos = new_grid_pos
		var target_pos = Vector2(field.cursor_grid_pos.x * field.CELL_SIZE.x, field.cursor_grid_pos.y * field.CELL_SIZE.y)
		if field.hover_glow.position != target_pos:
			field.hover_glow.position = target_pos
			var tween = field.create_tween()
			tween.tween_property(field.cursor, "position", target_pos, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	update_locked_inspect_cursor(field)


static func update_cursor_color(field) -> void:
	# 1. Start by resetting to the default white color every frame
	field.cursor_sprite.modulate = Color.WHITE
	if is_instance_valid(field.hover_glow):
		field.hover_glow.modulate = Color(1.0, 1.0, 1.0, 1.0)

	var cursor_state_name: String = "DEFAULT"
	var occupant_on_cursor: Node2D = field.get_occupant_at(field.cursor_grid_pos)

	if is_instance_valid(field.cursor) and field.cursor.has_method("set_occluded"):
		field.cursor.call("set_occluded", occupant_on_cursor != null)

	# 2. Check if it is the player's turn and a unit is currently selected
	if field.current_state == field.player_state and field.player_state.active_unit != null:
		# 3. Check if the tile the cursor is hovering over is within attack range
		if field.attackable_tiles.has(field.cursor_grid_pos):
			# 4. Check if there is actually an enemy on that specific tile
			var unit_under_cursor = field.get_enemy_at(field.cursor_grid_pos)
			if unit_under_cursor != null:
				# Tint the cursor red
				field.cursor_sprite.modulate = Color(1.0, 0.3, 0.3)
				if is_instance_valid(field.hover_glow):
					field.hover_glow.modulate = Color(1.0, 0.35, 0.35, 1.0)
				cursor_state_name = "ATTACK"
				set_cursor_state(field, field.cursor, cursor_state_name)
				return

		# Valid move destination (blue range): cyan cursor + glow reads clearly vs neutral tiles
		if (not field.player_state.active_unit.has_moved or field.player_state.active_unit.get("in_canto_phase") == true) and field.reachable_tiles.has(field.cursor_grid_pos):
			field.cursor_sprite.modulate = Color(0.5, 0.92, 1.0)
			if is_instance_valid(field.hover_glow):
				field.hover_glow.modulate = Color(0.45, 0.88, 1.0, 0.95)
			cursor_state_name = "MOVE"
		else:
			cursor_state_name = "INVALID"

	set_cursor_state(field, field.cursor, cursor_state_name)


static func update_locked_inspect_cursor(field) -> void:
	if not is_instance_valid(field.target_cursor):
		return

	if field.player_state != null and field.player_state.is_forecasting:
		return

	var locked_inspect_unit: Node2D = field._get_locked_inspect_unit()
	if locked_inspect_unit == null:
		if is_instance_valid(field.target_cursor_sprite):
			field.target_cursor_sprite.modulate = Color.WHITE
		set_cursor_state(field, field.target_cursor, "DEFAULT")
		if is_instance_valid(field.target_cursor) and field.target_cursor.has_method("set_occluded"):
			field.target_cursor.call("set_occluded", false)
		field.target_cursor.visible = false
		return

	field.target_cursor.z_index = 82
	field.target_cursor.global_position = locked_inspect_unit.global_position

	var tint: Color = get_inspect_cursor_tint(field, locked_inspect_unit)
	field.target_cursor.modulate = tint
	if is_instance_valid(field.target_cursor_sprite):
		field.target_cursor_sprite.modulate = tint

	set_cursor_state(field, field.target_cursor, "INSPECT")
	if is_instance_valid(field.target_cursor) and field.target_cursor.has_method("set_occluded"):
		field.target_cursor.call("set_occluded", true)
	field.target_cursor.visible = true


static func draw_preview_path(field) -> void:
	if not CampaignManager.battle_show_path_preview:
		field._hide_path_preview_visuals()
		return
	if field.path_line == null:
		return

	field._path_preview_tick_world.clear()
	field._set_path_pulse(false)

	if field.current_state != field.player_state or field.player_state == null or field.player_state.active_unit == null:
		field._hide_path_preview_visuals()
		return

	var active: Node2D = field.player_state.active_unit
	if active.has_moved and active.get("in_canto_phase") != true:
		field._hide_path_preview_visuals()
		return

	var start: Vector2i = field.get_grid_pos(active)
	var path: Array = field.get_unit_path(active, start, field.cursor_grid_pos)
	if path.size() <= 1:
		field._hide_path_preview_visuals()
		return

	var move_range: float = float(active.canto_move_budget) if active.get("in_canto_phase") == true else float(active.move_range)
	var path_cost: float = field.get_path_move_cost(path, active)
	var valid_path: bool = (path_cost <= move_range) and field.reachable_tiles.has(field.cursor_grid_pos)
	var ghost: bool = (not valid_path) and CampaignManager.battle_path_invalid_ghost

	if not valid_path and not ghost:
		field._hide_path_preview_visuals()
		return

	var poly: PackedVector2Array = field._grid_path_to_world_polyline(path, active)
	if field.path_line_under != null:
		field.path_line_under.clear_points()
		for pt in poly:
			field.path_line_under.add_point(pt)

	field.path_line.clear_points()
	for pt in poly:
		field.path_line.add_point(pt)

	field.path_line.joint_mode = Line2D.LINE_JOINT_ROUND
	field.path_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	field.path_line.end_cap_mode = Line2D.LINE_CAP_ROUND

	if field.path_line_under != null:
		field.path_line_under.joint_mode = field.path_line.joint_mode
		field.path_line_under.begin_cap_mode = field.path_line.begin_cap_mode
		field.path_line_under.end_cap_mode = field.path_line.end_cap_mode

	field._gather_path_cost_ticks(path, active)

	var canto_move: bool = active.get("in_canto_phase") == true
	field._apply_path_preview_style(ghost, canto_move)

	field.path_line.visible = true
	if field.path_line_under != null:
		field.path_line_under.visible = (CampaignManager.battle_path_style != CampaignManager.BATTLE_PATH_STYLE_MINIMAL)

	field._update_path_endpoint_marker(path, ghost, canto_move)

	if CampaignManager.battle_path_preview_pulse:
		field._set_path_pulse(true)

	if field.path_preview_ticks != null:
		field.path_preview_ticks.queue_redraw()

	field.queue_redraw()


static func get_path_preview_tick_positions_for_draw(field) -> Array[Vector2]:
	if not CampaignManager.battle_show_path_preview or not CampaignManager.battle_path_cost_ticks:
		return []
	return field._path_preview_tick_world.duplicate()

