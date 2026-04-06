# ==============================================================================
# Script Name: Unit.gd
# Purpose:
#   Tactical RPG unit entity: stats, movement, combat, leveling, poise, and
#   persistence. Used by BattleField for both player and enemy units.
#
# Project Role:
#   Core gameplay node for map units. Handles HP/EXP bars, defend state,
#   promotion aura, dash effects, and integration with CampaignManager (avatar,
#   difficulty scaling, save/load).
#
# Dependencies:
#   - UnitData, ClassData, WeaponData resources
#   - CampaignManager autoload (custom_avatar, difficulty, unit_move_speed)
#
# AI / Reviewer Notes:
#   - Main init: _ready() (data-driven stats, avatar override, difficulty boost)
#   - Turn lifecycle: reset_turn(), finish_turn(), trigger_defend()
#   - Combat: take_damage(), die(), get_max_poise(), update_poise_visuals()
#   - Persistence: setup_from_save_data(), get_exp_required()
# ==============================================================================

extends Node2D
class_name Unit

const UnitCombatStatusHelpers = preload("res://Scripts/Core/UnitCombatStatusHelpers.gd")
const ActiveCombatAbilityHelpers = preload("res://Scripts/Core/BattleField/ActiveCombatAbilityHelpers.gd")
const ClassDataRef = preload("res://Resources/Classes/ClassData.gd")

# ------------------------------------------------------------------------------
# Constants (match BattleField cell size when converting grid <-> world)
# ------------------------------------------------------------------------------
const DEFAULT_CELL_SIZE: int = 64
## Main HP fill: snappy ease-out. Trail bar drains slower so damage reads as a chunk.
const HEALTH_BAR_LOSS_DURATION: float = 0.22
const HEALTH_BAR_DELAY_TRAIL_DURATION: float = 0.62
const DAMAGE_FLASH_DURATION: float = 0.1
## Multiplier on [member base_color] when the unit has ended their turn (keeps enemy scene tints).
const EXHAUSTED_MODULATE: Color = Color(0.3, 0.3, 0.3, 1.0)
## After multiply, per-channel floor so strong scene tints (e.g. dark red enemies) do not crush G/B to ~0 → black silhouettes.
const EXHAUSTED_CHANNEL_FLOOR: float = 0.08
const EXP_BAR_TWEEN_DURATION: float = 0.2
const POISE_BAR_TWEEN_DURATION: float = 0.2
## Matches HealthBar width in `Unit.tscn` when `size` is not yet laid out (offset_right − offset_left).
const POISE_BAR_FALLBACK_WIDTH_PX: float = 85.0
const POISE_BAR_HEIGHT_PX: float = 6.0
const OVERHEAD_BAR_NON_FOCUS_ALPHA_DEFAULT: float = 0.32
const OVERHEAD_FOOT_GAP_PX: float = 2.0
const SELECT_PULSE_HALF_TIME: float = 0.27
const SELECT_PULSE_SPRITE_BRIGHT: Color = Color(1.30, 1.30, 1.30, 1.0)
const SELECT_PULSE_SPRITE_SCALE_MULT: float = 1.03
const SELECT_PULSE_GLOW_ALPHA_MIN: float = 0.24
const SELECT_PULSE_GLOW_ALPHA_MAX: float = 0.66
const SELECT_PULSE_GLOW_SCALE_MULT: float = 1.03
## Bone toxin: sprite [member Sprite2D.modulate] pulses green (root [member modulate] stays team-colored).
const BONE_TOXIN_PULSE_MODULATE_DIM: Color = Color(0.58, 0.95, 0.68, 1.0)
const BONE_TOXIN_PULSE_MODULATE_BRIGHT: Color = Color(0.82, 1.14, 0.93, 1.0)
const BONE_TOXIN_PULSE_HALF_PERIOD_SEC: float = 0.55
## [enum ClassData.MoveType.FLYING]: prep → arcing takeoff → cruise → hover → arcing landing (-Y = up).
const FLIGHT_CRUISE_HEIGHT_PX: float = 27.0
## Fractions of [i]total move duration[/i] (middle span is high cruise along path).
const FLIGHT_TIME_PREP_FRAC: float = 0.065
const FLIGHT_TIME_TAKEOFF_CLIMB_FRAC: float = 0.135
const FLIGHT_TIME_LANDING_HOVER_FRAC: float = 0.055
const FLIGHT_TIME_LANDING_DROP_FRAC: float = 0.125
## >3 = more of the climb happens late (reads as a quick push off the ground).
const FLIGHT_TAKEOFF_LIFT_POWER: float = 4.35
## Slight apex past nominal cruise during takeoff for a stronger leap (0 = off).
const FLIGHT_TAKEOFF_APEX_OVERSHOOT: float = 0.07
## >2 = hold altitude longer, then a faster final plunge.
const FLIGHT_LANDING_DROP_POWER: float = 3.05
## Takeoff: [i]u[/i] lags height ([code]pow(w, power)[/code]) so the path curves through the air.
const FLIGHT_TAKEOFF_U_FRAC_OF_PATH: float = 0.38
const FLIGHT_TAKEOFF_HORIZONTAL_LAG_POWER: float = 2.55
## Landing: hold [i]u[/i] this far short of the end (segment units), then close while dropping = swoop.
const FLIGHT_LANDING_U_PULLBACK: float = 0.3
## Drop timeline → horizontal closure; <1 closes forward motion slower (deeper arc before touching down).
const FLIGHT_LANDING_FORWARD_EASE_POWER: float = 0.78
## Cruise: no vertical bob (was reading as floaty pendulum with strides).
## Forward strides: translation only ([member Sprite2D.rotation] stays 0); stroke = [code]max(0,sin)[/code] half-period only.
const FLIGHT_STRIDE_DIAG_PX: float = 7.5
const FLIGHT_WING_FLAP_HZ: float = 0.95
const FLIGHT_WING_FLAP_SHAPE: float = 0.48
const FLIGHT_WING_FLAP_CRUISE_MUL: float = 1.08
## Takeoff/landing squash on [member Sprite2D.scale] (paired X/Y like [code]DragonActor[/code] [member Control.scale] on [code]body_pivot[/code]).
const FLIGHT_TAKEOFF_STRETCH_Y: float = 0.34
const FLIGHT_LANDING_SQUISH_Y: float = 0.32
## When Y stretches, narrow X slightly; when Y squashes, widen X (reads as volume, not a thin resize).
const FLIGHT_SQUISH_VOLUME_PAIR: float = 0.42
## Prep: crouch builds to max at end of prep; takeoff: extra Y pop at commit (decays with climb phase).
const FLIGHT_PREP_SQUISH_DEPTH: float = 0.14
const FLIGHT_TAKEOFF_POP_Y: float = 0.17
## Ground shadow under flier: alpha at ground / at full cruise altitude.
const FLIGHT_SHADOW_ALPHA_GROUND: float = 0.58
const FLIGHT_SHADOW_ALPHA_CRUISE: float = 0.16
const FLIGHT_SHADOW_SCALE_XYZ_GROUND: Vector2 = Vector2(1.05, 0.88)
const FLIGHT_SHADOW_SCALE_XYZ_CRUISE: Vector2 = Vector2(0.62, 0.52)
const STATUS_STRIP_ICON_SCALE: float = 0.5
## Max status textures in one row; beyond that, last slot becomes a +N overflow label.
const STATUS_STRIP_MAX_ICONS: int = 5
const STATUS_STRIP_GAP_PX: float = 3.0
const STATUS_STRIP_ABOVE_HP_GAP_PX: float = 3.0
const STATUS_STRIP_BADGE_H_MARGIN_PX: float = 4.0
## When HP bar is hidden / not laid out yet (buff strip fallback); debuffs use this Y at feet.
const STATUS_STRIP_FALLBACK_Y: float = 54.0
## Debuff row at feet — above tile/sprite stack, same layer family as old PoisonedIcon.
const STATUS_DEBUFF_STRIP_Z_INDEX: int = 15
## Buff row above HP bar — over health bar (10) and level badge (12).
const STATUS_BUFF_STRIP_Z_INDEX: int = 16

# ------------------------------------------------------------------------------
# Signals
# ------------------------------------------------------------------------------
signal moved(target_grid_pos: Vector2i)
signal finished_turn(unit: Node2D)
signal damaged(current_hp: int)
signal died(unit: Node2D, killer: Node2D)
signal leveled_up(unit: Node2D, gains: Dictionary)

# ------------------------------------------------------------------------------
# AI Configuration
# ------------------------------------------------------------------------------
# 1 = Dumb (Attacks nearest) | 2 = Bloodthirsty | 3 = Tactical
@export var ai_intelligence: int = 1
enum AIBehavior { DEFAULT, THIEF, SUPPORT, COWARD, AGGRESSIVE, MINION }
@export var ai_behavior: AIBehavior = AIBehavior.DEFAULT

# ------------------------------------------------------------------------------
# Visual / Promotion
# ------------------------------------------------------------------------------
@export var lightning_bolt_texture: Texture2D
@export var is_promoted: bool = false
## Layered flight move SFX (null = skip that layer). Assign a soft wind/wing loop to [code]flight_sound_cruise_loop[/code] if you want cruise bed (avoid phase-turn stings).
@export_group("Flight move audio")
@export var flight_sound_prep: AudioStream = preload("res://SoundEffects/DefenseMode.mp3")
## Shared clip for takeoff commit + touchdown; use pitch to differentiate.
@export var flight_sound_dragon_takeoff_land: AudioStream = preload("res://SoundEffects/dragon_landing.mp3")
## Optional loop during cruise only — do [b]not[/b] use [code]next-turn.mp3[/code] (same as battle phase UI sting).
@export var flight_sound_cruise_loop: AudioStream = null
@export var flight_audio_prep_db: float = -10.0
@export var flight_audio_takeoff_db: float = 0.0
## Slightly below 1.15 keeps takeoff bright; lower = longer playback (same clip).
@export var flight_audio_dragon_takeoff_pitch_scale: float = 1.05
@export var flight_audio_cruise_db: float = -14.0
@export var flight_audio_land_db: float = -2.0
## Lower than takeoff for a heavy land; lower = longer playback (same clip).
@export var flight_audio_dragon_land_pitch_scale: float = 0.78
var promo_aura: Sprite2D = null

var active_class_data: ClassData = null
@onready var death_sound_player: AudioStreamPlayer = $DeathSound
@onready var sprite: Sprite2D = $Sprite

var selection_tween: Tween
var _bone_toxin_pulse_tween: Tween
var stagger_tween: Tween
var _poise_bar_tween: Tween
var _mock_coop_owner_sprite_tint: Color = Color.WHITE

# ------------------------------------------------------------------------------
# Identity & Data
# ------------------------------------------------------------------------------
@export var data: UnitData
@export var is_custom_avatar: bool = false
var is_arena_ghost: bool = false

var unit_name: String = ""
var unit_class_name: String = ""
var unit_tags: Array = []  # Relationship Web: e.g. undead, cultist, holy, beast


func get_unit_type() -> UnitData.UnitType:
	if data == null:
		return UnitData.UnitType.UNSPECIFIED
	return data.unit_type

# ------------------------------------------------------------------------------
# Stats & Growth
# ------------------------------------------------------------------------------
var level: int = 1
var experience: int = 0
var move_type: int = 0
var max_hp: int
var current_hp: int
var strength: int
var defense: int
var speed: int
var agility: int
var magic: int
var resistance: int
var equipped_weapon: WeaponData
## Pass 4: read-only rune socket summary; no stat/combat effects (see [WeaponRuneRuntimeRead]).
func get_equipped_weapon_rune_runtime_summary() -> Dictionary:
	return WeaponRuneRuntimeRead.build_summary(equipped_weapon)

var inventory: Array[Resource] = []
var inventory_mapping: Array[Dictionary] = []
var move_range: int
var ability: String = ""
var unlocked_abilities: Array = []
var skill_points: int = 0
var unlocked_skills: Array = []
## Stacked passive labels (e.g. legacy class effects). Display-only strings until combat hooks read them.
var traits: Array = []
## Rookie legacy ids (recruit, villager, …) — combat stacks these with current rookie job if any.
var rookie_legacies: Array = []
## Stacked ids (base_knight, …) when leaving a normal class for promoted; traits hold readable lines.
var base_class_legacies: Array = []
## Stacked ids (promoted_great_knight, …) when leaving a promoted class for ascended.
var promoted_class_legacies: Array = []
## Battle-only status stack (co-op wire [code]cstat[/code]). See [UnitCombatStatusHelpers].
var combat_statuses: Array = []

