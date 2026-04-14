extends RefCounted

# Detailed unit info modal: meta/summary/record text, relationship cards, growth widgets,
# primary+stat panel refresh + animation orchestration — extracted from `BattleField.gd`.
# Scene-graph construction stays in `BattleFieldDetailedUnitInfoHelpers.gd`; bottom-bar widgets stay in `BattleFieldDetailedUnitInfoRuntimeHelpers.gd`.


static func ensure_detailed_unit_info_primary_widgets_style(field) -> void:
	for bar_def in field._unit_info_primary_bar_definitions():
		var bar_key: String = str(bar_def.get("key", ""))
		if not field.detailed_unit_info_primary_widgets.has(bar_key):
			continue
		var widgets: Dictionary = field.detailed_unit_info_primary_widgets[bar_key]
		var name_label := widgets.get("name") as Label
		var value_chip := widgets.get("value_chip") as Panel
		var value_label := widgets.get("value") as Label
		var bar := widgets.get("bar") as ProgressBar
		var desc_label := widgets.get("desc") as Label
		if name_label != null:
			field._style_tactical_label(name_label, field.TACTICAL_UI_TEXT_MUTED, 14, 2)
		if value_chip != null:
			field._style_tactical_panel(value_chip, Color(0.10, 0.09, 0.07, 0.98), Color(0.36, 0.32, 0.22, 0.90), 1, 6)
		if value_label != null:
			field._style_tactical_label(value_label, field.TACTICAL_UI_TEXT, 18, 2)
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if bar != null:
			bar.min_value = 0.0
		if desc_label != null:
			field._style_tactical_label(desc_label, field.TACTICAL_UI_TEXT_MUTED, 13, 1)


static func resolve_detailed_unit_info_class_label(unit: Node2D) -> String:
	if unit == null:
		return "Unknown"
	var class_res: Resource = null
	if unit.get("active_class_data") != null:
		class_res = unit.active_class_data
	if class_res != null and class_res.get("job_name") != null:
		return str(class_res.job_name)
	if unit.get("unit_class_name") != null:
		return str(unit.unit_class_name)
	return "Unknown"


static func build_detailed_unit_info_meta_line(_field, unit: Node2D) -> String:
	if unit == null:
		return ""
	var level_value: int = int(unit.get("level")) if unit.get("level") != null else 1
	var move_value: int = int(unit.get("move_range")) if unit.get("move_range") != null else 0
	return "LV %d  |  MOVE %d  |  CLASS %s" % [level_value, move_value, resolve_detailed_unit_info_class_label(unit).to_upper()]


static func build_detailed_unit_info_summary_text(_field, unit: Node2D) -> String:
	if unit == null:
		return ""
	var lines: Array[String] = []
	var ability_name: String = ""
	if "unlocked_abilities" in unit and unit.unlocked_abilities.size() > 0:
		ability_name = ", ".join(unit.unlocked_abilities)
	elif unit.get("ability") != null and str(unit.ability).strip_edges() != "":
		ability_name = str(unit.ability)
	if ability_name != "":
		lines.append("[color=#87d4ff]Ability:[/color] [color=#e9f8ff]%s[/color]" % ability_name)
	var inventory_count: int = unit.inventory.size() if "inventory" in unit else 0
	lines.append("[color=#f2bf59]Inventory:[/color] [color=#fff0c8]%d carried item%s[/color]" % [inventory_count, "" if inventory_count == 1 else "s"])
	return "\n".join(lines)


static func detailed_unit_info_stat_description(stat_key: String) -> String:
	match stat_key:
		"strength":
			return "Raises damage with swords, lances, axes, bows, and many physical techniques."
		"magic":
			return "Raises damage with spells, magic weapons, and abilities that scale from magical power."
		"defense":
			return "Reduces damage taken from physical attacks like blades, arrows, claws, and blunt impacts."
		"resistance":
			return "Reduces damage taken from spells, elemental attacks, curses, and other magical effects."
		"speed":
			return "Helps this unit strike twice before slower enemies and avoid being struck twice by faster ones."
		"agility":
			return "Improves dodge and evasive reactions, and it is the main stat feeding base critical chance before weapon, skill, and battle bonuses."
		_:
			return ""


