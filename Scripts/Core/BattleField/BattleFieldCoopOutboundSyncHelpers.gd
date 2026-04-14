extends RefCounted

# ENet mock co-op: host-authority + local-player outbound wire payloads ([method CoopExpeditionSessionManager.send_runtime_coop_action]) — extracted from `BattleField.gd`.


static func coop_enet_sync_after_host_authority_enemy_move(field, unit: Node2D, path: Array, path_cost: float) -> void:
	if not field.coop_enet_is_host_authority_enemy_turn_host():
		return
	if unit == null or not is_instance_valid(unit):
		return
	var uid: String = field._get_mock_coop_command_id(unit)
	if uid == "":
		return
	var serial: Array = []
	for p in path:
		var v := Vector2i.ZERO
		if p is Vector2i:
			v = p as Vector2i
		elif typeof(p) == TYPE_VECTOR2I:
			v = p as Vector2i
		else:
			continue
		serial.append([v.x, v.y])
	if serial.size() < 2:
		return
	CoopExpeditionSessionManager.send_runtime_coop_action({
		"action": "enemy_turn_move",
		"unit_id": uid,
		"path": serial,
		"path_cost": float(path_cost),
	})


static func coop_enet_sync_after_host_authority_enemy_finish_turn(field, unit: Node2D) -> void:
	if not field.coop_enet_is_host_authority_enemy_turn_host():
		return
	if unit == null or not is_instance_valid(unit):
		return
	var uid: String = field._get_mock_coop_command_id(unit)
	if uid == "":
		return
	CoopExpeditionSessionManager.send_runtime_coop_action({
		"action": "enemy_turn_finish",
		"unit_id": uid,
	})


static func coop_enet_sync_after_host_authority_enemy_escape(field, unit: Node2D) -> void:
	if not field.coop_enet_is_host_authority_enemy_turn_host():
		return
	if unit == null or not is_instance_valid(unit):
		return
	var uid: String = field._get_mock_coop_command_id(unit)
	if uid == "":
		return
	CoopExpeditionSessionManager.send_runtime_coop_action({
		"action": "enemy_turn_escape",
		"unit_id": uid,
	})


static func coop_enet_sync_after_host_authority_enemy_chest_open(field, opener: Node2D, chest: Node2D, stolen_items: Array) -> void:
	if not field.coop_enet_is_host_authority_enemy_turn_host():
		return
	if opener == null or chest == null or not is_instance_valid(opener) or not is_instance_valid(chest):
		return
	var opener_id: String = field._get_mock_coop_command_id(opener)
	var chest_id: String = field._get_mock_coop_command_id(chest)
	if opener_id == "" or chest_id == "":
		return
	CoopExpeditionSessionManager.send_runtime_coop_action({
		"action": "enemy_turn_chest_open",
		"opener_id": opener_id,
		"chest_id": chest_id,
		"stolen_items": field._coop_wire_serialize_items(stolen_items),
	})


static func coop_enet_sync_after_host_authority_enemy_turn_end(field) -> void:
	if not field.coop_enet_is_host_authority_enemy_turn_host():
		return
	CoopExpeditionSessionManager.send_runtime_coop_action({"action": "enemy_turn_end"})


static func coop_enet_sync_enemy_turn_batch_move(field, entries: Array) -> void:
	if not field.coop_enet_is_host_authority_enemy_turn_host():
		return
	var payload: Array = []
	for entry: Dictionary in entries:
		var unit: Node2D = entry.get("unit") as Node2D
		var path: Array = entry.get("move_path", [])
		if unit == null or not is_instance_valid(unit):
			continue
		var uid: String = field._get_mock_coop_command_id(unit)
		if uid == "":
			continue
		var serial: Array = []
		var typed_path: Array[Vector2i] = []
		for p in path:
			var v := Vector2i.ZERO
			if p is Vector2i:
				v = p as Vector2i
			elif typeof(p) == TYPE_VECTOR2I:
				v = p as Vector2i
			else:
				continue
			serial.append([v.x, v.y])
			typed_path.append(v)
		if serial.size() < 2:
			continue
		payload.append({
			"unit_id": uid,
			"path": serial,
			"path_cost": float(field.get_path_move_cost(typed_path, unit)),
		})
	if payload.is_empty():
		return
	CoopExpeditionSessionManager.send_runtime_coop_action({
		"action": "enemy_turn_batch_move",
		"entries": payload,
	})


