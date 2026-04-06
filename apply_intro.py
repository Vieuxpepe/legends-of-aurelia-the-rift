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

# 1. Staggered fade and slide
old_play_beat = '''	# Fade in (separate tween so completion is reliable across Godot versions).
	var tw_in := create_tween()
	tw_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_in.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(root, "modulate:a", 1.0, fade_in)
	if logo is Control and logo != null:
		tw_in.parallel().tween_property(logo as Control, "scale", Vector2.ONE, fade_in).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var code := await _await_tween_with_skip(tw_in, root, true)
	if code != 0 or _is_leaving:
		_finalize_beat_panel(root)
		return'''

new_play_beat = '''	# Fade in (separate tween so completion is reliable across Godot versions).
	var start_y = root.position.y
	root.position.y += 40.0
	root.modulate.a = 1.0 # Root stays solid, children stagger
	var tw_in := create_tween()
	tw_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_in.set_parallel(true)
	tw_in.tween_property(root, "position:y", start_y, fade_in + 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	var stagger_delay: float = 0.0
	for child in root.get_children():
		if child is Control and child.visible:
			child.modulate.a = 0.0
			tw_in.tween_property(child, "modulate:a", 1.0, fade_in).set_delay(stagger_delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			stagger_delay += 0.15
			
	if logo is Control and logo != null:
		tw_in.tween_property(logo as Control, "scale", Vector2.ONE, fade_in).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var code := await _await_tween_with_skip(tw_in, root, true)
	if code != 0 or _is_leaving:
		_finalize_beat_panel(root)
		return

	if b.get("id") == "studio":
		_burst_sparkles_outward()'''

replace_in_file('Scripts/UI/StudioIntro.gd', old_play_beat, new_play_beat)

# 2. Sparkle Burst injection
sparkle_update = '''		var vel: Vector2 = _sparkle_velocity[i]
		dot.position += vel * delta'''

sparkle_update_new = '''		var vel: Vector2 = _sparkle_velocity[i]
		var base_vy = sparkles_min_speed
		if eerie_atmosphere_enabled:
			base_vy += sparkle_sink_bias * 8.0
		# Apply drag to simulate magical explosion braking
		vel = vel.lerp(Vector2(_sparkle_rng.randf_range(-5.0, 5.0), base_vy), 1.8 * delta)
		_sparkle_velocity[i] = vel
		dot.position += vel * delta'''

replace_in_file('Scripts/UI/StudioIntro.gd', sparkle_update, sparkle_update_new)


burst_func = '''
func _burst_sparkles_outward() -> void:
	if not sparkles_enabled or _sparkles.is_empty():
		return
	var center = get_viewport_rect().size * 0.5
	for i in _sparkles.size():
		var dot = _sparkles[i]
		if dot == null: continue
		var dir = (dot.position - center).normalized()
		var p_force = _sparkle_rng.randf_range(150.0, 550.0)
		_sparkle_velocity[i] += dir * p_force
'''

# Append burst func to end of file
with open('Scripts/UI/StudioIntro.gd', 'a', encoding='utf-8') as f:
    f.write(burst_func)


# 3. Jump cut zoom
jump_cut_old = '''	var fade_duration: float = maxf(0.05, handoff_fade_out_seconds)
	var tw: Tween = create_tween()
	tw.tween_property(_handoff_black_rect, "modulate:a", 1.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:'''

jump_cut_new = '''	var fade_duration: float = maxf(0.05, handoff_fade_out_seconds)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_handoff_black_rect, "modulate:a", 1.0, fade_duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	if beats_root != null:
		beats_root.pivot_offset = beats_root.size * 0.5
		tw.tween_property(beats_root, "scale", Vector2(1.8, 1.8), fade_duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:'''

replace_in_file('Scripts/UI/StudioIntro.gd', jump_cut_old, jump_cut_new)
