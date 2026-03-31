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
signal coop_remote_enemy_turn_finished
signal coop_remote_escort_turn_finished
signal loot_window_closed


# =============================================================================
# ENUMS / CONSTANTS / PRELOADS
# =============================================================================

enum Objective { ROUT_ENEMY, SURVIVE_TURNS, DEFEND_TARGET }
enum UISfx { MOVE_OK, TARGET_OK, INVALID, INVENTORY_EQUIP, INVENTORY_USE }

const CELL_SIZE = Vector2i(64, 64)
## Co-op: wire schema for [method coop_net_build_authoritative_combat_snapshot] / peer apply (no second combat sim).
const COOP_AUTH_BATTLE_SNAPSHOT_VER: int = 1
const COOP_ENEMY_PHASE_SETUP_SNAPSHOT_VER: int = 1

const LEVELUP_HOLD_TIME_NORMAL := 4.2
const LEVELUP_HOLD_TIME_PERFECT := 6.0
const LEVELUP_ROW_REVEAL_DELAY := 0.50

const PATH_ALPHA_MIN := 0.55
const PATH_ALPHA_MAX := 1.00
const PATH_PULSE_TIME := 0.35
const PATH_PREVIEW_Z := 100
const PATH_PREVIEW_FG_WIDTH := 4.0
const PATH_PREVIEW_UNDER_WIDTH := 11.0
const PATH_PREVIEW_PULSE_W_FG := 1.35
const PATH_PREVIEW_PULSE_W_UNDER := 2.2
const PATH_PREVIEW_CORNER_INSET_LOW := 10.0
const PATH_PREVIEW_CORNER_INSET_HIGH := 16.0
const PATH_PREVIEW_DASH_SHADER := preload("res://path_preview_dash.gdshader")

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
const CoopHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopHelpers.gd")
const CoopReplayHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopReplayHelpers.gd")
const CoopRuntimeSyncHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopRuntimeSyncHelpers.gd")
const SupportHelpers = preload("res://Scripts/Core/BattleField/BattleFieldSupportHelpers.gd")
const InventoryUiHelpers = preload("res://Scripts/Core/BattleField/BattleFieldInventoryUiHelpers.gd")
const DrawHelpers = preload("res://Scripts/Core/BattleField/BattleFieldDrawHelpers.gd")
const PathCursorHelpers = preload("res://Scripts/Core/BattleField/BattleFieldPathfindingCursorHelpers.gd")
const TradeInventoryHelpers = preload("res://Scripts/Core/BattleField/BattleFieldTradeInventoryHelpers.gd")
const CombatOrchestrationHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCombatOrchestrationHelpers.gd")
const InventoryActionHelpers = preload("res://Scripts/Core/BattleField/BattleFieldInventoryActionHelpers.gd")
const PromotionChoiceUiHelpers = preload("res://Scripts/Core/BattleField/BattleFieldPromotionChoiceUiHelpers.gd")
const PromotionVfxHelpers = preload("res://Scripts/Core/BattleField/BattleFieldPromotionVfxHelpers.gd")
const ObjectiveUiHelpers = preload("res://Scripts/Core/BattleField/BattleFieldObjectiveUiHelpers.gd")
const CinematicDialogueHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCinematicDialogueHelpers.gd")
const MinimapHelpers = preload("res://Scripts/Core/BattleField/BattleFieldMinimapHelpers.gd")
const StatusIconVfxHelpers = preload("res://Scripts/Core/BattleField/BattleFieldStatusIconVfxHelpers.gd")
const CombatVfxHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCombatVfxHelpers.gd")
const GoldVfxHelpers = preload("res://Scripts/Core/BattleField/BattleFieldGoldVfxHelpers.gd")
const TurnOrchestrationHelpers = preload("res://Scripts/Core/BattleField/BattleFieldTurnOrchestrationHelpers.gd")
const DefensiveReactionHelpers = preload("res://Scripts/Core/BattleField/BattleFieldDefensiveReactionHelpers.gd")
const DefensiveReactionFlowHelpers = preload("res://Scripts/Core/BattleField/BattleFieldDefensiveReactionFlowHelpers.gd")
const DefensiveAbilityFlowHelpers = preload("res://Scripts/Core/BattleField/BattleFieldDefensiveAbilityFlowHelpers.gd")
const AttackResolutionHelpers = preload("res://Scripts/Core/BattleField/BattleFieldAttackResolutionHelpers.gd")
const PostStrikeCleanupHelpers = preload("res://Scripts/Core/BattleField/BattleFieldPostStrikeCleanupHelpers.gd")
const ForcedMovementTacticalHelpers = preload("res://Scripts/Core/BattleField/BattleFieldForcedMovementTacticalHelpers.gd")
const CombatCleanupHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCombatCleanupHelpers.gd")
const StrikeSequenceHelpers = preload("res://Scripts/Core/BattleField/BattleFieldStrikeSequenceHelpers.gd")
const CombatForecastHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCombatForecastHelpers.gd")
const CoopCombatRequestHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopCombatRequestHelpers.gd")
const CoopEnemyCombatNetHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopEnemyCombatNetHelpers.gd")
const CoopOutboundSyncHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopOutboundSyncHelpers.gd")
const CoopRemoteSyncActionHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopRemoteSyncActionHelpers.gd")
const CoopRngSyncHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopRngSyncHelpers.gd")
const CoopMockSessionHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopMockSessionHelpers.gd")

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

# Reinforcement telegraphing: expose existing EnemySpawner slot timers without new map schema.
const REINFORCEMENT_WARNING_ENEMY_PHASES := 1
const REINFORCEMENT_OVERLAY_LATER_FILL := Color(0.98, 0.84, 0.28, 0.08)
const REINFORCEMENT_OVERLAY_LATER_BORDER := Color(0.98, 0.84, 0.28, 0.65)
const REINFORCEMENT_OVERLAY_SOON_FILL := Color(1.0, 0.58, 0.08, 0.18)
const REINFORCEMENT_OVERLAY_SOON_BORDER := Color(1.0, 0.70, 0.16, 0.95)
const DECOR_FOG_SHADOW_TINT := Color(0.42, 0.45, 0.55, 0.96)
const TACTICAL_UI_BG := Color(0.08, 0.075, 0.06, 0.92)
const TACTICAL_UI_BG_ALT := Color(0.13, 0.115, 0.085, 0.95)
const TACTICAL_UI_BG_SOFT := Color(0.17, 0.15, 0.11, 0.88)
const TACTICAL_UI_BORDER := Color(0.82, 0.71, 0.38, 0.95)
const TACTICAL_UI_BORDER_MUTED := Color(0.44, 0.39, 0.27, 0.95)
const TACTICAL_UI_TEXT := Color(0.94, 0.92, 0.84, 1.0)
const TACTICAL_UI_TEXT_MUTED := Color(0.72, 0.69, 0.60, 1.0)
const TACTICAL_UI_ACCENT := Color(0.90, 0.80, 0.37, 1.0)
const TACTICAL_UI_ACCENT_SOFT := Color(0.74, 0.86, 0.42, 1.0)
const TACTICAL_UI_PRIMARY_FILL := Color(0.67, 0.52, 0.16, 0.98)
const TACTICAL_UI_PRIMARY_HOVER := Color(0.78, 0.61, 0.22, 0.98)
const TACTICAL_UI_PRIMARY_PRESS := Color(0.49, 0.36, 0.10, 1.0)
const TACTICAL_UI_SECONDARY_FILL := Color(0.21, 0.16, 0.08, 0.98)
const TACTICAL_UI_SECONDARY_HOVER := Color(0.30, 0.23, 0.11, 1.0)
const TACTICAL_UI_SECONDARY_PRESS := Color(0.14, 0.10, 0.05, 1.0)
const TACTICAL_UI_MARGIN := 24.0
const TACTICAL_UI_RAIL_WIDTH := 308.0
## Pre-battle roster is wider than the tactical rail so names and the bond readout fit.
const TACTICAL_DEPLOY_ROSTER_PANEL_WIDTH := 348.0
const TACTICAL_DEPLOY_ROSTER_BONDS_H := 252.0
## Min ItemList height (logical px); tuned so several units are visible without a tiny strip above the bond block.
const TACTICAL_DEPLOY_ROSTER_MIN_LIST_H := 132.0
## Pre-battle only: less bottom margin than tactical HUD so the deploy column can use more of the viewport.
const TACTICAL_DEPLOY_ROSTER_VIEWPORT_BOTTOM_RESERVE := 20.0
const META_DEPLOYMENT_RAIL_COLLAPSED := &"deployment_rail_collapsed"
## Start Battle button alpha when deploy roster is hidden (map-first view).
const DEPLOY_START_BATTLE_MODULATE_A_COLLAPSED := 0.58
const TACTICAL_UI_BOTTOM_HEIGHT := 212.0
const TACTICAL_UI_HUD_SCALE := 1.5
const TACTICAL_UI_BOTTOM_PANEL_SCALE_MULT := 0.85
const TACTICAL_UI_LOG_HEIGHT_RATIO := 0.75
const TACTICAL_UI_BOTTOM_EDGE_MARGIN := 8.0
## End Turn nudge when all local units have acted: stronger modulate + scale breathing (see _update_skip_button_visual_modulate).
const END_TURN_PULSE_TIME_SCALE := 0.0046
const END_TURN_PULSE_MOD_DEPTH := 0.32
const END_TURN_PULSE_SCALE_CENTER := 1.072
const END_TURN_PULSE_SCALE_DEPTH := 0.062
## Runtime inventory grid / description padding (applied once from [method _apply_inventory_panel_spacing]; scenes keep canonical node names).
const INVENTORY_UI_SCROLL_CONTENT_PAD := 12
const INVENTORY_UI_GRID_SEP := 10
const INVENTORY_UI_VBOX_SEP := 12
const INVENTORY_UI_INFO_PANEL_OUTER_PAD := 10
const INVENTORY_UI_DESC_TEXT_PAD := 12
const INVENTORY_UI_ITEMLIST_EXTRA_MARGIN := 8
const META_INVENTORY_UI_SPACING_APPLIED := "_inv_ui_spacing_v1"
const LOOT_INFO_BACKDROP_OUTER_PAD := 12
const LOOT_INFO_DESC_INNER_PAD := 14
const META_LOOT_DESC_LAYOUT_BASE := "_loot_desc_layout_base_rect"
const ITEM_DESC_RICHTEXT_MIN_H := 72.0
const ITEM_DESC_RICHTEXT_MAX_H := 620.0
const ITEM_DESC_RICHTEXT_EXTRA_PAD := 12.0
const INVENTORY_DESC_PANEL_MIN_H := 52.0
const INVENTORY_DESC_PANEL_PAD := 14.0
const UNIT_INFO_STAT_BAR_CAP := 50.0
const UNIT_INFO_STAT_TIER_CYAN := Color(0.28, 0.88, 1.0, 1.0)
const UNIT_INFO_STAT_TIER_PURPLE := Color(0.76, 0.48, 1.0, 1.0)
const UNIT_INFO_STAT_TIER_ORANGE := Color(1.0, 0.64, 0.22, 1.0)
const UNIT_INFO_STAT_TIER_WHITE := Color(0.96, 0.96, 0.98, 1.0)

# Boss Personal Dialogue (V1): trigger logic and tracking in BattleField; content in BossPersonalDialogueDB.
const BossDialogueDB = preload("res://Scripts/Narrative/BossPersonalDialogueDB.gd")
# Defy Death rescue lines by savior support_personality; content in SupportRescueDialogueDB.
const SupportRescueDialogueDB = preload("res://Scripts/Narrative/SupportRescueDialogueDB.gd")

const FloatingTextScene = preload("res://Scenes/FloatingText.tscn")

## Consecutive floaters on the same unit within ~0.4s stack upward for readability.
var _floater_stack_by_unit: Dictionary = {}


var detailed_unit_info_layer: CanvasLayer
var detailed_unit_info_panel: Panel
var detailed_unit_info_name: Label
var detailed_unit_info_meta_label: Label
var detailed_unit_info_summary_text: RichTextLabel
var detailed_unit_info_weapon_badge: Label
var detailed_unit_info_weapon_icon: TextureRect
var detailed_unit_info_weapon_name: Label
var detailed_unit_info_portrait: TextureRect
var detailed_unit_info_left_text: RichTextLabel
var detailed_unit_info_right_text: RichTextLabel
var detailed_unit_info_relationships_root: VBoxContainer
var detailed_unit_info_close_btn: Button
var detailed_unit_info_primary_widgets: Dictionary = {}
var detailed_unit_info_stat_widgets: Dictionary = {}
var detailed_unit_info_growth_widgets: Dictionary = {}
var detailed_unit_info_anim_tween: Tween
var field_log_toggle_btn: Button
var field_log_toggle_tween: Tween
var deploy_roster_toggle_btn: Button
var deploy_roster_toggle_tween: Tween

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
@onready var target_cursor_sprite: Sprite2D = get_node_or_null("TargetCursor/Sprite2D") as Sprite2D
@onready var path_line_under: Line2D = get_node_or_null("PathLineUnder") as Line2D
@onready var path_line: Line2D = $PathLine
@onready var path_end_marker: Node2D = get_node_or_null("PathEndMarker") as Node2D
@onready var path_preview_ticks: Node2D = get_node_or_null("PathPreviewTicks") as Node2D
@onready var hover_glow = $HoverGlow

@onready var minimap_container: Control = %MiniMapContainer
@onready var map_drawer: CanvasItem = %MapDrawer
@onready var decor_layer: Node = get_node_or_null("Decor")


# =============================================================================
# UI - UNIT INFO / CORE HUD
# =============================================================================

@onready var unit_info_panel = $UI/UnitInfoPanel
@onready var ui_root: CanvasLayer = $UI
@onready var unit_portrait = $UI/UnitInfoPanel/PortraitRect
@onready var unit_name_label = $UI/UnitInfoPanel/NameLabel
@onready var unit_hp_label = $UI/UnitInfoPanel/HPLabel
@onready var unit_stats_label = $UI/UnitInfoPanel/StatsLabel
@onready var support_btn = $UI/UnitInfoPanel/SupportButton
@onready var open_inv_button = $UI/UnitInfoPanel/OpenInvButton
@onready var unit_details_button: Button = get_node_or_null("UI/UnitDetailsButton") as Button
var inspected_unit: Node2D = null

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
var forecast_atk_hp_bar: ProgressBar
var forecast_def_hp_bar: ProgressBar
var _unit_info_primary_widgets: Dictionary = {}
var _unit_info_primary_anim_tween: Tween
var _unit_info_primary_anim_source_id: int = -1
var _unit_info_primary_animating: bool = false
var _unit_info_stat_widgets: Dictionary = {}
var _unit_info_stat_anim_tween: Tween
var _unit_info_stat_source_id: int = -1
var _unit_info_stat_anim_source_id: int = -1
var _unit_info_stat_animating: bool = false


# =============================================================================
# UI - INVENTORY / CONVOY
# =============================================================================

@onready var inventory_panel = $UI/InventoryPanel
var inv_scroll: ScrollContainer
var unit_grid: GridContainer
var convoy_grid: GridContainer
var inv_desc_label: RichTextLabel
@onready var equip_button = $UI/InventoryPanel/EquipButton
@onready var use_button = $UI/InventoryPanel/UseButton


# =============================================================================
# UI - LOOT
# =============================================================================

@onready var loot_window = $UI/LootWindow
@onready var loot_item_list = $UI/LootWindow/ItemList
@onready var close_loot_button = $UI/LootWindow/CloseLootButton
var loot_desc_label: RichTextLabel
var loot_item_info_panel: Panel


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
var _last_enemy_reinforcement_warning_turn: int = -1


# =============================================================================
# FOG OF WAR RUNTIME STATE
# =============================================================================

var fow_grid: Dictionary = {}
var fow_display_alphas: Dictionary = {}
var _decor_fow_base_modulates: Dictionary = {}

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
var _path_fg_dash_material: ShaderMaterial = null
## World-space centers for MP tick overlay (see [member path_preview_ticks]).
var _path_preview_tick_world: Array[Vector2] = []

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
## After equip, flash this item's slot once the unit grid is rebuilt ([method _populate_unit_inventory_list]).
var _battle_inv_flash_item: Resource = null
var unit_managing_inventory: Node2D = null

var pending_loot: Array[Resource] = []
var _deferred_battle_result_after_loot: String = ""

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
var _mock_coop_local_prebattle_ready: bool = false
var _mock_coop_remote_prebattle_ready: bool = false
var _mock_coop_prebattle_transition_pending: bool = false
var _mock_coop_local_player_phase_ready: bool = false
var _mock_coop_remote_player_phase_ready: bool = false
var _mock_coop_player_phase_transition_pending: bool = false
var _skip_button_base_modulate: Color = Color.WHITE
var _skip_button_base_modulate_captured: bool = false
var _mock_partner_placeholder_combat_log_done: bool = false
var _mock_coop_start_battle_button_base_text: String = ""
var _coop_remote_combat_replay_active: bool = false
var _coop_remote_battle_result_applying: bool = false
var _coop_host_battle_result_broadcast: String = ""
var _coop_finalized_battle_result: String = ""
var _coop_waiting_for_host_battle_result: String = ""
var _coop_battle_result_resolution_in_progress: String = ""
var _coop_remote_escort_turn_completed: bool = false
var _coop_pending_escort_destination_victory: bool = false

const MOCK_COOP_BATTLE_OWNER_META: String = "mock_coop_battle_owner"
const MOCK_COOP_COMMAND_ID_META: String = "mock_coop_command_id"
const MOCK_COOP_OWNER_LOCAL: String = "local"
const MOCK_COOP_OWNER_REMOTE: String = "remote"
const MOCK_COOP_COMMANDER_DEPLOYMENT_SLOT_COUNT: int = 2
const MOCK_COOP_PREBATTLE_BENCH_OFFSCREEN_XY: float = -1000.0
const COOP_REMOTE_AI_CAMERA_OFFSET_Y: float = 250.0
const COOP_REMOTE_AI_CAMERA_LEFT_MARGIN: float = -400.0
const COOP_REMOTE_AI_CAMERA_RIGHT_MARGIN: float = 400.0
const COOP_REMOTE_AI_CAMERA_TOP_MARGIN: float = -250.0
const COOP_REMOTE_AI_CAMERA_BOTTOM_MARGIN: float = 400.0

func get_consumed_mock_coop_battle_handoff_snapshot() -> Dictionary:
	return CoopMockSessionHelpers.get_consumed_mock_coop_battle_handoff_snapshot(self)


func get_mock_coop_battle_context_snapshot() -> Dictionary:
	return CoopMockSessionHelpers.get_mock_coop_battle_context_snapshot(self)


func get_mock_coop_unit_ownership_snapshot() -> Dictionary:
	return CoopMockSessionHelpers.get_mock_coop_unit_ownership_snapshot(self)


## Returns MOCK_COOP_OWNER_LOCAL / MOCK_COOP_OWNER_REMOTE, or "" if unset / not mock co-op.
func get_mock_coop_unit_owner_for_unit(unit: Node) -> String:
	return CoopMockSessionHelpers.get_mock_coop_unit_owner_for_unit(self, unit)


func is_mock_coop_unit_ownership_active() -> bool:
	return CoopMockSessionHelpers.is_mock_coop_unit_ownership_active(self)


## True when mock co-op ownership is on and this unit is assigned to the remote partner (not locally commandable).
func is_local_player_command_blocked_for_mock_coop_unit(unit: Node) -> bool:
	return CoopMockSessionHelpers.is_local_player_command_blocked_for_mock_coop_unit(self, unit)


func notify_mock_coop_remote_command_blocked(unit: Node2D) -> void:
	CoopMockSessionHelpers.notify_mock_coop_remote_command_blocked(self, unit)


func try_allow_local_player_select_unit_for_command(unit: Node2D) -> bool:
	return CoopMockSessionHelpers.try_allow_local_player_select_unit_for_command(self, unit)


func _infer_mock_coop_command_prefix_for_node(unit: Node2D) -> String:
	return CoopMockSessionHelpers._infer_mock_coop_command_prefix_for_node(self, unit)


func _ensure_mock_coop_command_id_for_node(unit: Node2D) -> String:
	return CoopMockSessionHelpers._ensure_mock_coop_command_id_for_node(self, unit)


func _get_mock_coop_command_id(unit_or_name: Variant) -> String:
	return CoopMockSessionHelpers._get_mock_coop_command_id(self, unit_or_name)


func _seed_mock_coop_command_ids_for_live_battle_nodes() -> void:
	CoopMockSessionHelpers._seed_mock_coop_command_ids_for_live_battle_nodes(self)


func _coop_focus_camera_on_world_point(world_point: Vector2, duration: float) -> void:
	await CoopMockSessionHelpers._coop_focus_camera_on_world_point(self, world_point, duration)


func _coop_focus_camera_on_unit(unit: Node2D, duration: float = 0.55) -> void:
	await CoopMockSessionHelpers._coop_focus_camera_on_unit(self, unit, duration)


func _coop_focus_camera_on_action(attacker: Node2D, target: Node2D, duration: float = 0.4) -> void:
	await CoopMockSessionHelpers._coop_focus_camera_on_action(self, attacker, target, duration)


func _mock_coop_battle_sync_active() -> bool:
	return CoopMockSessionHelpers._mock_coop_battle_sync_active(self)


func _mock_coop_prebattle_ready_sync_active() -> bool:
	return CoopMockSessionHelpers._mock_coop_prebattle_ready_sync_active(self)


func _mock_coop_role_key_from_command_id(command_id: String) -> String:
	return CoopMockSessionHelpers._mock_coop_role_key_from_command_id(self, command_id)


func get_mock_coop_allowed_prebattle_slots_for_command_id(command_id: String) -> Array[Vector2i]:
	return CoopMockSessionHelpers.get_mock_coop_allowed_prebattle_slots_for_command_id(self, command_id)


func get_mock_coop_allowed_prebattle_slots_for_unit(unit: Node2D) -> Array[Vector2i]:
	return CoopMockSessionHelpers.get_mock_coop_allowed_prebattle_slots_for_unit(self, unit)


func is_mock_coop_prebattle_slot_allowed_for_unit(unit: Node2D, slot: Vector2i) -> bool:
	return CoopMockSessionHelpers.is_mock_coop_prebattle_slot_allowed_for_unit(self, unit, slot)


func _reset_mock_coop_prebattle_ready_state() -> void:
	CoopMockSessionHelpers._reset_mock_coop_prebattle_ready_state(self)


func _update_mock_coop_start_battle_button_state() -> void:
	CoopMockSessionHelpers._update_mock_coop_start_battle_button_state(self)


func _mock_coop_try_advance_prebattle_after_ready_sync() -> void:
	CoopMockSessionHelpers._mock_coop_try_advance_prebattle_after_ready_sync(self)


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
var _coop_remote_enemy_turn_completed: bool = false

func _exit_tree() -> void:
	_coop_net_reset_battle_rng_sync()
	CoopExpeditionSessionManager.unregister_runtime_coop_battle_sync_target(self)


func _coop_net_reset_battle_rng_sync() -> void:
	CoopReplayHelpers.coop_net_reset_battle_rng_sync(self)


func coop_enet_enemy_turn_host_authority_active() -> bool:
	return CoopReplayHelpers.coop_enet_enemy_turn_host_authority_active(self)


func coop_enet_is_host_authority_enemy_turn_host() -> bool:
	return CoopReplayHelpers.coop_enet_is_host_authority_enemy_turn_host(self)


func coop_enet_should_wait_for_host_authority_enemy_turn() -> bool:
	return CoopReplayHelpers.coop_enet_should_wait_for_host_authority_enemy_turn(self)


func coop_enet_guest_wait_for_enemy_turn_end() -> void:
	await CoopReplayHelpers.coop_enet_guest_wait_for_enemy_turn_end(self)


func coop_enet_escort_turn_host_authority_active() -> bool:
	return CoopReplayHelpers.coop_enet_escort_turn_host_authority_active(self)


func coop_enet_is_host_authority_escort_turn_host() -> bool:
	return CoopReplayHelpers.coop_enet_is_host_authority_escort_turn_host(self)


func coop_enet_should_wait_for_host_authority_escort_turn() -> bool:
	return CoopReplayHelpers.coop_enet_should_wait_for_host_authority_escort_turn(self)


func coop_enet_guest_wait_for_escort_turn_end() -> void:
	await CoopReplayHelpers.coop_enet_guest_wait_for_escort_turn_end(self)


func _coop_normalize_battle_result(result: String) -> String:
	return CoopReplayHelpers.coop_normalize_battle_result(result)


func coop_enet_battle_result_host_authority_active() -> bool:
	return CoopReplayHelpers.coop_enet_battle_result_host_authority_active(self)


func coop_enet_should_wait_for_host_authoritative_battle_result() -> bool:
	return CoopReplayHelpers.coop_enet_should_wait_for_host_authoritative_battle_result(self)


func _coop_send_host_authoritative_battle_result(result: String) -> void:
	CoopReplayHelpers.coop_send_host_authoritative_battle_result(self, result)


func _coop_wait_for_host_authoritative_battle_result(result: String) -> void:
	CoopReplayHelpers.coop_wait_for_host_authoritative_battle_result(self, result)


func _is_loot_window_active() -> bool:
	return CoopReplayHelpers.is_loot_window_active(self)


func _wait_for_loot_window_close() -> void:
	await CoopReplayHelpers.wait_for_loot_window_close(self)


func _defer_battle_result_until_loot_if_needed(result: String) -> bool:
	return CoopReplayHelpers.defer_battle_result_until_loot_if_needed(self, result)


func _apply_deferred_battle_result_after_loot(result: String) -> void:
	await CoopReplayHelpers.apply_deferred_battle_result_after_loot(self, result)


func _coop_wire_serialize_items(items: Array) -> Array:
	return CoopHelpers.coop_wire_serialize_items(self, items)


func _coop_wire_deserialize_items(raw: Variant) -> Array:
	return CoopHelpers.coop_wire_deserialize_items(self, raw)


func _coop_wire_resource_path(res: Resource) -> String:
	return CoopHelpers.coop_wire_resource_path(self, res)


func _coop_wire_serialize_item_single(item: Resource) -> Variant:
	return CoopHelpers.coop_wire_serialize_item_single(self, item)


func _coop_wire_deserialize_item_single(raw: Variant) -> Resource:
	return CoopHelpers.coop_wire_deserialize_item_single(self, raw)


func _coop_capture_enemy_death_loot_for_sync(source_unit: Node2D, total_gold: int, items: Array, recipient: Node2D) -> void:
	if not _coop_combat_loot_capture_active:
		return
	if total_gold <= 0 and items.is_empty():
		return
	var entry: Dictionary = {"gold": total_gold}
	if source_unit != null and is_instance_valid(source_unit):
		var gp: Vector2i = get_grid_pos(source_unit)
		entry["gx"] = gp.x
		entry["gy"] = gp.y
		var source_id: String = _get_mock_coop_command_id(source_unit)
		if source_id != "":
			entry["source_id"] = source_id
	if recipient != null and is_instance_valid(recipient):
		var recipient_id: String = _get_mock_coop_command_id(recipient)
		if recipient_id != "":
			entry["recipient_id"] = recipient_id
	if not items.is_empty():
		entry["items"] = _coop_wire_serialize_items(items)
	_coop_combat_loot_capture_events.append(entry)


func _coop_apply_remote_synced_enemy_death_loot_events(raw: Variant) -> void:
	if typeof(raw) != TYPE_ARRAY:
		return
	var combined_items: Array = []
	var recipient_id: String = ""
	for event_raw in raw as Array:
		if not (event_raw is Dictionary):
			continue
		var event: Dictionary = event_raw as Dictionary
		var gold_amount: int = int(event.get("gold", 0))
		if gold_amount > 0:
			var world_pos := Vector2.ZERO
			if event.has("gx") and event.has("gy"):
				world_pos = Vector2(int(event.get("gx", 0)) * CELL_SIZE.x, int(event.get("gy", 0)) * CELL_SIZE.y)
			animate_flying_gold(world_pos, gold_amount)
			if battle_log != null and battle_log.visible:
				add_combat_log("Found " + str(gold_amount) + " gold.", "yellow")
		var items: Array = _coop_wire_deserialize_items(event.get("items", []))
		if not items.is_empty():
			combined_items.append_array(items)
			if recipient_id == "":
				recipient_id = str(event.get("recipient_id", "")).strip_edges()
	if combined_items.is_empty():
		return
	var recipient: Node2D = null
	if recipient_id != "":
		recipient = _coop_find_player_side_unit_by_relationship_id(recipient_id)
	pending_loot.clear()
	pending_loot.append_array(combined_items)
	loot_recipient = recipient
	show_loot_window()


func _coop_build_runtime_unit_wire_snapshot(unit: Node2D) -> Dictionary:
	if unit == null or not is_instance_valid(unit) or unit.is_queued_for_deletion():
		return {}
	var unit_id: String = _get_mock_coop_command_id(unit)
	if unit_id == "":
		return {}
	var gp: Vector2i = get_grid_pos(unit)
	var entry: Dictionary = {
		"id": unit_id,
		"gx": gp.x,
		"gy": gp.y,
		"visible": true,
		"modulate": [1.0, 1.0, 1.0, 1.0],
	}
	var scene_path: String = str(unit.get("scene_file_path")).strip_edges()
	if scene_path == "":
		if unit.get_parent() == enemy_container and enemy_scene != null:
			scene_path = str(enemy_scene.resource_path).strip_edges()
		elif player_unit_scene != null:
			scene_path = str(player_unit_scene.resource_path).strip_edges()
	if scene_path != "":
		entry["scene_path"] = scene_path
	var data_res: Resource = unit.get("data") as Resource
	var data_path: String = _coop_wire_resource_path(data_res)
	if data_path != "":
		entry["data_path"] = data_path
	var class_res: Resource = unit.get("active_class_data") as Resource
	var class_path: String = _coop_wire_resource_path(class_res)
	if class_path != "":
		entry["class_data"] = class_path
	var portrait_res: Resource = unit.get("portrait") as Resource
	var portrait_path: String = _coop_wire_resource_path(portrait_res)
	if portrait_path != "":
		entry["portrait"] = portrait_path
	var sprite_res: Resource = unit.get("battle_sprite") as Resource
	var sprite_path: String = _coop_wire_resource_path(sprite_res)
	if sprite_path != "":
		entry["battle_sprite"] = sprite_path
	if unit.get("unit_name") != null:
		entry["unit_name"] = str(unit.get("unit_name"))
	if unit.get("unit_class_name") != null:
		entry["unit_class_name"] = str(unit.get("unit_class_name"))
	if unit.get("team") != null:
		entry["team"] = int(unit.get("team"))
	if unit.get("is_enemy") != null:
		entry["is_enemy"] = bool(unit.get("is_enemy"))
	if unit.get("is_custom_avatar") != null:
		entry["is_custom_avatar"] = bool(unit.get("is_custom_avatar"))
	for key in ["level", "experience", "max_hp", "current_hp", "strength", "magic", "defense", "resistance", "speed", "agility", "move_range", "skill_points", "ai_intelligence", "experience_reward"]:
		var val: Variant = unit.get(key)
		if val != null:
			entry[key] = int(val)
	for key in ["has_moved", "is_exhausted", "is_defending"]:
		var flag_val: Variant = unit.get(key)
		if flag_val != null:
			entry[key] = bool(flag_val)
	if unit.get("move_points_used_this_turn") != null:
		entry["move_points_used_this_turn"] = float(unit.get("move_points_used_this_turn"))
	if unit.get("move_type") != null:
		entry["move_type"] = unit.get("move_type")
	if unit.get("ability") != null:
		entry["ability"] = unit.get("ability")
	var unit_tags_raw: Variant = unit.get("unit_tags")
	if unit_tags_raw is Array:
		entry["unit_tags"] = (unit_tags_raw as Array).duplicate(true)
	for list_key in ["traits", "rookie_legacies", "base_class_legacies", "promoted_class_legacies", "unlocked_skills"]:
		var list_raw: Variant = unit.get(list_key)
		if list_raw is Array:
			entry[list_key] = (list_raw as Array).duplicate(true)
	var inv_raw: Variant = unit.get("inventory")
	if inv_raw is Array:
		entry["inventory"] = _coop_wire_serialize_items(inv_raw as Array)
	var eq_raw: Resource = unit.get("equipped_weapon") as Resource
	var eq_ser: Variant = _coop_wire_serialize_item_single(eq_raw)
	if typeof(eq_ser) == TYPE_DICTIONARY and not (eq_ser as Dictionary).is_empty():
		entry["equipped_weapon"] = eq_ser
	elif eq_ser is String and str(eq_ser).strip_edges() != "":
		entry["equipped_weapon"] = eq_ser
	if unit is CanvasItem:
		var ci: CanvasItem = unit as CanvasItem
		entry["visible"] = ci.visible
		entry["modulate"] = [ci.modulate.r, ci.modulate.g, ci.modulate.b, ci.modulate.a]
	return entry


func _coop_instantiate_runtime_unit_from_snapshot(entry: Dictionary, target_parent: Node) -> Node2D:
	if target_parent == null:
		return null
	var scene_path: String = str(entry.get("scene_path", "")).strip_edges()
	var packed: PackedScene = null
	if scene_path != "":
		var loaded_scene: Resource = load(scene_path)
		if loaded_scene is PackedScene:
			packed = loaded_scene as PackedScene
	if packed == null:
		if target_parent == enemy_container and enemy_scene != null:
			packed = enemy_scene
		elif player_unit_scene != null:
			packed = player_unit_scene
	if packed == null:
		if OS.is_debug_build():
			push_warning("Coop enemy phase setup: failed to load unit scene for '%s'" % str(entry.get("id", "")))
		return null
	var unit: Node2D = packed.instantiate() as Node2D
	if unit == null:
		return null
	var unit_id: String = str(entry.get("id", "")).strip_edges()
	if unit_id != "":
		unit.set_meta(MOCK_COOP_COMMAND_ID_META, unit_id)
	var data_path: String = str(entry.get("data_path", "")).strip_edges()
	if data_path != "":
		var data_loaded: Resource = load(data_path) as Resource
		if data_loaded != null and unit.get("data") != null:
			unit.set("data", data_loaded.duplicate(true))
			var data_copy: Resource = unit.get("data") as Resource
			if data_copy != null and data_path != "":
				data_copy.set_meta("original_path", data_path)
	target_parent.add_child(unit)
	if unit.has_signal("died") and not unit.died.is_connected(_on_unit_died):
		unit.died.connect(_on_unit_died)
	if unit.has_signal("leveled_up") and not unit.leveled_up.is_connected(_on_unit_leveled_up):
		unit.leveled_up.connect(_on_unit_leveled_up)
	return unit


