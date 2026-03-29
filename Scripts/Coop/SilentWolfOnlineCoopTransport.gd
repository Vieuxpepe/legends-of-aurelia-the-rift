class_name SilentWolfOnlineCoopTransport
extends CoopSessionTransport

signal room_directory_updated

const DIRECTORY_PLAYER_NAME: String = "cor_dir_v1"
const SilentWolfScoresRelayBackendType = preload("res://Scripts/Coop/SilentWolfScoresRelayBackend.gd")
const ROOM_SCHEMA_VERSION: int = 1
const MAILBOX_SCHEMA_VERSION: int = 1
const STORAGE_BLOB_KEY: String = "blob"
const ROOM_CODE_CHARS: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const ROOM_CODE_LENGTH: int = 6
const DIRECTORY_POLL_UNPAIRED_MSEC: int = 1500
const DIRECTORY_POLL_LINKED_MSEC: int = 4500
const MAILBOX_POLL_STAGING_MSEC: int = 900
const MAILBOX_POLL_RUNTIME_MSEC: int = 600
const MAX_MAILBOX_MESSAGES: int = 128
const ROOM_TTL_SECONDS: int = 7200

const HOST_VIRTUAL_PEER_ID: int = 1
const GUEST_VIRTUAL_PEER_ID: int = 2

var _manager: Node = null

var _is_host: bool = false
var _session_code: String = ""
var _local_actor_id: String = ""
var _local_display_name: String = ""
var _remote_display_name: String = ""
var _remote_actor_id: String = ""
var _session_wired: bool = false

var _status_line: String = "Online idle."
var _last_error: String = ""

var _pending_create_room: bool = false
var _pending_join_room: bool = false
var _directory_request_pending: bool = false
var _directory_request_tag: String = ""
var _mailbox_request_pending: bool = false
var _mailbox_request_tag: String = ""
var _room_directory_cache: Array[Dictionary] = []

var _local_mailbox_messages: Array = []
var _local_mailbox_dirty: bool = false
var _next_local_seq: int = 0
var _last_remote_seq: int = 0
var _mailbox_save_seq_highwater: int = -1

var _next_directory_poll_at_msec: int = 0
var _next_mailbox_poll_at_msec: int = 0

var _relay_backend: CoopRelayDocumentBackend = null


func bind_manager(manager: Node) -> void:
	_manager = manager
	_ensure_relay_backend()


func transport_mode_id() -> String:
	return "silent_wolf_online"


func supports_staging_coop_sync() -> bool:
	return true


func supports_runtime_coop_sync() -> bool:
	return true


func recommended_runtime_launch_flush_delay_seconds() -> float:
	return 1.05


func is_session_wired() -> bool:
	return _session_wired


func get_status_line() -> String:
	return _status_line


func get_last_error() -> String:
	return _last_error


func get_room_directory_listing() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for room in _room_directory_cache:
		out.append(room.duplicate(true))
	return out


func refresh_room_directory_listing() -> bool:
	if not CoopOnlineServiceConfig.ensure_silent_wolf_ready():
		_set_error("SilentWolf backend is unavailable in this build.")
		room_directory_updated.emit()
		return false
	_ensure_relay_backend()
	if _relay_backend == null or _relay_backend.is_request_active():
		return false
	_request_directory_snapshot("directory_browse")
	return true


func create_session() -> Dictionary:
	if not CoopOnlineServiceConfig.ensure_silent_wolf_ready():
		return {"ok": false, "error": "silent_wolf_unavailable"}
	_reset_state()
	_is_host = true
	_session_code = _generate_room_code()
	_local_actor_id = _generate_local_actor_id()
	_local_display_name = _resolve_local_display_name()
	_pending_create_room = true
	_status_line = "Online room %s: reserving room code..." % _session_code
	_touch_directory_poll_now()
	if _manager != null and _manager.has_method("_online_transport_after_host_create"):
		return _manager._online_transport_after_host_create(_session_code)
	return {"ok": true, "session_id": _session_code}


