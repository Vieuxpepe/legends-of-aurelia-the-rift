@tool
extends EditorScript

const SkillNodeScript = preload("res://Scripts/Core/SkillNode.gd")
const SkillTreeScript = preload("res://Scripts/Core/SkillTree.gd")

const GENERATED_BASE_DIR: String = "res://Resources/Skills/Generated/"
const TREE_SAVE_DIR: String = "res://Resources/Skills/"

# =============================================================================
# FLIER (15-node normal tree)
# =============================================================================
var flier_data: Array = [
	{"id":"flier_hp_1", "grid_x":0, "grid_y":0, "req":"", "type":0, "stat":"hp", "boost":2, "ability":"", "name":"Wingborne Vigor I", "desc":"Increases Max HP by +2."},
	{"id":"flier_str_1", "grid_x":1, "grid_y":-1, "req":"flier_hp_1", "type":0, "stat":"str", "boost":1, "ability":"", "name":"Lance Drill I", "desc":"Increases Strength by +1."},
	{"id":"flier_spd_1", "grid_x":1, "grid_y":0, "req":"flier_hp_1", "type":0, "stat":"spd", "boost":1, "ability":"", "name":"Sky Pace I", "desc":"Increases Speed by +1."},
	{"id":"flier_res_1", "grid_x":1, "grid_y":1, "req":"flier_hp_1", "type":0, "stat":"res", "boost":1, "ability":"", "name":"Wind Ward I", "desc":"Increases Resistance by +1."},

	{"id":"flier_str_2", "grid_x":2, "grid_y":-1, "req":"flier_str_1", "type":0, "stat":"str", "boost":1, "ability":"", "name":"Lance Drill II", "desc":"Increases Strength by +1."},
	{"id":"flier_agi_1", "grid_x":2, "grid_y":0, "req":"flier_spd_1", "type":0, "stat":"agi", "boost":1, "ability":"", "name":"Aerial Sense I", "desc":"Increases Agility by +1."},
	{"id":"flier_res_2", "grid_x":2, "grid_y":1, "req":"flier_res_1", "type":0, "stat":"res", "boost":1, "ability":"", "name":"Wind Ward II", "desc":"Increases Resistance by +1."},

	{"id":"flier_charge", "grid_x":3, "grid_y":-1, "req":"flier_str_2", "type":1, "stat":"", "boost":0, "ability":"Charge", "name":"Sky Charge", "desc":"Unlocks Charge for a fast diving assault."},
	{"id":"flier_spd_2", "grid_x":3, "grid_y":0, "req":"flier_agi_1", "type":0, "stat":"spd", "boost":1, "ability":"", "name":"Sky Pace II", "desc":"Increases Speed by +1."},
	{"id":"flier_hp_2", "grid_x":3, "grid_y":1, "req":"flier_res_2", "type":0, "stat":"hp", "boost":2, "ability":"", "name":"Wingborne Vigor II", "desc":"Increases Max HP by +2."},

	{"id":"flier_str_3", "grid_x":4, "grid_y":-1, "req":"flier_charge", "type":0, "stat":"str", "boost":2, "ability":"", "name":"Lance Drill III", "desc":"Increases Strength by +2."},
	{"id":"flier_agi_2", "grid_x":4, "grid_y":0, "req":"flier_spd_2", "type":0, "stat":"agi", "boost":2, "ability":"", "name":"Aerial Sense II", "desc":"Increases Agility by +2."},
	{"id":"flier_def_1", "grid_x":4, "grid_y":1, "req":"flier_hp_2", "type":0, "stat":"def", "boost":1, "ability":"", "name":"Feather Guard I", "desc":"Increases Defense by +1."},

	{"id":"flier_res_3", "grid_x":5, "grid_y":0, "req":"flier_agi_2", "type":0, "stat":"res", "boost":2, "ability":"", "name":"Wind Ward III", "desc":"Increases Resistance by +2."},
	{"id":"flier_raptors_rush", "grid_x":6, "grid_y":0, "req":"flier_res_3", "type":1, "stat":"", "boost":0, "ability":"Adrenaline Rush", "name":"Raptor's Rush", "desc":"Unlocks Adrenaline Rush, turning momentum into burst aggression."}
]

