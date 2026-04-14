class_name SteamLobbyCoopTransport
extends CoopSessionTransport

## Friends-only Steam lobby + Steam P2P (same JSON envelope as [ENetCoopTransport]).
## Requires GodotSteam singleton [code]Steam[/code] and autoload [SteamService] with Steam running.

const P2P_CHANNEL: int = 0
const COOP_LOBBY_MAX_MEMBERS: int = 2
const HOST_VIRTUAL_PEER_ID: int = 1
const GUEST_VIRTUAL_PEER_ID: int = 2

## [url]https://partner.steamgames.com/doc/api/steam_api#EResult[/url] [code]k_EResultOK[/code] == 1
const STEAM_RESULT_OK: int = 1
## [code]EChatRoomEnterResponse::k_EChatRoomEnterResponseSuccess[/code] == 1
const CHAT_ROOM_ENTER_SUCCESS: int = 1
## [code]k_EChatMemberStateChangeEntered[/code] == 1
const CHAT_MEMBER_ENTERED: int = 1
## [url]https://godotsteam.com/tutorials/networking/[/url] — [code]P2P_SEND_RELIABLE[/code] == 2
const P2P_SEND_RELIABLE_VAL: int = 2
## [code]LOBBY_TYPE_FRIENDS_ONLY[/code] == 1
const LOBBY_TYPE_FRIENDS_ONLY_VAL: int = 1
## [code]k_EChatMemberStateChangeLeft[/code] == 2
const CHAT_MEMBER_LEFT: int = 2
const MAX_P2P_PACKET_BYTES: int = 1048576

var _manager: Node = null
var _steam: Object = null

var _is_host: bool = false
var _lobby_id: int = 0
var _local_steam_id: int = 0
var _host_steam_id: int = 0
var _guest_steam_id: int = 0
var _session_wired: bool = false
var _signals_bound: bool = false
var _last_status: String = "Steam co-op idle."


func bind_manager(manager: Node) -> void:
	_manager = manager
	_ensure_steam()
	## Signals are bound from [method create_session] / [method join_session] so a registered transport
	## that never starts a session does not consume global Steam callbacks.


func transport_mode_id() -> String:
	return "steam_friends_lobby"


func supports_staging_coop_sync() -> bool:
	return true


func supports_runtime_coop_sync() -> bool:
	return true


func recommended_runtime_launch_flush_delay_seconds() -> float:
	return 0.42


func is_host() -> bool:
	return _is_host


func is_session_wired() -> bool:
	return _session_wired and _lobby_id != 0 and (_is_host and _guest_steam_id != 0 or not _is_host and _host_steam_id != 0)


func get_status_line() -> String:
	return _last_status


func create_session() -> Dictionary:
	_reset_session_soft()
	_ensure_steam()
	if _steam == null:
		return {"ok": false, "error": "steam_singleton_missing"}
	if not _steam_ready():
		return {"ok": false, "error": "steam_not_initialized"}
	_local_steam_id = int(_call_steam_int("getSteamID", []))
	_is_host = true
	_guest_steam_id = 0
	_host_steam_id = _local_steam_id
	_session_wired = false
	_bind_signals_if_needed()
	if _manager != null and _manager.has_method("_steam_transport_begin_host_pending"):
		_manager._steam_transport_begin_host_pending()
	if not _steam.has_method("createLobby"):
		if _manager != null and _manager.has_method("_steam_transport_lobby_failed"):
			_manager._steam_transport_lobby_failed("steam_create_lobby_missing")
		return {"ok": false, "error": "steam_create_lobby_missing"}
	_steam.createLobby(LOBBY_TYPE_FRIENDS_ONLY_VAL, COOP_LOBBY_MAX_MEMBERS)
	_last_status = "Steam: creating friends-only lobby…"
	return {"ok": true, "session_id": "steam:pending"}


