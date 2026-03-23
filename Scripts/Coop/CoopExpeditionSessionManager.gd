extends Node

## Central co-op expedition session state (host/guest, readiness, selected map).
## Dormant until begin_host_session / join_session / debug hooks run. Single-player flow does not use this node.

signal session_state_changed
signal enet_battle_launch_committed
## Guest-side finalize over ENet: emitted when host returns errors (ok=false) so UI can refresh.
signal enet_guest_finalize_finished(fin: Dictionary)

enum Phase { NONE, HOST, GUEST }

## Pre-launch staging (single-process: host ingests guest via transport.send_session_payload).
enum StagingState {
	INACTIVE,
	HOST_AWAITING_GUEST,
	HOST_STAGING,
	GUEST_STAGING,
	READY_TO_LAUNCH,
}

var session_id: String = ""
var phase: int = Phase.NONE
var selected_expedition_map_id: String = ""

## Identity + ownership hints for future transport; keep JSON-serializable-friendly values.
var local_player_payload: Dictionary = {}
var remote_player_payload: Dictionary = {}

var local_ready: bool = false
var remote_ready: bool = false

var _transport: CoopSessionTransport = null
## ENet hardening: per-process guards (host pipeline vs guest duplicate handoff vs finalize spam).
var _enet_host_launch_pipeline_locked: bool = false
var _enet_guest_launch_apply_locked: bool = false
var _enet_host_finalize_busy: bool = false
var _enet_guest_finalize_pending: bool = false
var _enet_host_handoff_for_deferred_launch: Dictionary = {}
## Active BattleField for two-instance mock co-op (ENet); receive mirrored player moves.
var _enet_battle_sync_battlefield: Node = null
## Host publishes once per session so both processes can lock global RNG + per-combat epochs (see BattleField).
var _coop_battle_rng_seed_sent: bool = false

func _ready() -> void:
	## Keep polling ENet while other UI pauses the tree or a window loses focus (two-instance LAN testing).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_transport = LocalLoopbackCoopTransport.new()
	(_transport as LocalLoopbackCoopTransport).bind_manager(self)
	clear_session()

func _process(_delta: float) -> void:
	if _transport is ENetCoopTransport:
		var tr: ENetCoopTransport = _transport as ENetCoopTransport
		tr.poll_and_dispatch()
		## While awaiting finalize_result, poll twice per frame so a just-flushed host packet is less likely to sit one frame behind a heavy scene change on the other instance.
		if _enet_guest_finalize_pending:
			tr.poll_and_dispatch()

func get_transport() -> CoopSessionTransport:
	return _transport

## Swap transport (e.g. future lobby-backed implementation). Call clear_session first if switching mid-flight.
func set_transport(transport: CoopSessionTransport) -> void:
	if transport == null:
		return
	if _transport != null and _transport != transport:
		_transport.leave_session()
	_transport = transport
	if transport is LocalLoopbackCoopTransport:
		(transport as LocalLoopbackCoopTransport).bind_manager(self)
	elif transport is ENetCoopTransport:
		(transport as ENetCoopTransport).bind_manager(self)

func clear_session() -> void:
	session_id = ""
	phase = Phase.NONE
	selected_expedition_map_id = ""
	local_player_payload = _default_local_payload()
	remote_player_payload = {}
	local_ready = false
	remote_ready = false
	_enet_reset_enet_staging_guards()
	_enet_battle_sync_battlefield = null
	_coop_battle_rng_seed_sent = false
	session_state_changed.emit()

func leave_session() -> void:
	if _transport != null:
		_transport.leave_session()
	clear_session()

func _enet_reset_enet_staging_guards() -> void:
	_enet_host_launch_pipeline_locked = false
	_enet_guest_launch_apply_locked = false
	_enet_host_finalize_busy = false
	_enet_guest_finalize_pending = false
	_enet_host_handoff_for_deferred_launch.clear()

func register_enet_coop_battle_sync_battlefield(battlefield: Node) -> void:
	if battlefield == null:
		return
	if not uses_enet_coop_transport():
		return
	if phase == Phase.NONE:
		return
	_enet_battle_sync_battlefield = battlefield

func unregister_enet_coop_battle_sync_battlefield(battlefield: Node) -> void:
	if battlefield != null and _enet_battle_sync_battlefield == battlefield:
		_enet_battle_sync_battlefield = null

## Host only: one broadcast so guest + host share the same starting RNG stream for this battle.
func enet_try_publish_coop_battle_rng_seed() -> void:
	if _coop_battle_rng_seed_sent:
		return
	if phase != Phase.HOST:
		return
	if not uses_enet_coop_transport():
		return
	var tr: ENetCoopTransport = _transport as ENetCoopTransport
	if not tr.is_session_wired():
		return
	if _enet_battle_sync_battlefield == null or not is_instance_valid(_enet_battle_sync_battlefield):
		return
	var picker := RandomNumberGenerator.new()
	picker.randomize()
	var s: int = picker.randi()
	_coop_battle_rng_seed_sent = true
	var body: Dictionary = {"action": "battle_rng_seed", "seed": s, "v": 1, "from_host": true}
	tr.host_broadcast_coop_message("coop_battle_sync", body)
	if _enet_battle_sync_battlefield.has_method("apply_coop_battle_net_rng_seed"):
		_enet_battle_sync_battlefield.call("apply_coop_battle_net_rng_seed", s)

