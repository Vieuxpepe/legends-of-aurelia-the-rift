extends RefCounted

# Inventory / loot UI helpers extracted from `BattleField.gd`.

const TradeInventoryHelpers = preload("res://Scripts/Core/BattleField/BattleFieldTradeInventoryHelpers.gd")
const FateCardCatalog = preload("res://Scripts/FateCardCatalog.gd")
const FateCardLootData = preload("res://Resources/FateCardLootData.gd")
const FateCardLootHelpers = preload("res://Scripts/Core/FateCardLootHelpers.gd")

const FATE_CARD_PANEL_BG: Color = Color(0.11, 0.08, 0.05, 0.985)
const FATE_CARD_BORDER_SOFT: Color = Color(0.46, 0.36, 0.15, 0.96)
const FATE_CARD_TEXT: Color = Color(0.95, 0.92, 0.86, 1.0)
const FATE_CARD_TEXT_MUTED: Color = Color(0.76, 0.72, 0.66, 1.0)
const FATE_CARD_BUTTON_BG: Color = Color(0.28, 0.21, 0.13, 0.94)
const FATE_CARD_WIDTH: float = 282.0
const FATE_CARD_HEIGHT: float = 320.0
const FATE_CARD_FALLBACK_PORTRAIT_PATH: String = "res://Assets/Portraits/FateCardMatte/Portrait Hero 1.png"
const FATE_REVEAL_TARGET_SCALE_X: float = 0.94
const FATE_REVEAL_TARGET_SCALE_Y: float = 0.94
const FATE_REVEAL_POP_SCALE_X: float = 1.02
const FATE_REVEAL_POP_SCALE_Y: float = 1.02

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
		var is_fate_card_drop: bool = FateCardLootHelpers.is_fate_card_loot(item)
		if is_fate_card_drop:
			await _loot_show_fate_card_front_reveal(field, item)
		var display_text = field._get_item_display_text(item)

		# Add the (x3) multiplier text if there is more than 1
		if d.count > 1:
			display_text += " (x" + str(d.count) + ")"

		var img = item.icon if "icon" in item else null

		var rarity: String = item.get("rarity") if item.get("rarity") != null else "Common"
		var rarity_lc: String = rarity.to_lower()
		var item_color = Color.WHITE
		var is_high_tier: bool = false
		var is_mythic: bool = false

		match rarity_lc:
			"uncommon":
				item_color = Color(0.2, 1.0, 0.2) # Green
			"rare":
				item_color = Color(0.2, 0.5, 1.0) # Blue
			"epic":
				item_color = Color(0.8, 0.2, 1.0) # Purple
				is_high_tier = true
			"legendary":
				item_color = Color(1.0, 0.8, 0.2) # Gold
				is_high_tier = true
			"mythic":
				item_color = Color(1.0, 0.56, 0.06) # High-impact amber
				is_high_tier = true
				is_mythic = true

		# Add the item to the UI list and paint it the rarity color
		var idx = field.loot_item_list.add_item(display_text, img)
		field.loot_item_list.set_item_custom_fg_color(idx, item_color)

		# --- SAVE THE METADATA SO IT CAN BE CLICKED ---
		field.loot_item_list.set_item_metadata(idx, {"item": item, "count": d.count})

		# Per-row slide-in spotlight + list pop (all rarities)
		await _loot_reveal_row_spotlight_and_pop(field, idx, item_color, is_high_tier)

		# --- THE REVEAL JUICE ---
		if is_high_tier:
			if field.epic_level_up_sound != null and field.epic_level_up_sound.stream != null:
				field.epic_level_up_sound.play()

			if is_mythic:
				field.screen_shake(24.0, 0.62)
			else:
				field.screen_shake(17.5, 0.45)

			_loot_loot_window_rarity_punch(field, 1.3 if is_mythic else 1.0)

			var flash_rect = ColorRect.new()
			flash_rect.size = field.get_viewport_rect().size
			flash_rect.color = item_color
			flash_rect.modulate.a = 0.78 if is_mythic else 0.62
			flash_rect.process_mode = Node.PROCESS_MODE_ALWAYS
			field.get_node("UI").add_child(flash_rect)

			var hit_flash: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			hit_flash.tween_property(flash_rect, "modulate:a", 0.0, 0.42 if is_mythic else 0.34)
			hit_flash.tween_callback(flash_rect.queue_free)

			await field.get_tree().create_timer(0.26 if is_mythic else 0.22, true, false, true).timeout
			if is_mythic:
				field.screen_shake(14.0, 0.24)
			else:
				field.screen_shake(10.0, 0.17)
			if (rarity_lc == "legendary" or is_mythic) and field.crit_sound != null and field.crit_sound.stream != null:
				field.crit_sound.pitch_scale = 1.5 if is_mythic else 1.35
				field.crit_sound.play()
				field.crit_sound.pitch_scale = 1.0
			await field.get_tree().create_timer(0.28 if is_mythic else 0.2, true, false, true).timeout
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