func join_session(session_descriptor: String) -> Dictionary:
	_reset_session_soft()
	_ensure_steam()
	if _steam == null:
		return {"ok": false, "error": "steam_singleton_missing"}
	if not _steam_ready():
		return {"ok": false, "error": "steam_not_initialized"}
	var raw: String = str(session_descriptor).strip_edges()
	if raw.to_lower().begins_with("steam:"):
		raw = raw.substr(6).strip_edges()
	var lobby_parse: int = int(raw) if raw.is_valid_int() else 0
	if lobby_parse <= 0:
		return {"ok": false, "error": "bad_steam_lobby_id"}
	_local_steam_id = int(_call_steam_int("getSteamID", []))
	_is_host = false
	_host_steam_id = 0
	_guest_steam_id = 0
	_session_wired = false
	_bind_signals_if_needed()
	if _manager != null and _manager.has_method("_steam_transport_begin_guest_pending"):
		_manager._steam_transport_begin_guest_pending()
	if not _steam.has_method("joinLobby"):
		if _manager != null and _manager.has_method("_steam_transport_lobby_failed"):
			_manager._steam_transport_lobby_failed("steam_join_lobby_missing")
		return {"ok": false, "error": "steam_join_lobby_missing"}
	_steam.joinLobby(lobby_parse)
	_last_status = "Steam: joining lobby %s…" % str(lobby_parse)
	return {"ok": true, "session_id": "steam:%s" % str(lobby_parse)}


func leave_session() -> void:
	## Unhook first so late Steam callbacks cannot touch fields mid-teardown.
	_unbind_signals()
	if _steam != null and _lobby_id != 0 and _steam.has_method("leaveLobby"):
		_steam.leaveLobby(_lobby_id)
	_reset_session_soft()
	## Detach from manager so [method poll_transport] / stray callbacks no-op after [member CoopExpeditionSessionManager.leave_session] until a new [method bind_manager].
	_manager = null


func send_session_payload(_kind: String, payload: Dictionary) -> void:
	send_transport_message("participant_update", payload)


func send_transport_message(kind: String, body: Dictionary) -> bool:
	return _send_p2p_json_to_peer(_peer_send_target(), str(kind), body)


func host_broadcast_coop_message(kind: String, body: Dictionary) -> bool:
	if not _is_host:
		return false
	return _send_p2p_json_to_peer(_guest_steam_id, str(kind), body)


func send_coop_message(kind: String, body: Dictionary) -> bool:
	return send_transport_message(kind, body)


func broadcast_transport_message(kind: String, body: Dictionary) -> bool:
	return host_broadcast_coop_message(kind, body)


func start_expedition_session(map_id: String) -> Dictionary:
	if _is_host and _manager != null and _manager.has_method("_enet_host_confirm_map_from_transport"):
		return _manager._enet_host_confirm_map_from_transport(str(map_id))
	return {"ok": false, "error": "steam_start_expedition_not_used"}


func poll_transport() -> void:
	if _steam == null or not _is_active_for_callbacks():
		return
	_poll_discover_guest_via_member_list()
	_drain_incoming_p2p()


func _peer_send_target() -> int:
	if _is_host:
		return _guest_steam_id
	return _host_steam_id


func _p2p_send_mode() -> int:
	return P2P_SEND_RELIABLE_VAL


func _send_p2p_json_to_peer(target_steam_id: int, kind: String, body: Dictionary) -> bool:
	if _steam == null or target_steam_id <= 0:
		return false
	if not is_session_wired():
		return false
	var env: Dictionary = {"kind": str(kind), "body": body}
	var json_text: String = JSON.stringify(env)
	var pkt: PackedByteArray = json_text.to_utf8_buffer()
	var send_mode: int = _p2p_send_mode()
	if not _steam.has_method("sendP2PPacket"):
		return false
	var ok: bool = bool(_steam.sendP2PPacket(target_steam_id, pkt, send_mode, P2P_CHANNEL))
	return ok


