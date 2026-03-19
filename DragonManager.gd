extends Node

enum DragonStage { EGG, BABY, JUVENILE, ADULT }

var player_dragons: Array[Dictionary] = []

const DRAGON_ELEMENTS: Array[String] = ["Fire", "Ice", "Lightning", "Earth", "Wind"]



# A pool of passives they can spawn with!
const WILD_TRAITS: Array[String] = [
	"Thick Scales",
	"Fierce",
	"Swift",
	"Cunning",
	"Loyal",
	"Vicious",
	"Magic Blooded",
	"Regenerative",
	"Guardian",
	"Keen Hunter",
	"Sky Dancer",
	"Runebound",
	"Stormchaser",
	"Flameheart",
	"Frostborn",
	"Burrower",
	"Gentle Soul",
	"Voracious",
	"Dominant"
]

const TIER_2_TRAIT_MAP: Dictionary = {
	"Thick Scales": "Adamant Hide",
	"Fierce": "Savage",
	"Swift": "Lightning Reflexes",
	"Cunning": "Mastermind",
	"Loyal": "Heartbound",
	"Vicious": "Blood Frenzy",
	"Magic Blooded": "Elder Arcana",
	"Regenerative": "Everlasting",
	"Guardian": "Warden",
	"Keen Hunter": "Apex Hunter",
	"Sky Dancer": "Zephyr Lord",
	"Runebound": "Starbound",
	"Stormchaser": "Tempest Born",
	"Flameheart": "Infernal Core",
	"Frostborn": "Permafrost Heart",
	"Burrower": "Worldshaper",
	"Gentle Soul": "Soulkeeper",
	"Voracious": "Endless Maw",
	"Dominant": "Tyrant"
}

const ELEMENT_TRAIT_WEIGHTS: Dictionary = {
	"Fire": {
		"Fierce": 5.0,
		"Vicious": 4.0,
		"Flameheart": 6.0,
		"Dominant": 4.0,
		"Voracious": 2.0
	},
	"Ice": {
		"Thick Scales": 4.0,
		"Frostborn": 6.0,
		"Guardian": 4.0,
		"Regenerative": 2.0,
		"Gentle Soul": 2.0
	},
	"Lightning": {
		"Swift": 5.0,
		"Stormchaser": 6.0,
		"Keen Hunter": 4.0,
		"Cunning": 2.0
	},
	"Earth": {
		"Burrower": 6.0,
		"Guardian": 4.0,
		"Regenerative": 4.0,
		"Thick Scales": 3.0
	},
	"Wind": {
		"Sky Dancer": 6.0,
		"Swift": 4.0,
		"Cunning": 3.0,
		"Keen Hunter": 3.0,
		"Gentle Soul": 2.0
	}
}

const TRAIT_DEFS: Dictionary = {
	# -------------------------
	# TIER 1
	# -------------------------
	"Thick Scales": {
		"tier": 1,
		"family": "body",
		"rarity": "common",
		"birth": {"defense": 1, "resistance": 1},
		"growth": {"def": 12, "res": 8},
		"ranch": {"pet_comfort": -5}
	},
	"Fierce": {
		"tier": 1,
		"family": "instinct",
		"rarity": "common",
		"birth": {"strength": 1},
		"growth": {"str": 10},
		"ranch": {"pet_comfort": -12, "hunt_bonus": 3}
	},
	"Swift": {
		"tier": 1,
		"family": "mobility",
		"rarity": "common",
		"birth": {"speed": 1, "agility": 1},
		"growth": {"spd": 10, "agi": 10},
		"ranch": {"pet_comfort": 6, "hunt_bonus": 4}
	},
	"Cunning": {
		"tier": 1,
		"family": "instinct",
		"rarity": "common",
		"birth": {"magic": 1, "agility": 1},
		"growth": {"mag": 8, "agi": 6},
		"ranch": {"pet_comfort": 4, "hunt_bonus": 2}
	},
	"Loyal": {
		"tier": 1,
		"family": "temperament",
		"rarity": "common",
		"birth": {"max_hp": 2},
		"growth": {"hp": 8, "def": 4, "res": 4},
		"ranch": {"pet_comfort": 20, "bond_gain_bonus": 1}
	},
	"Vicious": {
		"tier": 1,
		"family": "instinct",
		"rarity": "common",
		"birth": {"strength": 1, "max_hp": 2},
		"growth": {"str": 8, "hp": 8},
		"ranch": {"pet_comfort": -22, "hunt_bonus": 5}
	},
	"Magic Blooded": {
		"tier": 1,
		"family": "arcane",
		"rarity": "rare",
		"birth": {"magic": 1, "resistance": 1},
		"growth": {"mag": 15, "res": 8},
		"ranch": {"pet_comfort": 10}
	},
	"Regenerative": {
		"tier": 1,
		"family": "body",
		"rarity": "rare",
		"birth": {"max_hp": 2, "resistance": 1},
		"growth": {"hp": 10, "res": 4}
	},
	"Guardian": {
		"tier": 1,
		"family": "temperament",
		"rarity": "rare",
		"birth": {"defense": 1, "max_hp": 2},
		"growth": {"hp": 6, "def": 10, "res": 4},
		"ranch": {"pet_comfort": 8}
	},
	"Keen Hunter": {
		"tier": 1,
		"family": "instinct",
		"rarity": "common",
		"birth": {"speed": 1, "agility": 1},
		"growth": {"spd": 8, "agi": 12},
		"ranch": {"hunt_bonus": 3}
	},
	"Sky Dancer": {
		"tier": 1,
		"family": "mobility",
		"rarity": "rare",
		"birth": {"agility": 1, "move_range": 1},
		"growth": {"spd": 6, "agi": 12}
	},
	"Runebound": {
		"tier": 1,
		"family": "arcane",
		"rarity": "rare",
		"birth": {"magic": 2},
		"growth": {"mag": 12, "res": 6}
	},
	"Stormchaser": {
		"tier": 1,
		"family": "mobility",
		"rarity": "rare",
		"birth": {"speed": 1, "magic": 1},
		"growth": {"spd": 10, "agi": 6, "mag": 6}
	},
	"Flameheart": {
		"tier": 1,
		"family": "instinct",
		"rarity": "rare",
		"birth": {"strength": 1, "resistance": 1},
		"growth": {"str": 10, "hp": 4, "res": 4},
		"ranch": {"hunt_bonus": 2, "pet_comfort": -4}
	},
	"Frostborn": {
		"tier": 1,
		"family": "body",
		"rarity": "rare",
		"birth": {"defense": 1, "resistance": 1},
		"growth": {"def": 8, "res": 10}
	},
	"Burrower": {
		"tier": 1,
		"family": "body",
		"rarity": "rare",
		"birth": {"defense": 2},
		"growth": {"def": 12, "hp": 4}
	},
	"Gentle Soul": {
		"tier": 1,
		"family": "temperament",
		"rarity": "rare",
		"birth": {"resistance": 1},
		"growth": {"hp": 6, "res": 8},
		"ranch": {"pet_comfort": 18, "bond_gain_bonus": 1, "happiness_gain_bonus": 1}
	},
	"Voracious": {
		"tier": 1,
		"family": "temperament",
		"rarity": "rare",
		"birth": {"max_hp": 1, "strength": 1},
		"growth": {"hp": 8, "str": 6},
		"ranch": {"feed_growth_bonus_pct": 10}
	},
	"Dominant": {
		"tier": 1,
		"family": "instinct",
		"rarity": "rare",
		"birth": {"strength": 1, "speed": 1},
		"growth": {"str": 12, "spd": 6},
		"ranch": {"pet_comfort": -10}
	},

	# -------------------------
	# TIER 2
	# -------------------------
	"Adamant Hide": {
		"tier": 2,
		"family": "body",
		"rarity": "epic",
		"birth": {"defense": 2, "resistance": 2, "max_hp": 4},
		"growth": {"hp": 12, "def": 20, "res": 12}
	},
	"Savage": {
		"tier": 2,
		"family": "instinct",
		"rarity": "epic",
		"birth": {"strength": 2, "max_hp": 3},
		"growth": {"hp": 10, "str": 18}
	},
	"Lightning Reflexes": {
		"tier": 2,
		"family": "mobility",
		"rarity": "epic",
		"birth": {"speed": 2, "agility": 2},
		"growth": {"spd": 18, "agi": 18}
	},
	"Mastermind": {
		"tier": 2,
		"family": "arcane",
		"rarity": "epic",
		"birth": {"magic": 2, "agility": 2},
		"growth": {"mag": 14, "spd": 6, "agi": 10}
	},
	"Heartbound": {
		"tier": 2,
		"family": "temperament",
		"rarity": "epic",
		"birth": {"max_hp": 5, "defense": 1, "resistance": 1},
		"growth": {"hp": 14, "def": 8, "res": 8},
		"ranch": {"pet_comfort": 24, "bond_gain_bonus": 1}
	},
	"Blood Frenzy": {
		"tier": 2,
		"family": "instinct",
		"rarity": "epic",
		"birth": {"strength": 2, "speed": 1, "max_hp": 3},
		"growth": {"hp": 10, "str": 16, "spd": 6},
		"ranch": {"pet_comfort": -28, "hunt_bonus": 6}
	},
	"Elder Arcana": {
		"tier": 2,
		"family": "arcane",
		"rarity": "epic",
		"birth": {"magic": 3, "resistance": 2},
		"growth": {"mag": 22, "res": 12}
	},
	"Everlasting": {
		"tier": 2,
		"family": "body",
		"rarity": "epic",
		"birth": {"max_hp": 5, "resistance": 2},
		"growth": {"hp": 16, "res": 8}
	},
	"Warden": {
		"tier": 2,
		"family": "temperament",
		"rarity": "epic",
		"birth": {"max_hp": 4, "defense": 2, "resistance": 1},
		"growth": {"hp": 10, "def": 14, "res": 8}
	},
	"Apex Hunter": {
		"tier": 2,
		"family": "instinct",
		"rarity": "epic",
		"birth": {"speed": 2, "agility": 2, "strength": 1},
		"growth": {"str": 8, "spd": 14, "agi": 16},
		"ranch": {"hunt_bonus": 6}
	},
	"Zephyr Lord": {
		"tier": 2,
		"family": "mobility",
		"rarity": "epic",
		"birth": {"move_range": 1, "speed": 1, "agility": 2},
		"growth": {"spd": 10, "agi": 16}
	},
	"Starbound": {
		"tier": 2,
		"family": "arcane",
		"rarity": "epic",
		"birth": {"magic": 3, "resistance": 1},
		"growth": {"mag": 18, "res": 10}
	},
	"Tempest Born": {
		"tier": 2,
		"family": "mobility",
		"rarity": "epic",
		"birth": {"speed": 2, "agility": 1, "magic": 1},
		"growth": {"spd": 14, "agi": 10, "mag": 8}
	},
	"Infernal Core": {
		"tier": 2,
		"family": "instinct",
		"rarity": "epic",
		"birth": {"strength": 2, "resistance": 2},
		"growth": {"str": 16, "hp": 8, "res": 6}
	},
	"Permafrost Heart": {
		"tier": 2,
		"family": "body",
		"rarity": "epic",
		"birth": {"defense": 2, "resistance": 2},
		"growth": {"def": 12, "res": 14}
	},
	"Worldshaper": {
		"tier": 2,
		"family": "body",
		"rarity": "epic",
		"birth": {"defense": 3, "max_hp": 3},
		"growth": {"hp": 10, "def": 16}
	},
	"Soulkeeper": {
		"tier": 2,
		"family": "temperament",
		"rarity": "epic",
		"birth": {"resistance": 2, "max_hp": 3},
		"growth": {"hp": 10, "res": 12, "def": 6},
		"ranch": {"pet_comfort": 24, "bond_gain_bonus": 1, "happiness_gain_bonus": 1}
	},
	"Endless Maw": {
		"tier": 2,
		"family": "temperament",
		"rarity": "epic",
		"birth": {"max_hp": 3, "strength": 2},
		"growth": {"hp": 12, "str": 10},
		"ranch": {"feed_growth_bonus_pct": 20}
	},
	"Tyrant": {
		"tier": 2,
		"family": "instinct",
		"rarity": "epic",
		"birth": {"strength": 2, "speed": 1, "max_hp": 2},
		"growth": {"str": 18, "spd": 8},
		"ranch": {"pet_comfort": -16, "hunt_bonus": 4}
	}
}