static func coop_enet_sync_after_host_authority_enemy_phase_setup(field) -> void:
	if not field.coop_enet_is_host_authority_enemy_turn_host():
		return
	var snap: Dictionary = field._coop_build_enemy_phase_setup_snapshot()
	CoopExpeditionSessionManager.send_runtime_coop_action({
		"action": "enemy_phase_setup",
		"setup": snap,
	})


static func coop_enet_sync_after_host_authoritative_battle_result(field, result: String) -> void:
	field._coop_send_host_authoritative_battle_result(result)


static func coop_enet_sync_after_host_authority_escort_turn(field, convoy: Node2D) -> void:
	if not field.coop_enet_is_host_authority_escort_turn_host():
		return
	if convoy == null or not is_instance_valid(convoy):
		return
	var path_payload: Array = []
	var path_raw: Variant = convoy.get("last_turn_path")
	if path_raw is Array:
		for cell in path_raw as Array:
			if cell is Vector2i:
				var grid: Vector2i = cell as Vector2i
				path_payload.append([grid.x, grid.y])
			elif cell is Array:
				var arr: Array = cell as Array
				if arr.size() >= 2:
					path_payload.append([int(arr[0]), int(arr[1])])
	var payload: Dictionary = {
		"action": "escort_turn",
		"path": path_payload,
		"current_marker_idx": int(convoy.get("current_marker_idx")),
		"current_hp": int(convoy.get("current_hp")),
		"has_moved": bool(convoy.get("has_moved")),
		"is_exhausted": bool(convoy.get("is_exhausted")),
		"reached_destination": bool(convoy.get("last_turn_reached_destination")),
	}
	CoopExpeditionSessionManager.send_runtime_coop_action(payload)


static func _coop_enet_sync_eligible_command_unit(field, unit: Node2D) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	if not field.is_mock_coop_unit_ownership_active():
		return false
	if not CoopExpeditionSessionManager.uses_runtime_network_coop_transport():
		return false
	if CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.NONE:
		return false
	if field.is_local_player_command_blocked_for_mock_coop_unit(unit):
		return false
	return true


static func _build_local_mock_coop_prebattle_layout_snapshot(field) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if field.player_container == null:
		return out
	for u in field.player_container.get_children():
		if u == null or not is_instance_valid(u) or u.is_queued_for_deletion():
			continue
		if field.get_mock_coop_unit_owner_for_unit(u) != field.MOCK_COOP_OWNER_LOCAL:
			continue
		var uid: String = field._get_mock_coop_command_id(u)
		if uid == "":
			continue
		var entry: Dictionary = {
			"unit_id": uid,
			"deployed": field._is_mock_coop_deployed_player_side_unit(u),
		}
		if bool(entry.get("deployed", false)):
			var gp: Vector2i = field.get_grid_pos(u)
			entry["grid_pos"] = {"x": gp.x, "y": gp.y}
		out.append(entry)
	return out


static func coop_enet_sync_after_local_prebattle_layout_change(field) -> void:
	if field.current_state != field.pre_battle_state:
		return
	if not field._mock_coop_battle_sync_active():
		return
	if field._mock_coop_local_prebattle_ready:
		field._mock_coop_clear_local_prebattle_ready(true)
	var units: Array[Dictionary] = _build_local_mock_coop_prebattle_layout_snapshot(field)
	if units.is_empty():
		return
	CoopExpeditionSessionManager.send_runtime_coop_action({
		"action": "prebattle_layout",
		"units": units,
	})


