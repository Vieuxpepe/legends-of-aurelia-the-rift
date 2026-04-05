extends RefCounted

# Trade / inventory / loot logic beyond the thin UI helpers.
# This extraction focuses on grid rebuild mechanics + trade swapping.

const FateCardLootHelpers = preload("res://Scripts/Core/FateCardLootHelpers.gd")


static func _find_player_dragon_with_space(field) -> Node2D:
	if field.player_container == null:
		return null
	for unit in field.player_container.get_children():
		if not is_instance_valid(unit) or unit.is_queued_for_deletion() or unit.current_hp <= 0:
			continue
		if field._is_unit_dragon(unit) and unit.inventory.size() < 5:
			return unit
	return null


static func _rehome_convoy_locked_dragon_weapons(field) -> void:
	if field.player_inventory == null or field.player_inventory.is_empty():
		return
	for i in range(field.player_inventory.size() - 1, -1, -1):
		var item = field.player_inventory[i]
		if not (item is WeaponData):
			continue
		if not field._is_weapon_convoy_locked(item as WeaponData):
			continue
		var dragon_target: Node2D = _find_player_dragon_with_space(field)
		if dragon_target == null:
			continue
		field.player_inventory.remove_at(i)
		dragon_target.inventory.append(item)


static func populate_convoy_list(field) -> void:
	if field.convoy_grid == null or field.inv_scroll == null:
		return

	_rehome_convoy_locked_dragon_weapons(field)
	field._clear_grids()
	if field.inv_desc_label:
		field.inv_desc_label.text = "Select an item to view details."
		field._queue_refit_item_description_panels()

	# 1. Build the Main Convoy Grid
	field._build_grid_items(field.convoy_grid, field.player_inventory, "convoy", null)

	# 2. Dynamically build a mini-grid for EVERY unit on the board!
	var vbox = field.inv_scroll.get_node_or_null("InventoryVBox")
	if vbox == null:
		return

	for unit in field.player_container.get_children():
		if unit.is_queued_for_deletion() or unit.current_hp <= 0:
			continue

		# Create a visual header with the unit's name
		var header = Label.new()
		header.text = "\n--- " + unit.unit_name.to_upper() + "'S BACKPACK ---"
		header.add_theme_color_override("font_color", Color.CYAN)
		header.add_theme_font_size_override("font_size", 18)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.set_meta("is_dynamic", true) # Tag it so we can delete it later
		vbox.add_child(header)

		# Create a new 5-column grid just for this unit
		var u_grid = GridContainer.new()
		u_grid.columns = 5
		u_grid.add_theme_constant_override("h_separation", field.INVENTORY_UI_GRID_SEP)
		u_grid.add_theme_constant_override("v_separation", field.INVENTORY_UI_GRID_SEP)
		u_grid.set_meta("is_dynamic", true) # Tag it so we can delete it later
		vbox.add_child(u_grid)

		var inv = []
		if "inventory" in unit:
			inv = unit.inventory

		# Fill their specific grid with their items!
		field._build_grid_items(u_grid, inv, "unit_personal", unit, 5)


static func clear_grids(field) -> void:
	# 1. Clear static grids
	if field.unit_grid != null:
		for child in field.unit_grid.get_children():
			child.queue_free()
	if field.convoy_grid != null:
		for child in field.convoy_grid.get_children():
			child.queue_free()

	# 2. Clear dynamically generated unit grids
	if field.inv_scroll == null:
		return
	var vbox = field.inv_scroll.get_node_or_null("InventoryVBox")
	if vbox == null:
		return
	for child in vbox.get_children():
		if child.has_meta("is_dynamic"):
			child.queue_free()

	field.selected_inventory_meta.clear()
	field.equip_button.disabled = true
	field.use_button.disabled = true


