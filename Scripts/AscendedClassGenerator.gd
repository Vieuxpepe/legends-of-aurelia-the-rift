@tool
extends EditorScript

const ClassDataScript = preload("res://Resources/Classes/ClassData.gd")

const CLASS_DIR: String = "res://Resources/Classes/AscendedClass/"
const TREE_DIR: String = "res://Resources/Skills/Generated/Ascended/"

const INFANTRY: int = 0
const ARMORED: int = 1
const FLYING: int = 2
const CAVALRY: int = 3

const CLASS_CONFIG := {
	"DawnExalt": {
		"job_name": "Dawn Exalt",
		"move_range": 6,
		"move_type": INFANTRY,

		"promo_hp_bonus": 3,
		"promo_str_bonus": 1,
		"promo_mag_bonus": 3,
		"promo_def_bonus": 1,
		"promo_res_bonus": 3,
		"promo_spd_bonus": 1,
		"promo_agi_bonus": 2,

		"hp_bonus": 4,
		"str_bonus": 1,
		"def_bonus": 1,
		"spd_bonus": 1,
		"agi_bonus": 2,
		"mag_bonus": 4,
		"res_bonus": 4,

		"hp_growth_bonus": 5,
		"str_growth_bonus": 0,
		"def_growth_bonus": 0,
		"spd_growth_bonus": 5,
		"agi_growth_bonus": 5,
		"mag_growth_bonus": 10,
		"res_growth_bonus": 10
	},

	"VoidStrider": {
		"job_name": "Void Strider",
		"move_range": 7,
		"move_type": INFANTRY,

		"promo_hp_bonus": 2,
		"promo_str_bonus": 2,
		"promo_mag_bonus": 2,
		"promo_def_bonus": 0,
		"promo_res_bonus": 1,
		"promo_spd_bonus": 3,
		"promo_agi_bonus": 3,

		"hp_bonus": 2,
		"str_bonus": 2,
		"def_bonus": 0,
		"spd_bonus": 4,
		"agi_bonus": 4,
		"mag_bonus": 2,
		"res_bonus": 1,

		"hp_growth_bonus": 0,
		"str_growth_bonus": 5,
		"def_growth_bonus": 0,
		"spd_growth_bonus": 10,
		"agi_growth_bonus": 10,
		"mag_growth_bonus": 5,
		"res_growth_bonus": 0
	},

	"RiftArchon": {
		"job_name": "Rift Archon",
		"move_range": 6,
		"move_type": INFANTRY,

		"promo_hp_bonus": 2,
		"promo_str_bonus": 0,
		"promo_mag_bonus": 4,
		"promo_def_bonus": 0,
		"promo_res_bonus": 3,
		"promo_spd_bonus": 1,
		"promo_agi_bonus": 2,

		"hp_bonus": 2,
		"str_bonus": 0,
		"def_bonus": 0,
		"spd_bonus": 1,
		"agi_bonus": 2,
		"mag_bonus": 5,
		"res_bonus": 4,

		"hp_growth_bonus": 0,
		"str_growth_bonus": 0,
		"def_growth_bonus": 0,
		"spd_growth_bonus": 5,
		"agi_growth_bonus": 5,
		"mag_growth_bonus": 15,
		"res_growth_bonus": 10
	}
}

func _run():
	_ensure_dir(CLASS_DIR)

	for class_key in CLASS_CONFIG.keys():
		var ascended_name: String = String(class_key)
		var cfg: Dictionary = CLASS_CONFIG[ascended_name]
		var tree_path: String = TREE_DIR + ascended_name + "/" + ascended_name + "Tree.tres"

		if not ResourceLoader.exists(tree_path):
			push_warning("Missing ascended skill tree for " + ascended_name + ": " + tree_path)
			continue

		var class_res = ClassDataScript.new()
		class_res.job_name = String(cfg["job_name"])
		class_res.move_range = int(cfg["move_range"])
		class_res.move_type = int(cfg["move_type"])
		class_res.class_skill_tree = load(tree_path)

		var no_promotions: Array[Resource] = []
		class_res.promotion_options = no_promotions

		class_res.promo_hp_bonus = int(cfg["promo_hp_bonus"])
		class_res.promo_str_bonus = int(cfg["promo_str_bonus"])
		class_res.promo_mag_bonus = int(cfg["promo_mag_bonus"])
		class_res.promo_def_bonus = int(cfg["promo_def_bonus"])
		class_res.promo_res_bonus = int(cfg["promo_res_bonus"])
		class_res.promo_spd_bonus = int(cfg["promo_spd_bonus"])
		class_res.promo_agi_bonus = int(cfg["promo_agi_bonus"])

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

		var save_path: String = CLASS_DIR + ascended_name + ".tres"
		var err: int = ResourceSaver.save(class_res, save_path)
		if err != OK:
			push_error("Failed to save ascended class: " + save_path)
		else:
			print("✅ Created ascended class: " + ascended_name)

	print("🎉 ALL ASCENDED CLASS RESOURCES GENERATED!")

func _ensure_dir(res_dir: String) -> void:
	var abs_dir: String = ProjectSettings.globalize_path(res_dir.trim_suffix("/"))
	DirAccess.make_dir_recursive_absolute(abs_dir)
