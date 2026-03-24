class_name SilentWolfScoresRelayBackend
extends CoopRelayDocumentBackend

const SWUtils = preload("res://addons/silent_wolf/utils/SWUtils.gd")
const UUID = preload("res://addons/silent_wolf/utils/UUID.gd")

const RELAY_LEADERBOARD_NAME: String = "coop_relay_v1"
const DIRECTORY_DOCUMENT_NAME: String = "cor_dir_v1"
const DIRECTORY_PAIRED_SCORE_BOOST: int = 1000000000000

var _transport: Object = null
var _active_request: HTTPRequest = null
var _active_request_weakref: WeakRef = null
var _active_request_serial: int = 0
var _last_monotonic_score: int = 0
var _latest_known_score_id_by_document: Dictionary = {}
var _latest_known_score_value_by_document: Dictionary = {}


func bind_transport(transport: Object) -> void:
	_transport = transport


func backend_id() -> String:
	return "silent_wolf_scores"


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
	var request_url: String = "https://api.silentwolf.com/get_scores_by_player/%s?max=1&ldboard_name=%s&player_name=%s&period_offset=0" % [
		str(SilentWolf.config.game_id).strip_edges(),
		RELAY_LEADERBOARD_NAME.uri_encode(),
		document_name.uri_encode(),
	]
	return _begin_request("get_document", tag, document_name, request_url, {})


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
	var requested_score: int = _next_document_score_for(document_name, payload)
	var request_payload: Dictionary = {
		"score_id": UUID.generate_uuid_v4(),
		"player_name": document_name,
		"game_id": str(SilentWolf.config.game_id).strip_edges(),
		"score": requested_score,
		"ldboard_name": RELAY_LEADERBOARD_NAME,
		"metadata": payload.duplicate(true),
	}
	return _begin_request("save_document", tag, document_name, "https://api.silentwolf.com/save_score", request_payload)


func _begin_request(operation: String, tag: String, document_name: String, request_url: String, payload: Dictionary) -> bool:
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
	var requested_score: int = int(payload.get("score", 0))
	request.request_completed.connect(
		_on_active_request_completed.bind(request_serial, operation, tag, document_name, requested_score, request, weakref_request),
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
	document_name: String,
	requested_score: int,
	request: HTTPRequest,
	weakref_request: WeakRef
) -> void:
	if request != null and is_instance_valid(request):
		SilentWolf.free_request(weakref_request, request)
	if request_serial != _active_request_serial:
		return
	_active_request = null
	_active_request_weakref = null
	var parsed: Dictionary = _parse_score_response(operation, response_code, headers, body)
	if OS.is_debug_build():
		var body_text: String = body.get_string_from_utf8()
		if body_text.length() > 420:
			body_text = body_text.substr(0, 420) + "...(trimmed)"
		print("[CoopScoresRelay] op=%s tag=%s doc=%s http=%d ok=%s err=%s body=%s" % [
			operation,
			tag,
			document_name,
			response_code,
			str(bool(parsed.get("ok", false))),
			str(parsed.get("error", "")),
			body_text,
		])
	if operation == "get_document" and bool(parsed.get("ok", false)):
		var fetched_score_id: String = str(parsed.get("score_id", "")).strip_edges()
		var fetched_score_value: int = int(parsed.get("score_value", 0))
		if fetched_score_id != "":
			_latest_known_score_id_by_document[document_name] = fetched_score_id
		if fetched_score_value > 0:
			_latest_known_score_value_by_document[document_name] = fetched_score_value
	if operation == "save_document" and bool(parsed.get("ok", false)):
		var score_id: String = str(parsed.get("score_id", "")).strip_edges()
		if score_id != "":
			_latest_known_score_id_by_document[document_name] = score_id
		if requested_score > 0:
			_latest_known_score_value_by_document[document_name] = requested_score
	request_completed.emit(operation, tag, parsed)


