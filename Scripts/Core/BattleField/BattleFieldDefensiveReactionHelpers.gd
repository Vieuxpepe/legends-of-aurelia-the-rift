extends RefCounted

static func run_parry_minigame(field, defender: Node2D) -> bool:
	if defender == null or not is_instance_valid(defender):
		return false

	# 1) TELEGRAPH
	var clang = field.get_node_or_null("ClangSound")
	if clang != null and clang.stream != null:
		clang.pitch_scale = randf_range(0.85, 0.95)
		clang.play()

	field.spawn_loot_text("PARRY!", Color(1.0, 0.8, 0.2), defender.global_position + Vector2(32, -48), {"stack_anchor": defender})

	field.screen_shake(6.0, 0.2)
	await field.get_tree().create_timer(0.45).timeout

	# --- CINEMATIC LOCK (Freeze the game) ---
	var prev_paused = field.get_tree().paused
	field.get_tree().paused = true

	# 2) UI POP (cinematic letterbox + flash + pop-in)
	var qte_layer = CanvasLayer.new()
	qte_layer.layer = 100
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS # Keeps running while paused
	field.add_child(qte_layer)

	var vp_size = field.get_viewport_rect().size

	var screen_dimmer = ColorRect.new()
	screen_dimmer.size = vp_size
	screen_dimmer.color = Color(0, 0, 0, 0.35)
	qte_layer.add_child(screen_dimmer)

	# Letterbox bars
	var letterbox_h = 56.0
	var top_bar = ColorRect.new()
	top_bar.color = Color(0, 0, 0, 0.85)
	top_bar.size = Vector2(vp_size.x, 0.0)
	qte_layer.add_child(top_bar)

	var bottom_bar = ColorRect.new()
	bottom_bar.color = Color(0, 0, 0, 0.85)
	bottom_bar.position = Vector2(0.0, vp_size.y)
	bottom_bar.size = Vector2(vp_size.x, 0.0)
	qte_layer.add_child(bottom_bar)

	# Use qte_layer.create_tween() so the animations play while the game is paused
	var lb_in = qte_layer.create_tween().set_parallel(true)
	lb_in.tween_property(top_bar, "size:y", letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lb_in.tween_property(bottom_bar, "size:y", letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lb_in.tween_property(bottom_bar, "position:y", vp_size.y - letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Screen flash
	var flash_rect = ColorRect.new()
	flash_rect.size = vp_size
	flash_rect.color = Color.WHITE
	flash_rect.modulate = Color(1, 1, 1, 0)
	qte_layer.add_child(flash_rect)

	var intro_flash = qte_layer.create_tween()
	intro_flash.tween_property(flash_rect, "modulate:a", 0.18, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro_flash.tween_property(flash_rect, "modulate:a", 0.00, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Bar
	var bar_bg = ColorRect.new()
	bar_bg.size = Vector2(420, 34)
	bar_bg.pivot_offset = bar_bg.size / 2.0
	bar_bg.position = (vp_size - bar_bg.size) / 2.0
	bar_bg.position.y -= 100.0
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.95)
	bar_bg.scale = Vector2(0.86, 0.86)
	bar_bg.modulate.a = 0.0
	qte_layer.add_child(bar_bg)

	var bar_pop = qte_layer.create_tween().set_parallel(true)
	bar_pop.tween_property(bar_bg, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bar_pop.tween_property(bar_bg, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Target zone
	var target_zone = ColorRect.new()
	target_zone.size = Vector2(92, 34)
	target_zone.color = Color(0.2, 0.8, 0.2, 0.85)
	var rand_max = bar_bg.size.x - target_zone.size.x
	target_zone.position = Vector2(randf_range(100.0, rand_max), 0.0)
	bar_bg.add_child(target_zone)

	var perfect_zone = ColorRect.new()
	perfect_zone.size = Vector2(26, 34)
	perfect_zone.position = Vector2((target_zone.size.x - perfect_zone.size.x) / 2.0, 0.0)
	perfect_zone.color = Color(1.0, 0.85, 0.2, 0.9)
	target_zone.add_child(perfect_zone)

	# Pulse the target zone
	var pulse = qte_layer.create_tween().set_loops()
	pulse.tween_property(target_zone, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(target_zone, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var qte_cursor = ColorRect.new()
	qte_cursor.size = Vector2(10, 56)
	qte_cursor.position = Vector2(0, -11)
	qte_cursor.color = Color.WHITE
	bar_bg.add_child(qte_cursor)

	var help_text = Label.new()
	help_text.text = "PRESS SPACE"
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.add_theme_font_size_override("font_size", 26)
	bar_bg.add_child(help_text)
	help_text.position = Vector2(0, -52)
	help_text.size.x = bar_bg.size.x
	field._apply_battlefield_qte_ui_polish(
		qte_layer,
		screen_dimmer,
		bar_bg,
		help_text,
		top_bar,
		bottom_bar,
		Color(1.0, 0.84, 0.30, 1.0),
		"PARRY"
	)

	# 3) TIMING LOOP (Uses Time.get_ticks_msec so it works while paused)
	var total_ms = 650
	var start_ms = Time.get_ticks_msec()
	var success = false
	var pressed = false
	var perfect = false

	while true:
		await field.get_tree().process_frame
		var elapsed_ms = Time.get_ticks_msec() - start_ms

		if elapsed_ms >= total_ms:
			break

		var progress = float(elapsed_ms) / float(total_ms)
		qte_cursor.position.x = progress * bar_bg.size.x

		if Input.is_action_just_pressed("ui_accept"):
			pressed = true

			var cursor_center = qte_cursor.position.x + (qte_cursor.size.x / 2.0)
			var tz_start = target_zone.position.x
			var tz_end = tz_start + target_zone.size.x
			var p_start = tz_start + perfect_zone.position.x
			var p_end = p_start + perfect_zone.size.x

			if cursor_center >= tz_start and cursor_center <= tz_end:
				success = true
				perfect = (cursor_center >= p_start and cursor_center <= p_end)

				qte_cursor.color = Color(1.0, 0.85, 0.2)
				target_zone.color = Color(1.0, 1.0, 1.0, 0.85)

				field.screen_shake(24.0 if perfect else 14.0, 0.30 if perfect else 0.25)

				if clang != null and clang.stream != null:
					clang.pitch_scale = randf_range(1.25, 1.45) if perfect else randf_range(1.15, 1.30)
					clang.play()

				flash_rect.modulate.a = 0.0
				var win_flash = qte_layer.create_tween()
				win_flash.tween_property(flash_rect, "modulate:a", 0.28 if perfect else 0.20, 0.05)
				win_flash.tween_property(flash_rect, "modulate:a", 0.00, 0.15)

				help_text.text = "PERFECT!" if perfect else "NICE!"
				help_text.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if perfect else Color(0.2, 1.0, 0.2))

			else:
				success = false
				qte_cursor.color = Color(0.9, 0.25, 0.25)
				field.screen_shake(10.0, 0.18)

				if field.miss_sound.stream != null:
					field.miss_sound.play()

				flash_rect.modulate.a = 0.0
				var fail_flash = qte_layer.create_tween()
				fail_flash.tween_property(flash_rect, "modulate:a", 0.10, 0.03)
				fail_flash.tween_property(flash_rect, "modulate:a", 0.00, 0.10)

				help_text.text = "MISS!"
				help_text.add_theme_color_override("font_color", Color.RED)

			break

	if not pressed:
		success = false
		if field.miss_sound.stream != null:
			field.miss_sound.play()
		help_text.text = "TOO SLOW!"
		help_text.add_theme_color_override("font_color", Color.RED)

	await field.get_tree().create_timer(0.45, true, false, true).timeout # Pause-safe timer

	# Letterbox out
	var lb_out = qte_layer.create_tween().set_parallel(true)
	lb_out.tween_property(top_bar, "size:y", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lb_out.tween_property(bottom_bar, "size:y", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lb_out.tween_property(bottom_bar, "position:y", vp_size.y, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await lb_out.finished

	qte_layer.queue_free()
	field.get_tree().paused = prev_paused
	return success


# --- ABILITY 2: SHIELD CLASH (Mashing QTE) ---
# Returns 0 (Fail), 1 (Block), 2 (Perfect Counter)
static func run_shield_clash_minigame(field, defender: Node2D, attacker: Node2D) -> int:
	# 1. CALCULATE WEIGHT ADVANTAGE
	# MoveType Enum: INFANTRY=0, ARMORED=1, FLYING=2, CAVALRY=3
	var def_type = defender.get("move_type") if defender.get("move_type") != null else 0
	var atk_type = attacker.get("move_type") if attacker.get("move_type") != null else 0

	# Convert MoveTypes into "Weight/Mass"
	var get_weight = func(m_type: int) -> int:
		if m_type == 1: return 3   # ARMORED (Heaviest)
		if m_type == 3: return 2   # CAVALRY (Heavy)
		if m_type == 0: return 1   # INFANTRY (Standard)
		if m_type == 2: return 0   # FLYING (Lightest)
		return 1

	var weight_diff = get_weight.call(def_type) - get_weight.call(atk_type)

	# Adjust the difficulty math based on the weight difference!
	var mash_power = 12.0 + (weight_diff * 1.5)  # Heavy defenders gain more per tap
	var enemy_pushback = 35.0 - (weight_diff * 5.0) # Heavy attackers push the bar down faster

	# 2. THE TELEGRAPH (Warning Phase)
	field.screen_shake(10.0, 0.3)

	if field.has_node("ShieldBashSound") and field.get_node("ShieldBashSound").stream != null:
		field.get_node("ShieldBashSound").pitch_scale = randf_range(0.85, 0.95)
		field.get_node("ShieldBashSound").play()

	field.spawn_loot_text("SHIELD CLASH!", Color(0.8, 0.9, 1.0), defender.global_position + Vector2(32, -48), {"stack_anchor": defender})

	await field.get_tree().create_timer(1.2).timeout

	# 3. THE UI POP
	var qte_layer = CanvasLayer.new()
	qte_layer.layer = 100
	field.add_child(qte_layer)

	var screen_dimmer = ColorRect.new()
	screen_dimmer.size = field.get_viewport_rect().size
	screen_dimmer.color = Color(0, 0, 0, 0.3)
	qte_layer.add_child(screen_dimmer)

	var bar = ProgressBar.new()
	bar.max_value = 100
	bar.value = 50.0
	bar.custom_minimum_size = Vector2(400, 40)
	bar.show_percentage = false
	bar.position = (field.get_viewport_rect().size - bar.size) / 2.0
	bar.position.y -= 100

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.8, 0.1, 0.1, 0.9)
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.5, 1.0, 1.0)
	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)

	qte_layer.add_child(bar)

	var help_text = Label.new()
	help_text.text = "MASH SPACE!"
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.add_theme_font_size_override("font_size", 32)
	help_text.add_theme_color_override("font_color", Color(1.0, 0.4, 0.0))
	qte_layer.add_child(help_text)
	help_text.position = bar.position + Vector2(0, -50)
	help_text.size.x = bar.size.x

	# --- NEW: SHOW WEIGHT ADVANTAGE UI ---
	var adv_text = Label.new()
	if weight_diff > 0:
		adv_text.text = "WEIGHT ADVANTAGE"
		adv_text.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2)) # Green
	elif weight_diff < 0:
		adv_text.text = "WEIGHT DISADVANTAGE!"
		adv_text.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2)) # Red
	else:
		adv_text.text = "EVEN MATCH"
		adv_text.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7)) # Gray

	adv_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	adv_text.add_theme_font_size_override("font_size", 18)
	qte_layer.add_child(adv_text)
	adv_text.position = bar.position + Vector2(0, 45)
	adv_text.size.x = bar.size.x

	# 4. THE TUG-OF-WAR LOOP
	var time_left = 3.0
	var final_result = 0

	while time_left > 0:
		await field.get_tree().process_frame
		var delta = field.get_process_delta_time()
		time_left -= delta

		# The enemy constantly pushes back (using the weight math!)
		bar.value -= enemy_pushback * delta

		if Input.is_action_just_pressed("ui_accept"):
			bar.value += mash_power # Player pushes forward (using weight math!)

			bar.modulate = Color(2.0, 2.0, 2.0)
			var flash = field.create_tween()
			flash.tween_property(bar, "modulate", Color.WHITE, 0.05)

		if bar.value >= 100.0:
			if time_left >= 1.5:
				final_result = 2
			else:
				final_result = 1
			break

		if bar.value <= 0.0:
			final_result = 0
			break

	# 5. RESOLUTION FEEDBACK
	if final_result > 0:
		var is_perfect = (final_result == 2)
		help_text.text = "PERFECT COUNTER!" if is_perfect else "GUARD HELD!"
		help_text.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if is_perfect else Color(0.2, 1.0, 0.2))
		adv_text.text = "" # Clear the advantage text on win

		field.screen_shake(25.0 if is_perfect else 15.0, 0.35)

		if field.has_node("ShieldBashSound") and field.get_node("ShieldBashSound").stream != null:
			field.get_node("ShieldBashSound").pitch_scale = randf_range(1.1, 1.25) if is_perfect else randf_range(0.95, 1.05)
			field.get_node("ShieldBashSound").play()
	else:
		help_text.text = "GUARD BROKEN!"
		help_text.add_theme_color_override("font_color", Color.RED)
		adv_text.text = ""
		if field.miss_sound.stream != null:
			field.miss_sound.play()

	await field.get_tree().create_timer(0.4).timeout

	qte_layer.queue_free()
	return final_result


