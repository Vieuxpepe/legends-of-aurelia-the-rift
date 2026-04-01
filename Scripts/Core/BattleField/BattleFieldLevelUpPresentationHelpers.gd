extends RefCounted


static func make_levelup_style(bg: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


static func hide_legacy_levelup_nodes(field) -> void:
	if field.level_up_title != null:
		field.level_up_title.visible = false
	if field.level_up_stats != null:
		field.level_up_stats.visible = false


static func get_levelup_dynamic_root(field) -> VBoxContainer:
	var existing_scroll_node: Node = field.level_up_panel.get_node_or_null("DynamicScroll")
	var existing_scroll: ScrollContainer = existing_scroll_node as ScrollContainer
	if existing_scroll != null:
		var existing_root_node: Node = existing_scroll.get_node_or_null("DynamicContent")
		var existing_root: VBoxContainer = existing_root_node as VBoxContainer
		if existing_root != null:
			return existing_root

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "DynamicScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 12
	scroll.offset_top = 12
	scroll.offset_right = -12
	scroll.offset_bottom = -12
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.level_up_panel.add_child(scroll)

	var root: VBoxContainer = VBoxContainer.new()
	root.name = "DynamicContent"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(root)

	return root


static func clear_levelup_dynamic_root(field) -> void:
	var root: VBoxContainer = get_levelup_dynamic_root(field)
	for child in root.get_children():
		child.queue_free()


static func get_levelup_bar_cap(stat_key: String, value: int) -> int:
	if stat_key == "hp":
		return int(max(20, int(ceil(float(value + 9) / 10.0) * 10.0)))
	return int(max(10, int(ceil(float(value + 4) / 5.0) * 5.0)))


static func update_levelup_value_label(value: float, value_label: Label, old_value: int, gain: int) -> void:
	var shown: int = int(round(value))
	if gain > 0:
		value_label.text = str(old_value) + " â†’ " + str(shown) + "  (+" + str(gain) + ")"
	else:
		value_label.text = str(shown)


static func get_levelup_class_theme(unit: Node2D) -> Dictionary:
	var raw_class_value = unit.get("unit_class_name")
	var unit_class_text: String = "Unit"
	if raw_class_value != null:
		unit_class_text = str(raw_class_value)

	var class_lower: String = unit_class_text.to_lower()

	var theme: Dictionary = {
		"panel_bg": Color(0.05, 0.09, 0.05, 0.97),
		"panel_border": Color(0.24, 0.86, 0.34, 1.0),
		"row_bg": Color(0.04, 0.07, 0.04, 0.95),
		"row_border": Color(0.18, 0.66, 0.28, 1.0),
		"accent": Color(0.38, 1.00, 0.44, 1.0),
		"accent_soft": Color(0.84, 1.00, 0.86, 1.0),
		"flash": Color(0.72, 1.00, 0.76, 1.0),
		"particle": Color(0.58, 1.00, 0.62, 1.0),
		"crit": Color(1.00, 0.92, 0.36, 1.0)
	}

	if "mage" in class_lower or "sage" in class_lower or "spellblade" in class_lower or "sorcer" in class_lower:
		theme["panel_bg"] = Color(0.06, 0.05, 0.12, 0.97)
		theme["panel_border"] = Color(0.56, 0.38, 1.00, 1.0)
		theme["row_bg"] = Color(0.05, 0.04, 0.10, 0.95)
		theme["row_border"] = Color(0.38, 0.28, 0.84, 1.0)
		theme["accent"] = Color(0.72, 0.54, 1.00, 1.0)
		theme["accent_soft"] = Color(0.90, 0.84, 1.00, 1.0)
		theme["flash"] = Color(0.84, 0.76, 1.00, 1.0)
		theme["particle"] = Color(0.74, 0.60, 1.00, 1.0)
		theme["crit"] = Color(1.00, 0.88, 0.44, 1.0)

	elif "knight" in class_lower or "paladin" in class_lower or "general" in class_lower:
		theme["panel_bg"] = Color(0.10, 0.08, 0.04, 0.97)
		theme["panel_border"] = Color(1.00, 0.82, 0.28, 1.0)
		theme["row_bg"] = Color(0.08, 0.06, 0.03, 0.95)
		theme["row_border"] = Color(0.78, 0.58, 0.20, 1.0)
		theme["accent"] = Color(1.00, 0.90, 0.40, 1.0)
		theme["accent_soft"] = Color(1.00, 0.97, 0.80, 1.0)
		theme["flash"] = Color(1.00, 0.94, 0.62, 1.0)
		theme["particle"] = Color(1.00, 0.86, 0.50, 1.0)
		theme["crit"] = Color(1.00, 0.95, 0.54, 1.0)

	elif "archer" in class_lower or "ranger" in class_lower or "bow" in class_lower or "sniper" in class_lower:
		theme["panel_bg"] = Color(0.06, 0.10, 0.05, 0.97)
		theme["panel_border"] = Color(0.46, 0.92, 0.34, 1.0)
		theme["row_bg"] = Color(0.05, 0.08, 0.04, 0.95)
		theme["row_border"] = Color(0.34, 0.70, 0.24, 1.0)
		theme["accent"] = Color(0.60, 1.00, 0.42, 1.0)
		theme["accent_soft"] = Color(0.88, 1.00, 0.82, 1.0)
		theme["flash"] = Color(0.78, 1.00, 0.66, 1.0)
		theme["particle"] = Color(0.66, 1.00, 0.52, 1.0)
		theme["crit"] = Color(1.00, 0.94, 0.48, 1.0)

	elif "thief" in class_lower or "assassin" in class_lower or "rogue" in class_lower:
		theme["panel_bg"] = Color(0.08, 0.05, 0.10, 0.97)
		theme["panel_border"] = Color(0.78, 0.34, 0.96, 1.0)
		theme["row_bg"] = Color(0.06, 0.04, 0.08, 0.95)
		theme["row_border"] = Color(0.56, 0.24, 0.78, 1.0)
		theme["accent"] = Color(0.94, 0.52, 1.00, 1.0)
		theme["accent_soft"] = Color(0.96, 0.84, 1.00, 1.0)
		theme["flash"] = Color(0.92, 0.72, 1.00, 1.0)
		theme["particle"] = Color(0.90, 0.60, 1.00, 1.0)
		theme["crit"] = Color(1.00, 0.90, 0.46, 1.0)

	elif "cleric" in class_lower or "monk" in class_lower or "divine" in class_lower or "healer" in class_lower:
		theme["panel_bg"] = Color(0.09, 0.09, 0.06, 0.97)
		theme["panel_border"] = Color(1.00, 0.88, 0.42, 1.0)
		theme["row_bg"] = Color(0.08, 0.08, 0.05, 0.95)
		theme["row_border"] = Color(0.80, 0.72, 0.28, 1.0)
		theme["accent"] = Color(1.00, 0.96, 0.60, 1.0)
		theme["accent_soft"] = Color(1.00, 1.00, 0.88, 1.0)
		theme["flash"] = Color(1.00, 0.97, 0.74, 1.0)
		theme["particle"] = Color(0.92, 1.00, 0.70, 1.0)
		theme["crit"] = Color(1.00, 0.96, 0.54, 1.0)

	elif "dragon" in class_lower or "monster" in class_lower:
		theme["panel_bg"] = Color(0.11, 0.05, 0.03, 0.97)
		theme["panel_border"] = Color(1.00, 0.42, 0.18, 1.0)
		theme["row_bg"] = Color(0.09, 0.04, 0.03, 0.95)
		theme["row_border"] = Color(0.78, 0.26, 0.14, 1.0)
		theme["accent"] = Color(1.00, 0.60, 0.24, 1.0)
		theme["accent_soft"] = Color(1.00, 0.86, 0.74, 1.0)
		theme["flash"] = Color(1.00, 0.76, 0.46, 1.0)
		theme["particle"] = Color(1.00, 0.60, 0.28, 1.0)
		theme["crit"] = Color(1.00, 0.92, 0.52, 1.0)

	elif "warrior" in class_lower or "berserk" in class_lower or "mercenary" in class_lower or "hero" in class_lower:
		theme["panel_bg"] = Color(0.10, 0.05, 0.05, 0.97)
		theme["panel_border"] = Color(1.00, 0.32, 0.28, 1.0)
		theme["row_bg"] = Color(0.08, 0.04, 0.04, 0.95)
		theme["row_border"] = Color(0.70, 0.22, 0.18, 1.0)
		theme["accent"] = Color(1.00, 0.46, 0.40, 1.0)
		theme["accent_soft"] = Color(1.00, 0.84, 0.80, 1.0)
		theme["flash"] = Color(1.00, 0.68, 0.58, 1.0)
		theme["particle"] = Color(1.00, 0.50, 0.42, 1.0)
		theme["crit"] = Color(1.00, 0.92, 0.50, 1.0)

	return theme


static func get_levelup_stat_visual(stat_key: String) -> Dictionary:
	match stat_key:
		"hp":
			return {"name": "HP", "icon": "â™¥", "color": Color(0.94, 0.32, 0.32, 1.0)}
		"str":
			return {"name": "STR", "icon": "âš”", "color": Color(1.00, 0.56, 0.20, 1.0)}
		"mag":
			return {"name": "MAG", "icon": "âœ¦", "color": Color(0.82, 0.48, 1.00, 1.0)}
		"def":
			return {"name": "DEF", "icon": "â¬¢", "color": Color(0.38, 0.82, 0.52, 1.0)}
		"res":
			return {"name": "RES", "icon": "âœš", "color": Color(0.38, 0.96, 0.92, 1.0)}
		"spd":
			return {"name": "SPD", "icon": "âž¤", "color": Color(0.44, 0.74, 1.00, 1.0)}
		"agi":
			return {"name": "AGI", "icon": "â–", "color": Color(1.00, 0.86, 0.42, 1.0)}
	return {"name": stat_key.to_upper(), "icon": "â€¢", "color": Color.WHITE}


static func create_levelup_icon_badge(icon_text: String, icon_color: Color) -> PanelContainer:
	var badge: PanelContainer = PanelContainer.new()
	badge.custom_minimum_size = Vector2(34, 34)
	badge.add_theme_stylebox_override("panel", make_levelup_style(
		Color(icon_color.r * 0.18, icon_color.g * 0.18, icon_color.b * 0.18, 1.0),
		icon_color,
		8
	))

	var icon_label: Label = Label.new()
	icon_label.text = icon_text
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_label.add_theme_font_size_override("font_size", 20)
	icon_label.add_theme_color_override("font_color", Color.WHITE)
	badge.add_child(icon_label)

	return badge


static func create_levelup_title_banner(root: VBoxContainer, title_text: String, theme: Dictionary) -> Dictionary:
	var panel_bg: Color = theme["panel_bg"]
	var panel_border: Color = theme["panel_border"]

	var title_panel: PanelContainer = PanelContainer.new()
	title_panel.custom_minimum_size = Vector2(0, 54)
	title_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_panel.modulate.a = 0.0
	title_panel.scale = Vector2(0.96, 0.96)
	title_panel.add_theme_stylebox_override("panel", make_levelup_style(
		panel_bg,
		panel_border,
		12
	))
	root.add_child(title_panel)

	var title_label: Label = Label.new()
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.96, 1.0, 0.96))
	title_panel.add_child(title_label)

	return {
		"panel": title_panel,
		"label": title_label
	}


