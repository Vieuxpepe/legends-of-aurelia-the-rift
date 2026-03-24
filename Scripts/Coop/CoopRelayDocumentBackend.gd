class_name CoopRelayDocumentBackend
extends RefCounted

@warning_ignore("unused_signal")
signal request_completed(operation: String, tag: String, result: Dictionary)


func bind_transport(_transport: Object) -> void:
	pass


func backend_id() -> String:
	return "unknown"


func is_request_active() -> bool:
	return false


func reset_backend_state() -> void:
	pass


func fetch_document(_document_name: String, _tag: String) -> bool:
	return false


func save_document(_document_name: String, _payload: Dictionary, _tag: String) -> bool:
	return false
