extends RefCounted
class_name DetailedUnitInfoRuntimeHelpers

## Tactical unit info panel (bottom bar): primary HP/Poise/XP rows, stat mini-bars, tier FX, layout, refresh, animation.
static func unit_info_primary_bar_definitions() -> Array[Dictionary]:
	return [
		{"key": "hp", "label": "HP"},
		{"key": "poise", "label": "POISE"},
		{"key": "xp", "label": "XP"},
	]

static func unit_info_primary_fill_color(field, bar_key: String, current_value: int, max_value: int) -> Color:
	match bar_key:
		"hp":
			return field._forecast_hp_fill_color(current_value, max_value)
		"poise":
			if max_value <= 0:
				return field.TACTICAL_UI_TEXT_MUTED
			var ratio := clampf(float(current_value) / float(max_value), 0.0, 1.0)
			if ratio >= 0.67:
				return Color(0.48, 0.90, 1.0, 1.0)
			if ratio >= 0.34:
				return Color(0.88, 0.78, 0.30, 1.0)
			return Color(0.93, 0.42, 0.30, 1.0)
		"xp":
			return Color(0.96, 0.82, 0.36, 1.0)
		_:
			return field.TACTICAL_UI_ACCENT_SOFT

static func style_unit_info_primary_bar(_field, bar: ProgressBar, fill: Color, bar_key: String = "") -> void:
	if bar == null:
		return
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.clip_contents = true
	var radius := 5
	var bg_border := Color(0.38, 0.33, 0.22, 0.92)
	match bar_key:
		"hp":
			radius = 7
			bg_border = Color(0.54, 0.28, 0.22, 0.94)
		"poise":
			radius = 3
			bg_border = Color(0.22, 0.46, 0.56, 0.94)
		"xp":
			radius = 2
			bg_border = Color(0.56, 0.46, 0.18, 0.94)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.06, 0.05, 0.98)
	bg_style.border_color = bg_border
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(radius)
	bg_style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	bg_style.shadow_size = 2

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.border_color = fill.lightened(0.18)
	fill_style.set_border_width_all(1)
	fill_style.set_corner_radius_all(radius)

	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)

static func attach_unit_info_bar_sheen(_field, bar: ProgressBar) -> ColorRect:
	if bar == null:
		return null
	bar.clip_contents = true
	var sheen := bar.get_node_or_null("Sheen") as ColorRect
	if sheen == null:
		sheen = ColorRect.new()
		sheen.name = "Sheen"
		sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(sheen)
	sheen.color = Color(1.0, 1.0, 1.0, 0.14)
	sheen.size = Vector2(34, 20)
	sheen.position = Vector2(-52, -6)
	sheen.rotation_degrees = 14.0
	sheen.modulate.a = 0.0
	return sheen

