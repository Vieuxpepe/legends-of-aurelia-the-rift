extends RefCounted

static func get_unit_target_for_details(field) -> Node2D:
	var locked_inspect_unit: Node2D = field._get_locked_inspect_unit()
	if locked_inspect_unit != null:
		return locked_inspect_unit
	var hovered_occupant: Node2D = field.get_occupant_at(field.cursor_grid_pos)
	if hovered_occupant != null:
		return hovered_occupant
	if field.current_state == field.player_state and field.player_state.active_unit != null:
		return field.player_state.active_unit
	return null



static func ensure_detailed_unit_info_panel(field) -> void:
	if field.detailed_unit_info_layer != null and is_instance_valid(field.detailed_unit_info_layer):
		return

	field.detailed_unit_info_primary_widgets.clear()
	field.detailed_unit_info_stat_widgets.clear()
	field.detailed_unit_info_growth_widgets.clear()

	field.detailed_unit_info_layer = CanvasLayer.new()
	field.detailed_unit_info_layer.layer = 120
	field.add_child(field.detailed_unit_info_layer)

	var dimmer = ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.color = Color(0, 0, 0, 0.78)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.visible = false
	field.detailed_unit_info_layer.add_child(dimmer)

	field.detailed_unit_info_panel = Panel.new()
	field.detailed_unit_info_panel.name = "DetailedUnitInfoPanel"
	field.detailed_unit_info_panel.custom_minimum_size = Vector2(1320, 860)
	field.detailed_unit_info_panel.visible = false
	field.detailed_unit_info_layer.add_child(field.detailed_unit_info_panel)

	field.detailed_unit_info_panel.anchor_left = 0.5
	field.detailed_unit_info_panel.anchor_top = 0.5
	field.detailed_unit_info_panel.anchor_right = 0.5
	field.detailed_unit_info_panel.anchor_bottom = 0.5
	field.detailed_unit_info_panel.offset_left = -660
	field.detailed_unit_info_panel.offset_top = -430
	field.detailed_unit_info_panel.offset_right = 660
	field.detailed_unit_info_panel.offset_bottom = 430
	field._style_tactical_panel(field.detailed_unit_info_panel, field.TACTICAL_UI_BG_ALT, field.TACTICAL_UI_BORDER, 2, 16)

	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	root.add_theme_constant_override("separation", 18)
	field.detailed_unit_info_panel.add_child(root)

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	root.add_child(header)

	var portrait_frame := Panel.new()
	portrait_frame.custom_minimum_size = Vector2(214, 214)
	field._style_tactical_panel(portrait_frame, field.TACTICAL_UI_BG_SOFT, field.TACTICAL_UI_BORDER_MUTED, 1, 12)
	header.add_child(portrait_frame)

	field.detailed_unit_info_portrait = TextureRect.new()
	field.detailed_unit_info_portrait.custom_minimum_size = Vector2(190, 190)
	field.detailed_unit_info_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	field.detailed_unit_info_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	field.detailed_unit_info_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	portrait_frame.add_child(field.detailed_unit_info_portrait)

	var name_box = VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 8)
	header.add_child(name_box)

	field.detailed_unit_info_name = Label.new()
	field._style_tactical_label(field.detailed_unit_info_name, field.TACTICAL_UI_ACCENT, 40, 3)
	name_box.add_child(field.detailed_unit_info_name)

	field.detailed_unit_info_meta_label = Label.new()
	field._style_tactical_label(field.detailed_unit_info_meta_label, field.TACTICAL_UI_TEXT_MUTED, 22, 2)
	name_box.add_child(field.detailed_unit_info_meta_label)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 3)
	divider.color = Color(field.TACTICAL_UI_BORDER.r, field.TACTICAL_UI_BORDER.g, field.TACTICAL_UI_BORDER.b, 0.55)
	name_box.add_child(divider)

	var weapon_row := HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 10)
	name_box.add_child(weapon_row)

	var weapon_pair_frame := Panel.new()
	weapon_pair_frame.custom_minimum_size = Vector2(114, 48)
	field._style_tactical_panel(weapon_pair_frame, Color(0.16, 0.13, 0.09, 0.94), field.TACTICAL_UI_BORDER_MUTED, 1, 8)
	weapon_row.add_child(weapon_pair_frame)

	var weapon_pair_inner := HBoxContainer.new()
	weapon_pair_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	weapon_pair_inner.add_theme_constant_override("separation", 6)
	weapon_pair_frame.add_child(weapon_pair_inner)

	var weapon_badge_panel := Panel.new()
	weapon_badge_panel.custom_minimum_size = Vector2(50, 32)
	field._style_tactical_panel(weapon_badge_panel, Color(0.24, 0.18, 0.10, 0.96), field.TACTICAL_UI_BORDER, 1, 7)
	weapon_pair_inner.add_child(weapon_badge_panel)

	field.detailed_unit_info_weapon_badge = Label.new()
	field.detailed_unit_info_weapon_badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
	field._style_tactical_label(field.detailed_unit_info_weapon_badge, field.TACTICAL_UI_ACCENT, 16, 2)
	field.detailed_unit_info_weapon_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.detailed_unit_info_weapon_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	weapon_badge_panel.add_child(field.detailed_unit_info_weapon_badge)

	var weapon_icon_panel := Panel.new()
	weapon_icon_panel.custom_minimum_size = Vector2(32, 32)
	field._style_tactical_panel(weapon_icon_panel, Color(0.11, 0.10, 0.08, 0.96), field.TACTICAL_UI_BORDER_MUTED, 1, 6)
	weapon_pair_inner.add_child(weapon_icon_panel)

	field.detailed_unit_info_weapon_icon = TextureRect.new()
	field.detailed_unit_info_weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	field.detailed_unit_info_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	field.detailed_unit_info_weapon_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
	weapon_icon_panel.add_child(field.detailed_unit_info_weapon_icon)

	field.detailed_unit_info_weapon_name = Label.new()
	field.detailed_unit_info_weapon_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field._style_tactical_label(field.detailed_unit_info_weapon_name, field.TACTICAL_UI_TEXT, 22, 2)
	weapon_row.add_child(field.detailed_unit_info_weapon_name)

	field.detailed_unit_info_summary_text = RichTextLabel.new()
	field.detailed_unit_info_summary_text.bbcode_enabled = true
	field.detailed_unit_info_summary_text.fit_content = true
	field.detailed_unit_info_summary_text.scroll_active = false
	field.detailed_unit_info_summary_text.custom_minimum_size = Vector2(0, 94)
	field._style_tactical_richtext(field.detailed_unit_info_summary_text, 22, 22)
	name_box.add_child(field.detailed_unit_info_summary_text)

	var close_box := VBoxContainer.new()
	close_box.alignment = BoxContainer.ALIGNMENT_END
	header.add_child(close_box)

	field.detailed_unit_info_close_btn = Button.new()
	field.detailed_unit_info_close_btn.custom_minimum_size = Vector2(196, 68)
	field._style_tactical_button(field.detailed_unit_info_close_btn, "Close", false, 26)
	field.detailed_unit_info_close_btn.pressed.connect(func():
		field._hide_detailed_unit_info_panel()
	)
	close_box.add_child(field.detailed_unit_info_close_btn)

	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	root.add_child(body)

	var left_panel = Panel.new()
	left_panel.custom_minimum_size = Vector2(560, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field._style_tactical_panel(left_panel, field.TACTICAL_UI_BG_SOFT, field.TACTICAL_UI_BORDER_MUTED, 1, 12)
	body.add_child(left_panel)

	var right_panel = Panel.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field._style_tactical_panel(right_panel, field.TACTICAL_UI_BG_SOFT, field.TACTICAL_UI_BORDER_MUTED, 1, 12)
	body.add_child(right_panel)

	var left_scroll := ScrollContainer.new()
	left_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	left_panel.add_child(left_scroll)

	var left_root := VBoxContainer.new()
	left_root.custom_minimum_size = Vector2(0, 760)
	left_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_root.add_theme_constant_override("separation", 14)
	left_scroll.add_child(left_root)

	var core_status_label := Label.new()
	field._style_tactical_label(core_status_label, field.TACTICAL_UI_ACCENT, 22, 2)
	core_status_label.text = "Core Status"
	left_root.add_child(core_status_label)

	var primary_root := VBoxContainer.new()
	primary_root.name = "DetailedUnitPrimaryBarsRoot"
	primary_root.add_theme_constant_override("separation", 10)
	left_root.add_child(primary_root)

	for bar_def in field._unit_info_primary_bar_definitions():
		var bar_key: String = str(bar_def.get("key", ""))
		var block := Panel.new()
		block.custom_minimum_size = Vector2(0, 102)
		field._style_tactical_panel(block, Color(0.10, 0.09, 0.07, 0.90), field.TACTICAL_UI_BORDER_MUTED, 1, 8)
		primary_root.add_child(block)

		var block_box := VBoxContainer.new()
		block_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		block_box.add_theme_constant_override("separation", 6)
		block.add_child(block_box)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		block_box.add_child(row)

		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var value_chip := Panel.new()
		value_chip.custom_minimum_size = Vector2(116, 28)
		row.add_child(value_chip)

		var value_label := Label.new()
		value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
		value_chip.add_child(value_label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 18)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block_box.add_child(bar)

		var desc_label := Label.new()
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.custom_minimum_size = Vector2(0, 34)
		block_box.add_child(desc_label)

		var sheen: ColorRect = field._attach_unit_info_bar_sheen(bar)
		field.detailed_unit_info_primary_widgets[bar_key] = {
			"panel": block,
			"name": name_label,
			"value_chip": value_chip,
			"value": value_label,
			"bar": bar,
			"desc": desc_label,
			"sheen": sheen,
		}

	field._ensure_detailed_unit_info_primary_widgets_style()

	var combat_profile_label := Label.new()
	field._style_tactical_label(combat_profile_label, field.TACTICAL_UI_ACCENT, 22, 2)
	combat_profile_label.text = "Combat Profile"
	left_root.add_child(combat_profile_label)

	var stat_root := GridContainer.new()
	stat_root.name = "DetailedUnitStatGrid"
	stat_root.columns = 1
	stat_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_root.add_theme_constant_override("h_separation", 0)
	stat_root.add_theme_constant_override("v_separation", 12)
	left_root.add_child(stat_root)

	for stat_def in field._unit_info_stat_definitions():
		var stat_key: String = str(stat_def.get("key", ""))
		var stat_block := Panel.new()
		stat_block.custom_minimum_size = Vector2(0, 92)
		stat_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field._style_tactical_panel(stat_block, Color(0.10, 0.09, 0.07, 0.88), field.TACTICAL_UI_BORDER_MUTED, 1, 6)
		stat_root.add_child(stat_block)

		var stat_box := VBoxContainer.new()
		stat_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		stat_box.add_theme_constant_override("separation", 6)
		stat_block.add_child(stat_box)

		var stat_row := HBoxContainer.new()
		stat_row.add_theme_constant_override("separation", 8)
		stat_box.add_child(stat_row)

		var stat_name := Label.new()
		stat_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_row.add_child(stat_name)

		var stat_hints := HBoxContainer.new()
		stat_hints.add_theme_constant_override("separation", 4)
		stat_row.add_child(stat_hints)

		var stat_value_chip := Panel.new()
		stat_value_chip.custom_minimum_size = Vector2(88, 28)
		stat_row.add_child(stat_value_chip)

		var stat_value_label := Label.new()
		stat_value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 1)
		stat_value_chip.add_child(stat_value_label)

		var stat_bar := ProgressBar.new()
		stat_bar.custom_minimum_size = Vector2(0, 16)
		stat_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_box.add_child(stat_bar)

		var stat_desc := Label.new()
		stat_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stat_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_box.add_child(stat_desc)

		var stat_sheen: ColorRect = field._attach_unit_info_bar_sheen(stat_bar)
		field.detailed_unit_info_stat_widgets[stat_key] = {
			"panel": stat_block,
			"name": stat_name,
			"hints": stat_hints,
			"value_chip": stat_value_chip,
			"value": stat_value_label,
			"bar": stat_bar,
			"desc": stat_desc,
			"sheen": stat_sheen,
		}

	var right_root := VBoxContainer.new()
	right_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
	right_root.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_root)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_root.add_child(right_scroll)

	var right_content := VBoxContainer.new()
	right_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_content.add_theme_constant_override("separation", 14)
	right_scroll.add_child(right_content)

	var growth_title := Label.new()
	field._style_tactical_label(growth_title, field.TACTICAL_UI_ACCENT, 22, 2)
	growth_title.text = "Growth Outlook"
	right_content.add_child(growth_title)

	var growth_root := VBoxContainer.new()
	growth_root.name = "DetailedUnitGrowthRoot"
	growth_root.add_theme_constant_override("separation", 8)
	right_content.add_child(growth_root)

	for growth_def in [
		{"key": "hp_growth_bonus", "label": "HP", "base": "hp"},
		{"key": "str_growth_bonus", "label": "STR", "base": "strength"},
		{"key": "mag_growth_bonus", "label": "MAG", "base": "magic"},
		{"key": "def_growth_bonus", "label": "DEF", "base": "defense"},
		{"key": "res_growth_bonus", "label": "RES", "base": "resistance"},
		{"key": "spd_growth_bonus", "label": "SPD", "base": "speed"},
		{"key": "agi_growth_bonus", "label": "AGI", "base": "agility"},
	]:
		var growth_key: String = str(growth_def.get("key", ""))
		var growth_block := Panel.new()
		growth_block.custom_minimum_size = Vector2(0, 48)
		field._style_tactical_panel(growth_block, Color(0.10, 0.09, 0.07, 0.84), field.TACTICAL_UI_BORDER_MUTED, 1, 7)
		growth_root.add_child(growth_block)

		var growth_box := VBoxContainer.new()
		growth_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		growth_box.add_theme_constant_override("separation", 2)
		growth_block.add_child(growth_box)

		var growth_row := HBoxContainer.new()
		growth_row.add_theme_constant_override("separation", 8)
		growth_box.add_child(growth_row)

		var growth_name := Label.new()
		growth_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		growth_row.add_child(growth_name)

		var growth_value_chip := Panel.new()
		growth_value_chip.custom_minimum_size = Vector2(92, 22)
		growth_row.add_child(growth_value_chip)

		var growth_value_label := Label.new()
		growth_value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 1)
		growth_value_chip.add_child(growth_value_label)

		var growth_bar := ProgressBar.new()
		growth_bar.custom_minimum_size = Vector2(0, 14)
		growth_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		growth_box.add_child(growth_bar)

		var growth_sheen: ColorRect = field._attach_unit_info_bar_sheen(growth_bar)
		field.detailed_unit_info_growth_widgets[growth_key] = {
			"panel": growth_block,
			"name": growth_name,
			"value_chip": growth_value_chip,
			"value": growth_value_label,
			"bar": growth_bar,
			"sheen": growth_sheen,
			"base_key": String(growth_def.get("base", "")),
			"label": String(growth_def.get("label", growth_key)),
		}

	var rel_title := Label.new()
	field._style_tactical_label(rel_title, field.TACTICAL_UI_ACCENT, 22, 2)
	rel_title.text = "Bond Network"
	right_content.add_child(rel_title)

	field.detailed_unit_info_relationships_root = VBoxContainer.new()
	field.detailed_unit_info_relationships_root.add_theme_constant_override("separation", 10)
	right_content.add_child(field.detailed_unit_info_relationships_root)

	var right_title := Label.new()
	field._style_tactical_label(right_title, field.TACTICAL_UI_ACCENT, 22, 2)
	right_title.text = "Field Record"
	right_content.add_child(right_title)

	field.detailed_unit_info_right_text = RichTextLabel.new()
	field.detailed_unit_info_right_text.bbcode_enabled = true
	field.detailed_unit_info_right_text.fit_content = false
	field.detailed_unit_info_right_text.scroll_active = false
	field.detailed_unit_info_right_text.custom_minimum_size = Vector2(0, 300)
	field.detailed_unit_info_right_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field._style_tactical_richtext(field.detailed_unit_info_right_text, 24, 24)
	right_content.add_child(field.detailed_unit_info_right_text)

	field.detailed_unit_info_left_text = null
			