static func detailed_unit_info_stat_label(stat_key: String) -> String:
	match stat_key:
		"strength":
			return "STRENGTH"
		"magic":
			return "MAGIC"
		"defense":
			return "DEFENSE"
		"resistance":
			return "RESISTANCE"
		"speed":
			return "SPEED"
		"agility":
			return "AGILITY"
		_:
			return stat_key.to_upper()


static func detailed_unit_info_stat_hint_specs(stat_key: String) -> Array[Dictionary]:
	match stat_key:
		"speed":
			return [
				{"text": "x2", "color": Color(0.45, 0.78, 1.0, 1.0)},
				{"text": "TEMPO", "color": Color(0.58, 0.84, 1.0, 1.0)},
			]
		"agility":
			return [
				{"text": "CRIT", "color": Color(1.0, 0.78, 0.30, 1.0)},
				{"text": "EVADE", "color": Color(0.60, 0.94, 0.76, 1.0)},
			]
		_:
			return []


static func detailed_unit_info_growth_label(growth_key: String) -> String:
	match growth_key:
		"hp_growth_bonus":
			return "HEALTH GROWTH"
		"str_growth_bonus":
			return "STRENGTH GROWTH"
		"mag_growth_bonus":
			return "MAGIC GROWTH"
		"def_growth_bonus":
			return "DEFENSE GROWTH"
		"res_growth_bonus":
			return "RESISTANCE GROWTH"
		"spd_growth_bonus":
			return "SPEED GROWTH"
		"agi_growth_bonus":
			return "AGILITY GROWTH"
		_:
			return growth_key.replace("_", " ").to_upper()


static func detailed_unit_info_primary_description(bar_key: String) -> String:
	match bar_key:
		"hp":
			return "Life total. If HP reaches 0, the unit is defeated or forced out of the fight."
		"poise":
			return "Stagger resistance. Higher Poise helps resist breaks, shock, and forced openings. It is usually improved by sturdier classes, defensive bonuses, certain gear, dragon effects, or traits."
		"xp":
			return "Current experience toward the next level, where the unit can gain stronger stats and improve overall combat power."
		_:
			return ""


static func populate_detailed_unit_info_weapon_row(field, unit: Node2D) -> void:
	if field.detailed_unit_info_weapon_badge == null or field.detailed_unit_info_weapon_name == null or field.detailed_unit_info_weapon_icon == null:
		return
	if unit == null or unit.get("equipped_weapon") == null:
		field.detailed_unit_info_weapon_badge.text = "--"
		field.detailed_unit_info_weapon_name.text = "UNARMED"
		field.detailed_unit_info_weapon_icon.texture = null
		return
	var weapon: WeaponData = unit.equipped_weapon as WeaponData
	if weapon == null:
		field.detailed_unit_info_weapon_badge.text = "--"
		field.detailed_unit_info_weapon_name.text = "UNARMED"
		field.detailed_unit_info_weapon_icon.texture = null
		return
	field.detailed_unit_info_weapon_badge.text = field._forecast_weapon_marker(weapon)
	field.detailed_unit_info_weapon_name.text = String(weapon.weapon_name).to_upper()
	field.detailed_unit_info_weapon_icon.texture = weapon.icon


## Matches growth-row tints on the detailed unit info modal; [code]stat_key[/code] may be [code]hp_growth_bonus[/code] or [code]hp_growth[/code] etc.
static func detailed_unit_info_growth_fill_color_standalone(stat_key: String, growth_value: int) -> Color:
	var base_key: String = str(stat_key).replace("_growth_bonus", "").replace("_growth", "")
	if base_key == "str":
		return Color(0.92, 0.48, 0.36, 1.0)
	if base_key == "mag":
		return Color(0.82, 0.54, 0.98, 1.0)
	if base_key == "def":
		return Color(0.55, 0.89, 0.52, 1.0)
	if base_key == "res":
		return Color(0.40, 0.92, 0.88, 1.0)
	if base_key == "spd":
		return Color(0.44, 0.72, 0.98, 1.0)
	if base_key == "agi":
		return Color(0.95, 0.82, 0.43, 1.0)
	if base_key == "hp":
		return Color(0.48, 0.88, 0.55, 1.0)
	if growth_value < 0:
		return Color(0.84, 0.36, 0.32, 1.0)
	return Color(0.74, 0.86, 0.42, 1.0)


