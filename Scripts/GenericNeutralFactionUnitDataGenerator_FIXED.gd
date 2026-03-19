@tool
extends EditorScript

const UNIT_DATA_SCRIPT := preload("res://Scripts/Core/UnitData.gd")

const OUTPUT_ROOT := "res://Resources/Units/NeutralFactionAllies/"

const CLASS_PATHS := {
	"Archer": "res://Resources/Classes/Archer.tres",
	"Cleric": "res://Resources/Classes/Cleric.tres",
	"Knight": "res://Resources/Classes/Knight.tres",
	"Mercenary": "res://Resources/Classes/Mercenary.tres",
	"Monk": "res://Resources/Classes/Monk.tres",
	"Paladin": "res://Resources/Classes/Paladin.tres",
	"Thief": "res://Resources/Classes/Thief.tres",
	"Cannoneer": "res://Resources/Classes/Cannoneer.tres",
	"BowKnight": "res://Resources/Classes/PromotedClass/BowKnight.tres",
	"GreatKnight": "res://Resources/Classes/PromotedClass/GreatKnight.tres",
	"HighPaladin": "res://Resources/Classes/PromotedClass/HighPaladin.tres"
}

const WEAPON_PATHS := {
	"Ash Shortbow": "res://Resources/GeneratedItems/Weapon_Ash_Shortbow.tres",
	"Beginners Staff": "res://Resources/GeneratedItems/Weapon_Beginners_Staff.tres",
	"Bronze Pike": "res://Resources/GeneratedItems/Weapon_Bronze_Pike.tres",
	"Crude Bow": "res://Resources/GeneratedItems/Weapon_Crude_Bow.tres",
	"Heal Staff": "res://Resources/GeneratedItems/Weapon_Heal_Staff.tres",
	"Holy Lance": "res://Resources/GeneratedItems/Weapon_Holy_Lance.tres",
	"Hunters Bow": "res://Resources/GeneratedItems/Weapon_Hunters_Bow.tres",
	"Longbow": "res://Resources/GeneratedItems/Weapon_Longbow.tres",
	"Militia Handgonne": "res://Resources/GeneratedItems/Weapon_Militia_Handgonne.tres",
	"Old Spear": "res://Resources/GeneratedItems/Weapon_Old_Spear.tres",
	"Protect Staff": "res://Resources/GeneratedItems/Weapon_Protect_Staff.tres",
	"Reinforced Bow": "res://Resources/GeneratedItems/Weapon_Reinforced_Bow.tres",
	"Scrap Knife": "res://Resources/GeneratedItems/Weapon_Scrap_Knife.tres",
	"Silver Lance": "res://Resources/GeneratedItems/Weapon_Silver_Lance.tres",
	"Street Dirk": "res://Resources/GeneratedItems/Weapon_Street_Dirk.tres",
	"Temple Gauntlets": "res://Resources/GeneratedItems/Weapon_Temple_Gauntlets.tres",
	"Travelers Blade": "res://Resources/GeneratedItems/Weapon_Travelers_Blade.tres",
	"Wooden Pike": "res://Resources/GeneratedItems/Weapon_Wooden_Pike.tres"
}

