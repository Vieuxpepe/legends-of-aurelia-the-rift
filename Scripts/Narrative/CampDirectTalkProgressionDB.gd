# CampDirectTalkProgressionDB.gd
# Stage-aware followups appended to generic idle direct talk (CampExploreDialogueDB baseline).
# Reads personal_arc_stage from CampaignManager avatar relationship entry.

class_name CampDirectTalkProgressionDB

## unit_display_name -> stage_int -> short followup (no biography dumps)
const IDLE_FOLLOWUP_BY_UNIT: Dictionary = {
	"Nyx": {
		1: "…I'm still here. That's not temporary—don't make me regret saying it out loud.",
		2: "If you're counting exits again—count me toward the wall, not the door.",
		3: "Slate still has my name—I check it like habit, not like I'm hunting a way out anymore.",
	},
	"Branik": {
		1: "You look steadier than last week. I'll take that as the camp doing its job.",
		2: "Eat. Then argue with the world. I've stopped being subtle about caring—deal with it.",
		3: "If I'm pushing bread again, it's the same rule as the larder: honesty in the pot, not theater in your stomach.",
	},
	"Sorrel": {
		1: "If you want my read on something murky, ask before the rumor hardens into gospel.",
		2: "I'll share the interpretation when it costs fewer lives than the silence would.",
		3: "I'll bring the ugly reading early now—before camp does it for me with adjectives and casualties.",
	},
	"Tamsin Reed": {
		1: "I'm not hiding that I'm tired anymore—I'm just still working anyway.",
		2: "If I hit a limit tonight, I'll say it plain. Borrow someone else's heroics if I do.",
		3: "I'm naming the ceiling before I hit it—if I go quiet, it's triage, not a mystery.",
	},
	"Celia": {
		1: "I'm practicing the small version of right—not the loud one that looks like penance.",
		2: "Watch if you need to. I'm not borrowing shame to prove I'm serious.",
		3: "If you see me slip into performance, say 'boring'—I'll take the small rep over the bruise-as-proof habit.",
	},
	"Garrick Vale": {
		1: "The line's holding habits I'd trust without me hovering—good.",
		2: "I'll back sergeants' calls when the mud disagrees with the manual. That's not weakness.",
		3: "Notes from last shift are plain—distributed judgment isn't me gone; it's me not treating every call like it's rented.",
	},
	"Brother Alden": {
		1: "I saw you drink water without performing martyrdom. Keep that; fevers love a commander who forgets the basics.",
		2: "Pulse before pageant, still—if you parade a patient for morale, I'll look bored on purpose again.",
		3: "Mercy moved into my hands before my mouth remembered how to argue—water, shade, quiet cots; the tent learns habit faster than lecture now.",
	},
	"Yselle Maris": {
		1: "I'm practicing calm as labor, not as costume—if the line borrows my face, it's because panic spreads faster than hunger.",
		2: "Armor still goes on before dawn—I'm just not pretending the weight is nothing when we're alone with the cups.",
		3: "I still set the board for the line—when it's your cups alone, I'll let the tired show without polishing the tremor away.",
	},
	"Maela Thorn": {
		1: "I'm shortening the angry stride before it turns into a speech—air is for orders, not for old voices.",
		2: "If I run ugly drills in the mud, it's because applause lied about safety once too often.",
		3: "I own the ring's answer now—not as proof against old insults, as duty: steadier hips, fewer performances, same standard for everyone including me.",
	},
	"Rufus": {
		1: "Still picking up work hot when I say dusk—heat doesn't lie, and neither should the ask.",
		2: "Quench tank still isn't holy water; I'm just glad you backed metal loud enough nobody needs my mouth to bless steel.",
		3: "Near my fire you're under my bluntness—I'd rather bruise an ego early than watch a soft lie cost someone their fingers.",
	},
	"Mira Ashdown": {
		1: "Slow on the line stays slow on purpose—mock patience and you train shame, not strings.",
		2: "Wind days still bite—I'm choosing ugly truth over fast lies, even when the camp wants a show.",
		3: "Slow work earned a seat at my ear—I'll back shared boring competence before I trust a clean score that hid the hurry.",
	},
	"Pell Rowan": {
		1: "One breath, one call—still ugly, still true. That's the only brave that holds.",
		2: "Relay tomorrow scares me less when I remember dry runs beat hero-voice—I'd rather be boring-right than shining-wrong.",
		3: "The call still rattles—difference is I expect true before pretty now; that's steadiness I can carry when the wall goes loud.",
	},
	"Oren Pike": {
		1: "I'm still padding your maps with hours they don't print—ask before you trust clean ink.",
		2: "Guy lines stayed ugly after that march; I'd rather own boring delay than a tidy story and a twisted ankle.",
		3: "You asked for ink plus judgment—I stake lines you can sleep behind, not timelines that look brave on parchment alone.",
	},
	"Tariq": {
		1: "I'm trimming rumor before it drafts your orders for you—dialect isn't the same as intelligence.",
		2: "Miser-words after the market lesson: earned syllables only. If they call it cold, good—warmth wraps rot.",
		3: "I still trim—but I leave enough thread that you're holding the translation beside me, not renting my mouth when the story sours.",
	},
	"Sabine Varr": {
		1: "Boredom's off the guest list on my section—rotate the pattern so the wall stops telling time to scouts.",
		2: "Ledger's bent where reality asked—small fractures, same spine; grief can wait behind procedure.",
		3: "My section bends and keeps spine—sergeants own small breaks while I stay with the grief in the room instead of burying it under the roster.",
	},
	"Inez": {
		1: "Shorter steps on gravel—still practice, not performance. The trees heard you first; I'm just catching up.",
		2: "Trust was letting you move my shape without taking my name—I'm holding to that when the soil gets opinionated.",
		3: "Soil still gets the first word—only now I leave the flap open after, in case you meant to stay past the lesson.",
	},
	"Kaelen": {
		1: "Grief waits its turn—breathing first. I'm still not soft about it; I'm just done pretending hardness is the same as useful.",
		2: "Greyspire's weight hasn't lifted—I'm watching you carry it without turning into the kind of officer who needs a corpse to feel righteous.",
		3: "You kept moving when Emberwood wanted you to kneel in ash—that's the line I invest in now, not speeches about sacrifice.",
	},
	"Liora": {
		1: "Sanctum ink still stains my sleeves—I'm practicing seeing you before the Mark when the camp forgets how.",
		2: "Sunlit Trial taught me fear isn't cleaner in priestess Latin—I'm scared for you, plainly, and I'm staying anyway.",
		3: "Chosen steadiness, not spectacle—if I reach for your hand in the quiet, it's because I mean it, not because the hymn told me to.",
	},
	"Ser Hadrien": {
		1: "Burden still fits the Veilbreaker better than destiny—I'm done polishing the Order's old excuses into poetry.",
		2: "I listen for the human beneath the rule now—your calls under fire earned that, even when doctrine would've called them wrong.",
	},
	"Darian": {
		1: "I still arrange the room—now I leave one corner crooked so nobody mistakes polish for full bellies.",
		2: "The mask still fits in public—privately I'm holding to the two knocks: anger on a leash, tenderness when nobody's buying tickets.",
	},
	"Veska Moor": {
		1: "Breath-length why, still—banners can hang quiet while feet learn where weight actually lives.",
		2: "Bruises don't lecture—if I'm cleaning blood off a shield again, it's because speeches lied and bodies paid; I'll say that plain before the next rally.",
	},
	"Corvin Ash": {
		1: "Warm copy's shorter; cold record stays long—visibility was the bargain, not comfort.",
		2: "Truth spreads like damp in a ledger—keep the cold copy honest and everyone who touches it pays a little; I'd rather that cost than a pretty lie that rots quiet.",
	},
	"Sister Meris": {
		1: "Files stay open longer—bread before verdict still feels like disobedience, which means it's probably mercy.",
		2: "I caught myself handing water before judgment yesterday—small, ugly mercy Alden didn't have to prompt; that's the practice I'm trying to live, not debate.",
	},
	"Hest \"Sparks\"": {
		1: "Dull build, intact fingers—if I joke mid-rig, check the clamps before the punchline; humor's just nervous insulation.",
		2: "Slow work stopped tasting like an exit clause—if you meant the bread-and-clamps promise, I'm building like I'm still here next week, not like I'm auditioning to be forgotten.",
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
