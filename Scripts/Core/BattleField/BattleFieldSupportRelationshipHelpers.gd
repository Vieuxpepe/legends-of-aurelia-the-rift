extends RefCounted

# Support / relationship identity, combat modifiers, bond pulse & award flow, bond panel UI,
# support-ready queue & popup. Extracted from `BattleField.gd` (battlefield remains state owner).

const SupportHelpers = preload("res://Scripts/Core/BattleField/BattleFieldSupportHelpers.gd")


static func support_name_from_unit(unit: Node2D) -> String:
	if unit.get("is_custom_avatar") == true:
		return "Avatar"
	return unit.unit_name


static func get_relationship_id(unit_or_name: Variant) -> String:
	if unit_or_name is Node2D:
		return support_name_from_unit(unit_or_name)
	if unit_or_name is String:
		return unit_or_name
	return ""


static func get_unit_tags(unit: Node2D) -> Array:
	if unit == null:
		return []
	var tags = unit.get("unit_tags")
	if tags is Array:
		return tags
	var data = unit.get("data")
	if data != null:
		var dt = data.get("unit_tags")
		if dt is Array:
			return dt
	return []


static func get_relationship_combat_modifiers(field, unit: Node2D) -> Dictionary:
	var out := {"hit": 0, "avo": 0, "crit_bonus": 0, "dmg_bonus": 0, "support_chance_bonus": 0}
	if unit == null:
		return out
	var my_id: String = get_relationship_id(unit)
	var my_pos: Vector2i = field.get_grid_pos(unit)
	var is_allied: bool = (unit.get_parent() == field.player_container or (field.ally_container != null and unit.get_parent() == field.ally_container))

	if field._grief_units.get(my_id, false):
		out["hit"] += field.RELATIONSHIP_GRIEF_HIT_PENALTY
		out["avo"] += field.RELATIONSHIP_GRIEF_AVO_PENALTY

	var directions := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for dir in directions:
		var neighbor_pos: Vector2i = my_pos + dir
		var neighbor: Node2D = field.get_occupant_at(neighbor_pos)
		if neighbor == null or neighbor == unit:
			continue
		var etags: Array = get_unit_tags(neighbor)
		for tag in field.FEAR_TAGS:
			if tag in etags:
				out["hit"] += field.RELATIONSHIP_FEAR_HIT_PENALTY
				out["avo"] += field.RELATIONSHIP_FEAR_AVO_PENALTY
				break

	if not is_allied:
		return out
	var allies: Array[Node2D] = []
	if field.player_container:
		for c in field.player_container.get_children():
			if c is Node2D and c != unit and is_instance_valid(c) and (c.get("current_hp") != null and int(c.current_hp) > 0):
				allies.append(c)
	if field.ally_container:
		for c in field.ally_container.get_children():
			if c is Node2D and c != unit and is_instance_valid(c) and (c.get("current_hp") != null and int(c.current_hp) > 0):
				allies.append(c)
	for ally in allies:
		var dist: int = abs(field.get_grid_pos(ally).x - my_pos.x) + abs(field.get_grid_pos(ally).y - my_pos.y)
		if dist > field.SUPPORT_COMBAT_RANGE_MANHATTAN:
			continue
		var rel: Dictionary = CampaignManager.get_relationship(my_id, get_relationship_id(ally))
		if rel["trust"] >= field.RELATIONSHIP_TRUST_THRESHOLD:
			out["support_chance_bonus"] = maxi(out["support_chance_bonus"], field.RELATIONSHIP_TRUST_SUPPORT_CHANCE_BONUS)
		if rel["rivalry"] >= field.RELATIONSHIP_RIVALRY_THRESHOLD:
			out["crit_bonus"] += field.RELATIONSHIP_RIVALRY_CRIT_BONUS
			out["dmg_bonus"] += field.RELATIONSHIP_RIVALRY_DMG_BONUS
		if rel["mentorship"] >= field.RELATIONSHIP_MENTORSHIP_THRESHOLD:
			out["hit"] += field.RELATIONSHIP_MENTORSHIP_HIT_BONUS

	if field.DEBUG_RELATIONSHIP_COMBAT and (out["hit"] != 0 or out["avo"] != 0 or out["crit_bonus"] != 0 or out["dmg_bonus"] != 0 or out["support_chance_bonus"] != 0):
		print("[RelationshipCombat] ", my_id, " mods: ", out)
	return out


static func show_bond_pulse(field, world_pos: Vector2, text: String, color: Color) -> void:
	field.spawn_loot_text(text, color, world_pos)


