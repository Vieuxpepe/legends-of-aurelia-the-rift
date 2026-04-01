extends RefCounted

## Runtime co-op battlefield glue: wire snapshots, enemy-phase setup sync, loot capture/apply, grid solidity around mirror units, relationship-id lookup, remote combat replay orchestration, post-authoritative outcome checks.


static func capture_enemy_death_loot_for_sync(field, source_unit: Node2D, total_gold: int, items: Array, recipient: Node2D) -> void:
	if not field._coop_combat_loot_capture_active:
		return
	if total_gold <= 0 and items.is_empty():
		return
	var entry: Dictionary = {"gold": total_gold}
	if source_unit != null and is_instance_valid(source_unit):
		var gp: Vector2i = field.get_grid_pos(source_unit)
		entry["gx"] = gp.x
		entry["gy"] = gp.y
		var source_id: String = field._get_mock_coop_command_id(source_unit)
		if source_id != "":
			entry["source_id"] = source_id
	if recipient != null and is_instance_valid(recipient):
		var recipient_id: String = field._get_mock_coop_command_id(recipient)
		if recipient_id != "":
			entry["recipient_id"] = recipient_id
	if not items.is_empty():
		entry["items"] = field._coop_wire_serialize_items(items)
	field._coop_combat_loot_capture_events.append(entry)


static func apply_remote_synced_enemy_death_loot_events(field, raw: Variant) -> void:
	if typeof(raw) != TYPE_ARRAY:
		return
	var combined_items: Array = []
	var recipient_id: String = ""
	for event_raw in raw as Array:
		if not (event_raw is Dictionary):
			continue
		var event: Dictionary = event_raw as Dictionary
		var gold_amount: int = int(event.get("gold", 0))
		if gold_amount > 0:
			var world_pos := Vector2.ZERO
			if event.has("gx") and event.has("gy"):
				world_pos = Vector2(int(event.get("gx", 0)) * field.CELL_SIZE.x, int(event.get("gy", 0)) * field.CELL_SIZE.y)
			field.animate_flying_gold(world_pos, gold_amount)
			if field.battle_log != null and field.battle_log.visible:
				field.add_combat_log("Found " + str(gold_amount) + " gold.", "yellow")
		var items: Array = field._coop_wire_deserialize_items(event.get("items", []))
		if not items.is_empty():
			combined_items.append_array(items)
			if recipient_id == "":
				recipient_id = str(event.get("recipient_id", "")).strip_edges()
	if combined_items.is_empty():
		return
	var recipient: Node2D = null
	if recipient_id != "":
		recipient = find_player_side_unit_by_relationship_id(field, recipient_id)
	field.pending_loot.clear()
	field.pending_loot.append_array(combined_items)
	field.loot_recipient = recipient
	field.show_loot_window()


