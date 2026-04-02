# ArenaLevel.gd
#
# Arena level controller: spawns the opponent's ghost team (roster + dragons) from
# ArenaManager.current_opponent_data into the battle. When this script is on a
# node under BattleField, it uses the battlefield's enemy container and cell size;
# otherwise it spawns as direct children of this node.
#
# Entry: _ready() -> _spawn_ghost_team(). Extension: add more spawn points via
# enemy_spawn_points or override _get_spawn_container() / _get_cell_size().

extends Node2D

const UNIT_SCENE: PackedScene = preload("res://Resources/Unit.tscn")
const Map01EnemyPassivesHelpers = preload("res://Scripts/Core/BattleField/BattleFieldMap01EnemyPassivesHelpers.gd")
const DEFAULT_CELL_SIZE: Vector2i = Vector2i(64, 64)

# Predefined grid coordinates for enemy spawns when no BattleField is found.
var enemy_spawn_points: Array[Vector2] = [
	Vector2(10, 5), Vector2(10, 6), Vector2(10, 7), Vector2(11, 5), Vector2(11, 6),
	Vector2(12, 5), Vector2(12, 6), Vector2(12, 7), Vector2(13, 5), Vector2(13, 6)
]

# Cached after _ready; used for spawning and signal connections.
var _battlefield: Node = null
var _spawn_container: Node = null
var _cell_size: Vector2i = DEFAULT_CELL_SIZE


func _ready() -> void:
	# Yield one frame to ensure _battlefield's @onready variables (like enemy_container) are initialized
	# because child _ready() runs before parent _ready().
	call_deferred("_initialize_spawns")

func _initialize_spawns() -> void:
	_resolve_spawn_target()
	_spawn_ghost_team()


# Resolves where to parent ghosts (BattleField's enemy container vs self) and cell size.
func _resolve_spawn_target() -> void:
	_battlefield = _find_battlefield()
	if _battlefield != null:
		var enc = _battlefield.get("enemy_container")
		if enc == null:
			# Fallback if onready hasn't fired or was missed
			enc = _battlefield.get_node_or_null("EnemyUnits")
		if enc != null and enc is Node:
			_spawn_container = enc
		if _battlefield.get("CELL_SIZE") != null:
			_cell_size = Vector2i(_battlefield.CELL_SIZE.x, _battlefield.CELL_SIZE.y)
	if _spawn_container == null:
		_spawn_container = self
		_cell_size = DEFAULT_CELL_SIZE


func _find_battlefield() -> Node:
	if get_parent() != null and get_parent().get("enemy_container") != null:
		return get_parent()
	var root = get_tree().current_scene
	if root != null and root.get("enemy_container") != null:
		return root
	return null


func _get_next_spawn_position(index: int) -> Vector2:
	var p: Vector2
	if index < enemy_spawn_points.size():
		p = enemy_spawn_points[index]
	else:
		# Fallback pattern if we run out of defined manual spawn points
		var offset = index - enemy_spawn_points.size()
		p = Vector2(9 - (offset / 3), 5 + (offset % 3))
	
	# Add half cell size to perfectly center the units in the grid tile
	return Vector2(p.x * _cell_size.x + _cell_size.x * 0.5, p.y * _cell_size.y + _cell_size.y * 0.5)


func _spawn_ghost_team() -> void:
	var opp_data: Dictionary = ArenaManager.current_opponent_data

	if opp_data.is_empty():
		push_warning("ArenaLevel: No opponent data; skipping ghost spawn.")
		return

	var meta: Dictionary = opp_data.get("metadata", {})
	var roster: Array = meta.get("roster", [])
	var dragons: Array = meta.get("dragons", [])
	var spawn_index: int = 0

	# Clear existing ghosts in the container so we don't double up with editor/other spawners.
	if _spawn_container != self:
		for child in _spawn_container.get_children():
			if child.get("is_arena_ghost") == true:
				child.queue_free()

	for unit_dict in roster:
		var ghost: Node2D = _spawn_one_ghost_unit(unit_dict, false)
		if ghost != null:
			ghost.position = _get_next_spawn_position(spawn_index)
			_spawn_container.add_child(ghost)
			_connect_ghost_signals(ghost)
			_apply_ghost_visuals(ghost, unit_dict)
			if ghost.has_method("setup_ghost_ui"):
				ghost.setup_ghost_ui()
			spawn_index += 1

	for d_dict in dragons:
		var ghost_dragon: Node2D = _spawn_one_ghost_dragon(d_dict)
		if ghost_dragon != null:
			ghost_dragon.position = _get_next_spawn_position(spawn_index)
			_spawn_container.add_child(ghost_dragon)
			_connect_ghost_signals(ghost_dragon)
			_apply_ghost_dragon_visuals(ghost_dragon, d_dict)
			if ghost_dragon.has_method("setup_ghost_ui"):
				ghost_dragon.setup_ghost_ui()
			spawn_index += 1


