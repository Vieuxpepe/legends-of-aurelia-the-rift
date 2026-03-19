@tool
extends EditorScript

const UNIT_DATA_SCRIPT := preload("res://Scripts/Core/UnitData.gd")
const OUTPUT_BASE_DIR := "res://Resources/EnemyUnitData/Generic/"

# Generic enemies only: no death lines, no abilities, no portraits/sprites assigned here.
# These are reusable encounter packages for the map roster below.

const CLASS_PATHS := {
	"Novice": "res://Resources/Classes/RookieClass/Novice.tres",
	"Apprentice": "res://Resources/Classes/RookieClass/Apprentice.tres",
	"Recruit": "res://Resources/Classes/RookieClass/Recruit.tres",
	"Urchin": "res://Resources/Classes/RookieClass/Urchin.tres",
	"Villager": "res://Resources/Classes/RookieClass/Villager.tres",
	"Archer": "res://Resources/Classes/Archer.tres",
	"Beastmaster": "res://Resources/Classes/Beastmaster.tres",
	"Cannoneer": "res://Resources/Classes/Cannoneer.tres",
	"Cleric": "res://Resources/Classes/Cleric.tres",
	"Knight": "res://Resources/Classes/Knight.tres",
	"Mage": "res://Resources/Classes/Mage.tres",
	"Mercenary": "res://Resources/Classes/Mercenary.tres",
	"Monk": "res://Resources/Classes/Monk.tres",
	"Monster": "res://Resources/Classes/Monster.tres",
	"Paladin": "res://Resources/Classes/Paladin.tres",
	"Spellblade": "res://Resources/Classes/Spellblade.tres",
	"Thief": "res://Resources/Classes/Thief.tres",
	"Warrior": "res://Resources/Classes/Warrior.tres",
	"Assassin": "res://Resources/Classes/PromotedClass/Assassin.tres",
	"BladeWeaver": "res://Resources/Classes/PromotedClass/BladeWeaver.tres",
	"BowKnight": "res://Resources/Classes/PromotedClass/BowKnight.tres",
	"DeathKnight": "res://Resources/Classes/PromotedClass/DeathKnight.tres",
	"DivineSage": "res://Resources/Classes/PromotedClass/DivineSage.tres",
	"Dreadnought": "res://Resources/Classes/PromotedClass/Dreadnought.tres",
	"FireSage": "res://Resources/Classes/PromotedClass/FireSage.tres",
	"General": "res://Resources/Classes/PromotedClass/General.tres",
	"GreatKnight": "res://Resources/Classes/PromotedClass/GreatKnight.tres",
	"HeavyArcher": "res://Resources/Classes/PromotedClass/HeavyArcher.tres",
	"Hero": "res://Resources/Classes/PromotedClass/Hero.tres",
	"HighPaladin": "res://Resources/Classes/PromotedClass/HighPaladin.tres",
	"WildWarden": "res://Resources/Classes/PromotedClass/WildWarden.tres",
	"RiftArchon": "res://Resources/Classes/AscendedClass/RiftArchon.tres",
	"VoidStrider": "res://Resources/Classes/AscendedClass/VoidStrider.tres",
}

