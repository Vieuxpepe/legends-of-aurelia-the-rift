# PreBattleState.gd
# Deployment phase: place units, build/pick structures, roster + bond UI, ghost preview.
# Roster: single-click = arm; double-click = bench/deploy; map double-click = bench; off-zone snap. Keys: Tab/[ ] cycle · Space/Enter confirm · Esc clear · Shift+X/B bench all on map · X/B bench armed · F6 zone overlay. Bond UI: RosterPanel/DeployBondPanel.
# Entry: enter(battlefield). Exit: exit(). Input: handle_input. Update: ghost under cursor.
#
# --- Upgrade / roadmap (suggested next steps) ---
# - Roster: virtualize ItemList or paginate if roster counts grow; debounce _refresh_ui_list on rapid co-op sync.
# - Rules: cache per-unit allowed slot sets when mock co-op constraints are stable; invalidate on coop_enet_sync_*.
# - Input: gamepad / keyboard grid cursor + confirm; align with BattleField tactical cursor if shared.
# - Structures: pool ghost previews (PackedScene) instead of instantiate()+free on each structure pick.
# - Multiplayer: server-authoritative checks mirroring _can_build_here / slot occupancy before applying builds.
# - UX: illegal-tile ghost (red pulse), optional deployment-zone overlay shader; audio distinction place vs swap.
# - A11y: focus neighbors for roster; bond readout panel + row tooltips.
# -------------------------------------------------------------------------------------------------------------

extends GameState
class_name PreBattleState

enum DeployMode { UNIT, BUILD }

const MAX_DEPLOYMENT_CAP: int = 6
const BENCH_OFFSCREEN_XY: float = -1000.0
## ItemList can't mix font sizes per line; custom deploy rows use RichTextLabel (see DeployRosterScroll).
const DEPLOY_ROSTER_RTL_NAME_FONT := 17
const DEPLOY_ROSTER_RTL_DETAIL_FONT := 12
const DEPLOY_ROSTER_ICON_PX := 56
const BOND_BAR_TRACK_W := 120.0
const BOND_BAR_FILL_H := 11.0
const BOND_COMPARE_VALUE_CAP := 48.0
## Sqrt scaling so low values (1–5) don't all look identical; bar length still maps to strength.
const BOND_BAR_DISPLAY_RATIO_CURVE := 0.52
const BOND_BAR_MIN_FILL_PX := 14.0
## Deployment placement ghost: match unit sprite world scale (it is not 1,1) and keep preview a bit smaller than the real sprite.
const DEPLOY_UNIT_GHOST_SCALE_MULT := 0.6
const _DEPLOY_CONTROLS_HINT_BUILD := "\nBuild — pick a structure in the list, then click the map."

var current_mode: DeployMode = DeployMode.UNIT
var selected_unit: Node2D = null
var active_structure: Dictionary = {}
var valid_deployment_slots: Array[Vector2i] = []
## O(1) tile checks for update()/input (Array.has is O(n)).
var _deployment_tile_lookup: Dictionary = {}
var max_deployment: int = 6

var roster_panel: Panel
var roster_list: ItemList
var count_label: Label
var build_btn: Button
var roster_bond_hint: Label
var roster_bond_title: Label
var roster_bond_rows: VBoxContainer
var _roster_selected_unit: Node2D = null

var ghost_sprite: Sprite2D
var ghost_offset: Vector2 = Vector2.ZERO

var deploy_roster_scroll: ScrollContainer = null
var deploy_roster_vbox: VBoxContainer = null
var _deploy_selected_row_index: int = -1
var _deploy_roster_last_click_msec: int = 0
var _deploy_roster_last_click_index: int = -1

## Read by BattleField._draw (class_name matches).
var show_deployment_zone_overlay: bool = true
var deploy_snap_highlight_cell: Vector2i = Vector2i(-1, -1)
var _deploy_hint_label: Label
var _deploy_controls_hint: Label


func _layout_deploy_controls_hint() -> void:
	if _deploy_controls_hint == null or battlefield == null:
		return
	var m: float = 14.0
	_deploy_controls_hint.position = Vector2(m, m + 4.0)
	var vp: Rect2 = battlefield.get_viewport_rect()
	var max_w: float = minf(440.0, vp.size.x * 0.42)
	_deploy_controls_hint.custom_minimum_size = Vector2(max_w, 0)
	_deploy_controls_hint.reset_size()


func _update_deploy_controls_hint_text() -> void:
	if _deploy_controls_hint == null:
		return
	var base: String = "DEPLOY CONTROLS\n"
	base += "Tab / [ ] — cycle unit   ·   Space / Enter — place tile\n"
	base += "Esc — clear armed selection   ·   X / B — bench armed unit only\n"
	base += "Shift+X / Shift+B — clear map (bench every unit on the field)\n"
	base += "F6 — zone outline   ·   Off-zone click snaps   ·   Dbl-click — bench\n"
	base += "Right-click — clear arm & roster focus\n"
	base += "Optional (Settings → Tactical View): "
	base += "Quick-fill auto-places when you arm someone and exactly ONE legal tile is free"
	if CampaignManager.battle_deploy_quick_fill:
		base += " [on]"
	else:
		base += " [off]"
	base += "; Auto-arm next selects the next benched unit after a place"
	if CampaignManager.battle_deploy_auto_arm_after_place:
		base += " [on]"
	else:
		base += " [off]"
	if current_mode == DeployMode.BUILD:
		base += _DEPLOY_CONTROLS_HINT_BUILD
	_deploy_controls_hint.text = base


func _clear_deploy_hint() -> void:
	if _deploy_hint_label != null and is_instance_valid(_deploy_hint_label):
		_deploy_hint_label.visible = false


func _show_deploy_hint(msg: String, play_invalid_sfx: bool = false) -> void:
	if msg.strip_edges().is_empty():
		_clear_deploy_hint()
		return
	if _deploy_hint_label == null:
		return
	if play_invalid_sfx and battlefield != null:
		battlefield.play_ui_sfx(battlefield.UISfx.INVALID)
	_deploy_hint_label.text = msg
	_deploy_hint_label.visible = true
	_layout_deploy_hint_label()
	if battlefield != null:
		battlefield.queue_redraw()
	## GameState is not a scene node; only battlefield has a valid SceneTree.
	var st: SceneTree = battlefield.get_tree()
	if st != null:
		st.create_timer(2.6).timeout.connect(_clear_deploy_hint, CONNECT_ONE_SHOT)


func _layout_deploy_hint_label() -> void:
	if _deploy_hint_label == null or battlefield == null:
		return
	var vp: Rect2 = battlefield.get_viewport_rect()
	var w: float = minf(560.0, vp.size.x - 48.0)
	_deploy_hint_label.custom_minimum_size = Vector2(w, 0)
	_deploy_hint_label.reset_size()
	_deploy_hint_label.position = Vector2((vp.size.x - _deploy_hint_label.size.x) * 0.5, vp.size.y * 0.34)


func _roster_units_ordered() -> Array[Node2D]:
	var out: Array[Node2D] = []
	if battlefield == null or battlefield.player_container == null:
		return out
	for c in battlefield.player_container.get_children():
		if c is Node2D:
			out.append(c as Node2D)
	return out


func _maybe_quick_fill_for_armed(unit: Node2D) -> bool:
	if unit == null or not is_instance_valid(unit) or battlefield == null:
		return false
	if not CampaignManager.battle_deploy_quick_fill:
		return false
	if unit.visible:
		return false
	if battlefield.is_local_player_command_blocked_for_mock_coop_unit(unit):
		return false
	if _get_deployed_count() >= max_deployment:
		return false
	var empty_slots: Array[Vector2i] = []
	for s: Vector2i in _allowed_deployment_slots_for_unit(unit):
		if _get_barricade(s) != null:
			continue
		if battlefield.get_unit_at(s) != null:
			continue
		empty_slots.append(s)
	if empty_slots.size() != 1:
		return false
	var slot: Vector2i = empty_slots[0]
	unit.position = _grid_to_world(slot)
	unit.visible = true
	unit.process_mode = Node.PROCESS_MODE_INHERIT
	battlefield.play_ui_sfx(battlefield.UISfx.TARGET_OK)
	_deselect()
	_refresh_ui_list()
	battlefield.rebuild_grid()
	if CampaignManager.battle_deploy_auto_arm_after_place:
		_arm_next_benched_after_place(unit)
	if battlefield.has_method("coop_enet_sync_after_local_prebattle_layout_change"):
		battlefield.coop_enet_sync_after_local_prebattle_layout_change()
	return true


