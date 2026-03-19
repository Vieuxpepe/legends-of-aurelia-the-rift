@tool
extends EditorScript

# ==========================================
# 1. ASSASSIN
# ==========================================
var assassin_data = [
	{"id": "assassin_spd_1", "grid_x": 0, "grid_y": 0, "req": "", "type": 0, "stat": "spd", "boost": 2, "ability": "", "name": "Silent Steps", "desc": "Grants +2 Speed."},
	{"id": "assassin_agi_1", "grid_x": 1, "grid_y": 0, "req": "assassin_spd_1", "type": 0, "stat": "agi", "boost": 2, "ability": "", "name": "Ghost Cloak", "desc": "Grants +2 Agility (Crit/Evasion)."},
	{"id": "assassin_str_1", "grid_x": 2, "grid_y": 0, "req": "assassin_agi_1", "type": 0, "stat": "str", "boost": 2, "ability": "", "name": "Lethal Tempo", "desc": "Grants +2 Strength."},
	{"id": "assassin_hp_1", "grid_x": 3, "grid_y": 0, "req": "assassin_str_1", "type": 0, "stat": "hp", "boost": 5, "ability": "", "name": "Assassin's Vigor", "desc": "Grants +5 Max HP."},
	{"id": "assassin_mastery", "grid_x": 4, "grid_y": 0, "req": "assassin_hp_1", "type": 1, "stat": "", "boost": 0, "ability": "Shadow Pin", "name": "Mastery: Shadow Pin", "desc": "Cripples the target, reducing their speed to 0 and preventing counter-attacks."}
]

# ==========================================
# 2. GENERAL
# ==========================================
var general_data = [
	{"id": "general_def_1", "grid_x": 0, "grid_y": 0, "req": "", "type": 0, "stat": "def", "boost": 3, "ability": "", "name": "Iron Plating", "desc": "Grants +3 Defense."},
	{"id": "general_hp_1", "grid_x": 1, "grid_y": 0, "req": "general_def_1", "type": 0, "stat": "hp", "boost": 10, "ability": "", "name": "Juggernaut", "desc": "Grants +10 Max HP."},
	{"id": "general_res_1", "grid_x": 2, "grid_y": 0, "req": "general_hp_1", "type": 0, "stat": "res", "boost": 2, "ability": "", "name": "Deflective Armor", "desc": "Grants +2 Resistance."},
	{"id": "general_str_1", "grid_x": 3, "grid_y": 0, "req": "general_res_1", "type": 0, "stat": "str", "boost": 2, "ability": "", "name": "Heavy Arms", "desc": "Grants +2 Strength."},
	{"id": "general_mastery", "grid_x": 4, "grid_y": 0, "req": "general_str_1", "type": 1, "stat": "", "boost": 0, "ability": "Weapon Shatter", "name": "Mastery: Weapon Shatter", "desc": "Defensively shatters the enemy's weapon, setting its durability to 0."}
]

# ==========================================
# 3. BERSERKER
# ==========================================
var berserker_data = [
	{"id": "berserker_str_1", "grid_x": 0, "grid_y": 0, "req": "", "type": 0, "stat": "str", "boost": 4, "ability": "", "name": "Boiling Blood", "desc": "Grants +4 Strength."},
	{"id": "berserker_hp_1", "grid_x": 1, "grid_y": 0, "req": "berserker_str_1", "type": 0, "stat": "hp", "boost": 8, "ability": "", "name": "Thick Hide", "desc": "Grants +8 Max HP."},
	{"id": "berserker_agi_1", "grid_x": 2, "grid_y": 0, "req": "berserker_hp_1", "type": 0, "stat": "agi", "boost": 3, "ability": "", "name": "Reckless Abandon", "desc": "Grants +3 Agility."},
	{"id": "berserker_spd_1", "grid_x": 3, "grid_y": 0, "req": "berserker_agi_1", "type": 0, "stat": "spd", "boost": 2, "ability": "", "name": "Unstoppable Force", "desc": "Grants +2 Speed."},
	{"id": "berserker_mastery", "grid_x": 4, "grid_y": 0, "req": "berserker_spd_1", "type": 1, "stat": "", "boost": 0, "ability": "Savage Toss", "name": "Mastery: Savage Toss", "desc": "Deals massive damage and hurls the enemy backward up to 3 tiles."}
]