## Mock co-op battle replication (move, defend, combat, …). Adds schema + from_host from session phase.
func enet_send_coop_battle_sync_action(payload: Dictionary) -> void:
	if not uses_enet_coop_transport():
		return
	if _enet_battle_sync_battlefield == null or not is_instance_valid(_enet_battle_sync_battlefield):
		return
	var tr: ENetCoopTransport = _transport as ENetCoopTransport
	if not tr.is_session_wired():
		return
	var body: Dictionary = payload.duplicate(true)
	body["v"] = 1
	body["from_host"] = (phase == Phase.HOST)
	if phase == Phase.HOST:
		tr.host_broadcast_coop_message("coop_battle_sync", body)
	elif phase == Phase.GUEST:
		tr.send_coop_message("coop_battle_sync", body)

func _enet_apply_incoming_coop_battle_sync(body: Dictionary) -> void:
	var bf: Node = _enet_battle_sync_battlefield
	if bf == null or not is_instance_valid(bf):
		return
	if int(body.get("v", 0)) != 1:
		return
	var from_host: bool = bool(body.get("from_host", false))
	var i_am_host: bool = phase == Phase.HOST
	if from_host == i_am_host:
		return
	var act: String = str(body.get("action", "")).strip_edges()
	## Apply immediately (do not queue): locks global RNG before other battle sync runs.
	if act == "battle_rng_seed":
		if bf.has_method("apply_coop_battle_net_rng_seed"):
			bf.call("apply_coop_battle_net_rng_seed", int(body.get("seed", 0)))
		return
	## Guest → host: resolve this player's combat only on the host (authoritative snapshot).
	if act == "player_combat_request":
		if not i_am_host:
			return
		if bf.has_method("coop_enet_host_handle_player_combat_request"):
			bf.coop_enet_host_handle_player_combat_request(body.duplicate(true))
		return
	## Host → guest: unblock [method BattleField.coop_enet_guest_delegate_player_combat_to_host] if the request was invalid.
	if act == "player_combat_request_nack":
		if i_am_host:
			return
		if bf.has_method("coop_enet_guest_receive_combat_request_nack"):
			bf.coop_enet_guest_receive_combat_request_nack(body.duplicate(true))
		return
	## Guest buffers host-led AI/enemy strikes; local AITurnState consumes FIFO (see [method BattleField.coop_enet_ai_execute_combat]).
	if act == "enemy_combat":
		if bf.has_method("coop_enet_buffer_incoming_enemy_combat"):
			bf.call("coop_enet_buffer_incoming_enemy_combat", body.duplicate(true))
		return
	if bf.has_method("apply_remote_coop_enet_sync"):
		bf.apply_remote_coop_enet_sync(body)

func begin_host_session() -> Dictionary:
	if _transport == null:
		return {"ok": false, "error": "no_transport"}
	return _transport.create_session()

func join_session(session_descriptor: String) -> Dictionary:
	if _transport == null:
		return {"ok": false, "error": "no_transport"}
	return _transport.join_session(session_descriptor)

func refresh_local_player_payload_from_campaign() -> void:
	var name_str: String = str(CampaignManager.custom_avatar.get("unit_name", "Commander")).strip_edges()
	if name_str == "":
		name_str = "Commander"
	# owned_expedition_map_ids = owned + DB coop_enabled subset (not full owned expedition list).
	local_player_payload = {
		"player_id": "local",
		"display_name": name_str,
		"owned_expedition_map_ids": CampaignManager.get_coop_eligible_expedition_map_ids(),
		"custom_avatar_snapshot": _snapshot_avatar_for_coop_payload(CampaignManager.custom_avatar),
		"ready": local_ready,
	}

func set_local_ready(value: bool) -> void:
	local_ready = value
	local_player_payload["ready"] = local_ready
	session_state_changed.emit()
	if _transport is ENetCoopTransport and phase == Phase.GUEST:
		_enet_guest_push_participant()
	elif _transport is ENetCoopTransport and phase == Phase.HOST:
		_enet_broadcast_session_snapshot()

func set_remote_ready(value: bool) -> void:
	remote_ready = value
	remote_player_payload["ready"] = remote_ready
	session_state_changed.emit()

func set_selected_expedition_map(map_id: String) -> bool:
	var key: String = str(map_id).strip_edges()
	if key == "":
		return false
	if not ExpeditionCoopEligibility.local_owns_coop_eligible_expedition(key):
		return false
	selected_expedition_map_id = key
	session_state_changed.emit()
	if _transport is ENetCoopTransport and phase == Phase.GUEST:
		(_transport as ENetCoopTransport).send_coop_message("selected_map_intent", {"map_id": key})
		_enet_guest_push_participant()
	elif _transport is ENetCoopTransport and phase == Phase.HOST:
		_enet_broadcast_session_snapshot()
	return true

