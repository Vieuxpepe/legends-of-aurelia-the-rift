extends RefCounted

# Skirmish / expedition / arena / VIP escort / base-defense siege branches invoked during battle bootstrap
# (after fog init). Includes full arena opponent spawn setup.


static func apply_special_modes_after_fog(field) -> void:
	if CampaignManager.is_skirmish_mode and not CampaignManager.is_expedition_run:
		field.setup_skirmish_battle()
		field._reset_rookie_battle_tracking()

	if CampaignManager.is_expedition_run:
		var exp_mod_line: String = CampaignManager.get_active_expedition_modifier_display_line()
		if exp_mod_line != "":
			field.add_combat_log(exp_mod_line, "cyan")

	if ArenaManager.current_opponent_data.size() > 0:
		field.is_arena_match = true
		setup_arena_battle(field)
		field._reset_rookie_battle_tracking()

	if field.map_objective == BattleField.Objective.DEFEND_TARGET and is_instance_valid(field.vip_target):
		if field.vip_target.has_signal("reached_destination"):
			field.vip_target.reached_destination.connect(func():
				if field.has_method("add_combat_log"):
					field.add_combat_log("MISSION ACCOMPLISHED: The convoy escaped!", "lime")
				if field._battle_resonance_allowed():
					CampaignManager.mark_battle_resonance("protected_civilians_first")
				field._coop_pending_escort_destination_victory = true
			)

	if CampaignManager.is_base_defense_active:
		print("--- INITIALIZING DATA-DRIVEN SIEGE ---")
		field.map_objective = BattleField.Objective.ROUT_ENEMY
		field.custom_objective_text = "Survive the Siege"

		field.intro_dialogue.clear()
		field.outro_dialogue.clear()

		if is_instance_valid(field.vip_target) and not field.vip_target.is_queued_for_deletion():
			field.vip_target.queue_free()
			field.vip_target = null

		if field.skirmish_music != null and field.has_node("LevelMusic"):
			var audio = field.get_node("LevelMusic")
			audio.stream = field.skirmish_music
			audio.play()

		for child in field.enemy_container.get_children():
			child.queue_free()

		if field.destructibles_container != null:
			for d in field.destructibles_container.get_children():
				if d.has_method("process_turn") and d.get("spawner_faction") == 0:
					d.queue_free()

		var max_roster_level = CampaignManager.get_highest_garrison_level()

		var chosen_data_path = "res://Resources/Units/LowLevelBandit.tres"

		if max_roster_level >= 12:
			chosen_data_path = "res://Resources/Units/HulkingOrc.tres"
		elif max_roster_level >= 10:
			chosen_data_path = "res://Resources/Units/EtherealImp.tres"
		elif max_roster_level >= 5:
			chosen_data_path = "res://Resources/Units/ArmoredMercenary.tres"

		var loaded_unit_data = load(chosen_data_path)
		if loaded_unit_data == null:
			push_warning("Siege unit data path invalid. Check your .tres file locations.")
			return

		var edge_tiles = []
		for x in range(field.GRID_SIZE.x):
			edge_tiles.append(Vector2i(x, 0))
			edge_tiles.append(Vector2i(x, field.GRID_SIZE.y - 1))
		for y in range(1, field.GRID_SIZE.y - 1):
			edge_tiles.append(Vector2i(0, y))
			edge_tiles.append(Vector2i(field.GRID_SIZE.x - 1, y))

		edge_tiles.shuffle()

		var spawn_count = randi_range(6, 9)
		var spawned = 0

		for pos in edge_tiles:
			if spawned >= spawn_count:
				break

			if not field.astar.is_point_solid(pos) and field.get_unit_at(pos) == null:

				if field.player_unit_scene == null:
					push_warning("CRITICAL: player_unit_scene is not assigned in the Inspector.")
					return

				var enemy = field.player_unit_scene.instantiate()

				if "team" in enemy:
					enemy.team = 1
				if "is_enemy" in enemy:
					enemy.is_enemy = true

				enemy.position = Vector2(pos.x * field.CELL_SIZE.x, pos.y * field.CELL_SIZE.y)
				field.enemy_container.add_child(enemy)

				if not enemy.died.is_connected(field._on_unit_died):
					enemy.died.connect(field._on_unit_died)
				if not enemy.leveled_up.is_connected(field._on_unit_leveled_up):
					enemy.leveled_up.connect(field._on_unit_leveled_up)

				enemy.data = loaded_unit_data.duplicate(true)
				enemy.level = max_roster_level
				enemy.unit_name = enemy.data.get("unit_name") if enemy.data.get("unit_name") != null else "Raider"
				enemy.set("is_custom_avatar", false)

				var base_hp = enemy.data.get("max_hp") if enemy.data.get("max_hp") != null else 20
				var base_str = enemy.data.get("strength") if enemy.data.get("strength") != null else 5
				var base_def = enemy.data.get("defense") if enemy.data.get("defense") != null else 3
				var base_spd = enemy.data.get("speed") if enemy.data.get("speed") != null else 4

				enemy.max_hp = base_hp + (max_roster_level * 2)
				enemy.current_hp = enemy.max_hp
				enemy.strength = base_str + int(max_roster_level * 0.8)
				enemy.defense = base_def + int(max_roster_level * 0.5)
				enemy.speed = base_spd + int(max_roster_level * 0.5)

				if enemy.get("health_bar") != null:
					enemy.health_bar.max_value = enemy.max_hp
					enemy.health_bar.value = enemy.current_hp

				var spr = enemy.get_node_or_null("Sprite")
				if spr == null:
					spr = enemy.get_node_or_null("Sprite2D")
				if spr and enemy.data.get("unit_sprite") != null:
					spr.texture = enemy.data.unit_sprite

				var strict_inventory: Array[Resource] = []

				if enemy.data.get("starting_weapon") != null:
					enemy.equipped_weapon = enemy.data.starting_weapon.duplicate(true)
					strict_inventory.append(enemy.equipped_weapon)
				else:
					var wpn = WeaponData.new()
					wpn.weapon_name = "Siege Blade"
					wpn.might = 5 + int(max_roster_level * 0.5)
					wpn.hit_bonus = 10
					wpn.min_range = 1
					wpn.max_range = 1
					enemy.equipped_weapon = wpn
					strict_inventory.append(wpn)

				enemy.inventory = strict_inventory

				enemy.ai_behavior = 2
				spawned += 1


