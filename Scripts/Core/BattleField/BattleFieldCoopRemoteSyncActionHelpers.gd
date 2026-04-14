extends RefCounted

# ENet mock co-op: remote sync queue action dispatcher + per-action handlers — extracted from `BattleField.gd`.

static func coop_run_one_remote_sync_async(field, body: Dictionary) -> void:
	var wg: int = int(body.get("_coop_wire_gen", 0))
	if wg < int(field._coop_full_resync_generation):
		if OS.is_debug_build():
			push_warning(
				"Coop: dropped stale remote sync (action=%s wire_gen=%d battle_gen=%d)"
				% [str(body.get("action", "")), wg, int(field._coop_full_resync_generation)]
			)
		field._coop_enet_remote_sync_busy = false
		field._coop_enet_pump_remote_sync_queue()
		return
	var action: String = str(body.get("action", "")).strip_edges()
	match action:
		"battle_result":
			await coop_remote_sync_battle_result(field, body)
		"escort_turn":
			await coop_remote_sync_escort_turn(field, body)
		"enemy_phase_setup":
			coop_remote_sync_enemy_phase_setup(field, body)
		"enemy_turn_move":
			await coop_remote_sync_enemy_turn_move(field, body)
		"enemy_turn_combat":
			await coop_remote_sync_enemy_turn_combat(field, body)
		"enemy_turn_finish":
			await coop_remote_sync_enemy_turn_finish(field, body)
		"enemy_turn_chest_open":
			await coop_remote_sync_enemy_turn_chest_open(field, body)
		"enemy_turn_escape":
			await coop_remote_sync_enemy_turn_escape(field, body)
		"enemy_turn_end":
			coop_remote_sync_enemy_turn_end(field, body)
		"enemy_turn_batch_move":
			await coop_remote_sync_enemy_turn_batch_move(field, body)
		"prebattle_layout":
			coop_remote_sync_prebattle_layout(field, body)
		"prebattle_ready":
			coop_remote_sync_prebattle_ready(field, body)
		"player_move":
			await coop_remote_sync_player_move(field, body)
		"player_defend":
			coop_remote_sync_player_defend(field, body)
		"player_combat":
			await coop_remote_sync_player_combat(field, body)
		"player_post_combat":
			coop_remote_sync_player_post_combat(field, body)
		"player_finish_turn":
			coop_remote_sync_player_finish_turn(field, body)
		"player_phase_ready":
			coop_remote_sync_player_phase_ready(field, body)
		_:
			if OS.is_debug_build():
				push_warning("Coop battle sync: unknown action '%s'" % action)
	field._coop_enet_remote_sync_busy = false
	field._coop_enet_pump_remote_sync_queue()


static func coop_remote_sync_enemy_phase_setup(field, body: Dictionary) -> void:
	var raw: Variant = body.get("setup", {})
	if raw is Dictionary:
		field._coop_apply_enemy_phase_setup_snapshot(raw as Dictionary)


static func coop_remote_sync_battle_result(field, body: Dictionary) -> void:
	var normalized: String = field._coop_normalize_battle_result(str(body.get("result", "")))
	if normalized == "":
		return
	if field._coop_finalized_battle_result != "":
		return
	await field._wait_for_loot_window_close()
	field._coop_waiting_for_host_battle_result = ""
	field._coop_remote_battle_result_applying = true
	if normalized == "VICTORY":
		await field._trigger_victory()
	else:
		field.trigger_game_over(normalized)
	field._coop_remote_battle_result_applying = false


