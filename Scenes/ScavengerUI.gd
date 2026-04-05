# ==============================================================================
# Script Name: ScavengerUI.gd
# Purpose: Player-facing UI for the salvage network (circulating relics, grey-market recovery).
# Entry: open_network(); core flow: _on_action_btn_pressed (pass into chain / recover from chain).
# ==============================================================================

extends Control

@onready var main_panel: Panel = $MainPanel
@onready var close_btn: Button = $MainPanel/CloseBtn

@onready var convoy_grid: GridContainer = $MainPanel/LayoutHBox/ConvoySection/ConvoyScroll/ConvoyGrid
@onready var network_grid: GridContainer = $MainPanel/LayoutHBox/NetworkSection/NetworkScroll/NetworkGrid
@onready var refresh_btn: Button = $MainPanel/LayoutHBox/NetworkSection/RefreshBtn

@onready var preview_icon: TextureRect = $MainPanel/LayoutHBox/DetailsSection/PreviewIcon
@onready var donor_label: Label = $MainPanel/LayoutHBox/DetailsSection/DonorLabel
@onready var item_desc: RichTextLabel = $MainPanel/LayoutHBox/DetailsSection/ItemDesc
@onready var action_btn: Button = $MainPanel/LayoutHBox/DetailsSection/ActionBtn

# Audio (Optional: Assign these in the editor if you want sounds here too)
var select_sound = AudioStreamPlayer.new()
var transaction_sound = AudioStreamPlayer.new()

var selected_meta: Dictionary = {}
var _last_selected_btn: Button = null
var _last_selected_was_convoy: bool = false
var selected_transfer_qty: int = 1
var _qty_container: HBoxContainer = null
var _qty_label: Label = null
var _max_transfer_qty: int = 1
var _status_label: Label = null
# Filter: "all" | "relics" | "materials"
var convoy_filter: String = "all"
var network_filter: String = "all"

const NETWORK_TILE_TINT: Color = Color(0.68, 0.72, 0.66)
const UNSELECTED_DIM: float = 0.78
const SELECT_TINT_CONVOY: Color = Color(0.75, 0.9, 1.0)
const SELECT_TINT_NETWORK: Color = Color(0.98, 0.94, 0.82)
const COST_COLOR_SALVAGE: Color = Color(0.82, 0.72, 0.48)
const BORDER_SELECTED: Color = Color(1.0, 0.88, 0.45)
const BORDER_RELIC: Color = Color(0.75, 0.6, 0.35)
const BORDER_MATERIAL: Color = Color(0.45, 0.5, 0.45)
const BG_CONVOY: Color = Color(0.12, 0.14, 0.18)
const BG_NETWORK: Color = Color(0.14, 0.13, 0.12)
const DEBUG_SCAVENGER: bool = false

const STATUS_LINES: Array[String] = [
	"Fresh salvage surfaced.",
	"Shared route stock turned up usable goods.",
	"The chain is quiet.",
	"Recovered relics pass through many hands.",
	"Bulk lots circulate faster than names do.",
	"Some finds never stay buried.",
	"Select an item. Salvage circulates hand to hand."
]
const EMPTY_LINES: Array[String] = [
	"The network is quiet.",
	"No salvage surfaced this time.",
	"Nothing worth reclaiming answered this pass.",
	"The salvage routes are quiet."
]
const FAILED_LINES: Array[String] = [
	"The network failed to answer.",
	"No signal from the salvage routes."
]
const SEARCHING_LINES: Array[String] = [
	"Searching the salvage routes...",
	"Sifting the chain..."
]

func _ready() -> void:
	add_child(select_sound)
	add_child(transaction_sound)
	close_btn.pressed.connect(close_network)
	refresh_btn.pressed.connect(_on_refresh_pressed)
	action_btn.pressed.connect(_on_action_btn_pressed)
	_build_qty_container()
	_build_filter_buttons()
	_build_status_label()
	_apply_panel_style()
	self.visible = false

func _apply_panel_style() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.12)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.35, 0.32, 0.28)
	panel_style.set_corner_radius_all(8)
	main_panel.add_theme_stylebox_override("panel", panel_style)

func _build_status_label() -> void:
	var details: Control = item_desc.get_parent()
	if details == null: return
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.52))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = _pick_flavor(STATUS_LINES)
	details.add_child(_status_label)
	details.move_child(_status_label, 0)