# ==========================================
# 4. HERO
# ==========================================
var hero_data = [
	{"id": "hero_str_1", "grid_x": 0, "grid_y": 0, "req": "", "type": 0, "stat": "str", "boost": 2, "ability": "", "name": "Hero's Vigor", "desc": "Grants +2 Strength."},
	{"id": "hero_hp_1", "grid_x": 1, "grid_y": 0, "req": "hero_str_1", "type": 0, "stat": "hp", "boost": 5, "ability": "", "name": "Frontline Leader", "desc": "Grants +5 Max HP."},
	{"id": "hero_def_1", "grid_x": 2, "grid_y": 0, "req": "hero_hp_1", "type": 0, "stat": "def", "boost": 2, "ability": "", "name": "Inspiring Presence", "desc": "Grants +2 Defense."},
	{"id": "hero_spd_1", "grid_x": 3, "grid_y": 0, "req": "hero_def_1", "type": 0, "stat": "spd", "boost": 2, "ability": "", "name": "Glorious Charge", "desc": "Grants +2 Speed."},
	{"id": "hero_mastery", "grid_x": 4, "grid_y": 0, "req": "hero_spd_1", "type": 1, "stat": "", "boost": 0, "ability": "Vanguard's Rally", "name": "Mastery: Vanguard's Rally", "desc": "Damages the target and permanently buffs the strength and magic of all allies."}
]

# ==========================================
# 5. BLADE MASTER
# ==========================================
var blademaster_data = [
	{"id": "bm_str_1", "grid_x": 0, "grid_y": 0, "req": "", "type": 0, "stat": "str", "boost": 2, "ability": "", "name": "Sword Faire I", "desc": "Grants +2 Strength."},
	{"id": "bm_spd_1", "grid_x": 1, "grid_y": 0, "req": "bm_str_1", "type": 0, "stat": "spd", "boost": 2, "ability": "", "name": "Sword Faire II", "desc": "Grants +2 Speed."},
	{"id": "bm_agi_1", "grid_x": 2, "grid_y": 0, "req": "bm_spd_1", "type": 0, "stat": "agi", "boost": 3, "ability": "", "name": "Lethal Edge", "desc": "Grants +3 Agility."},
	{"id": "bm_hp_1", "grid_x": 3, "grid_y": 0, "req": "bm_agi_1", "type": 0, "stat": "hp", "boost": 5, "ability": "", "name": "Master's Resolve", "desc": "Grants +5 Max HP."},
	{"id": "bm_mastery", "grid_x": 4, "grid_y": 0, "req": "bm_hp_1", "type": 1, "stat": "", "boost": 0, "ability": "Severing Strike", "name": "Mastery: Severing Strike", "desc": "A flurry of three absolute precision cuts."}
]

# ==========================================
# 6. BLADE WEAVER
# ==========================================
var bladeweaver_data = [
	{"id": "bw_mag_1", "grid_x": 0, "grid_y": 0, "req": "", "type": 0, "stat": "mag", "boost": 2, "ability": "", "name": "Arcane Edge I", "desc": "Grants +2 Magic."},
	{"id": "bw_spd_1", "grid_x": 1, "grid_y": 0, "req": "bw_mag_1", "type": 0, "stat": "spd", "boost": 2, "ability": "", "name": "Arcane Edge II", "desc": "Grants +2 Speed."},
	{"id": "bw_res_1", "grid_x": 2, "grid_y": 0, "req": "bw_spd_1", "type": 0, "stat": "res", "boost": 2, "ability": "", "name": "Mystic Weaver", "desc": "Grants +2 Resistance."},
	{"id": "bw_str_1", "grid_x": 3, "grid_y": 0, "req": "bw_res_1", "type": 0, "stat": "str", "boost": 2, "ability": "", "name": "Enchanted Blade", "desc": "Grants +2 Strength."},
	{"id": "bw_mastery", "grid_x": 4, "grid_y": 0, "req": "bw_str_1", "type": 1, "stat": "", "boost": 0, "ability": "Aether Bind", "name": "Mastery: Aether Bind", "desc": "Harvests raw magic to temporarily massively boost attack power."}
]

