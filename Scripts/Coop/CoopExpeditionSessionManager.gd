extends Node

## Central co-op expedition session state (host/guest, readiness, selected map).
## Dormant until begin_host_session / join_session / debug hooks run. Single-player flow does not use this node.

signal session_state_changed
signal enet_battle_launch_committed
## Guest-side finalize over ENet: emitted when host returns errors (ok=false) so UI can refresh.
signal enet_guest_finalize_finished(fin: Dictionary)

enum Phase { NONE, HOST, GUEST }

## In-battle ENet: pause and wait for peer after disconnect; host may continue solo after this window.
## Tuning: shorter window keeps tension; longer helps flaky LAN. Pair with [member RUNTIME_COOP_RECONNECT_USE_TREE_PAUSE].
const RUNTIME_COOP_RECONNECT_GRACE_SEC: float = 90.0
## If [code]true[/code], grace uses [code]get_tree().paused[/code] (menus with [code]PROCESS_MODE_ALWAYS[/code] still work). If [code]false[/code], battle-only soft-freeze (no global pause; see [method BattleField.coop_reconnect_grace_blocks_gameplay]).
const RUNTIME_COOP_RECONNECT_USE_TREE_PAUSE: bool = false

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
var _runtime_coop_reconnect_grace_deadline_msec: int = 0
## Host only: guest never returned within grace — stop sending runtime battle sync; promote partner units locally on the battlefield.
var _runtime_coop_host_solo_after_dropout: bool = false

func _ready() -> void:
	## Keep polling ENet while other UI pauses the tree or a window loses focus (two-instance LAN testing).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_transport = LocalLoopbackCoopTransport.new()
	_transport.bind_manager(self)
	clear_session()

func _process(_delta: float) -> void:
	_runtime_coop_tick_reconnect_grace_if_needed()
	if runtime_coop_reconnect_grace_active():
		var bfo: Node = _enet_battle_sync_battlefield
		if bfo != null and is_instance_valid(bfo) and bfo.has_method("coop_enet_refresh_reconnect_grace_overlay"):
			bfo.call("coop_enet_refresh_reconnect_grace_overlay")
	if _transport == null:
		return
	_transport.poll_transport()
	## While awaiting finalize_result, poll twice per frame so a just-flushed host packet is less likely to sit one frame behind a heavy scene change on the other instance.
	if _enet_guest_finalize_pending:
		_transport.poll_transport()

## May be [code]null[/code] after [method leave_session] until [method ensure_loopback_coop_transport_if_absent], [method begin_host_session], or [method set_transport].
func get_transport() -> CoopSessionTransport:
	return _transport

## Swap transport (e.g. future lobby-backed implementation). Call clear_session first if switching mid-flight.
func set_transport(transport: CoopSessionTransport) -> void:
	if transport == null:
		return
	if _transport != null and _transport != transport:
		_transport.leave_session()
	_transport = transport
	transport.bind_manager(self)

func clear_session() -> void:
	var bf_prev: Node = _enet_battle_sync_battlefield
	if bf_prev != null and is_instance_valid(bf_prev) and bf_prev.has_method("coop_enet_clear_reconnect_grace_pause_if_any"):
		bf_prev.call("coop_enet_clear_reconnect_grace_pause_if_any")
	session_id = ""
	phase = Phase.NONE
	selected_expedition_map_id = ""
	local_player_payload = _default_local_payload()
	remote_player_payload = {}
	local_ready = false
	remote_ready = false
	_runtime_coop_reconnect_grace_deadline_msec = 0
	_runtime_coop_host_solo_after_dropout = false
	_enet_reset_enet_staging_guards()
	_enet_battle_sync_battlefield = null
	_coop_battle_rng_seed_sent = false
	session_state_changed.emit()

## Drops the active transport reference after teardown ([code]_transport == null[/code]) so detached backends are never polled or messaged.
## Restore loopback with [method ensure_loopback_coop_transport_if_absent] or switch mode with [method set_transport]. [method begin_host_session] ensures loopback automatically.
func leave_session() -> void:
	if _transport != null:
		_transport.leave_session()
		_transport = null
	clear_session()


func ensure_loopback_coop_transport_if_absent() -> void:
	if _transport != null:
		return
	_transport = LocalLoopbackCoopTransport.new()
	_transport.bind_manager(self)