func _drain_incoming_p2p() -> void:
	if _steam == null or not _steam.has_method("getAvailableP2PPacketSize"):
		return
	var limit: int = 48
	while limit > 0:
		limit -= 1
		var sz_raw: Variant = _steam.getAvailableP2PPacketSize(P2P_CHANNEL)
		var packet_size: int = 0
		if typeof(sz_raw) == TYPE_DICTIONARY:
			packet_size = int((sz_raw as Dictionary).get("size", (sz_raw as Dictionary).get("packet_size", 0)))
		else:
			packet_size = int(sz_raw)
		if packet_size <= 0:
			break
		if packet_size > MAX_P2P_PACKET_BYTES:
			if OS.is_debug_build():
				push_warning("SteamLobbyCoopTransport: dropping oversize P2P advert (%d bytes)" % packet_size)
			break
		if not _steam.has_method("readP2PPacket"):
			break
		var read_res: Variant = _steam.readP2PPacket(packet_size, P2P_CHANNEL)
		if typeof(read_res) != TYPE_DICTIONARY:
			break
		var rd: Dictionary = read_res as Dictionary
		var remote_id: int = int(rd.get("remote_steam_id", rd.get("steam_id_remote", 0)))
		var data: PackedByteArray = rd.get("data", PackedByteArray()) as PackedByteArray
		if remote_id <= 0 or data.is_empty():
			continue
		var text: String = data.get_string_from_utf8()
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			if OS.is_debug_build():
				push_warning("SteamLobbyCoopTransport: dropped invalid JSON from steam_id=%d" % remote_id)
			continue
		var data_dict: Dictionary = parsed as Dictionary
		var msg_kind: String = str(data_dict.get("kind", ""))
		var body_v: Variant = data_dict.get("body", {})
		var body_dict: Dictionary = body_v if typeof(body_v) == TYPE_DICTIONARY else {}
		var virtual_from: int = GUEST_VIRTUAL_PEER_ID if _is_host else HOST_VIRTUAL_PEER_ID
		if _manager != null and _manager.has_method("_transport_receive_coop_message"):
			_manager._transport_receive_coop_message(virtual_from, msg_kind, body_dict)


func _poll_discover_guest_via_member_list() -> void:
	if not _is_host or _lobby_id == 0 or _guest_steam_id != 0:
		return
	if _steam == null or not _steam.has_method("getNumLobbyMembers"):
		return
	var n: int = int(_steam.getNumLobbyMembers(_lobby_id))
	if n < 2:
		return
	if not _steam.has_method("getLobbyMemberByIndex"):
		return
	for i in range(n):
		var mid: int = int(_steam.getLobbyMemberByIndex(_lobby_id, i))
		if mid > 0 and mid != _local_steam_id:
			_guest_steam_id = mid
			break
	if _guest_steam_id <= 0:
		return
	_accept_p2p_from(_guest_steam_id)
	_session_wired = true
	_last_status = "Steam: linked to guest (lobby %s)." % str(_lobby_id)
	if _manager != null and _manager.has_method("_enet_host_on_client_joined"):
		_manager._enet_host_on_client_joined(GUEST_VIRTUAL_PEER_ID)


func _reset_session_soft() -> void:
	_lobby_id = 0
	_host_steam_id = 0
	_guest_steam_id = 0
	_session_wired = false
	_is_host = false
	_last_status = "Steam co-op idle."


func _is_active_for_callbacks() -> bool:
	if _manager == null or not is_instance_valid(_manager):
		return false
	if not _manager.has_method("get_transport"):
		return false
	return _manager.get_transport() == self


func _ensure_steam() -> void:
	if _steam != null:
		return
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")


func _steam_ready() -> bool:
	return SteamService != null and SteamService.steam_initialized


func _bind_signals_if_needed() -> void:
	if _steam == null or _signals_bound:
		return
	if _steam.has_signal("lobby_created") and not _steam.lobby_created.is_connected(_on_lobby_created):
		_steam.lobby_created.connect(_on_lobby_created)
	if _steam.has_signal("lobby_joined") and not _steam.lobby_joined.is_connected(_on_lobby_joined):
		_steam.lobby_joined.connect(_on_lobby_joined)
	if _steam.has_signal("lobby_chat_update") and not _steam.lobby_chat_update.is_connected(_on_lobby_chat_update):
		_steam.lobby_chat_update.connect(_on_lobby_chat_update)
	if _steam.has_signal("p2p_session_request") and not _steam.p2p_session_request.is_connected(_on_p2p_session_request):
		_steam.p2p_session_request.connect(_on_p2p_session_request)
	if _steam.has_signal("p2p_session_connect_fail") and not _steam.p2p_session_connect_fail.is_connected(_on_p2p_session_connect_fail):
		_steam.p2p_session_connect_fail.connect(_on_p2p_session_connect_fail)
	_signals_bound = true


