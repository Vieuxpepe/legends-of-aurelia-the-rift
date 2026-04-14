# ==============================================================================
# Script Name: DialogueDatabase.gd
# Purpose: A global repository for all camp NPC dialogue lines.
# Overall Goal: Decouple dialogue text from the UI to allow easy expansion and editing.
# Project Fit: Runs as an Autoload (Singleton).
# Dependencies: None.
# AI/Code Reviewer Guidance:
#   - Core Logic Sections: Contains dictionaries for Blacksmith and Merchant lines.
#   - Extension Points: Add new keys or strings to the dictionaries to expand dialogue.
# ==============================================================================

extends Node

var blacksmith_lines: Dictionary = {
	"welcome": [
		{
			"text": "Forge is hot. Step close if you're freezing, or pretend to check your gear if you need a quiet word off the roster.",
			"solo_hint": {"needle": "quiet word", "scene_id": "haldor_solo_first_quiet"}
		},
		"Bellows are pumping and the anvil's free. What're we fixing today, Boss?",
		"Commander. Coals are getting lonely and I'm losing my patience. Hand over the dented gear.",
		"You're still breathing. Good. Let's make sure your kit can say the same.",
		"I'd weave plate from my own beard if I thought it'd keep you in one piece. Sit down. Let me see the damage.",
		"Hammer's hungry. Let's feed it some stubborn iron.",
		"Wrong tent if you're looking for polish. Right tent if you want an edge that survives the week.",
		"I don't sell morale. I sell rivets that hold. Let's get to work.",
		"You made it back breathing. Miracles happen. Let's see how much of your kit survived your tactical genius."
	],
	"craft_start": [
		"Clear the bench, Boss. This is going to get loud.",
		"Good stock. Let's beat some manners into it.",
		"Don't rush me. Rushed work gets people killed."
	],
	"craft_normal": [
		"Done. It'll survive the week. Probably.",
		"Usable. Keep the edge clean and it might actually save you.",
		"It's ugly, but it's sharp. Go swing it at something."
	],
	"craft_masterwork": [
		"Hmph. The temper caught perfect. You better not ruin this by cutting firewood, Boss.",
		"Striking fell right on this one. Treat it with half the respect it deserves, and it'll outlive us both.",
		"Grain aligned beautifully. It’s frankly too good for you. Try not to embarrass it out there.",
		"I outdid myself. First person who scratches this without shedding enemy blood first has to answer to my hammer."
	],
	"repair_normal": [
		"Good as new. Stop trying to break it so fast, eh?",
		"Fixed the nicks and polished the edge. She’s ready for blood again.",
		"A little oil, a little heat, and she's back in the fight."
	],
	"repair_masterwork": [
		"Realigned the edge, hardened the core. It's better than you deserve. Go break it again.",
		"Folded the weak spots out. If it bends now, it’s because you swung wrong.",
		"Not a flaw left in the grain. I'll charge you double if you bring it back muddy."
	],
	"salvage": [
		"Reduced to scrap. The forge takes all.",
		"A shame to break it, but we need the materials.",
		"Nothing is wasted in my forge, Boss.",
		"Torn apart and ready to be reborn!",
		"I'll break this down. We'll put it to better use."
	],
	# One-time forge open (camp_menu.gd) when runesmithing is newly available — keep to a single line so it always matches the flag.
	"runesmith_forge_intro": [
		"Listen close, Commander — runes are not garnish, they're paperwork for steel. Lay blade and carved stone on my anvil, hit SOCKET: the stone throws a tantrum and vanishes, the sword sulks and gets stronger. Or skip the drama and feed the glyph-row from your cart like a civilized maniac. Two paths, same rule — my forge doesn't do half measures."
	]
}

## Extra welcome lines when [code]CampaignManager.max_unlocked_index[/code] reaches each tier. One tier per narrative map beat (NARRATIVE PLAN maps 1–20); base welcomes always mix in.
var blacksmith_welcome_progress: Array = [
	{
		"unlock_level": 1,
		"lines": [
			"You smell like smoke and bad decisions — good. Emberwood doesn't forgive soft steel, and neither does my expense report.",
			"Every notch in your kit is tuition. Bring me the bent bits; I'll turn embarrassment into something pointy."
		]
	},
	{
		"unlock_level": 2,
		"lines": [
			"Sanctum stone lies — looks holy, chips like bad excuses. We'll beat honesty into it anyway.",
			"Thieves sprint like their purses are on fire. My anvil only runs hot when I say so."
		]
	},
	{
		"unlock_level": 3,
		"lines": [
			"League alleys: rust, lies, and lunch smells. I sell edges, not optimism.",
			"City politics greases every hinge. I scrub it off so your rivets don't try to negotiate when you get hit."
		]
	},
	{
		"unlock_level": 4,
		"lines": [
			"Salt up here eats iron for breakfast. Scrub your kit before you hand it over, or I'll charge you a frustration fee.",
			"Dock-night work is whisper, hurry, panic. My forge does stubborn — it's how I flirt."
		]
	},
	{
		"unlock_level": 5,
		"lines": [
			"Greyspire groans if you breathe wrong on it. Show respect — it's been breaking tourists since before your bloodline learned to walk upright.",
			"Necro-chill in the stone? Quench hot, oil often, and don't trust gear that hums lullabies."
		]
	},
	{
		"unlock_level": 6,
		"lines": [
			"Hoists that work, roof that drips elsewhere — I'm practically noble. Try not to track mud on my mood.",
			"This hub isn't a tavern. I don't serve comfort — I serve 'you'll thank me when the cleaving starts.'"
		]
	},
	{
		"unlock_level": 7,
		"lines": [
			"Famine makes folks creative with knives. Keep yours sharper than their excuses.",
			"Grain wagons, war wagons — same nails, different drama. I forge the bits that don't argue."
		]
	},
	{
		"unlock_level": 8,
		"lines": [
			"Sacred groves side-eye my hammer. Joke's on them — trees can't hold a file.",
			"Spirit-touched steel gets dramatic if you quench like a startled chicken. Breathe. Count. Hit."
		]
	},
	{
		"unlock_level": 9,
		"lines": [
			"Diplomacy's a tin shield. I'll hand you steel for when the mountain disagrees with your agenda.",
			"Mountain passes freeze ambition and rivets. Warm up here — pride thaws slower than grease."
		]
	},
	{
		"unlock_level": 10,
		"lines": [
			"Sunlit arenas sell theater. I sell 'you walk home with the same number of limbs you arrived with.'",
			"They'll judge your soul under banners. I'll judge your tang. Souls don't pay my coal bill."
		]
	},
	{
		"unlock_level": 11,
		"lines": [
			"Masked crowds, masked blades, masked bad ideas. Tighten your fittings — fashion kills sloppy.",
			"Carnival forges sell snap and sparkle. I sell 'still straight after the third liar.'"
		]
	},
	{
		"unlock_level": 12,
		"lines": [
			"College ink argues; hammer wins. Bring your codex if you want — I'll use it as a shim.",
			"They catalog truth; I compress it into bar stock. Same hobby, different shelf."
		]
	},
	{
		"unlock_level": 13,
		"lines": [
			"Beach landings: sand in the mail, salt in the soul. Shake your boots before you drip on my floor — I'm not a beach.",
			"Cannon smoke and hero hair don't mix. I'll fix the steel; you fix the vanity."
		]
	},
	{
		"unlock_level": 14,
		"lines": [
			"'Safehold' my beard. If betrayal had a weight, we'd need a bigger anvil.",
			"Three-front fights, one dwarf — story of my life. Line up the problems; I'll line up the rivets."
		]
	},
	{
		"unlock_level": 15,
		"lines": [
			"Weeping Marsh wants my boots, my temper, and my lunch. It can have the lunch.",
			"Poison spreads; so does gossip. Only one of those I can patch with a file — guess which I prefer."
		]
	},
	{
		"unlock_level": 16,
		"lines": [
			"Puzzle trials? Cute. Try puzzling out why your pommel wobbles after a week of real war.",
			"Spectral guardians don't tip. Good — neither do I when the quench is wrong."
		]
	},
	{
		"unlock_level": 17,
		"lines": [
			"Three faction camps, one coal budget, infinite opinions. I'm selling steel, not consensus.",
			"Diplomacy-by-arrow is inefficient. So is dull plate. Fix both before dinner."
		]
	},
	{
		"unlock_level": 18,
		"lines": [
			"Sky's doing tricks, sea's rude, tower's wrong. My anvil stays flat — that's my whole personality.",
			"Ritual towers love drama. Hammers love grammar: subject, verb, dent."
		]
	},
	{
		"unlock_level": 19,
		"lines": [
			"Truth and void and whatever's chewing the horizon — fine. Steel still obeys heat and shame.",
			"If the world's ending, we're ending it with sharp tools and worse language. Welcome."
		]
	},
	{
		"unlock_level": 20,
		"lines": [
			"Epilogue's just another shift if you still draw breath. Bring grief; I'll weld it to something useful.",
			"War winds down, tongs don't. Someone's gotta file the future straight — might as well be us."
		]
	}
]


func get_blacksmith_welcome_pool() -> Array:
	var out: Array = []
	var prog: int = CampaignManager.max_unlocked_index
	for raw_w in blacksmith_lines["welcome"]:
		out.append(normalize_blacksmith_line_pick(raw_w))
	for tier in blacksmith_welcome_progress:
		if prog < int(tier.get("unlock_level", 0)):
			continue
		var raw: Variant = tier.get("lines", [])
		if raw is Array:
			for line in raw as Array:
				out.append(normalize_blacksmith_line_pick(line))
	return out