func _update_status_line(has_network_items: bool, has_selection: bool) -> void:
	if _status_label == null: return
	if has_selection:
		_status_label.text = ""
		return
	if has_network_items:
		_status_label.text = _pick_flavor(["Fresh salvage surfaced.", "Shared route stock turned up usable goods.", "Recovered relics pass through many hands."])
	else:
		_status_label.text = _pick_flavor(["The chain is quiet.", "Select an item. Salvage circulates hand to hand.", "Bulk lots circulate faster than names do."])

func _build_filter_buttons() -> void:
	var convoy_section: Control = get_node_or_null("MainPanel/LayoutHBox/ConvoySection")
	var network_section: Control = get_node_or_null("MainPanel/LayoutHBox/NetworkSection")
	var convoy_grp: ButtonGroup = ButtonGroup.new()
	var network_grp: ButtonGroup = ButtonGroup.new()
	var seg_normal := StyleBoxFlat.new()
	seg_normal.bg_color = Color(0.18, 0.18, 0.2)
	seg_normal.set_border_width_all(1)
	seg_normal.border_color = Color(0.35, 0.35, 0.38)
	seg_normal.set_corner_radius_all(3)
	var seg_pressed := StyleBoxFlat.new()
	seg_pressed.bg_color = Color(0.25, 0.24, 0.2)
	seg_pressed.set_border_width_all(1)
	seg_pressed.border_color = BORDER_RELIC
	seg_pressed.set_corner_radius_all(3)
	if convoy_section != null:
		var h: HBoxContainer = HBoxContainer.new()
		h.add_theme_constant_override("separation", 2)
		for label in ["All", "Relics", "Materials"]:
			var b: Button = Button.new()
			b.text = label
			b.toggle_mode = true
			b.button_group = convoy_grp
			b.add_theme_stylebox_override("normal", seg_normal.duplicate())
			b.add_theme_stylebox_override("hover", seg_pressed.duplicate())
			b.add_theme_stylebox_override("pressed", seg_pressed.duplicate())
			var key: String = "all" if label == "All" else ("relics" if label == "Relics" else "materials")
			b.pressed.connect(_on_convoy_filter.bind(key))
			h.add_child(b)
			if label == "All": b.button_pressed = true
		convoy_section.add_child(h)
		convoy_section.move_child(h, 1)
	if network_section != null:
		var h: HBoxContainer = HBoxContainer.new()
		h.add_theme_constant_override("separation", 2)
		for label in ["All", "Relics", "Materials"]:
			var b: Button = Button.new()
			b.text = label
			b.toggle_mode = true
			b.button_group = network_grp
			b.add_theme_stylebox_override("normal", seg_normal.duplicate())
			b.add_theme_stylebox_override("hover", seg_pressed.duplicate())
			b.add_theme_stylebox_override("pressed", seg_pressed.duplicate())
			var key: String = "all" if label == "All" else ("relics" if label == "Relics" else "materials")
			b.pressed.connect(_on_network_filter.bind(key))
			h.add_child(b)
			if label == "All": b.button_pressed = true
		network_section.add_child(h)
		network_section.move_child(h, 1)

func _on_convoy_filter(key: String) -> void:
	convoy_filter = key
	_populate_convoy()

func _on_network_filter(key: String) -> void:
	network_filter = key
	_populate_network()

## True if item is stackable (materials, consumables, keys). Uses type checks so subclasses and loaded .tres are recognized.
func _is_stackable(item: Variant) -> bool:
	if item == null: return false
	return item is MaterialData or item is ConsumableData or item is ChestKeyData

