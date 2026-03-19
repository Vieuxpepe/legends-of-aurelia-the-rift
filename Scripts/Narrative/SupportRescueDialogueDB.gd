# SupportRescueDialogueDB.gd
# Data-only rescue lines for Defy Death: personality-keyed, short battlefield barks spoken by the SAVIOR.
# BattleField.gd triggers and displays; this file is content-only. Use get_line(personality, saved_name).

class_name SupportRescueDialogueDB

const DEFAULT_RESCUE_LINE: String = "I won't let you fall!"
const PLACEHOLDER_SAVED: String = "{saved}"

## Rescue lines by support_personality key. Each entry: array of 1–3 short lines; use {saved} for victim name.
const RESCUE_LINES: Dictionary = {
	"heroic": [
		"Not today!",
		"Get up, {saved}. We're not done.",
		"I've got you.",
		"Stay with me!",
	],
	"stoic": [
		"On your feet.",
		"Not here. Not like this.",
		"Up, {saved}.",
		"Move.",
	],
	"warm": [
		"I've got you. Breathe.",
		"Don't you dare leave yet, {saved}.",
		"You're alright. I'm here.",
		"Hold on.",
	],
	"compassionate": [
		"You're safe. I promise.",
		"Please stay with us, {saved}.",
		"I won't lose you.",
		"Hold on. I'm right here.",
	],
	"sly": [
		"Didn't think I'd let you have the glory of dying first.",
		"Up. You owe me one, {saved}.",
		"Nice try. We're not done.",
		"Consider that a favor.",
	],
	"scholarly": [
		"Statistical anomaly in your favor. Get up.",
		"Fascinating. You're still needed, {saved}.",
		"Recalibrating. You live.",
		"The data suggests you stand.",
	],
	"flamboyant": [
		"And the crowd holds its breath — but not you, {saved}. Rise.",
		"Dramatic exit denied. On your feet.",
		"I refuse to let this be your final act.",
		"Up. The show isn't over.",
	],
	"disciplined": [
		"Stand. That's an order.",
		"On your feet, soldier.",
		"Regroup, {saved}. Now.",
		"No. We do not fall here.",
	],
	"pragmatic": [
		"We need you. Get up.",
		"Can't afford to lose you yet, {saved}.",
		"Up. No time for this.",
		"Efficient exit denied. Move.",
	],
	"wild": [
		"Not yet! We're not done!",
		"Get up, {saved}! Fight!",
		"Nobody dies on my watch!",
		"Rise! Now!",
	],
	"sardonic": [
		"Congratulations. You're still inconveniently alive.",
		"Get up, {saved}. Your martyrdom is postponed.",
		"Death can wait. I said so.",
		"Alas. You'll have to suffer longer.",
	],
	"earnest": [
		"I won't let you down, {saved}!",
		"Get up! We need you!",
		"You're not done yet. I believe in you.",
		"Stay with us. Please.",
	],
	"chaotic": [
		"Nope! Not allowed! Up!",
		"Ha! Death said no today, {saved}!",
		"Random chance says you live. Go.",
		"Plot twist: you're fine. Get up.",
	],
	"devout": [
		"By grace, you are spared. Rise, {saved}.",
		"The path is not finished. Stand.",
		"You are not forsaken. Get up.",
		"Mercy today. On your feet.",
	],
	"severe": [
		"On your feet. Now.",
		"Stand, {saved}. We are not finished.",
		"I did not permit you to fall.",
		"Up. No further discussion.",
	],
	"occult": [
		"The veil holds. Rise, {saved}.",
		"Not your hour. Stand.",
		"Something else agrees: you stay.",
		"Get up. The balance says so.",
	],
	"haunted": [
		"Not again. Get up.",
		"I won't watch another fall, {saved}.",
		"Stand. I need you to stand.",
		"Up. Please.",
	],
	"spirited": [
		"Hey! No dying on me, {saved}!",
		"Up, up! We've got this!",
		"Nope! You're staying right here!",
		"Get up! There's still fight left!",
	],
}

## Returns one rescue line for the given personality; replaces {saved} with saved_name. Falls back to DEFAULT_RESCUE_LINE if personality missing or empty.
static func get_line(personality: String, saved_name: String) -> String:
	var key: String = str(personality).strip_edges().to_lower()
	if key.is_empty():
		return DEFAULT_RESCUE_LINE
	var lines: Variant = RESCUE_LINES.get(key, null)
	if lines == null or not (lines is Array) or lines.is_empty():
		return DEFAULT_RESCUE_LINE
	var chosen: String = str(lines.pick_random()).strip_edges()
	if chosen.is_empty():
		return DEFAULT_RESCUE_LINE
	return chosen.replace(PLACEHOLDER_SAVED, saved_name)
