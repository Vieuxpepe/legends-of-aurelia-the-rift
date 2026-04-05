# ============================================================================
# 🤖 AI & DEVELOPER CHEAT SHEET: HOW TO ADD A NEW LEVEL 🤖
# ============================================================================
# This game uses a dual-transition array system to seamlessly route the player:
# [BATTLE WIN] -> [POST-BATTLE TRANSITION] -> [CAMP] -> [PRE-BATTLE TRANSITION] -> [NEXT BATTLE]
#
# To add a new level (e.g., Level 4), follow these 4 steps EXACTLY:
#
# STEP 1: CREATE THE SCENES
#   - Create the map: `res://Scenes/Levels/Level4.tscn`
#   - Create the intro story: `res://Scenes/Transition4_Intro.tscn` (Pre-Battle)
#   - Create the outro story: `res://Scenes/Transition4_Outro.tscn` (Post-Battle)
#
# STEP 2: UPDATE ARRAYS IN THIS SCRIPT (CampaignManager.gd)
#   - Add the level to `campaign_levels`
#   - Add the intro to `pre_battle_transitions` (Leave as "" if no intro exists)
#   - Add the outro to `post_battle_transitions` (Use "res://Scenes/camp_menu.tscn" to go straight to camp)
#   * IMPORTANT: The indices MUST match! Index 0 = Level 1, Index 1 = Level 2, etc.
#
# STEP 3: WORLD MAP PROGRESSION (Optional)
#   - The linear "Story -> Camp -> Story" phase ends when `max_unlocked_index >= 2` (Level 3).
#   - After that, the Camp Menu "Next Battle" button automatically opens the World Map.
#   - To add a node to the World Map, update `WorldMap.gd` and point the new map pin to the correct Index.
#
# STEP 4: ADD LORE/SHOP TWEAKS (Optional)
#   - In `Camp_menu.gd`, you can add new dialogue to `blacksmith_monologues` 
#     and set its `unlock_level` to match the new map index!
# ============================================================================
# RESPONSIBILITY CLUSTERS (for audit): player settings | campaign progression |
# roster/inventory | world map & base | encounter flags | jukebox/playlists |
# NPC relationships (Seraphina + legacy) | merchant/crafting | arena state |
# structures/deployment | dragons (Morgra). Save/load/reset symmetry: see save_data
# in save_game(), load_game(), and reset_campaign_data().
# ============================================================================

extends Node

const SETTINGS_FILE_PATH: String = "user://settings.cfg"
const CAMP_PAIR_SCENE_DB = preload("res://Scripts/Narrative/CampPairSceneDB.gd")
const ActiveCombatAbilityHelpers = preload("res://Scripts/Core/BattleField/ActiveCombatAbilityHelpers.gd")
const BATTLE_PATH_STYLE_MINIMAL := 0
const BATTLE_PATH_STYLE_OUTLINED := 1
const BATTLE_PATH_STYLE_DASHED := 2

# --- GLOBAL PLAYER SETTINGS (runtime cache; persisted separately from campaign saves) ---
var audio_master_volume: float = 1.0
var audio_music_volume: float = 1.0
var audio_sfx_volume: float = 1.0
var audio_mute_when_unfocused: bool = false

# KEEP your existing vars:
# var camera_pan_speed: float = 600.0
# var unit_move_speed: float = 0.15

var battle_follow_enemy_camera: bool = true
## When true, AI turns process units in weapon-role order (buff staff, then others, then heal staff). Off by default; can change tactics vs scene order.
var battle_ai_role_batch_turns: bool = false
var battle_show_danger_zone_default: bool = false
var battle_show_minimap_default: bool = false
var battle_minimap_opacity: float = 0.90

var battle_zoom_step: float = 0.10
var battle_min_zoom: float = 0.60
var battle_max_zoom: float = 2.20
var battle_zoom_to_cursor: bool = true
var battle_edge_margin: int = 50

var battle_show_grid: bool = true
var battle_show_enemy_threat: bool = true
var battle_show_faction_tiles: bool = true
var battle_show_path_preview: bool = true
var battle_path_preview_pulse: bool = true
## See BATTLE_PATH_STYLE_* : minimal / outlined / dashed foreground.
var battle_path_style: int = BATTLE_PATH_STYLE_OUTLINED
var battle_path_endpoint_marker: bool = true
## 0 = sharp corners, 1 = low chamfer, 2 = stronger chamfer (world px scales with cell size).
var battle_path_corner_smoothing: int = 1
var battle_path_cost_ticks: bool = false
## When the route exists but the cursor tile is not a legal end (cost / blue tile), show muted preview.
var battle_path_invalid_ghost: bool = true
var battle_show_log: bool = true

# Important: this is a PLAYER OVERRIDE.
# It should only be able to DISABLE fog on maps that use it,
# not force fog onto maps that were not designed for it.
var battle_allow_fog_of_war: bool = true

## Pre-battle deployment: green zone overlay when entering deploy (F6 toggles in battle).
var battle_deploy_zone_overlay_default: bool = true
## After placing a benched unit, auto-arm the next benched roster unit.
var battle_deploy_auto_arm_after_place: bool = false
## When arming a benched unit, auto-place if exactly one legal empty tile exists.
var battle_deploy_quick_fill: bool = false
## When true, skip the loot reveal popup; items apply immediately with the same rules as closing the window.
var battle_skip_loot_window: bool = false

var arena_mmr: int = 1000

# --- ANTI-EXPLOIT REWARD TRACKER ---
var claimed_rank_rewards: Array = []
var support_bonds: Dictionary = {}
# Relationship Web V1: key = get_support_key(name_a, name_b), value = { trust, rivalry, mentorship, fear } (ints 0..100). Grief is battle-local only.
var relationship_web: Dictionary = {}

var morgra_favorite_dragon_uid: String = ""
var morgra_anger_duration: int = 0
var morgra_neutral_duration: int = 0
var morgra_favorite_survived_battles: int = 0

func get_save_path(slot: int, is_auto: bool = false) -> String:
	if is_auto:
		return "user://auto_save_" + str(slot) + ".dat"
	return "user://save_slot_" + str(slot) + ".dat"


## Read one save file without mutating campaign state. Empty `{}` if missing or unreadable.
func peek_save_file_summary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var save_variant: Variant = file.get_var()
	file.close()
	if typeof(save_variant) != TYPE_DICTIONARY:
		return {}
	var save_data: Dictionary = save_variant
	var roster: Array = save_data.get("player_roster", [])
	var leader_name: String = ""
	if roster.size() > 0:
		var first: Variant = roster[0]
		if first is Dictionary:
			leader_name = str(first.get("unit_name", "")).strip_edges()
	return {
		"global_gold": int(save_data.get("global_gold", 0)),
		"map_display_index": int(save_data.get("current_level_index", 0)) + 1,
		"leader_name": leader_name,
		"playtime_seconds": int(save_data.get("total_playtime_seconds", 0)),
	}


## Newest manual or auto save among slots 1–3 (by file mtime). Empty if none.
func get_newest_save_snapshot() -> Dictionary:
	var best_time: int = 0
	var best_slot: int = 0
	var best_auto: bool = false
	var best_path: String = ""
	for slot in range(1, 4):
		for use_auto in [false, true]:
			var p: String = get_save_path(slot, use_auto)
			if not FileAccess.file_exists(p):
				continue
			var t: int = int(FileAccess.get_modified_time(p))
			if t > best_time:
				best_time = t
				best_slot = slot
				best_auto = use_auto
				best_path = p
	if best_path == "":
		return {}
	var sum: Dictionary = peek_save_file_summary(best_path)
	if sum.is_empty():
		return {}
	sum["save_slot"] = best_slot
	sum["save_is_auto"] = best_auto
	sum["modified_unix"] = best_time
	sum["path"] = best_path
	return sum


# --- NPC RELATIONSHIP STATE ---
# Generic persistent relationship store for narrative NPCs.
# Seraphina uses a multi-axis model:
#   - affection
#   - trust
#   - professionalism
#
# The three legacy Seraphina variables are kept as compatibility properties so
# older scripts can continue to read/write them during the transition.
var npc_relationships: Dictionary = {}
var camp_time_of_day: String = "evening"
var current_camp_mood: String = "normal"

# Purpose: Defines the resource 'flavor' for each map node.
# Values are multipliers or base ranges for passive collection.
var base_yield_table: Dictionary = {
	0: {"name": "Evergreen Forest", "wood": "High", "iron": "Low", "gold": "Medium"},
	1: {"name": "Ironcrest Mines", "wood": "Low", "iron": "High", "gold": "Low"},
	2: {"name": "Trade Hub Outskirts", "wood": "Medium", "iron": "Medium", "gold": "High"},
	3: {"name": "Cursed Marshes", "wood": "Medium", "iron": "Low", "gold": "Very High"}
}

var _suppress_seraphina_legacy_sync: bool = false
var _legacy_seraphina_disposition: int = 0
var _legacy_seraphina_romance_rank: int = 0
var _legacy_seraphina_met_today: bool = false

var seraphina_disposition: int:
	get:
		return _legacy_seraphina_disposition
	set(value):
		_legacy_seraphina_disposition = value
		if not _suppress_seraphina_legacy_sync:
			_apply_legacy_seraphina_to_relationship_state()

var seraphina_romance_rank: int:
	get:
		return _legacy_seraphina_romance_rank
	set(value):
		_legacy_seraphina_romance_rank = value
		if not _suppress_seraphina_legacy_sync:
			_apply_legacy_seraphina_to_relationship_state()

var seraphina_met_today: bool:
	get:
		return _legacy_seraphina_met_today
	set(value):
		_legacy_seraphina_met_today = value
		if not _suppress_seraphina_legacy_sync:
			_apply_legacy_seraphina_to_relationship_state()

# --- CAMPAIGN STATE ---
var custom_avatar: Dictionary = {}
var player_roster: Array[Dictionary] = []
var active_save_slot: int = -1
var global_gold: int = 0
var global_fame: int = 0
var global_inventory: Array[Resource] = []
## listing_id -> escrowed gold currently locked for the local player in live auction bids.
var auction_gold_escrow_by_listing: Dictionary = {}
## listing_action key -> true once local payout/item application has been consumed.
## Example keys: "<listing_id>:seller_paid", "<listing_id>:winner_item".
var auction_applied_receipts: Dictionary = {}
## listing_id -> listing payload for local auction entries not yet confirmed to cloud.
var auction_pending_local_listings_by_id: Dictionary = {}

# --- CAMP PERSISTENCE ---
var camp_shop_stock: Array[Resource] = []
var camp_discount_item: Resource = null
## Extra fraction (0–0.15) shaved off the spotlight deal after successful haggles this stock; reset when shop stock refreshes.
var camp_haggle_extra_off: float = 0.0
## Optional second half-price slot from a lucky haggle win; cleared with shop refresh / purchase.
var camp_second_discount_item: Resource = null
var camp_has_haggled: bool = false
var blacksmith_unlocked: bool = false
var owned_expedition_maps: Array[String] = []
## Expedition map ids cleared at least once via expedition victory (load_next_level expedition branch). Persisted; see save_game/load_game/reset.
var completed_expedition_map_ids: Array[String] = []
## map_id -> cartographer survey line; set once on first clear from ExpeditionMapDatabase outcome pool. Persisted.
var expedition_outcome_notes: Dictionary = {}
## Last max_unlocked_index used to build expedition_cartographer_visible_map_ids; refresh when it changes. Persisted.
var expedition_cartographer_offer_stamp: int = -999
## Map ids currently on the Cartographer counter (subset of DB + progression). Persisted.
var expedition_cartographer_visible_map_ids: Array[String] = []

# --- WORLD MAP & PROGRESSION ---
var current_level_index: int = 0
var max_unlocked_index: int = 0
var is_skirmish_mode: bool = false
## True while the current battle was started from an expedition world-map node (not inferred from progression).
var is_expedition_run: bool = false
## DB id for the expedition map that started the current run (empty when not expedition-driven).
var active_expedition_map_id: String = ""
## expedition_modifier_id from DB for the active expedition run only (session; not saved).
var active_expedition_modifier_id: String = ""
## Mock co-op battle handoff (validated); consumed once by BattleField. Session-only, not saved.
var _pending_mock_coop_battle_handoff: Dictionary = {}

# --- ENCOUNTER MEMORY (chained events / remembered consequences) ---
# Persistent flags set/cleared by world-map encounters; used for selection and option/result variants.
var encounter_flags: Dictionary = {}

# Cumulative story-battle resonance (not arena/skirmish). Keys are a fixed small set; merged into camp story_flags.
var battle_resonance_flags: Dictionary = {}

# --- SCAVENGER CLAIM HISTORY (correctness: prevent re-claim after refresh/reload) ---
# score_id -> total quantity already claimed by this player for that score. Persisted in save.
var claimed_scavenger_scores: Dictionary = {}

# --- BASE MANAGEMENT ---
# Purpose: Tracks the status, location, and economy of the player's single forward operating base.
var active_base_level_index: int = -1
var base_resource_storage: Dictionary = {"wood": 0, "iron": 0, "gold": 0}
var base_under_attack: bool = false

var base_last_harvest_report: Dictionary = {}

# Hijack Flag: Set to true when entering a map specifically to defend the base.
# The level script will read this and delete narrative objectives.
var is_base_defense_active: bool = false

var camera_pan_speed: float = 600.0
var unit_move_speed: float = 0.15
## Whole-game speed via Engine.time_scale; only 1.0, 1.5, and 2.0 are offered in settings.
var game_speed_scale: float = 1.0
var performance_vsync: bool = true
## 0 = unlimited; otherwise Engine.max_fps (common presets from settings menu).
var performance_max_fps: int = 0
## 0 = Fullscreen, 1 = Windowed, 2 = Borderless Fullscreen
var performance_window_mode: int = 0
## Index into RESOLUTION_OPTIONS; default 3 = 1920×1080.
var performance_resolution: int = 3
## 0 = Disabled, 1 = 2X, 2 = 4X, 3 = 8X
var performance_msaa: int = 0
var performance_show_fps: bool = false
var performance_screen_shake: bool = true

## --- INTERFACE SETTINGS ---
## 0 = 1.0x, 1 = 1.25x, 2 = 1.5x, 3 = 1.75x, 4 = 2.0x
var interface_hud_scale: int = 2
var interface_show_damage_numbers: bool = true
var interface_show_health_bars: bool = true
## Smart declutter: keep HP/poise on map, but show EXP/full overhead only for focused units.
var interface_focus_unit_bars: bool = true
## If true, place on-map unit bars near the unit's feet instead of above the head.
var interface_unit_bars_at_feet: bool = false
var interface_show_phase_banner: bool = true
var interface_show_status_effects: bool = true
## 0 = Small, 1 = Medium, 2 = Large
var interface_damage_text_size: int = 1
## 0 = Small, 1 = Medium, 2 = Large
var interface_combat_log_font_size: int = 1
## 0 = 1.0x, 1 = 1.15x, 2 = 1.3x
var interface_cursor_size: int = 0
var interface_cursor_high_contrast: bool = false
## In-game display name override (menus, co-op label, feedback). Empty = Steam (if any), then avatar, then fallback.
var player_profile_display_override: String = ""
const PLAYER_PROFILE_DISPLAY_NAME_MAX_LEN := 48
var merchant_reputation: int = 0

var merchant_quests_completed: int = 0
var merchant_quest_active: bool = false
var merchant_quest_item_name: String = ""
var merchant_quest_target_amount: int = 0
var merchant_quest_reward: int = 0

# --- CAMP REQUESTS (Explore Camp v1) ---
var camp_request_status: String = ""
var camp_request_giver_name: String = ""
var camp_request_type: String = ""
var camp_request_title: String = ""
var camp_request_description: String = ""
var camp_request_target_name: String = ""
var camp_request_target_amount: int = 0
var camp_request_progress: int = 0
var camp_request_reward_gold: int = 0
var camp_request_reward_affinity: int = 0
var camp_request_payload: Dictionary = {}
var camp_requests_completed: int = 0
# Level-cleared-based pacing: increments only on successful story level completion (load_next_level).
var camp_request_progress_level: int = 0
# unit_name -> level threshold; giver eligible when camp_request_progress_level >= threshold. No entry = eligible.
var camp_request_unit_next_eligible_level: Dictionary = {}
var camp_request_recent_givers: Array = []
var camp_requests_completed_by_unit: Dictionary = {}

# --- AVATAR-TO-UNIT RELATIONSHIP (lightweight; foundation for real quests, support scenes, camp trust gates) ---
# key = unit_name (String), value = { score, requests_completed, branching_successes, branching_failures, last_change, last_reason }
# Score 0–100. Tier derived from score (stranger / known / trusted / close / bonded). Save/load safe; missing unit = safe defaults.
var avatar_relationship_by_unit: Dictionary = {}

# --- PERSONAL QUEST / PROGRESSION (relationship-gated; one-at-a-time with camp requests) ---
# Foundation for deeper personal quests, support-style scenes, trust-gated camp interactions.
# key = unit_name, value = { unlocked, active, completed, last_offered_at_score, seen_unlock_scene }.
# Used now: active (set/clear on accept/clear/turn-in), completed (set on turn-in). Reserved for future: unlocked, last_offered_at_score, seen_unlock_scene.
var personal_quest_state_by_unit: Dictionary = {}

# --- SPECIAL CAMP SCENES SEEN (one-time trusted/close scenes) ---
# key = "unit_name|tier" (e.g. "Liora|trusted"), value = true when one_time scene was shown.
var special_camp_scenes_seen: Dictionary = {}

# --- BASE RESOURCE PREFABS ---
var wood_item_path: String = "res://Resources/Materials/Wooden Plank.tres"
var iron_item_path: String = "res://Resources/GeneratedItems/Mat_Iron_Ore.tres"

# --- CRAFTING UNLOCKS ---
var has_recipe_book: bool = false
var has_smelter: bool = false
var unlocked_recipes: Array[String] = []

var unlocked_music_paths: Array[String] = []

# --- JUKEBOX PERSISTENT STATE (playlists + last session) ---
# saved_music_playlists: playlist_name -> Array of track path strings (save-friendly).
var saved_music_playlists: Dictionary = {}
var jukebox_volume_db: float = 0.0
var jukebox_last_mode: String = "default"
var jukebox_last_track_path: String = ""
var jukebox_last_playlist_name: String = ""
var favorite_music_paths: Array[String] = []
var jukebox_last_selected_list_item: int = 0
var jukebox_favorites_only: bool = false
var jukebox_sort_mode: String = "unlock"

# --- ARENA: streak/tokens/MMR + last locked team identity (persisted in save_game) ---
var arena_win_streak: int = 0
var arena_best_win_streak: int = 0
var gladiator_tokens: int = 0
## Fingerprint of last arena lock-in for restoring [ArenaManager.local_arena_team] after load (not the cloud snapshot).
var arena_locked_team_identity: Array = []

# --- Camp lore (one-time optional camp conversations) ---
var seen_camp_lore: Dictionary = {}

# --- Camp pair scenes (one-time paired camp interactions) ---
var seen_camp_pair_scenes: Dictionary = {}

# --- Camp memory (lightweight persistent social consequences) ---
var camp_memory: Dictionary = {}
var camp_unit_condition: Dictionary = {}
var camp_condition_last_applied_progress_level: int = -1

# --- NEW: ANTI-EXPLOIT SHOP CACHE ---
var active_shop_inventory: Array[Resource] = []

var campaign_levels: Array[String] = [
	"res://Scenes/Levels/Level1.tscn",
	"res://Scenes/Levels/Level2.tscn", # Index 1
	"res://Scenes/Levels/Level3.tscn"  # Index 2
]

# --- NARRATIVE TRANSITIONS ---

# 1. Plays when leaving Camp/World Map to start a new level
var pre_battle_transitions: Array[String] = [
	"",                              # Before Map 1
	"res://Scenes/Transition2.tscn", # Before Map 2
	"res://Scenes/Transition3.tscn"  # Before Map 3
]

# 2. Plays immediately after clicking "Continue" on the Victory Screen
var post_battle_transitions: Array[String] = [
	"res://Scenes/camp_transition.tscn", # After Map 1
	"res://Scenes/camp_menu.tscn",       # After Map 2
	"res://Scenes/camp_menu.tscn"        # After Map 3
]

enum Difficulty { NORMAL, HARD, MADDENING }
var current_difficulty: Difficulty = Difficulty.NORMAL

# The master inventory of placeable structures
var player_structures: Array[Dictionary] = [
	{
		"name": "Wooden Crate",
		"type": "barricade",
		"count": 3,
		"scene_path": "res://Resources/Destructibles/DestructibleCrate.tscn"
	},
	{
		"name": "Portable Fort",
		"type": "fortress",
		"count": 2,
		"scene_path": "res://Scenes/PortableFortress.tscn"
	},
	{
		"name": "Mercenary Tent",
		"type": "spawner",
		"count": 1,
		"scene_path": "res://Scenes/MercenaryTent.tscn"
	}
]

func _reset_player_structures() -> void:
	player_structures = [
		{
			"name": "Wooden Crate",
			"type": "barricade",
			"count": 3,
			"scene_path": "res://Resources/Destructibles/DestructibleCrate.tscn"
		},
		{
			"name": "Portable Fort",
			"type": "fortress",
			"count": 2,
			"scene_path": "res://Scenes/PortableFortress.tscn"
		},
		{
			"name": "Mercenary Tent",
			"type": "spawner",
			"count": 1,
			"scene_path": "res://Scenes/MercenaryTent.tscn"
		}
	]

func get_arena_gold_multiplier() -> float:
	var bonus_steps: int = max(0, arena_win_streak - 1) 
	return min(1.0 + (float(bonus_steps) * 0.20), 2.0) 

func _clamp_arena_persistence() -> void:
	arena_mmr = ArenaManager.clamp_mmr_int(int(arena_mmr))
	gladiator_tokens = clampi(int(gladiator_tokens), 0, ArenaManager.GLADIATOR_TOKENS_MAX)
	arena_win_streak = clampi(int(arena_win_streak), 0, ArenaManager.ARENA_WIN_STREAK_MAX)
	arena_best_win_streak = clampi(int(arena_best_win_streak), 0, ArenaManager.ARENA_WIN_STREAK_MAX)
	if arena_locked_team_identity is Array and arena_locked_team_identity.size() > ArenaManager.ARENA_MAX_SQUAD_SLOTS:
		arena_locked_team_identity = (arena_locked_team_identity as Array).slice(0, ArenaManager.ARENA_MAX_SQUAD_SLOTS)