static func coop_remote_sync_escort_turn(field, body: Dictionary) -> void:
	if not is_instance_valid(field.vip_target):
		return
	var path_raw: Variant = body.get("path", [])
	var path_typed: Array[Vector2i] = []
	if path_raw is Array:
		for item in path_raw as Array:
			if item is Array:
				var arr: Array = item as Array
				if arr.size() >= 2:
					path_typed.append(Vector2i(int(arr[0]), int(arr[1])))
			elif item is Dictionary:
				var d: Dictionary = item as Dictionary
				path_typed.append(Vector2i(int(d.get("x", 0)), int(d.get("y", 0))))
	var convoy: Node2D = field.vip_target
	for i in range(1, path_typed.size()):
		var step_grid: Vector2i = path_typed[i]
		var tween: Tween = (field as Node2D).create_tween()
		tween.tween_property(convoy, "global_position", Vector2(step_grid.x * field.CELL_SIZE.x, step_grid.y * field.CELL_SIZE.y), 0.25).set_trans(Tween.TRANS_LINEAR)
		if field.select_sound != null and field.select_sound.stream != null:
			field.select_sound.pitch_scale = 0.8
			field.select_sound.play()
		await tween.finished
		field.rebuild_grid()
	if path_typed.is_empty():
		var marker_idx_now: int = int(body.get("current_marker_idx", int(convoy.get("current_marker_idx"))))
		if marker_idx_now >= 0:
			convoy.set("current_marker_idx", marker_idx_now)
	if body.has("current_hp"):
		convoy.set("current_hp", int(body.get("current_hp", convoy.get("current_hp"))))
	if body.has("has_moved"):
		convoy.set("has_moved", bool(body.get("has_moved", convoy.get("has_moved"))))
	if body.has("is_exhausted"):
		convoy.set("is_exhausted", bool(body.get("is_exhausted", convoy.get("is_exhausted"))))
	if body.has("current_marker_idx"):
		convoy.set("current_marker_idx", int(body.get("current_marker_idx", convoy.get("current_marker_idx"))))
	if convoy.get("health_bar") != null:
		convoy.health_bar.value = int(convoy.get("current_hp"))
	field.rebuild_grid()
	field.update_fog_of_war()
	field.update_objective_ui()
	field._coop_remote_escort_turn_completed = true
	field.coop_remote_escort_turn_finished.emit()


static func coop_remote_sync_enemy_turn_move(field, body: Dictionary) -> void:
	await field._coop_wait_for_enemy_state_ready()
	var uid: String = str(body.get("unit_id", "")).strip_edges()
	var path_raw: Variant = body.get("path", [])
	var path_typed: Array[Vector2i] = []
	if path_raw is Array:
		for item in path_raw as Array:
			if item is Array:
				var a: Array = item as Array
				if a.size() >= 2:
					path_typed.append(Vector2i(int(a[0]), int(a[1])))
			elif item is Dictionary:
				var d: Dictionary = item as Dictionary
				path_typed.append(Vector2i(int(d.get("x", 0)), int(d.get("y", 0))))
	if path_typed.size() < 2:
		return
	var unit: Node2D = field._coop_find_unit_by_relationship_id_any_side(uid)
	if unit == null or not is_instance_valid(unit):
		return
	await field._coop_focus_camera_on_unit(unit, 0.55)
	await unit.move_along_path(path_typed)
	unit.move_points_used_this_turn = float(body.get("path_cost", field.get_path_move_cost(path_typed, unit)))
	field.rebuild_grid()
	field.update_fog_of_war()


static func coop_remote_sync_enemy_turn_combat(field, body: Dictionary) -> void:
	await field._coop_wait_for_enemy_state_ready()
	var aid: String = str(body.get("attacker_id", "")).strip_edges()
	var did: String = str(body.get("defender_id", "")).strip_edges()
	var att: Node2D = field._coop_find_unit_by_relationship_id_any_side(aid)
	var defu: Node2D = field._coop_find_unit_by_relationship_id_any_side(did)
	if att == null or defu == null or not is_instance_valid(att) or not is_instance_valid(defu):
		if OS.is_debug_build():
			push_warning("Coop enemy turn sync: combat resolve failed ids att=%s def=%s" % [aid, did])
		return
	await field._coop_focus_camera_on_action(att, defu, 0.4)
	var rp: int = int(body.get("rng_packed", -1))
	var qte_raw: Variant = body.get("qte_snapshot", {})
	await field._coop_execute_remote_combat_replay(att, defu, bool(body.get("used_ability", false)), qte_raw, rp)
	var auth_v: int = int(body.get("auth_v", 0))
	var auth_raw: Variant = body.get("auth_snapshot", {})
	if auth_raw is Dictionary and auth_v == field.COOP_AUTH_BATTLE_SNAPSHOT_VER and (auth_raw as Dictionary).size() > 0:
		field._coop_apply_authoritative_combat_snapshot(auth_raw as Dictionary)
	field._coop_apply_remote_synced_enemy_death_loot_events(body.get("loot_events", []))
	var spoils_raw: Variant = body.get("destructible_spoils", {})
	if spoils_raw is Dictionary and is_instance_valid(att):
		var spoils: Dictionary = spoils_raw as Dictionary
		var gold_delta: int = int(spoils.get("gold", 0))
		var items: Array = field._coop_wire_deserialize_items(spoils.get("items", []))
		if gold_delta > 0 and att.get("stolen_gold") != null:
			att.stolen_gold += gold_delta
		if not items.is_empty() and att.get("stolen_loot") != null:
			att.stolen_loot.append_array(items)
		if (gold_delta > 0 or not items.is_empty()) and field.battle_log != null and field.battle_log.visible:
			var destroyed_name: String = str(body.get("destructible_name", "a crate"))
			field.add_combat_log(att.unit_name + " destroyed " + destroyed_name + " and took the loot!", "tomato")
			field.spawn_loot_text("STOLEN!", Color.TOMATO, att.global_position + Vector2(32, -32))
	await field._wait_for_loot_window_close()