static func create_levelup_header(field, unit: Node2D, old_level: int, new_level: int, theme: Dictionary) -> Dictionary:
	var root: VBoxContainer = get_levelup_dynamic_root(field)

	var panel_bg: Color = theme["panel_bg"]
	var panel_border: Color = theme["panel_border"]
	var accent_color: Color = theme["accent"]
	var accent_soft: Color = theme["accent_soft"]

	var header_panel: PanelContainer = PanelContainer.new()
	header_panel.custom_minimum_size = Vector2(0, 108)
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_panel.modulate.a = 0.0
	header_panel.scale = Vector2(0.96, 0.96)
	header_panel.add_theme_stylebox_override("panel", make_levelup_style(
		panel_bg,
		panel_border,
		12
	))
	root.add_child(header_panel)

	var outer: HBoxContainer = HBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 10
	outer.offset_top = 10
	outer.offset_right = -10
	outer.offset_bottom = -10
	outer.add_theme_constant_override("separation", 12)
	header_panel.add_child(outer)

	var portrait_bg: PanelContainer = PanelContainer.new()
	portrait_bg.custom_minimum_size = Vector2(76, 76)
	portrait_bg.add_theme_stylebox_override("panel", make_levelup_style(
		Color(panel_bg.r + 0.04, panel_bg.g + 0.04, panel_bg.b + 0.04, 1.0),
		accent_color,
		10
	))
	outer.add_child(portrait_bg)

	var portrait_holder: Control = Control.new()
	portrait_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_holder.position.x = -22
	portrait_holder.modulate.a = 0.0
	portrait_bg.add_child(portrait_holder)

	var portrait: TextureRect = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = 4
	portrait.offset_top = 4
	portrait.offset_right = -4
	portrait.offset_bottom = -4
	portrait_holder.add_child(portrait)

	if unit.get("data") != null and unit.data != null and unit.data.get("portrait") != null:
		portrait.texture = unit.data.portrait

	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 4)
	outer.add_child(info_box)

	var unit_name_text: String = str(unit.unit_name)

	var raw_class_value = unit.get("unit_class_name")
	var unit_class_text: String = "Unit"
	if raw_class_value != null:
		unit_class_text = str(raw_class_value)

	var name_label: Label = Label.new()
	name_label.text = unit_name_text + "  â€¢  " + unit_class_text
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.96, 1.0, 0.96))
	info_box.add_child(name_label)

	var level_label: Label = Label.new()
	if old_level != new_level:
		level_label.text = "LEVEL " + str(old_level) + "  â†’  " + str(new_level)
	else:
		level_label.text = "LEVEL " + str(new_level)
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.add_theme_color_override("font_color", accent_color)
	info_box.add_child(level_label)

	var exp_bar: ProgressBar = ProgressBar.new()
	exp_bar.min_value = 0.0
	exp_bar.max_value = 100.0
	exp_bar.value = 100.0
	exp_bar.show_percentage = false
	exp_bar.custom_minimum_size = Vector2(0, 18)
	exp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var exp_bg: StyleBoxFlat = StyleBoxFlat.new()
	exp_bg.bg_color = Color(0.08, 0.10, 0.08, 1.0)
	exp_bg.border_color = Color(0.18, 0.22, 0.18, 1.0)
	exp_bg.border_width_left = 1
	exp_bg.border_width_top = 1
	exp_bg.border_width_right = 1
	exp_bg.border_width_bottom = 1
	exp_bg.corner_radius_top_left = 7
	exp_bg.corner_radius_top_right = 7
	exp_bg.corner_radius_bottom_left = 7
	exp_bg.corner_radius_bottom_right = 7

	var exp_fill: StyleBoxFlat = StyleBoxFlat.new()
	exp_fill.bg_color = accent_color
	exp_fill.corner_radius_top_left = 7
	exp_fill.corner_radius_top_right = 7
	exp_fill.corner_radius_bottom_left = 7
	exp_fill.corner_radius_bottom_right = 7

	exp_bar.add_theme_stylebox_override("background", exp_bg)
	exp_bar.add_theme_stylebox_override("fill", exp_fill)
	info_box.add_child(exp_bar)

	var exp_label: Label = Label.new()
	exp_label.text = "POWER SURGE"
	exp_label.add_theme_font_size_override("font_size", 16)
	exp_label.add_theme_color_override("font_color", accent_soft)
	info_box.add_child(exp_label)

	return {
		"panel": header_panel,
		"portrait_holder": portrait_holder,
		"exp_bar": exp_bar,
		"exp_label": exp_label
	}


