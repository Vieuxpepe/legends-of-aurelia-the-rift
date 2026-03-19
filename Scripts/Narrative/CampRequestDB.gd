# CampRequestDB.gd
# Data-driven camp requests for Explore Camp v1: offer generation, personality-based flavor text.
# Request types: item_delivery, talk_to_unit. One active request at a time.
# Per-character profiles (CHARACTER_REQUEST_PROFILES) override personality for type, targets, and flavor.

class_name CampRequestDB

# Content bank: ensure in scope for static lookups (class_name load order can vary).
const ContentDB = preload("res://Scripts/Narrative/CampRequestContentDB.gd")

const TYPE_ITEM_DELIVERY: String = "item_delivery"
const TYPE_TALK_TO_UNIT: String = "talk_to_unit"

# Preference keys: strongly_talk, talk, balanced_talk, balanced, balanced_item, item, strongly_item
const PREF_STRONGLY_TALK: String = "strongly_talk"
const PREF_TALK: String = "talk"
const PREF_BALANCED_TALK: String = "balanced_talk"
const PREF_BALANCED: String = "balanced"
const PREF_BALANCED_ITEM: String = "balanced_item"
const PREF_ITEM: String = "item"
const PREF_STRONGLY_ITEM: String = "strongly_item"

# Item theme tags for flavor (inventory does not filter by tag yet; used for title/description tone).
const ITEM_TAG_MAINTENANCE: String = "maintenance"
const ITEM_TAG_PROVISIONS: String = "provisions"
const ITEM_TAG_HEALING: String = "healing"
const ITEM_TAG_REAGENTS: String = "reagents"
const ITEM_TAG_TOOLS: String = "tools"
const ITEM_TAG_MORALE: String = "morale"
const ITEM_TAG_RECORDS: String = "records"
const ITEM_TAG_FORTIFICATION: String = "fortification"
const ITEM_TAG_ANIMAL_CARE: String = "animal_care"
const ITEM_TAG_RITUAL: String = "ritual"

