extends RefCounted

# Inventory / loot UI helpers extracted from `BattleField.gd`.

const TradeInventoryHelpers = preload("res://Scripts/Core/BattleField/BattleFieldTradeInventoryHelpers.gd")

static func apply_inventory_panel_spacing(field) -> void:
	if field.inventory_panel == null:
		return
	if field.inventory_panel.get_meta(field.META_INVENTORY_UI_SPACING_APPLIED, false):
		return
	field._resolve_inventory_ui_nodes()
	if field.inv_scroll != null:
		field._inventory_scroll_apply_content_padding(field.inv_scroll, field.INVENTORY_UI_SCROLL_CONTENT_PAD)
		var vbox := field.inv_scroll.get_node_or_null("InventoryVBox") as VBoxContainer
		if vbox != null:
			vbox.add_theme_constant_override("separation", field.INVENTORY_UI_VBOX_SEP)
	if field.unit_grid != null:
		field.unit_grid.add_theme_constant_override("h_separation", field.INVENTORY_UI_GRID_SEP)
		field.unit_grid.add_theme_constant_override("v_separation", field.INVENTORY_UI_GRID_SEP)
	if field.convoy_grid != null:
		field.convoy_grid.add_theme_constant_override("h_separation", field.INVENTORY_UI_GRID_SEP)
		field.convoy_grid.add_theme_constant_override("v_separation", field.INVENTORY_UI_GRID_SEP)

	var info_bg := field.inventory_panel.get_node_or_null("Panel") as Panel
	var outer := float(field.INVENTORY_UI_INFO_PANEL_OUTER_PAD)
	if info_bg != null:
		info_bg.offset_left += outer
		info_bg.offset_top += outer
		info_bg.offset_right -= outer
		info_bg.offset_bottom -= outer
		field._style_inventory_item_info_backdrop(info_bg)

	var dpad := float(field.INVENTORY_UI_DESC_TEXT_PAD)
	if field.inv_desc_label != null:
		field.inv_desc_label.offset_left += dpad
		field.inv_desc_label.offset_top += dpad
		field.inv_desc_label.offset_right -= dpad
		field.inv_desc_label.offset_bottom -= dpad

	field.inventory_panel.set_meta(field.META_INVENTORY_UI_SPACING_APPLIED, true)


static func populate_unit_inventory_list(field) -> void:
	if field.unit_grid == null:
		return
	field._clear_grids()
	if field.inv_desc_label:
		field.inv_desc_label.text = "Select an item to view details."
		field._queue_refit_item_description_panels()

	var inv = []
	if "inventory" in field.unit_managing_inventory:
		inv = field.unit_managing_inventory.inventory
	field._build_grid_items(field.unit_grid, inv, "unit_personal", field.unit_managing_inventory, 5)
	field._battle_try_flash_pending_inv_slot(field.unit_grid)


static func wait_for_loot_window_close(field) -> void:
	while field.is_inside_tree() and field._is_loot_window_active():
		await field.loot_window_closed