static func can_gain_mentorship(field, mentor: Node2D, mentee: Node2D) -> bool:
	if mentor == null or mentee == null or mentor == mentee:
		return false
	if not is_instance_valid(mentor) or not is_instance_valid(mentee):
		return false
	var mentor_parent: Node = mentor.get_parent()
	var mentee_parent: Node = mentee.get_parent()
	var mentor_allied: bool = (mentor_parent == field.player_container or (field.ally_container != null and mentor_parent == field.ally_container))
	var mentee_allied: bool = (mentee_parent == field.player_container or (field.ally_container != null and mentee_parent == field.ally_container))
	if not mentor_allied or not mentee_allied:
		return false
	var _ml: Variant = mentor.get("level")
	var _el: Variant = mentee.get("level")
	var mentor_lv: int = 1 if _ml == null else int(_ml)
	var mentee_lv: int = 1 if _el == null else int(_el)
	if mentor_lv <= mentee_lv:
		return false
	return (mentor_lv - mentee_lv) >= field.MENTORSHIP_LEVEL_GAP_MIN


static func award_relationship_stat_event(field, unit_a: Variant, unit_b: Variant, stat: String, event_type: String, amount: int = 1) -> void:
	var id_a: String = get_relationship_id(unit_a)
	var id_b: String = get_relationship_id(unit_b)
	if id_a.is_empty() or id_b.is_empty():
		return
	var key: String = CampaignManager.get_support_key(id_a, id_b) + "_" + event_type
	if field._relationship_event_awarded.get(key, false):
		return
	field._relationship_event_awarded[key] = true
	var rel: Dictionary = CampaignManager.get_relationship(id_a, id_b)
	var old_val: int = int(rel.get(stat, 0))
	CampaignManager.add_relationship_value(id_a, id_b, stat, amount)
	var new_val: int = old_val + amount

	var pulse_text: String = ""
	var pulse_color: Color = field.BOND_PULSE_COLOR_TRUST
	if stat == "trust":
		pulse_text = "Trust +1"
		pulse_color = field.BOND_PULSE_COLOR_TRUST
	elif stat == "mentorship":
		if new_val >= field.MENTORSHIP_FORMED_THRESHOLD and old_val < field.MENTORSHIP_FORMED_THRESHOLD:
			pulse_text = "Mentorship Formed"
			field.add_combat_log("Mentorship has formed between " + id_a + " and " + id_b + ".", "gold")
		else:
			pulse_text = "Mentorship +1"
		pulse_color = field.BOND_PULSE_COLOR_MENTORSHIP
	elif stat == "rivalry":
		if new_val >= field.RIVALRY_FORMED_THRESHOLD and old_val < field.RIVALRY_FORMED_THRESHOLD:
			pulse_text = "Rivalry Formed"
			field.add_combat_log("A rivalry ignites between " + id_a + " and " + id_b + ".", "tomato")
		else:
			pulse_text = "Rivalry +1"
		pulse_color = field.BOND_PULSE_COLOR_RIVALRY
	else:
		return

	var pos: Vector2 = Vector2.ZERO
	if unit_a is Node2D and unit_b is Node2D:
		pos = (unit_a.global_position + unit_b.global_position) * 0.5
	elif unit_a is Node2D:
		pos = unit_a.global_position
	elif unit_b is Node2D:
		pos = unit_b.global_position
	else:
		return
	show_bond_pulse(field, pos + Vector2(32, -24), pulse_text, pulse_color)


static func award_relationship_event(field, unit_a: Variant, unit_b: Variant, event_type: String, amount: int = 1) -> void:
	award_relationship_stat_event(field, unit_a, unit_b, "trust", event_type, amount)


static func get_support_personality(unit: Node2D) -> String:
	if unit == null:
		return ""
	var d = unit.get("data")
	if d == null:
		return ""
	var p = d.get("support_personality")
	return str(p).strip_edges() if p != null else ""


static func get_defy_death_rescue_line(savior: Node2D, victim_name: String) -> String:
	var personality: String = get_support_personality(savior)
	return SupportRescueDialogueDB.get_line(personality, victim_name)