func _coop_apply_runtime_unit_wire_snapshot(entry: Dictionary, target_parent: Node) -> Node2D:
	var unit_id: String = str(entry.get("id", "")).strip_edges()
	if unit_id == "":
		return null
	var unit: Node2D = _coop_find_unit_by_relationship_id_any_side(unit_id)
	if unit == null or not is_instance_valid(unit) or unit.is_queued_for_deletion():
		unit = _coop_instantiate_runtime_unit_from_snapshot(entry, target_parent)
	if unit == null or not is_instance_valid(unit):
		return null
	var gx: int = int(entry.get("gx", get_grid_pos(unit).x))
	var gy: int = int(entry.get("gy", get_grid_pos(unit).y))
	unit.position = Vector2(gx * CELL_SIZE.x, gy * CELL_SIZE.y)
	for key in ["unit_name", "unit_class_name", "move_type", "ability"]:
		if entry.has(key):
			unit.set(key, entry[key])
	for key in ["team", "level", "experience", "max_hp", "current_hp", "strength", "magic", "defense", "resistance", "speed", "agility", "move_range", "skill_points", "ai_intelligence", "experience_reward"]:
		if entry.has(key):
			unit.set(key, int(entry[key]))
	for key in ["has_moved", "is_exhausted", "is_defending"]:
		if entry.has(key) and unit.get(key) != null:
			unit.set(key, bool(entry[key]))
	if entry.has("move_points_used_this_turn") and unit.get("move_points_used_this_turn") != null:
		unit.set("move_points_used_this_turn", float(entry["move_points_used_this_turn"]))
	if entry.has("is_enemy") and unit.get("is_enemy") != null:
		unit.set("is_enemy", bool(entry["is_enemy"]))
	if entry.has("is_custom_avatar") and unit.get("is_custom_avatar") != null:
		unit.set("is_custom_avatar", bool(entry["is_custom_avatar"]))
	if entry.has("class_data") and unit.get("active_class_data") != null:
		var class_loaded: Resource = load(str(entry["class_data"])) as Resource
		if class_loaded != null:
			unit.set("active_class_data", class_loaded)
	if entry.has("portrait") and unit.get("portrait") != null:
		var portrait_loaded: Resource = load(str(entry["portrait"])) as Resource
		if portrait_loaded != null:
			unit.set("portrait", portrait_loaded)
	if entry.has("battle_sprite") and unit.get("battle_sprite") != null:
		var sprite_loaded: Resource = load(str(entry["battle_sprite"])) as Resource
		if sprite_loaded != null:
			unit.set("battle_sprite", sprite_loaded)
	if entry.has("traits") and unit.get("traits") != null:
		unit.set("traits", (entry["traits"] as Array).duplicate(true))
	if entry.has("rookie_legacies") and unit.get("rookie_legacies") != null:
		unit.set("rookie_legacies", (entry["rookie_legacies"] as Array).duplicate(true))
	if entry.has("base_class_legacies") and unit.get("base_class_legacies") != null:
		unit.set("base_class_legacies", (entry["base_class_legacies"] as Array).duplicate(true))
	if entry.has("promoted_class_legacies") and unit.get("promoted_class_legacies") != null:
		unit.set("promoted_class_legacies", (entry["promoted_class_legacies"] as Array).duplicate(true))
	if entry.has("unlocked_skills") and unit.get("unlocked_skills") != null:
		unit.set("unlocked_skills", (entry["unlocked_skills"] as Array).duplicate(true))
	if entry.has("unit_tags") and unit.get("unit_tags") != null:
		unit.set("unit_tags", (entry["unit_tags"] as Array).duplicate(true))
	if entry.has("inventory") and unit.get("inventory") != null:
		var inv_items: Array = _coop_wire_deserialize_items(entry["inventory"])
		unit.inventory.clear()
		unit.inventory.append_array(inv_items)
	if entry.has("equipped_weapon") and unit.get("equipped_weapon") != null:
		var eq_loaded: Resource = _coop_wire_deserialize_item_single(entry["equipped_weapon"])
		if eq_loaded != null:
			unit.set("equipped_weapon", eq_loaded)
	if unit.get("health_bar") != null:
		unit.health_bar.value = unit.current_hp
	if unit is CanvasItem:
		var ci: CanvasItem = unit as CanvasItem
		ci.visible = bool(entry.get("visible", true))
		var mod_raw: Variant = entry.get("modulate", [])
		if mod_raw is Array and (mod_raw as Array).size() >= 4:
			var mod_arr: Array = mod_raw as Array
			ci.modulate = Color(float(mod_arr[0]), float(mod_arr[1]), float(mod_arr[2]), float(mod_arr[3]))
	return unit


func _coop_build_enemy_phase_setup_snapshot() -> Dictionary:
	var enemy_units: Array = []
	if enemy_container != null:
		for child in enemy_container.get_children():
			if not child is Node2D:
				continue
			var enemy: Node2D = child as Node2D
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
				continue
			var unit_snap: Dictionary = _coop_build_runtime_unit_wire_snapshot(enemy)
			if not unit_snap.is_empty():
				enemy_units.append(unit_snap)
	var spawners: Array = []
	if destructibles_container != null:
		for child in destructibles_container.get_children():
			if not child is Node2D:
				continue
			var node: Node2D = child as Node2D
			if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.has_method("process_turn"):
				continue
			var spawner_id: String = _get_mock_coop_command_id(node)
			if spawner_id == "":
				continue
			var entry: Dictionary = {"id": spawner_id}
			var script_res: Script = node.get_script() as Script
			if script_res != null and str(script_res.resource_path).strip_edges() != "":
				entry["script_path"] = str(script_res.resource_path).strip_edges()
			if node.get("has_warned") != null:
				entry["has_warned"] = bool(node.get("has_warned"))
			if node.get("has_triggered") != null:
				entry["has_triggered"] = bool(node.get("has_triggered"))
			var slot_timers_raw: Variant = node.get("slot_timers")
			if slot_timers_raw is Array:
				entry["slot_timers"] = (slot_timers_raw as Array).duplicate(true)
			if node is CanvasItem:
				var ci: CanvasItem = node as CanvasItem
				entry["visible"] = ci.visible
				entry["alpha"] = ci.modulate.a
			var script_path: String = str(entry.get("script_path", "")).strip_edges()
			if bool(entry.get("has_triggered", false)) and script_path.ends_with("AmbushSpawner.gd"):
				entry["remove_on_guest"] = true
			spawners.append(entry)
	return {
		"v": COOP_ENEMY_PHASE_SETUP_SNAPSHOT_VER,
		"enemy_units": enemy_units,
		"spawners": spawners,
	}


func _coop_apply_enemy_phase_setup_snapshot(snap: Dictionary) -> void:
	if int(snap.get("v", 0)) != COOP_ENEMY_PHASE_SETUP_SNAPSHOT_VER:
		if OS.is_debug_build():
			push_warning("Coop enemy phase setup: reject snapshot (bad v).")
		return
	for raw_unit in snap.get("enemy_units", []):
		if not raw_unit is Dictionary:
			continue
		_coop_apply_runtime_unit_wire_snapshot(raw_unit as Dictionary, enemy_container)
	var live_spawner_ids: Dictionary = {}
	for raw_spawner in snap.get("spawners", []):
		if not raw_spawner is Dictionary:
			continue
		var entry: Dictionary = raw_spawner as Dictionary
		var sid: String = str(entry.get("id", "")).strip_edges()
		if sid == "":
			continue
		live_spawner_ids[sid] = true
		var node: Node2D = _coop_find_unit_by_relationship_id_any_side(sid)
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if entry.has("slot_timers") and node.get("slot_timers") != null:
			node.set("slot_timers", (entry["slot_timers"] as Array).duplicate(true))
		if entry.has("has_warned") and node.get("has_warned") != null:
			node.set("has_warned", bool(entry["has_warned"]))
		if entry.has("has_triggered") and node.get("has_triggered") != null:
			node.set("has_triggered", bool(entry["has_triggered"]))
		if node is CanvasItem:
			var ci: CanvasItem = node as CanvasItem
			if entry.has("visible"):
				ci.visible = bool(entry["visible"])
			if entry.has("alpha"):
				var mod: Color = ci.modulate
				mod.a = float(entry["alpha"])
				ci.modulate = mod
		if node.has_method("queue_redraw"):
			node.call("queue_redraw")
		if bool(entry.get("remove_on_guest", false)):
			node.queue_free()
	for child in destructibles_container.get_children():
		if not child is Node2D:
			continue
		var node: Node2D = child as Node2D
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.has_method("process_turn"):
			continue
		var sid: String = _get_mock_coop_command_id(node)
		if sid != "" and not live_spawner_ids.has(sid):
			node.queue_free()
	rebuild_grid()
	update_fog_of_war()
	update_objective_ui()


func coop_enet_sync_after_host_authority_enemy_move(unit: Node2D, path: Array, path_cost: float) -> void:
	CoopOutboundSyncHelpers.coop_enet_sync_after_host_authority_enemy_move(self, unit, path, path_cost)


func coop_enet_sync_after_host_authority_enemy_finish_turn(unit: Node2D) -> void:
	CoopOutboundSyncHelpers.coop_enet_sync_after_host_authority_enemy_finish_turn(self, unit)


func coop_enet_sync_after_host_authority_enemy_escape(unit: Node2D) -> void:
	CoopOutboundSyncHelpers.coop_enet_sync_after_host_authority_enemy_escape(self, unit)


func coop_enet_sync_after_host_authority_enemy_chest_open(opener: Node2D, chest: Node2D, stolen_items: Array) -> void:
	CoopOutboundSyncHelpers.coop_enet_sync_after_host_authority_enemy_chest_open(self, opener, chest, stolen_items)


func coop_enet_sync_after_host_authority_enemy_turn_end() -> void:
	CoopOutboundSyncHelpers.coop_enet_sync_after_host_authority_enemy_turn_end(self)


func coop_enet_sync_enemy_turn_batch_move(entries: Array) -> void:
	CoopOutboundSyncHelpers.coop_enet_sync_enemy_turn_batch_move(self, entries)


func coop_enet_sync_after_host_authority_enemy_phase_setup() -> void:
	CoopOutboundSyncHelpers.coop_enet_sync_after_host_authority_enemy_phase_setup(self)


func coop_enet_sync_after_host_authoritative_battle_result(result: String) -> void:
	CoopOutboundSyncHelpers.coop_enet_sync_after_host_authoritative_battle_result(self, result)


func coop_enet_sync_after_host_authority_escort_turn(convoy: Node2D) -> void:
	CoopOutboundSyncHelpers.coop_enet_sync_after_host_authority_escort_turn(self, convoy)


## Called on host + guest when the session locks RNG for this battle ([method CoopExpeditionSessionManager.enet_try_publish_coop_battle_rng_seed]).
func apply_coop_battle_net_rng_seed(s: int) -> void:
	CoopRngSyncHelpers.apply_coop_battle_net_rng_seed(self, s)


func coop_net_rng_sync_ready() -> bool:
	return CoopRngSyncHelpers.coop_net_rng_sync_ready(self)


## Call immediately before [method execute_combat] on the attacker’s machine. Returns packed id for the wire (guest vs host ranges avoid collisions).
func coop_enet_begin_synchronized_combat_round() -> int:
	return CoopRngSyncHelpers.coop_enet_begin_synchronized_combat_round(self)


func coop_enet_apply_remote_combat_packed_id(packed: int) -> void:
	CoopRngSyncHelpers.coop_enet_apply_remote_combat_packed_id(self, packed)


## Monotonic minigame ids for one [method execute_combat] (must match peer call order). Partner mirrors snapshot; no interactive QTE on guest.
var _coop_qte_event_seq: int = 0
var _coop_qte_mirror_active: bool = false
var _coop_qte_mirror_dict: Dictionary = {}
var _coop_qte_capture_active: bool = false
var _coop_qte_capture_dict: Dictionary = {}
var _coop_combat_loot_capture_active: bool = false
var _coop_combat_loot_capture_events: Array = []


func _coop_qte_tick_reset_for_execute_combat() -> void:
	CoopRuntimeSyncHelpers.coop_qte_tick_reset_for_execute_combat(self)


func coop_net_begin_local_combat_qte_capture() -> void:
	CoopRuntimeSyncHelpers.coop_net_begin_local_combat_qte_capture(self)


func coop_net_end_local_combat_qte_capture() -> Dictionary:
	return CoopRuntimeSyncHelpers.coop_net_end_local_combat_qte_capture(self)


func coop_net_begin_local_combat_loot_capture() -> void:
	CoopRuntimeSyncHelpers.coop_net_begin_local_combat_loot_capture(self)


func coop_net_end_local_combat_loot_capture() -> Array:
	return CoopRuntimeSyncHelpers.coop_net_end_local_combat_loot_capture(self)


func coop_net_apply_remote_combat_qte_snapshot(snap: Variant) -> void:
	CoopRuntimeSyncHelpers.coop_net_apply_remote_combat_qte_snapshot(self, snap)


func coop_net_clear_remote_combat_qte_snapshot() -> void:
	CoopRuntimeSyncHelpers.coop_net_clear_remote_combat_qte_snapshot(self)


func _coop_qte_alloc_event_id() -> String:
	return CoopRuntimeSyncHelpers.coop_qte_alloc_event_id(self)


func _coop_qte_mirror_read_int(event_id: String, default_v: int) -> int:
	return CoopRuntimeSyncHelpers.coop_qte_mirror_read_int(self, event_id, default_v)


func _coop_qte_mirror_read_bool(event_id: String, default_v: bool) -> bool:
	return CoopRuntimeSyncHelpers.coop_qte_mirror_read_bool(self, event_id, default_v)


func _coop_qte_capture_write(event_id: String, value: Variant) -> void:
	CoopRuntimeSyncHelpers.coop_qte_capture_write(self, event_id, value)


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
			var rid: String = _get_mock_coop_command_id(u)
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
	return CoopHelpers.coop_net_build_authoritative_combat_snapshot(self, pre_alive_ids)


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
	CoopHelpers.coop_apply_authoritative_combat_snapshot(self, snap)


func is_coop_remote_combat_replay_active() -> bool:
	return _coop_remote_combat_replay_active


func _coop_execute_remote_combat_replay(attacker: Node2D, defender: Node2D, used_ability: bool, qte_snapshot: Variant, rng_packed: int = -1) -> void:
	if attacker == null or defender == null:
		return
	_coop_remote_combat_replay_active = true
	coop_net_apply_remote_combat_qte_snapshot(qte_snapshot)
	if rng_packed >= 0:
		coop_enet_apply_remote_combat_packed_id(rng_packed)
	await execute_combat(attacker, defender, used_ability)
	coop_net_clear_remote_combat_qte_snapshot()
	_coop_remote_combat_replay_active = false


func _coop_validate_authoritative_post_combat_outcome() -> void:
	if player_container != null:
		for p in player_container.get_children():
			if not is_instance_valid(p) or p.is_queued_for_deletion():
				continue
			if p.get("is_custom_avatar") == true and int(p.get("current_hp")) <= 0:
				add_combat_log("The Leader has fallen! All is lost...", "red")
				trigger_game_over("DEFEAT")
				return
		var living_players: int = 0
		for p in player_container.get_children():
			if not is_instance_valid(p) or p.is_queued_for_deletion():
				continue
			if int(p.get("current_hp")) > 0:
				living_players += 1
		if living_players <= 0:
			add_combat_log("MISSION FAILED: Entire party wiped out.", "red")
			trigger_game_over("DEFEAT")
			return
	match map_objective:
		Objective.ROUT_ENEMY:
			if _count_alive_enemies() == 0 and _count_active_enemy_spawners() == 0:
				add_combat_log("MISSION ACCOMPLISHED: All enemies routed.", "lime")
				_trigger_victory()
				return
		Objective.DEFEND_TARGET:
			if vip_target != null and is_instance_valid(vip_target) and int(vip_target.get("current_hp")) <= 0:
				add_combat_log("MISSION FAILED: VIP Target was killed.", "red")
				trigger_game_over("DEFEAT")
				return


## ENet co-op: host allocates [method coop_enet_begin_synchronized_combat_round] + runs combat, then broadcasts; guest waits FIFO and mirrors (crit/miss match).
func coop_enet_buffer_incoming_enemy_combat(body: Dictionary) -> void:
	CoopEnemyCombatNetHelpers.coop_enet_buffer_incoming_enemy_combat(self, body)


func coop_enet_ai_execute_combat(attacker: Node2D, defender: Node2D, used_ability: bool = false) -> void:
	await CoopEnemyCombatNetHelpers.coop_enet_ai_execute_combat(self, attacker, defender, used_ability)


## True when this peer is the ENet guest with battle RNG locked — player-initiated combat must be simulated on the host only.
func coop_enet_should_delegate_player_combat_to_host() -> bool:
	return coop_net_rng_sync_ready() and is_mock_coop_unit_ownership_active() and CoopExpeditionSessionManager.uses_runtime_network_coop_transport() and CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.GUEST


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
	await CoopCombatRequestHelpers.coop_enet_guest_delegate_player_combat_to_host(self, attacker_id, defender_id, used_ability)


func coop_enet_guest_receive_combat_request_nack(body: Dictionary) -> void:
	CoopCombatRequestHelpers.coop_enet_guest_receive_combat_request_nack(self, body)


func coop_enet_host_handle_player_combat_request(body: Dictionary) -> void:
	call_deferred("_coop_host_start_player_combat_request", body.duplicate(true))


func _coop_host_start_player_combat_request(body: Dictionary) -> void:
	await CoopCombatRequestHelpers.coop_host_resolve_player_combat_request_async(self, body)


func _coop_host_send_player_combat_request_nack(attacker_id: String) -> void:
	CoopCombatRequestHelpers.coop_host_send_player_combat_request_nack(self, attacker_id)


func coop_enet_sync_after_local_prebattle_layout_change() -> void:
	CoopOutboundSyncHelpers.coop_enet_sync_after_local_prebattle_layout_change(self)


func coop_enet_sync_after_local_player_move(unit: Node2D, path: Array, _path_cost: float, finish_after_move: bool = false) -> void:
	CoopOutboundSyncHelpers.coop_enet_sync_after_local_player_move(self, unit, path, _path_cost, finish_after_move)


func coop_enet_sync_after_local_defend(unit: Node2D) -> void:
	CoopOutboundSyncHelpers.coop_enet_sync_after_local_defend(self, unit)


## IDs captured before [method execute_combat] so we still notify peer if the attacker dies. Post-combat packet only if [param attacker_after] is still alive.
func coop_enet_sync_local_combat_done(attacker_id: String, defender_id: String, used_ability: bool, attacker_after: Node2D, entered_canto: bool, canto_budget: float, combat_packed_rng_id: int = -1, qte_snapshot: Dictionary = {}, auth_snapshot: Dictionary = {}, combat_host_authority: bool = false, loot_events: Array = []) -> void:
	CoopOutboundSyncHelpers.coop_enet_sync_local_combat_done(self, attacker_id, defender_id, used_ability, attacker_after, entered_canto, canto_budget, combat_packed_rng_id, qte_snapshot, auth_snapshot, combat_host_authority, loot_events)


func coop_enet_sync_after_local_finish_turn(unit: Node2D) -> void:
	CoopOutboundSyncHelpers.coop_enet_sync_after_local_finish_turn(self, unit)


func apply_remote_coop_enet_sync(body: Dictionary) -> void:
	CoopRuntimeSyncHelpers.apply_remote_coop_enet_sync(self, body)


func _coop_enet_pump_remote_sync_queue() -> void:
	CoopRuntimeSyncHelpers.coop_enet_pump_remote_sync_queue(self)


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
			if _get_mock_coop_command_id(u) == r:
				return u as Node2D
	return null


func _coop_find_unit_by_relationship_id_any_side(rid: String) -> Node2D:
	var u: Node2D = _coop_find_player_side_unit_by_relationship_id(rid)
	if u != null:
		return u
	var r: String = str(rid).strip_edges()
	if r == "":
		return null
	for cont in [enemy_container, destructibles_container, chests_container]:
		if cont == null:
			continue
		for e in cont.get_children():
			if not is_instance_valid(e):
				continue
			if _get_mock_coop_command_id(e) == r:
				return e as Node2D
	return null


func _coop_run_one_remote_sync_async(body: Dictionary) -> void:
	await CoopRemoteSyncActionHelpers.coop_run_one_remote_sync_async(self, body)


func _coop_wait_for_enemy_state_ready() -> void:
	while is_inside_tree() and current_state != enemy_state:
		await get_tree().process_frame


func _coop_remote_sync_enemy_phase_setup(body: Dictionary) -> void:
	CoopRemoteSyncActionHelpers.coop_remote_sync_enemy_phase_setup(self, body)


func _coop_remote_sync_battle_result(body: Dictionary) -> void:
	await CoopRemoteSyncActionHelpers.coop_remote_sync_battle_result(self, body)


func _coop_remote_sync_escort_turn(body: Dictionary) -> void:
	await CoopRemoteSyncActionHelpers.coop_remote_sync_escort_turn(self, body)


func _coop_remote_sync_enemy_turn_move(body: Dictionary) -> void:
	await CoopRemoteSyncActionHelpers.coop_remote_sync_enemy_turn_move(self, body)


func _coop_remote_sync_enemy_turn_combat(body: Dictionary) -> void:
	await CoopRemoteSyncActionHelpers.coop_remote_sync_enemy_turn_combat(self, body)


func _coop_remote_sync_enemy_turn_finish(body: Dictionary) -> void:
	await CoopRemoteSyncActionHelpers.coop_remote_sync_enemy_turn_finish(self, body)


func _coop_remote_sync_enemy_turn_chest_open(body: Dictionary) -> void:
	await CoopRemoteSyncActionHelpers.coop_remote_sync_enemy_turn_chest_open(self, body)


func _coop_remote_sync_enemy_turn_escape(body: Dictionary) -> void:
	await CoopRemoteSyncActionHelpers.coop_remote_sync_enemy_turn_escape(self, body)


func _coop_remote_sync_enemy_turn_end(_body: Dictionary) -> void:
	CoopRemoteSyncActionHelpers.coop_remote_sync_enemy_turn_end(self, _body)


func _coop_remote_sync_enemy_turn_batch_move(body: Dictionary) -> void:
	await CoopRemoteSyncActionHelpers.coop_remote_sync_enemy_turn_batch_move(self, body)


func _coop_remote_sync_prebattle_layout(body: Dictionary) -> void:
	CoopRemoteSyncActionHelpers.coop_remote_sync_prebattle_layout(self, body)

func _queue_tactical_ui_overhaul() -> void:
	if not is_inside_tree():
		return
	call_deferred("_apply_tactical_ui_overhaul")

func _make_tactical_panel_style(fill: Color, border: Color = TACTICAL_UI_BORDER, border_width: int = 2, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	return style

func _make_tactical_bar_style(fill: Color, border: Color = TACTICAL_UI_BORDER_MUTED, border_width: int = 1, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style

func _style_tactical_panel(panel: Panel, fill: Color = TACTICAL_UI_BG, border: Color = TACTICAL_UI_BORDER, border_width: int = 2, radius: int = 10) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", _make_tactical_panel_style(fill, border, border_width, radius))

func _style_tactical_button(btn: Button, label: String, primary: bool = false, font_size: int = 24) -> void:
	if btn == null:
		return
	var normal_fill: Color = TACTICAL_UI_PRIMARY_FILL if primary else TACTICAL_UI_SECONDARY_FILL
	var hover_fill: Color = TACTICAL_UI_PRIMARY_HOVER if primary else TACTICAL_UI_SECONDARY_HOVER
	var press_fill: Color = TACTICAL_UI_PRIMARY_PRESS if primary else TACTICAL_UI_SECONDARY_PRESS
	var font_color: Color = Color(0.12, 0.08, 0.04, 1.0) if primary else TACTICAL_UI_TEXT
	var regular_font: Font = btn.get_theme_font("font", "Label")
	btn.text = label
	btn.scale = Vector2.ONE
	btn.add_theme_font_size_override("font_size", font_size)
	if regular_font != null:
		btn.add_theme_font_override("font", regular_font)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_color_override("font_focus_color", font_color)
	btn.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.9))
	btn.add_theme_constant_override("outline_size", 4)
	btn.add_theme_stylebox_override("normal", _make_tactical_panel_style(normal_fill, TACTICAL_UI_BORDER, 2, 10))
	btn.add_theme_stylebox_override("hover", _make_tactical_panel_style(hover_fill, TACTICAL_UI_BORDER, 2, 10))
	btn.add_theme_stylebox_override("pressed", _make_tactical_panel_style(press_fill, TACTICAL_UI_BORDER, 2, 10))
	btn.add_theme_stylebox_override("focus", _make_tactical_panel_style(hover_fill, TACTICAL_UI_ACCENT, 2, 10))
	btn.custom_minimum_size = btn.size


func _get_battle_log_panel() -> Panel:
	if battle_log == null:
		return null
	return battle_log.get_parent() as Panel


func _ensure_field_log_toggle_button() -> Button:
	if ui_root == null:
		return null
	if field_log_toggle_btn != null and is_instance_valid(field_log_toggle_btn):
		return field_log_toggle_btn
	var btn := ui_root.get_node_or_null("FieldLogToggleBtn") as Button
	if btn == null:
		btn = Button.new()
		btn.name = "FieldLogToggleBtn"
		ui_root.add_child(btn)
	field_log_toggle_btn = btn
	if not field_log_toggle_btn.pressed.is_connected(_on_field_log_toggle_pressed):
		field_log_toggle_btn.pressed.connect(_on_field_log_toggle_pressed)
	return field_log_toggle_btn


func _ensure_deploy_roster_toggle_button() -> Button:
	var ui := get_node_or_null("UI")
	if ui == null:
		return null
	if deploy_roster_toggle_btn != null and is_instance_valid(deploy_roster_toggle_btn):
		return deploy_roster_toggle_btn
	var btn := ui.get_node_or_null("DeployRosterToggleBtn") as Button
	if btn == null:
		btn = Button.new()
		btn.name = "DeployRosterToggleBtn"
		btn.visible = false
		btn.focus_mode = Control.FOCUS_NONE
		ui.add_child(btn)
	deploy_roster_toggle_btn = btn
	if not deploy_roster_toggle_btn.pressed.is_connected(_on_deploy_roster_toggle_pressed):
		deploy_roster_toggle_btn.pressed.connect(_on_deploy_roster_toggle_pressed)
	return deploy_roster_toggle_btn


func _on_deploy_roster_toggle_pressed() -> void:
	var rp: Panel = get_node_or_null("UI/RosterPanel") as Panel
	if rp == null:
		return
	if current_state != pre_battle_state:
		return
	var collapsed: bool = rp.get_meta(META_DEPLOYMENT_RAIL_COLLAPSED, false)
	rp.set_meta(META_DEPLOYMENT_RAIL_COLLAPSED, not collapsed)
	if select_sound and select_sound.stream:
		select_sound.pitch_scale = randf_range(0.96, 1.04)
		select_sound.play()
	_apply_deployment_rail_visibility(true)


func _apply_deployment_rail_visibility(animated: bool = false) -> void:
	var rp: Panel = get_node_or_null("UI/RosterPanel") as Panel
	var btn: Button = _ensure_deploy_roster_toggle_button()
	if rp == null or btn == null:
		return
	if current_state != pre_battle_state:
		return
	if not rp.visible or not rp.has_meta("deploy_rail_expanded_x"):
		return
	var expanded_px: float = float(rp.get_meta("deploy_rail_expanded_x"))
	var collapsed_px: float = float(rp.get_meta("deploy_rail_collapsed_x"))
	var expanded_bx: float = float(btn.get_meta("deploy_rail_btn_expanded_x")) if btn.has_meta("deploy_rail_btn_expanded_x") else btn.position.x
	var collapsed_bx: float = float(btn.get_meta("deploy_rail_btn_collapsed_x")) if btn.has_meta("deploy_rail_btn_collapsed_x") else btn.position.x
	var start_btn: Button = get_node_or_null("UI/StartBattleButton") as Button
	var expanded_sy: float = float(start_btn.get_meta("deploy_start_expanded_y")) if start_btn != null and start_btn.has_meta("deploy_start_expanded_y") else (start_btn.position.y if start_btn != null else 0.0)
	var collapsed_sy: float = float(start_btn.get_meta("deploy_start_collapsed_y")) if start_btn != null and start_btn.has_meta("deploy_start_collapsed_y") else expanded_sy
	var collapsed_now: bool = rp.get_meta(META_DEPLOYMENT_RAIL_COLLAPSED, false)
	var target_px: float = collapsed_px if collapsed_now else expanded_px
	var target_bx: float = collapsed_bx if collapsed_now else expanded_bx
	var target_sy: float = collapsed_sy if collapsed_now else expanded_sy

	if deploy_roster_toggle_tween != null:
		deploy_roster_toggle_tween.kill()
	deploy_roster_toggle_tween = null

	if not animated:
		rp.position.x = target_px
		btn.position.x = target_bx
		if start_btn != null:
			start_btn.position.y = target_sy
			start_btn.modulate = Color(1, 1, 1, DEPLOY_START_BATTLE_MODULATE_A_COLLAPSED) if collapsed_now else Color.WHITE
		_style_tactical_button(btn, "SHOW ROSTER" if collapsed_now else "HIDE ROSTER", false, 16)
		return

	deploy_roster_toggle_tween = create_tween()
	deploy_roster_toggle_tween.set_parallel(true)
	deploy_roster_toggle_tween.set_trans(Tween.TRANS_BACK)
	deploy_roster_toggle_tween.set_ease(Tween.EASE_IN_OUT)
	deploy_roster_toggle_tween.tween_property(rp, "position:x", target_px, 0.28)
	deploy_roster_toggle_tween.tween_property(btn, "position:x", target_bx, 0.28)
	if start_btn != null:
		deploy_roster_toggle_tween.tween_property(start_btn, "position:y", target_sy, 0.28)
		var target_modulate: Color = Color(1, 1, 1, DEPLOY_START_BATTLE_MODULATE_A_COLLAPSED) if collapsed_now else Color.WHITE
		deploy_roster_toggle_tween.tween_property(start_btn, "modulate", target_modulate, 0.28)
	await deploy_roster_toggle_tween.finished
	deploy_roster_toggle_tween = null
	_style_tactical_button(btn, "SHOW ROSTER" if collapsed_now else "HIDE ROSTER", false, 16)


func _set_field_log_toggle_button_text() -> void:
	if field_log_toggle_btn == null:
		return
	_style_tactical_button(field_log_toggle_btn, "SHOW LOG" if not CampaignManager.battle_show_log else "HIDE LOG", false, 16)


func _apply_field_log_visibility(animated: bool = false) -> void:
	var battle_log_panel: Panel = _get_battle_log_panel()
	var btn: Button = _ensure_field_log_toggle_button()
	if battle_log_panel == null or btn == null:
		return
	if current_state == pre_battle_state:
		if field_log_toggle_tween != null:
			field_log_toggle_tween.kill()
			field_log_toggle_tween = null
		btn.visible = false
		battle_log_panel.visible = false
		if battle_log != null:
			battle_log.visible = false
		return
	var expanded_panel_y: float = float(battle_log_panel.get_meta("field_log_expanded_y")) if battle_log_panel.has_meta("field_log_expanded_y") else battle_log_panel.position.y
	var collapsed_panel_y: float = float(battle_log_panel.get_meta("field_log_collapsed_y")) if battle_log_panel.has_meta("field_log_collapsed_y") else battle_log_panel.position.y
	var expanded_button_y: float = float(btn.get_meta("field_log_expanded_y")) if btn.has_meta("field_log_expanded_y") else btn.position.y
	var collapsed_button_y: float = float(btn.get_meta("field_log_collapsed_y")) if btn.has_meta("field_log_collapsed_y") else btn.position.y
	var target_panel_y: float = expanded_panel_y if CampaignManager.battle_show_log else collapsed_panel_y
	var target_button_y: float = expanded_button_y if CampaignManager.battle_show_log else collapsed_button_y

	btn.visible = true
	battle_log_panel.visible = true
	if battle_log != null and CampaignManager.battle_show_log:
		battle_log.visible = true

	if field_log_toggle_tween != null:
		field_log_toggle_tween.kill()
	field_log_toggle_tween = null

	if not animated:
		battle_log_panel.position.y = target_panel_y
		btn.position.y = target_button_y
		if battle_log != null:
			battle_log.visible = CampaignManager.battle_show_log
		_set_field_log_toggle_button_text()
		return

	field_log_toggle_tween = create_tween()
	field_log_toggle_tween.set_parallel(true)
	field_log_toggle_tween.set_trans(Tween.TRANS_BACK)
	field_log_toggle_tween.set_ease(Tween.EASE_IN_OUT)
	field_log_toggle_tween.tween_property(battle_log_panel, "position:y", target_panel_y, 0.28)
	field_log_toggle_tween.tween_property(btn, "position:y", target_button_y, 0.28)
	await field_log_toggle_tween.finished
	field_log_toggle_tween = null
	if battle_log != null:
		battle_log.visible = CampaignManager.battle_show_log
	_set_field_log_toggle_button_text()


func _on_field_log_toggle_pressed() -> void:
	CampaignManager.battle_show_log = not CampaignManager.battle_show_log
	CampaignManager.save_global_settings()
	if select_sound and select_sound.stream:
		select_sound.pitch_scale = randf_range(0.96, 1.04)
		select_sound.play()
	_apply_field_log_visibility(true)

func _style_tactical_label(label: Label, color: Color = TACTICAL_UI_TEXT, font_size: int = 22, outline_size: int = 4) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.9))
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_font_size_override("font_size", font_size)

func _style_tactical_richtext(text_box: RichTextLabel, font_size: int = 18, bold_font_size: int = 20) -> void:
	if text_box == null:
		return
	text_box.add_theme_color_override("default_color", TACTICAL_UI_TEXT)
	text_box.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.82))
	text_box.add_theme_constant_override("outline_size", 3)
	text_box.add_theme_font_size_override("normal_font_size", font_size)
	text_box.add_theme_font_size_override("bold_font_size", font_size)
	var normal_font: Font = text_box.get_theme_font("normal_font")
	if normal_font != null:
		text_box.add_theme_font_override("bold_font", normal_font)

func _style_tactical_item_list(item_list: ItemList) -> void:
	if item_list == null:
		return
	item_list.add_theme_stylebox_override("panel", _make_tactical_panel_style(TACTICAL_UI_BG_SOFT, TACTICAL_UI_BORDER_MUTED, 1, 8))
	item_list.add_theme_stylebox_override("cursor", _make_tactical_panel_style(Color(0.52, 0.43, 0.17, 0.32), TACTICAL_UI_BORDER, 2, 8))
	item_list.add_theme_stylebox_override("cursor_unfocused", _make_tactical_panel_style(Color(0.45, 0.37, 0.15, 0.20), TACTICAL_UI_BORDER_MUTED, 1, 8))
	item_list.add_theme_color_override("font_color", TACTICAL_UI_TEXT)
	item_list.add_theme_color_override("font_selected_color", Color.WHITE)

func _resolve_inventory_ui_nodes() -> void:
	if inventory_panel == null:
		return
	inv_desc_label = inventory_panel.get_node_or_null("ItemDescLabel") as RichTextLabel
	inv_scroll = inventory_panel.get_node_or_null("InventoryScroll") as ScrollContainer
	unit_grid = null
	convoy_grid = null
	if inv_scroll != null:
		var vbox_node := inv_scroll.get_node_or_null("InventoryVBox")
		if vbox_node != null:
			unit_grid = vbox_node.get_node_or_null("UnitGrid") as GridContainer
			convoy_grid = vbox_node.get_node_or_null("ConvoyGrid") as GridContainer

func _stylebox_bump_all_content_margins(sb: StyleBox, delta: float) -> void:
	if sb == null:
		return
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_content_margin(side, sb.get_content_margin(side) + delta)

func _inventory_scroll_apply_content_padding(scroll: ScrollContainer, pad: int) -> void:
	var sb: StyleBox = scroll.get_theme_stylebox("panel")
	if sb != null:
		sb = sb.duplicate() as StyleBox
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color(0, 0, 0, 0)
		sb = flat
	_stylebox_bump_all_content_margins(sb, float(pad))
	scroll.add_theme_stylebox_override("panel", sb)

func _style_inventory_item_info_backdrop(info_bg: Panel) -> void:
	if info_bg == null:
		return
	_style_tactical_panel(info_bg, TACTICAL_UI_BG_ALT, TACTICAL_UI_BORDER, 2, 12)
	info_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_bg.z_index = -1

func _apply_inventory_panel_spacing() -> void:
	InventoryUiHelpers.apply_inventory_panel_spacing(self)

