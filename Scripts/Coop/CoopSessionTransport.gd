class_name CoopSessionTransport
extends RefCounted

## Backend-agnostic hook surface for future lobby / relay networking.
## LocalLoopbackCoopTransport is the default implementation for editor/testing.
## Subclasses override; base returns explicit not-implemented failures.

func create_session() -> Dictionary:
	return {"ok": false, "error": "create_session not implemented for this transport"}

func join_session(_session_descriptor: String) -> Dictionary:
	return {"ok": false, "error": "join_session not implemented for this transport"}

func leave_session() -> void:
	pass

func send_session_payload(_kind: String, _payload: Dictionary) -> void:
	pass

## Reserved for future sync of roster/ready across peers before battle load.
func start_expedition_session(_map_id: String) -> Dictionary:
	return {"ok": false, "error": "start_expedition_session not implemented for this transport"}