static func get_best_support_context(field, unit: Node2D) -> Dictionary:
	var empty := {"partner": null, "rank": 0, "in_range": false, "can_react": false}
	if unit == null or unit.get_parent() == field.destructibles_container:
		return empty
	var is_allied: bool = (unit.get_parent() == field.player_container or (field.ally_container != null and unit.get_parent() == field.ally_container))
	if not is_allied:
		return empty
	var my_pos: Vector2i = field.get_grid_pos(unit)
	var my_name: String = support_name_from_unit(unit)
	var best_rank_ref: Array = [0]
	var best_partner_ref: Array = [null]
	var collect := func(container: Node) -> void:
		if container == null:
			return
		for c in container.get_children():
			if not (c is Node2D) or c == unit:
				continue
			if not is_instance_valid(c) or c.is_queued_for_deletion():
				continue
			if c.get("current_hp") != null and int(c.current_hp) <= 0:
				continue
			var dist: int = abs(field.get_grid_pos(c).x - my_pos.x) + abs(field.get_grid_pos(c).y - my_pos.y)
			if dist > field.SUPPORT_COMBAT_RANGE_MANHATTAN:
				continue
			var bond: Dictionary = CampaignManager.get_support_bond(my_name, support_name_from_unit(c))
			var rank: int = SupportHelpers.normalize_support_rank(field, bond)
			if rank > best_rank_ref[0]:
				best_rank_ref[0] = rank
				best_partner_ref[0] = c
	collect.call(field.player_container)
	if field.ally_container:
		collect.call(field.ally_container)
	var best_partner: Node2D = best_partner_ref[0]
	var best_rank: int = best_rank_ref[0]
	var in_range: bool = best_partner != null
	var can_react: bool = (best_partner != null and is_instance_valid(best_partner) and not best_partner.is_queued_for_deletion() and best_partner.get_parent() != field.destructibles_container and (best_partner.get("current_hp") != null and int(best_partner.current_hp) > 0))
	return {"partner": best_partner, "rank": best_rank, "in_range": in_range, "can_react": can_react}


static func on_support_btn_pressed(field) -> void:
	if field.select_sound and field.select_sound.stream != null:
		field.select_sound.play()

	var target_unit = null
	if field.current_state == field.player_state and field.player_state.active_unit != null:
		target_unit = field.player_state.active_unit
	else:
		target_unit = field.get_occupant_at(field.cursor_grid_pos)

	if target_unit == null:
		return

	var u_name = support_name_from_unit(target_unit)
	var display_text = "[center][b][color=gold]--- " + target_unit.unit_name.to_upper() + "'S BONDS ---[/color][/b][/center]\n\n"
	var found_any_friends = false

	for key in CampaignManager.support_bonds.keys():
		var names: PackedStringArray = CampaignManager.parse_relationship_key(key)
		var partner_name := ""
		if names.size() >= 2:
			if names[0] == u_name:
				partner_name = names[1]
			elif names[1] == u_name:
				partner_name = names[0]

		if partner_name != "":
			found_any_friends = true
			var display_partner_name := partner_name
			if partner_name == "Avatar":
				for p_unit in field.player_container.get_children():
					if p_unit.get("is_custom_avatar") == true:
						display_partner_name = p_unit.unit_name
						break
			var bond = CampaignManager.get_support_bond(u_name, partner_name)
			var pts = bond["points"]
			var rank_color = "gray"
			var rank_letter = "None"
			var next_goal = 10

			if bond["rank"] == 1:
				rank_letter = "C"
				rank_color = "cyan"
				next_goal = 25
			elif bond["rank"] == 2:
				rank_letter = "B"
				rank_color = "lime"
				next_goal = 45
			elif bond["rank"] == 3:
				rank_letter = "A (MAX)"
				rank_color = "gold"

			if bond["rank"] < 3:
				display_text += display_partner_name + "  -  Rank [color=" + rank_color + "]" + rank_letter + "[/color]  [color=gray](" + str(pts) + "/" + str(next_goal) + " pts)[/color]\n"
			else:
				display_text += display_partner_name + "  -  [color=gold]Rank A (MAX)[/color]\n"

	if not found_any_friends:
		display_text += "[center][color=gray]No bonds formed yet.\nFight adjacent to allies to grow closer![/color][/center]"

	field.support_list_text.text = display_text
	field.support_tracker_panel.visible = true


static func get_support_threshold_for_next_rank(field, unit_a: Node2D, unit_b: Node2D, current_rank: int) -> int:
	if unit_a == null or unit_b == null:
		return -1
	if unit_a.get("data") == null or unit_b.get("data") == null:
		return -1

	var name_a = support_name_from_unit(unit_a)
	var name_b = support_name_from_unit(unit_b)

	var support_file_found = null

	for s_file in unit_a.data.supports:
		if s_file.partner_name == name_b:
			support_file_found = s_file
			break

	if support_file_found == null:
		for s_file in unit_b.data.supports:
			if s_file.partner_name == name_a:
				support_file_found = s_file
				break

	if support_file_found == null:
		return -1

	if current_rank == 0:
		return int(support_file_found.points_for_c)
	elif current_rank == 1:
		return int(support_file_found.points_for_b)
	elif current_rank == 2:
		return int(support_file_found.points_for_a)

	return -1


