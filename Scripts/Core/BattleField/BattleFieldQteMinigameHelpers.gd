extends RefCounted

## Offensive / tactical QTE minigames + shared battlefield QTE UI polish.

static func apply_battlefield_qte_ui_polish(field, qte_layer: CanvasLayer, screen_dimmer: ColorRect, bar_bg: ColorRect, help_text: Label, top_bar: ColorRect, bottom_bar: ColorRect, accent: Color, title_text: String) -> void:
	if qte_layer == null or not is_instance_valid(qte_layer):
		return
	var vp_size: Vector2 = field.get_viewport_rect().size

	if screen_dimmer != null and is_instance_valid(screen_dimmer):
		screen_dimmer.color = Color(
			clampf(accent.r * 0.12, 0.0, 0.25),
			clampf(accent.g * 0.08, 0.0, 0.20),
			clampf(accent.b * 0.15, 0.0, 0.30),
			0.66
		)

	var atmosphere := ColorRect.new()
	atmosphere.name = "QteBattleAtmosphere"
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere.size = vp_size
	atmosphere.color = Color(
		clampf(accent.r * 0.10, 0.0, 0.18),
		clampf(accent.g * 0.08, 0.0, 0.14),
		clampf(accent.b * 0.12, 0.0, 0.20),
		0.28
	)
	atmosphere.z_index = -3
	qte_layer.add_child(atmosphere)
	qte_layer.move_child(atmosphere, 1)

	if top_bar != null:
		top_bar.color = Color(0.0, 0.0, 0.0, 0.90)
	if bottom_bar != null:
		bottom_bar.color = Color(0.0, 0.0, 0.0, 0.90)

	var title := Label.new()
	title.text = title_text
	title.position = Vector2(0.0, bar_bg.position.y - 124.0)
	title.size = Vector2(vp_size.x, 52.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(minf(accent.r + 0.10, 1.0), minf(accent.g + 0.10, 1.0), minf(accent.b + 0.10, 1.0), 1.0))
	title.add_theme_constant_override("outline_size", 7)
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	qte_layer.add_child(title)

	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.position = bar_bg.position + Vector2(-26.0, -20.0)
	frame.size = bar_bg.size + Vector2(52.0, 40.0)
	frame.z_index = -1
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.05, 0.06, 0.09, 0.80)
	frame_style.border_color = Color(accent.r, accent.g, accent.b, 0.72)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(14)
	frame_style.shadow_size = 20
	frame_style.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	frame.add_theme_stylebox_override("panel", frame_style)
	qte_layer.add_child(frame)

	var frame_glow := ColorRect.new()
	frame_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_glow.size = Vector2(frame.size.x - 22.0, 4.0)
	frame_glow.position = Vector2(11.0, 10.0)
	frame_glow.color = Color(accent.r, accent.g, accent.b, 0.56)
	frame.add_child(frame_glow)

	if help_text != null and is_instance_valid(help_text):
		help_text.add_theme_font_size_override("font_size", 28)
		help_text.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 0.98))
		help_text.add_theme_constant_override("outline_size", 5)
		help_text.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
		var help_tw: Tween = qte_layer.create_tween().set_loops()
		help_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		help_tw.tween_property(help_text, "modulate:a", 0.74, 0.45)
		help_tw.tween_property(help_text, "modulate:a", 0.98, 0.45)

	var title_tw: Tween = qte_layer.create_tween().set_loops()
	title_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	title_tw.tween_property(title, "modulate:a", 0.86, 0.66)
	title_tw.tween_property(title, "modulate:a", 1.0, 0.66)


