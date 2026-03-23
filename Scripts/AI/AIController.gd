extends Node
class_name AIController

const TYPE_HOSTILE: String = "hostile"
const TYPE_CRATE: String = "crate"
const TYPE_ALLY_HEAL: String = "ally_heal"
const TYPE_ALLY_BUFF: String = "ally_buff"
const TYPE_ALLY_FOLLOW: String = "ally_follow"

const AI_FIRE_TILE_STEP_PENALTY_INT: int = 18

@export var faction: String = "enemy" # "enemy" or "ally"
var _focus_target: Node2D = null

func begin_phase() -> void:
	_focus_target = null


# -------------------------
# Public entry
# -------------------------

func take_turn(unit: Node2D, battlefield: Node2D) -> void:
	if unit == null or not is_instance_valid(unit) or int(unit.current_hp) <= 0:
		return

	var plan: Dictionary = _get_best_plan_for(unit, battlefield)
	if plan.is_empty():
		await battlefield.get_tree().create_timer(0.25).timeout
		unit.finish_turn()
		return

	var target: Node2D = plan.get("node") as Node2D
	var target_type: String = String(plan.get("type"))

	if target == null or not is_instance_valid(target) or int(target.current_hp) <= 0:
		await battlefield.get_tree().create_timer(0.25).timeout
		unit.finish_turn()
		return

	var wpn: Variant = unit.equipped_weapon
	var min_r: int = int(wpn.min_range) if wpn != null else 1
	var max_r: int = int(wpn.max_range) if wpn != null else 1
	var is_ranged: bool = max_r > 1

	# 1) If already in range, act immediately (based on type)
	if battlefield.is_in_range(unit, target):
		await _execute_plan_action(unit, battlefield, target, target_type)
		unit.finish_turn()
		return

	# 2) Otherwise move to a good in-range tile if possible
	var start_pos: Vector2i = battlefield.get_grid_pos(unit)
	var target_pos: Vector2i = battlefield.get_grid_pos(target)

	var move_steps: Array = _compute_best_move_steps(unit, battlefield, start_pos, target_pos, min_r, max_r, is_ranged)

	if move_steps.size() > 0:
		await unit.move_along_path(move_steps)
		if battlefield == null:
			return
		battlefield.rebuild_grid()

	# 3) Try acting again after moving
	if battlefield.is_in_range(unit, target):
		await _execute_plan_action(unit, battlefield, target, target_type)
	else:
		await battlefield.get_tree().create_timer(0.25).timeout

	unit.finish_turn()


# -------------------------
# Plan selection (target + intent)
# -------------------------

