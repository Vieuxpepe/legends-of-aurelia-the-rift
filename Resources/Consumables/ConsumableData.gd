# ==============================================================================
# SCRIPT PURPOSE: Defines the data structure for consumable items (potions, boosters).
# OVERALL GOAL: Acts as a reusable Godot Resource for inventory and shop systems.
# DEPENDENCIES: Utilized by CityMenu.gd (Shop) and Unit.gd (Inventory).
# GUIDANCE FOR AI/REVIEWERS:
#   - Entry Points: Resource loading.
#   - Core Logic: Pure data container.
#   - Extension Points: Add new boost types or custom use effects here.
# ==============================================================================
extends Resource
class_name ConsumableData

@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity: String = "Common"
@export_multiline var description: String = ""

@export var item_name: String = "Health Potion"
@export var heal_amount: int = 0
@export var icon: Texture2D
@export var is_promotion_item: bool = false

@export_group("Shop Settings")
@export var gold_cost: int = 50 
@export var gladiator_token_cost: int = 10 # Added for the Arena Token Shop
@export_enum("Bronze", "Silver", "Gold", "Platinum", "Diamond", "Grandmaster") var required_arena_rank: String = "Bronze"

@export_group("Permanent Boosts")
@export var str_boost: int = 0
@export var mag_boost: int = 0
@export var def_boost: int = 0
@export var res_boost: int = 0
@export var spd_boost: int = 0
@export var agi_boost: int = 0
@export var hp_boost: int = 0

@export_category("Jukebox Unlock")
@export var unlocked_music_track: AudioStream
@export var track_title: String = ""