func record_arena_win(base_gold: int = 150) -> Dictionary:
	arena_win_streak += 1
	arena_win_streak = mini(arena_win_streak, ArenaManager.ARENA_WIN_STREAK_MAX)
	arena_best_win_streak = max(arena_best_win_streak, arena_win_streak)

	var multiplier: float = get_arena_gold_multiplier() 
	var gold_reward: int = int(round(float(base_gold) * multiplier)) 
	var token_reward: int = 1 + int(floor(float(arena_win_streak - 1) / 2.0)) 

	global_gold += gold_reward
	gladiator_tokens += token_reward
	gladiator_tokens = clampi(gladiator_tokens, 0, ArenaManager.GLADIATOR_TOKENS_MAX)

	return {
		"streak": arena_win_streak,
		"multiplier": multiplier,
		"gold": gold_reward,
		"tokens": token_reward
	}

func record_arena_loss() -> void:
	arena_win_streak = 0

func _normalize_camp_mood(value: String) -> String:
	var mood: String = str(value).strip_edges().to_lower()
	if mood in ["normal", "hopeful", "tense", "somber"]:
		return mood
	return "normal"

func get_current_camp_mood() -> String:
	current_camp_mood = _normalize_camp_mood(current_camp_mood)
	return current_camp_mood

func set_current_camp_mood(mood: String) -> void:
	current_camp_mood = _normalize_camp_mood(mood)

func _encounter_flags_match_any(tokens: Array[String]) -> bool:
	if encounter_flags.is_empty() or tokens.is_empty():
		return false
	for k in encounter_flags.keys():
		if not bool(encounter_flags.get(k, false)):
			continue
		var key: String = str(k).strip_edges().to_lower()
		if key.is_empty():
			continue
		for token in tokens:
			var t: String = str(token).strip_edges().to_lower()
			if t != "" and key.find(t) >= 0:
				return true
	return false

func _resolve_chapter_tone_fallback() -> String:
	var lvl: int = maxi(1, int(camp_request_progress_level) + 1)
	match lvl:
		1:
			return "somber"
		2, 3:
			return "tense"
		6:
			return "hopeful"
		7:
			return "tense"
		10:
			return "tense"
		11:
			return "normal"
		14:
			return "tense"
		15:
			return "somber"
		17, 18:
			return "tense"
		19:
			return "somber"
		20:
			if _encounter_flags_match_any(["sacrifice", "grief", "mourning", "loss"]):
				return "somber"
			return "hopeful"
		_:
			return "normal"

func resolve_auto_camp_mood() -> String:
	var status: String = str(camp_request_status).strip_edges().to_lower()
	if status == "failed":
		return "somber"
	if is_base_defense_active:
		return "tense"

	if _encounter_flags_match_any(["catastrophe", "collapse", "betray", "ambush", "haunted", "void", "ritual_fail", "grief"]):
		return "somber"
	if _encounter_flags_match_any(["siege", "retreat", "crisis", "threat", "storm", "judgment", "trial", "assassin", "war"]):
		return "tense"
	if _encounter_flags_match_any(["hub", "greyspire", "coalition", "alliance", "festival", "secured", "victory", "relief"]):
		return "hopeful"

	if global_fame <= -5:
		return "somber"
	if global_fame >= 20 and int(camp_request_progress_level) >= 5:
		return "hopeful"

	return _resolve_chapter_tone_fallback()

func reset_campaign_data() -> void:
	player_roster.clear()
	global_inventory.clear()
	global_gold = 0
	global_fame = 0
	auction_gold_escrow_by_listing.clear()
	auction_applied_receipts.clear()
	auction_pending_local_listings_by_id.clear()
	merchant_reputation = 0
	current_level_index = 0
	max_unlocked_index = 0
	is_skirmish_mode = false
	is_expedition_run = false
	active_expedition_map_id = ""
	active_expedition_modifier_id = ""
	encounter_flags.clear()
	battle_resonance_flags.clear()
	claimed_scavenger_scores.clear()
	seen_camp_lore.clear()
	seen_camp_pair_scenes.clear()
	camp_memory.clear()
	camp_unit_condition.clear()
	camp_condition_last_applied_progress_level = -1
	merchant_quests_completed = 0
	merchant_quest_active = false
	merchant_quest_item_name = ""
	merchant_quest_target_amount = 0
	merchant_quest_reward = 0
	camp_request_status = ""
	camp_request_giver_name = ""
	camp_request_type = ""
	camp_request_title = ""
	camp_request_description = ""
	camp_request_target_name = ""
	camp_request_target_amount = 0
	camp_request_progress = 0
	camp_request_reward_gold = 0
	camp_request_reward_affinity = 0
	camp_request_payload = {}
	camp_requests_completed = 0
	camp_request_progress_level = 0
	camp_request_unit_next_eligible_level = {}
	camp_request_recent_givers = []
	camp_requests_completed_by_unit = {}
	personal_quest_state_by_unit.clear()
	special_camp_scenes_seen.clear()
	support_bonds.clear()
	relationship_web.clear()
	claimed_rank_rewards.clear()
	blacksmith_unlocked = false
	owned_expedition_maps.clear()
	completed_expedition_map_ids.clear()
	expedition_outcome_notes.clear()
	expedition_cartographer_offer_stamp = -999
	expedition_cartographer_visible_map_ids.clear()
	clear_pending_mock_coop_battle_handoff()
	has_recipe_book = false
	has_smelter = false
	unlocked_recipes.clear()
	unlocked_music_paths.clear()
	saved_music_playlists.clear()
	jukebox_last_mode = "default"
	jukebox_last_track_path = ""
	jukebox_last_playlist_name = ""
	favorite_music_paths.clear()
	jukebox_last_selected_list_item = 0
	jukebox_favorites_only = false
	jukebox_sort_mode = "unlock"
	DragonManager.player_dragons.clear()
	active_shop_inventory.clear()
	base_last_harvest_report.clear()
	npc_relationships.clear()
	camp_time_of_day = "evening"
	current_camp_mood = "normal"
	morgra_favorite_dragon_uid = ""
	morgra_anger_duration = 0
	morgra_neutral_duration = 0
	morgra_favorite_survived_battles = 0

	arena_mmr = 1000
	gladiator_tokens = 0
	arena_win_streak = 0
	arena_best_win_streak = 0
	arena_locked_team_identity.clear()
	ArenaManager.clear_local_arena_team_state()

	ensure_seraphina_state()
	_sync_seraphina_legacy_from_relationship_state()
	ensure_camp_memory()

	_reset_player_structures()
	reset_camp_shop()
	
	# --- RESET BASE MANAGEMENT ---
	active_base_level_index = -1
	base_resource_storage = {"wood": 0, "iron": 0, "gold": 0}
	base_under_attack = false
	is_base_defense_active = false

	current_difficulty = Difficulty.NORMAL

	custom_avatar.clear()

	print("Campaign RAM successfully wiped for a fresh start.")
			
func reset_camp_shop() -> void:
	camp_shop_stock.clear()
	camp_discount_item = null
	camp_second_discount_item = null
	camp_haggle_extra_off = 0.0
	camp_has_haggled = false

func delete_game(slot: int) -> void:
	var dir = DirAccess.open("user://")
	if dir == null:
		return

	var man_file = "save_slot_" + str(slot) + ".dat"
	var auto_file = "auto_save_" + str(slot) + ".dat"
	if dir.file_exists(man_file):
		dir.remove(man_file)
	if dir.file_exists(auto_file):
		dir.remove(auto_file)

	if active_save_slot == slot:
		active_save_slot = -1

# ==========================================
# ITEM LIFECYCLE (UNIQUENESS + SAVE FORMAT)
# ==========================================

func make_unique_item(src: Resource) -> Resource:
	if src == null:
		return null

	var inst: Resource = src.duplicate(true)

	var opath := ""
	if src.resource_path != "":
		opath = src.resource_path
	elif src.has_meta("original_path"):
		opath = str(src.get_meta("original_path"))

	if opath != "":
		inst.set_meta("original_path", opath)

	if not inst.has_meta("uid"):
		inst.set_meta("uid", str(Time.get_unix_time_from_system()) + "_" + str(randi()))

	return inst

func duplicate_item(original: Resource) -> Resource:
	var dup = make_unique_item(original)
	if dup == null and original != null and not (original is WeaponData):
		return original
	return dup


func _serialize_socketed_runes_for_item(raw: Variant, max_slots: int) -> Array:
	var cap: int = clampi(max_slots, 0, 8)
	var out: Array = []
	if cap <= 0:
		return out
	if raw is Array:
		for entry in raw as Array:
			if out.size() >= cap:
				break
			if not (entry is Dictionary):
				continue
			var e: Dictionary = entry as Dictionary
			var rid: String = str(e.get("id", "")).strip_edges()
			if rid == "":
				continue
			var row: Dictionary = {
				"id": rid,
				"rank": clampi(int(e.get("rank", 0)), 0, 999),
			}
			if e.has("charges"):
				row["charges"] = clampi(int(e.get("charges", 0)), 0, 999999)
			out.append(row)
	return out


func _deserialize_socketed_runes_for_item(raw: Variant, max_slots: int) -> Array[Dictionary]:
	var cap: int = clampi(max_slots, 0, 8)
	var out: Array[Dictionary] = []
	if cap <= 0:
		return out
	if raw is Array:
		for entry in raw as Array:
			if out.size() >= cap:
				break
			if not (entry is Dictionary):
				continue
			var e: Dictionary = entry as Dictionary
			var rid: String = str(e.get("id", "")).strip_edges()
			if rid == "":
				continue
			var row: Dictionary = {"id": rid, "rank": clampi(int(e.get("rank", 0)), 0, 999)}
			if e.has("charges"):
				row["charges"] = clampi(int(e.get("charges", 0)), 0, 999999)
			out.append(row)
	return out


func _serialize_item(item: Resource) -> Dictionary:
	if item == null:
		return {}

	var path := ""
	if item.resource_path != "":
		path = item.resource_path
	elif item.has_meta("original_path"):
		path = str(item.get_meta("original_path"))

	if path == "":
		# Item has no path/original_path; omit from save so save does not corrupt. No warning to avoid log spam; ensure all code paths use make_unique_item() or set_meta("original_path", path) when adding to inventory.
		return {}

	var uid := ""
	if item.has_meta("uid"):
		uid = str(item.get_meta("uid"))

	var data: Dictionary = {
		"path": path,
		"uid": uid,
		"type": item.get_class()
	}
	
	if item.has_meta("is_locked"): 
		data["is_locked"] = item.get_meta("is_locked")
	if item.has_meta("base_recipe_name"): 
		data["base_recipe_name"] = item.get_meta("base_recipe_name")

	if item is WeaponData:
		var w: WeaponData = item as WeaponData
		data["weapon_name"] = w.weapon_name
		data["might"] = w.might
		data["hit_bonus"] = w.hit_bonus
		data["rarity"] = w.rarity
		data["gold_cost"] = w.get("gold_cost") if w.get("gold_cost") != null else 0
		data["current_durability"] = w.current_durability
		data["max_durability"] = w.max_durability
		data["rune_slot_count"] = clampi(w.rune_slot_count, 0, 8)
		data["socketed_runes"] = _serialize_socketed_runes_for_item(w.socketed_runes, w.rune_slot_count)

	return data