static func show_detailed_unit_info_panel(field, unit: Node2D) -> void:
	field._ensure_detailed_unit_info_panel()

	if unit == null:
		return

	var dimmer = field.detailed_unit_info_layer.get_node("Dimmer")
	dimmer.visible = true
	field.detailed_unit_info_panel.visible = true

	var portrait_tex: Texture2D = null
	if unit.get("data") != null and unit.data.get("portrait") != null:
		portrait_tex = unit.data.portrait
	elif unit.get("active_class_data") != null and unit.active_class_data.get("promoted_portrait") != null:
		portrait_tex = unit.active_class_data.promoted_portrait

	field.detailed_unit_info_portrait.texture = portrait_tex
	field.detailed_unit_info_name.text = unit.unit_name
	field.detailed_unit_info_meta_label.text = field._build_detailed_unit_info_meta_line(unit)
	field._populate_detailed_unit_info_weapon_row(unit)
	field.detailed_unit_info_summary_text.bbcode_text = field._build_detailed_unit_info_summary_text(unit)
	field.detailed_unit_info_right_text.bbcode_text = field._build_detailed_unit_info_record_text(unit)
	field._build_detailed_unit_info_relationship_cards(unit)
	field._refresh_detailed_unit_info_visuals(unit, true)
	

static func hide_detailed_unit_info_panel(field) -> void:
	if field.detailed_unit_info_panel == null:
		return

	if field.detailed_unit_info_anim_tween != null:
		field.detailed_unit_info_anim_tween.kill()
		field.detailed_unit_info_anim_tween = null
	var dimmer = field.detailed_unit_info_layer.get_node("Dimmer")
	dimmer.visible = false
	field.detailed_unit_info_panel.visible = false