static func build_runtime_unit_wire_snapshot(field, unit: Node2D) -> Dictionary:
	if unit == null or not is_instance_valid(unit) or unit.is_queued_for_deletion():
		return {}
	var unit_id: String = field._get_mock_coop_command_id(unit)
	if unit_id == "":
		return {}
	var gp: Vector2i = field.get_grid_pos(unit)
	var entry: Dictionary = {
		"id": unit_id,
		"gx": gp.x,
		"gy": gp.y,
		"visible": true,
		"modulate": [1.0, 1.0, 1.0, 1.0],
	}
	var scene_path: String = str(unit.get("scene_file_path")).strip_edges()
	if scene_path == "":
		if unit.get_parent() == field.enemy_container and field.enemy_scene != null:
			scene_path = str(field.enemy_scene.resource_path).strip_edges()
		elif field.player_unit_scene != null:
			scene_path = str(field.player_unit_scene.resource_path).strip_edges()
	if scene_path != "":
		entry["scene_path"] = scene_path
	var data_res: Resource = unit.get("data") as Resource
	var data_path: String = field._coop_wire_resource_path(data_res)
	if data_path != "":
		entry["data_path"] = data_path
	var class_res: Resource = unit.get("active_class_data") as Resource
	var class_path: String = field._coop_wire_resource_path(class_res)
	if class_path != "":
		entry["class_data"] = class_path
	var portrait_res: Resource = unit.get("portrait") as Resource
	var portrait_path: String = field._coop_wire_resource_path(portrait_res)
	if portrait_path != "":
		entry["portrait"] = portrait_path
	var sprite_res: Resource = unit.get("battle_sprite") as Resource
	var sprite_path: String = field._coop_wire_resource_path(sprite_res)
	if sprite_path != "":
		entry["battle_sprite"] = sprite_path
	if unit.get("unit_name") != null:
		entry["unit_name"] = str(unit.get("unit_name"))
	if unit.get("unit_class_name") != null:
		entry["unit_class_name"] = str(unit.get("unit_class_name"))
	if unit.get("team") != null:
		entry["team"] = int(unit.get("team"))
	if unit.get("is_enemy") != null:
		entry["is_enemy"] = bool(unit.get("is_enemy"))
	if unit.get("is_custom_avatar") != null:
		entry["is_custom_avatar"] = bool(unit.get("is_custom_avatar"))
	for key in ["level", "experience", "max_hp", "current_hp", "strength", "magic", "defense", "resistance", "speed", "agility", "move_range", "skill_points", "ai_intelligence", "experience_reward"]:
		var val: Variant = unit.get(key)
		if val != null:
			entry[key] = int(val)
	for key in ["has_moved", "is_exhausted", "is_defending"]:
		var flag_val: Variant = unit.get(key)
		if flag_val != null:
			entry[key] = bool(flag_val)
	if unit.get("move_points_used_this_turn") != null:
		entry["move_points_used_this_turn"] = float(unit.get("move_points_used_this_turn"))
	if unit.get("move_type") != null:
		entry["move_type"] = unit.get("move_type")
	if unit.get("ability") != null:
		entry["ability"] = unit.get("ability")
	var unit_tags_raw: Variant = unit.get("unit_tags")
	if unit_tags_raw is Array:
		entry["unit_tags"] = (unit_tags_raw as Array).duplicate(true)
	for list_key in ["traits", "rookie_legacies", "base_class_legacies", "promoted_class_legacies", "unlocked_skills"]:
		var list_raw: Variant = unit.get(list_key)
		if list_raw is Array:
			entry[list_key] = (list_raw as Array).duplicate(true)
	var inv_raw: Variant = unit.get("inventory")
	if inv_raw is Array:
		entry["inventory"] = field._coop_wire_serialize_items(inv_raw as Array)
	var eq_raw: Resource = unit.get("equipped_weapon") as Resource
	var eq_ser: Variant = field._coop_wire_serialize_item_single(eq_raw)
	if typeof(eq_ser) == TYPE_DICTIONARY and not (eq_ser as Dictionary).is_empty():
		entry["equipped_weapon"] = eq_ser
	elif eq_ser is String and str(eq_ser).strip_edges() != "":
		entry["equipped_weapon"] = eq_ser
	if unit is CanvasItem:
		var ci: CanvasItem = unit as CanvasItem
		entry["visible"] = ci.visible
		entry["modulate"] = [ci.modulate.r, ci.modulate.g, ci.modulate.b, ci.modulate.a]
	return entry


static func instantiate_runtime_unit_from_snapshot(field, entry: Dictionary, target_parent: Node) -> Node2D:
	if target_parent == null:
		return null
	var scene_path: String = str(entry.get("scene_path", "")).strip_edges()
	var packed: PackedScene = null
	if scene_path != "":
		var loaded_scene: Resource = load(scene_path)
		if loaded_scene is PackedScene:
			packed = loaded_scene as PackedScene
	if packed == null:
		if target_parent == field.enemy_container and field.enemy_scene != null:
			packed = field.enemy_scene
		elif field.player_unit_scene != null:
			packed = field.player_unit_scene
	if packed == null:
		if OS.is_debug_build():
			push_warning("Coop enemy phase setup: failed to load unit scene for '%s'" % str(entry.get("id", "")))
		return null
	var unit: Node2D = packed.instantiate() as Node2D
	if unit == null:
		return null
	var unit_id: String = str(entry.get("id", "")).strip_edges()
	if unit_id != "":
		unit.set_meta(field.MOCK_COOP_COMMAND_ID_META, unit_id)
	var data_path: String = str(entry.get("data_path", "")).strip_edges()
	if data_path != "":
		var data_loaded: Resource = load(data_path) as Resource
		if data_loaded != null and unit.get("data") != null:
			unit.set("data", data_loaded.duplicate(true))
			var data_copy: Resource = unit.get("data") as Resource
			if data_copy != null and data_path != "":
				data_copy.set_meta("original_path", data_path)
	target_parent.add_child(unit)
	if unit.has_signal("died") and not unit.died.is_connected(field._on_unit_died):
		unit.died.connect(field._on_unit_died)
	if unit.has_signal("leveled_up") and not unit.leveled_up.is_connected(field._on_unit_leveled_up):
		unit.leveled_up.connect(field._on_unit_leveled_up)
	return unit


