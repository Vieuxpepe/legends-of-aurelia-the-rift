# CampExploreDialogueDB.gd
# Data-only camp exploration dialogue: personality-keyed short lines for roster members.
# CampExplore.gd uses this for talk interactions. Use get_line(personality) or get_line_for_unit(unit_data, unit_name).
#
# Personality priority: UnitData.support_personality -> NAME_TO_PERSONALITY[unit_name] -> "neutral".

class_name CampExploreDialogueDB

const DEFAULT_LINE: String = "Good to see you."

## Fallback: unit display name -> personality key when UnitData has no support_personality.
const NAME_TO_PERSONALITY: Dictionary = {
	"Commander": "heroic",
	"Kaelen": "stoic",
	"Branik": "warm",
	"Liora": "compassionate",
	"Nyx": "sly",
	"Sorrel": "scholarly",
	"Darian": "flamboyant",
	"Celia": "disciplined",
	"Rufus": "pragmatic",
	"Inez": "wild",
	"Tariq": "sardonic",
	"Mira Ashdown": "heroic",
	"Pell Rowan": "earnest",
	"Tamsin Reed": "compassionate",
	"Hest \"Sparks\"": "chaotic",
	"Brother Alden": "devout",
	"Oren Pike": "pragmatic",
	"Garrick Vale": "disciplined",
	"Sabine Varr": "severe",
	"Yselle Maris": "flamboyant",
	"Sister Meris": "severe",
	"Corvin Ash": "occult",
	"Veska Moor": "stoic",
	"Ser Hadrien": "haunted",
	"Maela Thorn": "spirited",
}

## Camp lines by personality key. One short line per interaction; pick randomly.
const CAMP_LINES: Dictionary = {
	"heroic": [
		"Ready when you are, Commander.",
		"Rest now. We fight again soon.",
		"The camp's in good hands.",
	],
	"stoic": [
		"…",
		"Need something?",
		"All quiet.",
	],
	"warm": [
		"Good to see you.",
		"Come by anytime.",
		"Stay safe out there.",
	],
	"compassionate": [
		"Take care of yourself.",
		"If you need to talk, I'm here.",
		"Rest well.",
	],
	"sly": [
		"Keeping an eye on things.",
		"Don't mind me.",
		"Interesting company we keep.",
	],
	"scholarly": [
		"Fascinating place, this camp.",
		"Observations ongoing.",
		"Perhaps we can compare notes later.",
	],
	"flamboyant": [
		"The camp wouldn't be the same without me.",
		"Enjoying the atmosphere.",
		"Always a pleasure.",
	],
	"disciplined": [
		"Standing ready.",
		"Discipline holds.",
		"At ease.",
	],
	"pragmatic": [
		"Efficient use of downtime.",
		"Rest. We'll need it.",
		"Nothing to report.",
	],
	"wild": [
		"Can't sit still for long.",
		"Ready to move when you are.",
		"Camp's too quiet.",
	],
	"sardonic": [
		"Charming as ever.",
		"Don't let me keep you.",
		"Surviving. You?",
	],
	"earnest": [
		"Glad you're here.",
		"We'll get through this.",
		"Thanks for checking in.",
	],
	"chaotic": [
		"Who knows what's next?",
		"Fun times.",
		"Something's always happening.",
	],
	"devout": [
		"Peace be with you.",
		"The path continues.",
		"Blessings on the road ahead.",
	],
	"severe": [
		"State your business.",
		"Be brief.",
		"… Yes?",
	],
	"occult": [
		"The veil is thin here.",
		"… You feel it too.",
		"Rest. The unknown waits.",
	],
	"haunted": [
		"… Sorry. Lost in thought.",
		"Some days are harder.",
		"I'm here.",
	],
	"spirited": [
		"Hey! Good to see you.",
		"Don't work too hard.",
		"Camp's looking good.",
	],
	"neutral": [
		"Good to see you.",
		"Need something?",
		"Take care.",
	],
}

## Returns one short camp line for the given personality key. Falls back to DEFAULT_LINE if missing.
static func get_line(personality: String) -> String:
	var key: String = str(personality).strip_edges().to_lower()
	if key.is_empty():
		key = "neutral"
	var lines: Variant = CAMP_LINES.get(key, null)
	if lines == null or not (lines is Array) or lines.is_empty():
		lines = CAMP_LINES.get("neutral", [])
	if lines == null or not (lines is Array) or lines.is_empty():
		return DEFAULT_LINE
	var chosen: String = str((lines as Array).pick_random()).strip_edges()
	return chosen if not chosen.is_empty() else DEFAULT_LINE

## Resolves personality from unit: support_personality on data, else NAME_TO_PERSONALITY[name], else "neutral".
static func get_personality_for_unit(unit_data: Variant, unit_name: String) -> String:
	# Only Resource and Dictionary have get(); unit_data can be String after save/load (e.g. path).
	if unit_data != null and not (unit_data is String):
		var p: Variant = unit_data.get("support_personality")
		if p != null:
			var ps: String = str(p).strip_edges()
			if not ps.is_empty():
				return ps.to_lower()
	var name_key: String = str(unit_name).strip_edges()
	if name_key.is_empty():
		return "neutral"
	var fallback: Variant = NAME_TO_PERSONALITY.get(name_key, null)
	if fallback != null:
		return str(fallback).strip_edges().to_lower()
	return "neutral"

## Returns one short camp line for the unit (uses personality lookup). Safe if unit_data is null.
static func get_line_for_unit(unit_data: Variant, unit_name: String) -> String:
	var personality: String = get_personality_for_unit(unit_data, unit_name)
	return get_line(personality)