const BREED_REQUIRED_ITEM_NAME: String = "Dragon Rose"
const BREED_COOLDOWN_TURNS: int = 1
const BREED_MAX_TRAITS: int = 3

const GEN_BIRTH_HP_BONUS_PER_STEP: int = 2
const GEN_BIRTH_MINOR_BONUS_PER_STEP: int = 1

const GEN_GROWTH_BONUS_PER_STEP: int = 4
const GEN_GROWTH_BONUS_CAP: int = 36

const EGG_QUALITY_COMMON: String = "Common"
const EGG_QUALITY_RARE: String = "Rare"
const EGG_QUALITY_EPIC: String = "Epic"
const EGG_QUALITY_LEGENDARY: String = "Legendary"

var unhatched_eggs: Array = []

# ---------------------------------------------------------
# DRAGON TRAINING SYSTEM
# ---------------------------------------------------------
const TRAINING_INTENSITY_LIGHT: int = 0
const TRAINING_INTENSITY_NORMAL: int = 1
const TRAINING_INTENSITY_INTENSE: int = 2

const DRAGON_TRAINING_ORDER: Array[String] = [
	"endurance",
	"power",
	"arcana",
	"guard",
	"resistance",
	"speed",
	"agility",
	"balanced"
]

const DRAGON_TRAINING_PROGRAMS: Dictionary = {
	"endurance": {
		"display_name": "Endurance Drill",
		"gold_cost": 120,
		"happiness_loss": 6,
		"fatigue_gain": 12,
		"stat_weights": {
			"max_hp": 6.0,
			"defense": 2.0,
			"resistance": 2.0
		}
	},
	"power": {
		"display_name": "Power Sparring",
		"gold_cost": 140,
		"happiness_loss": 7,
		"fatigue_gain": 13,
		"stat_weights": {
			"strength": 7.0,
			"max_hp": 2.0,
			"speed": 1.0
		}
	},
	"arcana": {
		"display_name": "Arcane Study",
		"gold_cost": 150,
		"happiness_loss": 6,
		"fatigue_gain": 11,
		"stat_weights": {
			"magic": 7.0,
			"resistance": 2.0,
			"agility": 1.0
		}
	},
	"guard": {
		"display_name": "Guard Formation",
		"gold_cost": 130,
		"happiness_loss": 6,
		"fatigue_gain": 12,
		"stat_weights": {
			"defense": 7.0,
			"max_hp": 2.0,
			"resistance": 1.0
		}
	},
	"resistance": {
		"display_name": "Meditative Ward",
		"gold_cost": 130,
		"happiness_loss": 5,
		"fatigue_gain": 10,
		"stat_weights": {
			"resistance": 7.0,
			"magic": 2.0,
			"defense": 1.0
		}
	},
	"speed": {
		"display_name": "Wind Sprint",
		"gold_cost": 135,
		"happiness_loss": 7,
		"fatigue_gain": 13,
		"stat_weights": {
			"speed": 7.0,
			"agility": 2.0,
			"max_hp": 1.0
		}
	},
	"agility": {
		"display_name": "Sky Reflex Course",
		"gold_cost": 135,
		"happiness_loss": 7,
		"fatigue_gain": 13,
		"stat_weights": {
			"agility": 7.0,
			"speed": 2.0,
			"magic": 1.0
		}
	},
	"balanced": {
		"display_name": "Balanced Training",
		"gold_cost": 125,
		"happiness_loss": 5,
		"fatigue_gain": 10,
		"stat_weights": {
			"max_hp": 1.0,
			"strength": 1.0,
			"magic": 1.0,
			"defense": 1.0,
			"resistance": 1.0,
			"speed": 1.0,
			"agility": 1.0
		}
	}
}

func _ready() -> void:
	_normalize_training_fields_for_all_dragons()

func _normalize_training_fields_for_all_dragons() -> void:
	for dragon in player_dragons:
		_ensure_dragon_training_fields(dragon)

	for egg_record in unhatched_eggs:
		if typeof(egg_record) != TYPE_DICTIONARY:
			continue

		var baby_data_variant = egg_record.get("baby_data", {})
		if typeof(baby_data_variant) != TYPE_DICTIONARY:
			continue

		var baby_data: Dictionary = baby_data_variant
		if not baby_data.is_empty():
			_ensure_dragon_training_fields(baby_data)

func _ensure_dragon_training_fields(dragon: Dictionary) -> void:
	if not dragon.has("happiness"):
		dragon["happiness"] = 55
	if not dragon.has("bond"):
		dragon["bond"] = 0
	if not dragon.has("mood"):
		dragon["mood"] = "Curious"
	if not dragon.has("fatigue"):
		dragon["fatigue"] = 0
	if not dragon.has("training_sessions"):
		dragon["training_sessions"] = 0
	if not dragon.has("last_training_time"):
		dragon["last_training_time"] = 0

func get_training_program(program_id: String) -> Dictionary:
	if not DRAGON_TRAINING_PROGRAMS.has(program_id):
		return {}

	var program: Dictionary = DRAGON_TRAINING_PROGRAMS[program_id].duplicate(true)
	program["id"] = program_id
	return program

func get_training_program_list() -> Array[Dictionary]:
	var programs: Array[Dictionary] = []

	for program_id in DRAGON_TRAINING_ORDER:
		if DRAGON_TRAINING_PROGRAMS.has(program_id):
			var program: Dictionary = DRAGON_TRAINING_PROGRAMS[program_id].duplicate(true)
			program["id"] = program_id
			programs.append(program)

	return programs

func get_training_preview(index: int, program_id: String, intensity: int = TRAINING_INTENSITY_NORMAL) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"error": "",
		"program_id": program_id,
		"program_name": "",
		"gold_cost": 0,
		"happiness_loss": 0,
		"fatigue_gain": 0,
		"possible_stats": [],
		"dragon_name": ""
	}

	if index < 0 or index >= player_dragons.size():
		result["error"] = "Invalid dragon index."
		return result

	var dragon: Dictionary = player_dragons[index]
	_ensure_dragon_training_fields(dragon)

	var program: Dictionary = get_training_program(program_id)
	if program.is_empty():
		result["error"] = "Training program not found."
		return result

	intensity = clampi(intensity, TRAINING_INTENSITY_LIGHT, TRAINING_INTENSITY_INTENSE)

	result["dragon_name"] = str(dragon.get("name", "Dragon"))
	result["program_name"] = str(program.get("display_name", "Training"))
	result["gold_cost"] = _get_training_gold_cost(program, intensity)
	result["happiness_loss"] = _get_training_happiness_loss(program, intensity)
	result["fatigue_gain"] = _get_training_fatigue_gain(program, intensity)
	result["possible_stats"] = program.get("stat_weights", {}).keys()

	var fatigue: int = int(dragon.get("fatigue", 0))
	var happiness: int = int(dragon.get("happiness", 50))
	var current_gold: int = int(CampaignManager.global_gold)

	if int(dragon.get("stage", DragonStage.BABY)) == DragonStage.EGG:
		result["error"] = "Eggs cannot train."
		return result

	if fatigue >= 95:
		result["error"] = "This dragon is too exhausted to train."
		return result

	if intensity == TRAINING_INTENSITY_INTENSE and fatigue >= 70:
		result["error"] = "This dragon is too fatigued for intense training."
		return result

	if intensity == TRAINING_INTENSITY_NORMAL and fatigue >= 85:
		result["error"] = "This dragon is too fatigued for normal training."
		return result

	var minimum_happiness: int = 10
	if intensity == TRAINING_INTENSITY_NORMAL:
		minimum_happiness = 15
	elif intensity == TRAINING_INTENSITY_INTENSE:
		minimum_happiness = 25

	if happiness < minimum_happiness:
		result["error"] = "This dragon is too unhappy to train at that intensity."
		return result

	if current_gold < int(result["gold_cost"]):
		result["error"] = "Not enough gold."
		return result

	result["ok"] = true
	return result

