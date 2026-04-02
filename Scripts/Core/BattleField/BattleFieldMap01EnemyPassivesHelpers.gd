extends RefCounted

const GridRangeHelpers = preload("res://Scripts/Core/BattleField/BattleFieldGridRangeHelpers.gd")

const KIT_NONE := 0
const KIT_SOUL_REAVER := 1
const KIT_CINDER_ARCHER := 2
const KIT_PYRE_DISCIPLE := 3
const KIT_ASH_CULTIST := 4

const META_SCORCHED := "map01_scorched"

const ASH_SIGHT_HIT := 12
const PANIC_CIVILIAN_HIT := 15
const PANIC_ISOLATED_HIT := 10

const ASHBURST_FIRE_DMG := 1
const ASHBURST_FIRE_TURNS := 1
const EMBER_WAKE_FIRE_DMG := 1
const EMBER_WAKE_FIRE_TURNS := 2
const SCORCH_TICK_DMG := 2

const NEIGHBOR_ORDER: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]


static func _kit(unit: Node2D) -> int:
	var d: Variant = unit.get("data") if unit != null else null
	if d == null or not d is Resource:
		return KIT_NONE
	var v: Variant = (d as Resource).get("map01_enemy_kit")
	if v == null:
		return KIT_NONE
	return int(v)


static func _is_utility_staff(wpn: Resource) -> bool:
	if wpn == null:
		return false
	return (
		wpn.get("is_healing_staff") == true
		or wpn.get("is_buff_staff") == true
		or wpn.get("is_debuff_staff") == true
	)


