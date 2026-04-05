extends RefCounted

const CombatStatusRegistry = preload("res://Scripts/Core/CombatStatusRegistry.gd")

## Serializable battle status entries on [Unit]. Wire keys use short names for co-op snapshots.
## Each entry: { "id": String, optional "stacks": int, "xr": bool } — [code]xr[/code]: mirrors [member CombatStatusData.expires_next_activation] when applied.
## Register new ids in [code]res://Resources/CombatStatuses/*.tres[/code]; [CombatStatusRegistry] loads them at runtime.

const ID_BURNING := "burning"
const ID_MAP01_SCORCHED := "map01_scorched"
const ID_BONE_TOXIN := "bone_toxin"
const ID_POISON := "poison"
const ID_RESOLVE := "resolve"

const RESOLVE_HIT_BONUS := 8
const RESOLVE_AVO_BONUS := 5
const RESOLVE_MIGHT_BONUS := 2

const META_LEGACY_BURNING := "is_burning"
const META_LEGACY_SCORCHED := "map01_scorched"


static func export_wire(unit: Node) -> Array:
	var out: Array = []
	if unit == null or unit.get("combat_statuses") == null:
		return out
	for e in unit.combat_statuses:
		if e is Dictionary:
			var d: Dictionary = (e as Dictionary).duplicate(true)
			var id: String = str(d.get("id", "")).strip_edges()
			if id == "":
				continue
			out.append(d)
	return out


static func import_wire(unit: Node, raw: Variant) -> void:
	if unit == null or unit.get("combat_statuses") == null:
		return
	var arr: Array = unit.combat_statuses
	arr.clear()
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				var d: Dictionary = (item as Dictionary).duplicate(true)
				var id: String = str(d.get("id", "")).strip_edges()
				if id == "":
					continue
				arr.append(d)
	CombatStatusRegistry.ensure_loaded()
	for e in arr:
		if not (e is Dictionary):
			continue
		var ed: Dictionary = e as Dictionary
		var sid: String = str(ed.get("id", "")).strip_edges()
		if sid == "":
			continue
		if not ed.has("xr"):
			var sdef: CombatStatusData = CombatStatusRegistry.get_optional(sid)
			ed["xr"] = sdef.expires_next_activation if sdef != null else false
	sync_legacy_metas(unit)
	_notify_unit_combat_status_visuals(unit)


static func clear_all(unit: Node) -> void:
	if unit == null or unit.get("combat_statuses") == null:
		return
	unit.combat_statuses.clear()
	sync_legacy_metas(unit)
	_notify_unit_combat_status_visuals(unit)


