extends RefCounted

# Inventory open/close/grid selection, item-detail BBCode, loot selection, trade window,
# and inventory description-panel refit helpers extracted from `BattleField.gd`.

const BattleResultPresentationHelpers = preload("res://Scripts/Core/BattleField/BattleFieldBattleResultPresentationHelpers.gd")
const FateCardLootData = preload("res://Resources/FateCardLootData.gd")
const FateCardLootHelpers = preload("res://Scripts/Core/FateCardLootHelpers.gd")


static func resolve_inventory_ui_nodes(field) -> void:
	if field.inventory_panel == null:
		return
	field.inv_desc_label = field.inventory_panel.get_node_or_null("ItemDescLabel") as RichTextLabel
	field.inv_scroll = field.inventory_panel.get_node_or_null("InventoryScroll") as ScrollContainer
	field.unit_grid = null
	field.convoy_grid = null
	if field.inv_scroll != null:
		var vbox_node: Node = field.inv_scroll.get_node_or_null("InventoryVBox")
		if vbox_node != null:
			field.unit_grid = vbox_node.get_node_or_null("UnitGrid") as GridContainer
			field.convoy_grid = vbox_node.get_node_or_null("ConvoyGrid") as GridContainer


static func stylebox_bump_all_content_margins(sb: StyleBox, delta: float) -> void:
	if sb == null:
		return
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_content_margin(side, sb.get_content_margin(side) + delta)


static func inventory_scroll_apply_content_padding(scroll: ScrollContainer, pad: int) -> void:
	var sb: StyleBox = scroll.get_theme_stylebox("panel")
	if sb != null:
		sb = sb.duplicate() as StyleBox
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0, 0, 0, 0)
		sb = flat
	stylebox_bump_all_content_margins(sb, float(pad))
	scroll.add_theme_stylebox_override("panel", sb)


static func style_inventory_item_info_backdrop(field, info_bg: Panel) -> void:
	if info_bg == null:
		return
	field._style_tactical_panel(info_bg, field.TACTICAL_UI_BG_ALT, field.TACTICAL_UI_BORDER, 2, 12)
	info_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_bg.z_index = -1


static func apply_inventory_panel_item_list_extra_margins(field, inv_item_list: ItemList) -> void:
	if inv_item_list == null or field.inventory_panel == null:
		return
	if field.inventory_panel.get_meta("_inv_itemlist_extra_margin", false):
		return
	field.inventory_panel.set_meta("_inv_itemlist_extra_margin", true)
	var sb := inv_item_list.get_theme_stylebox("panel")
	if sb == null:
		return
	var d := sb.duplicate() as StyleBox
	stylebox_bump_all_content_margins(d, float(field.INVENTORY_UI_ITEMLIST_EXTRA_MARGIN))
	inv_item_list.add_theme_stylebox_override("panel", d)


static func queue_refit_item_description_panels(field) -> void:
	var t := Timer.new()
	t.wait_time = 0.03
	t.one_shot = true
	t.process_mode = Node.PROCESS_MODE_ALWAYS
	field.add_child(t)
	t.timeout.connect(func():
		BattleResultPresentationHelpers.refit_loot_description_panel_height(field)
		refit_inventory_description_panel_height(field)
		t.queue_free()
	, CONNECT_ONE_SHOT)
	t.start()


static func refit_inventory_description_panel_height(field) -> void:
	if field.inv_desc_label == null or field.inventory_panel == null:
		return
	if not field.inventory_panel.visible:
		return
	field.inv_desc_label.scroll_active = false
	var w: float = field.inv_desc_label.size.x
	if w < 8.0:
		return
	var ch: float = field.inv_desc_label.get_content_height()
	var th := clampf(ch + field.ITEM_DESC_RICHTEXT_EXTRA_PAD, field.INVENTORY_DESC_PANEL_MIN_H, field.ITEM_DESC_RICHTEXT_MAX_H)
	field.inv_desc_label.offset_top = field.inv_desc_label.offset_bottom - th
	var bg := field.inventory_panel.get_node_or_null("Panel") as Panel
	if bg != null:
		var pad: float = float(field.INVENTORY_DESC_PANEL_PAD)
		var r: Rect2 = field.inv_desc_label.get_rect()
		bg.position = r.position - Vector2(pad, pad)
		bg.size = r.size + Vector2(2.0 * pad, 2.0 * pad)
		style_inventory_item_info_backdrop(field, bg)


