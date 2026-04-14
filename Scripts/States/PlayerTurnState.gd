# PlayerTurnState.gd
#
# Handles player input during player phase: unit selection, move, attack/forecast,
# defend, trade, and chest open. Entry: handle_input(event). Clear selection via
# clear_active_unit() or ui_cancel / right-click.

extends GameState
class_name PlayerTurnState

const CombatTurnHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCombatTurnHelpers.gd")
const UNIT_HOTKEY_MAX: int = 6

var is_waiting_for_defend_confirm: bool = false
var active_unit: Node2D = null
var original_pos: Vector2i = Vector2i.ZERO
var is_forecasting: bool = false
var targeted_enemy: Node2D = null
var trade_target_ally: Node2D = null


func _sync_local_finish_turn(unit: Node2D) -> void:
	if battlefield == null or unit == null or not is_instance_valid(unit):
		return
	if battlefield.has_method("coop_enet_sync_after_local_finish_turn"):
		battlefield.coop_enet_sync_after_local_finish_turn(unit)


func clear_active_unit() -> void:
	"""Clears the current unit selection, resets defend flow, and rebuilds grid/ranges."""
	if is_instance_valid(active_unit):
		active_unit.set_selected_glow(false)
		active_unit.set_selected(false)
	active_unit = null
	is_waiting_for_defend_confirm = false
	if battlefield != null:
		battlefield.rebuild_grid()
		battlefield.clear_ranges()


