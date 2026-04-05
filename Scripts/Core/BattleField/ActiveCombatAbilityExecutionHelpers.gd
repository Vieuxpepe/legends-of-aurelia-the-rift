extends RefCounted

## Resolves [ActiveCombatAbilityData] outside normal weapon combat (forecast button, AI). Cooldown applied after a successful resolve.

const ActiveCombatAbilityHelpers = preload("res://Scripts/Core/BattleField/ActiveCombatAbilityHelpers.gd")
const UnitCombatStatusHelpers = preload("res://Scripts/Core/UnitCombatStatusHelpers.gd")

## Mirrors [enum Unit.AIBehavior] for numeric checks without hard dependency on [Unit].
const AI_BEH_DEFAULT := 0
const AI_BEH_THIEF := 1
const AI_BEH_SUPPORT := 2
const AI_BEH_COWARD := 3
const AI_BEH_AGGRESSIVE := 4
const AI_BEH_MINION := 5


static func _weapon_range_min_max(unit: Node) -> Vector2i:
	var w: Resource = unit.get("equipped_weapon") as Resource if unit != null else null
	var mn: int = int(w.min_range) if w != null and w.get("min_range") != null else 1
	var mx: int = int(w.max_range) if w != null and w.get("max_range") != null else 1
	return Vector2i(mn, mx)


static func ability_range_min_max(unit: Node, def) -> Vector2i:
	if def == null:
		return Vector2i(1, 1)
	if def.use_weapon_range:
		return _weapon_range_min_max(unit)
	return Vector2i(maxi(0, int(def.ability_min_range)), maxi(1, int(def.ability_max_range)))


static func in_ability_range(field, caster: Node2D, target: Node2D, def) -> bool:
	var mm: Vector2i = ability_range_min_max(caster, def)
	var d: int = field.get_distance(caster, target)
	return d >= int(mm.x) and d <= int(mm.y)


static func is_enemy_faction_unit(field, u: Node2D) -> bool:
	return u != null and is_instance_valid(u) and u.get_parent() == field.enemy_container


static func is_player_side_unit(field, u: Node2D) -> bool:
	if u == null or not is_instance_valid(u):
		return false
	var p: Node = u.get_parent()
	return p == field.player_container or (field.ally_container != null and p == field.ally_container)


static func targets_align_with_hostile_flag(field, caster: Node2D, target: Node2D, target_hostile: bool) -> bool:
	var on_enemy: bool = is_enemy_faction_unit(field, target)
	var on_ps: bool = is_player_side_unit(field, target)
	if target_hostile:
		if is_enemy_faction_unit(field, caster):
			return on_ps
		return on_enemy
	if is_enemy_faction_unit(field, caster):
		return on_enemy
	return on_ps


static func can_use_targeted(field, caster: Node2D, target: Node2D, def) -> bool:
	if field == null or caster == null or target == null or def == null:
		return false
	if int(def.effect_kind) != int(ActiveCombatAbilityData.EffectKind.TARGETED_SCRIPT):
		return false
	if int(target.current_hp) <= 0:
		return false
	if not ActiveCombatAbilityHelpers.is_ready(caster, def.ability_id):
		return false
	if not targets_align_with_hostile_flag(field, caster, target, def.target_hostile):
		return false
	return in_ability_range(field, caster, target, def)


static func can_use_self_centered(field, caster: Node2D, def) -> bool:
	if field == null or caster == null or def == null:
		return false
	if int(def.effect_kind) != int(ActiveCombatAbilityData.EffectKind.SELF_CENTERED):
		return false
	if int(caster.current_hp) <= 0:
		return false
	return ActiveCombatAbilityHelpers.is_ready(caster, def.ability_id)


static func _ai_read_intel_behavior(unit: Node2D) -> Vector2i:
	var intel: int = 1
	var beh: int = AI_BEH_DEFAULT
	if unit == null:
		return Vector2i(intel, beh)
	var iv: Variant = unit.get("ai_intelligence")
	if iv != null:
		intel = maxi(1, int(iv))
	var bv: Variant = unit.get("ai_behavior")
	if bv != null:
		beh = int(bv)
	return Vector2i(intel, beh)


