@tool
extends EditorScript

const SkillNodeScript = preload("res://Scripts/Core/SkillNode.gd")
const SkillTreeScript = preload("res://Scripts/Core/SkillTree.gd")

const BASE_SAVE_DIRECTORY: String = "res://Resources/Skills/Generated/Promoted/"

# =============================================================================
# FALCON KNIGHT
# =============================================================================
var falconknight_data: Array = [
	{"id":"fk_spd_1", "grid_x":0, "grid_y":0, "req":"", "type":0, "stat":"spd", "boost":2, "ability":"", "name":"Falcon Pace", "desc":"Grants +2 Speed."},
	{"id":"fk_agi_1", "grid_x":1, "grid_y":0, "req":"fk_spd_1", "type":0, "stat":"agi", "boost":2, "ability":"", "name":"Sky Instinct", "desc":"Grants +2 Agility."},
	{"id":"fk_str_1", "grid_x":2, "grid_y":0, "req":"fk_agi_1", "type":0, "stat":"str", "boost":2, "ability":"", "name":"Piercing Dive", "desc":"Grants +2 Strength."},
	{"id":"fk_res_1", "grid_x":3, "grid_y":0, "req":"fk_str_1", "type":0, "stat":"res", "boost":2, "ability":"", "name":"Windblessed Guard", "desc":"Grants +2 Resistance."},
	{"id":"fk_mastery", "grid_x":4, "grid_y":0, "req":"fk_res_1", "type":1, "stat":"", "boost":0, "ability":"Charge", "name":"Mastery: Falcon Dive", "desc":"Launches a devastating aerial charge from above."}
]

# =============================================================================
# SKY VANGUARD
# =============================================================================
var skyvanguard_data: Array = [
	{"id":"sv_hp_1", "grid_x":0, "grid_y":0, "req":"", "type":0, "stat":"hp", "boost":5, "ability":"", "name":"Stormborne Vigor", "desc":"Grants +5 Max HP."},
	{"id":"sv_str_1", "grid_x":1, "grid_y":0, "req":"sv_hp_1", "type":0, "stat":"str", "boost":2, "ability":"", "name":"Skybreaker Spear", "desc":"Grants +2 Strength."},
	{"id":"sv_def_1", "grid_x":2, "grid_y":0, "req":"sv_str_1", "type":0, "stat":"def", "boost":2, "ability":"", "name":"Cloudwall Plate", "desc":"Grants +2 Defense."},
	{"id":"sv_spd_1", "grid_x":3, "grid_y":0, "req":"sv_def_1", "type":0, "stat":"spd", "boost":2, "ability":"", "name":"Tempest Advance", "desc":"Grants +2 Speed."},
	{"id":"sv_mastery", "grid_x":4, "grid_y":0, "req":"sv_spd_1", "type":1, "stat":"", "boost":0, "ability":"Vanguard's Rally", "name":"Mastery: Storm Standard", "desc":"Rallies allies with a thunderous banner call from the sky."}
]

# =============================================================================
# MUSE
# =============================================================================
var muse_data: Array = [
	{"id":"muse_mag_1", "grid_x":0, "grid_y":0, "req":"", "type":0, "stat":"mag", "boost":2, "ability":"", "name":"Golden Voice", "desc":"Grants +2 Magic."},
	{"id":"muse_res_1", "grid_x":1, "grid_y":0, "req":"muse_mag_1", "type":0, "stat":"res", "boost":2, "ability":"", "name":"Stage Grace", "desc":"Grants +2 Resistance."},
	{"id":"muse_spd_1", "grid_x":2, "grid_y":0, "req":"muse_res_1", "type":0, "stat":"spd", "boost":2, "ability":"", "name":"Flowing Rhythm", "desc":"Grants +2 Speed."},
	{"id":"muse_hp_1", "grid_x":3, "grid_y":0, "req":"muse_spd_1", "type":0, "stat":"hp", "boost":5, "ability":"", "name":"Encore Spirit", "desc":"Grants +5 Max HP."},
	{"id":"muse_mastery", "grid_x":4, "grid_y":0, "req":"muse_hp_1", "type":1, "stat":"", "boost":0, "ability":"Celestial Choir", "name":"Mastery: Song of Dawn", "desc":"A transcendent performance that restores allies across the field."}
]

