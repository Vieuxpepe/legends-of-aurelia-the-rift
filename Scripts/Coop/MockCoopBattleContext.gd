class_name MockCoopBattleContext
extends RefCounted

## Battle-side interpretation of a consumed mock co-op handoff (no networking).
## Built only when BattleField received a non-empty handoff from CampaignManager.

var active: bool = false
## True when CoopExpeditionBattleHandoff.validate_handoff() reports no issues for this snapshot.
var context_valid: bool = false
var validation_errors: Array[String] = []

var session_id: String = ""
var expedition_map_id: String = ""
var battle_id: String = ""
var battle_scene_path: String = ""
var schema_version: int = -1
var handoff_kind: String = ""

## "host" | "guest" — derived from handoff local_is_host only.
var local_role: String = "guest"

var local_player_id: String = ""
var local_display_name: String = ""
var remote_player_id: String = ""
var remote_display_name: String = ""

## Locked at charter finalize; same schema as handoff["mock_detachment_assignment"].
var mock_detachment_assignment: Dictionary = {}
var ordered_command_unit_ids: PackedStringArray = PackedStringArray()
var local_command_unit_ids: PackedStringArray = PackedStringArray()
var partner_command_unit_ids: PackedStringArray = PackedStringArray()


## Matches BattleField locked split + legacy field-order fallback: indices [0 .. ceil(n/2)-1] → local commander.
static func mock_coop_local_command_slot_count(deployed_player_side_unit_count: int) -> int:
	var n: int = maxi(0, deployed_player_side_unit_count)
	return ceili(float(n) / 2.0)


static func from_consumed_handoff(handoff: Dictionary) -> MockCoopBattleContext:
	var ctx := MockCoopBattleContext.new()
	if handoff.is_empty():
		return ctx
	ctx.active = true
	ctx._populate_from_handoff(handoff)
	return ctx


func _populate_from_handoff(handoff: Dictionary) -> void:
	schema_version = int(handoff.get("schema_version", -1))
	handoff_kind = str(handoff.get("kind", ""))
	session_id = str(handoff.get("session_id", "")).strip_edges()
	expedition_map_id = str(handoff.get("expedition_map_id", "")).strip_edges()
	battle_id = str(handoff.get("battle_id", "")).strip_edges()
	battle_scene_path = str(handoff.get("battle_scene_path", "")).strip_edges()
	local_role = "host" if bool(handoff.get("local_is_host", false)) else "guest"

	var lp: Variant = handoff.get("local_player", {})
	if typeof(lp) == TYPE_DICTIONARY:
		var ld: Dictionary = lp as Dictionary
		local_player_id = str(ld.get("player_id", "")).strip_edges()
		local_display_name = str(ld.get("display_name", "")).strip_edges()

	var rp: Variant = handoff.get("remote_player", {})
	if typeof(rp) == TYPE_DICTIONARY:
		var rd: Dictionary = rp as Dictionary
		remote_player_id = str(rd.get("player_id", "")).strip_edges()
		remote_display_name = str(rd.get("display_name", "")).strip_edges()

	mock_detachment_assignment = {}
	ordered_command_unit_ids.clear()
	local_command_unit_ids.clear()
	partner_command_unit_ids.clear()
	var md: Variant = handoff.get("mock_detachment_assignment", {})
	if typeof(md) == TYPE_DICTIONARY:
		mock_detachment_assignment = (md as Dictionary).duplicate(true)
		_hydrate_detachment_ids_from_assignment_dict(md as Dictionary)

	validation_errors.clear()
	var val_errs: PackedStringArray = CoopExpeditionBattleHandoff.validate_handoff(handoff)
	for e in val_errs:
		validation_errors.append(str(e))
	context_valid = validation_errors.is_empty()


func _hydrate_detachment_ids_from_assignment_dict(m: Dictionary) -> void:
	ordered_command_unit_ids.clear()
	local_command_unit_ids.clear()
	partner_command_unit_ids.clear()
	var o: Variant = m.get("ordered_command_unit_ids", [])
	var l: Variant = m.get("local_command_unit_ids", [])
	var p: Variant = m.get("partner_command_unit_ids", [])
	if typeof(o) == TYPE_ARRAY:
		for x in (o as Array):
			ordered_command_unit_ids.append(str(x).strip_edges())
	if typeof(l) == TYPE_ARRAY:
		for x in (l as Array):
			local_command_unit_ids.append(str(x).strip_edges())
	if typeof(p) == TYPE_ARRAY:
		for x in (p as Array):
			partner_command_unit_ids.append(str(x).strip_edges())


func has_locked_mock_detachment_assignment() -> bool:
	return not mock_detachment_assignment.is_empty() and str(mock_detachment_assignment.get("rule", "")).strip_edges() == MockCoopDetachmentAssignment.RULE_FIRST_HALF_LOCAL_CEIL_LOCKED


func get_snapshot() -> Dictionary:
	return {
		"active": active,
		"context_valid": context_valid,
		"validation_errors": validation_errors.duplicate(),
		"session_id": session_id,
		"expedition_map_id": expedition_map_id,
		"battle_id": battle_id,
		"battle_scene_path": battle_scene_path,
		"schema_version": schema_version,
		"handoff_kind": handoff_kind,
		"local_role": local_role,
		"local_is_host": local_role == "host",
		"local_player": {"player_id": local_player_id, "display_name": local_display_name},
		"remote_player": {"player_id": remote_player_id, "display_name": remote_display_name},
		"mock_detachment_assignment": mock_detachment_assignment.duplicate(true),
		"ordered_command_unit_ids": Array(ordered_command_unit_ids),
		"local_command_unit_ids": Array(local_command_unit_ids),
		"partner_command_unit_ids": Array(partner_command_unit_ids),
	}


func get_debug_summary_line() -> String:
	if not active:
		return ""
	var loc: String = local_display_name if local_display_name != "" else local_player_id
	var rem: String = remote_display_name if remote_display_name != "" else remote_player_id
	return "map=%s session=%s role=%s local=%s remote=%s context_valid=%s" % [
		expedition_map_id, session_id, local_role, loc, rem, str(context_valid),
	]


## Player-facing expedition line for battle log (uses DB display title when available).
func get_expedition_display_title() -> String:
	if expedition_map_id.strip_edges() == "":
		return "Unknown expedition"
	var entry: Dictionary = ExpeditionMapDatabase.get_map_by_id(expedition_map_id)
	if entry.is_empty():
		return expedition_map_id
	var title: String = ExpeditionMapDatabase.build_world_map_short_title(entry).strip_edges()
	if title == "":
		return expedition_map_id
	return title


func get_local_participant_label() -> String:
	if local_display_name.strip_edges() != "":
		return local_display_name.strip_edges()
	if local_player_id.strip_edges() != "":
		return local_player_id.strip_edges()
	return "Unknown"


func get_remote_participant_label() -> String:
	if remote_display_name.strip_edges() != "":
		return remote_display_name.strip_edges()
	if remote_player_id.strip_edges() != "":
		return remote_player_id.strip_edges()
	return "Unknown"
