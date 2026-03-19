@tool
extends EditorScript

const UNIT_DATA_SCRIPT: Script = preload("res://Scripts/Core/UnitData.gd")

const OUTPUT_DIR: String = "res://Resources/EnemyUnitData/Bosses/"

const CLASS_PATHS := {
	"FireSage": "res://Resources/Classes/PromotedClass/FireSage.tres",
	"VoidStrider": "res://Resources/Classes/AscendedClass/VoidStrider.tres",
	"DivineSage": "res://Resources/Classes/PromotedClass/DivineSage.tres",
	"Assassin": "res://Resources/Classes/PromotedClass/Assassin.tres",
	"Monk": "res://Resources/Classes/Monk.tres",
	"BowKnight": "res://Resources/Classes/PromotedClass/BowKnight.tres",
	"DeathKnight": "res://Resources/Classes/PromotedClass/DeathKnight.tres",
	"BladeWeaver": "res://Resources/Classes/PromotedClass/BladeWeaver.tres",
	"Thief": "res://Resources/Classes/Thief.tres",
	"GreatKnight": "res://Resources/Classes/PromotedClass/GreatKnight.tres",
	"WildWarden": "res://Resources/Classes/PromotedClass/WildWarden.tres",
	"HighPaladin": "res://Resources/Classes/PromotedClass/HighPaladin.tres",
	"General": "res://Resources/Classes/PromotedClass/General.tres",
	"Dreadnought": "res://Resources/Classes/PromotedClass/Dreadnought.tres",
	"RiftArchon": "res://Resources/Classes/AscendedClass/RiftArchon.tres"
}

const WEAPON_PATHS := {
	"Rift Rite Tome": "res://Resources/GeneratedItems/Weapon_Rift_Rite_Tome.tres",
	"Grave Thesis": "res://Resources/GeneratedItems/Weapon_Grave_Thesis.tres",
	"Shadowglass Knives": "res://Resources/GeneratedItems/Weapon_Shadowglass_Knives.tres",
	"Silence Staff": "res://Resources/GeneratedItems/Weapon_Silence_Staff.tres",
	"Broker's Handgonne": "res://Resources/GeneratedItems/Weapon_Brokers_Handgonne.tres",
	"Blackened Lance": "res://Resources/GeneratedItems/Weapon_Blackened_Lance.tres",
	"Edict Staff": "res://Resources/GeneratedItems/Weapon_Edict_Staff.tres",
	"Bellhook Knife": "res://Resources/GeneratedItems/Weapon_Bellhook_Knife.tres",
	"Knight's Halberd": "res://Resources/GeneratedItems/Weapon_Knights_Halberd.tres",
	"Steel Axe": "res://Resources/GeneratedItems/Weapon_Steel_Axe.tres",
	"Judgment Pike": "res://Resources/GeneratedItems/Weapon_Judgment_Pike.tres",
	"Chain-Key Staff": "res://Resources/GeneratedItems/Weapon_Chain_Key_Staff.tres",
	"Pike of Valor": "res://Resources/GeneratedItems/Weapon_Pike_of_Valor.tres",
	"Verdict Blade": "res://Resources/GeneratedItems/Weapon_Verdict_Blade.tres",
	"Silver Lance": "res://Resources/GeneratedItems/Weapon_Silver_Lance.tres",
	"Dark Tide Grimoire": "res://Resources/GeneratedItems/Weapon_Dark_Tide_Grimoire.tres",
	"Null Hymn": "res://Resources/GeneratedItems/Weapon_Null_Hymn.tres"
}

const WEAPON_FALLBACKS := {
	"Censer Rod": [
		"res://Resources/GeneratedItems/Weapon_Censure_Staff.tres",
		"res://Resources/Weapons/Heal Staff.tres"
	],
	"Ledger Needle": [
		"res://Resources/GeneratedItems/Weapon_Sparkknife.tres",
		"res://Resources/GeneratedItems/Weapon_Bellhook_Knife.tres"
	],
	"Masquerade Needle": [
		"res://Resources/GeneratedItems/Weapon_Sparkknife.tres",
		"res://Resources/GeneratedItems/Weapon_Bellhook_Knife.tres"
	]
}