func train_dragon(index: int, program_id: String, intensity: int = TRAINING_INTENSITY_NORMAL) -> Dictionary:
	var preview: Dictionary = get_training_preview(index, program_id, intensity)

	var result: Dictionary = {
		"ok": false,
		"error": "",
		"dragon_name": "",
		"program_name": "",
		"gold_spent": 0,
		"happiness_before": 0,
		"happiness_after": 0,
		"happiness_delta": 0,
		"fatigue_before": 0,
		"fatigue_after": 0,
		"fatigue_delta": 0,
		"stat_gains": {},
		"breakthrough": false,
		"bond": 0,
		"mood": ""
	}

	if not bool(preview.get("ok", false)):
		result["error"] = str(preview.get("error", "Training failed."))
		return result

	var dragon: Dictionary = player_dragons[index]
	_ensure_dragon_training_fields(dragon)

	var program: Dictionary = get_training_program(program_id)
	intensity = clampi(intensity, TRAINING_INTENSITY_LIGHT, TRAINING_INTENSITY_INTENSE)

	var gold_cost: int = int(preview.get("gold_cost", 0))
	var happiness_loss: int = int(preview.get("happiness_loss", 0))
	var fatigue_gain: int = int(preview.get("fatigue_gain", 0))

	result["dragon_name"] = str(dragon.get("name", "Dragon"))
	result["program_name"] = str(program.get("display_name", "Training"))
	result["gold_spent"] = gold_cost

	var happiness_before: int = int(dragon.get("happiness", 50))
	var fatigue_before: int = int(dragon.get("fatigue", 0))

	result["happiness_before"] = happiness_before
	result["fatigue_before"] = fatigue_before

	CampaignManager.global_gold = int(CampaignManager.global_gold) - gold_cost

	dragon["happiness"] = clampi(happiness_before - happiness_loss, 0, 100)
	dragon["fatigue"] = clampi(fatigue_before + fatigue_gain, 0, 100)
	dragon["training_sessions"] = int(dragon.get("training_sessions", 0)) + 1
	dragon["last_training_time"] = int(Time.get_unix_time_from_system())

	var stat_gains: Dictionary = {}
	var roll_count: int = _get_training_roll_count(intensity)
	var stat_weights: Dictionary = program.get("stat_weights", {})

	for i in range(roll_count):
		var stat_key: String = _roll_weighted_training_stat(stat_weights)
		if stat_key == "":
			continue

		var amount: int = 1
		_apply_training_stat_gain(dragon, stat_key, amount)
		stat_gains[stat_key] = int(stat_gains.get(stat_key, 0)) + amount

	var breakthrough_chance: float = _get_training_breakthrough_chance(dragon, intensity)
	if randf() < breakthrough_chance:
		var bonus_stat: String = _roll_weighted_training_stat(stat_weights)
		if bonus_stat != "":
			_apply_training_stat_gain(dragon, bonus_stat, 1)
			stat_gains[bonus_stat] = int(stat_gains.get(bonus_stat, 0)) + 1
			result["breakthrough"] = true

	_refresh_dragon_mood(dragon)

	result["ok"] = true
	result["stat_gains"] = stat_gains
	result["happiness_after"] = int(dragon.get("happiness", 0))
	result["fatigue_after"] = int(dragon.get("fatigue", 0))
	result["happiness_delta"] = int(dragon.get("happiness", 0)) - happiness_before
	result["fatigue_delta"] = int(dragon.get("fatigue", 0)) - fatigue_before
	result["bond"] = int(dragon.get("bond", 0))
	result["mood"] = str(dragon.get("mood", "Curious"))

	return result

func rest_dragon(index: int, amount: int = 25) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"error": "",
		"fatigue_before": 0,
		"fatigue_after": 0,
		"happiness_before": 0,
		"happiness_after": 0,
		"mood": ""
	}

	if index < 0 or index >= player_dragons.size():
		result["error"] = "Invalid dragon index."
		return result

	var dragon: Dictionary = player_dragons[index]
	_ensure_dragon_training_fields(dragon)

	var fatigue_before: int = int(dragon.get("fatigue", 0))
	var happiness_before: int = int(dragon.get("happiness", 50))

	dragon["fatigue"] = clampi(fatigue_before - amount, 0, 100)
	dragon["happiness"] = clampi(happiness_before + 2, 0, 100)

	_refresh_dragon_mood(dragon)

	result["ok"] = true
	result["fatigue_before"] = fatigue_before
	result["fatigue_after"] = int(dragon.get("fatigue", 0))
	result["happiness_before"] = happiness_before
	result["happiness_after"] = int(dragon.get("happiness", 0))
	result["mood"] = str(dragon.get("mood", "Curious"))
	return result

func _get_training_gold_cost(program: Dictionary, intensity: int) -> int:
	var base_cost: int = int(program.get("gold_cost", 0))

	match intensity:
		TRAINING_INTENSITY_LIGHT:
			return max(1, int(round(float(base_cost) * 0.70)))
		TRAINING_INTENSITY_INTENSE:
			return max(1, int(round(float(base_cost) * 1.60)))
		_:
			return max(1, base_cost)

func _get_training_happiness_loss(program: Dictionary, intensity: int) -> int:
	var base_loss: int = int(program.get("happiness_loss", 0))

	match intensity:
		TRAINING_INTENSITY_LIGHT:
			return max(1, int(round(float(base_loss) * 0.60)))
		TRAINING_INTENSITY_INTENSE:
			return max(1, int(round(float(base_loss) * 1.50)))
		_:
			return max(1, base_loss)

func _get_training_fatigue_gain(program: Dictionary, intensity: int) -> int:
	var base_gain: int = int(program.get("fatigue_gain", 0))

	match intensity:
		TRAINING_INTENSITY_LIGHT:
			return max(1, int(round(float(base_gain) * 0.60)))
		TRAINING_INTENSITY_INTENSE:
			return max(1, int(round(float(base_gain) * 1.50)))
		_:
			return max(1, base_gain)

func _get_training_roll_count(intensity: int) -> int:
	match intensity:
		TRAINING_INTENSITY_LIGHT:
			return 1
		TRAINING_INTENSITY_INTENSE:
			return 3
		_:
			return 2

func _get_training_breakthrough_chance(dragon: Dictionary, intensity: int) -> float:
	var bond_score: float = float(int(dragon.get("bond", 0))) / 100.0
	var happiness_score: float = float(int(dragon.get("happiness", 50))) / 100.0

	var chance: float = 0.04
	chance += bond_score * 0.16
	chance += happiness_score * 0.10

	if intensity == TRAINING_INTENSITY_NORMAL:
		chance += 0.04
	elif intensity == TRAINING_INTENSITY_INTENSE:
		chance += 0.08

	return clampf(chance, 0.04, 0.40)

func _roll_weighted_training_stat(stat_weights: Dictionary) -> String:
	if stat_weights.is_empty():
		return ""

	var total_weight: float = 0.0
	var stat_keys: Array = stat_weights.keys()

	for stat_key in stat_keys:
		total_weight += float(stat_weights.get(stat_key, 0.0))

	if total_weight <= 0.0:
		return ""

	var roll: float = randf() * total_weight
	var running: float = 0.0

	for stat_key in stat_keys:
		running += float(stat_weights.get(stat_key, 0.0))
		if roll <= running:
			return str(stat_key)

	return str(stat_keys[stat_keys.size() - 1])

func _apply_training_stat_gain(dragon: Dictionary, stat_key: String, amount: int) -> void:
	match stat_key:
		"max_hp":
			dragon["max_hp"] = int(dragon.get("max_hp", 0)) + amount
			dragon["current_hp"] = min(
				int(dragon.get("current_hp", 0)) + amount,
				int(dragon.get("max_hp", 0))
			)
		"strength":
			dragon["strength"] = int(dragon.get("strength", 0)) + amount
		"magic":
			dragon["magic"] = int(dragon.get("magic", 0)) + amount
		"defense":
			dragon["defense"] = int(dragon.get("defense", 0)) + amount
		"resistance":
			dragon["resistance"] = int(dragon.get("resistance", 0)) + amount
		"speed":
			dragon["speed"] = int(dragon.get("speed", 0)) + amount
		"agility":
			dragon["agility"] = int(dragon.get("agility", 0)) + amount

# ---------------------------------------------------------
# 1. FINDING WILD EGGS (Map Drops)
# ---------------------------------------------------------
func hatch_egg() -> Dictionary:
	var chosen_elem: String = DRAGON_ELEMENTS[randi() % DRAGON_ELEMENTS.size()]
	var traits: Array = _roll_wild_traits_for_element(chosen_elem)

	var new_dragon: Dictionary = _create_dragon_dict(
		"Baby " + chosen_elem + " Dragon",
		chosen_elem,
		1,
		traits,
		15, 5, 5, 5, 4
	)

	# Optional test cheat:
	# new_dragon["stage"] = DragonStage.ADULT
	# new_dragon["name"] = "Elder " + chosen_elem + " Dragon"

	_refresh_dragon_mood(new_dragon)
	player_dragons.append(new_dragon)
	print("Hatched a Gen 1 ", chosen_elem, " dragon with traits: ", traits)

	return new_dragon
	
func hatch_bred_egg(egg_uid: String = "") -> Dictionary:
	if unhatched_eggs.is_empty():
		return hatch_egg()

	if egg_uid != "":
		for i in range(unhatched_eggs.size()):
			var egg_record: Dictionary = unhatched_eggs[i]
			if str(egg_record.get("egg_uid", "")) == egg_uid:
				var baby: Dictionary = egg_record.get("baby_data", {}).duplicate(true)
				unhatched_eggs.remove_at(i)
				player_dragons.append(baby)
				_refresh_dragon_mood(baby)
				return baby

	var fallback_record: Dictionary = unhatched_eggs.pop_front()
	var fallback_baby: Dictionary = fallback_record.get("baby_data", {}).duplicate(true)
	player_dragons.append(fallback_baby)
	_refresh_dragon_mood(fallback_baby)
	return fallback_baby
			
