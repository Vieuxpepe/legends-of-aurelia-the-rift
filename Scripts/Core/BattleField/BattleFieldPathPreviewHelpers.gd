extends RefCounted

# Path preview runtime visuals + move-cost tick geometry. Extracted from `BattleField.gd`.
# `field` owns nodes, astar, and path-preview shader/material state.

static func init_path_preview_nodes(field) -> void:
	for ln in [field.path_line_under, field.path_line]:
		if ln == null:
			continue
		ln.z_as_relative = false
		ln.joint_mode = Line2D.LINE_JOINT_ROUND
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.end_cap_mode = Line2D.LINE_CAP_ROUND
		ln.antialiased = true
	if field.path_line_under != null:
		field.path_line_under.z_index = field.PATH_PREVIEW_Z
		field.path_line_under.width = field.PATH_PREVIEW_UNDER_WIDTH
	if field.path_line != null:
		field.path_line.z_index = field.PATH_PREVIEW_Z + 1
		field.path_line.width = field.PATH_PREVIEW_FG_WIDTH
	if field.path_preview_ticks != null:
		field.path_preview_ticks.z_as_relative = false
		field.path_preview_ticks.z_index = field.PATH_PREVIEW_Z + 3
	if field.path_end_marker != null:
		field.path_end_marker.z_as_relative = false
		field.path_end_marker.z_index = field.PATH_PREVIEW_Z + 2
		var diamond: Polygon2D = field.path_end_marker.get_node_or_null("Diamond") as Polygon2D
		if diamond == null:
			for c in field.path_end_marker.get_children():
				if c is Polygon2D:
					diamond = c as Polygon2D
					break
		if diamond != null:
			diamond.polygon = PackedVector2Array([Vector2(0, -9), Vector2(11, 0), Vector2(0, 9), Vector2(-11, 0)])


static func hide_path_preview_visuals(field) -> void:
	field._path_preview_tick_world.clear()
	set_path_pulse(field, false)
	if field.path_line_under != null:
		field.path_line_under.clear_points()
		field.path_line_under.visible = false
	if field.path_line != null:
		field.path_line.clear_points()
		field.path_line.visible = false
		field.path_line.material = null
	if field.path_preview_ticks != null:
		field.path_preview_ticks.queue_redraw()
	if field.path_end_marker != null:
		field.path_end_marker.visible = false


static func cell_center_world(field, cell: Vector2i) -> Vector2:
	return Vector2(
		float(cell.x * field.CELL_SIZE.x) + float(field.CELL_SIZE.x) * 0.5,
		float(cell.y * field.CELL_SIZE.y) + float(field.CELL_SIZE.y) * 0.5
	)


static func single_step_enter_cost(field, unit: Node2D, cell: Vector2i) -> float:
	if unit == null:
		return 1.0
	if unit.get("move_type") == 2:
		return 1.0
	var base_cost: float = field.astar.get_point_weight_scale(cell)
	if unit.get("move_type") == 1 and base_cost > 1.0:
		base_cost += 1.0
	return base_cost


static func chamfer_world_polyline(pts: PackedVector2Array, inset: float) -> PackedVector2Array:
	if pts.size() < 3 or inset <= 0.0:
		return pts
	var out: PackedVector2Array = PackedVector2Array()
	out.append(pts[0])
	for i in range(1, pts.size() - 1):
		var prev: Vector2 = pts[i - 1]
		var curr: Vector2 = pts[i]
		var next: Vector2 = pts[i + 1]
		var v1: Vector2 = curr - prev
		var v2: Vector2 = next - curr
		var len1: float = v1.length()
		var len2: float = v2.length()
		if len1 < 0.001 or len2 < 0.001:
			out.append(curr)
			continue
		v1 /= len1
		v2 /= len2
		if absf(v1.dot(v2)) > 0.995:
			out.append(curr)
			continue
		var r: float = minf(inset, minf(len1 * 0.48, len2 * 0.48))
		out.append(curr - v1 * r)
		out.append(curr + v2 * r)
	out.append(pts[pts.size() - 1])
	return out


static func grid_path_to_world_polyline(field, path: Array, unit: Node2D) -> PackedVector2Array:
	var raw: PackedVector2Array = PackedVector2Array()
	for i in range(path.size()):
		raw.append(cell_center_world(field, path[i] as Vector2i))
	var smooth_level: int = CampaignManager.battle_path_corner_smoothing
	var inset: float = 0.0
	if smooth_level == 1:
		inset = field.PATH_PREVIEW_CORNER_INSET_LOW * (float(field.CELL_SIZE.x) / 64.0)
	elif smooth_level >= 2:
		inset = field.PATH_PREVIEW_CORNER_INSET_HIGH * (float(field.CELL_SIZE.x) / 64.0)
	return chamfer_world_polyline(raw, inset)


static func gather_path_cost_ticks(field, path: Array, unit: Node2D) -> void:
	field._path_preview_tick_world.clear()
	if not CampaignManager.battle_path_cost_ticks or path.size() < 2:
		return
	var cum: float = 0.0
	var next_tick_threshold: int = 1
	for i in range(1, path.size()):
		var cell: Vector2i = path[i] as Vector2i
		var prev_cell: Vector2i = path[i - 1] as Vector2i
		var step_cost: float = single_step_enter_cost(field, unit, cell)
		var prev_cum: float = cum
		cum += step_cost
		var p0: Vector2 = cell_center_world(field, prev_cell)
		var p1: Vector2 = cell_center_world(field, cell)
		while float(next_tick_threshold) <= cum + 0.001:
			var denom: float = cum - prev_cum
			var t: float = 1.0 if denom <= 0.0001 else clampf((float(next_tick_threshold) - prev_cum) / denom, 0.0, 1.0)
			field._path_preview_tick_world.append(p0.lerp(p1, t))
			next_tick_threshold += 1


