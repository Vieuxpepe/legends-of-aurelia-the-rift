@tool
extends EditorScript

const WeaponDataScript = preload("res://Resources/WeaponData.gd")

const SAVE_DIR: String = "res://Resources/GeneratedItems/"
const OVERWRITE_EXISTING: bool = true

const DMG_PHYSICAL: int = 0
const DMG_MAGIC: int = 1

const WT_SWORD: int = 0
const WT_LANCE: int = 1
const WT_AXE: int = 2
const WT_BOW: int = 3
const WT_TOME: int = 4
const WT_NONE: int = 5
const WT_KNIFE: int = 6
const WT_FIREARM: int = 7
const WT_FIST: int = 8
const WT_INSTRUMENT: int = 9
const WT_DARK_TOME: int = 10

func _run() -> void:
	_ensure_dir(SAVE_DIR)

	var weapon_list: Array = _build_weapon_list()
	var created: int = 0
	var skipped: int = 0

	for raw_entry in weapon_list:
		var entry: Dictionary = raw_entry
		var weapon_name: String = String(entry["weapon_name"])
		var file_path: String = SAVE_DIR + "Weapon_" + _slugify(weapon_name) + ".tres"

		if ResourceLoader.exists(file_path) and not OVERWRITE_EXISTING:
			print("⏭ Skipped existing weapon: " + weapon_name)
			skipped += 1
			continue

		var weapon = WeaponDataScript.new()
		weapon.weapon_name = weapon_name
		weapon.description = String(entry["description"])
		weapon.rarity = String(entry["rarity"])
		weapon.gold_cost = int(entry["gold_cost"])
		weapon.damage_type = int(entry["damage_type"])
		weapon.weapon_type = int(entry["weapon_type"])

		weapon.might = int(entry["might"])
		weapon.hit_bonus = int(entry["hit_bonus"])
		weapon.min_range = int(entry["min_range"])
		weapon.max_range = int(entry["max_range"])

		weapon.max_durability = int(entry["max_durability"])
		weapon.current_durability = int(entry["current_durability"])

		weapon.is_healing_staff = bool(entry["is_healing_staff"])
		weapon.is_buff_staff = bool(entry["is_buff_staff"])
		weapon.is_debuff_staff = bool(entry["is_debuff_staff"])
		weapon.affected_stat = String(entry["affected_stat"])
		weapon.effect_amount = int(entry["effect_amount"])

		if entry.has("required_arena_rank"):
			weapon.required_arena_rank = String(entry["required_arena_rank"])
		if entry.has("gladiator_token_cost"):
			weapon.gladiator_token_cost = int(entry["gladiator_token_cost"])

		var err: int = ResourceSaver.save(weapon, file_path)
		if err != OK:
			push_error("Failed to save weapon: " + weapon_name + " -> " + file_path)
		else:
			print("✅ Created weapon: " + weapon_name)
			created += 1

	print("🎉 Balanced armory generation complete! Created: " + str(created) + " | Skipped: " + str(skipped))