# ---------------------------------------------------------
# 2. THE BREEDING SYSTEM (Camp Menu)
# ---------------------------------------------------------
func breed_dragons(index_a: int, index_b: int) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"error": "",
		"baby": {},
		"egg": {},
		"consumed_item": "",
		"mutated_traits": [],
		"inherited_traits": [],
		"generation": 0,
		"element": "",
		"quality": EGG_QUALITY_COMMON,
		"compatibility": 0,
		"parent_a_uid": "",
		"parent_b_uid": ""
	}

	if index_a < 0 or index_a >= player_dragons.size():
		result["error"] = "Parent A index is invalid."
		return result

	if index_b < 0 or index_b >= player_dragons.size():
		result["error"] = "Parent B index is invalid."
		return result

	if index_a == index_b:
		result["error"] = "You must choose two different dragons."
		return result

	var p1: Dictionary = player_dragons[index_a]
	var p2: Dictionary = player_dragons[index_b]

	result["parent_a_uid"] = str(p1.get("uid", ""))
	result["parent_b_uid"] = str(p2.get("uid", ""))

	if int(p1.get("stage", DragonStage.BABY)) < DragonStage.ADULT:
		result["error"] = str(p1.get("name", "Parent A")) + " is not an adult yet."
		return result

	if int(p2.get("stage", DragonStage.BABY)) < DragonStage.ADULT:
		result["error"] = str(p2.get("name", "Parent B")) + " is not an adult yet."
		return result

	if int(p1.get("breed_cooldown", 0)) > 0:
		result["error"] = str(p1.get("name", "Parent A")) + " is on breeding cooldown."
		return result

	if int(p2.get("breed_cooldown", 0)) > 0:
		result["error"] = str(p2.get("name", "Parent B")) + " is on breeding cooldown."
		return result

	var rose_index: int = _find_inventory_consumable_index_by_name(BREED_REQUIRED_ITEM_NAME)
	if rose_index == -1:
		result["error"] = "You need 1x " + BREED_REQUIRED_ITEM_NAME + " to breed dragons."
		return result

	var preview_mutated_traits: Array = _get_guaranteed_mutation_traits(p1, p2)
	var preview_guaranteed_traits: Array = _get_guaranteed_non_mutating_traits(p1, p2)

	var compatibility: int = _calculate_breeding_compatibility(
		p1,
		p2,
		preview_mutated_traits,
		preview_guaranteed_traits
	)

	var child_element: String = str(p1.get("element", "Fire"))
	if randf() < 0.5:
		child_element = str(p2.get("element", child_element))

	var child_generation: int = max(int(p1.get("generation", 1)), int(p2.get("generation", 1))) + 1

	var trait_result: Dictionary = _resolve_baby_traits_from_parents(p1, p2, compatibility)
	var child_traits: Array = trait_result.get("traits", []).duplicate()
	var mutated_traits: Array = trait_result.get("mutated_traits", []).duplicate()
	var inherited_traits: Array = trait_result.get("inherited_traits", []).duplicate()

	var quality: String = _get_bred_egg_quality(child_generation, compatibility, mutated_traits.size(), child_traits.size())

	var stat_block: Dictionary = _build_bred_baby_stat_block(
		p1,
		p2,
		child_generation,
		compatibility,
		mutated_traits.size(),
		quality
	)

	var baby_name: String = "Gen %d %s Baby" % [child_generation, child_element]

	var baby_dragon: Dictionary = _create_bred_dragon_dict(
		baby_name,
		child_element,
		child_generation,
		child_traits,
		stat_block,
		p1,
		p2,
		compatibility,
		quality,
		mutated_traits
	)

	var egg_record: Dictionary = _create_bred_egg_record(
		baby_dragon,
		p1,
		p2,
		compatibility,
		quality,
		mutated_traits,
		inherited_traits
	)

	CampaignManager.global_inventory.remove_at(rose_index)
	player_dragons[index_a]["breed_cooldown"] = BREED_COOLDOWN_TURNS
	player_dragons[index_b]["breed_cooldown"] = BREED_COOLDOWN_TURNS

	unhatched_eggs.append(egg_record)

	result["success"] = true
	result["baby"] = baby_dragon
	result["egg"] = egg_record
	result["consumed_item"] = BREED_REQUIRED_ITEM_NAME
	result["mutated_traits"] = mutated_traits
	result["inherited_traits"] = inherited_traits
	result["generation"] = child_generation
	result["element"] = child_element
	result["quality"] = quality
	result["compatibility"] = compatibility

	return result
		
func _find_inventory_consumable_index_by_name(target_name: String) -> int:
	var target_lower: String = target_name.strip_edges().to_lower()

	for i in range(CampaignManager.global_inventory.size()):
		var item = CampaignManager.global_inventory[i]
		if item == null:
			continue

		if item is ConsumableData:
			var item_name: String = str(item.item_name).strip_edges().to_lower()
			if item_name == target_lower:
				return i

	return -1
	
func _resolve_baby_traits_from_parents(p1: Dictionary, p2: Dictionary, compatibility: int = 50) -> Dictionary:
	var result: Dictionary = {
		"traits": [],
		"mutated_traits": [],
		"inherited_traits": []
	}

	var traits_a: Array = _get_unique_trait_array(p1)
	var traits_b: Array = _get_unique_trait_array(p2)

	var baby_traits: Array = []
	var mutated_traits: Array = []
	var inherited_traits: Array = []
	var roll_candidates: Array = []

	var all_traits: Array = []

	for t_name in traits_a:
		if not all_traits.has(t_name):
			all_traits.append(t_name)

	for t_name in traits_b:
		if not all_traits.has(t_name):
			all_traits.append(t_name)

	for t_name in all_traits:
		var in_a: bool = traits_a.has(t_name)
		var in_b: bool = traits_b.has(t_name)

		# Same Tier 1 trait on both parents => Tier 2 mutation
		if in_a and in_b and TIER_2_TRAIT_MAP.has(t_name):
			var mutated_name: String = str(TIER_2_TRAIT_MAP[t_name])
			if baby_traits.size() < BREED_MAX_TRAITS and _can_add_trait_to_list(baby_traits, mutated_name, 2):
				baby_traits.append(mutated_name)
				mutated_traits.append(mutated_name)
			continue

		# Same non-mutating trait on both parents => guaranteed inherit
		if in_a and in_b:
			if baby_traits.size() < BREED_MAX_TRAITS and _can_add_trait_to_list(baby_traits, str(t_name), 2):
				baby_traits.append(t_name)
				inherited_traits.append(t_name)
			continue

		# One-sided inheritance roll
		if in_a:
			var chance_a: float = _get_trait_inheritance_chance(p1, str(t_name), compatibility)
			roll_candidates.append({
				"trait_name": str(t_name),
				"chance": chance_a
			})
		elif in_b:
			var chance_b: float = _get_trait_inheritance_chance(p2, str(t_name), compatibility)
			roll_candidates.append({
				"trait_name": str(t_name),
				"chance": chance_b
			})

	for entry in roll_candidates:
		if baby_traits.size() >= BREED_MAX_TRAITS:
			break

		var inherited_name: String = str(entry["trait_name"])
		var chance: float = float(entry["chance"])

		if randf() <= chance and _can_add_trait_to_list(baby_traits, inherited_name, 2):
			baby_traits.append(inherited_name)
			inherited_traits.append(inherited_name)

	# Pity rule
	if baby_traits.is_empty() and roll_candidates.size() > 0:
		var best_trait_name: String = ""
		var best_chance: float = -1.0

		for entry in roll_candidates:
			var this_name: String = str(entry["trait_name"])
			var this_chance: float = float(entry["chance"])
			if this_chance > best_chance and _can_add_trait_to_list(baby_traits, this_name, 2):
				best_chance = this_chance
				best_trait_name = this_name

		if best_trait_name != "":
			baby_traits.append(best_trait_name)
			inherited_traits.append(best_trait_name)

	# High compatibility bonus
	if compatibility >= 85 and baby_traits.size() < BREED_MAX_TRAITS:
		var best_extra: String = ""
		var best_extra_chance: float = -1.0

		for entry in roll_candidates:
			var extra_name: String = str(entry["trait_name"])
			var extra_chance: float = float(entry["chance"])
			if not baby_traits.has(extra_name) and extra_chance > best_extra_chance and _can_add_trait_to_list(baby_traits, extra_name, 2):
				best_extra = extra_name
				best_extra_chance = extra_chance

		if best_extra != "":
			baby_traits.append(best_extra)
			inherited_traits.append(best_extra)

	result["traits"] = baby_traits
	result["mutated_traits"] = mutated_traits
	result["inherited_traits"] = inherited_traits
	return result
	
func _get_unique_trait_array(dragon: Dictionary) -> Array:
	var raw_traits: Array = dragon.get("traits", [])
	var cleaned: Array = []

	for t_name in raw_traits:
		var s: String = str(t_name).strip_edges()
		if s == "":
			continue
		if not cleaned.has(s):
			cleaned.append(s)

	return cleaned
	
func _get_trait_inheritance_chance(parent: Dictionary, _trait_name: String, compatibility: int = 50) -> float:
	var bond_score: float = clampf(float(int(parent.get("bond", 0))) / 100.0, 0.0, 1.0)
	var happy_score: float = clampf(float(int(parent.get("happiness", 50))) / 100.0, 0.0, 1.0)
	var compat_score: float = clampf(float(compatibility) / 100.0, 0.0, 1.0)

	var chance: float = 0.18
	chance += bond_score * 0.28
	chance += happy_score * 0.22
	chance += compat_score * 0.18

	var mood: String = str(parent.get("mood", ""))
	match mood:
		"Affectionate":
			chance += 0.08
		"Ecstatic":
			chance += 0.05
		"Happy":
			chance += 0.03

	var gen_bonus: float = float(max(0, int(parent.get("generation", 1)) - 1)) * 0.01
	chance += min(gen_bonus, 0.06)

	return clampf(chance, 0.18, 0.95)
	
func _build_bred_baby_stat_block(
	p1: Dictionary,
	p2: Dictionary,
	child_generation: int,
	compatibility: int,
	mutation_count: int,
	quality: String
) -> Dictionary:
	var gen_steps: int = max(0, child_generation - 1)

	var hp_bonus: int = gen_steps * GEN_BIRTH_HP_BONUS_PER_STEP
	var minor_bonus: int = gen_steps * GEN_BIRTH_MINOR_BONUS_PER_STEP

	var compat_minor_bonus: int = 0
	if compatibility >= 85:
		compat_minor_bonus = 2
	elif compatibility >= 65:
		compat_minor_bonus = 1

	var quality_hp_bonus: int = 0
	var quality_minor_bonus: int = 0

	match quality:
		EGG_QUALITY_RARE:
			quality_hp_bonus = 2
			quality_minor_bonus = 1
		EGG_QUALITY_EPIC:
			quality_hp_bonus = 4
			quality_minor_bonus = 2
		EGG_QUALITY_LEGENDARY:
			quality_hp_bonus = 6
			quality_minor_bonus = 3

	var mutation_bonus: int = mutation_count

	var stat_block: Dictionary = {
		"max_hp": int(round((int(p1.get("max_hp", 10)) + int(p2.get("max_hp", 10))) / 2.0)) + hp_bonus + quality_hp_bonus + mutation_bonus,
		"strength": int(round((int(p1.get("strength", 4)) + int(p2.get("strength", 4))) / 2.0)) + minor_bonus + compat_minor_bonus + quality_minor_bonus,
		"magic": int(round((int(p1.get("magic", 4)) + int(p2.get("magic", 4))) / 2.0)) + minor_bonus + compat_minor_bonus + quality_minor_bonus,
		"defense": int(round((int(p1.get("defense", 4)) + int(p2.get("defense", 4))) / 2.0)) + minor_bonus + compat_minor_bonus + quality_minor_bonus,
		"resistance": int(round((int(p1.get("resistance", 4)) + int(p2.get("resistance", 4))) / 2.0)) + minor_bonus + compat_minor_bonus + quality_minor_bonus,
		"speed": int(round((int(p1.get("speed", 4)) + int(p2.get("speed", 4))) / 2.0)) + minor_bonus + compat_minor_bonus + quality_minor_bonus,
		"agility": int(round((int(p1.get("agility", 3)) + int(p2.get("agility", 3))) / 2.0)) + minor_bonus + compat_minor_bonus + quality_minor_bonus
	}

	return stat_block
	