func _apply_inventory_panel_item_list_extra_margins(inv_item_list: ItemList) -> void:
	if inv_item_list == null or inventory_panel == null:
		return
	if inventory_panel.get_meta("_inv_itemlist_extra_margin", false):
		return
	inventory_panel.set_meta("_inv_itemlist_extra_margin", true)
	var sb := inv_item_list.get_theme_stylebox("panel")
	if sb == null:
		return
	var d := sb.duplicate() as StyleBox
	_stylebox_bump_all_content_margins(d, float(INVENTORY_UI_ITEMLIST_EXTRA_MARGIN))
	inv_item_list.add_theme_stylebox_override("panel", d)

func _resolve_loot_ui_nodes() -> void:
	if loot_window == null:
		return
	loot_desc_label = loot_window.get_node_or_null("ItemDescLabel") as RichTextLabel
	loot_item_info_panel = loot_window.get_node_or_null("LootItemInfoBackdrop") as Panel

func _layout_loot_item_info_backdrop() -> void:
	if loot_window == null or loot_item_info_panel == null or loot_desc_label == null:
		return
	if not loot_desc_label.has_meta(META_LOOT_DESC_LAYOUT_BASE):
		loot_desc_label.set_meta(META_LOOT_DESC_LAYOUT_BASE, Rect2(loot_desc_label.position, loot_desc_label.size))
	var base_rect: Rect2 = loot_desc_label.get_meta(META_LOOT_DESC_LAYOUT_BASE)
	var outer := float(LOOT_INFO_BACKDROP_OUTER_PAD)
	var inner := float(LOOT_INFO_DESC_INNER_PAD)
	loot_item_info_panel.position = base_rect.position - Vector2(outer, outer)
	loot_item_info_panel.size = base_rect.size + Vector2(outer * 2.0, outer * 2.0)
	loot_item_info_panel.z_index = -1
	loot_desc_label.position = base_rect.position + Vector2(inner, inner)
	loot_desc_label.size = base_rect.size - Vector2(inner * 2.0, inner * 2.0)
	loot_desc_label.z_index = 2

func _ensure_loot_item_info_ui() -> void:
	if loot_window == null:
		return
	_resolve_loot_ui_nodes()
	if loot_desc_label == null:
		var rtl := RichTextLabel.new()
		rtl.name = "ItemDescLabel"
		rtl.layout_mode = 0
		rtl.offset_left = 770.0
		rtl.offset_top = 100.0
		rtl.offset_right = 1248.0
		rtl.offset_bottom = 392.0
		rtl.bbcode_enabled = true
		rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rtl.scroll_active = false
		rtl.fit_content = false
		rtl.mouse_filter = Control.MOUSE_FILTER_STOP
		rtl.process_mode = Node.PROCESS_MODE_ALWAYS
		loot_window.add_child(rtl)
		loot_desc_label = rtl
	if loot_item_info_panel == null:
		var bp := Panel.new()
		bp.name = "LootItemInfoBackdrop"
		bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		loot_window.add_child(bp)
		loot_item_info_panel = bp
		loot_window.move_child(loot_item_info_panel, 0)
	_style_tactical_panel(loot_item_info_panel, TACTICAL_UI_BG_ALT, TACTICAL_UI_BORDER, 2, 12)
	loot_item_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout_loot_item_info_backdrop()
	var loot_title := loot_window.get_node_or_null("Label") as Label
	if loot_title != null:
		_style_tactical_label(loot_title, TACTICAL_UI_ACCENT, 22, 4)
		loot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if loot_desc_label != null:
		loot_desc_label.focus_mode = Control.FOCUS_NONE
		loot_desc_label.remove_theme_stylebox_override("focus")
		loot_desc_label.scroll_active = false
		loot_desc_label.process_mode = Node.PROCESS_MODE_ALWAYS

func _queue_refit_item_description_panels() -> void:
	var t := Timer.new()
	t.wait_time = 0.03
	t.one_shot = true
	t.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(t)
	t.timeout.connect(func():
		_refit_loot_description_panel_height()
		_refit_inventory_description_panel_height()
		t.queue_free()
	, CONNECT_ONE_SHOT)
	t.start()

func _refit_loot_description_panel_height() -> void:
	if loot_desc_label == null or loot_item_info_panel == null:
		return
	if not loot_desc_label.has_meta(META_LOOT_DESC_LAYOUT_BASE):
		return
	loot_desc_label.scroll_active = false
	var base_rect: Rect2 = loot_desc_label.get_meta(META_LOOT_DESC_LAYOUT_BASE)
	var inner := float(LOOT_INFO_DESC_INNER_PAD)
	var outer := float(LOOT_INFO_BACKDROP_OUTER_PAD)
	var text_w: float = maxf(48.0, base_rect.size.x - inner * 2.0)
	loot_desc_label.position = base_rect.position + Vector2(inner, inner)
	loot_desc_label.size.x = text_w
	loot_desc_label.size.y = maxf(ITEM_DESC_RICHTEXT_MIN_H, 32.0)
	var ch: float = loot_desc_label.get_content_height()
	var th: float = clampf(ch + ITEM_DESC_RICHTEXT_EXTRA_PAD, ITEM_DESC_RICHTEXT_MIN_H, ITEM_DESC_RICHTEXT_MAX_H)
	loot_desc_label.size.y = th
	var block_h: float = th + inner * 2.0
	loot_item_info_panel.position = base_rect.position - Vector2(outer, outer)
	loot_item_info_panel.size = Vector2(base_rect.size.x + outer * 2.0, block_h + outer * 2.0)

func _refit_inventory_description_panel_height() -> void:
	if inv_desc_label == null or inventory_panel == null:
		return
	if not inventory_panel.visible:
		return
	inv_desc_label.scroll_active = false
	var w := inv_desc_label.size.x
	if w < 8.0:
		return
	var ch := inv_desc_label.get_content_height()
	var th := clampf(ch + ITEM_DESC_RICHTEXT_EXTRA_PAD, INVENTORY_DESC_PANEL_MIN_H, ITEM_DESC_RICHTEXT_MAX_H)
	inv_desc_label.offset_top = inv_desc_label.offset_bottom - th
	var bg := inventory_panel.get_node_or_null("Panel") as Panel
	if bg != null:
		var pad := INVENTORY_DESC_PANEL_PAD
		var r := inv_desc_label.get_rect()
		bg.position = r.position - Vector2(pad, pad)
		bg.size = r.size + Vector2(2.0 * pad, 2.0 * pad)
		_style_inventory_item_info_backdrop(bg)

func _unit_info_primary_bar_definitions() -> Array[Dictionary]:
	return [
		{"key": "hp", "label": "HP"},
		{"key": "poise", "label": "POISE"},
		{"key": "xp", "label": "XP"},
	]

func _unit_info_primary_fill_color(bar_key: String, current_value: int, max_value: int) -> Color:
	match bar_key:
		"hp":
			return _forecast_hp_fill_color(current_value, max_value)
		"poise":
			if max_value <= 0:
				return TACTICAL_UI_TEXT_MUTED
			var ratio := clampf(float(current_value) / float(max_value), 0.0, 1.0)
			if ratio >= 0.67:
				return Color(0.48, 0.90, 1.0, 1.0)
			if ratio >= 0.34:
				return Color(0.88, 0.78, 0.30, 1.0)
			return Color(0.93, 0.42, 0.30, 1.0)
		"xp":
			return Color(0.96, 0.82, 0.36, 1.0)
		_:
			return TACTICAL_UI_ACCENT_SOFT

func _style_unit_info_primary_bar(bar: ProgressBar, fill: Color, bar_key: String = "") -> void:
	if bar == null:
		return
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.clip_contents = true
	var radius := 5
	var bg_border := Color(0.38, 0.33, 0.22, 0.92)
	match bar_key:
		"hp":
			radius = 7
			bg_border = Color(0.54, 0.28, 0.22, 0.94)
		"poise":
			radius = 3
			bg_border = Color(0.22, 0.46, 0.56, 0.94)
		"xp":
			radius = 2
			bg_border = Color(0.56, 0.46, 0.18, 0.94)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.06, 0.05, 0.98)
	bg_style.border_color = bg_border
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(radius)
	bg_style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	bg_style.shadow_size = 2

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.border_color = fill.lightened(0.18)
	fill_style.set_border_width_all(1)
	fill_style.set_corner_radius_all(radius)

	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)

func _attach_unit_info_bar_sheen(bar: ProgressBar) -> ColorRect:
	if bar == null:
		return null
	bar.clip_contents = true
	var sheen := bar.get_node_or_null("Sheen") as ColorRect
	if sheen == null:
		sheen = ColorRect.new()
		sheen.name = "Sheen"
		sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(sheen)
	sheen.color = Color(1.0, 1.0, 1.0, 0.14)
	sheen.size = Vector2(34, 20)
	sheen.position = Vector2(-52, -6)
	sheen.rotation_degrees = 14.0
	sheen.modulate.a = 0.0
	return sheen

func _animate_unit_info_bar_sheen(sheen: ColorRect, bar: ProgressBar, delay: float = 0.0) -> void:
	if sheen == null or bar == null:
		return
	var bar_width: float = max(bar.size.x, bar.custom_minimum_size.x, 120.0)
	sheen.position = Vector2(-52, -6)
	sheen.modulate.a = 0.0
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(sheen, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(sheen, "position:x", bar_width + 18.0, 0.46).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(sheen, "modulate:a", 0.0, 0.12)

func _ensure_unit_info_primary_widgets() -> Control:
	if unit_info_panel == null:
		return null
	var root := unit_info_panel.get_node_or_null("UnitPrimaryBarsRoot") as Control
	if root == null:
		root = Control.new()
		root.name = "UnitPrimaryBarsRoot"
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unit_info_panel.add_child(root)

	for bar_def in _unit_info_primary_bar_definitions():
		var bar_key: String = str(bar_def.get("key", ""))
		if bar_key == "":
			continue
		var row_name := "PrimaryBlock_%s" % bar_key
		var block := root.get_node_or_null(row_name) as Panel
		if block == null:
			block = Panel.new()
			block.name = row_name
			block.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(block)
		_style_tactical_panel(block, Color(0.10, 0.09, 0.07, 0.82), Color(0.36, 0.31, 0.20, 0.72), 1, 6)

		var name_label := block.get_node_or_null("Name") as Label
		if name_label == null:
			name_label = Label.new()
			name_label.name = "Name"
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.add_child(name_label)
		var value_label := block.get_node_or_null("Value") as Label
		if value_label == null:
			value_label = Label.new()
			value_label.name = "Value"
			value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.add_child(value_label)
		var value_chip := block.get_node_or_null("ValueChip") as Panel
		if value_chip == null:
			value_chip = Panel.new()
			value_chip.name = "ValueChip"
			value_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.add_child(value_chip)
		var bar := block.get_node_or_null("Bar") as ProgressBar
		if bar == null:
			bar = ProgressBar.new()
			bar.name = "Bar"
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.add_child(bar)
		var sheen := _attach_unit_info_bar_sheen(bar)
		value_chip.z_index = 1
		value_label.z_index = 2
		block.move_child(value_chip, max(0, block.get_child_count() - 2))
		block.move_child(value_label, block.get_child_count() - 1)

		_unit_info_primary_widgets[bar_key] = {
			"panel": block,
			"name": name_label,
			"value_chip": value_chip,
			"value": value_label,
			"bar": bar,
			"sheen": sheen,
		}

	_layout_unit_info_primary_widgets()
	return root

func _layout_unit_info_primary_widgets() -> void:
	var root: Control = null
	if unit_info_panel != null:
		root = unit_info_panel.get_node_or_null("UnitPrimaryBarsRoot") as Control
	if root == null:
		return
	root.position = Vector2(16, 60)
	root.size = Vector2(210, 78)
	var block_height := 24.0
	var gap_y := 3.0
	var defs := _unit_info_primary_bar_definitions()
	for idx in range(defs.size()):
		var bar_key: String = str(defs[idx].get("key", ""))
		if not _unit_info_primary_widgets.has(bar_key):
			continue
		var widgets: Dictionary = _unit_info_primary_widgets[bar_key]
		var panel := widgets.get("panel") as Panel
		var name_label := widgets.get("name") as Label
		var value_chip := widgets.get("value_chip") as Panel
		var value_label := widgets.get("value") as Label
		var bar := widgets.get("bar") as ProgressBar
		var pos := Vector2(0, idx * (block_height + gap_y))
		if panel != null:
			panel.position = pos
			panel.size = Vector2(210, block_height)
		if name_label != null:
			name_label.position = Vector2(4, 0)
			name_label.size = Vector2(42, 11)
			name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_style_tactical_label(name_label, TACTICAL_UI_TEXT_MUTED, 10, 2)
		if value_chip != null:
			value_chip.position = Vector2(138, 0)
			value_chip.size = Vector2(68, 13)
			_style_tactical_panel(value_chip, Color(0.10, 0.09, 0.07, 0.98), Color(0.34, 0.30, 0.22, 0.86), 1, 4)
		if value_label != null:
			value_label.position = Vector2(144, 0)
			value_label.size = Vector2(56, 13)
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_style_tactical_label(value_label, TACTICAL_UI_TEXT, 13, 1)
		if bar != null:
			bar.min_value = 0.0
			bar.max_value = 100.0
			bar.position = Vector2(4, 15)
			bar.size = Vector2(202, 8)

func _set_unit_info_primary_widgets_visible(visible: bool) -> void:
	var root: Control = null
	if unit_info_panel != null:
		root = unit_info_panel.get_node_or_null("UnitPrimaryBarsRoot") as Control
	if not visible and _unit_info_primary_anim_tween != null:
		_unit_info_primary_anim_tween.kill()
		_unit_info_primary_anim_tween = null
		_unit_info_primary_animating = false
		_unit_info_primary_anim_source_id = -1
	if root != null:
		root.visible = visible

func _animate_unit_info_primary_widgets_in(target_values: Dictionary, source_id: int) -> void:
	if _unit_info_primary_anim_tween != null:
		_unit_info_primary_anim_tween.kill()
	_unit_info_primary_anim_tween = create_tween().set_parallel(true)
	_unit_info_primary_animating = true
	_unit_info_primary_anim_source_id = source_id
	var defs := _unit_info_primary_bar_definitions()
	for idx in range(defs.size()):
		var bar_key: String = str(defs[idx].get("key", ""))
		if not _unit_info_primary_widgets.has(bar_key):
			continue
		var widgets: Dictionary = _unit_info_primary_widgets[bar_key]
		var panel := widgets.get("panel") as Panel
		var bar := widgets.get("bar") as ProgressBar
		var sheen := widgets.get("sheen") as ColorRect
		var delay := float(idx) * 0.045
		if panel != null:
			panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
			_unit_info_primary_anim_tween.tween_property(panel, "modulate", Color.WHITE, 0.18).set_delay(delay)
		if bar != null:
			bar.value = 0.0
			_unit_info_primary_anim_tween.tween_property(bar, "value", float(target_values.get(bar_key, 0.0)), 0.28).set_delay(delay)
		if sheen != null:
			_animate_unit_info_bar_sheen(sheen, bar, delay + 0.06)
	_unit_info_primary_anim_tween.finished.connect(func():
		_unit_info_primary_anim_tween = null
		_unit_info_primary_animating = false
		_unit_info_primary_anim_source_id = -1
	, CONNECT_ONE_SHOT)

func _refresh_unit_info_primary_widgets(primary_values: Dictionary, animate: bool = false, source_id: int = -1) -> void:
	var root := _ensure_unit_info_primary_widgets()
	if root == null:
		return
	root.visible = true
	var display_values: Dictionary = {}
	for bar_def in _unit_info_primary_bar_definitions():
		var bar_key: String = str(bar_def.get("key", ""))
		if not _unit_info_primary_widgets.has(bar_key):
			continue
		var widgets: Dictionary = _unit_info_primary_widgets[bar_key]
		var panel := widgets.get("panel") as Panel
		var name_label := widgets.get("name") as Label
		var value_chip := widgets.get("value_chip") as Panel
		var value_label := widgets.get("value") as Label
		var bar := widgets.get("bar") as ProgressBar
		var sheen := widgets.get("sheen") as ColorRect
		var row_data: Dictionary = primary_values.get(bar_key, {})
		var current_value: int = int(row_data.get("current", 0))
		var max_value: int = max(1, int(row_data.get("max", 1)))
		var display_text: String = str(row_data.get("text", "%d/%d" % [current_value, max_value]))
		var fill_color := _unit_info_primary_fill_color(bar_key, current_value, max_value)
		display_values[bar_key] = float(clampf(float(current_value), 0.0, float(max_value)))
		if name_label != null:
			name_label.text = str(bar_def.get("label", bar_key))
			_style_tactical_label(name_label, fill_color, 10, 2)
		if panel != null:
			var panel_border := Color(
				min(fill_color.r + 0.08, 1.0),
				min(fill_color.g + 0.08, 1.0),
				min(fill_color.b + 0.08, 1.0),
				0.72
			)
			var panel_fill := Color(0.10, 0.09, 0.07, 0.84)
			var panel_radius := 6
			match bar_key:
				"hp":
					panel_radius = 8
				"poise":
					panel_radius = 5
				"xp":
					panel_radius = 4
			_style_tactical_panel(panel, panel_fill, panel_border, 1, panel_radius)
		if value_chip != null:
			var chip_fill := Color(0.10, 0.09, 0.07, 0.98)
			var chip_border := Color(
				min(fill_color.r + 0.12, 1.0),
				min(fill_color.g + 0.12, 1.0),
				min(fill_color.b + 0.12, 1.0),
				0.92
			)
			_style_tactical_panel(value_chip, chip_fill, chip_border, 1, 4)
		if value_label != null:
			value_label.text = display_text
			_style_tactical_label(value_label, TACTICAL_UI_TEXT, 13, 2)
		if bar != null:
			bar.max_value = float(max_value)
			if not animate and not (_unit_info_primary_animating and _unit_info_primary_anim_source_id == source_id):
				bar.value = display_values[bar_key]
			_style_unit_info_primary_bar(bar, fill_color, bar_key)
	if animate:
		_animate_unit_info_primary_widgets_in(display_values, source_id)

func _unit_info_stat_tier_index(stat_value: int) -> int:
	if stat_value >= 200:
		return 4
	if stat_value >= 150:
		return 3
	if stat_value >= 100:
		return 2
	if stat_value >= 50:
		return 1
	return 0

func _unit_info_stat_definitions() -> Array[Dictionary]:
	return [
		{"key": "strength", "label": "STR"},
		{"key": "magic", "label": "MAG"},
		{"key": "defense", "label": "DEF"},
		{"key": "resistance", "label": "RES"},
		{"key": "speed", "label": "SPD"},
		{"key": "agility", "label": "AGI"},
	]

func _unit_info_stat_fill_color(stat_key: String, stat_value: int) -> Color:
	if stat_value >= 200:
		return UNIT_INFO_STAT_TIER_WHITE
	if stat_value >= 150:
		return UNIT_INFO_STAT_TIER_ORANGE
	if stat_value >= 100:
		return UNIT_INFO_STAT_TIER_PURPLE
	if stat_value >= 50:
		return UNIT_INFO_STAT_TIER_CYAN
	match stat_key:
		"strength":
			return Color(0.94, 0.48, 0.36, 1.0)
		"magic":
			return Color(0.78, 0.48, 0.96, 1.0)
		"defense":
			return Color(0.50, 0.88, 0.50, 1.0)
		"resistance":
			return Color(0.38, 0.90, 0.82, 1.0)
		"speed":
			return Color(0.46, 0.76, 1.0, 1.0)
		"agility":
			return Color(0.96, 0.82, 0.44, 1.0)
		_:
			return TACTICAL_UI_ACCENT_SOFT

func _style_unit_info_stat_bar(bar: ProgressBar, fill: Color, overcap: bool) -> void:
	if bar == null:
		return
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.06, 0.05, 0.98)
	bg_style.border_color = fill if overcap else Color(0.24, 0.22, 0.18, 1.0)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(5)
	bg_style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	bg_style.shadow_size = 2

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.border_color = fill.lightened(0.18)
	fill_style.set_border_width_all(1)
	fill_style.set_corner_radius_all(5)

	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)

func _ensure_unit_info_stat_fx_nodes(block: Panel) -> void:
	if block == null:
		return
	var aura := block.get_node_or_null("TierAura") as ColorRect
	if aura == null:
		aura = ColorRect.new()
		aura.name = "TierAura"
		aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_child(aura)
		block.move_child(aura, 0)
	aura.modulate.a = 0.0

	var flash := block.get_node_or_null("TierFlash") as ColorRect
	if flash == null:
		flash = ColorRect.new()
		flash.name = "TierFlash"
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_child(flash)
		block.move_child(flash, 0)
	flash.modulate.a = 0.0

	block.clip_contents = false
	var arcs_root := _get_unit_info_stat_arcs_root(block)
	if arcs_root == null:
		return
	for idx in range(8):
		var arc_name := "Arc%d" % idx
		var arc := arcs_root.get_node_or_null(arc_name) as ColorRect
		if arc == null:
			arc = ColorRect.new()
			arc.name = arc_name
			arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			arcs_root.add_child(arc)
		arc.z_index = 220
		arc.size = Vector2(20, 4)
		arc.color = Color.WHITE
		arc.modulate.a = 0.0
	_position_unit_info_stat_fx_nodes(block)

func _get_unit_info_stat_arcs_root(block: Panel) -> Control:
	if block == null or ui_root == null:
		return null
	var arcs_root: Control = null
	if block.has_meta("tier_arcs_root_ref"):
		var stored_root = block.get_meta("tier_arcs_root_ref")
		if is_instance_valid(stored_root):
			arcs_root = stored_root as Control
	if arcs_root == null:
		arcs_root = Control.new()
		arcs_root.name = "TierArcs"
		ui_root.add_child(arcs_root)
		block.set_meta("tier_arcs_root_ref", arcs_root)
	var block_rect: Rect2 = block.get_global_rect()
	arcs_root.position = block_rect.position + Vector2(-10, -10)
	arcs_root.size = block_rect.size + Vector2(20, 20)
	arcs_root.visible = false
	arcs_root.z_index = 200
	arcs_root.clip_contents = false
	return arcs_root

func _position_unit_info_stat_fx_nodes(block: Panel) -> void:
	if block == null:
		return
	var aura := block.get_node_or_null("TierAura") as ColorRect
	if aura != null:
		aura.position = Vector2(4, 8)
		aura.size = Vector2(max(block.size.x - 8.0, 20.0), 7)
	var flash := block.get_node_or_null("TierFlash") as ColorRect
	if flash != null:
		flash.position = Vector2.ZERO
		flash.size = block.size
	var arcs_root := _get_unit_info_stat_arcs_root(block)
	if arcs_root != null:
		var block_rect: Rect2 = block.get_global_rect()
		arcs_root.position = block_rect.position + Vector2(-10, -10)
		arcs_root.size = block_rect.size + Vector2(20, 20)

func _stop_unit_info_stat_tier_fx(block: Panel) -> void:
	if block == null:
		return
	var flash_tween = null
	if block.has_meta("tier_flash_tween"):
		flash_tween = block.get_meta("tier_flash_tween")
	if flash_tween is Tween:
		(flash_tween as Tween).kill()
	if block.has_meta("tier_flash_tween"):
		block.remove_meta("tier_flash_tween")
	var loop_tween = null
	if block.has_meta("tier_loop_tween"):
		loop_tween = block.get_meta("tier_loop_tween")
	if loop_tween is Tween:
		(loop_tween as Tween).kill()
	if block.has_meta("tier_loop_tween"):
		block.remove_meta("tier_loop_tween")
	var arc_tweens: Array = []
	if block.has_meta("tier_arc_tweens"):
		var stored_arc_tweens = block.get_meta("tier_arc_tweens")
		if stored_arc_tweens is Array:
			arc_tweens = stored_arc_tweens
	if arc_tweens is Array:
		for item in arc_tweens:
			if item is Tween:
				(item as Tween).kill()
	if block.has_meta("tier_arc_tweens"):
		block.remove_meta("tier_arc_tweens")
	if block.has_meta("tier_loop_tier"):
		block.remove_meta("tier_loop_tier")
	var flash := block.get_node_or_null("TierFlash") as ColorRect
	if flash != null:
		flash.modulate.a = 0.0
	var aura := block.get_node_or_null("TierAura") as ColorRect
	if aura != null:
		aura.modulate.a = 0.0
	var arcs_root := _get_unit_info_stat_arcs_root(block)
	if arcs_root != null:
		arcs_root.visible = false
		for child in arcs_root.get_children():
			if child is ColorRect:
				var arc := child as ColorRect
				arc.modulate.a = 0.0

func _unit_info_stat_arc_count_for_tier(tier: int) -> int:
	match tier:
		1:
			return 3
		2:
			return 4
		3:
			return 6
		_:
			return 8

func _unit_info_stat_arc_perimeter_length(field_size: Vector2) -> float:
	var width: float = max(field_size.x - 8.0, 12.0)
	var height: float = max(field_size.y - 8.0, 12.0)
	return (width * 2.0) + (height * 2.0)

func _unit_info_stat_arc_perimeter_point(field_size: Vector2, raw_offset: float) -> Vector2:
	var inset: float = 4.0
	var width: float = max(field_size.x - (inset * 2.0), 12.0)
	var height: float = max(field_size.y - (inset * 2.0), 12.0)
	var perimeter: float = (width * 2.0) + (height * 2.0)
	if perimeter <= 0.0:
		return Vector2(inset, inset)
	var offset: float = fposmod(raw_offset, perimeter)
	if offset < width:
		return Vector2(inset + offset, inset)
	offset -= width
	if offset < height:
		return Vector2(inset + width, inset + offset)
	offset -= height
	if offset < width:
		return Vector2((inset + width) - offset, inset + height)
	offset -= width
	return Vector2(inset, (inset + height) - offset)

func _unit_info_stat_arc_perimeter_normal(field_size: Vector2, raw_offset: float) -> Vector2:
	var inset: float = 4.0
	var width: float = max(field_size.x - (inset * 2.0), 12.0)
	var height: float = max(field_size.y - (inset * 2.0), 12.0)
	var perimeter: float = (width * 2.0) + (height * 2.0)
	if perimeter <= 0.0:
		return Vector2.UP
	var offset: float = fposmod(raw_offset, perimeter)
	if offset < width:
		return Vector2.UP
	offset -= width
	if offset < height:
		return Vector2.RIGHT
	offset -= height
	if offset < width:
		return Vector2.DOWN
	return Vector2.LEFT

func _set_unit_info_stat_arc_progress(progress: float, arc: ColorRect, field_size: Vector2, segment_length: float, tier: int, phase: float, clockwise: bool) -> void:
	if arc == null:
		return
	var point: Vector2 = _unit_info_stat_arc_perimeter_point(field_size, progress)
	var normal: Vector2 = _unit_info_stat_arc_perimeter_normal(field_size, progress)
	var direction: float = 1.0 if clockwise else -1.0
	var outward_push: float = 1.5 + (float(tier) * 0.8)
	var wave: float = sin((progress * 0.08 * direction) + phase)
	var thickness: float = 4.0 + (float(tier) * 0.7)
	var long_length: float = max(segment_length * 0.42, 12.0)
	var short_length: float = max(segment_length * 0.22, 8.0)
	if absf(normal.x) > 0.5:
		arc.size = Vector2(thickness, long_length if clockwise else short_length)
		arc.position = point - Vector2(arc.size.x * 0.5, arc.size.y * 0.5) + (normal * ((wave * 1.4) + outward_push))
	else:
		arc.size = Vector2(long_length if clockwise else short_length, thickness)
		arc.position = point - Vector2(arc.size.x * 0.5, arc.size.y * 0.5) + (normal * ((wave * 1.4) + outward_push))

func _play_unit_info_stat_tier_flash(block: Panel, tier: int, color: Color) -> void:
	if block == null or tier <= 0:
		return
	_position_unit_info_stat_fx_nodes(block)
	var flash := block.get_node_or_null("TierFlash") as ColorRect
	if flash == null:
		return
	var flash_tween = null
	if block.has_meta("tier_flash_tween"):
		flash_tween = block.get_meta("tier_flash_tween")
	if flash_tween is Tween:
		(flash_tween as Tween).kill()
	flash.color = Color(color.r, color.g, color.b, 0.15 + (float(tier) * 0.04))
	flash.modulate.a = 0.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(flash, "modulate:a", 1.0, 0.10)
	tw.tween_property(flash, "modulate:a", 0.0, 0.24)
	block.set_meta("tier_flash_tween", tw)

func _start_unit_info_stat_tier_loop(block: Panel, tier: int, color: Color) -> void:
	if block == null or tier <= 0:
		return
	_position_unit_info_stat_fx_nodes(block)
	var aura := block.get_node_or_null("TierAura") as ColorRect
	var arcs_root := _get_unit_info_stat_arcs_root(block)
	if aura == null or arcs_root == null:
		return
	var loop_tween = null
	if block.has_meta("tier_loop_tween"):
		loop_tween = block.get_meta("tier_loop_tween")
	if loop_tween is Tween:
		(loop_tween as Tween).kill()
	var arc_tweens_old: Array = []
	if block.has_meta("tier_arc_tweens"):
		var stored_arc_tweens_old = block.get_meta("tier_arc_tweens")
		if stored_arc_tweens_old is Array:
			arc_tweens_old = stored_arc_tweens_old
	if arc_tweens_old is Array:
		for item in arc_tweens_old:
			if item is Tween:
				(item as Tween).kill()

	var aura_color := color.lightened(0.10)
	aura.color = aura_color
	aura.modulate.a = 0.22 + (float(tier) * 0.06)
	arcs_root.visible = true

	var field_size: Vector2 = arcs_root.size
	var alpha_peak: float = float(min(0.96 + (float(tier) * 0.02), 1.0))
	var alpha_idle: float = 0.72 + (float(tier) * 0.05)
	var cycle_time: float = float(max(0.68 - (float(tier) * 0.07), 0.28))
	var perimeter: float = _unit_info_stat_arc_perimeter_length(field_size)
	var segment_length: float = clampf(perimeter * (0.13 + (float(tier) * 0.02)), 22.0, perimeter * 0.34)

	var tw := create_tween().set_parallel(true).set_loops()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(aura, "modulate:a", min(0.34 + (float(tier) * 0.08), 0.72), cycle_time * 0.60)
	tw.parallel().tween_property(aura, "modulate:a", 0.16 + (float(tier) * 0.05), cycle_time * 0.40).set_delay(cycle_time * 0.60)

	var arc_count: int = _unit_info_stat_arc_count_for_tier(tier)
	var arc_tweens: Array = []
	for idx in range(arcs_root.get_child_count()):
		var arc := arcs_root.get_child(idx) as ColorRect
		if arc == null:
			continue
		if idx >= arc_count:
			arc.modulate.a = 0.0
			continue
		var arc_color := color.lightened(0.22 + (float(idx) * 0.03))
		var start_offset: float = (perimeter / float(arc_count)) * float(idx)
		var end_offset: float = start_offset + (perimeter * (1.0 if idx % 2 == 0 else -1.0))
		var phase: float = float(idx) * 0.85
		arc.color = arc_color
		_set_unit_info_stat_arc_progress(start_offset, arc, field_size, segment_length, tier, phase, idx % 2 == 0)
		arc.modulate.a = alpha_idle
		var arc_tw := create_tween().set_parallel(true).set_loops()
		arc_tw.set_trans(Tween.TRANS_SINE)
		arc_tw.set_ease(Tween.EASE_IN_OUT)
		arc_tw.tween_method(
			Callable(self, "_set_unit_info_stat_arc_progress").bind(arc, field_size, segment_length, tier, phase, idx % 2 == 0),
			start_offset,
			end_offset,
			cycle_time
		)
		arc_tw.parallel().tween_property(arc, "modulate:a", alpha_peak, cycle_time * 0.44)
		arc_tw.parallel().tween_property(arc, "modulate:a", alpha_idle, cycle_time * 0.56).set_delay(cycle_time * 0.44)
		arc_tweens.append(arc_tw)
	block.set_meta("tier_loop_tween", tw)
	block.set_meta("tier_arc_tweens", arc_tweens)
	block.set_meta("tier_loop_tier", tier)

func _play_unit_info_stat_tier_fx(block: Panel, tier: int, color: Color) -> void:
	if block == null or tier <= 0:
		return
	_ensure_unit_info_stat_fx_nodes(block)
	_play_unit_info_stat_tier_flash(block, tier, color)
	_start_unit_info_stat_tier_loop(block, tier, color)

func _ensure_unit_info_stat_widgets() -> Control:
	if unit_info_panel == null:
		return null
	var root := unit_info_panel.get_node_or_null("UnitStatBarsRoot") as Control
	if root == null:
		root = Control.new()
		root.name = "UnitStatBarsRoot"
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unit_info_panel.add_child(root)

	for stat_def in _unit_info_stat_definitions():
		var stat_key: String = str(stat_def.get("key", ""))
		if stat_key == "":
			continue
		var panel_name := "StatBlock_%s" % stat_key
		var block := root.get_node_or_null(panel_name) as Panel
		if block == null:
			block = Panel.new()
			block.name = panel_name
			block.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(block)
		_style_tactical_panel(block, Color(0.10, 0.09, 0.07, 0.88), TACTICAL_UI_BORDER_MUTED, 1, 6)

		var name_label := block.get_node_or_null("Name") as Label
		if name_label == null:
			name_label = Label.new()
			name_label.name = "Name"
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.add_child(name_label)
		var value_label := block.get_node_or_null("Value") as Label
		if value_label == null:
			value_label = Label.new()
			value_label.name = "Value"
			value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.add_child(value_label)
		var bar := block.get_node_or_null("Bar") as ProgressBar
		if bar == null:
			bar = ProgressBar.new()
			bar.name = "Bar"
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			block.add_child(bar)

		_unit_info_stat_widgets[stat_key] = {
			"panel": block,
			"name": name_label,
			"value": value_label,
			"bar": bar,
		}

	_layout_unit_info_stat_widgets()
	return root

func _layout_unit_info_stat_widgets() -> void:
	var root: Control = null
	if unit_info_panel != null:
		root = unit_info_panel.get_node_or_null("UnitStatBarsRoot") as Control
	if root == null:
		return
	root.position = Vector2(16, 170)
	root.size = Vector2(210, 50)
	var block_width := 102.0
	var block_height := 16.0
	var gap_x := 6.0
	var gap_y := 2.0
	var defs := _unit_info_stat_definitions()
	for idx in range(defs.size()):
		var stat_key: String = str(defs[idx].get("key", ""))
		if not _unit_info_stat_widgets.has(stat_key):
			continue
		var widgets: Dictionary = _unit_info_stat_widgets[stat_key]
		var panel := widgets.get("panel") as Panel
		var name_label := widgets.get("name") as Label
		var value_label := widgets.get("value") as Label
		var bar := widgets.get("bar") as ProgressBar
		var col: int = idx % 2
		var row: int = idx / 2
		var pos := Vector2(col * (block_width + gap_x), row * (block_height + gap_y))
		if panel != null:
			panel.position = pos
			panel.size = Vector2(block_width, block_height)
			_ensure_unit_info_stat_fx_nodes(panel)
		if name_label != null:
			name_label.position = Vector2(4, 0)
			name_label.size = Vector2(30, 8)
			name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_style_tactical_label(name_label, TACTICAL_UI_TEXT_MUTED, 10, 2)
		if value_label != null:
			value_label.position = Vector2(34, 0)
			value_label.size = Vector2(64, 8)
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_style_tactical_label(value_label, TACTICAL_UI_TEXT, 10, 2)
		if bar != null:
			bar.min_value = 0.0
			bar.max_value = UNIT_INFO_STAT_BAR_CAP
			bar.position = Vector2(4, 9)
			bar.size = Vector2(94, 5)

