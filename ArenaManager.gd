extends Node

## Arena: cloud roster snapshots, MMR tiers, Silent Wolf leaderboards, and UI helpers.
## MMR change previews match [BattleField] arena resolution; gold/token previews match [CampaignManager.record_arena_win].
##
## Persistence:
## - **Other players** fight the ghost built from your last [push_team_to_cloud] snapshot (Silent Wolf metadata). That lives on the service, not your PC.
## - **Your** [local_arena_team] is rebuilt from the campaign save via [restore_local_arena_team_from_saved_identity] so battles still deploy after reload.
## - **MMR / tokens / streak** live on [CampaignManager] and are saved with the campaign.

# --- Match snapshot (last arena battle, for CityMenu animations) ---
var current_opponent_data: Dictionary = {}
var local_arena_team: Array = []
var local_power_rating: int = 0

var last_match_result: String = ""
var last_match_mmr_change: int = 0
var last_match_old_mmr: int = 1000
var last_match_new_mmr: int = 1000
var last_match_gold_reward: int = 0
var last_match_token_reward: int = 0

## Filled by [fetch_arena_opponents]: why the opponent list might be empty (for status UI).
var last_opponent_fetch_hint: String = ""
## Raw rows returned by Silent Wolf for the arena board (before filtering). Useful for diagnostics.
var last_opponent_fetch_raw_count: int = 0

# ---------------------------------------------------------------------------
# Rank tiers (single source of truth for names, colors, icons, bounds)
# ---------------------------------------------------------------------------
const RANK_MAX_MMR_DISPLAY: int = 2400
## Hard cap for persisted / leaderboard MMR (save edits, bad payloads).
const ARENA_MMR_ABSOLUTE_MAX: int = 5000
## Max units + dragons combined in arena squad identity / ghost payloads.
const ARENA_MAX_SQUAD_SLOTS: int = 3
const ARENA_GHOST_STAT_MAX: int = 120
const ARENA_GHOST_HP_MAX: int = 999
const ARENA_GHOST_POWER_RATING_MAX: int = 200000
const ARENA_GHOST_DISPLAY_NAME_MAX: int = 64
const ARENA_GHOST_STRING_FIELD_MAX: int = 512
## Campaign save / economy guards (aligned with [CampaignManager] clamps).
const GLADIATOR_TOKENS_MAX: int = 999999
const ARENA_WIN_STREAK_MAX: int = 999

const RANK_TIERS: Array[Dictionary] = [
	{
		"min": 0,
		"max": 1200,
		"name": "Bronze",
		"color": Color(0.80, 0.50, 0.20),
		"icon": "res://Assets/Ranks/rank_bronze.png"
	},
	{
		"min": 1200,
		"max": 1400,
		"name": "Silver",
		"color": Color(0.75, 0.75, 0.75),
		"icon": "res://Assets/Ranks/rank_silver.png"
	},
	{
		"min": 1400,
		"max": 1600,
		"name": "Gold",
		"color": Color(1.00, 0.85, 0.20),
		"icon": "res://Assets/Ranks/rank_gold.png"
	},
	{
		"min": 1600,
		"max": 1800,
		"name": "Platinum",
		"color": Color(0.30, 0.80, 0.80),
		"icon": "res://Assets/Ranks/rank_platinum.png"
	},
	{
		"min": 1800,
		"max": 2000,
		"name": "Diamond",
		"color": Color(0.70, 0.30, 1.00),
		"icon": "res://Assets/Ranks/rank_diamond.png"
	},
	{
		"min": 2000,
		"max": RANK_MAX_MMR_DISPLAY,
		"name": "Grandmaster",
		"color": Color(1.00, 0.20, 0.20),
		"icon": "res://Assets/Ranks/rank_grandmaster.png"
	},
]

# Cooldown after fetching opponents before the list can be refreshed again (seconds).
const OPPONENT_REFRESH_COOLDOWN_SEC: float = 300.0

var _last_opponent_fetch_time_sec: float = -1.0


func _ready() -> void:
	CoopOnlineServiceConfig.ensure_silent_wolf_ready()


# ===========================================================================
# Ranks & icons
# ===========================================================================