func _enet_reset_enet_staging_guards() -> void:
	_enet_host_launch_pipeline_locked = false
	_enet_guest_launch_apply_locked = false
	_enet_host_finalize_busy = false
	_enet_guest_finalize_pending = false
	_enet_host_handoff_for_deferred_launch.clear()

func register_enet_coop_battle_sync_battlefield(battlefield: Node) -> void:
	if battlefield == null:
		return
	if not uses_runtime_network_coop_transport():
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
	if not uses_runtime_network_coop_transport():
		return
	if not is_runtime_coop_session_wired():
		return
	if _enet_battle_sync_battlefield == null or not is_instance_valid(_enet_battle_sync_battlefield):
		return
	var picker := RandomNumberGenerator.new()
	picker.randomize()
	var s: int = picker.randi()
	_coop_battle_rng_seed_sent = true
	var body: Dictionary = {"action": "battle_rng_seed", "seed": s, "v": 1, "from_host": true}
	broadcast_transport_message("coop_battle_sync", body)
	if _enet_battle_sync_battlefield.has_method("apply_coop_battle_net_rng_seed"):
		_enet_battle_sync_battlefield.call("apply_coop_battle_net_rng_seed", s)

## Mock co-op battle replication (move, defend, combat, …). Adds schema + from_host from session phase.
func enet_send_coop_battle_sync_action(payload: Dictionary) -> void:
	if not uses_runtime_network_coop_transport():
		return
	if _runtime_coop_host_solo_after_dropout:
		return
	if _enet_battle_sync_battlefield == null or not is_instance_valid(_enet_battle_sync_battlefield):
		if OS.is_debug_build():
			var act_missing_bf: String = str(payload.get("action", "")).strip_edges()
			push_warning("CoopExpeditionSessionManager: drop local coop_battle_sync '%s' (no registered battlefield)" % act_missing_bf)
		return
	if not is_runtime_coop_session_wired():
		return
	var body: Dictionary = payload.duplicate(true)
	body["v"] = 1
	body["from_host"] = (phase == Phase.HOST)
	if phase == Phase.HOST:
		broadcast_transport_message("coop_battle_sync", body)
	elif phase == Phase.GUEST:
		send_transport_message("coop_battle_sync", body)

func _enet_apply_incoming_coop_battle_sync(body: Dictionary) -> void:
	if _runtime_coop_host_solo_after_dropout:
		return
	var bf: Node = _enet_battle_sync_battlefield
	if bf == null or not is_instance_valid(bf):
		if OS.is_debug_build():
			var act_missing_bf: String = str(body.get("action", "")).strip_edges()
			push_warning("CoopExpeditionSessionManager: drop incoming coop_battle_sync '%s' (no registered battlefield)" % act_missing_bf)
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
	if act == "full_battle_resync":
		if i_am_host:
			return
		if bf.has_method("coop_enet_schedule_full_battle_resync_from_host"):
			bf.call("coop_enet_schedule_full_battle_resync_from_host", body.duplicate(true))
		return
	## Guest buffers host-led AI/enemy strikes; local AITurnState consumes FIFO (see [method BattleField.coop_enet_ai_execute_combat]).
	if act == "enemy_combat":
		if bf.has_method("coop_enet_buffer_incoming_enemy_combat"):
			bf.call("coop_enet_buffer_incoming_enemy_combat", body.duplicate(true))
		return
	if bf.has_method("apply_remote_coop_enet_sync"):
		bf.apply_remote_coop_enet_sync(body)

func begin_host_session() -> Dictionary:
	ensure_loopback_coop_transport_if_absent()
	return _transport.create_session()

func join_session(session_descriptor: String) -> Dictionary:
	if _transport == null:
		return {"ok": false, "error": "no_transport"}
	return _transport.join_session(session_descriptor)

func _mock_coop_role_key_for_phase(p: int = phase) -> String:
	match p:
		Phase.HOST:
			return "host"
		Phase.GUEST:
			return "guest"
		_:
			return "host"