static func animate_unit_info_bar_sheen(field, sheen: ColorRect, bar: ProgressBar, delay: float = 0.0) -> void:
	if sheen == null or bar == null:
		return
	var bar_width: float = max(bar.size.x, bar.custom_minimum_size.x, 120.0)
	sheen.position = Vector2(-52, -6)
	sheen.modulate.a = 0.0
	var tw: Tween = field.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(sheen, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(sheen, "position:x", bar_width + 18.0, 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(sheen, "modulate:a", 0.0, 0.12)

static func ensure_unit_info_primary_widgets(field) -> Control:
	if field.unit_info_panel == null:
		return null
	var root := field.unit_info_panel.get_node_or_null("UnitPrimaryBarsRoot") as Control
	if root == null:
		root = Control.new()
		root.name = "UnitPrimaryBarsRoot"
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		field.unit_info_panel.add_child(root)

	for bar_def in unit_info_primary_bar_definitions():
		var bar_key: String = str(bar_def.get("key", ""))
		if bar_key == "":
			continue
		var row_name := "PrimaryBlock_%s" % bar_key
		var block := root.get_node_or_null(row_name) as Panel
		if block == null:
			block = Panel.new()
			block.name = row_name
			block.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(block)
		field._style_tactical_panel(block, Color(0.10, 0.09, 0.07, 0.82), Color(0.36, 0.31, 0.20, 0.72), 1, 6)

		var name_label := block.get_node_or_null("Name") as Label
		if name_label == null:
			name_label = Label.new()
			name_label.name = "Name"
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.add_child(name_label)
		var value_label := block.get_node_or_null("Value") as Label
		if value_label == null:
			value_label = Label.new()
			value_label.name = "Value"
			value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.add_child(value_label)
		var value_chip := block.get_node_or_null("ValueChip") as Panel
		if value_chip == null:
			value_chip = Panel.new()
			value_chip.name = "ValueChip"
			value_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.add_child(value_chip)
		var bar := block.get_node_or_null("Bar") as ProgressBar
		if bar == null:
			bar = ProgressBar.new()
			bar.name = "Bar"
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.add_child(bar)
		var sheen := attach_unit_info_bar_sheen(field, bar)
		value_chip.z_index = 1
		value_label.z_index = 2
		block.move_child(value_chip, max(0, block.get_child_count() - 2))
		block.move_child(value_label, block.get_child_count() - 1)

		field._unit_info_primary_widgets[bar_key] = {
			"panel": block,
			"name": name_label,
			"value_chip": value_chip,
			"value": value_label,
			"bar": bar,
			"sheen": sheen,
		}

	layout_unit_info_primary_widgets(field)
	return root

static func layout_unit_info_primary_widgets(field) -> void:
	var root: Control = null
	if field.unit_info_panel != null:
		root = field.unit_info_panel.get_node_or_null("UnitPrimaryBarsRoot") as Control
	if root == null:
		return
	root.position = Vector2(16, 60)
	root.size = Vector2(210, 78)
	var block_height := 24.0
	var gap_y := 3.0
	var defs := unit_info_primary_bar_definitions()
	for idx in range(defs.size()):
		var bar_key: String = str(defs[idx].get("key", ""))
		if not field._unit_info_primary_widgets.has(bar_key):
			continue
		var widgets: Dictionary = field._unit_info_primary_widgets[bar_key]
		var panel := widgets.get("panel") as Panel
		var name_label := widgets.get("name") as Label
		var value_chip := widgets.get("value_chip") as Panel
		var value_label := widgets.get("value") as Label
		var bar := widgets.get("bar") as ProgressBar
		var pos := Vector2(0, idx * (block_height + gap_y))
		if panel != null:
			panel.position = pos
			panel.size = Vector2(210, block_height)
		if name_label != null:
			name_label.position = Vector2(4, 0)
			name_label.size = Vector2(42, 11)
			name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			field._style_tactical_label(name_label, field.TACTICAL_UI_TEXT_MUTED, 10, 2)
		if value_chip != null:
			value_chip.position = Vector2(138, 0)
			value_chip.size = Vector2(68, 13)
			field._style_tactical_panel(value_chip, Color(0.10, 0.09, 0.07, 0.98), Color(0.34, 0.30, 0.22, 0.86), 1, 4)
		if value_label != null:
			value_label.position = Vector2(144, 0)
			value_label.size = Vector2(56, 13)
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			field._style_tactical_label(value_label, field.TACTICAL_UI_TEXT, 13, 1)
		if bar != null:
			bar.min_value = 0.0
			bar.max_value = 100.0
			bar.position = Vector2(4, 15)
			bar.size = Vector2(202, 8)

static func set_unit_info_primary_widgets_visible(field, visible: bool) -> void:
	var root: Control = null
	if field.unit_info_panel != null:
		root = field.unit_info_panel.get_node_or_null("UnitPrimaryBarsRoot") as Control
	if not visible and field._unit_info_primary_anim_tween != null:
		field._unit_info_primary_anim_tween.kill()
		field._unit_info_primary_anim_tween = null
		field._unit_info_primary_animating = false
		field._unit_info_primary_anim_source_id = -1
	if root != null:
		root.visible = visible

static func animate_unit_info_primary_widgets_in(field, target_values: Dictionary, source_id: int) -> void:
	if field._unit_info_primary_anim_tween != null:
		field._unit_info_primary_anim_tween.kill()
	field._unit_info_primary_anim_tween = field.create_tween().set_parallel(true)
	field._unit_info_primary_animating = true
	field._unit_info_primary_anim_source_id = source_id
	var defs := unit_info_primary_bar_definitions()
	for idx in range(defs.size()):
		var bar_key: String = str(defs[idx].get("key", ""))
		if not field._unit_info_primary_widgets.has(bar_key):
			continue
		var widgets: Dictionary = field._unit_info_primary_widgets[bar_key]
		var panel := widgets.get("panel") as Panel
		var bar := widgets.get("bar") as ProgressBar
		var _sheen := widgets.get("sheen") as ColorRect
		var delay := float(idx) * 0.045
		if panel != null:
			panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
			field._unit_info_primary_anim_tween.tween_property(panel, "modulate", Color.WHITE, 0.18).set_delay(delay)
		if bar != null:
			bar.value = 0.0
			field._unit_info_primary_anim_tween.tween_property(bar, "value", float(target_values.get(bar_key, 0.0)), 0.28).set_delay(delay)
		if _sheen != null:
			animate_unit_info_bar_sheen(field, _sheen, bar, delay + 0.06)
	field._unit_info_primary_anim_tween.finished.connect(func():
		field._unit_info_primary_anim_tween = null
		field._unit_info_primary_animating = false
		field._unit_info_primary_anim_source_id = -1
	, CONNECT_ONE_SHOT)

static func refresh_unit_info_primary_widgets(field, primary_values: Dictionary, animate: bool = false, source_id: int = -1) -> void:
	var root := ensure_unit_info_primary_widgets(field)
	if root == null:
		return
	root.visible = true
	var display_values: Dictionary = {}
	for bar_def in unit_info_primary_bar_definitions():
		var bar_key: String = str(bar_def.get("key", ""))
		if not field._unit_info_primary_widgets.has(bar_key):
			continue
		var widgets: Dictionary = field._unit_info_primary_widgets[bar_key]
		var panel := widgets.get("panel") as Panel
		var name_label := widgets.get("name") as Label
		var value_chip := widgets.get("value_chip") as Panel
		var value_label := widgets.get("value") as Label
		var bar := widgets.get("bar") as ProgressBar
		var _sheen := widgets.get("sheen") as ColorRect
		var row_data: Dictionary = primary_values.get(bar_key, {})
		var current_value: int = int(row_data.get("current", 0))
		var max_value: int = max(1, int(row_data.get("max", 1)))
		var display_text: String = str(row_data.get("text", "%d/%d" % [current_value, max_value]))
		var fill_color := unit_info_primary_fill_color(field, bar_key, current_value, max_value)
		display_values[bar_key] = float(clampf(float(current_value), 0.0, float(max_value)))
		if name_label != null:
			name_label.text = str(bar_def.get("label", bar_key))
			field._style_tactical_label(name_label, fill_color, 10, 2)
		if panel != null:
			var panel_border := Color(
				min(fill_color.r + 0.08, 1.0),
				min(fill_color.g + 0.08, 1.0),
				min(fill_color.b + 0.08, 1.0),
				0.72
			)
			var panel_fill := Color(0.10, 0.09, 0.07, 0.84)
			var panel_radius := 6
			match bar_key:
				"hp":
					panel_radius = 8
				"poise":
					panel_radius = 5
				"xp":
					panel_radius = 4
			field._style_tactical_panel(panel, panel_fill, panel_border, 1, panel_radius)
		if value_chip != null:
			var chip_fill := Color(0.10, 0.09, 0.07, 0.98)
			var chip_border := Color(
				min(fill_color.r + 0.12, 1.0),
				min(fill_color.g + 0.12, 1.0),
				min(fill_color.b + 0.12, 1.0),
				0.92
			)
			field._style_tactical_panel(value_chip, chip_fill, chip_border, 1, 4)
		if value_label != null:
			value_label.text = display_text
			field._style_tactical_label(value_label, field.TACTICAL_UI_TEXT, 13, 2)
		if bar != null:
			bar.max_value = float(max_value)
			if not animate and not (field._unit_info_primary_animating and field._unit_info_primary_anim_source_id == source_id):
				bar.value = display_values[bar_key]
			style_unit_info_primary_bar(field, bar, fill_color, bar_key)
	if animate:
		animate_unit_info_primary_widgets_in(field, display_values, source_id)

static func unit_info_stat_tier_index(_field, stat_value: int) -> int:
	if stat_value >= 200:
		return 4
	if stat_value >= 150:
		return 3
	if stat_value >= 100:
		return 2
	if stat_value >= 50:
		return 1
	return 0

static func unit_info_stat_definitions() -> Array[Dictionary]:
	return [
		{"key": "strength", "label": "STR"},
		{"key": "magic", "label": "MAG"},
		{"key": "defense", "label": "DEF"},
		{"key": "resistance", "label": "RES"},
		{"key": "speed", "label": "SPD"},
		{"key": "agility", "label": "AGI"},
	]

## Same tints as the bottom-bar stat mini-bars ([method unit_info_stat_fill_color]); usable without a [BattleField] instance (e.g. Field Notes).
static func unit_info_stat_fill_color_standalone(stat_key: String, stat_value: int) -> Color:
	if stat_value >= 200:
		return Color(0.96, 0.96, 0.98, 1.0)
	if stat_value >= 150:
		return Color(1.0, 0.64, 0.22, 1.0)
	if stat_value >= 100:
		return Color(0.76, 0.48, 1.0, 1.0)
	if stat_value >= 50:
		return Color(0.28, 0.88, 1.0, 1.0)
	match stat_key:
		"strength":
			return Color(0.94, 0.48, 0.36, 1.0)
		"magic":
			return Color(0.78, 0.48, 0.96, 1.0)
		"defense":
			return Color(0.50, 0.88, 0.50, 1.0)
		"resistance":
			return Color(0.38, 0.90, 0.82, 1.0)
		"speed":
			return Color(0.46, 0.76, 1.0, 1.0)
		"agility":
			return Color(0.96, 0.82, 0.44, 1.0)
		_:
			return Color(0.74, 0.86, 0.42, 1.0)


static func unit_info_stat_fill_color(field, stat_key: String, stat_value: int) -> Color:
	return unit_info_stat_fill_color_standalone(stat_key, stat_value)

static func style_unit_info_stat_bar(_field, bar: ProgressBar, fill: Color, overcap: bool) -> void:
	if bar == null:
		return
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.06, 0.05, 0.98)
	bg_style.border_color = fill if overcap else Color(0.24, 0.22, 0.18, 1.0)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(5)
	bg_style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	bg_style.shadow_size = 2

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.border_color = fill.lightened(0.18)
	fill_style.set_border_width_all(1)
	fill_style.set_corner_radius_all(5)

	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)