func handle_input(event: InputEvent) -> void:
	if battlefield == null:
		return

	# --- Toggle danger zone ---
	if event is InputEventKey and event.keycode == KEY_SHIFT and event.pressed and not event.echo:
		battlefield.toggle_danger_zone()
		return

	if battlefield.has_method("is_mock_partner_placeholder_active") and battlefield.is_mock_partner_placeholder_active():
		return

	# --- Numeric hotkeys: 1..6 select player units quickly ---
	if event is InputEventKey and event.pressed and not event.echo:
		var hotkey_slot: int = _unit_hotkey_slot_from_key(event as InputEventKey)
		if hotkey_slot >= 0:
			_handle_unit_hotkey_select(hotkey_slot)
			return

	# --- Undo / deselect (Right-click or Escape) ---
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		if is_forecasting:
			return
		if battlefield.trade_popup.visible:
			battlefield.hide_trade_popup()
			trade_target_ally = null
			return
		if active_unit != null:
			if active_unit.get("in_canto_phase") == true:
				active_unit.in_canto_phase = false
				active_unit.canto_move_budget = 0
				active_unit.finish_turn()
				_sync_local_finish_turn(active_unit)
				battlefield.play_ui_sfx(BattleField.UISfx.INVALID)
				clear_active_unit()
				return
			if active_unit.has_moved:
				active_unit.position = Vector2(original_pos.x * battlefield.CELL_SIZE.x, original_pos.y * battlefield.CELL_SIZE.y)
				active_unit.has_moved = false
				active_unit.move_points_used_this_turn = 0
			battlefield.play_ui_sfx(BattleField.UISfx.INVALID)
			clear_active_unit()
		else:
			battlefield.inspected_unit = null
			battlefield.clear_ranges()
		return

	# --- Forecasting: confirm or cancel with click ---
	if is_forecasting:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if targeted_enemy != null and is_instance_valid(targeted_enemy) and battlefield.cursor_grid_pos == battlefield.get_grid_pos(targeted_enemy):
					battlefield.play_ui_sfx(BattleField.UISfx.TARGET_OK)
					battlefield._on_forecast_confirm()
				else:
					battlefield.play_ui_sfx(BattleField.UISfx.INVALID)
					if battlefield.battle_log and battlefield.battle_log.visible:
						battlefield.add_combat_log("Forecast: click the enemy tile to confirm, or right-click to cancel.", "gray")
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				battlefield._on_forecast_cancel()
		return

	# --- Left click only from here ---
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return

	var cursor_pos: Vector2i = battlefield.cursor_grid_pos

	if battlefield.trade_popup.visible:
		battlefield.hide_trade_popup()
		trade_target_ally = null

	# --- No unit selected: try select unit or show enemy threat ---
	if active_unit == null:
		_handle_click_with_no_selection(cursor_pos)
		return

	# --- Unit selected: same tile = defend, else move or action ---
	if battlefield.get_grid_pos(active_unit) == cursor_pos:
		_handle_defend_click()
		return

	is_waiting_for_defend_confirm = false

	# --- Action targeting (ally trade, chest, enemy/heal) ---
	var target_node: Node2D = battlefield.get_occupant_at(cursor_pos)
	if target_node != null and target_node != active_unit:
		var handled: bool = await _handle_action_target_click(cursor_pos, target_node)
		if handled:
			return

	# Another input pass may have cleared selection while we awaited forecast / combat UI.
	if active_unit == null or not is_instance_valid(active_unit):
		return

	# --- Move ---
	if active_unit.has_moved and active_unit.get("in_canto_phase") != true:
		battlefield.play_ui_sfx(BattleField.UISfx.INVALID)
		if battlefield.battle_log and battlefield.battle_log.visible:
			battlefield.add_combat_log("Already moved — attack/heal a valid target, Wait/Defend on this unit, or cancel.", "gray")
		clear_active_unit()
		return

	var start_pos: Vector2i = battlefield.get_grid_pos(active_unit)
	var path: Array = battlefield.get_unit_path(active_unit, start_pos, cursor_pos)
	var in_canto_move: bool = active_unit.get("in_canto_phase") == true
	var move_range_val: float = float(active_unit.canto_move_budget) if in_canto_move else float(active_unit.move_range)
	var path_cost: float = battlefield.get_path_move_cost(path, active_unit) if path.size() > 0 else 0.0

	var move_ok: bool = (
		path.size() > 0
		and path_cost <= move_range_val
		and battlefield.reachable_tiles.has(cursor_pos)
	)
	if not move_ok:
		battlefield.play_ui_sfx(BattleField.UISfx.INVALID)
		if battlefield.battle_log and battlefield.battle_log.visible:
			battlefield.add_combat_log("Can't move there — blocked, out of range, or not a blue tile.", "gray")
		clear_active_unit()
		return

	# Snapshot: handle_input is invoked without await from BattleField, so another click can clear
	# active_unit while we await move_along_path — always mutate the unit that actually moved.
	var moving_unit: Node2D = active_unit
	if moving_unit == null or not is_instance_valid(moving_unit):
		return
	battlefield.play_ui_sfx(BattleField.UISfx.MOVE_OK)
	battlefield.clear_ranges()
	await moving_unit.move_along_path(path)
	if not is_instance_valid(moving_unit):
		return
	if in_canto_move:
		if battlefield.has_method("coop_enet_sync_after_local_player_move"):
			battlefield.coop_enet_sync_after_local_player_move(moving_unit, path, path_cost, true)
		moving_unit.in_canto_phase = false
		moving_unit.canto_move_budget = 0
		moving_unit.finish_turn()
		clear_active_unit()
		return
	moving_unit.move_points_used_this_turn += path_cost
	battlefield.update_fog_of_war()
	battlefield.rebuild_grid()
	if active_unit == moving_unit and is_instance_valid(active_unit):
		battlefield.calculate_ranges(active_unit)
	else:
		battlefield.clear_ranges()
	if battlefield.has_method("coop_enet_sync_after_local_player_move"):
		battlefield.coop_enet_sync_after_local_player_move(moving_unit, path, path_cost, false)


