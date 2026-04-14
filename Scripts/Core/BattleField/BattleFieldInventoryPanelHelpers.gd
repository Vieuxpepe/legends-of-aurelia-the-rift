class_name BattleFieldInventoryPanelHelpers
extends RefCounted

const InventoryTradeFlowHelpers = preload("res://Scripts/Core/BattleField/BattleFieldInventoryTradeFlowHelpers.gd")
const PromotionFlowSharedHelpers = preload("res://Scripts/Core/PromotionFlowSharedHelpers.gd")
const FateCardLootData = preload("res://Resources/FateCardLootData.gd")
const FateCardLootHelpers = preload("res://Scripts/Core/FateCardLootHelpers.gd")
const RecipeDatabaseScript = preload("res://Scripts/RecipeDatabase.gd")
const WeaponRuneDisplayHelpers = preload("res://Scripts/UI/WeaponRuneDisplayHelpers.gd")

const META_LAYOUT_V2 := "_battle_inventory_layout_v2"
const META_RUNTIME_NODES := "_battle_inventory_runtime_nodes"
const META_FILTER_BUTTONS := "_battle_inventory_filter_buttons"
const META_MODAL_CONNECTED := "_battle_inventory_modal_connected"
const DRAG_KIND := "battle_inventory_item"

const DEFAULT_FILTER := "all"
const PANEL_MARGIN := 18.0
const PANEL_GAP := 16.0
const HEADER_HEIGHT := 56.0
const ACTION_ROW_HEIGHT := 46.0
const LEFT_PANEL_IDEAL_WIDTH := 392.0
const LEFT_PANEL_MIN_WIDTH := 376.0
const UNIT_CARD_HEIGHT := 250.0
const UNIT_PORTRAIT_SIZE := Vector2(88.0, 104.0)
const SLOT_SIZE := Vector2(56.0, 56.0)
const MODAL_DIMMER_NAME := "InventoryModalDimmer"
const PANEL_OPEN_SCALE := Vector2(0.965, 0.965)
const PANEL_OPEN_TIME := 0.16
const PANEL_CLOSE_TIME := 0.12
const DRAG_CURSOR_MAX_SIZE := 52
const DETAIL_HEADER_HEIGHT := 170.0
const DETAIL_CHIP_ROW_HEIGHT := 66.0
const DETAIL_CONFIRM_HEIGHT := 28.0
const DETAIL_CONFIRM_SHOW_TIME := 0.72
const HIGH_RARITY_SELECTED_RANK := 2

const CONVOY_FILTERS: Array[Dictionary] = [
	{"id": "all", "label": "All"},
	{"id": "weapons", "label": "Weapons"},
	{"id": "consumables", "label": "Consumables"},
	{"id": "materials", "label": "Materials"},
]


class InventorySlotButton:
	extends Button

	var owner_field
	var inv_meta: Dictionary = {}
	var drag_enabled: bool = false

	func _get_drag_data(_position: Vector2) -> Variant:
		if owner_field == null or not drag_enabled or inv_meta.is_empty():
			return null
		if not BattleFieldInventoryPanelHelpers.can_accept_drag_data(owner_field, inv_meta):
			return null

		var drag_item = inv_meta.get("item", null)
		var drag_count: int = int(inv_meta.get("count", 1))
		var preview := Panel.new()
		preview.custom_minimum_size = Vector2(72, 72)
		preview.size = Vector2(72, 72)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.modulate = Color(1.0, 1.0, 1.0, 0.96)
		owner_field._style_tactical_panel(
			preview,
			owner_field.TACTICAL_UI_BG_ALT.lerp(owner_field.TACTICAL_UI_BG_SOFT, 0.18),
			owner_field.TACTICAL_UI_ACCENT,
			3,
			10
		)
		preview.pivot_offset = preview.size * 0.5

		var icon_rect := TextureRect.new()
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.position = Vector2(8, 8)
		icon_rect.size = Vector2(56, 56)
		icon_rect.texture = icon
		preview.add_child(icon_rect)

		if icon_rect.texture == null and drag_item != null:
			var fallback := Label.new()
			fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fallback.position = Vector2(8, 8)
			fallback.size = Vector2(56, 56)
			fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			fallback.text = BattleFieldInventoryPanelHelpers._item_short_name(drag_item)
			owner_field._style_tactical_label(fallback, owner_field.TACTICAL_UI_TEXT, 18, 3)
			preview.add_child(fallback)

		if drag_item != null and drag_item.get("current_durability") != null:
			var durability_label := Label.new()
			durability_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			durability_label.position = Vector2(6, 50)
			durability_label.size = Vector2(24, 14)
			durability_label.text = str(int(drag_item.current_durability))
			owner_field._style_tactical_label(durability_label, Color(0.96, 0.92, 0.78), 12, 3)
			preview.add_child(durability_label)
		elif drag_item != null and drag_item.get("uses") != null:
			var uses_label := Label.new()
			uses_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			uses_label.position = Vector2(6, 50)
			uses_label.size = Vector2(24, 14)
			uses_label.text = str(int(drag_item.uses))
			owner_field._style_tactical_label(uses_label, Color(0.96, 0.92, 0.78), 12, 3)
			preview.add_child(uses_label)

		if drag_count > 1:
			var count_label := Label.new()
			count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			count_label.position = Vector2(38, 50)
			count_label.size = Vector2(28, 14)
			count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			count_label.text = "x%d" % drag_count
			owner_field._style_tactical_label(count_label, Color.WHITE, 12, 3)
			preview.add_child(count_label)

		set_drag_preview(preview)
		set_meta("_dragging_inventory_source", true)
		modulate = (get_meta("hover_base_modulate", Color.WHITE) as Color) * Color(1.0, 1.0, 1.0, 0.42)
		BattleFieldInventoryPanelHelpers.begin_inventory_drag(owner_field, drag_item)
		return {
			"kind": BattleFieldInventoryPanelHelpers.DRAG_KIND,
			"meta": inv_meta.duplicate(true),
		}

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END and has_meta("_dragging_inventory_source"):
			remove_meta("_dragging_inventory_source")
			BattleFieldInventoryPanelHelpers.end_inventory_drag(owner_field)
			if BattleFieldInventoryPanelHelpers._is_slot_currently_selected(owner_field, inv_meta):
				BattleFieldInventoryPanelHelpers._animate_slot_selection(owner_field, self, true)
			else:
				modulate = get_meta("hover_base_modulate", Color.WHITE) as Color

	func _can_drop_data(_position: Vector2, data: Variant) -> bool:
		if owner_field == null:
			return false
		if str(inv_meta.get("source", "")) != "convoy":
			return false
		return BattleFieldInventoryPanelHelpers.can_accept_convoy_drop(owner_field, data)

	func _drop_data(_position: Vector2, data: Variant) -> void:
		if owner_field == null:
			return
		if str(inv_meta.get("source", "")) != "convoy":
			return
		BattleFieldInventoryPanelHelpers.handle_convoy_drop(owner_field, data)


class InventoryConvoyDropZone:
	extends Panel

	var owner_field
	var drag_feedback_active: bool = false

	func _notification(what: int) -> void:
		if owner_field == null:
			return
		if what == NOTIFICATION_DRAG_BEGIN:
			var drag_data: Variant = get_viewport().gui_get_drag_data()
			_set_drag_feedback(BattleFieldInventoryPanelHelpers.can_accept_convoy_drop(owner_field, drag_data))
		elif what == NOTIFICATION_DRAG_END:
			_set_drag_feedback(false)

	func _can_drop_data(_position: Vector2, data: Variant) -> bool:
		if owner_field == null:
			return false
		var can_drop: bool = BattleFieldInventoryPanelHelpers.can_accept_convoy_drop(owner_field, data)
		_set_drag_feedback(can_drop)
		return can_drop

	func _drop_data(_position: Vector2, data: Variant) -> void:
		if owner_field == null:
			return
		_set_drag_feedback(false)
		BattleFieldInventoryPanelHelpers.handle_convoy_drop(owner_field, data)

	func _set_drag_feedback(active: bool) -> void:
		if drag_feedback_active == active:
			return
		drag_feedback_active = active
		BattleFieldInventoryPanelHelpers.style_convoy_drop_zone(owner_field, self, active)


