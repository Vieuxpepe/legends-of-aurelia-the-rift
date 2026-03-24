class_name ENetCoopTransport
extends CoopSessionTransport

## LAN/session staging transport using ENetMultiplayerPeer. Host is authoritative for session snapshot.
## Polling runs from CoopExpeditionSessionManager._process.

const DEFAULT_PORT: int = 7779

var _manager: Node = null
var _peer: ENetMultiplayerPeer = null
var _listen_port: int = DEFAULT_PORT
var _is_host: bool = false
var _host_remote_peer_id: int = 0
var _guest_initial_push_done: bool = false
var _guest_saw_connected: bool = false

func bind_manager(manager: Node) -> void:
	_manager = manager

func configure_listen_port(p: int) -> void:
	_listen_port = clampi(int(p), 1024, 65535)

func get_listen_port() -> int:
	return _listen_port

func is_host() -> bool:
	return _is_host

func transport_mode_id() -> String:
	return "direct_enet"

func supports_staging_coop_sync() -> bool:
	return true

func is_session_wired() -> bool:
	if _peer == null:
		return false
	if _is_host:
		return _host_remote_peer_id != 0
	return _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func supports_runtime_coop_sync() -> bool:
	return true

func create_session() -> Dictionary:
	_close_peer()
	_is_host = true
	_guest_initial_push_done = false
	var ep := ENetMultiplayerPeer.new()
	var err: Error = ep.create_server(_listen_port, 1)
	if err != OK:
		_is_host = false
		return {"ok": false, "error": "enet_create_server_failed_%d" % int(err)}
	_peer = ep
	if not _peer.peer_connected.is_connected(_on_server_peer_connected):
		_peer.peer_connected.connect(_on_server_peer_connected)
	if not _peer.peer_disconnected.is_connected(_on_server_peer_disconnected):
		_peer.peer_disconnected.connect(_on_server_peer_disconnected)
	if _manager != null and _manager.has_method("_enet_transport_after_host_listen"):
		return _manager._enet_transport_after_host_listen(_listen_port)
	return {"ok": true, "session_id": "127.0.0.1:%d" % _listen_port, "port": _listen_port}

func join_session(session_descriptor: String) -> Dictionary:
	_close_peer()
	_is_host = false
	_guest_initial_push_done = false
	var host: String = "127.0.0.1"
	var port: int = _listen_port
	var desc: String = str(session_descriptor).strip_edges()
	if desc.contains(":"):
		var parts: PackedStringArray = desc.split(":")
		host = str(parts[0]).strip_edges()
		if parts.size() >= 2:
			port = int(str(parts[1]).strip_edges())
	var ep := ENetMultiplayerPeer.new()
	var err: Error = ep.create_client(host, port)
	if err != OK:
		return {"ok": false, "error": "enet_create_client_failed_%d" % int(err)}
	_peer = ep
	if _manager != null and _manager.has_method("_enet_transport_begin_guest_connect"):
		return _manager._enet_transport_begin_guest_connect(host, port)
	return {"ok": true, "session_id": "%s:%d" % [host, port]}

func leave_session() -> void:
	_close_peer()

func send_session_payload(_kind: String, payload: Dictionary) -> void:
	send_coop_message("participant_update", payload)

## Structured messages (finalize, map intent, snapshots, etc.)
func send_coop_message(kind: String, body: Dictionary) -> bool:
	if _peer == null:
		return false
	var target: int = _target_peer_for_send()
	if target == 0:
		return false
	_peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	_peer.set_target_peer(target)
	var env: Dictionary = {"kind": str(kind), "body": body}
	var json_text: String = JSON.stringify(env)
	var pkt: PackedByteArray = json_text.to_utf8_buffer()
	var err: Error = _peer.put_packet(pkt)
	if err != OK:
		push_warning("ENetCoopTransport: send_coop_message put_packet failed kind=%s err=%d size=%d" % [str(kind), int(err), pkt.size()])
		return false
	## Outbound reliable packets may sit until poll(); flush so the peer instance can receive on localhost.
	_peer.poll()
	return true

