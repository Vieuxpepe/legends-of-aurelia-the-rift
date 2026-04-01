extends RefCounted


static func execute_talk(field, initiator: Node2D, target: Node2D) -> void:
	# --- 1. PLAY THE CINEMATIC FIRST! ---
	await field.play_recruit_dialogue(initiator, target)

	# --- 2. EXECUTE THE TEAM SWAP ---
	target.get_parent().remove_child(target)
	field.player_container.add_child(target)

	if target.get("data") != null:
		target.data.is_recruitable = false

	target.is_exhausted = true
	if target.has_method("set_selected_glow"):
		target.set_selected_glow(false)

	if field.epic_level_up_sound and field.epic_level_up_sound.stream != null:
		field.epic_level_up_sound.play()

	field.screen_shake(8.0, 0.3)
	field.add_combat_log(initiator.unit_name + " convinced " + target.unit_name + " to join.", "cyan")
	field.spawn_loot_text("RECRUITED!", Color.LIME, target.global_position + Vector2(32, -32))
	if field._battle_resonance_allowed():
		CampaignManager.mark_battle_resonance("showed_mercy_under_pressure")
	field.rebuild_grid()


static func play_recruit_dialogue(field, initiator: Node2D, target: Node2D) -> void:
	# Freeze the battlefield, but keep the UI running
	field.get_tree().paused = true
	field.talk_panel.process_mode = Node.PROCESS_MODE_ALWAYS

	# Grab the dialogue from the enemy data safely
	var lines: Array[String] = []
	if target.get("data") != null and "recruit_dialogue" in target.data and target.data.recruit_dialogue.size() > 0:
		for l in target.data.recruit_dialogue:
			lines.append(str(l))
	else:
		lines = ["Join us!", "If the pay is good, I'm in."] # Fallback text

	# Setup Portraits
	field.talk_left_portrait.texture = initiator.data.portrait if initiator.get("data") else null
	field.talk_right_portrait.texture = target.data.portrait if target.get("data") else null

	field.talk_panel.visible = true

	# Loop through the conversation line by line
	for i in range(lines.size()):
		var is_initiator_speaking: bool = (i % 2 == 0) # Evens = Player, Odds = Enemy

		# Dim the listener, highlight the speaker
		if is_initiator_speaking:
			field.talk_name.text = initiator.unit_name
			field.talk_name.modulate = Color.CYAN
			field.talk_left_portrait.modulate = Color.WHITE
			field.talk_right_portrait.modulate = Color(0.3, 0.3, 0.3) # Dimmer
		else:
			field.talk_name.text = target.unit_name
			field.talk_name.modulate = Color.TOMATO
			field.talk_left_portrait.modulate = Color(0.3, 0.3, 0.3) # Dimmer
			field.talk_right_portrait.modulate = Color.WHITE

		# Prepare text and replace {Name} with the Avatar's real name!
		var line_text: String = lines[i]
		if initiator.get("is_custom_avatar") == true:
			line_text = line_text.replace("{Name}", initiator.unit_name)
		elif target.get("is_custom_avatar") == true:
			line_text = line_text.replace("{Name}", target.unit_name)

		field.talk_text.text = "[center]" + line_text + "[/center]"
		field.talk_text.visible_ratio = 0.0 # Hide all text initially

		# Play a tiny dialogue beep
		if field.select_sound and field.select_sound.stream != null:
			field.select_sound.pitch_scale = 1.2 if is_initiator_speaking else 0.8
			field.select_sound.play()

		# Typewriter Effect Tween
		var type_speed: float = lines[i].length() * 0.025 # Longer lines take slightly more time
		var tw = field.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(field.talk_text, "visible_ratio", 1.0, type_speed)

		# Wait for the player to click the invisible Next Button
		await field.dialogue_advanced

		# If they clicked while text was still typing, force it to finish instantly!
		if tw.is_running():
			tw.kill()
			field.talk_text.visible_ratio = 1.0
			await field.dialogue_advanced # Wait for a second click to actually move on

	# Cleanup
	field.talk_panel.visible = false
	field.get_tree().paused = false


static func _on_support_talk_pressed(field) -> void:
	field.hide_trade_popup()
	var initiator: Node2D = field.player_state.active_unit
	var ally: Node2D = field.player_state.trade_target_ally

	if initiator != null and ally != null:
		field.play_ui_sfx(field.UISfx.TARGET_OK)
		await field.play_support_dialogue(initiator, ally)
		# End the initiator's turn after talking
		initiator.finish_turn()
		field.player_state.clear_active_unit()


static func play_support_dialogue(field, initiator: Node2D, target: Node2D) -> void:
	var init_name: String = field.get_support_name(initiator)
	var target_name: String = field.get_support_name(target)
	var bond: Dictionary = CampaignManager.get_support_bond(init_name, target_name)

	var dialogue_lines: Array = []
	var new_rank_name: String = "C"
	var support_file_found: Variant = null

	for s_file in initiator.data.supports:
		if s_file.partner_name == target_name:
			support_file_found = s_file
			break

	if support_file_found == null:
		for s_file in target.data.supports:
			if s_file.partner_name == init_name:
				support_file_found = s_file
				break

	if support_file_found != null:
		if bond["rank"] == 0:
			dialogue_lines = support_file_found.c_dialogue
			new_rank_name = "C"
		elif bond["rank"] == 1:
			dialogue_lines = support_file_found.b_dialogue
			new_rank_name = "B"
		elif bond["rank"] == 2:
			dialogue_lines = support_file_found.a_dialogue
			new_rank_name = "A"

	# Reuse the exact same cinematic UI we built for Enemy Recruitment!
	var temp_data: Variant = target.get("data")
	var original_recruit: Array = []
	if temp_data and "recruit_dialogue" in temp_data:
		original_recruit = temp_data.recruit_dialogue.duplicate()
		temp_data.recruit_dialogue = dialogue_lines

	# Play the cinematic scene
	await field.play_recruit_dialogue(initiator, target)

	# Restore their original data
	if temp_data and "recruit_dialogue" in temp_data:
		temp_data.recruit_dialogue = original_recruit

	# Upgrade the Rank permanently!
	bond["rank"] += 1

	if field.level_up_sound.stream != null:
		field.level_up_sound.play()
	field.spawn_loot_text("SUPPORT RANK " + new_rank_name + "!", Color.VIOLET, initiator.global_position + Vector2(0, -40))
	if support_file_found != null:
		var a_name: String = str(initiator.get("unit_name")) if initiator.get("unit_name") != null else "Unit"
		var b_name: String = str(target.get("unit_name")) if target.get("unit_name") != null else "Ally"
		field.add_combat_log(a_name + " & " + b_name + ": Support rank → " + new_rank_name + "!", "violet")
