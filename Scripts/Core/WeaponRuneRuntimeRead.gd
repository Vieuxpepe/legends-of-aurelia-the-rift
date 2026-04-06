# Pass 4: read-only normalized view of weapon rune socket primitives.
# Does not mutate weapons, apply stats, or participate in combat math.
class_name WeaponRuneRuntimeRead
extends RefCounted

const SUMMARY_VERSION: int = 1
const MAX_RUNE_SLOTS: int = 8


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

	if max_collect > 0 and w.socketed_runes is Array:
		for entry in w.socketed_runes as Array:
			if sockets.size() >= max_collect:
				break
			var row: Dictionary = _normalize_socket_entry(entry)
			if not row.is_empty():
				sockets.append(row)

	var socket_count: int = sockets.size()
	var has_any: bool = slot_count > 0 or socket_count > 0

	return {
		"summary_version": SUMMARY_VERSION,
		"valid_weapon": true,
		"reason": "",
		"slot_count": slot_count,
		"socket_count": socket_count,
		"sockets": sockets,
		"has_any_runes": has_any,
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
	}


static func _normalize_socket_entry(entry: Variant) -> Dictionary:
	if not (entry is Dictionary):
		return {}
	var e: Dictionary = entry as Dictionary
	var rid: String = str(e.get("id", "")).strip_edges()
	if rid == "":
		return {}
	var out: Dictionary = {
		"id": rid,
		"rank": clampi(int(e.get("rank", 0)), 0, 999),
	}
	if e.has("charges"):
		out["charges"] = clampi(int(e.get("charges", 0)), 0, 999999)
	else:
		out["charges"] = 0
	return out
