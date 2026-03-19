@tool
extends EditorScript

const UNIT_DATA_SCRIPT := preload("res://Scripts/Core/UnitData.gd")
const OUTPUT_DIR := "res://Resources/Units/PlayableRoster/"

const CLASS_PATHS := {
	"Recruit": "res://Resources/Classes/RookieClass/Recruit.tres",
	"HighPaladin": "res://Resources/Classes/PromotedClass/HighPaladin.tres",
	"Warrior": "res://Resources/Classes/Warrior.tres",
	"Cleric": "res://Resources/Classes/Cleric.tres",
	"Thief": "res://Resources/Classes/Thief.tres",
	"Mage": "res://Resources/Classes/Mage.tres",
	"Mercenary": "res://Resources/Classes/Mercenary.tres",
	"Flier": "res://Resources/Classes/Flier.tres",
	"Cannoneer": "res://Resources/Classes/Cannoneer.tres",
	"Beastmaster": "res://Resources/Classes/Beastmaster.tres",
	"Apprentice": "res://Resources/Classes/RookieClass/Apprentice.tres",
	"Urchin": "res://Resources/Classes/RookieClass/Urchin.tres",
	"Monk": "res://Resources/Classes/Monk.tres",
	"Paladin": "res://Resources/Classes/Paladin.tres",
	"HeavyArcher": "res://Resources/Classes/PromotedClass/HeavyArcher.tres",
	"Dancer": "res://Resources/Classes/Dancer.tres",
	"Knight": "res://Resources/Classes/Knight.tres",
	"DeathKnight": "res://Resources/Classes/PromotedClass/DeathKnight.tres",
	"Archer": "res://Resources/Classes/Archer.tres"
}
const WEAPON_PATHS := {
	"Traveler's Blade": "res://Resources/GeneratedItems/Weapon_Travelers_Blade.tres",
	"Steel Sword": "res://Resources/GeneratedItems/Weapon_Steel_Sword.tres",
	"Bronze Axe": "res://Resources/GeneratedItems/Weapon_Bronze_Axe.tres",
	"Beginner's Staff": "res://Resources/GeneratedItems/Weapon_Beginners_Staff.tres",
	"Street Dirk": "res://Resources/GeneratedItems/Weapon_Street_Dirk.tres",
	"Apprentice Tome": "res://Resources/GeneratedItems/Weapon_Apprentice_Tome.tres",
	"Old Spear": "res://Resources/GeneratedItems/Weapon_Old_Spear.tres",
	"Militia Handgonne": "res://Resources/GeneratedItems/Weapon_Militia_Handgonne.tres",
	"Hatchet": "res://Resources/GeneratedItems/Weapon_Hatchet.tres",
	"Arcane Grimoire": "res://Resources/GeneratedItems/Weapon_Arcane_Grimoire.tres",
	"Ash Shortbow": "res://Resources/GeneratedItems/Weapon_Ash_Shortbow.tres",
	"Wooden Pike": "res://Resources/GeneratedItems/Weapon_Wooden_Pike.tres",
	"Sparkknife": "res://Resources/GeneratedItems/Weapon_Sparkknife.tres",
	"Pilgrim's Knuckles": "res://Resources/GeneratedItems/Weapon_Pilgrims_Knuckles.tres",
	"Ramshackle Culverin": "res://Resources/GeneratedItems/Weapon_Ramshackle_Culverin.tres",
	"Pike of Valor": "res://Resources/GeneratedItems/Weapon_Pike_of_Valor.tres",
	"Reinforced Bow": "res://Resources/GeneratedItems/Weapon_Reinforced_Bow.tres",
	"Silken Fan": "res://Resources/GeneratedItems/Weapon_Silken_Fan.tres",
	"Censure Staff": "res://Resources/GeneratedItems/Weapon_Censure_Staff.tres",
	"Gloam Primer": "res://Resources/GeneratedItems/Weapon_Gloam_Primer.tres",
	"Knight's Halberd": "res://Resources/GeneratedItems/Weapon_Knights_Halberd.tres",
	"Silver Lance": "res://Resources/GeneratedItems/Weapon_Silver_Lance.tres"
}

