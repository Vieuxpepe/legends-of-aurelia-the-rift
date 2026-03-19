extends Control
class_name DragonActor

@onready var shadow: Control = $Shadow
@onready var body_pivot: Control = $BodyPivot
@onready var sprite: TextureRect = $BodyPivot/SpriteRect
@onready var name_label: Label = $NameLabel
@onready var aura_particles: CPUParticles2D = $BodyPivot/AuraParticles
@onready var roar_player: AudioStreamPlayer = $RoarPlayer
@export var roar_sounds: Array[AudioStream] = []
@export var roar_volume_db: float = -6.0

var is_hovered: bool = false
var dragon_data: Dictionary = {}
var element: String = "Fire"
var current_stage: int = 0

var facing: float = 1.0
var behavior_active: bool = false
var is_busy: bool = false
var is_selected: bool = false

var base_pulse_speed: float = 2.0
var base_glow_alpha: float = 0.35
var base_aura_amount: int = 8

var movement_tween: Tween
var body_tween: Tween
var idle_tween: Tween
var select_tween: Tween
var element_tween: Tween
var hover_tween: Tween
var reaction_tween: Tween

var dragon_uid: String = ""

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

const GLOW_SHADER: Shader = preload("res://elemental_glow.gdshader")

func _ready() -> void:
	rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func refresh_name_only() -> void:
	_refresh_name()
	_refresh_visual_emphasis(true)

func _exit_tree() -> void:
	behavior_active = false
	_kill_tween(movement_tween)
	_kill_tween(body_tween)
	_kill_tween(idle_tween)
	_kill_tween(select_tween)
	_kill_tween(element_tween)
	_kill_tween(hover_tween)
	_kill_tween(reaction_tween)

func setup(data: Dictionary) -> void:
	dragon_uid = str(data.get("uid", ""))
	dragon_data = data
	element = str(data.get("element", "Fire"))
	current_stage = int(data.get("stage", 1))

	var old_bottom_center: Vector2 = position + Vector2(size.x * 0.5, size.y)
	var had_previous_size: bool = size != Vector2.ZERO

	var target_size: Vector2 = _get_stage_size(current_stage)

	custom_minimum_size = target_size
	size = target_size
	pivot_offset = Vector2(size.x * 0.5, size.y)

	body_pivot.position = Vector2.ZERO
	body_pivot.size = target_size
	body_pivot.pivot_offset = Vector2(size.x * 0.5, size.y * 0.82)
	# FLIPPED: -facing because art faces left by default
	body_pivot.scale = Vector2(-facing, 1.0)
	body_pivot.rotation = 0.0

	sprite.position = Vector2.ZERO
	sprite.size = target_size
	sprite.scale = Vector2.ONE
	sprite.rotation = 0.0
	sprite.modulate = Color(1, 1, 1, 1)

	shadow.size = Vector2(target_size.x * 0.72, target_size.x * 0.22)
	shadow.position = Vector2(
		(target_size.x - shadow.size.x) * 0.5,
		(target_size.y * 0.82) - (shadow.size.y * 0.5)
	)
	shadow.scale = Vector2.ONE
	shadow.modulate = Color(1, 1, 1, 0.72)

	if not (sprite.material is ShaderMaterial):
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = GLOW_SHADER
		sprite.material = mat

	_configure_aura(target_size)
	_apply_element_identity()
	_refresh_name()
	_refresh_visual_emphasis(true)

	if had_previous_size:
		position = old_bottom_center - Vector2(size.x * 0.5, size.y)

	_clamp_inside_parent()

	if current_stage > 0 and not behavior_active:
		behavior_active = true
		_behavior_loop()
		_breathing_loop()
		_element_loop()

func show_float_text(text: String, color: Color) -> void:
	_spawn_float_text(text, color)
		
func _get_stage_size(stage: int) -> Vector2:
	match stage:
		0: return Vector2(48, 48)    # Egg
		1: return Vector2(160, 160)  # Baby
		2: return Vector2(160, 160)  # Juvenile
		3: return Vector2(220, 220)  # Adult
		_: return Vector2(160, 160)

func _configure_aura(target_size: Vector2) -> void:
	base_aura_amount = 8 if current_stage <= 1 else 12

	aura_particles.position = Vector2(target_size.x * 0.5, target_size.y * 0.5)
	aura_particles.emission_rect_extents = Vector2(target_size.x * 0.24, target_size.y * 0.22)
	aura_particles.amount = base_aura_amount
	aura_particles.lifetime = 1.2
	aura_particles.explosiveness = 0.0
	aura_particles.randomness = 0.65
	aura_particles.emitting = current_stage > 0

func _apply_element_identity() -> void:
	var mat: ShaderMaterial = sprite.material as ShaderMaterial
	if mat == null:
		return

	# Reset shared defaults first
	aura_particles.position = Vector2(size.x * 0.5, size.y * 0.5)
	aura_particles.gravity = Vector2.ZERO
	aura_particles.radial_accel_min = 0.0
	aura_particles.radial_accel_max = 0.0
	aura_particles.tangential_accel_min = 0.0
	aura_particles.tangential_accel_max = 0.0
	aura_particles.initial_velocity_min = 10.0
	aura_particles.initial_velocity_max = 20.0
	aura_particles.scale_amount_min = 3.0
	aura_particles.scale_amount_max = 6.0

	match element:
		"Fire":
			sprite.texture = load("res://Assets/Sprites/fire_dragon_sprite.png")
			base_pulse_speed = 4.0
			base_glow_alpha = 0.42
			mat.set_shader_parameter("element_color", Color(1.0, 0.55, 0.12, 1.0))
			aura_particles.color = Color(1.0, 0.6, 0.15, 0.9)
			aura_particles.gravity = Vector2(0, -55)
			aura_particles.initial_velocity_min = 16.0
			aura_particles.initial_velocity_max = 30.0
		"Ice":
			sprite.texture = load("res://Assets/Sprites/ice_dragon_sprite.png")
			base_pulse_speed = 1.1
			base_glow_alpha = 0.26
			mat.set_shader_parameter("element_color", Color(0.82, 0.95, 1.0, 1.0))
			aura_particles.color = Color(0.88, 0.96, 1.0, 0.85)
			aura_particles.gravity = Vector2(0, 14)
			aura_particles.initial_velocity_min = 5.0
			aura_particles.initial_velocity_max = 12.0
		"Lightning":
			sprite.texture = load("res://Assets/Sprites/lightning_dragon_sprite.png")
			base_pulse_speed = 10.0
			base_glow_alpha = 0.40
			mat.set_shader_parameter("element_color", Color(1.0, 0.93, 0.35, 1.0))
			aura_particles.color = Color(1.0, 0.95, 0.4, 0.9)
			aura_particles.gravity = Vector2.ZERO
			aura_particles.radial_accel_min = 45.0
			aura_particles.radial_accel_max = 90.0
			aura_particles.initial_velocity_min = 18.0
			aura_particles.initial_velocity_max = 35.0
		"Earth":
			sprite.texture = load("res://Assets/Sprites/earth_dragon_sprite.png")
			base_pulse_speed = 0.7
			base_glow_alpha = 0.22
			mat.set_shader_parameter("element_color", Color(0.56, 0.72, 0.36, 1.0))
			aura_particles.color = Color(0.45, 0.40, 0.28, 0.8)
			aura_particles.gravity = Vector2(0, 75)
			aura_particles.position = Vector2(size.x * 0.5, size.y * 0.70)
			aura_particles.initial_velocity_min = 6.0
			aura_particles.initial_velocity_max = 12.0
		"Wind":
			sprite.texture = load("res://Assets/Sprites/wind_dragon_sprite.png")
			base_pulse_speed = 2.0
			base_glow_alpha = 0.30
			mat.set_shader_parameter("element_color", Color(0.82, 1.0, 0.96, 1.0))
			aura_particles.color = Color(0.78, 1.0, 0.95, 0.85)
			aura_particles.gravity = Vector2(0, -8)
			aura_particles.tangential_accel_min = -28.0
			aura_particles.tangential_accel_max = 28.0
			aura_particles.initial_velocity_min = 10.0
			aura_particles.initial_velocity_max = 18.0
		_:
			base_pulse_speed = 2.0
			base_glow_alpha = 0.30
			mat.set_shader_parameter("element_color", Color.WHITE)
			aura_particles.color = Color.WHITE

	mat.set_shader_parameter("pulse_speed", base_pulse_speed)
	mat.set_shader_parameter("glow_alpha", base_glow_alpha)