static func _estimate_weapon_damage_approx(attacker: Node2D, defender: Node2D) -> int:
	if attacker == null or defender == null:
		return 0
	var w: Resource = attacker.get("equipped_weapon") as Resource
	var atk: int = 0
	if w != null:
		var dt: Variant = w.get("damage_type")
		if dt != null and int(dt) == int(WeaponData.DamageType.MAGIC):
			atk = int(attacker.magic) + int(w.might)
		else:
			atk = int(attacker.strength) + int(w.might)
	else:
		atk = int(attacker.strength)
	var def_stat: int = 0
	if w != null:
		var dt2: Variant = w.get("damage_type")
		if dt2 != null and int(dt2) == int(WeaponData.DamageType.MAGIC):
			def_stat = int(defender.resistance)
		else:
			def_stat = int(defender.defense)
	else:
		def_stat = int(defender.defense)
	return maxi(0, atk - def_stat)


static func _estimate_targeted_ability_damage_on_target(def: ActiveCombatAbilityData, target: Node2D) -> int:
	if def == null or target == null:
		return 0
	var mag: int = int(def.magic_damage)
	var phys: int = int(def.physical_damage)
	var sum: int = 0
	if mag > 0:
		sum += maxi(1, mag - int(target.resistance) / 3)
	if phys > 0:
		sum += maxi(1, phys - int(target.defense) / 3)
	return sum


static func _targeted_status_edge(def: ActiveCombatAbilityData, intel: int) -> int:
	if def == null or intel < 2:
		return 0
	var sid: String = str(def.apply_combat_status_id).strip_edges()
	return 18 if sid != "" else 0


static func _ai_accept_targeted_hostile(
	_unit: Node2D,
	target: Node2D,
	def: ActiveCombatAbilityData,
	intel: int,
	beh: int
) -> bool:
	var hp: int = int(target.current_hp)
	if hp <= 0:
		return false
	var w_dmg: int = _estimate_weapon_damage_approx(_unit, target)
	var a_dmg: int = _estimate_targeted_ability_damage_on_target(def, target)
	var status_e: int = _targeted_status_edge(def, intel)
	var eff_abi: int = a_dmg + status_e
	var weapon_kills: bool = w_dmg >= hp
	var ability_kills: bool = a_dmg >= hp

	if beh == AI_BEH_AGGRESSIVE:
		eff_abi += 4
	elif beh == AI_BEH_THIEF:
		eff_abi -= 3

	if intel <= 1:
		if ability_kills and not weapon_kills:
			return true
		if ability_kills and weapon_kills:
			return a_dmg >= w_dmg
		return false

	if intel == 2:
		if weapon_kills and status_e <= 0:
			return false
		return eff_abi >= w_dmg or ability_kills

	# intel >= 3
	if weapon_kills and status_e <= 0:
		return false
	if ability_kills and (not weapon_kills or status_e > 0):
		return true
	return eff_abi >= w_dmg + 5


static func _ai_accept_targeted_ally_heal(
	target: Node2D,
	def: ActiveCombatAbilityData,
	intel: int,
	beh: int
) -> bool:
	var mx: int = int(target.max_hp)
	var cur: int = int(target.current_hp)
	var missing: int = mx - cur
	var heal: int = int(def.heal_amount)
	if missing <= 0 or heal <= 0:
		return false
	var waste: int = maxi(0, heal - missing)
	var waste_ratio: float = float(waste) / float(max(1, heal))

	var waste_cap: float = 0.55
	if intel >= 3:
		waste_cap = 0.32
	elif intel == 2:
		waste_cap = 0.55
	else:
		waste_cap = 0.95

	if beh == AI_BEH_SUPPORT:
		waste_cap += 0.18
	elif beh == AI_BEH_AGGRESSIVE:
		waste_cap -= 0.12

	if intel <= 1:
		return float(cur) <= float(mx) * 0.42 and missing >= maxi(3, heal / 2)

	return waste_ratio <= waste_cap