const PLAYABLE_UNITS := [
	{
		"id": "commander_template",
		"save_name": "01_Commander_Template",
		"display_name": "Commander",
		"source_name": "Avatar / Commander",
		"role": "The adaptive lead",
		"class_key": "Recruit",
		"starting_level": 1,
		"starting_weapon": "Traveler's Blade",
		"stats": {
			"hp": 19,
			"str": 5,
			"mag": 0,
			"skl": 6,
			"spd": 6,
			"lck": 5,
			"def": 4,
			"res": 2,
			"mov": 5
		},
		"growths": {
			"hp": 75,
			"str": 45,
			"mag": 20,
			"skl": 55,
			"spd": 50,
			"lck": 45,
			"def": 35,
			"res": 25
		},
		"death_quotes": [
			"So this is where my road ends… then make sure it leads somewhere kinder.",
			"If I can’t go on, then go farther than I did.",
			"Don’t let my ending become an excuse to stop.",
            "I wanted to save something small and human… promise me that still matters."
		],
		"level_up_quotes": [
			"Then I can carry a little more than I could before.",
			"Good. I’m not the same person who left Oakhaven.",
            "If this strength means anything, I’ll make it mean protection."
		],
		"is_custom_avatar_template": true,
		"support_personality": "heroic"
	},
	{
		"id": "kaelen",
		"save_name": "02_Kaelen",
		"display_name": "Kaelen",
		"source_name": "Kaelen",
		"role": "The “Jagen” pre-promote mentor",
		"class_key": "HighPaladin",
		"starting_level": 4,
		"starting_weapon": "Steel Sword",
		"stats": {
			"hp": 33,
			"str": 13,
			"mag": 2,
			"skl": 14,
			"spd": 11,
			"lck": 7,
			"def": 12,
			"res": 8,
			"mov": 7
		},
		"growths": {
			"hp": 45,
			"str": 35,
			"mag": 10,
			"skl": 40,
			"spd": 30,
			"lck": 25,
			"def": 35,
			"res": 20
		},
		"death_quotes": [
			"Damn it… I was supposed to get you through this, not leave you in it.",
			"So this is my part done. Make yours count.",
			"Don’t stand there grieving — survive first, regret later.",
            "Tch… should’ve known I wouldn’t get to see how this ends."
		],
		"level_up_quotes": [
			"There. Slightly less likely to die doing something stupid.",
			"Good. Maybe now I can stop doing everyone else’s work for them.",
            "Hnh. Rust scrapes off eventually."
		],
		"is_custom_avatar_template": false,
		"support_personality": "stoic"
	},
	{
		"id": "branik",
		"save_name": "03_Branik",
		"display_name": "Branik",
		"source_name": "Branik",
		"role": "The dependable bruiser wall",
		"class_key": "Warrior",
		"starting_level": 5,
		"starting_weapon": "Bronze Axe",
		"stats": {
			"hp": 30,
			"str": 11,
			"mag": 0,
			"skl": 8,
			"spd": 6,
			"lck": 5,
			"def": 10,
			"res": 3,
			"mov": 5
		},
		"growths": {
			"hp": 85,
			"str": 60,
			"mag": 5,
			"skl": 35,
			"spd": 25,
			"lck": 30,
			"def": 50,
			"res": 15
		},
		"death_quotes": [
			"It’s all right… just keep the fire going, and make sure everyone eats.",
			"Look after each other. That matters more than anything.",
			"If someone’s frightened, stay with them. No one should go through this alone.",
            "Ah… that’s enough from me. You keep the others warm."
		],
		"level_up_quotes": [
			"That’s good. Means I can keep standing a bit longer.",
			"All right. One more reason not to let anyone through.",
            "If this helps somebody get home, it’s worth having."
		],
		"is_custom_avatar_template": false,
		"support_personality": "warm"
	},
	{
		"id": "liora",
		"save_name": "04_Liora",
		"display_name": "Liora",
		"source_name": "Liora",
		"role": "Primary cleric / conscience support",
		"class_key": "Cleric",
		"starting_level": 3,
		"starting_weapon": "Beginner's Staff",
		"stats": {
			"hp": 19,
			"str": 1,
			"mag": 8,
			"skl": 6,
			"spd": 5,
			"lck": 4,
			"def": 2,
			"res": 9,
			"mov": 5
		},
		"growths": {
			"hp": 50,
			"str": 5,
			"mag": 60,
			"skl": 45,
			"spd": 35,
			"lck": 30,
			"def": 10,
			"res": 55
		},
		"death_quotes": [
			"If mercy still means anything, let it live longer in you than it did in me.",
			"Do not use my death to justify cruelty.",
			"Faith is not fear… please remember that better than they did.",
            "If there is light left in this world, carry it gently."
		],
		"level_up_quotes": [
			"Then let this be another gift I use in service, not pride.",
			"I feel steadier now. That matters.",
            "Good. Faith should strengthen the hand as well as the heart."
		],
		"is_custom_avatar_template": false,
		"support_personality": "compassionate"
	},
	{
		"id": "nyx",
		"save_name": "05_Nyx",
		"display_name": "Nyx",
		"source_name": "Nyx",
		"role": "Early utility thief / dodge skirmisher",
		"class_key": "Thief",
		"starting_level": 2,
		"starting_weapon": "Street Dirk",
		"stats": {
			"hp": 18,
			"str": 4,
			"mag": 1,
			"skl": 7,
			"spd": 9,
			"lck": 6,
			"def": 2,
			"res": 3,
			"mov": 6
		},
		"growths": {
			"hp": 55,
			"str": 30,
			"mag": 20,
			"skl": 60,
			"spd": 70,
			"lck": 50,
			"def": 15,
			"res": 25
		},
		"death_quotes": [
			"Heh… figures I finally trusted people worth dying for.",
			"Well, that’s embarrassing. Don’t let them touch my things.",
			"Guess this is what I get for sticking around.",
            "Tch… if you survive, make it messy enough to honor me."
		],
		"level_up_quotes": [
			"Oh, excellent. I’m becoming even harder to catch.",
			"Nice. Love when the universe rewards bad habits and good reflexes.",
            "There we go — sharper hands, better odds."
		],
		"is_custom_avatar_template": false,
		"support_personality": "sly"
	},
	{
		"id": "sorrel",
		"save_name": "06_Sorrel",
		"display_name": "Sorrel",
		"source_name": "Sorrel",
		"role": "Frail scholar glass cannon",
		"class_key": "Mage",
		"starting_level": 3,
		"starting_weapon": "Apprentice Tome",
		"stats": {
			"hp": 17,
			"str": 0,
			"mag": 8,
			"skl": 7,
			"spd": 6,
			"lck": 2,
			"def": 1,
			"res": 6,
			"mov": 5
		},
		"growths": {
			"hp": 45,
			"str": 5,
			"mag": 70,
			"skl": 55,
			"spd": 45,
			"lck": 20,
			"def": 10,
			"res": 40
		},
		"death_quotes": [
			"So much left unread… promise me ignorance won’t inherit this.",
			"There were still answers here… do not let fools bury them.",
			"Ah. So inquiry ends, but consequence does not.",
            "If you learn anything from this, let it be something worth the cost."
		],
		"level_up_quotes": [
			"Remarkable. Applied survival continues to produce useful outcomes.",
			"Ah. That is a meaningful improvement, not merely a flattering one.",
            "Excellent. I should like to remain alive long enough to study this further."
		],
		"is_custom_avatar_template": false,
		"support_personality": "scholarly"
	},
	{
		"id": "darian",
		"save_name": "07_Darian",
		"display_name": "Darian",
		"source_name": "Darian",
		"role": "Stylish duelist carry",
		"class_key": "Mercenary",
		"starting_level": 4,
		"starting_weapon": "Traveler's Blade",
		"stats": {
			"hp": 24,
			"str": 8,
			"mag": 1,
			"skl": 9,
			"spd": 10,
			"lck": 7,
			"def": 6,
			"res": 3,
			"mov": 5
		},
		"growths": {
			"hp": 65,
			"str": 45,
			"mag": 20,
			"skl": 60,
			"spd": 60,
			"lck": 45,
			"def": 25,
			"res": 20
		},
		"death_quotes": [
			"What an ugly end for a man so devoted to better exits.",
			"Well… at least I had the decency to fall dramatically.",
			"If you speak of me later, do try to improve the poetry.",
            "So this is sincerity without performance. How unfortunate."
		],
		"level_up_quotes": [
			"Well now, that was almost enough to make hardship feel artistically worthwhile.",
			"Good. Grace is best supported by actual competence.",
            "I do adore progress when it arrives dressed this well."
		],
		"is_custom_avatar_template": false,
		"support_personality": "flamboyant"
	},
	{
		"id": "celia",
		"save_name": "08_Celia",
		"display_name": "Celia",
		"source_name": "Celia",
		"role": "Disciplined aerial lancer",
		"class_key": "Flier",
		"starting_level": 6,
		"starting_weapon": "Old Spear",
		"stats": {
			"hp": 25,
			"str": 9,
			"mag": 0,
			"skl": 10,
			"spd": 11,
			"lck": 6,
			"def": 7,
			"res": 8,
			"mov": 7
		},
		"growths": {
			"hp": 60,
			"str": 45,
			"mag": 15,
			"skl": 55,
			"spd": 60,
			"lck": 35,
			"def": 25,
			"res": 40
		},
		"death_quotes": [
			"I chose this path myself… do not dishonor it by calling me only obedient.",
			"Do not pity me. Stand where I stood.",
			"This was my will, not theirs.",
            "If duty survives me, let it be kinder in your hands."
		],
		"level_up_quotes": [
			"Then my training was not wasted.",
			"Good. I can answer more of what is asked of me.",
            "Strength chosen freely feels different."
		],
		"is_custom_avatar_template": false,
		"support_personality": "disciplined"
	},
	{
		"id": "rufus",
		"save_name": "09_Rufus",
		"display_name": "Rufus",
		"source_name": "Rufus",
		"role": "Early siege chip / anti-armor gunner",
		"class_key": "Cannoneer",
		"starting_level": 4,
		"starting_weapon": "Militia Handgonne",
		"stats": {
			"hp": 27,
			"str": 10,
			"mag": 0,
			"skl": 9,
			"spd": 4,
			"lck": 4,
			"def": 8,
			"res": 2,
			"mov": 4
		},
		"growths": {
			"hp": 75,
			"str": 55,
			"mag": 5,
			"skl": 50,
			"spd": 20,
			"lck": 25,
			"def": 35,
			"res": 15
		},
		"death_quotes": [
			"Right… then quit staring and finish the job before somebody poorer pays for it.",
			"Don’t waste time on me. The world’s already expensive enough.",
			"Yeah, all right… I’ve carried my share. Carry yours.",
            "If someone has to pay for this war, make it them for once."
		],
		"level_up_quotes": [
			"All right. That’ll do nicely.",
			"Good. Always appreciated when hard living starts paying dividends.",
            "Bit more bite in me yet. Useful."
		],
		"is_custom_avatar_template": false,
		"support_personality": "pragmatic"
	},
	{
		"id": "inez",
		"save_name": "10_Inez",
		"display_name": "Inez",
		"source_name": "Inez",
		"role": "Mobile beast skirmisher",
		"class_key": "Beastmaster",
		"starting_level": 5,
		"starting_weapon": "Hatchet",
		"stats": {
			"hp": 25,
			"str": 8,
			"mag": 0,
			"skl": 10,
			"spd": 10,
			"lck": 7,
			"def": 5,
			"res": 4,
			"mov": 6
		},
		"growths": {
			"hp": 60,
			"str": 45,
			"mag": 15,
			"skl": 55,
			"spd": 60,
			"lck": 45,
			"def": 25,
			"res": 25
		},
		"death_quotes": [
			"Listen to the ground… it will tell you what still needs protecting.",
			"The land keeps score. Don’t fail it.",
			"Stay quiet. Watch the trees. Live.",
            "I’m done. The wild isn’t."
		],
		"level_up_quotes": [
			"Better. I won’t fall behind the hunt.",
			"The body learns, or it dies. Good.",
            "Useful. The woods favor those who notice change."
		],
		"is_custom_avatar_template": false,
		"support_personality": "wild"
	},
	{
		"id": "tariq",
		"save_name": "11_Tariq",
		"display_name": "Tariq",
		"source_name": "Tariq",
		"role": "Arcane sniper / precision mage",
		"class_key": "Mage",
		"starting_level": 7,
		"starting_weapon": "Arcane Grimoire",
		"stats": {
			"hp": 22,
			"str": 0,
			"mag": 11,
			"skl": 11,
			"spd": 8,
			"lck": 3,
			"def": 3,
			"res": 8,
			"mov": 5
		},
		"growths": {
			"hp": 50,
			"str": 0,
			"mag": 65,
			"skl": 60,
			"spd": 45,
			"lck": 20,
			"def": 15,
			"res": 45
		},
		"death_quotes": [
			"How irritating… after all that, I turn out to be exactly as mortal as advertised.",
			"So that is the final correction. Fine.",
			"I had hoped for a more intellectually satisfying conclusion.",
            "Don’t become sentimental on my behalf. Become effective."
		],
		"level_up_quotes": [
			"Well. Apparently I remain annoyingly effective.",
			"Good. Competence continues to justify my presence.",
            "Mm. Refinement, not luck. Much preferred."
		],
		"is_custom_avatar_template": false,
		"support_personality": "sardonic"
	},
	{
		"id": "mira_ashdown",
		"save_name": "12_Mira_Ashdown",
		"display_name": "Mira Ashdown",
		"source_name": "Mira Ashdown",
		"role": "Growth sniper carry",
		"class_key": "Archer",
		"starting_level": 2,
		"starting_weapon": "Ash Shortbow",
		"stats": {
			"hp": 17,
			"str": 5,
			"mag": 0,
			"skl": 8,
			"spd": 7,
			"lck": 6,
			"def": 3,
			"res": 2,
			"mov": 5
		},
		"growths": {
			"hp": 55,
			"str": 50,
			"mag": 10,
			"skl": 70,
			"spd": 65,
			"lck": 45,
			"def": 20,
			"res": 25
		},
		"death_quotes": [
			"Don’t make Oakhaven into a story people use to feel noble.",
			"Remember what happened. Remember it properly.",
			"I didn’t survive that far just to be turned into a symbol.",
            "If you say my name later, say it like a person, not a tragedy."
		],
		"level_up_quotes": [
			"Good. I can make this count.",
			"I’m getting stronger. That matters.",
            "Then I’ll be harder to break next time."
		],
		"is_custom_avatar_template": false,
		"support_personality": "heroic"
	},
	{
		"id": "pell_rowan",
		"save_name": "13_Pell_Rowan",
		"display_name": "Pell Rowan",
		"source_name": "Pell Rowan",
		"role": "Idealistic trainee lancer",
		"class_key": "Recruit",
		"starting_level": 1,
		"starting_weapon": "Wooden Pike",
		"stats": {
			"hp": 20,
			"str": 5,
			"mag": 0,
			"skl": 4,
			"spd": 5,
			"lck": 4,
			"def": 5,
			"res": 1,
			"mov": 5
		},
		"growths": {
			"hp": 80,
			"str": 55,
			"mag": 5,
			"skl": 45,
			"spd": 45,
			"lck": 35,
			"def": 40,
			"res": 15
		},
		"death_quotes": [
			"I wanted to be brave… I hope, at least once, I managed it for real.",
			"Please… don’t let me have been pretending all along.",
			"Tell them I was trying. Truly trying.",
            "I was afraid. I just… didn’t want fear to be the last thing."
		],
		"level_up_quotes": [
			"Really? Then I mustn’t waste it!",
			"Good! I’m improving — properly improving!",
            "All right. One step closer to the knight I mean to be."
		],
		"is_custom_avatar_template": false,
		"support_personality": "earnest"
	},
	{
		"id": "tamsin_reed",
		"save_name": "14_Tamsin_Reed",
		"display_name": "Tamsin Reed",
		"source_name": "Tamsin Reed",
		"role": "The “Est” support bloom unit",
		"class_key": "Apprentice",
		"starting_level": 1,
		"starting_weapon": "Beginner's Staff",
		"stats": {
			"hp": 16,
			"str": 0,
			"mag": 5,
			"skl": 5,
			"spd": 4,
			"lck": 5,
			"def": 1,
			"res": 6,
			"mov": 5
		},
		"growths": {
			"hp": 45,
			"str": 0,
			"mag": 65,
			"skl": 50,
			"spd": 40,
			"lck": 45,
			"def": 10,
			"res": 60
		},
		"death_quotes": [
			"No, no — don’t stop because of me… there are still people who need you.",
			"It’s all right… help the ones you still can.",
			"Please don’t waste time grieving while someone else is bleeding.",
            "I know I’m scared. Just… don’t let that be what survives of me."
		],
		"level_up_quotes": [
			"Oh. Oh, that’s… actually very encouraging.",
			"All right, breathe. I can use this.",
            "Good. Maybe next time I’ll panic a little less first."
		],
		"is_custom_avatar_template": false,
		"support_personality": "chaotic"
	},
	{
		"id": "hest_sparks",
		"save_name": "15_Hest_Sparks",
		"display_name": "Hest “Sparks”",
		"source_name": "Hest “Sparks”",
		"role": "Chaotic trickster project",
		"class_key": "Urchin",
		"starting_level": 1,
		"starting_weapon": "Sparkknife",
		"stats": {
			"hp": 17,
			"str": 3,
			"mag": 3,
			"skl": 6,
			"spd": 8,
			"lck": 7,
			"def": 1,
			"res": 3,
			"mov": 6
		},
		"growths": {
			"hp": 50,
			"str": 20,
			"mag": 40,
			"skl": 60,
			"spd": 70,
			"lck": 60,
			"def": 10,
			"res": 25
		},
		"death_quotes": [
			"Wow… that’s rude; I was just starting to think this lot might keep me.",
			"Heh… guess I finally pushed one bad joke too far.",
			"Don’t go all sad on me now. Win first.",
            "So much for sticking the landing."
		],
		"level_up_quotes": [
			"Ha! I knew being reckless was building character.",
			"Look at that — premium-grade disaster goblin.",
            "Oh, this is fantastic. I’m getting away with even more now."
		],
		"is_custom_avatar_template": false,
		"support_personality": "devout"
	},
	{
		"id": "brother_alden",
		"save_name": "16_Brother_Alden",
		"display_name": "Brother Alden",
		"source_name": "Brother Alden",
		"role": "Holy bruiser / sustain frontline",
		"class_key": "Monk",
		"starting_level": 7,
		"starting_weapon": "Pilgrim's Knuckles",
		"stats": {
			"hp": 29,
			"str": 10,
			"mag": 4,
			"skl": 8,
			"spd": 7,
			"lck": 5,
			"def": 8,
			"res": 9,
			"mov": 5
		},
		"growths": {
			"hp": 75,
			"str": 50,
			"mag": 25,
			"skl": 40,
			"spd": 35,
			"lck": 30,
			"def": 35,
			"res": 45
		},
		"death_quotes": [
			"Then let my body fail if it must — only do not let your mercy fail with it.",
			"Stand firm. Be gentle. Those two things were never opposites.",
			"If pain must remain, let it at least teach compassion.",
            "I go in peace. See that you do not abandon yours."
		],
		"level_up_quotes": [
			"Then I am better prepared for what others place in my hands.",
			"Good. Let this be strength with purpose.",
            "If I am made stronger, let it be for steadiness."
		],
		"is_custom_avatar_template": false,
		"support_personality": "pragmatic"
	},
	{
		"id": "oren_pike",
		"save_name": "17_Oren_Pike",
		"display_name": "Oren Pike",
		"source_name": "Oren Pike",
		"role": "Precision siege technician",
		"class_key": "Cannoneer",
		"starting_level": 6,
		"starting_weapon": "Ramshackle Culverin",
		"stats": {
			"hp": 28,
			"str": 9,
			"mag": 0,
			"skl": 11,
			"spd": 3,
			"lck": 2,
			"def": 9,
			"res": 2,
			"mov": 4
		},
		"growths": {
			"hp": 70,
			"str": 45,
			"mag": 5,
			"skl": 60,
			"spd": 15,
			"lck": 20,
			"def": 40,
			"res": 15
		},
		"death_quotes": [
			"Tch… don’t waste this; I’d hate to die and still be surrounded by incompetence.",
			"Use the tools properly. I refuse to haunt idiots.",
			"Wonderful. I expire once, and now all the maintenance becomes your problem.",
            "If this line collapses after I’m gone, I will be deeply annoyed."
		],
		"level_up_quotes": [
			"There. Tangible results. Imagine that.",
			"Good. At least something around here improves on schedule.",
            "Mm. Functional, efficient, and not entirely embarrassing."
		],
		"is_custom_avatar_template": false,
		"support_personality": "disciplined"
	},
	{
		"id": "garrick_vale",
		"save_name": "18_Garrick_Vale",
		"display_name": "Garrick Vale",
		"source_name": "Garrick Vale",
		"role": "Honest-stat cavalry anchor",
		"class_key": "Paladin",
		"starting_level": 8,
		"starting_weapon": "Pike of Valor",
		"stats": {
			"hp": 31,
			"str": 10,
			"mag": 0,
			"skl": 11,
			"spd": 9,
			"lck": 6,
			"def": 10,
			"res": 6,
			"mov": 7
		},
		"growths": {
			"hp": 70,
			"str": 45,
			"mag": 5,
			"skl": 50,
			"spd": 40,
			"lck": 30,
			"def": 35,
			"res": 25
		},
		"death_quotes": [
			"If duty means anything, let it be this: protect the living, not the throne.",
			"Then let my oath die with me, not my conscience.",
			"A kingdom is not its crown. Remember that.",
            "I served too much that was unworthy. Do better with what remains."
		],
		"level_up_quotes": [
			"Good. Then I can meet the next test with clearer hands.",
			"Discipline answered. As it should.",
            "Then I remain fit to serve something better than what I was given."
		],
		"is_custom_avatar_template": false,
		"support_personality": "severe"
	},
	{
		"id": "sabine_varr",
		"save_name": "19_Sabine_Varr",
		"display_name": "Sabine Varr",
		"source_name": "Sabine Varr",
		"role": "Pre-promote heavy archer specialist",
		"class_key": "HeavyArcher",
		"starting_level": 2,
		"starting_weapon": "Reinforced Bow",
		"stats": {
			"hp": 30,
			"str": 12,
			"mag": 0,
			"skl": 13,
			"spd": 6,
			"lck": 4,
			"def": 9,
			"res": 4,
			"mov": 5
		},
		"growths": {
			"hp": 60,
			"str": 45,
			"mag": 5,
			"skl": 55,
			"spd": 25,
			"lck": 20,
			"def": 30,
			"res": 20
		},
		"death_quotes": [
			"Do not turn this into sentiment; secure the line, then grieve properly.",
			"Focus. Emotion after the perimeter holds.",
			"If my death creates disorder, then you learned nothing from me.",
            "Stay sharp. The threat does not pause for mourning."
		],
		"level_up_quotes": [
			"Improvement confirmed.",
			"Good. Precision should never remain static.",
            "Useful. I prefer growth that can be verified."
		],
		"is_custom_avatar_template": false,
		"support_personality": "flamboyant"
	},
	{
		"id": "yselle_maris",
		"save_name": "20_Yselle_Maris",
		"display_name": "Yselle Maris",
		"source_name": "Yselle Maris",
		"role": "Pure dancer force multiplier",
		"class_key": "Dancer",
		"starting_level": 6,
		"starting_weapon": "Silken Fan",
		"stats": {
			"hp": 22,
			"str": 2,
			"mag": 3,
			"skl": 7,
			"spd": 12,
			"lck": 10,
			"def": 3,
			"res": 8,
			"mov": 5
		},
		"growths": {
			"hp": 45,
			"str": 10,
			"mag": 30,
			"skl": 45,
			"spd": 70,
			"lck": 60,
			"def": 15,
			"res": 40
		},
		"death_quotes": [
			"If I must leave the stage, at least let the living remember why beauty mattered.",
			"Do not let war make ugliness your only language.",
			"I spent my life teaching people to look — now make them see.",
            "If the curtain falls, let it fall on something worth remembering."
		],
		"level_up_quotes": [
			"Ah. A stronger step, and a room that will feel it.",
			"Delightful. Survival continues to reward polish.",
            "Good. Beauty is far more persuasive when it can endure."
		],
		"is_custom_avatar_template": false,
		"support_personality": "severe"
	},
	{
		"id": "sister_meris",
		"save_name": "21_Sister_Meris",
		"display_name": "Sister Meris",
		"source_name": "Sister Meris",
		"role": "Debuff support / severe staff specialist",
		"class_key": "Cleric",
		"starting_level": 8,
		"starting_weapon": "Censure Staff",
		"stats": {
			"hp": 23,
			"str": 1,
			"mag": 10,
			"skl": 11,
			"spd": 7,
			"lck": 2,
			"def": 4,
			"res": 10,
			"mov": 5
		},
		"growths": {
			"hp": 50,
			"str": 5,
			"mag": 55,
			"skl": 60,
			"spd": 35,
			"lck": 20,
			"def": 20,
			"res": 55
		},
		"death_quotes": [
			"I spent too long mistaking severity for righteousness… do better than I did.",
			"So this is the weight of judgment without excuse.",
			"If penance means anything, let it spare someone after me.",
            "I was wrong in ways discipline could not cleanse."
		],
		"level_up_quotes": [
			"Then I will make stricter use of what remains to me.",
			"Good. Let discipline finally serve the right end.",
            "Another measure of strength. May I deserve it better now."
		],
		"is_custom_avatar_template": false,
		"support_personality": "occult"
	},
	{
		"id": "corvin_ash",
		"save_name": "22_Corvin_Ash",
		"display_name": "Corvin Ash",
		"source_name": "Corvin Ash",
		"role": "Forbidden dark mage / risky nuke",
		"class_key": "Mage",
		"starting_level": 8,
		"starting_weapon": "Gloam Primer",
		"stats": {
			"hp": 22,
			"str": 0,
			"mag": 12,
			"skl": 10,
			"spd": 8,
			"lck": 1,
			"def": 2,
			"res": 10,
			"mov": 5
		},
		"growths": {
			"hp": 45,
			"str": 0,
			"mag": 70,
			"skl": 50,
			"spd": 40,
			"lck": 15,
			"def": 10,
			"res": 55
		},
		"death_quotes": [
			"So this is the final threshold… less mysterious than I’d hoped, but honest.",
			"Interesting. In the end, death proves disappointingly literal.",
			"Then let this be one truth I do not misname.",
            "I studied darkness long enough to know this part was always mine."
		],
		"level_up_quotes": [
			"Interesting. I can feel the boundary thinning.",
			"Ah. Growth always feels a little like trespass.",
            "Good. Another refinement in the anatomy of power."
		],
		"is_custom_avatar_template": false,
		"support_personality": "stoic"
	},
	{
		"id": "veska_moor",
		"save_name": "23_Veska_Moor",
		"display_name": "Veska Moor",
		"source_name": "Veska Moor",
		"role": "Fortress tank",
		"class_key": "Knight",
		"starting_level": 10,
		"starting_weapon": "Knight's Halberd",
		"stats": {
			"hp": 33,
			"str": 11,
			"mag": 0,
			"skl": 8,
			"spd": 4,
			"lck": 3,
			"def": 13,
			"res": 4,
			"mov": 4
		},
		"growths": {
			"hp": 80,
			"str": 50,
			"mag": 5,
			"skl": 40,
			"spd": 20,
			"lck": 25,
			"def": 55,
			"res": 20
		},
		"death_quotes": [
			"I held as long as I could; now you hold.",
			"The wall doesn’t mourn. It stands.",
			"Don’t make speeches. Close the gap.",
            "If I fall, then someone else plants their feet here."
		],
		"level_up_quotes": [
			"Better. I won’t bend as easily.",
			"Good. More weight to put between danger and the others.",
            "That helps. Simple as that."
		],
		"is_custom_avatar_template": false,
		"support_personality": "haunted"
	},
	{
		"id": "ser_hadrien",
		"save_name": "24_Ser_Hadrien",
		"display_name": "Ser Hadrien",
		"source_name": "Ser Hadrien",
		"role": "Late-game elite wraith knight",
		"class_key": "DeathKnight",
		"starting_level": 6,
		"starting_weapon": "Silver Lance",
		"stats": {
			"hp": 36,
			"str": 14,
			"mag": 3,
			"skl": 13,
			"spd": 10,
			"lck": 5,
			"def": 11,
			"res": 9,
			"mov": 7
		},
		"growths": {
			"hp": 45,
			"str": 35,
			"mag": 10,
			"skl": 40,
			"spd": 30,
			"lck": 20,
			"def": 35,
			"res": 30
		},
		"death_quotes": [
			"Then let this borrowed life return to memory, and let the living finish the oath.",
			"At last… the dead may release what the living still must carry.",
			"Do not make a relic of me. Make use of what I believed.",
            "My vigil ends. Yours must not."
		],
		"level_up_quotes": [
			"So even now, the edge may yet be honed.",
			"Curious. This old oath still finds new strength.",
            "Then memory has not finished with me."
		],
		"is_custom_avatar_template": false,
		"support_personality": "spirited"
	},
	{
		"id": "maela_thorn",
		"save_name": "25_Maela_Thorn",
		"display_name": "Maela Thorn",
		"source_name": "Maela Thorn",
		"role": "Speed flier / snowball harrier",
		"class_key": "Flier",
		"starting_level": 8,
		"starting_weapon": "Old Spear",
		"stats": {
			"hp": 24,
			"str": 8,
			"mag": 0,
			"skl": 10,
			"spd": 13,
			"lck": 8,
			"def": 5,
			"res": 6,
			"mov": 7
		},
		"growths": {
			"hp": 55,
			"str": 40,
			"mag": 10,
			"skl": 55,
			"spd": 70,
			"lck": 45,
			"def": 20,
			"res": 25
		},
		"death_quotes": [
			"Damn… I really thought I had one more sky left in me.",
			"Heh… tell me that at least looked impressive.",
			"So that’s it. Ground finally caught me.",
            "Don’t slow down because of me. Fly harder."
		],
		"level_up_quotes": [
			"Oh, that’s lovely. I feel faster already.",
			"Ha! That’s what momentum’s supposed to feel like.",
            "Good luck catching me now."
		],
		"is_custom_avatar_template": false
	}
]

