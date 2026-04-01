extends RefCounted

static func _mark_dragon_weapon_flags(wpn: WeaponData) -> void:
	if wpn == null:
		return
	if WeaponData.is_dragon_weapon(wpn) or int(wpn.weapon_type) == WeaponData.WeaponType.NONE:
		wpn.dragon_only = true
		wpn.non_tradeable = true
		wpn.non_convoy = true


static func is_dragon_deployable_in_battle(dragon: Dictionary) -> bool:
	if not (dragon is Dictionary):
		return false
	return int(dragon.get("stage", 0)) >= 3


static func make_dragon_battle_entry(dragon: Dictionary) -> Dictionary:
	var stage: int = int(dragon.get("stage", 3))
	var element: String = str(dragon.get("element", "Fire"))
	var dragon_name: String = str(dragon.get("name", "Dragon"))
	var dragon_uid: String = str(dragon.get("uid", ""))

	var fang := WeaponData.new()
	fang.weapon_name = element + " Dragon Fang"
	fang.might = int(dragon.get("weapon_might", 8 + stage))
	fang.hit_bonus = int(dragon.get("weapon_hit_bonus", 10))
	fang.min_range = int(dragon.get("min_range", 1))
	fang.max_range = int(dragon.get("max_range", 1))
	_mark_dragon_weapon_flags(fang)

	var max_hp: int = int(dragon.get("max_hp", 30 + (stage * 4)))
	var current_hp: int = int(dragon.get("current_hp", max_hp))

	return {
		"unit_name": dragon_name,
		"unit_class": element + " Dragon",
		"level": int(dragon.get("level", 1)),
		"experience": int(dragon.get("experience", 0)),
		"max_hp": max_hp,
		"current_hp": current_hp,
		"strength": int(dragon.get("strength", 10 + stage)),
		"magic": int(dragon.get("magic", 8 + stage)),
		"defense": int(dragon.get("defense", 7 + stage)),
		"resistance": int(dragon.get("resistance", 6 + stage)),
		"speed": int(dragon.get("speed", 7 + stage)),
		"agility": int(dragon.get("agility", 6 + stage)),
		"move_range": int(dragon.get("move_range", 5)),
		"move_type": int(dragon.get("move_type", 2)),
		"equipped_weapon": fang,
		"inventory": [fang],
		"ability": str(dragon.get("ability", "")),
		"skill_points": 0,
		"unlocked_skills": [],
		"unlocked_abilities": [],
		"is_dragon": true,
		"dragon_uid": dragon_uid,
		"element": element,
		"stage": stage
	}


static func build_deployment_roster() -> Array:
	var roster: Array = CampaignManager.get_available_roster()

	for dragon in DragonManager.player_dragons:
		if is_dragon_deployable_in_battle(dragon):
			roster.append(make_dragon_battle_entry(dragon))

	return roster


static func build_deployment_roster_from_consumed_mock_coop_handoff(field) -> Array:
	if field._consumed_mock_coop_battle_handoff.is_empty():
		return []
	var snap_raw: Variant = field._consumed_mock_coop_battle_handoff.get("battle_roster_snapshot", null)
	if typeof(snap_raw) != TYPE_ARRAY:
		var launch_raw: Variant = field._consumed_mock_coop_battle_handoff.get("launch_snapshot", {})
		if typeof(launch_raw) == TYPE_DICTIONARY:
			snap_raw = (launch_raw as Dictionary).get("battle_roster_snapshot", [])
			if OS.is_debug_build() and typeof(snap_raw) == TYPE_ARRAY and not (snap_raw as Array).is_empty():
				push_warning("[MockCoopHandoff] using legacy launch_snapshot.battle_roster_snapshot fallback; promote snapshot to top-level handoff.")
	if typeof(snap_raw) != TYPE_ARRAY:
		if OS.is_debug_build():
			push_warning("[MockCoopHandoff] missing shared battle_roster_snapshot; falling back to local deployment roster.")
		return []
	var roster: Array = CampaignManager.hydrate_mock_coop_battle_roster_snapshot(snap_raw)
	if OS.is_debug_build() and not roster.is_empty():
		print("[MockCoopHandoff] using shared battle roster snapshot units=%d" % roster.size())
	return roster


