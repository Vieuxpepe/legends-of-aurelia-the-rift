extends RefCounted

## Runtime + wire helpers for [ActiveCombatAbilityData]. Assign abilities on [member UnitData.active_combat_abilities]; state on [member Unit.active_ability_cooldowns].


static func collect_definitions(unit: Node) -> Array:
	var out: Array = []
	if unit == null or unit.get("data") == null:
		return out
	var d: Variant = unit.data
	if d == null or not d is Resource:
		return out
	var raw: Variant = (d as Resource).get("active_combat_abilities")
	if raw is Array:
		for item in raw:
			if item is ActiveCombatAbilityData:
				out.append(item)
	return out


static func get_definition(unit: Node, ability_id: String) -> ActiveCombatAbilityData:
	var id: String = ability_id.strip_edges()
	if id == "":
		return null
	for def_variant in collect_definitions(unit):
		var def: ActiveCombatAbilityData = def_variant as ActiveCombatAbilityData
		if str(def.ability_id).strip_edges() == id:
			return def
	return null


## Ensures [member Unit.active_ability_cooldowns] has one entry per authored ability; preserves existing remainders for known ids.
static func bootstrap_unit(unit: Node) -> void:
	if unit == null:
		return
	var defs: Array = collect_definitions(unit)
	if defs.is_empty():
		if unit.get("active_ability_cooldowns") != null:
			unit.active_ability_cooldowns.clear()
		return
	var prior: Dictionary = {}
	if unit.get("active_ability_cooldowns") is Dictionary:
		prior = (unit.active_ability_cooldowns as Dictionary).duplicate()
	var next: Dictionary = {}
	for def_variant in defs:
		var def: ActiveCombatAbilityData = def_variant as ActiveCombatAbilityData
		var aid: String = str(def.ability_id).strip_edges()
		if aid == "":
			continue
		var initial: int = 0 if def.starts_ready else maxi(0, int(def.cooldown_turns))
		if prior.has(aid):
			next[aid] = maxi(0, int(prior[aid]))
		else:
			next[aid] = initial
	unit.active_ability_cooldowns = next


static func get_turns_remaining(unit: Node, ability_id: String) -> int:
	if unit == null or unit.get("active_ability_cooldowns") == null:
		return 999
	var aid: String = ability_id.strip_edges()
	if aid == "":
		return 999
	var d: Dictionary = unit.active_ability_cooldowns
	if not d.has(aid):
		return 999
	return maxi(0, int(d[aid]))


static func is_ready(unit: Node, ability_id: String) -> bool:
	if get_definition(unit, ability_id) == null:
		return false
	return get_turns_remaining(unit, ability_id) <= 0


## If ready, applies full cooldown from data and returns true. Otherwise returns false.
static func try_begin_cooldown_after_use(unit: Node, ability_id: String) -> bool:
	var def: ActiveCombatAbilityData = get_definition(unit, ability_id)
	if def == null:
		return false
	if not is_ready(unit, ability_id):
		return false
	var aid: String = str(def.ability_id).strip_edges()
	var cd: int = maxi(0, int(def.cooldown_turns))
	if unit.get("active_ability_cooldowns") == null:
		unit.active_ability_cooldowns = {}
	(unit.active_ability_cooldowns as Dictionary)[aid] = cd
	return true


static func put_on_cooldown(unit: Node, ability_id: String) -> void:
	var def: ActiveCombatAbilityData = get_definition(unit, ability_id)
	if def == null:
		return
	var aid: String = str(def.ability_id).strip_edges()
	if aid == "":
		return
	if unit.get("active_ability_cooldowns") == null:
		unit.active_ability_cooldowns = {}
	(unit.active_ability_cooldowns as Dictionary)[aid] = maxi(0, int(def.cooldown_turns))


static func tick_unit(unit: Node) -> void:
	if unit == null or unit.get("active_ability_cooldowns") == null:
		return
	var d: Dictionary = unit.active_ability_cooldowns
	for k in d.keys():
		var v: int = maxi(0, int(d[k]))
		if v > 0:
			d[k] = v - 1


static func tick_all_units_phase(field) -> void:
	if field == null:
		return
	for cont in [field.player_container, field.ally_container, field.enemy_container]:
		if cont == null:
			continue
		for c in cont.get_children():
			if not c is Node2D:
				continue
			var u: Node2D = c as Node2D
			if not is_instance_valid(u) or u.is_queued_for_deletion():
				continue
			if u.get("current_hp") != null and int(u.current_hp) <= 0:
				continue
			tick_unit(u)


static func export_wire(unit: Node) -> Array:
	var out: Array = []
	if unit == null or unit.get("active_ability_cooldowns") == null:
		return out
	var d: Dictionary = unit.active_ability_cooldowns
	for k in d.keys():
		out.append({"id": str(k), "cd": maxi(0, int(d[k]))})
	return out


static func import_wire(unit: Node, raw: Variant) -> void:
	bootstrap_unit(unit)
	if unit == null or unit.get("active_ability_cooldowns") == null:
		return
	if raw == null or not raw is Array:
		return
	var d: Dictionary = unit.active_ability_cooldowns
	for item in raw as Array:
		if not item is Dictionary:
			continue
		var e: Dictionary = item as Dictionary
		var id: String = str(e.get("id", "")).strip_edges()
		if id == "":
			continue
		if d.has(id):
			d[id] = maxi(0, int(e.get("cd", 0)))