static func create_levelup_stat_row(container: VBoxContainer, stat_name: String, stat_key: String, start_value: int, end_value: int, gain: int, theme: Dictionary) -> Dictionary:
	var visual: Dictionary = get_levelup_stat_visual(stat_key)
	var icon_symbol: String = str(visual["icon"])
	var icon_color: Color = visual["color"]
	var is_critical: bool = gain >= 2

	var row_border_color: Color = icon_color if gain > 0 else Color(0.28, 0.28, 0.28, 1.0)
	if is_critical:
		row_border_color = theme["crit"]

	var row_bg_color: Color = theme["row_bg"]
	if is_critical:
		row_bg_color = Color(
			min(theme["row_bg"].r + 0.03, 1.0),
			min(theme["row_bg"].g + 0.03, 1.0),
			min(theme["row_bg"].b + 0.03, 1.0),
			theme["row_bg"].a
		)

	var row_panel: PanelContainer = PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 68 if is_critical else 62)
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.modulate.a = 0.0
	row_panel.scale = Vector2(0.96, 0.96)
	row_panel.add_theme_stylebox_override("panel", make_levelup_style(
		row_bg_color,
		row_border_color,
		8
	))
	container.add_child(row_panel)

	var outer: VBoxContainer = VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 10
	outer.offset_top = 7
	outer.offset_right = -10
	outer.offset_bottom = -7
	outer.add_theme_constant_override("separation", 6)
	row_panel.add_child(outer)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 8)
	outer.add_child(top_row)

	var badge: PanelContainer = create_levelup_icon_badge(icon_symbol, theme["crit"] if is_critical else icon_color)
	badge.custom_minimum_size = Vector2(34, 34)
	top_row.add_child(badge)

	var name_label: Label = Label.new()
	name_label.text = stat_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20 if not is_critical else 21)
	name_label.add_theme_color_override("font_color", Color(0.94, 1.0, 0.94) if gain > 0 else Color(0.85, 0.85, 0.85))
	top_row.add_child(name_label)

	var value_label: Label = Label.new()
	value_label.custom_minimum_size = Vector2(132, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.add_theme_color_override("font_color", theme["crit"] if is_critical else (Color(0.94, 1.0, 0.94) if gain > 0 else Color(0.86, 0.86, 0.86)))
	value_label.text = str(start_value) + " â†’ " + str(start_value) + "  (+" + str(gain) + ")" if gain > 0 else str(end_value)
	top_row.add_child(value_label)

	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = float(get_levelup_bar_cap(stat_key, end_value))
	bar.value = float(start_value)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 18 if not is_critical else 20)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.09, 0.12, 0.09, 1.0)
	bg_style.border_color = Color(0.18, 0.20, 0.18, 1.0)
	bg_style.border_width_left = 1
	bg_style.border_width_top = 1
	bg_style.border_width_right = 1
	bg_style.border_width_bottom = 1
	bg_style.corner_radius_top_left = 7
	bg_style.corner_radius_top_right = 7
	bg_style.corner_radius_bottom_left = 7
	bg_style.corner_radius_bottom_right = 7

	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = theme["crit"] if is_critical else (icon_color if gain > 0 else Color(0.24, 0.34, 0.24, 1.0))
	fill_style.corner_radius_top_left = 7
	fill_style.corner_radius_top_right = 7
	fill_style.corner_radius_bottom_left = 7
	fill_style.corner_radius_bottom_right = 7

	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)
	outer.add_child(bar)

	var sheen: ColorRect = attach_levelup_bar_sheen(bar)

	return {
		"row": row_panel,
		"bar": bar,
		"value_label": value_label,
		"badge": badge,
		"shine": sheen,
		"is_critical": is_critical,
		"start_value": start_value,
		"end_value": end_value,
		"gain": gain
	}