# =============================================================================
# BLADE DANCER
# =============================================================================
var bladedancer_data: Array = [
	{"id":"bd_spd_1", "grid_x":0, "grid_y":0, "req":"", "type":0, "stat":"spd", "boost":2, "ability":"", "name":"Waltzing Step", "desc":"Grants +2 Speed."},
	{"id":"bd_agi_1", "grid_x":1, "grid_y":0, "req":"bd_spd_1", "type":0, "stat":"agi", "boost":2, "ability":"", "name":"Ribbon Feint", "desc":"Grants +2 Agility."},
	{"id":"bd_str_1", "grid_x":2, "grid_y":0, "req":"bd_agi_1", "type":0, "stat":"str", "boost":2, "ability":"", "name":"Duelist's Rhythm", "desc":"Grants +2 Strength."},
	{"id":"bd_hp_1", "grid_x":3, "grid_y":0, "req":"bd_str_1", "type":0, "stat":"hp", "boost":5, "ability":"", "name":"Crimson Flourish", "desc":"Grants +5 Max HP."},
	{"id":"bd_mastery", "grid_x":4, "grid_y":0, "req":"bd_hp_1", "type":1, "stat":"", "boost":0, "ability":"Blade Tempest", "name":"Mastery: Death Waltz", "desc":"Unleashes a spiraling storm of razor-sharp strikes."}
]

# =============================================================================
# WILD WARDEN
# =============================================================================
var wildwarden_data: Array = [
	{"id":"ww_hp_1", "grid_x":0, "grid_y":0, "req":"", "type":0, "stat":"hp", "boost":8, "ability":"", "name":"Ancient Vitality", "desc":"Grants +8 Max HP."},
	{"id":"ww_def_1", "grid_x":1, "grid_y":0, "req":"ww_hp_1", "type":0, "stat":"def", "boost":2, "ability":"", "name":"Barkskin Guard", "desc":"Grants +2 Defense."},
	{"id":"ww_str_1", "grid_x":2, "grid_y":0, "req":"ww_def_1", "type":0, "stat":"str", "boost":2, "ability":"", "name":"Hunter's Wrath", "desc":"Grants +2 Strength."},
	{"id":"ww_res_1", "grid_x":3, "grid_y":0, "req":"ww_str_1", "type":0, "stat":"res", "boost":2, "ability":"", "name":"Forest Ward", "desc":"Grants +2 Resistance."},
	{"id":"ww_mastery", "grid_x":4, "grid_y":0, "req":"ww_res_1", "type":1, "stat":"", "boost":0, "ability":"Unbreakable Bastion", "name":"Mastery: Verdant Bastion", "desc":"Calls the wilds to harden allies into an unyielding wall."}
]

# =============================================================================
# PACK LEADER
# =============================================================================
var packleader_data: Array = [
	{"id":"pl_str_1", "grid_x":0, "grid_y":0, "req":"", "type":0, "stat":"str", "boost":2, "ability":"", "name":"Alpha Fangs", "desc":"Grants +2 Strength."},
	{"id":"pl_spd_1", "grid_x":1, "grid_y":0, "req":"pl_str_1", "type":0, "stat":"spd", "boost":2, "ability":"", "name":"Predator's Pace", "desc":"Grants +2 Speed."},
	{"id":"pl_agi_1", "grid_x":2, "grid_y":0, "req":"pl_spd_1", "type":0, "stat":"agi", "boost":2, "ability":"", "name":"Pack Instinct", "desc":"Grants +2 Agility."},
	{"id":"pl_hp_1", "grid_x":3, "grid_y":0, "req":"pl_agi_1", "type":0, "stat":"hp", "boost":6, "ability":"", "name":"Howling Vigor", "desc":"Grants +6 Max HP."},
	{"id":"pl_mastery", "grid_x":4, "grid_y":0, "req":"pl_hp_1", "type":1, "stat":"", "boost":0, "ability":"Battle Cry", "name":"Mastery: Alpha Howl", "desc":"Lets out a dominant war cry that drives allies into a frenzy."}
]

