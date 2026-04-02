@tool
extends Node2D
class_name TelegraphedSpawner

const Map01EnemyPassivesHelpers = preload("res://Scripts/Core/BattleField/BattleFieldMap01EnemyPassivesHelpers.gd")

@export_category("Reinforcement Settings")
@export var base_unit_scene: PackedScene
@export var default_enemy_data: Resource
@export var override_unit_data: Array[Resource] = []

@export var event_faction: int = 0 # 0 = Enemy Phase, 1 = Ally Phase, 2 = Player Phase
@export var warning_turn: int = 3
@export var spawn_turn: int = 4

# Relative to this node's grid position
@export var spawn_offsets: Array[Vector2i] = [Vector2i.ZERO]
@export var telegraph_offsets: Array[Vector2i] = []

@export var allow_nearby_fallback: bool = true
@export var fallback_radius: int = 2
@export var one_shot: bool = true

@export_category("Presentation")
@export_multiline var warning_text: String = "A horn echoes in the distance..."
@export_multiline var spawn_text: String = "Enemy reinforcements have arrived!"

@export var cell_size: Vector2i = Vector2i(64, 64)

@export var use_faction_coloring: bool = true
@export var telegraph_fill_color: Color = Color(1.0, 0.15, 0.15, 0.22)
@export var telegraph_outline_color: Color = Color(1.0, 0.35, 0.35, 0.95)

@export var enemy_fill_color: Color = Color(1.0, 0.15, 0.15, 0.22)
@export var enemy_outline_color: Color = Color(1.0, 0.35, 0.35, 0.95)

@export var ally_fill_color: Color = Color(0.20, 0.95, 0.35, 0.22)
@export var ally_outline_color: Color = Color(0.45, 1.00, 0.60, 0.95)

@export var player_fill_color: Color = Color(0.20, 0.55, 1.00, 0.22)
@export var player_outline_color: Color = Color(0.50, 0.80, 1.00, 0.95)

@export var neutral_fill_color: Color = Color(1.0, 0.85, 0.20, 0.20)
@export var neutral_outline_color: Color = Color(1.0, 0.92, 0.45, 0.95)

@export var pulse_speed: float = 3.0
@export var pulse_fill_boost: float = 0.18
@export var pulse_outline_boost: float = 0.25

@export var pan_camera_on_warning: bool = true
@export var pan_camera_on_spawn: bool = true
@export var camera_pan_time: float = 0.35

@export_category("Zone Label")
@export var show_zone_warning_label: bool = true
@export var zone_warning_label_text: String = "REINFORCEMENTS NEXT TURN"
@export var zone_warning_label_color: Color = Color(1.0, 0.85, 0.2)

@export_category("Juice & VFX")
@export var warning_shake_power: float = 3.0
@export var warning_shake_time: float = 0.15
@export var spawn_vfx_scene: PackedScene
@export var static_vfx_scene: PackedScene
@export var spawn_sound: AudioStream

var has_warned: bool = false
var has_triggered: bool = false
var pulse_time: float = 0.0

func _ready() -> void:
	visible = true
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		pulse_time += delta
		queue_redraw()
		return

	if has_warned and not has_triggered:
		pulse_time += delta
		queue_redraw()

func is_targetable() -> bool:
	return false

func blocks_movement() -> bool:
	return false

func blocks_fliers() -> bool:
	return false

func process_turn(battlefield: Node2D, active_faction: int) -> void:
	if one_shot and has_triggered:
		return

	if active_faction != event_faction:
		return

	var turn_number: int = int(battlefield.current_turn)

	if not has_warned and turn_number >= warning_turn and turn_number < spawn_turn:
		await _show_warning(battlefield)

	if not has_triggered and turn_number >= spawn_turn:
		await _spawn_wave(battlefield)

func _show_warning(bf: Node2D) -> void:
	has_warned = true
	pulse_time = 0.0
	queue_redraw()

	var origin_grid: Vector2i = bf.get_grid_pos(self)
	var tele_tiles: Array[Vector2i] = _get_telegraph_tiles(origin_grid)

	if pan_camera_on_warning and tele_tiles.size() > 0:
		await _pan_camera_to_tile(bf, tele_tiles[0])

	if warning_text.strip_edges() != "" and bf.has_method("add_combat_log"):
		bf.add_combat_log(warning_text, "orange")

	if show_zone_warning_label and bf.has_method("spawn_loot_text") and tele_tiles.size() > 0:
		var center_world: Vector2 = _get_zone_center_world(tele_tiles)
		bf.spawn_loot_text(zone_warning_label_text, zone_warning_label_color, center_world + Vector2(0, -20))

	if bf.has_method("spawn_loot_text"):
		bf.spawn_loot_text("REINFORCEMENTS!", _get_zone_label_color(), global_position + Vector2(32, -40))

	if bf.has_method("screen_shake"):
		bf.screen_shake(warning_shake_power, warning_shake_time)

