# CampSpawnController.gd
# Roster selection, player/walker spawning, behavior profiles, relationship home bias, offer giver pick.

class_name CampSpawnController
extends RefCounted

const WALKER_SCENE := preload("res://Scenes/CampRosterWalker.tscn")
const CAMP_SPRITE_SCALE: Vector2 = Vector2(0.22, 0.22)
const CAMP_BEHAVIOR_DB = preload("res://Scripts/Narrative/CampBehaviorDB.gd")
const CAMP_ROUTINE_DB = preload("res://Scripts/Narrative/CampRoutineDB.gd")

const WATCHFUL_ROLE_TAGS: Array[String] = ["watch", "duty", "training", "post", "wall", "perimeter", "guard"]

const DEBUG_TEST_CAMP_UNIT_NAMES: Array[String] = [
	"Kaelen",
	"Celia",
	"Sorrel",
	"Tariq",
	"Tamsin Reed",
	"Branik",
	"Nyx",
	"Hest \"Sparks\"",
	"Liora",
	"Brother Alden",
	"Garrick Vale",
	"Sabine Varr",
]
const DEBUG_TEST_CAMP_UNIT_RESOURCE_PATHS: Dictionary = {
	"Kaelen": ["res://Resources/Units/PlayableRoster/02_Kaelen.tres"],
	"Branik": ["res://Resources/Units/PlayableRoster/03_Branik.tres"],
	"Liora": ["res://Resources/Units/PlayableRoster/04_Liora.tres"],
	"Nyx": ["res://Resources/Units/PlayableRoster/05_Nyx.tres"],
	"Sorrel": ["res://Resources/Units/PlayableRoster/06_Sorrel.tres"],
	"Celia": ["res://Resources/Units/PlayableRoster/08_Celia.tres"],
	"Tariq": ["res://Resources/Units/PlayableRoster/11_Tariq.tres"],
	"Tamsin Reed": ["res://Resources/Units/PlayableRoster/14_Tamsin_Reed.tres"],
	"Hest \"Sparks\"": ["res://Resources/Units/PlayableRoster/15_Hest_Sparks.tres"],
	"Brother Alden": ["res://Resources/Units/PlayableRoster/16_Brother_Alden.tres"],
	"Garrick Vale": ["res://Resources/Units/PlayableRoster/18_Garrick_Vale.tres"],
	"Sabine Varr": ["res://Resources/Units/PlayableRoster/19_Sabine_Varr.tres"],
}

var _explore: Node2D
var _ctx: CampContext
var _requests: CampRequestController
var _debug_spawn_count_logged_once: bool = false


func _init(explore: Node2D, ctx: CampContext, requests: CampRequestController) -> void:
	_explore = explore
	_ctx = ctx
	_requests = requests


func gather_camp_zones() -> void:
	_ctx.camp_zones.clear()
	var nodes: Array = _explore.get_tree().get_nodes_in_group("camp_behavior_zone")
	for n in nodes:
		_ctx.camp_zones.append(n)


func _read_zone_capacity(z: Node) -> int:
	if z is CampBehaviorZone:
		return maxi(1, int((z as CampBehaviorZone).capacity))
	if z != null and "capacity" in z:
		return maxi(1, int(z.capacity))
	return 8


func _read_zone_weight(z: Node) -> float:
	if z == null:
		return 1.0
	if "weight" in z:
		return maxf(0.05, float(z.weight))
	return 1.0


func _read_zone_social_heat(z: Node) -> float:
	if z is CampBehaviorZone:
		return maxf(0.0, (z as CampBehaviorZone).social_heat)
	if z != null and "social_heat" in z:
		return maxf(0.0, float(z.social_heat))
	return 0.0


func _zone_time_allows(z: Node, time_block: String) -> bool:
	var blocks: Array = []
	if z is CampBehaviorZone:
		blocks = (z as CampBehaviorZone).preferred_time_blocks
	elif z != null and "preferred_time_blocks" in z:
		var pv: Variant = z.preferred_time_blocks
		if pv is Array:
			blocks = pv as Array
	if blocks.is_empty():
		return true
	var tb: String = str(time_block).strip_edges().to_lower()
	return tb in blocks