func _handle_click_with_no_selection(cursor_pos: Vector2i) -> void:
	var unit: Node2D = battlefield.get_unit_at(cursor_pos)
	var enemy: Node2D = battlefield.get_enemy_at(cursor_pos)
	var occupant: Node2D = battlefield.get_occupant_at(cursor_pos)

	if unit != null and not unit.is_exhausted:
		_select_player_unit_for_command(unit)
	elif occupant != null and occupant.get("data") != null:
		battlefield.inspected_unit = occupant
		if PersonalJournalStore:
			PersonalJournalStore.note_inspected_unit_for_journal(occupant)
		battlefield.play_ui_sfx(BattleField.UISfx.MOVE_OK)
		if occupant == enemy and battlefield.can_preview_enemy_threat(enemy):
			battlefield.calculate_enemy_threat_range(enemy)
		else:
			battlefield.clear_ranges()
	elif enemy != null:
		battlefield.inspected_unit = enemy
		if PersonalJournalStore:
			PersonalJournalStore.note_inspected_unit_for_journal(enemy)
		battlefield.play_ui_sfx(BattleField.UISfx.MOVE_OK)
		if battlefield.can_preview_enemy_threat(enemy):
			battlefield.calculate_enemy_threat_range(enemy)
		else:
			battlefield.clear_ranges()
	else:
		battlefield.inspected_unit = null
		battlefield.play_ui_sfx(BattleField.UISfx.INVALID)
		battlefield.clear_ranges()


func _unit_hotkey_slot_from_key(ev: InputEventKey) -> int:
	match ev.keycode:
		KEY_1, KEY_KP_1:
			return 0
		KEY_2, KEY_KP_2:
			return 1
		KEY_3, KEY_KP_3:
			return 2
		KEY_4, KEY_KP_4:
			return 3
		KEY_5, KEY_KP_5:
			return 4
		KEY_6, KEY_KP_6:
			return 5
		_:
			return -1


func _hotkey_selectable_player_units() -> Array[Node2D]:
	var out: Array[Node2D] = []
	if battlefield == null or battlefield.player_container == null:
		return out
	for child in battlefield.player_container.get_children():
		var unit: Node2D = child as Node2D
		if unit == null or not is_instance_valid(unit) or unit.is_queued_for_deletion():
			continue
		if unit.visible == false:
			continue
		if unit.get("current_hp") != null and int(unit.current_hp) <= 0:
			continue
		if unit.get("is_exhausted") == true:
			continue
		if battlefield.is_local_player_command_blocked_for_mock_coop_unit(unit):
			continue
		out.append(unit)
		if out.size() >= UNIT_HOTKEY_MAX:
			break
	return out


func _handle_unit_hotkey_select(hotkey_slot: int) -> void:
	if battlefield == null:
		return
	if is_forecasting:
		return
	var units: Array[Node2D] = _hotkey_selectable_player_units()
	if hotkey_slot < 0 or hotkey_slot >= units.size():
		return
	var target_unit: Node2D = units[hotkey_slot]
	if target_unit == null or not is_instance_valid(target_unit):
		return
	if active_unit != null and is_instance_valid(active_unit):
		if active_unit == target_unit:
			return
		# Hotkey cycling should swap armed selection without forcing movement undo.
		clear_active_unit()
	_select_player_unit_for_command(target_unit)


func _select_player_unit_for_command(unit: Node2D) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not battlefield.try_allow_local_player_select_unit_for_command(unit):
		return
	battlefield.inspected_unit = null
	active_unit = unit
	original_pos = battlefield.get_grid_pos(active_unit)
	active_unit.set_selected_glow(true)
	battlefield.astar.set_point_solid(original_pos, false)
	battlefield.calculate_ranges(active_unit)
	if battlefield.select_sound != null and battlefield.select_sound.stream != null:
		battlefield.select_sound.pitch_scale = randf_range(0.95, 1.05)
		battlefield.select_sound.play()


func _handle_defend_click() -> void:
	if not is_waiting_for_defend_confirm:
		is_waiting_for_defend_confirm = true
		battlefield.play_ui_sfx(BattleField.UISfx.MOVE_OK)
		battlefield.spawn_loot_text("DEFEND?", Color.YELLOW, active_unit.global_position + Vector2(32, -32))
		return

	if battlefield.defend_sound != null:
		battlefield.defend_sound.pitch_scale = randf_range(0.9, 1.1)
		battlefield.defend_sound.play()
	active_unit.trigger_defend()
	battlefield.animate_shield_drop(active_unit)
	if battlefield.has_method("coop_enet_sync_after_local_defend"):
		battlefield.coop_enet_sync_after_local_defend(active_unit)
	clear_active_unit()


