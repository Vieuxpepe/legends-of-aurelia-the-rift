class_name ExpeditionMapDatabase
extends RefCounted

# Lightweight, data-driven map catalog used by tavern/cartographer and world map.
static var expedition_maps: Array[Dictionary] = [
	{
		"id": "exp_map_shattered_sanctum",
		"display_name": "Shattered Sanctum Survey",
		"description": "A torn chart of collapsed sanctum routes. Opens a sanctioned expedition path.",
		"price": 320,
		"rarity": "Rare",
		"coop_enabled": true,
		"consumable": false,
		"world_node_id": "",
		"battle_scene_path": "res://Scenes/Levels/Level3.tscn",
		"battle_id": "shattered_sanctum_expedition",
		"recommended_level": 3,
		"danger_tier": 2,
		"reward_tags": ["relics", "sanctum", "cooperative_route"]
	}
]

static func get_all_maps() -> Array[Dictionary]:
	return expedition_maps.duplicate(true)

static func get_map_by_id(map_id: String) -> Dictionary:
	var key: String = str(map_id).strip_edges()
	if key == "":
		return {}

	for entry in expedition_maps:
		if str(entry.get("id", "")) == key:
			return entry.duplicate(true)

	return {}

static func get_cartographer_stock(current_level_index: int = 0) -> Array[Dictionary]:
	var stock: Array[Dictionary] = []
	var unlock_threshold: int = max(1, int(current_level_index) + 1)

	for entry in expedition_maps:
		var rec_level: int = int(entry.get("recommended_level", 1))
		if rec_level <= unlock_threshold:
			stock.append(entry.duplicate(true))

	if stock.is_empty():
		for entry in expedition_maps:
			stock.append(entry.duplicate(true))

	return stock

static func get_world_node_requirements() -> Dictionary:
	var requirements: Dictionary = {}
	for entry in expedition_maps:
		var world_node_id: String = str(entry.get("world_node_id", "")).strip_edges()
		var map_id: String = str(entry.get("id", "")).strip_edges()
		if world_node_id == "" or map_id == "":
			continue
		requirements[world_node_id] = map_id
	return requirements

