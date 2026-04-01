extends RefCounted

# Combat forecast panel widgets / text styling helpers (bars, badges, emphasis pulse).

static func style_forecast_hp_bar(field, bar: ProgressBar, fill: Color) -> void:
	if bar == null:
		return
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", field._make_tactical_bar_style(Color(0.10, 0.09, 0.06, 0.98), Color(0.72, 0.61, 0.28, 1.0), 2, 6))
	bar.add_theme_stylebox_override("fill", field._make_tactical_bar_style(fill, Color(0.85, 0.78, 0.44, 0.95), 1, 6))

static func forecast_hp_fill_color(current_hp: int, max_hp: int) -> Color:
	if max_hp <= 0:
		return Color(0.82, 0.25, 0.22, 1.0)
	var ratio: float = clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	if ratio >= 0.67:
		return Color(0.24, 0.86, 0.50, 1.0)
	if ratio >= 0.34:
		return Color(0.93, 0.74, 0.24, 1.0)
	return Color(0.92, 0.32, 0.27, 1.0)

static func truncate_forecast_text(text: String, max_chars: int) -> String:
	var clean: String = str(text).strip_edges()
	if max_chars <= 3 or clean.length() <= max_chars:
		return clean
	return clean.substr(0, max_chars - 3) + "..."

static func format_forecast_name(prefix: String, unit_name: String, max_name_chars: int = 14) -> String:
	var pre: String = str(prefix).strip_edges()
	var capped_name: String = truncate_forecast_text(unit_name, max_name_chars)
	if pre == "":
		return capped_name
	return pre + ": " + capped_name

static func format_forecast_name_fitted(prefix: String, unit_name: String, max_total_chars: int = 18) -> String:
	var pre: String = str(prefix).strip_edges()
	var prefix_text: String = pre + ": " if pre != "" else ""
	var available_name_chars: int = maxi(4, max_total_chars - prefix_text.length())
	return prefix_text + truncate_forecast_text(unit_name, available_name_chars)

static func forecast_weapon_marker(weapon: WeaponData) -> String:
	if weapon == null:
		return "[---]"
	if WeaponData.is_staff_like(weapon):
		return "[STF]"
	match int(weapon.weapon_type):
		WeaponData.WeaponType.SWORD:
			return "[SWD]"
		WeaponData.WeaponType.LANCE:
			return "[LNC]"
		WeaponData.WeaponType.AXE:
			return "[AXE]"
		WeaponData.WeaponType.BOW:
			return "[BOW]"
		WeaponData.WeaponType.TOME:
			return "[TOM]"
		WeaponData.WeaponType.KNIFE:
			return "[KNF]"
		WeaponData.WeaponType.FIREARM:
			return "[GUN]"
		WeaponData.WeaponType.FIST:
			return "[FST]"
		WeaponData.WeaponType.INSTRUMENT:
			return "[SON]"
		WeaponData.WeaponType.DARK_TOME:
			return "[DRK]"
		_:
			return "[---]"

static func format_forecast_weapon_text(weapon: WeaponData) -> String:
	if weapon == null:
		return "[---] UNARMED"
	return "%s %s" % [forecast_weapon_marker(weapon), String(weapon.weapon_name).to_upper()]

static func format_forecast_weapon_name(weapon: WeaponData, max_chars: int = 14) -> String:
	if weapon == null:
		return "UNARMED"
	return truncate_forecast_text(String(weapon.weapon_name).to_upper(), max_chars)

static func forecast_weapon_rarity_glow_color(weapon: WeaponData) -> Color:
	if weapon == null:
		return Color(0, 0, 0, 0)
	match String(weapon.rarity):
		"Rare":
			return Color(0.42, 0.72, 1.0, 0.22)
		"Epic":
			return Color(0.82, 0.50, 1.0, 0.22)
		"Legendary":
			return Color(1.0, 0.84, 0.38, 0.26)
		_:
			return Color(0, 0, 0, 0)

static func style_forecast_weapon_glow(glow_panel: Panel, glow_color: Color) -> void:
	if glow_panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = glow_color
	style.set_corner_radius_all(6)
	style.shadow_color = Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 1.6)
	style.shadow_size = 10
	style.shadow_offset = Vector2.ZERO
	glow_panel.add_theme_stylebox_override("panel", style)