func _arm_next_benched_after_place(_just_placed: Node2D) -> void:
	var units: Array[Node2D] = _roster_units_ordered()
	for u: Node2D in units:
		if u == null or not is_instance_valid(u):
			continue
		if u.visible:
			continue
		if battlefield != null and battlefield.is_local_player_command_blocked_for_mock_coop_unit(u):
			continue
		if not battlefield.try_allow_local_player_select_unit_for_command(u):
			continue
		_deselect()
		selected_unit = u
		selected_unit.set_selected_glow(true)
		_roster_selected_unit = u
		var ri: int = _roster_index_for_unit(u)
		if ri >= 0:
			_set_deploy_roster_selection(ri)
		else:
			_set_deploy_roster_selection(-1)
		_update_roster_bond_readout(u)
		battlefield.play_ui_sfx(battlefield.UISfx.MOVE_OK)
		break


func _resolve_primary_deploy_grid(raw_cursor: Vector2i) -> Vector2i:
	## Grid for armed unit action; (-1,-1) if none.
	if selected_unit == null or not is_instance_valid(selected_unit):
		return Vector2i(-1, -1)
	var pos: Vector2i = raw_cursor
	if not _is_deployment_tile(pos):
		var snap0: Vector2i = _nearest_deployment_action_slot(pos, selected_unit)
		if snap0.x < 0:
			return Vector2i(-1, -1)
		if selected_unit.visible and snap0 == battlefield.get_grid_pos(selected_unit):
			return Vector2i(-1, -1)
		pos = snap0
	elif not _slot_allowed_for_unit(selected_unit, pos):
		var snap1: Vector2i = _nearest_deployment_action_slot(pos, selected_unit)
		if snap1.x < 0:
			return Vector2i(-1, -1)
		pos = snap1
	return pos


func _handle_prebattle_key(ev: InputEventKey) -> bool:
	if not ev.pressed or ev.echo:
		return false
	var k: Key = ev.keycode
	## Toggle deployment zone overlay (F6).
	if k == KEY_F6:
		show_deployment_zone_overlay = not show_deployment_zone_overlay
		if battlefield != null:
			battlefield.queue_redraw()
		return true
	if current_mode != DeployMode.UNIT:
		return false
	## Esc = clear armed selection (roster row / bond can stay).
	if k == KEY_ESCAPE:
		if selected_unit != null:
			_deselect()
			battlefield.play_ui_sfx(battlefield.UISfx.INVALID)
			return true
		return false
	## Bench every deployable unit currently on the map (co-op / commander units skipped).
	if (k == KEY_X or k == KEY_B) and ev.shift_pressed:
		_bench_all_deployed_map_units()
		return true
	## Bench shortcut (deployed unit armed).
	if (k == KEY_X or k == KEY_B) and selected_unit != null and is_instance_valid(selected_unit):
		if selected_unit.visible:
			if battlefield.is_local_player_command_blocked_for_mock_coop_unit(selected_unit):
				_show_deploy_hint("Co-op: you cannot command this unit.", true)
				battlefield.notify_mock_coop_remote_command_blocked(selected_unit)
				return true
			if not _try_toggle_unit_bench_deploy(selected_unit):
				return true
			_roster_selected_unit = selected_unit
			_refresh_ui_list()
			var ix: int = _roster_index_for_unit(selected_unit)
			if ix >= 0:
				_set_deploy_roster_selection(ix)
			else:
				_set_deploy_roster_selection(-1)
			_deselect()
			battlefield.rebuild_grid()
			if battlefield.has_method("coop_enet_sync_after_local_prebattle_layout_change"):
				battlefield.coop_enet_sync_after_local_prebattle_layout_change()
			return true
	## Cycle roster.
	var cycle_back: bool = (k == KEY_TAB and ev.shift_pressed) or k == KEY_BRACKETLEFT
	var cycle_fwd: bool = (k == KEY_TAB and not ev.shift_pressed) or k == KEY_BRACKETRIGHT
	if cycle_back or cycle_fwd:
		_cycle_armed_roster(-1 if cycle_back else 1)
		return true
	## Confirm placement / select under cursor.
	if k == KEY_SPACE or k == KEY_ENTER or k == KEY_KP_ENTER:
		_confirm_deploy_from_keyboard()
		return true
	return false


func _bench_all_deployed_map_units() -> void:
	if battlefield == null:
		return
	var benched_any: bool = false
	var skipped: int = 0
	for u: Node2D in _roster_units_ordered():
		if not u.visible:
			continue
		if battlefield.is_local_player_command_blocked_for_mock_coop_unit(u):
			skipped += 1
			continue
		if u.get("is_custom_avatar") == true:
			skipped += 1
			continue
		u.visible = false
		u.process_mode = Node.PROCESS_MODE_DISABLED
		u.position = Vector2(BENCH_OFFSCREEN_XY, BENCH_OFFSCREEN_XY)
		benched_any = true
		if selected_unit == u:
			_deselect()
	if not benched_any:
		if skipped > 0:
			_show_deploy_hint("No units could be benched (co-op / commander rules).", true)
		else:
			_show_deploy_hint("No units on the map.", true)
		return
	_deselect()
	_roster_selected_unit = null
	if roster_list:
		roster_list.deselect_all()
	_set_deploy_roster_selection(-1)
	battlefield.play_ui_sfx(battlefield.UISfx.MOVE_OK)
	_refresh_ui_list()
	battlefield.rebuild_grid()
	if battlefield.has_method("coop_enet_sync_after_local_prebattle_layout_change"):
		battlefield.coop_enet_sync_after_local_prebattle_layout_change()
	var tail: String = (" (%d skipped — co-op or commander)." % skipped) if skipped > 0 else ""
	_show_deploy_hint("All benchable units cleared from the map.%s" % tail, false)


func _cycle_armed_roster(dir: int) -> void:
	var units: Array[Node2D] = _roster_units_ordered()
	if units.is_empty():
		_show_deploy_hint("No units in roster.", true)
		return
	var start_i: int = 0
	if selected_unit != null:
		var fi: int = units.find(selected_unit)
		if fi >= 0:
			start_i = fi
	for step: int in range(units.size()):
		var idx: int = posmod(start_i + dir * (step + 1), units.size())
		var u: Node2D = units[idx]
		if battlefield.is_local_player_command_blocked_for_mock_coop_unit(u):
			continue
		if not battlefield.try_allow_local_player_select_unit_for_command(u):
			continue
		_deselect()
		selected_unit = u
		selected_unit.set_selected_glow(true)
		_roster_selected_unit = u
		active_structure = {}
		var ri: int = _roster_index_for_unit(u)
		if ri >= 0:
			_set_deploy_roster_selection(ri)
		else:
			_set_deploy_roster_selection(-1)
		_update_roster_bond_readout(u)
		battlefield.play_ui_sfx(battlefield.UISfx.MOVE_OK)
		if _maybe_quick_fill_for_armed(u):
			pass
		return
	_show_deploy_hint("No other unit available to select (co-op / permissions).", true)


func _confirm_deploy_from_keyboard() -> void:
	var raw: Vector2i = battlefield.cursor_grid_pos
	if selected_unit == null or not is_instance_valid(selected_unit):
		if current_mode == DeployMode.UNIT and battlefield.get_unit_at(raw) != null:
			_run_deploy_left_at_pos(raw, false)
			return
		_show_deploy_hint("Select a unit from the roster first (Tab / click).", true)
		return
	if battlefield.is_local_player_command_blocked_for_mock_coop_unit(selected_unit):
		_show_deploy_hint("Co-op: you cannot command this unit.", true)
		battlefield.notify_mock_coop_remote_command_blocked(selected_unit)
		return
	var grid: Vector2i = _resolve_primary_deploy_grid(raw)
	if grid.x < 0:
		_show_deploy_hint("No valid deployment tile nearby.", true)
		return
	_run_deploy_left_at_pos(grid, false)


func _is_deployment_tile(pos: Vector2i) -> bool:
	return _deployment_tile_lookup.has(pos)


func _rebuild_deployment_tile_lookup() -> void:
	_deployment_tile_lookup.clear()
	for p: Vector2i in valid_deployment_slots:
		_deployment_tile_lookup[p] = true


func _cell_size() -> Vector2i:
	if battlefield == null:
		return Vector2i(64, 64)
	var cs = battlefield.get("CELL_SIZE")
	return Vector2i(cs) if cs != null else Vector2i(64, 64)


func _grid_to_world(pos: Vector2i) -> Vector2:
	var cs := _cell_size()
	return Vector2(pos.x * cs.x, pos.y * cs.y)


func _get_deployed_count() -> int:
	if battlefield == null or battlefield.get("player_container") == null:
		return 0
	var n := 0
	for u in battlefield.player_container.get_children():
		if u.visible:
			n += 1
	return n