# Per-character request profiles: type weights, item_tags, preferred/avoided talk targets, title_style, motive_tags, signature_request_bias.
# Keys: unit_name. Fallback: personality then neutral.
const CHARACTER_REQUEST_PROFILES: Dictionary = {
	"Commander": {
		"preference": PREF_TALK,
		"request_type_weights": {"item_delivery": 1, "talk_to_unit": 2},
		"item_tags": [ITEM_TAG_PROVISIONS, ITEM_TAG_MORALE],
		"preferred_targets": [],
		"avoided_targets": [],
		"voice_style": "direct",
		"motive_tags": ["unity", "readiness"],
		"title_style": "direct_practical",
		"warmth_growth": "steady",
		"signature_request_bias": "quiet_tasks",
	},
	"Kaelen": {
		"preference": PREF_STRONGLY_ITEM,
		"request_type_weights": {"item_delivery": 3, "talk_to_unit": 1},
		"item_tags": [ITEM_TAG_MAINTENANCE, ITEM_TAG_PROVISIONS, ITEM_TAG_TOOLS],
		"preferred_targets": [],
		"avoided_targets": [],
		"voice_style": "blunt",
		"motive_tags": ["upkeep", "training", "rations"],
		"title_style": "blunt_practical",
		"warmth_growth": "slow",
		"signature_request_bias": "upkeep",
	},
	"Branik": {
		"preference": PREF_BALANCED_TALK,
		"request_type_weights": {"item_delivery": 1, "talk_to_unit": 2},
		"item_tags": [ITEM_TAG_PROVISIONS, ITEM_TAG_MORALE],
		"preferred_targets": ["Liora", "Pell Rowan", "Tamsin Reed"],
		"avoided_targets": [],
		"voice_style": "warm",
		"motive_tags": ["comfort", "vulnerable_check"],
		"title_style": "warm_practical",
		"warmth_growth": "warm",
		"signature_request_bias": "camp_comfort",
	},
	"Liora": {
		"preference": PREF_STRONGLY_TALK,
		"request_type_weights": {"item_delivery": 1, "talk_to_unit": 3},
		"item_tags": [ITEM_TAG_HEALING, ITEM_TAG_REAGENTS],
		"preferred_targets": ["Tamsin Reed", "Brother Alden", "Maela Thorn"],
		"avoided_targets": [],
		"voice_style": "caring",
		"motive_tags": ["herbs", "wellness", "spiritual"],
		"title_style": "caring_restorative",
		"warmth_growth": "warm",
		"signature_request_bias": "wellness_check",
	},
	"Nyx": {
		"preference": PREF_STRONGLY_TALK,
		"request_type_weights": {"item_delivery": 1, "talk_to_unit": 3},
		"item_tags": [ITEM_TAG_RECORDS, ITEM_TAG_REAGENTS],
		"preferred_targets": ["Tariq", "Corvin Ash", "Sabine Varr"],
		"avoided_targets": [],
		"voice_style": "sly",
		"motive_tags": ["information", "sounding_out", "suspicious"],
		"title_style": "suspicious_indirect",
		"warmth_growth": "guarded",
		"signature_request_bias": "read_mood",
	},
	"Sorrel": {
		"preference": PREF_STRONGLY_ITEM,
		"request_type_weights": {"item_delivery": 3, "talk_to_unit": 1},
		"item_tags": [ITEM_TAG_RECORDS, ITEM_TAG_REAGENTS, ITEM_TAG_TOOLS],
		"preferred_targets": ["Oren Pike", "Corvin Ash"],
		"avoided_targets": [],
		"voice_style": "scholarly",
		"motive_tags": ["notes", "samples", "technical"],
		"title_style": "scholarly_technical",
		"warmth_growth": "professional",
		"signature_request_bias": "notes_reagents",
	},
	"Darian": {
		"preference": PREF_STRONGLY_TALK,
		"request_type_weights": {"item_delivery": 1, "talk_to_unit": 3},
		"item_tags": [ITEM_TAG_MORALE],
		"preferred_targets": ["Yselle Maris", "Maela Thorn", "Hest \"Sparks\""],
		"avoided_targets": [],
		"voice_style": "flamboyant",
		"motive_tags": ["morale", "social_repair", "messages"],
		"title_style": "elegant_social",
		"warmth_growth": "expressive",
		"signature_request_bias": "social_errands",
	},
	"Celia": {
		"preference": PREF_STRONGLY_ITEM,
		"request_type_weights": {"item_delivery": 3, "talk_to_unit": 1},
		"item_tags": [ITEM_TAG_MAINTENANCE, ITEM_TAG_TOOLS, ITEM_TAG_FORTIFICATION],
		"preferred_targets": ["Garrick Vale", "Veska Moor"],
		"avoided_targets": [],
		"voice_style": "disciplined",
		"motive_tags": ["gear", "discipline", "quiet_protection"],
		"title_style": "disciplined_quiet",
		"warmth_growth": "reserved",
		"signature_request_bias": "gear_order",
	},
	"Rufus": {
		"preference": PREF_STRONGLY_ITEM,
		"request_type_weights": {"item_delivery": 3, "talk_to_unit": 1},
		"item_tags": [ITEM_TAG_TOOLS, ITEM_TAG_REAGENTS, ITEM_TAG_PROVISIONS],
		"preferred_targets": ["Oren Pike"],
		"avoided_targets": [],
		"voice_style": "pragmatic",
		"motive_tags": ["tools", "powder", "parts", "labor"],
		"title_style": "irritated_practical",
		"warmth_growth": "matter_of_fact",
		"signature_request_bias": "tools_parts",
	},
	"Inez": {
		"preference": PREF_BALANCED_TALK,
		"request_type_weights": {"item_delivery": 2, "talk_to_unit": 2},
		"item_tags": [ITEM_TAG_ANIMAL_CARE, ITEM_TAG_FORTIFICATION, ITEM_TAG_PROVISIONS],
		"preferred_targets": ["Veska Moor", "Garrick Vale"],
		"avoided_targets": [],
		"voice_style": "wild",
		"motive_tags": ["animals", "watch", "edges", "territorial"],
		"title_style": "territorial_caution",
		"warmth_growth": "earned",
		"signature_request_bias": "watch_lines",
	},
	"Tariq": {
		"preference": PREF_TALK,
		"request_type_weights": {"item_delivery": 1, "talk_to_unit": 2},
		"item_tags": [ITEM_TAG_RECORDS, ITEM_TAG_REAGENTS],
		"preferred_targets": ["Corvin Ash", "Sorrel", "Nyx"],
		"avoided_targets": [],
		"voice_style": "sardonic",
		"motive_tags": ["notes", "clarifications", "pointed", "arcane"],
		"title_style": "pointed_arcane",
		"warmth_growth": "guarded",
		"signature_request_bias": "pointed_conversations",
	},
	"Mira Ashdown": {
		"preference": PREF_TALK,
		"request_type_weights": {"item_delivery": 1, "talk_to_unit": 2},
		"item_tags": [ITEM_TAG_PROVISIONS, ITEM_TAG_FORTIFICATION],
		"preferred_targets": ["Kaelen", "Garrick Vale"],
		"avoided_targets": [],
		"voice_style": "quiet",
		"motive_tags": ["quiet_tasks", "patrol", "careful_check"],
		"title_style": "quiet_patrol",
		"warmth_growth": "steady",
		"signature_request_bias": "quiet_tasks",
	},
	"Pell Rowan": {
		"preference": PREF_TALK,
		"request_type_weights": {"item_delivery": 2, "talk_to_unit": 2},
		"item_tags": [ITEM_TAG_PROVISIONS, ITEM_TAG_TOOLS],
		"preferred_targets": ["Branik", "Tamsin Reed"],
		"avoided_targets": [],
		"voice_style": "earnest",
		"motive_tags": ["prove_useful", "eager"],
		"title_style": "earnest_help",
		"warmth_growth": "open",
		"signature_request_bias": "prove_useful",
	},
	"Tamsin Reed": {
		"preference": PREF_STRONGLY_TALK,
		"request_type_weights": {"item_delivery": 2, "talk_to_unit": 3},
		"item_tags": [ITEM_TAG_HEALING, ITEM_TAG_REAGENTS],
		"preferred_targets": ["Liora", "Brother Alden", "Pell Rowan"],
		"avoided_targets": [],
		"voice_style": "compassionate",
		"motive_tags": ["herbal", "bandages", "wellness"],
		"title_style": "caring_restorative",
		"warmth_growth": "warm",
		"signature_request_bias": "wellness_check",
	},
	"Hest \"Sparks\"": {
		"preference": PREF_BALANCED,
		"request_type_weights": {"item_delivery": 2, "talk_to_unit": 2},
		"item_tags": [ITEM_TAG_PROVISIONS, ITEM_TAG_REAGENTS],
		"preferred_targets": ["Darian", "Maela Thorn"],
		"avoided_targets": [],
		"voice_style": "chaotic",
		"motive_tags": ["gossip", "missing_items", "chaotic"],
		"title_style": "chaotic_errand",
		"warmth_growth": "chaotic",
		"signature_request_bias": "chaotic_errands",
	},
	"Brother Alden": {
		"preference": PREF_BALANCED_TALK,
		"request_type_weights": {"item_delivery": 1, "talk_to_unit": 2},
		"item_tags": [ITEM_TAG_PROVISIONS, ITEM_TAG_HEALING],
		"preferred_targets": ["Liora", "Tamsin Reed", "Sabine Varr"],
		"avoided_targets": [],
		"voice_style": "devout",
		"motive_tags": ["mediation", "welfare", "practical_aid"],
		"title_style": "calm_welfare",
		"warmth_growth": "peaceful",
		"signature_request_bias": "mediation",
	},
	"Oren Pike": {
		"preference": PREF_STRONGLY_ITEM,
		"request_type_weights": {"item_delivery": 3, "talk_to_unit": 1},
		"item_tags": [ITEM_TAG_TOOLS, ITEM_TAG_MAINTENANCE, ITEM_TAG_REAGENTS],
		"preferred_targets": ["Rufus", "Sorrel"],
		"avoided_targets": [],
		"voice_style": "pragmatic",
		"motive_tags": ["tools", "components", "maintenance"],
		"title_style": "irritated_practical",
		"warmth_growth": "grudging",
		"signature_request_bias": "tools_components",
	},
	"Garrick Vale": {
		"preference": PREF_STRONGLY_ITEM,
		"request_type_weights": {"item_delivery": 2, "talk_to_unit": 2},
		"item_tags": [ITEM_TAG_FORTIFICATION, ITEM_TAG_MAINTENANCE, ITEM_TAG_RECORDS],
		"preferred_targets": ["Veska Moor", "Celia", "Sabine Varr"],
		"avoided_targets": [],
		"voice_style": "disciplined",
		"motive_tags": ["patrol", "order", "protocol", "duty"],
		"title_style": "duty_protocol",
		"warmth_growth": "professional",
		"signature_request_bias": "duty_conversations",
	},
	"Sabine Varr": {
		"preference": PREF_ITEM,
		"request_type_weights": {"item_delivery": 2, "talk_to_unit": 1},
		"item_tags": [ITEM_TAG_FORTIFICATION, ITEM_TAG_TOOLS, ITEM_TAG_RECORDS],
		"preferred_targets": ["Garrick Vale", "Veska Moor"],
		"avoided_targets": [],
		"voice_style": "severe",
		"motive_tags": ["defenses", "vulnerabilities", "logistics"],
		"title_style": "competent_logistics",
		"warmth_growth": "reserved",
		"signature_request_bias": "defenses_logistics",
	},
	"Yselle Maris": {
		"preference": PREF_STRONGLY_TALK,
		"request_type_weights": {"item_delivery": 1, "talk_to_unit": 3},
		"item_tags": [ITEM_TAG_MORALE],
		"preferred_targets": ["Darian", "Maela Thorn", "Hest \"Sparks\""],
		"avoided_targets": [],
		"voice_style": "flamboyant",
		"motive_tags": ["morale", "rumors", "delicate_social"],
		"title_style": "elegant_social",
		"warmth_growth": "expressive",
		"signature_request_bias": "social_errands",
	},
	"Sister Meris": {
		"preference": PREF_ITEM,
		"request_type_weights": {"item_delivery": 2, "talk_to_unit": 2},
		"item_tags": [ITEM_TAG_RECORDS, ITEM_TAG_HEALING],
		"preferred_targets": ["Brother Alden", "Sabine Varr"],
		"avoided_targets": [],
		"voice_style": "severe",
		"motive_tags": ["discipline", "records", "difficult_conversations"],
		"title_style": "discipline_records",
		"warmth_growth": "stern",
		"signature_request_bias": "discipline_conversations",
	},
	"Corvin Ash": {
		"preference": PREF_TALK,
		"request_type_weights": {"item_delivery": 2, "talk_to_unit": 2},
		"item_tags": [ITEM_TAG_REAGENTS, ITEM_TAG_RECORDS, ITEM_TAG_RITUAL],
		"preferred_targets": ["Tariq", "Sorrel", "Nyx"],
		"avoided_targets": [],
		"voice_style": "occult",
		"motive_tags": ["reagents", "notes", "cursed_oddities", "consultation"],
		"title_style": "unsettling_consultation",
		"warmth_growth": "measured",
		"signature_request_bias": "arcane_consultation",
	},
	"Veska Moor": {
		"preference": PREF_STRONGLY_ITEM,
		"request_type_weights": {"item_delivery": 3, "talk_to_unit": 1},
		"item_tags": [ITEM_TAG_FORTIFICATION, ITEM_TAG_MAINTENANCE, ITEM_TAG_TOOLS],
		"preferred_targets": ["Garrick Vale", "Celia"],
		"avoided_targets": [],
		"voice_style": "stoic",
		"motive_tags": ["fortification", "drills", "reliability"],
		"title_style": "fortification_drills",
		"warmth_growth": "steady",
		"signature_request_bias": "fortification",
	},
	"Ser Hadrien": {
		"preference": PREF_TALK,
		"request_type_weights": {"item_delivery": 1, "talk_to_unit": 3},
		"item_tags": [ITEM_TAG_RECORDS, ITEM_TAG_RITUAL],
		"preferred_targets": ["Brother Alden", "Liora"],
		"avoided_targets": [],
		"voice_style": "haunted",
		"motive_tags": ["memory", "oaths", "solemn_check"],
		"title_style": "solemn_oath",
		"warmth_growth": "heavy",
		"signature_request_bias": "solemn_check",
	},
	"Maela Thorn": {
		"preference": PREF_STRONGLY_TALK,
		"request_type_weights": {"item_delivery": 1, "talk_to_unit": 3},
		"item_tags": [ITEM_TAG_MORALE, ITEM_TAG_PROVISIONS],
		"preferred_targets": ["Yselle Maris", "Darian", "Hest \"Sparks\""],
		"avoided_targets": [],
		"voice_style": "spirited",
		"motive_tags": ["messenger", "movement", "competitive"],
		"title_style": "kinetic_competitive",
		"warmth_growth": "bright",
		"signature_request_bias": "messenger_errands",
	},
}