static func _cell_open_for_map01_fire(field, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= field.GRID_SIZE.x or cell.y >= field.GRID_SIZE.y:
		return false
	if GridRangeHelpers.is_wall_at(field, cell):
		return false
	return true


static func pick_fire_cell_preferred_then_neighbors(field, preferred: Vector2i) -> Vector2i:
	if _cell_open_for_map01_fire(field, preferred):
		return preferred
	for offs: Vector2i in NEIGHBOR_ORDER:
		var c: Vector2i = preferred + offs
		if _cell_open_for_map01_fire(field, c):
			return c
	return Vector2i(-1, -1)


static func attack_line_has_fire_on_interior(field, start: Vector2i, target: Vector2i) -> bool:
	var dist: int = abs(target.x - start.x) + abs(target.y - start.y)
	if dist <= 1:
		return false
	var dx: int = abs(target.x - start.x)
	var dy: int = -abs(target.y - start.y)
	var sx: int = 1 if start.x < target.x else -1
	var sy: int = 1 if start.y < target.y else -1
	var err: int = dx + dy
	var current: Vector2i = start
	while true:
		if current != start and current != target:
			if field.is_fire_tile(current):
				return true
		if current == target:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			current.x += sx
		if e2 <= dx:
			err += dx
			current.y += sy
	return false


static func ash_sight_hit_bonus(field, attacker: Node2D, defender: Node2D, wpn: Resource) -> int:
	if wpn == null or _is_utility_staff(wpn):
		return 0
	if _kit(attacker) != KIT_CINDER_ARCHER:
		return 0
	var tiles_a: Array[Vector2i] = GridRangeHelpers.unit_footprint_tiles(field, attacker)
	var tiles_b: Array[Vector2i] = GridRangeHelpers.unit_footprint_tiles(field, defender)
	var min_r: int = int(wpn.min_range) if wpn.get("min_range") != null else 1
	var max_r: int = int(wpn.max_range) if wpn.get("max_range") != null else 1
	for ta: Vector2i in tiles_a:
		for tb: Vector2i in tiles_b:
			var d: int = abs(tb.x - ta.x) + abs(tb.y - ta.y)
			if d < min_r or d > max_r:
				continue
			if not field._attack_has_clear_los(ta, tb):
				continue
			if d <= 1:
				continue
			if attack_line_has_fire_on_interior(field, ta, tb):
				return ASH_SIGHT_HIT
	return 0


static func _defender_has_civilian_flag(defender: Node2D) -> bool:
	var d: Variant = defender.get("data") if defender != null else null
	if d == null or not d is Resource:
		return false
	return (d as Resource).get("counts_as_civilian_escort_target") == true


static func _defender_has_adjacent_ally_support(field, defender: Node2D) -> bool:
	if defender == null:
		return false
	var p: Node = defender.get_parent()
	if p == null:
		return false
	var pos: Vector2i = field.get_grid_pos(defender)
	for offs: Vector2i in NEIGHBOR_ORDER:
		var oc: Node2D = field.get_occupant_at(pos + offs)
		if oc == null or not is_instance_valid(oc) or oc == defender:
			continue
		if oc.get_parent() != p:
			continue
		if oc.get("current_hp") != null and int(oc.current_hp) > 0:
			return true
	return false


static func panic_hunger_hit_bonus(field, attacker: Node2D, defender: Node2D, wpn: Resource) -> int:
	if wpn == null or _is_utility_staff(wpn):
		return 0
	if _kit(attacker) != KIT_SOUL_REAVER:
		return 0
	var bonus: int = 0
	if _defender_has_civilian_flag(defender):
		bonus += PANIC_CIVILIAN_HIT
	if not _defender_has_adjacent_ally_support(field, defender):
		bonus += PANIC_ISOLATED_HIT
	return bonus


static func map01_striker_hit_bonus(field, attacker: Node2D, defender: Node2D, wpn: Resource) -> int:
	return ash_sight_hit_bonus(field, attacker, defender, wpn) + panic_hunger_hit_bonus(field, attacker, defender, wpn)


static func try_ashburst_on_enemy_death(field, unit: Node2D, death_cell: Vector2i) -> void:
	if unit == null or unit.get_parent() != field.enemy_container:
		return
	if _kit(unit) != KIT_SOUL_REAVER:
		return
	var spot: Vector2i = pick_fire_cell_preferred_then_neighbors(field, death_cell)
	if spot.x < 0:
		return
	field.spawn_fire_tile(spot, ASHBURST_FIRE_DMG, ASHBURST_FIRE_TURNS)
	field.add_combat_log("Ashburst: lingering flame marks the tile.", "orange")


static func apply_kindle_slash_on_hit(field, attacker: Node2D, defender: Node2D) -> void:
	if attacker == null or defender == null:
		return
	if _kit(attacker) != KIT_ASH_CULTIST:
		return
	defender.set_meta(META_SCORCHED, true)
	field.add_combat_log(defender.unit_name + " is Scorched (adjacent fire may sear).", "orangered")


static func try_ember_wake(field, attacker: Node2D, defender: Node2D, wpn: Resource, is_magic: bool) -> void:
	if attacker == null or defender == null or wpn == null:
		return
	if _kit(attacker) != KIT_PYRE_DISCIPLE:
		return
	if not is_magic:
		return
	if WeaponData.get_weapon_family(int(wpn.weapon_type)) != WeaponData.WeaponType.TOME:
		return
	var tgt: Vector2i = field.get_grid_pos(defender)
	var spot: Vector2i = pick_fire_cell_preferred_then_neighbors(field, tgt)
	if spot.x < 0:
		return
	field.spawn_fire_tile(spot, EMBER_WAKE_FIRE_DMG, EMBER_WAKE_FIRE_TURNS)
	field.add_combat_log("Ember Wake leaves fire nearby.", "darkorange")


static func on_unit_finished_turn_scorched_tick(field, unit: Node2D) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not unit.has_meta(META_SCORCHED) or unit.get_meta(META_SCORCHED) != true:
		return
	if unit.get("current_hp") == null or int(unit.current_hp) <= 0:
		return
	var pos: Vector2i = field.get_grid_pos(unit)
	for offs: Vector2i in NEIGHBOR_ORDER:
		if field.is_fire_tile(pos + offs):
			unit.take_damage(SCORCH_TICK_DMG, null)
			field.spawn_loot_text("SCORCH", Color(1.0, 0.35, 0.15), unit.global_position + Vector2(28, -36))
			field.add_combat_log(unit.unit_name + " is seared by Scorched + fire!", "orangered")
			return


static func ensure_finished_turn_hook(field, unit: Node2D) -> void:
	if unit == null or not unit.has_signal("finished_turn"):
		return
	if unit.finished_turn.is_connected(field._map01_on_unit_finished_turn):
		return
	unit.finished_turn.connect(field._map01_on_unit_finished_turn)


static func forecast_extra_lines(field, attacker: Node2D, defender: Node2D, atk_wpn: Resource) -> Array[String]:
	var out: Array[String] = []
	if defender != null and defender.has_meta(META_SCORCHED) and defender.get_meta(META_SCORCHED) == true:
		out.append("Scorched: if this unit ends its turn orthogonally next to fire, it takes a small extra burn tick.")
	if attacker != null and atk_wpn != null:
		if ash_sight_hit_bonus(field, attacker, defender, atk_wpn) > 0:
			out.append("Ash Sight: +%d HIT (burning tiles along this line of attack)." % ASH_SIGHT_HIT)
		if panic_hunger_hit_bonus(field, attacker, defender, atk_wpn) > 0:
			out.append("Panic Hunger: bonus HIT vs civilians / isolated targets (included in HIT%).")
		if _kit(attacker) == KIT_PYRE_DISCIPLE and atk_wpn.damage_type == WeaponData.DamageType.MAGIC and WeaponData.get_weapon_family(int(atk_wpn.weapon_type)) == WeaponData.WeaponType.TOME:
			out.append("Ember Wake: a successful Fire Tome hit may leave a short-lived fire tile (target cell or fixed neighbor).")
	return out