func _deploy_roster_jobs_stats_lines(u: Node) -> PackedStringArray:
	if u == null:
		return PackedStringArray()
	var lv: int = 1
	if u.get("level") != null:
		lv = int(u.get("level"))
	var cls: String = str(u.get("unit_class_name")).strip_edges()
	if cls.is_empty() and u.get("data") != null:
		var d: Variant = u.get("data")
		if typeof(d) == TYPE_OBJECT:
			if d.get("job_name") != null:
				cls = str(d.get("job_name"))
			else:
				var cd: Variant = d.get("character_class")
				if cd != null and typeof(cd) == TYPE_OBJECT and cd.get("job_name") != null:
					cls = str(cd.get("job_name"))
		elif d is Dictionary:
			cls = str((d as Dictionary).get("job_name", ""))
	if cls.is_empty():
		cls = "?"
	var wpn: String = "Unarmed"
	var eq: Variant = u.get("equipped_weapon")
	if eq != null:
		if eq is WeaponData:
			wpn = str((eq as WeaponData).weapon_name)
		elif typeof(eq) == TYPE_OBJECT and eq.get("weapon_name") != null:
			wpn = str(eq.get("weapon_name"))
	var hp_c: int = int(u.get("current_hp")) if u.get("current_hp") != null else 0
	var hp_m: int = maxi(1, int(u.get("max_hp"))) if u.get("max_hp") != null else 1
	var st: int = int(u.get("strength")) if u.get("strength") != null else 0
	var df: int = int(u.get("defense")) if u.get("defense") != null else 0
	var sp: int = int(u.get("speed")) if u.get("speed") != null else 0
	var mg: int = int(u.get("magic")) if u.get("magic") != null else 0
	var line_jobs := "Lv %d · %s · %s" % [lv, cls, wpn]
	var line_stats := "HP %d/%d · Str %d · Def %d · Spd %d · Mag %d" % [hp_c, hp_m, st, df, sp, mg]
	return PackedStringArray([line_jobs, line_stats])