static func on_convoy_pressed(field) -> void:
	if field.current_state != field.player_state or field.player_state.is_forecasting:
		return
	if field.convoy_grid == null or field.inv_scroll == null:
		return

	field.unit_managing_inventory = null
	field.player_state.is_forecasting = true

	field._populate_convoy_list()

	field.equip_button.visible = false
	field.use_button.visible = false
	field.inventory_panel.visible = true


static func on_open_inv_pressed(field) -> void:
	if field.current_state != field.player_state or field.player_state.active_unit == null:
		return
	if field.unit_grid == null:
		return

	field.unit_managing_inventory = field.player_state.active_unit
	field.player_state.is_forecasting = true

	field._populate_unit_inventory_list()

	field.equip_button.visible = true
	field.use_button.visible = true
	field.inventory_panel.visible = true


static func on_close_inv_pressed(field) -> void:
	field.inventory_panel.visible = false
	if field.current_state == field.player_state:
		field.player_state.is_forecasting = false
	field.unit_managing_inventory = null


static func on_grid_item_clicked(field, btn: Button, meta: Dictionary) -> void:
	if field.select_sound and field.select_sound.stream != null:
		field.select_sound.pitch_scale = 1.2
		field.select_sound.play()

	field.selected_inventory_meta = meta

	var grid_children: Array[Node] = []
	if field.unit_grid != null:
		grid_children.append_array(field.unit_grid.get_children())
	if field.convoy_grid != null:
		grid_children.append_array(field.convoy_grid.get_children())
	for child in grid_children:
		child.modulate = Color.WHITE
	btn.modulate = Color(1.5, 1.5, 1.5)

	var item = meta["item"]
	var count = meta.get("count", 1)
	var viewer_unit = meta.get("unit", null)
	if field.inv_desc_label != null:
		field.inv_desc_label.text = get_item_detailed_info(field, item, count, viewer_unit)
		queue_refit_item_description_panels(field)

	field.equip_button.disabled = false
	field.use_button.disabled = false


static func get_item_display_text(item: Resource) -> String:
	if FateCardLootHelpers.is_fate_card_loot(item):
		return "FATE CARD: " + FateCardLootHelpers.get_fate_card_loot_label(item)
	var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
	var dur_str = ""
	var broken_tag = ""

	if item.get("current_durability") != null:
		dur_str = " [%d/%d]" % [item.current_durability, item.max_durability]
		if item.current_durability <= 0:
			broken_tag = "[BROKEN] "
	elif item.get("uses") != null:
		dur_str = " (" + str(item.uses) + " Uses)"

	return "%s%s%s" % [broken_tag, i_name, dur_str]


static func bbcode_escape_user_text(s: String) -> String:
	return str(s).replace("[", "[lb]")


static func item_detail_soft_rule() -> String:
	# Middle dots via \u escapes — avoids mojibake if the .gd file is mis-saved as Latin-1.
	return "[color=#5c4f41]%s[/color]" % (" \u00b7").repeat(18)


static func item_detail_section_heading(title: String) -> String:
	return "[font_size=20][color=#c4943a]\u25b6 [/color][b][color=#f2d680]" + str(title).to_upper() + "[/color][/b][/font_size]"


static func item_detail_callout(accent_hex: String, body_hex: String, escaped_msg: String) -> String:
	return "[font_size=19][color=%s]\u25b8 [/color][color=%s]%s[/color][/font_size]" % [accent_hex, body_hex, escaped_msg]