func uses_loopback_coop_transport() -> bool:
	return _transport is LocalLoopbackCoopTransport

func uses_enet_coop_transport() -> bool:
	return _transport is ENetCoopTransport

func should_enet_mirror_launch_handoff_to_guest() -> bool:
	if not uses_enet_coop_transport() or phase != Phase.HOST:
		return false
	return (_transport as ENetCoopTransport).is_session_wired()

func enet_host_send_launch_handoff(handoff: Dictionary) -> void:
	if not should_enet_mirror_launch_handoff_to_guest():
		return
	var wire: Dictionary = _coop_handoff_clone_without_launch_snapshot_for_enet(handoff as Dictionary)
	(_transport as ENetCoopTransport).host_broadcast_coop_message("launch_handoff", {"handoff": wire})

func enet_guest_request_finalize_launch() -> void:
	if not uses_enet_coop_transport() or phase != Phase.GUEST:
		return
	var tr: ENetCoopTransport = _transport as ENetCoopTransport
	if not tr.is_session_wired():
		return
	if _enet_guest_finalize_pending:
		return
	_enet_guest_finalize_pending = true
	session_state_changed.emit()
	tr.send_coop_message("finalize_request", {})

func clear_enet_guest_finalize_pending() -> void:
	if not _enet_guest_finalize_pending:
		return
	_enet_guest_finalize_pending = false
	session_state_changed.emit()

func is_enet_guest_finalize_request_pending() -> bool:
	return _enet_guest_finalize_pending

func try_begin_enet_host_launch_pipeline() -> bool:
	if _enet_host_launch_pipeline_locked:
		return false
	_enet_host_launch_pipeline_locked = true
	return true

func release_enet_host_launch_pipeline() -> void:
	_enet_host_launch_pipeline_locked = false

## Host: local = ordered[0..k-1], partner = ordered[k..n-1]. Swapping only local/partner arrays leaves ordered in host order, so validate_handoff reports mock_detachment_ordered_partition_mismatch.
## Guest session: rotate ordered to partner||local, then rebuild local/partner as first k / rest of the new order (same k = ceil(n/2)).
func _coop_mock_detachment_dict_remapped_for_guest_session(m: Dictionary) -> Dictionary:
	var md: Dictionary = m.duplicate(true)
	var ord: Variant = md.get("ordered_command_unit_ids", [])
	if typeof(ord) != TYPE_ARRAY:
		return md
	var ord_a: Array = ord as Array
	var n: int = ord_a.size()
	if n <= 0:
		return md
	var k: int = MockCoopBattleContext.mock_coop_local_command_slot_count(n)
	var host_local: Array = []
	var host_partner: Array = []
	for i in range(n):
		if i < k:
			host_local.append(ord_a[i])
		else:
			host_partner.append(ord_a[i])
	var new_ordered: Array = []
	new_ordered.append_array(host_partner)
	new_ordered.append_array(host_local)
	var guest_local: Array = []
	var guest_partner: Array = []
	for i in range(n):
		if i < k:
			guest_local.append(new_ordered[i])
		else:
			guest_partner.append(new_ordered[i])
	md["ordered_command_unit_ids"] = new_ordered
	md["local_command_unit_ids"] = guest_local
	md["partner_command_unit_ids"] = guest_partner
	return md

## Finalize on the host embeds local_is_host=true and detachment lists from the host's POV. Session GUEST must remap before battle or ownership/UI/command gating desyncs (often crashes).
func _coop_handoff_remap_if_session_guest(h: Dictionary) -> Dictionary:
	if phase != Phase.GUEST:
		return h.duplicate(true)
	if not bool(h.get("local_is_host", false)):
		return h.duplicate(true)
	var d: Dictionary = h.duplicate(true)
	d["local_is_host"] = false
	var lp: Variant = d.get("local_player", {})
	var rp: Variant = d.get("remote_player", {})
	if typeof(lp) == TYPE_DICTIONARY and typeof(rp) == TYPE_DICTIONARY:
		d["local_player"] = (rp as Dictionary).duplicate(true)
		d["remote_player"] = (lp as Dictionary).duplicate(true)
	var mdv: Variant = d.get("mock_detachment_assignment", {})
	if typeof(mdv) == TYPE_DICTIONARY:
		d["mock_detachment_assignment"] = _coop_mock_detachment_dict_remapped_for_guest_session(mdv as Dictionary)
	var lsv: Variant = d.get("launch_snapshot", {})
	if typeof(lsv) == TYPE_DICTIONARY:
		var ls: Dictionary = (lsv as Dictionary).duplicate(true)
		ls["local_is_host"] = false
		var lsp: Variant = ls.get("local_player", {})
		var rsp: Variant = ls.get("remote_player", {})
		if typeof(lsp) == TYPE_DICTIONARY and typeof(rsp) == TYPE_DICTIONARY:
			ls["local_player"] = (rsp as Dictionary).duplicate(true)
			ls["remote_player"] = (lsp as Dictionary).duplicate(true)
		var lsd: Variant = ls.get("mock_detachment_assignment", {})
		if typeof(lsd) == TYPE_DICTIONARY:
			ls["mock_detachment_assignment"] = _coop_mock_detachment_dict_remapped_for_guest_session(lsd as Dictionary)
		d["launch_snapshot"] = ls
	return d