static func ensure_unit_info_stat_fx_nodes(field, block: Panel) -> void:
	if block == null:
		return
	var aura := block.get_node_or_null("TierAura") as ColorRect
	if aura == null:
		aura = ColorRect.new()
		aura.name = "TierAura"
		aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_child(aura)
		block.move_child(aura, 0)
	aura.modulate.a = 0.0

	var flash := block.get_node_or_null("TierFlash") as ColorRect
	if flash == null:
		flash = ColorRect.new()
		flash.name = "TierFlash"
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_child(flash)
		block.move_child(flash, 0)
	flash.modulate.a = 0.0

	block.clip_contents = false
	var arcs_root := get_unit_info_stat_arcs_root(field, block)
	if arcs_root == null:
		return
	for idx in range(8):
		var arc_name := "Arc%d" % idx
		var arc := arcs_root.get_node_or_null(arc_name) as ColorRect
		if arc == null:
			arc = ColorRect.new()
			arc.name = arc_name
			arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			arcs_root.add_child(arc)
		arc.z_index = 220
		arc.size = Vector2(20, 4)
		arc.color = Color.WHITE
		arc.modulate.a = 0.0
	position_unit_info_stat_fx_nodes(field, block)

static func get_unit_info_stat_arcs_root(field, block: Panel) -> Control:
	if block == null or field.ui_root == null:
		return null
	var arcs_root: Control = null
	if block.has_meta("tier_arcs_root_ref"):
		var stored_root = block.get_meta("tier_arcs_root_ref")
		if is_instance_valid(stored_root):
			arcs_root = stored_root as Control
	if arcs_root == null:
		arcs_root = Control.new()
		arcs_root.name = "TierArcs"
		field.ui_root.add_child(arcs_root)
		block.set_meta("tier_arcs_root_ref", arcs_root)
	var block_rect: Rect2 = block.get_global_rect()
	arcs_root.position = block_rect.position + Vector2(-10, -10)
	arcs_root.size = block_rect.size + Vector2(20, 20)
	arcs_root.visible = false
	arcs_root.z_index = 200
	arcs_root.clip_contents = false
	return arcs_root