static func build_grid_items(
	field,
	grid: GridContainer,
	item_array: Array,
	source_type: String,
	owner_unit: Node2D = null,
	min_slots: int = 0
) -> void:
	var display_items = []

	# 1. Compress the array for stacking
	for i in range(item_array.size()):
		var item = item_array[i]
		if item == null:
			continue

		var can_stack = (item is ConsumableData) or (item is ChestKeyData) or (item is MaterialData)
		var found_stack = false

		# We only stack in the Convoy! Personal backpacks remain 1 slot = 1 item.
		if can_stack and source_type == "convoy":
			for d in display_items:
				var d_name = d.item.get("weapon_name") if d.item.get("weapon_name") != null else d.item.get("item_name")
				var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")

				if d_name != null and i_name != null and d_name == i_name:
					d.count += 1
					d.indices.append(i)
					found_stack = true
					break

		if not found_stack:
			display_items.append({"item": item, "count": 1, "indices": [i]})

	# 2. Pad with empty slots to meet min_slots
	var total_slots = max(display_items.size(), min_slots)

	for i in range(total_slots):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(64, 64)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		style.border_width_bottom = 2
		style.border_color = Color(0.3, 0.3, 0.3)
		btn.add_theme_stylebox_override("normal", style)

		grid.add_child(btn)

		if i < display_items.size():
			var d = display_items[i]
			var item = d.item
			var count = d.count
			var real_index = d.indices[0]

			if item.get("icon") != null:
				btn.icon = item.icon
				btn.expand_icon = true
			else:
				var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
				btn.text = str(i_name).substr(0, 3) if i_name else "???"

			# Stack counter
			if count > 1:
				var count_lbl = Label.new()
				count_lbl.text = "x" + str(count)
				count_lbl.add_theme_font_size_override("font_size", 18)
				count_lbl.add_theme_color_override("font_color", Color.WHITE)
				count_lbl.add_theme_constant_override("outline_size", 6)
				count_lbl.add_theme_color_override("font_outline_color", Color.BLACK)

				btn.add_child(count_lbl)
				count_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
				count_lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
				count_lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
				count_lbl.offset_right = -4
				count_lbl.offset_bottom = -2

			var meta = {
				"source": source_type,
				"index": real_index,
				"item": item,
				"unit": owner_unit,
				"count": count
			}
			btn.set_meta("inv_data", meta)

			var is_usable_for_owner: bool = true
			if owner_unit != null and item is WeaponData:
				is_usable_for_owner = field._unit_can_use_item_for_ui(owner_unit, item)

			if not is_usable_for_owner:
				btn.modulate = Color(1.0, 0.55, 0.55, 0.95)

				var unusable_badge = Label.new()
				unusable_badge.text = "X"
				unusable_badge.add_theme_font_size_override("font_size", 18)
				unusable_badge.add_theme_color_override("font_color", Color.RED)
				unusable_badge.add_theme_constant_override("outline_size", 6)
				unusable_badge.add_theme_color_override("font_outline_color", Color.BLACK)
				btn.add_child(unusable_badge)
				unusable_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
				unusable_badge.position = Vector2(-10, 2)

			if owner_unit != null and item == owner_unit.get("equipped_weapon"):
				var eq_style = style.duplicate()
				eq_style.border_color = Color.GOLD
				eq_style.border_width_left = 2
				eq_style.border_width_top = 2
				eq_style.border_width_right = 2
				btn.add_theme_stylebox_override("normal", eq_style)
				field._add_equipped_badge_to_inv_button(btn)

			btn.pressed.connect(func(): field._on_grid_item_clicked(btn, meta))
		else:
			btn.disabled = true
			var empty_style = style.duplicate()
			empty_style.bg_color = Color(0.05, 0.05, 0.05, 0.5)
			btn.add_theme_stylebox_override("disabled", empty_style)


static func distribute_pending_loot_to_inventory(field) -> void:
	var recipient = field.loot_recipient if is_instance_valid(field.loot_recipient) else field.player_state.active_unit
	var should_save_fate_unlocks: bool = false
	for item in field.pending_loot:
		if item == null:
			continue
		if FateCardLootHelpers.is_fate_card_loot(item):
			var unlock_result: Dictionary = FateCardLootHelpers.apply_fate_card_unlock(item, false)
			var card_name: String = str(unlock_result.get("card_name", "Unknown Card"))
			if bool(unlock_result.get("unlocked", false)):
				field.add_combat_log("Fate Card unlocked permanently: " + card_name + ".", "gold")
				should_save_fate_unlocks = true
			elif bool(unlock_result.get("duplicate", false)):
				field.add_combat_log("Fate Card already owned: " + card_name + ".", "lightgray")
			else:
				field.add_combat_log("Failed to unlock Fate Card: " + card_name + ".", "orange")
			continue
		var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
		if item is WeaponData and field._is_weapon_convoy_locked(item as WeaponData):
			var dragon_target: Node2D = null
			if is_instance_valid(recipient) and recipient.get_parent() == field.player_container and field._is_unit_dragon(recipient) and recipient.inventory.size() < 5:
				dragon_target = recipient
			if dragon_target == null:
				dragon_target = _find_player_dragon_with_space(field)
			if dragon_target != null:
				dragon_target.inventory.append(item)
				field.add_combat_log(dragon_target.unit_name + " secured " + str(i_name) + " (dragon-bound).", "orange")
			else:
				field.player_inventory.append(item)
				field.add_combat_log("No dragon backpack space for " + str(i_name) + ". Sent to Convoy temporarily.", "orange")
			continue

		if item is MaterialData:
			field.player_inventory.append(item)
			field.add_combat_log(str(i_name) + " sent to Convoy.", "gray")
		else:
			if is_instance_valid(recipient) and recipient.get_parent() == field.player_container:
				if recipient.inventory.size() < 5:
					recipient.inventory.append(item)
					field.add_combat_log(recipient.unit_name + " pocketed " + str(i_name) + ".", "cyan")
				else:
					field.player_inventory.append(item)
					field.add_combat_log(recipient.unit_name + "'s pockets full. Sent to Convoy.", "gray")
			else:
				field.player_inventory.append(item)
				field.add_combat_log(str(i_name) + " sent to Convoy.", "gray")
	if should_save_fate_unlocks and CampaignManager != null and CampaignManager.has_method("save_current_progress"):
		CampaignManager.save_current_progress()