func _spawn_one_ghost_unit(unit_dict: Dictionary, _is_dragon: bool) -> Node2D:
	var ghost: Node2D = UNIT_SCENE.instantiate()
	ghost.set_meta("is_arena_ghost", true)
	ghost.set("is_arena_ghost", true)

	if "team" in ghost:
		ghost.team = 1
	if "is_enemy" in ghost:
		ghost.is_enemy = true

	ghost.set("unit_name", unit_dict.get("unit_name", "Gladiator"))
	ghost.set("unit_class", unit_dict.get("class", "Mercenary"))
	ghost.set("unit_class_name", unit_dict.get("class", "Mercenary"))
	ghost.level = unit_dict.get("level", 1)
	ghost.max_hp = unit_dict.get("max_hp", 20)
	ghost.current_hp = ghost.max_hp
	ghost.strength = unit_dict.get("strength", 5)
	ghost.magic = unit_dict.get("magic", 0)
	ghost.defense = unit_dict.get("defense", 3)
	ghost.resistance = unit_dict.get("resistance", 1)
	ghost.speed = unit_dict.get("speed", 4)
	ghost.agility = unit_dict.get("agility", 3)
	ghost.move_range = unit_dict.get("move_range", 4)
	if ghost.get("ability") != null:
		ghost.ability = unit_dict.get("ability", "None")

	_create_ghost_weapon(ghost, unit_dict.get("equipped_weapon_name", "Ghost Blade"), 5, 10, 1, 1)
	var safe_data = UnitData.new()
	safe_data.portrait = null
	ghost.set("data", safe_data)

	return ghost


func _spawn_one_ghost_dragon(d_dict: Dictionary) -> Node2D:
	var ghost: Node2D = UNIT_SCENE.instantiate()
	ghost.set_meta("is_arena_ghost", true)
	ghost.set_meta("is_dragon", true)
	ghost.set("is_arena_ghost", true)

	if "team" in ghost:
		ghost.team = 1
	if "is_enemy" in ghost:
		ghost.is_enemy = true

	ghost.set("unit_name", d_dict.get("name", "Dragon"))
	ghost.set("unit_class", d_dict.get("element", "Fire") + " Dragon")
	ghost.set("unit_class_name", d_dict.get("element", "Fire") + " Dragon")
	ghost.max_hp = d_dict.get("max_hp", 25)
	ghost.current_hp = ghost.max_hp
	ghost.strength = d_dict.get("strength", 8)
	ghost.magic = d_dict.get("magic", 8)
	ghost.defense = d_dict.get("defense", 5)
	ghost.resistance = d_dict.get("resistance", 4)
	ghost.speed = d_dict.get("speed", 5)
	ghost.agility = d_dict.get("agility", 4)
	ghost.move_range = 5

	var fang = WeaponData.new()
	fang.weapon_name = "Ghost Fang"
	fang.might = 6
	fang.min_range = 1
	fang.max_range = 1
	ghost.equipped_weapon = fang

	var safe_data = UnitData.new()
	safe_data.portrait = null
	ghost.set("data", safe_data)

	return ghost


func _create_ghost_weapon(unit: Node2D, weapon_name: String, might: int, hit_bonus: int, min_range: int, max_range: int) -> void:
	var wpn = WeaponData.new()
	wpn.weapon_name = weapon_name
	wpn.might = might
	wpn.hit_bonus = hit_bonus
	wpn.min_range = min_range
	wpn.max_range = max_range
	unit.equipped_weapon = wpn


func _connect_ghost_signals(ghost: Node2D) -> void:
	if _battlefield == null:
		return
	if ghost.has_signal("died") and _battlefield.has_method("_on_unit_died"):
		ghost.died.connect(_battlefield._on_unit_died)
	if ghost.has_signal("leveled_up") and _battlefield.has_method("_on_unit_leveled_up"):
		ghost.leveled_up.connect(_battlefield._on_unit_leveled_up)
	if _battlefield is BattleField:
		Map01EnemyPassivesHelpers.ensure_finished_turn_hook(_battlefield as BattleField, ghost)


func _apply_ghost_visuals(ghost: Node2D, unit_dict: Dictionary) -> void:
	ghost.base_color = Color(1.0, 0.7, 0.7)
	ghost.modulate = ghost.base_color

	var s_path: String = unit_dict.get("sprite_path", "")
	var p_path: String = unit_dict.get("portrait_path", "")
	if s_path != "" and ResourceLoader.exists(s_path):
		var sprite_node = ghost.get_node_or_null("Sprite")
		if sprite_node == null:
			sprite_node = ghost.get_node_or_null("Sprite2D")
		if sprite_node:
			sprite_node.texture = load(s_path) as Texture2D
	var data = ghost.get("data")
	if data != null:
		if p_path != "" and ResourceLoader.exists(p_path):
			data.portrait = load(p_path) as Texture2D
		else:
			data.portrait = null

func _apply_ghost_dragon_visuals(ghost: Node2D, d_dict: Dictionary) -> void:
	ghost.base_color = Color(1.0, 0.7, 0.7)
	ghost.modulate = ghost.base_color

	var elem: String = d_dict.get("element", "Fire").to_lower()
	var d_path: String = "res://Assets/Sprites/" + elem + "_dragon_sprite.png"
	if ResourceLoader.exists(d_path):
		var sprite_node = ghost.get_node_or_null("Sprite")
		if sprite_node == null:
			sprite_node = ghost.get_node_or_null("Sprite2D")
		if sprite_node:
			sprite_node.texture = load(d_path) as Texture2D
