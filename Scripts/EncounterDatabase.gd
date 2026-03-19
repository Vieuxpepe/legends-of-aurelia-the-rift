# ==============================================================================
# Script Name: EncounterDatabase.gd
# Purpose: Stores static narrative encounters for the world map.
# Overall Goal: Centralize event data to keep campaign managers clean.
# Project Fit: Accessed globally as a static data class by the WorldMap script.
# Dependencies: None.
# AI/Code Reviewer Guidance:
#   - Entry Point: Called via EncounterDatabase.map_encounters.
#   - Core Logic Sections: Static data definition.
#   - Extension Points: Add new dictionary elements to expand the world map events.
# ==============================================================================

class_name EncounterDatabase
extends RefCounted

# --- Optional encounter metadata (backward-compatible). Omitted keys use defaults below. ---
# category: crisis | mystery | ambush | mercy | profit | omen (tone/type).
# severity: minor | major | dangerous | occult (styling/urgency).
# region_tag / chapter_tag: for future region/chapter filtering.
# risk_tags / reward_tags: optional arrays of strings for UI chips (e.g. ["gold", "party_damage"]).

const DEFAULT_CATEGORY: String = "event"
const DEFAULT_SEVERITY: String = "minor"

## Returns encounter category; defaults to DEFAULT_CATEGORY if missing. Safe for old data.
static func get_encounter_category(enc: Dictionary) -> String:
	var v = enc.get("category")
	return str(v).strip_edges().to_lower() if v != null and str(v).strip_edges() != "" else DEFAULT_CATEGORY

## Returns encounter severity; defaults to DEFAULT_SEVERITY if missing.
static func get_encounter_severity(enc: Dictionary) -> String:
	var v = enc.get("severity")
	return str(v).strip_edges().to_lower() if v != null and str(v).strip_edges() != "" else DEFAULT_SEVERITY

## Returns optional region_tag for future filtering; empty if not set.
static func get_encounter_region_tag(enc: Dictionary) -> String:
	var v = enc.get("region_tag")
	return str(v).strip_edges() if v != null else ""

## Returns optional chapter_tag for future filtering; empty if not set.
static func get_encounter_chapter_tag(enc: Dictionary) -> String:
	var v = enc.get("chapter_tag")
	return str(v).strip_edges() if v != null else ""

# --- Fame-aware encounter variants (backward-compatible). ---
# Uses CampaignManager.global_fame. States: heretic (feared/distrusted), mercenary (transactional), savior (trusted/inspiring).
# Thresholds aligned with campaign bible: heretic < 20, mercenary 20–50, savior > 50.
const FAME_STATE_HERETIC: String = "heretic"
const FAME_STATE_MERCENARY: String = "mercenary"
const FAME_STATE_SAVIOR: String = "savior"
const FAME_MERCENARY_MIN: int = 20
const FAME_SAVIOR_MIN: int = 51
const DEBUG_FAME_SELECTION: bool = false

## Resolves current fame into a symbolic state from CampaignManager.global_fame. Canon: heretic if fame < 20, mercenary if 20–50, savior if > 50.
static func get_fame_state() -> String:
	var fame: int = int(CampaignManager.global_fame)
	if fame < FAME_MERCENARY_MIN:
		return FAME_STATE_HERETIC
	if fame >= FAME_SAVIOR_MIN:
		return FAME_STATE_SAVIOR
	return FAME_STATE_MERCENARY

## Returns preferred_fame_states array; empty if not set. Encounter is preferred when current state is in this list.
static func get_encounter_preferred_fame_states(enc: Dictionary) -> Array:
	var v = enc.get("preferred_fame_states")
	if v is Array:
		return v.duplicate()
	return []

## Returns allowed_fame_states array; empty = no restriction. When non-empty, encounter only in pool when state in list.
static func get_encounter_allowed_fame_states(enc: Dictionary) -> Array:
	var v = enc.get("allowed_fame_states")
	if v is Array:
		return v.duplicate()
	return []

## Returns fame_variants dict { "heretic": { "title": "", "description": "" }, ... } or empty. Use for UI title/description override.
static func get_encounter_fame_variants(enc: Dictionary) -> Dictionary:
	var v = enc.get("fame_variants")
	if v is Dictionary:
		return v
	return {}

## Returns req_fame_state: single string or array of allowed states; empty = no restriction. Option only valid when state in list.
static func get_option_req_fame_state(opt: Dictionary) -> Array:
	var v = opt.get("req_fame_state")
	if v is Array:
		return v.duplicate()
	if v != null and str(v).strip_edges() != "":
		return [str(v).strip_edges()]
	return []

## Returns option outcome override for fame state: { "result_text", "reward_gold", "reward_fame", "penalty_hp" }. Empty if no variant.
static func get_option_fame_variant_result(opt: Dictionary, fame_state: String) -> Dictionary:
	var variants = opt.get("fame_variant_result")
	if variants == null or typeof(variants) != TYPE_DICTIONARY:
		return {}
	var state_data = variants.get(fame_state)
	if state_data == null or typeof(state_data) != TYPE_DICTIONARY:
		return {}
	return state_data

# --- Encounter flags (chained events / remembered consequences). ---
# Optional encounter-level: required_flags, blocked_flags, preferred_flags, set_flags_on_resolve, clear_flags_on_resolve.
# Optional option-level: set_flags, clear_flags, required_flags, blocked_flags, flag_variants (flag name -> outcome override).
# Mini-arcs (Setup -> Echo -> Payoff): Black Briar/Plague/Ashen Waystation; Marsh/Ferry/Weeping Marsh; Famine/Widows/Flooded Mill;
# League: Smugglers/Vermin Cellar (unlock option); Valeron: Salt Road/Charred Waystation/Purifier. Negative arc: gallows_sided_noble -> Vermin cold variant.
# Personal-arc weighting: when roster_unit_names is passed to pick_random_encounter_for_region, PersonalEncounterArcDB boosts weight for that unit's arc encounters.
const DEBUG_FLAG_SELECTION: bool = false

## Returns true if flag is set in CampaignManager.encounter_flags. Safe for missing/empty key.
static func has_encounter_flag(flag: String) -> bool:
	if flag == null or str(flag).strip_edges().is_empty():
		return false
	return CampaignManager.encounter_flags.get(str(flag).strip_edges(), false) == true

## Returns true when all flags in the array are set. Empty array = true.
static func has_all_flags(flags: Array) -> bool:
	for f in flags:
		if not has_encounter_flag(str(f).strip_edges()):
			return false
	return true

## Returns true when any flag in the array is set. Empty array = false.
static func has_any_flag(flags: Array) -> bool:
	for f in flags:
		if has_encounter_flag(str(f).strip_edges()):
			return true
	return false

## Returns encounter required_flags array; empty = no restriction. Encounter only eligible when all are set.
static func get_encounter_required_flags(enc: Dictionary) -> Array:
	var v = enc.get("required_flags")
	if v is Array:
		return v.duplicate()
	if v != null and str(v).strip_edges() != "":
		return [str(v).strip_edges()]
	return []

## Returns encounter blocked_flags array; empty = no restriction. Encounter excluded when any is set.
static func get_encounter_blocked_flags(enc: Dictionary) -> Array:
	var v = enc.get("blocked_flags")
	if v is Array:
		return v.duplicate()
	if v != null and str(v).strip_edges() != "":
		return [str(v).strip_edges()]
	return []

## Returns encounter preferred_flags array; weight boosted when any is set.
static func get_encounter_preferred_flags(enc: Dictionary) -> Array:
	var v = enc.get("preferred_flags")
	if v is Array:
		return v.duplicate()
	if v != null and str(v).strip_edges() != "":
		return [str(v).strip_edges()]
	return []

## Returns encounter set_flags_on_resolve array; applied when any option in this encounter is resolved.
static func get_encounter_set_flags_on_resolve(enc: Dictionary) -> Array:
	var v = enc.get("set_flags_on_resolve")
	if v is Array:
		return v.duplicate()
	if v != null and str(v).strip_edges() != "":
		return [str(v).strip_edges()]
	return []

## Returns encounter clear_flags_on_resolve array.
static func get_encounter_clear_flags_on_resolve(enc: Dictionary) -> Array:
	var v = enc.get("clear_flags_on_resolve")
	if v is Array:
		return v.duplicate()
	if v != null and str(v).strip_edges() != "":
		return [str(v).strip_edges()]
	return []

## Returns option set_flags array (flags to set when this option is chosen).
static func get_option_set_flags(opt: Dictionary) -> Array:
	var v = opt.get("set_flags")
	if v is Array:
		return v.duplicate()
	if v != null and str(v).strip_edges() != "":
		return [str(v).strip_edges()]
	return []

## Returns option clear_flags array.
static func get_option_clear_flags(opt: Dictionary) -> Array:
	var v = opt.get("clear_flags")
	if v is Array:
		return v.duplicate()
	if v != null and str(v).strip_edges() != "":
		return [str(v).strip_edges()]
	return []

## Returns option required_flags array; option only available when all are set.
static func get_option_required_flags(opt: Dictionary) -> Array:
	var v = opt.get("required_flags")
	if v is Array:
		return v.duplicate()
	if v != null and str(v).strip_edges() != "":
		return [str(v).strip_edges()]
	return []

## Returns option blocked_flags array; option hidden when any is set.
static func get_option_blocked_flags(opt: Dictionary) -> Array:
	var v = opt.get("blocked_flags")
	if v is Array:
		return v.duplicate()
	if v != null and str(v).strip_edges() != "":
		return [str(v).strip_edges()]
	return []

## Returns option outcome override for first matching set flag in flag_variants. Empty if none match.
static func get_option_flag_variant_result(opt: Dictionary) -> Dictionary:
	var variants = opt.get("flag_variants")
	if variants == null or typeof(variants) != TYPE_DICTIONARY:
		return {}
	for flag_name in variants.keys():
		if has_encounter_flag(str(flag_name).strip_edges()):
			var data = variants[flag_name]
			if data != null and typeof(data) == TYPE_DICTIONARY:
				return data
	return {}

## Returns option risk_tags array; empty if not set. Used for UI chips (e.g. Party Damage Risk).
static func get_option_risk_tags(opt: Dictionary) -> Array:
	var v = opt.get("risk_tags")
	if v is Array:
		return v.duplicate()
	return []

## Returns option reward_tags array; empty if not set. Used for UI chips (e.g. Possible Gold).
static func get_option_reward_tags(opt: Dictionary) -> Array:
	var v = opt.get("reward_tags")
	if v is Array:
		return v.duplicate()
	return []

## Exact-unit requirement: option is only available if this unit is in roster. Empty = no requirement.
static func get_option_req_unit(opt: Dictionary) -> String:
	var v = opt.get("req_unit_name")
	return str(v).strip_edges() if v != null else ""

## Neutral internal identity for the protagonist in encounter options. Resolved at runtime by matching roster to CampaignManager.custom_avatar; display uses avatar's chosen name. Avoids premature "Commander" title in the identity model.
const AVATAR_SENTINEL: String = "Avatar"

## Roster names that match a canonical bonus_unit_name (e.g. display_name may include quotes).
const BONUS_UNIT_ALIASES: Dictionary = {
	"Hest Sparks": ["Hest \"Sparks\""]
}

## Returns alternate roster names that should be treated as the given canonical bonus unit name.
static func get_bonus_unit_aliases(canonical_name: String) -> Array:
	var key: String = str(canonical_name).strip_edges()
	var aliases = BONUS_UNIT_ALIASES.get(key)
	return aliases if aliases is Array else []

## Lightweight staging for Avatar encounter writing. Returns a public-role stage (e.g. survivor, rising, field_lead, leader, commander) so text can stay consistent with campaign arc. No new save schema; extend later with level/fame/plot if needed.
static func get_avatar_public_role() -> String:
	return "rising"

## Returns a short phrase for the current Avatar public role, for use in encounter result text. Substitute [AVATAR_ROLE] in result_text with this at display time. Early stage: "someone the road is beginning to name", etc.
static func get_avatar_public_role_phrase() -> String:
	match get_avatar_public_role():
		"survivor": return "a survivor the road has not yet named"
		"rising": return "someone the road is beginning to name"
		"field_lead": return "the one they are starting to follow"
		_: return "someone the road is beginning to name"

## Exact-unit bonus: choice is improved or highlighted if this unit is in roster. Display-only unless extended.
static func get_option_bonus_unit(opt: Dictionary) -> String:
	var v = opt.get("bonus_unit_name")
	return str(v).strip_edges() if v != null else ""

## Preferred unit for this choice; can be used like bonus_unit_name for UI and outcome bonus.
static func get_option_preferred_unit(opt: Dictionary) -> String:
	var v = opt.get("preferred_unit_name")
	return str(v).strip_edges() if v != null else ""

## True if option defines any bonus outcome (when bonus/preferred unit is in roster, use bonus_* instead of base).
static func has_bonus_outcome(opt: Dictionary) -> bool:
	return opt.get("bonus_result_text") != null or opt.get("bonus_reward_gold") != null or opt.get("bonus_reward_fame") != null or opt.get("bonus_penalty_hp") != null or opt.get("bonus_reward_item_path") != null

## Returns effective result text: bonus_result_text if key present, else result_text. Call when bonus unit is present.
static func get_effective_result_text(opt: Dictionary, bonus_unit_present: bool) -> String:
	if bonus_unit_present and opt.get("bonus_result_text") != null:
		return str(opt.get("bonus_result_text", "")).strip_edges()
	return str(opt.get("result_text", "The event concludes.")).strip_edges()

## Returns effective reward_gold; use bonus_reward_gold when bonus unit present and key set.
static func get_effective_reward_gold(opt: Dictionary, bonus_unit_present: bool) -> int:
	if bonus_unit_present and opt.get("bonus_reward_gold") != null:
		return int(opt.get("bonus_reward_gold", 0))
	return int(opt.get("reward_gold", 0))

## Returns effective reward_fame; use bonus_reward_fame when bonus unit present and key set.
static func get_effective_reward_fame(opt: Dictionary, bonus_unit_present: bool) -> int:
	if bonus_unit_present and opt.get("bonus_reward_fame") != null:
		return int(opt.get("bonus_reward_fame", 0))
	return int(opt.get("reward_fame", 0))

## Returns effective penalty_hp; use bonus_penalty_hp when bonus unit present and key set.
static func get_effective_penalty_hp(opt: Dictionary, bonus_unit_present: bool) -> int:
	if bonus_unit_present and opt.get("bonus_penalty_hp") != null:
		return int(opt.get("bonus_penalty_hp", 0))
	return int(opt.get("penalty_hp", 0))

## Returns effective reward_item_path; use bonus_reward_item_path when bonus unit present and key set.
static func get_effective_reward_item_path(opt: Dictionary, bonus_unit_present: bool) -> String:
	if bonus_unit_present and opt.get("bonus_reward_item_path") != null:
		return str(opt.get("bonus_reward_item_path", "")).strip_edges()
	return str(opt.get("reward_item_path", "")).strip_edges()

# --- Region-weighted encounter selection (backward-compatible). ---
# Per-level primary (and optional secondary) region map. Edit to match campaign geography/chapter tone.
# Levels not in the map resolve to empty string (no region preference).
const LEVEL_REGION_MAP: Dictionary = {
	0: "frontier",
	1: "frontier",
	2: "emberwood",
	3: "valeron_road",
	4: "league_city",
	5: "docks",
	6: "famine_fields",
	7: "greyspire",
	8: "edranor_border",
	9: "mountain_pass",
	10: "valeron_arena",
	11: "festival_city",
	12: "college",
	13: "black_coast",
	14: "marsh",
	15: "order_ruins",
	16: "coalition_camp",
	17: "dawnkeep",
	18: "dark_tide",
	19: "rift",
	20: "rift",
}
## Optional secondary region per level for mixed-tone chapters (e.g. urban/coastal, coalition/summit). Omit key = no secondary.
const LEVEL_SECONDARY_REGION_MAP: Dictionary = {
	5: "league_city",
	11: "league_city",
	16: "mountain_pass",
}

const DEBUG_REGION_SELECTION: bool = false