func _build_coop_player_payload_from_campaign(player_id_str: String, display_name_override: String, ready_value: bool, role_key: String, owned_map_ids: Array[String], selected_companion_id: String = "") -> Dictionary:
	var name_str: String = str(display_name_override).strip_edges()
	if name_str == "":
		name_str = str(CampaignManager.custom_avatar.get("unit_name", "Commander")).strip_edges()
	if name_str == "":
		name_str = "Commander"
	var party: Dictionary = CampaignManager.build_mock_coop_player_party_payload(selected_companion_id, role_key)
	return {
		"player_id": str(player_id_str).strip_edges(),
		"display_name": name_str,
		"owned_expedition_map_ids": owned_map_ids.duplicate(),
		"custom_avatar_snapshot": _snapshot_avatar_for_coop_payload(CampaignManager.custom_avatar),
		"ready": ready_value,
		"selected_companion_unit_id": str(party.get("selected_companion_unit_id", "")).strip_edges(),
		"selected_companion_display_name": str(party.get("selected_companion_display_name", "")).strip_edges(),
		"coop_party_avatar_command_id": str(party.get("avatar_command_id", "")).strip_edges(),
		"coop_party_avatar_display_name": str(party.get("avatar_display_name", name_str)).strip_edges(),
		"coop_party_avatar_snapshot": (party.get("avatar_snapshot", {}) as Dictionary).duplicate(true) if party.get("avatar_snapshot", {}) is Dictionary else {},
		"coop_party_companion_command_id": str(party.get("selected_companion_command_id", "")).strip_edges(),
		"coop_party_companion_snapshot": (party.get("selected_companion_snapshot", {}) as Dictionary).duplicate(true) if party.get("selected_companion_snapshot", {}) is Dictionary else {},
	}


func refresh_local_player_payload_from_campaign() -> void:
	var selected_companion_id: String = str(local_player_payload.get("selected_companion_unit_id", "")).strip_edges()
	local_player_payload = _build_coop_player_payload_from_campaign(
			"local",
			"",
			local_ready,
			_mock_coop_role_key_for_phase(),
			CampaignManager.get_coop_eligible_expedition_map_ids(),
			selected_companion_id
	)


func get_local_selected_companion_unit_id() -> String:
	return str(local_player_payload.get("selected_companion_unit_id", "")).strip_edges()


func set_local_selected_companion_unit_id(unit_id: String) -> bool:
	var requested: String = str(unit_id).strip_edges()
	var before: String = get_local_selected_companion_unit_id()
	local_player_payload["selected_companion_unit_id"] = requested
	refresh_local_player_payload_from_campaign()
	var after: String = get_local_selected_companion_unit_id()
	if after == "":
		return false
	if before == after and requested == after:
		return true
	session_state_changed.emit()
	if uses_network_coop_staging_transport() and phase == Phase.GUEST:
		_enet_guest_push_participant()
	elif uses_network_coop_staging_transport() and phase == Phase.HOST:
		_enet_broadcast_session_snapshot()
	return true

func set_local_ready(value: bool) -> void:
	local_ready = value
	local_player_payload["ready"] = local_ready
	session_state_changed.emit()
	if uses_network_coop_staging_transport() and phase == Phase.GUEST:
		_enet_guest_push_participant()
	elif uses_network_coop_staging_transport() and phase == Phase.HOST:
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
	if uses_network_coop_staging_transport() and phase == Phase.GUEST:
		send_transport_message("selected_map_intent", {"map_id": key})
		_enet_guest_push_participant()
	elif uses_network_coop_staging_transport() and phase == Phase.HOST:
		_enet_broadcast_session_snapshot()
	return true

func uses_loopback_coop_transport() -> bool:
	return _transport is LocalLoopbackCoopTransport

func uses_enet_coop_transport() -> bool:
	return _transport is ENetCoopTransport

func uses_online_coop_transport() -> bool:
	return _transport is SilentWolfOnlineCoopTransport


func uses_steam_coop_transport() -> bool:
	return _transport is SteamLobbyCoopTransport


func get_transport_mode_id() -> String:
	if _transport == null:
		return "none"
	return _transport.transport_mode_id()


func uses_network_coop_staging_transport() -> bool:
	return _transport != null and _transport.supports_staging_coop_sync()


func uses_runtime_network_coop_transport() -> bool:
	return _transport != null and _transport.supports_runtime_coop_sync()


func is_runtime_coop_session_wired() -> bool:
	return _transport != null and _transport.is_session_wired()