static func _self_centered_total_value(field, caster: Node2D, def: ActiveCombatAbilityData) -> Dictionary:
	var out: Dictionary = {
		"dmg_units": 0,
		"heal_units": 0,
		"dmg_hp_sum": 0,
		"heal_hp_sum": 0,
	}
	if field == null or caster == null or def == null:
		return out
	var center: Vector2i = field.get_grid_pos(caster)
	var r: int = maxi(0, int(def.self_radius))
	var mag: int = int(def.self_magic_damage_to_hostiles)
	var heal_amt: int = int(def.self_heal_allies)
	for cell: Vector2i in _tiles_within_manhattan(center, r):
		var u: Node2D = _unit_at_cell(field, cell)
		if u == null or u == caster or int(u.current_hp) <= 0:
			continue
		if mag > 0 and targets_align_with_hostile_flag(field, caster, u, true):
			var est: int = maxi(1, mag - int(u.resistance) / 3)
			out["dmg_units"] = int(out["dmg_units"]) + 1
			out["dmg_hp_sum"] = int(out["dmg_hp_sum"]) + mini(est, int(u.current_hp))
		if heal_amt > 0 and targets_align_with_hostile_flag(field, caster, u, false):
			var miss: int = int(u.max_hp) - int(u.current_hp)
			if miss > 0:
				out["heal_units"] = int(out["heal_units"]) + 1
				out["heal_hp_sum"] = int(out["heal_hp_sum"]) + mini(heal_amt, miss)
	return out


static func _ai_accept_self_centered(field, caster: Node2D, def: ActiveCombatAbilityData, intel: int, beh: int) -> bool:
	var v: Dictionary = _self_centered_total_value(field, caster, def)
	var du: int = int(v["dmg_units"])
	var hu: int = int(v["heal_units"])
	var dsum: int = int(v["dmg_hp_sum"])
	var hsum: int = int(v["heal_hp_sum"])
	var mag: int = int(def.self_magic_damage_to_hostiles)
	var heal_cfg: int = int(def.self_heal_allies)

	if mag <= 0 and heal_cfg <= 0:
		return false
	if du <= 0 and hsum <= 0:
		return false

	var dmg_score: int = dsum + du * 2
	var heal_score: int = hsum + hu * 3

	if beh == AI_BEH_AGGRESSIVE:
		dmg_score += 6
	elif beh == AI_BEH_COWARD:
		dmg_score -= 4
		heal_score += 6
	elif beh == AI_BEH_SUPPORT:
		heal_score += 8
	elif beh == AI_BEH_MINION:
		dmg_score += 4
		heal_score += 3

	if intel <= 1:
		if mag > 0 and du >= 2 and dsum >= 6:
			return true
		if heal_cfg > 0 and hu >= 1 and hsum >= maxi(4, heal_cfg / 2):
			return true
		return false

	if intel == 2:
		if mag > 0 and dmg_score >= 10:
			return true
		if heal_cfg > 0 and heal_score >= 9:
			return true
		return false

	if mag > 0 and dmg_score >= 16 and du >= 2:
		return true
	if heal_cfg > 0 and heal_score >= 14:
		return true
	if mag > 0 and heal_cfg > 0 and dmg_score >= 8 and heal_score >= 6:
		return true
	return false


## Player forecast: first ready targeted ability that can hit this defender (hidden when co-op guest delegates combat to host).
static func find_best_forecast_targeted_active(field, attacker: Node2D, defender: Node2D):
	if attacker == null or defender == null:
		return null
	if field.has_method("coop_enet_should_delegate_player_combat_to_host") and field.coop_enet_should_delegate_player_combat_to_host():
		return null
	var best = null
	var best_score: int = -1
	for item in ActiveCombatAbilityHelpers.collect_definitions(attacker):
		if not item is ActiveCombatAbilityData:
			continue
		var def: ActiveCombatAbilityData = item as ActiveCombatAbilityData
		if int(def.effect_kind) != int(ActiveCombatAbilityData.EffectKind.TARGETED_SCRIPT):
			continue
		if not can_use_targeted(field, attacker, defender, def):
			continue
		var score: int = int(def.magic_damage) + int(def.physical_damage) + int(def.heal_amount)
		if score > best_score:
			best_score = score
			best = def
	return best