func _zone_has_watchful_role(z: Node) -> bool:
	if z == null:
		return false
	var tags: Array = []
	if z is CampBehaviorZone:
		tags = (z as CampBehaviorZone).role_tags.duplicate()
	elif "role_tags" in z:
		var rv: Variant = z.role_tags
		if rv is Array:
			tags = (rv as Array).duplicate()
	for raw_t in tags:
		var lt: String = str(raw_t).strip_edges().to_lower()
		for w in WATCHFUL_ROLE_TAGS:
			if lt == str(w).strip_edges().to_lower():
				return true
	return false


func _zone_types_priority_for_profile(merged: Dictionary, idle_style: String) -> Array[String]:
	var out: Array[String] = []
	var preferred: Variant = merged.get("preferred_zones", [])
	var secondary: Variant = merged.get("secondary_zones", [])
	if preferred is Array:
		for zz in preferred:
			var s: String = str(zz).strip_edges()
			if s != "" and s not in out:
				out.append(s)
	if secondary is Array:
		for zz2 in secondary:
			var s2: String = str(zz2).strip_edges()
			if s2 != "" and s2 not in out:
				out.append(s2)
	var watchful: bool = idle_style in ["look_out", "check_gear", "inspect_wall", "read_notes"]
	if watchful:
		for wt in ["watch_post", "wall", "map_table", "workbench"]:
			if wt not in out:
				out.append(wt)
	var warmish: bool = idle_style in ["warm_hands", "neutral", "tinker_small", "pray_quietly"]
	if warmish:
		for ht in ["fire", "bench"]:
			if ht not in out:
				out.append(ht)
	return out


func _score_zone_candidate(z: Node, want_type: String, tier: float, idle_style: String, occ: Dictionary) -> float:
	if not is_instance_valid(z) or not ("zone_type" in z):
		return -1e9
	var zt: String = str(z.zone_type).strip_edges()
	if zt != want_type:
		return -1e9
	var tb: String = str(_ctx.active_time_block).strip_edges().to_lower()
	if not _zone_time_allows(z, tb):
		return -1e9
	var cap_v: int = _read_zone_capacity(z)
	var id: String = str(z.get_instance_id())
	var c: int = int(occ.get(id, 0))
	if c >= cap_v:
		return -800000.0 + tier * 0.05
	var warm_w: float = 0.38
	if idle_style in ["warm_hands", "neutral", "tinker_small", "pray_quietly"]:
		warm_w = 1.0
	var watchful: bool = idle_style in ["look_out", "check_gear", "inspect_wall", "read_notes"]
	var sc: float = tier
	sc += _read_zone_weight(z) * 4.5
	sc += _read_zone_social_heat(z) * 15.0 * warm_w
	if watchful and _zone_has_watchful_role(z):
		sc += 11.0
	if c > 0:
		sc -= float(c) * 5.5
	return sc


func _random_point_in_zone(z: Node, fallback: Vector2) -> Vector2:
	if not is_instance_valid(z):
		return fallback
	var center: Vector2 = z.global_position
	var rad: float = 32.0
	if "radius" in z:
		rad = maxf(4.0, float(z.radius))
	var j: float = rad * 0.38
	var p: Vector2 = center + Vector2(randf_range(-j, j), randf_range(-j, j))
	p.x = clampf(p.x, _ctx.walk_min.x, _ctx.walk_max.x)
	p.y = clampf(p.y, _ctx.walk_min.y, _ctx.walk_max.y)
	return p