static func coop_remote_sync_enemy_turn_finish(field, body: Dictionary) -> void:
	await field._coop_wait_for_enemy_state_ready()
	var uid: String = str(body.get("unit_id", "")).strip_edges()
	var unit: Node2D = field._coop_find_unit_by_relationship_id_any_side(uid)
	if unit == null or not is_instance_valid(unit):
		return
	if unit.has_method("finish_turn"):
		unit.finish_turn()
	field.rebuild_grid()


static func coop_remote_sync_enemy_turn_chest_open(field, body: Dictionary) -> void:
	await field._coop_wait_for_enemy_state_ready()
	var opener_id: String = str(body.get("opener_id", "")).strip_edges()
	var chest_id: String = str(body.get("chest_id", "")).strip_edges()
	var opener: Node2D = field._coop_find_unit_by_relationship_id_any_side(opener_id)
	var chest: Node2D = field._coop_find_unit_by_relationship_id_any_side(chest_id)
	if opener == null or chest == null or not is_instance_valid(opener) or not is_instance_valid(chest):
		return
	opener.look_at_pos(field.get_grid_pos(chest))
	if chest.has_method("play_open_effect"):
		await chest.play_open_effect()
	elif is_instance_valid(chest):
		chest.queue_free()
	var stolen_items: Array = field._coop_wire_deserialize_items(body.get("stolen_items", []))
	if not stolen_items.is_empty() and opener.get("stolen_loot") != null:
		opener.stolen_loot.append_array(stolen_items)
	if field.battle_log != null and field.battle_log.visible:
		field.add_combat_log(opener.unit_name + " picked the lock and stole the contents!", "tomato")
		field.spawn_loot_text("STOLEN!", Color.TOMATO, opener.global_position + Vector2(32, -32))
	field.rebuild_grid()
	field.update_fog_of_war()
	field.update_objective_ui()


static func coop_remote_sync_enemy_turn_escape(field, body: Dictionary) -> void:
	await field._coop_wait_for_enemy_state_ready()
	var uid: String = str(body.get("unit_id", "")).strip_edges()
	var unit: Node2D = field._coop_find_unit_by_relationship_id_any_side(uid)
	if unit == null or not is_instance_valid(unit):
		return
	if field.battle_log != null and field.battle_log.visible:
		field.add_combat_log(unit.unit_name + " escaped the map with the loot!", "tomato")
	var tween: Tween = (field as Node2D).create_tween()
	tween.tween_property(unit, "modulate:a", 0.0, 0.3)
	await tween.finished
	if is_instance_valid(unit):
		unit.queue_free()
	field.rebuild_grid()
	field.update_fog_of_war()
	field.update_objective_ui()


static func coop_remote_sync_enemy_turn_end(field, _body: Dictionary) -> void:
	field._coop_remote_enemy_turn_completed = true
	field.coop_remote_enemy_turn_finished.emit()


static func coop_do_batch_unit_move_async(field, unit: Node2D, path: Array[Vector2i], path_cost: Variant, on_done: Callable) -> void:
	if not is_instance_valid(unit) or path.size() < 2:
		on_done.call()
		return
	await unit.move_along_path(path)
	if is_instance_valid(unit):
		unit.move_points_used_this_turn = float(path_cost) if path_cost != null else field.get_path_move_cost(path, unit)
	on_done.call()


