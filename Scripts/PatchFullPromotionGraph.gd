@tool
extends EditorScript

const ROOKIE_DIR: String = "res://Resources/Classes/RookieClass/"
const NORMAL_DIR: String = "res://Resources/Classes/"
const PROMOTED_DIR: String = "res://Resources/Classes/PromotedClass/"
const ASCENDED_DIR: String = "res://Resources/Classes/AscendedClass/"

const ASCENDED_TARGETS: Array = [
	"res://Resources/Classes/AscendedClass/DawnExalt.tres",
	"res://Resources/Classes/AscendedClass/VoidStrider.tres",
	"res://Resources/Classes/AscendedClass/RiftArchon.tres"
]

# ---------------------------------------------------------------------------
# Explicit graph patches for Rookie + Normal classes
# ---------------------------------------------------------------------------
const PROMOTION_GRAPH := {
	# =========================
	# ROOKIE CLASSES
	# =========================
	"res://Resources/Classes/RookieClass/Recruit.tres": [
		"res://Resources/Classes/Knight.tres",
		"res://Resources/Classes/Mercenary.tres",
		"res://Resources/Classes/Warrior.tres"
	],
	"res://Resources/Classes/RookieClass/Apprentice.tres": [
		"res://Resources/Classes/Mage.tres",
		"res://Resources/Classes/Cleric.tres",
		"res://Resources/Classes/Spellblade.tres"
	],
	"res://Resources/Classes/RookieClass/Urchin.tres": [
		"res://Resources/Classes/Thief.tres",
		"res://Resources/Classes/Archer.tres",
		"res://Resources/Classes/Dancer.tres"
	],
	"res://Resources/Classes/RookieClass/Novice.tres": [
		"res://Resources/Classes/Monk.tres",
		"res://Resources/Classes/Paladin.tres",
		"res://Resources/Classes/Flier.tres"
	],
	"res://Resources/Classes/RookieClass/Villager.tres": [
		"res://Resources/Classes/Beastmaster.tres",
		"res://Resources/Classes/Cannoneer.tres",
		"res://Resources/Classes/Monster.tres"
	],

	# =========================
	# NORMAL CLASSES
	# =========================
	"res://Resources/Classes/Archer.tres": [
		"res://Resources/Classes/PromotedClass/BowKnight.tres",
		"res://Resources/Classes/PromotedClass/HeavyArcher.tres",
		"res://Resources/Classes/PromotedClass/Assassin.tres"
	],
	"res://Resources/Classes/Cleric.tres": [
		"res://Resources/Classes/PromotedClass/HighPaladin.tres",
		"res://Resources/Classes/PromotedClass/DivineSage.tres"
	],
	"res://Resources/Classes/Knight.tres": [
		"res://Resources/Classes/PromotedClass/GreatKnight.tres",
		"res://Resources/Classes/PromotedClass/General.tres",
		"res://Resources/Classes/PromotedClass/Hero.tres"
	],
	"res://Resources/Classes/Mage.tres": [
		"res://Resources/Classes/PromotedClass/FireSage.tres",
		"res://Resources/Classes/PromotedClass/DivineSage.tres",
		"res://Resources/Classes/PromotedClass/BladeWeaver.tres"
	],
	"res://Resources/Classes/Mercenary.tres": [
		"res://Resources/Classes/PromotedClass/Hero.tres",
		"res://Resources/Classes/PromotedClass/BladeMaster.tres",
		"res://Resources/Classes/PromotedClass/Assassin.tres"
	],
	"res://Resources/Classes/Monk.tres": [
		"res://Resources/Classes/PromotedClass/BladeWeaver.tres",
		"res://Resources/Classes/PromotedClass/Berserker.tres",
		"res://Resources/Classes/PromotedClass/FireSage.tres"
	],
	"res://Resources/Classes/Monster.tres": [
	],
	"res://Resources/Classes/Paladin.tres": [
		"res://Resources/Classes/PromotedClass/HighPaladin.tres",
		"res://Resources/Classes/PromotedClass/GreatKnight.tres",
		"res://Resources/Classes/PromotedClass/DeathKnight.tres"
	],
	"res://Resources/Classes/Spellblade.tres": [
		"res://Resources/Classes/PromotedClass/BladeWeaver.tres",
		"res://Resources/Classes/PromotedClass/DeathKnight.tres"
	],
	"res://Resources/Classes/Thief.tres": [
		"res://Resources/Classes/PromotedClass/HeavyArcher.tres",
		"res://Resources/Classes/PromotedClass/Assassin.tres"
	],
	"res://Resources/Classes/Warrior.tres": [
		"res://Resources/Classes/PromotedClass/BladeMaster.tres",
		"res://Resources/Classes/PromotedClass/Berserker.tres",
		"res://Resources/Classes/PromotedClass/Hero.tres"
	],
	"res://Resources/Classes/Flier.tres": [
		"res://Resources/Classes/PromotedClass/FalconKnight.tres",
		"res://Resources/Classes/PromotedClass/SkyVanguard.tres"
	],
	"res://Resources/Classes/Dancer.tres": [
		"res://Resources/Classes/PromotedClass/Muse.tres",
		"res://Resources/Classes/PromotedClass/BladeDancer.tres"
	],
	"res://Resources/Classes/Beastmaster.tres": [
		"res://Resources/Classes/PromotedClass/WildWarden.tres",
		"res://Resources/Classes/PromotedClass/PackLeader.tres"
	],
	"res://Resources/Classes/Cannoneer.tres": [
		"res://Resources/Classes/PromotedClass/SiegeMaster.tres",
		"res://Resources/Classes/PromotedClass/Dreadnought.tres"
	]
}