static func position_unit_info_stat_fx_nodes(field, block: Panel) -> void:
	if block == null:
		return
	var aura := block.get_node_or_null("TierAura") as ColorRect
	if aura != null:
		aura.position = Vector2(4, 8)
		aura.size = Vector2(max(block.size.x - 8.0, 20.0), 7)
	var flash := block.get_node_or_null("TierFlash") as ColorRect
	if flash != null:
		flash.position = Vector2.ZERO
		flash.size = block.size
	var arcs_root := get_unit_info_stat_arcs_root(field, block)
	if arcs_root != null:
		var block_rect: Rect2 = block.get_global_rect()
		arcs_root.position = block_rect.position + Vector2(-10, -10)
		arcs_root.size = block_rect.size + Vector2(20, 20)

static func stop_unit_info_stat_tier_fx(field, block: Panel) -> void:
	if block == null:
		return
	var flash_tween = null
	if block.has_meta("tier_flash_tween"):
		flash_tween = block.get_meta("tier_flash_tween")
	if flash_tween is Tween:
		(flash_tween as Tween).kill()
	if block.has_meta("tier_flash_tween"):
		block.remove_meta("tier_flash_tween")
	var loop_tween = null
	if block.has_meta("tier_loop_tween"):
		loop_tween = block.get_meta("tier_loop_tween")
	if loop_tween is Tween:
		(loop_tween as Tween).kill()
	if block.has_meta("tier_loop_tween"):
		block.remove_meta("tier_loop_tween")
	var arc_tweens: Array = []
	if block.has_meta("tier_arc_tweens"):
		var stored_arc_tweens = block.get_meta("tier_arc_tweens")
		if stored_arc_tweens is Array:
			arc_tweens = stored_arc_tweens
	if arc_tweens is Array:
		for item in arc_tweens:
			if item is Tween:
				(item as Tween).kill()
	if block.has_meta("tier_arc_tweens"):
		block.remove_meta("tier_arc_tweens")
	if block.has_meta("tier_loop_tier"):
		block.remove_meta("tier_loop_tier")
	var flash := block.get_node_or_null("TierFlash") as ColorRect
	if flash != null:
		flash.modulate.a = 0.0
	var aura := block.get_node_or_null("TierAura") as ColorRect
	if aura != null:
		aura.modulate.a = 0.0
	var arcs_root := get_unit_info_stat_arcs_root(field, block)
	if arcs_root != null:
		arcs_root.visible = false
		for child in arcs_root.get_children():
			if child is ColorRect:
				var arc := child as ColorRect
				arc.modulate.a = 0.0

