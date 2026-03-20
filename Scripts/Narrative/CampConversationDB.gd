# CampConversationDB.gd
# Authored multi-line direct (E) camp conversations with optional branching.
# Memory: once_ever -> CampaignManager.mark_camp_memory_scene_seen(id)
#         once_per_visit -> CampDialogueController visit dictionary (checked here via player_state)

class_name CampConversationDB
extends RefCounted

const TIER_ORDER: PackedStringArray = ["stranger", "known", "trusted", "close", "bonded"]

const CONVERSATIONS: Array = [
	{
		"id": "dc_camp_avatar_kaelen_1",
		"primary_unit": "Kaelen",
		"participants": ["Kaelen", "Commander"],
		"conversation_type": "support",
		"priority": 22,
		"req_level": 2,
		"once_ever": true,
		"branch_at": 4,
		"script": [
			{"speaker": "Kaelen", "text": "You kept looking back through Emberwood. At the fire, at the smoke... at ghosts that were already gone."},
			{"speaker": "Commander", "text": "There were still people in that village."},
			{"speaker": "Kaelen", "text": "I know. That's why I dragged you forward. One dead hero in the ashes helps no one."},
			{"speaker": "Commander", "text": "You say that like it's easy."},
			{"speaker": "Kaelen", "text": "It isn't. It's just necessary. So answer me straight, Commander: do you want comfort, or do you want to live long enough to matter?"},
		],
		"choices": [
			{
				"text": "Teach me survival.",
				"result": "success",
				"response": [
					{"speaker": "Kaelen", "text": "Good. Then first lesson: grief waits its turn. Breathing comes first."},
					{"speaker": "Kaelen", "text": "You'll hate me for saying it now, but one day you'll give the same order to someone else."},
					{"speaker": "Commander", "text": "And if I do?"},
					{"speaker": "Kaelen", "text": "Then I'll know you learned the part that keeps people alive."},
				],
				"effects": {"add_avatar_relationship": 2},
			},
			{
				"text": "I won't leave them.",
				"result": "fail",
				"response": [
					{"speaker": "Kaelen", "text": "That's a noble answer. Noble answers get graves dug all over Aurelia."},
					{"speaker": "Commander", "text": "Maybe. But I won't survive this by becoming empty."},
					{"speaker": "Kaelen", "text": "...No. And for what it's worth, that's not the worst flaw a commander can carry."},
				],
				"effects": {"add_avatar_relationship": 1},
			},
		],
	},
	{
		"id": "dc_camp_avatar_kaelen_2",
		"primary_unit": "Kaelen",
		"participants": ["Kaelen", "Commander"],
		"conversation_type": "support",
		"priority": 21,
		"req_level": 6,
		"once_ever": true,
		"branch_at": 5,
		"script": [
			{"speaker": "Kaelen", "text": "You've been pacing the walls of Greyspire every night since we took it."},
			{"speaker": "Commander", "text": "It doesn't feel won. Not yet. More like we asked the dead to make room."},
			{"speaker": "Kaelen", "text": "That's the right feeling, unfortunately. Fortresses remember. Especially this one."},
			{"speaker": "Commander", "text": "And you? Every room here seems to know your name before I do."},
			{"speaker": "Kaelen", "text": "Aye. Most of them remember me younger and dumber."},
			{"speaker": "Kaelen", "text": "So tell me, Commander. When you look at Greyspire, do you see a graveyard... or the first place this army can call home?"},
		],
		"choices": [
			{
				"text": "We'll make it home.",
				"result": "success",
				"response": [
					{"speaker": "Commander", "text": "A graveyard can still shelter the living. We build something better on top of what was lost."},
					{"speaker": "Kaelen", "text": "...That's a harder answer than hope, and a better one."},
					{"speaker": "Kaelen", "text": "Good. Keep thinking like that and these walls may yet deserve the people sleeping inside them."},
					{"speaker": "Commander", "text": "You sound relieved."},
					{"speaker": "Kaelen", "text": "Maybe I am. For the first time since Oakhaven, I can almost picture you lasting."},
				],
				"effects": {"add_avatar_relationship": 2},
			},
			{
				"text": "It's still haunted.",
				"result": "fail",
				"response": [
					{"speaker": "Commander", "text": "Home shouldn't feel this heavy."},
					{"speaker": "Kaelen", "text": "No. But sometimes heavy is the best the world offers."},
					{"speaker": "Kaelen", "text": "Stay long enough, and you'll learn most shelters are built out of someone else's ruin."},
					{"speaker": "Commander", "text": "That supposed to be comforting?"},
					{"speaker": "Kaelen", "text": "Not even slightly. Just true."},
				],
				"effects": {"add_avatar_relationship": 1},
			},
		],
	},
	{
		"id": "dc_camp_avatar_liora_1",
		"primary_unit": "Liora",
		"participants": ["Liora", "Commander"],
		"conversation_type": "support",
		"priority": 22,
		"req_level": 3,
		"once_ever": true,
		"branch_at": 5,
		"script": [
			{"speaker": "Liora", "text": "I meant to thank you properly for the sanctum... but every time I begin, the words sound too small."},
			{"speaker": "Commander", "text": "You don't owe me a speech. We got out. That's enough."},
			{"speaker": "Liora", "text": "It isn't, not to me. You walked into a collapsing temple for someone you barely knew."},
			{"speaker": "Commander", "text": "You were trapped. That was reason enough."},
			{"speaker": "Liora", "text": "Perhaps. But when Ephrem looked at you, it was not as a person. It was as a sign, a danger, a thing to be judged."},
			{"speaker": "Liora", "text": "Tell me honestly, Commander... when people stare at the Mark, what do you wish they would see?"},
		],
		"choices": [
			{
				"text": "Just me.",
				"result": "success",
				"response": [
					{"speaker": "Commander", "text": "Just me. Not a prophecy. Not a threat. Just the person standing here."},
					{"speaker": "Liora", "text": "...Then I will try very hard to be one of the people who remembers that."},
					{"speaker": "Liora", "text": "The world may insist on symbols. I do not have to follow its example."},
					{"speaker": "Commander", "text": "That's more thanks than I needed."},
					{"speaker": "Liora", "text": "Then forgive me. I intend to keep giving it anyway."},
				],
				"effects": {"add_avatar_relationship": 2},
			},
			{
				"text": "A weapon, maybe.",
				"result": "fail",
				"response": [
					{"speaker": "Liora", "text": "Do not say that so lightly."},
					{"speaker": "Commander", "text": "It isn't light. Just useful. People understand weapons."},
					{"speaker": "Liora", "text": "They understand how to fear them, command them, and spend them. That is not the same as seeing you."},
					{"speaker": "Liora", "text": "I would rather argue with you for years than watch you become something easier for them to name."},
				],
				"effects": {"add_avatar_relationship": 1},
			},
		],
	},
	{
		"id": "dc_camp_avatar_liora_2",
		"primary_unit": "Liora",
		"participants": ["Liora", "Commander"],
		"conversation_type": "support",
		"priority": 21,
		"req_level": 10,
		"once_ever": true,
		"branch_at": 5,
		"script": [
			{"speaker": "Liora", "text": "During the Sunlit Trial, when they sealed the gates and lit the outer ring... I thought Valeron had decided to burn you alive in front of its own faithful."},
			{"speaker": "Commander", "text": "You looked like you wanted to climb into the arena yourself."},
			{"speaker": "Liora", "text": "I did. For one very undignified moment, I considered it."},
			{"speaker": "Commander", "text": "That would've been a terrible plan."},
			{"speaker": "Liora", "text": "Yes. A terrible, earnest, heartfelt plan."},
			{"speaker": "Liora", "text": "When you stood there beneath all that judgment, I realized something that frightens me, Commander: I do not merely believe in your cause anymore. I am frightened for you personally."},
		],
		"choices": [
			{
				"text": "You kept me steady.",
				"result": "success",
				"response": [
					{"speaker": "Commander", "text": "Then know this: when the crowd wanted a symbol, I kept hearing your voice telling me I was still a person."},
					{"speaker": "Liora", "text": "...You should not say things like that when I am trying to remain composed."},
					{"speaker": "Commander", "text": "Was that composure?"},
					{"speaker": "Liora", "text": "Barely. But perhaps that is what steadiness is—remaining upright while your heart misbehaves."},
					{"speaker": "Commander", "text": "Then we managed it together."},
				],
				"effects": {"add_avatar_relationship": 2},
			},
			{
				"text": "I had to endure.",
				"result": "fail",
				"response": [
					{"speaker": "Commander", "text": "There wasn't time to think about anything but surviving."},
					{"speaker": "Liora", "text": "No... but survival is not a small thing."},
					{"speaker": "Liora", "text": "Forgive me. I keep trying to speak like a priestess when what I mean is much simpler."},
					{"speaker": "Liora", "text": "I was afraid to lose you. There. That was the honest version."},
				],
				"effects": {"add_avatar_relationship": 1},
			},
		],
	},
	{
		"id": "dc_camp_avatar_ser_hadrien_1",
		"primary_unit": "Ser Hadrien",
		"participants": ["Ser Hadrien", "Commander"],
		"conversation_type": "support",
		"priority": 20,
		"req_level": 16,
		"once_ever": true,
		"branch_at": 6,
		"script": [
			{"speaker": "Ser Hadrien", "text": "You carry the Veilbreaker like someone expecting it to accuse you."},
			{"speaker": "Commander", "text": "It came out of a vault built by people who believed my existence should end in sacrifice. I think a little suspicion is fair."},
			{"speaker": "Ser Hadrien", "text": "Fair, yes. But incomplete."},
			{"speaker": "Commander", "text": "You were one of them."},
			{"speaker": "Ser Hadrien", "text": "I was. Which is why I can tell you this plainly: the Order feared what the Mark could become, but it feared even more what the world would become if no bearer ever rose worthy of choosing."},
			{"speaker": "Commander", "text": "That sounds dangerously close to destiny."},
			{"speaker": "Ser Hadrien", "text": "No. Destiny is what institutions call it when they want obedience without guilt. I mean burden. The less flattering word."},
		],
		"choices": [
			{
				"text": "I never asked for it.",
				"result": "success",
				"response": [
					{"speaker": "Commander", "text": "I never asked for any of this."},
					{"speaker": "Ser Hadrien", "text": "No worthy bearer ever does."},
					{"speaker": "Commander", "text": "That is not comforting."},
					{"speaker": "Ser Hadrien", "text": "Comfort is a poor companion for truth. But hear this: the dead do not ask you to be willing. Only honest."},
					{"speaker": "Commander", "text": "...And if honesty tells me I am afraid?"},
					{"speaker": "Ser Hadrien", "text": "Then you are still human. The Order should have treasured that more carefully than it did."},
				],
				"effects": {"add_avatar_relationship": 2},
			},
			{
				"text": "Then the Order was wrong.",
				"result": "fail",
				"response": [
					{"speaker": "Ser Hadrien", "text": "Often. But not always in the same place."},
					{"speaker": "Commander", "text": "That sounds like a knight's answer."},
					{"speaker": "Ser Hadrien", "text": "It is a dead man's answer. More difficult to polish, sadly."},
					{"speaker": "Commander", "text": "...I still don't know whether to trust your ghosts."},
				],
				"effects": {"add_avatar_relationship": 1},
			},
		],
	},
	{
		"id": "dc_camp_liora_scholar_checkin",
		"primary_unit": "Liora",
		"participants": ["Liora", "Sorrel"],
		"conversation_type": "camp_depth",
		"priority": 14,
		"req_level": 6,
		"once_per_visit": true,
		"requires_units_present": ["Sorrel"],
		"preferred_visit_themes": ["normal", "hopeful", "recovery"],
		"script": [
			{"speaker": "Liora", "text": "You've spent nights in the archive again. Even here, I can see the ink on your sleeves."},
			{"speaker": "Sorrel", "text": "Paper is quieter than camp rumor. Barely."},
			{"speaker": "Liora", "text": "Quiet is not the same as safe. Sit. Drink. Argue with me if you must—only do it where someone can catch you if you sway."},
			{"speaker": "Sorrel", "text": "...You make rest sound like a tactical order."},
			{"speaker": "Liora", "text": "It is. The line holds better when the archivist is upright."},
		],
		"effects_on_complete": {"add_avatar_relationship": 1},
	},
]


