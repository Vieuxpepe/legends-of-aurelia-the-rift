# CampRosterWalker.gd
# Roster member NPC in Explore Camp: wanders near a home anchor, shows battle_sprite, holds unit data for dialogue.
# CampExplore spawns these from CampaignManager.player_roster and assigns home positions.

class_name CampRosterWalker
extends Node2D

const CAMP_BEHAVIOR_DB = preload("res://Scripts/Narrative/CampBehaviorDB.gd")

## World position this NPC considers "home"; wander stays near it.
var home_position: Vector2 = Vector2.ZERO
## Max distance from home for random wander target.
var roam_radius: float = 80.0
## Unit display name for dialogue and interaction.
var unit_name: String = ""
## Roster unit dict: portrait, battle_sprite, data, etc. May be empty.
var unit_data: Dictionary = {}
## Request marker: "none", "offer", "offer_personal", "turn_in", "request_target", "request_progress", "request_failed". Set by CampRequestController.
var request_marker: String = "none"

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var marker_label: Label = get_node_or_null("MarkerLabel")

var _idle_timer: float = 0.0
var _target_pos: Vector2 = Vector2.ZERO
var _target_is_zone: bool = false
var _wander_paused: bool = false
var _behavior_profile: Dictionary = {}
var _zones: Array = []
var _current_zone_type: String = ""
var _idle_style: String = "neutral"
var _idle_pose_applied: bool = false
var _base_sprite_offset: Vector2 = Vector2.ZERO
var _current_zone_center: Vector2 = Vector2.ZERO
var _current_zone_facing_dir: Vector2 = Vector2.ZERO
const IDLE_MIN: float = 1.2
const IDLE_MAX: float = 3.0
const MOVE_SPEED: float = 24.0
const ARRIVE_DIST: float = 6.0
## Max distance from zone center for "tight" zones (watch_post, shrine, etc.).
const TIGHT_ZONE_MAX_DIST: float = 10.0
## Zone types that use tight anchoring (stand very near marker).
const TIGHT_ZONE_TYPES: Array = ["watch_post", "shrine", "map_table", "workbench"]
## Zone types that use medium scatter (closer than loose, not at center).
const MEDIUM_ZONE_TYPES: Array = ["wall", "tree_line"]
const PERSONAL_SPACE_RADIUS: float = 30.0
const SEPARATION_STRENGTH: float = 0.92
const IDLE_SEPARATION_SPEED: float = 10.0
const HARD_SEPARATION_SPEED: float = 34.0
const HARD_SEPARATION_MAX_SPEED: float = 52.0
const HOME_RETURN_SPEED: float = 32.0
const ACCEL_RATE: float = 6.0
const ARRIVE_SLOW_RADIUS: float = 32.0
const DRIFT_STRENGTH: float = 4.0
const DRIFT_SPEED: float = 1.2
const STEP_BOB_HEIGHT: float = 1.5
const STEP_BOB_SPEED: float = 7.0
const MIN_MOVE_SPEED_FOR_BOB: float = 4.0
const ARRIVAL_SETTLE_UP: float = 1.4
const ARRIVAL_SETTLE_DOWN: float = 0.8
const SOCIAL_IDLE_BOB_HEIGHT: float = 0.5
const SOCIAL_IDLE_BOB_SPEED: float = 1.35
const TURN_LEAN_DEG: float = 2.0
const LISTENER_BOB_MULT: float = 0.45
const INJURED_MOVE_MULT: float = 0.78
const FATIGUED_MOVE_MULT: float = 0.88
const INJURED_BOB_MULT: float = 0.75
const FATIGUED_BOB_MULT: float = 0.85
## Solo: only bind a CampActivityAnchor for position/clamp when this close (avoids teleport-to-marker).
const STANDING_ANCHOR_PHYSICS_MAX_DIST: float = 20.0
## Beyond physics max, still allow anchor to drive facing until this distance.
const STANDING_ANCHOR_FACING_ONLY_MAX_DIST: float = 68.0
const SOLO_ROUTINE_POSITION_SPEED: float = 28.0
const FIRE_ORBIT_LOCAL_R_MULT: float = 0.5
const FIRE_ORBIT_LOCAL_R_MIN: float = 2.2
const FIRE_ORBIT_LOCAL_R_MAX: float = 6.2

var _move_velocity: Vector2 = Vector2.ZERO
var _walk_cycle: float = 0.0
var _drift_phase: float = 0.0
var _social_move_active: bool = false
var _social_target_pos: Vector2 = Vector2.ZERO
var _social_move_arrived: bool = false
var _condition_injured: bool = false
var _condition_fatigued: bool = false
var _social_idle_phase: float = 0.0
var _arrive_tween: Tween = null
var _reaction_tween: Tween = null
var _turn_tween: Tween = null

var _marker_rest_offset_top: float = -48.0
var _marker_anim_phase: float = 0.0
## Presentation-only: brief emphasis when player enters interact range (decays in _process).
var _proximity_ping: float = 0.0
const MARKER_BOB_PX: float = 2.8
const MARKER_PHASE_SPEED: float = 3.2
const PROXIMITY_PING_DECAY: float = 2.75

## Presentation-only: Explore Camp interact focus (0=neutral, 1=soften non-primary nearby, 2=nearest primary, 3=pair overhear participants).
var _interact_focus_tier: int = 0

const SOCIAL_STATE_FREE := 0
const SOCIAL_STATE_APPROACH := 1
const SOCIAL_STATE_SETTLED := 2
const SOCIAL_STATE_SPEAKING := 3
const SOCIAL_STATE_PAUSED := 4

var _social_state: int = SOCIAL_STATE_FREE
## Optional ambient choreography from CampAmbientDirector: "spar", "drill", "work", "fireside", or "".
var _ambient_social_pose: String = ""

