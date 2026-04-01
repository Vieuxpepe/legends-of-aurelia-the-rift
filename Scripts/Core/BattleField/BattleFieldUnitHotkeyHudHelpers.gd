extends RefCounted

const MAX_HOTKEY_SLOTS: int = 6
const PANEL_NAME: String = "UnitHotkeyStripPanel"
const ROW_NAME: String = "UnitHotkeyStripRow"


static func refresh_unit_hotkey_hud(field) -> void:
	if field == null:
		return
	var log_panel: Panel = field._get_battle_log_panel()
	if log_panel == null or not is_instance_valid(log_panel):
		return

	var panel: Panel = _ensure_panel(field, log_panel)
	if panel == null:
		return

	var units: Array[Node2D] = _collect_hotkey_units(field)
	var should_show: bool = (
		field.current_state != field.pre_battle_state
		and not units.is_empty()
	)
	panel.visible = should_show
	if not should_show:
		return

	_layout_panel(panel, log_panel, units.size())
	var sig: String = _build_signature(field, units)
	if str(panel.get_meta("hotkey_sig", "")) == sig:
		return
	panel.set_meta("hotkey_sig", sig)
	_rebuild_slots(field, panel, units)


static func _ensure_panel(field, log_panel: Panel) -> Panel:
	var panel: Panel = log_panel.get_node_or_null(PANEL_NAME) as Panel
	# Migration guard: if a previous build created the strip under UI root, reparent it back to log panel.
	if panel == null and field.ui_root != null:
		panel = field.ui_root.get_node_or_null(PANEL_NAME) as Panel
		if panel != null:
			field.ui_root.remove_child(panel)
			log_panel.add_child(panel)
	if panel == null:
		panel = Panel.new()
		panel.name = PANEL_NAME
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.z_index = 24
		log_panel.add_child(panel)
	if not panel.has_meta("hotkey_styled"):
		field._style_tactical_panel(panel, Color(0.10, 0.095, 0.08, 0.92), Color(0.44, 0.39, 0.27, 0.9), 1, 8)
		panel.set_meta("hotkey_styled", true)
	_ensure_row(panel)
	return panel


static func _ensure_row(panel: Panel) -> HBoxContainer:
	var row: HBoxContainer = panel.get_node_or_null(ROW_NAME) as HBoxContainer
	if row != null:
		return row
	row = HBoxContainer.new()
	row.name = ROW_NAME
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	return row


static func _layout_panel(panel: Panel, log_panel: Panel, slot_count: int) -> void:
	var effective_slots: int = maxi(1, mini(slot_count, MAX_HOTKEY_SLOTS))
	var desired_w: float = 8.0 + (62.0 * float(effective_slots))
	var max_w: float = maxf(140.0, log_panel.size.x - 20.0)
	panel.size = Vector2(minf(desired_w, max_w), 44.0)
	panel.position = Vector2(10.0, -48.0)


static func _collect_hotkey_units(field) -> Array[Node2D]:
	var out: Array[Node2D] = []
	if field.player_container == null:
		return out
	for child in field.player_container.get_children():
		var unit: Node2D = child as Node2D
		if unit == null or not is_instance_valid(unit) or unit.is_queued_for_deletion():
			continue
		if unit.visible == false:
			continue
		if unit.get("current_hp") != null and int(unit.current_hp) <= 0:
			continue
		if unit.get("is_exhausted") == true:
			continue
		if field.is_local_player_command_blocked_for_mock_coop_unit(unit):
			continue
		out.append(unit)
		if out.size() >= MAX_HOTKEY_SLOTS:
			break
	return out


static func _build_signature(field, units: Array[Node2D]) -> String:
	var active_id: int = -1
	if field.player_state != null and is_instance_valid(field.player_state.active_unit):
		active_id = field.player_state.active_unit.get_instance_id()
	var parts: PackedStringArray = PackedStringArray()
	parts.append(str(active_id))
	for unit in units:
		parts.append(str(unit.get_instance_id()))
		var icon_tex: Texture2D = _resolve_unit_icon(unit)
		parts.append(str(icon_tex.get_instance_id()) if icon_tex != null else "0")
	return "|".join(parts)


static func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


static func _resolve_unit_icon(unit: Node2D) -> Texture2D:
	# Prefer the live in-battle sprite so promotions/overrides are reflected immediately.
	var sprite_var: Variant = unit.get("sprite")
	if sprite_var is Sprite2D:
		var unit_sprite: Sprite2D = sprite_var as Sprite2D
		if unit_sprite.texture != null:
			return unit_sprite.texture
	var data_variant: Variant = unit.get("data")
	if data_variant is Object:
		var battle_sprite_variant: Variant = data_variant.get("unit_sprite")
		if battle_sprite_variant is Texture2D:
			return battle_sprite_variant as Texture2D
		var portrait_variant: Variant = data_variant.get("portrait")
		if portrait_variant is Texture2D:
			return portrait_variant as Texture2D
	var sprite: Sprite2D = unit.get_node_or_null("Sprite") as Sprite2D
	if sprite != null and sprite.texture != null:
		return sprite.texture
	return null


static func _slot_style(field, slot: Panel, is_active: bool) -> void:
	var fill: Color = Color(0.21, 0.17, 0.09, 0.95)
	var border: Color = Color(0.45, 0.39, 0.24, 0.95)
	if is_active:
		fill = Color(0.64, 0.50, 0.17, 0.98)
		border = Color(0.90, 0.80, 0.38, 1.0)
	field._style_tactical_panel(slot, fill, border, 1, 6)


static func _rebuild_slots(field, panel: Panel, units: Array[Node2D]) -> void:
	var row: HBoxContainer = _ensure_row(panel)
	_clear_children(row)
	var active_unit: Node2D = field.player_state.active_unit if field.player_state != null else null

	for i in range(units.size()):
		var unit: Node2D = units[i]
		var slot: Panel = Panel.new()
		slot.custom_minimum_size = Vector2(58, 34)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.tooltip_text = "%d - %s" % [i + 1, str(unit.get("unit_name") if unit.get("unit_name") != null else "Unit")]
		_slot_style(field, slot, active_unit == unit)
		row.add_child(slot)

		var inner: HBoxContainer = HBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 3)
		slot.add_child(inner)

		var key_label: Label = Label.new()
		key_label.text = str(i + 1)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_label.custom_minimum_size = Vector2(12, 26)
		key_label.add_theme_font_size_override("font_size", 12)
		key_label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.76, 1.0))
		key_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05, 1.0))
		key_label.add_theme_constant_override("outline_size", 2)
		inner.add_child(key_label)

		var icon: TextureRect = TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.custom_minimum_size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _resolve_unit_icon(unit)
		inner.add_child(icon)