## Handoff embeds launch_snapshot (duplicate of payload) — drops ENet single-packet reliable delivery; guest never sees finalize_result.
## Also slims player dicts: large owned_expedition_map_ids arrays can still exceed reliable packet limits.
func _coop_handoff_slim_player_dict_for_enet_wire(p: Variant) -> Dictionary:
	if typeof(p) != TYPE_DICTIONARY:
		return {}
	var src: Dictionary = p as Dictionary
	var out: Dictionary = {
		"player_id": str(src.get("player_id", "")),
		"display_name": str(src.get("display_name", "")),
		"owned_expedition_map_ids": [],
		"ready": bool(src.get("ready", false)),
	}
	var cav: Variant = src.get("custom_avatar_snapshot", {})
	if cav is Dictionary:
		var cav_d: Dictionary = cav as Dictionary
		var mini: Dictionary = {}
		if cav_d.has("unit_name"):
			mini["unit_name"] = str(cav_d.get("unit_name", ""))
		if cav_d.has("class_data_path"):
			mini["class_data_path"] = str(cav_d.get("class_data_path", ""))
		if not mini.is_empty():
			out["custom_avatar_snapshot"] = mini
	return out


func _coop_handoff_clone_without_launch_snapshot_for_enet(h: Dictionary) -> Dictionary:
	if h.is_empty():
		return {}
	var d: Dictionary = h.duplicate(true)
	d.erase("launch_snapshot")
	d["local_player"] = _coop_handoff_slim_player_dict_for_enet_wire(d.get("local_player", {}))
	d["remote_player"] = _coop_handoff_slim_player_dict_for_enet_wire(d.get("remote_player", {}))
	return d

## Store + launch + optional signal. Charter host passes emit_committed=false and closes UI itself (avoids double queue_free).
func enet_execute_pending_handoff_launch(handoff: Dictionary, emit_committed: bool = true) -> Dictionary:
	if typeof(handoff) != TYPE_DICTIONARY or (handoff as Dictionary).is_empty():
		return {"ok": false, "errors": ["handoff_empty"]}
	var handoff_to_store: Dictionary = _coop_handoff_remap_if_session_guest(handoff as Dictionary)
	var store_res: Dictionary = CampaignManager.store_pending_mock_coop_battle_handoff(handoff_to_store)
	if not bool(store_res.get("ok", false)):
		return {"ok": false, "errors": store_res.get("errors", ["store_failed"])}
	var launch_res: Dictionary = CampaignManager.launch_expedition_with_pending_mock_coop_handoff()
	if not bool(launch_res.get("ok", false)):
		CampaignManager.clear_pending_mock_coop_battle_handoff()
		return {"ok": false, "errors": launch_res.get("errors", ["launch_failed"])}
	if emit_committed:
		enet_battle_launch_committed.emit()
	return {"ok": true, "errors": []}

func enet_apply_remote_launch_handoff(handoff: Dictionary) -> void:
	if typeof(handoff) != TYPE_DICTIONARY or (handoff as Dictionary).is_empty():
		push_warning("CoopExpeditionSessionManager: enet_apply_remote_launch_handoff missing handoff")
		return
	if _enet_guest_launch_apply_locked:
		push_warning("CoopExpeditionSessionManager: duplicate guest ENet launch apply ignored")
		return
	_enet_guest_launch_apply_locked = true
	var exec_res: Dictionary = enet_execute_pending_handoff_launch(handoff as Dictionary)
	if not bool(exec_res.get("ok", false)):
		_enet_guest_launch_apply_locked = false
		push_warning("CoopExpeditionSessionManager: guest ENet launch failed: %s" % str(exec_res.get("errors", [])))
		return

func has_remote_peer_for_staging() -> bool:
	if remote_player_payload.is_empty():
		return false
	var pid: String = str(remote_player_payload.get("player_id", "")).strip_edges()
	var dn: String = str(remote_player_payload.get("display_name", "")).strip_edges()
	return pid != "" or dn != ""

func get_coop_staging_state() -> int:
	if phase == Phase.NONE:
		return StagingState.INACTIVE
	if get_coop_launch_blockers().is_empty():
		return StagingState.READY_TO_LAUNCH
	if phase == Phase.HOST:
		if not has_remote_peer_for_staging():
			return StagingState.HOST_AWAITING_GUEST
		return StagingState.HOST_STAGING
	if phase == Phase.GUEST:
		return StagingState.GUEST_STAGING
	return StagingState.HOST_STAGING

func get_coop_staging_state_name() -> String:
	match get_coop_staging_state():
		StagingState.INACTIVE:
			return "INACTIVE"
		StagingState.HOST_AWAITING_GUEST:
			return "HOST_AWAITING_GUEST"
		StagingState.HOST_STAGING:
			return "HOST_STAGING"
		StagingState.GUEST_STAGING:
			return "GUEST_STAGING"
		StagingState.READY_TO_LAUNCH:
			return "READY_TO_LAUNCH"
		_:
			return "UNKNOWN"