func _run() -> void:
	_ensure_dir(OUTPUT_DIR)

	var created := 0
	var updated := 0
	var failures := 0

	for cfg in PLAYABLE_UNITS:
		var save_path := OUTPUT_DIR + String(cfg.get("save_name", "Unit")) + ".tres"
		var existed := ResourceLoader.exists(save_path)
		var unit_data := _build_unit_data(cfg)

		if unit_data == null:
			failures += 1
			continue

		var err := ResourceSaver.save(unit_data, save_path)
		if err != OK:
			push_error("Failed to save playable resource: %s (err=%s)" % [save_path, str(err)])
			failures += 1
		else:
			if existed:
				updated += 1
				print("♻️ Updated: %s" % save_path)
			else:
				created += 1
				print("✅ Created: %s" % save_path)

	print("\n===== PLAYABLE UNITDATA GENERATION COMPLETE =====")
	print("Created: %d | Updated: %d | Failed: %d" % [created, updated, failures])
	print("\nSKL from your design docs is mapped to agility in your current UnitData schema.")
	print("LCK and MOV remain in the companion roster seed file because UnitData does not store them directly.")

func _build_unit_data(cfg: Dictionary) -> Resource:
	var data = UNIT_DATA_SCRIPT.new()
	if data == null:
		push_error("Could not instantiate UnitData from res://Scripts/Core/UnitData.gd")
		return null

	data.display_name = String(cfg.get("display_name", "Unit"))
	data.is_recruitable = false

	data.recruit_dialogue.clear()
	data.pre_battle_quote.clear()

	data.death_quotes = _string_array(cfg.get("death_quotes", []))
	data.level_up_quotes = _string_array(cfg.get("level_up_quotes", []))
	data.support_personality = String(cfg.get("support_personality", ""))

	data.character_class = _load_class_resource(String(cfg.get("class_key", "")))
	data.starting_weapon = _load_weapon_resource(String(cfg.get("starting_weapon", "")))
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
	data.agility = int(stats.get("skl", 3))

	var growths: Dictionary = cfg.get("growths", {})
	data.hp_growth = int(growths.get("hp", 40))
	data.str_growth = int(growths.get("str", 30))
	data.mag_growth = int(growths.get("mag", 20))
	data.def_growth = int(growths.get("def", 20))
	data.res_growth = int(growths.get("res", 20))
	data.spd_growth = int(growths.get("spd", 30))
	data.agi_growth = int(growths.get("skl", 30))

	data.min_gold_drop = 0
	data.max_gold_drop = 0
	data.drops_equipped_weapon = false
	data.equipped_weapon_chance = 100

	return data

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

func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for item in value:
			out.append(String(item))
	return out