static func ensure_inventory_layout(field) -> void:
	if field.inventory_panel == null:
		return

	var modal_dimmer := _ensure_modal_dimmer(field)

	field._resolve_inventory_ui_nodes()
	if field.inv_scroll == null or field.unit_grid == null or field.convoy_grid == null or field.inv_desc_label == null:
		return

	if field.battle_inventory_filter == "":
		var stored_filter: String = str(field.inventory_panel.get_meta("_battle_inventory_last_filter", DEFAULT_FILTER))
		field.battle_inventory_filter = stored_filter if stored_filter != "" else DEFAULT_FILTER
	field.inventory_panel.set_meta("_battle_inventory_last_filter", field.battle_inventory_filter)

	if not field.inventory_panel.get_meta(META_MODAL_CONNECTED, false):
		field.inventory_panel.visibility_changed.connect(func() -> void:
			sync_modal_dimmer(field)
		)
		field.inventory_panel.set_meta(META_MODAL_CONNECTED, true)

	if field.inventory_panel.get_meta(META_LAYOUT_V2, false):
		var existing_nodes: Dictionary = _runtime_nodes(field)
		var required_runtime_keys: PackedStringArray = [
			"unit_portrait_frame",
			"unit_class_chip",
			"unit_equipped_chip",
			"detail_title",
			"detail_meta",
			"detail_rule",
			"detail_durability_label",
			"detail_durability_bar",
			"detail_chip_row",
			"detail_body_panel",
			"detail_confirm_panel",
		]
		var missing_runtime_nodes: bool = existing_nodes.is_empty()
		if not missing_runtime_nodes:
			for key in required_runtime_keys:
				if existing_nodes.get(key, null) == null:
					missing_runtime_nodes = true
					break
		if missing_runtime_nodes:
			field.inventory_panel.set_meta(META_LAYOUT_V2, false)
			field.inventory_panel.remove_meta(META_RUNTIME_NODES)
		else:
			existing_nodes["modal_dimmer"] = modal_dimmer
			field.inventory_panel.set_meta(META_RUNTIME_NODES, existing_nodes)
			_style_runtime_nodes(field)
			sync_modal_dimmer(field)
			return

	var title_label := Label.new()
	title_label.name = "InventoryTitleLabel"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.inventory_panel.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.name = "InventorySubtitleLabel"
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.inventory_panel.add_child(subtitle_label)

	var unit_card := Panel.new()
	unit_card.name = "InventoryUnitCard"
	field.inventory_panel.add_child(unit_card)

	var unit_title := Label.new()
	unit_title.name = "InventoryUnitNameLabel"
	unit_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unit_card.add_child(unit_title)

	var unit_portrait_frame := Panel.new()
	unit_portrait_frame.name = "InventoryUnitPortraitFrame"
	unit_card.add_child(unit_portrait_frame)

	var unit_portrait_accent := ColorRect.new()
	unit_portrait_accent.name = "InventoryUnitPortraitAccent"
	unit_portrait_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unit_portrait_frame.add_child(unit_portrait_accent)

	var unit_portrait := TextureRect.new()
	unit_portrait.name = "InventoryUnitPortrait"
	unit_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	unit_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	unit_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unit_portrait_frame.add_child(unit_portrait)

	var unit_class_chip := Panel.new()
	unit_class_chip.name = "InventoryUnitClassChip"
	unit_card.add_child(unit_class_chip)

	var unit_class_label := Label.new()
	unit_class_label.name = "InventoryUnitClassChipLabel"
	unit_class_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unit_class_chip.add_child(unit_class_label)

	var unit_meta := Label.new()
	unit_meta.name = "InventoryUnitMetaLabel"
	unit_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unit_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unit_card.add_child(unit_meta)

	var unit_equipped_chip := Panel.new()
	unit_equipped_chip.name = "InventoryUnitEquippedChip"
	unit_card.add_child(unit_equipped_chip)

	var unit_equipped_label := Label.new()
	unit_equipped_label.name = "InventoryUnitEquippedChipLabel"
	unit_equipped_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unit_equipped_chip.add_child(unit_equipped_label)

	var unit_hint := Label.new()
	unit_hint.name = "InventoryUnitHintLabel"
	unit_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unit_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unit_card.add_child(unit_hint)

	var unit_grid_wrap := Control.new()
	unit_grid_wrap.name = "InventoryUnitGridWrap"
	unit_card.add_child(unit_grid_wrap)

	if field.unit_grid.get_parent() != unit_grid_wrap:
		if field.unit_grid.get_parent() != null:
			field.unit_grid.get_parent().remove_child(field.unit_grid)
		unit_grid_wrap.add_child(field.unit_grid)

	var detail_card := field.inventory_panel.get_node_or_null("Panel") as Panel
	if detail_card == null:
		detail_card = Panel.new()
		detail_card.name = "Panel"
		field.inventory_panel.add_child(detail_card)
	var detail_fill_rect := detail_card.get_node_or_null("DetailFillRect") as ColorRect
	if detail_fill_rect == null:
		detail_fill_rect = ColorRect.new()
		detail_fill_rect.name = "DetailFillRect"
		detail_fill_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail_card.add_child(detail_fill_rect)
		detail_card.move_child(detail_fill_rect, 0)

	var detail_title := detail_card.get_node_or_null("InventoryDetailTitleLabel") as Label
	if detail_title == null:
		detail_title = Label.new()
		detail_title.name = "InventoryDetailTitleLabel"
		detail_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail_card.add_child(detail_title)

	var detail_meta := detail_card.get_node_or_null("InventoryDetailMetaLabel") as Label
	if detail_meta == null:
		detail_meta = Label.new()
		detail_meta.name = "InventoryDetailMetaLabel"
		detail_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail_card.add_child(detail_meta)

	var detail_rule := detail_card.get_node_or_null("InventoryDetailRule") as ColorRect
	if detail_rule == null:
		detail_rule = ColorRect.new()
		detail_rule.name = "InventoryDetailRule"
		detail_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail_card.add_child(detail_rule)

	var detail_durability_label := detail_card.get_node_or_null("InventoryDetailDurabilityLabel") as Label
	if detail_durability_label == null:
		detail_durability_label = Label.new()
		detail_durability_label.name = "InventoryDetailDurabilityLabel"
		detail_durability_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail_card.add_child(detail_durability_label)

	var detail_durability_bar := detail_card.get_node_or_null("InventoryDetailDurabilityBar") as ProgressBar
	if detail_durability_bar == null:
		detail_durability_bar = ProgressBar.new()
		detail_durability_bar.name = "InventoryDetailDurabilityBar"
		detail_durability_bar.show_percentage = false
		detail_durability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail_card.add_child(detail_durability_bar)

	var detail_chip_row := detail_card.get_node_or_null("InventoryDetailChipRow") as HFlowContainer
	if detail_chip_row == null:
		detail_chip_row = HFlowContainer.new()
		detail_chip_row.name = "InventoryDetailChipRow"
		detail_card.add_child(detail_chip_row)

	var detail_body_panel := detail_card.get_node_or_null("InventoryDetailBodyPanel") as Panel
	if detail_body_panel == null:
		detail_body_panel = Panel.new()
		detail_body_panel.name = "InventoryDetailBodyPanel"
		detail_card.add_child(detail_body_panel)

	var detail_confirm_panel := detail_card.get_node_or_null("InventoryDetailConfirmPanel") as Panel
	if detail_confirm_panel == null:
		detail_confirm_panel = Panel.new()
		detail_confirm_panel.name = "InventoryDetailConfirmPanel"
		detail_confirm_panel.visible = false
		detail_card.add_child(detail_confirm_panel)

	var detail_confirm_label := detail_confirm_panel.get_node_or_null("InventoryDetailConfirmLabel") as Label
	if detail_confirm_label == null:
		detail_confirm_label = Label.new()
		detail_confirm_label.name = "InventoryDetailConfirmLabel"
		detail_confirm_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail_confirm_panel.add_child(detail_confirm_label)
	if field.inv_desc_label.get_parent() != detail_body_panel:
		if field.inv_desc_label.get_parent() != null:
			field.inv_desc_label.get_parent().remove_child(field.inv_desc_label)
		detail_body_panel.add_child(field.inv_desc_label)

	var convoy_card := InventoryConvoyDropZone.new()
	convoy_card.name = "InventoryConvoyCard"
	convoy_card.owner_field = field
	field.inventory_panel.add_child(convoy_card)

	var convoy_title := Label.new()
	convoy_title.name = "InventoryConvoyTitleLabel"
	convoy_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	convoy_card.add_child(convoy_title)

	var convoy_meta := Label.new()
	convoy_meta.name = "InventoryConvoyMetaLabel"
	convoy_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	convoy_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	convoy_card.add_child(convoy_meta)

	var filter_row := HBoxContainer.new()
	filter_row.name = "InventoryFilterRow"
	filter_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	convoy_card.add_child(filter_row)

	var filter_buttons: Array[Button] = []
	for filter_data in CONVOY_FILTERS:
		var filter_button := Button.new()
		filter_button.name = "Filter_%s" % str(filter_data.id)
		filter_button.text = str(filter_data.label).to_upper()
		filter_button.focus_mode = Control.FOCUS_NONE
		filter_button.pressed.connect(func(filter_id: String = str(filter_data.id)) -> void:
			set_convoy_filter(field, filter_id)
		)
		filter_row.add_child(filter_button)
		filter_buttons.append(filter_button)

	var empty_label := Label.new()
	empty_label.name = "InventoryConvoyEmptyLabel"
	empty_label.text = "Nothing matches this convoy filter."
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	convoy_card.add_child(empty_label)

	var drop_hint := Label.new()
	drop_hint.name = "InventoryConvoyDropHintLabel"
	drop_hint.visible = false
	drop_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drop_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	drop_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop_hint.text = "DROP ITEM HERE TO STORE IT"
	convoy_card.add_child(drop_hint)

	var toast_label := Label.new()
	toast_label.name = "InventoryConvoyToastLabel"
	toast_label.visible = false
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	convoy_card.add_child(toast_label)

	if field.inv_scroll.get_parent() != convoy_card:
		if field.inv_scroll.get_parent() != null:
			field.inv_scroll.get_parent().remove_child(field.inv_scroll)
		convoy_card.add_child(field.inv_scroll)

	var runtime_nodes := {
		"title": title_label,
		"subtitle": subtitle_label,
		"modal_dimmer": modal_dimmer,
		"unit_card": unit_card,
		"unit_portrait_frame": unit_portrait_frame,
		"unit_portrait_accent": unit_portrait_accent,
		"unit_portrait": unit_portrait,
		"unit_title": unit_title,
		"unit_class_chip": unit_class_chip,
		"unit_class_label": unit_class_label,
		"unit_meta": unit_meta,
		"unit_equipped_chip": unit_equipped_chip,
		"unit_equipped_label": unit_equipped_label,
		"unit_hint": unit_hint,
		"unit_grid_wrap": unit_grid_wrap,
		"detail_card": detail_card,
		"detail_fill": detail_fill_rect,
		"detail_title": detail_title,
		"detail_meta": detail_meta,
		"detail_rule": detail_rule,
		"detail_durability_label": detail_durability_label,
		"detail_durability_bar": detail_durability_bar,
		"detail_chip_row": detail_chip_row,
		"detail_body_panel": detail_body_panel,
		"detail_confirm_panel": detail_confirm_panel,
		"detail_confirm_label": detail_confirm_label,
		"convoy_card": convoy_card,
		"convoy_title": convoy_title,
		"convoy_meta": convoy_meta,
		"filter_row": filter_row,
		"convoy_empty": empty_label,
		"convoy_drop_hint": drop_hint,
		"convoy_toast": toast_label,
	}
	field.inventory_panel.set_meta(META_LAYOUT_V2, true)
	field.inventory_panel.set_meta(META_RUNTIME_NODES, runtime_nodes)
	field.inventory_panel.set_meta(META_FILTER_BUTTONS, filter_buttons)

	_style_runtime_nodes(field)
	layout_inventory_panel(field)


static func layout_inventory_panel(field) -> void:
	if field.inventory_panel == null:
		return
	ensure_inventory_layout(field)
	if not field.inventory_panel.get_meta(META_LAYOUT_V2, false):
		return

	var nodes: Dictionary = _runtime_nodes(field)
	if nodes.is_empty():
		return
	if field.inv_desc_label == null or field.inv_scroll == null or field.unit_grid == null or field.convoy_grid == null:
		return
	_style_runtime_nodes(field)

	var vp_size: Vector2 = field.get_viewport_rect().size
	var panel_size := Vector2(
		clampf(vp_size.x - 80.0, 980.0, 1120.0),
		clampf(vp_size.y - 72.0, 680.0, 820.0)
	)
	var ui_parent: Node = field.inventory_panel.get_parent()
	var modal_dimmer := nodes.get("modal_dimmer") as ColorRect
	if ui_parent != null and modal_dimmer != null:
		ui_parent.move_child(modal_dimmer, max(0, ui_parent.get_child_count() - 1))
		ui_parent.move_child(field.inventory_panel, ui_parent.get_child_count() - 1)
		ui_parent.move_child(modal_dimmer, max(0, field.inventory_panel.get_index() - 1))
	if modal_dimmer != null:
		modal_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
		modal_dimmer.offset_left = 0
		modal_dimmer.offset_top = 0
		modal_dimmer.offset_right = 0
		modal_dimmer.offset_bottom = 0
		modal_dimmer.position = Vector2.ZERO
		modal_dimmer.size = vp_size
		modal_dimmer.z_index = 39
	field.inventory_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	field.inventory_panel.scale = Vector2.ONE
	field.inventory_panel.position = (vp_size - panel_size) * 0.5
	field.inventory_panel.size = panel_size
	field.inventory_panel.z_index = 40
	field.inventory_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var inner_w: float = panel_size.x - (PANEL_MARGIN * 2.0)
	var content_y: float = PANEL_MARGIN + HEADER_HEIGHT
	var content_h: float = panel_size.y - content_y - PANEL_MARGIN - ACTION_ROW_HEIGHT - PANEL_GAP
	var min_slot_row_w: float = (SLOT_SIZE.x * 5.0) + (float(field.INVENTORY_UI_GRID_SEP) * 4.0) + 36.0
	var left_w: float = maxf(LEFT_PANEL_MIN_WIDTH, min_slot_row_w)
	left_w = minf(maxf(left_w, LEFT_PANEL_IDEAL_WIDTH), inner_w * 0.40)
	var right_w: float = inner_w - left_w - PANEL_GAP
	var unit_card_h: float = minf(UNIT_CARD_HEIGHT, content_h)
	var convoy_h: float = maxf(180.0, content_h - unit_card_h - PANEL_GAP)

	var title_label := nodes.get("title") as Label
	var subtitle_label := nodes.get("subtitle") as Label
	var unit_card := nodes.get("unit_card") as Panel
	var unit_portrait_frame := nodes.get("unit_portrait_frame") as Panel
	var unit_portrait_accent := nodes.get("unit_portrait_accent") as ColorRect
	var unit_portrait := nodes.get("unit_portrait") as TextureRect
	var unit_title := nodes.get("unit_title") as Label
	var unit_class_chip := nodes.get("unit_class_chip") as Panel
	var unit_class_label := nodes.get("unit_class_label") as Label
	var unit_meta := nodes.get("unit_meta") as Label
	var unit_equipped_chip := nodes.get("unit_equipped_chip") as Panel
	var unit_equipped_label := nodes.get("unit_equipped_label") as Label
	var unit_hint := nodes.get("unit_hint") as Label
	var unit_grid_wrap := nodes.get("unit_grid_wrap") as Control
	var detail_card := nodes.get("detail_card") as Panel
	var detail_fill := nodes.get("detail_fill") as ColorRect
	var detail_title := nodes.get("detail_title") as Label
	var detail_meta := nodes.get("detail_meta") as Label
	var detail_rule := nodes.get("detail_rule") as ColorRect
	var detail_durability_label := nodes.get("detail_durability_label") as Label
	var detail_durability_bar := nodes.get("detail_durability_bar") as ProgressBar
	var detail_chip_row := nodes.get("detail_chip_row") as HFlowContainer
	var detail_body_panel := nodes.get("detail_body_panel") as Panel
	var detail_confirm_panel := nodes.get("detail_confirm_panel") as Panel
	var detail_confirm_label := nodes.get("detail_confirm_label") as Label
	var convoy_card := nodes.get("convoy_card") as Panel
	var convoy_title := nodes.get("convoy_title") as Label
	var convoy_meta := nodes.get("convoy_meta") as Label
	var filter_row := nodes.get("filter_row") as HBoxContainer
	var empty_label := nodes.get("convoy_empty") as Label
	var drop_hint := nodes.get("convoy_drop_hint") as Label
	var convoy_toast := nodes.get("convoy_toast") as Label

	title_label.position = Vector2(PANEL_MARGIN, PANEL_MARGIN - 4.0)
	title_label.size = Vector2(inner_w, 28.0)
	subtitle_label.position = Vector2(PANEL_MARGIN, PANEL_MARGIN + 20.0)
	subtitle_label.size = Vector2(inner_w, 36.0)

	unit_card.position = Vector2(PANEL_MARGIN, content_y)
	unit_card.size = Vector2(left_w, unit_card_h)
	unit_card.clip_contents = true
	unit_portrait_frame.position = Vector2(18.0, 16.0)
	unit_portrait_frame.size = UNIT_PORTRAIT_SIZE
	if unit_portrait != null:
		unit_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
		unit_portrait.offset_left = 6
		unit_portrait.offset_top = 6
		unit_portrait.offset_right = -6
		unit_portrait.offset_bottom = -10
	if unit_portrait_accent != null:
		unit_portrait_accent.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		unit_portrait_accent.offset_left = 6
		unit_portrait_accent.offset_top = -12
		unit_portrait_accent.offset_right = -6
		unit_portrait_accent.offset_bottom = -6
	var header_info_x: float = 18.0 + UNIT_PORTRAIT_SIZE.x + 14.0
	var header_info_w: float = left_w - header_info_x - 18.0
	unit_title.position = Vector2(header_info_x, 18.0)
	unit_title.size = Vector2(header_info_w, 28.0)
	unit_class_chip.position = Vector2(header_info_x, 48.0)
	unit_class_chip.size = Vector2(minf(172.0, header_info_w), 26.0)
	unit_class_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	unit_class_label.offset_left = 6
	unit_class_label.offset_top = 2
	unit_class_label.offset_right = -6
	unit_class_label.offset_bottom = -2
	unit_meta.position = Vector2(header_info_x, 80.0)
	unit_meta.size = Vector2(header_info_w, 28.0)
	unit_equipped_chip.position = Vector2(header_info_x, 110.0)
	unit_equipped_chip.size = Vector2(header_info_w, 28.0)
	unit_equipped_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	unit_equipped_label.offset_left = 8
	unit_equipped_label.offset_top = 2
	unit_equipped_label.offset_right = -8
	unit_equipped_label.offset_bottom = -2
	unit_hint.position = Vector2(18.0, 146.0)
	unit_hint.size = Vector2(left_w - 36.0, 26.0)
	unit_grid_wrap.position = Vector2(18.0, 176.0)
	unit_grid_wrap.size = Vector2(left_w - 36.0, SLOT_SIZE.y + 14.0)
	unit_grid_wrap.clip_contents = true

	var unit_grid_w: float = (SLOT_SIZE.x * 5.0) + (float(field.INVENTORY_UI_GRID_SEP) * 4.0)
	field.unit_grid.position = Vector2(maxf(0.0, (unit_grid_wrap.size.x - unit_grid_w) * 0.5), 6.0)

	detail_card.position = Vector2(PANEL_MARGIN + left_w + PANEL_GAP, content_y)
	detail_card.size = Vector2(right_w, content_h)
	if detail_fill != null:
		detail_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		detail_fill.offset_left = 3
		detail_fill.offset_top = 3
		detail_fill.offset_right = -3
		detail_fill.offset_bottom = -3
	if detail_title != null:
		detail_title.position = Vector2(16.0, 14.0)
		detail_title.size = Vector2(right_w - 32.0, 28.0)
	if detail_meta != null:
		detail_meta.position = Vector2(16.0, 42.0)
		detail_meta.size = Vector2(right_w - 32.0, 20.0)
	if detail_rule != null:
		detail_rule.position = Vector2(16.0, 60.0)
		detail_rule.size = Vector2(right_w - 32.0, 2.0)
	if detail_durability_label != null:
		detail_durability_label.position = Vector2(16.0, 70.0)
		detail_durability_label.size = Vector2(right_w - 32.0, 16.0)
	if detail_durability_bar != null:
		detail_durability_bar.position = Vector2(16.0, 88.0)
		detail_durability_bar.size = Vector2(right_w - 32.0, 18.0)
	if detail_chip_row != null:
		detail_chip_row.position = Vector2(16.0, 116.0)
		detail_chip_row.size = Vector2(right_w - 32.0, DETAIL_CHIP_ROW_HEIGHT)
	if detail_body_panel != null:
		detail_body_panel.position = Vector2(16.0, DETAIL_HEADER_HEIGHT)
		detail_body_panel.size = Vector2(right_w - 32.0, clampf(content_h - DETAIL_HEADER_HEIGHT - DETAIL_CONFIRM_HEIGHT - 26.0, 180.0, 260.0))
	if detail_confirm_panel != null:
		detail_confirm_panel.position = Vector2(16.0, DETAIL_HEADER_HEIGHT + (detail_body_panel.size.y if detail_body_panel != null else 220.0) + 10.0)
		detail_confirm_panel.size = Vector2(minf(236.0, right_w - 32.0), DETAIL_CONFIRM_HEIGHT)
		if detail_confirm_label != null:
			detail_confirm_label.set_anchors_preset(Control.PRESET_FULL_RECT)
			detail_confirm_label.offset_left = 8
			detail_confirm_label.offset_top = 2
			detail_confirm_label.offset_right = -8
			detail_confirm_label.offset_bottom = -2
	field.inv_desc_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.inv_desc_label.offset_left = 14
	field.inv_desc_label.offset_top = 12
	field.inv_desc_label.offset_right = -14
	field.inv_desc_label.offset_bottom = -12

	convoy_card.position = Vector2(PANEL_MARGIN, content_y + unit_card_h + PANEL_GAP)
	convoy_card.size = Vector2(left_w, convoy_h)
	convoy_card.clip_contents = true
	convoy_title.position = Vector2(16.0, 12.0)
	convoy_title.size = Vector2(left_w - 32.0, 24.0)
	convoy_meta.position = Vector2(16.0, 34.0)
	convoy_meta.size = Vector2(left_w - 32.0, 28.0)
	filter_row.position = Vector2(16.0, 66.0)
	filter_row.size = Vector2(left_w - 32.0, 32.0)
	filter_row.add_theme_constant_override("separation", 6)
	field.inv_scroll.position = Vector2(12.0, 106.0)
	field.inv_scroll.size = Vector2(left_w - 24.0, convoy_card.size.y - 118.0)
	empty_label.position = Vector2(24.0, 142.0)
	empty_label.size = Vector2(left_w - 48.0, maxf(44.0, convoy_card.size.y - 166.0))
	if drop_hint != null:
		drop_hint.position = Vector2(20.0, 136.0)
		drop_hint.size = Vector2(left_w - 40.0, 28.0)
	if convoy_toast != null:
		convoy_toast.position = Vector2(16.0, 12.0)
		convoy_toast.size = Vector2(left_w - 32.0, 22.0)

	var action_y: float = panel_size.y - PANEL_MARGIN - ACTION_ROW_HEIGHT
	field.equip_button.position = Vector2(PANEL_MARGIN, action_y)
	field.equip_button.size = Vector2(148.0, ACTION_ROW_HEIGHT)
	field.use_button.position = Vector2(PANEL_MARGIN + 160.0, action_y)
	field.use_button.size = Vector2(148.0, ACTION_ROW_HEIGHT)
	var close_button := field.inventory_panel.get_node_or_null("CloseButton") as Button
	if close_button != null:
		close_button.position = Vector2(panel_size.x - PANEL_MARGIN - 148.0, action_y)
		close_button.size = Vector2(148.0, ACTION_ROW_HEIGHT)

	var panel_child_count: int = field.inventory_panel.get_child_count()
	field.inventory_panel.move_child(field.equip_button, panel_child_count - 1)
	field.inventory_panel.move_child(field.use_button, field.inventory_panel.get_child_count() - 1)
	if close_button != null:
		field.inventory_panel.move_child(close_button, field.inventory_panel.get_child_count() - 1)

	refresh_filter_buttons(field)
	sync_modal_dimmer(field)