static func attach_levelup_bar_sheen(bar: ProgressBar) -> ColorRect:
	bar.clip_contents = true

	var sheen: ColorRect = ColorRect.new()
	sheen.name = "Sheen"
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheen.color = Color(1.0, 1.0, 1.0, 0.18)
	sheen.size = Vector2(46, max(28.0, bar.custom_minimum_size.y + 12.0))
	sheen.position = Vector2(-70, -8)
	sheen.rotation_degrees = 16.0
	sheen.modulate.a = 0.0
	bar.add_child(sheen)

	return sheen


static func animate_levelup_bar_sheen(field, sheen: ColorRect, bar: ProgressBar) -> void:
	if sheen == null or bar == null:
		return

	var bar_width: float = max(bar.size.x, bar.custom_minimum_size.x, 120.0)

	sheen.position = Vector2(-70, -8)
	sheen.modulate.a = 0.0

	var tw = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(sheen, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(sheen, "position:x", bar_width + 30.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(sheen, "modulate:a", 0.0, 0.10)


static func spawn_levelup_panel_particles(field, theme: Dictionary) -> CPUParticles2D:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.name = "LevelUpPanelParticles"
	particles.process_mode = Node.PROCESS_MODE_ALWAYS
	particles.position = Vector2(field.level_up_panel.size.x * 0.5, field.level_up_panel.size.y - 26.0)
	particles.amount = 42
	particles.lifetime = 2.2
	particles.preprocess = 1.0
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.direction = Vector2(0, -1)
	particles.spread = 24.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 18.0
	particles.initial_velocity_max = 42.0
	particles.scale_amount_min = 1.2
	particles.scale_amount_max = 3.4
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(max(40.0, field.level_up_panel.size.x * 0.42), 10.0)

	var grad: Gradient = Gradient.new()
	var particle_color: Color = theme["particle"]
	grad.add_point(0.0, Color(particle_color.r, particle_color.g, particle_color.b, 0.0))
	grad.add_point(0.18, Color(particle_color.r, particle_color.g, particle_color.b, 0.75))
	grad.add_point(0.70, Color(theme["flash"].r, theme["flash"].g, theme["flash"].b, 0.42))
	grad.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))
	particles.color_ramp = grad

	field.level_up_panel.add_child(particles)
	particles.emitting = true
	return particles