func _refresh_name() -> void:
	name_label.text = str(dragon_data.get("name", "Dragon"))
	name_label.custom_minimum_size = Vector2(120, 28)
	name_label.position = Vector2((size.x * 0.5) - 60.0, -25.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.scale = Vector2.ONE
	name_label.rotation = 0.0

func _refresh_visual_emphasis(immediate: bool = false) -> void:
	var mat: ShaderMaterial = sprite.material as ShaderMaterial

	var pulse_mult: float = 1.0
	var glow_add: float = 0.0
	var aura_bonus: int = 0
	var name_scale: Vector2 = Vector2.ONE
	var sprite_color: Color = Color(1, 1, 1, 1)
	var shadow_alpha: float = 0.72

	if is_selected:
		pulse_mult += 0.60
		glow_add += 0.10
		aura_bonus += 3
		name_scale = Vector2(1.08, 1.08)
		sprite_color = Color(1.08, 1.08, 1.08, 1.0)
		shadow_alpha = 0.95

	if is_hovered:
		pulse_mult += 0.60
		glow_add += 0.06
		aura_bonus += 4
		name_scale += Vector2(0.04, 0.04)
		sprite_color = sprite_color.lerp(Color(1.12, 1.12, 1.12, 1.0), 0.5)
		shadow_alpha = max(shadow_alpha, 0.88)

	if _has_trait("Magic Blooded") or _has_trait("Elder Arcana"):
		pulse_mult += 0.12
		glow_add += 0.03
		aura_bonus += 2

	var target_pulse: float = base_pulse_speed * pulse_mult
	var target_glow: float = base_glow_alpha + glow_add
	var target_amount: int = base_aura_amount + aura_bonus

	if mat != null:
		mat.set_shader_parameter("pulse_speed", target_pulse)
		mat.set_shader_parameter("glow_alpha", target_glow)

	aura_particles.amount = target_amount

	_kill_tween(select_tween)

	if immediate:
		name_label.scale = name_scale
		sprite.modulate = sprite_color
		shadow.modulate.a = shadow_alpha
	else:
		select_tween = create_tween()
		select_tween.tween_property(name_label, "scale", name_scale, 0.12)
		select_tween.parallel().tween_property(sprite, "modulate", sprite_color, 0.12)
		select_tween.parallel().tween_property(shadow, "modulate:a", shadow_alpha, 0.12)

func _breathing_loop() -> void:
	while is_instance_valid(self) and behavior_active:
		if current_stage <= 0:
			await get_tree().create_timer(0.5).timeout
			continue

		if is_busy:
			await get_tree().create_timer(0.2).timeout
			continue

		_kill_tween(idle_tween)
		idle_tween = create_tween()

		var breathe_in: float = rng.randf_range(0.8, 1.2)
		var breathe_out: float = rng.randf_range(1.0, 1.6)

		idle_tween.tween_property(sprite, "scale", Vector2(1.018, 0.985), breathe_in).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		idle_tween.parallel().tween_property(name_label, "position:y", -27.0, breathe_in).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		idle_tween.tween_property(sprite, "scale", Vector2.ONE, breathe_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		idle_tween.parallel().tween_property(name_label, "position:y", -25.0, breathe_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		await idle_tween.finished

# ==========================================
# THE DYNAMIC BEHAVIOR ENGINE
# ==========================================
func _behavior_loop() -> void:
	while is_instance_valid(self) and behavior_active:
		# -------------------------------------------------
		# Age-stage pacing (older = less frequent actions)
		# Stage mapping (DragonManager.DragonStage):
		# 1 = Baby, 2 = Juvenile, 3 = Adult
		# -------------------------------------------------
		var stage_wait_mult: float = 1.0
		match current_stage:
			1:
				stage_wait_mult = 0.80
			2:
				stage_wait_mult = 1.00
			3:
				stage_wait_mult = 1.25
			_:
				stage_wait_mult = 1.10
		
		var wait_time: float = rng.randf_range(1.5, 3.5) * stage_wait_mult

		# Modify wait time based on traits
		if _has_trait("Swift") or _has_trait("Lightning Reflexes"):
			wait_time *= 0.6
		elif _has_trait("Thick Scales") or _has_trait("Adamant Hide"):
			wait_time *= 1.4

		if is_hovered:
			wait_time *= 0.85

		await get_tree().create_timer(wait_time).timeout

		if not is_instance_valid(self) or not behavior_active or is_busy or current_stage <= 0:
			continue

		# --- BUILD THE ACTION DECK ---
		var actions: Array[String] = ["wander", "wander", "look", "hop", "tail"]

		# Add personality based on traits
		if _has_trait("Cunning") or _has_trait("Mastermind"):
			actions.append("look")
			actions.append("look")
		if _has_trait("Loyal") or _has_trait("Heartbound"):
			actions.append("social")
			actions.append("social")
		if _has_trait("Fierce") or _has_trait("Savage"):
			actions.append("proud")
			actions.append("proud")

		# Add stage-specific behaviors
		# Zoomies: babies get lots, juveniles some, adults rarely.
		var zoomies_cards: int = 0
		match current_stage:
			1: zoomies_cards = 4
			2: zoomies_cards = 2
			3: zoomies_cards = 1
			_: zoomies_cards = 1
		# Traits can add a bit more zoomies, but age still dominates.
		if _has_trait("Swift") or _has_trait("Lightning Reflexes"):
			zoomies_cards += 1
		zoomies_cards = clampi(zoomies_cards, 0, 6)
		for i in range(zoomies_cards):
			actions.append("zoomies")

		# Sleep: babies/juveniles nap more often; adults less often.
		var sleep_cards: int = 0
		match current_stage:
			1: sleep_cards = 3
			2: sleep_cards = 2
			3: sleep_cards = 1
			_: sleep_cards = 1
		if _has_trait("Thick Scales") or _has_trait("Adamant Hide"):
			sleep_cards += 1
		sleep_cards = clampi(sleep_cards, 0, 5)
		for j in range(sleep_cards):
			actions.append("sleep")

		# Breaths are restricted to Adults unless Magic Blooded!
		if current_stage >= 3 or _has_trait("Magic Blooded") or _has_trait("Elder Arcana"):
			actions.append("breath")
			actions.append("breath")

		# Element-specific specials
		if element == "Wind" and current_stage >= 2:
			actions.append("hover")
			actions.append("hover")
		if element == "Earth":
			actions.append("dig")
			actions.append("dig")

		# Pick a random action from the weighted deck
		var chosen: String = actions[rng.randi() % actions.size()]

		match chosen:
			"wander": await _wander_once()
			"look": await _play_look_around()
			"hop": await _play_hop_in_place()
			"social": await _play_social_idle()
			"tail": await _play_tail_swish()
			"proud": await _play_proud_pose()
			"breath": await _play_elemental_breath()
			"sleep": await _play_sleep()
			"zoomies": await _play_zoomies()
			"hover": await _play_hover()
			"dig": await _play_dig()

# --- NEW BEHAVIOR: SLEEP ---
func _play_sleep() -> void:
	is_busy = true
	_spawn_float_text("Zzz...", Color(0.6, 0.8, 1.0))
	
	var tw = create_tween()
	tw.tween_property(body_pivot, "position:y", 12.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(body_pivot, "scale", Vector2(-facing * 1.05, 0.85), 0.6)
	tw.parallel().tween_property(body_pivot, "rotation", deg_to_rad(-10.0 * facing), 0.6)
	
	# Nap duration
	await get_tree().create_timer(rng.randf_range(2.5, 5.0)).timeout
	if not is_instance_valid(self): return
	
	# Wake up shake
	tw = create_tween()
	tw.tween_property(body_pivot, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE)
	tw.parallel().tween_property(body_pivot, "scale", Vector2(-facing, 1.0), 0.3)
	tw.parallel().tween_property(body_pivot, "rotation", 0.0, 0.3)
	
	await tw.finished
	is_busy = false
	_refresh_visual_emphasis()

# --- NEW BEHAVIOR: ZOOMIES ---
func _play_zoomies() -> void:
	is_busy = true
	var parent_control = get_parent() as Control
	if not parent_control:
		is_busy = false
		return

	_spawn_float_text("Zoom!", Color(1.0, 0.9, 0.4))
	
	for i in range(3):
		var target_x = rng.randf_range(0, max(0, parent_control.size.x - size.x))
		var dir = float(sign(target_x - position.x))
		if dir != 0: await _turn_toward(dir)

		var tw = create_tween()
		tw.tween_property(body_pivot, "rotation", deg_to_rad(15.0 * facing), 0.1)
		tw.parallel().tween_property(self, "position:x", target_x, 0.25).set_trans(Tween.TRANS_SINE)
		await tw.finished
	
	var settle = create_tween()
	settle.tween_property(body_pivot, "rotation", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE)
	await settle.finished
	
	is_busy = false
	_refresh_visual_emphasis()

# --- NEW BEHAVIOR: HOVER (Wind) ---
func _play_hover() -> void:
	is_busy = true
	var tw = create_tween()
	
	# Takeoff
	tw.tween_property(body_pivot, "position:y", -45.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(shadow, "scale", Vector2(0.5, 0.5), 0.5)
	tw.parallel().tween_property(shadow, "modulate:a", 0.2, 0.5)
	await tw.finished
	
	if not is_instance_valid(self): return
	
	# Bobbing in the air
	var hover_tw = create_tween().set_loops(2)
	hover_tw.tween_property(body_pivot, "position:y", -40.0, 0.4).set_trans(Tween.TRANS_SINE)
	hover_tw.tween_property(body_pivot, "position:y", -50.0, 0.4).set_trans(Tween.TRANS_SINE)
	
	await get_tree().create_timer(1.6).timeout
	if hover_tw.is_valid(): hover_tw.kill()
	
	if not is_instance_valid(self): return
	
	# Landing
	tw = create_tween()
	tw.tween_property(body_pivot, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(shadow, "scale", Vector2.ONE, 0.3)
	tw.parallel().tween_property(shadow, "modulate:a", 0.72, 0.3)
	await tw.finished
	
	_play_landing_burst(1.0)
	is_busy = false
	_refresh_visual_emphasis()

# --- NEW BEHAVIOR: DIG (Earth) ---
func _play_dig() -> void:
	is_busy = true
	var tw = create_tween()
	
	# Lean down
	tw.tween_property(body_pivot, "rotation", deg_to_rad(25.0 * facing), 0.2)
	tw.parallel().tween_property(body_pivot, "position:y", 10.0, 0.2)
	await tw.finished
	
	if not is_instance_valid(self): return
	
	# Digging motion
	for i in range(4):
		tw = create_tween()
		tw.tween_property(body_pivot, "position:x", 6.0 * facing, 0.08)
		tw.tween_property(body_pivot, "position:x", -2.0 * facing, 0.08)
		_spawn_local_dust()
		await tw.finished
		
	if not is_instance_valid(self): return
		
	# Recover
	tw = create_tween()
	tw.tween_property(body_pivot, "rotation", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE)
	tw.parallel().tween_property(body_pivot, "position", Vector2.ZERO, 0.2)
	await tw.finished
	
	is_busy = false
	_refresh_visual_emphasis()

func _spawn_local_dust() -> void:
	var parent = get_parent()
	if not parent: return
	
	var puff = ColorRect.new()
	puff.color = Color(0.5, 0.4, 0.3, 0.8) # Dirt color
	puff.size = Vector2(6, 6)
	# Spawn dust near the front claws
	puff.position = position + Vector2(size.x * 0.5 + (facing * 20), size.y - 10)
	parent.add_child(puff)
	
	var tw = create_tween()
	tw.tween_property(puff, "position:y", puff.position.y - 25.0, 0.3).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(puff, "position:x", puff.position.x - (facing * 30.0), 0.3)
	tw.parallel().tween_property(puff, "modulate:a", 0.0, 0.3)
	tw.tween_callback(puff.queue_free)

func _element_loop() -> void:
	while is_instance_valid(self) and behavior_active:
		await get_tree().create_timer(rng.randf_range(1.6, 3.4)).timeout

		if not is_instance_valid(self) or is_busy or current_stage <= 0:
			continue

		match element:
			"Fire": _fire_flicker()
			"Ice": _ice_shimmer()
			"Lightning": _lightning_crackle()
			"Earth": _earth_settle()
			"Wind": _wind_sway()

func _wander_once() -> void:
	if is_busy:
		return

	is_busy = true

	var parent_control: Control = get_parent() as Control
	if parent_control == null:
		is_busy = false
		return

	var target_pos: Vector2 = _pick_target(parent_control.size)
	var dir: float = float(sign(target_pos.x - position.x))
	if dir == 0.0:
		dir = facing

	await _turn_toward(dir)

	var dist: float = position.distance_to(target_pos)
	if dist < 12.0:
		is_busy = false
		_refresh_visual_emphasis()
		return

	var hop_height: float = -18.0
	var squash_mult: float = 1.0
	var speed_mult: float = 1.0

	match element:
		"Fire":
			hop_height = -26.0
			squash_mult = 1.20
			speed_mult = 0.88
		"Ice":
			hop_height = -12.0
			squash_mult = 0.45
			speed_mult = 1.15
		"Lightning":
			hop_height = -16.0
			squash_mult = 0.90
			speed_mult = 0.72
		"Earth":
			hop_height = -9.0
			squash_mult = 1.45
			speed_mult = 1.18
		"Wind":
			hop_height = -34.0
			squash_mult = 0.60
			speed_mult = 1.30

	var move_time: float = float(clamp((dist / 110.0) * speed_mult, 0.35, 1.55))

	_kill_tween(body_tween)
	body_tween = create_tween()
	body_tween.tween_property(
		body_pivot,
		"scale",
		Vector2(-facing * (1.05 + (0.04 * squash_mult)), 0.92 - (0.04 * squash_mult)),
		0.09
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	body_tween.parallel().tween_property(shadow, "scale", Vector2(1.08, 1.08), 0.09)
	await body_tween.finished

	_kill_tween(movement_tween)
	_kill_tween(body_tween)
	movement_tween = create_tween()
	movement_tween.tween_property(self, "position", target_pos, move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	body_tween = create_tween()
	body_tween.tween_property(body_pivot, "position:y", hop_height, move_time * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	body_tween.parallel().tween_property(shadow, "scale", Vector2(0.72, 0.72), move_time * 0.45)
	body_tween.parallel().tween_property(shadow, "modulate:a", 0.38, move_time * 0.45)

	body_tween.tween_property(body_pivot, "position:y", 0.0, move_time * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	body_tween.parallel().tween_property(shadow, "scale", Vector2(1.0, 1.0), move_time * 0.55)
	body_tween.parallel().tween_property(shadow, "modulate:a", 0.72, move_time * 0.55)
	await movement_tween.finished

	_kill_tween(body_tween)
	body_tween = create_tween()
	body_tween.tween_property(body_pivot, "scale", Vector2(-facing * (0.90 - (0.02 * squash_mult)), 1.08 + (0.08 * squash_mult)), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	body_tween.parallel().tween_property(shadow, "scale", Vector2(1.12, 1.12), 0.08)

	body_tween.tween_property(body_pivot, "scale", Vector2(-facing, 1.0), 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	body_tween.parallel().tween_property(shadow, "scale", Vector2.ONE, 0.16)
	await body_tween.finished

	_play_landing_burst(1.0)
	is_busy = false
	_refresh_visual_emphasis()
	
func _play_look_around() -> void:
	is_busy = true

	var tw: Tween = create_tween()
	tw.tween_property(body_pivot, "rotation", deg_to_rad(-5.0), 0.12).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(name_label, "rotation", deg_to_rad(-2.0), 0.12)

	tw.tween_property(body_pivot, "rotation", deg_to_rad(4.0), 0.16).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(name_label, "rotation", deg_to_rad(1.0), 0.16)

	tw.tween_property(body_pivot, "rotation", 0.0, 0.12)
	tw.parallel().tween_property(name_label, "rotation", 0.0, 0.12)

	if rng.randf() < 0.5:
		await tw.finished
		await _turn_toward(-facing)
	else:
		await tw.finished

	is_busy = false
	_refresh_visual_emphasis()

func _play_hop_in_place() -> void:
	is_busy = true
	var hop: float = -12.0
	if element == "Wind": hop = -20.0
	elif element == "Earth": hop = -7.0

	var tw: Tween = create_tween()
	tw.tween_property(body_pivot, "scale", Vector2(-facing * 1.08, 0.92), 0.08)
	tw.parallel().tween_property(shadow, "scale", Vector2(1.08, 1.08), 0.08)

	tw.tween_property(body_pivot, "position:y", hop, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(shadow, "scale", Vector2(0.75, 0.75), 0.12)
	tw.parallel().tween_property(shadow, "modulate:a", 0.38, 0.12)

	tw.tween_property(body_pivot, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(shadow, "scale", Vector2.ONE, 0.12)
	tw.parallel().tween_property(shadow, "modulate:a", 0.72, 0.12)

	tw.tween_property(body_pivot, "scale", Vector2(-facing, 1.0), 0.12).set_trans(Tween.TRANS_BOUNCE)
	await tw.finished
	_play_landing_burst(0.7)
	is_busy = false
	_refresh_visual_emphasis()
	
func _play_social_idle() -> void:
	var neighbor: DragonActor = _find_nearest_dragon(240.0)
	if neighbor == null:
		await _play_look_around()
		return

	is_busy = true

	var dir: float = float(sign(neighbor.position.x - position.x))
	if dir == 0.0:
		dir = facing

	await _turn_toward(dir)

	var tw: Tween = create_tween()
	tw.tween_property(body_pivot, "rotation", deg_to_rad(3.0 * dir), 0.12)
	tw.parallel().tween_property(name_label, "scale", Vector2(1.04, 1.04), 0.12)

	tw.tween_property(body_pivot, "rotation", 0.0, 0.14)
	tw.parallel().tween_property(name_label, "scale", Vector2.ONE, 0.14)

	await tw.finished

	if neighbor.element == element and rng.randf() < 0.65:
		_play_landing_burst(0.55)

	is_busy = false
	_refresh_visual_emphasis()

func _turn_toward(dir: float) -> void:
	dir = -1.0 if dir < 0.0 else 1.0
	if dir == facing:
		return

	facing = dir
	var tw: Tween = create_tween()
	tw.tween_property(body_pivot, "scale:x", -0.15 * dir, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(body_pivot, "scale:x", -facing, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	
func set_selected(value: bool) -> void:
	if is_selected == value: return
	is_selected = value
	_refresh_visual_emphasis(false)

func set_hovered(value: bool) -> void:
	if is_hovered == value: return
	is_hovered = value
	_refresh_visual_emphasis(false)

	if is_busy: return

	_kill_tween(hover_tween)
	hover_tween = create_tween()

	if value:
		hover_tween.tween_property(body_pivot, "position:y", -6.0, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		hover_tween.parallel().tween_property(shadow, "scale", Vector2(0.92, 0.92), 0.10)
	else:
		hover_tween.tween_property(body_pivot, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		hover_tween.parallel().tween_property(shadow, "scale", Vector2.ONE, 0.12)

func play_feed_bounce(growth_amount: int = 25) -> void:
	_interrupt_motion()
	is_busy = true
	_refresh_visual_emphasis(true)
	_spawn_float_text("+%d GP" % growth_amount, Color(1.0, 0.93, 0.45))

	var tw: Tween = create_tween()
	tw.tween_property(body_pivot, "position:y", -4.0, 0.05)
	tw.parallel().tween_property(body_pivot, "rotation", deg_to_rad(-8.0 * facing), 0.05)

	tw.tween_property(body_pivot, "rotation", deg_to_rad(5.0 * facing), 0.09)
	tw.parallel().tween_property(body_pivot, "scale", Vector2(-facing * 1.12, 0.88), 0.09)
	tw.parallel().tween_property(body_pivot, "position:y", 0.0, 0.09)

	tw.tween_property(body_pivot, "rotation", deg_to_rad(-3.0 * facing), 0.10)
	tw.parallel().tween_property(body_pivot, "scale", Vector2(-facing * 0.95, 1.08), 0.10)

	tw.tween_property(body_pivot, "rotation", 0.0, 0.18).set_trans(Tween.TRANS_BOUNCE)
	tw.parallel().tween_property(body_pivot, "scale", Vector2(-facing, 1.0), 0.18).set_trans(Tween.TRANS_BOUNCE)
	await tw.finished

	_play_landing_burst(0.9)
	is_busy = false
	_refresh_visual_emphasis(false)

func play_pet_reaction(result: Dictionary) -> void:
	_interrupt_motion()
	is_busy = true
	_refresh_visual_emphasis(true)

	var reaction: String = str(result.get("reaction", "neutral"))
	var float_text: String = str(result.get("float_text", "?"))

	match reaction:
		"ecstatic":
			_spawn_float_text(float_text, Color(1.0, 0.65, 0.85))

			var tw1: Tween = create_tween()
			tw1.tween_property(body_pivot, "position:y", -10.0, 0.08).set_trans(Tween.TRANS_SINE)
			tw1.parallel().tween_property(body_pivot, "scale", Vector2(-facing * 1.10, 0.90), 0.08)
			tw1.parallel().tween_property(name_label, "scale", Vector2(1.12, 1.12), 0.08)

			tw1.tween_property(body_pivot, "position:y", 0.0, 0.10).set_trans(Tween.TRANS_BOUNCE)
			tw1.parallel().tween_property(body_pivot, "scale", Vector2(-facing * 0.94, 1.08), 0.10)

			tw1.tween_property(body_pivot, "position:y", -6.0, 0.07).set_trans(Tween.TRANS_SINE)
			tw1.parallel().tween_property(body_pivot, "rotation", deg_to_rad(5.0 * facing), 0.07)

			tw1.tween_property(body_pivot, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_BOUNCE)
			tw1.parallel().tween_property(body_pivot, "rotation", 0.0, 0.12)
			tw1.parallel().tween_property(body_pivot, "scale", Vector2(-facing, 1.0), 0.12)

			await tw1.finished
			_play_landing_burst(1.2)

		"happy":
			_spawn_float_text(float_text, Color(1.0, 0.72, 0.88))

			var tw2: Tween = create_tween()
			tw2.tween_property(body_pivot, "position:y", -6.0, 0.08).set_trans(Tween.TRANS_SINE)
			tw2.parallel().tween_property(body_pivot, "rotation", deg_to_rad(-4.0 * facing), 0.08)

			tw2.tween_property(body_pivot, "rotation", deg_to_rad(3.0 * facing), 0.10)
			tw2.parallel().tween_property(body_pivot, "scale", Vector2(-facing * 1.06, 0.94), 0.10)

			tw2.tween_property(body_pivot, "rotation", 0.0, 0.14).set_trans(Tween.TRANS_BOUNCE)
			tw2.parallel().tween_property(body_pivot, "position:y", 0.0, 0.14)
			tw2.parallel().tween_property(body_pivot, "scale", Vector2(-facing, 1.0), 0.14)

			await tw2.finished
			_play_landing_burst(0.8)

		"annoyed":
			_spawn_float_text(float_text, Color(1.0, 0.45, 0.45))

			var tw3: Tween = create_tween()
			tw3.tween_property(body_pivot, "position:x", -10.0 * facing, 0.08).set_trans(Tween.TRANS_SINE)
			tw3.parallel().tween_property(body_pivot, "rotation", deg_to_rad(-8.0 * facing), 0.08)
			tw3.parallel().tween_property(shadow, "scale", Vector2(1.10, 1.10), 0.08)

			tw3.tween_property(body_pivot, "position:x", 0.0, 0.14).set_trans(Tween.TRANS_BOUNCE)
			tw3.parallel().tween_property(body_pivot, "rotation", 0.0, 0.14)
			tw3.parallel().tween_property(shadow, "scale", Vector2.ONE, 0.14)

			await tw3.finished
			_play_landing_burst(0.5)

		_:
			_spawn_float_text(float_text, Color(0.95, 0.95, 1.0))

			var tw4: Tween = create_tween()
			tw4.tween_property(body_pivot, "rotation", deg_to_rad(-4.0), 0.10).set_trans(Tween.TRANS_SINE)
			tw4.tween_property(body_pivot, "rotation", deg_to_rad(3.0), 0.12).set_trans(Tween.TRANS_SINE)
			tw4.tween_property(body_pivot, "rotation", 0.0, 0.10).set_trans(Tween.TRANS_SINE)

			await tw4.finished

	is_busy = false
	_refresh_visual_emphasis(false)
	
func play_evolution_fx(new_data: Dictionary, _old_stage: int, _new_stage: int) -> void:
	_interrupt_motion()
	is_busy = true
	dragon_data = new_data
	_spawn_float_text("EVOLVED!", Color(0.95, 1.0, 0.55))

	var tw: Tween = create_tween()
	tw.tween_property(body_pivot, "scale", Vector2(-facing * 0.88, 1.16), 0.10).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(body_pivot, "position:y", -24.0, 0.14)

	await tw.finished
	setup(new_data)

	var settle: Tween = create_tween()
	settle.tween_property(body_pivot, "scale", Vector2(-facing * 1.10, 0.92), 0.10)
	settle.tween_property(body_pivot, "scale", Vector2(-facing, 1.0), 0.22).set_trans(Tween.TRANS_BOUNCE)
	await settle.finished

	_play_landing_burst(1.4)
	is_busy = false
	_refresh_visual_emphasis(true)
	
func _play_landing_burst(power: float = 1.0) -> void:
	_kill_tween(reaction_tween)
	reaction_tween = create_tween()

	var burst_amount: int = base_aura_amount + int(round(6.0 * power))
	aura_particles.amount = burst_amount

	match element:
		"Fire":
			reaction_tween.tween_property(sprite, "modulate", Color(1.15, 1.07, 0.98, 1.0), 0.05)
			reaction_tween.parallel().tween_property(shadow, "scale", Vector2(1.08, 1.08), 0.05)
			reaction_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.12)
		"Ice":
			reaction_tween.tween_property(sprite, "modulate", Color(1.08, 1.12, 1.16, 1.0), 0.06)
			reaction_tween.parallel().tween_property(body_pivot, "rotation", deg_to_rad(-2.0), 0.06)
			reaction_tween.tween_property(body_pivot, "rotation", 0.0, 0.10)
			reaction_tween.parallel().tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.10)
		"Lightning":
			reaction_tween.tween_property(sprite, "modulate", Color(1.22, 1.18, 1.0, 1.0), 0.03)
			reaction_tween.tween_property(sprite, "modulate", Color(0.96, 0.96, 1.0, 1.0), 0.03)
			reaction_tween.tween_property(sprite, "modulate", Color(1.14, 1.10, 1.0, 1.0), 0.03)
			reaction_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.06)
		"Earth":
			reaction_tween.tween_property(shadow, "scale", Vector2(1.18, 1.18), 0.07)
			reaction_tween.parallel().tween_property(body_pivot, "position:y", 2.0, 0.07)
			reaction_tween.tween_property(shadow, "scale", Vector2.ONE, 0.12)
			reaction_tween.parallel().tween_property(body_pivot, "position:y", 0.0, 0.12)
		"Wind":
			reaction_tween.tween_property(body_pivot, "rotation", deg_to_rad(-4.0), 0.08).set_trans(Tween.TRANS_SINE)
			reaction_tween.tween_property(body_pivot, "rotation", deg_to_rad(2.0), 0.08).set_trans(Tween.TRANS_SINE)
			reaction_tween.tween_property(body_pivot, "rotation", 0.0, 0.08).set_trans(Tween.TRANS_SINE)
		_:
			reaction_tween.tween_property(sprite, "modulate", Color(1.08, 1.08, 1.08, 1.0), 0.05)
			reaction_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.10)

	reaction_tween.finished.connect(func() -> void:
		if is_instance_valid(aura_particles):
			var reset_amount: int = base_aura_amount
			if is_selected: reset_amount += 3
			if is_hovered: reset_amount += 4
			if _has_trait("Magic Blooded") or _has_trait("Elder Arcana"): reset_amount += 2
			aura_particles.amount = reset_amount
	)

func _interrupt_motion() -> void:
	_kill_tween(movement_tween)
	_kill_tween(body_tween)
	_kill_tween(idle_tween)
	_kill_tween(hover_tween)
	_kill_tween(reaction_tween)

	body_pivot.position.y = -6.0 if is_hovered else 0.0
	body_pivot.rotation = 0.0
	body_pivot.scale = Vector2(-facing, 1.0)

	sprite.scale = Vector2.ONE
	sprite.rotation = 0.0
	sprite.modulate = Color(1, 1, 1, 1)

	shadow.scale = Vector2(0.92, 0.92) if is_hovered else Vector2.ONE
	shadow.modulate.a = 0.72
	name_label.rotation = 0.0
	
func _pick_target(bounds: Vector2) -> Vector2:
	var target: Vector2

	if rng.randf() < 0.72:
		target = position + Vector2(
			rng.randf_range(-140.0, 140.0),
			rng.randf_range(-70.0, 70.0)
		)
	else:
		target = Vector2(
			rng.randf_range(0.0, max(0.0, bounds.x - size.x)),
			rng.randf_range(0.0, max(0.0, bounds.y - size.y))
		)

	target.x = float(clamp(target.x, 0.0, max(0.0, bounds.x - size.x)))
	target.y = float(clamp(target.y, 0.0, max(0.0, bounds.y - size.y)))
	return target

func _find_nearest_dragon(max_distance: float) -> DragonActor:
	var parent_control: Control = get_parent() as Control
	if parent_control == null: return null

	var best: DragonActor = null
	var best_dist: float = max_distance

	for child in parent_control.get_children():
		if child == self or not (child is DragonActor):
			continue

		var other: DragonActor = child as DragonActor
		var dist: float = position.distance_to(other.position)
		if dist < best_dist:
			best_dist = dist
			best = other

	return best

func _fire_flicker() -> void:
	_kill_tween(element_tween)
	element_tween = create_tween()
	element_tween.tween_property(sprite, "modulate", Color(1.08, 1.02, 0.95, 1.0), 0.07)
	element_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.12)

func _ice_shimmer() -> void:
	_kill_tween(element_tween)
	element_tween = create_tween()
	element_tween.tween_property(sprite, "rotation", deg_to_rad(-1.3), 0.12)
	element_tween.tween_property(sprite, "rotation", deg_to_rad(1.0), 0.14)
	element_tween.tween_property(sprite, "rotation", 0.0, 0.12)

func _lightning_crackle() -> void:
	_kill_tween(element_tween)
	element_tween = create_tween()
	element_tween.tween_property(sprite, "modulate", Color(1.22, 1.18, 1.0, 1.0), 0.03)
	element_tween.tween_property(sprite, "modulate", Color(0.94, 0.94, 1.0, 1.0), 0.04)
	element_tween.tween_property(sprite, "modulate", Color(1.18, 1.15, 1.0, 1.0), 0.03)
	element_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.07)

func _earth_settle() -> void:
	_kill_tween(element_tween)
	element_tween = create_tween()
	element_tween.tween_property(shadow, "scale", Vector2(1.10, 1.10), 0.10)
	element_tween.parallel().tween_property(body_pivot, "position:y", 2.0, 0.10)
	element_tween.tween_property(shadow, "scale", Vector2.ONE, 0.16)
	element_tween.parallel().tween_property(body_pivot, "position:y", 0.0, 0.16)

func _wind_sway() -> void:
	_kill_tween(element_tween)
	element_tween = create_tween()
	element_tween.tween_property(body_pivot, "rotation", deg_to_rad(-3.0), 0.18).set_trans(Tween.TRANS_SINE)
	element_tween.tween_property(body_pivot, "rotation", deg_to_rad(2.2), 0.18).set_trans(Tween.TRANS_SINE)
	element_tween.tween_property(body_pivot, "rotation", 0.0, 0.16).set_trans(Tween.TRANS_SINE)

func _spawn_float_text(text: String, color: Color) -> void:
	var parent_control: Control = get_parent() as Control
	if parent_control == null: return

	var label: Label = Label.new()
	label.text = text
	label.position = position + Vector2(size.x * 0.28, -10.0)
	label.z_index = 50
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate = color
	label.set("theme_override_font_sizes/font_size", 18)

	parent_control.add_child(label)

	var tw: Tween = label.create_tween()
	tw.tween_property(label, "position:y", label.position.y - 30.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.55)
	tw.finished.connect(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
	)

func _has_trait(trait_name: String) -> bool:
	var traits: Array = dragon_data.get("traits", [])
	return traits.has(trait_name)

func _clamp_inside_parent() -> void:
	var parent_control: Control = get_parent() as Control
	if parent_control == null: return

	position.x = float(clamp(position.x, 0.0, max(0.0, parent_control.size.x - size.x)))
	position.y = float(clamp(position.y, 0.0, max(0.0, parent_control.size.y - size.y)))

func _kill_tween(tw: Tween) -> void:
	if tw != null and is_instance_valid(tw): tw.kill()

func get_dragon_uid() -> String:
	return dragon_uid

func refresh_from_data(new_data: Dictionary) -> void:
	setup(new_data)
	
func _play_elemental_breath() -> void:
	is_busy = true

	var tw: Tween = create_tween()
	tw.tween_property(body_pivot, "scale", Vector2(-facing * 0.85, 1.15), 0.35).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(body_pivot, "rotation", deg_to_rad(-8.0 * facing), 0.35)
	await tw.finished

	if not is_instance_valid(self): return
	_play_roar(0.9, 1.05, 1.0)
	
	tw = create_tween()
	tw.tween_property(body_pivot, "scale", Vector2(-facing * 1.15, 0.9), 0.1).set_trans(Tween.TRANS_BOUNCE)
	tw.parallel().tween_property(body_pivot, "rotation", deg_to_rad(12.0 * facing), 0.1)
	
	_spawn_breath_particles()
	
	var shake_tw: Tween = create_tween()
	for i in range(4):
		shake_tw.tween_property(sprite, "position", Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)), 0.05)
	shake_tw.tween_property(sprite, "position", Vector2.ZERO, 0.05)

	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self): return

	tw = create_tween()
	tw.tween_property(body_pivot, "scale", Vector2(-facing, 1.0), 0.25).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(body_pivot, "rotation", 0.0, 0.25)
	await tw.finished

	is_busy = false
	_refresh_visual_emphasis()
	
func _spawn_breath_particles() -> void:
	var breath: CPUParticles2D = CPUParticles2D.new()
	breath.emitting = false
	breath.one_shot = true
	breath.explosiveness = 0.15
	breath.lifetime = 0.6
	breath.amount = 40
	breath.z_index = 20 
	
	var mouth_pos: Vector2 = Vector2(size.x * 0.5 + (size.x * 0.4 * facing), size.y * 0.35)
	breath.position = mouth_pos
	
	breath.direction = Vector2(facing, 0.15) 
	breath.spread = 20.0
	breath.initial_velocity_min = 180.0
	breath.initial_velocity_max = 260.0
	breath.scale_amount_min = 6.0
	breath.scale_amount_max = 12.0
	
	match element:
		"Fire":
			breath.color = Color(1.0, 0.35, 0.0, 1.0)
			breath.gravity = Vector2(0, -90) 
		"Ice":
			breath.color = Color(0.8, 0.95, 1.0, 0.85)
			breath.gravity = Vector2(0, 40) 
			breath.spread = 15.0
			breath.scale_amount_min = 4.0
			breath.scale_amount_max = 8.0
		"Lightning":
			breath.color = Color(1.0, 0.95, 0.2, 1.0)
			breath.gravity = Vector2.ZERO
			breath.spread = 45.0 
			breath.initial_velocity_min = 250.0
			breath.initial_velocity_max = 450.0
			breath.lifetime = 0.25
			breath.scale_amount_min = 3.0
			breath.scale_amount_max = 6.0
		"Earth":
			breath.color = Color(0.45, 0.35, 0.25, 1.0)
			breath.gravity = Vector2(0, 120) 
			breath.initial_velocity_min = 120.0
			breath.initial_velocity_max = 180.0
		"Wind":
			breath.color = Color(0.85, 1.0, 0.95, 0.5)
			breath.gravity = Vector2(0, -10)
			breath.spread = 60.0 
			breath.initial_velocity_min = 150.0
			breath.initial_velocity_max = 300.0
			breath.scale_amount_min = 8.0
			breath.scale_amount_max = 16.0
			
	add_child(breath)
	breath.emitting = true
	
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(breath):
			breath.queue_free()
	)

func _play_tail_swish() -> void:
	is_busy = true
	var tw: Tween = create_tween()
	tw.tween_property(body_pivot, "rotation", deg_to_rad(-6.0), 0.10).set_trans(Tween.TRANS_SINE)
	tw.tween_property(body_pivot, "rotation", deg_to_rad(5.0), 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(body_pivot, "rotation", deg_to_rad(-3.0), 0.10).set_trans(Tween.TRANS_SINE)
	tw.tween_property(body_pivot, "rotation", 0.0, 0.12).set_trans(Tween.TRANS_SINE)

	await tw.finished
	is_busy = false
	_refresh_visual_emphasis()

func _play_proud_pose() -> void:
	is_busy = true
	if rng.randf() < 0.45:
		_play_roar(0.95, 1.12, 1.0)
	var tw: Tween = create_tween()
	tw.tween_property(body_pivot, "position:y", -8.0, 0.12).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(body_pivot, "scale", Vector2(-facing * 1.06, 0.96), 0.12)
	tw.parallel().tween_property(name_label, "scale", Vector2(1.06, 1.06), 0.12)

	tw.tween_interval(0.18)

	tw.tween_property(body_pivot, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(body_pivot, "scale", Vector2(-facing, 1.0), 0.14)
	tw.parallel().tween_property(name_label, "scale", Vector2.ONE, 0.14)

	await tw.finished
	is_busy = false
	_refresh_visual_emphasis()

func _play_hunt_step(target_pos: Vector2, is_final: bool = false) -> void:
	var parent_control: Control = get_parent() as Control
	if parent_control == null: return

	var dir: float = float(sign(target_pos.x - (position.x + size.x * 0.5)))
	if dir == 0.0: dir = facing

	await _turn_toward(dir)
	var final_target: Vector2 = target_pos - Vector2(size.x * 0.5, size.y * 0.70)

	if not is_final:
		final_target.x -= 20.0 * dir

	final_target.x = float(clamp(final_target.x, 0.0, max(0.0, parent_control.size.x - size.x)))
	final_target.y = float(clamp(final_target.y, 0.0, max(0.0, parent_control.size.y - size.y)))

	var hop_height: float = -22.0 if not is_final else -30.0
	var move_time: float = 0.16 if not is_final else 0.22

	_kill_tween(body_tween)
	body_tween = create_tween()
	body_tween.tween_property(body_pivot, "scale", Vector2(-facing * 1.08, 0.90), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	body_tween.parallel().tween_property(shadow, "scale", Vector2(1.08, 1.08), 0.07)
	await body_tween.finished

	_kill_tween(movement_tween)
	_kill_tween(body_tween)

	movement_tween = create_tween()
	movement_tween.tween_property(self, "position", final_target, move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	body_tween = create_tween()
	body_tween.tween_property(body_pivot, "position:y", hop_height, move_time * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	body_tween.parallel().tween_property(shadow, "scale", Vector2(0.72, 0.72), move_time * 0.45)
	body_tween.parallel().tween_property(shadow, "modulate:a", 0.34, move_time * 0.45)

	body_tween.tween_property(body_pivot, "position:y", 0.0, move_time * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	body_tween.parallel().tween_property(shadow, "scale", Vector2.ONE, move_time * 0.55)
	body_tween.parallel().tween_property(shadow, "modulate:a", 0.72, move_time * 0.55)

	await movement_tween.finished

	_kill_tween(body_tween)
	body_tween = create_tween()
	body_tween.tween_property(body_pivot, "scale", Vector2(-facing * 0.92, 1.08), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	body_tween.parallel().tween_property(shadow, "scale", Vector2(1.12, 1.12), 0.07)

	body_tween.tween_property(body_pivot, "scale", Vector2(-facing, 1.0), 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	body_tween.parallel().tween_property(shadow, "scale", Vector2.ONE, 0.14)

	await body_tween.finished


func play_hunt_chase(chase_points: Array[Vector2], result: Dictionary) -> void:
	_interrupt_motion()
	is_busy = true
	_refresh_visual_emphasis(true)

	if chase_points.is_empty():
		is_busy = false
		_refresh_visual_emphasis(false)
		return

	for i in range(chase_points.size()):
		var is_final: bool = i == chase_points.size() - 1
		var point: Vector2 = chase_points[i]

		await _play_hunt_step(point, is_final)

		if not is_final:
			_play_landing_burst(0.45)
			await get_tree().create_timer(0.04).timeout

	_spawn_float_text(str(result.get("float_text", "+Happy")), Color(0.65, 1.0, 0.65))
	_play_landing_burst(1.2)

	is_busy = false
	_refresh_visual_emphasis(false)

func play_hunt_reaction(target_pos: Vector2, result: Dictionary) -> void:
	_interrupt_motion()
	is_busy = true
	_refresh_visual_emphasis(true)

	var float_text: String = str(result.get("float_text", "+Happy"))
	_spawn_float_text(float_text, Color(0.65, 1.0, 0.65))

	var dir: float = float(sign(target_pos.x - position.x))
	if dir == 0.0: dir = facing

	await _turn_toward(dir)

	var parent_control: Control = get_parent() as Control
	var final_target: Vector2 = target_pos - Vector2(size.x * 0.5, size.y * 0.7)

	if parent_control != null:
		final_target.x = float(clamp(final_target.x, 0.0, max(0.0, parent_control.size.x - size.x)))
		final_target.y = float(clamp(final_target.y, 0.0, max(0.0, parent_control.size.y - size.y)))

	var tw: Tween = create_tween()
	tw.tween_property(body_pivot, "scale", Vector2(-facing * 0.92, 1.10), 0.08).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(body_pivot, "position:y", -6.0, 0.08)
	await tw.finished

	_kill_tween(movement_tween)
	_kill_tween(body_tween)

	movement_tween = create_tween()
	movement_tween.tween_property(self, "position", final_target, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	body_tween = create_tween()
	body_tween.tween_property(body_pivot, "position:y", -28.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	body_tween.parallel().tween_property(shadow, "scale", Vector2(0.70, 0.70), 0.12)
	body_tween.parallel().tween_property(shadow, "modulate:a", 0.34, 0.12)

	body_tween.tween_property(body_pivot, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	body_tween.parallel().tween_property(shadow, "scale", Vector2.ONE, 0.14)
	body_tween.parallel().tween_property(shadow, "modulate:a", 0.72, 0.14)

	await movement_tween.finished

	var pounce: Tween = create_tween()
	pounce.tween_property(body_pivot, "scale", Vector2(-facing * 1.14, 0.86), 0.08).set_trans(Tween.TRANS_QUAD)
	pounce.parallel().tween_property(body_pivot, "rotation", deg_to_rad(6.0 * facing), 0.08)
	pounce.parallel().tween_property(shadow, "scale", Vector2(1.14, 1.14), 0.08)

	pounce.tween_property(body_pivot, "scale", Vector2(-facing, 1.0), 0.18).set_trans(Tween.TRANS_BOUNCE)
	pounce.parallel().tween_property(body_pivot, "rotation", 0.0, 0.18)
	pounce.parallel().tween_property(shadow, "scale", Vector2.ONE, 0.18)

	await pounce.finished
	if rng.randf() < 0.65:
		_play_roar(1.0, 1.15, 1.0)
	_play_landing_burst(1.2)
	is_busy = false
	_refresh_visual_emphasis(false)

func begin_hunt_step(target_pos: Vector2, is_final: bool = false, extra_overshoot: float = 0.0) -> float:
	is_busy = true
	_refresh_visual_emphasis(true)

	var parent_control: Control = get_parent() as Control
	if parent_control == null: return 0.0

	_kill_tween(movement_tween)
	_kill_tween(body_tween)

	var dir: float = float(sign(target_pos.x - (position.x + size.x * 0.5)))
	if dir == 0.0: dir = facing
	facing = -1.0 if dir < 0.0 else 1.0

	body_pivot.scale.x = -facing

	var final_target: Vector2 = target_pos - Vector2(size.x * 0.5, size.y * 0.70)

	if not is_final:
		final_target.x -= (18.0 + extra_overshoot) * facing

	final_target.x = float(clamp(final_target.x, 0.0, max(0.0, parent_control.size.x - size.x)))
	final_target.y = float(clamp(final_target.y, 0.0, max(0.0, parent_control.size.y - size.y)))

	var anticipation: float = 0.05
	var move_time: float = 0.17 if not is_final else 0.23
	var land_time: float = 0.14
	var hop_height: float = -22.0 if not is_final else -30.0

	movement_tween = create_tween()
	movement_tween.tween_interval(anticipation)
	movement_tween.tween_property(self, "position", final_target, move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	body_tween = create_tween()
	body_tween.tween_property(body_pivot, "scale", Vector2(-facing * 1.08, 0.90), anticipation).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	body_tween.parallel().tween_property(shadow, "scale", Vector2(1.08, 1.08), anticipation)
	body_tween.parallel().tween_property(body_pivot, "position:y", -4.0, anticipation)

	body_tween.tween_property(body_pivot, "position:y", hop_height, move_time * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	body_tween.parallel().tween_property(shadow, "scale", Vector2(0.72, 0.72), move_time * 0.45)
	body_tween.parallel().tween_property(shadow, "modulate:a", 0.34, move_time * 0.45)

	body_tween.tween_property(body_pivot, "position:y", 0.0, move_time * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	body_tween.parallel().tween_property(shadow, "scale", Vector2.ONE, move_time * 0.55)
	body_tween.parallel().tween_property(shadow, "modulate:a", 0.72, move_time * 0.55)

	body_tween.tween_property(body_pivot, "scale", Vector2(-facing * 0.92, 1.08), land_time * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	body_tween.parallel().tween_property(shadow, "scale", Vector2(1.12, 1.12), land_time * 0.35)

	body_tween.tween_property(body_pivot, "scale", Vector2(-facing, 1.0), land_time * 0.65).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	body_tween.parallel().tween_property(shadow, "scale", Vector2.ONE, land_time * 0.65)

	return anticipation + move_time + land_time
	
func end_hunt_chase(result: Dictionary) -> void:
	_spawn_float_text(str(result.get("float_text", "+Happy")), Color(0.65, 1.0, 0.65))
	_play_landing_burst(1.2)
	is_busy = false
	_refresh_visual_emphasis(false)

func _play_roar(pitch_min: float = 0.95, pitch_max: float = 1.08, chance: float = 1.0) -> void:
	if roar_player == null: return
	if roar_sounds.is_empty(): return
	if rng.randf() > chance: return

	var chosen: AudioStream = roar_sounds[rng.randi_range(0, roar_sounds.size() - 1)]
	var p := AudioStreamPlayer.new()
	p.stream = chosen
	p.volume_db = roar_volume_db
	p.pitch_scale = rng.randf_range(pitch_min, pitch_max)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func set_cinematic_mode(enabled: bool) -> void:
	if enabled:
		behavior_active = false
		is_busy = true
		_interrupt_motion()
		_kill_tween(movement_tween)
		_kill_tween(body_tween)
		_kill_tween(idle_tween)
		_kill_tween(select_tween)
		_kill_tween(element_tween)
		_kill_tween(hover_tween)
		_kill_tween(reaction_tween)
		body_pivot.position = Vector2.ZERO
		body_pivot.rotation = 0.0
		body_pivot.scale = Vector2(-facing, 1.0)
		name_label.rotation = 0.0
		name_label.scale = Vector2.ONE
		sprite.scale = Vector2.ONE
		sprite.rotation = 0.0
		shadow.scale = Vector2.ONE
	else:
		is_busy = false
		if current_stage > 0 and not behavior_active:
			behavior_active = true
			_behavior_loop()
			_breathing_loop()
			_element_loop()
		_refresh_visual_emphasis(true)

func play_cinematic_roar(pitch_min: float = 0.95, pitch_max: float = 1.08, chance: float = 1.0) -> void:
	_play_roar(pitch_min, pitch_max, chance)

func play_cinematic_pulse(power: float = 1.0) -> void:
	_play_landing_burst(power)

func set_facing_immediate(dir: float) -> void:
	facing = -1.0 if dir < 0.0 else 1.0
	if is_instance_valid(body_pivot):
		body_pivot.scale.x = -facing

func play_training_reaction(result: Dictionary) -> void:
	_interrupt_motion()
	is_busy = true
	_refresh_visual_emphasis(true)

	_spawn_float_text("Training!", Color(0.65, 0.90, 1.0))

	var prep: Tween = create_tween()
	prep.tween_property(body_pivot, "scale", Vector2(-facing * 1.08, 0.92), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	prep.parallel().tween_property(body_pivot, "position:y", -6.0, 0.08)
	prep.parallel().tween_property(shadow, "scale", Vector2(1.08, 1.08), 0.08)
	await prep.finished

	var burst: Tween = create_tween()
	burst.tween_property(body_pivot, "position:y", -14.0, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	burst.parallel().tween_property(body_pivot, "rotation", deg_to_rad(-8.0 * facing), 0.10)
	burst.parallel().tween_property(shadow, "scale", Vector2(0.86, 0.86), 0.10)

	burst.tween_property(body_pivot, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	burst.parallel().tween_property(body_pivot, "rotation", 0.0, 0.12)
	burst.parallel().tween_property(body_pivot, "scale", Vector2(-facing * 0.95, 1.06), 0.12)
	burst.parallel().tween_property(shadow, "scale", Vector2.ONE, 0.12)
	await burst.finished

	_play_landing_burst(0.9)

	var stat_gains: Dictionary = result.get("stat_gains", {})
	for stat_key in stat_gains.keys():
		var amount: int = int(stat_gains.get(stat_key, 0))
		if amount > 0:
			_spawn_float_text("+" + str(amount) + " " + str(stat_key).capitalize(), Color(1.0, 0.90, 0.55))
			await get_tree().create_timer(0.18).timeout

	if bool(result.get("breakthrough", false)):
		_play_roar(0.92, 1.04, 1.0)
		_spawn_float_text("Breakthrough!", Color(1.0, 0.78, 0.30))

		var breakthrough_tw: Tween = create_tween()
		breakthrough_tw.tween_property(body_pivot, "scale", Vector2(-facing * 1.16, 0.86), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		breakthrough_tw.parallel().tween_property(body_pivot, "position:y", -10.0, 0.10)
		breakthrough_tw.tween_property(body_pivot, "scale", Vector2(-facing, 1.0), 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		breakthrough_tw.parallel().tween_property(body_pivot, "position:y", 0.0, 0.18)
		await breakthrough_tw.finished

		_play_landing_burst(1.25)

	is_busy = false
	_refresh_visual_emphasis(false)
	
func play_rest_reaction() -> void:
	_interrupt_motion()
	is_busy = true
	_refresh_visual_emphasis(true)

	_spawn_float_text("Rested", Color(0.70, 1.0, 0.85))

	var tw: Tween = create_tween()
	tw.tween_property(body_pivot, "position:y", 10.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(body_pivot, "scale", Vector2(-facing * 1.04, 0.90), 0.18)
	tw.parallel().tween_property(body_pivot, "rotation", deg_to_rad(-6.0 * facing), 0.18)
	tw.parallel().tween_property(shadow, "scale", Vector2(1.06, 1.06), 0.18)

	await get_tree().create_timer(0.20).timeout

	var recover: Tween = create_tween()
	recover.tween_property(body_pivot, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	recover.parallel().tween_property(body_pivot, "scale", Vector2(-facing, 1.0), 0.22)
	recover.parallel().tween_property(body_pivot, "rotation", 0.0, 0.22)
	recover.parallel().tween_property(shadow, "scale", Vector2.ONE, 0.22)
	await recover.finished

	is_busy = false
	_refresh_visual_emphasis(false)