const WEAPON_PATHS := {
	"Rusty Sword": "res://Resources/GeneratedItems/Weapon_Rusty_Sword.tres",
	"Iron Sword": "res://Resources/GeneratedItems/Weapon_Iron_Sword.tres",
	"Traveler's Blade": "res://Resources/GeneratedItems/Weapon_Travelers_Blade.tres",
	"Steel Sword": "res://Resources/GeneratedItems/Weapon_Steel_Sword.tres",
	"Silver Sword": "res://Resources/GeneratedItems/Weapon_Silver_Sword.tres",
	"Oathcutter": "res://Resources/GeneratedItems/Weapon_Oathcutter.tres",
	"Flame Blade": "res://Resources/GeneratedItems/Weapon_Flame_Blade.tres",
	"Sunsteel Brand": "res://Resources/GeneratedItems/Weapon_Sunsteel_Brand.tres",
	"Bronze Pike": "res://Resources/GeneratedItems/Weapon_Bronze_Pike.tres",
	"Wooden Pike": "res://Resources/GeneratedItems/Weapon_Wooden_Pike.tres",
	"Old Spear": "res://Resources/GeneratedItems/Weapon_Old_Spear.tres",
	"Holy Lance": "res://Resources/GeneratedItems/Weapon_Holy_Lance.tres",
	"Blackened Lance": "res://Resources/GeneratedItems/Weapon_Blackened_Lance.tres",
	"Thunder Pike": "res://Resources/GeneratedItems/Weapon_Thunder_Pike.tres",
	"Judgment Pike": "res://Resources/GeneratedItems/Weapon_Judgment_Pike.tres",
	"Silver Lance": "res://Resources/GeneratedItems/Weapon_Silver_Lance.tres",
	"Bronze Axe": "res://Resources/GeneratedItems/Weapon_Bronze_Axe.tres",
	"Raiders Splitter": "res://Resources/GeneratedItems/Weapon_Raiders_Splitter.tres",
	"Steel Axe": "res://Resources/GeneratedItems/Weapon_Steel_Axe.tres",
	"Great Axe": "res://Resources/GeneratedItems/Weapon_Great_Axe.tres",
	"War Axe": "res://Resources/GeneratedItems/Weapon_War_Axe.tres",
	"Ash Shortbow": "res://Resources/GeneratedItems/Weapon_Ash_Shortbow.tres",
	"Crude Bow": "res://Resources/GeneratedItems/Weapon_Crude_Bow.tres",
	"Hunters Bow": "res://Resources/GeneratedItems/Weapon_Hunters_Bow.tres",
	"Reinforced Bow": "res://Resources/GeneratedItems/Weapon_Reinforced_Bow.tres",
	"Longbow": "res://Resources/GeneratedItems/Weapon_Longbow.tres",
	"Storm Bow": "res://Resources/GeneratedItems/Weapon_Storm_Bow.tres",
	"Apprentice Tome": "res://Resources/GeneratedItems/Weapon_Apprentice_Tome.tres",
	"Fire Tome": "res://Resources/GeneratedItems/Weapon_Fire_Tome.tres",
	"Flame Tome": "res://Resources/GeneratedItems/Weapon_Flame_Tome.tres",
	"Arcane Grimoire": "res://Resources/GeneratedItems/Weapon_Arcane_Grimoire.tres",
	"Prism Tome": "res://Resources/GeneratedItems/Weapon_Prism_Tome.tres",
	"Celestial Tome": "res://Resources/GeneratedItems/Weapon_Celestial_Tome.tres",
	"Gloam Primer": "res://Resources/GeneratedItems/Weapon_Gloam_Primer.tres",
	"Hexleaf Codex": "res://Resources/GeneratedItems/Weapon_Hexleaf_Codex.tres",
	"Dark Tide Grimoire": "res://Resources/GeneratedItems/Weapon_Dark_Tide_Grimoire.tres",
	"Scrap Knife": "res://Resources/GeneratedItems/Weapon_Scrap_Knife.tres",
	"Street Dirk": "res://Resources/GeneratedItems/Weapon_Street_Dirk.tres",
	"Bellhook Knife": "res://Resources/GeneratedItems/Weapon_Bellhook_Knife.tres",
	"Sparkknife": "res://Resources/GeneratedItems/Weapon_Sparkknife.tres",
	"Militia Handgonne": "res://Resources/GeneratedItems/Weapon_Militia_Handgonne.tres",
	"Ramshackle Culverin": "res://Resources/GeneratedItems/Weapon_Ramshackle_Culverin.tres",
	"Wrapped Cestus": "res://Resources/GeneratedItems/Weapon_Wrapped_Cestus.tres",
	"Pilgrim's Knuckles": "res://Resources/GeneratedItems/Weapon_Pilgrims_Knuckles.tres",
	"Temple Gauntlets": "res://Resources/GeneratedItems/Weapon_Temple_Gauntlets.tres",
	"Doom Hammer": "res://Resources/GeneratedItems/Weapon_Doom_Hammer.tres",
	"Null Hymn": "res://Resources/GeneratedItems/Weapon_Null_Hymn.tres",
}

const MAP_ROSTERS := {
	"Map01_RazedVillage": ["ash_cultist_t1", "pyre_disciple_t1", "soul_reaver_t1", "cinder_archer_t1"],
	"Map02_EmberwoodFlight": ["ash_cultist_t1", "pyre_disciple_t1", "soul_reaver_t1", "cinder_archer_t1", "rift_hound_t1"],
	"Map03_ShatteredSanctum": ["purifier_acolyte_t1", "temple_guard_t1", "sun_archer_t1", "censer_cleric_t1", "doctrine_blade_t2"],
	"Map04_MerchantsMaze": ["dock_thug_t1", "watch_crossbowman_t1", "rooftop_knife_t1", "sewer_smuggler_t1", "contract_guard_t2"],
	"Map05_LeagueDockAssault": ["bell_rigger_t1", "watch_crossbowman_t1", "powder_gunner_t2", "contract_guard_t2", "dock_thug_t1", "league_marshal_t2"],
	"Map06_SiegeOfGreyspire": ["bone_pikeman_t2", "graveblade_t2", "crypt_archer_t2", "death_acolyte_t2", "mournful_husk_t1"],
	"Map07_FaminesPrice": ["granary_guard_t2", "levy_spearman_t1", "tax_archer_t1", "mounted_retainer_t2", "road_bailiff_t2", "houndmaster_t2"],
	"Map08_SacredForestSkirmish": ["axebark_raider_t2", "road_warden_t2", "cliff_skirmisher_t2", "trapkeeper_t1", "houndmaster_t2", "totem_keeper_t2"],
	"Map09A_MountainPassNegotiation": ["temple_guard_t1", "purifier_acolyte_t1", "sun_archer_t1", "doctrine_blade_t2", "ashen_templar_t2"],
	"Map09B_LeagueCouncilSkirmish": ["rooftop_knife_t1", "contract_guard_t2", "accountant_duelist_t2", "bell_rigger_t1", "watch_crossbowman_t1", "league_marshal_t2"],
	"Map10_SunlitTrial": ["temple_guard_t1", "censer_cleric_t1", "doctrine_blade_t2", "ashen_templar_t2", "inquisitor_adept_t2", "arena_templar_t3"],
	"Map11_MarketOfMasks": ["rooftop_knife_t1", "watch_crossbowman_t1", "contract_guard_t2", "accountant_duelist_t2", "bell_rigger_t1"],
	"Map12_ShadowsInTheCollege": ["archive_warden_t2", "scriptor_mage_t1", "barrier_adept_t1", "stair_duelist_t2", "lamp_runner_t1", "sealkeeper_t2"],
	"Map13_StormingTheBlackCoast": ["black_coast_raider_t3", "tide_archer_t3", "pyre_disciple_t1", "ritual_adept_t2", "siege_crew_t3", "shadowblade_skirmisher_t3", "rift_hound_t1"],
	"Map14_DawnkeepAmbush": ["bone_pikeman_t2", "graveblade_t2", "crypt_archer_t2", "revenant_rider_t3", "trapkeeper_t1"],
	"Map15_WeepingMarsh": ["mournful_husk_t1", "rot_binder_t3", "drowned_archer_t3", "mire_hexer_t3", "death_acolyte_t2"],
	"Map16_EchoesOfTheOrder": ["oathshade_t3", "dawn_sentinel_t3", "trial_archer_t3", "chapel_echo_t2", "mirror_judge_t3"],
	"Map17_GatheringStorms": ["purifier_acolyte_t1", "contract_guard_t2", "mounted_retainer_t2", "rooftop_knife_t1", "temple_guard_t1", "league_marshal_t2", "road_bailiff_t2"],
	"Map18_RitualOfTheDarkTide": ["void_acolyte_t3", "tide_thrall_t2", "anchor_guardian_t3", "rift_stalker_t3", "null_choir_t3", "black_coast_raider_t3", "shadowblade_skirmisher_t3"],
	"Map19_TheTrueCatalyst": ["unmade_horror_t4", "null_choir_t3", "abyss_lancer_t3", "rift_stalker_t3", "tendril_spawn_t3", "glyph_breaker_t4", "anchor_guardian_t3"],
	"Map20_Epilogue_Sacrifice": ["tide_thrall_t2", "void_acolyte_t3", "black_coast_raider_t3", "unmade_horror_t4"],
	"Map20_Epilogue_Ascension": ["dawn_sentinel_t3", "mirror_judge_t3", "glyph_breaker_t4", "oathshade_t3"],
}

