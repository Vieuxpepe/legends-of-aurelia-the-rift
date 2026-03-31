extends RefCounted


static func create_evolution_buildup_vfx(field, target_pos: Vector2) -> CPUParticles2D:
	var vfx = CPUParticles2D.new()
	field.add_child(vfx)
	vfx.global_position = target_pos
	vfx.amount = 50
	vfx.lifetime = 1.5
	vfx.preprocess = 0.5 # Start already looking full
	vfx.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	vfx.emission_sphere_radius = 20.0
	vfx.gravity = Vector2(0, -98) # Float upwards
	vfx.direction = Vector2(0, -1)
	vfx.spread = 20.0
	vfx.initial_velocity_min = 30.0
	vfx.initial_velocity_max = 60.0
	# Start small and yellow, end big and transparent orange
	vfx.scale_amount_min = 2.0
	vfx.scale_amount_max = 5.0
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 0.8, 0.2, 1)) # Yellow
	gradient.set_color(1, Color(1, 0.4, 0, 0)) # Fade to Orange transparent
	vfx.color_ramp = gradient
	return vfx


static func create_evolution_burst_vfx(field, target_pos: Vector2) -> CPUParticles2D:
	var vfx = CPUParticles2D.new()
	field.add_child(vfx)
	vfx.global_position = target_pos
	vfx.emitting = false
	vfx.one_shot = true

	# --- 1. TRIPLE THE PARTICLES ---
	vfx.amount = 300
	vfx.lifetime = 1.5 # Give them time to fly off screen before dying
	vfx.explosiveness = 1.0 # All at once
	vfx.direction = Vector2(0, -1)
	vfx.spread = 180.0 # Full circle burst
	vfx.gravity = Vector2(0, 0)

	# --- 2. MASSIVE VELOCITY (Blasts off the screen!) ---
	vfx.initial_velocity_min = 800.0
	vfx.initial_velocity_max = 1600.0

	# --- 3. HUGE PARTICLES ---
	vfx.scale_amount_min = 8.0
	vfx.scale_amount_max = 25.0

	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1)) # White hot center
	gradient.set_color(1, Color(1, 0.7, 0, 0)) # Fade to rich gold transparent
	vfx.color_ramp = gradient

	return vfx

