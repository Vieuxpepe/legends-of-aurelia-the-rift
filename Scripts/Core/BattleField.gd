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
const SupportRelationshipHelpers = preload("res://Scripts/Core/BattleField/BattleFieldSupportRelationshipHelpers.gd")
const InventoryUiHelpers = preload("res://Scripts/Core/BattleField/BattleFieldInventoryUiHelpers.gd")
const DrawHelpers = preload("res://Scripts/Core/BattleField/BattleFieldDrawHelpers.gd")
const PathCursorHelpers = preload("res://Scripts/Core/BattleField/BattleFieldPathfindingCursorHelpers.gd")
const PathPreviewHelpers = preload("res://Scripts/Core/BattleField/BattleFieldPathPreviewHelpers.gd")
const CameraFxHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCameraFxHelpers.gd")
const TradeInventoryHelpers = preload("res://Scripts/Core/BattleField/BattleFieldTradeInventoryHelpers.gd")
const CombatOrchestrationHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCombatOrchestrationHelpers.gd")
const InventoryActionHelpers = preload("res://Scripts/Core/BattleField/BattleFieldInventoryActionHelpers.gd")
const InventoryTradeFlowHelpers = preload("res://Scripts/Core/BattleField/BattleFieldInventoryTradeFlowHelpers.gd")
const PromotionChoiceUiHelpers = preload("res://Scripts/Core/BattleField/BattleFieldPromotionChoiceUiHelpers.gd")
const PromotionVfxHelpers = preload("res://Scripts/Core/BattleField/BattleFieldPromotionVfxHelpers.gd")
const ObjectiveUiHelpers = preload("res://Scripts/Core/BattleField/BattleFieldObjectiveUiHelpers.gd")
const CinematicDialogueHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCinematicDialogueHelpers.gd")
const MinimapHelpers = preload("res://Scripts/Core/BattleField/BattleFieldMinimapHelpers.gd")
const StatusIconVfxHelpers = preload("res://Scripts/Core/BattleField/BattleFieldStatusIconVfxHelpers.gd")
const CombatVfxHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCombatVfxHelpers.gd")
const GoldVfxHelpers = preload("res://Scripts/Core/BattleField/BattleFieldGoldVfxHelpers.gd")
const TurnOrchestrationHelpers = preload("res://Scripts/Core/BattleField/BattleFieldTurnOrchestrationHelpers.gd")
const BattleFieldTurnFlowHelpers = preload("res://Scripts/Core/BattleField/BattleFieldTurnFlowHelpers.gd")
const TacticalHudLayoutHelpers = preload("res://Scripts/Core/BattleField/BattleFieldTacticalHudLayoutHelpers.gd")
const DefensiveReactionHelpers = preload("res://Scripts/Core/BattleField/BattleFieldDefensiveReactionHelpers.gd")
const BattleFieldQteMinigameHelpers = preload("res://Scripts/Core/BattleField/BattleFieldQteMinigameHelpers.gd")
const BattleFieldGridRangeHelpers = preload("res://Scripts/Core/BattleField/BattleFieldGridRangeHelpers.gd")
const DetailedUnitInfoHelpers = preload("res://Scripts/Core/BattleField/BattleFieldDetailedUnitInfoHelpers.gd")
const DetailedUnitInfoRuntimeHelpers = preload("res://Scripts/Core/BattleField/BattleFieldDetailedUnitInfoRuntimeHelpers.gd")
const DetailedUnitInfoContentHelpers = preload("res://Scripts/Core/BattleField/BattleFieldDetailedUnitInfoContentHelpers.gd")
const DialogueInteractionHelpers = preload("res://Scripts/Core/BattleField/BattleFieldDialogueInteractionHelpers.gd")
const LevelUpPresentationHelpers = preload("res://Scripts/Core/BattleField/BattleFieldLevelUpPresentationHelpers.gd")
const BattleEndFlowHelpers = preload("res://Scripts/Core/BattleField/BattleFieldBattleEndFlowHelpers.gd")
const BattleResultPresentationHelpers = preload("res://Scripts/Core/BattleField/BattleFieldBattleResultPresentationHelpers.gd")
const CampaignSetupHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCampaignSetupHelpers.gd")
const BattleFieldStartupHelpers = preload("res://Scripts/Core/BattleField/BattleFieldStartupHelpers.gd")
const BattleFieldSpecialModeSetupHelpers = preload("res://Scripts/Core/BattleField/BattleFieldSpecialModeSetupHelpers.gd")
const DefensiveReactionFlowHelpers = preload("res://Scripts/Core/BattleField/BattleFieldDefensiveReactionFlowHelpers.gd")
const DefensiveAbilityFlowHelpers = preload("res://Scripts/Core/BattleField/BattleFieldDefensiveAbilityFlowHelpers.gd")
const AttackResolutionHelpers = preload("res://Scripts/Core/BattleField/BattleFieldAttackResolutionHelpers.gd")
const PostStrikeCleanupHelpers = preload("res://Scripts/Core/BattleField/BattleFieldPostStrikeCleanupHelpers.gd")
const ForcedMovementTacticalHelpers = preload("res://Scripts/Core/BattleField/BattleFieldForcedMovementTacticalHelpers.gd")
const CombatCleanupHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCombatCleanupHelpers.gd")
const StrikeSequenceHelpers = preload("res://Scripts/Core/BattleField/BattleFieldStrikeSequenceHelpers.gd")
const CombatForecastHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCombatForecastHelpers.gd")
const CombatForecastFlowHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCombatForecastFlowHelpers.gd")
const CoopCombatRequestHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopCombatRequestHelpers.gd")
const CoopEnemyCombatNetHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopEnemyCombatNetHelpers.gd")
const CoopOutboundSyncHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopOutboundSyncHelpers.gd")
const CoopRemoteSyncActionHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopRemoteSyncActionHelpers.gd")
const CoopRngSyncHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopRngSyncHelpers.gd")
const CoopMockSessionHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopMockSessionHelpers.gd")
const CoopBattleRuntimeHelpers = preload("res://Scripts/Core/BattleField/BattleFieldCoopBattleRuntimeHelpers.gd")
const BattleFieldFogOfWarHelpers = preload("res://Scripts/Core/BattleField/BattleFieldFogOfWarHelpers.gd")

# Character-creation passives (not Shove/Grapple). Forecast tactical button can show class_tactical_ability (e.g. Fire Sage â†’ Fire Trap).
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

@export_category("Hazards â€” Fire tiles")
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
var _impact_snap_tween: Tween
var _screen_shake_tween: Tween

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
	CoopBattleRuntimeHelpers.capture_enemy_death_loot_for_sync(self, source_unit, total_gold, items, recipient)


func _coop_apply_remote_synced_enemy_death_loot_events(raw: Variant) -> void:
	CoopBattleRuntimeHelpers.apply_remote_synced_enemy_death_loot_events(self, raw)


func _coop_build_runtime_unit_wire_snapshot(unit: Node2D) -> Dictionary:
	return CoopBattleRuntimeHelpers.build_runtime_unit_wire_snapshot(self, unit)


func _coop_instantiate_runtime_unit_from_snapshot(entry: Dictionary, target_parent: Node) -> Node2D:
	return CoopBattleRuntimeHelpers.instantiate_runtime_unit_from_snapshot(self, entry, target_parent)


