# Pass 6: centralized applied-effects view from [WeaponRuneRuntimeRead] summaries.
# Combat consumers gate on [member WEAPON_RUNE_APPLY_IN_COMBAT]; this resolver always
# returns a stable dict for future blacksmith/UI reuse.
#
# --- Stacking (explicit, deterministic) ---
# - Order: normalized [code]sockets[/code] array order (Pass 5 contract).
# - Duplicate ids: each row applies independently; same id in multiple rows stacks additively.
# - Unknown ids: skipped; [member unknown_rune_count] incremented; no flat contribution.
# - Invalid / non-weapon runtime ([code]valid_weapon == false[/code]): flat_modifiers all zero; no throw.
# - Rank: per-row multiplier = 1 + min(rank, RANK_SCALE_CAP) (rank clamped 0..999 at read layer).
# - Charges: not used in Pass 6 ([member apply_notes] includes [code]charges_not_applied_pass6[/code]).
#
# --- Known families (display-aligned ids) ---
# - ember / ember_rune → might (+1 base per scaled row; hit reserved at 0 for now).
# - ward / ward_rune → defense and resistance (+1 each base per scaled row); combat applies the
#   stat that matches incoming damage type (physical → defense, magic → resistance).
class_name WeaponRuneAppliedEffectsResolver
extends RefCounted

const APPLIED_VERSION: int = 1
const RANK_SCALE_CAP: int = 10

## When false, forecast and strike resolution skip rune flat modifiers (this script still resolves for UI/tools).
## Default off until runesmithing is unlocked in campaign progression; set true to roll combat runes on.
const WEAPON_RUNE_APPLY_IN_COMBAT: bool = false

const _FAMILY_EMBER: String = "ember"
const _FAMILY_WARD: String = "ward"

## Per-family base contribution at multiplier 1 (scaled per row by rank policy above).
const _FAMILY_BASE: Dictionary = {
	"ember": {"might": 1, "hit": 0, "defense": 0, "resistance": 0},
	"ward": {"might": 0, "hit": 0, "defense": 1, "resistance": 1},
}


static func is_apply_enabled() -> bool:
	return WEAPON_RUNE_APPLY_IN_COMBAT


static func resolve_from_weapon(weapon: Variant) -> Dictionary:
	return resolve_from_runtime_summary(WeaponRuneRuntimeRead.build_summary(weapon))


static func resolve_from_runtime_summary(runtime: Variant) -> Dictionary:
	var flat: Dictionary = _zero_flat()
	var notes: Array[String] = ["charges_not_applied_pass6"]

	if runtime == null or not (runtime is Dictionary):
		return _make_output({}, flat, 0, 0, ["runtime_not_dict"], notes)

	var rt: Dictionary = runtime as Dictionary
	if not bool(rt.get("valid_weapon", false)):
		var w_invalid: Array[String] = _merge_warnings(rt, ["runtime_invalid_weapon"])
		return _make_output(rt, flat, 0, 0, w_invalid, notes)

	var sockets: Array = rt.get("sockets", []) as Array
	var recognized: int = 0
	var unknown: int = 0
	var warnings: Array[String] = _merge_warnings(rt, [])

	for entry in sockets:
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry as Dictionary
		var rid: String = str(row.get("id", "")).strip_edges().to_lower().replace(" ", "_")
		var fam: String = _family_for_normalized_id(rid)
		if fam.is_empty():
			unknown += 1
			continue

		var mult: int = 1 + mini(clampi(int(row.get("rank", 0)), 0, 999), RANK_SCALE_CAP)
		var base: Dictionary = _FAMILY_BASE.get(fam, {}) as Dictionary
		flat["might"] = int(flat["might"]) + int(base.get("might", 0)) * mult
		flat["hit"] = int(flat["hit"]) + int(base.get("hit", 0)) * mult
		flat["defense"] = int(flat["defense"]) + int(base.get("defense", 0)) * mult
		flat["resistance"] = int(flat["resistance"]) + int(base.get("resistance", 0)) * mult
		recognized += 1

	if bool(rt.get("duplicate_ids_present", false)):
		warnings.append("duplicate_rune_ids_stacked_additively")

	return _make_output(rt, flat, recognized, unknown, warnings, notes)


static func _family_for_normalized_id(id_norm: String) -> String:
	if id_norm == "ember" or id_norm == "ember_rune":
		return _FAMILY_EMBER
	if id_norm == "ward" or id_norm == "ward_rune":
		return _FAMILY_WARD
	return ""


static func _zero_flat() -> Dictionary:
	return {"might": 0, "hit": 0, "defense": 0, "resistance": 0}


static func _merge_warnings(rt: Dictionary, extra: Array) -> Array[String]:
	var out: Array[String] = []
	for w in rt.get("validation_warnings", []):
		out.append(str(w))
	for e in extra:
		out.append(str(e))
	return out


static func _make_output(
	rt: Dictionary,
	flat: Dictionary,
	recognized: int,
	unknown: int,
	warnings: Array[String],
	notes: Array[String]
) -> Dictionary:
	var dup: bool = bool(rt.get("duplicate_ids_present", false)) if not rt.is_empty() else false
	return {
		"applied_version": APPLIED_VERSION,
		"recognized_rune_count": recognized,
		"unknown_rune_count": unknown,
		"duplicate_ids_present": dup,
		"flat_modifiers": flat.duplicate(true),
		"apply_warnings": warnings,
		"apply_notes": notes,
	}
