extends RefCounted

const FLYING_GOLD_COIN_TEX: Texture2D = preload("res://Assets/Gold Coin.png")


static func _make_flying_coin_control(coin_px: int) -> TextureRect:
	var coin := TextureRect.new()
	coin.texture = FLYING_GOLD_COIN_TEX
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.custom_minimum_size = Vector2(coin_px, coin_px)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return coin


static func animate_flying_gold(field, world_pos: Vector2, amount: int) -> void:
	# 1. Bring back the floating text so you still see the big number instantly!
	field.spawn_loot_text("+ " + str(amount) + " G", Color(1.0, 0.9, 0.2), world_pos + Vector2(32, -32))
	var gold_lbl: Label = field.gold_label
	if gold_lbl == null:
		return

	# 2. Convert the 2D World Map position into Screen/UI coordinates
	var screen_pos = field.get_global_transform_with_canvas() * world_pos
	gold_lbl.pivot_offset = gold_lbl.size / 2.0

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
		var coin := _make_flying_coin_control(16)

		ui_root.add_child(coin)
		coin.global_position = screen_pos

		var t = field.create_tween()

		# Phase A: The Burst (All coins explode out simultaneously)
		var burst_offset = Vector2(randf_range(-70, 70), randf_range(-90, -30))
		t.tween_property(coin, "global_position", screen_pos + burst_offset, 0.3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)

		# Phase B: The STAGGERED Hangtime
		t.tween_interval(0.1 + (i * 0.05))

		# Phase C: Fly to the Bank!
		var target_pos = gold_lbl.global_position + (gold_lbl.size / 2.0) - (coin.custom_minimum_size / 2.0)
		t.tween_property(coin, "global_position", target_pos, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

		# Phase D: Impact!
		var is_last_coin = (i == coin_count - 1)

		t.tween_callback(func():
			coin.queue_free()

			# Tick up the UI number sequentially
			visual_gold_ref[0] += gold_per_coin
			if is_last_coin or visual_gold_ref[0] > field.player_gold:
				visual_gold_ref[0] = field.player_gold

			gold_lbl.text = "Gold: " + str(visual_gold_ref[0])

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
			gold_lbl.scale = Vector2(1.1, 1.1)
			var pulse = field.create_tween()
			pulse.tween_property(gold_lbl, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BOUNCE)
		)