func host_broadcast_coop_message(kind: String, body: Dictionary) -> bool:
	if not _is_host or _peer == null or _host_remote_peer_id == 0:
		return false
	_peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	_peer.set_target_peer(_host_remote_peer_id)
	var env: Dictionary = {"kind": str(kind), "body": body}
	var json_text: String = JSON.stringify(env)
	var pkt: PackedByteArray = json_text.to_utf8_buffer()
	var err: Error = _peer.put_packet(pkt)
	if err != OK:
		push_warning("ENetCoopTransport: put_packet failed kind=%s err=%d size=%d" % [str(kind), int(err), pkt.size()])
		return false
	_peer.poll()
	return true


func send_transport_message(kind: String, body: Dictionary) -> bool:
	return send_coop_message(kind, body)


func broadcast_transport_message(kind: String, body: Dictionary) -> bool:
	return host_broadcast_coop_message(kind, body)

func start_expedition_session(map_id: String) -> Dictionary:
	## Loopback uses this for host-driven map pick; ENet uses selected_map_intent / snapshot instead.
	if _is_host and _manager != null and _manager.has_method("_enet_host_confirm_map_from_transport"):
		return _manager._enet_host_confirm_map_from_transport(str(map_id))
	return {"ok": false, "error": "enet_start_expedition_not_used"}

func poll_and_dispatch() -> void:
	if _peer == null:
		return
	_peer.poll()
	if not _is_host:
		var st: int = _peer.get_connection_status()
		if st == MultiplayerPeer.CONNECTION_CONNECTED:
			_guest_saw_connected = true
			if not _guest_initial_push_done:
				_guest_initial_push_done = true
				if _manager != null and _manager.has_method("_enet_guest_on_transport_connected"):
					_manager._enet_guest_on_transport_connected()
		elif _guest_saw_connected and st == MultiplayerPeer.CONNECTION_DISCONNECTED:
			_guest_saw_connected = false
			_guest_initial_push_done = false
			if _manager != null and _manager.has_method("_enet_guest_on_transport_disconnected"):
				_manager._enet_guest_on_transport_disconnected()
	while _peer.get_available_packet_count() > 0:
		var from_id: int = _peer.get_packet_peer()
		var raw: PackedByteArray = _peer.get_packet()
		var text: String = raw.get_string_from_utf8()
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			if OS.is_debug_build():
				push_warning("ENetCoopTransport: dropped invalid JSON from peer=%d (len=%d)" % [from_id, text.length()])
			continue
		var data: Dictionary = parsed as Dictionary
		var kind: String = str(data.get("kind", ""))
		var body: Variant = data.get("body", {})
		var body_dict: Dictionary = body if typeof(body) == TYPE_DICTIONARY else {}
		if _manager != null:
			if _manager.has_method("_transport_receive_coop_message"):
				_manager._transport_receive_coop_message(from_id, kind, body_dict)
			elif _manager.has_method("_enet_receive_coop_message"):
				_manager._enet_receive_coop_message(from_id, kind, body_dict)


func poll_transport() -> void:
	poll_and_dispatch()

func _close_peer() -> void:
	if _peer != null:
		if _peer.peer_connected.is_connected(_on_server_peer_connected):
			_peer.peer_connected.disconnect(_on_server_peer_connected)
		if _peer.peer_disconnected.is_connected(_on_server_peer_disconnected):
			_peer.peer_disconnected.disconnect(_on_server_peer_disconnected)
		_peer.close()
	_peer = null
	_host_remote_peer_id = 0
	_is_host = false
	_guest_saw_connected = false

func _target_peer_for_send() -> int:
	if _peer == null:
		return 0
	if _is_host:
		return _host_remote_peer_id
	return 1

func _on_server_peer_connected(id: int) -> void:
	_host_remote_peer_id = int(id)
	if _manager != null and _manager.has_method("_enet_host_on_client_joined"):
		_manager._enet_host_on_client_joined(int(id))

func _on_server_peer_disconnected(id: int) -> void:
	if int(id) == _host_remote_peer_id:
		_host_remote_peer_id = 0
	if _manager != null and _manager.has_method("_enet_host_on_client_disconnected"):
		_manager._enet_host_on_client_disconnected(int(id))