# ------------------------------------------------------------------------------
# Turn State
# ------------------------------------------------------------------------------
var has_moved: bool = false
## Move cost (terrain-weighted) spent on the main move before combat this turn; used for Canto (cav/flier).
var move_points_used_this_turn: float = 0.0
## After an action, flying/cavalry may pivot with this remaining budget (move only, no second attack).
var in_canto_phase: bool = false
var canto_move_budget: float = 0.0
var is_exhausted: bool = false
var base_color: Color = Color.WHITE
var is_defending: bool = false
var defense_bonus: int = 3  # Flat bonus to DEF/RES when defending

# ------------------------------------------------------------------------------
# Thief / Loot
# ------------------------------------------------------------------------------
var stolen_gold: int = 0
var stolen_loot: Array[Resource] = []

# ------------------------------------------------------------------------------
# Trade UI State
# ------------------------------------------------------------------------------
var trade_unit_a: Node2D = null
var trade_unit_b: Node2D = null
var trade_selected_side: String = ""
var trade_selected_index: int = -1

# ------------------------------------------------------------------------------
# UI References (nullable for scene variants)
# ------------------------------------------------------------------------------
@onready var health_bar: ProgressBar = $HealthBar
@onready var exp_bar: ProgressBar = $ExpBar
@onready var level_badge: Label = get_node_or_null("LevelBadge") as Label
@onready var team_glow: ColorRect = $TeamGlow
@onready var defend_icon: Node = get_node_or_null("DefendIcon")
var _status_buff_strip: Node2D = null
var _status_buff_sprites: Array[Sprite2D] = []
var _status_buff_overflow: Label = null
var _status_debuff_strip: Node2D = null
var _status_debuff_sprites: Array[Sprite2D] = []
var _status_debuff_overflow: Label = null

## Drawn under [member health_bar]; lags behind on damage so hits feel heavier.
var health_bar_delay: ProgressBar
var _hp_damage_tween: Tween
var _overhead_bars_enabled: bool = true
var _overhead_focus_mode_enabled: bool = false
var _overhead_bar_is_focused: bool = true
var _overhead_non_focus_alpha: float = OVERHEAD_BAR_NON_FOCUS_ALPHA_DEFAULT
var _overhead_layout_at_feet_cached: bool = false
var _overhead_layout_cache_ready: bool = false
var _selection_base_sprite_scale: Vector2 = Vector2.ONE
var _selection_base_glow_alpha: float = 0.3
var _selection_pulse_active: bool = false
var _flight_sfx_player: AudioStreamPlayer = null
var _flight_cruise_player: AudioStreamPlayer = null
var _flight_ground_shadow: Sprite2D = null
static var _flight_shared_ground_shadow_texture: ImageTexture = null

func _exit_tree() -> void:
	_flight_stop_cruise_audio()
	_flight_hide_ground_shadow()


func _ready() -> void:
	if data == null:
		push_warning("Unit has no UnitData assigned; stats and visuals will not initialize.")
		return
	# Scene tint (e.g. enemies modulate red) must be restored after hit-flash / UI resets.
	base_color = modulate
	if data.unit_sprite != null and sprite != null:
		sprite.texture = data.unit_sprite
		var texture_size: Vector2 = sprite.texture.get_size()
		var target_size := Vector2(DEFAULT_CELL_SIZE, DEFAULT_CELL_SIZE)
		var base_factor: float = minf(target_size.x / texture_size.x, target_size.y / texture_size.y)
		var final_scale: float = base_factor * data.visual_scale
		sprite.scale = Vector2(final_scale, final_scale)

	# 1. INITIALIZE CLASS DATA
	active_class_data = data.character_class

	# --- CUSTOM AVATAR LOGIC ---
	if is_custom_avatar and not is_arena_ghost and CampaignManager.custom_avatar.has("stats"):
		var avatar = CampaignManager.custom_avatar
		unit_name = avatar["name"]
		unit_class_name = avatar["class_name"]
		if avatar.has("class_data") and avatar["class_data"] != null:
			active_class_data = avatar["class_data"]
		if avatar.has("portrait") and data:
			var p = avatar["portrait"]
			if p is String and ResourceLoader.exists(p): data.portrait = load(p)
			elif p is Texture2D: data.portrait = p
		ability = avatar.get("ability", "")
		var c_stats = avatar["stats"]
		max_hp = c_stats["hp"]
		strength = c_stats["str"]
		magic = c_stats["mag"]
		defense = c_stats["def"]
		resistance = c_stats["res"]
		speed = c_stats["spd"]
		agility = c_stats["agi"]
		if avatar.has("move_range"):
			move_range = avatar["move_range"]
		elif active_class_data:
			move_range = active_class_data.move_range
		else:
			move_range = 4
		if active_class_data != null:
			move_type = int(active_class_data.move_type)
	# --- STANDARD UNIT LOGIC ---
	else:
		unit_name = data.display_name
		unit_class_name = active_class_data.job_name if active_class_data else "Unknown"
		if active_class_data:
			move_type = active_class_data.move_type
			max_hp = data.max_hp + active_class_data.hp_bonus
			strength = data.strength + active_class_data.str_bonus
			magic = data.magic + active_class_data.mag_bonus
			defense = data.defense + active_class_data.def_bonus
			resistance = data.resistance + active_class_data.res_bonus
			speed = data.speed + active_class_data.spd_bonus
			agility = data.agility + active_class_data.agi_bonus
			move_range = active_class_data.move_range
		else:
			max_hp = data.max_hp
			strength = data.strength
			magic = data.magic
			defense = data.defense
			resistance = data.resistance
			speed = data.speed
			agility = data.agility
			move_range = 4
		if get_parent() != null and get_parent().name == "EnemyUnits":
			var multiplier: float = 1.0
			match CampaignManager.current_difficulty:
				CampaignManager.Difficulty.HARD:
					multiplier = 1.25
				CampaignManager.Difficulty.MADDENING:
					multiplier = 1.5
					ai_intelligence += 1
			if multiplier > 1.0:
				max_hp = int(max_hp * multiplier)
				strength = int(strength * multiplier)
				magic = int(magic * multiplier)
				defense = int(defense * multiplier)
				resistance = int(resistance * multiplier)
				speed = int(speed * multiplier)
				agility = int(agility * multiplier)
		ability = data.ability

	# Equip starting weapon and set bars
	if data.starting_weapon != null and CampaignManager.has_method("duplicate_item"):
		equipped_weapon = CampaignManager.duplicate_item(data.starting_weapon)
	else:
		equipped_weapon = null
	current_hp = max_hp
	if health_bar != null:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
	if exp_bar != null:
		exp_bar.max_value = get_exp_required()
		exp_bar.value = experience
	if sprite != null:
		sprite.centered = true
		sprite.position = Vector2(DEFAULT_CELL_SIZE / 2, DEFAULT_CELL_SIZE / 2)
	if equipped_weapon != null and inventory.is_empty():
		inventory.append(equipped_weapon)

	ActiveCombatAbilityHelpers.bootstrap_unit(self)

	_apply_overhead_bar_visuals()
	_refresh_level_badge()
	call_deferred("_refresh_level_badge")
	refresh_standard_team_glow()


func _ensure_level_badge_node() -> void:
	if level_badge != null and is_instance_valid(level_badge):
		return
	level_badge = get_node_or_null("LevelBadge") as Label
	if level_badge != null:
		return
	var lb := Label.new()
	lb.name = "LevelBadge"
	lb.z_index = 12
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb.text = "Lv. 1"
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(lb)
	level_badge = lb
	if health_bar != null:
		move_child(level_badge, health_bar.get_index() + 1)


func _apply_overhead_bar_visuals() -> void:
	_ensure_level_badge_node()
	if health_bar != null:
		health_bar.clip_contents = false
		health_bar.show_percentage = false
		# Layered bars: back = track + trailing damage fill; front = transparent + green only
		# (an opaque track on the front bar would hide the entire trail underneath).
		_ensure_health_bar_delay()
		if health_bar_delay != null:
			_sync_health_bar_delay_layout()
			call_deferred("_sync_health_bar_delay_layout")
	if exp_bar != null:
		exp_bar.add_theme_stylebox_override("background", UnitBarVisuals.exp_track())
		exp_bar.add_theme_stylebox_override("fill", UnitBarVisuals.exp_fill())
	_layout_overhead_bars()
	_style_level_badge()
	_apply_overhead_bar_focus_state()


## Applies battlefield-level overhead bar policy:
## - HP + Poise remain on-map for all units when bars are enabled.
## - EXP + level badge show only for focused units when focus mode is enabled.
## - Non-focused units are faded instead of fully hidden.
func set_overhead_bar_focus_state(show_bars: bool, use_focus_mode: bool, is_focus_unit: bool, non_focus_alpha: float = OVERHEAD_BAR_NON_FOCUS_ALPHA_DEFAULT) -> void:
	var bars_at_feet: bool = CampaignManager.interface_unit_bars_at_feet
	if (not _overhead_layout_cache_ready) or (bars_at_feet != _overhead_layout_at_feet_cached):
		_overhead_layout_cache_ready = true
		_overhead_layout_at_feet_cached = bars_at_feet
		_layout_overhead_bars()
		call_deferred("_refresh_level_badge")
	_overhead_bars_enabled = show_bars
	_overhead_focus_mode_enabled = use_focus_mode
	_overhead_bar_is_focused = is_focus_unit
	_overhead_non_focus_alpha = clampf(non_focus_alpha, 0.10, 1.0)
	_apply_overhead_bar_focus_state()


func _apply_overhead_bar_focus_state() -> void:
	var should_draw_overhead: bool = _overhead_bars_enabled and current_hp > 0 and not has_meta("coop_remote_pending_death")
	var is_focus_visible: bool = (not _overhead_focus_mode_enabled) or _overhead_bar_is_focused
	var ui_alpha: float = 1.0 if is_focus_visible else _overhead_non_focus_alpha
	var ui_tint: Color = Color(1.0, 1.0, 1.0, ui_alpha)

	if health_bar != null:
		health_bar.visible = should_draw_overhead
		health_bar.modulate = ui_tint
	if health_bar_delay != null:
		health_bar_delay.visible = should_draw_overhead
		health_bar_delay.modulate = ui_tint
	if exp_bar != null:
		exp_bar.visible = should_draw_overhead and is_focus_visible
		exp_bar.modulate = ui_tint
	if level_badge != null:
		level_badge.visible = should_draw_overhead
		level_badge.modulate = Color.WHITE

	var p_bar: ProgressBar = get_node_or_null("DynamicPoiseBar") as ProgressBar
	if p_bar != null:
		var poise_visible: bool = should_draw_overhead and int(get_current_poise()) < int(get_max_poise())
		p_bar.visible = poise_visible
		p_bar.modulate = ui_tint

	_reposition_status_icon_strip_if_visible()


func _style_level_badge() -> void:
	if level_badge == null:
		return
	level_badge.add_theme_font_size_override("font_size", 13)
	level_badge.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92, 1.0))
	level_badge.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 1.0))
	level_badge.add_theme_constant_override("outline_size", 3)
	level_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	level_badge.add_theme_constant_override("shadow_offset_x", 0)
	level_badge.add_theme_constant_override("shadow_offset_y", 1)
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.07, 0.08, 0.11, 0.92)
	plate.border_color = Color(0.42, 0.46, 0.52, 0.95)
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(4)
	plate.content_margin_left = 5
	plate.content_margin_right = 5
	plate.content_margin_top = 2
	plate.content_margin_bottom = 2
	plate.shadow_color = Color(0, 0, 0, 0.35)
	plate.shadow_size = 2
	plate.shadow_offset = Vector2(0, 1)
	level_badge.add_theme_stylebox_override("normal", plate)


func _target_overhead_bar_visual_width() -> float:
	# Keep card bars visually consistent across units; per-sprite sizing looked uneven in combat.
	return UnitBarVisuals.overhead_bar_visual_width_px()