func _create_bred_dragon_dict(
	d_name: String,
	elem: String,
	gen: int,
	traits: Array,
	stat_block: Dictionary,
	parent_a: Dictionary,
	parent_b: Dictionary,
	compatibility: int,
	quality: String,
	mutated_traits: Array
) -> Dictionary:
	var avg_happiness: int = int(round((int(parent_a.get("happiness", 55)) + int(parent_b.get("happiness", 55))) / 2.0))
	avg_happiness = clamp(avg_happiness, 45, 95)

	var start_bond: int = 0
	if compatibility >= 85:
		start_bond = 12
	elif compatibility >= 70:
		start_bond = 8
	elif compatibility >= 55:
		start_bond = 4

	var dragon: Dictionary = {
		"uid": "dragon_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 100000),

		"name": d_name,
		"element": elem,
		"generation": gen,
		"stage": DragonStage.BABY,
		"traits": traits.duplicate(),
		"is_dragon": true,
		"social_links": {},
		"last_pet_time": 0,
		"pet_cooldown_until": 0,
		"breed_cooldown": 0,
		"growth_points": 0,
		"happiness": avg_happiness,
		"last_hunt_time": 0,
		"bond": start_bond,
		"mood": "Curious",
		"times_petted": 0,
		"fatigue": 0,
		"training_sessions": 0,
		"last_training_time": 0,
		
		"level": 1,
		"experience": 0,
		"skill_points": 0,
		"unlocked_skills": [],
		"unlocked_abilities": [],
		"generation_growth_bonus": _get_generation_growth_bonus(gen),

		"max_hp": int(stat_block.get("max_hp", 12)),
		"current_hp": int(stat_block.get("max_hp", 12)),
		"strength": int(stat_block.get("strength", 4)),
		"magic": int(stat_block.get("magic", 4)),
		"defense": int(stat_block.get("defense", 4)),
		"resistance": int(stat_block.get("resistance", 4)),
		"speed": int(stat_block.get("speed", 4)),
		"agility": int(stat_block.get("agility", 3)),

		"move_range": 5,
		"move_type": 2,
		"ability": "",
		"is_promoted": false,

		"inventory": [],

		# breeding metadata
		"egg_quality": quality,
		"breed_compatibility": compatibility,
		"mutated_traits": mutated_traits.duplicate(),
		"parent_uids": [str(parent_a.get("uid", "")), str(parent_b.get("uid", ""))],
		"parent_names": [str(parent_a.get("name", "Unknown")), str(parent_b.get("name", "Unknown"))]
	}

	_apply_element_birth_bias(dragon)
	_apply_trait_birth_bonuses(dragon)

	dragon["current_hp"] = int(dragon["max_hp"])
	dragon["ability"] = _get_default_dragon_ability(elem, traits)
	_refresh_dragon_mood(dragon)

	return dragon

func _apply_element_birth_bias(dragon: Dictionary) -> void:
	match str(dragon.get("element", "")):
		"Fire":
			dragon["strength"] += 1
		"Ice":
			dragon["resistance"] += 1
		"Lightning":
			dragon["speed"] += 1
			dragon["agility"] += 1
		"Earth":
			dragon["defense"] += 1
			dragon["move_range"] = 4
		"Wind":
			dragon["move_range"] = 6
			dragon["agility"] += 1

func _apply_trait_birth_bonuses(dragon: Dictionary) -> void:
	var dragon_traits: Array = dragon.get("traits", [])

	for trait_name in dragon_traits:
		var def: Dictionary = _get_trait_def(str(trait_name))
		if def.is_empty():
			continue

		var birth_bonus: Dictionary = def.get("birth", {})
		_apply_bonus_dict_to_target(dragon, birth_bonus)
					
func _get_generation_growth_bonus(gen: int) -> int:
	return min(max(0, gen - 1) * GEN_GROWTH_BONUS_PER_STEP, GEN_GROWTH_BONUS_CAP)
	
	
	
# ---------------------------------------------------------
# FEEDING / GROWTH
# ---------------------------------------------------------
func feed_dragon(index: int, food_value: int) -> Dictionary:
	var result: Dictionary = {
		"fed": false,
		"evolved": false,
		"old_stage": -1,
		"new_stage": -1,
		"growth_added": 0,
		"growth_mult": 1.0,
		"happiness": 0,
		"mood": ""
	}

	if index < 0 or index >= player_dragons.size():
		return result

	var d: Dictionary = player_dragons[index]
	if d["stage"] >= DragonStage.ADULT:
		return result

	result["fed"] = true
	result["old_stage"] = d["stage"]

	var happiness: int = int(d.get("happiness", 50))
	var growth_mult: float = get_happiness_growth_multiplier_for_value(happiness)
	var actual_growth: int = max(1, int(round(float(food_value) * growth_mult)))

	var trait_feed_bonus_pct: int = _get_total_trait_ranch_modifier(d, "feed_growth_bonus_pct")
	if trait_feed_bonus_pct != 0:
		actual_growth = max(1, int(round(float(actual_growth) * (1.0 + float(trait_feed_bonus_pct) / 100.0))))

	d["growth_points"] += actual_growth
	result["growth_added"] = actual_growth
	result["growth_mult"] = growth_mult

	var happiness_bonus: int = _get_total_trait_ranch_modifier(d, "happiness_gain_bonus")
	d["happiness"] = int(clamp(happiness + 2 + happiness_bonus, 0, 100))
	_refresh_dragon_mood(d)

	if d["stage"] == DragonStage.BABY and d["growth_points"] >= 50:
		_evolve_dragon(d, DragonStage.JUVENILE)
	elif d["stage"] == DragonStage.JUVENILE and d["growth_points"] >= 150:
		_evolve_dragon(d, DragonStage.ADULT)

	result["new_stage"] = d["stage"]
	result["evolved"] = result["new_stage"] != result["old_stage"]
	result["happiness"] = int(d.get("happiness", 50))
	result["mood"] = str(d.get("mood", "Curious"))

	return result
		
func pet_dragon(index: int) -> Dictionary:
	var result: Dictionary = {
		"petted": false,
		"liked": false,
		"reaction": "neutral",
		"bond_delta": 0,
		"bond": 0,
		"mood": "Calm",
		"float_text": "?",
		"on_cooldown": false,
		"cooldown_remaining": 0,
		"happiness_delta": 0,
		"happiness": 0
	}

	if index < 0 or index >= player_dragons.size():
		return result

	var d: Dictionary = player_dragons[index]
	var now: int = int(Time.get_unix_time_from_system())
	var cooldown_until: int = int(d.get("pet_cooldown_until", 0))

	if now < cooldown_until:
		result["on_cooldown"] = true
		result["cooldown_remaining"] = cooldown_until - now
		result["float_text"] = "Wait " + str(cooldown_until - now) + "s"
		result["bond"] = int(d.get("bond", 0))
		result["happiness"] = int(d.get("happiness", 50))
		result["mood"] = str(d.get("mood", "Curious"))
		return result

	result["petted"] = true

	var comfort: float = 55.0

	match int(d.get("stage", DragonStage.BABY)):
		DragonStage.BABY:
			comfort += 20.0
		DragonStage.JUVENILE:
			comfort += 8.0
		DragonStage.ADULT:
			comfort -= 6.0

	comfort += float(_get_total_trait_ranch_modifier(d, "pet_comfort"))

	var reaction_roll: float = randf() * 100.0
	var bond_delta: int = 0
	var happiness_delta: int = 0
	var reaction: String = "neutral"
	var float_text: String = "?"

	if reaction_roll < comfort * 0.45:
		reaction = "ecstatic"
		bond_delta = 3
		happiness_delta = 4
		float_text = "♥ +3 Bond"
		result["liked"] = true
	elif reaction_roll < comfort:
		reaction = "happy"
		bond_delta = 2
		happiness_delta = 2
		float_text = "♥ +2 Bond"
		result["liked"] = true
	elif reaction_roll > 92.0 and comfort < 45.0:
		reaction = "annoyed"
		bond_delta = -1
		happiness_delta = -3
		float_text = "Hss! -1 Bond"
	else:
		reaction = "neutral"
		bond_delta = 0
		happiness_delta = 0
		float_text = "?"

	if reaction == "ecstatic" or reaction == "happy":
		bond_delta += _get_total_trait_ranch_modifier(d, "bond_gain_bonus")
		happiness_delta += _get_total_trait_ranch_modifier(d, "happiness_gain_bonus")

	d["times_petted"] = int(d.get("times_petted", 0)) + 1
	d["bond"] = int(clamp(int(d.get("bond", 0)) + bond_delta, 0, 100))
	d["happiness"] = int(clamp(int(d.get("happiness", 50)) + happiness_delta, 0, 100))
	d["last_pet_time"] = now
	d["pet_cooldown_until"] = now + 30

	_refresh_dragon_mood(d)

	result["reaction"] = reaction
	result["bond_delta"] = bond_delta
	result["happiness_delta"] = happiness_delta
	result["bond"] = int(d["bond"])
	result["happiness"] = int(d["happiness"])
	result["mood"] = str(d["mood"])
	result["float_text"] = float_text

	return result
			