func _deserialize_item(d) -> Resource:
	if d == null or typeof(d) != TYPE_DICTIONARY or d.is_empty():
		return null

	var path := str(d.get("path", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null

	var template: Resource = load(path)
	if template == null:
		return null

	var inst: Resource = make_unique_item(template)

	var uid := str(d.get("uid", ""))
	if uid != "":
		inst.set_meta("uid", uid)
		
	if d.has("is_locked"): 
		inst.set_meta("is_locked", d["is_locked"])
	if d.has("base_recipe_name"): 
		inst.set_meta("base_recipe_name", d["base_recipe_name"])

	if inst is WeaponData:
		var w: WeaponData = inst as WeaponData
		if d.has("weapon_name"): w.weapon_name = str(d["weapon_name"])
		if d.has("might"): w.might = int(d["might"])
		if d.has("hit_bonus"): w.hit_bonus = int(d["hit_bonus"])
		if d.has("rarity"): w.rarity = str(d["rarity"])
		if d.has("gold_cost"): w.gold_cost = int(d["gold_cost"])
		if d.has("current_durability"): w.current_durability = int(d["current_durability"])
		if d.has("max_durability"): w.max_durability = int(d["max_durability"])
		if d.has("rune_slot_count"):
			w.rune_slot_count = clampi(int(d["rune_slot_count"]), 0, 8)
		if d.has("socketed_runes"):
			w.socketed_runes = _deserialize_socketed_runes_for_item(d["socketed_runes"], w.rune_slot_count)

	return inst

# --- Avatar relationship save/load (primitive-only; old saves without key = safe defaults on read) ---
func _serialize_arc_flags(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if raw is Dictionary:
		for k in raw as Dictionary:
			if bool((raw as Dictionary)[k]):
				out[str(k)] = true
	return out


func _deserialize_arc_flags(raw: Variant) -> Dictionary:
	return _serialize_arc_flags(raw)


func _serialize_avatar_relationships() -> Dictionary:
	var out: Dictionary = {}
	for unit_name in avatar_relationship_by_unit:
		var entry: Variant = avatar_relationship_by_unit[unit_name]
		if entry is Dictionary:
			var d: Dictionary = entry as Dictionary
			out[str(unit_name)] = {
				"score": int(d.get("score", 0)),
				"requests_completed": int(d.get("requests_completed", 0)),
				"branching_successes": int(d.get("branching_successes", 0)),
				"branching_failures": int(d.get("branching_failures", 0)),
				"last_change": int(d.get("last_change", 0)),
				"last_reason": str(d.get("last_reason", "")),
				"personal_arc_stage": maxi(0, int(d.get("personal_arc_stage", 0))),
				"arc_flags": _serialize_arc_flags(d.get("arc_flags", {})),
			}
	return out

func _deserialize_avatar_relationships(raw: Variant) -> void:
	avatar_relationship_by_unit.clear()
	if raw == null or typeof(raw) != TYPE_DICTIONARY:
		return
	for unit_name in raw:
		var entry: Variant = raw[unit_name]
		if entry is Dictionary:
			var d: Dictionary = entry as Dictionary
			avatar_relationship_by_unit[str(unit_name)] = {
				"score": clampi(int(d.get("score", 0)), 0, 100),
				"requests_completed": maxi(0, int(d.get("requests_completed", 0))),
				"branching_successes": maxi(0, int(d.get("branching_successes", 0))),
				"branching_failures": maxi(0, int(d.get("branching_failures", 0))),
				"last_change": int(d.get("last_change", 0)),
				"last_reason": str(d.get("last_reason", "")).strip_edges(),
				"personal_arc_stage": maxi(0, int(d.get("personal_arc_stage", 0))),
				"arc_flags": _deserialize_arc_flags(d.get("arc_flags", {})),
			}

func _serialize_personal_quest_states() -> Dictionary:
	var out: Dictionary = {}
	for unit_name in personal_quest_state_by_unit:
		var entry: Variant = personal_quest_state_by_unit[unit_name]
		if entry is Dictionary:
			var d: Dictionary = entry as Dictionary
			out[str(unit_name)] = {
				"unlocked": bool(d.get("unlocked", false)),
				"active": bool(d.get("active", false)),
				"completed": bool(d.get("completed", false)),
				"last_offered_at_score": int(d.get("last_offered_at_score", 0)),
				"seen_unlock_scene": bool(d.get("seen_unlock_scene", false)),
			}
	return out

func _deserialize_personal_quest_states(raw: Variant) -> void:
	personal_quest_state_by_unit.clear()
	if raw == null or typeof(raw) != TYPE_DICTIONARY:
		return
	for unit_name in raw:
		var entry: Variant = raw[unit_name]
		if entry is Dictionary:
			var d: Dictionary = entry as Dictionary
			personal_quest_state_by_unit[str(unit_name)] = {
				"unlocked": bool(d.get("unlocked", false)),
				"active": bool(d.get("active", false)),
				"completed": bool(d.get("completed", false)),
				"last_offered_at_score": int(d.get("last_offered_at_score", 0)),
				"seen_unlock_scene": bool(d.get("seen_unlock_scene", false)),
			}

# ==========================================
# CORE SAVING & LOADING
# ==========================================

func save_game(slot: int, is_auto: bool = false) -> void:
	var path = get_save_path(slot, is_auto)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
		
	ensure_seraphina_state()
	_sync_seraphina_legacy_from_relationship_state()
	
	# 1) Global inventory
	var inventory_saved: Array = []
	for item in global_inventory:
		var s := _serialize_item(item)
		if not s.is_empty():
			inventory_saved.append(s)

	# 2) Camp shop
	var shop_stock_saved: Array = []
	for item in camp_shop_stock:
		var s := _serialize_item(item)
		if not s.is_empty():
			shop_stock_saved.append(s)

	# --- NEW: Serialize the Arena Token Shop ---
	var active_shop_saved: Array = []
	for item in active_shop_inventory:
		var s := _serialize_item(item)
		if not s.is_empty():
			active_shop_saved.append(s)

	# --- FIX 1: DISCOUNT ITEM UID RELINKING ---
	var discount_saved: Dictionary = {}
	var discount_uid: String = ""
	if camp_discount_item != null:
		discount_saved = _serialize_item(camp_discount_item)
		if camp_discount_item.has_meta("uid"):
			discount_uid = str(camp_discount_item.get_meta("uid"))

	var second_discount_saved: Dictionary = {}
	var second_discount_uid: String = ""
	if camp_second_discount_item != null:
		second_discount_saved = _serialize_item(camp_second_discount_item)
		if camp_second_discount_item.has_meta("uid"):
			second_discount_uid = str(camp_second_discount_item.get_meta("uid"))

	# 3) Roster
	var roster_to_save: Array = []
	for unit in player_roster:
		var u_copy := unit.duplicate()

		u_copy["equipped_weapon"] = {}
		var eq: Resource = unit.get("equipped_weapon")
		if eq != null:
			u_copy["equipped_weapon"] = _serialize_item(eq)

		var unit_inv_saved: Array = []
		if unit.has("inventory"):
			for it in unit["inventory"]:
				var s := _serialize_item(it)
				if not s.is_empty():
					unit_inv_saved.append(s)
		u_copy["inventory"] = unit_inv_saved

		if u_copy.get("data") is Resource:
			var data_res: Resource = u_copy["data"]
			var data_path: String = str(data_res.resource_path).strip_edges()
			if data_path == "" and data_res.has_meta("original_path"):
				data_path = str(data_res.get_meta("original_path")).strip_edges()
			if data_path == "":
				data_path = str(u_copy.get("data_path_hint", "")).strip_edges()
			u_copy["data"] = data_path if data_path != "" else ""
		if u_copy.get("class_data") is Resource: u_copy["class_data"] = u_copy["class_data"].resource_path
		if u_copy.get("portrait") is Texture2D: u_copy["portrait"] = u_copy["portrait"].resource_path
		if u_copy.get("battle_sprite") is Texture2D: u_copy["battle_sprite"] = u_copy["battle_sprite"].resource_path
		u_copy["unit_tags"] = unit.get("unit_tags", [])
		u_copy["traits"] = unit.get("traits", []).duplicate() if unit.get("traits") is Array else []
		u_copy["rookie_legacies"] = unit.get("rookie_legacies", []).duplicate() if unit.get("rookie_legacies") is Array else []
		u_copy["base_class_legacies"] = unit.get("base_class_legacies", []).duplicate() if unit.get("base_class_legacies") is Array else []
		u_copy["promoted_class_legacies"] = unit.get("promoted_class_legacies", []).duplicate() if unit.get("promoted_class_legacies") is Array else []

		roster_to_save.append(u_copy)

	# 4) Custom avatar
	var custom_avatar_saved := custom_avatar.duplicate()
	if custom_avatar_saved.get("class_data") is Resource: custom_avatar_saved["class_data"] = custom_avatar_saved["class_data"].resource_path
	if custom_avatar_saved.get("portrait") is Texture2D: custom_avatar_saved["portrait"] = custom_avatar_saved["portrait"].resource_path
	if custom_avatar_saved.get("battle_sprite") is Texture2D: custom_avatar_saved["battle_sprite"] = custom_avatar_saved["battle_sprite"].resource_path

	var save_data := {
		"support_bonds": support_bonds,
		"relationship_web": relationship_web.duplicate(),
		"custom_avatar": custom_avatar_saved,
		"player_roster": roster_to_save,
		"global_gold": global_gold,
		"global_fame": global_fame,
		"global_inventory": inventory_saved,
		"auction_gold_escrow_by_listing": auction_gold_escrow_by_listing.duplicate(),
		"auction_applied_receipts": auction_applied_receipts.duplicate(),
		"auction_pending_local_listings_by_id": auction_pending_local_listings_by_id.duplicate(true),
		"merchant_reputation": merchant_reputation,
		"current_level_index": current_level_index,
		"max_unlocked_index": max_unlocked_index,
		"merchant_quests_completed": merchant_quests_completed,
		"merchant_quest_active": merchant_quest_active,
		"merchant_quest_item_name": merchant_quest_item_name,
		"merchant_quest_target_amount": merchant_quest_target_amount,
		"merchant_quest_reward": merchant_quest_reward,

		"camp_request_status": camp_request_status,
		"camp_request_giver_name": camp_request_giver_name,
		"camp_request_type": camp_request_type,
		"camp_request_title": camp_request_title,
		"camp_request_description": camp_request_description,
		"camp_request_target_name": camp_request_target_name,
		"camp_request_target_amount": camp_request_target_amount,
		"camp_request_progress": camp_request_progress,
		"camp_request_reward_gold": camp_request_reward_gold,
		"camp_request_reward_affinity": camp_request_reward_affinity,
		"camp_request_payload": camp_request_payload.duplicate(),
		"camp_requests_completed": camp_requests_completed,
		"camp_request_progress_level": camp_request_progress_level,
		"camp_request_unit_next_eligible_level": camp_request_unit_next_eligible_level.duplicate(),
		"camp_request_recent_givers": camp_request_recent_givers.duplicate(),
		"camp_requests_completed_by_unit": camp_requests_completed_by_unit.duplicate(),
		"avatar_relationship_by_unit": _serialize_avatar_relationships(),
		"personal_quest_state_by_unit": _serialize_personal_quest_states(),
		"special_camp_scenes_seen": special_camp_scenes_seen.duplicate(),

		"camp_shop_stock": shop_stock_saved,
		"active_shop_inventory": active_shop_saved,
		"camp_discount_item": discount_saved,
		"camp_discount_uid": discount_uid,
		"camp_second_discount_item": second_discount_saved,
		"camp_second_discount_uid": second_discount_uid,
		"camp_haggle_extra_off": camp_haggle_extra_off,
		"camp_has_haggled": camp_has_haggled,
		"blacksmith_unlocked": blacksmith_unlocked,
		"owned_expedition_maps": owned_expedition_maps.duplicate(),
		"completed_expedition_map_ids": completed_expedition_map_ids.duplicate(),
		"expedition_outcome_notes": expedition_outcome_notes.duplicate(),
		"expedition_cartographer_offer_stamp": int(expedition_cartographer_offer_stamp),
		"expedition_cartographer_visible_map_ids": expedition_cartographer_visible_map_ids.duplicate(),
		"has_recipe_book": has_recipe_book,
		"has_smelter": has_smelter,
		"unlocked_music_paths": unlocked_music_paths,
		"saved_music_playlists": saved_music_playlists.duplicate(),
		"jukebox_volume_db": jukebox_volume_db,
		"jukebox_last_mode": jukebox_last_mode,
		"jukebox_last_track_path": jukebox_last_track_path,
		"jukebox_last_playlist_name": jukebox_last_playlist_name,
		"favorite_music_paths": favorite_music_paths.duplicate(),
		"jukebox_last_selected_list_item": jukebox_last_selected_list_item,
		"jukebox_favorites_only": jukebox_favorites_only,
		"jukebox_sort_mode": jukebox_sort_mode,
		"unlocked_recipes": unlocked_recipes,
		"player_structures": player_structures.duplicate(true),
		"claimed_rank_rewards": claimed_rank_rewards.duplicate(),
		"arena_mmr": arena_mmr,
		"gladiator_tokens": gladiator_tokens,
		"arena_win_streak": arena_win_streak,
		"arena_best_win_streak": arena_best_win_streak,
		"arena_locked_team_identity": arena_locked_team_identity.duplicate(true),
		"player_dragons": DragonManager.player_dragons.duplicate(true),
		
		# Base Management
		"active_base_level_index": active_base_level_index,
		"base_resource_storage": base_resource_storage.duplicate(),
		"base_under_attack": base_under_attack,
		"is_base_defense_active": is_base_defense_active,

		"current_difficulty": int(current_difficulty),

		# New relationship system
		"npc_relationships": npc_relationships.duplicate(true),
		"camp_time_of_day": camp_time_of_day,
		"current_camp_mood": get_current_camp_mood(),

		# Legacy compatibility save fields
		"seraphina_disposition": seraphina_disposition,
		"seraphina_romance_rank": seraphina_romance_rank,
		"seraphina_met_today": seraphina_met_today,
		
		"morgra_favorite_dragon_uid": morgra_favorite_dragon_uid,
		"morgra_anger_duration": morgra_anger_duration,
		"morgra_neutral_duration": morgra_neutral_duration,
		"morgra_favorite_survived_battles": morgra_favorite_survived_battles,

		"encounter_flags": encounter_flags.duplicate(),
		"battle_resonance_flags": battle_resonance_flags.duplicate(),
		"claimed_scavenger_scores": claimed_scavenger_scores.duplicate(),
		"seen_camp_lore": seen_camp_lore.duplicate(),
		"seen_camp_pair_scenes": seen_camp_pair_scenes.duplicate(),
		"camp_memory": camp_memory.duplicate(true),
		"camp_unit_condition": camp_unit_condition.duplicate(true),
		"camp_condition_last_applied_progress_level": camp_condition_last_applied_progress_level,
	}

	file.store_var(save_data)
	file.close()

func load_game(slot: int, is_auto: bool = false) -> bool:
	var path = get_save_path(slot, is_auto)
	if not FileAccess.file_exists(path):
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	var save_data = file.get_var()
	file.close()

	if typeof(save_data) != TYPE_DICTIONARY:
		return false

	clear_pending_mock_coop_battle_handoff()
	global_gold = save_data.get("global_gold", 0)
	global_fame = save_data.get("global_fame", 0)
	auction_gold_escrow_by_listing.clear()
	var raw_auction_escrow: Variant = save_data.get("auction_gold_escrow_by_listing", {})
	if raw_auction_escrow is Dictionary:
		var escrow_dict: Dictionary = raw_auction_escrow
		for listing_id_variant in escrow_dict.keys():
			var listing_id: String = str(listing_id_variant).strip_edges()
			if listing_id == "":
				continue
			var escrow_amount: int = maxi(int(escrow_dict.get(listing_id_variant, 0)), 0)
			if escrow_amount > 0:
				auction_gold_escrow_by_listing[listing_id] = escrow_amount
	auction_applied_receipts.clear()
	var raw_receipts: Variant = save_data.get("auction_applied_receipts", {})
	if raw_receipts is Dictionary:
		var receipts_dict: Dictionary = raw_receipts
		for receipt_key_variant in receipts_dict.keys():
			var receipt_key: String = str(receipt_key_variant).strip_edges()
			if receipt_key == "":
				continue
			if bool(receipts_dict.get(receipt_key_variant, false)):
				auction_applied_receipts[receipt_key] = true
	auction_pending_local_listings_by_id.clear()
	var raw_pending_listings: Variant = save_data.get("auction_pending_local_listings_by_id", {})
	if raw_pending_listings is Dictionary:
		var pending_dict: Dictionary = raw_pending_listings
		for listing_id_variant in pending_dict.keys():
			var listing_id: String = str(listing_id_variant).strip_edges()
			if listing_id == "":
				continue
			var payload_variant: Variant = pending_dict.get(listing_id_variant, {})
			if payload_variant is Dictionary:
				var payload: Dictionary = (payload_variant as Dictionary).duplicate(true)
				payload["pending_local"] = true
				payload["listing_id"] = listing_id
				auction_pending_local_listings_by_id[listing_id] = payload
	merchant_reputation = save_data.get("merchant_reputation", 0)
	
	active_base_level_index = save_data.get("active_base_level_index", -1)
	base_resource_storage = save_data.get("base_resource_storage", {"wood": 0, "iron": 0, "gold": 0})
	base_under_attack = save_data.get("base_under_attack", false)
	is_base_defense_active = save_data.get("is_base_defense_active", false)

	var diff_val: int = clampi(int(save_data.get("current_difficulty", 0)), 0, 2)
	if diff_val == 1:
		current_difficulty = Difficulty.HARD
	elif diff_val == 2:
		current_difficulty = Difficulty.MADDENING
	else:
		current_difficulty = Difficulty.NORMAL

	current_level_index = save_data.get("current_level_index", 0)
	max_unlocked_index = save_data.get("max_unlocked_index", 0)
	merchant_quests_completed = save_data.get("merchant_quests_completed", 0)
	merchant_quest_active = save_data.get("merchant_quest_active", false)
	merchant_quest_item_name = save_data.get("merchant_quest_item_name", "")
	merchant_quest_target_amount = save_data.get("merchant_quest_target_amount", 0)
	merchant_quest_reward = save_data.get("merchant_quest_reward", 0)
	camp_request_status = str(save_data.get("camp_request_status", "")).strip_edges()
	camp_request_giver_name = str(save_data.get("camp_request_giver_name", ""))
	camp_request_type = str(save_data.get("camp_request_type", ""))
	camp_request_title = str(save_data.get("camp_request_title", ""))
	camp_request_description = str(save_data.get("camp_request_description", ""))
	camp_request_target_name = str(save_data.get("camp_request_target_name", ""))
	camp_request_target_amount = int(save_data.get("camp_request_target_amount", 0))
	camp_request_progress = int(save_data.get("camp_request_progress", 0))
	camp_request_reward_gold = int(save_data.get("camp_request_reward_gold", 0))
	camp_request_reward_affinity = int(save_data.get("camp_request_reward_affinity", 0))
	var raw_payload = save_data.get("camp_request_payload", {})
	camp_request_payload = raw_payload if raw_payload is Dictionary else {}
	camp_requests_completed = int(save_data.get("camp_requests_completed", 0))
	# Level-based progression; migrate from max_unlocked_index if missing (old saves).
	camp_request_progress_level = int(save_data.get("camp_request_progress_level", max_unlocked_index))
	var raw_next_eligible = save_data.get("camp_request_unit_next_eligible_level", {})
	camp_request_unit_next_eligible_level = raw_next_eligible if raw_next_eligible is Dictionary else {}
	var raw_recent = save_data.get("camp_request_recent_givers", [])
	var recent_arr: Array = raw_recent if raw_recent is Array else []
	camp_request_recent_givers = recent_arr.duplicate()
	while camp_request_recent_givers.size() > 3:
		camp_request_recent_givers.pop_back()
	var raw_by_unit = save_data.get("camp_requests_completed_by_unit", {})
	camp_requests_completed_by_unit = raw_by_unit if raw_by_unit is Dictionary else {}
	var raw_avatar_rel = save_data.get("avatar_relationship_by_unit", {})
	_deserialize_avatar_relationships(raw_avatar_rel)
	var raw_pq = save_data.get("personal_quest_state_by_unit", {})
	_deserialize_personal_quest_states(raw_pq)
	var raw_scenes = save_data.get("special_camp_scenes_seen", {})
	special_camp_scenes_seen = raw_scenes if raw_scenes is Dictionary else {}

	camp_has_haggled = save_data.get("camp_has_haggled", false)
	support_bonds = save_data.get("support_bonds", {})
	relationship_web = save_data.get("relationship_web", {})
	
	npc_relationships = save_data.get("npc_relationships", {})
	camp_time_of_day = str(save_data.get("camp_time_of_day", "evening")).to_lower()
	set_current_camp_mood(str(save_data.get("current_camp_mood", "normal")))

	var raw_flags = save_data.get("encounter_flags", {})
	encounter_flags.clear()
	if raw_flags is Dictionary:
		for k in raw_flags:
			if str(k).strip_edges() != "" and raw_flags[k]:
				encounter_flags[str(k).strip_edges()] = true
	# Infer story beats for saves that cleared levels before encounter flags were written (camp conversation gating).
	if camp_request_progress_level >= 3:
		encounter_flags["shattered_sanctum_cleared"] = true
	if camp_request_progress_level >= 10:
		encounter_flags["sunlit_trial_cleared"] = true

	battle_resonance_flags.clear()
	var raw_resonance = save_data.get("battle_resonance_flags", {})
	if raw_resonance is Dictionary:
		for rk in raw_resonance:
			if str(rk).strip_edges() != "" and raw_resonance[rk]:
				battle_resonance_flags[str(rk).strip_edges()] = true

	claimed_scavenger_scores.clear()
	var raw_claimed = save_data.get("claimed_scavenger_scores", {})
	if raw_claimed is Dictionary:
		for sid in raw_claimed:
			var q: int = int(raw_claimed[sid])
			if str(sid).strip_edges() != "" and q > 0:
				claimed_scavenger_scores[str(sid).strip_edges()] = q

	seen_camp_lore.clear()
	var raw_lore = save_data.get("seen_camp_lore", {})
	if raw_lore is Dictionary:
		for lid in raw_lore:
			if str(lid).strip_edges() != "" and raw_lore[lid]:
				seen_camp_lore[str(lid).strip_edges()] = true

	seen_camp_pair_scenes.clear()
	var raw_pairs = save_data.get("seen_camp_pair_scenes", {})
	if raw_pairs is Dictionary:
		for pid in raw_pairs:
			if str(pid).strip_edges() != "" and raw_pairs[pid]:
				seen_camp_pair_scenes[str(pid).strip_edges()] = true

	var raw_camp_memory = save_data.get("camp_memory", {})
	if raw_camp_memory is Dictionary:
		camp_memory = (raw_camp_memory as Dictionary).duplicate(true)
	else:
		camp_memory = {}
	ensure_camp_memory()
	var raw_condition = save_data.get("camp_unit_condition", {})
	if raw_condition is Dictionary:
		camp_unit_condition = (raw_condition as Dictionary).duplicate(true)
	else:
		camp_unit_condition = {}
	camp_condition_last_applied_progress_level = int(save_data.get("camp_condition_last_applied_progress_level", -1))
	ensure_camp_unit_condition()

	_migrate_legacy_seraphina_state(save_data)
	ensure_seraphina_state()
	_sync_seraphina_legacy_from_relationship_state()
	morgra_favorite_dragon_uid = save_data.get("morgra_favorite_dragon_uid", "")
	morgra_anger_duration = save_data.get("morgra_anger_duration", 0)
	morgra_neutral_duration = save_data.get("morgra_neutral_duration", 0)
	morgra_favorite_survived_battles = save_data.get("morgra_favorite_survived_battles", 0)
	
	DragonManager.player_dragons.clear()
	var loaded_dragons = save_data.get("player_dragons", [])
	for d in loaded_dragons:
		if d is Dictionary:
			DragonManager.player_dragons.append(d)

	for d in DragonManager.player_dragons:
		if d is Dictionary and not d.has("ranch_action_used_this_level"):
			d["ranch_action_used_this_level"] = false
	
	unlocked_music_paths.clear()
	for m in save_data.get("unlocked_music_paths", []): unlocked_music_paths.append(str(m))

	var raw_playlists = save_data.get("saved_music_playlists", {})
	saved_music_playlists.clear()
	if raw_playlists is Dictionary:
		for k in raw_playlists.keys():
			var arr = raw_playlists[k]
			if arr is Array:
				saved_music_playlists[str(k)] = arr.duplicate()
	jukebox_volume_db = save_data.get("jukebox_volume_db", 0.0)
	jukebox_last_mode = str(save_data.get("jukebox_last_mode", "default"))
	jukebox_last_track_path = str(save_data.get("jukebox_last_track_path", ""))
	jukebox_last_playlist_name = str(save_data.get("jukebox_last_playlist_name", ""))
	favorite_music_paths.clear()
	for p in save_data.get("favorite_music_paths", []):
		favorite_music_paths.append(str(p))
	jukebox_last_selected_list_item = maxi(0, int(save_data.get("jukebox_last_selected_list_item", 0)))
	jukebox_favorites_only = bool(save_data.get("jukebox_favorites_only", false))
	jukebox_sort_mode = str(save_data.get("jukebox_sort_mode", "unlock")).to_lower()
	if jukebox_sort_mode != "alpha":
		jukebox_sort_mode = "unlock"

	has_recipe_book = save_data.get("has_recipe_book", false)
	unlocked_recipes.clear()
	for r in save_data.get("unlocked_recipes", []): unlocked_recipes.append(str(r))
		
	blacksmith_unlocked = save_data.get("blacksmith_unlocked", false)
	owned_expedition_maps = _sanitize_owned_expedition_maps(save_data.get("owned_expedition_maps", []))
	completed_expedition_map_ids = _sanitize_owned_expedition_maps(save_data.get("completed_expedition_map_ids", []))
	expedition_outcome_notes = _sanitize_expedition_outcome_notes(save_data.get("expedition_outcome_notes", {}))
	expedition_cartographer_offer_stamp = int(save_data.get("expedition_cartographer_offer_stamp", -999))
	expedition_cartographer_visible_map_ids = _sanitize_owned_expedition_maps(save_data.get("expedition_cartographer_visible_map_ids", []))
	has_smelter = save_data.get("has_smelter", false)
	
	player_structures.clear()
	var raw_structures = save_data.get("player_structures", [])
	for s in raw_structures:
		if typeof(s) == TYPE_DICTIONARY:
			player_structures.append(s.duplicate(true))

	if player_structures.is_empty():
		_reset_player_structures()

	custom_avatar = save_data.get("custom_avatar", {})
	if custom_avatar.get("class_data") is String and ResourceLoader.exists(custom_avatar["class_data"]): custom_avatar["class_data"] = load(custom_avatar["class_data"])
	if custom_avatar.get("portrait") is String and ResourceLoader.exists(custom_avatar["portrait"]): custom_avatar["portrait"] = load(custom_avatar["portrait"])
	if custom_avatar.get("battle_sprite") is String and ResourceLoader.exists(custom_avatar["battle_sprite"]): custom_avatar["battle_sprite"] = load(custom_avatar["battle_sprite"])

	global_inventory.clear()
	for d in save_data.get("global_inventory", []):
		var it: Resource = _deserialize_item(d)
		if it != null: global_inventory.append(it)

	camp_shop_stock.clear()
	for d in save_data.get("camp_shop_stock", []):
		var it: Resource = _deserialize_item(d)
		if it != null: camp_shop_stock.append(it)

	# --- NEW: LOAD ARENA SHOP STOCK ---
	active_shop_inventory.clear()
	for d in save_data.get("active_shop_inventory", []):
		var it: Resource = _deserialize_item(d)
		if it != null: active_shop_inventory.append(it)

	# --- FIX 1: RESTORING DISCOUNT ITEM PROPERLY ---
	camp_discount_item = null
	var discount_uid: String = str(save_data.get("camp_discount_uid", ""))

	if discount_uid != "":
		for it in camp_shop_stock:
			if it != null and it.has_meta("uid") and str(it.get_meta("uid")) == discount_uid:
				camp_discount_item = it
				break

	if camp_discount_item == null:
		var discount_data = save_data.get("camp_discount_item", {})
		if typeof(discount_data) == TYPE_DICTIONARY and not discount_data.is_empty():
			var discount_path: String = str(discount_data.get("path", ""))
			for it in camp_shop_stock:
				if it == null: continue
				var it_path: String = ""
				if it.resource_path != "": it_path = it.resource_path
				elif it.has_meta("original_path"): it_path = str(it.get_meta("original_path"))
				if it_path == discount_path:
					camp_discount_item = it
					break

	camp_haggle_extra_off = clampf(float(save_data.get("camp_haggle_extra_off", 0.0)), 0.0, 0.2)
	camp_second_discount_item = null
	var second_uid: String = str(save_data.get("camp_second_discount_uid", ""))
	if second_uid != "":
		for it in camp_shop_stock:
			if it != null and it.has_meta("uid") and str(it.get_meta("uid")) == second_uid:
				camp_second_discount_item = it
				break
	if camp_second_discount_item == null:
		var second_data = save_data.get("camp_second_discount_item", {})
		if typeof(second_data) == TYPE_DICTIONARY and not second_data.is_empty():
			var second_path: String = str(second_data.get("path", ""))
			for it in camp_shop_stock:
				if it == null: continue
				var it_path2: String = ""
				if it.resource_path != "": it_path2 = it.resource_path
				elif it.has_meta("original_path"): it_path2 = str(it.get_meta("original_path"))
				if it_path2 == second_path:
					camp_second_discount_item = it
					break

	player_roster.clear()
	var raw_roster: Array = save_data.get("player_roster", [])

	for unit in raw_roster:
		var loaded_inv: Array = []
		if unit.has("inventory"):
			for d in unit["inventory"]:
				var it: Resource = _deserialize_item(d)
				if it != null: loaded_inv.append(it)
		unit["inventory"] = loaded_inv

		unit["equipped_weapon"] = null
		var eq_data = unit.get("equipped_weapon", {})
		if typeof(eq_data) == TYPE_DICTIONARY and not eq_data.is_empty():
			var target_uid := str(eq_data.get("uid", ""))
			if target_uid != "":
				for inv_item in loaded_inv:
					if inv_item != null and inv_item.has_meta("uid") and str(inv_item.get_meta("uid")) == target_uid:
						unit["equipped_weapon"] = inv_item
						break

			if unit["equipped_weapon"] == null:
				var target_path := str(eq_data.get("path", ""))
				var target_dur := int(eq_data.get("current_durability", -1))
				for inv_item in loaded_inv:
					if inv_item == null: continue
					var inv_path := ""
					if inv_item.resource_path != "": inv_path = inv_item.resource_path
					elif inv_item.has_meta("original_path"): inv_path = str(inv_item.get_meta("original_path"))

					if inv_path == target_path:
						if inv_item is WeaponData and target_dur >= 0:
							if inv_item.current_durability == target_dur:
								unit["equipped_weapon"] = inv_item
								break
						else:
							unit["equipped_weapon"] = inv_item
							break

		if unit["equipped_weapon"] == null:
			for inv_item in loaded_inv:
				if inv_item is WeaponData:
					unit["equipped_weapon"] = inv_item
					break

		if unit.get("data") is String and ResourceLoader.exists(unit["data"]):
			unit["data"] = load(unit["data"])
		elif unit.get("data") == null:
			var data_hint: String = str(unit.get("data_path_hint", "")).strip_edges()
			if data_hint != "" and ResourceLoader.exists(data_hint):
				unit["data"] = load(data_hint)
		if unit.get("class_data") is String and ResourceLoader.exists(unit["class_data"]): unit["class_data"] = load(unit["class_data"])
		if unit.get("portrait") is String and ResourceLoader.exists(unit["portrait"]): unit["portrait"] = load(unit["portrait"])
		if unit.get("battle_sprite") is String and ResourceLoader.exists(unit["battle_sprite"]): unit["battle_sprite"] = load(unit["battle_sprite"])
		
		if not unit.has("unit_tags"): unit["unit_tags"] = []
		if not unit.has("skill_points"): unit["skill_points"] = 0
		if not unit.has("unlocked_skills"): unit["unlocked_skills"] = []
		if not unit.has("unlocked_abilities"): 
			var curr_ab = unit.get("ability", "")
			unit["unlocked_abilities"] = [curr_ab] if curr_ab != "" else []
		if not unit.has("traits"):
			unit["traits"] = []
		if not unit.has("rookie_legacies"):
			unit["rookie_legacies"] = []
		if not unit.has("base_class_legacies"):
			unit["base_class_legacies"] = []
		if not unit.has("promoted_class_legacies"):
			unit["promoted_class_legacies"] = []

		player_roster.append(unit)

	arena_mmr = int(save_data.get("arena_mmr", arena_mmr))
	gladiator_tokens = int(save_data.get("gladiator_tokens", gladiator_tokens))
	arena_win_streak = int(save_data.get("arena_win_streak", arena_win_streak))
	arena_best_win_streak = int(save_data.get("arena_best_win_streak", arena_best_win_streak))
	var raw_arena_id: Variant = save_data.get("arena_locked_team_identity", [])
	arena_locked_team_identity = raw_arena_id.duplicate(true) if raw_arena_id is Array else []
	_clamp_arena_persistence()

	claimed_rank_rewards.clear()
	var loaded_rewards = save_data.get("claimed_rank_rewards", [])
	for r in loaded_rewards: claimed_rank_rewards.append(r)

	active_save_slot = slot
	ArenaManager.restore_local_arena_team_from_saved_identity()
	return true

func has_seen_camp_lore(lore_id: String) -> bool:
	var key: String = str(lore_id).strip_edges()
	if key.is_empty():
		return true
	return bool(seen_camp_lore.get(key, false))

func mark_camp_lore_seen(lore_id: String) -> void:
	var key: String = str(lore_id).strip_edges()
	if key.is_empty():
		return
	seen_camp_lore[key] = true

func _is_camp_lore_flag_satisfied(flag_name: String) -> bool:
	var key: String = str(flag_name).strip_edges()
	if key.is_empty():
		return true
	match key:
		"shattered_sanctum_cleared":
			return bool(encounter_flags.get("shattered_sanctum_cleared", false))
		"greyspire_hub_established":
			return camp_request_progress_level >= 6
		"market_of_masks_cleared":
			return camp_request_progress_level >= 11
		"dawnkeep_siege_cleared":
			return camp_request_progress_level >= 14
		"echoes_of_the_order_cleared":
			return camp_request_progress_level >= 16
		"gathering_storms_cleared":
			return camp_request_progress_level >= 17
		"sunlit_trial_cleared":
			return bool(encounter_flags.get("sunlit_trial_cleared", false))
		_:
			return bool(encounter_flags.get(key, false))


## Story keys for CampConversationDB / ambient: encounter_flags plus narrative thresholds (same rules as _is_camp_lore_flag_satisfied).
func get_camp_conversation_story_flags() -> Dictionary:
	var out: Dictionary = {}
	for k in encounter_flags.keys():
		var ks: String = str(k).strip_edges()
		if ks != "" and bool(encounter_flags[k]):
			out[ks] = true
	for rk in battle_resonance_flags.keys():
		var rks: String = str(rk).strip_edges()
		if rks != "" and bool(battle_resonance_flags[rk]):
			out[rks] = true
	var script_keys: PackedStringArray = [
		"shattered_sanctum_cleared",
		"greyspire_hub_established",
		"market_of_masks_cleared",
		"dawnkeep_siege_cleared",
		"echoes_of_the_order_cleared",
		"gathering_storms_cleared",
		"sunlit_trial_cleared",
	]
	for sk in script_keys:
		if _is_camp_lore_flag_satisfied(sk):
			out[str(sk)] = true
	return out

func get_available_camp_lore(unit_name: String) -> Dictionary:
	var uname: String = str(unit_name).strip_edges()
	if uname.is_empty():
		return {}
	var entries: Array = CampLoreDB.get_lore_entries_for_unit(uname)
	if entries.is_empty():
		return {}

	var tier: String = get_avatar_relationship_tier(uname)
	var tier_rank: int = _tier_rank(tier)

	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var lore_id: String = str(entry.get("id", "")).strip_edges()
		if lore_id.is_empty():
			continue
		if has_seen_camp_lore(lore_id):
			continue

		var need_tier: String = str(entry.get("threshold", "stranger")).strip_edges().to_lower()
		if _tier_rank(need_tier) > tier_rank:
			continue

		var requires_flags: Array = entry.get("requires_flags", [])
		var forbidden_flags: Array = entry.get("forbidden_flags", [])

		var blocked: bool = false
		for f in requires_flags:
			var fk: String = str(f).strip_edges()
			if fk == "":
				continue
			if not _is_camp_lore_flag_satisfied(fk):
				blocked = true
				break
		if blocked:
			continue
		for f2 in forbidden_flags:
			var fk2: String = str(f2).strip_edges()
			if fk2 == "":
				continue
			if _is_camp_lore_flag_satisfied(fk2):
				blocked = true
				break
		if blocked:
			continue

		return entry

	return {}

func has_seen_pair_scene(scene_id: String) -> bool:
	var key: String = str(scene_id).strip_edges()
	if key.is_empty():
		return true
	return bool(seen_camp_pair_scenes.get(key, false))

func mark_pair_scene_seen(scene_id: String) -> void:
	var key: String = str(scene_id).strip_edges()
	if key.is_empty():
		return
	seen_camp_pair_scenes[key] = true

func ensure_camp_memory() -> void:
	if not (camp_memory is Dictionary):
		camp_memory = {}
	if not camp_memory.has("visit_index") or typeof(camp_memory.get("visit_index")) != TYPE_INT:
		camp_memory["visit_index"] = 0
	if not camp_memory.has("seen_scene_ids") or not (camp_memory.get("seen_scene_ids") is Dictionary):
		camp_memory["seen_scene_ids"] = {}
	if not camp_memory.has("pair_stats") or not (camp_memory.get("pair_stats") is Dictionary):
		camp_memory["pair_stats"] = {}

func increment_camp_visit() -> int:
	ensure_camp_memory()
	var idx: int = int(camp_memory.get("visit_index", 0)) + 1
	camp_memory["visit_index"] = idx
	return idx

func get_camp_visit_index() -> int:
	ensure_camp_memory()
	return int(camp_memory.get("visit_index", 0))

func make_pair_key(name_a: String, name_b: String) -> String:
	var a: String = str(name_a).strip_edges()
	var b: String = str(name_b).strip_edges()
	if a == "" or b == "":
		return ""
	if a <= b:
		return "%s|%s" % [a, b]
	return "%s|%s" % [b, a]

func get_pair_stats(name_a: String, name_b: String) -> Dictionary:
	ensure_camp_memory()
	var key: String = make_pair_key(name_a, name_b)
	if key == "":
		return { "familiarity": 0, "tension": 0, "last_visit_spoke": 0 }
	var pair_stats: Dictionary = camp_memory.get("pair_stats", {})
	var raw: Variant = pair_stats.get(key, {})
	if raw is Dictionary:
		var d: Dictionary = raw
		return {
			"familiarity": int(d.get("familiarity", 0)),
			"tension": int(d.get("tension", 0)),
			"last_visit_spoke": int(d.get("last_visit_spoke", 0)),
		}
	return { "familiarity": 0, "tension": 0, "last_visit_spoke": 0 }

func set_pair_stats(name_a: String, name_b: String, stats: Dictionary) -> void:
	ensure_camp_memory()
	var key: String = make_pair_key(name_a, name_b)
	if key == "":
		return
	var pair_stats: Dictionary = camp_memory.get("pair_stats", {})
	pair_stats[key] = {
		"familiarity": maxi(0, int(stats.get("familiarity", 0))),
		"tension": maxi(0, int(stats.get("tension", 0))),
		"last_visit_spoke": maxi(0, int(stats.get("last_visit_spoke", 0))),
	}
	camp_memory["pair_stats"] = pair_stats

func get_pair_familiarity(name_a: String, name_b: String) -> int:
	var stats: Dictionary = get_pair_stats(name_a, name_b)
	return int(stats.get("familiarity", 0))

func has_seen_camp_memory_scene(scene_id: String) -> bool:
	ensure_camp_memory()
	var sid: String = str(scene_id).strip_edges()
	if sid == "":
		return false
	var seen: Dictionary = camp_memory.get("seen_scene_ids", {})
	return bool(seen.get(sid, false))

func mark_camp_memory_scene_seen(scene_id: String) -> void:
	ensure_camp_memory()
	var sid: String = str(scene_id).strip_edges()
	if sid == "":
		return
	var seen: Dictionary = camp_memory.get("seen_scene_ids", {})
	seen[sid] = true
	camp_memory["seen_scene_ids"] = seen

func ensure_camp_unit_condition() -> void:
	if not (camp_unit_condition is Dictionary):
		camp_unit_condition = {}
	for key in camp_unit_condition.keys():
		var uname: String = str(key).strip_edges()
		if uname == "":
			continue
		var raw: Variant = camp_unit_condition.get(key, {})
		if raw is Dictionary:
			var d: Dictionary = raw
			camp_unit_condition[uname] = {
				"injured": bool(d.get("injured", false)),
				"fatigued": bool(d.get("fatigued", false)),
				"recovery_visits": maxi(0, int(d.get("recovery_visits", 0))),
			}

func get_unit_camp_condition(unit_name: String) -> Dictionary:
	ensure_camp_unit_condition()
	var key: String = str(unit_name).strip_edges()
	if key == "":
		return { "injured": false, "fatigued": false, "recovery_visits": 0 }
	var raw: Variant = camp_unit_condition.get(key, {})
	if raw is Dictionary:
		var d: Dictionary = raw
		return {
			"injured": bool(d.get("injured", false)),
			"fatigued": bool(d.get("fatigued", false)),
			"recovery_visits": maxi(0, int(d.get("recovery_visits", 0))),
		}
	return { "injured": false, "fatigued": false, "recovery_visits": 0 }

func set_unit_camp_condition(unit_name: String, data: Dictionary) -> void:
	ensure_camp_unit_condition()
	var key: String = str(unit_name).strip_edges()
	if key == "":
		return
	camp_unit_condition[key] = {
		"injured": bool(data.get("injured", false)),
		"fatigued": bool(data.get("fatigued", false)),
		"recovery_visits": maxi(0, int(data.get("recovery_visits", 0))),
	}

func is_unit_injured(unit_name: String) -> bool:
	var c: Dictionary = get_unit_camp_condition(unit_name)
	return bool(c.get("injured", false))

func is_unit_fatigued(unit_name: String) -> bool:
	var c: Dictionary = get_unit_camp_condition(unit_name)
	return bool(c.get("fatigued", false))

func apply_post_battle_camp_condition() -> void:
	ensure_camp_unit_condition()
	var progress_marker: int = int(camp_request_progress_level)
	if progress_marker == camp_condition_last_applied_progress_level:
		return
	camp_condition_last_applied_progress_level = progress_marker
	for ud in player_roster:
		if not (ud is Dictionary):
			continue
		var unit: Dictionary = ud
		var uname: String = str(unit.get("unit_name", "")).strip_edges()
		if uname == "":
			continue
		var max_hp_v: int = int(unit.get("max_hp", 0))
		var cur_hp_v: int = int(unit.get("current_hp", max_hp_v))
		if max_hp_v <= 0:
			continue
		var hp_ratio: float = clampf(float(cur_hp_v) / float(max_hp_v), 0.0, 1.0)
		var injured_now: bool = hp_ratio <= 0.45
		var fatigued_now: bool = hp_ratio <= 0.80
		if not injured_now and not fatigued_now:
			continue
		var c: Dictionary = get_unit_camp_condition(uname)
		var rec_visits: int = 2 if injured_now else 1
		c["injured"] = bool(c.get("injured", false)) or injured_now
		c["fatigued"] = bool(c.get("fatigued", false)) or fatigued_now
		c["recovery_visits"] = maxi(int(c.get("recovery_visits", 0)), rec_visits)
		set_unit_camp_condition(uname, c)

func _get_roster_hp_ratio(unit_name: String) -> float:
	var key: String = str(unit_name).strip_edges()
	if key == "":
		return -1.0
	for ud in player_roster:
		if not (ud is Dictionary):
			continue
		var unit: Dictionary = ud
		var uname: String = str(unit.get("unit_name", "")).strip_edges()
		if uname != key:
			continue
		var max_hp_v: int = int(unit.get("max_hp", 0))
		if max_hp_v <= 0:
			return -1.0
		var cur_hp_v: int = int(unit.get("current_hp", max_hp_v))
		return clampf(float(cur_hp_v) / float(max_hp_v), 0.0, 1.0)
	return -1.0

func advance_camp_condition_recovery_on_visit() -> void:
	ensure_camp_unit_condition()
	for key in camp_unit_condition.keys():
		var uname: String = str(key).strip_edges()
		if uname == "":
			continue
		var c: Dictionary = get_unit_camp_condition(uname)
		var rec: int = maxi(0, int(c.get("recovery_visits", 0)))
		if rec > 0:
			rec -= 1
		if rec <= 0:
			var hp_ratio: float = _get_roster_hp_ratio(uname)
			if hp_ratio >= 0.0:
				c["injured"] = hp_ratio <= 0.45
				c["fatigued"] = hp_ratio <= 0.80
			else:
				c["injured"] = false
				c["fatigued"] = false
			c["recovery_visits"] = 0
		else:
			c["recovery_visits"] = rec
		set_unit_camp_condition(uname, c)

func get_available_pair_scene_for_unit(unit_name: String) -> Dictionary:
	var uname: String = str(unit_name).strip_edges()
	if uname.is_empty():
		return {}

	var scenes: Array = CAMP_PAIR_SCENE_DB.get_scenes()
	if scenes.is_empty():
		return {}

	var roster_names: Array[String] = []
	for ud in player_roster:
		if ud is Dictionary:
			var n := str((ud as Dictionary).get("unit_name", "")).strip_edges()
			if n != "" and n not in roster_names:
				roster_names.append(n)

	for scene_variant in scenes:
		if not (scene_variant is Dictionary):
			continue
		var scene: Dictionary = scene_variant
		var sid: String = str(scene.get("id", "")).strip_edges()
		if sid.is_empty():
			continue
		if has_seen_pair_scene(sid) and bool(scene.get("one_time", true)):
			continue

		var a: String = str(scene.get("unit_a", "")).strip_edges()
		var b: String = str(scene.get("unit_b", "")).strip_edges()
		if a == "" or b == "":
			continue
		if uname != a and uname != b:
			continue

		if a not in roster_names or b not in roster_names:
			continue

		var tier_a: String = get_avatar_relationship_tier(a)
		var tier_b: String = get_avatar_relationship_tier(b)
		var need_a: String = str(scene.get("threshold_a", "stranger")).strip_edges().to_lower()
		var need_b: String = str(scene.get("threshold_b", "stranger")).strip_edges().to_lower()
		if _tier_rank(tier_a) < _tier_rank(need_a):
			continue
		if _tier_rank(tier_b) < _tier_rank(need_b):
			continue

		var requires_flags: Array = scene.get("requires_flags", [])
		var forbidden_flags: Array = scene.get("forbidden_flags", [])

		var blocked: bool = false
		for f in requires_flags:
			var fk: String = str(f).strip_edges()
			if fk == "":
				continue
			if not _is_camp_lore_flag_satisfied(fk):
				blocked = true
				break
		if blocked:
			continue
		for f2 in forbidden_flags:
			var fk2: String = str(f2).strip_edges()
			if fk2 == "":
				continue
			if _is_camp_lore_flag_satisfied(fk2):
				blocked = true
				break
		if blocked:
			continue

		return scene

	return {}

# ==========================================
# PARTY CAPTURE (MOST IMPORTANT SOURCE OF ORPHANS)
# ==========================================

func save_party(battlefield: Node2D) -> void:
	global_gold = battlefield.player_gold

	global_inventory.clear()
	for it in battlefield.player_inventory:
		var uniq := make_unique_item(it)
		if uniq != null:
			global_inventory.append(uniq)

	player_roster.clear()

	for unit in battlefield.player_container.get_children():
		if not unit.is_queued_for_deletion() and unit.current_hp > 0:
			if unit.get_meta("is_dragon", false):
				# --- COUNT FAVORITE SURVIVALS ---
				var d_uid = str(unit.get_meta("dragon_uid", ""))
				if d_uid != "" and d_uid == morgra_favorite_dragon_uid:
					morgra_favorite_survived_battles += 1
				# -------------------------------------
				continue

			var actual_sprite = null
			if unit.has_node("Sprite"):
				actual_sprite = unit.get_node("Sprite").texture
			elif unit.has_node("Sprite2D"):
				actual_sprite = unit.get_node("Sprite2D").texture

			var actual_portrait = null
			if unit.data:
				actual_portrait = unit.data.portrait

			# --- FIX 2: PRESERVE EQUIPPED WEAPON REFERENCE IN INVENTORY ---
			var inv_raw: Array = []
			var eq_weapon_src: Resource = null
			var eq_weapon: Resource = null

			if "equipped_weapon" in unit:
				eq_weapon_src = unit.equipped_weapon

			if "inventory" in unit and unit.inventory != null:
				for it in unit.inventory:
					var uniq := make_unique_item(it)
					if uniq != null:
						inv_raw.append(uniq)
						if it == eq_weapon_src:
							eq_weapon = uniq

			# Fallback if somehow the equipped weapon is not inside inventory
			if eq_weapon == null and eq_weapon_src != null:
				eq_weapon = make_unique_item(eq_weapon_src)

			var m_type = 0
			if "move_type" in unit: m_type = unit.move_type

			var u_ability = ""
			if "ability" in unit: u_ability = unit.ability

			var unit_dict = {
				"unit_name": unit.unit_name,
				"unit_class": unit.unit_class_name,
				"is_promoted": unit.get("is_promoted") if "is_promoted" in unit else false,
				"data": unit.data,
				"data_path_hint": (
					str(unit.data.resource_path).strip_edges()
					if unit.data != null and str(unit.data.resource_path).strip_edges() != ""
					else (
						str(unit.data.get_meta("original_path")).strip_edges()
						if unit.data != null and unit.data.has_meta("original_path")
						else ""
					)
				),
				"class_data": unit.active_class_data,
				"level": unit.level,
				"experience": unit.experience,
				"max_hp": unit.max_hp,
				"current_hp": unit.current_hp,
				"strength": unit.strength,
				"magic": unit.magic,
				"defense": unit.defense,
				"resistance": unit.resistance,
				"speed": unit.speed,
				"agility": unit.agility,
				"move_range": unit.move_range,
				"move_type": m_type,
				"equipped_weapon": eq_weapon,
				"inventory": inv_raw,
				"portrait": actual_portrait,
				"battle_sprite": actual_sprite,
				"ability": u_ability,
				"skill_points": int(unit.get("skill_points")) if unit.get("skill_points") != null else 0,
				"unlocked_skills": (unit.get("unlocked_skills") as Array).duplicate() if unit.get("unlocked_skills") is Array else [],
				"unlocked_abilities": (unit.get("unlocked_abilities") as Array).duplicate() if unit.get("unlocked_abilities") is Array else [],
				"unit_tags": (unit.get("unit_tags") as Array).duplicate() if unit.get("unit_tags") is Array else [],
				"traits": (unit.get("traits") as Array).duplicate() if unit.get("traits") is Array else [],
				"rookie_legacies": (unit.get("rookie_legacies") as Array).duplicate() if unit.get("rookie_legacies") is Array else [],
				"base_class_legacies": (unit.get("base_class_legacies") as Array).duplicate() if unit.get("base_class_legacies") is Array else [],
				"promoted_class_legacies": (unit.get("promoted_class_legacies") as Array).duplicate() if unit.get("promoted_class_legacies") is Array else []
			}

			if unit.get("active_ability_cooldowns") is Dictionary:
				var acd_wire: Array = ActiveCombatAbilityHelpers.export_wire(unit)
				if not acd_wire.is_empty():
					unit_dict["active_ability_cd"] = acd_wire

			player_roster.append(unit_dict)

	if active_save_slot != -1:
		save_game(active_save_slot, true)


# ==========================================
# LEVEL FLOW
# ==========================================

func load_next_level() -> void:
	# --- MORGRA EMOTIONAL STATE COUNTDOWN ---
	if morgra_anger_duration > 0:
		morgra_anger_duration -= 1
		if morgra_anger_duration == 0:
			# Anger is over, now she gives you the cold shoulder for 2 maps
			morgra_neutral_duration = 2 
	elif morgra_neutral_duration > 0:
		morgra_neutral_duration -= 1
		
	reset_camp_shop()
	reset_dragon_ranch_actions()
	has_triggered_map_encounter = false
	reset_npc_visit_flags()
	_process_base_economy()
	
	if active_save_slot != -1:
		save_game(active_save_slot, true)

	if is_expedition_run:
		var completed_id: String = str(active_expedition_map_id).strip_edges()
		if completed_id != "":
			mark_expedition_completed(completed_id)
		if active_save_slot != -1:
			save_game(active_save_slot, true)
		is_expedition_run = false
		active_expedition_map_id = ""
		active_expedition_modifier_id = ""
		SceneTransition.change_scene_to_file("res://Scenes/UI/WorldMap.tscn")
		return

	if is_skirmish_mode:
		is_expedition_run = false
		active_expedition_map_id = ""
		active_expedition_modifier_id = ""
		SceneTransition.change_scene_to_file("res://Scenes/UI/WorldMap.tscn")
		return

	var next_scene = "res://Scenes/camp_menu.tscn"

	if current_level_index < post_battle_transitions.size() and post_battle_transitions[current_level_index] != "":
		next_scene = post_battle_transitions[current_level_index]

	if current_level_index == max_unlocked_index:
		max_unlocked_index += 1
		# Camp request pacing: advance only when a story level is actually cleared.
		camp_request_progress_level += 1

	current_level_index = max_unlocked_index
	SceneTransition.change_scene_to_file(next_scene)
						
func enter_level_from_map(selected_level_idx: int) -> void:
	clear_pending_mock_coop_battle_handoff()
	reset_camp_shop()
	is_expedition_run = false
	active_expedition_map_id = ""
	active_expedition_modifier_id = ""
	current_level_index = selected_level_idx
	
	if selected_level_idx < max_unlocked_index:
		is_skirmish_mode = true
		if selected_level_idx < campaign_levels.size():
			SceneTransition.change_scene_to_file(campaign_levels[selected_level_idx])
	else:
		is_skirmish_mode = false
		if selected_level_idx < pre_battle_transitions.size() and pre_battle_transitions[selected_level_idx] != "":
			SceneTransition.change_scene_to_file(pre_battle_transitions[selected_level_idx])
		elif selected_level_idx < campaign_levels.size():
			SceneTransition.change_scene_to_file(campaign_levels[selected_level_idx])

## Loads the expedition's battle scene directly (no story pre-battle transition). Sets skirmish-style battle flags explicitly; does not use progression-based skirmish inference.
func launch_expedition_from_map(map_id: String) -> bool:
	var key: String = str(map_id).strip_edges()
	if key == "":
		return false
	if not has_expedition_map(key):
		return false
	var map_data: Dictionary = ExpeditionMapDatabase.get_map_by_id(key)
	if map_data.is_empty():
		return false
	if not ExpeditionMapDatabase.is_entry_repeatable(map_data) and has_completed_expedition(key):
		return false
	var battle_path: String = str(map_data.get("battle_scene_path", "")).strip_edges()
	if battle_path == "" or not ResourceLoader.exists(battle_path):
		return false
	var campaign_idx: int = campaign_levels.find(battle_path)
	if campaign_idx < 0:
		return false

	clear_pending_mock_coop_battle_handoff()
	reset_camp_shop()
	is_expedition_run = true
	active_expedition_map_id = key
	active_expedition_modifier_id = ExpeditionMapDatabase.get_expedition_modifier_id(map_data)
	is_skirmish_mode = true
	current_level_index = campaign_idx
	SceneTransition.change_scene_to_file(battle_path)
	return true

func clear_pending_mock_coop_battle_handoff() -> void:
	_pending_mock_coop_battle_handoff.clear()

func has_pending_mock_coop_battle_handoff() -> bool:
	return not _pending_mock_coop_battle_handoff.is_empty()

## Validates and stores a prepared handoff dict (from CoopExpeditionBattleHandoff.prepare_from_finalize_result handoff key).
func store_pending_mock_coop_battle_handoff(handoff: Dictionary) -> Dictionary:
	if typeof(handoff) != TYPE_DICTIONARY or handoff.is_empty():
		return {"ok": false, "errors": ["handoff_empty"]}
	var val_errs: PackedStringArray = CoopExpeditionBattleHandoff.validate_handoff(handoff)
	if not val_errs.is_empty():
		return {"ok": false, "errors": Array(val_errs)}
	_pending_mock_coop_battle_handoff = handoff.duplicate(true)
	return {"ok": true, "errors": []}

## Single consume at battle start; returns empty if none pending.
func consume_pending_mock_coop_battle_handoff() -> Dictionary:
	if _pending_mock_coop_battle_handoff.is_empty():
		return {}
	var copy: Dictionary = _pending_mock_coop_battle_handoff.duplicate(true)
	_pending_mock_coop_battle_handoff.clear()
	return copy

## Debug/mock: launch expedition battle using stored handoff (must pass expedition ownership + repeatability like normal launch).
func launch_expedition_with_pending_mock_coop_handoff() -> Dictionary:
	if _pending_mock_coop_battle_handoff.is_empty():
		return {"ok": false, "errors": ["no_pending_handoff"]}
	var h: Dictionary = _pending_mock_coop_battle_handoff.duplicate(true)
	var val_errs: PackedStringArray = CoopExpeditionBattleHandoff.validate_handoff(h)
	if not val_errs.is_empty():
		return {"ok": false, "errors": Array(val_errs)}
	var eid: String = str(h.get("expedition_map_id", "")).strip_edges()
	var bpath: String = str(h.get("battle_scene_path", "")).strip_edges()
	if eid == "" or bpath == "":
		return {"ok": false, "errors": ["handoff_missing_ids_or_path"]}
	if not has_expedition_map(eid):
		return {"ok": false, "errors": ["local_does_not_own_expedition_map"]}
	var map_data: Dictionary = ExpeditionMapDatabase.get_map_by_id(eid)
	if map_data.is_empty():
		return {"ok": false, "errors": ["expedition_not_in_database"]}
	if not ExpeditionMapDatabase.is_entry_repeatable(map_data) and has_completed_expedition(eid):
		return {"ok": false, "errors": ["non_repeatable_expedition_already_completed"]}
	if not ResourceLoader.exists(bpath):
		return {"ok": false, "errors": ["battle_scene_missing"]}
	var campaign_idx: int = campaign_levels.find(bpath)
	if campaign_idx < 0:
		return {"ok": false, "errors": ["battle_not_registered_in_campaign_levels"]}
	reset_camp_shop()
	is_expedition_run = true
	active_expedition_map_id = eid
	active_expedition_modifier_id = ExpeditionMapDatabase.get_expedition_modifier_id(map_data)
	is_skirmish_mode = true
	current_level_index = campaign_idx
	SceneTransition.change_scene_to_file(bpath)
	return {"ok": true, "errors": []}

func get_active_expedition_modifier_id() -> String:
	if not is_expedition_run:
		return ""
	return str(active_expedition_modifier_id).strip_edges()

## Full UI line for the active expedition (empty when not on an expedition run).
func get_active_expedition_modifier_display_line() -> String:
	if not is_expedition_run:
		return ""
	var entry: Dictionary = ExpeditionMapDatabase.get_map_by_id(active_expedition_map_id)
	return ExpeditionMapDatabase.build_expedition_modifier_ui_line(entry)

# --- FIX 3: SAFE PROGRESS SAVING ---
func save_current_progress(slot: int = -1) -> void:
	var target_slot: int = slot
	if target_slot == -1:
		target_slot = active_save_slot
		
	if target_slot == -1:
		return
		
	save_game(target_slot)

func _sanitize_owned_expedition_maps(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if raw == null or typeof(raw) != TYPE_ARRAY:
		return out

	for v in raw:
		var map_id: String = str(v).strip_edges()
		if map_id == "":
			continue
		if out.has(map_id):
			continue
		out.append(map_id)

	return out

func has_expedition_map(map_id: String) -> bool:
	var key: String = str(map_id).strip_edges()
	if key == "":
		return false
	return owned_expedition_maps.has(key)

func add_expedition_map(map_id: String) -> bool:
	var key: String = str(map_id).strip_edges()
	if key == "":
		return false
	if owned_expedition_maps.has(key):
		return false
	owned_expedition_maps.append(key)
	return true

func get_owned_expedition_maps() -> Array[String]:
	return owned_expedition_maps.duplicate()

func has_completed_expedition(map_id: String) -> bool:
	var key: String = str(map_id).strip_edges()
	if key == "":
		return false
	return completed_expedition_map_ids.has(key)

func mark_expedition_completed(map_id: String) -> void:
	var key: String = str(map_id).strip_edges()
	if key == "":
		return
	if completed_expedition_map_ids.has(key):
		return
	completed_expedition_map_ids.append(key)
	_roll_expedition_outcome_note_for_map(key)

func get_completed_expeditions() -> Array[String]:
	return completed_expedition_map_ids.duplicate()

func _sanitize_expedition_outcome_notes(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if raw == null or typeof(raw) != TYPE_DICTIONARY:
		return out
	for k in raw.keys():
		var ks: String = str(k).strip_edges()
		if ks == "":
			continue
		out[ks] = str(raw[k]).strip_edges()
	return out

func _roll_expedition_outcome_note_for_map(map_id: String) -> void:
	var key: String = str(map_id).strip_edges()
	if key == "":
		return
	if expedition_outcome_notes.has(key):
		return
	var entry: Dictionary = ExpeditionMapDatabase.get_map_by_id(key)
	var pool: PackedStringArray = ExpeditionMapDatabase.get_outcome_annotation_pool(entry)
	if pool.is_empty():
		return
	expedition_outcome_notes[key] = pool[randi_range(0, pool.size() - 1)]

func get_expedition_outcome_note(map_id: String) -> String:
	var key: String = str(map_id).strip_edges()
	if key == "" or not has_completed_expedition(key):
		return ""
	return str(expedition_outcome_notes.get(key, "")).strip_edges()

## Cartographer sale pool: progression-eligible maps minus owned one-time contracts (repeatable may still appear as "Already Owned").
func _filter_cartographer_sale_candidates(progression_eligible: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in progression_eligible:
		var mid: String = str(entry.get("id", "")).strip_edges()
		if mid == "":
			continue
		if has_expedition_map(mid) and not ExpeditionMapDatabase.is_entry_repeatable(entry):
			continue
		out.append(entry)
	return out

func _rebuild_expedition_cartographer_visible_map_ids(eligible: Array[Dictionary]) -> void:
	expedition_cartographer_visible_map_ids.clear()
	if eligible.is_empty():
		return
	var sorted_eligible: Array[Dictionary] = eligible.duplicate(true)
	sorted_eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", ""))
	)
	var max_vis: int = ExpeditionMapDatabase.get_cartographer_max_visible_offers()
	var n: int = sorted_eligible.size()
	var k: int = mini(max_vis, n)
	var start: int = (int(max_unlocked_index) % n + n) % n
	for i in range(k):
		var idx: int = (start + i) % n
		var mid: String = str(sorted_eligible[idx].get("id", "")).strip_edges()
		if mid != "":
			expedition_cartographer_visible_map_ids.append(mid)

func _sync_expedition_cartographer_visible_offers() -> void:
	var raw_eligible: Array[Dictionary] = ExpeditionMapDatabase.get_cartographer_eligible_maps(max_unlocked_index)
	var eligible: Array[Dictionary] = _filter_cartographer_sale_candidates(raw_eligible)
	var eligible_ids: Dictionary = {}
	for e in eligible:
		var mid: String = str(e.get("id", "")).strip_edges()
		if mid != "":
			eligible_ids[mid] = true
	var need_rebuild: bool = false
	if expedition_cartographer_offer_stamp != max_unlocked_index:
		need_rebuild = true
	elif expedition_cartographer_visible_map_ids.is_empty() and not eligible.is_empty():
		need_rebuild = true
	else:
		for vid in expedition_cartographer_visible_map_ids:
			var ks: String = str(vid).strip_edges()
			if ks == "" or not eligible_ids.has(ks):
				need_rebuild = true
				break
	if not need_rebuild:
		return
	_rebuild_expedition_cartographer_visible_map_ids(eligible)
	expedition_cartographer_offer_stamp = max_unlocked_index
	if active_save_slot != -1:
		save_game(active_save_slot, true)

## Cartographer-facing stock: progression-eligible maps, then a stable rotating subset keyed to max_unlocked_index.
func get_expedition_cartographer_shop_entries() -> Array[Dictionary]:
	_sync_expedition_cartographer_visible_offers()
	var out: Array[Dictionary] = []
	for map_id in expedition_cartographer_visible_map_ids:
		var d: Dictionary = ExpeditionMapDatabase.get_map_by_id(map_id)
		if not d.is_empty():
			out.append(d)
	return out

func get_coop_eligible_expedition_map_ids() -> Array[String]:
	var eligible: Array[String] = []
	for map_id in owned_expedition_maps:
		var map_data: Dictionary = ExpeditionMapDatabase.get_map_by_id(map_id)
		if map_data.is_empty():
			continue
		if not bool(map_data.get("coop_enabled", false)):
			continue
		eligible.append(map_id)
	return eligible

func can_use_expedition_for_coop(map_id: String) -> bool:
	if not has_expedition_map(map_id):
		return false
	var map_data: Dictionary = ExpeditionMapDatabase.get_map_by_id(map_id)
	if map_data.is_empty():
		return false
	return bool(map_data.get("coop_enabled", false))

func both_players_have_same_map(map_id: String, remote_owned_maps: Array[String]) -> bool:
	if not can_use_expedition_for_coop(map_id):
		return false
	for remote_map_id in remote_owned_maps:
		if str(remote_map_id).strip_edges() == str(map_id).strip_edges():
			return true
	return false

## Co-op foundation: same chart on both sides (remote list from session/transport payload).
func can_start_coop_expedition_with_remote(map_id: String, remote_owned_map_ids: Array) -> bool:
	var cleaned: Array[String] = []
	for x in remote_owned_map_ids:
		var s: String = str(x).strip_edges()
		if s != "":
			cleaned.append(s)
	return both_players_have_same_map(str(map_id).strip_edges(), cleaned)

func grant_debug_expedition_map(map_id: String) -> bool:
	var added: bool = add_expedition_map(map_id)
	if added:
		save_current_progress()
	return added

func grant_first_debug_expedition_map() -> String:
	var maps: Array[Dictionary] = ExpeditionMapDatabase.get_all_maps()
	for map_data in maps:
		var map_id: String = str(map_data.get("id", "")).strip_edges()
		if map_id == "":
			continue
		if grant_debug_expedition_map(map_id):
			return map_id
	return ""

## Returns how much of this scavenger score this player has already claimed (persisted). Used so refresh does not resurface claimed quantity.
func get_claimed_scavenger_quantity(score_id: String) -> int:
	if score_id == null or str(score_id).strip_edges().is_empty():
		return 0
	return int(claimed_scavenger_scores.get(str(score_id).strip_edges(), 0))

## Records a claim so fetch can subtract it; call before or with save to prevent re-claim after reload.
func record_scavenger_claim(score_id: String, quantity: int) -> void:
	if score_id == null or str(score_id).strip_edges().is_empty() or quantity <= 0:
		return
	var key: String = str(score_id).strip_edges()
	var prev: int = int(claimed_scavenger_scores.get(key, 0))
	claimed_scavenger_scores[key] = prev + quantity

## True if a save can be written (prevents scavenger transactions from applying without persistence).
func can_persist_scavenger() -> bool:
	return active_save_slot >= 0

# ==========================================
# SUPPORTS
# ==========================================

# Safe pair key: delimiter must not appear in unit names. Legacy saves use "_"; we migrate on read.
const REL_PAIR_KEY_SEP: String = "\u001F"

func get_support_key(name_a: String, name_b: String) -> String:
	var names = [name_a, name_b]
	names.sort()
	return names[0] + REL_PAIR_KEY_SEP + names[1]

## Parses a relationship/support key into [id_a, id_b]. Handles legacy "_" keys for backward compatibility.
func parse_relationship_key(key: String) -> PackedStringArray:
	if key.contains(REL_PAIR_KEY_SEP):
		return key.split(REL_PAIR_KEY_SEP)
	return key.split("_")

func _legacy_pair_key(name_a: String, name_b: String) -> String:
	var names = [name_a, name_b]
	names.sort()
	return names[0] + "_" + names[1]

func _migrate_support_bond_key_if_needed(name_a: String, name_b: String) -> void:
	var key: String = get_support_key(name_a, name_b)
	if support_bonds.has(key):
		return
	var legacy: String = _legacy_pair_key(name_a, name_b)
	if support_bonds.has(legacy):
		support_bonds[key] = support_bonds[legacy]
		support_bonds.erase(legacy)

## Returns support bond dict for the pair; migrates legacy key on read. Use this instead of support_bonds.get(key) when you have names.
func get_support_bond(name_a: String, name_b: String) -> Dictionary:
	_migrate_support_bond_key_if_needed(name_a, name_b)
	var key: String = get_support_key(name_a, name_b)
	return support_bonds.get(key, {"points": 0, "rank": 0})

func add_support_points(name_a: String, name_b: String, amount: int = 1) -> void:
	_migrate_support_bond_key_if_needed(name_a, name_b)
	var key = get_support_key(name_a, name_b)
	if not support_bonds.has(key):
		support_bonds[key] = {"points": 0, "rank": 0}

	if support_bonds[key]["rank"] >= 3:
		return

	support_bonds[key]["points"] += amount

func reset_dragon_ranch_actions() -> void:
	for d in DragonManager.player_dragons:
		if d is Dictionary:
			d["ranch_action_used_this_level"] = false

func penalize_support_points(name_a: String, name_b: String, amount: int = 2) -> void:
	_migrate_support_bond_key_if_needed(name_a, name_b)
	var key = get_support_key(name_a, name_b)
	if support_bonds.has(key):
		# Don't let it drop below 0
		support_bonds[key]["points"] = max(0, support_bonds[key]["points"] - amount)

# --- Relationship Web V1: pair stats (trust, rivalry, mentorship, fear). Grief is battle-local only, not persisted. ---
const RELATIONSHIP_DEFAULTS: Dictionary = {"trust": 0, "rivalry": 0, "mentorship": 0, "fear": 0}

func get_relationship(name_a: String, name_b: String) -> Dictionary:
	var key: String = get_support_key(name_a, name_b)
	var raw = relationship_web.get(key)
	if raw == null or not (raw is Dictionary):
		var legacy_key: String = _legacy_pair_key(name_a, name_b)
		raw = relationship_web.get(legacy_key)
		if raw != null and raw is Dictionary:
			relationship_web[key] = raw.duplicate()
			relationship_web.erase(legacy_key)
	if raw == null or not (raw is Dictionary):
		return RELATIONSHIP_DEFAULTS.duplicate()
	var out: Dictionary = RELATIONSHIP_DEFAULTS.duplicate()
	for k in out.keys():
		if raw.has(k):
			out[k] = clampi(int(raw[k]), 0, 100)
	return out

func set_relationship_value(name_a: String, name_b: String, stat: String, value: int) -> void:
	if stat == "grief":
		return
	var key: String = get_support_key(name_a, name_b)
	if not relationship_web.has(key):
		relationship_web[key] = RELATIONSHIP_DEFAULTS.duplicate()
	if RELATIONSHIP_DEFAULTS.has(stat):
		relationship_web[key][stat] = clampi(value, 0, 100)

func add_relationship_value(name_a: String, name_b: String, stat: String, delta: int) -> void:
	if stat == "grief":
		return
	var rel: Dictionary = get_relationship(name_a, name_b)
	set_relationship_value(name_a, name_b, stat, rel.get(stat, 0) + delta)

# --- Avatar-to-unit relationship (lightweight; reusable for real quests, support scenes, camp trust gates) ---
const AVATAR_RELATIONSHIP_SCORE_MIN: int = 0
const AVATAR_RELATIONSHIP_SCORE_MAX: int = 100
const AVATAR_RELATIONSHIP_TIER_STRANGER: int = 0
const AVATAR_RELATIONSHIP_TIER_KNOWN: int = 10
const AVATAR_RELATIONSHIP_TIER_TRUSTED: int = 25
const AVATAR_RELATIONSHIP_TIER_CLOSE: int = 50
const AVATAR_RELATIONSHIP_TIER_BONDED: int = 80

func _avatar_relationship_default_entry() -> Dictionary:
	return {
		"score": 0,
		"requests_completed": 0,
		"branching_successes": 0,
		"branching_failures": 0,
		"last_change": 0,
		"last_reason": "",
		"personal_arc_stage": 0,
		"arc_flags": {},
	}

## Returns full relationship entry for unit; creates with defaults if missing. Safe for missing units.
func get_avatar_relationship(unit_name: String) -> Dictionary:
	var key: String = str(unit_name).strip_edges()
	if key.is_empty():
		return _avatar_relationship_default_entry().duplicate()
	if not avatar_relationship_by_unit.has(key):
		avatar_relationship_by_unit[key] = _avatar_relationship_default_entry().duplicate()
	var entry: Variant = avatar_relationship_by_unit[key]
	if entry is Dictionary:
		return (entry as Dictionary).duplicate()
	return _avatar_relationship_default_entry().duplicate()

## Returns current score (0–100) for Avatar–unit relationship. Safe for missing units.
func get_avatar_relationship_score(unit_name: String) -> int:
	var entry: Dictionary = get_avatar_relationship(unit_name)
	return clampi(int(entry.get("score", 0)), AVATAR_RELATIONSHIP_SCORE_MIN, AVATAR_RELATIONSHIP_SCORE_MAX)

## Returns tier string from score: stranger / known / trusted / close / bonded. Derived, not stored.
func get_avatar_relationship_tier(unit_name: String) -> String:
	var score: int = get_avatar_relationship_score(unit_name)
	if score >= AVATAR_RELATIONSHIP_TIER_BONDED:
		return "bonded"
	if score >= AVATAR_RELATIONSHIP_TIER_CLOSE:
		return "close"
	if score >= AVATAR_RELATIONSHIP_TIER_TRUSTED:
		return "trusted"
	if score >= AVATAR_RELATIONSHIP_TIER_KNOWN:
		return "known"
	return "stranger"

func _ensure_avatar_progression_fields(entry: Dictionary) -> void:
	if not entry.has("personal_arc_stage") or typeof(entry.get("personal_arc_stage")) != TYPE_INT:
		entry["personal_arc_stage"] = 0
	else:
		entry["personal_arc_stage"] = maxi(0, int(entry.get("personal_arc_stage", 0)))
	var af: Variant = entry.get("arc_flags", {})
	if not (af is Dictionary):
		entry["arc_flags"] = {}
	else:
		entry["arc_flags"] = af as Dictionary


## Lightweight camp-direct arc progression (stored on avatar_relationship entry; saved with relationships).
func get_personal_arc_stage(unit_name: String) -> int:
	var key: String = str(unit_name).strip_edges()
	if key.is_empty():
		return 0
	if not avatar_relationship_by_unit.has(key):
		return 0
	var entry: Variant = avatar_relationship_by_unit[key]
	if entry is Dictionary:
		return maxi(0, int((entry as Dictionary).get("personal_arc_stage", 0)))
	return 0


func has_arc_flag(unit_name: String, flag: String) -> bool:
	var f: String = str(flag).strip_edges()
	if f.is_empty():
		return false
	var key: String = str(unit_name).strip_edges()
	if key.is_empty() or not avatar_relationship_by_unit.has(key):
		return false
	var entry: Variant = avatar_relationship_by_unit[key]
	if not (entry is Dictionary):
		return false
	var af: Variant = (entry as Dictionary).get("arc_flags", {})
	if not (af is Dictionary):
		return false
	return bool((af as Dictionary).get(f, false))


## Applies optional keys from authored direct conversation effects: set_personal_arc_stage, advance_personal_arc_stage,
## set_arc_flag (String), clear_arc_flag (String), set_arc_flags (Dictionary). Ignores unknown keys and add_avatar_relationship.
func apply_camp_direct_progression_effects(unit_name: String, fx: Dictionary) -> void:
	var key: String = str(unit_name).strip_edges()
	if key.is_empty() or fx.is_empty():
		return
	if not avatar_relationship_by_unit.has(key):
		avatar_relationship_by_unit[key] = _avatar_relationship_default_entry().duplicate()
	var entry: Dictionary = avatar_relationship_by_unit[key]
	_ensure_avatar_progression_fields(entry)
	if fx.has("set_personal_arc_stage"):
		entry["personal_arc_stage"] = maxi(0, int(fx.get("set_personal_arc_stage", 0)))
	if fx.has("advance_personal_arc_stage"):
		entry["personal_arc_stage"] = maxi(0, int(entry.get("personal_arc_stage", 0)) + int(fx.get("advance_personal_arc_stage", 0)))
	if fx.has("set_arc_flag"):
		var sf: String = str(fx.get("set_arc_flag", "")).strip_edges()
		if sf != "":
			entry["arc_flags"][sf] = true
	if fx.has("clear_arc_flag"):
		var cf: String = str(fx.get("clear_arc_flag", "")).strip_edges()
		if cf != "" and entry["arc_flags"] is Dictionary:
			(entry["arc_flags"] as Dictionary).erase(cf)
	var sfs: Variant = fx.get("set_arc_flags", {})
	if sfs is Dictionary:
		for fk in sfs as Dictionary:
			if bool((sfs as Dictionary)[fk]):
				entry["arc_flags"][str(fk)] = true


const BATTLE_RESONANCE_FLAG_KEYS: Array[String] = [
	"showed_mercy_under_pressure",
	"protected_civilians_first",
	"delegated_under_pressure",
	"chose_harsh_efficiency",
]


## Story battles only: set a cumulative resonance flag (idempotent). Ignored if key is not in BATTLE_RESONANCE_FLAG_KEYS.
func mark_battle_resonance(flag: String) -> void:
	var f: String = str(flag).strip_edges()
	if f.is_empty():
		return
	for allowed in BATTLE_RESONANCE_FLAG_KEYS:
		if str(allowed) == f:
			battle_resonance_flags[f] = true
			return


## Story battles only (BattleField skips arena + skirmish). Updates encounter_flags for camp story gating
## (get_camp_conversation_story_flags) and mirrors the same keys on the commander avatar entry via
## apply_camp_direct_progression_effects so arc_flag-based hooks can target the custom unit name if desired.
## Keys are mutually exclusive per outcome; "costly" is only set on VICTORY with player or ally losses.
func record_story_battle_outcome_for_camp(result: String, player_deaths: int, ally_deaths: int) -> void:
	encounter_flags.erase("battle_last_engagement_victory")
	encounter_flags.erase("battle_last_engagement_defeat")
	encounter_flags.erase("battle_last_engagement_costly")
	var cmd: String = str(custom_avatar.get("unit_name", "Commander")).strip_edges()
	if cmd.is_empty():
		cmd = "Commander"
	apply_camp_direct_progression_effects(cmd, {"clear_arc_flag": "battle_last_engagement_victory"})
	apply_camp_direct_progression_effects(cmd, {"clear_arc_flag": "battle_last_engagement_defeat"})
	apply_camp_direct_progression_effects(cmd, {"clear_arc_flag": "battle_last_engagement_costly"})
	if str(result).strip_edges().to_upper() == "VICTORY":
		encounter_flags["battle_last_engagement_victory"] = true
		var costly: bool = player_deaths > 0 or ally_deaths > 0
		if costly:
			encounter_flags["battle_last_engagement_costly"] = true
		var af: Dictionary = {"battle_last_engagement_victory": true}
		if costly:
			af["battle_last_engagement_costly"] = true
		apply_camp_direct_progression_effects(cmd, {"set_arc_flags": af})
	else:
		encounter_flags["battle_last_engagement_defeat"] = true
		apply_camp_direct_progression_effects(cmd, {"set_arc_flags": {"battle_last_engagement_defeat": true}})


## Ambient / DB hooks: speaker must meet min_personal_arc_stage and required_arc_flags; must not have forbidden_arc_flags.
func ambient_entry_matches_speaker_progression(speaker_name: String, entry: Dictionary) -> bool:
	if entry.is_empty():
		return true
	var sp: String = str(speaker_name).strip_edges()
	if sp.is_empty():
		return false
	if entry.has("min_personal_arc_stage"):
		if get_personal_arc_stage(sp) < int(entry.get("min_personal_arc_stage", 0)):
			return false
	if entry.has("max_personal_arc_stage"):
		if get_personal_arc_stage(sp) > int(entry.get("max_personal_arc_stage", 999)):
			return false
	var req_v: Variant = entry.get("required_arc_flags", [])
	if req_v is Array:
		for flg in req_v as Array:
			var fn: String = str(flg).strip_edges()
			if fn != "" and not has_arc_flag(sp, fn):
				return false
	var forb_v: Variant = entry.get("forbidden_arc_flags", [])
	if forb_v is Array:
		for flg2 in forb_v as Array:
			var fn2: String = str(flg2).strip_edges()
			if fn2 != "" and has_arc_flag(sp, fn2):
				return false
	return true


## Applies score delta and updates last_change/last_reason. Clamps score to 0–100. Creates entry if missing.
func add_avatar_relationship(unit_name: String, amount: int, reason: String = "") -> void:
	var key: String = str(unit_name).strip_edges()
	if key.is_empty():
		return
	if not avatar_relationship_by_unit.has(key):
		avatar_relationship_by_unit[key] = _avatar_relationship_default_entry().duplicate()
	var entry: Dictionary = avatar_relationship_by_unit[key]
	_ensure_avatar_progression_fields(entry)
	var old_score: int = int(entry.get("score", 0))
	var new_score: int = clampi(old_score + amount, AVATAR_RELATIONSHIP_SCORE_MIN, AVATAR_RELATIONSHIP_SCORE_MAX)
	entry["score"] = new_score
	entry["last_change"] = new_score - old_score
	entry["last_reason"] = str(reason).strip_edges()

## Call when player completes a camp request (turn-in). Increments requests_completed; if branching, branching_successes.
## request_depth: "normal" (+2 or +3), "deep" (+4), "personal" (+5). Used for progression layer.
func record_avatar_request_completed(unit_name: String, is_branching: bool, request_depth: String = "normal") -> void:
	var key: String = str(unit_name).strip_edges()
	if key.is_empty():
		return
	if not avatar_relationship_by_unit.has(key):
		avatar_relationship_by_unit[key] = _avatar_relationship_default_entry().duplicate()
	var entry: Dictionary = avatar_relationship_by_unit[key]
	entry["requests_completed"] = int(entry.get("requests_completed", 0)) + 1
	if is_branching:
		entry["branching_successes"] = int(entry.get("branching_successes", 0)) + 1
	var delta: int = 2
	if request_depth == "personal":
		delta = 5
	elif request_depth == "deep":
		delta = 4
	elif is_branching:
		delta = 3
	add_avatar_relationship(unit_name, delta, "request_completed")

## Call when player fails a branching camp check. Increments branching_failures and applies -1.
func record_avatar_branching_failure(unit_name: String) -> void:
	var key: String = str(unit_name).strip_edges()
	if key.is_empty():
		return
	if not avatar_relationship_by_unit.has(key):
		avatar_relationship_by_unit[key] = _avatar_relationship_default_entry().duplicate()
	var entry: Dictionary = avatar_relationship_by_unit[key]
	entry["branching_failures"] = int(entry.get("branching_failures", 0)) + 1
	add_avatar_relationship(unit_name, -1, "branching_failed")

## Returns a lightweight, display-ready summary of the current camp request.
## Keys:
##   has_active (bool), status (String), title (String), giver (String),
##   request_depth (String: normal/deep/personal), type (String),
##   objective (String), progress (String), reward (String),
##   relationship_tier (String), no_active_message (String), no_active_hint (String)
func get_camp_request_display_data() -> Dictionary:
	var status: String = str(camp_request_status).strip_edges().to_lower()
	var valid_status: bool = status == "active" or status == "ready_to_turn_in" or status == "failed"
	if not valid_status:
		return {
			"has_active": false,
			"status": "",
			"title": "",
			"giver": "",
			"request_depth": "",
			"type": "",
			"objective": "",
			"progress": "",
			"reward": "",
			"relationship_tier": "",
			"no_active_message": "No active camp request.",
			"no_active_hint": "Explore camp and speak to your allies. Higher bonds unlock deeper requests.",
		}
	var giver: String = str(camp_request_giver_name).strip_edges()
	var req_type: String = str(camp_request_type).strip_edges()
	var depth: String = "normal"
	if camp_request_payload is Dictionary:
		depth = str(camp_request_payload.get("request_depth", "normal")).strip_edges().to_lower()
	var objective: String = ""
	var progress_text: String = ""
	var target_name: String = str(camp_request_target_name).strip_edges()
	var target_amount: int = int(camp_request_target_amount)
	if status == "active":
		if req_type == "item_delivery":
			if target_name != "" and giver != "":
				objective = "Bring %d× %s to %s." % [maxi(1, target_amount), target_name, giver]
			elif giver != "":
				objective = "Gather the requested supplies for %s." % giver
			else:
				objective = "Gather the requested supplies."
			var have: int = camp_request_progress
			if have > 0 and target_amount > 0:
				progress_text = "Progress: %d / %d" % [have, target_amount]
		elif req_type == "talk_to_unit":
			if target_name != "" and giver != "":
				objective = "Talk to %s, then return to %s." % [target_name, giver]
			elif target_name != "":
				objective = "Talk to %s." % target_name
			elif giver != "":
				objective = "Speak with the requested target, then return to %s." % giver
			else:
				objective = "Speak with the requested ally in camp."
			progress_text = "Objective: Find %s and speak with them." % target_name if target_name != "" else "Objective: Speak with the requested ally."
	elif status == "ready_to_turn_in":
		if req_type == "item_delivery":
			if giver != "":
				objective = "Return to %s to complete the request." % giver
			else:
				objective = "Return to camp to complete the request."
			if target_name != "" and target_amount > 0:
				progress_text = "You have what you need: %d× %s." % [target_amount, target_name]
			else:
				progress_text = "Requirements met. Ready to turn in."
		elif req_type == "talk_to_unit":
			if target_name != "" and giver != "":
				objective = "You spoke with %s. Return to %s to complete the request." % [target_name, giver]
			elif target_name != "":
				objective = "You spoke with %s. Return to camp to complete the request." % target_name
			elif giver != "":
				objective = "Return to %s to complete the request." % giver
			else:
				objective = "Return to camp to complete the request."
			progress_text = "Conversation complete. Turn the request in."
		else:
			objective = "Return to %s to complete the request." % giver if giver != "" else "Return to camp to complete the request."
			progress_text = "Ready to turn in."
	elif status == "failed":
		if req_type == "talk_to_unit":
			if target_name != "" and giver != "":
				objective = "You failed to get through to %s. Return to %s." % [target_name, giver]
			elif target_name != "":
				objective = "You failed to get through to %s. Return to camp." % target_name
			elif giver != "":
				objective = "You were not able to complete this request. Return to %s." % giver
			else:
				objective = "You were not able to complete this request."
		elif giver != "":
			objective = "You were not able to complete this request. Return to %s." % giver
		else:
			objective = "You were not able to complete this request."
		progress_text = "Outcome: failed. No reward will be granted."
	var reward_bits: Array[String] = []
	if camp_request_reward_gold > 0:
		reward_bits.append("%d gold" % int(camp_request_reward_gold))
	if camp_request_reward_affinity > 0 and giver != "":
		reward_bits.append("Favor with %s (+%d)" % [giver, int(camp_request_reward_affinity)])
	var reward_text: String = ""
	if reward_bits.size() == 1:
		reward_text = "Reward: %s." % reward_bits[0]
	elif reward_bits.size() > 1:
		reward_text = "Reward: %s and %s." % [reward_bits[0], reward_bits[1]]
	var tier: String = get_avatar_relationship_tier(giver) if giver != "" else ""
	return {
		"has_active": true,
		"status": status,
		"title": str(camp_request_title),
		"giver": giver,
		"request_depth": depth,
		"type": req_type,
		"objective": objective,
		"progress": progress_text,
		"reward": reward_text,
		"relationship_tier": tier,
		"no_active_message": "",
		"no_active_hint": "",
	}

# --- Personal quest state (relationship-gated; one-at-a-time with camp requests) ---
const _TIER_ORDER: Array = ["stranger", "known", "trusted", "close", "bonded"]

func _tier_rank(tier: String) -> int:
	var t: String = str(tier).strip_edges().to_lower()
	for i in range(_TIER_ORDER.size()):
		if _TIER_ORDER[i] == t:
			return i
	return 0

func _personal_quest_default_state() -> Dictionary:
	return {"unlocked": false, "active": false, "completed": false, "last_offered_at_score": 0, "seen_unlock_scene": false}

## Returns personal quest state for unit; creates default entry if missing. Safe for missing units.
func get_personal_quest_state(unit_name: String) -> Dictionary:
	var key: String = str(unit_name).strip_edges()
	if key.is_empty():
		return _personal_quest_default_state().duplicate()
	if not personal_quest_state_by_unit.has(key):
		personal_quest_state_by_unit[key] = _personal_quest_default_state().duplicate()
	var entry: Variant = personal_quest_state_by_unit[key]
	if entry is Dictionary:
		return (entry as Dictionary).duplicate()
	return _personal_quest_default_state().duplicate()

## Sets active flag so one-at-a-time rule holds (active = no other camp request from this unit).
func set_personal_quest_active(unit_name: String, active: bool) -> void:
	var key: String = str(unit_name).strip_edges()
	if key.is_empty():
		return
	if not personal_quest_state_by_unit.has(key):
		personal_quest_state_by_unit[key] = _personal_quest_default_state().duplicate()
	personal_quest_state_by_unit[key]["active"] = active

## Marks personal quest completed for unit; clears active.
func mark_personal_quest_completed(unit_name: String) -> void:
	var key: String = str(unit_name).strip_edges()
	if key.is_empty():
		return
	if not personal_quest_state_by_unit.has(key):
		personal_quest_state_by_unit[key] = _personal_quest_default_state().duplicate()
	personal_quest_state_by_unit[key]["completed"] = true
	personal_quest_state_by_unit[key]["active"] = false

## Marks personal quest unlocked (when tier first qualifies). Optional.
func mark_personal_quest_unlocked(unit_name: String) -> void:
	var key: String = str(unit_name).strip_edges()
	if key.is_empty():
		return
	if not personal_quest_state_by_unit.has(key):
		personal_quest_state_by_unit[key] = _personal_quest_default_state().duplicate()
	personal_quest_state_by_unit[key]["unlocked"] = true

## True if unit has a personal quest profile, tier meets unlock_tier, and not completed/active.
func is_personal_quest_eligible(unit_name: String) -> bool:
	var profile: Dictionary = CampRequestContentDB.get_personal_quest_profile(unit_name)
	if profile.is_empty():
		return false
	var state: Dictionary = get_personal_quest_state(unit_name)
	if state.get("completed", false) or state.get("active", false):
		return false
	var tier: String = get_avatar_relationship_tier(unit_name)
	var need: String = str(profile.get("unlock_tier", "close")).strip_edges().to_lower()
	return _tier_rank(tier) >= _tier_rank(need)

## Returns a compact list of "Available Leads" in camp (personal quests, special scenes, deep-bond hints).
## Each entry: { unit_name, lead_type (personal_quest|special_scene|deep_hint), text, priority }
## Does not mutate any state; uses existing relationship / quest / scene data.
func get_available_task_leads(max_leads: int = 5) -> Array[Dictionary]:
	var leads_by_unit: Dictionary = {}
	if max_leads <= 0:
		return []

	var active_status: String = str(camp_request_status).strip_edges().to_lower()
	var active_giver: String = str(camp_request_giver_name).strip_edges()
	var has_active_request: bool = active_status == "active" or active_status == "ready_to_turn_in" or active_status == "failed"

	# Precompute roster and item candidates for request_offer leads (read-only).
	var roster_names: Array[String] = []
	for ud in player_roster:
		if ud is Dictionary:
			var n := str((ud as Dictionary).get("unit_name", "")).strip_edges()
			if n != "" and n not in roster_names:
				roster_names.append(n)

	var item_names: Array[String] = []
	if ItemDatabase:
		for item in ItemDatabase.master_item_pool:
			if item == null:
				continue
			# Only use materials/consumables for camp requests (matches camp behavior).
			if not (item is MaterialData or item is ConsumableData):
				continue
			var wn: Variant = item.get("weapon_name")
			var iname: Variant = item.get("item_name")
			var disp: String = ""
			if wn != null and str(wn).strip_edges() != "":
				disp = str(wn).strip_edges()
			elif iname != null and str(iname).strip_edges() != "":
				disp = str(iname).strip_edges()
			if disp != "" and disp not in item_names:
				item_names.append(disp)

	# Build a combined set of unit names we know about.
	var unit_names: Array[String] = []
	for rel_name in avatar_relationship_by_unit.keys():
		var s: String = str(rel_name).strip_edges()
		if s != "" and s not in unit_names:
			unit_names.append(s)
	for pq_name in personal_quest_state_by_unit.keys():
		var s2: String = str(pq_name).strip_edges()
		if s2 != "" and s2 not in unit_names:
			unit_names.append(s2)
	# Include current roster unit names if available.
	for unit_data in player_roster:
		if unit_data is Dictionary:
			var uname: String = str((unit_data as Dictionary).get("unit_name", "")).strip_edges()
			if uname != "" and uname not in unit_names:
				unit_names.append(uname)
	# Include units that have personal quest profiles defined in content.
	for profile_name in CampRequestContentDB.PERSONAL_QUEST_PROFILES.keys():
		var s3: String = str(profile_name).strip_edges()
		if s3 != "" and s3 not in unit_names:
			unit_names.append(s3)
	# Include units that have special camp scenes defined in content.
	for scene_name in CampRequestContentDB.SPECIAL_CAMP_SCENES.keys():
		var s4: String = str(scene_name).strip_edges()
		if s4 != "" and s4 not in unit_names:
			unit_names.append(s4)

	for unit_name in unit_names:
		var uname: String = str(unit_name).strip_edges()
		if uname == "":
			continue

		# Skip the current active request giver for lead hints, to avoid confusion.
		if has_active_request and uname == active_giver:
			continue

		var best_lead: Dictionary = {}
		var best_priority: int = -1

		# 1) Personal quest available.
		if is_personal_quest_eligible(uname):
			var text_pq: String = "Personal quest available: %s." % uname
			best_lead = {
				"unit_name": uname,
				"lead_type": "personal_quest",
				"text": text_pq,
				"priority": 100,
			}
			best_priority = 100

		# 2) Special camp scene available (only if we didn't already pick a higher-priority personal quest).
		if best_priority < 100:
			var tier: String = get_avatar_relationship_tier(uname)
			for scene_tier in ["close", "trusted"]:
				var scene_tier_str: String = str(scene_tier)
				var scene := CampRequestContentDB.get_special_camp_scene(uname, scene_tier_str)
				if scene.is_empty() or scene.get("lines", []).is_empty():
					continue
				var tier_ok: bool = (scene_tier_str == "close" and tier in ["close", "bonded"]) or (scene_tier_str == "trusted" and tier in ["trusted", "close", "bonded"])
				if not tier_ok:
					continue
				if scene.get("one_time", true) and has_seen_special_scene(uname, scene_tier_str):
					continue
				var text_scene: String = "Special camp scene available with %s." % uname
				if best_priority < 80:
					best_lead = {
						"unit_name": uname,
						"lead_type": "special_scene",
						"text": text_scene,
						"priority": 80,
					}
					best_priority = 80
				break

		# 3) High-bond deeper-content hint (only if we have no stronger lead yet).
		if best_priority < 80:
			var tier2: String = get_avatar_relationship_tier(uname)
			if tier2 in ["close", "bonded"]:
				var text_hint: String = "%s may have something more personal to ask." % uname
				best_lead = {
					"unit_name": uname,
					"lead_type": "deep_hint",
					"text": text_hint,
					"priority": 50,
				}
				best_priority = 50

		# 4) Normal camp request offer (read-only; only when no active request and no stronger lead).
		if best_priority < 50 and not has_active_request and not roster_names.is_empty():
			var preview: Dictionary = get_best_available_camp_offer_preview()
			if bool(preview.get("has_offer", false)):
				var giver: String = str(preview.get("giver_name", "")).strip_edges()
				if giver == uname:
					var texts: Array[String] = [
						"%s may have something for you." % uname,
						"%s seems to want a word." % uname,
						"%s may need your help." % uname,
					]
					var idx: int = abs(uname.hash()) % texts.size()
					best_lead = {
						"unit_name": uname,
						"lead_type": "request_offer",
						"text": texts[idx],
						"priority": 30,
					}
					best_priority = 30

		if best_priority > 0:
			leads_by_unit[uname] = best_lead

	var out: Array[Dictionary] = []
	for uname in leads_by_unit.keys():
		out.append(leads_by_unit[uname])

	out.sort_custom(func(a, b) -> bool:
		return int(a.get("priority", 0)) > int(b.get("priority", 0))
	)
	if out.size() > max_leads:
		out = out.slice(0, max_leads)
	return out

## Mirrors CampExplore.gd's "one offer giver when no active request" selection logic in a read-only helper.
## Returns: { has_offer: bool, giver_name: String, offer: Dictionary, score: int }.
func get_best_available_camp_offer_preview() -> Dictionary:
	var status: String = str(camp_request_status).strip_edges().to_lower()
	if status == "active" or status == "ready_to_turn_in" or status == "failed":
		return {"has_offer": false}
	if player_roster.is_empty():
		return {"has_offer": false}

	var roster_names: Array[String] = []
	for ud in player_roster:
		if ud is Dictionary:
			var n := str((ud as Dictionary).get("unit_name", "")).strip_edges()
			if n != "" and n not in roster_names:
				roster_names.append(n)

	var item_names: Array[String] = []
	if ItemDatabase:
		for item in ItemDatabase.master_item_pool:
			if item == null:
				continue
			if not (item is MaterialData or item is ConsumableData):
				continue
			var wn: Variant = item.get("weapon_name")
			var iname: Variant = item.get("item_name")
			var disp: String = ""
			if wn != null and str(wn).strip_edges() != "":
				disp = str(wn).strip_edges()
			elif iname != null and str(iname).strip_edges() != "":
				disp = str(iname).strip_edges()
			if disp != "" and disp not in item_names:
				item_names.append(disp)

	var best_name: String = ""
	var best_offer: Dictionary = {}
	var best_score: int = -99999
	var progress_level: int = camp_request_progress_level
	var next_eligible: Dictionary = camp_request_unit_next_eligible_level
	var recent: Array = camp_request_recent_givers
	var completed_by: Dictionary = camp_requests_completed_by_unit

	for ud in player_roster:
		if not (ud is Dictionary):
			continue
		var d: Dictionary = ud
		var name_str: String = str(d.get("unit_name", "")).strip_edges()
		if name_str == "":
			continue
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

		var giver_tier: String = get_avatar_relationship_tier(name_str)
		var personal_eligible: bool = is_personal_quest_eligible(name_str)
		var unit_data_variant: Variant = d.get("data", null)
		var personality: String = CampRequestDB.get_personality(unit_data_variant, name_str)
		var offer: Dictionary = CampRequestDB.get_offer(
			name_str,
			personality,
			roster_names,
			item_names,
			false,
			giver_tier,
			personal_eligible
		)
		if offer.is_empty():
			continue
		if score > best_score:
			best_score = score
			best_name = name_str
			best_offer = offer

	if best_name == "" or best_offer.is_empty():
		return {"has_offer": false}

	return {
		"has_offer": true,
		"giver_name": best_name,
		"offer": best_offer,
		"score": best_score,
	}

## Mark one-time special camp scene as seen for unit+tier.
func mark_special_scene_seen(unit_name: String, tier: String) -> void:
	var key: String = "%s|%s" % [str(unit_name).strip_edges(), str(tier).strip_edges().to_lower()]
	if key.is_empty() or key == "|":
		return
	special_camp_scenes_seen[key] = true

## True if one-time special scene for unit+tier was already shown.
func has_seen_special_scene(unit_name: String, tier: String) -> bool:
	var key: String = "%s|%s" % [str(unit_name).strip_edges(), str(tier).strip_edges().to_lower()]
	return special_camp_scenes_seen.get(key, false)

func get_mentorship(name_a: String, name_b: String) -> int:
	return int(get_relationship(name_a, name_b).get("mentorship", 0))

func get_rivalry(name_a: String, name_b: String) -> int:
	return int(get_relationship(name_a, name_b).get("rivalry", 0))

# --- Relationship Web UI helpers (display names, colors, effect hints, entries for Unit Details / tooltips) ---
const REL_UI_MENTORSHIP_FORMED_THRESHOLD: int = 25
const REL_UI_RIVALRY_FORMED_THRESHOLD: int = 20
const REL_UI_STATS: Array[String] = ["trust", "mentorship", "rivalry"]

func get_relationship_entries_for_unit(unit_id: String) -> Array:
	var out: Array = []
	if unit_id.is_empty():
		return out
	for key in relationship_web.keys():
		var parts: PackedStringArray = parse_relationship_key(key)
		if parts.size() < 2:
			continue
		var a: String = parts[0]
		var b: String = parts[1]
		if a != unit_id and b != unit_id:
			continue
		var partner_id: String = b if a == unit_id else a
		var rel: Dictionary = get_relationship(a, b)
		out.append({
			"partner_id": partner_id,
			"trust": int(rel.get("trust", 0)),
			"rivalry": int(rel.get("rivalry", 0)),
			"mentorship": int(rel.get("mentorship", 0)),
			"fear": int(rel.get("fear", 0))
		})
	return out

func get_top_relationship_entries_for_unit(unit_id: String, candidate_ids: Array, max_entries: int) -> Array:
	var entries: Array = get_relationship_entries_for_unit(unit_id)
	var flat: Array = []
	for e in entries:
		var partner_id: String = e.get("partner_id", "")
		if not candidate_ids.is_empty() and partner_id not in candidate_ids:
			continue
		for stat in REL_UI_STATS:
			var val: int = int(e.get(stat, 0))
			if val <= 0:
				continue
			var formed: bool = false
			if stat == "mentorship":
				formed = val >= REL_UI_MENTORSHIP_FORMED_THRESHOLD
			elif stat == "rivalry":
				formed = val >= REL_UI_RIVALRY_FORMED_THRESHOLD
			flat.append({"partner_id": partner_id, "stat": stat, "value": val, "formed": formed})
	flat.sort_custom(func(a, b) -> bool:
		var af: bool = a.get("formed", false)
		var bf: bool = b.get("formed", false)
		if af != bf:
			return af
		return int(a.get("value", 0)) > int(b.get("value", 0))
	)
	return flat.slice(0, max_entries)

func get_relationship_type_display_name(stat: String) -> String:
	var s: String = str(stat).to_lower()
	if s == "trust": return "Trust"
	if s == "mentorship": return "Mentorship"
	if s == "rivalry": return "Rivalry"
	if s == "fear": return "Fear"
	return stat

func get_relationship_type_color(stat: String) -> Color:
	var s: String = str(stat).to_lower()
	if s == "trust": return Color(0.35, 0.82, 0.88)
	if s == "mentorship": return Color(0.95, 0.75, 0.2)
	if s == "rivalry": return Color(0.92, 0.35, 0.2)
	if s == "fear": return Color(0.6, 0.4, 0.6)
	return Color.GRAY

func get_relationship_effect_hint(stat: String, _value: int) -> String:
	var s: String = str(stat).to_lower()
	if s == "trust": return "better guard / assist synergy nearby"
	if s == "mentorship": return "guidance bonus nearby"
	if s == "rivalry": return "sharper crits, lower coordination with them"
	if s == "fear": return "penalty when near"
	return ""

func format_relationship_tooltip(entry: Dictionary) -> String:
	var partner_id: String = entry.get("partner_id", "?")
	var stat: String = entry.get("stat", "")
	var value: int = int(entry.get("value", 0))
	var type_name: String = get_relationship_type_display_name(stat)
	var hint: String = get_relationship_effect_hint(stat, value)
	return type_name + ": " + partner_id + " (+" + hint + ")"

## One bond for deploy roster / pre-battle UI (readable without color legend).
func format_relationship_roster_line(entry: Dictionary) -> String:
	var partner_id: String = str(entry.get("partner_id", "?"))
	var stat: String = str(entry.get("stat", ""))
	var type_name: String = get_relationship_type_display_name(stat)
	return type_name + ": " + partner_id

## Join top bonds for a second line under the unit name in ItemList.
func format_relationship_roster_summary(entries: Array, max_parts: int = 3) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var n: int = 0
	for e in entries:
		if n >= max_parts:
			break
		if e is Dictionary:
			parts.append(format_relationship_roster_line(e as Dictionary))
		n += 1
	return " · ".join(parts)

## Compact tag for a small HUD strip (initial + short partner id).
func format_relationship_strip_tag(entry: Dictionary) -> String:
	var partner_id: String = str(entry.get("partner_id", "?"))
	var stat: String = str(entry.get("stat", "")).to_lower()
	var letter: String = "?"
	match stat:
		"trust":
			letter = "T"
		"mentorship":
			letter = "M"
		"rivalry":
			letter = "R"
		"fear":
			letter = "F"
		_:
			letter = str(get_relationship_type_display_name(stat)).substr(0, 1)
	var short_partner: String = partner_id
	if short_partner.length() > 9:
		short_partner = short_partner.substr(0, 8) + "…"
	return letter + "·" + short_partner

func format_relationship_row_bbcode(entry: Dictionary) -> String:
	var partner_id: String = entry.get("partner_id", "?")
	var stat: String = entry.get("stat", "")
	var value: int = int(entry.get("value", 0))
	var formed: bool = entry.get("formed", false)
	var type_name: String = get_relationship_type_display_name(stat)
	var hint: String = get_relationship_effect_hint(stat, value)
	var col: Color = get_relationship_type_color(stat)
	var hex: String = "#" + col.to_html(false)
	var label: String = (type_name + " Formed") if formed else (type_name + " " + str(value))
	return "[color=" + hex + "]" + partner_id + " — " + label + "[/color] — " + hint

# --- WORLD MAP ENCOUNTERS (session-only; not persisted) ---
var has_triggered_map_encounter: bool = false


# ==========================================
# SERAPHINA / NPC RELATIONSHIP HELPERS
# ==========================================

func _build_default_seraphina_state() -> Dictionary:
	return {
		"affection": 0,
		"trust": 0,
		"professionalism": 0,
		"flags": {
			"met_seraphina": false,
			"met_this_visit": false,
			"asked_about_scar": false,
			"drank_the_special": false,
			"discussed_special_aftertaste": false,
			"after_hours_talk": false
		},
		"seen_nodes": {},
		"counters": {
			"times_spoken": 0
		}
	}

func _normalize_seraphina_state(state: Dictionary) -> Dictionary:
	var defaults: Dictionary = _build_default_seraphina_state()

	if not state.has("affection"):
		state["affection"] = defaults["affection"]
	if not state.has("trust"):
		state["trust"] = defaults["trust"]
	if not state.has("professionalism"):
		state["professionalism"] = defaults["professionalism"]

	if not state.has("flags") or typeof(state["flags"]) != TYPE_DICTIONARY:
		state["flags"] = {}
	if not state.has("seen_nodes") or typeof(state["seen_nodes"]) != TYPE_DICTIONARY:
		state["seen_nodes"] = {}
	if not state.has("counters") or typeof(state["counters"]) != TYPE_DICTIONARY:
		state["counters"] = {}

	var flags: Dictionary = state["flags"]
	var seen_nodes: Dictionary = state["seen_nodes"]
	var counters: Dictionary = state["counters"]

	for key in defaults["flags"].keys():
		if not flags.has(key):
			flags[key] = defaults["flags"][key]

	for key in defaults["counters"].keys():
		if not counters.has(key):
			counters[key] = defaults["counters"][key]

	state["flags"] = flags
	state["seen_nodes"] = seen_nodes
	state["counters"] = counters
	return state

func ensure_seraphina_state() -> void:
	if not npc_relationships.has("seraphina"):
		npc_relationships["seraphina"] = _build_default_seraphina_state()
	else:
		npc_relationships["seraphina"] = _normalize_seraphina_state(npc_relationships["seraphina"])

func get_seraphina_state() -> Dictionary:
	ensure_seraphina_state()
	return npc_relationships["seraphina"]

func sync_seraphina_legacy_cache() -> void:
	_sync_seraphina_legacy_from_relationship_state()

func _sync_seraphina_legacy_from_relationship_state() -> void:
	ensure_seraphina_state()
	var state: Dictionary = npc_relationships["seraphina"]
	var flags: Dictionary = state.get("flags", {})

	var affection: int = int(state.get("affection", 0))
	var trust: int = int(state.get("trust", 0))
	var professionalism: int = int(state.get("professionalism", 0))

	var derived_disposition: int = clampi(
		int(round((float(affection) * 0.40) + (float(trust) * 0.30) + (float(professionalism) * 0.30))),
		0,
		100
	)

	var derived_rank: int = 0
	if affection >= 50 and trust >= 55 and professionalism >= 30:
		derived_rank = 3
	elif affection >= 25 and trust >= 35 and professionalism >= 25:
		derived_rank = 2
	elif trust >= 15 and professionalism >= 20:
		derived_rank = 1

	_suppress_seraphina_legacy_sync = true
	_legacy_seraphina_disposition = derived_disposition
	_legacy_seraphina_romance_rank = derived_rank
	_legacy_seraphina_met_today = bool(flags.get("met_this_visit", false))
	_suppress_seraphina_legacy_sync = false

func _apply_legacy_seraphina_to_relationship_state() -> void:
	ensure_seraphina_state()
	var state: Dictionary = npc_relationships["seraphina"]
	var flags: Dictionary = state.get("flags", {})

	state["affection"] = clampi(int(round(float(_legacy_seraphina_disposition) * 0.45)), 0, 100)
	state["trust"] = clampi(int(round(float(_legacy_seraphina_disposition) * 0.35)), 0, 100)
	state["professionalism"] = clampi(int(round(float(_legacy_seraphina_disposition) * 0.55)), 0, 100)

	match _legacy_seraphina_romance_rank:
		1:
			state["trust"] = max(int(state["trust"]), 15)
			state["professionalism"] = max(int(state["professionalism"]), 20)
		2:
			state["affection"] = max(int(state["affection"]), 25)
			state["trust"] = max(int(state["trust"]), 35)
			state["professionalism"] = max(int(state["professionalism"]), 25)
		3:
			state["affection"] = max(int(state["affection"]), 50)
			state["trust"] = max(int(state["trust"]), 55)
			state["professionalism"] = max(int(state["professionalism"]), 30)

	if _legacy_seraphina_disposition > 0 or _legacy_seraphina_romance_rank > 0:
		flags["met_seraphina"] = true

	flags["met_this_visit"] = _legacy_seraphina_met_today
	state["flags"] = flags
	npc_relationships["seraphina"] = _normalize_seraphina_state(state)

func _migrate_legacy_seraphina_state(save_data: Dictionary) -> void:
	if npc_relationships.has("seraphina"):
		npc_relationships["seraphina"] = _normalize_seraphina_state(npc_relationships["seraphina"])
		return

	var state: Dictionary = _build_default_seraphina_state()

	var legacy_disposition: int = int(save_data.get("seraphina_disposition", 0))
	var legacy_rank: int = int(save_data.get("seraphina_romance_rank", 0))
	var legacy_met_today: bool = bool(save_data.get("seraphina_met_today", false))

	state["affection"] = clampi(int(round(float(legacy_disposition) * 0.45)), 0, 100)
	state["trust"] = clampi(int(round(float(legacy_disposition) * 0.35)), 0, 100)
	state["professionalism"] = clampi(int(round(float(legacy_disposition) * 0.55)), 0, 100)

	match legacy_rank:
		1:
			state["trust"] = max(int(state["trust"]), 15)
			state["professionalism"] = max(int(state["professionalism"]), 20)
		2:
			state["affection"] = max(int(state["affection"]), 25)
			state["trust"] = max(int(state["trust"]), 35)
			state["professionalism"] = max(int(state["professionalism"]), 25)
		3:
			state["affection"] = max(int(state["affection"]), 50)
			state["trust"] = max(int(state["trust"]), 55)
			state["professionalism"] = max(int(state["professionalism"]), 30)

	if legacy_disposition > 0 or legacy_rank > 0:
		state["flags"]["met_seraphina"] = true

	state["flags"]["met_this_visit"] = legacy_met_today
	npc_relationships["seraphina"] = _normalize_seraphina_state(state)
	_sync_seraphina_legacy_from_relationship_state()

func reset_npc_visit_flags() -> void:
	ensure_seraphina_state()
	var seraphina: Dictionary = npc_relationships["seraphina"]
	var flags: Dictionary = seraphina.get("flags", {})
	flags["met_this_visit"] = false
	seraphina["flags"] = flags
	npc_relationships["seraphina"] = _normalize_seraphina_state(seraphina)
	_sync_seraphina_legacy_from_relationship_state()

# ==========================================
# BASE MANAGEMENT API
# ==========================================

# Purpose: Registers a new base location and assigns units to defend it.
# Inputs: level_index (int) representing the map, selected_unit_names (Array of Strings).
# Outputs: None.
# Side Effects: Clears old base data, updates roster garrison flags.
func establish_new_base(level_index: int, selected_unit_names: Array) -> void:
	active_base_level_index = level_index
	base_resource_storage = {"wood": 0, "iron": 0, "gold": 0}
	base_under_attack = false
	is_base_defense_active = false
	
	# Clear existing garrison flags to enforce the 1-base limit
	for unit in player_roster:
		unit["is_garrisoned"] = false
		
	# Apply the flag to the newly selected units
	for unit in player_roster:
		if unit.get("unit_name", "") in selected_unit_names:
			unit["is_garrisoned"] = true

# Purpose: Wipes the base state and returns garrisoned units to the active pool.
func abandon_base() -> void:
	active_base_level_index = -1
	base_under_attack = false
	is_base_defense_active = false
	for unit in player_roster:
		unit["is_garrisoned"] = false

# Purpose: Retrieves only the units currently defending the base.
# Returns: Array of unit dictionaries.
func get_garrisoned_units() -> Array[Dictionary]:
	var garrison: Array[Dictionary] = []
	for unit in player_roster:
		if unit.get("is_garrisoned", false):
			garrison.append(unit)
	return garrison

# Purpose: Retrieves the units available for standard campaign deployment.
# Returns: Array of unit dictionaries.
func get_available_roster() -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for unit in player_roster:
		if not unit.get("is_garrisoned", false):
			available.append(unit)
	return available


func _mock_coop_command_unit_id_from_roster_entry(unit: Dictionary) -> String:
	var un: String = str(unit.get("unit_name", unit.get("name", ""))).strip_edges()
	var av_name: String = str(custom_avatar.get("name", "")).strip_edges()
	var av_unit: String = str(custom_avatar.get("unit_name", "")).strip_edges()
	if un != "" and ((av_name != "" and un == av_name) or (av_unit != "" and un == av_unit)):
		return "Avatar"
	return un


func _is_mock_coop_avatar_roster_entry(unit: Dictionary) -> bool:
	return _mock_coop_command_unit_id_from_roster_entry(unit) == "Avatar"


func _find_mock_coop_available_roster_entry(command_unit_id: String) -> Dictionary:
	var target: String = str(command_unit_id).strip_edges()
	if target == "":
		return {}
	for unit in get_available_roster():
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		var unit_dict: Dictionary = unit as Dictionary
		if _mock_coop_command_unit_id_from_roster_entry(unit_dict) == target:
			return unit_dict.duplicate(true)
	return {}


func _build_mock_coop_avatar_roster_entry() -> Dictionary:
	var avatar_entry: Dictionary = _find_mock_coop_available_roster_entry("Avatar")
	if not avatar_entry.is_empty():
		return avatar_entry
	return custom_avatar.duplicate(true)


func get_mock_coop_companion_candidate_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for unit in get_available_roster():
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		var unit_dict: Dictionary = unit as Dictionary
		if _is_mock_coop_avatar_roster_entry(unit_dict):
			continue
		var unit_id: String = _mock_coop_command_unit_id_from_roster_entry(unit_dict)
		if unit_id == "":
			continue
		var display_name: String = str(unit_dict.get("unit_name", unit_dict.get("name", unit_id))).strip_edges()
		if display_name == "":
			display_name = unit_id
		out.append({
			"unit_id": unit_id,
			"display_name": display_name,
		})
	return out


func get_default_mock_coop_companion_unit_id() -> String:
	var entries: Array[Dictionary] = get_mock_coop_companion_candidate_entries()
	if entries.is_empty():
		return ""
	return str(entries[0].get("unit_id", "")).strip_edges()


func _mock_coop_party_command_id(role_key: String, raw_unit_id: String) -> String:
	var role: String = str(role_key).strip_edges().to_lower()
	if role == "":
		role = "host"
	var raw: String = str(raw_unit_id).strip_edges()
	return "%s::%s" % [role, raw]


func build_mock_coop_player_party_payload(selected_companion_unit_id: String, role_key: String) -> Dictionary:
	var payload: Dictionary = {}
	var avatar_entry: Dictionary = _build_mock_coop_avatar_roster_entry()
	if not avatar_entry.is_empty():
		var avatar_snapshot: Dictionary = _serialize_mock_coop_battle_roster_unit(avatar_entry)
		var avatar_display_name: String = get_player_display_name("Commander")
		avatar_snapshot["is_custom_avatar"] = false
		avatar_snapshot["mock_coop_command_id"] = _mock_coop_party_command_id(role_key, "Avatar")
		avatar_snapshot["mock_coop_raw_unit_id"] = "Avatar"
		payload["avatar_command_id"] = str(avatar_snapshot.get("mock_coop_command_id", ""))
		payload["avatar_display_name"] = avatar_display_name
		payload["avatar_snapshot"] = avatar_snapshot

	var companion_id: String = str(selected_companion_unit_id).strip_edges()
	if companion_id == "":
		companion_id = get_default_mock_coop_companion_unit_id()
	var companion_entry: Dictionary = _find_mock_coop_available_roster_entry(companion_id)
	if companion_entry.is_empty() and companion_id != "":
		companion_id = get_default_mock_coop_companion_unit_id()
		companion_entry = _find_mock_coop_available_roster_entry(companion_id)
	if not companion_entry.is_empty() and not _is_mock_coop_avatar_roster_entry(companion_entry):
		var companion_snapshot: Dictionary = _serialize_mock_coop_battle_roster_unit(companion_entry)
		var companion_display_name: String = str(companion_entry.get("unit_name", companion_entry.get("name", companion_id))).strip_edges()
		if companion_display_name == "":
			companion_display_name = companion_id
		companion_snapshot["is_custom_avatar"] = false
		companion_snapshot["mock_coop_command_id"] = _mock_coop_party_command_id(role_key, companion_id)
		companion_snapshot["mock_coop_raw_unit_id"] = companion_id
		payload["selected_companion_unit_id"] = companion_id
		payload["selected_companion_display_name"] = companion_display_name
		payload["selected_companion_command_id"] = str(companion_snapshot.get("mock_coop_command_id", ""))
		payload["selected_companion_snapshot"] = companion_snapshot

	return payload


func _serialize_mock_coop_battle_roster_unit(unit: Dictionary) -> Dictionary:
	var u_copy: Dictionary = unit.duplicate(true)
	var unit_name: String = str(unit.get("unit_name", unit.get("name", ""))).strip_edges()
	var avatar_name: String = str(custom_avatar.get("name", "")).strip_edges()
	var avatar_unit_name: String = str(custom_avatar.get("unit_name", "")).strip_edges()
	u_copy["is_custom_avatar"] = (
			(unit_name != "" and avatar_name != "" and unit_name == avatar_name)
			or (unit_name != "" and avatar_unit_name != "" and unit_name == avatar_unit_name)
	)

	u_copy["equipped_weapon"] = {}
	var eq: Resource = unit.get("equipped_weapon")
	if eq != null:
		u_copy["equipped_weapon"] = _serialize_item(eq)

	var unit_inv_saved: Array = []
	if unit.has("inventory"):
		for it in unit["inventory"]:
			var s: Dictionary = _serialize_item(it)
			if not s.is_empty():
				unit_inv_saved.append(s)
	u_copy["inventory"] = unit_inv_saved

	if u_copy.get("data") is Resource:
		var data_res: Resource = u_copy["data"]
		var data_path: String = str(data_res.resource_path).strip_edges()
		if data_path == "" and data_res.has_meta("original_path"):
			data_path = str(data_res.get_meta("original_path")).strip_edges()
		if data_path == "":
			data_path = str(u_copy.get("data_path_hint", "")).strip_edges()
		u_copy["data"] = data_path if data_path != "" else ""
	if u_copy.get("class_data") is Resource:
		u_copy["class_data"] = u_copy["class_data"].resource_path
	if u_copy.get("portrait") is Texture2D:
		u_copy["portrait"] = u_copy["portrait"].resource_path
	if u_copy.get("battle_sprite") is Texture2D:
		u_copy["battle_sprite"] = u_copy["battle_sprite"].resource_path
	u_copy["unit_tags"] = unit.get("unit_tags", [])
	u_copy["traits"] = unit.get("traits", []).duplicate() if unit.get("traits") is Array else []
	u_copy["rookie_legacies"] = unit.get("rookie_legacies", []).duplicate() if unit.get("rookie_legacies") is Array else []
	u_copy["base_class_legacies"] = unit.get("base_class_legacies", []).duplicate() if unit.get("base_class_legacies") is Array else []
	u_copy["promoted_class_legacies"] = unit.get("promoted_class_legacies", []).duplicate() if unit.get("promoted_class_legacies") is Array else []
	if unit.get("active_ability_cd") is Array:
		u_copy["active_ability_cd"] = (unit["active_ability_cd"] as Array).duplicate(true)
	return u_copy


## Host-auth snapshot for mock co-op battle entry. Intentionally capped to the live deployment limit so the ENet handoff stays compact.
func build_mock_coop_battle_roster_snapshot(max_units: int = 6) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cap: int = maxi(0, int(max_units))
	if cap <= 0:
		return out

	for unit in get_available_roster():
		if out.size() >= cap:
			break
		if typeof(unit) != TYPE_DICTIONARY:
			continue
		out.append(_serialize_mock_coop_battle_roster_unit(unit as Dictionary))

	if out.size() >= cap:
		return out

	for dragon in DragonManager.player_dragons:
		if out.size() >= cap:
			break
		if typeof(dragon) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = (dragon as Dictionary).duplicate(true)
		if int(d.get("stage", 0)) < 3:
			continue
		d["is_dragon"] = true
		out.append(d)

	return out


func hydrate_mock_coop_battle_roster_snapshot(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(raw) != TYPE_ARRAY:
		return out

	for entry_raw in raw as Array:
		if typeof(entry_raw) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = (entry_raw as Dictionary).duplicate(true)

		if bool(unit.get("is_dragon", false)) or str(unit.get("element", "")).strip_edges() != "":
			out.append(unit)
			continue

		var eq_data: Variant = unit.get("equipped_weapon", {})
		var loaded_inv: Array = []
		if unit.has("inventory"):
			for d in unit["inventory"]:
				var it: Resource = _deserialize_item(d)
				if it != null:
					loaded_inv.append(it)
		unit["inventory"] = loaded_inv

		unit["equipped_weapon"] = null
		if typeof(eq_data) == TYPE_DICTIONARY and not (eq_data as Dictionary).is_empty():
			var eq_dict: Dictionary = eq_data as Dictionary
			var target_uid: String = str(eq_dict.get("uid", ""))
			if target_uid != "":
				for inv_item in loaded_inv:
					if inv_item != null and inv_item.has_meta("uid") and str(inv_item.get_meta("uid")) == target_uid:
						unit["equipped_weapon"] = inv_item
						break

			if unit["equipped_weapon"] == null:
				var target_path: String = str(eq_dict.get("path", ""))
				var target_dur: int = int(eq_dict.get("current_durability", -1))
				for inv_item in loaded_inv:
					if inv_item == null:
						continue
					var inv_path: String = ""
					if inv_item.resource_path != "":
						inv_path = inv_item.resource_path
					elif inv_item.has_meta("original_path"):
						inv_path = str(inv_item.get_meta("original_path"))
					if inv_path != target_path:
						continue
					if inv_item is WeaponData and target_dur >= 0:
						if inv_item.current_durability == target_dur:
							unit["equipped_weapon"] = inv_item
							break
					else:
						unit["equipped_weapon"] = inv_item
						break

		if unit["equipped_weapon"] == null:
			for inv_item in loaded_inv:
				if inv_item is WeaponData:
					unit["equipped_weapon"] = inv_item
					break

		if unit.get("data") is String and ResourceLoader.exists(unit["data"]):
			unit["data"] = load(unit["data"])
		elif unit.get("data") == null:
			var data_hint: String = str(unit.get("data_path_hint", "")).strip_edges()
			if data_hint != "" and ResourceLoader.exists(data_hint):
				unit["data"] = load(data_hint)
		if unit.get("class_data") is String and ResourceLoader.exists(unit["class_data"]):
			unit["class_data"] = load(unit["class_data"])
		if unit.get("portrait") is String and ResourceLoader.exists(unit["portrait"]):
			unit["portrait"] = load(unit["portrait"])
		if unit.get("battle_sprite") is String and ResourceLoader.exists(unit["battle_sprite"]):
			unit["battle_sprite"] = load(unit["battle_sprite"])

		if not unit.has("unit_tags"):
			unit["unit_tags"] = []
		if not unit.has("skill_points"):
			unit["skill_points"] = 0
		if not unit.has("unlocked_skills"):
			unit["unlocked_skills"] = []
		if not unit.has("unlocked_abilities"):
			var curr_ab: String = str(unit.get("ability", "")).strip_edges()
			unit["unlocked_abilities"] = [curr_ab] if curr_ab != "" else []
		if not unit.has("traits"):
			unit["traits"] = []
		if not unit.has("rookie_legacies"):
			unit["rookie_legacies"] = []
		if not unit.has("base_class_legacies"):
			unit["base_class_legacies"] = []
		if not unit.has("promoted_class_legacies"):
			unit["promoted_class_legacies"] = []

		out.append(unit)

	return out
	
# Purpose: Calculates passive income based on base location and rolls for enemy attacks.
# Inputs: None.
# Outputs: None.
# Side Effects: Modifies base_resource_storage and base_under_attack flags.
func _process_base_economy() -> void:
	base_last_harvest_report.clear()
	if active_base_level_index == -1: return 

	if is_base_defense_active:
		is_base_defense_active = false
		base_under_attack = false
		return 

	if base_under_attack:
		base_resource_storage["wood"] = int(float(base_resource_storage["wood"]) * 0.2)
		base_resource_storage["iron"] = int(float(base_resource_storage["iron"]) * 0.2)
		base_resource_storage["gold"] = int(float(base_resource_storage["gold"]) * 0.2)
		base_under_attack = false
		base_last_harvest_report = {"robbed": true}
		return 

	# --- DYNAMIC YIELD LOGIC ---
	var w_gain = randi_range(2, 4)
	var i_gain = randi_range(2, 4)
	var g_gain = randi_range(40, 60)

	match active_base_level_index:
		0: # Forest: Wood Focus
			w_gain = randi_range(8, 12)
			g_gain = randi_range(20, 30)
		1: # Mines: Iron Focus
			i_gain = randi_range(6, 10)
			w_gain = randi_range(1, 2)
		2: # Trade Hub: Gold Focus
			g_gain = randi_range(120, 200)
		3: # Marshes: High Risk/High Gold
			g_gain = randi_range(250, 400)
			# Marshes might have a higher attack chance, but we'll stick to gold for now

	base_resource_storage["wood"] += w_gain
	base_resource_storage["iron"] += i_gain
	base_resource_storage["gold"] += g_gain

	base_last_harvest_report = {
		"robbed": false, "wood": w_gain, "iron": i_gain, "gold": g_gain,
		"total_wood": base_resource_storage["wood"], "total_iron": base_resource_storage["iron"], "total_gold": base_resource_storage["gold"]
	}

	if randf() <= 0.15:
		base_under_attack = true
				
# Purpose: Transfers stored resources to the global inventory and resets the base storage.
# Returns: A dictionary containing the exact amounts collected for UI display.
func collect_base_resources() -> Dictionary:
	var collected = base_resource_storage.duplicate()
	
	# 1. Transfer Gold
	global_gold += collected["gold"]
	
	# 2. Transfer Physical Items (Wooden Planks)
	# Check if we have any wood AND if the file exists before doing work
	if collected["wood"] > 0 and ResourceLoader.exists(wood_item_path):
		var wood_template = load(wood_item_path) # Load ONCE outside the loop
		for i in range(collected["wood"]):
			var new_wood = make_unique_item(wood_template) 
			global_inventory.append(new_wood)
	elif collected["wood"] > 0:
		push_error("Base Collection Error: WoodenPlank.tres not found at " + wood_item_path)
		
	# 3. Transfer Physical Items (Iron Ore)
	if collected["iron"] > 0 and ResourceLoader.exists(iron_item_path):
		var iron_template = load(iron_item_path) # Load ONCE outside the loop
		for i in range(collected["iron"]):
			var new_iron = make_unique_item(iron_template)
			global_inventory.append(new_iron)
	elif collected["iron"] > 0:
		push_error("Base Collection Error: IronOre.tres not found at " + iron_item_path)
		
	# 4. Reset storage and save progress
	base_resource_storage = {"wood": 0, "iron": 0, "gold": 0}
	save_current_progress()
	
	return collected
# Purpose: Scans the entire player roster to find the highest level unit.
# Inputs: None.
# Outputs: Integer representing the maximum level found (defaults to 1).
func get_highest_roster_level() -> int:
	var highest_level = 1
	
	for unit in player_roster:
		var u_level = int(unit.get("level", 1))
		if u_level > highest_level:
			highest_level = u_level
			
	return highest_level

# Purpose: Scans ONLY the units currently assigned to defend the base.
# Inputs: None.
# Outputs: Integer representing the maximum level among the garrison (defaults to 1).
func get_highest_garrison_level() -> int:
	var highest_level = 1
	
	for unit in player_roster:
		if unit.get("is_garrisoned", false):
			var u_level = int(unit.get("level", 1))
			if u_level > highest_level:
				highest_level = u_level
				
	return highest_level

func _ready() -> void:
	load_global_settings()
	var w := get_window()
	if w != null:
		if not w.focus_entered.is_connected(_on_window_focus_in_for_audio):
			w.focus_entered.connect(_on_window_focus_in_for_audio)
		if not w.focus_exited.is_connected(_on_window_focus_out_for_audio):
			w.focus_exited.connect(_on_window_focus_out_for_audio)


func _on_window_focus_out_for_audio() -> void:
	if not audio_mute_when_unfocused:
		return
	var b := AudioServer.get_bus_index("Master")
	if b >= 0:
		AudioServer.set_bus_mute(b, true)


func _on_window_focus_in_for_audio() -> void:
	if not audio_mute_when_unfocused:
		return
	apply_audio_settings()

func sanitize_player_display_name(raw: String) -> String:
	var s: String = str(raw).strip_edges()
	s = s.replace("\n", " ").replace("\r", "")
	if s.length() > PLAYER_PROFILE_DISPLAY_NAME_MAX_LEN:
		s = s.substr(0, PLAYER_PROFILE_DISPLAY_NAME_MAX_LEN)
	return s


## Resolves the name shown in UI / online tags. `override_line` is typically the profile LineEdit text or stored override.
func resolve_player_display_name(override_line: String, fallback_label: String = "Commander") -> String:
	var o: String = sanitize_player_display_name(override_line)
	if o != "":
		return o
	var steam_name: String = ""
	if SteamService != null and SteamService.has_method("get_steam_persona_name") and SteamService.is_steam_ready():
		steam_name = str(SteamService.get_steam_persona_name()).strip_edges()
	if steam_name != "":
		return steam_name
	var av: String = str(custom_avatar.get("name", custom_avatar.get("unit_name", ""))).strip_edges()
	if av != "":
		return av
	return fallback_label


func get_player_display_name(fallback_label: String = "Commander") -> String:
	return resolve_player_display_name(player_profile_display_override, fallback_label)


func load_global_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_FILE_PATH)

	if err != OK:
		apply_audio_settings()
		apply_game_speed_scale()
		apply_performance_settings()
		return

	audio_master_volume = clampf(float(cfg.get_value("audio", "master_volume", audio_master_volume)), 0.0, 1.0)
	audio_music_volume = clampf(float(cfg.get_value("audio", "music_volume", audio_music_volume)), 0.0, 1.0)
	audio_sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", audio_sfx_volume)), 0.0, 1.0)
	audio_mute_when_unfocused = bool(cfg.get_value("audio", "mute_when_unfocused", audio_mute_when_unfocused))

	camera_pan_speed = clampf(float(cfg.get_value("battle", "camera_pan_speed", camera_pan_speed)), 100.0, 2500.0)
	unit_move_speed = clampf(float(cfg.get_value("battle", "unit_move_speed", unit_move_speed)), 0.03, 1.0)
	game_speed_scale = sanitize_game_speed_scale(float(cfg.get_value("battle", "game_speed_scale", game_speed_scale)))

	battle_follow_enemy_camera = bool(cfg.get_value("battle", "follow_enemy_camera", battle_follow_enemy_camera))
	battle_ai_role_batch_turns = bool(cfg.get_value("battle", "ai_role_batch_turns", battle_ai_role_batch_turns))
	battle_show_danger_zone_default = bool(cfg.get_value("battle", "show_danger_zone_default", battle_show_danger_zone_default))
	battle_show_minimap_default = bool(cfg.get_value("battle", "show_minimap_default", battle_show_minimap_default))
	battle_minimap_opacity = clampf(float(cfg.get_value("battle", "minimap_opacity", battle_minimap_opacity)), 0.15, 1.0)

	battle_zoom_step = clampf(float(cfg.get_value("battle", "zoom_step", battle_zoom_step)), 0.02, 0.50)
	battle_min_zoom = clampf(float(cfg.get_value("battle", "min_zoom", battle_min_zoom)), 0.20, 3.00)
	battle_max_zoom = clampf(float(cfg.get_value("battle", "max_zoom", battle_max_zoom)), 0.20, 4.00)
	if battle_max_zoom <= battle_min_zoom:
		battle_max_zoom = battle_min_zoom + 0.10

	battle_zoom_to_cursor = bool(cfg.get_value("battle", "zoom_to_cursor", battle_zoom_to_cursor))
	battle_edge_margin = clampi(int(cfg.get_value("battle", "edge_margin", battle_edge_margin)), 4, 300)

	battle_show_grid = bool(cfg.get_value("battle", "show_grid", battle_show_grid))
	battle_show_enemy_threat = bool(cfg.get_value("battle", "show_enemy_threat", battle_show_enemy_threat))
	battle_show_faction_tiles = bool(cfg.get_value("battle", "show_faction_tiles", battle_show_faction_tiles))
	battle_show_path_preview = bool(cfg.get_value("battle", "show_path_preview", battle_show_path_preview))
	battle_path_preview_pulse = bool(cfg.get_value("battle", "path_preview_pulse", battle_path_preview_pulse))
	battle_path_style = clampi(int(cfg.get_value("battle", "path_style", battle_path_style)), BATTLE_PATH_STYLE_MINIMAL, BATTLE_PATH_STYLE_DASHED)
	battle_path_endpoint_marker = bool(cfg.get_value("battle", "path_endpoint_marker", battle_path_endpoint_marker))
	battle_path_corner_smoothing = clampi(int(cfg.get_value("battle", "path_corner_smoothing", battle_path_corner_smoothing)), 0, 2)
	battle_path_cost_ticks = bool(cfg.get_value("battle", "path_cost_ticks", battle_path_cost_ticks))
	battle_path_invalid_ghost = bool(cfg.get_value("battle", "path_invalid_ghost", battle_path_invalid_ghost))
	battle_show_log = bool(cfg.get_value("battle", "show_log", battle_show_log))
	battle_allow_fog_of_war = bool(cfg.get_value("battle", "allow_fog_of_war", battle_allow_fog_of_war))
	battle_deploy_zone_overlay_default = bool(cfg.get_value("battle", "deploy_zone_overlay_default", battle_deploy_zone_overlay_default))
	battle_deploy_auto_arm_after_place = bool(cfg.get_value("battle", "deploy_auto_arm_after_place", battle_deploy_auto_arm_after_place))
	battle_deploy_quick_fill = bool(cfg.get_value("battle", "deploy_quick_fill", battle_deploy_quick_fill))
	battle_skip_loot_window = bool(cfg.get_value("battle", "skip_loot_window", battle_skip_loot_window))

	performance_vsync = bool(cfg.get_value("performance", "vsync", performance_vsync))
	performance_max_fps = sanitize_performance_max_fps(int(cfg.get_value("performance", "max_fps", performance_max_fps)))
	performance_window_mode = clampi(int(cfg.get_value("performance", "window_mode", performance_window_mode)), 0, 2)
	performance_resolution = clampi(int(cfg.get_value("performance", "resolution", performance_resolution)), 0, RESOLUTION_OPTIONS.size() - 1)
	performance_msaa = clampi(int(cfg.get_value("performance", "msaa", performance_msaa)), 0, 3)
	performance_show_fps = bool(cfg.get_value("performance", "show_fps", performance_show_fps))
	performance_screen_shake = bool(cfg.get_value("performance", "screen_shake", performance_screen_shake))

	interface_hud_scale = clampi(int(cfg.get_value("interface", "hud_scale", interface_hud_scale)), 0, 4)
	interface_show_damage_numbers = bool(cfg.get_value("interface", "show_damage_numbers", interface_show_damage_numbers))
	interface_show_health_bars = bool(cfg.get_value("interface", "show_health_bars", interface_show_health_bars))
	interface_focus_unit_bars = bool(cfg.get_value("interface", "focus_unit_bars", interface_focus_unit_bars))
	interface_unit_bars_at_feet = bool(cfg.get_value("interface", "unit_bars_at_feet", interface_unit_bars_at_feet))
	interface_show_phase_banner = bool(cfg.get_value("interface", "show_phase_banner", interface_show_phase_banner))
	interface_show_status_effects = bool(cfg.get_value("interface", "show_status_effects", interface_show_status_effects))
	interface_damage_text_size = clampi(int(cfg.get_value("interface", "damage_text_size", interface_damage_text_size)), 0, 2)
	interface_combat_log_font_size = clampi(int(cfg.get_value("interface", "combat_log_font_size", interface_combat_log_font_size)), 0, 2)
	interface_cursor_size = clampi(int(cfg.get_value("interface", "cursor_size", interface_cursor_size)), 0, 2)
	interface_cursor_high_contrast = bool(cfg.get_value("interface", "cursor_high_contrast", interface_cursor_high_contrast))

	player_profile_display_override = str(cfg.get_value("profile", "display_name_override", player_profile_display_override))
	player_profile_display_override = sanitize_player_display_name(player_profile_display_override)

	apply_audio_settings()
	apply_game_speed_scale()
	apply_performance_settings()

func save_global_settings() -> void:
	var cfg := ConfigFile.new()

	cfg.set_value("audio", "master_volume", audio_master_volume)
	cfg.set_value("audio", "music_volume", audio_music_volume)
	cfg.set_value("audio", "sfx_volume", audio_sfx_volume)
	cfg.set_value("audio", "mute_when_unfocused", audio_mute_when_unfocused)

	cfg.set_value("battle", "camera_pan_speed", camera_pan_speed)
	cfg.set_value("battle", "unit_move_speed", unit_move_speed)
	cfg.set_value("battle", "game_speed_scale", game_speed_scale)

	cfg.set_value("battle", "follow_enemy_camera", battle_follow_enemy_camera)
	cfg.set_value("battle", "ai_role_batch_turns", battle_ai_role_batch_turns)
	cfg.set_value("battle", "show_danger_zone_default", battle_show_danger_zone_default)
	cfg.set_value("battle", "show_minimap_default", battle_show_minimap_default)
	cfg.set_value("battle", "minimap_opacity", battle_minimap_opacity)

	cfg.set_value("battle", "zoom_step", battle_zoom_step)
	cfg.set_value("battle", "min_zoom", battle_min_zoom)
	cfg.set_value("battle", "max_zoom", battle_max_zoom)
	cfg.set_value("battle", "zoom_to_cursor", battle_zoom_to_cursor)
	cfg.set_value("battle", "edge_margin", battle_edge_margin)

	cfg.set_value("battle", "show_grid", battle_show_grid)
	cfg.set_value("battle", "show_enemy_threat", battle_show_enemy_threat)
	cfg.set_value("battle", "show_faction_tiles", battle_show_faction_tiles)
	cfg.set_value("battle", "show_path_preview", battle_show_path_preview)
	cfg.set_value("battle", "path_preview_pulse", battle_path_preview_pulse)
	cfg.set_value("battle", "path_style", battle_path_style)
	cfg.set_value("battle", "path_endpoint_marker", battle_path_endpoint_marker)
	cfg.set_value("battle", "path_corner_smoothing", battle_path_corner_smoothing)
	cfg.set_value("battle", "path_cost_ticks", battle_path_cost_ticks)
	cfg.set_value("battle", "path_invalid_ghost", battle_path_invalid_ghost)
	cfg.set_value("battle", "show_log", battle_show_log)
	cfg.set_value("battle", "allow_fog_of_war", battle_allow_fog_of_war)
	cfg.set_value("battle", "deploy_zone_overlay_default", battle_deploy_zone_overlay_default)
	cfg.set_value("battle", "deploy_auto_arm_after_place", battle_deploy_auto_arm_after_place)
	cfg.set_value("battle", "deploy_quick_fill", battle_deploy_quick_fill)
	cfg.set_value("battle", "skip_loot_window", battle_skip_loot_window)

	cfg.set_value("performance", "vsync", performance_vsync)
	cfg.set_value("performance", "max_fps", performance_max_fps)
	cfg.set_value("performance", "window_mode", performance_window_mode)
	cfg.set_value("performance", "resolution", performance_resolution)
	cfg.set_value("performance", "msaa", performance_msaa)
	cfg.set_value("performance", "show_fps", performance_show_fps)
	cfg.set_value("performance", "screen_shake", performance_screen_shake)

	cfg.set_value("interface", "hud_scale", interface_hud_scale)
	cfg.set_value("interface", "show_damage_numbers", interface_show_damage_numbers)
	cfg.set_value("interface", "show_health_bars", interface_show_health_bars)
	cfg.set_value("interface", "focus_unit_bars", interface_focus_unit_bars)
	cfg.set_value("interface", "unit_bars_at_feet", interface_unit_bars_at_feet)
	cfg.set_value("interface", "show_phase_banner", interface_show_phase_banner)
	cfg.set_value("interface", "show_status_effects", interface_show_status_effects)
	cfg.set_value("interface", "damage_text_size", interface_damage_text_size)
	cfg.set_value("interface", "combat_log_font_size", interface_combat_log_font_size)
	cfg.set_value("interface", "cursor_size", interface_cursor_size)
	cfg.set_value("interface", "cursor_high_contrast", interface_cursor_high_contrast)

	cfg.set_value("profile", "display_name_override", player_profile_display_override)

	var err := cfg.save(SETTINGS_FILE_PATH)
	if err != OK:
		push_warning("Could not save global settings. Error code: %s" % err)

func sanitize_game_speed_scale(v: float) -> float:
	if v <= 1.24:
		return 1.0
	if v <= 1.74:
		return 1.5
	return 2.0


func apply_game_speed_scale() -> void:
	game_speed_scale = sanitize_game_speed_scale(game_speed_scale)
	Engine.time_scale = game_speed_scale


func sanitize_performance_max_fps(v: int) -> int:
	var choices: Array[int] = [0, 30, 60, 90, 120, 144, 240]
	var vv: int = clampi(int(v), 0, 360)
	var best: int = choices[0]
	var best_d: int = absi(vv - best)
	for o in choices:
		var oi: int = int(o)
		var d: int = absi(vv - oi)
		if d < best_d:
			best_d = d
			best = oi
	return best


func apply_performance_settings() -> void:
	performance_max_fps = sanitize_performance_max_fps(performance_max_fps)
	if performance_vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = performance_max_fps

	performance_window_mode = clampi(performance_window_mode, 0, 2)
	match performance_window_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			_apply_windowed_resolution()
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	performance_msaa = clampi(performance_msaa, 0, 3)
	var vp := get_viewport()
	if vp != null:
		var msaa_map: Array[int] = [
			Viewport.MSAA_DISABLED,
			Viewport.MSAA_2X,
			Viewport.MSAA_4X,
			Viewport.MSAA_8X,
		]
		vp.msaa_2d = msaa_map[performance_msaa] as Viewport.MSAA


const RESOLUTION_OPTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]


func _apply_windowed_resolution() -> void:
	performance_resolution = clampi(performance_resolution, 0, RESOLUTION_OPTIONS.size() - 1)
	var res := RESOLUTION_OPTIONS[performance_resolution]
	DisplayServer.window_set_size(res)
	var screen_sz := DisplayServer.screen_get_size()
	var win_pos := (screen_sz - res) / 2
	DisplayServer.window_set_position(Vector2i(maxi(win_pos.x, 0), maxi(win_pos.y, 0)))


const INTERFACE_HUD_SCALE_VALUES: Array[float] = [1.0, 1.25, 1.5, 1.75, 2.0]
const INTERFACE_DAMAGE_TEXT_SIZES: Array[int] = [16, 22, 30]
const INTERFACE_LOG_FONT_SIZES: Array[int] = [14, 18, 24]
const INTERFACE_CURSOR_SCALE_VALUES: Array[float] = [1.0, 1.15, 1.30]


func get_hud_scale_float() -> float:
	return INTERFACE_HUD_SCALE_VALUES[clampi(interface_hud_scale, 0, INTERFACE_HUD_SCALE_VALUES.size() - 1)]


func get_damage_text_font_size() -> int:
	return INTERFACE_DAMAGE_TEXT_SIZES[clampi(interface_damage_text_size, 0, INTERFACE_DAMAGE_TEXT_SIZES.size() - 1)]


func get_combat_log_font_size() -> int:
	return INTERFACE_LOG_FONT_SIZES[clampi(interface_combat_log_font_size, 0, INTERFACE_LOG_FONT_SIZES.size() - 1)]


func get_cursor_scale_float() -> float:
	return INTERFACE_CURSOR_SCALE_VALUES[clampi(interface_cursor_size, 0, INTERFACE_CURSOR_SCALE_VALUES.size() - 1)]


func _set_bus_volume_linear(bus_name: String, linear_vol: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return
	var v := clampf(linear_vol, 0.0, 1.0)
	if v <= 0.001:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(v))


func apply_audio_settings() -> void:
	_set_bus_volume_linear("Master", audio_master_volume)
	_set_bus_volume_linear("Music", audio_music_volume)
	_set_bus_volume_linear("SFX", audio_sfx_volume)