func send_transport_message(kind: String, body: Dictionary) -> bool:
	if _transport == null:
		return false
	return _transport.send_transport_message(str(kind), body.duplicate(true))


func broadcast_transport_message(kind: String, body: Dictionary) -> bool:
	if _transport == null:
		return false
	return _transport.broadcast_transport_message(str(kind), body.duplicate(true))


func register_runtime_coop_battle_sync_target(battlefield: Node) -> void:
	register_enet_coop_battle_sync_battlefield(battlefield)


func unregister_runtime_coop_battle_sync_target(battlefield: Node) -> void:
	unregister_enet_coop_battle_sync_battlefield(battlefield)


## ENet (and future transports): peer dropped while a battle may still be registered — unblock guest combat waits and host pipeline flags.
func notify_runtime_coop_battle_transport_peer_lost() -> void:
	var bf: Node = _enet_battle_sync_battlefield
	if bf == null or not is_instance_valid(bf):
		return
	if bf.has_method("coop_enet_on_transport_peer_lost"):
		bf.call("coop_enet_on_transport_peer_lost")


func notify_runtime_coop_battle_reconnect_grace_started(grace_sec: float) -> void:
	var bf: Node = _enet_battle_sync_battlefield
	if bf == null or not is_instance_valid(bf):
		return
	if bf.has_method("coop_enet_on_reconnect_grace_started"):
		bf.call("coop_enet_on_reconnect_grace_started", grace_sec)


func notify_runtime_coop_battle_reconnect_grace_cancelled() -> void:
	var bf: Node = _enet_battle_sync_battlefield
	if bf == null or not is_instance_valid(bf):
		return
	if bf.has_method("coop_enet_on_reconnect_grace_cancelled_peer_returned"):
		bf.call("coop_enet_on_reconnect_grace_cancelled_peer_returned")


func notify_runtime_coop_battle_host_continue_solo() -> void:
	var bf: Node = _enet_battle_sync_battlefield
	if bf == null or not is_instance_valid(bf):
		return
	if bf.has_method("coop_enet_on_host_continue_solo_after_partner_dropout"):
		bf.call("coop_enet_on_host_continue_solo_after_partner_dropout")


func notify_runtime_coop_battle_guest_grace_expired() -> void:
	var bf: Node = _enet_battle_sync_battlefield
	if bf == null or not is_instance_valid(bf):
		return
	if bf.has_method("coop_enet_on_guest_reconnect_grace_expired"):
		bf.call("coop_enet_on_guest_reconnect_grace_expired")


func runtime_coop_reconnect_grace_active() -> bool:
	return _runtime_coop_reconnect_grace_deadline_msec > 0 and Time.get_ticks_msec() < _runtime_coop_reconnect_grace_deadline_msec


func get_runtime_coop_reconnect_grace_remaining_sec() -> float:
	if _runtime_coop_reconnect_grace_deadline_msec <= 0:
		return 0.0
	return maxf(0.0, float(_runtime_coop_reconnect_grace_deadline_msec - Time.get_ticks_msec()) / 1000.0)


func get_runtime_coop_reconnect_grace_seconds_config() -> float:
	return RUNTIME_COOP_RECONNECT_GRACE_SEC


func runtime_coop_reconnect_uses_tree_pause() -> bool:
	return RUNTIME_COOP_RECONNECT_USE_TREE_PAUSE


func enet_send_runtime_full_battle_resync_to_guest() -> void:
	if phase != Phase.HOST or not uses_runtime_network_coop_transport():
		return
	if _runtime_coop_host_solo_after_dropout:
		return
	if not is_runtime_coop_session_wired():
		return
	var bf: Node = _enet_battle_sync_battlefield
	if bf == null or not is_instance_valid(bf) or not bf.has_method("coop_enet_build_full_battle_resync_wire_body"):
		return
	var inner: Dictionary = bf.call("coop_enet_build_full_battle_resync_wire_body") as Dictionary
	if inner.is_empty():
		return
	var wire: Dictionary = inner.duplicate(true)
	wire["v"] = 1
	wire["from_host"] = true
	if not wire.has("action"):
		wire["action"] = "full_battle_resync"
	var json_len: int = JSON.stringify(wire).length()
	if OS.is_debug_build() and json_len > 32000:
		push_warning(
			"Coop: full_battle_resync payload is large (%d chars) — may exceed transport limits; consider slimming." % json_len
		)
	broadcast_transport_message("coop_battle_sync", wire)