# Character-specific request type preference (overrides personality default); kept for fallback when profile has no preference.
const UNIT_PREFERENCE: Dictionary = {
	"Commander": PREF_TALK,
	"Kaelen": PREF_STRONGLY_ITEM,
	"Branik": PREF_BALANCED_TALK,
	"Liora": PREF_STRONGLY_TALK,
	"Nyx": PREF_STRONGLY_TALK,
	"Sorrel": PREF_STRONGLY_ITEM,
	"Darian": PREF_STRONGLY_TALK,
	"Celia": PREF_STRONGLY_ITEM,
	"Rufus": PREF_STRONGLY_ITEM,
	"Inez": PREF_BALANCED_TALK,
	"Tariq": PREF_TALK,
	"Mira Ashdown": PREF_TALK,
	"Pell Rowan": PREF_TALK,
	"Tamsin Reed": PREF_STRONGLY_TALK,
	"Hest \"Sparks\"": PREF_BALANCED,
	"Brother Alden": PREF_BALANCED_TALK,
	"Oren Pike": PREF_STRONGLY_ITEM,
	"Garrick Vale": PREF_STRONGLY_ITEM,
	"Sabine Varr": PREF_ITEM,
	"Yselle Maris": PREF_STRONGLY_TALK,
	"Sister Meris": PREF_ITEM,
	"Corvin Ash": PREF_TALK,
	"Veska Moor": PREF_STRONGLY_ITEM,
	"Ser Hadrien": PREF_TALK,
	"Maela Thorn": PREF_STRONGLY_TALK,
}

# Personality default preference when unit has no override.
const PERSONALITY_DEFAULT_PREFERENCE: Dictionary = {
	"heroic": PREF_TALK,
	"stoic": PREF_STRONGLY_ITEM,
	"warm": PREF_BALANCED_TALK,
	"compassionate": PREF_STRONGLY_TALK,
	"sly": PREF_STRONGLY_TALK,
	"scholarly": PREF_STRONGLY_ITEM,
	"flamboyant": PREF_STRONGLY_TALK,
	"disciplined": PREF_STRONGLY_ITEM,
	"pragmatic": PREF_STRONGLY_ITEM,
	"wild": PREF_BALANCED_TALK,
	"sardonic": PREF_TALK,
	"earnest": PREF_TALK,
	"chaotic": PREF_BALANCED,
	"devout": PREF_BALANCED_TALK,
	"severe": PREF_ITEM,
	"occult": PREF_TALK,
	"haunted": PREF_TALK,
	"spirited": PREF_STRONGLY_TALK,
	"neutral": PREF_BALANCED,
}

## Returns personality for unit using same priority as CampExploreDialogueDB.
static func get_personality(unit_data: Variant, unit_name: String) -> String:
	return CampExploreDialogueDB.get_personality_for_unit(unit_data, unit_name)

## Returns character request profile dict or {} if none. Keys: preference, request_type_weights, item_tags, preferred_targets, avoided_targets, voice_style, motive_tags, title_style, warmth_growth, signature_request_bias.
static func get_profile(unit_name: String) -> Dictionary:
	var key: String = str(unit_name).strip_edges()
	return CHARACTER_REQUEST_PROFILES.get(key, {})

## Returns request type preference: profile.preference first, then UNIT_PREFERENCE, then personality default.
static func get_request_type_preference(unit_name: String, personality: String) -> String:
	var prof: Dictionary = get_profile(unit_name)
	if prof.get("preference", "").length() > 0:
		return str(prof["preference"])
	var key: String = str(unit_name).strip_edges()
	if key in UNIT_PREFERENCE:
		return UNIT_PREFERENCE[key]
	var p: String = str(personality).strip_edges().to_lower()
	if p.is_empty():
		p = "neutral"
	return PERSONALITY_DEFAULT_PREFERENCE.get(p, PREF_BALANCED)

