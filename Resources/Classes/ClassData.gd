extends Resource
class_name ClassData

enum MoveType { INFANTRY, ARMORED, FLYING, CAVALRY }

@export var job_name: String = "Class"
@export var move_range: int = 4
@export var move_type: MoveType = MoveType.INFANTRY

@export_category("Weapon Permissions")
@export var allowed_weapon_types: Array[int] = []
@export var can_use_healing_staff: bool = false
@export var can_use_buff_staff: bool = false
@export var can_use_debuff_staff: bool = false

@export_category("Progression")
# Links the class to a specific skill tree!
@export var class_skill_tree: SkillTree

@export_category("Promotion Data")
# Replaces 'promotes_to' with an Array so you can have multiple branching paths!
@export var promotion_options: Array[Resource] = []

@export_category("Visuals")
# The sprite the unit will use on the battlefield after promoting
@export var promoted_battle_sprite: Texture2D

# The portrait used in menus and dialogue after promoting
@export var promoted_portrait: Texture2D

# The flat stat boosts the unit gets the moment they promote INTO this class
@export var promo_hp_bonus: int = 2
@export var promo_str_bonus: int = 1
@export var promo_mag_bonus: int = 0
@export var promo_def_bonus: int = 1
@export var promo_res_bonus: int = 1
@export var promo_spd_bonus: int = 1
@export var promo_agi_bonus: int = 1

@export_category("Class Base Bonuses")
@export var hp_bonus: int = 0
@export var str_bonus: int = 0
@export var def_bonus: int = 0
@export var spd_bonus: int = 0
@export var agi_bonus: int = 0
@export var mag_bonus: int = 0
@export var res_bonus: int = 0

@export_category("Class Growth Bonuses (%)")
@export var hp_growth_bonus: int = 0
@export var str_growth_bonus: int = 0
@export var def_growth_bonus: int = 0
@export var spd_growth_bonus: int = 0
@export var agi_growth_bonus: int = 0
@export var mag_growth_bonus: int = 0
@export var res_growth_bonus: int = 0
