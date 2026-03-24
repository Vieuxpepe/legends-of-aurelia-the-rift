class_name LocalLoopbackCoopTransport
extends CoopSessionTransport

var _manager: Node = null

func bind_manager(manager: Node) -> void:
	_manager = manager

func create_session() -> Dictionary:
	if _manager != null and _manager.has_method("_local_transport_create_host"):
		return _manager._local_transport_create_host()
	return {"ok": false, "error": "coop_session_manager_missing"}

func join_session(session_descriptor: String) -> Dictionary:
	if _manager != null and _manager.has_method("_local_transport_join"):
		return _manager._local_transport_join(str(session_descriptor))
	return {"ok": false, "error": "coop_session_manager_missing"}

func leave_session() -> void:
	if _manager != null and _manager.has_method("_local_transport_leave"):
		_manager._local_transport_leave()

func send_session_payload(kind: String, payload: Dictionary) -> void:
	if _manager != null and _manager.has_method("_local_transport_send_payload"):
		_manager._local_transport_send_payload(str(kind), payload)

func start_expedition_session(map_id: String) -> Dictionary:
	if _manager != null and _manager.has_method("_local_transport_start_expedition"):
		return _manager._local_transport_start_expedition(str(map_id))
	return {"ok": false, "error": "coop_session_manager_missing"}


func transport_mode_id() -> String:
	return "loopback"
