@tool
extends EditorScript

const ClassDataScript = preload("res://Resources/Classes/ClassData.gd")

const ROOKIE_CLASS_DIR := "res://Resources/Classes/RookieClass/"
const ROOKIE_SKILL_DIR := "res://Resources/Skills/Generated/Rookie/"
const INFANTRY := 0

const PROMOTION_MAP := {
	"Recruit": [
		"res://Resources/Classes/Knight.tres",
		"res://Resources/Classes/Mercenary.tres",
		"res://Resources/Classes/Warrior.tres"
	],
	"Apprentice": [
		"res://Resources/Classes/Mage.tres",
		"res://Resources/Classes/Cleric.tres",
		"res://Resources/Classes/Spellblade.tres"
	],
	"Urchin": [
		"res://Resources/Classes/Thief.tres",
		"res://Resources/Classes/Archer.tres",
		"res://Resources/Classes/Dancer.tres"
	],
	"Novice": [
		"res://Resources/Classes/Monk.tres",
		"res://Resources/Classes/Paladin.tres",
		"res://Resources/Classes/Flier.tres"
	],
	"Villager": [
		"res://Resources/Classes/Beastmaster.tres",
		"res://Resources/Classes/Cannoneer.tres",
		"res://Resources/Classes/Monster.tres"
	]
}

const CLASS_CONFIG := {
	"Recruit": {
		"move_range": 4,
		"move_type": INFANTRY,
		"hp_bonus": 2, "str_bonus": 1, "def_bonus": 1, "spd_bonus": 0, "agi_bonus": 0, "mag_bonus": 0, "res_bonus": 0,
		"hp_growth_bonus": 5, "str_growth_bonus": 5, "def_growth_bonus": 5, "spd_growth_bonus": 0, "agi_growth_bonus": 0, "mag_growth_bonus": 0, "res_growth_bonus": 0
	},
	"Apprentice": {
		"move_range": 4,
		"move_type": INFANTRY,
		"hp_bonus": 0, "str_bonus": 0, "def_bonus": 0, "spd_bonus": 1, "agi_bonus": 0, "mag_bonus": 2, "res_bonus": 1,
		"hp_growth_bonus": 0, "str_growth_bonus": 0, "def_growth_bonus": 0, "spd_growth_bonus": 5, "agi_growth_bonus": 0, "mag_growth_bonus": 10, "res_growth_bonus": 5
	},
	"Urchin": {
		"move_range": 5,
		"move_type": INFANTRY,
		"hp_bonus": 0, "str_bonus": 0, "def_bonus": 0, "spd_bonus": 1, "agi_bonus": 2, "mag_bonus": 0, "res_bonus": 0,
		"hp_growth_bonus": 0, "str_growth_bonus": 0, "def_growth_bonus": 0, "spd_growth_bonus": 10, "agi_growth_bonus": 10, "mag_growth_bonus": 0, "res_growth_bonus": 0
	},
	"Novice": {
		"move_range": 4,
		"move_type": INFANTRY,
		"hp_bonus": 1, "str_bonus": 1, "def_bonus": 0, "spd_bonus": 1, "agi_bonus": 0, "mag_bonus": 0, "res_bonus": 1,
		"hp_growth_bonus": 5, "str_growth_bonus": 5, "def_growth_bonus": 0, "spd_growth_bonus": 5, "agi_growth_bonus": 0, "mag_growth_bonus": 0, "res_growth_bonus": 5
	},
	"Villager": {
		"move_range": 4,
		"move_type": INFANTRY,
		"hp_bonus": 2, "str_bonus": 1, "def_bonus": 1, "spd_bonus": 0, "agi_bonus": 1, "mag_bonus": 0, "res_bonus": 0,
		"hp_growth_bonus": 5, "str_growth_bonus": 5, "def_growth_bonus": 5, "spd_growth_bonus": 0, "agi_growth_bonus": 5, "mag_growth_bonus": 0, "res_growth_bonus": 0
	}
}

func _run():
	_ensure_dir(ROOKIE_CLASS_DIR)

	for rookie_key in CLASS_CONFIG.keys():
		var rookie_name: String = String(rookie_key)
		var cfg: Dictionary = CLASS_CONFIG[rookie_name]
		var tree_path: String = ROOKIE_SKILL_DIR + rookie_name + "/" + rookie_name + "Tree.tres"

		if not ResourceLoader.exists(tree_path):
			push_warning("Missing rookie skill tree for " + rookie_name + ": " + tree_path)
			continue

		var class_res = ClassDataScript.new()
		class_res.job_name = rookie_name
		class_res.move_range = int(cfg["move_range"])
		class_res.move_type = int(cfg["move_type"])
		class_res.class_skill_tree = load(tree_path)

		class_res.hp_bonus = int(cfg["hp_bonus"])
		class_res.str_bonus = int(cfg["str_bonus"])
		class_res.def_bonus = int(cfg["def_bonus"])
		class_res.spd_bonus = int(cfg["spd_bonus"])
		class_res.agi_bonus = int(cfg["agi_bonus"])
		class_res.mag_bonus = int(cfg["mag_bonus"])
		class_res.res_bonus = int(cfg["res_bonus"])

		class_res.hp_growth_bonus = int(cfg["hp_growth_bonus"])
		class_res.str_growth_bonus = int(cfg["str_growth_bonus"])
		class_res.def_growth_bonus = int(cfg["def_growth_bonus"])
		class_res.spd_growth_bonus = int(cfg["spd_growth_bonus"])
		class_res.agi_growth_bonus = int(cfg["agi_growth_bonus"])
		class_res.mag_growth_bonus = int(cfg["mag_growth_bonus"])
		class_res.res_growth_bonus = int(cfg["res_growth_bonus"])

		var promotions: Array[Resource] = _build_promotions_for_rookie(rookie_name)
		class_res.promotion_options = promotions

		var save_path: String = ROOKIE_CLASS_DIR + rookie_name + ".tres"
		var err: int = ResourceSaver.save(class_res, save_path)
		if err != OK:
			push_error("Failed to save rookie class: " + save_path)
		else:
			print("✅ Created rookie class: " + rookie_name)

	print("🎉 ALL ROOKIE CLASS RESOURCES GENERATED!")

func _build_promotions_for_rookie(rookie_name: String) -> Array[Resource]:
	var out: Array[Resource] = []

	if not PROMOTION_MAP.has(rookie_name):
		return out

	var raw_paths: Array = PROMOTION_MAP[rookie_name]

	for raw_path in raw_paths:
		var path: String = String(raw_path)

		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res != null:
				out.append(res)
		else:
			push_warning("Promotion target missing, skipped: " + path)

	return out

func _ensure_dir(res_dir: String) -> void:
	var abs_dir: String = ProjectSettings.globalize_path(res_dir.trim_suffix("/"))
	DirAccess.make_dir_recursive_absolute(abs_dir)