static func coop_enet_sync_after_local_player_move(field, unit: Node2D, path: Array, _path_cost: float, finish_after_move: bool = false) -> void:
	if not _coop_enet_sync_eligible_command_unit(field, unit):
		return
	var uid: String = field._get_mock_coop_command_id(unit)
	if uid == "":
		return
	var serial: Array = []
	for p in path:
		var v: Vector2i = Vector2i.ZERO
		if p is Vector2i:
			v = p as Vector2i
		elif typeof(p) == TYPE_VECTOR2I:
			v = p as Vector2i
		else:
			continue
		serial.append([v.x, v.y])
	if serial.size() < 2:
		return
	var payload: Dictionary = {"action": "player_move", "unit_id": uid, "path": serial}
	if finish_after_move:
		payload["finish_after_move"] = true
	CoopExpeditionSessionManager.send_runtime_coop_action(payload)


static func coop_enet_sync_after_local_defend(field, unit: Node2D) -> void:
	if not _coop_enet_sync_eligible_command_unit(field, unit):
		return
	var uid: String = field._get_mock_coop_command_id(unit)
	if uid == "":
		return
	CoopExpeditionSessionManager.send_runtime_coop_action({"action": "player_defend", "unit_id": uid})


static func coop_enet_sync_local_combat_done(
	field,
	attacker_id: String,
	defender_id: String,
	used_ability: bool,
	attacker_after: Node2D,
	entered_canto: bool,
	canto_budget: float,
	combat_packed_rng_id: int = -1,
	qte_snapshot: Dictionary = {},
	auth_snapshot: Dictionary = {},
	combat_host_authority: bool = false,
	loot_events: Array = [],
	combat_body_extra: Dictionary = {}
) -> void:
	if not field.is_mock_coop_unit_ownership_active():
		return
	if not CoopExpeditionSessionManager.uses_runtime_network_coop_transport():
		return
	if CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.NONE:
		return
	var aid: String = str(attacker_id).strip_edges()
	var did: String = str(defender_id).strip_edges()
	if aid == "" or did == "":
		return
	var has_followup: bool = attacker_after != null and is_instance_valid(attacker_after) and int(attacker_after.current_hp) > 0
	var combat_body: Dictionary = {
		"action": "player_combat",
		"attacker_id": aid,
		"defender_id": did,
		"used_ability": used_ability,
		"has_post_combat_followup": has_followup,
	}
	if combat_packed_rng_id >= 0:
		combat_body["rng_packed"] = combat_packed_rng_id
	if qte_snapshot.size() > 0:
		combat_body["qte_snapshot"] = qte_snapshot.duplicate(true)
	if auth_snapshot.size() > 0:
		combat_body["auth_snapshot"] = auth_snapshot.duplicate(true)
		combat_body["auth_v"] = field.COOP_AUTH_BATTLE_SNAPSHOT_VER
	if combat_host_authority:
		combat_body["host_authority"] = true
	if not loot_events.is_empty():
		combat_body["loot_events"] = loot_events.duplicate(true)
	for ek in combat_body_extra.keys():
		combat_body[ek] = combat_body_extra[ek]
	CoopExpeditionSessionManager.send_runtime_coop_action(combat_body)
	if attacker_after == null or not is_instance_valid(attacker_after) or int(attacker_after.current_hp) <= 0:
		return
	var follow: String = "canto" if entered_canto else "finish"
	var post: Dictionary = {
		"action": "player_post_combat",
		"attacker_id": aid,
		"follow": follow,
		"canto_budget": float(canto_budget),
	}
	if combat_host_authority:
		post["host_authority"] = true
	CoopExpeditionSessionManager.send_runtime_coop_action(post)


static func coop_enet_sync_after_local_finish_turn(field, unit: Node2D) -> void:
	if not _coop_enet_sync_eligible_command_unit(field, unit):
		return
	var uid: String = field._get_mock_coop_command_id(unit)
	if uid == "":
		return
	CoopExpeditionSessionManager.send_runtime_coop_action({"action": "player_finish_turn", "unit_id": uid})
