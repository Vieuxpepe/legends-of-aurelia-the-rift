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

var _anchor_home_claims: Dictionary = {}
var _anchor_social_claims: Dictionary = {}


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
		var merged: Dictionary = CampaignManager.get_camp_conversation_story_flags()
		for mk in merged.keys():
			var mks: String = str(mk).strip_edges()
			if mks != "" and bool(merged[mk]):
				story_flags[mks] = true
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


func reset_activity_anchor_claims_for_visit() -> void:
	_anchor_home_claims.clear()
	_anchor_social_claims.clear()


func gather_activity_anchors_in_zone(zone: Node) -> Array:
	var out: Array = []
	if not is_instance_valid(zone):
		return out
	for ch in zone.get_children():
		if ch is CampActivityAnchor:
			out.append(ch)
	return out


func find_first_zone_of_type(zone_type: String) -> Node:
	var zt: String = str(zone_type).strip_edges()
	if zt == "":
		return null
	for z in camp_zones:
		if not is_instance_valid(z) or not ("zone_type" in z):
			continue
		if str(z.zone_type).strip_edges() == zt:
			return z
	return null


func get_all_activity_anchors_for_zone_type(zone_type: String) -> Array:
	var z: Node = find_first_zone_of_type(zone_type)
	if z == null:
		return []
	return gather_activity_anchors_in_zone(z)


func anchor_total_use_penalty(anchor: Node) -> float:
	if anchor == null or not is_instance_valid(anchor):
		return 0.0
	var id: int = anchor.get_instance_id()
	return float(_anchor_home_claims.get(id, 0)) * 12.0 + float(_anchor_social_claims.get(id, 0)) * 16.0


func claim_anchor_home(anchor: Node) -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	var id: int = anchor.get_instance_id()
	_anchor_home_claims[id] = int(_anchor_home_claims.get(id, 0)) + 1


func claim_anchor_social(anchor: Node) -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	var id: int = anchor.get_instance_id()
	_anchor_social_claims[id] = int(_anchor_social_claims.get(id, 0)) + 1


func release_anchor_social(anchor: Node) -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	var id: int = anchor.get_instance_id()
	var c: int = int(_anchor_social_claims.get(id, 0))
	c = maxi(0, c - 1)
	if c <= 0:
		_anchor_social_claims.erase(id)
	else:
		_anchor_social_claims[id] = c


func score_anchor_for_idle_style(anchor: CampActivityAnchor, idle_style: String, injured: bool, fatigued: bool) -> float:
	var sc: float = maxf(0.05, anchor.weight)
	var st: String = str(idle_style).strip_edges().to_lower()
	for ps in anchor.preferred_idle_styles:
		if str(ps).strip_edges().to_lower() == st:
			sc += 22.0
			break
	var role_l: String = str(anchor.anchor_role).strip_edges().to_lower()
	if role_l.length() > 1 and (role_l in st or st in role_l):
		sc += 6.0
	var tags: String = str(anchor.activity_tags).strip_edges().to_lower()
	if tags != "" and st in tags:
		sc += 10.0
	match st:
		"sit_rest", "rest_head_down":
			if anchor.sit_like:
				sc += 18.0
		"kneel_prayer", "pray_quietly":
			if anchor.kneel_like:
				sc += 20.0
		"tend_fire", "warm_hands", "pour_water":
			if anchor.fire_like:
				sc += 16.0
		"look_out", "patrol", "inspect_wall":
			if anchor.lookout_like:
				sc += 16.0
		"workbench_tinker", "sort_supplies", "sharpen", "carry_bundle", "sweep_area":
			if anchor.work_like:
				sc += 15.0
		_:
			pass
	if injured or fatigued:
		if anchor.sit_like or anchor.fire_like:
			sc += 5.0
	return sc


func score_anchor_for_social_family(anchor: CampActivityAnchor, behavior_family: String, pose_guess: String) -> float:
	var sc: float = maxf(0.05, anchor.weight)
	var fam: String = str(behavior_family).strip_edges().to_lower()
	var pose: String = str(pose_guess).strip_edges().to_lower()
	for pf in anchor.preferred_behavior_families:
		if str(pf).strip_edges().to_lower() == fam:
			sc += 20.0
	var tags: String = str(anchor.activity_tags).strip_edges().to_lower()
	if tags != "" and fam != "" and fam in tags:
		sc += 8.0
	match fam:
		"spar", "mock_duel":
			if anchor.work_like or anchor.lookout_like:
				sc += 6.0
		"drill", "formation":
			if anchor.lookout_like or anchor.work_like:
				sc += 10.0
		"work_detail", "repair":
			if anchor.work_like:
				sc += 18.0
		"morale_fire", "fireside", "rhythm", "song":
			if anchor.fire_like or anchor.sit_like:
				sc += 16.0
		_:
			pass
	match pose:
		"spar":
			if anchor.lookout_like:
				sc += 4.0
		"drill":
			if anchor.lookout_like:
				sc += 8.0
		"work":
			if anchor.work_like:
				sc += 12.0
		"fireside":
			if anchor.fire_like or anchor.sit_like:
				sc += 12.0
		_:
			pass
	return sc