static func unit_info_stat_arc_count_for_tier(tier: int) -> int:
	match tier:
		1:
			return 3
		2:
			return 4
		3:
			return 6
		_:
			return 8

static func unit_info_stat_arc_perimeter_length(field_size: Vector2) -> float:
	var width: float = max(field_size.x - 8.0, 12.0)
	var height: float = max(field_size.y - 8.0, 12.0)
	return (width * 2.0) + (height * 2.0)

static func unit_info_stat_arc_perimeter_point(field_size: Vector2, raw_offset: float) -> Vector2:
	var inset: float = 4.0
	var width: float = max(field_size.x - (inset * 2.0), 12.0)
	var height: float = max(field_size.y - (inset * 2.0), 12.0)
	var perimeter: float = (width * 2.0) + (height * 2.0)
	if perimeter <= 0.0:
		return Vector2(inset, inset)
	var offset: float = fposmod(raw_offset, perimeter)
	if offset < width:
		return Vector2(inset + offset, inset)
	offset -= width
	if offset < height:
		return Vector2(inset + width, inset + offset)
	offset -= height
	if offset < width:
		return Vector2((inset + width) - offset, inset + height)
	offset -= width
	return Vector2(inset, (inset + height) - offset)

static func unit_info_stat_arc_perimeter_normal(field_size: Vector2, raw_offset: float) -> Vector2:
	var inset: float = 4.0
	var width: float = max(field_size.x - (inset * 2.0), 12.0)
	var height: float = max(field_size.y - (inset * 2.0), 12.0)
	var perimeter: float = (width * 2.0) + (height * 2.0)
	if perimeter <= 0.0:
		return Vector2.UP
	var offset: float = fposmod(raw_offset, perimeter)
	if offset < width:
		return Vector2.UP
	offset -= width
	if offset < height:
		return Vector2.RIGHT
	offset -= height
	if offset < width:
		return Vector2.DOWN
	return Vector2.LEFT

static func set_unit_info_stat_arc_progress(progress: float, arc: ColorRect, field_size: Vector2, segment_length: float, tier: int, phase: float, clockwise: bool) -> void:
	if arc == null:
		return
	var point: Vector2 = unit_info_stat_arc_perimeter_point(field_size, progress)
	var normal: Vector2 = unit_info_stat_arc_perimeter_normal(field_size, progress)
	var direction: float = 1.0 if clockwise else -1.0
	var outward_push: float = 1.5 + (float(tier) * 0.8)
	var wave: float = sin((progress * 0.08 * direction) + phase)
	var thickness: float = 4.0 + (float(tier) * 0.7)
	var long_length: float = max(segment_length * 0.42, 12.0)
	var short_length: float = max(segment_length * 0.22, 8.0)
	if absf(normal.x) > 0.5:
		arc.size = Vector2(thickness, long_length if clockwise else short_length)
		arc.position = point - Vector2(arc.size.x * 0.5, arc.size.y * 0.5) + (normal * ((wave * 1.4) + outward_push))
	else:
		arc.size = Vector2(long_length if clockwise else short_length, thickness)
		arc.position = point - Vector2(arc.size.x * 0.5, arc.size.y * 0.5) + (normal * ((wave * 1.4) + outward_push))