func _sprite_top_y_in_unit_space() -> float:
	if sprite == null or sprite.texture == null:
		return float(DEFAULT_CELL_SIZE) * 0.25
	var r: Rect2 = sprite.get_rect()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return float(DEFAULT_CELL_SIZE) * 0.25
	var xf: Transform2D = sprite.get_transform()
	var p0: Vector2 = xf * r.position
	var p1: Vector2 = xf * Vector2(r.position.x + r.size.x, r.position.y)
	var p2: Vector2 = xf * Vector2(r.position.x, r.position.y + r.size.y)
	var p3: Vector2 = xf * (r.position + r.size)
	return minf(minf(p0.y, p1.y), minf(p2.y, p3.y))


func _sprite_visual_height_in_unit_space() -> float:
	if sprite == null or sprite.texture == null:
		return float(DEFAULT_CELL_SIZE)
	var r: Rect2 = sprite.get_rect()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return float(DEFAULT_CELL_SIZE)
	var xf: Transform2D = sprite.get_transform()
	var p0: Vector2 = xf * r.position
	var p1: Vector2 = xf * Vector2(r.position.x + r.size.x, r.position.y)
	var p2: Vector2 = xf * Vector2(r.position.x, r.position.y + r.size.y)
	var p3: Vector2 = xf * (r.position + r.size)
	var min_y: float = minf(minf(p0.y, p1.y), minf(p2.y, p3.y))
	var max_y: float = maxf(maxf(p0.y, p1.y), maxf(p2.y, p3.y))
	return maxf(1.0, max_y - min_y)


func _sprite_bottom_y_in_unit_space() -> float:
	return _sprite_top_y_in_unit_space() + _sprite_visual_height_in_unit_space()


func _layout_overhead_bars() -> void:
	if health_bar == null:
		return

	var hp_scale: Vector2 = UnitBarVisuals.overhead_hp_scale()
	var hp_scale_x: float = maxf(absf(hp_scale.x), 0.001)
	var hp_scale_y: float = maxf(absf(hp_scale.y), 0.001)
	var hp_visual_w: float = _target_overhead_bar_visual_width()
	var hp_unscaled_w: float = hp_visual_w / hp_scale_x
	var hp_unscaled_h: float = UnitBarVisuals.overhead_hp_height_px()
	var hp_visual_h: float = hp_unscaled_h * hp_scale_y
	var hp_pos_y: float = -4.0
	if CampaignManager.interface_unit_bars_at_feet:
		var desired_hp_y: float = _sprite_bottom_y_in_unit_space() + OVERHEAD_FOOT_GAP_PX
		var hp_min_y: float = 2.0
		var hp_max_y: float = maxf(hp_min_y, float(DEFAULT_CELL_SIZE) - hp_visual_h - 2.0)
		hp_pos_y = clampf(desired_hp_y, hp_min_y, hp_max_y)
	else:
		var sprite_top_y: float = _sprite_top_y_in_unit_space()
		var sprite_visual_h: float = _sprite_visual_height_in_unit_space()
		var head_clearance: float = UnitBarVisuals.overhead_head_gap_px() + (sprite_visual_h * UnitBarVisuals.overhead_head_clearance_height_factor())
		var desired_hp_y_head: float = sprite_top_y - hp_visual_h - head_clearance
		hp_pos_y = clampf(desired_hp_y_head, -UnitBarVisuals.overhead_top_margin_px(), -4.0)

	health_bar.scale = hp_scale
	health_bar.custom_minimum_size = Vector2(hp_unscaled_w, hp_unscaled_h)
	health_bar.size = health_bar.custom_minimum_size
	health_bar.position = Vector2(
		(DEFAULT_CELL_SIZE - hp_visual_w) * 0.5,
		hp_pos_y
	)

	if exp_bar != null:
		var exp_scale: Vector2 = UnitBarVisuals.overhead_exp_scale()
		var exp_scale_x: float = maxf(absf(exp_scale.x), 0.001)
		var exp_visual_w: float = hp_visual_w * UnitBarVisuals.overhead_exp_width_ratio()
		var exp_unscaled_w: float = exp_visual_w / exp_scale_x
		var exp_unscaled_h: float = UnitBarVisuals.overhead_exp_height_px()

		exp_bar.scale = exp_scale
		exp_bar.custom_minimum_size = Vector2(exp_unscaled_w, exp_unscaled_h)
		exp_bar.size = exp_bar.custom_minimum_size
		exp_bar.position = Vector2(
			(DEFAULT_CELL_SIZE - exp_visual_w) * 0.5,
			health_bar.position.y + hp_visual_h + UnitBarVisuals.overhead_exp_gap_px()
		)

	if health_bar_delay != null:
		_sync_health_bar_delay_layout(false)
	_reposition_status_icon_strip_if_visible()


func _ensure_health_bar_delay() -> void:
	if health_bar == null:
		return
	if health_bar_delay == null or not is_instance_valid(health_bar_delay):
		health_bar_delay = get_node_or_null("HealthBarDelay") as ProgressBar
		if health_bar_delay == null:
			var d := ProgressBar.new()
			d.name = "HealthBarDelay"
			d.mouse_filter = Control.MOUSE_FILTER_IGNORE
			d.show_percentage = false
			d.clip_contents = false
			add_child(d)
			move_child(d, health_bar.get_index())
			health_bar_delay = d
	_apply_layered_health_bar_styles()


## Back bar draws the dark track + [i]trailing[/i] coral/red fill; front bar draws only green fill on a clear background so the lagging strip is visible between the two fills.
func _apply_layered_health_bar_styles() -> void:
	if health_bar == null:
		return
	if health_bar_delay != null:
		health_bar_delay.add_theme_stylebox_override("background", UnitBarVisuals.hp_track())
		health_bar_delay.add_theme_stylebox_override("fill", UnitBarVisuals.hp_delay_fill())
	health_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	health_bar.add_theme_stylebox_override("fill", UnitBarVisuals.hp_fill())


func _sync_health_bar_delay_layout(align_trail_to_main: bool = true) -> void:
	if health_bar == null or health_bar_delay == null:
		return
	health_bar_delay.scale = health_bar.scale
	health_bar_delay.position = health_bar.position
	health_bar_delay.size = health_bar.size
	health_bar_delay.offset_left = health_bar.offset_left
	health_bar_delay.offset_top = health_bar.offset_top
	health_bar_delay.offset_right = health_bar.offset_right
	health_bar_delay.offset_bottom = health_bar.offset_bottom
	health_bar_delay.custom_minimum_size = health_bar.custom_minimum_size
	health_bar_delay.z_index = maxi(health_bar.z_index - 1, 0)
	health_bar_delay.max_value = health_bar.max_value
	if align_trail_to_main:
		health_bar_delay.value = health_bar.value


## Call after tweens or direct [member health_bar] writes outside [method take_damage] so the trail stays aligned.
func snap_health_delay_to_main() -> void:
	if health_bar == null or health_bar_delay == null:
		return
	health_bar_delay.max_value = health_bar.max_value
	health_bar_delay.value = health_bar.value


func _refresh_level_badge() -> void:
	_ensure_level_badge_node()
	if level_badge == null or health_bar == null:
		return
	if not is_inside_tree():
		return
	level_badge.visible = true
	level_badge.text = "Lv. %d" % level
	level_badge.reset_size()
	level_badge.scale = health_bar.scale
	var hp_gr: Rect2 = health_bar.get_global_rect()
	if hp_gr.size.y < 1.0 or hp_gr.size.x < 1.0:
		call_deferred("_refresh_level_badge")
		return
	## Sibling of HealthBar: world top-left of the full bar, converted to unit space — full badge above the bar.
	var inset_x: float = 2.0
	var gap: float = 2.0
	var hp_tl_unit: Vector2 = to_local(hp_gr.position)
	var badge_h: float = level_badge.size.y * absf(level_badge.scale.y)
	level_badge.position = Vector2(hp_tl_unit.x + inset_x, hp_tl_unit.y - badge_h - gap)
	_reposition_status_icon_strip_if_visible()


## Default under-tile ring color from parent container (PlayerUnits / EnemyUnits / other).
func refresh_standard_team_glow() -> void:
	if team_glow == null or get_parent() == null:
		return
	var parent_name: String = get_parent().name
	if parent_name == "PlayerUnits":
		team_glow.color = Color(0.2, 0.5, 1.0, 0.3)
	elif parent_name == "EnemyUnits":
		team_glow.color = Color(1.0, 0.2, 0.2, 0.3)
	else:
		team_glow.color = Color(1.0, 1.0, 1.0, 0.0)


## Mock co-op only: tint TeamGlow so local vs partner-owned units read at a glance (BattleField applies when ownership is active).
func apply_mock_coop_owner_visual(owner_key: String) -> void:
	if team_glow == null:
		return
	var parent_name: String = get_parent().name if get_parent() != null else ""
	if owner_key == "remote":
		team_glow.color = Color(1.0, 0.58, 0.12, 0.74)
		_mock_coop_owner_sprite_tint = Color(1.08, 0.98, 0.9, 1.0)
		if sprite != null:
			sprite.self_modulate = _mock_coop_owner_sprite_tint
		return
	if owner_key != "local":
		refresh_standard_team_glow()
		_mock_coop_owner_sprite_tint = Color.WHITE
		if sprite != null:
			sprite.self_modulate = Color.WHITE
		return
	if parent_name == "PlayerUnits":
		team_glow.color = Color(0.08, 0.56, 1.0, 0.62)
	elif parent_name == "AllyUnits":
		team_glow.color = Color(0.16, 0.88, 0.56, 0.58)
	else:
		refresh_standard_team_glow()
	_mock_coop_owner_sprite_tint = Color(0.94, 1.0, 1.08, 1.0)
	if sprite != null:
		sprite.self_modulate = _mock_coop_owner_sprite_tint


func _get_battlefield_node() -> Node:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return null
	return parent_node.get_parent()


func _set_remote_coop_pending_death_visual() -> void:
	set_meta("coop_remote_pending_death", true)
	if sprite != null:
		sprite.visible = false
	if health_bar != null:
		health_bar.visible = false
	if health_bar_delay != null:
		health_bar_delay.visible = false
	if exp_bar != null:
		exp_bar.visible = false
	if team_glow != null:
		team_glow.visible = false
	if defend_icon != null:
		defend_icon.visible = false
	_hide_status_icon_strip()
	if level_badge != null:
		level_badge.visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func clear_remote_coop_pending_death_visual() -> void:
	if has_meta("coop_remote_pending_death"):
		remove_meta("coop_remote_pending_death")
	if death_sound_player != null and death_sound_player.playing:
		death_sound_player.stop()
	if sprite != null:
		sprite.visible = true
		sprite.self_modulate = _mock_coop_owner_sprite_tint
	if health_bar != null:
		health_bar.visible = true
	if health_bar_delay != null:
		health_bar_delay.visible = true
	if exp_bar != null:
		exp_bar.visible = true
	if team_glow != null:
		team_glow.visible = true
	if defend_icon != null:
		defend_icon.visible = is_defending
	_refresh_combat_status_icon_strip()
	if level_badge != null:
		level_badge.visible = true
		_refresh_level_badge()
	snap_health_delay_to_main()
	_apply_overhead_bar_focus_state()
	process_mode = Node.PROCESS_MODE_INHERIT


func gain_exp(amount: int) -> void:
	experience += amount
	var required_exp = get_exp_required()
	
	if experience >= required_exp:
		# Loop in case they gained enough EXP to level up multiple times!
		while experience >= required_exp:
			# 1. Animate filling the bar to the max
			var fill_tween = create_tween()
			fill_tween.tween_property(exp_bar, "value", required_exp, EXP_BAR_TWEEN_DURATION)
			await fill_tween.finished
			
			# 2. Level up and deduct the cost
			experience -= required_exp
			level_up()
			
			# 3. Recalculate the NEW, higher requirement for the next level
			required_exp = get_exp_required()
			
			# 4. Reset the bar visually for the next loop
			exp_bar.max_value = required_exp
			exp_bar.value = 0
			
		# Animate whatever leftover EXP remains
		var remainder_tween = create_tween()
		remainder_tween.tween_property(exp_bar, "value", experience, EXP_BAR_TWEEN_DURATION)
	else:
		var tween: Tween = create_tween()
		tween.tween_property(exp_bar, "value", experience, EXP_BAR_TWEEN_DURATION)
		
