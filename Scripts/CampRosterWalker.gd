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
## Request marker: "none", "offer" (!), "turn_in" (?). Set by CampExplore.
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

const SOCIAL_STATE_FREE := 0
const SOCIAL_STATE_APPROACH := 1
const SOCIAL_STATE_SETTLED := 2
const SOCIAL_STATE_SPEAKING := 3
const SOCIAL_STATE_PAUSED := 4

var _social_state: int = SOCIAL_STATE_FREE

func _ready() -> void:
	home_position = global_position
	_target_pos = home_position
	if sprite != null:
		_base_sprite_offset = sprite.position
		var phase_seed: float = float(get_instance_id() & 1023) / 1023.0
		_drift_phase = phase_seed * TAU

## Call from CampExplore when dialogue opens/closes so wander pauses.
func set_wander_paused(paused: bool) -> void:
	_wander_paused = paused
	if paused:
		_clear_social_animation_tweens()
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
	_pick_next_idle()

func _process(_delta: float) -> void:
	if marker_label != null:
		if request_marker == "offer":
			marker_label.text = "!"
			marker_label.visible = true
		elif request_marker == "offer_personal":
			marker_label.text = "!!"
			marker_label.visible = true
		elif request_marker == "turn_in":
			marker_label.text = "?"
			marker_label.visible = true
		else:
			marker_label.visible = false
	if _wander_paused or sprite == null:
		_move_velocity = Vector2.ZERO
		_walk_cycle = 0.0
		if sprite != null:
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

func _apply_idle_style() -> void:
	if sprite == null:
		return
	_reset_idle_pose()
	if _current_zone_center != Vector2.ZERO:
		var dir: Vector2 = _current_zone_facing_dir
		if dir == Vector2.ZERO:
			dir = (_current_zone_center - global_position)
		if dir.length() > 0.001:
			sprite.flip_h = dir.x < 0.0
	match _idle_style:
		"warm_hands":
			sprite.position = _base_sprite_offset + Vector2(0, -2)
		"read_notes":
			sprite.position = _base_sprite_offset + Vector2(0, 1)
			sprite.rotation = deg_to_rad(-3.0)
		"inspect_wall":
			sprite.position = _base_sprite_offset + Vector2(1, 0)
			sprite.rotation = deg_to_rad(3.0)
		"pray_quietly":
			sprite.position = _base_sprite_offset + Vector2(0, 2)
		"check_gear":
			sprite.position = _base_sprite_offset + Vector2(0, 1)
		"tinker_small":
			sprite.position = _base_sprite_offset + Vector2(0, 3)
		"look_out":
			sprite.position = _base_sprite_offset + Vector2(0, -1)
		_:
			pass
	_idle_pose_applied = true

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
	_clear_social_animation_tweens()

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
	_social_idle_phase += SOCIAL_IDLE_BOB_SPEED * delta
	var c_mult: float = _get_condition_bob_multiplier()
	var bob: float = sin(_social_idle_phase) * SOCIAL_IDLE_BOB_HEIGHT * c_mult
	sprite.position = _base_sprite_offset + Vector2(0, bob)