func _coop_apply_runtime_unit_wire_snapshot(entry: Dictionary, target_parent: Node) -> Node2D:
	return CoopBattleRuntimeHelpers.apply_runtime_unit_wire_snapshot(self, entry, target_parent)


func _coop_build_enemy_phase_setup_snapshot() -> Dictionary:
	return CoopBattleRuntimeHelpers.build_enemy_phase_setup_snapshot(self)


func _coop_apply_enemy_phase_setup_snapshot(snap: Dictionary) -> void:
	CoopBattleRuntimeHelpers.apply_enemy_phase_setup_snapshot(self, snap)


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


## Call immediately before [method execute_combat] on the attackerâ€™s machine. Returns packed id for the wire (guest vs host ranges avoid collisions).
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
	return CoopBattleRuntimeHelpers.snapshot_alive_unit_ids(self)


func _coop_clear_unit_grid_solidity(u: Node2D) -> void:
	CoopBattleRuntimeHelpers.clear_unit_grid_solidity(self, u)


func _coop_set_unit_grid_solidity(u: Node2D, solid: bool) -> void:
	CoopBattleRuntimeHelpers.set_unit_grid_solidity(self, u, solid)


## Build after local [method execute_combat] completes; peer applies with [method _coop_apply_authoritative_combat_snapshot] (skips re-simulation).
func coop_net_build_authoritative_combat_snapshot(pre_alive_ids: Dictionary) -> Dictionary:
	return CoopHelpers.coop_net_build_authoritative_combat_snapshot(self, pre_alive_ids)


func _coop_remove_unit_coop_peer_mirror_by_id(rid: String) -> void:
	CoopBattleRuntimeHelpers.remove_unit_coop_peer_mirror_by_id(self, rid)


func _coop_apply_authoritative_combat_snapshot(snap: Dictionary) -> void:
	CoopHelpers.coop_apply_authoritative_combat_snapshot(self, snap)


func is_coop_remote_combat_replay_active() -> bool:
	return _coop_remote_combat_replay_active


func _coop_execute_remote_combat_replay(attacker: Node2D, defender: Node2D, used_ability: bool, qte_snapshot: Variant, rng_packed: int = -1) -> void:
	await CoopBattleRuntimeHelpers.execute_remote_combat_replay(self, attacker, defender, used_ability, qte_snapshot, rng_packed)


func _coop_validate_authoritative_post_combat_outcome() -> void:
	CoopBattleRuntimeHelpers.validate_authoritative_post_combat_outcome(self)


## ENet co-op: host allocates [method coop_enet_begin_synchronized_combat_round] + runs combat, then broadcasts; guest waits FIFO and mirrors (crit/miss match).
func coop_enet_buffer_incoming_enemy_combat(body: Dictionary) -> void:
	CoopEnemyCombatNetHelpers.coop_enet_buffer_incoming_enemy_combat(self, body)


func coop_enet_ai_execute_combat(attacker: Node2D, defender: Node2D, used_ability: bool = false) -> void:
	await CoopEnemyCombatNetHelpers.coop_enet_ai_execute_combat(self, attacker, defender, used_ability)


## True when this peer is the ENet guest with battle RNG locked â€” player-initiated combat must be simulated on the host only.
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
	return CoopBattleRuntimeHelpers.find_player_side_unit_by_relationship_id(self, rid)


func _coop_find_unit_by_relationship_id_any_side(rid: String) -> Node2D:
	return CoopBattleRuntimeHelpers.find_unit_by_relationship_id_any_side(self, rid)


func _coop_run_one_remote_sync_async(body: Dictionary) -> void:
	await CoopRemoteSyncActionHelpers.coop_run_one_remote_sync_async(self, body)


func _coop_wait_for_enemy_state_ready() -> void:
	await CoopBattleRuntimeHelpers.wait_for_enemy_state_ready(self)


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
	InventoryTradeFlowHelpers.resolve_inventory_ui_nodes(self)

func _stylebox_bump_all_content_margins(sb: StyleBox, delta: float) -> void:
	InventoryTradeFlowHelpers.stylebox_bump_all_content_margins(sb, delta)

func _inventory_scroll_apply_content_padding(scroll: ScrollContainer, pad: int) -> void:
	InventoryTradeFlowHelpers.inventory_scroll_apply_content_padding(scroll, pad)

func _style_inventory_item_info_backdrop(info_bg: Panel) -> void:
	InventoryTradeFlowHelpers.style_inventory_item_info_backdrop(self, info_bg)

func _apply_inventory_panel_spacing() -> void:
	InventoryUiHelpers.apply_inventory_panel_spacing(self)

func _apply_inventory_panel_item_list_extra_margins(inv_item_list: ItemList) -> void:
	InventoryTradeFlowHelpers.apply_inventory_panel_item_list_extra_margins(self, inv_item_list)

func _resolve_loot_ui_nodes() -> void:
	BattleResultPresentationHelpers.resolve_loot_ui_nodes(self)

func _layout_loot_item_info_backdrop() -> void:
	BattleResultPresentationHelpers.layout_loot_item_info_backdrop(self)

func _ensure_loot_item_info_ui() -> void:
	BattleResultPresentationHelpers.ensure_loot_item_info_ui(self)

func _queue_refit_item_description_panels() -> void:
	InventoryTradeFlowHelpers.queue_refit_item_description_panels(self)

func _refit_loot_description_panel_height() -> void:
	BattleResultPresentationHelpers.refit_loot_description_panel_height(self)

func _refit_inventory_description_panel_height() -> void:
	InventoryTradeFlowHelpers.refit_inventory_description_panel_height(self)

func _unit_info_primary_bar_definitions() -> Array[Dictionary]:
	return DetailedUnitInfoRuntimeHelpers.unit_info_primary_bar_definitions()


func _unit_info_primary_fill_color(bar_key: String, current_value: int, max_value: int) -> Color:
	return DetailedUnitInfoRuntimeHelpers.unit_info_primary_fill_color(self, bar_key, current_value, max_value)


func _style_unit_info_primary_bar(bar: ProgressBar, fill: Color, bar_key: String = "") -> void:
	DetailedUnitInfoRuntimeHelpers.style_unit_info_primary_bar(self, bar, fill, bar_key)


func _attach_unit_info_bar_sheen(bar: ProgressBar) -> ColorRect:
	return DetailedUnitInfoRuntimeHelpers.attach_unit_info_bar_sheen(self, bar)


func _animate_unit_info_bar_sheen(sheen: ColorRect, bar: ProgressBar, delay: float = 0.0) -> void:
	DetailedUnitInfoRuntimeHelpers.animate_unit_info_bar_sheen(self, sheen, bar, delay)


func _ensure_unit_info_primary_widgets() -> Control:
	return DetailedUnitInfoRuntimeHelpers.ensure_unit_info_primary_widgets(self)


func _layout_unit_info_primary_widgets() -> void:
	DetailedUnitInfoRuntimeHelpers.layout_unit_info_primary_widgets(self)


func _set_unit_info_primary_widgets_visible(visible: bool) -> void:
	DetailedUnitInfoRuntimeHelpers.set_unit_info_primary_widgets_visible(self, visible)


