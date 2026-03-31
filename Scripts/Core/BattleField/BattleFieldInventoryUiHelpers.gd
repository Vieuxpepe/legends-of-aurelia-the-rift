extends RefCounted

# Inventory / loot UI helpers extracted from `BattleField.gd`.

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

	var open_tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	open_tween.tween_property(field.loot_window, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open_tween.tween_property(field.loot_window, "modulate:a", 1.0, 0.2)

	await open_tween.finished
	await field.get_tree().create_timer(0.2, true, false, true).timeout

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

	# 2. The Sequential Item Reveal with Rarity!
	var current_pitch = 1.0

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

		# --- THE REVEAL JUICE ---
		if is_legendary_or_epic:
			if field.epic_level_up_sound != null and field.epic_level_up_sound.stream != null:
				field.epic_level_up_sound.play()

			field.screen_shake(15.0, 0.4)

			var flash_rect = ColorRect.new()
			flash_rect.size = field.get_viewport_rect().size
			flash_rect.color = item_color
			flash_rect.modulate.a = 0.5
			flash_rect.process_mode = Node.PROCESS_MODE_ALWAYS
			field.get_node("UI").add_child(flash_rect)

			var hit_flash = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			hit_flash.tween_property(flash_rect, "modulate:a", 0.0, 0.5)
			hit_flash.tween_callback(flash_rect.queue_free)

			await field.get_tree().create_timer(0.8, true, false, true).timeout
		else:
			if field.select_sound.stream != null:
				field.select_sound.pitch_scale = current_pitch
				field.select_sound.play()
				current_pitch = min(current_pitch + 0.15, 2.0)

			field.screen_shake(3.0, 0.1)
			await field.get_tree().create_timer(0.3, true, false, true).timeout

	if field.select_sound.stream != null:
		field.select_sound.pitch_scale = 1.0

	if field.close_loot_button:
		field.close_loot_button.disabled = false

	if field.loot_item_list.item_count > 0:
		field.loot_item_list.select(0)
		field._on_loot_item_selected(0)
	else:
		field._queue_refit_item_description_panels()