## Returns a request offer dict or {}. Only one active request; if cm has active request, caller should not call.
## Uses profile (type weights, preferred/avoided targets) then preference; fixed rewards per spec.
## giver_tier: Avatar relationship tier ("close"/"bonded" => deep request). personal_quest_eligible: try personal quest first.
static func get_offer(giver_name: String, giver_personality: String, roster_names: Array, item_candidates: Array, has_active_request: bool, giver_tier: String = "", personal_quest_eligible: bool = false) -> Dictionary:
	if has_active_request or giver_name.is_empty():
		return {}
	# Personal quest takes the one-offer slot when eligible.
	if personal_quest_eligible:
		var personal_offer: Dictionary = ContentDB.get_personal_quest_offer(giver_name, roster_names, item_candidates)
		if not personal_offer.is_empty():
			return personal_offer
	var personality: String = giver_personality.strip_edges().to_lower()
	if personality.is_empty():
		personality = "neutral"
	var prof: Dictionary = get_profile(giver_name)
	var other_names: Array = []
	for n in roster_names:
		var s: String = str(n).strip_edges()
		if s != "" and s != giver_name:
			other_names.append(s)
	var avoided: Array = prof.get("avoided_targets", [])
	var allowed_talk: Array = []
	for n in other_names:
		if n in avoided:
			continue
		allowed_talk.append(n)
	var can_talk: bool = allowed_talk.size() >= 1
	var can_item: bool = item_candidates.size() > 0
	var request_type: String = ""
	var target_name: String = ""
	var target_amount: int = 0
	var seed_h: int = giver_name.hash()
	var weights: Dictionary = prof.get("request_type_weights", {})
	var w_item: int = int(weights.get(TYPE_ITEM_DELIVERY, 1))
	var w_talk: int = int(weights.get(TYPE_TALK_TO_UNIT, 1))
	var pref: String = get_request_type_preference(giver_name, personality)
	if can_talk and can_item:
		if weights.size() > 0:
			var total: int = w_item + w_talk
			if total <= 0:
				total = 1
			var roll: int = abs(seed_h) % total
			if roll < w_talk:
				request_type = TYPE_TALK_TO_UNIT
				target_name = _pick_talk_target(giver_name, allowed_talk, prof, seed_h)
			else:
				request_type = TYPE_ITEM_DELIVERY
				target_name = item_candidates[abs(seed_h + 1) % item_candidates.size()]
				target_amount = clampi(1 + (abs(seed_h + 2) % 3), 1, 3)
		else:
			if pref == PREF_STRONGLY_TALK or pref == PREF_TALK:
				request_type = TYPE_TALK_TO_UNIT
				target_name = _pick_talk_target(giver_name, allowed_talk, prof, seed_h)
			elif pref == PREF_STRONGLY_ITEM or pref == PREF_ITEM:
				request_type = TYPE_ITEM_DELIVERY
				target_name = item_candidates[abs(seed_h + 1) % item_candidates.size()]
				target_amount = clampi(1 + (abs(seed_h + 2) % 3), 1, 3)
			else:
				if (abs(seed_h) % 2) == 0:
					request_type = TYPE_TALK_TO_UNIT
					target_name = _pick_talk_target(giver_name, allowed_talk, prof, seed_h + 2)
				else:
					request_type = TYPE_ITEM_DELIVERY
					target_name = item_candidates[abs(seed_h + 3) % item_candidates.size()]
					target_amount = clampi(1 + (abs(seed_h + 4) % 3), 1, 3)
	elif can_talk:
		request_type = TYPE_TALK_TO_UNIT
		target_name = _pick_talk_target(giver_name, allowed_talk, prof, seed_h)
	elif can_item:
		request_type = TYPE_ITEM_DELIVERY
		target_name = item_candidates[abs(seed_h) % item_candidates.size()]
		target_amount = clampi(1 + (abs(seed_h + 1) % 3), 1, 3)
	else:
		return {}
	if request_type == TYPE_ITEM_DELIVERY and target_amount <= 0:
		target_amount = 1
	if request_type == TYPE_TALK_TO_UNIT and (target_name.is_empty() or target_name == giver_name):
		if allowed_talk.size() > 0:
			target_name = allowed_talk[abs(seed_h) % allowed_talk.size()]
		else:
			return {}
	var tier: String = str(giver_tier).strip_edges().to_lower()
	var is_deep: bool = (tier == "close" or tier == "bonded")
	if is_deep and request_type == TYPE_ITEM_DELIVERY and target_amount < 3:
		target_amount = mini(target_amount + 1, 3)
	var depth: String = "deep" if is_deep else "normal"
	# Deep/personal requests get character-specific flavor; normal requests use personality/voice/neutral only.
	var flavor_name: String = giver_name if depth != "normal" else ""
	var title: String = _get_offer_title(request_type, personality, flavor_name, prof)
	var desc: String = _get_offer_description(request_type, personality, target_name, target_amount, flavor_name, prof)
	var reward_gold: int = _get_reward_gold(request_type, target_amount, depth)
	var reward_affinity: int = _get_reward_affinity(request_type, target_amount, depth)
	var payload: Dictionary = {}
	if request_type == TYPE_TALK_TO_UNIT:
		var bias: String = str(prof.get("signature_request_bias", "")).strip_edges()
		if bias in ContentDB.BRANCHING_BIASES:
			payload["branching_check"] = true
			payload["challenge_style"] = bias
			payload["challenge_id"] = "%s_%s_%d" % [giver_name, target_name, seed_h]
			payload["failure_on_wrong"] = true
	return {
		"type": request_type,
		"target_name": target_name,
		"target_amount": target_amount,
		"title": title,
		"description": desc,
		"reward_gold": reward_gold,
		"reward_affinity": reward_affinity,
		"payload": payload,
		"request_depth": depth,
	}

## Picks talk target: preferred_targets in roster first, then fallback from allowed list. Never self.
static func _pick_talk_target(giver_name: String, allowed: Array, prof: Dictionary, seed_h: int) -> String:
	if allowed.is_empty():
		return ""
	var preferred: Array = prof.get("preferred_targets", [])
	for p in preferred:
		var s: String = str(p).strip_edges()
		if s != "" and s != giver_name and s in allowed:
			return s
	return allowed[abs(seed_h) % allowed.size()]

# Title style -> short titles per request type (item_delivery / talk_to_unit). Used when profile has title_style.
const TITLE_BY_STYLE: Dictionary = {
	"blunt_practical": {"item_delivery": ["Need supplies.", "Equipment upkeep.", "Rations or parts."], "talk_to_unit": ["A word with someone.", "Check on them.", "Training correction."]},
	"caring_restorative": {"item_delivery": ["Herbs or bandages?", "Something for the infirmary.", "Tea or remedies."], "talk_to_unit": ["Check on them for me.", "See how they're holding up.", "A gentle word."]},
	"suspicious_indirect": {"item_delivery": ["A few things.", "Information in kind.", "Samples."], "talk_to_unit": ["Sound them out.", "Read the room.", "See where they stand."]},
	"scholarly_technical": {"item_delivery": ["Notes or reagents.", "Samples needed.", "Technical question."], "talk_to_unit": ["Ask them something.", "Clarify a point.", "Get their read."]},
	"elegant_social": {"item_delivery": ["A small token.", "For morale."], "talk_to_unit": ["A message, if you would.", "Smooth something over.", "Delicate matter."]},
	"irritated_practical": {"item_delivery": ["Tools. Parts.", "Components.", "Don't ask."], "talk_to_unit": ["Talk to them.", "Sort it out."]},
	"solemn_oath": {"item_delivery": ["Something I need.", "For the record."], "talk_to_unit": ["A solemn check.", "See they're steady.", "Word with them."]},
	"kinetic_competitive": {"item_delivery": ["Quick favor.", "Run something."], "talk_to_unit": ["Pass a message.", "Light a fire under them.", "See they're moving."]},
	"warm_practical": {"item_delivery": ["Comforts for camp.", "Something warm."], "talk_to_unit": ["Check on someone.", "See they're alright.", "A kind word."]},
	"quiet_patrol": {"item_delivery": ["Quiet request.", "Patrol concern."], "talk_to_unit": ["Careful check.", "See they're okay."]},
	"earnest_help": {"item_delivery": ["Could you help?", "I can be useful."], "talk_to_unit": ["Help me out?", "Ask them for me?"]},
	"chaotic_errand": {"item_delivery": ["Missing something.", "Chaos errand."], "talk_to_unit": ["Gossip run.", "See what they say."]},
	"calm_welfare": {"item_delivery": ["Practical aid.", "For the peace."], "talk_to_unit": ["Mediation.", "Welfare check."]},
	"duty_protocol": {"item_delivery": ["Patrol supply.", "Protocol."], "talk_to_unit": ["Duty word.", "Order check."]},
	"competent_logistics": {"item_delivery": ["Defenses. Logistics."], "talk_to_unit": ["Competence check.", "See they're sharp."]},
	"discipline_records": {"item_delivery": ["Records. Discipline."], "talk_to_unit": ["Necessary conversation.", "See they're clear."]},
	"unsettling_consultation": {"item_delivery": ["Reagents. Notes."], "talk_to_unit": ["Consultation.", "Unsettling question."]},
	"fortification_drills": {"item_delivery": ["Fortification.", "Drill supply."], "talk_to_unit": ["Reliability check."]},
	"territorial_caution": {"item_delivery": ["Watch supply.", "Edge of camp."], "talk_to_unit": ["Eyes on them.", "Territory check."]},
	"pointed_arcane": {"item_delivery": ["Notes. Clarification."], "talk_to_unit": ["Pointed conversation.", "Arcane question."]},
	"disciplined_quiet": {"item_delivery": ["Gear. Quiet."], "talk_to_unit": ["Quiet word.", "Protection check."]},
	"direct_practical": {"item_delivery": ["Practical favor.", "Readiness."], "talk_to_unit": ["Direct word.", "Check on them."]},
}