# ==========================================
# 7. BOW KNIGHT
# ==========================================
var bowknight_data = [
	{"id": "bk_spd_1", "grid_x": 0, "grid_y": 0, "req": "", "type": 0, "stat": "spd", "boost": 3, "ability": "", "name": "Mounted Archery", "desc": "Grants +3 Speed."},
	{"id": "bk_str_1", "grid_x": 1, "grid_y": 0, "req": "bk_spd_1", "type": 0, "stat": "str", "boost": 2, "ability": "", "name": "Composite Bow", "desc": "Grants +2 Strength."},
	{"id": "bk_agi_1", "grid_x": 2, "grid_y": 0, "req": "bk_str_1", "type": 0, "stat": "agi", "boost": 2, "ability": "", "name": "Hit and Run", "desc": "Grants +2 Agility."},
	{"id": "bk_hp_1", "grid_x": 3, "grid_y": 0, "req": "bk_agi_1", "type": 0, "stat": "hp", "boost": 5, "ability": "", "name": "Cavalry Vigor", "desc": "Grants +5 Max HP."},
	{"id": "bk_mastery", "grid_x": 4, "grid_y": 0, "req": "bk_hp_1", "type": 1, "stat": "", "boost": 0, "ability": "Parting Shot", "name": "Mastery: Parting Shot", "desc": "Fires a devastating shot and instantly retreats one tile backward."}
]

# ==========================================
# 8. DEATH KNIGHT
# ==========================================
var deathknight_data = [
	{"id": "dk_mag_1", "grid_x": 0, "grid_y": 0, "req": "", "type": 0, "stat": "mag", "boost": 3, "ability": "", "name": "Dark Aura", "desc": "Grants +3 Magic."},
	{"id": "dk_str_1", "grid_x": 1, "grid_y": 0, "req": "dk_mag_1", "type": 0, "stat": "str", "boost": 2, "ability": "", "name": "Cursed Blade", "desc": "Grants +2 Strength."},
	{"id": "dk_def_1", "grid_x": 2, "grid_y": 0, "req": "dk_str_1", "type": 0, "stat": "def", "boost": 2, "ability": "", "name": "Dread Armor", "desc": "Grants +2 Defense."},
	{"id": "dk_hp_1", "grid_x": 3, "grid_y": 0, "req": "dk_def_1", "type": 0, "stat": "hp", "boost": 8, "ability": "", "name": "Undead Vigor", "desc": "Grants +8 Max HP."},
	{"id": "dk_mastery", "grid_x": 4, "grid_y": 0, "req": "dk_hp_1", "type": 1, "stat": "", "boost": 0, "ability": "Soul Harvest", "name": "Mastery: Soul Harvest", "desc": "Siphons the enemy's life force to massively heal the Death Knight."}
]

# ==========================================
# 9. DIVINE SAGE
# ==========================================
var divinesage_data = [
	{"id": "ds_mag_1", "grid_x": 0, "grid_y": 0, "req": "", "type": 0, "stat": "mag", "boost": 3, "ability": "", "name": "Holy Light I", "desc": "Grants +3 Magic."},
	{"id": "ds_res_1", "grid_x": 1, "grid_y": 0, "req": "ds_mag_1", "type": 0, "stat": "res", "boost": 3, "ability": "", "name": "Holy Light II", "desc": "Grants +3 Resistance."},
	{"id": "ds_hp_1", "grid_x": 2, "grid_y": 0, "req": "ds_res_1", "type": 0, "stat": "hp", "boost": 5, "ability": "", "name": "Divine Aura", "desc": "Grants +5 Max HP."},
	{"id": "ds_spd_1", "grid_x": 3, "grid_y": 0, "req": "ds_hp_1", "type": 0, "stat": "spd", "boost": 2, "ability": "", "name": "Heavenly Step", "desc": "Grants +2 Speed."},
	{"id": "ds_mastery", "grid_x": 4, "grid_y": 0, "req": "ds_spd_1", "type": 1, "stat": "", "boost": 0, "ability": "Celestial Choir", "name": "Mastery: Celestial Choir", "desc": "Defensively plays a heavenly melody that heals all player units on the map."}
]

