extends Resource
class_name UnitData

@export var display_name: String = "Unit"
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
## Enemies only. If > 0, kills not dealt as bludgeoning collapse into a bone pile and reform after this many battle turn increments (end of enemy phase).
@export var bone_pile_reform_rounds: int = 0

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

# Add this helper function at the bottom of the script
func get_random_death_quote() -> String:
	if death_quotes.is_empty():
		return "..." # Fallback just in case you forgot to add lines in the editor
	return death_quotes.pick_random()

func get_random_level_up_quote() -> String:
	if level_up_quotes.is_empty():
		return "..."
	return level_up_quotes.pick_random()
