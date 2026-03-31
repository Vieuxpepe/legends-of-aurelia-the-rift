extends RefCounted

# Helper for remaining ENet runtime co-op replay/sync flow that still lives in `BattleField.gd`.

const InventoryUiHelpers = preload("res://Scripts/Core/BattleField/BattleFieldInventoryUiHelpers.gd")

static func coop_net_reset_battle_rng_sync(field) -> void:
	field._coop_net_have_battle_seed = false
	field._coop_net_stored_battle_seed = 0
	field._coop_net_local_combat_seq = 0
	field._coop_net_incoming_enemy_combat_fifo.clear()

	# QTE mirror + capture state
	field._coop_qte_event_seq = 0
	field._coop_qte_mirror_active = false
	field._coop_qte_mirror_dict.clear()
	field._coop_qte_capture_active = false
	field._coop_qte_capture_dict.clear()

	# Combat loot capture sync state
	field._coop_combat_loot_capture_active = false
	field._coop_combat_loot_capture_events.clear()

	field._coop_guest_awaiting_combat_aid = ""
	field._coop_remote_enemy_turn_completed = false
	field._coop_remote_battle_result_applying = false
	field._coop_host_battle_result_broadcast = ""
	field._coop_finalized_battle_result = ""
	field._coop_waiting_for_host_battle_result = ""
	field._coop_battle_result_resolution_in_progress = ""

	# Escort-turn state
	field._coop_remote_escort_turn_completed = false
	field._coop_pending_escort_destination_victory = false


static func coop_enet_enemy_turn_host_authority_active(field) -> bool:
	return (
		field.is_mock_coop_unit_ownership_active()
		and CoopExpeditionSessionManager.uses_runtime_network_coop_transport()
		and CoopExpeditionSessionManager.phase != CoopExpeditionSessionManager.Phase.NONE
	)


static func coop_enet_is_host_authority_enemy_turn_host(field) -> bool:
	return coop_enet_enemy_turn_host_authority_active(field) and CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.HOST


static func coop_enet_should_wait_for_host_authority_enemy_turn(field) -> bool:
	return coop_enet_enemy_turn_host_authority_active(field) and CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.GUEST


static func coop_enet_guest_wait_for_enemy_turn_end(field) -> void:
	if not coop_enet_should_wait_for_host_authority_enemy_turn(field):
		return

	if field._coop_remote_enemy_turn_completed:
		field._coop_remote_enemy_turn_completed = false
		return

	while field.is_inside_tree():
		await field.coop_remote_enemy_turn_finished
		if field._coop_remote_enemy_turn_completed:
			field._coop_remote_enemy_turn_completed = false
			return


static func coop_enet_escort_turn_host_authority_active(field) -> bool:
	return (
		field.map_objective == BattleField.Objective.DEFEND_TARGET
		and is_instance_valid(field.vip_target)
		and field.vip_target.has_method("process_escort_turn")
		and CoopExpeditionSessionManager.uses_runtime_network_coop_transport()
		and CoopExpeditionSessionManager.phase != CoopExpeditionSessionManager.Phase.NONE
	)


static func coop_enet_is_host_authority_escort_turn_host(field) -> bool:
	return coop_enet_escort_turn_host_authority_active(field) and CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.HOST


static func coop_enet_should_wait_for_host_authority_escort_turn(field) -> bool:
	return coop_enet_escort_turn_host_authority_active(field) and CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.GUEST


static func coop_enet_guest_wait_for_escort_turn_end(field) -> void:
	if not coop_enet_should_wait_for_host_authority_escort_turn(field):
		return

	if field._coop_remote_escort_turn_completed:
		field._coop_remote_escort_turn_completed = false
		return

	while field.is_inside_tree():
		await field.coop_remote_escort_turn_finished
		if field._coop_remote_escort_turn_completed:
			field._coop_remote_escort_turn_completed = false
			return


static func coop_normalize_battle_result(result: String) -> String:
	var normalized: String = str(result).strip_edges().to_upper()
	if normalized == "":
		return ""
	return normalized


static func coop_enet_battle_result_host_authority_active(field) -> bool:
	return coop_enet_enemy_turn_host_authority_active(field)


static func coop_enet_should_wait_for_host_authoritative_battle_result(field) -> bool:
	return coop_enet_battle_result_host_authority_active(field) and CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.GUEST


static func coop_send_host_authoritative_battle_result(field, result: String) -> void:
	var normalized: String = coop_normalize_battle_result(result)
	if normalized == "":
		return
	if not coop_enet_battle_result_host_authority_active(field) or CoopExpeditionSessionManager.phase != CoopExpeditionSessionManager.Phase.HOST:
		return
	if field._coop_host_battle_result_broadcast == normalized:
		return

	field._coop_host_battle_result_broadcast = normalized
	CoopExpeditionSessionManager.send_runtime_coop_action({
		"action": "battle_result",
		"result": normalized,
	})


static func coop_wait_for_host_authoritative_battle_result(field, result: String) -> void:
	var normalized: String = coop_normalize_battle_result(result)
	if normalized == "":
		return
	if field._coop_finalized_battle_result != "":
		return
	if field._coop_waiting_for_host_battle_result == normalized:
		return

	field._coop_waiting_for_host_battle_result = normalized
	field.change_state(null)

	if field.battle_log != null and field.battle_log.visible:
		field.add_combat_log("Co-op: waiting for host to confirm %s." % normalized.to_lower(), "gold")


static func is_loot_window_active(field) -> bool:
	return field.loot_window != null and is_instance_valid(field.loot_window) and field.loot_window.visible


static func wait_for_loot_window_close(field) -> void:
	await InventoryUiHelpers.wait_for_loot_window_close(field)


static func defer_battle_result_until_loot_if_needed(field, result: String) -> bool:
	var normalized: String = coop_normalize_battle_result(result)
	if normalized == "":
		normalized = str(result).strip_edges()
	if normalized == "":
		return false
	if not is_loot_window_active(field):
		return false
	field._deferred_battle_result_after_loot = normalized
	return true


static func apply_deferred_battle_result_after_loot(field, result: String) -> void:
	var normalized: String = coop_normalize_battle_result(result)
	if normalized == "":
		normalized = str(result).strip_edges()

	if normalized == "" or field._coop_finalized_battle_result != "":
		return

	if normalized == "VICTORY":
		await field._trigger_victory()
	else:
		field.trigger_game_over(normalized)