func pick_best_spawn_anchor_for_zone(zone: Node, idle_style: String, injured: bool, fatigued: bool) -> CampActivityAnchor:
	var anchors: Array = gather_activity_anchors_in_zone(zone)
	if anchors.is_empty():
		return null
	var best: CampActivityAnchor = null
	var best_sc: float = -1e9
	for a in anchors:
		if not (a is CampActivityAnchor):
			continue
		var ca: CampActivityAnchor = a as CampActivityAnchor
		var sc: float = score_anchor_for_idle_style(ca, idle_style, injured, fatigued)
		sc -= anchor_total_use_penalty(ca)
		if sc > best_sc:
			best_sc = sc
			best = ca
	return best


func pick_best_standing_activity_anchor(zone: Node, near_pos: Vector2, solo_style: String) -> CampActivityAnchor:
	if zone == null or not is_instance_valid(zone):
		return null
	var anchors: Array = gather_activity_anchors_in_zone(zone)
	if anchors.is_empty():
		return null
	var best: CampActivityAnchor = null
	var best_sc: float = -1e9
	var st: String = str(solo_style).strip_edges().to_lower()
	for a in anchors:
		if not (a is CampActivityAnchor):
			continue
		var ca: CampActivityAnchor = a as CampActivityAnchor
		var sc: float = score_anchor_for_idle_style(ca, st, false, false)
		var d: float = near_pos.distance_to(ca.global_position)
		sc -= d * 0.12
		sc -= anchor_total_use_penalty(ca) * 0.38
		if sc > best_sc:
			best_sc = sc
			best = ca
	return best


func pick_distinct_social_anchors(zone: Node, count: int, behavior_family: String, pose_guess: String) -> Array:
	if zone == null or not is_instance_valid(zone) or count <= 0:
		return []
	var anchors: Array = gather_activity_anchors_in_zone(zone)
	if anchors.is_empty():
		return []
	var fam: String = str(behavior_family).strip_edges().to_lower()
	var pose: String = str(pose_guess).strip_edges().to_lower()
	var scored: Array = []
	for a in anchors:
		if not (a is CampActivityAnchor):
			continue
		var ca: CampActivityAnchor = a as CampActivityAnchor
		var sc: float = score_anchor_for_social_family(ca, fam, pose)
		sc -= anchor_total_use_penalty(ca) * 0.65
		scored.append({"anchor": ca, "score": sc})
	if scored.is_empty():
		return []
	scored.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return float(x.get("score", 0.0)) > float(y.get("score", 0.0)))
	var picked: Array = []
	var min_sep: float = 12.0
	for _iter in range(count):
		var best_adj: float = -1e10
		var best_entry: Dictionary = {}
		var found: bool = false
		for entry in scored:
			var cand: CampActivityAnchor = entry.get("anchor", null) as CampActivityAnchor
			if cand == null:
				continue
			var cid: int = cand.get_instance_id()
			var taken: bool = false
			for p in picked:
				var pn: CampActivityAnchor = p.get("anchor", null) as CampActivityAnchor
				if pn != null and pn.get_instance_id() == cid:
					taken = true
					break
			if taken:
				continue
			var sep_pen: float = 0.0
			var cpos: Vector2 = cand.global_position
			for p2 in picked:
				var ppos: Vector2 = p2["position"] as Vector2
				var dd: float = cpos.distance_to(ppos)
				if dd < min_sep:
					sep_pen -= (min_sep - dd) * 2.4
			var adj: float = float(entry.get("score", 0.0)) + sep_pen
			if adj > best_adj:
				best_adj = adj
				best_entry = entry
				found = true
		if not found:
			return []
		var chosen: CampActivityAnchor = best_entry["anchor"] as CampActivityAnchor
		picked.append({"anchor": chosen, "position": chosen.global_position})
	if picked.size() < count:
		return []
	return picked


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