func _try_texture_from_path(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	return res as Texture2D


## Map sprite first, then battle-scale UnitData only (no portrait — those are often huge UI illustrations).
func _deploy_roster_icon_texture(u: Node) -> Texture2D:
	if u == null:
		return null
	for sprite_path: String in ["Sprite", "Sprite2D"]:
		var spr_node: Node = u.get_node_or_null(sprite_path)
		if spr_node is Sprite2D:
			var st: Texture2D = (spr_node as Sprite2D).texture
			if st != null:
				return st
	var ddata: Variant = u.get("data")
	if ddata != null and typeof(ddata) == TYPE_OBJECT:
		for key: String in ["unit_sprite", "battle_sprite"]:
			var v: Variant = ddata.get(key)
			if v is Texture2D:
				return v
			if typeof(v) == TYPE_STRING:
				var lt: Texture2D = _try_texture_from_path(str(v))
				if lt != null:
					return lt
	elif ddata is Dictionary:
		var dict: Dictionary = ddata as Dictionary
		for key2: String in ["unit_sprite", "battle_sprite"]:
			var v2: Variant = dict.get(key2)
			if v2 is Texture2D:
				return v2
			if typeof(v2) == TYPE_STRING:
				var lt2: Texture2D = _try_texture_from_path(str(v2))
				if lt2 != null:
					return lt2
	return null


func _bbcode_escape(s: String) -> String:
	var out := ""
	for i in s.length():
		var ch: String = s.substr(i, 1)
		match ch:
			"[":
				out += "[lb]"
			"]":
				out += "[rb]"
			_:
				out += ch
	return out


func _uses_deploy_custom_roster() -> bool:
	return deploy_roster_scroll != null and is_instance_valid(deploy_roster_scroll) and deploy_roster_scroll.visible


func _ensure_deploy_roster_custom_list() -> void:
	if roster_panel == null or roster_list == null:
		return
	if deploy_roster_scroll != null and is_instance_valid(deploy_roster_scroll):
		return
	deploy_roster_scroll = ScrollContainer.new()
	deploy_roster_scroll.name = "DeployRosterScroll"
	deploy_roster_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	deploy_roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	deploy_roster_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	deploy_roster_vbox = VBoxContainer.new()
	deploy_roster_vbox.name = "DeployRosterVBox"
	deploy_roster_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deploy_roster_vbox.add_theme_constant_override("separation", 2)
	deploy_roster_scroll.add_child(deploy_roster_vbox)
	roster_panel.add_child(deploy_roster_scroll)
	deploy_roster_scroll.visible = false
	deploy_roster_scroll.z_index = roster_list.z_index
	var insert_at: int = clampi(roster_list.get_index() + 1, 0, roster_panel.get_child_count() - 1)
	roster_panel.move_child(deploy_roster_scroll, insert_at)


func _sync_deploy_roster_scroll_if_needed() -> void:
	if deploy_roster_scroll == null or not deploy_roster_scroll.visible or roster_list == null:
		return
	deploy_roster_scroll.position = roster_list.position
	deploy_roster_scroll.size = roster_list.size


func _apply_deploy_row_visual(panel: PanelContainer, is_deployed: bool, selected: bool) -> void:
	var sb := StyleBoxFlat.new()
	if selected:
		sb.bg_color = Color(0.28, 0.26, 0.22, 0.72)
		sb.set_border_width_all(1)
		sb.border_color = Color(0.82, 0.71, 0.38, 0.85)
	else:
		sb.bg_color = Color(0.12, 0.11, 0.09, 0.35) if is_deployed else Color(0.1, 0.09, 0.08, 0.25)
		sb.set_border_width_all(0)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_top = 3
	sb.content_margin_right = 6
	sb.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", sb)


func _set_deploy_roster_selection(index: int) -> void:
	_deploy_selected_row_index = index
	if deploy_roster_vbox == null:
		return
	var i: int = 0
	for c in deploy_roster_vbox.get_children():
		if c is PanelContainer and c.has_meta("deploy_unit"):
			var u_meta: Node = c.get_meta("deploy_unit")
			var is_dep: bool = u_meta is Node2D and (u_meta as Node2D).visible
			_apply_deploy_row_visual(c as PanelContainer, is_dep, index >= 0 and i == index)
		i += 1


func _make_deploy_roster_row(unit: Node2D, title_plain: String, jobs_line: String, stats_line: String, icon: Texture2D, is_deployed: bool, tooltip: String, row_index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_meta("deploy_unit", unit)
	panel.set_meta("deploy_row_index", row_index)
	panel.tooltip_text = tooltip
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_host := Control.new()
	icon_host.custom_minimum_size = Vector2(DEPLOY_ROSTER_ICON_PX, DEPLOY_ROSTER_ICON_PX)
	icon_host.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	icon_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_host.clip_contents = true
	icon_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := TextureRect.new()
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.offset_left = 0.0
	tex.offset_top = 0.0
	tex.offset_right = 0.0
	tex.offset_bottom = 0.0
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != null:
		tex.texture = icon
	icon_host.add_child(tex)
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_hex := (Color(0.2, 1.0, 0.2) if is_deployed else Color(0.62, 0.62, 0.62)).to_html(false)
	var detail_hex := (Color(0.78, 0.86, 0.74) if is_deployed else Color(0.58, 0.58, 0.58)).to_html(false)
	var t_esc := _bbcode_escape(title_plain)
	var j_esc := _bbcode_escape(jobs_line)
	var s_esc := _bbcode_escape(stats_line)
	rtl.text = "[font_size=%d][color=#%s]%s[/color][/font_size]\n[font_size=%d][color=#%s]%s[/color][/font_size]\n[font_size=%d][color=#%s]%s[/color][/font_size]" % [
		DEPLOY_ROSTER_RTL_NAME_FONT, name_hex, t_esc,
		DEPLOY_ROSTER_RTL_DETAIL_FONT, detail_hex, j_esc,
		DEPLOY_ROSTER_RTL_DETAIL_FONT, detail_hex, s_esc
	]
	h.add_child(icon_host)
	h.add_child(rtl)
	panel.add_child(h)
	_apply_deploy_row_visual(panel, is_deployed, false)
	panel.gui_input.connect(_on_deploy_row_gui_input.bind(unit, row_index))
	return panel


func _on_deploy_row_gui_input(event: InputEvent, unit: Node2D, row_index: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if battlefield == null or unit == null or not is_instance_valid(unit):
		return
	if battlefield.is_local_player_command_blocked_for_mock_coop_unit(unit):
		battlefield.notify_mock_coop_remote_command_blocked(unit)
		return
	var now: int = Time.get_ticks_msec()
	if row_index == _deploy_roster_last_click_index and (now - _deploy_roster_last_click_msec) < 450:
		_deploy_roster_last_click_index = -1
		if current_mode != DeployMode.UNIT:
			return
		var layout_changed: bool = _try_toggle_unit_bench_deploy(unit)
		if not layout_changed:
			return
		_roster_selected_unit = unit
		_refresh_ui_list()
		var new_idx: int = _roster_index_for_unit(unit)
		if new_idx >= 0:
			_set_deploy_roster_selection(new_idx)
		else:
			_update_roster_bond_readout(unit)
		battlefield.rebuild_grid()
		if battlefield.has_method("coop_enet_sync_after_local_prebattle_layout_change"):
			battlefield.coop_enet_sync_after_local_prebattle_layout_change()
	else:
		_deploy_roster_last_click_msec = now
		_deploy_roster_last_click_index = row_index
		_set_deploy_roster_selection(row_index)
		_roster_selected_unit = unit
		active_structure = {}
		_update_roster_bond_readout(unit)
		# Single-click also arms the unit for click-to-place on deployment tiles.
		if not battlefield.try_allow_local_player_select_unit_for_command(unit):
			return
		_deselect()
		selected_unit = unit
		selected_unit.set_selected_glow(true)
		battlefield.play_ui_sfx(battlefield.UISfx.MOVE_OK)
		if _maybe_quick_fill_for_armed(unit):
			return


func _try_toggle_unit_bench_deploy(unit_nd: Node2D) -> bool:
	if unit_nd == null or not is_instance_valid(unit_nd) or battlefield == null:
		return false
	if battlefield.is_local_player_command_blocked_for_mock_coop_unit(unit_nd):
		battlefield.notify_mock_coop_remote_command_blocked(unit_nd)
		_show_deploy_hint("Co-op: you cannot command this unit.", true)
		return false
	if unit_nd.get("is_custom_avatar") == true and unit_nd.visible:
		_show_deploy_hint("This unit cannot return to the bench.", true)
		return false
	var layout_changed := false
	if unit_nd.visible:
		battlefield.play_ui_sfx(battlefield.UISfx.MOVE_OK)
		unit_nd.visible = false
		unit_nd.process_mode = Node.PROCESS_MODE_DISABLED
		unit_nd.position = Vector2(BENCH_OFFSCREEN_XY, BENCH_OFFSCREEN_XY)
		layout_changed = true
		if selected_unit == unit_nd:
			_deselect()
	else:
		if _get_deployed_count() >= max_deployment:
			_show_deploy_hint("Deployment band is full (%d / %d)." % [_get_deployed_count(), max_deployment], true)
		else:
			var slot: Vector2i = _find_first_empty_slot(unit_nd)
			if slot.x >= 0:
				battlefield.play_ui_sfx(battlefield.UISfx.MOVE_OK)
				unit_nd.position = _grid_to_world(slot)
				unit_nd.visible = true
				unit_nd.process_mode = Node.PROCESS_MODE_INHERIT
				layout_changed = true
			else:
				_show_deploy_hint("No empty deployment tile.", true)
	return layout_changed


func _collect_roster_relationship_ids() -> Array:
	var out: Array = []
	if battlefield == null or battlefield.player_container == null:
		return out
	for u in battlefield.player_container.get_children():
		out.append(battlefield.get_relationship_id(u))
	return out


func _allowed_deployment_slots_for_unit(unit: Node2D) -> Array[Vector2i]:
	if unit == null or not is_instance_valid(unit):
		return []
	if battlefield != null and battlefield.has_method("get_mock_coop_allowed_prebattle_slots_for_unit"):
		var allowed: Variant = battlefield.get_mock_coop_allowed_prebattle_slots_for_unit(unit)
		if typeof(allowed) == TYPE_ARRAY and not (allowed as Array).is_empty():
			var typed: Array[Vector2i] = []
			for slot in allowed as Array:
				if slot is Vector2i:
					typed.append(slot)
				elif typeof(slot) == TYPE_VECTOR2I:
					typed.append(slot as Vector2i)
			if not typed.is_empty():
				return typed
	return valid_deployment_slots


func _slot_allowed_for_unit(unit: Node2D, slot: Vector2i) -> bool:
	return slot in _allowed_deployment_slots_for_unit(unit)


## Closest allowed deployment cell to the cursor; benched units only consider empty tiles. Returns (-1,-1) if none.
func _nearest_deployment_action_slot(cursor: Vector2i, unit: Node2D) -> Vector2i:
	if unit == null or not is_instance_valid(unit) or battlefield == null:
		return Vector2i(-1, -1)
	var allowed: Array[Vector2i] = _allowed_deployment_slots_for_unit(unit)
	if allowed.is_empty():
		return Vector2i(-1, -1)
	var need_empty: bool = not unit.visible
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: int = 999999999
	for s: Vector2i in allowed:
		if _get_barricade(s) != null:
			continue
		if need_empty:
			if battlefield.get_unit_at(s) != null:
				continue
		var dx: int = s.x - cursor.x
		var dy: int = s.y - cursor.y
		var d: int = dx * dx + dy * dy
		if d < best_d:
			best_d = d
			best = s
	return best


func _find_first_empty_slot(for_unit: Node2D = null) -> Vector2i:
	if battlefield == null:
		return Vector2i(-1, -1)
	var candidate_slots: Array[Vector2i] = valid_deployment_slots
	if for_unit != null:
		candidate_slots = _allowed_deployment_slots_for_unit(for_unit)
	for slot: Vector2i in candidate_slots:
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
	_deployment_tile_lookup.clear()

	var zones_container: Node = battlefield.get_node_or_null("DeploymentZones") if battlefield else null
	if zones_container:
		var cs := _cell_size()
		for marker in zones_container.get_children():
			var gx := int(marker.global_position.x / float(cs.x))
			var gy := int(marker.global_position.y / float(cs.y))
			valid_deployment_slots.append(Vector2i(gx, gy))
	_rebuild_deployment_tile_lookup()

	var roster_cap: int = battlefield.player_container.get_child_count() if battlefield.player_container != null else MAX_DEPLOYMENT_CAP
	max_deployment = mini(MAX_DEPLOYMENT_CAP, mini(valid_deployment_slots.size(), roster_cap))

	var start_btn: Button = battlefield.get_node_or_null("UI/StartBattleButton")
	if start_btn:
		start_btn.visible = true
		if battlefield.has_method("_update_mock_coop_start_battle_button_state"):
			battlefield.call("_update_mock_coop_start_battle_button_state")

	roster_panel = battlefield.get_node_or_null("UI/RosterPanel")
	if roster_panel:
		roster_list = roster_panel.get_node_or_null("RosterList")
		count_label = roster_panel.get_node_or_null("DeployCountLabel")
		build_btn = roster_panel.get_node_or_null("BuildButton")
		if roster_list:
			roster_panel.visible = true
			roster_panel.clip_contents = true
			roster_list.allow_reselect = true
			_ensure_deploy_roster_custom_list()
			if not roster_list.item_selected.is_connected(_on_list_item_selected):
				roster_list.item_selected.connect(_on_list_item_selected)
			if not roster_list.item_activated.is_connected(_on_list_item_activated):
				roster_list.item_activated.connect(_on_list_item_activated)
			if build_btn and not build_btn.pressed.is_connected(_on_build_btn_pressed):
				build_btn.pressed.connect(_on_build_btn_pressed)
		_ensure_roster_bond_readout()
		var db_after: Panel = roster_panel.get_node_or_null("DeployBondPanel") as Panel
		if db_after != null:
			db_after.visible = true
		_refresh_ui_list()

	show_deployment_zone_overlay = CampaignManager.battle_deploy_zone_overlay_default
	deploy_snap_highlight_cell = Vector2i(-1, -1)
	## UI root is a CanvasLayer in battle_field.tscn — do not cast to Control (that yields null).
	var ui_layer: Node = battlefield.get_node_or_null("UI")
	if ui_layer != null:
		_deploy_hint_label = Label.new()
		_deploy_hint_label.name = "DeployHintLabel"
		_deploy_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_deploy_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_deploy_hint_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.95))
		_deploy_hint_label.add_theme_constant_override("outline_size", 5)
		_deploy_hint_label.add_theme_font_size_override("font_size", 18)
		_deploy_hint_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72, 1.0))
		_deploy_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_deploy_hint_label.custom_minimum_size = Vector2(420, 0)
		_deploy_hint_label.visible = false
		_deploy_hint_label.z_index = 80
		_deploy_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_layer.add_child(_deploy_hint_label)

		_deploy_controls_hint = Label.new()
		_deploy_controls_hint.name = "DeployControlsHint"
		_deploy_controls_hint.add_theme_font_size_override("font_size", 13)
		_deploy_controls_hint.add_theme_color_override(
			"font_color",
			Color(0.88, 0.84, 0.76, 0.92)
		)
		_deploy_controls_hint.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.88))
		_deploy_controls_hint.add_theme_constant_override("outline_size", 4)
		_deploy_controls_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_deploy_controls_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_deploy_controls_hint.z_index = 92
		_deploy_controls_hint.visible = true
		ui_layer.add_child(_deploy_controls_hint)
		_update_deploy_controls_hint_text()
		_layout_deploy_controls_hint()

	ghost_sprite = Sprite2D.new()
	ghost_sprite.modulate = Color(1.0, 1.0, 1.0, 0.6)
	ghost_sprite.z_index = 100
	ghost_sprite.visible = false
	battlefield.add_child(ghost_sprite)
	battlefield.queue_redraw()