func join_session(session_descriptor: String) -> Dictionary:
	if not CoopOnlineServiceConfig.ensure_silent_wolf_ready():
		return {"ok": false, "error": "silent_wolf_unavailable"}
	var code: String = _normalize_room_code(session_descriptor)
	if code == "":
		return {"ok": false, "error": "bad_room_code"}
	_reset_state()
	_is_host = false
	_session_code = code
	_local_actor_id = _generate_local_actor_id()
	_local_display_name = _resolve_local_display_name()
	_pending_join_room = true
	_status_line = "Online room %s: joining..." % _session_code
	_touch_directory_poll_now()
	if _manager != null and _manager.has_method("_online_transport_after_guest_join"):
		return _manager._online_transport_after_guest_join(_session_code)
	return {"ok": true, "session_id": _session_code}


func leave_session() -> void:
	_reset_state()


func send_session_payload(_kind: String, payload: Dictionary) -> void:
	send_transport_message("participant_update", payload)


func send_transport_message(kind: String, body: Dictionary) -> bool:
	if _session_code == "":
		return false
	if kind.strip_edges() == "":
		return false
	_next_local_seq += 1
	_local_mailbox_messages.append({
		"seq": _next_local_seq,
		"kind": str(kind),
		"body": body.duplicate(true),
		"sent_at": Time.get_unix_time_from_system(),
	})
	while _local_mailbox_messages.size() > MAX_MAILBOX_MESSAGES:
		_local_mailbox_messages.pop_front()
	_local_mailbox_dirty = true
	_touch_mailbox_poll_now()
	return true


func broadcast_transport_message(kind: String, body: Dictionary) -> bool:
	if not _is_host:
		return false
	return send_transport_message(kind, body)


func poll_transport() -> void:
	if _session_code == "":
		return
	if not CoopOnlineServiceConfig.ensure_silent_wolf_ready():
		if _last_error == "":
			_set_error("SilentWolf backend is unavailable in this build.")
		return
	_ensure_relay_backend()
	if _relay_backend == null or _relay_backend.is_request_active():
		return
	var now: int = Time.get_ticks_msec()
	if _local_mailbox_dirty:
		_request_save_mailbox("save_local_mailbox")
		return
	if _session_wired and now >= _next_mailbox_poll_at_msec:
		_request_peer_mailbox("poll_peer_mailbox")
		return
	if _pending_create_room or _pending_join_room or now >= _next_directory_poll_at_msec:
		_request_directory_snapshot("directory_sync")


func _reset_state() -> void:
	_is_host = false
	_session_code = ""
	_local_actor_id = ""
	_local_display_name = ""
	_remote_display_name = ""
	_remote_actor_id = ""
	_session_wired = false
	_status_line = "Online idle."
	_last_error = ""
	_pending_create_room = false
	_pending_join_room = false
	_directory_request_pending = false
	_directory_request_tag = ""
	_mailbox_request_pending = false
	_mailbox_request_tag = ""
	_room_directory_cache.clear()
	_local_mailbox_messages.clear()
	_local_mailbox_dirty = false
	_next_local_seq = 0
	_last_remote_seq = 0
	_mailbox_save_seq_highwater = -1
	_next_directory_poll_at_msec = 0
	_next_mailbox_poll_at_msec = 0
	if _relay_backend != null:
		_relay_backend.reset_backend_state()


func _resolve_local_display_name() -> String:
	if _manager != null:
		var payload: Variant = _manager.get("local_player_payload")
		if payload is Dictionary:
			var d: Dictionary = payload as Dictionary
			var dn: String = str(d.get("display_name", "")).strip_edges()
			if dn != "":
				return dn
	var sw_name: String = CoopOnlineServiceConfig.get_logged_in_player_name()
	if sw_name != "":
		return sw_name
	return CampaignManager.get_player_display_name("Commander")