static func apply_runtime_unit_wire_snapshot(field, entry: Dictionary, target_parent: Node) -> Node2D:
	var unit_id: String = str(entry.get("id", "")).strip_edges()
	if unit_id == "":
		return null
	var unit: Node2D = find_unit_by_relationship_id_any_side(field, unit_id)
	if unit == null or not is_instance_valid(unit) or unit.is_queued_for_deletion():
		unit = instantiate_runtime_unit_from_snapshot(field, entry, target_parent)
	if unit == null or not is_instance_valid(unit):
		return null
	var gx: int = int(entry.get("gx", field.get_grid_pos(unit).x))
	var gy: int = int(entry.get("gy", field.get_grid_pos(unit).y))
	unit.position = Vector2(gx * field.CELL_SIZE.x, gy * field.CELL_SIZE.y)
	for key in ["unit_name", "unit_class_name", "move_type", "ability"]:
		if entry.has(key):
			unit.set(key, entry[key])
	for key in ["team", "level", "experience", "max_hp", "current_hp", "strength", "magic", "defense", "resistance", "speed", "agility", "move_range", "skill_points", "ai_intelligence", "experience_reward"]:
		if entry.has(key):
			unit.set(key, int(entry[key]))
	for key in ["has_moved", "is_exhausted", "is_defending"]:
		if entry.has(key) and unit.get(key) != null:
			unit.set(key, bool(entry[key]))
	if entry.has("move_points_used_this_turn") and unit.get("move_points_used_this_turn") != null:
		unit.set("move_points_used_this_turn", float(entry["move_points_used_this_turn"]))
	if entry.has("is_enemy") and unit.get("is_enemy") != null:
		unit.set("is_enemy", bool(entry["is_enemy"]))
	if entry.has("is_custom_avatar") and unit.get("is_custom_avatar") != null:
		unit.set("is_custom_avatar", bool(entry["is_custom_avatar"]))
	if entry.has("class_data") and unit.get("active_class_data") != null:
		var class_loaded: Resource = load(str(entry["class_data"])) as Resource
		if class_loaded != null:
			unit.set("active_class_data", class_loaded)
	if entry.has("portrait") and unit.get("portrait") != null:
		var portrait_loaded: Resource = load(str(entry["portrait"])) as Resource
		if portrait_loaded != null:
			unit.set("portrait", portrait_loaded)
	if entry.has("battle_sprite") and unit.get("battle_sprite") != null:
		var sprite_loaded: Resource = load(str(entry["battle_sprite"])) as Resource
		if sprite_loaded != null:
			unit.set("battle_sprite", sprite_loaded)
	if entry.has("traits") and unit.get("traits") != null:
		unit.set("traits", (entry["traits"] as Array).duplicate(true))
	if entry.has("rookie_legacies") and unit.get("rookie_legacies") != null:
		unit.set("rookie_legacies", (entry["rookie_legacies"] as Array).duplicate(true))
	if entry.has("base_class_legacies") and unit.get("base_class_legacies") != null:
		unit.set("base_class_legacies", (entry["base_class_legacies"] as Array).duplicate(true))
	if entry.has("promoted_class_legacies") and unit.get("promoted_class_legacies") != null:
		unit.set("promoted_class_legacies", (entry["promoted_class_legacies"] as Array).duplicate(true))
	if entry.has("unlocked_skills") and unit.get("unlocked_skills") != null:
		unit.set("unlocked_skills", (entry["unlocked_skills"] as Array).duplicate(true))
	if entry.has("unit_tags") and unit.get("unit_tags") != null:
		unit.set("unit_tags", (entry["unit_tags"] as Array).duplicate(true))
	if entry.has("inventory") and unit.get("inventory") != null:
		var inv_items: Array = field._coop_wire_deserialize_items(entry["inventory"])
		unit.inventory.clear()
		unit.inventory.append_array(inv_items)
	if entry.has("equipped_weapon") and unit.get("equipped_weapon") != null:
		var eq_loaded: Resource = field._coop_wire_deserialize_item_single(entry["equipped_weapon"])
		if eq_loaded != null:
			unit.set("equipped_weapon", eq_loaded)
	if unit.get("health_bar") != null:
		unit.health_bar.value = unit.current_hp
	if unit is CanvasItem:
		var ci: CanvasItem = unit as CanvasItem
		ci.visible = bool(entry.get("visible", true))
		var mod_raw: Variant = entry.get("modulate", [])
		if mod_raw is Array and (mod_raw as Array).size() >= 4:
			var mod_arr: Array = mod_raw as Array
			ci.modulate = Color(float(mod_arr[0]), float(mod_arr[1]), float(mod_arr[2]), float(mod_arr[3]))
	return unit