func normalize_blacksmith_line_pick(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		var d: Dictionary = raw as Dictionary
		return {"text": str(d.get("text", "")), "solo_hint": d.get("solo_hint", null)}
	return {"text": str(raw), "solo_hint": null}


func blacksmith_escape_bbcode_literal(s: String) -> String:
	return str(s).replace("[", "[lb]")


const HALDOR_SOLO_FIRST_HOOK_ID: String = "haldor_solo_first_quiet"
const NARRATIVE_BEAT_FAMILY_HALDOR_FORGE: String = "haldor_forge"
const NARRATIVE_BEAT_FAMILY_ROSTER_SOLO: String = "roster_solo"


## Group beats for unlock math (e.g. [code]min_other_solo_scenes_seen[/code] only counts same family). [code]haldor_solo_*[/code] ids default to [member NARRATIVE_BEAT_FAMILY_HALDOR_FORGE]; set [code]beat_family[/code] on roster/world beats.
func narrative_beat_family(def: Dictionary) -> String:
	var f: String = str(def.get("beat_family", "")).strip_edges()
	if f != "":
		return f
	var bid: String = str(def.get("id", "")).strip_edges()
	if bid.begins_with("haldor_solo_"):
		return NARRATIVE_BEAT_FAMILY_HALDOR_FORGE
	return "narrative"


## Resolved [member narrative_beat_family] for a registered beat id, or empty if unknown.
func narrative_beat_family_for_id(beat_id: String) -> String:
	var sid: String = str(beat_id).strip_edges()
	if sid == "":
		return ""
	for def_raw in narrative_beat_definitions:
		if not (def_raw is Dictionary):
			continue
		var def: Dictionary = def_raw as Dictionary
		if str(def.get("id", "")).strip_edges() == sid:
			return narrative_beat_family(def)
	return ""


## First eligible unseen roster solo for [param unit_name] (Camp Explore), in definition order. See [member NARRATIVE_BEAT_FAMILY_ROSTER_SOLO] beats with [code]solo_unit_name[/code].
func get_eligible_roster_solo_beat_id(unit_name: String, max_unlocked_index: int, seen_beat_ids: Dictionary = {}) -> String:
	var uname: String = str(unit_name).strip_edges()
	if uname == "":
		return ""
	for def_raw in narrative_beat_definitions:
		if not (def_raw is Dictionary):
			continue
		var def: Dictionary = def_raw as Dictionary
		if narrative_beat_family(def) != NARRATIVE_BEAT_FAMILY_ROSTER_SOLO:
			continue
		if str(def.get("solo_unit_name", "")).strip_edges() != uname:
			continue
		var bid: String = str(def.get("id", "")).strip_edges()
		if bid == "" or bool(seen_beat_ids.get(bid, false)):
			continue
		if not is_narrative_beat_unlocked(bid, max_unlocked_index, seen_beat_ids):
			continue
		return bid
	return ""


func count_narrative_beats_seen_in_family_excluding(seen_beat_ids: Dictionary, family: String, exclude_beat_id: String) -> int:
	var ex: String = str(exclude_beat_id).strip_edges()
	var fam: String = str(family).strip_edges()
	var n: int = 0
	for def_raw in narrative_beat_definitions:
		if not (def_raw is Dictionary):
			continue
		var def: Dictionary = def_raw as Dictionary
		if narrative_beat_family(def) != fam:
			continue
		var sid: String = str(def.get("id", "")).strip_edges()
		if sid == "" or sid == ex:
			continue
		if bool(seen_beat_ids.get(sid, false)):
			n += 1
	return n


func _narrative_beat_def_unlocked_for_player(def: Dictionary, max_unlocked_index: int, seen_beat_ids: Dictionary) -> bool:
	var cap: int = maxi(0, int(max_unlocked_index))
	var need_map: int = maxi(0, int(def.get("min_max_unlocked_index", 999)))
	if cap < need_map:
		return false
	var req_seen: String = str(def.get("requires_seen_beat_id", "")).strip_edges()
	if req_seen != "" and not bool(seen_beat_ids.get(req_seen, false)):
		return false
	var min_other: int = 0
	if def.has("min_other_beats_seen"):
		min_other = maxi(0, int(def.get("min_other_beats_seen", 0)))
	elif def.has("min_other_solo_scenes_seen"):
		min_other = maxi(0, int(def.get("min_other_solo_scenes_seen", 0)))
	if min_other > 0:
		var sid: String = str(def.get("id", "")).strip_edges()
		var fam: String = narrative_beat_family(def)
		if count_narrative_beats_seen_in_family_excluding(seen_beat_ids, fam, sid) < min_other:
			return false
	return true


func is_narrative_beat_unlocked(beat_id: String, max_unlocked_index: int, seen_beat_ids: Dictionary = {}) -> bool:
	var sid: String = str(beat_id).strip_edges()
	if sid == "":
		return false
	for def_raw in narrative_beat_definitions:
		if not (def_raw is Dictionary):
			continue
		var def: Dictionary = def_raw as Dictionary
		if str(def.get("id", "")).strip_edges() != sid:
			continue
		return _narrative_beat_def_unlocked_for_player(def, max_unlocked_index, seen_beat_ids)
	return false


func is_haldor_solo_scene_unlocked(scene_id: String, max_unlocked_index: int, seen_scene_ids: Dictionary = {}) -> bool:
	var sid: String = str(scene_id).strip_edges()
	if sid == "":
		return false
	for def_raw in narrative_beat_definitions:
		if not (def_raw is Dictionary):
			continue
		var def: Dictionary = def_raw as Dictionary
		if str(def.get("id", "")).strip_edges() != sid:
			continue
		if narrative_beat_family(def) != NARRATIVE_BEAT_FAMILY_HALDOR_FORGE:
			return false
		return _narrative_beat_def_unlocked_for_player(def, max_unlocked_index, seen_scene_ids)
	return false


## First camp solo is always the hook scene until seen; after that, meta [param requested_scene_id] if still unseen, else a random other unseen eligible scene (replay variety).
func resolve_haldor_solo_scene_pick(requested_scene_id: String, max_unlocked_index: int, seen_scene_ids: Dictionary) -> String:
	var req: String = str(requested_scene_id).strip_edges()
	var cap: int = maxi(0, int(max_unlocked_index))
	if not bool(seen_scene_ids.get(HALDOR_SOLO_FIRST_HOOK_ID, false)):
		if is_haldor_solo_scene_unlocked(HALDOR_SOLO_FIRST_HOOK_ID, cap, seen_scene_ids):
			return HALDOR_SOLO_FIRST_HOOK_ID
	if req == "":
		return req
	if not bool(seen_scene_ids.get(req, false)):
		return req
	var unseen: Array = pick_haldor_solo_unseen_scene_ids(cap, seen_scene_ids)
	if unseen.is_empty():
		return req
	var filtered: Array = []
	for s in unseen:
		if str(s) != req:
			filtered.append(s)
	if filtered.is_empty():
		return str(unseen[randi() % unseen.size()])
	return str(filtered[randi() % filtered.size()])


func pick_haldor_solo_unseen_scene_ids(max_unlocked_index: int, seen_scene_ids: Dictionary) -> Array:
	var out: Array = []
	for sid in get_unlocked_forge_haldor_beat_ids_ordered(max_unlocked_index, seen_scene_ids):
		if not bool(seen_scene_ids.get(str(sid), false)):
			out.append(sid)
	return out


func pick_random_unseen_haldor_solo_scene_id(max_unlocked_index: int, seen_scene_ids: Dictionary) -> String:
	var pool: Array = pick_haldor_solo_unseen_scene_ids(max_unlocked_index, seen_scene_ids)
	if pool.is_empty():
		return ""
	return str(pool[randi() % pool.size()])


func is_haldor_solo_scene_hint_eligible(scene_id: String, max_unlocked_index: int, seen_scene_ids: Dictionary) -> bool:
	var sid: String = str(scene_id).strip_edges()
	if sid == "":
		return false
	if bool(seen_scene_ids.get(sid, false)):
		return false
	for def_raw in narrative_beat_definitions:
		if not (def_raw is Dictionary):
			continue
		var def: Dictionary = def_raw as Dictionary
		if str(def.get("id", "")).strip_edges() != sid:
			continue
		if narrative_beat_family(def) != NARRATIVE_BEAT_FAMILY_HALDOR_FORGE:
			return false
		return _narrative_beat_def_unlocked_for_player(def, max_unlocked_index, seen_scene_ids)
	return false


## Wraps [param needle] in underline + url meta when [param solo_hint] is active (unlocked, not yet seen). [param plain_text] must be plain (no BBCode). [param debug_force] skips unlock/seen checks (dev-only; see camp F9 test).
func apply_haldor_solo_tap_hint(plain_text: String, solo_hint: Variant, max_unlocked_index: int, seen_scene_ids: Dictionary, debug_force: bool = false) -> String:
	var body: String = blacksmith_escape_bbcode_literal(str(plain_text))
	if solo_hint == null or not (solo_hint is Dictionary):
		return body
	var d: Dictionary = solo_hint as Dictionary
	var scene_id: String = str(d.get("scene_id", "")).strip_edges()
	var needle: String = str(d.get("needle", "")).strip_edges()
	if scene_id == "" or needle == "":
		return body
	if bool(d.get("variety_unseen", false)):
		var spun: String = pick_random_unseen_haldor_solo_scene_id(max_unlocked_index, seen_scene_ids)
		if spun != "":
			scene_id = spun
	if not debug_force and not is_haldor_solo_scene_hint_eligible(scene_id, max_unlocked_index, seen_scene_ids):
		return body
	var needle_esc: String = blacksmith_escape_bbcode_literal(needle)
	var pos: int = body.find(needle_esc)
	if pos < 0:
		return body
	var before: String = body.substr(0, pos)
	var after: String = body.substr(pos + needle_esc.length())
	var wrap_bb: String = "[url=" + scene_id + "][u][color=#d8c27a]" + needle_esc + "[/color][/u][/url]"
	return before + wrap_bb + after


## Dev: build a tap line that always underlines [param needle] → [param scene_id] (used with [member CampaignManager.debug_forge_haldor_meta_gates_bypass]).
func apply_haldor_solo_tap_hint_for_debug(plain_text: String, needle: String, scene_id: String) -> String:
	var hint: Dictionary = {"needle": str(needle).strip_edges(), "scene_id": str(scene_id).strip_edges()}
	return apply_haldor_solo_tap_hint(plain_text, hint, 0, {}, true)


## Camp Explore roster solo gate: append an underlined BBCode url link for [param beat_id] (same style as forge Haldor hints). [param plain_idle_body] is plain text (brackets escaped).
func apply_camp_roster_solo_tap_hint(plain_idle_body: String, beat_id: String, cta_needle: String = "Sit a while — proper talk.") -> String:
	var body: String = blacksmith_escape_bbcode_literal(str(plain_idle_body).strip_edges())
	var bid: String = str(beat_id).strip_edges()
	var needle: String = str(cta_needle).strip_edges()
	if bid == "" or needle == "":
		return body
	var needle_esc: String = blacksmith_escape_bbcode_literal(needle)
	var wrap_bb: String = "[url=" + bid + "][u][color=#d8c27a]" + needle_esc + "[/color][/u][/url]"
	if body == "":
		return wrap_bb
	return body + "\n\n" + wrap_bb


func get_haldor_beat_solo_hint(beat_id: String) -> Variant:
	var ent: Dictionary = get_haldor_beat_entry(str(beat_id).strip_edges())
	return ent.get("solo_hint", null)


var merchant_lines: Dictionary = {
	"welcome": [
		"Well, %s. The road delivered you intact. Pity for my odds.",
		"Take a seat, %s. The wares are honest. The prices are not.",
		"Greetings, %s. The paladins still want my head, so speak softly.",
		"Ah, %s. I carry provisions for war, regret, and profit. Mostly profit.",
		"Welcome, %s. If your armor drips, aim away from the cloth.",
		"Step closer, %s. The donkey bites only the indecisive.",
		"You smell like battle, %s. That scent costs extra to air out.",
		"I hear the guild whispers your name, %s. I prefer coins over gossip.",
		"Come browse, %s. Everything here was acquired with minimal witness.",
		"Ah, %s. I kept your favorite shelf empty. For a fee.",
		"If you seek holy relics, %s, I carry several that have never seen a temple.",
		"Tomb dust on your boots, %s. We understand each other.",
		"The goblin markets raised my prices today, %s. Blame their enthusiasm.",
		"Welcome, %s. I offer steel, salves, and moral ambiguity.",
		"Back from the dead again, %s. My ledger hates surprises.",		
		"Back already, %s? My prices are high, but my standards are... questionable.",
		"Ah, the legendary %s. Please, buy something. My donkey is very hungry.",
		"Looking for steel, %s? Or perhaps a very shiny spoon? I have both.",
		"Stay a while and listen, %s. Or just give me your gold. Mostly the gold.",
		"I've traveled from Val-d'Or just to sell you this junk, %s. Don't let me down.",
		"The battlefield looks rough, %s. Lucky for you, greed is my primary motivator.",
		"Welcome back, %s. Try not to bleed on the merchandise this time.",
		"Ah, %s. I was just wondering who would fund my early retirement.",
		"Do come in, %s. The guild thinks I am dead, so let us keep this transaction quiet.",
		"I have goods from the far reaches of the abyss, %s. And also some very mediocre boots.",
		"Greetings, %s. If the authorities ask, we have never met.",
		"You survived, %s. Frankly, I had already started marking up your reserved gear.",
		"Step right up, %s. I have exactly what you need to delay your inevitable demise.",
		"Ah, %s. Still breathing, I see. How terribly inconvenient for my betting pool.",
		"Welcome, %s. Please lower your voice, the cursed amulets are trying to sleep.",
		"I see you brought your coin purse, %s. Let us relieve you of that heavy burden."
	],
	"buy": [
		"Sold, %s. If it screams at night, sleep farther away.",
		"A wise purchase, %s. The previous owner stopped complaining eventually.",
		"Keep the wax mark, %s. It proves you overpaid.",
		"Fine choice, %s. I polished it with a very clean prayer.",
		"Spend freely, %s. The war will not refund you.",
		"Take it, %s. May it wound your foes more than it wounds your purse.",
		"A pleasant exchange, %s. My donkey approves of the weight.",
		"Good, %s. One less cursed trinket for me to babysit.",
		"Excellent, %s. I can now afford silence from the guild.",
		"Hold it firmly, %s. Some artifacts prefer to be carried, not owned.",
		"May it serve you, %s. If it does not, I never met you.",
		"A bold buy, %s. Boldness and coin often travel together.",
		"You have taste, %s. Tragic, expensive taste.",
		"There. Yours, %s. Try not to wake whatever is sleeping inside it.",
		"Thank you, %s. I shall invest this gold in distance.",		
		"A fine choice, %s. That was almost a family heirloom.",
		"Careful with that, %s. It's sharp. I think.",
		"A pleasure doing business. Tell your friends (if they're rich), %s.",
		"This item has a 100%% guarantee. (Guarantee void upon leaving the camp, %s.)",
		"Sold. You've got an eye for quality, %s. Or at least for things that glow.",
		"An excellent choice, %s. I looted that from a very prestigious corpse.",
		"Consider it yours, %s. No refunds if it spontaneously combusts.",
		"A wise investment, %s. Or at least, a very profitable one for me.",
		"I will miss that one, %s. It doubled as a decent back scratcher.",
		"Sold to %s. May it serve you better than it served its previous, much deader owner.",
		"Thank you, %s. I can finally pay off that bounty hunter.",
		"You have exquisite taste, %s. And remarkably deep pockets.",
		"It is yours, %s. I accept no liability for any curses, hexes, or minor hauntings.",
		"Marvelous, %s. I was wondering how to get rid of that without alerting the guards.",
		"A transaction wrapped in mutual respect, %s. Mostly respect for your gold."
	],
	"sell": [
		"Let me see that, %s. It looks like it survived you by accident.",
		"I will buy it, %s. Not because it has worth, but because it has a market.",
		"Is that a paladin seal, %s. Interesting. I will pay extra to forget it.",
		"Fine, %s. The goblins will love it, or eat it. Either way, profit.",
		"I will take this off your hands, %s. Your hands will thank me.",
		"This reeks of tomb wards, %s. I charge a handling fee in my heart.",
		"Very well, %s. I know a dwarf who asks no questions and counts quickly.",
		"You call it loot, %s. I call it inventory.",
		"I will offer you a fair price, %s. Fair to me.",
		"Hand it over, %s. I have fenced worse to saints with clean hands.",
		"This blade has stories, %s. I will sell it as a legend and pay you as scrap.",
		"I will buy it, %s. If anyone asks, you found it in a river.",
		"All right, %s. I will add it to the pile marked regrettable.",
		"Hmm, %s. Bloodstains add character, and character adds coin.",
		"Deal, %s. Your trash becomes my doctrine.",		
		"You want me to pay for this, %s? Fine, but I'm losing money here.",
		"Ooh, slightly used. I can work with this, %s.",
		"I'll give it a new home. Or melt it down. Probably melt it down, %s.",
		"Is this blood, %s? Never mind, don't tell me. I'll just double the cleaning fee.",
		"I'll take it off your hands, %s. It'll make a great paperweight.",
		"I suppose I can take this, %s. The goblin market is remarkably forgiving.",
		"Are you sure, %s. This looks suspiciously like evidence.",
		"Hand it over, %s. I know a wizard who buys absolute garbage.",
		"I will give you half its value, %s. And consider it a personal favor.",
		"You bring me such curious trash, %s.",
		"Fine, %s. I will put it with the other things nobody wants.",
		"If you insist, %s. But I will need to wash my hands after touching this.",
		"I am buying this purely out of pity, %s.",
		"Let us just toss this in the bargain bin, %s. Right next to my hopes and dreams.",
		"Very well, %s. I have fenced worse things to better people."
	],
	"poor": [
		"Your purse sounds hollow, %s. My donkey finds that unsettling.",
		"No coin, %s. No miracles.",
		"I trade in gold, %s. Not good intentions.",
		"That offer would shame a goblin, %s.",
		"If you cannot pay, %s, at least stop breathing on the inventory.",
		"Come back richer, %s. Preferably alive.",
		"I have seen beggars with fuller purses, %s.",
		"If you insist on poverty, %s, do it elsewhere.",
		"I do not accept vows, %s. The last paladin tried, and it tasted like air.",
		"The guild taught me many things, %s. Charity was not among them.",
		"Your gold is missing, %s. I notice such tragedies.",
		"Try the temple, %s. They hand out blessings, not blades.",
		"You could always rob a tomb, %s. I hear it builds character.",
		"My donkey charges interest, %s. He starts by biting.",
		"Return when you can afford regret, %s.",		
		"Gold, my friend. I need the shiny yellow stuff. Not promises, %s.",
		"I'm a merchant, not a charity, %s. Come back when you're wealthier.",
		"That's a lot of window shopping for someone with empty pockets, %s.",
		"I cannot accept lint as payment, %s.",
		"Your lack of funds is deeply offensive to my religion, %s.",
		"Perhaps try looting more efficiently, %s.",
		"I am running a business, %s, not a refuge for the financially inept.",
		"Come back when your purse matches your ambition, %s.",
		"Are you trying to pay me in exposure, %s. Because that does not feed the donkey.",
		"Your gold count is as tragic as your fashion sense, %s.",
		"Please step aside, %s. You are blocking the paying customers. Oh wait, there are none.",
		"I would offer you a loan, %s, but I enjoy my kneecaps exactly where they are.",
		"This is a shop, %s. You give me gold, I give you items. It is a very simple concept."
	],
	"haggle_win": [
		"Fine, %s. I will shave the price, not my beard.",
		"You win, %s. My margins limp away.",
		"All right, %s. The donkey will eat less and judge you more.",
		"Very well, %s. Tell no one you saw weakness in me.",
		"A discount, %s. I hope it keeps you warm at night.",
		"You negotiated like a dwarf in a closed mine, %s.",
		"There. Lowered, %s. My scribe just fainted somewhere.",
		"Take your victory, %s. I will recover in the next transaction.",
		"Price reduced, %s. My grudges remain full price.",
		"I concede, %s. Your tongue is sharper than your steel.",
		"All right, %s. I will call it a loyalty reward for not dying.",
		"Fine, %s. I will pretend this was my idea.",
		"Discount granted, %s. The guild will hear a different story.",
		"You have talent, %s. It is wasted on heroism.",
		"Agreed, %s. The coin still shines, even when fewer.",
		"Alright, alright, %s. You drive a hard bargain. I'll lower my margins... slightly.",
		"You're robbing me blind, %s. But fine, your reputation precedes you.",
		"Fine, %s. Take it for less. I will just skip dinner tonight.",
		"You are a ruthless negotiator, %s. My donkey will go hungry because of you.",
		"Very well, %s. Consider this a discount for your highly intimidating aura.",
		"I concede, %s. You haggle like a dwarven debt collector.",
		"A lower price, as requested, %s. Please do not tell the Merchants Guild.",
		"You win this round, %s. I hope you feel proud of swindling a humble man.",
		"Discount applied, %s. Let the record show I protested vehemently.",
		"Alright, %s. But I expect a glowing recommendation to the next wealthy traveler.",
		"Take it, %s. Just take it and leave me to my sorrow.",
		"You have beaten me down, %s. I am emotionally and financially ruined."
	],
	"haggle_lose": [
		"No, %s. I have standards, and they cost money.",
		"Your argument is stirring, %s. My price remains unmoved.",
		"Try again after you defeat a dragon, %s. Dragons pay better.",
		"I refuse, %s. The donkey says your offer is weak.",
		"That was adorable, %s. The number stays the same.",
		"My prices are carved in stone, %s. Dwarven stone.",
		"You may bargain with goblins, %s. I charge for dignity.",
		"Not today, %s. I enjoy eating.",
		"If I lower it, %s, the paladins might think I have a heart.",
		"No discount, %s. I already risked my neck acquiring it.",
		"Your haggling lacks venom, %s. The guild would be disappointed.",
		"Keep your coin ready, %s. You will need all of it.",
		"I have heard worse offers in a graveyard, %s.",
		"My answer stays no, %s. Repetition only increases the price.",
		"Haggle all you like, %s. The number will not flinch.",
		"Nice try, %s. But Bartholomew The Bold does not fold so easily.",
		"Stick to fighting, %s. Leave the economics to the professionals.",
		"I admire your audacity, %s, but my prices are as fixed as my moral compass.",
		"Absolutely not, %s. I have a bounty to pay off.",
		"You cannot charm me, %s. I left my heart in a tavern in Val-d'Or.",
		"Try that again, %s, and I will start charging you for breathing my air.",
		"Did you really think that would work on me, %s.",
		"No discount for you, %s. In fact, I am tempted to charge a loitering fee.",
		"My donkey negotiates better than you do, %s.",
		"Do I look like a philanthropist, %s. The price remains.",
		"I would rather throw it in the river than sell it for that, %s.",
		"A tragic attempt at bartering, %s. Stick to swinging your weapon."
	],
	"haggle_mid": [
		"You are warming up, %s. My patience is not infinite, but it is theatrical.",
		"Halfway there, %s. The donkey is taking notes.",
		"Steady, %s. I respect a buyer who can hover.",
		"Interesting rhythm, %s. Are you negotiating or conducting an orchestra?",
		"You have focus, %s. That is almost as valuable as coin.",
	],
	"haggle_concede": [
		"Fine, %s. Walk away. I will pretend this never tested my nerves.",
		"Go, %s. My ledger will not mourn what you did not buy.",
		"As you wish, %s. The price remains, and my opinion of you is merely confused.",
		"Leaving mid-dance, %s. How very diplomatic.",
		"No harm done, %s. Next time bring steadier hands or heavier coin.",
	],
	"haggle_win_extra": [
		"And %s — I will mark a second shelf item down before I regret it. Do not make me say it twice.",
		"You broke me twice today, %s. Another piece joins the half-price pile. Happy?",
		"Fine, %s. Two discounts. The guild will assume I was hit on the head.",
		"Take your victory lap, %s. A second trinket goes on sale before I come to my senses.",
	],
	"idle": [
		"Are you going to buy something, %s, or just stare at my magnificent beard.",
		"I once sold a half-eaten apple to a king. True story, %s.",
		"It is quiet today... too quiet. Buy a sword, %s, just in case.",
		"Did I mention these prices are a steal, %s. Because I might have stolen some of this.",
		"Take your time, %s. It is not like I have other customers.",
		"I was not always a merchant, %s. The Guild of Assassins simply had a terrible pension plan.",
		"They say I was born from a dragon's hoard, %s. The truth involves far more paperwork and a very angry dwarven king.",
		"This monocle is not for show, %s. Staring into the abyss is quite bad for one's depth perception.",
		"Do not ask how I acquired the Archmage's spare slippers, %s. Plausible deniability is my greatest ware.",
		"My donkey is named after my first commanding officer, %s. They share the same stubbornness and smell.",
		"The Paladins of the Silver Hand are currently looking for me, %s. If they ask, I am merely a humble turnip farmer.",
		"I fought in the Siege of the Black Citadel, %s. Well, I sold overpriced bandages to the survivors, which is basically the same thing.",
		"Some call it grave robbing, %s. I prefer the term archaeological liquidation.",
		"I learned the art of the deal in the deep mines of Val-d'Or, %s. The goblins down there drive a very hard bargain.",
		"If you perish in the next battle, %s, do you mind if I reclaim my merchandise.",
		"My donkey is staring at you, %s. He only judges the guilty.",
		"I once smuggled dwarven silver through a monastery, %s. The monks were excellent customers.",
		"Do not touch the black ring, %s. It touches back.",
		"The guild sent me a letter once, %s. It was mostly threats and poor spelling.",
		"If you need a paladin, %s, try the next valley. I sell them rope and lies.",
		"Some heroes chase glory, %s. I chase debts that multiply.",
		"The goblin market taught me that morals are negotiable, %s.",
		"I can smell cursed silver, %s. It smells like opportunity.",
		"If a tomb whispers your name, %s, you should answer with a shovel. I did.",
		"That scar on my neck, %s. A paladin tried to collect what I owed.",
		"The donkey prefers oats, %s. I prefer your coin. We compromise poorly.",
		"I keep my daggers for cutting rope now, %s. Mostly.",
		"Every artifact here has a history, %s. Some also have a temper.",
		"If the war ends tomorrow, %s, I will sell mourning cloaks by sunset.",
		"Take your time, %s. I am only counting how long it takes you to surrender your gold."	
	]
}

var talk_lines: Dictionary = {
	"idle_open": [
		"What do you want, {name}. Time is money.",
		"Speak, {name}. The donkey charges me for loitering.",
		"If you are here to browse, {name}, at least look expensive.",
		"You have that heroic stare, {name}. It usually precedes unpaid invoices.",
		"Keep it brief, {name}. My profit margin is on a tight leash.",
		"If the paladins appear, {name}, you saw a turnip farmer.",
		"I have wares and a questionable conscience, {name}. Choose quickly.",
		"The war drags on, {name}. My prices keep pace.",
		"My tent is open, {name}. My trust is not.",
		"Ask for work or rumors, {name}. Small talk costs extra.",
		"Do not touch anything glowing, {name}. Unless you plan to buy it.",
		"I am listening, {name}. Mostly for coin clinking.",
		"You again, {name}. The guild would call this persistence.",
		"If you need a blessing, {name}, try a chapel. I sell outcomes.",
		"I have a schedule, {name}. It begins with payment."
	],
	"quest_waiting": [
		"I am still waiting on {amount} {item}{plural}, {name}. The donkey keeps count better than you.",
		"Bring me {amount} {item}{plural}, {name}. Preferably not soaked in blood this time.",
		"My ledger says {amount} {item}{plural}, {name}. The ledger rarely lies, unlike people.",
		"You owe me {amount} {item}{plural}, {name}. I would settle for speed, but coin will do.",
		"I require {amount} {item}{plural}, {name}. The tombs will not rob themselves.",
		"Still collecting {amount} {item}{plural}, {name}. Try the goblin stalls if you are desperate.",
		"The contract remains {amount} {item}{plural}, {name}. I wrote it in ink and spite.",
		"Deliver {amount} {item}{plural}, {name}. I have buyers who do not ask questions.",
		"I want {amount} {item}{plural}, {name}. If you bring fewer, you bring disappointment.",
		"Do you have my {amount} {item}{plural}, {name}. My patience has a shorter lifespan than you.",
		"Find {amount} {item}{plural}, {name}. The guild expects results, and so do I.",
		"I am paying for {amount} {item}{plural}, {name}. Do not make me look charitable.",
		"{amount} {item}{plural}, {name}. That is the whole job. Try not to improve it.",
		"You will return with {amount} {item}{plural}, {name}. Or you will return empty, which is worse.",
		"I am still missing {amount} {item}{plural}, {name}. The war ends faster than your errands."
	],
	"quest_short": [
		"Do not waste my time. You have {found} of {amount} {item}{plural}.",
		"Count with me. {found} of {amount} {item}{plural}. You are not done.",
		"You brought {found}. I asked for {amount} {item}{plural}. Try again.",
		"I see {found} in your pack. I require {amount} {item}{plural}.",
		"So far, {found} of {amount} {item}{plural}. My donkey looks unimpressed.",
		"{found} does not equal {amount}. Neither does wishful thinking. Bring {item}{plural}.",
		"You are short. {found} of {amount} {item}{plural}. That is arithmetic, not an insult.",
		"If you cannot reach {amount} {item}{plural}, stop bringing me {found} and excuses.",
		"The guild would laugh. {found} of {amount} {item}{plural}. I am close to joining them.",
		"You are nearly competent. {found} of {amount} {item}{plural}. Do not ruin it now.",
		"I can sell {found}. I can pay for {amount}. Finish the job.",
		"I will not pay full reward for {found} of {amount} {item}{plural}. I am greedy, not confused.",
		"{found} of {amount}. Bring the rest of the {item}{plural} before the trail goes cold.",
		"I am still missing {missing} {item}{plural}. You keep returning with {found}.",
		"This is a collection job, not a heroic tale. {found} of {amount} {item}{plural}."
	],
	"quest_complete": [
		"Excellent. Here is your {reward} gold, {name}. Spend it before someone braver takes it.",
		"Good. {reward} gold, {name}. Your competence has been noted, briefly.",
		"Payment delivered. {reward} gold, {name}. Do not make me regret accuracy.",
		"Here. {reward} gold, {name}. The donkey approves of punctual labor.",
		"You delivered. I pay. {reward} gold, {name}. That is the only romance I tolerate.",
		"{reward} gold, {name}. If you tell anyone I paid fairly, I will deny it.",
		"Well done. {reward} gold, {name}. The guild will be pleased. I will be richer.",
		"Take {reward} gold, {name}. Try not to die with it unspent.",
		"{reward} gold, {name}. I will now pretend you were never in debt.",
		"A clean delivery. {reward} gold, {name}. As clean as business gets.",
		"You have earned {reward} gold, {name}. I am mildly annoyed by your success.",
		"{reward} gold, {name}. Next time I will ask for something harder, to restore balance.",
		"Here is {reward} gold, {name}. I will reinvest my gratitude into more profit.",
		"{reward} gold, {name}. The paladins would call this blood money. I call it money.",
		"Take {reward} gold, {name}. Then leave before I start offering a bonus."
	],
	"abandon": [
		"A shame, {name}. I will hire someone less heroic and more reliable.",
		"Fine, {name}. I will find a goblin with lower standards.",
		"You withdraw, {name}. My ledger will survive. Your reputation may not.",
		"Understood, {name}. Do not expect me to remember you fondly, or at all.",
		"So be it, {name}. I will sell your promise at a discount.",
		"Leaving empty-handed, {name}. A bold strategy for someone who likes breathing.",
		"Very well, {name}. I will assign the work to my donkey. He at least shows up.",
		"You abandon the job, {name}. The guild loves that sort of tragedy.",
		"I accept your surrender, {name}. It costs nothing, which suits you.",
		"Fine, {name}. I will recover my losses by raising prices. On you.",
		"Then we are done, {name}. Do not return expecting warm words.",
		"Quit if you must, {name}. I will remember this at the bargaining table.",
		"All right, {name}. Someone else will loot the tombs and take the credit.",
		"As you wish, {name}. Try not to waste my time twice.",
		"Go, {name}. My patience is a finite resource and you have spent it."
	],
	"rumors": [
		"Rumor says the duke hired paladins to cleanse the old road, {name}. They mostly cleanse travelers of coin.",
		"They say goblins are selling blessed arrows this week, {name}. The blessing is usually a lie.",
		"A tomb near the Black Fen reopened, {name}. It also reclosed. On a party.",
		"The Silver Hand is hunting a merchant with a monocle, {name}. Terrible description, truly.",
		"A witch in the pines buys battlefield teeth, {name}. I do not ask why. I only ask the price.",
		"Word is a necromancer is paying in rubies, {name}. The rubies scream less than the corpses.",
		"The dwarven mines are sealed again, {name}. Smugglers are already celebrating.",
		"A cursed chalice surfaced in the river, {name}. Everyone who drank from it became honest for a day.",
		"A bandit lord is collecting banners, {name}. Apparently cloth has a market now.",
		"The archmage mislaid a staff, {name}. Half the realm is searching. I already priced it.",
		"A paladin relic was sold in a goblin market, {name}. The paladins pretend not to know.",
		"They say the king is afraid of donkeys, {name}. Sensible man, in my experience.",
		"There is a shrine that grants luck for a tithe, {name}. The priest keeps the luck.",
		"A caravan vanished near the old watchtower, {name}. Survivors report polite skeletons.",
		"Someone is forging guild seals again, {name}. I respect the craft, not the competition."
	]
}

## Talk-button monologues. [code]unlock_level[/code] gates on [code]CampaignManager.max_unlocked_index[/code] (increments as story maps clear). Tiers 0–20 align with NARRATIVE PLAN maps 1–20 (same numbering as plan). Optional rune flags for craft unlocks. Includes an About-Haldor block at unlock 0 plus a few tiered self-reveals. Tone: gruff, proud, deadpan funny — steel first, feelings filed smooth.
var blacksmith_monologues = [
	# --- Map 1+ / always ---
	{"unlock_level": 0, "text": "My old man used to say: 'Haldor, a dwarf is only as good as the temper of his steel.' I've spent fifty years trying to prove him right — and forty-nine apologizing to the neighbors for the noise."},
	{"unlock_level": 0, "text": "They ask why I left the Great Halls. Too many kings, not enough anvils. Out here, the air is cold, but the metal is honest — unlike my last landlord."},
	{"unlock_level": 0, "text": "Dwarven ale is meant to be thick enough to chew. This human swill you lot drink is basically water with a bad attitude and a marketing budget."},
	{"unlock_level": 0, "text": "I wasn't at Oakhaven when the sky tore — but I smelled the ash on the wind. Steel remembers fire; people remember drama. Guess which one I stockpile."},
	{"unlock_level": 0, "text": "You dragged survivors out of hell and still found time to knock dents flat. That's the kind of stubborn I respect — also the kind that needs better gloves."},
	{"unlock_level": 0, "text": "Magic is fine for scholars, but give me a well-balanced axe and a whetstone any day. Iron doesn't run out of mana — or try to negotiate."},

	# --- About Haldor (self-reveal; unlock 0 so they surface throughout the campaign) ---
	{"unlock_level": 0, "text": "I was the runt of twelve apprentices — smallest, loudest mouth. Learned to swing true before I learned to duck. Explains the nose."},
	{"unlock_level": 0, "text": "My ma could read a forge by color alone. She'd slap my ear if she saw me guess a temper today. I don't guess anymore — I still flinch when the metal lies."},
	{"unlock_level": 0, "text": "First blade I sold under my own mark warped like wet firewood. I nailed the twisted thing above my bunk. Humility is easier to swallow when it’s staring at you."},
	{"unlock_level": 0, "text": "I hum when I work. Can't carry a tune in a bucket — the anvil carries it for me. Don't tell bards; they'll charge admission."},
	{"unlock_level": 0, "text": "Crown adjusted my cousin's commission over a technicality. The lords called us 'honored artisans'. I honored my legs straight out the front gate."},
	{"unlock_level": 0, "text": "These hands? Nerves half-cooked from a crucible splash at nineteen. Still steady. The gods were stingy with mercy and generous with scar tissue."},
	{"unlock_level": 0, "text": "I name my tongs. Not telling you which one's the grump — you'll favor it and hurt the other's feelings."},
	{"unlock_level": 0, "text": "Superstition: I won't strike cold iron before I've eaten. Hungry hammer, sloppy line. Breakfast is tactical."},
	{"unlock_level": 0, "text": "Slept in a hayloft half my twenties. Dreamed of a roof that didn't itch. Now I've got one and I complain about the drip. Growth."},
	{"unlock_level": 0, "text": "There was someone. Brief. She liked quiet; I brought sparks home in my beard. Some love stories end in sensible geography."},
	{"unlock_level": 0, "text": "I can't read your human poetry. I read grain in steel like some folk read stars — same arrogance, fewer constellations."},
	{"unlock_level": 0, "text": "Once shared a cask with a paladin who swore his god loved honest labor. He paid the tab; I fixed his pommel. We're both pretending we won that night."},
	{"unlock_level": 0, "text": "Beard beads aren't fashion — they're counterweights. Pulls the braid off the collar so slag doesn't weld me into my own shirt."},
	{"unlock_level": 0, "text": "I talk tough because if I gave my worries oxygen, they'd burn the tent down. Anvil's a better confessor than any altar anyway."},
	{"unlock_level": 0, "text": "Youngest thing I fear isn't death — it's being useless. That's why I keep moving. Idle tongs rust in the head first."},
	{"unlock_level": 0, "text": "If I ever go home, it'll be with proof in my pack — work that outlasted kings. Petty? Maybe. Dwarf."},

	# --- Map 2+ Emberwood ---
	{"unlock_level": 1, "text": "Emberwood taught you retreat isn't cowardice — it's staying alive long enough to swing again. Trees don't judge you; I do, but only professionally."},
	{"unlock_level": 1, "text": "Burning ground behind you, mud underfoot — if your boots survived that, they're marriage material. Bring 'em here before you propose."},

	# --- Map 3+ Shattered Sanctum / Haldor intro beat ---
	{"unlock_level": 2, "text": "You survived the lower valleys, eh? Good. The enemies ahead wear thicker armor. We'll need to strike hotter — and complain louder, if it helps."},
	{"unlock_level": 2, "text": "I saw the dents in your shields from the last skirmish. Sloppy footwork! Let the shield take the glance, not the brunt — it's not a drum solo."},
	{"unlock_level": 2, "text": "Temple scavengers run like rats with ingots in their teeth. I don't chase rats — I outlast 'em and charge interest."},
	{"unlock_level": 2, "text": "Sanctum stone lies. Looks holy, chips like bad excuses. My hammer doesn't do theology; it does geometry."},
	{"unlock_level": 2, "text": "That sanctum held more prayers than answers. Good. An anvil prefers sweat to sermons — and I prefer coal to committee meetings."},

	# --- Map 4+ Merchant's Maze ---
	{"unlock_level": 3, "text": "Vharian coin shines bright and spends dirty. Wipe your hands after you count it — rust starts in the palm, greed starts in the grin."},
	{"unlock_level": 3, "text": "Alley-forge smoke and market perfume don't mix. I keep my bellows honest so your steel doesn't taste like a bribe with a ribbon on it."},
	{"unlock_level": 3, "text": "You left sanctum echoes behind you. Echoes don't hold an edge; hammers do. Guess which one I charge for."},

	# --- Map 5+ League docks ---
	{"unlock_level": 4, "text": "You see this singe on my left braid? Dragon fire. From a drake in the southern peaks. Didn't get the kill, but I kept the scales — and the bragging rights."},
	{"unlock_level": 4, "text": "The ores you're bringing back carry a strange chill. Dark magic is stirring, Commander — and my tea's gone cold. Both need fixing."},
	{"unlock_level": 4, "text": "Dock bells mean hurry. My forge means measure. Tell your saboteurs to synchronize their panic with my coffee break."},
	{"unlock_level": 4, "text": "Salt eats steel while you sleep. Oil what you love, Boss, or I'll file pits until my jokes rust."},

	# --- Map 6+ Greyspire siege ---
	{"unlock_level": 5, "text": "Greyspire's old bones groan when you breathe on 'em. Respect the keep — it's been breaking tourists since before your bloodline learned table manners."},
	{"unlock_level": 5, "text": "Necromancy leaves a taste like cold iron on the tongue. Quench hot, store dry, trust nothing that hums lullabies — except me. I'm harmless. Mostly."},
	{"unlock_level": 5, "text": "Walls like these remind me of the first fort I snuck into as a boy — delivery boy, not hero. I still get a itch at gatehouses. Old shame, good compass."},

	# --- Map 7+ Hub / famine era ---
	{"unlock_level": 6, "text": "Now this is a hearth — hoist, bench, room to swing. Don't insult it with lazy maintenance or I'll insult your lineage with precision."},
	{"unlock_level": 6, "text": "An army's only as good as what it marches on. Nails, rivets, buckles — small sins sink campaigns, like pebbles in a boot, but existential."},
	{"unlock_level": 6, "text": "Crypt-cold steel needs slow tempering. Rush a quench down there and you'll snap something you care about — usually your dignity first."},
	{"unlock_level": 6, "text": "Kaelen's ghosts aren't my business — the metal they left behind is. We put it to work. Ghosts can file a complaint with the anvil."},

	{"unlock_level": 7, "text": "I've forged blades for heroes who never came home, and for villains who deserved to fall. Now, I just forge for you. Make it count — my reputation's tired of funerals."},
	{"unlock_level": 7, "text": "I don't mind the noise. Means the army isn't dead yet. Remind me to hammer loud enough to drown out the enemy's drummer."},
	{"unlock_level": 7, "text": "Empty bellies make desperate hands. Keep your guards' edges true — mercy cuts cleaner when the steel isn't embarrassed to be seen in public."},
	{"unlock_level": 7, "text": "Grain and steel both travel in wagons. Guard the wheels, or you'll lose dinner and war to vultures wearing very serious hats."},

	# --- Map 8+ Sacred forest ---
	{"unlock_level": 8, "text": "Spirits in the roots, steel in the hand — I don't need them to agree. I need your grip steady when the forest gets philosophical."},
	{"unlock_level": 8, "text": "Totem-touched ore rings if you listen. I still file straight. Tradition can hum; discipline does the cutting — like a critic with a hammer."},

	# --- Map 9+ Passes / diplomacy ---
	{"unlock_level": 9, "text": "Envoys talk; avalanches don't. I'll put a spike through anything that tries to bury your parley — diplomacy, dwarven style."},
	{"unlock_level": 9, "text": "Valeron's sun paints everything righteous until you squint at the shadows. Keep your steel un-blinkered and your sarcasm loaded."},

	# --- Map 10+ Sunlit trial ---
	{"unlock_level": 10, "text": "Rings of fire make pretty theater. My forge makes law — heat, hold, strike, repeat. No intermission."},
	{"unlock_level": 10, "text": "They'll judge your soul under banners. I'll judge your tang and fuller. Souls don't tip; soldiers do, if they know what's good for their scabbards."},
	{"unlock_level": 10, "text": "Crowds used to unnerve me — too many voices waiting for a mistake. Arena's the same itch. I cope by making my joints too tight to heckle."},

	# --- Map 11+ Market of Masks ---
	{"unlock_level": 11, "text": "Masked killers mean seams you can't see. Check rivets, linings, pommels — paranoia is just maintenance with better PR."},
	{"unlock_level": 11, "text": "Carnival steel sells cheap and snaps loud. You're buying from a dwarf, not a juggler — unless you want juggling, then bring coin and a helmet."},

	# --- Map 12+ College ---
	{"unlock_level": 12, "text": "Scholars stack lies like plates. I stack ingots. One of those stacks stops a spear — the other stops dinner from sliding off."},
	{"unlock_level": 12, "text": "Ink lied to kings longer than swords did. I can't read your codex, but I can read a hairline fracture. Bring me both; I'll pretend to care about the footnotes."},

	# --- Map 13+ Black Coast assault ---
	{"unlock_level": 13, "text": "Amphibious assault: sand in the rivets, dignity in the drink. Rinse before you drip on my floor — I'm not running a seaside spa."},
	{"unlock_level": 13, "text": "Cannons speak fluent 'ruin your day.' I speak fluent 'straighten the aftermath.' We make a fine choir."},

	# --- Map 14+ Dawnkeep betrayal ---
	{"unlock_level": 14, "text": "Safehold, they said. Three fronts, they forgot to mention. Good thing steel doesn't believe in safe words."},
	{"unlock_level": 14, "text": "Betrayal's just rust between people. File it off, oil what's left, march before it spreads to the hinges."},

	# --- Map 15+ Weeping Marsh ---
	{"unlock_level": 15, "text": "Weeping Marsh weeps on everything — boots, temper, lunch. I can't fix the marsh, but I can fix your buckles while you complain."},
	{"unlock_level": 15, "text": "Poison spreads like gossip at a wedding. At least poison doesn't ask about your love life."},
	{"unlock_level": 15, "text": "Wet weeks on the road once ruined a whole batch of springs — damp coal, sulking steel. I still blame that bog personally. Grudges keep me warm."},

	# --- Map 16+ Order ruins / trials ---
	{"unlock_level": 16, "text": "Spectral trials, mirrored rooms — cute. Try mirror-polishing a blade at midnight without swearing. That's a real test."},
	{"unlock_level": 16, "text": "The Order's legacy is heavy. So's my hammer. Difference is, mine comes with a handle and a warranty."},

	# --- Map 17+ Coalition camp ---
	{"unlock_level": 17, "text": "Three faction tents, one coal pile, infinite speeches. I'm not forging consensus — I'm forging cleavers. Priorities."},
	{"unlock_level": 17, "text": "Negotiation under arrow fire is inefficient. So is dull plate. We're fixing both; I'm only licensed for one, but I improvise."},

	# --- Map 18+ Dark Tide ritual ---
	{"unlock_level": 18, "text": "Sky's wrong, sea's rude, tower's having a moment. My anvil stays flat — if the world ends, it'll do it on a level surface."},
	{"unlock_level": 18, "text": "Ritualists love a dramatic pause. Hammers don't pause; they punctuate."},

	# --- Map 19+ True Catalyst / breach ---
	{"unlock_level": 19, "text": "Void's knocking, reality's arguing, everyone's taking a dramatic pause. Steel still obeys heat and shame — two things I have plenty of."},
	{"unlock_level": 19, "text": "If the world's splitting like bad weld, we file the seam and brace it. Panic is optional; torque wrenches aren't."},

	# --- Map 20+ Epilogue beats ---
	{"unlock_level": 20, "text": "Epilogue's a fancy word for 'still breathing, still swinging.' I'm game. The forge doesn't do credits — only sequels."},
	{"unlock_level": 20, "text": "War winds down; tongs don't. Someone's gotta straighten tomorrow — might as well be the short fellow with the good hammer."},
	{"unlock_level": 20, "text": "If we live through this mess, I'm building a stool with no wobble. Throne optional. I've earned a seat that doesn't negotiate."},
	{"unlock_level": 20, "text": "You kept your people marching — I noticed. I don't do speeches; I do rivets. Consider every sound weld a thank-you I couldn't say sober."},

	# --- Craft philosophy, camp life, gags, bonds (mixed unlock tiers) ---
	{"unlock_level": 0, "text": "Magnus back home still writes that his rivets are tighter than mine. He's wrong, but the postage keeps the postal gnome employed."},
	{"unlock_level": 0, "text": "I don't do 'mystery metal.' If you won't tell me what melted your cousin, I won't pretend the tongs are feeling charitable."},
	{"unlock_level": 0, "text": "Camp stew has personality. Mostly 'betrayal.' I bring my own salt — for the stew and for commentary."},
	{"unlock_level": 0, "text": "Your quartermaster tried to invoice me for 'forge emissions.' I emitted a lecture. Invoice withdrawn."},
	{"unlock_level": 1, "text": "Kaelen oiled his sword like a man confessing. I respect that. Oil is honesty you can measure."},
	{"unlock_level": 1, "text": "If the healer asks why I'm limping, tell her it's pride, not the anvil. The anvil has an alibi."},
	{"unlock_level": 2, "text": "That sanctum midden taught me a valuable lesson: never kneel in unidentified slag. Faith heals; dermatology negotiates."},
	{"unlock_level": 2, "text": "Liora's shield work is tidy. I like tidy. Chaos is for battle maps, not for rivet spacing."},
	{"unlock_level": 3, "text": "Merchant tried to sell me 'lucky tongs.' I showed him real luck: walking away without buying."},
	{"unlock_level": 3, "text": "City kids threw rocks at my sign. I sharpened the cheapest knife free for the ringleader's mother. Politics."},
	{"unlock_level": 4, "text": "Dock workers bet on arm-wrestling. I arm-wrestled a crate. Crate conceded. Dignity intact."},
	{"unlock_level": 4, "text": "Salt rusts secrets out of steel. Humans should try it on their ledgers sometime."},
	{"unlock_level": 5, "text": "Greyspire stone remembers footfalls. So do my knees. We're having a contest; the stone's winning on points."},
	{"unlock_level": 5, "text": "Necromancy and forging both raise the dead — one with rot, one with heat. I prefer my customers vertical and opinionated."},
	{"unlock_level": 6, "text": "Finally hung my lucky horseshoe. Not for luck — for hanging wet gloves. Superstition is just engineering with feelings."},
	{"unlock_level": 6, "text": "The quartermaster and I have an understanding: I don't critique his counts, he doesn't critique my hammer grammar."},
	{"unlock_level": 7, "text": "Famine week I forged a spoon too proud to stir thin gruel. Ego — the other appetite."},
	{"unlock_level": 7, "text": "Shared my last wedge of cheese with a sentry who didn't ask. That's not kindness; that's investment in not being stabbed by boredom."},
	{"unlock_level": 8, "text": "Grove spirits whisper. I whisper back 'schedule an appointment.' Busy dwarf."},
	{"unlock_level": 8, "text": "Totem asked for a blood price. I offered sweat. We compromised on elbow grease."},
	{"unlock_level": 9, "text": "Diplomats speak in circles. I file circles into straight lines. Occupational hazard."},
	{"unlock_level": 9, "text": "Avalanche snow in my boots melted into philosophy: cold feet, warm complaints."},
	{"unlock_level": 10, "text": "Arena crowd wanted blood. I gave them sparks from a demonstration rivet. Cheaper, cleaner, worse tips."},
	{"unlock_level": 10, "text": "Sun-temple guards admired my beard. I admired their discipline. Mutual professional jealousy."},
	{"unlock_level": 11, "text": "Masked assassin dropped a knife in my slag bucket. I returned it point-first through the fence. Customer service."},
	{"unlock_level": 11, "text": "Festival fireworks scared my cat — I don't have a cat; that's how convincing the bang was."},
	{"unlock_level": 12, "text": "Scholar offered to catalog my tools. I catalogued his smugness into a smaller box. Fair trade."},
	{"unlock_level": 12, "text": "Library dust made me sneeze through three welds. Academia is an allergen."},
	{"unlock_level": 13, "text": "Seawater and flux don't mix. Neither do sailors and my coffee schedule. We endured each other."},
	{"unlock_level": 13, "text": "Cannon recoil loosened a wagon wheel. I tightened it; the cannon sent a thank-you note via smoke signal. Rude."},
	{"unlock_level": 14, "text": "Trust is like temper — lose the heat too fast and it cracks. I'm slow-cooling on people lately."},
	{"unlock_level": 14, "text": "Someone 'borrowed' my chalk for tactical maps. I borrowed their patience. They're still waiting interest."},
	{"unlock_level": 15, "text": "Marsh gas and bellows smoke had a turf war in my lungs. I declared neutrality and tea."},
	{"unlock_level": 15, "text": "Leech bit me. I bit back rhetorically. Leech had thicker skin. Respect."},
	{"unlock_level": 16, "text": "Order ghosts wanted a speech. I gave them a maintenance checklist. Haunting declined."},
	{"unlock_level": 16, "text": "Trial chamber asked for virtue. I offered punctuality. Jury still out — literally, spectral jury, very slow."},
	{"unlock_level": 17, "text": "Three faction dinners same night. I ate bread thrice and lies once. Bread won."},
	{"unlock_level": 17, "text": "Coalition maps on my bench — someone drew hearts on Valeron's supply lines. Not me. Probably not me."},
	{"unlock_level": 18, "text": "Ritual lightning charged my hair. New look. Terrible conductivity for hats."},
	{"unlock_level": 18, "text": "Dark tide stained my apron philosophical. Washing failed; philosophy stuck."},
	{"unlock_level": 19, "text": "Void headache feels like someone filed inside my skull. I sympathize — filing is intimate."},
	{"unlock_level": 19, "text": "Truth spilled everywhere; I mopped with facts and a rag of denial. Floor's cleaner. Head isn't."},
	{"unlock_level": 20, "text": "If peace comes, I'll miss the excuses for overtime. Don't tell the union I said that."},
	{"unlock_level": 20, "text": "Thinking of opening a side shop: 'Haldor's Slightly Less Apocalyptic Repairs.' Trademark pending."},
	{"unlock_level": 0, "text": "Impostor syndrome hits when you praise my work too loud. I fix it by hitting metal louder. Therapy by percussion."},
	{"unlock_level": 3, "text": "I talk to steel when nobody's watching. It never gossips. Ideal friend."},
	{"unlock_level": 6, "text": "Homesick for a tunnel I swore I'd never miss. Nostalgia is a blunt file — wears you down slow."},
	{"unlock_level": 10, "text": "Praise from you lands heavier than a hammer. I pretend it doesn't — the steel sees through me."},
	{"unlock_level": 0, "text": "Salvage ethics: I won't melt a named blade without a moment of silence. Three seconds. Then business."},
	{"unlock_level": 5, "text": "Young smiths want signature twists on guards. Old smiths want sleep. Guess my aesthetic."},
	{"unlock_level": 8, "text": "Ranger tried to teach me 'forest quiet.' I taught the forest anvil decibels. Truce called."},
	{"unlock_level": 12, "text": "Codex said steel fears nothing. I annotated the margin: 'steel fears bad quench.' Scholars hate margins."},
	{"unlock_level": 15, "text": "Cried once after a failed masterwork. Once. The steel didn't tell anyone. Good lad."},
	{"unlock_level": 18, "text": "Started sketching a retirement anvil on scrap. Embarrassing. Also heavier than scrap allows."},

	# --- Solo-scene tap hints (underline in forge UI; see [method apply_haldor_solo_tap_hint]) ---
	{"unlock_level": 3, "text": "If the camp gets loud, remember the kettle still boils without an audience. That's not wisdom — it's schedule. I find it calming.", "solo_hint": {"needle": "kettle still boils", "scene_id": "haldor_solo_smoke_and_schedules", "variety_unseen": true}},
	{"unlock_level": 4, "text": "Weight isn't always iron. Sometimes it's the pause before you answer a messenger. I watch for that pause — say tired if it's tired.", "solo_hint": {"needle": "say tired", "scene_id": "haldor_solo_midway_weight"}},
	{"unlock_level": 5, "text": "Your grip tells the truth before your mouth does. If the next strike isn't necessary, don't sell it to yourself as heroism.", "solo_hint": {"needle": "isn't necessary", "scene_id": "haldor_solo_the_edge_you_hold"}},
	{"unlock_level": 6, "text": "Bad dreams aren't a report card. They're weather. If thunder follows you inside, you don't have to audition the fear for me.", "solo_hint": {"needle": "Bad dreams", "scene_id": "haldor_solo_bad_dreams"}},
	{"unlock_level": 7, "text": "League math is simple: everything is a price until someone says no. I keep my no well-oiled.", "solo_hint": {"needle": "League math", "scene_id": "haldor_solo_league_maths"}},
	{"unlock_level": 9, "text": "Boring advice saves more lives than clever speeches. I'll be boring on purpose if it keeps your ribs in one column.", "solo_hint": {"needle": "Boring advice", "scene_id": "haldor_solo_late_trust"}},
	{"unlock_level": 11, "text": "Eat before you moralize. Empty commanders make loud mistakes — I've filed the burrs off both kinds.", "solo_hint": {"needle": "Eat before", "scene_id": "haldor_solo_commanders_eat_last"}},
	{"unlock_level": 13, "text": "This braid's half superstition, half stubbornness. If you need proof I'm not a myth, pull gently — it complains.", "solo_hint": {"needle": "half superstition", "scene_id": "haldor_solo_braid_and_burn"}},
	{"unlock_level": 15, "text": "Maps lie politely. Mud tells the truth with its teeth. Trust the teeth.", "solo_hint": {"needle": "Maps lie", "scene_id": "haldor_solo_when_the_maps_lie"}},
	{"unlock_level": 17, "text": "If we ever get real rest, I'm going to panic first, nap second. You're allowed the same order.", "solo_hint": {"needle": "real rest", "scene_id": "haldor_solo_before_the_rest"}},
	{"unlock_level": 19, "text": "Morning after a storm still counts as morning. Drink something warm before you argue with me.", "solo_hint": {"needle": "Morning after", "scene_id": "haldor_solo_morning_after"}},
	{"unlock_level": 21, "text": "The quench doesn't care about your reputation — only whether you survived the water. Surviving is the whole craft.", "solo_hint": {"needle": "survived the water", "scene_id": "haldor_solo_quench_truth"}},
	{"unlock_level": 23, "text": "Rust is honest rot: it shows up in public. I wish more problems had that integrity.", "solo_hint": {"needle": "honest rot", "scene_id": "haldor_solo_rust_lesson"}},
	{"unlock_level": 25, "text": "Give your orders a rhythm, not just volume. Panic has percussion too — it's the bad kind.", "solo_hint": {"needle": "rhythm, not just volume", "scene_id": "haldor_solo_hammer_rhyme"}},
	{"unlock_level": 27, "text": "Spectacle sparkles; duty sweeps. I prefer the broom side of life — fewer burns.", "solo_hint": {"needle": "Spectacle sparkles", "scene_id": "haldor_solo_spark_oath"}},
	{"unlock_level": 29, "text": "Charcoal remembers the tree without mourning it. Useful kind of memory.", "solo_hint": {"needle": "Charcoal remembers", "scene_id": "haldor_solo_charcoal_story"}},
	{"unlock_level": 31, "text": "Whetstone patience is rude because it works. The edge comes back whether you're dignified or not.", "solo_hint": {"needle": "Whetstone patience", "scene_id": "haldor_solo_whetstone_hours"}},
	{"unlock_level": 33, "text": "Bellows teach you to exhale on purpose. Try it before your next speech — humans hate the trick because it helps.", "solo_hint": {"needle": "Bellows teach", "scene_id": "haldor_solo_bellows_wind"}},
	{"unlock_level": 35, "text": "Cinder math: if it burns away easy, it wasn't holding anything up. Pack lighter.", "solo_hint": {"needle": "Cinder math", "scene_id": "haldor_solo_cinder_math"}},
	{"unlock_level": 37, "text": "Temper is structure, not mood — for steel and for commanders. Mix those up and people get hurt.", "solo_hint": {"needle": "Temper is structure", "scene_id": "haldor_solo_temper_promise"}},
	{"unlock_level": 39, "text": "Closing the forge is how I admit the day ended. You should try admitting it sometime — sleep follows honesty.", "solo_hint": {"needle": "Closing the forge", "scene_id": "haldor_solo_forge_closing"}},

	# --- Runesmithing (gated) ---
	{"unlock_level": 6, "requires_runesmithing": true, "text": "Runes aren't jewelry — they're tattoos for steel with worse commitment issues. Follow the recipe or argue with the socket."},
	{"unlock_level": 6, "requires_runesmithing": true, "text": "Glyphs drink resin and wax like I drink bad coffee: aggressively, and with consequences."},
	{"unlock_level": 8, "requires_runesmithing": true, "text": "Spirit-sigils and etched runes bicker if you're sloppy. Pick a lead singer, Commander — this band only fits one diva."},
	{"unlock_level": 11, "requires_advanced_runesmithing": true, "text": "Ward and Flux aren't 'try it and see.' They're 'earn it or explain yourself to your blade.'"},
	{"unlock_level": 11, "requires_advanced_runesmithing": true, "text": "Advanced runes bite like a loan-shark with a theology degree — respect the paperwork, or pay the repair bill."}
]


## Interstitial beats: queued when a story map clears ([method CampaignManager.queue_haldor_beats_for_cleared_map]). [br] [br] Keys = beat id; value = { text, once }.
const HALDOR_BEAT_ENTRIES: Dictionary = {
	"haldor_clear_0": {"text": "Between your last fight and this bench, I picked ash out of my beard for an hour. Oakhaven's still riding the wind — or my face.", "once": true, "solo_hint": {"needle": "Oakhaven's", "scene_id": "haldor_solo_first_quiet"}},
	"haldor_clear_1": {"text": "Slept wrong on the wagon plank. Neck's doing politics without my consent. Don't stare; it's sensitive legislation.", "once": true},
	"haldor_clear_2a": {"text": "Caught a rat making off with my lunch cheese in the sanctum rubble. Negotiations failed. Rat's ego, however, is intact.", "once": true},
	"haldor_clear_2b": {"text": "Stubbed every toe on 'holy' debris. If holiness is sharp, I've been baptized twice per foot.", "once": true},
	"haldor_clear_3": {"text": "League clerk tried to tax my tongs as 'mobile assets.' I mobilized them toward his exit. Paperwork miraculously simplified.", "once": true, "solo_hint": {"needle": "League clerk", "scene_id": "haldor_solo_league_maths"}},
	"haldor_clear_4": {"text": "Seagull stole my rag. I hope it builds a nest worthy of petty revenge. I'm not over it.", "once": true},
	"haldor_clear_5": {"text": "Greyspire dust crawled into places armor doesn't cover. If you hear me squeak, it's dignity, not hinges.", "once": true},
	"haldor_clear_6": {"text": "First night with a real roof — I woke up suspicious of silence. Good suspicious. Like steel before the quench.", "once": true},
	"haldor_clear_7": {"text": "Shared a thin stew with the line. Nobody thanked the pot; they thanked the ladle. I'll take it.", "once": true, "solo_hint": {"needle": "the ladle", "scene_id": "haldor_solo_commanders_eat_last"}},
	"haldor_clear_8": {"text": "Forest pollen declared war on my sinuses. I surrendered with tea. Honor intact.", "once": true},
	"haldor_clear_9": {"text": "Packed the wrong socks for the pass. Cold toes, hot opinions. You benefit from neither.", "once": true},
	"haldor_clear_10": {"text": "Arena crowd asked for my autograph on a horseshoe. I signed 'Haldor — not a performer.' They cheered anyway. Humans.", "once": true, "solo_hint": {"needle": "Arena crowd", "scene_id": "haldor_solo_midway_weight"}},
	"haldor_clear_11": {"text": "Festival mask glue bonded to my eyebrow. Removal required diplomacy, oil, and one suppressed scream.", "once": true},
	"haldor_clear_12": {"text": "College fined me for 'unauthorized sparking.' I paid in sarcasm and three rivets. We're even.", "once": true},
	"haldor_clear_13": {"text": "Sand in every crevice — including my sense of humor. It's coarse now. You're welcome.", "once": true},
	"haldor_clear_14": {"text": "Someone moved my favorite stool. Trust is a three-legged thing; so was that stool. Coincidence? I doubt.", "once": true},
	"haldor_clear_15": {"text": "Marsh leech wrote a manifesto on my calf. I evicted it. Democracy lost.", "once": true, "solo_hint": {"needle": "Marsh leech", "scene_id": "haldor_solo_when_the_maps_lie"}},
	"haldor_clear_16": {"text": "Spectral judge called my hammer 'unrefined.' I called his verdict 'drafty.' We're not dating.", "once": true},
	"haldor_clear_17": {"text": "Three faction dinners, one stomach. I invented a fourth meal: regret.", "once": true},
	"haldor_clear_18": {"text": "Ritual tide soaked my spare apron. It now drips drama. I wear it on laundry day only.", "once": true},
	"haldor_clear_19": {"text": "After that last sky nonsense, I hear ringing when it's quiet. Either the Veil or tinnitus. Both need oiling.", "once": true, "solo_hint": {"needle": "the Veil", "scene_id": "haldor_solo_before_the_rest"}},
	"haldor_clear_20": {"text": "Epilogue week's been weird — fixed a hoe, a gate hinge, and someone's feelings with a well-placed rivet. Peacetime is work.", "once": true},
	"haldor_gen_a": {"text": "Travel day: axle squealed, I threatened it with file and folklore. It chose silence. Wise axle.", "once": false},
	"haldor_gen_b": {"text": "Between camps I taught a recruit to deburr wire. He cut himself once, learned twice. Tuition paid in blood — standard.", "once": false},
	"haldor_gen_c": {"text": "Night watch borrowed my light. Returned it oily. I respect the honesty of stains.", "once": false},
}


## Beat IDs to queue per cleared story map index (0 = first map cleared). Extra entries fall back to generics.
var haldor_beat_ids_per_cleared_map: Array = [
	["haldor_clear_0"],
	["haldor_clear_1"],
	["haldor_clear_2a", "haldor_clear_2b"],
	["haldor_clear_3"],
	["haldor_clear_4"],
	["haldor_clear_5"],
	["haldor_clear_6"],
	["haldor_clear_7"],
	["haldor_clear_8"],
	["haldor_clear_9"],
	["haldor_clear_10"],
	["haldor_clear_11"],
	["haldor_clear_12"],
	["haldor_clear_13"],
	["haldor_clear_14"],
	["haldor_clear_15"],
	["haldor_clear_16"],
	["haldor_clear_17"],
	["haldor_clear_18"],
	["haldor_clear_19"],
	["haldor_clear_20"],
]


func get_haldor_beat_entry(beat_id: String) -> Dictionary:
	var k: String = str(beat_id).strip_edges()
	if k == "" or not HALDOR_BEAT_ENTRIES.has(k):
		return {"text": "", "once": true}
	var raw: Variant = HALDOR_BEAT_ENTRIES[k]
	if raw is Dictionary:
		return (raw as Dictionary).duplicate()
	return {"text": "", "once": true}


func get_haldor_beat_ids_for_cleared_map(cleared_map_index: int) -> Array:
	var i: int = clampi(cleared_map_index, 0, 999)
	if i >= 0 and i < haldor_beat_ids_per_cleared_map.size():
		var row: Variant = haldor_beat_ids_per_cleared_map[i]
		if row is Array:
			return (row as Array).duplicate()
	var gens: PackedStringArray = PackedStringArray(["haldor_gen_a", "haldor_gen_b", "haldor_gen_c"])
	var gi: int = (i + 17) % gens.size()
	return [str(gens[gi])]


# --- Full-screen narrative beats (Haldor forge solos, roster bond scenes, world encounters) ---
# Runtime: CampaignManager.begin_narrative_beat → res://Scenes/Narrative/NarrativeBeatScene.tscn (see CampaignManager.NARRATIVE_BEAT_SCENE_PATH).
## Portraits: [code]res://Assets/Haldor/Haldor Sad.png[/code] … [code]Haldor Angry.png[/code]. Line dicts may set [code]haldor_expression[/code] to [code]sad[/code] / [code]serious[/code] / [code]smiling[/code] / [code]angry[/code] (default [code]serious[/code]).
## Background: [code]HaldorBackground.png[/code] when present.
var _haldor_solo_portraits_by_mood: Dictionary = {}
var _haldor_solo_default_expression: String = "serious"
var _haldor_solo_bg_resolved: Texture2D = null
var _haldor_solo_art_resolved: bool = false

const _HALDOR_SOLO_EXPR_PATHS: Dictionary = {
	"sad": "res://Assets/Haldor/Haldor Sad.png",
	"serious": "res://Assets/Haldor/Haldor Serious.png",
	"smiling": "res://Assets/Haldor/Haldor Smiling.png",
	"angry": "res://Assets/Haldor/Haldor Angry.png",
}


func _haldor_solo_load_first_texture(paths: PackedStringArray, fallback_path: String) -> Texture2D:
	for p in paths:
		var ps: String = str(p).strip_edges()
		if ps == "":
			continue
		if not ResourceLoader.exists(ps):
			continue
		var res: Resource = load(ps) as Resource
		if res is Texture2D:
			return res as Texture2D
	var fb: String = str(fallback_path).strip_edges()
	if fb != "" and ResourceLoader.exists(fb):
		var res2: Resource = load(fb) as Resource
		if res2 is Texture2D:
			return res2 as Texture2D
	return null


func _haldor_solo_portrait_for_expression(expr: String) -> Texture2D:
	var e: String = str(expr).to_lower().strip_edges()
	if e == "smile":
		e = "smiling"
	if _haldor_solo_portraits_by_mood.has(e):
		return _haldor_solo_portraits_by_mood[e] as Texture2D
	if _haldor_solo_portraits_by_mood.has(_haldor_solo_default_expression):
		return _haldor_solo_portraits_by_mood[_haldor_solo_default_expression] as Texture2D
	for k in _haldor_solo_portraits_by_mood.keys():
		return _haldor_solo_portraits_by_mood[k] as Texture2D
	return _haldor_solo_load_first_texture(PackedStringArray(), "res://Assets/Portraits/HaldorNormal.png")


func _ensure_haldor_solo_art_loaded() -> void:
	if _haldor_solo_art_resolved:
		return
	_haldor_solo_art_resolved = true
	_haldor_solo_portraits_by_mood.clear()
	for mood_key in _HALDOR_SOLO_EXPR_PATHS.keys():
		var path: String = str(_HALDOR_SOLO_EXPR_PATHS[mood_key]).strip_edges()
		if path == "" or not ResourceLoader.exists(path):
			continue
		var res: Resource = load(path) as Resource
		if res is Texture2D:
			_haldor_solo_portraits_by_mood[str(mood_key)] = res as Texture2D
	_haldor_solo_default_expression = "serious"
	if not _haldor_solo_portraits_by_mood.has(_haldor_solo_default_expression):
		for fallback_mood in ["serious", "smiling", "sad", "angry"]:
			if _haldor_solo_portraits_by_mood.has(fallback_mood):
				_haldor_solo_default_expression = fallback_mood
				break
	_haldor_solo_bg_resolved = _haldor_solo_load_first_texture(PackedStringArray([
		"res://Assets/Haldor/HaldorBackground.png",
		"res://Assets/Haldor/HaldorSoloBackground.png",
		"res://Assets/Haldor/HaldorSoloBackground.jpg",
		"res://Assets/Haldor/haldor_solo_background.png",
		"res://Assets/Haldor/SoloBackground.png",
	]), "res://Assets/Backgrounds/peaceful_village.jpeg")


## Each entry: [code]id[/code], optional [code]beat_family[/code] (defaults from id prefix), [code]min_max_unlocked_index[/code] (omit or set [code]0[/code] for beats not gated by map progress), optional [code]min_other_solo_scenes_seen[/code] / [code]min_other_beats_seen[/code] (same-family count), optional [code]requires_seen_beat_id[/code] (that beat id must be in [param seen_beat_ids] before this unlocks — use for roster solo tiers 2+), optional [code]portrait_style[/code] ([code]haldor_moods[/code] / [code]static[/code] / [code]auto[/code]), optional [code]default_speaker_name[/code] / [code]default_speaker_portrait[/code], optional [code]default_reward_toast[/code] for [code]rewards[/code] entries that omit [code]toast[/code], roster solos: [code]beat_family[/code] [member NARRATIVE_BEAT_FAMILY_ROSTER_SOLO] + [code]solo_unit_name[/code] (display name) + [method get_eligible_roster_solo_beat_id], [code]lines[/code]. Lines may use [code]player_choice[/code]. Filled by [method get_narrative_beat_playback_lines].
var narrative_beat_definitions: Array = [
	{
		"id": "haldor_solo_first_quiet",
		"min_max_unlocked_index": 3,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "No anvil tonight, {hero_name}. No ledger. Just whatever honesty fits in one breath."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "I make noise in the forge because the steel expects it. You've already seen me greasy and wrong, so I don't need the act here."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "You've paid today in bruises and bad choices. I'm not here to grade you. If you need to be ordinary for five minutes, sit. I've got the watch."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "If the Mark scares you, good — you're still respecting it. If it stops scaring you, come find me before you do something clever. I like your face intact.", "player_choice": {
				"options": [
					{"id": "stoic", "label": "Stay quiet — I'm handling it."},
					{"id": "honest", "label": "It scares me. Plainly."},
					{"id": "deflect", "label": "Clever's underrated."}
				],
				"reactions": {
					"stoic": [
						{"speaker": "Haldor", "haldor_expression": "serious", "text": "Fair. Don't confuse silence with strength — the fire stays hot whether you yell at it or not."},
						{"speaker": "Haldor", "haldor_expression": "smiling", "text": "I've got the watch. You don't owe me a performance."}
					],
					"honest": [
						{"speaker": "Haldor", "haldor_expression": "sad", "text": "Fear kept honest is a tool. Fear you hide turns into a habit. I've worn both."},
						{"speaker": "Haldor", "haldor_expression": "serious", "text": "Come bang on my door before you pretend you're fine. Noise or honesty, pick whichever's easier."}
					],
					"deflect": [
						{"speaker": "Haldor", "haldor_expression": "smiling", "text": "That smirk will cost you sleep someday. But I'd rather you joke than lie to yourself."},
						{"speaker": "Haldor", "haldor_expression": "serious", "text": "Clever's fine until the dirt disagrees. When it does, I want you here, not proving a punchline."}
					]
				}
			}},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "I'll keep your kit honest. You keep yourself human — the {hero_name} I signed on for, not the legend the camp writes songs about. Deal?"},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Iron_Ore.tres", "amount": 2, "toast": "Bench scrap — don't tell the quartermaster"},
		]
	},
	{
		"id": "haldor_solo_smoke_and_schedules",
		"min_max_unlocked_index": 4,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "You want plain? My kettle still boils when the map goes to hell. Yours should too."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "I used to think discipline meant rules on a wall. Now it just means 'eat before you're hollow'. Boring, but it keeps you standing."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "{hero_name}, if your hands shake, that's not cowardice. That's your body telling the truth while your mouth tries to be commander-shaped."},
			{"speaker": "Haldor", "haldor_expression": "sad", "text": "I can't unsee what we've walked through together. But I can sit here without asking you to dress it up. You don't owe me a performance."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Oil the hinge. Drink the water. Steal some sleep. Tiny maintenance is how you stay sharp — for them, and for you."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Iron_Ore.tres", "amount": 1, "toast": "Kettle-side grit — still good iron"},
		]
	},
	{
		"id": "haldor_solo_midway_weight",
		"min_max_unlocked_index": 5,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Sit if you want. Stand if you can't. Pick what works, not what's pretty."},
			{"speaker": "Haldor", "haldor_expression": "sad", "text": "Folks think I only read dents in metal. I read the silence after you give an ugly order. You don't have to translate that silence for me."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "You're carrying more than kit now, {hero_name}. I see it in how you scan the horizon before your straps."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "You don't owe me wit or grit. If you're tired, say tired. I'll still respect you. Probably more."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "The forge isn't going anywhere. Neither am I. My bench is yours when the camp is too loud."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Iron_Ore.tres", "amount": 2, "toast": "Offcuts from a quiet filing session"},
		]
	},
	{
		"id": "haldor_solo_the_edge_you_hold",
		"min_max_unlocked_index": 6,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "That {weapon_name} in your hand isn't loyal — it's obedient to leverage and grip. There's no poetry in it."},
			{"speaker": "Haldor", "haldor_expression": "angry", "text": "I've watched commanders polish their steel and skip sleep like idiots. The blade doesn't love you back, {hero_name}. It just cuts."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "If you feel cruel with a clean edge, slow down. Cruelty loves speed. Mercy takes room."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "I'll keep your gear true. You keep asking if the next strike is necessary — not just if you can land it."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "Plain as I can say it: that weapon's a question only you answer. I'm just the guy who files your nicks."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Steel_Ingot.tres", "amount": 1, "toast": "A bar I was saving for a picky edge"},
		]
	},
	{
		"id": "haldor_solo_bad_dreams",
		"min_max_unlocked_index": 7,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "If you didn't dream ugly sometimes, I'd worry you weren't paying attention — and I'd worry about me, because I still do."},
			{"speaker": "Haldor", "haldor_expression": "sad", "text": "I still wake swinging at smoke. Age doesn't delete it; it shortens the swing. You're not broken for carrying nights. You're honest."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Don't turn nightmares into a contest with the roster. Pain isn't a leaderboard — it's weather. You don't have to audition your worst night for me."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "After the bad ones, come find me if you want a witness who'll shut up and share the fire. No lesson unless you ask. I've needed that too."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "Morning still arrives — rude, reliable schedule. Drink something hot. Let the day be ordinary for an hour. I'll save you a cup if you drag your boots in late."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Iron_Ore.tres", "amount": 1, "toast": "Something solid to hold when the night lies"},
		]
	},
	{
		"id": "haldor_solo_league_maths",
		"min_max_unlocked_index": 8,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "angry", "text": "League merchants price everything. That doesn't make your people line items. It means they panic when you refuse to price your conscience."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "I've been 'useful' in three tongues. Useful pays the tent. Disposable is what they want when the math turns — and I'm not letting them do that to you quietly."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "{hero_name}, clean words and dirty hands? Trust the hands. I've shaken both kinds; only one left grease on my soul."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "I don't hate coin — I hate the story that coin is virtue. You and I both know better. We've bought ugly truth cheaper than their silk lies."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "We're still breathing without their spreadsheet. That's ours. Remember it when some clerk tries to make your roster feel small."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Silver_Ore.tres", "amount": 1, "toast": "League-adjacent silver — laundered by fire"},
		]
	},
	{
		"id": "haldor_solo_late_trust",
		"min_max_unlocked_index": 10,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "{hero_name}. If this is the wrong moment, nod once — we pretend this fire never happened. No score kept. I've needed that grace too.", "player_choice": {
				"options": [
					{"id": "stoic", "label": "Not the wrong moment. Continue."},
					{"id": "honest", "label": "It's rough — but stay."},
					{"id": "deflect", "label": "Fire's never wrong. Talk."}
				],
				"reactions": {
					"stoic": [
						{"speaker": "Haldor", "haldor_expression": "serious", "text": "Stone in your voice. Fine. We stick to facts, not syrup."}
					],
					"honest": [
						{"speaker": "Haldor", "haldor_expression": "sad", "text": "Rough counts. So does showing up anyway."},
						{"speaker": "Haldor", "haldor_expression": "serious", "text": "I'll keep it short, then. No parade — just breath between us."}
					],
					"deflect": [
						{"speaker": "Haldor", "haldor_expression": "smiling", "text": "Cheeky commander. Fine. I'll pretend you didn't just draft me into your timing joke."}
					]
				}
			}},
			{"speaker": "Haldor", "haldor_expression": "sad", "text": "I've buried people behind jokes and forge-light. Lately I'm trying to remember them without sanding the rough edges off."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "You've dragged us through politics, ghosts, and sky-nonsense. That's not luck — that's you refusing to lie down. I'm still impressed."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "I can't promise how the story ends. Any dwarf who does is selling you a shiny sword. I can promise boring, practical truth when you need it."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "When the noise stops, find me. Not for repairs — for breath. Steel warps if it never cools; so do commanders. Kettle's always on."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Iron_Ore.tres", "amount": 2, "toast": "Iron — boring, honest, yours"},
			{"item_path": "res://Resources/GeneratedItems/Mat_Arcane_Dust.tres", "amount": 1, "toast": "Dust from a pouch I shouldn't have opened"},
		]
	},
	{
		"id": "haldor_solo_commanders_eat_last",
		"min_max_unlocked_index": 12,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Some leaders eat last and mean it. Some eat last because pride likes a slogan. I know which {hero_name} I'm hoping you are — and I've seen you forget food when the day bites."},
			{"speaker": "Haldor", "haldor_expression": "angry", "text": "Skip meals to look carved from stone and you're not strong — you're stealing from tomorrow's you. I didn't haul this camp across hell to lose you to an empty bowl."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Your people watch what you do with hunger more than they hear speeches. Show them you're still flesh. It gives them permission to stay flesh too."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "Eat. Drink. Sleep if you can steal it from the clock. Staying alive is part of the job — annoying, I know. So's listening to me. Do both."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "I'll nag you like I nag a bad temper on steel — because I want you standing when this ends, and I'm selfish about my friends."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Wooden_Plank.tres", "amount": 2, "toast": "Good planks — camp table owes me a favor"},
		]
	},
	{
		"id": "haldor_solo_braid_and_burn",
		"min_max_unlocked_index": 14,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "This braid caught fire once — not dragon drama, just me being a clot near a hot stack. I kept the singe. Reminds me I'm not a statue."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Some dwarves mythologize every scar. I'm tired of myths. I'd rather be accurate — especially with someone who's earned the plain version."},
			{"speaker": "Haldor", "haldor_expression": "sad", "text": "I left halls that wanted my hammer and not my mouth. Out here with you lot, I get both — noise at the anvil, quiet when it's just us and the coals."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "{hero_name}, you don't owe me your worst nights. If you share them, I won't hammer them into a trophy for the camp to stare at."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Heat makes honest shapes. So does saying you're scared without putting on a show. I've done both badly; you're allowed to as well."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Iron_Ore.tres", "amount": 3, "toast": "Singed scraps — the braid tax"},
		]
	},
	{
		"id": "haldor_solo_when_the_maps_lie",
		"min_max_unlocked_index": 16,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Maps are prayers we draw for ourselves. Mud answers honestly — sometimes with teeth. I've watched you read both; trust your boots when paper lies."},
			{"speaker": "Haldor", "haldor_expression": "sad", "text": "I've marched on swagger and limped home on facts. Facts are uglier. They kept me breathing. I want the same bargain for you, {hero_name}."},
			{"speaker": "Haldor", "haldor_expression": "angry", "text": "If your gut and your orders disagree, tell me or tell someone you trust before some clerk's ink puts you in a ditch. Your life's worth more than their tidy line."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Doubt isn't betrayal. Betrayal is faking certainty because steady-looking sells. You don't have to sell me anything."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "Steady tonight means fix what you can and say once, out loud, what you can't — no theater. I'll nod. I'll pass the whetstone. We'll start again in daylight."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Iron_Ore.tres", "amount": 2, "toast": "Ore for when the map disagrees with your boots"},
		]
	},
	{
		"id": "haldor_solo_before_the_rest",
		"min_max_unlocked_index": 18,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "If we ever get real rest — not a breath between disasters — I'll sleep first, then panic I'm sleeping. Tell me I'm not the only one who does that."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Victory won't sound like a bell for us. It'll feel like fewer leaks in the workshop and fewer names to say before bed. Guard your heart so it doesn't crack on the quiet days."},
			{"speaker": "Haldor", "haldor_expression": "sad", "text": "{hero_name}, you've carried names I can't pronounce and faces I'll never unsee. That weight is real. Say it once where it's safe — here counts."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "I won't insult you by promising it was all worth it. I will say you can still choose kindness on purpose — and I've watched you do it when it cost."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Whatever comes next, I want you whole enough to pick who you are after — not only who the war needed during. I'll be at the forge. No judgment, just tools."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Steel_Ingot.tres", "amount": 1, "toast": "Steel for the first slow morning"},
		]
	},
	{
		"id": "haldor_solo_morning_after",
		"min_max_unlocked_index": 20,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "Morning makes liars of monuments — good. Monuments don't drink tea. You do, badly, when you're thinking. I've seen it. It's endearing."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "If you're waiting for permission to feel relief, take mine — sloppy, informal, valid. You survived the chapter. You're allowed to feel that."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "We'll still fix bent nails and bent people. That's our trade, you and me. I'm not mourning it — I'm glad I get to swing the hammer beside you."},
			{"speaker": "Haldor", "haldor_expression": "sad", "text": "{hero_name}… thank you for staying complicated. The camp needs a person, not a statue. Simple heroes fill simple graves — I'm not ready for yours."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "Plain truth: I'm glad you're here. Eat something before I get soft and insufferable — and before I start polishing your armor out of sheer affection."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Iron_Ore.tres", "amount": 2, "toast": "Last of the morning batch — take it"},
			{"item_path": "res://Resources/GeneratedItems/Mat_Elemental_Crystal.tres", "amount": 1, "toast": "A crystal that 'fell' off a rich man's desk"},
		]
	},
	{
		"id": "haldor_solo_quench_truth",
		"min_max_unlocked_index": 22,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Quenching isn't theater — it's heat leaving fast and steel picking what it becomes. I've watched you do the human version more than once."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "Bards want a clean moral: perfect quench, perfect blade. Sometimes 'good enough' keeps everyone breathing — including you. I'll take that over pretty."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "{hero_name}, if life plunges you cold, that's not the gods punishing you — it's shape. Painful. Useful. You don't have to thank it out loud."},
			{"speaker": "Haldor", "haldor_expression": "sad", "text": "I don't romanticize hurt. I care what you become after. Outcomes are dull words until they're yours — and I'm invested in yours."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "Survive the quench. I'll be here with oil, a rag, and zero poetry unless you ask — then I'll be insufferable on purpose."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Iron_Ore.tres", "amount": 2, "toast": "Quench spillover — still usable"},
		]
	},
	{
		"id": "haldor_solo_rust_lesson",
		"min_max_unlocked_index": 24,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "Rust isn't a verdict on your soul — it's chemistry being smug. Same as guilt when you let it sit: visible beats hidden."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "I've seen fancy steel flake because someone skipped oil, and ugly steel hold because someone cared. Your habits matter more than your pedigree."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "If your mistakes show like rust, good — you can wire-brush them. The rot that hides in the seam is what breaks blades… and people."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "{hero_name}, maintain what you love — your kit, your roster, yourself. Maintenance is love without the ribbon. I've been nagging you; that's mine."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "Want to read orange and blue on steel with me sometime? Less romantic than a ballad. More useful than a lecture. I'll bring the bad tea."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Iron_Ore.tres", "amount": 3, "toast": "Surface-cleaned lumps — rust never won"},
		]
	},
	{
		"id": "haldor_solo_hammer_rhyme",
		"min_max_unlocked_index": 26,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "There's a rhythm to the hammer bards steal and wreck. Not poetry — spacing. Same thing your voice does when you're scared and shouting anyway."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "Hit too fast, you sweat and bend metal wrong. Too slow, you daydream and bend nothing. I've done both wearing your name in my head like a worry stone."},
			{"speaker": "Haldor", "haldor_expression": "angry", "text": "Leading under panic without pauses isn't urgency — it's noise. Noise gets people killed. I hate noise that wears your face."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "If they only hear panic from you, they'll answer in panic. Give them a beat — breath, a plan, a stupid joke, anything steady. They'll mirror you."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "I'll keep time on the anvil. You keep time for the living. When you forget, I'll tap the rhythm on your table until you glare. Deal?"},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Steel_Ingot.tres", "amount": 1, "toast": "Rhythm bar — tapped true"},
		]
	},
	{
		"id": "haldor_solo_spark_oath",
		"min_max_unlocked_index": 28,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Sparks look faithful. They're not — they're physics throwing a fit. So's the rush of being watched when you should be thinking."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Don't swear yourself to spectacle. Swear to straps checked, food eaten, sleep stolen — the boring stuff that keeps {hero_name} in one piece."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "I've burned holes in good wool chasing 'one more strike.' Wool forgave me. My pride didn't. Learn from my sleeves."},
			{"speaker": "Haldor", "haldor_expression": "angry", "text": "{hero_name}, courage that needs a crowd isn't courage — it's theater with a body count. You owe your people better than a performance."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "If you need a witness who won't clap, sit here. Tea, silence, no scorekeeping. I've needed that seat too."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Arcane_Dust.tres", "amount": 1, "toast": "Spark-caught dust — bottled before it lied"},
		]
	},
	{
		"id": "haldor_solo_charcoal_story",
		"min_max_unlocked_index": 30,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Charcoal remembers the tree. Fire remembers hunger. My forge remembers both and doesn't say sorry — like some days you don't either."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "I used to think bigger flames meant forward. Now I think controlled heat is forward — boring word, keeps fingers attached."},
			{"speaker": "Haldor", "haldor_expression": "angry", "text": "When you're molten, don't point it at throats first — point it at the problem. People dent easier than plate, {hero_name}, and I like ours unbent."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Mercy's easier when you're not glowing red. I've said hard things from a hot mouth; regret lasts longer than the heat."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "Cool down on purpose. That's an order from someone who makes fire for a living — and who'd rather not bandage you over words we could swallow."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Wooden_Plank.tres", "amount": 3, "toast": "Fuel-grade offcuts — dry and honest"},
		]
	},
	{
		"id": "haldor_solo_whetstone_hours",
		"min_max_unlocked_index": 32,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Whetstone time is humility time — the edge doesn't care you're a commander. It only cares if you show up honest."},
			{"speaker": "Haldor", "haldor_expression": "angry", "text": "I've watched knights pay someone else to sharpen, then lose fingers to dull pride. Expensive lesson. Don't buy it."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "{hero_name}, if your head's too loud to fix tonight, at least fix your kit — one of the two has to stay true. I'll help with whichever you pick."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "Slow circles, water, patience — almost meditation until you nod off and nick your knee. I've done it. You're in good company."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "I'll loan you a stone and a stool beside mine. No speeches — just friction, time, and me shuttin' up unless you want noise."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Iron_Ore.tres", "amount": 2, "toast": "Grit from the sharpening trough"},
		]
	},
	{
		"id": "haldor_solo_bellows_wind",
		"min_max_unlocked_index": 34,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Bellows taught me breathing: pull in, commit, let go — don't hoard air like coin. You've been hoarding lately; I've heard it in how you talk."},
			{"speaker": "Haldor", "haldor_expression": "sad", "text": "Worry sits in the chest like a bad weld — looks fine until it pops. You don't have to show me the crack for it to be real."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "If you hold your breath through every order, you'll go grey at the wrong moment. Your people need the sound of your voice, not the color of your lips."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "Exhale before you speak. Stupid trick. Works. Humans hate that. Try it anyway — I'll time you like a joke and still be proud."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "I'll pump the shop bellows. You practice the little one behind your ribs. We'll call it teamwork and deny we said anything soft."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Silver_Ore.tres", "amount": 1, "toast": "Silver that rode in on a hot wind"},
		]
	},
	{
		"id": "haldor_solo_cinder_math",
		"min_max_unlocked_index": 36,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Cinder math: what burns away wasn't holding the roof. Same for the junk we carry between fights — some of it's just ash pretending to be structure."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "Campaigns collect dead weight — grudges, lucky junk, 'might need' steel. Shed a little on purpose. I'll pretend I didn't see you do it."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "I'm not asking you to forgive monsters. I'm asking you to pack lighter than your guilt demands — you still have to march tomorrow."},
			{"speaker": "Haldor", "haldor_expression": "sad", "text": "{hero_name}, if something still hurts, name it once where it's safe. Then choose: bedroll, shovel, or my bench while I say nothing useful and mean it."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "I'll sweep the floor. You gut your pack. We meet at 'less rattling, more room' — best song the forge ever wrote."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Iron_Ore.tres", "amount": 2, "toast": "Cinder-sifted ore — cleaner than it sounds"},
			{"item_path": "res://Resources/GeneratedItems/Mat_Arcane_Dust.tres", "amount": 1, "toast": "Ash-fine dust — don't sneeze near the forge"},
		]
	},
	{
		"id": "haldor_solo_temper_promise",
		"min_max_unlocked_index": 38,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Temper on steel is structure. Temper in the mouth is mood. Same word — mix them up and someone bleeds. I've learned that the loud way."},
			{"speaker": "Haldor", "haldor_expression": "angry", "text": "A commander who runs hot makes brave folk act small — fear pretends to be survival. I've watched it; I won't pretend it's fine when it's you."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "I shout at metal; metal doesn't carry it home. People do. I'm careful where I aim noise — especially at you."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "When you lose your heat, fix it like a chipped edge: file the burr, oil the hinge, apologize where it lands. I've had to. It still counts if it's awkward."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Plain promise: I'll tug your sleeve kindly when you need it. You do the same for me. We're both loud; we should be each other's softer interrupt."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Steel_Ingot.tres", "amount": 2, "toast": "Double-tempered stock — stubborn in a good way"},
		]
	},
	{
		"id": "haldor_solo_forge_closing",
		"min_max_unlocked_index": 40,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Closing my forge is ritual: bank the fire, cover ash, listen for the last tick of cooling steel. I do the same with days — including yours, when you'll let me."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "Ending a day isn't failing it. Even wins need a lid or they spill into tomorrow's stupid mistake. I've boiled over; you don't have to."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "{hero_name}, if today was ugly, close it anyway — boots off, face washed, one honest breath. I'll pretend not to notice if you steal extra bread."},
			{"speaker": "Haldor", "haldor_expression": "sad", "text": "Tomorrow might be kinder or crueler. Tonight can still be enough — and enough isn't cowardice. It's how bodies survive each other."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "I'm banking my fire. Need me after, knock — I'll grumble and open. Don't need me? Sleep. Both count as obeying me. Pick one."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Mythril_Ingot.tres", "amount": 1, "toast": "A sliver of mythril — don't spend it on spite"},
		]
	},
	{
		"id": "haldor_solo_coda",
		"min_max_unlocked_index": 24,
		"min_other_solo_scenes_seen": 8,
		"lines": [
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "You've sat through enough of these fires that I can say this without flinching: you're not the same {hero_name} who first leaned on my bench. I'm glad."},
			{"speaker": "Haldor", "haldor_expression": "smiling", "text": "If this mess ends with us both boring and fed, I'll call that a masterpiece. No statues. Just decent bread and sleep."},
			{"speaker": "Haldor", "haldor_expression": "sad", "text": "Whatever tally the world keeps, mine's simpler. You showed up, kept showing up, and let me show up for you. That's the only ledger that counts."},
			{"speaker": "Haldor", "haldor_expression": "serious", "text": "So here's the finish: I'm still at the forge when you need weight off your shoulders. Steel or otherwise. No bards required."},
		],
		"rewards": [
			{"item_path": "res://Resources/GeneratedItems/Mat_Mythril_Ingot.tres", "amount": 1, "toast": "Coda stock — mythril, no speech tax"},
		]
	},
	# --- Roster solo beats (personality bible order; Camp Explore → Talk on that unit) ---
	{
		"id": "roster_solo_kaelen_sharpening_watch",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Kaelen",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 0,
		"portrait_style": "static",
		"default_speaker_name": "Kaelen",
		"default_speaker_portrait": "res://Assets/Portraits/kaelen_side.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Kaelen", "text": "Don't sneak up on a man filing steel, {hero_name}. I won't cut you — but my temper might."},
			{"speaker": "Kaelen", "text": "Sit if you want. I'm not performing wisdom. I'm keeping an edge honest so it doesn't lie to you in a fight."},
			{"speaker": "Kaelen", "text": "You've been staring at maps like they're going to apologize. They won't. People might, if you give them room — but maps just sit there smug."},
			{"speaker": "Kaelen", "text": "If you came for comfort, wrong tent. If you came for someone who'll tell you when you're about to do something stupid — stay.", "player_choice": {
				"options": [
					{"id": "stoic", "label": "I don't need a lecture."},
					{"id": "honest", "label": "I might be tired."},
					{"id": "trust", "label": "Say what you're holding back."}
				],
				"reactions": {
					"stoic": [
						{"speaker": "Kaelen", "text": "Fine. Then take this instead of a lecture: eat, sleep, check your straps. Boring keeps you breathing."},
						{"speaker": "Kaelen", "text": "Pride's useful until it makes you deaf. When it does, I'll nag. You'll survive the noise."}
					],
					"honest": [
						{"speaker": "Kaelen", "text": "Tired isn't shame. It's weather. You still march through weather — you just stop pretending it's sunshine."},
						{"speaker": "Kaelen", "text": "Rest isn't betrayal of the dead. It's how you keep the living from joining them."}
					],
					"trust": [
						{"speaker": "Kaelen", "text": "What I'm holding back is how much I hate watching someone decent learn command the way I did — by bleeding for it."},
						{"speaker": "Kaelen", "text": "So yeah, I'm harsh. I'd rather be harsh and have you upright than gentle and explain you at a pyre."}
					]
				}
			}},
			{"speaker": "Kaelen", "text": "I'm still here when the jokes run out, {hero_name}. That's the whole promise. Don't make me chase you to say it twice."},
		],
	},
	{
		"id": "roster_solo_kaelen_quiet_blade",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Kaelen",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_kaelen_sharpening_watch",
		"portrait_style": "static",
		"default_speaker_name": "Kaelen",
		"default_speaker_portrait": "res://Assets/Portraits/kaelen_side.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Kaelen", "text": "Back again, {hero_name}? Good. Means you didn't treat last time like a story you tell once and shelve."},
			{"speaker": "Kaelen", "text": "I sharpen when I'm angry. I oil when I'm scared. Both look like work — only one lies to the steel."},
			{"speaker": "Kaelen", "text": "Secrecy's a habit I wore like armor. I'm trying not to hand you the same weight by 'protecting' you from truth you already lived."},
			{"speaker": "Kaelen", "text": "If I go quiet, it's not a test. It's me deciding words won't turn into another order you didn't ask for."},
			{"speaker": "Kaelen", "text": "You're allowed to be young at this job. I'm not — and that's fine. I'll eat the years if it keeps your throat clear for the hard sentences."},
			{"speaker": "Kaelen", "text": "Next time you hear me bark, look at my hands. If they're busy fixing something, I'm not mad at you — I'm mad at a world that keeps breaking you."},
		],
	},
	{
		"id": "roster_solo_kaelen_bench_after_midnight",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Kaelen",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_kaelen_quiet_blade",
		"portrait_style": "static",
		"default_speaker_name": "Kaelen",
		"default_speaker_portrait": "res://Assets/Portraits/kaelen_side.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Kaelen", "text": "Third visit. Alright, {hero_name} — either you're stubborn or you're learning that command doesn't cure loneliness. Both are survivable."},
			{"speaker": "Kaelen", "text": "I've buried people I taught to stand. The guilt doesn't shrink; you just stop using it as an excuse to be cruel to the living."},
			{"speaker": "Kaelen", "text": "Love, for me, sounds like insults and fixed buckles. If you need it softer, say so — I'll mispronounce the words and mean them anyway."},
			{"speaker": "Kaelen", "text": "I don't want your gratitude on a plate. I want you upright when the day goes wrong — and it will."},
			{"speaker": "Kaelen", "text": "If you ever think you're becoming me… good. Take the competence. Leave the part that thinks suffering is currency."},
			{"speaker": "Kaelen", "text": "Bench is open. So am I — in my way. Don't make a speech about it. Just show up."},
		],
	},
	{
		"id": "roster_solo_branik_fire_and_mercy",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Branik",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 1,
		"portrait_style": "static",
		"default_speaker_name": "Branik",
		"default_speaker_portrait": "res://Assets/Portraits/Branik Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Branik", "text": "Smells like onions and old smoke out here, {hero_name}. Focus on the onions. The smoke's just yesterday trying to ruin tomorrow."},
			{"speaker": "Branik", "text": "I cook because it makes sense. Math you can eat. You start looking for deeper meaning in a war camp, you'll just end up starving."},
			{"speaker": "Branik", "text": "Mercy's a luxury we don't stock. What we have is hot broth. And the decency not to stare when someone flinches."},
			{"speaker": "Branik", "text": "If you're looking for a confession or a profound lesson from an old soldier, you're at the wrong fire. Sit, eat, and keep quiet."},
		],
	},
	{
		"id": "roster_solo_branik_second_ladle",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Branik",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_branik_fire_and_mercy",
		"portrait_style": "static",
		"default_speaker_name": "Branik",
		"default_speaker_portrait": "res://Assets/Portraits/Branik Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Branik", "text": "Second ladle. Right. You're persistent... or just tired of outrunning your own ghosts. I know the feeling."},
			{"speaker": "Branik", "text": "I stir the pot so loudly because I don't want to hear the silence. Silence means remembering the men who didn't get a second ladle."},
			{"speaker": "Branik", "text": "Survivor's guilt isn't an ache, {hero_name}. It's a ringing in the ears. An accusation that you're only breathing because you stepped on someone else to do it."},
			{"speaker": "Branik", "text": "I feed people to shut up the ringing. It works... sometimes. But don't mistake it for nobility."},
		],
	},
	{
		"id": "roster_solo_branik_the_doorway",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Branik",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_branik_second_ladle",
		"portrait_style": "static",
		"default_speaker_name": "Branik",
		"default_speaker_portrait": "res://Assets/Portraits/Branik Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Branik", "text": "You keep showing up. I used to think you were just hungry. Now I think you're helping me guard the doorway. Thanks."},
			{"speaker": "Branik", "text": "I spent a long time surviving just to spite the ones who wanted me dead. That's a hollow reason to wake up."},
			{"speaker": "Branik", "text": "I'm done letting the dead vote on how I live. The stew isn't an apology anymore. It's defiance."},
			{"speaker": "Branik", "text": "We're fighting for the right to an ordinary, utterly boring Tuesday. And I’d be honored to share it with you. Sit down, {hero_name}. I saved the best cut of meat for you."},
		],
	},
	{
		"id": "roster_solo_liora_tea_rites",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Liora",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 2,
		"portrait_style": "static",
		"default_speaker_name": "Liora",
		"default_speaker_portrait": "res://Assets/Portraits/Liora_Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Liora", "text": "{hero_name}. I expected you. The perimeter checks out, the watch is set, and the doctrine is observed. Nothing is left to chance."},
			{"speaker": "Liora", "text": "I offer tea the way I treat my shield. Ritualistic maintenance. If you don't maintain the structure, the chaos wins."},
			{"speaker": "Liora", "text": "The temple taught me that obedience is the highest form of holiness. A closed hand strikes harder. I do not question the striking."},
			{"speaker": "Liora", "text": "I hold my posture rigid because I am the bulwark. If I slouch, the standard falls. Drink your tea; I will watch the dark."},
		],
	},
	{
		"id": "roster_solo_liora_bitter_cup",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Liora",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_liora_tea_rites",
		"portrait_style": "static",
		"default_speaker_name": "Liora",
		"default_speaker_portrait": "res://Assets/Portraits/Liora_Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Liora", "text": "It's exceptionally bitter on purpose, {hero_name}. Sweetness lulls the senses. Bitter keeps you painfully awake."},
			{"speaker": "Liora", "text": "I recite the old dogmas, but the words feel like ash in my throat lately. The doctrine protects the institution, not the people."},
			{"speaker": "Liora", "text": "If my bloodline is so sacred, why do my hands shake when the shouting stops? I am utterly terrified that I am just a weapon holding a prayerbook."},
			{"speaker": "Liora", "text": "My rigidity isn't faith. It's panic. I am so terribly afraid of breaking that I've forgotten how to bend without shattering."},
		],
	},
	{
		"id": "roster_solo_liora_open_palm",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Liora",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_liora_bitter_cup",
		"portrait_style": "static",
		"default_speaker_name": "Liora",
		"default_speaker_portrait": "res://Assets/Portraits/Liora_Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Liora", "text": "A third cup. You are remarkably stubborn at sitting with someone else's contradictions. It helps, {hero_name}."},
			{"speaker": "Liora", "text": "I've stopped quoting the temple to myself. Their holy war requires casualties. My true faith requires survivors."},
			{"speaker": "Liora", "text": "My hands are finally open. I can hold the shield without pretending it is forged from divine mandate. It's just steel, and I am just me."},
			{"speaker": "Liora", "text": "I've chosen who I want to save. And who I want to stand beside when the smoke clears. It's you, {hero_name}. Truly. You have my sword, and my friendship."},
		],
	},
	{
		"id": "roster_solo_nyx_lockpick_truth",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Nyx",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 3,
		"portrait_style": "static",
		"default_speaker_name": "Nyx",
		"default_speaker_portrait": "res://Assets/Portraits/Nyx Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Nyx", "text": "Oh, it's you, {hero_name}. Relax your jaw. The system is entirely rigged, we're all walking corpses, and nothing actually matters."},
			{"speaker": "Nyx", "text": "I've mapped four exits from this campfire. Not because I expect trouble, but because betting on stability is for idiots."},
			{"speaker": "Nyx", "text": "People assume I joke to avoid sincerity. They're wrong. I joke because sincerity is a spectacular way to get leverage used against you.", "player_choice": {
				"options": [
					{"id": "edge", "label": "Keep your exits. I don't need a confession."},
					{"id": "plain", "label": "Say the plain thing. I'll carry it carefully."},
					{"id": "tease", "label": "Mean something on purpose. I dare you."}
				],
				"reactions": {
					"edge": [
						{"speaker": "Nyx", "text": "We're mercenaries playing hero. I'm just honest about the mercenary part."}
					],
					"plain": [
						{"speaker": "Nyx", "text": "The plain version: Heroism is a temporary condition. Dying is permanent."}
					],
					"tease": [
						{"speaker": "Nyx", "text": "Fine. I mean it when I say we're all utterly doomed. Better?"}
					]
				}
			}},
		],
	},
	{
		"id": "roster_solo_nyx_stray_warmth",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Nyx",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_nyx_lockpick_truth",
		"portrait_style": "static",
		"default_speaker_name": "Nyx",
		"default_speaker_portrait": "res://Assets/Portraits/Nyx Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Nyx", "text": "Persistent. I checked the perimeter traps three times tonight. Not for tactical advantage. Because letting my guard down makes me physically sick."},
			{"speaker": "Nyx", "text": "There's a stray cat in camp. I fed it. I fiercely hate myself for feeding it, because now it expects me to be here tomorrow."},
			{"speaker": "Nyx", "text": "You people keep surviving. You keep winning. It's genuinely terrifying, because it forces me to consider what happens if I actually start caring."},
			{"speaker": "Nyx", "text": "If I crack a joke while I'm bleeding, it's because crying acknowledges that I had something to lose. Don't make me admit I have things to lose."},
		],
	},
	{
		"id": "roster_solo_nyx_no_chorus",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Nyx",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_nyx_stray_warmth",
		"portrait_style": "static",
		"default_speaker_name": "Nyx",
		"default_speaker_portrait": "res://Assets/Portraits/Nyx Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Nyx", "text": "Third time, Commander. Fine. You win. I dismantled the trap nearest your tent. Not an accident. Deliberate sabotage of my own detachment."},
			{"speaker": "Nyx", "text": "I desperately wanted to leave before everything went up in flames. But the chairs I keep pulling for you all are bolted to the floor now."},
			{"speaker": "Nyx", "text": "This attachment is irrational, dangerous, and completely against my rules. But if we're going to face the abyss, I'll walk in with my eyes open."},
			{"speaker": "Nyx", "text": "I'm still going to complain relentlessly. But I'll do it right by your side. You actually made me care, {hero_name}. Don't make me regret it... partner."},
		],
	},
	{
		"id": "roster_solo_sorrel_margin_note",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Sorrel",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 4,
		"portrait_style": "static",
		"default_speaker_name": "Sorrel",
		"default_speaker_portrait": "res://Assets/Portraits/Sorrel Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Sorrel", "text": "Ah, {hero_name}. Please be brief. I am currently categorizing battle trauma into statistical probabilities. It requires tremendous focus."},
			{"speaker": "Sorrel", "text": "Ignorance is unacceptable. By treating warfare strictly as a data set, we remove the messy, unpredictable variable of human emotion."},
			{"speaker": "Sorrel", "text": "I do not 'feel' the war, Commander. I archive it. The detachment ensures my methodologies remain pristine and uncorrupted."},
			{"speaker": "Sorrel", "text": "I will provide tactical readouts. Do not expect me to provide morale or empathy. Those are grossly inefficient metrics."},
		],
	},
	{
		"id": "roster_solo_sorrel_wrong_question",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Sorrel",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_sorrel_margin_note",
		"portrait_style": "static",
		"default_speaker_name": "Sorrel",
		"default_speaker_portrait": "res://Assets/Portraits/Sorrel Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Sorrel", "text": "I made an error in my margin notes, {hero_name}. I tried to calculate the acceptable losses for the next skirmish... and I recognized the names."},
			{"speaker": "Sorrel", "text": "Detachment suddenly feels violently inadequate. A thesis on hemorrhage does absolutely nothing to stop compounding blood loss on the field."},
			{"speaker": "Sorrel", "text": "I hide behind my ledger because touching a dying soldier requires a courage my academia never prepared me for."},
			{"speaker": "Sorrel", "text": "My statistics are cowardly. I am terrified that understanding the mechanism of death does not give me the power to prevent it."},
		],
	},
	{
		"id": "roster_solo_sorrel_last_page",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Sorrel",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_sorrel_wrong_question",
		"portrait_style": "static",
		"default_speaker_name": "Sorrel",
		"default_speaker_portrait": "res://Assets/Portraits/Sorrel Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Sorrel", "text": "A third conversation. The pattern holds. I have physically shut the ledger, {hero_name}. The data is secondary to the immediate reality."},
			{"speaker": "Sorrel", "text": "I will no longer observe from a safe, academic distance. A theory untested by blood is just a dangerous vanity."},
			{"speaker": "Sorrel", "text": "If I must drop my quill to drag someone from the line of fire, I will do so. And I will not flinch."},
			{"speaker": "Sorrel", "text": "When we win, the record will show not just our casualty rates, but our messy, beautiful survival. I'm honored to be in your chapter, {hero_name}. Let's write the rest together."},
		],
	},
	{
		"id": "roster_solo_darian_tune_after_hours",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Darian",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 5,
		"portrait_style": "static",
		"default_speaker_name": "Darian",
		"default_speaker_portrait": "res://Assets/Portraits/Darian Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Darian", "text": "Loom heroically if you must, {hero_name}. I am merely tuning a lute, not swearing fealty to your magnificent posture."},
			{"speaker": "Darian", "text": "The aristocracy taught me that style is fundamentally superior to substance. I have simply brought that vital education to the mud."},
			{"speaker": "Darian", "text": "I flirt to avoid standing still. If I banter, no one asks for my deeply held convictions. Mostly because I pretend not to have any."},
			{"speaker": "Darian", "text": "Do not demand sincerity from me. Sincerity is terribly dull, and I have spent my entire life avoiding boredom at all costs."},
		],
	},
	{
		"id": "roster_solo_darian_scuffed_polish",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Darian",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_darian_tune_after_hours",
		"portrait_style": "static",
		"default_speaker_name": "Darian",
		"default_speaker_portrait": "res://Assets/Portraits/Darian Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Darian", "text": "Notice the scuff on my boot, {hero_name}? It drives me mad. But it reminds me that my former elegance was funded by the starving."},
			{"speaker": "Darian", "text": "The charm is a reflexive, exhausting lie. I smile to hide the sheer, crushing shame I feel when I hear my family's name spoken aloud."},
			{"speaker": "Darian", "text": "My class bought its polish with your people's blood. I mock everything because treating it seriously means admitting my own complicity."},
			{"speaker": "Darian", "text": "I am so incredibly tired of performing. Sincerity doesn't bore me. It violently terrifies me, because it demands I take a stand."},
		],
	},
	{
		"id": "roster_solo_darian_third_ask",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Darian",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_darian_scuffed_polish",
		"portrait_style": "static",
		"default_speaker_name": "Darian",
		"default_speaker_portrait": "res://Assets/Portraits/Darian Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Darian", "text": "A third visit. At court, that is a calculated maneuver. Out here, it is foolish stubbornness. I find I vastly prefer the mud."},
			{"speaker": "Darian", "text": "I am setting the instrument aside. No performance today. I am actively choosing the grueling work over the elegant excuse."},
			{"speaker": "Darian", "text": "I will not rebuild the world my fathers broke. I will happily burn their tapestries to bandage our wounded."},
			{"speaker": "Darian", "text": "You have my completely unvarnished loyalty, {hero_name}. Not just as a commander, but as a true friend. My blade, and my heart, are exactly where you need them."},
		],
	},
	{
		"id": "roster_solo_celia_spear_rest",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Celia",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 6,
		"portrait_style": "static",
		"default_speaker_name": "Celia",
		"default_speaker_portrait": "res://Assets/Portraits/Celia Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Celia", "text": "I checked the spear straps, {hero_name}. Then the perimeter. Then the rationing. The academy taught us to abhor an idle mind."},
			{"speaker": "Celia", "text": "Command is a performance. If the soldiers see the nobility panic, the line breaks. So my posture remains absolutely rigid."},
			{"speaker": "Celia", "text": "I do not complain about extreme fatigue. Fatigue is merely an administrative error on the part of the flesh."},
			{"speaker": "Celia", "text": "If you require obedience without question, merely give the order. I have practiced immaculate compliance my entire life.", "player_choice": {
				"options": [
					{"id": "need", "label": "I need you useful. Rest later."},
					{"id": "see", "label": "I see you. Take the rest now."},
					{"id": "trust", "label": "Tell me what you actually need."}
				],
				"reactions": {
					"need": [
						{"speaker": "Celia", "text": "Understood. I can do useful. Useful is a language I speak cleanly."},
						{"speaker": "Celia", "text": "Just... if I go quiet, check that it's actually focus and not me disappearing into the work. I'm still learning the difference."}
					],
					"see": [
						{"speaker": "Celia", "text": "...Thank you. That's harder to hear than an order, but it lands truer."},
						{"speaker": "Celia", "text": "I'll rest when the line holds. Tonight it holds. Because you said so, and because I am choosing to believe you."}
					],
					"trust": [
						{"speaker": "Celia", "text": "What I need is simple and difficult. Permission to matter outside my usefulness. I'm not good at asking."},
						{"speaker": "Celia", "text": "So I'll say it once. If I fall, do not make a sermon of me. Let it mean we failed the living, not that I was only ever a symbol."}
					]
				}
			}},
			{"speaker": "Celia", "text": "Whatever you answered… I'll hold it the way I hold a shield. Steady. On purpose."},
		],
	},
	{
		"id": "roster_solo_celia_sky_line",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Celia",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_celia_spear_rest",
		"portrait_style": "static",
		"default_speaker_name": "Celia",
		"default_speaker_portrait": "res://Assets/Portraits/Celia Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Celia", "text": "I checked the sky before the spear. I couldn't help it. For one second, I just wanted to look at something that didn't need organizing."},
			{"speaker": "Celia", "text": "I am so exhausted, {hero_name}. My spine aches from holding everyone's morale up like a tent pole."},
			{"speaker": "Celia", "text": "The Valeron drills broke the people who couldn't perform flawlessly. I survived them. I am beginning to wonder at what cost."},
			{"speaker": "Celia", "text": "If I unclench my jaw, I might actually weep. If you value my dignity, pretend you do not see my hands shaking."},
		],
	},
	{
		"id": "roster_solo_celia_chosen_post",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Celia",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_celia_sky_line",
		"portrait_style": "static",
		"default_speaker_name": "Celia",
		"default_speaker_portrait": "res://Assets/Portraits/Celia Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Celia", "text": "A third visit. You do not demand a report or a performance. You just let me sit. You have no idea what a luxury that is."},
			{"speaker": "Celia", "text": "I am putting the spear down. Just for ten minutes. The line will not collapse if I allow myself to rest."},
			{"speaker": "Celia", "text": "My family taught me I was a symbol first and a person second. I am actively trying to reverse that hierarchy."},
			{"speaker": "Celia", "text": "I will proudly hold the line for you when the horns sound. But tonight, as just Celia... I'm really glad you're here. Thank you for being my friend."},
		],
	},
	{
		"id": "roster_solo_rufus_powder_math",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Rufus",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 7,
		"portrait_style": "static",
		"default_speaker_name": "Rufus",
		"default_speaker_portrait": "res://Assets/Portraits/Rufus Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Rufus", "text": "If you're here for philosophy, {hero_name}, wrong tent. You want to know if we have enough canvas to patch the roofs? Pull up a stump."},
			{"speaker": "Rufus", "text": "Powder, shot, spare leather, dried beef. These are the only things that keep heroes from becoming corpses by Tuesday."},
			{"speaker": "Rufus", "text": "I treat the roster like a ledger because math doesn't lie to me. Math doesn't panic. Math just demands balancing."},
			{"speaker": "Rufus", "text": "Go inspire someone. I'll sit here and count the nails. You'll thank me when your wagons don't lose their axles."},
		],
	},
	{
		"id": "roster_solo_rufus_wet_barrel",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Rufus",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_rufus_powder_math",
		"portrait_style": "static",
		"default_speaker_name": "Rufus",
		"default_speaker_portrait": "res://Assets/Portraits/Rufus Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Rufus", "text": "Found a wet patch by the flour sacks. I handled it, but my heart stopped for a full minute. Flour is life out here."},
			{"speaker": "Rufus", "text": "The ledger isn't a hobby. It's how I keep the fear out. If I know exactly what we have, I know exactly how long we survive."},
			{"speaker": "Rufus", "text": "I was hungry on the docks. Not 'missed a meal' hungry. 'Staring at a stray dog with terrible thoughts' hungry. I will not let this camp feel that."},
			{"speaker": "Rufus", "text": "I obsess over inventory because I am terrified of failing you all. If the food runs out, the honor follows immediately."},
		],
	},
	{
		"id": "roster_solo_rufus_young_hands",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Rufus",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_rufus_wet_barrel",
		"portrait_style": "static",
		"default_speaker_name": "Rufus",
		"default_speaker_portrait": "res://Assets/Portraits/Rufus Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Rufus", "text": "Third time, {hero_name}. The ledger is closed. For tonight, anyway. I'm trying to look at the fire instead of the supplies."},
			{"speaker": "Rufus", "text": "You recruits aren't numbers. I keep forgetting that. Five wounded isn't a deficit in bandages, it's five of my friends bleeding."},
			{"speaker": "Rufus", "text": "I'm trusting you to keep the monsters off our backs, so I can stop planning for our total ruin quite so meticulously."},
			{"speaker": "Rufus", "text": "Take an extra ration, {hero_name}. Tell the quartermaster I authorized it. And between you and me? Having you lead us is the best asset in this entire ledger."},
		],
	},
	{
		"id": "roster_solo_inez_tree_line",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Inez",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 8,
		"portrait_style": "static",
		"default_speaker_name": "Inez",
		"default_speaker_portrait": "res://Assets/Portraits/Inez Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Inez", "text": "The wind shifted, {hero_name}. You missed it. You focus too much on the fire and not enough on the dark."},
			{"speaker": "Inez", "text": "I stay near the tree line because out here, distance equals time. The further I am from the noise, the sooner I see the threat."},
			{"speaker": "Inez", "text": "My rifle is a tool, my eyes are the mechanism. Empathy throws off the shot. I do not afford myself empathy."},
			{"speaker": "Inez", "text": "I am not here for camaraderie. I am here to ensure absolutely nothing reaches the camp unseen. Go back to the warmth."},
		],
	},
	{
		"id": "roster_solo_inez_mud_memory",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Inez",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_inez_tree_line",
		"portrait_style": "static",
		"default_speaker_name": "Inez",
		"default_speaker_portrait": "res://Assets/Portraits/Inez Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Inez", "text": "The mud says someone dragged something heavy away. It was an animal, this time. I watched it through the scope."},
			{"speaker": "Inez", "text": "Distance does not erase the impact. Watching a living thing drop from three hundred yards away is still watching a living thing drop."},
			{"speaker": "Inez", "text": "I am incredibly still because the moment I vibrate, I shatter. The spiritual toll of this precision is... eroding me. From the inside."},
			{"speaker": "Inez", "text": "I don't look at the faces in the scope anymore. If I look, I hesitate. And if I hesitate, our people die."},
		],
	},
	{
		"id": "roster_solo_inez_still_pool",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Inez",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_inez_mud_memory",
		"portrait_style": "static",
		"default_speaker_name": "Inez",
		"default_speaker_portrait": "res://Assets/Portraits/Inez Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Inez", "text": "Third time out here in the cold. Do you not feel the damp? ...Never mind. It's oddly reassuring to have someone stand in my blind spot."},
			{"speaker": "Inez", "text": "I unloaded the breech. For five minutes. A self-imposed cease-fire. The woods do not instantly collapse when I stop aiming."},
			{"speaker": "Inez", "text": "My stillness is shifting. From predatory focus to simple... presence. It is painfully difficult, but necessary."},
			{"speaker": "Inez", "text": "I will protect the camp because I desperately want our people to survive. I want you to survive, {hero_name}. Stand beside me in the warmth for a change. It's nice."},
		],
	},
	{
		"id": "roster_solo_tariq_line_of_sight",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Tariq",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 9,
		"portrait_style": "static",
		"default_speaker_name": "Tariq",
		"default_speaker_portrait": "res://Assets/Portraits/Tariq Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Tariq", "text": "If you've come for inspiration, {hero_name}, I'm fresh out of sermons. The rhythm of violence makes a terrible poem."},
			{"speaker": "Tariq", "text": "I observe the camp like a stanza that doesn't rhyme. Fascinating conceptually, utterly disastrous in execution."},
			{"speaker": "Tariq", "text": "I engage with this war philosophically. If I treat the bloodshed as abstract theory, the smell of copper bothers me significantly less."},
			{"speaker": "Tariq", "text": "You command. I critique. It is a mutually beneficial arrangement that keeps my boots largely clean of ideological fanaticism."},
		],
	},
	{
		"id": "roster_solo_tariq_margin_lecture",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Tariq",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_tariq_line_of_sight",
		"portrait_style": "static",
		"default_speaker_name": "Tariq",
		"default_speaker_portrait": "res://Assets/Portraits/Tariq Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Tariq", "text": "A second conversation. My theories are failing, {hero_name}. The mud is entirely too literal to be metaphorized."},
			{"speaker": "Tariq", "text": "I tried to weave a philosophy out of a skirmish yesterday. Utter nonsense. A spear through the lung has no subtext."},
			{"speaker": "Tariq", "text": "My cynicism is a coward's defense. I mock the earnestness of the recruits because their sincerity terrifies my detachment."},
			{"speaker": "Tariq", "text": "I am suffocating on my own cleverness. At some point, sitting on the philosophical fence just leaves you full of splinters."},
		],
	},
	{
		"id": "roster_solo_tariq_bargain_kept",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Tariq",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_tariq_margin_lecture",
		"portrait_style": "static",
		"default_speaker_name": "Tariq",
		"default_speaker_portrait": "res://Assets/Portraits/Tariq Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Tariq", "text": "Third visit. Fine. The poet concedes, {hero_name}. The abstract has been thoroughly routed by reality."},
			{"speaker": "Tariq", "text": "I am discarding the clever verses. We need a philosophy built for the trenches, constructed of grit, loyalty, and blunt force trauma."},
			{"speaker": "Tariq", "text": "I no longer view this camp as a sociological experiment. You are my people. God help my academic reputation."},
			{"speaker": "Tariq", "text": "I'll give you the ugliest truths entirely unrhymed. But I'll also draw my blade and help you fix them. It's actually an honor standing with you, my friend."},
		],
	},
	{
		"id": "roster_solo_mira_quiet_nock",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Mira Ashdown",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 10,
		"portrait_style": "static",
		"default_speaker_name": "Mira Ashdown",
		"default_speaker_portrait": "res://Assets/Portraits/Mira Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Mira Ashdown", "text": "I was checking the string tension. Someone has to make sure the weapons work when the younger ones inevitably act foolish."},
			{"speaker": "Mira Ashdown", "text": "I do not coddle. Survival is a discipline acquired through repetition and fear. I supply both."},
			{"speaker": "Mira Ashdown", "text": "Everyone in this camp thinks they are invincible. It is my deeply irritating duty to remind them they are made of meat."},
			{"speaker": "Mira Ashdown", "text": "If I bark orders, do not interpret it as anger. Interpret it as an aggressive refusal to let anyone else die on my watch."},
		],
	},
	{
		"id": "roster_solo_mira_oakhaven_weight",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Mira Ashdown",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_mira_quiet_nock",
		"portrait_style": "static",
		"default_speaker_name": "Mira Ashdown",
		"default_speaker_portrait": "res://Assets/Portraits/Mira Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Mira Ashdown", "text": "You came back. Good. I need someone who won't treat me like a legend when I admit a tactical error."},
			{"speaker": "Mira Ashdown", "text": "I see the weak points in every defensive line. I see exactly how everyone could die. It's a vision I cannot turn off."},
			{"speaker": "Mira Ashdown", "text": "Oakhaven taught me that my absolute best is sometimes profoundly inadequate. The weight of that knowledge is crushing."},
			{"speaker": "Mira Ashdown", "text": "I smother the recruits because I am terrified. Because if one of them falls, I know I will blame my own hands for failing to catch them."},
		],
	},
	{
		"id": "roster_solo_mira_still_here",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Mira Ashdown",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_mira_oakhaven_weight",
		"portrait_style": "static",
		"default_speaker_name": "Mira Ashdown",
		"default_speaker_portrait": "res://Assets/Portraits/Mira Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Mira Ashdown", "text": "Third time. You're tracking my stress levels. Astute, {hero_name}. Also, deeply annoying. But... appreciated."},
			{"speaker": "Mira Ashdown", "text": "I am working on un-nocking the arrow before the threat actually arrives. I cannot hold the line in perpetual tension."},
			{"speaker": "Mira Ashdown", "text": "I have to trust that the camp can protect itself. More troublingly, I have to trust that they can protect me."},
			{"speaker": "Mira Ashdown", "text": "If I ask for help tonight, just stand at my flank. You've lightened a burden I thought I'd have to carry forever, {hero_name}. For that, you have my deepest gratitude... and my smile."},
		],
	},
	{
		"id": "roster_solo_pell_first_vigil",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Pell Rowan",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 11,
		"portrait_style": "static",
		"default_speaker_name": "Pell Rowan",
		"default_speaker_portrait": "res://Assets/Portraits/Pell Rowan Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Pell Rowan", "text": "Commander {hero_name}! I—I mean, good evening. I was just practicing my sword forms. You know, for honor!"},
			{"speaker": "Pell Rowan", "text": "I'm going to be exactly like the knights in the ballads. I've memorized the vows, polished the brass, and absolutely ignored the blister on my heel."},
			{"speaker": "Pell Rowan", "text": "If I talk too much, it's just enthusiasm! The cause is so incredibly righteous, who wouldn't be loud about it?"},
			{"speaker": "Pell Rowan", "text": "Just give me an order—any order—and I will execute it with maximum dramatic flair and totally genuine devotion!"},
		],
	},
	{
		"id": "roster_solo_pell_shield_drill",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Pell Rowan",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_pell_first_vigil",
		"portrait_style": "static",
		"default_speaker_name": "Pell Rowan",
		"default_speaker_portrait": "res://Assets/Portraits/Pell Rowan Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Pell Rowan", "text": "Second check-in. {hero_name}... the forms aren't helping today. My arms shake, and I realized I don't actually know what I'm swinging at."},
			{"speaker": "Pell Rowan", "text": "Heroism looked a lot simpler when it was ink on a page. In the mud, it just looks like desperate people trying not to bleed to death."},
			{"speaker": "Pell Rowan", "text": "I keep talking loudly because if I stop, I'll think about the farm. About the soil... and the fact that it's probably burned."},
			{"speaker": "Pell Rowan", "text": "I'm not bold. I'm reckless because I'm terrified I have nothing left to return to. The ballads didn't mention this part."},
		],
	},
	{
		"id": "roster_solo_pell_oath_without_audience",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Pell Rowan",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_pell_shield_drill",
		"portrait_style": "static",
		"default_speaker_name": "Pell Rowan",
		"default_speaker_portrait": "res://Assets/Portraits/Pell Rowan Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Pell Rowan", "text": "Third time! I'm trying very hard not to be incredibly emotional about you checking on me again. I might be failing. Sorry."},
			{"speaker": "Pell Rowan", "text": "The farm is gone. Fine. But this camp... the mud here is real. The people here are real. I can plant something new in this soil."},
			{"speaker": "Pell Rowan", "text": "I don't care about the ballads anymore. I care about making sure Rufus gets his inventory sorted and Mira doesn't have to yell so much."},
			{"speaker": "Pell Rowan", "text": "No more performing for ghosts. I swear my blade to this wonderful, chaotic family. I'd follow you absolutely anywhere, {hero_name}. And I mean that."},
		],
	},
	{
		"id": "roster_solo_tamsin_salve_and_list",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Tamsin Reed",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 12,
		"portrait_style": "static",
		"default_speaker_name": "Tamsin Reed",
		"default_speaker_portrait": "res://Assets/Portraits/Tamsin Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Tamsin Reed", "text": "Oh—{hero_name}! Sorry, I didn't mean to startle you, I just—bandages, right, and the tincture counts, and I think I'm talking too fast already."},
			{"speaker": "Tamsin Reed", "text": "In the medical tent, when someone's actually bleeding, I stop babbling. Mostly. Because the blood is louder than my fear."},
			{"speaker": "Tamsin Reed", "text": "Herbs, bottles, thread—I fidget terribly when I'm scared. If my hands are busy, my heart stops sprinting."},
			{"speaker": "Tamsin Reed", "text": "If you need something for aches or nerves, tell me. If you're fine, also tell me—otherwise I'll invent injuries for you out of sheer anxiety."},
		],
	},
	{
		"id": "roster_solo_tamsin_firm_tent",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Tamsin Reed",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_tamsin_salve_and_list",
		"portrait_style": "static",
		"default_speaker_name": "Tamsin Reed",
		"default_speaker_portrait": "res://Assets/Portraits/Tamsin Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Tamsin Reed", "text": "Second visit! I mean—not that I'm keeping track—I am completely keeping track—it's fine, I'm just glad you're here, {hero_name}."},
			{"speaker": "Tamsin Reed", "text": "People completely underestimate healers until the line breaks. Then suddenly we're 'essential.' I'd much rather be respected on the quiet days, too."},
			{"speaker": "Tamsin Reed", "text": "Competence emerging from insecurity sounds really poetic in stories. In reality, it feels like dry-heaving before a shift and then doing the shift anyway."},
			{"speaker": "Tamsin Reed", "text": "Survival isn't just swords and shields. It's water, stitches, sleep, and someone remembering to eat. I am the very annoying reminder with good intentions."},
		],
	},
	{
		"id": "roster_solo_tamsin_hidden_labor",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Tamsin Reed",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_tamsin_firm_tent",
		"portrait_style": "static",
		"default_speaker_name": "Tamsin Reed",
		"default_speaker_portrait": "res://Assets/Portraits/Tamsin Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Tamsin Reed", "text": "Third time, {hero_name}. If you're just checking on me, I'm embarrassingly grateful. If you're not, I'm still grateful. I really can't win."},
			{"speaker": "Tamsin Reed", "text": "I realized something. You keep coming back to my tent, and nobody has died here yet today. That makes this a good tent."},
			{"speaker": "Tamsin Reed", "text": "I will probably always jump at loud noises. But when the noise stops, I know how to put people back together. That has to be brave enough."},
			{"speaker": "Tamsin Reed", "text": "You don't need to be a hero when you're in here. You're just my friend. Tell me when you hurt, and I promise I'll always fix it."},
		],
	},
	{
		"id": "roster_solo_hest_sparks_corner_bit",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Hest “Sparks”",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 13,
		"portrait_style": "static",
		"default_speaker_name": "Hest “Sparks”",
		"default_speaker_portrait": "res://Assets/Portraits/Hest Spark Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Hest “Sparks”", "text": "Yo, {hero_name}. If you're here to lecture me about the missing jerky, you'd better make it funny. Otherwise I'll die of sheer boredom."},
			{"speaker": "Hest “Sparks”", "text": "Yeah, I talk fast. Yeah, I swipe extra rations. Survival goes to whoever stays weird enough to be hard to predict."},
			{"speaker": "Hest “Sparks”", "text": "Laughing people are vastly safer people. Keep 'em laughing, keep 'em distracted. That's not profound wisdom, that's just street math."},
			{"speaker": "Hest “Sparks”", "text": "The nickname is Sparks. Chaos included. Warranty completely void if you take me seriously before I've had coffee. Improvise."},
		],
	},
	{
		"id": "roster_solo_hest_sparks_linger",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Hest “Sparks”",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_hest_sparks_corner_bit",
		"portrait_style": "static",
		"default_speaker_name": "Hest “Sparks”",
		"default_speaker_portrait": "res://Assets/Portraits/Hest Spark Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Hest “Sparks”", "text": "Back again, boss-of-mine. If this is an official inspection, I absolutely did not completely borrow anything. Today."},
			{"speaker": "Hest “Sparks”", "text": "I swipe things when I'm feeling insecure. The jokes... they're my armor. If I'm not entertaining you, why would you keep me around?"},
			{"speaker": "Hest “Sparks”", "text": "Fear of being disposable is my secret boss fight. Everything's a bit because bits don't get thrown in the trash—they get applauded."},
			{"speaker": "Hest “Sparks”", "text": "If I push you and you stay totally steady... that's weirdly comforting. Just don't tell anyone I said that. It completely ruins my brand."},
		],
	},
	{
		"id": "roster_solo_hest_sparks_not_disposable",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Hest “Sparks”",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_hest_sparks_linger",
		"portrait_style": "static",
		"default_speaker_name": "Hest “Sparks”",
		"default_speaker_portrait": "res://Assets/Portraits/Hest Spark Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Hest “Sparks”", "text": "Third round, {hero_name}. If you're seriously still showing up, that's... dangerous. It means I might start relying on you. Gross."},
			{"speaker": "Hest “Sparks”", "text": "When I'm actually sincere, I desperately dodge eye contact. Staring at your shoulder right now, for the record."},
			{"speaker": "Hest “Sparks”", "text": "Dependence officially scares me more than enemy blades. But if you actually want me here just to be here... fine. I'm in."},
			{"speaker": "Hest “Sparks”", "text": "If you keep me around, keep me as your friend. Meaning... I'm actually here for you, not just for the jokes. Seriously. Thanks for seeing me."},
		],
	},
	{
		"id": "roster_solo_alden_service_first",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Brother Alden",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 14,
		"portrait_style": "static",
		"default_speaker_name": "Brother Alden",
		"default_speaker_portrait": "res://Assets/Portraits/Brother Alden Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Brother Alden", "text": "{hero_name}. Sit, if you like. I was only folding wraps. It is work that keeps the hands honest."},
			{"speaker": "Brother Alden", "text": "Faith is service. Anything else is mere vanity in a clean robe. I speak slowly on purpose. Panic sells beautifully. Patience protects."},
			{"speaker": "Brother Alden", "text": "Calm is not softness. It is simply weight placed exactly where it will not break others."},
			{"speaker": "Brother Alden", "text": "If you carry something heavy tonight, you may set part of it here. I am built to carry the excess."},
		],
	},
	{
		"id": "roster_solo_alden_infirmary_hush",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Brother Alden",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_alden_service_first",
		"portrait_style": "static",
		"default_speaker_name": "Brother Alden",
		"default_speaker_portrait": "res://Assets/Portraits/Brother Alden Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Brother Alden", "text": "You returned. Good. Consistency is its own kind of courage, especially in a camp quite this loud."},
			{"speaker": "Brother Alden", "text": "I help in the infirmary when I am asked. But lately... there is so much groaning. It is a very heavy sound to fill a small room."},
			{"speaker": "Brother Alden", "text": "I occasionally endure more than I should. I make a virtue of not asking for aid, and the isolation of it is profound."},
			{"speaker": "Brother Alden", "text": "True mediation is lowering the temperature. I just wish I knew how to occasionally lower my own without feeling like I have failed my vows."},
		],
	},
	{
		"id": "roster_solo_alden_rooted_prayer",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Brother Alden",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_alden_infirmary_hush",
		"portrait_style": "static",
		"default_speaker_name": "Brother Alden",
		"default_speaker_portrait": "res://Assets/Portraits/Brother Alden Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Brother Alden", "text": "A third conversation, {hero_name}. You need not perform clarity for me. And tonight, I will not perform flawless serenity for you."},
			{"speaker": "Brother Alden", "text": "I trace my wraps when my faith is thin. It is a physical reminder that hands can act even when the spirit is deeply exhausted."},
			{"speaker": "Brother Alden", "text": "I am learning that accepting gentleness is also a form of humility. It admits I am not infinite."},
			{"speaker": "Brother Alden", "text": "Whatever you must hold in this war, hold it with mercy. And when it gets too heavy, let me carry it with you. That's what friends do."},
		],
	},
	{
		"id": "roster_solo_oren_missing_tool",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Oren Pike",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 15,
		"portrait_style": "static",
		"default_speaker_name": "Oren Pike",
		"default_speaker_portrait": "res://Assets/Portraits/OrenPike Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Oren Pike", "text": "{hero_name}. If you're here for small talk, the answer is definitively no. If you're here because something is bent or misaligned—talk."},
			{"speaker": "Oren Pike", "text": "Waste offends me vastly more than danger does. Danger is honest. Waste is just people refusing to count the cost."},
			{"speaker": "Oren Pike", "text": "Titles don't tighten a single bolt. Competence does. I would rather take orders from someone who understands leverage than someone with a shiny crest."},
			{"speaker": "Oren Pike", "text": "If I sound incredibly annoyed while fixing your problem, that's just my voice doing its job. Check the structural result."},
		],
	},
	{
		"id": "roster_solo_oren_stack_height",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Oren Pike",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_oren_missing_tool",
		"portrait_style": "static",
		"default_speaker_name": "Oren Pike",
		"default_speaker_portrait": "res://Assets/Portraits/OrenPike Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Oren Pike", "text": "You again, {hero_name}. Fine. Second visit means you're either intensely stubborn or you actually use your eyes."},
			{"speaker": "Oren Pike", "text": "I rant loudly because I cannot handle the alternative. The alternative is recognizing that if I misjudge the structural load, my friends die under it."},
			{"speaker": "Oren Pike", "text": "Calibration calms my nerves. If you see me tuning something at 3 AM, mind your business. I'm self-medicating with torque."},
			{"speaker": "Oren Pike", "text": "Camp inefficiency isn't a comedy act. It is hours stolen from sleep, which means reflexes slow, which means death out there. Every single bolt matters."},
		],
	},
	{
		"id": "roster_solo_oren_load_bearing_truth",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Oren Pike",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_oren_stack_height",
		"portrait_style": "static",
		"default_speaker_name": "Oren Pike",
		"default_speaker_portrait": "res://Assets/Portraits/OrenPike Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Oren Pike", "text": "Third time. Alright, {hero_name}. You're officially a recurring load stress. But... acceptable."},
			{"speaker": "Oren Pike", "text": "Physical consequences are the absolute only language every single rank understands. I yell because I actually care what happens to the lot of you."},
			{"speaker": "Oren Pike", "text": "If I completely refuse help, it's just pride. Call me out on it. Hand me the wrench without making a touching moment out of it."},
			{"speaker": "Oren Pike", "text": "You keep us alive out there, and I'll make sure the ground under you stays solid. We make a damn good team, {hero_name}. Don't tell anyone I said that."},
		],
	},
	{
		"id": "roster_solo_garrick_oath_line",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Garrick Vale",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 16,
		"portrait_style": "static",
		"default_speaker_name": "Garrick Vale",
		"default_speaker_portrait": "res://Assets/Portraits/Garrick Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Garrick Vale", "text": "{hero_name}. A moment, if you will. Not ceremony. I much prefer clarity to flourish."},
			{"speaker": "Garrick Vale", "text": "I was raised from birth to love order. The protocols of Knighthood were my absolute foundation."},
			{"speaker": "Garrick Vale", "text": "When I am distressed, I tighten up into rigid etiquette. If I sound abruptly formal, you may assume I am on guard."},
			{"speaker": "Garrick Vale", "text": "If you need someone to hold a line—whether literal or moral—I will not make it theatrical. I will simply secure it."},
		],
	},
	{
		"id": "roster_solo_garrick_crown_and_crowd",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Garrick Vale",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_garrick_oath_line",
		"portrait_style": "static",
		"default_speaker_name": "Garrick Vale",
		"default_speaker_portrait": "res://Assets/Portraits/Garrick Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Garrick Vale", "text": "You returned, {hero_name}. I must confess, my rigid etiquette earlier was shielding a profound sense of failure."},
			{"speaker": "Garrick Vale", "text": "A betrayal of oath doesn't always arrive as dramatic treason. Sometimes it's realizing the crown you swore to protect is actively starving its people."},
			{"speaker": "Garrick Vale", "text": "Disillusionment hurts considerably more when you still fundamentally love what the emblem was supposed to mean."},
			{"speaker": "Garrick Vale", "text": "Old models of honor die loudly in my mind. I am grieving the nobility I thought we possessed."},
		],
	},
	{
		"id": "roster_solo_garrick_worthy_loyalty",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Garrick Vale",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_garrick_crown_and_crowd",
		"portrait_style": "static",
		"default_speaker_name": "Garrick Vale",
		"default_speaker_portrait": "res://Assets/Portraits/Garrick Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Garrick Vale", "text": "A third conversation. Then I will be perfectly plain: I am deciding to reforge my loyalty. Not to banners, but to this ragged roster."},
			{"speaker": "Garrick Vale", "text": "Dignity must be reciprocal. The crown failed that test. I watch you, {hero_name}, and I see someone passing it."},
			{"speaker": "Garrick Vale", "text": "I am putting away the old etiquette. Casual, genuine ease is much harder for me, but I am currently practicing."},
			{"speaker": "Garrick Vale", "text": "I swear my blade to this camp, and my loyalty to you. I'm honored to call you my commander, and my friend. Let the palace rust."},
		],
	},
	{
		"id": "roster_solo_sabine_perimeter_math",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Sabine Varr",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 17,
		"portrait_style": "static",
		"default_speaker_name": "Sabine Varr",
		"default_speaker_portrait": "res://Assets/Portraits/Sabine Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Sabine Varr", "text": "{hero_name}. Perimeter secure first, messy feelings after. If you vehemently disagree, please make your case with numbers, not bad poetry."},
			{"speaker": "Sabine Varr", "text": "True stability isn't remotely glamorous. It is food moving efficiently, gates closing securely, and keeping idiots from storing oil near the fire."},
			{"speaker": "Sabine Varr", "text": "Standard League training: emotion only occurs after the tactical threat is gone. I am not heartless. I am securely scheduled."},
			{"speaker": "Sabine Varr", "text": "Tell me exactly what you need secured. I will tell you exactly what is delusional. We'll meet in the middle, or we won't."},
		],
	},
	{
		"id": "roster_solo_sabine_revolt_menu",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Sabine Varr",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_sabine_perimeter_math",
		"portrait_style": "static",
		"default_speaker_name": "Sabine Varr",
		"default_speaker_portrait": "res://Assets/Portraits/Sabine Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Sabine Varr", "text": "A second pass, {hero_name}. Good. Consistency is my favorite baseline security feature."},
			{"speaker": "Sabine Varr", "text": "I historically cover concern with critique. If I harshly nitpick your frontline spacing, I am essentially terrorized by the idea of you dying."},
			{"speaker": "Sabine Varr", "text": "My lack of visible reaction isn't smug moral superiority. It's aggressively compressed fear. I'm struggling with translating the difference."},
			{"speaker": "Sabine Varr", "text": "Clean ground, perfectly clear firing lanes, and zero vulnerabilities. I overcompensate on security because the alternative makes my chest seize."},
		],
	},
	{
		"id": "roster_solo_sabine_increment_warmth",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Sabine Varr",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_sabine_revolt_menu",
		"portrait_style": "static",
		"default_speaker_name": "Sabine Varr",
		"default_speaker_portrait": "res://Assets/Portraits/Sabine Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Sabine Varr", "text": "Third meeting, {hero_name}. If you're expecting perfect reliability and absolute ruthless efficiency? Still fully available."},
			{"speaker": "Sabine Varr", "text": "But perhaps... you can have that without me treating every conversation like a breach protocol. I'm trying out the concept of warmth. In increments."},
			{"speaker": "Sabine Varr", "text": "I soften slowly. If you happen to notice a crack in the armor, do not pry it wider for sport. Just stand in the clearance with me."},
			{"speaker": "Sabine Varr", "text": "Affection, for me, is showing up fully armed when the perimeter gets ugly. But knowing I'm doing it to protect a friend... makes me actually smile."},
		],
	},
	{
		"id": "roster_solo_yselle_backstage_breath",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Yselle Maris",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 18,
		"portrait_style": "static",
		"default_speaker_name": "Yselle Maris",
		"default_speaker_portrait": "res://Assets/Portraits/Yselle Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Yselle Maris", "text": "If you've come for a performance, the camp gets one later. If you've come for me... step where the lanterns don't reach."},
			{"speaker": "Yselle Maris", "text": "Morale isn't a luxury. It's how throats forcefully unclench enough to swallow hard bread. I have watched beauty actively keep people alive. Do not dare call it frivolous unless you've tried dying without it."},
			{"speaker": "Yselle Maris", "text": "I read crowded rooms exactly the way you read maps. Exits, appetites, and establishing who is lying to themselves the loudest."},
			{"speaker": "Yselle Maris", "text": "A curated presentation isn't false. It is simply survival with vastly better tailoring. And I am quite tired of apologizing for the visible stitches."},
			{"speaker": "Yselle Maris", "text": "Verbal fencing is exhilarating right up until someone bleeds. I will happily fence with you. Just tell me exactly when you want sincerity instead of a riposte."},
			{"speaker": "Yselle Maris", "text": "Tonight, I will lift the camp's spirits on purpose. If you ever need lifting in private, ask me without an audience."},
		],
	},
	{
		"id": "roster_solo_yselle_rumor_silk",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Yselle Maris",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_yselle_backstage_breath",
		"portrait_style": "static",
		"default_speaker_name": "Yselle Maris",
		"default_speaker_portrait": "res://Assets/Portraits/Yselle Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Yselle Maris", "text": "Again, {hero_name}? Good. Repetition typically means trust. Or excellent, dangerous curiosity. I will happily take either."},
			{"speaker": "Yselle Maris", "text": "Rumors reach me carefully wrapped in silk. I unwrap them, repackage them, and hand back something actionable. That is labor, too."},
			{"speaker": "Yselle Maris", "text": "I will smile fiercely through discomfort right up until I can't. If the smile drops, please don't stare. Just stay."},
			{"speaker": "Yselle Maris", "text": "Performance actively regulates fear. So does a steady hand securely on your shoulder. I offer both. At entirely different prices."},
			{"speaker": "Yselle Maris", "text": "People who demand the 'real' me usually just want a simpler, lazier story. I am not simple. I am precise."},
			{"speaker": "Yselle Maris", "text": "If I default to managing perception before attempting intimacy, correct me—gently. I respond much better to sharp wit than to scolding."},
		],
	},
	{
		"id": "roster_solo_yselle_uncurated_hour",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Yselle Maris",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_yselle_rumor_silk",
		"portrait_style": "static",
		"default_speaker_name": "Yselle Maris",
		"default_speaker_portrait": "res://Assets/Portraits/Yselle Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Yselle Maris", "text": "If you've come for a performance, the camp gets one later. If you've come for me... step where the lanterns don't reach."},
			{"speaker": "Yselle Maris", "text": "Morale isn't a luxury. It's how throats forcefully unclench enough to swallow hard bread. I have watched beauty actively keep people alive."},
			{"speaker": "Yselle Maris", "text": "A curated presentation isn't false. It is simply survival with vastly better tailoring. And I am quite tired of apologizing for the visible stitches."},
			{"speaker": "Yselle Maris", "text": "Tonight, I will lift the camp's spirits. But if you ever just want to sit quietly with a friend... I'm here for that, too."},
		],
	},
	{
		"id": "roster_solo_meris_institutional_ash",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Sister Meris",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 19,
		"portrait_style": "static",
		"default_speaker_name": "Sister Meris",
		"default_speaker_portrait": "res://Assets/Portraits/Sister Meris Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Sister Meris", "text": "{hero_name}. If you want comfort entirely devoid of truth, I am the wrong sister. If you want truth—even when it costs—speak."},
			{"speaker": "Sister Meris", "text": "I once served utter certainty as if it were a virtue. I am uncomfortably learning that nuance is not weakness. It is courage with better eyes."},
			{"speaker": "Sister Meris", "text": "My voice goes very cold when I am afraid of being tragically wrong again. Please correct me if simple kindness is what the moment needs."},
			{"speaker": "Sister Meris", "text": "Duty stripped of conscience became profound cruelty in my hands. I am here to ensure it does not do so again—even when familiar discipline tempts me."},
		],
	},
	{
		"id": "roster_solo_meris_long_pause",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Sister Meris",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_meris_institutional_ash",
		"portrait_style": "static",
		"default_speaker_name": "Sister Meris",
		"default_speaker_portrait": "res://Assets/Portraits/Sister Meris Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Sister Meris", "text": "You returned, {hero_name}. I... note it. Casual gratitude is an incredibly difficult language for me. This is my attempt."},
			{"speaker": "Sister Meris", "text": "I will pause painfully before admitting a fault. Not from pride alone, but from old training that severely punished hesitation and branded it virtue."},
			{"speaker": "Sister Meris", "text": "Forgiveness for my past cannot simply become another whip I use against myself. I am watching that internal boundary closely."},
			{"speaker": "Sister Meris", "text": "Mercy must be learned exactly as rigorously as my judgment once was. I am a remarkably slow student. But I am not an absent one."},
		],
	},
	{
		"id": "roster_solo_meris_partial_road",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Sister Meris",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_meris_long_pause",
		"portrait_style": "static",
		"default_speaker_name": "Sister Meris",
		"default_speaker_portrait": "res://Assets/Portraits/Sister Meris Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Sister Meris", "text": "A third conversation. Understand this: my redemption is not a weeping performance of softness. It is restraint, deeply chosen."},
			{"speaker": "Sister Meris", "text": "I am physically uncomfortable in moments of ease. That is entirely not your fault. Unclench. Do not shrink to accommodate my jagged habits."},
			{"speaker": "Sister Meris", "text": "I eagerly help where harsh discipline is needed. I am learning to help where genuine gentleness is needed. And to actually know the difference."},
			{"speaker": "Sister Meris", "text": "Walk this jagged road with me, {hero_name}. I can't promise perfection, but I promise I'll be exactly the friend you need at the end of it."},
		],
	},
	{
		"id": "roster_solo_corvin_honest_gloam",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Corvin Ash",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 20,
		"portrait_style": "static",
		"default_speaker_name": "Corvin Ash",
		"default_speaker_portrait": "res://Assets/Portraits/Corvin Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Corvin Ash", "text": "{hero_name}. Sit, if you like. Or stand. I find stillness highly educational either way."},
			{"speaker": "Corvin Ash", "text": "Forbidden knowledge does not care whether saints or tyrants open it. I would much rather fully understand the lock than pretend the door doesn't exist."},
			{"speaker": "Corvin Ash", "text": "I value truth over comfort. Nearly always. If that makes me fundamentally cold, please note that cold can be incredibly accurate."},
			{"speaker": "Corvin Ash", "text": "Ask your question plainly. I respond very poorly to fear disguised as poetry."},
		],
	},
	{
		"id": "roster_solo_corvin_cost_of_names",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Corvin Ash",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_corvin_honest_gloam",
		"portrait_style": "static",
		"default_speaker_name": "Corvin Ash",
		"default_speaker_portrait": "res://Assets/Portraits/Corvin Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Corvin Ash", "text": "You came back. Interesting. Most people prefer their mysteries strictly at arm's length. Yours seems considerably shorter."},
			{"speaker": "Corvin Ash", "text": "Curiosity aggressively seduces. I meticulously watch myself for the exact moment understanding becomes appetite without ethics."},
			{"speaker": "Corvin Ash", "text": "Ruin deeply fascinates me. So does repair. The boundary firmly between them is far thinner than sermons claim."},
			{"speaker": "Corvin Ash", "text": "If I suddenly go still, something dangerously hypocritical may be nearby. In the world, or in me. Either warrants intense attention."},
		],
	},
	{
		"id": "roster_solo_corvin_edge_dweller",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Corvin Ash",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_corvin_cost_of_names",
		"portrait_style": "static",
		"default_speaker_name": "Corvin Ash",
		"default_speaker_portrait": "res://Assets/Portraits/Corvin Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Corvin Ash", "text": "Third conversation, {hero_name}. Then a confession dressed fully as observation: I vastly underestimate how frightening I am. I will try to account for it."},
			{"speaker": "Corvin Ash", "text": "Extreme detachment is a tool and a hazard. If I drift too far, pull me forcefully toward consequence. Gently or not, as needed."},
			{"speaker": "Corvin Ash", "text": "Darkness utterly refuses to vanish just because you fear it. I live actively near it so it does not own me unexamined."},
			{"speaker": "Corvin Ash", "text": "If you truly want a companion at the edge, I will gladly meet you there. It turns out, sharing the drop with a friend actually changes the view entirely."},
		],
	},
	{
		"id": "roster_solo_veska_line_holds",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Veska Moor",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 21,
		"portrait_style": "static",
		"default_speaker_name": "Veska Moor",
		"default_speaker_portrait": "res://Assets/Portraits/Veska Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Veska Moor", "text": "{hero_name}. If you're here for flowery speeches, go to the campfire. If you're here to ask whether the line holds—I'm your primary answer."},
			{"speaker": "Veska Moor", "text": "I strictly trust what physically survives pressure. Walls. Endless drills. People who actually show up twice. Not pretty promises."},
			{"speaker": "Veska Moor", "text": "I am not graceful. I am painfully reliable. Pick one if you desperately need a label."},
			{"speaker": "Veska Moor", "text": "Sleep extremely light, work the palisade constantly, and stop pretending luck is a tactical plan. Done."},
		],
	},
	{
		"id": "roster_solo_veska_dry_measure",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Veska Moor",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_veska_line_holds",
		"portrait_style": "static",
		"default_speaker_name": "Veska Moor",
		"default_speaker_portrait": "res://Assets/Portraits/Veska Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Veska Moor", "text": "Back again, {hero_name}. Good. Aggressive consistency is a kind of courage. The deeply boring kind. I like it."},
			{"speaker": "Veska Moor", "text": "Care, consistently from me, looks like taking the hit you're entirely too small for. Don't call it noble. It is basic mass and math."},
			{"speaker": "Veska Moor", "text": "I relentlessly revise my judgments slow. Give me physical proof, not a dramatic performance."},
			{"speaker": "Veska Moor", "text": "I predictably carry too much sheer weight instead of talking. If you need words from me, ask plain. I'll answer plain."},
		],
	},
	{
		"id": "roster_solo_veska_plant_feet",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Veska Moor",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_veska_dry_measure",
		"portrait_style": "static",
		"default_speaker_name": "Veska Moor",
		"default_speaker_portrait": "res://Assets/Portraits/Veska Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Veska Moor", "text": "A third time. Then we are officially past idle curiosity, {hero_name}. Good. I vastly prefer concrete work over guessing."},
			{"speaker": "Veska Moor", "text": "Justice I can physically touch—hot food, dry shelter, a tightly closed gate—vastly beats justice you only hear about in bard songs."},
			{"speaker": "Veska Moor", "text": "Massive inflexibility is my primary flaw. If I dig my heels in wrong, shove me physically. I'll listen to force long before flattery."},
			{"speaker": "Veska Moor", "text": "Plant your feet hard when the world shoves. If you stumble, fall squarely behind mine. I’ll always catch you. That's a permanent offer to a friend."},
		],
	},
	{
		"id": "roster_solo_hadrien_borrowed_dawn",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Ser Hadrien",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 22,
		"portrait_style": "static",
		"default_speaker_name": "Ser Hadrien",
		"default_speaker_portrait": "res://Assets/Portraits/Ser Hadrien Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Ser Hadrien", "text": "{hero_name}. You need not physically flinch from me. I am merely memory with weight, not a crude tale told to frighten children."},
			{"speaker": "Ser Hadrien", "text": "I relentlessly wore an oath until it completely outlived its age. What remains is... unfinished. That is not poetry. It is heavy fact."},
			{"speaker": "Ser Hadrien", "text": "History is never a neat chapter heading to me. It is precisely what our screaming bodies paid. I can still clearly hear the tally."},
			{"speaker": "Ser Hadrien", "text": "Speak exceptionally plainly if you seek my counsel. I have very little patience for ornament. And infinitely less time than I appear to have."},
		],
	},
	{
		"id": "roster_solo_hadrien_memory_armor",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Ser Hadrien",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_hadrien_borrowed_dawn",
		"portrait_style": "static",
		"default_speaker_name": "Ser Hadrien",
		"default_speaker_portrait": "res://Assets/Portraits/Ser Hadrien Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Ser Hadrien", "text": "You returned, {hero_name}. The living remarkably often forget to return. I quietly mark it."},
			{"speaker": "Ser Hadrien", "text": "Grief, in my condition, is a very small signal. A prolonged pause. A static breath deeply held. Not loud theater."},
			{"speaker": "Ser Hadrien", "text": "Sacrifice can very easily become terrible idolatry. I constantly guard against loving the old wound significantly more than the new work."},
			{"speaker": "Ser Hadrien", "text": "I know I sometimes speak as though the dead have vastly more claim on me than you do. Correct that gently. I am... slowly learning."},
		],
	},
	{
		"id": "roster_solo_hadrien_unfinished_vigil",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Ser Hadrien",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_hadrien_memory_armor",
		"portrait_style": "static",
		"default_speaker_name": "Ser Hadrien",
		"default_speaker_portrait": "res://Assets/Portraits/Ser Hadrien Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Ser Hadrien", "text": "A third audience? Then hear this truth: I aggressively died for a massive cause once. Being patiently asked to live entirely beyond it... violently disorients me."},
			{"speaker": "Ser Hadrien", "text": "Duty with exactly zero survivors is purely vanity. I absolutely will not dress vanity as shining honor again."},
			{"speaker": "Ser Hadrien", "text": "Do not casually make a static relic of me. Make aggressive use of what I fiercely believed. For the living."},
			{"speaker": "Ser Hadrien", "text": "My ancient vigil ends when your future is secure. Guarding a friend's future is an oath I am profoundly grateful to finally understand."},
		],
	},
	{
		"id": "roster_solo_maela_thermal_up",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Maela Thorn",
		"min_max_unlocked_index": 2,
		"min_other_beats_seen": 23,
		"portrait_style": "static",
		"default_speaker_name": "Maela Thorn",
		"default_speaker_portrait": "res://Assets/Portraits/Maela Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Maela Thorn", "text": "{hero_name}! If you perfectly timed that entrance, bravo. If not, I'll confidently pretend you did. Looks significantly better on you."},
			{"speaker": "Maela Thorn", "text": "Freedom is constant motion, not a boring stamp on paper. I take mine high in the air and vigorously dare the ground to complain."},
			{"speaker": "Maela Thorn", "text": "Raw talent violently beats pedigree when pedigree stops to carefully polish its boots. We're in a massive hurry."},
			{"speaker": "Maela Thorn", "text": "If I'm loudly showing off, I'm probably intensely nervous. If I'm dead quiet, worry significantly more."},
		],
	},
	{
		"id": "roster_solo_maela_reckless_proof",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Maela Thorn",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_maela_thermal_up",
		"portrait_style": "static",
		"default_speaker_name": "Maela Thorn",
		"default_speaker_portrait": "res://Assets/Portraits/Maela Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Maela Thorn", "text": "Round two, {hero_name}. Still here? Good. Unyielding consistency is almost as impressively fast as me. Almost."},
			{"speaker": "Maela Thorn", "text": "Confidently dismiss me and watch the incredibly stupid risks I take to violently un-dismiss myself. Working on that. Slowly."},
			{"speaker": "Maela Thorn", "text": "Bravado is a heavy blanket. Warm, frequently obnoxious, and occasionally entirely on fire."},
			{"speaker": "Maela Thorn", "text": "After I massively screw up, I'm deeply honest. Sometimes too honest. Use it. I intensely hate being handled gently vastly more than I violently hate being wrong."},
		],
	},
	{
		"id": "roster_solo_maela_sky_rent",
		"beat_family": NARRATIVE_BEAT_FAMILY_ROSTER_SOLO,
		"solo_unit_name": "Maela Thorn",
		"min_max_unlocked_index": 2,
		"requires_seen_beat_id": "roster_solo_maela_reckless_proof",
		"portrait_style": "static",
		"default_speaker_name": "Maela Thorn",
		"default_speaker_portrait": "res://Assets/Portraits/Maela Portrait.png",
		"background": "res://Assets/Backgrounds/peaceful_village.jpeg",
		"lines": [
			{"speaker": "Maela Thorn", "text": "Third lap, {hero_name}. If you're rigorously keeping score, I'm definitively winning on sheer style points."},
			{"speaker": "Maela Thorn", "text": "I violently outrun casual expectations because standing perfectly still forcefully makes me wonder if I authentically earned my place."},
			{"speaker": "Maela Thorn", "text": "Rash impulse is absolutely my favorite vice and my notoriously worst strategist. Violently pull my sleeve when I'm about to forcefully prove a point with extreme altitude."},
			{"speaker": "Maela Thorn", "text": "The high sky is never casually granted, but flying alongside a true friend makes the terrifying drop entirely worth it. Race you to the clouds, {hero_name}!"},
		],
	},
]


