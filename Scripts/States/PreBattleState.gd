# PreBattleState.gd
# Game state for the pre-battle deployment phase: place units on valid slots, build barricades/fortresses,
# toggle unit roster vs build menu, ghost previews. Exits when player starts battle.
# Entry: enter(battlefield). Exit: exit(). Input: handle_input. Update: ghost preview under cursor.

extends GameState
class_name PreBattleState

enum DeployMode { UNIT, BUILD }

const MAX_DEPLOYMENT_CAP: int = 6
const ROSTER_BOND_ROW_HEIGHT: int = 56
const BENCH_OFFSCREEN_XY: float = -1000.0

var current_mode: DeployMode = DeployMode.UNIT
var selected_unit: Node2D = null
var active_structure: Dictionary = {}
var valid_deployment_slots: Array[Vector2i] = []
var max_deployment: int = 6

var roster_panel: Panel
var roster_list: ItemList
var count_label: Label
var build_btn: Button
var bond_icons_strip: HBoxContainer
var roster_bond_rows: VBoxContainer
var _roster_selected_unit: Node2D = null

var ghost_sprite: Sprite2D
var ghost_offset: Vector2 = Vector2.ZERO

# --- Helpers: battlefield geometry and counts ---
func _cell_size() -> Vector2i:
	if battlefield == null:
		return Vector2i(64, 64)
	var cs = battlefield.get("CELL_SIZE")
	return Vector2i(cs) if cs != null else Vector2i(64, 64)

func _grid_to_world(pos: Vector2i) -> Vector2:
	var cs = _cell_size()
	return Vector2(pos.x * cs.x, pos.y * cs.y)

func _get_deployed_count() -> int:
	if battlefield == null or battlefield.get("player_container") == null:
		return 0
	var n := 0
	for u in battlefield.player_container.get_children():
		if u.visible:
			n += 1
	return n

func _find_first_empty_slot() -> Vector2i:
	for slot in valid_deployment_slots:
		if battlefield.get_unit_at(slot) == null and not _get_barricade(slot):
			return slot
	return Vector2i(-1, -1)

# --- Lifecycle ---
func enter(p_battlefield: Node2D) -> void:
	super.enter(p_battlefield)
	selected_unit = null
	active_structure = {}
	current_mode = DeployMode.UNIT
	valid_deployment_slots.clear()

	var zones_container = battlefield.get_node_or_null("DeploymentZones")
	if zones_container:
		var cs = _cell_size()
		for marker in zones_container.get_children():
			var gx = int(marker.global_position.x / float(cs.x))
			var gy = int(marker.global_position.y / float(cs.y))
			valid_deployment_slots.append(Vector2i(gx, gy))

	max_deployment = mini(MAX_DEPLOYMENT_CAP, valid_deployment_slots.size())

	var start_btn = battlefield.get_node_or_null("UI/StartBattleButton")
	if start_btn:
		start_btn.visible = true

	roster_panel = battlefield.get_node_or_null("UI/RosterPanel")
	if roster_panel:
		roster_list = roster_panel.get_node_or_null("RosterList")
		count_label = roster_panel.get_node_or_null("DeployCountLabel")
		build_btn = roster_panel.get_node_or_null("BuildButton")
		if roster_list:
			roster_panel.visible = true
			if not roster_list.item_selected.is_connected(_on_list_item_selected):
				roster_list.item_selected.connect(_on_list_item_selected)
			if build_btn and not build_btn.pressed.is_connected(_on_build_btn_pressed):
				build_btn.pressed.connect(_on_build_btn_pressed)
		_ensure_bond_icons_strip()
		_ensure_roster_bond_rows()
		_refresh_ui_list()

	ghost_sprite = Sprite2D.new()
	ghost_sprite.modulate = Color(1.0, 1.0, 1.0, 0.6)
	ghost_sprite.z_index = 100
	ghost_sprite.visible = false
	battlefield.add_child(ghost_sprite)
	battlefield.queue_redraw()

