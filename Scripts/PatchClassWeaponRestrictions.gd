@tool
extends EditorScript

# Keep these aligned with WeaponData.gd
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

const CLASS_WEAPON_RULES := {
	# =========================================================================
	# ROOKIE CLASSES
	# =========================================================================
	"res://Resources/Classes/RookieClass/Recruit.tres": {
		"types": [WT_SWORD, WT_LANCE, WT_AXE],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/RookieClass/Apprentice.tres": {
		"types": [WT_TOME],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/RookieClass/Urchin.tres": {
		"types": [WT_KNIFE, WT_BOW],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/RookieClass/Novice.tres": {
		"types": [WT_FIST, WT_TOME],
		"heal": true, "buff": true, "debuff": false
	},
	"res://Resources/Classes/RookieClass/Villager.tres": {
		"types": [WT_AXE, WT_BOW],
		"heal": false, "buff": false, "debuff": false
	},

	# =========================================================================
	# NORMAL CLASSES
	# =========================================================================
	"res://Resources/Classes/Archer.tres": {
		"types": [WT_BOW],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/Cleric.tres": {
		"types": [WT_TOME],
		"heal": true, "buff": true, "debuff": true
	},
	"res://Resources/Classes/Knight.tres": {
		"types": [WT_LANCE],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/Mage.tres": {
		"types": [WT_TOME],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/Mercenary.tres": {
		"types": [WT_SWORD],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/Monk.tres": {
		"types": [WT_FIST],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/Monster.tres": {
		"types": [WT_NONE],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/Paladin.tres": {
		"types": [WT_SWORD, WT_LANCE],
		"heal": true, "buff": false, "debuff": false
	},
	"res://Resources/Classes/Spellblade.tres": {
		"types": [WT_SWORD, WT_TOME],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/Thief.tres": {
		"types": [WT_KNIFE],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/Warrior.tres": {
		"types": [WT_AXE],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/Flier.tres": {
		"types": [WT_LANCE],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/Dancer.tres": {
		"types": [WT_INSTRUMENT],
		"heal": true, "buff": true, "debuff": false
	},
	"res://Resources/Classes/Beastmaster.tres": {
		"types": [WT_AXE, WT_BOW],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/Cannoneer.tres": {
		"types": [WT_FIREARM],
		"heal": false, "buff": false, "debuff": false
	},

	# =========================================================================
	# PROMOTED CLASSES
	# =========================================================================
	"res://Resources/Classes/PromotedClass/Assassin.tres": {
		"types": [WT_KNIFE],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/PromotedClass/Berserker.tres": {
		"types": [WT_AXE],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/PromotedClass/BladeMaster.tres": {
		"types": [WT_SWORD],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/PromotedClass/BladeWeaver.tres": {
		"types": [WT_SWORD, WT_TOME],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/PromotedClass/BowKnight.tres": {
		"types": [WT_BOW, WT_SWORD],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/PromotedClass/DeathKnight.tres": {
		"types": [WT_SWORD, WT_DARK_TOME],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/PromotedClass/DivineSage.tres": {
		"types": [WT_TOME],
		"heal": true, "buff": true, "debuff": true
	},
	"res://Resources/Classes/PromotedClass/FireSage.tres": {
		"types": [WT_TOME],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/PromotedClass/General.tres": {
		"types": [WT_LANCE],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/PromotedClass/GreatKnight.tres": {
		"types": [WT_SWORD, WT_LANCE],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/PromotedClass/HeavyArcher.tres": {
		"types": [WT_BOW],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/PromotedClass/Hero.tres": {
		"types": [WT_SWORD, WT_AXE],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/PromotedClass/HighPaladin.tres": {
		"types": [WT_SWORD, WT_LANCE],
		"heal": true, "buff": true, "debuff": false
	},
	"res://Resources/Classes/PromotedClass/FalconKnight.tres": {
		"types": [WT_LANCE],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/PromotedClass/SkyVanguard.tres": {
		"types": [WT_LANCE],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/PromotedClass/Muse.tres": {
		"types": [WT_INSTRUMENT],
		"heal": true, "buff": true, "debuff": true
	},
	"res://Resources/Classes/PromotedClass/BladeDancer.tres": {
		"types": [WT_SWORD, WT_INSTRUMENT],
		"heal": false, "buff": true, "debuff": false
	},
	"res://Resources/Classes/PromotedClass/WildWarden.tres": {
		"types": [WT_AXE, WT_BOW],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/PromotedClass/PackLeader.tres": {
		"types": [WT_AXE, WT_FIST],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/PromotedClass/SiegeMaster.tres": {
		"types": [WT_FIREARM],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/PromotedClass/Dreadnought.tres": {
		"types": [WT_FIREARM, WT_SWORD],
		"heal": false, "buff": false, "debuff": false
	},

	# =========================================================================
	# ASCENDED CLASSES
	# =========================================================================
	"res://Resources/Classes/AscendedClass/DawnExalt.tres": {
		"types": [WT_SWORD, WT_TOME],
		"heal": true, "buff": true, "debuff": true
	},
	"res://Resources/Classes/AscendedClass/VoidStrider.tres": {
		"types": [WT_KNIFE, WT_DARK_TOME],
		"heal": false, "buff": false, "debuff": false
	},
	"res://Resources/Classes/AscendedClass/RiftArchon.tres": {
		"types": [WT_TOME, WT_DARK_TOME],
		"heal": false, "buff": false, "debuff": true
	}
}

func _run():
	var patched_count: int = 0

	for class_path_key in CLASS_WEAPON_RULES.keys():
		var class_path: String = String(class_path_key)
		var rules: Dictionary = CLASS_WEAPON_RULES[class_path_key]

		if not ResourceLoader.exists(class_path):
			push_warning("Missing class resource, skipped: " + class_path)
			continue

		var class_res = load(class_path)
		if class_res == null:
			push_warning("Could not load class resource: " + class_path)
			continue

		var raw_types: Array = rules["types"]
		var typed_types: Array[int] = []
		for raw_type in raw_types:
			typed_types.append(int(raw_type))

		class_res.allowed_weapon_types = typed_types
		class_res.can_use_healing_staff = bool(rules["heal"])
		class_res.can_use_buff_staff = bool(rules["buff"])
		class_res.can_use_debuff_staff = bool(rules["debuff"])

		var err: int = ResourceSaver.save(class_res, class_path)
		if err != OK:
			push_error("Failed to save class weapon restrictions: " + class_path)
		else:
			print("✅ Patched weapon restrictions for: " + class_path)
			patched_count += 1

	print("🎉 Weapon restriction patch complete! Patched classes: " + str(patched_count))
