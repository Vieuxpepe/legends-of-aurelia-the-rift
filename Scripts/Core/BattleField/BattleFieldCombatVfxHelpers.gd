extends RefCounted

const BONE_CHIP_TEXTURE_PATH: String = "res://Resources/Materials/Icons/Bone.png"


static func _target_should_spawn_bone_chips(target_unit: Node2D) -> bool:
	if target_unit == null or not is_instance_valid(target_unit):
		return false
	var ud: Variant = target_unit.get("data")
	if ud != null and ud is UnitData and UnitData.unit_type_uses_bone_hit_debris((ud as UnitData).unit_type):
		return true
	var nv: Variant = target_unit.get("unit_name")
	if nv == null:
		return false
	var s: String = str(nv)
	return s == "Skeleton" or s == "Risen Dead"


## Undead struck: small bone chips using [member BONE_CHIP_TEXTURE_PATH] instead of blood.
static func spawn_bone_chip_burst(
	field,
	target_unit: Node2D,
	attacker_pos: Vector2,
	is_crit: bool = false,
	damage_kind: int = 0
) -> void:
	if field == null or target_unit == null or not is_instance_valid(target_unit):
		return
	var tex: Texture2D = load(BONE_CHIP_TEXTURE_PATH) as Texture2D
	if tex == null:
		push_warning("Bone chip VFX: texture missing at %s" % BONE_CHIP_TEXTURE_PATH)
		return

	var chips: CPUParticles2D = CPUParticles2D.new()
	field.add_child(chips)
	chips.z_index = 105
	chips.global_position = target_unit.global_position + Vector2(32, 32)
	chips.emitting = false
	chips.one_shot = true
	chips.explosiveness = 1.0
	chips.local_coords = false
	chips.texture = tex
	chips.lifetime = 0.38

	var dir: Vector2 = target_unit.global_position - attacker_pos
	if dir.length_squared() < 1.0:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	chips.direction = dir
	chips.spread = 38.0
	chips.gravity = Vector2(0, 980)

	if damage_kind == 1:
		chips.amount = 7 if is_crit else 5
		chips.initial_velocity_min = 190.0
		chips.initial_velocity_max = 260.0 if is_crit else 230.0
		chips.color = Color(0.78, 0.90, 1.0, 1.0)
	else:
		chips.amount = 9 if is_crit else 6
		chips.initial_velocity_min = 240.0
		chips.initial_velocity_max = 340.0 if is_crit else 300.0
		chips.color = Color(0.97, 0.94, 0.88, 1.0)

	var tex_max: float = maxf(float(tex.get_width()), float(tex.get_height()))
	var s_min: float = 0.14
	var s_max: float = 0.36
	if tex_max > 0.0:
		var norm: float = clampf(22.0 / tex_max, 0.08, 0.55)
		s_min = 0.45 * norm
		s_max = (1.35 if is_crit else 1.05) * norm
	chips.scale_amount_min = s_min
	chips.scale_amount_max = s_max

	chips.angular_velocity_min = -420.0
	chips.angular_velocity_max = 420.0
	chips.angle_min = -35.0
	chips.angle_max = 35.0

	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.22, 0.5))
	curve.add_point(Vector2(0.55, 0.12))
	curve.add_point(Vector2(1, 0))
	chips.scale_amount_curve = curve

	chips.restart()
	field.get_tree().create_timer(1.05, true, false, true).timeout.connect(chips.queue_free)


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
		# Purely vertical step: keep a stable facing (rotation stays 0).
		fx.flip_h = false

	fx.scale = Vector2(randf_range(1.0, 1.3), randf_range(0.8, 1.2))


## weapon_family: WeaponData.get_weapon_family(...) or CombatVfxHelpers.FAMILY_STAFF_UTILITY; -1 = legacy/default silhouette.
const FAMILY_STAFF_UTILITY := -2