func _animate_unit_info_primary_widgets_in(target_values: Dictionary, source_id: int) -> void:
	DetailedUnitInfoRuntimeHelpers.animate_unit_info_primary_widgets_in(self, target_values, source_id)


func _refresh_unit_info_primary_widgets(primary_values: Dictionary, animate: bool = false, source_id: int = -1) -> void:
	DetailedUnitInfoRuntimeHelpers.refresh_unit_info_primary_widgets(self, primary_values, animate, source_id)


func _unit_info_stat_tier_index(stat_value: int) -> int:
	return DetailedUnitInfoRuntimeHelpers.unit_info_stat_tier_index(self, stat_value)


func _unit_info_stat_definitions() -> Array[Dictionary]:
	return DetailedUnitInfoRuntimeHelpers.unit_info_stat_definitions()


func _unit_info_stat_fill_color(stat_key: String, stat_value: int) -> Color:
	return DetailedUnitInfoRuntimeHelpers.unit_info_stat_fill_color(self, stat_key, stat_value)


func _style_unit_info_stat_bar(bar: ProgressBar, fill: Color, overcap: bool) -> void:
	DetailedUnitInfoRuntimeHelpers.style_unit_info_stat_bar(self, bar, fill, overcap)


func _ensure_unit_info_stat_fx_nodes(block: Panel) -> void:
	DetailedUnitInfoRuntimeHelpers.ensure_unit_info_stat_fx_nodes(self, block)


func _get_unit_info_stat_arcs_root(block: Panel) -> Control:
	return DetailedUnitInfoRuntimeHelpers.get_unit_info_stat_arcs_root(self, block)


func _position_unit_info_stat_fx_nodes(block: Panel) -> void:
	DetailedUnitInfoRuntimeHelpers.position_unit_info_stat_fx_nodes(self, block)


func _stop_unit_info_stat_tier_fx(block: Panel) -> void:
	DetailedUnitInfoRuntimeHelpers.stop_unit_info_stat_tier_fx(self, block)


func _unit_info_stat_arc_count_for_tier(tier: int) -> int:
	return DetailedUnitInfoRuntimeHelpers.unit_info_stat_arc_count_for_tier(tier)


func _unit_info_stat_arc_perimeter_length(field_size: Vector2) -> float:
	return DetailedUnitInfoRuntimeHelpers.unit_info_stat_arc_perimeter_length(field_size)


func _unit_info_stat_arc_perimeter_point(field_size: Vector2, raw_offset: float) -> Vector2:
	return DetailedUnitInfoRuntimeHelpers.unit_info_stat_arc_perimeter_point(field_size, raw_offset)


func _unit_info_stat_arc_perimeter_normal(field_size: Vector2, raw_offset: float) -> Vector2:
	return DetailedUnitInfoRuntimeHelpers.unit_info_stat_arc_perimeter_normal(field_size, raw_offset)


func _set_unit_info_stat_arc_progress(progress: float, arc: ColorRect, field_size: Vector2, segment_length: float, tier: int, phase: float, clockwise: bool) -> void:
	DetailedUnitInfoRuntimeHelpers.set_unit_info_stat_arc_progress(progress, arc, field_size, segment_length, tier, phase, clockwise)


func _play_unit_info_stat_tier_flash(block: Panel, tier: int, color: Color) -> void:
	DetailedUnitInfoRuntimeHelpers.play_unit_info_stat_tier_flash(self, block, tier, color)


func _start_unit_info_stat_tier_loop(block: Panel, tier: int, color: Color) -> void:
	DetailedUnitInfoRuntimeHelpers.start_unit_info_stat_tier_loop(self, block, tier, color)


func _play_unit_info_stat_tier_fx(block: Panel, tier: int, color: Color) -> void:
	DetailedUnitInfoRuntimeHelpers.play_unit_info_stat_tier_fx(self, block, tier, color)


func _ensure_unit_info_stat_widgets() -> Control:
	return DetailedUnitInfoRuntimeHelpers.ensure_unit_info_stat_widgets(self)


func _layout_unit_info_stat_widgets() -> void:
	DetailedUnitInfoRuntimeHelpers.layout_unit_info_stat_widgets(self)


func _set_unit_info_stat_widgets_visible(visible: bool) -> void:
	DetailedUnitInfoRuntimeHelpers.set_unit_info_stat_widgets_visible(self, visible)


func _unit_info_stat_display_value(raw_value: int) -> float:
	return DetailedUnitInfoRuntimeHelpers.unit_info_stat_display_value(self, raw_value)


func _animate_unit_info_stat_widgets_in(display_values: Dictionary, source_id: int) -> void:
	DetailedUnitInfoRuntimeHelpers.animate_unit_info_stat_widgets_in(self, display_values, source_id)


func _refresh_unit_info_stat_widgets(stat_values: Dictionary, animate: bool = false, source_id: int = -1) -> void:
	DetailedUnitInfoRuntimeHelpers.refresh_unit_info_stat_widgets(self, stat_values, animate, source_id)


func _style_forecast_hp_bar(bar: ProgressBar, fill: Color) -> void:
	CombatForecastHelpers.style_forecast_hp_bar(self, bar, fill)

func _forecast_hp_fill_color(current_hp: int, max_hp: int) -> Color:
	return CombatForecastHelpers.forecast_hp_fill_color(current_hp, max_hp)

func _truncate_forecast_text(text: String, max_chars: int) -> String:
	return CombatForecastHelpers.truncate_forecast_text(text, max_chars)

func _format_forecast_name(prefix: String, unit_name: String, max_name_chars: int = 14) -> String:
	return CombatForecastHelpers.format_forecast_name(prefix, unit_name, max_name_chars)

func _format_forecast_name_fitted(prefix: String, unit_name: String, max_total_chars: int = 18) -> String:
	return CombatForecastHelpers.format_forecast_name_fitted(prefix, unit_name, max_total_chars)

func _forecast_weapon_marker(weapon: WeaponData) -> String:
	return CombatForecastHelpers.forecast_weapon_marker(weapon)

func _format_forecast_weapon_text(weapon: WeaponData) -> String:
	return CombatForecastHelpers.format_forecast_weapon_text(weapon)

func _format_forecast_weapon_name(weapon: WeaponData, max_chars: int = 14) -> String:
	return CombatForecastHelpers.format_forecast_weapon_name(weapon, max_chars)

func _forecast_weapon_rarity_glow_color(weapon: WeaponData) -> Color:
	return CombatForecastHelpers.forecast_weapon_rarity_glow_color(weapon)

func _style_forecast_weapon_glow(glow_panel: Panel, glow_color: Color) -> void:
	CombatForecastHelpers.style_forecast_weapon_glow(glow_panel, glow_color)

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
	CombatForecastHelpers.ensure_forecast_hp_bars(self)

func _ensure_forecast_weapon_badges() -> void:
	CombatForecastHelpers.ensure_forecast_weapon_badges(self)

func _ensure_forecast_weapon_pair_frames() -> void:
	CombatForecastHelpers.ensure_forecast_weapon_pair_frames(self)

func _ensure_forecast_weapon_icons() -> void:
	CombatForecastHelpers.ensure_forecast_weapon_icons(self)

func _reset_forecast_emphasis_visuals() -> void:
	CombatForecastHelpers.reset_forecast_emphasis_visuals(self)