func _unbind_signals() -> void:
	if _steam == null or not _signals_bound:
		return
	if _steam.has_signal("lobby_created") and _steam.lobby_created.is_connected(_on_lobby_created):
		_steam.lobby_created.disconnect(_on_lobby_created)
	if _steam.has_signal("lobby_joined") and _steam.lobby_joined.is_connected(_on_lobby_joined):
		_steam.lobby_joined.disconnect(_on_lobby_joined)
	if _steam.has_signal("lobby_chat_update") and _steam.lobby_chat_update.is_connected(_on_lobby_chat_update):
		_steam.lobby_chat_update.disconnect(_on_lobby_chat_update)
	if _steam.has_signal("p2p_session_request") and _steam.p2p_session_request.is_connected(_on_p2p_session_request):
		_steam.p2p_session_request.disconnect(_on_p2p_session_request)
	if _steam.has_signal("p2p_session_connect_fail") and _steam.p2p_session_connect_fail.is_connected(_on_p2p_session_connect_fail):
		_steam.p2p_session_connect_fail.disconnect(_on_p2p_session_connect_fail)
	_signals_bound = false


func _call_steam_int(method_name: String, args: Array) -> int:
	if _steam == null or not _steam.has_method(method_name):
		return 0
	var v: Variant = _steam.callv(method_name, args)
	return int(v)


func _on_lobby_created(bind_arg: Variant, lobby_arg: Variant = null) -> void:
	if not _is_active_for_callbacks():
		return
	var create_res: int = -1
	var new_lobby: int = 0
	if typeof(bind_arg) == TYPE_DICTIONARY:
		var d: Dictionary = bind_arg as Dictionary
		create_res = int(d.get("connect", d.get("result", -99)))
		new_lobby = int(d.get("lobby", d.get("lobby_id", 0)))
	else:
		create_res = int(bind_arg)
		new_lobby = int(lobby_arg) if lobby_arg != null else 0
	## Authoritative success is a non-zero lobby id; [code]EResult[/code] should be OK (1) but bindings vary.
	if new_lobby <= 0:
		_last_status = "Steam: lobby create failed (%s)." % str(create_res)
		if _manager != null and _manager.has_method("_steam_transport_lobby_failed"):
			_manager._steam_transport_lobby_failed("lobby_create_%s" % str(create_res))
		return
	if create_res != STEAM_RESULT_OK and OS.is_debug_build():
		push_warning(
			"SteamLobbyCoopTransport: lobby_created result=%s but lobby id set — continuing (check GodotSteam RESULT enum if mismatched)."
			% str(create_res)
		)
	_lobby_id = new_lobby
	if _steam.has_method("allowP2PPacketRelay"):
		_steam.allowP2PPacketRelay(true)
	if _steam.has_method("setLobbyJoinable"):
		_steam.setLobbyJoinable(_lobby_id, true)
	if _steam.has_method("setLobbyData"):
		_steam.setLobbyData(_lobby_id, "loa_coop", "1")
	_last_status = "Steam: lobby ready — share numeric ID %s (friends-only)." % str(_lobby_id)
	if _manager != null and _manager.has_method("_steam_transport_host_lobby_ready"):
		_manager._steam_transport_host_lobby_ready(_lobby_id)