static func _family_slash_visual_params(weapon_family: int) -> Dictionary:
	var sc_normal := Vector2(1.3, 1.3)
	var sc_crit := Vector2(2.5, 2.5)
	var mod_norm := Color(1.0, 1.0, 1.0, 1.0)
	var rot_jitter := 0.3

	match weapon_family:
		FAMILY_STAFF_UTILITY:
			sc_normal = Vector2(0.92, 0.92)
			sc_crit = Vector2(1.32, 1.32)
			mod_norm = Color(0.72, 1.0, 0.88, 1.0)
			rot_jitter = 0.14
		int(WeaponData.WeaponType.SWORD):
			sc_normal = Vector2(1.22, 1.22)
			sc_crit = Vector2(2.38, 2.38)
			mod_norm = Color(1.05, 1.08, 1.18, 1.0)
			rot_jitter = 0.22
		int(WeaponData.WeaponType.AXE):
			sc_normal = Vector2(1.38, 1.38)
			sc_crit = Vector2(2.62, 2.62)
			mod_norm = Color(1.12, 0.94, 0.88, 1.0)
			rot_jitter = 0.38
		int(WeaponData.WeaponType.LANCE):
			sc_normal = Vector2(1.42, 1.06)
			sc_crit = Vector2(2.48, 1.68)
			mod_norm = Color(1.05, 1.02, 0.95, 1.0)
			rot_jitter = 0.14
		int(WeaponData.WeaponType.BOW):
			sc_normal = Vector2(1.10, 1.04)
			sc_crit = Vector2(1.88, 1.58)
			mod_norm = Color(0.92, 1.08, 1.12, 1.0)
			rot_jitter = 0.36
		int(WeaponData.WeaponType.TOME):
			sc_normal = Vector2(1.18, 1.18)
			sc_crit = Vector2(2.12, 2.12)
			mod_norm = Color(0.68, 0.52, 1.05, 1.0)
			rot_jitter = 0.44
		int(WeaponData.WeaponType.NONE):
			sc_normal = Vector2(1.06, 1.06)
			sc_crit = Vector2(1.62, 1.62)
			mod_norm = Color(1.0, 0.94, 0.78, 1.0)
			rot_jitter = 0.2

	return {
		"sc_normal": sc_normal,
		"sc_crit": sc_crit,
		"mod_norm": mod_norm,
		"rot_jitter": rot_jitter,
	}


static func spawn_slash_effect(field, target_pos: Vector2, attacker_pos: Vector2, is_crit: bool = false, weapon_family: int = -1) -> void:
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

	var p: Dictionary = _family_slash_visual_params(weapon_family)
	var rot_jitter: float = p["rot_jitter"]

	# Add a tiny bit of random angle so combo hits don't look perfectly identical
	fx.rotation = dir.angle() + randf_range(-rot_jitter, rot_jitter)
	fx.flip_v = false

	fx.scale = p["sc_crit"] if is_crit else p["sc_normal"]
	if is_crit:
		fx.modulate = p["mod_norm"] * Color(1.38, 1.22, 1.12, 1.0)
	else:
		fx.modulate = p["mod_norm"]


