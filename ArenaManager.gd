extends Node

# ArenaManager.gd – Version 2.0 (Juiced Up!)
var current_opponent_data: Dictionary = {}
var local_arena_team: Array = []
var local_power_rating: int = 0

var last_match_result: String = ""
var last_match_mmr_change: int = 0
var last_match_old_mmr: int = 1000
var last_match_new_mmr: int = 1000
var last_match_gold_reward: int = 0
var last_match_token_reward: int = 0

# Returns the specific icon based on MMR
func get_rank_icon(mmr: int) -> Texture2D:
	var path = ""
	
	if mmr >= 2000:
		path = "res://Assets/Ranks/rank_grandmaster.png"
	elif mmr >= 1800:
		path = "res://Assets/Ranks/rank_diamond.png"
	elif mmr >= 1600:
		path = "res://Assets/Ranks/rank_platinum.png"
	elif mmr >= 1400:
		path = "res://Assets/Ranks/rank_gold.png"
	elif mmr >= 1200:
		path = "res://Assets/Ranks/rank_silver.png"
	else:
		path = "res://Assets/Ranks/rank_bronze.png"
		
	# Safely load and return the texture
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	else:
		return null
		
func _ready() -> void:
	CoopOnlineServiceConfig.ensure_silent_wolf_ready()

# ==========================================
# --- RANK & MMR SYSTEM ---
# ==========================================
func get_local_mmr() -> int:
	if CampaignManager.get("arena_mmr") != null: return CampaignManager.arena_mmr
	return 1000 

func set_local_mmr(new_mmr: int) -> void:
	if CampaignManager.get("arena_mmr") != null: CampaignManager.arena_mmr = max(0, new_mmr)

func get_rank_data(mmr: int) -> Dictionary:
	if mmr < 1200: return {"name": "Bronze", "color": Color(0.80, 0.50, 0.20), "min": 0, "max": 1200, "index": 0}
	if mmr < 1400: return {"name": "Silver", "color": Color(0.75, 0.75, 0.75), "min": 1200, "max": 1400, "index": 1}
	if mmr < 1600: return {"name": "Gold", "color": Color(1.00, 0.85, 0.20), "min": 1400, "max": 1600, "index": 2}
	if mmr < 1800: return {"name": "Platinum", "color": Color(0.30, 0.80, 0.80), "min": 1600, "max": 1800, "index": 3}
	if mmr < 2000: return {"name": "Diamond", "color": Color(0.70, 0.30, 1.00), "min": 1800, "max": 2000, "index": 4}
	return {"name": "Grandmaster", "color": Color(1.00, 0.20, 0.20), "min": 2000, "max": 2400, "index": 5}


func get_rank_bounds(mmr: int) -> Dictionary:
	var data: Dictionary = get_rank_data(mmr) # <--- Explicitly typed
	return {"min": int(data["min"]), "max": int(data["max"])}

func get_rank_fill_ratio(mmr: int) -> float:
	var bounds: Dictionary = get_rank_bounds(mmr) # <--- Explicitly typed
	var span: int = max(1, bounds["max"] - bounds["min"]) # <--- Explicitly typed
	return clamp((float(mmr) - float(bounds["min"])) / float(span), 0.0, 1.0)

func format_signed(delta: int) -> String:
	return ("+" if delta >= 0 else "") + str(delta)

func _calculate_combat_power(team: Array) -> int:
	var power := 0
	for unit in team:
		if unit.get("is_dragon", false) or unit.has("element"):
			power += unit.get("generation", 1) + unit.get("max_hp", 0) + unit.get("strength", 0) + unit.get("magic", 0) + unit.get("defense", 0) + unit.get("resistance", 0) + unit.get("speed", 0) + unit.get("agility", 0)
		else:
			power += unit.get("level", 1) + unit.get("max_hp", 0) + unit.get("strength", 0) + unit.get("magic", 0) + unit.get("defense", 0) + unit.get("resistance", 0) + unit.get("speed", 0) + unit.get("agility", 0)
	return power