static func refresh_inventory_entry_state(field) -> void:
	if field.convoy_button == null:
		return
	var has_active_unit: bool = (
		field.current_state == field.player_state
		and field.player_state != null
		and field.player_state.active_unit != null
		and not field.player_state.is_forecasting
	)
	field.convoy_button.disabled = not has_active_unit


static func on_open_inv_pressed(field) -> void:
	_open_inventory_panel(field, "inventory")


static func on_convoy_pressed(field) -> void:
	_open_inventory_panel(field, "convoy")


static func on_close_inv_pressed(field) -> void:
	if field.inventory_panel == null:
		return
	_play_inventory_close_animation(field)


static func populate_unit_inventory_list(field) -> void:
	refresh_inventory_panel(field)


static func populate_convoy_list(field) -> void:
	refresh_inventory_panel(field)


static func clear_grids(field) -> void:
	if field.unit_grid != null:
		for child in field.unit_grid.get_children():
			child.queue_free()
	if field.convoy_grid != null:
		for child in field.convoy_grid.get_children():
			child.queue_free()
	field.selected_inventory_meta.clear()
	refresh_action_buttons(field)


static func build_grid_items(
	field,
	grid: GridContainer,
	item_array: Array,
	source_type: String,
	owner_unit: Node2D = null,
	min_slots: int = 0
) -> void:
	if grid == null:
		return

	var display_items: Array[Dictionary] = []
	for index in range(item_array.size()):
		var item: Resource = item_array[index]
		if item == null:
			continue

		var can_stack: bool = (item is ConsumableData) or (item is ChestKeyData) or (item is MaterialData)
		var found_stack: bool = false
		if can_stack and source_type == "convoy":
			var item_name := _item_name(item)
			for entry in display_items:
				if _item_name(entry.item) == item_name:
					entry.count += 1
					entry.indices.append(index)
					found_stack = true
					break
		if not found_stack:
			display_items.append({
				"item": item,
				"count": 1,
				"indices": [index],
			})

	var total_slots: int = max(display_items.size(), min_slots)
	for slot_index in range(total_slots):
		var btn := InventorySlotButton.new()
		btn.owner_field = field
		btn.custom_minimum_size = SLOT_SIZE
		btn.size = SLOT_SIZE
		btn.focus_mode = Control.FOCUS_NONE
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(btn)
		_apply_slot_theme(field, btn)

		if slot_index >= display_items.size():
			btn.disabled = true
			_apply_empty_slot_theme(field, btn)
			continue

		var display_entry: Dictionary = display_items[slot_index]
		var item: Resource = display_entry.item
		var count: int = int(display_entry.count)
		var real_index: int = int(display_entry.indices[0])
		var viewer_unit: Node2D = owner_unit if owner_unit != null else field.unit_managing_inventory
		var meta := {
			"source": source_type,
			"index": real_index,
			"item": item,
			"unit": viewer_unit,
			"count": count,
		}
		btn.inv_meta = meta
		btn.drag_enabled = (source_type == "unit_personal" and owner_unit == field.unit_managing_inventory)
		btn.set_meta("inv_data", meta)

		if item.get("icon") != null:
			btn.icon = item.icon
			btn.expand_icon = true
		else:
			btn.text = _item_short_name(item)
		_apply_rarity_slot_theme(field, btn, item)

		var base_modulate := Color.WHITE
		var is_usable_for_viewer: bool = true
		if viewer_unit != null and item is WeaponData:
			is_usable_for_viewer = field._unit_can_use_item_for_ui(viewer_unit, item)
			if not is_usable_for_viewer:
				base_modulate = Color(1.0, 0.60, 0.60, 0.96)
				_add_corner_badge(btn, "X", Control.PRESET_TOP_RIGHT, Color(1.0, 0.36, 0.36), 18)

		btn.modulate = base_modulate
		btn.set_meta("hover_base_modulate", base_modulate)
		btn.tooltip_text = _build_slot_tooltip(field, item, count, viewer_unit, owner_unit, source_type, is_usable_for_viewer)

		if owner_unit != null and item == owner_unit.get("equipped_weapon"):
			_apply_equipped_slot_theme(field, btn)
			InventoryTradeFlowHelpers.add_equipped_badge_to_inv_button(btn)

		if item is WeaponData and field._is_weapon_convoy_locked(item as WeaponData):
			_add_corner_badge(btn, "!", Control.PRESET_TOP_LEFT, Color(1.0, 0.82, 0.46), 16)

		if count > 1:
			_add_count_badge(btn, count)
		_add_durability_badge(item, btn)

		btn.pressed.connect(func() -> void:
			on_grid_item_clicked(field, btn, meta)
		)


static func on_grid_item_clicked(field, btn: Button, meta: Dictionary) -> void:
	_play_inventory_feedback_sfx(field, "select")

	field.selected_inventory_meta = meta
	_clear_selection_visuals(field)
	_animate_slot_selection(field, btn, true)

	var item: Resource = meta.get("item", null)
	var count: int = int(meta.get("count", 1))
	var viewer_unit: Node2D = meta.get("unit", null)
	_refresh_detail_header(field, item, count)
	_refresh_detail_durability_bar(field, item)
	if field.inv_desc_label != null and item != null:
		_set_inventory_detail_text(field, _build_inventory_detail_text(field, item, count, viewer_unit))
	_refresh_detail_chip_row(field, item, count, viewer_unit)
	clear_detail_confirmation(field)

	refresh_action_buttons(field)


static func refresh_inventory_panel(field) -> void:
	ensure_inventory_layout(field)
	if field.inventory_panel == null:
		return

	layout_inventory_panel(field)
	_rehome_convoy_locked_dragon_weapons(field)
	clear_grids(field)

	var managed_unit: Node2D = _validated_inventory_unit(field, field.unit_managing_inventory)
	field.unit_managing_inventory = managed_unit
	if managed_unit != null:
		var personal_inventory: Array = managed_unit.inventory if "inventory" in managed_unit else []
		build_grid_items(field, field.unit_grid, personal_inventory, "unit_personal", managed_unit, 5)
		field._battle_try_flash_pending_inv_slot(field.unit_grid)
	else:
		build_grid_items(field, field.unit_grid, [], "unit_personal", null, 5)

	var filtered_convoy: Array = _filtered_convoy_items(field)
	build_grid_items(field, field.convoy_grid, filtered_convoy, "convoy", managed_unit)

	_reset_description(field)
	_refresh_header_labels(field)
	_refresh_convoy_empty_state(field)
	refresh_action_buttons(field)
	refresh_filter_buttons(field)


static func refresh_action_buttons(field) -> void:
	var can_equip: bool = false
	var can_use: bool = false
	if not field.selected_inventory_meta.is_empty():
		var meta: Dictionary = field.selected_inventory_meta
		var source: String = str(meta.get("source", ""))
		var item: Resource = meta.get("item", null)
		var managed_unit: Node2D = field.unit_managing_inventory
		if source == "unit_personal" and item != null and managed_unit != null:
			can_equip = item is WeaponData and field._unit_can_equip_weapon(managed_unit, item)
			can_use = _can_use_personal_item(field, managed_unit, item)

	field.equip_button.visible = true
	field.use_button.visible = true
	field.equip_button.disabled = not can_equip
	field.use_button.disabled = not can_use
	_style_inventory_action_button(field, field.equip_button, "EQUIP", can_equip)
	_style_inventory_action_button(field, field.use_button, "USE", can_use)


static func set_convoy_filter(field, filter_id: String) -> void:
	field.battle_inventory_filter = filter_id
	if field.inventory_panel != null:
		field.inventory_panel.set_meta("_battle_inventory_last_filter", filter_id)
	refresh_inventory_panel(field)


static func refresh_filter_buttons(field) -> void:
	if field.inventory_panel == null:
		return
	var buttons_variant: Variant = field.inventory_panel.get_meta(META_FILTER_BUTTONS, [])
	if not (buttons_variant is Array):
		return
	for btn_variant in buttons_variant:
		var btn := btn_variant as Button
		if btn == null:
			continue
		field._style_tactical_button(btn, btn.text, false, 15)
		var active: bool = btn.name == "Filter_%s" % field.battle_inventory_filter
		if active:
			var active_fill: Color = field.TACTICAL_UI_PRIMARY_FILL.lerp(field.TACTICAL_UI_ACCENT, 0.18)
			var active_hover: Color = field.TACTICAL_UI_PRIMARY_HOVER.lerp(field.TACTICAL_UI_ACCENT, 0.12)
			btn.add_theme_stylebox_override("normal", field._make_tactical_panel_style(active_fill, field.TACTICAL_UI_ACCENT, 3, 10))
			btn.add_theme_stylebox_override("hover", field._make_tactical_panel_style(active_hover, field.TACTICAL_UI_ACCENT_SOFT, 3, 10))
			btn.add_theme_stylebox_override("pressed", field._make_tactical_panel_style(field.TACTICAL_UI_PRIMARY_PRESS, field.TACTICAL_UI_ACCENT, 3, 10))
			btn.add_theme_stylebox_override("focus", field._make_tactical_panel_style(active_hover, field.TACTICAL_UI_ACCENT_SOFT, 3, 10))