func exit() -> void:
	if selected_unit and is_instance_valid(selected_unit):
		selected_unit.set_selected_glow(false)
	selected_unit = null
	_roster_selected_unit = null
	active_structure = {}
	current_mode = DeployMode.UNIT

	if roster_list != null and roster_list.item_selected.is_connected(_on_list_item_selected):
		roster_list.item_selected.disconnect(_on_list_item_selected)
	if roster_list != null and roster_list.item_activated.is_connected(_on_list_item_activated):
		roster_list.item_activated.disconnect(_on_list_item_activated)
	if build_btn != null and build_btn.pressed.is_connected(_on_build_btn_pressed):
		build_btn.pressed.disconnect(_on_build_btn_pressed)

	var start_btn: Button = battlefield.get_node_or_null("UI/StartBattleButton") if battlefield else null
	if start_btn:
		start_btn.visible = false
	if roster_panel:
		if roster_panel.has_meta("deployment_rail_collapsed"):
			roster_panel.remove_meta("deployment_rail_collapsed")
		roster_panel.clip_contents = false
		roster_panel.visible = false
	var deploy_bond_exit: Panel = battlefield.get_node_or_null("UI/RosterPanel/DeployBondPanel") as Panel if battlefield else null
	if deploy_bond_exit != null:
		deploy_bond_exit.visible = false
	if is_instance_valid(ghost_sprite):
		ghost_sprite.queue_free()
		ghost_sprite = null
	if _deploy_hint_label != null and is_instance_valid(_deploy_hint_label):
		_deploy_hint_label.queue_free()
	_deploy_hint_label = null
	if _deploy_controls_hint != null and is_instance_valid(_deploy_controls_hint):
		_deploy_controls_hint.queue_free()
	_deploy_controls_hint = null
	deploy_snap_highlight_cell = Vector2i(-1, -1)
	if is_instance_valid(battlefield):
		battlefield.queue_redraw()
	super.exit()


func update(_delta: float) -> void:
	if battlefield == null or not is_instance_valid(ghost_sprite):
		return
	_sync_deploy_roster_scroll_if_needed()
	deploy_snap_highlight_cell = Vector2i(-1, -1)
	if _deploy_hint_label != null and _deploy_hint_label.visible:
		_layout_deploy_hint_label()
	_layout_deploy_controls_hint()
	var grid_pos: Vector2i = battlefield.cursor_grid_pos
	var world_pos := _grid_to_world(grid_pos)
	ghost_sprite.visible = false
	ghost_sprite.scale = Vector2.ONE

	if current_mode == DeployMode.BUILD and not active_structure.is_empty():
		if not _is_deployment_tile(grid_pos):
			battlefield.queue_redraw()
			return
		if active_structure.get("count", 0) > 0 and _can_build_here(grid_pos, active_structure.get("type", "")):
			ghost_sprite.position = world_pos + ghost_offset
			ghost_sprite.modulate = Color(0.2, 1.0, 0.2, 0.7)
			ghost_sprite.visible = true
	elif current_mode == DeployMode.UNIT and selected_unit != null and is_instance_valid(selected_unit):
		if battlefield.is_local_player_command_blocked_for_mock_coop_unit(selected_unit):
			battlefield.queue_redraw()
			return
		var preview_grid: Vector2i = grid_pos
		var have_preview: bool = false
		if _is_deployment_tile(grid_pos):
			var occupant: Node2D = battlefield.get_unit_at(grid_pos)
			if occupant != selected_unit and _slot_allowed_for_unit(selected_unit, grid_pos):
				have_preview = true
				preview_grid = grid_pos
		if not have_preview:
			var snap: Vector2i = _nearest_deployment_action_slot(grid_pos, selected_unit)
			if snap.x >= 0:
				if not (selected_unit.visible and snap == battlefield.get_grid_pos(selected_unit)):
					have_preview = true
					preview_grid = snap
		if have_preview:
			var spr: Node = selected_unit.get_node_or_null("Sprite")
			if spr == null:
				spr = selected_unit.get_node_or_null("Sprite2D")
			if spr is Sprite2D and (spr as Sprite2D).texture:
				var s2: Sprite2D = spr as Sprite2D
				var preview_world: Vector2 = _grid_to_world(preview_grid)
				ghost_sprite.texture = s2.texture
				ghost_sprite.centered = s2.centered
				ghost_sprite.offset = s2.offset
				ghost_sprite.flip_h = s2.flip_h
				var sprite_rel: Vector2 = s2.global_position - selected_unit.global_position
				ghost_sprite.global_position = preview_world + sprite_rel
				ghost_sprite.global_rotation = s2.global_rotation
				ghost_sprite.scale = s2.global_scale * DEPLOY_UNIT_GHOST_SCALE_MULT
				ghost_sprite.modulate = Color(1.0, 1.0, 1.0, 0.6)
				ghost_sprite.visible = true
				deploy_snap_highlight_cell = preview_grid

	battlefield.queue_redraw()


func _on_build_btn_pressed() -> void:
	if battlefield == null:
		return
	battlefield.play_ui_sfx(battlefield.UISfx.MOVE_OK)
	_deselect()
	current_mode = DeployMode.BUILD if current_mode != DeployMode.BUILD else DeployMode.UNIT
	_update_deploy_controls_hint_text()
	_refresh_ui_list()
	if battlefield.has_method("_queue_tactical_ui_overhaul"):
		battlefield._queue_tactical_ui_overhaul()


