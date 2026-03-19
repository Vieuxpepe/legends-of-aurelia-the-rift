@tool
extends EditorScript

const ClassDataScript = preload("res://Resources/Classes/ClassData.gd")

const CLASS_DIR: String = "res://Resources/Classes/"
const TREE_DIR: String = "res://Resources/Skills/"

const INFANTRY: int = 0
const ARMORED: int = 1
const FLYING: int = 2
const CAVALRY: int = 3

const PROMOTION_MAP := {
	"Flier": [
		"res://Resources/Classes/PromotedClass/FalconKnight.tres",
		"res://Resources/Classes/PromotedClass/SkyVanguard.tres"
	],
	"Dancer": [
		"res://Resources/Classes/PromotedClass/Muse.tres",
		"res://Resources/Classes/PromotedClass/BladeDancer.tres"
	],
	"Beastmaster": [
		"res://Resources/Classes/PromotedClass/WildWarden.tres",
		"res://Resources/Classes/PromotedClass/PackLeader.tres"
	],
	"Cannoneer": [
		"res://Resources/Classes/PromotedClass/SiegeMaster.tres",
		"res://Resources/Classes/PromotedClass/Dreadnought.tres"
	]
}

const CLASS_CONFIG := {
	"Flier": {
		"move_range": 7,
		"move_type": FLYING,
		"hp_bonus": 10, "str_bonus": 2, "def_bonus": 0, "spd_bonus": 3, "agi_bonus": 2, "mag_bonus": 0, "res_bonus": 3,
		"hp_growth_bonus": 5, "str_growth_bonus": 5, "def_growth_bonus": 0, "spd_growth_bonus": 15, "agi_growth_bonus": 10, "mag_growth_bonus": 0, "res_growth_bonus": 10
	},
	"Dancer": {
		"move_range": 5,
		"move_type": INFANTRY,
		"hp_bonus": 6, "str_bonus": -2, "def_bonus": -1, "spd_bonus": 4, "agi_bonus": 3, "mag_bonus": 1, "res_bonus": 2,
		"hp_growth_bonus": 0, "str_growth_bonus": -10, "def_growth_bonus": -5, "spd_growth_bonus": 20, "agi_growth_bonus": 15, "mag_growth_bonus": 5, "res_growth_bonus": 10
	},
	"Beastmaster": {
		"move_range": 6,
		"move_type": INFANTRY,
		"hp_bonus": 12, "str_bonus": 3, "def_bonus": 1, "spd_bonus": 2, "agi_bonus": 2, "mag_bonus": 0, "res_bonus": 0,
		"hp_growth_bonus": 10, "str_growth_bonus": 10, "def_growth_bonus": 5, "spd_growth_bonus": 10, "agi_growth_bonus": 10, "mag_growth_bonus": 0, "res_growth_bonus": 0
	},
	"Cannoneer": {
		"move_range": 4,
		"move_type": ARMORED,
		"hp_bonus": 12, "str_bonus": 4, "def_bonus": 3, "spd_bonus": -2, "agi_bonus": -2, "mag_bonus": 0, "res_bonus": -1,
		"hp_growth_bonus": 15, "str_growth_bonus": 15, "def_growth_bonus": 10, "spd_growth_bonus": -10, "agi_growth_bonus": -10, "mag_growth_bonus": 0, "res_growth_bonus": 0
	}
}

func _run():
	_ensure_dir(CLASS_DIR)

	for class_key in CLASS_CONFIG.keys():
		var normal_name: String = String(class_key)
		var cfg: Dictionary = CLASS_CONFIG[normal_name]
		var tree_path: String = TREE_DIR + normal_name + "Tree.tres"

		if not ResourceLoader.exists(tree_path):
			push_warning("Missing normal skill tree for " + normal_name + ": " + tree_path)
			continue

		var class_res = ClassDataScript.new()
		class_res.job_name = normal_name
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

		var promotions: Array[Resource] = _build_promotions_for_class(normal_name)
		class_res.promotion_options = promotions

		var save_path: String = CLASS_DIR + normal_name + ".tres"
		var err: int = ResourceSaver.save(class_res, save_path)
		if err != OK:
			push_error("Failed to save class: " + save_path)
		else:
			print("✅ Created normal class: " + normal_name)

	print("🎉 ALL MISSING NORMAL CLASS RESOURCES GENERATED!")

func _build_promotions_for_class(normal_name: String) -> Array[Resource]:
	var out: Array[Resource] = []

	if not PROMOTION_MAP.has(normal_name):
		return out

	var raw_paths: Array = PROMOTION_MAP[normal_name]

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
