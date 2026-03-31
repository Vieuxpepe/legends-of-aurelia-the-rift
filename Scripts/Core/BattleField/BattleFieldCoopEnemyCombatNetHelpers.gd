extends RefCounted

# ENet co-op: AI / enemy combat host broadcast + guest FIFO replay — extracted from `BattleField.gd`.


static func coop_enet_buffer_incoming_enemy_combat(field, body: Dictionary) -> void:
	if body.is_empty():
		return
	field._coop_net_incoming_enemy_combat_fifo.append(body.duplicate(true))


static func coop_enet_ai_execute_combat(field, attacker: Node2D, defender: Node2D, used_ability: bool = false) -> void:
	if attacker == null or defender == null or not is_instance_valid(attacker) or not is_instance_valid(defender):
		return
	if not field._coop_net_have_battle_seed or not field.is_mock_coop_unit_ownership_active() or not CoopExpeditionSessionManager.uses_runtime_network_coop_transport():
		await field.execute_combat(attacker, defender, used_ability)
		return
	if CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.NONE:
		await field.execute_combat(attacker, defender, used_ability)
		return
	var aid: String = field._get_mock_coop_command_id(attacker)
	var did: String = field._get_mock_coop_command_id(defender)
	if aid == "" or did == "":
		await field.execute_combat(attacker, defender, used_ability)
		return
	if field.current_state == field.enemy_state and field.coop_enet_should_wait_for_host_authority_enemy_turn():
		return
	if field.current_state == field.enemy_state and field.coop_enet_is_host_authority_enemy_turn_host():
		var pre_enemy_turn: Dictionary = field.coop_net_snapshot_alive_unit_ids()
		var packed_enemy_turn: int = field.coop_enet_begin_synchronized_combat_round()
		var defender_is_destructible: bool = defender.get_parent() == field.destructibles_container
		var defender_name_before: String = str(defender.get("object_name")) if defender.get("object_name") != null else str(defender.get("unit_name"))
		var pre_stolen_gold: int = int(attacker.get("stolen_gold")) if attacker.get("stolen_gold") != null else 0
		var pre_stolen_loot_size: int = 0
		if attacker.get("stolen_loot") != null:
			pre_stolen_loot_size = (attacker.stolen_loot as Array).size()
		field.coop_net_begin_local_combat_qte_capture()
		field.coop_net_begin_local_combat_loot_capture()
		await field.execute_combat(attacker, defender, used_ability)
		await field._wait_for_loot_window_close()
		var qte_enemy_turn: Dictionary = field.coop_net_end_local_combat_qte_capture()
		var loot_events_enemy_turn: Array = field.coop_net_end_local_combat_loot_capture()
		var auth_enemy_turn: Dictionary = field.coop_net_build_authoritative_combat_snapshot(pre_enemy_turn)
		var spoils: Dictionary = {}
		if defender_is_destructible:
			var defender_dead: bool = not is_instance_valid(defender) or defender.is_queued_for_deletion() or int(defender.get("current_hp")) <= 0
			if defender_dead:
				var gold_after: int = int(attacker.get("stolen_gold")) if attacker.get("stolen_gold") != null else pre_stolen_gold
				var gold_delta: int = maxi(0, gold_after - pre_stolen_gold)
				var new_items: Array = []
				if attacker.get("stolen_loot") != null:
					var loot_after: Array = attacker.stolen_loot as Array
					for i in range(pre_stolen_loot_size, loot_after.size()):
						new_items.append(loot_after[i])
				if gold_delta > 0 or not new_items.is_empty():
					spoils = {
						"gold": gold_delta,
						"items": field._coop_wire_serialize_items(new_items),
					}
		var combat_body: Dictionary = {
			"action": "enemy_turn_combat",
			"attacker_id": aid,
			"defender_id": did,
			"used_ability": used_ability,
			"rng_packed": packed_enemy_turn,
			"qte_snapshot": qte_enemy_turn,
			"auth_snapshot": auth_enemy_turn,
			"auth_v": field.COOP_AUTH_BATTLE_SNAPSHOT_VER,
		}
		if not loot_events_enemy_turn.is_empty():
			combat_body["loot_events"] = loot_events_enemy_turn.duplicate(true)
		if not spoils.is_empty():
			combat_body["destructible_spoils"] = spoils
			combat_body["destructible_name"] = defender_name_before
		CoopExpeditionSessionManager.send_runtime_coop_action(combat_body)
		return
	if CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.HOST:
		var pre_enemy: Dictionary = field.coop_net_snapshot_alive_unit_ids()
		var packed: int = field.coop_enet_begin_synchronized_combat_round()
		field.coop_net_begin_local_combat_qte_capture()
		field.coop_net_begin_local_combat_loot_capture()
		await field.execute_combat(attacker, defender, used_ability)
		await field._wait_for_loot_window_close()
		var qte_enemy: Dictionary = field.coop_net_end_local_combat_qte_capture()
		var loot_events_enemy: Array = field.coop_net_end_local_combat_loot_capture()
		var auth_enemy: Dictionary = field.coop_net_build_authoritative_combat_snapshot(pre_enemy)
		var enemy_body: Dictionary = {
			"action": "enemy_combat",
			"attacker_id": aid,
			"defender_id": did,
			"used_ability": used_ability,
			"rng_packed": packed,
			"qte_snapshot": qte_enemy,
			"auth_snapshot": auth_enemy,
			"auth_v": field.COOP_AUTH_BATTLE_SNAPSHOT_VER,
		}
		if not loot_events_enemy.is_empty():
			enemy_body["loot_events"] = loot_events_enemy.duplicate(true)
		CoopExpeditionSessionManager.send_runtime_coop_action(enemy_body)
		return
	while field.is_inside_tree():
		if not is_instance_valid(attacker) or not is_instance_valid(defender):
			return
		if not field._coop_net_incoming_enemy_combat_fifo.is_empty():
			var head = field._coop_net_incoming_enemy_combat_fifo[0]
			var h_aid: String = str(head.get("attacker_id", "")).strip_edges()
			var h_did: String = str(head.get("defender_id", "")).strip_edges()
			if h_aid == aid and h_did == did:
				field._coop_net_incoming_enemy_combat_fifo.pop_front()
				var av: int = int(head.get("auth_v", 0))
				var ar: Variant = head.get("auth_snapshot", {})
				var rp: int = int(head.get("rng_packed", -1))
				var qte_raw: Variant = head.get("qte_snapshot", {})
				await field._coop_execute_remote_combat_replay(attacker, defender, bool(head.get("used_ability", used_ability)), qte_raw, rp)
				if ar is Dictionary and av == field.COOP_AUTH_BATTLE_SNAPSHOT_VER:
					var ad: Dictionary = ar as Dictionary
					if ad.size() > 0:
						field._coop_apply_authoritative_combat_snapshot(ad)
				field._coop_apply_remote_synced_enemy_death_loot_events(head.get("loot_events", []))
				return
			if OS.is_debug_build():
				push_warning("Coop enemy combat FIFO mismatch: expected %s→%s, got %s→%s" % [aid, did, h_aid, h_did])
			field._coop_net_incoming_enemy_combat_fifo.pop_front()
			continue
		await field.get_tree().process_frame