static func coop_remote_sync_enemy_turn_batch_move(field, body: Dictionary) -> void:
	await field._coop_wait_for_enemy_state_ready()
	var entries_raw: Variant = body.get("entries", [])
	if not (entries_raw is Array):
		return
	var entries: Array = entries_raw as Array
	var pending_left: Array = [0]

	for entry in entries:
		if not (entry is Dictionary):
			continue
		var uid: String = str((entry as Dictionary).get("unit_id", "")).strip_edges()
		var path_raw: Variant = (entry as Dictionary).get("path", [])
		var path_typed: Array[Vector2i] = []
		if path_raw is Array:
			for item in path_raw as Array:
				if item is Array:
					var a: Array = item as Array
					if a.size() >= 2:
						path_typed.append(Vector2i(int(a[0]), int(a[1])))
				elif item is Dictionary:
					var d: Dictionary = item as Dictionary
					path_typed.append(Vector2i(int(d.get("x", 0)), int(d.get("y", 0))))
		if path_typed.size() < 2:
			continue
		var unit: Node2D = field._coop_find_unit_by_relationship_id_any_side(uid)
		if unit == null or not is_instance_valid(unit):
			continue
		pending_left[0] = int(pending_left[0]) + 1
		coop_do_batch_unit_move_async(
			field,
			unit,
			path_typed,
			(entry as Dictionary).get("path_cost", 0),
			func(): pending_left[0] = int(pending_left[0]) - 1
		)

	if int(pending_left[0]) > 0:
		while int(pending_left[0]) > 0:
			await field.get_tree().process_frame
	field.rebuild_grid()
	field.update_fog_of_war()


static func coop_remote_sync_prebattle_layout(field, body: Dictionary) -> void:
	var raw_units: Variant = body.get("units", [])
	if typeof(raw_units) != TYPE_ARRAY:
		return
	var changed_any: bool = false
	for item in raw_units as Array:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item as Dictionary
		var uid: String = str(entry.get("unit_id", "")).strip_edges()
		if uid == "":
			continue
		var unit: Node2D = field._coop_find_player_side_unit_by_relationship_id(uid)
		if unit == null or not is_instance_valid(unit):
			continue
		if field.get_mock_coop_unit_owner_for_unit(unit) != field.MOCK_COOP_OWNER_REMOTE:
			if OS.is_debug_build():
				push_warning("Coop battle sync: refuse prebattle layout for non-partner unit '%s'" % uid)
			continue
		var deployed: bool = bool(entry.get("deployed", false))
		if deployed:
			var pos_raw: Variant = entry.get("grid_pos", {})
			var grid_pos := Vector2i.ZERO
			var have_pos: bool = false
			if typeof(pos_raw) == TYPE_DICTIONARY:
				var pos_dict: Dictionary = pos_raw as Dictionary
				grid_pos = Vector2i(int(pos_dict.get("x", 0)), int(pos_dict.get("y", 0)))
				have_pos = true
			elif pos_raw is Array:
				var pos_arr: Array = pos_raw as Array
				if pos_arr.size() >= 2:
					grid_pos = Vector2i(int(pos_arr[0]), int(pos_arr[1]))
					have_pos = true
			if not have_pos:
				continue
			var allowed_slots: Array[Vector2i] = field.get_mock_coop_allowed_prebattle_slots_for_unit(unit)
			if not allowed_slots.is_empty() and grid_pos not in allowed_slots:
				if OS.is_debug_build():
					push_warning("Coop battle sync: refuse prebattle slot outside unit band '%s' -> %s" % [uid, str(grid_pos)])
				continue
			unit.position = Vector2(grid_pos.x * field.CELL_SIZE.x, grid_pos.y * field.CELL_SIZE.y)
			unit.visible = true
			unit.process_mode = Node.PROCESS_MODE_INHERIT
		else:
			unit.visible = false
			unit.process_mode = Node.PROCESS_MODE_DISABLED
			unit.position = Vector2(field.MOCK_COOP_PREBATTLE_BENCH_OFFSCREEN_XY, field.MOCK_COOP_PREBATTLE_BENCH_OFFSCREEN_XY)
		changed_any = true
	if not changed_any:
		return
	if field._mock_coop_remote_prebattle_ready:
		field._mock_coop_remote_prebattle_ready = false
		field._mock_coop_prebattle_transition_pending = false
		if field.battle_log != null and field.battle_log.visible:
			field.add_combat_log("Co-op: partner updated deployment. Start readiness cleared until they confirm again.", "gold")
		field._update_mock_coop_start_battle_button_state()
	field.rebuild_grid()
	field.queue_redraw()
	if field.current_state == field.pre_battle_state and field.pre_battle_state != null and field.pre_battle_state.has_method("_refresh_ui_list"):
		field.pre_battle_state.call("_refresh_ui_list")