func _generate_room_code() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var out := ""
	for _i in range(ROOM_CODE_LENGTH):
		out += ROOM_CODE_CHARS[rng.randi_range(0, ROOM_CODE_CHARS.length() - 1)]
	return out


func _normalize_room_code(raw: String) -> String:
	var code: String = str(raw).strip_edges().to_upper()
	code = code.replace("-", "")
	code = code.replace(" ", "")
	return code


func _generate_local_actor_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return "%s_%08x" % [_normalize_room_code(_session_code), rng.randi()]


func _touch_directory_poll_now() -> void:
	_next_directory_poll_at_msec = 0


func _touch_mailbox_poll_now() -> void:
	_next_mailbox_poll_at_msec = 0


func _request_directory_snapshot(tag: String) -> void:
	_directory_request_pending = true
	_directory_request_tag = tag
	_ensure_relay_backend()
	if _relay_backend == null or not _relay_backend.fetch_document(DIRECTORY_PLAYER_NAME, tag):
		_directory_request_pending = false
		_directory_request_tag = ""
		_set_error("Online relay backend could not start a directory read.")


func _request_save_directory(directory_payload: Dictionary, tag: String) -> void:
	_directory_request_pending = true
	_directory_request_tag = tag
	_ensure_relay_backend()
	if _relay_backend == null or not _relay_backend.save_document(DIRECTORY_PLAYER_NAME, _wrap_storage_payload(directory_payload), tag):
		_directory_request_pending = false
		_directory_request_tag = ""
		_set_error("Online relay backend could not start a directory write.")


func _request_save_mailbox(tag: String) -> void:
	if _session_code == "":
		return
	_mailbox_request_pending = true
	_mailbox_request_tag = tag
	_mailbox_save_seq_highwater = _next_local_seq
	_ensure_relay_backend()
	if _relay_backend == null or not _relay_backend.save_document(_local_mailbox_player_name(), _wrap_storage_payload(_build_local_mailbox_payload()), tag):
		_mailbox_request_pending = false
		_mailbox_request_tag = ""
		_set_error("Online relay backend could not start a mailbox write.")


func _request_peer_mailbox(tag: String) -> void:
	if _session_code == "":
		return
	_mailbox_request_pending = true
	_mailbox_request_tag = tag
	_ensure_relay_backend()
	if _relay_backend == null or not _relay_backend.fetch_document(_remote_mailbox_player_name(), tag):
		_mailbox_request_pending = false
		_mailbox_request_tag = ""
		_set_error("Online relay backend could not start a mailbox read.")


func set_relay_backend(backend: CoopRelayDocumentBackend) -> void:
	if _relay_backend != null:
		var existing_callable := Callable(self, "_on_relay_backend_request_completed")
		if _relay_backend.request_completed.is_connected(existing_callable):
			_relay_backend.request_completed.disconnect(existing_callable)
		_relay_backend.reset_backend_state()
	_relay_backend = backend
	if _relay_backend == null:
		return
	_relay_backend.bind_transport(self)
	_relay_backend.request_completed.connect(_on_relay_backend_request_completed)


func _ensure_relay_backend() -> void:
	if _relay_backend != null:
		return
	set_relay_backend(SilentWolfScoresRelayBackendType.new())


func _on_relay_backend_request_completed(operation: String, tag: String, result: Dictionary) -> void:
	var parse: Dictionary = {
		"ok": bool(result.get("ok", false)),
		"player_data": result.get("payload", {}),
		"body": result.get("body", {}),
		"error": str(result.get("error", "")).strip_edges(),
	}
	match operation:
		"get_document":
			_handle_get_player_data_result(tag, parse)
		"save_document":
			_handle_save_player_data_result(tag, parse)
		_:
			pass


func _handle_get_player_data_result(tag: String, parse: Dictionary) -> void:
	if tag == "directory_sync":
		_directory_request_pending = false
		_directory_request_tag = ""
		_handle_directory_snapshot(parse)
	elif tag == "directory_browse":
		_directory_request_pending = false
		_directory_request_tag = ""
		_handle_directory_browse_snapshot(parse)
	elif tag == "poll_peer_mailbox":
		_mailbox_request_pending = false
		_mailbox_request_tag = ""
		_handle_peer_mailbox_snapshot(parse)