static func ensure_path_fg_dash_material(field) -> ShaderMaterial:
	if field._path_fg_dash_material == null:
		field._path_fg_dash_material = ShaderMaterial.new()
		field._path_fg_dash_material.shader = field.PATH_PREVIEW_DASH_SHADER
	return field._path_fg_dash_material


static func apply_path_preview_style(field, ghost: bool, canto: bool) -> void:
	var style: int = CampaignManager.battle_path_style
	var minimal: bool = style == CampaignManager.BATTLE_PATH_STYLE_MINIMAL
	var dashed: bool = style == CampaignManager.BATTLE_PATH_STYLE_DASHED

	var fg := Color(0.82, 0.96, 1.0, 1.0)
	var under := Color(0.03, 0.05, 0.12, 0.92)
	var scroll_mult: float = 1.0
	if canto:
		fg = Color(1.0, 0.92, 0.55, 1.0)
		under = Color(0.14, 0.09, 0.02, 0.9)
		scroll_mult = 1.45
	if ghost:
		fg = Color(1.0, 0.45, 0.42, 0.55)
		under = Color(0.22, 0.04, 0.04, 0.6)
		scroll_mult = 1.65

	if field.path_line_under != null:
		field.path_line_under.default_color = under
		field.path_line_under.width = field.PATH_PREVIEW_UNDER_WIDTH
	if field.path_line == null:
		return

	if minimal:
		field.path_line.width = maxf(field.PATH_PREVIEW_FG_WIDTH, 5.5)
	else:
		field.path_line.width = field.PATH_PREVIEW_FG_WIDTH

	if dashed and not minimal:
		field.path_line.default_color = Color.WHITE
		var smat: ShaderMaterial = ensure_path_fg_dash_material(field)
		smat.set_shader_parameter("line_color", fg)
		smat.set_shader_parameter("scroll_speed", 1.15 * scroll_mult)
		smat.set_shader_parameter("dash_repeat", 12.0 * (1.1 if canto else 1.0))
		field.path_line.material = smat
	else:
		field.path_line.material = null
		field.path_line.default_color = fg


static func update_path_endpoint_marker(field, path: Array, ghost: bool, canto: bool) -> void:
	if field.path_end_marker == null:
		return
	if not CampaignManager.battle_path_endpoint_marker:
		field.path_end_marker.visible = false
		return
	var diamond: Polygon2D = field.path_end_marker.get_node_or_null("Diamond") as Polygon2D
	if diamond == null:
		for c in field.path_end_marker.get_children():
			if c is Polygon2D:
				diamond = c as Polygon2D
				break
	field.path_end_marker.visible = true
	field.path_end_marker.position = cell_center_world(field, path[path.size() - 1] as Vector2i)
	var col := Color(0.9, 0.98, 1.0, 0.92)
	if canto:
		col = Color(1.0, 0.95, 0.55, 0.95)
	if ghost:
		col = Color(1.0, 0.5, 0.48, 0.65)
	if diamond != null:
		diamond.color = col


static func reset_path_pulse_visuals(field) -> void:
	if field.path_line != null:
		var c: Color = field.path_line.modulate
		c.a = 1.0
		field.path_line.modulate = c
	if field.path_line_under != null:
		var cu: Color = field.path_line_under.modulate
		cu.a = 1.0
		field.path_line_under.modulate = cu


static func set_path_pulse(field, active: bool) -> void:
	if not active:
		if field._path_pulse_tween != null and field._path_pulse_tween.is_valid():
			field._path_pulse_tween.kill()
		field._path_pulse_active = false
		reset_path_pulse_visuals(field)
		return

	if field.path_line == null:
		return
	if field._path_pulse_active:
		return
	field._path_pulse_active = true
	if field._path_pulse_tween != null and field._path_pulse_tween.is_valid():
		field._path_pulse_tween.kill()

	var fg_w_base: float = field.path_line.width
	var un_w_base: float = field.path_line_under.width if field.path_line_under != null else fg_w_base

	var pm: Color = field.path_line.modulate
	pm.a = field.PATH_ALPHA_MIN
	field.path_line.modulate = pm
	if field.path_line_under != null:
		var pu: Color = field.path_line_under.modulate
		pu.a = field.PATH_ALPHA_MIN
		field.path_line_under.modulate = pu

	var apply_pulse: Callable = func(alpha: float) -> void:
		field.path_line.modulate.a = alpha
		if field.path_line_under != null:
			field.path_line_under.modulate.a = alpha
		var span: float = field.PATH_ALPHA_MAX - field.PATH_ALPHA_MIN
		var u: float = 0.0 if span <= 0.0001 else clampf((alpha - field.PATH_ALPHA_MIN) / span, 0.0, 1.0)
		field.path_line.width = fg_w_base + field.PATH_PREVIEW_PULSE_W_FG * u
		if field.path_line_under != null:
			field.path_line_under.width = un_w_base + field.PATH_PREVIEW_PULSE_W_UNDER * u

	field._path_pulse_tween = field.create_tween()
	field._path_pulse_tween.set_loops()
	field._path_pulse_tween.tween_method(apply_pulse, field.PATH_ALPHA_MIN, field.PATH_ALPHA_MAX, field.PATH_PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	field._path_pulse_tween.tween_method(apply_pulse, field.PATH_ALPHA_MAX, field.PATH_ALPHA_MIN, field.PATH_PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