static func detailed_unit_info_growth_fill_color(field, stat_key: String, growth_value: int) -> Color:
	return detailed_unit_info_growth_fill_color_standalone(stat_key, growth_value)


static func refresh_detailed_unit_info_growth_widgets(field, unit: Node2D, animate: bool, tween: Tween = null) -> void:
	if unit == null:
		return
	var class_res: Resource = unit.get("active_class_data") if unit.get("active_class_data") != null else null
	var index: int = 0
	for growth_key in [
		"hp_growth_bonus",
		"str_growth_bonus",
		"mag_growth_bonus",
		"def_growth_bonus",
		"res_growth_bonus",
		"spd_growth_bonus",
		"agi_growth_bonus",
	]:
		if not field.detailed_unit_info_growth_widgets.has(growth_key):
			continue
		var widgets: Dictionary = field.detailed_unit_info_growth_widgets[growth_key]
		var panel := widgets.get("panel") as Panel
		var name_label := widgets.get("name") as Label
		var value_chip := widgets.get("value_chip") as Panel
		var value_label := widgets.get("value") as Label
		var bar := widgets.get("bar") as ProgressBar
		var sheen := widgets.get("sheen") as ColorRect
		var label_text: String = detailed_unit_info_growth_label(String(growth_key))
		var growth_value: int = 0
		if class_res != null and class_res.get(growth_key) != null:
			growth_value = int(class_res.get(growth_key))
		var fill_color := detailed_unit_info_growth_fill_color(field, String(growth_key), growth_value)
		if name_label != null:
			name_label.text = label_text
			field._style_tactical_label(name_label, fill_color, 15, 2)
		if value_chip != null:
			field._style_tactical_panel(value_chip, Color(0.10, 0.09, 0.07, 0.98), fill_color.lightened(0.10), 1, 5)
		if value_label != null:
			value_label.text = "%+d%%" % growth_value
			field._style_tactical_label(value_label, field.TACTICAL_UI_TEXT, 14, 1)
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if panel != null:
			field._style_tactical_panel(panel, Color(0.10, 0.09, 0.07, 0.84), fill_color if growth_value != 0 else field.TACTICAL_UI_BORDER_MUTED, 1, 7)
		if bar != null:
			bar.max_value = 100.0
			bar.min_value = 0.0
			field._style_unit_info_stat_bar(bar, fill_color, growth_value >= 50)
			var target: float = clampf(absf(float(growth_value)), 0.0, 100.0)
			if not animate:
				bar.value = target
			else:
				bar.value = 0.0
				var delay := 0.06 + float(index) * 0.03
				if panel != null:
					panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
					tween.tween_property(panel, "modulate", Color.WHITE, 0.14).set_delay(delay)
				tween.tween_property(bar, "value", target, 0.24).set_delay(delay)
				if sheen != null:
					field._animate_unit_info_bar_sheen(sheen, bar, delay + 0.03)
		index += 1


