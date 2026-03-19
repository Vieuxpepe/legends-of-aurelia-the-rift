@tool
extends EditorScript

const SkillNodeScript = preload("res://Scripts/Core/SkillNode.gd")
const SkillTreeScript = preload("res://Scripts/Core/SkillTree.gd")

const BASE_SAVE_DIRECTORY: String = "res://Resources/Skills/Generated/Ascended/"

# =============================================================================
# DAWN EXALT
# Holy / radiant / high-end support-warrior capstone
# =============================================================================
var dawnexalt_data: Array = [
	{"id":"de_mag_1", "grid_x":0, "grid_y":0, "req":"", "type":0, "stat":"mag", "boost":3, "ability":"", "name":"Radiant Core", "desc":"Grants +3 Magic."},
	{"id":"de_res_1", "grid_x":1, "grid_y":0, "req":"de_mag_1", "type":0, "stat":"res", "boost":3, "ability":"", "name":"Halo Ward", "desc":"Grants +3 Resistance."},
	{"id":"de_hp_1", "grid_x":2, "grid_y":0, "req":"de_res_1", "type":0, "stat":"hp", "boost":8, "ability":"", "name":"Dawnborn Vitality", "desc":"Grants +8 Max HP."},
	{"id":"de_spd_1", "grid_x":3, "grid_y":0, "req":"de_hp_1", "type":0, "stat":"spd", "boost":2, "ability":"", "name":"Sunstep", "desc":"Grants +2 Speed."},
	{"id":"de_agi_1", "grid_x":4, "grid_y":0, "req":"de_spd_1", "type":0, "stat":"agi", "boost":3, "ability":"", "name":"Aurora Sight", "desc":"Grants +3 Agility."}
]

# =============================================================================
# VOID STRIDER
# Swift hybrid assassin / spellblade / void capstone
# =============================================================================
var voidstrider_data: Array = [
	{"id":"vs_spd_1", "grid_x":0, "grid_y":0, "req":"", "type":0, "stat":"spd", "boost":3, "ability":"", "name":"Abyssal Tempo", "desc":"Grants +3 Speed."},
	{"id":"vs_agi_1", "grid_x":1, "grid_y":0, "req":"vs_spd_1", "type":0, "stat":"agi", "boost":3, "ability":"", "name":"Fracture Sense", "desc":"Grants +3 Agility."},
	{"id":"vs_str_1", "grid_x":2, "grid_y":0, "req":"vs_agi_1", "type":0, "stat":"str", "boost":2, "ability":"", "name":"Void Edge", "desc":"Grants +2 Strength."},
	{"id":"vs_mag_1", "grid_x":3, "grid_y":0, "req":"vs_str_1", "type":0, "stat":"mag", "boost":2, "ability":"", "name":"Umbral Surge", "desc":"Grants +2 Magic."},
	{"id":"vs_hp_1", "grid_x":4, "grid_y":0, "req":"vs_mag_1", "type":0, "stat":"hp", "boost":6, "ability":"", "name":"Rift-Forged Flesh", "desc":"Grants +6 Max HP."}
]

# =============================================================================
# RIFT ARCHON
# Supreme arcane capstone
# =============================================================================
var riftarchon_data: Array = [
	{"id":"ra_mag_1", "grid_x":0, "grid_y":0, "req":"", "type":0, "stat":"mag", "boost":4, "ability":"", "name":"Archonic Mind", "desc":"Grants +4 Magic."},
	{"id":"ra_res_1", "grid_x":1, "grid_y":0, "req":"ra_mag_1", "type":0, "stat":"res", "boost":3, "ability":"", "name":"Dimensional Ward", "desc":"Grants +3 Resistance."},
	{"id":"ra_hp_1", "grid_x":2, "grid_y":0, "req":"ra_res_1", "type":0, "stat":"hp", "boost":6, "ability":"", "name":"Arcane Vessel", "desc":"Grants +6 Max HP."},
	{"id":"ra_spd_1", "grid_x":3, "grid_y":0, "req":"ra_hp_1", "type":0, "stat":"spd", "boost":2, "ability":"", "name":"Warp Reflex", "desc":"Grants +2 Speed."},
	{"id":"ra_agi_1", "grid_x":4, "grid_y":0, "req":"ra_spd_1", "type":0, "stat":"agi", "boost":2, "ability":"", "name":"Cosmic Calculation", "desc":"Grants +2 Agility."}
]

func _run():
	var all_classes: Dictionary = {
		"DawnExalt": dawnexalt_data,
		"VoidStrider": voidstrider_data,
		"RiftArchon": riftarchon_data
	}

	for class_key in all_classes.keys():
		var ascended_name: String = String(class_key)
		var class_dir: String = BASE_SAVE_DIRECTORY + ascended_name + "/"
		_ensure_dir(class_dir)

		var node_array: Array = all_classes[ascended_name]
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
		tree.tree_name = ascended_name + " Tree"

		for saved_path in saved_paths:
			var skill_res = load(saved_path)
			if skill_res != null:
				tree.skills.append(skill_res)

		var tree_path: String = class_dir + ascended_name + "Tree.tres"
		var tree_err: int = ResourceSaver.save(tree, tree_path)
		if tree_err != OK:
			push_error("Failed to save tree: " + tree_path)
		else:
			print("✅ Generated ascended tree for " + ascended_name + " with " + str(saved_paths.size()) + " skills.")

	print("🎉 ALL ASCENDED CLASS SKILLS GENERATED!")

func _ensure_dir(res_dir: String) -> void:
	var abs_dir: String = ProjectSettings.globalize_path(res_dir.trim_suffix("/"))
	DirAccess.make_dir_recursive_absolute(abs_dir)
