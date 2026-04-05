extends RefCounted

const BattleResultPresentationHelpers = preload("res://Scripts/Core/BattleField/BattleFieldBattleResultPresentationHelpers.gd")
const CombatPassiveAbilityHelpers = preload("res://Scripts/Core/BattleField/CombatPassiveAbilityHelpers.gd")
const FateCardLootHelpers = preload("res://Scripts/Core/FateCardLootHelpers.gd")


static func remove_dead_player_dragon(field, unit: Node2D) -> void:
	if unit == null:
		return
	if not unit.get_meta("is_dragon", false):
		return
	if unit.get_parent() != field.player_container:
		return

	var dragon_uid: String = str(unit.get_meta("dragon_uid", ""))
	if dragon_uid == "":
		return

	if dragon_uid == CampaignManager.morgra_favorite_dragon_uid:
		CampaignManager.morgra_anger_duration = 3
		CampaignManager.morgra_neutral_duration = 0
		CampaignManager.morgra_favorite_dragon_uid = ""
		CampaignManager.morgra_favorite_survived_battles = 0

	for i in range(DragonManager.player_dragons.size() - 1, -1, -1):
		var d = DragonManager.player_dragons[i]
		if d is Dictionary and str(d.get("uid", "")) == dragon_uid:
			DragonManager.player_dragons.remove_at(i)
			break

	for i in range(CampaignManager.player_roster.size() - 1, -1, -1):
		var entry = CampaignManager.player_roster[i]
		if not (entry is Dictionary):
			continue

		if str(entry.get("dragon_uid", "")) == dragon_uid:
			CampaignManager.player_roster.remove_at(i)
			break

	if CampaignManager.active_save_slot != -1:
		CampaignManager.save_game(CampaignManager.active_save_slot, true)