func _pick_zone_home_for_walker(merged: Dictionary, _unit_name: String, anchor_global: Vector2, occ: Dictionary) -> Dictionary:
	if _ctx.camp_zones.is_empty():
		return {"pos": anchor_global, "zone": null}
	var idle_style: String = str(merged.get("idle_style", "neutral")).strip_edges().to_lower()
	var types: Array[String] = _zone_types_priority_for_profile(merged, idle_style)
	var best_score: float = -1e10
	var best_zone: Node = null
	for ti in range(types.size()):
		var ztype: String = types[ti]
		var tier: float = 112.0 - float(ti) * 1.35
		for zn in _ctx.camp_zones:
			var raw: float = _score_zone_candidate(zn, ztype, tier, idle_style, occ)
			if raw > best_score:
				best_score = raw
				best_zone = zn
	if best_zone == null or best_score < -7e5:
		return {"pos": anchor_global, "zone": null}
	return {"pos": _random_point_in_zone(best_zone, anchor_global), "zone": best_zone}


func prepend_unique_zones(existing: Variant, preferred_first: Array[String]) -> Array:
	var out: Array = []
	for z in preferred_first:
		var key: String = str(z).strip_edges()
		if key != "" and key not in out:
			out.append(key)
	if existing is Array:
		for z2 in existing:
			var key2: String = str(z2).strip_edges()
			if key2 != "" and key2 not in out:
				out.append(key2)
	return out


func apply_condition_behavior_bias(profile: Dictionary, unit_name: String) -> Dictionary:
	var merged: Dictionary = profile.duplicate(true)
	if not CampaignManager:
		return merged
	var injured: bool = CampaignManager.is_unit_injured(unit_name)
	var fatigued: bool = CampaignManager.is_unit_fatigued(unit_name)
	if not injured and not fatigued:
		return merged
	if injured:
		merged["preferred_zones"] = prepend_unique_zones(merged.get("preferred_zones", []), ["infirmary", "bench", "fire"])
		merged["secondary_zones"] = prepend_unique_zones(merged.get("secondary_zones", []), ["bench", "fire", "wagon"])
		var freq_i: float = float(merged.get("movement_frequency", 0.5))
		merged["movement_frequency"] = clampf(freq_i * 0.72, 0.15, 1.0)
	elif fatigued:
		merged["preferred_zones"] = prepend_unique_zones(merged.get("preferred_zones", []), ["bench", "fire", "wagon"])
		merged["secondary_zones"] = prepend_unique_zones(merged.get("secondary_zones", []), ["bench", "fire"])
		var freq_f: float = float(merged.get("movement_frequency", 0.5))
		merged["movement_frequency"] = clampf(freq_f * 0.85, 0.15, 1.0)
	return merged


func resource_prop_or(res: Resource, prop: String, fallback: Variant) -> Variant:
	if res == null:
		return fallback
	var value: Variant = res.get(prop)
	return value if value != null else fallback


func build_roster_entry_from_unit_data(unit_data: Resource) -> Dictionary:
	var name_raw: String = str(resource_prop_or(unit_data, "display_name", "")).strip_edges()
	var unit_name: String = _ctx.normalize_unit_name_for_matching(name_raw)
	var max_hp_v: int = int(resource_prop_or(unit_data, "max_hp", 1))
	max_hp_v = maxi(1, max_hp_v)
	var class_data: Variant = unit_data.get("character_class")
	var move_range_v: int = int(class_data.get("move_range")) if class_data != null and class_data.get("move_range") != null else 5
	var move_type_v: int = int(class_data.get("move_type")) if class_data != null and class_data.get("move_type") != null else 0
	var unit_class_name: String = str(class_data.get("job_name")) if class_data != null and class_data.get("job_name") != null else ""
	var starting_weapon: Variant = resource_prop_or(unit_data, "starting_weapon", null)
	var equipped_weapon: Variant = starting_weapon
	if equipped_weapon != null and CampaignManager != null and CampaignManager.has_method("duplicate_item"):
		equipped_weapon = CampaignManager.duplicate_item(equipped_weapon)
	var inventory: Array = []
	if equipped_weapon != null:
		inventory.append(equipped_weapon)
	var ability_name: String = str(resource_prop_or(unit_data, "ability", ""))
	return {
		"unit_name": unit_name,
		"unit_class": unit_class_name,
		"class_name": unit_class_name,
		"is_promoted": false,
		"data": unit_data,
		"data_path_hint": str(unit_data.resource_path).strip_edges(),
		"class_data": class_data,
		"level": 1,
		"experience": 0,
		"max_hp": max_hp_v,
		"current_hp": max_hp_v,
		"strength": int(resource_prop_or(unit_data, "strength", 1)),
		"magic": int(resource_prop_or(unit_data, "magic", 0)),
		"defense": int(resource_prop_or(unit_data, "defense", 0)),
		"resistance": int(resource_prop_or(unit_data, "resistance", 0)),
		"speed": int(resource_prop_or(unit_data, "speed", 0)),
		"agility": int(resource_prop_or(unit_data, "agility", 0)),
		"move_range": move_range_v,
		"move_type": move_type_v,
		"equipped_weapon": equipped_weapon,
		"inventory": inventory,
		"portrait": resource_prop_or(unit_data, "portrait", null),
		"battle_sprite": resource_prop_or(unit_data, "unit_sprite", null),
		"ability": ability_name,
		"skill_points": 0,
		"unlocked_skills": [],
		"unlocked_abilities": [ability_name] if ability_name != "" else [],
		"unit_tags": [],
	}