# Aligned with NARRATIVE PLAN/EnemyDeathLines.txt (stronger alternates as final picks). Vespera Ascendant: phase-specific finale line.
const DEATH_QUOTES := {
	"Lady Vespera": "I wanted to break the chain, and instead I became its final link.",
	"Vespera Ascendant": "Lyell… I reached for godhood only to find the same cold hands waiting there.",
	"Master Enric": "Remarkable… even at the threshold, decay still refuses to become elegant.",
	"Captain Selene": "Tch… precision fails only once, and the body remembers forever.",
	"Ephrem the Zealot": "No — this fire was meant to cleanse, not leave the guilty standing.",
	"Mother Caldris Vein": "Mercy is always beautiful from the mouths of those someone else protected.",
	"Port-Master Rhex Valcero": "Damn you… do you have any idea what a city costs to keep obedient?",
	"Mortivar Hale": "At last… an order I can obey by ending.",
	"Preceptor Cassian Vow": "How tedious… to die in the service of people too small to deserve order.",
	"Auditor Nerez Sable": "So the account closes here… and still none of you understand the price of chaos.",
	"Juno Kest": "Heh — guess I rang one bell too many.",
	"Lord Septen Harrow": "You call this justice? Try feeding a realm before you bury the men who kept it standing.",
	"Thorn-Captain Edda Fen": "Then the forest will judge between us… and I doubt it will be kind.",
	"Justicar Halwen Serast": "If this is judgment, let the sun remember that I did not kneel.",
	"Noemi Veyr": "So… the mask slips at last; pity the truth beneath it was sharper.",
	"Provost Serik Quill": "You break locks so easily… and never once ask why the doors were sealed.",
	"Roen Halbrecht": "I sold honor piece by piece and called the bargain necessary.",
	"The Ash Adjudicator": "Sentence… interrupted; yet the old oath still weighs upon the living.",
	"Duke Alric Thornmere": "If I fall, then Edranor belongs to louder men and lesser blood.",
	"Naeva, Marrow-Seer of the Dark Tide": "You hear it now, don’t you… the tide beneath the world.",
	"The Witness Without Eyes": "[No voice. The air folds inward.]"
}