# --- Roster UI refresh: build menu vs unit list, tooltips, bond rows ---
func _refresh_ui_list() -> void:
	if roster_list == null:
		return

	if current_mode == DeployMode.BUILD:
		if deploy_roster_scroll != null:
			deploy_roster_scroll.visible = false
		roster_list.visible = true
		roster_list.clear()
		if roster_panel:
			roster_panel.set_meta("deploy_bond_hidden", true)
		var bond_roster: Panel = roster_panel.get_node_or_null("DeployBondPanel") as Panel if roster_panel else null
		if bond_roster != null:
			bond_roster.visible = false
		if count_label:
			count_label.text = "- ENGINEERING -"
		if build_btn:
			build_btn.text = "[ RETURN TO UNITS ]"
			build_btn.modulate = Color(1.0, 0.8, 0.2)
		for struct: Variant in CampaignManager.player_structures:
			if struct is Dictionary and struct.get("count", 0) > 0:
				var d: Dictionary = struct
				var text: String = str(d.get("name", "?")) + " (x" + str(d["count"]) + ")"
				var idx: int = roster_list.add_item(text, null)
				roster_list.set_item_metadata(idx, {"is_structure": true, "data": d})
				roster_list.set_item_custom_fg_color(idx, Color.GOLD)
		if roster_list.is_inside_tree():
			roster_list.force_update_list_size()
		return

	if build_btn:
		build_btn.text = "Build Defenses"
		build_btn.modulate = Color.WHITE
	if roster_panel and roster_panel.has_meta("deploy_bond_hidden"):
		roster_panel.remove_meta("deploy_bond_hidden")
	if battlefield == null or battlefield.player_container == null:
		return

	_ensure_deploy_roster_custom_list()
	roster_list.clear()
	roster_list.visible = false
	for c in deploy_roster_vbox.get_children():
		c.queue_free()
	if deploy_roster_scroll != null:
		deploy_roster_scroll.visible = true

	var candidate_ids: Array = _collect_roster_relationship_ids()
	var mock_coop_roster_tags: bool = battlefield.is_mock_coop_unit_ownership_active()

	var deployed_count := 0
	var row_i: int = 0
	for u in battlefield.player_container.get_children():
		if not (u is Node2D):
			continue
		var u2: Node2D = u as Node2D
		var is_deployed: bool = u2.visible
		if is_deployed:
			deployed_count += 1
		var u_name = u.get("unit_name")
		var title_plain := ("Deployed · " if is_deployed else "Benched · ")
		if mock_coop_roster_tags:
			var own_key: String = battlefield.get_mock_coop_unit_owner_for_unit(u2)
			if own_key == "remote":
				title_plain += "Partner · "
			elif own_key == "local":
				title_plain += "Yours · "
		title_plain += (str(u_name) if u_name != null else "?")
		if u.get("is_custom_avatar") == true:
			title_plain += " (Leader)"
		var jsl: PackedStringArray = _deploy_roster_jobs_stats_lines(u)
		if jsl.size() < 2:
			continue
		var icon: Texture2D = _deploy_roster_icon_texture(u)
		var unit_id: String = battlefield.get_relationship_id(u2)
		var others: Array = []
		for id in candidate_ids:
			if id != unit_id:
				others.append(id)
		var entries_full: Array = CampaignManager.get_top_relationship_entries_for_unit(unit_id, others, 5)
		var tooltip_lines: PackedStringArray = PackedStringArray()
		tooltip_lines.append("Strongest ties vs this list. Double-click row: deploy / bench.")
		if mock_coop_roster_tags:
			var own_tip: String = battlefield.get_mock_coop_unit_owner_for_unit(u2)
			if own_tip == "remote":
				tooltip_lines.append("Mock co-op: Partner detachment (locked)")
			elif own_tip == "local":
				tooltip_lines.append("Mock co-op: Your detachment (locked)")
		if entries_full.is_empty():
			tooltip_lines.append("No notable trust / mentorship / rivalry with current roster.")
		else:
			for e in entries_full:
				tooltip_lines.append(CampaignManager.format_relationship_tooltip(e))
		var tip: String = "\n".join(tooltip_lines)
		var row_pc: PanelContainer = _make_deploy_roster_row(u2, title_plain, jsl[0], jsl[1], icon, is_deployed, tip, row_i)
		deploy_roster_vbox.add_child(row_pc)
		row_i += 1

	if count_label:
		count_label.text = "Deployed: %d / %d" % [deployed_count, max_deployment]
	var bond_frame2: Panel = roster_panel.get_node_or_null("DeployBondPanel") as Panel if roster_panel else null
	if bond_frame2 != null:
		bond_frame2.visible = true
	_update_roster_bond_readout(_roster_selected_unit)
	if _roster_selected_unit != null and is_instance_valid(_roster_selected_unit):
		var sel_i: int = _roster_index_for_unit(_roster_selected_unit)
		if sel_i >= 0:
			_set_deploy_roster_selection(sel_i)
	else:
		_set_deploy_roster_selection(-1)


func _ensure_roster_bond_readout() -> void:
	if roster_bond_rows != null and is_instance_valid(roster_bond_rows):
		return
	if battlefield == null or roster_panel == null:
		return
	var ui_root: Node = battlefield.get_node_or_null("UI")
	if roster_panel != null:
		var legacy_inside: Node = roster_panel.get_node_or_null("RosterBondReadoutPanel")
		if legacy_inside != null:
			legacy_inside.queue_free()
	var legacy_strip: Node = roster_panel.get_node_or_null("BondIconsStrip")
	if legacy_strip != null:
		legacy_strip.queue_free()
	var legacy_rows: Node = roster_panel.get_node_or_null("RosterBondRows")
	if legacy_rows != null:
		legacy_rows.queue_free()
	if ui_root != null:
		var stray: Node = ui_root.get_node_or_null("DeployBondPanel")
		if stray != null and stray.get_parent() != roster_panel:
			var stray_parent: Node = stray.get_parent()
			if stray_parent != null:
				stray_parent.remove_child(stray)
			roster_panel.add_child(stray)
	var frame: Panel = roster_panel.get_node_or_null("DeployBondPanel") as Panel
	if frame == null:
		frame = Panel.new()
		frame.name = "DeployBondPanel"
		roster_panel.add_child(frame)
		frame.z_index = 2
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.clip_contents = true
	frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	frame.anchor_right = 0.0
	frame.anchor_bottom = 0.0
	if frame.get_node_or_null("BondRootVBox") == null:
		for c in frame.get_children():
			c.queue_free()
		var root := VBoxContainer.new()
		root.name = "BondRootVBox"
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.offset_left = 8.0
		root.offset_top = 8.0
		root.offset_right = -8.0
		root.offset_bottom = -8.0
		root.add_theme_constant_override("separation", 6)
		var hint := Label.new()
		hint.name = "RosterBondHint"
		hint.text = "Double-click a row to deploy or bench."
		hint.add_theme_font_size_override("font_size", 11)
		hint.add_theme_color_override("font_color", Color(0.5, 0.46, 0.4, 0.78))
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var title := Label.new()
		title.name = "RosterBondTitle"
		title.add_theme_font_size_override("font_size", 16)
		title.add_theme_color_override("font_color", Color(0.91, 0.81, 0.36))
		title.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.78))
		title.add_theme_constant_override("outline_size", 2)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var scroll := ScrollContainer.new()
		scroll.name = "RosterBondScroll"
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.mouse_filter = Control.MOUSE_FILTER_PASS
		var rows := VBoxContainer.new()
		rows.name = "RosterBondRows"
		rows.add_theme_constant_override("separation", 8)
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(rows)
		root.add_child(hint)
		root.add_child(title)
		root.add_child(scroll)
		frame.add_child(root)
		roster_bond_hint = hint
		roster_bond_title = title
		roster_bond_rows = rows
	else:
		var rroot: VBoxContainer = frame.get_node_or_null("BondRootVBox") as VBoxContainer
		roster_bond_hint = rroot.get_node_or_null("RosterBondHint") as Label
		roster_bond_title = rroot.get_node_or_null("RosterBondTitle") as Label
		var sc: ScrollContainer = rroot.get_node_or_null("RosterBondScroll") as ScrollContainer
		roster_bond_rows = sc.get_node_or_null("RosterBondRows") as VBoxContainer
	_bond_panel_place_below_roster_list()
	if battlefield.has_method("_queue_tactical_ui_overhaul"):
		battlefield._queue_tactical_ui_overhaul()


func _bond_panel_place_below_roster_list() -> void:
	if roster_panel == null or roster_list == null:
		return
	var f: Node = roster_panel.get_node_or_null("DeployBondPanel")
	if f == null:
		return
	f.z_index = 2
	var idx: int = roster_list.get_index() + 1
	idx = clampi(idx, 0, roster_panel.get_child_count() - 1)
	roster_panel.move_child(f, idx)


func _bond_clear_rows() -> void:
	if roster_bond_rows == null or not is_instance_valid(roster_bond_rows):
		return
	for c in roster_bond_rows.get_children():
		c.queue_free()


func _bond_bar_display_ratio(linear_strength: float, formed: bool) -> float:
	var t: float = clampf(linear_strength, 0.0, 1.0)
	if formed:
		t = maxf(t, 0.72)
	# Curve: pow(t, exp) with exp < 1 spreads apart small values; exp=0.5 is sqrt.
	var curved: float = pow(t, BOND_BAR_DISPLAY_RATIO_CURVE)
	return clampf(curved, 0.0, 1.0)