func _set_unit_info_stat_widgets_visible(visible: bool) -> void:
	var root: Control = null
	if unit_info_panel != null:
		root = unit_info_panel.get_node_or_null("UnitStatBarsRoot") as Control
	if not visible and _unit_info_stat_anim_tween != null:
		_unit_info_stat_anim_tween.kill()
		_unit_info_stat_anim_tween = null
		_unit_info_stat_animating = false
		_unit_info_stat_anim_source_id = -1
	if root != null:
		if not visible:
			for child in root.get_children():
				if child is Panel:
					_stop_unit_info_stat_tier_fx(child as Panel)
		root.visible = visible

func _unit_info_stat_display_value(raw_value: int) -> float:
	if raw_value <= 0:
		return 0.0
	var cap_int := int(UNIT_INFO_STAT_BAR_CAP)
	if raw_value < cap_int:
		return float(raw_value)
	var wrapped := raw_value % cap_int
	if wrapped == 0:
		return UNIT_INFO_STAT_BAR_CAP
	return float(wrapped)

func _animate_unit_info_stat_widgets_in(display_values: Dictionary, source_id: int) -> void:
	if _unit_info_stat_anim_tween != null:
		_unit_info_stat_anim_tween.kill()
	_unit_info_stat_anim_tween = create_tween().set_parallel(true)
	_unit_info_stat_animating = true
	_unit_info_stat_anim_source_id = source_id
	var defs := _unit_info_stat_definitions()
	for idx in range(defs.size()):
		var stat_key: String = str(defs[idx].get("key", ""))
		if not _unit_info_stat_widgets.has(stat_key):
			continue
		var widgets: Dictionary = _unit_info_stat_widgets[stat_key]
		var panel := widgets.get("panel") as Panel
		var bar := widgets.get("bar") as ProgressBar
		var delay := float(idx) * 0.028
		if panel != null:
			panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
			_unit_info_stat_anim_tween.tween_property(panel, "modulate", Color.WHITE, 0.16).set_delay(delay)
		if bar != null:
			bar.value = 0.0
			_unit_info_stat_anim_tween.tween_property(bar, "value", float(display_values.get(stat_key, 0.0)), 0.22).set_delay(delay)
	_unit_info_stat_anim_tween.finished.connect(func():
		_unit_info_stat_anim_tween = null
		_unit_info_stat_animating = false
		_unit_info_stat_anim_source_id = -1
	, CONNECT_ONE_SHOT)

func _refresh_unit_info_stat_widgets(stat_values: Dictionary, animate: bool = false, source_id: int = -1) -> void:
	var root := _ensure_unit_info_stat_widgets()
	if root == null:
		return
	root.visible = true
	var display_values: Dictionary = {}
	for stat_def in _unit_info_stat_definitions():
		var stat_key: String = str(stat_def.get("key", ""))
		var stat_label: String = str(stat_def.get("label", stat_key))
		if not _unit_info_stat_widgets.has(stat_key):
			continue
		var widgets: Dictionary = _unit_info_stat_widgets[stat_key]
		var panel := widgets.get("panel") as Panel
		var name_label := widgets.get("name") as Label
		var value_label := widgets.get("value") as Label
		var bar := widgets.get("bar") as ProgressBar
		var raw_value: int = int(stat_values.get(stat_key, 0))
		var display_value := _unit_info_stat_display_value(raw_value)
		display_values[stat_key] = display_value
		var overcap: bool = raw_value >= int(UNIT_INFO_STAT_BAR_CAP)
		var fill_color := _unit_info_stat_fill_color(stat_key, raw_value)
		var tier := _unit_info_stat_tier_index(raw_value)
		var previous_tier := -1
		if panel != null and panel.has_meta("stat_tier"):
			previous_tier = int(panel.get_meta("stat_tier"))
		if panel != null:
			panel.modulate = Color.WHITE
			_style_tactical_panel(panel, Color(0.10, 0.09, 0.07, 0.88), fill_color if overcap else TACTICAL_UI_BORDER_MUTED, 1, 6)
			panel.set_meta("stat_tier", tier)
		if name_label != null:
			name_label.text = stat_label
			_style_tactical_label(name_label, fill_color, 11, 2)
		if value_label != null:
			value_label.text = str(raw_value)
			_style_tactical_label(value_label, fill_color if overcap else TACTICAL_UI_TEXT, 11, 2)
		if bar != null:
			_style_unit_info_stat_bar(bar, fill_color, overcap)
			if not animate and not (_unit_info_stat_animating and _unit_info_stat_anim_source_id == source_id):
				bar.value = display_value
		if panel != null:
			if tier <= 0:
				_stop_unit_info_stat_tier_fx(panel)
			elif animate or (previous_tier >= 0 and previous_tier != tier) or not panel.has_meta("tier_loop_tween"):
				_play_unit_info_stat_tier_fx(panel, tier, fill_color)
	if animate:
		_animate_unit_info_stat_widgets_in(display_values, source_id)

func _style_forecast_hp_bar(bar: ProgressBar, fill: Color) -> void:
	if bar == null:
		return
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _make_tactical_bar_style(Color(0.10, 0.09, 0.06, 0.98), Color(0.72, 0.61, 0.28, 1.0), 2, 6))
	bar.add_theme_stylebox_override("fill", _make_tactical_bar_style(fill, Color(0.85, 0.78, 0.44, 0.95), 1, 6))

func _forecast_hp_fill_color(current_hp: int, max_hp: int) -> Color:
	if max_hp <= 0:
		return Color(0.82, 0.25, 0.22, 1.0)
	var ratio: float = clampf(float(current_hp) / float(max_hp), 0.0, 1.0)
	if ratio >= 0.67:
		return Color(0.24, 0.86, 0.50, 1.0)
	if ratio >= 0.34:
		return Color(0.93, 0.74, 0.24, 1.0)
	return Color(0.92, 0.32, 0.27, 1.0)

func _truncate_forecast_text(text: String, max_chars: int) -> String:
	var clean: String = str(text).strip_edges()
	if max_chars <= 3 or clean.length() <= max_chars:
		return clean
	return clean.substr(0, max_chars - 3) + "..."

func _format_forecast_name(prefix: String, unit_name: String, max_name_chars: int = 14) -> String:
	var pre: String = str(prefix).strip_edges()
	var capped_name: String = _truncate_forecast_text(unit_name, max_name_chars)
	if pre == "":
		return capped_name
	return pre + ": " + capped_name

func _format_forecast_name_fitted(prefix: String, unit_name: String, max_total_chars: int = 18) -> String:
	var pre: String = str(prefix).strip_edges()
	var prefix_text: String = pre + ": " if pre != "" else ""
	var available_name_chars: int = maxi(4, max_total_chars - prefix_text.length())
	return prefix_text + _truncate_forecast_text(unit_name, available_name_chars)

func _forecast_weapon_marker(weapon: WeaponData) -> String:
	if weapon == null:
		return "[---]"
	if WeaponData.is_staff_like(weapon):
		return "[STF]"
	match int(weapon.weapon_type):
		WeaponData.WeaponType.SWORD:
			return "[SWD]"
		WeaponData.WeaponType.LANCE:
			return "[LNC]"
		WeaponData.WeaponType.AXE:
			return "[AXE]"
		WeaponData.WeaponType.BOW:
			return "[BOW]"
		WeaponData.WeaponType.TOME:
			return "[TOM]"
		WeaponData.WeaponType.KNIFE:
			return "[KNF]"
		WeaponData.WeaponType.FIREARM:
			return "[GUN]"
		WeaponData.WeaponType.FIST:
			return "[FST]"
		WeaponData.WeaponType.INSTRUMENT:
			return "[SON]"
		WeaponData.WeaponType.DARK_TOME:
			return "[DRK]"
		_:
			return "[---]"

func _format_forecast_weapon_text(weapon: WeaponData) -> String:
	if weapon == null:
		return "[---] UNARMED"
	return "%s %s" % [_forecast_weapon_marker(weapon), String(weapon.weapon_name).to_upper()]

func _format_forecast_weapon_name(weapon: WeaponData, max_chars: int = 14) -> String:
	if weapon == null:
		return "UNARMED"
	return _truncate_forecast_text(String(weapon.weapon_name).to_upper(), max_chars)

func _forecast_weapon_rarity_glow_color(weapon: WeaponData) -> Color:
	if weapon == null:
		return Color(0, 0, 0, 0)
	match String(weapon.rarity):
		"Rare":
			return Color(0.42, 0.72, 1.0, 0.22)
		"Epic":
			return Color(0.82, 0.50, 1.0, 0.22)
		"Legendary":
			return Color(1.0, 0.84, 0.38, 0.26)
		_:
			return Color(0, 0, 0, 0)

func _style_forecast_weapon_glow(glow_panel: Panel, glow_color: Color) -> void:
	if glow_panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = glow_color
	style.set_corner_radius_all(6)
	style.shadow_color = Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 1.6)
	style.shadow_size = 10
	style.shadow_offset = Vector2.ZERO
	glow_panel.add_theme_stylebox_override("panel", style)

func _ensure_tactical_backdrop(name: String) -> Panel:
	var ui_root := get_node_or_null("UI")
	if ui_root == null:
		return null
	var panel := ui_root.get_node_or_null(name) as Panel
	if panel != null:
		return panel
	panel = Panel.new()
	panel.name = name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(panel)
	ui_root.move_child(panel, 0)
	return panel

func _ensure_unit_details_button() -> Button:
	var ui_root := get_node_or_null("UI")
	if ui_root == null:
		return null
	if unit_details_button != null and is_instance_valid(unit_details_button):
		return unit_details_button
	var btn := ui_root.get_node_or_null("UnitDetailsButton") as Button
	if btn == null:
		btn = Button.new()
		btn.name = "UnitDetailsButton"
		btn.visible = false
		btn.focus_mode = Control.FOCUS_NONE
		ui_root.add_child(btn)
	unit_details_button = btn
	if not unit_details_button.pressed.is_connected(_on_unit_details_button_pressed):
		unit_details_button.pressed.connect(_on_unit_details_button_pressed)
	return unit_details_button

func _detach_tactical_action_buttons_to_ui_root() -> void:
	var ui_root := get_node_or_null("UI")
	if ui_root == null:
		return
	for btn in [open_inv_button, support_btn, _ensure_unit_details_button()]:
		if btn == null or not is_instance_valid(btn):
			continue
		if btn.get_parent() != ui_root:
			btn.reparent(ui_root)
		btn.top_level = false
		btn.mouse_filter = Control.MOUSE_FILTER_STOP

func _ensure_tactical_header(panel: Control, node_name: String, text: String) -> Label:
	if panel == null:
		return null
	var header := panel.get_node_or_null(node_name) as Label
	if header == null:
		header = Label.new()
		header.name = node_name
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(header)
	header.text = text
	header.position = Vector2(16, 10)
	header.size = Vector2(max(panel.size.x - 32.0, 120.0), 20)
	header.uppercase = true
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_tactical_label(header, TACTICAL_UI_TEXT_MUTED, 15, 3)
	return header

func _ensure_forecast_hp_bars() -> void:
	if forecast_panel == null:
		return
	if forecast_atk_hp_bar == null:
		forecast_atk_hp_bar = ProgressBar.new()
		forecast_atk_hp_bar.name = "AtkHPBar"
		forecast_panel.add_child(forecast_atk_hp_bar)
	if forecast_def_hp_bar == null:
		forecast_def_hp_bar = ProgressBar.new()
		forecast_def_hp_bar.name = "DefHPBar"
		forecast_panel.add_child(forecast_def_hp_bar)
	for bar in [forecast_atk_hp_bar, forecast_def_hp_bar]:
		if bar == null:
			continue
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.value = 100.0
		bar.step = 0.1
		bar.custom_minimum_size = Vector2(190, 10)
		bar.size = Vector2(190, 10)
		bar.z_index = 2
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_style_forecast_hp_bar(bar, Color(0.24, 0.86, 0.50, 1.0))

func _ensure_forecast_weapon_badges() -> void:
	if forecast_panel == null:
		return
	var specs: Array[Dictionary] = [
		{
			"panel_name": "AtkWeaponBadgePanel",
			"fill": Color(0.34, 0.17, 0.10, 0.92),
			"border": Color(0.94, 0.72, 0.42, 0.92),
			"text_color": Color(1.0, 0.88, 0.62, 1.0),
		},
		{
			"panel_name": "DefWeaponBadgePanel",
			"fill": Color(0.10, 0.18, 0.34, 0.92),
			"border": Color(0.58, 0.80, 1.0, 0.92),
			"text_color": Color(0.88, 0.95, 1.0, 1.0),
		},
	]
	for spec in specs:
		var panel_name: String = str(spec.get("panel_name", ""))
		var panel := forecast_panel.get_node_or_null(panel_name) as Panel
		if panel == null:
			panel = Panel.new()
			panel.name = panel_name
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			forecast_panel.add_child(panel)
		panel.z_index = 3
		_style_tactical_panel(panel, spec.get("fill", TACTICAL_UI_BG_SOFT), spec.get("border", TACTICAL_UI_BORDER), 1, 8)
		var badge_label := panel.get_node_or_null("Text") as Label
		if badge_label == null:
			badge_label = Label.new()
			badge_label.name = "Text"
			badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(badge_label)
		badge_label.position = Vector2.ZERO
		badge_label.size = panel.size
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_style_tactical_label(badge_label, spec.get("text_color", TACTICAL_UI_TEXT), 15, 3)

func _ensure_forecast_weapon_pair_frames() -> void:
	if forecast_panel == null:
		return
	for panel_name in ["AtkWeaponPairFrame", "DefWeaponPairFrame"]:
		var frame := forecast_panel.get_node_or_null(panel_name) as Panel
		if frame == null:
			frame = Panel.new()
			frame.name = panel_name
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			forecast_panel.add_child(frame)
		frame.z_index = 2
		_style_tactical_panel(frame, Color(0.16, 0.13, 0.09, 0.88), Color(0.46, 0.40, 0.26, 0.88), 1, 8)
		var bevel_top := frame.get_node_or_null("BevelTop") as ColorRect
		if bevel_top == null:
			bevel_top = ColorRect.new()
			bevel_top.name = "BevelTop"
			bevel_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(bevel_top)
		bevel_top.color = Color(1.0, 0.94, 0.74, 0.18)
		var bevel_bottom := frame.get_node_or_null("BevelBottom") as ColorRect
		if bevel_bottom == null:
			bevel_bottom = ColorRect.new()
			bevel_bottom.name = "BevelBottom"
			bevel_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(bevel_bottom)
		bevel_bottom.color = Color(0.0, 0.0, 0.0, 0.20)

func _ensure_forecast_weapon_icons() -> void:
	if forecast_panel == null:
		return
	for panel_name in ["AtkWeaponIconPanel", "DefWeaponIconPanel"]:
		var panel := forecast_panel.get_node_or_null(panel_name) as Panel
		if panel == null:
			panel = Panel.new()
			panel.name = panel_name
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			forecast_panel.add_child(panel)
		panel.z_index = 3
		_style_tactical_panel(panel, TACTICAL_UI_BG_SOFT, TACTICAL_UI_BORDER_MUTED, 1, 7)
		var glow_panel := panel.get_node_or_null("Glow") as Panel
		if glow_panel == null:
			glow_panel = Panel.new()
			glow_panel.name = "Glow"
			glow_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(glow_panel)
			panel.move_child(glow_panel, 0)
		glow_panel.position = Vector2(2, 2)
		glow_panel.size = Vector2(22, 22)
		glow_panel.visible = false
		var icon_rect := panel.get_node_or_null("Icon") as TextureRect
		if icon_rect == null:
			icon_rect = TextureRect.new()
			icon_rect.name = "Icon"
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(icon_rect)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.position = Vector2(3, 3)
		icon_rect.size = Vector2(20, 20)

func _reset_forecast_emphasis_visuals() -> void:
	if crit_flash_tween != null:
		crit_flash_tween.kill()
	for lbl in [forecast_atk_dmg, forecast_def_dmg, forecast_atk_crit, forecast_def_crit]:
		if lbl is Label:
			var ui_lbl := lbl as Label
			ui_lbl.modulate = Color.WHITE
			ui_lbl.scale = Vector2.ONE

func _start_forecast_emphasis_pulse(attacker_lethal: bool, defender_lethal: bool, attacker_crit_ready: bool, defender_crit_ready: bool) -> void:
	_reset_forecast_emphasis_visuals()
	var pulse_targets: Array[Dictionary] = []
	if attacker_lethal and forecast_atk_dmg != null:
		pulse_targets.append({
			"label": forecast_atk_dmg,
			"color": Color(1.0, 0.86, 0.62, 1.0),
			"scale": Vector2(1.08, 1.08),
		})
	if defender_lethal and forecast_def_dmg != null:
		pulse_targets.append({
			"label": forecast_def_dmg,
			"color": Color(0.74, 0.92, 1.0, 1.0),
			"scale": Vector2(1.08, 1.08),
		})
	if attacker_crit_ready and forecast_atk_crit != null:
		pulse_targets.append({
			"label": forecast_atk_crit,
			"color": Color(1.0, 0.94, 0.62, 1.0),
			"scale": Vector2(1.05, 1.05),
		})
	if defender_crit_ready and forecast_def_crit != null:
		pulse_targets.append({
			"label": forecast_def_crit,
			"color": Color(0.88, 0.94, 1.0, 1.0),
			"scale": Vector2(1.05, 1.05),
		})
	if pulse_targets.is_empty():
		return

	crit_flash_tween = create_tween().set_loops()
	crit_flash_tween.set_trans(Tween.TRANS_SINE)
	crit_flash_tween.set_ease(Tween.EASE_IN_OUT)

	var first_up: bool = true
	for pulse in pulse_targets:
		var lbl: Label = pulse.get("label") as Label
		if lbl == null:
			continue
		var pulse_color: Color = pulse.get("color", Color.WHITE)
		var pulse_scale: Vector2 = pulse.get("scale", Vector2.ONE)
		if first_up:
			crit_flash_tween.tween_property(lbl, "modulate", pulse_color, 0.55)
			crit_flash_tween.parallel().tween_property(lbl, "scale", pulse_scale, 0.55)
			first_up = false
		else:
			crit_flash_tween.parallel().tween_property(lbl, "modulate", pulse_color, 0.55)
			crit_flash_tween.parallel().tween_property(lbl, "scale", pulse_scale, 0.55)

	var first_down: bool = true
	for pulse in pulse_targets:
		var lbl_down: Label = pulse.get("label") as Label
		if lbl_down == null:
			continue
		if first_down:
			crit_flash_tween.tween_property(lbl_down, "modulate", Color.WHITE, 0.55)
			crit_flash_tween.parallel().tween_property(lbl_down, "scale", Vector2.ONE, 0.55)
			first_down = false
		else:
			crit_flash_tween.parallel().tween_property(lbl_down, "modulate", Color.WHITE, 0.55)
			crit_flash_tween.parallel().tween_property(lbl_down, "scale", Vector2.ONE, 0.55)

func _set_unit_portrait_block_visible(show: bool) -> void:
	if unit_portrait != null:
		unit_portrait.visible = show
	if unit_info_panel != null:
		var portrait_frame := unit_info_panel.get_node_or_null("PortraitFrame") as Panel
		if portrait_frame != null:
			portrait_frame.visible = show

