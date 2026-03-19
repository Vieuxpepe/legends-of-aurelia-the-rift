@tool
extends EditorScript

const SkillNodeScript = preload("res://Scripts/Core/SkillNode.gd")
const SkillTreeScript = preload("res://Scripts/Core/SkillTree.gd")

const BASE_SAVE_DIRECTORY := "res://Resources/Skills/Generated/Rookie/"

var recruit_data = [
	{"id": "recruit_hp_1", "grid_x": 0, "grid_y": 0, "req": "", "type": 0, "stat": "hp", "boost": 4, "ability": "", "name": "Fresh Resolve", "desc": "Grants +4 Max HP."},
	{"id": "recruit_def_1", "grid_x": 1, "grid_y": 0, "req": "recruit_hp_1", "type": 0, "stat": "def", "boost": 1, "ability": "", "name": "Training Guard", "desc": "Grants +1 Defense."},
	{"id": "recruit_str_1", "grid_x": 2, "grid_y": 0, "req": "recruit_def_1", "type": 0, "stat": "str", "boost": 1, "ability": "", "name": "First Drill", "desc": "Grants +1 Strength."},
	{"id": "recruit_spd_1", "grid_x": 3, "grid_y": 0, "req": "recruit_str_1", "type": 0, "stat": "spd", "boost": 1, "ability": "", "name": "Forced March", "desc": "Grants +1 Speed."},
	{"id": "recruit_mastery", "grid_x": 4, "grid_y": 0, "req": "recruit_spd_1", "type": 1, "stat": "", "boost": 0, "ability": "Shield Clash", "name": "Graduate: Shield Clash", "desc": "Unlocks Shield Clash, a defensive technique learned through basic military training."}
]

var apprentice_data = [
	{"id": "apprentice_mag_1", "grid_x": 0, "grid_y": 0, "req": "", "type": 0, "stat": "mag", "boost": 2, "ability": "", "name": "Spell Primer", "desc": "Grants +2 Magic."},
	{"id": "apprentice_res_1", "grid_x": 1, "grid_y": 0, "req": "apprentice_mag_1", "type": 0, "stat": "res", "boost": 1, "ability": "", "name": "Warding Chalk", "desc": "Grants +1 Resistance."},
	{"id": "apprentice_spd_1", "grid_x": 2, "grid_y": 0, "req": "apprentice_res_1", "type": 0, "stat": "spd", "boost": 1, "ability": "", "name": "Quick Casting", "desc": "Grants +1 Speed."},
	{"id": "apprentice_hp_1", "grid_x": 3, "grid_y": 0, "req": "apprentice_spd_1", "type": 0, "stat": "hp", "boost": 3, "ability": "", "name": "Study Endurance", "desc": "Grants +3 Max HP."},
	{"id": "apprentice_mastery", "grid_x": 4, "grid_y": 0, "req": "apprentice_hp_1", "type": 1, "stat": "", "boost": 0, "ability": "Arcane Shift", "name": "Graduate: Arcane Shift", "desc": "Unlocks Arcane Shift, a basic repositioning spell for fledgling mages and adepts."}
]

var urchin_data = [
	{"id": "urchin_spd_1", "grid_x": 0, "grid_y": 0, "req": "", "type": 0, "stat": "spd", "boost": 2, "ability": "", "name": "Street Feet", "desc": "Grants +2 Speed."},
	{"id": "urchin_agi_1", "grid_x": 1, "grid_y": 0, "req": "urchin_spd_1", "type": 0, "stat": "agi", "boost": 2, "ability": "", "name": "Light Fingers", "desc": "Grants +2 Agility."},
	{"id": "urchin_str_1", "grid_x": 2, "grid_y": 0, "req": "urchin_agi_1", "type": 0, "stat": "str", "boost": 1, "ability": "", "name": "Cheap Shot", "desc": "Grants +1 Strength."},
	{"id": "urchin_hp_1", "grid_x": 3, "grid_y": 0, "req": "urchin_str_1", "type": 0, "stat": "hp", "boost": 3, "ability": "", "name": "Gutter Toughness", "desc": "Grants +3 Max HP."},
	{"id": "urchin_mastery", "grid_x": 4, "grid_y": 0, "req": "urchin_hp_1", "type": 1, "stat": "", "boost": 0, "ability": "Adrenaline Rush", "name": "Graduate: Adrenaline Rush", "desc": "Unlocks Adrenaline Rush, fueled by desperate survival instincts."}
]