# ==========================================
# 10. FIRE SAGE
# ==========================================
var firesage_data = [
	{"id": "fs_mag_1", "grid_x": 0, "grid_y": 0, "req": "", "type": 0, "stat": "mag", "boost": 4, "ability": "", "name": "Inferno I", "desc": "Grants +4 Magic."},
	{"id": "fs_spd_1", "grid_x": 1, "grid_y": 0, "req": "fs_mag_1", "type": 0, "stat": "spd", "boost": 2, "ability": "", "name": "Inferno II", "desc": "Grants +2 Speed."},
	{"id": "fs_res_1", "grid_x": 2, "grid_y": 0, "req": "fs_spd_1", "type": 0, "stat": "res", "boost": 2, "ability": "", "name": "Ash Cloak", "desc": "Grants +2 Resistance."},
	{"id": "fs_hp_1", "grid_x": 3, "grid_y": 0, "req": "fs_res_1", "type": 0, "stat": "hp", "boost": 5, "ability": "", "name": "Ember Vigor", "desc": "Grants +5 Max HP."},
	{"id": "fs_mastery", "grid_x": 4, "grid_y": 0, "req": "fs_hp_1", "type": 1, "stat": "", "boost": 0, "ability": "Hellfire", "name": "Mastery: Hellfire", "desc": "Deals heavy damage and permanently ignites the enemy, burning them every turn."}
]

# ==========================================
# 11. GREAT KNIGHT
# ==========================================
var greatknight_data = [
	{"id": "gk_def_1", "grid_x": 0, "grid_y": 0, "req": "", "type": 0, "stat": "def", "boost": 3, "ability": "", "name": "Heavy Cavalry I", "desc": "Grants +3 Defense."},
	{"id": "gk_str_1", "grid_x": 1, "grid_y": 0, "req": "gk_def_1", "type": 0, "stat": "str", "boost": 2, "ability": "", "name": "Heavy Cavalry II", "desc": "Grants +2 Strength."},
	{"id": "gk_hp_1", "grid_x": 2, "grid_y": 0, "req": "gk_str_1", "type": 0, "stat": "hp", "boost": 8, "ability": "", "name": "Armored Mount", "desc": "Grants +8 Max HP."},
	{"id": "gk_spd_1", "grid_x": 3, "grid_y": 0, "req": "gk_hp_1", "type": 0, "stat": "spd", "boost": 2, "ability": "", "name": "Trample", "desc": "Grants +2 Speed."},
	{"id": "gk_mastery", "grid_x": 4, "grid_y": 0, "req": "gk_spd_1", "type": 1, "stat": "", "boost": 0, "ability": "Phalanx", "name": "Mastery: Phalanx", "desc": "Defensively calls a formation, granting a massive defense buff to all player units."}
]

# ==========================================
# 12. HEAVY ARCHER
# ==========================================
var heavyarcher_data = [
	{"id": "ha_str_1", "grid_x": 0, "grid_y": 0, "req": "", "type": 0, "stat": "str", "boost": 3, "ability": "", "name": "Siege Bow I", "desc": "Grants +3 Strength."},
	{"id": "ha_def_1", "grid_x": 1, "grid_y": 0, "req": "ha_str_1", "type": 0, "stat": "def", "boost": 2, "ability": "", "name": "Siege Bow II", "desc": "Grants +2 Defense."},
	{"id": "ha_hp_1", "grid_x": 2, "grid_y": 0, "req": "ha_def_1", "type": 0, "stat": "hp", "boost": 5, "ability": "", "name": "Sniper's Nest", "desc": "Grants +5 Max HP."},
	{"id": "ha_agi_1", "grid_x": 3, "grid_y": 0, "req": "ha_hp_1", "type": 0, "stat": "agi", "boost": 2, "ability": "", "name": "Eagle Eye", "desc": "Grants +2 Agility."},
	{"id": "ha_mastery", "grid_x": 4, "grid_y": 0, "req": "ha_agi_1", "type": 1, "stat": "", "boost": 0, "ability": "Ballista Shot", "name": "Mastery: Ballista Shot", "desc": "Zooms in to deliver an earth-shattering critical strike."}
]