func exit() -> void:
	if selected_unit:
		selected_unit.set_selected_glow(false)
	selected_unit = null
	var start_btn = battlefield.get_node_or_null("UI/StartBattleButton")
	if start_btn:
		start_btn.visible = false
	if roster_panel:
		roster_panel.visible = false
	if is_instance_valid(ghost_sprite):
		ghost_sprite.queue_free()
	battlefield.queue_redraw()

func update(_delta: float) -> void:
	if not is_instance_valid(ghost_sprite):
		return
	var grid_pos = battlefield.cursor_grid_pos
	var world_pos := _grid_to_world(grid_pos)
	ghost_sprite.visible = false

	if not valid_deployment_slots.has(grid_pos):
		return

	if current_mode == DeployMode.BUILD and not active_structure.is_empty():
		if active_structure.get("count", 0) > 0 and _can_build_here(grid_pos, active_structure.get("type", "")):
			ghost_sprite.position = world_pos + ghost_offset
			ghost_sprite.modulate = Color(0.2, 1.0, 0.2, 0.7)
			ghost_sprite.visible = true
	elif current_mode == DeployMode.UNIT and selected_unit != null:
		var occupant = battlefield.get_unit_at(grid_pos)
		if occupant != selected_unit:
			var spr = selected_unit.get_node_or_null("Sprite")
			if spr == null:
				spr = selected_unit.get_node_or_null("Sprite2D")
			if spr and spr.texture:
				ghost_sprite.texture = spr.texture
				ghost_sprite.position = world_pos + spr.position
				ghost_sprite.modulate = Color(1.0, 1.0, 1.0, 0.6)
				ghost_sprite.visible = true

func _on_build_btn_pressed() -> void:
	battlefield.play_ui_sfx(battlefield.UISfx.MOVE_OK)
	_deselect()
	current_mode = DeployMode.BUILD if current_mode != DeployMode.BUILD else DeployMode.UNIT
	_refresh_ui_list()

# --- Roster UI refresh: build menu vs unit list, tooltips, bond rows ---
func _refresh_ui_list() -> void:
	if roster_list == null:
		return
	roster_list.clear()

	if current_mode == DeployMode.BUILD:
		if roster_bond_rows != null:
			roster_bond_rows.visible = false
		if count_label:
			count_label.text = "- ENGINEERING -"
		if build_btn:
			build_btn.text = "[ RETURN TO UNITS ]"
			build_btn.modulate = Color(1.0, 0.8, 0.2)
		for struct in CampaignManager.player_structures:
			if struct.get("count", 0) > 0:
				var text = str(struct.get("name", "?")) + " (x" + str(struct["count"]) + ")"
				var idx = roster_list.add_item(text, null)
				roster_list.set_item_metadata(idx, {"is_structure": true, "data": struct})
				roster_list.set_item_custom_fg_color(idx, Color.GOLD)
		return

	if build_btn:
		build_btn.text = "Build Defenses"
		build_btn.modulate = Color.WHITE
	if battlefield.player_container == null:
		return

	var candidate_ids: Array = []
	for u in battlefield.player_container.get_children():
		candidate_ids.append(battlefield.get_relationship_id(u))

	var mock_coop_roster_tags: bool = battlefield.is_mock_coop_unit_ownership_active()

	var deployed_count := 0
	for u in battlefield.player_container.get_children():
		var is_deployed: bool = u.visible
		if is_deployed:
			deployed_count += 1
		var u_name = u.get("unit_name")
		var text := ("[Deployed] " if is_deployed else "[Benched] ")
		if mock_coop_roster_tags:
			var own_key: String = battlefield.get_mock_coop_unit_owner_for_unit(u)
			if own_key == "remote":
				text += "[PARTNER] "
			elif own_key == "local":
				text += "[YOURS] "
		text += (str(u_name) if u_name != null else "?")
		if u.get("is_custom_avatar") == true:
			text += " (Leader)"
		var icon = null
		if u.get("data") != null:
			var d = u.get("data")
			if d.get("battle_sprite") != null:
				icon = d.get("battle_sprite")
		var idx = roster_list.add_item(text, icon)
		roster_list.set_item_metadata(idx, {"is_structure": false, "data": u})
		roster_list.set_item_custom_fg_color(idx, Color(0.2, 1.0, 0.2) if is_deployed else Color(0.6, 0.6, 0.6))
		var unit_id: String = battlefield.get_relationship_id(u)
		var others: Array = []
		for id in candidate_ids:
			if id != unit_id:
				others.append(id)
		var entries: Array = CampaignManager.get_top_relationship_entries_for_unit(unit_id, others, 5)
		var tooltip_lines: Array = []
		if mock_coop_roster_tags:
			var own_tip: String = battlefield.get_mock_coop_unit_owner_for_unit(u)
			if own_tip == "remote":
				tooltip_lines.append("Mock co-op: Partner detachment (locked)")
			elif own_tip == "local":
				tooltip_lines.append("Mock co-op: Your detachment (locked)")
		for e in entries:
			tooltip_lines.append(CampaignManager.format_relationship_tooltip(e))
		roster_list.set_item_tooltip(idx, "\n".join(tooltip_lines) if not tooltip_lines.is_empty() else "No bonds with current roster.")

	if count_label:
		count_label.text = "Deployed: %d / %d" % [deployed_count, max_deployment]
	_build_roster_bond_rows()
	_update_bond_icons_strip(_roster_selected_unit)

