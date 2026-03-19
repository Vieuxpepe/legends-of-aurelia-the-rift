# ==============================================================================
# Script Name: RecipeDatabase.gd
# Purpose: A global repository for all crafting, smelting, and structure recipes.
# Overall Goal: Decouple recipe data from the UI to allow easy expansion and balancing.
# Project Fit: Runs as an Autoload (Singleton).
# Dependencies: Requires valid resource paths for the 'result' keys.
# AI/Code Reviewer Guidance:
#   - Core Logic Sections: 'master_recipes' holds the raw data.
#   - Extension Points: Add new dictionaries to the array to expand crafting options.
# ==============================================================================

extends Node

var master_recipes: Array[Dictionary] = [
	# --- STRUCTURES ---
	{
		"name": "Wooden Crate",
		"ingredients": ["Wooden Plank", "Iron Nails"],
		"is_structure": true,
		"structure_type": "barricade",
		"icon_path": "res://Assets/UI/BarricadeIcon.png"
	},
	{
		"name": "Portable Fort",
		"ingredients": ["Wooden Plank", "Tent Cloth", "Iron Nails"],
		"is_structure": true,
		"structure_type": "fortress",
		"icon_path": "res://Assets/UI/TentIcon.png"
	},
	{
		"name": "Mercenary Tent",
		"ingredients": ["Wooden Plank", "Tent Cloth", "Leather Straps"],
		"is_structure": true,
		"structure_type": "spawner",
		"icon_path": "res://Assets/UI/TentIcon.png"
	},
	# --- SUPPORT MATERIALS / COMPONENTS ---
	{
		"name": "Charcoal Sack",
		"ingredients": ["Torchwood", "Torchwood"],
		"result": "res://Resources/Materials/GeneratedMaterials/Crafting/charcoal_sack.tres",
		"is_smelt": true
	},
	{
		"name": "Iron Nails",
		"ingredients": ["Scrap Iron", "Charcoal Sack"],
		"result": "res://Resources/Materials/GeneratedMaterials/Crafting/iron_nails.tres",
		"is_smelt": true
	},
	{
		"name": "Oak Resin",
		"ingredients": ["Wooden Plank", "Torchwood"],
		"result": "res://Resources/Materials/GeneratedMaterials/Crafting/oak_resin.tres"
	},
	{
		"name": "Leather Straps",
		"ingredients": ["Wolf Pelt", "Rock Salt"],
		"result": "res://Resources/Materials/GeneratedMaterials/Crafting/leather_straps.tres"
	},
	{
		"name": "Beeswax",
		"ingredients": ["Honey Jar", "Tallow Lump"],
		"result": "res://Resources/Materials/GeneratedMaterials/Crafting/beeswax.tres"
	},
	{
		"name": "Silver Thread",
		"ingredients": ["Silver Ore", "Linen Roll"],
		"result": "res://Resources/Materials/GeneratedMaterials/Crafting/silver_thread.tres",
		"is_smelt": true
	},
	{
		"name": "Tent Cloth",
		"ingredients": ["Linen Roll", "Leather Straps"],
		"result": "res://Resources/Materials/GeneratedMaterials/Crafting/tent_cloth.tres"
	},
	{
		"name": "Sewing Needles",
		"ingredients": ["Iron Ingot", "Charcoal Sack"],
		"result": "res://Resources/Materials/GeneratedMaterials/Crafting/sewing_needles.tres",
		"is_smelt": true
	},
	{
		"name": "Bandage Roll",
		"ingredients": ["Linen Roll", "Soap Brick"],
		"result": "res://Resources/Materials/GeneratedMaterials/Crafting/bandage_roll.tres"
	},
	{
		"name": "Tar Pot",
		"ingredients": ["Oak Resin", "Charcoal Sack", "Clay Crock"],
		"result": "res://Resources/Materials/GeneratedMaterials/Crafting/tar_pot.tres"
	},
	{
		"name": "Canvas Patch",
		"ingredients": ["Tent Cloth", "Sewing Needles"],
		"result": "res://Resources/Materials/GeneratedMaterials/Crafting/canvas_patch.tres"
	},
	{
		"name": "Ration Box",
		"ingredients": ["Wooden Plank", "Iron Nails"],
		"result": "res://Resources/Materials/GeneratedMaterials/Crafting/ration_box.tres"
	},
	{
		"name": "Mess Tin",
		"ingredients": ["Iron Ingot", "Iron Nails"],
		"result": "res://Resources/Materials/GeneratedMaterials/Crafting/mess_tin.tres",
		"is_smelt": true
	},
	{
		"name": "Tin Cup",
		"ingredients": ["Iron Ingot", "Charcoal Sack"],
		"result": "res://Resources/Materials/GeneratedMaterials/Crafting/tin_cup.tres",
		"is_smelt": true
	},
	{
		"name": "Pickling Brine",
		"ingredients": ["Rock Salt", "Vinegar Flask"],
		"result": "res://Resources/Materials/GeneratedMaterials/Cooking/pickling_brine.tres"
	},
	{
		"name": "Travel Rations",
		"ingredients": ["Dried Beans", "Dried Sausage", "Rock Salt"],
		"result": "res://Resources/Materials/GeneratedMaterials/Cooking/travel_rations.tres"
	},
	{
		"name": "Torchwood",
		"ingredients": ["Wooden Plank", "Tallow Lump"], # Fixed circular dependency
		"result": "res://Resources/Materials/GeneratedMaterials/Crafting/torchwood.tres"
	},
	{
		"name": "Copper Wire",
		"ingredients": ["Copper Pot", "Charcoal Sack"],
		"result": "res://Resources/Materials/GeneratedMaterials/Crafting/copper_wire.tres",
		"is_smelt": true
	},
	{
		"name": "Insect Salve",
		"ingredients": ["Medicinal Herbs", "Beeswax"],
		"result": "res://Resources/Materials/GeneratedMaterials/Crafting/insect_salve.tres"
	},
	{
		"name": "Twine Spool",
		"ingredients": ["Tent Cloth", "Leather Straps"],
		"result": "res://Resources/Materials/GeneratedMaterials/Crafting/twine_spool.tres"
	},
	# --- SMELTING ---
	{
		"name": "Iron Ingot",
		"ingredients": ["Iron Ore", "Charcoal Sack"],
		"result": "res://Resources/Materials/Iron Ingot.tres",
		"is_smelt": true
	},
	{
		"name": "Iron Ore",
		"ingredients": ["Scrap Iron", "Charcoal Sack"],
		"result": "res://Resources/Materials/Iron Ore.tres",
		"is_smelt": true
	},
	{
		"name": "Steel Ingot",
		"ingredients": ["Iron Ingot", "Iron Ingot", "Charcoal Sack"],
		"result": "res://Resources/Materials/Steel Ingot.tres",
		"is_smelt": true
	},
	{
		"name": "Mythril Ingot",
		"ingredients": ["Silver Ore", "Quicksilver Vial", "Arcane Dust"],
		"result": "res://Resources/GeneratedItems/Mat_Mythril_Ingot.tres",
		"is_smelt": true
	},
	
	# --- WEAPONS (EARLY GAME) ---
	{
		"name": "Bone Sword",
		"ingredients": ["Skeleton Bone", "Leather Straps", "Iron Nails"],
		"result": "res://Resources/Weapons/BoneSword.tres"
	},
	{
		"name": "Savage Axe",
		"ingredients": ["Skeleton Bone", "Wooden Plank", "Leather Straps"],
		"result": "res://Resources/GeneratedItems/Weapon_Raiders_Splitter.tres"
	},	
	{
		"name": "Rusty Sword",
		"ingredients": ["Scrap Iron", "Wooden Plank", "Leather Straps"],
		"result": "res://Resources/GeneratedItems/Weapon_Rusty_Sword.tres"
	},
	{
		"name": "Traveler's Blade",
		"ingredients": ["Iron Ore", "Oak Resin", "Leather Straps"],
		"result": "res://Resources/GeneratedItems/Weapon_Travelers_Blade.tres"
	},
	{
		"name": "Old Spear",
		"ingredients": ["Iron Ore", "Wooden Plank", "Leather Straps"],
		"result": "res://Resources/GeneratedItems/Weapon_Old_Spear.tres"
	},
	{
		"name": "Wooden Pike",
		"ingredients": ["Wooden Plank", "Iron Nails", "Leather Straps"],
		"result": "res://Resources/GeneratedItems/Weapon_Wooden_Pike.tres"
	},
	{
		"name": "Hatchet",
		"ingredients": ["Iron Ore", "Wooden Plank", "Iron Nails"],
		"result": "res://Resources/GeneratedItems/Weapon_Hatchet.tres"
	},
	{
		"name": "Bronze Axe",
		"ingredients": ["Iron Ingot", "Wooden Plank", "Charcoal Sack"],
		"result": "res://Resources/GeneratedItems/Weapon_Bronze_Axe.tres"
	},
	{
		"name": "Apprentice Tome",
		"ingredients": ["Wooden Plank", "Arcane Dust", "Beeswax"],
		"result": "res://Resources/GeneratedItems/Weapon_Apprentice_Tome.tres"
	},
	{
		"name": "Beginner's Staff",
		"ingredients": ["Wooden Plank", "Oak Resin", "Silver Thread"],
		"result": "res://Resources/GeneratedItems/Weapon_Beginners_Staff.tres"
	},
	{
		"name": "Iron Sword",
		"ingredients": ["Iron Ingot", "Leather Straps", "Oak Resin"],
		"result": "res://Resources/GeneratedItems/Weapon_Iron_Sword.tres"
	},
	{
		"name": "Crude Bow",
		"ingredients": ["Wooden Plank", "Leather Straps", "Iron Nails"],
		"result": "res://Resources/GeneratedItems/Weapon_Crude_Bow.tres"
	},
	{
		"name": "Ash Shortbow",
		"ingredients": ["Wooden Plank", "Oak Resin", "Leather Straps"],
		"result": "res://Resources/GeneratedItems/Weapon_Ash_Shortbow.tres"
	},
	{
		"name": "Hunter's Bow",
		"ingredients": ["Iron Ore", "Wooden Plank", "Leather Straps"],
		"result": "res://Resources/GeneratedItems/Weapon_Hunters_Bow.tres"
	},
	{
		"name": "Longbow",
		"ingredients": ["Steel Ingot", "Wooden Plank", "Leather Straps"],
		"result": "res://Resources/GeneratedItems/Weapon_Longbow.tres"
	},
	{
		"name": "Bronze Pike",
		"ingredients": ["Iron Ingot", "Wooden Plank", "Leather Straps"],
		"result": "res://Resources/GeneratedItems/Weapon_Bronze_Pike.tres"
	},
	{
		"name": "Scrap Knife",
		"ingredients": ["Scrap Iron", "Leather Straps", "Iron Nails"],
		"result": "res://Resources/GeneratedItems/Weapon_Scrap_Knife.tres"
	},
	{
		"name": "Street Dirk",
		"ingredients": ["Scrap Iron", "Leather Straps", "Wooden Plank"],
		"result": "res://Resources/GeneratedItems/Weapon_Street_Dirk.tres"
	},
	{
		"name": "Militia Handgonne",
		"ingredients": ["Iron Ore", "Charcoal Sack", "Iron Nails"],
		"result": "res://Resources/GeneratedItems/Weapon_Militia_Handgonne.tres"
	},
	{
		"name": "Rustlock Pistol",
		"ingredients": ["Scrap Iron", "Charcoal Sack", "Leather Straps"],
		"result": "res://Resources/GeneratedItems/Weapon_Rustlock_Pistol.tres"
	},
	{
		"name": "Gale Lexicon",
		"ingredients": ["Arcane Dust", "Tent Cloth", "Beeswax"],
		"result": "res://Resources/GeneratedItems/Weapon_Gale_Lexicon.tres"
	},
	{
		"name": "Protect Staff",
		"ingredients": ["Wooden Plank", "Arcane Dust", "Silver Thread"],
		"result": "res://Resources/GeneratedItems/Weapon_Protect_Staff.tres"
	},
	{
		"name": "Wrapped Cestus",
		"ingredients": ["Leather Straps", "Iron Nails", "Wooden Plank"],
		"result": "res://Resources/GeneratedItems/Weapon_Wrapped_Cestus.tres"
	},
	{
		"name": "Ironbound Cestus",
		"ingredients": ["Iron Ingot", "Leather Straps", "Iron Nails"],
		"result": "res://Resources/GeneratedItems/Weapon_Ironbound_Cestus.tres"
	},
	
	# --- WEAPONS (MID GAME) ---
	{
		"name": "Steel Sword",
		"ingredients": ["Steel Ingot", "Leather Straps", "Oak Resin"],
		"result": "res://Resources/GeneratedItems/Weapon_Steel_Sword.tres"
	},
	{
		"name": "Heavy Blade",
		"ingredients": ["Steel Ingot", "Iron Nails", "Leather Straps"],
		"result": "res://Resources/GeneratedItems/Weapon_Heavy_Blade.tres"
	},
	{
		"name": "Pike of Valor",
		"ingredients": ["Steel Ingot", "Wooden Plank", "Leather Straps"],
		"result": "res://Resources/GeneratedItems/Weapon_Pike_of_Valor.tres"
	},
	{
		"name": "Knight's Halberd",
		"ingredients": ["Steel Ingot", "Wooden Plank", "Silver Thread"],
		"result": "res://Resources/GeneratedItems/Weapon_Knights_Halberd.tres"
	},
	{
		"name": "Steel Axe",
		"ingredients": ["Steel Ingot", "Wooden Plank", "Iron Nails"],
		"result": "res://Resources/GeneratedItems/Weapon_Steel_Axe.tres"
	},
	{
		"name": "War Axe",
		"ingredients": ["Steel Ingot", "Steel Ingot", "Leather Straps"],
		"result": "res://Resources/GeneratedItems/Weapon_War_Axe.tres"
	},
	{
		"name": "Arcane Grimoire",
		"ingredients": ["Arcane Dust", "Tent Cloth", "Beeswax"],
		"result": "res://Resources/GeneratedItems/Weapon_Arcane_Grimoire.tres"
	},
	{
		"name": "Healing Staff",
		"ingredients": ["Wooden Plank", "Arcane Dust", "Silver Thread"],
		"result": "res://Resources/GeneratedItems/Weapon_Healing_Staff.tres"
	},
	
	# --- WEAPONS (LATE GAME) ---
	{
		"name": "Silver Sword",
		"ingredients": ["Silver Ore", "Steel Ingot", "Silver Thread"],
		"result": "res://Resources/GeneratedItems/Weapon_Silver_Sword.tres"
	},
	{
		"name": "Flame Blade",
		"ingredients": ["Steel Ingot", "Emberwood Resin", "Cinder Bloom"],
		"result": "res://Resources/GeneratedItems/Weapon_Flame_Blade.tres"
	},
	{
		"name": "Silver Lance",
		"ingredients": ["Silver Ore", "Wooden Plank", "Silver Thread"],
		"result": "res://Resources/GeneratedItems/Weapon_Silver_Lance.tres"
	},
	{
		"name": "Thunder Pike",
		"ingredients": ["Elemental Crystal", "Steel Ingot", "Copper Wire"],
		"result": "res://Resources/GeneratedItems/Weapon_Thunder_Pike.tres"
	},
	{
		"name": "Great Axe",
		"ingredients": ["Silver Ore", "Steel Ingot", "Leather Straps"],
		"result": "res://Resources/GeneratedItems/Weapon_Great_Axe.tres"
	},
	{
		"name": "Wind Cleaver",
		"ingredients": ["Elemental Crystal", "Silver Ore", "Hush Stone"],
		"result": "res://Resources/GeneratedItems/Weapon_Wind_Cleaver.tres"
	},
	{
		"name": "Flame Tome",
		"ingredients": ["Elemental Crystal", "Arcane Dust", "Cinder Bloom"],
		"result": "res://Resources/GeneratedItems/Weapon_Flame_Tome.tres"
	},
	{
		"name": "Thunder Staff",
		"ingredients": ["Silver Ore", "Elemental Crystal", "Copper Wire"],
		"result": "res://Resources/GeneratedItems/Weapon_Thunder_Staff.tres"
	},
	
	# --- WEAPONS (END GAME) ---
	{
		"name": "Excalibur",
		"ingredients": ["Mythril Ingot", "Dragon Scale", "Starforged Relic"],
		"result": "res://Resources/GeneratedItems/Weapon_Excalibur.tres"
	},
	{
		"name": "Dragonfang",
		"ingredients": ["Mythril Ingot", "Dragon Scale", "Wyrm Scale"],
		"result": "res://Resources/GeneratedItems/Weapon_Dragonfang.tres"
	},
	{
		"name": "Holy Lance",
		"ingredients": ["Mythril Ingot", "Dragon Scale", "Saint's Ash"],
		"result": "res://Resources/GeneratedItems/Weapon_Holy_Lance.tres"
	},
	{
		"name": "Dragon Spear",
		"ingredients": ["Mythril Ingot", "Dragon Scale", "Moonsteel Shard"],
		"result": "res://Resources/GeneratedItems/Weapon_Dragon_Spear.tres"
	},
	{
		"name": "Doom Hammer",
		"ingredients": ["Mythril Ingot", "Dragon Scale", "Abyssal Amber"],
		"result": "res://Resources/GeneratedItems/Weapon_Doom_Hammer.tres"
	},
	{
		"name": "Windslayer Axe",
		"ingredients": ["Mythril Ingot", "Dragon Scale", "Hush Stone"],
		"result": "res://Resources/GeneratedItems/Weapon_Windslayer_Axe.tres"
	},
	{
		"name": "Celestial Tome",
		"ingredients": ["Mythril Ingot", "Arcane Dust", "Rift Amber"],
		"result": "res://Resources/GeneratedItems/Weapon_Celestial_Tome.tres"
	},
	{
		"name": "Elysian Staff",
		"ingredients": ["Mythril Ingot", "Dragon Scale", "Phoenix Cinder"],
		"result": "res://Resources/GeneratedItems/Weapon_Elysian_Staff.tres"
	}
]