func _apply_tactical_ui_overhaul() -> void:
	if not _tactical_ui_resize_hooked:
		var vp := get_viewport()
		if vp != null:
			vp.size_changed.connect(_queue_tactical_ui_overhaul)
		_tactical_ui_resize_hooked = true

	var ui_root := get_node_or_null("UI")
	if ui_root == null:
		return
	_ensure_unit_details_button()
	_detach_tactical_action_buttons_to_ui_root()

	for path in ["UI/BottomBarUI", "UI/ColorRect", "UI/ColorRect2", "UI/FramePortrait", "UI/Panel"]:
		var legacy := get_node_or_null(path) as CanvasItem
		if legacy != null:
			legacy.visible = false

	var vp_size := get_viewport_rect().size
	var hud_scale := TACTICAL_UI_HUD_SCALE
	var hud_scale_vec := Vector2(hud_scale, hud_scale)
	var bottom_panel_scale := hud_scale * TACTICAL_UI_BOTTOM_PANEL_SCALE_MULT
	var bottom_panel_scale_vec := Vector2(bottom_panel_scale, bottom_panel_scale)
	var rail_render_w: float = TACTICAL_UI_RAIL_WIDTH * hud_scale
	var info_h: float = 258.0
	var bottom_render_h: float = info_h * bottom_panel_scale
	var log_panel_h: float = TACTICAL_UI_BOTTOM_HEIGHT * TACTICAL_UI_LOG_HEIGHT_RATIO
	var log_render_h: float = log_panel_h * bottom_panel_scale
	var info_w: float = 384.0
	var info_render_w: float = info_w * bottom_panel_scale
	var hud_gap: float = 18.0 * bottom_panel_scale
	var right_x: float = vp_size.x - rail_render_w - TACTICAL_UI_MARGIN
	var bottom_y: float = vp_size.y - bottom_render_h - TACTICAL_UI_BOTTOM_EDGE_MARGIN
	var log_y: float = bottom_y + (bottom_render_h - log_render_h)
	var log_x: float = TACTICAL_UI_MARGIN + info_render_w + hud_gap
	var log_render_w: float = max(372.0 * bottom_panel_scale, right_x - log_x - (hud_gap + (44.0 * bottom_panel_scale)))
	var log_w: float = log_render_w / bottom_panel_scale

	var right_rail := _ensure_tactical_backdrop("TacticalRightRail")
	var show_deployment_rail: bool = current_state == pre_battle_state
	var show_battle_hud: bool = not show_deployment_rail
	if right_rail != null:
		right_rail.visible = false
		right_rail.position = Vector2(right_x, TACTICAL_UI_MARGIN)
		right_rail.size = Vector2(rail_render_w, vp_size.y - (TACTICAL_UI_MARGIN * 2.0))
		_style_tactical_panel(right_rail, TACTICAL_UI_BG, TACTICAL_UI_BORDER_MUTED, 1, 12)

	var bottom_backdrop := _ensure_tactical_backdrop("TacticalBottomBackdrop")
	if bottom_backdrop != null:
		bottom_backdrop.visible = false

	var gold_backdrop := _ensure_tactical_backdrop("TacticalGoldBackdrop")
	var objective_panel_render_bottom: float = 252.0
	var gold_panel_height: float = 32.0
	var gold_anchor_y: float = vp_size.y - gold_panel_height - TACTICAL_UI_BOTTOM_EDGE_MARGIN
	var command_cluster_margin_render: float = 18.0
	var command_button_gap_render: float = 4.0
	var command_button_height: float = 40.0
	var command_cluster_x: float = right_x + command_cluster_margin_render
	var command_cluster_width_render: float = rail_render_w - (command_cluster_margin_render * 2.0)
	var command_button_width: float = (command_cluster_width_render - command_button_gap_render) * 0.5
	var command_buttons_y: float = gold_anchor_y - command_button_height - 10.0
	if gold_backdrop != null:
		gold_backdrop.z_index = 18
		gold_backdrop.scale = Vector2.ONE
		gold_backdrop.position = Vector2(command_cluster_x, gold_anchor_y)
		gold_backdrop.size = Vector2(command_cluster_width_render, gold_panel_height)
		_style_tactical_panel(gold_backdrop, TACTICAL_UI_BG_ALT, TACTICAL_UI_BORDER_MUTED, 1, 8)

	if objective_toggle_btn != null:
		objective_toggle_btn.scale = hud_scale_vec
		objective_toggle_btn.z_index = 31
		objective_toggle_btn.position = Vector2(right_x + rail_render_w - (144.0 * hud_scale) - 10.0, 18.0)
		objective_toggle_btn.size = Vector2(144.0, 38.0)
		objective_toggle_btn.visible = show_battle_hud
		objective_toggle_btn.text = "Hide Goals" if is_objective_expanded else "Show Goals"
		_style_tactical_button(objective_toggle_btn, objective_toggle_btn.text, false, 18)

	if objective_panel != null:
		objective_panel.scale = hud_scale_vec
		objective_panel.z_index = 24
		objective_panel.clip_contents = true
		var objective_expanded_pos := Vector2(right_x + 12.0, 18.0 + (38.0 * hud_scale) + 14.0)
		var objective_collapsed_x: float = vp_size.x + 50.0
		objective_panel.position = Vector2(objective_expanded_pos.x if is_objective_expanded else objective_collapsed_x, objective_expanded_pos.y)
		objective_panel.size.x = TACTICAL_UI_RAIL_WIDTH - 24.0
		objective_panel.pivot_offset = objective_panel.size / 2.0
		objective_panel.visible = show_battle_hud
		objective_panel.set_meta("objective_expanded_x", objective_expanded_pos.x)
		objective_panel.set_meta("objective_collapsed_x", objective_collapsed_x)
		_style_tactical_panel(objective_panel, TACTICAL_UI_BG_ALT, TACTICAL_UI_BORDER, 2, 12)
		objective_panel_render_bottom = objective_panel.position.y + (objective_panel.size.y * hud_scale) + 18.0
	if objective_label != null:
		objective_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
		objective_label.scroll_active = true
		_style_tactical_richtext(objective_label, 19, 23)

	var skip_button := get_node_or_null("UI/SkipButton") as Button
	if skip_button != null:
		skip_button.scale = Vector2.ONE
		skip_button.position = Vector2(command_cluster_x, command_buttons_y)
		skip_button.size = Vector2(command_button_width, command_button_height)
		skip_button.visible = show_battle_hud
		_style_tactical_button(skip_button, "END TURN", true, 20)
		var end_turn_fill: Color = TACTICAL_UI_PRIMARY_FILL.lerp(TACTICAL_UI_ACCENT, 0.20)
		var end_turn_hover: Color = TACTICAL_UI_PRIMARY_HOVER.lerp(TACTICAL_UI_ACCENT, 0.28)
		var end_turn_press: Color = TACTICAL_UI_PRIMARY_PRESS.lerp(TACTICAL_UI_ACCENT, 0.12)
		skip_button.add_theme_stylebox_override("normal", _make_tactical_panel_style(end_turn_fill, TACTICAL_UI_ACCENT, 3, 10))
		skip_button.add_theme_stylebox_override("hover", _make_tactical_panel_style(end_turn_hover, TACTICAL_UI_ACCENT, 3, 10))
		skip_button.add_theme_stylebox_override("pressed", _make_tactical_panel_style(end_turn_press, TACTICAL_UI_ACCENT, 3, 10))
		skip_button.add_theme_stylebox_override("focus", _make_tactical_panel_style(end_turn_hover, TACTICAL_UI_ACCENT_SOFT, 3, 10))

	if convoy_button != null:
		convoy_button.scale = Vector2.ONE
		convoy_button.position = Vector2(
			command_cluster_x + command_button_width + command_button_gap_render,
			command_buttons_y
		)
		convoy_button.size = Vector2(command_button_width, command_button_height)
		convoy_button.visible = show_battle_hud
		_style_tactical_button(convoy_button, "CONVOY", false, 20)

	if gold_label != null:
		gold_label.z_index = 19
		gold_label.scale = Vector2.ONE
		gold_label.position = Vector2(command_cluster_x + 14.0, gold_anchor_y + 2.0)
		gold_label.size = Vector2(command_cluster_width_render - 28.0, 28.0)
		gold_label.visible = show_battle_hud
		gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_tactical_label(gold_label, TACTICAL_UI_ACCENT, 20, 4)
	if gold_backdrop != null:
		gold_backdrop.visible = show_battle_hud

	if unit_info_panel != null:
		unit_info_panel.scale = bottom_panel_scale_vec
		unit_info_panel.position = Vector2(TACTICAL_UI_MARGIN, bottom_y)
		unit_info_panel.size = Vector2(info_w, info_h)
		unit_info_panel.clip_contents = true
		_style_tactical_panel(unit_info_panel, TACTICAL_UI_BG_ALT, TACTICAL_UI_BORDER, 2, 12)
		var portrait_frame := unit_info_panel.get_node_or_null("PortraitFrame") as Panel
		if portrait_frame == null:
			portrait_frame = Panel.new()
			portrait_frame.name = "PortraitFrame"
			portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			unit_info_panel.add_child(portrait_frame)
			unit_info_panel.move_child(portrait_frame, 0)
		portrait_frame.z_index = 0
		portrait_frame.position = Vector2(240, 18)
		portrait_frame.size = Vector2(122, 156)
		_style_tactical_panel(portrait_frame, TACTICAL_UI_BG_SOFT, TACTICAL_UI_BORDER_MUTED, 1, 8)

	if unit_name_label != null:
		unit_name_label.position = Vector2(18, 16)
		unit_name_label.size = Vector2(208, 30)
		unit_name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_style_tactical_label(unit_name_label, TACTICAL_UI_ACCENT, 24, 4)
	if unit_hp_label != null:
		unit_hp_label.position = Vector2(18, 35)
		unit_hp_label.size = Vector2(208, 16)
		unit_hp_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_style_tactical_label(unit_hp_label, TACTICAL_UI_ACCENT_SOFT, 14, 3)
		var header_divider := unit_info_panel.get_node_or_null("HeaderDivider") as Panel
		if header_divider == null:
			header_divider = Panel.new()
			header_divider.name = "HeaderDivider"
			header_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			unit_info_panel.add_child(header_divider)
		header_divider.position = Vector2(18, 53)
		header_divider.size = Vector2(208, 3)
		header_divider.z_index = 1
		_style_tactical_panel(
			header_divider,
			Color(0.19, 0.16, 0.10, 0.92),
			Color(0.55, 0.48, 0.26, 0.55),
			1,
			4
		)
	if unit_stats_label != null:
		unit_stats_label.position = Vector2(16, 142)
		unit_stats_label.size = Vector2(210, 24)
		unit_stats_label.scroll_active = false
		_style_tactical_richtext(unit_stats_label, 11, 12)
	_ensure_unit_info_primary_widgets()
	_layout_unit_info_primary_widgets()
	_ensure_unit_info_stat_widgets()
	_layout_unit_info_stat_widgets()
	if unit_portrait != null:
		unit_portrait.z_index = 1
		unit_portrait.position = Vector2(244, 22)
		unit_portrait.size = Vector2(114, 148)
		unit_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		unit_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if open_inv_button != null:
		open_inv_button.top_level = false
		open_inv_button.scale = bottom_panel_scale_vec
		open_inv_button.position = unit_info_panel.position + (Vector2(16, 228) * bottom_panel_scale)
		open_inv_button.size = Vector2(92, 28)
		open_inv_button.z_index = 20
		_style_tactical_button(open_inv_button, "ITEMS", false, 18)
	if support_btn != null:
		support_btn.top_level = false
		support_btn.scale = bottom_panel_scale_vec
		support_btn.position = unit_info_panel.position + (Vector2(112, 228) * bottom_panel_scale)
		support_btn.size = Vector2(104, 28)
		support_btn.z_index = 20
		_style_tactical_button(support_btn, "SUPPORTS", false, 16)
	if unit_details_button != null:
		unit_details_button.top_level = false
		unit_details_button.scale = bottom_panel_scale_vec
		unit_details_button.position = unit_info_panel.position + (Vector2(238, 228) * bottom_panel_scale)
		unit_details_button.size = Vector2(122, 28)
		unit_details_button.z_index = 20
		unit_details_button.visible = true
		_style_tactical_button(unit_details_button, "UNIT INFO", false, 16)

	var battle_log_panel: Panel = null
	if battle_log != null:
		battle_log_panel = battle_log.get_parent() as Panel
	if battle_log_panel != null:
		var field_log_toggle_gap: float = 8.0 * bottom_panel_scale
		var field_log_toggle_size := Vector2(132.0, 28.0)
		var field_log_toggle_render_size: Vector2 = field_log_toggle_size * bottom_panel_scale
		var field_log_expanded_button_pos := Vector2(
			log_x + log_render_w - field_log_toggle_render_size.x - (12.0 * bottom_panel_scale),
			log_y - field_log_toggle_render_size.y - field_log_toggle_gap
		)
		var field_log_collapsed_panel_y: float = vp_size.y + (6.0 * bottom_panel_scale)
		var field_log_collapsed_button_y: float = field_log_collapsed_panel_y - field_log_toggle_render_size.y - field_log_toggle_gap
		battle_log_panel.scale = bottom_panel_scale_vec
		battle_log_panel.position = Vector2(log_x, log_y)
		battle_log_panel.size = Vector2(log_w, log_panel_h)
		battle_log_panel.set_meta("field_log_expanded_y", log_y)
		battle_log_panel.set_meta("field_log_collapsed_y", field_log_collapsed_panel_y)
		_style_tactical_panel(battle_log_panel, Color(0.12, 0.11, 0.09, 0.88), Color(0.46, 0.40, 0.28, 0.44), 1, 10)
		var legacy_log_fill := battle_log_panel.get_node_or_null("ColorRect") as ColorRect
		if legacy_log_fill != null:
			legacy_log_fill.visible = false
		var log_header := _ensure_tactical_header(battle_log_panel, "HeaderLabel", "Field Log")
		if log_header != null:
			_style_tactical_label(log_header, TACTICAL_UI_TEXT_MUTED, 13, 3)
		var field_log_toggle := _ensure_field_log_toggle_button()
		if field_log_toggle != null:
			field_log_toggle.scale = bottom_panel_scale_vec
			field_log_toggle.size = field_log_toggle_size
			field_log_toggle.position = field_log_expanded_button_pos
			field_log_toggle.z_index = 22
			field_log_toggle.set_meta("field_log_expanded_y", field_log_expanded_button_pos.y)
			field_log_toggle.set_meta("field_log_collapsed_y", field_log_collapsed_button_y)
			field_log_toggle.custom_minimum_size = field_log_toggle_size
			_set_field_log_toggle_button_text()
			_apply_field_log_visibility(false)
	elif field_log_toggle_btn != null and is_instance_valid(field_log_toggle_btn):
		field_log_toggle_btn.visible = false
	if battle_log != null:
		battle_log.position = Vector2(16, 36)
		battle_log.size = Vector2(log_w - 32.0, log_panel_h - 50.0)
		battle_log.scroll_active = true
		_style_tactical_richtext(battle_log, 13, 15)

	if forecast_panel != null:
		var forecast_size := Vector2(540.0, 360.0)
		forecast_panel.position = Vector2(max(260.0, right_x - forecast_size.x - 20.0), max(120.0, bottom_y - forecast_size.y - 18.0))
		forecast_panel.size = forecast_size
		forecast_panel.clip_contents = false
		_style_tactical_panel(forecast_panel, TACTICAL_UI_BG_ALT, TACTICAL_UI_BORDER, 2, 12)
		var forecast_left_tint := forecast_panel.get_node_or_null("ForecastLeftTint") as ColorRect
		if forecast_left_tint == null:
			forecast_left_tint = ColorRect.new()
			forecast_left_tint.name = "ForecastLeftTint"
			forecast_left_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			forecast_panel.add_child(forecast_left_tint)
		forecast_left_tint.position = Vector2(14.0, 16.0)
		forecast_left_tint.size = Vector2(214.0, 236.0)
		forecast_left_tint.color = Color(0.78, 0.30, 0.18, 0.08)
		var forecast_right_tint := forecast_panel.get_node_or_null("ForecastRightTint") as ColorRect
		if forecast_right_tint == null:
			forecast_right_tint = ColorRect.new()
			forecast_right_tint.name = "ForecastRightTint"
			forecast_right_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			forecast_panel.add_child(forecast_right_tint)
		forecast_right_tint.position = Vector2(forecast_size.x - 228.0, 16.0)
		forecast_right_tint.size = Vector2(214.0, 236.0)
		forecast_right_tint.color = Color(0.18, 0.35, 0.76, 0.08)
		forecast_panel.move_child(forecast_left_tint, 0)
		forecast_panel.move_child(forecast_right_tint, 1)
		var center_line_top := forecast_panel.get_node_or_null("CenterLineTop") as ColorRect
		if center_line_top == null:
			center_line_top = ColorRect.new()
			center_line_top.name = "CenterLineTop"
			center_line_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
			forecast_panel.add_child(center_line_top)
		center_line_top.position = Vector2((forecast_size.x * 0.5) - 1.0, 24.0)
		center_line_top.size = Vector2(2.0, 92.0)
		center_line_top.color = Color(0.73, 0.64, 0.34, 0.68)
		var center_line_bottom := forecast_panel.get_node_or_null("CenterLineBottom") as ColorRect
		if center_line_bottom == null:
			center_line_bottom = ColorRect.new()
			center_line_bottom.name = "CenterLineBottom"
			center_line_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
			forecast_panel.add_child(center_line_bottom)
		center_line_bottom.position = Vector2((forecast_size.x * 0.5) - 1.0, 164.0)
		center_line_bottom.size = Vector2(2.0, 94.0)
		center_line_bottom.color = Color(0.73, 0.64, 0.34, 0.56)
		var center_badge := forecast_panel.get_node_or_null("CenterBadge") as Label
		if center_badge == null:
			center_badge = Label.new()
			center_badge.name = "CenterBadge"
			center_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			forecast_panel.add_child(center_badge)
		center_badge.text = "VS"
		center_badge.position = Vector2((forecast_size.x * 0.5) - 24.0, 126.0)
		center_badge.size = Vector2(48.0, 26.0)
		center_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_tactical_label(center_badge, Color(1.0, 0.90, 0.58), 18, 3)
		_ensure_forecast_support_labels()
		_ensure_forecast_hp_bars()
		_ensure_forecast_weapon_badges()
		_ensure_forecast_weapon_pair_frames()
		_ensure_forecast_weapon_icons()
		var atk_weapon_pair_frame := forecast_panel.get_node_or_null("AtkWeaponPairFrame") as Panel
		var def_weapon_pair_frame := forecast_panel.get_node_or_null("DefWeaponPairFrame") as Panel
		var atk_weapon_badge_panel := forecast_panel.get_node_or_null("AtkWeaponBadgePanel") as Panel
		var def_weapon_badge_panel := forecast_panel.get_node_or_null("DefWeaponBadgePanel") as Panel
		var atk_weapon_icon_panel := forecast_panel.get_node_or_null("AtkWeaponIconPanel") as Panel
		var def_weapon_icon_panel := forecast_panel.get_node_or_null("DefWeaponIconPanel") as Panel
		var left_col_x := 24.0
		var right_col_x := forecast_size.x - 214.0
		var col_w := 190.0
		var stat_y := {
			"name": 18.0,
			"hp": 54.0,
			"bar": 78.0,
			"hit": 92.0,
			"dmg": 126.0,
			"crit": 160.0,
			"support": 194.0,
			"weapon": 222.0,
			"footer": 250.0,
			"instruction": 266.0,
			"reaction": 290.0,
			"buttons": 306.0,
		}
		var name_labels: Array = [forecast_atk_name, forecast_def_name]
		var hp_labels: Array = [forecast_atk_hp, forecast_def_hp]
		var hit_labels: Array = [forecast_atk_hit, forecast_def_hit]
		var dmg_labels: Array = [forecast_atk_dmg, forecast_def_dmg]
		var crit_labels: Array = [forecast_atk_crit, forecast_def_crit]
		var support_labels: Array = [forecast_atk_support_label, forecast_def_support_label]
		var weapon_labels: Array = [forecast_atk_weapon, forecast_def_weapon]
		var adv_labels: Array = [forecast_atk_adv, forecast_def_adv]
		var double_labels: Array = [forecast_atk_double, forecast_def_double]
		var col_positions: Array[float] = [left_col_x, right_col_x]
		for idx in range(2):
			var base_x: float = col_positions[idx]
			var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT if idx == 0 else HORIZONTAL_ALIGNMENT_RIGHT
			var name_lbl := name_labels[idx] as Label
			if name_lbl != null:
				name_lbl.position = Vector2(base_x, stat_y["name"])
				name_lbl.size = Vector2(col_w, 28)
				name_lbl.horizontal_alignment = align
				name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
				name_lbl.clip_text = true
				name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			var hp_lbl := hp_labels[idx] as Label
			if hp_lbl != null:
				hp_lbl.position = Vector2(base_x, stat_y["hp"])
				hp_lbl.size = Vector2(col_w, 24)
				hp_lbl.horizontal_alignment = align
			var hp_bar: ProgressBar = forecast_atk_hp_bar if idx == 0 else forecast_def_hp_bar
			if hp_bar != null:
				hp_bar.position = Vector2(base_x, stat_y["bar"])
				hp_bar.size = Vector2(col_w, 10)
			var hit_lbl := hit_labels[idx] as Label
			if hit_lbl != null:
				hit_lbl.position = Vector2(base_x, stat_y["hit"])
				hit_lbl.size = Vector2(col_w, 22)
				hit_lbl.horizontal_alignment = align
			var dmg_lbl := dmg_labels[idx] as Label
			if dmg_lbl != null:
				dmg_lbl.position = Vector2(base_x, stat_y["dmg"])
				dmg_lbl.size = Vector2(col_w, 22)
				dmg_lbl.horizontal_alignment = align
			var crit_lbl := crit_labels[idx] as Label
			if crit_lbl != null:
				crit_lbl.position = Vector2(base_x, stat_y["crit"])
				crit_lbl.size = Vector2(col_w, 22)
				crit_lbl.horizontal_alignment = align
			var support_lbl := support_labels[idx] as Label
			if support_lbl != null:
				support_lbl.position = Vector2(base_x, stat_y["support"])
				support_lbl.size = Vector2(col_w, 22)
				support_lbl.horizontal_alignment = align
			var weapon_lbl := weapon_labels[idx] as Label
			if weapon_lbl != null:
				if idx == 0:
					weapon_lbl.position = Vector2(base_x + 96.0, stat_y["weapon"])
				else:
					weapon_lbl.position = Vector2(base_x, stat_y["weapon"])
				weapon_lbl.size = Vector2(col_w - 100.0, 22)
				weapon_lbl.horizontal_alignment = align
				weapon_lbl.clip_text = true
				weapon_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			var adv_lbl := adv_labels[idx] as Label
			if adv_lbl != null:
				adv_lbl.position = Vector2(base_x, stat_y["footer"])
				adv_lbl.size = Vector2(110.0, 22)
				adv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if idx == 0 else HORIZONTAL_ALIGNMENT_RIGHT
			var double_lbl := double_labels[idx] as Label
			if double_lbl != null:
				var double_x := base_x + 118.0 if idx == 0 else base_x + 118.0
				double_lbl.position = Vector2(double_x, stat_y["dmg"])
				double_lbl.size = Vector2(60.0, 22)
				double_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if atk_weapon_badge_panel != null:
			atk_weapon_badge_panel.position = Vector2(left_col_x, stat_y["weapon"] - 4.0)
			atk_weapon_badge_panel.size = Vector2(56.0, 26.0)
			var atk_badge_label := atk_weapon_badge_panel.get_node_or_null("Text") as Label
			if atk_badge_label != null:
				atk_badge_label.size = atk_weapon_badge_panel.size
		if atk_weapon_pair_frame != null:
			atk_weapon_pair_frame.position = Vector2(left_col_x - 6.0, stat_y["weapon"] - 6.0)
			atk_weapon_pair_frame.size = Vector2(96.0, 30.0)
			var atk_bevel_top := atk_weapon_pair_frame.get_node_or_null("BevelTop") as ColorRect
			if atk_bevel_top != null:
				atk_bevel_top.position = Vector2(4, 3)
				atk_bevel_top.size = Vector2(atk_weapon_pair_frame.size.x - 8.0, 2.0)
			var atk_bevel_bottom := atk_weapon_pair_frame.get_node_or_null("BevelBottom") as ColorRect
			if atk_bevel_bottom != null:
				atk_bevel_bottom.position = Vector2(4, atk_weapon_pair_frame.size.y - 5.0)
				atk_bevel_bottom.size = Vector2(atk_weapon_pair_frame.size.x - 8.0, 2.0)
		if atk_weapon_icon_panel != null:
			atk_weapon_icon_panel.position = Vector2(left_col_x + 62.0, stat_y["weapon"] - 4.0)
			atk_weapon_icon_panel.size = Vector2(26.0, 26.0)
			var atk_glow := atk_weapon_icon_panel.get_node_or_null("Glow") as Panel
			if atk_glow != null:
				atk_glow.position = Vector2(2, 2)
				atk_glow.size = Vector2(22, 22)
		if def_weapon_badge_panel != null:
			def_weapon_badge_panel.position = Vector2(right_col_x + col_w - 56.0, stat_y["weapon"] - 4.0)
			def_weapon_badge_panel.size = Vector2(56.0, 26.0)
			var def_badge_label := def_weapon_badge_panel.get_node_or_null("Text") as Label
			if def_badge_label != null:
				def_badge_label.size = def_weapon_badge_panel.size
		if def_weapon_pair_frame != null:
			def_weapon_pair_frame.position = Vector2(right_col_x + col_w - 90.0, stat_y["weapon"] - 6.0)
			def_weapon_pair_frame.size = Vector2(96.0, 30.0)
			var def_bevel_top := def_weapon_pair_frame.get_node_or_null("BevelTop") as ColorRect
			if def_bevel_top != null:
				def_bevel_top.position = Vector2(4, 3)
				def_bevel_top.size = Vector2(def_weapon_pair_frame.size.x - 8.0, 2.0)
			var def_bevel_bottom := def_weapon_pair_frame.get_node_or_null("BevelBottom") as ColorRect
			if def_bevel_bottom != null:
				def_bevel_bottom.position = Vector2(4, def_weapon_pair_frame.size.y - 5.0)
				def_bevel_bottom.size = Vector2(def_weapon_pair_frame.size.x - 8.0, 2.0)
		if def_weapon_icon_panel != null:
			def_weapon_icon_panel.position = Vector2(right_col_x + col_w - 88.0, stat_y["weapon"] - 4.0)
			def_weapon_icon_panel.size = Vector2(26.0, 26.0)
			var def_glow := def_weapon_icon_panel.get_node_or_null("Glow") as Panel
			if def_glow != null:
				def_glow.position = Vector2(2, 2)
				def_glow.size = Vector2(22, 22)
	for lbl in [forecast_atk_name, forecast_atk_hp, forecast_atk_dmg, forecast_atk_hit, forecast_atk_crit, forecast_atk_weapon, forecast_atk_adv, forecast_atk_double, forecast_def_name, forecast_def_hp, forecast_def_dmg, forecast_def_hit, forecast_def_crit, forecast_def_weapon, forecast_def_adv, forecast_def_double]:
		if lbl is Label:
			_style_tactical_label(lbl as Label, TACTICAL_UI_TEXT, 23, 3)
	for name_lbl in [forecast_atk_name, forecast_def_name]:
		if name_lbl is Label:
			_style_tactical_label(name_lbl as Label, Color(1.0, 0.90, 0.54), 24, 4)
	if forecast_atk_name != null:
		forecast_atk_name.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52))
	if forecast_def_name != null:
		forecast_def_name.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	for hp_lbl in [forecast_atk_hp, forecast_def_hp]:
		if hp_lbl is Label:
			_style_tactical_label(hp_lbl as Label, Color(0.90, 0.96, 0.92), 21, 3)
	for hit_lbl in [forecast_atk_hit, forecast_def_hit]:
		if hit_lbl is Label:
			_style_tactical_label(hit_lbl as Label, Color(0.57, 0.94, 1.0), 20, 3)
	if forecast_atk_dmg != null:
		_style_tactical_label(forecast_atk_dmg, Color(1.0, 0.72, 0.49), 20, 3)
	if forecast_def_dmg != null:
		_style_tactical_label(forecast_def_dmg, Color(0.67, 0.87, 1.0), 20, 3)
	for crit_lbl in [forecast_atk_crit, forecast_def_crit]:
		if crit_lbl is Label:
			_style_tactical_label(crit_lbl as Label, Color(1.0, 0.84, 0.38), 20, 3)
	for weapon_lbl in [forecast_atk_weapon, forecast_def_weapon]:
		if weapon_lbl is Label:
			_style_tactical_label(weapon_lbl as Label, Color(0.93, 0.91, 0.80), 20, 3)
	if forecast_atk_weapon != null:
		forecast_atk_weapon.add_theme_color_override("font_color", Color(1.0, 0.84, 0.68))
	if forecast_def_weapon != null:
		forecast_def_weapon.add_theme_color_override("font_color", Color(0.78, 0.90, 1.0))
	for adv_lbl in [forecast_atk_adv, forecast_def_adv]:
		if adv_lbl is Label:
			_style_tactical_label(adv_lbl as Label, Color(0.76, 0.96, 0.62), 19, 3)
	for dbl in [forecast_atk_double, forecast_def_double]:
		if dbl is Label:
			_style_tactical_label(dbl as Label, Color(0.48, 0.90, 1.0), 23, 3)
	var forecast_confirm := get_node_or_null("UI/CombatForecastPanel/ConfirmButton") as Button
	var forecast_cancel := get_node_or_null("UI/CombatForecastPanel/CancelButton") as Button
	if forecast_confirm != null:
		_style_tactical_button(forecast_confirm, "ATTACK", true, 22)
	if forecast_cancel != null:
		_style_tactical_button(forecast_cancel, "BACK", false, 22)
	if forecast_talk_btn != null:
		_style_tactical_button(forecast_talk_btn, "TALK", false, 20)
	if forecast_ability_btn != null:
		_style_tactical_button(forecast_ability_btn, "ABILITY", false, 20)
	if forecast_instruction_label != null:
		forecast_instruction_label.position = Vector2(24, 262)
		forecast_instruction_label.size = Vector2(492, 20)
		forecast_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		forecast_instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_style_tactical_label(forecast_instruction_label, Color(0.84, 0.84, 0.90), 14, 2)
	if forecast_reaction_label != null:
		forecast_reaction_label.position = Vector2(24, 284)
		forecast_reaction_label.size = Vector2(492, 18)
		forecast_reaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		forecast_reaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_style_tactical_label(forecast_reaction_label, Color(0.96, 0.85, 0.57), 13, 2)
	if forecast_confirm != null:
		forecast_confirm.position = Vector2(110, 306)
		forecast_confirm.size = Vector2(158, 42)
	if forecast_cancel != null:
		forecast_cancel.position = Vector2(282, 306)
		forecast_cancel.size = Vector2(158, 42)
	if forecast_talk_btn != null and forecast_ability_btn != null:
		forecast_talk_btn.position = Vector2(24, 372)
		forecast_talk_btn.size = Vector2(96, 42)
		forecast_ability_btn.position = Vector2(126, 372)
		forecast_ability_btn.size = Vector2(96, 42)
	elif forecast_talk_btn != null:
		forecast_talk_btn.position = Vector2(24, 372)
		forecast_talk_btn.size = Vector2(96, 42)
	elif forecast_ability_btn != null:
		forecast_ability_btn.position = Vector2(24, 372)
		forecast_ability_btn.size = Vector2(96, 42)

	if inventory_panel != null:
		_style_tactical_panel(inventory_panel, TACTICAL_UI_BG_ALT, TACTICAL_UI_BORDER, 2, 12)
		var inv_item_info := inventory_panel.get_node_or_null("Panel") as Panel
		_style_inventory_item_info_backdrop(inv_item_info)
	if inv_desc_label != null:
		_style_tactical_richtext(inv_desc_label, 21, 26)
		inv_desc_label.add_theme_constant_override("line_separation", 7)
		inv_desc_label.scroll_active = false
		inv_desc_label.z_index = 2
	_style_tactical_button(equip_button, "EQUIP", false, 18)
	_style_tactical_button(use_button, "USE", false, 18)
	var inv_close := get_node_or_null("UI/InventoryPanel/CloseButton") as Button
	if inv_close != null:
		_style_tactical_button(inv_close, "CLOSE", false, 18)
	var inv_item_list := get_node_or_null("UI/InventoryPanel/ItemList") as ItemList
	_style_tactical_item_list(inv_item_list)
	_apply_inventory_panel_item_list_extra_margins(inv_item_list)
	_style_tactical_item_list(get_node_or_null("UI/RosterPanel/RosterList") as ItemList)
	_style_tactical_item_list(loot_item_list)

	if loot_window != null:
		_style_tactical_panel(loot_window, TACTICAL_UI_BG_ALT, TACTICAL_UI_BORDER, 2, 12)
		_ensure_loot_item_info_ui()
	if loot_desc_label != null:
		_style_tactical_richtext(loot_desc_label, 21, 26)
		loot_desc_label.add_theme_constant_override("line_separation", 7)
	if close_loot_button != null:
		_style_tactical_button(close_loot_button, "CLAIM ALL", true, 20)

	if support_tracker_panel != null:
		_style_tactical_panel(support_tracker_panel, TACTICAL_UI_BG_ALT, TACTICAL_UI_BORDER, 2, 12)
	if support_list_text != null:
		_style_tactical_richtext(support_list_text, 18, 20)
	if close_support_btn != null:
		_style_tactical_button(close_support_btn, "CLOSE", false, 18)

	if trade_popup != null:
		_style_tactical_panel(trade_popup, TACTICAL_UI_BG_ALT, TACTICAL_UI_BORDER, 2, 12)
	if trade_popup_btn != null:
		_style_tactical_button(trade_popup_btn, "TRADE", false, 18)
	if popup_talk_btn != null:
		_style_tactical_button(popup_talk_btn, "SUPPORT TALK", false, 16)

	if trade_window != null:
		_style_tactical_panel(trade_window, TACTICAL_UI_BG_ALT, TACTICAL_UI_BORDER, 2, 12)
	for lbl in [trade_left_name, trade_right_name]:
		if lbl is Label:
			_style_tactical_label(lbl as Label, TACTICAL_UI_ACCENT, 20, 3)
	if trade_close_btn != null:
		_style_tactical_button(trade_close_btn, "CLOSE", false, 18)
	_style_tactical_item_list(trade_left_list)
	_style_tactical_item_list(trade_right_list)

	if talk_panel != null:
		_style_tactical_panel(talk_panel, TACTICAL_UI_BG_ALT, TACTICAL_UI_BORDER, 2, 12)
	if talk_name != null:
		_style_tactical_label(talk_name, TACTICAL_UI_ACCENT, 22, 4)
	if talk_text != null:
		_style_tactical_richtext(talk_text, 19, 21)
	if talk_next_btn != null:
		_style_tactical_button(talk_next_btn, "CONTINUE", true, 18)

	if level_up_panel != null:
		_style_tactical_panel(level_up_panel, TACTICAL_UI_BG_ALT, TACTICAL_UI_BORDER, 2, 14)
	if level_up_title != null:
		_style_tactical_label(level_up_title, TACTICAL_UI_ACCENT, 30, 5)
	if level_up_stats != null:
		_style_tactical_richtext(level_up_stats, 18, 20)

	if game_over_panel != null:
		_style_tactical_panel(game_over_panel, Color(0.06, 0.05, 0.04, 0.96), TACTICAL_UI_BORDER, 3, 16)
	if result_label != null:
		_style_tactical_label(result_label, TACTICAL_UI_ACCENT, 66, 6)
	_style_tactical_button(restart_button, restart_button.text if restart_button != null else "PLAY AGAIN", true, 24)
	_style_tactical_button(continue_button, continue_button.text if continue_button != null else "CONTINUE", false, 24)

	var roster_panel := get_node_or_null("UI/RosterPanel") as Panel
	var count_text := get_node_or_null("UI/RosterPanel/DeployCountLabel") as Label
	var roster_items := get_node_or_null("UI/RosterPanel/RosterList") as ItemList
	var build_button := get_node_or_null("UI/RosterPanel/BuildButton") as Button
	var deploy_bond_panel: Panel = get_node_or_null("UI/RosterPanel/DeployBondPanel") as Panel
	var deploy_bond_block_h: float = TACTICAL_DEPLOY_ROSTER_BONDS_H
	if roster_panel != null and show_deployment_rail and roster_panel.get_meta("deploy_bond_hidden", false):
		deploy_bond_block_h = 0.0
	if roster_panel != null:
		if show_deployment_rail:
			if deploy_roster_toggle_tween != null:
				deploy_roster_toggle_tween.kill()
				deploy_roster_toggle_tween = null
		roster_panel.visible = show_deployment_rail
		roster_panel.scale = hud_scale_vec
		# Pre-battle: objective HUD is hidden — don't force the 252px floor; use full-height column.
		var roster_top: float = (TACTICAL_UI_MARGIN if show_deployment_rail else maxf(252.0, objective_panel_render_bottom))
		var roster_w: float = TACTICAL_DEPLOY_ROSTER_PANEL_WIDTH if show_deployment_rail else (TACTICAL_UI_RAIL_WIDTH - 24.0)
		var roster_bottom_px: float = (108.0 * hud_scale) if not show_deployment_rail else (TACTICAL_DEPLOY_ROSTER_VIEWPORT_BOTTOM_RESERVE * hud_scale)
		var roster_base_h: float = max(180.0, (vp_size.y - roster_top - roster_bottom_px) / hud_scale)
		if show_deployment_rail:
			var min_deploy_h: float = 124.0 + deploy_bond_block_h + TACTICAL_DEPLOY_ROSTER_MIN_LIST_H
			roster_base_h = maxf(roster_base_h, min_deploy_h)
		roster_panel.size = Vector2(roster_w, roster_base_h)
		var roster_visual_w: float = roster_w * hud_scale
		var roster_left: float = clampf(right_x + 12.0, 8.0, maxf(8.0, vp_size.x - roster_visual_w - 8.0))
		roster_panel.position.y = roster_top
		roster_panel.set_meta("deploy_rail_expanded_x", roster_left)
		roster_panel.set_meta("deploy_rail_collapsed_x", vp_size.x + 24.0)
		_style_tactical_panel(roster_panel, TACTICAL_UI_BG_ALT, TACTICAL_UI_BORDER, 2, 12)
		# Pre-battle: let the player hide the deploy column for an unobstructed map view (slide + tween, same feel as field log).
		var d_toggle := _ensure_deploy_roster_toggle_button()
		if d_toggle != null and show_deployment_rail:
			d_toggle.visible = true
			d_toggle.scale = hud_scale_vec
			d_toggle.z_index = 28
			var tog_w: float = 132.0 * hud_scale
			var tog_h: float = 38.0 * hud_scale
			d_toggle.size = Vector2(tog_w, tog_h)
			d_toggle.position.y = roster_top
			d_toggle.set_meta("deploy_rail_btn_expanded_x", maxf(8.0, roster_left - tog_w - 10.0))
			d_toggle.set_meta("deploy_rail_btn_collapsed_x", vp_size.x - tog_w - TACTICAL_UI_MARGIN)
			_apply_deployment_rail_visibility(false)
		elif d_toggle != null:
			if deploy_roster_toggle_tween != null:
				deploy_roster_toggle_tween.kill()
				deploy_roster_toggle_tween = null
			d_toggle.visible = false
	if count_text != null and roster_panel != null:
		count_text.position = Vector2(16, 16)
		count_text.size = Vector2(roster_panel.size.x - 32.0, 24.0)
		count_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_tactical_label(count_text, TACTICAL_UI_ACCENT, 21, 4)
	if roster_items != null and roster_panel != null:
		roster_items.position = Vector2(12, 50)
		if show_deployment_rail:
			# Multi-line rows: default ItemList uses trim+ellipsis (one line); that hides Lv/class/weapon/stats.
			roster_items.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			roster_items.icon_mode = ItemList.ICON_MODE_TOP
			roster_items.max_text_lines = 4
			roster_items.fixed_icon_size = Vector2i(40, 40)
			roster_items.add_theme_font_size_override("font_size", 17)
			roster_items.add_theme_constant_override("line_separation", 2)
			roster_items.add_theme_constant_override("v_separation", 8)
		else:
			roster_items.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			roster_items.icon_mode = ItemList.ICON_MODE_LEFT
			roster_items.max_text_lines = 1
			roster_items.fixed_icon_size = Vector2i(40, 40)
			roster_items.add_theme_font_size_override("font_size", 19)
			roster_items.remove_theme_constant_override("line_separation")
			roster_items.remove_theme_constant_override("v_separation")
		if show_deployment_rail:
			var btn_top_r: float = roster_panel.size.y - 58.0
			var readout_top_r: float = btn_top_r - 8.0 - deploy_bond_block_h
			# Must not use min height larger than free space or the list draws over the bond panel.
			var list_h_r: float = readout_top_r - 50.0 - 8.0
			roster_items.size = Vector2(roster_panel.size.x - 24.0, maxf(40.0, list_h_r))
			roster_items.z_index = 0
		else:
		roster_items.size = Vector2(roster_panel.size.x - 24.0, max(180.0, roster_panel.size.y - 122.0))
	if build_button != null and roster_panel != null:
		build_button.position = Vector2(12, roster_panel.size.y - 58.0)
		build_button.size = Vector2(roster_panel.size.x - 24.0, 46.0)
		_style_tactical_button(build_button, build_button.text if build_button.text != "" else "BUILD DEFENSES", false, 20)
	# Nested under RosterPanel (CanvasLayer cannot lay out Control children reliably). PreBattleState toggles visibility.
	if deploy_bond_panel != null and roster_panel != null and roster_panel.visible and show_deployment_rail:
		if deploy_bond_block_h <= 0.01:
			deploy_bond_panel.visible = false
		else:
			deploy_bond_panel.visible = true
			deploy_bond_panel.scale = Vector2.ONE
			deploy_bond_panel.clip_contents = true
			deploy_bond_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
			deploy_bond_panel.anchor_right = 0.0
			deploy_bond_panel.anchor_bottom = 0.0
			var btn_top_b: float = roster_panel.size.y - 58.0
			var readout_top_b: float = btn_top_b - 8.0 - deploy_bond_block_h
			deploy_bond_panel.position = Vector2(12, readout_top_b)
			deploy_bond_panel.size = Vector2(roster_panel.size.x - 24.0, deploy_bond_block_h)
			deploy_bond_panel.z_index = 2
			# Opaquer than TACTICAL_UI_BG_SOFT so list text cannot show through when stacking.
			_style_tactical_panel(deploy_bond_panel, TACTICAL_UI_BG_ALT, TACTICAL_UI_BORDER_MUTED, 1, 8)
	var start_button := get_node_or_null("UI/StartBattleButton") as Button
	if start_button != null:
		start_button.z_index = 26
		start_button.scale = hud_scale_vec
		var start_button_y: float = vp_size.y - (78.0 * hud_scale) - TACTICAL_UI_BOTTOM_EDGE_MARGIN - (12.0 * hud_scale)
		start_button_y = maxf(110.0, start_button_y)
		# When the roster is hidden, sit lower than dead-center so the map reads clearer (~200px at 1:1 HUD scale).
		var start_button_mid_y: float = (vp_size.y - (78.0 * hud_scale)) * 0.5
		start_button_mid_y += 200.0 * hud_scale
		start_button_mid_y = minf(
			start_button_mid_y,
			vp_size.y - (78.0 * hud_scale) - TACTICAL_UI_BOTTOM_EDGE_MARGIN - (8.0 * hud_scale)
		)
		var start_button_x: float = ((vp_size.x - (460.0 * hud_scale)) * 0.5) + (24.0 * hud_scale)
		start_button.position = Vector2(start_button_x, start_button_y)
		start_button.size = Vector2(460.0, 78.0)
		start_button.visible = show_deployment_rail
		start_button.set_meta("deploy_start_expanded_y", start_button_y)
		start_button.set_meta("deploy_start_collapsed_y", start_button_mid_y)
		_style_tactical_button(start_button, start_button.text if start_button.text != "" else "START BATTLE", true, 42)


func _coop_remote_sync_prebattle_ready(body: Dictionary) -> void:
	CoopRemoteSyncActionHelpers.coop_remote_sync_prebattle_ready(self, body)


func _coop_remote_sync_player_move(body: Dictionary) -> void:
	await CoopRemoteSyncActionHelpers.coop_remote_sync_player_move(self, body)


func _coop_remote_sync_player_defend(body: Dictionary) -> void:
	CoopRemoteSyncActionHelpers.coop_remote_sync_player_defend(self, body)


func _coop_remote_sync_player_combat(body: Dictionary) -> void:
	await CoopRemoteSyncActionHelpers.coop_remote_sync_player_combat(self, body)


func _coop_remote_sync_player_post_combat(body: Dictionary) -> void:
	CoopRemoteSyncActionHelpers.coop_remote_sync_player_post_combat(self, body)


func _coop_remote_sync_player_finish_turn(body: Dictionary) -> void:
	CoopRemoteSyncActionHelpers.coop_remote_sync_player_finish_turn(self, body)


func _coop_remote_sync_player_phase_ready(body: Dictionary) -> void:
	CoopRemoteSyncActionHelpers.coop_remote_sync_player_phase_ready(self, body)


## Drops selection if active_unit somehow points at a partner-owned unit (mock co-op only). Skips while forecasting to avoid tearing an in-flight forecast await.
func _sanitize_player_phase_active_unit_for_mock_coop_ownership() -> void:
	TurnOrchestrationHelpers.sanitize_player_phase_active_unit_for_mock_coop_ownership(self)


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


## Player phase: true when at least one local-commandable player unit is fielded and alive, and every such unit has finished acting (is_exhausted).
func _local_player_fielded_commandable_units_all_exhausted() -> bool:
	return TurnOrchestrationHelpers.local_player_fielded_commandable_units_all_exhausted(self)


func _should_pulse_skip_button_end_turn_nudge() -> bool:
	return TurnOrchestrationHelpers.should_pulse_skip_button_end_turn_nudge(self)


func _mock_coop_set_local_prebattle_ready(send_sync: bool = true) -> void:
	CoopMockSessionHelpers._mock_coop_set_local_prebattle_ready(self, send_sync)


func _mock_coop_clear_local_prebattle_ready(send_sync: bool = true) -> void:
	CoopMockSessionHelpers._mock_coop_clear_local_prebattle_ready(self, send_sync)


func _mock_coop_player_phase_ready_sync_active() -> bool:
	return TurnOrchestrationHelpers.mock_coop_player_phase_ready_sync_active(self)


func _reset_mock_coop_player_phase_ready_state() -> void:
	TurnOrchestrationHelpers.reset_mock_coop_player_phase_ready_state(self)


func _mock_coop_try_advance_player_phase_after_ready_sync() -> void:
	TurnOrchestrationHelpers.mock_coop_try_advance_player_phase_after_ready_sync(self)


func _mock_coop_set_local_player_phase_ready(send_sync: bool = true) -> void:
	TurnOrchestrationHelpers.mock_coop_set_local_player_phase_ready(self, send_sync)


func _process_mock_partner_placeholder_frame() -> void:
	TurnOrchestrationHelpers.process_mock_partner_placeholder_frame(self)


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
	if partner_fielded > 0:
		var partner_state: String = "Ready" if _mock_coop_remote_player_phase_ready else "Acting"
		s += "\n[color=gold][b]Partner commander: %s[/b][/color]" % partner_state
	if _mock_coop_local_player_phase_ready:
		s += "\n[color=cyan][font_size=16]You have ended your phase for this turn.[/font_size][/color]"
		if partner_fielded > 0 and not _mock_coop_remote_player_phase_ready:
			s += "\n[color=gold][b]Waiting for your partner to proceed to enemy phase.[/b][/color]"
	elif ready == 0:
		s += "\n[color=gray][font_size=16]All your fielded units have acted this phase.[/font_size][/color]"
		if partner_fielded > 0:
			s += "\n[color=orange][font_size=16]Partner detachment still on the field — not under your command. End or Skip phase when you are ready.[/font_size][/color]"
	elif partner_fielded > 0 and _mock_coop_remote_player_phase_ready:
		s += "\n[color=gold][font_size=16]Partner is ready. Finish your commands when you are ready.[/font_size][/color]"
	return s + "\n"


func _update_skip_button_visual_modulate() -> void:
	var btn: Button = get_node_or_null("UI/SkipButton") as Button
	if btn == null or not btn.visible:
		return
	if not _skip_button_base_modulate_captured:
		_skip_button_base_modulate = btn.modulate
		_skip_button_base_modulate_captured = true
	var m: Color = _skip_button_base_modulate
	if is_mock_partner_placeholder_active():
		m *= Color(1.14, 1.12, 0.96, 1.0)
	var pulse_active: bool = _should_pulse_skip_button_end_turn_nudge()
	if pulse_active:
		var t: float = float(Time.get_ticks_msec()) * END_TURN_PULSE_TIME_SCALE
		var wave: float = 0.5 + 0.5 * sin(t)
		var wave_scale: float = 0.5 + 0.5 * sin(t * 1.19 + 0.85)
		var boost: float = 1.0 + END_TURN_PULSE_MOD_DEPTH * wave
		m *= Color(boost * 1.12, boost * 1.04, boost * 0.78, 1.0)
		var s: float = END_TURN_PULSE_SCALE_CENTER + END_TURN_PULSE_SCALE_DEPTH * (wave_scale - 0.5) * 2.0
		btn.pivot_offset = btn.size * 0.5
		btn.scale = Vector2(s, s)
	else:
		btn.scale = Vector2.ONE
		btn.pivot_offset = Vector2.ZERO
	btn.modulate = m


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
		var rid: String = _get_mock_coop_command_id(u)
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
var _tactical_ui_resize_hooked: bool = false

