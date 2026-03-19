extends Resource
class_name SkillNode

@export var skill_id: String = "skill_hp_1"
@export var skill_name: String = "Vitality I"
@export_multiline var description: String = "Grants +5 Max HP."
@export var icon: Texture2D

# To make it a tree, this node requires ANOTHER node to be unlocked first!
# Leave this blank ("") if it is a starting root node.
@export var required_skill_id: String = "" 

# This determines where it sits visually on the tree map (e.g., X:0, Y:0 is the start)
@export var grid_position: Vector2 = Vector2.ZERO

@export_category("Effect Details")
enum SkillType { STAT_BOOST, ABILITY_UNLOCK }
@export var effect_type: SkillType = SkillType.STAT_BOOST

# If STAT_BOOST:
@export_enum("hp", "str", "mag", "def", "res", "spd", "agi") var stat_to_boost: String = "hp"
@export var boost_amount: int = 5

# If ABILITY_UNLOCK:
# (Type the exact name from your BattleField script, e.g., "Shove")
@export var ability_to_unlock: String = ""