func has_unlocked_forge_haldor_narrative_beat(max_unlocked_index: int) -> bool:
	return not get_unlocked_forge_haldor_beat_ids_ordered(max_unlocked_index, {}).is_empty()


func has_unlocked_haldor_solo_scene(max_unlocked_index: int) -> bool:
	return has_unlocked_forge_haldor_narrative_beat(max_unlocked_index)


func get_unlocked_forge_haldor_beat_ids_ordered(max_unlocked_index: int, seen_scene_ids: Dictionary = {}) -> Array:
	var out: Array = []
	for def_raw in narrative_beat_definitions:
		if not (def_raw is Dictionary):
			continue
		var def: Dictionary = def_raw as Dictionary
		if narrative_beat_family(def) != NARRATIVE_BEAT_FAMILY_HALDOR_FORGE:
			continue
		if not _narrative_beat_def_unlocked_for_player(def, max_unlocked_index, seen_scene_ids):
			continue
		var bid: String = str(def.get("id", "")).strip_edges()
		if bid != "":
			out.append(bid)
	return out


func get_unlocked_haldor_solo_scene_ids_ordered(max_unlocked_index: int, seen_scene_ids: Dictionary = {}) -> Array:
	return get_unlocked_forge_haldor_beat_ids_ordered(max_unlocked_index, seen_scene_ids)