static func can_accept_drag_data(field, meta: Dictionary) -> bool:
	if field == null or meta.is_empty():
		return false
	if str(meta.get("source", "")) != "unit_personal":
		return false
	var managed_unit: Node2D = _validated_inventory_unit(field, meta.get("unit", null))
	if managed_unit == null or managed_unit != field.unit_managing_inventory:
		return false
	var item: Resource = meta.get("item", null)
	if item == null:
		return false
	if item is WeaponData and field._is_weapon_convoy_locked(item as WeaponData):
		field.play_ui_sfx(field.UISfx.INVALID)
		return false
	return true


static func can_accept_convoy_drop(field, data: Variant) -> bool:
	if field == null or not (data is Dictionary):
		return false
	var payload: Dictionary = data
	if str(payload.get("kind", "")) != DRAG_KIND:
		return false
	var meta: Dictionary = payload.get("meta", {})
	if not can_accept_drag_data(field, meta):
		return false
	var managed_unit: Node2D = _validated_inventory_unit(field, meta.get("unit", null))
	var item: Resource = meta.get("item", null)
	if managed_unit == null or item == null:
		return false
	var item_index: int = int(meta.get("index", -1))
	if item_index >= 0 and item_index < managed_unit.inventory.size():
		if managed_unit.inventory[item_index] == item:
			return true
	return managed_unit.inventory.has(item)


static func handle_convoy_drop(field, data: Variant) -> void:
	if not can_accept_convoy_drop(field, data):
		field.play_ui_sfx(field.UISfx.INVALID)
		return

	var payload: Dictionary = data
	var meta: Dictionary = payload.get("meta", {})
	var managed_unit: Node2D = _validated_inventory_unit(field, meta.get("unit", null))
	var item: Resource = meta.get("item", null)
	if managed_unit == null or item == null:
		field.play_ui_sfx(field.UISfx.INVALID)
		return

	var item_index: int = int(meta.get("index", -1))
	if item_index < 0 or item_index >= managed_unit.inventory.size() or managed_unit.inventory[item_index] != item:
		item_index = managed_unit.inventory.find(item)
	if item_index == -1:
		field.play_ui_sfx(field.UISfx.INVALID)
		return

	managed_unit.inventory.remove_at(item_index)
	field.player_inventory.append(item)
	InventoryTradeFlowHelpers.validate_equipment(field, managed_unit)
	if field.player_state != null and managed_unit == field.player_state.active_unit:
		field.calculate_ranges(managed_unit)
	field.update_unit_info_panel()
	_play_inventory_feedback_sfx(field, "store")
	refresh_inventory_panel(field)
	_play_convoy_store_feedback(field, item)


static func _open_inventory_panel(field, source: String) -> void:
	if field.current_state != field.player_state or field.player_state == null:
		return
	if field.player_state.is_forecasting:
		return
	if field.player_state.active_unit == null:
		field.play_ui_sfx(field.UISfx.INVALID)
		return

	field.battle_inventory_open_source = source
	field.unit_managing_inventory = field.player_state.active_unit
	field.player_state.is_forecasting = true
	ensure_inventory_layout(field)
	refresh_inventory_panel(field)
	refresh_inventory_entry_state(field)
	_play_inventory_feedback_sfx(field, "open")
	_play_inventory_open_animation(field)


static func _refresh_header_labels(field) -> void:
	var nodes: Dictionary = _runtime_nodes(field)
	if nodes.is_empty():
		return

	var title_label := nodes.get("title") as Label
	var subtitle_label := nodes.get("subtitle") as Label
	var unit_portrait_frame := nodes.get("unit_portrait_frame") as Panel
	var unit_portrait := nodes.get("unit_portrait") as TextureRect
	var unit_title := nodes.get("unit_title") as Label
	var unit_class_chip := nodes.get("unit_class_chip") as Panel
	var unit_class_label := nodes.get("unit_class_label") as Label
	var unit_meta := nodes.get("unit_meta") as Label
	var unit_equipped_chip := nodes.get("unit_equipped_chip") as Panel
	var unit_equipped_label := nodes.get("unit_equipped_label") as Label
	var unit_hint := nodes.get("unit_hint") as Label
	var convoy_title := nodes.get("convoy_title") as Label
	var convoy_meta := nodes.get("convoy_meta") as Label

	var managed_unit: Node2D = _validated_inventory_unit(field, field.unit_managing_inventory)
	var slots_used: int = managed_unit.inventory.size() if managed_unit != null and "inventory" in managed_unit else 0
	var convoy_count: int = field.player_inventory.size()

	if field.battle_inventory_open_source == "convoy":
		title_label.text = "CONVOY ACCESS"
		subtitle_label.text = "Drag items from the active unit's pack into storage. Withdrawals stay locked mid-battle."
	else:
		title_label.text = "BATTLE INVENTORY"
		subtitle_label.text = "Equip and use from the active unit's backpack, or store spare gear in convoy."

	if managed_unit != null:
		var unit_class_name: String = str(
			managed_unit.get("unit_class_name") if managed_unit.get("unit_class_name") != null else "Unknown"
		)
		var portrait_tex: Texture2D = _get_inventory_unit_portrait(managed_unit)
		var equipped_item: Resource = managed_unit.get("equipped_weapon")
		unit_title.text = str(managed_unit.unit_name).to_upper()
		unit_class_label.text = unit_class_name.to_upper()
		unit_meta.text = "Slots %d/5 | Active unit" % slots_used
		unit_hint.text = "Use the backpack here, then drag spare gear into convoy."
		if unit_class_chip != null:
			field._style_tactical_panel(
				unit_class_chip,
				field.TACTICAL_UI_PRIMARY_FILL.lerp(field.TACTICAL_UI_BG_SOFT, 0.22),
				field.TACTICAL_UI_ACCENT_SOFT,
				1,
				8
			)
		if unit_equipped_chip != null:
			field._style_tactical_panel(unit_equipped_chip, Color(0.16, 0.13, 0.09, 0.96), field.TACTICAL_UI_BORDER_MUTED, 1, 8)
		if unit_equipped_label != null:
			unit_equipped_label.text = (
				"READY: %s" % _item_drag_label(equipped_item)
				if equipped_item != null
				else "READY: NO WEAPON EQUIPPED"
			)
		if unit_portrait != null:
			unit_portrait.texture = portrait_tex
		if unit_portrait_frame != null:
			unit_portrait_frame.visible = true
	else:
		unit_title.text = "NO ACTIVE UNIT"
		unit_class_label.text = "BATTLEFIELD"
		unit_meta.text = "Select a player unit before opening battlefield inventory access."
		unit_hint.text = "Convoy review can stay open for loot, but mid-battle management belongs to the active unit."
		if unit_class_chip != null:
			field._style_tactical_panel(unit_class_chip, field.TACTICAL_UI_BG_SOFT, field.TACTICAL_UI_BORDER_MUTED, 1, 8)
		if unit_equipped_chip != null:
			field._style_tactical_panel(unit_equipped_chip, field.TACTICAL_UI_BG_SOFT, field.TACTICAL_UI_BORDER_MUTED, 1, 8)
		if unit_equipped_label != null:
			unit_equipped_label.text = "READY: SELECT A UNIT"
		if unit_portrait != null:
			unit_portrait.texture = null
		if unit_portrait_frame != null:
			unit_portrait_frame.visible = true

	convoy_title.text = "CONVOY STORAGE"
	convoy_meta.text = "%d item(s) stored | Filter: %s | Store only while battle is live." % [
		convoy_count,
		field.battle_inventory_filter.capitalize(),
	]


static func _refresh_convoy_empty_state(field) -> void:
	var nodes: Dictionary = _runtime_nodes(field)
	if nodes.is_empty():
		return
	var empty_label := nodes.get("convoy_empty") as Label
	if empty_label == null or field.convoy_grid == null:
		return
	var has_items: bool = false
	for child in field.convoy_grid.get_children():
		if child is Button and child.has_meta("inv_data"):
			has_items = true
			break
	empty_label.visible = not has_items


static func _set_inventory_detail_text(field, text: String) -> void:
	if field.inv_desc_label == null:
		return
	field.inv_desc_label.text = text
	field.inv_desc_label.scroll_to_line(0)
	field.inv_desc_label.call_deferred("scroll_to_line", 0)
	var v_scroll: VScrollBar = field.inv_desc_label.get_v_scroll_bar() as VScrollBar
	if v_scroll != null:
		v_scroll.value = v_scroll.min_value
	field._queue_refit_item_description_panels()


static func _reset_description(field) -> void:
	if field.inv_desc_label == null:
		return
	_refresh_detail_header(field, null)
	_refresh_detail_durability_bar(field, null)
	_refresh_detail_chip_row(field, null)
	clear_detail_confirmation(field)
	_set_inventory_detail_text(field, _default_description_text(field))


static func _clear_selection_visuals(field) -> void:
	for grid in [field.unit_grid, field.convoy_grid]:
		if grid == null:
			continue
		for child in grid.get_children():
			var btn := child as Button
			if btn == null:
				continue
			var base_modulate: Color = btn.get_meta("hover_base_modulate", Color.WHITE)
			btn.modulate = base_modulate
			_animate_slot_selection(field, btn, false)


static func _runtime_nodes(field) -> Dictionary:
	if field.inventory_panel == null:
		return {}
	var nodes_variant: Variant = field.inventory_panel.get_meta(META_RUNTIME_NODES, {})
	return nodes_variant as Dictionary


static func _ensure_modal_dimmer(field) -> ColorRect:
	if field.inventory_panel == null:
		return null
	var ui_parent: Node = field.inventory_panel.get_parent()
	if ui_parent == null:
		return null
	var modal_dimmer := ui_parent.get_node_or_null(MODAL_DIMMER_NAME) as ColorRect
	if modal_dimmer == null:
		modal_dimmer = ColorRect.new()
		modal_dimmer.name = MODAL_DIMMER_NAME
		modal_dimmer.visible = false
		modal_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		modal_dimmer.focus_mode = Control.FOCUS_NONE
		ui_parent.add_child(modal_dimmer)
	return modal_dimmer


static func sync_modal_dimmer(field) -> void:
	var modal_dimmer := _ensure_modal_dimmer(field)
	if modal_dimmer == null or field.inventory_panel == null:
		return
	var should_show: bool = field.inventory_panel.visible
	modal_dimmer.visible = should_show
	if not should_show:
		return
	var ui_parent: Node = field.inventory_panel.get_parent()
	if ui_parent != null:
		ui_parent.move_child(modal_dimmer, max(0, ui_parent.get_child_count() - 1))
		ui_parent.move_child(field.inventory_panel, ui_parent.get_child_count() - 1)
		ui_parent.move_child(modal_dimmer, max(0, field.inventory_panel.get_index() - 1))
	modal_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_dimmer.offset_left = 0
	modal_dimmer.offset_top = 0
	modal_dimmer.offset_right = 0
	modal_dimmer.offset_bottom = 0
	modal_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_dimmer.z_index = 39


static func begin_inventory_drag(field, item: Resource = null) -> void:
	var nodes: Dictionary = _runtime_nodes(field)
	if nodes.is_empty():
		return
	var convoy_card := nodes.get("convoy_card") as Panel
	style_convoy_drop_zone(field, convoy_card, true)
	_apply_inventory_drag_cursor(item)


static func end_inventory_drag(field) -> void:
	var nodes: Dictionary = _runtime_nodes(field)
	if nodes.is_empty():
		return
	var convoy_card := nodes.get("convoy_card") as Panel
	style_convoy_drop_zone(field, convoy_card, false)
	_restore_inventory_drag_cursor()