static func run_focused_strike_minigame(field, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	
	field.screen_shake(5.0, 0.2)
	var clang = field.get_node_or_null("ClangSound")
	if clang != null and clang.stream != null:
		clang.pitch_scale = 0.5
		clang.play()
	field.spawn_loot_text("FOCUS STRIKE!", Color(1.0, 0.5, 0.0), attacker.global_position + Vector2(32, -48), {"stack_anchor": attacker})
	await field.get_tree().create_timer(0.6).timeout
	
	var qte = QTEHoldReleaseBar.run(field, "FOCUS STRIKE!", "HOLD SPACE... RELEASE IN GREEN!", 1200)
	var res = await qte.qte_finished
	return res


static func run_bloodthirster_minigame(field, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	
	field.screen_shake(8.0, 0.3)
	var clang = field.get_node_or_null("ClangSound")
	if clang != null and clang.stream != null:
		clang.pitch_scale = 0.6
		clang.play()
	field.spawn_loot_text("BLOODTHIRSTER!", Color(0.8, 0.1, 0.1), attacker.global_position + Vector2(32, -48), {"stack_anchor": attacker})
	await field.get_tree().create_timer(0.6).timeout
	
	var qte = QTEComboSweepBar.run(field, "BLOODTHIRSTER", "TAP 3 TIMES!", [80.0, 200.0, 320.0], 1400)
	var res = await qte.qte_finished
	return res


static func run_hundred_point_strike_minigame(field, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker):
		return 0

	# 1. THE TELEGRAPH
	field.screen_shake(6.0, 0.2)
	
	if field.has_node("ClangSound") and field.get_node("ClangSound").stream != null:
		field.get_node("ClangSound").pitch_scale = 1.5 # Fast, sharp ring
		field.get_node("ClangSound").play()
		
	field.spawn_loot_text("HUNDRED POINT STRIKE!", Color(0.9, 0.2, 1.0), attacker.global_position + Vector2(32, -48), {"stack_anchor": attacker})
	
	await field.get_tree().create_timer(0.7).timeout
	
	# --- CINEMATIC LOCK ---
	var prev_paused = field.get_tree().paused
	field.get_tree().paused = true

	# 2. THE UI POP
	var qte_layer = CanvasLayer.new()
	qte_layer.layer = 100 
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	field.add_child(qte_layer)
	
	var vp_size = field.get_viewport_rect().size
	
	var screen_dimmer = ColorRect.new()
	screen_dimmer.size = vp_size
	screen_dimmer.color = Color(0.1, 0.0, 0.2, 0.6) # Deep purple tint
	qte_layer.add_child(screen_dimmer)
	
	# The Prompt Box (Shows the Arrow Key)
	var prompt_box = ColorRect.new()
	prompt_box.size = Vector2(120, 120)
	prompt_box.position = (vp_size - prompt_box.size) / 2.0
	prompt_box.position.y -= 50
	prompt_box.color = Color(0.1, 0.1, 0.1, 0.9)
	qte_layer.add_child(prompt_box)
	
	var prompt_label = Label.new()
	prompt_label.text = "â†‘"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 80)
	prompt_label.add_theme_color_override("font_color", Color.WHITE)
	prompt_label.size = prompt_box.size
	prompt_box.add_child(prompt_label)
	
	# The Timer Bar (Shrinks down)
	var timer_bar = ProgressBar.new()
	timer_bar.max_value = 100
	timer_bar.value = 100
	timer_bar.size = Vector2(300, 20)
	timer_bar.position = Vector2((vp_size.x - 300) / 2.0, prompt_box.position.y + 140)
	timer_bar.show_percentage = false
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.9, 0.2, 1.0)
	timer_bar.add_theme_stylebox_override("fill", fill_style)
	qte_layer.add_child(timer_bar)
	
	# Combo Counter
	var combo_label = Label.new()
	combo_label.text = "HITS: 0"
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 40)
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	combo_label.position = Vector2(0, prompt_box.position.y - 60)
	combo_label.size.x = vp_size.x
	qte_layer.add_child(combo_label)

	# 3. THE COMBO LOOP
	var actions = ["ui_up", "ui_down", "ui_left", "ui_right"]
	var arrows = ["UP â†‘", "DOWN â†“", "LEFT â†", "RIGHT â†’"]
	
	var hits = 0
	var current_target = randi() % 4
	prompt_label.text = arrows[current_target]
	
	# Base time is 1.2 seconds. It will shrink as the combo grows!
	var max_time_for_hit = 1.2 
	var time_left = max_time_for_hit
	var failed = false

	# We clear the input buffer so they don't accidentally fail on frame 1
	Input.flush_buffered_events()

	while not failed:
		await field.get_tree().process_frame
		var delta = field.get_process_delta_time()
		time_left -= delta
		
		# Update visual bar
		timer_bar.value = (time_left / max_time_for_hit) * 100.0
		
		# Did they run out of time?
		if time_left <= 0:
			failed = true
			prompt_box.color = Color(0.8, 0.1, 0.1) # Turn red
			prompt_label.text = "X"
			if field.miss_sound.stream != null: field.miss_sound.play()
			break
			
		# Check for player inputs
		var pressed_any = false
		var hit_correct = false
		
		for i in range(4):
			if Input.is_action_just_pressed(actions[i]):
				pressed_any = true
				if i == current_target:
					hit_correct = true
				break # Stop checking other keys if they pressed one
				
		if pressed_any:
			if hit_correct:
				# SUCCESS!
				hits += 1
				combo_label.text = "HITS: " + str(hits)
				
				# Play pitch-escalating sound
				if field.select_sound.stream != null:
					field.select_sound.pitch_scale = min(1.0 + (hits * 0.1), 2.5)
					field.select_sound.play()
					
				# Make the game harder! Shrink the time limit by 12% (min 0.25s)
				max_time_for_hit = max(0.25, max_time_for_hit * 0.88)
				time_left = max_time_for_hit
				
				# Pick a new random key
				current_target = randi() % 4
				prompt_label.text = arrows[current_target]
				
				# Micro flash for feedback
				prompt_box.modulate = Color(2.0, 2.0, 2.0)
				var flash: Tween = qte_layer.create_tween()
				flash.tween_property(prompt_box, "modulate", Color.WHITE, 0.05)
				
			else:
				# WRONG KEY PRESSED!
				failed = true
				prompt_box.color = Color(0.8, 0.1, 0.1) 
				prompt_label.text = "X"
				if field.miss_sound.stream != null: field.miss_sound.play()
				break

	# 4. RESOLUTION HOLD
	field.screen_shake(10.0, 0.2)
	await field.get_tree().create_timer(0.6, true, false, true).timeout 
	
	qte_layer.queue_free()
	field.get_tree().paused = prev_paused
	return hits