## Count how many of the same item (path + name) exist in global_inventory.
func _get_convoy_stack_count(item: Resource) -> int:
	var path: String = item.resource_path if item.resource_path else str(item.get_meta("original_path", ""))
	var name_key: String = str(item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name"))
	var n: int = 0
	for inv_item in CampaignManager.global_inventory:
		if inv_item == null: continue
		var p: String = inv_item.resource_path if inv_item.resource_path else str(inv_item.get_meta("original_path", ""))
		var k: String = str(inv_item.get("weapon_name") if inv_item.get("weapon_name") != null else inv_item.get("item_name"))
		if p == path and k == name_key: n += 1
	return n

## Indices in global_inventory that hold the same item (path + name), descending for safe remove_at.
func _get_convoy_indices_for_item(item: Resource) -> Array:
	var path: String = item.resource_path if item.resource_path else str(item.get_meta("original_path", ""))
	var name_key: String = str(item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name"))
	var idx: Array = []
	for i in range(CampaignManager.global_inventory.size()):
		var inv_item = CampaignManager.global_inventory[i]
		if inv_item == null: continue
		var p: String = inv_item.resource_path if inv_item.resource_path else str(inv_item.get_meta("original_path", ""))
		var k: String = str(inv_item.get("weapon_name") if inv_item.get("weapon_name") != null else inv_item.get("item_name"))
		if p == path and k == name_key: idx.append(i)
	idx.sort()
	idx.reverse()
	return idx

func _build_qty_container() -> void:
	var details: Control = item_desc.get_parent()
	if details == null: return
	_qty_container = HBoxContainer.new()
	_qty_container.name = "QtyContainer"
	_qty_container.add_theme_constant_override("separation", 6)
	var btn_m10: Button = Button.new()
	btn_m10.text = "-10"
	btn_m10.pressed.connect(_on_qty_adjust.bind(-10))
	var btn_m1: Button = Button.new()
	btn_m1.text = "-1"
	btn_m1.pressed.connect(_on_qty_adjust.bind(-1))
	_qty_label = Label.new()
	_qty_label.text = "1"
	_qty_label.custom_minimum_size = Vector2(36, 0)
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var btn_p1: Button = Button.new()
	btn_p1.text = "+1"
	btn_p1.pressed.connect(_on_qty_adjust.bind(1))
	var btn_p10: Button = Button.new()
	btn_p10.text = "+10"
	btn_p10.pressed.connect(_on_qty_adjust.bind(10))
	var btn_max: Button = Button.new()
	btn_max.text = "Max"
	btn_max.pressed.connect(_on_qty_max)
	_qty_container.add_child(btn_m10)
	_qty_container.add_child(btn_m1)
	_qty_container.add_child(_qty_label)
	_qty_container.add_child(btn_p1)
	_qty_container.add_child(btn_p10)
	_qty_container.add_child(btn_max)
	details.add_child(_qty_container)
	details.move_child(_qty_container, action_btn.get_index())
	_qty_container.visible = false

func _on_qty_adjust(delta: int) -> void:
	selected_transfer_qty = clampi(selected_transfer_qty + delta, 1, _max_transfer_qty)
	_update_transfer_display()

func _on_qty_max() -> void:
	selected_transfer_qty = _max_transfer_qty
	_update_transfer_display()

## Updates qty label and action button total (cost/reward) from selected_transfer_qty.
func _update_transfer_display() -> void:
	if _qty_label != null:
		_qty_label.text = str(selected_transfer_qty)
	if selected_meta.is_empty() or _qty_container == null: return
	var item = selected_meta.get("item")
	if item == null: return
	var base_cost = item.get("gold_cost") if item.get("gold_cost") != null else 10
	if selected_meta["type"] == "convoy":
		var reward = max(1, int(base_cost * 0.25)) * selected_transfer_qty
		action_btn.text = "Release to Circulation\n(+ " + str(reward) + " G)"
	elif selected_meta["type"] == "network":
		var cost = max(1, int(base_cost * 0.50)) * selected_transfer_qty
		action_btn.text = "Pull From the Chain\n(- " + str(cost) + " G)"

# Purpose: Opens the UI, triggers animations, and loads network data.
func open_network() -> void:
	self.visible = true
	main_panel.scale = Vector2(0.8, 0.8)
	main_panel.modulate.a = 0.0
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(main_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(main_panel, "modulate:a", 1.0, 0.2)
	
	_clear_details()
	var convoy_lbl: Label = get_node_or_null("MainPanel/LayoutHBox/ConvoySection/Label")
	var network_lbl: Label = get_node_or_null("MainPanel/LayoutHBox/NetworkSection/Label")
	if convoy_lbl != null:
		convoy_lbl.text = "Your Convoy"
		convoy_lbl.add_theme_font_size_override("font_size", 18)
		convoy_lbl.add_theme_color_override("font_color", Color(0.7, 0.78, 0.88))
	if network_lbl != null:
		network_lbl.text = "Circulating Salvage"
		network_lbl.add_theme_font_size_override("font_size", 18)
		network_lbl.add_theme_color_override("font_color", Color(0.82, 0.78, 0.65))
	_populate_convoy()
	# Fetch network items if the stock is empty
	if ScavengerManager.current_scavenger_stock.is_empty():
		_on_refresh_pressed()
	else:
		_populate_network()

# Purpose: Closes the UI and clears references.
func close_network() -> void:
	var tw = create_tween().set_parallel(true)
	tw.tween_property(main_panel, "scale", Vector2(0.9, 0.9), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(main_panel, "modulate:a", 0.0, 0.2)
	await tw.finished
	self.visible = false

func _clear_details() -> void:
	selected_meta.clear()
	selected_transfer_qty = 1
	_max_transfer_qty = 1
	if _qty_container != null:
		_qty_container.visible = false
	_clear_selection_highlight()
	preview_icon.texture = null
	donor_label.text = ""
	donor_label.remove_theme_color_override("font_color")
	item_desc.text = "[center][color=#6a6a6e]Select an item from your convoy or the circulating salvage. The chain remembers what passes through.[/color][/center]"
	action_btn.text = "---"
	action_btn.disabled = true
	_update_status_line(not ScavengerManager.current_scavenger_stock.is_empty(), false)

## Returns one line from the given array at random for rotating atmosphere.
func _pick_flavor(lines: Array) -> String:
	if lines.is_empty(): return ""
	return str(lines[randi() % lines.size()])

## Applies grim salvage-market frame to a tile. is_convoy: left side; is_relic: unique (non-stackable) for border accent.
func _apply_tile_style(btn: Button, is_convoy: bool, is_relic: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_CONVOY if is_convoy else BG_NETWORK
	sb.set_border_width_all(2)
	sb.border_color = BORDER_RELIC if is_relic else BORDER_MATERIAL
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", sb)
	btn.set_meta("salvage_convoy", is_convoy)
	btn.set_meta("salvage_relic", is_relic)

# Purpose: Builds the left-side grid from the player's global inventory. Groups stackables into one tile per stack. Respects convoy_filter.
func _populate_convoy() -> void:
	for child in convoy_grid.get_children():
		child.queue_free()

	var path_to_group: Dictionary = {}
	for i in range(CampaignManager.global_inventory.size()):
		var item = CampaignManager.global_inventory[i]
		if item == null: continue
		if item.get_meta("is_locked", false) == true: continue
		if convoy_filter == "relics" and _is_stackable(item): continue
		if convoy_filter == "materials" and not _is_stackable(item): continue
		var path: String = item.resource_path if item.resource_path else str(item.get_meta("original_path", ""))
		var name_key: String = str(item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name"))
		var key: String = path + "|" + name_key
		if not path_to_group.has(key):
			path_to_group[key] = {"item": item, "count": 0, "indices": []}
		path_to_group[key]["count"] += 1
		path_to_group[key]["indices"].append(i)

	for key in path_to_group:
		var group: Dictionary = path_to_group[key]
		var item: Resource = group["item"]
		var count: int = group["count"]
		group["indices"].sort()
		group["indices"].reverse()
		var is_relic: bool = not _is_stackable(item)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(92, 92)
		btn.icon = item.get("icon")
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_apply_tile_style(btn, true, is_relic)
		var cat_lbl = Label.new()
		cat_lbl.text = "Relic" if is_relic else "Material"
		cat_lbl.add_theme_font_size_override("font_size", 9)
		cat_lbl.add_theme_color_override("font_color", Color(0.5, 0.52, 0.55))
		cat_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		cat_lbl.offset_left = 6
		cat_lbl.offset_top = 4
		btn.add_child(cat_lbl)
		if count > 1:
			var qty_badge = Label.new()
			qty_badge.text = "x" + str(count)
			qty_badge.add_theme_font_size_override("font_size", 16)
			qty_badge.add_theme_color_override("font_color", Color.WHITE)
			qty_badge.add_theme_constant_override("outline_size", 5)
			qty_badge.add_theme_color_override("font_outline_color", Color.BLACK)
			btn.add_child(qty_badge)
			qty_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			qty_badge.offset_right = -6
			qty_badge.offset_top = 2
		var i_name: String = str(item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name"))
		var short_name: String = i_name if i_name.length() <= 9 else i_name.left(8) + "…"
		var name_lbl = Label.new()
		name_lbl.text = short_name
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		name_lbl.offset_bottom = -4
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.add_child(name_lbl)
		var meta: Dictionary = {"type": "convoy", "item": item, "count": count, "indices": group["indices"]}
		btn.pressed.connect(_on_item_clicked.bind(btn, meta))
		convoy_grid.add_child(btn)

# Purpose: Builds the right-side grid from the downloaded network stock.
func _populate_network() -> void:
	for child in network_grid.get_children():
		child.queue_free()

	if ScavengerManager.current_scavenger_stock.is_empty():
		var status_lbl = Label.new()
		var status: String = ScavengerManager.last_fetch_status
		if status == "error":
			status_lbl.text = _pick_flavor(FAILED_LINES) + "\n" + "The request returned nothing usable."
		else:
			status_lbl.text = _pick_flavor(EMPTY_LINES)
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status_lbl.add_theme_font_size_override("font_size", 16)
		status_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status_lbl.custom_minimum_size = Vector2(180, 60)
		network_grid.add_child(status_lbl)
		return

	for entry in ScavengerManager.current_scavenger_stock:
		var item = entry["item"]
		if network_filter == "relics" and _is_stackable(item): continue
		if network_filter == "materials" and not _is_stackable(item): continue
		var is_relic: bool = not _is_stackable(item)
		var base_cost = item.get("gold_cost") if item.get("gold_cost") != null else 10
		var cost = max(1, int(base_cost * 0.50))
		var i_name: String = str(item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name"))
		var short_name: String = i_name if i_name.length() <= 9 else i_name.left(8) + "…"

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(92, 92)
		btn.icon = item.get("icon")
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.modulate = NETWORK_TILE_TINT
		_apply_tile_style(btn, false, is_relic)
		var cat_lbl = Label.new()
		cat_lbl.text = "Relic" if is_relic else "Material"
		cat_lbl.add_theme_font_size_override("font_size", 9)
		cat_lbl.add_theme_color_override("font_color", Color(0.5, 0.52, 0.5))
		cat_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		cat_lbl.offset_left = 6
		cat_lbl.offset_top = 4
		btn.add_child(cat_lbl)
		var name_lbl = Label.new()
		name_lbl.text = short_name
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
		name_lbl.offset_top = 20
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.add_child(name_lbl)
		var cost_lbl = Label.new()
		cost_lbl.text = str(cost) + " G"
		cost_lbl.add_theme_font_size_override("font_size", 12)
		cost_lbl.add_theme_color_override("font_color", COST_COLOR_SALVAGE)
		cost_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		cost_lbl.offset_bottom = -6
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.add_child(cost_lbl)
		var qty: int = int(entry.get("quantity", 1))
		if qty > 1:
			var qty_badge = Label.new()
			qty_badge.text = "x" + str(qty)
			qty_badge.add_theme_font_size_override("font_size", 16)
			qty_badge.add_theme_color_override("font_color", Color.WHITE)
			qty_badge.add_theme_constant_override("outline_size", 5)
			qty_badge.add_theme_color_override("font_outline_color", Color.BLACK)
			btn.add_child(qty_badge)
			qty_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			qty_badge.offset_right = -6
			qty_badge.offset_top = 2
		var meta = {"type": "network", "entry": entry, "item": item}
		btn.pressed.connect(_on_item_clicked.bind(btn, meta))
		network_grid.add_child(btn)

func _clear_selection_highlight() -> void:
	if _last_selected_btn == null: return
	if _last_selected_was_convoy:
		_last_selected_btn.modulate = Color.WHITE
	else:
		_last_selected_btn.modulate = NETWORK_TILE_TINT
	_last_selected_btn.scale = Vector2.ONE
	var is_convoy: bool = _last_selected_btn.get_meta("salvage_convoy", true)
	var is_relic: bool = _last_selected_btn.get_meta("salvage_relic", false)
	_apply_tile_style(_last_selected_btn, is_convoy, is_relic)
	_last_selected_btn = null

func _on_item_clicked(btn: Button, meta: Dictionary) -> void:
	if select_sound.stream != null: select_sound.play()
	_clear_selection_highlight()
	_last_selected_btn = btn
	_last_selected_was_convoy = (meta["type"] == "convoy")
	if _last_selected_was_convoy:
		btn.modulate = SELECT_TINT_CONVOY
	else:
		btn.modulate = SELECT_TINT_NETWORK
	btn.scale = Vector2(1.06, 1.06)
	var sel_border := StyleBoxFlat.new()
	sel_border.bg_color = Color(0.08, 0.08, 0.1)
	sel_border.set_border_width_all(3)
	sel_border.border_color = BORDER_SELECTED
	sel_border.set_corner_radius_all(6)
	sel_border.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", sel_border)

	selected_meta = meta
	var item = meta["item"]
	preview_icon.texture = item.get("icon")

	var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
	var rarity = item.get("rarity") if item.get("rarity") != null else "Common"
	var base_cost = item.get("gold_cost") if item.get("gold_cost") != null else 10

	var category: String = "Relic" if not _is_stackable(item) else "Material"
	item_desc.text = "[center][b]" + str(i_name) + "[/b]\n[color=#8a8a8a]" + str(rarity) + "  ·  " + category + "[/color][/center]\n\n"
	if item.get("description") != null:
		item_desc.text += "[color=#a0a0a0][i]\"" + str(item.description) + "\"[/i][/color]\n\n"
	var rune_scav: String = WeaponRuneDisplayHelpers.format_runes_bbcode_for_item_variant(item)
	if rune_scav != "":
		item_desc.text += rune_scav + "\n\n"
	if meta["type"] == "convoy":
		var owned: int = _get_convoy_stack_count(item)
		var per_unit: int = max(1, int(base_cost * 0.25))
		var total: int = per_unit * selected_transfer_qty
		item_desc.text += "[color=#7a7a7a]Owned: %d  ·  Releasing: %d\n%d G each  →  %d G total[/color]\n\n[color=#666666]Release into circulation. The chain will carry it.[/color]" % [owned, selected_transfer_qty, per_unit, total]
	else:
		var in_net: int = int(meta["entry"].get("quantity", 1))
		var per_unit: int = max(1, int(base_cost * 0.50))
		var total: int = per_unit * selected_transfer_qty
		item_desc.text += "[color=#7a7a7a]Available: %d  ·  Recovering: %d\n%d G each  →  %d G total[/color]\n\n[color=#666666]Recovered through the network. Passed through unknown hands.[/color]" % [in_net, selected_transfer_qty, per_unit, total]

	action_btn.disabled = false

	if meta["type"] == "convoy":
		donor_label.text = "Your salvage"
		donor_label.add_theme_color_override("font_color", Color(0.45, 0.82, 0.95))
		_max_transfer_qty = _get_convoy_stack_count(item) if _is_stackable(item) else 1
		selected_transfer_qty = clampi(selected_transfer_qty, 1, _max_transfer_qty)
		if _qty_container != null:
			_qty_container.visible = _is_stackable(item)
		_update_transfer_display()
		action_btn.modulate = Color(0.5, 0.85, 0.55)
	elif meta["type"] == "network":
		var donor_name: String = str(meta["entry"].get("donor", "Origin obscured"))
		if donor_name.to_lower() == "origin obscured":
			donor_label.text = "Source obscured"
		else:
			donor_label.text = "Passed along by: " + donor_name
		donor_label.add_theme_color_override("font_color", Color(0.9, 0.72, 0.35))
		_max_transfer_qty = int(meta["entry"].get("quantity", 1))
		if _max_transfer_qty <= 0: _max_transfer_qty = 1
		selected_transfer_qty = clampi(selected_transfer_qty, 1, _max_transfer_qty)
		if _qty_container != null:
			_qty_container.visible = _is_stackable(item)
		_update_transfer_display()
		action_btn.modulate = Color(0.88, 0.78, 0.45)
	if _status_label != null:
		_status_label.text = ""
# Purpose: Executes the transaction (donate or claim). Uses custom_avatar for donor display name when available.
func _on_action_btn_pressed() -> void:
	if selected_meta.is_empty(): return

	var item = selected_meta["item"]
	var player_name: String = CampaignManager.resolve_player_display_name(CampaignManager.player_profile_display_override, "")
	if player_name.is_empty() and CampaignManager.player_roster.size() > 0:
		player_name = str(CampaignManager.player_roster[0].get("unit_name", "Hero"))
	if player_name.is_empty():
		player_name = "Unknown Hero"

	var base_cost = item.get("gold_cost") if item.get("gold_cost") != null else 10

	if selected_meta["type"] == "convoy":
		if not CampaignManager.can_persist_scavenger():
			_play_feedback_animation("Save your game first to donate.", true)
			return
		var qty: int = clampi(selected_transfer_qty, 1, _max_transfer_qty)
		var indices: Array = _get_convoy_indices_for_item(item)
		for i in range(min(qty, indices.size())):
			CampaignManager.global_inventory.remove_at(indices[i])
		var reward: int = ScavengerManager.donate_item(item, player_name, qty)
		CampaignManager.global_gold += reward
		_play_feedback_animation("Released into circulation." if qty <= 1 else "Bulk lot passed into the chain.", true, qty > 1)
	elif selected_meta["type"] == "network":
		var cost_per: int = max(1, int(base_cost * 0.50))
		var qty: int = clampi(selected_transfer_qty, 1, _max_transfer_qty)
		var cost: int = cost_per * qty
		if CampaignManager.global_gold >= cost:
			if not CampaignManager.can_persist_scavenger():
				_play_feedback_animation("Save your game first to recover items.", false)
				return
			CampaignManager.global_gold -= cost
			for _i in range(qty):
				var new_item: Resource = CampaignManager.make_unique_item(item)
				if new_item != null and (new_item.resource_path != "" or new_item.has_meta("original_path")):
					CampaignManager.global_inventory.append(new_item)
				elif new_item != null and item.has_meta("original_path"):
					new_item.set_meta("original_path", item.get_meta("original_path"))
					CampaignManager.global_inventory.append(new_item)
			var score_id: String = selected_meta["entry"]["score_id"]
			CampaignManager.record_scavenger_claim(score_id, qty)
			if DEBUG_SCAVENGER:
				push_warning("Scavenger claim: %s qty %d" % [score_id, qty])
			ScavengerManager.reduce_network_entry_quantity(score_id, qty)
			_play_feedback_animation("Pulled from the salvage chain." if qty <= 1 else "Bulk lot recovered.", false)
		else:
			action_btn.text = "Not enough gold"
			action_btn.modulate = Color.RED
			var tw = create_tween()
			tw.tween_property(action_btn, "position:x", action_btn.position.x + 5, 0.05)
			tw.tween_property(action_btn, "position:x", action_btn.position.x - 5, 0.05)
			tw.tween_property(action_btn, "position:x", action_btn.position.x, 0.05)
			return

	if transaction_sound.stream != null: transaction_sound.play()
	# Persist inventory, gold, and scavenger claim history immediately to prevent quit/reload duplication.
	CampaignManager.save_current_progress()
	if DEBUG_SCAVENGER:
		push_warning("Scavenger: autosave after transaction")
	_clear_details()
	_populate_convoy()
	_populate_network()
	
func _on_refresh_pressed() -> void:
	refresh_btn.disabled = true
	refresh_btn.text = _pick_flavor(SEARCHING_LINES)

	for child in network_grid.get_children():
		child.queue_free()
	var searching_lbl = Label.new()
	searching_lbl.text = _pick_flavor(SEARCHING_LINES)
	searching_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	searching_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	network_grid.add_child(searching_lbl)

	await ScavengerManager.fetch_network_items(6)
	refresh_btn.text = "Search the salvage routes"
	refresh_btn.disabled = false
	_populate_network()
	_clear_details()
	_update_status_line(not ScavengerManager.current_scavenger_stock.is_empty(), false)

## Shows a short full-panel feedback message. is_donate: green tint (give) vs gold (recover). is_bulk: slightly stronger presentation.
func _play_feedback_animation(msg_text: String, is_donate: bool, is_bulk: bool = false) -> void:
	var flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.88, 0.98, 0.9) if is_donate else Color(0.98, 0.95, 0.85)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var font_sz: int = 52 if is_bulk else 48
	var lbl = Label.new()
	lbl.text = msg_text
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", Color(0.15, 0.6, 0.28) if is_donate else Color(0.7, 0.5, 0.12))
	lbl.add_theme_constant_override("outline_size", 12)
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.position.y = (size.y / 2.0) - 80
	add_child(lbl)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(flash, "modulate:a", 0.0, 0.4)
	tw.tween_property(lbl, "position:y", lbl.position.y - 50, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.75)
	tw.chain().tween_callback(flash.queue_free)
	tw.chain().tween_callback(lbl.queue_free)