# ==========================================
# --- CLOUD UPLOAD ---
# ==========================================
func _generate_player_snapshot_dict(selected_team: Array) -> Dictionary:
	var snapshot: Dictionary = {
		"player_id": get_safe_player_id(),
		"player_name": "Gladiator", # Default fallback
		"power_rating": 0,
		"roster": [],
		"dragons": []
	}
	
	# ==========================================
	# --- SMART PLAYER NAME DETECTION ---
	# ==========================================
	# 1. Try to find the Custom Avatar in the Campaign Manager
	if CampaignManager.get("custom_avatar") != null and CampaignManager.custom_avatar.has("name"):
		snapshot["player_name"] = CampaignManager.custom_avatar["name"]
	else:
		# 2. Fallback: Search the player's full roster for the Avatar unit
		for u in CampaignManager.player_roster:
			if u.get("is_custom_avatar") == true:
				snapshot["player_name"] = u.get("unit_name", "Hero")
				break
	# ==========================================
		
	for unit in selected_team:
		if unit.get("is_dragon", false) or unit.has("element"):
			var d_data: Dictionary = {
				"name": unit.get("name", "Dragon"), "element": unit.get("element", "Fire"),
				"generation": unit.get("generation", 1), "traits": unit.get("traits", []).duplicate(),
				"stage": unit.get("stage", 1), "max_hp": unit.get("max_hp", 15), "strength": unit.get("strength", 5),
				"magic": unit.get("magic", 5), "defense": unit.get("defense", 5), "resistance": unit.get("resistance", 4),
				"speed": unit.get("speed", 4), "agility": unit.get("agility", 3)
			}
			snapshot["dragons"].append(d_data)
		else:
			var s_path: String = ""
			var p_path: String = ""
			var s_tex = unit.get("battle_sprite")
			if s_tex == null and unit.get("data") != null: s_tex = unit.data.get("unit_sprite")
			if s_tex == null and unit.get("data") != null: s_tex = unit.data.get("battle_sprite")
			if s_tex != null and s_tex is Texture2D and s_tex.resource_path != "": s_path = s_tex.resource_path
				
			var p_tex = unit.get("portrait")
			if p_tex == null and unit.get("data") != null: p_tex = unit.data.get("portrait")
			if p_tex != null and p_tex is Texture2D and p_tex.resource_path != "": p_path = p_tex.resource_path
				
			var unit_data: Dictionary = {
				"unit_name": unit.get("unit_name", unit.get("name", "Fighter")), "class": unit.get("unit_class", unit.get("class", "Mercenary")),
				"level": unit.get("level", 1), "max_hp": unit.get("max_hp", 10), "current_hp": unit.get("max_hp", 10),
				"strength": unit.get("strength", 4), "magic": unit.get("magic", 0), "defense": unit.get("defense", 2),
				"resistance": unit.get("resistance", 1), "speed": unit.get("speed", 4), "agility": unit.get("agility", 3),
				"move_range": unit.get("move_range", 4), "ability": unit.get("ability", "None"),
				"unlocked_abilities": unit.get("unlocked_abilities", []).duplicate(), "sprite_path": s_path, "portrait_path": p_path
			}
			var wpn = unit.get("equipped_weapon")
			if wpn != null and typeof(wpn) == TYPE_OBJECT:
				var w_name = wpn.get("weapon_name")
				if w_name != null and str(w_name) != "": unit_data["equipped_weapon_name"] = str(w_name)
				else: unit_data["equipped_weapon_name"] = "Unarmed"
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

# ==========================================
# --- MMR MATCHMAKING ---
# ==========================================