func _narrative_beat_coerce_texture(value: Variant) -> Texture2D:
	if value is Texture2D:
		return value as Texture2D
	var s: String = str(value).strip_edges()
	if s.begins_with("res://") and ResourceLoader.exists(s):
		var res: Resource = load(s) as Resource
		if res is Texture2D:
			return res as Texture2D
	return null


func _narrative_beat_uses_haldor_mood_portraits(beat_def: Dictionary) -> bool:
	var ps: String = str(beat_def.get("portrait_style", "auto")).strip_edges().to_lower()
	if ps == "haldor_moods":
		return true
	if ps == "static":
		return false
	return str(beat_def.get("id", "")).strip_edges().begins_with("haldor_solo_")


func _narrative_beat_normalize_playback_line(row: Dictionary, beat_def: Dictionary) -> void:
	var def_speaker: String = str(beat_def.get("default_speaker_name", "")).strip_edges()
	if not row.has("speaker") or str(row.get("speaker", "")).strip_edges() == "":
		if def_speaker != "":
			row["speaker"] = def_speaker
		elif narrative_beat_family(beat_def) == NARRATIVE_BEAT_FAMILY_HALDOR_FORGE or _narrative_beat_uses_haldor_mood_portraits(beat_def):
			row["speaker"] = "Haldor"
		else:
			row["speaker"] = ""
	if not row.has("text"):
		row["text"] = ""
	var pl: Variant = row.get("portrait_left", null)
	var pl_tex: Texture2D = _narrative_beat_coerce_texture(pl)
	if pl_tex != null:
		row["portrait_left"] = pl_tex
	if not row.has("portrait_left") or row["portrait_left"] == null:
		if _narrative_beat_uses_haldor_mood_portraits(beat_def):
			_ensure_haldor_solo_art_loaded()
			var mood: String = str(row.get("haldor_expression", _haldor_solo_default_expression))
			row["portrait_left"] = _haldor_solo_portrait_for_expression(mood)
		else:
			var dp: Texture2D = _narrative_beat_coerce_texture(beat_def.get("default_speaker_portrait", null))
			if dp != null:
				row["portrait_left"] = dp
	var pr: Variant = row.get("portrait_right", "HERO_PORTRAIT")
	if pr is String and str(pr) == "HERO_PORTRAIT":
		row["portrait_right"] = "HERO_PORTRAIT"
	else:
		var pr_tex: Texture2D = _narrative_beat_coerce_texture(pr)
		if pr_tex != null:
			row["portrait_right"] = pr_tex
	if not row.has("background"):
		var bg_tex: Texture2D = _narrative_beat_coerce_texture(beat_def.get("background", null))
		if bg_tex != null:
			row["background"] = bg_tex
		else:
			if _narrative_beat_uses_haldor_mood_portraits(beat_def):
				_ensure_haldor_solo_art_loaded()
				row["background"] = _haldor_solo_bg_resolved
	if not row.has("music"):
		if narrative_beat_family(beat_def) == NARRATIVE_BEAT_FAMILY_HALDOR_FORGE:
			row["music"] = "haldor_solo"
		else:
			row["music"] = "peaceful"
	if not row.has("active_side"):
		row["active_side"] = "left"
	if not row.has("fit_background"):
		row["fit_background"] = false
	var pc: Variant = row.get("player_choice", null)
	if pc != null and pc is Dictionary:
		var react: Variant = (pc as Dictionary).get("reactions", null)
		if react is Dictionary:
			for rk in (react as Dictionary).keys():
				var arr: Variant = (react as Dictionary)[rk]
				if arr is Array:
					for i in range((arr as Array).size()):
						var item: Variant = (arr as Array)[i]
						if item is Dictionary:
							_narrative_beat_normalize_playback_line(item as Dictionary, beat_def)