func level_up() -> void:
	level += 1
	skill_points += 1
	
	# IMPORTANT: Use active_class_data so custom classes work correctly
	var cls = active_class_data
	
	# 1. Calculate Total Growth Rates (Unit + Class)
	var h_gr = data.hp_growth + (cls.hp_growth_bonus if cls else 0)
	var s_gr = data.str_growth + (cls.str_growth_bonus if cls else 0)
	var d_gr = data.def_growth + (cls.def_growth_bonus if cls else 0)
	var sp_gr = data.spd_growth + (cls.spd_growth_bonus if cls else 0)
	var a_gr = data.agi_growth + (cls.agi_growth_bonus if cls else 0)
	var m_gr = data.mag_growth + (cls.mag_growth_bonus if cls else 0)
	var r_gr = data.res_growth + (cls.res_growth_bonus if cls else 0)
	
	var gains = {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}
	var total_gains = 0
	
	# 2. Roll for Stats with "Epic Proc" Logic
	# Logic: If we pass the main check, we roll AGAIN against (Growth / 5).
	# If we pass that too, we get +2. Otherwise +1.
	
	if randi() % 100 < h_gr: 
		gains["hp"] = 2 if (randi() % 100 < (h_gr / 5)) else 1
		total_gains += gains["hp"]
		
	if randi() % 100 < s_gr: 
		gains["str"] = 2 if (randi() % 100 < (s_gr / 5)) else 1
		total_gains += gains["str"]
		
	if randi() % 100 < d_gr: 
		gains["def"] = 2 if (randi() % 100 < (d_gr / 5)) else 1
		total_gains += gains["def"]
		
	if randi() % 100 < sp_gr: 
		gains["spd"] = 2 if (randi() % 100 < (sp_gr / 5)) else 1
		total_gains += gains["spd"]
		
	if randi() % 100 < a_gr: 
		gains["agi"] = 2 if (randi() % 100 < (a_gr / 5)) else 1
		total_gains += gains["agi"]
		
	if randi() % 100 < m_gr: 
		gains["mag"] = 2 if (randi() % 100 < (m_gr / 5)) else 1
		total_gains += gains["mag"]
		
	if randi() % 100 < r_gr: 
		gains["res"] = 2 if (randi() % 100 < (r_gr / 5)) else 1
		total_gains += gains["res"]

	# 3. The Pity System (Guarantees at least one +1 if you were super unlucky)
	if total_gains == 0:
		var fallback_stats = ["hp", "str", "mag", "def", "res", "spd", "agi"]
		var lucky_stat = fallback_stats[randi() % fallback_stats.size()]
		gains[lucky_stat] = 1
		
	# BattleField.gd will automatically read the +2 and display it correctly!
	emit_signal("leveled_up", self, gains)
	_refresh_level_badge()


func _is_flying_move_unit() -> bool:
	return int(move_type) == int(ClassDataRef.MoveType.FLYING)


func _sprite_cell_center_offset() -> Vector2:
	return Vector2(float(DEFAULT_CELL_SIZE) * 0.5, float(DEFAULT_CELL_SIZE) * 0.5)


func _reset_flight_step_sprite_pose(scale_restore: Vector2 = Vector2.ZERO) -> void:
	if sprite == null:
		return
	sprite.rotation = 0.0
	sprite.position = _sprite_cell_center_offset()
	if scale_restore.length_squared() > 0.0001:
		sprite.scale = scale_restore


func _flight_polyline_pos(waypoints: PackedVector2Array, u: float, seg_count: int) -> Vector2:
	if u <= 0.0:
		return waypoints[0]
	if u >= float(seg_count):
		return waypoints[seg_count]
	var si: int = int(floor(u))
	var fr: float = u - float(si)
	return waypoints[si].lerp(waypoints[si + 1], fr)


func _flight_smoothstep01(t: float) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Clamped phase lengths so a minimum slice remains for horizontal travel.
func _flight_build_time_layout() -> Dictionary:
	var prep: float = maxf(FLIGHT_TIME_PREP_FRAC, 0.0)
	var take: float = maxf(FLIGHT_TIME_TAKEOFF_CLIMB_FRAC, 0.0)
	var hover: float = maxf(FLIGHT_TIME_LANDING_HOVER_FRAC, 0.0)
	var drop: float = maxf(FLIGHT_TIME_LANDING_DROP_FRAC, 0.0)
	var sum4: float = prep + take + hover + drop
	if sum4 > 0.88:
		var s: float = 0.88 / sum4
		prep *= s
		take *= s
		hover *= s
		drop *= s
	var span_travel: float = 1.0 - prep - take - hover - drop
	if span_travel < 0.07:
		var deficit: float = 0.07 - span_travel
		var pool: float = prep + take + hover + drop
		if pool > 0.0001:
			var factor: float = clampf((pool - deficit) / pool, 0.42, 1.0)
			prep *= factor
			take *= factor
			hover *= factor
			drop *= factor
		span_travel = 1.0 - prep - take - hover - drop
	var prep_e: float = prep
	var takeoff_e: float = prep + take
	var travel_done_e: float = takeoff_e + span_travel
	var drop_start: float = 1.0 - drop
	return {
		"prep_e": prep_e,
		"takeoff_e": takeoff_e,
		"travel_done_e": travel_done_e,
		"drop_start": drop_start,
	}


## Takeoff climb: strong ease-out + small overshoot near the top for a powerful leap.
func _flight_takeoff_climb_height_ratio(norm: float) -> float:
	var x: float = clampf(norm, 0.0, 1.0)
	var core: float = 1.0 - pow(1.0 - x, FLIGHT_TAKEOFF_LIFT_POWER)
	var bump: float = FLIGHT_TAKEOFF_APEX_OVERSHOOT * sin(PI * x) * (1.0 - x)
	return clampf(core + bump, 0.0, 1.12)


## How far along the drop timeline the horizontal gap to the tile closes (ease-in = hang back, then tuck in).
func _flight_landing_horizontal_blend(norm: float) -> float:
	var w: float = clampf(norm, 0.0, 1.0)
	return pow(w, FLIGHT_LANDING_FORWARD_EASE_POWER)


## [code]u[/code] targets: partial progress after takeoff arc, and a short-of-end hover point before the landing swoop.
func _flight_u_arc_targets(seg_count: int) -> Dictionary:
	var sc: float = float(maxi(seg_count, 1))
	var pull: float = clampf(FLIGHT_LANDING_U_PULLBACK, 0.07, sc * 0.52)
	if pull >= sc - 0.03:
		pull = clampf(sc * 0.24, 0.09, sc * 0.48)
	var u_preland: float = maxf(sc - pull, 0.0)
	var wish_takeoff: float = FLIGHT_TAKEOFF_U_FRAC_OF_PATH * sc
	var u_takeoff_max: float = minf(wish_takeoff, maxf(u_preland - 0.06, 0.08))
	return {"u_preland": u_preland, "u_takeoff_max": u_takeoff_max}


## Landing: height multiplier 1→0 over the drop phase (linger high, then fall).
func _flight_landing_drop_height_ratio(norm: float) -> float:
	var x: float = clampf(norm, 0.0, 1.0)
	return pow(1.0 - x, FLIGHT_LANDING_DROP_POWER)


func _flight_altitude_timed(tn: float, layout: Dictionary, cruise_height: float) -> float:
	var h: float = maxf(cruise_height, 0.0)
	var prep_e: float = float(layout.get("prep_e", 0.0))
	var takeoff_e: float = float(layout.get("takeoff_e", 0.0))
	var drop_start: float = float(layout.get("drop_start", 1.0))
	if tn < prep_e:
		return 0.0
	if tn < takeoff_e:
		var denom: float = takeoff_e - prep_e
		if denom < 0.0001:
			return h
		var w: float = clampf((tn - prep_e) / denom, 0.0, 1.0)
		return h * _flight_takeoff_climb_height_ratio(w)
	if tn < drop_start:
		return h
	var drop_span: float = 1.0 - drop_start
	if drop_span < 0.0001:
		return 0.0
	var wl: float = clampf((tn - drop_start) / drop_span, 0.0, 1.0)
	return h * _flight_landing_drop_height_ratio(wl)


func _flight_horizontal_u_timed(tn: float, layout: Dictionary, seg_count: int, u_arc: Dictionary) -> float:
	if seg_count <= 0:
		return 0.0
	var prep_e: float = float(layout.get("prep_e", 0.0))
	var takeoff_e: float = float(layout.get("takeoff_e", 0.0))
	var travel_done_e: float = float(layout.get("travel_done_e", 1.0))
	var drop_start: float = float(layout.get("drop_start", 1.0))
	var u_preland: float = float(u_arc.get("u_preland", float(seg_count)))
	var u_takeoff_max: float = float(u_arc.get("u_takeoff_max", 0.0))
	var scf: float = float(seg_count)
	if tn < prep_e:
		return 0.0
	if tn < takeoff_e:
		var denom: float = takeoff_e - prep_e
		if denom < 0.0001:
			return u_takeoff_max
		var w: float = clampf((tn - prep_e) / denom, 0.0, 1.0)
		return u_takeoff_max * pow(w, FLIGHT_TAKEOFF_HORIZONTAL_LAG_POWER)
	if tn < travel_done_e:
		var span: float = travel_done_e - takeoff_e
		if span < 0.0001:
			return u_preland
		var t: float = clampf((tn - takeoff_e) / span, 0.0, 1.0)
		return lerpf(u_takeoff_max, u_preland, _flight_smoothstep01(t))
	if tn < drop_start:
		return u_preland
	var drop_span: float = 1.0 - drop_start
	if drop_span < 0.0001:
		return scf
	var wl: float = clampf((tn - drop_start) / drop_span, 0.0, 1.0)
	return lerpf(u_preland, scf, _flight_landing_horizontal_blend(wl))


## Stretch/squash aligned to timed takeoff/landing (paired X/Y).
func _flight_apply_vertical_squish_timed(
	spr: Sprite2D, base_scale: Vector2, tn: float, layout: Dictionary
) -> void:
	var sy: float = 1.0
	var prep_e: float = float(layout.get("prep_e", 0.0))
	var takeoff_e: float = float(layout.get("takeoff_e", 0.0))
	var drop_start: float = float(layout.get("drop_start", 1.0))
	if prep_e > 0.0001 and tn < prep_e:
		var pr: float = clampf(tn / prep_e, 0.0, 1.0)
		sy = 1.0 - FLIGHT_PREP_SQUISH_DEPTH * _flight_smoothstep01(pr)
	elif takeoff_e > prep_e + 0.0001 and tn < takeoff_e:
		var xt: float = clampf((tn - prep_e) / (takeoff_e - prep_e), 0.0, 1.0)
		var e: float = sin(PI * xt)
		var pop: float = FLIGHT_TAKEOFF_POP_Y * exp(-xt * 6.2)
		sy = 1.0 + FLIGHT_TAKEOFF_STRETCH_Y * e + pop
	elif takeoff_e <= prep_e + 0.0001 and tn < takeoff_e:
		var xt2: float = clampf(tn / maxf(takeoff_e, 0.0001), 0.0, 1.0)
		var e2: float = sin(PI * xt2)
		var pop2: float = FLIGHT_TAKEOFF_POP_Y * exp(-xt2 * 6.2)
		sy = 1.0 + FLIGHT_TAKEOFF_STRETCH_Y * e2 + pop2
	elif tn >= drop_start - 0.0001:
		var span_drop: float = 1.0 - drop_start
		if span_drop > 0.0001:
			var xl: float = clampf((tn - drop_start) / span_drop, 0.0, 1.0)
			var e2: float = pow(xl, 1.7)
			sy = 1.0 - FLIGHT_LANDING_SQUISH_Y * e2
	var d: float = sy - 1.0
	var sx: float = 1.0 - d * FLIGHT_SQUISH_VOLUME_PAIR
	spr.scale = Vector2(base_scale.x * sx, base_scale.y * sy)


## Half-period positive sine only: neutral → power → neutral; no mirror swing (no rotation used).
func _flight_forward_stride_unit(elapsed: float, hz: float) -> float:
	var ph: float = elapsed * TAU * maxf(hz, 0.05)
	return pow(maxf(0.0, sin(ph)), FLIGHT_WING_FLAP_SHAPE)


## Same ground dash dust as [method BattleField.spawn_dash_effect]; [code]from_cell[/code] → [code]to_cell[/code] sets facing.
func _flight_spawn_dash_effect_cells(battlefield: Node, from_cell: Vector2i, to_cell: Vector2i) -> void:
	if battlefield == null or not battlefield.has_method("spawn_dash_effect"):
		return
	var cs: int = DEFAULT_CELL_SIZE
	var a: Vector2 = Vector2(float(from_cell.x * cs), float(from_cell.y * cs))
	var b: Vector2 = Vector2(float(to_cell.x * cs), float(to_cell.y * cs))
	battlefield.spawn_dash_effect(a, b)