var novice_data = [
	{"id": "novice_res_1", "grid_x": 0, "grid_y": 0, "req": "", "type": 0, "stat": "res", "boost": 2, "ability": "", "name": "Quiet Prayer", "desc": "Grants +2 Resistance."},
	{"id": "novice_spd_1", "grid_x": 1, "grid_y": 0, "req": "novice_res_1", "type": 0, "stat": "spd", "boost": 1, "ability": "", "name": "Measured Step", "desc": "Grants +1 Speed."},
	{"id": "novice_str_1", "grid_x": 2, "grid_y": 0, "req": "novice_spd_1", "type": 0, "stat": "str", "boost": 1, "ability": "", "name": "Disciplined Form", "desc": "Grants +1 Strength."},
	{"id": "novice_hp_1", "grid_x": 3, "grid_y": 0, "req": "novice_str_1", "type": 0, "stat": "hp", "boost": 4, "ability": "", "name": "Steadfast Spirit", "desc": "Grants +4 Max HP."},
	{"id": "novice_mastery", "grid_x": 4, "grid_y": 0, "req": "novice_hp_1", "type": 1, "stat": "", "boost": 0, "ability": "Miracle", "name": "Graduate: Miracle", "desc": "Unlocks Miracle, a desperate spark of faith and survival."}
]

var villager_data = [
	{"id": "villager_hp_1", "grid_x": 0, "grid_y": 0, "req": "", "type": 0, "stat": "hp", "boost": 4, "ability": "", "name": "Farmhand's Stamina", "desc": "Grants +4 Max HP."},
	{"id": "villager_str_1", "grid_x": 1, "grid_y": 0, "req": "villager_hp_1", "type": 0, "stat": "str", "boost": 1, "ability": "", "name": "Work-Hardened", "desc": "Grants +1 Strength."},
	{"id": "villager_def_1", "grid_x": 2, "grid_y": 0, "req": "villager_str_1", "type": 0, "stat": "def", "boost": 1, "ability": "", "name": "Weathered Hide", "desc": "Grants +1 Defense."},
	{"id": "villager_agi_1", "grid_x": 3, "grid_y": 0, "req": "villager_def_1", "type": 0, "stat": "agi", "boost": 1, "ability": "", "name": "Field Sense", "desc": "Grants +1 Agility."},
	{"id": "villager_mastery", "grid_x": 4, "grid_y": 0, "req": "villager_agi_1", "type": 1, "stat": "", "boost": 0, "ability": "Battle Cry", "name": "Graduate: Battle Cry", "desc": "Unlocks Battle Cry, a rough but inspiring shout born from hard living."}
]

func _run():
	var all_rookies = {
		"Recruit": recruit_data,
		"Apprentice": apprentice_data,
		"Urchin": urchin_data,
		"Novice": novice_data,
		"Villager": villager_data
	}

	for rookie_key in all_rookies.keys():
		var rookie_name: String = String(rookie_key)
		var class_dir: String = BASE_SAVE_DIRECTORY + rookie_name + "/"
		_ensure_dir(class_dir)

		var current_array: Array = all_rookies[rookie_name]
		var saved_skill_paths: Array[String] = []

		for data_variant in current_array:
			var data: Dictionary = data_variant
			var skill = SkillNodeScript.new()

			skill.skill_id = String(data["id"])
			skill.skill_name = String(data["name"])
			skill.description = String(data["desc"])
			skill.required_skill_id = String(data["req"])
			skill.grid_position = Vector2(data["grid_x"], data["grid_y"])
			skill.effect_type = int(data["type"])
			skill.stat_to_boost = String(data["stat"])
			skill.boost_amount = int(data["boost"])
			skill.ability_to_unlock = String(data["ability"])

			var skill_path: String = class_dir + "Skill_" + String(data["id"]) + ".tres"
			var save_err: int = ResourceSaver.save(skill, skill_path)
			if save_err != OK:
				push_error("Failed to save skill: " + skill_path)
				continue

			saved_skill_paths.append(skill_path)

		var tree = SkillTreeScript.new()
		tree.tree_name = rookie_name + " Rookie Tree"

		for saved_path in saved_skill_paths:
			var skill_res = load(saved_path)
			if skill_res != null:
				tree.skills.append(skill_res)

		var tree_path: String = class_dir + rookie_name + "Tree.tres"
		var tree_err: int = ResourceSaver.save(tree, tree_path)
		if tree_err != OK:
			push_error("Failed to save tree: " + tree_path)
		else:
			print("✅ Generated rookie tree for " + rookie_name + " with " + str(saved_skill_paths.size()) + " skills.")

	print("🎉 ALL ROOKIE SKILLS GENERATED SUCCESSFULLY!")

func _ensure_dir(res_dir: String) -> void:
	var abs_dir := ProjectSettings.globalize_path(res_dir.trim_suffix("/"))
	DirAccess.make_dir_recursive_absolute(abs_dir)