## Returns { "primary": str, "secondary": str } for the given level/node index. Empty strings when not in map or index < 0.
static func get_regions_for_level(level_index: int) -> Dictionary:
	var out: Dictionary = { "primary": "", "secondary": "" }
	if level_index < 0:
		return out
	if LEVEL_REGION_MAP.has(level_index):
		out["primary"] = str(LEVEL_REGION_MAP[level_index]).strip_edges()
	if LEVEL_SECONDARY_REGION_MAP.has(level_index):
		out["secondary"] = str(LEVEL_SECONDARY_REGION_MAP[level_index]).strip_edges()
	return out

## Legacy single-tag resolver: returns primary region only. Prefer get_regions_for_level for new code.
static func get_region_for_level(level_index: int) -> String:
	return get_regions_for_level(level_index).get("primary", "")

## Picks one encounter, preferring primary/secondary region, preferred fame state, and personal-arc encounters when roster_unit_names is provided. allowed_fame_states can exclude. Fallback to full pool if no candidates.
## roster_unit_names: optional Array of unit_name strings; when non-empty, encounters in PersonalEncounterArcDB for those units get weight boost.
static func pick_random_encounter_for_region(primary_region: String, secondary_region: String = "", roster_unit_names: Array = []) -> Dictionary:
	var encounters: Array[Dictionary] = map_encounters
	if encounters.is_empty():
		return {}
	var fame_state: String = get_fame_state()
	var arc_preferred_ids: Array = []
	if roster_unit_names.size() > 0:
		arc_preferred_ids = PersonalEncounterArcDB.get_encounter_ids_preferred_for_roster(roster_unit_names)
	var no_preference: bool = primary_region.strip_edges().is_empty()
	if no_preference:
		# With roster data, still apply personal-arc boost via weighted draw.
		if arc_preferred_ids.is_empty():
			var idx: int = randi() % encounters.size()
			if DEBUG_REGION_SELECTION:
				print("[EncounterDB] No region; uniform random index %d" % idx)
			return encounters[idx]
		var weights_empty: Array[float] = []
		for enc in encounters:
			var w: float = 1.0
			var enc_id: String = str(enc.get("id", "")).strip_edges()
			if enc_id in arc_preferred_ids:
				w = 1.5
			weights_empty.append(w)
		var total_empty: float = 0.0
		for w in weights_empty:
			total_empty += w
		if total_empty <= 0.0:
			return encounters[randi() % encounters.size()]
		var r_empty: float = randf() * total_empty
		for i in range(weights_empty.size()):
			r_empty -= weights_empty[i]
			if r_empty <= 0.0:
				return encounters[i]
		return encounters[0]
	var primary_l: String = primary_region.to_lower()
	var secondary_l: String = secondary_region.to_lower() if secondary_region else ""
	var fame_state_l: String = fame_state.to_lower()
	var weights: Array[float] = []
	var primary_count: int = 0
	var secondary_count: int = 0
	var neutral_count: int = 0
	for enc in encounters:
		var allowed: Array = get_encounter_allowed_fame_states(enc)
		if allowed.size() > 0:
			var allowed_l: Array = []
			for s in allowed:
				allowed_l.append(str(s).to_lower())
			if fame_state_l not in allowed_l:
				weights.append(0.0)
				continue
		# Flag gating: required_flags = all must be set; blocked_flags = any set excludes encounter.
		var req_flags: Array = get_encounter_required_flags(enc)
		if req_flags.size() > 0 and not has_all_flags(req_flags):
			weights.append(0.0)
			if DEBUG_FLAG_SELECTION:
				print("[EncounterDB] id=%s excluded: missing required_flags %s" % [enc.get("id", ""), req_flags])
			continue
		var blk_flags: Array = get_encounter_blocked_flags(enc)
		if blk_flags.size() > 0 and has_any_flag(blk_flags):
			weights.append(0.0)
			if DEBUG_FLAG_SELECTION:
				print("[EncounterDB] id=%s excluded: blocked_flags %s" % [enc.get("id", ""), blk_flags])
			continue
		var tag: String = get_encounter_region_tag(enc).to_lower()
		var base_w: float = 0.0
		if tag == primary_l:
			base_w = 3.0
			primary_count += 1
		elif secondary_l != "" and tag == secondary_l:
			base_w = 1.5
			secondary_count += 1
		elif tag == "":
			base_w = 1.0
			neutral_count += 1
		else:
			base_w = 0.0
		var preferred: Array = get_encounter_preferred_fame_states(enc)
		if preferred.size() > 0:
			for s in preferred:
				if str(s).to_lower() == fame_state_l:
					base_w *= 1.5
					break
		# Preferred flags boost weight when any is set (layers with region/fame).
		var pref_flags: Array = get_encounter_preferred_flags(enc)
		if pref_flags.size() > 0 and has_any_flag(pref_flags):
			base_w *= 1.5
			if DEBUG_FLAG_SELECTION:
				print("[EncounterDB] id=%s preferred_flags match, weight boosted" % enc.get("id", ""))
		# Personal-arc boost: when roster includes a unit with this encounter in their arc, boost weight.
		if arc_preferred_ids.size() > 0:
			var enc_id: String = str(enc.get("id", "")).strip_edges()
			if enc_id in arc_preferred_ids:
				base_w *= 1.5
		weights.append(base_w)
	var total: float = 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		var idx: int = randi() % encounters.size()
		if DEBUG_REGION_SELECTION or DEBUG_FAME_SELECTION:
			print("[EncounterDB] primary=%s secondary=%s fame=%s no candidates; fallback random index %d" % [primary_region, secondary_region, fame_state, idx])
		return encounters[idx]
	var r: float = randf() * total
	for i in range(weights.size()):
		r -= weights[i]
		if r <= 0.0:
			if DEBUG_REGION_SELECTION or DEBUG_FAME_SELECTION:
				var enc_tag: String = get_encounter_region_tag(encounters[i])
				print("[EncounterDB] primary=%s secondary=%s fame=%s primary_n=%d secondary_n=%d neutral_n=%d picked id=%s tag=%s" % [primary_region, secondary_region, fame_state, primary_count, secondary_count, neutral_count, encounters[i].get("id", ""), enc_tag])
			return encounters[i]
	if DEBUG_REGION_SELECTION or DEBUG_FAME_SELECTION:
		print("[EncounterDB] primary=%s fame=%s fallback last" % [primary_region, fame_state])
	return encounters[encounters.size() - 1]

# --- Optional success/partial/fail branching (backward-compatible). ---
# Option may have "branches": { "success": { "chance": 50, "result_text": "...", ... }, "partial": { ... }, "fail": { ... } }.
# Chances are 0-100 and normalized if needed. Optional "bonus_success_chance" (default 15) on option adds to success when bonus unit present.

## True if option has branching outcome data (success/partial/fail). If false, use flat outcome as before.
static func has_branches(opt: Dictionary) -> bool:
	var b = opt.get("branches")
	if b == null or typeof(b) != TYPE_DICTIONARY:
		return false
	var branches: Dictionary = b
	return branches.get("success") != null or branches.get("partial") != null or branches.get("fail") != null

## Returns normalized branch chances { "success" => 0-100, "partial" => 0-100, "fail" => 0-100 }. When bonus_unit_present, adds bonus_success_chance to success and subtracts from fail.
static func get_branch_chances(opt: Dictionary, bonus_unit_present: bool) -> Dictionary:
	var branches: Dictionary = opt.get("branches", {})
	var s: float = float(int(branches.get("success", {}).get("chance", 0)))
	var p: float = float(int(branches.get("partial", {}).get("chance", 0)))
	var f: float = float(int(branches.get("fail", {}).get("chance", 0)))
	if bonus_unit_present:
		var bonus: int = int(opt.get("bonus_success_chance", 15))
		s = minf(100.0, s + float(bonus))
		f = maxf(0.0, f - float(bonus))
	var total: float = s + p + f
	if total <= 0.0:
		return { "success": 100, "partial": 0, "fail": 0 }
	var s_norm: int = int(round((s / total) * 100.0))
	var p_norm: int = int(round((p / total) * 100.0))
	var f_norm: int = 100 - s_norm - p_norm
	return { "success": s_norm, "partial": p_norm, "fail": maxi(0, f_norm) }

## Rolls and returns "success", "partial", or "fail" using get_branch_chances. Call only when has_branches(opt).
static func resolve_branch(opt: Dictionary, bonus_unit_present: bool) -> String:
	var chances: Dictionary = get_branch_chances(opt, bonus_unit_present)
	var roll: float = randf() * 100.0
	var s: int = int(chances.get("success", 0))
	var p: int = int(chances.get("partial", 0))
	if roll < float(s):
		return "success"
	if roll < float(s + p):
		return "partial"
	return "fail"

## Returns true if branching option has non-zero fail or partial chance (for "Risky" chip).
static func is_branch_risky(opt: Dictionary, bonus_unit_present: bool) -> bool:
	var chances: Dictionary = get_branch_chances(opt, bonus_unit_present)
	return int(chances.get("partial", 0)) > 0 or int(chances.get("fail", 0)) > 0

## Extracts outcome dict from a branch: result_text, reward_gold, reward_fame, penalty_hp, reward_item_path. Safe for missing keys.
static func get_branch_outcome(branch_data: Dictionary) -> Dictionary:
	if branch_data == null or typeof(branch_data) != TYPE_DICTIONARY:
		return {}
	return {
		"result_text": str(branch_data.get("result_text", "The event concludes.")).strip_edges(),
		"reward_gold": int(branch_data.get("reward_gold", 0)),
		"reward_fame": int(branch_data.get("reward_fame", 0)),
		"penalty_hp": int(branch_data.get("penalty_hp", 0)),
		"reward_item_path": str(branch_data.get("reward_item_path", "")).strip_edges()
	}

# ==============================================================================
# VALID CLASS LIST FOR 'req_class' CHECKS:
# (Matches the exact naming of the ClassData resources in the project)
#   - Archer
#   - Cleric
#   - Knight
#   - Mage
#   - Mercenary
#   - Monk
#   - Monster
#   - Paladin
#   - Spellblade
#   - Thief
#   - Warrior
# ==============================================================================