func _make_bond_compare_row(entry: Dictionary) -> Control:
	var stat: String = str(entry.get("stat", ""))
	var val: int = int(entry.get("value", 0))
	var formed: bool = bool(entry.get("formed", false))
	var col: Color = CampaignManager.get_relationship_type_color(stat)
	var partner_id: String = str(entry.get("partner_id", "?"))
	var type_name: String = CampaignManager.get_relationship_type_display_name(stat)
	var hint_line: String = CampaignManager.get_relationship_effect_hint(stat, val)
	var linear: float = clampf(float(val) / BOND_COMPARE_VALUE_CAP, 0.0, 1.0)
	var vis_ratio: float = _bond_bar_display_ratio(linear, formed)
	var track_inner_w: float = BOND_BAR_TRACK_W - 4.0
	var fill_px: float = track_inner_w * vis_ratio
	if val > 0:
		fill_px = maxf(fill_px, BOND_BAR_MIN_FILL_PX)
	fill_px = minf(fill_px, track_inner_w)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.mouse_filter = Control.MOUSE_FILTER_PASS

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 8)
	bar_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.mouse_filter = Control.MOUSE_FILTER_PASS

	var bar_host := Control.new()
	bar_host.custom_minimum_size = Vector2(BOND_BAR_TRACK_W, 18.0)
	bar_host.clip_contents = false
	bar_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := ColorRect.new()
	track.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.offset_left = 0.0
	track.offset_top = 4.0
	track.offset_right = 0.0
	track.offset_bottom = -4.0
	track.color = Color(0.12, 0.11, 0.1, 0.95)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track_tint := ColorRect.new()
	track_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	track_tint.offset_left = 0.0
	track_tint.offset_top = 4.0
	track_tint.offset_right = 0.0
	track_tint.offset_bottom = -4.0
	track_tint.color = Color(col.r, col.g, col.b, 0.18)
	track_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = col.lightened(0.08)
	fill.position = Vector2(2, 5)
	fill.size = Vector2(fill_px, BOND_BAR_FILL_H)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_host.add_child(track)
	bar_host.add_child(track_tint)
	bar_host.add_child(fill)

	var value_lbl := Label.new()
	value_lbl.text = str(val)
	value_lbl.add_theme_font_size_override("font_size", 17)
	value_lbl.add_theme_color_override("font_color", col.lightened(0.12))
	value_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.82))
	value_lbl.add_theme_constant_override("outline_size", 2)
	value_lbl.custom_minimum_size = Vector2(28, 0)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_lbl.tooltip_text = "Bond strength for this type (higher = stronger). Caps at %d for this bar." % int(BOND_COMPARE_VALUE_CAP)
	value_lbl.mouse_filter = Control.MOUSE_FILTER_STOP

	bar_row.add_child(bar_host)
	bar_row.add_child(value_lbl)

	var lbl := Label.new()
	lbl.text = partner_id + " — " + type_name + " — " + hint_line
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.86, 0.78))
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.75))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.tooltip_text = CampaignManager.format_relationship_tooltip(entry)
	lbl.mouse_filter = Control.MOUSE_FILTER_STOP

	outer.add_child(bar_row)
	outer.add_child(lbl)
	return outer


func _update_roster_bond_readout(unit: Node2D) -> void:
	if battlefield == null:
		return
	# Bonds UI is built once in enter(); tactical layout can replace the panel tree — rebuild if stale.
	if roster_bond_rows == null or not is_instance_valid(roster_bond_rows) \
		or roster_bond_title == null or not is_instance_valid(roster_bond_title) \
		or roster_bond_hint == null or not is_instance_valid(roster_bond_hint):
		_ensure_roster_bond_readout()
	if roster_bond_rows == null or not is_instance_valid(roster_bond_rows) \
		or roster_bond_title == null or not is_instance_valid(roster_bond_title) \
		or roster_bond_hint == null or not is_instance_valid(roster_bond_hint):
		return
	roster_bond_hint.visible = true
	roster_bond_hint.text = "Double-click a row to deploy or bench."
	if battlefield.player_container == null:
		roster_bond_title.text = "Roster bonds"
		_bond_clear_rows()
		var empty := Label.new()
		empty.text = "No units in roster."
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.7, 0.66, 0.6))
		roster_bond_rows.add_child(empty)
		return
	if unit == null or not is_instance_valid(unit):
		roster_bond_title.text = "Roster bonds"
		_bond_clear_rows()
		var idle := Label.new()
		idle.text = "Select a unit above to compare bonds. Bars match bond type color (e.g. cyan = trust); length scales with strength."
		idle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		idle.add_theme_font_size_override("font_size", 14)
		idle.add_theme_color_override("font_color", Color(0.72, 0.68, 0.62))
		roster_bond_rows.add_child(idle)
		return
	var unit_id: String = battlefield.get_relationship_id(unit)
	var u_name: String = str(unit.get("unit_name") if unit.get("unit_name") != null else "?")
	var candidate_ids: Array = []
	for u in battlefield.player_container.get_children():
		if u != unit:
			candidate_ids.append(battlefield.get_relationship_id(u))
	var entries: Array = CampaignManager.get_top_relationship_entries_for_unit(unit_id, candidate_ids, 8)
	roster_bond_title.text = u_name + " — strongest links vs this deploy roster:"
	_bond_clear_rows()
	if entries.is_empty():
		var none := Label.new()
		none.text = "No notable trust, mentorship, or rivalry with anyone on this list."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.add_theme_font_size_override("font_size", 14)
		none.add_theme_color_override("font_color", Color(0.72, 0.68, 0.62))
		roster_bond_rows.add_child(none)
		return
	for e in entries:
		if e is Dictionary:
			roster_bond_rows.add_child(_make_bond_compare_row(e as Dictionary))


func _roster_index_for_unit(unit: Node2D) -> int:
	if unit == null or not is_instance_valid(unit):
		return -1
	if _uses_deploy_custom_roster() and deploy_roster_vbox != null:
		var di: int = 0
		for c in deploy_roster_vbox.get_children():
			if c.has_meta("deploy_unit") and c.get_meta("deploy_unit") == unit:
				return di
			di += 1
		return -1
	if roster_list == null:
		return -1
	for i: int in range(roster_list.item_count):
		var meta_i: Variant = roster_list.get_item_metadata(i)
		if meta_i == null or typeof(meta_i) != TYPE_DICTIONARY:
			continue
		if (meta_i as Dictionary).get("is_structure", false):
			continue
		if (meta_i as Dictionary).get("data", null) == unit:
			return i
	return -1


func _on_list_item_selected(index: int) -> void:
	if roster_list == null or battlefield == null:
		return
	if index < 0 or index >= roster_list.item_count:
		return
	var meta: Variant = roster_list.get_item_metadata(index)
	if meta == null or typeof(meta) != TYPE_DICTIONARY:
		return

	if (meta as Dictionary).get("is_structure", false):
		_deselect()
		_roster_selected_unit = null
		active_structure = (meta as Dictionary).get("data", {})
		battlefield.play_ui_sfx(battlefield.UISfx.MOVE_OK)
		var scene_path: Variant = active_structure.get("scene_path")
		if scene_path:
			var scene_pack: PackedScene = load(str(scene_path)) as PackedScene
			if scene_pack:
				var temp: Node = scene_pack.instantiate()
				var spr: Sprite2D = null
				for child in temp.get_children():
					if child is Sprite2D:
						spr = child
						break
				if spr == null and temp is Sprite2D:
					spr = temp as Sprite2D
				if spr and spr.texture:
					ghost_sprite.texture = spr.texture
					ghost_sprite.scale = spr.scale
					ghost_sprite.centered = spr.centered
					ghost_sprite.offset = spr.offset
					ghost_offset = spr.position
				temp.free()
		return

	active_structure = {}
	var unit: Variant = (meta as Dictionary).get("data")
	if unit == null or not (unit is Node2D):
		return
	var unit_nd: Node2D = unit as Node2D
	if battlefield.is_local_player_command_blocked_for_mock_coop_unit(unit_nd):
		battlefield.notify_mock_coop_remote_command_blocked(unit_nd)
		_show_deploy_hint("Co-op: you cannot command this unit.", true)
		return
	_roster_selected_unit = unit_nd
	_update_roster_bond_readout(unit_nd)
	# Single-click selection should arm the unit for click-to-place on tiles.
	if not battlefield.try_allow_local_player_select_unit_for_command(unit_nd):
		return
	_deselect()
	selected_unit = unit_nd
	selected_unit.set_selected_glow(true)
	battlefield.play_ui_sfx(battlefield.UISfx.MOVE_OK)
	if _maybe_quick_fill_for_armed(unit_nd):
		return


func _on_list_item_activated(index: int) -> void:
	if roster_list == null or battlefield == null:
		return
	if current_mode == DeployMode.BUILD:
		return
	if index < 0 or index >= roster_list.item_count:
		return
	var meta: Variant = roster_list.get_item_metadata(index)
	if meta == null or typeof(meta) != TYPE_DICTIONARY:
		return
	if (meta as Dictionary).get("is_structure", false):
		return
	var unit: Variant = (meta as Dictionary).get("data")
	if unit == null or not (unit is Node2D):
		return
	var unit_nd: Node2D = unit as Node2D
	if battlefield.is_local_player_command_blocked_for_mock_coop_unit(unit_nd):
		battlefield.notify_mock_coop_remote_command_blocked(unit_nd)
		return
	var layout_changed: bool = _try_toggle_unit_bench_deploy(unit_nd)
	if not layout_changed:
		return
	_roster_selected_unit = unit_nd
	_refresh_ui_list()
	battlefield.rebuild_grid()
	if battlefield.has_method("coop_enet_sync_after_local_prebattle_layout_change"):
		battlefield.coop_enet_sync_after_local_prebattle_layout_change()


