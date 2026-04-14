extends RefCounted

# Extracted inventory action handlers from `BattleField.gd`.
# Keeps the awaited/predicted UI/turn sequencing identical by delegating back
# into the existing `field` instance for internal methods/state.
const PromotionFlowSharedHelpers = preload("res://Scripts/Core/PromotionFlowSharedHelpers.gd")
const IntelLearnedPopupUI = preload("res://Scripts/UI/IntelLearnedPopup.gd")
const InventoryPanelHelpers = preload("res://Scripts/Core/BattleField/BattleFieldInventoryPanelHelpers.gd")


static func on_equip_pressed(field) -> void:
	if field.selected_inventory_meta.is_empty():
		return

	var meta = field.selected_inventory_meta
	if meta["source"] != "unit_personal":
		return

	var item = meta["item"]
	if item is WeaponData:
		if not field._unit_can_equip_weapon(field.unit_managing_inventory, item):
			field.play_ui_sfx(field.UISfx.INVALID)
			return

		field.unit_managing_inventory.equipped_weapon = item
		field._battle_inv_flash_item = item
		field.calculate_ranges(field.unit_managing_inventory)
		field.update_unit_info_panel()
		field._populate_unit_inventory_list()
		InventoryPanelHelpers.focus_inventory_item(field, item, "unit_personal")
		InventoryPanelHelpers.show_detail_confirmation(field, "Equipped now")
		field.play_ui_sfx(field.UISfx.INVENTORY_EQUIP)


static func on_use_pressed(field) -> void:
	if field.selected_inventory_meta.is_empty():
		return

	var meta = field.selected_inventory_meta
	if meta["source"] != "unit_personal":
		return

	var item = meta["item"]
	var real_index = meta["index"]

	if item is ConsumableData:
		var unit = field.unit_managing_inventory
		if item.get("is_promotion_item") == true:
			var current_class: Resource = PromotionFlowSharedHelpers.resolve_current_class_from_unit_node(unit)
			var promotion_options: Array[Resource] = PromotionFlowSharedHelpers.get_promotion_options(current_class)
			if PromotionFlowSharedHelpers.can_unit_promote(int(unit.level), current_class):
				unit.inventory.remove_at(real_index)
				field.play_ui_sfx(field.UISfx.INVENTORY_USE)
				InventoryPanelHelpers.show_detail_confirmation(field, "Used")
				field._on_close_inv_pressed()

				var chosen_advanced_class = await field._ask_for_promotion_choice(promotion_options)
				if chosen_advanced_class != null:
					field.execute_promotion(unit, chosen_advanced_class)
					field.update_unit_info_panel()
					unit.finish_turn()
					field.player_state.active_unit = null
					field.rebuild_grid()
					field.clear_ranges()
				else:
					unit.inventory.insert(real_index, item)
					field._on_open_inv_pressed()
			else:
				field.play_ui_sfx(field.UISfx.INVALID)
				field.spawn_loot_text("Cannot Promote!", Color.RED, unit.global_position + Vector2(32, -32))
			return

		var raw_intel_ids: Variant = item.get("knowledge_intel_ids")
		if raw_intel_ids is Array and (raw_intel_ids as Array).size() > 0:
			var id_pack := PackedStringArray()
			for id_el in (raw_intel_ids as Array):
				var id_s: String = str(id_el).strip_edges()
				if id_s != "":
					id_pack.append(id_s)
			if not id_pack.is_empty():
				var new_intel_ids: PackedStringArray = CampaignManager.unlock_beastiary_intel_ids(id_pack)
				if new_intel_ids.is_empty():
					field.play_ui_sfx(field.UISfx.INVALID)
					field.spawn_loot_text("Already recorded!", Color.ORANGE, unit.global_position + Vector2(32, -32))
					return
				unit.inventory.remove_at(real_index)
				field.play_ui_sfx(field.UISfx.INVENTORY_USE)
				InventoryPanelHelpers.show_detail_confirmation(field, "Used")
				field._on_close_inv_pressed()
				var ui_root: Node = field.get_node_or_null("UI")
				var intel_bbcode: String = BeastiaryIntelRegistry.build_popup_bbcode_for_new_intel_ids(new_intel_ids)
				IntelLearnedPopupUI.show_at(ui_root if ui_root != null else field, intel_bbcode)
				field.update_unit_info_panel()
				unit.finish_turn()
				field.player_state.active_unit = null
				field.rebuild_grid()
				field.clear_ranges()
				return

		var gains = {
			"hp": item.hp_boost, "str": item.str_boost, "mag": item.mag_boost,
			"def": item.def_boost, "res": item.res_boost, "spd": item.spd_boost, "agi": item.agi_boost
		}

		field.apply_stat_gains(unit, gains)
		if item.heal_amount > 0:
			unit.current_hp = min(unit.current_hp + item.heal_amount, unit.max_hp)
			if unit.get("health_bar") != null:
				unit.health_bar.value = unit.current_hp

		unit.inventory.remove_at(real_index)
		field.play_ui_sfx(field.UISfx.INVENTORY_USE)
		InventoryPanelHelpers.show_detail_confirmation(field, "Used")
		field._on_close_inv_pressed()

		var is_permanent = false
		for val in gains.values():
			if val > 0:
				is_permanent = true

		if is_permanent:
			await field.run_theatrical_stat_reveal(unit, item.item_name, gains)

		field.update_unit_info_panel()
		unit.finish_turn()
		field.player_state.active_unit = null
		field.rebuild_grid()
		field.clear_ranges()