static func play_unit_info_stat_tier_flash(field, block: Panel, tier: int, color: Color) -> void:
	if block == null or tier <= 0:
		return
	position_unit_info_stat_fx_nodes(field, block)
	var flash := block.get_node_or_null("TierFlash") as ColorRect
	if flash == null:
		return
	var flash_tween = null
	if block.has_meta("tier_flash_tween"):
		flash_tween = block.get_meta("tier_flash_tween")
	if flash_tween is Tween:
		(flash_tween as Tween).kill()
	flash.color = Color(color.r, color.g, color.b, 0.15 + (float(tier) * 0.04))
	flash.modulate.a = 0.0
	var tw: Tween = field.create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(flash, "modulate:a", 1.0, 0.10)
	tw.tween_property(flash, "modulate:a", 0.0, 0.24)
	block.set_meta("tier_flash_tween", tw)

static func start_unit_info_stat_tier_loop(field, block: Panel, tier: int, color: Color) -> void:
	if block == null or tier <= 0:
		return
	position_unit_info_stat_fx_nodes(field, block)
	var aura := block.get_node_or_null("TierAura") as ColorRect
	var arcs_root := get_unit_info_stat_arcs_root(field, block)
	if aura == null or arcs_root == null:
		return
	var loop_tween = null
	if block.has_meta("tier_loop_tween"):
		loop_tween = block.get_meta("tier_loop_tween")
	if loop_tween is Tween:
		(loop_tween as Tween).kill()
	var arc_tweens_old: Array = []
	if block.has_meta("tier_arc_tweens"):
		var stored_arc_tweens_old = block.get_meta("tier_arc_tweens")
		if stored_arc_tweens_old is Array:
			arc_tweens_old = stored_arc_tweens_old
	if arc_tweens_old is Array:
		for item in arc_tweens_old:
			if item is Tween:
				(item as Tween).kill()

	var aura_color := color.lightened(0.10)
	aura.color = aura_color
	aura.modulate.a = 0.22 + (float(tier) * 0.06)
	arcs_root.visible = true

	var field_size: Vector2 = arcs_root.size
	var alpha_peak: float = float(min(0.96 + (float(tier) * 0.02), 1.0))
	var alpha_idle: float = 0.72 + (float(tier) * 0.05)
	var cycle_time: float = float(max(0.68 - (float(tier) * 0.07), 0.28))
	var perimeter: float = unit_info_stat_arc_perimeter_length(field_size)
	var segment_length: float = clampf(perimeter * (0.13 + (float(tier) * 0.02)), 22.0, perimeter * 0.34)

	var tw: Tween = field.create_tween().set_parallel(true).set_loops()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(aura, "modulate:a", min(0.34 + (float(tier) * 0.08), 0.72), cycle_time * 0.60)
	tw.parallel().tween_property(aura, "modulate:a", 0.16 + (float(tier) * 0.05), cycle_time * 0.40).set_delay(cycle_time * 0.60)

	var arc_count: int = unit_info_stat_arc_count_for_tier(tier)
	var arc_tweens: Array = []
	for idx in range(arcs_root.get_child_count()):
		var arc := arcs_root.get_child(idx) as ColorRect
		if arc == null:
			continue
		if idx >= arc_count:
			arc.modulate.a = 0.0
			continue
		var arc_color := color.lightened(0.22 + (float(idx) * 0.03))
		var start_offset: float = (perimeter / float(arc_count)) * float(idx)
		var end_offset: float = start_offset + (perimeter * (1.0 if idx % 2 == 0 else -1.0))
		var phase: float = float(idx) * 0.85
		arc.color = arc_color
		set_unit_info_stat_arc_progress(start_offset, arc, field_size, segment_length, tier, phase, idx % 2 == 0)
		arc.modulate.a = alpha_idle
		var arc_tw: Tween = field.create_tween().set_parallel(true).set_loops()
		arc_tw.set_trans(Tween.TRANS_SINE)
		arc_tw.set_ease(Tween.EASE_IN_OUT)
		arc_tw.tween_method(
			Callable(DetailedUnitInfoRuntimeHelpers, "set_unit_info_stat_arc_progress").bind(arc, field_size, segment_length, tier, phase, idx % 2 == 0),
			start_offset,
			end_offset,
			cycle_time
		)
		arc_tw.parallel().tween_property(arc, "modulate:a", alpha_peak, cycle_time * 0.44)
		arc_tw.parallel().tween_property(arc, "modulate:a", alpha_idle, cycle_time * 0.56).set_delay(cycle_time * 0.44)
		arc_tweens.append(arc_tw)
	block.set_meta("tier_loop_tween", tw)
	block.set_meta("tier_arc_tweens", arc_tweens)
	block.set_meta("tier_loop_tier", tier)