static func build_detailed_unit_info_text(field, unit: Node2D) -> String:
	if unit == null:
		return "[center]No unit selected.[/center]"

	var lines: Array[String] = []

	var class_label: String = "Unknown"
	var class_res: Resource = null
	if unit.get("active_class_data") != null:
		class_res = unit.active_class_data

	if class_res != null and class_res.get("job_name") != null:
		class_label = class_res.job_name
	elif unit.get("unit_class_name") != null:
		class_label = unit.unit_class_name

	lines.append("[font_size=30][b]" + unit.unit_name + "[/b][/font_size]")
	lines.append("Class: [color=cyan]" + class_label + "[/color]")
	lines.append("Level: " + str(unit.level) + "    XP: " + str(unit.experience))
	lines.append("Move: " + str(unit.move_range))
	lines.append("")

	lines.append("[color=gold][b]STATS[/b][/color]")
	lines.append("HP: " + str(unit.current_hp) + " / " + str(unit.max_hp))
	lines.append("STR: " + str(unit.strength) + "    MAG: " + str(unit.magic))
	lines.append("DEF: " + str(unit.defense) + "    RES: " + str(unit.resistance))
	lines.append("SPD: " + str(unit.speed) + "    AGI: " + str(unit.agility))
	lines.append("")

	if unit.equipped_weapon != null:
		lines.append("[color=gold][b]EQUIPPED WEAPON[/b][/color]")
		lines.append(unit.equipped_weapon.weapon_name + " (" + field._weapon_type_name_safe(int(unit.equipped_weapon.weapon_type)) + ")")
		lines.append("Mt: " + str(unit.equipped_weapon.might) + "    Hit: +" + str(unit.equipped_weapon.hit_bonus))
		lines.append("Range: " + str(unit.equipped_weapon.min_range) + "-" + str(unit.equipped_weapon.max_range))
		if unit.equipped_weapon.get("current_durability") != null:
			lines.append("Durability: " + str(unit.equipped_weapon.current_durability) + " / " + str(unit.equipped_weapon.max_durability))
		lines.append("")
	else:
		lines.append("[color=gold][b]EQUIPPED WEAPON[/b][/color]")
		lines.append("None")
		lines.append("")

	if class_res != null:
		lines.append("[color=gold][b]WEAPON PERMISSIONS[/b][/color]")
		lines.append(field._format_class_weapon_permissions(class_res))
		lines.append("")

		lines.append("[color=gold][b]CLASS BONUSES[/b][/color]")
		var class_bonus_parts: Array[String] = []

		if class_res.get("hp_bonus") != null and int(class_res.hp_bonus) != 0:
			class_bonus_parts.append("HP %+d" % int(class_res.hp_bonus))
		if class_res.get("str_bonus") != null and int(class_res.str_bonus) != 0:
			class_bonus_parts.append("STR %+d" % int(class_res.str_bonus))
		if class_res.get("mag_bonus") != null and int(class_res.mag_bonus) != 0:
			class_bonus_parts.append("MAG %+d" % int(class_res.mag_bonus))
		if class_res.get("def_bonus") != null and int(class_res.def_bonus) != 0:
			class_bonus_parts.append("DEF %+d" % int(class_res.def_bonus))
		if class_res.get("res_bonus") != null and int(class_res.res_bonus) != 0:
			class_bonus_parts.append("RES %+d" % int(class_res.res_bonus))
		if class_res.get("spd_bonus") != null and int(class_res.spd_bonus) != 0:
			class_bonus_parts.append("SPD %+d" % int(class_res.spd_bonus))
		if class_res.get("agi_bonus") != null and int(class_res.agi_bonus) != 0:
			class_bonus_parts.append("AGI %+d" % int(class_res.agi_bonus))

		if class_bonus_parts.is_empty():
			lines.append("None")
		else:
			lines.append(", ".join(class_bonus_parts))
		lines.append("")

		lines.append("[color=gold][b]GROWTH BONUSES[/b][/color]")
		var growth_parts: Array[String] = []

		if class_res.get("hp_growth_bonus") != null and int(class_res.hp_growth_bonus) != 0:
			growth_parts.append("HP %+d%%" % int(class_res.hp_growth_bonus))
		if class_res.get("str_growth_bonus") != null and int(class_res.str_growth_bonus) != 0:
			growth_parts.append("STR %+d%%" % int(class_res.str_growth_bonus))
		if class_res.get("mag_growth_bonus") != null and int(class_res.mag_growth_bonus) != 0:
			growth_parts.append("MAG %+d%%" % int(class_res.mag_growth_bonus))
		if class_res.get("def_growth_bonus") != null and int(class_res.def_growth_bonus) != 0:
			growth_parts.append("DEF %+d%%" % int(class_res.def_growth_bonus))
		if class_res.get("res_growth_bonus") != null and int(class_res.res_growth_bonus) != 0:
			growth_parts.append("RES %+d%%" % int(class_res.res_growth_bonus))
		if class_res.get("spd_growth_bonus") != null and int(class_res.spd_growth_bonus) != 0:
			growth_parts.append("SPD %+d%%" % int(class_res.spd_growth_bonus))
		if class_res.get("agi_growth_bonus") != null and int(class_res.agi_growth_bonus) != 0:
			growth_parts.append("AGI %+d%%" % int(class_res.agi_growth_bonus))

		if growth_parts.is_empty():
			lines.append("None")
		else:
			lines.append(", ".join(growth_parts))
		lines.append("")

		lines.append("[color=gold][b]PROMOTION BONUSES[/b][/color]")
		var promo_parts: Array[String] = []

		if class_res.get("promo_hp_bonus") != null and int(class_res.promo_hp_bonus) != 0:
			promo_parts.append("HP %+d" % int(class_res.promo_hp_bonus))
		if class_res.get("promo_str_bonus") != null and int(class_res.promo_str_bonus) != 0:
			promo_parts.append("STR %+d" % int(class_res.promo_str_bonus))
		if class_res.get("promo_mag_bonus") != null and int(class_res.promo_mag_bonus) != 0:
			promo_parts.append("MAG %+d" % int(class_res.promo_mag_bonus))
		if class_res.get("promo_def_bonus") != null and int(class_res.promo_def_bonus) != 0:
			promo_parts.append("DEF %+d" % int(class_res.promo_def_bonus))
		if class_res.get("promo_res_bonus") != null and int(class_res.promo_res_bonus) != 0:
			promo_parts.append("RES %+d" % int(class_res.promo_res_bonus))
		if class_res.get("promo_spd_bonus") != null and int(class_res.promo_spd_bonus) != 0:
			promo_parts.append("SPD %+d" % int(class_res.promo_spd_bonus))
		if class_res.get("promo_agi_bonus") != null and int(class_res.promo_agi_bonus) != 0:
			promo_parts.append("AGI %+d" % int(class_res.promo_agi_bonus))

		if promo_parts.is_empty():
			lines.append("None")
		else:
			lines.append(", ".join(promo_parts))
		lines.append("")

	if "unlocked_abilities" in unit and unit.unlocked_abilities.size() > 0:
		lines.append("[color=gold][b]ABILITIES[/b][/color]")
		lines.append(", ".join(unit.unlocked_abilities))
		lines.append("")
	elif unit.get("ability") != null and str(unit.ability) != "":
		lines.append("[color=gold][b]ABILITY[/b][/color]")
		lines.append(str(unit.ability))
		lines.append("")

	if "inventory" in unit and unit.inventory.size() > 0:
		lines.append("[color=gold][b]INVENTORY[/b][/color]")
		for item in unit.inventory:
			if item == null:
				continue

			var item_name: String = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
			var marker: String = ""
			if item is WeaponData:
				marker = " [color=lime](usable)[/color]" if field._unit_can_use_item_for_ui(unit, item) else " [color=red](locked)[/color]"
			lines.append("• " + str(item_name) + marker)

	return "[font_size=26]" + "\n".join(lines) + "[/font_size]"
			

