extends RefCounted

const UnitCombatStatusHelpers = preload("res://Scripts/Core/UnitCombatStatusHelpers.gd")
const ActiveCombatAbilityHelpers = preload("res://Scripts/Core/BattleField/ActiveCombatAbilityHelpers.gd")

# Helper functions for the co-op / authoritative-combat snapshot bridge.
# These are extracted from `Scripts/Core/BattleField.gd` to reduce monolith risk.

static func coop_wire_serialize_items(field, items: Array) -> Array:
	var out: Array = []
	for item in items:
		if not (item is Resource):
			continue
		var entry: Dictionary = {}
		if CampaignManager != null and CampaignManager.has_method("_serialize_item"):
			entry = CampaignManager._serialize_item(item as Resource)
		if entry.is_empty():
			var res: Resource = item as Resource
			var path: String = res.resource_path
			if path == "" and res.has_meta("original_path"):
				path = str(res.get_meta("original_path", "")).strip_edges()
			if path != "":
				entry = {"path": path}
				# Fallback parity: preserve rune primitives when CampaignManager serializer is unavailable.
				if res is WeaponData:
					var w: WeaponData = res as WeaponData
					entry["rune_slot_count"] = clampi(int(w.rune_slot_count), 0, 8)
					var sockets_raw: Variant = w.socketed_runes
					var sockets: Array = sockets_raw as Array if sockets_raw is Array else []
					var out_rows: Array = []
					var cap: int = int(entry["rune_slot_count"])
					for row in sockets:
						if out_rows.size() >= cap:
							break
						if not (row is Dictionary):
							continue
						var d: Dictionary = row as Dictionary
						var rid: String = str(d.get("id", "")).strip_edges()
						if rid == "":
							continue
						var out_row: Dictionary = {"id": rid, "rank": clampi(int(d.get("rank", 0)), 0, 999)}
						if d.has("charges"):
							out_row["charges"] = clampi(int(d.get("charges", 0)), 0, 999999)
						out_rows.append(out_row)
					entry["socketed_runes"] = out_rows
		if not entry.is_empty():
			out.append(entry)
	return out


