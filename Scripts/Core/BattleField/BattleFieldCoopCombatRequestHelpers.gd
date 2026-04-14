extends RefCounted

# ENet co-op: guest `player_combat_request` + host resolution — extracted from `BattleField.gd`.

const ActiveCombatAbilityHelpers = preload("res://Scripts/Core/BattleField/ActiveCombatAbilityHelpers.gd")
const ActiveCombatAbilityExecutionHelpers = preload("res://Scripts/Core/BattleField/ActiveCombatAbilityExecutionHelpers.gd")

## Guest must never wait indefinitely if packets are lost or the host desyncs.
const COOP_GUEST_COMBAT_DELEGATE_WAIT_TIMEOUT_MS: int = 45000


static func coop_enet_guest_delegate_player_combat_to_host(
	field,
	attacker_id: String,
	defender_id: String,
	used_ability: bool,
	active_ability_id: String = ""
) -> void:
	if not field.coop_enet_should_delegate_player_combat_to_host():
		return
	var aid: String = str(attacker_id).strip_edges()
	var did: String = str(defender_id).strip_edges()
	if aid == "" or did == "":
		return
	field._coop_guest_awaiting_combat_aid = aid
	var payload: Dictionary = {
		"action": "player_combat_request",
		"attacker_id": aid,
		"defender_id": did,
		"used_ability": used_ability,
	}
	var ab: String = str(active_ability_id).strip_edges()
	if ab != "":
		payload["active_ability_id"] = ab
	CoopExpeditionSessionManager.send_runtime_coop_action(payload)
	var deadline_ms: int = Time.get_ticks_msec() + COOP_GUEST_COMBAT_DELEGATE_WAIT_TIMEOUT_MS
	while field._coop_guest_awaiting_combat_aid != "" and field.is_inside_tree():
		if Time.get_ticks_msec() >= deadline_ms:
			if OS.is_debug_build():
				push_warning(
					"Coop: guest combat delegation timed out (attacker_id=%s, defender_id=%s) — clearing wait." % [aid, did]
				)
			field._coop_guest_awaiting_combat_aid = ""
			field.coop_guest_host_combat_resolved.emit()
			if field.battle_log != null and field.battle_log.visible:
				field.add_combat_log(
					"Co-op: no host combat response in time — check the connection, then retry.", "tomato"
				)
			return
		await field.get_tree().process_frame


static func coop_enet_guest_receive_combat_request_nack(field, body: Dictionary) -> void:
	var aid: String = str(body.get("attacker_id", "")).strip_edges()
	if field._coop_guest_awaiting_combat_aid == "":
		return
	if aid != "" and aid != field._coop_guest_awaiting_combat_aid:
		return
	field._coop_guest_awaiting_combat_aid = ""
	if OS.is_debug_build():
		push_warning("Coop: host rejected player_combat_request (attacker_id=%s)." % aid)
	field.coop_guest_host_combat_resolved.emit()


static func coop_host_send_player_combat_request_nack(field, attacker_id: String) -> void:
	if not CoopExpeditionSessionManager.uses_runtime_network_coop_transport():
		return
	if CoopExpeditionSessionManager.phase != CoopExpeditionSessionManager.Phase.HOST:
		return
	CoopExpeditionSessionManager.send_runtime_coop_action({
		"action": "player_combat_request_nack",
		"attacker_id": str(attacker_id).strip_edges(),
	})


## Host: guest used a [ActiveCombatAbilityData] id (not weapon strike). Apply on host world, sync via auth snapshot ([param active_ability_only] on wire).
static func coop_host_resolve_guest_data_driven_active_async(field, body: Dictionary) -> void:
	var aid: String = str(body.get("attacker_id", "")).strip_edges()
	var did: String = str(body.get("defender_id", "")).strip_edges()
	var ability_id: String = str(body.get("active_ability_id", "")).strip_edges()
	if aid == "" or did == "" or ability_id == "":
		coop_host_send_player_combat_request_nack(field, aid if aid != "" else "?")
		return
	var att: Node2D = field._coop_find_unit_by_relationship_id_any_side(aid)
	var defu: Node2D = field._coop_find_unit_by_relationship_id_any_side(did)
	if att == null or defu == null or not is_instance_valid(att) or not is_instance_valid(defu):
		coop_host_send_player_combat_request_nack(field, aid)
		return
	if field.get_mock_coop_unit_owner_for_unit(att) != field.MOCK_COOP_OWNER_REMOTE:
		if OS.is_debug_build():
			push_warning("Coop: active ability request ignored — attacker is not guest's unit (%s)." % aid)
		coop_host_send_player_combat_request_nack(field, aid)
		return
	var def_res: ActiveCombatAbilityData = ActiveCombatAbilityHelpers.get_definition(att, ability_id)
	if def_res == null:
		coop_host_send_player_combat_request_nack(field, aid)
		return
	var primary: Node2D = defu
	if int(def_res.effect_kind) == int(ActiveCombatAbilityData.EffectKind.SELF_CENTERED):
		primary = att

	var pre_alive: Dictionary = field.coop_net_snapshot_alive_unit_ids()
	var packed: int = field.coop_enet_begin_synchronized_combat_round()
	field.coop_net_begin_local_combat_qte_capture()
	field.coop_net_begin_local_combat_loot_capture()

	var ok: bool = await ActiveCombatAbilityExecutionHelpers.execute_async(field, att, primary, def_res)

	var qte_snap: Dictionary = field.coop_net_end_local_combat_qte_capture()
	if is_instance_valid(field) and field.is_inside_tree() and field.get_tree().paused:
		while is_instance_valid(field) and field.get_tree().paused:
			await field.get_tree().process_frame

	await field._wait_for_loot_window_close()
	var loot_events: Array = field.coop_net_end_local_combat_loot_capture()
	var auth: Dictionary = field.coop_net_build_authoritative_combat_snapshot(pre_alive)
	var att_after: Node2D = field._coop_find_player_side_unit_by_relationship_id(aid)

	var extra: Dictionary = {}
	if not auth.is_empty() and int(auth.get("v", -1)) == int(field.COOP_AUTH_BATTLE_SNAPSHOT_VER):
		extra["active_ability_only"] = true
	elif OS.is_debug_build():
		push_warning(
			"Coop: guest active resolve omitting active_ability_only — invalid auth snapshot (attacker_id=%s)." % aid
		)

	if not ok:
		var alive_fail: Node2D = att if is_instance_valid(att) and int(att.current_hp) > 0 else null
		field.coop_enet_sync_local_combat_done(
			aid, did, false, alive_fail, false, 0.0, packed, qte_snap, auth, true, loot_events, extra
		)
		return

	if att_after == null or not is_instance_valid(att_after) or int(att_after.current_hp) <= 0:
		field.coop_enet_sync_local_combat_done(aid, did, false, null, false, 0.0, packed, qte_snap, auth, true, loot_events, extra)
		return

	var entered_canto: bool = false
	var canto_budget: float = 0.0
	var used_f: float = float(att_after.move_points_used_this_turn)
	var rem: float = float(att_after.move_range) - used_f
	if field.unit_supports_canto(att_after) and rem > 0.001:
		entered_canto = true
		canto_budget = rem
		att_after.has_moved = true
		att_after.in_canto_phase = true
		att_after.canto_move_budget = rem
		if field.battle_log != null and field.battle_log.visible:
			field.add_combat_log(att_after.unit_name + " — Canto (" + str(snappedf(rem, 0.1)) + " move left).", "cyan")
		field.rebuild_grid()
		field.calculate_ranges(att_after)

	var alive_after: Node2D = att_after
	field.coop_enet_sync_local_combat_done(
		aid, did, false, alive_after, entered_canto, canto_budget, packed, qte_snap, auth, true, loot_events, extra
	)
	if alive_after != null and is_instance_valid(alive_after) and int(alive_after.current_hp) > 0 and not entered_canto and alive_after.has_method("finish_turn"):
		alive_after.finish_turn()