static func on_unit_died(field, unit: Node2D, killer: Node2D) -> void:
	var data = unit.get("data")

	var final_words: String = "..."
	var display_name: String = unit.get("unit_name") if unit.get("unit_name") != null else "Unknown Unit"

	if data != null:
		if data.get("display_name") != null:
			display_name = data.display_name
		if data.has_method("get_random_death_quote"):
			final_words = data.get_random_death_quote()

	if unit.get_parent() == field.enemy_container and killer != null and is_instance_valid(killer) and (killer.get_parent() == field.player_container or (field.ally_container != null and killer.get_parent() == field.ally_container)):
		var boss_id: String = field._get_boss_dialogue_id(unit)
		var unit_id: String = field._get_playable_dialogue_id(killer)
		var death_line: String = field._get_boss_personal_line(boss_id, unit_id, "death")
		if not death_line.is_empty():
			field.add_combat_log(display_name + ": " + death_line, "gold")

	print(display_name + " died saying: " + final_words)

	var grid_pos = field.get_grid_pos(unit)
	if field._coop_remote_combat_replay_active:
		field.astar.set_point_solid(grid_pos, false)
		field.update_fog_of_war()
		field.update_objective_ui()
		return

	var bone_payload: Variant = field._consume_skeleton_bone_pile_payload(unit.get_instance_id())
	if bone_payload != null:
		field._spawn_skeleton_bone_pile_for_dead_unit(bone_payload, unit.global_position)
	else:
		field.astar.set_point_solid(grid_pos, false)

	if bone_payload == null:
		CombatPassiveAbilityHelpers.try_ashburst_on_enemy_death(field, unit, grid_pos)

	if unit.get_parent() == field.player_container and unit.get_meta("is_dragon", false):
		remove_dead_player_dragon(field, unit)
		field.add_combat_log(unit.unit_name + " has fallen permanently!", "red")
	if unit.get_parent() == field.enemy_container:
		if bone_payload != null:
			field.add_combat_log(unit.unit_name + " collapses into a pile of bones!", "lightgray")
		else:
			field.enemy_kills_count += 1
			field.add_combat_log(unit.unit_name + " has been defeated!", "tomato")
	elif unit.get_parent() == field.player_container:
		field.player_deaths_count += 1
		field.add_combat_log(unit.unit_name + " has fallen in battle!", "crimson")
	elif unit.get_parent() == field.ally_container:
		field.ally_deaths_count += 1
		field.add_combat_log(unit.unit_name + " has fallen in battle!", "orange")

	if field._battle_resonance_allowed() and unit.get_parent() == field.enemy_container:
		if killer != null and is_instance_valid(killer):
			var kp: Node = killer.get_parent()
			if kp != null and (kp == field.player_container or (field.ally_container != null and kp == field.ally_container)):
				if unit.get("data") != null and unit.data.get("is_recruitable") == true:
					CampaignManager.mark_battle_resonance("chose_harsh_efficiency")

	if unit.get_parent() == field.player_container or unit.get_parent() == field.ally_container:
		var dead_id: String = field.get_relationship_id(unit)
		var dead_pos: Vector2i = field.get_grid_pos(unit)
		var witnesses: Array[Node2D] = []
		if field.player_container:
			for c in field.player_container.get_children():
				if c is Node2D and c != unit and is_instance_valid(c) and (c.get("current_hp") != null and int(c.current_hp) > 0):
					witnesses.append(c)
		if field.ally_container:
			for c in field.ally_container.get_children():
				if c is Node2D and c != unit and is_instance_valid(c) and (c.get("current_hp") != null and int(c.current_hp) > 0):
					witnesses.append(c)
		for w in witnesses:
			var w_pos: Vector2i = field.get_grid_pos(w)
			var dist: int = abs(w_pos.x - dead_pos.x) + abs(w_pos.y - dead_pos.y)
			if dist > field.SUPPORT_COMBAT_RANGE_MANHATTAN:
				continue
			var rel: Dictionary = CampaignManager.get_relationship(field.get_relationship_id(w), dead_id)
			if rel.get("trust", 0) >= field.RELATIONSHIP_TRUST_THRESHOLD:
				field._grief_units[field.get_relationship_id(w)] = true
				field.add_combat_log(field.get_relationship_id(w) + " falters after witnessing " + dead_id + "'s death.", "gray")
				if field.DEBUG_RELATIONSHIP_COMBAT:
					print("[RelationshipCombat] Grief: ", field.get_relationship_id(w), " witnessed ", dead_id)

	if unit.get_parent() == field.enemy_container and killer != null and is_instance_valid(killer):
		var killer_parent: Node = killer.get_parent()
		if killer_parent == field.player_container or (field.ally_container != null and killer_parent == field.ally_container):
			var killer_id: String = field.get_relationship_id(killer)
			var eid: int = unit.get_instance_id()
			var damagers: Array = field._enemy_damagers.get(eid, [])
			for damager_id in damagers:
				if damager_id == killer_id:
					continue
				var other_unit: Node2D = null
				if field.player_container:
					for c in field.player_container.get_children():
						if c is Node2D and field.get_relationship_id(c) == damager_id:
							other_unit = c
							break
				if other_unit == null and field.ally_container:
					for c in field.ally_container.get_children():
						if c is Node2D and field.get_relationship_id(c) == damager_id:
							other_unit = c
							break
				if other_unit != null:
					field._award_relationship_stat_event(killer, other_unit, "rivalry", "rival_finish", 1)
			var killer_pos: Vector2i = field.get_grid_pos(killer)
			var directions: Array = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
			for dir in directions:
				var npos: Vector2i = killer_pos + dir
				var ally_at: Node2D = field.get_unit_at(npos)
				if ally_at == null and field.ally_container != null:
					for c in field.ally_container.get_children():
						if c is Node2D and field.get_grid_pos(c) == npos and (c.get("current_hp") != null and int(c.current_hp) > 0):
							ally_at = c
							break
				if ally_at != null and ally_at != killer and field._can_gain_mentorship(ally_at, killer):
					field._award_relationship_stat_event(ally_at, killer, "mentorship", "kill_near_mentor", 1)
					break
			field._enemy_damagers.erase(eid)

	if unit.get("is_custom_avatar") == true:
		field.add_combat_log("The Leader has fallen! All is lost...", "red")
		trigger_game_over(field, "DEFEAT")
		return

	if unit.get_parent() == field.enemy_container and unit.data != null:
		var u_data = unit.data
		field.pending_loot.clear()

		var total_gold = 0
		if u_data.max_gold_drop > 0:
			total_gold += randi_range(u_data.min_gold_drop, u_data.max_gold_drop)
		if "stolen_gold" in unit:
			total_gold += unit.stolen_gold

		if total_gold > 0:
			field.player_gold += total_gold
			field.animate_flying_gold(unit.global_position, total_gold)
			field.add_combat_log("Found " + str(total_gold) + " gold.", "yellow")

		if u_data.drops_equipped_weapon and unit.equipped_weapon != null:
			if randi() % 100 < u_data.equipped_weapon_chance:
				field.pending_loot.append(CampaignManager.duplicate_item(unit.equipped_weapon))

		for loot in u_data.extra_loot:
			if loot != null and loot.get("item") != null:
				var chance = loot.get("drop_chance") if loot.get("drop_chance") != null else 100.0
				if randf() * 100.0 <= chance:
					field.pending_loot.append(CampaignManager.duplicate_item(loot.item))

		if "stolen_loot" in unit and unit.stolen_loot.size() > 0:
			for s_loot in unit.stolen_loot:
				if s_loot != null:
					field.pending_loot.append(CampaignManager.duplicate_item(s_loot))
		var fate_card_drop: Resource = FateCardLootHelpers.roll_enemy_fate_card_drop(unit)
		if fate_card_drop != null:
			field.pending_loot.append(fate_card_drop)
			var fate_name: String = FateCardLootHelpers.get_fate_card_loot_label(fate_card_drop)
			field.add_combat_log("A Fate Card drops: " + fate_name + "!", "gold")
		var local_loot_recipient: Node2D = null
		if killer != null and is_instance_valid(killer):
			var killer_parent: Node = killer.get_parent()
			if killer_parent == field.player_container or (field.ally_container != null and killer_parent == field.ally_container):
				local_loot_recipient = killer
		if local_loot_recipient == null and field.player_state != null:
			local_loot_recipient = field.player_state.active_unit
		field._coop_capture_enemy_death_loot_for_sync(unit, total_gold, field.pending_loot, local_loot_recipient)
		if not field.pending_loot.is_empty():
			field.loot_recipient = local_loot_recipient
			field.show_loot_window()

	if unit.get_parent() == field.player_container and field.player_container.get_child_count() <= 1:
		field.add_combat_log("MISSION FAILED: Entire party wiped out.", "red")
		trigger_game_over(field, "DEFEAT")
		return

	match field.map_objective:
		field.Objective.ROUT_ENEMY:
			if field._count_alive_enemies(unit) == 0 and field._count_active_enemy_spawners() == 0 and field._count_pending_skeleton_bone_piles() == 0:
				field.add_combat_log("MISSION ACCOMPLISHED: All enemies routed.", "lime")
				if field._defer_battle_result_until_loot_if_needed("VICTORY"):
					pass
				else:
					trigger_victory(field)

		field.Objective.DEFEND_TARGET:
			if unit == field.vip_target:
				field.add_combat_log("MISSION FAILED: VIP Target was killed.", "red")
				if field._defer_battle_result_until_loot_if_needed("DEFEAT"):
					pass
				else:
					trigger_game_over(field, "DEFEAT")

	field.update_fog_of_war()
	field.update_objective_ui()