func _ensure_bond_icons_strip() -> void:
	if bond_icons_strip != null and is_instance_valid(bond_icons_strip):
		return
	if roster_panel == null:
		return
	bond_icons_strip = HBoxContainer.new()
	bond_icons_strip.name = "BondIconsStrip"
	bond_icons_strip.add_theme_constant_override("separation", 6)
	bond_icons_strip.visible = false
	roster_panel.add_child(bond_icons_strip)

func _ensure_roster_bond_rows() -> void:
	if roster_bond_rows != null and is_instance_valid(roster_bond_rows):
		return
	if roster_panel == null:
		return
	roster_bond_rows = VBoxContainer.new()
	roster_bond_rows.name = "RosterBondRows"
	roster_bond_rows.add_theme_constant_override("separation", 2)
	roster_bond_rows.visible = true
	roster_bond_rows.set_anchors_preset(Control.PRESET_TOP_LEFT)
	roster_bond_rows.offset_left = 8
	roster_bond_rows.offset_top = 35
	roster_bond_rows.offset_right = 72
	roster_bond_rows.offset_bottom = 605
	roster_panel.add_child(roster_bond_rows)
	roster_panel.move_child(roster_bond_rows, 0)

func _build_roster_bond_rows() -> void:
	if roster_bond_rows == null:
		return
	for c in roster_bond_rows.get_children():
		c.queue_free()
	roster_bond_rows.visible = true
	var candidate_ids: Array = []
	for u in battlefield.player_container.get_children():
		candidate_ids.append(battlefield.get_relationship_id(u))
	for u in battlefield.player_container.get_children():
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, ROSTER_BOND_ROW_HEIGHT)
		row.add_theme_constant_override("separation", 4)
		var unit_id: String = battlefield.get_relationship_id(u)
		var others: Array = []
		for id in candidate_ids:
			if id != unit_id:
				others.append(id)
		var entries: Array = CampaignManager.get_top_relationship_entries_for_unit(unit_id, others, 3)
		for entry in entries:
			var stat: String = entry.get("stat", "")
			var col: Color = CampaignManager.get_relationship_type_color(stat)
			var tip: String = CampaignManager.format_relationship_tooltip(entry)
			var rect := ColorRect.new()
			rect.custom_minimum_size = Vector2(16, 16)
			rect.size = Vector2(16, 16)
			rect.color = col
			rect.tooltip_text = tip
			rect.mouse_filter = Control.MOUSE_FILTER_STOP
			row.add_child(rect)
		roster_bond_rows.add_child(row)