static func get_all_conversations() -> Array:
	return CONVERSATIONS.duplicate()


static func _normalize_name(s: String) -> String:
	return str(s).strip_edges()


static func _tier_index(tier: String) -> int:
	var t: String = str(tier).strip_edges().to_lower()
	var i: int = TIER_ORDER.find(t)
	return i if i >= 0 else 0


static func tier_at_least(current_tier: String, minimum_tier: String) -> bool:
	var mt: String = str(minimum_tier).strip_edges().to_lower()
	if mt == "":
		return true
	return _tier_index(current_tier) >= _tier_index(mt)


static func when_matches(entry: Dictionary, context: Dictionary) -> bool:
	var when_v: Variant = entry.get("when", {})
	if when_v is Dictionary:
		var tb: String = str((when_v as Dictionary).get("time_block", "")).strip_edges().to_lower()
		if tb != "":
			var ctx_tb: String = str(context.get("time_block", "")).strip_edges().to_lower()
			if ctx_tb != tb:
				return false
	return true


static func conversation_matches(
	entry: Dictionary,
	primary_unit: String,
	context: Dictionary,
	walker_names: Array,
	player_state: Dictionary
) -> bool:
	var pu: String = _normalize_name(entry.get("primary_unit", ""))
	if pu == "" or _normalize_name(primary_unit) != pu:
		return false
	var script_v: Variant = entry.get("script", [])
	if not (script_v is Array) or (script_v as Array).is_empty():
		return false
	if not when_matches(entry, context):
		return false
	var prog: int = maxi(0, int(context.get("progress_level", 0)))
	var req_lv: int = int(entry.get("req_level", 0))
	if prog < req_lv:
		return false
	var max_lv: int = int(entry.get("max_progress_level", -1))
	if max_lv >= 0 and prog > max_lv:
		return false
	if entry.has("moods"):
		var moods_v: Variant = entry.get("moods", [])
		if moods_v is Array:
			var cm: String = str(context.get("camp_mood", "normal")).strip_edges().to_lower()
			var ok_m: bool = false
			for m in moods_v as Array:
				if str(m).strip_edges().to_lower() == cm:
					ok_m = true
					break
			if not ok_m:
				return false
	var vt: String = str(context.get("visit_theme", "normal")).strip_edges().to_lower()
	if entry.has("preferred_visit_themes"):
		var pv: Variant = entry.get("preferred_visit_themes", [])
		if pv is Array and (pv as Array).size() > 0:
			var hit: bool = false
			for item in pv as Array:
				if str(item).strip_edges().to_lower() == vt:
					hit = true
					break
			if not hit:
				return false
	if entry.has("avoided_visit_themes"):
		var av: Variant = entry.get("avoided_visit_themes", [])
		if av is Array:
			for item2 in av as Array:
				if str(item2).strip_edges().to_lower() == vt:
					return false
	var req_names: Variant = entry.get("requires_units_present", [])
	if req_names is Array:
		var lowered: Dictionary = {}
		for n in walker_names:
			lowered[_normalize_name(str(n)).to_lower()] = true
		for req in req_names as Array:
			var rn: String = _normalize_name(str(req)).to_lower()
			if rn == "":
				continue
			if rn == "commander":
				continue
			if not lowered.has(rn):
				return false
	var min_tier: String = str(entry.get("req_min_relationship_tier", "")).strip_edges()
	if min_tier != "" and CampaignManager:
		var cur: String = CampaignManager.get_avatar_relationship_tier(pu)
		if not tier_at_least(cur, min_tier):
			return false
	var req_tiers_v: Variant = entry.get("req_relationship_tiers", [])
	if req_tiers_v is Array and (req_tiers_v as Array).size() > 0 and CampaignManager:
		var cur2: String = CampaignManager.get_avatar_relationship_tier(pu)
		var allowed: bool = false
		for t in req_tiers_v as Array:
			if str(t).strip_edges().to_lower() == cur2:
				allowed = true
				break
		if not allowed:
			return false
	var eid: String = _normalize_name(entry.get("id", ""))
	if bool(entry.get("once_ever", false)) and CampaignManager and eid != "":
		if CampaignManager.has_seen_camp_memory_scene(eid):
			return false
	if bool(entry.get("once_per_visit", false)):
		var vc_raw: Variant = player_state.get("visit_consumed", {})
		var consumed: Dictionary = vc_raw if vc_raw is Dictionary else {}
		if bool(consumed.get(eid, false)):
			return false
	return true