## Status mutations from helpers (not [method Unit.add_combat_status]) must refresh debuff icons / tints.
static func _notify_unit_combat_status_visuals(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if unit.has_method("refresh_combat_status_sprite_tint"):
		unit.call_deferred("refresh_combat_status_sprite_tint")


static func has_status(unit: Node, status_id: String) -> bool:
	if unit == null or unit.get("combat_statuses") == null:
		return false
	for e in unit.combat_statuses:
		if e is Dictionary and str((e as Dictionary).get("id", "")) == status_id:
			return true
	return false


static func resolve_combat_hit_bonus(unit: Node) -> int:
	if has_status(unit, ID_RESOLVE):
		return RESOLVE_HIT_BONUS
	return 0


static func resolve_combat_avo_bonus(unit: Node) -> int:
	if has_status(unit, ID_RESOLVE):
		return RESOLVE_AVO_BONUS
	return 0


static func resolve_combat_might_bonus(unit: Node) -> int:
	if has_status(unit, ID_RESOLVE):
		return RESOLVE_MIGHT_BONUS
	return 0


static func _stack_cap(status_id: String) -> int:
	CombatStatusRegistry.ensure_loaded()
	var d: CombatStatusData = CombatStatusRegistry.get_optional(status_id)
	if d == null or d.stack_cap <= 0:
		return 999
	return maxi(1, d.stack_cap)


static func add_status(unit: Node, status_id: String, opts: Dictionary = {}) -> void:
	if unit == null or unit.get("combat_statuses") == null:
		return
	CombatStatusRegistry.ensure_loaded()
	var def: CombatStatusData = CombatStatusRegistry.get_optional(status_id)
	var cap: int = _stack_cap(status_id)
	var arr: Array = unit.combat_statuses
	for e in arr:
		if e is Dictionary and str((e as Dictionary).get("id", "")) == status_id:
			var ed: Dictionary = e as Dictionary
			for k in opts.keys():
				ed[k] = opts[k]
			if opts.has("xr"):
				ed["xr"] = opts["xr"]
			elif not ed.has("xr") and def != null:
				ed["xr"] = def.expires_next_activation
			ed["stacks"] = mini(cap, maxi(1, int(ed.get("stacks", 1))))
			sync_legacy_metas(unit)
			_notify_unit_combat_status_visuals(unit)
			return
	var neu: Dictionary = {"id": status_id}
	for k in opts.keys():
		neu[k] = opts[k]
	if not neu.has("xr"):
		neu["xr"] = def.expires_next_activation if def != null else false
	if not neu.has("stacks"):
		neu["stacks"] = 1
	neu["stacks"] = mini(cap, maxi(1, int(neu["stacks"])))
	arr.append(neu)
	sync_legacy_metas(unit)
	_notify_unit_combat_status_visuals(unit)


static func remove_status(unit: Node, status_id: String) -> void:
	if unit == null or unit.get("combat_statuses") == null:
		return
	var arr: Array = unit.combat_statuses
	for i in range(arr.size() - 1, -1, -1):
		var e: Variant = arr[i]
		if e is Dictionary and str((e as Dictionary).get("id", "")) == status_id:
			arr.remove_at(i)
	sync_legacy_metas(unit)
	_notify_unit_combat_status_visuals(unit)


static func _should_expire_at_turn_start(entry: Dictionary) -> bool:
	if entry.get("xr") == true:
		return true
	var sid: String = str(entry.get("id", "")).strip_edges()
	var d: CombatStatusData = CombatStatusRegistry.get_optional(sid)
	return d != null and d.expires_next_activation


## Removes entries that expire when the unit’s next activation begins ([method Unit.reset_turn]).
static func expire_turn_start_statuses(unit: Node) -> void:
	if unit == null or unit.get("combat_statuses") == null:
		return
	CombatStatusRegistry.ensure_loaded()
	var arr: Array = unit.combat_statuses
	for i in range(arr.size() - 1, -1, -1):
		var e: Variant = arr[i]
		if e is Dictionary and _should_expire_at_turn_start(e as Dictionary):
			arr.remove_at(i)
	sync_legacy_metas(unit)
	_notify_unit_combat_status_visuals(unit)


static func sync_legacy_metas(unit: Node) -> void:
	if unit == null:
		return
	if has_status(unit, ID_BURNING):
		unit.set_meta(META_LEGACY_BURNING, true)
	elif unit.has_meta(META_LEGACY_BURNING):
		unit.remove_meta(META_LEGACY_BURNING)

	if has_status(unit, ID_MAP01_SCORCHED):
		unit.set_meta(META_LEGACY_SCORCHED, true)
	elif unit.has_meta(META_LEGACY_SCORCHED):
		unit.remove_meta(META_LEGACY_SCORCHED)


## Prefer status list; treat legacy metas as present if list missing entry (import from old snapshots).
static func unit_is_burning(unit: Node) -> bool:
	if unit == null:
		return false
	if has_status(unit, ID_BURNING):
		return true
	return unit.has_meta(META_LEGACY_BURNING) and unit.get_meta(META_LEGACY_BURNING) == true


static func decrement_bone_toxin_stack(unit: Node) -> void:
	if unit == null or unit.get("combat_statuses") == null:
		return
	var arr: Array = unit.combat_statuses
	for i in range(arr.size() - 1, -1, -1):
		var e: Variant = arr[i]
		if not (e is Dictionary):
			continue
		var ed: Dictionary = e as Dictionary
		if str(ed.get("id", "")) != ID_BONE_TOXIN:
			continue
		var st: int = maxi(1, int(ed.get("stacks", 1))) - 1
		if st <= 0:
			arr.remove_at(i)
		else:
			ed["stacks"] = st
	sync_legacy_metas(unit)
	_notify_unit_combat_status_visuals(unit)


static func unit_is_map01_scorched(unit: Node) -> bool:
	if unit == null:
		return false
	if has_status(unit, ID_MAP01_SCORCHED):
		return true
	return unit.has_meta(META_LEGACY_SCORCHED) and unit.get_meta(META_LEGACY_SCORCHED) == true


static func promote_legacy_metas_to_status_list(unit: Node) -> void:
	if unit == null or unit.get("combat_statuses") == null:
		return
	if unit.has_meta(META_LEGACY_BURNING) and unit.get_meta(META_LEGACY_BURNING) == true and not has_status(unit, ID_BURNING):
		add_status(unit, ID_BURNING, {})
	if unit.has_meta(META_LEGACY_SCORCHED) and unit.get_meta(META_LEGACY_SCORCHED) == true and not has_status(unit, ID_MAP01_SCORCHED):
		add_status(unit, ID_MAP01_SCORCHED, {})


## Human-readable tooltip/status-list lines for tactical hover popups.
static func build_plain_lines(unit: Node) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if unit == null or unit.get("combat_statuses") == null:
		return out
	CombatStatusRegistry.ensure_loaded()
	promote_legacy_metas_to_status_list(unit)
	for e in unit.combat_statuses:
		if not (e is Dictionary):
			continue
		var d: Dictionary = e as Dictionary
		var id: String = str(d.get("id", "")).strip_edges()
		if id == "":
			continue
		var label: String = CombatStatusRegistry.get_display_name(id)
		var stacks: int = maxi(1, int(d.get("stacks", 1)))
		if stacks > 1:
			label += " x" + str(stacks)
		if _should_expire_at_turn_start(d):
			label += " (expires next turn)"
		out.append(label)
		var sdef: CombatStatusData = CombatStatusRegistry.get_optional(id)
		if sdef != null and str(sdef.description).strip_edges() != "":
			out.append("  " + str(sdef.description).strip_edges())
	return out


## Grouped hover-tooltip lines for tactical battlefield popup columns.
## Returns a dictionary with keys [code]buffs[/code] and [code]debuffs[/code], each a [PackedStringArray].
static func build_plain_groups(unit: Node, include_descriptions: bool = false) -> Dictionary:
	var grouped: Dictionary = {}
	var buffs: PackedStringArray = PackedStringArray()
	var debuffs: PackedStringArray = PackedStringArray()
	if unit == null or unit.get("combat_statuses") == null:
		grouped["buffs"] = buffs
		grouped["debuffs"] = debuffs
		return grouped
	CombatStatusRegistry.ensure_loaded()
	promote_legacy_metas_to_status_list(unit)
	for e in unit.combat_statuses:
		if not (e is Dictionary):
			continue
		var d: Dictionary = e as Dictionary
		var id: String = str(d.get("id", "")).strip_edges()
		if id == "":
			continue
		var sdef: CombatStatusData = CombatStatusRegistry.get_optional(id)
		var label: String = CombatStatusRegistry.get_display_name(id)
		var stacks: int = maxi(1, int(d.get("stacks", 1)))
		if stacks > 1:
			label += " x" + str(stacks)
		if _should_expire_at_turn_start(d):
			label += " (expires next turn)"
		if _status_group_for_hover(id, d, sdef) == "buff":
			buffs.append(label)
			if include_descriptions and sdef != null and str(sdef.description).strip_edges() != "":
				buffs.append("  " + str(sdef.description).strip_edges())
		else:
			debuffs.append(label)
			if include_descriptions and sdef != null and str(sdef.description).strip_edges() != "":
				debuffs.append("  " + str(sdef.description).strip_edges())
	grouped["buffs"] = buffs
	grouped["debuffs"] = debuffs
	return grouped


static func _status_group_for_hover(status_id: String, entry: Dictionary, sdef: CombatStatusData) -> String:
	var from_entry: String = str(entry.get("hover_group", "")).strip_edges().to_lower()
	if from_entry == "buff" or from_entry == "debuff":
		return from_entry
	if sdef != null:
		var from_def: String = str(sdef.hover_group).strip_edges().to_lower()
		if from_def == "buff" or from_def == "debuff":
			return from_def
	if status_id == ID_BURNING or status_id == ID_MAP01_SCORCHED or status_id == ID_BONE_TOXIN:
		return "debuff"
	return "debuff"


## Rich-text badges for the tactical unit strip ([method Unit.get_active_combat_status_bbcode_badges]).
static func build_bbcode_badges(unit: Node) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if unit == null or unit.get("combat_statuses") == null:
		return out
	CombatStatusRegistry.ensure_loaded()
	promote_legacy_metas_to_status_list(unit)
	for e in unit.combat_statuses:
		if not (e is Dictionary):
			continue
		var d: Dictionary = e as Dictionary
		var id: String = str(d.get("id", "")).strip_edges()
		if id == "":
			continue
		var sdef: CombatStatusData = CombatStatusRegistry.get_optional(id)
		var col: String = "silver"
		var tag: String = id.to_upper()
		if sdef != null:
			col = str(sdef.hud_bbcode_color).strip_edges()
			if col == "":
				col = "silver"
			var ht: String = str(sdef.hud_tag).strip_edges()
			tag = ht.to_upper() if ht != "" else CombatStatusRegistry.get_display_name(id).to_upper()
		out.append("[color=%s][b]%s[/b][/color]" % [col, tag])
	return out


## Lightweight change token so UI callers can skip rebuilding unchanged popups.
static func build_signature(unit: Node) -> String:
	if unit == null or unit.get("combat_statuses") == null:
		return ""
	promote_legacy_metas_to_status_list(unit)
	var parts: Array[String] = []
	for e in unit.combat_statuses:
		if not (e is Dictionary):
			continue
		var d: Dictionary = e as Dictionary
		var id: String = str(d.get("id", "")).strip_edges()
		if id == "":
			continue
		var stacks: int = maxi(1, int(d.get("stacks", 1)))
		var xr: bool = d.get("xr", false) == true
		parts.append("%s:%d:%d" % [id, stacks, 1 if xr else 0])
	return "|".join(parts)