func _update_bond_icons_strip(unit: Node2D) -> void:
	if bond_icons_strip == null:
		return
	for c in bond_icons_strip.get_children():
		c.queue_free()
	bond_icons_strip.visible = false
	if unit == null or not is_instance_valid(unit):
		return
	var unit_id: String = battlefield.get_relationship_id(unit)
	var candidate_ids: Array = []
	for u in battlefield.player_container.get_children():
		if u != unit:
			candidate_ids.append(battlefield.get_relationship_id(u))
	var entries: Array = CampaignManager.get_top_relationship_entries_for_unit(unit_id, candidate_ids, 3)
	if entries.is_empty():
		return
	bond_icons_strip.visible = true
	for entry in entries:
		var stat: String = entry.get("stat", "")
		var col: Color = CampaignManager.get_relationship_type_color(stat)
		var tip: String = CampaignManager.format_relationship_tooltip(entry)
		var rect := ColorRect.new()
		rect.custom_minimum_size = Vector2(20, 20)
		rect.size = Vector2(20, 20)
		rect.color = col
		rect.tooltip_text = tip
		rect.mouse_filter = Control.MOUSE_FILTER_STOP
		bond_icons_strip.add_child(rect)

func _on_list_item_selected(index: int) -> void:
	var meta = roster_list.get_item_metadata(index)
	if meta == null:
		return

	if meta.get("is_structure", false):
		_deselect()
		_roster_selected_unit = null
		active_structure = meta.get("data", {})
		battlefield.play_ui_sfx(battlefield.UISfx.MOVE_OK)
		var scene_path = active_structure.get("scene_path")
		if scene_path:
			var scene_pack = load(scene_path) as PackedScene
			if scene_pack:
				var temp = scene_pack.instantiate()
				var spr: Sprite2D = null
				for child in temp.get_children():
					if child is Sprite2D:
						spr = child
						break
				if spr == null and temp is Sprite2D:
					spr = temp
				if spr and spr.texture:
					ghost_sprite.texture = spr.texture
					ghost_sprite.scale = spr.scale
					ghost_sprite.centered = spr.centered
					ghost_sprite.offset = spr.offset
					ghost_offset = spr.position
				temp.free()
		return

	active_structure = {}
	var unit = meta.get("data")
	if unit == null:
		return
	if battlefield.is_local_player_command_blocked_for_mock_coop_unit(unit):
		battlefield.notify_mock_coop_remote_command_blocked(unit)
		return
	_roster_selected_unit = unit
	if unit.get("is_custom_avatar") == true and unit.visible:
		battlefield.play_ui_sfx(battlefield.UISfx.INVALID)
		return

	battlefield.play_ui_sfx(battlefield.UISfx.MOVE_OK)
	if unit.visible:
		unit.visible = false
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		unit.position = Vector2(BENCH_OFFSCREEN_XY, BENCH_OFFSCREEN_XY)
		if selected_unit == unit:
			_deselect()
	else:
		if _get_deployed_count() >= max_deployment:
			battlefield.play_ui_sfx(battlefield.UISfx.INVALID)
		else:
			var slot := _find_first_empty_slot()
			if slot.x >= 0:
				unit.position = _grid_to_world(slot)
				unit.visible = true
				unit.process_mode = Node.PROCESS_MODE_INHERIT
	roster_list.deselect_all()
	_refresh_ui_list()
	battlefield.rebuild_grid()

