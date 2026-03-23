# BattleField.gd
# -----------------------------------------------------------------------------
# Main tactical battle controller.
#
# This script coordinates most of the combat-scene flow:
# - battlefield grid / pathfinding / cursor state
# - player / ally / enemy turn-state orchestration
# - combat forecast and combat presentation
# - talk / support / trade / inventory / loot UI
# - level-up, arena, objective, fog-of-war, and battle presentation
#
# Important:
# This file is highly central and currently owns multiple subsystems.
# Keep declarations grouped clearly so future refactors are less cursed.
# -----------------------------------------------------------------------------

extends Node2D
class_name BattleField


# =============================================================================
# SIGNALS
# =============================================================================

signal forecast_resolved(action: String, use_ability: bool)
signal dialogue_advanced
signal promotion_chosen(chosen_class_res: Resource)
## ENet mock co-op: guest finished applying host-resolved combat for the guest's own attacker (see [method coop_enet_guest_delegate_player_combat_to_host]).
signal coop_guest_host_combat_resolved


# =============================================================================
# ENUMS / CONSTANTS / PRELOADS
# =============================================================================

enum Objective { ROUT_ENEMY, SURVIVE_TURNS, DEFEND_TARGET }
enum UISfx { MOVE_OK, TARGET_OK, INVALID }

const CELL_SIZE = Vector2i(64, 64)
## Co-op: wire schema for [method coop_net_build_authoritative_combat_snapshot] / peer apply (no second combat sim).
const COOP_AUTH_BATTLE_SNAPSHOT_VER: int = 1

const LEVELUP_HOLD_TIME_NORMAL := 4.2
const LEVELUP_HOLD_TIME_PERFECT := 6.0
const LEVELUP_ROW_REVEAL_DELAY := 0.50

const PATH_ALPHA_MIN := 0.55
const PATH_ALPHA_MAX := 1.00
const PATH_PULSE_TIME := 0.35

const UI_SFX_COOLDOWN_MS := 45

# Support-bound combat (passive bonuses only). Range = Manhattan distance; best single partner only.
const SUPPORT_COMBAT_RANGE_MANHATTAN := 2
# V1 rank table: hit, avoid, crit_avoid (applied to unit when bonded ally within range)
const SUPPORT_COMBAT_RANK_BONUSES: Dictionary = {
	1: {"hit": 5, "avo": 3, "crit_avo": 0},
	2: {"hit": 8, "avo": 5, "crit_avo": 2},
	3: {"hit": 10, "avo": 8, "crit_avo": 5}
}
# Set true to log when support-combat bonuses are applied (one line per unit that receives non-zero bonus).
const DEBUG_SUPPORT_COMBAT := false

## Static helpers + legacy ids (preload so BattleField does not depend on global class registration order).
const UnitTraitsLib = preload("res://Scripts/Core/UnitTraitsDisplay.gd")

# Character-creation passives (not Shove/Grapple). Forecast tactical button can show class_tactical_ability (e.g. Fire Sage → Fire Trap).
const PASSIVE_FORECAST_SLOT_ABILITIES: Array[String] = [
	"Bloodthirster",
	"Shield Clash",
	"Focused Strike",
	"Hundred Point Strike",
]

# Rookie / civilian class passives (stack with personal creation abilities).
const META_ROOKIE_RECRUIT_DRILL := "rookie_recruit_drill_used"
const META_ROOKIE_VILLAGER_DESPERATE := "rookie_villager_desperate_turn"
const META_ROOKIE_VILLAGER_LAST_PROC_TURN := "rookie_villager_last_proc_turn"
const META_ROOKIE_APPRENTICE_HITS := "rookie_apprentice_magic_hits_landed"
const META_ROOKIE_NOVICE_DONE := "rookie_novice_blank_done"
const META_ROOKIE_NOVICE_HIT := "rookie_novice_hit_bonus"
const META_ROOKIE_NOVICE_DMG := "rookie_novice_dmg_bonus"
const META_ROOKIE_NOVICE_CRIT := "rookie_novice_crit_bonus"

# Relationship Web V1: combat modifiers from trust/rivalry/mentorship/grief/fear. Set true to log relationship combat effects.
const DEBUG_RELATIONSHIP_COMBAT := false
# Tags that trigger fear/disgust penalty when enemy has them (unit_tags).
const FEAR_TAGS: Array = ["undead", "cultist", "corrupted"]
# V1 thresholds and modifier amounts (modest numbers).
const RELATIONSHIP_TRUST_THRESHOLD := 20
const RELATIONSHIP_RIVALRY_THRESHOLD := 15
const RELATIONSHIP_MENTORSHIP_THRESHOLD := 25
const RELATIONSHIP_GRIEF_HIT_PENALTY := -5
const RELATIONSHIP_GRIEF_AVO_PENALTY := -5
const RELATIONSHIP_RIVALRY_CRIT_BONUS := 3
const RELATIONSHIP_RIVALRY_DMG_BONUS := 1
const RELATIONSHIP_MENTORSHIP_HIT_BONUS := 2
const RELATIONSHIP_FEAR_HIT_PENALTY := -3
const RELATIONSHIP_FEAR_AVO_PENALTY := -3
const RELATIONSHIP_TRUST_SUPPORT_CHANCE_BONUS := 2
const VICTORY_TRUST_PROXIMITY_MANHATTAN := 2

# Phase 2: support reaction chances (percent). Guard = redirect one hit to partner; Dual Strike = partner bonus strike.
const SUPPORT_GUARD_CHANCE_RANK2 := 12
const SUPPORT_GUARD_CHANCE_RANK3 := 20
const SUPPORT_DUAL_STRIKE_CHANCE_RANK2 := 15
const SUPPORT_DUAL_STRIKE_CHANCE_RANK3 := 25

# Burn DoT: applied once per full round when the enemy phase ends (before turn counter increments).
const BURN_TICK_MAX_HP_FRACTION := 0.06
const BURN_TICK_DAMAGE_MIN := 1
const BURN_TICK_DAMAGE_MAX := 10

# Boss Personal Dialogue (V1): trigger logic and tracking in BattleField; content in BossPersonalDialogueDB.
const BossDialogueDB = preload("res://Scripts/Narrative/BossPersonalDialogueDB.gd")
# Defy Death rescue lines by savior support_personality; content in SupportRescueDialogueDB.
const SupportRescueDialogueDB = preload("res://Scripts/Narrative/SupportRescueDialogueDB.gd")

const FloatingTextScene = preload("res://Scenes/FloatingText.tscn")


var detailed_unit_info_layer: CanvasLayer
var detailed_unit_info_panel: Panel
var detailed_unit_info_name: Label
var detailed_unit_info_portrait: TextureRect
var detailed_unit_info_left_text: RichTextLabel
var detailed_unit_info_right_text: RichTextLabel
var detailed_unit_info_close_btn: Button

# =============================================================================
# EXPORTED SCENE / AUDIO / GENERAL CONFIG
# =============================================================================

@export var player_unit_scene: PackedScene
@export var barricade_scene: PackedScene
@export var fortress_scene: PackedScene

@export var enemy_scene: PackedScene
@export var skirmish_music: AudioStream

@export var promotion_sound: AudioStream

@export var dash_fx_scene: PackedScene
@export var slash_fx_scene: PackedScene
@export var level_up_fx_scene: PackedScene

@export_category("Hazards — Fire tiles")
@export var fire_tile_loop_vfx_scene: PackedScene
@export var default_fire_tile_damage: int = 3
@export var fire_tile_extinguish_shrink_sec: float = 0.18

@export var GRID_SIZE: Vector2i = Vector2i(16, 10)

# --- Camera configuration ---
@export var zoom_step: float = 0.10
@export var min_zoom: float = 0.60
@export var max_zoom: float = 2.20
@export var zoom_to_cursor: bool = true

@export var camera_speed: float = 600.0
@export var edge_margin: int = 50


# =============================================================================
# EXPORTED LEVEL / CINEMATIC / OBJECTIVE CONFIG
# =============================================================================

@export_category("Fog of War")
@export var use_fog_of_war: bool = false
@export var default_vision_range: int = 5
@export var vision_blocking_terrain: Array[String] = [
	"Wall",
	"Mountain",
	"Closed Gate",
	"Tall Pillar"
]

@export_category("Level Cinematic")
@export var intro_dialogue: Array[DialogueBlock] = []
@export var outro_dialogue: Array[DialogueBlock] = []

@export_category("Level Objective")
@export var map_objective: Objective = Objective.ROUT_ENEMY
@export var custom_objective_text: String = ""
@export var turn_limit: int = 10
@export var vip_target: Node2D


# =============================================================================
# CORE SCENE REFERENCES
# =============================================================================

@onready var player_container = $PlayerUnits
@onready var ally_container = $AllyUnits
@onready var enemy_container = $EnemyUnits
@onready var walls_container = $Walls
@onready var chests_container = $Chests
@onready var destructibles_container = $Destructibles

@onready var main_camera = $MainCamera
@onready var cursor = $Cursor
@onready var cursor_sprite = $Cursor/Sprite2D
@onready var target_cursor = $TargetCursor
@onready var path_line: Line2D = $PathLine
@onready var hover_glow = $HoverGlow

@onready var minimap_container: Control = %MiniMapContainer
@onready var map_drawer: CanvasItem = %MapDrawer


# =============================================================================
# UI - UNIT INFO / CORE HUD
# =============================================================================

@onready var unit_info_panel = $UI/UnitInfoPanel
@onready var unit_portrait = $UI/UnitInfoPanel/PortraitRect
@onready var unit_name_label = $UI/UnitInfoPanel/NameLabel
@onready var unit_hp_label = $UI/UnitInfoPanel/HPLabel
@onready var unit_stats_label = $UI/UnitInfoPanel/StatsLabel
@onready var support_btn = $UI/UnitInfoPanel/SupportButton
@onready var open_inv_button = $UI/UnitInfoPanel/OpenInvButton

@onready var gold_label = $UI/GoldLabel
@onready var battle_log = $UI/BattleLogPanel/RichTextLabel
@onready var convoy_button = $UI/ConvoyButton


# =============================================================================
# UI - TALK / DIALOGUE
# =============================================================================

@onready var talk_panel = $UI/TalkPanel
@onready var talk_left_portrait = $UI/TalkPanel/LeftPortrait
@onready var talk_right_portrait = $UI/TalkPanel/RightPortrait
@onready var talk_name = $UI/TalkPanel/NameLabel
@onready var talk_text = $UI/TalkPanel/DialogueText
@onready var talk_next_btn = $UI/TalkPanel/NextButton


# =============================================================================
# UI - SUPPORT
# =============================================================================

@onready var support_tracker_panel = $UI/SupportTrackerPanel
@onready var support_list_text = $UI/SupportTrackerPanel/SupportList
@onready var close_support_btn = $UI/SupportTrackerPanel/CloseButton


# =============================================================================
# UI - TRADE
# =============================================================================

@onready var trade_popup = $UI/TradePopup
@onready var trade_popup_btn = $UI/TradePopup/VBoxContainer/TradeButton
@onready var popup_talk_btn = $UI/TradePopup/VBoxContainer/SupportTalkButton

@onready var trade_window = $UI/TradeWindow
@onready var trade_left_name = $UI/TradeWindow/LeftName
@onready var trade_left_portrait = $UI/TradeWindow/LeftPortrait
@onready var trade_left_list = $UI/TradeWindow/LeftList
@onready var trade_right_name = $UI/TradeWindow/RightName
@onready var trade_right_portrait = $UI/TradeWindow/RightPortrait
@onready var trade_right_list = $UI/TradeWindow/RightList
@onready var trade_close_btn = $UI/TradeWindow/CloseButton


# =============================================================================
# UI - COMBAT FORECAST
# =============================================================================

@onready var forecast_panel = $UI/CombatForecastPanel
@onready var forecast_talk_btn: Button = get_node_or_null("UI/CombatForecastPanel/TalkButton") as Button
@onready var forecast_ability_btn = $UI/CombatForecastPanel/AbilityButton

@onready var forecast_atk_name = $UI/CombatForecastPanel/AtkName
@onready var forecast_atk_hp = $UI/CombatForecastPanel/AtkHP
@onready var forecast_atk_dmg = $UI/CombatForecastPanel/AtkDMG
@onready var forecast_atk_hit = $UI/CombatForecastPanel/AtkHit
@onready var forecast_atk_crit = $UI/CombatForecastPanel/AtkCrit
@onready var forecast_atk_weapon = $UI/CombatForecastPanel/AtkWeapon
@onready var forecast_atk_adv = $UI/CombatForecastPanel/AtkAdvantage
@onready var forecast_atk_double = $UI/CombatForecastPanel/AtkDoubleLabel

@onready var forecast_def_name = $UI/CombatForecastPanel/DefName
@onready var forecast_def_hp = $UI/CombatForecastPanel/DefHP
@onready var forecast_def_dmg = $UI/CombatForecastPanel/DefDMG
@onready var forecast_def_hit = $UI/CombatForecastPanel/DefHit
@onready var forecast_def_crit = $UI/CombatForecastPanel/DefCrit
@onready var forecast_def_weapon = $UI/CombatForecastPanel/DefWeapon
@onready var forecast_def_adv = $UI/CombatForecastPanel/DefAdvantage
@onready var forecast_def_double = $UI/CombatForecastPanel/DefDoubleLabel

var forecast_atk_support_label: Label
var forecast_def_support_label: Label
var forecast_instruction_label: Label
var forecast_reaction_label: Label


# =============================================================================
# UI - INVENTORY / CONVOY
# =============================================================================

@onready var inventory_panel = $UI/InventoryPanel
@onready var inv_scroll = $UI/InventoryPanel/InventoryScroll
@onready var unit_grid = $UI/InventoryPanel/InventoryScroll/InventoryVBox/UnitGrid
@onready var convoy_grid = $UI/InventoryPanel/InventoryScroll/InventoryVBox/ConvoyGrid
@onready var inv_desc_label = $UI/InventoryPanel/ItemDescLabel
@onready var equip_button = $UI/InventoryPanel/EquipButton
@onready var use_button = $UI/InventoryPanel/UseButton


# =============================================================================
# UI - LOOT
# =============================================================================

@onready var loot_window = $UI/LootWindow
@onready var loot_item_list = $UI/LootWindow/ItemList
@onready var close_loot_button = $UI/LootWindow/CloseLootButton
@onready var loot_desc_label = $UI/LootWindow/ItemDescLabel


# =============================================================================
# UI - LEVEL / PHASE / GAME OVER
# =============================================================================

@onready var level_up_panel = $UI/LevelUpPanel
@onready var level_up_title = $UI/LevelUpPanel/TitleLabel
@onready var level_up_stats = $UI/LevelUpPanel/StatsLabel

@onready var phase_banner = $UI/PhaseBanner
@onready var game_over_panel = $UI/GameOverPanel
@onready var result_label = $UI/GameOverPanel/ResultLabel
@onready var restart_button = $UI/GameOverPanel/RestartButton
@onready var continue_button = $UI/GameOverPanel/ContinueButton


# =============================================================================
# UI - ARENA VS CINEMATIC
# =============================================================================

@onready var arena_vs_layer: Control = $UI/ArenaVSLayer
@onready var arena_vs_dimmer: ColorRect = $UI/ArenaVSLayer/Dimmer
@onready var arena_vs_flash: ColorRect = $UI/ArenaVSLayer/FlashRect
@onready var arena_vs_top_bar: ColorRect = $UI/ArenaVSLayer/TopBar
@onready var arena_vs_bottom_bar: ColorRect = $UI/ArenaVSLayer/BottomBar

@onready var arena_vs_left_panel: Control = $UI/ArenaVSLayer/LeftPanel
@onready var arena_vs_left_portrait: TextureRect = $UI/ArenaVSLayer/LeftPanel/Portrait
@onready var arena_vs_left_name: Label = $UI/ArenaVSLayer/LeftPanel/NameLabel
@onready var arena_vs_left_rank: Label = $UI/ArenaVSLayer/LeftPanel/RankLabel
@onready var arena_vs_left_mmr: Label = $UI/ArenaVSLayer/LeftPanel/MMRLabel

@onready var arena_vs_right_panel: Control = $UI/ArenaVSLayer/RightPanel
@onready var arena_vs_right_portrait: TextureRect = $UI/ArenaVSLayer/RightPanel/Portrait
@onready var arena_vs_right_name: Label = $UI/ArenaVSLayer/RightPanel/NameLabel
@onready var arena_vs_right_rank: Label = $UI/ArenaVSLayer/RightPanel/RankLabel
@onready var arena_vs_right_mmr: Label = $UI/ArenaVSLayer/RightPanel/MMRLabel

@onready var arena_vs_label: Label = $UI/ArenaVSLayer/VSLabel
@onready var arena_vs_particles: CPUParticles2D = $UI/ArenaVSLayer/SweepParticles


# =============================================================================
# AUDIO REFERENCES
# =============================================================================

@onready var attack_sound = $AttackSound
@onready var crit_sound = $CritSound
@onready var defend_sound = $DefendSound
@onready var invalid_sound = $InvalidSound
@onready var miss_sound = $MissSound
@onready var no_damage_sound = $NoDamageSound
@onready var select_sound = $SelectSound

@onready var level_up_sound = $LevelUpSound
@onready var epic_level_up_sound = $EpicLevelUpSound

@onready var phase_sound = $UI/PhaseSound


# =============================================================================
# PATHFINDING / GRID STATE
# =============================================================================

var astar = AStarGrid2D.new()
var flying_astar = AStarGrid2D.new()

var cursor_grid_pos = Vector2i.ZERO
var reachable_tiles: Array[Vector2i] = []
var attackable_tiles: Array[Vector2i] = []

var enemy_reachable_tiles: Array[Vector2i] = []
var enemy_attackable_tiles: Array[Vector2i] = []

var show_danger_zone: bool = false
var danger_zone_move_tiles: Array[Vector2i] = []
var danger_zone_attack_tiles: Array[Vector2i] = []
var _danger_zone_recalc_dirty: bool = false


# =============================================================================
# FOG OF WAR RUNTIME STATE
# =============================================================================

var fow_grid: Dictionary = {}
var fow_display_alphas: Dictionary = {}

var fow_image: Image
var fow_texture: ImageTexture
var fog_drawer: Node2D


# =============================================================================
# BATTLE / CAMERA / VFX RUNTIME STATE
# =============================================================================

var current_turn: int = 1
var camera_follows_enemies: bool = true
var is_arena_match: bool = false

func _battle_resonance_allowed() -> bool:
	return CampaignManager != null and not is_arena_match and not CampaignManager.is_skirmish_mode

var _camera_zoom_target: float = 1.0
var _camera_zoom_tween: Tween

var _hit_stop_active: bool = false
var _impact_restore_tween: Tween

var _path_pulse_tween: Tween
var _path_pulse_active := false

var crit_flash_tween: Tween
var atk_double_origin: Vector2
var def_double_origin: Vector2
var figure_8_tween: Tween

## Runtime fire hazards: Vector2i cell -> { remaining_turns: int, damage: int, vfx: Node }
var fire_tiles: Dictionary = {}


# =============================================================================
# TURN STATES / GAME STATES
# =============================================================================

var current_state: GameState
var player_state: PlayerTurnState
var pre_battle_state: PreBattleState
var ally_state: AITurnState
var enemy_state: AITurnState


# =============================================================================
# SUPPORT / RELATIONSHIP RUNTIME STATE
# =============================================================================

var _support_popup_busy: bool = false

var _battle_support_ready_queue: Array[Dictionary] = []
var _battle_support_ready_seen: Dictionary = {} # bond_key -> true

# Phase 2: reaction state. Guard: one per strike sequence; Dual Strike: one per attack exchange; Defy Death: once per unit per battle.
var _support_guard_used_this_sequence: bool = false
var _support_dual_strike_done_this_attack: bool = false
var _defy_death_used: Dictionary = {} # unit get_instance_id() -> true when that unit was saved this battle (instance-id avoids name collisions)
var _grief_units: Dictionary = {} # get_relationship_id(unit) -> true when unit witnessed a trusted ally die this battle
# Relationship Web: one trust gain per pair per event type per battle (anti-farm).
var _relationship_event_awarded: Dictionary = {} # key = get_support_key(id_a, id_b) + "_" + event_type

# Bond Pulse: trust = soft cyan; mentorship = warm gold; rivalry = sharp red/amber.
const BOND_PULSE_COLOR_TRUST: Color = Color(0.35, 0.82, 0.88)
const BOND_PULSE_COLOR_MENTORSHIP: Color = Color(0.95, 0.75, 0.2)
const BOND_PULSE_COLOR_RIVALRY: Color = Color(0.92, 0.35, 0.2)
# Formation thresholds (persistent stat 0..100): first time crossing shows "Formed" pulse + log.
const MENTORSHIP_FORMED_THRESHOLD: int = 25
const RIVALRY_FORMED_THRESHOLD: int = 20
const MENTORSHIP_LEVEL_GAP_MIN: int = 3

# Rivalry: enemy instance id -> list of relationship ids that damaged it this battle.
var _enemy_damagers: Dictionary = {} # int (instance_id) -> Array[String]

# Boss Personal Dialogue (V1): one-time-per-battle pre-attack per boss/playable pair. Key: "boss_id|unit_id".
var _boss_personal_dialogue_played: Dictionary = {}


# =============================================================================
# TRADE / INVENTORY / LOOT RUNTIME STATE
# =============================================================================

var loot_recipient: Node2D = null # Remembers who gets the loot even if turn ends

var trade_unit_a: Node2D = null
var trade_unit_b: Node2D = null
var trade_selected_side: String = ""
var trade_selected_index: int = -1

var selected_inventory_meta: Dictionary = {}
var unit_managing_inventory: Node2D = null

var pending_loot: Array[Resource] = []

var player_gold: int = 0
var player_inventory: Array[Resource] = []


# =============================================================================
# SCORE / TRACKING / UI THROTTLING
# =============================================================================

var ability_triggers_count: int = 0
var enemy_kills_count: int = 0
var player_deaths_count: int = 0
var ally_deaths_count: int = 0

## Filled when this battle consumed CampaignManager.consume_pending_mock_coop_battle_handoff() (mock co-op bridge only).
var _consumed_mock_coop_battle_handoff: Dictionary = {}
## Interpretation of consumed handoff; null when no mock handoff was consumed this battle.
var _mock_coop_battle_context: MockCoopBattleContext = null
## Mock co-op only: per-unit ownership after assignment (empty when inactive or context invalid).
var _mock_coop_ownership_assignments: Array[Dictionary] = []
var _mock_coop_skip_button_glow_active: bool = false
var _skip_button_base_modulate: Color = Color.WHITE
var _skip_button_base_modulate_captured: bool = false
var _mock_partner_placeholder_combat_log_done: bool = false

const MOCK_COOP_BATTLE_OWNER_META: String = "mock_coop_battle_owner"
const MOCK_COOP_OWNER_LOCAL: String = "local"
const MOCK_COOP_OWNER_REMOTE: String = "remote"

func get_consumed_mock_coop_battle_handoff_snapshot() -> Dictionary:
	return _consumed_mock_coop_battle_handoff.duplicate(true)


func get_mock_coop_battle_context_snapshot() -> Dictionary:
	if _mock_coop_battle_context == null:
		return {"active": false, "context_valid": false}
	return _mock_coop_battle_context.get_snapshot()


func get_mock_coop_unit_ownership_snapshot() -> Dictionary:
	if _mock_coop_ownership_assignments.is_empty():
		return {"active": false}
	return {
		"active": true,
		"rule": "first_half_local_ceil",
		"assignments": _mock_coop_ownership_assignments.duplicate(true),
	}


## Returns MOCK_COOP_OWNER_LOCAL / MOCK_COOP_OWNER_REMOTE, or "" if unset / not mock co-op.
func get_mock_coop_unit_owner_for_unit(unit: Node) -> String:
	if unit == null or not is_instance_valid(unit) or not unit.has_meta(MOCK_COOP_BATTLE_OWNER_META):
		return ""
	return str(unit.get_meta(MOCK_COOP_BATTLE_OWNER_META))


func is_mock_coop_unit_ownership_active() -> bool:
	return not _mock_coop_ownership_assignments.is_empty()


## True when mock co-op ownership is on and this unit is assigned to the remote partner (not locally commandable).
func is_local_player_command_blocked_for_mock_coop_unit(unit: Node) -> bool:
	if unit == null or not is_instance_valid(unit) or _mock_coop_ownership_assignments.is_empty():
		return false
	return get_mock_coop_unit_owner_for_unit(unit) == MOCK_COOP_OWNER_REMOTE


func notify_mock_coop_remote_command_blocked(unit: Node2D) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	play_ui_sfx(UISfx.INVALID)
	var uname: String = str(unit.get("unit_name")) if unit.get("unit_name") != null else str(unit.name)
	if battle_log != null and battle_log.visible:
		add_combat_log("Co-op: %s answers to your partner — you cannot command this unit here." % uname, "orange")
	if unit is CanvasItem and (unit as CanvasItem).visible:
		spawn_loot_text("Partner's unit", Color(1.0, 0.55, 0.2), unit.global_position + Vector2(32, -32))


func try_allow_local_player_select_unit_for_command(unit: Node2D) -> bool:
	if is_local_player_command_blocked_for_mock_coop_unit(unit):
		notify_mock_coop_remote_command_blocked(unit)
		return false
	return true


var _coop_enet_remote_sync_queue: Array = []
var _coop_enet_remote_sync_busy: bool = false
## ENet co-op: shared global RNG for combat (host publishes base seed; each attack re-seeds with a unique combat id).
var _coop_net_have_battle_seed: bool = false
var _coop_net_stored_battle_seed: int = 0
var _coop_net_local_combat_seq: int = 0
## Guest only: host-ordered enemy/AI combat packets (applied when local AI reaches the same strike).
var _coop_net_incoming_enemy_combat_fifo: Array = []
## Guest: relationship id of attacker while waiting for host [code]player_combat[/code] / [code]player_post_combat[/code] after [method coop_enet_guest_delegate_player_combat_to_host].
var _coop_guest_awaiting_combat_aid: String = ""

func _exit_tree() -> void:
	_coop_net_reset_battle_rng_sync()
	CoopExpeditionSessionManager.unregister_enet_coop_battle_sync_battlefield(self)


func _coop_net_reset_battle_rng_sync() -> void:
	_coop_net_have_battle_seed = false
	_coop_net_stored_battle_seed = 0
	_coop_net_local_combat_seq = 0
	_coop_net_incoming_enemy_combat_fifo.clear()
	_coop_qte_event_seq = 0
	_coop_qte_mirror_active = false
	_coop_qte_mirror_dict.clear()
	_coop_qte_capture_active = false
	_coop_qte_capture_dict.clear()
	_coop_guest_awaiting_combat_aid = ""


## Called on host + guest when the session locks RNG for this battle ([method CoopExpeditionSessionManager.enet_try_publish_coop_battle_rng_seed]).
func apply_coop_battle_net_rng_seed(s: int) -> void:
	_coop_net_stored_battle_seed = s
	_coop_net_have_battle_seed = true
	_coop_net_local_combat_seq = 0
	seed(s)
	if OS.is_debug_build():
		print("[CoopBattleRNG] Global seed locked (base=%d)." % s)


func coop_net_rng_sync_ready() -> bool:
	return _coop_net_have_battle_seed


func _coop_net_seed_global_for_packed_combat_id(packed_id: int) -> void:
	if not _coop_net_have_battle_seed:
		return
	seed(hash(str(_coop_net_stored_battle_seed) + "#" + str(packed_id)))


## Call immediately before [method execute_combat] on the attacker’s machine. Returns packed id for the wire (guest vs host ranges avoid collisions).
func coop_enet_begin_synchronized_combat_round() -> int:
	if not _coop_net_have_battle_seed:
		return -1
	if not is_mock_coop_unit_ownership_active():
		return -1
	if not CoopExpeditionSessionManager.uses_enet_coop_transport():
		return -1
	if CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.NONE:
		return -1
	_coop_net_local_combat_seq += 1
	var hi: int = 1 if CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.HOST else 0
	var packed: int = hi * 1_000_000_000 + _coop_net_local_combat_seq
	_coop_net_seed_global_for_packed_combat_id(packed)
	return packed


func coop_enet_apply_remote_combat_packed_id(packed: int) -> void:
	if packed < 0:
		return
	_coop_net_seed_global_for_packed_combat_id(packed)


## Monotonic minigame ids for one [method execute_combat] (must match peer call order). Partner mirrors snapshot; no interactive QTE on guest.
var _coop_qte_event_seq: int = 0
var _coop_qte_mirror_active: bool = false
var _coop_qte_mirror_dict: Dictionary = {}
var _coop_qte_capture_active: bool = false
var _coop_qte_capture_dict: Dictionary = {}


func _coop_qte_tick_reset_for_execute_combat() -> void:
	_coop_qte_event_seq = 0


func coop_net_begin_local_combat_qte_capture() -> void:
	_coop_qte_capture_dict.clear()
	_coop_qte_capture_active = true


func coop_net_end_local_combat_qte_capture() -> Dictionary:
	if not _coop_qte_capture_active:
		return {}
	_coop_qte_capture_active = false
	return _coop_qte_capture_dict.duplicate(true)


func coop_net_apply_remote_combat_qte_snapshot(snap: Variant) -> void:
	_coop_qte_mirror_active = true
	_coop_qte_mirror_dict.clear()
	if snap is Dictionary:
		for k in snap.keys():
			_coop_qte_mirror_dict[str(k)] = snap[k]


func coop_net_clear_remote_combat_qte_snapshot() -> void:
	_coop_qte_mirror_active = false
	_coop_qte_mirror_dict.clear()


func _coop_qte_alloc_event_id() -> String:
	var k := str(_coop_qte_event_seq)
	_coop_qte_event_seq += 1
	return k


func _coop_qte_mirror_read_int(event_id: String, default_v: int) -> int:
	if not _coop_qte_mirror_dict.has(event_id):
		return default_v
	return int(_coop_qte_mirror_dict[event_id])


func _coop_qte_mirror_read_bool(event_id: String, default_v: bool) -> bool:
	if not _coop_qte_mirror_dict.has(event_id):
		return default_v
	var v: Variant = _coop_qte_mirror_dict[event_id]
	if v is bool:
		return v
	return int(v) != 0


func _coop_qte_capture_write(event_id: String, value: Variant) -> void:
	if _coop_qte_capture_active:
		_coop_qte_capture_dict[event_id] = value


## Capture alive unit relationship ids (support / Avatar name) before combat for removed-id diffing.
func coop_net_snapshot_alive_unit_ids() -> Dictionary:
	var d: Dictionary = {}
	for cont in [player_container, ally_container, enemy_container]:
		if cont == null:
			continue
		for c in cont.get_children():
			if not c is Node2D:
				continue
			var u: Node2D = c as Node2D
			if not is_instance_valid(u) or u.is_queued_for_deletion():
				continue
			var rid: String = get_relationship_id(u).strip_edges()
			if rid == "":
				continue
			d[rid] = true
	return d


func _coop_clear_unit_grid_solidity(u: Node2D) -> void:
	if u == null or not is_instance_valid(u):
		return
	if u.has_method("get_occupied_tiles"):
		for t in u.get_occupied_tiles(self):
			astar.set_point_solid(t, false)
	else:
		astar.set_point_solid(get_grid_pos(u), false)


func _coop_set_unit_grid_solidity(u: Node2D, solid: bool) -> void:
	if u == null or not is_instance_valid(u):
		return
	if u.has_method("get_occupied_tiles"):
		for t in u.get_occupied_tiles(self):
			astar.set_point_solid(t, solid)
	else:
		astar.set_point_solid(get_grid_pos(u), solid)


## Build after local [method execute_combat] completes; peer applies with [method _coop_apply_authoritative_combat_snapshot] (skips re-simulation).
func coop_net_build_authoritative_combat_snapshot(pre_alive_ids: Dictionary) -> Dictionary:
	var post_alive: Dictionary = {}
	var units_arr: Array = []
	for cont in [player_container, ally_container, enemy_container]:
		if cont == null:
			continue
		for c in cont.get_children():
			if not c is Node2D:
				continue
			var u: Node2D = c as Node2D
			if not is_instance_valid(u) or u.is_queued_for_deletion():
				continue
			if int(u.get("current_hp")) <= 0:
				continue
			var rid: String = get_relationship_id(u).strip_edges()
			if rid == "":
				continue
			post_alive[rid] = true
			var gp: Vector2i = get_grid_pos(u)
			var e: Dictionary = {
				"id": rid,
				"hp": int(u.current_hp),
				"mhp": int(u.max_hp),
				"gx": gp.x,
				"gy": gp.y,
			}
			if u.get("strength") != null:
				e["str"] = int(u.strength)
			if u.get("magic") != null:
				e["mag"] = int(u.magic)
			if u.get("speed") != null:
				e["spd"] = int(u.speed)
			if u.get("agility") != null:
				e["agi"] = int(u.agility)
			if u.get("defense") != null:
				e["def"] = int(u.defense)
			if u.get("resistance") != null:
				e["res"] = int(u.resistance)
			var wpn = u.equipped_weapon
			if wpn != null and wpn.get("current_durability") != null:
				e["wpn_dur"] = int(wpn.current_durability)
			if u.has_meta("ability_cooldown"):
				e["abil_cd"] = int(u.get_meta("ability_cooldown"))
			if u.has_meta("current_poise"):
				e["poise"] = int(u.get_meta("current_poise"))
			if u.has_meta("is_staggered_this_combat"):
				e["stagger"] = bool(u.get_meta("is_staggered_this_combat"))
			if u.get("is_defending") != null:
				e["defending"] = bool(u.is_defending)
			units_arr.append(e)
	var removed: Array = []
	for k in pre_alive_ids.keys():
		if not post_alive.has(k):
			removed.append(str(k))
	return {
		"v": COOP_AUTH_BATTLE_SNAPSHOT_VER,
		"units": units_arr,
		"removed_ids": removed,
		"gold": int(player_gold),
		"ek": int(enemy_kills_count),
		"pd": int(player_deaths_count),
		"ad": int(ally_deaths_count),
		"atc": int(ability_triggers_count),
	}


func _coop_remove_unit_coop_peer_mirror_by_id(rid: String) -> void:
	var r: String = str(rid).strip_edges()
	if r == "":
		return
	var u: Node2D = _coop_find_unit_by_relationship_id_any_side(r)
	if u == null or not is_instance_valid(u) or u.is_queued_for_deletion():
		return
	_coop_clear_unit_grid_solidity(u)
	u.queue_free()


func _coop_apply_authoritative_combat_snapshot(snap: Dictionary) -> void:
	if int(snap.get("v", 0)) != COOP_AUTH_BATTLE_SNAPSHOT_VER:
		if OS.is_debug_build():
			push_warning("Coop: reject authoritative combat snapshot (bad v).")
		return
	enemy_kills_count = int(snap.get("ek", enemy_kills_count))
	player_deaths_count = int(snap.get("pd", player_deaths_count))
	ally_deaths_count = int(snap.get("ad", ally_deaths_count))
	ability_triggers_count = int(snap.get("atc", ability_triggers_count))
	player_gold = int(snap.get("gold", player_gold))

	var removed: Array = snap.get("removed_ids", []) as Array
	for rid_v in removed:
		var rs: String = str(rid_v).strip_edges()
		if rs == "":
			continue
		_coop_remove_unit_coop_peer_mirror_by_id(rs)

	for udat in snap.get("units", []):
		if not udat is Dictionary:
			continue
		var entry: Dictionary = udat
		var rid2: String = str(entry.get("id", "")).strip_edges()
		if rid2 == "":
			continue
		var u2: Node2D = _coop_find_unit_by_relationship_id_any_side(rid2)
		if u2 == null or not is_instance_valid(u2) or u2.is_queued_for_deletion():
			continue
		var gx: int = int(entry.get("gx", get_grid_pos(u2).x))
		var gy: int = int(entry.get("gy", get_grid_pos(u2).y))
		var old_gp: Vector2i = get_grid_pos(u2)
		var new_gp := Vector2i(gx, gy)
		if old_gp != new_gp:
			_coop_clear_unit_grid_solidity(u2)
			u2.position = Vector2(gx * CELL_SIZE.x, gy * CELL_SIZE.y)
			_coop_set_unit_grid_solidity(u2, true)
		if entry.has("hp"):
			u2.current_hp = int(entry["hp"])
		if entry.has("mhp"):
			u2.max_hp = int(entry["mhp"])
		if entry.has("str") and u2.get("strength") != null:
			u2.strength = int(entry["str"])
		if entry.has("mag") and u2.get("magic") != null:
			u2.magic = int(entry["mag"])
		if entry.has("spd") and u2.get("speed") != null:
			u2.speed = int(entry["spd"])
		if entry.has("agi") and u2.get("agility") != null:
			u2.agility = int(entry["agi"])
		if entry.has("def") and u2.get("defense") != null:
			u2.defense = int(entry["def"])
		if entry.has("res") and u2.get("resistance") != null:
			u2.resistance = int(entry["res"])
		var wpn2 = u2.equipped_weapon
		if wpn2 != null and entry.has("wpn_dur") and wpn2.get("current_durability") != null:
			wpn2.current_durability = int(entry["wpn_dur"])
		if entry.has("abil_cd"):
			u2.set_meta("ability_cooldown", int(entry["abil_cd"]))
		elif u2.has_meta("ability_cooldown"):
			u2.remove_meta("ability_cooldown")
		if entry.has("poise"):
			u2.set_meta("current_poise", int(entry["poise"]))
		if entry.has("stagger"):
			u2.set_meta("is_staggered_this_combat", bool(entry["stagger"]))
		if entry.has("defending") and u2.get("is_defending") != null:
			u2.is_defending = bool(entry["defending"])
		if u2.get("health_bar") != null:
			u2.health_bar.value = u2.current_hp
		if u2.has_method("update_poise_visuals"):
			u2.update_poise_visuals()

	rebuild_grid()
	update_fog_of_war()
	update_objective_ui()


## ENet co-op: host allocates [method coop_enet_begin_synchronized_combat_round] + runs combat, then broadcasts; guest waits FIFO and mirrors (crit/miss match).
func coop_enet_buffer_incoming_enemy_combat(body: Dictionary) -> void:
	if body.is_empty():
		return
	_coop_net_incoming_enemy_combat_fifo.append(body.duplicate(true))


func coop_enet_ai_execute_combat(attacker: Node2D, defender: Node2D, used_ability: bool = false) -> void:
	if attacker == null or defender == null or not is_instance_valid(attacker) or not is_instance_valid(defender):
		return
	if not _coop_net_have_battle_seed or not is_mock_coop_unit_ownership_active() or not CoopExpeditionSessionManager.uses_enet_coop_transport():
		await execute_combat(attacker, defender, used_ability)
		return
	if CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.NONE:
		await execute_combat(attacker, defender, used_ability)
		return
	var aid: String = get_relationship_id(attacker).strip_edges()
	var did: String = get_relationship_id(defender).strip_edges()
	if aid == "" or did == "":
		await execute_combat(attacker, defender, used_ability)
		return
	if CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.HOST:
		var pre_enemy: Dictionary = coop_net_snapshot_alive_unit_ids()
		var packed: int = coop_enet_begin_synchronized_combat_round()
		await execute_combat(attacker, defender, used_ability)
		var auth_enemy: Dictionary = coop_net_build_authoritative_combat_snapshot(pre_enemy)
		CoopExpeditionSessionManager.enet_send_coop_battle_sync_action({
			"action": "enemy_combat",
			"attacker_id": aid,
			"defender_id": did,
			"used_ability": used_ability,
			"rng_packed": packed,
			"auth_snapshot": auth_enemy,
			"auth_v": COOP_AUTH_BATTLE_SNAPSHOT_VER,
		})
		return
	## Guest: wait for host-ordered strike packet, then mirror RNG + combat.
	while is_inside_tree():
		if not is_instance_valid(attacker) or not is_instance_valid(defender):
			return
		if not _coop_net_incoming_enemy_combat_fifo.is_empty():
			var head = _coop_net_incoming_enemy_combat_fifo[0]
			var h_aid: String = str(head.get("attacker_id", "")).strip_edges()
			var h_did: String = str(head.get("defender_id", "")).strip_edges()
			if h_aid == aid and h_did == did:
				_coop_net_incoming_enemy_combat_fifo.pop_front()
				var av: int = int(head.get("auth_v", 0))
				var ar: Variant = head.get("auth_snapshot", {})
				if ar is Dictionary and av == COOP_AUTH_BATTLE_SNAPSHOT_VER:
					var ad: Dictionary = ar as Dictionary
					if ad.size() > 0:
						_coop_apply_authoritative_combat_snapshot(ad)
						return
				var rp: int = int(head.get("rng_packed", -1))
				if rp >= 0:
					coop_enet_apply_remote_combat_packed_id(rp)
				await execute_combat(attacker, defender, bool(head.get("used_ability", used_ability)))
				return
			if OS.is_debug_build():
				push_warning("Coop enemy combat FIFO mismatch: expected %s→%s, got %s→%s" % [aid, did, h_aid, h_did])
			_coop_net_incoming_enemy_combat_fifo.pop_front()
			continue
		await get_tree().process_frame


## True when this peer is the ENet guest with battle RNG locked — player-initiated combat must be simulated on the host only.
func coop_enet_should_delegate_player_combat_to_host() -> bool:
	return coop_net_rng_sync_ready() and is_mock_coop_unit_ownership_active() and CoopExpeditionSessionManager.uses_enet_coop_transport() and CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.GUEST


func coop_enet_get_player_side_unit_by_rel_id(rel_id: String) -> Node2D:
	return _coop_find_player_side_unit_by_relationship_id(str(rel_id).strip_edges())


func _coop_emit_guest_host_combat_resolved_if_waiting(aid: String) -> void:
	var a: String = str(aid).strip_edges()
	if _coop_guest_awaiting_combat_aid == "" or _coop_guest_awaiting_combat_aid != a:
		return
	_coop_guest_awaiting_combat_aid = ""
	coop_guest_host_combat_resolved.emit()


## Guest: send combat intent to host, then await authoritative apply + post-combat sync.
func coop_enet_guest_delegate_player_combat_to_host(attacker_id: String, defender_id: String, used_ability: bool) -> void:
	if not coop_enet_should_delegate_player_combat_to_host():
		return
	var aid: String = str(attacker_id).strip_edges()
	var did: String = str(defender_id).strip_edges()
	if aid == "" or did == "":
		return
	_coop_guest_awaiting_combat_aid = aid
	CoopExpeditionSessionManager.enet_send_coop_battle_sync_action({
		"action": "player_combat_request",
		"attacker_id": aid,
		"defender_id": did,
		"used_ability": used_ability,
	})
	while _coop_guest_awaiting_combat_aid != "" and is_inside_tree():
		await coop_guest_host_combat_resolved


func coop_enet_guest_receive_combat_request_nack(body: Dictionary) -> void:
	var aid: String = str(body.get("attacker_id", "")).strip_edges()
	if _coop_guest_awaiting_combat_aid == "":
		return
	if aid != "" and aid != _coop_guest_awaiting_combat_aid:
		return
	_coop_guest_awaiting_combat_aid = ""
	if OS.is_debug_build():
		push_warning("Coop: host rejected player_combat_request (attacker_id=%s)." % aid)
	coop_guest_host_combat_resolved.emit()


func coop_enet_host_handle_player_combat_request(body: Dictionary) -> void:
	call_deferred("_coop_host_start_player_combat_request", body.duplicate(true))


func _coop_host_start_player_combat_request(body: Dictionary) -> void:
	await _coop_host_resolve_player_combat_request_async(body)


func _coop_host_send_player_combat_request_nack(attacker_id: String) -> void:
	if not CoopExpeditionSessionManager.uses_enet_coop_transport():
		return
	if CoopExpeditionSessionManager.phase != CoopExpeditionSessionManager.Phase.HOST:
		return
	CoopExpeditionSessionManager.enet_send_coop_battle_sync_action({
		"action": "player_combat_request_nack",
		"attacker_id": str(attacker_id).strip_edges(),
	})


func _coop_host_resolve_player_combat_request_async(body: Dictionary) -> void:
	if not is_mock_coop_unit_ownership_active() or not CoopExpeditionSessionManager.uses_enet_coop_transport():
		return
	if CoopExpeditionSessionManager.phase != CoopExpeditionSessionManager.Phase.HOST:
		return
	var aid: String = str(body.get("attacker_id", "")).strip_edges()
	var did: String = str(body.get("defender_id", "")).strip_edges()
	var used_ab: bool = bool(body.get("used_ability", false))
	if aid == "" or did == "":
		_coop_host_send_player_combat_request_nack(aid if aid != "" else "?")
		return
	var att: Node2D = _coop_find_unit_by_relationship_id_any_side(aid)
	var defu: Node2D = _coop_find_unit_by_relationship_id_any_side(did)
	if att == null or defu == null or not is_instance_valid(att) or not is_instance_valid(defu):
		_coop_host_send_player_combat_request_nack(aid)
		return
	if get_mock_coop_unit_owner_for_unit(att) != MOCK_COOP_OWNER_REMOTE:
		if OS.is_debug_build():
			push_warning("Coop: player_combat_request ignored — attacker is not guest's unit (%s)." % aid)
		_coop_host_send_player_combat_request_nack(aid)
		return
	var pre_alive: Dictionary = coop_net_snapshot_alive_unit_ids()
	var packed: int = coop_enet_begin_synchronized_combat_round()
	await execute_combat(att, defu, used_ab)
	while is_inside_tree() and get_tree().paused:
		await get_tree().process_frame
	var auth: Dictionary = coop_net_build_authoritative_combat_snapshot(pre_alive)
	var att_after: Node2D = _coop_find_player_side_unit_by_relationship_id(aid)
	var entered_canto: bool = false
	var canto_budget: float = 0.0
	if att_after != null and is_instance_valid(att_after) and int(att_after.current_hp) > 0:
		var used_f: float = float(att_after.move_points_used_this_turn)
		var rem: float = float(att_after.move_range) - used_f
		if unit_supports_canto(att_after) and rem > 0.001:
			entered_canto = true
			canto_budget = rem
			att_after.has_moved = true
			att_after.in_canto_phase = true
			att_after.canto_move_budget = rem
			if battle_log != null and battle_log.visible:
				add_combat_log(att_after.unit_name + " — Canto (" + str(snappedf(rem, 0.1)) + " move left).", "cyan")
			rebuild_grid()
			calculate_ranges(att_after)
	var alive_after: Node2D = null
	if att_after != null and is_instance_valid(att_after) and int(att_after.current_hp) > 0:
		alive_after = att_after
	coop_enet_sync_local_combat_done(aid, did, used_ab, alive_after, entered_canto, canto_budget, packed, {}, auth, true)
	if alive_after != null and is_instance_valid(alive_after) and int(alive_after.current_hp) > 0 and not entered_canto and alive_after.has_method("finish_turn"):
		alive_after.finish_turn()


func _coop_enet_sync_eligible_command_unit(unit: Node2D) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	if not is_mock_coop_unit_ownership_active():
		return false
	if not CoopExpeditionSessionManager.uses_enet_coop_transport():
		return false
	if CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.NONE:
		return false
	if is_local_player_command_blocked_for_mock_coop_unit(unit):
		return false
	return true


func coop_enet_sync_after_local_player_move(unit: Node2D, path: Array, _path_cost: float, finish_after_move: bool = false) -> void:
	if not _coop_enet_sync_eligible_command_unit(unit):
		return
	var uid: String = get_relationship_id(unit).strip_edges()
	if uid == "":
		return
	var serial: Array = []
	for p in path:
		var v: Vector2i = Vector2i.ZERO
		if p is Vector2i:
			v = p as Vector2i
		elif typeof(p) == TYPE_VECTOR2I:
			v = p as Vector2i
		else:
			continue
		serial.append([v.x, v.y])
	if serial.size() < 2:
		return
	var payload: Dictionary = {"action": "player_move", "unit_id": uid, "path": serial}
	if finish_after_move:
		payload["finish_after_move"] = true
	CoopExpeditionSessionManager.enet_send_coop_battle_sync_action(payload)


func coop_enet_sync_after_local_defend(unit: Node2D) -> void:
	if not _coop_enet_sync_eligible_command_unit(unit):
		return
	var uid: String = get_relationship_id(unit).strip_edges()
	if uid == "":
		return
	CoopExpeditionSessionManager.enet_send_coop_battle_sync_action({"action": "player_defend", "unit_id": uid})


## IDs captured before [method execute_combat] so we still notify peer if the attacker dies. Post-combat packet only if [param attacker_after] is still alive.
func coop_enet_sync_local_combat_done(attacker_id: String, defender_id: String, used_ability: bool, attacker_after: Node2D, entered_canto: bool, canto_budget: float, combat_packed_rng_id: int = -1, qte_snapshot: Dictionary = {}, auth_snapshot: Dictionary = {}, combat_host_authority: bool = false) -> void:
	if not is_mock_coop_unit_ownership_active():
		return
	if not CoopExpeditionSessionManager.uses_enet_coop_transport():
		return
	if CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.NONE:
		return
	var aid: String = str(attacker_id).strip_edges()
	var did: String = str(defender_id).strip_edges()
	if aid == "" or did == "":
		return
	var has_followup: bool = attacker_after != null and is_instance_valid(attacker_after) and int(attacker_after.current_hp) > 0
	var combat_body: Dictionary = {
		"action": "player_combat",
		"attacker_id": aid,
		"defender_id": did,
		"used_ability": used_ability,
		"has_post_combat_followup": has_followup,
	}
	if combat_packed_rng_id >= 0:
		combat_body["rng_packed"] = combat_packed_rng_id
	if qte_snapshot.size() > 0:
		combat_body["qte_snapshot"] = qte_snapshot.duplicate(true)
	if auth_snapshot.size() > 0:
		combat_body["auth_snapshot"] = auth_snapshot.duplicate(true)
		combat_body["auth_v"] = COOP_AUTH_BATTLE_SNAPSHOT_VER
	if combat_host_authority:
		combat_body["host_authority"] = true
	CoopExpeditionSessionManager.enet_send_coop_battle_sync_action(combat_body)
	if attacker_after == null or not is_instance_valid(attacker_after) or int(attacker_after.current_hp) <= 0:
		return
	var follow: String = "canto" if entered_canto else "finish"
	var post: Dictionary = {
		"action": "player_post_combat",
		"attacker_id": aid,
		"follow": follow,
		"canto_budget": float(canto_budget),
	}
	if combat_host_authority:
		post["host_authority"] = true
	CoopExpeditionSessionManager.enet_send_coop_battle_sync_action(post)


func coop_enet_sync_after_local_finish_turn(unit: Node2D) -> void:
	if not _coop_enet_sync_eligible_command_unit(unit):
		return
	var uid: String = get_relationship_id(unit).strip_edges()
	if uid == "":
		return
	CoopExpeditionSessionManager.enet_send_coop_battle_sync_action({"action": "player_finish_turn", "unit_id": uid})


func apply_remote_coop_enet_sync(body: Dictionary) -> void:
	if not is_mock_coop_unit_ownership_active():
		return
	_coop_enet_remote_sync_queue.append(body.duplicate(true))
	_coop_enet_pump_remote_sync_queue()


func _coop_enet_pump_remote_sync_queue() -> void:
	if _coop_enet_remote_sync_busy:
		return
	if _coop_enet_remote_sync_queue.is_empty():
		return
	_coop_enet_remote_sync_busy = true
	var next_body: Dictionary = _coop_enet_remote_sync_queue.pop_front() as Dictionary
	var tr := get_tree().create_timer(0.0, true, true, true)
	tr.timeout.connect(func(): _coop_run_one_remote_sync_async(next_body), CONNECT_ONE_SHOT)


func _coop_find_player_side_unit_by_relationship_id(rid: String) -> Node2D:
	var r: String = str(rid).strip_edges()
	if r == "":
		return null
	for cont in [player_container, ally_container]:
		if cont == null:
			continue
		for u in cont.get_children():
			if not is_instance_valid(u):
				continue
			if get_relationship_id(u) == r:
				return u as Node2D
	return null


func _coop_find_unit_by_relationship_id_any_side(rid: String) -> Node2D:
	var u: Node2D = _coop_find_player_side_unit_by_relationship_id(rid)
	if u != null:
		return u
	var r: String = str(rid).strip_edges()
	if r == "" or enemy_container == null:
		return null
	for e in enemy_container.get_children():
		if not is_instance_valid(e):
			continue
		if get_relationship_id(e) == r:
			return e as Node2D
	return null


func _coop_run_one_remote_sync_async(body: Dictionary) -> void:
	var action: String = str(body.get("action", "")).strip_edges()
	match action:
		"player_move":
			await _coop_remote_sync_player_move(body)
		"player_defend":
			await _coop_remote_sync_player_defend(body)
		"player_combat":
			await _coop_remote_sync_player_combat(body)
		"player_post_combat":
			await _coop_remote_sync_player_post_combat(body)
		"player_finish_turn":
			await _coop_remote_sync_player_finish_turn(body)
		_:
			if OS.is_debug_build():
				push_warning("Coop battle sync: unknown action '%s'" % action)
	_coop_enet_remote_sync_busy = false
	_coop_enet_pump_remote_sync_queue()


func _coop_remote_sync_player_move(body: Dictionary) -> void:
	var uid: String = str(body.get("unit_id", "")).strip_edges()
	var path_raw: Variant = body.get("path", [])
	var path_typed: Array[Vector2i] = []
	if path_raw is Array:
		for item in path_raw as Array:
			if item is Array:
				var a: Array = item as Array
				if a.size() >= 2:
					path_typed.append(Vector2i(int(a[0]), int(a[1])))
			elif item is Dictionary:
				var d: Dictionary = item as Dictionary
				path_typed.append(Vector2i(int(d.get("x", 0)), int(d.get("y", 0))))
	if path_typed.size() < 2:
		return
	var unit: Node2D = _coop_find_player_side_unit_by_relationship_id(uid)
	if unit == null or not is_instance_valid(unit):
		if OS.is_debug_build():
			push_warning("Coop battle sync: no unit for id '%s'" % uid)
		return
	if get_mock_coop_unit_owner_for_unit(unit) != MOCK_COOP_OWNER_REMOTE:
		if OS.is_debug_build():
			push_warning("Coop battle sync: refuse mirror move for non-partner unit '%s'" % uid)
		return
	var path_cost: float = get_path_move_cost(path_typed, unit)
	await unit.move_along_path(path_typed)
	if not is_instance_valid(unit) or not is_instance_valid(self):
		return
	unit.move_points_used_this_turn += path_cost
	var unm: String = str(unit.get("unit_name")) if unit.get("unit_name") != null else uid
	if battle_log != null and battle_log.visible:
		add_combat_log("Co-op: %s moved (partner)." % unm, "gray")
	if bool(body.get("finish_after_move", false)) and unit.has_method("finish_turn"):
		unit.finish_turn()
	update_fog_of_war()
	rebuild_grid()
	if current_state == player_state and player_state != null:
		var au: Node2D = player_state.active_unit
		if au != null and au == unit:
			player_state.clear_active_unit()


func _coop_remote_sync_player_defend(body: Dictionary) -> void:
	var uid: String = str(body.get("unit_id", "")).strip_edges()
	var unit: Node2D = _coop_find_player_side_unit_by_relationship_id(uid)
	if unit == null or not is_instance_valid(unit):
		return
	if get_mock_coop_unit_owner_for_unit(unit) != MOCK_COOP_OWNER_REMOTE:
		return
	if defend_sound != null and defend_sound.stream != null:
		defend_sound.pitch_scale = randf_range(0.9, 1.1)
		defend_sound.play()
	unit.trigger_defend()
	animate_shield_drop(unit)
	if battle_log != null and battle_log.visible:
		var unm: String = str(unit.get("unit_name")) if unit.get("unit_name") != null else uid
		add_combat_log("Co-op: %s defended (partner)." % unm, "gray")
	rebuild_grid()
	if current_state == player_state and player_state != null:
		var au: Node2D = player_state.active_unit
		if au != null and au == unit:
			player_state.clear_active_unit()


func _coop_remote_sync_player_combat(body: Dictionary) -> void:
	var aid: String = str(body.get("attacker_id", "")).strip_edges()
	var did: String = str(body.get("defender_id", "")).strip_edges()
	var att: Node2D = _coop_find_unit_by_relationship_id_any_side(aid)
	var defu: Node2D = _coop_find_unit_by_relationship_id_any_side(did)
	if att == null or defu == null or not is_instance_valid(att) or not is_instance_valid(defu):
		if OS.is_debug_build():
			push_warning("Coop battle sync: combat resolve failed ids att=%s def=%s" % [aid, did])
		return
	var owner_att: String = get_mock_coop_unit_owner_for_unit(att)
	var host_auth: bool = bool(body.get("host_authority", false))
	var i_am_guest: bool = CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.GUEST
	var partner_mirror: bool = (owner_att == MOCK_COOP_OWNER_REMOTE)
	var guest_own_host_auth: bool = (host_auth and i_am_guest and owner_att == MOCK_COOP_OWNER_LOCAL)
	if not partner_mirror and not guest_own_host_auth:
		if OS.is_debug_build():
			push_warning("Coop battle sync: refuse combat mirror — attacker ownership mismatch (aid=%s)" % aid)
		return
	var auth_v: int = int(body.get("auth_v", 0))
	var auth_raw: Variant = body.get("auth_snapshot", {})
	var has_auth: bool = auth_raw is Dictionary and auth_v == COOP_AUTH_BATTLE_SNAPSHOT_VER and (auth_raw as Dictionary).size() > 0
	if guest_own_host_auth:
		if not has_auth:
			if OS.is_debug_build():
				push_warning("Coop battle sync: host-authority guest combat requires auth_snapshot")
			return
		_coop_apply_authoritative_combat_snapshot(auth_raw as Dictionary)
		coop_net_clear_remote_combat_qte_snapshot()
		if battle_log != null and battle_log.visible:
			add_combat_log("Co-op: your combat applied (host state).", "gray")
		if not bool(body.get("has_post_combat_followup", true)):
			_coop_emit_guest_host_combat_resolved_if_waiting(aid)
		return
	if has_auth:
		var auth_d: Dictionary = auth_raw as Dictionary
		_coop_apply_authoritative_combat_snapshot(auth_d)
		coop_net_clear_remote_combat_qte_snapshot()
		if battle_log != null and battle_log.visible:
			add_combat_log("Co-op: partner combat applied (host state).", "gray")
		if not bool(body.get("has_post_combat_followup", true)):
			_coop_emit_guest_host_combat_resolved_if_waiting(aid)
		return
	coop_net_apply_remote_combat_qte_snapshot(body.get("qte_snapshot", {}))
	var rp: int = int(body.get("rng_packed", -1))
	if rp >= 0:
		coop_enet_apply_remote_combat_packed_id(rp)
	await execute_combat(att, defu, bool(body.get("used_ability", false)))
	coop_net_clear_remote_combat_qte_snapshot()
	if battle_log != null and battle_log.visible:
		add_combat_log("Co-op: partner combat resolved (%s)." % aid, "gray")


func _coop_remote_sync_player_post_combat(body: Dictionary) -> void:
	var aid: String = str(body.get("attacker_id", "")).strip_edges()
	var att: Node2D = _coop_find_player_side_unit_by_relationship_id(aid)
	if att == null or not is_instance_valid(att):
		return
	var owner_att: String = get_mock_coop_unit_owner_for_unit(att)
	var host_auth: bool = bool(body.get("host_authority", false))
	var i_am_guest: bool = CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.GUEST
	var allow: bool = (owner_att == MOCK_COOP_OWNER_REMOTE) or (host_auth and i_am_guest and owner_att == MOCK_COOP_OWNER_LOCAL)
	if not allow:
		return
	var follow: String = str(body.get("follow", "finish")).strip_edges()
	if follow == "canto":
		var rem: float = float(body.get("canto_budget", 0.0))
		att.has_moved = true
		att.in_canto_phase = true
		att.canto_move_budget = rem
		if battle_log != null and battle_log.visible:
			var who: String = "co-op partner" if owner_att == MOCK_COOP_OWNER_REMOTE else "host"
			add_combat_log(att.unit_name + " — Canto (" + who + ", " + str(snappedf(rem, 0.1)) + " move left).", "cyan")
		calculate_ranges(att)
	elif att.has_method("finish_turn"):
		att.finish_turn()
	rebuild_grid()
	## Do not clear selection during canto — guest may still be commanding this unit after host-authority combat.
	if follow != "canto" and current_state == player_state and player_state != null and player_state.active_unit == att:
		player_state.clear_active_unit()
	if host_auth and i_am_guest:
		_coop_emit_guest_host_combat_resolved_if_waiting(aid)


func _coop_remote_sync_player_finish_turn(body: Dictionary) -> void:
	var uid: String = str(body.get("unit_id", "")).strip_edges()
	var unit: Node2D = _coop_find_player_side_unit_by_relationship_id(uid)
	if unit == null or not is_instance_valid(unit):
		return
	if get_mock_coop_unit_owner_for_unit(unit) != MOCK_COOP_OWNER_REMOTE:
		return
	if unit.has_method("finish_turn"):
		unit.finish_turn()
	if battle_log != null and battle_log.visible:
		var unm: String = str(unit.get("unit_name")) if unit.get("unit_name") != null else uid
		add_combat_log("Co-op: %s waited / ended turn (partner)." % unm, "gray")
	rebuild_grid()
	if current_state == player_state and player_state != null:
		var au: Node2D = player_state.active_unit
		if au != null and au == unit:
			player_state.clear_active_unit()


## Drops selection if active_unit somehow points at a partner-owned unit (mock co-op only). Skips while forecasting to avoid tearing an in-flight forecast await.
func _sanitize_player_phase_active_unit_for_mock_coop_ownership() -> void:
	if current_state != player_state or player_state == null:
		return
	if player_state.is_forecasting:
		return
	var au: Node2D = player_state.active_unit
	if au == null or not is_instance_valid(au):
		return
	if not is_local_player_command_blocked_for_mock_coop_unit(au):
		return
	player_state.clear_active_unit()


## One-line BBCode for unit stats panel when mock co-op ownership applies; empty otherwise.
func _mock_coop_unit_ownership_bbcode_line_for_panel(unit: Node2D) -> String:
	if unit == null or not is_instance_valid(unit):
		return ""
	if not is_mock_coop_unit_ownership_active():
		return ""
	if not _is_friendly_unit_on_field(unit):
		return ""
	var o: String = get_mock_coop_unit_owner_for_unit(unit)
	if o == MOCK_COOP_OWNER_REMOTE:
		return "[color=orange][b]Partner Unit[/b][/color] (co-op)\n"
	if o == MOCK_COOP_OWNER_LOCAL:
		return "[color=cyan][b]Your Unit[/b][/color] (co-op)\n"
	return ""


## Mock co-op + player phase: fielded local/partner counts (valid=false otherwise).
func _get_mock_coop_player_phase_detachment_counts() -> Dictionary:
	var out: Dictionary = {"valid": false, "local_total": 0, "local_ready": 0, "partner_fielded": 0}
	if not is_mock_coop_unit_ownership_active() or current_state != player_state:
		return out
	out["valid"] = true
	var total: int = 0
	var ready: int = 0
	var partner_fielded: int = 0
	for cont in [player_container, ally_container]:
		if cont == null:
			continue
		for u in cont.get_children():
			if not is_instance_valid(u) or u.is_queued_for_deletion():
				continue
			if u.get("current_hp") == null or int(u.current_hp) <= 0:
				continue
			if not _is_mock_coop_deployed_player_side_unit(u):
				continue
			var own: String = get_mock_coop_unit_owner_for_unit(u)
			if own == MOCK_COOP_OWNER_LOCAL:
				total += 1
				if u.get("is_exhausted") == false:
					ready += 1
			elif own == MOCK_COOP_OWNER_REMOTE:
				partner_fielded += 1
	out["local_total"] = total
	out["local_ready"] = ready
	out["partner_fielded"] = partner_fielded
	return out


## True when mock co-op player phase: all local fielded units have acted, partner fielded units remain (placeholder partner-turn gate).
func is_mock_partner_placeholder_active() -> bool:
	if not is_mock_coop_unit_ownership_active() or current_state != player_state:
		return false
	var c: Dictionary = _get_mock_coop_player_phase_detachment_counts()
	if not bool(c.get("valid", false)):
		return false
	var lt: int = int(c.get("local_total", 0))
	var lr: int = int(c.get("local_ready", 0))
	var pf: int = int(c.get("partner_fielded", 0))
	return lt > 0 and lr == 0 and pf > 0


func _process_mock_partner_placeholder_frame() -> void:
	if not is_mock_partner_placeholder_active():
		_mock_partner_placeholder_combat_log_done = false
		return
	if player_state != null and player_state.is_forecasting:
		player_state.is_forecasting = false
		player_state.targeted_enemy = null
		_on_forecast_cancel()
	if player_state != null and player_state.active_unit != null:
		player_state.clear_active_unit()
	if _mock_partner_placeholder_combat_log_done:
		return
	_mock_partner_placeholder_combat_log_done = true
	if battle_log != null and battle_log.visible:
		add_combat_log("Mock co-op: awaiting ally orders (placeholder). Use End / Skip phase to continue.", "gold")


## Player phase only: BBCode for objective panel — local-owned, fielded, alive units; ready = not is_exhausted.
func _build_mock_coop_player_phase_readiness_bbcode_suffix() -> String:
	var c: Dictionary = _get_mock_coop_player_phase_detachment_counts()
	if not bool(c.get("valid", false)):
		return ""
	var total: int = int(c.get("local_total", 0))
	var ready: int = int(c.get("local_ready", 0))
	var partner_fielded: int = int(c.get("partner_fielded", 0))
	if total <= 0:
		return ""
	var s: String = "\n[color=cyan][b]Co-op — Your units ready: %d / %d[/b][/color]" % [ready, total]
	if ready == 0:
		s += "\n[color=gray][font_size=16]All your fielded units have acted this phase.[/font_size][/color]"
		if partner_fielded > 0:
			s += "\n[color=orange][font_size=16]Partner detachment still on the field — not under your command. End or Skip phase when you are ready.[/font_size][/color]"
			s += "\n[color=gold][b]Awaiting ally orders[/b][/color] [color=gray](mock co-op placeholder)[/color]\n"
	return s + "\n"


func _update_mock_coop_skip_button_highlight() -> void:
	var btn: Button = get_node_or_null("UI/SkipButton") as Button
	if btn == null:
		return
	if not _skip_button_base_modulate_captured:
		_skip_button_base_modulate = btn.modulate
		_skip_button_base_modulate_captured = true
	var want: bool = is_mock_partner_placeholder_active()
	if want == _mock_coop_skip_button_glow_active:
		return
	_mock_coop_skip_button_glow_active = want
	if want:
		btn.modulate = _skip_button_base_modulate * Color(1.14, 1.12, 0.96, 1.0)
	else:
		btn.modulate = _skip_button_base_modulate


func _is_mock_coop_deployed_player_side_unit(unit: Node) -> bool:
	if unit == null or not is_instance_valid(unit) or unit.is_queued_for_deletion():
		return false
	if unit is CanvasItem and not (unit as CanvasItem).visible:
		return false
	if unit.process_mode == Node.PROCESS_MODE_DISABLED:
		return false
	return true


func _get_mock_coop_deployed_player_side_unit_nodes() -> Array:
	var out: Array = []
	if player_container != null:
		for u in player_container.get_children():
			if _is_mock_coop_deployed_player_side_unit(u):
				out.append(u)
	if ally_container != null:
		for u in ally_container.get_children():
			if _is_mock_coop_deployed_player_side_unit(u):
				out.append(u)
	return out


## All player-side units in tree order (player_container then ally_container), including benched/hidden — for locked mock co-op meta.
func _iter_all_player_side_unit_nodes_for_mock_coop() -> Array:
	var out: Array = []
	for cont in [player_container, ally_container]:
		if cont == null:
			continue
		for u in cont.get_children():
			if u == null or not is_instance_valid(u) or u.is_queued_for_deletion():
				continue
			out.append(u)
	return out


func _strip_mock_coop_ownership_meta_from_player_side() -> void:
	for cont in [player_container, ally_container]:
		if cont == null:
			continue
		for u in cont.get_children():
			if is_instance_valid(u) and u.has_meta(MOCK_COOP_BATTLE_OWNER_META):
				u.remove_meta(MOCK_COOP_BATTLE_OWNER_META)
				if u.has_method("refresh_standard_team_glow"):
					u.refresh_standard_team_glow()


func _apply_mock_coop_ownership_visuals() -> void:
	if _mock_coop_ownership_assignments.is_empty():
		return
	for cont in [player_container, ally_container]:
		if cont == null:
			continue
		for u in cont.get_children():
			if not is_instance_valid(u):
				continue
			var own: String = get_mock_coop_unit_owner_for_unit(u)
			if own == "":
				continue
			if u.has_method("apply_mock_coop_owner_visual"):
				u.apply_mock_coop_owner_visual(own)


## Applies charter-locked detachment from handoff when valid; otherwise explicit deprecated fallback (visible fielded order only).
func _assign_mock_coop_unit_ownership_from_context() -> void:
	_strip_mock_coop_ownership_meta_from_player_side()
	_mock_coop_ownership_assignments.clear()
	if _mock_coop_battle_context == null or not _mock_coop_battle_context.context_valid:
		if _mock_coop_battle_context != null and _mock_coop_battle_context.active:
			print("[MockCoopOwnership] skipped (mock context not valid — no unit ownership assigned)")
		return
	var assign_raw: Variant = _consumed_mock_coop_battle_handoff.get("mock_detachment_assignment", {})
	if typeof(assign_raw) == TYPE_DICTIONARY and not (assign_raw as Dictionary).is_empty() and _mock_coop_battle_context.has_locked_mock_detachment_assignment():
		_apply_mock_coop_locked_detachment_assignment(assign_raw as Dictionary)
		return
	push_warning("[MockCoopOwnership] mock_detachment_assignment missing or not locked — using DEPRECATED fielded visible-unit order fallback.")
	_assign_mock_coop_unit_ownership_fielded_order_fallback_deprecated()


func _apply_mock_coop_locked_detachment_assignment(assign: Dictionary) -> void:
	var loc_a: Variant = assign.get("local_command_unit_ids", [])
	var par_a: Variant = assign.get("partner_command_unit_ids", [])
	var local_set: Dictionary = {}
	var partner_set: Dictionary = {}
	if typeof(loc_a) == TYPE_ARRAY:
		for x in loc_a as Array:
			local_set[str(x).strip_edges()] = true
	if typeof(par_a) == TYPE_ARRAY:
		for x in par_a as Array:
			partner_set[str(x).strip_edges()] = true
	var units: Array = _iter_all_player_side_unit_nodes_for_mock_coop()
	if units.is_empty():
		print("[MockCoopOwnership] locked assignment: no player-side unit nodes")
		return
	var deploy_index: int = 0
	for u in units:
		var rid: String = get_relationship_id(u)
		var owner_s: String
		if local_set.has(rid):
			owner_s = MOCK_COOP_OWNER_LOCAL
		elif partner_set.has(rid):
			owner_s = MOCK_COOP_OWNER_REMOTE
		else:
			owner_s = MOCK_COOP_OWNER_REMOTE
			print("[MockCoopOwnership] unlisted id '%s' — PARTNER command (not in charter lock)" % rid)
		u.set_meta(MOCK_COOP_BATTLE_OWNER_META, owner_s)
		var uname: String = str(u.get("unit_name")) if u.get("unit_name") != null else str(u.name)
		var src: String = "player" if u.get_parent() == player_container else "ally"
		_mock_coop_ownership_assignments.append({
			"unit_path": str(u.get_path()),
			"unit_name": uname,
			"container": src,
			"owner": owner_s,
			"deploy_order_index": deploy_index,
		})
		deploy_index += 1
	_apply_mock_coop_ownership_visuals()
	var local_names: PackedStringArray = PackedStringArray()
	var remote_names: PackedStringArray = PackedStringArray()
	for a in _mock_coop_ownership_assignments:
		if str(a.get("owner", "")) == MOCK_COOP_OWNER_LOCAL:
			local_names.append(str(a.get("unit_name", "?")))
		else:
			remote_names.append(str(a.get("unit_name", "?")))
	add_combat_log("Mock co-op command (local): %s" % ", ".join(local_names), "cyan")
	add_combat_log("Mock co-op command (remote partner): %s" % ", ".join(remote_names), "gold")
	print("[MockCoopOwnership] rule=charter_locked_detachment units=%d %s" % [units.size(), str(_mock_coop_ownership_assignments)])


## Deprecated: visible fielded units only, first ceil(n/2) local — used only when handoff lacks a valid locked assignment.
func _assign_mock_coop_unit_ownership_fielded_order_fallback_deprecated() -> void:
	var units: Array = _get_mock_coop_deployed_player_side_unit_nodes()
	var n: int = units.size()
	if n == 0:
		print("[MockCoopOwnership] no deployed player-side units to assign (fallback)")
		return
	var local_n: int = (n + 1) / 2
	for i in range(n):
		var u: Node = units[i]
		var owner_s: String = MOCK_COOP_OWNER_LOCAL if i < local_n else MOCK_COOP_OWNER_REMOTE
		u.set_meta(MOCK_COOP_BATTLE_OWNER_META, owner_s)
		var uname: String = str(u.get("unit_name")) if u.get("unit_name") != null else str(u.name)
		var src: String = "player" if u.get_parent() == player_container else "ally"
		_mock_coop_ownership_assignments.append({
			"unit_path": str(u.get_path()),
			"unit_name": uname,
			"container": src,
			"owner": owner_s,
			"deploy_order_index": i,
		})
	_apply_mock_coop_ownership_visuals()
	var local_names: PackedStringArray = PackedStringArray()
	var remote_names: PackedStringArray = PackedStringArray()
	for a in _mock_coop_ownership_assignments:
		if str(a.get("owner", "")) == MOCK_COOP_OWNER_LOCAL:
			local_names.append(str(a.get("unit_name", "?")))
		else:
			remote_names.append(str(a.get("unit_name", "?")))
	add_combat_log("Mock co-op command (local): %s" % ", ".join(local_names), "cyan")
	add_combat_log("Mock co-op command (remote partner): %s" % ", ".join(remote_names), "gold")
	print("[MockCoopOwnership] DEPRECATED_FALLBACK rule=first_half_local_ceil_fielded total=%d local_slots=%d %s" % [n, local_n, str(_mock_coop_ownership_assignments)])


## Visible battle-start UX for mock co-op only (combat log charter). No-op if no active context.
func _present_mock_coop_joint_expedition_charter() -> void:
	if _mock_coop_battle_context == null or not _mock_coop_battle_context.active:
		return
	var ctx: MockCoopBattleContext = _mock_coop_battle_context
	var exp_title: String = ctx.get_expedition_display_title()
	var loc: String = ctx.get_local_participant_label()
	var rem: String = ctx.get_remote_participant_label()
	var role_cap: String = ctx.local_role.capitalize()
	if ctx.context_valid:
		add_combat_log("──────── Joint Expedition Charter (Mock Co-op) ────────", "gold")
		add_combat_log("Expedition: %s" % exp_title, "cyan")
		add_combat_log("Commanders: %s  ·  %s" % [loc, rem], "cyan")
		add_combat_log("Your role: %s" % role_cap, "cyan")
		add_combat_log("Shared contract — this sortie is fought together.", "gray")
	else:
		add_combat_log("──────── Joint Expedition Charter (incomplete data) ────────", "orange")
		add_combat_log("Expedition: %s — verify session before relying on co-op data." % exp_title, "yellow")
		add_combat_log("Commanders: %s  ·  %s  |  Your role: %s" % [loc, rem, role_cap], "yellow")
		add_combat_log("Issues: %s" % str(ctx.validation_errors), "orange")

var _ui_sfx_block_until_msec := 0

func _ready() -> void:
	# 1. SETUP ASTAR GRID
	astar.region = Rect2i(0, 0, GRID_SIZE.x, GRID_SIZE.y)
	astar.cell_size = CELL_SIZE
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	
	# 1B. SETUP FLYING ASTAR GRID
	flying_astar.region = Rect2i(0, 0, GRID_SIZE.x, GRID_SIZE.y)
	flying_astar.cell_size = CELL_SIZE
	flying_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	flying_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	flying_astar.update()
	
	# 2. INITIALIZE STATES
	player_state = PlayerTurnState.new()
	ally_state = AITurnState.new("ally")
	enemy_state = AITurnState.new("enemy")
	pre_battle_state = PreBattleState.new()
	
	ally_state.turn_finished.connect(_on_ally_turn_finished)
	enemy_state.turn_finished.connect(_on_enemy_turn_finished)
	
	# 3. CONNECT SIGNALS (For units already in the scene)
	if player_container:
		for u in player_container.get_children():
			u.died.connect(_on_unit_died)
			u.leveled_up.connect(_on_unit_leveled_up)
			
	if ally_container:
		for a in ally_container.get_children():
			a.died.connect(_on_unit_died)
			a.leveled_up.connect(_on_unit_leveled_up)
			
	if enemy_container:
		for e in enemy_container.get_children():
			e.died.connect(_on_unit_died)
			e.leveled_up.connect(_on_unit_leveled_up)

	# 4. UI CONNECTIONS
	trade_popup_btn.pressed.connect(_on_trade_popup_confirm)
	trade_close_btn.pressed.connect(_on_trade_window_close)
	trade_left_list.item_selected.connect(func(idx): _on_trade_item_clicked(idx, "left"))
	trade_right_list.item_selected.connect(func(idx): _on_trade_item_clicked(idx, "right"))
	$UI/CombatForecastPanel/ConfirmButton.pressed.connect(_on_forecast_confirm)
	$UI/CombatForecastPanel/CancelButton.pressed.connect(_on_forecast_cancel)
	if forecast_talk_btn:
		forecast_talk_btn.pressed.connect(_on_forecast_talk)
	if forecast_ability_btn:
		forecast_ability_btn.pressed.connect(_on_forecast_ability_pressed)
	convoy_button.pressed.connect(_on_convoy_pressed)
	open_inv_button.pressed.connect(_on_open_inv_pressed)
	$UI/InventoryPanel/EquipButton.pressed.connect(_on_equip_pressed)
	$UI/InventoryPanel/CloseButton.pressed.connect(_on_close_inv_pressed)
	$UI/InventoryPanel/UseButton.pressed.connect(_on_use_pressed)
	close_loot_button.pressed.connect(_on_close_loot_pressed)
	loot_item_list.fixed_icon_size = Vector2i(64, 64)
	trade_left_list.fixed_icon_size = Vector2i(32, 32)
	trade_right_list.fixed_icon_size = Vector2i(32, 32)
	loot_item_list.item_selected.connect(_on_loot_item_selected)
	if popup_talk_btn: popup_talk_btn.pressed.connect(_on_support_talk_pressed)
	if talk_next_btn: talk_next_btn.pressed.connect(func(): emit_signal("dialogue_advanced"))
	if support_btn: support_btn.pressed.connect(_on_support_btn_pressed)
	if close_support_btn: close_support_btn.pressed.connect(func(): support_tracker_panel.visible = false)
	if main_camera != null:
		_camera_zoom_target = main_camera.zoom.x
		
	_ensure_forecast_support_labels()

	# 4B. Phase 2 support reactions: reset battle-local Defy Death tracking (once per unit per battle).
	_defy_death_used.clear()
	_grief_units.clear()
	_relationship_event_awarded.clear()
	_enemy_damagers.clear()
	# Boss Personal Dialogue: reset one-time pre-attack tracking per battle.
	_boss_personal_dialogue_played.clear()

	# 5. ENVIRONMENT CONNECTIONS
	if destructibles_container:
		for d in destructibles_container.get_children():
			# THE FIX: Only connect the signal if the object actually has one!
			if d.has_signal("died"):
				d.died.connect(_on_destructible_died)
			
	# Note: We set chest solidity later in rebuild_grid, but we can do a safety check here
	if chests_container:
		for c in chests_container.get_children():
			if not c.is_queued_for_deletion() and c.is_locked: 
				astar.set_point_solid(get_grid_pos(c), true)

	# 6. AUDIO SETTINGS
	if select_sound: select_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	if epic_level_up_sound: epic_level_up_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	if level_up_sound: level_up_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	if crit_sound: crit_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	if miss_sound: miss_sound.process_mode = Node.PROCESS_MODE_ALWAYS				
	
	# 7. LOAD SAVE DATA (Restores Player Stats)
	if CampaignManager.player_roster.is_empty():
		# Direct Scene Start (F6) Debugging
		var test_path = CampaignManager.get_save_path(1)
		if FileAccess.file_exists(test_path):
			print("Direct Scene Start detected. Loading existing save data from Slot 1...")
			CampaignManager.load_game(1)
			
	load_campaign_data()
	apply_campaign_settings()

	_mock_coop_battle_context = null
	_mock_coop_ownership_assignments.clear()
	_consumed_mock_coop_battle_handoff = CampaignManager.consume_pending_mock_coop_battle_handoff()
	if not _consumed_mock_coop_battle_handoff.is_empty():
		_mock_coop_battle_context = MockCoopBattleContext.from_consumed_handoff(_consumed_mock_coop_battle_handoff)
		if _mock_coop_battle_context != null:
			var ctx_line: String = _mock_coop_battle_context.get_debug_summary_line()
			print("[MockCoopBattleContext] %s snapshot=%s" % [ctx_line, str(_mock_coop_battle_context.get_snapshot())])
		print("[MockCoopHandoff] battle start keys=%s" % str(_consumed_mock_coop_battle_handoff.keys()))
		_present_mock_coop_joint_expedition_charter()
		_assign_mock_coop_unit_ownership_from_context()
		if is_mock_coop_unit_ownership_active() and CoopExpeditionSessionManager.uses_enet_coop_transport() and CoopExpeditionSessionManager.phase != CoopExpeditionSessionManager.Phase.NONE:
			CoopExpeditionSessionManager.register_enet_coop_battle_sync_battlefield(self)
			CoopExpeditionSessionManager.enet_try_publish_coop_battle_rng_seed()
	
	# --- INITIALIZE FOG OF WAR ---
	if use_fog_of_war:
		fog_drawer = Node2D.new()
		fog_drawer.z_index = 80 
		fog_drawer.name = "FogDrawer"
		
		# THE MAGIC BULLET: Force Godot to aggressively blur the texture!
		fog_drawer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		
		fog_drawer.draw.connect(_on_fog_draw)
		add_child(fog_drawer)
		
		# Create a tiny image where 1 Pixel = 1 Grid Cell
		fow_image = Image.create(GRID_SIZE.x, GRID_SIZE.y, false, Image.FORMAT_RGBA8)
		
		for x in range(GRID_SIZE.x):
			for y in range(GRID_SIZE.y):
				var p = Vector2i(x, y)
				fow_grid[p] = 0 
				fow_display_alphas[p] = 0.85 
				# Color the pixel dark blue-black
				fow_image.set_pixel(x, y, Color(0.05, 0.05, 0.1, 0.85))
				
		# Convert the image into a texture we can draw
		fow_texture = ImageTexture.create_from_image(fow_image)

	# 8. --- SKIRMISH LOGIC ---
	# is_skirmish_mode is also set for expedition runs (world-map return routing). Those use story scenes
	# with pre-placed enemies — do NOT run random undead spawn (requires enemy_scene in inspector).
	if CampaignManager.is_skirmish_mode and not CampaignManager.is_expedition_run:
		setup_skirmish_battle()
		_reset_rookie_battle_tracking()

	if CampaignManager.is_expedition_run:
		var exp_mod_line: String = CampaignManager.get_active_expedition_modifier_display_line()
		if exp_mod_line != "":
			add_combat_log(exp_mod_line, "cyan")

	# --- ARENA LOGIC ---
	if ArenaManager.current_opponent_data.size() > 0:
		is_arena_match = true
		setup_arena_battle()
		_reset_rookie_battle_tracking()

	# ==========================================
	# --- VIP ESCORT VICTORY CHECK ---
	# ==========================================
	if map_objective == Objective.DEFEND_TARGET and is_instance_valid(vip_target):
		if vip_target.has_signal("reached_destination"):
			# When the Donkey shouts that it arrived, trigger the victory!
			vip_target.reached_destination.connect(func(): 
				if has_method("add_combat_log"):
					add_combat_log("MISSION ACCOMPLISHED: The convoy escaped!", "lime")
				if _battle_resonance_allowed():
					CampaignManager.mark_battle_resonance("protected_civilians_first")
				_trigger_victory() # <--- CHANGED!
			)
			
	# ==========================================
	# --- BASE DEFENSE HIJACK ---
	# ==========================================
	if CampaignManager.is_base_defense_active:
		print("--- INITIALIZING DATA-DRIVEN SIEGE ---")
		map_objective = Objective.ROUT_ENEMY
		custom_objective_text = "Survive the Siege"
		
		intro_dialogue.clear()
		outro_dialogue.clear()
		
		if is_instance_valid(vip_target) and not vip_target.is_queued_for_deletion():
			vip_target.queue_free()
			vip_target = null
			
		if skirmish_music != null and has_node("LevelMusic"):
			var audio = get_node("LevelMusic")
			audio.stream = skirmish_music
			audio.play()

		# 1. Clear existing map enemies
		for child in enemy_container.get_children():
			child.queue_free()
		
		# --- CLEAR LEFTOVER STORY SPAWNERS ---
		if destructibles_container != null:
			for d in destructibles_container.get_children():
				# If it's a spawner and it belongs to the enemy (faction 0), vaporize it!
				if d.has_method("process_turn") and d.get("spawner_faction") == 0:
					d.queue_free()
			
		# 2. Retrieve the scaling level directly from the CampaignManager
		var max_roster_level = CampaignManager.get_highest_garrison_level()
				
		# 3. Select the correct .tres file based on the highest level
		var chosen_data_path = "res://Resources/Units/LowLevelBandit.tres" # Default fallback
		
		if max_roster_level >= 12:
			chosen_data_path = "res://Resources/Units/HulkingOrc.tres"
		elif max_roster_level >= 10:
			chosen_data_path = "res://Resources/Units/EtherealImp.tres"
		elif max_roster_level >= 5:
			chosen_data_path = "res://Resources/Units/ArmoredMercenary.tres"
			
		var loaded_unit_data = load(chosen_data_path)
		if loaded_unit_data == null:
			push_warning("Siege unit data path invalid. Check your .tres file locations.")
			return
			
		# 4. Find all valid map edge coordinates
		var edge_tiles = []
		for x in range(GRID_SIZE.x):
			edge_tiles.append(Vector2i(x, 0))
			edge_tiles.append(Vector2i(x, GRID_SIZE.y - 1))
		for y in range(1, GRID_SIZE.y - 1):
			edge_tiles.append(Vector2i(0, y))
			edge_tiles.append(Vector2i(GRID_SIZE.x - 1, y))
			
		edge_tiles.shuffle()
		
# 5. Spawn the enemies and inject the data
		var spawn_count = randi_range(6, 9)
		var spawned = 0
		
		for pos in edge_tiles:
			if spawned >= spawn_count: break
			
			if not astar.is_point_solid(pos) and get_unit_at(pos) == null:
				
				# --- THE CRASH FIX: Use player_unit_scene instead of enemy_scene ---
				if player_unit_scene == null:
					push_warning("CRITICAL: player_unit_scene is not assigned in the Inspector.")
					return
					
				var enemy = player_unit_scene.instantiate()
				
				# Force the unit to act as an enemy
				if "team" in enemy: enemy.team = 1
				if "is_enemy" in enemy: enemy.is_enemy = true
				
				enemy.position = Vector2(pos.x * CELL_SIZE.x, pos.y * CELL_SIZE.y)
				enemy_container.add_child(enemy)
				
				# Connect critical signals
				if not enemy.died.is_connected(_on_unit_died):
					enemy.died.connect(_on_unit_died)
				if not enemy.leveled_up.is_connected(_on_unit_leveled_up):
					enemy.leveled_up.connect(_on_unit_leveled_up)
				
				# --- DATA INJECTION ---
				enemy.data = loaded_unit_data.duplicate(true)
				enemy.level = max_roster_level
				enemy.unit_name = enemy.data.get("unit_name") if enemy.data.get("unit_name") != null else "Raider"
				enemy.set("is_custom_avatar", false)
				
				var base_hp = enemy.data.get("max_hp") if enemy.data.get("max_hp") != null else 20
				var base_str = enemy.data.get("strength") if enemy.data.get("strength") != null else 5
				var base_def = enemy.data.get("defense") if enemy.data.get("defense") != null else 3
				var base_spd = enemy.data.get("speed") if enemy.data.get("speed") != null else 4
				
				enemy.max_hp = base_hp + (max_roster_level * 2)
				enemy.current_hp = enemy.max_hp
				enemy.strength = base_str + int(max_roster_level * 0.8)
				enemy.defense = base_def + int(max_roster_level * 0.5)
				enemy.speed = base_spd + int(max_roster_level * 0.5)
				
				if enemy.get("health_bar") != null:
					enemy.health_bar.max_value = enemy.max_hp
					enemy.health_bar.value = enemy.current_hp
				
				var spr = enemy.get_node_or_null("Sprite")
				if spr == null: spr = enemy.get_node_or_null("Sprite2D")
				if spr and enemy.data.get("unit_sprite") != null:
					spr.texture = enemy.data.unit_sprite
					
				# --- THE STRICT TYPING FIX ---
				# We explicitly declare an Array[Resource] so Godot doesn't crash
				var strict_inventory: Array[Resource] = []
				
				if enemy.data.get("starting_weapon") != null:
					enemy.equipped_weapon = enemy.data.starting_weapon.duplicate(true)
					strict_inventory.append(enemy.equipped_weapon)
				else:
					var wpn = WeaponData.new()
					wpn.weapon_name = "Siege Blade"
					wpn.might = 5 + int(max_roster_level * 0.5)
					wpn.hit_bonus = 10
					wpn.min_range = 1
					wpn.max_range = 1
					enemy.equipped_weapon = wpn
					strict_inventory.append(wpn)
					
				# Assign the strictly typed array back to the unit
				enemy.inventory = strict_inventory
				
				enemy.ai_behavior = 2 
				spawned += 1
			
	# 9. REBUILD GRID (Moved to END so it accounts for Skirmish Spawns)
	rebuild_grid()
	_setup_objective_ui()
	update_fog_of_war()
	
	# 10. START GAME
	$UI/StartBattleButton.pressed.connect(_on_start_battle_pressed)
	
	# Wait a fraction of a second so the map renders, then start the Cinematic!
	get_tree().create_timer(0.6).timeout.connect(_start_intro_sequence)
	
func _process(delta: float) -> void:
	update_cursor_pos()
	update_cursor_color()
	update_unit_info_panel()
	_sanitize_player_phase_active_unit_for_mock_coop_ownership()
	if is_mock_coop_unit_ownership_active() and current_state == player_state:
		update_objective_ui(true)
	_process_mock_partner_placeholder_frame()
	_update_mock_coop_skip_button_highlight()
	_handle_camera_panning(delta)
	
	# === ADD THIS LINE ===
	_process_fog(delta)
	# =====================

	if _danger_zone_recalc_dirty:
		_danger_zone_recalc_dirty = false
		if show_danger_zone:
			calculate_full_danger_zone()
	
	if current_state:
		current_state.update(delta)
		
	draw_preview_path()
	queue_redraw()

func _handle_camera_panning(delta: float) -> void:
	# Allow panning during player phase and pre-battle deployment so the player can look around the map.
	if current_state != player_state and current_state != pre_battle_state:
		return

	var viewport_size = get_viewport().get_visible_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
	var move_vec = Vector2.ZERO

	# Check Left/Right edges
	if mouse_pos.x < edge_margin:
		move_vec.x = -1
	elif mouse_pos.x > viewport_size.x - edge_margin:
		move_vec.x = 1

	# Check Top/Bottom edges
	if mouse_pos.y < edge_margin:
		move_vec.y = -1
	elif mouse_pos.y > viewport_size.y - edge_margin:
		move_vec.y = 1

	# Apply movement to the camera node
	if move_vec != Vector2.ZERO:
		main_camera.position += move_vec.normalized() * CampaignManager.camera_pan_speed * delta
		
		# --- ALLOW NEGATIVE PANNING ---
		# How many pixels past the map edge the camera is allowed to go
		var extra_scroll_margin = 400 
		
		var map_limit_x = GRID_SIZE.x * CELL_SIZE.x
		var map_limit_y = GRID_SIZE.y * CELL_SIZE.y
		
		# Clamp between negative margin and max limit + margin
		main_camera.position.x = clamp(main_camera.position.x, -extra_scroll_margin, map_limit_x + extra_scroll_margin)
		main_camera.position.y = clamp(main_camera.position.y, -extra_scroll_margin, map_limit_y + extra_scroll_margin)

func _unhandled_input(event: InputEvent) -> void:
	# --- Mouse wheel zoom ---
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_camera_zoom(-1) # zoom in
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_camera_zoom(1)  # zoom out
			return	
	# --- MINIMAP TOGGLE ---
	if event.is_action_pressed("toggle_minimap"):
		_toggle_minimap()
		get_viewport().set_input_as_handled() # Stop other things from reacting to 'M'
	
	if current_state:
		current_state.handle_input(event)

func change_state(new_state: GameState) -> void:
	if current_state:
		current_state.exit()
		
	current_state = null 
	
	if new_state == player_state:
		await show_phase_banner("PLAYER PHASE", Color(0.4, 0.6, 0.9))
		await _process_spawners(2) # <--- ADDED AWAIT
		
	elif new_state == ally_state:
		await show_phase_banner("ALLY PHASE", Color(0.4, 0.8, 0.5))
		await _process_spawners(1) # <--- ADDED AWAIT
		
		# --- ESCORT CONVOY LOGIC ---
		if map_objective == Objective.DEFEND_TARGET and is_instance_valid(vip_target):
			if vip_target.has_method("process_escort_turn"):
				var target_cam_pos = vip_target.global_position + Vector2(32, 32) 
				if main_camera.anchor_mode == Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT:
					var half_vp_world = (get_viewport_rect().size * 0.5) / main_camera.zoom
					target_cam_pos -= half_vp_world
					
				var c_tween = create_tween()
				c_tween.tween_property(main_camera, "global_position", target_cam_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				await c_tween.finished
				await get_tree().create_timer(0.3).timeout
				
				vip_target.process_escort_turn(self)
				await vip_target.turn_completed 
				_clamp_camera_position()
				await get_tree().create_timer(0.5).timeout
				
	elif new_state == enemy_state:
		await show_phase_banner("ENEMY PHASE", Color(0.85, 0.3, 0.3))
		await _process_spawners(0) # <--- ADDED AWAIT
		
	current_state = new_state
	if current_state:
		current_state.enter(self)
				
func _process_spawners(faction_id: int) -> void:
	if destructibles_container:
		for child in destructibles_container.get_children():
			if child.has_method("process_turn") and not child.is_queued_for_deletion():
				# <--- ADDED AWAIT SO IT WAITS FOR THE CINEMATIC TO FINISH!
				await child.process_turn(self, faction_id)
						
func _on_skip_button_pressed() -> void:
	if current_state == player_state:
		
		# --- QOL: AUTO-DEFEND UNUSED UNITS ---
		var auto_defended_anyone = false
		
		# Loop through all player units on the board
		if player_container != null:
			for u in player_container.get_children():
				# If they are alive and haven't finished their turn yet...
				if is_instance_valid(u) and not u.is_queued_for_deletion() and u.current_hp > 0:
					if is_local_player_command_blocked_for_mock_coop_unit(u):
						continue
					if u.get("is_exhausted") == false:
						u.set("is_defending", true)
						
						# Use the new helper!
						animate_shield_drop(u)
						
						if u.has_method("finish_turn"):
							u.finish_turn()
						auto_defended_anyone = true
		
		# Play the shield sound once if anyone braced for impact!
		if auto_defended_anyone and defend_sound != null and defend_sound.stream != null:
			defend_sound.play()
		# --------------------------------------

		# If we have green units, they go next. Otherwise, skip to enemies.
		if ally_container and ally_container.get_child_count() > 0:
			change_state(ally_state)
		else:
			change_state(enemy_state)
			
func _on_ally_turn_finished() -> void:
	# Reset player units for the new turn
	for u in player_container.get_children():
		if is_instance_valid(u):
			if u.has_method("reset_turn"):
				u.reset_turn()
				
			# --- TICK COOLDOWNS ---
			var cd = u.get_meta("ability_cooldown", 0)
			if cd > 0:
				u.set_meta("ability_cooldown", cd - 1)
	change_state(enemy_state)

func _on_enemy_turn_finished() -> void:
	await _tick_burn_status_effects()
	
	# Tick the turn counter
	current_turn += 1
	tick_fire_tiles_for_new_turn()
	
	update_objective_ui()
	
	# --- CHECK 'SURVIVE' / 'DEFEND' CONDITIONS ---
	if map_objective == Objective.SURVIVE_TURNS or map_objective == Objective.DEFEND_TARGET:
		if current_turn > turn_limit:
			add_combat_log("MISSION ACCOMPLISHED: Held the line.", "lime")
			_trigger_victory() # <--- CHANGED!
			return # Stop processing, the game is over!

	# Reset player units for the new turn
	for u in player_container.get_children():
		if is_instance_valid(u):
			if u.has_method("reset_turn"):
				u.reset_turn()
				
			# --- TICK COOLDOWNS ---
			var cd = u.get_meta("ability_cooldown", 0)
			if cd > 0:
				u.set_meta("ability_cooldown", cd - 1)
			
	change_state(player_state)


func _compute_burn_tick_damage(unit: Node2D) -> int:
	if unit == null or unit.get("max_hp") == null:
		return 0
	var mh: int = maxi(1, int(unit.max_hp))
	var raw: int = int(ceil(float(mh) * BURN_TICK_MAX_HP_FRACTION))
	return clampi(maxi(raw, BURN_TICK_DAMAGE_MIN), BURN_TICK_DAMAGE_MIN, BURN_TICK_DAMAGE_MAX)


## End-of-round burn for units with meta is_burning (Hellfire ignite). Uses RESISTANCE only — no attacker for EXP.
func _tick_burn_status_effects() -> void:
	var burn_units: Array[Node2D] = []
	for cont in [player_container, ally_container, enemy_container]:
		if cont == null:
			continue
		for c in cont.get_children():
			var u: Node2D = c as Node2D
			if u == null or not is_instance_valid(u) or u.is_queued_for_deletion():
				continue
			if u.get("current_hp") == null or int(u.current_hp) <= 0:
				continue
			if not u.has_meta("is_burning") or u.get_meta("is_burning") != true:
				continue
			burn_units.append(u)

	if burn_units.is_empty():
		return

	for unit in burn_units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion():
			continue
		if unit.get("current_hp") == null or int(unit.current_hp) <= 0:
			continue
		if not unit.has_meta("is_burning") or unit.get_meta("is_burning") != true:
			continue

		var base_dmg: int = _compute_burn_tick_damage(unit)
		if base_dmg <= 0:
			continue
		var res: int = int(unit.resistance) if unit.get("resistance") != null else 0
		var dmg: int = maxi(1, base_dmg - res / 3)

		var nm: String = str(unit.unit_name) if unit.get("unit_name") != null else "Unit"
		add_combat_log(nm + " burns for " + str(dmg) + " damage.", "orange")
		spawn_loot_text("-" + str(dmg) + " BURN", Color(1.0, 0.42, 0.12), unit.global_position + Vector2(32, -26))

		if unit.has_method("take_damage"):
			await unit.take_damage(dmg, null)
		await get_tree().create_timer(0.07, true, false, true).timeout

	update_unit_info_panel()


func spawn_fire_tile(cell: Vector2i, damage: int = -1, duration: int = 3) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= GRID_SIZE.x or cell.y >= GRID_SIZE.y:
		return
	if duration < 1:
		duration = 1
	if damage < 0:
		damage = default_fire_tile_damage
	if fire_tiles.has(cell):
		extinguish_fire_tile(cell, true)
	var entry: Dictionary = {"remaining_turns": duration, "damage": damage, "vfx": null}
	if fire_tile_loop_vfx_scene != null:
		var inst: Node = fire_tile_loop_vfx_scene.instantiate()
		add_child(inst)
		inst.z_index = 5
		inst.position = Vector2(
			float(cell.x * CELL_SIZE.x) + float(CELL_SIZE.x) * 0.5,
			float(cell.y * CELL_SIZE.y) + float(CELL_SIZE.y) * 0.5
		)
		entry["vfx"] = inst
	fire_tiles[cell] = entry


func is_fire_tile(cell: Vector2i) -> bool:
	return fire_tiles.has(cell)


func get_fire_tile_data(cell: Vector2i) -> Dictionary:
	if not fire_tiles.has(cell):
		return {}
	var raw: Variant = fire_tiles[cell]
	if raw is Dictionary:
		return (raw as Dictionary).duplicate()
	return {}


func extinguish_fire_tile(cell: Vector2i, instant: bool = false) -> void:
	if not fire_tiles.has(cell):
		return
	var e: Dictionary = fire_tiles[cell]
	fire_tiles.erase(cell)
	var vfx: Variant = e.get("vfx")
	if vfx == null or not is_instance_valid(vfx as Node):
		return
	var node: Node = vfx as Node
	if instant:
		node.queue_free()
		return
	var dur: float = maxf(0.05, fire_tile_extinguish_shrink_sec)
	if node is Node2D:
		var n2: Node2D = node as Node2D
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(n2, "scale", Vector2(0.001, 0.001), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(n2, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.finished.connect(func():
			if is_instance_valid(node):
				node.queue_free()
		)
	else:
		node.queue_free()


func tick_fire_tiles_for_new_turn() -> void:
	if fire_tiles.is_empty():
		return
	var cells: Array = fire_tiles.keys()
	var to_extinguish: Array[Vector2i] = []
	for k in cells:
		if not fire_tiles.has(k):
			continue
		var cell: Vector2i = k as Vector2i
		var entry: Dictionary = fire_tiles[cell]
		var rt: int = int(entry.get("remaining_turns", 1)) - 1
		entry["remaining_turns"] = rt
		if rt <= 0:
			to_extinguish.append(cell)
	for c in to_extinguish:
		extinguish_fire_tile(c)


func apply_fire_tile_damage_to_unit(unit: Node2D, cell: Vector2i) -> void:
	if unit == null or not is_instance_valid(unit) or unit.is_queued_for_deletion():
		return
	if not is_fire_tile(cell):
		return
	var data: Dictionary = fire_tiles[cell]
	var dmg: int = int(data.get("damage", default_fire_tile_damage))
	if dmg <= 0:
		return
	if unit.get("current_hp") != null and int(unit.current_hp) <= 0:
		return
	var nm: String = str(unit.unit_name) if unit.get("unit_name") != null else "Unit"
	add_combat_log(nm + " takes " + str(dmg) + " damage from fire.", "orange")
	spawn_loot_text("-" + str(dmg) + " FIRE", Color(1.0, 0.35, 0.1), unit.global_position + Vector2(32, -26))
	if unit.has_method("take_damage"):
		await unit.take_damage(dmg, null)
	if is_instance_valid(self) and is_inside_tree():
		await get_tree().create_timer(0.05, true, false, true).timeout
	update_unit_info_panel()


## Called only from Unit.move_along_path after each committed step (not preview / AI planning).
func on_unit_committed_move_enter_cell(unit: Node2D, cell: Vector2i) -> void:
	if not is_fire_tile(cell):
		return
	await apply_fire_tile_damage_to_unit(unit, cell)


func _remove_dead_player_dragon(unit: Node2D) -> void:
	if unit == null:
		return
	if not unit.get_meta("is_dragon", false):
		return
	if unit.get_parent() != player_container:
		return

	var dragon_uid: String = str(unit.get_meta("dragon_uid", ""))
	if dragon_uid == "":
		return

	# ==========================================
	# --- NEW: MORGRA'S GRIEF TRIGGER ---
	# ==========================================
	if dragon_uid == CampaignManager.morgra_favorite_dragon_uid:
		CampaignManager.morgra_anger_duration = 3 # She stays mad for 3 maps!
		CampaignManager.morgra_neutral_duration = 0 # Reset neutral phase
		CampaignManager.morgra_favorite_dragon_uid = "" # Clear the favorite
		CampaignManager.morgra_favorite_survived_battles = 0
	# ==========================================

	# 1. Remove from the permanent dragon collection
	for i in range(DragonManager.player_dragons.size() - 1, -1, -1):
		var d = DragonManager.player_dragons[i]
		if d is Dictionary and str(d.get("uid", "")) == dragon_uid:
			DragonManager.player_dragons.remove_at(i)
			break

	# 2. Remove only the matching dragon from any legacy roster entry
	for i in range(CampaignManager.player_roster.size() - 1, -1, -1):
		var entry = CampaignManager.player_roster[i]
		if not (entry is Dictionary):
			continue

		if str(entry.get("dragon_uid", "")) == dragon_uid:
			CampaignManager.player_roster.remove_at(i)
			break

	# 3. Lock it in immediately so reloads cannot resurrect it
	if CampaignManager.active_save_slot != -1:
		CampaignManager.save_game(CampaignManager.active_save_slot, true)
		
func _on_unit_died(unit: Node2D, killer: Node2D):
	# 1. Grab the dying unit's resource data
	var data = unit.get("data")
	
	# 2. Fetch the random quote safely
	var final_words: String = "..."
	var display_name: String = unit.get("unit_name") if unit.get("unit_name") != null else "Unknown Unit"
	
	if data != null:
		if data.get("display_name") != null:
			display_name = data.display_name
		if data.has_method("get_random_death_quote"):
			final_words = data.get_random_death_quote()

	# 2B. Boss Personal Dialogue (V1): if a playable got the killing blow on a supported boss, show personal death line.
	if unit.get_parent() == enemy_container and killer != null and is_instance_valid(killer) and (killer.get_parent() == player_container or (ally_container != null and killer.get_parent() == ally_container)):
		var boss_id: String = _get_boss_dialogue_id(unit)
		var unit_id: String = _get_playable_dialogue_id(killer)
		var death_line: String = _get_boss_personal_line(boss_id, unit_id, "death")
		if not death_line.is_empty():
			add_combat_log(display_name + ": " + death_line, "gold")
		
	# 3. Send it to UI / log
	print(display_name + " died saying: " + final_words)
	# talk_panel.display_message(display_name, final_words)

	var grid_pos = get_grid_pos(unit)
	astar.set_point_solid(grid_pos, false)
	if unit.get_parent() == player_container and unit.get_meta("is_dragon", false):
		_remove_dead_player_dragon(unit)
		add_combat_log(unit.unit_name + " has fallen permanently!", "red")
	# --- DEATH LOGGING & FAME TRACKING ---
	if unit.get_parent() == enemy_container:
		enemy_kills_count += 1
		add_combat_log(unit.unit_name + " has been defeated!", "tomato")
	elif unit.get_parent() == player_container:
		player_deaths_count += 1
		add_combat_log(unit.unit_name + " has fallen in battle!", "crimson")
	elif unit.get_parent() == ally_container:
		ally_deaths_count += 1
		add_combat_log(unit.unit_name + " has fallen in battle!", "orange")

	if _battle_resonance_allowed() and unit.get_parent() == enemy_container:
		if killer != null and is_instance_valid(killer):
			var kp: Node = killer.get_parent()
			if kp != null and (kp == player_container or (ally_container != null and kp == ally_container)):
				if unit.get("data") != null and unit.data.get("is_recruitable") == true:
					CampaignManager.mark_battle_resonance("chose_harsh_efficiency")

	# --- Relationship Web: grief when allied unit dies and nearby allies had trust with them (battle-local only) ---
	if unit.get_parent() == player_container or unit.get_parent() == ally_container:
		var dead_id: String = get_relationship_id(unit)
		var dead_pos: Vector2i = get_grid_pos(unit)
		var witnesses: Array[Node2D] = []
		if player_container:
			for c in player_container.get_children():
				if c is Node2D and c != unit and is_instance_valid(c) and (c.get("current_hp") != null and int(c.current_hp) > 0):
					witnesses.append(c)
		if ally_container:
			for c in ally_container.get_children():
				if c is Node2D and c != unit and is_instance_valid(c) and (c.get("current_hp") != null and int(c.current_hp) > 0):
					witnesses.append(c)
		for w in witnesses:
			var w_pos: Vector2i = get_grid_pos(w)
			var dist: int = abs(w_pos.x - dead_pos.x) + abs(w_pos.y - dead_pos.y)
			if dist > SUPPORT_COMBAT_RANGE_MANHATTAN:
				continue
			var rel: Dictionary = CampaignManager.get_relationship(get_relationship_id(w), dead_id)
			if rel.get("trust", 0) >= RELATIONSHIP_TRUST_THRESHOLD:
				_grief_units[get_relationship_id(w)] = true
				add_combat_log(get_relationship_id(w) + " falters after witnessing " + dead_id + "'s death.", "gray")
				if DEBUG_RELATIONSHIP_COMBAT:
					print("[RelationshipCombat] Grief: ", get_relationship_id(w), " witnessed ", dead_id)

	# --- Rivalry: contested kill (killer + others who damaged this enemy this battle). Kill-near-mentor: killer gets kill while near higher-level ally. ---
	if unit.get_parent() == enemy_container and killer != null and is_instance_valid(killer):
		var killer_parent: Node = killer.get_parent()
		if killer_parent == player_container or (ally_container != null and killer_parent == ally_container):
			var killer_id: String = get_relationship_id(killer)
			var eid: int = unit.get_instance_id()
			var damagers: Array = _enemy_damagers.get(eid, [])
			for damager_id in damagers:
				if damager_id == killer_id:
					continue
				var other_unit: Node2D = null
				if player_container:
					for c in player_container.get_children():
						if c is Node2D and get_relationship_id(c) == damager_id:
							other_unit = c
							break
				if other_unit == null and ally_container:
					for c in ally_container.get_children():
						if c is Node2D and get_relationship_id(c) == damager_id:
							other_unit = c
							break
				if other_unit != null:
					_award_relationship_stat_event(killer, other_unit, "rivalry", "rival_finish", 1)
			# Kill near mentor: killer (lower-level) got kill while adjacent to higher-level ally.
			var killer_pos: Vector2i = get_grid_pos(killer)
			var directions: Array = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
			for dir in directions:
				var npos: Vector2i = killer_pos + dir
				var ally_at: Node2D = get_unit_at(npos)
				if ally_at == null and ally_container != null:
					for c in ally_container.get_children():
						if c is Node2D and get_grid_pos(c) == npos and (c.get("current_hp") != null and int(c.current_hp) > 0):
							ally_at = c
							break
				if ally_at != null and ally_at != killer and _can_gain_mentorship(ally_at, killer):
					_award_relationship_stat_event(ally_at, killer, "mentorship", "kill_near_mentor", 1)
					break
			_enemy_damagers.erase(eid)

	# ==========================================
	# --- CRITICAL BUG FIX: AVATAR DEATH ---
	# ==========================================
	if unit.get("is_custom_avatar") == true:
		add_combat_log("The Leader has fallen! All is lost...", "red")
		trigger_game_over("DEFEAT")
		return # Stop execution here!

	# --- LOOT LOGIC (Enemies only) ---
	if unit.get_parent() == enemy_container and unit.data != null:
		var u_data = unit.data
		pending_loot.clear() 
		
		# --- LOOT LOGIC (Enemies only) ---
		var total_gold = 0
		if u_data.max_gold_drop > 0:
			total_gold += randi_range(u_data.min_gold_drop, u_data.max_gold_drop)
		if "stolen_gold" in unit:
			total_gold += unit.stolen_gold
			
		if total_gold > 0:
			# 1. Update the math instantly in the background
			player_gold += total_gold 
			
			# 2. THE FIX: Remove update_gold_display() and spawn_loot_text()!
			# Replace them with our new Flying Animation!
			animate_flying_gold(unit.global_position, total_gold)
			
			add_combat_log("Found " + str(total_gold) + " gold.", "yellow")

		if u_data.drops_equipped_weapon and unit.equipped_weapon != null:
			if randi() % 100 < u_data.equipped_weapon_chance:
				pending_loot.append(CampaignManager.duplicate_item(unit.equipped_weapon))
				
		# --- SAFE LOOT CHECKING ---
		for loot in u_data.extra_loot:
			# Ensure the slot isn't empty, AND it actually has an item in it
			if loot != null and loot.get("item") != null:
				var chance = loot.get("drop_chance") if loot.get("drop_chance") != null else 100.0
				if randf() * 100.0 <= chance:
					pending_loot.append(CampaignManager.duplicate_item(loot.item))
				
		if "stolen_loot" in unit and unit.stolen_loot.size() > 0:
			for s_loot in unit.stolen_loot:
				if s_loot != null: # Safety check here too!
					pending_loot.append(CampaignManager.duplicate_item(s_loot))
		
		if not pending_loot.is_empty():
			loot_recipient = player_state.active_unit
			show_loot_window()

	# ==========================================
	# --- WIN / LOSS CONDITION CHECKS ---
	# ==========================================
	
	# 1. UNIVERSAL LOSS CONDITION: All player units are dead
	if unit.get_parent() == player_container and player_container.get_child_count() <= 1: 
		add_combat_log("MISSION FAILED: Entire party wiped out.", "red")
		trigger_game_over("DEFEAT")
		return

	# 2. SPECIFIC OBJECTIVE CHECKS
	match map_objective:
		Objective.ROUT_ENEMY:
			if _count_alive_enemies(unit) == 0 and _count_active_enemy_spawners() == 0:
				add_combat_log("MISSION ACCOMPLISHED: All enemies routed.", "lime")
				_trigger_victory()
					
		Objective.DEFEND_TARGET:
			if unit == vip_target:
				add_combat_log("MISSION FAILED: VIP Target was killed.", "red")
				trigger_game_over("DEFEAT")
	
	
	update_fog_of_war()
	update_objective_ui()
		
func trigger_game_over(result: String) -> void:
	change_state(null)
	if CampaignManager and not is_arena_match and not CampaignManager.is_skirmish_mode:
		CampaignManager.record_story_battle_outcome_for_camp(result, player_deaths_count, ally_deaths_count)

	# 1. THE PAUSE FIX: Force the game to freeze, but keep the UI panel awake
	get_tree().paused = true
	game_over_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# ==========================================
	# --- NEW: ARENA MMR, STREAKS & TOKENS ---
	# ==========================================
	if ArenaManager.current_opponent_data.size() > 0:
		var opp_mmr: int = ArenaManager.current_opponent_data.get("score", 1000)
		var my_mmr: int = ArenaManager.get_local_mmr()
		var mmr_change: int = 0
		
		# Save old state for the animated sequence in the city
		ArenaManager.last_match_old_mmr = my_mmr

		if result == "VICTORY":
			mmr_change = 25 + int(max(0, (opp_mmr - my_mmr) / 10.0))
			ArenaManager.last_match_result = "VICTORY"
			
			# RECORD WIN STREAK & GET REWARDS
			var arena_rewards = CampaignManager.record_arena_win(150)
			ArenaManager.last_match_gold_reward = arena_rewards["gold"]
			ArenaManager.last_match_token_reward = arena_rewards["tokens"]
		else:
			mmr_change = -15 + int(min(0, (opp_mmr - my_mmr) / 15.0))
			mmr_change = min(-1, mmr_change) 
			ArenaManager.last_match_result = "DEFEAT"
			
			# BREAK STREAK
			CampaignManager.record_arena_loss()
			
			# Ghost Defense logic
			var meta = ArenaManager.current_opponent_data.get("metadata", {})
			var owner_id = meta.get("player_id", "")
			if owner_id != "":
				ArenaManager.record_defense_result(owner_id, true)
				
		ArenaManager.set_local_mmr(my_mmr + mmr_change)
		ArenaManager.last_match_mmr_change = mmr_change
		ArenaManager.last_match_new_mmr = my_mmr + mmr_change
	# ==========================================
	
	result_label.text = result
	if result == "VICTORY":
		result_label.modulate = Color(0.2, 0.8, 0.2)
		continue_button.visible = true
		restart_button.visible = false
		if is_arena_match: continue_button.text = "Return to City"
	else:
		result_label.modulate = Color(0.8, 0.2, 0.2)
		continue_button.visible = false
		restart_button.visible = true
		if is_arena_match: restart_button.text = "Leave Arena"
		
	# ==========================================
	# --- FAME & SCORE CALCULATION ---
	# ==========================================
	var base_clear = 500 if result == "VICTORY" else 0
	var ability_pts = ability_triggers_count * 50
	var kill_pts = enemy_kills_count * 25
	var p_death_pen = player_deaths_count * -250
	var a_death_pen = ally_deaths_count * -100
	
	var raw_score = base_clear + ability_pts + kill_pts + p_death_pen + a_death_pen
	
	# Find Kaelen's level to calculate the Maximum Score Cap
	var hero_level = 1
	for u in player_container.get_children():
		if u.get("is_custom_avatar") == true:
			hero_level = u.level
			break
			
	var max_allowed = hero_level * 1000
	
	# We use clamp(raw_score, 1, ...) so you always get at least 1 point as requested!
	var final_score = clamp(raw_score, 1, max_allowed) 
	
	# Save it permanently to the Campaign
	CampaignManager.global_fame += final_score
	
	# ==========================================
	# --- BUILD THE SCORE UI DYNAMICALLY ---
	# ==========================================
	var score_label = game_over_panel.get_node_or_null("ScoreBreakdown")
	if score_label == null:
		score_label = RichTextLabel.new()
		score_label.name = "ScoreBreakdown"
		score_label.bbcode_enabled = true
		
		# --- FONT SIZE FIX: Double the size ---
		score_label.add_theme_font_size_override("normal_font_size", 32)
		score_label.add_theme_font_size_override("bold_font_size", 32)
		
		# --- INVISIBLE WALL FIX: Allow clicks to pass through to buttons ---
		score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# --- BOX SIZE: Bigger box for bigger text ---
		score_label.custom_minimum_size = Vector2(800, 500)
		score_label.position = Vector2((game_over_panel.size.x - 800) / 2.0, result_label.position.y + 70)
		game_over_panel.add_child(score_label)
		
	# --- BUILD THE TEXT CONTENT ---
	var txt = "[center]"
	if base_clear > 0: txt += "Map Clear: [color=lime]+500[/color]\n"
	if kill_pts > 0: txt += "Enemies Defeated (" + str(enemy_kills_count) + "): [color=lime]+" + str(kill_pts) + "[/color]\n"
	if ability_pts > 0: txt += "Abilities Executed (" + str(ability_triggers_count) + "): [color=lime]+" + str(ability_pts) + "[/color]\n"
	
	if p_death_pen < 0: txt += "Player Units Lost (" + str(player_deaths_count) + "): [color=red]" + str(p_death_pen) + "[/color]\n"
	if a_death_pen < 0: txt += "Allies Lost (" + str(ally_deaths_count) + "): [color=orange]" + str(a_death_pen) + "[/color]\n"
	
	txt += "------------------\n"
	txt += "Total Score: " + str(final_score) + "\n"
	
	if raw_score > max_allowed:
		txt += "[color=yellow](Capped at Hero Level Limit: " + str(max_allowed) + ")[/color]\n"
		
	txt += "\n[color=gold]GLOBAL FAME: " + str(CampaignManager.global_fame) + "[/color][/center]"
	
	score_label.text = txt
	game_over_panel.visible = true
	
func _on_restart_button_pressed() -> void:
	get_tree().paused = false # <--- ADD THIS
	
	# --- NEW: ARENA DEFEAT LOGIC ---
	if is_arena_match:
		ArenaManager.last_match_result = "DEFEAT" # Save the loss!
		ArenaManager.current_opponent_data = {} 
		get_tree().change_scene_to_file("res://Scenes/CityMenu.tscn")
		return
		
	SceneTransition.change_scene_to_file(get_tree().current_scene.scene_file_path)

# --- VISUALS & UTILS ---
func update_cursor_pos() -> void:
	var m = get_global_mouse_position()
	var new_grid_pos = Vector2i(
		clamp(m.x / CELL_SIZE.x, 0, GRID_SIZE.x - 1), 
		clamp(m.y / CELL_SIZE.y, 0, GRID_SIZE.y - 1)
	)
	
	if new_grid_pos != cursor_grid_pos:
		cursor_grid_pos = new_grid_pos
		var target_pos = Vector2(cursor_grid_pos.x * CELL_SIZE.x, cursor_grid_pos.y * CELL_SIZE.y)
		
		# Move the HoverGlow instantly or with a very fast tween
		hover_glow.position = target_pos
		
		# Smoothly slide the cursor to the new tile (snappier follow for battle readability)
		var tween = create_tween()
		tween.tween_property(cursor, "position", target_pos, 0.07)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)

func update_cursor_color() -> void:
	# 1. Start by resetting to the default white color every frame
	cursor_sprite.modulate = Color.WHITE
	if is_instance_valid(hover_glow):
		hover_glow.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	# 2. Check if it is the player's turn and a unit is currently selected
	if current_state == player_state and player_state.active_unit != null:
		
		# 3. Check if the tile the cursor is hovering over is within attack range
		if attackable_tiles.has(cursor_grid_pos):
			
			# 4. Check if there is actually an enemy on that specific tile
			var unit_under_cursor = get_enemy_at(cursor_grid_pos)
			if unit_under_cursor != null:
				
				# Tint the cursor red
				cursor_sprite.modulate = Color(1.0, 0.3, 0.3)
				if is_instance_valid(hover_glow):
					hover_glow.modulate = Color(1.0, 0.35, 0.35, 1.0)
				return
		
		# Valid move destination (blue range): cyan cursor + glow reads clearly vs neutral tiles
		if (not player_state.active_unit.has_moved or player_state.active_unit.get("in_canto_phase") == true) and reachable_tiles.has(cursor_grid_pos):
			cursor_sprite.modulate = Color(0.5, 0.92, 1.0)
			if is_instance_valid(hover_glow):
				hover_glow.modulate = Color(0.45, 0.88, 1.0, 0.95)

func draw_preview_path() -> void:
	if path_line == null:
		return
		
	if not CampaignManager.battle_show_path_preview:
		path_line.visible = false
		return

	path_line.visible = true
	path_line.clear_points()
	_set_path_pulse(false) # par défaut

	if current_state != player_state or player_state == null or player_state.active_unit == null:
		return

	var active = player_state.active_unit
	if active.has_moved and active.get("in_canto_phase") != true:
		return

	var start = get_grid_pos(active)
	
	# Use our new helper to get the path from the correct AStar grid (Flying vs Walking)
	var path = get_unit_path(active, start, cursor_grid_pos)
	var move_range: float = float(active.canto_move_budget) if active.get("in_canto_phase") == true else float(active.move_range)

	# 1. Path must exist
	# 2. Total terrain cost must be within unit's move range
	# 3. The target tile MUST be a valid blue tile (stops them from landing on allies or walls)
	var valid_path: bool = (path.size() > 1) and (get_path_move_cost(path, active) <= move_range) and reachable_tiles.has(cursor_grid_pos)
	
	if not valid_path:
		return

	# Draw the line through the center of each cell (32, 32 offset based on 64x64 cell size)
	for p in path:
		path_line.add_point(Vector2(p.x * CELL_SIZE.x + 32, p.y * CELL_SIZE.y + 32))

	path_line.joint_mode = Line2D.LINE_JOINT_ROUND
	path_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	path_line.end_cap_mode = Line2D.LINE_CAP_ROUND

	if CampaignManager.battle_path_preview_pulse:
		_set_path_pulse(true)
	else:
		_set_path_pulse(false)

func _draw() -> void:
	if current_state == pre_battle_state:
		for pos in pre_battle_state.valid_deployment_slots:
			draw_rect(Rect2(pos.x * CELL_SIZE.x, pos.y * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y), Color(0.2, 0.8, 0.2, 0.4))
			draw_rect(Rect2(pos.x * CELL_SIZE.x, pos.y * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y), Color(0.2, 1.0, 0.2, 0.8), false, 2.0)

	var player_base_color = Color(0.2, 0.4, 0.8, 0.4)
	var enemy_base_color = Color(0.8, 0.2, 0.2, 0.4)
	var ally_base_color = Color(0.2, 0.8, 0.2, 0.4)

	var draw_unit_bases = func(container: Node, color: Color):
		if container != null:
			for unit in container.get_children():
				if is_instance_valid(unit) and unit.visible and not unit.is_queued_for_deletion():
					var tiles = [get_grid_pos(unit)]
					if unit.has_method("get_occupied_tiles"):
						tiles = unit.get_occupied_tiles(self)

					for pos in tiles:
						draw_rect(Rect2(pos.x * CELL_SIZE.x, pos.y * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y), color)

	if CampaignManager.battle_show_faction_tiles:
		draw_unit_bases.call(player_container, player_base_color)
		draw_unit_bases.call(enemy_container, enemy_base_color)
		draw_unit_bases.call(ally_container, ally_base_color)

	if show_danger_zone:
		for pos in danger_zone_move_tiles:
			if _danger_overlay_cell_drawable(pos):
				draw_rect(Rect2(pos.x * CELL_SIZE.x, pos.y * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y), Color(0.5, 0.0, 0.5, 0.4))
		for pos in danger_zone_attack_tiles:
			if _danger_overlay_cell_drawable(pos):
				draw_rect(Rect2(pos.x * CELL_SIZE.x, pos.y * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y), Color(1.0, 0.4, 0.0, 0.5))

	for pos in reachable_tiles:
		draw_rect(Rect2(pos.x * CELL_SIZE.x, pos.y * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y), Color(0.3, 0.5, 0.9, 0.5))

	var action_color = Color(0.8, 0.2, 0.2, 0.5)
	if current_state == player_state and player_state.active_unit != null:
		var wpn = player_state.active_unit.equipped_weapon
		if wpn != null and (wpn.get("is_healing_staff") == true or wpn.get("is_buff_staff") == true):
			action_color = Color(0.2, 0.8, 0.2, 0.5)

	for pos in attackable_tiles:
		draw_rect(Rect2(pos.x * CELL_SIZE.x, pos.y * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y), action_color)

	if CampaignManager.battle_show_grid:
		var c = Color(1, 1, 1, 0.3)
		for x in range(GRID_SIZE.x + 1):
			draw_line(Vector2(x * CELL_SIZE.x, 0), Vector2(x * CELL_SIZE.x, GRID_SIZE.y * CELL_SIZE.y), c)
		for y in range(GRID_SIZE.y + 1):
			draw_line(Vector2(0, y * CELL_SIZE.y), Vector2(GRID_SIZE.x * CELL_SIZE.x, y * CELL_SIZE.y), c)

	if CampaignManager.battle_show_enemy_threat:
		for pos in enemy_reachable_tiles:
			if _danger_overlay_cell_drawable(pos):
				draw_rect(Rect2(pos.x * CELL_SIZE.x, pos.y * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y), Color(0.5, 0.0, 0.5, 0.4))

		for pos in enemy_attackable_tiles:
			if _danger_overlay_cell_drawable(pos):
				draw_rect(Rect2(pos.x * CELL_SIZE.x, pos.y * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y), Color(1.0, 0.4, 0.0, 0.5))

func get_grid_pos(node: Node2D) -> Vector2i:
	return Vector2i(int(node.position.x / CELL_SIZE.x), int(node.position.y / CELL_SIZE.y))

func get_unit_at(pos: Vector2i) -> Node2D:
	for u in player_container.get_children():
		if u.visible and not u.is_queued_for_deletion():
			if u.has_method("get_occupied_tiles"):
				if pos in u.get_occupied_tiles(self): return u
			elif get_grid_pos(u) == pos: return u
	return null

## One step from `from_cell` toward `to_cell` on the grid (-1/0/1 each axis). Zero if cells coincide.
func _attack_line_step(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	var dx: int = to_cell.x - from_cell.x
	var dy: int = to_cell.y - from_cell.y
	var sx: int = 0 if dx == 0 else (1 if dx > 0 else -1)
	var sy: int = 0 if dy == 0 else (1 if dy > 0 else -1)
	if sx == 0 and sy == 0:
		return Vector2i.ZERO
	return Vector2i(sx, sy)


func get_enemy_at(pos: Vector2i) -> Node2D:
	for e in enemy_container.get_children():
		# Added 'and e.visible' to prevent targeting enemies in the fog!
		if not e.is_queued_for_deletion() and e.visible:
			if e.has_method("get_occupied_tiles"):
				if pos in e.get_occupied_tiles(self): return e
			elif get_grid_pos(e) == pos: return e
	if destructibles_container:
		for d in destructibles_container.get_children():
			if not d.is_queued_for_deletion():
				if d.has_method("get_occupied_tiles"):
					if pos in d.get_occupied_tiles(self): return d
				elif get_grid_pos(d) == pos: return d
	if chests_container:
		for c in chests_container.get_children():
			if not c.is_queued_for_deletion():
				if get_grid_pos(c) == pos: return c
	return null

func get_distance(node_a: Node2D, node_b: Node2D) -> int:
	var tiles_a = [get_grid_pos(node_a)]
	if node_a.has_method("get_occupied_tiles"): 
		tiles_a = node_a.get_occupied_tiles(self)
		
	var tiles_b = [get_grid_pos(node_b)]
	if node_b.has_method("get_occupied_tiles"): 
		tiles_b = node_b.get_occupied_tiles(self)
		
	# Find the absolute shortest distance between ANY of their footprint tiles
	var min_dist = 9999
	for ta in tiles_a:
		for tb in tiles_b:
			var d = abs(ta.x - tb.x) + abs(ta.y - tb.y)
			if d < min_dist:
				min_dist = d
				
	return min_dist

func is_in_range(attacker: Node2D, defender: Node2D) -> bool:
	if attacker.equipped_weapon == null:
		return false
	var wpn: Resource = attacker.equipped_weapon
	var min_r: int = wpn.min_range
	var max_r: int = wpn.max_range
	var staff_like: bool = wpn.get("is_healing_staff") == true or wpn.get("is_buff_staff") == true or wpn.get("is_debuff_staff") == true
	if staff_like:
		var dist: int = get_distance(attacker, defender)
		return dist >= min_r and dist <= max_r
	var tiles_a: Array[Vector2i] = _unit_footprint_tiles(attacker)
	var tiles_b: Array[Vector2i] = _unit_footprint_tiles(defender)
	for ta in tiles_a:
		for tb in tiles_b:
			var d: int = abs(ta.x - tb.x) + abs(ta.y - tb.y)
			if d < min_r or d > max_r:
				continue
			if _attack_has_clear_los(ta, tb):
				return true
	return false


## ClassData.MoveType: FLYING = 2, CAVALRY = 3 — only these get post-action Canto (leftover move, no second attack).
func unit_supports_canto(unit: Node2D) -> bool:
	if unit == null:
		return false
	var mt: Variant = unit.get("move_type")
	return mt == 2 or mt == 3


func rebuild_grid() -> void:
	astar.fill_solid_region(astar.region, false)
	flying_astar.fill_solid_region(flying_astar.region, false)

	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			var pos = Vector2i(x, y)
			var t_data = get_terrain_data(pos)
			astar.set_point_weight_scale(pos, t_data["move_cost"])
			flying_astar.set_point_weight_scale(pos, 1.0)

	# --- MULTI-TILE SOLIDITY HELPER ---
	var apply_solidity = func(node: Node2D, default_block_fliers: bool = false):
		if node == null or node.is_queued_for_deletion():
			return

		var should_block_movement: bool = true
		var should_block_fliers: bool = default_block_fliers

		if node.has_method("blocks_movement"):
			should_block_movement = node.blocks_movement()

		if node.has_method("blocks_fliers"):
			should_block_fliers = node.blocks_fliers()

		if not should_block_movement and not should_block_fliers:
			return

		var tiles = [get_grid_pos(node)]
		if node.has_method("get_occupied_tiles"):
			tiles = node.get_occupied_tiles(self)

		for t in tiles:
			if t.x >= 0 and t.x < GRID_SIZE.x and t.y >= 0 and t.y < GRID_SIZE.y:
				if should_block_movement:
					astar.set_point_solid(t, true)
				if should_block_fliers:
					flying_astar.set_point_solid(t, true)

	# --- SOLID OBJECTS (Only block walking units unless overridden) ---
	for w in walls_container.get_children():
		apply_solidity.call(w, false)

	if destructibles_container:
		for d in destructibles_container.get_children():
			apply_solidity.call(d, false)

	if chests_container:
		for c in chests_container.get_children():
			if not c.is_queued_for_deletion() and c.is_locked:
				astar.set_point_solid(get_grid_pos(c), true)

	# --- ENEMIES (Block BOTH walkers and fliers unless overridden) ---
	if enemy_container:
		for e in enemy_container.get_children():
			apply_solidity.call(e, true)

	# --- PLAYER & ALLIES ---
	var all_units = player_container.get_children()
	if ally_container:
		all_units += ally_container.get_children()

	for u in all_units:
		apply_solidity.call(u, false)

	if show_danger_zone:
		_danger_zone_recalc_dirty = true
		
func get_occupant_at(pos: Vector2i) -> Node2D:
	var containers = [player_container, enemy_container, ally_container, destructibles_container, chests_container]

	for c in containers:
		if c != null:
			for child in c.get_children():
				if child == null or child.is_queued_for_deletion():
					continue

				if child.has_method("is_targetable") and not child.is_targetable():
					continue

				if child.has_method("get_occupied_tiles"):
					if pos in child.get_occupied_tiles(self):
						return child
				else:
					if get_grid_pos(child) == pos:
						return child

	return null


func _unit_footprint_tiles(unit: Node2D) -> Array[Vector2i]:
	if unit != null and unit.has_method("get_occupied_tiles"):
		var raw: Array = unit.get_occupied_tiles(self)
		var out: Array[Vector2i] = []
		for t in raw:
			if t is Vector2i:
				out.append(t as Vector2i)
		if out.size() > 0:
			return out
	return [get_grid_pos(unit)]


func _danger_overlay_cell_drawable(cell: Vector2i) -> bool:
	if not use_fog_of_war:
		return true
	return fow_grid.has(cell) and fow_grid[cell] == 2


func _attack_has_clear_los(from_tile: Vector2i, to_tile: Vector2i) -> bool:
	if from_tile == to_tile:
		return true
	var dist: int = abs(from_tile.x - to_tile.x) + abs(from_tile.y - to_tile.y)
	if dist <= 1:
		return true
	return _check_line_of_sight(from_tile, to_tile)


func clear_ranges() -> void:
	reachable_tiles.clear()
	attackable_tiles.clear()
	enemy_reachable_tiles.clear() # Added
	enemy_attackable_tiles.clear() # Added
	queue_redraw()

func calculate_ranges(unit: Node2D) -> void:
	clear_ranges()
	if unit == null: return

	var footprint: Array[Vector2i] = _unit_footprint_tiles(unit)
	var move_range: int = unit.get("move_range") if unit.get("move_range") != null else 0
	var in_canto: bool = unit.get("in_canto_phase") == true
	var eff_budget: float = float(move_range)
	if in_canto:
		eff_budget = float(unit.get("canto_move_budget"))
	var budget_shape: int = maxi(int(ceil(eff_budget)), 1)

	# 1. Walkable Tiles (Blue): full phase, or Canto pivot (move only), or footprint-only for post-move attacks
	if not unit.has_moved or in_canto:
		var saved: Dictionary = {}
		for t in footprint:
			saved[t] = {"w": astar.is_point_solid(t), "fl": flying_astar.is_point_solid(t)}
			astar.set_point_solid(t, false)
			flying_astar.set_point_solid(t, false)

		var reach_accum: Dictionary = {}
		for start in footprint:
			var x0: int = maxi(0, start.x - budget_shape)
			var x1: int = mini(GRID_SIZE.x, start.x + budget_shape + 1)
			var y0: int = maxi(0, start.y - budget_shape)
			var y1: int = mini(GRID_SIZE.y, start.y + budget_shape + 1)
			for x in range(x0, x1):
				for y in range(y0, y1):
					var target = Vector2i(x, y)
					if abs(start.x - target.x) + abs(start.y - target.y) > budget_shape:
						continue

					var is_solid = flying_astar.is_point_solid(target) if unit.get("move_type") == 2 else astar.is_point_solid(target)

					if target != start and is_solid:
						continue
					var path = get_unit_path(unit, start, target)
					if path.size() > 0:
						var path_cost = get_path_move_cost(path, unit)
						if path_cost <= eff_budget:
							reach_accum[target] = true

		for t in footprint:
			var rec: Variant = saved.get(t, null)
			if rec != null:
				astar.set_point_solid(t, rec.w)
				flying_astar.set_point_solid(t, rec.fl)

		for k in reach_accum.keys():
			reachable_tiles.append(k)
	else:
		for t in footprint:
			reachable_tiles.append(t)

	# --- FILTER LANDING ZONES ---
	# Ensure fliers don't end their turn hovering inside a wall, and no one lands on friends!
	var final_reachable: Array[Vector2i] = []
	for tile in reachable_tiles:
		var valid = true
		var occupant = get_unit_at(tile)
		if occupant != null and occupant != unit: valid = false
		
		if unit.get("move_type") == 2: # FLYING
			for w in walls_container.get_children():
				if get_grid_pos(w) == tile: valid = false
			for d in destructibles_container.get_children():
				if get_grid_pos(d) == tile and not d.is_queued_for_deletion(): valid = false
			for c in chests_container.get_children():
				if get_grid_pos(c) == tile and not c.is_queued_for_deletion(): valid = false

		if valid: final_reachable.append(tile)
			
	reachable_tiles = final_reachable

	# 2. Attackable Tiles (Red) — not during Canto (no second attack)
	if not in_canto:
		var min_r = 1
		var max_r = 1
		var wpn_res: Resource = unit.equipped_weapon
		var use_attack_los: bool = true
		if wpn_res != null:
			min_r = wpn_res.min_range
			max_r = wpn_res.max_range
			if wpn_res.get("is_healing_staff") == true or wpn_res.get("is_buff_staff") == true or wpn_res.get("is_debuff_staff") == true:
				use_attack_los = false

		for r_tile in reachable_tiles:
			for x in range(-max_r, max_r + 1):
				for y in range(-max_r, max_r + 1):
					var dist = abs(x) + abs(y)
					if dist >= min_r and dist <= max_r:
						var n = r_tile + Vector2i(x, y)
						if n.x >= 0 and n.x < GRID_SIZE.x and n.y >= 0 and n.y < GRID_SIZE.y:
							if not reachable_tiles.has(n) and not attackable_tiles.has(n):
								if use_attack_los and not _attack_has_clear_los(r_tile, n):
									continue
								attackable_tiles.append(n)

	if unit.has_moved and not in_canto:
		reachable_tiles.clear()
	queue_redraw()
		
func show_phase_banner(phase_title: String, phase_color: Color) -> void:
	# 1. Reset and Modulate the Banner
	phase_banner.self_modulate = phase_color
	phase_banner.modulate.a = 0.0
	phase_banner.visible = true
	
	# --- THE FIX: Stop the animation and force it to Frame 0 ---
	if phase_banner.has_method("stop"):
		phase_banner.stop()
		phase_banner.frame = 0 
		
	# 2. Handle Positioning (AnimatedSprite2D uses global_position centered)
	var viewport_size = get_viewport_rect().size
	var banner_size = Vector2(800, 150) # Fallback approximate size of the ribbon
	
	if phase_banner is Control:
		banner_size = phase_banner.size
		phase_banner.position.x = (viewport_size.x - banner_size.x) / 2.0
		phase_banner.position.y = ((viewport_size.y - banner_size.y) / 2.0) - 50
	else:
		phase_banner.global_position = viewport_size / 2.0
		phase_banner.global_position.y -= 50

	# 3. Add the dynamic Phase Text (Player Phase, etc.)
	var title_label = phase_banner.get_node_or_null("PhaseTitle")
	if title_label == null:
		title_label = Label.new()
		title_label.name = "PhaseTitle"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 38)
		title_label.add_theme_color_override("font_color", Color.WHITE)
		title_label.add_theme_constant_override("outline_size", 8)
		title_label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1))
		phase_banner.add_child(title_label)
		
	title_label.text = phase_title
	title_label.modulate.a = 1.0 # Ensure it's fully visible from the start
	
	# Center the text over the banner
	if phase_banner is Control:
		title_label.size = banner_size
		title_label.position = Vector2.ZERO
	else:
		title_label.custom_minimum_size = banner_size
		title_label.position = -(banner_size / 2.0)

	# 4. Add the Objective Text below the banner
	var obj_label = phase_banner.get_node_or_null("ObjectiveText")
	if obj_label == null:
		obj_label = Label.new()
		obj_label.name = "ObjectiveText"
		obj_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		obj_label.add_theme_font_size_override("font_size", 26)
		obj_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5)) # Soft Gold
		obj_label.add_theme_constant_override("outline_size", 6)
		obj_label.add_theme_color_override("font_outline_color", Color.BLACK)
		phase_banner.add_child(obj_label)
		
	if phase_banner is Control:
		obj_label.position = Vector2(0, banner_size.y + 5)
		obj_label.size.x = banner_size.x
	else:
		obj_label.position = Vector2(-(banner_size.x / 2.0), (banner_size.y / 2.0) + 5)
		obj_label.custom_minimum_size.x = banner_size.x
		
	obj_label.modulate.a = 1.0 # Ensure it's fully visible from the start
		
	var custom_obj: String = custom_objective_text.strip_edges()
	match map_objective:
		Objective.ROUT_ENEMY:
			if custom_obj != "":
				obj_label.text = "- Turn " + str(current_turn) + " — " + custom_obj + " -"
			else:
				obj_label.text = "- Turn " + str(current_turn) + " : Rout the Enemy -"
		Objective.SURVIVE_TURNS:
			if custom_obj != "":
				obj_label.text = "- " + custom_obj + " (" + str(current_turn) + " / " + str(turn_limit) + ") -"
			else:
				obj_label.text = "- Survive: Turn " + str(current_turn) + " / " + str(turn_limit) + " -"
		Objective.DEFEND_TARGET:
			if custom_obj != "":
				obj_label.text = "- " + custom_obj + " — Turn " + str(current_turn) + " / " + str(turn_limit) + " -"
			else:
				obj_label.text = "- Defend Target: Turn " + str(current_turn) + " / " + str(turn_limit) + " -"
	
	# 5. Play Sound and Animate Opacity
	var tween = create_tween()
	
	# Fast fade in (0.2s)
	tween.tween_property(phase_banner, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Brief hold before ribbon unroll (tighter pacing than a long static beat)
	tween.tween_interval(1.2) 
	
	# Trigger the unfolding animation AND the sound!
	tween.tween_callback(func():
		if phase_banner.has_method("play"):
			phase_banner.play("default")
			
		# Play the sound exactly as the ribbon unrolls! (And only here!)
		if phase_sound != null and phase_sound.stream != null:
			phase_sound.play()
	)
	
	# Wait JUST long enough for the unroll animation to finish playing (e.g., 0.5s)
	tween.tween_interval(0.5) 
	
	# Snap it out of existence quickly! (0.15s)
	tween.tween_property(phase_banner, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	await tween.finished
	phase_banner.visible = false
			
func update_unit_info_panel() -> void:
	var target_unit: Node2D = null
	var hover_unit: Node2D = null
	var show_cursor_unit_row: bool = false

	if current_state == player_state and player_state.active_unit != null:
		target_unit = player_state.active_unit
		hover_unit = get_occupant_at(cursor_grid_pos)
		if hover_unit != null and hover_unit != target_unit and hover_unit.get("data") != null:
			show_cursor_unit_row = true
	else:
		target_unit = get_occupant_at(cursor_grid_pos)

	var terrain = get_terrain_data(cursor_grid_pos)
	var terrain_bb = "\n[color=yellow]%s[/color] [color=gray]|[/color] [color=cyan]DEF +%d[/color] [color=gray]|[/color] [color=chartreuse]AVO +%d%%[/color]" % [terrain["name"], terrain["def"], terrain["avo"]]

	if target_unit == null:
		unit_name_label.text = "Map Tile"
		unit_hp_label.text = ""
		unit_stats_label.text = "[center]TERRAIN INFO" + terrain_bb + "[/center]"
		unit_portrait.visible = false
		open_inv_button.visible = false
		unit_info_panel.visible = true
		return
		
	if target_unit.get("data") != null:
		var current_xp = target_unit.experience
		var required_xp = target_unit.get_exp_required() if target_unit.has_method("get_exp_required") else 100
		
		var active_tag: String = ""
		if current_state == player_state and player_state.active_unit == target_unit:
			if target_unit.is_exhausted:
				active_tag = " [Turn done]"
			elif target_unit.has_moved:
				active_tag = " [Moved — act]"
			else:
				active_tag = " [ACTIVE]"
		unit_name_label.text = target_unit.unit_name + active_tag + " (Lv " + str(target_unit.level) + " | XP: " + str(current_xp) + " / " + str(required_xp) + ")"
		unit_hp_label.text = "HP: " + str(target_unit.current_hp) + " / " + str(target_unit.max_hp)

		var display_def = target_unit.defense
		var display_res = target_unit.resistance
		var def_color = "white"
		
		if target_unit.get("is_defending") == true:
			display_def += target_unit.defense_bonus
			display_res += target_unit.defense_bonus
			def_color = "lime"
			
		# --- POISE BREAK UI REFLECTION ---
		var is_staggered = target_unit.get_meta("is_staggered_this_combat", false)
		if is_staggered:
			display_def = int(float(display_def) * 0.5)
			display_res = int(float(display_res) * 0.5)
			def_color = "red" # Show them it's dangerously low!

		var u_class = target_unit.get("unit_class_name") if target_unit.get("unit_class_name") != null else "Structure"
		var u_move = target_unit.get("move_range") if target_unit.get("move_range") != null else 0
		var u_str = target_unit.get("strength") if target_unit.get("strength") != null else 0
		var u_mag = target_unit.get("magic") if target_unit.get("magic") != null else 0
		var u_spd = target_unit.get("speed") if target_unit.get("speed") != null else 0
		var u_agi = target_unit.get("agility") if target_unit.get("agility") != null else 0

		var s = "[center]"
		if current_state == player_state and player_state.active_unit == target_unit:
			s += "[color=cyan][b]Selected unit[/b][/color]\n"
		var coop_own_line: String = _mock_coop_unit_ownership_bbcode_line_for_panel(target_unit)
		if coop_own_line != "":
			s += coop_own_line
		s += "[color=gray]Class:[/color] %s [color=gray]|[/color] [color=gray]Move:[/color] %d\n" % [u_class, u_move]
		s += "[color=gray]------------------------------------[/color]\n"
		s += "[color=coral]STR:[/color] %d  [color=orchid]MAG:[/color] %d  [color=skyblue]SPD:[/color] %d\n" % [u_str, u_mag, u_spd]
		s += "[color=palegreen]DEF:[/color] [color=%s]%d[/color]  [color=aquamarine]RES:[/color] [color=%s]%d[/color]  [color=wheat]AGI:[/color] %d\n" % [def_color, display_def, def_color, display_res, u_agi]
		
		# --- POISE HUD ADDITION ---
		var u_poise = "?"
		if target_unit.has_method("get_current_poise"):
			u_poise = str(target_unit.get_current_poise()) + "/" + str(target_unit.get_max_poise())
		s += "[color=gold]POISE:[/color] %s\n" % [u_poise]
		
		if target_unit.has_meta("is_burning") and target_unit.get_meta("is_burning") == true:
			s += "[color=orangered][b]BURNING[/b][/color] — fire damage after enemy phase\n"
		
		# --- UPDATED: WEAPON INFO WITH DURABILITY ---
		if target_unit.equipped_weapon != null:
			var wpn = target_unit.equipped_weapon
			var d_cur = wpn.get("current_durability") if wpn.get("current_durability") != null else 0
			var d_max = wpn.get("max_durability") if wpn.get("max_durability") != null else 0
			s += "[color=gray]Eqp:[/color] [color=yellow]%s[/color] [color=gray](Dur: %d/%d)[/color]\n" % [wpn.weapon_name, d_cur, d_max]
		else:
			s += "[color=gray]Eqp: Unarmed[/color]\n"

		s += UnitTraitsLib.bbcode_section(UnitTraitsLib.trait_lines_from_unit(target_unit))

		if show_cursor_unit_row and is_instance_valid(hover_unit) and hover_unit.get("data") != null:
			s += "[color=gray]————————————————————[/color]\n"
			s += "[color=gold][b]Under cursor[/b][/color]: [color=white]%s[/color]  HP %d/%d\n" % [
				hover_unit.unit_name, hover_unit.current_hp, hover_unit.max_hp
			]
			var coop_hover_line: String = _mock_coop_unit_ownership_bbcode_line_for_panel(hover_unit)
			if coop_hover_line != "":
				s += coop_hover_line
			if hover_unit.get_parent() == enemy_container and hover_unit.data.get("is_recruitable") == true:
				s += "[color=chartreuse]Recruitable — use Talk in combat preview when available.[/color]\n"

		s += terrain_bb + "[/center]"
		unit_stats_label.text = s

		if target_unit.data != null and target_unit.data.get("portrait") != null:
			unit_portrait.texture = target_unit.data.portrait
			unit_portrait.visible = true
		
		var is_friendly = (target_unit.get_parent() == player_container or target_unit.get_parent() == ally_container)
		open_inv_button.visible = (target_unit.get_parent() == player_container)
		if support_btn: support_btn.visible = is_friendly
		unit_info_panel.visible = true
	else:
		unit_info_panel.visible = false
				
func _on_unit_leveled_up(unit: Node2D, gains: Dictionary) -> void:
	apply_stat_gains(unit, gains)
	
	await run_theatrical_stat_reveal(unit, "LEVEL UP: " + unit.unit_name, gains)
	update_unit_info_panel()
	
func _resolve_tactical_ability_name(attacker: Node2D) -> String:
	var ability_raw: Variant = attacker.get("ability")
	var unit_abil: String = str(ability_raw) if ability_raw != null else ""
	if unit_abil == "Shove" or unit_abil == "Grapple Hook" or unit_abil == "Fire Trap":
		return unit_abil
	# Everyone picks a passive at creation; class-granted tactics (Fire Trap) use the same forecast slot as Shove/Pull.
	var may_use_class_tac: bool = unit_abil.is_empty() or PASSIVE_FORECAST_SLOT_ABILITIES.has(unit_abil)
	if may_use_class_tac:
		var cls: Variant = attacker.get("active_class_data")
		if cls != null and cls is ClassData:
			var cta: String = (cls as ClassData).class_tactical_ability
			if cta != null and not cta.is_empty():
				return cta
	return ""


func _attacker_has_attack_skill(attacker: Node2D, skill_name: String) -> bool:
	var abil: Variant = attacker.get("ability")
	if str(abil) == skill_name:
		return true
	var cls: Variant = attacker.get("active_class_data")
	if cls != null and cls is ClassData:
		var cd: ClassData = cls as ClassData
		if cd.class_combat_ability == skill_name or cd.class_combat_ability_b == skill_name:
			return true
	return false


func _is_friendly_unit_on_field(u: Node2D) -> bool:
	if u == null or not is_instance_valid(u):
		return false
	var p: Node = u.get_parent()
	return p == player_container or (ally_container != null and p == ally_container)


func _ensure_novice_blank_slate_roll(attacker: Node2D) -> void:
	if attacker.has_meta(META_ROOKIE_NOVICE_DONE):
		return
	var _ucn: Variant = attacker.get("unit_class_name")
	var job: String = str(_ucn) if _ucn != null else ""
	if job != "Novice":
		return
	attacker.set_meta(META_ROOKIE_NOVICE_DONE, true)
	var r: int = randi() % 3
	if r == 0:
		attacker.set_meta(META_ROOKIE_NOVICE_HIT, 10)
		add_combat_log(attacker.unit_name + ": Blank Slate — sharp instincts! (+Hit this battle)", "cyan")
	elif r == 1:
		attacker.set_meta(META_ROOKIE_NOVICE_DMG, 4)
		add_combat_log(attacker.unit_name + ": Blank Slate — raw power! (+Damage this battle)", "cyan")
	else:
		attacker.set_meta(META_ROOKIE_NOVICE_CRIT, 8)
		add_combat_log(attacker.unit_name + ": Blank Slate — lucky streak! (+Crit this battle)", "cyan")


func _rookie_ordered_unique_roles(attacker: Node2D) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	var ujob_v: Variant = attacker.get("unit_class_name")
	var ujob: String = str(ujob_v) if ujob_v != null else ""
	if UnitTraitsLib.ROOKIE_JOB_NAMES.has(ujob):
		out.append(ujob)
		seen[ujob] = true
	var legs_v: Variant = attacker.get("rookie_legacies")
	if legs_v is Array:
		for lid in legs_v:
			var jn: String = UnitTraitsLib.rookie_job_name_for_legacy_id(str(lid))
			if jn.is_empty() or seen.has(jn):
				continue
			out.append(jn)
			seen[jn] = true
	return out


func _rookie_mods_for_job_role(attacker: Node2D, defender: Node2D, is_magic: bool, _wpn: WeaponData, role: String, apply_effects: bool) -> Dictionary:
	var part: Dictionary = {"hit": 0, "dmg": 0, "crit": 0, "log": ""}
	match role:
		"Recruit":
			if not attacker.has_meta(META_ROOKIE_RECRUIT_DRILL):
				part["hit"] = 12
				part["log"] = "Drill Formation (+Hit)."
				if apply_effects:
					attacker.set_meta(META_ROOKIE_RECRUIT_DRILL, true)
		"Villager":
			if attacker.current_hp < attacker.max_hp:
				var last_t: int = int(attacker.get_meta(META_ROOKIE_VILLAGER_LAST_PROC_TURN, -1))
				if last_t < current_turn:
					part["dmg"] = 5
					part["crit"] = 10
					part["log"] = "Desperate Measure (+dmg/crit)."
					if apply_effects:
						attacker.set_meta(META_ROOKIE_VILLAGER_LAST_PROC_TURN, current_turn)
		"Urchin":
			if defender.current_hp >= defender.max_hp:
				part["hit"] = 8
				part["dmg"] = 4
				part["log"] = "Pickpocket's Eye vs. full HP."
		"Apprentice":
			if is_magic and _wpn != null:
				var wt: int = int(_wpn.weapon_type)
				if wt == WeaponData.WeaponType.TOME or wt == WeaponData.WeaponType.DARK_TOME:
					var n: int = int(attacker.get_meta(META_ROOKIE_APPRENTICE_HITS, 0))
					if n >= 2 and (n % 3) == 2:
						part["dmg"] = 6
						part["log"] = "Cantrip Surge (3rd tome hit)."
		"Novice":
			part["hit"] = int(attacker.get_meta(META_ROOKIE_NOVICE_HIT, 0))
			part["dmg"] = int(attacker.get_meta(META_ROOKIE_NOVICE_DMG, 0))
			part["crit"] = int(attacker.get_meta(META_ROOKIE_NOVICE_CRIT, 0))
			if part["hit"] > 0 or part["dmg"] > 0 or part["crit"] > 0:
				part["log"] = "Blank Slate."
	return part


## apply_effects: true = combat resolution (sets meta, logs). false = forecast preview only (no consumption).
func _rookie_passive_mods_internal(attacker: Node2D, defender: Node2D, is_magic: bool, wpn: WeaponData, apply_effects: bool) -> Dictionary:
	var merged: Dictionary = {"hit": 0, "dmg": 0, "crit": 0, "log": ""}
	if not _is_friendly_unit_on_field(attacker) or defender.get_parent() != enemy_container:
		return merged
	var ujob_v2: Variant = attacker.get("unit_class_name")
	var ujob_s: String = str(ujob_v2) if ujob_v2 != null else ""
	var legs_v2: Variant = attacker.get("rookie_legacies")
	var legs_arr: Array = legs_v2 if legs_v2 is Array else []
	if ujob_s == "Novice" or legs_arr.has(UnitTraitsLib.LEGACY_ID_NOVICE):
		_ensure_novice_blank_slate_roll(attacker)
	var roles: Array[String] = _rookie_ordered_unique_roles(attacker)
	var log_parts: PackedStringArray = PackedStringArray()
	for role in roles:
		var part: Dictionary = _rookie_mods_for_job_role(attacker, defender, is_magic, wpn, role, apply_effects)
		merged["hit"] = int(merged["hit"]) + int(part.get("hit", 0))
		merged["dmg"] = int(merged["dmg"]) + int(part.get("dmg", 0))
		merged["crit"] = int(merged["crit"]) + int(part.get("crit", 0))
		var lg: String = str(part.get("log", ""))
		if not lg.is_empty():
			log_parts.append(lg)
	if log_parts.size() > 0:
		merged["log"] = " ".join(log_parts)
	return merged


func _forecast_rookie_class_passive_mods(attacker: Node2D, defender: Node2D, is_magic: bool, wpn: WeaponData) -> Dictionary:
	return _rookie_passive_mods_internal(attacker, defender, is_magic, wpn, false)


func _compute_rookie_class_passive_mods(attacker: Node2D, defender: Node2D, is_magic: bool, wpn: WeaponData) -> Dictionary:
	return _rookie_passive_mods_internal(attacker, defender, is_magic, wpn, true)


func _rookie_register_apprentice_magic_hit(attacker: Node2D, wpn: WeaponData, is_magic: bool, attack_connected: bool) -> void:
	if not attack_connected or not _is_friendly_unit_on_field(attacker):
		return
	var rl: Variant = attacker.get("rookie_legacies")
	var legs: Array = rl if rl is Array else []
	var ap_uj: Variant = attacker.get("unit_class_name")
	var ap_job: String = str(ap_uj) if ap_uj != null else ""
	if ap_job != "Apprentice" and not legs.has(UnitTraitsLib.LEGACY_ID_APPRENTICE):
		return
	if not is_magic or wpn == null:
		return
	var wt: int = int(wpn.weapon_type)
	if wt != WeaponData.WeaponType.TOME and wt != WeaponData.WeaponType.DARK_TOME:
		return
	var n: int = int(attacker.get_meta(META_ROOKIE_APPRENTICE_HITS, 0))
	attacker.set_meta(META_ROOKIE_APPRENTICE_HITS, n + 1)


func _reset_rookie_battle_tracking() -> void:
	var keys: Array[String] = [
		META_ROOKIE_RECRUIT_DRILL,
		META_ROOKIE_APPRENTICE_HITS,
		META_ROOKIE_VILLAGER_LAST_PROC_TURN,
		META_ROOKIE_NOVICE_DONE,
		META_ROOKIE_NOVICE_HIT,
		META_ROOKIE_NOVICE_DMG,
		META_ROOKIE_NOVICE_CRIT,
	]
	for cont in [player_container, ally_container]:
		if cont == null:
			continue
		for c in cont.get_children():
			var u: Node2D = c as Node2D
			if not is_instance_valid(u) or u.is_queued_for_deletion():
				continue
			for k in keys:
				if u.has_meta(k):
					u.remove_meta(k)


func show_combat_forecast(attacker: Node2D, defender: Node2D) -> Array:
	if attacker == null or defender == null:
		return []

	if is_local_player_command_blocked_for_mock_coop_unit(attacker):
		return []

	if attacker.get("equipped_weapon") == null:
		return []

	# Defender can be forecasted even if unarmed, but must still be a combat unit
	if attacker.get("strength") == null or attacker.get("magic") == null:
		return []
	if defender.get("strength") == null or defender.get("magic") == null:
		return []

	var atk_wpn = attacker.equipped_weapon
	var def_wpn = defender.equipped_weapon
	
	# Adjacency check
	var atk_adj = get_adjacency_bonus(attacker)
	var def_adj = get_adjacency_bonus(defender)
	
	_ensure_forecast_support_labels()
	if forecast_atk_support_label:
		forecast_atk_support_label.text = _get_forecast_support_text(attacker)
	if forecast_def_support_label:
		forecast_def_support_label.text = _get_forecast_support_text(defender)
		
	var atk_terrain = get_terrain_data(get_grid_pos(attacker))
	var def_terrain = get_terrain_data(get_grid_pos(defender))
	
	var atk_might = atk_wpn.might if atk_wpn else 0
	var atk_hit_bonus = atk_wpn.hit_bonus if atk_wpn else 0
	var def_might = def_wpn.might if def_wpn else 0
	var def_hit_bonus = def_wpn.hit_bonus if def_wpn else 0

	# --- THE BROKEN PENALTY ---
	if atk_wpn and atk_wpn.get("current_durability") != null and atk_wpn.current_durability <= 0:
		atk_might /= 2
		atk_hit_bonus /= 2
		
	if def_wpn and def_wpn.get("current_durability") != null and def_wpn.current_durability <= 0:
		def_might /= 2
		def_hit_bonus /= 2
	# -------------------------------

	var atk_is_magic = atk_wpn.damage_type == WeaponData.DamageType.MAGIC if atk_wpn else false
	var def_is_magic = def_wpn.damage_type == WeaponData.DamageType.MAGIC if def_wpn else false

	var atk_offense = attacker.magic if atk_is_magic else attacker.strength
	var def_offense = defender.magic if def_is_magic else defender.strength
	
	# Apply Defender's Adjacency to their Defense
	var atk_defense_target = defender.resistance if atk_is_magic else defender.defense
	if defender.get("is_defending") == true:
		atk_defense_target += defender.defense_bonus	
	atk_defense_target += def_adj["def"] 
	atk_defense_target += def_terrain["def"]

	# Apply Attacker's Adjacency to their Defense
	var def_defense_target = attacker.resistance if def_is_magic else attacker.defense	
	def_defense_target += atk_adj["def"] 
	def_defense_target += atk_terrain["def"]
	
	var advantage = get_triangle_advantage(attacker, defender)
	var atk_tri_dmg = advantage * 1
	var atk_tri_hit = advantage * 15
	var def_tri_dmg = (advantage * -1) * 1
	var def_tri_hit = (advantage * -1) * 15

	# Support-combat and relationship web (forecast must match resolution)
	var atk_sup: Dictionary = get_support_combat_bonus(attacker)
	var def_sup: Dictionary = get_support_combat_bonus(defender)
	var atk_rel: Dictionary = get_relationship_combat_modifiers(attacker)
	var def_rel: Dictionary = get_relationship_combat_modifiers(defender)
	var atk_dmg = max(0, (atk_offense + atk_might + atk_tri_dmg) - atk_defense_target) + atk_rel.get("dmg_bonus", 0)
	var def_dmg = max(0, (def_offense + def_might + def_tri_dmg) - def_defense_target) + def_rel.get("dmg_bonus", 0)
	var atk_hit: int = clamp(80 + atk_hit_bonus + atk_tri_hit + atk_adj["hit"] + atk_sup["hit"] - def_sup["avo"] + atk_rel["hit"] - def_rel["avo"] + (attacker.agility * 2) - (defender.speed * 2) - def_terrain["avo"], 0, 100)
	var atk_crit: int = clamp(attacker.agility / 2 + atk_rel["crit_bonus"] - def_sup["crit_avo"], 0, 100)
	var def_hit: int = clamp(80 + def_hit_bonus + def_tri_hit + def_adj["hit"] + def_sup["hit"] - atk_sup["avo"] + def_rel["hit"] - atk_rel["avo"] + (defender.agility * 2) - (attacker.speed * 2) - atk_terrain["avo"], 0, 100)
	var def_crit: int = clamp(defender.agility / 2 + def_rel["crit_bonus"] - atk_sup["crit_avo"], 0, 100)

	if atk_wpn == null or atk_wpn.get("is_healing_staff") != true:
		var fr_rookie: Dictionary = _forecast_rookie_class_passive_mods(attacker, defender, atk_is_magic, atk_wpn)
		atk_hit = clampi(atk_hit + int(fr_rookie.get("hit", 0)), 0, 100)
		atk_dmg = max(0, atk_dmg + int(fr_rookie.get("dmg", 0)))
		atk_crit = clampi(atk_crit + int(fr_rookie.get("crit", 0)), 0, 100)

	# UI Updates (columns: left = attacker / you, right = defender / target)
	forecast_atk_name.text = "ATK: " + attacker.unit_name
	forecast_atk_weapon.text = atk_wpn.weapon_name if atk_wpn else "Unarmed"
	forecast_atk_hp.text = "HP: %d / %d" % [attacker.current_hp, attacker.max_hp]
	
	forecast_def_name.text = defender.unit_name
	forecast_def_weapon.text = def_wpn.weapon_name if def_wpn else "Unarmed"
	forecast_def_hp.text = "HP: %d / %d" % [defender.current_hp, defender.max_hp]
	
	# --- RESET UI MODULATES ---
	forecast_atk_dmg.modulate = Color.WHITE
	forecast_atk_dmg.scale = Vector2.ONE
	
	# --- HEALING VS ATTACKING LOGIC ---
	if atk_wpn != null and atk_wpn.get("is_healing_staff") == true:
		forecast_def_name.text = "Target: " + defender.unit_name
		var heal_amount = attacker.magic + atk_wpn.might
		forecast_atk_dmg.text = "HEAL: " + str(heal_amount)
		forecast_atk_hit.text = "HIT: 100%"
		forecast_atk_crit.text = "CRIT: 0%"
		
		forecast_def_dmg.text = "Damage: —"
		forecast_def_hit.text = ""
		forecast_def_crit.text = ""
		
		forecast_atk_adv.text = ""
		forecast_def_adv.text = ""
		forecast_atk_double.text = ""
		forecast_def_double.text = ""
	else:
		# Standard Attack UI
		forecast_atk_dmg.text = "DMG: " + str(atk_dmg)
		forecast_atk_hit.text = "HIT: " + str(atk_hit) + "%"
		forecast_atk_crit.text = "CRIT: " + str(atk_crit) + "%"
		
		# --- CRITICAL FLASH TRIGGER ---
		if crit_flash_tween: crit_flash_tween.kill()
		if atk_crit > 15:
			crit_flash_tween = create_tween().set_loops()
			crit_flash_tween.tween_property(forecast_atk_dmg, "modulate", Color.YELLOW, 0.2)
			crit_flash_tween.tween_property(forecast_atk_dmg, "modulate", Color.WHITE, 0.2)
			crit_flash_tween.parallel().tween_property(forecast_atk_dmg, "scale", Vector2(1.15, 1.15), 0.2)
			crit_flash_tween.set_trans(Tween.TRANS_SINE)
		
		var def_is_healer = def_wpn != null and def_wpn.get("is_healing_staff") == true
		if defender.get_parent() == enemy_container:
			forecast_def_name.text = "DEF: " + defender.unit_name
		else:
			forecast_def_name.text = "Target: " + defender.unit_name
		
		if def_wpn == null or def_is_healer or not is_in_range(defender, attacker):
			forecast_def_dmg.text = "Counter: none"
			forecast_def_hit.text = ""
			forecast_def_crit.text = ""
			forecast_def_double.text = ""
		else:
			forecast_def_dmg.text = "Counter dmg: " + str(def_dmg)
			forecast_def_hit.text = "Counter hit: " + str(def_hit) + "%"
			forecast_def_crit.text = "Counter crit: " + str(def_crit) + "%"
			var def_doubles = (defender.speed - attacker.speed) >= 4
			forecast_def_double.text = "×2" if def_doubles else ""

		# Advantage Indicators
		if advantage == 1:
			forecast_atk_adv.text = "Adv."
			forecast_atk_adv.modulate = Color.CYAN
			forecast_def_adv.text = "Disadv."
			forecast_def_adv.modulate = Color.TOMATO
		elif advantage == -1:
			forecast_atk_adv.text = "Disadv."
			forecast_atk_adv.modulate = Color.TOMATO
			forecast_def_adv.text = "Adv."
			forecast_def_adv.modulate = Color.CYAN
		else:
			forecast_atk_adv.text = ""
			forecast_def_adv.text = ""
		
		# --- POISE BREAK WARNING ---
		var raw_power = atk_offense + atk_might
		var poise_dmg = raw_power
		if atk_wpn and atk_wpn.get("weapon_type") == WeaponData.WeaponType.AXE:
			poise_dmg = int(float(poise_dmg) * 1.5)
			
		var def_cur_poise = defender.get_current_poise() if defender.has_method("get_current_poise") else 999
		
		if def_cur_poise <= 0:
			forecast_def_adv.text = "GUARD BROKEN"
			forecast_def_adv.modulate = Color.RED
		elif (def_cur_poise - poise_dmg) <= 0:
			forecast_def_adv.text = "STAGGER RISK!"
			forecast_def_adv.modulate = Color.ORANGE
			
		var atk_doubles = (attacker.speed - defender.speed) >= 4
		forecast_atk_double.text = "×2" if atk_doubles else ""

	# --- FIGURE-8 ANIMATION TRIGGER ---
	if forecast_atk_double.text != "" or forecast_def_double.text != "":
		_start_double_animation()
	else:
		if figure_8_tween: figure_8_tween.kill()

	var talk_visible: bool = false
	if forecast_talk_btn != null:
		if defender.get_parent() == enemy_container and defender.get("data") != null and defender.data.get("is_recruitable") == true:
			forecast_talk_btn.visible = true
			talk_visible = true
			forecast_talk_btn.tooltip_text = "Recruit this unit through dialogue (ends this unit's turn)."
		else:
			forecast_talk_btn.visible = false
			forecast_talk_btn.tooltip_text = ""
	
	# --- ABILITY BUTTON LOGIC ---
	if forecast_ability_btn:
		forecast_ability_btn.visible = false # Hide by default
		
		var abil: String = _resolve_tactical_ability_name(attacker)
		if abil == "Shove" or abil == "Grapple Hook" or abil == "Fire Trap":
			var cooldown = attacker.get_meta("ability_cooldown", 0)
			
			forecast_ability_btn.visible = true
			if cooldown > 0:
				forecast_ability_btn.text = abil + " (CD: " + str(cooldown) + ")"
				forecast_ability_btn.disabled = true
			else:
				forecast_ability_btn.text = "USE " + abil.to_upper()
				forecast_ability_btn.disabled = false
	
	if forecast_atk_support_label:
		forecast_atk_support_label.visible = true
	if forecast_def_support_label:
		forecast_def_support_label.visible = true
	
	var fc_btn: Button = forecast_panel.get_node_or_null("ConfirmButton") as Button
	if fc_btn != null:
		if atk_wpn != null and atk_wpn.get("is_healing_staff") == true:
			fc_btn.text = "Heal"
		elif atk_wpn != null and atk_wpn.get("is_buff_staff") == true:
			fc_btn.text = "Buff"
		elif atk_wpn != null and atk_wpn.get("is_debuff_staff") == true:
			fc_btn.text = "Debuff"
		else:
			fc_btn.text = "Attack"
	
	if forecast_instruction_label:
		if atk_wpn != null and atk_wpn.get("is_healing_staff") == true:
			forecast_instruction_label.text = "Confirm to heal. Cancel or right-click to go back."
		else:
			var ins := "Left: your strike · Right: enemy counter (if any). Click the defender's tile to commit."
			if talk_visible:
				ins += " Talk = recruit (ends turn)."
			forecast_instruction_label.text = ins
	
	if forecast_reaction_label:
		var rsum: String = _build_forecast_reaction_summary(attacker, defender, atk_wpn)
		if rsum.is_empty():
			forecast_reaction_label.visible = false
			forecast_reaction_label.text = ""
		else:
			forecast_reaction_label.text = rsum
			forecast_reaction_label.visible = true
	
	if is_instance_valid(target_cursor):
		target_cursor.z_index = 80
		# Match main Cursor: parent sits on tile top-left; child Sprite2D (~half cell + texture offset) centers the art.
		target_cursor.global_position = defender.global_position
		target_cursor.visible = true
	
	forecast_panel.visible = true
	# --- UPDATE THE AWAIT ---
	# We must capture BOTH variables from the array the signal now returns!
	var result_array = await self.forecast_resolved
	var action = result_array[0]
	var used_ability = result_array[1]
	
	# --- CLEANUP AND RESET ---
	if figure_8_tween: figure_8_tween.kill()
	if crit_flash_tween: crit_flash_tween.kill()
	
	if atk_double_origin != Vector2.ZERO:
		forecast_atk_double.position = atk_double_origin
		forecast_def_double.position = def_double_origin
		
	forecast_atk_dmg.modulate = Color.WHITE
	forecast_atk_dmg.scale = Vector2.ONE
	
	if forecast_atk_support_label:
		forecast_atk_support_label.visible = false
	if forecast_def_support_label:
		forecast_def_support_label.visible = false
	if forecast_reaction_label:
		forecast_reaction_label.visible = false
		forecast_reaction_label.text = ""
	
	forecast_panel.visible = false
	if is_instance_valid(target_cursor):
		target_cursor.visible = false
	return [action, used_ability]
	
func _on_forecast_confirm() -> void:
	emit_signal("forecast_resolved", "confirm", false)

func _on_forecast_cancel() -> void:
	emit_signal("forecast_resolved", "cancel", false)

func _on_forecast_talk() -> void:
	emit_signal("forecast_resolved", "talk", false)
	
func _on_forecast_ability_pressed() -> void:
	emit_signal("forecast_resolved", "confirm", true) # Returns confirm, but flags the ability!
	
func execute_combat(attacker: Node2D, defender: Node2D, trigger_active_ability: bool = false) -> void:
	# --- SAFETY CHECKS ---
	if not _is_valid_combat_unit(attacker):
		push_warning("execute_combat aborted: attacker is not a valid combat unit.")
		return

	if not _is_valid_combat_unit(defender):
		push_warning("execute_combat aborted: defender is not a valid combat unit.")
		return

	var wpn = attacker.equipped_weapon
	if wpn == null:
		push_warning("execute_combat aborted: attacker has no equipped weapon.")
		return

	_coop_qte_tick_reset_for_execute_combat()

	var is_staff: bool = wpn != null and (
		wpn.get("is_healing_staff") == true
		or wpn.get("is_buff_staff") == true
		or wpn.get("is_debuff_staff") == true
	)

	# ==========================================
	# --- FIRST COMBAT / BOSS QUOTES ---
	# ==========================================
	if not is_staff:
		# 1. Did the Player attack a Boss/Recruitable Enemy?
		if defender.get_parent() == enemy_container and not defender.has_meta("has_spoken_quote"):
			if defender.get("data") != null and "pre_battle_quote" in defender.data and defender.data.pre_battle_quote.size() > 0:
				defender.set_meta("has_spoken_quote", true)
				var port = defender.data.portrait
				await play_cinematic_dialogue(defender.unit_name, port, defender.data.pre_battle_quote)

		# 2. Did the Boss/Recruitable Enemy attack the Player first?
		elif attacker.get_parent() == enemy_container and not attacker.has_meta("has_spoken_quote"):
			if attacker.get("data") != null and "pre_battle_quote" in attacker.data and attacker.data.pre_battle_quote.size() > 0:
				attacker.set_meta("has_spoken_quote", true)
				var port = attacker.data.portrait
				await play_cinematic_dialogue(attacker.unit_name, port, attacker.data.pre_battle_quote)

		# 3. Boss Personal Dialogue (V1): special pre-attack line when playable attacks supported boss pair (once per battle).
		if defender.get_parent() == enemy_container and (attacker.get_parent() == player_container or (ally_container != null and attacker.get_parent() == ally_container)):
			var boss_id: String = _get_boss_dialogue_id(defender)
			var unit_id: String = _get_playable_dialogue_id(attacker)
			var play_key: String = boss_id + "|" + unit_id
			if not boss_id.is_empty() and not unit_id.is_empty() and not _boss_personal_dialogue_played.get(play_key, false):
				var line: String = _get_boss_personal_line(boss_id, unit_id, "pre_attack")
				if not line.is_empty():
					_boss_personal_dialogue_played[play_key] = true
					add_combat_log(defender.unit_name + ": " + line, "gold")
					var snippet: String = line.substr(0, 24) + ("…" if line.length() > 24 else "")
					spawn_loot_text(snippet, Color(1.0, 0.9, 0.5), defender.global_position + Vector2(32, -36))

	# --- SET THE COOLDOWN IF TRIGGERED ---
	if trigger_active_ability:
		attacker.set_meta("ability_cooldown", 3)

	_support_dual_strike_done_this_attack = false

	# --- PHASE 1: THE INITIATOR ATTACKS ---
	await _run_strike_sequence(attacker, defender, trigger_active_ability)

	# --- Phase 2: DUAL STRIKE (support partner bonus strike; one per attack exchange; no chain) ---
	if not is_staff and not _support_dual_strike_done_this_attack and is_instance_valid(defender) and _is_valid_combat_unit(defender) and defender.current_hp > 0 and is_instance_valid(attacker) and _is_valid_combat_unit(attacker) and attacker.current_hp > 0:
		var ctx: Dictionary = get_best_support_context(attacker)
		var partner: Node2D = ctx.get("partner", null) as Node2D
		var rank: int = int(ctx.get("rank", 0))
		if partner != null and rank >= 2 and ctx.get("can_react", false):
			var dual_chance: int = SUPPORT_DUAL_STRIKE_CHANCE_RANK3 if rank >= 3 else SUPPORT_DUAL_STRIKE_CHANCE_RANK2
			dual_chance += get_relationship_combat_modifiers(attacker).get("support_chance_bonus", 0)
			if randi() % 100 < dual_chance:
				_support_dual_strike_done_this_attack = true
				if DEBUG_SUPPORT_COMBAT:
					print("[SupportReaction] Dual Strike! ", partner.get("unit_name"), " -> bonus strike on ", defender.get("unit_name"))
				add_combat_log("Dual Strike!", "cyan")
				spawn_loot_text("Dual Strike!", Color(0.4, 0.9, 1.0), defender.global_position + Vector2(32, -28))
				_award_relationship_event(attacker, partner, "dual_strike", 1)
				await get_tree().create_timer(0.2, true, false, true).timeout
				# Re-validate before executing: do not run if partner or defender became invalid (e.g. death cleanup).
				if is_instance_valid(partner) and partner.current_hp > 0 and is_instance_valid(defender) and _is_valid_combat_unit(defender):
					await _run_strike_sequence(partner, defender, false, true)

	# --- PHASE 2: THE DEFENDER RETALIATES ---
	if not is_staff \
	and is_instance_valid(defender) \
	and _is_valid_combat_unit(defender) \
	and defender.current_hp > 0 \
	and is_instance_valid(attacker) \
	and _is_valid_combat_unit(attacker) \
	and attacker.current_hp > 0:

		# --- STAGGER CHECK ---
		if defender.get_meta("is_staggered_this_combat", false) == true:
			await get_tree().create_timer(0.6).timeout
			add_combat_log(defender.unit_name + "'s guard was broken! Cannot counter-attack!", "orange")
			spawn_loot_text("STAGGERED!", Color(1.0, 0.4, 0.0), defender.global_position + Vector2(32, -32))
		else:
			var def_wpn = defender.equipped_weapon
			var defender_is_staff: bool = def_wpn != null and (
				def_wpn.get("is_healing_staff") == true
				or def_wpn.get("is_buff_staff") == true
				or def_wpn.get("is_debuff_staff") == true
			)

			# Only retaliate if the defender is holding a real weapon
			if def_wpn != null and not defender_is_staff and is_in_range(defender, attacker):
				await get_tree().create_timer(0.5).timeout
				add_combat_log(defender.unit_name + " retaliates", "orange")
				await _run_strike_sequence(defender, attacker, false)

# ============================================================================
# 🤖 AI / DEVELOPER INSTRUCTIONS: HOW TO ADD NEW COMBAT ABILITIES 🤖
# ============================================================================
# To add a new skill/ability to the game, follow these 4 steps:
#
# 1. CREATE THE MINIGAME FUNCTION (Bottom of script)
#    - Create a new function: `func _run_my_new_ability(unit: Node2D) -> Type:`
#    - CRITICAL: Use `get_tree().paused = true` to freeze the battlefield.
#    - CRITICAL: Set `qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS` so the UI runs while paused.
#    - CRITICAL: Use `Time.get_ticks_msec()` or `get_tree().create_timer(X, true, false, true)` for timers so they don't break during the pause.
#
# 2. USE THE SCALING TRIGGER MATH
#    - When checking if the ability fires, use: `randi() % 100 < get_ability_trigger_chance(unit)`
#
# 3. HOOK INTO _run_strike_sequence
#    - OFFENSIVE ABILITIES (Buffs, Pierce, Combo prep): 
#      -> Hook into "PHASE B". Add `elif _attacker_has_attack_skill(attacker, "Name") and randi()...` (or match personal `ability` only if intended). Modify `force_hit`, `defense_stat`, etc.
#    - DEFENSIVE ABILITIES (Blocks, Counters, Dodges): 
#      -> Hook into "PHASE D". Add an `elif defender.get("ability") == "Name":` block. Set `defense_resolved_and_won = true` if the player succeeds so they don't take normal damage.
#    - MULTI-HITS & POST-ATTACK (Flurries, Lifesteal application): 
#      -> Hook into "PHASE E". Catch the variables set in Phase B and apply them during the actual damage step.
#
# 4. ADD TO MENUS
#    - Go to `CharacterCreation.gd` and add the string to `ability_dropdown`.
# ============================================================================
# ============================================================================
# 🤖 AI / DEVELOPER INSTRUCTIONS: HOW TO ADD NEW COMBAT ABILITIES USING COOLDOWNS
# ============================================================================
# The game now supports TWO types of abilities. Follow the steps below for the type you want to add.
#
# ---------------------------------------------------------
# TYPE 1: PASSIVE MINIGAME ABILITIES (RNG Triggered)
# (e.g., Bloodthirster, Shield Clash, Focused Strike)
# ---------------------------------------------------------
# 1. CREATE THE MINIGAME: Add a new function at the bottom of BattleField.gd (e.g., `func _run_my_ability(unit: Node2D) -> int:`).
#    - CRITICAL: Freeze the map using `get_tree().paused = true`.
#    - CRITICAL: Set your QTE UI layer to `process_mode = Node.PROCESS_MODE_ALWAYS`.
#    - CRITICAL: Use `Time.get_ticks_msec()` for timers so they don't break while paused.
#
# 2. HOOK INTO COMBAT MATH (`_run_strike_sequence`):
#    - OFFENSIVE: Add to PHASE B. Trigger via: `if _attacker_has_attack_skill(attacker, "Name") and randi() % 100 < get_ability_trigger_chance(attacker):`
#    - DEFENSIVE: Add to PHASE D. Set `defense_resolved_and_won = true` if the player blocks the attack.
#
# ---------------------------------------------------------
# TYPE 2: ACTIVE TACTICAL ABILITIES (Button Triggered + Cooldown)
# (e.g., Shove, Grapple Hook, Suplex)
# ---------------------------------------------------------
# 1. SHOW THE BUTTON: In `show_combat_forecast()`, find the `# --- ABILITY BUTTON LOGIC ---` block.
#    - Either set the unit's `ability` string, or set `class_tactical_ability` on ClassData when personal ability is empty.
#    - Add the name to `_resolve_tactical_ability_name()` / the forecast `if` alongside Shove & Grapple Hook.
#
# 2. ADD THE LOGIC: In `_run_strike_sequence()`, scroll to `PHASE G: FORCED MOVEMENT`.
#    - Add an `elif abil == "MyNewAbility":` block inside the `if force_active_ability:` check.
#    - Write the positional math (push, pull, swap, etc.) and update the `astar` grid solidity.
#
# ---------------------------------------------------------
# UNIVERSAL FINAL STEP: UPDATE CHARACTER CREATION
# ---------------------------------------------------------
# Go to `CharacterCreation.gd`:
# 1. Add a lore/mechanic explanation to the `ABILITY_DESCRIPTIONS` dictionary.
# 2. Add the string name to the `_setup_dropdowns()` function so the player can actually equip it!
# ============================================================================

# This helper function handles the actual math and animations for a single turn of strikes.
# When force_single_attack is true (e.g. Dual Strike), only one strike is performed.
func _run_strike_sequence(attacker: Node2D, defender: Node2D, force_active_ability: bool = false, force_single_attack: bool = false) -> void:
	if not _is_valid_combat_unit(attacker):
		push_warning("_run_strike_sequence aborted: attacker is not a valid combat unit.")
		return

	if not _is_valid_combat_unit(defender):
		push_warning("_run_strike_sequence aborted: defender is not a valid combat unit.")
		return

	if attacker.get("equipped_weapon") == null:
		push_warning("_run_strike_sequence aborted: attacker has no equipped weapon.")
		return

	_support_guard_used_this_sequence = false
	var will_double: bool = (attacker.speed - defender.speed) >= 4 and not force_single_attack
	var total_attacks: int = 2 if will_double else 1
	
	var atk_adj: Dictionary = get_adjacency_bonus(attacker)
	var def_adj: Dictionary = get_adjacency_bonus(defender)
	var atk_sup: Dictionary = get_support_combat_bonus(attacker)
	var def_sup: Dictionary = get_support_combat_bonus(defender)
	var atk_rel: Dictionary = get_relationship_combat_modifiers(attacker)
	var def_rel: Dictionary = get_relationship_combat_modifiers(defender)

	var _atk_terrain: Dictionary = get_terrain_data(get_grid_pos(attacker))
	var def_terrain: Dictionary = get_terrain_data(get_grid_pos(defender))
	
	# ==========================================
	# --- ALL QTE TEMP VARIABLES (GLOBAL SCOPE) ---
	# ==========================================
	var charge_bonus_damage: int = 0
	var charge_collision_target: Node2D = null
	var charge_collision_damage: int = 0
	var incoming_damage_multiplier: float = 1.0
	
	# Archer
	var deadeye_bonus_damage: int = 0
	var volley_extra_hits: int = 0
	var volley_damage_multiplier: float = 0.0
	var volley_spread_target: Node2D = null
	var rain_primary_bonus_damage: int = 0
	var rain_splash_targets: Array[Node2D] = []
	var rain_splash_damage: int = 0
	var rain_tail_unit: Node2D = null
	var rain_rear_extra_damage: int = 0
	
	# Mage + Mercenary
	var fireball_bonus_damage: int = 0
	var fireball_splash_targets: Array[Node2D] = []
	var fireball_splash_damage: int = 0
	var fireball_tail_unit: Node2D = null
	var fireball_tail_extra_damage: int = 0
	var meteor_storm_bonus_damage: int = 0
	var meteor_storm_splash_targets: Array[Node2D] = []
	var meteor_storm_splash_damage: int = 0
	var meteor_tail_unit: Node2D = null
	var meteor_tail_extra_damage: int = 0
	var flurry_strike_hits: int = 0
	var flurry_strike_damage_multiplier: float = 0.45
	var battle_cry_bonus_damage: int = 0
	var battle_cry_bonus_hit: int = 0
	var blade_tempest_bonus_damage: int = 0
	var blade_tempest_splash_targets: Array[Node2D] = []
	var blade_tempest_splash_damage: int = 0
	
	# Monk + Monster
	var chakra_bonus_damage: int = 0
	var chakra_bonus_hit: int = 0
	var chi_burst_bonus_damage: int = 0
	var chi_burst_splash_targets: Array[Node2D] = []
	var chi_burst_splash_damage: int = 0
	var frenzy_bonus_damage: int = 0
	var frenzy_bonus_hit: int = 0
	var _frenzy_hit_count: int = 0
	var frenzy_def_penalty: int = 0

	# Paladin + Spellblade
	var smite_bonus_damage: int = 0
	var smite_splash_targets: Array[Node2D] = []
	var smite_splash_damage: int = 0
	var sacred_judgment_bonus_damage: int = 0
	var sacred_judgment_splash_targets: Array[Node2D] = []
	var sacred_judgment_splash_damage: int = 0
	var flame_blade_bonus_damage: int = 0
	var elemental_convergence_bonus_damage: int = 0
	var elemental_convergence_splash_targets: Array[Node2D] = []
	var elemental_convergence_splash_damage: int = 0
	
	# Thief + Warrior
	var shadow_strike_bonus_damage: int = 0
	var shadow_strike_armor_pierce: float = 0.0
	var assassinate_crit_bonus: int = 0
	var shadow_step_bonus_damage: int = 0
	var power_strike_bonus_damage: int = 0
	var earthshatter_bonus_damage: int = 0
	var earthshatter_splash_targets: Array[Node2D] = []
	var earthshatter_splash_damage: int = 0
	
	# Promoted Mastery Temp Vars
	var shadow_pin_bonus_damage: int = 0
	var shadow_pin_speed_lock: bool = false
	var _weapon_shatter_triggered: bool = false
	var savage_toss_distance: int = 0
	var savage_toss_bonus_damage: int = 0
	var vanguards_rally_bonus_damage: int = 0
	var vanguards_rally_might_bonus: int = 0
	
	# Batch 2 Promoted Mastery Temp Vars
	var severing_strike_hits: int = 0
	var severing_strike_damage_multiplier: float = 0.5
	var aether_bind_sparks: int = 0
	var parting_shot_result: int = 0
	var _parting_shot_bonus_damage: int = 0
	var parting_shot_dodge: bool = false
	var soul_harvest_result: int = 0
	
	# Final Batch Promoted Mastery Temp Vars
	var celestial_choir_hits: int = 0
	var hellfire_result: int = 0
	var hellfire_bonus_damage: int = 0
	var ballista_shot_bonus_damage: int = 0
	var ballista_shot_pierce_targets: Array[Node2D] = []
	var ballista_shot_pierce_damage: int = 0
	var aegis_strike_bonus_damage: int = 0
	
	for i in range(total_attacks):
		# --- BUG FIX: Ensure both units survived the previous hits! ---
		if not is_instance_valid(defender) or defender.current_hp <= 0: break
		if not is_instance_valid(attacker) or attacker.current_hp <= 0: break
		
		# Clear splash targets for the new attack phase!
		rain_splash_targets.clear()
		rain_tail_unit = null
		rain_rear_extra_damage = 0
		volley_spread_target = null
		smite_splash_targets.clear()
		smite_splash_damage = 0
		fireball_splash_targets.clear()
		fireball_tail_unit = null
		fireball_tail_extra_damage = 0
		meteor_storm_splash_targets.clear()
		meteor_tail_unit = null
		meteor_tail_extra_damage = 0
		blade_tempest_splash_targets.clear()
		chi_burst_splash_targets.clear()
		sacred_judgment_splash_targets.clear()
		elemental_convergence_splash_targets.clear()
		earthshatter_splash_targets.clear()
		ballista_shot_pierce_targets.clear()
		charge_collision_target = null
		charge_collision_damage = 0
		
		var wpn = attacker.equipped_weapon
		var is_heal: bool = wpn != null and wpn.get("is_healing_staff") == true
		var is_buff: bool = wpn != null and wpn.get("is_buff_staff") == true
		var is_debuff: bool = wpn != null and wpn.get("is_debuff_staff") == true
		
		# ==========================================
		# PHASE A: STAFF LOGIC (Heal, Buff, Debuff)
		# ==========================================
		if is_heal or is_buff or is_debuff:
			var staff_orig_pos: Vector2 = attacker.global_position
			var staff_lunge_dir: Vector2 = (defender.global_position - attacker.global_position).normalized()
			var lunge_tween: Tween = create_tween()
			lunge_tween.tween_property(attacker, "global_position", staff_orig_pos + (staff_lunge_dir * 16.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			await lunge_tween.finished
			
			var popup_text: String = ""
			var text_color: Color = Color.WHITE
			
			if is_heal:
				# --- CLERIC: HEALING LIGHT ---
				var heal_amount: int = int(attacker.magic + wpn.might)
				
				var heal_trigger_chance: int = get_ability_trigger_chance(attacker)
				if _attacker_has_attack_skill(attacker, "Healing Light") and randi() % 100 < heal_trigger_chance:
					var _cqe := _coop_qte_alloc_event_id()
					var result: int
					if _coop_qte_mirror_active:
						result = _coop_qte_mirror_read_int(_cqe, 0)
					else:
						result = await QTEManager.run_healing_light_minigame(self, attacker)
						_coop_qte_capture_write(_cqe, result)
					if result == 1:
						ability_triggers_count += 1
						heal_amount = int(round(float(heal_amount) * 1.5))
						add_combat_log("HEALING LIGHT! Restorative power surges.", "lime")
					elif result == 2:
						ability_triggers_count += 1
						heal_amount = int(round(float(heal_amount) * 2.0))
						add_combat_log("PERFECT HEALING LIGHT! Divine restoration unleashed!", "gold")
					else:
						add_combat_log("Healing Light failed to amplify the spell.", "gray")

				defender.current_hp = min(defender.current_hp + heal_amount, defender.max_hp)
				if defender.get("health_bar") != null:
					var bar_tween: Tween = create_tween()
					bar_tween.tween_property(defender.health_bar, "value", defender.current_hp, 0.2)
				popup_text = "+" + str(heal_amount)
				text_color = Color(0.2, 1.0, 0.2)
				add_combat_log(attacker.unit_name + " healed " + defender.unit_name + ".", "lime")
				_add_support_points_and_check(attacker, defender, 1)
				_award_relationship_event(attacker, defender, "heal", 1)
				if _can_gain_mentorship(attacker, defender):
					_award_relationship_stat_event(attacker, defender, "mentorship", "heal_mentorship", 1)
				
			elif is_buff:
				var stat: String = wpn.affected_stat
				var amt: int = wpn.effect_amount
				defender.set(stat, defender.get(stat) + amt)
				popup_text = stat.to_upper() + " +" + str(amt)
				text_color = Color(0.2, 0.8, 1.0)
				add_combat_log(attacker.unit_name + " buffed " + defender.unit_name + "'s " + stat + ".", "cyan")
				_award_relationship_event(attacker, defender, "buff", 1)
				if _can_gain_mentorship(attacker, defender):
					_award_relationship_stat_event(attacker, defender, "mentorship", "buff_mentorship", 1)
				
			elif is_debuff:
				var stat: String = wpn.affected_stat
				var amt: int = wpn.effect_amount
				defender.set(stat, max(0, defender.get(stat) - amt))
				popup_text = stat.to_upper() + " -" + str(amt)
				text_color = Color(0.8, 0.2, 1.0)
				add_combat_log(attacker.unit_name + " debuffed " + defender.unit_name + "'s " + stat + ".", "purple")
			
			if level_up_sound.stream != null: level_up_sound.play() 
			
			var f_text = FloatingTextScene.instantiate()
			f_text.text_to_show = popup_text
			f_text.text_color = text_color
			add_child(f_text)
			f_text.global_position = defender.global_position + Vector2(32, -16)
			
			var return_tween: Tween = create_tween()
			return_tween.tween_property(attacker, "global_position", staff_orig_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await return_tween.finished
			
			await get_tree().create_timer(0.25).timeout
			break
		
		# ==========================================
		# PHASE B: COMBAT MATH & OFFENSIVE ABILITIES
		# ==========================================
		var advantage: int = get_triangle_advantage(attacker, defender)
		var tri_dmg: int = advantage * 1
		var tri_hit: int = advantage * 15
		
		var is_magic: bool = wpn.damage_type == WeaponData.DamageType.MAGIC if wpn else false
		var offense_stat: int = int(attacker.magic) if is_magic else int(attacker.strength)
		var defense_stat: int = int(defender.resistance) if is_magic else int(defender.defense)

		if defender.get("is_defending") == true:
			defense_stat += int(defender.defense_bonus)
		
		defense_stat += int(def_adj["def"]) + int(def_terrain["def"])
		
		# --- DEFENSIVE PENALTIES & BUFFS ---
		if is_magic:
			defense_stat += int(defender.get_meta("inner_peace_res_bonus_temp", 0))
			defense_stat += int(defender.get_meta("holy_ward_res_bonus_temp", 0))
			defense_stat -= int(defender.get_meta("frenzy_res_penalty_temp", 0))
		else:
			defense_stat += int(defender.get_meta("inner_peace_def_bonus_temp", 0))
			defense_stat -= int(defender.get_meta("frenzy_def_penalty_temp", 0))

		defense_stat = int(max(0, defense_stat))
		
		var focused_failed: bool = false
		var lifesteal_percent: float = 0.0
		var force_crit: bool = false
		var force_hit: bool = false 
		var combo_hits: int = 0 
		
		# --- GET DYNAMIC TRIGGER CHANCE ---
		var atk_trigger_chance: int = get_ability_trigger_chance(attacker)
		
		
		if attacker.get_parent() == player_container and defender.get_parent() == enemy_container:
			# FOCUSED STRIKE
			if _attacker_has_attack_skill(attacker, "Focused Strike") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var focus_result: int
				if _coop_qte_mirror_active:
					focus_result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					focus_result = await _run_focused_strike_minigame(attacker)
					_coop_qte_capture_write(_cqe, focus_result)
				if focus_result > 0:
					ability_triggers_count += 1
					defense_stat = 0 # Completely ignore enemy armor
					force_hit = true 
					if focus_result == 2:
						add_combat_log("PERFECT FOCUS! Armor shattered & Critical blow!", "gold")
						force_crit = true 
						offense_stat += 5 
					else:
						add_combat_log("FOCUSED STRIKE! Defenses shattered!", "lime")
				else:
					add_combat_log("Focus Lost! Attack overextended!", "red")
					focused_failed = true
					
			# BLOODTHIRSTER
			elif _attacker_has_attack_skill(attacker, "Bloodthirster") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var hits_landed: int
				if _coop_qte_mirror_active:
					hits_landed = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					hits_landed = await _run_bloodthirster_minigame(attacker)
					_coop_qte_capture_write(_cqe, hits_landed)
				if hits_landed > 0:
					ability_triggers_count += 1
					lifesteal_percent = float(hits_landed) * 0.25 
					force_hit = true 
					add_combat_log("BLOODTHIRSTER! " + str(hits_landed) + " hits!", "crimson")
					if hits_landed == 3: force_crit = true 
				else:
					add_combat_log("Bloodthirster Failed! Combo broken.", "gray")
					
			# HUNDRED POINT STRIKE
			elif _attacker_has_attack_skill(attacker, "Hundred Point Strike") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				if _coop_qte_mirror_active:
					combo_hits = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					combo_hits = await _run_hundred_point_strike_minigame(attacker)
					_coop_qte_capture_write(_cqe, combo_hits)
				if combo_hits > 0:
					ability_triggers_count += 1
					force_hit = true 
					add_combat_log("HUNDRED POINT STRIKE! " + str(combo_hits) + " Combo!", "purple")
				else:
					add_combat_log("Strike Failed! Slipped up.", "gray")
					focused_failed = true
					
			# --- ARCHER: DEADEYE SHOT ---
			elif _attacker_has_attack_skill(attacker, "Deadeye Shot") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var deadeye_result: int
				if _coop_qte_mirror_active:
					deadeye_result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					deadeye_result = await QTEManager.run_deadeye_shot_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, deadeye_result)
				if deadeye_result > 0:
					ability_triggers_count += 1
					force_hit = true
					deadeye_bonus_damage = 6 if deadeye_result == 1 else 10
					if get_distance(attacker, defender) >= 3:
						deadeye_bonus_damage += 4
						add_combat_log("Deadeye: long draw — full string tension!", "aquamarine")
					if deadeye_result == 2:
						force_crit = true
						add_combat_log("PERFECT DEADEYE! Critical shot lined up!", "gold")
					else:
						add_combat_log("DEADEYE SHOT! Precision damage boosted!", "lime")
				else:
					add_combat_log("Deadeye timing missed.", "gray")
			
			# --- ARCHER: VOLLEY (perfect: second follow-up veers to a foe adjacent to the target) ---
			elif _attacker_has_attack_skill(attacker, "Volley") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var volley_result: int
				if _coop_qte_mirror_active:
					volley_result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					volley_result = await QTEManager.run_volley_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, volley_result)
				volley_spread_target = null
				if volley_result > 0:
					ability_triggers_count += 1
					force_hit = true
					volley_extra_hits = 1 if volley_result == 1 else 2
					volley_damage_multiplier = 0.55 if volley_result == 1 else 0.72
					if volley_result == 2:
						add_combat_log("PERFECT VOLLEY! Three arrows loose at once!", "gold")
						var vd: Vector2i = get_grid_pos(defender)
						for vdir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
							var ve: Node2D = get_enemy_at(vd + vdir)
							if ve != null and ve != defender and is_instance_valid(ve) and not ve.is_queued_for_deletion() and ve.get_parent() == enemy_container and ve.current_hp > 0:
								volley_spread_target = ve
								add_combat_log("One shaft veers into " + str(ve.unit_name) + "!", "lightcyan")
								break
					else:
						add_combat_log("VOLLEY! Bonus arrows incoming!", "cyan")
				else:
					add_combat_log("Volley fizzled. Not enough arrows loosed.", "gray")
			
			# --- ARCHER: RAIN OF ARROWS ---
			elif _attacker_has_attack_skill(attacker, "Rain of Arrows") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var rain_result: int
				if _coop_qte_mirror_active:
					rain_result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					rain_result = await QTEManager.run_rain_of_arrows_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, rain_result)
				if rain_result > 0:
					ability_triggers_count += 1
					force_hit = true
					rain_primary_bonus_damage = 5 if rain_result == 1 else 9
					rain_splash_damage = 4 if rain_result == 1 else 7
			
					var center_tile: Vector2i = get_grid_pos(defender)
					var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
			
					for dir in dirs:
						var splash_target: Node2D = get_enemy_at(center_tile + dir)
						if splash_target != null and splash_target != defender and splash_target.get_parent() == enemy_container and is_instance_valid(splash_target) and not splash_target.is_queued_for_deletion() and splash_target.current_hp > 0 and not rain_splash_targets.has(splash_target):
							rain_splash_targets.append(splash_target)

					rain_tail_unit = null
					rain_rear_extra_damage = 0
					var r_a: Vector2i = get_grid_pos(attacker)
					var r_d: Vector2i = get_grid_pos(defender)
					var r_step: Vector2i = _attack_line_step(r_a, r_d)
					if r_step != Vector2i.ZERO:
						var r_tail: Node2D = get_enemy_at(r_d + r_step)
						if r_tail != null and r_tail != defender and is_instance_valid(r_tail) and not r_tail.is_queued_for_deletion() and r_tail.get_parent() == enemy_container and r_tail.current_hp > 0:
							rain_tail_unit = r_tail
							rain_rear_extra_damage = 6 if rain_result == 2 else 3
							if not rain_splash_targets.has(r_tail):
								rain_splash_targets.append(r_tail)
							add_combat_log("The volley hammers the rear rank (" + str(r_tail.unit_name) + ")!", "wheat")

					if rain_result == 1 and rain_splash_targets.size() > 1:
						if rain_tail_unit != null and rain_splash_targets.has(rain_tail_unit):
							rain_splash_targets = [rain_tail_unit]
						else:
							rain_splash_targets = [rain_splash_targets[0]]
			
					if rain_result == 2:
						add_combat_log("PERFECT RAIN OF ARROWS! The whole zone is covered!", "gold")
					else:
						add_combat_log("RAIN OF ARROWS! Nearby foes are caught in the barrage!", "khaki")
				else:
					add_combat_log("Rain of Arrows sequence broken.", "gray")

			# --- KNIGHT: CHARGE (pin vs rear foe — extra crush when someone stands behind the target) ---
			elif _attacker_has_attack_skill(attacker, "Charge") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_charge_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result == 2:
					ability_triggers_count += 1
					force_hit = true
					force_crit = true
					charge_bonus_damage = 12
					add_combat_log("PERFECT CHARGE! Crushing impact!", "gold")
				elif result == 1:
					ability_triggers_count += 1
					force_hit = true
					charge_bonus_damage = 7
					add_combat_log("CHARGE! The Knight slams through with full momentum!", "orange")
				else:
					add_combat_log("Charge timing failed. Momentum lost.", "gray")
				if result > 0:
					var ca: Vector2i = get_grid_pos(attacker)
					var cd: Vector2i = get_grid_pos(defender)
					var cstep: Vector2i = _attack_line_step(ca, cd)
					if cstep != Vector2i.ZERO:
						var pin_cell: Vector2i = cd + cstep
						var rear: Node2D = get_enemy_at(pin_cell)
						if rear != null and rear != defender and is_instance_valid(rear) and not rear.is_queued_for_deletion() and rear.get_parent() == enemy_container and rear.current_hp > 0:
							charge_collision_target = rear
							charge_collision_damage = 12 if result == 2 else 6
							charge_bonus_damage += 5 if result == 2 else 3
							add_combat_log(str(defender.unit_name) + " is crushed against " + str(rear.unit_name) + "!", "coral")

			# --- MAGE: FIREBALL ---
			elif _attacker_has_attack_skill(attacker, "Fireball") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_fireball_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					force_hit = true

					var center_tile: Vector2i = get_grid_pos(defender)
					var splash_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

					fireball_bonus_damage = 7 if result == 1 else 11
					fireball_splash_damage = 4 if result == 1 else 7

					if result == 2:
						splash_dirs.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])

					for dir in splash_dirs:
						var splash_target: Node2D = get_enemy_at(center_tile + dir)
						if splash_target != null and splash_target != defender and splash_target.get_parent() == enemy_container and is_instance_valid(splash_target) and not splash_target.is_queued_for_deletion() and splash_target.current_hp > 0 and not fireball_splash_targets.has(splash_target):
							fireball_splash_targets.append(splash_target)

					fireball_tail_unit = null
					fireball_tail_extra_damage = 0
					var fa: Vector2i = get_grid_pos(attacker)
					var fd: Vector2i = get_grid_pos(defender)
					var fstep: Vector2i = _attack_line_step(fa, fd)
					if fstep != Vector2i.ZERO:
						var f_tail: Node2D = get_enemy_at(fd + fstep)
						if f_tail != null and f_tail != defender and is_instance_valid(f_tail) and not f_tail.is_queued_for_deletion() and f_tail.get_parent() == enemy_container and f_tail.current_hp > 0:
							fireball_tail_unit = f_tail
							fireball_tail_extra_damage = 6 if result == 2 else 3
							if not fireball_splash_targets.has(f_tail):
								fireball_splash_targets.append(f_tail)
							add_combat_log("The fireball rolls through onto " + str(f_tail.unit_name) + "!", "orangered")

					if result == 2:
						add_combat_log("PERFECT FIREBALL! The blast fully engulfs the area!", "gold")
					else:
						add_combat_log("FIREBALL! The explosion scorches nearby foes!", "orange")
				else:
					add_combat_log("Fireball fizzled. The spell landed poorly.", "gray")

			# --- MAGE: METEOR STORM ---
			elif _attacker_has_attack_skill(attacker, "Meteor Storm") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_meteor_storm_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					force_hit = true

					var center_tile: Vector2i = get_grid_pos(defender)
					var splash_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

					meteor_storm_bonus_damage = 11 if result == 1 else 17
					meteor_storm_splash_damage = 6 if result == 1 else 10

					if result == 2:
						splash_dirs.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])

					for dir in splash_dirs:
						var splash_target: Node2D = get_enemy_at(center_tile + dir)
						if splash_target != null and splash_target != defender and splash_target.get_parent() == enemy_container and is_instance_valid(splash_target) and not splash_target.is_queued_for_deletion() and splash_target.current_hp > 0 and not meteor_storm_splash_targets.has(splash_target):
							meteor_storm_splash_targets.append(splash_target)

					meteor_tail_unit = null
					meteor_tail_extra_damage = 0
					var ma: Vector2i = get_grid_pos(attacker)
					var md: Vector2i = get_grid_pos(defender)
					var mstep: Vector2i = _attack_line_step(ma, md)
					if mstep != Vector2i.ZERO:
						var m_tail: Node2D = get_enemy_at(md + mstep)
						if m_tail != null and m_tail != defender and is_instance_valid(m_tail) and not m_tail.is_queued_for_deletion() and m_tail.get_parent() == enemy_container and m_tail.current_hp > 0:
							meteor_tail_unit = m_tail
							meteor_tail_extra_damage = 8 if result == 2 else 4
							if not meteor_storm_splash_targets.has(m_tail):
								meteor_storm_splash_targets.append(m_tail)
							add_combat_log("A meteor fragment streaks into " + str(m_tail.unit_name) + "!", "tomato")

					if result == 2:
						force_crit = true
						add_combat_log("PERFECT METEOR STORM! Cataclysmic impact across the battlefield!", "gold")
					else:
						add_combat_log("METEOR STORM! Burning fragments rain across the target zone!", "tomato")
				else:
					add_combat_log("Meteor Storm sequence failed. The heavens do not answer.", "gray")

			# --- MERCENARY: FLURRY STRIKE ---
			elif _attacker_has_attack_skill(attacker, "Flurry Strike") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_flurry_strike_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					force_hit = true
					flurry_strike_hits = result

					if result >= 5:
						flurry_strike_damage_multiplier = 0.60
						add_combat_log("PERFECT FLURRY STRIKE! A storm of blades erupts!", "gold")
					elif result >= 3:
						flurry_strike_damage_multiplier = 0.50
						add_combat_log("FLURRY STRIKE! Multiple rapid hits break through!", "cyan")
					else:
						flurry_strike_damage_multiplier = 0.42
						add_combat_log("Flurry Strike lands a short combo.", "white")
				else:
					add_combat_log("Flurry Strike failed. The combo never began.", "gray")

			# --- MERCENARY: BATTLE CRY ---
			elif _attacker_has_attack_skill(attacker, "Battle Cry") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_battle_cry_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					var ally_count: int = 0
					var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
					var attacker_pos: Vector2i = get_grid_pos(attacker)
					var attacker_is_friendly: bool = (attacker.get_parent() == player_container or attacker.get_parent() == ally_container)

					for dir in dirs:
						var check_pos: Vector2i = attacker_pos + dir
						var nearby_unit: Node2D = null

						if attacker_is_friendly:
							nearby_unit = get_unit_at(check_pos)
							if nearby_unit == null and ally_container != null:
								for a in ally_container.get_children():
									if is_instance_valid(a) and not a.is_queued_for_deletion() and get_grid_pos(a) == check_pos:
										nearby_unit = a
										break
						else:
							nearby_unit = get_enemy_at(check_pos)

						if nearby_unit != null and nearby_unit != attacker:
							ally_count += 1
							spawn_loot_text("RALLIED!", Color(1.0, 0.95, 0.4), nearby_unit.global_position + Vector2(32, -24))

					if result == 2:
						battle_cry_bonus_damage = 5 + (ally_count * 3)
						battle_cry_bonus_hit = 18 + (ally_count * 4)
						add_combat_log("PERFECT BATTLE CRY! The whole formation surges with morale!", "gold")
					else:
						battle_cry_bonus_damage = 3 + (ally_count * 2)
						battle_cry_bonus_hit = 10 + (ally_count * 3)
						add_combat_log("BATTLE CRY! Nearby allies fuel the Mercenary's assault!", "orange")
				else:
					add_combat_log("Battle Cry falls flat. No momentum gained.", "gray")

			# --- MERCENARY: BLADE TEMPEST ---
			elif _attacker_has_attack_skill(attacker, "Blade Tempest") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_blade_tempest_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					force_hit = true

					var center_tile: Vector2i = get_grid_pos(attacker)
					var splash_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

					blade_tempest_bonus_damage = 7 if result == 1 else 12
					blade_tempest_splash_damage = 5 if result == 1 else 9

					if result == 2:
						splash_dirs.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])

					for dir in splash_dirs:
						var splash_target: Node2D = get_enemy_at(center_tile + dir)
						if splash_target != null and splash_target != defender and splash_target.get_parent() == enemy_container and is_instance_valid(splash_target) and not splash_target.is_queued_for_deletion() and splash_target.current_hp > 0 and not blade_tempest_splash_targets.has(splash_target):
							blade_tempest_splash_targets.append(splash_target)

					if result == 2:
						add_combat_log("PERFECT BLADE TEMPEST! Steel tears through everything nearby!", "gold")
					else:
						add_combat_log("BLADE TEMPEST! The Mercenary's spinning assault clips nearby enemies!", "cyan")
				else:
					add_combat_log("Blade Tempest loses rhythm before the storm begins.", "gray")

			# --- MONK: CHAKRA ---
			elif _attacker_has_attack_skill(attacker, "Chakra") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_chakra_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					var heal_amount: int = 0
			
					if result == 2:
						heal_amount = int(max(8, attacker.magic + 4))
						chakra_bonus_damage = 6
						chakra_bonus_hit = 18
						add_combat_log("PERFECT CHAKRA! Body and spirit are fully aligned!", "gold")
					else:
						heal_amount = int(max(5, attacker.magic + 1))
						chakra_bonus_damage = 3
						chakra_bonus_hit = 10
						add_combat_log("CHAKRA! The Monk restores inner strength and focus.", "lime")
			
					attacker.current_hp = min(attacker.current_hp + heal_amount, attacker.max_hp)
					if attacker.get("health_bar") != null:
						attacker.health_bar.value = attacker.current_hp
			
					spawn_loot_text("+" + str(heal_amount) + " HP", Color(0.35, 1.0, 0.35), attacker.global_position + Vector2(32, -30))
				else:
					add_combat_log("Chakra faltered. The Monk failed to center their breathing.", "gray")

			# --- MONK: CHI BURST ---
			elif _attacker_has_attack_skill(attacker, "Chi Burst") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_chi_burst_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					force_hit = true
			
					var center_tile: Vector2i = get_grid_pos(defender)
					var splash_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
			
					if result == 2:
						chi_burst_bonus_damage = 10
						chi_burst_splash_damage = 7
						splash_dirs.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])
						add_combat_log("PERFECT CHI BURST! Spiritual force erupts in every direction!", "gold")
					else:
						chi_burst_bonus_damage = 6
						chi_burst_splash_damage = 4
						add_combat_log("CHI BURST! The Monk's energy detonates outward.", "violet")
			
					for dir in splash_dirs:
						var splash_target: Node2D = get_enemy_at(center_tile + dir)
						if splash_target != null and splash_target != defender and splash_target.get_parent() == enemy_container and is_instance_valid(splash_target) and not splash_target.is_queued_for_deletion() and splash_target.current_hp > 0 and not chi_burst_splash_targets.has(splash_target):
							chi_burst_splash_targets.append(splash_target)
				else:
					add_combat_log("Chi Burst collapsed before release.", "gray")

			# --- MONSTER: ROAR ---
			elif _attacker_has_attack_skill(attacker, "Roar") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_roar_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					var attacker_is_friendly: bool = (attacker.get_parent() == player_container or attacker.get_parent() == ally_container)
					var roar_radius: int = 1 if result == 1 else 2
					var debuff_amount: int = 1 if result == 1 else 2
					var affected_targets: Array[Node2D] = []
					var affected_count: int = 0
			
					for x in range(-roar_radius, roar_radius + 1):
						for y in range(-roar_radius, roar_radius + 1):
							var offset: Vector2i = Vector2i(x, y)
							if abs(offset.x) + abs(offset.y) > roar_radius: continue
							if offset == Vector2i.ZERO: continue
			
							var target_tile: Vector2i = get_grid_pos(attacker) + offset
							var target: Node2D = get_occupant_at(target_tile)
			
							if target == null or not is_instance_valid(target) or target.is_queued_for_deletion(): continue
							if affected_targets.has(target): continue
			
							var is_hostile: bool = false
							if attacker_is_friendly:
								is_hostile = target.get_parent() == enemy_container
							else:
								is_hostile = (target.get_parent() == player_container or target.get_parent() == ally_container)
			
							if not is_hostile: continue
			
							target.strength = int(max(0, target.strength - debuff_amount))
							target.magic = int(max(0, target.magic - debuff_amount))
							target.speed = int(max(0, target.speed - debuff_amount))
							target.agility = int(max(0, target.agility - debuff_amount))
			
							affected_targets.append(target)
							affected_count += 1
							spawn_loot_text("INTIMIDATED!", Color(1.0, 0.70, 0.25), target.global_position + Vector2(32, -20))
			
					if result == 2:
						add_combat_log("PERFECT ROAR! " + str(affected_count) + " enemies are shaken to the bone!", "gold")
					else:
						add_combat_log("ROAR! " + str(affected_count) + " enemies are rattled by the beast's cry.", "orange")
				else:
					add_combat_log("The Roar came out weak and uneven.", "gray")

			# --- MONSTER: FRENZY ---
			elif _attacker_has_attack_skill(attacker, "Frenzy") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_frenzy_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					_frenzy_hit_count = result
					frenzy_bonus_damage = result * 2
					frenzy_bonus_hit = result * 4
					frenzy_def_penalty = 2 + int(float(result) / 2.0)
			
					attacker.set_meta("frenzy_def_penalty_temp", frenzy_def_penalty)
					attacker.set_meta("frenzy_res_penalty_temp", frenzy_def_penalty)
			
					if result >= 6:
						force_hit = true
						add_combat_log("PERFECT FRENZY! The Monster goes completely berserk!", "gold")
					elif result >= 4:
						add_combat_log("FRENZY! The Monster's rage spikes violently!", "crimson")
					else:
						add_combat_log("Frenzy builds, but leaves the Monster exposed.", "tomato")
			
					spawn_loot_text("-" + str(frenzy_def_penalty) + " DEF", Color(1.0, 0.45, 0.45), attacker.global_position + Vector2(32, -30))
				else:
					add_combat_log("Frenzy never took hold.", "gray")

			# --- MONSTER: RENDING CLAW ---
			elif _attacker_has_attack_skill(attacker, "Rending Claw") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_rending_claw_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					force_hit = true
					if result == 2:
						defense_stat = 0
						force_crit = true
						add_combat_log("PERFECT RENDING CLAW! Armor is shredded completely!", "gold")
					else:
						defense_stat = int(max(0, defense_stat - 8))
						add_combat_log("RENDING CLAW! The Monster tears through armor plating!", "tomato")
				else:
					add_combat_log("Rending Claw missed the weak point.", "gray")
					
			# --- PALADIN: SMITE ---
			elif _attacker_has_attack_skill(attacker, "Smite") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_smite_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				smite_splash_targets.clear()
				smite_splash_damage = 0
				if result > 0:
					ability_triggers_count += 1
					force_hit = true
					
					if result == 2:
						force_crit = true
						smite_bonus_damage = 8 + int(attacker.magic / 2)
						smite_splash_damage = 7 + int(attacker.magic / 4)
						add_combat_log("PERFECT SMITE! A blinding ray of holy light obliterates the target!", "gold")
					else:
						smite_bonus_damage = 4 + int(attacker.magic / 3)
						smite_splash_damage = 4 + int(attacker.magic / 5)
						add_combat_log("SMITE! Holy energy sears the enemy!", "yellow")
					var smite_center: Vector2i = get_grid_pos(defender)
					for sm_dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
						if smite_splash_targets.size() >= 2:
							break
						var sm_e: Node2D = get_enemy_at(smite_center + sm_dir)
						if sm_e != null and sm_e != defender and is_instance_valid(sm_e) and not sm_e.is_queued_for_deletion() and sm_e.get_parent() == enemy_container and sm_e.current_hp > 0 and not smite_splash_targets.has(sm_e):
							smite_splash_targets.append(sm_e)
					if smite_splash_targets.size() > 0:
						add_combat_log("Holy light splashes onto nearby foes!", "khaki")
				else:
					add_combat_log("Smite failed to find its mark.", "gray")
					
			# --- PALADIN: SACRED JUDGMENT ---
			elif _attacker_has_attack_skill(attacker, "Sacred Judgment") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_sacred_judgment_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					force_hit = true

					var center_tile: Vector2i = get_grid_pos(defender)
					var splash_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

					sacred_judgment_bonus_damage = 10 if result == 1 else 15
					sacred_judgment_splash_damage = 5 if result == 1 else 8

					if result == 2:
						splash_dirs.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])

					for dir in splash_dirs:
						var splash_target: Node2D = get_enemy_at(center_tile + dir)
						if splash_target != null and splash_target != defender and splash_target.get_parent() == enemy_container and is_instance_valid(splash_target) and not splash_target.is_queued_for_deletion() and splash_target.current_hp > 0 and not sacred_judgment_splash_targets.has(splash_target):
							sacred_judgment_splash_targets.append(splash_target)

					if result == 2:
						add_combat_log("PERFECT SACRED JUDGMENT! A colossal cross of light engulfs the area!", "gold")
					else:
						add_combat_log("SACRED JUDGMENT! The heavens strike down nearby foes!", "yellow")
				else:
					add_combat_log("Sacred Judgment was released too early.", "gray")

			# --- SPELLBLADE: FLAME BLADE ---
			elif _attacker_has_attack_skill(attacker, "Flame Blade") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_flame_blade_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					force_hit = true
					
					var magic_scale: int = int(float(attacker.magic) * 0.8)
					if result == 2:
						flame_blade_bonus_damage = 5 + magic_scale
						force_crit = true
						add_combat_log("PERFECT FLAME BLADE! The sword erupts into a roaring inferno!", "gold")
					else:
						flame_blade_bonus_damage = 2 + int(float(magic_scale) * 0.5)
						add_combat_log("FLAME BLADE! Searing heat wraps around the strike!", "orange")
				else:
					add_combat_log("Flame Blade fizzled out.", "gray")

			# --- SPELLBLADE: ELEMENTAL CONVERGENCE ---
			elif _attacker_has_attack_skill(attacker, "Elemental Convergence") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_elemental_convergence_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					force_hit = true

					var center_tile: Vector2i = get_grid_pos(defender)
					var splash_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

					elemental_convergence_bonus_damage = 12 if result == 1 else 20
					elemental_convergence_splash_damage = 6 if result == 1 else 10

					if result == 2:
						splash_dirs.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])

					for dir in splash_dirs:
						var splash_target: Node2D = get_enemy_at(center_tile + dir)
						if splash_target != null and splash_target != defender and splash_target.get_parent() == enemy_container and is_instance_valid(splash_target) and not splash_target.is_queued_for_deletion() and splash_target.current_hp > 0 and not elemental_convergence_splash_targets.has(splash_target):
							elemental_convergence_splash_targets.append(splash_target)

					if result == 2:
						force_crit = true
						add_combat_log("PERFECT CONVERGENCE! Fire, Ice, and Lightning detonate simultaneously!", "gold")
					else:
						add_combat_log("ELEMENTAL CONVERGENCE! A chaotic magical storm blasts the area!", "violet")
				else:
					add_combat_log("The elemental energies destabilized and vanished.", "gray")
					
			# --- THIEF: SHADOW STRIKE ---
			elif _attacker_has_attack_skill(attacker, "Shadow Strike") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_shadow_strike_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					force_hit = true
					if result == 2:
						shadow_strike_bonus_damage = 10
						shadow_strike_armor_pierce = 1.0 # Ignore 100% armor
						add_combat_log("PERFECT SHADOW STRIKE! A flawless strike from the darkness!", "gold")
					else:
						shadow_strike_bonus_damage = 5
						shadow_strike_armor_pierce = 0.5 # Ignore 50% armor
						add_combat_log("SHADOW STRIKE! The Thief strikes from the blind spot!", "violet")
				else:
					add_combat_log("Shadow Strike revealed. The element of surprise is gone.", "gray")
					
			# --- THIEF: ASSASSINATE ---
			elif _attacker_has_attack_skill(attacker, "Assassinate") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_assassinate_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					force_hit = true
					assassinate_crit_bonus = result * 25 # Each successful lockpick adds 25% crit chance
					if result == 3:
						force_crit = true
						add_combat_log("PERFECT ASSASSINATION! All vital points struck!", "gold")
					else:
						add_combat_log("ASSASSINATE! " + str(result) + " vitals hit!", "crimson")
				else:
					add_combat_log("Assassinate failed to find an opening.", "gray")
					
			# --- THIEF: ULTIMATE SHADOW STEP ---
			elif _attacker_has_attack_skill(attacker, "Ultimate Shadow Step") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_ultimate_shadow_step_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					force_hit = true
					if result == 2:
						shadow_step_bonus_damage = 15
						force_crit = true
						add_combat_log("PERFECT SHADOW STEP! Absolute teleportation mastery!", "gold")
					else:
						shadow_step_bonus_damage = 8
						add_combat_log("SHADOW STEP! The Thief materializes behind the enemy!", "cyan")
				else:
					add_combat_log("Ultimate Shadow Step collapsed. Sequence broken.", "gray")

			# --- WARRIOR: POWER STRIKE ---
			elif _attacker_has_attack_skill(attacker, "Power Strike") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_power_strike_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					force_hit = true
					if result == 2:
						power_strike_bonus_damage = int(float(attacker.strength) * 1.5)
						force_crit = true
						add_combat_log("PERFECT POWER STRIKE! Maximum kinetic energy!", "gold")
					else:
						power_strike_bonus_damage = int(float(attacker.strength) * 0.75)
						add_combat_log("POWER STRIKE! A heavy, punishing blow!", "orange")
				else:
					add_combat_log("Power Strike whiffed entirely.", "gray")

			# --- WARRIOR: ADRENALINE RUSH ---
			elif _attacker_has_attack_skill(attacker, "Adrenaline Rush") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_adrenaline_rush_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					var buff_amt: int = 0
					if result == 2:
						buff_amt = 8
						add_combat_log("PERFECT ADRENALINE RUSH! Blood boils with pure fury!", "gold")
					else:
						buff_amt = 4
						add_combat_log("ADRENALINE RUSH! The Warrior pushes past their limits!", "tomato")
					
					attacker.strength += buff_amt
					attacker.speed += buff_amt
					spawn_loot_text("+" + str(buff_amt) + " STR/SPD", Color(1.0, 0.2, 0.2), attacker.global_position + Vector2(32, -32))
				else:
					add_combat_log("Adrenaline Rush faded.", "gray")

			# --- WARRIOR: EARTHSHATTER ---
			elif _attacker_has_attack_skill(attacker, "Earthshatter") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_earthshatter_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					force_hit = true

					var center_tile: Vector2i = get_grid_pos(defender)
					var splash_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

					if result == 2:
						earthshatter_bonus_damage = 18
						earthshatter_splash_damage = 12
						splash_dirs.append_array([Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)])
						force_crit = true
						add_combat_log("PERFECT EARTHSHATTER! The ground itself explodes!", "gold")
					else:
						earthshatter_bonus_damage = 10
						earthshatter_splash_damage = 6
						add_combat_log("EARTHSHATTER! Shockwaves tear through the terrain!", "orange")

					for dir in splash_dirs:
						var splash_target: Node2D = get_enemy_at(center_tile + dir)
						if splash_target != null and splash_target != defender and splash_target.get_parent() == enemy_container and is_instance_valid(splash_target) and not splash_target.is_queued_for_deletion() and splash_target.current_hp > 0 and not earthshatter_splash_targets.has(splash_target):
							earthshatter_splash_targets.append(splash_target)
				else:
					add_combat_log("Earthshatter miscalculated. The strike hit dirt.", "gray")
			
			# --- PROMOTED ASSASSIN: SHADOW PIN ---
			elif _attacker_has_attack_skill(attacker, "Shadow Pin") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_shadow_pin_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					force_hit = true
					shadow_pin_speed_lock = true
					
					if result == 2:
						shadow_pin_bonus_damage = 12
						force_crit = true
						add_combat_log("PERFECT SHADOW PIN! The target is completely paralyzed!", "gold")
					else:
						shadow_pin_bonus_damage = 6
						add_combat_log("SHADOW PIN! The target is crippled!", "violet")
				else:
					add_combat_log("Shadow Pin missed the pressure point.", "gray")

			# --- PROMOTED BERSERKER: SAVAGE TOSS ---
			elif _attacker_has_attack_skill(attacker, "Savage Toss") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				if _coop_qte_mirror_active:
					savage_toss_distance = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					savage_toss_distance = await QTEManager.run_savage_toss_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, savage_toss_distance)
				if savage_toss_distance > 0:
					ability_triggers_count += 1
					force_hit = true
					savage_toss_bonus_damage = savage_toss_distance * 3
					
					if savage_toss_distance == 3:
						force_crit = true
						add_combat_log("PERFECT SAVAGE TOSS! Sent flying across the battlefield!", "gold")
					else:
						add_combat_log("SAVAGE TOSS! The enemy is hurled backward!", "orange")
				else:
					add_combat_log("Savage Toss failed to lift the target.", "gray")

			# --- PROMOTED HERO: VANGUARD'S RALLY ---
			elif _attacker_has_attack_skill(attacker, "Vanguard's Rally") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var combos: int
				if _coop_qte_mirror_active:
					combos = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					combos = await QTEManager.run_vanguards_rally_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, combos)
				if combos > 0:
					ability_triggers_count += 1
					force_hit = true
					vanguards_rally_bonus_damage = 4 + (combos * 2)
					vanguards_rally_might_bonus = mini(combos, 4)
					
					if combos >= 4:
						force_crit = true
						add_combat_log("PERFECT VANGUARD'S RALLY! The entire army surges with power!", "gold")
					else:
						add_combat_log("VANGUARD'S RALLY! Inspiring strike bolsters nearby allies!", "cyan")
				else:
					add_combat_log("Vanguard's Rally failed to build momentum.", "gray")

			# --- PROMOTED BLADE MASTER: SEVERING STRIKE ---
			elif _attacker_has_attack_skill(attacker, "Severing Strike") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				if _coop_qte_mirror_active:
					severing_strike_hits = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					severing_strike_hits = await QTEManager.run_severing_strike_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, severing_strike_hits)
				if severing_strike_hits > 0:
					ability_triggers_count += 1
					force_hit = true
					
					if severing_strike_hits == 3:
						force_crit = true
						severing_strike_damage_multiplier = 0.8
						add_combat_log("PERFECT SEVERING STRIKE! Three absolute precision cuts!", "gold")
					else:
						severing_strike_damage_multiplier = 0.5
						add_combat_log("SEVERING STRIKE! " + str(severing_strike_hits) + " critical points hit!", "cyan")
				else:
					add_combat_log("Severing Strike missed all vital points.", "gray")

			# --- PROMOTED BLADE WEAVER: AETHER BIND ---
			elif _attacker_has_attack_skill(attacker, "Aether Bind") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				if _coop_qte_mirror_active:
					aether_bind_sparks = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					aether_bind_sparks = await QTEManager.run_aether_bind_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, aether_bind_sparks)
				if aether_bind_sparks > 0:
					ability_triggers_count += 1
					force_hit = true
					
					var bonus: int = aether_bind_sparks * 2
					offense_stat += bonus # Permanently boosts their magic for the rest of the attack!
					
					if aether_bind_sparks >= 5:
						force_crit = true
						add_combat_log("PERFECT AETHER BIND! Maximum magical energy harvested!", "gold")
					else:
						add_combat_log("AETHER BIND! Gathered " + str(aether_bind_sparks) + " sparks of raw power!", "violet")
					
					spawn_loot_text("+" + str(bonus) + " MAG", Color(0.8, 0.4, 1.0), attacker.global_position + Vector2(32, -32))
				else:
					add_combat_log("Aether Bind failed to catch any magical energy.", "gray")

			# --- PROMOTED BOW KNIGHT: PARTING SHOT ---
			elif _attacker_has_attack_skill(attacker, "Parting Shot") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				if _coop_qte_mirror_active:
					parting_shot_result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					parting_shot_result = await QTEManager.run_parting_shot_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, parting_shot_result)
				if parting_shot_result > 0:
					ability_triggers_count += 1
					force_hit = true
					
					if parting_shot_result == 2:
						force_crit = true
						_parting_shot_bonus_damage = 8
						parting_shot_dodge = true
						add_combat_log("PERFECT PARTING SHOT! Flawless strike and retreat!", "gold")
					else:
						_parting_shot_bonus_damage = 4
						add_combat_log("PARTING SHOT! Arrow strikes true!", "lime")
				else:
					add_combat_log("Parting Shot execution failed.", "gray")

			# --- PROMOTED DEATH KNIGHT: SOUL HARVEST ---
			elif _attacker_has_attack_skill(attacker, "Soul Harvest") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				if _coop_qte_mirror_active:
					soul_harvest_result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					soul_harvest_result = await QTEManager.run_soul_harvest_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, soul_harvest_result)
				if soul_harvest_result > 0:
					ability_triggers_count += 1
					force_hit = true
					
					# Soul Harvest drains HP equal to a % of the enemy's MAX HP instead of relying on attack stat!
					var drain_percent: float = 0.25 if soul_harvest_result == 2 else 0.10
					var drain_amt: int = int(float(defender.max_hp) * drain_percent)
					
					attacker.current_hp = min(attacker.current_hp + drain_amt, attacker.max_hp)
					if attacker.get("health_bar") != null:
						attacker.health_bar.value = attacker.current_hp
					spawn_loot_text("+" + str(drain_amt) + " HP", Color(0.2, 1.0, 0.2), attacker.global_position + Vector2(-32, -16))
					
					if soul_harvest_result == 2:
						force_crit = true
						add_combat_log("PERFECT SOUL HARVEST! Massive life force drained!", "gold")
					else:
						add_combat_log("SOUL HARVEST! Life force siphoned!", "crimson")
				else:
					add_combat_log("Soul Harvest grip broken.", "gray")

			# --- PROMOTED FIRE SAGE: HELLFIRE ---
			elif _attacker_has_attack_skill(attacker, "Hellfire") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				if _coop_qte_mirror_active:
					hellfire_result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					hellfire_result = await QTEManager.run_hellfire_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, hellfire_result)
				if hellfire_result == 2:
					ability_triggers_count += 1
					force_hit = true
					force_crit = true
					hellfire_bonus_damage = 15
					add_combat_log("PERFECT HELLFIRE! The enemy is engulfed in unholy flames!", "gold")
				else:
					add_combat_log("Hellfire failed to reach critical mass.", "gray")

			# --- CANNONEER / SIEGE: BALLISTA SHOT (overpenetration — foe behind primary target in line) ---
			elif _attacker_has_attack_skill(attacker, "Ballista Shot") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_ballista_shot_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					force_hit = true
					if result == 2:
						force_crit = true
						ballista_shot_bonus_damage = 18
						add_combat_log("PERFECT BALLISTA SHOT! An absolute bullseye!", "gold")
					else:
						ballista_shot_bonus_damage = 8
						add_combat_log("BALLISTA SHOT! A heavy bolt strikes the target!", "cyan")
					# Identity: siege bolt punches through — next enemy on the same line behind the target eats spill damage.
					ballista_shot_pierce_damage = 0
					var a_cell: Vector2i = get_grid_pos(attacker)
					var d_cell: Vector2i = get_grid_pos(defender)
					var step: Vector2i = _attack_line_step(a_cell, d_cell)
					if step != Vector2i.ZERO:
						var behind_cell: Vector2i = d_cell + step
						var pierce: Node2D = get_enemy_at(behind_cell)
						if pierce != null and pierce != defender and is_instance_valid(pierce) and not pierce.is_queued_for_deletion() and pierce.get_parent() == enemy_container and pierce.current_hp > 0:
							ballista_shot_pierce_targets.append(pierce)
							ballista_shot_pierce_damage = 14 if result == 2 else 7
							add_combat_log("The bolt overpenetrates toward " + str(pierce.unit_name) + "!", "lightskyblue")
				else:
					add_combat_log("Ballista Shot missed the mark.", "gray")

			# --- PROMOTED HIGH PALADIN: AEGIS STRIKE ---
			elif _attacker_has_attack_skill(attacker, "Aegis Strike") and randi() % 100 < atk_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_aegis_strike_minigame(self, attacker)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					force_hit = true
					if result == 2:
						force_crit = true
						aegis_strike_bonus_damage = 16
						add_combat_log("PERFECT AEGIS STRIKE! The holy cross detonates!", "gold")
					else:
						aegis_strike_bonus_damage = 7
						add_combat_log("AEGIS STRIKE! A heavy blow aligned with the heavens!", "yellow")
				else:
					add_combat_log("Aegis Strike lost its alignment.", "gray")

		var rookie_mods: Dictionary = _compute_rookie_class_passive_mods(attacker, defender, is_magic, wpn)
		var rookie_hit: int = int(rookie_mods.get("hit", 0))
		var rookie_dmg: int = int(rookie_mods.get("dmg", 0))
		var rookie_crit: int = int(rookie_mods.get("crit", 0))
		var rookie_log: String = str(rookie_mods.get("log", ""))

		# --- FINAL HIT CHANCE MATH (support-combat: atk_sup hit, def_sup avo; relationship: atk_rel hit, def_rel avo) ---
		var hit_chance: int = int(clamp(80 + (wpn.hit_bonus if wpn else 0) + tri_hit + atk_adj["hit"] + atk_sup["hit"] - def_sup["avo"] + atk_rel["hit"] - def_rel["avo"] + (attacker.agility * 2) - (defender.speed * 2) - def_terrain["avo"], 0, 100))
		hit_chance = int(clamp(hit_chance + battle_cry_bonus_hit + chakra_bonus_hit + frenzy_bonus_hit + rookie_hit - int(defender.get_meta("inner_peace_avo_bonus_temp", 0)), 0, 100))
		if focused_failed: hit_chance = 0 
		
		# --- ARMOR PIERCING CALCULATION ---
		var actual_defense: int = defense_stat
		if shadow_strike_armor_pierce > 0.0:
			actual_defense = int(float(actual_defense) * (1.0 - shadow_strike_armor_pierce))
		
		# ==========================================
		# --- POISE & GUARD BREAK SYSTEM ---
		# ==========================================
		# Use unit's get_max_poise() when available so forecast, UI, and resolution stay in sync.
		var def_max_poise: int = defender.get_max_poise() if defender.has_method("get_max_poise") else (defender.max_hp + (actual_defense * 2) + (25 if defender.get("is_defending") else 0))
		var def_current_poise: int = defender.get_meta("current_poise", def_max_poise)
		def_current_poise = clampi(def_current_poise, 0, def_max_poise)

		# --- Are they already broken from a previous attack? ---
		var already_staggered: bool = (def_current_poise <= 0) 
		
		var raw_power: int = offense_stat + (wpn.might if wpn else 0)
		var poise_dmg: int = raw_power
		
		# Axes deal massive poise damage to crack shields
		if wpn and wpn.get("weapon_type") == WeaponData.WeaponType.AXE:
			poise_dmg = int(float(poise_dmg) * 1.5)
			
		if force_crit: 
			poise_dmg *= 2
			
		# Only trigger the "Break" event if they weren't broken already
		var will_stagger: bool = not already_staggered and (def_current_poise - poise_dmg) <= 0
		
		if will_stagger or already_staggered:
			actual_defense = int(float(actual_defense) * 0.5) # Armor is cracked!
			
		# Calculate Base Damage
		var damage: int = int(max(0, (offense_stat + (wpn.might if wpn else 0) + tri_dmg) - actual_defense))
		
		# If staggering/staggered, guarantee at least 20% chip damage bypassing remaining armor
		if will_stagger or already_staggered:
			var chip_damage = int(float(raw_power) * 0.2)
			if damage < chip_damage: 
				damage = chip_damage
		# ==========================================
		
			
		
		# --- ADD QTE DAMAGE BOOSTS ---
		damage += deadeye_bonus_damage + rain_primary_bonus_damage + charge_bonus_damage 
		damage += fireball_bonus_damage + meteor_storm_bonus_damage + battle_cry_bonus_damage + blade_tempest_bonus_damage
		damage += chakra_bonus_damage + chi_burst_bonus_damage + frenzy_bonus_damage
		damage += smite_bonus_damage + sacred_judgment_bonus_damage + flame_blade_bonus_damage + elemental_convergence_bonus_damage
		damage += shadow_strike_bonus_damage + shadow_step_bonus_damage + power_strike_bonus_damage + earthshatter_bonus_damage
		damage += shadow_pin_bonus_damage + savage_toss_bonus_damage + vanguards_rally_bonus_damage
		damage += atk_rel["dmg_bonus"]
		var crit_chance: int = int(clamp((attacker.agility / 2) + assassinate_crit_bonus + atk_rel["crit_bonus"] - def_sup["crit_avo"] + rookie_crit, 0, 100))
		damage += hellfire_bonus_damage + ballista_shot_bonus_damage + aegis_strike_bonus_damage
		damage += rookie_dmg
		var is_crit: bool = force_crit or (randi() % 100 < crit_chance)
		var attack_hits: bool = force_hit or (randi() % 100 < hit_chance)
		if not rookie_log.is_empty():
			add_combat_log(attacker.unit_name + ": " + rookie_log, "lightblue")
		# ==========================================
		# PHASE C: ATTACK LUNGE OR SHOOT
		# ==========================================
		var orig_pos: Vector2 = attacker.global_position
		var lunge_dir: Vector2 = (defender.global_position - attacker.global_position).normalized()
		var did_melee_crit_animation: bool = false
		var did_melee_normal_animation: bool = false

		if wpn != null and wpn.get("is_instant_cast") == true:
			# --- INSTANT CAST (BEAM / PILLAR) ---
			var recoil_tween: Tween = create_tween()
			recoil_tween.tween_property(attacker, "global_position", orig_pos - (lunge_dir * 4.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			await recoil_tween.finished
			
			if wpn.get("impact_scene") != null and wpn.impact_scene != null:
				var impact: Node2D = wpn.impact_scene.instantiate()
				add_child(impact)
				impact.z_index = 115
				impact.global_position = defender.global_position + Vector2(32, 32)
				var p_scale: float = float(wpn.get("projectile_scale")) if wpn.get("projectile_scale") != null else 2.0
				impact.scale = Vector2(p_scale, p_scale)
				
			await get_tree().create_timer(0.3).timeout
			
		elif wpn != null and wpn.get("projectile_scene") != null:
			# --- RANGED PROJECTILE ---
			var recoil_tween: Tween = create_tween()
			recoil_tween.tween_property(attacker, "global_position", orig_pos - (lunge_dir * 8.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			await recoil_tween.finished
			
			var proj: Node2D = wpn.projectile_scene.instantiate()
			add_child(proj)
			proj.z_index = 110
			
			var p_scale: float = float(wpn.get("projectile_scale")) if wpn.get("projectile_scale") != null else 2.0
			proj.scale = Vector2(p_scale, p_scale)
			
			proj.global_position = attacker.global_position + Vector2(32, 32) 
			proj.rotation = lunge_dir.angle()
			
			var distance: float = attacker.global_position.distance_to(defender.global_position)
			var travel_time: float = distance / 800.0
			
			var fly_tween: Tween = create_tween()
			fly_tween.tween_property(proj, "global_position", defender.global_position + Vector2(32, 32), travel_time)
			await fly_tween.finished
			
			if wpn.get("impact_scene") != null and wpn.impact_scene != null:
				var impact: Node2D = wpn.impact_scene.instantiate()
				add_child(impact)
				impact.z_index = 115
				impact.global_position = defender.global_position + Vector2(32, 32)
				impact.scale = Vector2(p_scale * 1.2, p_scale * 1.2)
			
			proj.queue_free()
			
		else:
			# --- MELEE ATTACK ---
			if is_crit and attack_hits:
				did_melee_crit_animation = true
				await _run_melee_crit_lunge(attacker, defender, orig_pos, lunge_dir)
			else:
				did_melee_normal_animation = true
				await _run_melee_normal_lunge(attacker, defender, orig_pos, lunge_dir)
		
		# ==========================================
		# PHASE D: DEFENSIVE ABILITIES & PARRY
		# ==========================================
		var defense_resolved_and_won: bool = false
		
		var def_trigger_chance: int = get_ability_trigger_chance(defender)
		var parry_chance: int = get_ability_trigger_chance(defender, true)

		if attack_hits and (defender.get_parent() == player_container or defender.get_parent() == ally_container):

			# --- PROMOTED GENERAL: WEAPON SHATTER ---
			if defender.get("ability") == "Weapon Shatter" and randi() % 100 < def_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_weapon_shatter_minigame(self, defender)
					_coop_qte_capture_write(_cqe, result)
				if result == 2:
					ability_triggers_count += 1
					_weapon_shatter_triggered = true
					incoming_damage_multiplier = min(incoming_damage_multiplier, 0.5)
					
					spawn_loot_text("SHATTERED!", Color(1.0, 0.8, 0.2), attacker.global_position + Vector2(32, -32))
					add_combat_log("PERFECT WEAPON SHATTER! The General completely destroyed the enemy's weapon!", "gold")
					
					if attacker.equipped_weapon != null and attacker.equipped_weapon.get("current_durability") != null:
						attacker.equipped_weapon.current_durability = 0
				else:
					add_combat_log("Weapon Shatter failed to catch the blade.", "gray")

			# --- PROMOTED DIVINE SAGE: CELESTIAL CHOIR (Map-Wide Heal) ---
			elif defender.get("ability") == "Celestial Choir" and randi() % 100 < def_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				if _coop_qte_mirror_active:
					celestial_choir_hits = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					celestial_choir_hits = await QTEManager.run_celestial_choir_minigame(self, defender)
					_coop_qte_capture_write(_cqe, celestial_choir_hits)
				if celestial_choir_hits > 0:
					ability_triggers_count += 1
					
					# Heal is based on hits AND the Sage's Magic!
					var aoe_heal_amount: int = celestial_choir_hits * (2 + int(float(defender.magic) * 0.2))
					
					var allies_healed: int = 0
					if player_container != null:
						for ally in player_container.get_children():
							if is_instance_valid(ally) and ally.current_hp > 0:
								ally.current_hp = min(ally.current_hp + aoe_heal_amount, ally.max_hp)
								if ally.get("health_bar") != null: ally.health_bar.value = ally.current_hp
								spawn_loot_text("+" + str(aoe_heal_amount), Color(0.4, 1.0, 0.4), ally.global_position + Vector2(32, -24))
								allies_healed += 1
								
					add_combat_log("CELESTIAL CHOIR! " + str(allies_healed) + " allies restored by heavenly music!", "lime")
				else:
					add_combat_log("Celestial Choir faltered. The notes were lost.", "gray")

			# --- PROMOTED GREAT KNIGHT: PHALANX (Map-Wide Defense) ---
			elif defender.get("ability") == "Phalanx" and randi() % 100 < def_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_phalanx_minigame(self, defender)
					_coop_qte_capture_write(_cqe, result)
				if result == 2:
					ability_triggers_count += 1
					defense_resolved_and_won = true
					incoming_damage_multiplier = min(incoming_damage_multiplier, 0.1) # Take almost 0 damage!
					
					var allies_buffed: int = 0
					if player_container != null:
						for ally in player_container.get_children():
							if is_instance_valid(ally) and ally.current_hp > 0:
								# Give them a temporary +10 Defense!
								ally.set_meta("inner_peace_def_bonus_temp", 10) 
								spawn_loot_text("PHALANX!", Color(0.8, 0.9, 1.0), ally.global_position + Vector2(32, -24))
								allies_buffed += 1
								
					add_combat_log("PERFECT PHALANX! " + str(allies_buffed) + " allies raise their shields as one!", "gold")
				else:
					add_combat_log("Phalanx formation was broken before it could set.", "gray")
			
			# --- CLERIC: DIVINE PROTECTION ---
			if defender.get("ability") == "Divine Protection" and randi() % 100 < def_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_divine_protection_minigame(self, defender)
					_coop_qte_capture_write(_cqe, result)
				if result == 2:
					ability_triggers_count += 1
					defense_resolved_and_won = true
		
					var heal_amt: int = int(max(1, round(float(defender.max_hp) * 0.10)))
					defender.current_hp = min(defender.current_hp + heal_amt, defender.max_hp)
					if defender.get("health_bar") != null:
						defender.health_bar.value = defender.current_hp
		
					spawn_loot_text("BARRIER!", Color(1.0, 0.9, 0.4), defender.global_position + Vector2(32, -32))
					spawn_loot_text("+" + str(heal_amt) + " HP", Color(0.2, 1.0, 0.2), defender.global_position + Vector2(32, -56))
					add_combat_log("PERFECT DIVINE PROTECTION! The attack is completely warded off!", "gold")
				elif result == 1:
					ability_triggers_count += 1
					incoming_damage_multiplier = min(incoming_damage_multiplier, 0.35)
					spawn_loot_text("BARRIER!", Color(0.8, 0.9, 1.0), defender.global_position + Vector2(32, -32))
					add_combat_log("DIVINE PROTECTION! Most of the blow is absorbed.", "cyan")
				else:
					add_combat_log("Divine Protection failed to form in time.", "gray")

			# --- MAGE: ARCANE SHIFT ---
			elif defender.get("ability") == "Arcane Shift" and randi() % 100 < def_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_arcane_shift_minigame(self, defender)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					defense_resolved_and_won = true

					spawn_loot_text("SHIFT!", Color(0.7, 0.95, 1.0), defender.global_position + Vector2(32, -32))

					if result == 2:
						var counter_dmg: int = int(max(1, round(float(defender.magic) * 0.85)))
						if crit_sound and crit_sound.stream != null:
							crit_sound.play()
						attacker.take_damage(counter_dmg, defender)
						spawn_loot_text(str(counter_dmg) + " ARCANE", Color(0.8, 0.6, 1.0), attacker.global_position + Vector2(32, -16))
						add_combat_log("PERFECT ARCANE SHIFT! The Mage vanishes and lashes back with arcane force!", "gold")
					else:
						add_combat_log("ARCANE SHIFT! The attack passes harmlessly through the Mage.", "cyan")
				else:
					add_combat_log("Arcane Shift failed. The dodge was mistimed.", "gray")

			# --- KNIGHT: SHIELD BASH ---
			elif defender.get("ability") == "Shield Bash" and randi() % 100 < def_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_shield_bash_minigame(self, defender)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					defense_resolved_and_won = true
		
					var def_wpn = defender.equipped_weapon
					var is_magic_counter: bool = false
					if def_wpn != null and def_wpn.get("damage_type") != null:
						is_magic_counter = (def_wpn.damage_type == WeaponData.DamageType.MAGIC)

					var counter_offense: int = int(defender.magic) if is_magic_counter else int(defender.strength)
					var counter_defense: int = int(attacker.resistance) if is_magic_counter else int(attacker.defense)
					var def_might: int = int(def_wpn.might) if def_wpn != null else 0

					var base_counter_dmg: int = int(max(1, (counter_offense + def_might) - counter_defense))
					var final_counter_dmg: int = base_counter_dmg if result == 1 else int(round(float(base_counter_dmg) * 1.75))
		
					if crit_sound and crit_sound.stream != null and result == 2:
						crit_sound.play()
					elif attack_sound and attack_sound.stream != null:
						attack_sound.play()
		
					attacker.take_damage(final_counter_dmg, defender)
					spawn_loot_text(str(final_counter_dmg) + " COUNTER", Color(0.8, 0.9, 1.0), attacker.global_position + Vector2(32, -16))
		
					if result == 2:
						add_combat_log("PERFECT SHIELD BASH! The enemy is smashed backward by the counter!", "gold")
					else:
						add_combat_log("SHIELD BASH! The attack is blocked and countered!", "cyan")
				else:
					add_combat_log("Shield Bash failed. Guard opened up.", "gray")

			# --- KNIGHT: UNBREAKABLE BASTION ---
			elif defender.get("ability") == "Unbreakable Bastion" and randi() % 100 < def_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_unbreakable_bastion_minigame(self, defender)
					_coop_qte_capture_write(_cqe, result)
				if result == 2:
					ability_triggers_count += 1
					defense_resolved_and_won = true
					spawn_loot_text("BASTION!", Color(1.0, 0.85, 0.2), defender.global_position + Vector2(32, -32))
					add_combat_log("PERFECT UNBREAKABLE BASTION! The blow does nothing!", "gold")
				elif result == 1:
					ability_triggers_count += 1
					incoming_damage_multiplier = min(incoming_damage_multiplier, 0.15)
					spawn_loot_text("BRACED!", Color(0.8, 0.9, 1.0), defender.global_position + Vector2(32, -32))
					add_combat_log("UNBREAKABLE BASTION! The shield absorbs nearly everything.", "cyan")
				else:
					add_combat_log("Unbreakable Bastion failed to set in time.", "gray")

			# --- MONK: INNER PEACE ---
			elif defender.get("ability") == "Inner Peace" and randi() % 100 < def_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_inner_peace_minigame(self, defender)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					defense_resolved_and_won = true
			
					var avo_bonus: int = 0
					var res_bonus: int = 0
					var def_bonus: int = 0
					var calm_heal: int = 0
			
					if result == 2:
						avo_bonus = 35
						res_bonus = 7
						def_bonus = 4
						calm_heal = int(max(2, int(round(float(defender.magic) * 0.35))))
						add_combat_log("PERFECT INNER PEACE! The Monk slips beyond harm itself.", "gold")
					else:
						avo_bonus = 20
						res_bonus = 4
						def_bonus = 2
						calm_heal = int(max(1, int(round(float(defender.magic) * 0.20))))
						add_combat_log("INNER PEACE! The Monk calmly avoids the blow.", "cyan")
			
					defender.set_meta("inner_peace_avo_bonus_temp", avo_bonus)
					defender.set_meta("inner_peace_res_bonus_temp", res_bonus)
					defender.set_meta("inner_peace_def_bonus_temp", def_bonus)
			
					if calm_heal > 0:
						defender.current_hp = min(defender.current_hp + calm_heal, defender.max_hp)
						if defender.get("health_bar") != null:
							defender.health_bar.value = defender.current_hp
						spawn_loot_text("+" + str(calm_heal), Color(0.65, 1.0, 0.85), defender.global_position + Vector2(32, -30))
				else:
					add_combat_log("Inner Peace broke. The Monk lost their meditative rhythm.", "gray")

			# --- PALADIN: HOLY WARD ---
			elif defender.get("ability") == "Holy Ward" and randi() % 100 < def_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_holy_ward_minigame(self, defender)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					var is_magic_atk: bool = (wpn != null and wpn.get("damage_type") != null and wpn.damage_type == WeaponData.DamageType.MAGIC)
					
					if result == 2:
						defender.set_meta("holy_ward_res_bonus_temp", 25)
						if is_magic_atk: incoming_damage_multiplier = min(incoming_damage_multiplier, 0.1)
						spawn_loot_text("HOLY WARD!", Color(1.0, 0.85, 0.2), defender.global_position + Vector2(32, -32))
						add_combat_log("PERFECT HOLY WARD! Absolute divine shielding!", "gold")
					else:
						defender.set_meta("holy_ward_res_bonus_temp", 10)
						if is_magic_atk: incoming_damage_multiplier = min(incoming_damage_multiplier, 0.5)
						spawn_loot_text("WARDED!", Color(0.8, 0.9, 1.0), defender.global_position + Vector2(32, -32))
						add_combat_log("HOLY WARD! Magical defenses raised.", "cyan")
				else:
					add_combat_log("Holy Ward failed to materialize.", "gray")

			# --- SPELLBLADE: BLINK STEP ---
			elif defender.get("ability") == "Blink Step" and randi() % 100 < def_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var result: int
				if _coop_qte_mirror_active:
					result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					result = await QTEManager.run_blink_step_minigame(self, defender)
					_coop_qte_capture_write(_cqe, result)
				if result > 0:
					ability_triggers_count += 1
					
					if result == 2:
						defense_resolved_and_won = true # Dodge completely!
						spawn_loot_text("BLINK!", Color(0.9, 0.5, 1.0), defender.global_position + Vector2(32, -32))
						add_combat_log("PERFECT BLINK STEP! A flawless evasion!", "gold")
					else:
						incoming_damage_multiplier = min(incoming_damage_multiplier, 0.5) # Half damage
						spawn_loot_text("GLANCING!", Color(0.7, 0.5, 0.9), defender.global_position + Vector2(32, -32))
						add_combat_log("BLINK STEP! Only partially evaded the attack.", "violet")
				else:
					add_combat_log("Blink Step was too slow. Struck fully.", "gray")

			# --- OLD SHIELD CLASH ---
			elif defender.get("ability") == "Shield Clash" and randi() % 100 < def_trigger_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var clash_result: int
				if _coop_qte_mirror_active:
					clash_result = _coop_qte_mirror_read_int(_cqe, 0)
				else:
					clash_result = await _run_shield_clash_minigame(defender, attacker)
					_coop_qte_capture_write(_cqe, clash_result)
				
				if clash_result > 0:
					ability_triggers_count += 1
					defense_resolved_and_won = true
					
					var heal_amt = int(defender.max_hp * 0.25)
					defender.current_hp = min(defender.current_hp + heal_amt, defender.max_hp)
					if defender.get("health_bar") != null: defender.health_bar.value = defender.current_hp
					spawn_loot_text("+" + str(heal_amt) + " HP", Color(0.2, 1.0, 0.2), defender.global_position + Vector2(32, -32))
					
					if clash_result == 2:
						add_combat_log("PERFECT CLASH! Devastating Counter!", "gold")
						var def_wpn = defender.equipped_weapon
						var base_counter_dmg = max(1, (defender.strength + (def_wpn.might if def_wpn else 0)) - attacker.defense)
						var final_counter_dmg = base_counter_dmg * 3 
						
						screen_shake(15.0, 0.4)
						if crit_sound.stream != null: crit_sound.play()
						attacker.take_damage(final_counter_dmg, defender)
						spawn_loot_text(str(final_counter_dmg) + " CRIT!", Color(1.0, 0.2, 0.2), attacker.global_position + Vector2(32, -16))
					else:
						add_combat_log("SHIELD CLASH WON! Attack deflected.", "lime")
				else:
					add_combat_log("Shield Clash Failed! Guard broken!", "red")			
			
			# --- UNIVERSAL PARRY ---
			elif randi() % 100 < parry_chance:
				var _cqe := _coop_qte_alloc_event_id()
				var won_parry: bool
				if _coop_qte_mirror_active:
					won_parry = _coop_qte_mirror_read_bool(_cqe, false)
				else:
					won_parry = await _run_parry_minigame(defender)
					_coop_qte_capture_write(_cqe, won_parry)
				if won_parry:
					ability_triggers_count += 1
					defense_resolved_and_won = true
					add_combat_log("PARRY SUCCESSFUL!", "lime")
					
					var def_wpn = defender.equipped_weapon
					var is_magic_counter = def_wpn != null and def_wpn.damage_type == WeaponData.DamageType.MAGIC
					var counter_offense = defender.magic if is_magic_counter else defender.strength
					var counter_defense = attacker.resistance if is_magic_counter else attacker.defense
					var base_counter_dmg = max(1, (counter_offense + (def_wpn.might if def_wpn else 0)) - counter_defense)
					
					if crit_sound.stream != null: crit_sound.play()
					attacker.take_damage(base_counter_dmg, defender)
					spawn_loot_text(str(base_counter_dmg) + " DMG", Color(1.0, 1.0, 1.0), attacker.global_position + Vector2(32, -16))
				else:
					add_combat_log("Parry Failed! Timing missed!", "red")
		
		# ==========================================
		# PHASE E: NORMAL ATTACK RESOLUTION
		# ==========================================
		
		# Apply defensive damage reductions
		damage = int(round(float(damage) * incoming_damage_multiplier))
		
		if not defense_resolved_and_won:
			if attack_hits:
				_rookie_register_apprentice_magic_hit(attacker, wpn, is_magic, true)
				# ==========================================
				# --- IMPACT JUICE (HIT-STOP & ZOOM) ---
				# ==========================================
				var impact_focus: Vector2 = defender.global_position + Vector2(32, 32)

				if attack_hits and is_crit:
					await _play_critical_impact(impact_focus)
				elif already_staggered or will_stagger:
					await _play_guard_break_impact(impact_focus)
				elif did_melee_normal_animation:
					# Light hit-stop on normal melee only — ranged/magic keep prior pacing
					await _do_hit_stop(0.007, 0.22, 0.04)
				# ==========================================
				
				var final_dmg: int = damage * 3 if is_crit else damage
				
				# --- 1. APPLY POISE REDUCTION ALWAYS (Even on 0 DMG!) ---
				if will_stagger:
					defender.set_meta("current_poise", 0)
					defender.set_meta("is_staggered_this_combat", true)
				elif not already_staggered:
					defender.set_meta("current_poise", clampi(def_current_poise - poise_dmg, 0, def_max_poise))

				if defender.has_method("update_poise_visuals"): 
					defender.update_poise_visuals()

				# --- 2. NO DAMAGE CHECK ---
				if final_dmg <= 0:
					if no_damage_sound and no_damage_sound.stream:
						no_damage_sound.play()
					spawn_loot_text("NO DAMAGE", Color.LIGHT_GRAY, defender.global_position + Vector2(32, -16))
					add_combat_log(attacker.unit_name + " attacked " + defender.unit_name + " but dealt no damage!", "gray")
					screen_shake(3.0, 0.15)
					
					# Edge case: If they had exactly 1 Poise left and a 0 DMG attack broke it
					if will_stagger:
						spawn_loot_text("GUARD BREAK!", Color.ORANGE, defender.global_position + Vector2(32, -40))
						screen_shake(12.0, 0.2)
						if defender.has_method("set_staggered_visuals"):
							defender.set_staggered_visuals(true)
							
				else:
					var is_lethal: bool = final_dmg >= defender.current_hp
					var death_defied: bool = false
					
					# --- CLERIC: MIRACLE ---
					if is_lethal and defender.get("ability") == "Miracle" and (defender.get_parent() == player_container or defender.get_parent() == ally_container):
						var _cqe := _coop_qte_alloc_event_id()
						var result: int
						if _coop_qte_mirror_active:
							result = _coop_qte_mirror_read_int(_cqe, 0)
						else:
							result = await QTEManager.run_miracle_minigame(self, defender)
							_coop_qte_capture_write(_cqe, result)
						if result > 0:
							death_defied = true
							ability_triggers_count += 1
					
							if result == 2:
								defender.current_hp = max(1, int(round(defender.max_hp * 0.25)))
								spawn_loot_text("PERFECT MIRACLE!", Color(1.0, 0.85, 0.2), defender.global_position + Vector2(32, -16))
								add_combat_log(defender.unit_name + " invoked a PERFECT MIRACLE and cheated death!", "gold")
							else:
								defender.current_hp = 1
								spawn_loot_text("MIRACLE!", Color(1.0, 1.0, 0.6), defender.global_position + Vector2(32, -16))
								add_combat_log(defender.unit_name + " survived the fatal blow with Miracle!", "khaki")
					
							if defender.get("health_bar") != null:
								defender.health_bar.value = defender.current_hp
					
					# --- THE LAST STAND (Lethal Blow Protection) ---
					if not death_defied and is_lethal and defender.get("is_custom_avatar") == true:
						var _cqe_ls := _coop_qte_alloc_event_id()
						if _coop_qte_mirror_active:
							death_defied = _coop_qte_mirror_read_bool(_cqe_ls, false)
						else:
							death_defied = await _run_last_stand_minigame(defender)
							_coop_qte_capture_write(_cqe_ls, death_defied)
						if death_defied:
							final_dmg = 0
							is_crit = false
							ability_triggers_count += 2
							add_combat_log(defender.unit_name + " defied death!", "gold")
							spawn_loot_text("DEATH DEFIED!", Color(1.0, 0.8, 0.2), defender.global_position + Vector2(32, -16))
							
					var actually_dies: bool = is_lethal and not death_defied
					
					# --- 3. GUARD BREAK VISUALS (Only if they survive!) ---
					if will_stagger and not actually_dies:
						spawn_loot_text("GUARD BREAK!", Color.ORANGE, defender.global_position + Vector2(32, -40))
						screen_shake(12.0, 0.2)
						if defender.has_method("set_staggered_visuals"):
							defender.set_staggered_visuals(true)

					if not death_defied:
						# --- HUNDRED POINT STRIKE FLURRY ---
						if combo_hits > 0:
							for hit_idx in range(combo_hits):
								if not is_instance_valid(defender) or defender.current_hp <= 0: break
								var current_hit_dmg: int = int(max(1.0, float(damage) * 0.5)) 
								if hit_idx >= 5: current_hit_dmg = int(float(current_hit_dmg) * pow(0.75, hit_idx - 4))
								current_hit_dmg = int(max(1, current_hit_dmg)) 
								
								if attack_sound.stream != null: attack_sound.play()
								screen_shake(4.0, 0.05)
								attacker.position += lunge_dir * 4.0
								var snap = create_tween()
								snap.tween_property(attacker, "position", attacker.position - (lunge_dir * 4.0), 0.05)
								
								spawn_loot_text(str(current_hit_dmg), Color(0.9, 0.2, 1.0), defender.global_position + Vector2(32, -16) + Vector2(randf_range(-24,24), randf_range(-24,24)))
								
								spawn_slash_effect(defender.global_position, attacker.global_position, false)
								spawn_blood_splatter(defender, attacker.global_position, false)
								
								var exp_tgt = attacker if (defender.current_hp <= current_hit_dmg or hit_idx == combo_hits - 1) else null
								_apply_hit_with_support_reactions(defender, current_hit_dmg, attacker, exp_tgt, false)
								# --- PROMOTED FIRE SAGE POST-HIT (Permanent Burn) ---
							if hellfire_result == 2 and is_instance_valid(defender) and defender.current_hp > 0:
								defender.set_meta("is_burning", true)
								add_combat_log(attacker.unit_name + " ignited " + defender.unit_name + "!", "orange")
								spawn_loot_text("IGNITED!", Color(1.0, 0.4, 0.1), defender.global_position + Vector2(32, -40))
								
								await get_tree().create_timer(0.1).timeout
						
						# --- STANDARD ATTACK ---
						else:
							if attack_hits and is_crit:
								if not did_melee_crit_animation and crit_sound.stream != null:
									crit_sound.play()
								screen_shake(15.0, 0.4)
							else:
								if wpn != null and wpn.get("custom_hit_sound") != null:
									var custom_audio = AudioStreamPlayer.new()
									custom_audio.stream = wpn.custom_hit_sound
									add_child(custom_audio)
									custom_audio.play()
									custom_audio.finished.connect(custom_audio.queue_free)
								else:
									if attack_sound.stream != null: attack_sound.play()

							add_combat_log(attacker.unit_name + " hit " + defender.unit_name + " for " + str(final_dmg) + (" (CRIT)" if is_crit else ""), "gold" if is_crit else "white")
							if is_crit and atk_rel.get("crit_bonus", 0) > 0 and attacker.get("unit_name") != null:
								add_combat_log("Rivalry sharpens " + str(attacker.unit_name) + "'s strike!", "yellow")
							spawn_loot_text(str(final_dmg) + (" CRIT" if is_crit else ""), Color(1.0, 0.2, 0.2) if is_crit else Color.WHITE, defender.global_position + Vector2(32, -16))
							spawn_slash_effect(defender.global_position, attacker.global_position, is_crit)
							spawn_blood_splatter(defender, attacker.global_position, is_crit)
							
							# =========================================================
							# --- EARN SUPPORT POINTS (Includes Green Allies!) ---
							# =========================================================
							if attacker.get_parent() == player_container or attacker.get_parent() == ally_container:
								var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
								var current_pos = get_grid_pos(attacker)
								
								for dir in directions:
									var n_pos = current_pos + dir
									var support_ally = get_unit_at(n_pos)
									
									if support_ally == null and ally_container != null:
										for a in ally_container.get_children():
											if get_grid_pos(a) == n_pos and not a.is_queued_for_deletion():
												support_ally = a
												break
												
									if support_ally != null and support_ally != attacker:
										_add_support_points_and_check(attacker, support_ally, 1)
							
							if attacker.get_parent() == player_container:
								loot_recipient = attacker
							else:
								loot_recipient = null
								
							_apply_hit_with_support_reactions(defender, final_dmg, attacker, attacker, false)
							if hellfire_result == 2 and is_instance_valid(defender) and defender.current_hp > 0:
								defender.set_meta("is_burning", true)
								add_combat_log(attacker.unit_name + " ignited " + defender.unit_name + "!", "orange")
								spawn_loot_text("IGNITED!", Color(1.0, 0.4, 0.1), defender.global_position + Vector2(32, -40))
							# --- PROMOTED BLADE MASTER POST-HIT (Multi-slash) ---
							if severing_strike_hits > 1 and is_instance_valid(defender) and defender.current_hp > 0:
								for hit_idx in range(severing_strike_hits - 1): # -1 because the first hit was the main attack
									await get_tree().create_timer(0.15).timeout
									if not is_instance_valid(defender) or defender.current_hp <= 0: break
									
									var slash_dmg: int = int(max(1.0, float(damage) * severing_strike_damage_multiplier))
									if attack_sound and attack_sound.stream != null: attack_sound.play()
									spawn_loot_text(str(slash_dmg), Color(0.70, 0.90, 1.00), defender.global_position + Vector2(32, -16) + Vector2(randf_range(-18, 18), randf_range(-12, 12)))
									spawn_slash_effect(defender.global_position, attacker.global_position, force_crit)
									_apply_hit_with_support_reactions(defender, slash_dmg, attacker, attacker, false)

							# --- PROMOTED BOW KNIGHT POST-HIT (Tactical Retreat) ---
							if parting_shot_dodge and is_instance_valid(attacker) and attacker.current_hp > 0:
								# Move the attacker 1 tile backward
								var b_pos: Vector2i = get_grid_pos(attacker)
								var back_dir: Vector2i = Vector2i(round(-lunge_dir.x), round(-lunge_dir.y))
								var safe_tile: Vector2i = b_pos + back_dir
								
								if safe_tile.x >= 0 and safe_tile.x < GRID_SIZE.x and safe_tile.y >= 0 and safe_tile.y < GRID_SIZE.y:
									if not astar.is_point_solid(safe_tile) and get_occupant_at(safe_tile) == null:
										var backflip: Tween = create_tween()
										backflip.tween_property(attacker, "global_position", Vector2(safe_tile.x * CELL_SIZE.x, safe_tile.y * CELL_SIZE.y), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
										astar.set_point_solid(b_pos, false)
										astar.set_point_solid(safe_tile, true)
										spawn_loot_text("RETREAT!", Color.CYAN, attacker.global_position + Vector2(32, -40))
										
							# --- PROMOTED ASSASSIN POST-HIT ---
							if shadow_pin_speed_lock and is_instance_valid(defender):
								defender.speed = 0
								spawn_loot_text("PINNED!", Color(0.6, 0.3, 0.9), defender.global_position + Vector2(32, -40))
								
							# --- PROMOTED HERO POST-HIT ---
							if vanguards_rally_might_bonus > 0:
								if player_container != null:
									for ally in player_container.get_children():
										if is_instance_valid(ally) and ally.current_hp > 0:
											ally.strength += vanguards_rally_might_bonus
											ally.magic += vanguards_rally_might_bonus
											spawn_loot_text("RALLIED!", Color(1.0, 0.9, 0.4), ally.global_position + Vector2(32, -24))
											
							# --- PROMOTED BERSERKER POST-HIT ---
							if savage_toss_distance > 0 and is_instance_valid(defender) and defender.current_hp > 0:
								var t_pos: Vector2i = get_grid_pos(defender)
								for step in range(savage_toss_distance):
									var next_tile: Vector2i = t_pos + Vector2i(round(lunge_dir.x), round(lunge_dir.y))
									if next_tile.x >= 0 and next_tile.x < GRID_SIZE.x and next_tile.y >= 0 and next_tile.y < GRID_SIZE.y:
										if not astar.is_point_solid(next_tile) and get_occupant_at(next_tile) == null:
											t_pos = next_tile
										else:
											var crash_dmg: int = 15
											_apply_hit_with_support_reactions(defender, crash_dmg, attacker, attacker, false)
											screen_shake(12.0, 0.2)
											spawn_loot_text("CRASH!", Color.RED, defender.global_position + Vector2(32, -40))
											break
									else:
										break
										
								if t_pos != get_grid_pos(defender):
									var toss_tween: Tween = create_tween()
									toss_tween.tween_property(defender, "global_position", Vector2(t_pos.x * CELL_SIZE.x, t_pos.y * CELL_SIZE.y), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
									astar.set_point_solid(get_grid_pos(defender), false)
									astar.set_point_solid(t_pos, true)
									await toss_tween.finished
									
							if lifesteal_percent > 0.0 and is_instance_valid(attacker) and attacker.current_hp > 0:
								var heal: int = int(final_dmg * lifesteal_percent)
								if heal > 0:
									attacker.current_hp = min(attacker.current_hp + heal, attacker.max_hp)
									if attacker.get("health_bar") != null: attacker.health_bar.value = attacker.current_hp
									await get_tree().create_timer(0.2).timeout
									if is_instance_valid(attacker): spawn_loot_text("+" + str(heal) + " HP", Color(0.2, 1.0, 0.2), attacker.global_position + Vector2(-32, -16))
									
							# --- ARCHER QTE: VOLLEY FOLLOW-UP HITS ---
							if volley_extra_hits > 0 and is_instance_valid(defender) and defender.current_hp > 0:
								for volley_idx in range(volley_extra_hits):
									await get_tree().create_timer(0.10).timeout
									var vol_tgt: Node2D = defender
									if volley_idx == 1 and volley_spread_target != null and is_instance_valid(volley_spread_target) and not volley_spread_target.is_queued_for_deletion() and volley_spread_target.current_hp > 0 and volley_spread_target.get_parent() == enemy_container:
										vol_tgt = volley_spread_target
									elif not is_instance_valid(defender) or defender.current_hp <= 0:
										break
							
									var volley_dmg: int = int(round(max(1.0, float(damage)) * volley_damage_multiplier))
							
									if attack_sound and attack_sound.stream != null:
										attack_sound.play()
							
									spawn_loot_text(str(volley_dmg), Color(0.70, 0.90, 1.00), vol_tgt.global_position + Vector2(32, -16) + Vector2(randf_range(-18, 18), randf_range(-12, 12)))
									add_combat_log(attacker.unit_name + "'s Volley arrow hits " + str(vol_tgt.unit_name) + " for " + str(volley_dmg) + ".", "cyan")
									_apply_hit_with_support_reactions(vol_tgt, volley_dmg, attacker, attacker, false)
							
							# --- ARCHER QTE: RAIN OF ARROWS SPLASH ---
							if rain_splash_targets.size() > 0:
								await get_tree().create_timer(0.12).timeout
							
								for splash_target in rain_splash_targets:
									if splash_target == null or not is_instance_valid(splash_target) or splash_target.is_queued_for_deletion():
										continue
									if splash_target.current_hp <= 0:
										continue
							
									if attack_sound and attack_sound.stream != null:
										attack_sound.play()

									var rain_d: int = rain_splash_damage
									if rain_tail_unit != null and splash_target == rain_tail_unit and rain_rear_extra_damage > 0:
										rain_d += rain_rear_extra_damage
							
									spawn_loot_text(str(rain_d) + " SPLASH", Color(1.0, 0.86, 0.45), splash_target.global_position + Vector2(32, -16))
									add_combat_log(splash_target.unit_name + " is struck by falling arrows for " + str(rain_d) + ".", "khaki")
									splash_target.take_damage(rain_d, attacker)

							# --- MAGE QTE: FIREBALL SPLASH ---
							if fireball_splash_targets.size() > 0:
								await get_tree().create_timer(0.12).timeout

								for splash_target in fireball_splash_targets:
									if splash_target == null or not is_instance_valid(splash_target) or splash_target.is_queued_for_deletion():
										continue
									if splash_target.current_hp <= 0:
										continue

									if attack_sound and attack_sound.stream != null:
										attack_sound.play()

									var fb_splash: int = fireball_splash_damage
									if fireball_tail_unit != null and splash_target == fireball_tail_unit:
										fb_splash += fireball_tail_extra_damage
									spawn_loot_text(str(fb_splash) + " BURN", Color(1.0, 0.65, 0.25), splash_target.global_position + Vector2(32, -16))
									add_combat_log(splash_target.unit_name + " is caught in the Fireball blast for " + str(fb_splash) + ".", "orange")
									splash_target.take_damage(fb_splash, attacker)

							# --- MAGE QTE: METEOR STORM SPLASH ---
							if meteor_storm_splash_targets.size() > 0:
								await get_tree().create_timer(0.12).timeout

								for splash_target in meteor_storm_splash_targets:
									if splash_target == null or not is_instance_valid(splash_target) or splash_target.is_queued_for_deletion():
										continue
									if splash_target.current_hp <= 0:
										continue

									if attack_sound and attack_sound.stream != null:
										attack_sound.play()

									var met_splash: int = meteor_storm_splash_damage
									if meteor_tail_unit != null and splash_target == meteor_tail_unit:
										met_splash += meteor_tail_extra_damage
									spawn_loot_text(str(met_splash) + " METEOR", Color(1.0, 0.45, 0.25), splash_target.global_position + Vector2(32, -16))
									add_combat_log(splash_target.unit_name + " is smashed by falling meteors for " + str(met_splash) + ".", "tomato")
									splash_target.take_damage(met_splash, attacker)

							# --- MERCENARY QTE: FLURRY STRIKE FOLLOW-UP HITS ---
							if flurry_strike_hits > 0 and is_instance_valid(defender) and defender.current_hp > 0:
								for flurry_idx in range(flurry_strike_hits):
									await get_tree().create_timer(0.08).timeout
									if not is_instance_valid(defender) or defender.current_hp <= 0:
										break

									var flurry_dmg: int = int(round(max(1.0, float(damage)) * flurry_strike_damage_multiplier))

									if attack_sound and attack_sound.stream != null:
										attack_sound.play()

									spawn_loot_text(str(flurry_dmg), Color(0.90, 0.95, 1.00), defender.global_position + Vector2(32, -16) + Vector2(randf_range(-18, 18), randf_range(-12, 12)))
									add_combat_log(attacker.unit_name + "'s Flurry Strike follow-up hits for " + str(flurry_dmg) + ".", "white")
									_apply_hit_with_support_reactions(defender, flurry_dmg, attacker, attacker, false)

							# --- MERCENARY QTE: BLADE TEMPEST SPLASH ---
							if blade_tempest_splash_targets.size() > 0:
								await get_tree().create_timer(0.10).timeout

								for splash_target in blade_tempest_splash_targets:
									if splash_target == null or not is_instance_valid(splash_target) or splash_target.is_queued_for_deletion():
										continue
									if splash_target.current_hp <= 0:
										continue

									if attack_sound and attack_sound.stream != null:
										attack_sound.play()

									spawn_loot_text(str(blade_tempest_splash_damage) + " TEMPEST", Color(0.75, 0.90, 1.00), splash_target.global_position + Vector2(32, -16))
									add_combat_log(splash_target.unit_name + " is slashed by Blade Tempest for " + str(blade_tempest_splash_damage) + ".", "cyan")
									splash_target.take_damage(blade_tempest_splash_damage, attacker)

							# --- MONK QTE: CHI BURST SPLASH ---
							if chi_burst_splash_targets.size() > 0:
								await get_tree().create_timer(0.12).timeout

								for splash_target in chi_burst_splash_targets:
									if splash_target == null or not is_instance_valid(splash_target) or splash_target.is_queued_for_deletion():
										continue
									if splash_target.current_hp <= 0:
										continue

									if attack_sound and attack_sound.stream != null:
										attack_sound.play()

									spawn_loot_text(str(chi_burst_splash_damage) + " CHI", Color(0.75, 0.55, 1.0), splash_target.global_position + Vector2(32, -16))
									add_combat_log(splash_target.unit_name + " is struck by the Chi Burst for " + str(chi_burst_splash_damage) + ".", "violet")
									splash_target.take_damage(chi_burst_splash_damage, attacker)
									
							# --- PALADIN QTE: SMITE HOLY SPLASH (ortho neighbors of target) ---
							if smite_splash_targets.size() > 0 and smite_splash_damage > 0:
								await get_tree().create_timer(0.10).timeout
								for sm_sp in smite_splash_targets:
									if sm_sp == null or not is_instance_valid(sm_sp) or sm_sp.is_queued_for_deletion():
										continue
									if sm_sp.current_hp <= 0:
										continue
									if attack_sound and attack_sound.stream != null:
										attack_sound.play()
									spawn_loot_text(str(smite_splash_damage) + " HOLY", Color(1.0, 0.95, 0.55), sm_sp.global_position + Vector2(32, -16))
									add_combat_log(sm_sp.unit_name + " is scorched by Smite's holy spill for " + str(smite_splash_damage) + ".", "yellow")
									sm_sp.take_damage(smite_splash_damage, attacker)

							# --- PALADIN QTE: SACRED JUDGMENT SPLASH ---
							if sacred_judgment_splash_targets.size() > 0:
								await get_tree().create_timer(0.12).timeout

								for splash_target in sacred_judgment_splash_targets:
									if splash_target == null or not is_instance_valid(splash_target) or splash_target.is_queued_for_deletion():
										continue
									if splash_target.current_hp <= 0:
										continue

									if attack_sound and attack_sound.stream != null:
										attack_sound.play()

									spawn_loot_text(str(sacred_judgment_splash_damage) + " HOLY", Color(1.0, 0.9, 0.4), splash_target.global_position + Vector2(32, -16))
									add_combat_log(splash_target.unit_name + " is scorched by Sacred Judgment for " + str(sacred_judgment_splash_damage) + ".", "yellow")
									splash_target.take_damage(sacred_judgment_splash_damage, attacker)
									
							# --- SPELLBLADE QTE: ELEMENTAL CONVERGENCE SPLASH ---
							if elemental_convergence_splash_targets.size() > 0:
								await get_tree().create_timer(0.12).timeout

								for splash_target in elemental_convergence_splash_targets:
									if splash_target == null or not is_instance_valid(splash_target) or splash_target.is_queued_for_deletion():
										continue
									if splash_target.current_hp <= 0:
										continue

									if attack_sound and attack_sound.stream != null:
										attack_sound.play()

									spawn_loot_text(str(elemental_convergence_splash_damage) + " MAGIC", Color(0.4, 0.8, 1.0), splash_target.global_position + Vector2(32, -16))
									add_combat_log(splash_target.unit_name + " is hit by the Elemental Convergence blast for " + str(elemental_convergence_splash_damage) + ".", "cyan")
									splash_target.take_damage(elemental_convergence_splash_damage, attacker)
									
							# --- CHARGE: COLLISION DAMAGE (rear foe pinned in the charge line) ---
							if charge_collision_target != null and charge_collision_damage > 0:
								await get_tree().create_timer(0.08).timeout
								var cc: Node2D = charge_collision_target
								if is_instance_valid(cc) and not cc.is_queued_for_deletion() and cc.current_hp > 0 and cc.get_parent() == enemy_container:
									if attack_sound and attack_sound.stream != null:
										attack_sound.play()
									spawn_loot_text(str(charge_collision_damage) + " PIN", Color(1.0, 0.55, 0.35), cc.global_position + Vector2(32, -16))
									add_combat_log(cc.unit_name + " is slammed by the pinned charge for " + str(charge_collision_damage) + ".", "coral")
									cc.take_damage(charge_collision_damage, attacker)

							# --- BALLISTA SHOT: LINE OVERPENETRATION (behind primary target) ---
							if ballista_shot_pierce_targets.size() > 0 and ballista_shot_pierce_damage > 0:
								await get_tree().create_timer(0.10).timeout
								for pierce_target in ballista_shot_pierce_targets:
									if pierce_target == null or not is_instance_valid(pierce_target) or pierce_target.is_queued_for_deletion():
										continue
									if pierce_target.current_hp <= 0:
										continue
									if attack_sound and attack_sound.stream != null:
										attack_sound.play()
									spawn_loot_text(str(ballista_shot_pierce_damage) + " PIERCE", Color(0.55, 0.85, 1.0), pierce_target.global_position + Vector2(32, -16))
									add_combat_log(pierce_target.unit_name + " is struck by the overpenetrating bolt for " + str(ballista_shot_pierce_damage) + ".", "lightskyblue")
									pierce_target.take_damage(ballista_shot_pierce_damage, attacker)

							# --- WARRIOR QTE: EARTHSHATTER SPLASH ---
							if earthshatter_splash_targets.size() > 0:
								await get_tree().create_timer(0.12).timeout

								for splash_target in earthshatter_splash_targets:
									if splash_target == null or not is_instance_valid(splash_target) or splash_target.is_queued_for_deletion():
										continue
									if splash_target.current_hp <= 0:
										continue

									if attack_sound and attack_sound.stream != null:
										attack_sound.play()

									spawn_loot_text(str(earthshatter_splash_damage) + " SHOCK", Color(1.0, 0.6, 0.2), splash_target.global_position + Vector2(32, -16))
									add_combat_log(splash_target.unit_name + " is caught in the Earthshatter shockwave for " + str(earthshatter_splash_damage) + ".", "orange")
									splash_target.take_damage(earthshatter_splash_damage, attacker)

			else:
				# --- MISS LOGIC ---
				if miss_sound.stream != null: miss_sound.play()
				add_combat_log(attacker.unit_name + " missed " + defender.unit_name, "gray")
				spawn_loot_text("Miss", Color(0.7, 0.7, 0.7), defender.global_position + Vector2(32, -16))
		
		# ==========================================
		# PHASE F: DURABILITY & RETURN
		# ==========================================
		if is_instance_valid(attacker):
			if not did_melee_normal_animation:
				var return_tween: Tween = create_tween()
				return_tween.tween_property(attacker, "global_position", orig_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				await return_tween.finished
			
			# --- DEGRADE WEAPON AFTER STRIKE ---
			if wpn and wpn.get("current_durability") != null and wpn.current_durability > 0:
				wpn.current_durability -= 1
				if wpn.current_durability <= 0:
					spawn_loot_text("BROKEN!", Color.RED, attacker.global_position + Vector2(32, -40))
					screen_shake(15.0, 0.3) # Heavy shake for impact
					if miss_sound.stream != null: miss_sound.play() # Play a negative sound

		# ==========================================
		# PHASE G: FORCED MOVEMENT (SHOVE & PULL) + FIRE TRAP
		# ==========================================
		if force_active_ability and attack_hits and is_instance_valid(defender) and defender.current_hp > 0:
			var abil: String = _resolve_tactical_ability_name(attacker)

			if abil == "Fire Trap":
				var _cqe_ft := _coop_qte_alloc_event_id()
				var is_perfect_ft: bool
				if _coop_qte_mirror_active:
					is_perfect_ft = _coop_qte_mirror_read_bool(_cqe_ft, false)
				else:
					is_perfect_ft = await _run_tactical_action_minigame(attacker, abil)
					_coop_qte_capture_write(_cqe_ft, is_perfect_ft)
				var trap_cell: Vector2i = get_grid_pos(defender)
				var mag: int = int(attacker.get("magic")) if attacker.get("magic") != null else 0
				var ft_dmg: int = default_fire_tile_damage + mag / 3
				ft_dmg = maxi(1, ft_dmg)
				if is_perfect_ft:
					ft_dmg += 2
				var ft_dur: int = 5 if is_perfect_ft else 3
				spawn_fire_tile(trap_cell, ft_dmg, ft_dur)
				add_combat_log(attacker.unit_name + " sears the ground under " + defender.unit_name + "!", "orange")
				spawn_loot_text("FIRE TRAP!", Color(1.0, 0.35, 0.12), defender.global_position + Vector2(32, -32))
			elif abil == "Shove" or abil == "Grapple Hook":
				var _cqe_tac := _coop_qte_alloc_event_id()
				var is_perfect: bool
				if _coop_qte_mirror_active:
					is_perfect = _coop_qte_mirror_read_bool(_cqe_tac, false)
				else:
					is_perfect = await _run_tactical_action_minigame(attacker, abil)
					_coop_qte_capture_write(_cqe_tac, is_perfect)
				var max_distance: int = 2 if is_perfect else 1

				var a_pos: Vector2i = get_grid_pos(attacker)
				var d_pos: Vector2i = get_grid_pos(defender)
				var push_dir: Vector2i = Vector2i.ZERO

				if d_pos.x > a_pos.x: push_dir = Vector2i(1, 0)
				elif d_pos.x < a_pos.x: push_dir = Vector2i(-1, 0)
				elif d_pos.y > a_pos.y: push_dir = Vector2i(0, 1)
				elif d_pos.y < a_pos.y: push_dir = Vector2i(0, -1)

				var target_tile: Vector2i = d_pos
				var tiles_moved: int = 0
				var crashed: bool = false

				if abil == "Shove":
					add_combat_log(attacker.unit_name + " shoved " + defender.unit_name + "!", "yellow")
					spawn_loot_text("SHOVE!", Color.ORANGE, defender.global_position + Vector2(32, -32))

					for step in range(max_distance):
						var next_tile: Vector2i = target_tile + push_dir
						if next_tile.x >= 0 and next_tile.x < GRID_SIZE.x and next_tile.y >= 0 and next_tile.y < GRID_SIZE.y:
							if not astar.is_point_solid(next_tile) and get_occupant_at(next_tile) == null:
								target_tile = next_tile
								tiles_moved += 1
							else:
								crashed = true
								break
						else:
							crashed = true
							break

				elif abil == "Grapple Hook":
					add_combat_log(attacker.unit_name + " hooked " + defender.unit_name + "!", "purple")
					spawn_loot_text("PULLED!", Color.VIOLET, defender.global_position + Vector2(32, -32))

					for step in range(max_distance):
						var next_tile: Vector2i = target_tile - push_dir
						if next_tile == a_pos:
							break
						if next_tile.x >= 0 and next_tile.x < GRID_SIZE.x and next_tile.y >= 0 and next_tile.y < GRID_SIZE.y:
							if not astar.is_point_solid(next_tile) and get_occupant_at(next_tile) == null:
								target_tile = next_tile
								tiles_moved += 1
							else:
								crashed = true
								break
						else:
							crashed = true
							break

				if tiles_moved > 0:
					var slide_tween: Tween = create_tween()
					slide_tween.tween_property(defender, "global_position", Vector2(target_tile.x * CELL_SIZE.x, target_tile.y * CELL_SIZE.y), 0.15 * tiles_moved).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					astar.set_point_solid(d_pos, false)
					astar.set_point_solid(target_tile, true)
					await slide_tween.finished

				if crashed:
					spawn_loot_text("CRASH!", Color.RED, defender.global_position + Vector2(32, -16))
					screen_shake(18.0 if is_perfect else 12.0, 0.25)
					if attack_sound.stream != null: attack_sound.play()
					var crash_dmg: int = 10 if is_perfect else 5
					_apply_hit_with_support_reactions(defender, crash_dmg, attacker, attacker, false)
					add_combat_log(defender.unit_name + " crashed into an obstacle for " + str(crash_dmg) + " damage!", "tomato")
					
		await get_tree().create_timer(0.25).timeout
		
	# ==========================================
	# PHASE H: COMBAT CLEANUP
	# ==========================================
	for unit in [attacker, defender]:
		if unit == null or not is_instance_valid(unit):
			continue
	
		if unit.has_meta("inner_peace_avo_bonus_temp"): unit.remove_meta("inner_peace_avo_bonus_temp")
		if unit.has_meta("inner_peace_res_bonus_temp"): unit.remove_meta("inner_peace_res_bonus_temp")
		if unit.has_meta("inner_peace_def_bonus_temp"): unit.remove_meta("inner_peace_def_bonus_temp")
		if unit.has_meta("frenzy_def_penalty_temp"): unit.remove_meta("frenzy_def_penalty_temp")
		if unit.has_meta("frenzy_res_penalty_temp"): unit.remove_meta("frenzy_res_penalty_temp")
		if unit.has_meta("holy_ward_res_bonus_temp"): unit.remove_meta("holy_ward_res_bonus_temp")
								
func screen_shake(intensity: float = 12.0, duration: float = 0.4) -> void:
	if main_camera == null:
		return

	if _screen_shake_tween:
		_screen_shake_tween.kill()

	main_camera.offset = Vector2.ZERO

	_screen_shake_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	var steps: int = 8
	var step_time: float = duration / float(steps)

	for i in range(steps):
		var random_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		_screen_shake_tween.tween_property(main_camera, "offset", random_offset, step_time)

	_screen_shake_tween.tween_property(main_camera, "offset", Vector2.ZERO, step_time)
		

func get_triangle_advantage(attacker: Node2D, defender: Node2D) -> int:
	var a_wpn = attacker.equipped_weapon
	var d_wpn = defender.equipped_weapon

	if a_wpn == null or d_wpn == null:
		return 0

	var a_type: int = WeaponData.get_weapon_family(int(a_wpn.weapon_type))
	var d_type: int = WeaponData.get_weapon_family(int(d_wpn.weapon_type))

	# Classic physical triangle only for now:
	# Sword-family > Axe-family
	# Axe-family > Lance-family
	# Lance-family > Sword-family
	if (a_type == WeaponData.WeaponType.SWORD and d_type == WeaponData.WeaponType.AXE) \
	or (a_type == WeaponData.WeaponType.AXE and d_type == WeaponData.WeaponType.LANCE) \
	or (a_type == WeaponData.WeaponType.LANCE and d_type == WeaponData.WeaponType.SWORD):
		return 1

	if (a_type == WeaponData.WeaponType.AXE and d_type == WeaponData.WeaponType.SWORD) \
	or (a_type == WeaponData.WeaponType.LANCE and d_type == WeaponData.WeaponType.AXE) \
	or (a_type == WeaponData.WeaponType.SWORD and d_type == WeaponData.WeaponType.LANCE):
		return -1

	return 0
		
func get_ability_trigger_chance(unit: Node2D, is_universal_parry: bool = false) -> int:
	if unit == null: return 0
	
	# 1. Base Chance: 15% for unique abilities, 5% for universal parry
	var chance = 5.0 if is_universal_parry else 15.0
	
	# 2. Level Scaling (Diminishing Returns)
	# Formula: (Level / (Level + Constant)) * Max_Bonus
	if unit.get("level") != null:
		var lvl = float(unit.level)
		var max_level_bonus = 60.0 # Leveling up can never grant more than +60%
		var slowing_curve = 25.0   # Higher = slower growth. At level 25, you get half the max bonus (30%)
		
		var level_bonus = (lvl / (lvl + slowing_curve)) * max_level_bonus
		chance += level_bonus
		
	# 3. WEAPON FOUNDATION
	if unit.get("equipped_weapon") != null and unit.equipped_weapon.get("ability_trigger_bonus") != null:
		chance += float(unit.equipped_weapon.get("ability_trigger_bonus"))
		
	# 4. UNIT/ITEM FOUNDATION
	if unit.get("ability_trigger_bonus") != null:
		chance += float(unit.get("ability_trigger_bonus"))
		
	# 5. Hard cap at 85% to ensure it never becomes fully guaranteed (keeps tension high)
	return clamp(int(chance), 0, 85)
	
func update_gold_display() -> void:
	gold_label.text = "Gold: " + str(player_gold)

func _on_convoy_pressed() -> void:
	if current_state != player_state or player_state.is_forecasting: return
		
	unit_managing_inventory = null
	player_state.is_forecasting = true 
	
	_populate_convoy_list()
	
	equip_button.visible = false
	use_button.visible = false
	inventory_panel.visible = true

func _on_open_inv_pressed() -> void:
	if current_state != player_state or player_state.active_unit == null: return
		
	unit_managing_inventory = player_state.active_unit
	player_state.is_forecasting = true 
	
	_populate_unit_inventory_list()
	
	equip_button.visible = true
	use_button.visible = true
	inventory_panel.visible = true

func _populate_convoy_list() -> void:
	_clear_grids()
	if inv_desc_label: inv_desc_label.text = "Select an item to view details." 
	
	# 1. Build the Main Convoy Grid
	_build_grid_items(convoy_grid, player_inventory, "convoy", null)
	
	# 2. Dynamically build a mini-grid for EVERY unit on the board!
	var vbox = inv_scroll.get_node("InventoryVBox")
	
	for unit in player_container.get_children():
		if unit.is_queued_for_deletion() or unit.current_hp <= 0: continue
		
		# Create a visual header with the unit's name
		var header = Label.new()
		header.text = "\n--- " + unit.unit_name.to_upper() + "'S BACKPACK ---"
		header.add_theme_color_override("font_color", Color.CYAN)
		header.add_theme_font_size_override("font_size", 18)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.set_meta("is_dynamic", true) # Tag it so we can delete it later
		vbox.add_child(header)
		
		# Create a new 5-column grid just for this unit
		var u_grid = GridContainer.new()
		u_grid.columns = 5
		u_grid.set_meta("is_dynamic", true) # Tag it so we can delete it later
		vbox.add_child(u_grid)
		
		var inv = []
		if "inventory" in unit: inv = unit.inventory
		
		# Fill their specific grid with their items!
		_build_grid_items(u_grid, inv, "unit_personal", unit, 5)

func _populate_unit_inventory_list() -> void:
	_clear_grids()
	if inv_desc_label: inv_desc_label.text = "Select an item to view details." 
	var inv = []
	if "inventory" in unit_managing_inventory:
		inv = unit_managing_inventory.inventory
	_build_grid_items(unit_grid, inv, "unit_personal", unit_managing_inventory, 5)

func _clear_grids() -> void:
	# 1. Clear static grids
	for child in unit_grid.get_children(): child.queue_free()
	for child in convoy_grid.get_children(): child.queue_free()
	
	# 2. Clear dynamically generated unit grids
	var vbox = inv_scroll.get_node("InventoryVBox")
	for child in vbox.get_children():
		if child.has_meta("is_dynamic"):
			child.queue_free()
			
	selected_inventory_meta.clear()
	equip_button.disabled = true
	use_button.disabled = true

func _build_grid_items(grid: GridContainer, item_array: Array, source_type: String, owner_unit: Node2D = null, min_slots: int = 0) -> void:
	var display_items = []
	
	# 1. Compress the array for stacking
	for i in range(item_array.size()):
		var item = item_array[i]
		if item == null:
			continue
			
		var can_stack = (item is ConsumableData) or (item is ChestKeyData) or (item is MaterialData)
		var found_stack = false
		
		# We only stack in the Convoy! Personal backpacks remain 1 slot = 1 item.
		if can_stack and source_type == "convoy":
			for d in display_items:
				var d_name = d.item.get("weapon_name") if d.item.get("weapon_name") != null else d.item.get("item_name")
				var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
				
				if d_name != null and i_name != null and d_name == i_name:
					d.count += 1
					d.indices.append(i)
					found_stack = true
					break
					
		if not found_stack:
			display_items.append({"item": item, "count": 1, "indices": [i]})
			
	# 2. Pad with empty slots to meet min_slots
	var total_slots = max(display_items.size(), min_slots)
	
	for i in range(total_slots):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(64, 64)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		style.border_width_bottom = 2
		style.border_color = Color(0.3, 0.3, 0.3)
		btn.add_theme_stylebox_override("normal", style)
		
		grid.add_child(btn)
		
		if i < display_items.size():
			var d = display_items[i]
			var item = d.item
			var count = d.count
			var real_index = d.indices[0]
			
			if item.get("icon") != null:
				btn.icon = item.icon
				btn.expand_icon = true
			else:
				var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
				btn.text = str(i_name).substr(0, 3) if i_name else "???"
				
			# Stack counter
			if count > 1:
				var count_lbl = Label.new()
				count_lbl.text = "x" + str(count)
				count_lbl.add_theme_font_size_override("font_size", 18)
				count_lbl.add_theme_color_override("font_color", Color.WHITE)
				count_lbl.add_theme_constant_override("outline_size", 6)
				count_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
				
				btn.add_child(count_lbl)
				count_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
				count_lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
				count_lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
				count_lbl.offset_right = -4
				count_lbl.offset_bottom = -2
			
			var meta = {
				"source": source_type,
				"index": real_index,
				"item": item,
				"unit": owner_unit,
				"count": count
			}
			btn.set_meta("inv_data", meta)
			
			var is_usable_for_owner: bool = true
			if owner_unit != null and item is WeaponData:
				is_usable_for_owner = _unit_can_use_item_for_ui(owner_unit, item)
			
			if not is_usable_for_owner:
				btn.modulate = Color(1.0, 0.55, 0.55, 0.95)

				var unusable_badge = Label.new()
				unusable_badge.text = "X"
				unusable_badge.add_theme_font_size_override("font_size", 18)
				unusable_badge.add_theme_color_override("font_color", Color.RED)
				unusable_badge.add_theme_constant_override("outline_size", 6)
				unusable_badge.add_theme_color_override("font_outline_color", Color.BLACK)
				btn.add_child(unusable_badge)
				unusable_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
				unusable_badge.position = Vector2(-10, 2)
			
			if owner_unit != null and item == owner_unit.get("equipped_weapon"):
				var eq_style = style.duplicate()
				eq_style.border_color = Color.GOLD
				eq_style.border_width_left = 2
				eq_style.border_width_top = 2
				eq_style.border_width_right = 2
				btn.add_theme_stylebox_override("normal", eq_style)
				
			btn.pressed.connect(func(): _on_grid_item_clicked(btn, meta))
		else:
			btn.disabled = true
			var empty_style = style.duplicate()
			empty_style.bg_color = Color(0.05, 0.05, 0.05, 0.5)
			btn.add_theme_stylebox_override("disabled", empty_style)
							
func _on_grid_item_clicked(btn: Button, meta: Dictionary) -> void:
	if select_sound and select_sound.stream != null:
		select_sound.pitch_scale = 1.2
		select_sound.play()
		
	selected_inventory_meta = meta
	
	for child in unit_grid.get_children() + convoy_grid.get_children():
		child.modulate = Color.WHITE
	btn.modulate = Color(1.5, 1.5, 1.5)
	
	var item = meta["item"]
	var count = meta.get("count", 1)
	var viewer_unit = meta.get("unit", null)
	inv_desc_label.text = _get_item_detailed_info(item, count, viewer_unit)
	
	equip_button.disabled = false
	use_button.disabled = false
	
func _on_equip_pressed() -> void:
	if selected_inventory_meta.is_empty():
		return

	var meta = selected_inventory_meta
	if meta["source"] != "unit_personal":
		return

	var item = meta["item"]
	if item is WeaponData:
		if not _unit_can_equip_weapon(unit_managing_inventory, item):
			if invalid_sound.stream != null:
				invalid_sound.play()
			return

		unit_managing_inventory.equipped_weapon = item
		calculate_ranges(unit_managing_inventory)
		update_unit_info_panel()
		_populate_unit_inventory_list()
		if select_sound.stream != null:
			select_sound.play()

func _on_close_inv_pressed() -> void:
	inventory_panel.visible = false
	if current_state == player_state:
		player_state.is_forecasting = false
	unit_managing_inventory = null

func _on_use_pressed() -> void:
	if selected_inventory_meta.is_empty(): return
	var meta = selected_inventory_meta
	if meta["source"] != "unit_personal": return
	
	var item = meta["item"]
	var real_index = meta["index"]
	
	if item is ConsumableData:
		var unit = unit_managing_inventory
		if item.get("is_promotion_item") == true:
			var current_class = unit.get("active_class_data")
			if unit.level >= 1 and current_class != null and current_class.get("promotion_options") != null and current_class.promotion_options.size() > 0:
				unit.inventory.remove_at(real_index)
				_on_close_inv_pressed()
				var chosen_advanced_class = await _ask_for_promotion_choice(current_class.promotion_options)
				if chosen_advanced_class != null:
					execute_promotion(unit, chosen_advanced_class)
					update_unit_info_panel()
					unit.finish_turn()
					player_state.active_unit = null
					rebuild_grid()
					clear_ranges()
				else:
					unit.inventory.insert(real_index, item)
					_on_open_inv_pressed()
			else:
				if invalid_sound and invalid_sound.stream != null: invalid_sound.play()
				spawn_loot_text("Cannot Promote!", Color.RED, unit.global_position + Vector2(32, -32))
			return 
			
		var gains = {
			"hp": item.hp_boost, "str": item.str_boost, "mag": item.mag_boost,
			"def": item.def_boost, "res": item.res_boost, "spd": item.spd_boost, "agi": item.agi_boost
		}
		apply_stat_gains(unit, gains)
		if item.heal_amount > 0:
			unit.current_hp = min(unit.current_hp + item.heal_amount, unit.max_hp)
			if unit.get("health_bar") != null: unit.health_bar.value = unit.current_hp
		unit.inventory.remove_at(real_index)
		_on_close_inv_pressed()
		var is_permanent = false
		for val in gains.values():
			if val > 0: is_permanent = true
		if is_permanent: await run_theatrical_stat_reveal(unit, item.item_name, gains)
		update_unit_info_panel()
		unit.finish_turn()
		player_state.active_unit = null
		rebuild_grid()
		clear_ranges()

func _get_item_display_text(item: Resource) -> String:
	var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
	var dur_str = ""
	var broken_tag = ""
	
	if item.get("current_durability") != null:
		dur_str = " [%d/%d]" % [item.current_durability, item.max_durability]
		if item.current_durability <= 0:
			broken_tag = "[BROKEN] "
	elif item.get("uses") != null:
		dur_str = " (" + str(item.uses) + " Uses)"
			
	return "%s%s%s" % [broken_tag, i_name, dur_str]

func _get_item_detailed_info(item: Resource, stack_count: int = 1, viewer_unit: Node2D = null) -> String:
	var info = ""
	
	# 1. HEADER (Rarity, Value & Quantity)
	var rarity = item.get("rarity") if item.get("rarity") != null else "Common"
	var cost = item.get("gold_cost") if item.get("gold_cost") != null else 0
	
	var rarity_color = "white"
	match rarity:
		"Uncommon":
			rarity_color = "lime"
		"Rare":
			rarity_color = "deepskyblue"
		"Epic":
			rarity_color = "mediumorchid"
		"Legendary":
			rarity_color = "gold"
		
	var stack_text = ""
	if stack_count > 1:
		stack_text = "   |   [color=white]Owned: x" + str(stack_count) + "[/color]"
		
	info += "[ [color=" + rarity_color + "]" + rarity + "[/color] ]   |   Value: [color=khaki]" + str(cost) + "G[/color]" + stack_text + "\n"
	info += "[color=gray]------------------------------------[/color]\n"

	# 2. WEAPON SPECIFIC STATS
	if item is WeaponData:
		if item.get("current_durability") != null and item.current_durability <= 0:
			info += "[color=red]BROKEN! Effectiveness halved. Needs repair.[/color]\n\n"
			
		var w_type_str = "Unknown"
		if item.get("weapon_type") != null:
			w_type_str = _weapon_type_name_safe(int(item.weapon_type))
		var d_type_str = "Physical" if item.get("damage_type") != null and item.damage_type == 0 else "Magical"
		
		info += "[color=gray]Type:[/color] " + w_type_str + " (" + d_type_str + ")\n"
		info += "[color=coral]Might:[/color] " + str(item.might) + "\n"
		info += "[color=khaki]Hit:[/color] +" + str(item.hit_bonus) + "\n"
		info += "[color=palegreen]Range:[/color] " + str(item.min_range) + "-" + str(item.max_range) + "\n"
		
		if item.get("current_durability") != null:
			info += "[color=lightskyblue]Durability:[/color] " + str(item.current_durability) + " / " + str(item.max_durability) + "\n"
		
		if viewer_unit != null:
			var usable: bool = _unit_can_use_item_for_ui(viewer_unit, item)
			if usable:
				info += "[color=lime]Usable by this unit[/color]\n"
			else:
				info += "[color=red]Cannot be equipped by this unit[/color]\n"
		
		var effects = []
		if item.get("is_healing_staff") == true:
			effects.append("Restores " + str(item.effect_amount) + " HP")
			
		if item.get("is_buff_staff") == true or item.get("is_debuff_staff") == true:
			var word = "Grants +" if item.get("is_buff_staff") == true else "Inflicts -"
			if item.get("affected_stat") != null and str(item.affected_stat) != "":
				var stats = str(item.affected_stat).split(",")
				var formatted_stats = []
				for s in stats:
					formatted_stats.append(s.strip_edges().capitalize())
				effects.append(word + str(item.effect_amount) + " to " + ", ".join(formatted_stats))
			
		if effects.size() > 0:
			info += "[color=plum]Effect:[/color] " + " & ".join(effects) + "\n"
			
	# 3. CONSUMABLE SPECIFIC STATS
	elif item is ConsumableData:
		info += "[color=gray]Type:[/color] Consumable\n"
		
		var effects = []
		if item.heal_amount > 0:
			effects.append("Restores " + str(item.heal_amount) + " HP")
			
		var boosts = []
		if item.hp_boost > 0: boosts.append("+" + str(item.hp_boost) + " HP")
		if item.str_boost > 0: boosts.append("+" + str(item.str_boost) + " STR")
		if item.mag_boost > 0: boosts.append("+" + str(item.mag_boost) + " MAG")
		if item.def_boost > 0: boosts.append("+" + str(item.def_boost) + " DEF")
		if item.res_boost > 0: boosts.append("+" + str(item.res_boost) + " RES")
		if item.spd_boost > 0: boosts.append("+" + str(item.spd_boost) + " SPD")
		if item.agi_boost > 0: boosts.append("+" + str(item.agi_boost) + " AGI")
		
		if boosts.size() > 0:
			effects.append("Permanent Boost: " + ", ".join(boosts))
			
		if effects.size() > 0:
			info += "[color=plum]Effect:[/color]\n" + "\n".join(effects) + "\n"
			
	# 4. MATERIAL SPECIFIC STATS
	elif item is MaterialData:
		info += "[color=gray]Type:[/color] Crafting Material\n"
	else:
		info += "A mysterious item.\n"

	# 5. CUSTOM DESCRIPTION / LORE
	info += "[color=gray]------------------------------------[/color]\n"
	if item.get("description") != null and item.description.strip_edges() != "":
		info += "[color=silver][i]\"" + item.description + "\"[/i][/color]"
	else:
		info += "[color=dimgray][i]No description available.[/i][/color]"
		
	return info
	
func spawn_loot_text(text: String, color: Color, pos: Vector2) -> void:
	var f_text = FloatingTextScene.instantiate()
	f_text.text_to_show = text
	f_text.text_color = color
	add_child(f_text)
	f_text.global_position = pos
	
func show_loot_window() -> void:
	loot_item_list.clear()
	if loot_desc_label: loot_desc_label.text = "Select an item to view details."	
	# Lock the map
	if player_state: player_state.is_forecasting = true
	get_tree().paused = true 
	
	# Ensure the UI keeps running while the game is paused
	loot_window.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 1. Setup for the Elastic Pop-in
	loot_window.scale = Vector2(0.5, 0.5)
	loot_window.modulate.a = 0.0
	loot_window.visible = true
	
	if close_loot_button: close_loot_button.disabled = true
	
	var open_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	open_tween.tween_property(loot_window, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open_tween.tween_property(loot_window, "modulate:a", 1.0, 0.2)
	
	await open_tween.finished
	await get_tree().create_timer(0.2, true, false, true).timeout
	
	# --- NEW: GROUP STACKABLE LOOT FOR THE REVEAL ---
	var display_items = []
	for item in pending_loot:
		var can_stack = (item is ConsumableData) or (item is ChestKeyData) or (item is MaterialData)
		var found_stack = false
		if can_stack:
			for d in display_items:
				if d.item.get("item_name") != null and d.item.get("item_name") == item.get("item_name"):
					d.count += 1
					found_stack = true
					break
		if not found_stack:
			display_items.append({"item": item, "count": 1})
	# ------------------------------------------------
	
	# 2. The Sequential Item Reveal with Rarity!
	var current_pitch = 1.0
	
	for d in display_items:
		var item = d.item
		var display_text = _get_item_display_text(item)
		
		# Add the (x3) multiplier text if there is more than 1
		if d.count > 1:
			display_text += " (x" + str(d.count) + ")"
			
		var img = item.icon if "icon" in item else null
		
		var rarity = item.get("rarity") if item.get("rarity") != null else "Common"
		var item_color = Color.WHITE
		var is_legendary_or_epic = false
		
		match rarity:
			"Uncommon": item_color = Color(0.2, 1.0, 0.2) # Green
			"Rare": item_color = Color(0.2, 0.5, 1.0) # Blue
			"Epic": 
				item_color = Color(0.8, 0.2, 1.0) # Purple
				is_legendary_or_epic = true
			"Legendary": 
				item_color = Color(1.0, 0.8, 0.2) # Gold
				is_legendary_or_epic = true
				
		# Add the item to the UI list and paint it the rarity color
		var idx = loot_item_list.add_item(display_text, img)
		loot_item_list.set_item_custom_fg_color(idx, item_color)
		
		# --- SAVE THE METADATA SO IT CAN BE CLICKED ---
		loot_item_list.set_item_metadata(idx, {"item": item, "count": d.count})
		
		# --- THE REVEAL JUICE ---
		if is_legendary_or_epic:
			if epic_level_up_sound != null and epic_level_up_sound.stream != null:
				epic_level_up_sound.play()
				
			screen_shake(15.0, 0.4)
			
			var flash_rect = ColorRect.new()
			flash_rect.size = get_viewport_rect().size
			flash_rect.color = item_color
			flash_rect.modulate.a = 0.5
			flash_rect.process_mode = Node.PROCESS_MODE_ALWAYS
			get_node("UI").add_child(flash_rect)
			
			var hit_flash = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			hit_flash.tween_property(flash_rect, "modulate:a", 0.0, 0.5)
			hit_flash.tween_callback(flash_rect.queue_free)
			
			await get_tree().create_timer(0.8, true, false, true).timeout 
		else:
			if select_sound.stream != null:
				select_sound.pitch_scale = current_pitch
				select_sound.play()
				current_pitch = min(current_pitch + 0.15, 2.0)
				
			screen_shake(3.0, 0.1)
			await get_tree().create_timer(0.3, true, false, true).timeout
		
	if select_sound.stream != null:
		select_sound.pitch_scale = 1.0
		
	if close_loot_button: close_loot_button.disabled = false
	
func _on_close_loot_pressed() -> void:
	# 1. Immediately hide the popup UI to clear the screen
	var close_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	close_tween.tween_property(loot_window, "scale", Vector2(0.5, 0.5), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	close_tween.tween_property(loot_window, "modulate:a", 0.0, 0.2)
	close_tween.chain().tween_callback(func(): loot_window.visible = false)
	
	close_loot_button.disabled = true 

	# 2. Distribute Loot & Keep track of the EXACT items we added
	var recipient = loot_recipient if is_instance_valid(loot_recipient) else player_state.active_unit
	var looted_items_refs = []
	
	for item in pending_loot:
		looted_items_refs.append(item) # Save the reference to animate later!
		var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
		
		if item is MaterialData:
			player_inventory.append(item)
			add_combat_log(str(i_name) + " sent to Convoy.", "gray")
		else:
			if is_instance_valid(recipient) and recipient.get_parent() == player_container:
				if recipient.inventory.size() < 5:
					recipient.inventory.append(item)
					add_combat_log(recipient.unit_name + " pocketed " + str(i_name) + ".", "cyan")
				else:
					player_inventory.append(item)
					add_combat_log(recipient.unit_name + "'s pockets full. Sent to Convoy.", "gray")
			else:
				player_inventory.append(item)
				add_combat_log(str(i_name) + " sent to Convoy.", "gray")

	await close_tween.finished
	
	# 3. Open the Convoy view so we can see all grids
	unit_managing_inventory = null 
	_populate_convoy_list()
	
	equip_button.visible = false
	use_button.visible = false
	inventory_panel.visible = true
	
	await get_tree().process_frame
	await get_tree().process_frame 
	
	# 4. THE FIX: Perfectly match the looted items to their UI buttons in order!
	var target_buttons = []
	var available_buttons = []
	
	var all_grids = [convoy_grid]
	var vbox = inv_scroll.get_node("InventoryVBox")
	for child in vbox.get_children():
		if child is GridContainer:
			all_grids.append(child)
			
	for grid in all_grids:
		for btn in grid.get_children():
			if btn.has_meta("inv_data"):
				available_buttons.append(btn)
				
	for item in looted_items_refs:
		var found_btn = null
		var is_stackable = (item is ConsumableData) or (item is ChestKeyData) or (item is MaterialData)
		var item_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
		
		for i in range(available_buttons.size()):
			var btn = available_buttons[i]
			var btn_item = btn.get_meta("inv_data").get("item")
			
			if btn_item == item:
				found_btn = btn
				if not is_stackable: 
					available_buttons.remove_at(i) # Uniques consume the slot permanently
				break
			elif is_stackable and btn_item != null:
				var b_name = btn_item.get("weapon_name") if btn_item.get("weapon_name") != null else btn_item.get("item_name")
				if b_name == item_name:
					found_btn = btn
					# Do NOT remove it from available_buttons, so the next stackable item can also fly here!
					break
				
		if found_btn == null:
			found_btn = convoy_button # Failsafe
			
		target_buttons.append(found_btn)
		if found_btn is Button and found_btn != convoy_button:
			found_btn.modulate.a = 0.0 # Hide it until the flying icon hits it
				
	# 5. Spawn and Fly the Icons!
	var vp_center = get_viewport_rect().size / 2.0
	
	var fly_layer = CanvasLayer.new()
	fly_layer.layer = 150 
	fly_layer.process_mode = Node.PROCESS_MODE_ALWAYS 
	add_child(fly_layer)
	
	for i in range(looted_items_refs.size()):
		var item = looted_items_refs[i]
		var target_btn = target_buttons[i]
		
		var flying_icon = TextureRect.new()
		flying_icon.texture = item.get("icon")
		flying_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		flying_icon.custom_minimum_size = Vector2(64, 64)
		flying_icon.pivot_offset = Vector2(32, 32)
		fly_layer.add_child(flying_icon)
		
		flying_icon.global_position = vp_center + Vector2(randf_range(-100, 100), randf_range(-100, 100))
		
		var fly_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fly_tween.tween_interval(i * 0.15) 
		fly_tween.tween_property(flying_icon, "global_position", target_btn.global_position, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		
		# THE BIND FIX: We force Godot to remember EXACTLY which item is attached to this animation
		var impact_func = func(cb_item: Resource, cb_btn: Button, cb_icon: TextureRect):
			cb_icon.queue_free()
			
			var rarity = cb_item.get("rarity") if cb_item.get("rarity") != null else "Common"
			var is_high_tier = (rarity == "Epic" or rarity == "Legendary")
			
			if is_high_tier:
				if crit_sound and crit_sound.stream != null:
					var p = AudioStreamPlayer.new()
					p.stream = crit_sound.stream
					p.pitch_scale = randf_range(1.2, 1.4) 
					p.volume_db = -2.0
					add_child(p)
					p.play()
					p.finished.connect(p.queue_free)
					
				var crack_node = Node2D.new()
				crack_node.position = cb_btn.size / 2.0
				cb_btn.add_child(crack_node)
				
				var angles = [0.5, 2.1, 3.8, 5.0, 1.2]
				for a in angles:
					var line = Line2D.new()
					line.width = 3.0
					line.default_color = Color(0.05, 0.05, 0.05, 0.9) 
					line.add_point(Vector2.ZERO)
					line.add_point(Vector2(cos(a) * 15, sin(a) * 15))
					line.add_point(Vector2(cos(a) * 35 + randf_range(-10, 10), sin(a) * 35 + randf_range(-10, 10)))
					crack_node.add_child(line)
				
				var flash = ColorRect.new()
				flash.set_anchors_preset(Control.PRESET_FULL_RECT)
				flash.color = Color(0.8, 0.2, 1.0) if rarity == "Epic" else Color(1.0, 0.8, 0.2)
				cb_btn.add_child(flash)
				
				cb_btn.modulate.a = 1.0
				cb_btn.scale = Vector2(1.5, 1.5) 
				cb_btn.pivot_offset = cb_btn.size / 2.0
				
				var bounce = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
				bounce.tween_property(cb_btn, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BOUNCE)
				bounce.tween_property(flash, "modulate:a", 0.0, 0.4)
				
				var crack_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				crack_fade.tween_interval(1.0) 
				crack_fade.tween_property(crack_node, "modulate:a", 0.0, 0.3)
				crack_fade.chain().tween_callback(func(): 
					if is_instance_valid(crack_node): crack_node.queue_free()
					if is_instance_valid(flash): flash.queue_free()
				)
				screen_shake(12.0, 0.25)
				
			else:
				if select_sound and select_sound.stream != null:
					var p = AudioStreamPlayer.new()
					p.stream = select_sound.stream
					p.pitch_scale = randf_range(1.5, 1.8) 
					p.volume_db = -5.0
					add_child(p)
					p.play()
					p.finished.connect(p.queue_free)
					
				cb_btn.modulate.a = 1.0
				cb_btn.scale = Vector2(1.2, 1.2)
				cb_btn.pivot_offset = cb_btn.size / 2.0
				var bounce = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				bounce.tween_property(cb_btn, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BOUNCE)
				
		# Attach the bound variables!
		fly_tween.tween_callback(impact_func.bind(item, target_btn, flying_icon))

	# 6. Wait for all animations to finish
	var max_wait_time = 0.4 + (looted_items_refs.size() * 0.15) + 1.5
	await get_tree().create_timer(max_wait_time, true, false, true).timeout
	
	fly_layer.queue_free()
	
	# 7. Close everything
	inventory_panel.visible = false
	pending_loot.clear()
	loot_recipient = null
	close_loot_button.disabled = false
	
	if player_state: player_state.is_forecasting = false
	get_tree().paused = false
	
	update_unit_info_panel()
				
func add_combat_log(message: String, color: String = "white") -> void:
	if battle_log == null:
		return
	const MAX_COMBAT_LOG_LINES: int = 220
	battle_log.append_text("[color=" + color + "]" + message + "[/color]\n")
	var raw: String = battle_log.text
	var lines: PackedStringArray = raw.split("\n")
	if lines.size() > MAX_COMBAT_LOG_LINES:
		var start_idx: int = maxi(0, lines.size() - MAX_COMBAT_LOG_LINES)
		var kept: PackedStringArray = lines.slice(start_idx)
		battle_log.text = "[color=gray](Earlier log trimmed.)[/color]\n" + "\n".join(Array(kept))
		
# Adjacency: per-adjacent ally, support-rank scaled (original behavior). Support-combat layer adds separately via get_support_combat_bonus.
func get_adjacency_bonus(unit: Node2D) -> Dictionary:
	var bonus := {"hit": 0, "def": 0}
	if unit.get_parent() == destructibles_container:
		return bonus
	var current_pos := get_grid_pos(unit)
	var directions := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var is_allied := (unit.get_parent() == player_container or (ally_container != null and unit.get_parent() == ally_container))
	for dir in directions:
		var neighbor_pos: Vector2i = current_pos + dir
		var teammate: Node2D = null
		if is_allied:
			teammate = get_unit_at(neighbor_pos)
			if teammate == null and ally_container != null:
				for a in ally_container.get_children():
					if get_grid_pos(a) == neighbor_pos and not a.is_queued_for_deletion():
						teammate = a
						break
		else:
			teammate = get_enemy_at(neighbor_pos)
		if teammate == null or teammate == unit:
			continue
		var support_rank: int = 0
		if is_allied:
			var bond: Dictionary = CampaignManager.get_support_bond(get_support_name(unit), get_support_name(teammate))
			support_rank = _normalize_support_rank(bond)
		# Original scale: strangers/0 -> +5/+1; C/1 -> +10/+2; B/2 -> +15/+3; A/3 -> +20/+5
		if support_rank <= 0:
			bonus["hit"] += 5
			bonus["def"] += 1
		elif support_rank == 1:
			bonus["hit"] += 10
			bonus["def"] += 2
		elif support_rank == 2:
			bonus["hit"] += 15
			bonus["def"] += 3
		elif support_rank >= 3:
			bonus["hit"] += 20
			bonus["def"] += 5
	return bonus

func _on_destructible_died(node: Node2D, killer: Node2D = null) -> void:
	var grid_pos = get_grid_pos(node)
	astar.set_point_solid(grid_pos, false)
	
	# --- SMART KILLER DETECTION ---
	var is_player_kill = false
	
	if killer != null:
		if killer.get_parent() == player_container:
			is_player_kill = true
	elif current_state == player_state and player_state.active_unit != null:
		# Fallback: If it died during player turn and killer is null, assume player
		is_player_kill = true
		killer = player_state.active_unit
	
	# If it's NOT a player kill, we need to find which enemy did it for the loot stealing!
	if not is_player_kill and killer == null:
		if current_state == enemy_state:
			# Grab the enemy currently moving/attacking in the AI state machine
			killer = enemy_state.active_unit 
	
	# --- LOGGING ---
	var obj_name = node.get("object_name") if node.get("object_name") != null else "a crate"
	if is_player_kill:
		add_combat_log(killer.unit_name + " smashed open " + obj_name + ".", "orange")
	else:
		var name_str = killer.unit_name if killer else "An enemy"
		add_combat_log(name_str + " destroyed " + obj_name + " and took the loot!", "tomato")
	
	# --- ROLL FOR SPOILS ---
	var dropped_gold = 0
	var max_gold = node.get("max_gold_drop") if node.get("max_gold_drop") != null else (node.data.max_gold_drop if node.get("data") else 0)
	var min_gold = node.get("min_gold_drop") if node.get("min_gold_drop") != null else (node.data.min_gold_drop if node.get("data") else 0)
	if max_gold > 0: dropped_gold = randi_range(min_gold, max_gold)

	var dropped_items = []
	
	# --- THE BULLETPROOF LOOT DETECTOR ---
	# Check for all possible ways an object might store its loot
	var node_loot = []
	if node.get("drop_loot") != null:      # <-- ADDED THIS FOR CRATES!
		node_loot = node.drop_loot
	elif node.get("loot_table") != null:   # For Chests
		node_loot = node.loot_table
	elif node.get("extra_loot") != null:   # For generic enemies
		node_loot = node.extra_loot
	elif node.get("data") != null and "extra_loot" in node.data:
		node_loot = node.data.extra_loot
		
	# Process the loot
	for loot in node_loot:
		if loot != null:
			var dropped_item = loot.get("item")
			if dropped_item != null:
				var chance = loot.get("drop_chance")
				if chance == null: chance = 100.0 # Default to 100%
				
				if randf() * 100.0 <= chance:
					dropped_items.append(CampaignManager.duplicate_item(dropped_item))

	# --- DISTRIBUTE THE SPOILS ---
	if is_player_kill:
		# Player gets everything immediately
		if dropped_gold > 0:
			player_gold += dropped_gold
			
			# THE FIX: Replace the old text with the new flying text!
			animate_flying_gold(node.global_position, dropped_gold)
			
		if dropped_items.size() > 0:
			pending_loot.clear()
			pending_loot.append_array(dropped_items)
			loot_recipient = killer
			show_loot_window()
	else:
		# ENEMY STEALS IT
		if killer != null:
			if "stolen_gold" in killer:
				killer.stolen_gold += dropped_gold
			if "stolen_loot" in killer:
				# Ensure killer has a stolen_loot array
				if not killer.has_meta("stolen_loot"): killer.set_meta("stolen_loot", [])
				killer.stolen_loot.append_array(dropped_items)
			
			# Visual feedback that the enemy is now a "Loot Carrier"
			spawn_loot_text("STOLEN!", Color.TOMATO, killer.global_position + Vector2(32, -32))
					
	rebuild_grid()
	update_fog_of_war()
	update_objective_ui()

	if map_objective == Objective.ROUT_ENEMY:
		if _count_alive_enemies() == 0 and _count_active_enemy_spawners(node) == 0:
			add_combat_log("MISSION ACCOMPLISHED: All enemies routed.", "lime")
			_trigger_victory()				
						
#=========== Chest Logic ================

func _on_chest_opened(chest: Node2D, opener: Node2D) -> void:
	var can_open = false
	
	# 1. Check if the opener is a Thief
	if opener.get("ai_behavior") == 1: # AIBehavior.THIEF
		can_open = true
	else:
		# 2. Check the opener's PERSONAL pockets first!
		if "inventory" in opener:
			for item in opener.inventory:
				if item is ChestKeyData:
					opener.inventory.erase(item)
					can_open = true
					add_combat_log(opener.unit_name + " used a Chest Key.", "white")
					break
					
		# 3. Quality of Life: Check the Convoy if they didn't have one in their pockets
		if not can_open:
			for item in player_inventory:
				if item is ChestKeyData:
					player_inventory.erase(item)
					can_open = true
					add_combat_log(opener.unit_name + " used a Chest Key from the Convoy.", "gray")
					break
				
	if can_open:
		chest.play_open_effect() # Trigger your chest animation
		
		# --- THE ENEMY THIEF FIX ---
		if opener.get_parent() == enemy_container:
			add_combat_log(opener.unit_name + " picked the lock and stole the contents!", "tomato")
			spawn_loot_text("STOLEN!", Color.TOMATO, opener.global_position + Vector2(32, -32))
			
			var stolen = []
			for loot in chest.loot_table:
				if loot != null and loot.get("item") != null:
					var chance = loot.get("drop_chance") if loot.get("drop_chance") != null else 100.0
					if randf() * 100.0 <= chance:
						stolen.append(CampaignManager.duplicate_item(loot.item))
			
			# Save the loot inside the Thief's memory so they drop it if you kill them!
			if not opener.has_meta("stolen_loot"): 
				opener.set_meta("stolen_loot", [])
			opener.stolen_loot.append_array(stolen)
			
		# --- THE PLAYER OPENS IT ---
		else:
			add_combat_log(opener.unit_name + " opened the chest!", "cyan")
			_process_loot(chest.loot_table)
	else:
		add_combat_log("The chest is locked. Need a Key or a Thief.", "gray")
				
func _process_loot(loot_list: Array[Resource]) -> void:
	pending_loot.clear()
	
	for loot in loot_list:
		if loot != null:
			var dropped_item = loot.get("item")
			
			if dropped_item != null:
				var chance = loot.get("drop_chance")
				if chance == null: chance = 100.0
					
				if randf() * 100.0 <= chance:
					# THE FIX: Safe duplication
					pending_loot.append(CampaignManager.duplicate_item(dropped_item))
	
	if not pending_loot.is_empty():
		for item in pending_loot:
			var item_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
			if item_name == null: 
				item_name = "Mysterious Item"
			add_combat_log("Found " + item_name + " in the chest!", "cyan")
			
		show_loot_window()

func _on_continue_button_pressed() -> void:
	get_tree().paused = false
	
	# --- NEW: ARENA VICTORY LOGIC ---
	if is_arena_match:
		ArenaManager.last_match_result = "VICTORY" # Save the win!
		ArenaManager.current_opponent_data = {} 
		get_tree().change_scene_to_file("res://Scenes/CityMenu.tscn")
		return
	
	# --- 1. FIX THE EXPLOIT: VAPORIZE SUMMONS ---
	for u in player_container.get_children():
		if u.has_meta("is_temporary_summon"):
			player_container.remove_child(u)
			u.queue_free()
			
	# --- 2. SELECTIVELY RECRUIT SURVIVING ALLIES ---
	if ally_container:
		var surviving_allies = ally_container.get_children()
		for ally in surviving_allies:
			if is_instance_valid(ally) and not ally.is_queued_for_deletion() and ally.current_hp > 0:
				if ally.get("data") != null and ally.data.get("is_recruitable") == true and not ally.has_meta("is_temporary_summon"):
					ally_container.remove_child(ally)
					player_container.add_child(ally)
					add_combat_log(ally.unit_name + " joined the party!", "lime")
	
	# --- 3. SAVE THE DATA SAFELY ---
	CampaignManager.save_party(self)
	
	# --- 4. EXECUTE TRANSITION (Let CampaignManager handle the routing!) ---
	CampaignManager.load_next_level()

func _is_dragon_deployable_in_battle(dragon: Dictionary) -> bool:
	if not (dragon is Dictionary):
		return false

	# Adult only
	return int(dragon.get("stage", 0)) >= 3


func _make_dragon_battle_entry(dragon: Dictionary) -> Dictionary:
	var stage: int = int(dragon.get("stage", 3))
	var element: String = str(dragon.get("element", "Fire"))
	var dragon_name: String = str(dragon.get("name", "Dragon"))
	var dragon_uid: String = str(dragon.get("uid", ""))

	var fang := WeaponData.new()
	fang.weapon_name = element + " Dragon Fang"
	fang.might = int(dragon.get("weapon_might", 8 + stage))
	fang.hit_bonus = int(dragon.get("weapon_hit_bonus", 10))
	fang.min_range = int(dragon.get("min_range", 1))
	fang.max_range = int(dragon.get("max_range", 1))

	var max_hp: int = int(dragon.get("max_hp", 30 + (stage * 4)))
	var current_hp: int = int(dragon.get("current_hp", max_hp))

	return {
		"unit_name": dragon_name,
		"unit_class": element + " Dragon",
		"level": int(dragon.get("level", 1)),
		"experience": int(dragon.get("experience", 0)),
		"max_hp": max_hp,
		"current_hp": current_hp,
		"strength": int(dragon.get("strength", 10 + stage)),
		"magic": int(dragon.get("magic", 8 + stage)),
		"defense": int(dragon.get("defense", 7 + stage)),
		"resistance": int(dragon.get("resistance", 6 + stage)),
		"speed": int(dragon.get("speed", 7 + stage)),
		"agility": int(dragon.get("agility", 6 + stage)),
		"move_range": int(dragon.get("move_range", 5)),
		"move_type": int(dragon.get("move_type", 2)), # 2 = flying
		"equipped_weapon": fang,
		"inventory": [fang],
		"ability": str(dragon.get("ability", "")),
		"skill_points": 0,
		"unlocked_skills": [],
		"unlocked_abilities": [],
		"is_dragon": true,
		"dragon_uid": dragon_uid,
		"element": element,
		"stage": stage
	}


func _build_deployment_roster() -> Array:
	# Use the new API to exclude base defenders!
	var roster: Array = CampaignManager.get_available_roster()

	for dragon in DragonManager.player_dragons:
		if _is_dragon_deployable_in_battle(dragon):
			roster.append(_make_dragon_battle_entry(dragon))

	return roster
	
func load_campaign_data() -> void:
	# 1. Load global resources
	player_gold = CampaignManager.global_gold
	player_inventory = CampaignManager.global_inventory.duplicate()
	update_gold_display()

	var roster = _build_deployment_roster()
	
	# ==========================================
	# --- BASE DEFENSE SPAWN LOGIC ---
	# ==========================================
	if CampaignManager.is_base_defense_active:
		# Empty the standard roster and ONLY load the garrisoned units
		roster.clear()
		roster = CampaignManager.get_garrisoned_units()
		
		if roster.is_empty():
			print("WARNING: Base Defense started, but no garrison units were found!")
			
	# --- ARENA FIX: OVERRIDE THE ROSTER WITH THE 3 CHOSEN UNITS ---
	if ArenaManager.current_opponent_data.size() > 0:
		roster = ArenaManager.local_arena_team
		
	if roster.is_empty():
		return
	
	# --- FIX: FIND DEPLOYMENT SLOTS VIA MARKERS ---
	var deployment_slots = []
	var zones_container = get_node_or_null("DeploymentZones")
	if zones_container:
		for marker in zones_container.get_children():
			var grid_x = int(marker.global_position.x / CELL_SIZE.x)
			var grid_y = int(marker.global_position.y / CELL_SIZE.y)
			var pos = Vector2i(grid_x, grid_y)
			
			if not deployment_slots.has(pos):
				deployment_slots.append(pos)
	
	if deployment_slots.is_empty():
		print("WARNING: No Marker2Ds found inside the 'DeploymentZones' node!")
		
	var max_to_deploy = min(6, deployment_slots.size())
	var _load_count = min(roster.size(), max_to_deploy)

	# --- CLEAR DUMMY UNITS ---
	# Delete any units manually placed in the editor so we have a clean slate
	for child in player_container.get_children():
		child.queue_free()

# --- DYNAMIC SPAWNING ---
	if player_unit_scene == null:
		print("ERROR: player_unit_scene is not assigned in the Inspector!")
		return

	# Notice we now loop through the ENTIRE roster size, not load_count!
	for i in range(roster.size()):
		var saved = roster[i]
		
		# 1. Instantiate a brand new physical unit node
		var new_unit = player_unit_scene.instantiate()
		
		# 2. PASS CRITICAL DATA BEFORE ADDING TO TREE
		# For the Avatar, we need to flag them!
		if saved.get("unit_name") == CampaignManager.custom_avatar.get("name"):
			new_unit.set("is_custom_avatar", true)
		else:
			new_unit.set("is_custom_avatar", false)

		if saved.get("data") is Resource:
			var original_path = saved["data"].resource_path
			new_unit.data = saved["data"].duplicate()
			if original_path != "":
				# Use metadata instead of forcibly overwriting the hard drive path!
				new_unit.data.set_meta("original_path", original_path)

		# 3. ADD IT TO THE TREE 
		player_container.add_child(new_unit)
		
		new_unit.died.connect(_on_unit_died)
		new_unit.leveled_up.connect(_on_unit_leveled_up)
		
		# --- NEW: DEPLOY OR BENCH ---
		if i < max_to_deploy and i < deployment_slots.size():
			# Deploy them onto a green tile!
			var slot_pos = deployment_slots[i]
			new_unit.position = Vector2(slot_pos.x * CELL_SIZE.x, slot_pos.y * CELL_SIZE.y)
			new_unit.visible = true
			new_unit.process_mode = Node.PROCESS_MODE_INHERIT
		else:
			# Bench them! Hide them off-screen.
			new_unit.position = Vector2(-1000, -1000)
			new_unit.visible = false
			new_unit.process_mode = Node.PROCESS_MODE_DISABLED
		
		# 4. OVERRIDE STATS WITH SAVED PROGRESS
		new_unit.unit_name = saved.get("unit_name", new_unit.unit_name)
		new_unit.unit_class_name = saved.get("unit_class", saved.get("class_name", new_unit.unit_class_name))
		new_unit.unit_tags = saved.get("unit_tags", [])
		new_unit.level = saved.get("level", 1)
		new_unit.experience = saved.get("experience", 0)
		new_unit.max_hp = saved.get("max_hp", 10)
		new_unit.current_hp = saved.get("current_hp", 10)
		new_unit.strength = saved.get("strength", 0)
		new_unit.magic = saved.get("magic", 0)
		new_unit.defense = saved.get("defense", 0)
		new_unit.resistance = saved.get("resistance", 0)
		new_unit.speed = saved.get("speed", 0)
		new_unit.agility = saved.get("agility", 0)
		
		if saved.has("move_type"): new_unit.set("move_type", saved["move_type"])
		if saved.has("move_range"): new_unit.move_range = saved["move_range"]
		if saved.has("class_data") and saved["class_data"] != null:
			new_unit.active_class_data = saved["class_data"]
		
		if saved.has("ability"): new_unit.ability = saved["ability"]
		if saved.has("traits") and new_unit.get("traits") != null:
			new_unit.traits = saved["traits"].duplicate()
		if saved.has("rookie_legacies") and new_unit.get("rookie_legacies") != null:
			new_unit.rookie_legacies = saved["rookie_legacies"].duplicate()
		if saved.has("base_class_legacies") and new_unit.get("base_class_legacies") != null:
			new_unit.base_class_legacies = saved["base_class_legacies"].duplicate()
		if saved.has("promoted_class_legacies") and new_unit.get("promoted_class_legacies") != null:
			new_unit.promoted_class_legacies = saved["promoted_class_legacies"].duplicate()

		# --- THE FIX: TRANSFER SKILL DATA TO THE NODE ---
		if saved.has("skill_points"): 
			new_unit.skill_points = saved["skill_points"]
		if saved.has("unlocked_skills"): 
			new_unit.unlocked_skills = saved["unlocked_skills"].duplicate()
		
		# --- INVENTORY ---
		if saved.has("inventory"):
			new_unit.inventory.clear()
			new_unit.inventory.append_array(saved["inventory"])
			
		if saved.has("equipped_weapon"):
			new_unit.equipped_weapon = saved["equipped_weapon"]
		
		# --- RESTORE PERMANENT PROMOTION AURA ---
		if saved.has("is_promoted"):
			new_unit.set("is_promoted", saved["is_promoted"])
			if new_unit.get("is_promoted") == true and new_unit.has_method("apply_promotion_aura"):
				new_unit.apply_promotion_aura()
				
		# --- APPLY VISUALS ---
		var s_tex = saved.get("battle_sprite")
		var p_tex = saved.get("portrait")
		
		# ==========================================
		# --- PLAYER DRAGON ARENA FIX ---
		# ==========================================
		if saved.has("element") or saved.get("is_dragon") == true:
			new_unit.unit_name = saved.get("unit_name", saved.get("name", "Dragon"))
			new_unit.unit_class_name = saved.get("unit_class", saved.get("element", "Fire") + " Dragon")
			new_unit.set_meta("is_dragon", true)
			new_unit.set_meta("dragon_uid", str(saved.get("dragon_uid", saved.get("uid", ""))))

			if new_unit.data == null:
				new_unit.data = UnitData.new()

			if new_unit.equipped_weapon == null:
				var fang = WeaponData.new()
				fang.weapon_name = "Dragon Fang"
				fang.might = 6
				fang.min_range = 1
				fang.max_range = 1
				new_unit.equipped_weapon = fang
				new_unit.inventory = [fang]

			var elem = str(saved.get("element", "Fire")).to_lower()
			var d_path = "res://Assets/Sprites/" + elem + "_dragon_sprite.png"
			if ResourceLoader.exists(d_path):
				s_tex = load(d_path)

			var dp_path = "res://Assets/Portraits/" + elem + "_dragon_portrait.png"
			if ResourceLoader.exists(dp_path):
				p_tex = load(dp_path)
		# ==========================================
		
		var sprite_node = new_unit.get_node_or_null("Sprite")
		if sprite_node == null: sprite_node = new_unit.get_node_or_null("Sprite2D")
		if s_tex and sprite_node: sprite_node.texture = s_tex
		if p_tex and new_unit.data: new_unit.data.portrait = p_tex
				
		# --- REFRESH HUD ---
		if new_unit.get("health_bar") != null:
			new_unit.health_bar.max_value = new_unit.max_hp
			new_unit.health_bar.value = new_unit.current_hp
									
func get_terrain_data(grid_pos: Vector2i) -> Dictionary:
	# Default stats
	var terrain = {"name": "Plain", "def": 0, "avo": 0, "move_cost": 1.0}
	
	var t_map = get_node_or_null("TerrainMap")
	if t_map != null:
		# ==========================================
		# TRANSLATE 64x64 GRID TO 32x32 MAP
		# ==========================================
		# 1. Find the exact center physical pixel of the 64x64 cell
		var pixel_center = Vector2(grid_pos.x * CELL_SIZE.x + (CELL_SIZE.x / 2.0), grid_pos.y * CELL_SIZE.y + (CELL_SIZE.y / 2.0))
		# 2. Ask the TileMap what its specific 32x32 coordinate is for that pixel
		var tilemap_pos = t_map.local_to_map(pixel_center)

		# --- GODOT 4.3 TILEMAPLAYER SUPPORT ---
		if t_map.has_method("get_cell_source_id") and not t_map is TileMap:
			# Notice we now use 'tilemap_pos' instead of 'grid_pos'
			var source_id = t_map.get_cell_source_id(tilemap_pos)
			if source_id != -1: 
				var cell_data = t_map.get_cell_tile_data(tilemap_pos)
				if cell_data != null:
					var t_name = cell_data.get_custom_data("terrain_name")
					if t_name != null and t_name != "": terrain["name"] = t_name
					
					var t_def = cell_data.get_custom_data("def_bonus")
					if t_def != null: terrain["def"] = int(t_def)
						
					var t_avo = cell_data.get_custom_data("avo_bonus")
					if t_avo != null: terrain["avo"] = int(t_avo)
						
					var t_cost = cell_data.get_custom_data("move_cost")
					if t_cost != null and float(t_cost) >= 1.0:
						terrain["move_cost"] = float(t_cost)

		# --- GODOT 4.2 TILEMAP SUPPORT ---
		elif t_map is TileMap:
			for layer in range(t_map.get_layers_count() - 1, -1, -1):
				var source_id = t_map.get_cell_source_id(layer, tilemap_pos)
				
				if source_id != -1:
					var cell_data = t_map.get_cell_tile_data(layer, tilemap_pos)
					if cell_data != null:
						var t_name = cell_data.get_custom_data("terrain_name")
						if t_name != null and t_name != "": 
							terrain["name"] = t_name
						
						var t_def = cell_data.get_custom_data("def_bonus")
						if t_def != null: terrain["def"] = int(t_def)
						
						var t_avo = cell_data.get_custom_data("avo_bonus")
						if t_avo != null: terrain["avo"] = int(t_avo)
						
						var t_cost = cell_data.get_custom_data("move_cost")
						if t_cost != null and float(t_cost) > 0.0:
							terrain["move_cost"] = float(t_cost)
						
						break 
						
	# --- CHECK FOR PORTABLE FORTRESSES ---
	var fort_container = get_node_or_null("Fortresses")
	if fort_container:
		for fort in fort_container.get_children():
			# THE FIX: Compare to 'grid_pos', not 'tilemap_pos'!
			if get_grid_pos(fort) == grid_pos and not fort.is_queued_for_deletion():
				terrain["name"] = "Portable Fort"
				terrain["def"] += 2  # Grants +2 Defense
				terrain["avo"] += 15 # Grants +15% Evasion
				break # Found one, stop looking
				
	return terrain
	
func _set_path_pulse(active: bool) -> void:
	if _path_pulse_active == active:
		return
	_path_pulse_active = active

	if _path_pulse_tween and _path_pulse_tween.is_running():
		_path_pulse_tween.kill()

	if not path_line:
		return

	if not active:
		# reset propre
		var c: Color = path_line.modulate
		c.a = 1.0
		path_line.modulate = c
		return

	# démarre au min
	var path_mod: Color = path_line.modulate
	path_mod.a = PATH_ALPHA_MIN
	path_line.modulate = path_mod

	_path_pulse_tween = create_tween()
	_path_pulse_tween.set_loops() # loop infini

	_path_pulse_tween.tween_property(path_line, "modulate:a", PATH_ALPHA_MAX, PATH_PULSE_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_path_pulse_tween.tween_property(path_line, "modulate:a", PATH_ALPHA_MIN, PATH_PULSE_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func play_ui_sfx(kind: int) -> void:
	var now := Time.get_ticks_msec()
	if now < _ui_sfx_block_until_msec:
		return
	_ui_sfx_block_until_msec = now + UI_SFX_COOLDOWN_MS

	var p := 1.0
	var player: AudioStreamPlayer = select_sound

	match kind:
		UISfx.MOVE_OK:
			player = select_sound
			p = randf_range(0.95, 1.02) # “confirm” doux
		UISfx.TARGET_OK:
			player = select_sound
			p = randf_range(1.08, 1.16) # “attaque” plus aigu
		UISfx.INVALID:
			# buzzer soft, sinon fallback sur miss_sound
			player = invalid_sound if (invalid_sound and invalid_sound.stream) else miss_sound
			p = randf_range(0.82, 0.92)

	if player == null or player.stream == null:
		return

	player.pitch_scale = p
	player.play()

func _clamp_camera_position() -> void:
	if main_camera == null:
		return

	# How many pixels past the map edge the camera is allowed to go
	var extra_scroll_margin := 400

	var map_limit_x := GRID_SIZE.x * CELL_SIZE.x
	var map_limit_y := GRID_SIZE.y * CELL_SIZE.y

	main_camera.position.x = clamp(main_camera.position.x, -extra_scroll_margin, map_limit_x + extra_scroll_margin)
	main_camera.position.y = clamp(main_camera.position.y, -extra_scroll_margin, map_limit_y + extra_scroll_margin)


func _apply_camera_zoom(direction: int) -> void:
	if main_camera == null:
		return

	# Optional: block zoom during impact freeze / heavy cinematic moments
	if _hit_stop_active:
		return

	var old_target: float = _camera_zoom_target
	_camera_zoom_target = clampf(
		_camera_zoom_target + zoom_step * float(direction),
		min_zoom,
		max_zoom
	)

	if is_equal_approx(old_target, _camera_zoom_target):
		return

	var before_mouse_world: Vector2 = Vector2.ZERO
	if zoom_to_cursor:
		before_mouse_world = get_global_mouse_position()

	if _camera_zoom_tween != null and _camera_zoom_tween.is_valid():
		_camera_zoom_tween.kill()

	_camera_zoom_tween = create_tween()
	_camera_zoom_tween.set_parallel(true)
	_camera_zoom_tween.set_trans(Tween.TRANS_SINE)
	_camera_zoom_tween.set_ease(Tween.EASE_OUT)

	_camera_zoom_tween.tween_property(
		main_camera,
		"zoom",
		Vector2(_camera_zoom_target, _camera_zoom_target),
		0.12
	)

	if zoom_to_cursor:
		await get_tree().process_frame
		var after_mouse_world: Vector2 = get_global_mouse_position()
		main_camera.global_position += (before_mouse_world - after_mouse_world)
		_clamp_camera_position()

	_camera_zoom_tween.finished.connect(func():
		_clamp_camera_position()
	)
	
# --- ABILITY 1: THE UNIVERSAL PARRY (Timing QTE) ---
func _run_parry_minigame(defender: Node2D) -> bool:
	if defender == null or not is_instance_valid(defender):
		return false

	# 1) TELEGRAPH
	var clang = get_node_or_null("ClangSound")
	if clang != null and clang.stream != null:
		clang.pitch_scale = randf_range(0.85, 0.95)
		clang.play()

	var f_text = FloatingTextScene.instantiate()
	f_text.text_to_show = "PARRY!"
	f_text.text_color = Color(1.0, 0.8, 0.2)
	add_child(f_text)
	f_text.global_position = defender.global_position + Vector2(32, -48)

	screen_shake(6.0, 0.2)
	await get_tree().create_timer(0.45).timeout

	# --- CINEMATIC LOCK (Freeze the game) ---
	var prev_paused = get_tree().paused
	get_tree().paused = true

	# 2) UI POP (cinematic letterbox + flash + pop-in)
	var qte_layer = CanvasLayer.new()
	qte_layer.layer = 100
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS # Keeps running while paused
	add_child(qte_layer)

	var vp_size = get_viewport_rect().size

	var screen_dimmer = ColorRect.new()
	screen_dimmer.size = vp_size
	screen_dimmer.color = Color(0, 0, 0, 0.35)
	qte_layer.add_child(screen_dimmer)

	# Letterbox bars
	var letterbox_h = 56.0
	var top_bar = ColorRect.new()
	top_bar.color = Color(0, 0, 0, 0.85)
	top_bar.size = Vector2(vp_size.x, 0.0)
	qte_layer.add_child(top_bar)

	var bottom_bar = ColorRect.new()
	bottom_bar.color = Color(0, 0, 0, 0.85)
	bottom_bar.position = Vector2(0.0, vp_size.y)
	bottom_bar.size = Vector2(vp_size.x, 0.0)
	qte_layer.add_child(bottom_bar)

	# Use qte_layer.create_tween() so the animations play while the game is paused
	var lb_in = qte_layer.create_tween().set_parallel(true)
	lb_in.tween_property(top_bar, "size:y", letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lb_in.tween_property(bottom_bar, "size:y", letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lb_in.tween_property(bottom_bar, "position:y", vp_size.y - letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Screen flash
	var flash_rect = ColorRect.new()
	flash_rect.size = vp_size
	flash_rect.color = Color.WHITE
	flash_rect.modulate = Color(1, 1, 1, 0)
	qte_layer.add_child(flash_rect)

	var intro_flash = qte_layer.create_tween()
	intro_flash.tween_property(flash_rect, "modulate:a", 0.18, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro_flash.tween_property(flash_rect, "modulate:a", 0.00, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Bar
	var bar_bg = ColorRect.new()
	bar_bg.size = Vector2(420, 34)
	bar_bg.pivot_offset = bar_bg.size / 2.0
	bar_bg.position = (vp_size - bar_bg.size) / 2.0
	bar_bg.position.y -= 100.0
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.95)
	bar_bg.scale = Vector2(0.86, 0.86)
	bar_bg.modulate.a = 0.0
	qte_layer.add_child(bar_bg)

	var bar_pop = qte_layer.create_tween().set_parallel(true)
	bar_pop.tween_property(bar_bg, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bar_pop.tween_property(bar_bg, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Target zone
	var target_zone = ColorRect.new()
	target_zone.size = Vector2(92, 34)
	target_zone.color = Color(0.2, 0.8, 0.2, 0.85)
	var rand_max = bar_bg.size.x - target_zone.size.x
	target_zone.position = Vector2(randf_range(100.0, rand_max), 0.0)
	bar_bg.add_child(target_zone)

	var perfect_zone = ColorRect.new()
	perfect_zone.size = Vector2(26, 34)
	perfect_zone.position = Vector2((target_zone.size.x - perfect_zone.size.x) / 2.0, 0.0)
	perfect_zone.color = Color(1.0, 0.85, 0.2, 0.9)
	target_zone.add_child(perfect_zone)

	# Pulse the target zone
	var pulse = qte_layer.create_tween().set_loops()
	pulse.tween_property(target_zone, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(target_zone, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var qte_cursor = ColorRect.new()
	qte_cursor.size = Vector2(10, 56)
	qte_cursor.position = Vector2(0, -11)
	qte_cursor.color = Color.WHITE
	bar_bg.add_child(qte_cursor)

	var help_text = Label.new()
	help_text.text = "PRESS SPACE"
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.add_theme_font_size_override("font_size", 26)
	bar_bg.add_child(help_text)
	help_text.position = Vector2(0, -52)
	help_text.size.x = bar_bg.size.x

	# 3) TIMING LOOP (Uses Time.get_ticks_msec so it works while paused)
	var total_ms = 650
	var start_ms = Time.get_ticks_msec()
	var success = false
	var pressed = false
	var perfect = false

	while true:
		await get_tree().process_frame
		var elapsed_ms = Time.get_ticks_msec() - start_ms

		if elapsed_ms >= total_ms:
			break

		var progress = float(elapsed_ms) / float(total_ms)
		qte_cursor.position.x = progress * bar_bg.size.x

		if Input.is_action_just_pressed("ui_accept"):
			pressed = true

			var cursor_center = qte_cursor.position.x + (qte_cursor.size.x / 2.0)
			var tz_start = target_zone.position.x
			var tz_end = tz_start + target_zone.size.x
			var p_start = tz_start + perfect_zone.position.x
			var p_end = p_start + perfect_zone.size.x

			if cursor_center >= tz_start and cursor_center <= tz_end:
				success = true
				perfect = (cursor_center >= p_start and cursor_center <= p_end)

				qte_cursor.color = Color(1.0, 0.85, 0.2)
				target_zone.color = Color(1.0, 1.0, 1.0, 0.85)

				screen_shake(24.0 if perfect else 14.0, 0.30 if perfect else 0.25)

				if clang != null and clang.stream != null:
					clang.pitch_scale = randf_range(1.25, 1.45) if perfect else randf_range(1.15, 1.30)
					clang.play()

				flash_rect.modulate.a = 0.0
				var win_flash = qte_layer.create_tween()
				win_flash.tween_property(flash_rect, "modulate:a", 0.28 if perfect else 0.20, 0.05)
				win_flash.tween_property(flash_rect, "modulate:a", 0.00, 0.15)
				
				help_text.text = "PERFECT!" if perfect else "NICE!"
				help_text.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if perfect else Color(0.2, 1.0, 0.2))

			else:
				success = false
				qte_cursor.color = Color(0.9, 0.25, 0.25)
				screen_shake(10.0, 0.18)

				if miss_sound.stream != null:
					miss_sound.play()

				flash_rect.modulate.a = 0.0
				var fail_flash = qte_layer.create_tween()
				fail_flash.tween_property(flash_rect, "modulate:a", 0.10, 0.03)
				fail_flash.tween_property(flash_rect, "modulate:a", 0.00, 0.10)
				
				help_text.text = "MISS!"
				help_text.add_theme_color_override("font_color", Color.RED)

			break

	if not pressed:
		success = false
		if miss_sound.stream != null:
			miss_sound.play()
		help_text.text = "TOO SLOW!"
		help_text.add_theme_color_override("font_color", Color.RED)

	await get_tree().create_timer(0.45, true, false, true).timeout # Pause-safe timer

	# Letterbox out
	var lb_out = qte_layer.create_tween().set_parallel(true)
	lb_out.tween_property(top_bar, "size:y", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lb_out.tween_property(bottom_bar, "size:y", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lb_out.tween_property(bottom_bar, "position:y", vp_size.y, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await lb_out.finished

	qte_layer.queue_free()
	get_tree().paused = prev_paused
	return success

# --- ABILITY 2: SHIELD CLASH (Mashing QTE) ---
# Returns 0 (Fail), 1 (Block), 2 (Perfect Counter)
func _run_shield_clash_minigame(defender: Node2D, attacker: Node2D) -> int:
	# 1. CALCULATE WEIGHT ADVANTAGE
	# MoveType Enum: INFANTRY=0, ARMORED=1, FLYING=2, CAVALRY=3
	var def_type = defender.get("move_type") if defender.get("move_type") != null else 0
	var atk_type = attacker.get("move_type") if attacker.get("move_type") != null else 0
	
	# Convert MoveTypes into "Weight/Mass"
	var get_weight = func(m_type: int) -> int:
		if m_type == 1: return 3   # ARMORED (Heaviest)
		if m_type == 3: return 2   # CAVALRY (Heavy)
		if m_type == 0: return 1   # INFANTRY (Standard)
		if m_type == 2: return 0   # FLYING (Lightest)
		return 1
		
	var weight_diff = get_weight.call(def_type) - get_weight.call(atk_type)
	
	# Adjust the difficulty math based on the weight difference!
	var mash_power = 12.0 + (weight_diff * 1.5)  # Heavy defenders gain more per tap
	var enemy_pushback = 35.0 - (weight_diff * 5.0) # Heavy attackers push the bar down faster

	# 2. THE TELEGRAPH (Warning Phase)
	screen_shake(10.0, 0.3)
	
	if has_node("ShieldBashSound") and get_node("ShieldBashSound").stream != null:
		get_node("ShieldBashSound").pitch_scale = randf_range(0.85, 0.95)
		get_node("ShieldBashSound").play()
		
	var f_text = FloatingTextScene.instantiate()
	f_text.text_to_show = "SHIELD CLASH!"
	f_text.text_color = Color(0.8, 0.9, 1.0)
	add_child(f_text)
	f_text.global_position = defender.global_position + Vector2(32, -48)
	
	await get_tree().create_timer(1.2).timeout 
	
	# 3. THE UI POP
	var qte_layer = CanvasLayer.new()
	qte_layer.layer = 100 
	add_child(qte_layer)
	
	var screen_dimmer = ColorRect.new()
	screen_dimmer.size = get_viewport_rect().size
	screen_dimmer.color = Color(0, 0, 0, 0.3)
	qte_layer.add_child(screen_dimmer)
	
	var bar = ProgressBar.new()
	bar.max_value = 100
	bar.value = 50.0 
	bar.custom_minimum_size = Vector2(400, 40)
	bar.show_percentage = false
	bar.position = (get_viewport_rect().size - bar.size) / 2.0
	bar.position.y -= 100 
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.8, 0.1, 0.1, 0.9) 
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.5, 1.0, 1.0) 
	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)
	
	qte_layer.add_child(bar)
	
	var help_text = Label.new()
	help_text.text = "MASH SPACE!"
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.add_theme_font_size_override("font_size", 32)
	help_text.add_theme_color_override("font_color", Color(1.0, 0.4, 0.0))
	qte_layer.add_child(help_text)
	help_text.position = bar.position + Vector2(0, -50)
	help_text.size.x = bar.size.x
	
	# --- NEW: SHOW WEIGHT ADVANTAGE UI ---
	var adv_text = Label.new()
	if weight_diff > 0:
		adv_text.text = "WEIGHT ADVANTAGE"
		adv_text.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2)) # Green
	elif weight_diff < 0:
		adv_text.text = "WEIGHT DISADVANTAGE!"
		adv_text.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2)) # Red
	else:
		adv_text.text = "EVEN MATCH"
		adv_text.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7)) # Gray
		
	adv_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	adv_text.add_theme_font_size_override("font_size", 18)
	qte_layer.add_child(adv_text)
	adv_text.position = bar.position + Vector2(0, 45)
	adv_text.size.x = bar.size.x
	
	# 4. THE TUG-OF-WAR LOOP
	var time_left = 3.0 
	var final_result = 0 
	
	while time_left > 0:
		await get_tree().process_frame
		var delta = get_process_delta_time()
		time_left -= delta
		
		# The enemy constantly pushes back (using the weight math!)
		bar.value -= enemy_pushback * delta 
		
		if Input.is_action_just_pressed("ui_accept"): 
			bar.value += mash_power # Player pushes forward (using weight math!)
			
			bar.modulate = Color(2.0, 2.0, 2.0)
			var flash = create_tween()
			flash.tween_property(bar, "modulate", Color.WHITE, 0.05)
			
		if bar.value >= 100.0:
			if time_left >= 1.5:
				final_result = 2 
			else:
				final_result = 1
			break
			
		if bar.value <= 0.0:
			final_result = 0
			break
			
	# 5. RESOLUTION FEEDBACK
	if final_result > 0:
		var is_perfect = (final_result == 2)
		help_text.text = "PERFECT COUNTER!" if is_perfect else "GUARD HELD!"
		help_text.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if is_perfect else Color(0.2, 1.0, 0.2))
		adv_text.text = "" # Clear the advantage text on win
		
		screen_shake(25.0 if is_perfect else 15.0, 0.35)
		
		if has_node("ShieldBashSound") and get_node("ShieldBashSound").stream != null:
			get_node("ShieldBashSound").pitch_scale = randf_range(1.1, 1.25) if is_perfect else randf_range(0.95, 1.05)
			get_node("ShieldBashSound").play()
	else:
		help_text.text = "GUARD BROKEN!"
		help_text.add_theme_color_override("font_color", Color.RED)
		adv_text.text = ""
		if miss_sound.stream != null:
			miss_sound.play()
			
	await get_tree().create_timer(0.4).timeout
	
	qte_layer.queue_free()
	return final_result
	
# --- ABILITY 3: FOCUSED STRIKE (Offensive Hold & Release QTE) ---
func _run_focused_strike_minigame(attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker):
		return 0

	# 1. THE TELEGRAPH
	screen_shake(5.0, 0.2)
	
	var clang = get_node_or_null("ClangSound")
	if clang != null and clang.stream != null:
		clang.pitch_scale = 0.5 # Deep wind-up sound
		clang.play()
		
	var f_text = FloatingTextScene.instantiate()
	f_text.text_to_show = "FOCUS STRIKE!"
	f_text.text_color = Color(1.0, 0.5, 0.0)
	add_child(f_text)
	f_text.global_position = attacker.global_position + Vector2(32, -48)
	
	await get_tree().create_timer(0.6).timeout
	
	# --- CINEMATIC LOCK ---
	var prev_paused = get_tree().paused
	get_tree().paused = true
	
	# 2. THE UI POP
	var qte_layer = CanvasLayer.new()
	qte_layer.layer = 100 
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS # Keeps UI running while game is paused
	add_child(qte_layer)
	
	var vp_size = get_viewport_rect().size
	
	var screen_dimmer = ColorRect.new()
	screen_dimmer.size = vp_size
	screen_dimmer.color = Color(0, 0, 0, 0.35)
	qte_layer.add_child(screen_dimmer)
	
	# Letterbox bars
	var letterbox_h = 56.0
	var top_bar = ColorRect.new()
	top_bar.color = Color(0, 0, 0, 0.85)
	top_bar.size = Vector2(vp_size.x, 0.0)
	qte_layer.add_child(top_bar)

	var bottom_bar = ColorRect.new()
	bottom_bar.color = Color(0, 0, 0, 0.85)
	bottom_bar.position = Vector2(0.0, vp_size.y)
	bottom_bar.size = Vector2(vp_size.x, 0.0)
	qte_layer.add_child(bottom_bar)

	var lb_in = qte_layer.create_tween().set_parallel(true)
	lb_in.tween_property(top_bar, "size:y", letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lb_in.tween_property(bottom_bar, "size:y", letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lb_in.tween_property(bottom_bar, "position:y", vp_size.y - letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var flash_rect = ColorRect.new()
	flash_rect.size = vp_size
	flash_rect.color = Color.WHITE
	flash_rect.modulate = Color(1, 1, 1, 0)
	qte_layer.add_child(flash_rect)

	# The Background Bar
	var bar_bg = ColorRect.new()
	bar_bg.size = Vector2(400, 30)
	bar_bg.pivot_offset = bar_bg.size / 2.0
	bar_bg.position = (vp_size - bar_bg.size) / 2.0
	bar_bg.position.y -= 100 
	bar_bg.color = Color(0.1, 0.1, 0.1, 0.9)
	bar_bg.scale = Vector2(0.8, 0.8)
	bar_bg.modulate.a = 0.0
	qte_layer.add_child(bar_bg)
	
	var bar_pop = qte_layer.create_tween().set_parallel(true)
	bar_pop.tween_property(bar_bg, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bar_pop.tween_property(bar_bg, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# The Target Zone
	var target_zone = ColorRect.new()
	target_zone.size = Vector2(50, 30) 
	target_zone.position = Vector2(300, 0) # Near the end
	target_zone.color = Color(0.2, 0.8, 0.2, 0.85)
	bar_bg.add_child(target_zone)
	
	# The Perfect Zone
	var perfect_zone = ColorRect.new()
	perfect_zone.size = Vector2(16, 30)
	perfect_zone.position = Vector2((target_zone.size.x - perfect_zone.size.x) / 2.0, 0.0)
	perfect_zone.color = Color(1.0, 0.85, 0.2, 0.9)
	target_zone.add_child(perfect_zone)
	
	var pulse = qte_layer.create_tween().set_loops()
	pulse.tween_property(target_zone, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(target_zone, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# The Charging Fill Bar
	var fill_bar = ColorRect.new()
	fill_bar.size = Vector2(0, 30)
	fill_bar.position = Vector2.ZERO
	fill_bar.color = Color(1.0, 0.6, 0.0)
	bar_bg.add_child(fill_bar)
	
	var help_text = Label.new()
	help_text.text = "HOLD SPACE... RELEASE IN GREEN!"
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.add_theme_font_size_override("font_size", 24)
	bar_bg.add_child(help_text)
	help_text.position = Vector2(0, -40)
	help_text.size.x = bar_bg.size.x
	
	# 3. THE CHARGE LOOP (Time Tick Based for pausing immunity)
	var final_result = 0 # 0 = fail, 1 = nice, 2 = perfect
	var is_charging = false
	var finished = false
	var time_waiting = 0.0
	
	var fill_time = 1.2 # Takes 1.2 seconds to fill
	var charge_start_ms = 0
	
	while not finished:
		await get_tree().process_frame
		
		# If they haven't started holding Spacebar yet
		if not is_charging:
			time_waiting += get_process_delta_time()
			if time_waiting > 2.0: 
				finished = true
				help_text.text = "TOO SLOW!"
				help_text.add_theme_color_override("font_color", Color.RED)
				break
				
			if Input.is_action_just_pressed("ui_accept"):
				is_charging = true
				charge_start_ms = Time.get_ticks_msec()
				
		# If they are holding it
		else:
			var elapsed = Time.get_ticks_msec() - charge_start_ms
			var progress = float(elapsed) / (fill_time * 1000.0)
			fill_bar.size.x = progress * bar_bg.size.x
			
			# Check Release
			if Input.is_action_just_released("ui_accept"):
				finished = true
				var tip = fill_bar.size.x
				var tz_start = target_zone.position.x
				var tz_end = tz_start + target_zone.size.x
				var p_start = tz_start + perfect_zone.position.x
				var p_end = p_start + perfect_zone.size.x
				
				if tip >= tz_start and tip <= tz_end:
					var perfect = (tip >= p_start and tip <= p_end)
					final_result = 2 if perfect else 1 # <--- THE KEY UPDATE
					
					fill_bar.color = Color(1.0, 0.85, 0.2)
					target_zone.color = Color(1.0, 1.0, 1.0, 0.85)
					
					screen_shake(24.0 if perfect else 14.0, 0.3 if perfect else 0.2)
					
					if clang != null and clang.stream != null:
						clang.pitch_scale = randf_range(1.25, 1.45) if perfect else randf_range(1.15, 1.30)
						clang.play()
						
					flash_rect.modulate.a = 0.0
					var win_flash = qte_layer.create_tween()
					win_flash.tween_property(flash_rect, "modulate:a", 0.28 if perfect else 0.20, 0.05)
					win_flash.tween_property(flash_rect, "modulate:a", 0.00, 0.15)
					
					help_text.text = "PERFECT STRIKE!" if perfect else "NICE!"
					help_text.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if perfect else Color(0.2, 1.0, 0.2))
				else:
					final_result = 0
					fill_bar.color = Color(0.9, 0.25, 0.25)
					screen_shake(10.0, 0.18)
					if miss_sound.stream != null: miss_sound.play()
					
					flash_rect.modulate.a = 0.0
					var fail_flash = qte_layer.create_tween()
					fail_flash.tween_property(flash_rect, "modulate:a", 0.10, 0.03)
					fail_flash.tween_property(flash_rect, "modulate:a", 0.00, 0.10)
					
					help_text.text = "MISSED!"
					help_text.add_theme_color_override("font_color", Color.RED)
				break
				
			# Check Overcharge
			if fill_bar.size.x >= bar_bg.size.x:
				fill_bar.size.x = bar_bg.size.x
				finished = true
				final_result = 0
				fill_bar.color = Color(0.9, 0.25, 0.25)
				screen_shake(10.0, 0.18)
				if miss_sound.stream != null: miss_sound.play()
				
				help_text.text = "OVERCHARGED!"
				help_text.add_theme_color_override("font_color", Color.RED)
				break
				
	# 4. RESOLUTION HOLD AND CLEANUP
	await get_tree().create_timer(0.45, true, false, true).timeout # Pause-safe timer
	
	var lb_out = qte_layer.create_tween().set_parallel(true)
	lb_out.tween_property(top_bar, "size:y", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lb_out.tween_property(bottom_bar, "size:y", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lb_out.tween_property(bottom_bar, "position:y", vp_size.y, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await lb_out.finished
	
	qte_layer.queue_free()
	get_tree().paused = prev_paused
	
	# Returns 0 (Fail), 1 (Nice), or 2 (Perfect!)
	return final_result

# --- ABILITY 4: BLOODTHIRSTER (Multi-Tap Combo QTE) ---
# Returns the number of successful hits (0 to 3)
func _run_bloodthirster_minigame(attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker):
		return 0

	# 1. THE TELEGRAPH
	screen_shake(8.0, 0.3)
	
	var clang = get_node_or_null("ClangSound")
	if clang != null and clang.stream != null:
		clang.pitch_scale = 0.6 # Deep, sinister thud
		clang.play()
		
	var f_text = FloatingTextScene.instantiate()
	f_text.text_to_show = "BLOODTHIRSTER!"
	f_text.text_color = Color(0.8, 0.1, 0.1) # Crimson Red
	add_child(f_text)
	f_text.global_position = attacker.global_position + Vector2(32, -48)
	
	await get_tree().create_timer(0.6).timeout
	
	# --- CINEMATIC LOCK ---
	var prev_paused = get_tree().paused
	get_tree().paused = true

	# 2. THE UI POP
	var qte_layer = CanvasLayer.new()
	qte_layer.layer = 100 
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(qte_layer)
	
	var vp_size = get_viewport_rect().size
	
	var screen_dimmer = ColorRect.new()
	screen_dimmer.size = vp_size
	screen_dimmer.color = Color(0.2, 0.0, 0.0, 0.4) # Dark red tint
	qte_layer.add_child(screen_dimmer)
	
	# Letterbox Bars
	var letterbox_h = 56.0
	var top_bar = ColorRect.new()
	top_bar.color = Color(0, 0, 0, 0.85)
	top_bar.size = Vector2(vp_size.x, 0.0)
	qte_layer.add_child(top_bar)

	var bottom_bar = ColorRect.new()
	bottom_bar.color = Color(0, 0, 0, 0.85)
	bottom_bar.position = Vector2(0.0, vp_size.y)
	bottom_bar.size = Vector2(vp_size.x, 0.0)
	qte_layer.add_child(bottom_bar)

	var lb_in = qte_layer.create_tween().set_parallel(true)
	lb_in.tween_property(top_bar, "size:y", letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lb_in.tween_property(bottom_bar, "size:y", letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lb_in.tween_property(bottom_bar, "position:y", vp_size.y - letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var flash_rect = ColorRect.new()
	flash_rect.size = vp_size
	flash_rect.color = Color(0.8, 0.1, 0.1) # Red flash
	flash_rect.modulate = Color(1, 1, 1, 0)
	qte_layer.add_child(flash_rect)

	# Main Bar
	var bar_bg = ColorRect.new()
	bar_bg.size = Vector2(420, 34)
	bar_bg.position = (vp_size - bar_bg.size) / 2.0
	bar_bg.position.y -= 100.0
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.95)
	bar_bg.scale = Vector2(0.9, 0.9)
	bar_bg.modulate.a = 0.0
	qte_layer.add_child(bar_bg)
	
	var bar_pop = qte_layer.create_tween().set_parallel(true)
	bar_pop.tween_property(bar_bg, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bar_pop.tween_property(bar_bg, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# The 3 Combo Target Zones
	var z_width = 30.0
	var targets = []
	var positions = [80.0, 200.0, 320.0] # Spread evenly across the bar
	
	for pos in positions:
		var tz = ColorRect.new()
		tz.size = Vector2(z_width, 34)
		tz.position = Vector2(pos, 0)
		tz.color = Color(0.4, 0.0, 0.0, 0.8) # Dull red until hit
		bar_bg.add_child(tz)
		targets.append(tz)
	
	var qte_cursor = ColorRect.new()
	qte_cursor.size = Vector2(8, 56)
	qte_cursor.position = Vector2(0, -11)
	qte_cursor.color = Color.WHITE
	bar_bg.add_child(qte_cursor)
	
	var help_text = Label.new()
	help_text.text = "TAP 3 TIMES!"
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.add_theme_font_size_override("font_size", 26)
	help_text.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
	help_text.position = Vector2(0, -52)
	help_text.size.x = bar_bg.size.x
	bar_bg.add_child(help_text)
	
	# 3. COMBO SWEEP LOOP
	var total_ms = 1400 # 1.4 seconds to sweep across
	var start_ms = Time.get_ticks_msec()
	
	var hits = 0
	var active_zone = 0
	var broken = false

	while true:
		await get_tree().process_frame
		var elapsed_ms = Time.get_ticks_msec() - start_ms
		
		if elapsed_ms >= total_ms:
			break
			
		var progress = float(elapsed_ms) / float(total_ms)
		qte_cursor.position.x = progress * bar_bg.size.x
		
		if not broken and active_zone < 3:
			var current_tz = targets[active_zone]
			var c_center = qte_cursor.position.x + (qte_cursor.size.x / 2.0)
			var tz_start = current_tz.position.x
			var tz_end = tz_start + current_tz.size.x
			
			# Check if cursor passed the zone without the player pressing space
			if c_center > tz_end + 5.0:
				broken = true
				qte_cursor.color = Color(0.4, 0.4, 0.4)
				current_tz.color = Color(0.2, 0.0, 0.0, 0.8)
				if miss_sound.stream != null: miss_sound.play()
				help_text.text = "COMBO DROPPED!"
				help_text.add_theme_color_override("font_color", Color.GRAY)
				screen_shake(8.0, 0.2)
				
			# Check if they pressed space
			elif Input.is_action_just_pressed("ui_accept"):
				# Give a tiny bit of leniency (8 pixels)
				if c_center >= tz_start - 8.0 and c_center <= tz_end + 8.0:
					hits += 1
					active_zone += 1
					current_tz.color = Color(1.0, 0.1, 0.1, 1.0) # Bright Crimson on hit!
					screen_shake(12.0, 0.15)
					
					# Pitch escalates with each successful hit
					if clang != null and clang.stream != null:
						clang.pitch_scale = 0.8 + (hits * 0.25) 
						clang.play()
						
					flash_rect.modulate.a = 0.0
					var hit_flash = qte_layer.create_tween()
					hit_flash.tween_property(flash_rect, "modulate:a", 0.15, 0.03)
					hit_flash.tween_property(flash_rect, "modulate:a", 0.00, 0.1)
				else:
					broken = true
					qte_cursor.color = Color(0.4, 0.4, 0.4)
					if miss_sound.stream != null: miss_sound.play()
					help_text.text = "MISSED!"
					help_text.add_theme_color_override("font_color", Color.GRAY)
					screen_shake(8.0, 0.2)
					
	# 4. FINAL RESOLUTION
	if hits == 3:
		help_text.text = "MAXIMUM BLOODSHED!"
		help_text.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
		screen_shake(20.0, 0.4)
		if crit_sound.stream != null: crit_sound.play()
		
	await get_tree().create_timer(0.45, true, false, true).timeout 
	
	var lb_out = qte_layer.create_tween().set_parallel(true)
	lb_out.tween_property(top_bar, "size:y", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lb_out.tween_property(bottom_bar, "size:y", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lb_out.tween_property(bottom_bar, "position:y", vp_size.y, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await lb_out.finished
	
	qte_layer.queue_free()
	get_tree().paused = prev_paused
	return hits # Returns 0, 1, 2, or 3!
	
# --- ABILITY 5: HUNDRED POINT STRIKE (Simon Says QTE) ---
# Returns the total number of successful combo hits
func _run_hundred_point_strike_minigame(attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker):
		return 0

	# 1. THE TELEGRAPH
	screen_shake(6.0, 0.2)
	
	if has_node("ClangSound") and get_node("ClangSound").stream != null:
		get_node("ClangSound").pitch_scale = 1.5 # Fast, sharp ring
		get_node("ClangSound").play()
		
	var f_text = FloatingTextScene.instantiate()
	f_text.text_to_show = "HUNDRED POINT STRIKE!"
	f_text.text_color = Color(0.9, 0.2, 1.0) # Vibrant Purple
	add_child(f_text)
	f_text.global_position = attacker.global_position + Vector2(32, -48)
	
	await get_tree().create_timer(0.7).timeout
	
	# --- CINEMATIC LOCK ---
	var prev_paused = get_tree().paused
	get_tree().paused = true

	# 2. THE UI POP
	var qte_layer = CanvasLayer.new()
	qte_layer.layer = 100 
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(qte_layer)
	
	var vp_size = get_viewport_rect().size
	
	var screen_dimmer = ColorRect.new()
	screen_dimmer.size = vp_size
	screen_dimmer.color = Color(0.1, 0.0, 0.2, 0.6) # Deep purple tint
	qte_layer.add_child(screen_dimmer)
	
	# The Prompt Box (Shows the Arrow Key)
	var prompt_box = ColorRect.new()
	prompt_box.size = Vector2(120, 120)
	prompt_box.position = (vp_size - prompt_box.size) / 2.0
	prompt_box.position.y -= 50
	prompt_box.color = Color(0.1, 0.1, 0.1, 0.9)
	qte_layer.add_child(prompt_box)
	
	var prompt_label = Label.new()
	prompt_label.text = "↑"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 80)
	prompt_label.add_theme_color_override("font_color", Color.WHITE)
	prompt_label.size = prompt_box.size
	prompt_box.add_child(prompt_label)
	
	# The Timer Bar (Shrinks down)
	var timer_bar = ProgressBar.new()
	timer_bar.max_value = 100
	timer_bar.value = 100
	timer_bar.size = Vector2(300, 20)
	timer_bar.position = Vector2((vp_size.x - 300) / 2.0, prompt_box.position.y + 140)
	timer_bar.show_percentage = false
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.9, 0.2, 1.0)
	timer_bar.add_theme_stylebox_override("fill", fill_style)
	qte_layer.add_child(timer_bar)
	
	# Combo Counter
	var combo_label = Label.new()
	combo_label.text = "HITS: 0"
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 40)
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	combo_label.position = Vector2(0, prompt_box.position.y - 60)
	combo_label.size.x = vp_size.x
	qte_layer.add_child(combo_label)

	# 3. THE COMBO LOOP
	var actions = ["ui_up", "ui_down", "ui_left", "ui_right"]
	var arrows = ["UP ↑", "DOWN ↓", "LEFT ←", "RIGHT →"]
	
	var hits = 0
	var current_target = randi() % 4
	prompt_label.text = arrows[current_target]
	
	# Base time is 1.2 seconds. It will shrink as the combo grows!
	var max_time_for_hit = 1.2 
	var time_left = max_time_for_hit
	var failed = false

	# We clear the input buffer so they don't accidentally fail on frame 1
	Input.flush_buffered_events()

	while not failed:
		await get_tree().process_frame
		var delta = get_process_delta_time()
		time_left -= delta
		
		# Update visual bar
		timer_bar.value = (time_left / max_time_for_hit) * 100.0
		
		# Did they run out of time?
		if time_left <= 0:
			failed = true
			prompt_box.color = Color(0.8, 0.1, 0.1) # Turn red
			prompt_label.text = "X"
			if miss_sound.stream != null: miss_sound.play()
			break
			
		# Check for player inputs
		var pressed_any = false
		var hit_correct = false
		
		for i in range(4):
			if Input.is_action_just_pressed(actions[i]):
				pressed_any = true
				if i == current_target:
					hit_correct = true
				break # Stop checking other keys if they pressed one
				
		if pressed_any:
			if hit_correct:
				# SUCCESS!
				hits += 1
				combo_label.text = "HITS: " + str(hits)
				
				# Play pitch-escalating sound
				if select_sound.stream != null:
					select_sound.pitch_scale = min(1.0 + (hits * 0.1), 2.5)
					select_sound.play()
					
				# Make the game harder! Shrink the time limit by 12% (min 0.25s)
				max_time_for_hit = max(0.25, max_time_for_hit * 0.88)
				time_left = max_time_for_hit
				
				# Pick a new random key
				current_target = randi() % 4
				prompt_label.text = arrows[current_target]
				
				# Micro flash for feedback
				prompt_box.modulate = Color(2.0, 2.0, 2.0)
				var flash = qte_layer.create_tween()
				flash.tween_property(prompt_box, "modulate", Color.WHITE, 0.05)
				
			else:
				# WRONG KEY PRESSED!
				failed = true
				prompt_box.color = Color(0.8, 0.1, 0.1) 
				prompt_label.text = "X"
				if miss_sound.stream != null: miss_sound.play()
				break

	# 4. RESOLUTION HOLD
	screen_shake(10.0, 0.2)
	await get_tree().create_timer(0.6, true, false, true).timeout 
	
	qte_layer.queue_free()
	get_tree().paused = prev_paused
	return hits

# ==========================================
# STAT APPLICATION HELPER
# ==========================================
func apply_stat_gains(unit: Node2D, gains: Dictionary) -> void:
	# 1. Update Max HP and heal the unit by the gain amount
	var hp_gain = gains.get("hp", 0)
	unit.max_hp += hp_gain
	unit.current_hp += hp_gain
	
	# 2. Update the Health Bar UI
	if unit.get("health_bar") != null:
		unit.health_bar.max_value = unit.max_hp
		unit.health_bar.value = unit.current_hp
		
	# 3. Apply the rest of the stats using safe dictionary lookups
	unit.strength += gains.get("str", 0)
	unit.magic += gains.get("mag", 0)
	unit.defense += gains.get("def", 0)
	unit.resistance += gains.get("res", 0)
	unit.speed += gains.get("spd", 0)
	unit.agility += gains.get("agi", 0)


# --- ABILITY 6: LAST STAND (Lethal Blow Survival) ---
func _run_last_stand_minigame(defender: Node2D) -> bool:
	if defender == null or not is_instance_valid(defender):
		return false

	# 1) THE EXTENDED TELEGRAPH (The Heartbeat)
	# We use 1.5 seconds to build tension so the player can get their thumb ready
	var clang = get_node_or_null("ClangSound")
	
	# Heartbeat 1
	screen_shake(8.0, 0.2)
	if clang:
		clang.pitch_scale = 0.4
		clang.play()
	
	var f_text = FloatingTextScene.instantiate()
	f_text.text_to_show = "LETHAL BLOW!"
	f_text.text_color = Color(1.0, 0.1, 0.1)
	add_child(f_text)
	f_text.global_position = defender.global_position + Vector2(32, -48)
	
	await get_tree().create_timer(0.6).timeout

	# Heartbeat 2 (Faster, Higher pitch, New Text)
	screen_shake(12.0, 0.2)
	if clang:
		clang.pitch_scale = 0.6
		clang.play()
		
	var f_text2 = FloatingTextScene.instantiate()
	f_text2.text_to_show = "GET READY..."
	f_text2.text_color = Color(1.0, 0.8, 0.2) # Gold warning
	add_child(f_text2)
	f_text2.global_position = defender.global_position + Vector2(32, -80)

	# Final pause to let the player focus
	await get_tree().create_timer(0.7).timeout

	# --- CINEMATIC LOCK ---
	var prev_paused = get_tree().paused
	get_tree().paused = true

	var qte_layer = CanvasLayer.new()
	qte_layer.layer = 100
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(qte_layer)

	var vp_size = get_viewport_rect().size

	# 2) UI SETUP
	var screen_dimmer = ColorRect.new()
	screen_dimmer.size = vp_size
	screen_dimmer.color = Color(0.4, 0.0, 0.0, 0.7) 
	qte_layer.add_child(screen_dimmer)

	var letterbox_h = 56.0
	var top_bar = ColorRect.new()
	top_bar.color = Color(0, 0, 0, 0.85)
	top_bar.size = Vector2(vp_size.x, 0.0)
	qte_layer.add_child(top_bar)

	var bottom_bar = ColorRect.new()
	bottom_bar.color = Color(0, 0, 0, 0.85)
	bottom_bar.position = Vector2(0.0, vp_size.y)
	bottom_bar.size = Vector2(vp_size.x, 0.0)
	qte_layer.add_child(bottom_bar)

	var lb_in = qte_layer.create_tween().set_parallel(true)
	lb_in.tween_property(top_bar, "size:y", letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lb_in.tween_property(bottom_bar, "size:y", letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lb_in.tween_property(bottom_bar, "position:y", vp_size.y - letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var flash_rect = ColorRect.new()
	flash_rect.size = vp_size
	flash_rect.color = Color.RED
	flash_rect.modulate = Color(1, 1, 1, 0)
	qte_layer.add_child(flash_rect)

	var bar_bg = ColorRect.new()
	bar_bg.size = Vector2(420, 34)
	bar_bg.pivot_offset = bar_bg.size / 2.0
	bar_bg.position = (vp_size - bar_bg.size) / 2.0
	bar_bg.position.y -= 100.0
	bar_bg.color = Color(0.05, 0.05, 0.05, 0.95)
	bar_bg.scale = Vector2(0.86, 0.86)
	bar_bg.modulate.a = 0.0
	qte_layer.add_child(bar_bg)

	var bar_pop = qte_layer.create_tween().set_parallel(true)
	bar_pop.tween_property(bar_bg, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bar_pop.tween_property(bar_bg, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var target_zone = ColorRect.new()
	target_zone.size = Vector2(40, 34) 
	target_zone.color = Color(1.0, 0.8, 0.2, 0.9) 
	var rand_max = bar_bg.size.x - target_zone.size.x
	target_zone.position = Vector2(randf_range(150.0, rand_max), 0.0)
	bar_bg.add_child(target_zone)

	var qte_cursor = ColorRect.new()
	qte_cursor.size = Vector2(10, 56)
	qte_cursor.position = Vector2(0, -11)
	qte_cursor.color = Color.WHITE
	bar_bg.add_child(qte_cursor)

	var help_text = Label.new()
	help_text.text = "DEFY DEATH!"
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.add_theme_font_size_override("font_size", 32)
	help_text.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	bar_bg.add_child(help_text)
	help_text.position = Vector2(0, -55)
	help_text.size.x = bar_bg.size.x

	# 3) TIMING LOOP (Speed is still the same: 0.45s)
	var total_ms = 600 
	var start_ms = Time.get_ticks_msec()
	var success = false
	var pressed = false

	while true:
		await get_tree().process_frame
		var elapsed_ms = Time.get_ticks_msec() - start_ms

		if elapsed_ms >= total_ms:
			break

		var progress = float(elapsed_ms) / float(total_ms)
		qte_cursor.position.x = progress * bar_bg.size.x

		if Input.is_action_just_pressed("ui_accept"):
			pressed = true
			var cursor_center = qte_cursor.position.x + (qte_cursor.size.x / 2.0)
			var tz_start = target_zone.position.x
			var tz_end = tz_start + target_zone.size.x

			if cursor_center >= tz_start and cursor_center <= tz_end:
				success = true
				qte_cursor.color = Color(1.0, 1.0, 1.0)
				target_zone.color = Color(1.0, 1.0, 1.0, 1.0)
				help_text.text = "SURVIVED!"
				help_text.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
				screen_shake(30.0, 0.4)
				if clang:
					clang.pitch_scale = 1.5
					clang.play()
				flash_rect.color = Color.WHITE
				flash_rect.modulate.a = 0.6
				var win_flash = qte_layer.create_tween()
				win_flash.tween_property(flash_rect, "modulate:a", 0.00, 0.25)
			else:
				success = false
				qte_cursor.color = Color(0.3, 0.0, 0.0)
				help_text.text = "FAILED"
				flash_rect.color = Color.BLACK
				flash_rect.modulate.a = 0.5
				var fail_flash = qte_layer.create_tween()
				fail_flash.tween_property(flash_rect, "modulate:a", 0.00, 0.15)
			break

	if not pressed:
		success = false
		help_text.text = "TOO SLOW"

	await get_tree().create_timer(0.5, true, false, true).timeout 

	var lb_out = qte_layer.create_tween().set_parallel(true)
	lb_out.tween_property(top_bar, "size:y", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lb_out.tween_property(bottom_bar, "size:y", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lb_out.tween_property(bottom_bar, "position:y", vp_size.y, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await lb_out.finished

	qte_layer.queue_free()
	get_tree().paused = prev_paused
	return success
	
func _start_double_animation():
	# Capture original positions if not already set
	if atk_double_origin == Vector2.ZERO:
		atk_double_origin = forecast_atk_double.position
		def_double_origin = forecast_def_double.position
	
	if figure_8_tween:
		figure_8_tween.kill()
	
	figure_8_tween = create_tween().set_loops()
	# We animate a value from 0 to TAU (one full circle/cycle)
	figure_8_tween.tween_method(_animate_doubles, 0.0, TAU, 2.0)

func _animate_doubles(angle: float):
	# The Lemniscate of Bernoulli formula for a Figure-8
	# x = cos(t), y = sin(2t) / 2
	var amplitude = 12.0 # How far it travels
	var offset_x = cos(angle) * amplitude
	var offset_y = (sin(2 * angle) / 2.0) * amplitude
	
	forecast_atk_double.position = atk_double_origin + Vector2(offset_x, offset_y)
	forecast_def_double.position = def_double_origin + Vector2(offset_x, offset_y)	

func setup_skirmish_battle() -> void:
	print("--- INITIALIZING UNDEAD SKIRMISH ---")
	
	# 1. Change Music
	if skirmish_music != null and has_node("LevelMusic"):
		get_node("LevelMusic").stream = skirmish_music
		get_node("LevelMusic").play()
		
	# 2. Delete Pre-placed Story Enemies
	for child in enemy_container.get_children():
		child.queue_free()
		
	# 3. Determine Scaling Level
	var scaling_level = CampaignManager.get_highest_roster_level()
	
	# 4. Spawn Random Zombies (4 to 6 enemies)
	if enemy_scene == null:
		print("ERROR: No EnemyScene assigned in Battlefield Inspector!")
		return
		
	var spawn_count = randi_range(4, 6)
	var valid_spawn_points = []
	
	# Find empty tiles on the right side of the map (Assuming map is 16 wide)
	for x in range(5, GRID_SIZE.x): 
		for y in range(GRID_SIZE.y):
			var pos = Vector2i(x, y)
			# Check if tile is walkable and empty
			if not astar.is_point_solid(pos) and get_unit_at(pos) == null:
				valid_spawn_points.append(pos)
				
	valid_spawn_points.shuffle()
	
	for i in range(min(spawn_count, valid_spawn_points.size())):
		var grid_pos = valid_spawn_points[i]
		var enemy = enemy_scene.instantiate()
		
		# Place them
		enemy.position = Vector2(grid_pos.x * CELL_SIZE.x, grid_pos.y * CELL_SIZE.y)
		enemy_container.add_child(enemy)
		
		# --- ZOMBIFY THEM ---
		enemy.unit_name = "Risen Dead"
		enemy.modulate = Color(0.6, 0.8, 0.6) # Sickly green tint
		
		var _diff_mult = 1.0
		var intelligence_boost = 0
		if CampaignManager.current_difficulty == CampaignManager.Difficulty.HARD: _diff_mult = 1.2
		if CampaignManager.current_difficulty == CampaignManager.Difficulty.MADDENING: _diff_mult = 1.4
		
		# Procedural Stats
		enemy.level = scaling_level
		enemy.max_hp = 18 + (scaling_level * 2)
		enemy.current_hp = enemy.max_hp
		enemy.strength = 4 + int(scaling_level * 0.8)
		enemy.defense = 2 + int(scaling_level * 0.5)
		enemy.speed = 2 + int(scaling_level * 0.3) # Zombies are slow
		enemy.experience_reward = 30 # Good for grinding
		enemy.ai_intelligence += intelligence_boost
		
		# Equip a basic weapon (assuming you have a way to give them one)
		# If you don't have code for this, they might spawn unarmed!
		# You might need: enemy.equipped_weapon = load("res://Resources/Weapons/IronAxe.tres")

# ==========================================
# LOOT WINDOW INFO PANEL
# ==========================================
func _on_loot_item_selected(index: int) -> void:
	if loot_desc_label == null: return
	
	# --- NEW: Read from Metadata instead of the raw array! ---
	var meta = loot_item_list.get_item_metadata(index)
	if meta == null: return
	
	var stack_amt = meta.get("count", 1)
	loot_desc_label.text = _get_item_detailed_info(meta["item"], stack_amt)
	
	if select_sound and select_sound.stream != null:
		select_sound.pitch_scale = 1.2
		select_sound.play()

# ==========================================
# INVENTORY WINDOW INFO PANEL
# ==========================================

func calculate_enemy_threat_range(enemy: Node2D) -> void:
	clear_ranges()
	enemy_reachable_tiles.clear()
	enemy_attackable_tiles.clear()
	if enemy == null: return

	var footprint: Array[Vector2i] = _unit_footprint_tiles(enemy)
	var move_range = enemy.get("move_range") if enemy.get("move_range") != null else 0

	var saved: Dictionary = {}
	for t in footprint:
		saved[t] = {"w": astar.is_point_solid(t), "fl": flying_astar.is_point_solid(t)}
		astar.set_point_solid(t, false)
		flying_astar.set_point_solid(t, false)

	var reach_accum: Dictionary = {}
	for start in footprint:
		var x0: int = maxi(0, start.x - move_range)
		var x1: int = mini(GRID_SIZE.x, start.x + move_range + 1)
		var y0: int = maxi(0, start.y - move_range)
		var y1: int = mini(GRID_SIZE.y, start.y + move_range + 1)
		for x in range(x0, x1):
			for y in range(y0, y1):
				var target = Vector2i(x, y)
				if abs(start.x - target.x) + abs(start.y - target.y) > move_range:
					continue

				var path = get_unit_path(enemy, start, target)
				if path.size() > 0:
					var path_cost = get_path_move_cost(path, enemy)
					if path_cost <= float(move_range):
						reach_accum[target] = true

	for t in footprint:
		var rec: Variant = saved.get(t, null)
		if rec != null:
			astar.set_point_solid(t, rec.w)
			flying_astar.set_point_solid(t, rec.fl)

	for k in reach_accum.keys():
		enemy_reachable_tiles.append(k)

	var min_r = 1
	var max_r = 1
	var ew: Resource = enemy.equipped_weapon
	var enemy_use_los: bool = true
	if ew != null:
		min_r = ew.min_range
		max_r = ew.max_range
		if ew.get("is_healing_staff") == true or ew.get("is_buff_staff") == true or ew.get("is_debuff_staff") == true:
			enemy_use_los = false

	for r_tile in enemy_reachable_tiles:
		for x in range(-max_r, max_r + 1):
			for y in range(-max_r, max_r + 1):
				var dist = abs(x) + abs(y)
				if dist >= min_r and dist <= max_r:
					var n = r_tile + Vector2i(x, y)
					if n.x >= 0 and n.x < GRID_SIZE.x and n.y >= 0 and n.y < GRID_SIZE.y:
						if not enemy_reachable_tiles.has(n) and not enemy_attackable_tiles.has(n):
							if enemy_use_los and not _attack_has_clear_los(r_tile, n):
								continue
							enemy_attackable_tiles.append(n)
	queue_redraw()
		
# Calculates the movement points, adding penalties for Armored units
func get_path_move_cost(path: Array[Vector2i], unit: Node2D) -> float:
	var total_cost = 0.0
	var is_flying = unit.get("move_type") == 2 # FLYING
	var is_armored = unit.get("move_type") == 1 # ARMORED


	for i in range(1, path.size()):
		if is_flying:
			total_cost += 1.0
		else:
			var base_cost = astar.get_point_weight_scale(path[i])
			# If terrain is tough (Cost > 1.0) and unit is Armored, punish them!
			if is_armored and base_cost > 1.0:
				base_cost += 1.0 
			total_cost += base_cost
	return total_cost
	
func get_unit_path(unit: Node2D, start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	if unit.get("move_type") == 2: # FLYING
		return flying_astar.get_id_path(start, target)
	return astar.get_id_path(start, target)

func calculate_full_danger_zone() -> void:
	_danger_zone_recalc_dirty = false
	danger_zone_move_tiles.clear()
	danger_zone_attack_tiles.clear()
	if enemy_container == null: return

	var union_move: Dictionary = {}
	var union_attack: Dictionary = {}

	for enemy in enemy_container.get_children():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		# Match get_enemy_at / FoW: hidden enemies do not contribute threat.
		if not enemy.visible:
			continue
		if enemy.get("current_hp") != null and enemy.current_hp <= 0:
			continue

		var footprint: Array[Vector2i] = _unit_footprint_tiles(enemy)
		var move_range = enemy.get("move_range") if enemy.get("move_range") != null else 0

		var saved: Dictionary = {}
		for t in footprint:
			saved[t] = {"w": astar.is_point_solid(t), "fl": flying_astar.is_point_solid(t)}
			astar.set_point_solid(t, false)
			flying_astar.set_point_solid(t, false)

		var reachable: Array[Vector2i] = []
		var reach_seen: Dictionary = {}
		for start in footprint:
			var x0: int = maxi(0, start.x - move_range)
			var x1: int = mini(GRID_SIZE.x, start.x + move_range + 1)
			var y0: int = maxi(0, start.y - move_range)
			var y1: int = mini(GRID_SIZE.y, start.y + move_range + 1)
			for x in range(x0, x1):
				for y in range(y0, y1):
					var target = Vector2i(x, y)
					if abs(start.x - target.x) + abs(start.y - target.y) > move_range:
						continue
					var path = get_unit_path(enemy, start, target)
					if path.size() > 0:
						var path_cost = get_path_move_cost(path, enemy)
						if path_cost <= float(move_range):
							if not reach_seen.has(target):
								reach_seen[target] = true
								reachable.append(target)

		for t in footprint:
			var rec: Variant = saved.get(t, null)
			if rec != null:
				astar.set_point_solid(t, rec.w)
				flying_astar.set_point_solid(t, rec.fl)

		var reachable_set: Dictionary = {}
		for t in reachable:
			reachable_set[t] = true
			union_move[t] = true

		var min_r = 1
		var max_r = 1
		var ew2: Resource = enemy.equipped_weapon
		var danger_use_los: bool = true
		if ew2 != null:
			min_r = ew2.min_range
			max_r = ew2.max_range
			if ew2.get("is_healing_staff") == true or ew2.get("is_buff_staff") == true or ew2.get("is_debuff_staff") == true:
				danger_use_los = false

		for r_tile in reachable:
			for ox in range(-max_r, max_r + 1):
				for oy in range(-max_r, max_r + 1):
					var dist = abs(ox) + abs(oy)
					if dist < min_r or dist > max_r:
						continue
					var n = r_tile + Vector2i(ox, oy)
					if n.x < 0 or n.x >= GRID_SIZE.x or n.y < 0 or n.y >= GRID_SIZE.y:
						continue
					if reachable_set.has(n):
						continue
					if union_attack.has(n):
						continue
					if danger_use_los and not _attack_has_clear_los(r_tile, n):
						continue
					union_attack[n] = true

	for k in union_move.keys():
		danger_zone_move_tiles.append(k)
	for k in union_attack.keys():
		danger_zone_attack_tiles.append(k)
	queue_redraw()

func toggle_danger_zone() -> void:
	show_danger_zone = !show_danger_zone
	if show_danger_zone:
		_danger_zone_recalc_dirty = false
		calculate_full_danger_zone()
		play_ui_sfx(UISfx.TARGET_OK) # Sharp "On" sound
		if battle_log and battle_log.visible:
			add_combat_log("Enemy threat overlay: ON (Shift) — visible enemies; purple = move, orange = attack", "gray")
	else:
		_danger_zone_recalc_dirty = false
		danger_zone_move_tiles.clear()
		danger_zone_attack_tiles.clear()
		play_ui_sfx(UISfx.INVALID) # Soft "Off" sound
		if battle_log and battle_log.visible:
			add_combat_log("Enemy threat overlay: OFF", "gray")
	queue_redraw()

# ==========================================
# TRADE SYSTEM LOGIC
# ==========================================
func show_trade_popup(ally: Node2D) -> void:
	# 1. Position the menu
	trade_popup.position = ally.get_global_transform_with_canvas().origin + Vector2(40, -40)
	trade_popup.visible = true
	
	# 2. Hide the Talk button by default
	popup_talk_btn.visible = false
	
	# 3. Check if a Support Conversation is ready!
	var initiator = player_state.active_unit
	if initiator == null or initiator.get("data") == null or ally.get("data") == null: return
	
	# --- THE FIX: USE CODENAMES ---
	var init_name = get_support_name(initiator)
	var ally_name = get_support_name(ally)
	
	var bond = CampaignManager.get_support_bond(init_name, ally_name)
	
	var support_file_found = null
	
	for s_file in initiator.data.supports:
		if s_file.partner_name == ally_name:
			support_file_found = s_file
			break
			
	if support_file_found == null:
		for s_file in ally.data.supports:
			if s_file.partner_name == init_name:
				support_file_found = s_file
				break
				
	# If we found a valid link between these two, check the points!
	if support_file_found != null:
		var rank = bond["rank"]
		if rank == 0 and bond["points"] >= support_file_found.points_for_c: popup_talk_btn.visible = true
		elif rank == 1 and bond["points"] >= support_file_found.points_for_b: popup_talk_btn.visible = true
		elif rank == 2 and bond["points"] >= support_file_found.points_for_a: popup_talk_btn.visible = true
	
func hide_trade_popup() -> void:
	trade_popup.visible = false
	
func _on_trade_popup_confirm() -> void:
	hide_trade_popup()
	if player_state.active_unit != null and player_state.trade_target_ally != null:
		open_trade_window(player_state.active_unit, player_state.trade_target_ally)

func open_trade_window(unit_a: Node2D, unit_b: Node2D) -> void:
	trade_unit_a = unit_a
	trade_unit_b = unit_b
	trade_selected_side = ""
	trade_selected_index = -1
	
	player_state.is_forecasting = true # Freeze the map
	
	# Setup Portraits and Names
	trade_left_name.text = unit_a.unit_name
	trade_right_name.text = unit_b.unit_name
	if unit_a.data and unit_a.data.portrait: trade_left_portrait.texture = unit_a.data.portrait
	if unit_b.data and unit_b.data.portrait: trade_right_portrait.texture = unit_b.data.portrait
	
	refresh_trade_window()
	trade_window.visible = true

func refresh_trade_window() -> void:
	trade_left_list.clear()
	trade_right_list.clear()
	
	_fill_trade_list(trade_left_list, trade_unit_a)
	_fill_trade_list(trade_right_list, trade_unit_b)
	
	# Keep the item highlighted if they are mid-swap
	if trade_selected_side == "left" and trade_selected_index != -1:
		trade_left_list.select(trade_selected_index)
	elif trade_selected_side == "right" and trade_selected_index != -1:
		trade_right_list.select(trade_selected_index)

func _fill_trade_list(list: ItemList, unit: Node2D) -> void:
	var inv = []
	if "inventory" in unit:
		inv = unit.inventory
	
	# Always draw exactly 5 slots
	for i in range(5):
		if i < inv.size() and inv[i] != null:
			var item = inv[i]
			var text = _get_item_display_text(item)
			if item == unit.equipped_weapon: text = "[E] " + text
			var img = item.get("icon") if item.get("icon") != null else null
			list.add_item(text, img)
		else:
			list.add_item("--- Empty ---", null)

func _on_trade_item_clicked(index: int, side: String) -> void:
	if select_sound.stream != null: select_sound.play()
	
	# Click 1: Select the first item
	if trade_selected_side == "":
		trade_selected_side = side
		trade_selected_index = index
		return
		
	# Click 2 (Same Item): Deselect it
	if trade_selected_side == side and trade_selected_index == index:
		trade_selected_side = ""
		trade_selected_index = -1
		refresh_trade_window()
		return
		
	# Click 2 (Different Item or Empty Slot): Execute the Swap!
	_execute_trade_swap(trade_selected_side, trade_selected_index, side, index)
	
	# Reset state after swapping
	trade_selected_side = ""
	trade_selected_index = -1
	refresh_trade_window()

func _execute_trade_swap(side1: String, idx1: int, side2: String, idx2: int) -> void:
	# 1. Normalize both arrays to exactly 5 slots (prevents crash on empty slot clicks)
	var inv_a = trade_unit_a.inventory.duplicate()
	var inv_b = trade_unit_b.inventory.duplicate()
	inv_a.resize(5)
	inv_b.resize(5)
	
	# 2. Point to the correct arrays based on the click
	var target_inv1 = inv_a if side1 == "left" else inv_b
	var target_inv2 = inv_a if side2 == "left" else inv_b
	
	# 3. Swap the data
	var temp = target_inv1[idx1]
	target_inv1[idx1] = target_inv2[idx2]
	target_inv2[idx2] = temp
	
	# 4. Strip the empty slots out and save it back to the units
	trade_unit_a.inventory.clear()
	for item in inv_a: 
		if item != null: trade_unit_a.inventory.append(item)
		
	trade_unit_b.inventory.clear()
	for item in inv_b: 
		if item != null: trade_unit_b.inventory.append(item)

func _on_trade_window_close() -> void:
	trade_window.visible = false
	player_state.is_forecasting = false
	player_state.trade_target_ally = null
	
	# Ensure nobody is holding a ghost weapon they just traded away
	_validate_equipment(trade_unit_a)
	_validate_equipment(trade_unit_b)
	update_unit_info_panel()

func _validate_equipment(unit: Node2D) -> void:
	if unit == null:
		return

	if unit.equipped_weapon != null:
		var still_has_weapon: bool = unit.inventory.has(unit.equipped_weapon)
		var still_allowed: bool = _unit_can_equip_weapon(unit, unit.equipped_weapon)

		if not still_has_weapon or not still_allowed:
			unit.equipped_weapon = null

	if unit.equipped_weapon == null:
		for item in unit.inventory:
			if item is WeaponData and _unit_can_equip_weapon(unit, item):
				unit.equipped_weapon = item
				break
	
func execute_talk(initiator: Node2D, target: Node2D) -> void:
	# --- 1. PLAY THE CINEMATIC FIRST! ---
	await play_recruit_dialogue(initiator, target)
	
	# --- 2. EXECUTE THE TEAM SWAP ---
	target.get_parent().remove_child(target)
	player_container.add_child(target)
	
	if target.get("data") != null:
		target.data.is_recruitable = false
		
	target.is_exhausted = true
	if target.has_method("set_selected_glow"):
		target.set_selected_glow(false)
		
	if epic_level_up_sound and epic_level_up_sound.stream != null:
		epic_level_up_sound.play()
		
	screen_shake(8.0, 0.3)
	add_combat_log(initiator.unit_name + " convinced " + target.unit_name + " to join.", "cyan")
	spawn_loot_text("RECRUITED!", Color.LIME, target.global_position + Vector2(32, -32))
	if _battle_resonance_allowed():
		CampaignManager.mark_battle_resonance("showed_mercy_under_pressure")
	rebuild_grid()

func play_recruit_dialogue(initiator: Node2D, target: Node2D) -> void:
	# Freeze the battlefield, but keep the UI running
	get_tree().paused = true
	talk_panel.process_mode = Node.PROCESS_MODE_ALWAYS 
	
	# Grab the dialogue from the enemy data safely
	var lines: Array[String] = []
	if target.get("data") != null and "recruit_dialogue" in target.data and target.data.recruit_dialogue.size() > 0:
		for l in target.data.recruit_dialogue: 
			lines.append(str(l))
	else:
		lines = ["Join us!", "If the pay is good, I'm in."] # Fallback text
		
	# Setup Portraits
	talk_left_portrait.texture = initiator.data.portrait if initiator.get("data") else null
	talk_right_portrait.texture = target.data.portrait if target.get("data") else null
	
	talk_panel.visible = true
	
	# Loop through the conversation line by line
	for i in range(lines.size()):
		var is_initiator_speaking = (i % 2 == 0) # Evens = Player, Odds = Enemy
		
		# Dim the listener, highlight the speaker
		if is_initiator_speaking:
			talk_name.text = initiator.unit_name
			talk_name.modulate = Color.CYAN
			talk_left_portrait.modulate = Color.WHITE
			talk_right_portrait.modulate = Color(0.3, 0.3, 0.3) # Dimmer
		else:
			talk_name.text = target.unit_name
			talk_name.modulate = Color.TOMATO
			talk_left_portrait.modulate = Color(0.3, 0.3, 0.3) # Dimmer
			talk_right_portrait.modulate = Color.WHITE
			
		# Prepare text and replace {Name} with the Avatar's real name!
		var line_text = lines[i]
		if initiator.get("is_custom_avatar") == true:
			line_text = line_text.replace("{Name}", initiator.unit_name)
		elif target.get("is_custom_avatar") == true:
			line_text = line_text.replace("{Name}", target.unit_name)
			
		talk_text.text = "[center]" + line_text + "[/center]"
		talk_text.visible_ratio = 0.0 # Hide all text initially
		
		# Play a tiny dialogue beep
		if select_sound and select_sound.stream != null:
			select_sound.pitch_scale = 1.2 if is_initiator_speaking else 0.8
			select_sound.play()
			
		# Typewriter Effect Tween
		var type_speed = lines[i].length() * 0.025 # Longer lines take slightly more time
		var tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(talk_text, "visible_ratio", 1.0, type_speed)
		
		# Wait for the player to click the invisible Next Button
		await self.dialogue_advanced
		
		# If they clicked while text was still typing, force it to finish instantly!
		if tw.is_running():
			tw.kill()
			talk_text.visible_ratio = 1.0
			await self.dialogue_advanced # Wait for a second click to actually move on
		
	# Cleanup
	talk_panel.visible = false
	get_tree().paused = false

func _on_support_talk_pressed() -> void:
	hide_trade_popup()
	var initiator = player_state.active_unit
	var ally = player_state.trade_target_ally
	
	if initiator != null and ally != null:
		play_ui_sfx(UISfx.TARGET_OK)
		await play_support_dialogue(initiator, ally)
		# End the initiator's turn after talking
		initiator.finish_turn()
		player_state.clear_active_unit()

func play_support_dialogue(initiator: Node2D, target: Node2D) -> void:
	var init_name = get_support_name(initiator)
	var target_name = get_support_name(target)
	var bond = CampaignManager.get_support_bond(init_name, target_name)
	
	var dialogue_lines = []
	var new_rank_name = "C"
	var support_file_found = null
	
	for s_file in initiator.data.supports:
		if s_file.partner_name == target_name:
			support_file_found = s_file
			break
			
	if support_file_found == null:
		for s_file in target.data.supports:
			if s_file.partner_name == init_name:
				support_file_found = s_file
				break
				
	if support_file_found != null:
		if bond["rank"] == 0: 
			dialogue_lines = support_file_found.c_dialogue
			new_rank_name = "C"
		elif bond["rank"] == 1: 
			dialogue_lines = support_file_found.b_dialogue
			new_rank_name = "B"
		elif bond["rank"] == 2: 
			dialogue_lines = support_file_found.a_dialogue
			new_rank_name = "A"
			
	# Reuse the exact same cinematic UI we built for Enemy Recruitment!
	var temp_data = target.get("data")
	var original_recruit = []
	if temp_data and "recruit_dialogue" in temp_data:
		original_recruit = temp_data.recruit_dialogue.duplicate()
		temp_data.recruit_dialogue = dialogue_lines 
		
	# Play the cinematic scene
	await play_recruit_dialogue(initiator, target)
	
	# Restore their original data
	if temp_data and "recruit_dialogue" in temp_data:
		temp_data.recruit_dialogue = original_recruit
		
	# Upgrade the Rank permanently!
	bond["rank"] += 1
	
	if level_up_sound.stream != null: level_up_sound.play()
	spawn_loot_text("SUPPORT RANK " + new_rank_name + "!", Color.VIOLET, initiator.global_position + Vector2(0, -40))
	if support_file_found != null:
		var a_name: String = str(initiator.get("unit_name")) if initiator.get("unit_name") != null else "Unit"
		var b_name: String = str(target.get("unit_name")) if target.get("unit_name") != null else "Ally"
		add_combat_log(a_name + " & " + b_name + ": Support rank → " + new_rank_name + "!", "violet")

# Safely handles the Player's custom name for Support Files
func get_support_name(unit: Node2D) -> String:
	if unit.get("is_custom_avatar") == true:
		return "Avatar" # This is the codename you will type in the Inspector!
	return unit.unit_name

# --- Relationship Web V1: central identity for relationship lookups (future-proof for unit_id migration). ---
func get_relationship_id(unit_or_name: Variant) -> String:
	if unit_or_name is Node2D:
		return get_support_name(unit_or_name)
	if unit_or_name is String:
		return unit_or_name
	return ""

# --- Relationship Web V1: tag and combat modifiers. ---
## Returns unit_tags array from unit or unit.data; empty if missing.
func get_unit_tags(unit: Node2D) -> Array:
	if unit == null:
		return []
	var tags = unit.get("unit_tags")
	if tags is Array:
		return tags
	var data = unit.get("data")
	if data != null:
		var dt = data.get("unit_tags")
		if dt is Array:
			return dt
	return []

## Returns combat modifiers from relationship web + grief + fear tags. hit/avo/crit_bonus/dmg_bonus/support_chance_bonus (additive).
func get_relationship_combat_modifiers(unit: Node2D) -> Dictionary:
	var out := {"hit": 0, "avo": 0, "crit_bonus": 0, "dmg_bonus": 0, "support_chance_bonus": 0}
	if unit == null:
		return out
	var my_id: String = get_relationship_id(unit)
	var my_pos: Vector2i = get_grid_pos(unit)
	var is_allied := (unit.get_parent() == player_container or (ally_container != null and unit.get_parent() == ally_container))

	# Grief: temporary penalty after witnessing trusted ally die (battle-local only)
	if _grief_units.get(my_id, false):
		out["hit"] += RELATIONSHIP_GRIEF_HIT_PENALTY
		out["avo"] += RELATIONSHIP_GRIEF_AVO_PENALTY

	# Fear/disgust: penalty when adjacent to any unit (enemy or ally) with certain tags
	var directions := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for dir in directions:
		var neighbor_pos: Vector2i = my_pos + dir
		var neighbor: Node2D = get_occupant_at(neighbor_pos)
		if neighbor == null or neighbor == unit:
			continue
		var etags: Array = get_unit_tags(neighbor)
		for tag in FEAR_TAGS:
			if tag in etags:
				out["hit"] += RELATIONSHIP_FEAR_HIT_PENALTY
				out["avo"] += RELATIONSHIP_FEAR_AVO_PENALTY
				break

	# Trust / rivalry / mentorship: only for allied units
	if not is_allied:
		return out
	var allies: Array[Node2D] = []
	if player_container:
		for c in player_container.get_children():
			if c is Node2D and c != unit and is_instance_valid(c) and (c.get("current_hp") != null and int(c.current_hp) > 0):
				allies.append(c)
	if ally_container:
		for c in ally_container.get_children():
			if c is Node2D and c != unit and is_instance_valid(c) and (c.get("current_hp") != null and int(c.current_hp) > 0):
				allies.append(c)
	for ally in allies:
		var dist: int = abs(get_grid_pos(ally).x - my_pos.x) + abs(get_grid_pos(ally).y - my_pos.y)
		if dist > SUPPORT_COMBAT_RANGE_MANHATTAN:
			continue
		var rel: Dictionary = CampaignManager.get_relationship(my_id, get_relationship_id(ally))
		if rel["trust"] >= RELATIONSHIP_TRUST_THRESHOLD:
			out["support_chance_bonus"] = maxi(out["support_chance_bonus"], RELATIONSHIP_TRUST_SUPPORT_CHANCE_BONUS)
		if rel["rivalry"] >= RELATIONSHIP_RIVALRY_THRESHOLD:
			out["crit_bonus"] += RELATIONSHIP_RIVALRY_CRIT_BONUS
			out["dmg_bonus"] += RELATIONSHIP_RIVALRY_DMG_BONUS
		if rel["mentorship"] >= RELATIONSHIP_MENTORSHIP_THRESHOLD:
			out["hit"] += RELATIONSHIP_MENTORSHIP_HIT_BONUS

	if DEBUG_RELATIONSHIP_COMBAT and (out["hit"] != 0 or out["avo"] != 0 or out["crit_bonus"] != 0 or out["dmg_bonus"] != 0 or out["support_chance_bonus"] != 0):
		print("[RelationshipCombat] ", my_id, " mods: ", out)
	return out

## Lightweight Bond Pulse: floating text at world_pos (rise + fade via existing FloatingText).
func _show_bond_pulse(world_pos: Vector2, text: String, color: Color) -> void:
	spawn_loot_text(text, color, world_pos)

## True if mentor is higher level than mentee with gap >= MENTORSHIP_LEVEL_GAP_MIN; both allied and valid.
func _can_gain_mentorship(mentor: Node2D, mentee: Node2D) -> bool:
	if mentor == null or mentee == null or mentor == mentee:
		return false
	if not is_instance_valid(mentor) or not is_instance_valid(mentee):
		return false
	var mentor_parent: Node = mentor.get_parent()
	var mentee_parent: Node = mentee.get_parent()
	var mentor_allied: bool = (mentor_parent == player_container or (ally_container != null and mentor_parent == ally_container))
	var mentee_allied: bool = (mentee_parent == player_container or (ally_container != null and mentee_parent == ally_container))
	if not mentor_allied or not mentee_allied:
		return false
	var _ml: Variant = mentor.get("level")
	var _el: Variant = mentee.get("level")
	var mentor_lv: int = 1 if _ml == null else int(_ml)
	var mentee_lv: int = 1 if _el == null else int(_el)
	if mentor_lv <= mentee_lv:
		return false
	return (mentor_lv - mentee_lv) >= MENTORSHIP_LEVEL_GAP_MIN

## Awards a relationship stat (trust/mentorship/rivalry) from an event; one gain per pair per event_type per battle. Shows Bond Pulse; "Formed" log on threshold cross.
func _award_relationship_stat_event(unit_a: Variant, unit_b: Variant, stat: String, event_type: String, amount: int = 1) -> void:
	var id_a: String = get_relationship_id(unit_a)
	var id_b: String = get_relationship_id(unit_b)
	if id_a.is_empty() or id_b.is_empty():
		return
	var key: String = CampaignManager.get_support_key(id_a, id_b) + "_" + event_type
	if _relationship_event_awarded.get(key, false):
		return
	_relationship_event_awarded[key] = true
	var rel: Dictionary = CampaignManager.get_relationship(id_a, id_b)
	var old_val: int = int(rel.get(stat, 0))
	CampaignManager.add_relationship_value(id_a, id_b, stat, amount)
	var new_val: int = old_val + amount

	var pulse_text: String = ""
	var pulse_color: Color = BOND_PULSE_COLOR_TRUST
	if stat == "trust":
		pulse_text = "Trust +1"
		pulse_color = BOND_PULSE_COLOR_TRUST
	elif stat == "mentorship":
		if new_val >= MENTORSHIP_FORMED_THRESHOLD and old_val < MENTORSHIP_FORMED_THRESHOLD:
			pulse_text = "Mentorship Formed"
			add_combat_log("Mentorship has formed between " + id_a + " and " + id_b + ".", "gold")
		else:
			pulse_text = "Mentorship +1"
		pulse_color = BOND_PULSE_COLOR_MENTORSHIP
	elif stat == "rivalry":
		if new_val >= RIVALRY_FORMED_THRESHOLD and old_val < RIVALRY_FORMED_THRESHOLD:
			pulse_text = "Rivalry Formed"
			add_combat_log("A rivalry ignites between " + id_a + " and " + id_b + ".", "tomato")
		else:
			pulse_text = "Rivalry +1"
		pulse_color = BOND_PULSE_COLOR_RIVALRY
	else:
		return

	var pos: Vector2 = Vector2.ZERO
	if unit_a is Node2D and unit_b is Node2D:
		pos = (unit_a.global_position + unit_b.global_position) * 0.5
	elif unit_a is Node2D:
		pos = unit_a.global_position
	elif unit_b is Node2D:
		pos = unit_b.global_position
	else:
		return
	_show_bond_pulse(pos + Vector2(32, -24), pulse_text, pulse_color)

## Trust-only shorthand (calls _award_relationship_stat_event with stat "trust").
func _award_relationship_event(unit_a: Variant, unit_b: Variant, event_type: String, amount: int = 1) -> void:
	_award_relationship_stat_event(unit_a, unit_b, "trust", event_type, amount)

# --- Boss Personal Dialogue (V1): identity helpers; lookup via BossPersonalDialogueDB.get_line. ---
## Returns stable boss/commander ID for dialogue lookup (unit_name or data.display_name).
func _get_boss_dialogue_id(unit: Node2D) -> String:
	if unit == null:
		return ""
	var name_var = unit.get("unit_name")
	if name_var != null and str(name_var).strip_edges().length() > 0:
		return str(name_var).strip_edges()
	var data = unit.get("data")
	if data != null and data.get("display_name") != null:
		return str(data.display_name).strip_edges()
	return ""

## Returns stable playable unit ID for dialogue lookup (reuses get_support_name: unit_name or "Avatar").
func _get_playable_dialogue_id(unit: Node2D) -> String:
	return get_support_name(unit) if unit != null else ""

## Returns personal dialogue line for boss_id + unit_id + event_type (pre_attack/death/retreat); queries BossPersonalDialogueDB.
func _get_boss_personal_line(boss_id: String, unit_id: String, event_type: String) -> String:
	return BossDialogueDB.get_line(boss_id, unit_id, event_type)

## Returns support_personality from unit's UnitData; empty string if missing. Used for Defy Death rescue line lookup.
func _get_support_personality(unit: Node2D) -> String:
	if unit == null:
		return ""
	var d = unit.get("data")
	if d == null:
		return ""
	var p = d.get("support_personality")
	return str(p).strip_edges() if p != null else ""

## Returns savior-spoken rescue line for Defy Death; uses savior's personality and victim's display name.
func _get_defy_death_rescue_line(savior: Node2D, victim_name: String) -> String:
	var personality: String = _get_support_personality(savior)
	return SupportRescueDialogueDB.get_line(personality, victim_name)

## Shows TalkPanel with savior portrait and rescue line for a short time. Does not pause the game.
func _show_defy_death_savior_portrait(savior: Node2D, savior_name: String, rescue_line: String) -> void:
	if talk_panel == null:
		return
	var portrait_tex: Texture2D = null
	if savior != null and savior.get("data") != null:
		var p = savior.data.get("portrait")
		if p is Texture2D:
			portrait_tex = p
	talk_left_portrait.texture = portrait_tex
	talk_left_portrait.modulate = Color.WHITE
	talk_left_portrait.visible = true
	if talk_right_portrait != null:
		talk_right_portrait.texture = null
		talk_right_portrait.visible = false
	talk_name.text = savior_name
	talk_name.modulate = Color.GOLD
	talk_text.text = "[center]" + rescue_line + "[/center]"
	talk_text.visible_ratio = 1.0
	if talk_next_btn != null:
		talk_next_btn.visible = false
	talk_panel.visible = true
	await get_tree().create_timer(2.0).timeout
	talk_panel.visible = false
	if talk_next_btn != null:
		talk_next_btn.visible = true

# Normalizes support rank from bond data to 0..3. Handles int, string "C"/"B"/"A", null/missing; malformed => 0.
func _normalize_support_rank(bond: Variant) -> int:
	if bond == null or not (bond is Dictionary):
		return 0
	var r: Variant = bond.get("rank", null)
	if r == null:
		return 0
	if r is int:
		return clampi(int(r), 0, 3)
	if r is String:
		var s := (r as String).strip_edges().to_upper()
		if s == "C": return 1
		if s == "B": return 2
		if s == "A": return 3
		return 0
	return 0

# --- Support-combat: Phase 1 passive bonuses; Phase 2 reactions (Guard, Defy Death, Dual Strike) via get_best_support_context + _apply_hit_with_support_reactions. ---
# Returns passive combat bonuses from the single best support partner within SUPPORT_COMBAT_RANGE_MANHATTAN.
# Only applies to player/ally units; uses CampaignManager.support_bonds; missing/legacy data => no bonus.
func get_support_combat_bonus(unit: Node2D) -> Dictionary:
	var out := {"hit": 0, "avo": 0, "crit_avo": 0}
	if unit == null or unit.get_parent() == destructibles_container:
		return out
	var is_allied := (unit.get_parent() == player_container or (ally_container != null and unit.get_parent() == ally_container))
	if not is_allied:
		return out
	var my_pos: Vector2i = get_grid_pos(unit)
	var my_name: String = get_support_name(unit)
	var best_rank: int = 0
	var allies: Array[Node2D] = []
	var collect := func(container: Node) -> void:
		if container == null: return
		for c in container.get_children():
			if not (c is Node2D) or c == unit: continue
			if not is_instance_valid(c) or c.is_queued_for_deletion(): continue
			if c.get("current_hp") != null and int(c.current_hp) <= 0: continue
			allies.append(c)
	collect.call(player_container)
	if ally_container: collect.call(ally_container)
	for ally in allies:
		var dist: int = abs(get_grid_pos(ally).x - my_pos.x) + abs(get_grid_pos(ally).y - my_pos.y)
		if dist > SUPPORT_COMBAT_RANGE_MANHATTAN:
			continue
		var bond: Dictionary = CampaignManager.get_support_bond(my_name, get_support_name(ally))
		var rank: int = _normalize_support_rank(bond)
		if rank > best_rank:
			best_rank = rank
	if best_rank <= 0 or not SUPPORT_COMBAT_RANK_BONUSES.has(best_rank):
		return out
	out = SUPPORT_COMBAT_RANK_BONUSES[best_rank].duplicate()
	if DEBUG_SUPPORT_COMBAT and unit.get("unit_name") != null:
		print("[SupportCombat] ", unit.unit_name, " rank ", best_rank, " -> +", out["hit"], " hit +", out["avo"], " avo +", out["crit_avo"], " c.avo")
	return out

# --- Phase 2: support reaction context (partner node, rank, can_react). Used by Guard, Defy Death, Dual Strike. ---
## Returns the best support partner and rank for reaction checks. Reuses Phase 1 range and identity.
## Purpose: Expose partner node and rank so callers can implement Guard (rank>=2), Defy Death (rank 3), Dual Strike (rank>=2).
## Inputs: unit (Node2D) — the unit whose support partner we query.
## Outputs: Dictionary with "partner" (Node2D or null), "rank" (int 0..3), "in_range" (bool), "can_react" (bool).
## Side effects: None. Missing/invalid data => partner null, rank 0, can_react false.
func get_best_support_context(unit: Node2D) -> Dictionary:
	var empty := {"partner": null, "rank": 0, "in_range": false, "can_react": false}
	if unit == null or unit.get_parent() == destructibles_container:
		return empty
	var is_allied := (unit.get_parent() == player_container or (ally_container != null and unit.get_parent() == ally_container))
	if not is_allied:
		return empty
	var my_pos: Vector2i = get_grid_pos(unit)
	var my_name: String = get_support_name(unit)
	var best_rank_ref: Array = [0]
	var best_partner_ref: Array = [null]
	var collect := func(container: Node) -> void:
		if container == null: return
		for c in container.get_children():
			if not (c is Node2D) or c == unit: continue
			if not is_instance_valid(c) or c.is_queued_for_deletion(): continue
			if c.get("current_hp") != null and int(c.current_hp) <= 0: continue
			var dist: int = abs(get_grid_pos(c).x - my_pos.x) + abs(get_grid_pos(c).y - my_pos.y)
			if dist > SUPPORT_COMBAT_RANGE_MANHATTAN:
				continue
			var bond: Dictionary = CampaignManager.get_support_bond(my_name, get_support_name(c))
			var rank: int = _normalize_support_rank(bond)
			if rank > best_rank_ref[0]:
				best_rank_ref[0] = rank
				best_partner_ref[0] = c
	collect.call(player_container)
	if ally_container: collect.call(ally_container)
	var best_partner: Node2D = best_partner_ref[0]
	var best_rank: int = best_rank_ref[0]
	var in_range: bool = best_partner != null
	var can_react: bool = (best_partner != null and is_instance_valid(best_partner) and not best_partner.is_queued_for_deletion() and best_partner.get_parent() != destructibles_container and (best_partner.get("current_hp") != null and int(best_partner.current_hp) > 0))
	return {"partner": best_partner, "rank": best_rank, "in_range": in_range, "can_react": can_react}

## Applies one hit with Phase 2 support reactions: Guard (redirect one hit to partner), then Defy Death (survive at 1 HP once per battle).
## Purpose: Single insertion point for Guard/Defy so forecast and resolution stay consistent; prevents redirect loops via is_redirected.
## Inputs: victim (Node2D), damage (int), source (Node2D), exp_tgt (Node2D or null), is_redirected (bool) — if true, no reactions.
## Outputs: None.
## Side effects: May apply damage to victim or to guard partner; may cap damage and set _defy_death_used; sets _support_guard_used_this_sequence when Guard triggers.
func _apply_hit_with_support_reactions(victim: Node2D, damage: int, source: Node2D, exp_tgt: Node2D, is_redirected: bool) -> void:
	if victim == null or not is_instance_valid(victim):
		return
	# Rivalry: record ally damager of this enemy (for contested-kill rivalry later).
	if victim.get_parent() == enemy_container and source != null and is_instance_valid(source):
		var src_parent: Node = source.get_parent()
		if src_parent == player_container or (ally_container != null and src_parent == ally_container):
			var eid: int = victim.get_instance_id()
			if not _enemy_damagers.has(eid):
				_enemy_damagers[eid] = []
			var rid: String = get_relationship_id(source)
			if rid != "" and rid not in _enemy_damagers[eid]:
				_enemy_damagers[eid].append(rid)
	if is_redirected:
		victim.take_damage(damage, source)
		return
	# Guard: one redirect per sequence; rank >= 2; redirect this hit to partner (partner cannot be victim).
	if not _support_guard_used_this_sequence:
		var ctx: Dictionary = get_best_support_context(victim)
		var partner: Node2D = ctx.get("partner", null) as Node2D
		var rank: int = int(ctx.get("rank", 0))
		if partner != null and partner != victim and rank >= 2 and ctx.get("can_react", false):
			var guard_chance: int = SUPPORT_GUARD_CHANCE_RANK3 if rank >= 3 else SUPPORT_GUARD_CHANCE_RANK2
			guard_chance += get_relationship_combat_modifiers(victim).get("support_chance_bonus", 0)
			if randi() % 100 < guard_chance:
				_support_guard_used_this_sequence = true
				if DEBUG_SUPPORT_COMBAT:
					print("[SupportReaction] Guard! ", victim.get("unit_name"), " -> partner takes hit")
				var guard_log: String = "Guard!"
				if get_relationship_combat_modifiers(victim).get("support_chance_bonus", 0) > 0 and victim.get("unit_name") != null and partner.get("unit_name") != null:
					guard_log = str(partner.unit_name) + " guarded " + str(victim.unit_name) + " out of trust."
				add_combat_log(guard_log, "lime")
				spawn_loot_text("Guard!", Color(0.2, 1.0, 0.4), partner.global_position + Vector2(32, -24))
				_award_relationship_event(partner, victim, "guard", 1)
				if _can_gain_mentorship(partner, victim):
					_award_relationship_stat_event(partner, victim, "mentorship", "guard_mentorship", 1)
				_apply_hit_with_support_reactions(partner, damage, source, null, true)
				return
	# Defy Death: rank 3 only; lethal hit; once per unit per battle; Guard did not fire.
	var victim_instance_id: int = victim.get_instance_id()
	var would_be_lethal: bool = (victim.get("current_hp") != null and (int(victim.current_hp) - damage <= 0))
	if would_be_lethal:
		var ctx: Dictionary = get_best_support_context(victim)
		var partner: Node2D = ctx.get("partner", null) as Node2D
		var rank: int = int(ctx.get("rank", 0))
		if rank >= 3 and partner != null and not _defy_death_used.get(victim_instance_id, false):
			_defy_death_used[victim_instance_id] = true
			var capped: int = int(victim.current_hp) - 1
			if capped < 0:
				capped = 0
			if DEBUG_SUPPORT_COMBAT:
				print("[SupportReaction] Defy Death! ", victim.get("unit_name"), " saved at 1 HP")
			var victim_name: String = get_support_name(victim)
			var rescue_line: String = _get_defy_death_rescue_line(partner, victim_name)
			var savior_name: String = partner.get("unit_name") if partner.get("unit_name") != null else "Ally"
			await _show_defy_death_savior_portrait(partner, savior_name, rescue_line)
			add_combat_log(savior_name + ": " + rescue_line, "gold")
			spawn_loot_text("Defied Death!", Color(1.0, 0.84, 0.0), victim.global_position + Vector2(32, -32))
			victim.take_damage(capped, source)
			return
	victim.take_damage(damage, exp_tgt)

func _on_support_btn_pressed() -> void:
	if select_sound and select_sound.stream != null: select_sound.play()
	
	# 1. Figure out whose supports we are checking
	var target_unit = null
	if current_state == player_state and player_state.active_unit != null:
		target_unit = player_state.active_unit
	else:
		target_unit = get_occupant_at(cursor_grid_pos)
		
	if target_unit == null: return
	
	var u_name = get_support_name(target_unit)
	var display_text = "[center][b][color=gold]--- " + target_unit.unit_name.to_upper() + "'S BONDS ---[/color][/b][/center]\n\n"
	var found_any_friends = false
	
	# 2. Loop through the global memory and find their friends!
	for key in CampaignManager.support_bonds.keys():
		var names: PackedStringArray = CampaignManager.parse_relationship_key(key)
		var partner_name := ""
		if names.size() >= 2:
			if names[0] == u_name: partner_name = names[1]
			elif names[1] == u_name: partner_name = names[0]

		# If we found a match, format their current standing!
		if partner_name != "":
			found_any_friends = true
			# --- Translate 'Avatar' back to the real name for display ---
			var display_partner_name := partner_name
			if partner_name == "Avatar":
				for p_unit in player_container.get_children():
					if p_unit.get("is_custom_avatar") == true:
						display_partner_name = p_unit.unit_name
						break
			var bond = CampaignManager.get_support_bond(u_name, partner_name)
			var pts = bond["points"]
			var rank_color = "gray"
			var rank_letter = "None"
			var next_goal = 10 # Default points for C rank
			
			if bond["rank"] == 1: 
				rank_letter = "C"
				rank_color = "cyan"
				next_goal = 25
			elif bond["rank"] == 2: 
				rank_letter = "B"
				rank_color = "lime"
				next_goal = 45
			elif bond["rank"] == 3: 
				rank_letter = "A (MAX)"
				rank_color = "gold"
				
			# Build the visual row using the TRANSLATED name
			if bond["rank"] < 3:
				display_text += display_partner_name + "  -  Rank [color=" + rank_color + "]" + rank_letter + "[/color]  [color=gray](" + str(pts) + "/" + str(next_goal) + " pts)[/color]\n"
			else:
				display_text += display_partner_name + "  -  [color=gold]Rank A (MAX)[/color]\n"
				
	if not found_any_friends:
		display_text += "[center][color=gray]No bonds formed yet.\nFight adjacent to allies to grow closer![/color][/center]"
		
	# 3. Show the UI
	support_list_text.text = display_text
	support_tracker_panel.visible = true

func execute_promotion(unit: Node2D, advanced_class: Resource) -> void:
	# 0. Lock input during the sequence
	set_process_input(false)
	var vp_size = get_viewport_rect().size
	
	# --- 1. DATA PREPARATION ---
	var old_class_name = unit.unit_class_name
	var new_class_name = advanced_class.get("job_name") if advanced_class.get("job_name") != null else "Advanced Class"
	
	var old_sprite_tex = unit.data.unit_sprite
	var new_sprite_tex = advanced_class.get("promoted_battle_sprite")
	var new_portrait_tex = advanced_class.get("promoted_portrait")
	
	# --- 2. BUILD THE CINEMATIC UI LAYER ---
	var promo_layer = CanvasLayer.new()
	promo_layer.layer = 150 
	add_child(promo_layer)
	
	# MASTER CONTROL
	var master_control = Control.new()
	master_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	promo_layer.add_child(master_control)
	
	# Dark dramatic background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.9)
	bg.modulate.a = 0.0 
	master_control.add_child(bg)
	
	# CENTER CONTAINER
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	master_control.add_child(center_container)
	
	# VBox to stack sprite and text
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_container.add_child(vbox)
	
	# The Giant Sprite
	var big_sprite = TextureRect.new()
	big_sprite.texture = old_sprite_tex
	big_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	big_sprite.custom_minimum_size = Vector2(200, 200) 
	big_sprite.pivot_offset = big_sprite.custom_minimum_size / 2.0
	vbox.add_child(big_sprite)
	
	# --- NEW: THE GLOWING AURA SPRITE ---
	var aura_sprite = TextureRect.new()
	aura_sprite.texture = old_sprite_tex
	aura_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	aura_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Anchor it to the parent
	aura_sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# THE FIX: Explicitly set the pivot point back to the center!
	# Since big_sprite is 200x200, the dead center is 100,100
	aura_sprite.pivot_offset = Vector2(100, 100)
	
	# Set it behind the main sprite, make it orange, and start invisible
	aura_sprite.show_behind_parent = true
	aura_sprite.modulate = Color(1.0, 0.4, 0.0, 0.0) # Vivid Orange, 0 Alpha
	big_sprite.add_child(aura_sprite)
	
	# The Name & Class Text 
	var info_label = RichTextLabel.new()
	info_label.bbcode_enabled = true
	info_label.fit_content = true
	info_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	info_label.custom_minimum_size = Vector2(300, 60)
	info_label.text = "[center]" + unit.unit_name + "\n" + old_class_name + "[/center]"
	vbox.add_child(info_label)
	
	# The Blinding Flash Overlay
	var flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color.WHITE
	flash_rect.modulate.a = 0.0
	master_control.add_child(flash_rect)

	# Particles Setup
	var buildup_vfx = _create_evolution_buildup_vfx(vp_size / 2.0)
	var burst_vfx = _create_evolution_burst_vfx(vp_size / 2.0)
	buildup_vfx.reparent(master_control)
	burst_vfx.reparent(master_control)
	buildup_vfx.position = vp_size / 2.0
	burst_vfx.position = vp_size / 2.0

	# --- AUDIO SETUP ---
	var audio_player = null
	if promotion_sound != null:
		audio_player = AudioStreamPlayer.new()
		audio_player.stream = promotion_sound
		audio_player.pitch_scale = randf_range(0.95, 1.05) 
		master_control.add_child(audio_player)

	# --- 3. THE CINEMATIC TWEEN SEQUENCE ---
	var tween = create_tween()

	# STAGE 0: Enter the Void
	tween.tween_property(bg, "modulate:a", 1.0, 0.5)
	tween.tween_interval(0.5)

	# STAGE 1: BUILDUP
	tween.chain().set_parallel(true)
	tween.tween_property(big_sprite, "modulate", Color(10, 10, 10, 1), 2.0).set_ease(Tween.EASE_IN) 
	tween.tween_method(func(val): 
		big_sprite.position = Vector2(randf_range(-val, val), randf_range(-val, val))
	, 2.0, 15.0, 2.0)
	
	# STAGE 2: THE FLASH & DATA SWAP
	tween.chain().tween_callback(func():
		UnitTraitsLib.grant_rookie_legacy_on_promotion(unit, old_class_name)
		UnitTraitsLib.grant_tier_class_legacy_on_promotion(unit, old_class_name, advanced_class)

		var gains = {
			"hp": advanced_class.get("promo_hp_bonus") if advanced_class.get("promo_hp_bonus") != null else 0,
			"str": advanced_class.get("promo_str_bonus") if advanced_class.get("promo_str_bonus") != null else 0,
			"mag": advanced_class.get("promo_mag_bonus") if advanced_class.get("promo_mag_bonus") != null else 0,
			"def": advanced_class.get("promo_def_bonus") if advanced_class.get("promo_def_bonus") != null else 0,
			"res": advanced_class.get("promo_res_bonus") if advanced_class.get("promo_res_bonus") != null else 0,
			"spd": advanced_class.get("promo_spd_bonus") if advanced_class.get("promo_spd_bonus") != null else 0,
			"agi": advanced_class.get("promo_agi_bonus") if advanced_class.get("promo_agi_bonus") != null else 0
		}
		
		unit.active_class_data = advanced_class
		unit.unit_class_name = new_class_name
		unit.level = 1
		unit.experience = 0
		if advanced_class.get("move_range") != null: unit.move_range = advanced_class.move_range
		if advanced_class.get("move_type") != null: unit.set("move_type", advanced_class.move_type)

		apply_stat_gains(unit, gains)
		
		# --- FLAG AS PROMOTED AND IGNITE AURA ---
		unit.set("is_promoted", true)
		if unit.has_method("apply_promotion_aura"):
			unit.apply_promotion_aura()
			
		if new_sprite_tex != null:
			big_sprite.texture = new_sprite_tex
			aura_sprite.texture = new_sprite_tex # Update the aura's texture too!
			
			if unit.get("data") != null: unit.data.unit_sprite = new_sprite_tex 
			var map_sprite = unit.get_node_or_null("Sprite")
			if map_sprite: map_sprite.texture = new_sprite_tex
			
			# The Silhouette Setup
			big_sprite.modulate = Color.BLACK
			big_sprite.scale = Vector2(1.15, 1.15) 
			
		if new_portrait_tex != null and unit.get("data") != null:
			unit.data.portrait = new_portrait_tex

		info_label.text = "[center]" + unit.unit_name + "\n[color=gold]" + new_class_name.to_upper() + "[/color][/center]"
		unit.set_meta("promo_gains_temp", gains) 
	)
	
	# The instant blinding flash
	tween.tween_property(flash_rect, "modulate:a", 1.0, 0.1).set_ease(Tween.EASE_IN)

	# STAGE 3: THE REVEAL (The Slow Fade)
	tween.chain().set_parallel(true)
	tween.tween_property(flash_rect, "modulate:a", 0.0, 2.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(big_sprite, "modulate", Color.WHITE, 2.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(big_sprite, "scale", Vector2(1.0, 1.0), 2.5).set_ease(Tween.EASE_OUT)
	
	# Fade in the Orange Aura
	tween.tween_property(aura_sprite, "modulate:a", 0.8, 1.0).set_ease(Tween.EASE_OUT)
	
	tween.parallel().tween_callback(func(): 
		big_sprite.position = Vector2.ZERO 
		buildup_vfx.emitting = false 
		burst_vfx.restart() 
		
		if audio_player != null:
			audio_player.play()
			
		screen_shake(20.0, 0.5)
		
		# --- START THE PULSATING AURA LOOP ---
		# We bind this tween to big_sprite so it automatically dies when the UI closes
		var pulse_tween = big_sprite.create_tween().set_loops()
		pulse_tween.tween_property(aura_sprite, "scale", Vector2(1.2, 1.2), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse_tween.tween_property(aura_sprite, "scale", Vector2(1.05, 1.05), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	)
	
	# STAGE 4: EXIT
	tween.chain().tween_interval(2.5) # Wait an extra second to admire the glow
	tween.chain().tween_property(master_control, "modulate:a", 0.0, 0.5)
	
	tween.chain().tween_callback(func():
		promo_layer.queue_free() 
		set_process_input(true)
		
		var title_text = "CLASS CHANGE: " + unit.unit_class_name.to_upper()
		await run_theatrical_stat_reveal(unit, title_text, unit.get_meta("promo_gains_temp"))
		update_unit_info_panel()
	)
	
# ==========================================
# BRANCHING PROMOTION UI
# ==========================================
func _ask_for_promotion_choice(options: Array) -> Resource:
	var promo_layer = CanvasLayer.new()
	promo_layer.layer = 110 # Keep it on top of everything
	add_child(promo_layer)

	var vp_size = get_viewport_rect().size
	
	# Dim the background
	var dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.85)
	dimmer.size = vp_size
	promo_layer.add_child(dimmer)
	
	var title = Label.new()
	title.text = "CHOOSE YOUR PATH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 80)
	title.add_theme_color_override("font_color", Color.GOLD)
	title.position = Vector2(0, 80)
	title.size.x = vp_size.x
	promo_layer.add_child(title)
	
	# The container holding the class cards
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 60)
	hbox.size = Vector2(vp_size.x, 600)
	hbox.position = Vector2(0, 200)
	promo_layer.add_child(hbox)
	
	# Build a card for each option in the array
	for class_res in options:
		if class_res == null: continue
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(450, 650) 
		
		# Set pivot to the center for smooth scaling!
		btn.pivot_offset = btn.custom_minimum_size / 2.0
		
		var vbox = VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
		vbox.add_theme_constant_override("separation", 15)
		# Tell the VBox to ignore the parent's scale so it doesn't double-scale the text weirdly
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE 
		btn.add_child(vbox)
		
		var c_name = Label.new()
		c_name.text = class_res.get("job_name") if class_res.get("job_name") else "Unknown"
		c_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c_name.add_theme_font_size_override("font_size", 56) 
		c_name.add_theme_color_override("font_color", Color.CYAN)
		vbox.add_child(c_name)
		
		var sep = HSeparator.new()
		vbox.add_child(sep)
		
		var stats = Label.new()
		var m_range = str(class_res.get("move_range")) if class_res.get("move_range") != null else "N/A"
		stats.text = "\n[ MOVE: " + m_range + " ]\n\n"
		
		# Safely extract stats 
		var p_hp = class_res.get("promo_hp_bonus") if class_res.get("promo_hp_bonus") != null else 0
		var p_str = class_res.get("promo_str_bonus") if class_res.get("promo_str_bonus") != null else 0
		var p_mag = class_res.get("promo_mag_bonus") if class_res.get("promo_mag_bonus") != null else 0
		var p_def = class_res.get("promo_def_bonus") if class_res.get("promo_def_bonus") != null else 0
		var p_res = class_res.get("promo_res_bonus") if class_res.get("promo_res_bonus") != null else 0
		var p_spd = class_res.get("promo_spd_bonus") if class_res.get("promo_spd_bonus") != null else 0
		var p_agi = class_res.get("promo_agi_bonus") if class_res.get("promo_agi_bonus") != null else 0
		
		# Format stat bonuses dynamically
		stats.text += "HP:  +" + str(p_hp) + "    STR: +" + str(p_str) + "\n"
		stats.text += "MAG: +" + str(p_mag) + "    DEF: +" + str(p_def) + "\n"
		stats.text += "RES: +" + str(p_res) + "    SPD: +" + str(p_spd) + "\n"
		stats.text += "AGI: +" + str(p_agi) + "\n"
		
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.add_theme_font_size_override("font_size", 32) 
		vbox.add_child(stats)
		
		var weapons_label = RichTextLabel.new()
		weapons_label.bbcode_enabled = true
		weapons_label.fit_content = true
		weapons_label.scroll_active = false
		weapons_label.custom_minimum_size = Vector2(0, 120)
		weapons_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		weapons_label.bbcode_text = "[center][color=gold]" + _format_class_weapon_permissions(class_res) + "[/color][/center]"
		vbox.add_child(weapons_label)
		
		var new_sprite_tex = class_res.get("promoted_battle_sprite")
		if new_sprite_tex != null:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 20)
			vbox.add_child(spacer)
			
			var icon_rect = TextureRect.new()
			icon_rect.texture = new_sprite_tex
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.custom_minimum_size = Vector2(160, 160)
			icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			vbox.add_child(icon_rect)
		
		# --- NEW: HOVER EFFECTS ---
		btn.mouse_entered.connect(func():
			var tween = create_tween().set_parallel(true)
			# Pop the scale up slightly
			tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)
			# Shift to a glowing, warm golden tint
			tween.tween_property(btn, "modulate", Color(1.2, 1.15, 1.0), 0.1)
			
			# Optional: If you want a tick sound on hover, uncomment this!
			# if select_sound and select_sound.stream: select_sound.play()
		)
		
		btn.mouse_exited.connect(func():
			var tween = create_tween().set_parallel(true)
			# Return to normal
			tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
			tween.tween_property(btn, "modulate", Color.WHITE, 0.1)
		)
		
		# Hook up the button click
		btn.pressed.connect(func():
			if select_sound and select_sound.stream: select_sound.play()
			emit_signal("promotion_chosen", class_res)
		)
		hbox.add_child(btn)

	# Cancel button at the bottom
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.add_theme_font_size_override("font_size", 36)
	cancel_btn.custom_minimum_size = Vector2(300, 80)
	cancel_btn.pivot_offset = cancel_btn.custom_minimum_size / 2.0
	cancel_btn.position = Vector2((vp_size.x - 300)/2, vp_size.y - 120)
	
	# Cancel button hover effect (subtle red tint)
	cancel_btn.mouse_entered.connect(func():
		var tween = create_tween().set_parallel(true)
		tween.tween_property(cancel_btn, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)
		tween.tween_property(cancel_btn, "modulate", Color(1.2, 0.9, 0.9), 0.1)
	)
	cancel_btn.mouse_exited.connect(func():
		var tween = create_tween().set_parallel(true)
		tween.tween_property(cancel_btn, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)
		tween.tween_property(cancel_btn, "modulate", Color.WHITE, 0.1)
	)
	
	cancel_btn.pressed.connect(func():
		if select_sound and select_sound.stream: select_sound.play()
		emit_signal("promotion_chosen", null)
	)
	promo_layer.add_child(cancel_btn)

	# Wait for the player to click a card or Cancel
	var final_choice = await self.promotion_chosen
	
	# Destroy the UI once a choice is made
	promo_layer.queue_free()
	
	return final_choice
	
# ==========================================
# --- NEW VFX HELPER FUNCTIONS ---
# ==========================================

# Creates rising energy particles (The Buildup)
func _create_evolution_buildup_vfx(target_pos: Vector2) -> CPUParticles2D:
	var vfx = CPUParticles2D.new()
	add_child(vfx)
	vfx.global_position = target_pos
	vfx.amount = 50
	vfx.lifetime = 1.5
	vfx.preprocess = 0.5 # Start already looking full
	vfx.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	vfx.emission_sphere_radius = 20.0
	vfx.gravity = Vector2(0, -98) # Float upwards
	vfx.direction = Vector2(0, -1)
	vfx.spread = 20.0
	vfx.initial_velocity_min = 30.0
	vfx.initial_velocity_max = 60.0
	# Start small and yellow, end big and transparent orange
	vfx.scale_amount_min = 2.0
	vfx.scale_amount_max = 5.0
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 0.8, 0.2, 1)) # Yellow
	gradient.set_color(1, Color(1, 0.4, 0, 0))   # Fade to Orange transparent
	vfx.color_ramp = gradient
	return vfx

# Creates an outward burst of particles (The Reveal)
func _create_evolution_burst_vfx(target_pos: Vector2) -> CPUParticles2D:
	var vfx = CPUParticles2D.new()
	add_child(vfx)
	vfx.global_position = target_pos
	vfx.emitting = false
	vfx.one_shot = true
	
	# --- 1. TRIPLE THE PARTICLES ---
	vfx.amount = 300 
	vfx.lifetime = 1.5 # Give them time to fly off screen before dying
	vfx.explosiveness = 1.0 # All at once
	vfx.direction = Vector2(0, -1)
	vfx.spread = 180.0 # Full circle burst
	vfx.gravity = Vector2(0, 0)
	
	# --- 2. MASSIVE VELOCITY (Blasts off the screen!) ---
	vfx.initial_velocity_min = 800.0
	vfx.initial_velocity_max = 1600.0 
	
	# --- 3. HUGE PARTICLES ---
	vfx.scale_amount_min = 8.0
	vfx.scale_amount_max = 25.0 
	
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1)) # White hot center
	gradient.set_color(1, Color(1, 0.7, 0, 0)) # Fade to rich gold transparent
	vfx.color_ramp = gradient
	
	return vfx
	
func _on_start_battle_pressed() -> void:
	if select_sound.stream != null: select_sound.play()
	# Phase 2: ensure Defy Death tracking is reset when battle starts (in case scene was reused without reload).
	_defy_death_used.clear()
	_grief_units.clear()
	_relationship_event_awarded.clear()
	_enemy_damagers.clear()
	# Boss Personal Dialogue: ensure one-time pre-attack tracking is reset when battle starts.
	_boss_personal_dialogue_played.clear()
	_reset_rookie_battle_tracking()
	change_state(player_state) # Officially starts Turn 1!

# ==========================================
# --- OBJECTIVE UI SYSTEM ---
# ==========================================
var objective_panel: Panel
var objective_label: RichTextLabel
var objective_toggle_btn: Button
var is_objective_expanded: bool = true

func _setup_objective_ui() -> void:
	var vp_size = get_viewport_rect().size
	
	# 1. THE TOGGLE BUTTON (Foundation for a Quest Log)
	objective_toggle_btn = Button.new()
	objective_toggle_btn.name = "ObjectiveToggleBtn"
	objective_toggle_btn.text = "Hide Goals"
	objective_toggle_btn.add_theme_font_size_override("font_size", 20)
	objective_toggle_btn.size = Vector2(140, 40)
	objective_toggle_btn.position = Vector2(vp_size.x - 160, 20)
	objective_toggle_btn.pressed.connect(_on_objective_toggle_pressed)
	
	# Style the button so it matches the UI
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.8, 0.6, 0.2, 0.8)
	objective_toggle_btn.add_theme_stylebox_override("normal", btn_style)
	$UI.add_child(objective_toggle_btn)

	# 2. THE BACKGROUND BOX (Goldilocks size: 400x120)
	objective_panel = Panel.new()
	objective_panel.name = "ObjectivePanel"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.8, 0.6, 0.2, 0.8) 
	objective_panel.add_theme_stylebox_override("panel", style)
	
	objective_panel.size = Vector2(400, 120)
	objective_panel.position = Vector2(vp_size.x - 420, 70) # Sits just below the toggle button
	objective_panel.pivot_offset = objective_panel.size / 2.0 
	
	# 3. THE TEXT LABEL (Medium fonts)
	objective_label = RichTextLabel.new()
	objective_label.bbcode_enabled = true
	objective_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	objective_label.add_theme_font_size_override("normal_font_size", 22)
	objective_label.add_theme_font_size_override("bold_font_size", 26)
	
	objective_panel.add_child(objective_label)
	$UI.add_child(objective_panel)
	
	update_objective_ui(true) # Pass true so it doesn't do the bounce animation right when the level loads

func _on_objective_toggle_pressed() -> void:
	is_objective_expanded = !is_objective_expanded
	var vp_size = get_viewport_rect().size
	
	# Slide target: When hidden, shove it completely off the right side of the screen
	var target_x = vp_size.x - 420 if is_objective_expanded else vp_size.x + 50
	
	var tween = create_tween()
	tween.tween_property(objective_panel, "position:x", target_x, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	
	objective_toggle_btn.text = "Hide Goals" if is_objective_expanded else "Show Goals"
	if select_sound and select_sound.stream: select_sound.play()

func update_objective_ui(skip_animation: bool = false) -> void:
	if objective_label == null: return
	
	var txt = "[center][b][color=gold]--- CURRENT OBJECTIVE ---[/color][/b]\n"
	
	match map_objective:
		Objective.ROUT_ENEMY:
			var e_count = 0
			if enemy_container:
				for e in enemy_container.get_children():
					if not e.is_queued_for_deletion() and e.current_hp > 0: e_count += 1
			
			var spawner_count = 0
			if destructibles_container:
				for d in destructibles_container.get_children():
					if d.has_method("process_turn") and d.get("spawner_faction") == 0 and not d.is_queued_for_deletion():
						spawner_count += 1
			
			var instruction = custom_objective_text if custom_objective_text != "" else "Defeat all enemies!"
			
			if spawner_count > 0:
				txt += instruction + "\n[color=gray](Remaining: " + str(e_count) + " + " + str(spawner_count) + " Spawners)[/color]"
			else:
				txt += instruction + "\n[color=gray](Remaining: " + str(e_count) + ")[/color]"
				
		Objective.SURVIVE_TURNS:
			var instruction = custom_objective_text if custom_objective_text != "" else "Survive the assault!"
			txt += instruction + "\n[color=cyan]Turn: " + str(current_turn) + " / " + str(turn_limit) + "[/color]"
			
		Objective.DEFEND_TARGET:
			var vip_name = "Target"
			var vip_hp_str = "?/?"
			var hp_color = "white"
			
			if is_instance_valid(vip_target) and not vip_target.is_queued_for_deletion():
				vip_name = vip_target.get("unit_name") if vip_target.get("unit_name") != null else "VIP"
				var chp = vip_target.get("current_hp")
				var mhp = vip_target.get("max_hp")
				
				if chp != null and mhp != null:
					vip_hp_str = str(chp) + "/" + str(mhp)
					var ratio = float(chp) / float(mhp)
					if ratio <= 0.3: hp_color = "red"
					elif ratio <= 0.6: hp_color = "yellow"
					else: hp_color = "lime"
						
			var instruction = custom_objective_text if custom_objective_text != "" else "Escort " + vip_name + " to the exit!"
			txt += instruction + " (Turn " + str(current_turn) + "/" + str(turn_limit) + ")\n"
			txt += "[color=gray]Convoy Status: [/color][color=" + hp_color + "]" + vip_hp_str + "[/color]"

	# ==========================================
	# --- NEW: LIVE BOUNTY TRACKER ---
	# ==========================================
	var target_height = 120 # Default panel height
	
	if CampaignManager.merchant_quest_active:
		target_height = 190 # Expand the panel to fit the side quest text
		
		var target_item = CampaignManager.merchant_quest_item_name
		var target_amt = CampaignManager.merchant_quest_target_amount
		var current_amt = 0
		
		# 1. Check the Global Convoy
		for item in player_inventory:
			var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
			if i_name == target_item: current_amt += 1
				
		# 2. Check personal pockets (in case they just picked it up!)
		if player_container:
			for unit in player_container.get_children():
				if "inventory" in unit:
					for item in unit.inventory:
						if item != null:
							var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
							if i_name == target_item: current_amt += 1
							
		# 3. Format the UI Text
		txt += "\n\n[b][color=orange]--- BOUNTY ---[/color][/b]\n"
		if current_amt >= target_amt:
			txt += "[color=lime]" + target_item + ": " + str(current_amt) + " / " + str(target_amt) + " (Ready!)[/color]"
		else:
			txt += "[color=gray]" + target_item + ": " + str(current_amt) + " / " + str(target_amt) + "[/color]"

	txt += _build_mock_coop_player_phase_readiness_bbcode_suffix()
	txt += "\n[color=gray][font_size=15]Shift: enemy threat · Side panel: goals[/font_size][/color]\n[/center]"
	
	# Dynamically resize the panel based on whether a quest is active
	if objective_panel.size.y != target_height:
		create_tween().tween_property(objective_panel, "size:y", target_height, 0.3).set_trans(Tween.TRANS_BACK)
	
	# --- NORMAL TEXT UPDATE ---
	if objective_label.text != txt:
		objective_label.text = txt
		
		if not skip_animation and is_objective_expanded:
			objective_panel.scale = Vector2(1.10, 1.10)
			objective_panel.modulate = Color(1.5, 1.5, 1.5, 1.0)
			
			var tween = create_tween().set_parallel(true)
			tween.tween_property(objective_panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(objective_panel, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_SINE)
			
			if select_sound and select_sound.stream != null:
				var tick_player = AudioStreamPlayer.new()
				tick_player.stream = select_sound.stream
				tick_player.pitch_scale = 1.6
				tick_player.volume_db = -5.0
				add_child(tick_player)
				tick_player.play()
				tick_player.finished.connect(tick_player.queue_free)
				
# ==========================================
# --- EPIC VFX SPAWNERS ---
# ==========================================
func spawn_dash_effect(start_pos: Vector2, target_pos: Vector2) -> void:
	if dash_fx_scene == null: 
		print("WARNING: Dash FX Scene is missing! Assign it in the Battlefield Inspector!")
		return
	
	var fx = dash_fx_scene.instantiate()
	add_child(fx)
	
	fx.z_index = 100 
	
	# Position exactly at the unit's feet
	fx.global_position = start_pos + Vector2(32, 60)
	
	# --- FIX: NO ROTATION! ---
	# We force rotation to 0 so the dust never looks like it's falling sideways.
	fx.rotation = 0 
	
	# --- FIX: SMART HORIZONTAL FLIPPING ---
	var move_dir_x = target_pos.x - start_pos.x
	
	if move_dir_x > 0:
		# Moving RIGHT: Inverted for your specific sprite sheet
		fx.flip_h = false 
	elif move_dir_x < 0:
		# Moving LEFT: Inverted for your specific sprite sheet
		fx.flip_h = true
	else:
		# Moving purely UP or DOWN: 
		# Randomly flip it horizontally so it doesn't look identical every time!
		fx.flip_h = randf() > 0.5
		
	fx.scale = Vector2(randf_range(1.0, 1.3), randf_range(0.8, 1.2))

func spawn_slash_effect(target_pos: Vector2, attacker_pos: Vector2, is_crit: bool = false) -> void:
	if slash_fx_scene == null: 
		print("WARNING: Slash FX Scene is missing! Assign it in the Battlefield Inspector!")
		return
	
	var fx = slash_fx_scene.instantiate()
	add_child(fx)
	
	fx.z_index = 110 # Make sure it draws above the units!
	
	# Center it on the defender's chest
	fx.global_position = target_pos + Vector2(32, 32)
	
	# Point the slash so it cuts FROM the attacker TO the defender
	var dir = (target_pos - attacker_pos).normalized()
	
	# Add a tiny bit of random angle so combo hits don't look perfectly identical
	fx.rotation = dir.angle() + randf_range(-0.3, 0.3)
	
	# Randomly flip the "blade" orientation
	if randf() > 0.5:
		fx.flip_v = true
		
	# --- THE JUICE: MAKE CRITS ENORMOUS ---
	if is_crit:
		fx.scale = Vector2(2.5, 2.5)
		fx.modulate = Color(1.5, 1.2, 1.2, 1.0) # Over-brighten it
	else:
		fx.scale = Vector2(1.3, 1.3)

func spawn_level_up_effect(target_pos: Vector2) -> void:
	if level_up_fx_scene == null: 
		print("WARNING: Level Up FX Scene is missing! Assign it in the Battlefield Inspector!")
		return
	
	var fx = level_up_fx_scene.instantiate()
	add_child(fx)
	
	fx.z_index = 110 # Draw above units
	
	# CRITICAL: Force the code to also ignore the pause state just in case!
	fx.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Position it at the unit's feet. 
	# (Adjust the Y value if the beam needs to go higher/lower based on your sprite sheet cuts)
	fx.global_position = target_pos + Vector2(32, 48)
	
	# Make it large enough to encompass the whole unit!
	fx.scale = Vector2(3.0, 3.0)


func spawn_blood_splatter(target_unit: Node2D, attacker_pos: Vector2, is_crit: bool = false) -> void:
	var target_name = target_unit.get("unit_name")
	if target_name == null: return
	
	# 1. THE LOGIC CHECK: Remove "Skeleton" from this list if you want them to bleed!
	var no_blood_types = ["Wooden Crate", "Spawner Tent", "Portable Fort", "Skeleton", "Risen Dead"]
	if no_blood_types.has(target_name):
		return 

	var blood = CPUParticles2D.new()
	add_child(blood)
	
	blood.z_index = 105
	blood.global_position = target_unit.global_position + Vector2(32, 32)
	blood.emitting = false
	blood.one_shot = true
	
	# ==========================================
	# --- 2. THE BURST UPGRADE ---
	# ==========================================
	# 1.0 means ALL particles spawn instantly on the exact same frame!
	blood.explosiveness = 1.0 
	
	# Increased the amount of droplets for a thicker spray
	blood.amount = 60 if is_crit else 25 
	
	var dir = (target_unit.global_position - attacker_pos).normalized()
	blood.direction = dir
	
	# Widened from 35 to 75 so it sprays out in a wide, violent fan
	blood.spread = 75.0 
	
	# Heavier gravity and much faster velocity so it whips out and drops fast
	blood.gravity = Vector2(0, 800) 
	blood.initial_velocity_min = 250.0
	blood.initial_velocity_max = 550.0 if is_crit else 350.0
	
	blood.scale_amount_min = 3.0
	blood.scale_amount_max = 7.0
	
	# --- NEW: SHRINK OVER TIME ---
	# This makes the droplets shrink as they fly, making it look like real liquid dispersing!
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1)) # Start at 100% size
	curve.add_point(Vector2(1, 0)) # End at 0% size
	blood.scale_amount_curve = curve
	
	# Brighter crimson color so it pops against the dark backgrounds
	blood.color = Color(0.8, 0.0, 0.0, 1.0)
	
	blood.restart()
	get_tree().create_timer(1.5, true, false, true).timeout.connect(blood.queue_free)

# ==========================================
# --- LEVEL INTRO CINEMATICS ---
# ==========================================
func _start_intro_sequence() -> void:
	if is_arena_match:
		await _play_arena_vs_screen() # Dramatic entry!
		# Only play story dialogue if we are NOT in a Skirmish map, AND if you actually added dialogue in the Inspector!
	if not CampaignManager.is_skirmish_mode and intro_dialogue.size() > 0:
		
		# Find Kaelen so we can steal his dynamic name and portrait if needed
		var avatar_node = null
		for u in player_container.get_children():
			if u.get("is_custom_avatar") == true:
				avatar_node = u
				break
		
		# Loop through every Dialogue Block you set up in the Inspector!
		for block in intro_dialogue:
			if block.lines.is_empty(): continue # Skip empty blocks
			
			var final_name = block.speaker_name
			var final_portrait = block.portrait
			
			# --- THE MAGIC AVATAR TRICK ---
			# If you type "Avatar" as the speaker name in the Inspector, 
			# the game automatically grabs Kaelen's real name and portrait for you!
			if final_name.to_lower() == "avatar" and avatar_node != null:
				final_name = avatar_node.unit_name
				if final_portrait == null and avatar_node.data != null:
					final_portrait = avatar_node.data.portrait
			
			# Format the text to replace {Avatar} with his actual name!
			var formatted_lines: Array = []
			for line in block.lines:
				var f_line = line
				if avatar_node != null:
					f_line = f_line.replace("{Avatar}", avatar_node.unit_name)
				formatted_lines.append(f_line)
				
			# Play this block, and wait for the player to click through it before loading the next one
			await play_cinematic_dialogue(final_name, final_portrait, formatted_lines)

	# Once all the dialogue finishes (or is skipped), begin the Deployment Phase!
	change_state(pre_battle_state)
	
func play_cinematic_dialogue(speaker_name: String, portrait_tex: Texture2D, lines: Array) -> void:
	# 1. Freeze the game so nothing moves in the background
	get_tree().paused = true
	var vp_size = get_viewport_rect().size
	
	# ==========================================
	# --- FIX: ROBUST NAME MATCHING & CAMERA WAKEUP ---
	# ==========================================
	# Force the camera to stay awake while the game is paused!
	main_camera.process_mode = Node.PROCESS_MODE_ALWAYS 
	
	var target_unit: Node2D = null
	var all_units = player_container.get_children()
	if ally_container: all_units += ally_container.get_children()
	if enemy_container: all_units += enemy_container.get_children()
	
	var s_name_lower = speaker_name.to_lower()
	
	# Find the speaker on the board
	for u in all_units:
		if not is_instance_valid(u): continue
		
		# Check both the custom RPG name and the internal Node name
		var u_name = ""
		if u.get("unit_name") != null:
			u_name = str(u.get("unit_name")).to_lower()
			
		var node_name = u.name.to_lower()
		
		# Smarter check: Matches "Malakor" even if the node is called "EnemyUnit"
		if u_name == s_name_lower or s_name_lower in u_name or s_name_lower in node_name:
			target_unit = u
			break
			
	# Fallback for Bartholomew! (Point the camera at the Donkey Cart)
	if target_unit == null and "bartholomew" in s_name_lower and is_instance_valid(vip_target):
		target_unit = vip_target
		
	var highlight: ColorRect = null
	if target_unit != null:
		# Pan Camera to the speaker
		var target_cam_pos = target_unit.global_position + Vector2(32, 32)
		if main_camera.anchor_mode == Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT:
			target_cam_pos -= (vp_size * 0.5) / main_camera.zoom
			
		var cam_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		cam_tw.tween_property(main_camera, "global_position", target_cam_pos, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		# Flash their tile (Red for enemies, Blue for players, Green for Allies)
		highlight = ColorRect.new()
		highlight.size = Vector2(64, 64)
		highlight.position = target_unit.global_position
		highlight.z_index = 50 # <-- FIX: Make sure it draws ABOVE the map tiles!
		
		if target_unit.get_parent() == enemy_container: 
			highlight.color = Color(1.0, 0.2, 0.2)
		elif target_unit.get_parent() == ally_container: 
			highlight.color = Color(0.2, 1.0, 0.2)
		else: 
			highlight.color = Color(0.2, 0.6, 1.0)
			
		highlight.modulate.a = 0.0
		highlight.process_mode = Node.PROCESS_MODE_ALWAYS # Run while paused
		add_child(highlight)
		
		# Make it pulse!
		# --- THE FIX: Attach the tween directly to the highlight node! ---
		var hl_tw = highlight.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_loops()
		hl_tw.tween_property(highlight, "modulate:a", 0.6, 0.5).set_trans(Tween.TRANS_SINE)
		hl_tw.tween_property(highlight, "modulate:a", 0.1, 0.5).set_trans(Tween.TRANS_SINE)
	# ==========================================

	# 2. Setup the Canvas Layer
	var cine_layer = CanvasLayer.new()
	cine_layer.layer = 120 # Put it above everything!
	cine_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cine_layer)
	
	# Background Dimmer (Lightened to 0.4 so you can clearly see the map behind the dialogue!)
	var dimmer = ColorRect.new()
	dimmer.size = vp_size
	dimmer.color = Color(0, 0, 0, 0.4)
	dimmer.modulate.a = 0.0
	cine_layer.add_child(dimmer)
	
	# The Giant Portrait
	var portrait = TextureRect.new()
	portrait.texture = portrait_tex
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(500, 500) # Make it huge!
	portrait.position = Vector2(-200, vp_size.y - 650)
	portrait.modulate.a = 0.0
	cine_layer.add_child(portrait)
	
	# The Dialogue Box
	var box_h = 220.0
	var box = ColorRect.new()
	box.color = Color(0.05, 0.05, 0.05, 0.95)
	box.size = Vector2(vp_size.x, box_h)
	box.position = Vector2(0, vp_size.y) # Start off-screen at the bottom
	cine_layer.add_child(box)
	
	var border = ColorRect.new()
	border.color = Color(0.8, 0.6, 0.2) # Gold border
	border.size = Vector2(vp_size.x, 4)
	box.add_child(border)
	
	var name_lbl = Label.new()
	name_lbl.text = speaker_name
	name_lbl.add_theme_font_size_override("font_size", 42)
	name_lbl.add_theme_color_override("font_color", Color.CYAN)
	name_lbl.position = Vector2(400, 20) # Push text right to make room for portrait
	box.add_child(name_lbl)
	
	var text_lbl = RichTextLabel.new()
	text_lbl.bbcode_enabled = true
	text_lbl.size = Vector2(vp_size.x - 450, 100)
	text_lbl.position = Vector2(400, 80)
	box.add_child(text_lbl)
	
	# Invisible Full-Screen Button to catch clicks to advance text
	var click_catcher = Button.new()
	click_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_catcher.flat = true
	click_catcher.pressed.connect(func(): emit_signal("dialogue_advanced"))
	cine_layer.add_child(click_catcher)
	
	# The Skip Button
	var skip_flag = [false]
	var skip_btn = Button.new()
	skip_btn.text = "Skip >>"
	skip_btn.add_theme_font_size_override("font_size", 24)
	skip_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	skip_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	skip_btn.flat = true
	skip_btn.position = Vector2(vp_size.x - 120, 20)
	skip_btn.pressed.connect(func():
		skip_flag[0] = true
		emit_signal("dialogue_advanced") 
	)
	cine_layer.add_child(skip_btn)
	
	# 3. Animate Everything In
	var intro_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	intro_tw.tween_property(dimmer, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(portrait, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(portrait, "position:x", 50.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(box, "position:y", vp_size.y - box_h, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await intro_tw.finished
	
	# 4. Loop through the Dialogue Lines
	for line in lines:
		if skip_flag[0]: break 
		
		text_lbl.text = "[font_size=36]" + line + "[/font_size]"
		text_lbl.visible_ratio = 0.0
		
		if select_sound and select_sound.stream != null:
			select_sound.pitch_scale = 0.9
			select_sound.play()
			
		var type_speed = line.length() * 0.025
		var type_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		type_tw.tween_property(text_lbl, "visible_ratio", 1.0, type_speed)
		
		await self.dialogue_advanced
		if skip_flag[0]: 
			type_tw.kill()
			break
		
		# If they clicked while typing, skip to the end of the line
		if type_tw.is_running():
			type_tw.kill()
			text_lbl.visible_ratio = 1.0
			await self.dialogue_advanced
			if skip_flag[0]: break
			
		if select_sound and select_sound.stream != null:
			select_sound.pitch_scale = 1.1
			select_sound.play()
			
	# 5. Animate Everything Out
	skip_btn.visible = false 
	var outro_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	outro_tw.tween_property(dimmer, "modulate:a", 0.0, 0.3)
	outro_tw.tween_property(portrait, "modulate:a", 0.0, 0.3)
	outro_tw.tween_property(portrait, "position:x", -200.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	outro_tw.tween_property(box, "position:y", vp_size.y, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await outro_tw.finished
	
	# ==========================================
	# --- CLEANUP ---
	# ==========================================
	if highlight != null:
		highlight.queue_free()
		
	cine_layer.queue_free()
	get_tree().paused = false
	
func animate_shield_drop(unit: Node2D) -> void:
	var shield_icon = unit.get_node_or_null("DefendIcon") 
	if shield_icon != null:
		# Capture designed position
		var target_pos = shield_icon.position
		
		# Reset for animation
		shield_icon.position = target_pos + Vector2(0, -60)
		shield_icon.modulate.a = 0.0
		shield_icon.visible = true
		
		# The satisfying bounce!
		var drop_tween = create_tween().set_parallel(true)
		drop_tween.tween_property(shield_icon, "position", target_pos, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		drop_tween.tween_property(shield_icon, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)

# Helper function to handle the toggle logic
func _toggle_minimap() -> void:
	if minimap_container == null: return
	
	minimap_container.visible = not minimap_container.visible
	
	if minimap_container.visible:
		# Play a cool high-tech open sound if you have one!
		if select_sound: 
			select_sound.pitch_scale = 1.2
			select_sound.play()
		# Force the drawer to update its visuals based on the current grid state
		map_drawer.queue_redraw()
	else:
		# Play a close sound
		if select_sound: 
			select_sound.pitch_scale = 0.8
			select_sound.play()

# ==========================================
# --- OUTRO CINEMATIC & VICTORY ---
# ==========================================
func _trigger_victory() -> void:
	# 1. Play the Outro Dialogue (if any exists!)
	if not CampaignManager.is_skirmish_mode and outro_dialogue.size() > 0:
		var avatar_node = null
		for u in player_container.get_children():
			if u.get("is_custom_avatar") == true:
				avatar_node = u
				break
		
		for block in outro_dialogue:
			if block.lines.is_empty(): continue 
			
			var final_name = block.speaker_name
			var final_portrait = block.portrait
			
			if final_name.to_lower() == "avatar" and avatar_node != null:
				final_name = avatar_node.unit_name
				if final_portrait == null and avatar_node.data != null:
					final_portrait = avatar_node.data.portrait
			
			var formatted_lines: Array = []
			for line in block.lines:
				var f_line = line
				if avatar_node != null:
					f_line = f_line.replace("{Avatar}", avatar_node.unit_name)
				formatted_lines.append(f_line)
				
			# Wait for the dialogue block to finish!
			await play_cinematic_dialogue(final_name, final_portrait, formatted_lines)

	# --- UNLOCK THE BLACKSMITH IF WE BEAT LEVEL 3 ---
	if CampaignManager.current_level_index == 2: # Index 2 is Level 3!
		CampaignManager.blacksmith_unlocked = true
		CampaignManager.encounter_flags["shattered_sanctum_cleared"] = true

	# --- Relationship Web: trust +1 only when both survived and were close (Manhattan <= VICTORY_TRUST_PROXIMITY_MANHATTAN) at victory ---
	var survivors: Array[Node2D] = []
	if player_container:
		for c in player_container.get_children():
			if c is Node2D and is_instance_valid(c) and (c.get("current_hp") != null and int(c.current_hp) > 0):
				survivors.append(c)
	var trust_pairs: int = 0
	for i in range(survivors.size()):
		for j in range(i + 1, survivors.size()):
			var a: Node2D = survivors[i]
			var b: Node2D = survivors[j]
			var pa: Vector2i = get_grid_pos(a)
			var pb: Vector2i = get_grid_pos(b)
			var dist: int = abs(pa.x - pb.x) + abs(pa.y - pb.y)
			if dist <= VICTORY_TRUST_PROXIMITY_MANHATTAN:
				CampaignManager.add_relationship_value(get_relationship_id(a), get_relationship_id(b), "trust", 1)
				trust_pairs += 1
			if dist <= VICTORY_TRUST_PROXIMITY_MANHATTAN:
				if _can_gain_mentorship(a, b):
					_award_relationship_stat_event(a, b, "mentorship", "victory_mentorship", 1)
				elif _can_gain_mentorship(b, a):
					_award_relationship_stat_event(b, a, "mentorship", "victory_mentorship", 1)
	if DEBUG_RELATIONSHIP_COMBAT and trust_pairs > 0:
		print("[RelationshipCombat] Victory: +1 trust for ", trust_pairs, " close survivor pairs")

	# 2. Trigger the Victory Screen
	trigger_game_over("VICTORY")


# ==========================================
# --- FOG OF WAR & LINE OF SIGHT ---
# ==========================================
func update_fog_of_war() -> void:
	if not use_fog_of_war or fog_drawer == null: return
	
	# 1. Demote all currently "Visible" (2) tiles to "Fogged/Remembered" (1)
	for key in fow_grid.keys():
		if fow_grid[key] == 2:
			fow_grid[key] = 1
			
	# 2. Gather all units that grant vision
	var vision_sources = []
	if player_container: vision_sources += player_container.get_children()
	if ally_container: vision_sources += ally_container.get_children()
	
	# 3. Cast Line of Sight for every friendly unit
	for u in vision_sources:
		if not is_instance_valid(u) or u.is_queued_for_deletion() or u.current_hp <= 0:
			continue
			
		var start = get_grid_pos(u)
		var v_range = u.get("vision_range") if u.get("vision_range") != null else default_vision_range
		
		# The unit can always see the tile they are standing on
		fow_grid[start] = 2 
		
		for x in range(start.x - v_range, start.x + v_range + 1):
			for y in range(start.y - v_range, start.y + v_range + 1):
				var target = Vector2i(x, y)
				
				# Ensure target is inside map bounds
				if target.x >= 0 and target.x < GRID_SIZE.x and target.y >= 0 and target.y < GRID_SIZE.y:
					# Check if it's within the circular/diamond radius
					if abs(start.x - target.x) + abs(start.y - target.y) <= v_range:
						# Trace a ray to see if a wall blocks it
						if _check_line_of_sight(start, target):
							fow_grid[target] = 2
							
	# 4. Hide/Reveal Enemies based on the new vision map
	_apply_fow_visibility(enemy_container)
	_apply_fow_visibility(destructibles_container)
	_apply_fow_visibility(chests_container)
	
	# Force the black squares to redraw
	fog_drawer.queue_redraw()

func _check_line_of_sight(start: Vector2i, target: Vector2i) -> bool:
	# Bresenham's Line Algorithm
	var dx = abs(target.x - start.x)
	var dy = -abs(target.y - start.y)
	var sx = 1 if start.x < target.x else -1
	var sy = 1 if start.y < target.y else -1
	var err = dx + dy
	
	var current = start
	
	while true:
		# If the ray hits a wall/mountain BEFORE reaching the target, vision is blocked
		if current != start and current != target:
			
			# --- NEW: Check physical Wall nodes in the Hierarchy! ---
			if _is_wall_at(current):
				return false
				
			# (We keep the TileMap check as a backup just in case you ever 
			# want to add "Mountain" or "Thick Forest" tiles later)
			var t_data = get_terrain_data(current)
			if vision_blocking_terrain.has(t_data["name"]):
				return false
				
		if current == target: break
		
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			current.x += sx
		if e2 <= dx:
			err += dx
			current.y += sy
			
	return true
	
func _is_wall_at(pos: Vector2i) -> bool:
	if walls_container == null: return false
	
	for w in walls_container.get_children():
		if not is_instance_valid(w) or w.is_queued_for_deletion(): continue
		
		# Support for both 1x1 walls and massive multi-tile walls!
		if w.has_method("get_occupied_tiles"):
			if pos in w.get_occupied_tiles(self):
				return true
		else:
			if get_grid_pos(w) == pos:
				return true
				
	return false
	
func _apply_fow_visibility(container: Node) -> void:
	if container == null: return
	for child in container.get_children():
		if not is_instance_valid(child) or child.is_queued_for_deletion(): continue
		
		var pos = get_grid_pos(child)
		# An enemy is only visible if their tile is currently State 2 (Visible)
		var tile_visible: bool = fow_grid.has(pos) and fow_grid[pos] == 2
		child.visible = tile_visible

func _process_fog(delta: float) -> void:
	if not use_fog_of_war or fog_drawer == null: return
	
	var needs_redraw = false
	
	for pos in fow_grid.keys():
		var state = fow_grid[pos]
		var target_a = 0.85 
		
		if state == 1: target_a = 0.45 
		elif state == 2: target_a = 0.00 
			
		var current_a = fow_display_alphas.get(pos, 0.85)
		
		if abs(current_a - target_a) > 0.01:
			var new_a = lerp(current_a, target_a, 10.0 * delta)
			fow_display_alphas[pos] = new_a
			
			# Paint the updated transparency onto the exact pixel
			fow_image.set_pixel(pos.x, pos.y, Color(0.05, 0.05, 0.1, new_a))
			needs_redraw = true
			
	if needs_redraw:
		# Push the updated image to the GPU and redraw
		fow_texture.update(fow_image)
		fog_drawer.queue_redraw()

func animate_flying_gold(world_pos: Vector2, amount: int) -> void:
	# 1. Bring back the floating text so you still see the big number instantly!
	spawn_loot_text("+ " + str(amount) + " G", Color(1.0, 0.9, 0.2), world_pos + Vector2(32, -32))
	
	# 2. Convert the 2D World Map position into Screen/UI coordinates
	var screen_pos = get_global_transform_with_canvas() * world_pos
	gold_label.pivot_offset = gold_label.size / 2.0
	
	# 3. THE FIX: 1-to-1 coin mapping, capped at 20 coins max!
	var coin_count = amount
	if amount > 20:
		coin_count = 20 # Hard cap so massive drops don't lag or take forever to finish

	# 4. Setup the Visual Counter (ref so lambda can update it)
	var visual_gold_ref: Array = [player_gold - amount]
	var gold_per_coin = int(ceil(float(amount) / float(coin_count)))
	
	# 5. Spawn the fountain of coins!
	for i in range(coin_count):
		var coin = Panel.new()
		coin.custom_minimum_size = Vector2(16, 16)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.85, 0.1) # Shiny Gold
		style.border_width_bottom = 2
		style.border_color = Color(0.7, 0.4, 0.0) # Shadow for depth
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		coin.add_theme_stylebox_override("panel", style)
		
		get_node("UI").add_child(coin)
		coin.global_position = screen_pos
		
		var t = create_tween()
		
		# Phase A: The Burst (All coins explode out simultaneously)
		var burst_offset = Vector2(randf_range(-70, 70), randf_range(-90, -30))
		t.tween_property(coin, "global_position", screen_pos + burst_offset, 0.3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
		
		# Phase B: The STAGGERED Hangtime
		t.tween_interval(0.1 + (i * 0.05)) 
		
		# Phase C: Fly to the Bank!
		var target_pos = gold_label.global_position + (gold_label.size / 2.0) - (coin.custom_minimum_size / 2.0)
		t.tween_property(coin, "global_position", target_pos, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		
		# Phase D: Impact!
		var is_last_coin = (i == coin_count - 1)
		
		t.tween_callback(func():
			coin.queue_free() 
			
			# Tick up the UI number sequentially
			visual_gold_ref[0] += gold_per_coin
			if is_last_coin or visual_gold_ref[0] > player_gold:
				visual_gold_ref[0] = player_gold 
				
			gold_label.text = "Gold: " + str(visual_gold_ref[0])
			
			# Play a rapid "clinking" sound
			if select_sound and select_sound.stream != null:
				var p = AudioStreamPlayer.new()
				p.stream = select_sound.stream
				p.pitch_scale = randf_range(1.8, 2.3) 
				p.volume_db = -12.0 
				add_child(p)
				p.play()
				p.finished.connect(p.queue_free)
				
			# Micro-bounce the UI Label
			gold_label.scale = Vector2(1.1, 1.1)
			var pulse = create_tween()
			pulse.tween_property(gold_label, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BOUNCE)
		)
		
func _on_fog_draw() -> void:
	if not use_fog_of_war or fow_texture == null: return
	
	# Stretch the tiny image over the massive map.
	# Because we set texture_filter to LINEAR, the GPU smoothly blends 
	# the pixels together, creating flawless, cloud-like soft edges!
	var map_rect = Rect2(0, 0, GRID_SIZE.x * CELL_SIZE.x, GRID_SIZE.y * CELL_SIZE.y)
	fog_drawer.draw_texture_rect(fow_texture, map_rect, false)

# --- TACTICAL ABILITY (Momentum QTE) ---
func _run_tactical_action_minigame(attacker: Node2D, ability_name: String) -> bool:
	if attacker == null or not is_instance_valid(attacker): return false

	# 1) TELEGRAPH
	screen_shake(6.0, 0.2)
	var clang = get_node_or_null("ClangSound")
	if clang != null and clang.stream != null:
		clang.pitch_scale = 1.8 # High-pitched windup
		clang.play()

	var f_text = FloatingTextScene.instantiate()
	f_text.text_to_show = "MOMENTUM!"
	f_text.text_color = Color(0.2, 1.0, 1.0)
	add_child(f_text)
	f_text.global_position = attacker.global_position + Vector2(32, -48)

	await get_tree().create_timer(0.45).timeout

	# --- CINEMATIC LOCK ---
	var prev_paused = get_tree().paused
	get_tree().paused = true

	# 2) UI POP
	var qte_layer = CanvasLayer.new()
	qte_layer.layer = 100
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS 
	add_child(qte_layer)

	var vp_size = get_viewport_rect().size

	var screen_dimmer = ColorRect.new()
	screen_dimmer.size = vp_size
	screen_dimmer.color = Color(0, 0.1, 0.2, 0.3) # Slight blue tint
	qte_layer.add_child(screen_dimmer)

	# Bar
	var bar_bg = ColorRect.new()
	bar_bg.size = Vector2(380, 30)
	bar_bg.pivot_offset = bar_bg.size / 2.0
	bar_bg.position = (vp_size - bar_bg.size) / 2.0
	bar_bg.position.y += 100.0 # Put it below the action
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.95)
	bar_bg.scale = Vector2(0.86, 0.86)
	bar_bg.modulate.a = 0.0
	qte_layer.add_child(bar_bg)

	var bar_pop = qte_layer.create_tween().set_parallel(true)
	bar_pop.tween_property(bar_bg, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bar_pop.tween_property(bar_bg, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# The "Perfect" Sweet Spot (Small and Green)
	var perfect_zone = ColorRect.new()
	perfect_zone.size = Vector2(40, 30)
	var rand_max = bar_bg.size.x - perfect_zone.size.x
	perfect_zone.position = Vector2(randf_range(50.0, rand_max), 0.0)
	perfect_zone.color = Color(0.2, 1.0, 0.2, 0.9)
	bar_bg.add_child(perfect_zone)

	var qte_cursor = ColorRect.new()
	qte_cursor.size = Vector2(8, 50)
	qte_cursor.position = Vector2(0, -10)
	qte_cursor.color = Color.WHITE
	bar_bg.add_child(qte_cursor)

	var help_text = Label.new()
	help_text.text = "STOP IN GREEN FOR +DAMAGE & TRAP DURATION!" if ability_name == "Fire Trap" else "STOP IN GREEN FOR 2x DISTANCE!"
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.add_theme_font_size_override("font_size", 24)
	help_text.add_theme_color_override("font_color", Color.CYAN)
	bar_bg.add_child(help_text)
	help_text.position = Vector2(0, 40)
	help_text.size.x = bar_bg.size.x

	# 3) TIMING LOOP 
	var total_ms = 700 # Very fast!
	var start_ms = Time.get_ticks_msec()
	var is_perfect = false
	var pressed = false

	while true:
		await get_tree().process_frame
		var elapsed_ms = Time.get_ticks_msec() - start_ms

		if elapsed_ms >= total_ms: break

		var progress = float(elapsed_ms) / float(total_ms)
		qte_cursor.position.x = progress * bar_bg.size.x

		if Input.is_action_just_pressed("ui_accept"):
			pressed = true
			var cursor_center = qte_cursor.position.x + (qte_cursor.size.x / 2.0)
			var p_start = perfect_zone.position.x
			var p_end = p_start + perfect_zone.size.x

			if cursor_center >= p_start and cursor_center <= p_end:
				is_perfect = true
				qte_cursor.color = Color.YELLOW
				perfect_zone.color = Color.WHITE
				screen_shake(15.0, 0.25)

				if clang != null and clang.stream != null:
					clang.pitch_scale = 1.3
					clang.play()
				
				help_text.text = "MAXIMUM POWER!"
				help_text.add_theme_color_override("font_color", Color.YELLOW)
			else:
				qte_cursor.color = Color(0.9, 0.25, 0.25)
				if miss_sound.stream != null: miss_sound.play()
				help_text.text = "NORMAL " + ability_name.to_upper()
				help_text.add_theme_color_override("font_color", Color.GRAY)
			break

	if not pressed:
		if miss_sound.stream != null: miss_sound.play()
		help_text.text = "NORMAL " + ability_name.to_upper()
		help_text.add_theme_color_override("font_color", Color.GRAY)

	await get_tree().create_timer(0.45, true, false, true).timeout 

	qte_layer.queue_free()
	get_tree().paused = prev_paused
	
	return is_perfect

func _count_alive_enemies(exclude: Node2D = null) -> int:
	var count := 0
	if enemy_container:
		for e in enemy_container.get_children():
			if e == exclude:
				continue
			if is_instance_valid(e) and not e.is_queued_for_deletion() and e.current_hp > 0:
				count += 1
	return count

func _count_active_enemy_spawners(exclude: Node2D = null) -> int:
	var count := 0
	if destructibles_container:
		for d in destructibles_container.get_children():
			if d == exclude:
				continue
			if not is_instance_valid(d) or d.is_queued_for_deletion():
				continue
			if d.has_method("process_turn") and d.get("spawner_faction") == 0:
				count += 1
	return count

# ==========================================
# --- MULTIVERSE ARENA SPAWNER ---
# ==========================================
func setup_arena_battle() -> void:
	print("--- INITIALIZING MULTIVERSE ARENA ---")
	var opp_data = ArenaManager.current_opponent_data
	
	# Delete any pre-placed enemies left over in the editor
	for child in enemy_container.get_children():
		child.queue_free()
		
	var meta = opp_data.get("metadata", {})
	var roster = meta.get("roster", [])
	var dragons = meta.get("dragons", [])
	
	# Find empty, walkable tiles on the right side of the map for enemies
	var valid_spawn_points = []
	for x in range(int(GRID_SIZE.x / 2.0), GRID_SIZE.x): 
		for y in range(GRID_SIZE.y):
			var pos = Vector2i(x, y)
			if not astar.is_point_solid(pos) and get_unit_at(pos) == null:
				valid_spawn_points.append(pos)
				
	valid_spawn_points.shuffle()
	var spawn_index = 0
	
	# 1. SPAWN THE GHOST HEROES
	for unit_dict in roster:
		if spawn_index >= valid_spawn_points.size(): break 
		
		var ghost = player_unit_scene.instantiate()
		ghost.is_arena_ghost = true 
		enemy_container.add_child(ghost) 
		
		# --- FIX: CONNECT SIGNALS SO THE GAME KNOWS THEY DIED ---
		ghost.died.connect(_on_unit_died)
		ghost.leveled_up.connect(_on_unit_leveled_up)
		
		# Force them to the enemy team
		if "team" in ghost: ghost.team = 1 
		if "is_enemy" in ghost: ghost.is_enemy = true
		
		var grid_pos = valid_spawn_points[spawn_index]
		ghost.position = Vector2(grid_pos.x * CELL_SIZE.x, grid_pos.y * CELL_SIZE.y)
		
		# Inject Cloud Stats
		ghost.unit_name = unit_dict.get("unit_name", "Gladiator")
		ghost.unit_class_name = unit_dict.get("class", "Mercenary")
		ghost.level = unit_dict.get("level", 1)
		ghost.max_hp = unit_dict.get("max_hp", 20)
		ghost.current_hp = ghost.max_hp 
		ghost.strength = unit_dict.get("strength", 5)
		ghost.magic = unit_dict.get("magic", 0)
		ghost.defense = unit_dict.get("defense", 3)
		ghost.resistance = unit_dict.get("resistance", 1)
		ghost.speed = unit_dict.get("speed", 4)
		ghost.agility = unit_dict.get("agility", 3)
		ghost.move_range = unit_dict.get("move_range", 4)
		ghost.ability = unit_dict.get("ability", "None")
		
		# Give them a dummy "Ghost Weapon" so they can deal actual damage!
		var dummy_wpn = WeaponData.new()
		dummy_wpn.weapon_name = unit_dict.get("equipped_weapon_name", "Ghost Blade")
		dummy_wpn.might = 5
		dummy_wpn.hit_bonus = 10
		dummy_wpn.min_range = 1
		dummy_wpn.max_range = 1
		ghost.equipped_weapon = dummy_wpn
		
		if ghost.data == null: ghost.data = UnitData.new()
		
		# --- RESTORE VISUALS FROM THE CLOUD ---
		var s_path = unit_dict.get("sprite_path", "")
		var p_path = unit_dict.get("portrait_path", "")
		
		if s_path != "" and ResourceLoader.exists(s_path):
			var sprite_node = ghost.get_node_or_null("Sprite")
			if sprite_node == null: sprite_node = ghost.get_node_or_null("Sprite2D")
			if sprite_node: sprite_node.texture = load(s_path)
			
		if p_path != "" and ResourceLoader.exists(p_path):
			ghost.data.portrait = load(p_path)
			
		# Tint them slightly red so players know they are enemy ghosts!
		ghost.base_color = Color(1.0, 0.7, 0.7)
		ghost.modulate = ghost.base_color
		
		if ghost.has_method("setup_ghost_ui"):
			ghost.setup_ghost_ui()
			
		spawn_index += 1
		
	# 2. SPAWN THE GHOST DRAGONS
	for d_dict in dragons:
		if spawn_index >= valid_spawn_points.size(): break
		
		var ghost_dragon = player_unit_scene.instantiate()
		ghost_dragon.is_arena_ghost = true 
		enemy_container.add_child(ghost_dragon)
		
		ghost_dragon.died.connect(_on_unit_died)
		ghost_dragon.leveled_up.connect(_on_unit_leveled_up)
		
		if "team" in ghost_dragon: ghost_dragon.team = 1
		if "is_enemy" in ghost_dragon: ghost_dragon.is_enemy = true
		
		var grid_pos = valid_spawn_points[spawn_index]
		ghost_dragon.position = Vector2(grid_pos.x * CELL_SIZE.x, grid_pos.y * CELL_SIZE.y)
		
		ghost_dragon.unit_name = d_dict.get("name", "Dragon")
		ghost_dragon.unit_class_name = d_dict.get("element", "Fire") + " Dragon"
		ghost_dragon.max_hp = d_dict.get("max_hp", 25)
		ghost_dragon.current_hp = ghost_dragon.max_hp
		ghost_dragon.strength = d_dict.get("strength", 8)
		ghost_dragon.magic = d_dict.get("magic", 8)
		ghost_dragon.defense = d_dict.get("defense", 5)
		ghost_dragon.resistance = d_dict.get("resistance", 4)
		ghost_dragon.speed = d_dict.get("speed", 5)
		ghost_dragon.agility = d_dict.get("agility", 4)
		ghost_dragon.move_range = 5 
		ghost_dragon.set_meta("is_dragon", true)
		
		# Give dragons a built-in weapon so they can attack
		var fang = WeaponData.new()
		fang.weapon_name = "Ghost Fang"
		fang.might = 6
		fang.min_range = 1
		fang.max_range = 1
		ghost_dragon.equipped_weapon = fang
		
		if ghost_dragon.data == null: ghost_dragon.data = UnitData.new()
		
		# Auto-assign the correct dragon sprite based on their element!
		var elem = d_dict.get("element", "Fire").to_lower()
		var d_path = "res://Assets/Sprites/" + elem + "_dragon_sprite.png"
		if ResourceLoader.exists(d_path):
			var sprite_node = ghost_dragon.get_node_or_null("Sprite")
			if sprite_node == null: sprite_node = ghost_dragon.get_node_or_null("Sprite2D")
			if sprite_node: sprite_node.texture = load(d_path)
			
		ghost_dragon.base_color = Color(1.0, 0.7, 0.7)
		ghost_dragon.modulate = ghost_dragon.base_color
		
		if ghost_dragon.has_method("setup_ghost_ui"):
			ghost_dragon.setup_ghost_ui()
			
		spawn_index += 1

func _do_hit_stop(freeze_duration: float, slow_scale: float = 0.12, slow_duration: float = 0.10) -> void:
	if _hit_stop_active:
		return

	_hit_stop_active = true
	var old_scale: float = Engine.time_scale

	# Tiny real freeze
	Engine.time_scale = 0.01
	await get_tree().create_timer(freeze_duration, true, false, true).timeout

	# Short dramatic slow-motion tail
	Engine.time_scale = slow_scale
	await get_tree().create_timer(slow_duration, true, false, true).timeout

	Engine.time_scale = old_scale
	_hit_stop_active = false

var _impact_snap_tween: Tween
var _screen_shake_tween: Tween

func _start_impact_camera(focus_world: Vector2, _zoom_mult: float, snap_t: float, restore_t: float) -> void:
	if main_camera == null:
		return

	if _impact_snap_tween:
		_impact_snap_tween.kill()
	if _impact_restore_tween:
		_impact_restore_tween.kill()

	var old_offset: Vector2 = main_camera.offset
	var camera_center: Vector2 = main_camera.get_screen_center_position()
	var dir_to_impact: Vector2 = focus_world - camera_center

	var punch_offset := Vector2.ZERO
	if dir_to_impact.length() > 0.001:
		var punch_strength: float = clamp(dir_to_impact.length() * 0.08, 10.0, 24.0)
		punch_offset = dir_to_impact.normalized() * punch_strength

	_impact_snap_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_impact_snap_tween.tween_property(main_camera, "offset", old_offset + punch_offset, snap_t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_impact_snap_tween.finished.connect(func():
		_impact_restore_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_impact_restore_tween.tween_property(main_camera, "offset", Vector2.ZERO, restore_t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	)		
func _spawn_fullscreen_impact_flash(color: Color, alpha: float, duration: float) -> void:
	var flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = color
	flash.modulate.a = 0.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(flash)

	var tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(flash, "modulate:a", alpha, duration * 0.16)
	tw.tween_property(flash, "modulate:a", alpha * 0.35, duration * 0.18)
	tw.tween_property(flash, "modulate:a", 0.0, duration * 0.66)
	tw.finished.connect(flash.queue_free)
		
func _play_arena_vs_screen() -> void:
	if arena_vs_layer == null:
		return

	var vp_size = get_viewport_rect().size
	var left_target = Vector2(40, 110)
	var right_target = Vector2(vp_size.x - arena_vs_right_panel.size.x - 40, 110)

	var p_leader = ArenaManager.local_arena_team[0] if ArenaManager.local_arena_team.size() > 0 else null
	var my_mmr = ArenaManager.get_local_mmr()
	var my_rank = ArenaManager.get_rank_data(my_mmr)

	var enemy_meta = ArenaManager.current_opponent_data.get("metadata", {})
	var opp_mmr = int(ArenaManager.current_opponent_data.get("score", 1000))
	var opp_rank = ArenaManager.get_rank_data(opp_mmr)

	arena_vs_left_portrait.texture = p_leader.get("portrait") if p_leader else null
	arena_vs_left_name.text = p_leader.get("unit_name", "Challenger") if p_leader else "Challenger"
	arena_vs_left_rank.text = my_rank["name"].to_upper()
	arena_vs_left_rank.add_theme_color_override("font_color", my_rank["color"])
	arena_vs_left_mmr.text = str(my_mmr) + " MMR"

	arena_vs_right_name.text = enemy_meta.get("player_name", "Unknown")
	arena_vs_right_rank.text = opp_rank["name"].to_upper()
	arena_vs_right_rank.add_theme_color_override("font_color", opp_rank["color"])
	arena_vs_right_mmr.text = str(opp_mmr) + " MMR"

	var e_roster = enemy_meta.get("roster", [])
	if e_roster.size() > 0 and e_roster[0].get("portrait_path"):
		arena_vs_right_portrait.texture = load(e_roster[0]["portrait_path"])

	arena_vs_layer.show()
	arena_vs_left_panel.position.x = -600
	arena_vs_right_panel.position.x = vp_size.x + 200

	var tw = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(arena_vs_dimmer, "modulate:a", 1.0, 0.3)
	tw.tween_property(arena_vs_left_panel, "position", left_target, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(arena_vs_right_panel, "position", right_target, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await tw.finished

	arena_vs_label.scale = Vector2(5, 5)
	arena_vs_label.modulate.a = 0
	var vs_tw = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	vs_tw.tween_property(arena_vs_label, "scale", Vector2(1, 1), 0.2).set_trans(Tween.TRANS_BACK)
	vs_tw.tween_property(arena_vs_label, "modulate:a", 1.0, 0.1)
	arena_vs_particles.emitting = true

	if crit_sound:
		crit_sound.play()
	screen_shake(15.0, 0.3)

	await get_tree().create_timer(1.5, true).timeout

	var out_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	out_tw.tween_property(arena_vs_layer, "modulate:a", 0.0, 0.4)
	await out_tw.finished
	arena_vs_layer.hide()


func _hide_legacy_levelup_nodes() -> void:
	if level_up_title != null:
		level_up_title.visible = false
	if level_up_stats != null:
		level_up_stats.visible = false


func _make_levelup_style(bg: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _get_levelup_dynamic_root() -> VBoxContainer:
	var existing_scroll_node: Node = level_up_panel.get_node_or_null("DynamicScroll")
	var existing_scroll: ScrollContainer = existing_scroll_node as ScrollContainer
	if existing_scroll != null:
		var existing_root_node: Node = existing_scroll.get_node_or_null("DynamicContent")
		var existing_root: VBoxContainer = existing_root_node as VBoxContainer
		if existing_root != null:
			return existing_root

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "DynamicScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 12
	scroll.offset_top = 12
	scroll.offset_right = -12
	scroll.offset_bottom = -12
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_up_panel.add_child(scroll)

	var root: VBoxContainer = VBoxContainer.new()
	root.name = "DynamicContent"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(root)

	return root


func _clear_levelup_dynamic_root() -> void:
	var root: VBoxContainer = _get_levelup_dynamic_root()
	for child in root.get_children():
		child.queue_free()


func _get_levelup_bar_cap(stat_key: String, value: int) -> int:
	if stat_key == "hp":
		return int(max(20, int(ceil(float(value + 9) / 10.0) * 10.0)))
	return int(max(10, int(ceil(float(value + 4) / 5.0) * 5.0)))


func _update_levelup_value_label(value: float, value_label: Label, old_value: int, gain: int) -> void:
	var shown: int = int(round(value))
	if gain > 0:
		value_label.text = str(old_value) + " → " + str(shown) + "  (+" + str(gain) + ")"
	else:
		value_label.text = str(shown)


func _get_levelup_class_theme(unit: Node2D) -> Dictionary:
	var raw_class_value = unit.get("unit_class_name")
	var unit_class_text: String = "Unit"
	if raw_class_value != null:
		unit_class_text = str(raw_class_value)

	var class_lower: String = unit_class_text.to_lower()

	var theme: Dictionary = {
		"panel_bg": Color(0.05, 0.09, 0.05, 0.97),
		"panel_border": Color(0.24, 0.86, 0.34, 1.0),
		"row_bg": Color(0.04, 0.07, 0.04, 0.95),
		"row_border": Color(0.18, 0.66, 0.28, 1.0),
		"accent": Color(0.38, 1.00, 0.44, 1.0),
		"accent_soft": Color(0.84, 1.00, 0.86, 1.0),
		"flash": Color(0.72, 1.00, 0.76, 1.0),
		"particle": Color(0.58, 1.00, 0.62, 1.0),
		"crit": Color(1.00, 0.92, 0.36, 1.0)
	}

	if "mage" in class_lower or "sage" in class_lower or "spellblade" in class_lower or "sorcer" in class_lower:
		theme["panel_bg"] = Color(0.06, 0.05, 0.12, 0.97)
		theme["panel_border"] = Color(0.56, 0.38, 1.00, 1.0)
		theme["row_bg"] = Color(0.05, 0.04, 0.10, 0.95)
		theme["row_border"] = Color(0.38, 0.28, 0.84, 1.0)
		theme["accent"] = Color(0.72, 0.54, 1.00, 1.0)
		theme["accent_soft"] = Color(0.90, 0.84, 1.00, 1.0)
		theme["flash"] = Color(0.84, 0.76, 1.00, 1.0)
		theme["particle"] = Color(0.74, 0.60, 1.00, 1.0)
		theme["crit"] = Color(1.00, 0.88, 0.44, 1.0)

	elif "knight" in class_lower or "paladin" in class_lower or "general" in class_lower:
		theme["panel_bg"] = Color(0.10, 0.08, 0.04, 0.97)
		theme["panel_border"] = Color(1.00, 0.82, 0.28, 1.0)
		theme["row_bg"] = Color(0.08, 0.06, 0.03, 0.95)
		theme["row_border"] = Color(0.78, 0.58, 0.20, 1.0)
		theme["accent"] = Color(1.00, 0.90, 0.40, 1.0)
		theme["accent_soft"] = Color(1.00, 0.97, 0.80, 1.0)
		theme["flash"] = Color(1.00, 0.94, 0.62, 1.0)
		theme["particle"] = Color(1.00, 0.86, 0.50, 1.0)
		theme["crit"] = Color(1.00, 0.95, 0.54, 1.0)

	elif "archer" in class_lower or "ranger" in class_lower or "bow" in class_lower or "sniper" in class_lower:
		theme["panel_bg"] = Color(0.06, 0.10, 0.05, 0.97)
		theme["panel_border"] = Color(0.46, 0.92, 0.34, 1.0)
		theme["row_bg"] = Color(0.05, 0.08, 0.04, 0.95)
		theme["row_border"] = Color(0.34, 0.70, 0.24, 1.0)
		theme["accent"] = Color(0.60, 1.00, 0.42, 1.0)
		theme["accent_soft"] = Color(0.88, 1.00, 0.82, 1.0)
		theme["flash"] = Color(0.78, 1.00, 0.66, 1.0)
		theme["particle"] = Color(0.66, 1.00, 0.52, 1.0)
		theme["crit"] = Color(1.00, 0.94, 0.48, 1.0)

	elif "thief" in class_lower or "assassin" in class_lower or "rogue" in class_lower:
		theme["panel_bg"] = Color(0.08, 0.05, 0.10, 0.97)
		theme["panel_border"] = Color(0.78, 0.34, 0.96, 1.0)
		theme["row_bg"] = Color(0.06, 0.04, 0.08, 0.95)
		theme["row_border"] = Color(0.56, 0.24, 0.78, 1.0)
		theme["accent"] = Color(0.94, 0.52, 1.00, 1.0)
		theme["accent_soft"] = Color(0.96, 0.84, 1.00, 1.0)
		theme["flash"] = Color(0.92, 0.72, 1.00, 1.0)
		theme["particle"] = Color(0.90, 0.60, 1.00, 1.0)
		theme["crit"] = Color(1.00, 0.90, 0.46, 1.0)

	elif "cleric" in class_lower or "monk" in class_lower or "divine" in class_lower or "healer" in class_lower:
		theme["panel_bg"] = Color(0.09, 0.09, 0.06, 0.97)
		theme["panel_border"] = Color(1.00, 0.88, 0.42, 1.0)
		theme["row_bg"] = Color(0.08, 0.08, 0.05, 0.95)
		theme["row_border"] = Color(0.80, 0.72, 0.28, 1.0)
		theme["accent"] = Color(1.00, 0.96, 0.60, 1.0)
		theme["accent_soft"] = Color(1.00, 1.00, 0.88, 1.0)
		theme["flash"] = Color(1.00, 0.97, 0.74, 1.0)
		theme["particle"] = Color(0.92, 1.00, 0.70, 1.0)
		theme["crit"] = Color(1.00, 0.96, 0.54, 1.0)

	elif "dragon" in class_lower or "monster" in class_lower:
		theme["panel_bg"] = Color(0.11, 0.05, 0.03, 0.97)
		theme["panel_border"] = Color(1.00, 0.42, 0.18, 1.0)
		theme["row_bg"] = Color(0.09, 0.04, 0.03, 0.95)
		theme["row_border"] = Color(0.78, 0.26, 0.14, 1.0)
		theme["accent"] = Color(1.00, 0.60, 0.24, 1.0)
		theme["accent_soft"] = Color(1.00, 0.86, 0.74, 1.0)
		theme["flash"] = Color(1.00, 0.76, 0.46, 1.0)
		theme["particle"] = Color(1.00, 0.60, 0.28, 1.0)
		theme["crit"] = Color(1.00, 0.92, 0.52, 1.0)

	elif "warrior" in class_lower or "berserk" in class_lower or "mercenary" in class_lower or "hero" in class_lower:
		theme["panel_bg"] = Color(0.10, 0.05, 0.05, 0.97)
		theme["panel_border"] = Color(1.00, 0.32, 0.28, 1.0)
		theme["row_bg"] = Color(0.08, 0.04, 0.04, 0.95)
		theme["row_border"] = Color(0.70, 0.22, 0.18, 1.0)
		theme["accent"] = Color(1.00, 0.46, 0.40, 1.0)
		theme["accent_soft"] = Color(1.00, 0.84, 0.80, 1.0)
		theme["flash"] = Color(1.00, 0.68, 0.58, 1.0)
		theme["particle"] = Color(1.00, 0.50, 0.42, 1.0)
		theme["crit"] = Color(1.00, 0.92, 0.50, 1.0)

	return theme
	
func _get_levelup_stat_visual(stat_key: String) -> Dictionary:
	match stat_key:
		"hp":
			return {"name": "HP", "icon": "♥", "color": Color(0.94, 0.32, 0.32, 1.0)}
		"str":
			return {"name": "STR", "icon": "⚔", "color": Color(1.00, 0.56, 0.20, 1.0)}
		"mag":
			return {"name": "MAG", "icon": "✦", "color": Color(0.82, 0.48, 1.00, 1.0)}
		"def":
			return {"name": "DEF", "icon": "⬢", "color": Color(0.38, 0.82, 0.52, 1.0)}
		"res":
			return {"name": "RES", "icon": "✚", "color": Color(0.38, 0.96, 0.92, 1.0)}
		"spd":
			return {"name": "SPD", "icon": "➤", "color": Color(0.44, 0.74, 1.00, 1.0)}
		"agi":
			return {"name": "AGI", "icon": "❖", "color": Color(1.00, 0.86, 0.42, 1.0)}
	return {"name": stat_key.to_upper(), "icon": "•", "color": Color.WHITE}

func _create_levelup_icon_badge(icon_text: String, icon_color: Color) -> PanelContainer:
	var badge: PanelContainer = PanelContainer.new()
	badge.custom_minimum_size = Vector2(34, 34)
	badge.add_theme_stylebox_override("panel", _make_levelup_style(
		Color(icon_color.r * 0.18, icon_color.g * 0.18, icon_color.b * 0.18, 1.0),
		icon_color,
		8
	))

	var icon_label: Label = Label.new()
	icon_label.text = icon_text
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_label.add_theme_font_size_override("font_size", 20)
	icon_label.add_theme_color_override("font_color", Color.WHITE)
	badge.add_child(icon_label)

	return badge


func _create_levelup_title_banner(root: VBoxContainer, title_text: String, theme: Dictionary) -> Dictionary:
	var panel_bg: Color = theme["panel_bg"]
	var panel_border: Color = theme["panel_border"]

	var title_panel: PanelContainer = PanelContainer.new()
	title_panel.custom_minimum_size = Vector2(0, 54)
	title_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_panel.modulate.a = 0.0
	title_panel.scale = Vector2(0.96, 0.96)
	title_panel.add_theme_stylebox_override("panel", _make_levelup_style(
		panel_bg,
		panel_border,
		12
	))
	root.add_child(title_panel)

	var title_label: Label = Label.new()
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.96, 1.0, 0.96))
	title_panel.add_child(title_label)

	return {
		"panel": title_panel,
		"label": title_label
	}


func _create_levelup_header(unit: Node2D, old_level: int, new_level: int, theme: Dictionary) -> Dictionary:
	var root: VBoxContainer = _get_levelup_dynamic_root()

	var panel_bg: Color = theme["panel_bg"]
	var panel_border: Color = theme["panel_border"]
	var accent_color: Color = theme["accent"]
	var accent_soft: Color = theme["accent_soft"]

	var header_panel: PanelContainer = PanelContainer.new()
	header_panel.custom_minimum_size = Vector2(0, 108)
	header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_panel.modulate.a = 0.0
	header_panel.scale = Vector2(0.96, 0.96)
	header_panel.add_theme_stylebox_override("panel", _make_levelup_style(
		panel_bg,
		panel_border,
		12
	))
	root.add_child(header_panel)

	var outer: HBoxContainer = HBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 10
	outer.offset_top = 10
	outer.offset_right = -10
	outer.offset_bottom = -10
	outer.add_theme_constant_override("separation", 12)
	header_panel.add_child(outer)

	var portrait_bg: PanelContainer = PanelContainer.new()
	portrait_bg.custom_minimum_size = Vector2(76, 76)
	portrait_bg.add_theme_stylebox_override("panel", _make_levelup_style(
		Color(panel_bg.r + 0.04, panel_bg.g + 0.04, panel_bg.b + 0.04, 1.0),
		accent_color,
		10
	))
	outer.add_child(portrait_bg)

	var portrait_holder: Control = Control.new()
	portrait_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_holder.position.x = -22
	portrait_holder.modulate.a = 0.0
	portrait_bg.add_child(portrait_holder)

	var portrait: TextureRect = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = 4
	portrait.offset_top = 4
	portrait.offset_right = -4
	portrait.offset_bottom = -4
	portrait_holder.add_child(portrait)

	if unit.get("data") != null and unit.data != null and unit.data.get("portrait") != null:
		portrait.texture = unit.data.portrait

	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 4)
	outer.add_child(info_box)

	var unit_name_text: String = str(unit.unit_name)

	var raw_class_value = unit.get("unit_class_name")
	var unit_class_text: String = "Unit"
	if raw_class_value != null:
		unit_class_text = str(raw_class_value)

	var name_label: Label = Label.new()
	name_label.text = unit_name_text + "  •  " + unit_class_text
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.96, 1.0, 0.96))
	info_box.add_child(name_label)

	var level_label: Label = Label.new()
	if old_level != new_level:
		level_label.text = "LEVEL " + str(old_level) + "  →  " + str(new_level)
	else:
		level_label.text = "LEVEL " + str(new_level)
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.add_theme_color_override("font_color", accent_color)
	info_box.add_child(level_label)

	var exp_bar: ProgressBar = ProgressBar.new()
	exp_bar.min_value = 0.0
	exp_bar.max_value = 100.0
	exp_bar.value = 100.0
	exp_bar.show_percentage = false
	exp_bar.custom_minimum_size = Vector2(0, 18)
	exp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var exp_bg: StyleBoxFlat = StyleBoxFlat.new()
	exp_bg.bg_color = Color(0.08, 0.10, 0.08, 1.0)
	exp_bg.border_color = Color(0.18, 0.22, 0.18, 1.0)
	exp_bg.border_width_left = 1
	exp_bg.border_width_top = 1
	exp_bg.border_width_right = 1
	exp_bg.border_width_bottom = 1
	exp_bg.corner_radius_top_left = 7
	exp_bg.corner_radius_top_right = 7
	exp_bg.corner_radius_bottom_left = 7
	exp_bg.corner_radius_bottom_right = 7

	var exp_fill: StyleBoxFlat = StyleBoxFlat.new()
	exp_fill.bg_color = accent_color
	exp_fill.corner_radius_top_left = 7
	exp_fill.corner_radius_top_right = 7
	exp_fill.corner_radius_bottom_left = 7
	exp_fill.corner_radius_bottom_right = 7

	exp_bar.add_theme_stylebox_override("background", exp_bg)
	exp_bar.add_theme_stylebox_override("fill", exp_fill)
	info_box.add_child(exp_bar)

	var exp_label: Label = Label.new()
	exp_label.text = "POWER SURGE"
	exp_label.add_theme_font_size_override("font_size", 16)
	exp_label.add_theme_color_override("font_color", accent_soft)
	info_box.add_child(exp_label)

	return {
		"panel": header_panel,
		"portrait_holder": portrait_holder,
		"exp_bar": exp_bar,
		"exp_label": exp_label
	}

func _create_levelup_stat_row(container: VBoxContainer, stat_name: String, stat_key: String, start_value: int, end_value: int, gain: int, theme: Dictionary) -> Dictionary:
	var visual: Dictionary = _get_levelup_stat_visual(stat_key)
	var icon_symbol: String = str(visual["icon"])
	var icon_color: Color = visual["color"]
	var is_critical: bool = gain >= 2

	var row_border_color: Color = icon_color if gain > 0 else Color(0.28, 0.28, 0.28, 1.0)
	if is_critical:
		row_border_color = theme["crit"]

	var row_bg_color: Color = theme["row_bg"]
	if is_critical:
		row_bg_color = Color(
			min(theme["row_bg"].r + 0.03, 1.0),
			min(theme["row_bg"].g + 0.03, 1.0),
			min(theme["row_bg"].b + 0.03, 1.0),
			theme["row_bg"].a
		)

	var row_panel: PanelContainer = PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 68 if is_critical else 62)
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.modulate.a = 0.0
	row_panel.scale = Vector2(0.96, 0.96)
	row_panel.add_theme_stylebox_override("panel", _make_levelup_style(
		row_bg_color,
		row_border_color,
		8
	))
	container.add_child(row_panel)

	var outer: VBoxContainer = VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 10
	outer.offset_top = 7
	outer.offset_right = -10
	outer.offset_bottom = -7
	outer.add_theme_constant_override("separation", 6)
	row_panel.add_child(outer)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 8)
	outer.add_child(top_row)

	var badge: PanelContainer = _create_levelup_icon_badge(icon_symbol, theme["crit"] if is_critical else icon_color)
	badge.custom_minimum_size = Vector2(34, 34)
	top_row.add_child(badge)

	var name_label: Label = Label.new()
	name_label.text = stat_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20 if not is_critical else 21)
	name_label.add_theme_color_override("font_color", Color(0.94, 1.0, 0.94) if gain > 0 else Color(0.85, 0.85, 0.85))
	top_row.add_child(name_label)

	var value_label: Label = Label.new()
	value_label.custom_minimum_size = Vector2(132, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.add_theme_color_override("font_color", theme["crit"] if is_critical else (Color(0.94, 1.0, 0.94) if gain > 0 else Color(0.86, 0.86, 0.86)))
	value_label.text = str(start_value) + " → " + str(start_value) + "  (+" + str(gain) + ")" if gain > 0 else str(end_value)
	top_row.add_child(value_label)

	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = float(_get_levelup_bar_cap(stat_key, end_value))
	bar.value = float(start_value)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 18 if not is_critical else 20)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.09, 0.12, 0.09, 1.0)
	bg_style.border_color = Color(0.18, 0.20, 0.18, 1.0)
	bg_style.border_width_left = 1
	bg_style.border_width_top = 1
	bg_style.border_width_right = 1
	bg_style.border_width_bottom = 1
	bg_style.corner_radius_top_left = 7
	bg_style.corner_radius_top_right = 7
	bg_style.corner_radius_bottom_left = 7
	bg_style.corner_radius_bottom_right = 7

	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = theme["crit"] if is_critical else (icon_color if gain > 0 else Color(0.24, 0.34, 0.24, 1.0))
	fill_style.corner_radius_top_left = 7
	fill_style.corner_radius_top_right = 7
	fill_style.corner_radius_bottom_left = 7
	fill_style.corner_radius_bottom_right = 7

	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)
	outer.add_child(bar)

	var sheen: ColorRect = _attach_levelup_bar_sheen(bar)

	return {
		"row": row_panel,
		"bar": bar,
		"value_label": value_label,
		"badge": badge,
		"shine": sheen,
		"is_critical": is_critical,
		"start_value": start_value,
		"end_value": end_value,
		"gain": gain
	}

func run_theatrical_stat_reveal(unit: Node2D, title_text: String, gains: Dictionary) -> void:
	get_tree().paused = true
	level_up_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_hide_legacy_levelup_nodes()

	var total_gains: int = 0
	var gained_rows: int = 0
	for val in gains.values():
		total_gains += int(val)
		if int(val) > 0:
			gained_rows += 1

	var is_perfect: bool = total_gains >= 5
	var title_lower: String = title_text.to_lower()
	var is_real_level_up: bool = title_lower.begins_with("level up")

	var theme: Dictionary = _get_levelup_class_theme(unit)

	level_up_title.text = title_text
	level_up_title.modulate = theme["accent"] if not is_perfect else theme["crit"]

	var main_panel_style: StyleBoxFlat = _make_levelup_style(theme["panel_bg"], theme["panel_border"], 18)
	level_up_panel.add_theme_stylebox_override("panel", main_panel_style)

	_clear_levelup_dynamic_root()

	var flash_rect: ColorRect = ColorRect.new()
	flash_rect.size = get_viewport_rect().size
	flash_rect.color = theme["flash"]
	flash_rect.modulate.a = 0.0
	flash_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_node("UI").add_child(flash_rect)

	level_up_panel.scale = Vector2(0.84, 0.84)
	level_up_panel.modulate.a = 0.0
	level_up_panel.visible = true

	spawn_level_up_effect(unit.global_position)

	if is_perfect and epic_level_up_sound != null and epic_level_up_sound.stream != null:
		epic_level_up_sound.play()
	elif level_up_sound != null and level_up_sound.stream != null:
		level_up_sound.play()

	var burst_text: String = "LEVEL UP!" if is_real_level_up else "POWER SURGE!"
	await _show_levelup_center_burst(burst_text, theme["flash"])

	var halo: Node2D = _spawn_levelup_halo(unit, theme["accent"])
	var halo_tw = halo.create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	halo_tw.tween_property(halo, "modulate:a", 0.88, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	halo_tw.parallel().tween_property(halo, "scale", Vector2(1.0, 1.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	halo_tw.tween_property(halo, "modulate:a", 0.38, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	halo_tw.parallel().tween_property(halo, "scale", Vector2(0.88, 0.88), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var panel_particles: CPUParticles2D = _spawn_levelup_panel_particles(theme)

	await get_tree().create_timer(0.20, true, false, true).timeout

	var open_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	open_tween.tween_property(level_up_panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open_tween.tween_property(level_up_panel, "modulate:a", 1.0, 0.22)
	open_tween.tween_property(flash_rect, "modulate:a", 0.12, 0.08)
	open_tween.chain().tween_property(flash_rect, "modulate:a", 0.0, 0.22)
	await open_tween.finished

	await get_tree().process_frame

	var displayed_old_level: int = unit.level
	if is_real_level_up:
		displayed_old_level = max(1, unit.level - 1)

	var header_data: Dictionary = _create_levelup_header(unit, displayed_old_level, unit.level, theme)
	var header_panel: PanelContainer = header_data["panel"]
	var portrait_holder: Control = header_data["portrait_holder"]
	var exp_bar: ProgressBar = header_data["exp_bar"]

	var header_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	header_tw.tween_property(header_panel, "modulate:a", 1.0, 0.20)
	header_tw.tween_property(header_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	header_tw.tween_property(portrait_holder, "position:x", 0.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	header_tw.tween_property(portrait_holder, "modulate:a", 1.0, 0.20)
	header_tw.tween_property(exp_bar, "value", exp_bar.max_value, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await header_tw.finished

	await get_tree().create_timer(0.18, true, false, true).timeout

	var root: VBoxContainer = _get_levelup_dynamic_root()

	var stat_order: Array[String] = ["hp", "str", "mag", "def", "res", "spd", "agi"]
	var row_entries: Array = []

	for stat_key in stat_order:
		var gain: int = int(gains.get(stat_key, 0))
		if gain <= 0:
			continue

		var visual: Dictionary = _get_levelup_stat_visual(stat_key)
		var end_value: int = 0

		match stat_key:
			"hp":
				end_value = int(unit.max_hp)
			"str":
				end_value = int(unit.strength)
			"mag":
				end_value = int(unit.magic)
			"def":
				end_value = int(unit.defense)
			"res":
				end_value = int(unit.resistance)
			"spd":
				end_value = int(unit.speed)
			"agi":
				end_value = int(unit.agility)

		var start_value: int = end_value - gain

		var row_data: Dictionary = _create_levelup_stat_row(
			root,
			str(visual["name"]),
			stat_key,
			start_value,
			end_value,
			gain,
			theme
		)
		row_entries.append(row_data)

	await get_tree().process_frame

	for row_data in row_entries:
		var row_panel: PanelContainer = row_data["row"]
		var bar: ProgressBar = row_data["bar"]
		var value_label: Label = row_data["value_label"]
		var sheen: ColorRect = row_data["shine"]
		var start_value: int = int(row_data["start_value"])
		var end_value: int = int(row_data["end_value"])
		var gain: int = int(row_data["gain"])
		var is_critical: bool = bool(row_data["is_critical"])

		var row_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
		row_tw.tween_property(row_panel, "modulate:a", 1.0, 0.16)
		row_tw.tween_property(row_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		row_tw.tween_property(bar, "value", float(end_value), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		row_tw.tween_method(
			func(v: float):
				_update_levelup_value_label(v, value_label, start_value, gain),
			float(start_value),
			float(end_value),
			0.42
		)

		if select_sound != null and select_sound.stream != null:
			select_sound.pitch_scale = 1.18 if not is_critical else 1.28
			select_sound.play()

		_animate_levelup_bar_sheen(sheen, bar)

		await row_tw.finished

		if is_critical:
			await _play_levelup_critical_row_fx(row_data, theme)
		else:
			screen_shake(3.0, 0.08)

		await get_tree().create_timer(LEVELUP_ROW_REVEAL_DELAY, true, false, true).timeout

	if select_sound != null and select_sound.stream != null:
		select_sound.pitch_scale = 1.0

	var hold_time: float = LEVELUP_HOLD_TIME_PERFECT if is_perfect else LEVELUP_HOLD_TIME_NORMAL
	hold_time += float(gained_rows) * 0.22

	await get_tree().create_timer(hold_time, true, false, true).timeout

	if panel_particles != null and is_instance_valid(panel_particles):
		panel_particles.emitting = false

	var exit_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	exit_tween.tween_property(level_up_panel, "scale", Vector2(0.92, 0.92), 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	exit_tween.tween_property(level_up_panel, "modulate:a", 0.0, 0.24)
	if halo != null and is_instance_valid(halo):
		exit_tween.tween_property(halo, "modulate:a", 0.0, 0.20)

	await exit_tween.finished

	if panel_particles != null and is_instance_valid(panel_particles):
		panel_particles.queue_free()
	if halo != null and is_instance_valid(halo):
		halo.queue_free()
	if flash_rect != null and is_instance_valid(flash_rect):
		flash_rect.queue_free()

	level_up_panel.visible = false
	get_tree().paused = false
	
func _attach_levelup_bar_sheen(bar: ProgressBar) -> ColorRect:
	bar.clip_contents = true

	var sheen: ColorRect = ColorRect.new()
	sheen.name = "Sheen"
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheen.color = Color(1.0, 1.0, 1.0, 0.18)
	sheen.size = Vector2(46, max(28.0, bar.custom_minimum_size.y + 12.0))
	sheen.position = Vector2(-70, -8)
	sheen.rotation_degrees = 16.0
	sheen.modulate.a = 0.0
	bar.add_child(sheen)

	return sheen


func _animate_levelup_bar_sheen(sheen: ColorRect, bar: ProgressBar) -> void:
	if sheen == null or bar == null:
		return

	var bar_width: float = max(bar.size.x, bar.custom_minimum_size.x, 120.0)

	sheen.position = Vector2(-70, -8)
	sheen.modulate.a = 0.0

	var tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(sheen, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(sheen, "position:x", bar_width + 30.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(sheen, "modulate:a", 0.0, 0.10)


func _spawn_levelup_panel_particles(theme: Dictionary) -> CPUParticles2D:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.name = "LevelUpPanelParticles"
	particles.process_mode = Node.PROCESS_MODE_ALWAYS
	particles.position = Vector2(level_up_panel.size.x * 0.5, level_up_panel.size.y - 26.0)
	particles.amount = 42
	particles.lifetime = 2.2
	particles.preprocess = 1.0
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.direction = Vector2(0, -1)
	particles.spread = 24.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 18.0
	particles.initial_velocity_max = 42.0
	particles.scale_amount_min = 1.2
	particles.scale_amount_max = 3.4
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(max(40.0, level_up_panel.size.x * 0.42), 10.0)

	var grad: Gradient = Gradient.new()
	var particle_color: Color = theme["particle"]
	grad.add_point(0.0, Color(particle_color.r, particle_color.g, particle_color.b, 0.0))
	grad.add_point(0.18, Color(particle_color.r, particle_color.g, particle_color.b, 0.75))
	grad.add_point(0.70, Color(theme["flash"].r, theme["flash"].g, theme["flash"].b, 0.42))
	grad.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))
	particles.color_ramp = grad

	level_up_panel.add_child(particles)
	particles.emitting = true
	return particles


func _play_levelup_critical_row_fx(row_data: Dictionary, theme: Dictionary) -> void:
	var row_panel: PanelContainer = row_data.get("row") as PanelContainer
	var badge: PanelContainer = row_data.get("badge") as PanelContainer
	var bar: ProgressBar = row_data.get("bar") as ProgressBar

	if row_panel == null:
		return

	var flash: ColorRect = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(theme["crit"].r, theme["crit"].g, theme["crit"].b, 0.18)
	flash.modulate.a = 0.0
	row_panel.add_child(flash)

	var tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	row_panel.scale = Vector2(1.03, 1.03)
	row_panel.modulate = Color(1.20, 1.20, 1.20, 1.0)

	tw.tween_property(row_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(row_panel, "modulate", Color.WHITE, 0.24)
	tw.tween_property(flash, "modulate:a", 1.0, 0.08)
	tw.chain().tween_property(flash, "modulate:a", 0.0, 0.20)

	if badge != null:
		var badge_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		badge.scale = Vector2(1.15, 1.15)
		badge_tw.tween_property(badge, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if bar != null:
		var sheen: ColorRect = row_data.get("shine") as ColorRect
		if sheen != null:
			_animate_levelup_bar_sheen(sheen, bar)
			await get_tree().create_timer(0.10, true, false, true).timeout
			_animate_levelup_bar_sheen(sheen, bar)

	if crit_sound != null and crit_sound.stream != null:
		crit_sound.pitch_scale = 1.08
		crit_sound.play()

	screen_shake(7.0, 0.18)

	await get_tree().create_timer(0.28, true, false, true).timeout
	if is_instance_valid(flash):
		flash.queue_free()
		
func _show_levelup_center_burst(main_text: String, accent_color: Color) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 170
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var vp_size: Vector2 = get_viewport_rect().size

	var flash_rect: ColorRect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = accent_color
	flash_rect.modulate.a = 0.0
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash_rect)

	var glow_label: Label = Label.new()
	glow_label.text = main_text
	glow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glow_label.size = Vector2(vp_size.x, 140)
	glow_label.position = Vector2(0, (vp_size.y - 140) * 0.5 - 90)
	glow_label.add_theme_font_size_override("font_size", 88)
	glow_label.add_theme_color_override("font_color", accent_color)
	glow_label.add_theme_constant_override("outline_size", 18)
	glow_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05, 1.0))
	glow_label.modulate.a = 0.0
	glow_label.scale = Vector2(0.50, 0.50)
	layer.add_child(glow_label)

	var main_label: Label = Label.new()
	main_label.text = main_text
	main_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main_label.size = Vector2(vp_size.x, 140)
	main_label.position = glow_label.position
	main_label.add_theme_font_size_override("font_size", 76)
	main_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	main_label.add_theme_constant_override("outline_size", 10)
	main_label.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.08, 1.0))
	main_label.modulate.a = 0.0
	main_label.scale = Vector2(0.38, 0.38)
	layer.add_child(main_label)

	var tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.tween_property(flash_rect, "modulate:a", 0.20, 0.08)
	tw.tween_property(glow_label, "modulate:a", 1.0, 0.14)
	tw.tween_property(main_label, "modulate:a", 1.0, 0.12)
	tw.tween_property(glow_label, "scale", Vector2(1.18, 1.18), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(main_label, "scale", Vector2(1.0, 1.0), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.34, true, false, true).timeout

	var tw_out = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw_out.tween_property(flash_rect, "modulate:a", 0.0, 0.18)
	tw_out.tween_property(glow_label, "modulate:a", 0.0, 0.20)
	tw_out.tween_property(main_label, "modulate:a", 0.0, 0.18)
	tw_out.tween_property(glow_label, "scale", Vector2(1.30, 1.30), 0.20)
	tw_out.tween_property(main_label, "scale", Vector2(1.10, 1.10), 0.20)

	await tw_out.finished
	layer.queue_free()
	
func _make_levelup_circle(radius: float, point_count: int, color: Color) -> Polygon2D:
	var poly: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()

	for i in range(point_count):
		var angle: float = (TAU * float(i)) / float(point_count)
		pts.append(Vector2(cos(angle), sin(angle)) * radius)

	poly.polygon = pts
	poly.color = color
	return poly


func _spawn_levelup_halo(unit: Node2D, accent_color: Color) -> Node2D:
	var halo_root: Node2D = Node2D.new()
	halo_root.name = "LevelUpHalo"
	halo_root.position = Vector2(32, 32)
	halo_root.show_behind_parent = true
	halo_root.z_index = -1
	halo_root.scale = Vector2(0.22, 0.22)
	halo_root.modulate.a = 0.0
	unit.add_child(halo_root)

	var outer: Polygon2D = _make_levelup_circle(58.0, 40, Color(accent_color.r, accent_color.g, accent_color.b, 0.16))
	var middle: Polygon2D = _make_levelup_circle(44.0, 40, Color(1.0, 0.90, 0.34, 0.18))
	var inner: Polygon2D = _make_levelup_circle(30.0, 32, Color(1.0, 0.98, 0.72, 0.14))

	halo_root.add_child(outer)
	halo_root.add_child(middle)
	halo_root.add_child(inner)

	return halo_root

func _get_support_threshold_for_next_rank(unit_a: Node2D, unit_b: Node2D, current_rank: int) -> int:
	if unit_a == null or unit_b == null:
		return -1
	if unit_a.get("data") == null or unit_b.get("data") == null:
		return -1

	var name_a = get_support_name(unit_a)
	var name_b = get_support_name(unit_b)

	var support_file_found = null

	for s_file in unit_a.data.supports:
		if s_file.partner_name == name_b:
			support_file_found = s_file
			break

	if support_file_found == null:
		for s_file in unit_b.data.supports:
			if s_file.partner_name == name_a:
				support_file_found = s_file
				break

	if support_file_found == null:
		return -1

	if current_rank == 0:
		return int(support_file_found.points_for_c)
	elif current_rank == 1:
		return int(support_file_found.points_for_b)
	elif current_rank == 2:
		return int(support_file_found.points_for_a)

	return -1


func _get_next_support_rank_letter(current_rank: int) -> String:
	match current_rank:
		0:
			return "C"
		1:
			return "B"
		2:
			return "A"
		_:
			return ""


func _queue_support_ready_if_needed(unit_a: Node2D, unit_b: Node2D) -> void:
	if unit_a == null or unit_b == null:
		return

	var name_a = get_support_name(unit_a)
	var name_b = get_support_name(unit_b)
	var bond_key = CampaignManager.get_support_key(name_a, name_b)

	if _battle_support_ready_seen.has(bond_key):
		return

	var bond = CampaignManager.get_support_bond(name_a, name_b)

	var current_rank: int = int(bond.get("rank", 0))
	if current_rank >= 3:
		return

	var current_points: int = int(bond.get("points", 0))
	var needed_points: int = _get_support_threshold_for_next_rank(unit_a, unit_b, current_rank)

	if needed_points < 0:
		return

	if current_points >= needed_points:
		_battle_support_ready_seen[bond_key] = true
		_battle_support_ready_queue.append({
			"bond_key": bond_key,
			"unit_a_name": unit_a.unit_name,
			"unit_b_name": unit_b.unit_name,
			"next_rank": _get_next_support_rank_letter(current_rank)
		})
		_show_next_support_ready_popup()


func _show_next_support_ready_popup() -> void:
	if _support_popup_busy:
		return
	if _battle_support_ready_queue.is_empty():
		return

	_support_popup_busy = true
	var data: Dictionary = _battle_support_ready_queue.pop_front()

	var popup_layer := CanvasLayer.new()
	popup_layer.layer = 160
	popup_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(popup_layer)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 100)
	panel.position = Vector2((get_viewport_rect().size.x - 520) * 0.5, 70)
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_levelup_style(
		Color(0.06, 0.06, 0.10, 0.96),
		Color(0.85, 0.75, 0.25, 1.0),
		14
	))
	popup_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 14
	vbox.offset_top = 12
	vbox.offset_right = -14
	vbox.offset_bottom = -12
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "SUPPORT READY!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.42))
	vbox.add_child(title)

	var body := Label.new()
	body.text = data["unit_a_name"] + " & " + data["unit_b_name"] + " can now view Rank " + data["next_rank"] + "."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	vbox.add_child(body)

	var sub := Label.new()
	sub.text = "Visit a support conversation after battle."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.75, 0.78, 0.84))
	vbox.add_child(sub)

	if level_up_sound and level_up_sound.stream != null:
		level_up_sound.pitch_scale = 1.08
		level_up_sound.play()

	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

	await get_tree().create_timer(2.1, true, false, true).timeout

	var out_tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	out_tw.tween_property(panel, "modulate:a", 0.0, 0.18)
	out_tw.tween_property(panel, "position:y", panel.position.y - 20.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await out_tw.finished

	popup_layer.queue_free()
	_support_popup_busy = false

	if not _battle_support_ready_queue.is_empty():
		_show_next_support_ready_popup()


func _add_support_points_and_check(unit_a: Node2D, unit_b: Node2D, amount: int) -> void:
	if unit_a == null or unit_b == null:
		return
	if amount <= 0:
		return

	CampaignManager.add_support_points(get_support_name(unit_a), get_support_name(unit_b), amount)
	_queue_support_ready_if_needed(unit_a, unit_b)


# Forecast support line: shows passive support-combat bonus (Hit/Avo/Crit Avo) from get_support_combat_bonus.
func _get_forecast_support_text(unit: Node2D) -> String:
	if unit == null:
		return ""
	var sup: Dictionary = get_support_combat_bonus(unit)
	var h: int = int(sup.get("hit", 0))
	var a: int = int(sup.get("avo", 0))
	var c: int = int(sup.get("crit_avo", 0))
	if h <= 0 and a <= 0 and c <= 0:
		return "SUPPORT: --"
	var parts: PackedStringArray = []
	if h > 0: parts.append("+%d HIT" % h)
	if a > 0: parts.append("+%d AVO" % a)
	if c > 0: parts.append("+%d C.AVO" % c)
	return "SUPPORT: " + "  |  ".join(parts)


func _is_forecast_allied_unit(unit: Node2D) -> bool:
	if unit == null:
		return false
	return unit.get_parent() == player_container or (ally_container != null and unit.get_parent() == ally_container)


## Lines for support reactions + burn hints; mirrors execute_combat / _apply_hit_with_support_reactions / Dual Strike gates (no balance changes).
func _build_forecast_reaction_summary(attacker: Node2D, defender: Node2D, atk_wpn: Resource) -> String:
	var lines: Array[String] = []
	if attacker == null or defender == null:
		return ""

	var staff: bool = atk_wpn != null and (
		atk_wpn.get("is_healing_staff") == true
		or atk_wpn.get("is_buff_staff") == true
		or atk_wpn.get("is_debuff_staff") == true
	)
	if staff:
		lines.append("Staff: Guard / Dual Strike / Defy Death do not apply to this exchange.")
		return "\n".join(lines)

	# Dual Strike: allied attacker only; same gates as execute_combat (non-staff).
	if _is_forecast_allied_unit(attacker):
		var actx: Dictionary = get_best_support_context(attacker)
		var apart: Node2D = actx.get("partner", null) as Node2D
		var arank: int = int(actx.get("rank", 0))
		if apart != null and arank >= 2 and bool(actx.get("can_react", false)):
			var dual_pct: int = SUPPORT_DUAL_STRIKE_CHANCE_RANK3 if arank >= 3 else SUPPORT_DUAL_STRIKE_CHANCE_RANK2
			dual_pct += int(get_relationship_combat_modifiers(attacker).get("support_chance_bonus", 0))
			lines.append("Dual Strike chance (partner bonus hit after yours): ~%d%%" % clampi(dual_pct, 0, 100))

	# Guard & Defy Death: allied defender only; matches get_best_support_context + _apply_hit_with_support_reactions.
	if _is_forecast_allied_unit(defender):
		var dctx: Dictionary = get_best_support_context(defender)
		var dpartner: Node2D = dctx.get("partner", null) as Node2D
		var drank: int = int(dctx.get("rank", 0))
		var dcan: bool = bool(dctx.get("can_react", false))
		if dpartner != null and drank >= 2 and dcan:
			var guard_pct: int = SUPPORT_GUARD_CHANCE_RANK3 if drank >= 3 else SUPPORT_GUARD_CHANCE_RANK2
			guard_pct += int(get_relationship_combat_modifiers(defender).get("support_chance_bonus", 0))
			lines.append("Guard chance (partner takes this hit): ~%d%%" % clampi(guard_pct, 0, 100))
		if dpartner != null and drank >= 3 and dcan:
			if bool(_defy_death_used.get(defender.get_instance_id(), false)):
				lines.append("Defy Death: already used this battle for this unit.")
			else:
				lines.append("Defy Death: if a hit here would kill, survive at 1 HP once (A-rank bond).")

	if defender.has_meta("is_burning") and defender.get_meta("is_burning") == true:
		lines.append("Target is burning (fire damage after each enemy phase).")

	if _attacker_has_attack_skill(attacker, "Hellfire"):
		lines.append("Hellfire: strong minigame can ignite (burn DoT after enemy phase).")

	if _attacker_has_attack_skill(attacker, "Ballista Shot"):
		lines.append("Ballista Shot: on proc, bolt can overpenetrate — spill damage to a foe in the tile behind this target (same line).")

	if _attacker_has_attack_skill(attacker, "Charge"):
		lines.append("Charge: on proc, if another enemy stands behind this target in your line, they take collision damage and your impact is stronger.")

	if _attacker_has_attack_skill(attacker, "Fireball"):
		lines.append("Fireball: on proc, flames wash down the line — extra burn on a foe in the tile behind the target.")

	if _attacker_has_attack_skill(attacker, "Meteor Storm"):
		lines.append("Meteor Storm: on proc, a fragment may streak into a foe behind the target (same line) for extra splash damage.")

	if _attacker_has_attack_skill(attacker, "Deadeye Shot"):
		lines.append("Deadeye Shot: at range 3+, a successful proc gains extra precision damage.")

	if _attacker_has_attack_skill(attacker, "Smite"):
		lines.append("Smite: on proc, holy energy can splash to up to two foes orthogonally adjacent to the target.")

	if _attacker_has_attack_skill(attacker, "Volley"):
		lines.append("Volley: on a perfect proc, the second follow-up arrow can strike a different foe adjacent to the target.")

	if _attacker_has_attack_skill(attacker, "Rain of Arrows"):
		lines.append("Rain of Arrows: rear-rank pressure — extra damage to a foe in the tile behind the target (same line); non-perfect splash favors that foe when you must pick one.")

	if lines.is_empty():
		return ""
	return "\n".join(lines)


func _ensure_forecast_support_labels() -> void:
	if forecast_panel == null:
		return

	if forecast_atk_support_label == null:
		forecast_atk_support_label = Label.new()
		forecast_atk_support_label.name = "AtkSupportBonus"
		forecast_atk_support_label.position = forecast_atk_crit.position + Vector2(0, 26)
		forecast_atk_support_label.size = Vector2(240, 22)
		forecast_atk_support_label.add_theme_font_size_override("font_size", 16)
		forecast_atk_support_label.add_theme_color_override("font_color", Color(0.60, 0.95, 1.0))
		forecast_panel.add_child(forecast_atk_support_label)

	if forecast_def_support_label == null:
		forecast_def_support_label = Label.new()
		forecast_def_support_label.name = "DefSupportBonus"
		forecast_def_support_label.position = forecast_def_crit.position + Vector2(0, 26)
		forecast_def_support_label.size = Vector2(240, 22)
		forecast_def_support_label.add_theme_font_size_override("font_size", 16)
		forecast_def_support_label.add_theme_color_override("font_color", Color(0.60, 0.95, 1.0))
		forecast_panel.add_child(forecast_def_support_label)

	if forecast_instruction_label == null:
		forecast_instruction_label = Label.new()
		forecast_instruction_label.name = "ForecastInstruction"
		forecast_instruction_label.position = Vector2(8, 148)
		forecast_instruction_label.size = Vector2(384, 26)
		forecast_instruction_label.add_theme_font_size_override("font_size", 11)
		forecast_instruction_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9))
		forecast_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		forecast_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		forecast_instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		forecast_panel.add_child(forecast_instruction_label)

	if forecast_reaction_label == null:
		forecast_reaction_label = Label.new()
		forecast_reaction_label.name = "ForecastReactionSummary"
		forecast_reaction_label.position = Vector2(8, 174)
		forecast_reaction_label.size = Vector2(384, 28)
		forecast_reaction_label.add_theme_font_size_override("font_size", 10)
		forecast_reaction_label.add_theme_color_override("font_color", Color(0.90, 0.84, 0.62))
		forecast_reaction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		forecast_reaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		forecast_reaction_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		forecast_panel.add_child(forecast_reaction_label)

	# Keep bottom stack above Confirm/Cancel (~y 201+).
	if forecast_instruction_label != null:
		forecast_instruction_label.position = Vector2(8, 148)
		forecast_instruction_label.size = Vector2(384, 26)
	if forecast_reaction_label != null:
		forecast_reaction_label.position = Vector2(8, 174)
		forecast_reaction_label.size = Vector2(384, 28)

func apply_campaign_settings() -> void:
	camera_follows_enemies = CampaignManager.battle_follow_enemy_camera

	zoom_step = CampaignManager.battle_zoom_step
	min_zoom = CampaignManager.battle_min_zoom
	max_zoom = CampaignManager.battle_max_zoom
	zoom_to_cursor = CampaignManager.battle_zoom_to_cursor
	edge_margin = CampaignManager.battle_edge_margin

	# Player can disable fog on fog-enabled maps, but cannot force fog onto maps
	# that were not authored for it.
	use_fog_of_war = use_fog_of_war and CampaignManager.battle_allow_fog_of_war

	if minimap_container:
		minimap_container.visible = CampaignManager.battle_show_minimap_default
		minimap_container.modulate = Color(
			minimap_container.modulate.r,
			minimap_container.modulate.g,
			minimap_container.modulate.b,
			CampaignManager.battle_minimap_opacity
		)

	if map_drawer:
		map_drawer.queue_redraw()

	if battle_log:
		battle_log.visible = CampaignManager.battle_show_log

	if path_line:
		path_line.visible = CampaignManager.battle_show_path_preview

	show_danger_zone = CampaignManager.battle_show_danger_zone_default
	if show_danger_zone:
		_danger_zone_recalc_dirty = false
		calculate_full_danger_zone()
	else:
		_danger_zone_recalc_dirty = false
		danger_zone_move_tiles.clear()
		danger_zone_attack_tiles.clear()

	if main_camera != null:
		_camera_zoom_target = clampf(main_camera.zoom.x, min_zoom, max_zoom)

	queue_redraw()

func _class_can_equip_weapon(class_data: ClassData, weapon: WeaponData) -> bool:
	if class_data == null or weapon == null:
		return false

	# Staff-like items are controlled by flags, not weapon_type alone
	if weapon.get("is_healing_staff") == true:
		return class_data.can_use_healing_staff

	if weapon.get("is_buff_staff") == true:
		return class_data.can_use_buff_staff

	if weapon.get("is_debuff_staff") == true:
		return class_data.can_use_debuff_staff

	return class_data.allowed_weapon_types.has(int(weapon.weapon_type))


func _unit_can_equip_weapon(unit: Node2D, weapon: WeaponData) -> bool:
	if unit == null or weapon == null:
		return false

	if not ("active_class_data" in unit):
		return false

	return _class_can_equip_weapon(unit.active_class_data, weapon)

func _weapon_type_name_safe(w_type: int) -> String:
	match int(w_type):
		0: return "Sword"
		1: return "Lance"
		2: return "Axe"
		3: return "Bow"
		4: return "Tome"
		5: return "None"
		6: return "Knife"
		7: return "Firearm"
		8: return "Fist"
		9: return "Instrument"
		10: return "Dark Tome"
		_: return "Unknown"

func _format_class_weapon_permissions(class_res: Resource) -> String:
	if class_res == null:
		return "Weapons: Unknown"

	var parts: Array[String] = []

	if class_res.get("allowed_weapon_types") != null:
		for raw_type in class_res.allowed_weapon_types:
			parts.append(_weapon_type_name_safe(int(raw_type)))

	if class_res.get("can_use_healing_staff") == true:
		parts.append("Healing Staff")
	if class_res.get("can_use_buff_staff") == true:
		parts.append("Buff Staff")
	if class_res.get("can_use_debuff_staff") == true:
		parts.append("Debuff Staff")

	if parts.is_empty():
		return "Weapons: None"

	return "Weapons: " + ", ".join(parts)


func _class_can_equip_item(class_res: Resource, item: Resource) -> bool:
	if class_res == null or item == null:
		return false

	if not (item is WeaponData):
		return true

	if item.get("is_healing_staff") == true:
		return class_res.get("can_use_healing_staff") == true
	if item.get("is_buff_staff") == true:
		return class_res.get("can_use_buff_staff") == true
	if item.get("is_debuff_staff") == true:
		return class_res.get("can_use_debuff_staff") == true

	if class_res.get("allowed_weapon_types") != null:
		return class_res.allowed_weapon_types.has(int(item.weapon_type))

	return true


func _unit_can_use_item_for_ui(unit: Node2D, item: Resource) -> bool:
	if unit == null:
		return false
	if item == null:
		return false
	if not ("active_class_data" in unit):
		return false

	return _class_can_equip_item(unit.active_class_data, item)


func _get_unit_target_for_details() -> Node2D:
	if current_state == player_state and player_state.active_unit != null:
		return player_state.active_unit
	return get_occupant_at(cursor_grid_pos)
	
func _ensure_detailed_unit_info_panel() -> void:
	if detailed_unit_info_layer != null and is_instance_valid(detailed_unit_info_layer):
		return

	detailed_unit_info_layer = CanvasLayer.new()
	detailed_unit_info_layer.layer = 120
	add_child(detailed_unit_info_layer)

	var dimmer = ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.color = Color(0, 0, 0, 0.78)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.visible = false
	detailed_unit_info_layer.add_child(dimmer)

	detailed_unit_info_panel = Panel.new()
	detailed_unit_info_panel.name = "DetailedUnitInfoPanel"
	detailed_unit_info_panel.custom_minimum_size = Vector2(1180, 760)
	detailed_unit_info_panel.visible = false
	detailed_unit_info_layer.add_child(detailed_unit_info_panel)

	detailed_unit_info_panel.anchor_left = 0.5
	detailed_unit_info_panel.anchor_top = 0.5
	detailed_unit_info_panel.anchor_right = 0.5
	detailed_unit_info_panel.anchor_bottom = 0.5
	detailed_unit_info_panel.offset_left = -590
	detailed_unit_info_panel.offset_top = -380
	detailed_unit_info_panel.offset_right = 590
	detailed_unit_info_panel.offset_bottom = 380

	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	root.add_theme_constant_override("separation", 14)
	detailed_unit_info_panel.add_child(root)

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	root.add_child(header)

	detailed_unit_info_portrait = TextureRect.new()
	detailed_unit_info_portrait.custom_minimum_size = Vector2(190, 190)
	detailed_unit_info_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detailed_unit_info_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(detailed_unit_info_portrait)

	var name_box = VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 10)
	header.add_child(name_box)

	detailed_unit_info_name = Label.new()
	detailed_unit_info_name.add_theme_font_size_override("font_size", 40)
	name_box.add_child(detailed_unit_info_name)

	detailed_unit_info_close_btn = Button.new()
	detailed_unit_info_close_btn.text = "Close"
	detailed_unit_info_close_btn.custom_minimum_size = Vector2(170, 56)
	detailed_unit_info_close_btn.add_theme_font_size_override("font_size", 22)
	detailed_unit_info_close_btn.pressed.connect(func():
		_hide_detailed_unit_info_panel()
	)
	name_box.add_child(detailed_unit_info_close_btn)

	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)

	var left_panel = Panel.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(left_panel)

	var right_panel = Panel.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(right_panel)

	detailed_unit_info_left_text = RichTextLabel.new()
	detailed_unit_info_left_text.bbcode_enabled = true
	detailed_unit_info_left_text.fit_content = false
	detailed_unit_info_left_text.scroll_active = true
	detailed_unit_info_left_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	left_panel.add_child(detailed_unit_info_left_text)

	detailed_unit_info_right_text = RichTextLabel.new()
	detailed_unit_info_right_text.bbcode_enabled = true
	detailed_unit_info_right_text.fit_content = false
	detailed_unit_info_right_text.scroll_active = true
	detailed_unit_info_right_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	right_panel.add_child(detailed_unit_info_right_text)
			
func _show_detailed_unit_info_panel(unit: Node2D) -> void:
	_ensure_detailed_unit_info_panel()

	if unit == null:
		return

	var dimmer = detailed_unit_info_layer.get_node("Dimmer")
	dimmer.visible = true
	detailed_unit_info_panel.visible = true

	var portrait_tex: Texture2D = null
	if unit.get("data") != null and unit.data.get("portrait") != null:
		portrait_tex = unit.data.portrait
	elif unit.get("active_class_data") != null and unit.active_class_data.get("promoted_portrait") != null:
		portrait_tex = unit.active_class_data.promoted_portrait

	detailed_unit_info_portrait.texture = portrait_tex
	detailed_unit_info_name.text = unit.unit_name
	detailed_unit_info_left_text.bbcode_text = _build_detailed_unit_info_left_text(unit)
	detailed_unit_info_right_text.bbcode_text = _build_detailed_unit_info_right_text(unit)
	
func _hide_detailed_unit_info_panel() -> void:
	if detailed_unit_info_panel == null:
		return

	var dimmer = detailed_unit_info_layer.get_node("Dimmer")
	dimmer.visible = false
	detailed_unit_info_panel.visible = false
	
func _build_detailed_unit_info_text(unit: Node2D) -> String:
	if unit == null:
		return "[center]No unit selected.[/center]"

	var lines: Array[String] = []

	var class_label: String = "Unknown"
	var class_res: Resource = null
	if unit.get("active_class_data") != null:
		class_res = unit.active_class_data

	if class_res != null and class_res.get("job_name") != null:
		class_label = class_res.job_name
	elif unit.get("unit_class_name") != null:
		class_label = unit.unit_class_name

	lines.append("[font_size=30][b]" + unit.unit_name + "[/b][/font_size]")
	lines.append("Class: [color=cyan]" + class_label + "[/color]")
	lines.append("Level: " + str(unit.level) + "    XP: " + str(unit.experience))
	lines.append("Move: " + str(unit.move_range))
	lines.append("")

	lines.append("[color=gold][b]STATS[/b][/color]")
	lines.append("HP: " + str(unit.current_hp) + " / " + str(unit.max_hp))
	lines.append("STR: " + str(unit.strength) + "    MAG: " + str(unit.magic))
	lines.append("DEF: " + str(unit.defense) + "    RES: " + str(unit.resistance))
	lines.append("SPD: " + str(unit.speed) + "    AGI: " + str(unit.agility))
	lines.append("")

	if unit.equipped_weapon != null:
		lines.append("[color=gold][b]EQUIPPED WEAPON[/b][/color]")
		lines.append(unit.equipped_weapon.weapon_name + " (" + _weapon_type_name_safe(int(unit.equipped_weapon.weapon_type)) + ")")
		lines.append("Mt: " + str(unit.equipped_weapon.might) + "    Hit: +" + str(unit.equipped_weapon.hit_bonus))
		lines.append("Range: " + str(unit.equipped_weapon.min_range) + "-" + str(unit.equipped_weapon.max_range))
		if unit.equipped_weapon.get("current_durability") != null:
			lines.append("Durability: " + str(unit.equipped_weapon.current_durability) + " / " + str(unit.equipped_weapon.max_durability))
		lines.append("")
	else:
		lines.append("[color=gold][b]EQUIPPED WEAPON[/b][/color]")
		lines.append("None")
		lines.append("")

	if class_res != null:
		lines.append("[color=gold][b]WEAPON PERMISSIONS[/b][/color]")
		lines.append(_format_class_weapon_permissions(class_res))
		lines.append("")

		lines.append("[color=gold][b]CLASS BONUSES[/b][/color]")
		var class_bonus_parts: Array[String] = []

		if class_res.get("hp_bonus") != null and int(class_res.hp_bonus) != 0:
			class_bonus_parts.append("HP %+d" % int(class_res.hp_bonus))
		if class_res.get("str_bonus") != null and int(class_res.str_bonus) != 0:
			class_bonus_parts.append("STR %+d" % int(class_res.str_bonus))
		if class_res.get("mag_bonus") != null and int(class_res.mag_bonus) != 0:
			class_bonus_parts.append("MAG %+d" % int(class_res.mag_bonus))
		if class_res.get("def_bonus") != null and int(class_res.def_bonus) != 0:
			class_bonus_parts.append("DEF %+d" % int(class_res.def_bonus))
		if class_res.get("res_bonus") != null and int(class_res.res_bonus) != 0:
			class_bonus_parts.append("RES %+d" % int(class_res.res_bonus))
		if class_res.get("spd_bonus") != null and int(class_res.spd_bonus) != 0:
			class_bonus_parts.append("SPD %+d" % int(class_res.spd_bonus))
		if class_res.get("agi_bonus") != null and int(class_res.agi_bonus) != 0:
			class_bonus_parts.append("AGI %+d" % int(class_res.agi_bonus))

		if class_bonus_parts.is_empty():
			lines.append("None")
		else:
			lines.append(", ".join(class_bonus_parts))
		lines.append("")

		lines.append("[color=gold][b]GROWTH BONUSES[/b][/color]")
		var growth_parts: Array[String] = []

		if class_res.get("hp_growth_bonus") != null and int(class_res.hp_growth_bonus) != 0:
			growth_parts.append("HP %+d%%" % int(class_res.hp_growth_bonus))
		if class_res.get("str_growth_bonus") != null and int(class_res.str_growth_bonus) != 0:
			growth_parts.append("STR %+d%%" % int(class_res.str_growth_bonus))
		if class_res.get("mag_growth_bonus") != null and int(class_res.mag_growth_bonus) != 0:
			growth_parts.append("MAG %+d%%" % int(class_res.mag_growth_bonus))
		if class_res.get("def_growth_bonus") != null and int(class_res.def_growth_bonus) != 0:
			growth_parts.append("DEF %+d%%" % int(class_res.def_growth_bonus))
		if class_res.get("res_growth_bonus") != null and int(class_res.res_growth_bonus) != 0:
			growth_parts.append("RES %+d%%" % int(class_res.res_growth_bonus))
		if class_res.get("spd_growth_bonus") != null and int(class_res.spd_growth_bonus) != 0:
			growth_parts.append("SPD %+d%%" % int(class_res.spd_growth_bonus))
		if class_res.get("agi_growth_bonus") != null and int(class_res.agi_growth_bonus) != 0:
			growth_parts.append("AGI %+d%%" % int(class_res.agi_growth_bonus))

		if growth_parts.is_empty():
			lines.append("None")
		else:
			lines.append(", ".join(growth_parts))
		lines.append("")

		lines.append("[color=gold][b]PROMOTION BONUSES[/b][/color]")
		var promo_parts: Array[String] = []

		if class_res.get("promo_hp_bonus") != null and int(class_res.promo_hp_bonus) != 0:
			promo_parts.append("HP %+d" % int(class_res.promo_hp_bonus))
		if class_res.get("promo_str_bonus") != null and int(class_res.promo_str_bonus) != 0:
			promo_parts.append("STR %+d" % int(class_res.promo_str_bonus))
		if class_res.get("promo_mag_bonus") != null and int(class_res.promo_mag_bonus) != 0:
			promo_parts.append("MAG %+d" % int(class_res.promo_mag_bonus))
		if class_res.get("promo_def_bonus") != null and int(class_res.promo_def_bonus) != 0:
			promo_parts.append("DEF %+d" % int(class_res.promo_def_bonus))
		if class_res.get("promo_res_bonus") != null and int(class_res.promo_res_bonus) != 0:
			promo_parts.append("RES %+d" % int(class_res.promo_res_bonus))
		if class_res.get("promo_spd_bonus") != null and int(class_res.promo_spd_bonus) != 0:
			promo_parts.append("SPD %+d" % int(class_res.promo_spd_bonus))
		if class_res.get("promo_agi_bonus") != null and int(class_res.promo_agi_bonus) != 0:
			promo_parts.append("AGI %+d" % int(class_res.promo_agi_bonus))

		if promo_parts.is_empty():
			lines.append("None")
		else:
			lines.append(", ".join(promo_parts))
		lines.append("")

	if "unlocked_abilities" in unit and unit.unlocked_abilities.size() > 0:
		lines.append("[color=gold][b]ABILITIES[/b][/color]")
		lines.append(", ".join(unit.unlocked_abilities))
		lines.append("")
	elif unit.get("ability") != null and str(unit.ability) != "":
		lines.append("[color=gold][b]ABILITY[/b][/color]")
		lines.append(str(unit.ability))
		lines.append("")

	if "inventory" in unit and unit.inventory.size() > 0:
		lines.append("[color=gold][b]INVENTORY[/b][/color]")
		for item in unit.inventory:
			if item == null:
				continue

			var item_name: String = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
			var marker: String = ""
			if item is WeaponData:
				marker = " [color=lime](usable)[/color]" if _unit_can_use_item_for_ui(unit, item) else " [color=red](locked)[/color]"
			lines.append("• " + str(item_name) + marker)

	return "[font_size=26]" + "\n".join(lines) + "[/font_size]"
			
func _on_unit_details_button_pressed() -> void:
	var target_unit = _get_unit_target_for_details()
	if target_unit != null:
		_show_detailed_unit_info_panel(target_unit)

func _build_detailed_unit_info_left_text(unit: Node2D) -> String:
	if unit == null:
		return "[center]No unit selected.[/center]"

	var lines: Array[String] = []

	var class_label: String = "Unknown"
	var class_res: Resource = null
	if unit.get("active_class_data") != null:
		class_res = unit.active_class_data

	if class_res != null and class_res.get("job_name") != null:
		class_label = class_res.job_name
	elif unit.get("unit_class_name") != null:
		class_label = unit.unit_class_name

	lines.append("[font_size=28]" + unit.unit_name + "[/font_size]")
	lines.append("Class: [color=cyan]" + class_label + "[/color]")
	lines.append("Level: " + str(unit.level) + "    XP: " + str(unit.experience))
	lines.append("Move: " + str(unit.move_range))
	lines.append("")

	lines.append("[color=gold]Stats[/color]")
	lines.append("HP: " + str(unit.current_hp) + " / " + str(unit.max_hp))
	lines.append("[color=coral]STR:[/color] " + str(unit.strength) + "    [color=orchid]MAG:[/color] " + str(unit.magic))
	lines.append("[color=palegreen]DEF:[/color] " + str(unit.defense) + "    [color=aquamarine]RES:[/color] " + str(unit.resistance))
	lines.append("[color=skyblue]SPD:[/color] " + str(unit.speed) + "    [color=wheat]AGI:[/color] " + str(unit.agility))

	var poise_text := "?"
	if unit.has_method("get_current_poise") and unit.has_method("get_max_poise"):
		poise_text = str(unit.get_current_poise()) + "/" + str(unit.get_max_poise())
	lines.append("[color=gold]POISE:[/color] " + poise_text)
	lines.append("")

	lines.append("[color=gold]Equipped Weapon[/color]")
	if unit.equipped_weapon != null:
		lines.append(unit.equipped_weapon.weapon_name + " (" + _weapon_type_name_safe(int(unit.equipped_weapon.weapon_type)) + ")")
		lines.append("Mt: " + str(unit.equipped_weapon.might) + "    Hit: +" + str(unit.equipped_weapon.hit_bonus))
		lines.append("Range: " + str(unit.equipped_weapon.min_range) + "-" + str(unit.equipped_weapon.max_range))
		if unit.equipped_weapon.get("current_durability") != null:
			lines.append("Durability: " + str(unit.equipped_weapon.current_durability) + " / " + str(unit.equipped_weapon.max_durability))
	else:
		lines.append("None")
	lines.append("")

	if class_res != null:
		lines.append("[color=gold]Weapon Permissions[/color]")
		lines.append(_format_class_weapon_permissions(class_res))
		lines.append("")

		lines.append("[color=gold]Class Bonuses[/color]")
		var class_bonus_parts: Array[String] = []

		if class_res.get("hp_bonus") != null and int(class_res.hp_bonus) != 0:
			class_bonus_parts.append("HP %+d" % int(class_res.hp_bonus))
		if class_res.get("str_bonus") != null and int(class_res.str_bonus) != 0:
			class_bonus_parts.append("[color=coral]STR %+d[/color]" % int(class_res.str_bonus))
		if class_res.get("mag_bonus") != null and int(class_res.mag_bonus) != 0:
			class_bonus_parts.append("[color=orchid]MAG %+d[/color]" % int(class_res.mag_bonus))
		if class_res.get("def_bonus") != null and int(class_res.def_bonus) != 0:
			class_bonus_parts.append("[color=palegreen]DEF %+d[/color]" % int(class_res.def_bonus))
		if class_res.get("res_bonus") != null and int(class_res.res_bonus) != 0:
			class_bonus_parts.append("[color=aquamarine]RES %+d[/color]" % int(class_res.res_bonus))
		if class_res.get("spd_bonus") != null and int(class_res.spd_bonus) != 0:
			class_bonus_parts.append("[color=skyblue]SPD %+d[/color]" % int(class_res.spd_bonus))
		if class_res.get("agi_bonus") != null and int(class_res.agi_bonus) != 0:
			class_bonus_parts.append("[color=wheat]AGI %+d[/color]" % int(class_res.agi_bonus))

		lines.append("None" if class_bonus_parts.is_empty() else ", ".join(class_bonus_parts))
		lines.append("")

		lines.append("[color=gold]Growth Bonuses[/color]")
		var growth_parts: Array[String] = []

		if class_res.get("hp_growth_bonus") != null and int(class_res.hp_growth_bonus) != 0:
			growth_parts.append("HP %+d%%" % int(class_res.hp_growth_bonus))
		if class_res.get("str_growth_bonus") != null and int(class_res.str_growth_bonus) != 0:
			growth_parts.append("[color=coral]STR %+d%%[/color]" % int(class_res.str_growth_bonus))
		if class_res.get("mag_growth_bonus") != null and int(class_res.mag_growth_bonus) != 0:
			growth_parts.append("[color=orchid]MAG %+d%%[/color]" % int(class_res.mag_growth_bonus))
		if class_res.get("def_growth_bonus") != null and int(class_res.def_growth_bonus) != 0:
			growth_parts.append("[color=palegreen]DEF %+d%%[/color]" % int(class_res.def_growth_bonus))
		if class_res.get("res_growth_bonus") != null and int(class_res.res_growth_bonus) != 0:
			growth_parts.append("[color=aquamarine]RES %+d%%[/color]" % int(class_res.res_growth_bonus))
		if class_res.get("spd_growth_bonus") != null and int(class_res.spd_growth_bonus) != 0:
			growth_parts.append("[color=skyblue]SPD %+d%%[/color]" % int(class_res.spd_growth_bonus))
		if class_res.get("agi_growth_bonus") != null and int(class_res.agi_growth_bonus) != 0:
			growth_parts.append("[color=wheat]AGI %+d%%[/color]" % int(class_res.agi_growth_bonus))

		lines.append("None" if growth_parts.is_empty() else ", ".join(growth_parts))
		lines.append("")

		lines.append("[color=gold]Promotion Bonuses[/color]")
		var promo_parts: Array[String] = []

		if class_res.get("promo_hp_bonus") != null and int(class_res.promo_hp_bonus) != 0:
			promo_parts.append("HP %+d" % int(class_res.promo_hp_bonus))
		if class_res.get("promo_str_bonus") != null and int(class_res.promo_str_bonus) != 0:
			promo_parts.append("[color=coral]STR %+d[/color]" % int(class_res.promo_str_bonus))
		if class_res.get("promo_mag_bonus") != null and int(class_res.promo_mag_bonus) != 0:
			promo_parts.append("[color=orchid]MAG %+d[/color]" % int(class_res.promo_mag_bonus))
		if class_res.get("promo_def_bonus") != null and int(class_res.promo_def_bonus) != 0:
			promo_parts.append("[color=palegreen]DEF %+d[/color]" % int(class_res.promo_def_bonus))
		if class_res.get("promo_res_bonus") != null and int(class_res.promo_res_bonus) != 0:
			promo_parts.append("[color=aquamarine]RES %+d[/color]" % int(class_res.promo_res_bonus))
		if class_res.get("promo_spd_bonus") != null and int(class_res.promo_spd_bonus) != 0:
			promo_parts.append("[color=skyblue]SPD %+d[/color]" % int(class_res.promo_spd_bonus))
		if class_res.get("promo_agi_bonus") != null and int(class_res.promo_agi_bonus) != 0:
			promo_parts.append("[color=wheat]AGI %+d[/color]" % int(class_res.promo_agi_bonus))

		lines.append("None" if promo_parts.is_empty() else ", ".join(promo_parts))

	return "[font_size=24]" + "\n".join(lines) + "[/font_size]"
	
func _build_detailed_unit_info_right_text(unit: Node2D) -> String:
	if unit == null:
		return ""

	var lines: Array[String] = []

	if "unlocked_abilities" in unit and unit.unlocked_abilities.size() > 0:
		lines.append("[color=gold]Abilities[/color]")
		lines.append(", ".join(unit.unlocked_abilities))
		lines.append("")
	elif unit.get("ability") != null and str(unit.ability) != "":
		lines.append("[color=gold]Ability[/color]")
		lines.append(str(unit.ability))
		lines.append("")

	lines.append("[color=gold]Inventory[/color]")
	if "inventory" in unit and unit.inventory.size() > 0:
		for item in unit.inventory:
			if item == null:
				continue

			var item_name: String = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
			var marker: String = ""

			if item is WeaponData:
				marker = " [color=lime](usable)[/color]" if _unit_can_use_item_for_ui(unit, item) else " [color=red](locked)[/color]"

				var w_type := _weapon_type_name_safe(int(item.weapon_type))
				var extra := " | Mt " + str(item.might) + " | Hit +" + str(item.hit_bonus) + " | Rng " + str(item.min_range) + "-" + str(item.max_range)
				lines.append("• " + str(item_name) + " (" + w_type + ")" + marker)
				lines.append("   " + extra)
			else:
				lines.append("• " + str(item_name))
	else:
		lines.append("None")

	# --- Relationships section (trust, mentorship, rivalry; top entries among deployed) ---
	lines.append("")
	lines.append("[color=gold]Relationships[/color]")
	var unit_id: String = get_relationship_id(unit)
	var candidate_ids: Array = []
	if player_container != null:
		for u in player_container.get_children():
			if is_instance_valid(u) and u != unit:
				candidate_ids.append(get_relationship_id(u))
	var rel_entries: Array = CampaignManager.get_top_relationship_entries_for_unit(unit_id, candidate_ids, 9)
	if rel_entries.is_empty():
		lines.append("No notable bonds yet.")
	else:
		for entry in rel_entries:
			lines.append("• " + CampaignManager.format_relationship_row_bbcode(entry))

	lines.append("")
	lines.append("[color=gold]Notes[/color]")
	lines.append("Green = usable")
	lines.append("Red = class locked")

	return "[font_size=24]" + "\n".join(lines) + "[/font_size]"

func _is_valid_combat_unit(node: Node2D) -> bool:
	if node == null or node.is_queued_for_deletion():
		return false

	# Explicit opt-out for helper nodes / spawners
	if node.has_method("is_targetable") and not node.is_targetable():
		return false

	# Must at least look like a combat-capable unit
	if node.get("current_hp") == null:
		return false
	if node.get("speed") == null:
		return false
	if node.get("strength") == null:
		return false
	if node.get("defense") == null:
		return false

	return true
	
func _run_melee_crit_lunge(attacker: Node2D, _defender: Node2D, orig_pos: Vector2, lunge_dir: Vector2) -> void:
	"""Crit-only melee sequence: charge back with jitter, very fast strike, brief hold with crit sound, attacker left at enemy for PHASE F return."""
	if not is_instance_valid(attacker):
		return
	var recoil_pos: Vector2 = orig_pos - (lunge_dir * 6.0)
	var perp: Vector2 = Vector2(-lunge_dir.y, lunge_dir.x)
	var strike_pos: Vector2 = orig_pos + (lunge_dir * 16.0)

	# Short charge-back with subtle jitter (0.06s)
	var charge_tween: Tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	charge_tween.tween_method(
		func(progress: float) -> void:
			if not is_instance_valid(attacker): return
			var base_pos: Vector2 = orig_pos.lerp(recoil_pos, progress)
			var jitter: float = sin(progress * 20.0) * 2.0
			attacker.global_position = base_pos + (perp * jitter),
		0.0, 1.0, 0.06
	)
	await charge_tween.finished
	if not is_instance_valid(attacker): return

	# Very fast strike toward target (0.05s)
	spawn_dash_effect(attacker.global_position, strike_pos)
	var strike_tween: Tween = create_tween()
	strike_tween.tween_property(attacker, "global_position", strike_pos, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await strike_tween.finished
	if not is_instance_valid(attacker): return

	# Brief hold; crit sound on impact
	if crit_sound != null and crit_sound.stream != null:
		crit_sound.play()
	await get_tree().create_timer(0.10).timeout
	# Attacker remains at strike_pos; PHASE F returns to orig_pos later


func _run_melee_normal_lunge(attacker: Node2D, _defender: Node2D, orig_pos: Vector2, lunge_dir: Vector2) -> void:
	"""Snappy normal melee: short recoil, crisp strike, brief contact, quick return. Attacker ends at orig_pos."""
	if not is_instance_valid(attacker):
		return
	var recoil_pos: Vector2 = orig_pos - (lunge_dir * 3.0)
	var strike_pos: Vector2 = orig_pos + (lunge_dir * 16.0)

	# Short startup recoil (0.03s)
	var recoil_tween: Tween = create_tween()
	recoil_tween.tween_property(attacker, "global_position", recoil_pos, 0.03).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await recoil_tween.finished
	if not is_instance_valid(attacker): return

	# Crisp forward strike (0.06s)
	spawn_dash_effect(attacker.global_position, strike_pos)
	var strike_tween: Tween = create_tween()
	strike_tween.tween_property(attacker, "global_position", strike_pos, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await strike_tween.finished
	if not is_instance_valid(attacker): return

	# Brief contact (0.03s)
	await get_tree().create_timer(0.03).timeout
	if not is_instance_valid(attacker): return

	# Quick return to orig_pos (0.06s)
	var return_tween: Tween = create_tween()
	return_tween.tween_property(attacker, "global_position", orig_pos, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await return_tween.finished


func _play_critical_impact(focus_world: Vector2) -> void:
	_spawn_fullscreen_impact_flash(Color(1.0, 0.98, 0.88), 0.44, 0.16)
	_spawn_fullscreen_impact_flash(Color(1.0, 0.72, 0.20), 0.16, 0.22)

	# Offset punch only — no zoom manipulation
	_start_impact_camera(focus_world, 1.0, 0.040, 0.18)

	await _do_hit_stop(0.018, 0.14, 0.11)
	
func _play_guard_break_impact(focus_world: Vector2) -> void:
	_spawn_fullscreen_impact_flash(Color(1.0, 0.55, 0.18), 0.28, 0.12)
	_spawn_fullscreen_impact_flash(Color(1.0, 0.82, 0.35), 0.10, 0.18)

	# Smaller offset punch than crits
	_start_impact_camera(focus_world, 1.0, 0.030, 0.14)

	await _do_hit_stop(0.012, 0.22, 0.07)