func _ready() -> void:
	if has_node("LevelMusic"):
		var level_music := get_node("LevelMusic") as AudioStreamPlayer
		if level_music != null:
			level_music.bus = "Music"
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
	if unit_details_button and not unit_details_button.pressed.is_connected(_on_unit_details_button_pressed):
		unit_details_button.pressed.connect(_on_unit_details_button_pressed)
	if close_support_btn: close_support_btn.pressed.connect(func(): support_tracker_panel.visible = false)
	if main_camera != null:
		_camera_zoom_target = main_camera.zoom.x
		
	_ensure_forecast_support_labels()
	_apply_inventory_panel_spacing()

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

	_consumed_mock_coop_battle_handoff = CampaignManager.consume_pending_mock_coop_battle_handoff()
	load_campaign_data()
	_init_path_preview_nodes()
	apply_campaign_settings()
	_seed_mock_coop_command_ids_for_live_battle_nodes()

	_mock_coop_battle_context = null
	_mock_coop_ownership_assignments.clear()
	_reset_mock_coop_prebattle_ready_state()
	_reset_mock_coop_player_phase_ready_state()
	var has_live_runtime_coop_phase: bool = (
			CoopExpeditionSessionManager.uses_runtime_network_coop_transport()
			and CoopExpeditionSessionManager.phase != CoopExpeditionSessionManager.Phase.NONE
	)
	if has_live_runtime_coop_phase:
		CoopExpeditionSessionManager.register_runtime_coop_battle_sync_target(self)
	if not _consumed_mock_coop_battle_handoff.is_empty():
		_mock_coop_battle_context = MockCoopBattleContext.from_consumed_handoff(_consumed_mock_coop_battle_handoff)
		if _mock_coop_battle_context != null:
			var ctx_line: String = _mock_coop_battle_context.get_debug_summary_line()
			print("[MockCoopBattleContext] %s snapshot=%s" % [ctx_line, str(_mock_coop_battle_context.get_snapshot())])
		print("[MockCoopHandoff] battle start keys=%s" % str(_consumed_mock_coop_battle_handoff.keys()))
		_present_mock_coop_joint_expedition_charter()
		_assign_mock_coop_unit_ownership_from_context()
		if is_mock_coop_unit_ownership_active() and has_live_runtime_coop_phase:
			CoopExpeditionSessionManager.try_publish_runtime_coop_battle_rng_seed()
	elif has_live_runtime_coop_phase and OS.is_debug_build():
		push_warning("BattleField: network co-op battle loaded without a pending mock handoff; battle sync is registered, but ownership is inactive.")
	if has_live_runtime_coop_phase and not is_mock_coop_unit_ownership_active() and OS.is_debug_build():
		push_warning("BattleField: network co-op battle has no active mock ownership assignment; local player moves will not mirror until the handoff/ownership path is valid.")
	
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
			# Defer victory handling to the ally-phase flow so co-op can sync the escort turn first.
			vip_target.reached_destination.connect(func(): 
				if has_method("add_combat_log"):
					add_combat_log("MISSION ACCOMPLISHED: The convoy escaped!", "lime")
				if _battle_resonance_allowed():
					CampaignManager.mark_battle_resonance("protected_civilians_first")
				_coop_pending_escort_destination_victory = true
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
	_queue_tactical_ui_overhaul()
	update_fog_of_war()
	
	# 10. START GAME
	$UI/StartBattleButton.pressed.connect(_on_start_battle_pressed)
	
	# Wait a fraction of a second so the map renders, then start the Cinematic!
	get_tree().create_timer(0.6).timeout.connect(_start_intro_sequence)
	
func _process(delta: float) -> void:
	TurnOrchestrationHelpers.process(self, delta)

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
	await TurnOrchestrationHelpers.change_state(self, new_state)
				
func _process_spawners(faction_id: int) -> void:
	await TurnOrchestrationHelpers.process_spawners(self, faction_id)
						
func _on_skip_button_pressed() -> void:
	TurnOrchestrationHelpers.on_skip_button_pressed(self)
			
func _on_ally_turn_finished() -> void:
	TurnOrchestrationHelpers.on_ally_turn_finished(self)

func _on_enemy_turn_finished() -> void:
	await TurnOrchestrationHelpers.on_enemy_turn_finished(self)


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
	if _coop_remote_combat_replay_active:
		update_fog_of_war()
		update_objective_ui()
		return
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
		var local_loot_recipient: Node2D = null
		if killer != null and is_instance_valid(killer):
			var killer_parent: Node = killer.get_parent()
			if killer_parent == player_container or (ally_container != null and killer_parent == ally_container):
				local_loot_recipient = killer
		if local_loot_recipient == null and player_state != null:
			local_loot_recipient = player_state.active_unit
		_coop_capture_enemy_death_loot_for_sync(unit, total_gold, pending_loot, local_loot_recipient)
		if not pending_loot.is_empty():
			loot_recipient = local_loot_recipient
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
				if _defer_battle_result_until_loot_if_needed("VICTORY"):
					pass
				else:
					_trigger_victory()
					
		Objective.DEFEND_TARGET:
			if unit == vip_target:
				add_combat_log("MISSION FAILED: VIP Target was killed.", "red")
				if _defer_battle_result_until_loot_if_needed("DEFEAT"):
					pass
				else:
					trigger_game_over("DEFEAT")
	
	
	update_fog_of_war()
	update_objective_ui()
		
func trigger_game_over(result: String) -> void:
	var normalized_result: String = _coop_normalize_battle_result(result)
	if normalized_result == "":
		normalized_result = str(result).strip_edges()
	if _coop_finalized_battle_result != "":
		return
	if not _coop_remote_battle_result_applying and normalized_result != "VICTORY":
		if coop_enet_should_wait_for_host_authoritative_battle_result():
			_coop_wait_for_host_authoritative_battle_result(normalized_result)
			return
		if _defer_battle_result_until_loot_if_needed(normalized_result):
			return
		coop_enet_sync_after_host_authoritative_battle_result(normalized_result)
	elif _defer_battle_result_until_loot_if_needed(normalized_result):
		return
	_coop_waiting_for_host_battle_result = ""
	_coop_battle_result_resolution_in_progress = normalized_result
	_coop_finalized_battle_result = normalized_result

	change_state(null)
	if CampaignManager and not is_arena_match and not CampaignManager.is_skirmish_mode:
		CampaignManager.record_story_battle_outcome_for_camp(normalized_result, player_deaths_count, ally_deaths_count)

	# 1. THE PAUSE FIX: Force the game to freeze, but keep the UI panel awake
	get_tree().paused = true
	game_over_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# ==========================================
	# --- NEW: ARENA MMR, STREAKS & TOKENS ---
	# ==========================================
	if is_arena_match and ArenaManager.current_opponent_data.size() > 0:
		var opp_mmr: int = ArenaManager.sanitize_leaderboard_score_mmr(ArenaManager.current_opponent_data.get("score", 1000))
		var my_mmr: int = ArenaManager.get_local_mmr()
		var mmr_change: int = 0
		
		# Save old state for the animated sequence in the city
		ArenaManager.last_match_old_mmr = my_mmr

		if normalized_result == "VICTORY":
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
		ArenaManager.last_match_new_mmr = ArenaManager.get_local_mmr()
	# ==========================================
	
	result_label.text = normalized_result
	var coop_defeat_return_to_charter: bool = (
		normalized_result != "VICTORY"
		and CoopExpeditionSessionManager.uses_runtime_network_coop_transport()
		and CoopExpeditionSessionManager.phase != CoopExpeditionSessionManager.Phase.NONE
	)
	if normalized_result == "VICTORY":
		result_label.modulate = Color(0.2, 0.8, 0.2)
		continue_button.visible = true
		restart_button.visible = false
		if is_arena_match:
			continue_button.text = "Return to City"
		else:
			continue_button.text = "Continue"
	else:
		result_label.modulate = Color(0.8, 0.2, 0.2)
		continue_button.visible = coop_defeat_return_to_charter
		restart_button.visible = not coop_defeat_return_to_charter
		if coop_defeat_return_to_charter:
			continue_button.text = "Return to Charter"
		elif is_arena_match:
			restart_button.text = "Leave Arena"
		
	# ==========================================
	# --- FAME & SCORE CALCULATION ---
	# ==========================================
	var base_clear = 500 if normalized_result == "VICTORY" else 0
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
	if CoopExpeditionSessionManager.uses_runtime_network_coop_transport() and CoopExpeditionSessionManager.phase != CoopExpeditionSessionManager.Phase.NONE:
		if battle_log != null and battle_log.visible:
			add_combat_log("Co-op: restart is disabled after defeat. Return to the charter to regroup.", "gold")
		return
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
	PathCursorHelpers.update_cursor_pos(self)

func update_cursor_color() -> void:
	PathCursorHelpers.update_cursor_color(self)


func _update_locked_inspect_cursor() -> void:
	PathCursorHelpers.update_locked_inspect_cursor(self)


func _get_inspect_cursor_tint(unit: Node2D) -> Color:
	return PathCursorHelpers.get_inspect_cursor_tint(self, unit)


func _set_cursor_state(cursor_node: Node, state_name: String) -> void:
	PathCursorHelpers.set_cursor_state(self, cursor_node, state_name)


func _apply_cursor_accessibility_settings() -> void:
	PathCursorHelpers.apply_cursor_accessibility_settings(self)


func _is_neutral_inspect_unit(unit: Node2D) -> bool:
	return PathCursorHelpers.is_neutral_inspect_unit(self, unit)

func draw_preview_path() -> void:
	PathCursorHelpers.draw_preview_path(self)


func get_path_preview_tick_positions_for_draw() -> Array[Vector2]:
	return PathCursorHelpers.get_path_preview_tick_positions_for_draw(self)


func _init_path_preview_nodes() -> void:
	for ln in [path_line_under, path_line]:
		if ln == null:
			continue
		ln.z_as_relative = false
		ln.joint_mode = Line2D.LINE_JOINT_ROUND
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.end_cap_mode = Line2D.LINE_CAP_ROUND
		ln.antialiased = true
	if path_line_under != null:
		path_line_under.z_index = PATH_PREVIEW_Z
		path_line_under.width = PATH_PREVIEW_UNDER_WIDTH
	if path_line != null:
		path_line.z_index = PATH_PREVIEW_Z + 1
		path_line.width = PATH_PREVIEW_FG_WIDTH
	if path_preview_ticks != null:
		path_preview_ticks.z_as_relative = false
		path_preview_ticks.z_index = PATH_PREVIEW_Z + 3
	if path_end_marker != null:
		path_end_marker.z_as_relative = false
		path_end_marker.z_index = PATH_PREVIEW_Z + 2
		var diamond: Polygon2D = path_end_marker.get_node_or_null("Diamond") as Polygon2D
		if diamond == null:
			for c in path_end_marker.get_children():
				if c is Polygon2D:
					diamond = c as Polygon2D
					break
		if diamond != null:
			diamond.polygon = PackedVector2Array([Vector2(0, -9), Vector2(11, 0), Vector2(0, 9), Vector2(-11, 0)])


func _hide_path_preview_visuals() -> void:
	_path_preview_tick_world.clear()
	_set_path_pulse(false)
	if path_line_under != null:
		path_line_under.clear_points()
		path_line_under.visible = false
	if path_line != null:
		path_line.clear_points()
		path_line.visible = false
		path_line.material = null
	if path_preview_ticks != null:
		path_preview_ticks.queue_redraw()
	if path_end_marker != null:
		path_end_marker.visible = false


func _cell_center_world(cell: Vector2i) -> Vector2:
	return Vector2(
		float(cell.x * CELL_SIZE.x) + float(CELL_SIZE.x) * 0.5,
		float(cell.y * CELL_SIZE.y) + float(CELL_SIZE.y) * 0.5
	)


func _single_step_enter_cost(unit: Node2D, cell: Vector2i) -> float:
	if unit == null:
		return 1.0
	if unit.get("move_type") == 2:
		return 1.0
	var base_cost: float = astar.get_point_weight_scale(cell)
	if unit.get("move_type") == 1 and base_cost > 1.0:
		base_cost += 1.0
	return base_cost


func _chamfer_world_polyline(pts: PackedVector2Array, inset: float) -> PackedVector2Array:
	if pts.size() < 3 or inset <= 0.0:
		return pts
	var out: PackedVector2Array = PackedVector2Array()
	out.append(pts[0])
	for i in range(1, pts.size() - 1):
		var prev: Vector2 = pts[i - 1]
		var curr: Vector2 = pts[i]
		var next: Vector2 = pts[i + 1]
		var v1: Vector2 = curr - prev
		var v2: Vector2 = next - curr
		var len1: float = v1.length()
		var len2: float = v2.length()
		if len1 < 0.001 or len2 < 0.001:
			out.append(curr)
			continue
		v1 /= len1
		v2 /= len2
		if absf(v1.dot(v2)) > 0.995:
			out.append(curr)
			continue
		var r: float = minf(inset, minf(len1 * 0.48, len2 * 0.48))
		out.append(curr - v1 * r)
		out.append(curr + v2 * r)
	out.append(pts[pts.size() - 1])
	return out


func _grid_path_to_world_polyline(path: Array, unit: Node2D) -> PackedVector2Array:
	var raw: PackedVector2Array = PackedVector2Array()
	for i in range(path.size()):
		raw.append(_cell_center_world(path[i] as Vector2i))
	var smooth_level: int = CampaignManager.battle_path_corner_smoothing
	var inset: float = 0.0
	if smooth_level == 1:
		inset = PATH_PREVIEW_CORNER_INSET_LOW * (float(CELL_SIZE.x) / 64.0)
	elif smooth_level >= 2:
		inset = PATH_PREVIEW_CORNER_INSET_HIGH * (float(CELL_SIZE.x) / 64.0)
	return _chamfer_world_polyline(raw, inset)


func _gather_path_cost_ticks(path: Array, unit: Node2D) -> void:
	_path_preview_tick_world.clear()
	if not CampaignManager.battle_path_cost_ticks or path.size() < 2:
		return
	var cum: float = 0.0
	var next_tick_threshold: int = 1
	for i in range(1, path.size()):
		var cell: Vector2i = path[i] as Vector2i
		var prev_cell: Vector2i = path[i - 1] as Vector2i
		var step_cost: float = _single_step_enter_cost(unit, cell)
		var prev_cum: float = cum
		cum += step_cost
		var p0: Vector2 = _cell_center_world(prev_cell)
		var p1: Vector2 = _cell_center_world(cell)
		while float(next_tick_threshold) <= cum + 0.001:
			var denom: float = cum - prev_cum
			var t: float = 1.0 if denom <= 0.0001 else clampf((float(next_tick_threshold) - prev_cum) / denom, 0.0, 1.0)
			_path_preview_tick_world.append(p0.lerp(p1, t))
			next_tick_threshold += 1


func _ensure_path_fg_dash_material() -> ShaderMaterial:
	if _path_fg_dash_material == null:
		_path_fg_dash_material = ShaderMaterial.new()
		_path_fg_dash_material.shader = PATH_PREVIEW_DASH_SHADER
	return _path_fg_dash_material


func _apply_path_preview_style(ghost: bool, canto: bool) -> void:
	var style: int = CampaignManager.battle_path_style
	var minimal: bool = style == CampaignManager.BATTLE_PATH_STYLE_MINIMAL
	var dashed: bool = style == CampaignManager.BATTLE_PATH_STYLE_DASHED

	var fg := Color(0.82, 0.96, 1.0, 1.0)
	var under := Color(0.03, 0.05, 0.12, 0.92)
	var scroll_mult: float = 1.0
	if canto:
		fg = Color(1.0, 0.92, 0.55, 1.0)
		under = Color(0.14, 0.09, 0.02, 0.9)
		scroll_mult = 1.45
	if ghost:
		fg = Color(1.0, 0.45, 0.42, 0.55)
		under = Color(0.22, 0.04, 0.04, 0.6)
		scroll_mult = 1.65

	if path_line_under != null:
		path_line_under.default_color = under
		path_line_under.width = PATH_PREVIEW_UNDER_WIDTH
	if path_line == null:
		return

	if minimal:
		path_line.width = maxf(PATH_PREVIEW_FG_WIDTH, 5.5)
	else:
		path_line.width = PATH_PREVIEW_FG_WIDTH

	if dashed and not minimal:
		path_line.default_color = Color.WHITE
		var smat: ShaderMaterial = _ensure_path_fg_dash_material()
		smat.set_shader_parameter("line_color", fg)
		smat.set_shader_parameter("scroll_speed", 1.15 * scroll_mult)
		smat.set_shader_parameter("dash_repeat", 12.0 * (1.1 if canto else 1.0))
		path_line.material = smat
	else:
		path_line.material = null
		path_line.default_color = fg


func _update_path_endpoint_marker(path: Array, ghost: bool, canto: bool) -> void:
	if path_end_marker == null:
		return
	if not CampaignManager.battle_path_endpoint_marker:
		path_end_marker.visible = false
		return
	var diamond: Polygon2D = path_end_marker.get_node_or_null("Diamond") as Polygon2D
	if diamond == null:
		for c in path_end_marker.get_children():
			if c is Polygon2D:
				diamond = c as Polygon2D
				break
	path_end_marker.visible = true
	path_end_marker.position = _cell_center_world(path[path.size() - 1] as Vector2i)
	var col := Color(0.9, 0.98, 1.0, 0.92)
	if canto:
		col = Color(1.0, 0.95, 0.55, 0.95)
	if ghost:
		col = Color(1.0, 0.5, 0.48, 0.65)
	if diamond != null:
		diamond.color = col

func _draw() -> void:
	if current_state == pre_battle_state:
		var pbs: PreBattleState = pre_battle_state
		DrawHelpers.draw_pre_battle_deployment_overlay_and_snap(self, pbs)

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

	var action_color = Color(0.8, 0.2, 0.2, 0.5)
	if current_state == player_state and player_state.active_unit != null:
		var wpn = player_state.active_unit.equipped_weapon
		if wpn != null and (wpn.get("is_healing_staff") == true or wpn.get("is_buff_staff") == true):
			action_color = Color(0.2, 0.8, 0.2, 0.5)

	DrawHelpers.draw_danger_reachable_attackable(self, action_color)

	if CampaignManager.battle_show_grid:
		var c = Color(1, 1, 1, 0.3)
		for x in range(GRID_SIZE.x + 1):
			draw_line(Vector2(x * CELL_SIZE.x, 0), Vector2(x * CELL_SIZE.x, GRID_SIZE.y * CELL_SIZE.y), c)
		for y in range(GRID_SIZE.y + 1):
			draw_line(Vector2(0, y * CELL_SIZE.y), Vector2(GRID_SIZE.x * CELL_SIZE.x, y * CELL_SIZE.y), c)

	DrawHelpers.draw_enemy_threat(self)
	DrawHelpers.draw_reinforcement_telegraph_overlays(self)

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

	var locked_inspect_unit: Node2D = _get_locked_inspect_unit()
	var hovered_occupant: Node2D = get_occupant_at(cursor_grid_pos)
	if locked_inspect_unit != null:
		target_unit = locked_inspect_unit
	elif hovered_occupant != null:
		target_unit = hovered_occupant
	elif current_state == player_state and player_state.active_unit != null:
		target_unit = player_state.active_unit

	var terrain = get_terrain_data(cursor_grid_pos)
	var terrain_bb = "\n[color=yellow]%s[/color] [color=gray]|[/color] [color=cyan]DEF +%d[/color] [color=gray]|[/color] [color=chartreuse]AVO +%d%%[/color]" % [terrain["name"], terrain["def"], terrain["avo"]]

	if target_unit == null:
		_unit_info_stat_source_id = -1
		_set_unit_info_primary_widgets_visible(false)
		_set_unit_info_stat_widgets_visible(false)
		unit_name_label.text = "Map Tile"
		unit_hp_label.text = ""
		unit_stats_label.position = Vector2(16, 80)
		unit_stats_label.size = Vector2(194, 84)
		_style_tactical_richtext(unit_stats_label, 16, 18)
		unit_stats_label.text = "[center]TERRAIN INFO" + terrain_bb + "[/center]"
		_set_unit_portrait_block_visible(false)
		open_inv_button.visible = false
		if support_btn: support_btn.visible = false
		if unit_details_button: unit_details_button.visible = false
		unit_info_panel.visible = true
		return
		
	if target_unit.get("data") != null:
		var unit_info_source_id: int = target_unit.get_instance_id()
		var animate_stat_bars: bool = unit_info_source_id != _unit_info_stat_source_id
		var current_xp = target_unit.experience
		var required_xp = target_unit.get_exp_required() if target_unit.has_method("get_exp_required") else 100
		var status_line: String = ""
		
		var active_tag: String = ""
		if current_state == player_state and player_state.active_unit == target_unit:
			if target_unit.is_exhausted:
				active_tag = " [Turn done]"
			elif target_unit.has_moved:
				active_tag = " [Moved — act]"
			else:
				active_tag = " [ACTIVE]"
		if current_state == player_state and player_state.active_unit == target_unit:
			if target_unit.is_exhausted:
				status_line = "[color=gold]Turn Done[/color]\n"
			elif target_unit.has_moved:
				status_line = "[color=gold]Moved - Action Ready[/color]\n"
			else:
				status_line = "[color=cyan]Selected Unit[/color]\n"
		unit_name_label.text = String(target_unit.unit_name).to_upper()

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

		var current_poise: int = 0
		var max_poise: int = 1
		var u_poise = "--"
		if target_unit.has_method("get_current_poise"):
			current_poise = int(target_unit.get_current_poise())
			max_poise = max(1, int(target_unit.get_max_poise()))
			u_poise = str(current_poise) + "/" + str(max_poise)

		unit_hp_label.text = "LV %d  |  MOVE %d" % [
			int(target_unit.level),
			int(u_move),
		]

		unit_stats_label.position = Vector2(16, 142)
		unit_stats_label.size = Vector2(210, 24)
		_style_tactical_richtext(unit_stats_label, 11, 12)

		var meta_lines: PackedStringArray = PackedStringArray()
		var coop_own_line: String = _mock_coop_unit_ownership_bbcode_line_for_panel(target_unit).strip_edges()
		if status_line != "":
			meta_lines.append(status_line.strip_edges())
		elif coop_own_line != "":
			meta_lines.append(coop_own_line)
		meta_lines.append("[color=gray]CLASS:[/color] %s" % [String(u_class).to_upper()])
		var detail_parts: PackedStringArray = PackedStringArray()
		if target_unit.has_meta("is_burning") and target_unit.get_meta("is_burning") == true:
			detail_parts.append("[color=orangered][b]BURNING[/b][/color]")
		elif target_unit.equipped_weapon != null:
			detail_parts.append("[color=yellow]%s[/color]" % _truncate_forecast_text(String(target_unit.equipped_weapon.weapon_name).to_upper(), 12))
		if detail_parts.size() > 0:
			meta_lines.append(" [color=gray]|[/color] ".join(detail_parts))
		unit_stats_label.text = "[center]" + "\n".join(meta_lines) + "[/center]"
		_refresh_unit_info_primary_widgets({
			"hp": {
				"current": int(target_unit.current_hp),
				"max": max(1, int(target_unit.max_hp)),
				"text": "%d/%d" % [int(target_unit.current_hp), int(target_unit.max_hp)],
			},
			"poise": {
				"current": current_poise,
				"max": max_poise,
				"text": u_poise,
			},
			"xp": {
				"current": int(current_xp),
				"max": max(1, int(required_xp)),
				"text": "%d/%d" % [int(current_xp), int(required_xp)],
			},
		}, animate_stat_bars, unit_info_source_id)
		_refresh_unit_info_stat_widgets({
			"strength": u_str,
			"magic": u_mag,
			"defense": display_def,
			"resistance": display_res,
			"speed": u_spd,
			"agility": u_agi,
		}, animate_stat_bars, unit_info_source_id)
		_unit_info_stat_source_id = unit_info_source_id

		if target_unit.data != null and target_unit.data.get("portrait") != null:
			unit_portrait.texture = target_unit.data.portrait
			_set_unit_portrait_block_visible(true)
		else:
			_set_unit_portrait_block_visible(false)
		
		var is_friendly = (target_unit.get_parent() == player_container or target_unit.get_parent() == ally_container)
		open_inv_button.visible = (target_unit.get_parent() == player_container)
		if support_btn: support_btn.visible = is_friendly
		if unit_details_button: unit_details_button.visible = true
		unit_info_panel.visible = true
	else:
		_unit_info_stat_source_id = -1
		_set_unit_info_primary_widgets_visible(false)
		_set_unit_info_stat_widgets_visible(false)
		if unit_details_button: unit_details_button.visible = false
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
	return await CombatForecastHelpers.show_combat_forecast(self, attacker, defender)
	
func _on_forecast_confirm() -> void:
	emit_signal("forecast_resolved", "confirm", false)

func _on_forecast_cancel() -> void:
	emit_signal("forecast_resolved", "cancel", false)

func _on_forecast_talk() -> void:
	emit_signal("forecast_resolved", "talk", false)
	
func _on_forecast_ability_pressed() -> void:
	emit_signal("forecast_resolved", "confirm", true) # Returns confirm, but flags the ability!
	
func execute_combat(attacker: Node2D, defender: Node2D, trigger_active_ability: bool = false) -> void:
	await CombatOrchestrationHelpers.execute_combat(self, attacker, defender, trigger_active_ability)

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
	await StrikeSequenceHelpers.run_strike_sequence(self, attacker, defender, force_active_ability, force_single_attack)
								
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
	if convoy_grid == null or inv_scroll == null:
		return
		
	unit_managing_inventory = null
	player_state.is_forecasting = true 
	
	_populate_convoy_list()
	
	equip_button.visible = false
	use_button.visible = false
	inventory_panel.visible = true

func _on_open_inv_pressed() -> void:
	if current_state != player_state or player_state.active_unit == null: return
	if unit_grid == null:
		return
		
	unit_managing_inventory = player_state.active_unit
	player_state.is_forecasting = true 
	
	_populate_unit_inventory_list()
	
	equip_button.visible = true
	use_button.visible = true
	inventory_panel.visible = true

func _populate_convoy_list() -> void:
	TradeInventoryHelpers.populate_convoy_list(self)

func _populate_unit_inventory_list() -> void:
	InventoryUiHelpers.populate_unit_inventory_list(self)

func _clear_grids() -> void:
	TradeInventoryHelpers.clear_grids(self)

func _build_grid_items(grid: GridContainer, item_array: Array, source_type: String, owner_unit: Node2D = null, min_slots: int = 0) -> void:
	TradeInventoryHelpers.build_grid_items(self, grid, item_array, source_type, owner_unit, min_slots)
							
func _on_grid_item_clicked(btn: Button, meta: Dictionary) -> void:
	if select_sound and select_sound.stream != null:
		select_sound.pitch_scale = 1.2
		select_sound.play()
		
	selected_inventory_meta = meta
	
	var grid_children: Array[Node] = []
	if unit_grid != null:
		grid_children.append_array(unit_grid.get_children())
	if convoy_grid != null:
		grid_children.append_array(convoy_grid.get_children())
	for child in grid_children:
		child.modulate = Color.WHITE
	btn.modulate = Color(1.5, 1.5, 1.5)
	
	var item = meta["item"]
	var count = meta.get("count", 1)
	var viewer_unit = meta.get("unit", null)
	if inv_desc_label != null:
		inv_desc_label.text = _get_item_detailed_info(item, count, viewer_unit)
		_queue_refit_item_description_panels()
	
	equip_button.disabled = false
	use_button.disabled = false
	
func _on_equip_pressed() -> void:
	InventoryActionHelpers.on_equip_pressed(self)

func _on_close_inv_pressed() -> void:
	inventory_panel.visible = false
	if current_state == player_state:
		player_state.is_forecasting = false
	unit_managing_inventory = null

func _on_use_pressed() -> void:
	await InventoryActionHelpers.on_use_pressed(self)

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

func _bbcode_escape_user_text(s: String) -> String:
	return str(s).replace("[", "[lb]")

func _item_detail_soft_rule() -> String:
	return "[color=#5c4f41] · · · · · · · · · · · · · · · ·[/color]"

func _item_detail_section_heading(title: String) -> String:
	return "[font_size=20][color=#c4943a]▍ [/color][b][color=#f2d680]" + str(title).to_upper() + "[/color][/b][/font_size]"

func _item_detail_callout(accent_hex: String, body_hex: String, escaped_msg: String) -> String:
	return "[font_size=19][color=%s]▸ [/color][color=%s]%s[/color][/font_size]" % [accent_hex, body_hex, escaped_msg]

func _item_detail_line(lbl: String, value_bb: String) -> String:
	return "[font_size=19][color=#c4bba8][b]" + lbl + "[/b][/color][color=#5a5248]   [/color]" + value_bb + "[/font_size]"

func _item_detail_effect_row(body_color: String, escaped_inner: String) -> String:
	return "[font_size=19]   [color=#e0b858]◆[/color][color=#5a5248]   [/color][color=%s]%s[/color][/font_size]" % [body_color, escaped_inner]


func _weapon_compare_delta_fragments_bbcode(sel: WeaponData, equipped: WeaponData) -> PackedStringArray:
	var out: PackedStringArray = []
	if sel.damage_type != equipped.damage_type:
		return out
	const C_UP: String = "#a8e8b8"
	const C_DN: String = "#ffa898"
	var md: int = int(sel.might) - int(equipped.might)
	var hd: int = int(sel.hit_bonus) - int(equipped.hit_bonus)
	if md != 0:
		var c: String = C_UP if md > 0 else C_DN
		out.append("[color=%s][b]%s Might[/b][/color]" % [c, "%+d" % md])
	if hd != 0:
		var c2: String = C_UP if hd > 0 else C_DN
		out.append("[color=%s][b]%s Hit[/b][/color]" % [c2, "%+d" % hd])
	return out


func _weapon_stat_compare_line_bbcode(sel: WeaponData, equipped: WeaponData) -> String:
	var frags: PackedStringArray = _weapon_compare_delta_fragments_bbcode(sel, equipped)
	if frags.is_empty():
		return ""
	var sep: String = "[color=#5a5248] · [/color]"
	return (
		"[font_size=19][color=#b8a890]vs equipped[/color]%s%s[/font_size]"
		% [sep, sep.join(frags)]
	)


func _add_equipped_badge_to_inv_button(btn: Button) -> void:
	if btn == null:
		return
	if btn.get_node_or_null("EquippedBadge") != null:
		return
	var badge := Label.new()
	badge.name = "EquippedBadge"
	badge.text = "E"
	badge.add_theme_font_size_override("font_size", 15)
	badge.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	badge.add_theme_constant_override("outline_size", 4)
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(badge)
	badge.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	badge.offset_left = 4
	badge.offset_bottom = -2
	badge.grow_horizontal = Control.GROW_DIRECTION_END


func _play_inv_slot_flash(btn: Button) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	var peak: Vector2 = Vector2(1.11, 1.11)
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", peak, 0.085)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.11)
	var base_col: Color = Color.WHITE
	if btn is Control and btn.has_meta("hover_base_modulate"):
		base_col = btn.get_meta("hover_base_modulate") as Color
	var tw2 := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(btn, "modulate", base_col * Color(1.32, 1.22, 1.05), 0.07)
	tw2.tween_property(btn, "modulate", base_col, 0.13)


func _battle_try_flash_pending_inv_slot(grid: GridContainer) -> void:
	if _battle_inv_flash_item == null or grid == null:
		return
	var want: Resource = _battle_inv_flash_item
	_battle_inv_flash_item = null
	for c in grid.get_children():
		if c is Button and (c as Button).has_meta("inv_data"):
			var d: Dictionary = (c as Button).get_meta("inv_data") as Dictionary
			if d.get("item") == want:
				_play_inv_slot_flash(c as Button)
				return

func _get_item_detailed_info(item: Resource, stack_count: int = 1, viewer_unit: Node2D = null) -> String:
	var lines: PackedStringArray = []
	const C_MUTED: String = "#c4bba8"
	const C_BODY: String = "#faf6eb"
	const C_DIM: String = "#8a8274"
	const C_VALUE: String = "#f0d78c"
	const C_OK: String = "#a8e8b8"
	const C_BAD: String = "#ffa898"
	const C_STAT: String = "#ffd4b8"

	var rarity: String = item.get("rarity") if item.get("rarity") != null else "Common"
	var cost: int = item.get("gold_cost") if item.get("gold_cost") != null else 0

	var rarity_hex: String = "#f2ede0"
	match rarity:
		"Uncommon":
			rarity_hex = "#8ae89e"
		"Rare":
			rarity_hex = "#8ed4ff"
		"Epic":
			rarity_hex = "#d4a8ff"
		"Legendary":
			rarity_hex = "#ffe090"

	lines.append("[font_size=28][b][color=%s]%s[/color][/b][/font_size]" % [rarity_hex, str(rarity).to_upper()])
	var meta: String = (
		"[font_size=20][color=#d4a85c]⬥ [/color][color=%s]Value[/color][color=#5a5248]   [/color][color=%s][b]%d[/b][/color][color=%s]g[/color]"
		% [C_MUTED, C_VALUE, cost, C_DIM]
	)
	if stack_count > 1:
		meta += "[color=#5a5248]        [/color][color=#b89858]⬧ [/color][color=%s]Stack[/color][color=#5a5248]   [/color][color=%s][b]×%d[/b][/color]" % [C_MUTED, C_BODY, stack_count]
	meta += "[/font_size]"
	lines.append(meta)
	lines.append(_item_detail_soft_rule())
	lines.append("")

	if item is WeaponData:
		if item.get("current_durability") != null and item.current_durability <= 0:
			lines.append("[font_size=20][b][color=%s]Broken — half effectiveness. Repair to restore full power.[/color][/b][/font_size]" % C_BAD)
			lines.append("")

		lines.append(_item_detail_section_heading("Combat stats"))
		lines.append("")

		var w_type_str: String = "Unknown"
		if item.get("weapon_type") != null:
			w_type_str = _weapon_type_name_safe(int(item.weapon_type))
		var d_type_str: String = "Physical" if item.get("damage_type") != null and item.damage_type == 0 else "Magical"

		lines.append(
			_item_detail_line(
				"Weapon",
				"[color=%s]%s[/color][color=%s]   ·   [/color][color=%s]%s[/color]"
				% [C_BODY, w_type_str, C_DIM, C_DIM, d_type_str]
			)
		)
		lines.append(
			_item_detail_line("Might", "[color=%s]%d[/color]" % [C_STAT, int(item.might)])
		)
		lines.append(
			_item_detail_line("Hit", "[color=%s]+%d[/color]" % [C_VALUE, int(item.hit_bonus)])
		)
		lines.append(
			_item_detail_line(
				"Range",
				"[color=%s]%d[/color][color=%s]–[/color][color=%s]%d[/color]"
				% [C_BODY, int(item.min_range), C_DIM, C_BODY, int(item.max_range)]
			)
		)

		if item.get("current_durability") != null:
			lines.append(
				_item_detail_line(
					"Durability",
					"[color=%s]%d[/color][color=%s] / [/color][color=%s]%d[/color]"
					% [C_BODY, int(item.current_durability), C_DIM, C_BODY, int(item.max_durability)]
				)
			)

		var eq_weapon: Resource = viewer_unit.get("equipped_weapon") if viewer_unit != null else null
		if (
				eq_weapon != null
				and eq_weapon is WeaponData
				and item != eq_weapon
		):
			var cmp_line: String = _weapon_stat_compare_line_bbcode(item as WeaponData, eq_weapon as WeaponData)
			if cmp_line != "":
				lines.append("")
				lines.append(cmp_line)

		if viewer_unit != null:
			lines.append("")
			var usable: bool = _unit_can_use_item_for_ui(viewer_unit, item)
			if usable:
				lines.append("[font_size=20][color=%s][b]Equippable[/b][/color][color=#5a5248] — [/color][color=%s]This unit can use this weapon.[/color][/font_size]" % [C_OK, C_BODY])
			else:
				lines.append("[font_size=20][color=%s][b]Locked[/b][/color][color=#5a5248] — [/color][color=%s]This unit cannot equip this weapon.[/color][/font_size]" % [C_BAD, C_MUTED])

		var effects: Array = []
		if item.get("is_healing_staff") == true:
			effects.append("Restores %d HP" % int(item.effect_amount))

		if item.get("is_buff_staff") == true or item.get("is_debuff_staff") == true:
			var word: String = "Grants +" if item.get("is_buff_staff") == true else "Inflicts -"
			if item.get("affected_stat") != null and str(item.affected_stat) != "":
				var stats: PackedStringArray = str(item.affected_stat).split(",")
				var formatted_stats: PackedStringArray = []
				for s in stats:
					formatted_stats.append(s.strip_edges().capitalize())
				effects.append(word + str(item.effect_amount) + " to " + ", ".join(formatted_stats))

		if effects.size() > 0:
			lines.append("")
			lines.append(_item_detail_section_heading("Effects"))
			lines.append("")
			for e in effects:
				lines.append(_item_detail_effect_row(C_BODY, _bbcode_escape_user_text(str(e))))

	elif item is ConsumableData:
		lines.append(_item_detail_section_heading("Overview"))
		lines.append(_item_detail_line("Kind", "[color=%s]Consumable[/color]" % C_BODY))

		var effects: Array = []
		if item.heal_amount > 0:
			effects.append("Restores %d HP" % int(item.heal_amount))

		var boosts: PackedStringArray = []
		if item.hp_boost > 0:
			boosts.append("+%d HP" % int(item.hp_boost))
		if item.str_boost > 0:
			boosts.append("+%d STR" % int(item.str_boost))
		if item.mag_boost > 0:
			boosts.append("+%d MAG" % int(item.mag_boost))
		if item.def_boost > 0:
			boosts.append("+%d DEF" % int(item.def_boost))
		if item.res_boost > 0:
			boosts.append("+%d RES" % int(item.res_boost))
		if item.spd_boost > 0:
			boosts.append("+%d SPD" % int(item.spd_boost))
		if item.agi_boost > 0:
			boosts.append("+%d AGI" % int(item.agi_boost))

		if boosts.size() > 0:
			effects.append("Permanent stat boost: " + ", ".join(boosts))

		if effects.size() > 0:
			lines.append("")
			lines.append(_item_detail_section_heading("Effects"))
			lines.append("")
			for e in effects:
				lines.append(_item_detail_effect_row(C_BODY, _bbcode_escape_user_text(str(e))))

	elif item is MaterialData:
		lines.append(_item_detail_section_heading("Overview"))
		lines.append(_item_detail_line("Kind", "[color=%s]Crafting material[/color]" % C_BODY))
	else:
		lines.append(_item_detail_section_heading("Overview"))
		lines.append(
			_item_detail_callout(
				"#a89878",
				"#e8dfd4",
				"Unclassified treasure — still worth its weight on the market."
			)
		)

	lines.append("")
	lines.append(_item_detail_soft_rule())
	lines.append(_item_detail_section_heading("Details"))
	lines.append("")
	if item.get("description") != null and item.description.strip_edges() != "":
		var raw_desc: String = item.description.strip_edges()
		for piece: String in raw_desc.split("\n"):
			var row: String = piece.strip_edges()
			if row == "":
				lines.append("")
				continue
			lines.append(
				"[font_size=19][color=#b8a890]▸[/color][color=#5a5248]  [/color][color=%s]%s[/color][/font_size]"
				% [C_BODY, _bbcode_escape_user_text(row)]
			)
	else:
		lines.append(
			_item_detail_callout(
				"#7a7064",
				"#c8beb2",
				"No written notes for this entry — check its name in the list or try it in battle."
			)
		)

	return "\n".join(lines)


## Units/terrain live under the level root as [ BattleField ] siblings; parenting floaters there + last index keeps them above map actors.
func _mount_floating_combat_text(node: Node) -> void:
	var mount: Node = get_parent() if get_parent() != null else self
	mount.add_child(node)
	mount.move_child(node, -1)


func _floater_stack_nudge_for_anchor(anchor: Node) -> float:
	if anchor == null or not is_instance_valid(anchor):
		return 0.0
	var id: int = anchor.get_instance_id()
	var depth: int = int(_floater_stack_by_unit.get(id, 0))
	_floater_stack_by_unit[id] = depth + 1
	var timer := get_tree().create_timer(0.4)
	var captured_id: int = id
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		var d: int = int(_floater_stack_by_unit.get(captured_id, 0))
		d = maxi(0, d - 1)
		if d <= 0:
			_floater_stack_by_unit.erase(captured_id)
		else:
			_floater_stack_by_unit[captured_id] = d
	)
	return -14.0 * float(depth)