static func coop_remote_sync_prebattle_ready(field, body: Dictionary) -> void:
	var ready_now: bool = bool(body.get("ready", true))
	if not ready_now:
		if not field._mock_coop_remote_prebattle_ready:
			return
		field._mock_coop_remote_prebattle_ready = false
		field._mock_coop_prebattle_transition_pending = false
		if field.battle_log != null and field.battle_log.visible:
			field.add_combat_log("Co-op: partner revised deployment. Waiting for them to press Start again.", "gold")
		field._update_mock_coop_start_battle_button_state()
		return
	if field._mock_coop_remote_prebattle_ready:
		return
	field._mock_coop_remote_prebattle_ready = true
	if field.battle_log != null and field.battle_log.visible:
		if field._mock_coop_local_prebattle_ready:
			field.add_combat_log("Co-op: partner commander is ready. Starting the battle.", "gold")
		else:
			field.add_combat_log("Co-op: partner commander is ready to start. Finish deployment and press Start when you are ready.", "gold")
	field._update_mock_coop_start_battle_button_state()
	field._mock_coop_try_advance_prebattle_after_ready_sync()


static func coop_remote_sync_player_move(field, body: Dictionary) -> void:
	var uid: String = str(body.get("unit_id", "")).strip_edges()
	var path_raw: Variant = body.get("path", [])
	var path_typed: Array[Vector2i] = []
	if path_raw is Array:
		for item in path_raw as Array:
			if item is Array:
				var a: Array = item as Array
				if a.size() >= 2:
					path_typed.append(Vector2i(int(a[0]), int(a[1])))
			elif item is Dictionary:
				var d: Dictionary = item as Dictionary
				path_typed.append(Vector2i(int(d.get("x", 0)), int(d.get("y", 0))))
	if path_typed.size() < 2:
		return
	var unit: Node2D = field._coop_find_player_side_unit_by_relationship_id(uid)
	if unit == null or not is_instance_valid(unit):
		if OS.is_debug_build():
			push_warning("Coop battle sync: no unit for id '%s'" % uid)
		return
	if field.get_mock_coop_unit_owner_for_unit(unit) != field.MOCK_COOP_OWNER_REMOTE:
		if OS.is_debug_build():
			push_warning("Coop battle sync: refuse mirror move for non-partner unit '%s'" % uid)
		return
	var path_cost: float = field.get_path_move_cost(path_typed, unit)
	await unit.move_along_path(path_typed)
	if not is_instance_valid(unit) or not is_instance_valid(field):
		return
	unit.move_points_used_this_turn += path_cost
	var unm: String = str(unit.get("unit_name")) if unit.get("unit_name") != null else uid
	if field.battle_log != null and field.battle_log.visible:
		field.add_combat_log("Co-op: %s moved (partner)." % unm, "gray")
	if bool(body.get("finish_after_move", false)) and unit.has_method("finish_turn"):
		unit.finish_turn()
	field.update_fog_of_war()
	field.rebuild_grid()
	if field.current_state == field.player_state and field.player_state != null:
		var au: Node2D = field.player_state.active_unit
		if au != null and au == unit:
			field.player_state.clear_active_unit()