func _build_weapon_list() -> Array:
	var items: Array = []

	# =========================================================================
	# SWORDS — reliable, accurate, balanced
	# =========================================================================
	items.append(_physical_weapon("Iron Sword", WT_SWORD, "Common", 420, 4, 10, 1, 1, 42, "A dependable standard sword for disciplined frontliners."))
	items.append(_physical_weapon("Traveler's Blade", WT_SWORD, "Common", 520, 5, 8, 1, 1, 40, "A versatile early blade suited to long marches and uncertain roads."))
	items.append(_physical_weapon("Steel Sword", WT_SWORD, "Uncommon", 980, 7, 4, 1, 1, 34, "A heavier sword that rewards solid strength and timing."))
	items.append(_physical_weapon("Oathcutter", WT_SWORD, "Rare", 1850, 8, 7, 1, 1, 32, "A disciplined midgame blade built for duels and decisive cuts."))
	items.append(_physical_weapon("Sunsteel Brand", WT_SWORD, "Epic", 5200, 11, 8, 1, 1, 28, "A radiant warblade forged to hold against darkness."))
	items.append(_physical_weapon("Verdict Blade", WT_SWORD, "Legendary", 8600, 13, 10, 1, 1, 22, "A severe late-game sword said to strike like a sentence."))

	# =========================================================================
	# LANCES — reach, discipline, good might, moderate hit
	# =========================================================================
	items.append(_physical_weapon("Bronze Pike", WT_LANCE, "Common", 380, 4, 8, 1, 1, 42, "A simple pike for early recruits and militia lines."))
	items.append(_physical_weapon("Old Spear", WT_LANCE, "Common", 460, 5, 6, 1, 1, 40, "A worn but effective spear trusted by practical fighters."))
	items.append(_physical_weapon("Silver Lance", WT_LANCE, "Rare", 1900, 8, 5, 1, 1, 32, "A clean cavalry-grade lance with strong finishing power."))
	items.append(_physical_weapon("Knight's Halberd", WT_LANCE, "Rare", 2200, 9, 2, 1, 1, 30, "A heavier polearm meant to punish armored foes."))
	items.append(_physical_weapon("Blackened Lance", WT_LANCE, "Epic", 5400, 11, 4, 1, 1, 28, "A soot-dark lance steeped in ritual war."))
	items.append(_physical_weapon("Judgment Pike", WT_LANCE, "Legendary", 9000, 13, 6, 1, 2, 22, "A ceremonial execution pike with unnerving reach."))

	# =========================================================================
	# AXES — high might, lower hit, chunky identity
	# =========================================================================
	items.append(_physical_weapon("Bronze Axe", WT_AXE, "Common", 360, 5, 2, 1, 1, 42, "A crude but effective axe for bruisers and labor fighters."))
	items.append(_physical_weapon("Steel Axe", WT_AXE, "Uncommon", 920, 8, -2, 1, 1, 34, "A hard-hitting axe that asks for commitment."))
	items.append(_physical_weapon("War Axe", WT_AXE, "Rare", 1750, 9, -1, 1, 1, 30, "A serious battlefield axe for seasoned shock troops."))
	items.append(_physical_weapon("Raider's Splitter", WT_AXE, "Rare", 1950, 10, -3, 1, 1, 28, "A brutal midgame axe favored by ambushers and reavers."))
	items.append(_physical_weapon("Forgemaw Axe", WT_AXE, "Epic", 5100, 12, 0, 1, 1, 26, "A furnace-dark axe with ruinous bite."))
	items.append(_physical_weapon("Titan Breaker", WT_AXE, "Legendary", 9200, 15, -4, 1, 1, 18, "A monstrous endgame axe for ending arguments and walls."))

	# =========================================================================
	# BOWS — accurate, stable chip/control, modest might scaling
	# =========================================================================
	items.append(_physical_weapon("Crude Bow", WT_BOW, "Common", 340, 3, 12, 2, 2, 42, "A rough bow that still does its job if the hand is steady."))
	items.append(_physical_weapon("Ash Shortbow", WT_BOW, "Common", 420, 4, 14, 2, 2, 40, "A light early bow for skirmishing and pursuit."))
	items.append(_physical_weapon("Hunter's Bow", WT_BOW, "Uncommon", 860, 6, 10, 2, 2, 36, "A reliable field bow with clean handling."))
	items.append(_physical_weapon("Reinforced Bow", WT_BOW, "Rare", 1700, 8, 8, 2, 2, 32, "A strengthened bow for disciplined archers and heavy draws."))
	items.append(_physical_weapon("Longbow", WT_BOW, "Rare", 2200, 7, 5, 2, 3, 28, "Long reach at the cost of comfort and tempo."))
	items.append(_physical_weapon("Storm Bow", WT_BOW, "Epic", 5600, 10, 12, 2, 3, 24, "A high-end war bow that strikes like a breaking squall."))

	# =========================================================================
	# TOMES — accurate magic mainline, balanced power curve
	# =========================================================================
	items.append(_magic_weapon("Apprentice Tome", WT_TOME, "Common", 420, 4, 12, 1, 2, 40, "A simple practice tome for basic offensive casting."))
	items.append(_magic_weapon("Fire Tome", WT_TOME, "Common", 520, 5, 8, 1, 2, 38, "A straightforward fire text with reliable destructive force."))
	items.append(_magic_weapon("Arcane Grimoire", WT_TOME, "Uncommon", 980, 6, 10, 1, 2, 34, "A compact grimoire for educated battlefield mages."))
	items.append(_magic_weapon("Gale Lexicon", WT_TOME, "Rare", 1850, 8, 12, 1, 2, 30, "A tome of slicing winds and battlefield pressure."))
	items.append(_magic_weapon("Prism Tome", WT_TOME, "Epic", 4700, 10, 14, 1, 2, 26, "A refractive spellbook tuned for precise casting."))
	items.append(_magic_weapon("Starfire Codex", WT_TOME, "Legendary", 9000, 13, 16, 1, 2, 20, "A late-game codex burning with cold celestial fire."))

	# =========================================================================
	# DARK TOMES — higher damage ceiling, shakier handling, grim identity
	# =========================================================================
	items.append(_magic_weapon("Gloam Primer", WT_DARK_TOME, "Common", 500, 5, 6, 1, 2, 34, "A beginner's dark text that whispers more than it teaches."))
	items.append(_magic_weapon("Hexleaf Codex", WT_DARK_TOME, "Uncommon", 980, 6, 8, 1, 2, 32, "A compact grimoire of spite, ash, and petty malediction."))
	items.append(_magic_weapon("Grave Thesis", WT_DARK_TOME, "Rare", 2200, 9, 6, 1, 2, 28, "A necromantic dissertation compiled with horrifying precision."))
	items.append(_magic_weapon("Rift Rite Tome", WT_DARK_TOME, "Epic", 5200, 11, 8, 1, 2, 24, "A ritual text that resents geometry and stable reality."))
	items.append(_magic_weapon("Dark Tide Grimoire", WT_DARK_TOME, "Legendary", 8800, 13, 10, 1, 2, 20, "A void-soaked liturgy dragged up from below the world."))
	items.append(_magic_weapon("Null Hymn", WT_DARK_TOME, "Legendary", 9800, 14, 12, 2, 3, 16, "An endgame text that sings absence into the battlefield."))

	# =========================================================================
	# KNIVES — low might, high hit, light pressure, some 1-2 utility
	# =========================================================================
	items.append(_physical_weapon("Street Dirk", WT_KNIFE, "Common", 360, 3, 18, 1, 1, 42, "A quick dirty blade built for alleys, panic, and survival."))
	items.append(_physical_weapon("Scrap Knife", WT_KNIFE, "Common", 300, 2, 20, 1, 1, 44, "A scavenged knife with ugly balance and ugly purpose."))
	items.append(_physical_weapon("Sparkknife", WT_KNIFE, "Uncommon", 1100, 5, 14, 1, 2, 34, "A volatile blade etched with unstable charge and trick reach."))
	items.append(_physical_weapon("Bellhook Knife", WT_KNIFE, "Rare", 1950, 7, 16, 1, 2, 28, "A hooked knife ideal for harrying and finishing exposed targets."))
	items.append(_physical_weapon("Shadowglass Knives", WT_KNIFE, "Legendary", 7600, 10, 22, 1, 2, 18, "Twin void-dark knives that vanish into motion before the eye can follow."))

	# =========================================================================
	# FIREARMS — strong might, shaky hit, mostly 2-range, low durability
	# =========================================================================
	items.append(_physical_weapon("Militia Handgonne", WT_FIREARM, "Common", 480, 6, 0, 2, 2, 28, "A crude firearm with poor handling but real stopping power."))
	items.append(_physical_weapon("Rustlock Pistol", WT_FIREARM, "Uncommon", 980, 7, 2, 2, 2, 26, "A battered sidearm trusted by smugglers and desperate guards."))
	items.append(_physical_weapon("Ramshackle Culverin", WT_FIREARM, "Rare", 2200, 10, -2, 2, 3, 20, "A jury-rigged siege tube that hits hard and rattles the user."))
	items.append(_physical_weapon("Broker's Handgonne", WT_FIREARM, "Epic", 4700, 11, 4, 2, 2, 22, "A polished underworld firearm bought with leverage and blood."))
	items.append(_physical_weapon("Siege Repeater", WT_FIREARM, "Legendary", 8900, 13, 2, 2, 3, 16, "A brutal late-game repeating firearm for disciplined demolition."))

	# =========================================================================
	# FISTS — accurate, close-range, tempo-focused bruiser tools
	# =========================================================================
	items.append(_physical_weapon("Pilgrim's Knuckles", WT_FIST, "Common", 390, 4, 14, 1, 1, 40, "Simple knuckle irons used by wandering monks and zealots."))
	items.append(_physical_weapon("Wrapped Cestus", WT_FIST, "Common", 420, 5, 12, 1, 1, 38, "A leather-and-metal fist weapon for disciplined close combat."))
	items.append(_physical_weapon("Ironbound Cestus", WT_FIST, "Rare", 1600, 7, 10, 1, 1, 32, "A heavier striking set for trained brawlers and war monks."))
	items.append(_physical_weapon("Temple Gauntlets", WT_FIST, "Rare", 1950, 8, 8, 1, 1, 30, "Consecrated gauntlets that reward relentless forward pressure."))
	items.append(_physical_weapon("Meteor Knuckles", WT_FIST, "Legendary", 8200, 11, 12, 1, 1, 20, "Late-game fist weapons that hit like falling stone."))

	# =========================================================================
	# INSTRUMENTS — lower raw damage, high accuracy, support-flavored offense
	# =========================================================================
	items.append(_magic_weapon("Silken Fan", WT_INSTRUMENT, "Common", 520, 3, 16, 1, 2, 40, "A graceful performance fan that turns movement into cutting force."))
	items.append(_magic_weapon("Festival Bell", WT_INSTRUMENT, "Common", 650, 4, 14, 1, 2, 38, "A bright little instrument whose chime unsettles enemy rhythm."))
	items.append(_magic_weapon("Court Lute", WT_INSTRUMENT, "Rare", 1750, 6, 16, 1, 2, 32, "A refined instrument whose notes bite deeper than they should."))
	items.append(_magic_weapon("Veil Tambour", WT_INSTRUMENT, "Rare", 2100, 7, 12, 1, 2, 30, "A dancer's battle instrument tuned to tempo and misdirection."))
	items.append(_magic_weapon("Dawn Harp", WT_INSTRUMENT, "Legendary", 8700, 9, 20, 1, 2, 20, "A transcendent harp whose resonance feels almost holy."))

	# =========================================================================
	# STAVES — utility-first; not damage tools
	# =========================================================================
	items.append(_staff_weapon("Heal Staff", "Common", 520, 2, 40, true, false, false, "magic", 8, "A basic healing staff for early sustain and stability."))
	items.append(_staff_weapon("Protect Staff", "Uncommon", 1100, 2, 34, false, true, false, "defense", 3, "A support staff that hardens an ally's footing."))
	items.append(_staff_weapon("Censure Staff", "Uncommon", 1400, 2, 34, false, false, true, "defense", 4, "A severe debuff staff used to weaken enemy fronts."))
	items.append(_staff_weapon("Silence Staff", "Rare", 2600, 3, 28, false, false, true, "magic", 5, "A muting staff that blunts hostile spellcasters."))
	items.append(_staff_weapon("Edict Staff", "Epic", 5200, 3, 24, false, true, false, "defense", 5, "A command staff that hardens allies under strict authority."))
	items.append(_staff_weapon("Chain-Key Staff", "Legendary", 8600, 3, 20, false, true, true, "speed", 6, "A relic staff that binds enemies or restores allied tempo."))

	return items