func get_rank_icon(mmr: int) -> Texture2D:
	var data: Dictionary = get_rank_data(mmr)
	var idx: int = clampi(int(data.get("index", 0)), 0, RANK_TIERS.size() - 1)
	var path: String = str(RANK_TIERS[idx].get("icon", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func clamp_mmr_int(v: int) -> int:
	return clampi(v, 0, ARENA_MMR_ABSOLUTE_MAX)


## Leaderboard / opponent row [score] may be missing, non-numeric, or tampered.
func sanitize_leaderboard_score_mmr(raw: Variant) -> int:
	var n: int = 1000
	if raw is int or raw is float:
		n = int(raw)
	else:
		var s: String = str(raw).strip_edges()
		if s.is_valid_int():
			n = int(s)
		elif s.is_valid_float():
			n = int(round(float(s)))
		else:
			n = 1000
	return clamp_mmr_int(n)


func get_local_mmr() -> int:
	if CampaignManager.get("arena_mmr") != null:
		return clamp_mmr_int(int(CampaignManager.arena_mmr))
	return 1000


func set_local_mmr(new_mmr: int) -> void:
	if CampaignManager.get("arena_mmr") != null:
		CampaignManager.arena_mmr = clamp_mmr_int(new_mmr)


func get_rank_data(mmr: int) -> Dictionary:
	var last_i: int = RANK_TIERS.size() - 1
	for i in range(RANK_TIERS.size()):
		var t: Dictionary = RANK_TIERS[i]
		var t_min: int = int(t["min"])
		var t_max: int = int(t["max"])
		if i == last_i:
			if mmr >= t_min:
				return {
					"name": t["name"],
					"color": t["color"],
					"min": t_min,
					"max": t_max,
					"index": i
				}
		elif mmr >= t_min and mmr < t_max:
			return {
				"name": t["name"],
				"color": t["color"],
				"min": t_min,
				"max": t_max,
				"index": i
			}
	return {
		"name": RANK_TIERS[0]["name"],
		"color": RANK_TIERS[0]["color"],
		"min": int(RANK_TIERS[0]["min"]),
		"max": int(RANK_TIERS[0]["max"]),
		"index": 0
	}


func get_rank_bounds(mmr: int) -> Dictionary:
	var data: Dictionary = get_rank_data(mmr)
	return {"min": int(data["min"]), "max": int(data["max"])}


func get_rank_fill_ratio(mmr: int) -> float:
	var bounds: Dictionary = get_rank_bounds(mmr)
	var span: int = max(1, int(bounds["max"]) - int(bounds["min"]))
	return clampf((float(mmr) - float(bounds["min"])) / float(span), 0.0, 1.0)


func get_next_rank_info(current_mmr: int) -> Dictionary:
	if current_mmr >= RANK_MAX_MMR_DISPLAY:
		return {"name": "", "mmr_needed": current_mmr, "points_to_go": 0, "is_max_rank": true}
	var data: Dictionary = get_rank_data(current_mmr)
	var idx: int = int(data["index"])
	if idx >= RANK_TIERS.size() - 1:
		return {"name": "", "mmr_needed": current_mmr, "points_to_go": 0, "is_max_rank": true}
	var next_t: Dictionary = RANK_TIERS[idx + 1]
	var next_min: int = int(next_t["min"])
	return {
		"name": str(next_t["name"]),
		"mmr_needed": next_min,
		"points_to_go": maxi(0, next_min - current_mmr),
		"is_max_rank": false
	}


func format_signed(delta: int) -> String:
	return ("+" if delta >= 0 else "") + str(delta)


# ===========================================================================
# Combat power & snapshots
# ===========================================================================

func _calculate_combat_power(team: Array) -> int:
	var power: int = 0
	for unit in team:
		if unit.get("is_dragon", false) or unit.has("element"):
			power += int(unit.get("generation", 1)) + int(unit.get("max_hp", 0)) + int(unit.get("strength", 0)) + int(unit.get("magic", 0)) + int(unit.get("defense", 0)) + int(unit.get("resistance", 0)) + int(unit.get("speed", 0)) + int(unit.get("agility", 0))
		else:
			power += int(unit.get("level", 1)) + int(unit.get("max_hp", 0)) + int(unit.get("strength", 0)) + int(unit.get("magic", 0)) + int(unit.get("defense", 0)) + int(unit.get("resistance", 0)) + int(unit.get("speed", 0)) + int(unit.get("agility", 0))
	return power


func _generate_player_snapshot_dict(selected_team: Array) -> Dictionary:
	var snapshot: Dictionary = {
		"player_id": get_safe_player_id(),
		"player_name": "Gladiator",
		"power_rating": 0,
		"roster": [],
		"dragons": []
	}

	if CampaignManager.get("custom_avatar") != null and CampaignManager.custom_avatar.has("name"):
		snapshot["player_name"] = CampaignManager.custom_avatar["name"]
	else:
		for u in CampaignManager.player_roster:
			if u.get("is_custom_avatar") == true:
				snapshot["player_name"] = u.get("unit_name", "Hero")
				break

	var display_name: String = str(snapshot.get("player_name", "Gladiator")).strip_edges()
	if display_name.is_empty() or display_name == "Gladiator":
		var steam_svc: Node = Engine.get_main_loop().root.get_node_or_null("/root/SteamService")
		if steam_svc != null and steam_svc.has_method("get_steam_persona_name"):
			var pn: String = str(steam_svc.call("get_steam_persona_name")).strip_edges()
			if pn != "":
				snapshot["player_name"] = pn

	for unit in selected_team:
		if unit.get("is_dragon", false) or unit.has("element"):
			var d_data: Dictionary = {
				"name": unit.get("name", "Dragon"),
				"element": unit.get("element", "Fire"),
				"generation": unit.get("generation", 1),
				"traits": unit.get("traits", []).duplicate(),
				"stage": unit.get("stage", 1),
				"max_hp": unit.get("max_hp", 15),
				"strength": unit.get("strength", 5),
				"magic": unit.get("magic", 5),
				"defense": unit.get("defense", 5),
				"resistance": unit.get("resistance", 4),
				"speed": unit.get("speed", 4),
				"agility": unit.get("agility", 3)
			}
			snapshot["dragons"].append(d_data)
		else:
			var s_path: String = ""
			var p_path: String = ""
			var s_tex = unit.get("battle_sprite")
			if s_tex == null and unit.get("data") != null:
				s_tex = unit.data.get("unit_sprite")
			if s_tex == null and unit.get("data") != null:
				s_tex = unit.data.get("battle_sprite")
			if s_tex != null and s_tex is Texture2D and str(s_tex.resource_path) != "":
				s_path = s_tex.resource_path

			var p_tex = unit.get("portrait")
			if p_tex == null and unit.get("data") != null:
				p_tex = unit.data.get("portrait")
			if p_tex != null and p_tex is Texture2D and str(p_tex.resource_path) != "":
				p_path = p_tex.resource_path

			var unit_data: Dictionary = {
				"unit_name": unit.get("unit_name", unit.get("name", "Fighter")),
				"class": unit.get("unit_class", unit.get("class", "Mercenary")),
				"level": unit.get("level", 1),
				"max_hp": unit.get("max_hp", 10),
				"current_hp": unit.get("max_hp", 10),
				"strength": unit.get("strength", 4),
				"magic": unit.get("magic", 0),
				"defense": unit.get("defense", 2),
				"resistance": unit.get("resistance", 1),
				"speed": unit.get("speed", 4),
				"agility": unit.get("agility", 3),
				"move_range": unit.get("move_range", 4),
				"ability": unit.get("ability", "None"),
				"unlocked_abilities": unit.get("unlocked_abilities", []).duplicate(),
				"sprite_path": s_path,
				"portrait_path": p_path
			}
			var wpn = unit.get("equipped_weapon")
			if wpn != null and typeof(wpn) == TYPE_OBJECT:
				var w_name = wpn.get("weapon_name")
				if w_name != null and str(w_name) != "":
					unit_data["equipped_weapon_name"] = str(w_name)
				else:
					unit_data["equipped_weapon_name"] = "Unarmed"
			else:
				unit_data["equipped_weapon_name"] = "Unarmed"

			snapshot["roster"].append(unit_data)

	var rating: int = _calculate_combat_power(selected_team)
	snapshot["power_rating"] = rating
	local_power_rating = rating
	return snapshot


func push_team_to_cloud(selected_team: Array) -> void:
	var snapshot: Dictionary = _generate_player_snapshot_dict(selected_team)
	var unique_board_name: String = get_safe_player_id()
	var current_mmr: int = get_local_mmr()
	await SilentWolf.Scores.save_score(unique_board_name, current_mmr, "arena", snapshot).sw_save_score_complete


func clear_local_arena_team_state() -> void:
	local_arena_team.clear()
	local_power_rating = 0
	current_opponent_data = {}


## Serializes the locked squad for [CampaignManager.arena_locked_team_identity] (campaign save / reload).
func build_arena_team_identity(team: Array) -> Array:
	var out: Array = []
	for u in team:
		if out.size() >= ARENA_MAX_SQUAD_SLOTS:
			break
		if u == null:
			continue
		var is_d: bool = bool(u.get("is_dragon", false)) or u.has("element")
		if is_d:
			out.append({
				"is_dragon": true,
				"uid": str(u.get("uid", "")).strip_edges(),
				"name": str(u.get("name", "Dragon")),
				"generation": int(u.get("generation", 1))
			})
		else:
			out.append({
				"is_dragon": false,
				"unit_name": str(u.get("unit_name", u.get("name", ""))).strip_edges(),
				"level": int(u.get("level", 1))
			})
	return out


func _find_unit_for_arena_identity(d: Dictionary) -> Variant:
	var want: String = str(d.get("unit_name", "")).strip_edges()
	var wl: int = int(d.get("level", 1))
	if want == "":
		return null
	for u in CampaignManager.player_roster:
		var un: String = str(u.get("unit_name", u.get("name", ""))).strip_edges()
		if un == want and int(u.get("level", 1)) == wl:
			return u
	return null


func _find_dragon_for_arena_identity(d: Dictionary) -> Variant:
	var uid: String = str(d.get("uid", "")).strip_edges()
	var nm: String = str(d.get("name", "")).strip_edges()
	var gen: int = int(d.get("generation", 1))
	for dr in DragonManager.player_dragons:
		if uid != "" and str(dr.get("uid", "")).strip_edges() == uid:
			return dr
		if str(dr.get("name", "")).strip_edges() == nm and int(dr.get("generation", 1)) == gen:
			return dr
	return null


## Rebuilds [local_arena_team] from [CampaignManager.arena_locked_team_identity] after [load_game].
func restore_local_arena_team_from_saved_identity() -> void:
	local_arena_team.clear()
	local_power_rating = 0
	var ids: Array = CampaignManager.arena_locked_team_identity
	if typeof(ids) != TYPE_ARRAY or ids.is_empty():
		return
	for id in ids:
		if local_arena_team.size() >= ARENA_MAX_SQUAD_SLOTS:
			break
		if typeof(id) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = id
		if bool(d.get("is_dragon", false)):
			var fd: Variant = _find_dragon_for_arena_identity(d)
			if fd != null:
				local_arena_team.append(fd)
		else:
			var fu: Variant = _find_unit_for_arena_identity(d)
			if fu != null:
				local_arena_team.append(fu)
	if not local_arena_team.is_empty():
		local_power_rating = _calculate_combat_power(local_arena_team)


# ===========================================================================
# Leaderboard & ghosts
# ===========================================================================

## Silent Wolf may return [code]metadata[/code] as a Dictionary, a JSON string, or omit it.
## [save_score] uses [code]player_name[/code] = device id; snapshot [code]player_id[/code] matches that when present.
func _parse_leaderboard_metadata(raw: Variant) -> Dictionary:
	if raw == null:
		return {}
	if raw is Dictionary:
		return raw.duplicate(true)
	if raw is String:
		var s: String = raw.strip_edges()
		if s.is_empty():
			return {}
		var parsed: Variant = JSON.parse_string(s)
		if parsed is Dictionary:
			return (parsed as Dictionary).duplicate(true)
	return {}


func _is_own_leaderboard_entry(my_id: String, score: Dictionary, meta: Dictionary) -> bool:
	if my_id.is_empty():
		return false
	var sw_player_name: String = str(score.get("player_name", "")).strip_edges()
	var meta_pid: String = str(meta.get("player_id", "")).strip_edges()
	if sw_player_name == my_id:
		return true
	if meta_pid != "" and meta_pid == my_id:
		return true
	return false


func _minimal_metadata_from_score_entry(score: Dictionary) -> Dictionary:
	var sw_name: String = str(score.get("player_name", "")).strip_edges()
	var label: String = "Challenger"
	if sw_name.length() >= 6:
		label = "Gladiator %s…" % sw_name.substr(0, 6)
	return {
		"player_id": sw_name,
		"player_name": label,
		"power_rating": 0,
		"roster": [],
		"dragons": []
	}


func fetch_arena_opponents(max_results: int = 10) -> Array:
	const POOL_SIZE: int = 50
	const DEFAULT_MMR_FALLBACK: int = 1000

	last_opponent_fetch_hint = ""
	last_opponent_fetch_raw_count = 0

	await SilentWolf.Scores.get_scores(POOL_SIZE, "arena").sw_get_scores_complete
	_mark_opponents_fetched()

	var raw_scores = SilentWolf.Scores.scores
	var all_scores: Array = raw_scores.duplicate() if raw_scores is Array else []
	last_opponent_fetch_raw_count = all_scores.size()

	var local_mmr: int = get_local_mmr()
	var my_id: String = get_safe_player_id()
	var candidates: Array = []
	var skipped_self: int = 0

	if all_scores.is_empty():
		last_opponent_fetch_hint = "No leaderboard entries yet (offline, empty board, or Silent Wolf still loading). Use Search for Challengers after you go online."
		return []

	for score in all_scores:
		if typeof(score) != TYPE_DICTIONARY:
			continue

		var meta: Dictionary = _parse_leaderboard_metadata(score.get("metadata", null))
		if _is_own_leaderboard_entry(my_id, score, meta):
			skipped_self += 1
			continue

		if meta.is_empty():
			meta = _minimal_metadata_from_score_entry(score)

		var clean_meta: Dictionary = validate_ghost_snapshot(meta)
		var opp_mmr: int = sanitize_leaderboard_score_mmr(score.get("score", DEFAULT_MMR_FALLBACK))
		score["score"] = opp_mmr
		var diff: int = abs(local_mmr - opp_mmr)
		score["match_diff"] = diff
		score["metadata"] = clean_meta
		candidates.append(score)

	candidates.sort_custom(func(a, b): return int(a.get("match_diff", 0)) < int(b.get("match_diff", 0)))

	if candidates.is_empty():
		if last_opponent_fetch_raw_count > 0 and skipped_self >= last_opponent_fetch_raw_count:
			last_opponent_fetch_hint = "You're the only gladiator on this board right now. Other players appear after they enter the arena and upload a team."
		elif last_opponent_fetch_raw_count > 0:
			last_opponent_fetch_hint = "No challengers could be loaded (entries were skipped). Try refreshing in a moment."
		else:
			last_opponent_fetch_hint = "No leaderboard entries yet."

	var final_opponents: Array = []
	var count: int = mini(max_results, candidates.size())
	for i in range(count):
		final_opponents.append(candidates[i])
	return final_opponents


func _truncate_ghost_str(s: String, max_len: int) -> String:
	var t: String = s.strip_edges()
	if t.length() <= max_len:
		return t
	return t.substr(0, max_len)


func _clamp_ghost_unit_dict(u: Dictionary) -> void:
	u["unit_name"] = _truncate_ghost_str(str(u.get("unit_name", "Dummy Gladiator")), 48)
	u["class"] = _truncate_ghost_str(str(u.get("class", "Mercenary")), 48)
	u["level"] = clampi(int(u.get("level", 1)), 1, 99)
	u["max_hp"] = clampi(int(u.get("max_hp", 10)), 1, ARENA_GHOST_HP_MAX)
	var mx: int = int(u["max_hp"])
	u["current_hp"] = clampi(int(u.get("current_hp", mx)), 0, mx)
	u["strength"] = clampi(int(u.get("strength", 3)), 0, ARENA_GHOST_STAT_MAX)
	u["magic"] = clampi(int(u.get("magic", 0)), 0, ARENA_GHOST_STAT_MAX)
	u["defense"] = clampi(int(u.get("defense", 2)), 0, ARENA_GHOST_STAT_MAX)
	u["resistance"] = clampi(int(u.get("resistance", 1)), 0, ARENA_GHOST_STAT_MAX)
	u["speed"] = clampi(int(u.get("speed", 3)), 0, ARENA_GHOST_STAT_MAX)
	u["agility"] = clampi(int(u.get("agility", 3)), 0, ARENA_GHOST_STAT_MAX)
	u["sprite_path"] = _truncate_ghost_str(str(u.get("sprite_path", "")), ARENA_GHOST_STRING_FIELD_MAX)
	u["portrait_path"] = _truncate_ghost_str(str(u.get("portrait_path", "")), ARENA_GHOST_STRING_FIELD_MAX)
	u["equipped_weapon_name"] = _truncate_ghost_str(str(u.get("equipped_weapon_name", "Unarmed")), 64)
	if u.has("move_range"):
		u["move_range"] = clampi(int(u.get("move_range", 4)), 1, 12)


func _clamp_ghost_dragon_dict(dg: Dictionary) -> void:
	dg["name"] = _truncate_ghost_str(str(dg.get("name", "Dragon")), 48)
	dg["element"] = _truncate_ghost_str(str(dg.get("element", "Fire")), 24)
	dg["generation"] = clampi(int(dg.get("generation", 1)), 1, 99)
	dg["stage"] = clampi(int(dg.get("stage", 1)), 1, 99)
	if dg.get("traits") is Array:
		dg["traits"] = (dg["traits"] as Array).duplicate()
	else:
		dg["traits"] = []
	dg["max_hp"] = clampi(int(dg.get("max_hp", 15)), 1, ARENA_GHOST_HP_MAX)
	dg["strength"] = clampi(int(dg.get("strength", 5)), 0, ARENA_GHOST_STAT_MAX)
	dg["magic"] = clampi(int(dg.get("magic", 5)), 0, ARENA_GHOST_STAT_MAX)
	dg["defense"] = clampi(int(dg.get("defense", 5)), 0, ARENA_GHOST_STAT_MAX)
	dg["resistance"] = clampi(int(dg.get("resistance", 4)), 0, ARENA_GHOST_STAT_MAX)
	dg["speed"] = clampi(int(dg.get("speed", 4)), 0, ARENA_GHOST_STAT_MAX)
	dg["agility"] = clampi(int(dg.get("agility", 3)), 0, ARENA_GHOST_STAT_MAX)


func validate_ghost_snapshot(snapshot: Dictionary) -> Dictionary:
	var clean: Dictionary = snapshot.duplicate(true)
	if not clean.has("roster"):
		clean["roster"] = []
	if not clean.has("dragons"):
		clean["dragons"] = []
	if not clean.has("power_rating"):
		clean["power_rating"] = 0
	if not clean.has("player_name"):
		clean["player_name"] = "Gladiator"
	if not clean.has("player_id"):
		clean["player_id"] = ""

	var pname: String = str(clean.get("player_name", "Gladiator")).strip_edges()
	clean["player_name"] = _truncate_ghost_str(pname if not pname.is_empty() else "Gladiator", ARENA_GHOST_DISPLAY_NAME_MAX)
	clean["player_id"] = _truncate_ghost_str(str(clean.get("player_id", "")), 128)

	var new_roster: Array = []
	for unit in clean["roster"]:
		if new_roster.size() >= ARENA_MAX_SQUAD_SLOTS:
			break
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		var u: Dictionary = (unit as Dictionary).duplicate(true)
		_clamp_ghost_unit_dict(u)
		new_roster.append(u)

	var slots_left: int = ARENA_MAX_SQUAD_SLOTS - new_roster.size()
	var new_dragons: Array = []
	for d in clean["dragons"]:
		if slots_left <= 0:
			break
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var dg: Dictionary = (d as Dictionary).duplicate(true)
		_clamp_ghost_dragon_dict(dg)
		new_dragons.append(dg)
		slots_left -= 1

	if new_roster.is_empty() and new_dragons.is_empty():
		var dummy: Dictionary = {
			"unit_name": "Dummy Gladiator",
			"class": "Mercenary",
			"level": 1,
			"max_hp": 10,
			"current_hp": 10,
			"strength": 3,
			"magic": 0,
			"defense": 2,
			"resistance": 1,
			"speed": 3,
			"agility": 3,
			"sprite_path": "",
			"portrait_path": "",
			"equipped_weapon_name": "Unarmed"
		}
		_clamp_ghost_unit_dict(dummy)
		new_roster.append(dummy)

	clean["roster"] = new_roster
	clean["dragons"] = new_dragons
	clean["power_rating"] = clampi(int(clean.get("power_rating", 0)), 0, ARENA_GHOST_POWER_RATING_MAX)
	return clean


# ===========================================================================
# Silent Wolf: defense rewards & identity
# ===========================================================================

func record_defense_result(owner_player_id: String, victory: bool) -> void:
	const MAX_UNCLAIMED_GOLD: int = 999999999
	var reward_gold: int = 100 if victory else 0
	var reward_mmr: int = 15 if victory else -5

	var result = await SilentWolf.Players.get_player_data(owner_player_id).sw_get_player_data_complete
	var data: Dictionary = result.get("player_data", {})

	var current_gold: int = clampi(int(data.get("unclaimed_gold", 0)) + reward_gold, 0, MAX_UNCLAIMED_GOLD)
	var current_mmr: int = clampi(int(data.get("unclaimed_mmr", 0)) + reward_mmr, -ARENA_MMR_ABSOLUTE_MAX, ARENA_MMR_ABSOLUTE_MAX)

	await SilentWolf.Players.save_player_data(owner_player_id, {
		"unclaimed_gold": current_gold,
		"unclaimed_mmr": current_mmr
	}).sw_save_player_data_complete


func check_defense_rewards() -> Dictionary:
	const MAX_UNCLAIMED_GOLD: int = 999999999
	var my_id: String = get_safe_player_id()
	var result = await SilentWolf.Players.get_player_data(my_id).sw_get_player_data_complete
	var data: Dictionary = result.get("player_data", {})

	var gold: int = clampi(int(data.get("unclaimed_gold", 0)), 0, MAX_UNCLAIMED_GOLD)
	var mmr: int = clampi(int(data.get("unclaimed_mmr", 0)), -ARENA_MMR_ABSOLUTE_MAX, ARENA_MMR_ABSOLUTE_MAX)

	if gold > 0 or mmr != 0:
		await SilentWolf.Players.save_player_data(my_id, {"unclaimed_gold": 0, "unclaimed_mmr": 0}).sw_save_player_data_complete

	return {"gold": gold, "mmr": mmr}


## Leaderboard row key for Silent Wolf [save_score]. Prefers Steam ID64 when available (stable, Steam-deck friendly).
## Falls back to a shortened OS unique id for non-Steam / editor runs.
func get_safe_player_id() -> String:
	var steam: Node = Engine.get_main_loop().root.get_node_or_null("/root/SteamService")
	if steam != null and steam.has_method("get_local_steam_id_string"):
		var sid: String = str(steam.call("get_local_steam_id_string")).strip_edges()
		if sid != "":
			return sid
	var raw_id: String = OS.get_unique_id()
	var safe_id: String = raw_id.replace("{", "").replace("}", "").replace("-", "")
	if safe_id.length() > 30:
		safe_id = safe_id.substr(0, 30)
	return safe_id


## Short line for UI: whether the arena board uses Steam identity or a local fallback.
func get_arena_identity_blurb() -> String:
	var steam: Node = Engine.get_main_loop().root.get_node_or_null("/root/SteamService")
	if steam != null and steam.has_method("is_steam_ready") and bool(steam.call("is_steam_ready")):
		var pn: String = ""
		if steam.has_method("get_steam_persona_name"):
			pn = str(steam.call("get_steam_persona_name")).strip_edges()
		if pn != "":
			return "Steam: %s" % pn
		return "Steam connected — roster will sync to the Multiverse board."
	return "Offline / non-Steam build: using a device profile for the arena board."


# ===========================================================================
# UI: MMR math (matches BattleField arena block), rewards, difficulty, cooldown
# ===========================================================================

## Preview deltas use the same formulas as BattleField (win / loss).
func compute_mmr_delta_preview(my_mmr: int, opponent_mmr: int) -> Dictionary:
	var my_c: int = clamp_mmr_int(my_mmr)
	var op_c: int = clamp_mmr_int(opponent_mmr)
	var diff: int = op_c - my_c
	var win_delta: int = 25 + int(max(0, diff) / 10.0)
	var loss_delta: int = -15 + int(min(0, diff) / 15.0)
	loss_delta = mini(-1, loss_delta)
	return {"mmr_on_win": win_delta, "mmr_on_loss": loss_delta}


## Gold/token preview if this arena fight is won next (uses current [CampaignManager] streak).
func _estimate_arena_win_gold_and_tokens() -> Dictionary:
	var s: int = CampaignManager.arena_win_streak
	var streak_after_win: int = s + 1
	var bonus_steps: int = maxi(0, streak_after_win - 1)
	var mult: float = minf(1.0 + float(bonus_steps) * 0.20, 2.0)
	var gold: int = int(round(150.0 * mult))
	var tokens: int = 1 + int(floor(float(streak_after_win - 1) / 2.0))
	return {"gold": gold, "tokens": tokens, "gold_multiplier": mult, "streak_after_win": streak_after_win}


func get_estimated_rewards(opponent_mmr: int) -> Dictionary:
	var my_mmr: int = get_local_mmr()
	var mmr: Dictionary = compute_mmr_delta_preview(my_mmr, opponent_mmr)
	var loot: Dictionary = _estimate_arena_win_gold_and_tokens()
	return {
		"mmr_on_win": mmr["mmr_on_win"],
		"mmr_on_loss": mmr["mmr_on_loss"],
		"gold_on_win": int(loot["gold"]),
		"gold_on_loss": 0,
		"tokens_on_win": int(loot["tokens"]),
		"tokens_on_loss": 0,
		"gold_multiplier": float(loot["gold_multiplier"])
	}


func get_opponent_difficulty_label(mmr_diff: int) -> String:
	var abs_diff: int = abs(mmr_diff)
	if abs_diff <= 50:
		return "Fair"
	if abs_diff <= 150:
		return "Easy" if mmr_diff > 0 else "Hard"
	if abs_diff <= 300:
		return "Easy" if mmr_diff > 0 else "Very Hard"
	return "Very Easy" if mmr_diff > 0 else "Very Hard"


## Same bands as [get_opponent_difficulty_label] plus tier and color for richer UI.
func get_opponent_difficulty_detail(mmr_diff: int) -> Dictionary:
	var label: String = get_opponent_difficulty_label(mmr_diff)
	var abs_diff: int = abs(mmr_diff)
	var tier: int = 2
	var color: Color = Color(0.85, 0.85, 0.75)
	if abs_diff <= 50:
		tier = 2
		color = Color(0.85, 0.85, 0.75)
	elif abs_diff <= 150:
		tier = 1 if mmr_diff < 0 else 3
		color = Color(0.45, 0.85, 0.55) if mmr_diff < 0 else Color(1.0, 0.72, 0.35)
	elif abs_diff <= 300:
		tier = 0 if mmr_diff < 0 else 4
		color = Color(0.35, 0.95, 0.55) if mmr_diff < 0 else Color(1.0, 0.45, 0.30)
	else:
		tier = 0 if mmr_diff < 0 else 5
		color = Color(0.25, 1.0, 0.45) if mmr_diff < 0 else Color(1.0, 0.25, 0.22)
	return {"label": label, "tier": tier, "color": color, "mmr_diff": mmr_diff}


## Compare listed team power ratings (from snapshot) for a short UI blurb.
func get_power_matchup_hint(local_power: int, opponent_power: int) -> String:
	if local_power < 1 and opponent_power < 1:
		return ""
	var ratio: float = float(opponent_power + 1) / float(local_power + 1)
	if ratio < 0.75:
		return "Power: you look stronger on paper."
	if ratio > 1.35:
		return "Power: they bring more raw stats."
	return "Power: relatively even."


func _mark_opponents_fetched() -> void:
	_last_opponent_fetch_time_sec = Time.get_ticks_msec() / 1000.0


func get_opponents_refresh_cooldown_remaining_sec() -> float:
	if _last_opponent_fetch_time_sec < 0.0:
		return 0.0
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _last_opponent_fetch_time_sec
	return maxf(0.0, OPPONENT_REFRESH_COOLDOWN_SEC - elapsed)


## Human-readable cooldown, e.g. "Ready" or "4m 32s".
func format_opponents_refresh_cooldown() -> String:
	var rem: float = get_opponents_refresh_cooldown_remaining_sec()
	if rem <= 0.01:
		return "Ready"
	var total: int = int(ceil(rem))
	var m: int = total / 60
	var s: int = total % 60
	if m <= 0:
		return "%ds" % s
	return "%dm %02ds" % [m, s]


func report_arena_result(victory: bool) -> void:
	var win_streak: int = int(CampaignManager.get("arena_win_streak")) if CampaignManager.get("arena_win_streak") != null else 0
	var loss_streak: int = int(CampaignManager.get("arena_loss_streak")) if CampaignManager.get("arena_loss_streak") != null else 0
	if victory:
		CampaignManager.set("arena_win_streak", win_streak + 1)
		CampaignManager.set("arena_loss_streak", 0)
	else:
		CampaignManager.set("arena_loss_streak", loss_streak + 1)
		CampaignManager.set("arena_win_streak", 0)


func get_win_streak() -> int:
	return CampaignManager.arena_win_streak


func get_loss_streak() -> int:
	var v = CampaignManager.get("arena_loss_streak")
	return int(v) if v != null else 0