static func _flight_shared_ellipse_shadow_texture() -> ImageTexture:
	if _flight_shared_ground_shadow_texture != null:
		return _flight_shared_ground_shadow_texture
	var w: int = 56
	var h: int = 22
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = (w - 1) * 0.5
	var cy: float = (h - 1) * 0.5
	var rx: float = float(w) * 0.42
	var ry: float = float(h) * 0.38
	for y in range(h):
		for x in range(w):
			var dx: float = (float(x) - cx) / rx
			var dy: float = (float(y) - cy) / ry
			var d2: float = dx * dx + dy * dy
			if d2 <= 1.0:
				var edge: float = sqrt(d2)
				var a: float = pow(1.0 - edge, 1.85) * 0.62
				img.set_pixel(x, y, Color(0, 0, 0, a))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_flight_shared_ground_shadow_texture = tex
	return tex


func _flight_ensure_ground_shadow() -> void:
	if _flight_ground_shadow != null:
		return
	var sh: Sprite2D = Sprite2D.new()
	sh.name = "FlightGroundShadow"
	sh.z_index = -8
	sh.position = Vector2(float(DEFAULT_CELL_SIZE) * 0.5, float(DEFAULT_CELL_SIZE) * 0.86)
	sh.texture = _flight_shared_ellipse_shadow_texture()
	sh.modulate = Color(1, 1, 1, 0.0)
	sh.visible = false
	add_child(sh)
	_flight_ground_shadow = sh


func _flight_show_ground_shadow() -> void:
	_flight_ensure_ground_shadow()
	if _flight_ground_shadow != null:
		_flight_ground_shadow.visible = true


func _flight_hide_ground_shadow() -> void:
	if _flight_ground_shadow != null:
		_flight_ground_shadow.visible = false


func _flight_update_ground_shadow(alt_px: float) -> void:
	if _flight_ground_shadow == null or not _flight_ground_shadow.visible:
		return
	var h_ref: float = maxf(FLIGHT_CRUISE_HEIGHT_PX * 1.18, 1.0)
	var t: float = clampf(alt_px / h_ref, 0.0, 1.0)
	var a: float = lerpf(FLIGHT_SHADOW_ALPHA_GROUND, FLIGHT_SHADOW_ALPHA_CRUISE, t)
	_flight_ground_shadow.modulate = Color(1, 1, 1, a)
	var sx: float = lerpf(FLIGHT_SHADOW_SCALE_XYZ_GROUND.x, FLIGHT_SHADOW_SCALE_XYZ_CRUISE.x, t)
	var sy: float = lerpf(FLIGHT_SHADOW_SCALE_XYZ_GROUND.y, FLIGHT_SHADOW_SCALE_XYZ_CRUISE.y, t)
	_flight_ground_shadow.scale = Vector2(sx, sy)


func _flight_configure_loop_stream(original: AudioStream) -> AudioStream:
	if original == null:
		return null
	var d: AudioStream = original.duplicate()
	if d is AudioStreamMP3:
		(d as AudioStreamMP3).loop = true
	elif d is AudioStreamOggVorbis:
		(d as AudioStreamOggVorbis).loop = true
	elif d is AudioStreamWAV:
		(d as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return d


func _flight_ensure_audio_players() -> void:
	if _flight_sfx_player != null:
		return
	_flight_sfx_player = AudioStreamPlayer.new()
	_flight_sfx_player.name = "FlightSfxPlayer"
	add_child(_flight_sfx_player)
	_flight_cruise_player = AudioStreamPlayer.new()
	_flight_cruise_player.name = "FlightCruisePlayer"
	add_child(_flight_cruise_player)


func _flight_play_flight_one_shot(stream: AudioStream, volume_db: float, pitch_scale: float = 1.0) -> void:
	if stream == null:
		return
	_flight_ensure_audio_players()
	if _flight_sfx_player == null:
		return
	_flight_sfx_player.stream = stream
	_flight_sfx_player.volume_db = volume_db
	_flight_sfx_player.pitch_scale = maxf(pitch_scale, 0.01)
	_flight_sfx_player.play()


func _flight_start_cruise_loop() -> void:
	if flight_sound_cruise_loop == null:
		return
	_flight_ensure_audio_players()
	if _flight_cruise_player == null:
		return
	if _flight_cruise_player.playing:
		return
	_flight_cruise_player.stream = _flight_configure_loop_stream(flight_sound_cruise_loop)
	_flight_cruise_player.volume_db = flight_audio_cruise_db
	_flight_cruise_player.play()


func _flight_stop_cruise_audio() -> void:
	if _flight_cruise_player != null and _flight_cruise_player.playing:
		_flight_cruise_player.stop()


func _flight_cleanup_move_fx() -> void:
	_flight_stop_cruise_audio()
	_flight_hide_ground_shadow()


## One smooth vault along the whole path (not per-tile). Fires [method BattleField.on_unit_committed_move_enter_cell] at each tile boundary.
func _move_along_path_flying_continuous(path: Array[Vector2i], battlefield: Node) -> void:
	var seg_count: int = path.size() - 1
	if seg_count <= 0:
		return
	var cs: float = float(DEFAULT_CELL_SIZE)
	var waypoints: PackedVector2Array = PackedVector2Array()
	waypoints.resize(path.size())
	for i in path.size():
		waypoints[i] = Vector2(float(path[i].x) * cs, float(path[i].y) * cs)
	var total_duration: float = CampaignManager.unit_move_speed * float(seg_count)
	total_duration = maxf(total_duration, 0.04)
	var base_sp: Vector2 = _sprite_cell_center_offset()
	var scale_base: Vector2 = sprite.scale if sprite != null else Vector2.ONE
	var tree: SceneTree = get_tree()
	if tree == null:
		_flight_cleanup_move_fx()
		position = waypoints[seg_count]
		_reset_flight_step_sprite_pose(scale_base)
		return
	_flight_show_ground_shadow()
	var t_elapsed: float = 0.0
	var last_usec: int = Time.get_ticks_usec()
	var next_enter_idx: int = 1
	var time_layout: Dictionary = _flight_build_time_layout()
	var u_arc: Dictionary = _flight_u_arc_targets(seg_count)
	var prep_e: float = float(time_layout.get("prep_e", 0.0))
	var takeoff_e: float = float(time_layout.get("takeoff_e", 0.0))
	var drop_start: float = float(time_layout.get("drop_start", 1.0))
	var prev_tn: float = -1.0
	var did_takeoff_dash: bool = false
	var did_landing_dash: bool = false
	var did_prep_sfx: bool = false
	var did_takeoff_sfx: bool = false
	var did_start_cruise_sfx: bool = false
	var did_landing_sfx: bool = false
	while true:
		await tree.process_frame
		if not is_instance_valid(self):
			return
		var now_usec: int = Time.get_ticks_usec()
		t_elapsed += float(now_usec - last_usec) / 1_000_000.0
		last_usec = now_usec
		t_elapsed = minf(t_elapsed, total_duration)
		var tn: float = t_elapsed / total_duration
		if battlefield != null and battlefield.has_method("spawn_dash_effect") and path.size() >= 2:
			if not did_takeoff_dash:
				var cross_prep: bool = (prep_e <= 0.0001 and prev_tn < 0.0) or (prev_tn < prep_e and tn >= prep_e)
				if cross_prep:
					_flight_spawn_dash_effect_cells(battlefield, path[0], path[1])
					did_takeoff_dash = true
			if not did_landing_dash and prev_tn < drop_start and tn >= drop_start:
				_flight_spawn_dash_effect_cells(battlefield, path[path.size() - 2], path[path.size() - 1])
				did_landing_dash = true
		if not did_prep_sfx and prep_e > 0.0001 and prev_tn < 0.0 and tn >= 0.0:
			_flight_play_flight_one_shot(flight_sound_prep, flight_audio_prep_db)
			did_prep_sfx = true
		if not did_takeoff_sfx:
			var cross_commit: bool = (prep_e <= 0.0001 and prev_tn < 0.0) or (prev_tn < prep_e and tn >= prep_e)
			if cross_commit:
				_flight_play_flight_one_shot(
					flight_sound_dragon_takeoff_land, flight_audio_takeoff_db, flight_audio_dragon_takeoff_pitch_scale
				)
				did_takeoff_sfx = true
		if not did_start_cruise_sfx and prev_tn < takeoff_e and tn >= takeoff_e:
			_flight_start_cruise_loop()
			did_start_cruise_sfx = true
		if not did_landing_sfx and prev_tn < drop_start and tn >= drop_start:
			_flight_stop_cruise_audio()
			_flight_play_flight_one_shot(
				flight_sound_dragon_takeoff_land, flight_audio_land_db, flight_audio_dragon_land_pitch_scale
			)
			did_landing_sfx = true
		prev_tn = tn
		var u: float = _flight_horizontal_u_timed(tn, time_layout, seg_count, u_arc)
		var along: Vector2 = _flight_polyline_pos(waypoints, u, seg_count)
		var alt: float = _flight_altitude_timed(tn, time_layout, FLIGHT_CRUISE_HEIGHT_PX)
		position = along + Vector2(0.0, -alt)
		_flight_update_ground_shadow(alt)
		var seg_i: int = clampi(int(floor(u)), 0, seg_count - 1)
		var face_idx: int = mini(seg_i + 1, path.size() - 1)
		look_at_pos(path[face_idx])
		if sprite != null:
			_flight_apply_vertical_squish_timed(sprite, scale_base, tn, time_layout)
			var in_cruise: bool = tn >= takeoff_e and tn < drop_start
			if in_cruise:
				var flap_mul: float = FLIGHT_WING_FLAP_CRUISE_MUL
				var stride: float = _flight_forward_stride_unit(t_elapsed, FLIGHT_WING_FLAP_HZ * flap_mul)
				var fh: float = -1.0 if sprite.flip_h else 1.0
				var d: float = FLIGHT_STRIDE_DIAG_PX * flap_mul
				sprite.position = base_sp + Vector2(fh * d * stride, -d * stride * 0.68)
				sprite.rotation = 0.0
			else:
				sprite.position = base_sp
				sprite.rotation = 0.0
		if battlefield != null and battlefield.has_method("on_unit_committed_move_enter_cell"):
			while next_enter_idx <= seg_count and u >= float(next_enter_idx) - 0.0001:
				await battlefield.on_unit_committed_move_enter_cell(self, path[next_enter_idx])
				if not is_instance_valid(self):
					return
				next_enter_idx += 1
		if t_elapsed >= total_duration:
			break
	while next_enter_idx <= seg_count and battlefield != null and battlefield.has_method("on_unit_committed_move_enter_cell"):
		await battlefield.on_unit_committed_move_enter_cell(self, path[next_enter_idx])
		if not is_instance_valid(self):
			return
		next_enter_idx += 1
	_flight_cleanup_move_fx()
	position = waypoints[seg_count]
	_reset_flight_step_sprite_pose(scale_base)


func move_along_path(path: Array[Vector2i]) -> void:
	# We check <= 1 so the wind doesn't spawn if they just click themselves to wait
	if path.size() <= 1:
		return
		
	# Ground: full-path dash. Fliers: dash only on takeoff/landing in [method _move_along_path_flying_continuous].
	var battlefield: Node = get_parent().get_parent() if get_parent() != null else null
	if battlefield != null and battlefield.has_method("spawn_dash_effect") and not _is_flying_move_unit():
		var cs: int = DEFAULT_CELL_SIZE
		var start_pixel := Vector2(path[0].x * cs, path[0].y * cs)
		var end_pixel := Vector2(path[-1].x * cs, path[-1].y * cs)
		battlefield.spawn_dash_effect(start_pixel, end_pixel)
		
	has_moved = true

	if _is_flying_move_unit():
		await _move_along_path_flying_continuous(path, battlefield)
	else:
		# Walkers: one step at a time so hazards (e.g. fire tiles) resolve on real entry, not path preview.
		for i in range(1, path.size()):
			if not is_instance_valid(self):
				return
			var grid_pos: Vector2i = path[i]
			look_at_pos(grid_pos)
			var world_target := Vector2(grid_pos.x * DEFAULT_CELL_SIZE, grid_pos.y * DEFAULT_CELL_SIZE)
			var step_tween: Tween = create_tween()
			step_tween.tween_property(self, "position", world_target, CampaignManager.unit_move_speed)
			await step_tween.finished
			if not is_instance_valid(self):
				return
			if battlefield != null and battlefield.has_method("on_unit_committed_move_enter_cell"):
				await battlefield.on_unit_committed_move_enter_cell(self, grid_pos)
			if not is_instance_valid(self):
				return

	if not is_instance_valid(self):
		return
	emit_signal("moved", path[path.size() - 1])
	
## Emits [signal died], hides visuals, optionally waits for death sound, then [method Node.queue_free].
func die(killer: Node2D = null) -> void:
	var battlefield: Node = _get_battlefield_node()
	var will_collapse_to_bone_pile: bool = false
	if battlefield != null and battlefield.has_method("_register_skeleton_bone_pile_if_applicable"):
		battlefield._register_skeleton_bone_pile_if_applicable(self, killer)
		if battlefield.has_method("_unit_has_pending_skeleton_bone_pile_payload"):
			will_collapse_to_bone_pile = battlefield._unit_has_pending_skeleton_bone_pile_payload(self)

	if data != null and data.death_sound != null and death_sound_player != null:
		death_sound_player.stream = data.death_sound
		death_sound_player.pitch_scale = randf_range(0.9, 1.1)
		death_sound_player.play()
	UnitCombatStatusHelpers.clear_all(self)
	emit_signal("died", self, killer)
	if battlefield != null and battlefield.has_method("is_coop_remote_combat_replay_active") and battlefield.is_coop_remote_combat_replay_active():
		_set_remote_coop_pending_death_visual()
		return

	if health_bar != null:
		health_bar.visible = false
	if health_bar_delay != null:
		health_bar_delay.visible = false
	if exp_bar != null:
		exp_bar.visible = false
	if team_glow != null:
		team_glow.visible = false
	if defend_icon != null:
		defend_icon.visible = false
	_hide_status_icon_strip()
	if level_badge != null:
		level_badge.visible = false

	if will_collapse_to_bone_pile and battlefield != null and battlefield.has_method("_await_skeleton_collapse_to_bone_pile"):
		await battlefield._await_skeleton_collapse_to_bone_pile(self)
	elif sprite != null:
		sprite.visible = false

	if death_sound_player != null and death_sound_player.stream != null:
		await death_sound_player.finished
	queue_free()

## Reduces current_hp by [amount], plays bar/flash tweens, grants EXP to [attacker]. Calls [method die] if HP reaches 0.
func take_damage(amount: int, attacker: Node2D = null) -> void:
	var hp_before := current_hp
	current_hp -= amount
	if current_hp < 0:
		current_hp = 0

	if _hp_damage_tween != null and _hp_damage_tween.is_valid():
		_hp_damage_tween.kill()
	_hp_damage_tween = null

	var bar_tween: Tween = null
	if health_bar != null:
		_ensure_health_bar_delay()
		_sync_health_bar_delay_layout(false)
		health_bar.max_value = max_hp
		if health_bar_delay != null:
			health_bar_delay.max_value = max_hp
		health_bar.value = float(hp_before)
		if health_bar_delay != null:
			health_bar_delay.value = maxf(health_bar_delay.value, float(hp_before))

		bar_tween = create_tween()
		bar_tween.set_parallel(true)
		bar_tween.tween_property(health_bar, "value", float(current_hp), HEALTH_BAR_LOSS_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if health_bar_delay != null:
			bar_tween.tween_property(health_bar_delay, "value", float(current_hp), HEALTH_BAR_DELAY_TRAIL_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_hp_damage_tween = bar_tween
	var flash: Tween = create_tween()
	flash.tween_property(self, "modulate", Color.RED, DAMAGE_FLASH_DURATION)
	flash.tween_property(self, "modulate", base_color, DAMAGE_FLASH_DURATION)
	if bar_tween != null:
		await bar_tween.finished
	else:
		await flash.finished
	
	if current_hp <= 0:
		if attacker != null and attacker.has_method("gain_exp"):
			attacker.gain_exp(50) 
		
		# --- CHANGED: Call the dedicated die() function instead of queue_free ---
		die(attacker)
	else:
		if attacker != null and attacker.has_method("gain_exp"):
			attacker.gain_exp(15)
		emit_signal("damaged", current_hp)

func has_combat_status(status_id: String) -> bool:
	return UnitCombatStatusHelpers.has_status(self, status_id)


func add_combat_status(status_id: String, opts: Dictionary = {}) -> void:
	UnitCombatStatusHelpers.add_status(self, status_id, opts)
	refresh_combat_status_sprite_tint()


func remove_combat_status(status_id: String) -> void:
	UnitCombatStatusHelpers.remove_status(self, status_id)
	refresh_combat_status_sprite_tint()


func export_combat_statuses_wire() -> Array:
	return UnitCombatStatusHelpers.export_wire(self)


func import_combat_statuses_wire(raw: Variant) -> void:
	UnitCombatStatusHelpers.import_wire(self, raw)
	refresh_combat_status_sprite_tint()


## Human-readable status names for hover popups / non-BBCode UI.
func get_active_combat_status_plain_lines() -> PackedStringArray:
	return UnitCombatStatusHelpers.build_plain_lines(self)


## Grouped human-readable lines for battlefield hover popup columns.
func get_active_combat_status_grouped_lines(include_descriptions: bool = false) -> Dictionary:
	return UnitCombatStatusHelpers.build_plain_groups(self, include_descriptions)


## Compact hash-like token for status popup refresh guards.
func get_combat_status_signature() -> String:
	return UnitCombatStatusHelpers.build_signature(self)


## Returns BBCode fragments for battle HUD (ongoing effects).
func get_active_combat_status_bbcode_badges() -> PackedStringArray:
	return UnitCombatStatusHelpers.build_bbcode_badges(self)


func _hide_status_icon_strip() -> void:
	for nm: String in ["StatusBuffStrip", "StatusDebuffStrip", "StatusIconStrip"]:
		var n: Node = get_node_or_null(nm)
		if n != null:
			n.visible = false


func _append_strip_children(strip: Node2D, into_sprites: Array[Sprite2D]) -> Label:
	into_sprites.clear()
	var overflow: Label = null
	for ch in strip.get_children():
		if ch is Sprite2D:
			into_sprites.append(ch as Sprite2D)
		elif ch is Label and str(ch.name) == "StatusOverflow":
			overflow = ch as Label
	return overflow


func _create_status_strip_package(strip_node_name: String, z_index: int, initial_position: Vector2) -> Node2D:
	var strip := Node2D.new()
	strip.name = strip_node_name
	strip.z_index = z_index
	strip.position = initial_position
	strip.visible = false
	add_child(strip)
	for i in range(STATUS_STRIP_MAX_ICONS):
		var spr := Sprite2D.new()
		spr.name = "StripIcon%d" % i
		spr.visible = false
		spr.centered = true
		strip.add_child(spr)
	var ol := Label.new()
	ol.name = "StatusOverflow"
	ol.visible = false
	ol.z_index = 1
	ol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ol.add_theme_font_size_override("font_size", 11)
	ol.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1.0))
	ol.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 1.0))
	ol.add_theme_constant_override("outline_size", 3)
	strip.add_child(ol)
	return strip