var _camp_visit_theme: String = "normal"
## Zone-grounded solo pose chosen when arriving at a stand location (overrides profile idle until next move).
var _solo_visual_style: String = ""
var _standing_zone_type: String = ""
var _standing_zone_center: Vector2 = Vector2.ZERO
var _standing_zone_radius: float = 0.0
var _standing_facing_dir: Vector2 = Vector2.ZERO
var _standing_face_mode: String = "center"
var _standing_idle_override: String = ""
## Lightweight idle micro-motion: "", "orbit", "patrol_ping", "shift_side", "fire_orbit", "sit_pulse", "kneel_pulse".
var _solo_routine_kind: String = ""
var _solo_routine_phase: float = 0.0
var _solo_routine_vec: Vector2 = Vector2.ZERO
var _solo_routine_orbit_r: float = 6.0
var _solo_routine_anchor: Vector2 = Vector2.ZERO
var _camp_ctx: CampContext = null
var _standing_zone_node: Node = null
var _standing_activity_anchor: Node = null

func set_camp_context(ctx: CampContext) -> void:
	_camp_ctx = ctx

## One-shot marker emphasis for proximity feedback; does not change marker symbols or request state.
func play_interact_proximity_ping() -> void:
	_proximity_ping = 1.0


func set_interact_focus_presentation(tier: int) -> void:
	_interact_focus_tier = clampi(tier, 0, 3)


func _apply_interact_focus_sprite_modulate() -> void:
	if sprite == null:
		return
	match _interact_focus_tier:
		1:
			sprite.modulate = Color(0.9, 0.9, 0.93, 1.0)
		2:
			sprite.modulate = Color(1.04, 1.04, 1.06, 1.0)
		3:
			sprite.modulate = Color(1.03, 1.02, 1.05, 1.0)
		_:
			sprite.modulate = Color(1, 1, 1, 1.0)


func set_camp_visit_theme(theme: String) -> void:
	_camp_visit_theme = str(theme).strip_edges().to_lower()
	if _camp_visit_theme == "":
		_camp_visit_theme = "normal"

func set_ambient_social_pose(pose: String) -> void:
	_ambient_social_pose = str(pose).strip_edges().to_lower()

func clear_ambient_social_pose() -> void:
	_ambient_social_pose = ""

func get_ambient_social_pose() -> String:
	return _ambient_social_pose

func _ready() -> void:
	home_position = global_position
	_target_pos = home_position
	var phase_seed: float = float(get_instance_id() & 1023) / 1023.0
	if sprite != null:
		_base_sprite_offset = sprite.position
		_drift_phase = phase_seed * TAU
	if marker_label != null:
		_marker_rest_offset_top = marker_label.offset_top
		_marker_anim_phase = phase_seed * TAU

## Call from CampExplore when dialogue opens/closes so wander pauses.
func set_wander_paused(paused: bool) -> void:
	_wander_paused = paused
	if paused:
		_clear_social_animation_tweens()
		_solo_routine_kind = ""
		_solo_routine_phase = 0.0
		_social_state = SOCIAL_STATE_PAUSED
	else:
		if _social_state == SOCIAL_STATE_PAUSED:
			_social_state = SOCIAL_STATE_FREE

## Applies roster unit dict: sets sprite texture from battle_sprite, stores name/data.
func setup_from_roster(roster_entry: Dictionary) -> void:
	unit_data = roster_entry
	unit_name = str(roster_entry.get("unit_name", "Unit")).strip_edges()
	_behavior_profile = CAMP_BEHAVIOR_DB.get_profile(unit_name)
	_idle_style = str(_behavior_profile.get("idle_style", "neutral")).strip_edges()
	var tex: Variant = roster_entry.get("battle_sprite", null)
	if sprite != null:
		_base_sprite_offset = sprite.position
		if tex is Texture2D:
			sprite.texture = tex
			sprite.visible = true
		else:
			sprite.visible = true
			# Placeholder: keep default (e.g. white rect) or leave as-is

func set_behavior_zones(zones: Array) -> void:
	_zones = zones

func apply_behavior_profile(profile: Dictionary) -> void:
	_behavior_profile = profile
	_idle_style = str(_behavior_profile.get("idle_style", "neutral")).strip_edges()

func apply_condition_flags(injured: bool, fatigued: bool) -> void:
	_condition_injured = injured
	_condition_fatigued = fatigued

func _get_condition_move_multiplier() -> float:
	if _condition_injured:
		return INJURED_MOVE_MULT
	if _condition_fatigued:
		return FATIGUED_MOVE_MULT
	return 1.0

func _get_condition_bob_multiplier() -> float:
	if _condition_injured:
		return INJURED_BOB_MULT
	if _condition_fatigued:
		return FATIGUED_BOB_MULT
	return 1.0

func start_behavior() -> void:
	_idle_timer = 0.0
	_update_standing_zone_at_position(global_position)
	_refresh_solo_visual_behavior()
	_pick_next_idle()