static func coop_host_resolve_player_combat_request_async(field, body: Dictionary) -> void:
	if not field.is_mock_coop_unit_ownership_active() or not CoopExpeditionSessionManager.uses_runtime_network_coop_transport():
		return
	if CoopExpeditionSessionManager.phase != CoopExpeditionSessionManager.Phase.HOST:
		return
	var ability_active: String = str(body.get("active_ability_id", "")).strip_edges()
	if ability_active != "":
		await coop_host_resolve_guest_data_driven_active_async(field, body)
		return

	var aid: String = str(body.get("attacker_id", "")).strip_edges()
	var did: String = str(body.get("defender_id", "")).strip_edges()
	var used_ab: bool = bool(body.get("used_ability", false))
	if aid == "" or did == "":
		coop_host_send_player_combat_request_nack(field, aid if aid != "" else "?")
		return
	var att: Node2D = field._coop_find_unit_by_relationship_id_any_side(aid)
	var defu: Node2D = field._coop_find_unit_by_relationship_id_any_side(did)
	if att == null or defu == null or not is_instance_valid(att) or not is_instance_valid(defu):
		coop_host_send_player_combat_request_nack(field, aid)
		return
	if field.get_mock_coop_unit_owner_for_unit(att) != field.MOCK_COOP_OWNER_REMOTE:
		if OS.is_debug_build():
			push_warning("Coop: player_combat_request ignored — attacker is not guest's unit (%s)." % aid)
		coop_host_send_player_combat_request_nack(field, aid)
		return
	var pre_alive: Dictionary = field.coop_net_snapshot_alive_unit_ids()
	var packed: int = field.coop_enet_begin_synchronized_combat_round()
	field.coop_net_begin_local_combat_qte_capture()
	field.coop_net_begin_local_combat_loot_capture()
	await field.execute_combat(att, defu, used_ab)
	var qte_snap: Dictionary = field.coop_net_end_local_combat_qte_capture()
	await field._wait_for_loot_window_close()
	var loot_events: Array = field.coop_net_end_local_combat_loot_capture()
	var auth: Dictionary = field.coop_net_build_authoritative_combat_snapshot(pre_alive)
	var att_after: Node2D = field._coop_find_player_side_unit_by_relationship_id(aid)
	var entered_canto: bool = false
	var canto_budget: float = 0.0
	if att_after != null and is_instance_valid(att_after) and int(att_after.current_hp) > 0:
		var used_f: float = float(att_after.move_points_used_this_turn)
		var rem: float = float(att_after.move_range) - used_f
		if field.unit_supports_canto(att_after) and rem > 0.001:
			entered_canto = true
			canto_budget = rem
			att_after.has_moved = true
			att_after.in_canto_phase = true
			att_after.canto_move_budget = rem
			if field.battle_log != null and field.battle_log.visible:
				field.add_combat_log(att_after.unit_name + " — Canto (" + str(snappedf(rem, 0.1)) + " move left).", "cyan")
			field.rebuild_grid()
			field.calculate_ranges(att_after)
	var alive_after: Node2D = null
	if att_after != null and is_instance_valid(att_after) and int(att_after.current_hp) > 0:
		alive_after = att_after
	field.coop_enet_sync_local_combat_done(aid, did, used_ab, alive_after, entered_canto, canto_budget, packed, qte_snap, auth, true, loot_events)
	if alive_after != null and is_instance_valid(alive_after) and int(alive_after.current_hp) > 0 and not entered_canto and alive_after.has_method("finish_turn"):
		alive_after.finish_turn()