func _handle_save_player_data_result(tag: String, parse: Dictionary) -> void:
	if not bool(parse.get("ok", false)):
		if tag == "save_directory":
			_directory_request_pending = false
			_directory_request_tag = ""
		elif tag == "save_local_mailbox":
			_mailbox_request_pending = false
			_mailbox_request_tag = ""
		_set_error("Online transport save failed: %s" % str(parse.get("error", "save_failed")))
		return
	_last_error = ""
	if tag == "save_directory":
		_directory_request_pending = false
		_directory_request_tag = ""
		_pending_create_room = false
		_pending_join_room = false
		## Confirm room-pairing writes immediately; otherwise host/guest can sit for a full idle poll window
		## before they discover the room is linked and start exchanging staging payloads.
		_next_directory_poll_at_msec = 0
	elif tag == "save_local_mailbox":
		_mailbox_request_pending = false
		_mailbox_request_tag = ""
		if _next_local_seq <= _mailbox_save_seq_highwater:
			_local_mailbox_dirty = false
			_next_mailbox_poll_at_msec = 0
		else:
			_local_mailbox_dirty = true
			_next_mailbox_poll_at_msec = 0


func _handle_directory_snapshot(parse: Dictionary) -> void:
	var directory_payload: Dictionary = {}
	if bool(parse.get("ok", false)):
		_last_error = ""
		directory_payload = _coerce_directory_payload(parse.get("player_data", {}))
	else:
		var err: String = str(parse.get("error", "")).strip_edges()
		var can_bootstrap_empty_directory: bool = _pending_create_room
		if err == "rate_limited":
			_next_directory_poll_at_msec = Time.get_ticks_msec() + max(_current_directory_poll_msec(), 2500)
			return
		if err == "" or err == "player_not_found" or err.to_lower().contains("not found") or can_bootstrap_empty_directory:
			directory_payload = _coerce_directory_payload({})
		else:
			_set_error("Online directory fetch failed: %s" % err)
			_next_directory_poll_at_msec = Time.get_ticks_msec() + _current_directory_poll_msec()
			return
	_prune_stale_rooms(directory_payload)
	_cache_room_directory(directory_payload)
	if OS.is_debug_build():
		var rooms_dict: Dictionary = directory_payload.get("rooms", {}) as Dictionary
		print("[OnlineCoop] directory_sync code=%s host=%s pending_create=%s pending_join=%s wired=%s rooms=%s" % [
			_session_code,
			str(_is_host),
			str(_pending_create_room),
			str(_pending_join_room),
			str(_session_wired),
			str(rooms_dict.keys()),
		])
	var changed: bool = false
	if _pending_create_room:
		changed = _apply_local_host_create(directory_payload)
	elif _pending_join_room:
		var join_res: Dictionary = _apply_local_guest_join(directory_payload)
		if not bool(join_res.get("ok", false)):
			_set_error(str(join_res.get("error", "join_failed")))
			_next_directory_poll_at_msec = Time.get_ticks_msec() + _current_directory_poll_msec()
			return
		changed = bool(join_res.get("changed", false))
	_apply_room_state_from_directory(directory_payload)
	if changed:
		_request_save_directory(directory_payload, "save_directory")
		return
	_next_directory_poll_at_msec = Time.get_ticks_msec() + _current_directory_poll_msec()
	if _session_wired:
		_next_mailbox_poll_at_msec = 0