static func coop_remote_sync_player_defend(field, body: Dictionary) -> void:
	var uid: String = str(body.get("unit_id", "")).strip_edges()
	var unit: Node2D = field._coop_find_player_side_unit_by_relationship_id(uid)
	if unit == null or not is_instance_valid(unit):
		return
	if field.get_mock_coop_unit_owner_for_unit(unit) != field.MOCK_COOP_OWNER_REMOTE:
		return
	if field.defend_sound != null and field.defend_sound.stream != null:
		field.defend_sound.pitch_scale = randf_range(0.9, 1.1)
		field.defend_sound.play()
	unit.trigger_defend()
	field.animate_shield_drop(unit)
	if field.battle_log != null and field.battle_log.visible:
		var unm: String = str(unit.get("unit_name")) if unit.get("unit_name") != null else uid
		field.add_combat_log("Co-op: %s defended (partner)." % unm, "gray")
	field.rebuild_grid()
	if field.current_state == field.player_state and field.player_state != null:
		var au: Node2D = field.player_state.active_unit
		if au != null and au == unit:
			field.player_state.clear_active_unit()


## Guest + [code]host_authority[/code]: if we bail out of [code]player_combat[/code] early, still unblock [method coop_enet_guest_delegate_player_combat_to_host].
static func _coop_guest_unblock_awaiting_host_player_combat(field, body: Dictionary, attacker_id: String) -> void:
	if CoopExpeditionSessionManager.phase != CoopExpeditionSessionManager.Phase.GUEST:
		return
	if not bool(body.get("host_authority", false)):
		return
	field._coop_emit_guest_host_combat_resolved_if_waiting(attacker_id)


static func coop_remote_sync_player_combat(field, body: Dictionary) -> void:
	var aid: String = str(body.get("attacker_id", "")).strip_edges()
	var did: String = str(body.get("defender_id", "")).strip_edges()
	var att: Node2D = field._coop_find_unit_by_relationship_id_any_side(aid)
	var defu: Node2D = field._coop_find_unit_by_relationship_id_any_side(did)
	if att == null or defu == null or not is_instance_valid(att) or not is_instance_valid(defu):
		if OS.is_debug_build():
			push_warning("Coop battle sync: combat resolve failed ids att=%s def=%s" % [aid, did])
		_coop_guest_unblock_awaiting_host_player_combat(field, body, aid)
		return
	var owner_att: String = field.get_mock_coop_unit_owner_for_unit(att)
	var host_auth: bool = bool(body.get("host_authority", false))
	var i_am_guest: bool = CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.GUEST
	var partner_mirror: bool = (owner_att == field.MOCK_COOP_OWNER_REMOTE)
	var guest_own_host_auth: bool = (host_auth and i_am_guest and owner_att == field.MOCK_COOP_OWNER_LOCAL)
	if not partner_mirror and not guest_own_host_auth:
		if OS.is_debug_build():
			push_warning("Coop battle sync: refuse combat mirror — attacker ownership mismatch (aid=%s)" % aid)
		_coop_guest_unblock_awaiting_host_player_combat(field, body, aid)
		return
	var auth_v: int = int(body.get("auth_v", 0))
	var auth_raw: Variant = body.get("auth_snapshot", {})
	var has_auth: bool = auth_raw is Dictionary and auth_v == field.COOP_AUTH_BATTLE_SNAPSHOT_VER and (auth_raw as Dictionary).size() > 0
	var rp: int = int(body.get("rng_packed", -1))
	var qte_raw: Variant = body.get("qte_snapshot", {})
	## Host-resolved [ActiveCombatAbilityData] uses snapshots only — never re-run [method BattleField.execute_combat] on the guest.
	var active_ability_only: bool = bool(body.get("active_ability_only", false))
	var should_replay: bool = not active_ability_only and (rp >= 0 or (qte_raw is Dictionary and (qte_raw as Dictionary).size() > 0))
	if should_replay:
		await field._coop_execute_remote_combat_replay(att, defu, bool(body.get("used_ability", false)), qte_raw, rp)
	elif not has_auth:
		if OS.is_debug_build():
			push_warning("Coop battle sync: combat mirror missing replay data and auth_snapshot (aid=%s def=%s)" % [aid, did])
		_coop_guest_unblock_awaiting_host_player_combat(field, body, aid)
		return
	if has_auth:
		var auth_d: Dictionary = auth_raw as Dictionary
		field._coop_apply_authoritative_combat_snapshot(auth_d)
	field._coop_apply_remote_synced_enemy_death_loot_events(body.get("loot_events", []))
	await field._wait_for_loot_window_close()
	if field.battle_log != null and field.battle_log.visible:
		if guest_own_host_auth:
			field.add_combat_log("Co-op: your combat applied (host state).", "gray")
		elif has_auth:
			field.add_combat_log("Co-op: partner combat applied (host state).", "gray")
		else:
			field.add_combat_log("Co-op: partner combat resolved (%s)." % aid, "gray")
	if not bool(body.get("has_post_combat_followup", true)):
		field._coop_emit_guest_host_combat_resolved_if_waiting(aid)