# --- ABILITY 6: LAST STAND (Lethal Blow Survival) ---
static func run_last_stand_minigame(field, defender: Node2D) -> bool:
	if defender == null or not is_instance_valid(defender):
		return false

	# 1) THE EXTENDED TELEGRAPH (The Heartbeat)
	# We use 1.5 seconds to build tension so the player can get their thumb ready
	var clang = field.get_node_or_null("ClangSound")

	# Heartbeat 1
	field.screen_shake(8.0, 0.2)
	if clang:
		clang.pitch_scale = 0.4
		clang.play()

	field.spawn_loot_text("LETHAL BLOW!", Color(1.0, 0.1, 0.1), defender.global_position + Vector2(32, -48), {"stack_anchor": defender})

	await field.get_tree().create_timer(0.6).timeout

	# Heartbeat 2 (Faster, Higher pitch, New Text)
	field.screen_shake(12.0, 0.2)
	if clang:
		clang.pitch_scale = 0.6
		clang.play()

	field.spawn_loot_text("GET READY...", Color(1.0, 0.8, 0.2), defender.global_position + Vector2(32, -80), {"stack_anchor": defender})

	# Final pause to let the player focus
	await field.get_tree().create_timer(0.7).timeout

	# --- CINEMATIC LOCK ---
	var prev_paused = field.get_tree().paused
	field.get_tree().paused = true

	var qte_layer = CanvasLayer.new()
	qte_layer.layer = 100
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	field.add_child(qte_layer)

	var vp_size = field.get_viewport_rect().size

	# 2) UI SETUP
	var screen_dimmer = ColorRect.new()
	screen_dimmer.size = vp_size
	screen_dimmer.color = Color(0.4, 0.0, 0.0, 0.7)
	qte_layer.add_child(screen_dimmer)

	var letterbox_h = 56.0
	var top_bar = ColorRect.new()
	top_bar.color = Color(0, 0, 0, 0.85)
	top_bar.size = Vector2(vp_size.x, 0.0)
	qte_layer.add_child(top_bar)

	var bottom_bar = ColorRect.new()
	bottom_bar.color = Color(0, 0, 0, 0.85)
	bottom_bar.position = Vector2(0.0, vp_size.y)
	bottom_bar.size = Vector2(vp_size.x, 0.0)
	qte_layer.add_child(bottom_bar)

	var lb_in = qte_layer.create_tween().set_parallel(true)
	lb_in.tween_property(top_bar, "size:y", letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lb_in.tween_property(bottom_bar, "size:y", letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lb_in.tween_property(bottom_bar, "position:y", vp_size.y - letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var flash_rect = ColorRect.new()
	flash_rect.size = vp_size
	flash_rect.color = Color.RED
	flash_rect.modulate = Color(1, 1, 1, 0)
	qte_layer.add_child(flash_rect)

	var bar_bg = ColorRect.new()
	bar_bg.size = Vector2(420, 34)
	bar_bg.pivot_offset = bar_bg.size / 2.0
	bar_bg.position = (vp_size - bar_bg.size) / 2.0
	bar_bg.position.y -= 100.0
	bar_bg.color = Color(0.05, 0.05, 0.05, 0.95)
	bar_bg.scale = Vector2(0.86, 0.86)
	bar_bg.modulate.a = 0.0
	qte_layer.add_child(bar_bg)

	var bar_pop = qte_layer.create_tween().set_parallel(true)
	bar_pop.tween_property(bar_bg, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bar_pop.tween_property(bar_bg, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var target_zone = ColorRect.new()
	target_zone.size = Vector2(40, 34)
	target_zone.color = Color(1.0, 0.8, 0.2, 0.9)
	var rand_max = bar_bg.size.x - target_zone.size.x
	target_zone.position = Vector2(randf_range(150.0, rand_max), 0.0)
	bar_bg.add_child(target_zone)

	var qte_cursor = ColorRect.new()
	qte_cursor.size = Vector2(10, 56)
	qte_cursor.position = Vector2(0, -11)
	qte_cursor.color = Color.WHITE
	bar_bg.add_child(qte_cursor)

	var help_text = Label.new()
	help_text.text = "DEFY DEATH!"
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.add_theme_font_size_override("font_size", 32)
	help_text.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	bar_bg.add_child(help_text)
	help_text.position = Vector2(0, -55)
	help_text.size.x = bar_bg.size.x
	field._apply_battlefield_qte_ui_polish(
		qte_layer,
		screen_dimmer,
		bar_bg,
		help_text,
		top_bar,
		bottom_bar,
		Color(1.0, 0.26, 0.20, 1.0),
		"LAST STAND"
	)

	# 3) TIMING LOOP (Speed is still the same: 0.45s)
	var total_ms = 600
	var start_ms = Time.get_ticks_msec()
	var success = false
	var pressed = false

	while true:
		await field.get_tree().process_frame
		var elapsed_ms = Time.get_ticks_msec() - start_ms

		if elapsed_ms >= total_ms:
			break

		var progress = float(elapsed_ms) / float(total_ms)
		qte_cursor.position.x = progress * bar_bg.size.x

		if Input.is_action_just_pressed("ui_accept"):
			pressed = true
			var cursor_center = qte_cursor.position.x + (qte_cursor.size.x / 2.0)
			var tz_start = target_zone.position.x
			var tz_end = tz_start + target_zone.size.x

			if cursor_center >= tz_start and cursor_center <= tz_end:
				success = true
				qte_cursor.color = Color(1.0, 1.0, 1.0)
				target_zone.color = Color(1.0, 1.0, 1.0, 1.0)
				help_text.text = "SURVIVED!"
				help_text.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
				field.screen_shake(30.0, 0.4)
				if clang:
					clang.pitch_scale = 1.5
					clang.play()
				flash_rect.color = Color.WHITE
				flash_rect.modulate.a = 0.6
				var win_flash = qte_layer.create_tween()
				win_flash.tween_property(flash_rect, "modulate:a", 0.00, 0.25)
			else:
				success = false
				qte_cursor.color = Color(0.3, 0.0, 0.0)
				help_text.text = "FAILED"
				flash_rect.color = Color.BLACK
				flash_rect.modulate.a = 0.5
				var fail_flash = qte_layer.create_tween()
				fail_flash.tween_property(flash_rect, "modulate:a", 0.00, 0.15)
			break

	if not pressed:
		success = false
		help_text.text = "TOO SLOW"

	await field.get_tree().create_timer(0.5, true, false, true).timeout

	var lb_out = qte_layer.create_tween().set_parallel(true)
	lb_out.tween_property(top_bar, "size:y", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lb_out.tween_property(bottom_bar, "size:y", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lb_out.tween_property(bottom_bar, "position:y", vp_size.y, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await lb_out.finished

	qte_layer.queue_free()
	field.get_tree().paused = prev_paused
	return success