func _process(_delta: float) -> void:
	_proximity_ping = move_toward(_proximity_ping, 0.0, _delta * PROXIMITY_PING_DECAY)
	_apply_interact_focus_sprite_modulate()
	if marker_label != null:
		var marker_txt: String = ""
		var marker_on: bool = false
		if request_marker == "offer":
			marker_txt = "!"
			marker_on = true
		elif request_marker == "offer_personal":
			marker_txt = "!!"
			marker_on = true
		elif request_marker == "turn_in":
			marker_txt = "?"
			marker_on = true
		elif request_marker == "request_target":
			marker_txt = ">"
			marker_on = true
		elif request_marker == "request_progress":
			marker_txt = "+"
			marker_on = true
		elif request_marker == "request_failed":
			marker_txt = "×"
			marker_on = true
		if marker_on:
			marker_label.text = marker_txt
			marker_label.visible = true
			_marker_anim_phase += _delta * MARKER_PHASE_SPEED
			var ping: float = _proximity_ping
			var bob: float = sin(_marker_anim_phase) * MARKER_BOB_PX + ping * 2.2 * sin(_marker_anim_phase * 2.4)
			var glint: float = 0.93 + 0.07 * sin(_marker_anim_phase * 1.85) + ping * 0.11
			var focus_mul: float = 1.0
			var focus_a: float = 1.0
			match _interact_focus_tier:
				1:
					focus_mul = 0.8
					focus_a = 0.82
				2:
					focus_mul = 1.1
				3:
					focus_mul = 1.07
				_:
					pass
			marker_label.offset_top = _marker_rest_offset_top + bob
			marker_label.modulate = Color(
				clampf(glint * focus_mul, 0.0, 1.0),
				clampf(glint * focus_mul, 0.0, 1.0),
				clampf(glint * 0.96 * focus_mul, 0.0, 1.0),
				focus_a
			)
		else:
			marker_label.visible = false
			marker_label.offset_top = _marker_rest_offset_top
			marker_label.modulate = Color(1, 1, 1, 1)
			_marker_anim_phase = 0.0
	if _wander_paused or sprite == null:
		_move_velocity = Vector2.ZERO
		_walk_cycle = 0.0
		if sprite != null:
			# Allow pair-overhear / dialogue reaction tweens to play while paused; freeze pose otherwise.
			var reaction_running: bool = _reaction_tween != null and is_instance_valid(_reaction_tween)
			var turn_running: bool = _turn_tween != null and is_instance_valid(_turn_tween)
			if not reaction_running and not turn_running:
				sprite.position = _base_sprite_offset
				sprite.rotation = 0.0
		return
	# Socially settled walkers hold their meetup position until CampExplore releases them.
	if _social_state == SOCIAL_STATE_SETTLED or _social_state == SOCIAL_STATE_SPEAKING:
		_apply_personal_space_correction(_delta, 0.82)
		_move_velocity = Vector2.ZERO
		_walk_cycle = 0.0
		_play_social_idle_motion(_delta)
		return
	# Idle phase
	if _idle_timer > 0:
		_idle_timer -= _delta
		if not _idle_pose_applied:
			_apply_idle_style()
		_apply_solo_idle_frame(_delta)
		_apply_personal_space_correction(_delta, 0.72)
		if not _target_is_zone and not _social_move_active:
			var to_home_idle: Vector2 = home_position - global_position
			if to_home_idle.length() > roam_radius:
				var boundary_pos_idle: Vector2 = home_position + (global_position - home_position).normalized() * roam_radius
				global_position = global_position.move_toward(boundary_pos_idle, HOME_RETURN_SPEED * _delta)
		_move_velocity = Vector2.ZERO
		_walk_cycle = 0.0
		return
	if _idle_pose_applied:
		_reset_idle_pose()
	# Move toward target
	var target: Vector2 = _target_pos
	if _social_move_active:
		target = _social_target_pos
	var to_target: Vector2 = target - global_position
	if to_target.length() <= ARRIVE_DIST:
		_move_velocity = Vector2.ZERO
		_walk_cycle = 0.0
		if sprite != null:
			sprite.position = _base_sprite_offset
		_play_arrival_settle()
		if _social_move_active:
			_social_move_arrived = true
			_social_state = SOCIAL_STATE_SETTLED
			return
		_update_standing_zone_at_position(global_position)
		_refresh_solo_visual_behavior()
		_pick_next_idle()
		return
	var move_dir: Vector2 = to_target.normalized()
	var sep: Vector2 = _compute_separation_vector()
	if sep.length() > 0.001:
		move_dir = (move_dir + sep * SEPARATION_STRENGTH)
		if move_dir.length() > 0.001:
			move_dir = move_dir.normalized()
	var dist_to_target: float = to_target.length()
	var arrive_factor: float = 1.0
	if dist_to_target < ARRIVE_SLOW_RADIUS:
		var t: float = clamp(dist_to_target / ARRIVE_SLOW_RADIUS, 0.0, 1.0)
		arrive_factor = lerp(0.35, 1.0, t)
	var desired_velocity: Vector2 = move_dir * MOVE_SPEED * arrive_factor * _get_condition_move_multiplier()
	if move_dir.length() > 0.001:
		var perp: Vector2 = Vector2(-move_dir.y, move_dir.x)
		var time_s: float = Time.get_ticks_msec() / 1000.0
		var drift_scale: float = sin(time_s * DRIFT_SPEED + _drift_phase)
		var drift_vel: Vector2 = perp * (DRIFT_STRENGTH * drift_scale)
		desired_velocity += drift_vel
	_move_velocity = _move_velocity.lerp(desired_velocity, clamp(ACCEL_RATE * _delta, 0.0, 1.0))
	global_position += _move_velocity * _delta
	_apply_personal_space_correction(_delta, 1.06)
	# Clamp back toward home so we don't drift when doing home wander.
	if not _target_is_zone and not _social_move_active:
		var to_home: Vector2 = home_position - global_position
		if to_home.length() > roam_radius:
			var boundary_pos: Vector2 = home_position + (global_position - home_position).normalized() * roam_radius
			global_position = global_position.move_toward(boundary_pos, HOME_RETURN_SPEED * _delta)
	var speed_now: float = _move_velocity.length()
	if speed_now > MIN_MOVE_SPEED_FOR_BOB:
		_walk_cycle += STEP_BOB_SPEED * _delta
		if sprite != null:
			var bob: float = sin(_walk_cycle) * STEP_BOB_HEIGHT * _get_condition_bob_multiplier()
			sprite.position = _base_sprite_offset + Vector2(0, bob)
	else:
		_walk_cycle = 0.0
		if sprite != null and not _idle_pose_applied:
			sprite.position = _base_sprite_offset
	if sprite != null and abs(_move_velocity.x) > 1.0:
		sprite.flip_h = _move_velocity.x < 0.0

func _pick_next_idle() -> void:
	_idle_timer = randf_range(IDLE_MIN, IDLE_MAX)
	var freq: float = float(_behavior_profile.get("movement_frequency", 0.5))
	if randf() < freq:
		_target_pos = _choose_zone_target_position()
	else:
		_target_pos = _choose_random_home_target()
		_target_is_zone = false
		_current_zone_type = ""
		_current_zone_center = Vector2.ZERO
		_current_zone_facing_dir = Vector2.ZERO


func _add_solo_style_w(cands: Array, style: String, w: float) -> void:
	var st: String = str(style).strip_edges().to_lower()
	if st == "":
		return
	cands.append({"style": st, "weight": maxf(0.05, w)})