static func _style_runtime_nodes(field) -> void:
	var nodes: Dictionary = _runtime_nodes(field)
	if nodes.is_empty():
		return

	var modal_dimmer := nodes.get("modal_dimmer") as ColorRect
	var unit_card := nodes.get("unit_card") as Panel
	var unit_portrait_frame := nodes.get("unit_portrait_frame") as Panel
	var unit_portrait_accent := nodes.get("unit_portrait_accent") as ColorRect
	var detail_card := nodes.get("detail_card") as Panel
	var detail_fill_rect := nodes.get("detail_fill") as ColorRect
	var detail_title := nodes.get("detail_title") as Label
	var detail_meta := nodes.get("detail_meta") as Label
	var detail_rule := nodes.get("detail_rule") as ColorRect
	var detail_durability_label := nodes.get("detail_durability_label") as Label
	var detail_durability_bar := nodes.get("detail_durability_bar") as ProgressBar
	var detail_chip_row := nodes.get("detail_chip_row") as HFlowContainer
	var detail_body_panel := nodes.get("detail_body_panel") as Panel
	var detail_confirm_panel := nodes.get("detail_confirm_panel") as Panel
	var detail_confirm_label := nodes.get("detail_confirm_label") as Label
	var convoy_card := nodes.get("convoy_card") as Panel
	var detail_fill := Color(0.24, 0.21, 0.15, 0.985)
	var detail_inner_fill := Color(0.29, 0.25, 0.18, 0.98)

	if modal_dimmer != null:
		modal_dimmer.color = Color(0.02, 0.015, 0.01, 0.84)
		modal_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		modal_dimmer.z_index = 39

	field._style_tactical_panel(field.inventory_panel, field.TACTICAL_UI_BG_ALT, field.TACTICAL_UI_BORDER, 2, 14)
	field._style_tactical_panel(unit_card, field.TACTICAL_UI_BG_SOFT, field.TACTICAL_UI_BORDER_MUTED, 2, 12)
	if unit_portrait_frame != null:
		field._style_tactical_panel(unit_portrait_frame, Color(0.12, 0.10, 0.08, 0.98), field.TACTICAL_UI_BORDER_MUTED, 2, 10)
	if unit_portrait_accent != null:
		unit_portrait_accent.color = field.TACTICAL_UI_ACCENT
	field._style_tactical_panel(detail_card, detail_fill, field.TACTICAL_UI_BORDER, 2, 12)
	if detail_body_panel != null:
		field._style_tactical_panel(detail_body_panel, Color(0.16, 0.14, 0.10, 0.94), field.TACTICAL_UI_BORDER_MUTED, 1, 10)
	if detail_confirm_panel != null:
		field._style_tactical_panel(
			detail_confirm_panel,
			field.TACTICAL_UI_PRIMARY_FILL.lerp(field.TACTICAL_UI_BG_SOFT, 0.20),
			field.TACTICAL_UI_ACCENT,
			2,
			10
		)
	style_convoy_drop_zone(field, convoy_card, false)
	if unit_card != null:
		unit_card.z_index = 1
	if detail_card != null:
		detail_card.z_index = 2
		detail_card.modulate = Color.WHITE
		detail_card.clip_contents = true
	if detail_fill_rect != null:
		detail_fill_rect.color = detail_inner_fill
		detail_fill_rect.z_index = 0
	if detail_rule != null:
		detail_rule.color = Color(field.TACTICAL_UI_BORDER.r, field.TACTICAL_UI_BORDER.g, field.TACTICAL_UI_BORDER.b, 0.45)
		detail_rule.z_index = 1
	if convoy_card != null:
		convoy_card.z_index = 1

	var title_label := nodes.get("title") as Label
	var subtitle_label := nodes.get("subtitle") as Label
	var unit_title := nodes.get("unit_title") as Label
	var unit_class_label := nodes.get("unit_class_label") as Label
	var unit_meta := nodes.get("unit_meta") as Label
	var unit_equipped_chip := nodes.get("unit_equipped_chip") as Panel
	var unit_equipped_label := nodes.get("unit_equipped_label") as Label
	var unit_hint := nodes.get("unit_hint") as Label
	var convoy_title := nodes.get("convoy_title") as Label
	var convoy_meta := nodes.get("convoy_meta") as Label
	var empty_label := nodes.get("convoy_empty") as Label
	var drop_hint := nodes.get("convoy_drop_hint") as Label
	var convoy_toast := nodes.get("convoy_toast") as Label

	field._style_tactical_label(title_label, field.TACTICAL_UI_ACCENT, 24, 4)
	field._style_tactical_label(subtitle_label, field.TACTICAL_UI_TEXT_MUTED, 14, 2)
	field._style_tactical_label(unit_title, field.TACTICAL_UI_ACCENT, 20, 3)
	field._style_tactical_label(unit_class_label, field.TACTICAL_UI_ACCENT_SOFT, 13, 2)
	field._style_tactical_label(unit_meta, field.TACTICAL_UI_TEXT, 14, 2)
	if unit_equipped_chip != null:
		field._style_tactical_panel(unit_equipped_chip, Color(0.16, 0.13, 0.09, 0.96), field.TACTICAL_UI_BORDER_MUTED, 1, 8)
	field._style_tactical_label(unit_equipped_label, field.TACTICAL_UI_TEXT, 13, 2)
	field._style_tactical_label(unit_hint, field.TACTICAL_UI_TEXT_MUTED, 13, 2)
	field._style_tactical_label(detail_title, field.TACTICAL_UI_ACCENT, 24, 3)
	field._style_tactical_label(detail_meta, field.TACTICAL_UI_TEXT_MUTED, 14, 2)
	field._style_tactical_label(detail_durability_label, field.TACTICAL_UI_TEXT_MUTED, 12, 2)
	_style_detail_durability_bar(field, detail_durability_bar, Color(0.26, 0.82, 0.50, 1.0))
	field._style_tactical_label(convoy_title, field.TACTICAL_UI_ACCENT_SOFT, 18, 3)
	field._style_tactical_label(convoy_meta, field.TACTICAL_UI_TEXT_MUTED, 13, 2)
	field._style_tactical_label(empty_label, field.TACTICAL_UI_TEXT_MUTED, 16, 2)
	field._style_tactical_label(drop_hint, field.TACTICAL_UI_ACCENT, 14, 3)
	field._style_tactical_label(convoy_toast, field.TACTICAL_UI_ACCENT, 13, 3)
	field._style_tactical_label(detail_confirm_label, field.TACTICAL_UI_ACCENT, 13, 3)

	field._style_tactical_richtext(field.inv_desc_label, 17, 22)
	field.inv_desc_label.add_theme_constant_override("line_separation", 4)
	field.inv_desc_label.scroll_active = true
	field.inv_desc_label.scroll_following = false
	field.inv_desc_label.selection_enabled = false
	field.inv_desc_label.z_index = 3
	if detail_chip_row != null:
		detail_chip_row.add_theme_constant_override("h_separation", 8)
		detail_chip_row.add_theme_constant_override("v_separation", 6)
		detail_chip_row.z_index = 2

	if field.inv_scroll != null:
		field.inv_scroll.clip_contents = true
		field.inv_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
		field.inv_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		if not field.inv_scroll.get_meta("_battle_inventory_scroll_padded", false):
			field._inventory_scroll_apply_content_padding(field.inv_scroll, field.INVENTORY_UI_SCROLL_CONTENT_PAD)
			field.inv_scroll.set_meta("_battle_inventory_scroll_padded", true)

	if field.unit_grid != null:
		field.unit_grid.columns = 5
		field.unit_grid.add_theme_constant_override("h_separation", field.INVENTORY_UI_GRID_SEP)
		field.unit_grid.add_theme_constant_override("v_separation", field.INVENTORY_UI_GRID_SEP)
	if field.convoy_grid != null:
		field.convoy_grid.columns = 5
		field.convoy_grid.add_theme_constant_override("h_separation", field.INVENTORY_UI_GRID_SEP)
		field.convoy_grid.add_theme_constant_override("v_separation", field.INVENTORY_UI_GRID_SEP)
	var inventory_vbox := field.inv_scroll.get_node_or_null("InventoryVBox") as VBoxContainer
	if inventory_vbox != null:
		inventory_vbox.add_theme_constant_override("separation", field.INVENTORY_UI_VBOX_SEP)


static func _validated_inventory_unit(field, unit: Variant) -> Node2D:
	var unit_node := unit as Node2D
	if unit_node == null or not is_instance_valid(unit_node) or unit_node.is_queued_for_deletion():
		return null
	if unit_node.get_parent() != field.player_container:
		return null
	if unit_node.current_hp <= 0:
		return null
	return unit_node


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
	for index in range(field.player_inventory.size() - 1, -1, -1):
		var item: Resource = field.player_inventory[index]
		if not (item is WeaponData):
			continue
		if not field._is_weapon_convoy_locked(item as WeaponData):
			continue
		var dragon_target: Node2D = _find_player_dragon_with_space(field)
		if dragon_target == null:
			continue
		field.player_inventory.remove_at(index)
		dragon_target.inventory.append(item)


static func _filtered_convoy_items(field) -> Array:
	var filtered: Array = []
	for item in field.player_inventory:
		if item == null:
			continue
		if _matches_filter(item, field.battle_inventory_filter):
			filtered.append(item)
	return filtered


static func _matches_filter(item: Resource, filter_id: String) -> bool:
	match filter_id:
		"weapons":
			return item is WeaponData
		"consumables":
			return (item is ConsumableData) or (item is ChestKeyData)
		"materials":
			return item is MaterialData
		_:
			return true


static func _default_description_text(field) -> String:
	var unit_name: String = ""
	if field.unit_managing_inventory != null and is_instance_valid(field.unit_managing_inventory):
		unit_name = str(field.unit_managing_inventory.unit_name)
	if unit_name != "":
		return (
			"[font_size=18][color=#efe7d8]Select a backpack or convoy slot to inspect it.[/color][/font_size]\n"
			+ "[font_size=17][color=#b8a890]Equip and Use only work from the active unit's backpack. Drag a backpack item into convoy to store it.[/color][/font_size]"
		)
	return (
		"[font_size=18][color=#efe7d8]Select an item to inspect it.[/color][/font_size]\n"
		+ "[font_size=17][color=#b8a890]Convoy withdrawals are disabled mid-battle.[/color][/font_size]"
	)


static func _refresh_detail_header(field, item: Resource, stack_count: int = 1) -> void:
	var nodes: Dictionary = _runtime_nodes(field)
	if nodes.is_empty():
		return
	var detail_title := nodes.get("detail_title") as Label
	var detail_meta := nodes.get("detail_meta") as Label
	if detail_title == null or detail_meta == null:
		return
	if item == null:
		field._style_tactical_label(detail_title, field.TACTICAL_UI_ACCENT, 24, 3)
		field._style_tactical_label(detail_meta, field.TACTICAL_UI_TEXT_MUTED, 14, 2)
		detail_title.text = "SELECT AN ITEM"
		detail_meta.text = "Backpack or convoy inspection"
		return

	var name_text: String = _item_name(item)
	if item is FateCardLootData:
		name_text = FateCardLootHelpers.get_fate_card_loot_label(item as FateCardLootData)
	if name_text == "":
		name_text = "Unknown Item"

	var rarity: String = str(item.get("rarity") if item.get("rarity") != null else "Common")
	var rarity_color: Color = Color(0.95, 0.93, 0.88)
	match rarity:
		"Uncommon":
			rarity_color = Color(0.54, 0.91, 0.62)
		"Rare":
			rarity_color = Color(0.55, 0.84, 1.0)
		"Epic":
			rarity_color = Color(0.83, 0.67, 1.0)
		"Legendary":
			rarity_color = Color(1.0, 0.88, 0.58)
		"Mythic":
			rarity_color = Color(1.0, 0.69, 0.40)
	field._style_tactical_label(detail_title, rarity_color, 24, 3)
	field._style_tactical_label(detail_meta, field.TACTICAL_UI_TEXT_MUTED, 14, 2)
	detail_title.text = name_text.to_upper()

	var meta_parts: PackedStringArray = []
	meta_parts.append(rarity.to_upper())
	var value: int = int(item.get("gold_cost") if item.get("gold_cost") != null else 0)
	if value > 0:
		meta_parts.append("%dG" % value)
	var forge_tag: String = _item_forge_meta_label(item)
	if forge_tag != "":
		meta_parts.append(forge_tag)
	if stack_count > 1:
		meta_parts.append("x%d" % stack_count)
	if item.get("current_durability") == null and item.get("uses") != null:
		meta_parts.append("%d USES" % int(item.uses))
	detail_meta.text = " | ".join(meta_parts)


static func _refresh_detail_durability_bar(field, item: Resource) -> void:
	var nodes: Dictionary = _runtime_nodes(field)
	if nodes.is_empty():
		return
	var durability_label := nodes.get("detail_durability_label") as Label
	var durability_bar := nodes.get("detail_durability_bar") as ProgressBar
	if durability_label == null or durability_bar == null:
		return
	if item == null or item.get("current_durability") == null or item.get("max_durability") == null:
		durability_label.visible = false
		durability_bar.visible = false
		return

	var current_durability: int = int(item.current_durability)
	var max_durability: int = max(1, int(item.max_durability))
	durability_label.visible = true
	durability_bar.visible = true
	durability_label.text = "DURABILITY %d / %d" % [current_durability, max_durability]
	durability_bar.min_value = 0.0
	durability_bar.max_value = float(max_durability)
	durability_bar.value = float(clampi(current_durability, 0, max_durability))
	durability_bar.tooltip_text = "Weapon condition: %d of %d durability remaining." % [current_durability, max_durability]
	_style_detail_durability_bar(field, durability_bar, _detail_durability_fill_color(current_durability, max_durability))