## Skip reveal UI: same distribution and completion signals as closing the loot window, without popup or fly-in animations.
static func instant_resolve_loot_without_reveal(field) -> void:
	if field.pending_loot.is_empty():
		return
	var floater_pos := Vector2.ZERO
	var floater_anchor: Node2D = null
	if is_instance_valid(field.loot_recipient):
		floater_anchor = field.loot_recipient
	elif field.player_state != null and is_instance_valid(field.player_state.active_unit):
		floater_anchor = field.player_state.active_unit
	if floater_anchor != null:
		floater_pos = floater_anchor.global_position + Vector2(32, -32)
	distribute_pending_loot_to_inventory(field)
	if floater_anchor != null and field.has_method("spawn_loot_text"):
		field.spawn_loot_text("+ Loot", Color(1.0, 0.92, 0.45, 1.0), floater_pos, {"tier": FloatingCombatText.Tier.NORMAL, "stack_anchor": floater_anchor})
	field.pending_loot.clear()
	field.loot_recipient = null
	if field.player_state:
		field.player_state.is_forecasting = false
	field.get_tree().paused = false
	if field.close_loot_button:
		field.close_loot_button.disabled = false
	if field.loot_window:
		field.loot_window.visible = false
	var deferred_result: String = field._deferred_battle_result_after_loot
	field._deferred_battle_result_after_loot = ""
	field.loot_window_closed.emit()
	if deferred_result != "":
		field.call_deferred("_apply_deferred_battle_result_after_loot", deferred_result)
	field.update_unit_info_panel()


static func execute_trade_swap(field, side1: String, idx1: int, side2: String, idx2: int) -> void:
	# 1. Normalize both arrays to exactly 5 slots (prevents crash on empty slot clicks)
	var inv_a = field.trade_unit_a.inventory.duplicate()
	var inv_b = field.trade_unit_b.inventory.duplicate()
	inv_a.resize(5)
	inv_b.resize(5)

	# 2. Point to the correct arrays based on the click
	var target_inv1 = inv_a if side1 == "left" else inv_b
	var target_inv2 = inv_a if side2 == "left" else inv_b

	# 2.5. Safety gate: locked dragon weapons cannot move between inventories.
	var item_a = target_inv1[idx1]
	var item_b = target_inv2[idx2]
	var a_locked: bool = item_a is WeaponData and field._is_weapon_non_tradeable(item_a as WeaponData)
	var b_locked: bool = item_b is WeaponData and field._is_weapon_non_tradeable(item_b as WeaponData)
	if a_locked or b_locked:
		field.play_ui_sfx(field.UISfx.INVALID)
		field.add_combat_log("Dragon-bound weapons cannot be traded.", "orange")
		return

	# 3. Swap the data
	var temp = target_inv1[idx1]
	target_inv1[idx1] = target_inv2[idx2]
	target_inv2[idx2] = temp

	# 4. Strip the empty slots out and save it back to the units
	field.trade_unit_a.inventory.clear()
	for item in inv_a:
		if item != null:
			field.trade_unit_a.inventory.append(item)

	field.trade_unit_b.inventory.clear()
	for item in inv_b:
		if item != null:
			field.trade_unit_b.inventory.append(item)