func _on_lobby_joined(a: Variant, b: Variant = null, c: Variant = null, d: Variant = null) -> void:
	if not _is_active_for_callbacks():
		return
	var joined_lobby: int = 0
	var response: int = CHAT_ROOM_ENTER_SUCCESS
	if typeof(a) == TYPE_DICTIONARY:
		var dd: Dictionary = a as Dictionary
		joined_lobby = int(dd.get("lobby_id", dd.get("lobby", 0)))
		response = int(dd.get("response", CHAT_ROOM_ENTER_SUCCESS))
	else:
		joined_lobby = int(a)
		if d != null:
			response = int(d)
	if joined_lobby <= 0:
		return
	if response != CHAT_ROOM_ENTER_SUCCESS:
		_last_status = "Steam: lobby join failed (response=%s)." % str(response)
		if not _is_host and _manager != null and _manager.has_method("_steam_transport_lobby_failed"):
			_manager._steam_transport_lobby_failed("lobby_join_%s" % str(response))
		return
	_lobby_id = joined_lobby
	if _is_host:
		_last_status = "Steam: lobby active — waiting for friend (ID %s)…" % str(_lobby_id)
		return
	if not _steam.has_method("getLobbyOwner"):
		return
	_host_steam_id = int(_steam.getLobbyOwner(_lobby_id))
	if _host_steam_id <= 0:
		return
	_accept_p2p_from(_host_steam_id)
	_session_wired = true
	_last_status = "Steam: joined lobby %s — P2P linked." % str(_lobby_id)
	if _manager != null and _manager.has_method("_enet_guest_on_transport_connected"):
		_manager._enet_guest_on_transport_connected()


func _on_lobby_chat_update(p0: Variant, p1: Variant = null, p2: Variant = null, p3: Variant = null) -> void:
	if not _is_active_for_callbacks():
		return
	var lobby_key: int = 0
	var changed_id: int = 0
	var chat_state: int = 0
	if typeof(p0) == TYPE_DICTIONARY:
		var d: Dictionary = p0 as Dictionary
		lobby_key = int(d.get("lobby_id", d.get("lobby", 0)))
		changed_id = int(d.get("changed_id", 0))
		chat_state = int(d.get("chat_state", 0))
	else:
		## Steam order is lobby → changed → making → state; if a binding ever swaps the first two IDs, recover.
		var a0: int = int(p0)
		var a1: int = int(p1) if p1 != null else 0
		if a1 == _lobby_id and a0 > 0 and a0 != _lobby_id:
			lobby_key = a1
			changed_id = a0
			chat_state = int(p3) if p3 != null else 0
		else:
			lobby_key = a0
			changed_id = a1
			chat_state = int(p3) if p3 != null else 0
	if lobby_key != _lobby_id or _lobby_id == 0:
		return
	if (chat_state & CHAT_MEMBER_ENTERED) != 0 and changed_id > 0 and changed_id != _local_steam_id:
		_accept_p2p_from(changed_id)
	if _is_host and _session_wired and _guest_steam_id > 0 and changed_id == _guest_steam_id:
		if (chat_state & CHAT_MEMBER_LEFT) != 0:
			_handle_host_guest_left_lobby()


func _handle_host_guest_left_lobby() -> void:
	if not _is_host:
		return
	_guest_steam_id = 0
	_session_wired = false
	_last_status = "Steam: guest left the lobby."
	if _manager != null and _manager.has_method("_enet_host_on_client_disconnected"):
		_manager._enet_host_on_client_disconnected(GUEST_VIRTUAL_PEER_ID)


func _on_p2p_session_request(remote_arg: Variant) -> void:
	if not _is_active_for_callbacks():
		return
	var remote_id: int = 0
	if typeof(remote_arg) == TYPE_DICTIONARY:
		remote_id = int((remote_arg as Dictionary).get("remote_steam_id", (remote_arg as Dictionary).get("steam_id", 0)))
	else:
		remote_id = int(remote_arg)
	if remote_id > 0:
		_accept_p2p_from(remote_id)


func _on_p2p_session_connect_fail(steam_id: Variant, err_code: Variant = null) -> void:
	if not _is_active_for_callbacks():
		return
	_last_status = "Steam: P2P session failed (err=%s)." % str(err_code)
	if OS.is_debug_build():
		push_warning("SteamLobbyCoopTransport: P2P session failed steam_id=%s err=%s" % [str(steam_id), str(err_code)])


func _accept_p2p_from(remote_id: int) -> void:
	if _steam == null or remote_id <= 0:
		return
	if _steam.has_method("acceptP2PSessionWithUser"):
		_steam.acceptP2PSessionWithUser(remote_id)