# Every encounter below contains at least one universal fallback option:
# "req_class": ""
# "req_item": ""
# This guarantees the player can always select something.
static var map_encounters: Array[Dictionary] = [
	{
		"id": "collapsed_bridge_crossing",
		"region_tag": "frontier",
		"title": "Collapsed Bridge Crossing",
		"description": "A stone bridge has fallen into a black, fast-moving river, leaving only broken arches and dangling ropes above the current. On the far bank, starving refugees wave frantically while pack animals scream from the spray below.",
		"category": "crisis",
		"severity": "major",
		"options": [
			{
				"text": "Rig a crossing line and haul survivors over.",
				"req_class": "Knight",
				"req_item": "Rope",
				"consume_item": true,
				"result_text": "Your party anchors the rope through shattered masonry and drags families across one by one. The work is brutal, but the survivors kneel in tears when the last child reaches safety.",
				"reward_fame": 90,
				"penalty_hp": 12,
				"bonus_unit_name": "Mira Ashdown",
				"bonus_result_text": "Mira doesn't speak. She anchors the rope and hauls with the rest. When a woman on the far bank meets her eyes, there's a nod—the kind survivors give when they recognize one of their own. No fanfare. The road remembers correctly.",
				"bonus_reward_fame": 98,
				"fame_variant_result": {
					"heretic": { "result_text": "You haul them across. They take the rope, the safety, the dry ground—but they do not thank you. They gather their children and leave without a word. The road has already taught them what to expect from your kind.", "reward_fame": 30 },
					"savior": { "result_text": "Word of your approach had run ahead. The survivors weep before you have finished the line. When the last child is across, they kneel in the mud and speak your name like a blessing. The road will carry it for miles.", "reward_fame": 100 }
				},
				"branches": {
					"success": { "chance": 45, "result_text": "The rope holds. Your party hauls every soul across before the current claims the line. The survivors kneel in tears; the road will remember this rescue.", "reward_fame": 95, "penalty_hp": 4 },
					"partial": { "chance": 40, "result_text": "You save most of them, but the line snaps near the end. Two are lost to the river. The survivors are grateful and grim.", "reward_fame": 55, "penalty_hp": 10 },
					"fail": { "chance": 15, "result_text": "The masonry gives way mid-crossing. The rope fails and the current takes more than you can count. You retreat with the few who made it and the weight of the rest.", "reward_fame": -20, "penalty_hp": 18 }
				}
			},
			{
				"text": "Cross first and secure an anchor on the far bank.",
				"req_class": "",
				"req_item": "Rope",
				"consume_item": true,
				"result_text": "Someone goes across the broken arches before the main party—finding the sturdiest point, fixing the line, then signaling the rest. The rescue runs smoother for it. The survivors remember the one who reached them first.",
				"reward_fame": 75,
				"penalty_hp": 8,
				"bonus_unit_name": "Maela Thorn",
				"bonus_result_text": "Maela doesn't wait for a vote. She's across the gap before the rope is even tied—wrong foot, right angle, the one path that still holds. She secures the line; the rest is just hauling. They remember who got there first.",
				"bonus_reward_fame": 90,
				"bonus_penalty_hp": 4
			},
			{
				"text": "Take the rope and help pull survivors across.",
				"req_class": "",
				"req_item": "Rope",
				"consume_item": true,
				"result_text": "You throw yourself into the hauling—no rank, no glory, just hands on the line until every soul who can be reached is on the near bank. The work is brutal. The survivors remember who stayed at the rope.",
				"reward_fame": 72,
				"penalty_hp": 10,
				"bonus_unit_name": "Pell Rowan",
				"bonus_result_text": "Pell volunteers before anyone asks. He's not the one who rigged the line—he's the one hauling until his arms shake. No speeches. No knightly flourish. Just the work. Courage without glamour.",
				"bonus_reward_fame": 85
			},
			{
				"text": "Hold the line at the near bank.",
				"req_class": "",
				"req_item": "Rope",
				"consume_item": true,
				"result_text": "Someone has to anchor the rope and hold position while others cross or haul. You take the post. You don't move until the last survivor is off the river. The line holds.",
				"reward_fame": 70,
				"penalty_hp": 6,
				"bonus_unit_name": "Veska Moor",
				"bonus_result_text": "Veska takes the anchor point. She doesn't run the rescue—she holds. When the current pulls and the rope screams, she doesn't move. The survivors remember the one who stood where it mattered.",
				"bonus_reward_fame": 88
			},
			{
				"text": "Search the wreckage below for valuables while the refugees wait.",
				"req_class": "Thief",
				"req_item": "",
				"result_text": "Your thief slips through the debris and retrieves coin pouches, trade seals, and a merchant's lockbox from the riverbank. The refugees watch in silence, and word spreads that you chose profit over rescue.",
				"reward_gold": 140,
				"reward_fame": -85
			},
			{
				"text": "Give the order. The survivors wait for your word before they move.",
				"req_class": "",
				"req_item": "Rope",
				"consume_item": true,
				"result_text": "Someone has to say what happens next. You say it. The line goes out, the hauling begins, and the survivors do not move until you have spoken. The weight of it stays with you long after the crossing is clear.",
				"reward_fame": 70,
				"penalty_hp": 6,
				"bonus_unit_name": "Avatar",
				"bonus_result_text": "They stop when they see you. Not the rope, not the knights—you. A woman at the front catches your eye, then your face. She stills. The rest wait. The river screams and nobody moves until you speak. You give the order. They move. The weight of it is new. They are beginning to wait for your word. You are becoming the one who decides.",
				"bonus_reward_fame": 88,
				"bonus_penalty_hp": 4
			},
			{
				"text": "Turn away before the river claims your own people too.",
				"req_class": "",
				"req_item": "",
				"result_text": "You leave the crossing behind as the cries fade into the rain. No one in your party speaks for the rest of the march.",
				"reward_fame": -40
			}
		]
	},
	{
		"id": "plague_cart_procession",
		"preferred_fame_states": ["savior"],
		"preferred_flags": ["helped_black_briar_refugees"],
		"fame_variants": {
			"heretic": { "description": "A line of plague carts creaks along the road. The handlers see your banners and pull their masks tight. No one asks for your help; they would rather risk the sickness than be seen accepting yours." },
			"savior": { "description": "A line of plague carts creaks along the road. Villagers at the roadside point at your company and call out—they have heard what you did at the last crossing. The masked handlers slow, waiting to see if you will stop." }
		},
		"title": "Plague Cart Procession",
		"description": "A line of plague carts creaks along the road, covered in waxed sheets and buzzing flies. One cart still moves from within, and the masked handlers refuse to stop unless someone intervenes.",
		"options": [
			{
				"text": "Examine the living victim and direct a safe quarantine.",
				"req_class": "Cleric",
				"req_item": "",
				"result_text": "Your cleric recognizes fever from tainted well-water rather than true plague and orders the carts separated. The saved villagers spread your name with desperate gratitude.",
				"reward_fame": 95,
				"bonus_unit_name": "Brother Alden",
				"bonus_result_text": "Alden doesn't preach. He examines the living, separates the carts, and speaks the rites so the dying can hear. The villagers lower their shoulders without knowing why. Faith as service.",
				"bonus_reward_fame": 105,
				"flag_variants": {
					"helped_black_briar_refugees": { "result_text": "Your cleric recognizes fever from tainted well-water rather than true plague and orders the carts separated. Among the saved are faces from the Black Briar camp—they weep and call you by name. Your deeds on the road have run ahead of you.", "reward_fame": 105 }
				}
			},
			{
				"text": "Sort the carts and tend whoever can still take water.",
				"req_class": "",
				"req_item": "",
				"result_text": "You separate the living from the worst of the fever, pass out what water and cloth you can spare, and direct the handlers to hold the line. It is not a cure, but the villagers remember the hands that stayed.",
				"reward_fame": 65,
				"bonus_unit_name": "Tamsin Reed",
				"bonus_result_text": "Tamsin talks through her fear until she's at the first cart—then she's all hands, sorting the living, directing who gets water, cataloguing what they'll need. By the time the procession moves on, they remember who stayed.",
				"bonus_reward_fame": 82
			},
			{
				"text": "Burn the infected carts before the sickness spreads.",
				"req_class": "Mage",
				"req_item": "Torch",
				"consume_item": true,
				"result_text": "Flame consumes the carts in moments, along with the moans from inside. The road is made safer, but witnesses remember the smoke and the screams.",
				"reward_fame": -70,
				"penalty_hp": 8
			},
			{
				"text": "Keep your distance and let the procession pass.",
				"req_class": "",
				"req_item": "",
				"result_text": "You order the party off the road and wait in grim silence as the carts roll by. You avoid entanglement, but the memory clings to the company like the smell of sickness.",
				"reward_fame": -20,
				"bonus_unit_name": "Avatar",
				"bonus_result_text": "You give the order. The party moves off the road. The handlers and the villagers watch you go—they know who you are. You did not help. They will remember that too. The road names you either way: shelter or refusal. You chose refusal. The weight of it does not leave.",
				"bonus_reward_fame": -8
			}
		]
	},
	{
		"id": "bell_tower_of_ashes",
		"region_tag": "frontier",
		"preferred_fame_states": ["savior"],
		"fame_variants": {
			"heretic": { "description": "The ruin of a chapel rises from a field of soot, its cracked bell tolling on its own. When the villagers see who approaches, they bar the path. No one here will accept a blessing from your hand—only that you leave before the bell names another dead." },
			"savior": { "description": "The ruin of a chapel rises from a field of soot, its cracked bell tolling on its own. The villagers recognize your company and part in silence. They have heard what you did on the road; they beg you to quiet the bell before it claims more." }
		},
		"title": "Bell Tower of Ashes",
		"description": "The ruin of a chapel rises from a field of soot, its cracked bell tolling on its own whenever the wind dies. Villagers claim every ring marks another body found in the nearby hamlets.",
		"options": [
			{
				"text": "Climb the tower and sanctify the bell.",
				"req_class": "Paladin",
				"req_fame_state": ["mercenary", "savior"],
				"req_item": "",
				"result_text": "Your paladin ascends through collapsing beams and drives a blessing into the bronze with bloodied hands. The tolling stops at once, and kneeling peasants begin to hope again.",
				"reward_fame": 100,
				"penalty_hp": 14,
				"bonus_unit_name": "Kaelen",
				"bonus_result_text": "Your paladin ascends; Kaelen watches from below, saying nothing. When the tolling stops, he looks at the sanctified bell the way someone looks at a thing they thought was lost. The peasants kneel in hope; he simply turns and walks back to the road.",
				"bonus_reward_fame": 105,
				"fame_variant_result": {
					"savior": { "result_text": "Your paladin ascends with the villagers' prayers at her back. The blessing takes; the tolling stops. The peasants kneel not only in hope but in recognition—they name you guardians of this stretch of the road.", "reward_fame": 110 }
				}
			},
			{
				"text": "Study the runes carved beneath the yoke.",
				"req_class": "Mage",
				"req_item": "",
				"result_text": "Your mage uncovers a ward-seal twisted into a beacon for carrion spirits and breaks its pattern with careful counter-signs. The curse lifts, but the strain leaves your party shaken.",
				"reward_fame": 80,
				"penalty_hp": 10
			},
			{
				"text": "Strip the chapel of metal and move on.",
				"req_class": "",
				"req_item": "",
				"set_flags": ["desecrated_bell_chapel"],
				"result_text": "You pry bronze, silver trim, and candle stands from the ruin while villagers watch from a distance. The bell rings one final time as you depart, and the sound follows you for miles.",
				"reward_gold": 95,
				"reward_fame": -75
			}
		]
	},
	{
		"id": "salt_road_hangings",
		"region_tag": "valeron_road",
		"fame_variants": {
			"heretic": { "description": "Along the old salt road, seven bodies hang from iron hooks. One is still alive. The local wardens watch from the shade; they have orders to treat anyone who interferes as an accomplice. Your presence here is noted." },
			"savior": { "description": "Along the old salt road, seven bodies hang from iron hooks. One is still alive. Villagers at the well have seen your banners; they whisper that if anyone can defy the lord's justice and live, it is you." }
		},
		"title": "Salt Road Hangings",
		"description": "Along the old salt road, seven bodies hang from iron hooks with signs naming them deserters. One is still alive, barely able to lift his head as crows tear at the others.",
		"options": [
			{
				"text": "Cut the survivor down and treat his wounds.",
				"req_class": "Monk",
				"req_item": "",
				"set_flags": ["salt_road_mercy"],
				"result_text": "Your monk lowers the man gently and forces water between cracked lips until he can breathe. He names the lord who ordered the hanging, and the nearby villages praise your mercy openly.",
				"reward_fame": 85,
				"penalty_hp": 6,
				"bonus_unit_name": "Liora",
				"bonus_result_text": "Liora tends the survivor with a healer's certainty and speaks the rites that let him finally rest. The villages speak not only of mercy but of grace, and her name is asked for in every chapel along the road.",
				"bonus_reward_fame": 95,
				"bonus_penalty_hp": 3
			},
			{
				"text": "Interrogate him for military intelligence before deciding.",
				"req_class": "Mercenary",
				"req_item": "",
				"result_text": "You wring supply routes and troop counts from the dying soldier before leaving him to fate. The information has value, but so does the story of how you got it.",
				"reward_gold": 80,
				"reward_fame": -60
			},
			{
				"text": "Step forward and cut the survivor down.",
				"req_class": "",
				"req_item": "",
				"set_flags": ["salt_road_mercy"],
				"result_text": "You move before the wardens can react—blade to the ropes, not to them. The survivor drops into your arms. It isn't clean. It isn't glorious. The villages will talk about who stepped up anyway.",
				"reward_fame": 70,
				"penalty_hp": 10,
				"bonus_unit_name": "Pell Rowan",
				"bonus_result_text": "Pell doesn't wait for permission. He's not ready—his hands shake—but he steps forward and cuts the man down. No speech. No flourish. Just the thing that had to be done. Courage becoming real instead of theatrical.",
				"bonus_reward_fame": 85,
				"bonus_penalty_hp": 6
			},
			{
				"text": "Leave the road in silence and spare yourself the choice.",
				"req_class": "",
				"req_item": "",
				"result_text": "You lower your eyes and march on while the crows continue their work behind you. The company reaches the next mile marker faster, but not lighter.",
				"reward_fame": -25
			}
		]
	},
	{
		"id": "flooded_mill_ruins",
		"preferred_flags": ["salt_road_mercy", "helped_famine_wagon"],
		"fame_variants": {
			"heretic": { "description": "A grain mill has burst into a swamp of splintered wheels and drowned sacks. The farmers see your company and fall silent. They need help, but they have heard what you are. They will not ask—they will only watch the water and wait for you to pass." },
			"savior": { "description": "A grain mill has burst apart into a swamp of splintered wheels and drowned sacks. The farmers have heard your name. They press forward despite the thing moving beneath the water—they beg you to clear the blockage before the next flood takes the harvest." }
		},
		"title": "Flooded Mill Ruins",
		"description": "A grain mill has burst apart into a swamp of splintered wheels and drowned sacks, poisoning the fields downstream. Farmers plead for help while something large moves beneath the brown water.",
		"options": [
			{
				"text": "Wade in and clear the blockage by force.",
				"req_class": "Warrior",
				"req_item": "",
				"result_text": "Your warrior hacks apart jammed beams and drags rotten timber free while hidden debris tears at armor and skin. The water begins to run clear again, and the farmers swear they will remember the cost.",
				"reward_fame": 75,
				"penalty_hp": 18,
				"bonus_unit_name": "Veska Moor",
				"bonus_result_text": "Veska doesn't give speeches. She takes the position that holds the worst of the weight—where the current could take someone—and doesn't move. The rest clear the blockage. The farmers remember the one who stood where others would have broken.",
				"bonus_reward_fame": 90,
				"bonus_penalty_hp": 12,
				"flag_variants": {
					"helped_famine_wagon": { "result_text": "Your warrior hacks apart jammed beams and drags rotten timber free. The farmers have heard about the wagon at dusk—who shared food when they had none. They wade in beside you with whatever tools they have. The water runs clear again; they name you guardians of this stretch. Survival has a long memory.", "reward_fame": 95 },
					"salt_road_mercy": { "result_text": "Your warrior hacks apart jammed beams and drags rotten timber free. The farmers have heard what you did on the salt road—they wade in beside you with whatever tools they have. The water runs clear again, and they name you guardians of this stretch.", "reward_fame": 90 }
				}
			},
			{
				"text": "Scout the submerged storehouse for salvage.",
				"req_class": "Thief",
				"req_item": "",
				"result_text": "Your thief slips through a shattered side door and emerges with sealed tax coin and dry promissory notes. The mill stays ruined, and the villages below remain angry.",
				"reward_gold": 135,
				"reward_fame": -80
			},
			{
				"text": "Mark the area as dangerous and move on.",
				"req_class": "",
				"req_item": "",
				"result_text": "You warn the farmers away from the deepest water and continue the march without intervening further. It is cautious, but it leaves the land wounded.",
				"reward_fame": -15
			}
		]
	},
	{
		"id": "black_briar_refugee_camp",
		"region_tag": "coalition_camp",
		"preferred_fame_states": ["savior"],
		"fame_variants": {
			"heretic": { "description": "A camp of displaced families huddles behind wagons bound with black thorns. At the sight of your company, they draw their children close. The tax collectors smirk; they know the refugees would rather take the lord's terms than your coin." },
			"savior": { "description": "A camp of displaced families huddles behind wagons bound with black thorns. Word has already reached them—they recognize your company and press forward with desperate hope. The tax collectors hesitate, weighing the mood." }
		},
		"title": "Black Briar Refugee Camp",
		"description": "A camp of displaced families huddles behind wagons bound with black thorns to keep raiders away. Their food stores are nearly empty, and a local lord's tax collectors wait nearby like vultures.",
		"options": [
			{
				"text": "Drive off the tax collectors and leave your own coin behind.",
				"req_class": "Paladin",
				"req_item": "",
				"set_flags": ["helped_black_briar_refugees"],
				"result_text": "Your paladin shames the collectors in front of the camp and forces them to withdraw under threat of steel. The refugees weep over the coin you leave in their cook pots and speak your name like a prayer.",
				"reward_gold": -80,
				"reward_fame": 100,
				"bonus_unit_name": "Branik",
				"bonus_result_text": "Branik doesn't make speeches. He steps between the collectors and the camp and stands there. When they move, he doesn't flinch. When the coin goes into the cook pots, he's already helping shift the heaviest sacks. The refugees remember the man who made survival possible.",
				"bonus_reward_fame": 110,
				"fame_variant_result": {
					"heretic": { "result_text": "Your paladin drives off the collectors, but when you offer coin the refugees refuse to take it. They accept your protection from the lord's men and nothing more. Your name is not spoken here.", "reward_gold": -40, "reward_fame": 20 },
					"savior": { "result_text": "The refugees surge forward before your paladin has finished. The collectors flee. The camp takes your coin with tears and oaths; by nightfall your name is being sung around their fires.", "reward_gold": -80, "reward_fame": 115 }
				}
			},
			{
				"text": "Sell protection to the camp for the week.",
				"req_class": "Mercenary",
				"req_item": "",
				"result_text": "You post guards, ration watchfires, and keep the collectors from entering as long as payment holds. The camp survives, but everyone understands your help had a price.",
				"reward_gold": 110,
				"reward_fame": 15,
				"bonus_unit_name": "Avatar",
				"bonus_result_text": "The camp's headman looks at you before he looks at the tax men. He is waiting for you to speak first. You are the one they are bargaining around—the one whose word is starting to set the price. You post the guards and take the coin. People are beginning to read you as the one in the middle. No one mistakes you for a bystander anymore.",
				"bonus_reward_fame": 28
			},
			{
				"text": "Share directions to safer roads and move on.",
				"req_class": "",
				"req_item": "",
				"set_flags": ["helped_black_briar_refugees"],
				"result_text": "You point the refugees toward a monastery route you believe is less dangerous, then continue before the lord's men can draw you in. It is something, though far from enough.",
				"reward_fame": 5,
				"bonus_unit_name": "Yselle Maris",
				"bonus_result_text": "Yselle doesn't just point. She reads the camp—who is about to break, who needs to hear that the road has an end. She leaves them feeling like people again, not just survivors. They remember the one who kept the room human.",
				"bonus_reward_fame": 28
			}
		]
	},
	{
		"id": "whispering_marrow_pit",
		"fame_variants": {
			"heretic": { "description": "A sinkhole has opened in a battlefield charnel ground; bones gleam in cold blue vapor. The voices from the pit do not beg—they name you. The dead know what you are. The villages nearby will not forget that you stood at the edge and did not turn away." },
			"savior": { "description": "A sinkhole has opened in a battlefield charnel ground, exposing layers of bones slick with cold blue vapor. Word has run ahead: they say you quiet the restless and give names to the forgotten. The voices in the pit rise in the dialects of the dead, and the living wait to see if you will answer." }
		},
		"title": "Whispering Marrow Pit",
		"description": "A sinkhole has opened in a battlefield charnel ground, exposing layers of bones slick with cold blue vapor. Voices rise from the pit in the dialects of the dead, begging for names, prayers, and blood.",
		"options": [
			{
				"text": "Descend with a torch and lay the remains to rest.",
				"req_class": "Cleric",
				"req_item": "Torch",
				"consume_item": true,
				"set_flags": ["laid_marrow_pit_to_rest"],
				"result_text": "Your cleric spends hours naming what can be named and sealing the rest beneath ash and scripture. The whispers fade, and the nearby villages treat your company as guardians of the dead.",
				"reward_fame": 90,
				"penalty_hp": 10,
				"bonus_unit_name": "Brother Alden",
				"bonus_result_text": "Alden descends without drama. He names what can be named and seals the rest with the same steady presence that quiets a camp in crisis. The whispers fade. The villages remember the man whose faith felt like service, not judgment.",
				"bonus_reward_fame": 98
			},
			{
				"text": "Harvest relic metal and grave coin from the exposed dead.",
				"req_class": "",
				"req_item": "",
				"result_text": "You strip rings, medals, and fused coin from the remains while the vapor curls around your boots. The haul is rich, but every witness sees grave-robbing for what it is.",
				"reward_gold": 160,
				"reward_fame": -95
			},
			{
				"text": "Seal the pit with fallen masonry from a distance.",
				"req_class": "Knight",
				"req_item": "",
				"result_text": "Your party topples broken memorial stones into the hole until the voices are muffled beneath stone and mud. The danger lessens, though some fear you buried restless souls rather than freed them.",
				"reward_fame": 45
			},
			{
				"text": "Stand at the edge and speak to what the pit is asking.",
				"req_class": "Mage",
				"req_item": "",
				"result_text": "Your mage listens to the dialects in the vapor and answers—not with rites, but with the words the dead left unfinished. The whispers still when they are heard. The villages do not know what you said; they know the pit went quiet.",
				"reward_fame": 70,
				"penalty_hp": 8,
				"bonus_unit_name": "Corvin Ash",
				"bonus_result_text": "Corvin does not descend. He stands at the edge and speaks in the language the pit expects. What they wanted was not blood—only to be understood. He gives them that. Truth over comfort. The whispers still; the dead had no need to be frightening once someone refused to look away.",
				"bonus_reward_fame": 85,
				"bonus_penalty_hp": 4
			}
		]
	},
	{
		"id": "ravens_at_the_watchfire",
		"region_tag": "rift",
		"preferred_flags": ["laid_ferry_dead_to_rest", "laid_marrow_pit_to_rest"],
		"fame_variants": {
			"heretic": { "description": "At dusk you find a circle of military watchfires and an abandoned post. Ravens sit on the spears, each with a strip of skin tied to one leg. The birds turn as one toward your company. The road has long said you draw omens; here the omen has come to meet you." },
			"savior": { "description": "At dusk you find a circle of military watchfires and an abandoned post. Ravens sit on the spears, each with a strip of skin tied to one leg. Scouts who fled this place have spread your name; they say you break curses and hold the line. The ravens wait." }
		},
		"title": "Ravens at the Watchfire",
		"description": "At dusk you find a circle of military watchfires still burning around an abandoned post, though no soldiers remain. Ravens sit in perfect silence on the spears, each bird wearing a strip of human skin tied to one leg.",
		"options": [
			{
				"text": "Hold your ground and break the omen before night fully falls.",
				"req_class": "Spellblade",
				"req_item": "",
				"result_text": "Your spellblade cuts sigils through firelight and drives the flock screaming into the dark, though talons and fevered dreams exact a price. By morning the road feels less cursed, and nearby scouts spread word of your resolve.",
				"reward_fame": 70,
				"penalty_hp": 13,
				"bonus_unit_name": "Nyx",
				"bonus_result_text": "Nyx's familiarity with grim omens lets her turn the ravens without drawing their fury. Her sigils scatter the flock cleanly, and the road is safe with barely a scratch.",
				"bonus_reward_fame": 85,
				"bonus_penalty_hp": 8,
				"bonus_success_chance": 20,
				"branches": {
					"success": { "chance": 45, "result_text": "Your sigils scatter the ravens before they dive. The road is clear by midnight and scouts spread word of your resolve.", "reward_fame": 75, "penalty_hp": 6 },
					"partial": { "chance": 40, "result_text": "You drive most of the flock back, but talons and fever-dreams exact a price before the last bird flees. The road feels less cursed by morning.", "reward_fame": 45, "penalty_hp": 14 },
					"fail": { "chance": 15, "result_text": "The ravens do not break. They come in waves until you retreat, bleeding and half-mad from the dreams. The road stays cursed behind you.", "reward_fame": -25, "penalty_hp": 20 }
				},
				"flag_variants": {
					"laid_ferry_dead_to_rest": { "result_text": "Your spellblade cuts sigils through firelight. The ravens hesitate—as if the dead you laid to rest at the ferry stand between you and the omen. The flock breaks before midnight. The road remembers what you did for the nameless.", "reward_fame": 85, "penalty_hp": 8 },
					"laid_marrow_pit_to_rest": { "result_text": "Your sigils drive the flock back. The bones you named in the marrow pit seem to hold the worst of the dream at bay. By morning the road is clear; the dead have long memories.", "reward_fame": 82 }
				}
			},
			{
				"text": "Search the abandoned post for the soldiers' pay chest.",
				"req_class": "Thief",
				"req_item": "",
				"result_text": "Your thief locates a buried iron coffer beneath the watch platform and pries it free before the ravens descend. The coin is real, but the skin strips mark your company in ugly rumor.",
				"reward_gold": 125,
				"reward_fame": -65
			},
			{
				"text": "Withdraw before whatever claimed the garrison returns.",
				"req_class": "",
				"req_item": "",
				"result_text": "You leave the watchfires burning and march through the night without rest. Some dangers are survived only by refusing to name them.",
				"reward_fame": -10,
				"bonus_unit_name": "Avatar",
				"bonus_result_text": "You give the order to withdraw. The ravens turn as you leave—as if they were waiting for you to choose. The road has already named you. Omen, magnet, the one the dead look toward. You walk away. The naming does not undo itself.",
				"bonus_reward_fame": 5
			}
		]
	},
	{
		"id": "iron_mine_cavein",
		"fame_variants": {
			"heretic": { "description": "A collapsed mine mouth groans beneath a ridge of unstable shale; trapped miners hammer weakly from inside. The overseer sees your company and hesitates. The families in the mud do not look at you—they have learned who gets help and who does not." },
			"savior": { "description": "A collapsed mine mouth groans beneath a ridge of unstable shale; trapped miners hammer weakly from inside. The families in the mud see your banners and surge forward. They have heard your name; they beg you to go in before the ridge gives way." }
		},
		"title": "Iron Mine Cave-In",
		"description": "A collapsed mine mouth groans beneath a ridge of unstable shale while trapped miners hammer weakly from inside. Their overseer offers coin for a rescue, but the families kneeling in the mud offer only prayers.",
		"options": [
			{
				"text": "Brace the entrance and lead the rescue yourself.",
				"req_class": "Knight",
				"req_item": "Rope",
				"consume_item": true,
				"set_flags": ["rescued_iron_mine_miners"],
				"result_text": "Your knight and laborers secure a path through the debris and drag the miners out one bleeding body at a time. The overseer pays less than promised, but the families carry your name to every market town nearby.",
				"reward_gold": 60,
				"reward_fame": 95,
				"penalty_hp": 16,
				"bonus_unit_name": "Garrick Vale",
				"bonus_result_text": "Garrick coordinates the rescue like the officer he once was—clear orders, no wasted motion. The families do not know his name, but they see the same discipline that once kept their sons in line, this time turned to saving them. They remember.",
				"bonus_reward_fame": 105,
				"branches": {
					"success": { "chance": 40, "result_text": "The entrance holds. You pull every trapped miner out before the ridge groans again. The families weep and the overseer pays what he promised; your name is spoken in every market town.", "reward_gold": 70, "reward_fame": 100, "penalty_hp": 6 },
					"partial": { "chance": 45, "result_text": "You save most, but a second collapse seals the deepest tunnel. The rescued thank you; the rest haunt the ridge. The overseer pays less than promised.", "reward_gold": 45, "reward_fame": 60, "penalty_hp": 14 },
					"fail": { "chance": 15, "result_text": "The ridge gives way before you clear the mouth. You barely escape; the hammering from inside stops by dawn. The families do not forget, but neither do they thank.", "reward_gold": 0, "reward_fame": -30, "penalty_hp": 22 }
				}
			},
			{
				"text": "Accept the overseer's coin and clear only the ore vault.",
				"req_class": "Mercenary",
				"req_item": "",
				"result_text": "You recover ingots, ledgers, and stamped bars while the trapped hammering slowly stops. The overseer is pleased, but the widows are not.",
				"reward_gold": 170,
				"reward_fame": -90
			},
			{
				"text": "Leave spare tools and move on before the ridge gives way.",
				"req_class": "",
				"req_item": "",
				"result_text": "You pass a few picks and lanterns to the families and refuse to gamble the whole company on unstable stone. The choice is understandable, but bitter.",
				"reward_fame": -20,
				"bonus_unit_name": "Oren Pike",
				"bonus_result_text": "Oren doesn't go in. He grumbles, then tells them exactly which timbers to prop first and which to leave alone—what will hold long enough for a rescue and what will bury everyone. They remember the one who knew what not to touch.",
				"bonus_reward_fame": 25
			}
		]
	},
	{
		"id": "roadside_gallows_feast",
		"region_tag": "league_city",
		"fame_variants": {
			"heretic": { "title": "A Feast in Your Honour", "description": "A noble's retinue dines beneath a gallows where peasants swing. When your company is spotted, the table falls silent. The noble raises a toast—to the outlaws who dare show their faces on a civilized road. The blades are already loose." },
			"savior": { "description": "A noble's retinue dines beneath a gallows where peasants swing. Common folk at the roadside see your banners and begin to murmur. The noble's laughter falters; his guards glance at the crowd and then at you." }
		},
		"title": "Roadside Gallows Feast",
		"description": "A noble's retinue dines beneath a gallows where peasants swing in the evening wind, using the corpses as entertainment for drunken guests. The road is blocked by banners, musicians, and hired blades.",
		"options": [
			{
				"text": "Challenge the retinue and cut the bodies down.",
				"req_class": "Warrior",
				"req_item": "",
				"set_flags": ["gallows_defied_noble"],
				"result_text": "Steel and overturned tables send the feast into panic while your warrior breaks the gallows beam with a single brutal strike. The noble survives the humiliation, and his friends will hate you for it, but the common folk will not forget.",
				"reward_fame": 100,
				"penalty_hp": 20,
				"bonus_unit_name": "Darian",
				"bonus_result_text": "Darian doesn't perform tonight. When the moment comes, he steps forward without the usual flourish—and the noble's table goes quiet. They know his house. They know what it cost him to choose this. The road remembers the man who dropped the act.",
				"bonus_reward_fame": 110,
				"bonus_penalty_hp": 16,
				"branches": {
					"success": { "chance": 40, "result_text": "Your warrior scatters the retinue and shatters the gallows beam. The noble flees; the dead are cut down with dignity. The common folk will not forget.", "reward_fame": 105, "penalty_hp": 10 },
					"partial": { "chance": 45, "result_text": "You cut down the bodies and drive back the guards, but the noble's blades hold long enough to wound your party. The deed is done, at a cost.", "reward_fame": 70, "penalty_hp": 18 },
					"fail": { "chance": 15, "result_text": "The retinue outnumbers you. You are driven back with the gallows still full and your party bloodied. The feast continues behind you.", "reward_fame": -50, "penalty_hp": 28 }
				}
			},
			{
				"text": "Entertain the court and accept payment to keep silent.",
				"req_class": "",
				"req_item": "",
				"set_flags": ["gallows_sided_noble"],
				"result_text": "You eat at the noble's table while the dead turn above you in the dark. The purse is heavy, and the shame is heavier.",
				"reward_gold": 150,
				"reward_fame": -95,
				"bonus_unit_name": "Avatar",
				"bonus_result_text": "The noble does not treat you as a hired hand. He treats you as a calculation. The crowd at the roadside is watching you—the one the road has been naming. You take the purse. You eat at his table. The dead turn above you. When you leave, the noble's laughter is too loud. He has bought the wrong thing, and he knows it. You are not a bystander. You are becoming the political incident he just tried to swallow.",
				"bonus_reward_gold": 30,
				"bonus_reward_fame": -75
			},
			{
				"text": "Slip behind the camp and free the prisoners still waiting their turn.",
				"req_class": "Thief",
				"req_item": "",
				"set_flags": ["gallows_defied_noble"],
				"result_text": "Your thief cuts bonds in the rear wagons and leads several captives into the reeds before anyone notices. The rescue remains half-hidden, but whispers of your defiance spread anyway.",
				"reward_fame": 80
			}
		]
	},
	{
		"id": "blighted_orchard",
		"title": "Blighted Orchard",
		"description": "An orchard of blackened fruit stretches over a hill where every tree bleeds sap the color of old bruises. Children from a nearby hamlet have gone missing among the roots after chasing voices that sounded like their mothers.",
		"options": [
			{
				"text": "Track the missing children through the blight.",
				"req_class": "Archer",
				"req_item": "",
				"result_text": "Your archer reads broken twigs and bare footprints through the cursed grove, finding the children trapped in a ring of thorn and illusion. You bring them home alive, though the branches leave long cuts behind.",
				"reward_fame": 90,
				"penalty_hp": 11
			},
			{
				"text": "Burn the orchard to end the haunting.",
				"req_class": "Mage",
				"req_item": "Torch",
				"consume_item": true,
				"result_text": "The blaze devours the blight and the voices with it, but half the village's future harvest goes up in sparks as well. They are safer, though not all of them forgive the method.",
				"reward_fame": 35,
				"penalty_hp": 7
			},
			{
				"text": "Harvest what fruit still looks sellable and leave.",
				"req_class": "",
				"req_item": "",
				"result_text": "You fill sacks with the least-rotten fruit and push onward before the voices can settle into your thoughts. When buyers learn where it came from, your name rots faster than the harvest.",
				"reward_gold": 90,
				"reward_fame": -75
			}
		]
	},
	{
		"id": "ghosts_of_the_ferry",
		"region_tag": "black_coast",
		"fame_variants": {
			"heretic": { "description": "A river ferry drifts in slow circles with no ferryman aboard; pale passengers stare from the deck. The locals say the dead know the damned. They will not cross after you—they will only watch and remember who passed." },
			"savior": { "description": "A river ferry drifts in slow circles with no ferryman aboard; pale passengers stare from the deck. Word has reached even the coast: you speak for the restless and give names to the forgotten. The dead wait at the rail." }
		},
		"title": "Ghosts of the Ferry",
		"description": "A river ferry drifts in slow circles with no ferryman aboard, bumping softly against the posts as pale passengers stare from the deck. The crossing is the only route for miles, and the dead do not seem willing to share it.",
		"options": [
			{
				"text": "Board the ferry and speak to the dead as equals.",
				"req_class": "Monk",
				"req_item": "",
				"set_flags": ["laid_ferry_dead_to_rest"],
				"result_text": "Your monk bows, listens, and learns they were never buried after a massacre upriver. Once their names are carried to shore and spoken aloud, the ferry glides empty into the fog and the crossing opens again.",
				"reward_fame": 85,
				"penalty_hp": 9,
				"bonus_unit_name": "Inez",
				"bonus_result_text": "Inez doesn't need the title of priest. She steps onto the ferry and does what the land asks—names the dead, speaks the rite the river never got. The ferry glides empty into the fog. The road remembers who tends it.",
				"bonus_reward_fame": 95
			},
			{
				"text": "Use arcane force to bind the spirits aside.",
				"req_class": "Mage",
				"req_item": "",
				"result_text": "Your mage tears a corridor through the spectral crowd long enough for the party to cross, though the dead claw at mind and flesh before the bond snaps. Travelers praise your courage, but some whisper you profaned the slain.",
				"reward_fame": 50,
				"penalty_hp": 15
			},
			{
				"text": "Wait until dawn and seek another ford.",
				"req_class": "",
				"req_item": "",
				"result_text": "You camp in uneasy silence and add miles to the journey to avoid the haunted crossing entirely. The dead keep their ferry, and you keep your distance.",
				"reward_fame": -10
			}
		]
	},
	{
		"id": "the_ashen_waystation",
		"preferred_flags": ["helped_black_briar_refugees"],
		"fame_variants": {
			"heretic": { "description": "A coaching inn has been reduced to char and wet ash; survivors claw through the ruin. When they see your banners they go still. The looters in the yard scatter—not from guilt, but because they know what your kind do to witnesses." },
			"savior": { "description": "A coaching inn has been reduced to char and wet ash; survivors still claw through the ruin. Someone recognizes your company and calls out. They have heard you dig through wreckage and return the dead with dignity; they beg you to help." }
		},
		"title": "The Ashen Waystation",
		"description": "A coaching inn has been reduced to char and wet ash, yet a handful of survivors still claw through the ruin for family beneath collapsed beams. In the stable yard, opportunists haggle over stolen luggage as smoke rises from fresh graves.",
		"options": [
			{
				"text": "Help dig through the ruin until the smoke dies.",
				"req_class": "Warrior",
				"req_item": "",
				"result_text": "Your warrior lifts blackened beams until arms and back begin to fail, pulling two survivors and three bodies from the wreck. The living cling to you in gratitude, and the dead are buried with dignity.",
				"reward_fame": 80,
				"penalty_hp": 17,
				"bonus_unit_name": "Kaelen",
				"bonus_result_text": "Kaelen works in silence beside you, lifting beams until his arms shake. Survivors who have seen old soldiers before recognize the set of his shoulders; one whispers that the road still has a few who remember duty. The dead are buried with dignity.",
				"bonus_reward_fame": 95,
				"flag_variants": {
					"helped_black_briar_refugees": { "result_text": "Your warrior lifts blackened beams until arms and back begin to fail. Among the survivors are faces from the Black Briar camp—and from the plague carts you turned back from the road. They weep and call you by name; they pull beside you until the last body is free. The road has not forgotten.", "reward_fame": 100 },
					"repaired_aqueduct": { "result_text": "Your warrior lifts blackened beams until arms and back begin to fail. Among the survivors are faces from the aqueduct—they cry out your name and help you pull the rest free. The road has not forgotten what you did at the cistern.", "reward_fame": 95 },
					"extorted_aqueduct_village": { "result_text": "Your warrior lifts beams and pulls two survivors and three bodies from the wreck. One of the survivors recognizes you from the aqueduct—the village you left thirsty. They take the help in silence. The dead are buried; the living do not thank you.", "reward_fame": 50 }
				}
			},
			{
				"text": "Break up the looters and return what can be identified.",
				"req_class": "Paladin",
				"req_item": "",
				"result_text": "Your paladin drives the scavengers off the yard and sorts rings, letters, and purses back to the rightful hands. The survivors speak your name with fierce loyalty before dawn even comes.",
				"reward_fame": 95,
				"bonus_unit_name": "Branik",
				"bonus_result_text": "Branik walks into the yard and the looters step back. He doesn't raise his voice; he sorts the baggage with the same steady hands that feed the camp. The survivors remember the man who made the ruin feel less like an ending.",
				"bonus_reward_fame": 105
			},
			{
				"text": "Work alongside the survivors and help shift what can be saved.",
				"req_class": "",
				"req_item": "",
				"result_text": "You join the dig without taking charge—lifting beams, sorting salvage, returning what can be identified. The survivors work beside you in shared silence. The dead are buried with dignity.",
				"reward_fame": 70,
				"penalty_hp": 12,
				"bonus_unit_name": "Mira Ashdown",
				"bonus_result_text": "Mira works the beams without a word. A woman from the ruin catches her eye and gives a slow nod—the kind survivors give when they recognize one of their own. No fanfare. Memory carried correctly.",
				"bonus_reward_fame": 85
			},
			{
				"text": "The survivors stop when they see you. They wait.",
				"req_class": "",
				"req_item": "",
				"result_text": "You do not give an order. You simply arrive. The digging stops. The looters in the yard go still. For a moment everyone is waiting—for you to speak, to act, to be the one who decides what happens next. You join the dig. The silence breaks. But they had already named you before you lifted a single beam.",
				"reward_fame": 65,
				"penalty_hp": 8,
				"bonus_unit_name": "Avatar",
				"bonus_result_text": "They stop. Not when you speak—when they see you. The survivors, the looters, the ones still pulling at the beams. They wait. You are [AVATAR_ROLE]. You have not said a word; the room is already orienting around you. You give the order to dig. They dig. You are becoming the one they look to.",
				"bonus_reward_fame": 85,
				"bonus_penalty_hp": 4
			},
			{
				"text": "Join the scramble and take the best baggage first.",
				"req_class": "",
				"req_item": "",
				"result_text": "You seize trunks before the embers cool and depart richer than the grieving families around you. Several witnesses survive long enough to make certain everyone hears about it.",
				"reward_gold": 145,
				"reward_fame": -90
			}
		]
	},
	{
		"id": "chains_in_the_marsh",
		"region_tag": "marsh",
		"fame_variants": {
			"heretic": { "description": "From the marsh comes the clink of chains and muffled crying. The slavers have scouts; they have heard who travels this road. They will not treat you as rescue—they will treat you as competition or threat." },
			"mercenary": { "description": "From a reed-choked marsh comes the clink of chains and muffled crying. Slavers move captives by night through channels too narrow for horses. Your reputation is practical here: they will deal or fight based on numbers, not virtue." },
			"savior": { "description": "From the marsh comes the clink of chains and muffled crying. The captives have heard your name in the villages they passed. Some still dare to hope; the slavers have heard it too, and their lookouts are nervous." }
		},
		"title": "Chains in the Marsh",
		"description": "From a reed-choked marsh comes the clink of chains and muffled crying, carried over stagnant water that reeks of rot and alchemy. Slavers are moving captives by night through channels too narrow for horses.",
		"options": [
			{
				"text": "Ambush the slavers and free the captives.",
				"req_class": "Archer",
				"req_item": "",
				"set_flags": ["freed_marsh_captives"],
				"result_text": "Your archers strike from dry hummocks while the rest of the party wades in to break chains and drag prisoners free. The marsh drinks blood before it is over, but the freed captives begin singing your praises before sunrise.",
				"reward_fame": 100,
				"penalty_hp": 14,
				"bonus_unit_name": "Rufus",
				"bonus_result_text": "Rufus leads the assault with the same conviction that keeps a city honest. The slavers break under disciplined volleys and a charge that leaves no doubt. The freed captives swear his name will be remembered in every port.",
				"bonus_reward_fame": 110,
				"bonus_penalty_hp": 10,
				"bonus_success_chance": 15,
				"branches": {
					"success": { "chance": 50, "result_text": "Your archers drop the slavers from the hummocks; the rest of you wade in and break every chain. The marsh drinks only slaver blood. By sunrise the freed captives are singing your praises.", "reward_fame": 105, "penalty_hp": 8 },
					"partial": { "chance": 35, "result_text": "You free most of the captives, but a handful of slavers escape into the reeds and the fight leaves your party bloodied. The freed still thank you, with fear in their eyes.", "reward_fame": 60, "penalty_hp": 16 },
					"fail": { "chance": 15, "result_text": "The slavers were ready. They flank you in the water and the ambush becomes a rout. You retreat with a few freed souls; the rest are dragged deeper into the marsh.", "reward_fame": -40, "penalty_hp": 22 }
				}
			},
			{
				"text": "Negotiate for a share of their next sale.",
				"req_class": "Mercenary",
				"req_item": "",
				"set_flags": ["dealt_with_marsh_slavers"],
				"result_text": "The slavers respect hard eyes and practical terms, and they pay you to look the other way. The coin is heavy, and the hatred that follows it is heavier still.",
				"reward_gold": 180,
				"reward_fame": -100
			},
			{
				"text": "Shadow the marsh roads and remember where they went.",
				"req_class": "",
				"req_item": "",
				"result_text": "You avoid a direct clash, but you memorize the route and the landmarks with cold precision. The captives are not saved today, though the trail is not lost.",
				"reward_fame": 10
			}
		]
	},
	{
		"id": "cairn_of_the_oathbreaker",
		"region_tag": "greyspire",
		"preferred_fame_states": ["savior"],
		"fame_variants": {
			"heretic": { "description": "A toppled war cairn marks the grave of a commander who sold his troops for a title. The pious who still tend this stretch will not let you near the stones. They say the oathbreaker's curse feeds on the faithless; they bar your path." },
			"savior": { "description": "A toppled war cairn marks the grave of a commander who sold his troops for a title. The veterans who remember this place have heard your name. They ask you to reset the stones—they say only someone the dead might trust can bind the oathbreaker again." }
		},
		"title": "Cairn of the Oathbreaker",
		"description": "A toppled war cairn marks the grave of a commander who sold his own troops to die for a title. Since the stones were disturbed, patrols vanish near the hill and return marching in circles until they starve.",
		"options": [
			{
				"text": "Rebuild the cairn and bind the oathbreaker beneath it.",
				"req_class": "Paladin",
				"req_item": "",
				"set_flags": ["bound_oathbreaker"],
				"result_text": "Your paladin resets the stones one by one while reciting the dead commander's crimes to the wind. The circles in the grass stop by dawn, and the soldiers who hear of it salute your company from then on.",
				"reward_fame": 90,
				"penalty_hp": 8,
				"bonus_unit_name": "Ser Hadrien",
				"bonus_result_text": "Hadrien resets the stones. He does not need to recite the crimes; he carries them. The circles in the grass stop. The road feels the weight of an oath that outlived its era.",
				"bonus_reward_fame": 98,
				"bonus_penalty_hp": 4
			},
			{
				"text": "Search the grave for the commander's battlefield treasury.",
				"req_class": "",
				"req_item": "",
				"result_text": "You pry open the cairn and recover old campaign silver, rank insignia, and lacquered rings from the bones beneath. The curse thickens behind you as the rumor of grave theft spreads ahead.",
				"reward_gold": 155,
				"reward_fame": -90
			},
			{
				"text": "Mark the hill as forbidden and move on.",
				"req_class": "Knight",
				"req_item": "",
				"result_text": "You post warnings and leave the cairn untouched, keeping later travelers from wandering into the worst of the haunting. It is a cautious mercy, and only a modest one.",
				"reward_fame": 25
			}
		]
	},
	{
		"id": "feast_of_hollow_masks",
		"region_tag": "sacred_road",
		"preferred_fame_states": ["savior"],
		"fame_variants": {
			"heretic": { "description": "In a village stripped nearly bare by war, the people host a silent feast in hollow wooden masks. When your company is seen, the masks turn as one. No seat is offered. The rite is not for you; the village will not break vigil for the likes of you." },
			"savior": { "description": "In a village stripped nearly bare by war, the people host a silent feast in hollow wooden masks. They have heard your name. A place is cleared at the table before you can refuse; the rusted coin at the setting is laid there with trembling hands." }
		},
		"title": "Feast of Hollow Masks",
		"description": "In a village stripped nearly bare by war, the people host a silent feast wearing hollow wooden masks and offering strangers seats at the table. No one touches the food, and every place setting includes a rusted funerary coin.",
		"options": [
			{
				"text": "Participate in the rite and learn whom they mourn.",
				"req_class": "Cleric",
				"req_item": "",
				"req_fame_state": ["mercenary", "savior"],
				"set_flags": ["feast_vigil_kept"],
				"result_text": "Your cleric sits through the silent course and discovers the feast honors those taken by a press-gang who never returned. By dawn you have helped them complete the vigil properly, and the village declares your company blessed guests forever after.",
				"reward_fame": 80,
				"bonus_unit_name": "Liora",
				"bonus_result_text": "Liora does not only sit the vigil — she names the lost and speaks the blessings the village had no one left to give. By dawn the masks come off in tears of relief, and the village declares your company and her faith blessed forever after.",
				"bonus_reward_fame": 90
			},
			{
				"text": "Expose the hidden corpses beneath the floorboards.",
				"req_class": "Mage",
				"req_item": "",
				"result_text": "Your mage senses trapped unrest and reveals shallow graves under the hall, forcing the village into grief rather than denial. The truth is ugly, but it frees them from the ritual's slow madness.",
				"reward_fame": 70,
				"penalty_hp": 9
			},
			{
				"text": "Steady the room so the vigil can hold.",
				"req_class": "",
				"req_item": "",
				"result_text": "You do not sit the rite yourself—you read the room, calm the ones near breaking, and keep the feast from flying apart. By the time the masks come off, the village has completed what they came to do. They remember the presence that held the space.",
				"reward_fame": 65,
				"bonus_unit_name": "Yselle Maris",
				"bonus_result_text": "Yselle never raises her voice. She moves through the hall like she knows exactly where the cracks are—who is about to weep, who needs a hand on a shoulder. The vigil holds. The village remembers the one who kept them human in front of an audience.",
				"bonus_reward_fame": 82
			},
			{
				"text": "Refuse the feast and leave before night deepens.",
				"req_class": "",
				"req_item": "",
				"result_text": "You decline the offered seats and continue the march while the masked villagers watch without a word. Whatever sorrow binds the hall remains there, not with you.",
				"reward_fame": -5,
				"bonus_unit_name": "Avatar",
				"bonus_result_text": "You refuse. The masks turn as one. They are not watching a stranger leave—they are watching you. The one the road is beginning to name. You walk out. They do not call after you. You are becoming the kind of presence that is watched in silence. The anonymity you once had is slipping away.",
				"bonus_reward_fame": 5
			}
		]
	},
	{
		"id": "shattered_aqueduct",
		"preferred_fame_states": ["savior", "mercenary"],
		"fame_variants": {
			"heretic": { "description": "A broken aqueduct spills water into a ravine; two settlements below draw blades over the cistern. When your company is seen, both sides pause. They do not want your help—they want you gone before you become the excuse for the next massacre." },
			"savior": { "description": "A broken aqueduct spills precious clean water into a ravine; two settlements below draw blades over the last cistern. Both sides have heard your name. They lower their weapons long enough to see if you will speak—and whether the other will listen." }
		},
		"title": "Shattered Aqueduct",
		"description": "A broken aqueduct spills precious clean water into a ravine while two settlements below draw blades over the last usable cistern. The stone channels tremble with each aftershock, and the next collapse may bury them all.",
		"options": [
			{
				"text": "Coordinate a repair under falling stone.",
				"req_class": "Knight",
				"req_item": "Rope",
				"consume_item": true,
				"set_flags": ["repaired_aqueduct"],
				"result_text": "Your knight organizes ladders, braces, and hauling lines while workers race the trembling masonry. The water is restored before dawn, and both settlements spread your name as the force that stopped a blood feud.",
				"reward_fame": 100,
				"penalty_hp": 15,
				"bonus_unit_name": "Rufus",
				"bonus_result_text": "Rufus doesn't give speeches. He picks up a shovel and shows the village how to brace the channel. By the time the water runs, they're already passing his name to the next crew—in the language of work, not blessings.",
				"bonus_reward_fame": 110
			},
			{
				"text": "Sell water discipline and guard service to the richer village.",
				"req_class": "Mercenary",
				"req_item": "",
				"set_flags": ["extorted_aqueduct_village"],
				"result_text": "You secure the cistern and enforce rationing for whoever can pay, ensuring order for one side and thirst for the other. The contract is lucrative and morally ugly.",
				"reward_gold": 140,
				"reward_fame": -70
			},
			{
				"text": "Survey the structure and direct what will hold.",
				"req_class": "",
				"req_item": "",
				"result_text": "You inspect the channels, the cracks, the points of failure, and tell both sides exactly what will collapse if they keep fighting—and what to brace if they want to live. The repair that follows is theirs; the knowledge is yours.",
				"reward_fame": 55,
				"penalty_hp": 4,
				"bonus_unit_name": "Oren Pike",
				"bonus_result_text": "Oren grumbles through the inspection, then tells them which timbers to prop, which to cut, and which to leave alone. He doesn't charm anyone. When the water runs again, they remember the one who understood consequences.",
				"bonus_reward_fame": 75
			},
			{
				"text": "Broker a brief truce and continue on.",
				"req_class": "",
				"req_item": "",
				"result_text": "You force both sides to lower their blades long enough to divide what little water remains for the day. It is only a pause in the feud, but it buys time.",
				"reward_fame": 10,
				"bonus_unit_name": "Avatar",
				"bonus_result_text": "One of the village elders meets your eyes and holds. The rest take their cue from him—and from you. Both sides look at you before they look at each other. You are [AVATAR_ROLE]—the one whose presence the room reads. You speak. They lower their blades. It is only a pause, but the pause is yours. They will remember who held the room.",
				"bonus_reward_fame": 35
			}
		]
	},
	{
		"id": "the_red_snowfield",
		"region_tag": "mountain_pass",
		"title": "The Red Snowfield",
		"description": "A stretch of snow remains stained red months after a massacre, and travelers crossing it hear marching drums under the ice. Half-buried standards still jut from the drift like frozen spears pointing nowhere.",
		"options": [
			{
				"text": "Recover the fallen standards and return them to the nearest shrine.",
				"req_class": "Warrior",
				"req_item": "",
				"result_text": "Your warrior hauls splintered banners out of the ice while the dead seem to march beside you in silence. When the standards are finally laid down at the shrine, veterans across the region speak of your honor.",
				"reward_fame": 85,
				"penalty_hp": 10
			},
			{
				"text": "Dig for battlefield spoils trapped under the crust.",
				"req_class": "",
				"req_item": "",
				"result_text": "You strip rings, blade fittings, and frozen payroll from the dead with numb fingers as the drums grow louder beneath the snow. The coin spends cleanly even when the story behind it does not.",
				"reward_gold": 150,
				"reward_fame": -85,
				"penalty_hp": 6
			},
			{
				"text": "Track the phantom drums to their source.",
				"req_class": "Archer",
				"req_item": "",
				"result_text": "Your archer follows impossible sound through wind and whiteout to a buried command sled where unburied officers still bind the field in unrest. Breaking the sled's insignia quiets the drums at last.",
				"reward_fame": 70,
				"penalty_hp": 11
			}
		]
	},
	{
		"id": "widows_at_the_forge",
		"region_tag": "famine_fields",
		"preferred_flags": ["helped_famine_wagon", "rescued_iron_mine_miners"],
		"title": "Widows at the Forge",
		"description": "At a village forge, widows melt the armor of their dead into farming tools because they cannot afford seed, guards, or grief for much longer. A passing recruiter offers them coin to turn the metal back into spearheads for the next levy.",
		"options": [
			{
				"text": "Pay the recruiter to leave and help finish the tools.",
				"req_class": "Monk",
				"req_item": "",
				"req_fame_state": ["savior", "mercenary"],
				"result_text": "Your monk empties part of the company purse and works the bellows beside the widows until dawn. The recruiter rides off bitter and empty-handed, while the village gains one more season to live.",
				"reward_gold": -70,
				"reward_fame": 95,
				"fame_variant_result": {
					"savior": { "result_text": "The widows recognize your company and accept your coin without hesitation. They work beside your monk through the night; by dawn the recruiter is gone and the village has sworn to remember who stood with them.", "reward_gold": -60, "reward_fame": 105 }
				},
				"flag_variants": {
					"helped_famine_wagon": { "result_text": "The widows have heard about the wagon at dusk—who shared food when they had none. They take your coin and work the bellows without asking twice. It is not courtly thanks; it is the memory of who did not pass by.", "reward_fame": 105 },
					"rescued_iron_mine_miners": { "result_text": "One of the widows is a miner's wife. She has heard your name from the cave-in. She does not weep; she nods and works beside your monk until dawn. The village gains one more season, and the road has not forgotten the rescue.", "reward_fame": 100 }
				},
				"bonus_unit_name": "Inez",
				"bonus_result_text": "Inez talks the recruiter down with a mix of coin and cold reason, then spends the night at the forge so the widows finish every tool. Word spreads that someone with a soldier's past chose their side, and the village names her guardian.",
				"bonus_reward_gold": -50,
				"bonus_reward_fame": 100
			},
			{
				"text": "Take the recruiter's contract and escort the metal shipment.",
				"req_class": "Mercenary",
				"req_item": "",
				"result_text": "You guard the cart as breastplates become spearheads once more, leaving the widows staring at empty racks and colder futures. The pay is strong, and so is the contempt it earns.",
				"reward_gold": 160,
				"reward_fame": -95
			},
			{
				"text": "Leave a little coin and continue the march.",
				"req_class": "",
				"req_item": "",
				"result_text": "You cannot solve the village's future, but you leave enough coin for coal and seed before moving on. The gesture is small, yet deeply felt.",
				"reward_gold": -30,
				"reward_fame": 20
			}
		]
	},
	{
		"id": "lanterns_on_the_grave_road",
		"region_tag": "dark_tide",
		"preferred_flags": ["laid_ferry_dead_to_rest"],
		"fame_variants": {
			"heretic": { "description": "At moonrise, lanterns walk the grave road with no hands holding them. The villagers have barred their doors—from the dead and from you. They say the cursed draw the lights; they beg you to leave before you draw them to the gates." },
			"savior": { "description": "At moonrise, dozens of lanterns walk the grave road with no hands holding them. The villagers have heard your name. They beg you to stand in the road—they say only those who have faced worse can turn the lights back." }
		},
		"title": "Lanterns on the Grave Road",
		"description": "At moonrise, dozens of lanterns begin walking down the grave road with no hands holding them, drifting toward a cemetery overrun by fresh earth and open crypts. The villagers bar their doors and beg you not to let the lights reach the gates.",
		"options": [
			{
				"text": "Stand in the road and confront whatever leads the lanterns.",
				"req_class": "Paladin",
				"req_item": "",
				"result_text": "Your paladin plants steel in the dirt and forces the procession to reveal a headless grave-warden dragging chains through the mist. When it falls, the lanterns gutter out and the village erupts in relieved bells and tears.",
				"reward_fame": 100,
				"penalty_hp": 18,
				"bonus_unit_name": "Ser Hadrien",
				"bonus_result_text": "Hadrien stands in the road. The lanterns slow. Something in the mist recognizes what he is—oath, memory, the dead who have not left. The grave-warden falls. The village bells ring. Memory answering memory.",
				"bonus_reward_fame": 108,
				"bonus_penalty_hp": 12,
				"flag_variants": {
					"laid_ferry_dead_to_rest": { "result_text": "Your paladin plants steel in the dirt. The grave-warden rises from the mist—and the dead you laid to rest at the ferry seem to stand with you in that moment. The lanterns gutter; the village bells ring. The road remembers what you did for the nameless.", "reward_fame": 110 }
				}
			},
			{
				"text": "Scatter the procession with arcane fire from a safe distance.",
				"req_class": "Mage",
				"req_item": "",
				"result_text": "Your mage blasts the lanterns into bursts of oil and pale flame, stopping the march but setting brush and grave flowers alight in the process. The villagers are saved, though the cemetery burns until dawn.",
				"reward_fame": 40,
				"penalty_hp": 10
			},
			{
				"text": "Bar the villagers inside and avoid the grave road.",
				"req_class": "",
				"req_item": "",
				"result_text": "You help the villagers secure shutters and doors, then order everyone away from the road until sunrise. The haunting passes without confrontation, though nothing is truly resolved.",
				"reward_fame": 10,
				"bonus_unit_name": "Avatar",
				"bonus_result_text": "You give the order. Bar the doors. Stay inside. The villagers look at you before they move—reading your face before they choose panic or order. You are the one they are beginning to wait on. You are not a neighbor helping anymore. The lanterns pass. The village is safe. They thank you like someone the road has already started to name.",
				"bonus_reward_fame": 28
			}
		]
	},
	{
		"id": "the_hunger_tithe",
		"region_tag": "famine_fields",
		"preferred_fame_states": ["savior"],
		"preferred_flags": ["rescued_iron_mine_miners"],
		"fame_variants": {
			"heretic": { "description": "In a famine-struck parish, the granary is locked by decree. The guards have orders: if your company approaches the storehouse, they are to treat it as a raid. The mothers boiling leather watch in silence; they have learned not to hope for outlaws." },
			"mercenary": { "description": "In a famine-struck parish, the granary is locked until the bishop's agents arrive. The guards will deal with anyone who can pay or enforce—your reputation precedes you as useful, not saintly." },
			"savior": { "description": "In a famine-struck parish, the granary is locked by decree. The hungry have heard your name. They press toward your company; the guards glance at the crowd and at you, and do not raise their pikes." }
		},
		"title": "The Hunger Tithe",
		"description": "In a famine-struck parish, the granary is locked by decree until the bishop's agents arrive to count every sack and claim their share. Outside, mothers boil leather and bark while the guards insist the law must be honored.",
		"options": [
			{
				"text": "Break the granary open and distribute food immediately.",
				"req_class": "Warrior",
				"req_item": "",
				"result_text": "Your warrior smashes the lock and keeps order while the grain is measured into shaking hands rather than church ledgers. The bishop's house brands you criminal, but the hungry call you savior.",
				"reward_fame": 95,
				"penalty_hp": 9,
				"flag_variants": {
					"helped_famine_wagon": { "result_text": "Your warrior smashes the lock and keeps order while the grain is measured out. Among the hungry are faces from the wagon at dusk—they press forward to thank you by name. Word of your mercy has run ahead; the bishop brands you criminal, but this parish will not forget.", "reward_fame": 105 },
					"abandoned_famine_wagon": { "result_text": "Your warrior smashes the lock and keeps order. The mothers take the grain in silence. Some have heard what happened at the wagon at dusk—who passed by. They feed their children; they do not thank you.", "reward_fame": 70 }
				}
			},
			{
				"text": "Enforce the tithe in exchange for official payment.",
				"req_class": "Knight",
				"req_item": "",
				"result_text": "You hold the line while church agents count grain away from the starving and load their carts under armed watch. The payment is prompt, and the hatred is unforgettable.",
				"reward_gold": 170,
				"reward_fame": -100
			},
			{
				"text": "Leave hidden food caches and avoid open conflict.",
				"req_class": "",
				"req_item": "",
				"result_text": "You quietly leave grain, dried meat, and coin where desperate families will find them after dark, then depart before the church men can trace it. It does not end the tithe, but it keeps some children alive.",
				"reward_gold": -40,
				"reward_fame": 30,
				"flag_variants": {
					"helped_famine_wagon": { "result_text": "You leave the caches where the hungry will find them. Among the mothers who slip out at dusk are faces from the wagon—they say nothing. They take the food and hide your tracks. Survival has a long memory.", "reward_fame": 45 },
					"rescued_iron_mine_miners": { "result_text": "You leave grain and coin in the usual places. The miners' families know the drill; they have seen you before, at the cave-in. They spread the caches and say nothing to the church. The parish remembers.", "reward_fame": 40 }
				}
			}
		]
	},
	{
		"id": "charred_wayfarer_shrine",
		"region_tag": "sacred_road",
		"preferred_fame_states": ["savior"],
		"preferred_flags": ["salt_road_mercy"],
		"fame_variants": {
			"heretic": { "description": "A roadside shrine has been burned black, its saint's face split by heat. Pilgrims camped nearby pack at the sight of your banners. They will not share the road with you; the hollow beneath the altar will keep its secrets until someone else comes." },
			"savior": { "description": "A roadside shrine has been burned black, its saint's face split by heat. Those who still tend this stretch of the sacred road have heard your name. They step aside and ask only that you treat what lies beneath with the respect the flames could not." }
		},
		"title": "Charred Wayfarer Shrine",
		"description": "A roadside shrine has been burned black, its saint's face split by heat and soot. Beneath the cracked altar, a hollow sound suggests something was hidden before the war reached this road.",
		"options": [
			{
				"text": "Pry the altar stone loose.",
				"req_class": "",
				"req_item": "Crowbar",
				"consume_item": false,
				"result_text": "With iron leverage and a shower of dust, the slab shifts just enough to expose a sealed compartment. Inside lies an old insignia wrapped in scorched linen, overlooked by looters who lacked patience or tools.",
				"reward_fame": 15,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/dawn_sigil.tres"
			},
			{
				"text": "Recite the shrine's broken prayers and search respectfully.",
				"req_class": "Cleric",
				"req_item": "",
				"result_text": "Your cleric recognizes half-obliterated rites of passage and uncovers a hidden niche behind the altar without disturbing the whole structure. A brittle vow-scroll lies within, spared only because the flames never reached that far.",
				"reward_fame": 40,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/oath_parchment.tres",
				"flag_variants": {
					"salt_road_mercy": { "result_text": "Your cleric recites the broken prayers. Pilgrims camped nearby have heard what you did on the salt road—they leave a second offering at the altar before you go. The vow-scroll is in your hands; their trust is in their eyes.", "reward_fame": 55 }
				}
			},
			{
				"text": "Leave the burned shrine behind.",
				"req_class": "",
				"req_item": "",
				"result_text": "You pass the ruin in silence and let the dead keep what little the fire spared. The road grows no kinder for it.",
				"reward_fame": -5
			}
		]
	},
	{
		"id": "famine_wagon_at_dusk",
		"region_tag": "famine_fields",
		"fame_variants": {
			"heretic": { "description": "A wagon piled with empty grain sacks leans in a ditch; villagers sit around it too weak to argue. They see your company and go still. They have heard what you are. They will not ask—they will only watch until you pass." },
			"savior": { "description": "A wagon piled with empty grain sacks leans in a ditch; villagers sit around it too weak to argue. Someone recognizes your banners and struggles to stand. Word has reached even here: you are the ones who share when you have enough." }
		},
		"title": "Famine Wagon at Dusk",
		"description": "A wagon piled with empty grain sacks leans in a ditch while a handful of villagers sit around it too weak to argue. Their eyes follow your packs more closely than your weapons.",
		"options": [
			{
				"text": "Distribute preserved food from your stores.",
				"req_class": "",
				"req_item": "Travel Rations",
				"consume_item": true,
				"set_flags": ["helped_famine_wagon"],
				"result_text": "You break open your provisions and hand them out in measured portions. The villagers devour the food without ceremony, then speak your company name with the hushed fervor reserved for miracles.",
				"reward_fame": 60,
				"bonus_unit_name": "Tamsin Reed",
				"bonus_result_text": "Tamsin talks through her fear until her hands find the work. She portions it out—nervous until the first family gets their share, then steady. Small acts of care. They remember who fed them.",
				"bonus_reward_fame": 72
			},
			{
				"text": "Share drink and soft food with the weakest among them.",
				"req_class": "",
				"req_item": "Apple Cider",
				"consume_item": true,
				"set_flags": ["helped_famine_wagon"],
				"result_text": "The cider steadies trembling hands and wets cracked throats, buying enough strength for the sickest to swallow again. It is not abundance, but on this road it passes for mercy.",
				"reward_fame": 35,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Cooking/wheat_sheaf.tres"
			},
			{
				"text": "Move on before hunger makes them desperate.",
				"req_class": "",
				"req_item": "",
				"set_flags": ["abandoned_famine_wagon"],
				"result_text": "You keep formation and leave the ditch behind before need turns to violence. Their staring does not stop until the road bends out of sight.",
				"reward_fame": -30
			}
		]
	},
	{
		"id": "sealed_crypt_door",
		"region_tag": "rift",
		"preferred_flags": ["laid_ferry_dead_to_rest", "laid_marrow_pit_to_rest"],
		"fame_variants": {
			"heretic": { "description": "An old burial door protrudes from a landslide, its iron seams exposed by rain. Something has scratched from the inside. The locals say the crypt wakes when the cursed pass; they have already marked your approach." },
			"savior": { "description": "An old burial door protrudes from a landslide, its iron seams newly exposed by rain. The lock is funerary, not noble, and something has scratched from the inside. The villages speak of you as those who lay the restless to peace—they ask whether you will do the same here." }
		},
		"title": "Sealed Crypt Door",
		"description": "An old burial door protrudes from a landslide, its iron seams newly exposed by rain. The lock is funerary, not noble, and something has scratched from the inside at the stone around it.",
		"options": [
			{
				"text": "Read the door and speak to what waits.",
				"req_class": "Mage",
				"req_item": "",
				"result_text": "Your mage traces the seals, speaks the words the dead left on the stone, and the scratching stops. The door opens without a key. What lay inside was not malice—only hunger to be heard. You take the shard; the crypt is still.",
				"reward_fame": 35,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/moonsteel_shard.tres",
				"penalty_hp": 6,
				"bonus_unit_name": "Corvin Ash",
				"bonus_result_text": "Corvin does not flinch. He reads what is written on the door and answers in the language it expects. The thing behind the stone was not evil—only unfinished. He understands what the dead want. The crypt yields; the truth was always sharper than comfort.",
				"bonus_reward_fame": 48,
				"bonus_penalty_hp": 2
			},
			{
				"text": "Use the proper key and open it carefully.",
				"req_class": "",
				"req_item": "Crypt Key",
				"consume_item": false,
				"result_text": "The key turns with a groan like bone in frost, and the door yields to a crypt still half-intact. On the inner bier lies a shard of pale metal wrapped in burial cloth stained centuries old.",
				"reward_fame": 20,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/moonsteel_shard.tres",
				"flag_variants": {
					"laid_ferry_dead_to_rest": { "result_text": "The key turns. Inside, the scratching has stopped. The dead you named at the ferry seem to walk with you in that moment—the crypt yields the shard without a sound. The rift remembers who speaks for the restless.", "reward_fame": 35 },
					"laid_marrow_pit_to_rest": { "result_text": "The key turns with a groan. The bones you laid to rest in the marrow pit have carried your name into places the living do not go. The crypt is still; the shard is in your hands. The dead have long memories.", "reward_fame": 32 }
				}
			},
			{
				"text": "Force the lock with thin tools and steady hands.",
				"req_class": "Thief",
				"req_item": "Lock Picks",
				"consume_item": false,
				"result_text": "Your thief slips the ancient mechanism after several tense minutes while everyone else watches the dark seam beneath the door. The crypt holds a relic of funerary glass that makes torchlight bend strangely around it.",
				"reward_gold": 40,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/veil_glass.tres"
			},
			{
				"text": "Leave the dead to their lock and mud.",
				"req_class": "",
				"req_item": "",
				"result_text": "You let the earth keep its secret and continue before night closes around the slope. The scratching behind the stone might have been memory, or hunger.",
				"reward_fame": 5,
				"bonus_unit_name": "Avatar",
				"bonus_result_text": "You walk away. The crypt stays shut. But the slope feels watched—not by the dead behind the door, but by something that has already named you. Omen, answer, wound in the world. You did not open the door. The road has already opened you. You leave. The naming does not undo itself.",
				"bonus_reward_fame": 18
			}
		]
	},
	{
		"id": "bridge_of_rotten_planks",
		"title": "Bridge of Rotten Planks",
		"description": "A ravine bridge still stands by habit more than strength, its planks split and its ropes slick with old rain. A dead courier hangs below in a snapped harness, his satchel caught on a beam over the drop.",
		"options": [
			{
				"text": "Secure a line and descend for the satchel.",
				"req_class": "",
				"req_item": "Rope Coil",
				"consume_item": false,
				"result_text": "A rope line keeps the rescuer from vanishing into the gorge when the beam shifts under weight. The satchel contains a sealed letter of sworn service that should never have been left to the crows.",
				"reward_fame": 15,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/oath_parchment.tres"
			},
			{
				"text": "Leap down the beams and recover it quickly.",
				"req_class": "Warrior",
				"req_item": "",
				"result_text": "Your warrior crashes down the support frame, rips the satchel free, and climbs back with bruised ribs and shaking hands. The deed is bold enough to impress even those who call it foolish.",
				"reward_fame": 45,
				"penalty_hp": 14,
				"bonus_unit_name": "Maela Thorn",
				"bonus_result_text": "Maela doesn't wait for a rope. She's down the beams before anyone can argue, satchel in hand, back up with a grin that says she knew she could. Motion changes the encounter. They remember who got there first.",
				"bonus_reward_fame": 58,
				"bonus_penalty_hp": 8
			},
			{
				"text": "Cross one at a time and ignore the corpse.",
				"req_class": "",
				"req_item": "",
				"result_text": "You inch across the bridge and leave the satchel swaying in the wind below. Whatever message died with the courier remains buried with him.",
				"reward_fame": -10
			}
		]
	},
	{
		"id": "vermin_cellar_below_inn",
		"region_tag": "docks",
		"preferred_fame_states": ["mercenary"],
		"preferred_flags": ["smuggler_cistern_dealt", "gallows_sided_noble"],
		"fame_variants": {
			"heretic": { "description": "The ruins of an inn shelter a root cellar beneath the collapsed kitchen. The survivor who pointed you here has fled. In the docks, your kind are bad for business—they would rather lose the provisions than be seen with you." },
			"mercenary": { "description": "The ruins of an inn still shelter a root cellar beneath the collapsed kitchen. The survivor who swears provisions remain below has heard your reputation: you take risks and you take a share. They are willing to deal." }
		},
		"title": "Vermin Cellar Below the Inn",
		"description": "The ruins of an inn still shelter a root cellar beneath the collapsed kitchen, but the entrance reeks of damp fur and worse. A frightened survivor swears provisions remain below, if the gnawing things have not spoiled them.",
		"options": [
			{
				"text": "Drive the cellar vermin back with smoke and flame.",
				"req_class": "",
				"req_item": "Torch Bundle",
				"consume_item": true,
				"result_text": "The burning resin fills the cellar with thick black smoke, and the creatures flee deeper through cracks in the stone. You drag out intact stores before the air turns unbreathable.",
				"reward_gold": 25,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Cooking/goat_cheese.tres",
				"bonus_unit_name": "Sabine Varr",
				"bonus_result_text": "Sabine doesn't raise her voice. She posts the party, clears the perimeter, and the survivor stops shaking long enough to point. The cellar is secured. The docks remember who kept their head.",
				"bonus_reward_gold": 35,
				"flag_variants": {
					"gallows_sided_noble": { "result_text": "The smoke drives the vermin back. The survivor has heard about the feast beneath the gallows—who ate at the noble's table. They take their share in silence and do not meet your eyes. The docks have long memories.", "reward_gold": 15 },
					"smuggler_cistern_dealt": { "result_text": "The smoke drives the vermin back. As you haul out the stores, a dockhand you don't recognize nods from the alley—word of the cistern run has reached the right ears. They leave an extra crate by the steps. No one asks; no one explains.", "reward_gold": 45 }
				}
			},
			{
				"text": "Lower a lantern and search methodically.",
				"req_class": "",
				"req_item": "Lantern",
				"consume_item": false,
				"result_text": "The steady light reveals where rot ends and salvage begins. Hidden behind collapsed shelves you find both preserved food and a strange wax-sealed vial forgotten by whatever last fed here.",
				"reward_fame": 10,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/ghoul_ichor.tres",
				"bonus_unit_name": "Nyx",
				"bonus_result_text": "The lantern finds the stores—and a dock worker who knows Nyx by another name steps out of the shadows. No words, just a second vial and a nod. The kind of trust that doesn't need explaining. The docks remember who reads danger first.",
				"bonus_reward_fame": 28,
				"flag_variants": {
					"gallows_defied_noble": { "result_text": "The lantern finds the stores—and a dock worker who watched you cut down the gallows bodies steps out of the shadows. They say nothing. They leave a second vial and a nod. The docks remember who defied the noble.", "reward_fame": 25 }
				}
			},
			{
				"text": "Let the cellar keep its teeth.",
				"req_class": "",
				"req_item": "",
				"result_text": "You choose not to crawl into a ruin that already sounds half alive. The survivor watches you go with the blank resignation of someone who has run out of surprises.",
				"reward_fame": -15
			},
			{
				"text": "Meet the contact from the cistern run.",
				"req_class": "",
				"req_item": "",
				"required_flags": ["smuggler_cistern_dealt"],
				"result_text": "A figure you half recognize from the customs shed steps out of the alley. They say nothing of the cistern; they hand you a sealed purse and a scrap with a dock number. Keep the right kind of silence, and the League remembers who can be trusted.",
				"reward_gold": 85,
				"reward_fame": 5,
				"bonus_unit_name": "Hest Sparks",
				"bonus_result_text": "The figure steps out of the alley. They look at Hest, then at you. A half grin. 'So you're the one they came back for.' The purse is heavier than it had to be. The streets remember sideways.",
				"bonus_reward_gold": 110,
				"bonus_reward_fame": 15
			}
		]
	},
	{
		"id": "grave_pit_after_rain",
		"preferred_flags": ["laid_ferry_dead_to_rest", "laid_marrow_pit_to_rest"],
		"title": "Grave Pit After Rain",
		"description": "Rain has collapsed a mass grave outside a plague village, exposing rotted boards and pale hands beneath the mud. Something glitters in the slurry near the lowest layer, where no sane gravedigger would have climbed willingly.",
		"options": [
			{
				"text": "Dig carefully through the collapse.",
				"req_class": "",
				"req_item": "Shovel",
				"consume_item": false,
				"result_text": "The shovel lets you work the unstable mud without burying yourself beside the dead. Wrapped in oilcloth beneath the lowest board is a funerary key black with old wax.",
				"reward_fame": 10,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/crypt_key.tres"
			},
			{
				"text": "Break the stone marker and reach the cavity from the side.",
				"req_class": "",
				"req_item": "Pick Hammer",
				"consume_item": false,
				"result_text": "The pick opens a safer angle through the grave border, though each strike echoes across the drowned field like accusation. Buried in the loosened cavity you find a vial of breach-scorched dust tucked into a dead scholar's pouch.",
				"reward_fame": -10,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/night_of_cinders.tres"
			},
			{
				"text": "Cover what you can and refuse the temptation.",
				"req_class": "",
				"req_item": "",
				"set_flags": ["covered_grave_pit"],
				"result_text": "You scrape mud back over the opened dead with boots and broken boards, then leave the rest to weather and silence. Whatever shone below remains with those who fell nameless.",
				"reward_fame": 20,
				"flag_variants": {
					"laid_ferry_dead_to_rest": { "result_text": "You scrape mud back over the dead. The same instinct that led you to name them at the ferry keeps your hands from the glitter below. The pit is covered; the nameless keep what is theirs. The road has not forgotten.", "reward_fame": 30 },
					"laid_marrow_pit_to_rest": { "result_text": "You cover what you can. The dead you named in the marrow pit seem to stand at your back—you leave the grave as you found it, only quieter. Whatever shone below stays with the nameless.", "reward_fame": 28 }
				}
			}
		]
	},
	{
		"id": "purifier_checkpoint_ruin",
		"preferred_flags": ["salt_road_mercy"],
		"fame_variants": {
			"heretic": { "description": "A ruined checkpoint stands where the road narrows; holy banners burned, wagon overturned. The Purifiers who fell here would have marked you for death. The coffer beneath the axle is intact—and the survivors who return will assume you took it. They will be right to fear what you might do with it." },
			"savior": { "description": "A ruined checkpoint stands where the road narrows; its holy banners burned, its wagon overturned. Those who still serve the order have heard your name. They will not thank you for what you find—but they may not hunt you for it either." }
		},
		"title": "Purifier Checkpoint Ruin",
		"description": "A ruined checkpoint stands where the road narrows between ditches, its holy banners burned and its wagon overturned. Bodies in scorched mail lie where they fell, but one iron coffer beneath the axle remains unopened.",
		"options": [
			{
				"text": "Force the coffer open.",
				"req_class": "",
				"req_item": "Crowbar",
				"consume_item": false,
				"result_text": "The crowbar wrenches the warped lid free with a metallic scream. Inside lies a stamped brass token of authority the surviving faithful would kill to reclaim.",
				"reward_gold": 55,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/purifier_seal.tres",
				"bonus_unit_name": "Tariq",
				"bonus_result_text": "Tariq reads the seals, the chain of custody, who this would matter to—and who would pay to keep it quiet. He sees the real pressure point before the lid is off. The coffer opens; he already knows what to do with what's inside.",
				"bonus_reward_fame": 25,
				"bonus_reward_gold": 25
			},
			{
				"text": "Study the remains and recover what was being moved.",
				"req_class": "Paladin",
				"req_item": "",
				"result_text": "Your paladin recognizes the checkpoint as a site of sanctioned cruelty, not sanctified duty. Hidden within a false-bottomed travel chest lies a flask of unnaturally clear sacramental oil meant for darker rites.",
				"reward_fame": 35,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/sun_gold_phial.tres",
				"bonus_unit_name": "Celia",
				"bonus_result_text": "Celia studies the remains without flinching. What she sees there—the sanctioned cruelty, the instruments of fear—hardens something in her. She leaves the flask for you to decide; her silence says she has already chosen which side of that order she stands on.",
				"bonus_reward_fame": 45
			},
			{
				"text": "Walk through. Let the ruin see who passes.",
				"req_class": "",
				"req_item": "",
				"result_text": "You do not take the coffer. You do not kneel. You walk through the checkpoint as you are—visible, named. The dead do not rise. The road carries the story anyway.",
				"reward_fame": 5,
				"bonus_unit_name": "Avatar",
				"bonus_result_text": "You walk through. The ruin is silent. The Purifiers who fell here would have marked you for death; the survivors who hear of it will not know what to call you. Heretic, necessity, the one who did not take the seal and did not kneel. You are becoming the legitimacy problem. The road sees you.",
				"bonus_reward_fame": 22
			},
			{
				"text": "Leave before loyalists or scavengers return.",
				"req_class": "",
				"req_item": "",
				"result_text": "You step around the dead and keep moving. The checkpoint rots behind you, as every instrument of fear eventually does.",
				"reward_fame": 0,
				"bonus_unit_name": "Sister Meris",
				"bonus_result_text": "Meris passes the dead without a word. Later she says the checkpoint was the kind of place she once enforced. She does not ask forgiveness; she simply does not raise her blade. The road leaves the ruin behind.",
				"bonus_reward_fame": 10,
				"flag_variants": {
					"salt_road_mercy": { "result_text": "You step around the dead. A wounded man in scorched mail catches your eye—he was at the salt road when you cut the survivor down. He says nothing. He does not raise his blade. The checkpoint rots behind you; the road has not forgotten.", "reward_fame": 15 }
				}
			}
		]
	},
	{
		"id": "smugglers_cistern",
		"region_tag": "league_city",
		"preferred_fame_states": ["mercenary"],
		"fame_variants": {
			"heretic": { "description": "Beneath a ruined customs shed, an old cistern hides fresh footprints and a chained ladder. The League does not welcome your kind here—the cache is for those who can still do business without drawing the wrong kind of attention." },
			"mercenary": { "description": "Beneath a ruined customs shed, an old rain cistern hides fresh footprints and a ladder chained to the wall. In League territory, your reputation is currency: you are useful, deniable, and expected to understand the difference between tax and trade." }
		},
		"title": "Smugglers' Cistern",
		"description": "Beneath a ruined customs shed, an old rain cistern hides fresh footprints, candle drippings, and a ladder chained to the wall. Someone used this place recently to move goods no tax ledger was meant to see.",
		"options": [
			{
				"text": "Pick the chain lock and descend quietly.",
				"req_class": "Thief",
				"req_item": "Lock Picks",
				"consume_item": false,
				"set_flags": ["smuggler_cistern_dealt"],
				"result_text": "The picks slip the corroded lock with barely a click, and the ladder takes you into a cache of coded brass tools and hidden correspondence. Whoever ran this route was moving more than salt and cloth.",
				"reward_gold": 70,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/league_cipher.tres",
				"bonus_unit_name": "Nyx",
				"bonus_result_text": "Nyx has the right words and the right silence. The handoff goes smooth; someone you don't see again leaves a token where the correspondence was. No speeches, no names—the League remembers who can be trusted.",
				"bonus_reward_gold": 90
			},
			{
				"text": "Light the chamber and search every crate.",
				"req_class": "",
				"req_item": "Lantern",
				"consume_item": false,
				"set_flags": ["smuggler_cistern_dealt"],
				"result_text": "The lantern light exposes false-bottomed crates and smuggler marks painted too low for daylight inspection. Tucked behind damp canvas is a compact optical device used for forbidden night runs along the coast.",
				"reward_fame": 10,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/smuggler_lens.tres",
				"bonus_unit_name": "Sabine Varr",
				"bonus_result_text": "Sabine runs the search like a professional. No panic, no chatter—methodical. Whoever ran this route would recognize the type. The League respects competence.",
				"bonus_reward_fame": 22
			},
			{
				"text": "Read the marks and the correspondence before anyone moves a crate.",
				"req_class": "",
				"req_item": "",
				"set_flags": ["smuggler_cistern_dealt"],
				"result_text": "You study the painted marks, the cipher on the scraps, and the chain of custody before touching anything. The right kind of silence and the right kind of knowledge keep the handoff clean.",
				"reward_fame": 15,
				"reward_gold": 35,
				"bonus_unit_name": "Tariq",
				"bonus_result_text": "Tariq reads the room before he reads the papers—who really runs this route, who's bluffing, what would burn whom. He sees the structure under the scene. The deal that follows is precise.",
				"bonus_reward_fame": 28,
				"bonus_reward_gold": 25
			},
			{
				"text": "Ignore the cache and stay on the road.",
				"req_class": "",
				"req_item": "",
				"result_text": "You leave the hidden trade to those reckless enough to profit from it. The road above smells cleaner than the cistern below, even if the kingdom does not.",
				"reward_fame": 5
			}
		]
	},
	{
		"id": "weeping_marsh_reedfield",
		"region_tag": "marsh",
		"preferred_flags": ["freed_marsh_captives", "laid_ferry_dead_to_rest"],
		"fame_variants": {
			"heretic": { "description": "At the edge of the marsh, pale reeds hum with voices that almost form words. The drowned pilgrim camp slumps nearby. The marsh has always welcomed the lost; the reeds do not care what the living call you." },
			"savior": { "description": "At the edge of the marsh, pale reeds hum in the wind with voices that almost form words. Villagers say you quiet the restless and name the dead. The marsh has swallowed many names; they wonder if you will ask for them." }
		},
		"title": "Weeping Marsh Reedfield",
		"description": "At the edge of the marsh, pale reeds hum in the wind with voices that almost form words. A drowned pilgrim's camp slumps nearby, its packs rotted open and its shrine offerings sunk in black water.",
		"options": [
			{
				"text": "Harvest the whispering reeds by lantern light.",
				"req_class": "",
				"req_item": "Lantern",
				"consume_item": false,
				"result_text": "The lantern keeps the party from wandering toward false lights deeper in the bog. You cut a bundle of reeds that sing softly even after they dry, and the marsh answers with uneasy silence.",
				"reward_fame": 15,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/marsh_wisp_reed.tres",
				"flag_variants": {
					"freed_marsh_captives": { "result_text": "The lantern keeps the party from wandering toward false lights. As you cut the reeds, a voice calls from the far bank—one of the souls you freed from the slavers. They leave a small offering at the water's edge and slip away. The marsh remembers.", "reward_fame": 25 }
				}
			},
			{
				"text": "Wade into the ritual pool and gather the flowers whole.",
				"req_class": "Monk",
				"req_item": "",
				"result_text": "Your monk crosses the black water with patient, measured steps and plucks the translucent lilies without breaking their stems. The dead beneath the surface do not rise, but they do not welcome the theft either.",
				"reward_fame": 30,
				"penalty_hp": 8,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/weeping_lily.tres",
				"bonus_unit_name": "Inez",
				"bonus_result_text": "Inez wades in. The marsh stills—not from doctrine, but from the kind of attention that has always been her language. The lilies come away without a struggle; the land has not forgotten who tends it.",
				"bonus_reward_fame": 42,
				"flag_variants": {
					"laid_ferry_dead_to_rest": { "result_text": "Your monk wades in. The dead you laid to rest at the ferry and the souls you freed from the chains have spoken your name in the deep. The water stills; the lilies come away without a struggle. The marsh remembers who gave the nameless peace and who broke the chains.", "reward_fame": 48 },
					"freed_marsh_captives": { "result_text": "Your monk wades in. The freed and the dead have carried your name here. The water stills; the lilies come away without a struggle. The deep remembers who broke the chains.", "reward_fame": 42 }
				}
			},
			{
				"text": "Skirt the marsh before it learns your names.",
				"req_class": "",
				"req_item": "",
				"result_text": "You take the long bank road and leave the reeds to their whispering. Mud still stains your boots by nightfall, but nothing follows you out.",
				"reward_fame": 0
			}
		]
	},
	{
		"id": "cinderscar_orchard",
		"region_tag": "emberwood",
		"title": "Cinderscar Orchard",
		"description": "A burned orchard still stands in rows of black trunks, but a few branches bleed orange resin when cut. Beneath the ash, something fragile and rare has begun to grow where living roots should not.",
		"options": [
			{
				"text": "Use cloth and careful hands to collect the resin.",
				"req_class": "",
				"req_item": "Bandage Roll",
				"consume_item": true,
				"result_text": "The clean cloth keeps the resin from fouling with ash and grit while you harvest it from the cracked bark. The smell clings to your packs like a fire that refuses to die.",
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/emberwood_resin.tres"
			},
			{
				"text": "Search the ash beds for heat-born blossoms.",
				"req_class": "Mage",
				"req_item": "",
				"result_text": "Your mage recognizes where the ground still breathes warmth beneath the cinders and uncovers a flower black as soot, preserved by the very ruin that should have killed it. Few such blooms survive an hour after picking.",
				"reward_fame": 25,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/cinder_bloom.tres"
			},
			{
				"text": "Keep walking before the old fire remembers itself.",
				"req_class": "",
				"req_item": "",
				"result_text": "You leave the orchard to its ash and strange rebirth. The road ahead smells cleaner, but no less haunted.",
				"reward_fame": 0
			}
		]
	},
	{
		"id": "collapsed_watchtower_store",
		"title": "Collapsed Watchtower Store",
		"description": "A frontier watchtower has fallen sideways into its own supply pit, crushing beams, barrels, and a handful of dead sentries beneath the rubble. Somewhere under the stone, a survivor keeps knocking in a slow, weakening rhythm.",
		"options": [
			{
				"text": "Pull the survivor free and tend the crushed limb.",
				"req_class": "",
				"req_item": "Bandage Roll",
				"consume_item": true,
				"result_text": "You drag the sentry out through a gap in the stonework and bind the leg before shock finishes what the collapse began. In gratitude, the survivor hands over a writ hidden from the officers who abandoned the tower weeks ago.",
				"reward_fame": 55,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/edran_grain_writ.tres"
			},
			{
				"text": "Break open the buried supply chest first.",
				"req_class": "",
				"req_item": "Crowbar",
				"consume_item": false,
				"result_text": "The iron bar cracks the chest lid before the knocking stops beneath the rubble. Inside you find preserved food and a bottle of harsh sour liquid prized more by survival than taste.",
				"reward_gold": 35,
				"reward_fame": -45,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Cooking/mead_vinegar.tres"
			},
			{
				"text": "Move on before the remaining masonry shifts.",
				"req_class": "",
				"req_item": "",
				"result_text": "You leave the tower to stone, hunger, and bad leadership. The knocking fades before the next bend in the road.",
				"reward_fame": -35
			}
		]
	},
	{
		"id": "breach_scar_waymarker",
		"title": "Breach-Scar Waymarker",
		"description": "A mile stone near the old war front has melted into glassy black ripples, and the air around it tastes faintly metallic. Travelers avoid the place, claiming their reflections move a heartbeat too slowly beside it.",
		"options": [
			{
				"text": "Examine the warped stone through controlled magic.",
				"req_class": "Spellblade",
				"req_item": "",
				"result_text": "Your spellblade coaxes the unstable residue into stillness long enough to chip away a clean shard. It shows the world slightly wrong when held to the eye, as though the road never fully healed.",
				"reward_fame": 35,
				"penalty_hp": 7,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/veil_glass.tres"
			},
			{
				"text": "Chip through the fused edge with brute persistence.",
				"req_class": "",
				"req_item": "Pick Hammer",
				"consume_item": false,
				"result_text": "The pick rings against the warped waymarker until a pocket of breach residue breaks loose in a spill of black dust. The powder hisses when it touches rainwater and belongs nowhere near sane hands.",
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/night_of_cinders.tres"
			},
			{
				"text": "Give the scarred stone a wide berth.",
				"req_class": "",
				"req_item": "",
				"result_text": "You refuse whatever curiosity ruined better people than you. The company marches past without speaking until the air tastes normal again.",
				"reward_fame": 5
			}
		]
	},
	{
		"id": "crypt_gargoyle_perch",
		"title": "Crypt Gargoyle Perch",
		"description": "A ruined mausoleum roof has collapsed, leaving a stone gargoyle half-buried but intact enough to glower over the entrance. Claw marks gouge the crypt arch, and a dark stain runs from the statue's beak like old rain or older blood.",
		"options": [
			{
				"text": "Break the statue apart and salvage the strongest piece.",
				"req_class": "",
				"req_item": "Pick Hammer",
				"consume_item": false,
				"result_text": "Repeated blows split the black stone along an old weakness line, and one claw comes free with unnatural weight. Something in the crypt below stirs once, then falls silent again.",
				"reward_fame": -10,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/gargoyle_talon.tres"
			},
			{
				"text": "Read the ward-lines instead of smashing them.",
				"req_class": "Mage",
				"req_item": "",
				"result_text": "Your mage identifies the gargoyle as part sentinel, part seal, built to watch something beneath rather than keep thieves out. Hidden in the lintel above the door is a bronze token of a long-dead order placed there to reinforce the ward.",
				"reward_fame": 30,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/dawn_sigil.tres",
				"bonus_unit_name": "Sorrel",
				"bonus_result_text": "Sorrel doesn't smash. They read the script, the sequence, what the ward was actually for—and explain it to everyone else so the fear goes quiet. Knowledge rescuing people from bad interpretation. The token is in hand; the crypt stays sealed.",
				"bonus_reward_fame": 42
			},
			{
				"text": "Avoid the mausoleum entirely.",
				"req_class": "",
				"req_item": "",
				"result_text": "You let the gargoyle keep watch over whatever remains below. Some doors are safer closed, even when they promise wealth.",
				"reward_fame": 10
			}
		]
	},
	{
		"id": "deserters_snow_camp",
		"title": "Deserters' Snow Camp",
		"description": "In a hollow shielded from the wind, a dead camp lies beneath fresh snow and torn canvas. The fire pit is cold, but footprints show someone fled in haste, leaving gear and a blood-dark trail toward the pines.",
		"options": [
			{
				"text": "Search the abandoned packs for stores worth carrying.",
				"req_class": "",
				"req_item": "Tent Cloth",
				"consume_item": false,
				"result_text": "Using the cloth to wrap frozen goods and keep them from splitting open in the cold, you salvage preserved food that would otherwise spoil by morning. The camp tells a hard story, but not a complete one.",
				"reward_gold": 20,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Cooking/dried_sausage.tres"
			},
			{
				"text": "Follow the blood trail and recover the deserter's satchel.",
				"req_class": "Archer",
				"req_item": "",
				"result_text": "Your archer tracks the staggered prints to a pine break where wolves finished what the war began. The satchel remains untouched beneath the corpse, carrying a coded levy record no officer meant common eyes to see.",
				"reward_fame": 20,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/knight_tax_roll.tres"
			},
			{
				"text": "Leave the snow to bury their shame.",
				"req_class": "",
				"req_item": "",
				"result_text": "You stamp out no fresh trail and disturb no dead men. By morning the hollow will look untouched from the road above.",
				"reward_fame": 0
			}
		]
	},
	{
		"id": "broken_abbey_reliquary",
		"region_tag": "order_ruins",
		"preferred_fame_states": ["savior"],
		"preferred_flags": ["feast_vigil_kept", "bound_oathbreaker"],
		"blocked_flags": ["desecrated_bell_chapel"],
		"fame_variants": {
			"heretic": { "description": "A broken abbey reliquary stands open to the wind. The faithful who still tend the ruins will not let you enter. They say the relics inside are not for your kind—that you would defile what the war could not." },
			"savior": { "description": "A broken abbey reliquary stands open to the wind. The brothers who remain have heard your name. They step aside at the door; they ask only that you treat what lies within as the dead would wish." }
		},
		"title": "Broken Abbey Reliquary",
		"description": "A shelled abbey clings to a hillside, its choir roof gone and its reliquary chamber split open by siege fire. Beneath fallen beams, a metal casket glints amid bones and old incense ash.",
		"options": [
			{
				"text": "Lift the beam and recover the casket by strength alone.",
				"req_class": "Knight",
				"req_item": "",
				"result_text": "Your knight heaves the timber high enough for others to drag the reliquary free before the rubble shifts again. The abbey offers no blessing for the theft, but the old order has few hands left to protest.",
				"reward_fame": 10,
				"penalty_hp": 10,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/greyspire_reliquary.tres"
			},
			{
				"text": "Brace the wreckage with rope and work slowly.",
				"req_class": "",
				"req_item": "Rope Coil",
				"consume_item": false,
				"result_text": "The rope keeps the broken frame from collapsing long enough to reach the chamber safely. Behind the casket, hidden in a crack where heat could not touch it, lies a sharpened relic fragment of greater worth than any silver box.",
				"reward_fame": 25,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/moonsteel_shard.tres",
				"bonus_unit_name": "Sorrel",
				"bonus_result_text": "Sorrel reads the stress lines, the order of collapse—which beam to brace first so the rest holds. They don't guess. The chamber is reached without bringing the choir down. Insight rescuing people from fear.",
				"bonus_reward_fame": 38
			},
			{
				"text": "Enter and let the brothers see who has come.",
				"req_class": "",
				"req_item": "",
				"result_text": "You step through the broken door without taking anything. The remaining brothers watch in silence. They do not bless you; they do not bar you. They simply see.",
				"reward_fame": 12,
				"bonus_unit_name": "Avatar",
				"bonus_result_text": "You enter. The brothers stop. They are not looking at your blade or your banner—they are looking at you. Symbol, danger, shelter, the one the road has been naming. They do not offer a blessing. One of them says, quietly, that they have heard what you are becoming. They step aside. You leave the reliquary untouched. The weight of their gaze stays with you.",
				"bonus_reward_fame": 32
			},
			{
				"text": "Bow once and leave the abbey to ruin.",
				"req_class": "",
				"req_item": "",
				"result_text": "You take nothing from the broken sanctuary and ask nothing of it in return. The wind through the empty choir sounds almost like approval.",
				"reward_fame": 15,
				"bonus_unit_name": "Liora",
				"bonus_result_text": "Liora bows with the rest—but when she rises, one of the remaining brothers meets her eyes. He does not bless the relic; he says the abbey has heard of the vigil at the feast and the mercy on the salt road. What they honor is not the institution she left. It is the faith she is building in its place. The wind through the choir sounds like approval.",
				"bonus_reward_fame": 35,
				"flag_variants": {
					"bound_oathbreaker": { "result_text": "You bow and turn to leave. One of the remaining brothers has heard how you bound the oathbreaker's cairn—he presses a small blessing into your hand and says the dead have long memories. The wind through the choir sounds like approval.", "reward_fame": 30 },
					"feast_vigil_kept": { "result_text": "You bow once. The brothers have heard of the vigil you kept at the feast of hollow masks. They do not ask you to take anything; they only nod as you go. The road has carried your name here.", "reward_fame": 28 }
				}
			}
		]
	},
	{
		"id": "ash_cart_heretics",
		"title": "Ash Cart of the Heretics",
		"description": "A burnt prison cart sits alone beside the road, its wheels half sunk in mud and its cage split from within. Inside, amid the chains and grey ash, someone left behind a packet of notes, a cracked vial, and a smell of ritual smoke.",
		"options": [
			{
				"text": "Search the cage with a steady light.",
				"req_class": "",
				"req_item": "Lantern",
				"consume_item": false,
				"result_text": "The lantern reveals hidden writing beneath soot and boot marks, enough to identify the prisoners as more useful to their captors alive than dead. Among the ashes rests a surviving catechism copied in a cramped novice hand.",
				"reward_fame": 10,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/ash_catechism.tres"
			},
			{
				"text": "Use your knowledge of blood rites to identify the residue.",
				"req_class": "Mage",
				"req_item": "",
				"result_text": "Your mage recognizes ritual ink, preservation salts, and the signs of interrupted communion rather than simple execution. Beneath the bench a stoppered phial remains wedged in place, overlooked in the rush of fire and escape.",
				"reward_fame": 20,
				"reward_item_path": "res://Resources/Materials/GeneratedMaterials/Lore_And_Misc/binders_phial.tres"
			},
			{
				"text": "Leave the cart and its secrets to the crows.",
				"req_class": "",
				"req_item": "",
				"result_text": "You walk on without disturbing whatever history burned here. The road has enough ghosts already.",
				"reward_fame": 0
			}
		]
	}
]