func get_coop_launch_blockers() -> PackedStringArray:
	return _collect_coop_launch_blockers()

func _collect_coop_launch_blockers() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if phase == Phase.NONE:
		out.append("no_active_session")
		return out
	var mid: String = str(selected_expedition_map_id).strip_edges()
	if mid == "":
		out.append("no_expedition_selected")
		return out
	if not ExpeditionCoopEligibility.is_expedition_registered(mid):
		out.append("expedition_not_in_database")
		return out
	if not ExpeditionCoopEligibility.local_owns_coop_eligible_expedition(mid):
		out.append("local_player_not_coop_eligible_for_map")
		return out
	var map_data: Dictionary = ExpeditionMapDatabase.get_map_by_id(mid)
	if map_data.is_empty():
		out.append("expedition_data_missing")
	if phase == Phase.HOST and not has_remote_peer_for_staging():
		out.append("host_waiting_for_guest_payload")
	if phase == Phase.GUEST and not has_remote_peer_for_staging():
		out.append("guest_waiting_for_host_payload")
	var remote_owned: Array = remote_player_payload.get("owned_expedition_map_ids", [])
	if typeof(remote_owned) != TYPE_ARRAY:
		remote_owned = []
	if not ExpeditionCoopEligibility.can_start_coop_expedition(mid, remote_owned):
		out.append("remote_does_not_own_selected_coop_map")
	if not local_ready:
		out.append("local_not_ready")
	if not remote_ready:
		out.append("remote_not_ready")
	return out

func is_session_launchable() -> bool:
	return get_coop_launch_blockers().is_empty()

## Final gate for battle entry: same as build when launchable; includes error list when not.
func finalize_coop_expedition_launch() -> Dictionary:
	var blockers: PackedStringArray = get_coop_launch_blockers()
	if not blockers.is_empty():
		return {"ok": false, "errors": Array(blockers), "payload": {}}
	var payload: Dictionary = build_expedition_coop_launch_payload()
	if payload.is_empty():
		return {"ok": false, "errors": ["payload_build_failed"], "payload": {}}
	return {"ok": true, "errors": [], "payload": payload}

## Wraps finalize + CoopExpeditionBattleHandoff for debug / future battle entry bridge (no scene change).
func prepare_mock_coop_battle_handoff() -> Dictionary:
	return CoopExpeditionBattleHandoff.prepare_from_finalize_result(finalize_coop_expedition_launch())

## Data for a future shared battle entry (empty if not launchable).
func build_expedition_coop_launch_payload() -> Dictionary:
	if not is_session_launchable():
		return {}
	var map_data: Dictionary = ExpeditionMapDatabase.get_map_by_id(selected_expedition_map_id)
	if map_data.is_empty():
		return {}
	return {
		"session_id": session_id,
		"expedition_map_id": selected_expedition_map_id,
		"battle_scene_path": str(map_data.get("battle_scene_path", "")).strip_edges(),
		"battle_id": str(map_data.get("battle_id", "")).strip_edges(),
		"local_is_host": phase == Phase.HOST,
		"local_player": local_player_payload.duplicate(true),
		"remote_player": remote_player_payload.duplicate(true),
		"mock_detachment_assignment": MockCoopDetachmentAssignment.build_handoff_payload_dict(),
	}

func _default_local_payload() -> Dictionary:
	return {
		"player_id": "local",
		"display_name": "Commander",
		"owned_expedition_map_ids": [],
		"custom_avatar_snapshot": {},
		"ready": false,
	}

func _snapshot_avatar_for_coop_payload(avatar: Dictionary) -> Dictionary:
	var snap: Dictionary = {}
	if avatar.has("unit_name"):
		snap["unit_name"] = str(avatar.get("unit_name", ""))
	if avatar.get("class_data") is Resource:
		var cd: Resource = avatar["class_data"] as Resource
		snap["class_data_path"] = cd.resource_path
	elif avatar.get("class_data") is String:
		snap["class_data_path"] = str(avatar["class_data"])
	return snap

# --- ENet transport callbacks (invoked by ENetCoopTransport) ---

func _enet_transport_after_host_listen(listen_port: int) -> Dictionary:
	clear_session()
	session_id = "127.0.0.1:%d" % int(listen_port)
	phase = Phase.HOST
	refresh_local_player_payload_from_campaign()
	session_state_changed.emit()
	return {"ok": true, "session_id": session_id, "port": int(listen_port)}

func _enet_transport_begin_guest_connect(host: String, port: int) -> Dictionary:
	clear_session()
	session_id = "%s:%d" % [str(host).strip_edges(), int(port)]
	phase = Phase.GUEST
	refresh_local_player_payload_from_campaign()
	session_state_changed.emit()
	return {"ok": true, "session_id": session_id}

func _enet_host_on_client_joined(_peer_id: int) -> void:
	session_state_changed.emit()
	_enet_broadcast_session_snapshot()

