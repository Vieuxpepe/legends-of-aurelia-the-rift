@tool # <--- Allows the colored tile to draw inside the Godot Editor!
extends Node2D

const Map01EnemyPassivesHelpers = preload("res://Scripts/Core/BattleField/BattleFieldMap01EnemyPassivesHelpers.gd")

signal died(node: Node2D, killer: Node2D)
signal damaged(current_hp: int)

enum Faction { ENEMY, ALLY, PLAYER }

@export_category("Destructible Stats")
@export var object_name: String = "Spawner Tent"
@export var max_hp: int = 40
var current_hp: int = 40
var is_defending: bool = false
var base_color: Color = Color.WHITE

# --- ADD THESE DUMMY RPG STATS FOR COMBAT MATH ---
@onready var unit_name: String = object_name
var speed: int = 0
var agility: int = 0
var defense: int = 0
var resistance: int = 0
var strength: int = 0
var magic: int = 0
var equipped_weapon: Resource = null
var ability: String = ""
# -------------------------------------------------

@export_category("Spawner Settings")
@export var spawner_faction: Faction = Faction.ENEMY:
	set(value):
		spawner_faction = value
		queue_redraw() # Instantly updates the tile color in the Editor!

@export var base_unit_scene: PackedScene 
@export var unit_data: Resource 
@export var spawn_vfx_scene: PackedScene
@export var static_vfx_scene: PackedScene
@export var spawn_sound: AudioStream
@export var max_units: int = 3
@export var initial_delay: int = 1
@export var cooldown_turns: int = 3
var static_timer: Timer
var micro_spark_timer: Timer

var slot_timers: Array[int] = []
var active_units: Dictionary = {}

