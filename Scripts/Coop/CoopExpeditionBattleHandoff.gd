class_name CoopExpeditionBattleHandoff
extends RefCounted

## Mock battle-entry package derived from finalize_coop_expedition_launch(). No scene load, no network.

const SCHEMA_VERSION: int = 2
const HANDOFF_KIND: String = "coop_expedition_battle_handoff_v1"

static func prepare_from_finalize_result(finalize_result: Dictionary) -> Dictionary:
	if typeof(finalize_result) != TYPE_DICTIONARY:
		return {"ok": false, "errors": ["finalize_result_not_dictionary"], "handoff": {}, "finalize_errors": []}
	var fin_errs: Variant = finalize_result.get("errors", [])
	var fin_err_array: Array = fin_errs if typeof(fin_errs) == TYPE_ARRAY else []
	if not bool(finalize_result.get("ok", false)):
		var merged: Array[String] = ["finalize_not_ok"]
		for e in fin_err_array:
			merged.append(str(e))
		return {
			"ok": false,
			"errors": merged,
			"handoff": {},
			"finalize_errors": fin_err_array,
		}
	var lp: Variant = finalize_result.get("payload", {})
	if typeof(lp) != TYPE_DICTIONARY or (lp as Dictionary).is_empty():
		return {
			"ok": false,
			"errors": ["finalize_payload_missing_or_empty"],
			"handoff": {},
			"finalize_errors": fin_err_array,
		}
	var launch: Dictionary = lp as Dictionary
	var det: Variant = launch.get("mock_detachment_assignment", {})
	var det_d: Dictionary = {}
	if typeof(det) == TYPE_DICTIONARY:
		det_d = (det as Dictionary).duplicate(true)
	var handoff: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"kind": HANDOFF_KIND,
		"captured_at_ticks_msec": Time.get_ticks_msec(),
		"session_id": str(launch.get("session_id", "")).strip_edges(),
		"expedition_map_id": str(launch.get("expedition_map_id", "")).strip_edges(),
		"battle_scene_path": str(launch.get("battle_scene_path", "")).strip_edges(),
		"battle_id": str(launch.get("battle_id", "")).strip_edges(),
		"local_is_host": bool(launch.get("local_is_host", false)),
		"local_player": _duplicate_player_dict(launch.get("local_player", {})),
		"remote_player": _duplicate_player_dict(launch.get("remote_player", {})),
		"mock_detachment_assignment": det_d,
		"launch_snapshot": launch.duplicate(true),
	}
	var val_errs: PackedStringArray = validate_handoff(handoff)
	if not val_errs.is_empty():
		return {
			"ok": false,
			"errors": Array(val_errs),
			"handoff": handoff,
			"finalize_errors": [],
		}
	return {"ok": true, "errors": [], "handoff": handoff, "finalize_errors": []}

static func _duplicate_player_dict(v: Variant) -> Dictionary:
	if typeof(v) == TYPE_DICTIONARY:
		return (v as Dictionary).duplicate(true)
	return {}

## Returns empty if handoff is acceptable for a future co-op battle entry hook.
static func validate_handoff(handoff: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if handoff.is_empty():
		out.append("handoff_empty")
		return out
	if int(handoff.get("schema_version", -1)) != SCHEMA_VERSION:
		out.append("invalid_schema_version")
	if str(handoff.get("kind", "")) != HANDOFF_KIND:
		out.append("invalid_handoff_kind")
	var sid: String = str(handoff.get("session_id", "")).strip_edges()
	if sid == "":
		out.append("missing_session_id")
	var mid: String = str(handoff.get("expedition_map_id", "")).strip_edges()
	if mid == "":
		out.append("missing_expedition_map_id")
	elif ExpeditionMapDatabase.get_map_by_id(mid).is_empty():
		out.append("expedition_map_not_in_database")
	var bpath: String = str(handoff.get("battle_scene_path", "")).strip_edges()
	if bpath == "":
		out.append("missing_battle_scene_path")
	elif not ResourceLoader.exists(bpath):
		out.append("battle_scene_path_not_found")
	var bid: String = str(handoff.get("battle_id", "")).strip_edges()
	if bid == "":
		out.append("missing_battle_id")
	_append_player_errors(out, "local_player", handoff.get("local_player", {}))
	_append_player_errors(out, "remote_player", handoff.get("remote_player", {}))
	_append_mock_detachment_assignment_errors(out, handoff.get("mock_detachment_assignment", null))
	return out


static func _append_mock_detachment_assignment_errors(out: PackedStringArray, raw: Variant) -> void:
	if typeof(raw) != TYPE_DICTIONARY:
		out.append("mock_detachment_assignment_missing_or_invalid")
		return
	var m: Dictionary = raw as Dictionary
	if str(m.get("rule", "")).strip_edges() != MockCoopDetachmentAssignment.RULE_FIRST_HALF_LOCAL_CEIL_LOCKED:
		out.append("mock_detachment_assignment_invalid_rule")
	var o: Variant = m.get("ordered_command_unit_ids", null)
	var l: Variant = m.get("local_command_unit_ids", null)
	var p: Variant = m.get("partner_command_unit_ids", null)
	if typeof(o) != TYPE_ARRAY or typeof(l) != TYPE_ARRAY or typeof(p) != TYPE_ARRAY:
		out.append("mock_detachment_assignment_arrays_invalid")
		return
	var ord_a: Array = o as Array
	var loc_a: Array = l as Array
	var par_a: Array = p as Array
	var n: int = ord_a.size()
	var k: int = MockCoopBattleContext.mock_coop_local_command_slot_count(n)
	if loc_a.size() != k:
		out.append("mock_detachment_local_count_mismatch")
	if par_a.size() != n - k:
		out.append("mock_detachment_partner_count_mismatch")
	for i in range(n):
		var exp_bucket: Array = loc_a if i < k else par_a
		var idx2: int = i if i < k else i - k
		if idx2 < 0 or idx2 >= exp_bucket.size():
			out.append("mock_detachment_partition_index_error")
			break
		if str(exp_bucket[idx2]).strip_edges() != str(ord_a[i]).strip_edges():
			out.append("mock_detachment_ordered_partition_mismatch")
			break

static func _append_player_errors(out: PackedStringArray, label: String, player: Variant) -> void:
	if typeof(player) != TYPE_DICTIONARY:
		out.append("%s_not_dictionary" % label)
		return
	var d: Dictionary = player as Dictionary
	var pid: String = str(d.get("player_id", "")).strip_edges()
	var dn: String = str(d.get("display_name", "")).strip_edges()
	if pid == "" and dn == "":
		out.append("%s_missing_identity" % label)
	var owned: Variant = d.get("owned_expedition_map_ids", [])
	if typeof(owned) != TYPE_ARRAY:
		out.append("%s_owned_expedition_map_ids_not_array" % label)