func _enet_host_on_client_disconnected(_peer_id: int) -> void:
	release_enet_host_launch_pipeline()
	_enet_host_finalize_busy = false
	remote_player_payload = {}
	remote_ready = false
	session_state_changed.emit()

func _enet_guest_on_transport_connected() -> void:
	refresh_local_player_payload_from_campaign()
	_enet_guest_push_participant()

func _enet_guest_on_transport_disconnected() -> void:
	_enet_guest_finalize_pending = false
	_enet_guest_launch_apply_locked = false
	remote_player_payload = {}
	remote_ready = false
	session_state_changed.emit()

func _enet_host_confirm_map_from_transport(map_id: String) -> Dictionary:
	var key: String = str(map_id).strip_edges()
	if key == "":
		return {"ok": false, "error": "bad_map_id"}
	if not set_selected_expedition_map(key):
		return {"ok": false, "error": "local_ineligible"}
	return {"ok": true, "session_id": session_id}

func _enet_guest_push_participant() -> void:
	if not uses_enet_coop_transport() or phase != Phase.GUEST:
		return
	var tr: ENetCoopTransport = _transport as ENetCoopTransport
	if not tr.is_session_wired():
		return
	refresh_local_player_payload_from_campaign()
	tr.send_session_payload("guest_staging_join", local_player_payload.duplicate(true))

func _enet_build_session_snapshot() -> Dictionary:
	return {
		"session_id": session_id,
		"selected_expedition_map_id": selected_expedition_map_id,
		"host_player": local_player_payload.duplicate(true),
		"guest_player": remote_player_payload.duplicate(true),
		"host_ready": local_ready,
		"guest_ready": remote_ready,
	}

func _enet_broadcast_session_snapshot() -> void:
	if not uses_enet_coop_transport() or phase != Phase.HOST:
		return
	var tr: ENetCoopTransport = _transport as ENetCoopTransport
	if not tr.is_session_wired():
		return
	tr.host_broadcast_coop_message("session_snapshot", _enet_build_session_snapshot())

func _enet_apply_session_snapshot(body: Dictionary) -> void:
	if phase != Phase.GUEST:
		return
	session_id = str(body.get("session_id", session_id)).strip_edges()
	selected_expedition_map_id = str(body.get("selected_expedition_map_id", "")).strip_edges()
	var hp: Variant = body.get("host_player", {})
	if hp is Dictionary:
		remote_player_payload = (hp as Dictionary).duplicate(true)
		remote_ready = bool(remote_player_payload.get("ready", false))
	else:
		remote_ready = bool(body.get("host_ready", false))
	if body.has("guest_ready"):
		var gr: bool = bool(body.get("guest_ready", false))
		if local_ready != gr:
			local_ready = gr
			local_player_payload["ready"] = local_ready
	session_state_changed.emit()

func _enet_receive_coop_message(from_peer_id: int, kind: String, body: Dictionary) -> void:
	if not uses_enet_coop_transport():
		return
	if phase == Phase.NONE:
		return
	var k: String = str(kind).strip_edges()
	if phase == Phase.HOST:
		if from_peer_id < 2:
			return
		match k:
			"participant_update":
				_enet_host_handle_participant_update(body)
			"selected_map_intent":
				_enet_host_apply_guest_map_intent(str(body.get("map_id", "")).strip_edges())
			"finalize_request":
				_enet_host_handle_finalize_request()
			"coop_battle_sync":
				_enet_apply_incoming_coop_battle_sync(body)
			_:
				pass
	elif phase == Phase.GUEST:
		## Server is normally peer 1; reject only clearly-invalid senders (LAN single-host topology).
		if from_peer_id <= 0:
			return
		match k:
			"session_snapshot":
				_enet_apply_session_snapshot(body)
			"finalize_result":
				_enet_guest_handle_finalize_result(body)
			"launch_handoff":
				_enet_guest_handle_launch_handoff(body)
			"coop_battle_sync":
				_enet_apply_incoming_coop_battle_sync(body)
			_:
				pass

func _enet_host_handle_participant_update(body: Dictionary) -> void:
	if body.is_empty():
		return
	remote_player_payload = body.duplicate(true)
	if remote_player_payload.has("ready"):
		remote_ready = bool(remote_player_payload.get("ready", false))
	session_state_changed.emit()
	_enet_broadcast_session_snapshot()

func _enet_host_apply_guest_map_intent(map_id: String) -> void:
	var key: String = str(map_id).strip_edges()
	if key == "":
		_enet_broadcast_session_snapshot()
		return
	if not ExpeditionCoopEligibility.local_owns_coop_eligible_expedition(key):
		_enet_broadcast_session_snapshot()
		return
	var remote_owned: Array = remote_player_payload.get("owned_expedition_map_ids", [])
	if typeof(remote_owned) != TYPE_ARRAY:
		remote_owned = []
	if not ExpeditionCoopEligibility.can_start_coop_expedition(key, remote_owned):
		_enet_broadcast_session_snapshot()
		return
	selected_expedition_map_id = key
	session_state_changed.emit()
	_enet_broadcast_session_snapshot()