const FACTIONS := {
	"Edranor": [
		{
			"save_name": "Neutral_Edranor_EscortGuard_T1",
			"display_name": "Edranor Escort Guard",
			"class_key": "Knight",
			"weapon_name": "Bronze Pike",
			"visual_scale": 1.0,
			"stats": {"hp": 26, "str": 8, "mag": 0, "def": 9, "res": 3, "spd": 5, "agi": 6},
			"maps": [7, 17]
		},
		{
			"save_name": "Neutral_Edranor_RoadArcher_T1",
			"display_name": "Edranor Road Archer",
			"class_key": "Archer",
			"weapon_name": "Ash Shortbow",
			"visual_scale": 1.0,
			"stats": {"hp": 22, "str": 8, "mag": 0, "def": 4, "res": 4, "spd": 7, "agi": 8},
			"maps": [7, 8, 17]
		},
		{
			"save_name": "Neutral_Edranor_Rider_T1",
			"display_name": "Edranor Rider",
			"class_key": "Paladin",
			"weapon_name": "Old Spear",
			"visual_scale": 1.0,
			"stats": {"hp": 27, "str": 9, "mag": 0, "def": 8, "res": 4, "spd": 7, "agi": 7},
			"maps": [7, 17, 20]
		},
		{
			"save_name": "Neutral_Edranor_BannerCleric_T1",
			"display_name": "Edranor Banner Cleric",
			"class_key": "Cleric",
			"weapon_name": "Protect Staff",
			"visual_scale": 1.0,
			"stats": {"hp": 21, "str": 0, "mag": 8, "def": 3, "res": 8, "spd": 6, "agi": 7},
			"maps": [7, 17, 20]
		},
		{
			"save_name": "Neutral_Edranor_RoyalGuard_T2",
			"display_name": "Edranor Royal Guard",
			"class_key": "GreatKnight",
			"weapon_name": "Silver Lance",
			"visual_scale": 1.0,
			"stats": {"hp": 35, "str": 13, "mag": 0, "def": 13, "res": 6, "spd": 8, "agi": 9},
			"maps": [17, 20]
		}
	],
	"RoadWardens": [
		{
			"save_name": "Neutral_Warden_SpearGuard_T1",
			"display_name": "Road-Warden Spear Guard",
			"class_key": "Knight",
			"weapon_name": "Wooden Pike",
			"visual_scale": 1.0,
			"stats": {"hp": 24, "str": 7, "mag": 0, "def": 8, "res": 4, "spd": 6, "agi": 7},
			"maps": [8, 9]
		},
		{
			"save_name": "Neutral_Warden_Bowman_T1",
			"display_name": "Road-Warden Bowman",
			"class_key": "Archer",
			"weapon_name": "Hunters Bow",
			"visual_scale": 1.0,
			"stats": {"hp": 22, "str": 8, "mag": 0, "def": 4, "res": 4, "spd": 8, "agi": 8},
			"maps": [8, 9]
		},
		{
			"save_name": "Neutral_Warden_Scout_T1",
			"display_name": "Road-Warden Scout",
			"class_key": "Thief",
			"weapon_name": "Scrap Knife",
			"visual_scale": 1.0,
			"stats": {"hp": 20, "str": 6, "mag": 0, "def": 3, "res": 4, "spd": 10, "agi": 9},
			"maps": [4, 8, 9]
		},
		{
			"save_name": "Neutral_Warden_PassCaptain_T2",
			"display_name": "Road-Warden Pass Captain",
			"class_key": "BowKnight",
			"weapon_name": "Longbow",
			"visual_scale": 1.0,
			"stats": {"hp": 31, "str": 11, "mag": 0, "def": 8, "res": 6, "spd": 10, "agi": 10},
			"maps": [9, 17]
		}
	],
	"ValeronModerates": [
		{
			"save_name": "Neutral_Valeron_ShieldBearer_T1",
			"display_name": "Valeron Shield-Bearer",
			"class_key": "Knight",
			"weapon_name": "Old Spear",
			"visual_scale": 1.0,
			"stats": {"hp": 25, "str": 8, "mag": 0, "def": 9, "res": 5, "spd": 5, "agi": 6},
			"maps": [9, 17]
		},
		{
			"save_name": "Neutral_Valeron_SanctuaryCleric_T1",
			"display_name": "Valeron Sanctuary Cleric",
			"class_key": "Cleric",
			"weapon_name": "Heal Staff",
			"visual_scale": 1.0,
			"stats": {"hp": 21, "str": 0, "mag": 8, "def": 3, "res": 9, "spd": 6, "agi": 7},
			"maps": [9, 17]
		},
		{
			"save_name": "Neutral_Valeron_WarMonk_T1",
			"display_name": "Valeron War Monk",
			"class_key": "Monk",
			"weapon_name": "Temple Gauntlets",
			"visual_scale": 1.0,
			"stats": {"hp": 24, "str": 7, "mag": 4, "def": 6, "res": 7, "spd": 7, "agi": 7},
			"maps": [9, 10, 17]
		},
		{
			"save_name": "Neutral_Valeron_SunArcher_T1",
			"display_name": "Valeron Sun Archer",
			"class_key": "Archer",
			"weapon_name": "Reinforced Bow",
			"visual_scale": 1.0,
			"stats": {"hp": 22, "str": 8, "mag": 0, "def": 4, "res": 5, "spd": 7, "agi": 8},
			"maps": [9, 17]
		},
		{
			"save_name": "Neutral_Valeron_ReformTemplar_T2",
			"display_name": "Valeron Reform Templar",
			"class_key": "HighPaladin",
			"weapon_name": "Holy Lance",
			"visual_scale": 1.0,
			"stats": {"hp": 34, "str": 12, "mag": 4, "def": 11, "res": 9, "spd": 8, "agi": 9},
			"maps": [17, 20]
		}
	],
	"LeagueReformists": [
		{
			"save_name": "Neutral_League_Guard_T1",
			"display_name": "League Guard",
			"class_key": "Mercenary",
			"weapon_name": "Travelers Blade",
			"visual_scale": 1.0,
			"stats": {"hp": 24, "str": 8, "mag": 0, "def": 6, "res": 4, "spd": 7, "agi": 7},
			"maps": [11, 17]
		},
		{
			"save_name": "Neutral_League_WatchArcher_T1",
			"display_name": "League Watch Archer",
			"class_key": "Archer",
			"weapon_name": "Longbow",
			"visual_scale": 1.0,
			"stats": {"hp": 22, "str": 8, "mag": 0, "def": 4, "res": 4, "spd": 7, "agi": 8},
			"maps": [11, 17]
		},
		{
			"save_name": "Neutral_League_Scout_T1",
			"display_name": "League Scout",
			"class_key": "Thief",
			"weapon_name": "Street Dirk",
			"visual_scale": 1.0,
			"stats": {"hp": 20, "str": 6, "mag": 0, "def": 3, "res": 4, "spd": 10, "agi": 9},
			"maps": [11, 17]
		},
		{
			"save_name": "Neutral_League_WatchGunner_T1",
			"display_name": "League Watch Gunner",
			"class_key": "Cannoneer",
			"weapon_name": "Militia Handgonne",
			"visual_scale": 1.0,
			"stats": {"hp": 23, "str": 9, "mag": 0, "def": 5, "res": 4, "spd": 5, "agi": 6},
			"maps": [11, 17]
		},
		{
			"save_name": "Neutral_League_BridgeSentry_T2",
			"display_name": "League Bridge Sentry",
			"class_key": "Knight",
			"weapon_name": "Bronze Pike",
			"visual_scale": 1.0,
			"stats": {"hp": 31, "str": 11, "mag": 0, "def": 10, "res": 5, "spd": 6, "agi": 7},
			"maps": [11, 17]
		}
	]
}