func _physical_weapon(
	weapon_name: String,
	weapon_type: int,
	rarity: String,
	gold_cost: int,
	might: int,
	hit_bonus: int,
	min_range: int,
	max_range: int,
	durability: int,
	description: String
) -> Dictionary:
	return {
		"weapon_name": weapon_name,
		"description": description,
		"rarity": rarity,
		"gold_cost": gold_cost,
		"damage_type": DMG_PHYSICAL,
		"weapon_type": weapon_type,
		"might": might,
		"hit_bonus": hit_bonus,
		"min_range": min_range,
		"max_range": max_range,
		"max_durability": durability,
		"current_durability": durability,
		"is_healing_staff": false,
		"is_buff_staff": false,
		"is_debuff_staff": false,
		"affected_stat": "strength",
		"effect_amount": 0,
		"required_arena_rank": "Bronze",
		"gladiator_token_cost": 0
	}


func _magic_weapon(
	weapon_name: String,
	weapon_type: int,
	rarity: String,
	gold_cost: int,
	might: int,
	hit_bonus: int,
	min_range: int,
	max_range: int,
	durability: int,
	description: String
) -> Dictionary:
	return {
		"weapon_name": weapon_name,
		"description": description,
		"rarity": rarity,
		"gold_cost": gold_cost,
		"damage_type": DMG_MAGIC,
		"weapon_type": weapon_type,
		"might": might,
		"hit_bonus": hit_bonus,
		"min_range": min_range,
		"max_range": max_range,
		"max_durability": durability,
		"current_durability": durability,
		"is_healing_staff": false,
		"is_buff_staff": false,
		"is_debuff_staff": false,
		"affected_stat": "magic",
		"effect_amount": 0,
		"required_arena_rank": "Bronze",
		"gladiator_token_cost": 0
	}


