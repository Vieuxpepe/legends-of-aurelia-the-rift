# ==============================================================================
# Script Name: ItemDatabase.gd
# Purpose: Dynamically loads and organizes all game items at boot.
# Overall Goal: Eliminate manual drag-and-drop arrays for merchants and loot.
# Project Fit: Runs as an Autoload (Singleton).
# Dependencies: Assumes items are saved as .tres files in res://Resources/
# AI/Code Reviewer Guidance:
#   - Entry Point: _ready() triggers the folder scan automatically.
#   - Core Logic Sections: _scan_folder recursively searches directories. 
#     get_leveled_shop_pool() gates items based on campaign progression.
# ==============================================================================

extends Node

var master_item_pool: Array[Resource] = []

var items_by_rarity: Dictionary = {
	"Common": [],
	"Uncommon": [],
	"Rare": [],
	"Epic": [],
	"Legendary": []
}

# Add any specific folders here you want the game to automatically scan.
var folders_to_scan: Array[String] = [
	"res://Resources/Materials/GeneratedMaterials/",
	"res://Resources/Weapons/",
	"res://Resources/GeneratedItems/"
]

# Purpose: Triggers the recursive scan when the game starts.
func _ready() -> void:
	print("--- ITEM DATABASE INITIALIZING ---")
	for folder in folders_to_scan:
		_scan_folder(folder)
	print("Total Items Loaded: ", master_item_pool.size())

# Purpose: Recursively searches a directory for .tres files and categorizes them.
# Inputs: path (String) - The directory path to search.
# Side Effects: Populates master_item_pool and items_by_rarity.
func _scan_folder(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				# If it's a folder, scan inside it
				_scan_folder(path + file_name + "/")
			else:
				# If it's a resource file, load it
				if file_name.ends_with(".tres") or file_name.ends_with(".res"):
					var res = load(path + file_name)
					if res:
						master_item_pool.append(res)
						
						# Categorize by rarity
						var rarity = str(res.get("rarity")) if res.get("rarity") != null else "Common"
						if items_by_rarity.has(rarity):
							items_by_rarity[rarity].append(res)
						else:
							items_by_rarity["Common"].append(res)
							
			file_name = dir.get_next()

# Purpose: Generates a safe pool of items for the merchant to sell based on story progress.
# Inputs: current_level_index (int) - The player's current progression.
# Outputs: Array[Resource] - A filtered list of allowed items.
func get_leveled_shop_pool(current_level_index: int) -> Array[Resource]:
	var allowed_pool: Array[Resource] = []
	
	# Common is always available
	allowed_pool.append_array(items_by_rarity["Common"])
	
	# Uncommon unlocks after Map 2
	if current_level_index >= 2:
		allowed_pool.append_array(items_by_rarity["Uncommon"])
		
	# Rare unlocks after Map 5
	if current_level_index >= 5:
		allowed_pool.append_array(items_by_rarity["Rare"])
		
	# Epic unlocks after Map 9
	if current_level_index >= 9:
		allowed_pool.append_array(items_by_rarity["Epic"])
		
	# Legendary unlocks after Map 13
	if current_level_index >= 13:
		allowed_pool.append_array(items_by_rarity["Legendary"])
		
	return allowed_pool
