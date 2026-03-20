# CampContext.gd
# Shared camp explore runtime state and small cross-cutting helpers (walker lookup, zone tests, pair scoring).

class_name CampContext
extends RefCounted

const RUMOR_NEAR_ZONE_MARGIN: float = 24.0

var walk_min: Vector2 = Vector2(80, 80)
var walk_max: Vector2 = Vector2(720, 520)
var walker_nodes: Array[Node] = []
var camp_zones: Array = []
var active_time_block: String = "day"
var active_camp_mood: String = "normal"
var visit_theme: String = "normal"


func normalize_unit_name_for_matching(raw_name: String) -> String:
	var out: String = str(raw_name).strip_edges()
	out = out.replace("“", "\"")
	out = out.replace("”", "\"")
	out = out.replace("’", "'")
	return out


func build_camp_context_dict() -> Dictionary:
	var ctx: Dictionary = {}
	var tb: String = str(active_time_block).strip_edges().to_lower()
	if tb == "" or tb not in ["dawn", "day", "night"]:
		tb = "day"
	var mood: String = normalize_camp_mood(active_camp_mood)
	var progress_level: int = 0
	var story_flags: Dictionary = {}
	if CampaignManager:
		progress_level = maxi(0, int(CampaignManager.camp_request_progress_level))
		var flags_v: Variant = CampaignManager.encounter_flags
		if flags_v is Dictionary:
			for key_v in (flags_v as Dictionary).keys():
				var k: String = str(key_v).strip_edges()
				if k == "":
					continue
				if bool((flags_v as Dictionary).get(key_v, false)):
					story_flags[k] = true
	ctx["time_block"] = tb
	ctx["camp_mood"] = mood
	ctx["progress_level"] = progress_level
	ctx["story_flags"] = story_flags
	ctx["visit_theme"] = str(visit_theme).strip_edges().to_lower()
	return ctx


func resolve_visit_theme() -> void:
	var mood: String = normalize_camp_mood(active_camp_mood)
	var theme: String = "normal"
	match mood:
		"hopeful":
			theme = "hopeful"
		"tense":
			theme = "tense"
		"somber":
			theme = "somber"
		_:
			theme = "normal"
	var injured_any: bool = false
	var fatigued_any: bool = false
	if CampaignManager:
		for row in CampaignManager.player_roster:
			if not (row is Dictionary):
				continue
			var n: String = str((row as Dictionary).get("unit_name", "")).strip_edges()
			if n == "":
				continue
			if CampaignManager.is_unit_injured(n):
				injured_any = true
			if CampaignManager.is_unit_fatigued(n):
				fatigued_any = true
	if injured_any or fatigued_any:
		if theme == "normal" or theme == "hopeful":
			theme = "recovery"
	var st: String = ""
	if CampaignManager:
		st = str(CampaignManager.camp_request_status).strip_edges().to_lower()
	if st == "active" or st == "ready_to_turn_in":
		if theme in ["normal", "hopeful", "gossip"]:
			theme = "tense"
	if theme == "normal":
		var tb: String = str(active_time_block).strip_edges().to_lower()
		if tb == "day":
			var r: float = randf()
			if r < 0.14:
				theme = "gossip"
			elif r < 0.24:
				theme = "training"
	visit_theme = theme


func visit_theme_score_adjust(entry: Dictionary, event_kind: String) -> float:
	var delta: float = 0.0
	var t: String = str(visit_theme).strip_edges().to_lower()
	if entry.has("preferred_visit_themes"):
		var pv: Variant = entry.get("preferred_visit_themes", [])
		if pv is Array:
			for item in pv as Array:
				if str(item).strip_edges().to_lower() == t:
					delta += 1.35
					break
	if entry.has("avoided_visit_themes"):
		var av: Variant = entry.get("avoided_visit_themes", [])
		if av is Array:
			for item2 in av as Array:
				if str(item2).strip_edges().to_lower() == t:
					delta -= 2.1
					break
	match t:
		"gossip":
			if event_kind in ["rumor", "micro", "chatter", "social"]:
				delta += 0.48
			elif event_kind == "pair_listen":
				delta += 0.2
		"recovery":
			if event_kind in ["rumor", "micro", "chatter"]:
				delta += 0.32
			elif event_kind == "social":
				delta += 0.12
		"tense":
			if event_kind in ["rumor", "social", "micro"]:
				delta += 0.28
		"hopeful":
			if event_kind in ["chatter", "social", "pair_listen"]:
				delta += 0.24
		"somber":
			if event_kind in ["rumor", "micro"]:
				delta += 0.22
			elif event_kind == "chatter":
				delta -= 0.08
		"training":
			if event_kind == "pair_listen":
				delta += 0.26
			if event_kind in ["chatter", "social"]:
				delta += 0.1
		_:
			pass
	return delta


