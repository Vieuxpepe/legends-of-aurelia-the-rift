extends RefCounted
class_name UnitTraitsDisplay

## Human-readable trait lines for UI (legacy passives, quirks, etc.).

const ROOKIE_JOB_NAMES: Array[String] = ["Recruit", "Villager", "Urchin", "Apprentice", "Novice"]

## Stable ids stored on Unit.rookie_legacies (stack across promotions).
const LEGACY_ID_RECRUIT := "recruit"
const LEGACY_ID_VILLAGER := "villager"
const LEGACY_ID_URCHIN := "urchin"
const LEGACY_ID_APPRENTICE := "apprentice"
const LEGACY_ID_NOVICE := "novice"


static func legacy_id_for_rookie_job(job_name: String) -> String:
	match job_name.strip_edges():
		"Recruit":
			return LEGACY_ID_RECRUIT
		"Villager":
			return LEGACY_ID_VILLAGER
		"Urchin":
			return LEGACY_ID_URCHIN
		"Apprentice":
			return LEGACY_ID_APPRENTICE
		"Novice":
			return LEGACY_ID_NOVICE
		_:
			return ""


static func rookie_job_name_for_legacy_id(legacy_id: String) -> String:
	match str(legacy_id):
		LEGACY_ID_RECRUIT:
			return "Recruit"
		LEGACY_ID_VILLAGER:
			return "Villager"
		LEGACY_ID_URCHIN:
			return "Urchin"
		LEGACY_ID_APPRENTICE:
			return "Apprentice"
		LEGACY_ID_NOVICE:
			return "Novice"
		_:
			return ""


## Shown in TRAITS after promoting out of that rookie class (matches combat passives).
const ROOKIE_LEGACY_TRAIT_LINES: Dictionary = {
	"Recruit": "Legacy — Recruit: Drill Formation (+Hit on your first strike each battle).",
	"Villager": "Legacy — Villager: Desperate Measure (+damage & crit when wounded, once per turn).",
	"Urchin": "Legacy — Urchin: Pickpocket's Eye (+Hit & damage vs. full-HP foes).",
	"Apprentice": "Legacy — Apprentice: Cantrip Surge (+damage every 3rd tome hit).",
	"Novice": "Legacy — Novice: Blank Slate (random Hit, damage, or crit bias each battle).",
}

## Normal (tier-1) classes: granted when promoting into a PromotedClass (not from a rookie job).
const BASE_CLASS_JOB_NAMES: Array[String] = [
	"Knight", "Warrior", "Mage", "Archer", "Mercenary", "Monk", "Paladin",
	"Spellblade", "Thief", "Flier", "Dancer", "Beastmaster", "Cannoneer", "Cleric",
]

## Shown after promoting out of that base class (flavor + reminder of former kit).
const BASE_LEGACY_TRAIT_LINES: Dictionary = {
	"Knight": "Legacy — Knight: Shield-wall habits—closing distance and bracing for impact feel instinctive.",
	"Warrior": "Legacy — Warrior: Front-line grit—raw exchanges taught you to trade blows without flinching.",
	"Mage": "Legacy — Mage: Arcane cadence—you still read battlefields like a lattice of vectors and fire.",
	"Archer": "Legacy — Archer: Marksmanship patience—breath, lead, and release stay wired into muscle memory.",
	"Mercenary": "Legacy — Mercenary: Sell-sword pragmatism—you favor openings that pay off in blood.",
	"Monk": "Legacy — Monk: Flow state—strikes chain in your mind before the body commits.",
	"Paladin": "Legacy — Paladin: Oath tempo—every swing still carries the rhythm of consecration.",
	"Spellblade": "Legacy — Spellblade: Edge-and-weave—you blur the line between blade pressure and spell surge.",
	"Thief": "Legacy — Thief: Shadow economy—you spot weak angles and second chances others miss.",
	"Flier": "Legacy — Flier: Sky sense—altitude, dive lines, and escape vectors are second nature.",
	"Dancer": "Legacy — Dancer: Battle tempo—you feel the fight as choreography and exploit the beat.",
	"Beastmaster": "Legacy — Beastmaster: Wild empathy—predator patience and explosive bursts still guide you.",
	"Cannoneer": "Legacy — Cannoneer: Siege math—range, splash, and shock still shape how you commit.",
	"Cleric": "Legacy — Cleric: Liturgical focus—support and smite share the same steady hand.",
}