static func on_close_loot_pressed(field) -> void:
	# 1. Immediately hide the popup UI to clear the screen
	var close_tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	close_tween.tween_property(field.loot_window, "scale", Vector2(0.5, 0.5), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	close_tween.tween_property(field.loot_window, "modulate:a", 0.0, 0.2)
	close_tween.chain().tween_callback(func(): field.loot_window.visible = false)

	field.close_loot_button.disabled = true

	# 2. Distribute Loot & Keep track of the EXACT items we added
	var looted_items_refs: Array = field.pending_loot.duplicate()
	distribute_pending_loot_to_inventory(field)

	await close_tween.finished
	# Fate cards are permanent unlocks, not inventory items; skip fly-to-slot visuals for them.
	var fly_loot_items: Array = []
	for item in looted_items_refs:
		if item != null and not FateCardLootHelpers.is_fate_card_loot(item):
			fly_loot_items.append(item)
	looted_items_refs = fly_loot_items
	if looted_items_refs.is_empty():
		field.inventory_panel.visible = false
		field.pending_loot.clear()
		field.loot_recipient = null
		field.close_loot_button.disabled = false
		if field.player_state:
			field.player_state.is_forecasting = false
		field.get_tree().paused = false
		var deferred_result_now: String = field._deferred_battle_result_after_loot
		field._deferred_battle_result_after_loot = ""
		field.loot_window_closed.emit()
		if deferred_result_now != "":
			field.call_deferred("_apply_deferred_battle_result_after_loot", deferred_result_now)
		field.update_unit_info_panel()
		return

	# 3. Open the Convoy view so we can see all grids
	field.unit_managing_inventory = null
	field._populate_convoy_list()

	field.equip_button.visible = false
	field.use_button.visible = false
	field.inventory_panel.visible = true

	await field.get_tree().process_frame
	await field.get_tree().process_frame

	# 4. THE FIX: Perfectly match the looted items to their UI buttons in order!
	var target_buttons = []
	var available_buttons = []

	var all_grids: Array = []
	if field.convoy_grid != null:
		all_grids.append(field.convoy_grid)

	var vbox = field.inv_scroll.get_node_or_null("InventoryVBox") if field.inv_scroll != null else null
	if vbox != null:
		for child in vbox.get_children():
			if child is GridContainer:
				all_grids.append(child)

	for grid in all_grids:
		for btn in grid.get_children():
			if btn.has_meta("inv_data"):
				available_buttons.append(btn)

	for item in looted_items_refs:
		var found_btn = null
		var is_stackable = (item is ConsumableData) or (item is ChestKeyData) or (item is MaterialData)
		var item_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")

		for i in range(available_buttons.size()):
			var btn = available_buttons[i]
			var btn_item = btn.get_meta("inv_data").get("item")

			if btn_item == item:
				found_btn = btn
				if not is_stackable:
					available_buttons.remove_at(i) # Uniques consume the slot permanently
				break
			elif is_stackable and btn_item != null:
				var b_name = btn_item.get("weapon_name") if btn_item.get("weapon_name") != null else btn_item.get("item_name")
				if b_name == item_name:
					found_btn = btn
					# Do NOT remove it from available_buttons, so the next stackable item can also fly here!
					break

		if found_btn == null:
			found_btn = field.convoy_button # Failsafe

		target_buttons.append(found_btn)
		if found_btn is Button and found_btn != field.convoy_button:
			found_btn.modulate.a = 0.0 # Hide it until the flying icon hits it

	# 5. Spawn and Fly the Icons!
	var vp_center = field.get_viewport_rect().size / 2.0

	var fly_layer = CanvasLayer.new()
	fly_layer.layer = 150
	fly_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	field.add_child(fly_layer)

	for i in range(looted_items_refs.size()):
		var item = looted_items_refs[i]
		var target_btn = target_buttons[i]

		var flying_icon = TextureRect.new()
		flying_icon.texture = item.get("icon")
		flying_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flying_icon.custom_minimum_size = Vector2(64, 64)
		flying_icon.pivot_offset = Vector2(32, 32)
		fly_layer.add_child(flying_icon)

		flying_icon.global_position = vp_center + Vector2(randf_range(-100, 100), randf_range(-100, 100))

		var fly_tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fly_tween.tween_interval(i * 0.15)
		fly_tween.tween_property(flying_icon, "global_position", target_btn.global_position, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

		# THE BIND FIX: We force Godot to remember EXACTLY which item is attached to this animation
		var impact_func = func(cb_item: Resource, cb_btn: Button, cb_icon: TextureRect):
			cb_icon.queue_free()

			var rarity: String = cb_item.get("rarity") if cb_item.get("rarity") != null else "Common"
			var rarity_lc: String = rarity.to_lower()
			var is_mythic: bool = rarity_lc == "mythic"
			var is_high_tier: bool = is_mythic or rarity_lc == "epic" or rarity_lc == "legendary"

			if is_high_tier:
				if field.crit_sound and field.crit_sound.stream != null:
					var p = AudioStreamPlayer.new()
					p.stream = field.crit_sound.stream
					p.pitch_scale = randf_range(1.45, 1.6) if is_mythic else randf_range(1.2, 1.4)
					p.volume_db = 1.5 if is_mythic else -2.0
					field.add_child(p)
					p.play()
					p.finished.connect(p.queue_free)

				var crack_node = Node2D.new()
				crack_node.position = cb_btn.size / 2.0
				cb_btn.add_child(crack_node)

				var angles = [0.5, 2.1, 3.8, 5.0, 1.2]
				for a in angles:
					var line = Line2D.new()
					line.width = 4.0 if is_mythic else 3.0
					line.default_color = Color(0.05, 0.05, 0.05, 0.9)
					line.add_point(Vector2.ZERO)
					line.add_point(Vector2(cos(a) * 15, sin(a) * 15))
					line.add_point(Vector2(cos(a) * 35 + randf_range(-10, 10), sin(a) * 35 + randf_range(-10, 10)))
					crack_node.add_child(line)

				var flash = ColorRect.new()
				flash.set_anchors_preset(Control.PRESET_FULL_RECT)
				if is_mythic:
					flash.color = Color(0.94, 0.58, 0.08)
				elif rarity_lc == "epic":
					flash.color = Color(0.8, 0.2, 1.0)
				else:
					flash.color = Color(1.0, 0.8, 0.2)
				cb_btn.add_child(flash)

				cb_btn.modulate.a = 1.0
				cb_btn.scale = Vector2(1.65, 1.65) if is_mythic else Vector2(1.5, 1.5)
				cb_btn.pivot_offset = cb_btn.size / 2.0

				var bounce = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
				bounce.tween_property(cb_btn, "scale", Vector2.ONE, 0.36 if is_mythic else 0.3).set_trans(Tween.TRANS_BOUNCE)
				bounce.tween_property(flash, "modulate:a", 0.0, 0.5 if is_mythic else 0.4)

				var crack_fade = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				crack_fade.tween_interval(1.2 if is_mythic else 1.0)
				crack_fade.tween_property(crack_node, "modulate:a", 0.0, 0.3)
				crack_fade.chain().tween_callback(func():
					if is_instance_valid(crack_node): crack_node.queue_free()
					if is_instance_valid(flash): flash.queue_free()
				)
				if is_mythic:
					field.screen_shake(18.0, 0.4)
				else:
					field.screen_shake(12.0, 0.25)
			else:
				if field.select_sound and field.select_sound.stream != null:
					var p = AudioStreamPlayer.new()
					p.stream = field.select_sound.stream
					p.pitch_scale = randf_range(1.5, 1.8)
					p.volume_db = -5.0
					field.add_child(p)
					p.play()
					p.finished.connect(p.queue_free)

				cb_btn.modulate.a = 1.0
				cb_btn.scale = Vector2(1.2, 1.2)
				cb_btn.pivot_offset = cb_btn.size / 2.0

				var bounce = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				bounce.tween_property(cb_btn, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BOUNCE)

		# Attach the bound variables!
		fly_tween.tween_callback(impact_func.bind(item, target_btn, flying_icon))

	# 6. Wait for all animations to finish
	var max_wait_time = 0.4 + (looted_items_refs.size() * 0.15) + 1.5
	await field.get_tree().create_timer(max_wait_time, true, false, true).timeout

	fly_layer.queue_free()

	# 7. Close everything
	field.inventory_panel.visible = false
	field.pending_loot.clear()
	field.loot_recipient = null
	field.close_loot_button.disabled = false

	if field.player_state:
		field.player_state.is_forecasting = false
	field.get_tree().paused = false

	var deferred_result: String = field._deferred_battle_result_after_loot
	field._deferred_battle_result_after_loot = ""
	field.loot_window_closed.emit()
	if deferred_result != "":
		field.call_deferred("_apply_deferred_battle_result_after_loot", deferred_result)

	field.update_unit_info_panel()