func _ensure_status_strips() -> void:
	if (
		_status_buff_strip != null
		and is_instance_valid(_status_buff_strip)
		and _status_debuff_strip != null
		and is_instance_valid(_status_debuff_strip)
	):
		return
	if _status_debuff_strip == null or not is_instance_valid(_status_debuff_strip):
		var ex_d: Node = get_node_or_null("StatusDebuffStrip")
		if ex_d is Node2D:
			_status_debuff_strip = ex_d as Node2D
			_status_debuff_overflow = _append_strip_children(_status_debuff_strip, _status_debuff_sprites)
		else:
			_status_debuff_strip = _create_status_strip_package(
				"StatusDebuffStrip",
				STATUS_DEBUFF_STRIP_Z_INDEX,
				Vector2(float(DEFAULT_CELL_SIZE) * 0.5, STATUS_STRIP_FALLBACK_Y)
			)
			_status_debuff_overflow = _append_strip_children(_status_debuff_strip, _status_debuff_sprites)
	if _status_buff_strip == null or not is_instance_valid(_status_buff_strip):
		var ex_b: Node = get_node_or_null("StatusBuffStrip")
		if ex_b is Node2D:
			_status_buff_strip = ex_b as Node2D
			_status_buff_overflow = _append_strip_children(_status_buff_strip, _status_buff_sprites)
		else:
			_status_buff_strip = _create_status_strip_package(
				"StatusBuffStrip",
				STATUS_BUFF_STRIP_Z_INDEX,
				Vector2(float(DEFAULT_CELL_SIZE) * 0.5, STATUS_STRIP_FALLBACK_Y)
			)
			_status_buff_overflow = _append_strip_children(_status_buff_strip, _status_buff_sprites)


func _gather_tactical_status_textures_by_buff_flag(want_buff: bool) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	CombatStatusRegistry.ensure_loaded()
	for e in combat_statuses:
		if not e is Dictionary:
			continue
		var sid: String = str((e as Dictionary).get("id", "")).strip_edges()
		if sid == "":
			continue
		var sdef: CombatStatusData = CombatStatusRegistry.get_optional(sid)
		if sdef == null or sdef.tactical_icon == null:
			continue
		var is_buff: bool = str(sdef.hover_group).strip_edges().to_lower() == "buff"
		if is_buff == want_buff:
			out.append(sdef.tactical_icon)
	return out


func _apply_overflow_trim(textures: Array[Texture2D]) -> Dictionary:
	var tex_list: Array[Texture2D] = []
	for t in textures:
		tex_list.append(t)
	var overflow_n: int = 0
	if tex_list.size() > STATUS_STRIP_MAX_ICONS:
		overflow_n = tex_list.size() - (STATUS_STRIP_MAX_ICONS - 1)
		var cap: int = STATUS_STRIP_MAX_ICONS - 1
		var trimmed: Array[Texture2D] = []
		for i in range(cap):
			trimmed.append(tex_list[i])
		tex_list = trimmed
	return {"textures": tex_list, "overflow": overflow_n}


func _layout_one_status_strip(
	strip: Node2D,
	sprites: Array[Sprite2D],
	overflow_lbl: Label,
	textures: Array[Texture2D],
	overflow_extra: int
) -> void:
	if strip == null:
		return
	var n: int = textures.size()
	for i in range(sprites.size()):
		var spr: Sprite2D = sprites[i]
		if i < n:
			spr.texture = textures[i]
			spr.scale = Vector2(STATUS_STRIP_ICON_SCALE, STATUS_STRIP_ICON_SCALE)
			spr.visible = true
		else:
			spr.visible = false
	var label_w: float = 0.0
	if overflow_extra > 0 and overflow_lbl != null:
		overflow_lbl.text = "+%d" % overflow_extra
		overflow_lbl.visible = true
		label_w = 22.0
	else:
		if overflow_lbl != null:
			overflow_lbl.visible = false
	var widths: Array[float] = []
	var total: float = 0.0
	var sc: float = STATUS_STRIP_ICON_SCALE
	for i in n:
		var sz: Vector2 = textures[i].get_size()
		var w: float = sz.x * sc
		widths.append(w)
		total += w
	if n > 1:
		total += float(n - 1) * STATUS_STRIP_GAP_PX
	if label_w > 0.0:
		total += label_w + STATUS_STRIP_GAP_PX
	var x: float = -total * 0.5
	for i in n:
		var spr_i: Sprite2D = sprites[i]
		var wi: float = widths[i]
		spr_i.position = Vector2(x + wi * 0.5, 0.0)
		x += wi + STATUS_STRIP_GAP_PX
	if overflow_extra > 0 and overflow_lbl != null:
		overflow_lbl.position = Vector2(x + 2.0, -10.0)


func _compute_strip_row_half_height(sprites: Array[Sprite2D], overflow_lbl: Label) -> float:
	var max_h: float = 8.0
	for spr in sprites:
		if spr.visible and spr.texture != null:
			max_h = maxf(max_h, spr.texture.get_size().y * absf(spr.scale.y))
	if overflow_lbl != null and overflow_lbl.visible:
		max_h = maxf(max_h, 16.0)
	return max_h * 0.5