static func trigger_game_over(field, result: String) -> void:
	var normalized_result: String = field._coop_normalize_battle_result(result)
	if normalized_result == "":
		normalized_result = str(result).strip_edges()
	if field._coop_finalized_battle_result != "":
		return
	if not field._coop_remote_battle_result_applying and normalized_result != "VICTORY":
		if field.coop_enet_should_wait_for_host_authoritative_battle_result():
			field._coop_wait_for_host_authoritative_battle_result(normalized_result)
			return
		if field._defer_battle_result_until_loot_if_needed(normalized_result):
			return
		field.coop_enet_sync_after_host_authoritative_battle_result(normalized_result)
	elif field._defer_battle_result_until_loot_if_needed(normalized_result):
		return
	field._coop_waiting_for_host_battle_result = ""
	field._coop_battle_result_resolution_in_progress = normalized_result
	field._coop_finalized_battle_result = normalized_result

	field.change_state(null)
	if CampaignManager and not field.is_arena_match and not CampaignManager.is_skirmish_mode:
		CampaignManager.record_story_battle_outcome_for_camp(normalized_result, field.player_deaths_count, field.ally_deaths_count)

	field.get_tree().paused = true
	field.game_over_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	if field.is_arena_match and ArenaManager.current_opponent_data.size() > 0:
		var opp_mmr: int = ArenaManager.sanitize_leaderboard_score_mmr(ArenaManager.current_opponent_data.get("score", 1000))
		var my_mmr: int = ArenaManager.get_local_mmr()
		var mmr_change: int = 0

		ArenaManager.last_match_old_mmr = my_mmr

		if normalized_result == "VICTORY":
			mmr_change = 25 + int(max(0, (opp_mmr - my_mmr) / 10.0))
			ArenaManager.last_match_result = "VICTORY"

			var arena_rewards = CampaignManager.record_arena_win(150)
			ArenaManager.last_match_gold_reward = arena_rewards["gold"]
			ArenaManager.last_match_token_reward = arena_rewards["tokens"]
		else:
			mmr_change = -15 + int(min(0, (opp_mmr - my_mmr) / 15.0))
			mmr_change = min(-1, mmr_change)
			ArenaManager.last_match_result = "DEFEAT"

			CampaignManager.record_arena_loss()

			var meta = ArenaManager.current_opponent_data.get("metadata", {})
			var owner_id = meta.get("player_id", "")
			if owner_id != "":
				ArenaManager.record_defense_result(owner_id, true)

		ArenaManager.set_local_mmr(my_mmr + mmr_change)
		ArenaManager.last_match_mmr_change = mmr_change
		ArenaManager.last_match_new_mmr = ArenaManager.get_local_mmr()

	BattleResultPresentationHelpers.present_game_over_panel(field, normalized_result)