static func item_detail_line(lbl: String, value_bb: String) -> String:
	return "[font_size=19][color=#c4bba8][b]" + lbl + "[/b][/color][color=#5a5248]   [/color]" + value_bb + "[/font_size]"


static func item_detail_effect_row(body_color: String, escaped_inner: String) -> String:
	return "[font_size=19]   [color=#e0b858]\u25c6[/color][color=#5a5248]   [/color][color=%s]%s[/color][/font_size]" % [body_color, escaped_inner]


static func weapon_compare_delta_fragments_bbcode(sel: WeaponData, equipped: WeaponData) -> PackedStringArray:
	var out: PackedStringArray = []
	if sel.damage_type != equipped.damage_type:
		return out
	const C_UP: String = "#a8e8b8"
	const C_DN: String = "#ffa898"
	var md: int = int(sel.might) - int(equipped.might)
	var hd: int = int(sel.hit_bonus) - int(equipped.hit_bonus)
	if md != 0:
		var c: String = C_UP if md > 0 else C_DN
		out.append("[color=%s][b]%s Might[/b][/color]" % [c, "%+d" % md])
	if hd != 0:
		var c2: String = C_UP if hd > 0 else C_DN
		out.append("[color=%s][b]%s Hit[/b][/color]" % [c2, "%+d" % hd])
	return out


static func weapon_stat_compare_line_bbcode(sel: WeaponData, equipped: WeaponData) -> String:
	var frags: PackedStringArray = weapon_compare_delta_fragments_bbcode(sel, equipped)
	if frags.is_empty():
		return ""
	var sep: String = "[color=#5a5248] \u00b7 [/color]"
	return (
		"[font_size=19][color=#b8a890]vs equipped[/color]%s%s[/font_size]"
		% [sep, sep.join(frags)]
	)


static func add_equipped_badge_to_inv_button(btn: Button) -> void:
	if btn == null:
		return
	if btn.get_node_or_null("EquippedBadge") != null:
		return
	var badge := Label.new()
	badge.name = "EquippedBadge"
	badge.text = "E"
	badge.add_theme_font_size_override("font_size", 15)
	badge.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	badge.add_theme_constant_override("outline_size", 4)
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(badge)
	badge.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	badge.offset_left = 4
	badge.offset_bottom = -2
	badge.grow_horizontal = Control.GROW_DIRECTION_END


static func play_inv_slot_flash(field, btn: Button) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	var peak: Vector2 = Vector2(1.11, 1.11)
	var tw: Tween = field.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", peak, 0.085)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.11)
	var base_col: Color = Color.WHITE
	if btn is Control and btn.has_meta("hover_base_modulate"):
		base_col = btn.get_meta("hover_base_modulate") as Color
	var tw2: Tween = field.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(btn, "modulate", base_col * Color(1.32, 1.22, 1.05), 0.07)
	tw2.tween_property(btn, "modulate", base_col, 0.13)


static func battle_try_flash_pending_inv_slot(field, grid: GridContainer) -> void:
	if field._battle_inv_flash_item == null or grid == null:
		return
	var want: Resource = field._battle_inv_flash_item
	field._battle_inv_flash_item = null
	for c in grid.get_children():
		if c is Button and (c as Button).has_meta("inv_data"):
			var d: Dictionary = (c as Button).get_meta("inv_data") as Dictionary
			if d.get("item") == want:
				play_inv_slot_flash(field, c as Button)
				return