static func coop_remote_sync_player_post_combat(field, body: Dictionary) -> void:
	var aid: String = str(body.get("attacker_id", "")).strip_edges()
	var att: Node2D = field._coop_find_player_side_unit_by_relationship_id(aid)
	if att == null or not is_instance_valid(att):
		var host_auth_dead: bool = bool(body.get("host_authority", false))
		var i_am_guest_dead: bool = CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.GUEST
		if host_auth_dead and i_am_guest_dead:
			field._coop_emit_guest_host_combat_resolved_if_waiting(aid)
		return
	var owner_att: String = field.get_mock_coop_unit_owner_for_unit(att)
	var host_auth: bool = bool(body.get("host_authority", false))
	var i_am_guest: bool = CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.GUEST
	var allow: bool = (owner_att == field.MOCK_COOP_OWNER_REMOTE) or (host_auth and i_am_guest and owner_att == field.MOCK_COOP_OWNER_LOCAL)
	if not allow:
		return
	var follow: String = str(body.get("follow", "finish")).strip_edges()
	if follow == "canto":
		var rem: float = float(body.get("canto_budget", 0.0))
		att.has_moved = true
		att.in_canto_phase = true
		att.canto_move_budget = rem
		if field.battle_log != null and field.battle_log.visible:
			var who: String = "co-op partner" if owner_att == field.MOCK_COOP_OWNER_REMOTE else "host"
			field.add_combat_log(att.unit_name + " — Canto (" + who + ", " + str(snappedf(rem, 0.1)) + " move left).", "cyan")
		field.calculate_ranges(att)
	elif att.has_method("finish_turn"):
		att.finish_turn()
	field.rebuild_grid()
	if follow != "canto" and field.current_state == field.player_state and field.player_state != null and field.player_state.active_unit == att:
		field.player_state.clear_active_unit()
	if host_auth and i_am_guest:
		field._coop_emit_guest_host_combat_resolved_if_waiting(aid)


static func coop_remote_sync_player_finish_turn(field, body: Dictionary) -> void:
	var uid: String = str(body.get("unit_id", "")).strip_edges()
	var unit: Node2D = field._coop_find_player_side_unit_by_relationship_id(uid)
	if unit == null or not is_instance_valid(unit):
		return
	if field.get_mock_coop_unit_owner_for_unit(unit) != field.MOCK_COOP_OWNER_REMOTE:
		return
	if unit.has_method("finish_turn"):
		unit.finish_turn()
	if field.battle_log != null and field.battle_log.visible:
		var unm: String = str(unit.get("unit_name")) if unit.get("unit_name") != null else uid
		field.add_combat_log("Co-op: %s waited / ended turn (partner)." % unm, "gray")
	field.rebuild_grid()
	if field.current_state == field.player_state and field.player_state != null:
		var au: Node2D = field.player_state.active_unit
		if au != null and au == unit:
			field.player_state.clear_active_unit()


static func coop_remote_sync_player_phase_ready(field, body: Dictionary) -> void:
	if not bool(body.get("ready", true)):
		return
	if field._mock_coop_remote_player_phase_ready:
		return
	field._mock_coop_remote_player_phase_ready = true
	if field.battle_log != null and field.battle_log.visible:
		if field._mock_coop_local_player_phase_ready:
			field.add_combat_log("Co-op: partner detachment is ready. Advancing to the next phase.", "gold")
		else:
			field.add_combat_log("Co-op: partner detachment is ready. Finish your commands when you are ready.", "gold")
	field.update_objective_ui(true)
	field._mock_coop_try_advance_player_phase_after_ready_sync()