func _build_solo_candidates() -> Array:
	var c: Array = []
	var zt: String = _standing_zone_type.strip_edges().to_lower()
	var base_idle: String = str(_idle_style).strip_edges().to_lower()
	if base_idle != "" and base_idle != "neutral":
		_add_solo_style_w(c, base_idle, 0.55)
	match zt:
		"watch_post", "wall":
			_add_solo_style_w(c, "patrol", 1.4)
			_add_solo_style_w(c, "look_out", 1.45)
			_add_solo_style_w(c, "inspect_wall", 1.1)
			_add_solo_style_w(c, "check_gear", 0.95)
			_add_solo_style_w(c, "stretch", 0.75)
			_add_solo_style_w(c, "warm_hands", 0.35)
		"fire", "cook", "cook_area":
			_add_solo_style_w(c, "tend_fire", 1.5)
			_add_solo_style_w(c, "warm_hands", 1.2)
			_add_solo_style_w(c, "sit_rest", 0.85)
			_add_solo_style_w(c, "pour_water", 0.7)
			_add_solo_style_w(c, "read_notes", 0.45)
		"workbench", "supply":
			_add_solo_style_w(c, "sort_supplies", 1.35)
			_add_solo_style_w(c, "workbench_tinker", 1.25)
			_add_solo_style_w(c, "sharpen", 0.95)
			_add_solo_style_w(c, "carry_bundle", 0.85)
			_add_solo_style_w(c, "check_gear", 0.65)
		"infirmary", "bench":
			_add_solo_style_w(c, "sit_rest", 1.2)
			_add_solo_style_w(c, "pour_water", 0.95)
			_add_solo_style_w(c, "wash_hands", 0.85)
			_add_solo_style_w(c, "check_gear", 0.65)
			_add_solo_style_w(c, "rest_head_down", 0.55)
		"shrine":
			_add_solo_style_w(c, "kneel_prayer", 1.5)
			_add_solo_style_w(c, "pray_quietly", 1.1)
			_add_solo_style_w(c, "read_notes", 0.6)
		"tree_line":
			_add_solo_style_w(c, "look_out", 1.35)
			_add_solo_style_w(c, "patrol", 1.15)
			_add_solo_style_w(c, "inspect_wall", 0.7)
		"map_table", "wagon":
			_add_solo_style_w(c, "read_notes", 1.0)
			_add_solo_style_w(c, "sort_supplies", 0.75)
			_add_solo_style_w(c, "check_gear", 0.55)
		_:
			pass
	if c.is_empty():
		if base_idle != "":
			_add_solo_style_w(c, base_idle, 1.0)
		else:
			_add_solo_style_w(c, "neutral", 1.0)
		_add_solo_style_w(c, "check_gear", 0.35)
		_add_solo_style_w(c, "warm_hands", 0.32)
	var ov: String = _standing_idle_override.strip_edges().to_lower()
	if ov != "":
		_add_solo_style_w(c, ov, 2.4)
	return c


func _theme_weight_mul(style: String) -> float:
	var s: String = str(style).strip_edges().to_lower()
	var th: String = _camp_visit_theme
	var m: float = 1.0
	match th:
		"training":
			if s in ["patrol", "inspect_wall", "sharpen", "check_gear", "stretch", "look_out", "workbench_tinker", "sort_supplies", "carry_bundle"]:
				m *= 1.45
			if s in ["sit_rest", "rest_head_down", "pour_water", "read_notes"]:
				m *= 0.72
		"tense":
			if s in ["look_out", "inspect_wall", "patrol", "check_gear", "sharpen"]:
				m *= 1.5
			if s in ["tend_fire", "warm_hands", "sit_rest"]:
				m *= 0.78
		"hopeful":
			if s in ["tend_fire", "warm_hands", "sit_rest", "read_notes", "pour_water"]:
				m *= 1.35
			if s in ["sharpen", "inspect_wall", "patrol"]:
				m *= 0.85
		"recovery":
			if s in ["sit_rest", "rest_head_down", "pour_water", "wash_hands", "kneel_prayer", "pray_quietly", "check_gear"]:
				m *= 1.4
			if s in ["patrol", "stretch", "sharpen", "carry_bundle"]:
				m *= 0.75
		"somber":
			if s in ["kneel_prayer", "pray_quietly", "rest_head_down", "read_notes", "sit_rest"]:
				m *= 1.42
			if s in ["stretch", "patrol"]:
				m *= 0.7
		"gossip":
			if s in ["read_notes", "sit_rest", "sort_supplies", "wash_hands", "check_gear"]:
				m *= 1.25
			if s in ["sharpen", "patrol", "look_out"]:
				m *= 0.82
		_:
			pass
	return m


func _weighted_pick_solo_style(candidates: Array) -> String:
	var acc_map: Dictionary = {}
	for d in candidates:
		if not d is Dictionary:
			continue
		var st: String = str(d.get("style", "")).strip_edges().to_lower()
		if st == "":
			continue
		var w: float = float(d.get("weight", 0.1)) * _theme_weight_mul(st)
		if w <= 0.001:
			continue
		acc_map[st] = float(acc_map.get(st, 0.0)) + w
	var styles: Array = acc_map.keys()
	if styles.is_empty():
		return str(_idle_style).strip_edges().to_lower()
	var total: float = 0.0
	for st in styles:
		total += float(acc_map[st])
	var r: float = randf() * total
	var acc: float = 0.0
	for st in styles:
		acc += float(acc_map[st])
		if r <= acc:
			return str(st)
	return str(styles[styles.size() - 1])


