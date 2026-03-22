# AI Turn State
#
# Utility-based AI decision making for tactical RPG turns.
# Controls a faction ("enemy" or "ally") and selects a plan for each unit.
# Indentation uses tabs to avoid copy/paste issues in Godot.

extends GameState
class_name AITurnState

signal turn_finished



const TYPE_HOSTILE: String = "hostile"
const TYPE_CRATE: String = "crate"
const TYPE_ALLY_HEAL: String = "ally_heal"
const TYPE_ALLY_BUFF: String = "ally_buff"
const TYPE_ALLY_FOLLOW: String = "ally_follow"
const TYPE_CHEST: String = "chest"
const TYPE_ESCAPE: String = "escape"

const AI_CAMERA_OFFSET_Y: float = 250.0
const AI_CAMERA_TWEEN_TIME_PREMOVE: float = 0.55
const AI_CAMERA_TWEEN_TIME_POSTMOVE: float = 0.40

const AI_CAMERA_LEFT_MARGIN: float = -400.0
const AI_CAMERA_RIGHT_MARGIN: float = 400.0
const AI_CAMERA_TOP_MARGIN: float = -250.0
const AI_CAMERA_BOTTOM_MARGIN: float = 400.0

# --- Optional archetypes ---
const ARCHETYPE_NONE: String = ""
const ARCHETYPE_ASSASSIN: String = "assassin"
const ARCHETYPE_GUARDIAN: String = "guardian"
const ARCHETYPE_PACK_HUNTER: String = "pack_hunter"
const ARCHETYPE_OPPORTUNIST: String = "opportunist"

# --- Threat / retaliation avoidance tuning ---
const DANGER_WEIGHT_RANGED: float = 2.5
const DANGER_WEIGHT_MELEE: float = 1.5
const DANGER_DEATH_PENALTY: float = 60.0

# Set true to log one line per unit when flier dive or squad/focus reasons apply. Easy to disable.
const DEBUG_AI_SCORING: bool = false

# --- Tactical scoring bonuses ---
const BONUS_FINISH_KILL: float = 95.0
const BONUS_TARGET_SUPPORT: float = 70.0
const BONUS_TARGET_LEADER: float = 90.0
const BONUS_FOCUS_FIRE: float = 18.0
const BONUS_FOCUS_KILL: float = 28.0
const BONUS_JOIN_PRESSURE: float = 22.0
const BONUS_SAVE_CRITICAL_ALLY: float = 180.0
const PENALTY_FOLLOW_WHEN_HOSTILE_REACHABLE: float = 650.0
const HOSTILE_DISTANCE_PENALTY_PER_TILE: float = 18.0
const HOSTILE_WOUNDED_BONUS_MAX: float = 38.0
const BONUS_HEAL_LEADER: float = 90.0
const BONUS_PROTECT_THREATENED_ALLY: float = 65.0
const BONUS_CRATE_IF_ENEMY_REACHABLE: float = -900.0
const PENALTY_LOW_HP_BAD_FIGHT: float = 100.0
const PENALTY_TARGET_OVERPROTECTED: float = 50.0

# Indicates which faction this AI controls ("enemy" or "ally").
var faction: String = "enemy"

# Tracks a target that the faction is already focusing on.
var _focus_target: Node2D = null

func _init(p_faction: String = "enemy") -> void:
	faction = p_faction

# --- SAFE PROPERTY HELPERS ---
func _i(u: Object, key: String, default_val: int = 0) -> int:
	var v = u.get(key)
	return default_val if v == null else int(v)

func _b(u: Object, key: String, default_val: bool = false) -> bool:
	var v = u.get(key)
	return default_val if v == null else bool(v)

func _weapon(u: Object) -> Resource:
	return u.get("equipped_weapon") as Resource

func _get_ai_archetype(unit: Object) -> String:
	var v = unit.get("ai_archetype")
	if v == null:
		return ARCHETYPE_NONE
	return str(v).strip_edges().to_lower()

func _weapon_is_magic(w: Resource) -> bool:
	if w == null:
		return false
	var dmg_type_v = w.get("damage_type")
	return dmg_type_v != null and int(dmg_type_v) == int(WeaponData.DamageType.MAGIC)

func _hp_ratio(u: Object) -> float:
	return float(_i(u, "current_hp")) / max(1.0, float(_i(u, "max_hp", 1)))

func _is_support_unit(u: Node2D) -> bool:
	if u == null:
		return false
	var w: Resource = _weapon(u)
	if w == null:
		return false
	return _b(w, "is_healing_staff") or _b(w, "is_buff_staff")

func _is_leader(u: Node2D) -> bool:
	if u == null:
		return false
	return _b(u, "is_custom_avatar")

func _get_attack_power(attacker: Node2D) -> int:
	if attacker == null:
		return 0

	var w: Resource = _weapon(attacker)
	var atk: int = 0

	if _weapon_is_magic(w):
		atk = _i(attacker, "magic")
	else:
		atk = _i(attacker, "strength")

	if w != null:
		atk += _i(w, "might")

	return atk

func _get_defense_stat_against(defender: Node2D, attacking_weapon: Resource) -> int:
	if defender == null:
		return 0
	if _weapon_is_magic(attacking_weapon):
		return _i(defender, "resistance")
	return _i(defender, "defense")

func _estimate_unit_threat(u: Node2D) -> int:
	if u == null:
		return 0

	var threat: int = _get_attack_power(u)
	threat += _i(u, "move_range")

	var w: Resource = _weapon(u)
	if w != null:
		threat += _i(w, "max_range")
		if _weapon_is_magic(w):
			threat += 2
		if _b(w, "is_healing_staff"):
			threat += 8
		if _b(w, "is_buff_staff"):
			threat += 6

	if _is_leader(u):
		threat += 12

	threat += int(_hp_ratio(u) * 10.0)
	return threat

func _distance_to_nearest_unit_from(pos: Vector2i, units: Array[Node2D], ignore: Node2D = null) -> int:
	var best: int = 999999
	for u: Node2D in units:
		if u == ignore:
			continue
		if not is_instance_valid(u) or _i(u, "current_hp") <= 0:
			continue
		best = min(best, _grid_dist(pos, battlefield.get_grid_pos(u)))
	return best

func _count_units_within_distance(pos: Vector2i, units: Array[Node2D], max_dist: int, ignore: Node2D = null) -> int:
	var count: int = 0
	for u: Node2D in units:
		if u == ignore:
			continue
		if not is_instance_valid(u) or _i(u, "current_hp") <= 0:
			continue
		if _grid_dist(pos, battlefield.get_grid_pos(u)) <= max_dist:
			count += 1
	return count

func _get_guard_anchor(friendlies: Array[Node2D], unit: Node2D) -> Node2D:
	var best_anchor: Node2D = null
	var best_score: float = -999999.0

	for ally: Node2D in friendlies:
		if ally == unit:
			continue
		if not is_instance_valid(ally) or _i(ally, "current_hp") <= 0:
			continue

		var score: float = 0.0
		score += _estimate_unit_threat(ally) * 3.0

		if _is_leader(ally):
			score += 200.0
		if _is_support_unit(ally):
			score += 90.0

		score += _hp_ratio(ally) * 20.0

		if score > best_score:
			best_score = score
			best_anchor = ally

	return best_anchor

func _get_action_range_for(unit: Node2D, target_type: String) -> Dictionary:
	match target_type:
		TYPE_CHEST:
			return {"min": 1, "max": 1}
		TYPE_ESCAPE:
			return {"min": 1, "max": 1}
		TYPE_ALLY_FOLLOW:
			var behavior: int = _i(unit, "ai_behavior")
			if behavior == 3: # Coward
				return {"min": 3, "max": 5}
			elif behavior == 5: # Minion
				return {"min": 2, "max": 3}
			return {"min": 1, "max": 2}
		_:
			var wpn: Resource = _weapon(unit)
			return {
				"min": _i(wpn, "min_range", 1) if wpn != null else 1,
				"max": _i(wpn, "max_range", 1) if wpn != null else 1
			}

func _can_act_from_tile(unit: Node2D, tile_pos: Vector2i, target: Node2D, target_type: String) -> bool:
	if unit == null or target == null or not is_instance_valid(target):
		return false

	var action_range: Dictionary = _get_action_range_for(unit, target_type)
	var min_r: int = int(action_range["min"])
	var max_r: int = int(action_range["max"])
	var target_pos: Vector2i = battlefield.get_grid_pos(target)
	var dist: int = _grid_dist(tile_pos, target_pos)

	if dist < min_r or dist > max_r:
		return false

	var occupier: Node2D = battlefield.get_occupant_at(tile_pos)
	return occupier == null or occupier == unit

func _can_reach_target_this_turn(unit: Node2D, target: Node2D, target_type: String, reachable_tiles: Array[Vector2i]) -> bool:
	if unit == null or target == null or not is_instance_valid(target):
		return false

	for pos: Vector2i in reachable_tiles:
		if _can_act_from_tile(unit, pos, target, target_type):
			return true

	return false

func enter(p_battlefield: Node2D) -> void:
	super.enter(p_battlefield)
	_focus_target = null

	var my_container: Node = (battlefield.enemy_container as Node) if faction == "enemy" else (battlefield.ally_container as Node)
	if my_container == null:
		emit_signal("turn_finished")
		return

	for unit: Node in my_container.get_children():
		var u := unit as Node2D
		if is_instance_valid(u) and u.has_method("reset_turn"):
			u.reset_turn()

	execute_ai_turn(my_container)