static func ai_choose_targeted_active(field, unit: Node2D, target: Node2D, target_type: String):
	if unit == null or target == null:
		return null
	var want_hostile: bool = (target_type == "hostile")
	var ib: Vector2i = _ai_read_intel_behavior(unit)
	var intel: int = ib.x
	var beh: int = ib.y

	var ranked: Array = []
	for item in ActiveCombatAbilityHelpers.collect_definitions(unit):
		if not item is ActiveCombatAbilityData:
			continue
		var def: ActiveCombatAbilityData = item as ActiveCombatAbilityData
		if int(def.effect_kind) != int(ActiveCombatAbilityData.EffectKind.TARGETED_SCRIPT):
			continue
		if def.target_hostile != want_hostile:
			continue
		if want_hostile and int(def.magic_damage) + int(def.physical_damage) <= 0:
			continue
		if not want_hostile and int(def.heal_amount) <= 0:
			continue
		if not can_use_targeted(field, unit, target, def):
			continue
		var score: int = int(def.magic_damage) + int(def.physical_damage) + int(def.heal_amount)
		if want_hostile and int(target.current_hp) > 0:
			var est_raw: int = int(def.magic_damage) + int(def.physical_damage)
			if est_raw >= int(target.current_hp):
				score += 50
			var est_mit: int = _estimate_targeted_ability_damage_on_target(def, target)
			if est_mit >= int(target.current_hp):
				score += 22
		if str(def.apply_combat_status_id).strip_edges() != "":
			score += 8
		ranked.append({"def": def, "score": score})

	ranked.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))

	for entry in ranked:
		var def2: ActiveCombatAbilityData = entry["def"] as ActiveCombatAbilityData
		if want_hostile:
			if _ai_accept_targeted_hostile(unit, target, def2, intel, beh):
				return def2
		else:
			if _ai_accept_targeted_ally_heal(target, def2, intel, beh):
				return def2
	return null


static func ai_choose_self_centered_active(field, unit: Node2D):
	if unit == null:
		return null
	var ib: Vector2i = _ai_read_intel_behavior(unit)
	var intel: int = ib.x
	var beh: int = ib.y

	var ranked: Array = []
	for item in ActiveCombatAbilityHelpers.collect_definitions(unit):
		if not item is ActiveCombatAbilityData:
			continue
		var def: ActiveCombatAbilityData = item as ActiveCombatAbilityData
		if int(def.effect_kind) != int(ActiveCombatAbilityData.EffectKind.SELF_CENTERED):
			continue
		if not can_use_self_centered(field, unit, def):
			continue
		var v: Dictionary = _self_centered_total_value(field, unit, def)
		var score: int = int(def.self_magic_damage_to_hostiles) + int(def.self_heal_allies)
		score += int(v["dmg_hp_sum"]) / 3
		score += int(v["heal_hp_sum"]) / 2
		ranked.append({"def": def, "score": score})

	ranked.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))

	for entry in ranked:
		var def2: ActiveCombatAbilityData = entry["def"] as ActiveCombatAbilityData
		if _ai_accept_self_centered(field, unit, def2, intel, beh):
			return def2
	return null


static func _deal_magic_burst(field, caster: Node2D, victim: Node2D, base: int) -> void:
	if base <= 0 or victim == null:
		return
	var mitigated: int = maxi(1, base - int(victim.resistance) / 3)
	victim.take_damage(mitigated, caster)
	field.spawn_loot_text(str(mitigated), Color(0.55, 0.75, 1.0), victim.global_position + Vector2(28, -28))


static func _deal_phys_burst(field, caster: Node2D, victim: Node2D, base: int) -> void:
	if base <= 0 or victim == null:
		return
	var mitigated: int = maxi(1, base - int(victim.defense) / 3)
	victim.take_damage(mitigated, caster)
	field.spawn_loot_text(str(mitigated), Color.ORANGE, victim.global_position + Vector2(28, -28))


static func _apply_heal(field, caster: Node2D, target: Node2D, amt: int) -> void:
	if amt <= 0 or target == null:
		return
	var mh: int = int(target.max_hp)
	target.current_hp = mini(mh, int(target.current_hp) + amt)
	if target.get("health_bar") != null:
		target.health_bar.value = target.current_hp
	field.spawn_loot_text("+%d" % amt, Color(0.5, 1.0, 0.55), target.global_position + Vector2(26, -32))
	field.add_combat_log(caster.unit_name + " restores " + str(amt) + " HP to " + target.unit_name + ".", "lightgreen")


static func _apply_status(field, target: Node2D, status_id: String) -> void:
	var sid: String = status_id.strip_edges()
	if sid == "" or target.get("combat_statuses") == null:
		return
	UnitCombatStatusHelpers.add_status(target, sid, {})
	field.add_combat_log(target.unit_name + " gains " + sid + ".", "violet")