const ENCOUNTERS := [
	{"save_name": "Boss_L01_LadyVespera_Apparition", "display_name": "Lady Vespera", "class_key": "FireSage", "weapon_name": "Rift Rite Tome", "ability": "cataclysmic_locus", "stats": {"hp": 38, "str": 0, "mag": 17, "def": 7, "res": 16, "spd": 12, "agi": 14}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L18_LadyVespera", "display_name": "Lady Vespera", "class_key": "FireSage", "weapon_name": "Rift Rite Tome", "ability": "cataclysmic_locus", "stats": {"hp": 52, "str": 0, "mag": 22, "def": 9, "res": 20, "spd": 15, "agi": 18}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L19_VesperaAscendant", "display_name": "Vespera Ascendant", "class_key": "VoidStrider", "weapon_name": "Rift Rite Tome", "ability": "cataclysmic_locus", "stats": {"hp": 68, "str": 4, "mag": 26, "def": 12, "res": 24, "spd": 17, "agi": 21}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}, "death_quotes": ["Lyell… I reached for godhood only to find the same cold hands waiting there."]},
	{"save_name": "Boss_L15_MasterEnric", "display_name": "Master Enric", "class_key": "DivineSage", "weapon_name": "Grave Thesis", "ability": "dissertation_of_rot", "stats": {"hp": 44, "str": 0, "mag": 20, "def": 6, "res": 15, "spd": 8, "agi": 15}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L13_CaptainSelene", "display_name": "Captain Selene", "class_key": "Assassin", "weapon_name": "Shadowglass Knives", "ability": "umbra_step", "stats": {"hp": 33, "str": 14, "mag": 0, "def": 7, "res": 8, "spd": 20, "agi": 18}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L18_CaptainSelene", "display_name": "Captain Selene", "class_key": "Assassin", "weapon_name": "Shadowglass Knives", "ability": "umbra_step", "stats": {"hp": 42, "str": 18, "mag": 0, "def": 9, "res": 10, "spd": 23, "agi": 21}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L03_EphremTheZealot", "display_name": "Ephrem the Zealot", "class_key": "Monk", "weapon_name": "Censer Rod", "ability": "mark_of_cinder", "stats": {"hp": 28, "str": 9, "mag": 6, "def": 7, "res": 8, "spd": 7, "agi": 8}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L02_MotherCaldrisVein", "display_name": "Mother Caldris Vein", "class_key": "DivineSage", "weapon_name": "Silence Staff", "ability": "litany_of_restraint", "stats": {"hp": 30, "str": 1, "mag": 12, "def": 5, "res": 12, "spd": 10, "agi": 13}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L10_MotherCaldrisVein", "display_name": "Mother Caldris Vein", "class_key": "DivineSage", "weapon_name": "Silence Staff", "ability": "litany_of_restraint", "stats": {"hp": 38, "str": 1, "mag": 16, "def": 6, "res": 15, "spd": 12, "agi": 16}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L17_MotherCaldrisVein", "display_name": "Mother Caldris Vein", "class_key": "DivineSage", "weapon_name": "Silence Staff", "ability": "litany_of_restraint", "stats": {"hp": 46, "str": 2, "mag": 20, "def": 8, "res": 18, "spd": 14, "agi": 18}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L04_PortMasterRhexValcero", "display_name": "Port-Master Rhex Valcero", "class_key": "BowKnight", "weapon_name": "Broker's Handgonne", "ability": "bought_time", "stats": {"hp": 34, "str": 11, "mag": 0, "def": 8, "res": 4, "spd": 9, "agi": 13}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L05_PortMasterRhexValcero", "display_name": "Port-Master Rhex Valcero", "class_key": "BowKnight", "weapon_name": "Broker's Handgonne", "ability": "bought_time", "stats": {"hp": 38, "str": 13, "mag": 0, "def": 9, "res": 5, "spd": 10, "agi": 15}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L06_MortivarHale", "display_name": "Mortivar Hale", "class_key": "DeathKnight", "weapon_name": "Blackened Lance", "ability": "grave_muster", "stats": {"hp": 42, "str": 16, "mag": 2, "def": 15, "res": 9, "spd": 8, "agi": 12}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L14_MortivarHale", "display_name": "Mortivar Hale", "class_key": "DeathKnight", "weapon_name": "Blackened Lance", "ability": "grave_muster", "stats": {"hp": 50, "str": 19, "mag": 3, "def": 18, "res": 11, "spd": 10, "agi": 15}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L09A_PreceptorCassianVow", "display_name": "Preceptor Cassian Vow", "class_key": "DivineSage", "weapon_name": "Edict Staff", "ability": "false_accord", "stats": {"hp": 34, "str": 0, "mag": 15, "def": 4, "res": 14, "spd": 10, "agi": 15}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L17_PreceptorCassianVow", "display_name": "Preceptor Cassian Vow", "class_key": "DivineSage", "weapon_name": "Edict Staff", "ability": "false_accord", "stats": {"hp": 45, "str": 0, "mag": 20, "def": 6, "res": 18, "spd": 12, "agi": 18}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L09B_AuditorNerezSable", "display_name": "Auditor Nerez Sable", "class_key": "BladeWeaver", "weapon_name": "Ledger Needle", "ability": "collateral_clause", "stats": {"hp": 32, "str": 10, "mag": 6, "def": 5, "res": 8, "spd": 16, "agi": 16}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L11_AuditorNerezSable", "display_name": "Auditor Nerez Sable", "class_key": "BladeWeaver", "weapon_name": "Ledger Needle", "ability": "collateral_clause", "stats": {"hp": 36, "str": 12, "mag": 7, "def": 6, "res": 9, "spd": 18, "agi": 18}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L17_AuditorNerezSable", "display_name": "Auditor Nerez Sable", "class_key": "BladeWeaver", "weapon_name": "Ledger Needle", "ability": "collateral_clause", "stats": {"hp": 44, "str": 15, "mag": 9, "def": 8, "res": 11, "spd": 20, "agi": 21}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L05_JunoKest", "display_name": "Juno Kest", "class_key": "Thief", "weapon_name": "Bellhook Knife", "ability": "alarm_net", "stats": {"hp": 30, "str": 10, "mag": 0, "def": 5, "res": 4, "spd": 17, "agi": 15}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L07_LordSeptenHarrow", "display_name": "Lord Septen Harrow", "class_key": "GreatKnight", "weapon_name": "Knight's Halberd", "ability": "hoardfire", "stats": {"hp": 46, "str": 16, "mag": 0, "def": 15, "res": 7, "spd": 6, "agi": 10}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L08_ThornCaptainEddaFen", "display_name": "Thorn-Captain Edda Fen", "class_key": "WildWarden", "weapon_name": "Steel Axe", "ability": "timberline_snare", "stats": {"hp": 40, "str": 14, "mag": 0, "def": 10, "res": 8, "spd": 12, "agi": 16}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L10_JusticarHalwenSerast", "display_name": "Justicar Halwen Serast", "class_key": "HighPaladin", "weapon_name": "Judgment Pike", "ability": "verdict_of_flame", "stats": {"hp": 48, "str": 17, "mag": 6, "def": 14, "res": 12, "spd": 11, "agi": 15}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L11_NoemiVeyr", "display_name": "Noemi Veyr", "class_key": "Assassin", "weapon_name": "Masquerade Needle", "ability": "fifth_mask", "stats": {"hp": 34, "str": 15, "mag": 0, "def": 6, "res": 9, "spd": 22, "agi": 20}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L12_ProvostSerikQuill", "display_name": "Provost Serik Quill", "class_key": "DivineSage", "weapon_name": "Chain-Key Staff", "ability": "archive_lock", "stats": {"hp": 37, "str": 0, "mag": 18, "def": 6, "res": 15, "spd": 9, "agi": 17}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L14_RoenHalbrecht", "display_name": "Roen Halbrecht", "class_key": "General", "weapon_name": "Pike of Valor", "ability": "betrayers_lever", "stats": {"hp": 50, "str": 18, "mag": 0, "def": 17, "res": 8, "spd": 7, "agi": 12}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L16_AshAdjudicator", "display_name": "The Ash Adjudicator", "class_key": "Dreadnought", "weapon_name": "Verdict Blade", "ability": "trial_mirror", "stats": {"hp": 55, "str": 19, "mag": 8, "def": 18, "res": 16, "spd": 10, "agi": 18}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L17_DukeAlricThornmere", "display_name": "Duke Alric Thornmere", "class_key": "HighPaladin", "weapon_name": "Silver Lance", "ability": "banner_break", "stats": {"hp": 52, "str": 19, "mag": 0, "def": 15, "res": 10, "spd": 13, "agi": 17}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L18_NaevaMarrowSeer", "display_name": "Naeva, Marrow-Seer of the Dark Tide", "class_key": "VoidStrider", "weapon_name": "Dark Tide Grimoire", "ability": "marrow_hymn", "stats": {"hp": 48, "str": 0, "mag": 24, "def": 8, "res": 20, "spd": 15, "agi": 18}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}},
	{"save_name": "Boss_L19_WitnessWithoutEyes", "display_name": "The Witness Without Eyes", "class_key": "RiftArchon", "weapon_name": "Null Hymn", "ability": "unmake_the_grid", "stats": {"hp": 72, "str": 18, "mag": 26, "def": 20, "res": 24, "spd": 14, "agi": 20}, "growths": {"hp": 0, "str": 0, "mag": 0, "def": 0, "res": 0, "spd": 0, "agi": 0}}
]