func _run() -> void:
	_ensure_dir(OUTPUT_ROOT)

	var created := 0
	var updated := 0
	var failures := 0

	for faction in FACTIONS.keys():
		var faction_dir := OUTPUT_ROOT.path_join(faction)
		_ensure_dir(faction_dir)

		for cfg in FACTIONS[faction]:
			var save_path := faction_dir.path_join(String(cfg["save_name"]) + ".tres")
			var existed := ResourceLoader.exists(save_path)
			var data := _build_unit_data(cfg)

			if data == null:
				push_error("Failed to build generic neutral ally: %s" % String(cfg.get("display_name", "UNKNOWN")))
				failures += 1
				continue

			var err := ResourceSaver.save(data, save_path)
			if err != OK:
				push_error("Failed to save resource: %s (err=%s)" % [save_path, str(err)])
				failures += 1
			else:
				if existed:
					updated += 1
					print("♻️ Updated generic neutral ally: %s" % save_path)
				else:
					created += 1
					print("✅ Created generic neutral ally: %s" % save_path)

	print("\n===== GENERIC NEUTRAL FACTION UNITDATA GENERATION COMPLETE =====")
	print("Created: %d | Updated: %d | Failed: %d" % [created, updated, failures])
	_print_map_summary()

func _build_unit_data(cfg: Dictionary) -> Resource:
	var data = UNIT_DATA_SCRIPT.new()
	data.display_name = String(cfg.get("display_name", "Neutral Ally"))
	data.is_recruitable = false
	data.recruit_dialogue = _empty_string_array()
	data.pre_battle_quote = _empty_string_array()
	data.death_quotes = _empty_string_array()
	data.level_up_quotes = _empty_string_array()

	data.character_class = _load_class_resource(String(cfg.get("class_key", "")))
	data.starting_weapon = _load_weapon_resource(String(cfg.get("weapon_name", "")))
	data.death_sound = null
	data.ability = ""
	data.supports = _empty_support_array()

	data.unit_sprite = null
	data.portrait = null
	data.visual_scale = float(cfg.get("visual_scale", 1.0))

	var stats: Dictionary = cfg.get("stats", {})
	data.max_hp = int(stats.get("hp", 20))
	data.strength = int(stats.get("str", 5))
	data.magic = int(stats.get("mag", 0))
	data.defense = int(stats.get("def", 4))
	data.resistance = int(stats.get("res", 3))
	data.speed = int(stats.get("spd", 5))
	data.agility = int(stats.get("agi", 5))

	data.hp_growth = 0
	data.str_growth = 0
	data.mag_growth = 0
	data.def_growth = 0
	data.res_growth = 0
	data.spd_growth = 0
	data.agi_growth = 0

	data.min_gold_drop = 0
	data.max_gold_drop = 0
	data.drops_equipped_weapon = false
	data.equipped_weapon_chance = 100
	data.extra_loot = _empty_loot_array()
	return data