func _evolve_dragon(dragon: Dictionary, new_stage: int) -> void:
	dragon["stage"] = new_stage
	
	var gen_mult: float = 1.0 + (float(int(dragon.get("generation", 1)) - 1) * 0.1)
	
	dragon["max_hp"] += int(10 * gen_mult)
	dragon["strength"] += int(3 * gen_mult)
	dragon["magic"] += int(3 * gen_mult)
	dragon["defense"] += int(2 * gen_mult)
	dragon["resistance"] += int(2 * gen_mult)
	dragon["speed"] += int(1 * gen_mult)
	dragon["agility"] += int(1 * gen_mult)

	# Fully heal on evolution
	dragon["current_hp"] = dragon["max_hp"]

	if new_stage == DragonStage.JUVENILE:
		dragon["move_range"] += 1
		dragon["name"] = dragon["element"] + " Drake"
	elif new_stage == DragonStage.ADULT:
		dragon["move_range"] += 1
		dragon["is_promoted"] = true
		dragon["name"] = "Elder " + dragon["element"] + " Dragon"

# ---------------------------------------------------------
# DRAGON COMBAT PROGRESSION
# ---------------------------------------------------------
func grant_battle_exp(index: int, amount: int) -> Dictionary:
	var result: Dictionary = {
		"gained_exp": 0,
		"leveled_up": false,
		"levels_gained": 0,
		"gains": []
	}

	if index < 0 or index >= player_dragons.size():
		return result

	var dragon: Dictionary = player_dragons[index]
	dragon["experience"] += amount
	result["gained_exp"] = amount

	while int(dragon["experience"]) >= _get_exp_required_for_level(int(dragon["level"])):
		dragon["experience"] -= _get_exp_required_for_level(int(dragon["level"]))
		var gains: Dictionary = _dragon_level_up(dragon)
		result["leveled_up"] = true
		result["levels_gained"] += 1
		result["gains"].append(gains)

	return result
func _dragon_level_up(dragon: Dictionary) -> Dictionary:
	dragon["level"] += 1

	var growths: Dictionary = {
		"hp": 80,
		"str": 50,
		"mag": 50,
		"def": 40,
		"res": 35,
		"spd": 45,
		"agi": 40
	}

	_apply_trait_growth_modifiers(dragon, growths)

	var gen_bonus: int = _get_generation_growth_bonus(int(dragon.get("generation", 1)))
	dragon["generation_growth_bonus"] = gen_bonus

	for key_name in growths.keys():
		growths[key_name] = clampi(int(growths[key_name]) + gen_bonus, 5, 95)

	var gains: Dictionary = {
		"hp": 0,
		"str": 0,
		"mag": 0,
		"def": 0,
		"res": 0,
		"spd": 0,
		"agi": 0
	}

	var total_gains: int = 0

	for stat_key in gains.keys():
		var growth: int = int(growths[stat_key])
		var gain: int = _roll_growth_gain(growth)
		gains[stat_key] = gain
		total_gains += gain

	# pity system
	if total_gains == 0:
		var fallback_stats: Array = ["hp", "str", "mag", "def", "res", "spd", "agi"]
		var lucky_stat: String = str(fallback_stats[randi() % fallback_stats.size()])
		gains[lucky_stat] = 1

	dragon["max_hp"] += int(gains["hp"])
	dragon["strength"] += int(gains["str"])
	dragon["magic"] += int(gains["mag"])
	dragon["defense"] += int(gains["def"])
	dragon["resistance"] += int(gains["res"])
	dragon["speed"] += int(gains["spd"])
	dragon["agility"] += int(gains["agi"])

	dragon["current_hp"] = min(int(dragon["max_hp"]), int(dragon["current_hp"]) + int(gains["hp"]) + 1)
	dragon["skill_points"] += 1

	return gains
	
func _apply_trait_growth_modifiers(dragon: Dictionary, growths: Dictionary) -> void:
	var dragon_traits: Array = dragon.get("traits", [])

	for trait_name in dragon_traits:
		var def: Dictionary = _get_trait_def(str(trait_name))
		if def.is_empty():
			continue

		var growth_bonus: Dictionary = def.get("growth", {})
		_apply_bonus_dict_to_target(growths, growth_bonus)
				
func _roll_growth_gain(growth: int) -> int:
	if randi() % 100 >= growth:
		return 0

	# High growths have a small chance to grant +2
	var double_gain_chance: int = clampi(int(round(float(growth) * 0.20)), 8, 30)
	if randi() % 100 < double_gain_chance:
		return 2

	return 1
	
func _get_exp_required_for_level(level: int) -> int:
	var base_exp: int = 100
	var scaling_factor: int = 25
	return base_exp + max(0, level - 1) * scaling_factor

# ---------------------------------------------------------
# BATTLE CONVERSION / SYNC
# ---------------------------------------------------------
func create_battle_unit_from_dragon(index: int) -> Dictionary:
	if index < 0 or index >= player_dragons.size():
		return {}

	return create_battle_unit_from_dragon_dict(player_dragons[index])

func create_battle_unit_from_dragon_dict(dragon: Dictionary) -> Dictionary:
	return {
		# Identity / tags
		"is_dragon": true,
		"uid": dragon["uid"],
		"dragon_uid": dragon["uid"],
		"unit_name": dragon["name"],
		"unit_class_name": _get_dragon_class_name(dragon),
		"element": dragon["element"],
		"generation": dragon["generation"],
		"stage": dragon["stage"],
		"traits": dragon["traits"].duplicate(),
		"is_promoted": dragon.get("is_promoted", false),

		# Combat state
		"level": dragon["level"],
		"experience": dragon["experience"],
		"current_hp": dragon["current_hp"],
		"max_hp": dragon["max_hp"],
		"strength": dragon["strength"],
		"magic": dragon["magic"],
		"defense": dragon["defense"],
		"resistance": dragon["resistance"],
		"speed": dragon["speed"],
		"agility": dragon["agility"],

		# Movement / combat identity
		"move_range": dragon["move_range"],
		"move_type": dragon["move_type"],
		"ability": dragon["ability"],

		# Progress systems
		"skill_points": dragon["skill_points"],
		"unlocked_skills": dragon["unlocked_skills"].duplicate(),
		"unlocked_abilities": dragon["unlocked_abilities"].duplicate(),

		# Inventory / equipment
		"inventory": dragon["inventory"].duplicate(),

		# Keep ranch data that might matter later
		"growth_points": dragon["growth_points"]
	}

func apply_battle_results_to_dragon(dragon_uid: String, battle_dict: Dictionary) -> bool:
	var index: int = get_dragon_index_by_uid(dragon_uid)
	if index == -1:
		return false

	var dragon: Dictionary = player_dragons[index]

	dragon["level"] = battle_dict.get("level", dragon["level"])
	dragon["experience"] = battle_dict.get("experience", dragon["experience"])
	dragon["current_hp"] = battle_dict.get("current_hp", dragon["current_hp"])
	dragon["max_hp"] = battle_dict.get("max_hp", dragon["max_hp"])
	dragon["strength"] = battle_dict.get("strength", dragon["strength"])
	dragon["magic"] = battle_dict.get("magic", dragon["magic"])
	dragon["defense"] = battle_dict.get("defense", dragon["defense"])
	dragon["resistance"] = battle_dict.get("resistance", dragon["resistance"])
	dragon["speed"] = battle_dict.get("speed", dragon["speed"])
	dragon["agility"] = battle_dict.get("agility", dragon["agility"])
	dragon["move_range"] = battle_dict.get("move_range", dragon["move_range"])
	dragon["move_type"] = battle_dict.get("move_type", dragon["move_type"])
	dragon["ability"] = battle_dict.get("ability", dragon["ability"])
	dragon["skill_points"] = battle_dict.get("skill_points", dragon["skill_points"])

	if battle_dict.has("unlocked_skills"):
		dragon["unlocked_skills"] = battle_dict["unlocked_skills"].duplicate()
	if battle_dict.has("unlocked_abilities"):
		dragon["unlocked_abilities"] = battle_dict["unlocked_abilities"].duplicate()
	if battle_dict.has("inventory"):
		dragon["inventory"] = battle_dict["inventory"].duplicate()

	return true

# ---------------------------------------------------------
# HELPERS / LOOKUPS
# ---------------------------------------------------------
func get_dragon_index_by_uid(uid: String) -> int:
	if uid == "":
		return -1

	for i in range(player_dragons.size()):
		if str(player_dragons[i].get("uid", "")) == uid:
			return i

	return -1

func get_dragon_by_uid(uid: String) -> Dictionary:
	var index: int = get_dragon_index_by_uid(uid)
	if index == -1:
		return {}
	return player_dragons[index]

func get_dragon_stage_name(stage: int) -> String:
	match stage:
		DragonStage.EGG:
			return "Egg"
		DragonStage.BABY:
			return "Baby"
		DragonStage.JUVENILE:
			return "Juvenile"
		DragonStage.ADULT:
			return "Adult"
		_:
			return "Unknown"

func _get_dragon_class_name(dragon: Dictionary) -> String:
	match int(dragon.get("stage", DragonStage.BABY)):
		DragonStage.EGG:
			return "Egg"
		DragonStage.BABY:
			return "Wyrmling"
		DragonStage.JUVENILE:
			return "Drake"
		DragonStage.ADULT:
			return "Dragon"
		_:
			return "Dragon"

func _dragon_has_trait_dict(dragon: Dictionary, trait_name: String) -> bool:
	var traits: Array = dragon.get("traits", [])
	return traits.has(trait_name)

func _get_default_dragon_ability(elem: String, traits: Array) -> String:
	if _traits_have_any(traits, ["Magic Blooded", "Runebound", "Elder Arcana", "Starbound"]):
		return "Arcane Breath"

	if elem == "Fire" and _traits_have_any(traits, ["Flameheart", "Infernal Core"]):
		return "Inferno Breath"

	if elem == "Ice" and _traits_have_any(traits, ["Frostborn", "Permafrost Heart"]):
		return "Glacial Breath"

	if elem == "Lightning" and _traits_have_any(traits, ["Stormchaser", "Tempest Born"]):
		return "Volt Breath"

	if elem == "Earth" and _traits_have_any(traits, ["Burrower", "Worldshaper"]):
		return "Quake Hide"

	if elem == "Wind" and _traits_have_any(traits, ["Sky Dancer", "Zephyr Lord"]):
		return "Tempest Wing"

	match elem:
		"Fire":
			return "Flame Breath"
		"Ice":
			return "Frost Breath"
		"Lightning":
			return "Thunder Breath"
		"Earth":
			return "Stone Hide"
		"Wind":
			return "Gale Wing"
		_:
			return ""
			
