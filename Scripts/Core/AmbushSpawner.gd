extends Node2D

@export_category("Ambush Settings")
@export var base_unit_scene: PackedScene 
@export var enemy_data: Resource         
@export var spawn_count: int = 3
@export var activation_distance: int = 6 
@export var spawner_faction: int = 0     

@export_category("Juice & VFX")
@export var spawn_vfx_scene: PackedScene
@export var static_vfx_scene: PackedScene
@export var spawn_sound: AudioStream

var has_triggered: bool = false

func _ready() -> void:
	# Start completely invisible!
	modulate.a = 0.0
	visible = false

func process_turn(battlefield: Node2D, active_faction: int) -> void:
	# If we already ambushed, or it's not the enemy turn, do nothing.
	if has_triggered or active_faction != spawner_faction:
		return
		
	# Find the VIP target (The Donkey)
	var target = battlefield.vip_target
	if target == null or not is_instance_valid(target):
		return 
		
	# Check the distance
	var dist = battlefield.get_distance(self, target)
	
	if dist <= activation_distance:
		await _trigger_ambush(battlefield)

func _trigger_ambush(bf: Node2D) -> void:
	has_triggered = true # Lock it so it never fires again
	
	# 1. THE CINEMATIC CAMERA PAN
	var cam = bf.main_camera
	if cam:
		var target_cam_pos = global_position + Vector2(32, 32)
		if cam.anchor_mode == Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT:
			target_cam_pos -= (bf.get_viewport_rect().size * 0.5) / cam.zoom
			
		var c_tween = create_tween()
		c_tween.tween_property(cam, "global_position", target_cam_pos, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await c_tween.finished
		await get_tree().create_timer(0.2).timeout
		
	# ==========================================
	# 2. THE SURPRISE REVEAL
	# ==========================================
	visible = true # Turn the node on
	
	# Play the custom tear sound
	if spawn_sound != null:
		var custom_audio = AudioStreamPlayer.new()
		custom_audio.stream = spawn_sound
		custom_audio.pitch_scale = randf_range(0.8, 1.0) # Deep rumble
		bf.add_child(custom_audio)
		custom_audio.play()
		custom_audio.finished.connect(custom_audio.queue_free)
	elif bf.has_node("DefendSound") and bf.get_node("DefendSound").stream:
		var snd = bf.get_node("DefendSound")
		snd.pitch_scale = 0.5
		snd.play()
		
	# Spawn the massive Rift explosion VFX
	if spawn_vfx_scene != null:
		var fx = spawn_vfx_scene.instantiate()
		bf.add_child(fx)
		fx.global_position = global_position + Vector2(32, 32)
		fx.scale = Vector2(2.0, 2.0) # Make it huge!
		fx.z_index = 105
		fx.modulate = Color.PURPLE
		
	bf.screen_shake(18.0, 0.5)
	
	if bf.has_method("add_combat_log"):
		bf.add_combat_log("AMBUSH! A tear in reality opens!", "tomato")
	if bf.has_method("spawn_loot_text"):
		bf.spawn_loot_text("AMBUSH!", Color.RED, global_position + Vector2(32, -40))

	# Fade the Rift Sprite in dramatically
	var reveal_tween = create_tween()
	reveal_tween.tween_property(self, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	await reveal_tween.finished
	await get_tree().create_timer(0.3).timeout # Tiny pause for tension
		
	# 3. CALCULATE SPAWN ZONES (Check a 5x5 grid around the rift)
	var my_pos = bf.get_grid_pos(self)
	var valid_tiles = []
	
	for x in range(my_pos.x - 2, my_pos.x + 3):
		for y in range(my_pos.y - 2, my_pos.y + 3):
			var check_pos = Vector2i(x, y)
			if check_pos.x >= 0 and check_pos.x < bf.GRID_SIZE.x and check_pos.y >= 0 and check_pos.y < bf.GRID_SIZE.y:
				if not bf.astar.is_point_solid(check_pos) and bf.get_occupant_at(check_pos) == null:
					valid_tiles.append(check_pos)
					
	valid_tiles.shuffle()
	
	# ==========================================
	# 4. SPAWN THE ENEMIES (With Elastic Pop-In)
	# ==========================================
	for i in range(min(spawn_count, valid_tiles.size())):
		var spawn_pos = valid_tiles[i]
		
		var enemy = base_unit_scene.instantiate()
		if enemy_data != null:
			enemy.data = enemy_data.duplicate()
		
		enemy.position = Vector2(spawn_pos.x * 64, spawn_pos.y * 64)
		bf.enemy_container.add_child(enemy)
		
		enemy.unit_name = "Rift Skeleton"
		enemy.modulate = Color(0.8, 0.5, 1.0) # Creepy purple tint
		
		# --- ELASTIC POP-IN ANIMATION ---
		enemy.modulate.a = 0.0
		var spr = enemy.get_node_or_null("Sprite")
		if spr == null: spr = enemy.get_node_or_null("Sprite2D")
		
		if spr:
			var original_scale = spr.scale 
			spr.scale = original_scale * 0.1 
			
			var u_tween = create_tween().set_parallel(true)
			u_tween.tween_property(enemy, "modulate:a", 1.0, 0.3)
			u_tween.tween_property(spr, "scale", original_scale, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		else:
			var u_tween = create_tween()
			u_tween.tween_property(enemy, "modulate:a", 1.0, 0.3)
			
		# Drop a micro spark on them as they spawn
		if static_vfx_scene != null:
			var spark = static_vfx_scene.instantiate()
			bf.add_child(spark)
			spark.global_position = enemy.global_position + Vector2(32, 32)
			spark.rotation = randf_range(0, TAU)
			spark.scale = Vector2(0.5, 0.5)
			spark.z_index = 105
			
		await get_tree().create_timer(0.15).timeout
		
	# 5. CLEANUP & HAND CONTROL BACK TO AI
	bf.rebuild_grid()
	
	# Slowly fade the rift out and delete it now that it's empty
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_SINE)
	fade.tween_callback(self.queue_free)
	
	await get_tree().create_timer(0.6).timeout