static func load_campaign_data(field) -> void:
	field.player_gold = CampaignManager.global_gold
	field.player_inventory = CampaignManager.global_inventory.duplicate()
	field.update_gold_display()

	var roster: Array = build_deployment_roster_from_consumed_mock_coop_handoff(field)
	if roster.is_empty():
		roster = build_deployment_roster()

	if CampaignManager.is_base_defense_active:
		roster.clear()
		roster = CampaignManager.get_garrisoned_units()

		if roster.is_empty():
			print("WARNING: Base Defense started, but no garrison units were found!")

	if ArenaManager.current_opponent_data.size() > 0:
		roster = ArenaManager.local_arena_team

	if roster.is_empty():
		return

	var deployment_slots = []
	var zones_container = field.get_node_or_null("DeploymentZones")
	if zones_container:
		for marker in zones_container.get_children():
			var grid_x = int(marker.global_position.x / field.CELL_SIZE.x)
			var grid_y = int(marker.global_position.y / field.CELL_SIZE.y)
			var pos = Vector2i(grid_x, grid_y)

			if not deployment_slots.has(pos):
				deployment_slots.append(pos)

	if deployment_slots.is_empty():
		print("WARNING: No Marker2Ds found inside the 'DeploymentZones' node!")

	var max_to_deploy = min(6, deployment_slots.size())
	var _load_count = min(roster.size(), max_to_deploy)

	for child in field.player_container.get_children():
		child.queue_free()

	if field.player_unit_scene == null:
		print("ERROR: player_unit_scene is not assigned in the Inspector!")
		return

	for i in range(roster.size()):
		var saved = roster[i]

		var new_unit = field.player_unit_scene.instantiate()

		var saved_unit_name: String = str(saved.get("unit_name", "")).strip_edges()
		var avatar_name: String = str(CampaignManager.custom_avatar.get("name", "")).strip_edges()
		var avatar_unit_name: String = str(CampaignManager.custom_avatar.get("unit_name", "")).strip_edges()
		if bool(saved.get("is_custom_avatar", false)) or (saved_unit_name != "" and (saved_unit_name == avatar_name or saved_unit_name == avatar_unit_name)):
			new_unit.set("is_custom_avatar", true)
		else:
			new_unit.set("is_custom_avatar", false)
		var mock_coop_command_id: String = str(saved.get("mock_coop_command_id", "")).strip_edges()
		if mock_coop_command_id != "":
			new_unit.set_meta(field.MOCK_COOP_COMMAND_ID_META, mock_coop_command_id)
		elif new_unit.has_meta(field.MOCK_COOP_COMMAND_ID_META):
			new_unit.remove_meta(field.MOCK_COOP_COMMAND_ID_META)

		if saved.get("data") is Resource:
			var original_path = saved["data"].resource_path
			new_unit.data = saved["data"].duplicate()
			if original_path != "":
				new_unit.data.set_meta("original_path", original_path)

		field.player_container.add_child(new_unit)

		new_unit.died.connect(field._on_unit_died)
		new_unit.leveled_up.connect(field._on_unit_leveled_up)

		if i < max_to_deploy and i < deployment_slots.size():
			var slot_pos = deployment_slots[i]
			new_unit.position = Vector2(slot_pos.x * field.CELL_SIZE.x, slot_pos.y * field.CELL_SIZE.y)
			new_unit.visible = true
			new_unit.process_mode = Node.PROCESS_MODE_INHERIT
		else:
			new_unit.position = Vector2(-1000, -1000)
			new_unit.visible = false
			new_unit.process_mode = Node.PROCESS_MODE_DISABLED

		new_unit.unit_name = saved.get("unit_name", new_unit.unit_name)
		new_unit.unit_class_name = saved.get("unit_class", saved.get("class_name", new_unit.unit_class_name))
		new_unit.unit_tags = saved.get("unit_tags", [])
		new_unit.level = saved.get("level", 1)
		new_unit.experience = saved.get("experience", 0)
		new_unit.max_hp = saved.get("max_hp", 10)
		new_unit.current_hp = saved.get("current_hp", 10)
		new_unit.strength = saved.get("strength", 0)
		new_unit.magic = saved.get("magic", 0)
		new_unit.defense = saved.get("defense", 0)
		new_unit.resistance = saved.get("resistance", 0)
		new_unit.speed = saved.get("speed", 0)
		new_unit.agility = saved.get("agility", 0)

		if saved.has("move_type"): new_unit.set("move_type", saved["move_type"])
		if saved.has("move_range"): new_unit.move_range = saved["move_range"]
		if saved.has("class_data") and saved["class_data"] != null:
			new_unit.active_class_data = saved["class_data"]

		if saved.has("ability"): new_unit.ability = saved["ability"]
		if saved.has("traits") and new_unit.get("traits") != null:
			new_unit.traits = saved["traits"].duplicate()
		if saved.has("rookie_legacies") and new_unit.get("rookie_legacies") != null:
			new_unit.rookie_legacies = saved["rookie_legacies"].duplicate()
		if saved.has("base_class_legacies") and new_unit.get("base_class_legacies") != null:
			new_unit.base_class_legacies = saved["base_class_legacies"].duplicate()
		if saved.has("promoted_class_legacies") and new_unit.get("promoted_class_legacies") != null:
			new_unit.promoted_class_legacies = saved["promoted_class_legacies"].duplicate()

		if saved.has("skill_points"):
			new_unit.skill_points = saved["skill_points"]
		if saved.has("unlocked_skills"):
			new_unit.unlocked_skills = saved["unlocked_skills"].duplicate()

		if saved.has("inventory"):
			new_unit.inventory.clear()
			new_unit.inventory.append_array(saved["inventory"])

		if saved.has("equipped_weapon"):
			new_unit.equipped_weapon = saved["equipped_weapon"]

		if saved.has("is_promoted"):
			new_unit.set("is_promoted", saved["is_promoted"])
			if new_unit.get("is_promoted") == true and new_unit.has_method("apply_promotion_aura"):
				new_unit.apply_promotion_aura()

		var s_tex = saved.get("battle_sprite")
		var p_tex = saved.get("portrait")

		if saved.has("element") or saved.get("is_dragon") == true:
			new_unit.unit_name = saved.get("unit_name", saved.get("name", "Dragon"))
			new_unit.unit_class_name = saved.get("unit_class", saved.get("element", "Fire") + " Dragon")
			new_unit.set_meta("is_dragon", true)
			new_unit.set_meta("dragon_uid", str(saved.get("dragon_uid", saved.get("uid", ""))))

			if new_unit.data == null:
				new_unit.data = UnitData.new()

			if new_unit.equipped_weapon == null:
				var fang = WeaponData.new()
				fang.weapon_name = "Dragon Fang"
				fang.might = 6
				fang.min_range = 1
				fang.max_range = 1
				_mark_dragon_weapon_flags(fang)
				new_unit.equipped_weapon = fang
				new_unit.inventory = [fang]
			elif new_unit.equipped_weapon is WeaponData:
				_mark_dragon_weapon_flags(new_unit.equipped_weapon as WeaponData)
			for inv_item in new_unit.inventory:
				if inv_item is WeaponData:
					_mark_dragon_weapon_flags(inv_item as WeaponData)

			var elem = str(saved.get("element", "Fire")).to_lower()
			var d_path = "res://Assets/Sprites/" + elem + "_dragon_sprite.png"
			if ResourceLoader.exists(d_path):
				s_tex = load(d_path)

			var dp_path = "res://Assets/Portraits/" + elem + "_dragon_portrait.png"
			if ResourceLoader.exists(dp_path):
				p_tex = load(dp_path)

		var sprite_node = new_unit.get_node_or_null("Sprite")
		if sprite_node == null: sprite_node = new_unit.get_node_or_null("Sprite2D")
		if s_tex and sprite_node: sprite_node.texture = s_tex
		if p_tex and new_unit.data: new_unit.data.portrait = p_tex

		if new_unit.get("health_bar") != null:
			new_unit.health_bar.max_value = new_unit.max_hp
			new_unit.health_bar.value = new_unit.current_hp