func runtime_coop_host_solo_after_partner_dropout() -> bool:
	return _runtime_coop_host_solo_after_dropout


func _runtime_coop_tick_reconnect_grace_if_needed() -> void:
	if _runtime_coop_reconnect_grace_deadline_msec <= 0:
		return
	if Time.get_ticks_msec() < _runtime_coop_reconnect_grace_deadline_msec:
		return
	_runtime_coop_reconnect_grace_deadline_msec = 0
	if phase == Phase.HOST:
		_runtime_coop_host_solo_after_dropout = true
		remote_player_payload = {}
		remote_ready = false
		notify_runtime_coop_battle_host_continue_solo()
		session_state_changed.emit()
	elif phase == Phase.GUEST:
		remote_player_payload = {}
		remote_ready = false
		notify_runtime_coop_battle_guest_grace_expired()
		leave_session()


func runtime_coop_battle_sync_active() -> bool:
	return (
			uses_runtime_network_coop_transport()
			and phase != Phase.NONE
			and _enet_battle_sync_battlefield != null
			and is_instance_valid(_enet_battle_sync_battlefield)
	)


func send_runtime_coop_action(payload: Dictionary) -> void:
	enet_send_coop_battle_sync_action(payload)


func try_publish_runtime_coop_battle_rng_seed() -> void:
	enet_try_publish_coop_battle_rng_seed()


func runtime_host_can_mirror_launch_handoff() -> bool:
	return should_enet_mirror_launch_handoff_to_guest()


func host_send_runtime_launch_handoff(handoff: Dictionary) -> void:
	enet_host_send_launch_handoff(handoff)


func request_runtime_finalize_launch() -> void:
	enet_guest_request_finalize_launch()


func is_runtime_finalize_request_pending() -> bool:
	return is_enet_guest_finalize_request_pending()


func clear_runtime_finalize_pending() -> void:
	clear_enet_guest_finalize_pending()


func try_begin_runtime_launch_pipeline() -> bool:
	return try_begin_enet_host_launch_pipeline()


func release_runtime_launch_pipeline() -> void:
	release_enet_host_launch_pipeline()


func execute_pending_runtime_handoff_launch(handoff: Dictionary, emit_committed: bool = true) -> Dictionary:
	return enet_execute_pending_handoff_launch(handoff, emit_committed)


func runtime_launch_flush_delay_seconds() -> float:
	if _transport == null:
		return 0.18
	return max(0.0, _transport.recommended_runtime_launch_flush_delay_seconds())


func should_enet_mirror_launch_handoff_to_guest() -> bool:
	if not uses_runtime_network_coop_transport() or phase != Phase.HOST:
		return false
	return is_runtime_coop_session_wired()

func enet_host_send_launch_handoff(handoff: Dictionary) -> void:
	if not should_enet_mirror_launch_handoff_to_guest():
		return
	var wire: Dictionary = _coop_handoff_clone_without_launch_snapshot_for_enet(handoff as Dictionary)
	broadcast_transport_message("launch_handoff", {"handoff": wire})

func enet_guest_request_finalize_launch() -> void:
	if not uses_runtime_network_coop_transport() or phase != Phase.GUEST:
		return
	if not is_runtime_coop_session_wired():
		return
	if _enet_guest_finalize_pending:
		return
	_enet_guest_finalize_pending = true
	session_state_changed.emit()
	send_transport_message("finalize_request", {})

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
	var ordered_ids_value: Variant = md.get("ordered_command_unit_ids", [])
	if typeof(ordered_ids_value) != TYPE_ARRAY:
		return md
	var ord_a: Array = ordered_ids_value as Array
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
		var compact_avatar: Dictionary = {}
		if cav_d.has("unit_name"):
			compact_avatar["unit_name"] = str(cav_d.get("unit_name", ""))
		if cav_d.has("class_data_path"):
			compact_avatar["class_data_path"] = str(cav_d.get("class_data_path", ""))
		if not compact_avatar.is_empty():
			out["custom_avatar_snapshot"] = compact_avatar
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
	if not _player_payload_has_required_mock_coop_party(local_player_payload):
		out.append("local_commander_party_incomplete")
	if not _player_payload_has_required_mock_coop_party(remote_player_payload):
		out.append("remote_commander_party_incomplete")
	if not local_ready:
		out.append("local_not_ready")
	if not remote_ready:
		out.append("remote_not_ready")
	return out