func get_narrative_beat_playback_lines(beat_id: String) -> Array[Dictionary]:
	var sid: String = str(beat_id).strip_edges()
	var beat_def: Dictionary = {}
	var lines_src: Array = []
	for def_raw in narrative_beat_definitions:
		if not (def_raw is Dictionary):
			continue
		var def: Dictionary = def_raw as Dictionary
		if str(def.get("id", "")).strip_edges() != sid:
			continue
		beat_def = def
		var raw_lines: Variant = def.get("lines", [])
		if raw_lines is Array:
			lines_src = raw_lines as Array
		break
	if _narrative_beat_uses_haldor_mood_portraits(beat_def):
		_ensure_haldor_solo_art_loaded()
	var built: Array[Dictionary] = []
	for row_raw in lines_src:
		if not (row_raw is Dictionary):
			continue
		var row: Dictionary = (row_raw as Dictionary).duplicate(true)
		_narrative_beat_normalize_playback_line(row, beat_def)
		built.append(row)
	return built


func get_haldor_solo_playback_lines(scene_id: String) -> Array[Dictionary]:
	return get_narrative_beat_playback_lines(scene_id)


## Optional per-beat gifts on completion (see [member CampaignManager.try_grant_narrative_beat_rewards]). Each reward: [code]item_path[/code], [code]amount[/code], [code]toast[/code].
func get_narrative_beat_reward_entries(beat_id: String) -> Array:
	var sid: String = str(beat_id).strip_edges()
	for def_raw in narrative_beat_definitions:
		if not (def_raw is Dictionary):
			continue
		var def: Dictionary = def_raw as Dictionary
		if str(def.get("id", "")).strip_edges() != sid:
			continue
		var raw: Variant = def.get("rewards", [])
		if not (raw is Array):
			return []
		var fam: String = narrative_beat_family(def)
		var beat_toast: String = str(def.get("default_reward_toast", "")).strip_edges()
		var fallback_toast: String = "From Haldor" if fam == NARRATIVE_BEAT_FAMILY_HALDOR_FORGE else "Received"
		var out: Array = []
		for spec_raw in raw as Array:
			if not (spec_raw is Dictionary):
				continue
			var spec: Dictionary = (spec_raw as Dictionary).duplicate(true)
			var t: String = str(spec.get("toast", "")).strip_edges()
			if t == "":
				spec["toast"] = beat_toast if beat_toast != "" else fallback_toast
			out.append(spec)
		return out
	return []


func get_haldor_solo_reward_entries(scene_id: String) -> Array:
	return get_narrative_beat_reward_entries(scene_id)