const ENEMIES := [
	{
		"id": "ash_cultist_t1",
		"faction": "ObsidianCircle",
		"display_name": "Ash Cultist",
		"class_key": "Novice",
		"weapon_name": "Rusty Sword",
		"tier": 1,
		"stats": {"hp": 18, "str": 6, "mag": 0, "def": 3, "res": 1, "spd": 4, "agi": 5},
	},
	{
		"id": "pyre_disciple_t1",
		"faction": "ObsidianCircle",
		"display_name": "Pyre Disciple",
		"class_key": "Apprentice",
		"weapon_name": "Fire Tome",
		"tier": 1,
		"stats": {"hp": 16, "str": 1, "mag": 7, "def": 1, "res": 4, "spd": 4, "agi": 5},
	},
	{
		"id": "soul_reaver_t1",
		"faction": "ObsidianCircle",
		"display_name": "Soul Reaver",
		"class_key": "Mercenary",
		"weapon_name": "Traveler's Blade",
		"tier": 1,
		"stats": {"hp": 22, "str": 8, "mag": 0, "def": 4, "res": 2, "spd": 6, "agi": 6},
	},
	{
		"id": "cinder_archer_t1",
		"faction": "ObsidianCircle",
		"display_name": "Cinder Archer",
		"class_key": "Archer",
		"weapon_name": "Ash Shortbow",
		"tier": 1,
		"stats": {"hp": 19, "str": 7, "mag": 0, "def": 3, "res": 2, "spd": 5, "agi": 6},
	},
	{
		"id": "rift_hound_t1",
		"faction": "ObsidianCircle",
		"display_name": "Rift Hound",
		"class_key": "Monster",
		"weapon_name": "Wrapped Cestus",
		"tier": 1,
		"stats": {"hp": 20, "str": 7, "mag": 0, "def": 2, "res": 1, "spd": 7, "agi": 5},
	},
	{
		"id": "ritual_adept_t2",
		"faction": "ObsidianCircle",
		"display_name": "Ritual Adept",
		"class_key": "Monk",
		"weapon_name": "Pilgrim's Knuckles",
		"tier": 2,
		"stats": {"hp": 24, "str": 8, "mag": 2, "def": 4, "res": 5, "spd": 5, "agi": 6},
	},
	{
		"id": "void_touched_elite_t3",
		"faction": "ObsidianCircle",
		"display_name": "Void-Touched Elite",
		"class_key": "FireSage",
		"weapon_name": "Gloam Primer",
		"tier": 3,
		"stats": {"hp": 34, "str": 2, "mag": 13, "def": 5, "res": 9, "spd": 6, "agi": 8},
	},
	{
		"id": "black_coast_raider_t3",
		"faction": "ObsidianCircle",
		"display_name": "Black Coast Raider",
		"class_key": "Warrior",
		"weapon_name": "Raiders Splitter",
		"tier": 3,
		"stats": {"hp": 36, "str": 13, "mag": 0, "def": 7, "res": 3, "spd": 6, "agi": 6},
	},
	{
		"id": "tide_archer_t3",
		"faction": "ObsidianCircle",
		"display_name": "Tide Archer",
		"class_key": "HeavyArcher",
		"weapon_name": "Storm Bow",
		"tier": 3,
		"stats": {"hp": 34, "str": 12, "mag": 0, "def": 7, "res": 4, "spd": 5, "agi": 6},
	},
	{
		"id": "shadowblade_skirmisher_t3",
		"faction": "ObsidianCircle",
		"display_name": "Shadowblade Skirmisher",
		"class_key": "Assassin",
		"weapon_name": "Sparkknife",
		"tier": 3,
		"stats": {"hp": 30, "str": 11, "mag": 0, "def": 4, "res": 4, "spd": 9, "agi": 9},
	},
	{
		"id": "siege_crew_t3",
		"faction": "ObsidianCircle",
		"display_name": "Siege Crew",
		"class_key": "Cannoneer",
		"weapon_name": "Ramshackle Culverin",
		"tier": 3,
		"stats": {"hp": 38, "str": 13, "mag": 0, "def": 9, "res": 2, "spd": 3, "agi": 3},
	},
	{
		"id": "purifier_acolyte_t1",
		"faction": "Valeron",
		"display_name": "Purifier Acolyte",
		"class_key": "Monk",
		"weapon_name": "Temple Gauntlets",
		"tier": 1,
		"stats": {"hp": 20, "str": 7, "mag": 2, "def": 4, "res": 5, "spd": 5, "agi": 6},
	},
	{
		"id": "temple_guard_t1",
		"faction": "Valeron",
		"display_name": "Temple Guard",
		"class_key": "Knight",
		"weapon_name": "Bronze Pike",
		"tier": 1,
		"stats": {"hp": 24, "str": 8, "mag": 0, "def": 7, "res": 2, "spd": 3, "agi": 4},
	},
	{
		"id": "sun_archer_t1",
		"faction": "Valeron",
		"display_name": "Sun Archer",
		"class_key": "Archer",
		"weapon_name": "Hunters Bow",
		"tier": 1,
		"stats": {"hp": 20, "str": 7, "mag": 0, "def": 3, "res": 3, "spd": 5, "agi": 6},
	},
	{
		"id": "censer_cleric_t1",
		"faction": "Valeron",
		"display_name": "Censer Cleric",
		"class_key": "Cleric",
		"weapon_name": "Prism Tome",
		"tier": 1,
		"stats": {"hp": 18, "str": 0, "mag": 8, "def": 2, "res": 6, "spd": 4, "agi": 6},
	},
	{
		"id": "doctrine_blade_t2",
		"faction": "Valeron",
		"display_name": "Doctrine Blade",
		"class_key": "Spellblade",
		"weapon_name": "Flame Blade",
		"tier": 2,
		"stats": {"hp": 23, "str": 7, "mag": 5, "def": 4, "res": 4, "spd": 6, "agi": 6},
	},
	{
		"id": "ashen_templar_t2",
		"faction": "Valeron",
		"display_name": "Ashen Templar",
		"class_key": "Paladin",
		"weapon_name": "Holy Lance",
		"tier": 2,
		"stats": {"hp": 30, "str": 10, "mag": 2, "def": 8, "res": 5, "spd": 5, "agi": 6},
	},
	{
		"id": "inquisitor_adept_t2",
		"faction": "Valeron",
		"display_name": "Inquisitor Adept",
		"class_key": "DivineSage",
		"weapon_name": "Prism Tome",
		"tier": 2,
		"stats": {"hp": 28, "str": 0, "mag": 11, "def": 4, "res": 8, "spd": 6, "agi": 8},
	},
	{
		"id": "arena_templar_t3",
		"faction": "Valeron",
		"display_name": "Arena Templar",
		"class_key": "HighPaladin",
		"weapon_name": "Judgment Pike",
		"tier": 3,
		"stats": {"hp": 36, "str": 13, "mag": 4, "def": 10, "res": 8, "spd": 7, "agi": 8},
	},
	{
		"id": "dock_thug_t1",
		"faction": "League",
		"display_name": "Dock Thug",
		"class_key": "Warrior",
		"weapon_name": "Bronze Axe",
		"tier": 1,
		"stats": {"hp": 24, "str": 8, "mag": 0, "def": 4, "res": 1, "spd": 4, "agi": 4},
	},
	{
		"id": "watch_crossbowman_t1",
		"faction": "League",
		"display_name": "Watch Crossbowman",
		"class_key": "Archer",
		"weapon_name": "Crude Bow",
		"tier": 1,
		"stats": {"hp": 20, "str": 7, "mag": 0, "def": 3, "res": 2, "spd": 5, "agi": 5},
	},
	{
		"id": "rooftop_knife_t1",
		"faction": "League",
		"display_name": "Rooftop Knife",
		"class_key": "Thief",
		"weapon_name": "Street Dirk",
		"tier": 1,
		"stats": {"hp": 18, "str": 6, "mag": 0, "def": 2, "res": 2, "spd": 8, "agi": 8},
	},
	{
		"id": "contract_guard_t2",
		"faction": "League",
		"display_name": "Contract Guard",
		"class_key": "Mercenary",
		"weapon_name": "Iron Sword",
		"tier": 2,
		"stats": {"hp": 24, "str": 8, "mag": 0, "def": 5, "res": 2, "spd": 6, "agi": 6},
	},
	{
		"id": "bell_rigger_t1",
		"faction": "League",
		"display_name": "Bell Rigger",
		"class_key": "Thief",
		"weapon_name": "Bellhook Knife",
		"tier": 1,
		"stats": {"hp": 19, "str": 6, "mag": 0, "def": 2, "res": 3, "spd": 7, "agi": 7},
	},
	{
		"id": "powder_gunner_t2",
		"faction": "League",
		"display_name": "Powder Gunner",
		"class_key": "Cannoneer",
		"weapon_name": "Militia Handgonne",
		"tier": 2,
		"stats": {"hp": 26, "str": 9, "mag": 0, "def": 6, "res": 1, "spd": 2, "agi": 3},
	},
	{
		"id": "accountant_duelist_t2",
		"faction": "League",
		"display_name": "Accountant Duelist",
		"class_key": "Spellblade",
		"weapon_name": "Flame Blade",
		"tier": 2,
		"stats": {"hp": 24, "str": 7, "mag": 4, "def": 4, "res": 4, "spd": 7, "agi": 7},
	},
	{
		"id": "sewer_smuggler_t1",
		"faction": "League",
		"display_name": "Sewer Smuggler",
		"class_key": "Thief",
		"weapon_name": "Scrap Knife",
		"tier": 1,
		"stats": {"hp": 19, "str": 7, "mag": 0, "def": 3, "res": 2, "spd": 7, "agi": 6},
	},
	{
		"id": "league_marshal_t2",
		"faction": "League",
		"display_name": "League Marshal",
		"class_key": "GreatKnight",
		"weapon_name": "Old Spear",
		"tier": 2,
		"stats": {"hp": 34, "str": 11, "mag": 0, "def": 10, "res": 4, "spd": 4, "agi": 5},
	},
	{
		"id": "bone_pikeman_t2",
		"faction": "UndeadGreyspire",
		"display_name": "Bone Pikeman",
		"class_key": "Knight",
		"weapon_name": "Old Spear",
		"tier": 2,
		"stats": {"hp": 26, "str": 9, "mag": 0, "def": 8, "res": 2, "spd": 3, "agi": 4},
	},
	{
		"id": "graveblade_t2",
		"faction": "UndeadGreyspire",
		"display_name": "Graveblade",
		"class_key": "Mercenary",
		"weapon_name": "Oathcutter",
		"tier": 2,
		"stats": {"hp": 25, "str": 9, "mag": 0, "def": 5, "res": 2, "spd": 5, "agi": 5},
	},
	{
		"id": "crypt_archer_t2",
		"faction": "UndeadGreyspire",
		"display_name": "Crypt Archer",
		"class_key": "Archer",
		"weapon_name": "Reinforced Bow",
		"tier": 2,
		"stats": {"hp": 22, "str": 8, "mag": 0, "def": 4, "res": 2, "spd": 5, "agi": 5},
	},
	{
		"id": "mournful_husk_t1",
		"faction": "UndeadGreyspire",
		"display_name": "Mournful Husk",
		"class_key": "Monster",
		"weapon_name": "Rusty Sword",
		"tier": 1,
		"stats": {"hp": 24, "str": 8, "mag": 0, "def": 4, "res": 1, "spd": 4, "agi": 3},
	},
	{
		"id": "death_acolyte_t2",
		"faction": "UndeadGreyspire",
		"display_name": "Death Acolyte",
		"class_key": "Mage",
		"weapon_name": "Gloam Primer",
		"tier": 2,
		"stats": {"hp": 20, "str": 0, "mag": 9, "def": 2, "res": 5, "spd": 5, "agi": 6},
	},
	{
		"id": "revenant_rider_t3",
		"faction": "UndeadGreyspire",
		"display_name": "Revenant Rider",
		"class_key": "DeathKnight",
		"weapon_name": "Blackened Lance",
		"tier": 3,
		"stats": {"hp": 36, "str": 12, "mag": 3, "def": 10, "res": 6, "spd": 5, "agi": 6},
	},
	{
		"id": "rot_binder_t3",
		"faction": "UndeadGreyspire",
		"display_name": "Rot Binder",
		"class_key": "DivineSage",
		"weapon_name": "Hexleaf Codex",
		"tier": 3,
		"stats": {"hp": 30, "str": 0, "mag": 11, "def": 4, "res": 8, "spd": 5, "agi": 7},
	},
	{
		"id": "drowned_archer_t3",
		"faction": "UndeadGreyspire",
		"display_name": "Drowned Archer",
		"class_key": "HeavyArcher",
		"weapon_name": "Longbow",
		"tier": 3,
		"stats": {"hp": 30, "str": 11, "mag": 0, "def": 7, "res": 3, "spd": 4, "agi": 5},
	},
	{
		"id": "mire_hexer_t3",
		"faction": "UndeadGreyspire",
		"display_name": "Mire Hexer",
		"class_key": "FireSage",
		"weapon_name": "Hexleaf Codex",
		"tier": 3,
		"stats": {"hp": 32, "str": 0, "mag": 12, "def": 4, "res": 8, "spd": 6, "agi": 7},
	},
	{
		"id": "granary_guard_t2",
		"faction": "EdranorAndForest",
		"display_name": "Granary Guard",
		"class_key": "Knight",
		"weapon_name": "Bronze Pike",
		"tier": 2,
		"stats": {"hp": 25, "str": 8, "mag": 0, "def": 7, "res": 2, "spd": 3, "agi": 4},
	},
	{
		"id": "levy_spearman_t1",
		"faction": "EdranorAndForest",
		"display_name": "Levy Spearman",
		"class_key": "Recruit",
		"weapon_name": "Wooden Pike",
		"tier": 1,
		"stats": {"hp": 18, "str": 6, "mag": 0, "def": 3, "res": 1, "spd": 4, "agi": 4},
	},
	{
		"id": "tax_archer_t1",
		"faction": "EdranorAndForest",
		"display_name": "Tax Archer",
		"class_key": "Archer",
		"weapon_name": "Crude Bow",
		"tier": 1,
		"stats": {"hp": 19, "str": 6, "mag": 0, "def": 3, "res": 1, "spd": 5, "agi": 5},
	},
	{
		"id": "mounted_retainer_t2",
		"faction": "EdranorAndForest",
		"display_name": "Mounted Retainer",
		"class_key": "Paladin",
		"weapon_name": "Old Spear",
		"tier": 2,
		"stats": {"hp": 28, "str": 9, "mag": 1, "def": 7, "res": 3, "spd": 5, "agi": 5},
	},
	{
		"id": "road_bailiff_t2",
		"faction": "EdranorAndForest",
		"display_name": "Road Bailiff",
		"class_key": "Mercenary",
		"weapon_name": "Traveler's Blade",
		"tier": 2,
		"stats": {"hp": 24, "str": 8, "mag": 0, "def": 5, "res": 2, "spd": 5, "agi": 5},
	},
	{
		"id": "houndmaster_t2",
		"faction": "EdranorAndForest",
		"display_name": "Houndmaster",
		"class_key": "Beastmaster",
		"weapon_name": "Hunters Bow",
		"tier": 2,
		"stats": {"hp": 26, "str": 9, "mag": 0, "def": 4, "res": 2, "spd": 6, "agi": 6},
	},
	{
		"id": "axebark_raider_t2",
		"faction": "EdranorAndForest",
		"display_name": "Axebark Raider",
		"class_key": "Warrior",
		"weapon_name": "Steel Axe",
		"tier": 2,
		"stats": {"hp": 28, "str": 10, "mag": 0, "def": 5, "res": 2, "spd": 5, "agi": 5},
	},
	{
		"id": "road_warden_t2",
		"faction": "EdranorAndForest",
		"display_name": "Road Warden",
		"class_key": "Archer",
		"weapon_name": "Reinforced Bow",
		"tier": 2,
		"stats": {"hp": 22, "str": 8, "mag": 0, "def": 4, "res": 2, "spd": 6, "agi": 6},
	},
	{
		"id": "trapkeeper_t1",
		"faction": "EdranorAndForest",
		"display_name": "Trapkeeper",
		"class_key": "Thief",
		"weapon_name": "Scrap Knife",
		"tier": 1,
		"stats": {"hp": 20, "str": 7, "mag": 0, "def": 3, "res": 2, "spd": 7, "agi": 7},
	},
	{
		"id": "cliff_skirmisher_t2",
		"faction": "EdranorAndForest",
		"display_name": "Cliff Skirmisher",
		"class_key": "BowKnight",
		"weapon_name": "Longbow",
		"tier": 2,
		"stats": {"hp": 28, "str": 10, "mag": 0, "def": 5, "res": 3, "spd": 7, "agi": 7},
	},
	{
		"id": "totem_keeper_t2",
		"faction": "EdranorAndForest",
		"display_name": "Totem Keeper",
		"class_key": "Monk",
		"weapon_name": "Pilgrim's Knuckles",
		"tier": 2,
		"stats": {"hp": 24, "str": 8, "mag": 2, "def": 4, "res": 6, "spd": 5, "agi": 6},
	},
	{
		"id": "archive_warden_t2",
		"faction": "CollegeAndOrder",
		"display_name": "Archive Warden",
		"class_key": "Knight",
		"weapon_name": "Bronze Pike",
		"tier": 2,
		"stats": {"hp": 26, "str": 8, "mag": 0, "def": 7, "res": 3, "spd": 3, "agi": 4},
	},
	{
		"id": "scriptor_mage_t1",
		"faction": "CollegeAndOrder",
		"display_name": "Scriptor Mage",
		"class_key": "Mage",
		"weapon_name": "Apprentice Tome",
		"tier": 1,
		"stats": {"hp": 19, "str": 0, "mag": 8, "def": 2, "res": 5, "spd": 5, "agi": 6},
	},
	{
		"id": "barrier_adept_t1",
		"faction": "CollegeAndOrder",
		"display_name": "Barrier Adept",
		"class_key": "Cleric",
		"weapon_name": "Prism Tome",
		"tier": 1,
		"stats": {"hp": 20, "str": 0, "mag": 9, "def": 2, "res": 6, "spd": 4, "agi": 6},
	},
	{
		"id": "stair_duelist_t2",
		"faction": "CollegeAndOrder",
		"display_name": "Stair Duelist",
		"class_key": "Mercenary",
		"weapon_name": "Iron Sword",
		"tier": 2,
		"stats": {"hp": 24, "str": 8, "mag": 0, "def": 5, "res": 2, "spd": 6, "agi": 6},
	},
	{
		"id": "lamp_runner_t1",
		"faction": "CollegeAndOrder",
		"display_name": "Lamp Runner",
		"class_key": "Thief",
		"weapon_name": "Street Dirk",
		"tier": 1,
		"stats": {"hp": 18, "str": 6, "mag": 0, "def": 2, "res": 3, "spd": 7, "agi": 7},
	},
	{
		"id": "sealkeeper_t2",
		"faction": "CollegeAndOrder",
		"display_name": "Sealkeeper",
		"class_key": "DivineSage",
		"weapon_name": "Arcane Grimoire",
		"tier": 2,
		"stats": {"hp": 30, "str": 0, "mag": 11, "def": 4, "res": 8, "spd": 6, "agi": 7},
	},
	{
		"id": "oathshade_t3",
		"faction": "CollegeAndOrder",
		"display_name": "Oathshade",
		"class_key": "Hero",
		"weapon_name": "Silver Sword",
		"tier": 3,
		"stats": {"hp": 34, "str": 12, "mag": 0, "def": 8, "res": 5, "spd": 6, "agi": 7},
	},
	{
		"id": "dawn_sentinel_t3",
		"faction": "CollegeAndOrder",
		"display_name": "Dawn Sentinel",
		"class_key": "General",
		"weapon_name": "Holy Lance",
		"tier": 3,
		"stats": {"hp": 38, "str": 13, "mag": 0, "def": 12, "res": 6, "spd": 4, "agi": 5},
	},
	{
		"id": "trial_archer_t3",
		"faction": "CollegeAndOrder",
		"display_name": "Trial Archer",
		"class_key": "HeavyArcher",
		"weapon_name": "Longbow",
		"tier": 3,
		"stats": {"hp": 30, "str": 11, "mag": 0, "def": 7, "res": 4, "spd": 5, "agi": 6},
	},
	{
		"id": "chapel_echo_t2",
		"faction": "CollegeAndOrder",
		"display_name": "Chapel Echo",
		"class_key": "DivineSage",
		"weapon_name": "Celestial Tome",
		"tier": 2,
		"stats": {"hp": 28, "str": 0, "mag": 11, "def": 4, "res": 8, "spd": 5, "agi": 7},
	},
	{
		"id": "mirror_judge_t3",
		"faction": "CollegeAndOrder",
		"display_name": "Mirror Judge",
		"class_key": "BladeWeaver",
		"weapon_name": "Arcane Grimoire",
		"tier": 3,
		"stats": {"hp": 32, "str": 8, "mag": 10, "def": 6, "res": 7, "spd": 7, "agi": 8},
	},
	{
		"id": "tide_thrall_t2",
		"faction": "DarkTide",
		"display_name": "Tide Thrall",
		"class_key": "Monster",
		"weapon_name": "Rusty Sword",
		"tier": 2,
		"stats": {"hp": 26, "str": 9, "mag": 0, "def": 4, "res": 3, "spd": 5, "agi": 4},
	},
	{
		"id": "void_acolyte_t3",
		"faction": "DarkTide",
		"display_name": "Void Acolyte",
		"class_key": "Mage",
		"weapon_name": "Gloam Primer",
		"tier": 3,
		"stats": {"hp": 22, "str": 0, "mag": 10, "def": 2, "res": 6, "spd": 5, "agi": 6},
	},
	{
		"id": "abyss_lancer_t3",
		"faction": "DarkTide",
		"display_name": "Abyss Lancer",
		"class_key": "Paladin",
		"weapon_name": "Thunder Pike",
		"tier": 3,
		"stats": {"hp": 32, "str": 11, "mag": 2, "def": 8, "res": 5, "spd": 6, "agi": 6},
	},
	{
		"id": "null_choir_t3",
		"faction": "DarkTide",
		"display_name": "Null Choir",
		"class_key": "DivineSage",
		"weapon_name": "Dark Tide Grimoire",
		"tier": 3,
		"stats": {"hp": 30, "str": 0, "mag": 12, "def": 4, "res": 9, "spd": 5, "agi": 7},
	},
	{
		"id": "rift_stalker_t3",
		"faction": "DarkTide",
		"display_name": "Rift Stalker",
		"class_key": "Assassin",
		"weapon_name": "Sparkknife",
		"tier": 3,
		"stats": {"hp": 28, "str": 10, "mag": 0, "def": 4, "res": 4, "spd": 9, "agi": 9},
	},
	{
		"id": "anchor_guardian_t3",
		"faction": "DarkTide",
		"display_name": "Anchor Guardian",
		"class_key": "General",
		"weapon_name": "Thunder Pike",
		"tier": 3,
		"stats": {"hp": 40, "str": 14, "mag": 0, "def": 13, "res": 7, "spd": 4, "agi": 5},
	},
	{
		"id": "tendril_spawn_t3",
		"faction": "DarkTide",
		"display_name": "Tendril Spawn",
		"class_key": "Monster",
		"weapon_name": "Wrapped Cestus",
		"tier": 3,
		"stats": {"hp": 30, "str": 10, "mag": 0, "def": 5, "res": 4, "spd": 6, "agi": 5},
	},
	{
		"id": "unmade_horror_t4",
		"faction": "DarkTide",
		"display_name": "Unmade Horror",
		"class_key": "Dreadnought",
		"weapon_name": "Doom Hammer",
		"tier": 4,
		"stats": {"hp": 48, "str": 16, "mag": 4, "def": 12, "res": 9, "spd": 5, "agi": 6},
	},
	{
		"id": "glyph_breaker_t4",
		"faction": "DarkTide",
		"display_name": "Glyph Breaker",
		"class_key": "RiftArchon",
		"weapon_name": "Null Hymn",
		"tier": 4,
		"stats": {"hp": 42, "str": 6, "mag": 15, "def": 8, "res": 11, "spd": 8, "agi": 9},
	},
]