# =============================================================================
# DANCER (15-node normal tree)
# =============================================================================
var dancer_data: Array = [
	{"id":"dancer_hp_1", "grid_x":0, "grid_y":0, "req":"", "type":0, "stat":"hp", "boost":2, "ability":"", "name":"Graceful Vitality I", "desc":"Increases Max HP by +2."},
	{"id":"dancer_mag_1", "grid_x":1, "grid_y":-1, "req":"dancer_hp_1", "type":0, "stat":"mag", "boost":1, "ability":"", "name":"Stagecraft I", "desc":"Increases Magic by +1."},
	{"id":"dancer_spd_1", "grid_x":1, "grid_y":0, "req":"dancer_hp_1", "type":0, "stat":"spd", "boost":1, "ability":"", "name":"Light Step I", "desc":"Increases Speed by +1."},
	{"id":"dancer_res_1", "grid_x":1, "grid_y":1, "req":"dancer_hp_1", "type":0, "stat":"res", "boost":1, "ability":"", "name":"Poise I", "desc":"Increases Resistance by +1."},

	{"id":"dancer_mag_2", "grid_x":2, "grid_y":-1, "req":"dancer_mag_1", "type":0, "stat":"mag", "boost":1, "ability":"", "name":"Stagecraft II", "desc":"Increases Magic by +1."},
	{"id":"dancer_agi_1", "grid_x":2, "grid_y":0, "req":"dancer_spd_1", "type":0, "stat":"agi", "boost":1, "ability":"", "name":"Showmanship I", "desc":"Increases Agility by +1."},
	{"id":"dancer_res_2", "grid_x":2, "grid_y":1, "req":"dancer_res_1", "type":0, "stat":"res", "boost":1, "ability":"", "name":"Poise II", "desc":"Increases Resistance by +1."},

	{"id":"dancer_battle_cry", "grid_x":3, "grid_y":-1, "req":"dancer_mag_2", "type":1, "stat":"", "boost":0, "ability":"Battle Cry", "name":"Rousing Verse", "desc":"Unlocks Battle Cry through a rallying performance."},
	{"id":"dancer_spd_2", "grid_x":3, "grid_y":0, "req":"dancer_agi_1", "type":0, "stat":"spd", "boost":1, "ability":"", "name":"Light Step II", "desc":"Increases Speed by +1."},
	{"id":"dancer_hp_2", "grid_x":3, "grid_y":1, "req":"dancer_res_2", "type":0, "stat":"hp", "boost":2, "ability":"", "name":"Graceful Vitality II", "desc":"Increases Max HP by +2."},

	{"id":"dancer_mag_3", "grid_x":4, "grid_y":-1, "req":"dancer_battle_cry", "type":0, "stat":"mag", "boost":2, "ability":"", "name":"Stagecraft III", "desc":"Increases Magic by +2."},
	{"id":"dancer_agi_2", "grid_x":4, "grid_y":0, "req":"dancer_spd_2", "type":0, "stat":"agi", "boost":2, "ability":"", "name":"Showmanship II", "desc":"Increases Agility by +2."},
	{"id":"dancer_def_1", "grid_x":4, "grid_y":1, "req":"dancer_hp_2", "type":0, "stat":"def", "boost":1, "ability":"", "name":"Veil Guard I", "desc":"Increases Defense by +1."},

	{"id":"dancer_res_3", "grid_x":5, "grid_y":0, "req":"dancer_agi_2", "type":0, "stat":"res", "boost":2, "ability":"", "name":"Poise III", "desc":"Increases Resistance by +2."},
	{"id":"dancer_encore_of_fate", "grid_x":6, "grid_y":0, "req":"dancer_res_3", "type":1, "stat":"", "boost":0, "ability":"Miracle", "name":"Encore of Fate", "desc":"Unlocks Miracle through impossible timing and presence."}
]