static func show_loot_window(field) -> void:
	if CampaignManager.battle_skip_loot_window:
		TradeInventoryHelpers.instant_resolve_loot_without_reveal(field)
		return

	field._ensure_loot_item_info_ui()
	field.loot_item_list.clear()
	if field.loot_desc_label:
		field.loot_desc_label.text = "Select an item to view details."

	# Lock the map
	if field.player_state:
		field.player_state.is_forecasting = true

	field.get_tree().paused = true

	# Ensure the UI keeps running while the game is paused
	field.loot_window.process_mode = Node.PROCESS_MODE_ALWAYS

	# 1. Setup for the Elastic Pop-in
	field.loot_window.scale = Vector2(0.5, 0.5)
	field.loot_window.modulate.a = 0.0
	field.loot_window.visible = true

	if field.close_loot_button:
		field.close_loot_button.disabled = true

	var open_tween: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	open_tween.tween_property(field.loot_window, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open_tween.tween_property(field.loot_window, "modulate:a", 1.0, 0.14)

	await open_tween.finished
	await field.get_tree().create_timer(0.1, true, false, true).timeout

	# --- NEW: GROUP STACKABLE LOOT FOR THE REVEAL ---
	var display_items = []
	for item in field.pending_loot:
		var can_stack = (item is ConsumableData) or (item is ChestKeyData) or (item is MaterialData)
		var found_stack = false
		if can_stack:
			for d in display_items:
				if d.item.get("item_name") != null and d.item.get("item_name") == item.get("item_name"):
					d.count += 1
					found_stack = true
					break
		if not found_stack:
			display_items.append({"item": item, "count": 1})
	# ------------------------------------------------

	# 2. The Sequential Item Reveal with Rarity! (row spotlight + combo pacing + rarity punctuation)
	var current_pitch = 1.0
	var chain_idx := 0

	for d in display_items:
		var item = d.item
		var display_text = field._get_item_display_text(item)

		# Add the (x3) multiplier text if there is more than 1
		if d.count > 1:
			display_text += " (x" + str(d.count) + ")"

		var img = item.icon if "icon" in item else null

		var rarity = item.get("rarity") if item.get("rarity") != null else "Common"
		var item_color = Color.WHITE
		var is_legendary_or_epic = false

		match rarity:
			"Uncommon": item_color = Color(0.2, 1.0, 0.2) # Green
			"Rare": item_color = Color(0.2, 0.5, 1.0) # Blue
			"Epic":
				item_color = Color(0.8, 0.2, 1.0) # Purple
				is_legendary_or_epic = true
			"Legendary":
				item_color = Color(1.0, 0.8, 0.2) # Gold
				is_legendary_or_epic = true

		# Add the item to the UI list and paint it the rarity color
		var idx = field.loot_item_list.add_item(display_text, img)
		field.loot_item_list.set_item_custom_fg_color(idx, item_color)

		# --- SAVE THE METADATA SO IT CAN BE CLICKED ---
		field.loot_item_list.set_item_metadata(idx, {"item": item, "count": d.count})

		# Per-row slide-in spotlight + list pop (all rarities)
		await _loot_reveal_row_spotlight_and_pop(field, idx, item_color, is_legendary_or_epic)

		# --- THE REVEAL JUICE ---
		if is_legendary_or_epic:
			if field.epic_level_up_sound != null and field.epic_level_up_sound.stream != null:
				field.epic_level_up_sound.play()

			field.screen_shake(17.5, 0.45)

			_loot_loot_window_rarity_punch(field)

			var flash_rect = ColorRect.new()
			flash_rect.size = field.get_viewport_rect().size
			flash_rect.color = item_color
			flash_rect.modulate.a = 0.62
			flash_rect.process_mode = Node.PROCESS_MODE_ALWAYS
			field.get_node("UI").add_child(flash_rect)

			var hit_flash: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			hit_flash.tween_property(flash_rect, "modulate:a", 0.0, 0.34)
			hit_flash.tween_callback(flash_rect.queue_free)

			await field.get_tree().create_timer(0.22, true, false, true).timeout
			field.screen_shake(10.0, 0.17)
			if rarity == "Legendary" and field.crit_sound != null and field.crit_sound.stream != null:
				field.crit_sound.pitch_scale = 1.35
				field.crit_sound.play()
				field.crit_sound.pitch_scale = 1.0
			await field.get_tree().create_timer(0.2, true, false, true).timeout
		else:
			if field.select_sound != null and field.select_sound.stream != null:
				field.select_sound.pitch_scale = current_pitch
				field.select_sound.play()
				current_pitch = min(current_pitch + 0.15, 2.0)

			field.screen_shake(3.6, 0.08)

			var combo_gap: float = maxf(0.06, 0.19 - 0.028 * minf(float(chain_idx), 6.0))
			await field.get_tree().create_timer(combo_gap, true, false, true).timeout

		chain_idx += 1

	if field.select_sound != null and field.select_sound.stream != null:
		field.select_sound.pitch_scale = 1.0

	if display_items.size() > 1:
		field.screen_shake(5.0, 0.09)

	if display_items.size() > 0:
		await _loot_finalize_reveal_payoff(field)

	if field.close_loot_button:
		field.close_loot_button.disabled = false

	if field.loot_item_list.item_count > 0:
		field.loot_item_list.select(0)
		field._on_loot_item_selected(0)
	else:
		field._queue_refit_item_description_panels()


static func _loot_reveal_row_spotlight_and_pop(field, idx: int, item_color: Color, is_high_rarity: bool) -> void:
	if field.loot_item_list == null or not field.is_inside_tree():
		return
	await field.get_tree().process_frame
	if idx < 0 or idx >= field.loot_item_list.item_count:
		return
	var r: Rect2 = field.loot_item_list.get_item_rect(idx, true)
	var row_glow := ColorRect.new()
	row_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_glow.process_mode = Node.PROCESS_MODE_ALWAYS
	var gc := item_color
	gc.a = 0.44
	row_glow.color = gc
	field.loot_item_list.add_child(row_glow)
	row_glow.position = r.position + Vector2(-44.0, 0.0)
	row_glow.size = r.size
	row_glow.modulate.a = 0.0
	var slide: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	slide.set_parallel(true)
	slide.tween_property(row_glow, "position:x", r.position.x, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slide.tween_property(row_glow, "modulate:a", 1.0, 0.09).from(0.0)
	await slide.finished
	var fade: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(row_glow, "modulate:a", 0.0, 0.15)
	fade.tween_callback(row_glow.queue_free)
	await fade.finished
	var pop_sc := 1.048 if is_high_rarity else 1.028
	var list_pop: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	list_pop.tween_property(field.loot_item_list, "scale", Vector2(pop_sc, pop_sc), 0.055).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	list_pop.tween_property(field.loot_item_list, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await list_pop.finished


static func _loot_loot_window_rarity_punch(field) -> void:
	if field.loot_window == null or not field.is_inside_tree():
		return
	var tw: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(field.loot_window, "scale", Vector2(1.072, 1.072), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(field.loot_window, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


static func _loot_finalize_reveal_payoff(field) -> void:
	if field.loot_window == null or not field.is_inside_tree():
		return
	var tww: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tww.tween_property(field.loot_window, "scale", Vector2(1.038, 1.038), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tww.tween_property(field.loot_window, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await tww.finished
	if field.loot_item_list != null:
		var twl: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		twl.tween_property(field.loot_item_list, "modulate", Color(1.06, 1.04, 0.98, 1.0), 0.07)
		twl.tween_property(field.loot_item_list, "modulate", Color.WHITE, 0.16)
		await twl.finished
	if field.select_sound != null and field.select_sound.stream != null:
		field.select_sound.pitch_scale = 1.14
		field.select_sound.play()
		field.select_sound.pitch_scale = 1.0