func _enet_host_handle_finalize_request() -> void:
	var tr: ENetCoopTransport = _transport as ENetCoopTransport
	if not tr.is_session_wired():
		return
	if _enet_host_finalize_busy:
		tr.host_broadcast_coop_message("finalize_result", {
			"ok": false,
			"errors": ["host_finalize_busy"],
			"finalize": {"ok": false, "errors": ["host_finalize_busy"], "payload": {}},
		})
		return
	if not try_begin_enet_host_launch_pipeline():
		tr.host_broadcast_coop_message("finalize_result", {
			"ok": false,
			"errors": ["host_launch_pipeline_locked"],
			"finalize": {"ok": false, "errors": ["host_launch_pipeline_locked"], "payload": {}},
		})
		return
	_enet_host_finalize_busy = true
	var fin: Dictionary = finalize_coop_expedition_launch()
	if not bool(fin.get("ok", false)):
		release_enet_host_launch_pipeline()
		_enet_host_finalize_busy = false
		tr.host_broadcast_coop_message("finalize_result", {"ok": false, "finalize": fin})
		return
	var hand_res: Dictionary = CoopExpeditionBattleHandoff.prepare_from_finalize_result(fin)
	if not bool(hand_res.get("ok", false)):
		release_enet_host_launch_pipeline()
		_enet_host_finalize_busy = false
		tr.host_broadcast_coop_message("finalize_result", {
			"ok": false,
			"finalize": fin,
			"errors": hand_res.get("errors", []),
		})
		return
	var hh: Variant = hand_res.get("handoff", {})
	if typeof(hh) != TYPE_DICTIONARY:
		release_enet_host_launch_pipeline()
		_enet_host_finalize_busy = false
		tr.host_broadcast_coop_message("finalize_result", {"ok": false, "finalize": fin, "errors": ["handoff_missing"]})
		return
	var hh_d: Dictionary = hh as Dictionary
	## Slim wire payload: full finalize + launch_snapshot often exceeds ENet reliable packet size — guest then never receives OK.
	var wire_handoff: Dictionary = _coop_handoff_clone_without_launch_snapshot_for_enet(hh_d)
	var sent_ok: bool = tr.host_broadcast_coop_message("finalize_result", {"ok": true, "handoff": wire_handoff})
	if not sent_ok:
		release_enet_host_launch_pipeline()
		_enet_host_finalize_busy = false
		push_warning("CoopExpeditionSessionManager: finalize_result broadcast failed (oversize or disconnect).")
		return
	_enet_host_handoff_for_deferred_launch = hh_d.duplicate(true)
	_enet_schedule_host_finalize_launch_after_packet_flush()

func _enet_schedule_host_finalize_launch_after_packet_flush() -> void:
	## Defer past a few idle ticks + wall time so the guest OS socket receives finalize_result before this instance spikes loading the battle scene.
	var tree: SceneTree = get_tree()
	if tree == null:
		call_deferred("_enet_host_complete_finalize_launch_after_network")
		return
	var t: SceneTreeTimer = tree.create_timer(0.18, true, true, true)
	t.timeout.connect(_enet_host_complete_finalize_launch_after_network, CONNECT_ONE_SHOT)

func _enet_host_complete_finalize_launch_after_network() -> void:
	var hh: Dictionary = _enet_host_handoff_for_deferred_launch.duplicate(true)
	_enet_host_handoff_for_deferred_launch.clear()
	var exec_res: Dictionary = enet_execute_pending_handoff_launch(hh, true)
	_enet_host_finalize_busy = false
	if not bool(exec_res.get("ok", false)):
		release_enet_host_launch_pipeline()
		push_warning("CoopExpeditionSessionManager: host finalize launch failed: %s" % str(exec_res.get("errors", [])))
		return
	release_enet_host_launch_pipeline()

func _enet_guest_handle_finalize_result(body: Dictionary) -> void:
	_enet_guest_finalize_pending = false
	var fin: Variant = body.get("finalize", {})
	if typeof(fin) != TYPE_DICTIONARY:
		fin = {}
	var fin_d: Dictionary = fin as Dictionary
	if not bool(body.get("ok", false)):
		var errs: Array = []
		var be: Variant = body.get("errors", [])
		if be is Array and not (be as Array).is_empty():
			errs = (be as Array).duplicate()
		elif not bool(fin_d.get("ok", true)) and fin_d.get("errors") is Array:
			errs = (fin_d["errors"] as Array).duplicate()
		else:
			errs.append("finalize_rejected")
		enet_guest_finalize_finished.emit({"ok": false, "errors": errs, "payload": {}})
		return
	var hh: Variant = body.get("handoff", {})
	if typeof(hh) != TYPE_DICTIONARY:
		enet_guest_finalize_finished.emit({"ok": false, "errors": ["handoff_missing"], "payload": {}})
		return
	enet_apply_remote_launch_handoff(hh as Dictionary)