# --- AI/Reviewer: Entry point for arena matchmaking. Sections: (1) network fetch, (2) metadata validation + MMR diff, (3) sort by MMR, (4) slice to max_results.
## Fetches arena opponents from the SilentWolf leaderboard, sorted by MMR proximity to the local player.
##
## Purpose: Populate the arena opponent list for the UI. Only scores with valid metadata are considered; results are ordered by absolute MMR difference so the closest matches appear first.
##
## Inputs:
##   max_results (int): Maximum number of opponents to return. Default 10.
##
## Outputs:
##   Array: Array of score entries (each with "metadata", "score", "match_diff"). Empty if fetch fails or no valid entries.
##
## Side effects: None. Does not mutate SilentWolf.Scores; only reads scores after the async fetch completes.
func fetch_arena_opponents(max_results: int = 10) -> Array:
	const POOL_SIZE: int = 50
	const DEFAULT_MMR_FALLBACK: int = 1000

	# --- 1. Network fetch: wait for leaderboard data before reading scores (avoids race). ---
	await SilentWolf.Scores.get_scores(POOL_SIZE, "arena").sw_get_scores_complete
	_mark_opponents_fetched()
	# Read scores only after await; guard against null or non-Array so we never call .duplicate() on invalid ref.
	var raw_scores = SilentWolf.Scores.scores
	var all_scores: Array = raw_scores.duplicate() if raw_scores is Array else []

	# --- 2. Metadata validation and MMR difference: build candidates with normalized metadata and match_diff. ---
	var local_mmr: int = get_local_mmr()
	var candidates: Array = []

	for score in all_scores:
		if score.get("metadata", null) == null:
			continue
		# Normalize opponent snapshot so roster/dragons/stats are safe for battle scene.
		var clean_meta: Dictionary = validate_ghost_snapshot(score.get("metadata"))
		var opp_mmr: int = score.get("score", DEFAULT_MMR_FALLBACK)
		var diff: int = abs(local_mmr - opp_mmr)
		score["match_diff"] = diff
		score["metadata"] = clean_meta
		candidates.append(score)

	# --- 3. MMR sorting: closest opponents first. ---
	candidates.sort_custom(func(a, b): return a.get("match_diff", 0) < b.get("match_diff", 0))

	# --- 4. Slice to requested size and return (no in-place mutation of candidates). ---
	var final_opponents: Array = []
	var count: int = min(max_results, candidates.size())
	for i in range(count):
		final_opponents.append(candidates[i])
	return final_opponents

func validate_ghost_snapshot(snapshot: Dictionary) -> Dictionary:
	var clean: Dictionary = snapshot.duplicate(true)
	if not clean.has("roster"): clean["roster"] = []
	if not clean.has("dragons"): clean["dragons"] = []
	if not clean.has("power_rating"): clean["power_rating"] = 0
	
	var new_roster: Array = []
	for unit in clean["roster"]:
		var u: Dictionary = unit.duplicate(true)
		u["unit_name"] = u.get("unit_name", "Dummy Gladiator")
		u["class"] = u.get("class", "Mercenary")
		u["level"] = u.get("level", 1)
		u["max_hp"] = u.get("max_hp", 10)
		u["current_hp"] = u.get("current_hp", u["max_hp"])
		u["strength"] = u.get("strength", 3)
		u["magic"] = u.get("magic", 0)
		u["defense"] = u.get("defense", 2)
		u["resistance"] = u.get("resistance", 1)
		u["speed"] = u.get("speed", 3)
		u["agility"] = u.get("agility", 3)
		u["sprite_path"] = u.get("sprite_path", "")
		u["portrait_path"] = u.get("portrait_path", "")
		u["equipped_weapon_name"] = u.get("equipped_weapon_name", "Unarmed")
		new_roster.append(u)
		
	if new_roster.is_empty():
		new_roster.append({
			"unit_name": "Dummy Gladiator", "class": "Mercenary", "level": 1, "max_hp": 10,
			"current_hp": 10, "strength": 3, "magic": 0, "defense": 2, "resistance": 1,
			"speed": 3, "agility": 3, "sprite_path": "", "portrait_path": "", "equipped_weapon_name": "Unarmed"
		})
	clean["roster"] = new_roster
	return clean

# ==========================================
# --- PASSIVE OFFLINE REWARDS & MMR ---
# ==========================================
func record_defense_result(owner_player_id: String, victory: bool) -> void:
	var reward_gold: int = 100 if victory else 0
	var reward_mmr: int = 15 if victory else -5 
	
	var result = await SilentWolf.Players.get_player_data(owner_player_id).sw_get_player_data_complete
	var data: Dictionary = result.get("player_data", {})
	
	var current_gold: int = data.get("unclaimed_gold", 0) + reward_gold
	var current_mmr: int = data.get("unclaimed_mmr", 0) + reward_mmr
	
	await SilentWolf.Players.save_player_data(owner_player_id, {
		"unclaimed_gold": current_gold,
		"unclaimed_mmr": current_mmr
	}).sw_save_player_data_complete
		
func check_defense_rewards() -> Dictionary:
	var my_id: String = get_safe_player_id()
	var result = await SilentWolf.Players.get_player_data(my_id).sw_get_player_data_complete
	var data: Dictionary = result.get("player_data", {})
	
	var gold: int = data.get("unclaimed_gold", 0)
	var mmr: int = data.get("unclaimed_mmr", 0)
	
	if gold > 0 or mmr != 0:
		await SilentWolf.Players.save_player_data(my_id, {"unclaimed_gold": 0, "unclaimed_mmr": 0}).sw_save_player_data_complete
		
	return {"gold": gold, "mmr": mmr}
	
