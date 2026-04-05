extends RefCounted

## Single combat reader for [PassiveCombatAbilityData]: merges [member UnitData.passive_combat_abilities]
## with legacy [member UnitData.map01_enemy_kit] preset resources (deduped by [enum PassiveCombatAbilityData.EffectKind]).

const GridRangeHelpers = preload("res://Scripts/Core/BattleField/BattleFieldGridRangeHelpers.gd")
const UnitCombatStatusHelpers = preload("res://Scripts/Core/UnitCombatStatusHelpers.gd")
const ActiveCombatAbilityExecutionHelpers = preload("res://Scripts/Core/BattleField/ActiveCombatAbilityExecutionHelpers.gd")

const PassiveAshburst = preload("res://Resources/CombatPassives/Passive_Ashburst.tres")
const PassivePanicHunger = preload("res://Resources/CombatPassives/Passive_PanicHunger.tres")
const PassiveAshSight = preload("res://Resources/CombatPassives/Passive_AshSight.tres")
const PassiveEmberWake = preload("res://Resources/CombatPassives/Passive_EmberWake.tres")
const PassiveKindleScorched = preload("res://Resources/CombatPassives/Passive_KindleScorched.tres")

const KIT_NONE := 0
const KIT_SOUL_REAVER := 1
const KIT_CINDER_ARCHER := 2
const KIT_PYRE_DISCIPLE := 3
const KIT_ASH_CULTIST := 4

const SCORCH_TICK_DMG := 2

const NEIGHBOR_ORDER: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]


static func _kit_preset_resources(kit: int) -> Array[PassiveCombatAbilityData]:
	match kit:
		KIT_SOUL_REAVER:
			return [PassiveAshburst, PassivePanicHunger]
		KIT_CINDER_ARCHER:
			return [PassiveAshSight]
		KIT_PYRE_DISCIPLE:
			return [PassiveEmberWake]
		KIT_ASH_CULTIST:
			return [PassiveKindleScorched]
		_:
			return []


static func collect_passives(unit: Node2D) -> Array[PassiveCombatAbilityData]:
	var out: Array[PassiveCombatAbilityData] = []
	var seen: Dictionary = {}
	if unit == null:
		return out
	var d: Variant = unit.get("data")
	if d == null or not d is Resource:
		return out
	var res: Resource = d as Resource
	var authored: Variant = res.get("passive_combat_abilities")
	if authored is Array:
		for item in authored:
			if item is PassiveCombatAbilityData:
				var p: PassiveCombatAbilityData = item as PassiveCombatAbilityData
				if p.effect_kind != PassiveCombatAbilityData.EffectKind.NONE and not seen.has(p.effect_kind):
					seen[p.effect_kind] = true
					out.append(p)
	var kit_raw: Variant = res.get("map01_enemy_kit")
	var kit: int = int(kit_raw) if kit_raw != null else 0
	for preset in _kit_preset_resources(kit):
		if not preset is PassiveCombatAbilityData:
			continue
		var pd: PassiveCombatAbilityData = preset as PassiveCombatAbilityData
		if pd.effect_kind != PassiveCombatAbilityData.EffectKind.NONE and not seen.has(pd.effect_kind):
			seen[pd.effect_kind] = true
			out.append(pd)
	return out


static func _first_passive_of_kind(unit: Node2D, kind: PassiveCombatAbilityData.EffectKind) -> PassiveCombatAbilityData:
	for p: PassiveCombatAbilityData in collect_passives(unit):
		if p.effect_kind == kind:
			return p
	return null


## Bone pile / skeleton reform: passive [enum PassiveCombatAbilityData.EffectKind.BONE_PILE_REFORM_ON_DEATH] wins; else legacy [member UnitData.bone_pile_reform_rounds].
static func bone_pile_reform_turn_count(unit: Node2D) -> int:
	if unit == null:
		return 0
	var passive: PassiveCombatAbilityData = _first_passive_of_kind(unit, PassiveCombatAbilityData.EffectKind.BONE_PILE_REFORM_ON_DEATH)
	if passive != null:
		return maxi(1, int(passive.reform_after_battle_turn_increments))
	var d: Variant = unit.get("data")
	if d == null or not d is Resource:
		return 0
	var raw: Variant = (d as Resource).get("bone_pile_reform_rounds")
	if raw == null:
		return 0
	var n: int = int(raw)
	return maxi(1, n) if n > 0 else 0