func _empty_string_array() -> Array[String]:
	var out: Array[String] = []
	return out

func _empty_support_array() -> Array[SupportData]:
	var out: Array[SupportData] = []
	return out

func _empty_loot_array() -> Array[LootDrop]:
	var out: Array[LootDrop] = []
	return out

func _load_class_resource(class_key: String) -> Resource:
	var path := String(CLASS_PATHS.get(class_key, ""))
	var res := _try_load(path)
	if res == null:
		push_error("Missing class resource for key '%s' -> %s" % [class_key, path])
	return res

func _load_weapon_resource(weapon_name: String) -> Resource:
	var path := String(WEAPON_PATHS.get(weapon_name, ""))
	var res := _try_load(path)
	if res == null:
		push_error("Missing weapon resource for '%s' -> %s" % [weapon_name, path])
	return res

func _try_load(path: String) -> Resource:
	if path == "":
		return null
	if not ResourceLoader.exists(path):
		return null
	return load(path)

func _ensure_dir(res_dir: String) -> void:
	var abs_dir := ProjectSettings.globalize_path(res_dir.trim_suffix("/"))
	DirAccess.make_dir_recursive_absolute(abs_dir)

func _print_map_summary() -> void:
	print("\nSuggested map usage:")
	print("- Level 7 / 17: Edranor escort forces")
	print("- Level 8 / 9A: Road-warden route defenders")
	print("- Level 9A / 17: Valeron moderate escorts")
	print("- Level 11 / 17: League reformist security")
	print("- Level 20: Selected late coalition remnants")
