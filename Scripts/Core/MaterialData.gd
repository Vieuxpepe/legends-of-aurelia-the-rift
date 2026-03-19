extends Resource
class_name MaterialData

@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity: String = "Common"

@export var item_name: String = "Material"
@export var description: String = "A crafting material or quest item."
@export var gold_cost: int = 10 # Sell price
@export var icon: Texture2D

# fields for organization and UI display.
@export var category: String = ""
