extends RefCounted

# Fog-of-war visibility, decor shadowing, alpha smoothing, and fog layer draw — extracted from `BattleField.gd`.
# Line-of-sight trace stays delegated on the field (`_check_line_of_sight` → `BattleFieldGridRangeHelpers`).


static func update_fog_of_war(field) -> void:
	if not field.use_fog_of_war or field.fog_drawer == null:
		return

	for key in field.fow_grid.keys():
		if field.fow_grid[key] == 2:
			field.fow_grid[key] = 1

	var vision_sources = []
	if field.player_container:
		vision_sources += field.player_container.get_children()
	if field.ally_container:
		vision_sources += field.ally_container.get_children()

	for u in vision_sources:
		if not is_instance_valid(u) or u.is_queued_for_deletion() or u.current_hp <= 0:
			continue

		var start = field.get_grid_pos(u)
		var v_range = u.get("vision_range") if u.get("vision_range") != null else field.default_vision_range

		field.fow_grid[start] = 2

		for x in range(start.x - v_range, start.x + v_range + 1):
			for y in range(start.y - v_range, start.y + v_range + 1):
				var target = Vector2i(x, y)

				if target.x >= 0 and target.x < field.GRID_SIZE.x and target.y >= 0 and target.y < field.GRID_SIZE.y:
					if abs(start.x - target.x) + abs(start.y - target.y) <= v_range:
						if field._check_line_of_sight(start, target):
							field.fow_grid[target] = 2

	apply_fow_visibility(field, field.enemy_container)
	apply_fow_visibility(field, field.destructibles_container)
	apply_fow_visibility(field, field.chests_container)
	apply_decor_fow_shadow(field)

	field.fog_drawer.queue_redraw()


static func apply_fow_visibility(field, container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		if not is_instance_valid(child) or child.is_queued_for_deletion():
			continue

		var pos = field.get_grid_pos(child)
		var tile_visible: bool = field.fow_grid.has(pos) and field.fow_grid[pos] == 2
		child.visible = tile_visible


static func decor_base_modulate(field, item: CanvasItem) -> Color:
	var key: int = item.get_instance_id()
	if not field._decor_fow_base_modulates.has(key):
		field._decor_fow_base_modulates[key] = item.modulate
	return field._decor_fow_base_modulates[key]


static func decor_tile_currently_visible(field, node: Node2D) -> bool:
	for tile in field._unit_footprint_tiles(node):
		if field.fow_grid.has(tile) and field.fow_grid[tile] == 2:
			return true
	return false


static func apply_decor_fow_shadow(field) -> void:
	if field.decor_layer == null:
		return
	for child in field.decor_layer.get_children():
		var item: CanvasItem = child as CanvasItem
		if item == null or not is_instance_valid(item) or item.is_queued_for_deletion():
			continue
		var base: Color = decor_base_modulate(field, item)
		var node_2d: Node2D = child as Node2D
		if node_2d == null or decor_tile_currently_visible(field, node_2d):
			item.modulate = base
			continue
		item.modulate = Color(
			base.r * field.DECOR_FOG_SHADOW_TINT.r,
			base.g * field.DECOR_FOG_SHADOW_TINT.g,
			base.b * field.DECOR_FOG_SHADOW_TINT.b,
			base.a * field.DECOR_FOG_SHADOW_TINT.a
		)


static func process_fog(field, delta: float) -> void:
	if not field.use_fog_of_war or field.fog_drawer == null:
		return

	var needs_redraw = false

	for pos in field.fow_grid.keys():
		var state = field.fow_grid[pos]
		var target_a = 0.85

		if state == 1:
			target_a = 0.45
		elif state == 2:
			target_a = 0.00

		var current_a = field.fow_display_alphas.get(pos, 0.85)

		if abs(current_a - target_a) > 0.01:
			var new_a = lerp(current_a, target_a, 10.0 * delta)
			field.fow_display_alphas[pos] = new_a

			field.fow_image.set_pixel(pos.x, pos.y, Color(0.05, 0.05, 0.1, new_a))
			needs_redraw = true

	if needs_redraw:
		field.fow_texture.update(field.fow_image)
		field.fog_drawer.queue_redraw()


static func on_fog_draw(field) -> void:
	if not field.use_fog_of_war or field.fow_texture == null:
		return

	var map_rect = Rect2(0, 0, field.GRID_SIZE.x * field.CELL_SIZE.x, field.GRID_SIZE.y * field.CELL_SIZE.y)
	field.fog_drawer.draw_texture_rect(field.fow_texture, map_rect, false)