static func setup_skirmish_battle(field) -> void:
	print("--- INITIALIZING UNDEAD SKIRMISH ---")

	if field.skirmish_music != null and field.has_node("LevelMusic"):
		field.get_node("LevelMusic").stream = field.skirmish_music
		field.get_node("LevelMusic").play()

	for child in field.enemy_container.get_children():
		child.queue_free()

	var scaling_level = CampaignManager.get_highest_roster_level()

	if field.enemy_scene == null:
		print("ERROR: No EnemyScene assigned in Battlefield Inspector!")
		return

	var spawn_count = randi_range(4, 6)
	var valid_spawn_points = []

	for x in range(5, field.GRID_SIZE.x):
		for y in range(field.GRID_SIZE.y):
			var pos = Vector2i(x, y)
			if not field.astar.is_point_solid(pos) and field.get_unit_at(pos) == null:
				valid_spawn_points.append(pos)

	valid_spawn_points.shuffle()

	for i in range(min(spawn_count, valid_spawn_points.size())):
		var grid_pos = valid_spawn_points[i]
		var enemy = field.enemy_scene.instantiate()

		enemy.position = Vector2(grid_pos.x * field.CELL_SIZE.x, grid_pos.y * field.CELL_SIZE.y)
		field.enemy_container.add_child(enemy)

		enemy.unit_name = "Risen Dead"
		enemy.modulate = Color(0.6, 0.8, 0.6)

		var _diff_mult = 1.0
		var intelligence_boost = 0
		if CampaignManager.current_difficulty == CampaignManager.Difficulty.HARD: _diff_mult = 1.2
		if CampaignManager.current_difficulty == CampaignManager.Difficulty.MADDENING: _diff_mult = 1.4

		enemy.level = scaling_level
		enemy.max_hp = 18 + (scaling_level * 2)
		enemy.current_hp = enemy.max_hp
		enemy.strength = 4 + int(scaling_level * 0.8)
		enemy.defense = 2 + int(scaling_level * 0.5)
		enemy.speed = 2 + int(scaling_level * 0.3)
		enemy.experience_reward = 30
		enemy.ai_intelligence += intelligence_boost


static func start_battle_from_deployment(field) -> void:
	if field.select_sound.stream != null: field.select_sound.play()
	field._defy_death_used.clear()
	field._grief_units.clear()
	field._relationship_event_awarded.clear()
	field._enemy_damagers.clear()
	field._boss_personal_dialogue_played.clear()
	field._reset_rookie_battle_tracking()
	field.change_state(field.player_state)