func _create_dragon_dict(
	d_name: String,
	elem: String,
	gen: int,
	traits: Array,
	hp: int,
	st: int,
	mg: int,
	df: int,
	sp: int
) -> Dictionary:
	var base_res: int = 4
	var base_agi: int = max(3, sp - 1)
	var base_move_range: int = 5
	var base_move_type: int = 2

	# Small elemental identity bias
	match elem:
		"Fire":
			st += 1
		"Ice":
			base_res += 1
		"Lightning":
			sp += 1
			base_agi += 1
		"Earth":
			df += 1
			base_move_range = 4
		"Wind":
			base_move_range = 6
			base_agi += 1

	var dragon: Dictionary = {
		"uid": "dragon_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000),

		# Identity
		"name": d_name,
		"element": elem,
		"generation": gen,
		"stage": DragonStage.BABY,
		"traits": traits.duplicate(),
		"is_dragon": true,
		"last_pet_time": 0,
		"pet_cooldown_until": 0,
		"social_links": {},
		# --- THE PATCH: Add the new fields here ---
		"breed_cooldown": 0,
		"generation_growth_bonus": _get_generation_growth_bonus(gen),
		
		"growth_points": 0,
		
		"happiness": 55,
		"last_hunt_time": 0,
		
		# Social / ranch personality
		"bond": 0,
		"mood": "Curious",
		"times_petted": 0,
		"fatigue": 0,
		"training_sessions": 0,
		"last_training_time": 0,

		# Combat progression
		"level": 1,
		"experience": 0,
		"skill_points": 0,
		"unlocked_skills": [],
		"unlocked_abilities": [],

		# Core combat stats
		"max_hp": hp,
		"current_hp": hp,
		"strength": st,
		"magic": mg,
		"defense": df,
		"resistance": base_res,
		"speed": sp,
		"agility": base_agi,

		# Battle identity / movement
		"move_range": base_move_range,
		"move_type": base_move_type,
		"ability": _get_default_dragon_ability(elem, traits),
		"is_promoted": false,

		# Equipment / inventory
		"inventory": []
	}
	
	_apply_trait_birth_bonuses(dragon)
	
	return dragon


func get_happiness_growth_multiplier_for_value(happiness: int) -> float:
	if happiness >= 85:
		return 1.50
	elif happiness >= 70:
		return 1.25
	elif happiness >= 55:
		return 1.10
	elif happiness >= 35:
		return 1.00
	elif happiness >= 20:
		return 0.85
	else:
		return 0.70

func get_happiness_state_name(happiness: int) -> String:
	if happiness >= 85:
		return "Ecstatic"
	elif happiness >= 70:
		return "Happy"
	elif happiness >= 55:
		return "Content"
	elif happiness >= 35:
		return "Calm"
	elif happiness >= 20:
		return "Restless"
	else:
		return "Miserable"

func _refresh_dragon_mood(dragon: Dictionary) -> void:
	var happiness: int = int(dragon.get("happiness", 50))
	var bond: int = int(dragon.get("bond", 0))

	if happiness >= 85 and bond >= 60:
		dragon["mood"] = "Affectionate"
	elif happiness >= 85:
		dragon["mood"] = "Ecstatic"
	elif happiness >= 70:
		dragon["mood"] = "Happy"
	elif happiness >= 55:
		dragon["mood"] = "Content"
	elif happiness >= 35:
		dragon["mood"] = "Curious"
	elif happiness >= 20:
		dragon["mood"] = "Restless"
	else:
		dragon["mood"] = "Irritated"
		
func throw_rabbit_for_hunt(index: int) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"happiness_delta": 0,
		"happiness": 0,
		"bond_delta": 0,
		"bond": 0,
		"mood": "",
		"float_text": ""
	}

	if index < 0 or index >= player_dragons.size():
		return result

	var d: Dictionary = player_dragons[index]

	var happiness_gain: int = 10

	match int(d.get("stage", DragonStage.BABY)):
		DragonStage.BABY:
			happiness_gain += 4
		DragonStage.JUVENILE:
			happiness_gain += 2
		DragonStage.ADULT:
			happiness_gain += 1

	happiness_gain += _get_total_trait_ranch_modifier(d, "hunt_bonus")

	match str(d.get("element", "")):
		"Wind":
			happiness_gain += 2
		"Lightning":
			happiness_gain += 1

	happiness_gain = clamp(happiness_gain, 4, 24)

	d["happiness"] = int(clamp(int(d.get("happiness", 50)) + happiness_gain, 0, 100))

	var bond_delta: int = 0
	if int(d["happiness"]) >= 75:
		bond_delta = 1
		d["bond"] = int(clamp(int(d.get("bond", 0)) + 1, 0, 100))

	d["last_hunt_time"] = int(Time.get_unix_time_from_system())
	_refresh_dragon_mood(d)

	result["success"] = true
	result["happiness_delta"] = happiness_gain
	result["happiness"] = int(d["happiness"])
	result["bond_delta"] = bond_delta
	result["bond"] = int(d.get("bond", 0))
	result["mood"] = str(d.get("mood", "Curious"))
	result["float_text"] = "+%d Happy" % happiness_gain

	return result
	
func _get_shared_traits(p1: Dictionary, p2: Dictionary) -> Array:
	var shared: Array = []
	var traits_a: Array = _get_unique_trait_array(p1)
	var traits_b: Array = _get_unique_trait_array(p2)

	for t_name in traits_a:
		if traits_b.has(t_name) and not shared.has(t_name):
			shared.append(t_name)

	return shared


func _get_bred_egg_quality(child_generation: int, compatibility: int, mutation_count: int, trait_count: int) -> String:
	var score: int = compatibility
	score += mutation_count * 16
	score += max(0, child_generation - 1) * 4
	score += max(0, trait_count - 1) * 5

	if score >= 100:
		return EGG_QUALITY_LEGENDARY
	elif score >= 80:
		return EGG_QUALITY_EPIC
	elif score >= 60:
		return EGG_QUALITY_RARE
	return EGG_QUALITY_COMMON
	
func _create_bred_egg_record(
	baby_dragon: Dictionary,
	parent_a: Dictionary,
	parent_b: Dictionary,
	compatibility: int,
	quality: String,
	mutated_traits: Array,
	inherited_traits: Array
) -> Dictionary:
	return {
		"egg_uid": "egg_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 100000),
		"baby_uid": str(baby_dragon.get("uid", "")),
		"baby_data": baby_dragon.duplicate(true),
		"generation": int(baby_dragon.get("generation", 1)),
		"element": str(baby_dragon.get("element", "Unknown")),
		"quality": quality,
		"compatibility": compatibility,
		"traits": baby_dragon.get("traits", []).duplicate(),
		"mutated_traits": mutated_traits.duplicate(),
		"inherited_traits": inherited_traits.duplicate(),
		"parent_names": [str(parent_a.get("name", "Unknown")), str(parent_b.get("name", "Unknown"))],
		"parent_uids": [str(parent_a.get("uid", "")), str(parent_b.get("uid", ""))]
	}
	
func get_breeding_preview(index_a: int, index_b: int) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"error": "",
		"generation": 0,
		"element_a": "",
		"element_b": "",
		"element_text": "",
		"compatibility_score": 0,
		"compatibility_tier": "Unknown",
		"quality": "Common",
		"mutated_traits": [],
		"guaranteed_traits": [],
		"possible_traits": [],
		"resonance_tags": [],
		"rose_owned": _find_inventory_consumable_index_by_name(BREED_REQUIRED_ITEM_NAME) != -1
	}

	if index_a < 0 or index_a >= player_dragons.size():
		result["error"] = "Parent A index is invalid."
		return result

	if index_b < 0 or index_b >= player_dragons.size():
		result["error"] = "Parent B index is invalid."
		return result

	if index_a == index_b:
		result["error"] = "You must choose two different dragons."
		return result

	var p1: Dictionary = player_dragons[index_a]
	var p2: Dictionary = player_dragons[index_b]

	if int(p1.get("stage", DragonStage.BABY)) < DragonStage.ADULT:
		result["error"] = str(p1.get("name", "Parent A")) + " is not an adult yet."
		return result

	if int(p2.get("stage", DragonStage.BABY)) < DragonStage.ADULT:
		result["error"] = str(p2.get("name", "Parent B")) + " is not an adult yet."
		return result

	if int(p1.get("breed_cooldown", 0)) > 0:
		result["error"] = str(p1.get("name", "Parent A")) + " is on breeding cooldown."
		return result

	if int(p2.get("breed_cooldown", 0)) > 0:
		result["error"] = str(p2.get("name", "Parent B")) + " is on breeding cooldown."
		return result

	var generation: int = max(int(p1.get("generation", 1)), int(p2.get("generation", 1))) + 1
	var element_a: String = str(p1.get("element", "Unknown"))
	var element_b: String = str(p2.get("element", "Unknown"))

	var mutated_traits: Array = _get_guaranteed_mutation_traits(p1, p2)
	var guaranteed_traits: Array = _get_guaranteed_non_mutating_traits(p1, p2)
	var inherited_candidates: Array = _get_preview_inherited_traits(p1, p2)

	var possible_traits: Array = []
	for t in mutated_traits:
		if not possible_traits.has(t):
			possible_traits.append(t)
	for t in guaranteed_traits:
		if not possible_traits.has(t):
			possible_traits.append(t)
	for t in inherited_candidates:
		if not possible_traits.has(t):
			possible_traits.append(t)

	var compatibility_score: int = _calculate_breeding_compatibility(
		p1,
		p2,
		mutated_traits,
		guaranteed_traits
	)
	var compatibility_tier: String = _get_compatibility_tier_name(compatibility_score)
	var quality: String = _get_preview_quality_name(compatibility_score, generation, mutated_traits.size())
	var resonance_tags: Array = _build_breeding_resonance_tags(
		p1,
		p2,
		compatibility_score,
		mutated_traits,
		guaranteed_traits,
		generation
	)

	result["success"] = true
	result["generation"] = generation
	result["element_a"] = element_a
	result["element_b"] = element_b
	result["element_text"] = element_a if element_a == element_b else (element_a + " / " + element_b)
	result["compatibility_score"] = compatibility_score
	result["compatibility_tier"] = compatibility_tier
	result["quality"] = quality
	result["mutated_traits"] = mutated_traits
	result["guaranteed_traits"] = guaranteed_traits
	result["possible_traits"] = possible_traits
	result["resonance_tags"] = resonance_tags

	return result