static func build_detailed_unit_info_left_text(field, unit: Node2D) -> String:
	if unit == null:
		return "[center]No unit selected.[/center]"

	var lines: Array[String] = []

	var class_label: String = "Unknown"
	var class_res: Resource = null
	if unit.get("active_class_data") != null:
		class_res = unit.active_class_data

	if class_res != null and class_res.get("job_name") != null:
		class_label = class_res.job_name
	elif unit.get("unit_class_name") != null:
		class_label = unit.unit_class_name

	lines.append("[font_size=28]" + unit.unit_name + "[/font_size]")
	lines.append("Class: [color=cyan]" + class_label + "[/color]")
	lines.append("Level: " + str(unit.level) + "    XP: " + str(unit.experience))
	lines.append("Move: " + str(unit.move_range))
	lines.append("")

	lines.append("[color=gold]Stats[/color]")
	lines.append("HP: " + str(unit.current_hp) + " / " + str(unit.max_hp))
	lines.append("[color=coral]STR:[/color] " + str(unit.strength) + "    [color=orchid]MAG:[/color] " + str(unit.magic))
	lines.append("[color=palegreen]DEF:[/color] " + str(unit.defense) + "    [color=aquamarine]RES:[/color] " + str(unit.resistance))
	lines.append("[color=skyblue]SPD:[/color] " + str(unit.speed) + "    [color=wheat]AGI:[/color] " + str(unit.agility))

	var poise_text := "?"
	if unit.has_method("get_current_poise") and unit.has_method("get_max_poise"):
		poise_text = str(unit.get_current_poise()) + "/" + str(unit.get_max_poise())
	lines.append("[color=gold]POISE:[/color] " + poise_text)
	lines.append("")

	lines.append("[color=gold]Equipped Weapon[/color]")
	if unit.equipped_weapon != null:
		lines.append(unit.equipped_weapon.weapon_name + " (" + field._weapon_type_name_safe(int(unit.equipped_weapon.weapon_type)) + ")")
		lines.append("Mt: " + str(unit.equipped_weapon.might) + "    Hit: +" + str(unit.equipped_weapon.hit_bonus))
		lines.append("Range: " + str(unit.equipped_weapon.min_range) + "-" + str(unit.equipped_weapon.max_range))
		if unit.equipped_weapon.get("current_durability") != null:
			lines.append("Durability: " + str(unit.equipped_weapon.current_durability) + " / " + str(unit.equipped_weapon.max_durability))
	else:
		lines.append("None")
	lines.append("")

	if class_res != null:
		lines.append("[color=gold]Weapon Permissions[/color]")
		lines.append(field._format_class_weapon_permissions(class_res))
		lines.append("")

		lines.append("[color=gold]Class Bonuses[/color]")
		var class_bonus_parts: Array[String] = []

		if class_res.get("hp_bonus") != null and int(class_res.hp_bonus) != 0:
			class_bonus_parts.append("HP %+d" % int(class_res.hp_bonus))
		if class_res.get("str_bonus") != null and int(class_res.str_bonus) != 0:
			class_bonus_parts.append("[color=coral]STR %+d[/color]" % int(class_res.str_bonus))
		if class_res.get("mag_bonus") != null and int(class_res.mag_bonus) != 0:
			class_bonus_parts.append("[color=orchid]MAG %+d[/color]" % int(class_res.mag_bonus))
		if class_res.get("def_bonus") != null and int(class_res.def_bonus) != 0:
			class_bonus_parts.append("[color=palegreen]DEF %+d[/color]" % int(class_res.def_bonus))
		if class_res.get("res_bonus") != null and int(class_res.res_bonus) != 0:
			class_bonus_parts.append("[color=aquamarine]RES %+d[/color]" % int(class_res.res_bonus))
		if class_res.get("spd_bonus") != null and int(class_res.spd_bonus) != 0:
			class_bonus_parts.append("[color=skyblue]SPD %+d[/color]" % int(class_res.spd_bonus))
		if class_res.get("agi_bonus") != null and int(class_res.agi_bonus) != 0:
			class_bonus_parts.append("[color=wheat]AGI %+d[/color]" % int(class_res.agi_bonus))

		lines.append("None" if class_bonus_parts.is_empty() else ", ".join(class_bonus_parts))
		lines.append("")

		lines.append("[color=gold]Growth Bonuses[/color]")
		var growth_parts: Array[String] = []

		if class_res.get("hp_growth_bonus") != null and int(class_res.hp_growth_bonus) != 0:
			growth_parts.append("HP %+d%%" % int(class_res.hp_growth_bonus))
		if class_res.get("str_growth_bonus") != null and int(class_res.str_growth_bonus) != 0:
			growth_parts.append("[color=coral]STR %+d%%[/color]" % int(class_res.str_growth_bonus))
		if class_res.get("mag_growth_bonus") != null and int(class_res.mag_growth_bonus) != 0:
			growth_parts.append("[color=orchid]MAG %+d%%[/color]" % int(class_res.mag_growth_bonus))
		if class_res.get("def_growth_bonus") != null and int(class_res.def_growth_bonus) != 0:
			growth_parts.append("[color=palegreen]DEF %+d%%[/color]" % int(class_res.def_growth_bonus))
		if class_res.get("res_growth_bonus") != null and int(class_res.res_growth_bonus) != 0:
			growth_parts.append("[color=aquamarine]RES %+d%%[/color]" % int(class_res.res_growth_bonus))
		if class_res.get("spd_growth_bonus") != null and int(class_res.spd_growth_bonus) != 0:
			growth_parts.append("[color=skyblue]SPD %+d%%[/color]" % int(class_res.spd_growth_bonus))
		if class_res.get("agi_growth_bonus") != null and int(class_res.agi_growth_bonus) != 0:
			growth_parts.append("[color=wheat]AGI %+d%%[/color]" % int(class_res.agi_growth_bonus))

		lines.append("None" if growth_parts.is_empty() else ", ".join(growth_parts))
		lines.append("")

		lines.append("[color=gold]Promotion Bonuses[/color]")
		var promo_parts: Array[String] = []

		if class_res.get("promo_hp_bonus") != null and int(class_res.promo_hp_bonus) != 0:
			promo_parts.append("HP %+d" % int(class_res.promo_hp_bonus))
		if class_res.get("promo_str_bonus") != null and int(class_res.promo_str_bonus) != 0:
			promo_parts.append("[color=coral]STR %+d[/color]" % int(class_res.promo_str_bonus))
		if class_res.get("promo_mag_bonus") != null and int(class_res.promo_mag_bonus) != 0:
			promo_parts.append("[color=orchid]MAG %+d[/color]" % int(class_res.promo_mag_bonus))
		if class_res.get("promo_def_bonus") != null and int(class_res.promo_def_bonus) != 0:
			promo_parts.append("[color=palegreen]DEF %+d[/color]" % int(class_res.promo_def_bonus))
		if class_res.get("promo_res_bonus") != null and int(class_res.promo_res_bonus) != 0:
			promo_parts.append("[color=aquamarine]RES %+d[/color]" % int(class_res.promo_res_bonus))
		if class_res.get("promo_spd_bonus") != null and int(class_res.promo_spd_bonus) != 0:
			promo_parts.append("[color=skyblue]SPD %+d[/color]" % int(class_res.promo_spd_bonus))
		if class_res.get("promo_agi_bonus") != null and int(class_res.promo_agi_bonus) != 0:
			promo_parts.append("[color=wheat]AGI %+d[/color]" % int(class_res.promo_agi_bonus))

		lines.append("None" if promo_parts.is_empty() else ", ".join(promo_parts))

	return "[font_size=24]" + "\n".join(lines) + "[/font_size]"
	

