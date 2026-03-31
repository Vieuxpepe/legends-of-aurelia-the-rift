extends RefCounted


static func setup_objective_ui(field) -> void:
	var vp_size = field.get_viewport_rect().size
	var ui_root = field.get_node("UI")

	# 1. THE TOGGLE BUTTON (Foundation for a Quest Log)
	field.objective_toggle_btn = Button.new()
	field.objective_toggle_btn.name = "ObjectiveToggleBtn"
	field.objective_toggle_btn.text = "Hide Goals"
	field.objective_toggle_btn.add_theme_font_size_override("font_size", 20)
	field.objective_toggle_btn.size = Vector2(140, 40)
	field.objective_toggle_btn.position = Vector2(vp_size.x - 160, 20)
	field.objective_toggle_btn.pressed.connect(field._on_objective_toggle_pressed)

	# Style the button so it matches the UI
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.8, 0.6, 0.2, 0.8)
	field.objective_toggle_btn.add_theme_stylebox_override("normal", btn_style)
	ui_root.add_child(field.objective_toggle_btn)

	# 2. THE BACKGROUND BOX (Goldilocks size: 400x120)
	field.objective_panel = Panel.new()
	field.objective_panel.name = "ObjectivePanel"

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.8, 0.6, 0.2, 0.8)
	field.objective_panel.add_theme_stylebox_override("panel", style)

	field.objective_panel.size = Vector2(400, 120)
	field.objective_panel.position = Vector2(vp_size.x - 420, 70) # Sits just below the toggle button
	field.objective_panel.pivot_offset = field.objective_panel.size / 2.0

	# 3. THE TEXT LABEL (Medium fonts)
	field.objective_label = RichTextLabel.new()
	field.objective_label.bbcode_enabled = true
	field.objective_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	field.objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	field.objective_label.add_theme_font_size_override("normal_font_size", 22)
	field.objective_label.add_theme_font_size_override("bold_font_size", 26)

	field.objective_panel.add_child(field.objective_label)
	ui_root.add_child(field.objective_panel)

	update_objective_ui(field, true) # Pass true so it doesn't do the bounce animation right when the level loads


static func on_objective_toggle_pressed(field) -> void:
	field.is_objective_expanded = !field.is_objective_expanded
	var target_x: float = 0.0
	if (
		field.objective_panel != null
		and field.objective_panel.has_meta("objective_expanded_x")
		and field.objective_panel.has_meta("objective_collapsed_x")
	):
		target_x = (
			float(field.objective_panel.get_meta("objective_expanded_x"))
			if field.is_objective_expanded
			else float(field.objective_panel.get_meta("objective_collapsed_x"))
		)
	else:
		var vp_size = field.get_viewport_rect().size
		target_x = vp_size.x - 420 if field.is_objective_expanded else vp_size.x + 50

	var tween = field.create_tween()
	tween.tween_property(field.objective_panel, "position:x", target_x, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)

	field.objective_toggle_btn.text = "Hide Goals" if field.is_objective_expanded else "Show Goals"
	if field.select_sound and field.select_sound.stream:
		field.select_sound.play()