static func build_enemy_phase_setup_snapshot(field) -> Dictionary:
	var enemy_units: Array = []
	if field.enemy_container != null:
		for child in field.enemy_container.get_children():
			if not child is Node2D:
				continue
			var enemy: Node2D = child as Node2D
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
				continue
			var unit_snap: Dictionary = build_runtime_unit_wire_snapshot(field, enemy)
			if not unit_snap.is_empty():
				enemy_units.append(unit_snap)
	var spawners: Array = []
	if field.destructibles_container != null:
		for child in field.destructibles_container.get_children():
			if not child is Node2D:
				continue
			var node: Node2D = child as Node2D
			if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.has_method("process_turn"):
				continue
			var spawner_id: String = field._get_mock_coop_command_id(node)
			if spawner_id == "":
				continue
			var entry: Dictionary = {"id": spawner_id}
			var script_res: Script = node.get_script() as Script
			if script_res != null and str(script_res.resource_path).strip_edges() != "":
				entry["script_path"] = str(script_res.resource_path).strip_edges()
			if node.get("has_warned") != null:
				entry["has_warned"] = bool(node.get("has_warned"))
			if node.get("has_triggered") != null:
				entry["has_triggered"] = bool(node.get("has_triggered"))
			var slot_timers_raw: Variant = node.get("slot_timers")
			if slot_timers_raw is Array:
				entry["slot_timers"] = (slot_timers_raw as Array).duplicate(true)
			if node is CanvasItem:
				var ci: CanvasItem = node as CanvasItem
				entry["visible"] = ci.visible
				entry["alpha"] = ci.modulate.a
			var script_path: String = str(entry.get("script_path", "")).strip_edges()
			if bool(entry.get("has_triggered", false)) and script_path.ends_with("AmbushSpawner.gd"):
				entry["remove_on_guest"] = true
			spawners.append(entry)
	return {
		"v": field.COOP_ENEMY_PHASE_SETUP_SNAPSHOT_VER,
		"enemy_units": enemy_units,
		"spawners": spawners,
	}


static func apply_enemy_phase_setup_snapshot(field, snap: Dictionary) -> void:
	if int(snap.get("v", 0)) != field.COOP_ENEMY_PHASE_SETUP_SNAPSHOT_VER:
		if OS.is_debug_build():
			push_warning("Coop enemy phase setup: reject snapshot (bad v).")
		return
	for raw_unit in snap.get("enemy_units", []):
		if not raw_unit is Dictionary:
			continue
		apply_runtime_unit_wire_snapshot(field, raw_unit as Dictionary, field.enemy_container)
	var live_spawner_ids: Dictionary = {}
	for raw_spawner in snap.get("spawners", []):
		if not raw_spawner is Dictionary:
			continue
		var entry: Dictionary = raw_spawner as Dictionary
		var sid: String = str(entry.get("id", "")).strip_edges()
		if sid == "":
			continue
		live_spawner_ids[sid] = true
		var node: Node2D = find_unit_by_relationship_id_any_side(field, sid)
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if entry.has("slot_timers") and node.get("slot_timers") != null:
			node.set("slot_timers", (entry["slot_timers"] as Array).duplicate(true))
		if entry.has("has_warned") and node.get("has_warned") != null:
			node.set("has_warned", bool(entry["has_warned"]))
		if entry.has("has_triggered") and node.get("has_triggered") != null:
			node.set("has_triggered", bool(entry["has_triggered"]))
		if node is CanvasItem:
			var ci: CanvasItem = node as CanvasItem
			if entry.has("visible"):
				ci.visible = bool(entry["visible"])
			if entry.has("alpha"):
				var mod: Color = ci.modulate
				mod.a = float(entry["alpha"])
				ci.modulate = mod
		if node.has_method("queue_redraw"):
			node.call("queue_redraw")
		if bool(entry.get("remove_on_guest", false)):
			node.queue_free()
	for child in field.destructibles_container.get_children():
		if not child is Node2D:
			continue
		var node: Node2D = child as Node2D
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.has_method("process_turn"):
			continue
		var sid: String = field._get_mock_coop_command_id(node)
		if sid != "" and not live_spawner_ids.has(sid):
			node.queue_free()
	field.rebuild_grid()
	field.update_fog_of_war()
	field.update_objective_ui()


static func snapshot_alive_unit_ids(field) -> Dictionary:
	var d: Dictionary = {}
	for cont in [field.player_container, field.ally_container, field.enemy_container]:
		if cont == null:
			continue
		for c in cont.get_children():
			if not c is Node2D:
				continue
			var u: Node2D = c as Node2D
			if not is_instance_valid(u) or u.is_queued_for_deletion():
				continue
			var rid: String = field._get_mock_coop_command_id(u)
			if rid == "":
				continue
			d[rid] = true
	return d