static func _build_inventory_detail_text(field, item: Resource, stack_count: int = 1, viewer_unit: Node2D = null) -> String:
	var lines: PackedStringArray = []
	var desc: String = str(item.get("description") if item.get("description") != null else "").strip_edges()

	if item is WeaponData:
		var weapon: WeaponData = item as WeaponData
		var weapon_type: String = field._weapon_type_name_safe(int(weapon.weapon_type))
		var damage_type: String = "Physical" if int(weapon.damage_type) == 0 else "Magical"
		if not lines.is_empty():
			lines.append("")
		lines.append("[font_size=17][b][color=#f2d680]Combat[/color][/b][/font_size]")
		lines.append(
			"[font_size=15][color=#e9dec7]%s | %s | Range %d-%d[/color][/font_size]"
			% [weapon_type, damage_type, int(weapon.min_range), int(weapon.max_range)]
		)
		lines.append(
			"[font_size=15][color=#e9dec7]Might %d | Hit %+d[/color][/font_size]"
			% [int(weapon.might), int(weapon.hit_bonus)]
		)

		var weapon_status_parts: PackedStringArray = []
		var compare_line: String = ""
		if viewer_unit != null:
			if viewer_unit.get("equipped_weapon") == weapon:
				weapon_status_parts.append("[color=#a8e8b8]Equipped[/color]")
			elif field._unit_can_use_item_for_ui(viewer_unit, weapon):
				weapon_status_parts.append("[color=#a8e8b8]Equippable[/color]")
			else:
				weapon_status_parts.append("[color=#ffa898]Locked[/color]")
			var eq_weapon: Resource = viewer_unit.get("equipped_weapon")
			if eq_weapon != null and eq_weapon is WeaponData and eq_weapon != weapon:
				compare_line = InventoryTradeFlowHelpers.weapon_stat_compare_line_bbcode(weapon, eq_weapon as WeaponData)
		if weapon_status_parts.size() > 0:
			lines.append("[font_size=15]%s[/font_size]" % " | ".join(weapon_status_parts))
		if compare_line != "":
			lines.append(compare_line)

		var weapon_effects: PackedStringArray = []
		if weapon.get("is_healing_staff") == true:
			weapon_effects.append("Restores %d HP" % int(weapon.effect_amount))
		if weapon.get("is_buff_staff") == true or weapon.get("is_debuff_staff") == true:
			var verb: String = "Grants" if weapon.get("is_buff_staff") == true else "Inflicts"
			var affected: String = str(weapon.get("affected_stat") if weapon.get("affected_stat") != null else "").replace(",", ", ")
			if affected.strip_edges() != "":
				weapon_effects.append("%s %d %s" % [verb, int(weapon.effect_amount), affected])
		if weapon_effects.size() > 0:
			lines.append("[font_size=15][color=#d9ccb4]%s[/color][/font_size]" % " | ".join(weapon_effects))
		_append_forge_detail_lines(lines, item)
		_append_rune_detail_lines(lines, weapon)

	elif item is ConsumableData:
		var consumable_effects: PackedStringArray = []
		var consumable: ConsumableData = item as ConsumableData
		if consumable.heal_amount > 0:
			consumable_effects.append("Restores %d HP" % int(consumable.heal_amount))
		if consumable.hp_boost > 0:
			consumable_effects.append("+%d HP" % int(consumable.hp_boost))
		if consumable.str_boost > 0:
			consumable_effects.append("+%d STR" % int(consumable.str_boost))
		if consumable.mag_boost > 0:
			consumable_effects.append("+%d MAG" % int(consumable.mag_boost))
		if consumable.def_boost > 0:
			consumable_effects.append("+%d DEF" % int(consumable.def_boost))
		if consumable.res_boost > 0:
			consumable_effects.append("+%d RES" % int(consumable.res_boost))
		if consumable.spd_boost > 0:
			consumable_effects.append("+%d SPD" % int(consumable.spd_boost))
		if consumable.agi_boost > 0:
			consumable_effects.append("+%d AGI" % int(consumable.agi_boost))
		if consumable.get("is_promotion_item") == true:
			consumable_effects.append("Promotion item")
		var raw_intel_ids: Variant = consumable.get("knowledge_intel_ids")
		if raw_intel_ids is Array and (raw_intel_ids as Array).size() > 0:
			consumable_effects.append("Unlocks field notes intel")

		if consumable_effects.size() > 0:
			if not lines.is_empty():
				lines.append("")
			lines.append("[font_size=17][b][color=#f2d680]Use[/color][/b][/font_size]")
			lines.append("[font_size=15][color=#e9dec7]%s[/color][/font_size]" % " | ".join(consumable_effects))

	elif item is MaterialData:
		if not lines.is_empty():
			lines.append("")
		lines.append("[font_size=15][color=#e9dec7]Crafting material stored for later use.[/color][/font_size]")
	elif item is FateCardLootData:
		if not lines.is_empty():
			lines.append("")
		lines.append("[font_size=15][color=#e9dec7]Permanent campaign unlock. This does not consume convoy space after claim.[/color][/font_size]")

	if desc != "":
		if not lines.is_empty():
			lines.append("")
		lines.append("[font_size=17][b][color=#f2d680]Notes[/color][/b][/font_size]")
		lines.append(
			"[font_size=16][color=#efe6d6]%s[/color][/font_size]"
			% InventoryTradeFlowHelpers.bbcode_escape_user_text(desc.replace("\n", " "))
		)

	return "\n".join(lines)


static func _append_forge_detail_lines(lines: PackedStringArray, item: Resource) -> void:
	var base_recipe_name: String = _item_base_recipe_name(item)
	if base_recipe_name == "":
		return
	if not lines.is_empty():
		lines.append("")
	lines.append("[font_size=17][b][color=#f2d680]Forge[/color][/b][/font_size]")
	lines.append(
		"[font_size=15][color=#e9dec7]Pattern %s[/color][/font_size]"
		% InventoryTradeFlowHelpers.bbcode_escape_user_text(base_recipe_name)
	)
	var quality_label: String = "Masterwork" if _is_masterwork_forged_item(item) else "Forged"
	var quality_color: String = "#ffd27c" if quality_label == "Masterwork" else "#d9c29a"
	lines.append(
		"[font_size=15][color=%s]Quality: %s[/color][/font_size]"
		% [quality_color, quality_label]
	)


static func _append_rune_detail_lines(lines: PackedStringArray, weapon: WeaponData) -> void:
	if weapon == null:
		return
	var slot_count: int = clampi(int(weapon.rune_slot_count), 0, 8)
	var rune_entries: Array[String] = _weapon_rune_entry_labels(weapon)
	if slot_count <= 0 and rune_entries.is_empty():
		return
	if not lines.is_empty():
		lines.append("")
	lines.append("[font_size=17][b][color=#d2a7ff]Runes[/color][/b][/font_size]")
	if slot_count > 0:
		lines.append(
			"[font_size=15][color=#e9dec7]Sockets %d | Inscribed %d[/color][/font_size]"
			% [slot_count, rune_entries.size()]
		)
	if rune_entries.is_empty():
		lines.append("[font_size=15][color=#b8a890]No runes inscribed.[/color][/font_size]")
		return
	for idx in range(rune_entries.size()):
		lines.append(
			"[font_size=15][color=#d8caea]%d.[/color][color=#efe6d6] %s[/color][/font_size]"
			% [
				idx + 1,
				InventoryTradeFlowHelpers.bbcode_escape_user_text(rune_entries[idx]),
			]
		)


static func _weapon_rune_entry_labels(weapon: WeaponData) -> Array[String]:
	var entries: Array[String] = []
	if weapon == null or not (weapon.socketed_runes is Array):
		return entries
	for entry_variant in weapon.socketed_runes as Array:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant as Dictionary
		var rune_id: String = str(entry.get("id", "")).strip_edges()
		if rune_id == "":
			continue
		var parts: PackedStringArray = []
		parts.append(WeaponRuneDisplayHelpers.catalog_name_for_rune_id(rune_id))
		var rank: int = int(entry.get("rank", 0))
		if rank > 0:
			parts.append("R%d" % rank)
		if entry.has("charges"):
			var charges: int = int(entry.get("charges", 0))
			if charges > 0:
				parts.append("%d charges" % charges)
		entries.append(" - ".join(parts))
	return entries


static func _item_base_recipe_name(item: Resource) -> String:
	if item == null or not item.has_meta("base_recipe_name"):
		return ""
	return str(item.get_meta("base_recipe_name", "")).strip_edges()


static func _item_forge_meta_label(item: Resource) -> String:
	var base_recipe_name: String = _item_base_recipe_name(item)
	if base_recipe_name == "":
		return ""
	return "MASTERWORK" if _is_masterwork_forged_item(item) else "FORGED"


static func _is_masterwork_forged_item(item: Resource) -> bool:
	if not (item is WeaponData):
		return false
	var base_recipe_name: String = _item_base_recipe_name(item)
	if base_recipe_name == "":
		return false
	var base_item: Resource = _load_base_recipe_result_item(base_recipe_name)
	if not (base_item is WeaponData):
		return false
	var base_weapon: WeaponData = base_item as WeaponData
	var weapon: WeaponData = item as WeaponData
	return (
		str(weapon.weapon_name) != str(base_weapon.weapon_name)
		or int(weapon.might) != int(base_weapon.might)
		or int(weapon.hit_bonus) != int(base_weapon.hit_bonus)
		or int(weapon.max_durability) != int(base_weapon.max_durability)
		or int(weapon.gold_cost) != int(base_weapon.gold_cost)
		or str(weapon.rarity) != str(base_weapon.rarity)
	)


static func _load_base_recipe_result_item(base_recipe_name: String) -> Resource:
	if base_recipe_name == "":
		return null
	var recipe_db: Node = RecipeDatabaseScript.new()
	for recipe_variant in recipe_db.get("master_recipes") as Array:
		if not (recipe_variant is Dictionary):
			continue
		var recipe: Dictionary = recipe_variant as Dictionary
		if str(recipe.get("name", "")).strip_edges() != base_recipe_name:
			continue
		var result_path: String = str(recipe.get("result", "")).strip_edges()
		if result_path == "" or not ResourceLoader.exists(result_path):
			recipe_db.free()
			return null
		var result: Resource = load(result_path) as Resource
		recipe_db.free()
		return result
	recipe_db.free()
	return null


static func _can_use_personal_item(field, unit: Node2D, item: Resource) -> bool:
	if unit == null or item == null:
		return false
	if not (item is ConsumableData):
		return false

	if item.get("is_promotion_item") == true:
		var current_class: Resource = PromotionFlowSharedHelpers.resolve_current_class_from_unit_node(unit)
		return PromotionFlowSharedHelpers.can_unit_promote(int(unit.level), current_class)

	var raw_intel_ids: Variant = item.get("knowledge_intel_ids")
	if raw_intel_ids is Array and (raw_intel_ids as Array).size() > 0:
		for intel_id in raw_intel_ids:
			if not CampaignManager.has_beastiary_intel(str(intel_id)):
				return true
		return false

	return true


static func _item_name(item: Resource) -> String:
	if item == null:
		return ""
	if item.get("weapon_name") != null:
		return str(item.weapon_name)
	return str(item.get("item_name") if item.get("item_name") != null else "")


static func _item_short_name(item: Resource) -> String:
	var raw_name: String = _item_name(item)
	if raw_name == "":
		return "???"
	return raw_name.substr(0, min(raw_name.length(), 3)).to_upper()


static func _item_drag_label(item: Resource) -> String:
	var raw_name: String = _item_name(item).strip_edges()
	if raw_name == "":
		return "ITEM"
	var clipped: String = raw_name.substr(0, min(raw_name.length(), 18))
	if raw_name.length() > clipped.length():
		clipped += "..."
	return clipped.to_upper()


static func _item_rarity_rank(item: Resource) -> int:
	var rarity: String = str(item.get("rarity") if item != null and item.get("rarity") != null else "Common")
	match rarity:
		"Uncommon":
			return 1
		"Rare":
			return 2
		"Epic":
			return 3
		"Legendary":
			return 4
		"Mythic":
			return 5
		_:
			return 0


static func _item_rarity_border_color(item: Resource) -> Color:
	var rarity: String = str(item.get("rarity") if item != null and item.get("rarity") != null else "Common")
	match rarity:
		"Uncommon":
			return Color(0.46, 0.80, 0.40, 0.96)
		"Rare":
			return Color(0.42, 0.72, 0.98, 0.96)
		"Epic":
			return Color(0.74, 0.56, 0.96, 0.98)
		"Legendary":
			return Color(0.98, 0.84, 0.40, 0.98)
		"Mythic":
			return Color(1.00, 0.52, 0.24, 1.00)
		_:
			return Color(0.58, 0.50, 0.34, 0.94)


static func _apply_rarity_slot_theme(field, btn: Button, item: Resource) -> void:
	if field == null or btn == null or item == null:
		return
	var border: Color = _item_rarity_border_color(item)
	var normal_fill: Color = Color(0.14, 0.11, 0.08, 0.97).lerp(border, 0.08)
	var hover_fill: Color = Color(0.21, 0.16, 0.11, 1.0).lerp(border, 0.12)
	var press_fill: Color = Color(0.27, 0.20, 0.12, 1.0).lerp(border, 0.16)
	var hover_border: Color = border.lightened(0.12)
	var press_border: Color = border.lightened(0.18)
	btn.add_theme_stylebox_override("normal", field._make_tactical_panel_style(normal_fill, border, 2, 8))
	btn.add_theme_stylebox_override("hover", field._make_tactical_panel_style(hover_fill, hover_border, 2, 8))
	btn.add_theme_stylebox_override("pressed", field._make_tactical_panel_style(press_fill, press_border, 2, 8))
	btn.add_theme_stylebox_override("focus", field._make_tactical_panel_style(hover_fill, hover_border, 2, 8))


static func _apply_slot_theme(field, btn: Button) -> void:
	var normal_fill := Color(0.14, 0.11, 0.08, 0.97)
	var hover_fill := Color(0.21, 0.16, 0.11, 1.0)
	var press_fill := Color(0.27, 0.20, 0.12, 1.0)
	btn.add_theme_stylebox_override("normal", field._make_tactical_panel_style(normal_fill, field.TACTICAL_UI_BORDER_MUTED, 2, 8))
	btn.add_theme_stylebox_override("hover", field._make_tactical_panel_style(hover_fill, field.TACTICAL_UI_ACCENT_SOFT, 2, 8))
	btn.add_theme_stylebox_override("pressed", field._make_tactical_panel_style(press_fill, field.TACTICAL_UI_ACCENT, 2, 8))
	btn.add_theme_stylebox_override("focus", field._make_tactical_panel_style(hover_fill, field.TACTICAL_UI_ACCENT_SOFT, 2, 8))
	btn.add_theme_stylebox_override("disabled", field._make_tactical_panel_style(Color(0.08, 0.07, 0.05, 0.86), field.TACTICAL_UI_BORDER_MUTED, 1, 8))


static func _apply_empty_slot_theme(field, btn: Button) -> void:
	btn.text = ""
	btn.modulate = Color(0.72, 0.72, 0.72, 0.8)
	btn.set_meta("hover_base_modulate", btn.modulate)
	btn.add_theme_stylebox_override("disabled", field._make_tactical_panel_style(Color(0.08, 0.07, 0.05, 0.8), field.TACTICAL_UI_BORDER_MUTED, 1, 8))