func _staff_weapon(
	weapon_name: String,
	rarity: String,
	gold_cost: int,
	max_range: int,
	durability: int,
	is_healing_staff: bool,
	is_buff_staff: bool,
	is_debuff_staff: bool,
	affected_stat: String,
	effect_amount: int,
	description: String
) -> Dictionary:
	return {
		"weapon_name": weapon_name,
		"description": description,
		"rarity": rarity,
		"gold_cost": gold_cost,
		"damage_type": DMG_MAGIC,
		"weapon_type": WT_TOME,
		"might": 0,
		"hit_bonus": 18,
		"min_range": 1,
		"max_range": max_range,
		"max_durability": durability,
		"current_durability": durability,
		"is_healing_staff": is_healing_staff,
		"is_buff_staff": is_buff_staff,
		"is_debuff_staff": is_debuff_staff,
		"affected_stat": affected_stat,
		"effect_amount": effect_amount,
		"required_arena_rank": "Bronze",
		"gladiator_token_cost": 0
	}


func _slugify(raw_name: String) -> String:
	var out: String = raw_name.strip_edges()
	out = out.replace("'", "")
	out = out.replace("-", "_")
	out = out.replace(" ", "_")
	out = out.replace(",", "")
	out = out.replace(".", "")
	return out


func _ensure_dir(res_dir: String) -> void:
	var abs_dir: String = ProjectSettings.globalize_path(res_dir.trim_suffix("/"))
	DirAccess.make_dir_recursive_absolute(abs_dir)
