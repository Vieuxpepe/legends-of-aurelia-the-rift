extends Resource
class_name SkillTree

@export var tree_name: String = "Mercenary Skill Tree"
# You will drag your SkillNode resources into this array in the Inspector!
@export var skills: Array[SkillNode] = []