# ---------------------------------------------------------------------------
# Optional cleanup for the two job_name bugs we already caught
# ---------------------------------------------------------------------------
const JOB_NAME_FIXES := {
	"res://Resources/Classes/PromotedClass/DivineSage.tres": "Divine Sage",
	"res://Resources/Classes/PromotedClass/FireSage.tres": "Fire Sage"
}

func _run():
	var patched_count: int = 0

	# 1) Patch Rookie + Normal classes explicitly
	for class_path_key in PROMOTION_GRAPH.keys():
		var class_path: String = String(class_path_key)
		var raw_targets: Array = PROMOTION_GRAPH[class_path_key]
		if _patch_class_promotions(class_path, raw_targets):
			patched_count += 1

	# 2) Patch every promoted class so it can ascend into any of the 3 ascended classes
	patched_count += _patch_all_promoted_to_ascended()

	# 3) Ensure ascended classes have no further promotions
	patched_count += _clear_all_ascended_promotions()

	# 4) Fix known job_name bugs
	patched_count += _apply_job_name_fixes()

	print("🎉 Promotion graph patch complete! Total patched resources: " + str(patched_count))


func _patch_class_promotions(class_path: String, raw_target_paths: Array) -> bool:
	if not ResourceLoader.exists(class_path):
		push_warning("Class file missing, skipped: " + class_path)
		return false

	var class_res = load(class_path)
	if class_res == null:
		push_warning("Failed to load class resource: " + class_path)
		return false

	var promotions: Array[Resource] = _load_resource_array(raw_target_paths)
	class_res.promotion_options = promotions

	var err: int = ResourceSaver.save(class_res, class_path)
	if err != OK:
		push_error("Failed to save patched class: " + class_path)
		return false

	print("✅ Patched promotions for: " + class_path + " (" + str(promotions.size()) + " targets)")
	return true


func _patch_all_promoted_to_ascended() -> int:
	var count: int = 0
	var dir: DirAccess = DirAccess.open(PROMOTED_DIR)

	if dir == null:
		push_error("Could not open promoted class directory: " + PROMOTED_DIR)
		return 0

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path: String = PROMOTED_DIR + file_name
			if _patch_class_promotions(full_path, ASCENDED_TARGETS):
				count += 1

		file_name = dir.get_next()

	dir.list_dir_end()
	return count


func _clear_all_ascended_promotions() -> int:
	var count: int = 0
	var dir: DirAccess = DirAccess.open(ASCENDED_DIR)

	if dir == null:
		push_error("Could not open ascended class directory: " + ASCENDED_DIR)
		return 0

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path: String = ASCENDED_DIR + file_name

			if not ResourceLoader.exists(full_path):
				file_name = dir.get_next()
				continue

			var class_res = load(full_path)
			if class_res == null:
				file_name = dir.get_next()
				continue

			var no_promotions: Array[Resource] = []
			class_res.promotion_options = no_promotions

			var err: int = ResourceSaver.save(class_res, full_path)
			if err == OK:
				print("✅ Cleared ascended promotions for: " + full_path)
				count += 1
			else:
				push_error("Failed to save ascended class: " + full_path)

		file_name = dir.get_next()

	dir.list_dir_end()
	return count


func _apply_job_name_fixes() -> int:
	var count: int = 0

	for class_path_key in JOB_NAME_FIXES.keys():
		var class_path: String = String(class_path_key)
		var fixed_name: String = String(JOB_NAME_FIXES[class_path_key])

		if not ResourceLoader.exists(class_path):
			push_warning("Job name fix target missing: " + class_path)
			continue

		var class_res = load(class_path)
		if class_res == null:
			push_warning("Could not load class for job_name fix: " + class_path)
			continue

		class_res.job_name = fixed_name

		var err: int = ResourceSaver.save(class_res, class_path)
		if err == OK:
			print("✅ Fixed job_name for: " + class_path + " -> " + fixed_name)
			count += 1
		else:
			push_error("Failed to save job_name fix for: " + class_path)

	return count


func _load_resource_array(raw_paths: Array) -> Array[Resource]:
	var out: Array[Resource] = []

	for raw_path in raw_paths:
		var path: String = String(raw_path)

		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res != null:
				out.append(res)
		else:
			push_warning("Promotion target missing, skipped: " + path)

	return out