func _enet_guest_handle_launch_handoff(body: Dictionary) -> void:
	_enet_guest_finalize_pending = false
	var hh: Variant = body.get("handoff", {})
	if typeof(hh) != TYPE_DICTIONARY:
		return
	enet_apply_remote_launch_handoff(hh as Dictionary)

# --- Local transport callbacks (invoked by LocalLoopbackCoopTransport) ---

func _local_transport_create_host() -> Dictionary:
	clear_session()
	session_id = "local_host_%d" % Time.get_ticks_msec()
	phase = Phase.HOST
	refresh_local_player_payload_from_campaign()
	session_state_changed.emit()
	return {"ok": true, "session_id": session_id}

func _local_transport_join(session_descriptor: String) -> Dictionary:
	clear_session()
	session_id = str(session_descriptor).strip_edges()
	if session_id == "":
		session_id = "local_join_%d" % Time.get_ticks_msec()
	phase = Phase.GUEST
	refresh_local_player_payload_from_campaign()
	session_state_changed.emit()
	return {"ok": true, "session_id": session_id}

func _local_transport_leave() -> void:
	## Disconnect/cleanup only; CoopExpeditionSessionManager.leave_session() owns clear_session() to avoid double-clear.
	pass

func _local_transport_send_payload(_kind: String, payload: Dictionary) -> void:
	## Loopback: host applies inbound peer snapshot (guest join / roster sync). Kind reserved for future routing.
	remote_player_payload = payload.duplicate(true)
	if remote_player_payload.has("ready"):
		remote_ready = bool(remote_player_payload.get("ready", false))
	session_state_changed.emit()

func _local_transport_start_expedition(map_id: String) -> Dictionary:
	var key: String = str(map_id).strip_edges()
	if key == "":
		return {"ok": false, "error": "bad_map_id"}
	if not set_selected_expedition_map(key):
		return {"ok": false, "error": "local_ineligible"}
	return {"ok": true, "session_id": session_id}

## Same-process mock partner for Expedition Charter / loopback transport (not network). Host only.
func apply_loopback_partner_staging_payload(owned_map_ids: Array, partner_ready: bool = false) -> Dictionary:
	if phase != Phase.HOST:
		return {"ok": false, "error": "not_host"}
	var ids: Array[String] = []
	for x in owned_map_ids:
		var s: String = str(x).strip_edges()
		if s != "":
			ids.append(s)
	var guest_payload: Dictionary = {
		"player_id": "loopback_guest",
		"display_name": "Loopback Guest",
		"owned_expedition_map_ids": ids,
		"custom_avatar_snapshot": {"unit_name": "Loopback Guest"},
		"ready": partner_ready,
	}
	get_transport().send_session_payload("guest_staging_join", guest_payload)
	return {"ok": true, "staging_state": get_coop_staging_state()}

# --- Debug / mock (editor & debug builds only) ---

## After begin_host_session: inject a guest peer payload (same machine). Then set map + readiness via normal APIs.
func debug_apply_mock_guest_payload_for_staging(owned_map_ids: Array, guest_ready: bool = false) -> Dictionary:
	if not OS.is_debug_build():
		return {"ok": false, "error": "debug_only"}
	return apply_loopback_partner_staging_payload(owned_map_ids, guest_ready)

## Guest-side single process: after join_session(host_session_id), apply mock host peer for staging tests.
func debug_apply_mock_host_payload_for_staging(owned_map_ids: Array, host_ready: bool = false) -> Dictionary:
	if not OS.is_debug_build():
		return {"ok": false, "error": "debug_only"}
	if phase != Phase.GUEST:
		return {"ok": false, "error": "not_guest"}
	var ids: Array[String] = []
	for x in owned_map_ids:
		var s: String = str(x).strip_edges()
		if s != "":
			ids.append(s)
	var host_payload: Dictionary = {
		"player_id": "loopback_host",
		"display_name": "Loopback Host",
		"owned_expedition_map_ids": ids,
		"custom_avatar_snapshot": {"unit_name": "Loopback Host"},
		"ready": host_ready,
	}
	get_transport().send_session_payload("host_staging_join", host_payload)
	return {"ok": true, "staging_state": get_coop_staging_state()}

func debug_simulate_ready_coop_pair(map_id: String) -> Dictionary:
	if not OS.is_debug_build():
		return {"ok": false, "error": "debug_only"}
	var key: String = str(map_id).strip_edges()
	if key == "":
		return {"ok": false, "error": "bad_map_id"}
	var res: Dictionary = begin_host_session()
	if not bool(res.get("ok", false)):
		return res
	if not set_selected_expedition_map(key):
		leave_session()
		return {"ok": false, "error": "local_not_eligible"}
	refresh_local_player_payload_from_campaign()
	remote_player_payload = {
		"player_id": "mock_remote",
		"display_name": "Mock Co-op Partner",
		"owned_expedition_map_ids": [key],
		"custom_avatar_snapshot": {"unit_name": "Mock Partner"},
		"ready": true,
	}
	remote_ready = true
	local_ready = true
	local_player_payload["ready"] = true
	session_state_changed.emit()
	return {"ok": true, "launchable": is_session_launchable(), "payload": build_expedition_coop_launch_payload()}