## Buff row: just above the HP bar, centered in space to the right of the level badge.
func _position_buff_strip_above_health_bar() -> void:
	if _status_buff_strip == null or not is_instance_valid(_status_buff_strip):
		return
	var row_half: float = _compute_strip_row_half_height(_status_buff_sprites, _status_buff_overflow)
	if health_bar == null or not health_bar.visible:
		_status_buff_strip.position = Vector2(float(DEFAULT_CELL_SIZE) * 0.5, STATUS_STRIP_FALLBACK_Y)
		return
	var hp_gr: Rect2 = health_bar.get_global_rect()
	if hp_gr.size.x < 1.0 or hp_gr.size.y < 1.0:
		call_deferred("_reposition_status_icon_strip_if_visible")
		return
	var hp_tl: Vector2 = to_local(hp_gr.position)
	var hp_br: Vector2 = to_local(hp_gr.position + Vector2(hp_gr.size.x, hp_gr.size.y))
	var hp_left: float = minf(hp_tl.x, hp_br.x)
	var hp_right: float = maxf(hp_tl.x, hp_br.x)
	var hp_top: float = minf(hp_tl.y, hp_br.y)
	var strip_cy: float = hp_top - STATUS_STRIP_ABOVE_HP_GAP_PX - row_half
	var center_x: float = (hp_left + hp_right) * 0.5
	if level_badge != null and level_badge.visible:
		var bg: Rect2 = level_badge.get_global_rect()
		var b_tl: Vector2 = to_local(bg.position)
		var b_br: Vector2 = to_local(bg.position + Vector2(bg.size.x, bg.size.y))
		var b_right: float = maxf(b_tl.x, b_br.x)
		var b_top: float = minf(b_tl.y, b_br.y)
		var b_bot: float = maxf(b_tl.y, b_br.y)
		var usable_left: float = maxf(hp_left, b_right + STATUS_STRIP_BADGE_H_MARGIN_PX)
		if usable_left < hp_right - 6.0:
			center_x = (usable_left + hp_right) * 0.5
		var s_top: float = strip_cy - row_half
		var s_bot: float = strip_cy + row_half
		if s_bot > b_top - 0.5 and s_top < b_bot + 0.5:
			strip_cy = b_top - STATUS_STRIP_ABOVE_HP_GAP_PX - row_half
	_status_buff_strip.position = Vector2(center_x, strip_cy)


## Debuff row: centered at feet (same anchor as legacy PoisonedIcon).
func _position_debuff_strip_at_feet() -> void:
	if _status_debuff_strip == null or not is_instance_valid(_status_debuff_strip):
		return
	_status_debuff_strip.position = Vector2(float(DEFAULT_CELL_SIZE) * 0.5, STATUS_STRIP_FALLBACK_Y)


func _reposition_status_icon_strip_if_visible() -> void:
	if _status_buff_strip != null and is_instance_valid(_status_buff_strip) and _status_buff_strip.visible:
		_position_buff_strip_above_health_bar()
	if _status_debuff_strip != null and is_instance_valid(_status_debuff_strip) and _status_debuff_strip.visible:
		_position_debuff_strip_at_feet()


func _sync_status_strip_modulate_vs_exhaustion() -> void:
	_ensure_status_strips()
	var child_mod: Color
	if is_exhausted:
		var dim: Color = _exhausted_root_modulate()
		const EPS: float = 0.001
		child_mod = Color(
			base_color.r / maxf(dim.r, EPS),
			base_color.g / maxf(dim.g, EPS),
			base_color.b / maxf(dim.b, EPS),
			base_color.a / maxf(dim.a, EPS)
		)
	else:
		child_mod = Color.WHITE
	for strip in [_status_buff_strip, _status_debuff_strip]:
		if strip == null or not is_instance_valid(strip):
			continue
		for ch in strip.get_children():
			if ch is CanvasItem:
				(ch as CanvasItem).modulate = child_mod


func _refresh_combat_status_icon_strip() -> void:
	_ensure_status_strips()
	if _status_buff_strip == null or _status_debuff_strip == null:
		return
	_sync_status_strip_modulate_vs_exhaustion()
	if has_meta("coop_remote_pending_death") or current_hp <= 0:
		_status_buff_strip.visible = false
		_status_debuff_strip.visible = false
		return
	var raw_buffs: Array[Texture2D] = _gather_tactical_status_textures_by_buff_flag(true)
	var raw_debuffs: Array[Texture2D] = _gather_tactical_status_textures_by_buff_flag(false)
	var buff_pack: Dictionary = _apply_overflow_trim(raw_buffs)
	var deb_pack: Dictionary = _apply_overflow_trim(raw_debuffs)
	var buff_tex: Array[Texture2D] = buff_pack["textures"]
	var buff_ov: int = int(buff_pack["overflow"])
	var deb_tex: Array[Texture2D] = deb_pack["textures"]
	var deb_ov: int = int(deb_pack["overflow"])
	var any_buff: bool = not buff_tex.is_empty() or buff_ov > 0
	var any_deb: bool = not deb_tex.is_empty() or deb_ov > 0
	if not any_buff:
		_status_buff_strip.visible = false
	else:
		_layout_one_status_strip(_status_buff_strip, _status_buff_sprites, _status_buff_overflow, buff_tex, buff_ov)
		_status_buff_strip.visible = true
		_position_buff_strip_above_health_bar()
	if not any_deb:
		_status_debuff_strip.visible = false
	else:
		_layout_one_status_strip(_status_debuff_strip, _status_debuff_sprites, _status_debuff_overflow, deb_tex, deb_ov)
		_status_debuff_strip.visible = true
		_position_debuff_strip_at_feet()


func refresh_combat_status_sprite_tint() -> void:
	_refresh_combat_status_icon_strip()
	if sprite == null:
		return
	if _selection_pulse_active:
		return
	if UnitCombatStatusHelpers.has_status(self, UnitCombatStatusHelpers.ID_BONE_TOXIN):
		_ensure_bone_toxin_pulse_running()
	else:
		_stop_bone_toxin_pulse()
		sprite.modulate = Color.WHITE


func _stop_bone_toxin_pulse() -> void:
	if _bone_toxin_pulse_tween != null and _bone_toxin_pulse_tween.is_valid():
		_bone_toxin_pulse_tween.kill()
	_bone_toxin_pulse_tween = null