func _handle_directory_browse_snapshot(parse: Dictionary) -> void:
	var directory_payload: Dictionary = {}
	if bool(parse.get("ok", false)):
		_last_error = ""
		directory_payload = _coerce_directory_payload(parse.get("player_data", {}))
	else:
		var err: String = str(parse.get("error", "")).strip_edges()
		if err == "rate_limited":
			room_directory_updated.emit()
			return
		if err == "" or err == "player_not_found" or err.to_lower().contains("not found"):
			directory_payload = _coerce_directory_payload({})
		else:
			_set_error("Online room list refresh failed: %s" % err)
			room_directory_updated.emit()
			return
	_prune_stale_rooms(directory_payload)
	_cache_room_directory(directory_payload)
	if OS.is_debug_build():
		print("[OnlineCoop] directory_browse rooms=%s" % str(_room_directory_cache))
	room_directory_updated.emit()


func _handle_peer_mailbox_snapshot(parse: Dictionary) -> void:
	_next_mailbox_poll_at_msec = Time.get_ticks_msec() + _current_mailbox_poll_msec()
	if not bool(parse.get("ok", false)):
		if str(parse.get("error", "")).strip_edges() == "rate_limited":
			_next_mailbox_poll_at_msec = Time.get_ticks_msec() + max(_current_mailbox_poll_msec(), 1500)
			return
		if OS.is_debug_build():
			print("[OnlineCoop] mailbox_read code=%s host=%s ok=false err=%s" % [_session_code, str(_is_host), str(parse.get("error", ""))])
		return
	var mailbox: Dictionary = _coerce_mailbox_payload(parse.get("player_data", {}))
	var messages: Variant = mailbox.get("messages", [])
	if typeof(messages) != TYPE_ARRAY:
		return
	if OS.is_debug_build():
		print("[OnlineCoop] mailbox_read code=%s host=%s messages=%d last_remote_seq=%d" % [_session_code, str(_is_host), (messages as Array).size(), _last_remote_seq])
	for raw in messages as Array:
		if not (raw is Dictionary):
			continue
		var msg: Dictionary = raw as Dictionary
		var seq: int = int(msg.get("seq", -1))
		if seq <= _last_remote_seq:
			continue
		var kind: String = str(msg.get("kind", "")).strip_edges()
		if kind == "":
			continue
		var body: Variant = msg.get("body", {})
		var body_dict: Dictionary = body if body is Dictionary else {}
		_last_remote_seq = seq
		if _manager != null and _manager.has_method("_transport_receive_coop_message"):
			var from_peer_id: int = HOST_VIRTUAL_PEER_ID if not _is_host else GUEST_VIRTUAL_PEER_ID
			_manager._transport_receive_coop_message(from_peer_id, kind, body_dict.duplicate(true))


func _coerce_directory_payload(raw: Variant) -> Dictionary:
	var out: Dictionary = {"schema_v": ROOM_SCHEMA_VERSION, "rooms": {}}
	var unwrapped: Dictionary = _unwrap_storage_payload(raw)
	if not unwrapped.is_empty():
		var src: Dictionary = unwrapped
		var rooms_raw: Variant = src.get("rooms", {})
		if rooms_raw is Dictionary:
			out["rooms"] = (rooms_raw as Dictionary).duplicate(true)
	return out


func _coerce_mailbox_payload(raw: Variant) -> Dictionary:
	var out: Dictionary = {
		"schema_v": MAILBOX_SCHEMA_VERSION,
		"room_code": _session_code,
		"owner_role": _local_role_name(),
		"messages": [],
	}
	var unwrapped: Dictionary = _unwrap_storage_payload(raw)
	if not unwrapped.is_empty():
		var src: Dictionary = unwrapped
		if src.has("messages") and src.get("messages") is Array:
			out["messages"] = (src.get("messages") as Array).duplicate(true)
	return out


func _wrap_storage_payload(payload: Dictionary) -> Dictionary:
	return {STORAGE_BLOB_KEY: JSON.stringify(payload)}