func _update_standing_zone_at_position(pos: Vector2) -> void:
	_standing_zone_type = ""
	_standing_zone_center = Vector2.ZERO
	_standing_zone_radius = 0.0
	_standing_facing_dir = Vector2.ZERO
	_standing_face_mode = "center"
	_standing_idle_override = ""
	_standing_zone_node = null
	_standing_activity_anchor = null
	if _zones.is_empty():
		return
	var best: Node2D = null
	var best_score: float = -1.0
	for z in _zones:
		if not is_instance_valid(z):
			continue
		if not (z is Node2D):
			continue
		var zn: Node2D = z as Node2D
		var r: float = 96.0
		if z is CampBehaviorZone:
			r = maxf(4.0, (z as CampBehaviorZone).radius)
		elif "radius" in z:
			r = maxf(4.0, float(z.radius))
		var cpos: Vector2 = zn.global_position
		var d: float = pos.distance_to(cpos)
		if d > r:
			continue
		var score: float = r - d
		if score > best_score:
			best_score = score
			best = zn
	if best == null:
		return
	var bz: Node = best
	_standing_zone_node = bz
	_standing_zone_center = best.global_position
	if bz is CampBehaviorZone:
		var cb: CampBehaviorZone = bz as CampBehaviorZone
		_standing_zone_type = str(cb.zone_type).strip_edges()
		_standing_zone_radius = maxf(4.0, cb.radius)
		_standing_idle_override = str(cb.idle_style_override).strip_edges()
		_standing_face_mode = str(cb.face_mode).strip_edges().to_lower()
		var fd: Vector2 = cb.facing_dir
		if fd.length() > 0.001:
			_standing_facing_dir = fd.normalized()
	else:
		if "zone_type" in bz:
			_standing_zone_type = str(bz.zone_type).strip_edges()
		if "radius" in bz:
			_standing_zone_radius = maxf(4.0, float(bz.radius))
		if "idle_style_override" in bz:
			_standing_idle_override = str(bz.idle_style_override).strip_edges()
		if "face_mode" in bz:
			_standing_face_mode = str(bz.face_mode).strip_edges().to_lower()
		if "facing_dir" in bz:
			var fd2: Variant = bz.facing_dir
			if fd2 is Vector2 and (fd2 as Vector2).length() > 0.001:
				_standing_facing_dir = (fd2 as Vector2).normalized()


func _refresh_solo_visual_behavior() -> void:
	if _wander_paused:
		return
	if str(_ambient_social_pose).strip_edges() != "":
		return
	var candidates: Array = _build_solo_candidates()
	var picked: String = ""
	if candidates.is_empty():
		picked = str(_idle_style).strip_edges().to_lower()
	else:
		picked = _weighted_pick_solo_style(candidates)
	if picked == "":
		picked = "neutral"
	_solo_visual_style = picked
	_resolve_activity_anchor_for_standing(global_position)
	_assign_routine_for_style(_solo_visual_style)
	_idle_pose_applied = false


func _apply_standing_facing_from_anchor(cand: CampActivityAnchor) -> void:
	if cand.facing_dir.length() > 0.001:
		_standing_facing_dir = cand.facing_dir.normalized()
	var fm: String = str(cand.face_mode).strip_edges().to_lower()
	if fm != "":
		_standing_face_mode = fm


func _resolve_activity_anchor_for_standing(near_pos: Vector2) -> void:
	_standing_activity_anchor = null
	if _camp_ctx == null or _standing_zone_node == null or not is_instance_valid(_standing_zone_node):
		return
	var cand: CampActivityAnchor = _camp_ctx.pick_best_standing_activity_anchor(_standing_zone_node, near_pos, _effective_idle_style())
	if cand == null or not is_instance_valid(cand):
		return
	var dist: float = near_pos.distance_to(cand.global_position)
	if dist <= STANDING_ANCHOR_PHYSICS_MAX_DIST:
		_standing_activity_anchor = cand
		_apply_standing_facing_from_anchor(cand)
	elif dist <= STANDING_ANCHOR_FACING_ONLY_MAX_DIST:
		_apply_standing_facing_from_anchor(cand)


func _effective_idle_style() -> String:
	var s: String = str(_solo_visual_style).strip_edges().to_lower()
	if s != "":
		return s
	return str(_idle_style).strip_edges().to_lower()


func _assign_routine_for_style(style: String) -> void:
	var s: String = str(style).strip_edges().to_lower()
	_solo_routine_phase = randf() * TAU
	_solo_routine_orbit_r = randf_range(4.5, 7.5)
	_solo_routine_vec = Vector2.RIGHT.rotated(randf() * TAU)
	var zt: String = _standing_zone_type.strip_edges().to_lower()
	match s:
		"patrol", "inspect_wall", "sort_supplies", "sweep_area":
			_solo_routine_kind = "patrol_ping"
		"tend_fire", "warm_hands":
			if zt in ["fire", "cook", "cook_area"]:
				_solo_routine_kind = "fire_orbit"
			else:
				_solo_routine_kind = "shift_side"
		"sit_rest", "rest_head_down":
			_solo_routine_kind = "sit_pulse"
		"kneel_prayer", "pray_quietly":
			_solo_routine_kind = "kneel_pulse"
		"look_out", "check_gear", "sharpen", "carry_bundle", "pour_water", "wash_hands", "read_notes", "stretch", "workbench_tinker":
			_solo_routine_kind = "shift_side"
		_:
			_solo_routine_kind = ""
	if _solo_routine_kind != "":
		_solo_routine_anchor = global_position


func _clamp_pos_to_standing_and_home(p: Vector2) -> Vector2:
	var out: Vector2 = p
	if _standing_activity_anchor is CampActivityAnchor:
		var aa: CampActivityAnchor = _standing_activity_anchor as CampActivityAnchor
		var rad_a: float = maxf(4.5, aa.occupancy_radius)
		var ag: Vector2 = aa.global_position
		var va: Vector2 = out - ag
		if va.length() > rad_a and va.length() > 0.001:
			out = ag + va.normalized() * rad_a
	if _standing_zone_center != Vector2.ZERO and _standing_zone_radius > 1.0:
		var max_d: float = maxf(5.0, _standing_zone_radius * 0.62)
		var v: Vector2 = out - _standing_zone_center
		if v.length() > max_d and v.length() > 0.001:
			out = _standing_zone_center + v.normalized() * max_d
	if home_position != Vector2.ZERO:
		var v2: Vector2 = out - home_position
		if v2.length() > roam_radius and v2.length() > 0.001:
			out = home_position + v2.normalized() * roam_radius
	return out


func _solo_routine_slide_toward(target: Vector2, delta: float) -> void:
	var step: float = maxf(SOLO_ROUTINE_POSITION_SPEED * delta, 0.001)
	global_position = global_position.move_toward(_clamp_pos_to_standing_and_home(target), step)