static func _apply_equipped_slot_theme(field, btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", field._make_tactical_panel_style(Color(0.18, 0.14, 0.09, 0.98), Color(0.95, 0.79, 0.28), 3, 8))
	btn.add_theme_stylebox_override("hover", field._make_tactical_panel_style(Color(0.24, 0.18, 0.11, 1.0), Color(1.0, 0.86, 0.42), 3, 8))
	btn.add_theme_stylebox_override("pressed", field._make_tactical_panel_style(Color(0.27, 0.20, 0.12, 1.0), Color(1.0, 0.82, 0.30), 3, 8))


static func style_convoy_drop_zone(field, convoy_card: Panel, highlighted: bool) -> void:
	if field == null or convoy_card == null:
		return
	var fill: Color = field.TACTICAL_UI_BG_SOFT
	var border: Color = field.TACTICAL_UI_BORDER_MUTED
	if highlighted:
		fill = field.TACTICAL_UI_PRIMARY_FILL.lerp(field.TACTICAL_UI_BG_SOFT, 0.36)
		border = field.TACTICAL_UI_ACCENT
	field._style_tactical_panel(convoy_card, fill, border, 2, 12)
	convoy_card.modulate = Color.WHITE

	var convoy_title := convoy_card.get_node_or_null("InventoryConvoyTitleLabel") as Label
	var convoy_meta := convoy_card.get_node_or_null("InventoryConvoyMetaLabel") as Label
	var drop_hint := convoy_card.get_node_or_null("InventoryConvoyDropHintLabel") as Label
	if highlighted:
		field._style_tactical_label(convoy_title, field.TACTICAL_UI_ACCENT, 18, 3)
		field._style_tactical_label(convoy_meta, field.TACTICAL_UI_TEXT, 13, 2)
	else:
		field._style_tactical_label(convoy_title, field.TACTICAL_UI_ACCENT_SOFT, 18, 3)
		field._style_tactical_label(convoy_meta, field.TACTICAL_UI_TEXT_MUTED, 13, 2)
	if drop_hint != null:
		drop_hint.visible = highlighted


static func _animate_slot_selection(field, btn: Button, selected: bool) -> void:
	if field == null or btn == null or not is_instance_valid(btn):
		return
	_stop_slot_selection_pulse(btn)
	_set_selected_slot_rarity_fx(field, btn, selected)
	btn.pivot_offset = btn.size * 0.5
	if selected:
		btn.scale = Vector2(1.04, 1.04)
		btn.modulate = _selected_slot_rest_modulate(btn)
		var intro_tween: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		intro_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		intro_tween.set_parallel(true)
		intro_tween.tween_property(btn, "scale", Vector2(1.10, 1.10), 0.10)
		intro_tween.tween_property(btn, "modulate", _selected_slot_peak_modulate(btn), 0.10)
		intro_tween.chain().tween_callback(func() -> void:
			_start_slot_selection_pulse(field, btn)
		)
		return

	var outro_tween: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	outro_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	outro_tween.set_parallel(true)
	outro_tween.tween_property(btn, "scale", Vector2.ONE, 0.10)
	outro_tween.tween_property(btn, "modulate", btn.get_meta("hover_base_modulate", Color.WHITE) as Color, 0.10)


static func _start_slot_selection_pulse(field, btn: Button) -> void:
	if field == null or btn == null or not is_instance_valid(btn):
		return
	_stop_slot_selection_pulse(btn)
	btn.set_meta("_selection_pulse_active", true)
	_continue_slot_selection_pulse(field, btn, true)


static func _continue_slot_selection_pulse(field, btn: Button, pulse_up: bool) -> void:
	if field == null or btn == null or not is_instance_valid(btn):
		return
	if not bool(btn.get_meta("_selection_pulse_active", false)):
		return
	var inv_data_variant: Variant = btn.get_meta("inv_data", null)
	if not (inv_data_variant is Dictionary) or not _is_slot_currently_selected(field, inv_data_variant as Dictionary):
		_stop_slot_selection_pulse(btn)
		return

	var pulse_tween: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.set_parallel(true)
	if pulse_up:
		pulse_tween.tween_property(btn, "scale", Vector2(1.105, 1.105), 0.40)
		pulse_tween.tween_property(btn, "modulate", _selected_slot_peak_modulate(btn), 0.36)
	else:
		pulse_tween.tween_property(btn, "scale", Vector2(1.065, 1.065), 0.48)
		pulse_tween.tween_property(btn, "modulate", _selected_slot_rest_modulate(btn), 0.42)
	pulse_tween.chain().tween_callback(func() -> void:
		_continue_slot_selection_pulse(field, btn, not pulse_up)
	)
	btn.set_meta("_selection_pulse_tween", pulse_tween)


static func _stop_slot_selection_pulse(btn: Button) -> void:
	if btn == null:
		return
	btn.remove_meta("_selection_pulse_active")
	var tween_variant: Variant = btn.get_meta("_selection_pulse_tween", null)
	var pulse_tween: Tween = tween_variant as Tween
	if pulse_tween != null:
		pulse_tween.kill()
		btn.remove_meta("_selection_pulse_tween")


static func _set_selected_slot_rarity_fx(field, btn: Button, selected: bool) -> void:
	if field == null or btn == null:
		return
	var glow := btn.get_node_or_null("SelectedRarityGlow") as ColorRect
	var trim := btn.get_node_or_null("SelectedRarityTrim") as Panel
	var inv_data_variant: Variant = btn.get_meta("inv_data", null)
	var item: Resource = null
	if inv_data_variant is Dictionary:
		item = (inv_data_variant as Dictionary).get("item", null)
	var show_fx: bool = selected and _item_rarity_rank(item) >= HIGH_RARITY_SELECTED_RANK
	if not show_fx:
		if glow != null:
			glow.visible = false
		if trim != null:
			trim.visible = false
		return

	var accent: Color = _item_rarity_border_color(item)
	if glow == null:
		glow = ColorRect.new()
		glow.name = "SelectedRarityGlow"
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow.offset_left = 4
		glow.offset_top = 4
		glow.offset_right = -4
		glow.offset_bottom = -4
		btn.add_child(glow)
		btn.move_child(glow, 0)
	if trim == null:
		trim = Panel.new()
		trim.name = "SelectedRarityTrim"
		trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trim.set_anchors_preset(Control.PRESET_FULL_RECT)
		trim.offset_left = 6
		trim.offset_top = 6
		trim.offset_right = -6
		trim.offset_bottom = -6
		btn.add_child(trim)
		btn.move_child(trim, 1)
	glow.color = Color(accent.r, accent.g, accent.b, 0.10)
	glow.visible = true
	field._style_tactical_panel(trim, Color(accent.r, accent.g, accent.b, 0.03), accent.lightened(0.10), 1, 6)
	trim.visible = true


static func _selected_slot_rest_modulate(btn: Button) -> Color:
	var base_modulate: Color = btn.get_meta("hover_base_modulate", Color.WHITE) as Color
	return base_modulate * Color(1.18, 1.18, 1.08, 1.0)


static func _selected_slot_peak_modulate(btn: Button) -> Color:
	var base_modulate: Color = btn.get_meta("hover_base_modulate", Color.WHITE) as Color
	return base_modulate * Color(1.28, 1.25, 1.12, 1.0)


static func _is_slot_currently_selected(field, meta: Dictionary) -> bool:
	if field == null or meta.is_empty() or field.selected_inventory_meta.is_empty():
		return false
	var selected_meta: Dictionary = field.selected_inventory_meta
	return (
		str(selected_meta.get("source", "")) == str(meta.get("source", ""))
		and int(selected_meta.get("index", -1)) == int(meta.get("index", -2))
		and selected_meta.get("item", null) == meta.get("item", null)
	)


static func _style_inventory_action_button(field, btn: Button, label: String, active: bool) -> void:
	if field == null or btn == null:
		return
	field._style_tactical_button(btn, label, false, 18)
	btn.modulate = Color.WHITE
	if active:
		var active_fill: Color = field.TACTICAL_UI_PRIMARY_FILL.lerp(field.TACTICAL_UI_ACCENT, 0.22)
		var active_hover: Color = field.TACTICAL_UI_PRIMARY_HOVER.lerp(field.TACTICAL_UI_ACCENT, 0.18)
		btn.add_theme_stylebox_override("normal", field._make_tactical_panel_style(active_fill, field.TACTICAL_UI_ACCENT, 3, 10))
		btn.add_theme_stylebox_override("hover", field._make_tactical_panel_style(active_hover, field.TACTICAL_UI_ACCENT_SOFT, 3, 10))
		btn.add_theme_stylebox_override("pressed", field._make_tactical_panel_style(field.TACTICAL_UI_PRIMARY_PRESS, field.TACTICAL_UI_ACCENT, 3, 10))
		btn.add_theme_stylebox_override("focus", field._make_tactical_panel_style(active_hover, field.TACTICAL_UI_ACCENT_SOFT, 3, 10))
		btn.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		btn.add_theme_color_override("font_disabled_color", field.TACTICAL_UI_TEXT_MUTED)
	else:
		var idle_fill: Color = field.TACTICAL_UI_BG_SOFT.lerp(field.TACTICAL_UI_BG_ALT, 0.28)
		var idle_border: Color = field.TACTICAL_UI_BORDER_MUTED
		btn.add_theme_stylebox_override("normal", field._make_tactical_panel_style(idle_fill, idle_border, 2, 10))
		btn.add_theme_stylebox_override("hover", field._make_tactical_panel_style(idle_fill, idle_border, 2, 10))
		btn.add_theme_stylebox_override("pressed", field._make_tactical_panel_style(idle_fill, idle_border, 2, 10))
		btn.add_theme_stylebox_override("focus", field._make_tactical_panel_style(idle_fill, idle_border, 2, 10))
		btn.add_theme_stylebox_override("disabled", field._make_tactical_panel_style(idle_fill, idle_border, 2, 10))
		btn.add_theme_color_override("font_color", field.TACTICAL_UI_TEXT_MUTED)
		btn.add_theme_color_override("font_hover_color", field.TACTICAL_UI_TEXT_MUTED)
		btn.add_theme_color_override("font_pressed_color", field.TACTICAL_UI_TEXT_MUTED)
		btn.add_theme_color_override("font_disabled_color", field.TACTICAL_UI_TEXT_MUTED)


static func _build_slot_tooltip(
	field,
	item: Resource,
	count: int,
	viewer_unit: Node2D,
	owner_unit: Node2D,
	source_type: String,
	is_usable_for_viewer: bool
) -> String:
	if item == null:
		return ""
	var lines: PackedStringArray = []
	lines.append(_item_name(item))
	if owner_unit != null and item == owner_unit.get("equipped_weapon"):
		lines.append("E: Equipped now.")
	if item is WeaponData and not is_usable_for_viewer and viewer_unit != null:
		lines.append("X: %s cannot use this weapon." % str(viewer_unit.unit_name))
	if item is WeaponData and field._is_weapon_convoy_locked(item as WeaponData):
		lines.append("!: Dragon-bound gear cannot be stored in convoy.")
	if count > 1 and source_type == "convoy":
		lines.append("x%d: Stacked convoy copies." % count)
	if item.get("current_durability") != null:
		lines.append("%d/%d durability remaining." % [int(item.current_durability), int(item.max_durability)])
	elif item.get("uses") != null:
		lines.append("%d uses remaining." % int(item.uses))
	return "\n".join(lines)


static func _play_inventory_feedback_sfx(field, cue: String) -> void:
	if field == null or field.select_sound == null or field.select_sound.stream == null:
		return
	var pitch_min: float = 1.0
	var pitch_max: float = 1.0
	match cue:
		"open":
			pitch_min = 0.96
			pitch_max = 1.02
		"select":
			pitch_min = 1.08
			pitch_max = 1.13
		"store":
			pitch_min = 0.90
			pitch_max = 0.97
	field.select_sound.pitch_scale = randf_range(pitch_min, pitch_max)
	field.select_sound.play()


static func _get_inventory_unit_portrait(unit: Node2D) -> Texture2D:
	if unit == null:
		return null
	if unit.get("data") != null and unit.data.get("portrait") != null:
		return unit.data.portrait
	if unit.get("active_class_data") != null and unit.active_class_data.get("promoted_portrait") != null:
		return unit.active_class_data.promoted_portrait
	var portrait_variant: Variant = unit.get("portrait")
	return portrait_variant as Texture2D


static func _refresh_detail_chip_row(
	field,
	item: Resource,
	stack_count: int = 1,
	viewer_unit: Node2D = null
) -> void:
	var nodes: Dictionary = _runtime_nodes(field)
	if nodes.is_empty():
		return
	var chip_row := nodes.get("detail_chip_row") as HFlowContainer
	if chip_row == null:
		return
	for child in chip_row.get_children():
		chip_row.remove_child(child)
		child.queue_free()
	chip_row.visible = item != null
	if item == null:
		return

	var chips: Array[Dictionary] = []
	if item is WeaponData:
		var weapon: WeaponData = item as WeaponData
		var damage_type: String = "PHYSICAL" if int(weapon.damage_type) == 0 else "MAGICAL"
		var rune_entry_count: int = _weapon_rune_entry_labels(weapon).size()
		chips.append(_detail_chip_data(field._weapon_type_name_safe(int(weapon.weapon_type)).to_upper(), field.TACTICAL_UI_ACCENT_SOFT))
		chips.append(_detail_chip_data(damage_type, Color(0.98, 0.82, 0.52)))
		chips.append(_detail_chip_data("RNG %d-%d" % [int(weapon.min_range), int(weapon.max_range)], Color(0.82, 0.93, 1.0)))
		chips.append(_detail_chip_data("MT %d" % int(weapon.might), Color(1.0, 0.78, 0.68)))
		chips.append(_detail_chip_data("HIT %+d" % int(weapon.hit_bonus), Color(0.92, 0.92, 0.92)))
		if viewer_unit != null:
			if viewer_unit.get("equipped_weapon") == weapon:
				chips.append(_detail_chip_data("EQUIPPED", Color(0.68, 1.0, 0.74), true))
			elif field._unit_can_use_item_for_ui(viewer_unit, weapon):
				chips.append(_detail_chip_data("READY", Color(0.77, 0.95, 1.0), true))
			else:
				chips.append(_detail_chip_data("LOCKED", Color(1.0, 0.70, 0.70), true))
		var slot_count: int = clampi(int(weapon.rune_slot_count), 0, 8)
		if slot_count > 0:
			chips.append(
				_detail_chip_data(
					"RUNES %d/%d" % [rune_entry_count, slot_count],
					Color(0.85, 0.72, 1.0),
					rune_entry_count > 0
				)
			)
		var forge_tag: String = _item_forge_meta_label(item)
		if forge_tag != "":
			var forge_color: Color = Color(1.0, 0.84, 0.58) if forge_tag == "MASTERWORK" else Color(0.90, 0.78, 0.60)
			chips.append(_detail_chip_data(forge_tag, forge_color, true))
	elif item is ConsumableData:
		var consumable: ConsumableData = item as ConsumableData
		if consumable.heal_amount > 0:
			chips.append(_detail_chip_data("HEAL %d" % int(consumable.heal_amount), Color(0.70, 1.0, 0.76), true))
		if consumable.hp_boost > 0:
			chips.append(_detail_chip_data("+%d HP" % int(consumable.hp_boost), Color(0.90, 0.86, 1.0)))
		if consumable.str_boost > 0:
			chips.append(_detail_chip_data("+%d STR" % int(consumable.str_boost), Color(1.0, 0.76, 0.68)))
		if consumable.mag_boost > 0:
			chips.append(_detail_chip_data("+%d MAG" % int(consumable.mag_boost), Color(0.88, 0.76, 1.0)))
		if consumable.def_boost > 0:
			chips.append(_detail_chip_data("+%d DEF" % int(consumable.def_boost), Color(0.82, 0.96, 0.86)))
		if consumable.res_boost > 0:
			chips.append(_detail_chip_data("+%d RES" % int(consumable.res_boost), Color(0.76, 0.90, 1.0)))
		if consumable.spd_boost > 0:
			chips.append(_detail_chip_data("+%d SPD" % int(consumable.spd_boost), Color(0.99, 0.88, 0.66)))
		if consumable.agi_boost > 0:
			chips.append(_detail_chip_data("+%d AGI" % int(consumable.agi_boost), Color(0.99, 0.92, 0.70)))
		if consumable.get("is_promotion_item") == true:
			chips.append(_detail_chip_data("PROMOTION", Color(1.0, 0.82, 0.54), true))
		var raw_intel_ids: Variant = consumable.get("knowledge_intel_ids")
		if raw_intel_ids is Array and (raw_intel_ids as Array).size() > 0:
			chips.append(_detail_chip_data("INTEL", Color(0.76, 0.92, 1.0), true))
		if consumable.get("uses") != null:
			chips.append(_detail_chip_data("%d USES" % int(consumable.uses), Color(0.95, 0.90, 0.76)))
	elif item is MaterialData:
		chips.append(_detail_chip_data("MATERIAL", Color(0.88, 1.0, 0.72), true))
	elif item is FateCardLootData:
		chips.append(_detail_chip_data("CAMPAIGN UNLOCK", Color(0.98, 0.84, 0.54), true))
	if stack_count > 1:
		chips.append(_detail_chip_data("STACK x%d" % stack_count, Color(0.95, 0.92, 0.82)))
	if chips.is_empty():
		chip_row.visible = false
		return

	for chip_data in chips:
		chip_row.add_child(_make_detail_chip(field, chip_data))


static func _detail_chip_data(text: String, accent: Color, emphasized: bool = false) -> Dictionary:
	return {
		"text": text,
		"accent": accent,
		"emphasized": emphasized,
	}


static func _make_detail_chip(field, chip_data: Dictionary) -> Panel:
	var chip := Panel.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_text: String = str(chip_data.get("text", "")).to_upper()
	var chip_width: float = clampf((float(chip_text.length()) * 8.4) + 28.0, 74.0, 196.0)
	chip.custom_minimum_size = Vector2(chip_width, 28.0)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var accent: Color = chip_data.get("accent", field.TACTICAL_UI_ACCENT_SOFT) as Color
	var emphasized: bool = bool(chip_data.get("emphasized", false))
	var fill_alpha: float = 0.12 if emphasized else 0.08
	var border_lighten: float = 0.12 if emphasized else 0.02
	var fill: Color = Color(accent.r, accent.g, accent.b, fill_alpha)
	var border: Color = accent.lightened(border_lighten)
	field._style_tactical_panel(chip, fill, border, 1, 8)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 8
	label.offset_top = 2
	label.offset_right = -8
	label.offset_bottom = -2
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = chip_text
	field._style_tactical_label(label, accent, 12, 2)
	chip.add_child(label)
	return chip


static func _style_detail_durability_bar(field, bar: ProgressBar, fill: Color) -> void:
	if field == null or bar == null:
		return
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 18.0)
	bar.add_theme_stylebox_override("background", field._make_tactical_bar_style(Color(0.10, 0.09, 0.06, 0.98), Color(0.72, 0.61, 0.28, 1.0), 2, 6))
	bar.add_theme_stylebox_override("fill", field._make_tactical_bar_style(fill, Color(0.85, 0.78, 0.44, 0.95), 1, 6))