func load_first_existing_resource(paths: Array) -> Dictionary:
	for p in paths:
		var path_str: String = str(p).strip_edges()
		if path_str == "":
			continue
		var res: Variant = load(path_str)
		if res != null and res is Resource:
			return {
				"resource": res as Resource,
				"path": path_str,
			}
	return {}


func get_debug_test_camp_roster(base_roster: Array, debug_use_test_camp_roster: bool, debug_replace_roster_entirely: bool) -> Array:
	var out: Array = []
	if not debug_use_test_camp_roster:
		return base_roster
	if not debug_replace_roster_entirely:
		for entry in base_roster:
			if entry is Dictionary:
				out.append((entry as Dictionary).duplicate(true))

	var existing_names: Dictionary = {}
	for entry2 in out:
		if not (entry2 is Dictionary):
			continue
		var n0: String = _ctx.normalize_unit_name_for_matching(str((entry2 as Dictionary).get("unit_name", "")))
		if n0 != "":
			existing_names[n0] = true

	var wanted: Dictionary = {}
	for n in DEBUG_TEST_CAMP_UNIT_NAMES:
		var wn: String = _ctx.normalize_unit_name_for_matching(str(n))
		if wn != "":
			wanted[wn] = true
	var scanned_files: int = 0
	var accepted_names: Array[String] = []
	for desired_name in DEBUG_TEST_CAMP_UNIT_NAMES:
		var desired_norm: String = _ctx.normalize_unit_name_for_matching(desired_name)
		if desired_norm == "" or not wanted.has(desired_norm):
			continue
		if existing_names.has(desired_norm):
			continue
		var path_options: Array = DEBUG_TEST_CAMP_UNIT_RESOURCE_PATHS.get(desired_name, [])
		scanned_files += path_options.size()
		var resolved: Dictionary = load_first_existing_resource(path_options)
		if resolved.is_empty():
			if debug_use_test_camp_roster:
				print("DEBUG_CAMP_LOAD name=", desired_norm, " path=<missing>")
			continue
		var unit_data: Resource = resolved.get("resource", null)
		var loaded_path: String = str(resolved.get("path", "")).strip_edges()
		if unit_data == null:
			continue
		var display_name: String = _ctx.normalize_unit_name_for_matching(str(resource_prop_or(unit_data, "display_name", "")))
		var resolved_name: String = display_name if display_name != "" else desired_norm
		if debug_use_test_camp_roster:
			print("DEBUG_CAMP_LOAD path=", loaded_path)
			print("DEBUG_CAMP_NAME display_name=", display_name, " desired=", desired_norm)
		if resolved_name == "" or not wanted.has(resolved_name):
			continue
		if existing_names.has(resolved_name):
			continue
		out.append(build_roster_entry_from_unit_data(unit_data))
		existing_names[resolved_name] = true
		accepted_names.append(resolved_name)

	var ordered: Array = []
	var by_name: Dictionary = {}
	for entry3 in out:
		if not (entry3 is Dictionary):
			continue
		var d: Dictionary = entry3
		by_name[_ctx.normalize_unit_name_for_matching(str(d.get("unit_name", "")))] = d
	for desired in DEBUG_TEST_CAMP_UNIT_NAMES:
		var dn: String = _ctx.normalize_unit_name_for_matching(str(desired))
		if by_name.has(dn):
			ordered.append((by_name[dn] as Dictionary).duplicate(true))
	var final_roster: Array = ordered if not ordered.is_empty() else out
	if debug_use_test_camp_roster:
		print("DEBUG_CAMP_ROSTER_COUNT scanned=", scanned_files, " accepted=", accepted_names.size(), " final=", final_roster.size())
	if debug_replace_roster_entirely and final_roster.is_empty():
		print("CAMP_DEBUG_TEST_ROSTER fallback to base roster (debug list resolved empty).")
		return base_roster
	return final_roster


