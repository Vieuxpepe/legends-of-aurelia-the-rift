# Pass 4–5: read-only normalized view + authoring/validation contract for weapon rune sockets.
# Does not mutate weapons, apply stats, save/load, or participate in combat math.
#
# --- Canonical policies (Pass 5) ---
# Socket entry shape (normalized "sockets" rows):
#   Required output keys: id (String), rank (int), charges (int).
#   Source: only "id" is required to accept a row; "rank"/"charges" optional; other keys ignored.
# Duplicate ids: ALLOWED in normalized output (stacking / future rules); duplicate_ids_present flags repeats.
# Capacity: slot_count clamped to [0, MAX_RUNE_SLOTS]. If slot_count == 0, zero sockets collected.
#   If slot_count > 0, collect at most slot_count valid rows in array order; excess valid rows counted
#   in skipped_due_to_capacity_count.
# Invalid entries: non-Dictionary, blank id → dropped (dropped_malformed_count). rank/charges coerced via int() + clamp.
# Unknown source keys: ignored; triggers per-row had_unknown_keys → validation_warnings.
# Unknown rune ids: ALLOWED through unchanged; unknown_ids_present if id not in KNOWN_AUTHORING_RUNE_IDS.
# Ordering: source array order preserved among collected rows.
class_name WeaponRuneRuntimeRead
extends RefCounted

const SUMMARY_VERSION: int = 2
const MAX_RUNE_SLOTS: int = 8
const _SOCKET_SOURCE_KEYS_ALLOWED: Dictionary = {"id": true, "rank": true, "charges": true}

## Authoring hint only: ids not in this set still pass through; unknown_ids_present is true.
const KNOWN_AUTHORING_RUNE_IDS: Dictionary = {
	"ember": true,
	"ember_rune": true,
	"ward": true,
	"ward_rune": true,
}


static func build_summary(weapon: Variant) -> Dictionary:
	if weapon == null:
		return _empty_summary("null")
	if not (weapon is WeaponData):
		return _empty_summary("not_weapon_data")
	if not is_instance_valid(weapon):
		return _empty_summary("invalid_instance")

	var w: WeaponData = weapon as WeaponData
	var slot_count: int = clampi(w.rune_slot_count, 0, MAX_RUNE_SLOTS)
	var max_collect: int = slot_count
	var sockets: Array[Dictionary] = []
	var dropped_malformed: int = 0
	var skipped_capacity: int = 0
	var any_unknown_keys: bool = false

	if w.socketed_runes is Array:
		for entry in w.socketed_runes as Array:
			var parsed: Dictionary = _parse_socket_entry(entry)
			var ok: bool = bool(parsed.get("ok", false))
			if bool(parsed.get("had_unknown_keys", false)):
				any_unknown_keys = true

			if not ok:
				dropped_malformed += 1
				continue

			var row: Dictionary = parsed["row"] as Dictionary
			if sockets.size() >= max_collect:
				skipped_capacity += 1
				continue

			sockets.append(row)

	var socket_count: int = sockets.size()
	var has_any: bool = slot_count > 0 or socket_count > 0
	var dup_present: bool = _duplicate_ids_present(sockets)
	var unk_id_present: bool = _unknown_authoring_ids_present(sockets)

	var warnings: Array[String] = []
	if any_unknown_keys:
		warnings.append("socket_entry_unknown_keys_ignored")
	if dup_present:
		warnings.append("duplicate_rune_ids_present")
	if unk_id_present:
		warnings.append("unknown_rune_ids_present")
	if skipped_capacity > 0:
		warnings.append("excess_socket_entries_not_applied")
	if dropped_malformed > 0:
		warnings.append("malformed_socket_rows_dropped")

	return {
		"summary_version": SUMMARY_VERSION,
		"valid_weapon": true,
		"reason": "",
		"slot_count": slot_count,
		"socket_count": socket_count,
		"sockets": sockets,
		"has_any_runes": has_any,
		"dropped_malformed_count": dropped_malformed,
		"skipped_due_to_capacity_count": skipped_capacity,
		"duplicate_ids_present": dup_present,
		"unknown_ids_present": unk_id_present,
		"validation_warnings": warnings,
	}


static func _empty_summary(reason: String) -> Dictionary:
	return {
		"summary_version": SUMMARY_VERSION,
		"valid_weapon": false,
		"reason": reason,
		"slot_count": 0,
		"socket_count": 0,
		"sockets": [] as Array[Dictionary],
		"has_any_runes": false,
		"dropped_malformed_count": 0,
		"skipped_due_to_capacity_count": 0,
		"duplicate_ids_present": false,
		"unknown_ids_present": false,
		"validation_warnings": [] as Array[String],
	}


static func _parse_socket_entry(entry: Variant) -> Dictionary:
	if not (entry is Dictionary):
		return {"ok": false, "drop": "non_dict", "had_unknown_keys": false, "row": {}}

	var e: Dictionary = entry as Dictionary
	var had_unknown: bool = false
	for k in e.keys():
		var ks: String = str(k)
		if not _SOCKET_SOURCE_KEYS_ALLOWED.has(ks):
			had_unknown = true

	var rid: String = str(e.get("id", "")).strip_edges()
	if rid == "":
		return {"ok": false, "drop": "blank_id", "had_unknown_keys": had_unknown, "row": {}}

	var out: Dictionary = {
		"id": rid,
		"rank": clampi(int(e.get("rank", 0)), 0, 999),
		"charges": clampi(int(e.get("charges", 0)), 0, 999999) if e.has("charges") else 0,
	}
	return {"ok": true, "drop": "", "had_unknown_keys": had_unknown, "row": out}


static func _duplicate_ids_present(sockets: Array[Dictionary]) -> bool:
	var seen: Dictionary = {}
	for row in sockets:
		var idv: String = str(row.get("id", "")).strip_edges()
		if idv == "":
			continue
		if seen.has(idv):
			return true
		seen[idv] = true
	return false


static func _unknown_authoring_ids_present(sockets: Array[Dictionary]) -> bool:
	for row in sockets:
		var idv: String = str(row.get("id", "")).strip_edges()
		if idv == "":
			continue
		var key: String = idv.to_lower().replace(" ", "_")
		if not KNOWN_AUTHORING_RUNE_IDS.has(key):
			return true
	return false
