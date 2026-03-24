class_name SilentWolfPlayerDataRelayBackend
extends CoopRelayDocumentBackend

const SWUtils = preload("res://addons/silent_wolf/utils/SWUtils.gd")

var _transport: Object = null
var _active_request: HTTPRequest = null
var _active_request_weakref: WeakRef = null
var _active_request_serial: int = 0


func bind_transport(transport: Object) -> void:
	_transport = transport


func backend_id() -> String:
	return "silent_wolf_player_data"


func is_request_active() -> bool:
	return _active_request != null


func reset_backend_state() -> void:
	_active_request_serial += 1
	if _active_request != null and is_instance_valid(_active_request):
		SilentWolf.free_request(_active_request_weakref, _active_request)
	_active_request = null
	_active_request_weakref = null


func fetch_document(document_name: String, tag: String) -> bool:
	if document_name.strip_edges() == "":
		return false
	if not CoopOnlineServiceConfig.ensure_silent_wolf_ready():
		request_completed.emit("get_document", tag, {
			"ok": false,
			"payload": {},
			"body": {},
			"error": "silent_wolf_unavailable",
		})
		return true
	if _active_request != null:
		return false
	var request_url: String = "https://api.silentwolf.com/get_player_data/%s/%s" % [
		str(SilentWolf.config.game_id).strip_edges(),
		document_name.uri_encode(),
	]
	return _begin_request("get_document", tag, request_url, {})


func save_document(document_name: String, payload: Dictionary, tag: String) -> bool:
	if document_name.strip_edges() == "":
		return false
	if not CoopOnlineServiceConfig.ensure_silent_wolf_ready():
		request_completed.emit("save_document", tag, {
			"ok": false,
			"payload": {},
			"body": {},
			"error": "silent_wolf_unavailable",
		})
		return true
	if _active_request != null:
		return false
	var request_payload: Dictionary = {
		"game_id": str(SilentWolf.config.game_id).strip_edges(),
		"player_name": document_name,
		"player_data": payload.duplicate(true),
		"overwrite": true,
	}
	return _begin_request("save_document", tag, "https://api.silentwolf.com/push_player_data", request_payload)


func _begin_request(operation: String, tag: String, request_url: String, payload: Dictionary) -> bool:
	var prepared: Dictionary = SilentWolf.prepare_http_request()
	var request: HTTPRequest = prepared.get("request", null) as HTTPRequest
	var weakref_request: WeakRef = prepared.get("weakref", null)
	if request == null:
		request_completed.emit(operation, tag, {
			"ok": false,
			"payload": {},
			"body": {},
			"error": "http_request_allocation_failed",
		})
		return true
	_active_request = request
	_active_request_weakref = weakref_request
	_active_request_serial += 1
	var request_serial: int = _active_request_serial
	request.request_completed.connect(
		_on_active_request_completed.bind(request_serial, operation, tag, request, weakref_request),
		CONNECT_ONE_SHOT
	)
	match operation:
		"get_document":
			_send_transport_get_request_without_auth(request, request_url)
		"save_document":
			_send_transport_post_request_without_auth(request, request_url, payload)
		_:
			request_completed.emit(operation, tag, {
				"ok": false,
				"payload": {},
				"body": {},
				"error": "unsupported_relay_operation",
			})
			return true
	return true


func _send_transport_get_request_without_auth(http_node: HTTPRequest, request_url: String) -> void:
	var token_state: Dictionary = _suspend_silent_wolf_auth_headers()
	SilentWolf.send_get_request(http_node, request_url)
	_restore_silent_wolf_auth_headers(token_state)


func _send_transport_post_request_without_auth(http_node: HTTPRequest, request_url: String, payload: Dictionary) -> void:
	var token_state: Dictionary = _suspend_silent_wolf_auth_headers()
	SilentWolf.send_post_request(http_node, request_url, payload)
	_restore_silent_wolf_auth_headers(token_state)


func _suspend_silent_wolf_auth_headers() -> Dictionary:
	var out: Dictionary = {"auth_node": null, "id_token": null, "access_token": null}
	if SilentWolf == null:
		return out
	var auth_node: Variant = SilentWolf.get("Auth")
	if auth_node == null:
		return out
	out["auth_node"] = auth_node
	out["id_token"] = auth_node.get("sw_id_token")
	out["access_token"] = auth_node.get("sw_access_token")
	auth_node.set("sw_id_token", null)
	auth_node.set("sw_access_token", null)
	return out


func _restore_silent_wolf_auth_headers(token_state: Dictionary) -> void:
	var auth_node: Variant = token_state.get("auth_node", null)
	if auth_node == null:
		return
	auth_node.set("sw_id_token", token_state.get("id_token", null))
	auth_node.set("sw_access_token", token_state.get("access_token", null))


func _on_active_request_completed(
	_result: int,
	response_code: int,
	headers: PackedStringArray,
	body: PackedByteArray,
	request_serial: int,
	operation: String,
	tag: String,
	request: HTTPRequest,
	weakref_request: WeakRef
) -> void:
	if request != null and is_instance_valid(request):
		SilentWolf.free_request(weakref_request, request)
	if request_serial != _active_request_serial:
		return
	_active_request = null
	_active_request_weakref = null
	request_completed.emit(operation, tag, _parse_silent_wolf_response(response_code, headers, body))


func _parse_silent_wolf_response(response_code: int, headers: PackedStringArray, body: PackedByteArray) -> Dictionary:
	var ok_http: bool = SWUtils.check_http_response(response_code, headers, body)
	if not ok_http:
		return {"ok": false, "error": "http_unavailable", "payload": {}, "body": {}}
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "json_invalid", "payload": {}, "body": {}}
	var json_body: Dictionary = parsed as Dictionary
	if bool(json_body.get("success", false)):
		var player_data: Variant = json_body.get("player_data", {})
		if player_data is Dictionary:
			return {"ok": true, "payload": (player_data as Dictionary).duplicate(true), "body": json_body}
		return {"ok": true, "payload": {}, "body": json_body}
	var error_text: String = str(json_body.get("error", "silentwolf_error")).strip_edges()
	if error_text == "":
		error_text = "silentwolf_error"
	return {"ok": false, "error": error_text, "payload": {}, "body": json_body}