func _get_best_plan_for(unit: Node2D, battlefield: Node2D) -> Dictionary:
	var best_target: Node2D = null
	var best_type: String = ""
	var best_score: int = -999999

	var behavior_v: Variant = unit.get("ai_behavior")
	var behavior: int = int(behavior_v) if behavior_v != null else 0

	var intel_v: Variant = unit.get("ai_intelligence")
	var intel: int = int(intel_v) if intel_v != null else 1

	var wpn: Variant = unit.equipped_weapon
	var has_heal: bool = (wpn != null and bool(wpn.get("is_healing_staff")) == true)
	var has_buff: bool = (wpn != null and bool(wpn.get("is_buff_staff")) == true)

	var potential: Array = []

	if has_heal or has_buff:
		# Friends only
		var friends: Array = _get_friendly_units(battlefield)
		for a in friends:
			var ally: Node2D = a as Node2D
			if ally == null or not is_instance_valid(ally) or ally == unit:
				continue
			if int(ally.current_hp) <= 0:
				continue

			if has_heal and int(ally.current_hp) < int(ally.max_hp):
				potential.append({"node": ally, "type": TYPE_ALLY_HEAL})
			elif has_buff:
				potential.append({"node": ally, "type": TYPE_ALLY_BUFF})

		if potential.is_empty():
			# Nothing to do: follow a valuable ally
			for a2 in friends:
				var ally2: Node2D = a2 as Node2D
				if ally2 == null or not is_instance_valid(ally2) or ally2 == unit:
					continue
				if int(ally2.current_hp) <= 0:
					continue
				potential.append({"node": ally2, "type": TYPE_ALLY_FOLLOW})
	else:
		# Hostiles
		var hostiles: Array = _get_hostile_units(battlefield)
		for h in hostiles:
			var hostile: Node2D = h as Node2D
			if hostile == null or not is_instance_valid(hostile):
				continue
			if int(hostile.current_hp) <= 0:
				continue
			potential.append({"node": hostile, "type": TYPE_HOSTILE})

		# Optional crates/objectives
		if behavior == 1 and battlefield.destructibles_container != null:
			for cnode: Node in battlefield.destructibles_container.get_children():
				var crate: Node2D = cnode as Node2D
				if crate != null and is_instance_valid(crate) and int(crate.current_hp) > 0:
					potential.append({"node": crate, "type": TYPE_CRATE})

	if potential.is_empty():
		return {}

	# Score
	for info in potential:
		var target: Node2D = info.get("node") as Node2D
		var t: String = String(info.get("type"))
		if target == null or not is_instance_valid(target):
			continue

		var dist: int = int(battlefield.get_distance(unit, target))
		var score: int = 0

		if t == TYPE_ALLY_HEAL:
			score += (int(target.max_hp) - int(target.current_hp)) * 10
			score -= dist * 5
		elif t == TYPE_ALLY_BUFF:
			score += (int(target.strength) + int(target.magic) + int(target.defense)) * 2
			score -= dist * 5
		elif t == TYPE_ALLY_FOLLOW:
			score -= dist * 5
			if intel >= 2:
				score += int(target.max_hp) * 2
			if intel >= 3:
				score += (int(target.defense) + int(target.strength)) * 3
		elif t == TYPE_CRATE:
			score += 250
			score -= dist * 5
		else:
			# Hostile
			var rough_damage: int = int(unit.strength)
			var wpn2: Variant = unit.equipped_weapon
			if wpn2 != null:
				rough_damage += int(wpn2.might)

			score -= dist * 5

			if intel >= 2:
				score -= int(target.current_hp)
				if int(target.current_hp) <= rough_damage:
					score += 120

			if intel >= 3 and battlefield.has_method("get_triangle_advantage"):
				score += int(battlefield.get_triangle_advantage(unit, target)) * 25

			# Focus fire
			if is_instance_valid(_focus_target) and target == _focus_target:
				score += 35

		if score > best_score:
			best_score = score
			best_target = target
			best_type = t

	if best_target == null:
		return {}

	return {"node": best_target, "type": best_type, "score": best_score}


func _fire_path_penalty_int(bf: Node2D, unit: Node2D, from_cell: Vector2i, to_cell: Vector2i) -> int:
	if bf == null or unit == null or not bf.has_method("is_fire_tile"):
		return 0
	var path: Array = bf.get_unit_path(unit, from_cell, to_cell)
	if path.size() <= 1:
		return 0
	var pen: int = 0
	for i in range(1, path.size()):
		var c: Vector2i = path[i]
		if bf.is_fire_tile(c):
			pen += AI_FIRE_TILE_STEP_PENALTY_INT
	return pen


# -------------------------
# Movement: pick a good in-range tile (min/max range)
# Returns steps excluding the start tile (same style as your old AIController).
# -------------------------