func _ensure_bone_toxin_pulse_running() -> void:
	if sprite == null:
		return
	if _bone_toxin_pulse_tween != null and _bone_toxin_pulse_tween.is_valid():
		return
	sprite.modulate = BONE_TOXIN_PULSE_MODULATE_DIM
	_bone_toxin_pulse_tween = create_tween().set_loops()
	_bone_toxin_pulse_tween.tween_property(
		sprite, "modulate", BONE_TOXIN_PULSE_MODULATE_BRIGHT, BONE_TOXIN_PULSE_HALF_PERIOD_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bone_toxin_pulse_tween.tween_property(
		sprite, "modulate", BONE_TOXIN_PULSE_MODULATE_DIM, BONE_TOXIN_PULSE_HALF_PERIOD_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Clears has_moved, is_exhausted, is_defending; resets poise meta and stagger visuals.
func _exhausted_root_modulate() -> Color:
	var m: Color = base_color * EXHAUSTED_MODULATE
	return Color(
		maxf(m.r, EXHAUSTED_CHANNEL_FLOOR),
		maxf(m.g, EXHAUSTED_CHANNEL_FLOOR),
		maxf(m.b, EXHAUSTED_CHANNEL_FLOOR),
		m.a
	)


func reset_turn() -> void:
	UnitCombatStatusHelpers.promote_legacy_metas_to_status_list(self)
	UnitCombatStatusHelpers.expire_turn_start_statuses(self)

	has_moved = false
	move_points_used_this_turn = 0.0
	in_canto_phase = false
	canto_move_budget = 0.0
	is_exhausted = false
	is_defending = false
	if defend_icon != null:
		defend_icon.visible = false
	modulate = base_color
	_sync_status_strip_modulate_vs_exhaustion()
	
	# --- POISE RECOVERY ---
	if has_meta("current_poise"):
		remove_meta("current_poise")
	if has_meta("is_staggered_this_combat"):
		remove_meta("is_staggered_this_combat")
		
	set_staggered_visuals(false)	
	update_poise_visuals()

	if has_meta("rookie_villager_desperate_turn"):
		remove_meta("rookie_villager_desperate_turn")

	refresh_combat_status_sprite_tint()

func finish_turn() -> void:
	in_canto_phase = false
	canto_move_budget = 0.0
	is_exhausted = true
	
	# Turn off ALL selection visuals
	set_selected(false) 
	set_selected_glow(false) # <--- ADD THIS LINE
	
	# Force the sprite color to update immediately (preserve scene tint on enemies)
	if is_exhausted:
		modulate = _exhausted_root_modulate()
	_sync_status_strip_modulate_vs_exhaustion()
	
	emit_signal("finished_turn", self)

func look_at_pos(target_grid_pos: Vector2i) -> void:
	if sprite == null:
		return
	var current_grid_pos := Vector2i(int(position.x / DEFAULT_CELL_SIZE), int(position.y / DEFAULT_CELL_SIZE))
	var d := Vector2(float(target_grid_pos.x - current_grid_pos.x), float(target_grid_pos.y - current_grid_pos.y))
	if d.length_squared() < 0.0001:
		return
	# Horizontal (or flatter diagonal): classic left/right face.
	if absf(d.x) >= absf(d.y):
		if d.x > 0.0:
			sprite.flip_h = false
		elif d.x < 0.0:
			sprite.flip_h = true
	else:
		# Pure vertical / steep diagonal: old code never updated flip_h (same column).
		sprite.flip_h = d.y > 0.0
		
func set_selected(is_selected: bool) -> void:
	if selection_tween:
		selection_tween.kill()
	
	if is_selected:
		selection_tween = create_tween().set_loops()
		selection_tween.tween_property(team_glow, "color:a", 0.7, 0.5)
		selection_tween.tween_property(team_glow, "color:a", 0.3, 0.5)
	else:
		team_glow.color.a = maxf(team_glow.color.a, 0.3)
		modulate = _exhausted_root_modulate() if is_exhausted else base_color
		_sync_status_strip_modulate_vs_exhaustion()

# Call this function with true to start glowing, false to stop.
func set_selected_glow(is_selected: bool) -> void:
	# Kill any existing tween so they don't fight each other
	if selection_tween and selection_tween.is_valid():
		selection_tween.kill()
	selection_tween = null
	
	if is_selected:
		if sprite == null:
			return
		_stop_bone_toxin_pulse()
		_selection_base_sprite_scale = sprite.scale
		if team_glow != null:
			_selection_base_glow_alpha = team_glow.color.a
			team_glow.pivot_offset = team_glow.size * 0.5
			team_glow.scale = Vector2.ONE
		_selection_pulse_active = true
		# Faster + stronger pulse for clearer active-unit read.
		selection_tween = create_tween().set_loops()
		selection_tween.tween_property(sprite, "modulate", SELECT_PULSE_SPRITE_BRIGHT, SELECT_PULSE_HALF_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Fliers: do not tween sprite.scale — continuous flight squash uses non-uniform scale and would be overwritten every frame.
		if not _is_flying_move_unit():
			selection_tween.parallel().tween_property(sprite, "scale", _selection_base_sprite_scale * SELECT_PULSE_SPRITE_SCALE_MULT, SELECT_PULSE_HALF_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if team_glow != null:
			selection_tween.parallel().tween_property(team_glow, "color:a", SELECT_PULSE_GLOW_ALPHA_MAX, SELECT_PULSE_HALF_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			selection_tween.parallel().tween_property(team_glow, "scale", Vector2.ONE * SELECT_PULSE_GLOW_SCALE_MULT, SELECT_PULSE_HALF_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		selection_tween.tween_property(sprite, "modulate", Color.WHITE, SELECT_PULSE_HALF_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if not _is_flying_move_unit():
			selection_tween.parallel().tween_property(sprite, "scale", _selection_base_sprite_scale, SELECT_PULSE_HALF_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		if team_glow != null:
			var target_base_alpha: float = maxf(_selection_base_glow_alpha, SELECT_PULSE_GLOW_ALPHA_MIN)
			selection_tween.parallel().tween_property(team_glow, "color:a", target_base_alpha, SELECT_PULSE_HALF_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			selection_tween.parallel().tween_property(team_glow, "scale", Vector2.ONE, SELECT_PULSE_HALF_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	else:
		if not _selection_pulse_active:
			return
		_selection_pulse_active = false
		# Ensure the unit returns to normal color when deselected
		if sprite != null:
			sprite.scale = _selection_base_sprite_scale
			refresh_combat_status_sprite_tint()
		if team_glow != null:
			var glow_color: Color = team_glow.color
			glow_color.a = maxf(_selection_base_glow_alpha, SELECT_PULSE_GLOW_ALPHA_MIN)
			team_glow.color = glow_color
			team_glow.scale = Vector2.ONE
		
func trigger_defend() -> void:
	is_defending = true
	if defend_icon != null:
		defend_icon.visible = true
	update_poise_visuals()
	finish_turn()

func setup_from_save_data(save_dict: Dictionary) -> void:
	# 1. Restore Stats
	experience = save_dict.get("experience", 0)
	level = save_dict.get("level", 1)
	current_hp = save_dict.get("current_hp", max_hp)
	max_hp = save_dict.get("max_hp", max_hp)
	strength = save_dict.get("strength", strength)
	magic = save_dict.get("magic", magic)
	defense = save_dict.get("defense", defense)
	resistance = save_dict.get("resistance", resistance)
	speed = save_dict.get("speed", speed)
	agility = save_dict.get("agility", agility)
	
	# 2. Restore Movement (Boots)
	if save_dict.has("move_range"):
		move_range = save_dict["move_range"]

	# 3. Restore Class (Crucial for Promotions!)
	if save_dict.has("class_data") and save_dict["class_data"] != null:
		active_class_data = save_dict["class_data"]
		# Update the class name string too
		if active_class_data:
			unit_class_name = active_class_data.job_name
			
	if save_dict.has("inventory"):
		inventory.clear()
		inventory.append_array(save_dict["inventory"])		
		
	# 4. Update Bars
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
	if exp_bar:
		exp_bar.max_value = get_exp_required()
		exp_bar.value = experience
	_layout_overhead_bars()
	snap_health_delay_to_main()
	_refresh_level_badge()
	call_deferred("_refresh_level_badge")
	_apply_overhead_bar_focus_state()
	# 5. Restore Skill Tree Data
	if save_dict.has("skill_points"):
		skill_points = save_dict["skill_points"]
	if save_dict.has("unlocked_skills"):
		unlocked_skills.clear()
		unlocked_skills.append_array(save_dict["unlocked_skills"])
	# --- Restore Unlocked Abilities ---
	if save_dict.has("unlocked_abilities"):
		unlocked_abilities.clear()
		unlocked_abilities.append_array(save_dict["unlocked_abilities"])
	if save_dict.has("traits"):
		traits = save_dict["traits"].duplicate()
	else:
		traits.clear()
	if save_dict.has("rookie_legacies"):
		rookie_legacies = save_dict["rookie_legacies"].duplicate()
	else:
		rookie_legacies.clear()
	if save_dict.has("base_class_legacies"):
		base_class_legacies = save_dict["base_class_legacies"].duplicate()
	else:
		base_class_legacies.clear()
	if save_dict.has("promoted_class_legacies"):
		promoted_class_legacies = save_dict["promoted_class_legacies"].duplicate()
	else:
		promoted_class_legacies.clear()

	if save_dict.has("active_ability_cd"):
		ActiveCombatAbilityHelpers.import_wire(self, save_dict["active_ability_cd"])
	else:
		ActiveCombatAbilityHelpers.bootstrap_unit(self)

# --- NEW: PHYSICALLY UPDATE VISUALS ---
func apply_custom_visuals(sprite_tex: Texture2D, portrait_tex: Texture2D) -> void:
	if sprite_tex:
		# Update the actual 2D sprite node on the map
		if sprite:
			sprite.texture = sprite_tex
			_layout_overhead_bars()
			call_deferred("_layout_overhead_bars")
		
	if portrait_tex and data:
		# Update the internal resource so the HUD info panel finds it
		data.portrait = portrait_tex

## EXP required for the next level (base + scaling per level). Used for bar max and level-up loop.
func get_exp_required() -> int:
	# Base: 100 EXP for Level 2. 
	# Adds +25 EXP requirement for every level after that.
	# (Lv 1->2 = 100 | Lv 2->3 = 125 | Lv 3->4 = 150 | Lv 10->11 = 325)
	var base_exp = 200
	var scaling_factor = 200
	
	return base_exp + ((level - 1) * scaling_factor)

func apply_promotion_aura() -> void:
	if promo_aura != null: return 
	
	# --- 1. THE PULSATING GLOW (Behind) ---
	promo_aura = Sprite2D.new()
	promo_aura.show_behind_parent = true
	var aura_base_color: Color = Color(1.0, 0.8, 0.2, 0.6)
	var spark_color: Color = Color(1.0, 0.9, 0.5, 1.0)
	
	if get_parent() and get_parent().name == "EnemyUnits":
		aura_base_color = Color(0.8, 0.1, 1.0, 0.6)
		spark_color = Color(0.9, 0.4, 1.0, 1.0)
		
	promo_aura.modulate = aura_base_color
	sprite.add_child(promo_aura)
	
	var pulse = create_tween().set_loops()
	pulse.tween_property(promo_aura, "scale", Vector2(1.15, 1.15), 1.5).set_trans(Tween.TRANS_SINE)
	pulse.parallel().tween_property(promo_aura, "modulate:a", 0.1, 1.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(promo_aura, "scale", Vector2(1.0, 1.0), 1.5).set_trans(Tween.TRANS_SINE)
	pulse.parallel().tween_property(promo_aura, "modulate:a", 0.6, 1.5).set_trans(Tween.TRANS_SINE)

	# --- 2. THE JAGGED ELECTRIC ARCS ---
	var sparks = CPUParticles2D.new()
	add_child(sparks) 
	
	sparks.emitting = false 
	sparks.one_shot = true
	sparks.amount = 4 
	sparks.lifetime = 0.15 
	sparks.explosiveness = 1.0 
	sparks.local_coords = false 
	
	# --- NEW: APPLY THE TEXTURE ---
	if lightning_bolt_texture != null:
		sparks.texture = lightning_bolt_texture
	
	# --- NEW: RANDOM ROTATION ---
	# This makes sure the lightning bolts point in random directions
	sparks.angle_min = 0
	sparks.angle_max = 360
	
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(1, 1) 
	
	sparks.gravity = Vector2(0, 0)
	sparks.spread = 180.0 
	sparks.initial_velocity_min = 30.0 
	sparks.initial_velocity_max = 80.0
	
	# Normalize spark size against texture dimensions so promoted aura sparks stay micro.
	var spark_scale_min: float = 0.20
	var spark_scale_max: float = 0.45
	if lightning_bolt_texture != null:
		var tex_max_dim: float = maxf(float(lightning_bolt_texture.get_width()), float(lightning_bolt_texture.get_height()))
		if tex_max_dim > 0.0:
			var tex_norm: float = clampf(24.0 / tex_max_dim, 0.08, 0.45)
			spark_scale_min = 0.55 * tex_norm
			spark_scale_max = 1.20 * tex_norm
	sparks.scale_amount_min = spark_scale_min
	sparks.scale_amount_max = spark_scale_max
	
	var grad = Gradient.new()
	grad.set_color(0, Color.WHITE) 
	grad.set_color(1, Color(spark_color.r, spark_color.g, spark_color.b, 0.0)) 
	sparks.color_ramp = grad
	
	# --- 3. THE SPORADIC TIMER ---
	var zap_timer = Timer.new()
	add_child(zap_timer) 
	zap_timer.wait_time = randf_range(0.3, 1.5)
	
	zap_timer.timeout.connect(func():
		if is_instance_valid(sparks) and is_instance_valid(sprite):
			var rx = randf_range(-40, 40)
			var ry = randf_range(-55, 25)
			sparks.position = sprite.position + Vector2(rx, ry)
			sparks.restart()
			zap_timer.wait_time = randf_range(0.2, 2.0) 
	)
	zap_timer.start()
	
func _process(_delta: float) -> void:
	if promo_aura != null and sprite != null:
		promo_aura.texture = sprite.texture
		promo_aura.hframes = sprite.hframes
		promo_aura.vframes = sprite.vframes
		promo_aura.frame = sprite.frame
		promo_aura.flip_h = sprite.flip_h
		promo_aura.offset = sprite.offset

# ==========================================
# --- POISE SYSTEM & UI ---
# ==========================================
## Poise cap from HP, DEF (and defend bonus), and temporary meta modifiers. Used by BattleField for stagger.
func get_max_poise() -> int:
	var def_stat = defense + int(get_meta("inner_peace_def_bonus_temp", 0)) - int(get_meta("frenzy_def_penalty_temp", 0))
	if is_defending:
		def_stat += defense_bonus
		
	# --- NERFED MATH: Add Max HP to the baseline! ---
	return max_hp + (def_stat * 2) + (25 if is_defending else 0)

func get_current_poise() -> int:
	return get_meta("current_poise", get_max_poise())


func _sync_poise_bar_layout(p_bar: ProgressBar) -> void:
	if health_bar == null or p_bar == null:
		return
	var w: float = health_bar.size.x
	if w < 2.0:
		w = POISE_BAR_FALLBACK_WIDTH_PX
	p_bar.custom_minimum_size = Vector2(w, POISE_BAR_HEIGHT_PX)
	p_bar.scale = health_bar.scale
	var dy: float = health_bar.size.y * absf(health_bar.scale.y) + 2.0
	p_bar.position = health_bar.position + Vector2(0.0, dy)
	p_bar.z_index = maxi(health_bar.z_index - 1, 0)


func update_poise_visuals() -> void:
	var max_p := get_max_poise()
	var cur_p := get_current_poise()

	var p_bar = get_node_or_null("DynamicPoiseBar")
	if p_bar == null and health_bar != null:
		p_bar = ProgressBar.new()
		p_bar.name = "DynamicPoiseBar"
		p_bar.show_percentage = false
		p_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p_bar.add_theme_stylebox_override("background", UnitBarVisuals.poise_track())
		p_bar.add_theme_stylebox_override("fill", UnitBarVisuals.poise_fill())
		add_child(p_bar)
		p_bar.set_meta("_unit_bar_visuals_v1", true)
		_sync_poise_bar_layout(p_bar)
		call_deferred("_sync_poise_bar_layout", p_bar)

	if p_bar != null:
		if not p_bar.has_meta("_unit_bar_visuals_v1"):
			p_bar.add_theme_stylebox_override("background", UnitBarVisuals.poise_track())
			p_bar.add_theme_stylebox_override("fill", UnitBarVisuals.poise_fill())
			p_bar.set_meta("_unit_bar_visuals_v1", true)
		_sync_poise_bar_layout(p_bar)
		p_bar.max_value = maxf(1, max_p)
		if _poise_bar_tween != null and _poise_bar_tween.is_valid():
			_poise_bar_tween.kill()
		_poise_bar_tween = create_tween()
		_poise_bar_tween.tween_property(p_bar, "value", float(clampi(cur_p, 0, max_p)), POISE_BAR_TWEEN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		p_bar.visible = (cur_p < max_p and current_hp > 0)
	_apply_overhead_bar_focus_state()

func set_staggered_visuals(is_staggered: bool) -> void:
	if stagger_tween and stagger_tween.is_valid():
		stagger_tween.kill()
		
	if is_staggered:
		stagger_tween = create_tween().set_loops(-1)
		# Pulse from normal to a painful, fleshy reddish-pink
		stagger_tween.tween_property(sprite, "modulate", Color(1.0, 0.4, 0.4), 0.6).set_trans(Tween.TRANS_SINE)
		stagger_tween.tween_property(sprite, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)
	else:
		if sprite:
			refresh_combat_status_sprite_tint()

# ==========================================
# ARENA GHOST UI SYNC
# ==========================================
func setup_ghost_ui() -> void:
	_apply_overhead_bar_visuals()
	_refresh_level_badge()
	call_deferred("_refresh_level_badge")
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
	if exp_bar:
		exp_bar.max_value = get_exp_required()
		exp_bar.value = experience
	snap_health_delay_to_main()
	_apply_overhead_bar_focus_state()

	# Optional: Give the ghosts an intimidating purple Arena aura!
	if team_glow:
		team_glow.color = Color(0.8, 0.1, 1.0, 0.4)