func normalize_camp_mood(value: String) -> String:
	var mood: String = str(value).strip_edges().to_lower()
	if mood in ["normal", "hopeful", "tense", "somber"]:
		return mood
	return "normal"


func find_walker_by_name(unit_name: String) -> Node:
	var key: String = normalize_unit_name_for_matching(unit_name)
	if key.is_empty():
		return null
	for w in walker_nodes:
		if not is_instance_valid(w) or not (w is CampRosterWalker):
			continue
		var walker_name: String = normalize_unit_name_for_matching((w as CampRosterWalker).unit_name)
		if walker_name == key:
			return w
	return null


func get_walker_by_name(unit_name: String) -> CampRosterWalker:
	var node: Node = find_walker_by_name(unit_name)
	if node is CampRosterWalker:
		return node as CampRosterWalker
	return null


func is_walker_near_zone(walker_node: Node, zone_type: String) -> bool:
	var pos: Vector2 = walker_node.global_position
	for z in camp_zones:
		if not is_instance_valid(z) or not ("zone_type" in z):
			continue
		var zt: String = str(z.zone_type).strip_edges()
		if zt != zone_type:
			continue
		var z_pos: Vector2 = z.global_position
		var z_radius: float = float(z.radius) if "radius" in z else 32.0
		if pos.distance_squared_to(z_pos) <= (z_radius + RUMOR_NEAR_ZONE_MARGIN) * (z_radius + RUMOR_NEAR_ZONE_MARGIN):
			return true
	return false


func are_walkers_near_each_other(w1: Node, w2: Node, pair_radius: float) -> bool:
	if w1 == null or w2 == null or w1 == w2:
		return false
	return w1.global_position.distance_squared_to(w2.global_position) <= pair_radius * pair_radius


## First matching camp behavior zone of this type (for staging / facing hints).
func get_zone_layout_hints(zone_type: String) -> Dictionary:
	var zt: String = str(zone_type).strip_edges()
	var out: Dictionary = {
		"valid": false,
		"center": Vector2.ZERO,
		"radius": 32.0,
		"facing_dir": Vector2.RIGHT,
		"face_mode": "center",
	}
	if zt == "":
		return out
	for z in camp_zones:
		if not is_instance_valid(z) or not ("zone_type" in z):
			continue
		if str(z.zone_type).strip_edges() != zt:
			continue
		out["valid"] = true
		out["center"] = (z as Node2D).global_position
		out["radius"] = float(z.radius) if "radius" in z else 32.0
		if "facing_dir" in z:
			var fd: Variant = z.facing_dir
			if fd is Vector2 and (fd as Vector2).length() > 0.001:
				out["facing_dir"] = (fd as Vector2).normalized()
		if "face_mode" in z:
			out["face_mode"] = str(z.face_mode).strip_edges().to_lower()
		return out
	return out


func make_pair_key(name_a: String, name_b: String) -> String:
	if CampaignManager:
		return CampaignManager.make_pair_key(name_a, name_b)
	var a: String = str(name_a).strip_edges()
	var b: String = str(name_b).strip_edges()
	if a == "" or b == "":
		return ""
	if a <= b:
		return "%s|%s" % [a, b]
	return "%s|%s" % [b, a]


func get_pair_stats(name_a: String, name_b: String) -> Dictionary:
	if CampaignManager:
		CampaignManager.ensure_camp_memory()
		return CampaignManager.get_pair_stats(name_a, name_b)
	return { "familiarity": 0, "tension": 0, "last_visit_spoke": 0 }


func set_pair_stats(name_a: String, name_b: String, stats: Dictionary) -> void:
	if CampaignManager:
		CampaignManager.ensure_camp_memory()
		CampaignManager.set_pair_stats(name_a, name_b, stats)


func get_pair_familiarity(name_a: String, name_b: String) -> int:
	if CampaignManager:
		CampaignManager.ensure_camp_memory()
		return CampaignManager.get_pair_familiarity(name_a, name_b)
	return 0


