extends Resource
class_name ChestKeyData

@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity: String = "Common"

@export var item_name: String = "Chest Key"
@export var gold_cost: int = 100 # Added for shop
@export var icon: Texture2D