static func get_item_detailed_info(field, item: Resource, stack_count: int = 1, viewer_unit: Node2D = null) -> String:
	var lines: PackedStringArray = []
	const C_MUTED: String = "#c4bba8"
	const C_BODY: String = "#faf6eb"
	const C_DIM: String = "#8a8274"
	const C_VALUE: String = "#f0d78c"
	const C_OK: String = "#a8e8b8"
	const C_BAD: String = "#ffa898"
	const C_STAT: String = "#ffd4b8"

	var rarity: String = item.get("rarity") if item.get("rarity") != null else "Common"
	var cost: int = item.get("gold_cost") if item.get("gold_cost") != null else 0

	var rarity_hex: String = "#f2ede0"
	match rarity:
		"Uncommon":
			rarity_hex = "#8ae89e"
		"Rare":
			rarity_hex = "#8ed4ff"
		"Epic":
			rarity_hex = "#d4a8ff"
		"Legendary":
			rarity_hex = "#ffe090"
		"Mythic":
			rarity_hex = "#ffb060"

	lines.append("[font_size=28][b][color=%s]%s[/color][/b][/font_size]" % [rarity_hex, str(rarity).to_upper()])
	var meta: String = (
		"[font_size=20][color=#d4a85c]\u2022 [/color][color=%s]Value[/color][color=#5a5248]   [/color][color=%s][b]%d[/b][/color][color=%s]g[/color]"
		% [C_MUTED, C_VALUE, cost, C_DIM]
	)
	if stack_count > 1:
		meta += "[color=#5a5248]        [/color][color=#b89858]\u2022 [/color][color=%s]Stack[/color][color=#5a5248]   [/color][color=%s][b]\u00d7%d[/b][/color]" % [C_MUTED, C_BODY, stack_count]
	meta += "[/font_size]"
	lines.append(meta)
	lines.append(item_detail_soft_rule())
	lines.append("")

	if item is WeaponData:
		if item.get("current_durability") != null and item.current_durability <= 0:
			lines.append("[font_size=20][b][color=%s]Broken \u2014 half effectiveness. Repair to restore full power.[/color][/b][/font_size]" % C_BAD)
			lines.append("")

		lines.append(item_detail_section_heading("Combat stats"))
		lines.append("")

		var w_type_str: String = "Unknown"
		if item.get("weapon_type") != null:
			w_type_str = field._weapon_type_name_safe(int(item.weapon_type))
		var d_type_str: String = "Physical" if item.get("damage_type") != null and item.damage_type == 0 else "Magical"

		lines.append(
			item_detail_line(
				"Weapon",
				"[color=%s]%s[/color][color=%s]   \u00b7   [/color][color=%s]%s[/color]"
				% [C_BODY, w_type_str, C_DIM, C_DIM, d_type_str]
			)
		)
		lines.append(
			item_detail_line("Might", "[color=%s]%d[/color]" % [C_STAT, int(item.might)])
		)
		lines.append(
			item_detail_line("Hit", "[color=%s]+%d[/color]" % [C_VALUE, int(item.hit_bonus)])
		)
		lines.append(
			item_detail_line(
				"Range",
				"[color=%s]%d[/color][color=%s]\u2013[/color][color=%s]%d[/color]"
				% [C_BODY, int(item.min_range), C_DIM, C_BODY, int(item.max_range)]
			)
		)

		if item.get("current_durability") != null:
			lines.append(
				item_detail_line(
					"Durability",
					"[color=%s]%d[/color][color=%s] / [/color][color=%s]%d[/color]"
					% [C_BODY, int(item.current_durability), C_DIM, C_BODY, int(item.max_durability)]
				)
			)

		var eq_weapon: Resource = viewer_unit.get("equipped_weapon") if viewer_unit != null else null
		if (
				eq_weapon != null
				and eq_weapon is WeaponData
				and item != eq_weapon
		):
			var cmp_line: String = weapon_stat_compare_line_bbcode(item as WeaponData, eq_weapon as WeaponData)
			if cmp_line != "":
				lines.append("")
				lines.append(cmp_line)

		if viewer_unit != null:
			lines.append("")
			var usable: bool = field._unit_can_use_item_for_ui(viewer_unit, item)
			if usable:
				lines.append("[font_size=20][color=%s][b]Equippable[/b][/color][color=#5a5248] \u2014 [/color][color=%s]This unit can use this weapon.[/color][/font_size]" % [C_OK, C_BODY])
			else:
				lines.append("[font_size=20][color=%s][b]Locked[/b][/color][color=#5a5248] \u2014 [/color][color=%s]This unit cannot equip this weapon.[/color][/font_size]" % [C_BAD, C_MUTED])

		var effects: Array = []
		if item.get("is_healing_staff") == true:
			effects.append("Restores %d HP" % int(item.effect_amount))

		if item.get("is_buff_staff") == true or item.get("is_debuff_staff") == true:
			var word: String = "Grants +" if item.get("is_buff_staff") == true else "Inflicts -"
			if item.get("affected_stat") != null and str(item.affected_stat) != "":
				var stats: PackedStringArray = str(item.affected_stat).split(",")
				var formatted_stats: PackedStringArray = []
				for s in stats:
					formatted_stats.append(s.strip_edges().capitalize())
				effects.append(word + str(item.effect_amount) + " to " + ", ".join(formatted_stats))

		if effects.size() > 0:
			lines.append("")
			lines.append(item_detail_section_heading("Effects"))
			lines.append("")
			for e in effects:
				lines.append(item_detail_effect_row(C_BODY, bbcode_escape_user_text(str(e))))

	elif item is ConsumableData:
		lines.append(item_detail_section_heading("Overview"))
		lines.append(item_detail_line("Kind", "[color=%s]Consumable[/color]" % C_BODY))

		var effects: Array = []
		if item.heal_amount > 0:
			effects.append("Restores %d HP" % int(item.heal_amount))

		var boosts: PackedStringArray = []
		if item.hp_boost > 0:
			boosts.append("+%d HP" % int(item.hp_boost))
		if item.str_boost > 0:
			boosts.append("+%d STR" % int(item.str_boost))
		if item.mag_boost > 0:
			boosts.append("+%d MAG" % int(item.mag_boost))
		if item.def_boost > 0:
			boosts.append("+%d DEF" % int(item.def_boost))
		if item.res_boost > 0:
			boosts.append("+%d RES" % int(item.res_boost))
		if item.spd_boost > 0:
			boosts.append("+%d SPD" % int(item.spd_boost))
		if item.agi_boost > 0:
			boosts.append("+%d AGI" % int(item.agi_boost))

		if boosts.size() > 0:
			effects.append("Permanent stat boost: " + ", ".join(boosts))

		if effects.size() > 0:
			lines.append("")
			lines.append(item_detail_section_heading("Effects"))
			lines.append("")
			for e in effects:
				lines.append(item_detail_effect_row(C_BODY, bbcode_escape_user_text(str(e))))

	elif item is MaterialData:
		lines.append(item_detail_section_heading("Overview"))
		lines.append(item_detail_line("Kind", "[color=%s]Crafting material[/color]" % C_BODY))
	elif item is FateCardLootData:
		var loot_card: FateCardLootData = item as FateCardLootData
		var card_name: String = FateCardLootHelpers.get_fate_card_loot_label(loot_card)
		var card_rarity: String = str(loot_card.card_rarity).strip_edges()
		if card_rarity == "":
			card_rarity = "Unknown"
		lines.append(item_detail_section_heading("Fate Unlock"))
		lines.append(item_detail_line("Kind", "[color=%s]Permanent card unlock[/color]" % C_BODY))
		lines.append(item_detail_line("Card", "[color=%s]%s[/color]" % [C_VALUE, bbcode_escape_user_text(card_name)]))
		lines.append(item_detail_line("Card Rarity", "[color=%s]%s[/color]" % [C_BODY, bbcode_escape_user_text(card_rarity.capitalize())]))
		lines.append("")
		lines.append(item_detail_callout("#ffb060", "#f5ead8", "Unlock applies globally to this campaign profile and is not sent to inventory or convoy."))
	else:
		lines.append(item_detail_section_heading("Overview"))
		lines.append(
			item_detail_callout(
				"#a89878",
				"#e8dfd4",
				"Unclassified treasure \u2014 still worth its weight on the market."
			)
		)

	lines.append("")
	lines.append(item_detail_soft_rule())
	lines.append(item_detail_section_heading("Details"))
	lines.append("")
	if item.get("description") != null and item.description.strip_edges() != "":
		var raw_desc: String = item.description.strip_edges()
		for piece: String in raw_desc.split("\n"):
			var row: String = piece.strip_edges()
			if row == "":
				lines.append("")
				continue
			lines.append(
				"[font_size=19][color=#b8a890]\u25b8[/color][color=#5a5248]  [/color][color=%s]%s[/color][/font_size]"
				% [C_BODY, bbcode_escape_user_text(row)]
			)
	else:
		lines.append(
			item_detail_callout(
				"#7a7064",
				"#c8beb2",
				"No written notes for this entry \u2014 check its name in the list or try it in battle."
			)
		)

	return "\n".join(lines)