static func build_detailed_unit_info_right_text(field, unit: Node2D) -> String:
	if unit == null:
		return ""

	var lines: Array[String] = []
	var class_res: Resource = null
	if unit.get("active_class_data") != null:
		class_res = unit.active_class_data

	lines.append("[color=gold]Class Profile[/color]")
	lines.append("Class: [color=cyan]%s[/color]" % field._resolve_detailed_unit_info_class_label(unit))
	lines.append("Move: %d" % (int(unit.get("move_range")) if unit.get("move_range") != null else 0))
	lines.append("")

	if class_res != null:
		lines.append("[color=gold]Weapon Permissions[/color]")
		lines.append(field._format_class_weapon_permissions(class_res))
		lines.append("")

		lines.append("[color=gold]Class Bonuses[/color]")
		var class_bonus_parts: Array[String] = []
		if class_res.get("hp_bonus") != null and int(class_res.hp_bonus) != 0:
			class_bonus_parts.append("HP %+d" % int(class_res.hp_bonus))
		if class_res.get("str_bonus") != null and int(class_res.str_bonus) != 0:
			class_bonus_parts.append("[color=coral]STR %+d[/color]" % int(class_res.str_bonus))
		if class_res.get("mag_bonus") != null and int(class_res.mag_bonus) != 0:
			class_bonus_parts.append("[color=orchid]MAG %+d[/color]" % int(class_res.mag_bonus))
		if class_res.get("def_bonus") != null and int(class_res.def_bonus) != 0:
			class_bonus_parts.append("[color=palegreen]DEF %+d[/color]" % int(class_res.def_bonus))
		if class_res.get("res_bonus") != null and int(class_res.res_bonus) != 0:
			class_bonus_parts.append("[color=aquamarine]RES %+d[/color]" % int(class_res.res_bonus))
		if class_res.get("spd_bonus") != null and int(class_res.spd_bonus) != 0:
			class_bonus_parts.append("[color=skyblue]SPD %+d[/color]" % int(class_res.spd_bonus))
		if class_res.get("agi_bonus") != null and int(class_res.agi_bonus) != 0:
			class_bonus_parts.append("[color=wheat]AGI %+d[/color]" % int(class_res.agi_bonus))
		lines.append("None" if class_bonus_parts.is_empty() else ", ".join(class_bonus_parts))
		lines.append("")

		lines.append("[color=gold]Promotion Bonuses[/color]")
		var promo_parts: Array[String] = []
		if class_res.get("promo_hp_bonus") != null and int(class_res.promo_hp_bonus) != 0:
			promo_parts.append("HP %+d" % int(class_res.promo_hp_bonus))
		if class_res.get("promo_str_bonus") != null and int(class_res.promo_str_bonus) != 0:
			promo_parts.append("[color=coral]STR %+d[/color]" % int(class_res.promo_str_bonus))
		if class_res.get("promo_mag_bonus") != null and int(class_res.promo_mag_bonus) != 0:
			promo_parts.append("[color=orchid]MAG %+d[/color]" % int(class_res.promo_mag_bonus))
		if class_res.get("promo_def_bonus") != null and int(class_res.promo_def_bonus) != 0:
			promo_parts.append("[color=palegreen]DEF %+d[/color]" % int(class_res.promo_def_bonus))
		if class_res.get("promo_res_bonus") != null and int(class_res.promo_res_bonus) != 0:
			promo_parts.append("[color=aquamarine]RES %+d[/color]" % int(class_res.promo_res_bonus))
		if class_res.get("promo_spd_bonus") != null and int(class_res.promo_spd_bonus) != 0:
			promo_parts.append("[color=skyblue]SPD %+d[/color]" % int(class_res.promo_spd_bonus))
		if class_res.get("promo_agi_bonus") != null and int(class_res.promo_agi_bonus) != 0:
			promo_parts.append("[color=wheat]AGI %+d[/color]" % int(class_res.promo_agi_bonus))
		lines.append("None" if promo_parts.is_empty() else ", ".join(promo_parts))
		lines.append("")

	if "unlocked_abilities" in unit and unit.unlocked_abilities.size() > 0:
		lines.append("[color=gold]Abilities[/color]")
		lines.append(", ".join(unit.unlocked_abilities))
		lines.append("")
	elif unit.get("ability") != null and str(unit.ability) != "":
		lines.append("[color=gold]Ability[/color]")
		lines.append(str(unit.ability))
		lines.append("")

	lines.append("[color=gold]Inventory[/color]")
	if "inventory" in unit and unit.inventory.size() > 0:
		for item in unit.inventory:
			if item == null:
				continue

			var item_name: String = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
			var marker: String = ""

			if item is WeaponData:
				marker = " [color=lime](usable)[/color]" if field._unit_can_use_item_for_ui(unit, item) else " [color=red](locked)[/color]"

				var w_type: String = field._weapon_type_name_safe(int(item.weapon_type))
				var extra := " | Mt " + str(item.might) + " | Hit +" + str(item.hit_bonus) + " | Rng " + str(item.min_range) + "-" + str(item.max_range)
				lines.append("• " + str(item_name) + " (" + w_type + ")" + marker)
				lines.append("   " + extra)
			else:
				lines.append("• " + str(item_name))
	else:
		lines.append("None")

	# --- Relationships section (trust, mentorship, rivalry; top entries among deployed) ---
	lines.append("")
	lines.append("[color=gold]Relationships[/color]")
	var unit_id: String = field.get_relationship_id(unit)
	var candidate_ids: Array = []
	if field.player_container != null:
		for u in field.player_container.get_children():
			if is_instance_valid(u) and u != unit:
				candidate_ids.append(field.get_relationship_id(u))
	var rel_entries: Array = CampaignManager.get_top_relationship_entries_for_unit(unit_id, candidate_ids, 9)
	if rel_entries.is_empty():
		lines.append("No notable bonds yet.")
	else:
		for entry in rel_entries:
			lines.append("• " + CampaignManager.format_relationship_row_bbcode(entry))

	lines.append("")
	lines.append("[color=gold]Notes[/color]")
	lines.append("Green = usable")
	lines.append("Red = class locked")

	return "[font_size=24]" + "\n".join(lines) + "[/font_size]"


static func on_unit_details_button_pressed(field) -> void:
	var target_unit = field._get_unit_target_for_details()
	if target_unit != null:
		field._show_detailed_unit_info_panel(target_unit)
