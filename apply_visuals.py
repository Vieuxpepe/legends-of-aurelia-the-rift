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

# 1. Slide Intro
old_intro = '''func _prepare_intro_state() -> void:
	_layout_menu()
	main_vbox.visible = true
	campaign_vbox.visible = false
	slots_container.visible = false
	main_vbox.modulate.a = 0.0
	main_vbox.scale = Vector2(0.97, 0.97)
	campaign_vbox.modulate.a = 0.0
	campaign_vbox.scale = Vector2(0.97, 0.97)
	if intel_panel != null:
		intel_panel.modulate.a = 0.0
		intel_panel.position.y += 18.0
	if dispatch_panel != null:
		dispatch_panel.modulate.a = 0.0
		dispatch_panel.position.y += 18.0
	var intro := create_tween()
	intro.set_parallel(true)
	intro.tween_property(main_vbox, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro.tween_property(main_vbox, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if intel_panel != null:
		intro.tween_property(intel_panel, "modulate:a", 1.0, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		intro.tween_property(intel_panel, "position:y", intel_panel.position.y - 18.0, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if dispatch_panel != null:
		intro.tween_property(dispatch_panel, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		intro.tween_property(dispatch_panel, "position:y", dispatch_panel.position.y - 18.0, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)'''

new_intro = '''func _prepare_intro_state() -> void:
	_layout_menu()
	main_vbox.visible = true
	campaign_vbox.visible = false
	slots_container.visible = false
	main_vbox.modulate.a = 0.0
	main_vbox.position.x -= 80.0
	campaign_vbox.modulate.a = 0.0
	
	if intel_panel != null:
		intel_panel.modulate.a = 0.0
		intel_panel.position.x += 80.0
	if dispatch_panel != null:
		dispatch_panel.modulate.a = 0.0
		dispatch_panel.position.x += 80.0
		
	var intro := create_tween()
	intro.set_parallel(true)
	intro.tween_property(main_vbox, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro.tween_property(main_vbox, "position:x", main_vbox.position.x + 80.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if intel_panel != null:
		intro.tween_property(intel_panel, "modulate:a", 1.0, 0.40).set_delay(0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		intro.tween_property(intel_panel, "position:x", intel_panel.position.x - 80.0, 0.50).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if dispatch_panel != null:
		intro.tween_property(dispatch_panel, "modulate:a", 1.0, 0.40).set_delay(0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		intro.tween_property(dispatch_panel, "position:x", dispatch_panel.position.x - 80.0, 0.50).set_delay(0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)'''

replace_in_file('MainMenu.gd', old_intro, new_intro)

# 2. Hover states
old_hover = '''func _button_hover_entered(control: Control) -> void:
	if control == null:
		return
	var t := create_tween()
	t.tween_property(control, "scale", Vector2(1.02, 1.02), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)'''

new_hover = '''func _button_hover_entered(control: Control) -> void:
	if control == null:
		return
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(control, "scale", Vector2(1.03, 1.03), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if control is Button:
		t.tween_property(control, "modulate", Color(1.2, 1.15, 1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)'''
replace_in_file('MainMenu.gd', old_hover, new_hover)

old_hover_out = '''func _button_hover_exited(control: Control) -> void:
	if control == null:
		return
	var t := create_tween()
	t.tween_property(control, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)'''

new_hover_out = '''func _button_hover_exited(control: Control) -> void:
	if control == null:
		return
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(control, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if control is Button:
		t.tween_property(control, "modulate", Color.WHITE, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)'''
replace_in_file('MainMenu.gd', old_hover_out, new_hover_out)

# 3. Soften Panels 
old_main_panel = '''var fill := Color(0.23, 0.19, 0.13, 0.99).lerp(MENU_BG_ALT, 0.45)'''
new_main_panel = '''var fill := Color(0.12, 0.08, 0.05, 0.70)'''
replace_in_file('MainMenu.gd', old_main_panel, new_main_panel)

# 4. Particles 
old_atmosphere = '''	if backdrop_shade != null:
		backdrop_shade.modulate.a = 1.0
		var shade := create_tween()
		shade.set_loops()
		shade.tween_property(backdrop_shade, "modulate:a", 0.96, 7.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		shade.tween_property(backdrop_shade, "modulate:a", 1.0, 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)'''

new_atmosphere = '''	if backdrop_shade != null:
		backdrop_shade.modulate.a = 1.0
		var shade := create_tween()
		shade.set_loops()
		shade.tween_property(backdrop_shade, "modulate:a", 0.96, 7.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		shade.tween_property(backdrop_shade, "modulate:a", 1.0, 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var vp_size = get_viewport_rect().size
	
	# Vignette Overlay
	var vignette = ColorRect.new()
	vignette.color = Color(0.02, 0.015, 0.01, 0.40)
	vignette.size = vp_size
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.z_index = -1 
	add_child(vignette)
	var vig_t = create_tween().set_loops()
	vig_t.tween_property(vignette, "color:a", 0.50, 4.0).set_trans(Tween.TRANS_SINE)
	vig_t.tween_property(vignette, "color:a", 0.35, 4.0).set_trans(Tween.TRANS_SINE)

	# Particles
	var particles = CPUParticles2D.new()
	particles.amount = 80
	particles.lifetime = 12.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(vp_size.x, vp_size.y)
	particles.position = vp_size * 0.5
	particles.gravity = Vector2(5.0, -12.0)
	particles.initial_velocity_min = 5.0
	particles.initial_velocity_max = 20.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1.0, 0.7, 0.2, 0.7)
	var grad = Gradient.new()
	grad.add_point(0.0, Color(1,1,1,0))
	grad.add_point(0.2, Color(1,1,1,1))
	grad.add_point(0.8, Color(1,1,1,1))
	grad.add_point(1.0, Color(1,1,1,0))
	particles.color_ramp = grad
	particles.z_index = -1
	particles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(particles)'''
replace_in_file('MainMenu.gd', old_atmosphere, new_atmosphere)