func _apply_solo_routine_position(delta: float) -> void:
	if _solo_routine_kind == "":
		return
	match _solo_routine_kind:
		"patrol_ping":
			var amp: float = 5.0
			if _standing_zone_radius > 1.0:
				amp = clampf(_standing_zone_radius * 0.22, 4.0, 11.0)
			var off: Vector2 = _solo_routine_vec * sin(_solo_routine_phase * 1.12) * amp
			_solo_routine_slide_toward(_solo_routine_anchor + off, delta)
		"fire_orbit":
			var rr_loc: float = clampf(_solo_routine_orbit_r * FIRE_ORBIT_LOCAL_R_MULT, FIRE_ORBIT_LOCAL_R_MIN, FIRE_ORBIT_LOCAL_R_MAX)
			var orb_local: Vector2 = _solo_routine_anchor + Vector2(cos(_solo_routine_phase * 0.92), sin(_solo_routine_phase * 0.92)) * rr_loc
			_solo_routine_slide_toward(orb_local, delta)
		"shift_side":
			var sh: Vector2 = Vector2(sin(_solo_routine_phase * 1.35), cos(_solo_routine_phase * 0.85) * 0.35) * 3.0
			_solo_routine_slide_toward(_solo_routine_anchor + sh, delta)
		_:
			pass


func _style_pose_offset_rot(style: String) -> Vector3:
	var s: String = str(style).strip_edges().to_lower()
	match s:
		"neutral":
			return Vector3(0.0, 0.0, 0.0)
		"warm_hands":
			return Vector3(0.0, -2.0, deg_to_rad(-3.0))
		"read_notes":
			return Vector3(0.0, 1.0, deg_to_rad(-3.5))
		"inspect_wall":
			return Vector3(1.0, 0.0, deg_to_rad(3.2))
		"pray_quietly":
			return Vector3(0.0, 2.0, deg_to_rad(1.0))
		"check_gear":
			return Vector3(0.0, 1.0, deg_to_rad(2.0))
		"tinker_small", "workbench_tinker":
			return Vector3(0.0, 3.0, deg_to_rad(-2.2))
		"look_out":
			return Vector3(0.0, -1.0, deg_to_rad(1.2))
		"patrol":
			return Vector3(0.5, 0.0, deg_to_rad(1.8))
		"sit_rest":
			return Vector3(0.0, 4.0, deg_to_rad(4.0))
		"stretch":
			return Vector3(0.0, -3.0, deg_to_rad(-4.0))
		"sharpen":
			return Vector3(1.0, 2.0, deg_to_rad(3.5))
		"sort_supplies":
			return Vector3(0.0, 2.0, deg_to_rad(-2.0))
		"carry_bundle", "carry_bowl":
			return Vector3(1.0, 1.0, deg_to_rad(-5.0))
		"kneel_prayer":
			return Vector3(0.0, 5.0, deg_to_rad(8.0))
		"tend_fire":
			return Vector3(0.0, 0.0, deg_to_rad(3.0))
		"sweep_area":
			return Vector3(2.0, 2.0, deg_to_rad(2.5))
		"wash_hands":
			return Vector3(0.0, 3.0, deg_to_rad(-3.0))
		"pour_water":
			return Vector3(0.0, 2.0, deg_to_rad(2.2))
		"rest_head_down":
			return Vector3(0.0, 5.0, deg_to_rad(6.0))
		_:
			return Vector3(0.0, 0.0, 0.0)


func _apply_pose_facing_for_standing(_unused_style: String) -> void:
	if sprite == null:
		return
	if _standing_zone_center != Vector2.ZERO:
		var dir: Vector2 = Vector2.ZERO
		if _standing_face_mode == "outward" and _standing_facing_dir.length() > 0.001:
			dir = _standing_facing_dir
		else:
			dir = _standing_zone_center - global_position
		if dir.length() > 0.001:
			sprite.flip_h = dir.x < 0.0
	elif _current_zone_center != Vector2.ZERO:
		var dir2: Vector2 = _current_zone_facing_dir
		if dir2 == Vector2.ZERO:
			dir2 = _current_zone_center - global_position
		if dir2.length() > 0.001:
			sprite.flip_h = dir2.x < 0.0


func _apply_idle_style() -> void:
	if sprite == null:
		return
	_solo_routine_anchor = global_position
	_idle_pose_applied = true


func _apply_solo_idle_frame(delta: float) -> void:
	if str(_ambient_social_pose).strip_edges() != "":
		return
	if not _idle_pose_applied:
		return
	if sprite == null:
		return
	_solo_routine_phase += delta * 1.05
	_apply_solo_routine_position(delta)
	var style: String = _effective_idle_style()
	var spr: Vector3 = _style_pose_offset_rot(style)
	var pulse_y: float = 0.0
	var pulse_rot: float = 0.0
	match _solo_routine_kind:
		"sit_pulse":
			pulse_y = sin(_solo_routine_phase * 2.2) * 0.85
		"kneel_pulse":
			var ph: float = _solo_routine_phase * 1.55
			pulse_y = sin(ph) * 0.55
			pulse_rot = sin(ph) * deg_to_rad(1.1)
		_:
			pass
	_apply_pose_facing_for_standing(style)
	sprite.position = _base_sprite_offset + Vector2(spr.x, spr.y + pulse_y)
	sprite.rotation = spr.z + pulse_rot


func _reset_idle_pose() -> void:
	if sprite == null:
		_idle_pose_applied = false
		return
	sprite.position = _base_sprite_offset
	sprite.rotation = 0.0
	_idle_pose_applied = false

func is_available_for_chatter() -> bool:
	return is_available_for_social()

func is_available_for_social() -> bool:
	return not _wander_paused and _social_state == SOCIAL_STATE_FREE

func face_toward(target: Vector2) -> void:
	if sprite == null:
		return
	var to_target: Vector2 = target - global_position
	if abs(to_target.x) > 1.0:
		var new_flip: bool = to_target.x < 0.0
		if sprite.flip_h != new_flip:
			sprite.flip_h = new_flip
			_play_turn_settle()