static func _apply_targeted_effects(field, caster: Node2D, target: Node2D, def: ActiveCombatAbilityData) -> void:
	if int(def.magic_damage) > 0:
		_deal_magic_burst(field, caster, target, int(def.magic_damage))
	if int(def.physical_damage) > 0:
		_deal_phys_burst(field, caster, target, int(def.physical_damage))
	if int(def.heal_amount) > 0:
		_apply_heal(field, caster, target, int(def.heal_amount))
	_apply_status(field, target, def.apply_combat_status_id)


static func _tiles_within_manhattan(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r: int = maxi(0, radius)
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if absi(dx) + absi(dy) <= r:
				out.append(center + Vector2i(dx, dy))
	return out


static func _unit_at_cell(field, cell: Vector2i) -> Node2D:
	var u: Node2D = field.get_unit_at(cell)
	if u != null:
		return u
	if field.enemy_container:
		for c in field.enemy_container.get_children():
			if c is Node2D and field.get_grid_pos(c as Node2D) == cell:
				return c as Node2D
	if field.player_container:
		for c in field.player_container.get_children():
			if c is Node2D and field.get_grid_pos(c as Node2D) == cell:
				return c as Node2D
	if field.ally_container:
		for c in field.ally_container.get_children():
			if c is Node2D and field.get_grid_pos(c as Node2D) == cell:
				return c as Node2D
	return null


static func _apply_self_centered_effects(field, caster: Node2D, def: ActiveCombatAbilityData) -> void:
	var center: Vector2i = field.get_grid_pos(caster)
	var seen: Dictionary = {}
	for cell: Vector2i in _tiles_within_manhattan(center, int(def.self_radius)):
		var u: Node2D = _unit_at_cell(field, cell)
		if u == null or u == caster or int(u.current_hp) <= 0:
			continue
		var uid: int = u.get_instance_id()
		if seen.has(uid):
			continue
		seen[uid] = true
		if int(def.self_magic_damage_to_hostiles) > 0 and targets_align_with_hostile_flag(field, caster, u, true):
			_deal_magic_burst(field, caster, u, int(def.self_magic_damage_to_hostiles))
		if int(def.self_heal_allies) > 0 and targets_align_with_hostile_flag(field, caster, u, false):
			_apply_heal(field, caster, u, int(def.self_heal_allies))


static func execute_async(field, caster: Node2D, primary_target: Node2D, def: ActiveCombatAbilityData) -> bool:
	if field == null or caster == null or def == null:
		return false
	var kind: int = int(def.effect_kind)
	if kind == int(ActiveCombatAbilityData.EffectKind.TARGETED_SCRIPT):
		if primary_target == null or not can_use_targeted(field, caster, primary_target, def):
			return false
	elif kind == int(ActiveCombatAbilityData.EffectKind.SELF_CENTERED):
		if not can_use_self_centered(field, caster, def):
			return false
	else:
		return false

	var face_cell: Vector2i = field.get_grid_pos(caster)
	if primary_target != null and is_instance_valid(primary_target):
		face_cell = field.get_grid_pos(primary_target)
	caster.look_at_pos(face_cell)
	await field.get_tree().create_timer(0.28).timeout
	if not is_instance_valid(field) or not is_instance_valid(caster):
		return false

	if kind == int(ActiveCombatAbilityData.EffectKind.TARGETED_SCRIPT):
		_apply_targeted_effects(field, caster, primary_target, def)
		var dn: String = str(def.display_name).strip_edges()
		field.add_combat_log(caster.unit_name + " uses " + (dn if dn != "" else str(def.ability_id)) + "!", "gold")
	elif kind == int(ActiveCombatAbilityData.EffectKind.SELF_CENTERED):
		_apply_self_centered_effects(field, caster, def)
		var dn2: String = str(def.display_name).strip_edges()
		field.add_combat_log(caster.unit_name + " unleashes " + (dn2 if dn2 != "" else str(def.ability_id)) + "!", "gold")

	ActiveCombatAbilityHelpers.put_on_cooldown(caster, def.ability_id)
	field.ability_triggers_count = int(field.ability_triggers_count) + 1
	field.rebuild_grid()
	field.update_fog_of_war()
	return true