static func on_loot_item_selected(field, index: int) -> void:
	if field.loot_desc_label == null:
		return

	# --- NEW: Read from Metadata instead of the raw array! ---
	var meta = field.loot_item_list.get_item_metadata(index)
	if meta == null:
		return

	var stack_amt = meta.get("count", 1)
	field.loot_desc_label.text = get_item_detailed_info(field, meta["item"], stack_amt)
	queue_refit_item_description_panels(field)

	if field.select_sound and field.select_sound.stream != null:
		field.select_sound.pitch_scale = 1.2
		field.select_sound.play()


static func show_trade_popup(field, ally: Node2D) -> void:
	# 1. Position the menu
	field.trade_popup.position = ally.get_global_transform_with_canvas().origin + Vector2(40, -40)
	field.trade_popup.visible = true

	# 2. Hide the Talk button by default
	field.popup_talk_btn.visible = false

	# 3. Check if a Support Conversation is ready!
	var initiator = field.player_state.active_unit
	if initiator == null or initiator.get("data") == null or ally.get("data") == null:
		return

	# --- THE FIX: USE CODENAMES ---
	var init_name = field.get_support_name(initiator)
	var ally_name = field.get_support_name(ally)

	var bond = CampaignManager.get_support_bond(init_name, ally_name)

	var support_file_found = null

	for s_file in initiator.data.supports:
		if s_file.partner_name == ally_name:
			support_file_found = s_file
			break

	if support_file_found == null:
		for s_file in ally.data.supports:
			if s_file.partner_name == init_name:
				support_file_found = s_file
				break

	# If we found a valid link between these two, check the points!
	if support_file_found != null:
		var rank = bond["rank"]
		if rank == 0 and bond["points"] >= support_file_found.points_for_c:
			field.popup_talk_btn.visible = true
		elif rank == 1 and bond["points"] >= support_file_found.points_for_b:
			field.popup_talk_btn.visible = true
		elif rank == 2 and bond["points"] >= support_file_found.points_for_a:
			field.popup_talk_btn.visible = true