static func play_levelup_critical_row_fx(field, row_data: Dictionary, theme: Dictionary) -> void:
	var row_panel: PanelContainer = row_data.get("row") as PanelContainer
	var badge: PanelContainer = row_data.get("badge") as PanelContainer
	var bar: ProgressBar = row_data.get("bar") as ProgressBar

	if row_panel == null:
		return

	var flash: ColorRect = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(theme["crit"].r, theme["crit"].g, theme["crit"].b, 0.18)
	flash.modulate.a = 0.0
	row_panel.add_child(flash)

	var tw = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	row_panel.scale = Vector2(1.03, 1.03)
	row_panel.modulate = Color(1.20, 1.20, 1.20, 1.0)

	tw.tween_property(row_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(row_panel, "modulate", Color.WHITE, 0.24)
	tw.tween_property(flash, "modulate:a", 1.0, 0.08)
	tw.chain().tween_property(flash, "modulate:a", 0.0, 0.20)

	if badge != null:
		var badge_tw = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		badge.scale = Vector2(1.15, 1.15)
		badge_tw.tween_property(badge, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if bar != null:
		var sheen: ColorRect = row_data.get("shine") as ColorRect
		if sheen != null:
			animate_levelup_bar_sheen(field, sheen, bar)
			await field.get_tree().create_timer(0.10, true, false, true).timeout
			animate_levelup_bar_sheen(field, sheen, bar)

	if field.crit_sound != null and field.crit_sound.stream != null:
		field.crit_sound.pitch_scale = 1.08
		field.crit_sound.play()

	field.screen_shake(7.0, 0.18)

	await field.get_tree().create_timer(0.28, true, false, true).timeout
	if is_instance_valid(flash):
		flash.queue_free()


static func show_levelup_center_burst(field, main_text: String, accent_color: Color) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 170
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	field.add_child(layer)

	var vp_size: Vector2 = field.get_viewport_rect().size

	var flash_rect: ColorRect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = accent_color
	flash_rect.modulate.a = 0.0
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash_rect)

	var glow_label: Label = Label.new()
	glow_label.text = main_text
	glow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glow_label.size = Vector2(vp_size.x, 140)
	glow_label.position = Vector2(0, (vp_size.y - 140) * 0.5 - 90)
	glow_label.add_theme_font_size_override("font_size", 88)
	glow_label.add_theme_color_override("font_color", accent_color)
	glow_label.add_theme_constant_override("outline_size", 18)
	glow_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05, 1.0))
	glow_label.modulate.a = 0.0
	glow_label.scale = Vector2(0.50, 0.50)
	layer.add_child(glow_label)

	var main_label: Label = Label.new()
	main_label.text = main_text
	main_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main_label.size = Vector2(vp_size.x, 140)
	main_label.position = glow_label.position
	main_label.add_theme_font_size_override("font_size", 76)
	main_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	main_label.add_theme_constant_override("outline_size", 10)
	main_label.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.08, 1.0))
	main_label.modulate.a = 0.0
	main_label.scale = Vector2(0.38, 0.38)
	layer.add_child(main_label)

	var tw = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.tween_property(flash_rect, "modulate:a", 0.20, 0.08)
	tw.tween_property(glow_label, "modulate:a", 1.0, 0.14)
	tw.tween_property(main_label, "modulate:a", 1.0, 0.12)
	tw.tween_property(glow_label, "scale", Vector2(1.18, 1.18), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(main_label, "scale", Vector2(1.0, 1.0), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await field.get_tree().create_timer(0.34, true, false, true).timeout

	var tw_out = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw_out.tween_property(flash_rect, "modulate:a", 0.0, 0.18)
	tw_out.tween_property(glow_label, "modulate:a", 0.0, 0.20)
	tw_out.tween_property(main_label, "modulate:a", 0.0, 0.18)
	tw_out.tween_property(glow_label, "scale", Vector2(1.30, 1.30), 0.20)
	tw_out.tween_property(main_label, "scale", Vector2(1.10, 1.10), 0.20)

	await tw_out.finished
	layer.queue_free()


static func make_levelup_circle(radius: float, point_count: int, color: Color) -> Polygon2D:
	var poly: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()

	for i in range(point_count):
		var angle: float = (TAU * float(i)) / float(point_count)
		pts.append(Vector2(cos(angle), sin(angle)) * radius)

	poly.polygon = pts
	poly.color = color
	return poly


static func spawn_levelup_halo(unit: Node2D, accent_color: Color) -> Node2D:
	var halo_root: Node2D = Node2D.new()
	halo_root.name = "LevelUpHalo"
	halo_root.position = Vector2(32, 32)
	halo_root.show_behind_parent = true
	halo_root.z_index = -1
	halo_root.scale = Vector2(0.22, 0.22)
	halo_root.modulate.a = 0.0
	unit.add_child(halo_root)

	var outer: Polygon2D = make_levelup_circle(58.0, 40, Color(accent_color.r, accent_color.g, accent_color.b, 0.16))
	var middle: Polygon2D = make_levelup_circle(44.0, 40, Color(1.0, 0.90, 0.34, 0.18))
	var inner: Polygon2D = make_levelup_circle(30.0, 32, Color(1.0, 0.98, 0.72, 0.14))

	halo_root.add_child(outer)
	halo_root.add_child(middle)
	halo_root.add_child(inner)

	return halo_root


static func run_theatrical_stat_reveal(field, unit: Node2D, title_text: String, gains: Dictionary) -> void:
	field.get_tree().paused = true
	field.level_up_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	hide_legacy_levelup_nodes(field)

	var total_gains: int = 0
	var gained_rows: int = 0
	for val in gains.values():
		total_gains += int(val)
		if int(val) > 0:
			gained_rows += 1

	var is_perfect: bool = total_gains >= 5
	var title_lower: String = title_text.to_lower()
	var is_real_level_up: bool = title_lower.begins_with("level up")

	var theme: Dictionary = get_levelup_class_theme(unit)

	field.level_up_title.text = title_text
	field.level_up_title.modulate = theme["accent"] if not is_perfect else theme["crit"]

	var main_panel_style: StyleBoxFlat = make_levelup_style(theme["panel_bg"], theme["panel_border"], 18)
	field.level_up_panel.add_theme_stylebox_override("panel", main_panel_style)

	clear_levelup_dynamic_root(field)

	var flash_rect: ColorRect = ColorRect.new()
	flash_rect.size = field.get_viewport_rect().size
	flash_rect.color = theme["flash"]
	flash_rect.modulate.a = 0.0
	flash_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.get_node("UI").add_child(flash_rect)

	field.level_up_panel.scale = Vector2(0.84, 0.84)
	field.level_up_panel.modulate.a = 0.0
	field.level_up_panel.visible = true

	field.spawn_level_up_effect(unit.global_position)

	if is_perfect and field.epic_level_up_sound != null and field.epic_level_up_sound.stream != null:
		field.epic_level_up_sound.play()
	elif field.level_up_sound != null and field.level_up_sound.stream != null:
		field.level_up_sound.play()

	var burst_text: String = "LEVEL UP!" if is_real_level_up else "POWER SURGE!"
	await show_levelup_center_burst(field, burst_text, theme["flash"])

	var halo: Node2D = spawn_levelup_halo(unit, theme["accent"])
	var halo_tw = halo.create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	halo_tw.tween_property(halo, "modulate:a", 0.88, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	halo_tw.parallel().tween_property(halo, "scale", Vector2(1.0, 1.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	halo_tw.tween_property(halo, "modulate:a", 0.38, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	halo_tw.parallel().tween_property(halo, "scale", Vector2(0.88, 0.88), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var panel_particles: CPUParticles2D = spawn_levelup_panel_particles(field, theme)

	await field.get_tree().create_timer(0.20, true, false, true).timeout

	var open_tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	open_tween.tween_property(field.level_up_panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open_tween.tween_property(field.level_up_panel, "modulate:a", 1.0, 0.22)
	open_tween.tween_property(flash_rect, "modulate:a", 0.12, 0.08)
	open_tween.chain().tween_property(flash_rect, "modulate:a", 0.0, 0.22)
	await open_tween.finished

	await field.get_tree().process_frame

	var displayed_old_level: int = unit.level
	if is_real_level_up:
		displayed_old_level = max(1, unit.level - 1)

	var header_data: Dictionary = create_levelup_header(field, unit, displayed_old_level, unit.level, theme)
	var header_panel: PanelContainer = header_data["panel"]
	var portrait_holder: Control = header_data["portrait_holder"]
	var exp_bar: ProgressBar = header_data["exp_bar"]

	var header_tw = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	header_tw.tween_property(header_panel, "modulate:a", 1.0, 0.20)
	header_tw.tween_property(header_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	header_tw.tween_property(portrait_holder, "position:x", 0.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	header_tw.tween_property(portrait_holder, "modulate:a", 1.0, 0.20)
	header_tw.tween_property(exp_bar, "value", exp_bar.max_value, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await header_tw.finished

	await field.get_tree().create_timer(0.18, true, false, true).timeout

	var root: VBoxContainer = get_levelup_dynamic_root(field)

	var stat_order: Array[String] = ["hp", "str", "mag", "def", "res", "spd", "agi"]
	var row_entries: Array = []

	for stat_key in stat_order:
		var gain: int = int(gains.get(stat_key, 0))
		if gain <= 0:
			continue

		var visual: Dictionary = get_levelup_stat_visual(stat_key)
		var end_value: int = 0

		match stat_key:
			"hp":
				end_value = int(unit.max_hp)
			"str":
				end_value = int(unit.strength)
			"mag":
				end_value = int(unit.magic)
			"def":
				end_value = int(unit.defense)
			"res":
				end_value = int(unit.resistance)
			"spd":
				end_value = int(unit.speed)
			"agi":
				end_value = int(unit.agility)

		var start_value: int = end_value - gain

		var row_data: Dictionary = create_levelup_stat_row(
			root,
			str(visual["name"]),
			stat_key,
			start_value,
			end_value,
			gain,
			theme
		)
		row_entries.append(row_data)

	await field.get_tree().process_frame

	for row_data in row_entries:
		var row_panel: PanelContainer = row_data["row"]
		var bar: ProgressBar = row_data["bar"]
		var value_label: Label = row_data["value_label"]
		var sheen: ColorRect = row_data["shine"]
		var start_value: int = int(row_data["start_value"])
		var end_value: int = int(row_data["end_value"])
		var gain: int = int(row_data["gain"])
		var is_critical: bool = bool(row_data["is_critical"])

		var row_tw = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
		row_tw.tween_property(row_panel, "modulate:a", 1.0, 0.16)
		row_tw.tween_property(row_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		row_tw.tween_property(bar, "value", float(end_value), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		row_tw.tween_method(
			func(v: float):
				update_levelup_value_label(v, value_label, start_value, gain),
			float(start_value),
			float(end_value),
			0.42
		)

		if field.select_sound != null and field.select_sound.stream != null:
			field.select_sound.pitch_scale = 1.18 if not is_critical else 1.28
			field.select_sound.play()

		animate_levelup_bar_sheen(field, sheen, bar)

		await row_tw.finished

		if is_critical:
			await play_levelup_critical_row_fx(field, row_data, theme)
		else:
			field.screen_shake(3.0, 0.08)

		await field.get_tree().create_timer(field.LEVELUP_ROW_REVEAL_DELAY, true, false, true).timeout

	if field.select_sound != null and field.select_sound.stream != null:
		field.select_sound.pitch_scale = 1.0

	var hold_time: float = field.LEVELUP_HOLD_TIME_PERFECT if is_perfect else field.LEVELUP_HOLD_TIME_NORMAL
	hold_time += float(gained_rows) * 0.22

	await field.get_tree().create_timer(hold_time, true, false, true).timeout

	if panel_particles != null and is_instance_valid(panel_particles):
		panel_particles.emitting = false

	var exit_tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	exit_tween.tween_property(field.level_up_panel, "scale", Vector2(0.92, 0.92), 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	exit_tween.tween_property(field.level_up_panel, "modulate:a", 0.0, 0.24)
	if halo != null and is_instance_valid(halo):
		exit_tween.tween_property(halo, "modulate:a", 0.0, 0.20)

	await exit_tween.finished

	if panel_particles != null and is_instance_valid(panel_particles):
		panel_particles.queue_free()
	if halo != null and is_instance_valid(halo):
		halo.queue_free()
	if flash_rect != null and is_instance_valid(flash_rect):
		flash_rect.queue_free()

	field.level_up_panel.visible = false
	field.get_tree().paused = false