# Voice-style -> short line pools per phase (2-4 lines). Profile voice_style used first; personality maps below for fallback.
const VOICE_STYLE_LINES: Dictionary = {
	"blunt": {"offer": ["Need a moment.", "Favor to ask.", "Quick word."], "accepted": ["Understood.", "Good. Thank you."], "declined": ["Understood.", "Another time."], "in_progress": ["When you have it.", "No rush."], "ready": ["You have it? Thanks.", "Good. Here."], "completed": ["Thanks.", "Square."]},
	"caring": {"offer": ["Could you help?", "A small kindness.", "When you have a moment."], "accepted": ["Thank you. I'm grateful.", "I appreciate you."], "declined": ["I understand. Perhaps later.", "No trouble."], "in_progress": ["Whenever you're able.", "I'll be here."], "ready": ["You have it? Thank you.", "Bless you."], "completed": ["Thanks again.", "You've been kind."]},
	"sly": {"offer": ["A word?", "Small favor.", "Need you to run an errand."], "accepted": ["Clever. I owe you one.", "We're even."], "declined": ["Your loss. Another time.", "Fair enough."], "in_progress": ["See what you find.", "Come back when you can."], "ready": ["Got it? Good.", "Just in time."], "completed": ["We're square. For now.", "Don't think I didn't notice."]},
	"scholarly": {"offer": ["A moment? I need something.", "Notes or samples.", "Technical favor."], "accepted": ["Noted. My thanks.", "I'll put it to use."], "declined": ["Understood. No matter.", "Another time."], "in_progress": ["When you have them.", "No hurry."], "ready": ["You have it? Thank you.", "Useful."], "completed": ["My thanks again.", "I'm in your debt."]},
	"elegant": {"offer": ["A message, if you would.", "Small token of favor.", "Delicate matter."], "accepted": ["Magnificent. My thanks.", "Splendid."], "declined": ["Alas. Perhaps another day.", "No matter."], "in_progress": ["When it's done.", "I'll wait."], "ready": ["Perfect. Here.", "You've done well."], "completed": ["Splendid. Thanks again.", "Magnificent."]},
	"disciplined": {"offer": ["Favor to ask.", "Need something.", "A word."], "accepted": ["Acknowledged. Thank you.", "Understood."], "declined": ["Acknowledged. Dismissed.", "Carry on."], "in_progress": ["When you have it.", "Report when done."], "ready": ["Good. Square up.", "Debt repaid."], "completed": ["Acknowledged. Thanks.", "Dismissed."]},
	"pragmatic": {"offer": ["Need a hand.", "Favor.", "Quick ask."], "accepted": ["Good. We're square.", "That helps."], "declined": ["No worries.", "Next time."], "in_progress": ["When you've got it.", "No rush."], "ready": ["Good. Thanks.", "Square."], "completed": ["We're good. Thanks.", "Appreciate it."]},
	"severe": {"offer": ["I have a request.", "Favor. Don't dally.", "Word with you."], "accepted": ["Acknowledged.", "Understood. I'll remember."], "declined": ["Understood. You're dismissed.", "Go."], "in_progress": ["When you have them.", "Don't delay."], "ready": ["Good. Here.", "You've done well."], "completed": ["Acknowledged. Thank you.", "Understood."]},
	"solemn": {"offer": ["A solemn request.", "Word with you.", "I need something."], "accepted": ["Thank you. I mean it.", "I won't forget."], "declined": ["Understood.", "Another time. Perhaps."], "in_progress": ["When you've spoken to them.", "I'll wait."], "ready": ["You have it? Thank you.", "It is noted."], "completed": ["Thank you. I mean it.", "I won't forget."]},
	"chaotic": {"offer": ["Quick! Need a favor.", "Chaos errand.", "Missing something."], "accepted": ["Yes! Thanks.", "Don't forget."], "declined": ["Alright, next time.", "See you."], "in_progress": ["When you find it.", "Come back."], "ready": ["You did it! Thanks.", "Cheers."], "completed": ["You did it. Thanks.", "Don't lose that."]},
	"earnest": {"offer": ["Could you help me?", "I need a favor.", "Would you ask them?"], "accepted": ["Thank you. Really.", "I appreciate it."], "declined": ["That's okay. Maybe later.", "Thanks anyway."], "in_progress": ["Whenever you can.", "I'll be here."], "ready": ["You have it? Thank you.", "Really. Thanks."], "completed": ["Thanks again.", "I won't forget."]},
	"warm": {"offer": ["Could you check on someone?", "Small comfort.", "A kind word."], "accepted": ["Thank you. That means a lot.", "You're a good soul."], "declined": ["No worries. Another time.", "That's alright."], "in_progress": ["When you've seen them.", "No hurry."], "ready": ["You have it? Thank you.", "You're a help."], "completed": ["Thanks again.", "You're a help. Thank you."]},
	"guarded": {"offer": ["A word.", "Need you to sound someone out.", "Favor."], "accepted": ["Thanks. We're even.", "Noted."], "declined": ["Fair enough.", "Another time."], "in_progress": ["See where they stand.", "Come back."], "ready": ["Got it? Good.", "Thanks."], "completed": ["We're square.", "Thanks."]},
	"unsettling": {"offer": ["I need something.", "Consultation.", "A question."], "accepted": ["...Thank you. It will not go unmarked.", "Accepted."], "declined": ["...As you wish.", "Another time."], "in_progress": ["When you have it.", "I will wait."], "ready": ["You have it? Thank you.", "The debt is cleared."], "completed": ["...It is noted. Thank you.", "Accepted."]},
	"kinetic": {"offer": ["Quick favor.", "Pass a message.", "Run something."], "accepted": ["Thanks! You're on it.", "Don't forget."], "declined": ["No problem. Later.", "See you."], "in_progress": ["When you've moved.", "Come find me."], "ready": ["You have it? Great.", "Just in time."], "completed": ["Thanks! You're the best.", "You're a star."]},
	"direct": {"offer": ["Practical favor.", "Need you to check on someone.", "Word."], "accepted": ["Thank you. I won't forget it.", "Appreciate it."], "declined": ["Understood. No offense.", "Another time."], "in_progress": ["When it's done.", "Report back."], "ready": ["Good. Here.", "Thanks."], "completed": ["Thanks again.", "Good work."]},
	"neutral": {"offer": ["Take a moment?", "Favor to ask.", "Could you help?"], "accepted": ["Thank you.", "Appreciate it."], "declined": ["Another time, perhaps.", "No worries."], "in_progress": ["When you have it.", "No rush."], "ready": ["You have it? Thank you.", "Here."], "completed": ["Thanks again.", "Good work."]},
}

