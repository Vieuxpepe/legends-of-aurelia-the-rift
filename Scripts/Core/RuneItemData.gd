extends Resource
class_name RuneItemData

## Matches [WeaponRuneAppliedEffectsResolver] / camp socket ids (e.g. ember_rune, swift_rune).
@export var rune_id: String = "ember_rune"

@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity: String = "Uncommon"
@export var item_name: String = "Rune Stone"
@export var description: String = "A carved rune stone. Socket it onto a rune-capable weapon at the camp blacksmith."
@export var gold_cost: int = 40
@export var icon: Texture2D
@export var category: String = "Runes"
