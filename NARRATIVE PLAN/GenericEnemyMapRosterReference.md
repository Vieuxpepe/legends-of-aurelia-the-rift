# Generic enemy packs by map

## Unit types (`UnitData.unit_type`)

Authoring on each **UnitData** (`.tres`): narrative/species tag used for UI, future “bane vs type” rules, and **blood splatter** suppression (`Undead`, `Construct`, `Spirit`, `Aberration`, `Elemental` → no red spray; `Dragon` uses normal bleed VFX).

| Value | Enum | Use for |
|-------|------|--------|
| 0 | Unspecified | Legacy or generic; treat like human for VFX until set |
| 1 | Human | Most League, dock, temple line humans |
| 2 | Elf | Elven/fair-folk (future) |
| 3 | Dwarf | Dwarven units |
| 4 | Halfling | Halfling units |
| 5 | Goblin | Goblinoids |
| 6 | Orc | Orcs / big greenskin brutes |
| 7 | Undead | Skeleton line, revenants, husks, crypt packs |
| 8 | Beast | Hounds, mounts-as-unit, pure animals |
| 9 | Construct | Golems, animated objects |
| 10 | Spirit | Echoes, shades, oathshades |
| 11 | Aberration | Rift/void masses, “wrong” biology |
| 12 | Elemental | Fire/water/air/earth incarnations, salamanders, etc. |
| 13 | Dragon | Drakes, wyrms, true dragons |

Code: `UnitData.UnitType`, `unit.get_unit_type()`, `UnitData.unit_type_display_name(t)`, `UnitData.unit_type_suppresses_blood(t)`.

## Map01\_RazedVillage