func _player_payload_has_required_mock_coop_party(payload: Dictionary) -> bool:
	var avatar_id: String = str(payload.get("coop_party_avatar_command_id", "")).strip_edges()
	var avatar_snap: Variant = payload.get("coop_party_avatar_snapshot", {})
	var companion_id: String = str(payload.get("coop_party_companion_command_id", "")).strip_edges()
	var companion_snap: Variant = payload.get("coop_party_companion_snapshot", {})
	return (
			avatar_id != ""
			and avatar_snap is Dictionary
			and not (avatar_snap as Dictionary).is_empty()
			and companion_id != ""
			and companion_snap is Dictionary
			and not (companion_snap as Dictionary).is_empty()
	)


func _append_payload_party_unit_snapshot(out: Array, payload: Dictionary, snapshot_key: String) -> void:
	var raw: Variant = payload.get(snapshot_key, {})
	if raw is Dictionary and not (raw as Dictionary).is_empty():
		out.append((raw as Dictionary).duplicate(true))


func _build_mock_coop_detachment_assignment_from_session_players() -> Dictionary:
	var local_ids: Array = []
	var remote_ids: Array = []
	var local_avatar_id: String = str(local_player_payload.get("coop_party_avatar_command_id", "")).strip_edges()
	var local_companion_id: String = str(local_player_payload.get("coop_party_companion_command_id", "")).strip_edges()
	var remote_avatar_id: String = str(remote_player_payload.get("coop_party_avatar_command_id", "")).strip_edges()
	var remote_companion_id: String = str(remote_player_payload.get("coop_party_companion_command_id", "")).strip_edges()
	if local_avatar_id != "":
		local_ids.append(local_avatar_id)
	if local_companion_id != "":
		local_ids.append(local_companion_id)
	if remote_avatar_id != "":
		remote_ids.append(remote_avatar_id)
	if remote_companion_id != "":
		remote_ids.append(remote_companion_id)
	var ordered: Array = local_ids.duplicate()
	ordered.append_array(remote_ids)
	return {
		"rule": MockCoopDetachmentAssignment.RULE_FIRST_HALF_LOCAL_CEIL_LOCKED,
		"ordered_command_unit_ids": ordered,
		"local_command_unit_ids": local_ids,
		"partner_command_unit_ids": remote_ids,
	}


func _build_mock_coop_shared_battle_roster_snapshot_from_session_players() -> Array:
	var out: Array = []
	_append_payload_party_unit_snapshot(out, local_player_payload, "coop_party_avatar_snapshot")
	_append_payload_party_unit_snapshot(out, local_player_payload, "coop_party_companion_snapshot")
	_append_payload_party_unit_snapshot(out, remote_player_payload, "coop_party_avatar_snapshot")
	_append_payload_party_unit_snapshot(out, remote_player_payload, "coop_party_companion_snapshot")
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
		"mock_detachment_assignment": _build_mock_coop_detachment_assignment_from_session_players(),
		"battle_roster_snapshot": _build_mock_coop_shared_battle_roster_snapshot_from_session_players(),
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


func _online_transport_after_host_create(room_code: String) -> Dictionary:
	clear_session()
	session_id = "online:%s" % str(room_code).strip_edges().to_upper()
	phase = Phase.HOST
	refresh_local_player_payload_from_campaign()
	session_state_changed.emit()
	return {"ok": true, "session_id": session_id}


func _online_transport_after_guest_join(room_code: String) -> Dictionary:
	clear_session()
	session_id = "online:%s" % str(room_code).strip_edges().to_upper()
	phase = Phase.GUEST
	refresh_local_player_payload_from_campaign()
	session_state_changed.emit()
	return {"ok": true, "session_id": session_id}


func _steam_transport_begin_host_pending() -> void:
	clear_session()
	session_id = "steam:pending"
	phase = Phase.HOST
	refresh_local_player_payload_from_campaign()
	session_state_changed.emit()