static func bone_pile_reform_suppresses_on_bludgeon_kill(unit: Node2D) -> bool:
	var passive: PassiveCombatAbilityData = _first_passive_of_kind(unit, PassiveCombatAbilityData.EffectKind.BONE_PILE_REFORM_ON_DEATH)
	if passive != null:
		return passive.suppress_reform_if_bludgeoning_kill
	return bone_pile_reform_turn_count(unit) > 0


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
	var passive: PassiveCombatAbilityData = _first_passive_of_kind(attacker, PassiveCombatAbilityData.EffectKind.ASH_SIGHT_HIT)
	if passive == null:
		return 0
	var bonus: int = int(passive.hit_bonus)
	var tiles_a: Array[Vector2i] = GridRangeHelpers.unit_footprint_tiles(field, attacker)
	var tiles_b: Array[Vector2i] = GridRangeHelpers.unit_footprint_tiles(field, defender)
	var min_r: int = int(wpn.min_range) if wpn.get("min_range") != null else 1
	var max_r: int = int(wpn.max_range) if wpn.get("max_range") != null else 1
	for ta: Vector2i in tiles_a:
		for tb: Vector2i in tiles_b:
			var dist: int = abs(tb.x - ta.x) + abs(tb.y - ta.y)
			if dist < min_r or dist > max_r:
				continue
			if not field._attack_has_clear_los(ta, tb):
				continue
			if dist <= 1:
				continue
			if attack_line_has_fire_on_interior(field, ta, tb):
				return bonus
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
	var passive: PassiveCombatAbilityData = _first_passive_of_kind(attacker, PassiveCombatAbilityData.EffectKind.PANIC_HUNGER_HIT)
	if passive == null:
		return 0
	var bonus: int = 0
	if _defender_has_civilian_flag(defender):
		bonus += int(passive.panic_civilian_hit_bonus)
	if not _defender_has_adjacent_ally_support(field, defender):
		bonus += int(passive.panic_isolated_hit_bonus)
	return bonus


## Sum of passive combat HIT modifiers (Ash Sight, Panic Hunger, etc.).
static func passive_combat_hit_bonus(field, attacker: Node2D, defender: Node2D, wpn: Resource) -> int:
	return ash_sight_hit_bonus(field, attacker, defender, wpn) + panic_hunger_hit_bonus(field, attacker, defender, wpn)


static func _manhattan_between_units(field, a: Node2D, b: Node2D) -> int:
	var pa: Vector2i = field.get_grid_pos(a)
	var pb: Vector2i = field.get_grid_pos(b)
	return abs(pb.x - pa.x) + abs(pb.y - pa.y)


static func _passive_applies_on_hit_weapon(passive: PassiveCombatAbilityData, wpn: Resource, is_magic: bool, field, attacker: Node2D, defender: Node2D) -> bool:
	if passive.require_magic_weapon and not is_magic:
		return false
	if passive.require_tome_weapon_family:
		if wpn == null or WeaponData.get_weapon_family(int(wpn.weapon_type)) != WeaponData.WeaponType.TOME:
			return false
	if passive.require_adjacent_melee_range and _manhattan_between_units(field, attacker, defender) > 1:
		return false
	return true


static func apply_status_on_weapon_hit_passives(field, attacker: Node2D, defender: Node2D, wpn: Resource, is_magic: bool) -> void:
	if attacker == null or defender == null:
		return
	for passive: PassiveCombatAbilityData in collect_passives(attacker):
		if passive.effect_kind != PassiveCombatAbilityData.EffectKind.APPLY_STATUS_ON_WEAPON_HIT:
			continue
		if not _passive_applies_on_hit_weapon(passive, wpn, is_magic, field, attacker, defender):
			continue
		var sid: String = str(passive.status_id_to_apply).strip_edges()
		if sid == "" or defender.get("combat_statuses") == null:
			continue
		if sid == UnitCombatStatusHelpers.ID_BONE_TOXIN:
			if not ActiveCombatAbilityExecutionHelpers.targets_align_with_hostile_flag(field, attacker, defender, true):
				continue
		var apply_opts: Dictionary = {}
		if sid == UnitCombatStatusHelpers.ID_BONE_TOXIN:
			apply_opts = {"stacks": 3}
		UnitCombatStatusHelpers.add_status(defender, sid, apply_opts)
		if sid == UnitCombatStatusHelpers.ID_MAP01_SCORCHED:
			field.add_combat_log(defender.unit_name + " is Scorched (adjacent fire may sear).", "orangered")
		elif sid == UnitCombatStatusHelpers.ID_BONE_TOXIN:
			field.add_combat_log(defender.unit_name + " is poisoned by bone toxin!", "limegreen")
			field.spawn_loot_text("POISONED!", Color(0.45, 0.95, 0.42), defender.global_position + Vector2(32, -40))
		else:
			field.add_combat_log(defender.unit_name + " gains " + sid + ".", "orangered")
		if defender.has_method("refresh_combat_status_sprite_tint"):
			defender.refresh_combat_status_sprite_tint()


