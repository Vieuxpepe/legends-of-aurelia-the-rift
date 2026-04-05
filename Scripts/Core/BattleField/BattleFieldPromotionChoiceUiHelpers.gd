extends RefCounted

# Extracted branching promotion-choice UI from `BattleField.gd:_ask_for_promotion_choice`.
# Uses the existing `promotion_chosen` signal on `field` to preserve await semantics.


static func ask_for_promotion_choice(field, options: Array) -> Resource:
	var promo_layer = CanvasLayer.new()
	promo_layer.layer = 110 # Keep it on top of everything
	field.add_child(promo_layer)

	var vp_size = field.get_viewport_rect().size

	# Dim the background
	var dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.85)
	dimmer.size = vp_size
	promo_layer.add_child(dimmer)

	var title = Label.new()
	title.text = "CHOOSE YOUR PATH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 80)
	title.add_theme_color_override("font_color", Color.GOLD)
	title.position = Vector2(0, 80)
	title.size.x = vp_size.x
	promo_layer.add_child(title)

	# The container holding the class cards
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 60)
	hbox.size = Vector2(vp_size.x, 600)
	hbox.position = Vector2(0, 200)
	promo_layer.add_child(hbox)

	# Build a card for each option in the array
	for class_res in options:
		if not (class_res is Resource):
			continue
		var option_res: Resource = class_res

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(450, 650)

		# Set pivot to the center for smooth scaling!
		btn.pivot_offset = btn.custom_minimum_size / 2.0

		var vbox = VBoxContainer.new()
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
		vbox.add_theme_constant_override("separation", 15)
		# Tell the VBox to ignore the parent's scale so it doesn't double-scale the text weirdly
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vbox)

		var c_name = Label.new()
		c_name.text = option_res.get("job_name") if option_res.get("job_name") else "Unknown"
		c_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c_name.add_theme_font_size_override("font_size", 56)
		c_name.add_theme_color_override("font_color", Color.CYAN)
		vbox.add_child(c_name)

		var sep = HSeparator.new()
		vbox.add_child(sep)

		var stats = Label.new()
		var m_range = str(option_res.get("move_range")) if option_res.get("move_range") != null else "N/A"
		stats.text = "\n[ MOVE: " + m_range + " ]\n\n"

		# Safely extract stats
		var p_hp = option_res.get("promo_hp_bonus") if option_res.get("promo_hp_bonus") != null else 0
		var p_str = option_res.get("promo_str_bonus") if option_res.get("promo_str_bonus") != null else 0
		var p_mag = option_res.get("promo_mag_bonus") if option_res.get("promo_mag_bonus") != null else 0
		var p_def = option_res.get("promo_def_bonus") if option_res.get("promo_def_bonus") != null else 0
		var p_res = option_res.get("promo_res_bonus") if option_res.get("promo_res_bonus") != null else 0
		var p_spd = option_res.get("promo_spd_bonus") if option_res.get("promo_spd_bonus") != null else 0
		var p_agi = option_res.get("promo_agi_bonus") if option_res.get("promo_agi_bonus") != null else 0

		# Format stat bonuses dynamically
		stats.text += "HP:  +" + str(p_hp) + "    STR: +" + str(p_str) + "\n"
		stats.text += "MAG: +" + str(p_mag) + "    DEF: +" + str(p_def) + "\n"
		stats.text += "RES: +" + str(p_res) + "    SPD: +" + str(p_spd) + "\n"
		stats.text += "AGI: +" + str(p_agi) + "\n"

		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.add_theme_font_size_override("font_size", 32)
		vbox.add_child(stats)

		var weapons_label = RichTextLabel.new()
		weapons_label.bbcode_enabled = true
		weapons_label.fit_content = true
		weapons_label.scroll_active = false
		weapons_label.custom_minimum_size = Vector2(0, 120)
		weapons_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		weapons_label.bbcode_text = "[center][color=gold]" + field._format_class_weapon_permissions(option_res) + "[/color][/center]"
		vbox.add_child(weapons_label)

		var new_sprite_tex = option_res.get("promoted_battle_sprite")
		if new_sprite_tex != null:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 20)
			vbox.add_child(spacer)

			var icon_rect = TextureRect.new()
			icon_rect.texture = new_sprite_tex
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.custom_minimum_size = Vector2(160, 160)
			icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			vbox.add_child(icon_rect)

		# --- NEW: HOVER EFFECTS ---
		btn.mouse_entered.connect(func():
			var tween = field.create_tween().set_parallel(true)
			# Pop the scale up slightly
			tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)
			# Shift to a glowing, warm golden tint
			tween.tween_property(btn, "modulate", Color(1.2, 1.15, 1.0), 0.1)
		)

		btn.mouse_exited.connect(func():
			var tween = field.create_tween().set_parallel(true)
			# Return to normal
			tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
			tween.tween_property(btn, "modulate", Color.WHITE, 0.1)
		)

		# Hook up the button click
		btn.pressed.connect(func():
			if field.select_sound and field.select_sound.stream:
				field.select_sound.play()
			field.emit_signal("promotion_chosen", option_res)
		)
		hbox.add_child(btn)

	# Cancel button at the bottom
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.add_theme_font_size_override("font_size", 36)
	cancel_btn.custom_minimum_size = Vector2(300, 80)
	cancel_btn.pivot_offset = cancel_btn.custom_minimum_size / 2.0
	cancel_btn.position = Vector2((vp_size.x - 300) / 2, vp_size.y - 120)

	# Cancel button hover effect (subtle red tint)
	cancel_btn.mouse_entered.connect(func():
		var tween = field.create_tween().set_parallel(true)
		tween.tween_property(cancel_btn, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)
		tween.tween_property(cancel_btn, "modulate", Color(1.2, 0.9, 0.9), 0.1)
	)
	cancel_btn.mouse_exited.connect(func():
		var tween = field.create_tween().set_parallel(true)
		tween.tween_property(cancel_btn, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_OUT)
		tween.tween_property(cancel_btn, "modulate", Color.WHITE, 0.1)
	)

	cancel_btn.pressed.connect(func():
		if field.select_sound and field.select_sound.stream:
			field.select_sound.play()
		field.emit_signal("promotion_chosen", null)
	)
	promo_layer.add_child(cancel_btn)

	# Wait for the player to click a card or Cancel
	var final_choice = await field.promotion_chosen

	# Destroy the UI once a choice is made
	promo_layer.queue_free()

	return final_choice
