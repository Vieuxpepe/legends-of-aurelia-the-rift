extends Node2D

var _particles: Array[Dictionary] = []
var _texture: ImageTexture
var vp_size: Vector2

var emission_rect: Vector2
var amount: int = 120

func _ready() -> void:
	vp_size = get_viewport_rect().size
	emission_rect = vp_size
	
	# Generate soft circular texture
	var img = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	var center = Vector2(16, 16)
	var radius = 15.0
	for x in range(32):
		for y in range(32):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				var alpha = clampf(1.0 - (dist / radius), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, alpha * alpha))
			else:
				img.set_pixel(x, y, Color(1, 1, 1, 0))
	_texture = ImageTexture.create_from_image(img)
	
	# Initial spawn
	for i in range(amount):
		_spawn_particle(true)

func _spawn_particle(random_life: bool = false) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _texture
	
	var pos = Vector2(
		randf_range(0, emission_rect.x),
		randf_range(0, emission_rect.y)
	)
	var scale_val = randf_range(0.3, 0.8)
	sprite.position = pos
	sprite.scale = Vector2(scale_val, scale_val)
	
	var lifetime = randf_range(8.0, 12.0)
	var current_life = randf_range(0.0, lifetime) if random_life else 0.0
	var vel_x = randf_range(10.0, 35.0)
	var vel_y = randf_range(-40.0, -15.0)
	
	sprite.modulate = Color(1.0, 0.6, 0.15, 0.0) # Start invisible
	add_child(sprite)
	
	_particles.append({
		"sprite": sprite,
		"velocity": Vector2(vel_x, vel_y),
		"lifetime": lifetime,
		"age": current_life,
		"base_scale": scale_val
	})

func _process(delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
	var repel_radius := 180.0
	var repel_force := 450.0
	
	for i in range(_particles.size() - 1, -1, -1):
		var p = _particles[i]
		p.age += delta
		if p.age >= p.lifetime:
			p.sprite.queue_free()
			_particles.remove_at(i)
			_spawn_particle()
			continue
			
		# Movement & Gravity
		p.velocity.y += 10.0 * delta # base gravity
		
		# Mouse Repel Logic
		var dist = p.sprite.position.distance_to(mouse_pos)
		if dist < repel_radius:
			var force: float = (1.0 - (dist / repel_radius)) * repel_force
			var dir = (p.sprite.position - mouse_pos).normalized()
			p.velocity += dir * force * delta
			
		# Apply drag so they don't fly away infinitely
		p.velocity = p.velocity.lerp(Vector2(p.velocity.x, min(p.velocity.y, -10.0)), 1.2 * delta)
		
		p.sprite.position += p.velocity * delta
		
		# Alpha fading
		var alpha_ratio = p.age / p.lifetime
		var a = 1.0
		if alpha_ratio < 0.2:
			a = alpha_ratio / 0.2
		elif alpha_ratio > 0.8:
			a = 1.0 - ((alpha_ratio - 0.8) / 0.2)
		p.sprite.modulate.a = a * 0.9 # Base color alpha multiplier