func _steam_transport_host_lobby_ready(lobby_id: int) -> void:
	if not uses_steam_coop_transport():
		return
	if phase != Phase.HOST:
		return
	session_id = str(lobby_id)
	session_state_changed.emit()


func _steam_transport_begin_guest_pending() -> void:
	clear_session()
	session_id = "steam:pending"
	phase = Phase.GUEST
	refresh_local_player_payload_from_campaign()
	session_state_changed.emit()


func _steam_transport_lobby_failed(_reason: String) -> void:
	if _transport is SteamLobbyCoopTransport:
		leave_session()
	ensure_loopback_coop_transport_if_absent()


func _enet_host_on_client_joined(_peer_id: int) -> void:
	_runtime_coop_reconnect_grace_deadline_msec = 0
	_runtime_coop_host_solo_after_dropout = false
	notify_runtime_coop_battle_reconnect_grace_cancelled()
	enet_send_runtime_full_battle_resync_to_guest()
	session_state_changed.emit()
	_enet_broadcast_session_snapshot()

func _enet_host_on_client_disconnected(_peer_id: int) -> void:
	notify_runtime_coop_battle_transport_peer_lost()
	var bf_dc: Node = _enet_battle_sync_battlefield
	var in_battle: bool = bf_dc != null and is_instance_valid(bf_dc)
	var start_grace: bool = in_battle and phase == Phase.HOST
	if start_grace:
		_runtime_coop_host_solo_after_dropout = false
		_runtime_coop_reconnect_grace_deadline_msec = Time.get_ticks_msec() + int(RUNTIME_COOP_RECONNECT_GRACE_SEC * 1000.0)
		notify_runtime_coop_battle_reconnect_grace_started(RUNTIME_COOP_RECONNECT_GRACE_SEC)
	else:
		_runtime_coop_reconnect_grace_deadline_msec = 0
	if not start_grace:
		remote_player_payload = {}
		remote_ready = false
	release_enet_host_launch_pipeline()
	_enet_host_finalize_busy = false
	session_state_changed.emit()

func _enet_guest_on_transport_connected() -> void:
	_runtime_coop_reconnect_grace_deadline_msec = 0
	_runtime_coop_host_solo_after_dropout = false
	notify_runtime_coop_battle_reconnect_grace_cancelled()
	refresh_local_player_payload_from_campaign()
	_enet_guest_push_participant()

func _enet_guest_on_transport_disconnected() -> void:
	notify_runtime_coop_battle_transport_peer_lost()
	var bf_g: Node = _enet_battle_sync_battlefield
	var in_battle_g: bool = bf_g != null and is_instance_valid(bf_g)
	var start_grace_g: bool = in_battle_g and phase == Phase.GUEST
	if start_grace_g:
		_runtime_coop_host_solo_after_dropout = false
		_runtime_coop_reconnect_grace_deadline_msec = Time.get_ticks_msec() + int(RUNTIME_COOP_RECONNECT_GRACE_SEC * 1000.0)
		notify_runtime_coop_battle_reconnect_grace_started(RUNTIME_COOP_RECONNECT_GRACE_SEC)
	else:
		_runtime_coop_reconnect_grace_deadline_msec = 0
	if not start_grace_g:
		remote_player_payload = {}
		remote_ready = false
	_enet_guest_finalize_pending = false
	_enet_guest_launch_apply_locked = false
	session_state_changed.emit()


func _online_transport_on_room_linked() -> void:
	if phase == Phase.HOST:
		refresh_local_player_payload_from_campaign()
		_enet_broadcast_session_snapshot()
		session_state_changed.emit()
		return
	if phase != Phase.GUEST:
		session_state_changed.emit()
		return
	refresh_local_player_payload_from_campaign()
	if selected_expedition_map_id.strip_edges() != "":
		send_transport_message("selected_map_intent", {"map_id": selected_expedition_map_id})
	_enet_guest_push_participant()
	session_state_changed.emit()

func _enet_host_confirm_map_from_transport(map_id: String) -> Dictionary:
	var key: String = str(map_id).strip_edges()
	if key == "":
		return {"ok": false, "error": "bad_map_id"}
	if not set_selected_expedition_map(key):
		return {"ok": false, "error": "local_ineligible"}
	return {"ok": true, "session_id": session_id}