func _spawn_wave(bf: Node2D) -> void:
	has_triggered = true
	queue_redraw()

	var origin_grid: Vector2i = bf.get_grid_pos(self)
	var target_tiles: Array[Vector2i] = _get_spawn_tiles(origin_grid)
	var resolved_tiles: Array[Vector2i] = []

	for desired_tile in target_tiles:
		var final_tile: Vector2i = _resolve_spawn_tile(bf, desired_tile)
		if final_tile.x != -9999:
			resolved_tiles.append(final_tile)

	if pan_camera_on_spawn and resolved_tiles.size() > 0:
		await _pan_camera_to_tile(bf, resolved_tiles[0])

	var spawned_any: bool = false

	for i in range(resolved_tiles.size()):
		var enemy = _spawn_single_unit(bf, resolved_tiles[i], i)
		if enemy != null:
			spawned_any = true
			await get_tree().create_timer(0.12).timeout

	if spawn_text.strip_edges() != "" and bf.has_method("add_combat_log"):
		bf.add_combat_log(spawn_text, "tomato")

	if bf.has_method("spawn_loot_text") and resolved_tiles.size() > 0:
		var center_world: Vector2 = _get_zone_center_world(resolved_tiles)
		bf.spawn_loot_text("ARRIVED!", _get_zone_label_color(), center_world + Vector2(0, -20))

	if spawned_any:
		bf.rebuild_grid()
		if bf.has_method("update_fog_of_war"):
			bf.update_fog_of_war()
		if bf.has_method("update_objective_ui"):
			bf.update_objective_ui()