# =============================================================================
# BEASTMASTER (15-node normal tree)
# =============================================================================
var beastmaster_data: Array = [
	{"id":"beastmaster_hp_1", "grid_x":0, "grid_y":0, "req":"", "type":0, "stat":"hp", "boost":2, "ability":"", "name":"Beastbond Vitality I", "desc":"Increases Max HP by +2."},
	{"id":"beastmaster_str_1", "grid_x":1, "grid_y":-1, "req":"beastmaster_hp_1", "type":0, "stat":"str", "boost":1, "ability":"", "name":"Handler's Strength I", "desc":"Increases Strength by +1."},
	{"id":"beastmaster_spd_1", "grid_x":1, "grid_y":0, "req":"beastmaster_hp_1", "type":0, "stat":"spd", "boost":1, "ability":"", "name":"Hunter's Pace I", "desc":"Increases Speed by +1."},
	{"id":"beastmaster_def_1", "grid_x":1, "grid_y":1, "req":"beastmaster_hp_1", "type":0, "stat":"def", "boost":1, "ability":"", "name":"Hidebound I", "desc":"Increases Defense by +1."},

	{"id":"beastmaster_str_2", "grid_x":2, "grid_y":-1, "req":"beastmaster_str_1", "type":0, "stat":"str", "boost":1, "ability":"", "name":"Handler's Strength II", "desc":"Increases Strength by +1."},
	{"id":"beastmaster_agi_1", "grid_x":2, "grid_y":0, "req":"beastmaster_spd_1", "type":0, "stat":"agi", "boost":1, "ability":"", "name":"Pack Sense I", "desc":"Increases Agility by +1."},
	{"id":"beastmaster_hp_2", "grid_x":2, "grid_y":1, "req":"beastmaster_def_1", "type":0, "stat":"hp", "boost":2, "ability":"", "name":"Beastbond Vitality II", "desc":"Increases Max HP by +2."},

	{"id":"beastmaster_alpha_roar", "grid_x":3, "grid_y":-1, "req":"beastmaster_str_2", "type":1, "stat":"", "boost":0, "ability":"Terrifying Roar", "name":"Alpha Roar", "desc":"Unlocks Terrifying Roar to shake enemy formations."},
	{"id":"beastmaster_spd_2", "grid_x":3, "grid_y":0, "req":"beastmaster_agi_1", "type":0, "stat":"spd", "boost":1, "ability":"", "name":"Hunter's Pace II", "desc":"Increases Speed by +1."},
	{"id":"beastmaster_def_2", "grid_x":3, "grid_y":1, "req":"beastmaster_hp_2", "type":0, "stat":"def", "boost":1, "ability":"", "name":"Hidebound II", "desc":"Increases Defense by +1."},

	{"id":"beastmaster_str_3", "grid_x":4, "grid_y":-1, "req":"beastmaster_alpha_roar", "type":0, "stat":"str", "boost":2, "ability":"", "name":"Handler's Strength III", "desc":"Increases Strength by +2."},
	{"id":"beastmaster_agi_2", "grid_x":4, "grid_y":0, "req":"beastmaster_spd_2", "type":0, "stat":"agi", "boost":2, "ability":"", "name":"Pack Sense II", "desc":"Increases Agility by +2."},
	{"id":"beastmaster_res_1", "grid_x":4, "grid_y":1, "req":"beastmaster_def_2", "type":0, "stat":"res", "boost":1, "ability":"", "name":"Wild Instinct I", "desc":"Increases Resistance by +1."},

	{"id":"beastmaster_hp_3", "grid_x":5, "grid_y":0, "req":"beastmaster_res_1", "type":0, "stat":"hp", "boost":2, "ability":"", "name":"Beastbond Vitality III", "desc":"Increases Max HP by +2."},
	{"id":"beastmaster_apex_predator", "grid_x":6, "grid_y":0, "req":"beastmaster_hp_3", "type":1, "stat":"", "boost":0, "ability":"Apex Predator", "name":"Apex Predator", "desc":"Unlocks Apex Predator for a brutal finishing instinct."}
]