# -----------------------------------------------------------------------------
# Faction helpers
# -----------------------------------------------------------------------------
func _friendly_parents() -> Array[Node]:
	if faction == "enemy":
		return [battlefield.enemy_container as Node]
	return [battlefield.player_container as Node, battlefield.ally_container as Node]

func _hostile_parents() -> Array[Node]:
	if faction == "enemy":
		return [battlefield.player_container as Node, battlefield.ally_container as Node]
	return [battlefield.enemy_container as Node]

func _is_friendly_target(target: Node2D) -> bool:
	if target == null:
		return false
	var p: Node = target.get_parent()
	return _friendly_parents().has(p)

func _is_friendly_destructible(d: Node2D) -> bool:
	var sf_v = d.get("spawner_faction")
	if sf_v != null:
		var sf = int(sf_v)
		# From EnemySpawner.gd: Faction { ENEMY=0, ALLY=1, PLAYER=2 }
		if faction == "enemy" and sf == 0:
			return true
		if faction == "ally" and (sf == 1 or sf == 2):
			return true
	return false

func _get_crate_at(pos: Vector2i) -> Node2D:
	if battlefield.destructibles_container:
		for dnode: Node in battlefield.destructibles_container.get_children():
			var d := dnode as Node2D
			if is_instance_valid(d) and battlefield.get_grid_pos(d) == pos:
				if not _is_friendly_destructible(d):
					return d
	return null

# -----------------------------------------------------------------------------
# Threat helpers
# -----------------------------------------------------------------------------
func _get_live_units_in(parents: Array[Node]) -> Array[Node2D]:
	var units: Array[Node2D] = []

	for c: Node in parents:
		if c == null:
			continue

		for n: Node in c.get_children():
			var u := n as Node2D
			if not is_instance_valid(u):
				continue
			if not _is_valid_ai_target(u):
				continue
			if _i(u, "current_hp") <= 0:
				continue

			units.append(u)

	return units
	