# ==========================================
# 13. HIGH PALADIN
# ==========================================
var highpaladin_data = [
	{"id": "hp_str_1", "grid_x": 0, "grid_y": 0, "req": "", "type": 0, "stat": "str", "boost": 2, "ability": "", "name": "Holy Knight I", "desc": "Grants +2 Strength."},
	{"id": "hp_res_1", "grid_x": 1, "grid_y": 0, "req": "hp_str_1", "type": 0, "stat": "res", "boost": 2, "ability": "", "name": "Holy Knight II", "desc": "Grants +2 Resistance."},
	{"id": "hp_def_1", "grid_x": 2, "grid_y": 0, "req": "hp_res_1", "type": 0, "stat": "def", "boost": 2, "ability": "", "name": "Aegis Shield", "desc": "Grants +2 Defense."},
	{"id": "hp_hp_1", "grid_x": 3, "grid_y": 0, "req": "hp_def_1", "type": 0, "stat": "hp", "boost": 8, "ability": "", "name": "Crusader's Vigor", "desc": "Grants +8 Max HP."},
	{"id": "hp_mastery", "grid_x": 4, "grid_y": 0, "req": "hp_hp_1", "type": 1, "stat": "", "boost": 0, "ability": "Aegis Strike", "name": "Mastery: Aegis Strike", "desc": "A holy cross attack that perfectly aligns to obliterate enemies."}
]


# --- EXECUTION LOGIC ---
const BASE_SAVE_DIRECTORY = "res://Resources/Skills/Generated/Promoted/"

func _run():
	var all_classes = {
		"Assassin": assassin_data,
		"Berserker": berserker_data,
		"BladeMaster": blademaster_data,
		"BladeWeaver": bladeweaver_data,
		"BowKnight": bowknight_data,
		"DeathKnight": deathknight_data,
		"DivineSage": divinesage_data,
		"FireSage": firesage_data,
		"General": general_data,
		"GreatKnight": greatknight_data,
		"HeavyArcher": heavyarcher_data,
		"Hero": hero_data,
		"HighPaladin": highpaladin_data
	}

	var dir = DirAccess.open("res://")
	
	# Loop through each class and generate their files!
	for c_name in all_classes.keys():
		var class_dir = BASE_SAVE_DIRECTORY + c_name + "/"
		
		# Create the specific class folder if it doesn't exist
		if not dir.dir_exists(class_dir):
			dir.make_dir_recursive(class_dir)

		var count = 0
		var current_array = all_classes[c_name]
		
		for data in current_array:
			var skill = SkillNode.new()
			
			skill.skill_id = data["id"]
			skill.skill_name = data.get("name", "Unknown Skill")
			skill.description = data.get("desc", "No description provided.")
			skill.required_skill_id = data["req"]
			skill.grid_position = Vector2(data["grid_x"], data["grid_y"])
			skill.effect_type = data["type"]
			skill.stat_to_boost = data["stat"]
			skill.boost_amount = data["boost"]
			skill.ability_to_unlock = data["ability"]
			
			var file_name = class_dir + "Skill_" + data["id"] + ".tres"
			ResourceSaver.save(skill, file_name)
			count += 1
			
		print("✅ Generated " + str(count) + " skills for " + c_name)
	
	print("🎉 ALL PROMOTED CLASSES GENERATED SUCCESSFULLY!")