static func ensure_forecast_hp_bars(field) -> void:
	if field.forecast_panel == null:
		return
	if field.forecast_atk_hp_bar == null:
		field.forecast_atk_hp_bar = ProgressBar.new()
		field.forecast_atk_hp_bar.name = "AtkHPBar"
		field.forecast_panel.add_child(field.forecast_atk_hp_bar)
	if field.forecast_def_hp_bar == null:
		field.forecast_def_hp_bar = ProgressBar.new()
		field.forecast_def_hp_bar.name = "DefHPBar"
		field.forecast_panel.add_child(field.forecast_def_hp_bar)
	for bar in [field.forecast_atk_hp_bar, field.forecast_def_hp_bar]:
		if bar == null:
			continue
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.value = 100.0
		bar.step = 0.1
		bar.custom_minimum_size = Vector2(190, 10)
		bar.size = Vector2(190, 10)
		bar.z_index = 2
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		style_forecast_hp_bar(field, bar, Color(0.24, 0.86, 0.50, 1.0))

static func ensure_forecast_weapon_badges(field) -> void:
	if field.forecast_panel == null:
		return
	var specs: Array[Dictionary] = [
		{
			"panel_name": "AtkWeaponBadgePanel",
			"fill": Color(0.34, 0.17, 0.10, 0.92),
			"border": Color(0.94, 0.72, 0.42, 0.92),
			"text_color": Color(1.0, 0.88, 0.62, 1.0),
		},
		{
			"panel_name": "DefWeaponBadgePanel",
			"fill": Color(0.10, 0.18, 0.34, 0.92),
			"border": Color(0.58, 0.80, 1.0, 0.92),
			"text_color": Color(0.88, 0.95, 1.0, 1.0),
		},
	]
	for spec in specs:
		var panel_name: String = str(spec.get("panel_name", ""))
		var panel := field.forecast_panel.get_node_or_null(panel_name) as Panel
		if panel == null:
			panel = Panel.new()
			panel.name = panel_name
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			field.forecast_panel.add_child(panel)
		panel.z_index = 3
		field._style_tactical_panel(panel, spec.get("fill", field.TACTICAL_UI_BG_SOFT), spec.get("border", field.TACTICAL_UI_BORDER), 1, 8)
		var badge_label := panel.get_node_or_null("Text") as Label
		if badge_label == null:
			badge_label = Label.new()
			badge_label.name = "Text"
			badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(badge_label)
		badge_label.position = Vector2.ZERO
		badge_label.size = panel.size
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		field._style_tactical_label(badge_label, spec.get("text_color", field.TACTICAL_UI_TEXT), 15, 3)

static func ensure_forecast_weapon_pair_frames(field) -> void:
	if field.forecast_panel == null:
		return
	for panel_name in ["AtkWeaponPairFrame", "DefWeaponPairFrame"]:
		var frame := field.forecast_panel.get_node_or_null(panel_name) as Panel
		if frame == null:
			frame = Panel.new()
			frame.name = panel_name
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			field.forecast_panel.add_child(frame)
		frame.z_index = 2
		field._style_tactical_panel(frame, Color(0.16, 0.13, 0.09, 0.88), Color(0.46, 0.40, 0.26, 0.88), 1, 8)
		var bevel_top := frame.get_node_or_null("BevelTop") as ColorRect
		if bevel_top == null:
			bevel_top = ColorRect.new()
			bevel_top.name = "BevelTop"
			bevel_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(bevel_top)
		bevel_top.color = Color(1.0, 0.94, 0.74, 0.18)
		var bevel_bottom := frame.get_node_or_null("BevelBottom") as ColorRect
		if bevel_bottom == null:
			bevel_bottom = ColorRect.new()
			bevel_bottom.name = "BevelBottom"
			bevel_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(bevel_bottom)
		bevel_bottom.color = Color(0.0, 0.0, 0.0, 0.20)