static func build_detailed_unit_info_relationship_cards(field, unit: Node2D) -> void:
	if field.detailed_unit_info_relationships_root == null:
		return
	for child in field.detailed_unit_info_relationships_root.get_children():
		child.queue_free()
	if unit == null:
		return
	var unit_id: String = field.get_relationship_id(unit)
	var candidate_ids: Array = []
	if field.player_container != null:
		for ally in field.player_container.get_children():
			if is_instance_valid(ally) and ally != unit:
				candidate_ids.append(field.get_relationship_id(ally))
	var rel_entries: Array = CampaignManager.get_top_relationship_entries_for_unit(unit_id, candidate_ids, 6)
	if rel_entries.is_empty():
		var empty_label := Label.new()
		field._style_tactical_label(empty_label, field.TACTICAL_UI_TEXT_MUTED, 16, 2)
		empty_label.text = "No notable bonds in this deployment yet."
		field.detailed_unit_info_relationships_root.add_child(empty_label)
		return

	for entry_raw in rel_entries:
		var entry: Dictionary = entry_raw as Dictionary
		var stat: String = str(entry.get("stat")) if entry.get("stat") != null else ""
		var value: int = int(entry.get("value")) if entry.get("value") != null else 0
		var formed: bool = bool(entry.get("formed")) if entry.get("formed") != null else false
		var partner_id: String = str(entry.get("partner_id")) if entry.get("partner_id") != null else "?"
		var tint: Color = CampaignManager.get_relationship_type_color(stat)
		var effect_hint: String = CampaignManager.get_relationship_effect_hint(stat, value)

		var card := Panel.new()
		card.custom_minimum_size = Vector2(0, 96)
		field._style_tactical_panel(card, Color(0.11, 0.10, 0.08, 0.92), tint.lightened(0.08), 1, 9)
		field.detailed_unit_info_relationships_root.add_child(card)

		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		box.add_theme_constant_override("separation", 5)
		card.add_child(box)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 8)
		box.add_child(top_row)

		var partner_label := Label.new()
		partner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field._style_tactical_label(partner_label, field.TACTICAL_UI_TEXT, 18, 2)
		partner_label.text = partner_id
		top_row.add_child(partner_label)

		var state_chip := Panel.new()
		state_chip.custom_minimum_size = Vector2(144, 28)
		field._style_tactical_panel(state_chip, Color(0.10, 0.09, 0.07, 0.96), tint, 1, 6)
		top_row.add_child(state_chip)

		var state_label := Label.new()
		state_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
		field._style_tactical_label(state_label, field.TACTICAL_UI_TEXT, 15, 2)
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		state_label.text = ("%s FORMED" % CampaignManager.get_relationship_type_display_name(stat).to_upper()) if formed else ("%s %d" % [CampaignManager.get_relationship_type_display_name(stat).to_upper(), value])
		state_chip.add_child(state_label)

		var hint_label := Label.new()
		field._style_tactical_label(hint_label, tint.lightened(0.18), 16, 2)
		hint_label.text = effect_hint
		box.add_child(hint_label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 14)
		bar.max_value = 100.0
		bar.value = clampf(float(value), 0.0, 100.0)
		field._style_unit_info_stat_bar(bar, tint, formed)
		box.add_child(bar)
		var sheen: ColorRect = field._attach_unit_info_bar_sheen(bar)
		field._animate_unit_info_bar_sheen(sheen, bar, 0.02)