func _grid_dist(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func _estimate_raw_damage(attacker: Node2D, defender: Node2D) -> int:
	if attacker == null or defender == null:
		return 0

	var w: Resource = _weapon(attacker)
	var atk: int = _get_attack_power(attacker)
	var def_stat: int = _get_defense_stat_against(defender, w)

	return max(0, atk - def_stat)

func _enemy_threatens_pos(enemy: Node2D, pos: Vector2i) -> bool:
	if enemy == null:
		return false

	var w: Resource = _weapon(enemy)
	var min_r: int = 1
	var max_r: int = 1

	if w != null:
		min_r = _i(w, "min_range", 1)
		max_r = _i(w, "max_range", 1)

	var epos: Vector2i = battlefield.get_grid_pos(enemy)
	var d: int = _grid_dist(epos, pos)
	return d >= min_r and d <= max_r

func _incoming_damage_at(pos: Vector2i, unit: Node2D, enemies: Array[Node2D], ignored_enemy: Node2D = null) -> int:
	var total: int = 0
	for e: Node2D in enemies:
		if e == ignored_enemy:
			continue
		if not is_instance_valid(e) or _i(e, "current_hp") <= 0:
			continue
		if _enemy_threatens_pos(e, pos):
			total += max(1, _estimate_raw_damage(e, unit))
	return total


## Flying/cavalry only: after combat, spend leftover move to step toward lower threat (retreat / reposition).
func _ai_try_canto_move(unit: Node2D, remaining: float) -> void:
	if battlefield == null or not is_instance_valid(unit) or remaining <= 0.001:
		return
	if not battlefield.unit_supports_canto(unit):
		return
	unit.has_moved = true
	unit.in_canto_phase = true
	unit.canto_move_budget = remaining
	battlefield.rebuild_grid()
	battlefield.calculate_ranges(unit)
	var here: Vector2i = battlefield.get_grid_pos(unit)
	var candidates: Array[Vector2i] = []
	for t in battlefield.reachable_tiles:
		if t == here:
			continue
		candidates.append(t)
	if candidates.is_empty():
		unit.in_canto_phase = false
		unit.canto_move_budget = 0
		return
	var enemies: Array[Node2D] = _get_live_units_in(_hostile_parents())
	var best: Vector2i = candidates[0]
	var best_score: float = -999999.0
	for t in candidates:
		var dang: int = _incoming_damage_at(t, unit, enemies, null)
		var score: float = -float(dang) * 2.0
		score += float(_distance_to_nearest_unit_from(t, enemies)) * 1.5
		if score > best_score:
			best_score = score
			best = t
	var path: Array = battlefield.get_unit_path(unit, here, best)
	if path.size() <= 1:
		unit.in_canto_phase = false
		unit.canto_move_budget = 0
		return
	var pc: float = battlefield.get_path_move_cost(path, unit)
	if pc > remaining + 0.001:
		unit.in_canto_phase = false
		unit.canto_move_budget = 0
		return
	await unit.move_along_path(path)
	unit.in_canto_phase = false
	unit.canto_move_budget = 0
	if faction == "ally":
		battlefield.update_fog_of_war()
	battlefield.rebuild_grid()


# -----------------------------------------------------------------------------
# Planning
# -----------------------------------------------------------------------------
func get_best_plan_for(unit: Node2D, exclude_plans: Array = [], allowed_types: Array = []) -> Dictionary:
	if unit == null or not is_instance_valid(unit):
		return {}
	if exclude_plans == null:
		exclude_plans = []
	if allowed_types == null:
		allowed_types = []

	var best_target: Node2D = null
	var best_type: String = ""
	var highest_score: float = -999999.0

	var behavior: int = _i(unit, "ai_behavior")
	var intel: int = _i(unit, "ai_intelligence", 1)
	var archetype: String = _get_ai_archetype(unit)
	var is_flying: bool = _is_flying_unit(unit)

	var wpn: Resource = _weapon(unit)
	var has_heal: bool = (wpn != null and bool(wpn.get("is_healing_staff")) == true)
	var has_buff: bool = (wpn != null and bool(wpn.get("is_buff_staff")) == true)
	var is_coward: bool = (behavior == 3)
	var is_minion: bool = (behavior == 5)

	var potential_targets: Array[Dictionary] = []
	var friendly_containers: Array[Node] = []
	var hostile_containers: Array[Node] = []

	for c: Node in _friendly_parents():
		if c != null:
			friendly_containers.append(c)

	for c: Node in _hostile_parents():
		if c != null:
			hostile_containers.append(c)

	var live_friendlies: Array[Node2D] = _get_live_units_in(friendly_containers)
	var live_hostiles: Array[Node2D] = _get_live_units_in(hostile_containers)
	var guard_anchor: Node2D = null

	if archetype == ARCHETYPE_GUARDIAN:
		guard_anchor = _get_guard_anchor(live_friendlies, unit)

	# --- COWARD LOGIC ---
	if is_coward:
		for container in friendly_containers:
			for ally_node in container.get_children():
				var ally := ally_node as Node2D
				if is_instance_valid(ally) and _is_valid_ai_target(ally) and _i(ally, "current_hp") > 0 and ally != unit:
					var ally_beh: int = _i(ally, "ai_behavior")
					if ally_beh != 3:
						potential_targets.append({"node": ally, "type": TYPE_ALLY_FOLLOW})

	if has_heal or has_buff:
		for container: Node in friendly_containers:
			for ally_node: Node in container.get_children():
				var ally := ally_node as Node2D
				if not is_instance_valid(ally):
					continue
				if not _is_valid_ai_target(ally):
					continue
				if _i(ally, "current_hp") <= 0 or ally == unit:
					continue

				if has_heal and _i(ally, "current_hp") < _i(ally, "max_hp"):
					potential_targets.append({"node": ally, "type": TYPE_ALLY_HEAL})
				elif has_buff:
					potential_targets.append({"node": ally, "type": TYPE_ALLY_BUFF})

		if is_instance_valid(guard_anchor) and guard_anchor != unit:
			potential_targets.append({"node": guard_anchor, "type": TYPE_ALLY_FOLLOW})

		if potential_targets.is_empty():
			for container2: Node in friendly_containers:
				for ally_node2: Node in container2.get_children():
					var ally2 := ally_node2 as Node2D
					if not is_instance_valid(ally2):
						continue
					if not _is_valid_ai_target(ally2):
						continue
					if _i(ally2, "current_hp") <= 0 or ally2 == unit:
						continue
					potential_targets.append({"node": ally2, "type": TYPE_ALLY_FOLLOW})
	else:
		for container_h: Node in hostile_containers:
			for hostile_node: Node in container_h.get_children():
				var hostile := hostile_node as Node2D
				if is_instance_valid(hostile) and _is_valid_ai_target(hostile) and _i(hostile, "current_hp") > 0:
					potential_targets.append({"node": hostile, "type": TYPE_HOSTILE})

		if is_minion:
			for container in friendly_containers:
				for ally_node in container.get_children():
					var ally := ally_node as Node2D
					if is_instance_valid(ally) and _is_valid_ai_target(ally) and _i(ally, "current_hp") > 0 and ally != unit:
						var a_intel: int = _i(ally, "ai_intelligence", 1)
						if a_intel >= 5:
							potential_targets.append({"node": ally, "type": TYPE_ALLY_FOLLOW})

		if is_instance_valid(guard_anchor) and guard_anchor != unit:
			potential_targets.append({"node": guard_anchor, "type": TYPE_ALLY_FOLLOW})

		if behavior == 1 and battlefield.destructibles_container != null:
			for crate_node: Node in battlefield.destructibles_container.get_children():
				var crate := crate_node as Node2D
				if is_instance_valid(crate) and _is_valid_ai_target(crate) and _i(crate, "current_hp") > 0:
					if not _is_friendly_destructible(crate):
						potential_targets.append({"node": crate, "type": TYPE_CRATE})

		var is_thief = (behavior == 1)
		var stolen_loot = unit.get("stolen_loot")
		var has_loot = (_i(unit, "stolen_gold") > 0) or (stolen_loot != null and stolen_loot.size() > 0)

		if is_thief:
			if has_loot:
				var escape_node = battlefield.get_node_or_null("EscapePoint")
				if escape_node != null:
					potential_targets.append({"node": escape_node, "type": TYPE_ESCAPE})
				else:
					is_coward = true
			else:
				if battlefield.chests_container != null:
					for chest_node in battlefield.chests_container.get_children():
						var chest = chest_node as Node2D
						if is_instance_valid(chest) and _is_valid_ai_target(chest) and chest.get("is_locked") == true:
							potential_targets.append({"node": chest, "type": TYPE_CHEST})

	if potential_targets.is_empty():
		return {}

	# For DEBUG_AI_SCORING: store flier dive and squad/focus reasons when we pick a plan.
	var best_flier_dive_reasons: PackedStringArray = []
	var best_squad_reasons: PackedStringArray = []

	# Precompute friendlies for squad coordination (attackers_count, join_pressure) and intel>=4 heuristics.
	var friendlies: Array[Node2D] = []
	if intel >= 3:
		for cont in friendly_containers:
			for f in cont.get_children():
				var u2 := f as Node2D
				if is_instance_valid(u2) and _is_valid_ai_target(u2) and _i(u2, "current_hp") > 0:
					friendlies.append(u2)

	# Precompute reachable tiles for feasibility checks.
	battlefield.calculate_ranges(unit)
	var reachable_tiles: Array[Vector2i] = battlefield.reachable_tiles.duplicate()
	var unit_start_pos: Vector2i = battlefield.get_grid_pos(unit)
	if not reachable_tiles.has(unit_start_pos):
		reachable_tiles.append(unit_start_pos)
	battlefield.clear_ranges()

	var any_reachable_hostile: bool = false
	for info_check: Dictionary in potential_targets:
		var check_target := info_check.get("node") as Node2D
		var check_type: String = String(info_check.get("type"))
		if check_type == TYPE_HOSTILE and check_target != null and is_instance_valid(check_target):
			if _can_reach_target_this_turn(unit, check_target, check_type, reachable_tiles):
				any_reachable_hostile = true
				break

	# Evaluate each potential target.
	for info: Dictionary in potential_targets:
		var target := info.get("node") as Node2D
		var t: String = String(info.get("type"))
		if target == null or not is_instance_valid(target):
			continue
		if not _is_valid_ai_target(target):
			continue
		var skip_excluded: bool = false
		for ex in exclude_plans:
			if ex.get("node") == target and String(ex.get("type", "")) == t:
				skip_excluded = true
				break
		if skip_excluded:
			continue
		if allowed_types.size() > 0:
			var in_allowed: bool = false
			for at in allowed_types:
				if String(at) == t:
					in_allowed = true
					break
			if not in_allowed:
				continue

		var score: float = 0.0
		var dist: int = int(battlefield.get_distance(unit, target))
		var can_reach_this_turn: bool = _can_reach_target_this_turn(unit, target, t, reachable_tiles)
		var target_pos: Vector2i = battlefield.get_grid_pos(target)
		var squad_reasons: PackedStringArray = []
		var dive_result: Dictionary = {"bonus": 0.0, "reasons": []}

		if can_reach_this_turn:
			score += 1000.0
		else:
			score -= 500.0

		# --- Friendly actions ---
		if t == TYPE_ALLY_HEAL:
			var missing_hp: int = _i(target, "max_hp") - _i(target, "current_hp")
			var danger_on_ally: int = _incoming_damage_at(target_pos, target, live_hostiles)

			score += missing_hp * 10
			score += danger_on_ally * 8
			score -= dist * 5

			if danger_on_ally >= _i(target, "current_hp"):
				score += BONUS_SAVE_CRITICAL_ALLY

			if _hp_ratio(target) <= 0.35:
				score += 80

			if _is_leader(target):
				score += BONUS_HEAL_LEADER

			if intel >= 3:
				score += (_i(target, "defense") + _i(target, "strength") + _i(target, "magic")) * 2
				score += _estimate_unit_threat(target) * 2

			if archetype == ARCHETYPE_GUARDIAN and is_instance_valid(guard_anchor) and target == guard_anchor:
				score += 140

		elif t == TYPE_ALLY_BUFF:
			var buff_target_danger: int = _incoming_damage_at(target_pos, target, live_hostiles)

			score += (_i(target, "strength") + _i(target, "magic") + _i(target, "defense")) * 2
			score += _estimate_unit_threat(target) * 4
			score -= dist * 5

			if _is_leader(target):
				score += 40

			if _hp_ratio(target) <= 0.50:
				score -= 30

			if buff_target_danger >= _i(target, "current_hp"):
				score -= 60

			if intel >= 3:
				score += _i(target, "current_hp")

			if archetype == ARCHETYPE_GUARDIAN and is_instance_valid(guard_anchor) and target == guard_anchor:
				score += 120

		elif t == TYPE_ALLY_FOLLOW:
			var ally_danger: int = _incoming_damage_at(target_pos, target, live_hostiles)

			score -= dist * 5

			# Normal combat units should strongly prefer attacking a reachable hostile over following.
			if any_reachable_hostile and not has_heal and not has_buff:
				if is_minion:
					score -= PENALTY_FOLLOW_WHEN_HOSTILE_REACHABLE * 0.5
				elif archetype == ARCHETYPE_GUARDIAN:
					score -= PENALTY_FOLLOW_WHEN_HOSTILE_REACHABLE * 0.4
				else:
					score -= PENALTY_FOLLOW_WHEN_HOSTILE_REACHABLE

			if is_minion:
				score += 220

			if is_coward:
				score -= ally_danger * 4
				if ally_danger == 0:
					score += 50

			# Bodyguard: prefer protecting threatened commanders/supports/ranged backliners.
			if intel >= 2 and ally_danger > 0:
				if _is_leader(target):
					score += BONUS_PROTECT_THREATENED_ALLY
					squad_reasons.append("protect_boss")
				elif _is_support_unit(target):
					score += BONUS_PROTECT_THREATENED_ALLY
					squad_reasons.append("protect_support")
				else:
					var tw_ally: Resource = _weapon(target)
					if tw_ally != null and _i(tw_ally, "max_range", 1) > 1:
						score += 40
						squad_reasons.append("screen_backline")

			if intel >= 2:
				score += _i(target, "max_hp") * 2
				score += (_i(target, "defense") + _i(target, "strength")) * 3

			if intel >= 3:
				score += _i(target, "magic") * 2
				score += _count_units_within_distance(target_pos, live_friendlies, 2, target) * 8

			if archetype == ARCHETYPE_GUARDIAN and is_instance_valid(guard_anchor) and target == guard_anchor:
				score += 260

		# --- Destructible objectives ---
		elif t == TYPE_CRATE:
			if is_coward or is_minion:
				score -= 9999
			else:
				score += 500
				score -= dist * 5
				if any_reachable_hostile:
					score += BONUS_CRATE_IF_ENEMY_REACHABLE

		# --- Thief priorities ---
		elif t == TYPE_CHEST:
			score += 2000
			score -= dist * 5

		elif t == TYPE_ESCAPE:
			score += 5000
			score -= dist * 5

		# --- Hostile targets ---
		else:
			var is_aggressive: bool = (behavior == 4)
			var rough_damage: int = _estimate_raw_damage(unit, target)
			var unit_wpn: Resource = _weapon(unit)
			var target_threat: int = _estimate_unit_threat(target)
			var target_adjacent_friendlies: int = _count_units_within_distance(target_pos, live_friendlies, 1, unit)
			var target_nearby_friendlies: int = _count_units_within_distance(target_pos, live_friendlies, 2, unit)
			var target_nearby_hostiles: int = _count_units_within_distance(target_pos, live_hostiles, 2, target)

			score -= dist * HOSTILE_DISTANCE_PENALTY_PER_TILE
			score += target_threat * 3
			score += int((1.0 - _hp_ratio(target)) * HOSTILE_WOUNDED_BONUS_MAX)

			if _is_support_unit(target):
				score += BONUS_TARGET_SUPPORT

			if _is_leader(target):
				score += BONUS_TARGET_LEADER

			if is_aggressive:
				score += rough_damage * 3

			if intel >= 2:
				score -= _i(target, "current_hp")
				if _i(target, "current_hp") <= rough_damage:
					score += BONUS_FINISH_KILL

			if intel >= 3:
				if _b(target, "is_defending"):
					score -= 30
				score += int(battlefield.get_triangle_advantage(unit, target)) * 25

			if intel >= 4:
				var def_stat: int = _get_defense_stat_against(target, unit_wpn)

				if rough_damage <= 0:
					score -= def_stat * 5

					var target_poise = target.get_meta("current_poise", 99) if target.has_meta("current_poise") else 99
					var ai_poise_dmg = _i(unit, "strength") + (unit_wpn.get("might") if unit_wpn != null else 0)

					if unit_wpn != null and int(unit_wpn.get("weapon_type")) == int(WeaponData.WeaponType.AXE):
						ai_poise_dmg = int(float(ai_poise_dmg) * 1.5)

					if target_poise > 0 and ai_poise_dmg >= target_poise:
						score += 250
					else:
						score -= 160
				else:
					score += max(1, rough_damage) * 4

			if intel >= 5 and not is_aggressive:
				var tgt_wpn: Resource = _weapon(target)
				var tgt_damage: int = _get_attack_power(target)
				var my_def: int = _get_defense_stat_against(unit, tgt_wpn)
				var potential_damage_to_self: int = max(0, tgt_damage - my_def)

				var target_is_staggered = target.get_meta("is_staggered_this_combat", false)
				if target_is_staggered:
					potential_damage_to_self = 0
					score += 150

				score -= potential_damage_to_self * 5

				if _hp_ratio(unit) <= 0.40 and _i(target, "current_hp") > rough_damage:
					score -= PENALTY_LOW_HP_BAD_FIGHT

			# Squad coordination: how many friendlies can reach this target (focus-fire / join pressure).
			var attackers_count: int = 0
			if intel >= 3 and friendlies.size() > 0:
				for f_unit in friendlies:
					if f_unit == unit:
						continue
					if not is_instance_valid(f_unit) or _i(f_unit, "current_hp") <= 0:
						continue
					var fw: Resource = _weapon(f_unit)
					var f_min_r: int = _i(fw, "min_range", 1) if fw != null else 1
					var f_max_r: int = _i(fw, "max_range", 1) if fw != null else 1
					var f_dist: int = abs(int(battlefield.get_grid_pos(f_unit).x) - int(target_pos.x)) + abs(int(battlefield.get_grid_pos(f_unit).y) - int(target_pos.y))
					if f_dist >= f_min_r and f_dist <= f_max_r:
						attackers_count += 1
				if attackers_count <= 1:
					score += 50
				elif attackers_count <= 2:
					score += 20

			# Overprotected target: many enemy allies nearby; disfavor so we don't all pile on one brick.
			if target_adjacent_friendlies >= 3 or target_nearby_friendlies >= 4:
				score -= PENALTY_TARGET_OVERPROTECTED
				squad_reasons.append("target_overprotected")

			if is_instance_valid(_focus_target) and target == _focus_target:
				score += BONUS_FOCUS_FIRE
				if _i(target, "current_hp") <= rough_damage:
					score += BONUS_FOCUS_KILL
					squad_reasons.append("focus_kill")

			# Join pressure: target is injured or killable and others can reach; converge without overcommitting.
			if intel >= 3 and attackers_count >= 1:
				var target_low: bool = _hp_ratio(target) <= 0.5 or _i(target, "current_hp") <= rough_damage * 2
				if target_low:
					score += BONUS_JOIN_PRESSURE
					squad_reasons.append("join_pressure")

			# --- Flying dive logic (backline, isolated, terrain bypass; avoid suicidal dives) ---
			if is_flying:
				dive_result = _get_flier_dive_bonus(unit, target, live_hostiles)
				score += dive_result["bonus"]

				if can_reach_this_turn and (_is_leader(target) or _is_support_unit(target)):
					score += 60.0

			# --- Archetype bonuses ---
			match archetype:
				ARCHETYPE_ASSASSIN:
					score += int((1.0 - _hp_ratio(target)) * 120.0)

					if _is_support_unit(target):
						score += 90
					if _is_leader(target):
						score += 70

					score -= target_nearby_hostiles * 35

					var soft_stat: int = _get_defense_stat_against(target, unit_wpn)
					score -= soft_stat * 2

					if is_flying:
						score += target_adjacent_friendlies * 18

				ARCHETYPE_GUARDIAN:
					if is_instance_valid(guard_anchor):
						var dist_to_anchor: int = _grid_dist(target_pos, battlefield.get_grid_pos(guard_anchor))
						score += max(0, 6 - dist_to_anchor) * 30

						if _enemy_threatens_pos(target, battlefield.get_grid_pos(guard_anchor)):
							score += 120

				ARCHETYPE_PACK_HUNTER:
					score += target_adjacent_friendlies * 60
					score += target_nearby_friendlies * 18

					if can_reach_this_turn and target_adjacent_friendlies > 0:
						score += 80

				ARCHETYPE_OPPORTUNIST:
					if target.get_meta("is_staggered_this_combat", false):
						score += 180

					var target_poise2 = target.get_meta("current_poise", 99) if target.has_meta("current_poise") else 99
					if target_poise2 <= 8:
						score += 100

					if _i(target, "current_hp") <= rough_damage + 3:
						score += 120

		if score > highest_score:
			highest_score = score
			best_target = target
			best_type = t
			if is_flying and t == TYPE_HOSTILE:
				best_flier_dive_reasons = dive_result.get("reasons", PackedStringArray())
			best_squad_reasons = squad_reasons

	if best_target == null:
		return {}

	if DEBUG_AI_SCORING:
		var u_name: String = unit.get("unit_name") if unit.get("unit_name") != null else "Unit"
		if is_flying and best_type == TYPE_HOSTILE and best_flier_dive_reasons.size() > 0:
			print("[AI Flier] ", u_name, " dive: ", ", ".join(best_flier_dive_reasons))
		if best_squad_reasons.size() > 0:
			print("[AI Squad] ", u_name, " ", best_type, ": ", ", ".join(best_squad_reasons))
		if best_type == TYPE_ALLY_FOLLOW and any_reachable_hostile and not has_heal and not has_buff:
			print("[AI] ", u_name, " chose follow despite reachable hostile (minion/guardian/coward)")
		elif best_type == TYPE_HOSTILE and any_reachable_hostile:
			print("[AI] ", u_name, " chose hostile (reachable)")

	return {"node": best_target, "type": best_type, "score": highest_score}


func _get_best_plan_for_types(unit: Node2D, allowed_types: Array, exclude_plans: Array = []) -> Dictionary:
	"""Returns the best plan among allowed_types only, excluding any (node, type) in exclude_plans."""
	return get_best_plan_for(unit, exclude_plans, allowed_types)


func _get_backup_plan_for(unit: Node2D, failed_plan: Dictionary) -> Dictionary:
	"""Ordered backup: 1) hostile, 2) heal (if support), 3) buff (if support), 4) follow. Returns {} or {"plan": {...}, "tier": "hostile"|"heal"|"buff"|"follow"}."""
	var ex: Array = [failed_plan] if not failed_plan.is_empty() else []
	var wpn: Resource = _weapon(unit)
	var has_heal: bool = (wpn != null and bool(wpn.get("is_healing_staff")) == true)
	var has_buff: bool = (wpn != null and bool(wpn.get("is_buff_staff")) == true)

	var b: Dictionary = _get_best_plan_for_types(unit, [TYPE_HOSTILE], ex)
	if not b.is_empty():
		return {"plan": b, "tier": "hostile"}
	if has_heal:
		b = _get_best_plan_for_types(unit, [TYPE_ALLY_HEAL], ex)
		if not b.is_empty():
			return {"plan": b, "tier": "heal"}
	if has_buff:
		b = _get_best_plan_for_types(unit, [TYPE_ALLY_BUFF], ex)
		if not b.is_empty():
			return {"plan": b, "tier": "buff"}
	b = _get_best_plan_for_types(unit, [TYPE_ALLY_FOLLOW], ex)
	if not b.is_empty():
		return {"plan": b, "tier": "follow"}
	return {}


# -----------------------------------------------------------------------------
# Execution loop
# -----------------------------------------------------------------------------
func execute_ai_turn(my_container: Node) -> void:
	await battlefield.get_tree().create_timer(0.5).timeout

	var units_to_process = my_container.get_children()

	for unit_node in units_to_process:
		if not is_instance_valid(unit_node) or unit_node.get_parent() != my_container:
			continue

		var unit = unit_node as Node2D
		if not is_instance_valid(unit) or unit.is_queued_for_deletion():
			continue

		if _i(unit, "current_hp") <= 0:
			continue

		if unit.has_method("process_escort_turn"):
			continue

		var plan: Dictionary = get_best_plan_for(unit)
		if plan.is_empty():
			if unit.has_method("finish_turn"):
				unit.finish_turn()
			battlefield.rebuild_grid()
			await battlefield.get_tree().create_timer(0.2).timeout
			continue

		var target := plan.get("node") as Node2D
		var target_type: String = String(plan.get("type"))

		if target == null or not is_instance_valid(target):
			if unit.has_method("finish_turn"):
				unit.finish_turn()
			battlefield.rebuild_grid()
			await battlefield.get_tree().create_timer(0.2).timeout
			continue

		if not _is_valid_ai_target(target):
			if unit.has_method("finish_turn"):
				unit.finish_turn()
			battlefield.rebuild_grid()
			await battlefield.get_tree().create_timer(0.2).timeout
			continue

		var start_pos: Vector2i = battlefield.get_grid_pos(unit)
		var target_pos: Vector2i = battlefield.get_grid_pos(target)

		var action_range: Dictionary = _get_action_range_for(unit, target_type)
		var min_r: int = int(action_range["min"])
		var max_r: int = int(action_range["max"])
		var is_ranged: bool = max_r > 1
		var is_flying: bool = _is_flying_unit(unit)

		var my_beh: int = _i(unit, "ai_behavior")
		var intel: int = _i(unit, "ai_intelligence", 1)
		var archetype: String = _get_ai_archetype(unit)

		var enemies: Array[Node2D] = _get_live_units_in(_hostile_parents())
		var friendlies: Array[Node2D] = _get_live_units_in(_friendly_parents())
		var guard_anchor: Node2D = null
		if archetype == ARCHETYPE_GUARDIAN:
			guard_anchor = _get_guard_anchor(friendlies, unit)

		var intel_risk_scale: float = clamp(0.4 + (float(intel - 1) * 0.15), 0.4, 1.0)

		if my_beh == 3:
			intel_risk_scale *= 5.0

		var ignore_retaliation_from: Node2D = null
		var rough_damage: int = 0

		if target_type == TYPE_HOSTILE and target != null:
			rough_damage = _estimate_raw_damage(unit, target)

		if target_type == TYPE_HOSTILE and _i(target, "current_hp") > 0 and _i(target, "current_hp") <= rough_damage:
			ignore_retaliation_from = target

		var hp_ratio: float = _hp_ratio(unit)
		var danger_mult: float = 1.0
		if hp_ratio <= 0.35:
			danger_mult = 1.5

		battlefield.astar.set_point_solid(start_pos, false)
		battlefield.calculate_ranges(unit)
		var reachable: Array[Vector2i] = battlefield.reachable_tiles.duplicate()
		if not reachable.has(start_pos):
			reachable.append(start_pos)
		battlefield.clear_ranges()

		var valid_firing_spots: Array[Vector2i] = []
		for pos: Vector2i in reachable:
			if _can_act_from_tile(unit, pos, target, target_type):
				valid_firing_spots.append(pos)

		var move_path: Array = []
		var targeted_crate: Node2D = null
		var took_crate_shortcut: bool = false

		if valid_firing_spots.size() > 0:
			var best_spot: Vector2i = start_pos
			var best_spot_score: float = -999999.0

			for spot: Vector2i in valid_firing_spots:
				var dist_to_target: int = abs(spot.x - target_pos.x) + abs(spot.y - target_pos.y)
				var score_spot: float = 0.0
				var danger: int = _incoming_damage_at(spot, unit, enemies, ignore_retaliation_from)
				var nearest_enemy_dist: int = _distance_to_nearest_unit_from(spot, enemies)
				var nearby_friends: int = _count_units_within_distance(spot, friendlies, 2, unit)
				var danger_weight: float = DANGER_WEIGHT_RANGED if is_ranged else DANGER_WEIGHT_MELEE
				var is_aggressive = (my_beh == 4)

				if is_ranged:
					score_spot += dist_to_target * 10
					if dist_to_target == max_r:
						score_spot += 18
					elif dist_to_target < max_r:
						score_spot -= float(max_r - dist_to_target) * 8.0
				else:
					score_spot -= dist_to_target * 10
					if dist_to_target == 1:
						score_spot += 8

				if spot == start_pos:
					score_spot += 5

				if is_aggressive:
					danger_weight = 0.0
				else:
					score_spot -= float(danger) * danger_weight * danger_mult * intel_risk_scale
					if danger >= _i(unit, "current_hp"):
						score_spot -= DANGER_DEATH_PENALTY

				match target_type:
					TYPE_HOSTILE:
						if is_ranged:
							score_spot += min(nearest_enemy_dist, 6) * 4
							score_spot += nearby_friends * 3
						else:
							score_spot += nearby_friends * 8

					TYPE_ALLY_HEAL, TYPE_ALLY_BUFF:
						score_spot += nearby_friends * 10
						score_spot += min(nearest_enemy_dist, 5) * 5
						if is_ranged and dist_to_target == max_r:
							score_spot += 10

					TYPE_ALLY_FOLLOW:
						var desired_follow_dist: int = 1
						if my_beh == 3:
							desired_follow_dist = 4
						elif my_beh == 5:
							desired_follow_dist = 3

						score_spot -= abs(dist_to_target - desired_follow_dist) * 12
						score_spot += nearby_friends * 8
						score_spot += min(nearest_enemy_dist, 5) * 6
						# Prefer spots that screen a threatened leader/support/ranged backliner.
						if target != null and is_instance_valid(target):
							var danger_on_ally: int = _incoming_damage_at(target_pos, target, enemies)
							if danger_on_ally > 0 and (_is_leader(target) or _is_support_unit(target) or (_weapon(target) != null and _i(_weapon(target), "max_range", 1) > 1)):
								score_spot += 15

					TYPE_CHEST:
						score_spot += min(nearest_enemy_dist, 6) * 3

					TYPE_ESCAPE:
						score_spot += min(nearest_enemy_dist, 6) * 6

				match archetype:
					ARCHETYPE_ASSASSIN:
						score_spot += min(nearest_enemy_dist, 6) * 4
						score_spot += nearby_friends * 2

					ARCHETYPE_GUARDIAN:
						if is_instance_valid(guard_anchor):
							var dist_to_anchor: int = _grid_dist(spot, battlefield.get_grid_pos(guard_anchor))
							score_spot -= dist_to_anchor * 6
							score_spot += nearby_friends * 5

					ARCHETYPE_PACK_HUNTER:
						score_spot += nearby_friends * 10

					ARCHETYPE_OPPORTUNIST:
						if target != null and is_instance_valid(target):
							if target.get_meta("is_staggered_this_combat", false):
								score_spot += 40
							if _i(target, "current_hp") <= rough_damage + 3:
								score_spot += 35

				# --- Flier spot scoring: backline preference, terrain bypass; avoid suicidal landings (2+ threats) ---
				if is_flying and target_type == TYPE_HOSTILE and target != null and is_instance_valid(target):
					if _is_leader(target) or _is_support_unit(target):
						score_spot += 35
					var target_cover: int = _count_adjacent_solid_tiles(target_pos)
					score_spot += target_cover * 6
					# Discourage landing in the middle of multiple enemies (retaliation risk).
					var threats_at_spot: int = 0
					for e: Node2D in enemies:
						if e == ignore_retaliation_from or not is_instance_valid(e) or _i(e, "current_hp") <= 0:
							continue
						if _enemy_threatens_pos(e, spot):
							threats_at_spot += 1
					if not is_aggressive and threats_at_spot >= 2:
						score_spot -= 45

				if score_spot > best_spot_score:
					best_spot_score = score_spot
					best_spot = spot

			battlefield.astar.set_point_solid(best_spot, false)
			move_path = _get_ai_path(unit, start_pos, best_spot)
			battlefield.astar.set_point_solid(best_spot, true)
		else:
			battlefield.astar.set_point_solid(target_pos, false)
			var full_path: Array = _get_ai_path(unit, start_pos, target_pos)
			battlefield.astar.set_point_solid(target_pos, true)

			took_crate_shortcut = false
			var can_break_crates = (my_beh != 3 and my_beh != 5)

			if battlefield.destructibles_container != null and can_break_crates:
				for dnode: Node in battlefield.destructibles_container.get_children():
					var d := dnode as Node2D
					if is_instance_valid(d):
						if not _is_friendly_destructible(d):
							battlefield.astar.set_point_solid(battlefield.get_grid_pos(d), false)

				battlefield.astar.set_point_solid(target_pos, false)
				var crate_path: Array = _get_ai_path(unit, start_pos, target_pos)
				battlefield.astar.set_point_solid(target_pos, true)

				for dnode2: Node in battlefield.destructibles_container.get_children():
					var d2 := dnode2 as Node2D
					if is_instance_valid(d2):
						if not _is_friendly_destructible(d2):
							battlefield.astar.set_point_solid(battlefield.get_grid_pos(d2), true)

				if not crate_path.is_empty() and (full_path.is_empty() or full_path.size() > crate_path.size() + 3):
					for i: int in range(crate_path.size()):
						var step_pos: Vector2i = crate_path[i] as Vector2i
						var check_crate := _get_crate_at(step_pos)

						if check_crate != null:
							targeted_crate = check_crate
							took_crate_shortcut = true

							var safe_target_index = i - 1

							if safe_target_index <= 0:
								move_path = [start_pos]
							else:
								var max_reachable_index = min(safe_target_index, _i(unit, "move_range"))
								move_path = crate_path.slice(0, max_reachable_index + 1)

							break

			if not took_crate_shortcut:
				if full_path.size() > 1:
					var max_steps: int = min(full_path.size() - 1, _i(unit, "move_range"))
					var best_progress_score: float = -999999.0
					var best_progress_index: int = 0
					var is_aggressive_progress: bool = (my_beh == 4)
					var progress_danger_weight: float = DANGER_WEIGHT_RANGED if is_ranged else DANGER_WEIGHT_MELEE

					for i: int in range(1, max_steps + 1):
						var step_pos: Vector2i = full_path[i] as Vector2i
						var step_dist_to_target: int = _grid_dist(step_pos, target_pos)
						var step_danger: int = _incoming_damage_at(step_pos, unit, enemies, ignore_retaliation_from)
						var step_nearest_enemy: int = _distance_to_nearest_unit_from(step_pos, enemies)
						var step_nearby_friends: int = _count_units_within_distance(step_pos, friendlies, 2, unit)
						var progress_score: float = 0.0

						progress_score -= step_dist_to_target * 8.0

						if not is_aggressive_progress:
							progress_score -= float(step_danger) * progress_danger_weight * danger_mult * intel_risk_scale
							if step_danger >= _i(unit, "current_hp"):
								progress_score -= DANGER_DEATH_PENALTY

						match target_type:
							TYPE_HOSTILE:
								if is_ranged:
									progress_score += min(step_nearest_enemy, 6) * 3
								else:
									progress_score += step_nearby_friends * 6

							TYPE_ALLY_HEAL, TYPE_ALLY_BUFF, TYPE_ALLY_FOLLOW:
								progress_score += step_nearby_friends * 8
								progress_score += min(step_nearest_enemy, 5) * 4

							TYPE_CHEST:
								progress_score += min(step_nearest_enemy, 6) * 3

							TYPE_ESCAPE:
								progress_score -= step_dist_to_target * 4.0
								progress_score += min(step_nearest_enemy, 6) * 6

						match archetype:
							ARCHETYPE_ASSASSIN:
								progress_score += min(step_nearest_enemy, 6) * 3

							ARCHETYPE_GUARDIAN:
								if is_instance_valid(guard_anchor):
									var step_to_anchor: int = _grid_dist(step_pos, battlefield.get_grid_pos(guard_anchor))
									progress_score -= step_to_anchor * 5.0
									progress_score += step_nearby_friends * 4.0

							ARCHETYPE_PACK_HUNTER:
								progress_score += step_nearby_friends * 7.0

							ARCHETYPE_OPPORTUNIST:
								if target != null and is_instance_valid(target):
									if target.get_meta("is_staggered_this_combat", false):
										progress_score += 25.0
									if _i(target, "current_hp") <= rough_damage + 3:
										progress_score += 20.0

						if is_flying and target_type == TYPE_HOSTILE and target != null and is_instance_valid(target):
							if _is_leader(target) or _is_support_unit(target):
								progress_score += 24.0
							progress_score += _count_adjacent_solid_tiles(target_pos) * 5.0
							var step_threats: int = 0
							for e2: Node2D in enemies:
								if e2 == ignore_retaliation_from or not is_instance_valid(e2) or _i(e2, "current_hp") <= 0:
									continue
								if _enemy_threatens_pos(e2, step_pos):
									step_threats += 1
							if not is_aggressive_progress and step_threats >= 2:
								progress_score -= 35.0

						if progress_score > best_progress_score:
							best_progress_score = progress_score
							best_progress_index = i

					if best_progress_index > 0:
						move_path = full_path.slice(0, best_progress_index + 1)

		battlefield.astar.set_point_solid(start_pos, true)

		# Backup plan when primary yields no action and no meaningful movement path (ordered: hostile -> heal -> buff -> follow).
		if valid_firing_spots.is_empty() and (move_path.is_empty() or move_path.size() <= 1) and not took_crate_shortcut:
			var backup_result: Dictionary = _get_backup_plan_for(unit, plan)
			if backup_result.is_empty():
				if DEBUG_AI_SCORING:
					var u_name: String = unit.get("unit_name") if unit.get("unit_name") != null else "Unit"
					print("[AI Backup] ", u_name, " primary failed -> hold")
			else:
				var backup_plan: Dictionary = backup_result.get("plan", {})
				var backup_tier: String = String(backup_result.get("tier", ""))
				if DEBUG_AI_SCORING:
					var u_name: String = unit.get("unit_name") if unit.get("unit_name") != null else "Unit"
					print("[AI Backup] ", u_name, " primary failed -> backup ", backup_tier)
				var backup_target: Node2D = backup_plan.get("node") as Node2D
				if backup_target != null and is_instance_valid(backup_target) and _is_valid_ai_target(backup_target):
					plan = backup_plan
					target = backup_target
					target_type = String(backup_plan.get("type"))
					target_pos = battlefield.get_grid_pos(target)
					action_range = _get_action_range_for(unit, target_type)
					min_r = int(action_range["min"])
					max_r = int(action_range["max"])
					is_ranged = (max_r > 1)
					ignore_retaliation_from = null
					rough_damage = 0
					if target_type == TYPE_HOSTILE and target != null:
						rough_damage = _estimate_raw_damage(unit, target)
					if target_type == TYPE_HOSTILE and _i(target, "current_hp") > 0 and _i(target, "current_hp") <= rough_damage:
						ignore_retaliation_from = target
					valid_firing_spots = []
					for pos in reachable:
						if _can_act_from_tile(unit, pos, target, target_type):
							valid_firing_spots.append(pos)
					move_path = []
					targeted_crate = null
					took_crate_shortcut = false
					battlefield.astar.set_point_solid(start_pos, false)
					if valid_firing_spots.size() > 0:
						var best_spot: Vector2i = start_pos
						var best_spot_score: float = -999999.0
						for spot: Vector2i in valid_firing_spots:
							var dist_to_target: int = abs(spot.x - target_pos.x) + abs(spot.y - target_pos.y)
							var score_spot: float = 0.0
							var danger: int = _incoming_damage_at(spot, unit, enemies, ignore_retaliation_from)
							var nearest_enemy_dist: int = _distance_to_nearest_unit_from(spot, enemies)
							var nearby_friends: int = _count_units_within_distance(spot, friendlies, 2, unit)
							var danger_weight: float = DANGER_WEIGHT_RANGED if is_ranged else DANGER_WEIGHT_MELEE
							var is_aggressive = (my_beh == 4)
							if is_ranged:
								score_spot += dist_to_target * 10
								if dist_to_target == max_r:
									score_spot += 18
								elif dist_to_target < max_r:
									score_spot -= float(max_r - dist_to_target) * 8.0
							else:
								score_spot -= dist_to_target * 10
								if dist_to_target == 1:
									score_spot += 8
							if spot == start_pos:
								score_spot += 5
							if is_aggressive:
								danger_weight = 0.0
							else:
								score_spot -= float(danger) * danger_weight * danger_mult * intel_risk_scale
								if danger >= _i(unit, "current_hp"):
									score_spot -= DANGER_DEATH_PENALTY
							match target_type:
								TYPE_HOSTILE:
									if is_ranged:
										score_spot += min(nearest_enemy_dist, 6) * 4
										score_spot += nearby_friends * 3
									else:
										score_spot += nearby_friends * 8
								TYPE_ALLY_HEAL, TYPE_ALLY_BUFF:
									score_spot += nearby_friends * 10
									score_spot += min(nearest_enemy_dist, 5) * 5
									if is_ranged and dist_to_target == max_r:
										score_spot += 10
								TYPE_ALLY_FOLLOW:
									var desired_follow_dist: int = 1
									if my_beh == 3:
										desired_follow_dist = 4
									elif my_beh == 5:
										desired_follow_dist = 3
									score_spot -= abs(dist_to_target - desired_follow_dist) * 12
									score_spot += nearby_friends * 8
									score_spot += min(nearest_enemy_dist, 5) * 6
									if target != null and is_instance_valid(target):
										var danger_on_ally: int = _incoming_damage_at(target_pos, target, enemies)
										if danger_on_ally > 0 and (_is_leader(target) or _is_support_unit(target) or (_weapon(target) != null and _i(_weapon(target), "max_range", 1) > 1)):
											score_spot += 15
								TYPE_CHEST:
									score_spot += min(nearest_enemy_dist, 6) * 3
								TYPE_ESCAPE:
									score_spot += min(nearest_enemy_dist, 6) * 6
							match archetype:
								ARCHETYPE_ASSASSIN:
									score_spot += min(nearest_enemy_dist, 6) * 4
									score_spot += nearby_friends * 2
								ARCHETYPE_GUARDIAN:
									if is_instance_valid(guard_anchor):
										var dist_to_anchor: int = _grid_dist(spot, battlefield.get_grid_pos(guard_anchor))
										score_spot -= dist_to_anchor * 6
										score_spot += nearby_friends * 5
								ARCHETYPE_PACK_HUNTER:
									score_spot += nearby_friends * 10
								ARCHETYPE_OPPORTUNIST:
									if target != null and is_instance_valid(target):
										if target.get_meta("is_staggered_this_combat", false):
											score_spot += 40
										if _i(target, "current_hp") <= rough_damage + 3:
											score_spot += 35
							if is_flying and target_type == TYPE_HOSTILE and target != null and is_instance_valid(target):
								if _is_leader(target) or _is_support_unit(target):
									score_spot += 35
								var target_cover: int = _count_adjacent_solid_tiles(target_pos)
								score_spot += target_cover * 6
								var threats_at_spot: int = 0
								for e: Node2D in enemies:
									if e == ignore_retaliation_from or not is_instance_valid(e) or _i(e, "current_hp") <= 0:
										continue
									if _enemy_threatens_pos(e, spot):
										threats_at_spot += 1
								if not (my_beh == 4) and threats_at_spot >= 2:
									score_spot -= 45
							if score_spot > best_spot_score:
								best_spot_score = score_spot
								best_spot = spot
						battlefield.astar.set_point_solid(best_spot, false)
						move_path = _get_ai_path(unit, start_pos, best_spot)
						battlefield.astar.set_point_solid(best_spot, true)
					else:
						battlefield.astar.set_point_solid(target_pos, false)
						var full_path: Array = _get_ai_path(unit, start_pos, target_pos)
						battlefield.astar.set_point_solid(target_pos, true)
						var can_break_crates: bool = (my_beh != 3 and my_beh != 5)
						if battlefield.destructibles_container != null and can_break_crates:
							for dnode: Node in battlefield.destructibles_container.get_children():
								var d := dnode as Node2D
								if is_instance_valid(d) and not _is_friendly_destructible(d):
									battlefield.astar.set_point_solid(battlefield.get_grid_pos(d), false)
							battlefield.astar.set_point_solid(target_pos, false)
							var crate_path: Array = _get_ai_path(unit, start_pos, target_pos)
							battlefield.astar.set_point_solid(target_pos, true)
							for dnode2: Node in battlefield.destructibles_container.get_children():
								var d2 := dnode2 as Node2D
								if is_instance_valid(d2) and not _is_friendly_destructible(d2):
									battlefield.astar.set_point_solid(battlefield.get_grid_pos(d2), true)
							if not crate_path.is_empty() and (full_path.is_empty() or full_path.size() > crate_path.size() + 3):
								for i: int in range(crate_path.size()):
									var step_pos: Vector2i = crate_path[i] as Vector2i
									var check_crate := _get_crate_at(step_pos)
									if check_crate != null:
										targeted_crate = check_crate
										took_crate_shortcut = true
										var safe_target_index: int = i - 1
										if safe_target_index <= 0:
											move_path = [start_pos]
										else:
											var max_reachable_index: int = min(safe_target_index, _i(unit, "move_range"))
											move_path = crate_path.slice(0, max_reachable_index + 1)
										break
						if not took_crate_shortcut and full_path.size() > 1:
							var max_steps: int = min(full_path.size() - 1, _i(unit, "move_range"))
							var best_progress_score: float = -999999.0
							var best_progress_index: int = 0
							var is_aggressive_progress: bool = (my_beh == 4)
							var progress_danger_weight: float = DANGER_WEIGHT_RANGED if is_ranged else DANGER_WEIGHT_MELEE
							for i: int in range(1, max_steps + 1):
								var step_pos: Vector2i = full_path[i] as Vector2i
								var step_dist_to_target: int = _grid_dist(step_pos, target_pos)
								var step_danger: int = _incoming_damage_at(step_pos, unit, enemies, ignore_retaliation_from)
								var step_nearest_enemy: int = _distance_to_nearest_unit_from(step_pos, enemies)
								var step_nearby_friends: int = _count_units_within_distance(step_pos, friendlies, 2, unit)
								var progress_score: float = 0.0
								progress_score -= step_dist_to_target * 8.0
								if not is_aggressive_progress:
									progress_score -= float(step_danger) * progress_danger_weight * danger_mult * intel_risk_scale
									if step_danger >= _i(unit, "current_hp"):
										progress_score -= DANGER_DEATH_PENALTY
								match target_type:
									TYPE_HOSTILE:
										if is_ranged:
											progress_score += min(step_nearest_enemy, 6) * 3
										else:
											progress_score += step_nearby_friends * 6
									TYPE_ALLY_HEAL, TYPE_ALLY_BUFF, TYPE_ALLY_FOLLOW:
										progress_score += step_nearby_friends * 8
										progress_score += min(step_nearest_enemy, 5) * 4
									TYPE_CHEST:
										progress_score += min(step_nearest_enemy, 6) * 3
									TYPE_ESCAPE:
										progress_score -= step_dist_to_target * 4.0
										progress_score += min(step_nearest_enemy, 6) * 6
								match archetype:
									ARCHETYPE_ASSASSIN:
										progress_score += min(step_nearest_enemy, 6) * 3
									ARCHETYPE_GUARDIAN:
										if is_instance_valid(guard_anchor):
											var step_to_anchor: int = _grid_dist(step_pos, battlefield.get_grid_pos(guard_anchor))
											progress_score -= step_to_anchor * 5.0
											progress_score += step_nearby_friends * 4.0
									ARCHETYPE_PACK_HUNTER:
										progress_score += step_nearby_friends * 7.0
									ARCHETYPE_OPPORTUNIST:
										if target != null and is_instance_valid(target):
											if target.get_meta("is_staggered_this_combat", false):
												progress_score += 25.0
											if _i(target, "current_hp") <= rough_damage + 3:
												progress_score += 20.0
								if is_flying and target_type == TYPE_HOSTILE and target != null and is_instance_valid(target):
									if _is_leader(target) or _is_support_unit(target):
										progress_score += 24.0
									progress_score += _count_adjacent_solid_tiles(target_pos) * 5.0
									var step_threats: int = 0
									for e2: Node2D in enemies:
										if e2 == ignore_retaliation_from or not is_instance_valid(e2) or _i(e2, "current_hp") <= 0:
											continue
										if _enemy_threatens_pos(e2, step_pos):
											step_threats += 1
									if not is_aggressive_progress and step_threats >= 2:
										progress_score -= 35.0
								if progress_score > best_progress_score:
									best_progress_score = progress_score
									best_progress_index = i
							if best_progress_index > 0:
								move_path = full_path.slice(0, best_progress_index + 1)
					battlefield.astar.set_point_solid(start_pos, true)
					# Follow backup only accepted if it yields a meaningful move path.
					if backup_tier == "follow" and (move_path.is_empty() or move_path.size() <= 1):
						if DEBUG_AI_SCORING:
							var u_name_f: String = unit.get("unit_name") if unit.get("unit_name") != null else "Unit"
							print("[AI Backup] ", u_name_f, " follow backup yielded no path -> hold")
						move_path = []
						valid_firing_spots = []

		# Hold position when both primary and backup yield no action and no meaningful path.
		if valid_firing_spots.is_empty() and (move_path.is_empty() or move_path.size() <= 1):
			if unit.has_method("finish_turn"):
				unit.finish_turn()
			battlefield.rebuild_grid()
			await battlefield.get_tree().create_timer(0.2).timeout
			continue

		# Pre-move camera focus
		if battlefield.camera_follows_enemies and battlefield.main_camera:
			var cam: Camera2D = battlefield.main_camera
			var unit_focus: Vector2 = unit.global_position + Vector2(32, 32)
			var vp: Vector2 = battlefield.get_viewport_rect().size
			var target_cam_pos: Vector2 = unit_focus + Vector2(0, AI_CAMERA_OFFSET_Y)

			if cam.anchor_mode == Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT:
				var half_vp_world: Vector2 = (vp * 0.5) / cam.zoom
				target_cam_pos -= half_vp_world

			var map_limit_x: float = float(battlefield.GRID_SIZE.x * battlefield.CELL_SIZE.x)
			var map_limit_y: float = float(battlefield.GRID_SIZE.y * battlefield.CELL_SIZE.y)

			target_cam_pos.x = clamp(
				target_cam_pos.x,
				AI_CAMERA_LEFT_MARGIN,
				map_limit_x + AI_CAMERA_RIGHT_MARGIN
			)
			target_cam_pos.y = clamp(
				target_cam_pos.y,
				AI_CAMERA_TOP_MARGIN,
				map_limit_y + AI_CAMERA_BOTTOM_MARGIN
			)

			var camera_tween: Tween = battlefield.create_tween()
			camera_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			var cam_step: PropertyTweener = camera_tween.tween_property(cam, "global_position", target_cam_pos, AI_CAMERA_TWEEN_TIME_PREMOVE)
			cam_step.set_trans(Tween.TRANS_SINE)
			cam_step.set_ease(Tween.EASE_IN_OUT)
			await camera_tween.finished

			if not is_instance_valid(battlefield):
				return

		var performed_attack_action: bool = false

		# Move
		if move_path.size() > 1:
			await unit.move_along_path(move_path)
			unit.move_points_used_this_turn = battlefield.get_path_move_cost(move_path, unit)

			if not is_instance_valid(target) and targeted_crate == null:
				if is_instance_valid(unit) and unit.has_method("finish_turn"):
					unit.finish_turn()
				continue

			if battlefield == null:
				return

			if faction == "ally":
				battlefield.update_fog_of_war()

			battlefield.rebuild_grid()

		# Post-move camera focus for the actual action
		if targeted_crate != null:
			await _focus_camera_on_ai_action(unit, targeted_crate, AI_CAMERA_TWEEN_TIME_POSTMOVE)
		elif target != null and is_instance_valid(target):
			await _focus_camera_on_ai_action(unit, target, AI_CAMERA_TWEEN_TIME_POSTMOVE)

		# Act based on plan type
		if targeted_crate != null:
			if battlefield.is_in_range(unit, targeted_crate):
				unit.look_at_pos(battlefield.get_grid_pos(targeted_crate))
				await battlefield.execute_combat(unit, targeted_crate)
				performed_attack_action = true
		else:
			if target_type == TYPE_ESCAPE and battlefield.get_distance(unit, target) <= 1:
				battlefield.add_combat_log(unit.unit_name + " escaped the map with the loot!", "tomato")

				var tween = create_tween()
				tween.tween_property(unit, "modulate:a", 0.0, 0.3)
				await tween.finished

				unit.queue_free()
				continue

			if battlefield.is_in_range(unit, target) or target_type == TYPE_CHEST:
				match target_type:
					TYPE_CHEST:
						if battlefield.get_distance(unit, target) <= 1:
							unit.look_at_pos(battlefield.get_grid_pos(target))
							if battlefield.has_method("_on_chest_opened"):
								battlefield._on_chest_opened(target, unit)

					TYPE_HOSTILE:
						unit.look_at_pos(battlefield.get_grid_pos(target))
						await battlefield.execute_combat(unit, target)
						_focus_target = target
						performed_attack_action = true

					TYPE_CRATE:
						unit.look_at_pos(battlefield.get_grid_pos(target))
						await battlefield.execute_combat(unit, target)
						performed_attack_action = true

					TYPE_ALLY_HEAL:
						if _i(target, "current_hp") < _i(target, "max_hp"):
							unit.look_at_pos(battlefield.get_grid_pos(target))
							await battlefield.execute_combat(unit, target)
							performed_attack_action = true

					TYPE_ALLY_BUFF:
						unit.look_at_pos(battlefield.get_grid_pos(target))
						await battlefield.execute_combat(unit, target)
						performed_attack_action = true

					TYPE_ALLY_FOLLOW:
						pass

		if not is_instance_valid(battlefield):
			return

		if is_instance_valid(unit) and _i(unit, "current_hp") > 0:
			if performed_attack_action and battlefield.unit_supports_canto(unit):
				var mpu_v: Variant = unit.get("move_points_used_this_turn")
				var mpu_f: float = 0.0 if mpu_v == null else float(mpu_v)
				var rem_c: float = float(_i(unit, "move_range")) - mpu_f
				if rem_c > 0.001:
					await _ai_try_canto_move(unit, rem_c)
			if unit.has_method("finish_turn"):
				unit.finish_turn()

		battlefield.rebuild_grid()
		await battlefield.get_tree().create_timer(0.2).timeout

	await battlefield.get_tree().create_timer(0.35).timeout
	turn_finished.emit()
	
func _focus_camera_on_ai_unit(unit: Node2D, duration: float = 0.45) -> void:
	if battlefield == null or unit == null or not is_instance_valid(unit):
		return
	if not battlefield.camera_follows_enemies or battlefield.main_camera == null:
		return

	var cam: Camera2D = battlefield.main_camera
	var vp: Vector2 = battlefield.get_viewport_rect().size
	var unit_focus: Vector2 = unit.global_position + Vector2(32, 32)

	# Push camera downward so the unit appears higher on screen.
	var target_cam_pos: Vector2 = unit_focus + Vector2(0, AI_CAMERA_OFFSET_Y)

	if cam.anchor_mode == Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT:
		var half_vp_world: Vector2 = (vp * 0.5) / cam.zoom
		target_cam_pos -= half_vp_world

	# Pre-clamp here so the tween goes directly to a legal position,
	# instead of being corrected afterward by Battlefield.
	var map_limit_x: float = float(battlefield.GRID_SIZE.x * battlefield.CELL_SIZE.x)
	var map_limit_y: float = float(battlefield.GRID_SIZE.y * battlefield.CELL_SIZE.y)

	target_cam_pos.x = clamp(
		target_cam_pos.x,
		AI_CAMERA_LEFT_MARGIN,
		map_limit_x + AI_CAMERA_RIGHT_MARGIN
	)
	target_cam_pos.y = clamp(
		target_cam_pos.y,
		AI_CAMERA_TOP_MARGIN,
		map_limit_y + AI_CAMERA_BOTTOM_MARGIN
	)

	var camera_tween: Tween = battlefield.create_tween()
	camera_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var cam_step: PropertyTweener = camera_tween.tween_property(
		cam,
		"global_position",
		target_cam_pos,
		duration
	)
	cam_step.set_trans(Tween.TRANS_SINE)
	cam_step.set_ease(Tween.EASE_IN_OUT)

	await camera_tween.finished

func _focus_camera_on_ai_action(attacker: Node2D, target: Node2D, duration: float = 0.42) -> void:
	if battlefield == null or attacker == null or target == null:
		return
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return
	if not battlefield.camera_follows_enemies or battlefield.main_camera == null:
		return

	var cam: Camera2D = battlefield.main_camera
	var vp: Vector2 = battlefield.get_viewport_rect().size

	var attacker_focus: Vector2 = attacker.global_position + Vector2(32, 32)
	var target_focus: Vector2 = target.global_position + Vector2(32, 32)

	# Midpoint between both units
	var focus_point: Vector2 = (attacker_focus + target_focus) * 0.5

	# Push the framing a bit downward so it looks centered above bottom UI
	var target_cam_pos: Vector2 = focus_point + Vector2(0, AI_CAMERA_OFFSET_Y)

	if cam.anchor_mode == Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT:
		var half_vp_world: Vector2 = (vp * 0.5) / cam.zoom
		target_cam_pos -= half_vp_world

	var map_limit_x: float = float(battlefield.GRID_SIZE.x * battlefield.CELL_SIZE.x)
	var map_limit_y: float = float(battlefield.GRID_SIZE.y * battlefield.CELL_SIZE.y)

	target_cam_pos.x = clamp(
		target_cam_pos.x,
		AI_CAMERA_LEFT_MARGIN,
		map_limit_x + AI_CAMERA_RIGHT_MARGIN
	)
	target_cam_pos.y = clamp(
		target_cam_pos.y,
		AI_CAMERA_TOP_MARGIN,
		map_limit_y + AI_CAMERA_BOTTOM_MARGIN
	)

	var camera_tween: Tween = battlefield.create_tween()
	camera_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	var cam_step: PropertyTweener = camera_tween.tween_property(
		cam,
		"global_position",
		target_cam_pos,
		duration
	)
	cam_step.set_trans(Tween.TRANS_SINE)
	cam_step.set_ease(Tween.EASE_IN_OUT)

	await camera_tween.finished

func _is_valid_ai_target(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return false

	if target.has_method("is_targetable") and not target.is_targetable():
		return false

	return true


## True if unit uses flying movement (move_type == 2). Used to gate flier-specific scoring and spot selection.
func _is_flying_unit(unit: Node2D) -> bool:
	if unit == null:
		return false
	return _i(unit, "move_type", -1) == 2


func _get_ai_path(unit: Node2D, start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	if battlefield == null or unit == null:
		return []
	return battlefield.get_unit_path(unit, start, target)


func _count_adjacent_solid_tiles(pos: Vector2i) -> int:
	if battlefield == null:
		return 0

	var count: int = 0
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

	for dir in dirs:
		var check: Vector2i = pos + dir

		if check.x < 0 or check.y < 0 or check.x >= battlefield.GRID_SIZE.x or check.y >= battlefield.GRID_SIZE.y:
			count += 1
			continue

		if battlefield.astar.is_point_solid(check):
			count += 1

	return count


## Returns { "bonus": float, "reasons": PackedStringArray } for flier target scoring. Prefers backline/isolated/terrain-bypass; penalizes suicidal dives.
func _get_flier_dive_bonus(unit: Node2D, target: Node2D, live_hostiles: Array[Node2D]) -> Dictionary:
	var empty := {"bonus": 0.0, "reasons": PackedStringArray()}
	if unit == null or target == null:
		return empty
	if not _is_flying_unit(unit):
		return empty

	var bonus: float = 0.0
	var reasons: PackedStringArray = []
	var target_pos: Vector2i = battlefield.get_grid_pos(target)

	# High-value targets (backline / support / leader)
	if _is_leader(target):
		bonus += 120.0
		reasons.append("leader")
	if _is_support_unit(target):
		bonus += 95.0
		reasons.append("support")

	# Ranged units often sit in backline; fliers can reach them despite terrain.
	var tw: Resource = _weapon(target)
	if tw != null and _i(tw, "max_range", 1) > 1:
		bonus += 45.0
		reasons.append("ranged")

	# live_hostiles = enemy units (from AI perspective); count allies adjacent to target (bodyguards).
	var adjacent_bodyguards: int = _count_units_within_distance(target_pos, live_hostiles, 1, target)
	# Prefer isolated or lightly protected targets; avoid diving into stacked formations (suicidal).
	if adjacent_bodyguards <= 1:
		bonus += 55.0
		reasons.append("isolated")
	elif adjacent_bodyguards >= 3:
		bonus -= 60.0
		reasons.append("stacked")

	# Terrain-ignoring approach: target behind walls/solids is more valuable to a flier.
	var adjacent_solids: int = _count_adjacent_solid_tiles(target_pos)
	if adjacent_solids >= 2:
		bonus += float(adjacent_solids) * 14.0
		reasons.append("terrain")
	else:
		bonus += float(adjacent_solids) * 10.0

	# Softer targets (low def+res) are better dive targets.
	var softness: int = _i(target, "defense") + _i(target, "resistance")
	if softness <= 14:
		bonus += 35.0
	elif softness <= 20:
		bonus += 18.0

	if _hp_ratio(target) <= 0.50:
		bonus += 25.0

	return {"bonus": bonus, "reasons": reasons}