static func play_unit_info_stat_tier_fx(field, block: Panel, tier: int, color: Color) -> void:
	if block == null or tier <= 0:
		return
	ensure_unit_info_stat_fx_nodes(field, block)
	play_unit_info_stat_tier_flash(field, block, tier, color)
	start_unit_info_stat_tier_loop(field, block, tier, color)

static func ensure_unit_info_stat_widgets(field) -> Control:
	if field.unit_info_panel == null:
		return null
	var root := field.unit_info_panel.get_node_or_null("UnitStatBarsRoot") as Control
	if root == null:
		root = Control.new()
		root.name = "UnitStatBarsRoot"
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		field.unit_info_panel.add_child(root)

	for stat_def in unit_info_stat_definitions():
		var stat_key: String = str(stat_def.get("key", ""))
		if stat_key == "":
			continue
		var panel_name := "StatBlock_%s" % stat_key
		var block := root.get_node_or_null(panel_name) as Panel
		if block == null:
			block = Panel.new()
			block.name = panel_name
			block.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(block)
		field._style_tactical_panel(block, Color(0.10, 0.09, 0.07, 0.88), field.TACTICAL_UI_BORDER_MUTED, 1, 6)

		var name_label := block.get_node_or_null("Name") as Label
		if name_label == null:
			name_label = Label.new()
			name_label.name = "Name"
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.add_child(name_label)
		var value_label := block.get_node_or_null("Value") as Label
		if value_label == null:
			value_label = Label.new()
			value_label.name = "Value"
			value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.add_child(value_label)
		var bar := block.get_node_or_null("Bar") as ProgressBar
		if bar == null:
			bar = ProgressBar.new()
			bar.name = "Bar"
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.add_child(bar)

		field._unit_info_stat_widgets[stat_key] = {
			"panel": block,
			"name": name_label,
			"value": value_label,
			"bar": bar,
		}

	layout_unit_info_stat_widgets(field)
	return root

static func layout_unit_info_stat_widgets(field) -> void:
	var root: Control = null
	if field.unit_info_panel != null:
		root = field.unit_info_panel.get_node_or_null("UnitStatBarsRoot") as Control
	if root == null:
		return
	root.position = Vector2(16, 170)
	root.size = Vector2(210, 50)
	var block_width := 102.0
	var block_height := 16.0
	var gap_x := 6.0
	var gap_y := 2.0
	var defs := unit_info_stat_definitions()
	for idx in range(defs.size()):
		var stat_key: String = str(defs[idx].get("key", ""))
		if not field._unit_info_stat_widgets.has(stat_key):
			continue
		var widgets: Dictionary = field._unit_info_stat_widgets[stat_key]
		var panel := widgets.get("panel") as Panel
		var name_label := widgets.get("name") as Label
		var value_label := widgets.get("value") as Label
		var bar := widgets.get("bar") as ProgressBar
		var col: int = idx % 2
		var row: int = int(idx / 2.0)
		var pos := Vector2(col * (block_width + gap_x), row * (block_height + gap_y))
		if panel != null:
			panel.position = pos
			panel.size = Vector2(block_width, block_height)
			ensure_unit_info_stat_fx_nodes(field, panel)
		if name_label != null:
			name_label.position = Vector2(4, 0)
			name_label.size = Vector2(30, 8)
			name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			field._style_tactical_label(name_label, field.TACTICAL_UI_TEXT_MUTED, 10, 2)
		if value_label != null:
			value_label.position = Vector2(34, 0)
			value_label.size = Vector2(64, 8)
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			field._style_tactical_label(value_label, field.TACTICAL_UI_TEXT, 10, 2)
		if bar != null:
			bar.min_value = 0.0
			bar.max_value = field.UNIT_INFO_STAT_BAR_CAP
			bar.position = Vector2(4, 9)
			bar.size = Vector2(94, 5)

static func set_unit_info_stat_widgets_visible(field, visible: bool) -> void:
	var root: Control = null
	if field.unit_info_panel != null:
		root = field.unit_info_panel.get_node_or_null("UnitStatBarsRoot") as Control
	if not visible and field._unit_info_stat_anim_tween != null:
		field._unit_info_stat_anim_tween.kill()
		field._unit_info_stat_anim_tween = null
		field._unit_info_stat_animating = false
		field._unit_info_stat_anim_source_id = -1
	if root != null:
		if not visible:
			for child in root.get_children():
				if child is Panel:
					stop_unit_info_stat_tier_fx(field, child as Panel)
		root.visible = visible

