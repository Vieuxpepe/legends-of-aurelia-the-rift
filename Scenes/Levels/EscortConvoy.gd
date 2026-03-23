extends Node2D

signal died(node: Node2D, killer: Node2D)
signal leveled_up(node: Node2D, gains: Dictionary)
signal reached_destination
signal turn_completed 

@export_category("Escort Route")
@export var path_markers: Array[Marker2D] = []
@export var move_range: int = 3

@export_category("Convoy Stats")
@export var unit_name: String = "Merchant Convoy"
@export var max_hp: int = 50
var current_hp: int = 50
var defense: int = 8
var resistance: int = 6
var speed: int = 0
var agility: int = 0
var magic: int = 0
var strength: int = 0
var move_type: int = 0 
var equipped_weapon: Resource = null
var ability: String = ""

var is_defending: bool = false
var has_moved: bool = false
var is_exhausted: bool = false
var current_marker_idx: int = 0
var is_custom_avatar: bool = false
var ai_behavior: int = 999 
var last_turn_path: Array[Vector2i] = []
var last_turn_reached_destination: bool = false

@onready var health_bar = $HealthBar 

# ==========================================
# --- NEW: MULTI-TILE FOOTPRINT (2x3 Grid) ---
# ==========================================
var footprint_offsets: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), # Top Row
	Vector2i(0, 1), Vector2i(1, 1), # Middle Row
	Vector2i(0, 2), Vector2i(1, 2)  # Bottom Row
]

# The Battlefield will call this to find out everywhere the cart is standing
func get_occupied_tiles(bf: Node2D = null) -> Array[Vector2i]:
	var my_pos = Vector2i(int(global_position.x / 64), int(global_position.y / 64))
	var tiles: Array[Vector2i] = []
	for offset in footprint_offsets:
		tiles.append(my_pos + offset)
	return tiles

func _ready() -> void:
	current_hp = max_hp
	if health_bar != null:
		health_bar.max_value = max_hp
		health_bar.value = current_hp

func take_damage(amount: int, attacker: Node2D = null) -> void:
	current_hp -= amount
	if health_bar != null:
		var bar_tween = create_tween()
		bar_tween.tween_property(health_bar, "value", current_hp, 0.2)
		
	var flash = create_tween()
	flash.tween_property(self, "modulate", Color.RED, 0.1)
	flash.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	if current_hp <= 0:
		emit_signal("died", self, attacker)
		queue_free()

func process_escort_turn(battlefield: Node2D) -> void:
	has_moved = true
	is_exhausted = true
	last_turn_path.clear()
	last_turn_reached_destination = false

	var start_pos := Vector2i(int(global_position.x / 64), int(global_position.y / 64))
	last_turn_path.append(start_pos)

	if current_hp <= 0 or path_markers.is_empty():
		emit_signal("turn_completed")
		return
		
	var stepped_at_least_once = false
	
	for step in range(move_range):
		var target_marker = path_markers[current_marker_idx]
		if target_marker == null: break
		
		var my_pos = Vector2i(int(global_position.x / 64), int(global_position.y / 64))
		var target_pos = battlefield.get_grid_pos(target_marker)
		
		if my_pos == target_pos:
			current_marker_idx += 1
			if current_marker_idx >= path_markers.size():
				last_turn_reached_destination = true
				emit_signal("reached_destination")
				emit_signal("turn_completed")
				return
			target_marker = path_markers[current_marker_idx]
			target_pos = battlefield.get_grid_pos(target_marker)
			
		var dir = Vector2i.ZERO
		if my_pos.x < target_pos.x: dir.x = 1
		elif my_pos.x > target_pos.x: dir.x = -1
		elif my_pos.y < target_pos.y: dir.y = 1
		elif my_pos.y > target_pos.y: dir.y = -1
		
		var next_base_tile = my_pos + dir
		var is_blocked = false
		
		# --- MULTI-TILE COLLISION CHECK ---
		var current_tiles = get_occupied_tiles()
		var next_tiles = []
		for offset in footprint_offsets:
			next_tiles.append(next_base_tile + offset)
			
		# Temporarily clear our current physical body from the grid so we don't trip over ourselves!
		for t in current_tiles: battlefield.astar.set_point_solid(t, false)
			
		for nt in next_tiles:
			var occupant = battlefield.get_occupant_at(nt)
			if occupant != null and occupant != self:
				is_blocked = true; break
				
			if battlefield.astar.is_point_solid(nt):
				is_blocked = true; break
				
		# Restore our physical body
		for t in current_tiles: battlefield.astar.set_point_solid(t, true)
			
		if is_blocked:
			if not stepped_at_least_once:
				await _show_blocked_msg(battlefield)
			break 
			
		stepped_at_least_once = true
		var pixel_pos = Vector2(next_base_tile.x * 64, next_base_tile.y * 64)
		last_turn_path.append(next_base_tile)
		
		var tween = create_tween()
		tween.tween_property(self, "global_position", pixel_pos, 0.25).set_trans(Tween.TRANS_LINEAR)
		
		if battlefield.select_sound and battlefield.select_sound.stream != null:
			battlefield.select_sound.pitch_scale = 0.8
			battlefield.select_sound.play()
			
		await tween.finished
		battlefield.rebuild_grid() 

		if next_base_tile == battlefield.get_grid_pos(path_markers.back()):
			last_turn_reached_destination = true
			emit_signal("reached_destination")
			break
			
	emit_signal("turn_completed")

func _show_blocked_msg(bf: Node2D) -> void:
	if bf.has_method("spawn_loot_text"):
		bf.spawn_loot_text("Blocked!", Color.ORANGE, global_position + Vector2(64, -16))
		var bump = create_tween()
		bump.tween_property(self, "global_position:y", global_position.y + 10, 0.1)
		bump.tween_property(self, "global_position:y", global_position.y, 0.1)
		await bump.finished