## Promoted jobs (exact `job_name` on ClassData) — granted when promoting into an AscendedClass.
const PROMOTED_LEGACY_TRAIT_LINES: Dictionary = {
	"Great Knight": "Legacy — Great Knight: Armored vanguard—heavy line leadership still steadies your strikes.",
	"General": "Legacy — General: Fort doctrine—terrain, denial, and measured blows define your rhythm.",
	"Hero": "Legacy — Hero: Mythic versatility—legendary scrapes taught you to adapt mid-blade.",
	"BowKnight": "Legacy — Bow Knight: Mounted archery—gallop, draw, and release fused into one motion.",
	"Heavy Archer": "Legacy — Heavy Archer: Siege bow discipline—power shots and brace still anchor you.",
	"Assassin": "Legacy — Assassin: Terminal precision—one clean window is worth ten wild swings.",
	"Blademaster": "Legacy — Blademaster: Edge mastery—tempo and edge alignment outrank brute strength.",
	"Berserker": "Legacy — Berserker: Crimson momentum—rage as a tool, not an accident.",
	"Fire Sage": "Legacy — Fire Sage: Pyric theology—heat, ash, and omen-readings still fuel your cast.",
	"Divine Sage": "Legacy — Divine Sage: Sanctified weave—miracle and judgment share the same breath.",
	"Blade Weaver": "Legacy — Blade Weaver: Spell-thread fencing—steel and sigil answer the same pull.",
	"High Paladin": "Legacy — High Paladin: Radiant charge—auras and lances still rise as one thought.",
	"Death Knight": "Legacy — Death Knight: Umbral command—dread and discipline march in lockstep.",
	"Falcon Knight": "Legacy — Falcon Knight: Aerial lance craft—dive, impale, and wheel away on instinct.",
	"Sky Vanguard": "Legacy — Sky Vanguard: Storm-front tactics—wind shear and daring share one calculus.",
	"Muse": "Legacy — Muse: Inspiring cadence—morale and motion bend to your performance.",
	"Blade Dancer": "Legacy — Blade Dancer: Lethal choreography—every flourish hides a killing line.",
	"Wild Warden": "Legacy — Wild Warden: Primal boundary—feral strength answers when the wild is threatened.",
	"Pack Leader": "Legacy — Pack Leader: Alpha pulse—pack tactics and savage finishes still drive you.",
	"Siege Master": "Legacy — Siege Master: Breach calculus—angles, powder, and shockwaves are your language.",
	"Dreadnought": "Legacy — Dreadnought: Walking fortress—nothing stops the line while you still stand.",
}


static func _tier_job_slug(job_name: String) -> String:
	return job_name.strip_edges().to_lower().replace(" ", "_")


## Call during promotion after `grant_rookie_legacy_on_promotion`. Uses `new_class.resource_path`:
## PromotedClass → records former **base** job; AscendedClass → records former **promoted** job.
static func grant_tier_class_legacy_on_promotion(unit: Node2D, old_class_name: String, new_class: Resource) -> void:
	if unit == null or not is_instance_valid(unit) or new_class == null:
		return
	var old_job: String = old_class_name.strip_edges()
	if old_job.is_empty():
		return
	var path: String = str(new_class.resource_path)
	if path.find("AscendedClass") != -1:
		_grant_promoted_class_legacy(unit, old_job)
	elif path.find("PromotedClass") != -1:
		if ROOKIE_JOB_NAMES.has(old_job):
			return
		_grant_base_class_legacy(unit, old_job)


static func _grant_base_class_legacy(unit: Node2D, old_job: String) -> void:
	if not BASE_CLASS_JOB_NAMES.has(old_job):
		return
	if unit.get("base_class_legacies") == null or unit.get("traits") == null:
		return
	var id: String = "base_" + _tier_job_slug(old_job)
	var leg: Array = unit.base_class_legacies
	if not leg.has(id):
		leg.append(id)
	var line: String = str(BASE_LEGACY_TRAIT_LINES.get(old_job, "")).strip_edges()
	if line.is_empty():
		line = "Legacy — %s: Training in this role still shapes your instincts in battle." % old_job
	var traits_list: Array = unit.traits
	if not traits_list.has(line):
		traits_list.append(line)


static func _grant_promoted_class_legacy(unit: Node2D, old_job: String) -> void:
	if not PROMOTED_LEGACY_TRAIT_LINES.has(old_job):
		return
	if unit.get("promoted_class_legacies") == null or unit.get("traits") == null:
		return
	var id: String = "promoted_" + _tier_job_slug(old_job)
	var leg: Array = unit.promoted_class_legacies
	if not leg.has(id):
		leg.append(id)
	var line: String = str(PROMOTED_LEGACY_TRAIT_LINES.get(old_job, "")).strip_edges()
	if line.is_empty():
		return
	var traits_list: Array = unit.traits
	if not traits_list.has(line):
		traits_list.append(line)


static func grant_rookie_legacy_on_promotion(unit: Node2D, old_class_name: String) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	var j: String = old_class_name.strip_edges()
	if not ROOKIE_JOB_NAMES.has(j):
		return
	var lid: String = legacy_id_for_rookie_job(j)
	if lid.is_empty():
		return
	if unit.get("rookie_legacies") == null:
		return
	var legacies: Array = unit.rookie_legacies
	if not legacies.has(lid):
		legacies.append(lid)
	if unit.get("traits") == null:
		return
	var line: String = str(ROOKIE_LEGACY_TRAIT_LINES.get(j, "")).strip_edges()
	if line.is_empty():
		return
	var traits_list: Array = unit.traits
	if not traits_list.has(line):
		traits_list.append(line)


static func trait_lines_from_unit(u: Node2D) -> PackedStringArray:
	var out: PackedStringArray = []
	if u == null or not is_instance_valid(u):
		return out
	var t: Variant = u.get("traits")
	if t is Array:
		for x in t:
			var s: String = str(x).strip_edges()
			if not s.is_empty():
				out.append(s)
	return out


static func trait_lines_from_roster_dict(d: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var t: Variant = d.get("traits", [])
	if t is Array:
		for x in t:
			var s: String = str(x).strip_edges()
			if not s.is_empty():
				out.append(s)
	return out


## BBCode fragment (leading newline if non-empty) for RichTextLabel panels.
static func bbcode_section(lines: PackedStringArray) -> String:
	if lines.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	parts.append("\n[color=plum][b]TRAITS[/b][/color]")
	for L in lines:
		parts.append("• [color=wheat]" + L + "[/color]")
	return "\n".join(parts) + "\n"
