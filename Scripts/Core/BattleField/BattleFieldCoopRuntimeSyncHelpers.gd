extends RefCounted

# ENet runtime co-op sync helpers extracted from `BattleField.gd`.
# Scope: QTE mirror/capture utilities + remote sync queue pumping/dispatch.

static func coop_qte_tick_reset_for_execute_combat(field) -> void:
	field._coop_qte_event_seq = 0


static func coop_net_begin_local_combat_qte_capture(field) -> void:
	field._coop_qte_capture_dict.clear()
	field._coop_qte_capture_active = true


static func coop_net_end_local_combat_qte_capture(field) -> Dictionary:
	if not field._coop_qte_capture_active:
		return {}
	field._coop_qte_capture_active = false
	return field._coop_qte_capture_dict.duplicate(true)


static func coop_net_begin_local_combat_loot_capture(field) -> void:
	field._coop_combat_loot_capture_events.clear()
	field._coop_combat_loot_capture_active = true


static func coop_net_end_local_combat_loot_capture(field) -> Array:
	var out: Array = []
	if field._coop_combat_loot_capture_active:
		out = field._coop_combat_loot_capture_events.duplicate(true)
	field._coop_combat_loot_capture_active = false
	field._coop_combat_loot_capture_events.clear()
	return out


static func coop_net_apply_remote_combat_qte_snapshot(field, snap: Variant) -> void:
	field._coop_qte_mirror_active = true
	field._coop_qte_mirror_dict.clear()
	if snap is Dictionary:
		for k in snap.keys():
			field._coop_qte_mirror_dict[str(k)] = (snap as Dictionary)[k]


static func coop_net_clear_remote_combat_qte_snapshot(field) -> void:
	field._coop_qte_mirror_active = false
	field._coop_qte_mirror_dict.clear()


static func coop_qte_alloc_event_id(field) -> String:
	var k := str(field._coop_qte_event_seq)
	field._coop_qte_event_seq += 1
	return k


static func coop_qte_mirror_read_int(field, event_id: String, default_v: int) -> int:
	if not field._coop_qte_mirror_dict.has(event_id):
		return default_v
	return int(field._coop_qte_mirror_dict[event_id])


static func coop_qte_mirror_read_bool(field, event_id: String, default_v: bool) -> bool:
	if not field._coop_qte_mirror_dict.has(event_id):
		return default_v
	var v: Variant = field._coop_qte_mirror_dict[event_id]
	if v is bool:
		return v
	return int(v) != 0


static func coop_qte_capture_write(field, event_id: String, value: Variant) -> void:
	if field._coop_qte_capture_active:
		field._coop_qte_capture_dict[event_id] = value


static func apply_remote_coop_enet_sync(field, body: Dictionary) -> void:
	if not field.is_mock_coop_unit_ownership_active():
		if OS.is_debug_build():
			var act_no_owner: String = str(body.get("action", "")).strip_edges()
			push_warning("BattleField: drop incoming coop sync '%s' (mock ownership inactive on this battlefield)" % act_no_owner)
		return
	var copy: Dictionary = body.duplicate(true)
	copy["_coop_wire_gen"] = int(field._coop_full_resync_generation)
	field._coop_enet_remote_sync_queue.append(copy)
	coop_enet_pump_remote_sync_queue(field)


## After full_battle_resync: drop pending mirrors so stale combat never applies on top of fresh host state.
static func coop_enet_prepare_for_full_battle_resync(field) -> void:
	field._coop_net_incoming_enemy_combat_fifo.clear()
	coop_net_clear_remote_combat_qte_snapshot(field)
	field._coop_enet_remote_sync_queue.clear()
	field._coop_enet_remote_sync_busy = false


static func coop_enet_pump_remote_sync_queue(field) -> void:
	if field._coop_enet_remote_sync_busy:
		return
	if field._coop_enet_remote_sync_queue.is_empty():
		return

	field._coop_enet_remote_sync_busy = true
	var next_body: Dictionary = field._coop_enet_remote_sync_queue.pop_front() as Dictionary
	var defer_timer: SceneTreeTimer = field.get_tree().create_timer(0.0, true, true, true)
	defer_timer.timeout.connect(func(): field._coop_run_one_remote_sync_async(next_body), CONNECT_ONE_SHOT)
