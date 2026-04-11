# Debug-only checks for rune resolution (Pass 6) + Viking glyph display helpers.
# Run from shell: godot --headless -s res://Scripts/Debug/run_rune_smithing_debug.gd
# Or call: RuneSmithingDebugTest.run_all()
class_name RuneSmithingDebugTest
extends RefCounted

## Set false to no-op (e.g. while bisecting unrelated issues).
const ENABLED: bool = true


## If [param force] is true, runs even in release builds (for headless CI / -s script).
static func run_all(force: bool = false) -> bool:
	if not ENABLED:
		return true
	if not force and not OS.is_debug_build():
		return true
	var ok: bool = true
	ok = _run_resolver_cases() and ok
	ok = _run_display_helper_cases() and ok
	if ok:
		print_rich("[color=green][RuneSmithingDebugTest] OK — resolver + display helpers[/color]")
	else:
		push_error("[RuneSmithingDebugTest] FAILED (see errors above)")
	return ok


static func _rt(sockets: Array, dup: bool = false) -> Dictionary:
	return {
		"valid_weapon": true,
		"sockets": sockets,
		"validation_warnings": [],
		"duplicate_ids_present": dup,
	}


static func _expect_flat(got: Dictionary, want: Dictionary, label: String) -> bool:
	var fm: Dictionary = got.get("flat_modifiers", {}) as Dictionary
	for k in want.keys():
		if int(fm.get(k, -99999)) != int(want[k]):
			push_error(
				"[RuneSmithingDebugTest] %s: flat[%s] want %d got %d"
				% [label, k, int(want[k]), int(fm.get(k, -1))]
			)
			return false
	return true


static func _run_resolver_cases() -> bool:
	var ok: bool = true
	# Single families
	var r1: Dictionary = WeaponRuneAppliedEffectsResolver.resolve_from_runtime_summary(
		_rt([{"id": "ember_rune", "rank": 0}])
	)
	ok = _expect_flat(r1, {"might": 1, "hit": 0, "defense": 0, "resistance": 0}, "ember") and ok
	if int(r1.get("recognized_rune_count", 0)) != 1 or int(r1.get("unknown_rune_count", -1)) != 0:
		ok = false
		push_error("[RuneSmithingDebugTest] ember counts wrong")

	var r2: Dictionary = WeaponRuneAppliedEffectsResolver.resolve_from_runtime_summary(
		_rt([{"id": "swift_rune", "rank": 0}])
	)
	ok = _expect_flat(r2, {"might": 0, "hit": 1, "defense": 0, "resistance": 0}, "swift") and ok

	var r3: Dictionary = WeaponRuneAppliedEffectsResolver.resolve_from_runtime_summary(
		_rt([{"id": "flux_rune", "rank": 1}])
	)
	# mult = 1 + min(1,10) = 2 → might 2, hit 2
	ok = _expect_flat(r3, {"might": 2, "hit": 2, "defense": 0, "resistance": 0}, "flux r1") and ok

	var r4: Dictionary = WeaponRuneAppliedEffectsResolver.resolve_from_runtime_summary(
		_rt([{"id": "ward_rune", "rank": 0}])
	)
	ok = _expect_flat(r4, {"might": 0, "hit": 0, "defense": 1, "resistance": 1}, "ward") and ok

	# Stack ember + swift
	var r5: Dictionary = WeaponRuneAppliedEffectsResolver.resolve_from_runtime_summary(
		_rt([{"id": "ember_rune", "rank": 0}, {"id": "swift_rune", "rank": 0}])
	)
	ok = _expect_flat(r5, {"might": 1, "hit": 1, "defense": 0, "resistance": 0}, "ember+swift") and ok

	# Unknown id → no flats from that row
	var r6: Dictionary = WeaponRuneAppliedEffectsResolver.resolve_from_runtime_summary(
		_rt([{"id": "totally_unknown_rune_xyz", "rank": 0}])
	)
	if int(r6.get("unknown_rune_count", -1)) != 1:
		ok = false
		push_error("[RuneSmithingDebugTest] unknown id count wrong")
	ok = _expect_flat(r6, {"might": 0, "hit": 0, "defense": 0, "resistance": 0}, "unknown flat") and ok

	# Invalid weapon → zero flats
	var r7: Dictionary = WeaponRuneAppliedEffectsResolver.resolve_from_runtime_summary(
		{"valid_weapon": false, "sockets": [{"id": "ember_rune", "rank": 0}], "validation_warnings": []}
	)
	ok = _expect_flat(r7, {"might": 0, "hit": 0, "defense": 0, "resistance": 0}, "invalid weapon") and ok

	return ok


static func _run_display_helper_cases() -> bool:
	var ok: bool = true
	if WeaponRuneDisplayHelpers.BLACKSMITH_POP_GLYPH.is_empty():
		ok = false
		push_error("[RuneSmithingDebugTest] POP glyph empty")
	for id_key: String in ["ember_rune", "swift_rune", "ward_rune", "flux_rune"]:
		var g: String = WeaponRuneDisplayHelpers.viking_rune_glyph_for_key(id_key)
		if g.length() != 1:
			ok = false
			push_error("[RuneSmithingDebugTest] glyph for %s expected 1 char, got %s" % [id_key, g])

	var sample: Dictionary = {"rune_slot_count": 2, "socketed_runes": [{"id": "ember_rune", "rank": 0}]}
	var bb: String = WeaponRuneDisplayHelpers.format_runes_bbcode_for_item_variant(sample)
	if not bb.contains("Ember"):
		ok = false
		push_error("[RuneSmithingDebugTest] format_runes_bbcode missing Ember label")
	# Glyph should appear for known ids
	if not bb.contains(WeaponRuneDisplayHelpers.viking_rune_glyph_for_key("ember_rune")):
		ok = false
		push_error("[RuneSmithingDebugTest] format_runes_bbcode missing Ember glyph")

	return ok