func _enet_guest_push_participant() -> void:
	if not uses_network_coop_staging_transport() or phase != Phase.GUEST:
		return
	if not is_runtime_coop_session_wired():
		return
	refresh_local_player_payload_from_campaign()
	_transport.send_session_payload("guest_staging_join", local_player_payload.duplicate(true))

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
	if not uses_network_coop_staging_transport() or phase != Phase.HOST:
		return
	if not is_runtime_coop_session_wired():
		return
	broadcast_transport_message("session_snapshot", _enet_build_session_snapshot())

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

func _transport_receive_coop_message(from_peer_id: int, kind: String, body: Dictionary) -> void:
	if not uses_network_coop_staging_transport():
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


func _enet_receive_coop_message(from_peer_id: int, kind: String, body: Dictionary) -> void:
	_transport_receive_coop_message(from_peer_id, kind, body)

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
	if not is_runtime_coop_session_wired():
		return
	if _enet_host_finalize_busy:
		broadcast_transport_message("finalize_result", {
			"ok": false,
			"errors": ["host_finalize_busy"],
			"finalize": {"ok": false, "errors": ["host_finalize_busy"], "payload": {}},
		})
		return
	if not try_begin_enet_host_launch_pipeline():
		broadcast_transport_message("finalize_result", {
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
		broadcast_transport_message("finalize_result", {"ok": false, "finalize": fin})
		return
	var hand_res: Dictionary = CoopExpeditionBattleHandoff.prepare_from_finalize_result(fin)
	if not bool(hand_res.get("ok", false)):
		release_enet_host_launch_pipeline()
		_enet_host_finalize_busy = false
		broadcast_transport_message("finalize_result", {
			"ok": false,
			"finalize": fin,
			"errors": hand_res.get("errors", []),
		})
		return
	var hh: Variant = hand_res.get("handoff", {})
	if typeof(hh) != TYPE_DICTIONARY:
		release_enet_host_launch_pipeline()
		_enet_host_finalize_busy = false
		broadcast_transport_message("finalize_result", {"ok": false, "finalize": fin, "errors": ["handoff_missing"]})
		return
	var hh_d: Dictionary = hh as Dictionary
	## Slim wire payload: full finalize + launch_snapshot often exceeds ENet reliable packet size — guest then never receives OK.
	var wire_handoff: Dictionary = _coop_handoff_clone_without_launch_snapshot_for_enet(hh_d)
	var sent_ok: bool = broadcast_transport_message("finalize_result", {"ok": true, "handoff": wire_handoff})
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
	var t: SceneTreeTimer = tree.create_timer(runtime_launch_flush_delay_seconds(), true, true, true)
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
	ensure_loopback_coop_transport_if_absent()
	var ids: Array[String] = []
	for x in owned_map_ids:
		var s: String = str(x).strip_edges()
		if s != "":
			ids.append(s)
	var guest_payload: Dictionary = _build_coop_player_payload_from_campaign(
			"loopback_guest",
			"Loopback Guest",
			partner_ready,
			"guest",
			ids,
			get_local_selected_companion_unit_id()
	)
	var tr_loop: CoopSessionTransport = get_transport()
	if tr_loop == null:
		return {"ok": false, "error": "no_transport"}
	tr_loop.send_session_payload("guest_staging_join", guest_payload)
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
	var host_payload: Dictionary = _build_coop_player_payload_from_campaign(
			"loopback_host",
			"Loopback Host",
			host_ready,
			"host",
			ids,
			get_local_selected_companion_unit_id()
	)
	var tr: CoopSessionTransport = get_transport()
	if tr == null:
		return {"ok": false, "error": "no_transport"}
	tr.send_session_payload("host_staging_join", host_payload)
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
	remote_player_payload = _build_coop_player_payload_from_campaign(
			"mock_remote",
			"Mock Co-op Partner",
			true,
			"guest",
			[key],
			get_local_selected_companion_unit_id()
	)
	remote_ready = true
	local_ready = true
	local_player_payload["ready"] = true
	session_state_changed.emit()
	return {"ok": true, "launchable": is_session_launchable(), "payload": build_expedition_coop_launch_payload()}