* `ash\_cultist\_t1` — Ash Cultist (Novice, Rusty Sword)
* `pyre\_disciple\_t1` — Pyre Disciple (Apprentice, Fire Tome)
* `soul\_reaver\_t1` — Soul Reaver (Mercenary, Traveler's Blade)
* `cinder\_archer\_t1` — Cinder Archer (Archer, Ash Shortbow)

## Map02\_EmberwoodFlight

* `ash\_cultist\_t1` — Ash Cultist (Novice, Rusty Sword)
* `pyre\_disciple\_t1` — Pyre Disciple (Apprentice, Fire Tome)
* `soul\_reaver\_t1` — Soul Reaver (Mercenary, Traveler's Blade)
* `cinder\_archer\_t1` — Cinder Archer (Archer, Ash Shortbow)
* `rift\_hound\_t1` — Rift Hound (Monster, Wrapped Cestus)

## Map03\_ShatteredSanctum

* `purifier\_acolyte\_t1` — Purifier Acolyte (Monk, Temple Gauntlets)
* `temple\_guard\_t1` — Temple Guard (Knight, Bronze Pike)
* `sun\_archer\_t1` — Sun Archer (Archer, Hunters Bow)
* `censer\_cleric\_t1` — Censer Cleric (Cleric, Prism Tome)
* `doctrine\_blade\_t2` — Doctrine Blade (Spellblade, Flame Blade)

## Map04\_MerchantsMaze

* `dock\_thug\_t1` — Dock Thug (Warrior, Bronze Axe)
* `watch\_crossbowman\_t1` — Watch Crossbowman (Archer, Crude Bow)
* `rooftop\_knife\_t1` — Rooftop Knife (Thief, Street Dirk)
* `sewer\_smuggler\_t1` — Sewer Smuggler (Thief, Scrap Knife)
* `contract\_guard\_t2` — Contract Guard (Mercenary, Iron Sword)

## Map05\_LeagueDockAssault

* `bell\_rigger\_t1` — Bell Rigger (Thief, Bellhook Knife)
* `watch\_crossbowman\_t1` — Watch Crossbowman (Archer, Crude Bow)
* `powder\_gunner\_t2` — Powder Gunner (Cannoneer, Militia Handgonne)
* `contract\_guard\_t2` — Contract Guard (Mercenary, Iron Sword)
* `dock\_thug\_t1` — Dock Thug (Warrior, Bronze Axe)
* `league\_marshal\_t2` — League Marshal (GreatKnight, Old Spear)

## Map06\_SiegeOfGreyspire

* `bone\_pikeman\_t2` — Bone Pikeman (Knight, Old Spear)
* `graveblade\_t2` — Graveblade (Mercenary, Oathcutter)
* `crypt\_archer\_t2` — Crypt Archer (Archer, Reinforced Bow)
* `death\_acolyte\_t2` — Death Acolyte (Mage, Gloam Primer)
* `mournful\_husk\_t1` — Mournful Husk (Monster, Rusty Sword)

## Map07\_FaminesPrice

* `granary\_guard\_t2` — Granary Guard (Knight, Bronze Pike)
* `levy\_spearman\_t1` — Levy Spearman (Recruit, Wooden Pike)
* `tax\_archer\_t1` — Tax Archer (Archer, Crude Bow)
* `mounted\_retainer\_t2` — Mounted Retainer (Paladin, Old Spear)
* `road\_bailiff\_t2` — Road Bailiff (Mercenary, Traveler's Blade)
* `houndmaster\_t2` — Houndmaster (Beastmaster, Hunters Bow)

## Map08\_SacredForestSkirmish

* `axebark\_raider\_t2` — Axebark Raider (Warrior, Steel Axe)
* `road\_warden\_t2` — Road Warden (Archer, Reinforced Bow)
* `cliff\_skirmisher\_t2` — Cliff Skirmisher (BowKnight, Longbow)
* `trapkeeper\_t1` — Trapkeeper (Thief, Scrap Knife)
* `houndmaster\_t2` — Houndmaster (Beastmaster, Hunters Bow)
* `totem\_keeper\_t2` — Totem Keeper (Monk, Pilgrim's Knuckles)

## Map09A\_MountainPassNegotiation

* `temple\_guard\_t1` — Temple Guard (Knight, Bronze Pike)
* `purifier\_acolyte\_t1` — Purifier Acolyte (Monk, Temple Gauntlets)
* `sun\_archer\_t1` — Sun Archer (Archer, Hunters Bow)
* `doctrine\_blade\_t2` — Doctrine Blade (Spellblade, Flame Blade)
* `ashen\_templar\_t2` — Ashen Templar (Paladin, Holy Lance)

## Map09B\_LeagueCouncilSkirmish

* `rooftop\_knife\_t1` — Rooftop Knife (Thief, Street Dirk)
* `contract\_guard\_t2` — Contract Guard (Mercenary, Iron Sword)
* `accountant\_duelist\_t2` — Accountant Duelist (Spellblade, Flame Blade)
* `bell\_rigger\_t1` — Bell Rigger (Thief, Bellhook Knife)
* `watch\_crossbowman\_t1` — Watch Crossbowman (Archer, Crude Bow)
* `league\_marshal\_t2` — League Marshal (GreatKnight, Old Spear)

## Map10\_SunlitTrial

* `temple\_guard\_t1` — Temple Guard (Knight, Bronze Pike)
* `censer\_cleric\_t1` — Censer Cleric (Cleric, Prism Tome)
* `doctrine\_blade\_t2` — Doctrine Blade (Spellblade, Flame Blade)
* `ashen\_templar\_t2` — Ashen Templar (Paladin, Holy Lance)
* `inquisitor\_adept\_t2` — Inquisitor Adept (DivineSage, Prism Tome)
* `arena\_templar\_t3` — Arena Templar (HighPaladin, Judgment Pike)

## Map11\_MarketOfMasks

* `rooftop\_knife\_t1` — Rooftop Knife (Thief, Street Dirk)
* `watch\_crossbowman\_t1` — Watch Crossbowman (Archer, Crude Bow)
* `contract\_guard\_t2` — Contract Guard (Mercenary, Iron Sword)
* `accountant\_duelist\_t2` — Accountant Duelist (Spellblade, Flame Blade)
* `bell\_rigger\_t1` — Bell Rigger (Thief, Bellhook Knife)

## Map12\_ShadowsInTheCollege

* `archive\_warden\_t2` — Archive Warden (Knight, Bronze Pike)
* `scriptor\_mage\_t1` — Scriptor Mage (Mage, Apprentice Tome)
* `barrier\_adept\_t1` — Barrier Adept (Cleric, Prism Tome)
* `stair\_duelist\_t2` — Stair Duelist (Mercenary, Iron Sword)
* `lamp\_runner\_t1` — Lamp Runner (Thief, Street Dirk)
* `sealkeeper\_t2` — Sealkeeper (DivineSage, Arcane Grimoire)

## Map13\_StormingTheBlackCoast

* `black\_coast\_raider\_t3` — Black Coast Raider (Warrior, Raiders Splitter)
* `tide\_archer\_t3` — Tide Archer (HeavyArcher, Storm Bow)
* `pyre\_disciple\_t1` — Pyre Disciple (Apprentice, Fire Tome)
* `ritual\_adept\_t2` — Ritual Adept (Monk, Pilgrim's Knuckles)
* `siege\_crew\_t3` — Siege Crew (Cannoneer, Ramshackle Culverin)
* `shadowblade\_skirmisher\_t3` — Shadowblade Skirmisher (Assassin, Sparkknife)
* `rift\_hound\_t1` — Rift Hound (Monster, Wrapped Cestus)

## Map14\_DawnkeepAmbush

* `bone\_pikeman\_t2` — Bone Pikeman (Knight, Old Spear)
* `graveblade\_t2` — Graveblade (Mercenary, Oathcutter)
* `crypt\_archer\_t2` — Crypt Archer (Archer, Reinforced Bow)
* `revenant\_rider\_t3` — Revenant Rider (DeathKnight, Blackened Lance)
* `trapkeeper\_t1` — Trapkeeper (Thief, Scrap Knife)

## Map15\_WeepingMarsh

* `mournful\_husk\_t1` — Mournful Husk (Monster, Rusty Sword)
* `rot\_binder\_t3` — Rot Binder (DivineSage, Hexleaf Codex)
* `drowned\_archer\_t3` — Drowned Archer (HeavyArcher, Longbow)
* `mire\_hexer\_t3` — Mire Hexer (FireSage, Hexleaf Codex)
* `death\_acolyte\_t2` — Death Acolyte (Mage, Gloam Primer)

## Map16\_EchoesOfTheOrder

* `oathshade\_t3` — Oathshade (Hero, Silver Sword)
* `dawn\_sentinel\_t3` — Dawn Sentinel (General, Holy Lance)
* `trial\_archer\_t3` — Trial Archer (HeavyArcher, Longbow)
* `chapel\_echo\_t2` — Chapel Echo (DivineSage, Celestial Tome)
* `mirror\_judge\_t3` — Mirror Judge (BladeWeaver, Arcane Grimoire)

## Map17\_GatheringStorms

* `purifier\_acolyte\_t1` — Purifier Acolyte (Monk, Temple Gauntlets)
* `contract\_guard\_t2` — Contract Guard (Mercenary, Iron Sword)
* `mounted\_retainer\_t2` — Mounted Retainer (Paladin, Old Spear)
* `rooftop\_knife\_t1` — Rooftop Knife (Thief, Street Dirk)
* `temple\_guard\_t1` — Temple Guard (Knight, Bronze Pike)
* `league\_marshal\_t2` — League Marshal (GreatKnight, Old Spear)
* `road\_bailiff\_t2` — Road Bailiff (Mercenary, Traveler's Blade)

## Map18\_RitualOfTheDarkTide

* `void\_acolyte\_t3` — Void Acolyte (Mage, Gloam Primer)
* `tide\_thrall\_t2` — Tide Thrall (Monster, Rusty Sword)
* `anchor\_guardian\_t3` — Anchor Guardian (General, Thunder Pike)
* `rift\_stalker\_t3` — Rift Stalker (Assassin, Sparkknife)
* `null\_choir\_t3` — Null Choir (DivineSage, Dark Tide Grimoire)
* `black\_coast\_raider\_t3` — Black Coast Raider (Warrior, Raiders Splitter)
* `shadowblade\_skirmisher\_t3` — Shadowblade Skirmisher (Assassin, Sparkknife)

## Map19\_TheTrueCatalyst

* `unmade\_horror\_t4` — Unmade Horror (Dreadnought, Doom Hammer)
* `null\_choir\_t3` — Null Choir (DivineSage, Dark Tide Grimoire)
* `abyss\_lancer\_t3` — Abyss Lancer (Paladin, Thunder Pike)
* `rift\_stalker\_t3` — Rift Stalker (Assassin, Sparkknife)
* `tendril\_spawn\_t3` — Tendril Spawn (Monster, Wrapped Cestus)
* `glyph\_breaker\_t4` — Glyph Breaker (RiftArchon, Null Hymn)
* `anchor\_guardian\_t3` — Anchor Guardian (General, Thunder Pike)

## Map20\_Epilogue\_Sacrifice

* `tide\_thrall\_t2` — Tide Thrall (Monster, Rusty Sword)
* `void\_acolyte\_t3` — Void Acolyte (Mage, Gloam Primer)
* `black\_coast\_raider\_t3` — Black Coast Raider (Warrior, Raiders Splitter)
* `unmade\_horror\_t4` — Unmade Horror (Dreadnought, Doom Hammer)

## Map20\_Epilogue\_Ascension

* `dawn\_sentinel\_t3` — Dawn Sentinel (General, Holy Lance)
* `mirror\_judge\_t3` — Mirror Judge (BladeWeaver, Arcane Grimoire)
* `glyph\_breaker\_t4` — Glyph Breaker (RiftArchon, Null Hymn)
* `oathshade\_t3` — Oathshade (Hero, Silver Sword)

