extends Resource
class_name WeaponData

enum DamageType {
	PHYSICAL = 0,
	MAGIC = 1
}

# IMPORTANT:
# Existing serialized values are preserved explicitly.
# New weapon categories are appended safely to avoid remapping old .tres files.
enum WeaponType {
	SWORD = 0,
	LANCE = 1,
	AXE = 2,
	BOW = 3,
	TOME = 4,
	NONE = 5,

	KNIFE = 6,
	FIREARM = 7,
	FIST = 8,
	INSTRUMENT = 9,
	DARK_TOME = 10
}

@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity: String = "Common"
@export_multiline var description: String = ""

@export var weapon_name: String = "Iron Sword"
@export var gold_cost: int = 250
@export var damage_type: DamageType = DamageType.PHYSICAL
@export var weapon_type: WeaponType = WeaponType.SWORD

@export_category("Visual Effects")
@export var projectile_scene: PackedScene
@export var impact_scene: PackedScene
@export var projectile_scale: float = 2.0
@export var custom_hit_sound: AudioStream
@export var is_instant_cast: bool = false

@export_category("Restrictions")
@export var dragon_only: bool = false
@export var non_tradeable: bool = false
@export var non_convoy: bool = false

@export var is_healing_staff: bool = false
@export var is_buff_staff: bool = false
@export var is_debuff_staff: bool = false

@export var affected_stat: String = "strength"
@export var effect_amount: int = 4

@export var might: int = 5
@export var hit_bonus: int = 0
@export var min_range: int = 1
@export var max_range: int = 1
@export var icon: Texture2D

@export_category("Durability")
@export var max_durability: int = 30
@export var current_durability: int = 30

@export_category("Gladiator Arena Shop")
@export var gladiator_token_cost: int = 0
@export var required_arena_rank: String = "Bronze"


static func get_weapon_type_name(w_type: int) -> String:
	match int(w_type):
		WeaponType.SWORD:
			return "Sword"
		WeaponType.LANCE:
			return "Lance"
		WeaponType.AXE:
			return "Axe"
		WeaponType.BOW:
			return "Bow"
		WeaponType.TOME:
			return "Tome"
		WeaponType.NONE:
			return "None"
		WeaponType.KNIFE:
			return "Knife"
		WeaponType.FIREARM:
			return "Firearm"
		WeaponType.FIST:
			return "Fist"
		WeaponType.INSTRUMENT:
			return "Instrument"
		WeaponType.DARK_TOME:
			return "Dark Tome"
		_:
			return "Unknown"


static func get_weapon_family(w_type: int) -> int:
	# Family is used for broad rule grouping and triangle logic.
	match int(w_type):
		WeaponType.KNIFE:
			return WeaponType.SWORD
		WeaponType.FIST:
			return WeaponType.AXE
		WeaponType.FIREARM:
			return WeaponType.BOW
		WeaponType.DARK_TOME:
			return WeaponType.TOME
		WeaponType.INSTRUMENT:
			return WeaponType.NONE
		_:
			return int(w_type)


static func is_staff_like(weapon: WeaponData) -> bool:
	if weapon == null:
		return false

	return weapon.is_healing_staff or weapon.is_buff_staff or weapon.is_debuff_staff


static func is_dragon_weapon(weapon: WeaponData) -> bool:
	if weapon == null:
		return false

	if weapon.get("dragon_only") == true:
		return true

	var n: String = str(weapon.weapon_name).strip_edges().to_lower()
	return n.contains("dragon")


static func is_trade_locked(weapon: WeaponData) -> bool:
	if weapon == null:
		return false
	return weapon.get("non_tradeable") == true or is_dragon_weapon(weapon)


static func is_convoy_locked(weapon: WeaponData) -> bool:
	if weapon == null:
		return false
	return weapon.get("non_convoy") == true or is_trade_locked(weapon)