func _run() -> void:
	_ensure_dir(OUTPUT_BASE_DIR)
	var created := 0
	var updated := 0
	var failed := 0

	for cfg in ENEMIES:
		var faction_dir := OUTPUT_BASE_DIR.path_join(String(cfg.get("faction", "Misc")))
		_ensure_dir(faction_dir)
		var save_name := _build_save_name(cfg)
		var save_path := faction_dir.path_join(save_name + ".tres")
		var existed := ResourceLoader.exists(save_path)
		var unit_data = _build_unit_data(cfg)
		if unit_data == null:
			failed += 1
			continue
		var err := ResourceSaver.save(unit_data, save_path)
		if err != OK:
			push_error("Failed to save generic enemy resource: %s (err=%s)" % [save_path, str(err)])
			failed += 1
		else:
			if existed:
				updated += 1
				print("♻️ Updated: %s" % save_path)
			else:
				created += 1
				print("✅ Created: %s" % save_path)

	print("\n===== GENERIC ENEMY GENERATION COMPLETE =====")
	print("Created: %d | Updated: %d | Failed: %d" % [created, updated, failed])
	print("\n===== MAP ROSTERS =====")
	for map_name in MAP_ROSTERS.keys():
		print("%s -> %s" % [map_name, ", ".join(MAP_ROSTERS[map_name])])