static func ensure_forecast_weapon_icons(field) -> void:
	if field.forecast_panel == null:
		return
	for panel_name in ["AtkWeaponIconPanel", "DefWeaponIconPanel"]:
		var panel := field.forecast_panel.get_node_or_null(panel_name) as Panel
		if panel == null:
			panel = Panel.new()
			panel.name = panel_name
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			field.forecast_panel.add_child(panel)
		panel.z_index = 3
		field._style_tactical_panel(panel, field.TACTICAL_UI_BG_SOFT, field.TACTICAL_UI_BORDER_MUTED, 1, 7)
		var glow_panel := panel.get_node_or_null("Glow") as Panel
		if glow_panel == null:
			glow_panel = Panel.new()
			glow_panel.name = "Glow"
			glow_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(glow_panel)
			panel.move_child(glow_panel, 0)
		glow_panel.position = Vector2(2, 2)
		glow_panel.size = Vector2(22, 22)
		glow_panel.visible = false
		var icon_rect := panel.get_node_or_null("Icon") as TextureRect
		if icon_rect == null:
			icon_rect = TextureRect.new()
			icon_rect.name = "Icon"
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(icon_rect)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.position = Vector2(3, 3)
		icon_rect.size = Vector2(20, 20)

static func reset_forecast_emphasis_visuals(field) -> void:
	if field.crit_flash_tween != null:
		field.crit_flash_tween.kill()
	for lbl in [field.forecast_atk_dmg, field.forecast_def_dmg, field.forecast_atk_crit, field.forecast_def_crit]:
		if lbl is Label:
			var ui_lbl := lbl as Label
			ui_lbl.modulate = Color.WHITE
			ui_lbl.scale = Vector2.ONE

static func start_forecast_emphasis_pulse(field, attacker_lethal: bool, defender_lethal: bool, attacker_crit_ready: bool, defender_crit_ready: bool) -> void:
	reset_forecast_emphasis_visuals(field)
	var pulse_targets: Array[Dictionary] = []
	if attacker_lethal and field.forecast_atk_dmg != null:
		pulse_targets.append({
			"label": field.forecast_atk_dmg,
			"color": Color(1.0, 0.86, 0.62, 1.0),
			"scale": Vector2(1.08, 1.08),
		})
	if defender_lethal and field.forecast_def_dmg != null:
		pulse_targets.append({
			"label": field.forecast_def_dmg,
			"color": Color(0.74, 0.92, 1.0, 1.0),
			"scale": Vector2(1.08, 1.08),
		})
	if attacker_crit_ready and field.forecast_atk_crit != null:
		pulse_targets.append({
			"label": field.forecast_atk_crit,
			"color": Color(1.0, 0.94, 0.62, 1.0),
			"scale": Vector2(1.05, 1.05),
		})
	if defender_crit_ready and field.forecast_def_crit != null:
		pulse_targets.append({
			"label": field.forecast_def_crit,
			"color": Color(0.88, 0.94, 1.0, 1.0),
			"scale": Vector2(1.05, 1.05),
		})
	if pulse_targets.is_empty():
		return

	field.crit_flash_tween = field.create_tween().set_loops()
	field.crit_flash_tween.set_trans(Tween.TRANS_SINE)
	field.crit_flash_tween.set_ease(Tween.EASE_IN_OUT)

	var first_up: bool = true
	for pulse in pulse_targets:
		var lbl: Label = pulse.get("label") as Label
		if lbl == null:
			continue
		var pulse_color: Color = pulse.get("color", Color.WHITE)
		var pulse_scale: Vector2 = pulse.get("scale", Vector2.ONE)
		if first_up:
			field.crit_flash_tween.tween_property(lbl, "modulate", pulse_color, 0.55)
			field.crit_flash_tween.parallel().tween_property(lbl, "scale", pulse_scale, 0.55)
			first_up = false
		else:
			field.crit_flash_tween.parallel().tween_property(lbl, "modulate", pulse_color, 0.55)
			field.crit_flash_tween.parallel().tween_property(lbl, "scale", pulse_scale, 0.55)

	var first_down: bool = true
	for pulse in pulse_targets:
		var lbl_down: Label = pulse.get("label") as Label
		if lbl_down == null:
			continue
		if first_down:
			field.crit_flash_tween.tween_property(lbl_down, "modulate", Color.WHITE, 0.55)
			field.crit_flash_tween.parallel().tween_property(lbl_down, "scale", Vector2.ONE, 0.55)
			first_down = false
		else:
			field.crit_flash_tween.parallel().tween_property(lbl_down, "modulate", Color.WHITE, 0.55)
			field.crit_flash_tween.parallel().tween_property(lbl_down, "scale", Vector2.ONE, 0.55)