static func on_restart_button_pressed(field) -> void:
	if CoopExpeditionSessionManager.uses_runtime_network_coop_transport() and CoopExpeditionSessionManager.phase != CoopExpeditionSessionManager.Phase.NONE:
		if field.battle_log != null and field.battle_log.visible:
			field.add_combat_log("Co-op: restart is disabled after defeat. Return to the charter to regroup.", "gold")
		return
	field.get_tree().paused = false

	if field.is_arena_match:
		ArenaManager.last_match_result = "DEFEAT"
		ArenaManager.current_opponent_data = {}
		field.get_tree().change_scene_to_file("res://Scenes/CityMenu.tscn")
		return

	SceneTransition.change_scene_to_file(field.get_tree().current_scene.scene_file_path)


static func on_continue_button_pressed(field) -> void:
	field.get_tree().paused = false
	if field.result_label != null and field.result_label.text == "DEFEAT" and CoopExpeditionSessionManager.uses_runtime_network_coop_transport() and CoopExpeditionSessionManager.phase != CoopExpeditionSessionManager.Phase.NONE:
		SceneTransition.change_scene_to_file("res://Scenes/UI/ExpeditionCharterStagingUI.tscn")
		return

	if field.is_arena_match:
		ArenaManager.current_opponent_data = {}
		field.get_tree().change_scene_to_file("res://Scenes/CityMenu.tscn")
		return

	for u in field.player_container.get_children():
		if u.has_meta("is_temporary_summon"):
			field.player_container.remove_child(u)
			u.queue_free()

	if field.ally_container:
		var surviving_allies = field.ally_container.get_children()
		for ally in surviving_allies:
			if is_instance_valid(ally) and not ally.is_queued_for_deletion() and ally.current_hp > 0:
				if ally.get("data") != null and ally.data.get("is_recruitable") == true and not ally.has_meta("is_temporary_summon"):
					field.ally_container.remove_child(ally)
					field.player_container.add_child(ally)
					field.add_combat_log(ally.unit_name + " joined the party!", "lime")

	CampaignManager.save_party(field)

	CampaignManager.load_next_level()