func _run() -> void:
	_ensure_dir(OUTPUT_DIR)

	var created: int = 0
	var updated: int = 0
	var failures: int = 0

	for encounter_variant in ENCOUNTERS:
		var encounter: Dictionary = encounter_variant
		var save_path: String = OUTPUT_DIR + String(encounter.get("save_name", "UnnamedBoss")) + ".tres"
		var existed: bool = ResourceLoader.exists(save_path)
		var unit_data: UnitData = _build_unit_data(encounter)

		if unit_data == null:
			failures += 1
			continue

		var err: Error = ResourceSaver.save(unit_data, save_path)
		if err != OK:
			push_error("Failed to save enemy resource: %s (err=%s)" % [save_path, str(err)])
			failures += 1
		else:
			if existed:
				updated += 1
				print("Updated: %s" % save_path)
			else:
				created += 1
				print("Created: %s" % save_path)

	print("\n===== BOSS UNITDATA GENERATION COMPLETE =====")
	print("Created: %d | Updated: %d | Failed: %d" % [created, updated, failures])

func _build_unit_data(cfg: Dictionary) -> UnitData:
	var data: UnitData = UNIT_DATA_SCRIPT.new() as UnitData
	if data == null:
		push_error("Could not instantiate UnitData from res://Scripts/Core/UnitData.gd")
		return null

	data.display_name = str(cfg.get("display_name", "Enemy"))
	data.is_recruitable = false
	data.recruit_dialogue = _string_array([])
	data.pre_battle_quote = _string_array(cfg.get("pre_battle_quotes", []))

	var display_name: String = data.display_name
	var death_quotes: Array[String] = _string_array(cfg.get("death_quotes", []))
	if death_quotes.is_empty() and DEATH_QUOTES.has(display_name):
		death_quotes = [DEATH_QUOTES[display_name]]
	data.death_quotes = death_quotes
	data.level_up_quotes = _string_array(cfg.get("level_up_quotes", []))

	data.character_class = _load_class_resource(str(cfg.get("class_key", "")))
	data.starting_weapon = _load_weapon_resource(str(cfg.get("weapon_name", "")))
	data.ability = str(cfg.get("ability", ""))

	var sprite_path: String = str(cfg.get("sprite_path", ""))
	var portrait_path: String = str(cfg.get("portrait_path", ""))
	data.unit_sprite = _try_load(sprite_path) as Texture2D
	data.portrait = _try_load(portrait_path) as Texture2D
	data.visual_scale = float(cfg.get("visual_scale", 1.0))

	var stats: Dictionary = cfg.get("stats", {})
	data.max_hp = int(stats.get("hp", 15))
	data.strength = int(stats.get("str", 3))
	data.magic = int(stats.get("mag", 0))
	data.defense = int(stats.get("def", 2))
	data.resistance = int(stats.get("res", 0))
	data.speed = int(stats.get("spd", 3))
	data.agility = int(stats.get("agi", 3))

	var growths: Dictionary = cfg.get("growths", {})
	data.hp_growth = int(growths.get("hp", 0))
	data.str_growth = int(growths.get("str", 0))
	data.mag_growth = int(growths.get("mag", 0))
	data.def_growth = int(growths.get("def", 0))
	data.res_growth = int(growths.get("res", 0))
	data.spd_growth = int(growths.get("spd", 0))
	data.agi_growth = int(growths.get("agi", 0))

	var gold_drop: Dictionary = cfg.get("gold_drop", {})
	data.min_gold_drop = int(gold_drop.get("min", 0))
	data.max_gold_drop = int(gold_drop.get("max", 0))
	data.drops_equipped_weapon = bool(cfg.get("drops_equipped_weapon", false))
	data.equipped_weapon_chance = int(cfg.get("equipped_weapon_chance", 100))

	var empty_loot: Array[LootDrop] = []
	data.extra_loot = empty_loot
	return data

