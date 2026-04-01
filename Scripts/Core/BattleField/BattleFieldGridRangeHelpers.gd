extends RefCounted

## Grid solidity, paths, player/enemy reach & attack ranges, danger zone union, LOS for attacks & FoW.

static func attack_line_step(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	var dx: int = to_cell.x - from_cell.x
	var dy: int = to_cell.y - from_cell.y
	var sx: int = 0 if dx == 0 else (1 if dx > 0 else -1)
	var sy: int = 0 if dy == 0 else (1 if dy > 0 else -1)
	if sx == 0 and sy == 0:
		return Vector2i.ZERO
	return Vector2i(sx, sy)


static func get_unit_at(field, pos: Vector2i) -> Node2D:
	for u in field.player_container.get_children():
		if u.visible and not u.is_queued_for_deletion():
			if u.has_method("get_occupied_tiles"):
				if pos in u.get_occupied_tiles(field): return u
			elif field.get_grid_pos(u) == pos: return u
	return null


static func get_occupant_at(field, pos: Vector2i) -> Node2D:
	var containers = [field.player_container, field.enemy_container, field.ally_container, field.destructibles_container, field.chests_container]

	for c in containers:
		if c != null:
			for child in c.get_children():
				if child == null or child.is_queued_for_deletion():
					continue

				if child.has_method("is_targetable") and not child.is_targetable():
					continue

				if child.has_method("get_occupied_tiles"):
					if pos in child.get_occupied_tiles(field):
						return child
				else:
					if field.get_grid_pos(child) == pos:
						return child

	return null


static func unit_footprint_tiles(field, unit: Node2D) -> Array[Vector2i]:
	if unit != null and unit.has_method("get_occupied_tiles"):
		var raw: Array = unit.get_occupied_tiles(field)
		var out: Array[Vector2i] = []
		for t in raw:
			if t is Vector2i:
				out.append(t as Vector2i)
		if out.size() > 0:
			return out
	return [field.get_grid_pos(unit)]


static func is_wall_at(field, pos: Vector2i) -> bool:
	if field.walls_container == null: return false
	
	for w in field.walls_container.get_children():
		if not is_instance_valid(w) or w.is_queued_for_deletion(): continue
		
		# Support for both 1x1 walls and massive multi-tile walls!
		if w.has_method("get_occupied_tiles"):
			if pos in w.get_occupied_tiles(field):
				return true
		else:
			if field.get_grid_pos(w) == pos:
				return true
				
	return false


static func check_line_of_sight(field, start: Vector2i, target: Vector2i) -> bool:
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
			if is_wall_at(field, current):
				return false
				
			# (We keep the TileMap check as a backup just in case you ever 
			# want to add "Mountain" or "Thick Forest" tiles later)
			var t_data = field.get_terrain_data(current)
			if field.vision_blocking_terrain.has(t_data["name"]):
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


static func attack_has_clear_los(field, from_tile: Vector2i, to_tile: Vector2i) -> bool:
	if from_tile == to_tile:
		return true
	var dist: int = abs(from_tile.x - to_tile.x) + abs(from_tile.y - to_tile.y)
	if dist <= 1:
		return true
	return check_line_of_sight(field, from_tile, to_tile)


static func danger_overlay_cell_drawable(field, cell: Vector2i) -> bool:
	if not field.use_fog_of_war:
		return true
	return field.fow_grid.has(cell) and field.fow_grid[cell] == 2


static func clear_ranges(field) -> void:
	field.reachable_tiles.clear()
	field.attackable_tiles.clear()
	field.enemy_reachable_tiles.clear() # Added
	field.enemy_attackable_tiles.clear() # Added
	field.queue_redraw()


static func get_unit_path(field, unit: Node2D, start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	if unit.get("move_type") == 2: # FLYING
		return field.flying_astar.get_id_path(start, target)
	return field.astar.get_id_path(start, target)


static func get_path_move_cost(field, path: Array[Vector2i], unit: Node2D) -> float:
	var total_cost = 0.0
	var is_flying = unit.get("move_type") == 2 # FLYING
	var is_armored = unit.get("move_type") == 1 # ARMORED


	for i in range(1, path.size()):
		if is_flying:
			total_cost += 1.0
		else:
			var base_cost = field.astar.get_point_weight_scale(path[i])
			# If terrain is tough (Cost > 1.0) and unit is Armored, punish them!
			if is_armored and base_cost > 1.0:
				base_cost += 1.0 
			total_cost += base_cost
	return total_cost


static func rebuild_grid(field) -> void:
	field.astar.fill_solid_region(field.astar.region, false)
	field.flying_astar.fill_solid_region(field.flying_astar.region, false)

	for x in range(field.GRID_SIZE.x):
		for y in range(field.GRID_SIZE.y):
			var pos = Vector2i(x, y)
			var t_data = field.get_terrain_data(pos)
			field.astar.set_point_weight_scale(pos, t_data["move_cost"])
			field.flying_astar.set_point_weight_scale(pos, 1.0)

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

		var tiles = [field.get_grid_pos(node)]
		if node.has_method("get_occupied_tiles"):
			tiles = node.get_occupied_tiles(field)

		for t in tiles:
			if t.x >= 0 and t.x < field.GRID_SIZE.x and t.y >= 0 and t.y < field.GRID_SIZE.y:
				if should_block_movement:
					field.astar.set_point_solid(t, true)
				if should_block_fliers:
					field.flying_astar.set_point_solid(t, true)

	# --- SOLID OBJECTS (Only block walking units unless overridden) ---
	for w in field.walls_container.get_children():
		apply_solidity.call(w, false)

	if field.destructibles_container:
		for d in field.destructibles_container.get_children():
			apply_solidity.call(d, false)

	if field.chests_container:
		for c in field.chests_container.get_children():
			if not c.is_queued_for_deletion() and c.is_locked:
				field.astar.set_point_solid(field.get_grid_pos(c), true)

	# --- ENEMIES (Block BOTH walkers and fliers unless overridden) ---
	if field.enemy_container:
		for e in field.enemy_container.get_children():
			apply_solidity.call(e, true)

	# --- PLAYER & ALLIES ---
	var all_units = field.player_container.get_children()
	if field.ally_container:
		all_units += field.ally_container.get_children()

	for u in all_units:
		apply_solidity.call(u, false)

	if field.show_danger_zone:
		field._danger_zone_recalc_dirty = true


static func calculate_ranges(field, unit: Node2D) -> void:
	clear_ranges(field)
	if unit == null: return

	var footprint: Array[Vector2i] = unit_footprint_tiles(field, unit)
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
			saved[t] = {"w": field.astar.is_point_solid(t), "fl": field.flying_astar.is_point_solid(t)}
			field.astar.set_point_solid(t, false)
			field.flying_astar.set_point_solid(t, false)

		var reach_accum: Dictionary = {}
		for start in footprint:
			var x0: int = maxi(0, start.x - budget_shape)
			var x1: int = mini(field.GRID_SIZE.x, start.x + budget_shape + 1)
			var y0: int = maxi(0, start.y - budget_shape)
			var y1: int = mini(field.GRID_SIZE.y, start.y + budget_shape + 1)
			for x in range(x0, x1):
				for y in range(y0, y1):
					var target = Vector2i(x, y)
					if abs(start.x - target.x) + abs(start.y - target.y) > budget_shape:
						continue

					var is_solid = field.flying_astar.is_point_solid(target) if unit.get("move_type") == 2 else field.astar.is_point_solid(target)

					if target != start and is_solid:
						continue
					var path = get_unit_path(field, unit, start, target)
					if path.size() > 0:
						var path_cost = get_path_move_cost(field, path, unit)
						if path_cost <= eff_budget:
							reach_accum[target] = true

		for t in footprint:
			var rec: Variant = saved.get(t, null)
			if rec != null:
				field.astar.set_point_solid(t, rec.w)
				field.flying_astar.set_point_solid(t, rec.fl)

		for k in reach_accum.keys():
			field.reachable_tiles.append(k)
	else:
		for t in footprint:
			field.reachable_tiles.append(t)

	# --- FILTER LANDING ZONES ---
	# Ensure fliers don't end their turn hovering inside a wall, and no one lands on friends!
	var final_reachable: Array[Vector2i] = []
	for tile in field.reachable_tiles:
		var valid = true
		var occupant = get_unit_at(field, tile)
		if occupant != null and occupant != unit: valid = false
		
		if unit.get("move_type") == 2: # FLYING
			for w in field.walls_container.get_children():
				if field.get_grid_pos(w) == tile: valid = false
			for d in field.destructibles_container.get_children():
				if field.get_grid_pos(d) == tile and not d.is_queued_for_deletion(): valid = false
			for c in field.chests_container.get_children():
				if field.get_grid_pos(c) == tile and not c.is_queued_for_deletion(): valid = false

		if valid: final_reachable.append(tile)
			
	field.reachable_tiles = final_reachable

	# 2. Attackable Tiles (Red) â€” not during Canto (no second attack)
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

		for r_tile in field.reachable_tiles:
			for x in range(-max_r, max_r + 1):
				for y in range(-max_r, max_r + 1):
					var dist = abs(x) + abs(y)
					if dist >= min_r and dist <= max_r:
						var n = r_tile + Vector2i(x, y)
						if n.x >= 0 and n.x < field.GRID_SIZE.x and n.y >= 0 and n.y < field.GRID_SIZE.y:
							if not field.reachable_tiles.has(n) and not field.attackable_tiles.has(n):
								if use_attack_los and not attack_has_clear_los(field, r_tile, n):
									continue
								field.attackable_tiles.append(n)

	if unit.has_moved and not in_canto:
		field.reachable_tiles.clear()
	field.queue_redraw()


static func calculate_enemy_threat_range(field, enemy: Node2D) -> void:
	clear_ranges(field)
	field.enemy_reachable_tiles.clear()
	field.enemy_attackable_tiles.clear()
	if enemy == null: return
	if not field.can_preview_enemy_threat(enemy): return

	var footprint: Array[Vector2i] = unit_footprint_tiles(field, enemy)
	var move_range = enemy.get("move_range") if enemy.get("move_range") != null else 0

	var saved: Dictionary = {}
	for t in footprint:
		saved[t] = {"w": field.astar.is_point_solid(t), "fl": field.flying_astar.is_point_solid(t)}
		field.astar.set_point_solid(t, false)
		field.flying_astar.set_point_solid(t, false)

	var reach_accum: Dictionary = {}
	for start in footprint:
		var x0: int = maxi(0, start.x - move_range)
		var x1: int = mini(field.GRID_SIZE.x, start.x + move_range + 1)
		var y0: int = maxi(0, start.y - move_range)
		var y1: int = mini(field.GRID_SIZE.y, start.y + move_range + 1)
		for x in range(x0, x1):
			for y in range(y0, y1):
				var target = Vector2i(x, y)
				if abs(start.x - target.x) + abs(start.y - target.y) > move_range:
					continue

				var path = get_unit_path(field, enemy, start, target)
				if path.size() > 0:
					var path_cost = get_path_move_cost(field, path, enemy)
					if path_cost <= float(move_range):
						reach_accum[target] = true

	for t in footprint:
		var rec: Variant = saved.get(t, null)
		if rec != null:
			field.astar.set_point_solid(t, rec.w)
			field.flying_astar.set_point_solid(t, rec.fl)

	for k in reach_accum.keys():
		field.enemy_reachable_tiles.append(k)

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

	for r_tile in field.enemy_reachable_tiles:
		for x in range(-max_r, max_r + 1):
			for y in range(-max_r, max_r + 1):
				var dist = abs(x) + abs(y)
				if dist >= min_r and dist <= max_r:
					var n = r_tile + Vector2i(x, y)
					if n.x >= 0 and n.x < field.GRID_SIZE.x and n.y >= 0 and n.y < field.GRID_SIZE.y:
						if not field.enemy_reachable_tiles.has(n) and not field.enemy_attackable_tiles.has(n):
							if enemy_use_los and not attack_has_clear_los(field, r_tile, n):
								continue
							field.enemy_attackable_tiles.append(n)
	field.queue_redraw()


static func calculate_full_danger_zone(field) -> void:
	field._danger_zone_recalc_dirty = false
	field.danger_zone_move_tiles.clear()
	field.danger_zone_attack_tiles.clear()
	if field.enemy_container == null: return

	var union_move: Dictionary = {}
	var union_attack: Dictionary = {}

	for enemy in field.enemy_container.get_children():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		# Match get_enemy_at / FoW: hidden enemies do not contribute threat.
		if not enemy.visible:
			continue
		if enemy.get("current_hp") != null and enemy.current_hp <= 0:
			continue

		var footprint: Array[Vector2i] = unit_footprint_tiles(field, enemy)
		var move_range = enemy.get("move_range") if enemy.get("move_range") != null else 0

		var saved: Dictionary = {}
		for t in footprint:
			saved[t] = {"w": field.astar.is_point_solid(t), "fl": field.flying_astar.is_point_solid(t)}
			field.astar.set_point_solid(t, false)
			field.flying_astar.set_point_solid(t, false)

		var reachable: Array[Vector2i] = []
		var reach_seen: Dictionary = {}
		for start in footprint:
			var x0: int = maxi(0, start.x - move_range)
			var x1: int = mini(field.GRID_SIZE.x, start.x + move_range + 1)
			var y0: int = maxi(0, start.y - move_range)
			var y1: int = mini(field.GRID_SIZE.y, start.y + move_range + 1)
			for x in range(x0, x1):
				for y in range(y0, y1):
					var target = Vector2i(x, y)
					if abs(start.x - target.x) + abs(start.y - target.y) > move_range:
						continue
					var path = get_unit_path(field, enemy, start, target)
					if path.size() > 0:
						var path_cost = get_path_move_cost(field, path, enemy)
						if path_cost <= float(move_range):
							if not reach_seen.has(target):
								reach_seen[target] = true
								reachable.append(target)

		for t in footprint:
			var rec: Variant = saved.get(t, null)
			if rec != null:
				field.astar.set_point_solid(t, rec.w)
				field.flying_astar.set_point_solid(t, rec.fl)

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
					if n.x < 0 or n.x >= field.GRID_SIZE.x or n.y < 0 or n.y >= field.GRID_SIZE.y:
						continue
					if reachable_set.has(n):
						continue
					if union_attack.has(n):
						continue
					if danger_use_los and not attack_has_clear_los(field, r_tile, n):
						continue
					union_attack[n] = true

	for k in union_move.keys():
		field.danger_zone_move_tiles.append(k)
	for k in union_attack.keys():
		field.danger_zone_attack_tiles.append(k)
	field.queue_redraw()