static func trigger_victory(field) -> void:
	if field._coop_finalized_battle_result != "":
		return
	if field._coop_battle_result_resolution_in_progress == "VICTORY":
		return
	if not field._coop_remote_battle_result_applying:
		if field.coop_enet_should_wait_for_host_authoritative_battle_result():
			field._coop_wait_for_host_authoritative_battle_result("VICTORY")
			return
		if field._defer_battle_result_until_loot_if_needed("VICTORY"):
			return
		field.coop_enet_sync_after_host_authoritative_battle_result("VICTORY")
	elif field._defer_battle_result_until_loot_if_needed("VICTORY"):
		return
	field._coop_battle_result_resolution_in_progress = "VICTORY"

	if not CampaignManager.is_skirmish_mode and field.outro_dialogue.size() > 0:
		var avatar_node = null
		for u in field.player_container.get_children():
			if u.get("is_custom_avatar") == true:
				avatar_node = u
				break

		for block in field.outro_dialogue:
			if block.lines.is_empty():
				continue

			var final_name = block.speaker_name
			var final_portrait = block.portrait

			if final_name.to_lower() == "avatar" and avatar_node != null:
				final_name = avatar_node.unit_name
				if final_portrait == null and avatar_node.data != null:
					final_portrait = avatar_node.data.portrait

			var formatted_lines: Array = []
			for line in block.lines:
				var f_line = line
				if avatar_node != null:
					f_line = f_line.replace("{Avatar}", avatar_node.unit_name)
				formatted_lines.append(f_line)

			await field.play_cinematic_dialogue(final_name, final_portrait, formatted_lines, true)

	if CampaignManager.current_level_index == 2:
		CampaignManager.blacksmith_unlocked = true
		CampaignManager.encounter_flags["shattered_sanctum_cleared"] = true

	var survivors: Array[Node2D] = []
	if field.player_container:
		for c in field.player_container.get_children():
			if c is Node2D and is_instance_valid(c) and (c.get("current_hp") != null and int(c.current_hp) > 0):
				survivors.append(c)
	var trust_pairs: int = 0
	for i in range(survivors.size()):
		for j in range(i + 1, survivors.size()):
			var a: Node2D = survivors[i]
			var b: Node2D = survivors[j]
			var pa: Vector2i = field.get_grid_pos(a)
			var pb: Vector2i = field.get_grid_pos(b)
			var dist: int = abs(pa.x - pb.x) + abs(pa.y - pb.y)
			if dist <= field.VICTORY_TRUST_PROXIMITY_MANHATTAN:
				CampaignManager.add_relationship_value(field.get_relationship_id(a), field.get_relationship_id(b), "trust", 1)
				trust_pairs += 1
			if dist <= field.VICTORY_TRUST_PROXIMITY_MANHATTAN:
				if field._can_gain_mentorship(a, b):
					field._award_relationship_stat_event(a, b, "mentorship", "victory_mentorship", 1)
				elif field._can_gain_mentorship(b, a):
					field._award_relationship_stat_event(b, a, "mentorship", "victory_mentorship", 1)
	if field.DEBUG_RELATIONSHIP_COMBAT and trust_pairs > 0:
		print("[RelationshipCombat] Victory: +1 trust for ", trust_pairs, " close survivor pairs")

	trigger_game_over(field, "VICTORY")
