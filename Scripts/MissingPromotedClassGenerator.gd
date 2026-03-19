@tool
extends EditorScript

const ClassDataScript = preload("res://Resources/Classes/ClassData.gd")

const CLASS_DIR: String = "res://Resources/Classes/PromotedClass/"
const TREE_DIR: String = "res://Resources/Skills/Generated/Promoted/"

const INFANTRY: int = 0
const ARMORED: int = 1
const FLYING: int = 2
const CAVALRY: int = 3

const CLASS_CONFIG := {
	"FalconKnight": {
		"job_name": "Falcon Knight",
		"move_range": 8,
		"move_type": FLYING,
		"promo_hp_bonus": 1,
		"promo_str_bonus": 1,
		"promo_mag_bonus": 0,
		"promo_def_bonus": 0,
		"promo_res_bonus": 2,
		"promo_spd_bonus": 2,
		"promo_agi_bonus": 2
	},
	"SkyVanguard": {
		"job_name": "Sky Vanguard",
		"move_range": 8,
		"move_type": FLYING,
		"promo_hp_bonus": 2,
		"promo_str_bonus": 2,
		"promo_mag_bonus": 0,
		"promo_def_bonus": 2,
		"promo_res_bonus": 0,
		"promo_spd_bonus": 1,
		"promo_agi_bonus": 1
	},
	"Muse": {
		"job_name": "Muse",
		"move_range": 6,
		"move_type": INFANTRY,
		"promo_hp_bonus": 1,
		"promo_str_bonus": 0,
		"promo_mag_bonus": 2,
		"promo_def_bonus": 0,
		"promo_res_bonus": 2,
		"promo_spd_bonus": 1,
		"promo_agi_bonus": 1
	},
	"BladeDancer": {
		"job_name": "Blade Dancer",
		"move_range": 6,
		"move_type": INFANTRY,
		"promo_hp_bonus": 1,
		"promo_str_bonus": 2,
		"promo_mag_bonus": 0,
		"promo_def_bonus": 0,
		"promo_res_bonus": 0,
		"promo_spd_bonus": 2,
		"promo_agi_bonus": 2
	},
	"WildWarden": {
		"job_name": "Wild Warden",
		"move_range": 6,
		"move_type": INFANTRY,
		"promo_hp_bonus": 3,
		"promo_str_bonus": 2,
		"promo_mag_bonus": 0,
		"promo_def_bonus": 2,
		"promo_res_bonus": 1,
		"promo_spd_bonus": 0,
		"promo_agi_bonus": 0
	},
	"PackLeader": {
		"job_name": "Pack Leader",
		"move_range": 7,
		"move_type": INFANTRY,
		"promo_hp_bonus": 2,
		"promo_str_bonus": 2,
		"promo_mag_bonus": 0,
		"promo_def_bonus": 0,
		"promo_res_bonus": 0,
		"promo_spd_bonus": 1,
		"promo_agi_bonus": 2
	},
	"SiegeMaster": {
		"job_name": "Siege Master",
		"move_range": 4,
		"move_type": ARMORED,
		"promo_hp_bonus": 2,
		"promo_str_bonus": 2,
		"promo_mag_bonus": 0,
		"promo_def_bonus": 2,
		"promo_res_bonus": 0,
		"promo_spd_bonus": 0,
		"promo_agi_bonus": 1
	},
	"Dreadnought": {
		"job_name": "Dreadnought",
		"move_range": 4,
		"move_type": ARMORED,
		"promo_hp_bonus": 4,
		"promo_str_bonus": 2,
		"promo_mag_bonus": 0,
		"promo_def_bonus": 3,
		"promo_res_bonus": 1,
		"promo_spd_bonus": 0,
		"promo_agi_bonus": 0
	}
}

func _run():
	_ensure_dir(CLASS_DIR)

	for class_key in CLASS_CONFIG.keys():
		var promoted_name: String = String(class_key)
		var cfg: Dictionary = CLASS_CONFIG[promoted_name]
		var tree_path: String = TREE_DIR + promoted_name + "/" + promoted_name + "Tree.tres"

		if not ResourceLoader.exists(tree_path):
			push_warning("Missing promoted skill tree for " + promoted_name + ": " + tree_path)
			continue

		var class_res = ClassDataScript.new()
		class_res.job_name = String(cfg["job_name"])
		class_res.move_range = int(cfg["move_range"])
		class_res.move_type = int(cfg["move_type"])
		class_res.class_skill_tree = load(tree_path)

		class_res.promo_hp_bonus = int(cfg["promo_hp_bonus"])
		class_res.promo_str_bonus = int(cfg["promo_str_bonus"])
		class_res.promo_mag_bonus = int(cfg["promo_mag_bonus"])
		class_res.promo_def_bonus = int(cfg["promo_def_bonus"])
		class_res.promo_res_bonus = int(cfg["promo_res_bonus"])
		class_res.promo_spd_bonus = int(cfg["promo_spd_bonus"])
		class_res.promo_agi_bonus = int(cfg["promo_agi_bonus"])

		var save_path: String = CLASS_DIR + promoted_name + ".tres"
		var err: int = ResourceSaver.save(class_res, save_path)
		if err != OK:
			push_error("Failed to save promoted class: " + save_path)
		else:
			print("✅ Created promoted class: " + promoted_name)

	print("🎉 ALL MISSING PROMOTED CLASS RESOURCES GENERATED!")

func _ensure_dir(res_dir: String) -> void:
	var abs_dir: String = ProjectSettings.globalize_path(res_dir.trim_suffix("/"))
	DirAccess.make_dir_recursive_absolute(abs_dir)