# =============================================================================
# SIEGE MASTER
# =============================================================================
var siegemaster_data: Array = [
	{"id":"sm_str_1", "grid_x":0, "grid_y":0, "req":"", "type":0, "stat":"str", "boost":3, "ability":"", "name":"Heavy Powder", "desc":"Grants +3 Strength."},
	{"id":"sm_def_1", "grid_x":1, "grid_y":0, "req":"sm_str_1", "type":0, "stat":"def", "boost":2, "ability":"", "name":"Gunshield Brace", "desc":"Grants +2 Defense."},
	{"id":"sm_agi_1", "grid_x":2, "grid_y":0, "req":"sm_def_1", "type":0, "stat":"agi", "boost":2, "ability":"", "name":"Rangefinding", "desc":"Grants +2 Agility."},
	{"id":"sm_hp_1", "grid_x":3, "grid_y":0, "req":"sm_agi_1", "type":0, "stat":"hp", "boost":5, "ability":"", "name":"Iron Carriage", "desc":"Grants +5 Max HP."},
	{"id":"sm_mastery", "grid_x":4, "grid_y":0, "req":"sm_hp_1", "type":1, "stat":"", "boost":0, "ability":"Ballista Shot", "name":"Mastery: Fortress Breaker", "desc":"Fires a crushing siege round capable of shattering entire formations."}
]

# =============================================================================
# DREADNOUGHT
# =============================================================================
var dreadnought_data: Array = [
	{"id":"dn_hp_1", "grid_x":0, "grid_y":0, "req":"", "type":0, "stat":"hp", "boost":8, "ability":"", "name":"Juggernaut Hull", "desc":"Grants +8 Max HP."},
	{"id":"dn_def_1", "grid_x":1, "grid_y":0, "req":"dn_hp_1", "type":0, "stat":"def", "boost":3, "ability":"", "name":"Adamant Plating", "desc":"Grants +3 Defense."},
	{"id":"dn_str_1", "grid_x":2, "grid_y":0, "req":"dn_def_1", "type":0, "stat":"str", "boost":2, "ability":"", "name":"Overloaded Chamber", "desc":"Grants +2 Strength."},
	{"id":"dn_res_1", "grid_x":3, "grid_y":0, "req":"dn_str_1", "type":0, "stat":"res", "boost":2, "ability":"", "name":"Smokeproof Core", "desc":"Grants +2 Resistance."},
	{"id":"dn_mastery", "grid_x":4, "grid_y":0, "req":"dn_res_1", "type":1, "stat":"", "boost":0, "ability":"Earthshatter", "name":"Mastery: Cataclysm Shell", "desc":"Detonates the battlefield with a catastrophic impact shot."}
]

func _run():
	var all_classes: Dictionary = {
		"FalconKnight": falconknight_data,
		"SkyVanguard": skyvanguard_data,
		"Muse": muse_data,
		"BladeDancer": bladedancer_data,
		"WildWarden": wildwarden_data,
		"PackLeader": packleader_data,
		"SiegeMaster": siegemaster_data,
		"Dreadnought": dreadnought_data
	}

	for class_key in all_classes.keys():
		var promoted_name: String = String(class_key)
		var class_dir: String = BASE_SAVE_DIRECTORY + promoted_name + "/"
		_ensure_dir(class_dir)

		var node_array: Array = all_classes[promoted_name]
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
		tree.tree_name = promoted_name + " Tree"

		for saved_path in saved_paths:
			var skill_res = load(saved_path)
			if skill_res != null:
				tree.skills.append(skill_res)

		var tree_path: String = class_dir + promoted_name + "Tree.tres"
		var tree_err: int = ResourceSaver.save(tree, tree_path)
		if tree_err != OK:
			push_error("Failed to save tree: " + tree_path)
		else:
			print("✅ Generated promoted tree for " + promoted_name + " with " + str(saved_paths.size()) + " skills.")

	print("🎉 ALL MISSING PROMOTED CLASS SKILLS GENERATED!")

func _ensure_dir(res_dir: String) -> void:
	var abs_dir: String = ProjectSettings.globalize_path(res_dir.trim_suffix("/"))
	DirAccess.make_dir_recursive_absolute(abs_dir)