## Thrust along attacker→defender (projectile-like). Prefers `piercing_fx_scene`, else narrow slash strip.
static func spawn_piercing_strike_effect(field, target_pos: Vector2, attacker_pos: Vector2, is_crit: bool = false, weapon_family: int = -1) -> void:
	var scene: PackedScene = field.piercing_fx_scene
	if scene == null:
		scene = field.slash_fx_scene
	if scene == null:
		print("WARNING: Piercing FX Scene is missing (no slash fallback). Assign piercing_fx_scene or slash_fx_scene on BattleField.")
		return

	var fx = scene.instantiate()
	field.add_child(fx)
	fx.z_index = 110

	var dir_vec: Vector2 = target_pos - attacker_pos
	var dist: float = dir_vec.length()
	var dir: Vector2
	if dist > 0.5:
		dir = dir_vec / dist
	else:
		dir = Vector2.RIGHT

	var using_dedicated_pierce: bool = field.piercing_fx_scene != null and scene == field.piercing_fx_scene

	if using_dedicated_pierce:
		# Impact center on defender; pull FX back along the thrust so it reads as driving into the target.
		var impact: Vector2 = target_pos + Vector2(32, 32)
		var pullback: float = clampf(dist * 0.32, 10.0, 52.0)
		fx.global_position = impact - dir * pullback
		# Assumes thrust art points along local +X (same convention as battle projectiles). If it points +Y, add PI/2.
		fx.rotation = dir.angle()
		fx.flip_h = false
		fx.flip_v = false
		var crit_mul: float = 1.2 if is_crit else 1.0
		fx.scale *= Vector2(crit_mul, crit_mul)
		var mod: Color = Color(0.90, 0.95, 1.06, 1.0)
		if is_crit:
			fx.modulate = mod * Color(1.38, 1.22, 1.12, 1.0)
		else:
			fx.modulate = mod
	else:
		fx.global_position = target_pos + Vector2(32, 32)
		var p: Dictionary = _family_slash_visual_params(weapon_family)
		var base_scale: Vector2 = p["sc_crit"] if is_crit else p["sc_normal"]
		fx.scale = Vector2(base_scale.x * 0.58, base_scale.y * 1.24)
		fx.rotation = dir.angle() + randf_range(-0.055, 0.055)
		fx.flip_v = false
		var mod2: Color = (p["mod_norm"] as Color) * Color(0.90, 0.95, 1.06, 1.0)
		if is_crit:
			fx.modulate = mod2 * Color(1.38, 1.22, 1.12, 1.0)
		else:
			fx.modulate = mod2


## Chunky impact read; prefers `bludgeon_fx_scene`, falls back to slash VFX.
static func spawn_bludgeon_impact_effect(field, target_pos: Vector2, attacker_pos: Vector2, is_crit: bool = false, weapon_family: int = -1) -> void:
	var scene: PackedScene = field.bludgeon_fx_scene
	if scene == null:
		scene = field.slash_fx_scene
	if scene == null:
		print("WARNING: Bludgeon FX Scene is missing (no slash fallback). Assign bludgeon_fx_scene or slash_fx_scene on BattleField.")
		return

	var fx = scene.instantiate()
	field.add_child(fx)
	fx.z_index = 110
	fx.global_position = target_pos + Vector2(32, 32)

	var p: Dictionary = _family_slash_visual_params(weapon_family)
	var base_scale: Vector2 = p["sc_crit"] if is_crit else p["sc_normal"]
	fx.scale = Vector2(base_scale.x * 1.34, base_scale.y * 1.12)
	fx.flip_v = false

	# BludgeoningEffect is a vertical frame strip (top → bottom in atlas). Full dir.angle() rotation
	# makes the read flip by quadrant; keep upright and only mirror left/right from attacker side.
	var using_dedicated_bludgeon: bool = field.bludgeon_fx_scene != null and scene == field.bludgeon_fx_scene
	if using_dedicated_bludgeon:
		fx.rotation = 0.0
		var dx: float = target_pos.x - attacker_pos.x
		if absf(dx) > 2.0:
			fx.flip_h = dx < 0.0
		else:
			fx.flip_h = false
	else:
		var dir: Vector2 = (target_pos - attacker_pos).normalized()
		fx.rotation = dir.angle() + randf_range(-0.44, 0.44)

	var mod: Color = (p["mod_norm"] as Color) * Color(1.08, 0.95, 0.82, 1.0)
	if is_crit:
		fx.modulate = mod * Color(1.38, 1.22, 1.12, 1.0)
	else:
		fx.modulate = mod