func _start_forecast_emphasis_pulse(attacker_lethal: bool, defender_lethal: bool, attacker_crit_ready: bool, defender_crit_ready: bool) -> void:
	CombatForecastHelpers.start_forecast_emphasis_pulse(self, attacker_lethal, defender_lethal, attacker_crit_ready, defender_crit_ready)

func _set_unit_portrait_block_visible(show: bool) -> void:
	if unit_portrait != null:
		unit_portrait.visible = show
	if unit_info_panel != null:
		var portrait_frame := unit_info_panel.get_node_or_null("PortraitFrame") as Panel
		if portrait_frame != null:
			portrait_frame.visible = show

func _apply_tactical_ui_overhaul() -> void:
	TacticalHudLayoutHelpers.apply_tactical_ui_overhaul(self)


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
	return BattleFieldTurnFlowHelpers.mock_coop_unit_ownership_bbcode_line_for_panel(self, unit)


## Mock co-op + player phase: fielded local/partner counts (valid=false otherwise).
func _get_mock_coop_player_phase_detachment_counts() -> Dictionary:
	return BattleFieldTurnFlowHelpers.get_mock_coop_player_phase_detachment_counts(self)


## True when mock co-op player phase: all local fielded units have acted, partner fielded units remain (placeholder partner-turn gate).
func is_mock_partner_placeholder_active() -> bool:
	return BattleFieldTurnFlowHelpers.is_mock_partner_placeholder_active(self)


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


## Player phase only: BBCode for objective panel â€” local-owned, fielded, alive units; ready = not is_exhausted.
func _build_mock_coop_player_phase_readiness_bbcode_suffix() -> String:
	return BattleFieldTurnFlowHelpers.build_mock_coop_player_phase_readiness_bbcode_suffix(self)


func _update_skip_button_visual_modulate() -> void:
	BattleFieldTurnFlowHelpers.update_skip_button_visual_modulate(self)


func _is_mock_coop_deployed_player_side_unit(unit: Node) -> bool:
	return BattleFieldTurnFlowHelpers.is_mock_coop_deployed_player_side_unit(self, unit)


func _get_mock_coop_deployed_player_side_unit_nodes() -> Array:
	return BattleFieldTurnFlowHelpers.get_mock_coop_deployed_player_side_unit_nodes(self)


## All player-side units in tree order (player_container then ally_container), including benched/hidden â€” for locked mock co-op meta.
func _iter_all_player_side_unit_nodes_for_mock_coop() -> Array:
	return BattleFieldTurnFlowHelpers.iter_all_player_side_unit_nodes_for_mock_coop(self)


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
			print("[MockCoopOwnership] skipped (mock context not valid â€” no unit ownership assigned)")
		return
	var assign_raw: Variant = _consumed_mock_coop_battle_handoff.get("mock_detachment_assignment", {})
	if typeof(assign_raw) == TYPE_DICTIONARY and not (assign_raw as Dictionary).is_empty() and _mock_coop_battle_context.has_locked_mock_detachment_assignment():
		_apply_mock_coop_locked_detachment_assignment(assign_raw as Dictionary)
		return
	push_warning("[MockCoopOwnership] mock_detachment_assignment missing or not locked â€” using DEPRECATED fielded visible-unit order fallback.")
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
			print("[MockCoopOwnership] unlisted id '%s' â€” PARTNER command (not in charter lock)" % rid)
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


## Deprecated: visible fielded units only, first ceil(n/2) local â€” used only when handoff lacks a valid locked assignment.
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
	BattleFieldStartupHelpers.present_mock_coop_joint_expedition_charter(self)


var _ui_sfx_block_until_msec := 0
var _tactical_ui_resize_hooked: bool = false

func _ready() -> void:
	BattleFieldStartupHelpers.on_ready(self)

func _process(delta: float) -> void:
	TurnOrchestrationHelpers.process(self, delta)

func _handle_camera_panning(delta: float) -> void:
	CameraFxHelpers.handle_camera_panning(self, delta)

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


## End-of-round burn for units with meta is_burning (Hellfire ignite). Uses RESISTANCE only â€” no attacker for EXP.
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
	BattleEndFlowHelpers.remove_dead_player_dragon(self, unit)


func _on_unit_died(unit: Node2D, killer: Node2D) -> void:
	BattleEndFlowHelpers.on_unit_died(self, unit, killer)


func trigger_game_over(result: String) -> void:
	BattleEndFlowHelpers.trigger_game_over(self, result)


func _on_restart_button_pressed() -> void:
	BattleEndFlowHelpers.on_restart_button_pressed(self)




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
	PathPreviewHelpers.init_path_preview_nodes(self)


func _hide_path_preview_visuals() -> void:
	PathPreviewHelpers.hide_path_preview_visuals(self)


func _cell_center_world(cell: Vector2i) -> Vector2:
	return PathPreviewHelpers.cell_center_world(self, cell)


func _single_step_enter_cost(unit: Node2D, cell: Vector2i) -> float:
	return PathPreviewHelpers.single_step_enter_cost(self, unit, cell)


func _chamfer_world_polyline(pts: PackedVector2Array, inset: float) -> PackedVector2Array:
	return PathPreviewHelpers.chamfer_world_polyline(pts, inset)


func _grid_path_to_world_polyline(path: Array, unit: Node2D) -> PackedVector2Array:
	return PathPreviewHelpers.grid_path_to_world_polyline(self, path, unit)


func _gather_path_cost_ticks(path: Array, unit: Node2D) -> void:
	PathPreviewHelpers.gather_path_cost_ticks(self, path, unit)


func _ensure_path_fg_dash_material() -> ShaderMaterial:
	return PathPreviewHelpers.ensure_path_fg_dash_material(self)


func _apply_path_preview_style(ghost: bool, canto: bool) -> void:
	PathPreviewHelpers.apply_path_preview_style(self, ghost, canto)


func _update_path_endpoint_marker(path: Array, ghost: bool, canto: bool) -> void:
	PathPreviewHelpers.update_path_endpoint_marker(self, path, ghost, canto)

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
	return BattleFieldGridRangeHelpers.get_unit_at(self, pos)