## meta keys: tier (FloatingCombatText.Tier), hp_chunk_ratio (0..1), stack_anchor (Node).
func spawn_loot_text(text: String, color: Color, pos: Vector2, meta = null) -> void:
	var md: Dictionary = meta if meta is Dictionary else {}
	var f_text = FloatingTextScene.instantiate()
	f_text.text_to_show = text
	f_text.text_color = color
	if md.has("tier"):
		f_text.tier = md["tier"]
	if md.has("hp_chunk_ratio"):
		f_text.hp_chunk_ratio = md["hp_chunk_ratio"]
	var anchor: Node = md.get("stack_anchor", null)
	var nudge: float = _floater_stack_nudge_for_anchor(anchor)
	_mount_floating_combat_text(f_text)
	f_text.global_position = pos + Vector2(0.0, nudge)

func show_loot_window() -> void:
	await InventoryUiHelpers.show_loot_window(self)
	
func _on_close_loot_pressed() -> void:
	await TradeInventoryHelpers.on_close_loot_pressed(self)
				
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
	if _coop_remote_combat_replay_active:
		update_fog_of_war()
		update_objective_ui()
		return
	
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
	if result_label != null and result_label.text == "DEFEAT" and CoopExpeditionSessionManager.uses_runtime_network_coop_transport() and CoopExpeditionSessionManager.phase != CoopExpeditionSessionManager.Phase.NONE:
		SceneTransition.change_scene_to_file("res://Scenes/UI/ExpeditionCharterStagingUI.tscn")
		return
	
	# --- NEW: ARENA VICTORY LOGIC ---
	if is_arena_match:
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


func _build_deployment_roster_from_consumed_mock_coop_handoff() -> Array:
	if _consumed_mock_coop_battle_handoff.is_empty():
		return []
	var snap_raw: Variant = _consumed_mock_coop_battle_handoff.get("battle_roster_snapshot", null)
	if typeof(snap_raw) != TYPE_ARRAY:
		var launch_raw: Variant = _consumed_mock_coop_battle_handoff.get("launch_snapshot", {})
		if typeof(launch_raw) == TYPE_DICTIONARY:
			snap_raw = (launch_raw as Dictionary).get("battle_roster_snapshot", [])
			if OS.is_debug_build() and typeof(snap_raw) == TYPE_ARRAY and not (snap_raw as Array).is_empty():
				push_warning("[MockCoopHandoff] using legacy launch_snapshot.battle_roster_snapshot fallback; promote snapshot to top-level handoff.")
	if typeof(snap_raw) != TYPE_ARRAY:
		if OS.is_debug_build():
			push_warning("[MockCoopHandoff] missing shared battle_roster_snapshot; falling back to local deployment roster.")
		return []
	var roster: Array = CampaignManager.hydrate_mock_coop_battle_roster_snapshot(snap_raw)
	if OS.is_debug_build() and not roster.is_empty():
		print("[MockCoopHandoff] using shared battle roster snapshot units=%d" % roster.size())
	return roster
	
func load_campaign_data() -> void:
	# 1. Load global resources
	player_gold = CampaignManager.global_gold
	player_inventory = CampaignManager.global_inventory.duplicate()
	update_gold_display()

	var roster: Array = _build_deployment_roster_from_consumed_mock_coop_handoff()
	if roster.is_empty():
		roster = _build_deployment_roster()
	
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
		var saved_unit_name: String = str(saved.get("unit_name", "")).strip_edges()
		var avatar_name: String = str(CampaignManager.custom_avatar.get("name", "")).strip_edges()
		var avatar_unit_name: String = str(CampaignManager.custom_avatar.get("unit_name", "")).strip_edges()
		if bool(saved.get("is_custom_avatar", false)) or (saved_unit_name != "" and (saved_unit_name == avatar_name or saved_unit_name == avatar_unit_name)):
			new_unit.set("is_custom_avatar", true)
		else:
			new_unit.set("is_custom_avatar", false)
		var mock_coop_command_id: String = str(saved.get("mock_coop_command_id", "")).strip_edges()
		if mock_coop_command_id != "":
			new_unit.set_meta(MOCK_COOP_COMMAND_ID_META, mock_coop_command_id)
		elif new_unit.has_meta(MOCK_COOP_COMMAND_ID_META):
			new_unit.remove_meta(MOCK_COOP_COMMAND_ID_META)

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


func _reset_path_pulse_visuals() -> void:
	if path_line != null:
		var c: Color = path_line.modulate
		c.a = 1.0
		path_line.modulate = c
	if path_line_under != null:
		var cu: Color = path_line_under.modulate
		cu.a = 1.0
		path_line_under.modulate = cu


func _set_path_pulse(active: bool) -> void:
	if not active:
		if _path_pulse_tween != null and _path_pulse_tween.is_valid():
			_path_pulse_tween.kill()
		_path_pulse_active = false
		_reset_path_pulse_visuals()
		return

	if path_line == null:
		return
	if _path_pulse_active:
		return
	_path_pulse_active = true
	if _path_pulse_tween != null and _path_pulse_tween.is_valid():
		_path_pulse_tween.kill()

	var fg_w_base: float = path_line.width
	var un_w_base: float = path_line_under.width if path_line_under != null else fg_w_base

	var pm: Color = path_line.modulate
	pm.a = PATH_ALPHA_MIN
	path_line.modulate = pm
	if path_line_under != null:
		var pu: Color = path_line_under.modulate
		pu.a = PATH_ALPHA_MIN
		path_line_under.modulate = pu

	var apply_pulse: Callable = func(alpha: float) -> void:
		path_line.modulate.a = alpha
		if path_line_under != null:
			path_line_under.modulate.a = alpha
		var span: float = PATH_ALPHA_MAX - PATH_ALPHA_MIN
		var u: float = 0.0 if span <= 0.0001 else clampf((alpha - PATH_ALPHA_MIN) / span, 0.0, 1.0)
		path_line.width = fg_w_base + PATH_PREVIEW_PULSE_W_FG * u
		if path_line_under != null:
			path_line_under.width = un_w_base + PATH_PREVIEW_PULSE_W_UNDER * u

	_path_pulse_tween = create_tween()
	_path_pulse_tween.set_loops()
	_path_pulse_tween.tween_method(apply_pulse, PATH_ALPHA_MIN, PATH_ALPHA_MAX, PATH_PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_path_pulse_tween.tween_method(apply_pulse, PATH_ALPHA_MAX, PATH_ALPHA_MIN, PATH_PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

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
		UISfx.INVENTORY_EQUIP:
			player = select_sound
			p = randf_range(0.86, 0.97)
		UISfx.INVENTORY_USE:
			player = select_sound
			p = randf_range(1.14, 1.30)

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
func _apply_battlefield_qte_ui_polish(
	qte_layer: CanvasLayer,
	screen_dimmer: ColorRect,
	bar_bg: ColorRect,
	help_text: Label,
	top_bar: ColorRect,
	bottom_bar: ColorRect,
	accent: Color,
	title_text: String
) -> void:
	if qte_layer == null or not is_instance_valid(qte_layer):
		return
	var vp_size: Vector2 = get_viewport_rect().size

	if screen_dimmer != null and is_instance_valid(screen_dimmer):
		screen_dimmer.color = Color(
			clampf(accent.r * 0.12, 0.0, 0.25),
			clampf(accent.g * 0.08, 0.0, 0.20),
			clampf(accent.b * 0.15, 0.0, 0.30),
			0.66
		)

	var atmosphere := ColorRect.new()
	atmosphere.name = "QteBattleAtmosphere"
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere.size = vp_size
	atmosphere.color = Color(
		clampf(accent.r * 0.10, 0.0, 0.18),
		clampf(accent.g * 0.08, 0.0, 0.14),
		clampf(accent.b * 0.12, 0.0, 0.20),
		0.28
	)
	atmosphere.z_index = -3
	qte_layer.add_child(atmosphere)
	qte_layer.move_child(atmosphere, 1)

	if top_bar != null:
		top_bar.color = Color(0.0, 0.0, 0.0, 0.90)
	if bottom_bar != null:
		bottom_bar.color = Color(0.0, 0.0, 0.0, 0.90)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0.0, bar_bg.position.y - 124.0)
	title.size = Vector2(vp_size.x, 52.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(minf(accent.r + 0.10, 1.0), minf(accent.g + 0.10, 1.0), minf(accent.b + 0.10, 1.0), 1.0))
	title.add_theme_constant_override("outline_size", 7)
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	qte_layer.add_child(title)

	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.position = bar_bg.position + Vector2(-26.0, -20.0)
	frame.size = bar_bg.size + Vector2(52.0, 40.0)
	frame.z_index = -1
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.05, 0.06, 0.09, 0.80)
	frame_style.border_color = Color(accent.r, accent.g, accent.b, 0.72)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(14)
	frame_style.shadow_size = 20
	frame_style.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	frame.add_theme_stylebox_override("panel", frame_style)
	qte_layer.add_child(frame)

	var frame_glow := ColorRect.new()
	frame_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_glow.size = Vector2(frame.size.x - 22.0, 4.0)
	frame_glow.position = Vector2(11.0, 10.0)
	frame_glow.color = Color(accent.r, accent.g, accent.b, 0.56)
	frame.add_child(frame_glow)

	if help_text != null and is_instance_valid(help_text):
		help_text.add_theme_font_size_override("font_size", 28)
		help_text.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 0.98))
		help_text.add_theme_constant_override("outline_size", 5)
		help_text.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
		var help_tw := qte_layer.create_tween().set_loops()
		help_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		help_tw.tween_property(help_text, "modulate:a", 0.74, 0.45)
		help_tw.tween_property(help_text, "modulate:a", 0.98, 0.45)

	var title_tw := qte_layer.create_tween().set_loops()
	title_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	title_tw.tween_property(title, "modulate:a", 0.86, 0.66)
	title_tw.tween_property(title, "modulate:a", 1.0, 0.66)


func _run_parry_minigame(defender: Node2D) -> bool:
	return await DefensiveReactionHelpers.run_parry_minigame(self, defender)

# --- ABILITY 2: SHIELD CLASH (Mashing QTE) ---
# Returns 0 (Fail), 1 (Block), 2 (Perfect Counter)
func _run_shield_clash_minigame(defender: Node2D, attacker: Node2D) -> int:
	return await DefensiveReactionHelpers.run_shield_clash_minigame(self, defender, attacker)
	
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
		
	spawn_loot_text("FOCUS STRIKE!", Color(1.0, 0.5, 0.0), attacker.global_position + Vector2(32, -48), {"stack_anchor": attacker})
	
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
		
	spawn_loot_text("BLOODTHIRSTER!", Color(0.8, 0.1, 0.1), attacker.global_position + Vector2(32, -48), {"stack_anchor": attacker})
	
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
		
	spawn_loot_text("HUNDRED POINT STRIKE!", Color(0.9, 0.2, 1.0), attacker.global_position + Vector2(32, -48), {"stack_anchor": attacker})
	
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
	return await DefensiveReactionHelpers.run_last_stand_minigame(self, defender)
	
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
	_queue_refit_item_description_panels()
	
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
	if not can_preview_enemy_threat(enemy): return

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
	var ew_variant: Variant = enemy.get("equipped_weapon")
	var ew: Resource = ew_variant as Resource if ew_variant is Resource else null
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
	TradeInventoryHelpers.execute_trade_swap(self, side1, idx1, side2, idx2)

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
	return SupportHelpers.normalize_support_rank(self, bond)

# --- Support-combat: Phase 1 passive bonuses; Phase 2 reactions (Guard, Defy Death, Dual Strike) via get_best_support_context + _apply_hit_with_support_reactions. ---
# Returns passive combat bonuses from the single best support partner within SUPPORT_COMBAT_RANGE_MANHATTAN.
# Only applies to player/ally units; uses CampaignManager.support_bonds; missing/legacy data => no bonus.
func get_support_combat_bonus(unit: Node2D) -> Dictionary:
	return SupportHelpers.get_support_combat_bonus(self, unit)

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
	await SupportHelpers.apply_hit_with_support_reactions(self, victim, damage, source, exp_tgt, is_redirected)

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
	return await PromotionChoiceUiHelpers.ask_for_promotion_choice(self, options)
	
# ==========================================
# --- NEW VFX HELPER FUNCTIONS ---
# ==========================================

# Creates rising energy particles (The Buildup)
func _create_evolution_buildup_vfx(target_pos: Vector2) -> CPUParticles2D:
	return PromotionVfxHelpers.create_evolution_buildup_vfx(self, target_pos)

# Creates an outward burst of particles (The Reveal)
func _create_evolution_burst_vfx(target_pos: Vector2) -> CPUParticles2D:
	return PromotionVfxHelpers.create_evolution_burst_vfx(self, target_pos)

func _start_battle_from_deployment() -> void:
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


func _on_start_battle_pressed() -> void:
	if current_state == pre_battle_state and _mock_coop_prebattle_ready_sync_active():
		var will_only_mark_ready: bool = not _mock_coop_remote_prebattle_ready
		if will_only_mark_ready and select_sound.stream != null:
			select_sound.play()
		_mock_coop_set_local_prebattle_ready(true)
		return
	_start_battle_from_deployment()

# ==========================================
# --- OBJECTIVE UI SYSTEM ---
# ==========================================
var objective_panel: Panel
var objective_label: RichTextLabel
var objective_toggle_btn: Button
var is_objective_expanded: bool = true

func _setup_objective_ui() -> void:
	ObjectiveUiHelpers.setup_objective_ui(self)

func _on_objective_toggle_pressed() -> void:
	ObjectiveUiHelpers.on_objective_toggle_pressed(self)

func update_objective_ui(skip_animation: bool = false) -> void:
	ObjectiveUiHelpers.update_objective_ui(self, skip_animation)
				
# ==========================================
# --- EPIC VFX SPAWNERS ---
# ==========================================
func spawn_dash_effect(start_pos: Vector2, target_pos: Vector2) -> void:
	CombatVfxHelpers.spawn_dash_effect(self, start_pos, target_pos)

func spawn_slash_effect(target_pos: Vector2, attacker_pos: Vector2, is_crit: bool = false) -> void:
	CombatVfxHelpers.spawn_slash_effect(self, target_pos, attacker_pos, is_crit)

func spawn_level_up_effect(target_pos: Vector2) -> void:
	CombatVfxHelpers.spawn_level_up_effect(self, target_pos)


func spawn_blood_splatter(target_unit: Node2D, attacker_pos: Vector2, is_crit: bool = false) -> void:
	CombatVfxHelpers.spawn_blood_splatter(self, target_unit, attacker_pos, is_crit)

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
			await play_cinematic_dialogue(final_name, final_portrait, formatted_lines, true)

	# Once all the dialogue finishes (or is skipped), begin the Deployment Phase!
	change_state(pre_battle_state)
	
func _capture_ui_visibility_snapshot() -> Array[Dictionary]:
	return CinematicDialogueHelpers.capture_ui_visibility_snapshot(self)

func _set_ui_children_visible(visible: bool) -> void:
	CinematicDialogueHelpers.set_ui_children_visible(self, visible)

func _restore_ui_visibility_snapshot(snapshot: Array[Dictionary]) -> void:
	CinematicDialogueHelpers.restore_ui_visibility_snapshot(self, snapshot)

func play_cinematic_dialogue(speaker_name: String, portrait_tex: Texture2D, lines: Array, hide_gameplay_ui: bool = false) -> void:
	await CinematicDialogueHelpers.play_cinematic_dialogue(self, speaker_name, portrait_tex, lines, hide_gameplay_ui)
	
func animate_shield_drop(unit: Node2D) -> void:
	StatusIconVfxHelpers.animate_shield_drop(self, unit)

# Helper function to handle the toggle logic
func _toggle_minimap() -> void:
	MinimapHelpers.toggle_minimap(self)

# ==========================================
# --- OUTRO CINEMATIC & VICTORY ---
# ==========================================
func _trigger_victory() -> void:
	if _coop_finalized_battle_result != "":
		return
	if _coop_battle_result_resolution_in_progress == "VICTORY":
		return
	if not _coop_remote_battle_result_applying:
		if coop_enet_should_wait_for_host_authoritative_battle_result():
			_coop_wait_for_host_authoritative_battle_result("VICTORY")
			return
		if _defer_battle_result_until_loot_if_needed("VICTORY"):
			return
		coop_enet_sync_after_host_authoritative_battle_result("VICTORY")
	elif _defer_battle_result_until_loot_if_needed("VICTORY"):
		return
	_coop_battle_result_resolution_in_progress = "VICTORY"

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
			await play_cinematic_dialogue(final_name, final_portrait, formatted_lines, true)

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
	_apply_decor_fow_shadow()
	
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

func _decor_base_modulate(item: CanvasItem) -> Color:
	var key: int = item.get_instance_id()
	if not _decor_fow_base_modulates.has(key):
		_decor_fow_base_modulates[key] = item.modulate
	return _decor_fow_base_modulates[key]

func _decor_tile_currently_visible(node: Node2D) -> bool:
	for tile in _unit_footprint_tiles(node):
		if fow_grid.has(tile) and fow_grid[tile] == 2:
			return true
	return false

func _apply_decor_fow_shadow() -> void:
	if decor_layer == null:
		return
	for child in decor_layer.get_children():
		var item: CanvasItem = child as CanvasItem
		if item == null or not is_instance_valid(item) or item.is_queued_for_deletion():
			continue
		var base: Color = _decor_base_modulate(item)
		var node_2d: Node2D = child as Node2D
		if node_2d == null or _decor_tile_currently_visible(node_2d):
			item.modulate = base
			continue
		item.modulate = Color(
			base.r * DECOR_FOG_SHADOW_TINT.r,
			base.g * DECOR_FOG_SHADOW_TINT.g,
			base.b * DECOR_FOG_SHADOW_TINT.b,
			base.a * DECOR_FOG_SHADOW_TINT.a
		)

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
	GoldVfxHelpers.animate_flying_gold(self, world_pos, amount)
		
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

	spawn_loot_text("MOMENTUM!", Color(0.2, 1.0, 1.0), attacker.global_position + Vector2(32, -48), {"stack_anchor": attacker})

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

func _is_enemy_reinforcement_spawner(node: Node2D) -> bool:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return false
	if not node.visible:
		return false
	if not node.has_method("process_turn"):
		return false
	var raw_faction: Variant = node.get("spawner_faction")
	if raw_faction == null or int(raw_faction) != 0:
		return false
	var slot_timers_value: Variant = node.get("slot_timers")
	return slot_timers_value is Array

func _enemy_spawner_slot_is_open(active_units_value: Variant, slot_index: int) -> bool:
	if active_units_value is Dictionary:
		var active_unit: Variant = active_units_value.get(slot_index, null)
		if active_unit == null:
			return true
		if active_unit is Node:
			var active_node: Node = active_unit as Node
			return not is_instance_valid(active_node) or active_node.is_queued_for_deletion()
	return true

func _predict_turns_until_enemy_spawner_spawn(spawner: Node2D) -> int:
	if not _is_enemy_reinforcement_spawner(spawner):
		return -1
	var slot_timers_value: Variant = spawner.get("slot_timers")
	if not (slot_timers_value is Array):
		return -1
	var slot_timers: Array = slot_timers_value
	var active_units_value: Variant = spawner.get("active_units")
	var best_turns: int = -1
	for slot_index in range(slot_timers.size()):
		if not _enemy_spawner_slot_is_open(active_units_value, slot_index):
			continue
		var raw_timer: Variant = slot_timers[slot_index]
		if raw_timer == null:
			continue
		var timer: int = int(raw_timer)
		if timer < 0:
			continue
		var turns_until_spawn: int = 1 if timer <= 1 else timer
		if best_turns == -1 or turns_until_spawn < best_turns:
			best_turns = turns_until_spawn
	return best_turns

func _get_spawner_display_tiles(spawner: Node2D) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if spawner == null or not is_instance_valid(spawner):
		return tiles
	if spawner.has_method("get_occupied_tiles"):
		for raw_tile in spawner.get_occupied_tiles(self):
			if raw_tile is Vector2i and not tiles.has(raw_tile):
				tiles.append(raw_tile)
	if tiles.is_empty():
		tiles.append(get_grid_pos(spawner))
	return tiles

func _build_enemy_reinforcement_telegraph_snapshot() -> Dictionary:
	var telegraphable_count: int = 0
	var due_next_count: int = 0
	var next_turns: int = -1
	var soon_tiles: Array[Vector2i] = []
	var later_tiles: Array[Vector2i] = []

	if destructibles_container == null:
		return {
			"telegraphable_count": telegraphable_count,
			"due_next_count": due_next_count,
			"next_turns": next_turns,
			"soon_tiles": soon_tiles,
			"later_tiles": later_tiles,
		}

	for child in destructibles_container.get_children():
		var spawner: Node2D = child as Node2D
		if not _is_enemy_reinforcement_spawner(spawner):
			continue
		var turns_until_spawn: int = _predict_turns_until_enemy_spawner_spawn(spawner)
		if turns_until_spawn < 0:
			continue
		telegraphable_count += 1
		if next_turns == -1 or turns_until_spawn < next_turns:
			next_turns = turns_until_spawn
		if turns_until_spawn <= REINFORCEMENT_WARNING_ENEMY_PHASES:
			due_next_count += 1
			for tile in _get_spawner_display_tiles(spawner):
				if not soon_tiles.has(tile):
					soon_tiles.append(tile)
		else:
			for tile in _get_spawner_display_tiles(spawner):
				if not later_tiles.has(tile):
					later_tiles.append(tile)

	return {
		"telegraphable_count": telegraphable_count,
		"due_next_count": due_next_count,
		"next_turns": next_turns,
		"soon_tiles": soon_tiles,
		"later_tiles": later_tiles,
	}

func _build_enemy_reinforcement_objective_bbcode() -> String:
	var snapshot: Dictionary = _build_enemy_reinforcement_telegraph_snapshot()
	var telegraphable_count: int = int(snapshot.get("telegraphable_count", 0))
	if telegraphable_count <= 0:
		return ""
	var next_turns: int = int(snapshot.get("next_turns", -1))
	var due_next_count: int = int(snapshot.get("due_next_count", 0))
	if next_turns <= 0:
		return "[color=gray]Enemy reinforcements: movement is obscured.[/color]"
	if next_turns == 1:
		var soon_noun: String = "spawner" if due_next_count == 1 else "spawners"
		return "[color=orange]Enemy reinforcements: " + str(due_next_count) + " " + soon_noun + " primed for the next enemy phase.[/color]"
	var phase_noun: String = "phase" if next_turns == 1 else "phases"
	return "[color=gold]Enemy reinforcements: next wave in " + str(next_turns) + " enemy " + phase_noun + ".[/color]"

func _maybe_log_enemy_reinforcement_warning_for_player_phase() -> void:
	if battle_log == null or not battle_log.visible:
		return
	if _last_enemy_reinforcement_warning_turn == current_turn:
		return
	var snapshot: Dictionary = _build_enemy_reinforcement_telegraph_snapshot()
	var due_next_count: int = int(snapshot.get("due_next_count", 0))
	if due_next_count <= 0:
		return
	_last_enemy_reinforcement_warning_turn = current_turn
	var soon_noun: String = "spawner" if due_next_count == 1 else "spawners"
	add_combat_log("Scout report: " + str(due_next_count) + " enemy " + soon_noun + " are primed for the next enemy phase.", "orange")

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
	var opp_mmr: int = ArenaManager.sanitize_leaderboard_score_mmr(ArenaManager.current_opponent_data.get("score", 1000))
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
		forecast_atk_support_label.position = Vector2(24, 190)
		forecast_atk_support_label.size = Vector2(190, 22)
		forecast_atk_support_label.add_theme_font_size_override("font_size", 16)
		forecast_atk_support_label.add_theme_color_override("font_color", Color(0.60, 0.95, 1.0))
		forecast_panel.add_child(forecast_atk_support_label)

	if forecast_def_support_label == null:
		forecast_def_support_label = Label.new()
		forecast_def_support_label.name = "DefSupportBonus"
		forecast_def_support_label.position = Vector2(326, 190)
		forecast_def_support_label.size = Vector2(190, 22)
		forecast_def_support_label.add_theme_font_size_override("font_size", 16)
		forecast_def_support_label.add_theme_color_override("font_color", Color(0.60, 0.95, 1.0))
		forecast_panel.add_child(forecast_def_support_label)

	if forecast_instruction_label == null:
		forecast_instruction_label = Label.new()
		forecast_instruction_label.name = "ForecastInstruction"
		forecast_instruction_label.position = Vector2(24, 262)
		forecast_instruction_label.size = Vector2(492, 20)
		forecast_instruction_label.add_theme_font_size_override("font_size", 11)
		forecast_instruction_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9))
		forecast_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		forecast_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		forecast_instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		forecast_panel.add_child(forecast_instruction_label)

	if forecast_reaction_label == null:
		forecast_reaction_label = Label.new()
		forecast_reaction_label.name = "ForecastReactionSummary"
		forecast_reaction_label.position = Vector2(24, 284)
		forecast_reaction_label.size = Vector2(492, 18)
		forecast_reaction_label.add_theme_font_size_override("font_size", 10)
		forecast_reaction_label.add_theme_color_override("font_color", Color(0.90, 0.84, 0.62))
		forecast_reaction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		forecast_reaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		forecast_reaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		forecast_panel.add_child(forecast_reaction_label)

	# Keep bottom stack above Confirm/Cancel (~y 201+).
	if forecast_instruction_label != null:
		forecast_instruction_label.position = Vector2(24, 262)
		forecast_instruction_label.size = Vector2(492, 20)
	if forecast_reaction_label != null:
		forecast_reaction_label.position = Vector2(24, 284)
		forecast_reaction_label.size = Vector2(492, 18)

func apply_campaign_settings() -> void:
	camera_follows_enemies = CampaignManager.battle_follow_enemy_camera
	_apply_cursor_accessibility_settings()

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

	draw_preview_path()

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
	var locked_inspect_unit: Node2D = _get_locked_inspect_unit()
	if locked_inspect_unit != null:
		return locked_inspect_unit
	var hovered_occupant: Node2D = get_occupant_at(cursor_grid_pos)
	if hovered_occupant != null:
		return hovered_occupant
	if current_state == player_state and player_state.active_unit != null:
		return player_state.active_unit
	return null


func can_preview_enemy_threat(unit: Node2D) -> bool:
	if unit == null or not is_instance_valid(unit) or unit.is_queued_for_deletion():
		return false
	if unit.get_parent() != enemy_container:
		return false
	if unit.get("move_range") == null:
		return false
	if unit.get("move_type") == null:
		return false
	return true


func _get_locked_inspect_unit() -> Node2D:
	if inspected_unit == null:
		return null
	if not is_instance_valid(inspected_unit) or inspected_unit.is_queued_for_deletion():
		inspected_unit = null
		return null
	if current_state == player_state and player_state.active_unit != null:
		return null
	return inspected_unit
	