static func hide_trade_popup(field) -> void:
	field.trade_popup.visible = false


static func on_trade_popup_confirm(field) -> void:
	hide_trade_popup(field)
	if field.player_state.active_unit != null and field.player_state.trade_target_ally != null:
		open_trade_window(field, field.player_state.active_unit, field.player_state.trade_target_ally)


static func open_trade_window(field, unit_a: Node2D, unit_b: Node2D) -> void:
	field.trade_unit_a = unit_a
	field.trade_unit_b = unit_b
	field.trade_selected_side = ""
	field.trade_selected_index = -1

	field.player_state.is_forecasting = true # Freeze the map

	field.trade_left_name.text = unit_a.unit_name
	field.trade_right_name.text = unit_b.unit_name
	if unit_a.data and unit_a.data.portrait:
		field.trade_left_portrait.texture = unit_a.data.portrait
	if unit_b.data and unit_b.data.portrait:
		field.trade_right_portrait.texture = unit_b.data.portrait

	refresh_trade_window(field)
	field.trade_window.visible = true


static func refresh_trade_window(field) -> void:
	field.trade_left_list.clear()
	field.trade_right_list.clear()

	fill_trade_list(field.trade_left_list, field.trade_unit_a)
	fill_trade_list(field.trade_right_list, field.trade_unit_b)

	# Keep the item highlighted if they are mid-swap
	if field.trade_selected_side == "left" and field.trade_selected_index != -1:
		field.trade_left_list.select(field.trade_selected_index)
	elif field.trade_selected_side == "right" and field.trade_selected_index != -1:
		field.trade_right_list.select(field.trade_selected_index)