@onready var health_bar: ProgressBar = get_node_or_null("HealthBar")

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	unit_name = object_name
	base_color = modulate
	current_hp = max_hp
	
	if health_bar != null:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
		
	for i in range(max_units):
		slot_timers.append(initial_delay + i)
		active_units[i] = null

	# ==========================================
	# --- NEW: RIFT PULSE ANIMATION ---
	# ==========================================
	var spr = get_node_or_null("Sprite2D") # Finds your Rift image
	if spr == null: spr = get_node_or_null("Sprite")
	
	if spr:
		var base_scale = spr.scale
		var pulse = create_tween().set_loops()
		# Slowly swell up 8%
		pulse.tween_property(spr, "scale", base_scale * 1.08, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Slowly shrink back down
		pulse.tween_property(spr, "scale", base_scale * 0.96, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# ==========================================
	# --- NEW: RANDOM STATIC TIMER ---
	# ==========================================
	static_timer = Timer.new()
	add_child(static_timer)
	static_timer.timeout.connect(_on_static_timer_timeout)
	# Trigger the first spark somewhere between 1 and 3 seconds from now
	static_timer.start(randf_range(1.0, 3.0))

	# ==========================================
	# --- NEW: RAPID MICRO-SPARK TIMER ---
	# ==========================================
	micro_spark_timer = Timer.new()
	add_child(micro_spark_timer)
	micro_spark_timer.timeout.connect(_on_micro_spark_timeout)
	
	# Start extremely fast! (Between 0.1 and 0.6 seconds)
	micro_spark_timer.start(randf_range(0.1, 0.6))

func _draw() -> void:
	# 1. Choose the Faction Color
	var tile_color = Color(0.8, 0.2, 0.2, 0.4) # Red for Enemy
	var border_color = Color(1.0, 0.2, 0.2, 0.8)
	
	if spawner_faction == Faction.ALLY:
		tile_color = Color(0.2, 0.8, 0.2, 0.4) # Green for Ally
		border_color = Color(0.2, 1.0, 0.2, 0.8)
	elif spawner_faction == Faction.PLAYER:
		tile_color = Color(0.2, 0.4, 0.8, 0.4) # Blue for Player
		border_color = Color(0.2, 0.6, 1.0, 0.8)
		
	# 2. Draw the transparent base and a crisp border (Assuming 64x64 cell size)
	draw_rect(Rect2(0, 0, 64, 64), tile_color)
	draw_rect(Rect2(0, 0, 64, 64), border_color, false, 2.0)

func take_damage(amount: int, attacker: Node = null) -> void:
	if Engine.is_editor_hint():
		return
	
	current_hp -= amount
	if current_hp < 0:
		current_hp = 0

	emit_signal("damaged", current_hp)
	
	if health_bar != null:
		var bar_tween = create_tween()
		bar_tween.tween_property(health_bar, "value", current_hp, 0.2)
		
	var flash = create_tween()
	flash.tween_property(self, "modulate", Color.RED, 0.1)
	flash.tween_property(self, "modulate", base_color, 0.1)
	
	if current_hp <= 0:
		emit_signal("died", self, attacker)
		queue_free()

func process_turn(battlefield: Node2D, active_faction: int) -> void:
	if Engine.is_editor_hint():
		return
	
	if spawner_faction != active_faction:
		return
		
	if base_unit_scene == null or unit_data == null:
		print("WARNING: Spawner is missing either its Base Scene or its .tres Data!")
		return
	
	var spawned_this_turn = false
	
	for i in range(max_units):
		if active_units[i] == null:
			if slot_timers[i] > 0:
				slot_timers[i] -= 1
			
			if slot_timers[i] == 0 and not spawned_this_turn:
				if _try_spawn_unit(battlefield, i):
					spawned_this_turn = true
					slot_timers[i] = -1
					await get_tree().create_timer(0.65).timeout

func _try_spawn_unit(battlefield: Node2D, slot: int) -> bool:
	var my_pos = battlefield.get_grid_pos(self)
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	directions.shuffle() 
	
	for dir in directions:
		var target_pos = my_pos + dir
		
		if target_pos.x < 0 or target_pos.x >= battlefield.GRID_SIZE.x or target_pos.y < 0 or target_pos.y >= battlefield.GRID_SIZE.y:
			continue
			
		var is_solid = battlefield.astar.is_point_solid(target_pos)
		var occupant = battlefield.get_occupant_at(target_pos)
		
		if occupant == null and not is_solid:
			var new_unit = base_unit_scene.instantiate()
			new_unit.data = unit_data.duplicate(true)
			new_unit.set("is_custom_avatar", false)
			new_unit.set_meta("is_temporary_summon", true)
			
			var target_container = battlefield.enemy_container
			var spawn_text = "AMBUSH!"
			var spawn_color = Color.PURPLE
			
			if spawner_faction == Faction.ALLY:
				target_container = battlefield.ally_container
				spawn_text = "REINFORCEMENTS!"
				spawn_color = Color.LIME
			elif spawner_faction == Faction.PLAYER:
				target_container = battlefield.player_container
				spawn_text = "RECRUIT!"
				spawn_color = Color.CYAN
			
			target_container.add_child(new_unit)
			new_unit.position = Vector2(target_pos.x * battlefield.CELL_SIZE.x, target_pos.y * battlefield.CELL_SIZE.y)
			
			# ==========================================
			# --- THE EPIC SPAWN SEQUENCE ---
			# ==========================================
			# 1. Sound and Shake
			battlefield.screen_shake(12.0, 0.3)
			
			# --- NEW: CUSTOM SPAWN SOUND OR HEAVY THUD ---
			if spawn_sound != null:
				# Spawns a temporary audio player just for this rift!
				var custom_audio = AudioStreamPlayer.new()
				custom_audio.stream = spawn_sound
				custom_audio.pitch_scale = randf_range(0.9, 1.1)
				battlefield.add_child(custom_audio)
				custom_audio.play()
				custom_audio.finished.connect(custom_audio.queue_free)
			elif battlefield.crit_sound and battlefield.crit_sound.stream:
				# Fallback: A deep, menacing thud instead of the happy level-up chime!
				battlefield.crit_sound.pitch_scale = randf_range(0.6, 0.8)
				battlefield.crit_sound.play()
			# ---------------------------------------------
				
			# --- 1.5 NEW: THE RIFT PORTAL VFX ---
			if spawn_vfx_scene != null:
				var fx = spawn_vfx_scene.instantiate()
				battlefield.add_child(fx)
				fx.global_position = new_unit.position + Vector2(32, 32) # Center it
				fx.z_index = 105 # Draw over the unit!
				fx.scale = Vector2(1.5, 1.5) # Scale it up slightly to fill the 64x64 tile
				
				# Optional: Tint the rift based on the faction!
				fx.modulate = spawn_color 
			# ------------------------------------
				
			# 2. Flash the ground tile
			var flash = ColorRect.new()
			flash.size = Vector2(64, 64)
			flash.color = spawn_color
			flash.position = new_unit.position
			battlefield.add_child(flash)
			
			var flash_tween = create_tween()
			flash_tween.tween_property(flash, "modulate:a", 0.0, 0.6)
			flash_tween.tween_callback(flash.queue_free)
			
			# 3. Elastic Pop-in Animation
			new_unit.modulate.a = 0.0
			var spr = new_unit.get_node_or_null("Sprite")
			if spr == null: spr = new_unit.get_node_or_null("Sprite2D")
			
			if spr:
				# Memorize the actual scale of the unit's sprite first!
				var original_scale = spr.scale 
				
				# Shrink it relative to its actual size
				spr.scale = original_scale * 0.1 
				
				var u_tween = create_tween().set_parallel(true)
				u_tween.tween_property(new_unit, "modulate:a", 1.0, 0.3)
				
				# Tween back to the original size, not Vector2.ONE!
				u_tween.tween_property(spr, "scale", original_scale, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			else:
				var u_tween = create_tween()
				u_tween.tween_property(new_unit, "modulate:a", 1.0, 0.3)
			# ==========================================
			
			if new_unit.has_signal("died"):
				new_unit.died.connect(battlefield._on_unit_died)
				new_unit.died.connect(_on_spawned_unit_died.bind(slot))

			if new_unit.has_signal("leveled_up"):
				new_unit.leveled_up.connect(battlefield._on_unit_leveled_up)

			Map01EnemyPassivesHelpers.ensure_finished_turn_hook(battlefield, new_unit)
			
			if "has_moved" in new_unit: new_unit.has_moved = true
			if "is_exhausted" in new_unit: new_unit.is_exhausted = true
			if new_unit.has_method("finish_turn"): new_unit.finish_turn()
			
			battlefield.spawn_loot_text(spawn_text, spawn_color, new_unit.global_position + Vector2(32, -32))
			battlefield.rebuild_grid()
			
			active_units[slot] = new_unit
			return true
			
	return false 

func _on_spawned_unit_died(node: Node2D, _killer: Node2D, slot: int) -> void:
	if active_units.has(slot) and active_units[slot] == node:
		active_units[slot] = null
		slot_timers[slot] = cooldown_turns


func _on_static_timer_timeout() -> void:
	if static_vfx_scene != null:
		var fx = static_vfx_scene.instantiate()
		add_child(fx)
		
		# Center it roughly on the rift (32, 32), plus a random jitter so it doesn't spark in the exact same place twice!
		fx.position = Vector2(32, 32) + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		
		# Randomly rotate the electricity so the arcs point in chaotic directions
		fx.rotation = randf_range(0, TAU)
		
		# Randomize the size slightly
		fx.scale = Vector2(randf_range(0.8, 1.2), randf_range(0.8, 1.2))
		
	# Pick a NEW random time for the next spark! (Between 0.5s and 4.0s)
	static_timer.start(randf_range(0.5, 4.0))

func _on_micro_spark_timeout() -> void:
	if static_vfx_scene != null:
		var fx = static_vfx_scene.instantiate()
		add_child(fx)
		
		# Spread them out a little further from the center
		fx.position = Vector2(32, 32) + Vector2(randf_range(-25, 25), randf_range(-25, 25))
		fx.rotation = randf_range(0, TAU)
		
		# --- THE JUICE: MAKE THEM TINY AND FAINT ---
		fx.scale = Vector2(randf_range(0.2, 0.4), randf_range(0.2, 0.4))
		fx.modulate.a = randf_range(0.4, 0.8) # Slight transparency for depth
		
	# Restart the timer very quickly!
	micro_spark_timer.start(randf_range(0.1, 0.8))
