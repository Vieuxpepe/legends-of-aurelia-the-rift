extends RefCounted


static func animate_flying_gold(field, world_pos: Vector2, amount: int) -> void:
	# 1. Bring back the floating text so you still see the big number instantly!
	field.spawn_loot_text("+ " + str(amount) + " G", Color(1.0, 0.9, 0.2), world_pos + Vector2(32, -32))

	# 2. Convert the 2D World Map position into Screen/UI coordinates
	var screen_pos = field.get_global_transform_with_canvas() * world_pos
	field.gold_label.pivot_offset = field.gold_label.size / 2.0

	# 3. THE FIX: 1-to-1 coin mapping, capped at 20 coins max!
	var coin_count = amount
	if amount > 20:
		coin_count = 20 # Hard cap so massive drops don't lag or take forever to finish

	# 4. Setup the Visual Counter (ref so lambda can update it)
	var visual_gold_ref: Array = [field.player_gold - amount]
	var gold_per_coin = int(ceil(float(amount) / float(coin_count)))

	# 5. Spawn the fountain of coins!
	var ui_root = field.get_node("UI")
	for i in range(coin_count):
		var coin = Panel.new()
		coin.custom_minimum_size = Vector2(16, 16)

		var style = StyleBoxFlat.new()
		style.bg_color = Color(1.0, 0.85, 0.1) # Shiny Gold
		style.border_width_bottom = 2
		style.border_color = Color(0.7, 0.4, 0.0) # Shadow for depth
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		coin.add_theme_stylebox_override("panel", style)

		ui_root.add_child(coin)
		coin.global_position = screen_pos

		var t = field.create_tween()

		# Phase A: The Burst (All coins explode out simultaneously)
		var burst_offset = Vector2(randf_range(-70, 70), randf_range(-90, -30))
		t.tween_property(coin, "global_position", screen_pos + burst_offset, 0.3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)

		# Phase B: The STAGGERED Hangtime
		t.tween_interval(0.1 + (i * 0.05))

		# Phase C: Fly to the Bank!
		var target_pos = field.gold_label.global_position + (field.gold_label.size / 2.0) - (coin.custom_minimum_size / 2.0)
		t.tween_property(coin, "global_position", target_pos, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

		# Phase D: Impact!
		var is_last_coin = (i == coin_count - 1)

		t.tween_callback(func():
			coin.queue_free()

			# Tick up the UI number sequentially
			visual_gold_ref[0] += gold_per_coin
			if is_last_coin or visual_gold_ref[0] > field.player_gold:
				visual_gold_ref[0] = field.player_gold

			field.gold_label.text = "Gold: " + str(visual_gold_ref[0])

			# Play a rapid "clinking" sound
			if field.select_sound and field.select_sound.stream != null:
				var p = AudioStreamPlayer.new()
				p.stream = field.select_sound.stream
				p.pitch_scale = randf_range(1.8, 2.3)
				p.volume_db = -12.0
				field.add_child(p)
				p.play()
				p.finished.connect(p.queue_free)

			# Micro-bounce the UI Label
			field.gold_label.scale = Vector2(1.1, 1.1)
			var pulse = field.create_tween()
			pulse.tween_property(field.gold_label, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BOUNCE)
		)