func play_speaking_bob() -> void:
	if sprite == null:
		return
	if _reaction_tween != null and is_instance_valid(_reaction_tween):
		_reaction_tween.kill()
	var up_offset: Vector2 = _base_sprite_offset + Vector2(0, -STEP_BOB_HEIGHT * _get_condition_bob_multiplier())
	_reaction_tween = get_tree().create_tween()
	_reaction_tween.tween_property(sprite, "position", up_offset, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_reaction_tween.tween_property(sprite, "position", _base_sprite_offset, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_reaction_tween.parallel().tween_property(sprite, "rotation", deg_to_rad(0.8 if not sprite.flip_h else -0.8), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_reaction_tween.tween_property(sprite, "rotation", 0.0, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func begin_speaking() -> void:
	_social_state = SOCIAL_STATE_SPEAKING
	play_speaking_bob()

func end_speaking() -> void:
	if _social_state == SOCIAL_STATE_SPEAKING:
		_social_state = SOCIAL_STATE_SETTLED

func begin_listening() -> void:
	_play_listener_reaction()

func end_listening() -> void:
	# Listener reaction is a short tween back to base; no extra state needed.
	pass

func begin_social_move(target_pos: Vector2) -> void:
	_social_move_active = true
	_social_target_pos = target_pos
	_social_move_arrived = false
	_social_state = SOCIAL_STATE_APPROACH
	_idle_timer = 0.0
	_social_idle_phase = randf() * TAU

func is_in_social_move() -> bool:
	return _social_move_active

func has_reached_social_target() -> bool:
	return _social_move_active and _social_move_arrived

func end_social_move() -> void:
	_social_move_active = false
	_social_move_arrived = false
	if _social_state == SOCIAL_STATE_APPROACH or _social_state == SOCIAL_STATE_SETTLED or _social_state == SOCIAL_STATE_SPEAKING:
		_social_state = SOCIAL_STATE_FREE
	clear_ambient_social_pose()
	_clear_social_animation_tweens()
	_update_standing_zone_at_position(global_position)
	_refresh_solo_visual_behavior()

func play_social_settle_beat() -> void:
	_play_arrival_settle()

func _compute_separation_vector() -> Vector2:
	var parent := get_parent()
	if parent == null:
		return Vector2.ZERO
	var sep: Vector2 = Vector2.ZERO
	for child in parent.get_children():
		if child == self:
			continue
		if not (child is CampRosterWalker):
			continue
		var other: CampRosterWalker = child as CampRosterWalker
		var offset: Vector2 = global_position - other.global_position
		var dist: float = offset.length()
		if dist <= 0.001:
			# Deterministic tiny push if perfectly overlapped
			var angle: float = float(get_instance_id() & 1023) / 1023.0 * TAU
			var overlap_push_dir: Vector2 = Vector2(cos(angle), sin(angle))
			var weight0: float = 1.0
			sep += overlap_push_dir * weight0
			continue
		if dist >= PERSONAL_SPACE_RADIUS:
			continue
		var push_dir: Vector2 = offset / dist
		var t: float = (PERSONAL_SPACE_RADIUS - dist) / PERSONAL_SPACE_RADIUS
		var weight: float = t * t
		sep += push_dir * (0.28 + weight * 1.34)
	return sep

func _apply_personal_space_correction(delta: float, strength_scale: float = 1.0) -> void:
	var sep: Vector2 = _compute_separation_vector()
	if sep.length() <= 0.001:
		return
	var strength: float = maxf(0.0, strength_scale)
	var push: Vector2 = sep * HARD_SEPARATION_SPEED * strength * delta
	var max_step: float = HARD_SEPARATION_MAX_SPEED * maxf(0.35, strength) * delta
	if push.length() > max_step and max_step > 0.0:
		push = push.normalized() * max_step
	global_position += push

func _choose_random_home_target() -> Vector2:
	var angle: float = randf() * TAU
	var r: float = randf_range(0.2, 1.0) * roam_radius
	return home_position + Vector2(cos(angle), sin(angle)) * r

func _get_zone_candidate_score(zone: Node2D, zone_type: String, is_preferred: bool) -> float:
	var radius: float = float(zone.radius) if "radius" in zone else 32.0
	var capacity: int = maxi(1, int(zone.capacity)) if "capacity" in zone else 2
	var weight: float = maxf(0.25, float(zone.weight)) if "weight" in zone else 1.0
	var occupancy: int = 0
	var crowding: float = 0.0
	var parent := get_parent()
	if parent != null:
		for child in parent.get_children():
			if child == self or not (child is CampRosterWalker):
				continue
			var other: CampRosterWalker = child as CampRosterWalker
			var dist_to_zone: float = other.global_position.distance_to(zone.global_position)
			var relevant_radius: float = maxf(radius + 14.0, PERSONAL_SPACE_RADIUS * 1.35)
			if dist_to_zone <= relevant_radius or other._current_zone_type == zone_type:
				occupancy += 1
				crowding += clampf(1.0 - (dist_to_zone / maxf(relevant_radius, 1.0)), 0.0, 1.0)
	var score: float = weight
	score += 0.32 if is_preferred else 0.08
	score -= float(occupancy) / float(capacity)
	score -= crowding * 0.35
	if _current_zone_type == zone_type:
		score += 0.12
	score += randf() * 0.18
	return score

func _choose_zone_target_position() -> Vector2:
	if _zones.is_empty():
		_target_is_zone = false
		_current_zone_type = ""
		_current_zone_center = Vector2.ZERO
		_current_zone_facing_dir = Vector2.ZERO
		return _choose_random_home_target()

	var preferred: Array = _behavior_profile.get("preferred_zones", [])
	var secondary: Array = _behavior_profile.get("secondary_zones", [])
	var best_zone: Node2D = null
	var best_score: float = -99999.0

	for z in _zones:
		if not z is Node2D:
			continue
		var zone_node: Node2D = z as Node2D
		var z_type: String = ""
		if "zone_type" in zone_node:
			z_type = str(zone_node.zone_type).strip_edges()
		if z_type == "" or z_type not in preferred:
			continue
		var score: float = _get_zone_candidate_score(zone_node, z_type, true)
		if score > best_score:
			best_score = score
			best_zone = zone_node

	if best_zone == null:
		for z2 in _zones:
			if not z2 is Node2D:
				continue
			var zone_node2: Node2D = z2 as Node2D
			var z_type2: String = ""
			if "zone_type" in zone_node2:
				z_type2 = str(zone_node2.zone_type).strip_edges()
			if z_type2 == "" or z_type2 not in secondary:
				continue
			var score2: float = _get_zone_candidate_score(zone_node2, z_type2, false)
			if score2 > best_score:
				best_score = score2
				best_zone = zone_node2

	if best_zone == null:
		_target_is_zone = false
		_current_zone_type = ""
		_current_zone_center = Vector2.ZERO
		_current_zone_facing_dir = Vector2.ZERO
		return _choose_random_home_target()

	var center: Vector2 = best_zone.global_position
	_current_zone_type = str(best_zone.zone_type).strip_edges()
	_current_zone_center = center
	_current_zone_facing_dir = Vector2.ZERO
	if "face_mode" in best_zone:
		var mode: String = str(best_zone.face_mode).strip_edges().to_lower()
		if mode == "outward" and "facing_dir" in best_zone:
			var fd: Variant = best_zone.facing_dir
			if fd is Vector2 and (fd as Vector2).length() > 0.001:
				_current_zone_facing_dir = (fd as Vector2).normalized()
	var radius: float = float(best_zone.radius) if "radius" in best_zone else 32.0
	var angle: float = randf() * TAU
	var r: float
	if _current_zone_type in TIGHT_ZONE_TYPES:
		r = randf_range(0.0, min(radius, TIGHT_ZONE_MAX_DIST))
	elif _current_zone_type in MEDIUM_ZONE_TYPES:
		r = randf_range(0.1 * radius, 0.45 * radius)
	else:
		r = randf_range(0.2, 1.0) * radius
	_target_is_zone = true
	return center + Vector2(cos(angle), sin(angle)) * r

func _clear_social_animation_tweens() -> void:
	if _arrive_tween != null and is_instance_valid(_arrive_tween):
		_arrive_tween.kill()
	_arrive_tween = null
	if _reaction_tween != null and is_instance_valid(_reaction_tween):
		_reaction_tween.kill()
	_reaction_tween = null
	if _turn_tween != null and is_instance_valid(_turn_tween):
		_turn_tween.kill()
	_turn_tween = null
	if sprite != null:
		sprite.position = _base_sprite_offset
		sprite.rotation = 0.0


func clear_pair_listen_reaction_tweens() -> void:
	_clear_social_animation_tweens()

func _play_arrival_settle() -> void:
	if sprite == null:
		return
	if _arrive_tween != null and is_instance_valid(_arrive_tween):
		_arrive_tween.kill()
	_arrive_tween = get_tree().create_tween()
	var c_mult: float = _get_condition_bob_multiplier()
	var up_pos: Vector2 = _base_sprite_offset + Vector2(0, -ARRIVAL_SETTLE_UP * c_mult)
	var down_pos: Vector2 = _base_sprite_offset + Vector2(0, ARRIVAL_SETTLE_DOWN * c_mult)
	_arrive_tween.tween_property(sprite, "position", up_pos, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_arrive_tween.tween_property(sprite, "position", down_pos, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_arrive_tween.tween_property(sprite, "position", _base_sprite_offset, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _play_turn_settle() -> void:
	if sprite == null:
		return
	if _turn_tween != null and is_instance_valid(_turn_tween):
		_turn_tween.kill()
	var lean: float = deg_to_rad(TURN_LEAN_DEG if not sprite.flip_h else -TURN_LEAN_DEG)
	_turn_tween = get_tree().create_tween()
	_turn_tween.tween_property(sprite, "rotation", lean, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_turn_tween.tween_property(sprite, "rotation", 0.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _play_listener_reaction() -> void:
	if sprite == null:
		return
	if _reaction_tween != null and is_instance_valid(_reaction_tween):
		_reaction_tween.kill()
	var c_mult: float = _get_condition_bob_multiplier()
	var up_pos: Vector2 = _base_sprite_offset + Vector2(0, -STEP_BOB_HEIGHT * LISTENER_BOB_MULT * c_mult)
	var down_rot: float = deg_to_rad(-0.9 if not sprite.flip_h else 0.9)
	_reaction_tween = get_tree().create_tween()
	_reaction_tween.tween_property(sprite, "position", up_pos, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_reaction_tween.parallel().tween_property(sprite, "rotation", down_rot, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_reaction_tween.tween_property(sprite, "position", _base_sprite_offset, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_reaction_tween.parallel().tween_property(sprite, "rotation", 0.0, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _play_social_idle_motion(delta: float) -> void:
	if sprite == null:
		return
	if (_arrive_tween != null and is_instance_valid(_arrive_tween)) or (_reaction_tween != null and is_instance_valid(_reaction_tween)):
		return
	var pace: float = SOCIAL_IDLE_BOB_SPEED
	var amp: float = SOCIAL_IDLE_BOB_HEIGHT
	var rot_amp: float = 0.0
	var x_shift_scale: float = 0.0
	var x_mirror: float = 1.0 if (get_instance_id() & 1) != 0 else -1.0
	match _ambient_social_pose:
		"spar", "mock_duel":
			pace *= 1.38
			amp *= 1.22
			rot_amp = deg_to_rad(1.15)
			x_shift_scale = 1.8
		"drill", "formation":
			pace *= 0.82
			amp *= 0.72
			rot_amp = deg_to_rad(0.55)
			x_shift_scale = 0.55
			x_mirror = 1.0
		"work", "work_detail", "repair":
			pace *= 0.68
			amp *= 0.58
			rot_amp = deg_to_rad(0.35)
			x_shift_scale = 0.35
			x_mirror = 1.0
		"fireside", "morale", "rhythm":
			pace *= 0.92
			amp *= 0.88
			rot_amp = deg_to_rad(0.45)
			x_shift_scale = 0.28
			x_mirror = 1.0
		_:
			pass
	_social_idle_phase += pace * delta
	var c_mult: float = _get_condition_bob_multiplier()
	var phase_off: float = float(get_instance_id() & 255) * 0.01
	var bob: float = sin(_social_idle_phase + phase_off) * amp * c_mult
	var x_shift: float = 0.0
	if x_shift_scale > 0.001:
		x_shift = sin(_social_idle_phase * 0.5 + phase_off) * x_shift_scale * x_mirror * c_mult
	sprite.position = _base_sprite_offset + Vector2(x_shift, bob)
	if rot_amp != 0.0:
		var rph: float = _social_idle_phase * 0.5
		if _ambient_social_pose in ["drill", "formation"]:
			rph = _social_idle_phase * 0.42
		sprite.rotation = sin(rph + phase_off * 0.5) * rot_amp * c_mult
	else:
		sprite.rotation = 0.0
