@tool
extends EditorScript

# Neutral / allied battlefield-capable UnitData generator for Legends of Aurelia.
# Haldor is intentionally excluded because he is a camp crafter / hub NPC, not a field unit.
# This generator focuses on named allies who can plausibly appear as green units,
# temporary controllable allies, or conditional reinforcements.

const OUTPUT_DIR := "res://Resources/Units/NeutralAllies/"
const UNIT_DATA_SCRIPT := preload("res://Scripts/Core/UnitData.gd")

const CLASS_PATHS := {
	"Paladin": "res://Resources/Classes/Paladin.tres",
	"BowKnight": "res://Resources/Classes/PromotedClass/BowKnight.tres",
	"GreatKnight": "res://Resources/Classes/PromotedClass/GreatKnight.tres",
	"DivineSage": "res://Resources/Classes/PromotedClass/DivineSage.tres",
	"Spellblade": "res://Resources/Classes/Spellblade.tres",
	"Hero": "res://Resources/Classes/PromotedClass/Hero.tres"
}

const WEAPON_PATHS := {
	"Old Spear": "res://Resources/GeneratedItems/Weapon_Old_Spear.tres",
	"Hunter's Bow": "res://Resources/GeneratedItems/Weapon_Hunters_Bow.tres",
	"Holy Lance": "res://Resources/GeneratedItems/Weapon_Holy_Lance.tres",
	"Elysian Staff": "res://Resources/GeneratedItems/Weapon_Elysian_Staff.tres",
	"Traveler's Blade": "res://Resources/GeneratedItems/Weapon_Travelers_Blade.tres",
	"Censure Staff": "res://Resources/GeneratedItems/Weapon_Censure_Staff.tres",
	"Silver Sword": "res://Resources/GeneratedItems/Weapon_Silver_Sword.tres"
}

const DEATH_QUOTES := {
	"Captain Mirelle Dorn": [
		"If you mean to survive this war, earn the help of the living before they’re gone."
	],
	"Warden Thane Ors": [
		"Then guard the road, damn you… or all this dying meant nothing."
	],
	"Queen Seraphine Valedorn": [
		"Do not kneel to my death — feed my land, and let that be your loyalty."
	],
	"Sister Aveline Marr": [
		"I kept the dark from your door as long as I could; bar it yourselves now."
	],
	"Varo Kestrel": [
		"Heh… looks like I finally signed the one contract I couldn’t walk away from."
	]
}

# NOTE:
# - No abilities for now, per current production direction.
# - No portraits/sprites are assigned here.
# - These are not permanent roster units by default: is_recruitable = false.
# - Growths are set to 0 because these are fixed encounter / allied deployment packages.
const ALLIES := [
	{
		"save_name": "Neutral_CaptainMirelleDorn",
		"display_name": "Captain Mirelle Dorn",
		"class_key": "Paladin",
		"weapon_name": "Old Spear",
		"encounter_level": 11,
		"maps": [7, 17],
		"ally_behavior": "green_defender",
		"notes": "Edranor local captain for grain routes, roads, and civilian corridors.",
		"stats": {"hp": 38, "str": 14, "mag": 1, "def": 11, "res": 7, "spd": 10, "agi": 12}
	},
	{
		"save_name": "Neutral_WardenThaneOrs",
		"display_name": "Warden Thane Ors",
		"class_key": "BowKnight",
		"weapon_name": "Hunter's Bow",
		"encounter_level": 12,
		"maps": [8, 9],
		"ally_behavior": "route_ally",
		"notes": "Road-warden captain who opens safer routes and protects passes.",
		"stats": {"hp": 34, "str": 13, "mag": 0, "def": 8, "res": 6, "spd": 14, "agi": 15}
	},
	{
		"save_name": "Neutral_QueenSeraphineValedorn",
		"display_name": "Queen Seraphine Valedorn",
		"class_key": "GreatKnight",
		"weapon_name": "Holy Lance",
		"encounter_level": 18,
		"maps": [17, 20],
		"ally_behavior": "major_conditional_ally",
		"notes": "Sovereign coalition ally; should feel like a real war leader, not a cameo.",
		"stats": {"hp": 48, "str": 18, "mag": 8, "def": 15, "res": 14, "spd": 11, "agi": 14}
	},
	{
		"save_name": "Neutral_LysandraSolmere",
		"display_name": "Lysandra Solmere",
		"class_key": "DivineSage",
		"weapon_name": "Elysian Staff",
		"encounter_level": 16,
		"maps": [9, 17],
		"ally_behavior": "diplomatic_support",
		"notes": "Valeron moderate who can provide sanctuary wards, escorts, and green clerics.",
		"stats": {"hp": 36, "str": 1, "mag": 18, "def": 7, "res": 17, "spd": 10, "agi": 15}
	},
	{
		"save_name": "Neutral_ConsulMarcellusVeyne",
		"display_name": "Consul Marcellus Veyne",
		"class_key": "Spellblade",
		"weapon_name": "Traveler's Blade",
		"encounter_level": 15,
		"maps": [11, 17],
		"ally_behavior": "political_asset",
		"notes": "League reformist who can appear directly or remain a strategic enabler, depending on the chapter version.",
		"stats": {"hp": 35, "str": 11, "mag": 9, "def": 7, "res": 10, "spd": 13, "agi": 15}
	},
	{
		"save_name": "Neutral_SisterAvelineMarr",
		"display_name": "Sister Aveline Marr",
		"class_key": "DivineSage",
		"weapon_name": "Censure Staff",
		"encounter_level": 17,
		"maps": [15, 16],
		"ally_behavior": "occult_specialist",
		"notes": "Harsh sacred investigator who is most useful against rituals, curses, and abominations.",
		"stats": {"hp": 39, "str": 2, "mag": 20, "def": 8, "res": 18, "spd": 11, "agi": 16}
	},
	{
		"save_name": "Neutral_VaroKestrel",
		"display_name": "Varo Kestrel",
		"class_key": "Hero",
		"weapon_name": "Silver Sword",
		"encounter_level": 16,
		"maps": [7, 13, 17],
		"ally_behavior": "conditional_reinforcement",
		"notes": "Free-company captain who can arrive as hired muscle or earned reinforcement.",
		"stats": {"hp": 43, "str": 17, "mag": 0, "def": 11, "res": 7, "spd": 14, "agi": 14}
	}
]