static func get_next_support_rank_letter(current_rank: int) -> String:
	match current_rank:
		0:
			return "C"
		1:
			return "B"
		2:
			return "A"
		_:
			return ""


static func queue_support_ready_if_needed(field, unit_a: Node2D, unit_b: Node2D) -> void:
	if unit_a == null or unit_b == null:
		return

	var name_a = support_name_from_unit(unit_a)
	var name_b = support_name_from_unit(unit_b)
	var bond_key = CampaignManager.get_support_key(name_a, name_b)

	if field._battle_support_ready_seen.has(bond_key):
		return

	var bond = CampaignManager.get_support_bond(name_a, name_b)

	var current_rank: int = int(bond.get("rank", 0))
	if current_rank >= 3:
		return

	var current_points: int = int(bond.get("points", 0))
	var needed_points: int = get_support_threshold_for_next_rank(field, unit_a, unit_b, current_rank)

	if needed_points < 0:
		return

	if current_points >= needed_points:
		field._battle_support_ready_seen[bond_key] = true
		field._battle_support_ready_queue.append({
			"bond_key": bond_key,
			"unit_a_name": unit_a.unit_name,
			"unit_b_name": unit_b.unit_name,
			"next_rank": get_next_support_rank_letter(current_rank)
		})
		field._show_next_support_ready_popup()


static func add_support_points_and_check(field, unit_a: Node2D, unit_b: Node2D, amount: int) -> void:
	if unit_a == null or unit_b == null:
		return
	if amount <= 0:
		return

	CampaignManager.add_support_points(support_name_from_unit(unit_a), support_name_from_unit(unit_b), amount)
	queue_support_ready_if_needed(field, unit_a, unit_b)


func show_defy_death_savior_portrait(field, savior: Node2D, savior_name: String, rescue_line: String) -> void:
	if field.talk_panel == null:
		return
	var portrait_tex: Texture2D = null
	if savior != null and savior.get("data") != null:
		var p = savior.data.get("portrait")
		if p is Texture2D:
			portrait_tex = p
	field.talk_left_portrait.texture = portrait_tex
	field.talk_left_portrait.modulate = Color.WHITE
	field.talk_left_portrait.visible = true
	if field.talk_right_portrait != null:
		field.talk_right_portrait.texture = null
		field.talk_right_portrait.visible = false
	field.talk_name.text = savior_name
	field.talk_name.modulate = Color.GOLD
	field.talk_text.text = "[center]" + rescue_line + "[/center]"
	field.talk_text.visible_ratio = 1.0
	if field.talk_next_btn != null:
		field.talk_next_btn.visible = false
	field.talk_panel.visible = true
	await field.get_tree().create_timer(2.0).timeout
	field.talk_panel.visible = false
	if field.talk_next_btn != null:
		field.talk_next_btn.visible = true


func show_next_support_ready_popup(field) -> void:
	if field._support_popup_busy:
		return
	if field._battle_support_ready_queue.is_empty():
		return

	field._support_popup_busy = true
	var data: Dictionary = field._battle_support_ready_queue.pop_front()

	var popup_layer := CanvasLayer.new()
	popup_layer.layer = 160
	popup_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	field.add_child(popup_layer)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 100)
	panel.position = Vector2((field.get_viewport_rect().size.x - 520) * 0.5, 70)
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate.a = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", field._make_levelup_style(
		Color(0.06, 0.06, 0.10, 0.96),
		Color(0.85, 0.75, 0.25, 1.0),
		14
	))
	popup_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 14
	vbox.offset_top = 12
	vbox.offset_right = -14
	vbox.offset_bottom = -12
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "SUPPORT READY!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.42))
	vbox.add_child(title)

	var body := Label.new()
	body.text = data["unit_a_name"] + " & " + data["unit_b_name"] + " can now view Rank " + data["next_rank"] + "."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	vbox.add_child(body)

	var sub := Label.new()
	sub.text = "Visit a support conversation after battle."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.75, 0.78, 0.84))
	vbox.add_child(sub)

	if field.level_up_sound and field.level_up_sound.stream != null:
		field.level_up_sound.pitch_scale = 1.08
		field.level_up_sound.play()

	var tw: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

	await field.get_tree().create_timer(2.1, true, false, true).timeout

	var out_tw: Tween = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	out_tw.tween_property(panel, "modulate:a", 0.0, 0.18)
	out_tw.tween_property(panel, "position:y", panel.position.y - 20.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await out_tw.finished

	popup_layer.queue_free()
	field._support_popup_busy = false

	if not field._battle_support_ready_queue.is_empty():
		field._show_next_support_ready_popup()