# Profile voice_style may use different names; map to VOICE_STYLE_LINES key.
const VOICE_STYLE_ALIASES: Dictionary = {
	"flamboyant": "elegant", "devout": "warm", "haunted": "solemn", "occult": "unsettling", "spirited": "kinetic",
	"compassionate": "caring", "wild": "chaotic", "sardonic": "guarded", "quiet": "direct",
}

# Personality -> voice_style for fallback when profile has no voice_style.
const PERSONALITY_TO_VOICE: Dictionary = {
	"heroic": "direct", "stoic": "blunt", "warm": "warm", "compassionate": "caring", "sly": "sly", "scholarly": "scholarly",
	"flamboyant": "elegant", "disciplined": "disciplined", "pragmatic": "pragmatic", "wild": "chaotic", "sardonic": "guarded",
	"earnest": "earnest", "chaotic": "chaotic", "devout": "warm", "severe": "severe", "occult": "unsettling", "haunted": "solemn",
	"spirited": "kinetic", "neutral": "neutral",
}

# Item tag -> description phrase for item_delivery (shapes flavor; still use target_name/target_amount).
const DESC_ITEM_BY_TAG: Dictionary = {
	ITEM_TAG_MAINTENANCE: "If you have %d x %s to spare—straps, oil, or spare fittings—I need it for upkeep. I'll make it worth your while.",
	ITEM_TAG_PROVISIONS: "Rations or stores: if you can spare %d x %s, I'd be grateful. I'll make it worth your while.",
	ITEM_TAG_HEALING: "Bandages, herbs, or remedies—if you have %d x %s, the infirmary could use it. I'll make it worth your while.",
	ITEM_TAG_REAGENTS: "Tinctures, powders, or samples: %d x %s if you can spare it. I'll make it worth your while.",
	ITEM_TAG_TOOLS: "Tools, nails, or spares—if you've got %d x %s, I need it. I'll make it worth your while.",
	ITEM_TAG_MORALE: "Tea or small comforts: %d x %s if you can spare it. Camp morale. I'll make it worth your while.",
	ITEM_TAG_RECORDS: "Notes, ledgers, or paper—%d x %s if you have it. I'll make it worth your while.",
	ITEM_TAG_FORTIFICATION: "Cord, stakes, or repair supplies: %d x %s if you can spare it. I'll make it worth your while.",
	ITEM_TAG_ANIMAL_CARE: "Feed, brush, or tack—%d x %s if you have any. I'll make it worth your while.",
	ITEM_TAG_RITUAL: "Candles, ash, or cloth—%d x %s if you can spare it. I'll make it worth your while.",
}

# Signature bias -> talk_to_unit description flavor (target_name inserted).
const DESC_TALK_BY_SIGNATURE: Dictionary = {
	"upkeep": "Could you check on %s? I need to know they're squared away—gear and readiness.",
	"camp_comfort": "Could you see how %s is doing? Food, rest—someone to look in on them.",
	"wellness_check": "Could you check on %s? Wounds, rest, spirits—I want to know they're cared for.",
	"read_mood": "I need you to read %s. Tension, intention—what they're not saying. Come back and tell me.",
	"notes_reagents": "Ask %s something for me—observations, a sample, or a technical read. I need their input.",
	"tools_components": "Talk to %s. Tools, fittings, parts—see what they need or what's missing. Sort it out.",
	"duty_conversations": "Word with %s. Protocol, reports, discipline—see they're sharp and ready.",
	"social_errands": "Smooth things over with %s. Pass a word, keep the peace—you know how.",
	"solemn_check": "A solemn check. See %s—memory, duty. Hard conversations. I need to know they're steady.",
	"messenger_errands": "Get a message to %s. Fast. Relay it, keep the momentum—you're good at that.",
	"quiet_tasks": "Quiet word with %s. Patrol concern, readiness. Let me know how they are.",
	"mediation": "See %s. Mediation, welfare—practical aid. Peace be with you.",
	"chaotic_errands": "See what %s says. Gossip, missing things—chaos errand. Come back and tell me.",
	"pointed_conversations": "Pointed conversation with %s. Clarify something. Arcane or otherwise.",
	"defenses_logistics": "Check %s. Defenses, logistics—see they're competent and sharp.",
	"discipline_conversations": "Necessary conversation with %s. Discipline, records. See they're clear.",
	"arcane_consultation": "Consult %s. Unsettling question, reagents—I need their read.",
	"fortification": "See %s. Fortification, drills—reliability check.",
	"prove_useful": "Could you ask %s for me? I want to be useful. Help me out.",
	"gear_order": "Quiet word with %s. Gear, protection—see they're set.",
	"watch_lines": "Eyes on %s. Watch lines, edges of camp—see they're alert.",
	"tools_parts": "Talk to %s. Tools, fittings, parts—see what they need or what's missing. Sort it out.",
}

# warmth_growth -> 1–2 slightly warmer completed lines when completed_count >= 2. Restrained styles get none (use normal).
const WARMTH_COMPLETED: Dictionary = {
	"warm": ["Thank you again. You're a good friend.", "I'm grateful. Really."],
	"steady": ["Thanks again. You've proven reliable.", "Good work. I won't forget it."],
	"expressive": ["Splendid! You've done well.", "My thanks again. Truly."],
	"open": ["Thank you again. Really.", "I won't forget you did this."],
	"bright": ["Thanks! You're the best.", "I owe you. Really."],
	"peaceful": ["Bless you. Thank you again.", "Peace. I'm grateful."],
	"professional": ["Noted. My thanks again.", "Useful. I'm in your debt."],
}

static func _content_pool_name_for_phase(phase: String) -> String:
	match phase:
		"offer": return ContentDB.POOL_OFFER_LINES
		"accepted": return ContentDB.POOL_ACCEPTED_LINES
		"declined": return ContentDB.POOL_DECLINED_LINES
		"in_progress": return ContentDB.POOL_IN_PROGRESS_LINES
		"ready_to_turn_in": return ContentDB.POOL_READY_LINES
		"completed": return ContentDB.POOL_COMPLETED_LINES
	return ""

static func _get_offer_title(req_type: String, personality: String, giver_name: String = "", prof: Dictionary = {}) -> String:
	var p: String = str(personality).strip_edges().to_lower()
	if p.is_empty():
		p = "neutral"
	var pool_name: String = ContentDB.POOL_TITLES_ITEM_DELIVERY if req_type == TYPE_ITEM_DELIVERY else ContentDB.POOL_TITLES_TALK_TO_UNIT
	var style: String = str(prof.get("title_style", "")).strip_edges()
	var voice_str: String = str(prof.get("voice_style", "")).strip_edges().to_lower()
	var seed_h: int = giver_name.hash() if giver_name else p.hash()
	# Content bank: character -> voice_style -> personality -> neutral (same stack as lines).
	var arr: Array = ContentDB.get_best_pool(giver_name, voice_str, p, pool_name, style)
	if arr.size() == 0 and style != "":
		arr = ContentDB.get_best_pool(giver_name, voice_str, p, pool_name, "")
	if arr.size() > 0:
		return ContentDB.pick_from_pool(arr, seed_h)
	if style != "" and style in TITLE_BY_STYLE:
		var by_type: Dictionary = TITLE_BY_STYLE[style]
		var title_arr: Array = by_type.get(req_type, [])
		if title_arr.size() > 0:
			return title_arr[abs(seed_h) % title_arr.size()]
	if req_type == TYPE_ITEM_DELIVERY:
		var t: Array[String] = ["A small favor.", "Could use a hand.", "Supplies needed.", "Reagents or parts.", "Provisions, if you can spare any."]
		return t[abs(p.hash()) % t.size()]
	if req_type == TYPE_TALK_TO_UNIT:
		var t: Array[String] = ["A word with someone.", "Pass a message.", "Check on someone.", "Need you to ask something.", "Clarify something with a friend."]
		return t[abs(p.hash() + 1) % t.size()]
	return "Request."