static func unit_info_stat_display_value(field, raw_value: int) -> float:
	if raw_value <= 0:
		return 0.0
	var cap_int := int(field.UNIT_INFO_STAT_BAR_CAP)
	if raw_value < cap_int:
		return float(raw_value)
	var wrapped := raw_value % cap_int
	if wrapped == 0:
		return field.UNIT_INFO_STAT_BAR_CAP
	return float(wrapped)

static func animate_unit_info_stat_widgets_in(field, display_values: Dictionary, source_id: int) -> void:
	if field._unit_info_stat_anim_tween != null:
		field._unit_info_stat_anim_tween.kill()
	field._unit_info_stat_anim_tween = field.create_tween().set_parallel(true)
	field._unit_info_stat_animating = true
	field._unit_info_stat_anim_source_id = source_id
	var defs := unit_info_stat_definitions()
	for idx in range(defs.size()):
		var stat_key: String = str(defs[idx].get("key", ""))
		if not field._unit_info_stat_widgets.has(stat_key):
			continue
		var widgets: Dictionary = field._unit_info_stat_widgets[stat_key]
		var panel := widgets.get("panel") as Panel
		var bar := widgets.get("bar") as ProgressBar
		var delay := float(idx) * 0.028
		if panel != null:
			panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
			field._unit_info_stat_anim_tween.tween_property(panel, "modulate", Color.WHITE, 0.16).set_delay(delay)
		if bar != null:
			bar.value = 0.0
			field._unit_info_stat_anim_tween.tween_property(bar, "value", float(display_values.get(stat_key, 0.0)), 0.22).set_delay(delay)
	field._unit_info_stat_anim_tween.finished.connect(func():
		field._unit_info_stat_anim_tween = null
		field._unit_info_stat_animating = false
		field._unit_info_stat_anim_source_id = -1
	, CONNECT_ONE_SHOT)

static func refresh_unit_info_stat_widgets(field, stat_values: Dictionary, animate: bool = false, source_id: int = -1) -> void:
	var root := ensure_unit_info_stat_widgets(field)
	if root == null:
		return
	root.visible = true
	var display_values: Dictionary = {}
	for stat_def in unit_info_stat_definitions():
		var stat_key: String = str(stat_def.get("key", ""))
		var stat_label: String = str(stat_def.get("label", stat_key))
		if not field._unit_info_stat_widgets.has(stat_key):
			continue
		var widgets: Dictionary = field._unit_info_stat_widgets[stat_key]
		var panel := widgets.get("panel") as Panel
		var name_label := widgets.get("name") as Label
		var value_label := widgets.get("value") as Label
		var bar := widgets.get("bar") as ProgressBar
		var raw_value: int = int(stat_values.get(stat_key, 0))
		var display_value := unit_info_stat_display_value(field, raw_value)
		display_values[stat_key] = display_value
		var overcap: bool = raw_value >= int(field.UNIT_INFO_STAT_BAR_CAP)
		var fill_color := unit_info_stat_fill_color(field, stat_key, raw_value)
		var tier := unit_info_stat_tier_index(field, raw_value)
		var previous_tier := -1
		if panel != null and panel.has_meta("stat_tier"):
			previous_tier = int(panel.get_meta("stat_tier"))
		if panel != null:
			panel.modulate = Color.WHITE
			field._style_tactical_panel(panel, Color(0.10, 0.09, 0.07, 0.88), fill_color if overcap else field.TACTICAL_UI_BORDER_MUTED, 1, 6)
			panel.set_meta("stat_tier", tier)
		if name_label != null:
			name_label.text = stat_label
			field._style_tactical_label(name_label, fill_color, 11, 2)
		if value_label != null:
			value_label.text = str(raw_value)
			field._style_tactical_label(value_label, fill_color if overcap else field.TACTICAL_UI_TEXT, 11, 2)
		if bar != null:
			style_unit_info_stat_bar(field, bar, fill_color, overcap)
			if not animate and not (field._unit_info_stat_animating and field._unit_info_stat_anim_source_id == source_id):
				bar.value = display_value
		if panel != null:
			if tier <= 0:
				stop_unit_info_stat_tier_fx(field, panel)
			elif animate or (previous_tier >= 0 and previous_tier != tier) or not panel.has_meta("tier_loop_tween"):
				play_unit_info_stat_tier_fx(field, panel, tier, fill_color)
	if animate:
		animate_unit_info_stat_widgets_in(field, display_values, source_id)