func _build_save_name(cfg: Dictionary) -> String:
	var tier := int(cfg.get("tier", 1))
	var faction := _sanitize_token(String(cfg.get("faction", "Misc")))
	var name := _sanitize_token(String(cfg.get("display_name", "Enemy")))
	return "Generic_%s_%s_T%d" % [faction, name, tier]

func _build_unit_data(cfg: Dictionary):
	var data = UNIT_DATA_SCRIPT.new()
	data.display_name = String(cfg.get("display_name", "Enemy"))
	data.is_recruitable = false
	data.recruit_dialogue = _string_array([])
	data.pre_battle_quote = _string_array([])
	data.death_quotes = _string_array([])
	data.level_up_quotes = _string_array([])
	data.character_class = _load_class_resource(String(cfg.get("class_key", "")))
	data.starting_weapon = _load_weapon_resource(String(cfg.get("weapon_name", "")))
	data.ability = ""
	data.unit_sprite = null
	data.portrait = null
	data.visual_scale = 1.0
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
	var tier := int(cfg.get("tier", 1))
	var gold_range := _tier_gold_range(tier)
	data.min_gold_drop = gold_range.x
	data.max_gold_drop = gold_range.y
	data.drops_equipped_weapon = true
	data.equipped_weapon_chance = _tier_weapon_drop_chance(tier)
	return data

