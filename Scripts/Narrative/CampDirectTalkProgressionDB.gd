# CampDirectTalkProgressionDB.gd
# Stage-aware followups appended to generic idle direct talk (CampExploreDialogueDB baseline).
# Reads personal_arc_stage from CampaignManager avatar relationship entry.

class_name CampDirectTalkProgressionDB

## unit_display_name -> stage_int -> short followup (no biography dumps)
const IDLE_FOLLOWUP_BY_UNIT: Dictionary = {
	"Nyx": {
		1: "…I'm still here. That's not temporary—don't make me regret saying it out loud.",
		2: "If you're counting exits again—count me toward the wall, not the door.",
	},
	"Branik": {
		1: "You look steadier than last week. I'll take that as the camp doing its job.",
		2: "Eat. Then argue with the world. I've stopped being subtle about caring—deal with it.",
	},
	"Sorrel": {
		1: "If you want my read on something murky, ask before the rumor hardens into gospel.",
		2: "I'll share the interpretation when it costs fewer lives than the silence would.",
	},
	"Tamsin Reed": {
		1: "I'm not hiding that I'm tired anymore—I'm just still working anyway.",
		2: "If I hit a limit tonight, I'll say it plain. Borrow someone else's heroics if I do.",
	},
	"Celia": {
		1: "I'm practicing the small version of right—not the loud one that looks like penance.",
		2: "Watch if you need to. I'm not borrowing shame to prove I'm serious.",
	},
	"Garrick Vale": {
		1: "The line's holding habits I'd trust without me hovering—good.",
		2: "I'll back sergeants' calls when the mud disagrees with the manual. That's not weakness.",
	},
}


static func get_idle_followup(unit_name: String) -> String:
	var un: String = str(unit_name).strip_edges()
	if un.is_empty() or not CampaignManager:
		return ""
	var stage: int = CampaignManager.get_personal_arc_stage(un)
	if stage <= 0:
		return ""
	var by_unit: Variant = IDLE_FOLLOWUP_BY_UNIT.get(un, null)
	if not (by_unit is Dictionary):
		return ""
	var line_v: Variant = (by_unit as Dictionary).get(stage, "")
	var line: String = str(line_v).strip_edges()
	return line