func _run_deploy_left_at_pos(pos: Vector2i, is_double_click: bool) -> void:
	if current_mode != DeployMode.UNIT:
		return
	var layout_changed := false
	var clicked_unit: Node2D = battlefield.get_unit_at(pos)
	if is_double_click and clicked_unit != null and is_instance_valid(clicked_unit) and clicked_unit.visible:
		if battlefield.is_local_player_command_blocked_for_mock_coop_unit(clicked_unit):
			battlefield.notify_mock_coop_remote_command_blocked(clicked_unit)
			return
		if not _try_toggle_unit_bench_deploy(clicked_unit):
			return
		_roster_selected_unit = clicked_unit
		_refresh_ui_list()
		var benched_idx: int = _roster_index_for_unit(clicked_unit)
		if benched_idx >= 0:
			_set_deploy_roster_selection(benched_idx)
		else:
			_set_deploy_roster_selection(-1)
		battlefield.rebuild_grid()
		if battlefield.has_method("coop_enet_sync_after_local_prebattle_layout_change"):
			battlefield.coop_enet_sync_after_local_prebattle_layout_change()
		return
	if selected_unit == null:
		if clicked_unit != null:
			if not battlefield.try_allow_local_player_select_unit_for_command(clicked_unit):
				return
			selected_unit = clicked_unit
			selected_unit.set_selected_glow(true)
			battlefield.play_ui_sfx(battlefield.UISfx.MOVE_OK)
			if _maybe_quick_fill_for_armed(clicked_unit):
				pass
	else:
		if not _slot_allowed_for_unit(selected_unit, pos):
			_show_deploy_hint("This tile is not valid for this unit.", true)
			return
		if not selected_unit.visible:
			if clicked_unit != null:
				_show_deploy_hint("Tile blocked by another unit.", true)
				return
			if _get_barricade(pos) != null:
				_show_deploy_hint("Tile blocked.", true)
				return
			if _get_deployed_count() >= max_deployment:
				_show_deploy_hint("Deployment band is full (%d / %d)." % [_get_deployed_count(), max_deployment], true)
				return
			var placed_from_bench: Node2D = selected_unit
			selected_unit.global_position = _grid_to_world(pos)
			selected_unit.visible = true
			selected_unit.process_mode = Node.PROCESS_MODE_INHERIT
			battlefield.play_ui_sfx(battlefield.UISfx.TARGET_OK)
			layout_changed = true
			_deselect()
			_refresh_ui_list()
			battlefield.rebuild_grid()
			if CampaignManager.battle_deploy_auto_arm_after_place:
				_arm_next_benched_after_place(placed_from_bench)
			if layout_changed and battlefield.has_method("coop_enet_sync_after_local_prebattle_layout_change"):
				battlefield.coop_enet_sync_after_local_prebattle_layout_change()
			return
		if clicked_unit != null and clicked_unit != selected_unit:
			if battlefield.is_local_player_command_blocked_for_mock_coop_unit(clicked_unit):
				battlefield.notify_mock_coop_remote_command_blocked(clicked_unit)
				return
			if battlefield.is_local_player_command_blocked_for_mock_coop_unit(selected_unit):
				battlefield.notify_mock_coop_remote_command_blocked(selected_unit)
				return
			var tmp: Vector2 = selected_unit.global_position
			selected_unit.global_position = clicked_unit.global_position
			clicked_unit.global_position = tmp
			battlefield.play_ui_sfx(battlefield.UISfx.TARGET_OK)
			layout_changed = true
		elif clicked_unit == null and _get_barricade(pos) == null:
			if battlefield.is_local_player_command_blocked_for_mock_coop_unit(selected_unit):
				battlefield.notify_mock_coop_remote_command_blocked(selected_unit)
				return
			selected_unit.global_position = _grid_to_world(pos)
			battlefield.play_ui_sfx(battlefield.UISfx.TARGET_OK)
			layout_changed = true
		_deselect()
	_refresh_ui_list()
	battlefield.rebuild_grid()
	if layout_changed and battlefield.has_method("coop_enet_sync_after_local_prebattle_layout_change"):
		battlefield.coop_enet_sync_after_local_prebattle_layout_change()


func handle_input(event: InputEvent) -> void:
	if battlefield == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if _handle_prebattle_key(event as InputEventKey):
			battlefield.get_viewport().set_input_as_handled()
			return
	if not event is InputEventMouseButton or not event.pressed:
		return
	var pos: Vector2i = battlefield.cursor_grid_pos
	if not _is_deployment_tile(pos):
		if (
			event.button_index == MOUSE_BUTTON_LEFT
			and current_mode == DeployMode.UNIT
			and selected_unit != null
			and is_instance_valid(selected_unit)
		):
			if battlefield.is_local_player_command_blocked_for_mock_coop_unit(selected_unit):
				battlefield.notify_mock_coop_remote_command_blocked(selected_unit)
				_show_deploy_hint("Co-op: you cannot command this unit.", true)
				return
			var snap: Vector2i = _nearest_deployment_action_slot(pos, selected_unit)
			if snap.x < 0:
				_show_deploy_hint("No valid deployment tile nearby.", true)
				return
			if selected_unit.visible and snap == battlefield.get_grid_pos(selected_unit):
				_show_deploy_hint("Already standing on the snapped tile.", true)
				return
			pos = snap
		else:
			return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if current_mode == DeployMode.BUILD and _try_pickup_structure(pos):
			return
		if current_mode == DeployMode.BUILD and not active_structure.is_empty():
			var type_str: String = str(active_structure.get("type", ""))
			if active_structure.get("count", 0) > 0 and _can_build_here(pos, type_str):
				var scene_path: Variant = active_structure.get("scene_path")
				if scene_path:
					var packed: PackedScene = load(str(scene_path)) as PackedScene
					if packed:
						var new_struct: Node = packed.instantiate()
						new_struct.set_meta("structure_name", active_structure.get("name", ""))
						if type_str == "barricade" or type_str == "spawner":
							battlefield.destructibles_container.add_child(new_struct)
						else:
							var fortresses: Node = battlefield.get_node_or_null("Fortresses")
							if fortresses:
								fortresses.add_child(new_struct)
						if new_struct is Node2D:
							(new_struct as Node2D).position = _grid_to_world(pos)
						active_structure["count"] = active_structure.get("count", 1) - 1
						battlefield.play_ui_sfx(battlefield.UISfx.TARGET_OK)
						if active_structure.get("count", 0) <= 0:
							active_structure = {}
							if roster_list:
								roster_list.deselect_all()
						_refresh_ui_list()
						battlefield.rebuild_grid()
			else:
				_show_deploy_hint("Cannot build here.", true)
			return

		if current_mode == DeployMode.UNIT:
			_run_deploy_left_at_pos(pos, event.double_click)
		return

	if event.button_index == MOUSE_BUTTON_RIGHT:
		active_structure = {}
		_deselect()
		_roster_selected_unit = null
		if roster_list:
			roster_list.deselect_all()
		_set_deploy_roster_selection(-1)
		battlefield.play_ui_sfx(battlefield.UISfx.INVALID)
		_refresh_ui_list()


func _deselect() -> void:
	if selected_unit != null and is_instance_valid(selected_unit):
		selected_unit.set_selected_glow(false)
	selected_unit = null


func _can_build_here(pos: Vector2i, type: String) -> bool:
	if type == "barricade" or type == "spawner":
		return battlefield.get_occupant_at(pos) == null
	if type == "fortress":
		return _get_barricade(pos) == null and _get_fortress(pos) == null
	return false


func _try_pickup_structure(pos: Vector2i) -> bool:
	var clicked_obj: Node2D = _get_barricade(pos)
	if clicked_obj == null:
		clicked_obj = _get_fortress(pos)
	if clicked_obj == null or not clicked_obj.has_meta("structure_name"):
		return false
	var s_name: String = str(clicked_obj.get_meta("structure_name"))
	for struct: Variant in CampaignManager.player_structures:
		if struct is Dictionary and struct.get("name", "") == s_name:
			struct["count"] = struct.get("count", 0) + 1
			clicked_obj.queue_free()
			battlefield.play_ui_sfx(battlefield.UISfx.INVALID)
			_refresh_ui_list()
			battlefield.rebuild_grid()
			return true
	return false


func _get_barricade(pos: Vector2i) -> Node2D:
	var container: Node = battlefield.get("destructibles_container")
	if container == null:
		return null
	for d in container.get_children():
		if battlefield.get_grid_pos(d) == pos and not d.is_queued_for_deletion():
			return d
	return null


func _get_fortress(pos: Vector2i) -> Node2D:
	var fc: Node = battlefield.get_node_or_null("Fortresses")
	if fc == null:
		return null
	for f in fc.get_children():
		if battlefield.get_grid_pos(f) == pos and not f.is_queued_for_deletion():
			return f
	return null