func get_pair_tension(name_a: String, name_b: String) -> int:
	var stats: Dictionary = get_pair_stats(name_a, name_b)
	return int(stats.get("tension", 0))


func get_pair_affinity_bias(name_a: String, name_b: String) -> float:
	var familiarity: float = float(get_pair_familiarity(name_a, name_b))
	return clampf(familiarity * 0.12, 0.0, 0.6)


func get_pair_social_bias(name_a: String, name_b: String) -> float:
	var affinity_bias: float = get_pair_affinity_bias(name_a, name_b)
	var tension_bias: float = float(get_pair_tension(name_a, name_b)) * 0.08
	return clampf(affinity_bias - tension_bias, -0.4, 0.6)


func get_relationship_tone(entry: Dictionary) -> String:
	var tone: String = str(entry.get("relationship_tone", "neutral")).strip_edges().to_lower()
	if tone in ["warm", "neutral", "tense"]:
		return tone
	return "neutral"


func score_with_relationship_bias(base_priority: float, entry: Dictionary, name_a: String, name_b: String) -> float:
	var tone: String = get_relationship_tone(entry)
	var social_bias: float = get_pair_social_bias(name_a, name_b)
	match tone:
		"tense":
			social_bias = maxf(social_bias, 0.0)
		"warm":
			social_bias += maxf(0.0, get_pair_affinity_bias(name_a, name_b)) * 0.2
		_:
			pass
	social_bias = clampf(social_bias, -0.4, 0.6)
	return base_priority + social_bias


func was_pair_recently_active(name_a: String, name_b: String, within_visits: int) -> bool:
	if within_visits < 0:
		return false
	if not CampaignManager:
		return false
	CampaignManager.ensure_camp_memory()
	var current_visit: int = int(CampaignManager.get_camp_visit_index())
	var stats: Dictionary = get_pair_stats(name_a, name_b)
	var last_visit: int = int(stats.get("last_visit_spoke", 0))
	if last_visit <= 0:
		return false
	var delta_visits: int = current_visit - last_visit
	return delta_visits >= 0 and delta_visits <= within_visits


func pair_memory_matches(entry: Dictionary, name_a: String, name_b: String) -> bool:
	var has_memory_gate: bool = entry.has("min_familiarity") or entry.has("max_familiarity") or entry.has("min_tension") or entry.has("max_tension") or entry.has("recent_within_visits")
	if not has_memory_gate:
		return true
	var a_name: String = str(name_a).strip_edges()
	var b_name: String = str(name_b).strip_edges()
	if a_name.is_empty() or b_name.is_empty():
		return true
	var stats: Dictionary = get_pair_stats(a_name, b_name)
	var familiarity: int = int(stats.get("familiarity", 0))
	var tension: int = int(stats.get("tension", 0))
	if entry.has("min_familiarity") and familiarity < int(entry.get("min_familiarity", 0)):
		return false
	if entry.has("max_familiarity") and familiarity > int(entry.get("max_familiarity", 999999)):
		return false
	if entry.has("min_tension") and tension < int(entry.get("min_tension", 0)):
		return false
	if entry.has("max_tension") and tension > int(entry.get("max_tension", 999999)):
		return false
	if entry.has("recent_within_visits"):
		var within_visits: int = int(entry.get("recent_within_visits", 0))
		if not was_pair_recently_active(a_name, b_name, within_visits):
			return false
	return true


func content_condition_matches(entry: Dictionary, speaker_name: String, listener_name: String = "") -> bool:
	if not CampaignManager:
		return not bool(entry.get("requires_injured_speaker", false)) and not bool(entry.get("requires_fatigued_speaker", false)) and not bool(entry.get("requires_injured_listener", false)) and not bool(entry.get("requires_fatigued_listener", false))
	var speaker: String = str(speaker_name).strip_edges()
	var listener: String = str(listener_name).strip_edges()
	if bool(entry.get("requires_injured_speaker", false)) and not CampaignManager.is_unit_injured(speaker):
		return false
	if bool(entry.get("requires_fatigued_speaker", false)) and not CampaignManager.is_unit_fatigued(speaker):
		return false
	if bool(entry.get("requires_injured_listener", false)):
		if listener == "" or not CampaignManager.is_unit_injured(listener):
			return false
	if bool(entry.get("requires_fatigued_listener", false)):
		if listener == "" or not CampaignManager.is_unit_fatigued(listener):
			return false
	return true