static func score_conversation(entry: Dictionary, context: Dictionary) -> float:
	var p: float = float(entry.get("priority", 0))
	var vt: String = str(context.get("visit_theme", "normal")).strip_edges().to_lower()
	if entry.has("preferred_visit_themes"):
		var pv2: Variant = entry.get("preferred_visit_themes", [])
		if pv2 is Array:
			for it in pv2 as Array:
				if str(it).strip_edges().to_lower() == vt:
					p += 1.25
					break
	return p


static func get_best_direct_conversation(
	unit_name: String,
	context: Dictionary,
	walker_names: Array,
	player_state: Dictionary
) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -1e12
	for raw in CONVERSATIONS:
		if not (raw is Dictionary):
			continue
		var e: Dictionary = raw
		if not conversation_matches(e, unit_name, context, walker_names, player_state):
			continue
		var sc: float = score_conversation(e, context)
		var eid2: String = _normalize_name(e.get("id", ""))
		if sc > best_score or (absf(sc - best_score) < 0.001 and eid2 < _normalize_name(best.get("id", "zzz"))):
			best_score = sc
			best = e
	return best


static func has_eligible_direct_conversation(
	unit_name: String,
	context: Dictionary,
	walker_names: Array,
	player_state: Dictionary
) -> bool:
	return not get_best_direct_conversation(unit_name, context, walker_names, player_state).is_empty()