func get_camp_spawn_roster(debug_use_test_camp_roster: bool, debug_replace_roster_entirely: bool) -> Array:
	var base_roster: Array = CampaignManager.player_roster if CampaignManager else []
	var roster: Array = get_debug_test_camp_roster(base_roster, debug_use_test_camp_roster, debug_replace_roster_entirely)
	if roster.is_empty() and not base_roster.is_empty():
		roster = base_roster
		if debug_use_test_camp_roster:
			print("CAMP_DEBUG_SPAWN_ROSTER fallback applied from base roster, size=", roster.size())
	if debug_use_test_camp_roster:
		var names: Array[String] = []
		for e in roster:
			if e is Dictionary:
				var n: String = str((e as Dictionary).get("unit_name", "")).strip_edges()
				if n != "":
					names.append(n)
		print("DEBUG_CAMP_ROSTER_NAMES ", names)
		print("CAMP_DEBUG_SPAWN_ROSTER size=", roster.size(), " names=", names)
	return roster


func apply_relationship_home_bias() -> void:
	if not CampaignManager:
		return
	var adjusted_count: int = 0
	for node in _ctx.walker_nodes:
		if adjusted_count >= 8:
			break
		if not (node is CampRosterWalker):
			continue
		var walker: CampRosterWalker = node as CampRosterWalker
		var source_name: String = str(walker.unit_name).strip_edges()
		if source_name == "":
			continue
		var best_partner: CampRosterWalker = null
		var best_score: float = 0.1
		for other_node in _ctx.walker_nodes:
			if other_node == node or not (other_node is CampRosterWalker):
				continue
			var other: CampRosterWalker = other_node as CampRosterWalker
			var other_name: String = str(other.unit_name).strip_edges()
			if other_name == "":
				continue
			var familiarity: int = _ctx.get_pair_familiarity(source_name, other_name)
			if familiarity < 1:
				continue
			var social_bias: float = _ctx.get_pair_social_bias(source_name, other_name)
			if social_bias <= 0.1:
				continue
			var dist: float = walker.home_position.distance_to(other.home_position)
			if dist > 360.0:
				continue
			var score: float = social_bias - clampf(dist / 900.0, 0.0, 0.35)
			if score > best_score:
				best_score = score
				best_partner = other
		if best_partner == null:
			continue
		var to_partner: Vector2 = best_partner.home_position - walker.home_position
		var distance_to_partner: float = to_partner.length()
		if distance_to_partner <= 0.001:
			continue
		var nudge_len: float = minf(30.0, minf(distance_to_partner * 0.45, 12.0 + best_score * 24.0))
		if nudge_len <= 0.0:
			continue
		var nudged_home: Vector2 = walker.home_position + to_partner.normalized() * nudge_len
		nudged_home.x = clampf(nudged_home.x, _ctx.walk_min.x, _ctx.walk_max.x)
		nudged_home.y = clampf(nudged_home.y, _ctx.walk_min.y, _ctx.walk_max.y)
		walker.home_position = nudged_home
		adjusted_count += 1