func _run() -> void:
	_ensure_dir(OUTPUT_DIR)

	var created := 0
	var updated := 0
	var failed := 0

	for cfg in ALLIES:
		var save_path := OUTPUT_DIR + String(cfg["save_name"]) + ".tres"
		var existed := ResourceLoader.exists(save_path)
		var unit_data := _build_unit_data(cfg)

		if unit_data == null:
			failed += 1
			continue

		var err := ResourceSaver.save(unit_data, save_path)
		if err != OK:
			push_error("Failed to save neutral ally resource: %s (err=%s)" % [save_path, str(err)])
			failed += 1
		else:
			if existed:
				updated += 1
				print("♻ Updated neutral ally: %s" % save_path)
			else:
				created += 1
				print("✅ Created neutral ally: %s" % save_path)

	print("\n===== NEUTRAL ALLY UNITDATA GENERATION COMPLETE =====")
	print("Created: %d | Updated: %d | Failed: %d" % [created, updated, failed])
	print("Haldor intentionally excluded: hub crafter, not field unit.")

func _build_unit_data(cfg: Dictionary) -> UnitData:
	var data: UnitData = UNIT_DATA_SCRIPT.new() as UnitData
	if data == null:
		push_error("Could not instantiate UnitData. Check Scripts/Core/UnitData.gd.")
		return null

	data.display_name = String(cfg.get("display_name", "Neutral Ally"))
	data.is_recruitable = false
	data.recruit_dialogue = []
	data.pre_battle_quote = []
	data.death_quotes = _get_death_quotes(data.display_name)
	data.level_up_quotes = []
	data.ability = ""
	data.supports = []

	data.character_class = _load_class_resource(String(cfg.get("class_key", "")))
	data.starting_weapon = _load_weapon_resource(String(cfg.get("weapon_name", "")))
	data.death_sound = null

	data.unit_sprite = null
	data.portrait = null
	data.visual_scale = float(cfg.get("visual_scale", 1.0))

	var stats: Dictionary = cfg.get("stats", {})
	data.max_hp = int(stats.get("hp", 15))
	data.strength = int(stats.get("str", 3))
	data.magic = int(stats.get("mag", 0))
	data.defense = int(stats.get("def", 2))
	data.resistance = int(stats.get("res", 0))
	data.speed = int(stats.get("spd", 3))
	data.agility = int(stats.get("agi", 3))

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
	data.extra_loot = []

	return data

func _get_death_quotes(display_name: String) -> Array[String]:
	if DEATH_QUOTES.has(display_name):
		return DEATH_QUOTES[display_name].duplicate()
	return []

func _load_class_resource(class_key: String) -> Resource:
	var path := String(CLASS_PATHS.get(class_key, ""))
	var res := _try_load(path)
	if res == null:
		push_error("Missing class resource for neutral ally '%s' -> %s" % [class_key, path])
	return res

func _load_weapon_resource(weapon_name: String) -> Resource:
	var path := String(WEAPON_PATHS.get(weapon_name, ""))
	var res := _try_load(path)
	if res == null:
		push_error("Missing weapon resource for neutral ally '%s' -> %s" % [weapon_name, path])
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