static func clear_unit_grid_solidity(field, u: Node2D) -> void:
	if u == null or not is_instance_valid(u):
		return
	if u.has_method("get_occupied_tiles"):
		for t in u.get_occupied_tiles(field):
			field.astar.set_point_solid(t, false)
	else:
		field.astar.set_point_solid(field.get_grid_pos(u), false)


static func set_unit_grid_solidity(field, u: Node2D, solid: bool) -> void:
	if u == null or not is_instance_valid(u):
		return
	if u.has_method("get_occupied_tiles"):
		for t in u.get_occupied_tiles(field):
			field.astar.set_point_solid(t, solid)
	else:
		field.astar.set_point_solid(field.get_grid_pos(u), solid)


static func remove_unit_coop_peer_mirror_by_id(field, rid: String) -> void:
	var r: String = str(rid).strip_edges()
	if r == "":
		return
	var u: Node2D = find_unit_by_relationship_id_any_side(field, r)
	if u == null or not is_instance_valid(u) or u.is_queued_for_deletion():
		return
	clear_unit_grid_solidity(field, u)
	u.queue_free()


static func execute_remote_combat_replay(field, attacker: Node2D, defender: Node2D, used_ability: bool, qte_snapshot: Variant, rng_packed: int = -1) -> void:
	if attacker == null or defender == null:
		return
	field._coop_remote_combat_replay_active = true
	field.coop_net_apply_remote_combat_qte_snapshot(qte_snapshot)
	if rng_packed >= 0:
		field.coop_enet_apply_remote_combat_packed_id(rng_packed)
	await field.execute_combat(attacker, defender, used_ability)
	field.coop_net_clear_remote_combat_qte_snapshot()
	field._coop_remote_combat_replay_active = false


static func validate_authoritative_post_combat_outcome(field) -> void:
	if field.player_container != null:
		for p in field.player_container.get_children():
			if not is_instance_valid(p) or p.is_queued_for_deletion():
				continue
			if p.get("is_custom_avatar") == true and int(p.get("current_hp")) <= 0:
				field.add_combat_log("The Leader has fallen! All is lost...", "red")
				field.trigger_game_over("DEFEAT")
				return
		var living_players: int = 0
		for p in field.player_container.get_children():
			if not is_instance_valid(p) or p.is_queued_for_deletion():
				continue
			if int(p.get("current_hp")) > 0:
				living_players += 1
		if living_players <= 0:
			field.add_combat_log("MISSION FAILED: Entire party wiped out.", "red")
			field.trigger_game_over("DEFEAT")
			return
	# Same ordinals as BattleField.Objective: ROUT_ENEMY=0, SURVIVE_TURNS=1, DEFEND_TARGET=2
	var mobj: int = int(field.map_objective)
	if mobj == 0:
		if field._count_alive_enemies() == 0 and field._count_active_enemy_spawners() == 0:
			field.add_combat_log("MISSION ACCOMPLISHED: All enemies routed.", "lime")
			field._trigger_victory()
			return
	elif mobj == 2:
		if field.vip_target != null and is_instance_valid(field.vip_target) and int(field.vip_target.get("current_hp")) <= 0:
			field.add_combat_log("MISSION FAILED: VIP Target was killed.", "red")
			field.trigger_game_over("DEFEAT")
			return


static func find_player_side_unit_by_relationship_id(field, rid: String) -> Node2D:
	var r: String = str(rid).strip_edges()
	if r == "":
		return null
	for cont in [field.player_container, field.ally_container]:
		if cont == null:
			continue
		for u in cont.get_children():
			if not is_instance_valid(u):
				continue
			if field._get_mock_coop_command_id(u) == r:
				return u as Node2D
	return null


static func find_unit_by_relationship_id_any_side(field, rid: String) -> Node2D:
	var u: Node2D = find_player_side_unit_by_relationship_id(field, rid)
	if u != null:
		return u
	var r: String = str(rid).strip_edges()
	if r == "":
		return null
	for cont in [field.enemy_container, field.destructibles_container, field.chests_container]:
		if cont == null:
			continue
		for e in cont.get_children():
			if not is_instance_valid(e):
				continue
			if field._get_mock_coop_command_id(e) == r:
				return e as Node2D
	return null


static func wait_for_enemy_state_ready(field) -> void:
	while field.is_inside_tree() and field.current_state != field.enemy_state:
		await field.get_tree().process_frame