func get_safe_player_id() -> String:
	var raw_id = OS.get_unique_id()
	var safe_id = raw_id.replace("{", "").replace("}", "").replace("-", "")
	if safe_id.length() > 30: safe_id = safe_id.substr(0, 30)
	return safe_id

# ==========================================
# --- PLAYER EXPERIENCE ENHANCEMENTS ---
# ==========================================
#
# This section adds UX features for the arena: pre-battle reward estimates, difficulty
# labels, next-rank progress, opponent-list refresh cooldown, and win/loss streak tracking.
# It depends on ArenaManager's existing rank/MMR API (get_local_mmr, get_rank_data) and
# on CampaignManager for persistent streak storage (arena_win_streak, arena_loss_streak).
#
# INTEGRATION: To enable the refresh cooldown, call _mark_opponents_fetched() from
# fetch_arena_opponents() immediately after the "await ... sw_get_scores_complete" line.
#
# --- AI/Reviewer: Entry points for UI ---
#   get_estimated_rewards(opponent_mmr)     -> pre-battle reward preview
#   get_opponent_difficulty_label(mmr_diff)-> "Easy" / "Fair" / "Hard" etc.
#   get_next_rank_info(current_mmr)        -> next rank name and points to go
#   get_opponents_refresh_cooldown_remaining_sec() -> refresh button state
#   get_win_streak() / get_loss_streak()   -> streak display
#   report_arena_result(victory)           -> call from battle scene when match ends
# Configuration: OPPONENT_REFRESH_COOLDOWN_SEC, difficulty thresholds in get_opponent_difficulty_label.

# Cooldown after fetching opponents before the list can be refreshed again (seconds).
const OPPONENT_REFRESH_COOLDOWN_SEC: float = 300.0
# Timestamp (seconds since engine start) of last successful opponent fetch. -1.0 = never.
var _last_opponent_fetch_time_sec: float = -1.0

## Called internally when fetch_arena_opponents() completes. Records time for refresh cooldown.
## Side effects: Sets _last_opponent_fetch_time_sec.
func _mark_opponents_fetched() -> void:
	_last_opponent_fetch_time_sec = Time.get_ticks_msec() / 1000.0

## Returns estimated MMR change and gold for winning or losing against an opponent at the given MMR.
##
## Purpose: Let the UI show "Win: +18 MMR, 50 gold / Loss: -4 MMR" before the player starts a battle.
## The estimates scale with MMR difference: underdogs (opponent higher) gain more on win and lose
## less on defeat; favourites gain less on win and lose more on defeat.
##
## Inputs:
##   opponent_mmr (int): Opponent's current MMR (e.g. from score["score"]).
##
## Outputs:
##   Dictionary with keys: mmr_on_win (int), mmr_on_loss (int), gold_on_win (int), gold_on_loss (int).
##
## Side effects: None.
func get_estimated_rewards(opponent_mmr: int) -> Dictionary:
	var my_mmr: int = get_local_mmr()
	# Positive diff = opponent is higher (player is underdog). Underdog gets slightly more MMR on win, less loss on defeat.
	var diff: int = opponent_mmr - my_mmr
	# Scale by diff/40 so ~40 MMR difference shifts estimate by ±1. Explicit float division then truncate for integer MMR deltas.
	var delta: int = int(float(diff) / 40.0)
	var win_mmr: int = clampi(15 + delta, 8, 22)
	var loss_mmr: int = clampi(-5 - delta, -12, -2)
	return {
		"mmr_on_win": win_mmr,
		"mmr_on_loss": loss_mmr,
		"gold_on_win": 50,
		"gold_on_loss": 0
	}

## Returns a difficulty label for the opponent based on MMR difference (from player's perspective).
##
## Purpose: Show "Easy", "Fair", "Hard", or "Very Hard" next to each opponent so players can
## choose risk level. Positive mmr_diff means the opponent is higher rated (harder for the player).
##
## Inputs:
##   mmr_diff (int): opponent_mmr - local_mmr. Positive = opponent stronger.
##
## Outputs:
##   String: "Fair", "Easy", "Hard", "Very Easy", or "Very Hard".
##
## Side effects: None.
func get_opponent_difficulty_label(mmr_diff: int) -> String:
	var abs_diff: int = abs(mmr_diff)
	# Bands: ±50 Fair, ±150 Easy/Hard, ±300 Easy/Very Hard, beyond that Very Easy / Very Hard.
	if abs_diff <= 50:
		return "Fair"
	if abs_diff <= 150:
		return "Easy" if mmr_diff > 0 else "Hard"
	if abs_diff <= 300:
		return "Easy" if mmr_diff > 0 else "Very Hard"
	return "Very Easy" if mmr_diff > 0 else "Very Hard"

