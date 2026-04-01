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
	if attacker == null or not is_instance_valid(attacker):
		return 0

	# 1. THE TELEGRAPH
	field.screen_shake(5.0, 0.2)
	
	var clang = field.get_node_or_null("ClangSound")
	if clang != null and clang.stream != null:
		clang.pitch_scale = 0.5 # Deep wind-up sound
		clang.play()
		
	field.spawn_loot_text("FOCUS STRIKE!", Color(1.0, 0.5, 0.0), attacker.global_position + Vector2(32, -48), {"stack_anchor": attacker})
	
	await field.get_tree().create_timer(0.6).timeout
	
	# --- CINEMATIC LOCK ---
	var prev_paused = field.get_tree().paused
	field.get_tree().paused = true
	
	# 2. THE UI POP
	var qte_layer = CanvasLayer.new()
	qte_layer.layer = 100 
	qte_layer.process_mode = Node.PROCESS_MODE_ALWAYS # Keeps UI running while game is paused
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

	var lb_in: Tween = qte_layer.create_tween().set_parallel(true)
	lb_in.tween_property(top_bar, "size:y", letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lb_in.tween_property(bottom_bar, "size:y", letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lb_in.tween_property(bottom_bar, "position:y", vp_size.y - letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var flash_rect = ColorRect.new()
	flash_rect.size = vp_size
	flash_rect.color = Color.WHITE
	flash_rect.modulate = Color(1, 1, 1, 0)
	qte_layer.add_child(flash_rect)

	# The Background Bar
	var bar_bg = ColorRect.new()
	bar_bg.size = Vector2(400, 30)
	bar_bg.pivot_offset = bar_bg.size / 2.0
	bar_bg.position = (vp_size - bar_bg.size) / 2.0
	bar_bg.position.y -= 100 
	bar_bg.color = Color(0.1, 0.1, 0.1, 0.9)
	bar_bg.scale = Vector2(0.8, 0.8)
	bar_bg.modulate.a = 0.0
	qte_layer.add_child(bar_bg)
	
	var bar_pop: Tween = qte_layer.create_tween().set_parallel(true)
	bar_pop.tween_property(bar_bg, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bar_pop.tween_property(bar_bg, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# The Target Zone
	var target_zone = ColorRect.new()
	target_zone.size = Vector2(50, 30) 
	target_zone.position = Vector2(300, 0) # Near the end
	target_zone.color = Color(0.2, 0.8, 0.2, 0.85)
	bar_bg.add_child(target_zone)
	
	# The Perfect Zone
	var perfect_zone = ColorRect.new()
	perfect_zone.size = Vector2(16, 30)
	perfect_zone.position = Vector2((target_zone.size.x - perfect_zone.size.x) / 2.0, 0.0)
	perfect_zone.color = Color(1.0, 0.85, 0.2, 0.9)
	target_zone.add_child(perfect_zone)
	
	var pulse: Tween = qte_layer.create_tween().set_loops()
	pulse.tween_property(target_zone, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(target_zone, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# The Charging Fill Bar
	var fill_bar = ColorRect.new()
	fill_bar.size = Vector2(0, 30)
	fill_bar.position = Vector2.ZERO
	fill_bar.color = Color(1.0, 0.6, 0.0)
	bar_bg.add_child(fill_bar)
	
	var help_text = Label.new()
	help_text.text = "HOLD SPACE... RELEASE IN GREEN!"
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.add_theme_font_size_override("font_size", 24)
	bar_bg.add_child(help_text)
	help_text.position = Vector2(0, -40)
	help_text.size.x = bar_bg.size.x
	
	# 3. THE CHARGE LOOP (Time Tick Based for pausing immunity)
	var final_result = 0 # 0 = fail, 1 = nice, 2 = perfect
	var is_charging = false
	var finished = false
	var time_waiting = 0.0
	
	var fill_time = 1.2 # Takes 1.2 seconds to fill
	var charge_start_ms = 0
	
	while not finished:
		await field.get_tree().process_frame
		
		# If they haven't started holding Spacebar yet
		if not is_charging:
			time_waiting += field.get_process_delta_time()
			if time_waiting > 2.0: 
				finished = true
				help_text.text = "TOO SLOW!"
				help_text.add_theme_color_override("font_color", Color.RED)
				break
				
			if Input.is_action_just_pressed("ui_accept"):
				is_charging = true
				charge_start_ms = Time.get_ticks_msec()
				
		# If they are holding it
		else:
			var elapsed = Time.get_ticks_msec() - charge_start_ms
			var progress = float(elapsed) / (fill_time * 1000.0)
			fill_bar.size.x = progress * bar_bg.size.x
			
			# Check Release
			if Input.is_action_just_released("ui_accept"):
				finished = true
				var tip = fill_bar.size.x
				var tz_start = target_zone.position.x
				var tz_end = tz_start + target_zone.size.x
				var p_start = tz_start + perfect_zone.position.x
				var p_end = p_start + perfect_zone.size.x
				
				if tip >= tz_start and tip <= tz_end:
					var perfect = (tip >= p_start and tip <= p_end)
					final_result = 2 if perfect else 1 # <--- THE KEY UPDATE
					
					fill_bar.color = Color(1.0, 0.85, 0.2)
					target_zone.color = Color(1.0, 1.0, 1.0, 0.85)
					
					field.screen_shake(24.0 if perfect else 14.0, 0.3 if perfect else 0.2)
					
					if clang != null and clang.stream != null:
						clang.pitch_scale = randf_range(1.25, 1.45) if perfect else randf_range(1.15, 1.30)
						clang.play()
						
					flash_rect.modulate.a = 0.0
					var win_flash: Tween = qte_layer.create_tween()
					win_flash.tween_property(flash_rect, "modulate:a", 0.28 if perfect else 0.20, 0.05)
					win_flash.tween_property(flash_rect, "modulate:a", 0.00, 0.15)
					
					help_text.text = "PERFECT STRIKE!" if perfect else "NICE!"
					help_text.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if perfect else Color(0.2, 1.0, 0.2))
				else:
					final_result = 0
					fill_bar.color = Color(0.9, 0.25, 0.25)
					field.screen_shake(10.0, 0.18)
					if field.miss_sound.stream != null: field.miss_sound.play()
					
					flash_rect.modulate.a = 0.0
					var fail_flash: Tween = qte_layer.create_tween()
					fail_flash.tween_property(flash_rect, "modulate:a", 0.10, 0.03)
					fail_flash.tween_property(flash_rect, "modulate:a", 0.00, 0.10)
					
					help_text.text = "MISSED!"
					help_text.add_theme_color_override("font_color", Color.RED)
				break
				
			# Check Overcharge
			if fill_bar.size.x >= bar_bg.size.x:
				fill_bar.size.x = bar_bg.size.x
				finished = true
				final_result = 0
				fill_bar.color = Color(0.9, 0.25, 0.25)
				field.screen_shake(10.0, 0.18)
				if field.miss_sound.stream != null: field.miss_sound.play()
				
				help_text.text = "OVERCHARGED!"
				help_text.add_theme_color_override("font_color", Color.RED)
				break
				
	# 4. RESOLUTION HOLD AND CLEANUP
	await field.get_tree().create_timer(0.45, true, false, true).timeout # Pause-safe timer
	
	var lb_out: Tween = qte_layer.create_tween().set_parallel(true)
	lb_out.tween_property(top_bar, "size:y", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lb_out.tween_property(bottom_bar, "size:y", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lb_out.tween_property(bottom_bar, "position:y", vp_size.y, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await lb_out.finished
	
	qte_layer.queue_free()
	field.get_tree().paused = prev_paused
	
	# Returns 0 (Fail), 1 (Nice), or 2 (Perfect!)
	return final_result


static func run_bloodthirster_minigame(field, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker):
		return 0

	# 1. THE TELEGRAPH
	field.screen_shake(8.0, 0.3)
	
	var clang = field.get_node_or_null("ClangSound")
	if clang != null and clang.stream != null:
		clang.pitch_scale = 0.6 # Deep, sinister thud
		clang.play()
		
	field.spawn_loot_text("BLOODTHIRSTER!", Color(0.8, 0.1, 0.1), attacker.global_position + Vector2(32, -48), {"stack_anchor": attacker})
	
	await field.get_tree().create_timer(0.6).timeout
	
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
	screen_dimmer.color = Color(0.2, 0.0, 0.0, 0.4) # Dark red tint
	qte_layer.add_child(screen_dimmer)
	
	# Letterbox Bars
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

	var lb_in: Tween = qte_layer.create_tween().set_parallel(true)
	lb_in.tween_property(top_bar, "size:y", letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lb_in.tween_property(bottom_bar, "size:y", letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lb_in.tween_property(bottom_bar, "position:y", vp_size.y - letterbox_h, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var flash_rect = ColorRect.new()
	flash_rect.size = vp_size
	flash_rect.color = Color(0.8, 0.1, 0.1) # Red flash
	flash_rect.modulate = Color(1, 1, 1, 0)
	qte_layer.add_child(flash_rect)

	# Main Bar
	var bar_bg = ColorRect.new()
	bar_bg.size = Vector2(420, 34)
	bar_bg.position = (vp_size - bar_bg.size) / 2.0
	bar_bg.position.y -= 100.0
	bar_bg.color = Color(0.08, 0.08, 0.08, 0.95)
	bar_bg.scale = Vector2(0.9, 0.9)
	bar_bg.modulate.a = 0.0
	qte_layer.add_child(bar_bg)
	
	var bar_pop: Tween = qte_layer.create_tween().set_parallel(true)
	bar_pop.tween_property(bar_bg, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bar_pop.tween_property(bar_bg, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# The 3 Combo Target Zones
	var z_width = 30.0
	var targets = []
	var positions = [80.0, 200.0, 320.0] # Spread evenly across the bar
	
	for pos in positions:
		var tz = ColorRect.new()
		tz.size = Vector2(z_width, 34)
		tz.position = Vector2(pos, 0)
		tz.color = Color(0.4, 0.0, 0.0, 0.8) # Dull red until hit
		bar_bg.add_child(tz)
		targets.append(tz)
	
	var qte_cursor = ColorRect.new()
	qte_cursor.size = Vector2(8, 56)
	qte_cursor.position = Vector2(0, -11)
	qte_cursor.color = Color.WHITE
	bar_bg.add_child(qte_cursor)
	
	var help_text = Label.new()
	help_text.text = "TAP 3 TIMES!"
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.add_theme_font_size_override("font_size", 26)
	help_text.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
	help_text.position = Vector2(0, -52)
	help_text.size.x = bar_bg.size.x
	bar_bg.add_child(help_text)
	
	# 3. COMBO SWEEP LOOP
	var total_ms = 1400 # 1.4 seconds to sweep across
	var start_ms = Time.get_ticks_msec()
	
	var hits = 0
	var active_zone = 0
	var broken = false

	while true:
		await field.get_tree().process_frame
		var elapsed_ms = Time.get_ticks_msec() - start_ms
		
		if elapsed_ms >= total_ms:
			break
			
		var progress = float(elapsed_ms) / float(total_ms)
		qte_cursor.position.x = progress * bar_bg.size.x
		
		if not broken and active_zone < 3:
			var current_tz = targets[active_zone]
			var c_center = qte_cursor.position.x + (qte_cursor.size.x / 2.0)
			var tz_start = current_tz.position.x
			var tz_end = tz_start + current_tz.size.x
			
			# Check if cursor passed the zone without the player pressing space
			if c_center > tz_end + 5.0:
				broken = true
				qte_cursor.color = Color(0.4, 0.4, 0.4)
				current_tz.color = Color(0.2, 0.0, 0.0, 0.8)
				if field.miss_sound.stream != null: field.miss_sound.play()
				help_text.text = "COMBO DROPPED!"
				help_text.add_theme_color_override("font_color", Color.GRAY)
				field.screen_shake(8.0, 0.2)
				
			# Check if they pressed space
			elif Input.is_action_just_pressed("ui_accept"):
				# Give a tiny bit of leniency (8 pixels)
				if c_center >= tz_start - 8.0 and c_center <= tz_end + 8.0:
					hits += 1
					active_zone += 1
					current_tz.color = Color(1.0, 0.1, 0.1, 1.0) # Bright Crimson on hit!
					field.screen_shake(12.0, 0.15)
					
					# Pitch escalates with each successful hit
					if clang != null and clang.stream != null:
						clang.pitch_scale = 0.8 + (hits * 0.25) 
						clang.play()
						
					flash_rect.modulate.a = 0.0
					var hit_flash: Tween = qte_layer.create_tween()
					hit_flash.tween_property(flash_rect, "modulate:a", 0.15, 0.03)
					hit_flash.tween_property(flash_rect, "modulate:a", 0.00, 0.1)
				else:
					broken = true
					qte_cursor.color = Color(0.4, 0.4, 0.4)
					if field.miss_sound.stream != null: field.miss_sound.play()
					help_text.text = "MISSED!"
					help_text.add_theme_color_override("font_color", Color.GRAY)
					field.screen_shake(8.0, 0.2)
					
	# 4. FINAL RESOLUTION
	if hits == 3:
		help_text.text = "MAXIMUM BLOODSHED!"
		help_text.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
		field.screen_shake(20.0, 0.4)
		if field.crit_sound.stream != null: field.crit_sound.play()
		
	await field.get_tree().create_timer(0.45, true, false, true).timeout 
	
	var lb_out: Tween = qte_layer.create_tween().set_parallel(true)
	lb_out.tween_property(top_bar, "size:y", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lb_out.tween_property(bottom_bar, "size:y", 0.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lb_out.tween_property(bottom_bar, "position:y", vp_size.y, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await lb_out.finished
	
	qte_layer.queue_free()
	field.get_tree().paused = prev_paused
	return hits # Returns 0, 1, 2, or 3!


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