func _unwrap_storage_payload(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var src: Dictionary = raw as Dictionary
	if src.has(STORAGE_BLOB_KEY):
		var blob: String = str(src.get(STORAGE_BLOB_KEY, ""))
		if blob.strip_edges() == "":
			return {}
		var parsed: Variant = JSON.parse_string(blob)
		if parsed is Dictionary:
			return (parsed as Dictionary).duplicate(true)
		return {}
	return src.duplicate(true)


func _prune_stale_rooms(directory_payload: Dictionary) -> void:
	var rooms: Variant = directory_payload.get("rooms", {})
	if not (rooms is Dictionary):
		return
	var rooms_dict: Dictionary = rooms as Dictionary
	var now: int = int(Time.get_unix_time_from_system())
	var stale_codes: PackedStringArray = PackedStringArray()
	for code in rooms_dict.keys():
		var room_raw: Variant = rooms_dict.get(code, {})
		if not (room_raw is Dictionary):
			stale_codes.append(str(code))
			continue
		var room: Dictionary = room_raw as Dictionary
		var updated_at: int = int(room.get("updated_at", 0))
		if updated_at > 0 and now - updated_at > ROOM_TTL_SECONDS:
			stale_codes.append(str(code))
	for code in stale_codes:
		rooms_dict.erase(code)
	directory_payload["rooms"] = rooms_dict


func _cache_room_directory(directory_payload: Dictionary) -> void:
	_room_directory_cache.clear()
	var rooms: Variant = directory_payload.get("rooms", {})
	if not (rooms is Dictionary):
		return
	var rooms_dict: Dictionary = rooms as Dictionary
	var room_codes: PackedStringArray = PackedStringArray()
	for code_any in rooms_dict.keys():
		room_codes.append(str(code_any).strip_edges().to_upper())
	room_codes.sort()
	for code in room_codes:
		var room_raw: Variant = rooms_dict.get(code, {})
		if not (room_raw is Dictionary):
			continue
		var room: Dictionary = room_raw as Dictionary
		var host_name: String = str(room.get("host_display_name", "")).strip_edges()
		var guest_name: String = str(room.get("guest_display_name", "")).strip_edges()
		var guest_actor: String = str(room.get("guest_actor_id", "")).strip_edges()
		var status: String = str(room.get("status", "")).strip_edges()
		var joinable: bool = guest_actor == ""
		_room_directory_cache.append({
			"code": code,
			"host_display_name": host_name,
			"guest_display_name": guest_name,
			"status": status,
			"joinable": joinable,
			"updated_at": int(room.get("updated_at", 0)),
		})


func _apply_local_host_create(directory_payload: Dictionary) -> bool:
	var rooms: Dictionary = (directory_payload.get("rooms", {}) as Dictionary).duplicate(true)
	var existing: Variant = rooms.get(_session_code, {})
	if existing is Dictionary and not (existing as Dictionary).is_empty():
		_session_code = _generate_room_code()
		_status_line = "Online room collision detected. Retrying with %s..." % _session_code
	var now: int = int(Time.get_unix_time_from_system())
	rooms[_session_code] = {
		"schema_v": ROOM_SCHEMA_VERSION,
		"code": _session_code,
		"status": "open",
		"host_actor_id": _local_actor_id,
		"host_display_name": _local_display_name,
		"guest_actor_id": "",
		"guest_display_name": "",
		"created_at": now,
		"updated_at": now,
	}
	directory_payload["rooms"] = rooms
	_status_line = "Online room %s is live. Share the code with your partner." % _session_code
	_emit_manager_session_state_changed()
	return true


func _apply_local_guest_join(directory_payload: Dictionary) -> Dictionary:
	var rooms: Dictionary = (directory_payload.get("rooms", {}) as Dictionary).duplicate(true)
	var room_raw: Variant = rooms.get(_session_code, {})
	if not (room_raw is Dictionary):
		return {"ok": false, "error": "online_room_not_found", "changed": false}
	var room: Dictionary = (room_raw as Dictionary).duplicate(true)
	var existing_guest: String = str(room.get("guest_actor_id", "")).strip_edges()
	if existing_guest != "" and existing_guest != _local_actor_id:
		return {"ok": false, "error": "online_room_already_full", "changed": false}
	room["guest_actor_id"] = _local_actor_id
	room["guest_display_name"] = _local_display_name
	room["status"] = "paired"
	room["updated_at"] = int(Time.get_unix_time_from_system())
	rooms[_session_code] = room
	directory_payload["rooms"] = rooms
	_status_line = "Online room %s joined. Waiting for host sync..." % _session_code
	_emit_manager_session_state_changed()
	return {"ok": true, "changed": true}


func _apply_room_state_from_directory(directory_payload: Dictionary) -> void:
	var rooms: Variant = directory_payload.get("rooms", {})
	if not (rooms is Dictionary):
		return
	var room_raw: Variant = (rooms as Dictionary).get(_session_code, {})
	if not (room_raw is Dictionary):
		_session_wired = false
		return
	var room: Dictionary = room_raw as Dictionary
	if _is_host:
		_remote_actor_id = str(room.get("guest_actor_id", "")).strip_edges()
		_remote_display_name = str(room.get("guest_display_name", "")).strip_edges()
	else:
		_remote_actor_id = str(room.get("host_actor_id", "")).strip_edges()
		_remote_display_name = str(room.get("host_display_name", "")).strip_edges()
	var prev_wired: bool = _session_wired
	_session_wired = _remote_actor_id != ""
	if OS.is_debug_build():
		print("[OnlineCoop] room_state code=%s host=%s remote_actor=%s remote_name=%s prev_wired=%s wired=%s" % [
			_session_code,
			str(_is_host),
			_remote_actor_id,
			_remote_display_name,
			str(prev_wired),
			str(_session_wired),
		])
	if _session_wired:
		if _is_host:
			_status_line = "Online room %s linked to %s. Live relay sync is active." % [_session_code, _remote_display_name if _remote_display_name != "" else "guest"]
		else:
			_status_line = "Online room %s linked to %s. Live relay sync is active." % [_session_code, _remote_display_name if _remote_display_name != "" else "host"]
	else:
		_status_line = "Online room %s is waiting for a second commander." % _session_code
	_emit_manager_session_state_changed()
	if prev_wired != _session_wired:
		_next_mailbox_poll_at_msec = 0
		if _session_wired and _manager != null and _manager.has_method("_online_transport_on_room_linked"):
			_manager._online_transport_on_room_linked()


func _build_local_mailbox_payload() -> Dictionary:
	return {
		"schema_v": MAILBOX_SCHEMA_VERSION,
		"room_code": _session_code,
		"owner_role": _local_role_name(),
		"messages": _local_mailbox_messages.duplicate(true),
		"updated_at": int(Time.get_unix_time_from_system()),
	}


func _local_role_name() -> String:
	return "host" if _is_host else "guest"


func _local_mailbox_player_name() -> String:
	return "crm_%s_%s" % [_session_code.to_lower(), "h" if _is_host else "g"]


func _remote_mailbox_player_name() -> String:
	return "crm_%s_%s" % [_session_code.to_lower(), "g" if _is_host else "h"]


func _emit_manager_session_state_changed() -> void:
	if _manager == null:
		return
	if _manager.has_signal("session_state_changed"):
		_manager.session_state_changed.emit()


func _set_error(message: String) -> void:
	_last_error = str(message).strip_edges()
	if _last_error == "":
		_last_error = "unknown_online_error"
	_status_line = "Online relay error: %s" % _last_error
	_emit_manager_session_state_changed()


func _current_directory_poll_msec() -> int:
	return DIRECTORY_POLL_LINKED_MSEC if _session_wired else DIRECTORY_POLL_UNPAIRED_MSEC


func _current_mailbox_poll_msec() -> int:
	if _manager != null and _manager.has_method("runtime_coop_battle_sync_active"):
		if bool(_manager.call("runtime_coop_battle_sync_active")):
			return MAILBOX_POLL_RUNTIME_MSEC
	return MAILBOX_POLL_STAGING_MSEC