static func update_objective_ui(field, skip_animation: bool = false) -> void:
	if field.objective_label == null:
		return

	var txt = "[center][b][color=gold]--- CURRENT OBJECTIVE ---[/color][/b]\n"
	var target_height = 120 # Default panel height

	match field.map_objective:
		field.Objective.ROUT_ENEMY:
			var e_count = 0
			if field.enemy_container:
				for e in field.enemy_container.get_children():
					if not e.is_queued_for_deletion() and e.current_hp > 0:
						e_count += 1

			var spawner_count = 0
			if field.destructibles_container:
				for d in field.destructibles_container.get_children():
					if d.has_method("process_turn") and d.get("spawner_faction") == 0 and not d.is_queued_for_deletion():
						spawner_count += 1

			var instruction = field.custom_objective_text if field.custom_objective_text != "" else "Defeat all enemies!"

			if spawner_count > 0:
				txt += instruction + "\n[color=gray](Remaining: " + str(e_count) + " + " + str(spawner_count) + " Spawners)[/color]"
			else:
				txt += instruction + "\n[color=gray](Remaining: " + str(e_count) + ")[/color]"

		field.Objective.SURVIVE_TURNS:
			var instruction = field.custom_objective_text if field.custom_objective_text != "" else "Survive the assault!"
			txt += instruction + "\n[color=cyan]Turn: " + str(field.current_turn) + " / " + str(field.turn_limit) + "[/color]"

		field.Objective.DEFEND_TARGET:
			var vip_name = "Target"
			var vip_hp_str = "?/?"
			var hp_color = "white"

			if is_instance_valid(field.vip_target) and not field.vip_target.is_queued_for_deletion():
				vip_name = field.vip_target.get("unit_name") if field.vip_target.get("unit_name") != null else "VIP"
				var chp = field.vip_target.get("current_hp")
				var mhp = field.vip_target.get("max_hp")

				if chp != null and mhp != null:
					vip_hp_str = str(chp) + "/" + str(mhp)
					var ratio = float(chp) / float(mhp)
					if ratio <= 0.3:
						hp_color = "red"
					elif ratio <= 0.6:
						hp_color = "yellow"
					else:
						hp_color = "lime"

			var instruction = field.custom_objective_text if field.custom_objective_text != "" else "Escort " + vip_name + " to the exit!"
			txt += instruction + " (Turn " + str(field.current_turn) + "/" + str(field.turn_limit) + ")\n"
			txt += "[color=gray]Convoy Status: [/color][color=" + hp_color + "]" + vip_hp_str + "[/color]"

	var reinforcement_line: String = field._build_enemy_reinforcement_objective_bbcode()
	if reinforcement_line != "":
		txt += "\n" + reinforcement_line
		target_height += 28

	if CampaignManager.merchant_quest_active:
		target_height = 190 + (28 if reinforcement_line != "" else 0) # Expand the panel to fit quest + telegraph text

		var target_item = CampaignManager.merchant_quest_item_name
		var target_amt = CampaignManager.merchant_quest_target_amount
		var current_amt = 0

		# 1. Check the Global Convoy
		for item in field.player_inventory:
			var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
			if i_name == target_item:
				current_amt += 1

		# 2. Check personal pockets (in case they just picked it up!)
		if field.player_container:
			for unit in field.player_container.get_children():
				if "inventory" in unit:
					for item in unit.inventory:
						if item != null:
							var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
							if i_name == target_item:
								current_amt += 1

		# 3. Format the UI Text
		txt += "\n\n[b][color=orange]--- BOUNTY ---[/color][/b]\n"
		if current_amt >= target_amt:
			txt += "[color=lime]" + target_item + ": " + str(current_amt) + " / " + str(target_amt) + " (Ready!)[/color]"
		else:
			txt += "[color=gray]" + target_item + ": " + str(current_amt) + " / " + str(target_amt) + "[/color]"

	txt += field._build_mock_coop_player_phase_readiness_bbcode_suffix()
	txt += "\n[color=gray][font_size=15]Shift: enemy threat · Side panel: goals[/font_size][/color]\n[/center]"

	# Dynamically resize the panel based on whether a quest is active
	if field.objective_panel.size.y != target_height:
		field.create_tween().tween_property(field.objective_panel, "size:y", target_height, 0.3).set_trans(Tween.TRANS_BACK)

	# --- NORMAL TEXT UPDATE ---
	if field.objective_label.text != txt:
		field.objective_label.text = txt

		if not skip_animation and field.is_objective_expanded:
			field.objective_panel.scale = Vector2(1.10, 1.10)
			field.objective_panel.modulate = Color(1.5, 1.5, 1.5, 1.0)

			var tween = field.create_tween().set_parallel(true)
			tween.tween_property(field.objective_panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(field.objective_panel, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_SINE)

			if field.select_sound and field.select_sound.stream != null:
				var tick_player = AudioStreamPlayer.new()
				tick_player.stream = field.select_sound.stream
				tick_player.pitch_scale = 1.6
				tick_player.volume_db = -5.0
				field.add_child(tick_player)
				tick_player.play()
				tick_player.finished.connect(tick_player.queue_free)

	field.queue_redraw()