func _handle_action_target_click(cursor_pos: Vector2i, target_node: Node2D) -> bool:
	if active_unit.get("in_canto_phase") == true:
		battlefield.play_ui_sfx(BattleField.UISfx.INVALID)
		if battlefield.battle_log and battlefield.battle_log.visible:
			battlefield.add_combat_log("Canto: use leftover movement only — no second attack.", "gray")
		return false

	var wpn: Resource = active_unit.equipped_weapon
	var targets_allies: bool = wpn != null and (wpn.get("is_healing_staff") == true or wpn.get("is_buff_staff") == true)

	var parent_node: Node = target_node.get_parent()
	var parent_name: String = parent_node.name if parent_node != null else ""

	# --- Clicked on ally: heal (fall through) or trade ---
	if parent_name == "PlayerUnits":
		if targets_allies:
			pass
		elif battlefield.get_distance(active_unit, target_node) == 1:
			if battlefield.is_local_player_command_blocked_for_mock_coop_unit(target_node):
				battlefield.notify_mock_coop_remote_command_blocked(target_node)
				return true
			battlefield.play_ui_sfx(BattleField.UISfx.MOVE_OK)
			trade_target_ally = target_node
			battlefield.show_trade_popup(target_node)
			return true
		else:
			battlefield.play_ui_sfx(BattleField.UISfx.INVALID)
			if battlefield.battle_log and battlefield.battle_log.visible:
				battlefield.add_combat_log("Stand adjacent to an ally to trade or support talk.", "gray")
			return false

	# --- Clicked on chest ---
	if target_node is TreasureChest:
		if battlefield.get_distance(active_unit, target_node) == 1:
			battlefield.play_ui_sfx(BattleField.UISfx.TARGET_OK)
			battlefield._on_chest_opened(target_node, active_unit)
			active_unit.finish_turn()
			_sync_local_finish_turn(active_unit)
			clear_active_unit()
		else:
			battlefield.play_ui_sfx(BattleField.UISfx.INVALID)
		return true

	# --- Clicked on enemy or healable target in range ---
	if not battlefield.is_in_range(active_unit, target_node):
		battlefield.play_ui_sfx(BattleField.UISfx.INVALID)
		if battlefield.battle_log and battlefield.battle_log.visible:
			battlefield.add_combat_log("Target is outside weapon range.", "gray")
		return false

	battlefield.play_ui_sfx(BattleField.UISfx.TARGET_OK)
	is_forecasting = true
	targeted_enemy = target_node
	if PersonalJournalStore:
		PersonalJournalStore.note_inspected_unit_for_journal(target_node)

	var forecast_data: Array = await battlefield.show_combat_forecast(active_unit, target_node)

	is_forecasting = false
	targeted_enemy = null

	if forecast_data.size() < 2:
		return true

	var action: String = str(forecast_data[0])
	var used_ability: bool = bool(forecast_data[1])

	if action == "cancel":
		return true
	if action == "active_ability":
		var pending_aid: String = str(battlefield._forecast_pending_active_ability_id).strip_edges()
		battlefield._forecast_pending_active_ability_id = ""
		return await CombatTurnHelpers.resolve_player_active_ability_after_forecast(
			battlefield,
			self,
			active_unit,
			target_node,
			pending_aid
		)
	if action == "talk":
		battlefield.execute_talk(active_unit, target_node)
		if is_instance_valid(battlefield) and battlefield.is_inside_tree() and battlefield.get_tree().paused:
			while is_instance_valid(battlefield) and battlefield.get_tree().paused:
				await battlefield.get_tree().process_frame
		if is_instance_valid(active_unit):
			active_unit.finish_turn()
			_sync_local_finish_turn(active_unit)
		clear_active_unit()
		return true
	if action != "confirm":
		return true

	return await CombatTurnHelpers.resolve_confirmed_player_combat_after_forecast(
		battlefield,
		self,
		active_unit,
		target_node,
		used_ability
	)