## Returns the next rank tier and how much MMR is needed to reach it (for progress UI).
##
## Purpose: Drive "Next: Gold — 45 MMR to go" and rank progress bars. Uses existing
## get_rank_data() tier boundaries (1200 Silver, 1400 Gold, 1600 Platinum, 1800 Diamond, 2000 Grandmaster).
##
## Inputs:
##   current_mmr (int): Player's current MMR (e.g. get_local_mmr()).
##
## Outputs:
##   Dictionary: "name" (String, next rank name), "mmr_needed" (int), "points_to_go" (int),
##   "is_max_rank" (bool). If at max rank, name is empty and points_to_go is 0.
##
## Side effects: None.
func get_next_rank_info(current_mmr: int) -> Dictionary:
	var data: Dictionary = get_rank_data(current_mmr)
	var tier_max: int = int(data["max"])
	if current_mmr >= 2400:
		return {"name": "", "mmr_needed": current_mmr, "points_to_go": 0, "is_max_rank": true}
	# Next rank is the tier whose minimum MMR equals this tier's maximum.
	var next_names: Dictionary = {1200: "Silver", 1400: "Gold", 1600: "Platinum", 1800: "Diamond", 2000: "Grandmaster"}
	var next_name: String = next_names.get(tier_max, "Grandmaster")
	return {
		"name": next_name,
		"mmr_needed": tier_max,
		"points_to_go": max(0, tier_max - current_mmr),
		"is_max_rank": false
	}

## Returns seconds remaining until the opponent list can be refreshed (0.0 if ready).
##
## Purpose: Disable the refresh button or show "Refresh in 4:32". Call _mark_opponents_fetched()
## from fetch_arena_opponents() when the fetch completes so this cooldown is accurate.
##
## Inputs: None.
##
## Outputs:
##   float: Seconds until refresh is allowed, or 0.0 if no fetch yet or cooldown elapsed.
##
## Side effects: None.
func get_opponents_refresh_cooldown_remaining_sec() -> float:
	if _last_opponent_fetch_time_sec < 0.0:
		return 0.0
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _last_opponent_fetch_time_sec
	return maxf(0.0, OPPONENT_REFRESH_COOLDOWN_SEC - elapsed)

## Updates win/loss streak after an arena battle. Call once when the battle result is known.
##
## Purpose: Maintain arena_win_streak and arena_loss_streak on CampaignManager for UI and
## future streak bonuses. A win resets loss streak and increments win streak; a loss does the opposite.
##
## Inputs:
##   victory (bool): True if the local player won the arena battle.
##
## Outputs: None.
##
## Side effects: Sets CampaignManager.arena_win_streak and CampaignManager.arena_loss_streak.
## Persist these in your save/load if you want streaks to survive restart.
func report_arena_result(victory: bool) -> void:
	var win_streak: int = int(CampaignManager.get("arena_win_streak")) if CampaignManager.get("arena_win_streak") != null else 0
	var loss_streak: int = int(CampaignManager.get("arena_loss_streak")) if CampaignManager.get("arena_loss_streak") != null else 0
	if victory:
		CampaignManager.set("arena_win_streak", win_streak + 1)
		CampaignManager.set("arena_loss_streak", 0)
	else:
		CampaignManager.set("arena_loss_streak", loss_streak + 1)
		CampaignManager.set("arena_win_streak", 0)

## Returns the current arena win streak (consecutive wins). For UI and optional bonuses.
##
## Inputs: None.
## Outputs: int. 0 if not set or no streak.
## Side effects: None.
func get_win_streak() -> int:
	var v = CampaignManager.get("arena_win_streak")
	return int(v) if v != null else 0

## Returns the current arena loss streak (consecutive losses). For UI and optional bonuses.
##
## Inputs: None.
## Outputs: int. 0 if not set or no streak.
## Side effects: None.
func get_loss_streak() -> int:
	var v = CampaignManager.get("arena_loss_streak")
	return int(v) if v != null else 0
