import os

def replace_in_file(path, old_str, new_str):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    if old_str in content:
        content = content.replace(old_str, new_str)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Replaced string in {path}")
    else:
        print(f"Could not find old_str in {path}")

# 1. Sync Burst
old_burst_sync = '''	if b.get("id") == "studio" and play_sting_on_studio_beat:
		_begin_studio_sting_sequence()'''

new_burst_sync = '''	if b.get("id") == "studio":
		if play_sting_on_studio_beat:
			_begin_studio_sting_sequence()
		# Trigger the burst immediately when the tween/sting starts, instead of waiting for the slide to finish!
		_burst_sparkles_outward()'''

replace_in_file('Scripts/UI/StudioIntro.gd', old_burst_sync, new_burst_sync)

old_burst_cleanup = '''	var code := await _await_tween_with_skip(tw_in, root, true)
	if code != 0 or _is_leaving:
		_finalize_beat_panel(root)
		return

	if b.get("id") == "studio":
		_burst_sparkles_outward()'''

new_burst_cleanup = '''	var code := await _await_tween_with_skip(tw_in, root, true)
	if code != 0 or _is_leaving:
		_finalize_beat_panel(root)
		return'''

replace_in_file('Scripts/UI/StudioIntro.gd', old_burst_cleanup, new_burst_cleanup)

# 2. Round Particles instead of ColorRect
old_spawn = '''	_sparkle_phase.clear()
	_sparkle_twinkle_speed.clear()
	var viewport_size: Vector2 = get_viewport_rect().size
	for i in count:
		var dot := ColorRect.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var px_size: int = _sparkle_rng.randi_range(maxi(1, sparkles_min_size), maxi(maxi(1, sparkles_min_size), sparkles_max_size))
		dot.custom_minimum_size = Vector2(px_size, px_size)
		dot.size = Vector2(px_size, px_size)
		var base_alpha: float = _sparkle_rng.randf_range(clampf(sparkles_alpha_min, 0.02, 1.0), clampf(maxf(sparkles_alpha_min, sparkles_alpha_max), 0.02, 1.0))
		dot.color = Color(sparkles_tint.r, sparkles_tint.g, sparkles_tint.b, base_alpha)'''

new_spawn = '''	_sparkle_phase.clear()
	_sparkle_twinkle_speed.clear()
	var viewport_size: Vector2 = get_viewport_rect().size
	
	var img = Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	var center = Vector2(8, 8)
	var radius = 7.0
	for x in range(16):
		for y in range(16):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				var alpha = clampf(1.0 - (dist / radius), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, alpha * alpha))
			else:
				img.set_pixel(x, y, Color(1, 1, 1, 0))
	var tex = ImageTexture.create_from_image(img)
	
	for i in count:
		var dot := Sprite2D.new()
		dot.texture = tex
		var px_size: float = float(_sparkle_rng.randi_range(maxi(1, sparkles_min_size), maxi(maxi(1, sparkles_min_size), sparkles_max_size)))
		dot.scale = Vector2(px_size / 16.0, px_size / 16.0)
		var base_alpha: float = _sparkle_rng.randf_range(clampf(sparkles_alpha_min, 0.02, 1.0), clampf(maxf(sparkles_alpha_min, sparkles_alpha_max), 0.02, 1.0))
		dot.modulate = Color(sparkles_tint.r, sparkles_tint.g, sparkles_tint.b, base_alpha)'''

replace_in_file('Scripts/UI/StudioIntro.gd', old_spawn, new_spawn)

# 3. Update 'color' to 'modulate' in _update_sparkles
old_update = '''		var base_alpha: float = _sparkle_base_alpha[i]
		var phase: float = _sparkle_phase[i]
		var speed: float = _sparkle_twinkle_speed[i]
		var twinkle: float = 0.78 + 0.22 * sin((twinkle_time * speed) + phase)
		dot.color = Color('''

new_update = '''		var base_alpha: float = _sparkle_base_alpha[i]
		var phase: float = _sparkle_phase[i]
		var speed: float = _sparkle_twinkle_speed[i]
		var twinkle: float = 0.78 + 0.22 * sin((twinkle_time * speed) + phase)
		dot.modulate = Color('''

replace_in_file('Scripts/UI/StudioIntro.gd', old_update, new_update)

# Also need to fix the type hint in _update_sparkles loop
old_dot_var = '''		var dot: ColorRect = _sparkles[i]'''
new_dot_var = '''		var dot: Sprite2D = _sparkles[i]'''
replace_in_file('Scripts/UI/StudioIntro.gd', old_dot_var, new_dot_var)

# And array type hint
old_array = '''var _sparkles: Array[ColorRect] = []'''
new_array = '''var _sparkles: Array[Sprite2D] = []'''
replace_in_file('Scripts/UI/StudioIntro.gd', old_array, new_array)
