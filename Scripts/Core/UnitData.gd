extends Resource
class_name UnitData

## Broad species / creature category for narrative, UI, and lightweight combat rules (e.g. bleed VFX). Assign per [UnitData] asset; [member Unit.data] is the runtime source.
enum UnitType {
	UNSPECIFIED = 0,
	HUMAN = 1,
	ELF = 2,
	DWARF = 3,
	HALFLING = 4,
	GOBLIN = 5,
	ORC = 6,
	UNDEAD = 7,
	BEAST = 8,
	CONSTRUCT = 9,
	SPIRIT = 10,
	ABERRATION = 11,
	ELEMENTAL = 12,
	DRAGON = 13,
}

@export var display_name: String = "Unit"

@export_category("Species / unit type")
@export var unit_type: UnitType = UnitType.UNSPECIFIED
@export var is_recruitable: bool = false
@export_multiline var recruit_dialogue: Array[String] = [
	"Wait! Lay down your weapons. There is no need for us to be enemies.",
	"I... I never wanted this. I just needed the coin.",
	"Then fight for us. We pay better, and we fight for what's right.",
	"Alright. I'm with you. I won't let you down!"
]

@export_multiline var pre_battle_quote: Array[String] = []

@export_category("Dialogue & Narrative")
@export_multiline var death_quotes: Array[String] = []
@export_multiline var level_up_quotes: Array[String] = []
## Short support-rescue battle lines key. Used by Defy Death for savior dialogue (e.g. heroic, stoic, warm).
@export var support_personality: String = ""

@export var character_class: ClassData
@export var starting_weapon: WeaponData
@export var death_sound: AudioStream
@export var ability: String = ""
@export var supports: Array[SupportData] = []

@export_category("Visuals")
@export var unit_sprite: Texture2D 
@export var portrait: Texture2D # High-res portrait for the UI
@export var visual_scale: float = 1.0

@export_category("Character Base Stats")
@export var max_hp: int = 15
@export var strength: int = 3
@export var magic: int = 0
@export var defense: int = 2
@export var resistance: int = 0
@export var speed: int = 3
@export var agility: int = 3

@export_category("Damage Subtype Multipliers (Physical)")
## 1.0 = neutral, <1.0 = resistant, >1.0 = vulnerable
@export var phys_mult_slashing: float = 1.0
@export var phys_mult_piercing: float = 1.0
@export var phys_mult_bludgeoning: float = 1.0

@export_category("Undead / Bone pile reform")
## Legacy fallback when no [member passive_combat_abilities] entry uses [enum PassiveCombatAbilityData.EffectKind.BONE_PILE_REFORM_ON_DEATH]. Prefer that passive on [PassiveCombatAbilityData].
@export var bone_pile_reform_rounds: int = 0

@export_category("Map 01 (tutorial fire map)")
## Obsidian Circle kit id for Map 01 enemy passives (Ashburst, Ash Sight, Ember Wake, Kindle Slash, Panic Hunger).
@export_enum("None", "SoulReaver", "CinderArcher", "PyreDisciple", "AshCultist") var map01_enemy_kit: int = 0
## Used by Panic Hunger (HIT): treat as civilian / escort-style target.
@export var counts_as_civilian_escort_target: bool = false

@export_category("Passive combat abilities")
## Data-driven passives evaluated in combat ([CombatPassiveAbilityHelpers]). Merged with [member map01_enemy_kit] presets; same [enum PassiveCombatAbilityData.EffectKind] only once (array order wins over kit).
@export var passive_combat_abilities: Array[PassiveCombatAbilityData] = []

@export_category("Active combat abilities (cooldown)")
## Cooldown-gated actives (enemy AI / future player). State: [member Unit.active_ability_cooldowns]; helpers: [ActiveCombatAbilityHelpers].
@export var active_combat_abilities: Array[ActiveCombatAbilityData] = []

@export_category("Character Growth Rates (%)")
@export var hp_growth: int = 40
@export var str_growth: int = 30
@export var mag_growth: int = 20
@export var def_growth: int = 20
@export var res_growth: int = 20
@export var spd_growth: int = 30
@export var agi_growth: int = 30

@export_category("Loot Drops")
@export var min_gold_drop: int = 0
@export var max_gold_drop: int = 0
@export var drops_equipped_weapon: bool = false
@export var equipped_weapon_chance: int = 100
@export var extra_loot: Array[LootDrop] = []

static func unit_type_display_name(t: UnitType) -> String:
	match t:
		UnitType.UNSPECIFIED:
			return ""
		UnitType.HUMAN:
			return "Human"
		UnitType.ELF:
			return "Elf"
		UnitType.DWARF:
			return "Dwarf"
		UnitType.HALFLING:
			return "Halfling"
		UnitType.GOBLIN:
			return "Goblin"
		UnitType.ORC:
			return "Orc"
		UnitType.UNDEAD:
			return "Undead"
		UnitType.BEAST:
			return "Beast"
		UnitType.CONSTRUCT:
			return "Construct"
		UnitType.SPIRIT:
			return "Spirit"
		UnitType.ABERRATION:
			return "Aberration"
		UnitType.ELEMENTAL:
			return "Elemental"
		UnitType.DRAGON:
			return "Dragon"
	return ""


static func unit_type_suppresses_blood(t: UnitType) -> bool:
	return (
		t == UnitType.UNDEAD
		or t == UnitType.CONSTRUCT
		or t == UnitType.SPIRIT
		or t == UnitType.ABERRATION
		or t == UnitType.ELEMENTAL
	)


static func unit_type_uses_bone_hit_debris(t: UnitType) -> bool:
	return t == UnitType.UNDEAD


# Add this helper function at the bottom of the script
func get_random_death_quote() -> String:
	if death_quotes.is_empty():
		return "..." # Fallback just in case you forgot to add lines in the editor
	return death_quotes.pick_random()

func get_random_level_up_quote() -> String:
	if level_up_quotes.is_empty():
		return "..."
	return level_up_quotes.pick_random()