static func run_tactical_action_minigame(field, attacker: Node2D, ability_name: String) -> bool:
	if attacker == null or not is_instance_valid(attacker): return false

	# 1) TELEGRAPH
	field.screen_shake(6.0, 0.2)
	var clang = field.get_node_or_null("ClangSound")
	if clang != null and clang.stream != null:
		clang.pitch_scale = 1.8 # High-pitched windup
		clang.play()

	field.spawn_loot_text("MOMENTUM!", Color(0.2, 1.0, 1.0), attacker.global_position + Vector2(32, -48), {"stack_anchor": attacker})

	await field.get_tree().create_timer(0.45).timeout

	# --- CINEMATIC LOCK ---
	var prev_paused = field.get_tree().paused
	field.get_tree().paused = true

	# 2) UI POP
	var qte_layer = CanvasLayer.new()
	qte_layer.layer = 100
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS 
	field.add_child(qte_layer)

	var vp_size = field.get_viewport_rect().size

	var screen_dimmer = ColorRect.new()
	screen_dimmer.size = vp_size
	screen_dimmer.color = Color(0, 0.1, 0.2, 0.3) # Slight blue tint
	qte_layer.add_child(screen_dimmer)

	# Bar
	var bar_bg = ColorRect.new()
	bar_bg.size = Vector2(380, 30)
	bar_bg.pivot_offset = bar_bg.size / 2.0
	bar_bg.position = (vp_size - bar_bg.size) / 2.0
	bar_bg.position.y += 100.0 # Put it below the action
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.95)
	bar_bg.scale = Vector2(0.86, 0.86)
	bar_bg.modulate.a = 0.0
	qte_layer.add_child(bar_bg)

	var bar_pop: Tween = qte_layer.create_tween().set_parallel(true)
	bar_pop.tween_property(bar_bg, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bar_pop.tween_property(bar_bg, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# The "Perfect" Sweet Spot (Small and Green)
	var perfect_zone = ColorRect.new()
	perfect_zone.size = Vector2(40, 30)
	var rand_max = bar_bg.size.x - perfect_zone.size.x
	perfect_zone.position = Vector2(randf_range(50.0, rand_max), 0.0)
	perfect_zone.color = Color(0.2, 1.0, 0.2, 0.9)
	bar_bg.add_child(perfect_zone)

	var qte_cursor = ColorRect.new()
	qte_cursor.size = Vector2(8, 50)
	qte_cursor.position = Vector2(0, -10)
	qte_cursor.color = Color.WHITE
	bar_bg.add_child(qte_cursor)

	var help_text = Label.new()
	help_text.text = "STOP IN GREEN FOR +DAMAGE & TRAP DURATION!" if ability_name == "Fire Trap" else "STOP IN GREEN FOR 2x DISTANCE!"
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.add_theme_font_size_override("font_size", 24)
	help_text.add_theme_color_override("font_color", Color.CYAN)
	bar_bg.add_child(help_text)
	help_text.position = Vector2(0, 40)
	help_text.size.x = bar_bg.size.x

	# 3) TIMING LOOP 
	var total_ms = 700 # Very fast!
	var start_ms = Time.get_ticks_msec()
	var is_perfect = false
	var pressed = false

	while true:
		await field.get_tree().process_frame
		var elapsed_ms = Time.get_ticks_msec() - start_ms

		if elapsed_ms >= total_ms: break

		var progress = float(elapsed_ms) / float(total_ms)
		qte_cursor.position.x = progress * bar_bg.size.x

		if Input.is_action_just_pressed("ui_accept"):
			pressed = true
			var cursor_center = qte_cursor.position.x + (qte_cursor.size.x / 2.0)
			var p_start = perfect_zone.position.x
			var p_end = p_start + perfect_zone.size.x

			if cursor_center >= p_start and cursor_center <= p_end:
				is_perfect = true
				qte_cursor.color = Color.YELLOW
				perfect_zone.color = Color.WHITE
				field.screen_shake(15.0, 0.25)

				if clang != null and clang.stream != null:
					clang.pitch_scale = 1.3
					clang.play()
				
				help_text.text = "MAXIMUM POWER!"
				help_text.add_theme_color_override("font_color", Color.YELLOW)
			else:
				qte_cursor.color = Color(0.9, 0.25, 0.25)
				if field.miss_sound.stream != null: field.miss_sound.play()
				help_text.text = "NORMAL " + ability_name.to_upper()
				help_text.add_theme_color_override("font_color", Color.GRAY)
			break

	if not pressed:
		if field.miss_sound.stream != null: field.miss_sound.play()
		help_text.text = "NORMAL " + ability_name.to_upper()
		help_text.add_theme_color_override("font_color", Color.GRAY)

	await field.get_tree().create_timer(0.45, true, false, true).timeout 

	qte_layer.queue_free()
	field.get_tree().paused = prev_paused
	
	return is_perfect