## Returns [player_root, sprite] for the camp explore scene to keep node refs in sync.
func spawn_player(player_ref: Node2D) -> Array:
	var p: Node2D = player_ref
	if p == null:
		p = Node2D.new()
		p.name = "Player"
		_explore.add_child(p)
	var sprite: Sprite2D = p.get_node_or_null("Sprite2D")
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		p.add_child(sprite)
	var roster: Array = CampaignManager.player_roster if CampaignManager else []
	if roster.size() > 0:
		var first: Dictionary = roster[0]
		var tex: Variant = first.get("battle_sprite", null)
		if tex is Texture2D:
			sprite.texture = tex
		else:
			sprite.texture = load("res://icon.svg") as Texture2D
	else:
		sprite.texture = load("res://icon.svg") as Texture2D
	sprite.scale = CAMP_SPRITE_SCALE
	p.position = (_ctx.walk_min + _ctx.walk_max) * 0.5
	return [p, sprite]


func spawn_walkers(walkers_container: Node2D, debug_use_test_camp_roster: bool, debug_replace_roster_entirely: bool) -> Node2D:
	var wc: Node2D = walkers_container
	if wc == null:
		wc = Node2D.new()
		wc.name = "Walkers"
		_explore.add_child(wc)
	var roster: Array = get_camp_spawn_roster(debug_use_test_camp_roster, debug_replace_roster_entirely)
	if debug_use_test_camp_roster and not _debug_spawn_count_logged_once:
		print("DEBUG_CAMP_SPAWN_FINAL_ROSTER_SIZE ", roster.size())
		_debug_spawn_count_logged_once = true
	if roster.is_empty():
		return wc
	var context: Dictionary = _ctx.build_camp_context_dict()
	var anchors: Array[Vector2] = []
	var w: float = _ctx.walk_max.x - _ctx.walk_min.x
	var h: float = _ctx.walk_max.y - _ctx.walk_min.y
	var cols: int = maxi(2, int(sqrt(roster.size())))
	var rows: int = int(ceil(float(roster.size()) / float(cols))) if cols > 0 else 0
	for i in roster.size():
		var col: int = i % cols
		var row: int = int(float(i) / float(cols)) if cols > 0 else 0
		var fx: float = (float(col) + 0.5) / float(cols)
		var fy: float = (float(row) + 0.5) / float(rows)
		anchors.append(Vector2(_ctx.walk_min.x + w * fx, _ctx.walk_min.y + h * fy))
	var zone_occupancy: Dictionary = {}
	for i in roster.size():
		var entry: Dictionary = (roster[i] as Dictionary).duplicate(true)
		entry["unit_name"] = _ctx.normalize_unit_name_for_matching(str(entry.get("unit_name", "")))
		var inst: Node = WALKER_SCENE.instantiate()
		wc.add_child(inst)
		var anchor_g: Vector2 = anchors[i] if i < anchors.size() else (_ctx.walk_min + _ctx.walk_max) * 0.5
		if inst is CampRosterWalker:
			var walker: CampRosterWalker = inst as CampRosterWalker
			walker.setup_from_roster(entry)
			var base_profile: Dictionary = CAMP_BEHAVIOR_DB.get_profile(walker.unit_name)
			var routine: Dictionary = CAMP_ROUTINE_DB.get_best_routine(walker.unit_name, context)
			var merged: Dictionary = base_profile.duplicate()
			if not routine.is_empty():
				if routine.has("preferred_zones"):
					merged["preferred_zones"] = routine.get("preferred_zones")
				if routine.has("secondary_zones"):
					merged["secondary_zones"] = routine.get("secondary_zones")
				if routine.has("movement_frequency"):
					merged["movement_frequency"] = routine.get("movement_frequency")
				if routine.has("idle_style"):
					merged["idle_style"] = routine.get("idle_style")
			merged = apply_condition_behavior_bias(merged, walker.unit_name)
			var pick: Dictionary = _pick_zone_home_for_walker(merged, walker.unit_name, anchor_g, zone_occupancy)
			var home_g: Vector2 = pick.get("pos", anchor_g)
			var znode: Node = pick.get("zone", null)
			inst.global_position = home_g
			walker.home_position = inst.global_position
			walker.roam_radius = 60.0
			if znode != null:
				var zid: String = str(znode.get_instance_id())
				zone_occupancy[zid] = int(zone_occupancy.get(zid, 0)) + 1
			if znode != null and znode is CampBehaviorZone:
				var ov: String = str((znode as CampBehaviorZone).idle_style_override).strip_edges()
				if ov != "":
					merged["idle_style"] = ov
			walker.apply_behavior_profile(merged)
			if CampaignManager:
				walker.apply_condition_flags(
					CampaignManager.is_unit_injured(walker.unit_name),
					CampaignManager.is_unit_fatigued(walker.unit_name)
				)
			walker.set_behavior_zones(_ctx.camp_zones)
			walker.start_behavior()
		else:
			inst.global_position = anchor_g
		_ctx.walker_nodes.append(inst)
	apply_relationship_home_bias()
	var status: String = _requests.get_camp_request_status()
	if status != "active" and status != "ready_to_turn_in" and status != "failed" and CampaignManager:
		var roster_names: Array = []
		var item_names: Array = _requests.get_requestable_item_names()
		for walk_node in _ctx.walker_nodes:
			if walk_node is CampRosterWalker:
				roster_names.append((walk_node as CampRosterWalker).unit_name)
		var best_name: String = ""
		var best_offer: Dictionary = {}
		var best_score: int = -99999
		var progress_level: int = CampaignManager.camp_request_progress_level
		var next_eligible: Dictionary = CampaignManager.camp_request_unit_next_eligible_level
		var recent: Array = CampaignManager.camp_request_recent_givers
		var completed_by: Dictionary = CampaignManager.camp_requests_completed_by_unit
		for w2 in _ctx.walker_nodes:
			if not (w2 is CampRosterWalker):
				continue
			var walker2: CampRosterWalker = w2 as CampRosterWalker
			var name_str: String = walker2.unit_name
			var score: int = 0
			var completed: int = int(completed_by.get(name_str, 0))
			if completed == 0:
				score += 20
			elif completed == 1:
				score += 10
			if name_str in recent:
				score -= 30
			var threshold: int = int(next_eligible.get(name_str, -1))
			if threshold >= 0 and progress_level < threshold:
				score -= 100
			var tiebreak: int = (name_str.hash() + progress_level) % 1000
			score = score * 1000 + (500 - tiebreak)
			var giver_tier: String = CampaignManager.get_avatar_relationship_tier(name_str) if CampaignManager else ""
			var personal_eligible: bool = CampaignManager.is_personal_quest_eligible(name_str) if CampaignManager else false
			var offer: Dictionary = CampRequestDB.get_offer(name_str, CampRequestDB.get_personality(walker2.unit_data.get("data", null), name_str), roster_names, item_names, false, giver_tier, personal_eligible)
			if offer.is_empty():
				continue
			if score > best_score:
				best_score = score
				best_name = name_str
				best_offer = offer
		if best_name != "":
			_requests.offer_giver_name = best_name
			_requests.offer_is_personal = str(best_offer.get("request_depth", "")).strip_edges().to_lower() == "personal"
			print("EXPLORE_SELECTED_GIVER =", best_name)
			print("EXPLORE_SELECTED_OFFER =", best_offer)
			print("EXPLORE_STATUS =", str(CampaignManager.camp_request_status) if CampaignManager else "")
			print("EXPLORE_GIVER_STORED =", _requests.offer_giver_name)
	return wc