static func _loot_show_fate_card_front_reveal(field, item: Resource) -> void:
	if not FateCardLootHelpers.is_fate_card_loot(item):
		return
	var loot_card: FateCardLootData = item as FateCardLootData
	if loot_card == null:
		return

	var card_id: String = str(loot_card.card_id).strip_edges().to_lower()
	var card: Dictionary = _fate_lookup_card_by_id_or_name(card_id, str(loot_card.card_name))
	if card.is_empty():
		card = {
			"id": card_id,
			"name": str(loot_card.card_name).strip_edges(),
			"rarity": str(loot_card.card_rarity).strip_edges().to_lower(),
			"summary": "Permanent unlock",
			"description": str(loot_card.description).strip_edges()
		}
	if str(card.get("name", "")).strip_edges() == "":
		card["name"] = FateCardLootHelpers.get_fate_card_loot_label(loot_card)
	if str(card.get("rarity", "")).strip_edges() == "":
		card["rarity"] = "common"
	if str(card.get("id", "")).strip_edges() != "":
		card_id = str(card.get("id", "")).strip_edges().to_lower()
		card["id"] = card_id

	var layer := CanvasLayer.new()
	layer.layer = 260
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	field.add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 0.0
	root.offset_top = 0.0
	root.offset_right = 0.0
	root.offset_bottom = 0.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(root)

	var veil := ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.offset_left = 0.0
	veil.offset_top = 0.0
	veil.offset_right = 0.0
	veil.offset_bottom = 0.0
	veil.color = Color(0.0, 0.0, 0.0, 0.0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)

	var title := Label.new()
	title.text = "FATE CARD UNLOCKED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0
	title.anchor_top = 0.0
	title.anchor_right = 1.0
	title.anchor_bottom = 0.0
	title.offset_left = 0.0
	title.offset_top = 58.0
	title.offset_right = 0.0
	title.offset_bottom = 110.0
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.48, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)

	# Keep reveal portraits sourced from catalog card data to avoid icon overlays/masks.
	var card_panel: Control = _build_fate_drop_card_widget(card, null)
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.z_index = 3
	root.add_child(card_panel)
	var vp_size: Vector2 = field.get_viewport_rect().size
	var card_size: Vector2 = card_panel.custom_minimum_size
	if card_size == Vector2.ZERO:
		card_size = Vector2(FATE_CARD_WIDTH, FATE_CARD_HEIGHT)
	card_panel.pivot_offset = card_size * 0.5
	card_panel.position = vp_size * 0.5 - card_size * 0.5
	card_panel.scale = Vector2(0.02, FATE_REVEAL_TARGET_SCALE_Y)
	card_panel.rotation_degrees = -14.0
	card_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var reveal_burst: GPUParticles2D = _fate_build_reveal_gpu_burst(card, vp_size * 0.5)
	if reveal_burst != null:
		root.add_child(reveal_burst)

	if field.epic_level_up_sound != null and field.epic_level_up_sound.stream != null:
		field.epic_level_up_sound.play()
	if field.crit_sound != null and field.crit_sound.stream != null:
		field.crit_sound.pitch_scale = 1.58
		field.crit_sound.play()
		field.crit_sound.pitch_scale = 1.0
	field.screen_shake(22.0, 0.48)

	var intro: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	intro.tween_property(veil, "color:a", 0.76, 0.16)
	await intro.finished

	# Two-step self-turn: first swing through the back face, then settle front-facing.
	var flip_in: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	flip_in.tween_property(card_panel, "scale:x", -FATE_REVEAL_POP_SCALE_X, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	flip_in.tween_property(card_panel, "scale:y", FATE_REVEAL_POP_SCALE_Y, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	flip_in.tween_property(card_panel, "rotation_degrees", 7.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await flip_in.finished
	if reveal_burst != null:
		reveal_burst.restart()
		reveal_burst.emitting = true

	var flip_out: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	flip_out.tween_property(card_panel, "scale:x", FATE_REVEAL_POP_SCALE_X, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flip_out.tween_property(card_panel, "scale:y", FATE_REVEAL_POP_SCALE_Y, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flip_out.tween_property(card_panel, "rotation_degrees", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await flip_out.finished

	var settle: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	settle.tween_property(card_panel, "scale", Vector2(FATE_REVEAL_TARGET_SCALE_X, FATE_REVEAL_TARGET_SCALE_Y), 0.20).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	settle.tween_property(card_panel, "rotation_degrees", 0.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await settle.finished
	await field.get_tree().create_timer(0.74, true, false, true).timeout

	var outro: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	outro.tween_property(root, "modulate:a", 0.0, 0.18)
	outro.tween_property(card_panel, "scale", Vector2(0.98, 0.98), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await outro.finished
	if is_instance_valid(layer):
		layer.queue_free()


static func _build_fate_drop_card_widget(card: Dictionary, fallback_icon: Texture2D) -> Control:
	var rarity: String = str(card.get("rarity", "common")).to_lower()
	var rarity_color: Color = FateCardCatalog.get_rarity_color(rarity)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = FATE_CARD_WIDTH
	panel.offset_bottom = FATE_CARD_HEIGHT
	panel.custom_minimum_size = Vector2(FATE_CARD_WIDTH, FATE_CARD_HEIGHT)
	panel.size = panel.custom_minimum_size
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.clip_contents = true
	panel.add_theme_stylebox_override(
		"panel",
		_fate_make_panel_style(FATE_CARD_PANEL_BG, rarity_color, 14, 3, 8, 8)
	)
	panel.add_child(_fate_build_card_chrome_layer(rarity_color, false, false))

	var body := VBoxContainer.new()
	body.anchor_left = 0.0
	body.anchor_top = 0.0
	body.anchor_right = 1.0
	body.anchor_bottom = 1.0
	body.offset_left = 0.0
	body.offset_top = 0.0
	body.offset_right = 0.0
	body.offset_bottom = 0.0
	body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_theme_constant_override("separation", 6)
	panel.add_child(body)

	var portrait_frame := PanelContainer.new()
	# Match Fate hand card portrait footprint to keep reveal card proportions consistent.
	portrait_frame.custom_minimum_size = Vector2(0.0, 174.0)
	portrait_frame.clip_contents = true
	portrait_frame.add_theme_stylebox_override(
		"panel",
		_fate_make_panel_style(
			Color(0.06, 0.06, 0.06, 1.0),
			Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.75),
			10,
			1,
			0,
			0
		)
	)
	body.add_child(portrait_frame)

	var portrait_underlay := ColorRect.new()
	portrait_underlay.anchor_left = 0.0
	portrait_underlay.anchor_top = 0.0
	portrait_underlay.anchor_right = 1.0
	portrait_underlay.anchor_bottom = 1.0
	portrait_underlay.offset_left = 2.0
	portrait_underlay.offset_top = 2.0
	portrait_underlay.offset_right = -2.0
	portrait_underlay.offset_bottom = -2.0
	portrait_underlay.color = Color(0.03, 0.03, 0.03, 1.0)
	portrait_underlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_underlay.z_index = 0
	portrait_frame.add_child(portrait_underlay)

	var portrait := TextureRect.new()
	portrait.anchor_left = 0.0
	portrait.anchor_top = 0.0
	portrait.anchor_right = 1.0
	portrait.anchor_bottom = 1.0
	portrait.offset_left = 2.0
	portrait.offset_top = 2.0
	portrait.offset_right = -2.0
	portrait.offset_bottom = -2.0
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	portrait.texture = _fate_load_card_portrait(card, fallback_icon)
	portrait.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	portrait.modulate = Color(1.0, 1.0, 1.0, 1.0)
	portrait.z_index = 1
	portrait_frame.add_child(portrait)
	var portrait_gloss := TextureRect.new()
	portrait_gloss.anchor_left = 0.0
	portrait_gloss.anchor_top = 0.0
	portrait_gloss.anchor_right = 1.0
	portrait_gloss.anchor_bottom = 0.0
	portrait_gloss.offset_left = 2.0
	portrait_gloss.offset_top = 2.0
	portrait_gloss.offset_right = -2.0
	portrait_gloss.offset_bottom = 46.0
	portrait_gloss.texture = _fate_make_vertical_gradient_texture(
		Color(1.0, 1.0, 1.0, 0.08),
		Color(1.0, 1.0, 1.0, 0.02),
		Color(1.0, 1.0, 1.0, 0.0),
		8,
		84
	)
	portrait_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait_gloss)
	_fate_add_corner_trim(portrait_frame, rarity_color, 6.0, 14.0, 2.0, 0.62)
	portrait_frame.add_child(_fate_build_rarity_sigil(rarity, rarity_color))


	# Keep the reveal portrait clean/readable; avoid extra overlays that can wash it out.

	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 6)
	body.add_child(chip_row)
	chip_row.add_child(_fate_build_card_chip(rarity.to_upper(), rarity_color, Color(0.10, 0.10, 0.10, 0.95), 11))
	chip_row.add_child(
		_fate_build_card_chip(
			"UNLOCK",
			Color(0.38, 0.98, 0.67, 1.0),
			Color(0.06, 0.18, 0.11, 0.96),
			11
		)
	)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", FATE_CARD_TEXT)
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	name_label.text = str(card.get("name", "Unknown Card")).to_upper()
	body.add_child(name_label)
	var accent_rule := ColorRect.new()
	accent_rule.custom_minimum_size = Vector2(0.0, 2.0)
	accent_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accent_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent_rule.color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.28)
	body.add_child(accent_rule)

	var summary_label := Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", 13)
	summary_label.add_theme_color_override("font_color", FATE_CARD_TEXT_MUTED)
	summary_label.text = str(card.get("summary", "Permanent card unlock."))
	body.add_child(summary_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 2.0)
	spacer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(spacer)

	var unlock_band := PanelContainer.new()
	unlock_band.custom_minimum_size = Vector2(0.0, 34.0)
	unlock_band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlock_band.add_theme_stylebox_override("panel", _fate_make_panel_style(FATE_CARD_BUTTON_BG, FATE_CARD_BORDER_SOFT, 10, 2, 10, 7))
	var unlock_label := Label.new()
	unlock_label.text = "PERMANENT UNLOCK"
	unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	unlock_label.add_theme_font_size_override("font_size", 17)
	unlock_label.add_theme_color_override("font_color", FATE_CARD_TEXT)
	unlock_band.add_child(unlock_label)
	body.add_child(unlock_band)

	return panel


static func _fate_lookup_card_by_id_or_name(card_id: String, card_name: String) -> Dictionary:
	var by_id: Dictionary = FateCardCatalog.get_card(card_id)
	if not by_id.is_empty():
		return by_id
	var wanted_name: String = card_name.strip_edges().to_lower()
	if wanted_name == "":
		return {}
	for card_any in FateCardCatalog.get_all_cards():
		var c: Dictionary = card_any
		if str(c.get("name", "")).strip_edges().to_lower() == wanted_name:
			return c.duplicate(true)
	return {}


static func _fate_load_card_portrait(card: Dictionary, fallback_icon: Texture2D) -> Texture2D:
	var path: String = str(card.get("portrait_path", "")).strip_edges()
	if path != "":
		if ResourceLoader.exists(path):
			var tex: Resource = load(path)
			if tex is Texture2D:
				var rebuilt_from_res: Texture2D = _fate_texture_with_dark_matte(tex as Texture2D)
				return rebuilt_from_res if rebuilt_from_res != null else (tex as Texture2D)
		var source_tex: Texture2D = _fate_load_portrait_texture_from_source(path)
		if source_tex != null:
			return source_tex
		var res_tex: Texture2D = _fate_load_portrait_texture_from_resource(path)
		if res_tex != null:
			return res_tex
	if fallback_icon != null:
		var fallback_from_tex: Texture2D = _fate_texture_with_dark_matte(fallback_icon)
		return fallback_from_tex if fallback_from_tex != null else fallback_icon
	if ResourceLoader.exists(FATE_CARD_FALLBACK_PORTRAIT_PATH):
		var backup_tex: Resource = load(FATE_CARD_FALLBACK_PORTRAIT_PATH)
		if backup_tex is Texture2D:
			return backup_tex as Texture2D
		var source_backup: Texture2D = _fate_load_portrait_texture_from_source(FATE_CARD_FALLBACK_PORTRAIT_PATH)
		if source_backup != null:
			return source_backup
		var backup_from_res: Texture2D = _fate_load_portrait_texture_from_resource(FATE_CARD_FALLBACK_PORTRAIT_PATH)
		if backup_from_res != null:
			return backup_from_res
	return null


static func _fate_load_portrait_texture_from_source(path: String) -> Texture2D:
	var clean_path: String = path.strip_edges()
	if clean_path == "":
		return null
	var img := Image.new()
	var err: Error = img.load(clean_path)
	if err != OK:
		return null
	return _fate_image_with_dark_matte(img)


static func _fate_load_portrait_texture_from_resource(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var tex_res: Resource = load(path)
	if tex_res is Texture2D:
		return _fate_texture_with_dark_matte(tex_res as Texture2D)
	return null


static func _fate_texture_with_dark_matte(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null:
		return tex
	if img.get_width() <= 0 or img.get_height() <= 0:
		return tex
	var rebuilt: Texture2D = _fate_image_with_dark_matte(img)
	return rebuilt if rebuilt != null else tex


static func _fate_image_with_dark_matte(source_img: Image) -> Texture2D:
	if source_img == null:
		return null
	if source_img.get_width() <= 0 or source_img.get_height() <= 0:
		return null
	var img := source_img.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var matte := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	matte.fill(Color(0.03, 0.03, 0.03, 1.0))
	matte.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i.ZERO)
	return ImageTexture.create_from_image(matte)


static func _fate_make_panel_style(
	bg: Color,
	border: Color,
	radius: int = 12,
	border_px: int = 2,
	pad_h: int = 8,
	pad_v: int = 8
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_px)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


static func _fate_build_card_chip(text: String, border: Color, bg: Color, font_size: int = 11) -> Control:
	var chip_panel := PanelContainer.new()
	chip_panel.add_theme_stylebox_override("panel", _fate_make_panel_style(bg, border, 8, 1, 6, 2))
	var chip_label := Label.new()
	chip_label.text = text
	chip_label.add_theme_font_size_override("font_size", font_size)
	chip_label.add_theme_color_override("font_color", border)
	chip_panel.add_child(chip_label)
	return chip_panel


static func _fate_build_rarity_particles_node(rarity: String) -> CPUParticles2D:
	var rank: int = FateCardCatalog.get_rarity_rank(rarity)
	if rank < 2:
		return null
	var p := CPUParticles2D.new()
	p.position = Vector2(142.0, 86.0)
	p.amount = 6 + (rank * 4)
	p.lifetime = 1.15
	p.one_shot = false
	p.explosiveness = 0.08
	p.randomness = 0.55
	p.emitting = true
	p.modulate = FateCardCatalog.get_rarity_color(rarity)
	p.z_index = 5
	p.z_as_relative = false
	return p


static func _fate_build_rarity_glow_overlay(rarity_color: Color, rarity_rank: int) -> ColorRect:
	var glow := ColorRect.new()
	glow.anchor_left = 0.0
	glow.anchor_top = 0.0
	glow.anchor_right = 1.0
	glow.anchor_bottom = 1.0
	glow.offset_left = 1.0
	glow.offset_top = 1.0
	glow.offset_right = -1.0
	glow.offset_bottom = -1.0
	# Keep rarity color off the portrait art itself; border/accent already carry the color identity.
	glow.color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return glow


static func _fate_add_rarity_sheen_animation(portrait_frame: Control, rarity_rank: int) -> void:
	if portrait_frame == null or rarity_rank < 1:
		return
	var stripe := ColorRect.new()
	var stripe_alpha: float = clampf(0.05 + (0.015 * float(rarity_rank)), 0.05, 0.12)
	stripe.color = Color(1.0, 1.0, 1.0, stripe_alpha)
	stripe.custom_minimum_size = Vector2(44.0, 360.0)
	stripe.size = stripe.custom_minimum_size
	stripe.position = Vector2(-88.0, -64.0)
	stripe.rotation_degrees = 18.0
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	stripe.material = mat
	portrait_frame.add_child(stripe)

	var travel_width: float = 420.0
	var sweep_time: float = clampf(0.78 - (0.06 * float(rarity_rank)), 0.5, 0.78)
	var pause_time: float = clampf(3.3 - (0.35 * float(rarity_rank)), 1.7, 3.3)
	var tw: Tween = stripe.create_tween()
	tw.set_loops()
	tw.tween_property(stripe, "position:x", travel_width, sweep_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(pause_time)
	tw.tween_property(stripe, "position:x", -88.0, 0.01)


static func _fate_build_card_chrome_layer(rarity_color: Color, active: bool, dimmed: bool) -> Control:
	var chrome := Control.new()
	chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	chrome.offset_left = 0.0
	chrome.offset_top = 0.0
	chrome.offset_right = 0.0
	chrome.offset_bottom = 0.0
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_alpha: float = 0.20 if active else 0.15
	if dimmed:
		top_alpha *= 0.45

	var backdrop := TextureRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.offset_left = 1.0
	backdrop.offset_top = 1.0
	backdrop.offset_right = -1.0
	backdrop.offset_bottom = -1.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.texture = _fate_make_vertical_gradient_texture(
		Color(rarity_color.r, rarity_color.g, rarity_color.b, top_alpha),
		Color(0.0, 0.0, 0.0, 0.03),
		Color(0.0, 0.0, 0.0, 0.18),
		8,
		256
	)
	chrome.add_child(backdrop)

	var crown := TextureRect.new()
	crown.anchor_left = 0.0
	crown.anchor_top = 0.0
	crown.anchor_right = 1.0
	crown.anchor_bottom = 0.0
	crown.offset_left = 12.0
	crown.offset_top = 8.0
	crown.offset_right = -12.0
	crown.offset_bottom = 52.0
	crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crown.texture = _fate_make_vertical_gradient_texture(
		Color(1.0, 1.0, 1.0, 0.07 if not dimmed else 0.04),
		Color(1.0, 1.0, 1.0, 0.02),
		Color(1.0, 1.0, 1.0, 0.0),
		8,
		88
	)
	chrome.add_child(crown)

	_fate_add_corner_trim(chrome, rarity_color, 7.0, 18.0, 2.0, 0.60 if not dimmed else 0.42)
	return chrome


static func _fate_build_rarity_sigil(rarity: String, rarity_color: Color) -> Control:
	var sigil_root := Control.new()
	sigil_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	sigil_root.offset_left = 0.0
	sigil_root.offset_top = 0.0
	sigil_root.offset_right = 0.0
	sigil_root.offset_bottom = 0.0
	sigil_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sigil := PanelContainer.new()
	sigil.anchor_left = 1.0
	sigil.anchor_top = 0.0
	sigil.anchor_right = 1.0
	sigil.anchor_bottom = 0.0
	sigil.offset_left = -44.0
	sigil.offset_top = 10.0
	sigil.offset_right = -10.0
	sigil.offset_bottom = 34.0
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sigil.add_theme_stylebox_override(
		"panel",
		_fate_make_panel_style(Color(0.09, 0.07, 0.05, 0.94), Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.92), 8, 2, 5, 3)
	)

	var sigil_label := Label.new()
	sigil_label.text = _fate_rarity_letter(rarity)
	sigil_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sigil_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sigil_label.add_theme_font_size_override("font_size", 12)
	sigil_label.add_theme_constant_override("outline_size", 2)
	sigil_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	sigil_label.add_theme_color_override("font_color", rarity_color)
	sigil.add_child(sigil_label)
	sigil_root.add_child(sigil)
	return sigil_root


static func _fate_rarity_letter(rarity: String) -> String:
	match FateCardCatalog.get_rarity_rank(rarity):
		4:
			return "L"
		3:
			return "E"
		2:
			return "R"
		1:
			return "C"
		_:
			return "?"


static func _fate_add_corner_trim(target: Control, rarity_color: Color, inset: float, segment_length: float, thickness: float, alpha: float) -> void:
	if target == null:
		return
	var trim_color: Color = Color(rarity_color.r, rarity_color.g, rarity_color.b, alpha)
	var top_left_h := ColorRect.new()
	top_left_h.anchor_left = 0.0
	top_left_h.anchor_right = 0.0
	top_left_h.anchor_top = 0.0
	top_left_h.anchor_bottom = 0.0
	top_left_h.offset_left = inset
	top_left_h.offset_top = inset
	top_left_h.offset_right = inset + segment_length
	top_left_h.offset_bottom = inset + thickness
	top_left_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left_h.color = trim_color
	target.add_child(top_left_h)

	var top_left_v := ColorRect.new()
	top_left_v.anchor_left = 0.0
	top_left_v.anchor_right = 0.0
	top_left_v.anchor_top = 0.0
	top_left_v.anchor_bottom = 0.0
	top_left_v.offset_left = inset
	top_left_v.offset_top = inset
	top_left_v.offset_right = inset + thickness
	top_left_v.offset_bottom = inset + segment_length
	top_left_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left_v.color = trim_color
	target.add_child(top_left_v)

	var top_right_h := ColorRect.new()
	top_right_h.anchor_left = 1.0
	top_right_h.anchor_right = 1.0
	top_right_h.anchor_top = 0.0
	top_right_h.anchor_bottom = 0.0
	top_right_h.offset_left = -inset - segment_length
	top_right_h.offset_top = inset
	top_right_h.offset_right = -inset
	top_right_h.offset_bottom = inset + thickness
	top_right_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_right_h.color = trim_color
	target.add_child(top_right_h)

	var top_right_v := ColorRect.new()
	top_right_v.anchor_left = 1.0
	top_right_v.anchor_right = 1.0
	top_right_v.anchor_top = 0.0
	top_right_v.anchor_bottom = 0.0
	top_right_v.offset_left = -inset - thickness
	top_right_v.offset_top = inset
	top_right_v.offset_right = -inset
	top_right_v.offset_bottom = inset + segment_length
	top_right_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_right_v.color = trim_color
	target.add_child(top_right_v)

	var bottom_left_h := ColorRect.new()
	bottom_left_h.anchor_left = 0.0
	bottom_left_h.anchor_right = 0.0
	bottom_left_h.anchor_top = 1.0
	bottom_left_h.anchor_bottom = 1.0
	bottom_left_h.offset_left = inset
	bottom_left_h.offset_top = -inset - thickness
	bottom_left_h.offset_right = inset + segment_length
	bottom_left_h.offset_bottom = -inset
	bottom_left_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_left_h.color = trim_color
	target.add_child(bottom_left_h)

	var bottom_left_v := ColorRect.new()
	bottom_left_v.anchor_left = 0.0
	bottom_left_v.anchor_right = 0.0
	bottom_left_v.anchor_top = 1.0
	bottom_left_v.anchor_bottom = 1.0
	bottom_left_v.offset_left = inset
	bottom_left_v.offset_top = -inset - segment_length
	bottom_left_v.offset_right = inset + thickness
	bottom_left_v.offset_bottom = -inset
	bottom_left_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_left_v.color = trim_color
	target.add_child(bottom_left_v)

	var bottom_right_h := ColorRect.new()
	bottom_right_h.anchor_left = 1.0
	bottom_right_h.anchor_right = 1.0
	bottom_right_h.anchor_top = 1.0
	bottom_right_h.anchor_bottom = 1.0
	bottom_right_h.offset_left = -inset - segment_length
	bottom_right_h.offset_top = -inset - thickness
	bottom_right_h.offset_right = -inset
	bottom_right_h.offset_bottom = -inset
	bottom_right_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_right_h.color = trim_color
	target.add_child(bottom_right_h)

	var bottom_right_v := ColorRect.new()
	bottom_right_v.anchor_left = 1.0
	bottom_right_v.anchor_right = 1.0
	bottom_right_v.anchor_top = 1.0
	bottom_right_v.anchor_bottom = 1.0
	bottom_right_v.offset_left = -inset - thickness
	bottom_right_v.offset_top = -inset - segment_length
	bottom_right_v.offset_right = -inset
	bottom_right_v.offset_bottom = -inset
	bottom_right_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_right_v.color = trim_color
	target.add_child(bottom_right_v)


static func _fate_make_vertical_gradient_texture(top: Color, middle: Color, bottom: Color, width: int = 8, height: int = 256) -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.add_point(0.0, top)
	gradient.add_point(0.42, middle)
	gradient.add_point(1.0, bottom)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.width = width
	texture.height = height
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.gradient = gradient
	return texture


static func _fate_make_particle_texture() -> Texture2D:
	var size: int = 28
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center: Vector2 = Vector2((float(size) - 1.0) * 0.5, (float(size) - 1.0) * 0.5)
	var max_radius: float = float(size) * 0.5
	for y in range(size):
		for x in range(size):
			var pixel_pos: Vector2 = Vector2(float(x), float(y))
			var dist: float = pixel_pos.distance_to(center) / max_radius
			if dist >= 1.0:
				continue
			var alpha: float = pow(1.0 - dist, 2.8)
			if absf(pixel_pos.x - center.x) <= 1.2 or absf(pixel_pos.y - center.y) <= 1.2:
				alpha = max(alpha, pow(maxf(0.0, 1.0 - dist), 1.35) * 0.55)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(alpha, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


static func _fate_build_reveal_gpu_burst(card: Dictionary, at_pos: Vector2) -> GPUParticles2D:
	var rarity: String = str(card.get("rarity", "common")).strip_edges().to_lower()
	var rank: int = FateCardCatalog.get_rarity_rank(rarity)
	var rarity_color: Color = FateCardCatalog.get_rarity_color(rarity)
	var particles := GPUParticles2D.new()
	particles.position = at_pos
	particles.one_shot = true
	particles.emitting = false
	particles.local_coords = false
	particles.process_mode = Node.PROCESS_MODE_ALWAYS
	particles.amount = 40 + (rank * 16)
	particles.lifetime = 1.05 + (0.08 * float(rank))
	particles.explosiveness = 1.0
	particles.randomness = 0.28
	particles.visibility_rect = Rect2(-560.0, -560.0, 1120.0, 1120.0)
	particles.texture = _fate_make_particle_texture()
	particles.z_index = 2
	var canvas_mat := CanvasItemMaterial.new()
	canvas_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = canvas_mat

	var process_mat := ParticleProcessMaterial.new()
	process_mat.set("emission_shape", ParticleProcessMaterial.EMISSION_SHAPE_SPHERE)
	process_mat.set("emission_sphere_radius", 18.0 + (float(rank) * 5.0))
	process_mat.set("direction", Vector3(0.0, -1.0, 0.0))
	process_mat.set("spread", 180.0)
	process_mat.set("gravity", Vector3(0.0, 165.0, 0.0))
	process_mat.set("initial_velocity_min", 240.0 + (float(rank) * 34.0))
	process_mat.set("initial_velocity_max", 430.0 + (float(rank) * 68.0))
	process_mat.set("radial_accel_min", -32.0)
	process_mat.set("radial_accel_max", 64.0 + (float(rank) * 10.0))
	process_mat.set("damping_min", 10.0)
	process_mat.set("damping_max", 24.0)
	process_mat.set("scale_min", 0.65)
	process_mat.set("scale_max", 1.5 + (float(rank) * 0.18))
	process_mat.set("hue_variation_min", -0.03)
	process_mat.set("hue_variation_max", 0.03)
	process_mat.set("color", Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.96))
	particles.process_material = process_mat
	return particles


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


static func _loot_loot_window_rarity_punch(field, intensity: float = 1.0) -> void:
	if field.loot_window == null or not field.is_inside_tree():
		return
	var pulse_scale: float = lerpf(1.072, 1.11, clampf(intensity - 1.0, 0.0, 0.6) / 0.6)
	var settle_time: float = lerpf(0.22, 0.32, clampf(intensity - 1.0, 0.0, 0.6) / 0.6)
	var tw: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(field.loot_window, "scale", Vector2(pulse_scale, pulse_scale), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(field.loot_window, "scale", Vector2.ONE, settle_time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


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