func _load_class_resource(class_key: String) -> ClassData:
	var path: String = str(CLASS_PATHS.get(class_key, ""))
	var res: ClassData = _try_load(path) as ClassData
	if res == null:
		push_error("Missing class resource for key '%s' -> %s" % [class_key, path])
	return res

func _load_weapon_resource(weapon_name: String) -> WeaponData:
	var exact_path: String = str(WEAPON_PATHS.get(weapon_name, ""))
	if exact_path != "":
		var exact_res: WeaponData = _try_load(exact_path) as WeaponData
		if exact_res != null:
			return exact_res
		push_warning("Exact weapon path missing for '%s': %s" % [weapon_name, exact_path])

	if WEAPON_FALLBACKS.has(weapon_name):
		var fallback_paths: Array = WEAPON_FALLBACKS[weapon_name]
		for fallback_variant in fallback_paths:
			var fallback_path: String = str(fallback_variant)
			var fallback_res: WeaponData = _try_load(fallback_path) as WeaponData
			if fallback_res != null:
				push_warning("Using fallback weapon for '%s' -> %s" % [weapon_name, fallback_path])
				return fallback_res

	push_warning("No weapon resource found for '%s'. Resource will be saved with null starting_weapon." % weapon_name)
	return null

func _try_load(path: String) -> Resource:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		return null
	return load(path)

func _ensure_dir(res_dir: String) -> void:
	var abs_dir: String = ProjectSettings.globalize_path(res_dir.trim_suffix("/"))
	DirAccess.make_dir_recursive_absolute(abs_dir)

func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for item in value:
			out.append(str(item))
	return out