# =============================================================================
# CANNONEER (15-node normal tree)
# =============================================================================
var cannoneer_data: Array = [
	{"id":"cannoneer_hp_1", "grid_x":0, "grid_y":0, "req":"", "type":0, "stat":"hp", "boost":2, "ability":"", "name":"Siege Frame I", "desc":"Increases Max HP by +2."},
	{"id":"cannoneer_str_1", "grid_x":1, "grid_y":-1, "req":"cannoneer_hp_1", "type":0, "stat":"str", "boost":1, "ability":"", "name":"Powder Drill I", "desc":"Increases Strength by +1."},
	{"id":"cannoneer_def_1", "grid_x":1, "grid_y":0, "req":"cannoneer_hp_1", "type":0, "stat":"def", "boost":1, "ability":"", "name":"Braced Stance I", "desc":"Increases Defense by +1."},
	{"id":"cannoneer_agi_1", "grid_x":1, "grid_y":1, "req":"cannoneer_hp_1", "type":0, "stat":"agi", "boost":1, "ability":"", "name":"Sighting I", "desc":"Increases Agility by +1."},

	{"id":"cannoneer_str_2", "grid_x":2, "grid_y":-1, "req":"cannoneer_str_1", "type":0, "stat":"str", "boost":1, "ability":"", "name":"Powder Drill II", "desc":"Increases Strength by +1."},
	{"id":"cannoneer_hp_2", "grid_x":2, "grid_y":0, "req":"cannoneer_def_1", "type":0, "stat":"hp", "boost":2, "ability":"", "name":"Siege Frame II", "desc":"Increases Max HP by +2."},
	{"id":"cannoneer_res_1", "grid_x":2, "grid_y":1, "req":"cannoneer_agi_1", "type":0, "stat":"res", "boost":1, "ability":"", "name":"Smoke Tolerance I", "desc":"Increases Resistance by +1."},

	{"id":"cannoneer_deadeye_shot", "grid_x":3, "grid_y":-1, "req":"cannoneer_str_2", "type":1, "stat":"", "boost":0, "ability":"Deadeye Shot", "name":"Deadeye Shot", "desc":"Unlocks Deadeye Shot for a precise ranged punisher."},
	{"id":"cannoneer_def_2", "grid_x":3, "grid_y":0, "req":"cannoneer_hp_2", "type":0, "stat":"def", "boost":1, "ability":"", "name":"Braced Stance II", "desc":"Increases Defense by +1."},
	{"id":"cannoneer_agi_2", "grid_x":3, "grid_y":1, "req":"cannoneer_res_1", "type":0, "stat":"agi", "boost":1, "ability":"", "name":"Sighting II", "desc":"Increases Agility by +1."},

	{"id":"cannoneer_str_3", "grid_x":4, "grid_y":-1, "req":"cannoneer_deadeye_shot", "type":0, "stat":"str", "boost":2, "ability":"", "name":"Powder Drill III", "desc":"Increases Strength by +2."},
	{"id":"cannoneer_hp_3", "grid_x":4, "grid_y":0, "req":"cannoneer_def_2", "type":0, "stat":"hp", "boost":2, "ability":"", "name":"Siege Frame III", "desc":"Increases Max HP by +2."},
	{"id":"cannoneer_res_2", "grid_x":4, "grid_y":1, "req":"cannoneer_agi_2", "type":0, "stat":"res", "boost":1, "ability":"", "name":"Smoke Tolerance II", "desc":"Increases Resistance by +1."},

	{"id":"cannoneer_def_3", "grid_x":5, "grid_y":0, "req":"cannoneer_hp_3", "type":0, "stat":"def", "boost":2, "ability":"", "name":"Braced Stance III", "desc":"Increases Defense by +2."},
	{"id":"cannoneer_ballista_shot", "grid_x":6, "grid_y":0, "req":"cannoneer_def_3", "type":1, "stat":"", "boost":0, "ability":"Ballista Shot", "name":"Ballista Shot", "desc":"Unlocks Ballista Shot for crushing siege impact."}
]

func _run():
	var all_classes: Dictionary = {
		"Flier": flier_data,
		"Dancer": dancer_data,
		"Beastmaster": beastmaster_data,
		"Cannoneer": cannoneer_data
	}

	for class_key in all_classes.keys():
		var normal_name: String = String(class_key)
		var class_dir: String = GENERATED_BASE_DIR + normal_name + "/"
		_ensure_dir(class_dir)

		var node_array: Array = all_classes[normal_name]
		var saved_paths: Array[String] = []

		for raw_data in node_array:
			var data: Dictionary = raw_data
			var skill = SkillNodeScript.new()

			skill.skill_id = String(data["id"])
			skill.skill_name = String(data["name"])
			skill.description = String(data["desc"])
			skill.required_skill_id = String(data["req"])
			skill.grid_position = Vector2(int(data["grid_x"]), int(data["grid_y"]))
			skill.effect_type = int(data["type"])
			skill.stat_to_boost = String(data["stat"])
			skill.boost_amount = int(data["boost"])
			skill.ability_to_unlock = String(data["ability"])

			var skill_path: String = class_dir + "Skill_" + String(data["id"]) + ".tres"
			var save_err: int = ResourceSaver.save(skill, skill_path)
			if save_err != OK:
				push_error("Failed to save skill: " + skill_path)
				continue

			saved_paths.append(skill_path)

		var tree = SkillTreeScript.new()
		tree.tree_name = normal_name + " Tree"

		for saved_path in saved_paths:
			var skill_res = load(saved_path)
			if skill_res != null:
				tree.skills.append(skill_res)

		var tree_path: String = TREE_SAVE_DIR + normal_name + "Tree.tres"
		var tree_err: int = ResourceSaver.save(tree, tree_path)
		if tree_err != OK:
			push_error("Failed to save tree: " + tree_path)
		else:
			print("✅ Generated normal tree for " + normal_name + " with " + str(saved_paths.size()) + " skills.")

	print("🎉 ALL MISSING NORMAL CLASS SKILLS GENERATED!")

func _ensure_dir(res_dir: String) -> void:
	var abs_dir: String = ProjectSettings.globalize_path(res_dir.trim_suffix("/"))
	DirAccess.make_dir_recursive_absolute(abs_dir)