func _parse_score_response(operation: String, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> Dictionary:
	if response_code == 429:
		return {"ok": false, "error": "rate_limited", "payload": {}, "body": {"message": "Too Many Requests"}}
	var ok_http: bool = SWUtils.check_http_response(response_code, headers, body)
	if not ok_http:
		return {"ok": false, "error": "http_unavailable", "payload": {}, "body": {}}
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "json_invalid", "payload": {}, "body": {}}
	var json_body: Dictionary = parsed as Dictionary
	if not bool(json_body.get("success", false)):
		var error_text: String = str(json_body.get("error", "silentwolf_error")).strip_edges()
		if error_text == "":
			error_text = "silentwolf_error"
		if operation == "get_document" and _is_empty_document_fetch_error(error_text, json_body):
			return {"ok": true, "payload": {}, "body": json_body, "score_id": "", "score_value": 0}
		return {"ok": false, "error": error_text, "payload": {}, "body": json_body}
	match operation:
		"get_document":
			var top_dict: Dictionary = {}
			var top_score: Variant = json_body.get("top_score", {})
			if top_score is Dictionary and not (top_score as Dictionary).is_empty():
				top_dict = top_score as Dictionary
			elif json_body.get("top_scores", null) is Array:
				var top_scores: Array = json_body.get("top_scores", [])
				if not top_scores.is_empty() and top_scores[0] is Dictionary:
					top_dict = top_scores[0] as Dictionary
			var metadata: Variant = top_dict.get("md", {})
			var payload: Dictionary = metadata if metadata is Dictionary else {}
			var score_id: String = str(top_dict.get("sid", "")).strip_edges()
			var score_value: int = int(top_dict.get("s", top_dict.get("score", 0)))
			return {"ok": true, "payload": payload.duplicate(true), "body": json_body, "score_id": score_id, "score_value": score_value}
		"save_document":
			return {"ok": true, "payload": {}, "body": json_body, "score_id": str(json_body.get("score_id", "")).strip_edges(), "score_value": int(json_body.get("score", 0))}
		_:
			return {"ok": true, "payload": {}, "body": json_body}


func _is_empty_document_fetch_error(error_text: String, json_body: Dictionary) -> bool:
	var normalized_error: String = error_text.strip_edges().to_lower()
	if normalized_error == "" or normalized_error == "player_not_found":
		return true
	if normalized_error == "silentwolf_error":
		var top_score: Variant = json_body.get("top_score", {})
		var top_scores: Variant = json_body.get("top_scores", [])
		if top_scores is Array and (top_scores as Array).is_empty():
			return true
		if not (top_score is Dictionary):
			return true
		return (top_score as Dictionary).is_empty()
	if normalized_error.contains("not found"):
		return true
	return false


func _next_document_score_for(document_name: String, payload: Dictionary = {}) -> int:
	var now_score: int = int(Time.get_unix_time_from_system() * 1000.0)
	var known_score: int = int(_latest_known_score_value_by_document.get(document_name, 0))
	var next_score: int = max(now_score, _last_monotonic_score, known_score) + 1
	if document_name == DIRECTORY_DOCUMENT_NAME and _directory_payload_has_paired_room(payload):
		next_score += DIRECTORY_PAIRED_SCORE_BOOST
	_last_monotonic_score = next_score
	return next_score


func _directory_payload_has_paired_room(payload: Dictionary) -> bool:
	if payload.is_empty():
		return false
	var blob: String = str(payload.get("blob", "")).strip_edges()
	if blob == "":
		return false
	var parsed: Variant = JSON.parse_string(blob)
	if not (parsed is Dictionary):
		return false
	var rooms: Variant = (parsed as Dictionary).get("rooms", {})
	if not (rooms is Dictionary):
		return false
	for room_any in (rooms as Dictionary).values():
		if not (room_any is Dictionary):
			continue
		var room: Dictionary = room_any as Dictionary
		if str(room.get("status", "")).strip_edges().to_lower() == "paired":
			return true
		if str(room.get("guest_actor_id", "")).strip_edges() != "":
			return true
	return false