static func fill_trade_list(list: ItemList, unit: Node2D) -> void:
	var inv = []
	if "inventory" in unit:
		inv = unit.inventory

	# Always draw exactly 5 slots
	for i in range(5):
		if i < inv.size() and inv[i] != null:
			var item = inv[i]
			var text = get_item_display_text(item)
			if item is WeaponData and WeaponData.is_trade_locked(item as WeaponData):
				text = "[LOCK] " + text
			if item == unit.equipped_weapon:
				text = "[E] " + text
			var img = item.get("icon") if item.get("icon") != null else null
			list.add_item(text, img)
		else:
			list.add_item("--- Empty ---", null)


static func _trade_item_at(field, side: String, index: int):
	var unit: Node2D = field.trade_unit_a if side == "left" else field.trade_unit_b
	if unit == null:
		return null
	if index < 0 or index >= unit.inventory.size():
		return null
	return unit.inventory[index]


static func on_trade_item_clicked(field, index: int, side: String) -> void:
	if field.select_sound.stream != null:
		field.select_sound.play()
	var clicked_item = _trade_item_at(field, side, index)
	if clicked_item is WeaponData and field._is_weapon_non_tradeable(clicked_item as WeaponData):
		field.play_ui_sfx(field.UISfx.INVALID)
		field.add_combat_log("Dragon-bound weapons cannot be traded.", "orange")
		return

	# Click 1: Select the first item
	if field.trade_selected_side == "":
		field.trade_selected_side = side
		field.trade_selected_index = index
		return

	# Click 2 (Same Item): Deselect it
	if field.trade_selected_side == side and field.trade_selected_index == index:
		field.trade_selected_side = ""
		field.trade_selected_index = -1
		refresh_trade_window(field)
		return

	# Click 2 (Different Item or Empty Slot): Execute the Swap!
	field._execute_trade_swap(field.trade_selected_side, field.trade_selected_index, side, index)

	# Reset state after swapping
	field.trade_selected_side = ""
	field.trade_selected_index = -1
	refresh_trade_window(field)


static func on_trade_window_close(field) -> void:
	field.trade_window.visible = false
	field.player_state.is_forecasting = false
	field.player_state.trade_target_ally = null

	# Ensure nobody is holding a ghost weapon they just traded away
	validate_equipment(field, field.trade_unit_a)
	validate_equipment(field, field.trade_unit_b)
	field.update_unit_info_panel()


static func validate_equipment(field, unit: Node2D) -> void:
	if unit == null:
		return

	if unit.equipped_weapon != null:
		var still_has_weapon: bool = unit.inventory.has(unit.equipped_weapon)
		var still_allowed: bool = field._unit_can_equip_weapon(unit, unit.equipped_weapon)

		if not still_has_weapon or not still_allowed:
			unit.equipped_weapon = null

	if unit.equipped_weapon == null:
		for item in unit.inventory:
			if item is WeaponData and field._unit_can_equip_weapon(unit, item):
				unit.equipped_weapon = item
				break