static func refresh_detailed_unit_info_visuals(field, unit: Node2D, animate: bool = false) -> void:
	if unit == null:
		return
	if field.detailed_unit_info_anim_tween != null:
		field.detailed_unit_info_anim_tween.kill()
		field.detailed_unit_info_anim_tween = null

	var current_poise: int = 0
	var max_poise: int = 1
	if unit.has_method("get_current_poise") and unit.has_method("get_max_poise"):
		current_poise = int(unit.get_current_poise())
		max_poise = max(1, int(unit.get_max_poise()))
	elif unit.get("poise") != null:
		current_poise = int(unit.get("poise"))
		max_poise = max(1, int(unit.get("max_poise")) if unit.get("max_poise") != null else current_poise)

	var xp_current: int = int(unit.get("experience")) if unit.get("experience") != null else 0
	var xp_max: int = unit.get_exp_required() if unit.has_method("get_exp_required") else 100
	xp_max = max(1, xp_max)

	var current_hp: int = int(unit.get("current_hp")) if unit.get("current_hp") != null else 0
	var max_hp: int = max(1, int(unit.get("max_hp")) if unit.get("max_hp") != null else 1)
	var primary_rows: Dictionary = {
		"hp": {"current": current_hp, "max": max_hp, "text": "%d/%d" % [current_hp, max_hp]},
		"poise": {"current": current_poise, "max": max_poise, "text": "%d/%d" % [current_poise, max_poise]},
		"xp": {"current": xp_current, "max": xp_max, "text": "%d/%d" % [xp_current, xp_max]},
	}

	var primary_targets: Dictionary = {}
	for bar_def in field._unit_info_primary_bar_definitions():
		var bar_key: String = str(bar_def.get("key", ""))
		if not field.detailed_unit_info_primary_widgets.has(bar_key):
			continue
		var row_data: Dictionary = primary_rows.get(bar_key, {})
		var current_value: int = int(row_data.get("current", 0))
		var max_value: int = max(1, int(row_data.get("max", 1)))
		var display_text: String = str(row_data.get("text", "%d/%d" % [current_value, max_value]))
		var fill_color: Color = field._unit_info_primary_fill_color(bar_key, current_value, max_value)
		var widgets: Dictionary = field.detailed_unit_info_primary_widgets[bar_key]
		var panel := widgets.get("panel") as Panel
		var name_label := widgets.get("name") as Label
		var hints_root := widgets.get("hints") as HBoxContainer
		var value_chip := widgets.get("value_chip") as Panel
		var value_label := widgets.get("value") as Label
		var bar := widgets.get("bar") as ProgressBar
		var desc_label := widgets.get("desc") as Label
		if panel != null:
			var panel_border := Color(min(fill_color.r + 0.08, 1.0), min(fill_color.g + 0.08, 1.0), min(fill_color.b + 0.08, 1.0), 0.76)
			var tinted_fill := Color(
				lerpf(0.10, fill_color.r, 0.10),
				lerpf(0.09, fill_color.g, 0.10),
				lerpf(0.07, fill_color.b, 0.10),
				0.92
			)
			field._style_tactical_panel(panel, tinted_fill, panel_border, 1, 8)
		if name_label != null:
			name_label.text = str(bar_def.get("label", bar_key))
			field._style_tactical_label(name_label, fill_color, 16, 2)
		if value_chip != null:
			field._style_tactical_panel(value_chip, Color(0.10, 0.09, 0.07, 0.98), fill_color.lightened(0.10), 1, 6)
		if value_label != null:
			value_label.text = display_text
			field._style_tactical_label(value_label, field.TACTICAL_UI_TEXT, 18, 2)
		if bar != null:
			bar.max_value = float(max_value)
			field._style_unit_info_primary_bar(bar, fill_color, bar_key)
			primary_targets[bar_key] = float(clampf(float(current_value), 0.0, float(max_value)))
			if not animate:
				bar.value = primary_targets[bar_key]
		if desc_label != null:
			desc_label.text = detailed_unit_info_primary_description(bar_key)
			field._style_tactical_label(desc_label, field.TACTICAL_UI_TEXT_MUTED, 13, 1)

	var stat_targets: Dictionary = {}
	for stat_def in field._unit_info_stat_definitions():
		var stat_key: String = str(stat_def.get("key", ""))
		if not field.detailed_unit_info_stat_widgets.has(stat_key):
			continue
		var raw_value: int = int(unit.get(stat_key)) if unit.get(stat_key) != null else 0
		var display_value: float = field._unit_info_stat_display_value(raw_value)
		var fill_color: Color = field._unit_info_stat_fill_color(stat_key, raw_value)
		var overcap: bool = raw_value >= int(field.UNIT_INFO_STAT_BAR_CAP)
		var widgets: Dictionary = field.detailed_unit_info_stat_widgets[stat_key]
		var panel := widgets.get("panel") as Panel
		var name_label := widgets.get("name") as Label
		var hints_root := widgets.get("hints") as HBoxContainer
		var value_chip := widgets.get("value_chip") as Panel
		var value_label := widgets.get("value") as Label
		var bar := widgets.get("bar") as ProgressBar
		var desc_label := widgets.get("desc") as Label
		if panel != null:
			var tinted_fill := Color(
				lerpf(0.10, fill_color.r, 0.16),
				lerpf(0.09, fill_color.g, 0.16),
				lerpf(0.07, fill_color.b, 0.16),
				0.92
			)
			field._style_tactical_panel(panel, tinted_fill, fill_color if overcap else fill_color.darkened(0.20), 1, 6)
		if name_label != null:
			name_label.text = detailed_unit_info_stat_label(stat_key)
			field._style_tactical_label(name_label, fill_color, 17, 2)
		if hints_root != null:
			for child in hints_root.get_children():
				child.queue_free()
			for spec in detailed_unit_info_stat_hint_specs(stat_key):
				var chip := Panel.new()
				chip.custom_minimum_size = Vector2(52, 20)
				var chip_color: Color = spec.get("color", fill_color)
				field._style_tactical_panel(chip, Color(0.10, 0.09, 0.07, 0.95), chip_color, 1, 5)
				hints_root.add_child(chip)

				var chip_label := Label.new()
				chip_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 1)
				field._style_tactical_label(chip_label, chip_color, 10, 1)
				chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				chip_label.text = str(spec.get("text", ""))
				chip.add_child(chip_label)
		if value_chip != null:
			field._style_tactical_panel(value_chip, Color(0.10, 0.09, 0.07, 0.98), fill_color, 1, 4)
		if value_label != null:
			value_label.text = str(raw_value)
			field._style_tactical_label(value_label, field.TACTICAL_UI_TEXT, 16, 1)
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if bar != null:
			bar.max_value = field.UNIT_INFO_STAT_BAR_CAP
			field._style_unit_info_stat_bar(bar, fill_color, overcap)
			stat_targets[stat_key] = display_value
			if not animate:
				bar.value = display_value
		if desc_label != null:
			desc_label.text = detailed_unit_info_stat_description(stat_key)
			field._style_tactical_label(desc_label, field.TACTICAL_UI_TEXT_MUTED, 13, 1)

	if not animate:
		refresh_detailed_unit_info_growth_widgets(field, unit, false, null)
		return

	field.detailed_unit_info_anim_tween = field.create_tween().set_parallel(true)
	var primary_defs: Array[Dictionary] = field._unit_info_primary_bar_definitions()
	for idx in range(primary_defs.size()):
		var bar_key: String = str(primary_defs[idx].get("key", ""))
		if not field.detailed_unit_info_primary_widgets.has(bar_key):
			continue
		var widgets: Dictionary = field.detailed_unit_info_primary_widgets[bar_key]
		var panel := widgets.get("panel") as Panel
		var bar := widgets.get("bar") as ProgressBar
		var desc_label := widgets.get("desc") as Label
		var sheen := widgets.get("sheen") as ColorRect
		var delay := float(idx) * 0.05
		if panel != null:
			panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
			field.detailed_unit_info_anim_tween.tween_property(panel, "modulate", Color.WHITE, 0.18).set_delay(delay)
		if bar != null:
			bar.value = 0.0
			field.detailed_unit_info_anim_tween.tween_property(bar, "value", float(primary_targets.get(bar_key, 0.0)), 0.30).set_delay(delay)
		if sheen != null and bar != null:
			field._animate_unit_info_bar_sheen(sheen, bar, delay + 0.05)
		if desc_label != null:
			desc_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
			field.detailed_unit_info_anim_tween.tween_property(desc_label, "modulate", Color.WHITE, 0.16).set_delay(delay + 0.03)

	var stat_defs: Array[Dictionary] = field._unit_info_stat_definitions()
	for idx in range(stat_defs.size()):
		var stat_key: String = str(stat_defs[idx].get("key", ""))
		if not field.detailed_unit_info_stat_widgets.has(stat_key):
			continue
		var widgets: Dictionary = field.detailed_unit_info_stat_widgets[stat_key]
		var panel := widgets.get("panel") as Panel
		var bar := widgets.get("bar") as ProgressBar
		var sheen := widgets.get("sheen") as ColorRect
		var delay := 0.16 + float(idx) * 0.04
		if panel != null:
			panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
			field.detailed_unit_info_anim_tween.tween_property(panel, "modulate", Color.WHITE, 0.16).set_delay(delay)
		if bar != null:
			bar.value = 0.0
			field.detailed_unit_info_anim_tween.tween_property(bar, "value", float(stat_targets.get(stat_key, 0.0)), 0.24).set_delay(delay)
			if sheen != null and bar != null:
				field._animate_unit_info_bar_sheen(sheen, bar, delay + 0.04)
		var desc_label_stat := widgets.get("desc") as Label
		if desc_label_stat != null:
			desc_label_stat.modulate = Color(1.0, 1.0, 1.0, 0.0)
			field.detailed_unit_info_anim_tween.tween_property(desc_label_stat, "modulate", Color.WHITE, 0.18).set_delay(delay + 0.03)

	refresh_detailed_unit_info_growth_widgets(field, unit, animate, field.detailed_unit_info_anim_tween)

	field.detailed_unit_info_anim_tween.finished.connect(func():
		field.detailed_unit_info_anim_tween = null
	, CONNECT_ONE_SHOT)


