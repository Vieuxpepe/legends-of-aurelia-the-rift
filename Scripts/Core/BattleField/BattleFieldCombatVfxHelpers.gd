extends RefCounted


static func spawn_dash_effect(field, start_pos: Vector2, target_pos: Vector2) -> void:
	if field.dash_fx_scene == null:
		print("WARNING: Dash FX Scene is missing! Assign it in the Battlefield Inspector!")
		return

	var fx = field.dash_fx_scene.instantiate()
	field.add_child(fx)

	fx.z_index = 100

	# Position exactly at the unit's feet
	fx.global_position = start_pos + Vector2(32, 60)

	# --- FIX: NO ROTATION! ---
	# We force rotation to 0 so the dust never looks like it's falling sideways.
	fx.rotation = 0

	# --- FIX: SMART HORIZONTAL FLIPPING ---
	var move_dir_x = target_pos.x - start_pos.x

	if move_dir_x > 0:
		# Moving RIGHT: Inverted for your specific sprite sheet
		fx.flip_h = false
	elif move_dir_x < 0:
		# Moving LEFT: Inverted for your specific sprite sheet
		fx.flip_h = true
	else:
		# Moving purely UP or DOWN:
		# Randomly flip it horizontally so it doesn't look identical every time!
		fx.flip_h = randf() > 0.5

	fx.scale = Vector2(randf_range(1.0, 1.3), randf_range(0.8, 1.2))


static func spawn_slash_effect(field, target_pos: Vector2, attacker_pos: Vector2, is_crit: bool = false) -> void:
	if field.slash_fx_scene == null:
		print("WARNING: Slash FX Scene is missing! Assign it in the Battlefield Inspector!")
		return

	var fx = field.slash_fx_scene.instantiate()
	field.add_child(fx)

	fx.z_index = 110 # Make sure it draws above the units!

	# Center it on the defender's chest
	fx.global_position = target_pos + Vector2(32, 32)

	# Point the slash so it cuts FROM the attacker TO the defender
	var dir = (target_pos - attacker_pos).normalized()

	# Add a tiny bit of random angle so combo hits don't look perfectly identical
	fx.rotation = dir.angle() + randf_range(-0.3, 0.3)

	# Randomly flip the "blade" orientation
	if randf() > 0.5:
		fx.flip_v = true

	# --- THE JUICE: MAKE CRITS ENORMOUS ---
	if is_crit:
		fx.scale = Vector2(2.5, 2.5)
		fx.modulate = Color(1.5, 1.2, 1.2, 1.0) # Over-brighten it
	else:
		fx.scale = Vector2(1.3, 1.3)


static func spawn_level_up_effect(field, target_pos: Vector2) -> void:
	if field.level_up_fx_scene == null:
		print("WARNING: Level Up FX Scene is missing! Assign it in the Battlefield Inspector!")
		return

	var fx = field.level_up_fx_scene.instantiate()
	field.add_child(fx)

	fx.z_index = 110 # Draw above units

	# CRITICAL: Force the code to also ignore the pause state just in case!
	fx.process_mode = Node.PROCESS_MODE_ALWAYS

	# Position it at the unit's feet.
	# (Adjust the Y value if the beam needs to go higher/lower based on your sprite sheet cuts)
	fx.global_position = target_pos + Vector2(32, 48)

	# Make it large enough to encompass the whole unit!
	fx.scale = Vector2(3.0, 3.0)


static func spawn_blood_splatter(field, target_unit: Node2D, attacker_pos: Vector2, is_crit: bool = false) -> void:
	var target_name = target_unit.get("unit_name")
	if target_name == null:
		return

	# 1. THE LOGIC CHECK: Remove "Skeleton" from this list if you want them to bleed!
	var no_blood_types = ["Wooden Crate", "Spawner Tent", "Portable Fort", "Skeleton", "Risen Dead"]
	if no_blood_types.has(target_name):
		return

	var blood = CPUParticles2D.new()
	field.add_child(blood)

	blood.z_index = 105
	blood.global_position = target_unit.global_position + Vector2(32, 32)
	blood.emitting = false
	blood.one_shot = true

	# ==========================================
	# --- 2. THE BURST UPGRADE ---
	# ==========================================
	# 1.0 means ALL particles spawn instantly on the exact same frame!
	blood.explosiveness = 1.0

	# Increased the amount of droplets for a thicker spray
	blood.amount = 60 if is_crit else 25

	var dir = (target_unit.global_position - attacker_pos).normalized()
	blood.direction = dir

	# Widened from 35 to 75 so it sprays out in a wide, violent fan
	blood.spread = 75.0

	# Heavier gravity and much faster velocity so it whips out and drops fast
	blood.gravity = Vector2(0, 800)
	blood.initial_velocity_min = 250.0
	blood.initial_velocity_max = 550.0 if is_crit else 350.0

	blood.scale_amount_min = 3.0
	blood.scale_amount_max = 7.0

	# --- NEW: SHRINK OVER TIME ---
	# This makes the droplets shrink as they fly, making it look like real liquid dispersing!
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1)) # Start at 100% size
	curve.add_point(Vector2(1, 0)) # End at 0% size
	blood.scale_amount_curve = curve

	# Brighter crimson color so it pops against the dark backgrounds
	blood.color = Color(0.8, 0.0, 0.0, 1.0)

	blood.restart()
	field.get_tree().create_timer(1.5, true, false, true).timeout.connect(blood.queue_free)