func _load_class_resource(class_key: String):
	var path := String(CLASS_PATHS.get(class_key, ""))
	if path == "":
		push_error("Missing class key in CLASS_PATHS: %s" % class_key)
		return null
	var res = _try_load(path)
	if res == null:
		push_error("Missing class resource for key %s -> %s" % [class_key, path])
	return res

func _load_weapon_resource(weapon_name: String):
	var path := String(WEAPON_PATHS.get(weapon_name, ""))
	if path == "":
		push_error("Missing weapon key in WEAPON_PATHS: %s" % weapon_name)
		return null
	var res = _try_load(path)
	if res == null:
		push_error("Missing weapon resource for key %s -> %s" % [weapon_name, path])
	return res

func _try_load(path: String):
	if path == "":
		return null
	if not ResourceLoader.exists(path):
		return null
	return load(path)

func _tier_gold_range(tier: int) -> Vector2i:
	match tier:
		1:
			return Vector2i(4, 8)
		2:
			return Vector2i(7, 12)
		3:
			return Vector2i(12, 18)
		4:
			return Vector2i(18, 26)
		_:
			return Vector2i(0, 0)

func _tier_weapon_drop_chance(tier: int) -> int:
	match tier:
		1:
			return 10
		2:
			return 14
		3:
			return 18
		4:
			return 22
		_:
			return 10

func _sanitize_token(value: String) -> String:
	var out := value.strip_edges()
	out = out.replace(" ", "")
	out = out.replace("-", "")
	out = out.replace(",", "")
	out = out.replace("'", "")
	out = out.replace(".", "")
	out = out.replace(":", "")
	return out

func _ensure_dir(res_dir: String) -> void:
	var abs_dir := ProjectSettings.globalize_path(res_dir.trim_suffix("/"))
	DirAccess.make_dir_recursive_absolute(abs_dir)

func _string_array(value) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for item in value:
			out.append(String(item))
	return out