## Melee impacts for [method WeaponData.is_dragon_weapon]. Uses [member BattleField.claw_fx_scene] (default claw scene on the field).
static func spawn_claw_strike_effect(field, target_pos: Vector2, attacker_pos: Vector2, is_crit: bool = false) -> void:
	var scene: PackedScene = field.claw_fx_scene
	if scene == null:
		return
	var fx: Node = scene.instantiate()
	field.add_child(fx)
	fx.z_index = 110
	fx.global_position = target_pos + Vector2(32, 32)

	var dir: Vector2 = target_pos - attacker_pos
	if dir.length_squared() < 4.0:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()

	var asp: AnimatedSprite2D = fx as AnimatedSprite2D
	if asp == null:
		asp = _find_first_animated_sprite_under(fx)
	if asp == null:
		fx.queue_free()
		return

	var sc_mul: float = 1.32 if is_crit else 1.06
	asp.scale = asp.scale * sc_mul
	if is_crit:
		asp.modulate = asp.modulate * Color(1.22, 1.12, 0.95, 1.0)

	asp.rotation = dir.angle()
	asp.flip_h = false

	if asp.sprite_frames != null:
		var names: PackedStringArray = asp.sprite_frames.get_animation_names()
		var play_name: String = "default"
		if not asp.sprite_frames.has_animation(play_name) and names.size() > 0:
			play_name = names[0]
		if asp.sprite_frames.has_animation(play_name):
			asp.sprite_frames.set_animation_loop(play_name, false)
			asp.play(play_name)

	var cleanup: Callable = func():
		if is_instance_valid(fx):
			fx.queue_free()
	field.get_tree().create_timer(1.15, true, false, true).timeout.connect(cleanup)


static func _find_first_animated_sprite_under(n: Node) -> AnimatedSprite2D:
	if n == null:
		return null
	if n is AnimatedSprite2D:
		return n as AnimatedSprite2D
	for c in n.get_children():
		var found: AnimatedSprite2D = _find_first_animated_sprite_under(c)
		if found != null:
			return found
	return null


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


## damage_kind: 0 physical (red spray), 1 magic (cool spark-burst read)
static func spawn_blood_splatter(field, target_unit: Node2D, attacker_pos: Vector2, is_crit: bool = false, damage_kind: int = 0) -> void:
	if target_unit == null or not is_instance_valid(target_unit):
		return

	if _target_should_spawn_bone_chips(target_unit):
		spawn_bone_chip_burst(field, target_unit, attacker_pos, is_crit, damage_kind)
		return

	var target_name = target_unit.get("unit_name")
	if target_name == null:
		return

	# 1. THE LOGIC CHECK: props / [enum UnitData.UnitType] (constructs, spirits, etc.). Undead use bone burst above.
	var no_blood_types = ["Wooden Crate", "Spawner Tent", "Portable Fort"]
	if no_blood_types.has(target_name):
		return
	var ud: Variant = target_unit.get("data")
	if ud != null and ud is UnitData and UnitData.unit_type_suppresses_blood((ud as UnitData).unit_type):
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

	if damage_kind == 1:
		blood.amount = 34 if is_crit else 14
		blood.spread = 58.0
		blood.gravity = Vector2(0, 420)
		blood.initial_velocity_min = 120.0
		blood.initial_velocity_max = 300.0 if is_crit else 220.0
		blood.scale_amount_min = 2.2
		blood.scale_amount_max = 5.0
	else:
		# Increased the amount of droplets for a thicker spray
		blood.amount = 60 if is_crit else 25
		blood.spread = 75.0
		blood.gravity = Vector2(0, 800)
		blood.initial_velocity_min = 250.0
		blood.initial_velocity_max = 550.0 if is_crit else 350.0
		blood.scale_amount_min = 3.0
		blood.scale_amount_max = 7.0

	var dir = (target_unit.global_position - attacker_pos).normalized()
	blood.direction = dir

	# --- NEW: SHRINK OVER TIME ---
	# This makes the droplets shrink as they fly, making it look like real liquid dispersing!
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1)) # Start at 100% size
	curve.add_point(Vector2(1, 0)) # End at 0% size
	blood.scale_amount_curve = curve

	if damage_kind == 1:
		blood.color = Color(0.45, 0.78, 1.0, 1.0) if is_crit else Color(0.55, 0.72, 1.0, 1.0)
	else:
		# Brighter crimson color so it pops against the dark backgrounds
		blood.color = Color(0.8, 0.0, 0.0, 1.0)

	blood.restart()
	field.get_tree().create_timer(1.5, true, false, true).timeout.connect(blood.queue_free)