func _spawn_single_unit(bf: Node2D, spawn_tile: Vector2i, index: int) -> Node2D:
	if base_unit_scene == null:
		push_warning("TelegraphedSpawner is missing base_unit_scene.")
		return null

	var enemy = base_unit_scene.instantiate()
	if enemy == null:
		return null

	var chosen_data: Resource = default_enemy_data
	if index < override_unit_data.size() and override_unit_data[index] != null:
		chosen_data = override_unit_data[index]

	# IMPORTANT: assign data BEFORE add_child so Unit._ready() initializes correctly
	if chosen_data != null and ("data" in enemy or enemy.get("data") != null):
		enemy.data = chosen_data.duplicate(true)

	if "is_custom_avatar" in enemy:
		enemy.is_custom_avatar = false

	bf.enemy_container.add_child(enemy)
	enemy.position = Vector2(spawn_tile.x * cell_size.x, spawn_tile.y * cell_size.y)

	if "team" in enemy:
		enemy.team = 1
	if "is_enemy" in enemy:
		enemy.is_enemy = true

	if chosen_data != null and ("unit_name" in enemy or enemy.get("unit_name") != null):
		var d_name = chosen_data.get("display_name")
		if d_name == null or str(d_name).strip_edges() == "":
			d_name = chosen_data.get("unit_name")
		if d_name != null and str(d_name).strip_edges() != "":
			enemy.unit_name = str(d_name)

	if enemy.has_signal("died") and not enemy.died.is_connected(bf._on_unit_died):
		enemy.died.connect(bf._on_unit_died)

	if enemy.has_signal("leveled_up") and not enemy.leveled_up.is_connected(bf._on_unit_leveled_up):
		enemy.leveled_up.connect(bf._on_unit_leveled_up)

	Map01EnemyPassivesHelpers.ensure_finished_turn_hook(bf, enemy)

	if spawn_sound != null:
		var custom_audio = AudioStreamPlayer.new()
		bf.add_child(custom_audio)
		custom_audio.stream = spawn_sound
		custom_audio.pitch_scale = randf_range(0.95, 1.05)
		custom_audio.play()
		custom_audio.finished.connect(custom_audio.queue_free)

	if spawn_vfx_scene != null:
		var fx = spawn_vfx_scene.instantiate()
		bf.add_child(fx)
		fx.global_position = enemy.global_position + Vector2(cell_size.x / 2.0, cell_size.y / 2.0)
		fx.z_index = 105

	if static_vfx_scene != null:
		var spark = static_vfx_scene.instantiate()
		bf.add_child(spark)
		spark.global_position = enemy.global_position + Vector2(cell_size.x / 2.0, cell_size.y / 2.0)
		spark.rotation = randf_range(0.0, TAU)
		spark.scale = Vector2(0.5, 0.5)
		spark.z_index = 105

	enemy.modulate.a = 0.0
	var spr = enemy.get_node_or_null("Sprite")
	if spr == null:
		spr = enemy.get_node_or_null("Sprite2D")

	if spr:
		var original_scale = spr.scale
		spr.scale = original_scale * 0.2

		var tween = create_tween().set_parallel(true)
		tween.tween_property(enemy, "modulate:a", 1.0, 0.25)
		tween.tween_property(spr, "scale", original_scale, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		var tween = create_tween()
		tween.tween_property(enemy, "modulate:a", 1.0, 0.25)

	return enemy

func _resolve_spawn_tile(bf: Node2D, desired_tile: Vector2i) -> Vector2i:
	if _is_valid_spawn_tile(bf, desired_tile):
		return desired_tile

	if allow_nearby_fallback:
		return _find_nearby_valid_tile(bf, desired_tile, fallback_radius)

	return Vector2i(-9999, -9999)

func _get_spawn_tiles(origin_grid: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for offset in spawn_offsets:
		out.append(origin_grid + offset)
	return out

func _get_telegraph_tiles(origin_grid: Vector2i) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = telegraph_offsets if not telegraph_offsets.is_empty() else spawn_offsets
	var out: Array[Vector2i] = []
	for offset in offsets:
		out.append(origin_grid + offset)
	return out

func _is_valid_spawn_tile(bf: Node2D, tile: Vector2i) -> bool:
	if tile.x < 0 or tile.x >= bf.GRID_SIZE.x:
		return false
	if tile.y < 0 or tile.y >= bf.GRID_SIZE.y:
		return false
	if bf.astar.is_point_solid(tile):
		return false
	if bf.get_occupant_at(tile) != null:
		return false
	return true

func _find_nearby_valid_tile(bf: Node2D, center: Vector2i, radius: int) -> Vector2i:
	var candidates: Array[Vector2i] = []

	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			var tile = Vector2i(x, y)
			if _is_valid_spawn_tile(bf, tile):
				candidates.append(tile)

	if candidates.is_empty():
		return Vector2i(-9999, -9999)

	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return abs(a.x - center.x) + abs(a.y - center.y) < abs(b.x - center.x) + abs(b.y - center.y)
	)

	return candidates[0]

func _pan_camera_to_tile(bf: Node2D, tile: Vector2i) -> void:
	var cam = bf.main_camera
	if cam == null:
		return

	var target_world: Vector2 = Vector2(
		tile.x * cell_size.x + cell_size.x / 2.0,
		tile.y * cell_size.y + cell_size.y / 2.0
	)

	if cam.anchor_mode == Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT:
		target_world -= (bf.get_viewport_rect().size * 0.5) / cam.zoom

	var c_tween = create_tween()
	c_tween.tween_property(cam, "global_position", target_world, camera_pan_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await c_tween.finished
	await get_tree().create_timer(0.15).timeout

func _get_zone_center_world(tiles: Array[Vector2i]) -> Vector2:
	if tiles.is_empty():
		return global_position

	var acc := Vector2.ZERO
	for tile in tiles:
		acc += Vector2(
			tile.x * cell_size.x + cell_size.x / 2.0,
			tile.y * cell_size.y + cell_size.y / 2.0
		)

	return acc / float(tiles.size())

func _get_zone_label_color() -> Color:
	var colors: Dictionary = _get_effective_colors()
	return colors["outline"]

func _get_effective_colors() -> Dictionary:
	if not use_faction_coloring:
		return {
			"fill": telegraph_fill_color,
			"outline": telegraph_outline_color
		}

	match event_faction:
		0:
			return {
				"fill": enemy_fill_color,
				"outline": enemy_outline_color
			}
		1:
			return {
				"fill": ally_fill_color,
				"outline": ally_outline_color
			}
		2:
			return {
				"fill": player_fill_color,
				"outline": player_outline_color
			}
		_:
			return {
				"fill": neutral_fill_color,
				"outline": neutral_outline_color
			}

func _draw() -> void:
	var offsets: Array[Vector2i] = telegraph_offsets if not telegraph_offsets.is_empty() else spawn_offsets

	if not Engine.is_editor_hint():
		if not has_warned or has_triggered:
			return

	var pulse01: float = 0.5 + 0.5 * sin(pulse_time * pulse_speed * TAU * 0.5)
	var colors: Dictionary = _get_effective_colors()

	for offset in offsets:
		var px: float = offset.x * cell_size.x
		var py: float = offset.y * cell_size.y

		var fill: Color = colors["fill"]
		var outline: Color = colors["outline"]

		fill.a = clamp(fill.a + (pulse01 * pulse_fill_boost), 0.0, 1.0)
		outline.a = clamp(outline.a + (pulse01 * pulse_outline_boost), 0.0, 1.0)

		var rect := Rect2(Vector2(px, py), Vector2(cell_size))
		draw_rect(rect, fill, true)
		draw_rect(rect, outline, false, 2.0)