func _ensure_detailed_unit_info_panel() -> void:
	if detailed_unit_info_layer != null and is_instance_valid(detailed_unit_info_layer):
		return

	detailed_unit_info_primary_widgets.clear()
	detailed_unit_info_stat_widgets.clear()
	detailed_unit_info_growth_widgets.clear()

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
	detailed_unit_info_panel.custom_minimum_size = Vector2(1320, 860)
	detailed_unit_info_panel.visible = false
	detailed_unit_info_layer.add_child(detailed_unit_info_panel)

	detailed_unit_info_panel.anchor_left = 0.5
	detailed_unit_info_panel.anchor_top = 0.5
	detailed_unit_info_panel.anchor_right = 0.5
	detailed_unit_info_panel.anchor_bottom = 0.5
	detailed_unit_info_panel.offset_left = -660
	detailed_unit_info_panel.offset_top = -430
	detailed_unit_info_panel.offset_right = 660
	detailed_unit_info_panel.offset_bottom = 430
	_style_tactical_panel(detailed_unit_info_panel, TACTICAL_UI_BG_ALT, TACTICAL_UI_BORDER, 2, 16)

	var root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	root.add_theme_constant_override("separation", 18)
	detailed_unit_info_panel.add_child(root)

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	root.add_child(header)

	var portrait_frame := Panel.new()
	portrait_frame.custom_minimum_size = Vector2(214, 214)
	_style_tactical_panel(portrait_frame, TACTICAL_UI_BG_SOFT, TACTICAL_UI_BORDER_MUTED, 1, 12)
	header.add_child(portrait_frame)

	detailed_unit_info_portrait = TextureRect.new()
	detailed_unit_info_portrait.custom_minimum_size = Vector2(190, 190)
	detailed_unit_info_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detailed_unit_info_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detailed_unit_info_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	portrait_frame.add_child(detailed_unit_info_portrait)

	var name_box = VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 8)
	header.add_child(name_box)

	detailed_unit_info_name = Label.new()
	_style_tactical_label(detailed_unit_info_name, TACTICAL_UI_ACCENT, 40, 3)
	name_box.add_child(detailed_unit_info_name)

	detailed_unit_info_meta_label = Label.new()
	_style_tactical_label(detailed_unit_info_meta_label, TACTICAL_UI_TEXT_MUTED, 22, 2)
	name_box.add_child(detailed_unit_info_meta_label)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 3)
	divider.color = Color(TACTICAL_UI_BORDER.r, TACTICAL_UI_BORDER.g, TACTICAL_UI_BORDER.b, 0.55)
	name_box.add_child(divider)

	var weapon_row := HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 10)
	name_box.add_child(weapon_row)

	var weapon_pair_frame := Panel.new()
	weapon_pair_frame.custom_minimum_size = Vector2(114, 48)
	_style_tactical_panel(weapon_pair_frame, Color(0.16, 0.13, 0.09, 0.94), TACTICAL_UI_BORDER_MUTED, 1, 8)
	weapon_row.add_child(weapon_pair_frame)

	var weapon_pair_inner := HBoxContainer.new()
	weapon_pair_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	weapon_pair_inner.add_theme_constant_override("separation", 6)
	weapon_pair_frame.add_child(weapon_pair_inner)

	var weapon_badge_panel := Panel.new()
	weapon_badge_panel.custom_minimum_size = Vector2(50, 32)
	_style_tactical_panel(weapon_badge_panel, Color(0.24, 0.18, 0.10, 0.96), TACTICAL_UI_BORDER, 1, 7)
	weapon_pair_inner.add_child(weapon_badge_panel)

	detailed_unit_info_weapon_badge = Label.new()
	detailed_unit_info_weapon_badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
	_style_tactical_label(detailed_unit_info_weapon_badge, TACTICAL_UI_ACCENT, 16, 2)
	detailed_unit_info_weapon_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detailed_unit_info_weapon_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	weapon_badge_panel.add_child(detailed_unit_info_weapon_badge)

	var weapon_icon_panel := Panel.new()
	weapon_icon_panel.custom_minimum_size = Vector2(32, 32)
	_style_tactical_panel(weapon_icon_panel, Color(0.11, 0.10, 0.08, 0.96), TACTICAL_UI_BORDER_MUTED, 1, 6)
	weapon_pair_inner.add_child(weapon_icon_panel)

	detailed_unit_info_weapon_icon = TextureRect.new()
	detailed_unit_info_weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detailed_unit_info_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detailed_unit_info_weapon_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
	weapon_icon_panel.add_child(detailed_unit_info_weapon_icon)

	detailed_unit_info_weapon_name = Label.new()
	detailed_unit_info_weapon_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_tactical_label(detailed_unit_info_weapon_name, TACTICAL_UI_TEXT, 22, 2)
	weapon_row.add_child(detailed_unit_info_weapon_name)

	detailed_unit_info_summary_text = RichTextLabel.new()
	detailed_unit_info_summary_text.bbcode_enabled = true
	detailed_unit_info_summary_text.fit_content = true
	detailed_unit_info_summary_text.scroll_active = false
	detailed_unit_info_summary_text.custom_minimum_size = Vector2(0, 94)
	_style_tactical_richtext(detailed_unit_info_summary_text, 22, 22)
	name_box.add_child(detailed_unit_info_summary_text)

	var close_box := VBoxContainer.new()
	close_box.alignment = BoxContainer.ALIGNMENT_END
	header.add_child(close_box)

	detailed_unit_info_close_btn = Button.new()
	detailed_unit_info_close_btn.custom_minimum_size = Vector2(196, 68)
	_style_tactical_button(detailed_unit_info_close_btn, "Close", false, 26)
	detailed_unit_info_close_btn.pressed.connect(func():
		_hide_detailed_unit_info_panel()
	)
	close_box.add_child(detailed_unit_info_close_btn)

	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	root.add_child(body)

	var left_panel = Panel.new()
	left_panel.custom_minimum_size = Vector2(560, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_tactical_panel(left_panel, TACTICAL_UI_BG_SOFT, TACTICAL_UI_BORDER_MUTED, 1, 12)
	body.add_child(left_panel)

	var right_panel = Panel.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_tactical_panel(right_panel, TACTICAL_UI_BG_SOFT, TACTICAL_UI_BORDER_MUTED, 1, 12)
	body.add_child(right_panel)

	var left_scroll := ScrollContainer.new()
	left_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	left_panel.add_child(left_scroll)

	var left_root := VBoxContainer.new()
	left_root.custom_minimum_size = Vector2(0, 760)
	left_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_root.add_theme_constant_override("separation", 14)
	left_scroll.add_child(left_root)

	var core_status_label := Label.new()
	_style_tactical_label(core_status_label, TACTICAL_UI_ACCENT, 22, 2)
	core_status_label.text = "Core Status"
	left_root.add_child(core_status_label)

	var primary_root := VBoxContainer.new()
	primary_root.name = "DetailedUnitPrimaryBarsRoot"
	primary_root.add_theme_constant_override("separation", 10)
	left_root.add_child(primary_root)

	for bar_def in _unit_info_primary_bar_definitions():
		var bar_key: String = str(bar_def.get("key", ""))
		var block := Panel.new()
		block.custom_minimum_size = Vector2(0, 102)
		_style_tactical_panel(block, Color(0.10, 0.09, 0.07, 0.90), TACTICAL_UI_BORDER_MUTED, 1, 8)
		primary_root.add_child(block)

		var block_box := VBoxContainer.new()
		block_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		block_box.add_theme_constant_override("separation", 6)
		block.add_child(block_box)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		block_box.add_child(row)

		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var value_chip := Panel.new()
		value_chip.custom_minimum_size = Vector2(116, 28)
		row.add_child(value_chip)

		var value_label := Label.new()
		value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
		value_chip.add_child(value_label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 18)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block_box.add_child(bar)

		var desc_label := Label.new()
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_label.custom_minimum_size = Vector2(0, 34)
		block_box.add_child(desc_label)

		var sheen := _attach_unit_info_bar_sheen(bar)
		detailed_unit_info_primary_widgets[bar_key] = {
			"panel": block,
			"name": name_label,
			"value_chip": value_chip,
			"value": value_label,
			"bar": bar,
			"desc": desc_label,
			"sheen": sheen,
		}

	_ensure_detailed_unit_info_primary_widgets_style()

	var combat_profile_label := Label.new()
	_style_tactical_label(combat_profile_label, TACTICAL_UI_ACCENT, 22, 2)
	combat_profile_label.text = "Combat Profile"
	left_root.add_child(combat_profile_label)

	var stat_root := GridContainer.new()
	stat_root.name = "DetailedUnitStatGrid"
	stat_root.columns = 1
	stat_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_root.add_theme_constant_override("h_separation", 0)
	stat_root.add_theme_constant_override("v_separation", 12)
	left_root.add_child(stat_root)

	for stat_def in _unit_info_stat_definitions():
		var stat_key: String = str(stat_def.get("key", ""))
		var stat_block := Panel.new()
		stat_block.custom_minimum_size = Vector2(0, 92)
		stat_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_tactical_panel(stat_block, Color(0.10, 0.09, 0.07, 0.88), TACTICAL_UI_BORDER_MUTED, 1, 6)
		stat_root.add_child(stat_block)

		var stat_box := VBoxContainer.new()
		stat_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		stat_box.add_theme_constant_override("separation", 6)
		stat_block.add_child(stat_box)

		var stat_row := HBoxContainer.new()
		stat_row.add_theme_constant_override("separation", 8)
		stat_box.add_child(stat_row)

		var stat_name := Label.new()
		stat_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_row.add_child(stat_name)

		var stat_hints := HBoxContainer.new()
		stat_hints.add_theme_constant_override("separation", 4)
		stat_row.add_child(stat_hints)

		var stat_value_chip := Panel.new()
		stat_value_chip.custom_minimum_size = Vector2(88, 28)
		stat_row.add_child(stat_value_chip)

		var stat_value_label := Label.new()
		stat_value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 1)
		stat_value_chip.add_child(stat_value_label)

		var stat_bar := ProgressBar.new()
		stat_bar.custom_minimum_size = Vector2(0, 16)
		stat_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_box.add_child(stat_bar)

		var stat_desc := Label.new()
		stat_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stat_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_box.add_child(stat_desc)

		var stat_sheen := _attach_unit_info_bar_sheen(stat_bar)
		detailed_unit_info_stat_widgets[stat_key] = {
			"panel": stat_block,
			"name": stat_name,
			"hints": stat_hints,
			"value_chip": stat_value_chip,
			"value": stat_value_label,
			"bar": stat_bar,
			"desc": stat_desc,
			"sheen": stat_sheen,
		}

	var right_root := VBoxContainer.new()
	right_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
	right_root.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_root)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_root.add_child(right_scroll)

	var right_content := VBoxContainer.new()
	right_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_content.add_theme_constant_override("separation", 14)
	right_scroll.add_child(right_content)

	var growth_title := Label.new()
	_style_tactical_label(growth_title, TACTICAL_UI_ACCENT, 22, 2)
	growth_title.text = "Growth Outlook"
	right_content.add_child(growth_title)

	var growth_root := VBoxContainer.new()
	growth_root.name = "DetailedUnitGrowthRoot"
	growth_root.add_theme_constant_override("separation", 8)
	right_content.add_child(growth_root)

	for growth_def in [
		{"key": "hp_growth_bonus", "label": "HP", "base": "hp"},
		{"key": "str_growth_bonus", "label": "STR", "base": "strength"},
		{"key": "mag_growth_bonus", "label": "MAG", "base": "magic"},
		{"key": "def_growth_bonus", "label": "DEF", "base": "defense"},
		{"key": "res_growth_bonus", "label": "RES", "base": "resistance"},
		{"key": "spd_growth_bonus", "label": "SPD", "base": "speed"},
		{"key": "agi_growth_bonus", "label": "AGI", "base": "agility"},
	]:
		var growth_key: String = str(growth_def.get("key", ""))
		var growth_block := Panel.new()
		growth_block.custom_minimum_size = Vector2(0, 48)
		_style_tactical_panel(growth_block, Color(0.10, 0.09, 0.07, 0.84), TACTICAL_UI_BORDER_MUTED, 1, 7)
		growth_root.add_child(growth_block)

		var growth_box := VBoxContainer.new()
		growth_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		growth_box.add_theme_constant_override("separation", 2)
		growth_block.add_child(growth_box)

		var growth_row := HBoxContainer.new()
		growth_row.add_theme_constant_override("separation", 8)
		growth_box.add_child(growth_row)

		var growth_name := Label.new()
		growth_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		growth_row.add_child(growth_name)

		var growth_value_chip := Panel.new()
		growth_value_chip.custom_minimum_size = Vector2(92, 22)
		growth_row.add_child(growth_value_chip)

		var growth_value_label := Label.new()
		growth_value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 1)
		growth_value_chip.add_child(growth_value_label)

		var growth_bar := ProgressBar.new()
		growth_bar.custom_minimum_size = Vector2(0, 14)
		growth_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		growth_box.add_child(growth_bar)

		var growth_sheen := _attach_unit_info_bar_sheen(growth_bar)
		detailed_unit_info_growth_widgets[growth_key] = {
			"panel": growth_block,
			"name": growth_name,
			"value_chip": growth_value_chip,
			"value": growth_value_label,
			"bar": growth_bar,
			"sheen": growth_sheen,
			"base_key": String(growth_def.get("base", "")),
			"label": String(growth_def.get("label", growth_key)),
		}

	var rel_title := Label.new()
	_style_tactical_label(rel_title, TACTICAL_UI_ACCENT, 22, 2)
	rel_title.text = "Bond Network"
	right_content.add_child(rel_title)

	detailed_unit_info_relationships_root = VBoxContainer.new()
	detailed_unit_info_relationships_root.add_theme_constant_override("separation", 10)
	right_content.add_child(detailed_unit_info_relationships_root)

	var right_title := Label.new()
	_style_tactical_label(right_title, TACTICAL_UI_ACCENT, 22, 2)
	right_title.text = "Field Record"
	right_content.add_child(right_title)

	detailed_unit_info_right_text = RichTextLabel.new()
	detailed_unit_info_right_text.bbcode_enabled = true
	detailed_unit_info_right_text.fit_content = false
	detailed_unit_info_right_text.scroll_active = false
	detailed_unit_info_right_text.custom_minimum_size = Vector2(0, 300)
	detailed_unit_info_right_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_tactical_richtext(detailed_unit_info_right_text, 24, 24)
	right_content.add_child(detailed_unit_info_right_text)

	detailed_unit_info_left_text = null
			
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
	detailed_unit_info_meta_label.text = _build_detailed_unit_info_meta_line(unit)
	_populate_detailed_unit_info_weapon_row(unit)
	detailed_unit_info_summary_text.bbcode_text = _build_detailed_unit_info_summary_text(unit)
	detailed_unit_info_right_text.bbcode_text = _build_detailed_unit_info_record_text(unit)
	_build_detailed_unit_info_relationship_cards(unit)
	_refresh_detailed_unit_info_visuals(unit, true)
	
func _hide_detailed_unit_info_panel() -> void:
	if detailed_unit_info_panel == null:
		return

	if detailed_unit_info_anim_tween != null:
		detailed_unit_info_anim_tween.kill()
		detailed_unit_info_anim_tween = null
	var dimmer = detailed_unit_info_layer.get_node("Dimmer")
	dimmer.visible = false
	detailed_unit_info_panel.visible = false

func _ensure_detailed_unit_info_primary_widgets_style() -> void:
	for bar_def in _unit_info_primary_bar_definitions():
		var bar_key: String = str(bar_def.get("key", ""))
		if not detailed_unit_info_primary_widgets.has(bar_key):
			continue
		var widgets: Dictionary = detailed_unit_info_primary_widgets[bar_key]
		var name_label := widgets.get("name") as Label
		var value_chip := widgets.get("value_chip") as Panel
		var value_label := widgets.get("value") as Label
		var bar := widgets.get("bar") as ProgressBar
		var desc_label := widgets.get("desc") as Label
		if name_label != null:
			_style_tactical_label(name_label, TACTICAL_UI_TEXT_MUTED, 14, 2)
		if value_chip != null:
			_style_tactical_panel(value_chip, Color(0.10, 0.09, 0.07, 0.98), Color(0.36, 0.32, 0.22, 0.90), 1, 6)
		if value_label != null:
			_style_tactical_label(value_label, TACTICAL_UI_TEXT, 18, 2)
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if bar != null:
			bar.min_value = 0.0
		if desc_label != null:
			_style_tactical_label(desc_label, TACTICAL_UI_TEXT_MUTED, 13, 1)

func _resolve_detailed_unit_info_class_label(unit: Node2D) -> String:
	if unit == null:
		return "Unknown"
	var class_res: Resource = null
	if unit.get("active_class_data") != null:
		class_res = unit.active_class_data
	if class_res != null and class_res.get("job_name") != null:
		return str(class_res.job_name)
	if unit.get("unit_class_name") != null:
		return str(unit.unit_class_name)
	return "Unknown"

func _build_detailed_unit_info_meta_line(unit: Node2D) -> String:
	if unit == null:
		return ""
	var level_value: int = int(unit.get("level")) if unit.get("level") != null else 1
	var move_value: int = int(unit.get("move_range")) if unit.get("move_range") != null else 0
	return "LV %d  |  MOVE %d  |  CLASS %s" % [level_value, move_value, _resolve_detailed_unit_info_class_label(unit).to_upper()]

func _build_detailed_unit_info_summary_text(unit: Node2D) -> String:
	if unit == null:
		return ""
	var lines: Array[String] = []
	var ability_name: String = ""
	if "unlocked_abilities" in unit and unit.unlocked_abilities.size() > 0:
		ability_name = ", ".join(unit.unlocked_abilities)
	elif unit.get("ability") != null and str(unit.ability).strip_edges() != "":
		ability_name = str(unit.ability)
	if ability_name != "":
		lines.append("[color=#87d4ff]Ability:[/color] [color=#e9f8ff]%s[/color]" % ability_name)
	var inventory_count: int = unit.inventory.size() if "inventory" in unit else 0
	lines.append("[color=#f2bf59]Inventory:[/color] [color=#fff0c8]%d carried item%s[/color]" % [inventory_count, "" if inventory_count == 1 else "s"])
	return "\n".join(lines)

func _detailed_unit_info_stat_description(stat_key: String) -> String:
	match stat_key:
		"strength":
			return "Raises damage with swords, lances, axes, bows, and many physical techniques."
		"magic":
			return "Raises damage with spells, magic weapons, and abilities that scale from magical power."
		"defense":
			return "Reduces damage taken from physical attacks like blades, arrows, claws, and blunt impacts."
		"resistance":
			return "Reduces damage taken from spells, elemental attacks, curses, and other magical effects."
		"speed":
			return "Helps this unit strike twice before slower enemies and avoid being struck twice by faster ones."
		"agility":
			return "Improves dodge and evasive reactions, and it is the main stat feeding base critical chance before weapon, skill, and battle bonuses."
		_:
			return ""

func _detailed_unit_info_stat_label(stat_key: String) -> String:
	match stat_key:
		"strength":
			return "STRENGTH"
		"magic":
			return "MAGIC"
		"defense":
			return "DEFENSE"
		"resistance":
			return "RESISTANCE"
		"speed":
			return "SPEED"
		"agility":
			return "AGILITY"
		_:
			return stat_key.to_upper()

func _detailed_unit_info_stat_hint_specs(stat_key: String) -> Array[Dictionary]:
	match stat_key:
		"speed":
			return [
				{"text": "x2", "color": Color(0.45, 0.78, 1.0, 1.0)},
				{"text": "TEMPO", "color": Color(0.58, 0.84, 1.0, 1.0)},
			]
		"agility":
			return [
				{"text": "CRIT", "color": Color(1.0, 0.78, 0.30, 1.0)},
				{"text": "EVADE", "color": Color(0.60, 0.94, 0.76, 1.0)},
			]
		_:
			return []

func _detailed_unit_info_growth_label(growth_key: String) -> String:
	match growth_key:
		"hp_growth_bonus":
			return "HEALTH GROWTH"
		"str_growth_bonus":
			return "STRENGTH GROWTH"
		"mag_growth_bonus":
			return "MAGIC GROWTH"
		"def_growth_bonus":
			return "DEFENSE GROWTH"
		"res_growth_bonus":
			return "RESISTANCE GROWTH"
		"spd_growth_bonus":
			return "SPEED GROWTH"
		"agi_growth_bonus":
			return "AGILITY GROWTH"
		_:
			return growth_key.replace("_", " ").to_upper()

func _detailed_unit_info_primary_description(bar_key: String) -> String:
	match bar_key:
		"hp":
			return "Life total. If HP reaches 0, the unit is defeated or forced out of the fight."
		"poise":
			return "Stagger resistance. Higher Poise helps resist breaks, shock, and forced openings. It is usually improved by sturdier classes, defensive bonuses, certain gear, dragon effects, or traits."
		"xp":
			return "Current experience toward the next level, where the unit can gain stronger stats and improve overall combat power."
		_:
			return ""

func _populate_detailed_unit_info_weapon_row(unit: Node2D) -> void:
	if detailed_unit_info_weapon_badge == null or detailed_unit_info_weapon_name == null or detailed_unit_info_weapon_icon == null:
		return
	if unit == null or unit.get("equipped_weapon") == null:
		detailed_unit_info_weapon_badge.text = "--"
		detailed_unit_info_weapon_name.text = "UNARMED"
		detailed_unit_info_weapon_icon.texture = null
		return
	var weapon: WeaponData = unit.equipped_weapon as WeaponData
	if weapon == null:
		detailed_unit_info_weapon_badge.text = "--"
		detailed_unit_info_weapon_name.text = "UNARMED"
		detailed_unit_info_weapon_icon.texture = null
		return
	detailed_unit_info_weapon_badge.text = _forecast_weapon_marker(weapon)
	detailed_unit_info_weapon_name.text = String(weapon.weapon_name).to_upper()
	detailed_unit_info_weapon_icon.texture = weapon.icon

func _detailed_unit_info_growth_fill_color(stat_key: String, growth_value: int) -> Color:
	var base_key: String = stat_key.replace("_growth_bonus", "")
	if base_key == "str":
		return Color(0.92, 0.48, 0.36, 1.0)
	if base_key == "mag":
		return Color(0.82, 0.54, 0.98, 1.0)
	if base_key == "def":
		return Color(0.55, 0.89, 0.52, 1.0)
	if base_key == "res":
		return Color(0.40, 0.92, 0.88, 1.0)
	if base_key == "spd":
		return Color(0.44, 0.72, 0.98, 1.0)
	if base_key == "agi":
		return Color(0.95, 0.82, 0.43, 1.0)
	if base_key == "hp":
		return Color(0.48, 0.88, 0.55, 1.0)
	if growth_value < 0:
		return Color(0.84, 0.36, 0.32, 1.0)
	return TACTICAL_UI_ACCENT_SOFT

func _refresh_detailed_unit_info_growth_widgets(unit: Node2D, animate: bool, tween: Tween = null) -> void:
	if unit == null:
		return
	var class_res: Resource = unit.get("active_class_data") if unit.get("active_class_data") != null else null
	var index: int = 0
	for growth_key in [
		"hp_growth_bonus",
		"str_growth_bonus",
		"mag_growth_bonus",
		"def_growth_bonus",
		"res_growth_bonus",
		"spd_growth_bonus",
		"agi_growth_bonus",
	]:
		if not detailed_unit_info_growth_widgets.has(growth_key):
			continue
		var widgets: Dictionary = detailed_unit_info_growth_widgets[growth_key]
		var panel := widgets.get("panel") as Panel
		var name_label := widgets.get("name") as Label
		var value_chip := widgets.get("value_chip") as Panel
		var value_label := widgets.get("value") as Label
		var bar := widgets.get("bar") as ProgressBar
		var sheen := widgets.get("sheen") as ColorRect
		var label_text: String = _detailed_unit_info_growth_label(String(growth_key))
		var growth_value: int = 0
		if class_res != null and class_res.get(growth_key) != null:
			growth_value = int(class_res.get(growth_key))
		var fill_color := _detailed_unit_info_growth_fill_color(String(growth_key), growth_value)
		if name_label != null:
			name_label.text = label_text
			_style_tactical_label(name_label, fill_color, 15, 2)
		if value_chip != null:
			_style_tactical_panel(value_chip, Color(0.10, 0.09, 0.07, 0.98), fill_color.lightened(0.10), 1, 5)
		if value_label != null:
			value_label.text = "%+d%%" % growth_value
			_style_tactical_label(value_label, TACTICAL_UI_TEXT, 14, 1)
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if panel != null:
			_style_tactical_panel(panel, Color(0.10, 0.09, 0.07, 0.84), fill_color if growth_value != 0 else TACTICAL_UI_BORDER_MUTED, 1, 7)
		if bar != null:
			bar.max_value = 100.0
			bar.min_value = 0.0
			_style_unit_info_stat_bar(bar, fill_color, growth_value >= 50)
			var target: float = clampf(absf(float(growth_value)), 0.0, 100.0)
			if not animate:
				bar.value = target
			else:
				bar.value = 0.0
				var delay := 0.06 + float(index) * 0.03
				if panel != null:
					panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
					tween.tween_property(panel, "modulate", Color.WHITE, 0.14).set_delay(delay)
				tween.tween_property(bar, "value", target, 0.24).set_delay(delay)
				if sheen != null:
					_animate_unit_info_bar_sheen(sheen, bar, delay + 0.03)
		index += 1

func _build_detailed_unit_info_relationship_cards(unit: Node2D) -> void:
	if detailed_unit_info_relationships_root == null:
		return
	for child in detailed_unit_info_relationships_root.get_children():
		child.queue_free()
	if unit == null:
		return
	var unit_id: String = get_relationship_id(unit)
	var candidate_ids: Array = []
	if player_container != null:
		for ally in player_container.get_children():
			if is_instance_valid(ally) and ally != unit:
				candidate_ids.append(get_relationship_id(ally))
	var rel_entries: Array = CampaignManager.get_top_relationship_entries_for_unit(unit_id, candidate_ids, 6)
	if rel_entries.is_empty():
		var empty_label := Label.new()
		_style_tactical_label(empty_label, TACTICAL_UI_TEXT_MUTED, 16, 2)
		empty_label.text = "No notable bonds in this deployment yet."
		detailed_unit_info_relationships_root.add_child(empty_label)
		return

	for entry_raw in rel_entries:
		var entry: Dictionary = entry_raw as Dictionary
		var stat: String = str(entry.get("stat")) if entry.get("stat") != null else ""
		var value: int = int(entry.get("value")) if entry.get("value") != null else 0
		var formed: bool = bool(entry.get("formed")) if entry.get("formed") != null else false
		var partner_id: String = str(entry.get("partner_id")) if entry.get("partner_id") != null else "?"
		var tint: Color = CampaignManager.get_relationship_type_color(stat)
		var effect_hint: String = CampaignManager.get_relationship_effect_hint(stat, value)

		var card := Panel.new()
		card.custom_minimum_size = Vector2(0, 96)
		_style_tactical_panel(card, Color(0.11, 0.10, 0.08, 0.92), tint.lightened(0.08), 1, 9)
		detailed_unit_info_relationships_root.add_child(card)

		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		box.add_theme_constant_override("separation", 5)
		card.add_child(box)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 8)
		box.add_child(top_row)

		var partner_label := Label.new()
		partner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_tactical_label(partner_label, TACTICAL_UI_TEXT, 18, 2)
		partner_label.text = partner_id
		top_row.add_child(partner_label)

		var state_chip := Panel.new()
		state_chip.custom_minimum_size = Vector2(144, 28)
		_style_tactical_panel(state_chip, Color(0.10, 0.09, 0.07, 0.96), tint, 1, 6)
		top_row.add_child(state_chip)

		var state_label := Label.new()
		state_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
		_style_tactical_label(state_label, TACTICAL_UI_TEXT, 15, 2)
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		state_label.text = ("%s FORMED" % CampaignManager.get_relationship_type_display_name(stat).to_upper()) if formed else ("%s %d" % [CampaignManager.get_relationship_type_display_name(stat).to_upper(), value])
		state_chip.add_child(state_label)

		var hint_label := Label.new()
		_style_tactical_label(hint_label, tint.lightened(0.18), 16, 2)
		hint_label.text = effect_hint
		box.add_child(hint_label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 14)
		bar.max_value = 100.0
		bar.value = clampf(float(value), 0.0, 100.0)
		_style_unit_info_stat_bar(bar, tint, formed)
		box.add_child(bar)
		var sheen := _attach_unit_info_bar_sheen(bar)
		_animate_unit_info_bar_sheen(sheen, bar, 0.02)

func _refresh_detailed_unit_info_visuals(unit: Node2D, animate: bool = false) -> void:
	if unit == null:
		return
	if detailed_unit_info_anim_tween != null:
		detailed_unit_info_anim_tween.kill()
		detailed_unit_info_anim_tween = null

	var current_poise: int = 0
	var max_poise: int = 1
	if unit.has_method("get_current_poise") and unit.has_method("get_max_poise"):
		current_poise = int(unit.get_current_poise())
		max_poise = max(1, int(unit.get_max_poise()))
	elif unit.get("poise") != null:
		current_poise = int(unit.get("poise"))
		max_poise = max(1, int(unit.get("max_poise")) if unit.get("max_poise") != null else current_poise)

	var xp_current: int = int(unit.get("experience")) if unit.get("experience") != null else 0
	var xp_max: int = unit.get_exp_required() if unit.has_method("get_exp_required") else 100
	xp_max = max(1, xp_max)

	var current_hp: int = int(unit.get("current_hp")) if unit.get("current_hp") != null else 0
	var max_hp: int = max(1, int(unit.get("max_hp")) if unit.get("max_hp") != null else 1)
	var primary_rows: Dictionary = {
		"hp": {"current": current_hp, "max": max_hp, "text": "%d/%d" % [current_hp, max_hp]},
		"poise": {"current": current_poise, "max": max_poise, "text": "%d/%d" % [current_poise, max_poise]},
		"xp": {"current": xp_current, "max": xp_max, "text": "%d/%d" % [xp_current, xp_max]},
	}

	var primary_targets: Dictionary = {}
	for bar_def in _unit_info_primary_bar_definitions():
		var bar_key: String = str(bar_def.get("key", ""))
		if not detailed_unit_info_primary_widgets.has(bar_key):
			continue
		var row_data: Dictionary = primary_rows.get(bar_key, {})
		var current_value: int = int(row_data.get("current", 0))
		var max_value: int = max(1, int(row_data.get("max", 1)))
		var display_text: String = str(row_data.get("text", "%d/%d" % [current_value, max_value]))
		var fill_color := _unit_info_primary_fill_color(bar_key, current_value, max_value)
		var widgets: Dictionary = detailed_unit_info_primary_widgets[bar_key]
		var panel := widgets.get("panel") as Panel
		var name_label := widgets.get("name") as Label
		var hints_root := widgets.get("hints") as HBoxContainer
		var value_chip := widgets.get("value_chip") as Panel
		var value_label := widgets.get("value") as Label
		var bar := widgets.get("bar") as ProgressBar
		var desc_label := widgets.get("desc") as Label
		if panel != null:
			var panel_border := Color(min(fill_color.r + 0.08, 1.0), min(fill_color.g + 0.08, 1.0), min(fill_color.b + 0.08, 1.0), 0.76)
			var tinted_fill := Color(
				lerpf(0.10, fill_color.r, 0.10),
				lerpf(0.09, fill_color.g, 0.10),
				lerpf(0.07, fill_color.b, 0.10),
				0.92
			)
			_style_tactical_panel(panel, tinted_fill, panel_border, 1, 8)
		if name_label != null:
			name_label.text = str(bar_def.get("label", bar_key))
			_style_tactical_label(name_label, fill_color, 16, 2)
		if value_chip != null:
			_style_tactical_panel(value_chip, Color(0.10, 0.09, 0.07, 0.98), fill_color.lightened(0.10), 1, 6)
		if value_label != null:
			value_label.text = display_text
			_style_tactical_label(value_label, TACTICAL_UI_TEXT, 18, 2)
		if bar != null:
			bar.max_value = float(max_value)
			_style_unit_info_primary_bar(bar, fill_color, bar_key)
			primary_targets[bar_key] = float(clampf(float(current_value), 0.0, float(max_value)))
			if not animate:
				bar.value = primary_targets[bar_key]
		if desc_label != null:
			desc_label.text = _detailed_unit_info_primary_description(bar_key)
			_style_tactical_label(desc_label, TACTICAL_UI_TEXT_MUTED, 13, 1)

	var stat_targets: Dictionary = {}
	for stat_def in _unit_info_stat_definitions():
		var stat_key: String = str(stat_def.get("key", ""))
		if not detailed_unit_info_stat_widgets.has(stat_key):
			continue
		var raw_value: int = int(unit.get(stat_key)) if unit.get(stat_key) != null else 0
		var display_value: float = _unit_info_stat_display_value(raw_value)
		var fill_color := _unit_info_stat_fill_color(stat_key, raw_value)
		var overcap: bool = raw_value >= int(UNIT_INFO_STAT_BAR_CAP)
		var widgets: Dictionary = detailed_unit_info_stat_widgets[stat_key]
		var panel := widgets.get("panel") as Panel
		var name_label := widgets.get("name") as Label
		var hints_root := widgets.get("hints") as HBoxContainer
		var value_chip := widgets.get("value_chip") as Panel
		var value_label := widgets.get("value") as Label
		var bar := widgets.get("bar") as ProgressBar
		var desc_label := widgets.get("desc") as Label
		if panel != null:
			var tinted_fill := Color(
				lerpf(0.10, fill_color.r, 0.16),
				lerpf(0.09, fill_color.g, 0.16),
				lerpf(0.07, fill_color.b, 0.16),
				0.92
			)
			_style_tactical_panel(panel, tinted_fill, fill_color if overcap else fill_color.darkened(0.20), 1, 6)
		if name_label != null:
			name_label.text = _detailed_unit_info_stat_label(stat_key)
			_style_tactical_label(name_label, fill_color, 17, 2)
		if hints_root != null:
			for child in hints_root.get_children():
				child.queue_free()
			for spec in _detailed_unit_info_stat_hint_specs(stat_key):
				var chip := Panel.new()
				chip.custom_minimum_size = Vector2(52, 20)
				var chip_color: Color = spec.get("color", fill_color)
				_style_tactical_panel(chip, Color(0.10, 0.09, 0.07, 0.95), chip_color, 1, 5)
				hints_root.add_child(chip)

				var chip_label := Label.new()
				chip_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 1)
				_style_tactical_label(chip_label, chip_color, 10, 1)
				chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				chip_label.text = str(spec.get("text", ""))
				chip.add_child(chip_label)
		if value_chip != null:
			_style_tactical_panel(value_chip, Color(0.10, 0.09, 0.07, 0.98), fill_color, 1, 4)
		if value_label != null:
			value_label.text = str(raw_value)
			_style_tactical_label(value_label, TACTICAL_UI_TEXT, 16, 1)
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if bar != null:
			bar.max_value = UNIT_INFO_STAT_BAR_CAP
			_style_unit_info_stat_bar(bar, fill_color, overcap)
			stat_targets[stat_key] = display_value
			if not animate:
				bar.value = display_value
		if desc_label != null:
			desc_label.text = _detailed_unit_info_stat_description(stat_key)
			_style_tactical_label(desc_label, TACTICAL_UI_TEXT_MUTED, 13, 1)

	if not animate:
		_refresh_detailed_unit_info_growth_widgets(unit, false, null)
		return

	detailed_unit_info_anim_tween = create_tween().set_parallel(true)
	var primary_defs := _unit_info_primary_bar_definitions()
	for idx in range(primary_defs.size()):
		var bar_key: String = str(primary_defs[idx].get("key", ""))
		if not detailed_unit_info_primary_widgets.has(bar_key):
			continue
		var widgets: Dictionary = detailed_unit_info_primary_widgets[bar_key]
		var panel := widgets.get("panel") as Panel
		var bar := widgets.get("bar") as ProgressBar
		var desc_label := widgets.get("desc") as Label
		var sheen := widgets.get("sheen") as ColorRect
		var delay := float(idx) * 0.05
		if panel != null:
			panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
			detailed_unit_info_anim_tween.tween_property(panel, "modulate", Color.WHITE, 0.18).set_delay(delay)
		if bar != null:
			bar.value = 0.0
			detailed_unit_info_anim_tween.tween_property(bar, "value", float(primary_targets.get(bar_key, 0.0)), 0.30).set_delay(delay)
		if sheen != null and bar != null:
			_animate_unit_info_bar_sheen(sheen, bar, delay + 0.05)
		if desc_label != null:
			desc_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
			detailed_unit_info_anim_tween.tween_property(desc_label, "modulate", Color.WHITE, 0.16).set_delay(delay + 0.03)

	var stat_defs := _unit_info_stat_definitions()
	for idx in range(stat_defs.size()):
		var stat_key: String = str(stat_defs[idx].get("key", ""))
		if not detailed_unit_info_stat_widgets.has(stat_key):
			continue
		var widgets: Dictionary = detailed_unit_info_stat_widgets[stat_key]
		var panel := widgets.get("panel") as Panel
		var bar := widgets.get("bar") as ProgressBar
		var sheen := widgets.get("sheen") as ColorRect
		var delay := 0.16 + float(idx) * 0.04
		if panel != null:
			panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
			detailed_unit_info_anim_tween.tween_property(panel, "modulate", Color.WHITE, 0.16).set_delay(delay)
		if bar != null:
			bar.value = 0.0
			detailed_unit_info_anim_tween.tween_property(bar, "value", float(stat_targets.get(stat_key, 0.0)), 0.24).set_delay(delay)
			if sheen != null and bar != null:
				_animate_unit_info_bar_sheen(sheen, bar, delay + 0.04)
		var desc_label := widgets.get("desc") as Label
		if desc_label != null:
			desc_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
			detailed_unit_info_anim_tween.tween_property(desc_label, "modulate", Color.WHITE, 0.18).set_delay(delay + 0.03)

	_refresh_detailed_unit_info_growth_widgets(unit, animate, detailed_unit_info_anim_tween)

	detailed_unit_info_anim_tween.finished.connect(func():
		detailed_unit_info_anim_tween = null
	, CONNECT_ONE_SHOT)
	
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
	var class_res: Resource = null
	if unit.get("active_class_data") != null:
		class_res = unit.active_class_data

	lines.append("[color=gold]Class Profile[/color]")
	lines.append("Class: [color=cyan]%s[/color]" % _resolve_detailed_unit_info_class_label(unit))
	lines.append("Move: %d" % (int(unit.get("move_range")) if unit.get("move_range") != null else 0))
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
		lines.append("")

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

func _build_detailed_unit_info_record_text(unit: Node2D) -> String:
	if unit == null:
		return ""

	var lines: Array[String] = []
	var class_res: Resource = unit.get("active_class_data") if unit.get("active_class_data") != null else null

	lines.append("[color=gold]Field Doctrine[/color]")
	lines.append("Class: [color=cyan]%s[/color]" % _resolve_detailed_unit_info_class_label(unit))
	lines.append("Move: %d" % (int(unit.get("move_range")) if unit.get("move_range") != null else 0))
	lines.append("")

	if class_res != null:
		lines.append("[color=gold]Weapon Permissions[/color]")
		lines.append(_format_class_weapon_permissions(class_res))
		lines.append("")

		lines.append("[color=gold]Class Bonuses[/color]")
		var class_bonus_parts: Array[String] = []
		for pair in [
			["hp_bonus", "HP", ""],
			["str_bonus", "STR", "coral"],
			["mag_bonus", "MAG", "orchid"],
			["def_bonus", "DEF", "palegreen"],
			["res_bonus", "RES", "aquamarine"],
			["spd_bonus", "SPD", "skyblue"],
			["agi_bonus", "AGI", "wheat"],
		]:
			var key: String = String(pair[0])
			if class_res.get(key) == null or int(class_res.get(key)) == 0:
				continue
			var chunk: String = "%s %+d" % [String(pair[1]), int(class_res.get(key))]
			var tint: String = String(pair[2])
			class_bonus_parts.append(chunk if tint == "" else "[color=%s]%s[/color]" % [tint, chunk])
		lines.append("None" if class_bonus_parts.is_empty() else ", ".join(class_bonus_parts))
		lines.append("")

		lines.append("[color=gold]Promotion Bonuses[/color]")
		var promo_parts: Array[String] = []
		for pair in [
			["promo_hp_bonus", "HP", ""],
			["promo_str_bonus", "STR", "coral"],
			["promo_mag_bonus", "MAG", "orchid"],
			["promo_def_bonus", "DEF", "palegreen"],
			["promo_res_bonus", "RES", "aquamarine"],
			["promo_spd_bonus", "SPD", "skyblue"],
			["promo_agi_bonus", "AGI", "wheat"],
		]:
			var key: String = String(pair[0])
			if class_res.get(key) == null or int(class_res.get(key)) == 0:
				continue
			var chunk: String = "%s %+d" % [String(pair[1]), int(class_res.get(key))]
			var tint: String = String(pair[2])
			promo_parts.append(chunk if tint == "" else "[color=%s]%s[/color]" % [tint, chunk])
		lines.append("None" if promo_parts.is_empty() else ", ".join(promo_parts))
		lines.append("")

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
				var w_type: String = _weapon_type_name_safe(int(item.weapon_type))
				var extra: String = " | Mt " + str(item.might) + " | Hit +" + str(item.hit_bonus) + " | Rng " + str(item.min_range) + "-" + str(item.max_range)
				lines.append("- " + str(item_name) + " (" + w_type + ")" + marker)
				lines.append("  " + extra)
			else:
				lines.append("- " + str(item_name))
	else:
		lines.append("None")

	lines.append("")
	lines.append("[color=gold]Notes[/color]")
	lines.append("Growth outlook and bond cards are surfaced above.")
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