func handle_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	var pos: Vector2i = battlefield.cursor_grid_pos
	if not valid_deployment_slots.has(pos):
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if current_mode == DeployMode.BUILD and _try_pickup_structure(pos):
			return
		if current_mode == DeployMode.BUILD and not active_structure.is_empty():
			var type_str = active_structure.get("type", "")
			if active_structure.get("count", 0) > 0 and _can_build_here(pos, type_str):
				var scene_path = active_structure.get("scene_path")
				if scene_path:
					var packed = load(scene_path) as PackedScene
					if packed:
						var new_struct = packed.instantiate()
						new_struct.set_meta("structure_name", active_structure.get("name", ""))
						if type_str == "barricade" or type_str == "spawner":
							battlefield.destructibles_container.add_child(new_struct)
						else:
							var fortresses = battlefield.get_node_or_null("Fortresses")
							if fortresses:
								fortresses.add_child(new_struct)
						new_struct.position = _grid_to_world(pos)
						active_structure["count"] = active_structure.get("count", 1) - 1
						battlefield.play_ui_sfx(battlefield.UISfx.TARGET_OK)
						if active_structure.get("count", 0) <= 0:
							active_structure = {}
							roster_list.deselect_all()
						_refresh_ui_list()
						battlefield.rebuild_grid()
			else:
				battlefield.play_ui_sfx(battlefield.UISfx.INVALID)
			return

		if current_mode == DeployMode.UNIT:
			var clicked_unit = battlefield.get_unit_at(pos)
			if selected_unit == null:
				if clicked_unit != null:
					if not battlefield.try_allow_local_player_select_unit_for_command(clicked_unit):
						return
					selected_unit = clicked_unit
					selected_unit.set_selected_glow(true)
					battlefield.play_ui_sfx(battlefield.UISfx.MOVE_OK)
			else:
				if clicked_unit != null and clicked_unit != selected_unit:
					if battlefield.is_local_player_command_blocked_for_mock_coop_unit(clicked_unit):
						battlefield.notify_mock_coop_remote_command_blocked(clicked_unit)
						return
					if battlefield.is_local_player_command_blocked_for_mock_coop_unit(selected_unit):
						battlefield.notify_mock_coop_remote_command_blocked(selected_unit)
						return
					var tmp = selected_unit.global_position
					selected_unit.global_position = clicked_unit.global_position
					clicked_unit.global_position = tmp
					battlefield.play_ui_sfx(battlefield.UISfx.TARGET_OK)
				elif clicked_unit == null and _get_barricade(pos) == null:
					if battlefield.is_local_player_command_blocked_for_mock_coop_unit(selected_unit):
						battlefield.notify_mock_coop_remote_command_blocked(selected_unit)
						return
					selected_unit.global_position = _grid_to_world(pos)
					battlefield.play_ui_sfx(battlefield.UISfx.TARGET_OK)
				_deselect()
			_refresh_ui_list()
			battlefield.rebuild_grid()
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		active_structure = {}
		_deselect()
		roster_list.deselect_all()
		battlefield.play_ui_sfx(battlefield.UISfx.INVALID)

func _deselect() -> void:
	if selected_unit != null:
		selected_unit.set_selected_glow(false)
		selected_unit = null

# --- Placement / structure helpers ---
func _can_build_here(pos: Vector2i, type: String) -> bool:
	if type == "barricade" or type == "spawner":
		return battlefield.get_occupant_at(pos) == null
	if type == "fortress":
		return _get_barricade(pos) == null and _get_fortress(pos) == null
	return false

func _try_pickup_structure(pos: Vector2i) -> bool:
	var clicked_obj = _get_barricade(pos)
	if clicked_obj == null:
		clicked_obj = _get_fortress(pos)
	if clicked_obj == null or not clicked_obj.has_meta("structure_name"):
		return false
	var s_name = clicked_obj.get_meta("structure_name")
	for struct in CampaignManager.player_structures:
		if struct.get("name", "") == s_name:
			struct["count"] = struct.get("count", 0) + 1
			clicked_obj.queue_free()
			battlefield.play_ui_sfx(battlefield.UISfx.INVALID)
			_refresh_ui_list()
			battlefield.rebuild_grid()
			return true
	return false

func _get_barricade(pos: Vector2i) -> Node2D:
	var container = battlefield.get("destructibles_container")
	if container == null:
		return null
	for d in container.get_children():
		if battlefield.get_grid_pos(d) == pos and not d.is_queued_for_deletion():
			return d
	return null

func _get_fortress(pos: Vector2i) -> Node2D:
	var fc = battlefield.get_node_or_null("Fortresses")
	if fc == null:
		return null
	for f in fc.get_children():
		if battlefield.get_grid_pos(f) == pos and not f.is_queued_for_deletion():
			return f
	return null