static func _get_offer_description(req_type: String, personality: String, target_name: String, target_amount: int, giver_name: String = "", prof: Dictionary = {}) -> String:
	var p: String = str(personality).strip_edges().to_lower()
	if p.is_empty():
		p = "neutral"
	var voice_str: String = str(prof.get("voice_style", "")).strip_edges().to_lower()
	var seed_h: int = (giver_name + target_name).hash() if giver_name else target_name.hash()
	# Content bank: character -> voice_style -> personality -> neutral (same stack as lines).
	if req_type == TYPE_ITEM_DELIVERY:
		var pool_name: String = ContentDB.POOL_DESC_ITEM_DELIVERY
		var tags: Array = prof.get("item_tags", [])
		var arr: Array = []
		for tag in tags:
			arr = ContentDB.get_best_pool(giver_name, voice_str, p, pool_name, str(tag))
			if arr.size() > 0:
				break
		if arr.size() == 0:
			arr = ContentDB.get_best_pool(giver_name, voice_str, p, pool_name, "")
		if arr.size() > 0:
			var tmpl: String = ContentDB.pick_from_pool(arr, seed_h)
			if tmpl != "":
				return tmpl % [target_amount, target_name]
		for tag in tags:
			if tag in DESC_ITEM_BY_TAG:
				return (DESC_ITEM_BY_TAG[tag] as String) % [target_amount, target_name]
		return "If you have %d x %s to spare, I'd be grateful. I'll make it worth your while." % [target_amount, target_name]
	if req_type == TYPE_TALK_TO_UNIT:
		var bias: String = str(prof.get("signature_request_bias", "")).strip_edges()
		var pool_name: String = ContentDB.POOL_DESC_TALK_TO_UNIT
		var arr: Array = ContentDB.get_best_pool(giver_name, voice_str, p, pool_name, bias)
		if arr.size() == 0 and bias != "":
			arr = ContentDB.get_best_pool(giver_name, voice_str, p, pool_name, "")
		if arr.size() > 0:
			var tmpl: String = ContentDB.pick_from_pool(arr, seed_h)
			if tmpl != "":
				return tmpl % target_name
		if bias != "" and bias in DESC_TALK_BY_SIGNATURE:
			return (DESC_TALK_BY_SIGNATURE[bias] as String) % target_name
		return "Could you have a word with %s for me? I need to know they're doing alright." % target_name
	return ""

## Fixed rewards: item_delivery 1->40, 2->60, 3->80 gold; talk_to_unit 30. deep: +10 gold.
static func _get_reward_gold(req_type: String, target_amount: int, request_depth: String = "normal") -> int:
	var base: int = 30
	if req_type == TYPE_ITEM_DELIVERY:
		match target_amount:
			1: base = 40
			2: base = 60
			3: base = 80
			_: base = 40
	elif req_type == TYPE_TALK_TO_UNIT:
		base = 30
	if str(request_depth).strip_edges().to_lower() == "deep":
		base += 10
	return base

## item_delivery: amount 1 or 2 -> 1 affinity, 3 -> 2; talk_to_unit -> 1. deep: +1 affinity.
static func _get_reward_affinity(req_type: String, target_amount: int, request_depth: String = "normal") -> int:
	var base: int = 1
	if req_type == TYPE_ITEM_DELIVERY:
		base = 2 if target_amount >= 3 else 1
	if str(request_depth).strip_edges().to_lower() == "deep":
		base += 1
	return base

## Phase: "offer", "accepted", "declined", "in_progress", "ready_to_turn_in", "completed"
## Resolution: 1) content bank (get_best_pool) 2) profile voice_style -> VOICE_STYLE_LINES 3) personality 4) neutral.
static func get_line(phase: String, personality: String, request_data: Dictionary, completed_count_for_giver: int = 0, giver_name: String = "") -> String:
	var p: String = personality.strip_edges().to_lower()
	if p.is_empty():
		p = "neutral"
	var req_type: String = str(request_data.get("type", ""))
	var prof: Dictionary = get_profile(giver_name) if giver_name else {}
	var voice_key: String = str(prof.get("voice_style", "")).strip_edges().to_lower()
	if voice_key != "":
		voice_key = VOICE_STYLE_ALIASES.get(voice_key, voice_key)
	var depth: String = str(request_data.get("request_depth", "normal")).strip_edges().to_lower()
	var use_character_flavor: bool = (depth == "deep" or depth == "personal")
	var flavor_name: String = giver_name if use_character_flavor else ""
	var seed_val: int = flavor_name.hash() if flavor_name else p.hash()
	# Content bank first: try completed_warm then phase pool.
	if phase == "completed" and completed_count_for_giver >= 2:
		var warm_arr: Array = ContentDB.get_best_pool(flavor_name, voice_key, p, ContentDB.POOL_COMPLETED_WARM_LINES)
		if warm_arr.size() > 0:
			return ContentDB.pick_from_pool(warm_arr, seed_val + completed_count_for_giver)
	var pool_name: String = _content_pool_name_for_phase(phase)
	if pool_name != "":
		var arr: Array = ContentDB.get_best_pool(flavor_name, voice_key, p, pool_name)
		if arr.size() > 0:
			return ContentDB.pick_from_pool(arr, seed_val + phase.hash())
	# Fallback: existing VOICE_STYLE_LINES / personality / internal.
	if voice_key != "" and voice_key in VOICE_STYLE_LINES:
		var by_phase: Dictionary = VOICE_STYLE_LINES[voice_key]
		var phase_key: String = "ready" if phase == "ready_to_turn_in" else phase
		var arr: Array = by_phase.get(phase_key, [])
		if arr.size() > 0:
			if phase == "completed" and completed_count_for_giver >= 2:
				var wg: String = str(prof.get("warmth_growth", "")).strip_edges().to_lower()
				if wg != "" and wg in WARMTH_COMPLETED:
					var warm_arr: Array = WARMTH_COMPLETED[wg]
					return _pick(warm_arr, seed_val + completed_count_for_giver)
			return _pick(arr, seed_val + phase_key.hash())
	match phase:
		"offer":
			return _get_offer_line(p, req_type)
		"accepted":
			return _get_accepted_line(p, req_type)
		"declined":
			return _get_declined_line(p)
		"in_progress":
			return _get_in_progress_line(p, request_data)
		"ready_to_turn_in":
			return _get_ready_line(p, req_type)
		"completed":
			return _get_completed_line(p, completed_count_for_giver)
	return ""

static func _pick(lines: Array[String], seed_val: int) -> String:
	if lines.is_empty():
		return ""
	return lines[abs(seed_val) % lines.size()]