func _compute_best_move_steps(
	unit: Node2D,
	battlefield: Node2D,
	start_pos: Vector2i,
	target_pos: Vector2i,
	min_r: int,
	max_r: int,
	is_ranged: bool
) -> Array:
	var mv: int = int(unit.move_range)
	if mv <= 0:
		return []

	# Reachable tiles via your battlefield range system
	battlefield.astar.set_point_solid(start_pos, false)
	battlefield.calculate_ranges(unit)
	var reachable_raw: Array = battlefield.reachable_tiles.duplicate()
	battlefield.clear_ranges()
	battlefield.astar.set_point_solid(start_pos, true)

	# Build valid in-range landing spots
	var valid_spots: Array = []
	for item in reachable_raw:
		var pos: Vector2i = item
		var dist: int = abs(pos.x - target_pos.x) + abs(pos.y - target_pos.y)
		if dist < min_r or dist > max_r:
			continue
		var occupier: Node2D = battlefield.get_occupant_at(pos)
		if occupier == null or occupier == unit:
			valid_spots.append(pos)

	# Choose best spot (simple FE-ish spacing)
	if valid_spots.size() > 0:
		var best_spot: Vector2i = start_pos
		var best_score: int = -999999

		for spot_item in valid_spots:
			var spot: Vector2i = spot_item
			var d: int = abs(spot.x - target_pos.x) + abs(spot.y - target_pos.y)
			var s: int = 0

			if is_ranged:
				s += d * 10 # farther is better
			else:
				s -= d * 10 # closer is better

			if spot == start_pos:
				s += 5

			s -= _fire_path_penalty_int(battlefield, unit, start_pos, spot)

			if s > best_score:
				best_score = s
				best_spot = spot

		return _path_steps_limited(battlefield, start_pos, best_spot, mv)

	# Otherwise: move toward target (classic simple AI)
	return _path_steps_limited(battlefield, start_pos, target_pos, mv)


func _path_steps_limited(battlefield: Node2D, start: Vector2i, goal: Vector2i, mv: int) -> Array:
	battlefield.astar.set_point_solid(start, false)
	battlefield.astar.set_point_solid(goal, false)

	var full_path: Array = battlefield.astar.get_id_path(start, goal)

	battlefield.astar.set_point_solid(start, true)
	battlefield.astar.set_point_solid(goal, true)

	if full_path.size() <= 1:
		return []

	# Steps excluding start, limited by mv
	var steps_to_take: int = min(mv, full_path.size() - 1)
	var steps: Array = []
	for i in range(1, steps_to_take + 1):
		steps.append(full_path[i])

	return steps


# -------------------------
# Acting based on plan type
# -------------------------

func _ai_execute_combat(bf: Node2D, attacker: Node2D, defender: Node2D, used_ability: bool = false) -> void:
	if bf == null or not is_instance_valid(bf):
		return
	if bf.has_method("coop_enet_ai_execute_combat"):
		await bf.coop_enet_ai_execute_combat(attacker, defender, used_ability)
	else:
		await bf.execute_combat(attacker, defender, used_ability)


func _execute_plan_action(unit: Node2D, battlefield: Node2D, target: Node2D, target_type: String) -> void:
	match target_type:
		TYPE_HOSTILE:
			unit.look_at_pos(battlefield.get_grid_pos(target))
			await _ai_execute_combat(battlefield, unit, target, false)
			_focus_target = target
		TYPE_CRATE:
			unit.look_at_pos(battlefield.get_grid_pos(target))
			await _ai_execute_combat(battlefield, unit, target, false)
		TYPE_ALLY_HEAL:
			if int(target.current_hp) < int(target.max_hp):
				unit.look_at_pos(battlefield.get_grid_pos(target))
				await _ai_execute_combat(battlefield, unit, target, false)
		TYPE_ALLY_BUFF:
			unit.look_at_pos(battlefield.get_grid_pos(target))
			await _ai_execute_combat(battlefield, unit, target, false)
		TYPE_ALLY_FOLLOW:
			# no action
			pass


# -------------------------
# Unit pools (faction-aware)
# -------------------------

func _get_friendly_units(battlefield: Node2D) -> Array:
	var out: Array = []
	if faction == "enemy":
		if battlefield.enemy_container != null:
			out = battlefield.enemy_container.get_children()
	else:
		if battlefield.player_container != null:
			out.append_array(battlefield.player_container.get_children())
		if battlefield.ally_container != null:
			out.append_array(battlefield.ally_container.get_children())
	return out

func _get_hostile_units(battlefield: Node2D) -> Array:
	var out: Array = []
	if faction == "enemy":
		if battlefield.player_container != null:
			out.append_array(battlefield.player_container.get_children())
		if battlefield.ally_container != null:
			out.append_array(battlefield.ally_container.get_children())
	else:
		if battlefield.enemy_container != null:
			out = battlefield.enemy_container.get_children()
	return out
