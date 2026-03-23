extends Node

## Central co-op expedition session state (host/guest, readiness, selected map).
## Dormant until begin_host_session / join_session / debug hooks run. Single-player flow does not use this node.

signal session_state_changed

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

func _ready() -> void:
	_transport = LocalLoopbackCoopTransport.new()
	(_transport as LocalLoopbackCoopTransport).bind_manager(self)
	clear_session()

func get_transport() -> CoopSessionTransport:
	return _transport

## Swap transport (e.g. future lobby-backed implementation). Call clear_session first if switching mid-flight.
func set_transport(transport: CoopSessionTransport) -> void:
	if transport == null:
		return
	_transport = transport
	if transport is LocalLoopbackCoopTransport:
		(transport as LocalLoopbackCoopTransport).bind_manager(self)

func clear_session() -> void:
	session_id = ""
	phase = Phase.NONE
	selected_expedition_map_id = ""
	local_player_payload = _default_local_payload()
	remote_player_payload = {}
	local_ready = false
	remote_ready = false
	session_state_changed.emit()

func leave_session() -> void:
	if _transport != null:
		_transport.leave_session()
	clear_session()

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
	return true

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