static func try_ember_wake_passives(field, attacker: Node2D, defender: Node2D, wpn: Resource, is_magic: bool) -> void:
	if attacker == null or defender == null or wpn == null:
		return
	var passive: PassiveCombatAbilityData = _first_passive_of_kind(attacker, PassiveCombatAbilityData.EffectKind.EMBER_WAKE_FIRE_TILE)
	if passive == null:
		return
	if passive.require_magic_weapon and not is_magic:
		return
	if passive.require_tome_weapon_family and WeaponData.get_weapon_family(int(wpn.weapon_type)) != WeaponData.WeaponType.TOME:
		return
	var tgt: Vector2i = field.get_grid_pos(defender)
	var spot: Vector2i = pick_fire_cell_preferred_then_neighbors(field, tgt)
	if spot.x < 0:
		return
	field.spawn_fire_tile(spot, int(passive.fire_tile_damage), int(passive.fire_tile_duration_turns))
	field.add_combat_log("Ember Wake leaves fire nearby.", "darkorange")


static func try_ashburst_on_enemy_death(field, unit: Node2D, death_cell: Vector2i) -> void:
	if unit == null or unit.get_parent() != field.enemy_container:
		return
	var passive: PassiveCombatAbilityData = _first_passive_of_kind(unit, PassiveCombatAbilityData.EffectKind.ASH_BURST_ON_DEATH)
	if passive == null:
		return
	var spot: Vector2i = pick_fire_cell_preferred_then_neighbors(field, death_cell)
	if spot.x < 0:
		return
	field.spawn_fire_tile(spot, int(passive.fire_tile_damage), int(passive.fire_tile_duration_turns))
	field.add_combat_log("Ashburst: lingering flame marks the tile.", "orange")


static func on_unit_finished_turn_scorched_tick(field, unit: Node2D) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not UnitCombatStatusHelpers.unit_is_map01_scorched(unit):
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
	if defender != null and UnitCombatStatusHelpers.unit_is_map01_scorched(defender):
		out.append("Scorched: if this unit ends its turn orthogonally next to fire, it takes a small extra burn tick.")
	if defender != null and UnitCombatStatusHelpers.has_status(defender, UnitCombatStatusHelpers.ID_BONE_TOXIN):
		out.append("Bone Toxin: 1 damage at the end of each enemy phase; stacks show turns remaining.")
	if attacker != null and atk_wpn != null:
		var ash: PassiveCombatAbilityData = _first_passive_of_kind(attacker, PassiveCombatAbilityData.EffectKind.ASH_SIGHT_HIT)
		if ash != null and ash_sight_hit_bonus(field, attacker, defender, atk_wpn) > 0:
			out.append("Ash Sight: +%d HIT (burning tiles along this line of attack)." % int(ash.hit_bonus))
		if panic_hunger_hit_bonus(field, attacker, defender, atk_wpn) > 0:
			out.append("Panic Hunger: bonus HIT vs civilians / isolated targets (included in HIT%).")
		var ember: PassiveCombatAbilityData = _first_passive_of_kind(attacker, PassiveCombatAbilityData.EffectKind.EMBER_WAKE_FIRE_TILE)
		if ember != null and atk_wpn.damage_type == WeaponData.DamageType.MAGIC:
			if not ember.require_tome_weapon_family or WeaponData.get_weapon_family(int(atk_wpn.weapon_type)) == WeaponData.WeaponType.TOME:
				out.append("Ember Wake: a successful Fire Tome hit may leave a short-lived fire tile (target cell or fixed neighbor).")
	if defender != null:
		var n_turns: int = bone_pile_reform_turn_count(defender)
		if n_turns > 0:
			var bludg: bool = bone_pile_reform_suppresses_on_bludgeon_kill(defender)
			if bludg:
				out.append("Bone pile: if this unit dies to a non-bludgeoning blow, it may reform after %d battle turn increments (tile blocked until then)." % n_turns)
			else:
				out.append("Bone pile: on death, may reform after %d battle turn increments (tile blocked until then)." % n_turns)
	return out