func _get_guaranteed_mutation_traits(p1: Dictionary, p2: Dictionary) -> Array:
	var out: Array = []
	var traits_a: Array = _get_unique_trait_array(p1)
	var traits_b: Array = _get_unique_trait_array(p2)

	for t_name in traits_a:
		if traits_b.has(t_name) and TIER_2_TRAIT_MAP.has(t_name):
			var mutated_name: String = str(TIER_2_TRAIT_MAP[t_name])
			if not out.has(mutated_name):
				out.append(mutated_name)

	return out


func _get_guaranteed_non_mutating_traits(p1: Dictionary, p2: Dictionary) -> Array:
	var out: Array = []
	var traits_a: Array = _get_unique_trait_array(p1)
	var traits_b: Array = _get_unique_trait_array(p2)

	for t_name in traits_a:
		if traits_b.has(t_name) and not TIER_2_TRAIT_MAP.has(t_name):
			if not out.has(t_name):
				out.append(t_name)

	return out


func _get_preview_inherited_traits(p1: Dictionary, p2: Dictionary) -> Array:
	var out: Array = []
	var traits_a: Array = _get_unique_trait_array(p1)
	var traits_b: Array = _get_unique_trait_array(p2)

	for t_name in traits_a:
		if not traits_b.has(t_name) and not out.has(t_name):
			out.append(t_name)

	for t_name in traits_b:
		if not traits_a.has(t_name) and not out.has(t_name):
			out.append(t_name)

	return out


func _calculate_breeding_compatibility(
	p1: Dictionary,
	p2: Dictionary,
	mutated_traits: Array,
	guaranteed_traits: Array
) -> int:
	var score: float = 20.0

	var avg_bond: float = (
		float(int(p1.get("bond", 0))) +
		float(int(p2.get("bond", 0)))
	) / 2.0

	var avg_happiness: float = (
		float(int(p1.get("happiness", 50))) +
		float(int(p2.get("happiness", 50)))
	) / 2.0

	score += avg_bond * 0.18
	score += avg_happiness * 0.20

	if str(p1.get("element", "")) == str(p2.get("element", "")):
		score += 16.0
	else:
		score += 6.0

	score += float(mutated_traits.size()) * 12.0
	score += float(guaranteed_traits.size()) * 6.0

	var min_gen: int = min(int(p1.get("generation", 1)), int(p2.get("generation", 1)))
	score += min(float(min_gen - 1) * 4.0, 18.0)

	var mood_a: String = str(p1.get("mood", ""))
	var mood_b: String = str(p2.get("mood", ""))

	if mood_a == "Affectionate" and mood_b == "Affectionate":
		score += 10.0
	elif (
		(mood_a == "Happy" or mood_a == "Ecstatic" or mood_a == "Affectionate") and
		(mood_b == "Happy" or mood_b == "Ecstatic" or mood_b == "Affectionate")
	):
		score += 6.0

	if mood_a == "Irritated" or mood_b == "Irritated":
		score -= 12.0
	elif mood_a == "Restless" or mood_b == "Restless":
		score -= 6.0

	return clampi(int(round(score)), 0, 100)


func _get_compatibility_tier_name(score: int) -> String:
	if score >= 90:
		return "Mythic Resonance"
	elif score >= 75:
		return "Soulbound"
	elif score >= 55:
		return "Stable"
	elif score >= 35:
		return "Volatile"
	return "Chaotic"


func _get_preview_quality_name(score: int, generation: int, mutation_count: int) -> String:
	var quality_score: int = score + (generation * 4) + (mutation_count * 12)

	if quality_score >= 120:
		return "Legendary"
	elif quality_score >= 90:
		return "Epic"
	elif quality_score >= 60:
		return "Rare"
	return "Common"


func _build_breeding_resonance_tags(
	p1: Dictionary,
	p2: Dictionary,
	compatibility_score: int,
	mutated_traits: Array,
	guaranteed_traits: Array,
	generation: int
) -> Array:
	var tags: Array = []

	if str(p1.get("element", "")) == str(p2.get("element", "")):
		tags.append("Pure Bloodline")
	else:
		tags.append("Split Bloodline")

	if not mutated_traits.is_empty():
		tags.append("Mutation Surge")

	if not guaranteed_traits.is_empty():
		tags.append("Stable Inheritance")

	if compatibility_score >= 80:
		tags.append("High Resonance")

	if generation >= 4:
		tags.append("Ancient Lineage")

	var mood_a: String = str(p1.get("mood", ""))
	var mood_b: String = str(p2.get("mood", ""))

	if mood_a == "Affectionate" and mood_b == "Affectionate":
		tags.append("Heartbonded")

	return tags

func _get_trait_def(trait_name: String) -> Dictionary:
	if TRAIT_DEFS.has(trait_name):
		return TRAIT_DEFS[trait_name]
	return {}

func _get_trait_family(trait_name: String) -> String:
	var def: Dictionary = _get_trait_def(trait_name)
	return str(def.get("family", ""))

func _get_trait_tier(trait_name: String) -> int:
	var def: Dictionary = _get_trait_def(trait_name)
	return int(def.get("tier", 1))

func _apply_bonus_dict_to_target(target: Dictionary, bonus_dict: Dictionary) -> void:
	for key_name in bonus_dict.keys():
		target[key_name] = int(target.get(key_name, 0)) + int(bonus_dict[key_name])

func _get_total_trait_ranch_modifier(dragon: Dictionary, modifier_name: String) -> int:
	var total: int = 0
	var dragon_traits: Array = dragon.get("traits", [])

	for trait_name in dragon_traits:
		var def: Dictionary = _get_trait_def(str(trait_name))
		if def.is_empty():
			continue

		var ranch: Dictionary = def.get("ranch", {})
		total += int(ranch.get(modifier_name, 0))

	return total

func _traits_have_any(traits: Array, wanted: Array) -> bool:
	for t_name in wanted:
		if traits.has(t_name):
			return true
	return false

func _count_family_in_traits(traits: Array, family_name: String) -> int:
	var count: int = 0

	for trait_name in traits:
		if _get_trait_family(str(trait_name)) == family_name:
			count += 1

	return count

func _can_add_trait_to_list(existing_traits: Array, candidate_trait: String, family_cap: int = 2) -> bool:
	if candidate_trait == "":
		return false
	if existing_traits.has(candidate_trait):
		return false
	if not TRAIT_DEFS.has(candidate_trait):
		return true

	var family_name: String = _get_trait_family(candidate_trait)
	if family_name == "":
		return true

	var tier: int = _get_trait_tier(candidate_trait)
	var allowed_in_family: int = family_cap
	if tier >= 2:
		allowed_in_family = max(family_cap, 2)

	return _count_family_in_traits(existing_traits, family_name) < allowed_in_family

func _roll_wild_trait_count() -> int:
	var roll: float = randf()
	if roll < 0.65:
		return 1
	elif roll < 0.93:
		return 2
	return 3

func _roll_weighted_wild_trait(element: String, excluded: Array, current_traits: Array) -> String:
	var total_weight: float = 0.0
	var weighted_defs: Dictionary = ELEMENT_TRAIT_WEIGHTS.get(element, {})
	var candidates: Array = []

	for trait_name in WILD_TRAITS:
		if excluded.has(trait_name):
			continue

		var weight: float = float(weighted_defs.get(trait_name, 1.0))

		# Soft discourage same-family stacking on wild dragons
		var family_name: String = _get_trait_family(trait_name)
		if family_name != "" and _count_family_in_traits(current_traits, family_name) > 0:
			weight *= 0.45

		if weight <= 0.0:
			continue

		candidates.append({
			"name": trait_name,
			"weight": weight
		})
		total_weight += weight

	if candidates.is_empty() or total_weight <= 0.0:
		return ""

	var roll: float = randf() * total_weight
	var running: float = 0.0

	for entry in candidates:
		running += float(entry["weight"])
		if roll <= running:
			return str(entry["name"])

	return str(candidates[candidates.size() - 1]["name"])

func _roll_wild_traits_for_element(element: String) -> Array:
	var desired_count: int = _roll_wild_trait_count()
	var traits: Array = []
	var attempts: int = 0

	while traits.size() < desired_count and attempts < 40:
		attempts += 1

		var picked: String = _roll_weighted_wild_trait(element, traits, traits)
		if picked == "":
			break

		if _can_add_trait_to_list(traits, picked, 1):
			traits.append(picked)

	if traits.is_empty():
		var fallback_trait: String = _roll_weighted_wild_trait(element, [], [])
		if fallback_trait == "":
			fallback_trait = WILD_TRAITS[randi() % WILD_TRAITS.size()]
		traits.append(fallback_trait)

	return traits

func _ensure_social_links(dragon: Dictionary) -> void:
	if not dragon.has("social_links") or typeof(dragon["social_links"]) != TYPE_DICTIONARY:
		dragon["social_links"] = {}


func get_social_score(uid_a: String, uid_b: String) -> int:
	if uid_a == "" or uid_b == "" or uid_a == uid_b:
		return 0

	var index_a: int = get_dragon_index_by_uid(uid_a)
	if index_a == -1:
		return 0

	var dragon_a: Dictionary = player_dragons[index_a]
	_ensure_social_links(dragon_a)

	return int(dragon_a["social_links"].get(uid_b, 0))


func set_social_score(uid_a: String, uid_b: String, value: int) -> void:
	if uid_a == "" or uid_b == "" or uid_a == uid_b:
		return

	var index_a: int = get_dragon_index_by_uid(uid_a)
	var index_b: int = get_dragon_index_by_uid(uid_b)
	if index_a == -1 or index_b == -1:
		return

	var dragon_a: Dictionary = player_dragons[index_a]
	var dragon_b: Dictionary = player_dragons[index_b]

	_ensure_social_links(dragon_a)
	_ensure_social_links(dragon_b)

	var final_value: int = clampi(value, -100, 100)
	dragon_a["social_links"][uid_b] = final_value
	dragon_b["social_links"][uid_a] = final_value


func change_social_score(uid_a: String, uid_b: String, delta: int) -> int:
	var current: int = get_social_score(uid_a, uid_b)
	var updated: int = clampi(current + delta, -100, 100)
	set_social_score(uid_a, uid_b, updated)
	return updated