static func setup_arena_battle(field) -> void:
	print("--- INITIALIZING MULTIVERSE ARENA ---")
	var opp_data = ArenaManager.current_opponent_data

	for child in field.enemy_container.get_children():
		child.queue_free()

	var meta = opp_data.get("metadata", {})
	var roster = meta.get("roster", [])
	var dragons = meta.get("dragons", [])

	var valid_spawn_points = []
	for x in range(int(field.GRID_SIZE.x / 2.0), field.GRID_SIZE.x):
		for y in range(field.GRID_SIZE.y):
			var pos = Vector2i(x, y)
			if not field.astar.is_point_solid(pos) and field.get_unit_at(pos) == null:
				valid_spawn_points.append(pos)

	valid_spawn_points.shuffle()
	var spawn_index = 0

	for unit_dict in roster:
		if spawn_index >= valid_spawn_points.size():
			break

		var ghost = field.player_unit_scene.instantiate()
		ghost.is_arena_ghost = true
		field.enemy_container.add_child(ghost)

		ghost.died.connect(field._on_unit_died)
		ghost.leveled_up.connect(field._on_unit_leveled_up)

		if "team" in ghost:
			ghost.team = 1
		if "is_enemy" in ghost:
			ghost.is_enemy = true

		var grid_pos = valid_spawn_points[spawn_index]
		ghost.position = Vector2(grid_pos.x * field.CELL_SIZE.x, grid_pos.y * field.CELL_SIZE.y)

		ghost.unit_name = unit_dict.get("unit_name", "Gladiator")
		ghost.unit_class_name = unit_dict.get("class", "Mercenary")
		ghost.level = unit_dict.get("level", 1)
		ghost.max_hp = unit_dict.get("max_hp", 20)
		ghost.current_hp = ghost.max_hp
		ghost.strength = unit_dict.get("strength", 5)
		ghost.magic = unit_dict.get("magic", 0)
		ghost.defense = unit_dict.get("defense", 3)
		ghost.resistance = unit_dict.get("resistance", 1)
		ghost.speed = unit_dict.get("speed", 4)
		ghost.agility = unit_dict.get("agility", 3)
		ghost.move_range = unit_dict.get("move_range", 4)
		ghost.ability = unit_dict.get("ability", "None")

		var dummy_wpn = WeaponData.new()
		dummy_wpn.weapon_name = unit_dict.get("equipped_weapon_name", "Ghost Blade")
		dummy_wpn.might = 5
		dummy_wpn.hit_bonus = 10
		dummy_wpn.min_range = 1
		dummy_wpn.max_range = 1
		ghost.equipped_weapon = dummy_wpn

		if ghost.data == null:
			ghost.data = UnitData.new()

		var s_path = unit_dict.get("sprite_path", "")
		var p_path = unit_dict.get("portrait_path", "")

		if s_path != "" and ResourceLoader.exists(s_path):
			var sprite_node = ghost.get_node_or_null("Sprite")
			if sprite_node == null:
				sprite_node = ghost.get_node_or_null("Sprite2D")
			if sprite_node:
				sprite_node.texture = load(s_path)

		if p_path != "" and ResourceLoader.exists(p_path):
			ghost.data.portrait = load(p_path)

		ghost.base_color = Color(1.0, 0.7, 0.7)
		ghost.modulate = ghost.base_color

		if ghost.has_method("setup_ghost_ui"):
			ghost.setup_ghost_ui()

		spawn_index += 1

	for d_dict in dragons:
		if spawn_index >= valid_spawn_points.size():
			break

		var ghost_dragon = field.player_unit_scene.instantiate()
		ghost_dragon.is_arena_ghost = true
		field.enemy_container.add_child(ghost_dragon)

		ghost_dragon.died.connect(field._on_unit_died)
		ghost_dragon.leveled_up.connect(field._on_unit_leveled_up)

		if "team" in ghost_dragon:
			ghost_dragon.team = 1
		if "is_enemy" in ghost_dragon:
			ghost_dragon.is_enemy = true

		var grid_pos_dragon = valid_spawn_points[spawn_index]
		ghost_dragon.position = Vector2(grid_pos_dragon.x * field.CELL_SIZE.x, grid_pos_dragon.y * field.CELL_SIZE.y)

		ghost_dragon.unit_name = d_dict.get("name", "Dragon")
		ghost_dragon.unit_class_name = d_dict.get("element", "Fire") + " Dragon"
		ghost_dragon.max_hp = d_dict.get("max_hp", 25)
		ghost_dragon.current_hp = ghost_dragon.max_hp
		ghost_dragon.strength = d_dict.get("strength", 8)
		ghost_dragon.magic = d_dict.get("magic", 8)
		ghost_dragon.defense = d_dict.get("defense", 5)
		ghost_dragon.resistance = d_dict.get("resistance", 4)
		ghost_dragon.speed = d_dict.get("speed", 5)
		ghost_dragon.agility = d_dict.get("agility", 4)
		ghost_dragon.move_range = 5
		ghost_dragon.set_meta("is_dragon", true)

		var fang = WeaponData.new()
		fang.weapon_name = "Ghost Fang"
		fang.might = 6
		fang.min_range = 1
		fang.max_range = 1
		ghost_dragon.equipped_weapon = fang

		if ghost_dragon.data == null:
			ghost_dragon.data = UnitData.new()

		var elem = d_dict.get("element", "Fire").to_lower()
		var d_path = "res://Assets/Sprites/" + elem + "_dragon_sprite.png"
		if ResourceLoader.exists(d_path):
			var sprite_node = ghost_dragon.get_node_or_null("Sprite")
			if sprite_node == null:
				sprite_node = ghost_dragon.get_node_or_null("Sprite2D")
			if sprite_node:
				sprite_node.texture = load(d_path)

		ghost_dragon.base_color = Color(1.0, 0.7, 0.7)
		ghost_dragon.modulate = ghost_dragon.base_color

		if ghost_dragon.has_method("setup_ghost_ui"):
			ghost_dragon.setup_ghost_ui()

		spawn_index += 1