static func coop_wire_deserialize_items(field, raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for item_data in raw as Array:
		var inst: Resource = null
		if item_data is Dictionary:
			var d: Dictionary = item_data as Dictionary
			if CampaignManager != null and CampaignManager.has_method("_deserialize_item"):
				inst = CampaignManager._deserialize_item(d)
			else:
				var p: String = str(d.get("path", "")).strip_edges()
				if p != "" and ResourceLoader.exists(p):
					var loaded: Resource = load(p) as Resource
					if loaded != null:
						inst = loaded.duplicate(true)
						# Fallback parity: apply rune primitives in correct order.
						if inst is WeaponData:
							var w: WeaponData = inst as WeaponData
							if d.has("rune_slot_count"):
								w.rune_slot_count = clampi(int(d.get("rune_slot_count", 0)), 0, 8)
							if d.has("socketed_runes") and d.get("socketed_runes") is Array:
								var cap: int = clampi(int(w.rune_slot_count), 0, 8)
								var out_rows: Array[Dictionary] = []
								for row in d.get("socketed_runes", []) as Array:
									if out_rows.size() >= cap:
										break
									if not (row is Dictionary):
										continue
									var rd: Dictionary = row as Dictionary
									var rid: String = str(rd.get("id", "")).strip_edges()
									if rid == "":
										continue
									var out_row: Dictionary = {"id": rid, "rank": clampi(int(rd.get("rank", 0)), 0, 999)}
									if rd.has("charges"):
										out_row["charges"] = clampi(int(rd.get("charges", 0)), 0, 999999)
									out_rows.append(out_row)
								w.socketed_runes = out_rows
		elif item_data is String:
			var loaded: Resource = load(str(item_data)) as Resource
			if loaded != null:
				inst = CampaignManager.duplicate_item(loaded) if CampaignManager != null else loaded.duplicate(true)
		if inst != null:
			out.append(inst)
	return out


static func coop_wire_resource_path(field, res: Resource) -> String:
	if res == null:
		return ""
	var path: String = str(res.resource_path).strip_edges()
	if path == "" and res.has_meta("original_path"):
		path = str(res.get_meta("original_path", "")).strip_edges()
	return path


static func coop_wire_serialize_item_single(field, item: Resource) -> Variant:
	if item == null:
		return {}
	var raw: Array = coop_wire_serialize_items(field, [item])
	if raw.is_empty():
		return {}
	return raw[0]


static func coop_wire_deserialize_item_single(field, raw: Variant) -> Resource:
	var wrapped: Array = [raw]
	var out: Array = coop_wire_deserialize_items(field, wrapped)
	if out.is_empty():
		return null
	return out[0] as Resource


static func coop_net_build_authoritative_combat_snapshot(field, pre_alive_ids: Dictionary) -> Dictionary:
	var post_alive: Dictionary = {}
	var units_arr: Array = []

	for cont in [field.player_container, field.ally_container, field.enemy_container]:
		if cont == null:
			continue
		for c in cont.get_children():
			if not c is Node2D:
				continue
			var u: Node2D = c as Node2D
			if not is_instance_valid(u) or u.is_queued_for_deletion():
				continue
			if int(u.get("current_hp")) <= 0:
				continue

			var rid: String = field._get_mock_coop_command_id(u)
			if rid == "":
				continue

			post_alive[rid] = true
			var gp: Vector2i = field.get_grid_pos(u)
			var e: Dictionary = {
				"id": rid,
				"hp": int(u.current_hp),
				"mhp": int(u.max_hp),
				"gx": gp.x,
				"gy": gp.y,
			}

			if u.get("strength") != null:
				e["str"] = int(u.strength)
			if u.get("magic") != null:
				e["mag"] = int(u.magic)
			if u.get("speed") != null:
				e["spd"] = int(u.speed)
			if u.get("agility") != null:
				e["agi"] = int(u.agility)
			if u.get("defense") != null:
				e["def"] = int(u.defense)
			if u.get("resistance") != null:
				e["res"] = int(u.resistance)

			var wpn = u.equipped_weapon
			if wpn != null and wpn.get("current_durability") != null:
				e["wpn_dur"] = int(wpn.current_durability)

			if u.has_meta("ability_cooldown"):
				e["abil_cd"] = int(u.get_meta("ability_cooldown"))
			if u.has_meta("current_poise"):
				e["poise"] = int(u.get_meta("current_poise"))
			if u.has_meta("is_staggered_this_combat"):
				e["stagger"] = bool(u.get_meta("is_staggered_this_combat"))
			if u.get("is_defending") != null:
				e["defending"] = bool(u.is_defending)

			e["cstat"] = UnitCombatStatusHelpers.export_wire(u)
			if ActiveCombatAbilityHelpers.collect_definitions(u).size() > 0:
				e["acd"] = ActiveCombatAbilityHelpers.export_wire(u)

			units_arr.append(e)

	var removed: Array = []
	for k in pre_alive_ids.keys():
		if not post_alive.has(k):
			removed.append(str(k))

	return {
		"v": field.COOP_AUTH_BATTLE_SNAPSHOT_VER,
		"units": units_arr,
		"removed_ids": removed,
		"gold": int(field.player_gold),
		"ek": int(field.enemy_kills_count),
		"pd": int(field.player_deaths_count),
		"ad": int(field.ally_deaths_count),
		"atc": int(field.ability_triggers_count),
	}


static func coop_apply_authoritative_combat_snapshot(field, snap: Dictionary) -> void:
	var snap_ver: int = int(snap.get("v", 0))
	if snap_ver != 1 and snap_ver != 2 and snap_ver != 3:
		if OS.is_debug_build():
			push_warning("Coop: reject authoritative combat snapshot (bad v).")
		return

	field.enemy_kills_count = int(snap.get("ek", field.enemy_kills_count))
	field.player_deaths_count = int(snap.get("pd", field.player_deaths_count))
	field.ally_deaths_count = int(snap.get("ad", field.ally_deaths_count))
	field.ability_triggers_count = int(snap.get("atc", field.ability_triggers_count))
	field.player_gold = int(snap.get("gold", field.player_gold))

	var removed: Array = snap.get("removed_ids", []) as Array
	for rid_v in removed:
		var rs: String = str(rid_v).strip_edges()
		if rs == "":
			continue
		field._coop_remove_unit_coop_peer_mirror_by_id(rs)

	for udat in snap.get("units", []):
		if not udat is Dictionary:
			continue
		var entry: Dictionary = udat
		var rid2: String = str(entry.get("id", "")).strip_edges()
		if rid2 == "":
			continue

		var u2: Node2D = field._coop_find_unit_by_relationship_id_any_side(rid2)
		if u2 == null or not is_instance_valid(u2) or u2.is_queued_for_deletion():
			continue

		var gx: int = int(entry.get("gx", field.get_grid_pos(u2).x))
		var gy: int = int(entry.get("gy", field.get_grid_pos(u2).y))
		var old_gp: Vector2i = field.get_grid_pos(u2)
		var new_gp := Vector2i(gx, gy)
		if old_gp != new_gp:
			field._coop_clear_unit_grid_solidity(u2)
			u2.position = Vector2(gx * field.CELL_SIZE.x, gy * field.CELL_SIZE.y)
			field._coop_set_unit_grid_solidity(u2, true)

		if entry.has("hp"):
			u2.current_hp = int(entry["hp"])
		if entry.has("mhp"):
			u2.max_hp = int(entry["mhp"])
		if entry.has("str") and u2.get("strength") != null:
			u2.strength = int(entry["str"])
		if entry.has("mag") and u2.get("magic") != null:
			u2.magic = int(entry["mag"])
		if entry.has("spd") and u2.get("speed") != null:
			u2.speed = int(entry["spd"])
		if entry.has("agi") and u2.get("agility") != null:
			u2.agility = int(entry["agi"])
		if entry.has("def") and u2.get("defense") != null:
			u2.defense = int(entry["def"])
		if entry.has("res") and u2.get("resistance") != null:
			u2.resistance = int(entry["res"])

		var wpn2 = u2.equipped_weapon
		if wpn2 != null and entry.has("wpn_dur") and wpn2.get("current_durability") != null:
			wpn2.current_durability = int(entry["wpn_dur"])

		if entry.has("abil_cd"):
			u2.set_meta("ability_cooldown", int(entry["abil_cd"]))
		elif u2.has_meta("ability_cooldown"):
			u2.remove_meta("ability_cooldown")

		if entry.has("poise"):
			u2.set_meta("current_poise", int(entry["poise"]))
		if entry.has("stagger"):
			u2.set_meta("is_staggered_this_combat", bool(entry["stagger"]))

		if entry.has("defending") and u2.get("is_defending") != null:
			u2.is_defending = bool(entry["defending"])

		if snap_ver >= 2:
			UnitCombatStatusHelpers.import_wire(u2, entry.get("cstat", []))

		if entry.has("acd"):
			ActiveCombatAbilityHelpers.import_wire(u2, entry["acd"])
		elif snap_ver >= 3:
			ActiveCombatAbilityHelpers.bootstrap_unit(u2)

		if u2.has_method("clear_remote_coop_pending_death_visual") and int(entry.get("hp", u2.current_hp)) > 0:
			u2.clear_remote_coop_pending_death_visual()

		if u2.get("health_bar") != null:
			u2.health_bar.value = u2.current_hp
		if u2.has_method("update_poise_visuals"):
			u2.update_poise_visuals()

	field.rebuild_grid()
	field.update_fog_of_war()
	field.update_objective_ui()
	field._coop_validate_authoritative_post_combat_outcome()