static func build_detailed_unit_info_record_text(field, unit: Node2D) -> String:
	if unit == null:
		return ""

	var lines: Array[String] = []
	var class_res: Resource = unit.get("active_class_data") if unit.get("active_class_data") != null else null

	lines.append("[color=gold]Field Doctrine[/color]")
	lines.append("Class: [color=cyan]%s[/color]" % resolve_detailed_unit_info_class_label(unit))
	lines.append("Move: %d" % (int(unit.get("move_range")) if unit.get("move_range") != null else 0))
	lines.append("")

	if class_res != null:
		lines.append("[color=gold]Weapon Permissions[/color]")
		lines.append(field._format_class_weapon_permissions(class_res))
		lines.append("")

		lines.append("[color=gold]Class Bonuses[/color]")
		var class_bonus_parts: Array[String] = []
		for pair in [
			["hp_bonus", "HP", ""],
			["str_bonus", "STR", "coral"],
			["mag_bonus", "MAG", "orchid"],
			["def_bonus", "DEF", "palegreen"],
			["res_bonus", "RES", "aquamarine"],
			["spd_bonus", "SPD", "skyblue"],
			["agi_bonus", "AGI", "wheat"],
		]:
			var key: String = String(pair[0])
			if class_res.get(key) == null or int(class_res.get(key)) == 0:
				continue
			var chunk: String = "%s %+d" % [String(pair[1]), int(class_res.get(key))]
			var tint: String = String(pair[2])
			class_bonus_parts.append(chunk if tint == "" else "[color=%s]%s[/color]" % [tint, chunk])
		lines.append("None" if class_bonus_parts.is_empty() else ", ".join(class_bonus_parts))
		lines.append("")

		lines.append("[color=gold]Promotion Bonuses[/color]")
		var promo_parts: Array[String] = []
		for pair in [
			["promo_hp_bonus", "HP", ""],
			["promo_str_bonus", "STR", "coral"],
			["promo_mag_bonus", "MAG", "orchid"],
			["promo_def_bonus", "DEF", "palegreen"],
			["promo_res_bonus", "RES", "aquamarine"],
			["promo_spd_bonus", "SPD", "skyblue"],
			["promo_agi_bonus", "AGI", "wheat"],
		]:
			var key: String = String(pair[0])
			if class_res.get(key) == null or int(class_res.get(key)) == 0:
				continue
			var chunk: String = "%s %+d" % [String(pair[1]), int(class_res.get(key))]
			var tint: String = String(pair[2])
			promo_parts.append(chunk if tint == "" else "[color=%s]%s[/color]" % [tint, chunk])
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
				var extra: String = " | Mt " + str(item.might) + " | Hit +" + str(item.hit_bonus) + " | Rng " + str(item.min_range) + "-" + str(item.max_range)
				lines.append("- " + str(item_name) + " (" + w_type + ")" + marker)
				lines.append("  " + extra)
			else:
				lines.append("- " + str(item_name))
	else:
		lines.append("None")

	lines.append("")
	lines.append("[color=gold]Notes[/color]")
	lines.append("Growth outlook and bond cards are surfaced above.")
	lines.append("Green = usable")
	lines.append("Red = class locked")

	return "[font_size=24]" + "\n".join(lines) + "[/font_size]"