static func _detail_durability_fill_color(current_value: int, max_value: int) -> Color:
	if max_value <= 0:
		return Color(0.92, 0.32, 0.27, 1.0)
	var ratio: float = clampf(float(current_value) / float(max_value), 0.0, 1.0)
	if ratio >= 0.67:
		return Color(0.24, 0.86, 0.50, 1.0)
	if ratio >= 0.34:
		return Color(0.93, 0.74, 0.24, 1.0)
	return Color(0.92, 0.32, 0.27, 1.0)


static func clear_detail_confirmation(field) -> void:
	var nodes: Dictionary = _runtime_nodes(field)
	if nodes.is_empty():
		return
	var confirm_panel := nodes.get("detail_confirm_panel") as Panel
	if confirm_panel == null:
		return
	if confirm_panel.has_meta("_detail_confirm_tween"):
		var tween_variant: Variant = confirm_panel.get_meta("_detail_confirm_tween")
		var active_tween: Tween = tween_variant as Tween
		if active_tween != null:
			active_tween.kill()
		confirm_panel.remove_meta("_detail_confirm_tween")
	confirm_panel.visible = false
	confirm_panel.modulate = Color.WHITE


static func show_detail_confirmation(field, text: String, accent: Color = Color(0.68, 1.0, 0.74)) -> void:
	var nodes: Dictionary = _runtime_nodes(field)
	if nodes.is_empty():
		return
	var confirm_panel := nodes.get("detail_confirm_panel") as Panel
	var confirm_label := nodes.get("detail_confirm_label") as Label
	if confirm_panel == null or confirm_label == null:
		return
	clear_detail_confirmation(field)
	field._style_tactical_panel(confirm_panel, Color(accent.r, accent.g, accent.b, 0.18), accent, 2, 10)
	field._style_tactical_label(confirm_label, accent, 13, 3)
	confirm_label.text = text.to_upper()
	confirm_panel.visible = true
	confirm_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(confirm_panel, "modulate:a", 1.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(DETAIL_CONFIRM_SHOW_TIME)
	tween.tween_property(confirm_panel, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		confirm_panel.visible = false
		confirm_panel.modulate = Color.WHITE
	)
	confirm_panel.set_meta("_detail_confirm_tween", tween)


static func focus_inventory_item(field, target_item: Resource, preferred_source: String = "unit_personal", play_sound: bool = false) -> void:
	if field == null or target_item == null:
		return
	var matching_btn: Button = null
	var matching_meta: Dictionary = {}
	for grid in [field.unit_grid, field.convoy_grid]:
		if grid == null:
			continue
		for child in grid.get_children():
			var btn := child as Button
			if btn == null or not btn.has_meta("inv_data"):
				continue
			var meta: Dictionary = btn.get_meta("inv_data") as Dictionary
			if meta.get("item", null) != target_item:
				continue
			if preferred_source != "" and str(meta.get("source", "")) != preferred_source:
				if matching_btn == null:
					matching_btn = btn
					matching_meta = meta
				continue
			matching_btn = btn
			matching_meta = meta
			break
		if matching_btn != null and str(matching_meta.get("source", "")) == preferred_source:
			break
	if matching_btn == null or matching_meta.is_empty():
		return
	if play_sound:
		_play_inventory_feedback_sfx(field, "select")
	field.selected_inventory_meta = matching_meta
	_clear_selection_visuals(field)
	_animate_slot_selection(field, matching_btn, true)
	clear_detail_confirmation(field)
	var viewer_unit: Node2D = matching_meta.get("unit", null)
	var count: int = int(matching_meta.get("count", 1))
	_refresh_detail_header(field, target_item, count)
	_refresh_detail_durability_bar(field, target_item)
	_set_inventory_detail_text(field, _build_inventory_detail_text(field, target_item, count, viewer_unit))
	_refresh_detail_chip_row(field, target_item, count, viewer_unit)
	refresh_action_buttons(field)


static func _apply_inventory_drag_cursor(item: Resource) -> void:
	if item == null:
		return
	var icon_texture := item.get("icon") as Texture2D
	if icon_texture == null:
		return
	var cursor_texture := _make_drag_cursor_texture(icon_texture)
	if cursor_texture == null:
		return
	var hotspot := Vector2(8, 8)
	for cursor_shape in [
		Input.CURSOR_ARROW,
		Input.CURSOR_POINTING_HAND,
		Input.CURSOR_MOVE,
		Input.CURSOR_CAN_DROP,
		Input.CURSOR_FORBIDDEN,
	]:
		Input.set_custom_mouse_cursor(cursor_texture, cursor_shape, hotspot)


static func _restore_inventory_drag_cursor() -> void:
	CampaignManager.apply_custom_mouse_cursors()


static func _make_drag_cursor_texture(icon_texture: Texture2D) -> Texture2D:
	if icon_texture == null:
		return null
	var image: Image = icon_texture.get_image()
	if image == null or image.is_empty():
		return icon_texture
	var max_side: int = maxi(image.get_width(), image.get_height())
	if max_side <= DRAG_CURSOR_MAX_SIZE:
		return icon_texture
	var scale_ratio: float = float(DRAG_CURSOR_MAX_SIZE) / float(max_side)
	var target_w: int = maxi(1, int(round(image.get_width() * scale_ratio)))
	var target_h: int = maxi(1, int(round(image.get_height() * scale_ratio)))
	image.resize(target_w, target_h, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


static func _play_convoy_store_feedback(field, item: Resource) -> void:
	var nodes: Dictionary = _runtime_nodes(field)
	if nodes.is_empty():
		return
	var toast := nodes.get("convoy_toast") as Label
	if toast == null:
		return
	toast.text = "%s STORED" % _item_drag_label(item)
	toast.visible = true
	toast.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var base_position: Vector2 = toast.position
	toast.position = base_position + Vector2(0.0, 4.0)
	var tween: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(toast, "modulate:a", 1.0, 0.10)
	tween.tween_property(toast, "position:y", base_position.y, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(0.28)
	tween.set_parallel(true)
	tween.tween_property(toast, "modulate:a", 0.0, 0.22)
	tween.tween_property(toast, "position:y", base_position.y - 4.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func() -> void:
		toast.visible = false
		toast.position = base_position
		toast.modulate = Color.WHITE
	)


static func _play_inventory_open_animation(field) -> void:
	if field == null or field.inventory_panel == null:
		return
	var modal_dimmer := _ensure_modal_dimmer(field)
	field.inventory_panel.visible = true
	sync_modal_dimmer(field)
	field.inventory_panel.scale = PANEL_OPEN_SCALE
	field.inventory_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if modal_dimmer != null:
		modal_dimmer.visible = true
		modal_dimmer.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(field.inventory_panel, "modulate:a", 1.0, PANEL_OPEN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(field.inventory_panel, "scale", Vector2.ONE, PANEL_OPEN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if modal_dimmer != null:
		tween.tween_property(modal_dimmer, "modulate:a", 1.0, PANEL_OPEN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _play_inventory_close_animation(field) -> void:
	if field == null or field.inventory_panel == null or not field.inventory_panel.visible:
		return
	var modal_dimmer := _ensure_modal_dimmer(field)
	var tween: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(field.inventory_panel, "modulate:a", 0.0, PANEL_CLOSE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(field.inventory_panel, "scale", PANEL_OPEN_SCALE, PANEL_CLOSE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if modal_dimmer != null:
		tween.tween_property(modal_dimmer, "modulate:a", 0.0, PANEL_CLOSE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		field.inventory_panel.visible = false
		field.inventory_panel.scale = Vector2.ONE
		field.inventory_panel.modulate = Color.WHITE
		_restore_inventory_drag_cursor()
		if modal_dimmer != null:
			modal_dimmer.visible = false
			modal_dimmer.modulate = Color.WHITE
		field.selected_inventory_meta.clear()
		_clear_selection_visuals(field)
		clear_detail_confirmation(field)
		_reset_description(field)
		refresh_action_buttons(field)
		if field.current_state == field.player_state and field.player_state != null:
			field.player_state.is_forecasting = false
		field.unit_managing_inventory = null
		field.battle_inventory_open_source = ""
		refresh_inventory_entry_state(field)
		sync_modal_dimmer(field)
	)


static func _add_count_badge(btn: Button, count: int) -> void:
	var count_label := Label.new()
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.text = "x%d" % count
	count_label.add_theme_font_size_override("font_size", 15)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_constant_override("outline_size", 5)
	count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_child(count_label)
	count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.offset_right = -4
	count_label.offset_bottom = -2


static func _add_durability_badge(item: Resource, btn: Button) -> void:
	if item == null:
		return
	var badge_text: String = ""
	if item.get("current_durability") != null:
		badge_text = str(int(item.current_durability))
	elif item.get("uses") != null:
		badge_text = str(int(item.uses))
	if badge_text == "":
		return

	var durability_label := Label.new()
	durability_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	durability_label.text = badge_text
	durability_label.add_theme_font_size_override("font_size", 13)
	durability_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.78))
	durability_label.add_theme_constant_override("outline_size", 5)
	durability_label.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_child(durability_label)
	durability_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	durability_label.offset_left = 5
	durability_label.offset_bottom = -3


static func _add_corner_badge(btn: Button, text: String, preset: int, color: Color, font_size: int) -> void:
	var badge := Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.text = text
	badge.add_theme_font_size_override("font_size", font_size)
	badge.add_theme_color_override("font_color", color)
	badge.add_theme_constant_override("outline_size", 5)
	badge.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_child(badge)
	badge.set_anchors_preset(preset)
	match preset:
		Control.PRESET_TOP_RIGHT:
			badge.offset_right = -6
			badge.offset_top = 2
		Control.PRESET_TOP_LEFT:
			badge.offset_left = 6
			badge.offset_top = 2