## One step from `from_cell` toward `to_cell` on the grid (-1/0/1 each axis). Zero if cells coincide.
func _attack_line_step(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	return BattleFieldGridRangeHelpers.attack_line_step(from_cell, to_cell)



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


## ClassData.MoveType: FLYING = 2, CAVALRY = 3 â€” only these get post-action Canto (leftover move, no second attack).
func unit_supports_canto(unit: Node2D) -> bool:
	if unit == null:
		return false
	var mt: Variant = unit.get("move_type")
	return mt == 2 or mt == 3


func rebuild_grid() -> void:
	BattleFieldGridRangeHelpers.rebuild_grid(self)


func get_occupant_at(pos: Vector2i) -> Node2D:
	return BattleFieldGridRangeHelpers.get_occupant_at(self, pos)


func _unit_footprint_tiles(unit: Node2D) -> Array[Vector2i]:
	return BattleFieldGridRangeHelpers.unit_footprint_tiles(self, unit)


func _danger_overlay_cell_drawable(cell: Vector2i) -> bool:
	return BattleFieldGridRangeHelpers.danger_overlay_cell_drawable(self, cell)


func _attack_has_clear_los(from_tile: Vector2i, to_tile: Vector2i) -> bool:
	return BattleFieldGridRangeHelpers.attack_has_clear_los(self, from_tile, to_tile)


func clear_ranges() -> void:
	BattleFieldGridRangeHelpers.clear_ranges(self)


func calculate_ranges(unit: Node2D) -> void:
	BattleFieldGridRangeHelpers.calculate_ranges(self, unit)


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
				obj_label.text = "- Turn " + str(current_turn) + " â€” " + custom_obj + " -"
			else:
				obj_label.text = "- Turn " + str(current_turn) + " : Rout the Enemy -"
		Objective.SURVIVE_TURNS:
			if custom_obj != "":
				obj_label.text = "- " + custom_obj + " (" + str(current_turn) + " / " + str(turn_limit) + ") -"
			else:
				obj_label.text = "- Survive: Turn " + str(current_turn) + " / " + str(turn_limit) + " -"
		Objective.DEFEND_TARGET:
			if custom_obj != "":
				obj_label.text = "- " + custom_obj + " â€” Turn " + str(current_turn) + " / " + str(turn_limit) + " -"
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
				active_tag = " [Moved â€” act]"
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
		add_combat_log(attacker.unit_name + ": Blank Slate â€” sharp instincts! (+Hit this battle)", "cyan")
	elif r == 1:
		attacker.set_meta(META_ROOKIE_NOVICE_DMG, 4)
		add_combat_log(attacker.unit_name + ": Blank Slate â€” raw power! (+Damage this battle)", "cyan")
	else:
		attacker.set_meta(META_ROOKIE_NOVICE_CRIT, 8)
		add_combat_log(attacker.unit_name + ": Blank Slate â€” lucky streak! (+Crit this battle)", "cyan")


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
	return await CombatForecastFlowHelpers.show_combat_forecast(self, attacker, defender)

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
# ðŸ¤– AI / DEVELOPER INSTRUCTIONS: HOW TO ADD NEW COMBAT ABILITIES ðŸ¤–
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
# ðŸ¤– AI / DEVELOPER INSTRUCTIONS: HOW TO ADD NEW COMBAT ABILITIES USING COOLDOWNS
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
	CameraFxHelpers.screen_shake(self, intensity, duration)


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
	InventoryTradeFlowHelpers.on_convoy_pressed(self)

func _on_open_inv_pressed() -> void:
	InventoryTradeFlowHelpers.on_open_inv_pressed(self)

func _populate_convoy_list() -> void:
	TradeInventoryHelpers.populate_convoy_list(self)

func _populate_unit_inventory_list() -> void:
	InventoryUiHelpers.populate_unit_inventory_list(self)

func _clear_grids() -> void:
	TradeInventoryHelpers.clear_grids(self)

func _build_grid_items(grid: GridContainer, item_array: Array, source_type: String, owner_unit: Node2D = null, min_slots: int = 0) -> void:
	TradeInventoryHelpers.build_grid_items(self, grid, item_array, source_type, owner_unit, min_slots)
							
func _on_grid_item_clicked(btn: Button, meta: Dictionary) -> void:
	InventoryTradeFlowHelpers.on_grid_item_clicked(self, btn, meta)

func _on_equip_pressed() -> void:
	InventoryActionHelpers.on_equip_pressed(self)

func _on_close_inv_pressed() -> void:
	InventoryTradeFlowHelpers.on_close_inv_pressed(self)

func _on_use_pressed() -> void:
	await InventoryActionHelpers.on_use_pressed(self)

func _get_item_display_text(item: Resource) -> String:
	return InventoryTradeFlowHelpers.get_item_display_text(item)

func _bbcode_escape_user_text(s: String) -> String:
	return InventoryTradeFlowHelpers.bbcode_escape_user_text(s)

func _item_detail_soft_rule() -> String:
	return InventoryTradeFlowHelpers.item_detail_soft_rule()

func _item_detail_section_heading(title: String) -> String:
	return InventoryTradeFlowHelpers.item_detail_section_heading(title)

func _item_detail_callout(accent_hex: String, body_hex: String, escaped_msg: String) -> String:
	return InventoryTradeFlowHelpers.item_detail_callout(accent_hex, body_hex, escaped_msg)

func _item_detail_line(lbl: String, value_bb: String) -> String:
	return InventoryTradeFlowHelpers.item_detail_line(lbl, value_bb)

func _item_detail_effect_row(body_color: String, escaped_inner: String) -> String:
	return InventoryTradeFlowHelpers.item_detail_effect_row(body_color, escaped_inner)


func _weapon_compare_delta_fragments_bbcode(sel: WeaponData, equipped: WeaponData) -> PackedStringArray:
	return InventoryTradeFlowHelpers.weapon_compare_delta_fragments_bbcode(sel, equipped)


func _weapon_stat_compare_line_bbcode(sel: WeaponData, equipped: WeaponData) -> String:
	return InventoryTradeFlowHelpers.weapon_stat_compare_line_bbcode(sel, equipped)


func _add_equipped_badge_to_inv_button(btn: Button) -> void:
	InventoryTradeFlowHelpers.add_equipped_badge_to_inv_button(btn)


func _play_inv_slot_flash(btn: Button) -> void:
	InventoryTradeFlowHelpers.play_inv_slot_flash(self, btn)


func _battle_try_flash_pending_inv_slot(grid: GridContainer) -> void:
	InventoryTradeFlowHelpers.battle_try_flash_pending_inv_slot(self, grid)

func _get_item_detailed_info(item: Resource, stack_count: int = 1, viewer_unit: Node2D = null) -> String:
	return InventoryTradeFlowHelpers.get_item_detailed_info(self, item, stack_count, viewer_unit)


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
	BattleEndFlowHelpers.on_continue_button_pressed(self)


func _is_dragon_deployable_in_battle(dragon: Dictionary) -> bool:
	return CampaignSetupHelpers.is_dragon_deployable_in_battle(dragon)


func _make_dragon_battle_entry(dragon: Dictionary) -> Dictionary:
	return CampaignSetupHelpers.make_dragon_battle_entry(dragon)


func _build_deployment_roster() -> Array:
	return CampaignSetupHelpers.build_deployment_roster()


func _build_deployment_roster_from_consumed_mock_coop_handoff() -> Array:
	return CampaignSetupHelpers.build_deployment_roster_from_consumed_mock_coop_handoff(self)


func load_campaign_data() -> void:
	CampaignSetupHelpers.load_campaign_data(self)


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
	PathPreviewHelpers.reset_path_pulse_visuals(self)


func _set_path_pulse(active: bool) -> void:
	PathPreviewHelpers.set_path_pulse(self, active)

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
			p = randf_range(0.95, 1.02) # â€œconfirmâ€ doux
		UISfx.TARGET_OK:
			player = select_sound
			p = randf_range(1.08, 1.16) # â€œattaqueâ€ plus aigu
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
	CameraFxHelpers.clamp_camera_position(self)


func _apply_camera_zoom(direction: int) -> void:
	await CameraFxHelpers.new().apply_camera_zoom(self, direction)


# Shared battlefield QTE polish (defensive reaction UI + cinematic layers).
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
	BattleFieldQteMinigameHelpers.apply_battlefield_qte_ui_polish(self, qte_layer, screen_dimmer, bar_bg, help_text, top_bar, bottom_bar, accent, title_text)


# --- ABILITY 1: THE UNIVERSAL PARRY (Timing QTE) ---


func _run_parry_minigame(defender: Node2D) -> bool:
	return await DefensiveReactionHelpers.run_parry_minigame(self, defender)

# --- ABILITY 2: SHIELD CLASH (Mashing QTE) ---
# Returns 0 (Fail), 1 (Block), 2 (Perfect Counter)
func _run_shield_clash_minigame(defender: Node2D, attacker: Node2D) -> int:
	return await DefensiveReactionHelpers.run_shield_clash_minigame(self, defender, attacker)
	
# --- ABILITY 3: FOCUSED STRIKE (Offensive Hold & Release QTE) ---
func _run_focused_strike_minigame(attacker: Node2D) -> int:
	return await BattleFieldQteMinigameHelpers.run_focused_strike_minigame(self, attacker)


# --- ABILITY 4: BLOODTHIRSTER (Multi-Tap Combo QTE) ---
# Returns the number of successful hits (0 to 3)
func _run_bloodthirster_minigame(attacker: Node2D) -> int:
	return await BattleFieldQteMinigameHelpers.run_bloodthirster_minigame(self, attacker)


# --- ABILITY 5: HUNDRED POINT STRIKE (Simon Says QTE) ---
# Returns the total number of successful combo hits
func _run_hundred_point_strike_minigame(attacker: Node2D) -> int:
	return await BattleFieldQteMinigameHelpers.run_hundred_point_strike_minigame(self, attacker)


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
	CampaignSetupHelpers.setup_skirmish_battle(self)


# ==========================================
# LOOT WINDOW INFO PANEL
# ==========================================
func _on_loot_item_selected(index: int) -> void:
	InventoryTradeFlowHelpers.on_loot_item_selected(self, index)

# ==========================================
# INVENTORY WINDOW INFO PANEL
# ==========================================



func calculate_enemy_threat_range(enemy: Node2D) -> void:
	BattleFieldGridRangeHelpers.calculate_enemy_threat_range(self, enemy)


# Calculates the movement points, adding penalties for Armored units
func get_path_move_cost(path: Array[Vector2i], unit: Node2D) -> float:
	return BattleFieldGridRangeHelpers.get_path_move_cost(self, path, unit)


func get_unit_path(unit: Node2D, start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	return BattleFieldGridRangeHelpers.get_unit_path(self, unit, start, target)


func calculate_full_danger_zone() -> void:
	BattleFieldGridRangeHelpers.calculate_full_danger_zone(self)



func toggle_danger_zone() -> void:
	show_danger_zone = !show_danger_zone
	if show_danger_zone:
		_danger_zone_recalc_dirty = false
		calculate_full_danger_zone()
		play_ui_sfx(UISfx.TARGET_OK) # Sharp "On" sound
		if battle_log and battle_log.visible:
			add_combat_log("Enemy threat overlay: ON (Shift) â€” visible enemies; purple = move, orange = attack", "gray")
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
	InventoryTradeFlowHelpers.show_trade_popup(self, ally)

func hide_trade_popup() -> void:
	InventoryTradeFlowHelpers.hide_trade_popup(self)

func _on_trade_popup_confirm() -> void:
	InventoryTradeFlowHelpers.on_trade_popup_confirm(self)

func open_trade_window(unit_a: Node2D, unit_b: Node2D) -> void:
	InventoryTradeFlowHelpers.open_trade_window(self, unit_a, unit_b)

func refresh_trade_window() -> void:
	InventoryTradeFlowHelpers.refresh_trade_window(self)

func _fill_trade_list(list: ItemList, unit: Node2D) -> void:
	InventoryTradeFlowHelpers.fill_trade_list(list, unit)

func _on_trade_item_clicked(index: int, side: String) -> void:
	InventoryTradeFlowHelpers.on_trade_item_clicked(self, index, side)

func _execute_trade_swap(side1: String, idx1: int, side2: String, idx2: int) -> void:
	TradeInventoryHelpers.execute_trade_swap(self, side1, idx1, side2, idx2)

func _on_trade_window_close() -> void:
	InventoryTradeFlowHelpers.on_trade_window_close(self)

func _validate_equipment(unit: Node2D) -> void:
	InventoryTradeFlowHelpers.validate_equipment(self, unit)

func execute_talk(initiator: Node2D, target: Node2D) -> void:
	await DialogueInteractionHelpers.execute_talk(self, initiator, target)

func play_recruit_dialogue(initiator: Node2D, target: Node2D) -> void:
	await DialogueInteractionHelpers.play_recruit_dialogue(self, initiator, target)

func _on_support_talk_pressed() -> void:
	await DialogueInteractionHelpers._on_support_talk_pressed(self)

func play_support_dialogue(initiator: Node2D, target: Node2D) -> void:
	await DialogueInteractionHelpers.play_support_dialogue(self, initiator, target)

func get_support_name(unit: Node2D) -> String:
	return SupportRelationshipHelpers.support_name_from_unit(unit)

# --- Relationship Web V1: central identity for relationship lookups (future-proof for unit_id migration). ---
func get_relationship_id(unit_or_name: Variant) -> String:
	return SupportRelationshipHelpers.get_relationship_id(unit_or_name)

# --- Relationship Web V1: tag and combat modifiers. ---
## Returns unit_tags array from unit or unit.data; empty if missing.
func get_unit_tags(unit: Node2D) -> Array:
	return SupportRelationshipHelpers.get_unit_tags(unit)

## Returns combat modifiers from relationship web + grief + fear tags. hit/avo/crit_bonus/dmg_bonus/support_chance_bonus (additive).
func get_relationship_combat_modifiers(unit: Node2D) -> Dictionary:
	return SupportRelationshipHelpers.get_relationship_combat_modifiers(self, unit)

## True if mentor is higher level than mentee with gap >= MENTORSHIP_LEVEL_GAP_MIN; both allied and valid.
func _can_gain_mentorship(mentor: Node2D, mentee: Node2D) -> bool:
	return SupportRelationshipHelpers.can_gain_mentorship(self, mentor, mentee)

## Awards a relationship stat (trust/mentorship/rivalry) from an event; one gain per pair per event_type per battle. Shows Bond Pulse; "Formed" log on threshold cross.
func _award_relationship_stat_event(unit_a: Variant, unit_b: Variant, stat: String, event_type: String, amount: int = 1) -> void:
	SupportRelationshipHelpers.award_relationship_stat_event(self, unit_a, unit_b, stat, event_type, amount)

## Trust-only shorthand (calls _award_relationship_stat_event with stat "trust").
func _award_relationship_event(unit_a: Variant, unit_b: Variant, event_type: String, amount: int = 1) -> void:
	SupportRelationshipHelpers.award_relationship_event(self, unit_a, unit_b, event_type, amount)

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
	return SupportRelationshipHelpers.support_name_from_unit(unit) if unit != null else ""

## Returns personal dialogue line for boss_id + unit_id + event_type (pre_attack/death/retreat); queries BossPersonalDialogueDB.
func _get_boss_personal_line(boss_id: String, unit_id: String, event_type: String) -> String:
	return BossDialogueDB.get_line(boss_id, unit_id, event_type)

## Returns support_personality from unit's UnitData; empty string if missing. Used for Defy Death rescue line lookup.
func _get_support_personality(unit: Node2D) -> String:
	return SupportRelationshipHelpers.get_support_personality(unit)

## Returns savior-spoken rescue line for Defy Death; uses savior's personality and victim's display name.
func _get_defy_death_rescue_line(savior: Node2D, victim_name: String) -> String:
	return SupportRelationshipHelpers.get_defy_death_rescue_line(savior, victim_name)

## Shows TalkPanel with savior portrait and rescue line for a short time. Does not pause the game.
func _show_defy_death_savior_portrait(savior: Node2D, savior_name: String, rescue_line: String) -> void:
	await SupportRelationshipHelpers.new().show_defy_death_savior_portrait(self, savior, savior_name, rescue_line)

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
## Inputs: unit (Node2D) â€” the unit whose support partner we query.
## Outputs: Dictionary with "partner" (Node2D or null), "rank" (int 0..3), "in_range" (bool), "can_react" (bool).
## Side effects: None. Missing/invalid data => partner null, rank 0, can_react false.
func get_best_support_context(unit: Node2D) -> Dictionary:
	return SupportRelationshipHelpers.get_best_support_context(self, unit)

## Applies one hit with Phase 2 support reactions: Guard (redirect one hit to partner), then Defy Death (survive at 1 HP once per battle).
## Purpose: Single insertion point for Guard/Defy so forecast and resolution stay consistent; prevents redirect loops via is_redirected.
## Inputs: victim (Node2D), damage (int), source (Node2D), exp_tgt (Node2D or null), is_redirected (bool) â€” if true, no reactions.
## Outputs: None.
## Side effects: May apply damage to victim or to guard partner; may cap damage and set _defy_death_used; sets _support_guard_used_this_sequence when Guard triggers.
func _apply_hit_with_support_reactions(victim: Node2D, damage: int, source: Node2D, exp_tgt: Node2D, is_redirected: bool) -> void:
	await SupportHelpers.apply_hit_with_support_reactions(self, victim, damage, source, exp_tgt, is_redirected)

func _on_support_btn_pressed() -> void:
	SupportRelationshipHelpers.on_support_btn_pressed(self)

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
	CampaignSetupHelpers.start_battle_from_deployment(self)


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
	await BattleEndFlowHelpers.trigger_victory(self)


# ==========================================
# --- FOG OF WAR & LINE OF SIGHT ---
# ==========================================
func update_fog_of_war() -> void:
	BattleFieldFogOfWarHelpers.update_fog_of_war(self)

func _check_line_of_sight(start: Vector2i, target: Vector2i) -> bool:
	return BattleFieldGridRangeHelpers.check_line_of_sight(self, start, target)


func _is_wall_at(pos: Vector2i) -> bool:
	return BattleFieldGridRangeHelpers.is_wall_at(self, pos)



func _apply_fow_visibility(container: Node) -> void:
	BattleFieldFogOfWarHelpers.apply_fow_visibility(self, container)

func _decor_base_modulate(item: CanvasItem) -> Color:
	return BattleFieldFogOfWarHelpers.decor_base_modulate(self, item)

func _decor_tile_currently_visible(node: Node2D) -> bool:
	return BattleFieldFogOfWarHelpers.decor_tile_currently_visible(self, node)

func _apply_decor_fow_shadow() -> void:
	BattleFieldFogOfWarHelpers.apply_decor_fow_shadow(self)

func _process_fog(delta: float) -> void:
	BattleFieldFogOfWarHelpers.process_fog(self, delta)

func animate_flying_gold(world_pos: Vector2, amount: int) -> void:
	GoldVfxHelpers.animate_flying_gold(self, world_pos, amount)
		
func _on_fog_draw() -> void:
	BattleFieldFogOfWarHelpers.on_fog_draw(self)

# --- TACTICAL ABILITY (Momentum QTE) ---
func _run_tactical_action_minigame(attacker: Node2D, ability_name: String) -> bool:
	return await BattleFieldQteMinigameHelpers.run_tactical_action_minigame(self, attacker, ability_name)


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
	BattleFieldSpecialModeSetupHelpers.setup_arena_battle(self)

func _do_hit_stop(freeze_duration: float, slow_scale: float = 0.12, slow_duration: float = 0.10) -> void:
	await CameraFxHelpers.new().do_hit_stop(self, freeze_duration, slow_scale, slow_duration)

func _start_impact_camera(focus_world: Vector2, _zoom_mult: float, snap_t: float, restore_t: float) -> void:
	CameraFxHelpers.start_impact_camera(self, focus_world, _zoom_mult, snap_t, restore_t)

func _spawn_fullscreen_impact_flash(color: Color, alpha: float, duration: float) -> void:
	CameraFxHelpers.spawn_fullscreen_impact_flash(self, color, alpha, duration)
		
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
	LevelUpPresentationHelpers.hide_legacy_levelup_nodes(self)


func _make_levelup_style(bg: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	return LevelUpPresentationHelpers.make_levelup_style(bg, border, radius)


func _get_levelup_dynamic_root() -> VBoxContainer:
	return LevelUpPresentationHelpers.get_levelup_dynamic_root(self)


func _clear_levelup_dynamic_root() -> void:
	LevelUpPresentationHelpers.clear_levelup_dynamic_root(self)


func _get_levelup_bar_cap(stat_key: String, value: int) -> int:
	return LevelUpPresentationHelpers.get_levelup_bar_cap(stat_key, value)


func _update_levelup_value_label(value: float, value_label: Label, old_value: int, gain: int) -> void:
	LevelUpPresentationHelpers.update_levelup_value_label(value, value_label, old_value, gain)


func _get_levelup_class_theme(unit: Node2D) -> Dictionary:
	return LevelUpPresentationHelpers.get_levelup_class_theme(unit)


func _get_levelup_stat_visual(stat_key: String) -> Dictionary:
	return LevelUpPresentationHelpers.get_levelup_stat_visual(stat_key)


func _create_levelup_icon_badge(icon_text: String, icon_color: Color) -> PanelContainer:
	return LevelUpPresentationHelpers.create_levelup_icon_badge(icon_text, icon_color)


func _create_levelup_title_banner(root: VBoxContainer, title_text: String, theme: Dictionary) -> Dictionary:
	return LevelUpPresentationHelpers.create_levelup_title_banner(root, title_text, theme)


func _create_levelup_header(unit: Node2D, old_level: int, new_level: int, theme: Dictionary) -> Dictionary:
	return LevelUpPresentationHelpers.create_levelup_header(self, unit, old_level, new_level, theme)


func _create_levelup_stat_row(container: VBoxContainer, stat_name: String, stat_key: String, start_value: int, end_value: int, gain: int, theme: Dictionary) -> Dictionary:
	return LevelUpPresentationHelpers.create_levelup_stat_row(container, stat_name, stat_key, start_value, end_value, gain, theme)


func run_theatrical_stat_reveal(unit: Node2D, title_text: String, gains: Dictionary) -> void:
	await LevelUpPresentationHelpers.run_theatrical_stat_reveal(self, unit, title_text, gains)


func _attach_levelup_bar_sheen(bar: ProgressBar) -> ColorRect:
	return LevelUpPresentationHelpers.attach_levelup_bar_sheen(bar)


func _animate_levelup_bar_sheen(sheen: ColorRect, bar: ProgressBar) -> void:
	LevelUpPresentationHelpers.animate_levelup_bar_sheen(self, sheen, bar)


func _spawn_levelup_panel_particles(theme: Dictionary) -> CPUParticles2D:
	return LevelUpPresentationHelpers.spawn_levelup_panel_particles(self, theme)


func _play_levelup_critical_row_fx(row_data: Dictionary, theme: Dictionary) -> void:
	await LevelUpPresentationHelpers.play_levelup_critical_row_fx(self, row_data, theme)


func _show_levelup_center_burst(main_text: String, accent_color: Color) -> void:
	await LevelUpPresentationHelpers.show_levelup_center_burst(self, main_text, accent_color)


func _make_levelup_circle(radius: float, point_count: int, color: Color) -> Polygon2D:
	return LevelUpPresentationHelpers.make_levelup_circle(radius, point_count, color)


func _spawn_levelup_halo(unit: Node2D, accent_color: Color) -> Node2D:
	return LevelUpPresentationHelpers.spawn_levelup_halo(unit, accent_color)


func _get_support_threshold_for_next_rank(unit_a: Node2D, unit_b: Node2D, current_rank: int) -> int:
	return SupportRelationshipHelpers.get_support_threshold_for_next_rank(self, unit_a, unit_b, current_rank)


func _get_next_support_rank_letter(current_rank: int) -> String:
	return SupportRelationshipHelpers.get_next_support_rank_letter(current_rank)


func _queue_support_ready_if_needed(unit_a: Node2D, unit_b: Node2D) -> void:
	SupportRelationshipHelpers.queue_support_ready_if_needed(self, unit_a, unit_b)


func _show_next_support_ready_popup() -> void:
	await SupportRelationshipHelpers.new().show_next_support_ready_popup(self)


func _add_support_points_and_check(unit_a: Node2D, unit_b: Node2D, amount: int) -> void:
	SupportRelationshipHelpers.add_support_points_and_check(self, unit_a, unit_b, amount)


func _get_forecast_support_text(unit: Node2D) -> String:
	return CombatForecastFlowHelpers.get_forecast_support_text(self, unit)


func _is_forecast_allied_unit(unit: Node2D) -> bool:
	return CombatForecastFlowHelpers.is_forecast_allied_unit(self, unit)


func _build_forecast_reaction_summary(attacker: Node2D, defender: Node2D, atk_wpn: Resource) -> String:
	return CombatForecastFlowHelpers.build_forecast_reaction_summary(self, attacker, defender, atk_wpn)


func _ensure_forecast_support_labels() -> void:
	CombatForecastFlowHelpers.ensure_forecast_support_labels(self)

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
	return DetailedUnitInfoHelpers.get_unit_target_for_details(self)

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
	DetailedUnitInfoHelpers.ensure_detailed_unit_info_panel(self)

func _show_detailed_unit_info_panel(unit: Node2D) -> void:
	DetailedUnitInfoHelpers.show_detailed_unit_info_panel(self, unit)

func _hide_detailed_unit_info_panel() -> void:
	DetailedUnitInfoHelpers.hide_detailed_unit_info_panel(self)

func _ensure_detailed_unit_info_primary_widgets_style() -> void:
	DetailedUnitInfoContentHelpers.ensure_detailed_unit_info_primary_widgets_style(self)

func _resolve_detailed_unit_info_class_label(unit: Node2D) -> String:
	return DetailedUnitInfoContentHelpers.resolve_detailed_unit_info_class_label(unit)

func _build_detailed_unit_info_meta_line(unit: Node2D) -> String:
	return DetailedUnitInfoContentHelpers.build_detailed_unit_info_meta_line(self, unit)

func _build_detailed_unit_info_summary_text(unit: Node2D) -> String:
	return DetailedUnitInfoContentHelpers.build_detailed_unit_info_summary_text(self, unit)

func _detailed_unit_info_stat_description(stat_key: String) -> String:
	return DetailedUnitInfoContentHelpers.detailed_unit_info_stat_description(stat_key)

func _detailed_unit_info_stat_label(stat_key: String) -> String:
	return DetailedUnitInfoContentHelpers.detailed_unit_info_stat_label(stat_key)

func _detailed_unit_info_stat_hint_specs(stat_key: String) -> Array[Dictionary]:
	return DetailedUnitInfoContentHelpers.detailed_unit_info_stat_hint_specs(stat_key)

func _detailed_unit_info_growth_label(growth_key: String) -> String:
	return DetailedUnitInfoContentHelpers.detailed_unit_info_growth_label(growth_key)

func _detailed_unit_info_primary_description(bar_key: String) -> String:
	return DetailedUnitInfoContentHelpers.detailed_unit_info_primary_description(bar_key)

func _populate_detailed_unit_info_weapon_row(unit: Node2D) -> void:
	DetailedUnitInfoContentHelpers.populate_detailed_unit_info_weapon_row(self, unit)

func _detailed_unit_info_growth_fill_color(stat_key: String, growth_value: int) -> Color:
	return DetailedUnitInfoContentHelpers.detailed_unit_info_growth_fill_color(self, stat_key, growth_value)

func _refresh_detailed_unit_info_growth_widgets(unit: Node2D, animate: bool, tween: Tween = null) -> void:
	DetailedUnitInfoContentHelpers.refresh_detailed_unit_info_growth_widgets(self, unit, animate, tween)

func _build_detailed_unit_info_relationship_cards(unit: Node2D) -> void:
	DetailedUnitInfoContentHelpers.build_detailed_unit_info_relationship_cards(self, unit)

func _refresh_detailed_unit_info_visuals(unit: Node2D, animate: bool = false) -> void:
	DetailedUnitInfoContentHelpers.refresh_detailed_unit_info_visuals(self, unit, animate)

func _build_detailed_unit_info_text(unit: Node2D) -> String:
	return DetailedUnitInfoHelpers.build_detailed_unit_info_text(self, unit)

func _on_unit_details_button_pressed() -> void:
	DetailedUnitInfoHelpers.on_unit_details_button_pressed(self)

func _build_detailed_unit_info_left_text(unit: Node2D) -> String:
	return DetailedUnitInfoHelpers.build_detailed_unit_info_left_text(self, unit)

func _build_detailed_unit_info_right_text(unit: Node2D) -> String:
	return DetailedUnitInfoHelpers.build_detailed_unit_info_right_text(self, unit)

func _build_detailed_unit_info_record_text(unit: Node2D) -> String:
	return DetailedUnitInfoContentHelpers.build_detailed_unit_info_record_text(self, unit)

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

	# Offset punch only â€” no zoom manipulation
	_start_impact_camera(focus_world, 1.0, 0.040, 0.18)

	await _do_hit_stop(0.018, 0.14, 0.11)
	
func _play_guard_break_impact(focus_world: Vector2) -> void:
	_spawn_fullscreen_impact_flash(Color(1.0, 0.55, 0.18), 0.28, 0.12)
	_spawn_fullscreen_impact_flash(Color(1.0, 0.82, 0.35), 0.10, 0.18)

	# Smaller offset punch than crits
	_start_impact_camera(focus_world, 1.0, 0.030, 0.14)

	await _do_hit_stop(0.012, 0.22, 0.07)