static func _get_offer_line(p: String, req_type: String) -> String:
	var seed_val: int = p.hash() + req_type.hash()
	if req_type == TYPE_ITEM_DELIVERY:
		var lines: Array[String] = [
			"Take a moment? I need supplies.",
			"Got a favor to ask—reagents or parts.",
			"Could you spare some provisions?",
			"A few components would help.",
			"Need bandages or tools if you have any.",
		]
		return _pick(lines, seed_val)
	if req_type == TYPE_TALK_TO_UNIT:
		var lines: Array[String] = [
			"Take a moment? Need a message passed.",
			"Could you check on someone for me?",
			"Got a word I need you to carry.",
			"I need to know they're alright.",
			"Would you ask them something for me?",
		]
		return _pick(lines, seed_val)
	return _pick(["Take a moment?", "Got a favor to ask."], seed_val)

static func _get_accepted_line(p: String, _req_type: String) -> String:
	var lines_by_p: Dictionary = {
		"heroic": ["Thank you. I won't forget it.", "Appreciate it. You have my thanks."],
		"stoic": ["Understood. I'll remember.", "Good. Thank you."],
		"warm": ["Thank you. That means a lot.", "You're a good soul. Thanks."],
		"compassionate": ["Thank you. I'm grateful.", "I appreciate you doing this."],
		"sly": ["Clever. I owe you one.", "Thanks. We'll call it even."],
		"scholarly": ["Noted. My thanks.", "Thank you. I'll put it to use."],
		"flamboyant": ["Magnificent! You have my thanks.", "Splendid. I shan't forget."],
		"disciplined": ["Acknowledged. Thank you.", "Understood. I'm in your debt."],
		"pragmatic": ["Good. We're square.", "Thanks. That helps."],
		"wild": ["Ha! Thanks. You're alright.", "Good. I owe you."],
		"sardonic": ["How generous. Thanks.", "I'm touched. Really."],
		"earnest": ["Thank you. Really.", "I appreciate it. Thanks."],
		"chaotic": ["Yes! Thanks. This'll be good.", "Cheers. Don't forget."],
		"devout": ["Bless you. Thank you.", "I'm grateful. Peace be with you."],
		"severe": ["Acknowledged. Thank you.", "Understood. I'll remember."],
		"occult": ["...Thank you. It will not go unmarked.", "Accepted. My thanks."],
		"haunted": ["Thank you. I mean it.", "...Thanks. I won't forget."],
		"spirited": ["Thanks! You're the best.", "I owe you. Thank you."],
		"neutral": ["Thank you. I won't forget it.", "Appreciate it."],
	}
	var arr: Array = lines_by_p.get(p, lines_by_p["neutral"])
	return _pick(arr, p.hash())

static func _get_declined_line(p: String) -> String:
	var lines_by_p: Dictionary = {
		"heroic": ["Another time, perhaps.", "Understood. No offense taken."],
		"stoic": ["Understood.", "Very well."],
		"warm": ["No worries. Another time.", "That's alright. Maybe later."],
		"compassionate": ["I understand. Perhaps later.", "No trouble. Another time."],
		"sly": ["Your loss. Another time.", "Fair enough. We'll see."],
		"scholarly": ["Understood. No matter.", "Another time, then."],
		"flamboyant": ["Alas! Perhaps another day.", "No matter. Until then."],
		"disciplined": ["Acknowledged. Dismissed.", "Understood. Carry on."],
		"pragmatic": ["No worries.", "Understood. Next time."],
		"wild": ["Suit yourself. Later.", "Fine. Catch you then."],
		"sardonic": ["How disappointing. No, I jest.", "Another time. Or not."],
		"earnest": ["That's okay. Maybe later.", "No problem. Thanks anyway."],
		"chaotic": ["Alright, alright. Next time.", "No big deal. See you."],
		"devout": ["Peace. Another time.", "As you wish. Bless you."],
		"severe": ["Understood. You're dismissed.", "Very well. Go."],
		"occult": ["...As you wish.", "Understood. Another time."],
		"haunted": ["...Understood.", "Another time. Perhaps."],
		"spirited": ["No problem! Maybe later.", "That's okay. See you."],
		"neutral": ["Another time, perhaps.", "No worries."],
	}
	var arr: Array = lines_by_p.get(p, lines_by_p["neutral"])
	return _pick(arr, p.hash())

static func _get_in_progress_line(p: String, data: Dictionary) -> String:
	var type_str: String = str(data.get("type", ""))
	if type_str == TYPE_ITEM_DELIVERY:
		var lines: Array[String] = ["Still looking for those items. No rush.", "When you have them, bring them by.", "No hurry. I'll be here."]
		return _pick(lines, p.hash())
	if type_str == TYPE_TALK_TO_UNIT:
		var lines: Array[String] = ["When you've spoken to them, come back.", "Let me know once you've had a word.", "I'll wait. Come find me after."]
		return _pick(lines, p.hash() + 1)
	return "Still in progress."

static func _get_ready_line(p: String, req_type: String) -> String:
	var lines: Array[String] = [
		"You have it? Thank you.",
		"Perfect. Here's your reward.",
		"Just in time. Much obliged.",
		"Good. Let me square up.",
	]
	return _pick(lines, p.hash() + req_type.hash())

static func _get_completed_line(p: String, completed_count: int) -> String:
	var warmer: bool = completed_count >= 2
	var normal: Dictionary = {
		"heroic": ["Thanks again.", "Good work. I owe you one."],
		"stoic": ["Understood. We're even.", "Good. Thank you."],
		"warm": ["Thanks again.", "You're a help. Thank you."],
		"compassionate": ["Thanks again.", "I appreciate it."],
		"sly": ["We're square. For now.", "Thanks. Don't think I didn't notice."],
		"scholarly": ["Noted. My thanks again.", "Useful. I'm in your debt."],
		"flamboyant": ["Splendid! You've done well.", "Magnificent. My thanks again."],
		"disciplined": ["Acknowledged. Debt repaid.", "Thank you. Dismissed."],
		"pragmatic": ["We're good. Thanks.", "Square. Appreciate it."],
		"wild": ["Ha! You came through. Thanks.", "Good. I owe you one."],
		"sardonic": ["I'm moved. Truly. Thanks.", "Don't let it go to your head."],
		"earnest": ["Thanks again.", "I appreciate it."],
		"chaotic": ["Yes! You did it. Thanks.", "Cheers. Don't lose that."],
		"devout": ["Bless you. Thank you again.", "Peace. I'm grateful."],
		"severe": ["Acknowledged. Thank you.", "Understood. You've done well."],
		"occult": ["...It is noted. Thank you.", "Accepted. The debt is cleared."],
		"haunted": ["...Thank you. I mean it.", "I won't forget. Thanks."],
		"spirited": ["Thanks again!", "You're a star."],
		"neutral": ["Thanks again.", "Good work. I owe you one."],
	}
	var warm_lines: Dictionary = {
		"heroic": ["Thanks again. You've proven yourself.", "Good work. I won't forget it."],
		"warm": ["Thank you again. You're a good friend.", "I'm grateful. Really."],
		"compassionate": ["Thank you. You've been kind.", "I'm grateful. Bless you."],
		"earnest": ["Thank you again. Really.", "I won't forget you did this."],
		"spirited": ["Thanks! You're the best.", "I owe you. Really."],
	}
	var arr: Array
	if warmer and p in warm_lines:
		arr = warm_lines[p]
	else:
		arr = normal.get(p, normal["neutral"])
	return _pick(arr, p.hash() + completed_count)
