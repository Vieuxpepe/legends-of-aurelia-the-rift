# CampRequestContentDB.gd
# Data-only content bank for Camp Requests. Add character/voice/personality/neutral text here
# without changing request logic. CampRequestDB queries this first, then falls back to internal templates.
# Schema supports bulk writing and optional nesting by item_tag, signature_request_bias, motive_tag, voice_style.
#
# Content schema (bulk-fill reference):
#   Pool names: titles_item_delivery, titles_talk_to_unit, desc_item_delivery, desc_talk_to_unit,
#               offer_lines, accepted_lines, declined_lines, in_progress_lines, ready_lines,
#               completed_lines, completed_warm_lines.
#   Each pool value: Array of strings, or Dict keyed by item_tag | signature_request_bias | motive_tag | voice_style -> Array of strings.
#   Description pools use format strings: desc_item_delivery "%d x %s" (target_amount, target_name); desc_talk_to_unit "%s" (target_name).

class_name CampRequestContentDB

# --- Pool names (schema). Use these when calling get_character_pool / get_fallback_pool / get_best_pool. ---
const POOL_TITLES_ITEM_DELIVERY: String = "titles_item_delivery"
const POOL_TITLES_TALK_TO_UNIT: String = "titles_talk_to_unit"
const POOL_DESC_ITEM_DELIVERY: String = "desc_item_delivery"
const POOL_DESC_TALK_TO_UNIT: String = "desc_talk_to_unit"
const POOL_OFFER_LINES: String = "offer_lines"
const POOL_ACCEPTED_LINES: String = "accepted_lines"
const POOL_DECLINED_LINES: String = "declined_lines"
const POOL_IN_PROGRESS_LINES: String = "in_progress_lines"
const POOL_READY_LINES: String = "ready_lines"
const POOL_COMPLETED_LINES: String = "completed_lines"
const POOL_COMPLETED_WARM_LINES: String = "completed_warm_lines"

# --- Branching "check on someone" (talk_to_unit with choices; wrong choice can fail). ---
# Request biases that can use branching checks. Others complete on first talk.
const BRANCHING_BIASES: Array = ["wellness_check", "read_mood", "mediation", "solemn_check", "social_errands", "pointed_conversations"]

# --- Special camp scenes (trusted/close tier; one-time or repeatable). Foundation for support-style scenes. ---
# SPECIAL_CAMP_SCENES[unit_name][tier] = { "one_time": bool, "lines": Array[String] }. Tier: "trusted" | "close".
static var SPECIAL_CAMP_SCENES: Dictionary = {
	"Commander": {
		"trusted": {"one_time": true, "lines": ["You've carried quiet burdens well. I notice.", "When I need someone steady, I think of you. That's not nothing.", "Keep doing what you're doing. The camp is better for it."]},
		"close": {"one_time": true, "lines": ["I don't say this often. I trust your judgment.", "Whatever comes—I'm glad you're here.", "You've earned more than I can say in front of the ranks."]},
	},
	"Kaelen": {
		"trusted": {"one_time": true, "lines": ["You don't waste words. I respect that.", "You've held your end. That matters.", "Standards matter. You've met them."]},
		"close": {"one_time": true, "lines": ["I don't ask much of people. You've given more than asked.", "Between us—you've carried weight I didn't have to spell out.", "Thank you. Properly."]},
	},
	"Branik": {
		"trusted": {"one_time": true, "lines": ["You've been good for camp morale. I mean it.", "Keep an eye on people. You're one of the few who does.", "Thanks for being there. It matters."]},
		"close": {"one_time": true, "lines": ["You've looked after the vulnerable when it counted.", "This place needs more like you. Seriously.", "I'm glad you're here. Don't forget it."]},
	},
	"Liora": {
		"trusted": {"one_time": true, "lines": ["You've proven yourself a friend to the infirmary. I wanted to say so.", "When you have a moment—thank you. For checking in on people. It matters.", "I don't say it enough. You've been kind. Thank you."]},
		"close": {"one_time": true, "lines": ["I trust you. That's not something I give lightly.", "You've earned a place here. In case no one's said it.", "Whatever comes next—I'm glad you're with us."]},
	},
	"Nyx": {
		"trusted": {"one_time": true, "lines": ["You're not as easy to read as most. I can work with that.", "We're square. For now. Don't make me regret it.", "You've been useful. I don't forget that."]},
		"close": {"one_time": true, "lines": ["I've let you in further than most. Don't abuse it.", "You see angles others miss. I value that.", "We're aligned. For as long as it serves both of us."]},
	},
	"Sorrel": {
		"trusted": {"one_time": true, "lines": ["Your discretion has been noted. And appreciated.", "The work you've done—quiet, accurate. It matters.", "I don't trust many with the full picture. You're one of them."]},
		"close": {"one_time": true, "lines": ["You've earned access to the messier threads. Handle them well.", "Truth matters. You've pursued it. Thank you.", "Whatever we find next—I'd rather have you there."]},
	},
	"Darian": {
		"trusted": {"one_time": true, "lines": ["You've smoothed fractures I couldn't touch. Thank you.", "Morale is fragile. You've held it. I notice.", "The camp needs people who can read a room. You can."]},
		"close": {"one_time": true, "lines": ["I've let you see the cracks. Don't make me regret it.", "You've carried social weight I couldn't. Proper thanks.", "Whatever comes—you're in my corner. I'm in yours."]},
	},
	"Celia": {
		"trusted": {"one_time": true, "lines": ["You've handled quiet responsibility well. Not everyone does.", "Discipline without cruelty. You understand the difference.", "I trust you with the things I don't broadcast."]},
		"close": {"one_time": true, "lines": ["You've shared the burden without flinching. Thank you.", "Protection isn't always visible. You've provided it.", "I'm glad you're here. Truly."]},
	},
	"Rufus": {
		"trusted": {"one_time": true, "lines": ["You've gotten things where they needed to go. No fuss.", "Practical trust—you've earned it.", "Tools and labor. You understand both."]},
		"close": {"one_time": true, "lines": ["I don't ask many. You're one of them. That means something.", "You've run the hard errands. I won't forget.", "Thanks. The real kind."]},
	},
	"Inez": {
		"trusted": {"one_time": true, "lines": ["You've had eyes on the edge when it mattered.", "Instinct and follow-through. You've got both.", "The line's safer for having you."]},
		"close": {"one_time": true, "lines": ["You've watched my back when the camp got sharp. Thank you.", "Pressure at the edge—you've held. I see it.", "We're good. You and me."]},
	},
	"Tariq": {
		"trusted": {"one_time": true, "lines": ["You've asked the questions that needed asking. Uncomfortable, but right.", "Pointed truth. You've delivered it. I respect that.", "Ambiguity doesn't faze you. Useful."]},
		"close": {"one_time": true, "lines": ["I've given you the harder truths. Don't waste them.", "You've earned the right to the full picture. Such as it is.", "Whatever comes—we're clear. You and I."]},
	},
	"Mira Ashdown": {
		"trusted": {"one_time": true, "lines": ["Quiet loyalty. You've shown it. I notice.", "Patrol strain—you've carried your share and then some.", "I trust you with the things that don't get announced."]},
		"close": {"one_time": true, "lines": ["You've shared the burden when I couldn't spread it. Thank you.", "Burden-sharing. You've done it. Proper thanks.", "I'm glad you're here. Really."]},
	},
	"Pell Rowan": {
		"trusted": {"one_time": true, "lines": ["You've proven useful in the ways that matter. Not just busy.", "Earning your place—you've done it. I see you.", "Keep showing up. It matters."]},
		"close": {"one_time": true, "lines": ["You've pushed past the insecurity. I respect that.", "You're not just useful. You're needed. There's a difference.", "Thank you. For sticking."]},
	},
	"Tamsin Reed": {
		"trusted": {"one_time": true, "lines": ["Gentle courage. You've got it. The infirmary sees it.", "You've tended to overlooked pain. Thank you.", "Healing load—you've carried more than your share."]},
		"close": {"one_time": true, "lines": ["I trust you with the fragile things. People included.", "You've been kind when it cost you. I won't forget.", "Whatever comes—I'm glad you're with us."]},
	},
	"Hest \"Sparks\"": {
		"trusted": {"one_time": true, "lines": ["Chaos with consequences—you've owned it. That counts.", "You've cleaned up messes you didn't have to. Thanks.", "Gossip and damage control. You've helped. Seriously."]},
		"close": {"one_time": true, "lines": ["I've let you see the mess. Don't spread it.", "You've had my back when the chaos landed wrong. Thank you.", "We're good. Messy, but good."]},
	},
	"Brother Alden": {
		"trusted": {"one_time": true, "lines": ["You've done the emotional labor when others stepped back. Peace be with you.", "Mediation isn't easy. You've tried. I'm grateful.", "The camp is calmer for your presence."]},
		"close": {"one_time": true, "lines": ["I've trusted you with peacekeeping. You've honored that.", "Bless you. For the quiet work. Truly.", "Whatever comes—you've been a steady hand."]},
	},
	"Oren Pike": {
		"trusted": {"one_time": true, "lines": ["You've gotten parts where they needed to go. No drama.", "Competence. You've shown it. I notice.", "Maintenance burden—you've carried it. Thanks."]},
		"close": {"one_time": true, "lines": ["I don't ask many. You're one. Resentment and all—you've delivered.", "You've eased the neglect. Proper thanks.", "We're square. You and me."]},
	},
	"Garrick Vale": {
		"trusted": {"one_time": true, "lines": ["Order and duty—you've upheld both. The line notices.", "You've kept discipline without breaking people. That matters.", "I trust you with the hard conversations."]},
		"close": {"one_time": true, "lines": ["You've held the line when it was hard. Thank you.", "Duty shared is duty halved. You've done your part.", "I'm glad you're here. Don't doubt it."]},
	},
	"Sabine Varr": {
		"trusted": {"one_time": true, "lines": ["Logistics and weak points—you've watched both. I notice.", "Controlled concern. You've shown it. The camp is safer.", "You've filled gaps others didn't see."]},
		"close": {"one_time": true, "lines": ["I've trusted you with the vulnerable spots. Don't betray it.", "You've defended what mattered. Thank you.", "Whatever comes—we're aligned."]},
	},
	"Yselle Maris": {
		"trusted": {"one_time": true, "lines": ["Social currents—you've read them well. Morale thanks you.", "Elegance under strain. You've held it. I see that.", "You've smoothed what could have fractured."]},
		"close": {"one_time": true, "lines": ["I've let you see the frayed edges. Handle with care.", "You've carried morale when I couldn't. Proper thanks.", "We're good. You and I."]},
	},
	"Sister Meris": {
		"trusted": {"one_time": true, "lines": ["Discipline and records—you've kept both. The camp is clearer for it.", "Difficult care. You've done it. I'm grateful.", "You've held the line when kindness and order met."]},
		"close": {"one_time": true, "lines": ["I've trusted you with the hard conversations. You've honored that.", "Records and care. You've balanced both. Thank you.", "Whatever comes—you've been steady."]},
	},
	"Corvin Ash": {
		"trusted": {"one_time": true, "lines": ["Strange evidence—you've looked at it without flinching.", "Truth in discomfort. You've pursued it. Useful.", "Ritual residue and oddities. You've been a steady pair of eyes."]},
		"close": {"one_time": true, "lines": ["I've shown you things I don't show many. Don't misuse that.", "You've sat with the uncomfortable truth. Thank you.", "We're aligned. In the uncanny sense."]},
	},
	"Veska Moor": {
		"trusted": {"one_time": true, "lines": ["Reliability. You've shown it. Drills and fortification—you've held.", "You've carried the pressure without buckling. I notice.", "The line's sharper for having you."]},
		"close": {"one_time": true, "lines": ["I've trusted you with the hard prep. You've delivered.", "Fortification pressure—you've shared it. Thank you.", "We're good. Steady."]},
	},
	"Ser Hadrien": {
		"trusted": {"one_time": true, "lines": ["Memory and duty—you've respected both. I see that.", "You've carried weight without dropping it. Thank you.", "Endurance. You've shown it. The camp needs that."]},
		"close": {"one_time": true, "lines": ["I've let you near the grief. Don't spread it.", "You've checked on the ones who carry the most. Thank you.", "Whatever comes—you've been steady. I won't forget."]},
	},
	"Maela Thorn": {
		"trusted": {"one_time": true, "lines": ["Momentum and messenger work—you've carried both. Thanks.", "Bravado and sincerity. You've shown both. I notice.", "You've lightened the burden. Don't think it's unseen."]},
		"close": {"one_time": true, "lines": ["I've trusted you with the real message. Don't drop it.", "You've been there when the pace was brutal. Thank you.", "We're good. Fast, but good."]},
	},
}

# --- Personal quest profiles (relationship-gated; unlock_tier = "trusted" or "close"). Foundation for deeper personal quests. ---
# PERSONAL_QUEST_PROFILES[unit_name] = { "unlock_tier": String, "title": String, "description": String, "type": "item_delivery"|"talk_to_unit", "target_bias": String (talk) or optional, "request_depth": "personal" }
static var PERSONAL_QUEST_PROFILES: Dictionary = {
	"Commander": {
		"unlock_tier": "trusted",
		"title": "A quiet matter.",
		"description": "I need someone steady to check on a soldier. Not officially—I need the truth of how they're holding.",
		"type": "talk_to_unit",
		"target_bias": "quiet_tasks",
		"request_depth": "personal",
	},
	"Kaelen": {
		"unlock_tier": "close",
		"title": "One more thing.",
		"description": "I don't ask often. I need you to run something to the field—and to keep it between us.",
		"type": "item_delivery",
		"request_depth": "personal",
	},
	"Branik": {
		"unlock_tier": "trusted",
		"title": "Someone needs looking after.",
		"description": "I'd do it myself but they'll open up to you. See that they're alright—really alright.",
		"type": "talk_to_unit",
		"target_bias": "wellness_check",
		"request_depth": "personal",
	},
	"Liora": {
		"unlock_tier": "trusted",
		"title": "A personal favor.",
		"description": "I need someone I can trust to take this to the person who needs it most. Will you?",
		"type": "talk_to_unit",
		"target_bias": "wellness_check",
		"request_depth": "personal",
	},
	"Nyx": {
		"unlock_tier": "close",
		"title": "I need a read.",
		"description": "Someone in camp—I need to know where their head is. Not what they say. What they mean. Can you do that?",
		"type": "talk_to_unit",
		"target_bias": "read_mood",
		"request_depth": "personal",
	},
	"Sorrel": {
		"unlock_tier": "trusted",
		"title": "A piece of the puzzle.",
		"description": "I'm following a thread. I need specific materials delivered without drawing attention. Discretion matters.",
		"type": "item_delivery",
		"request_depth": "personal",
	},
	"Darian": {
		"unlock_tier": "close",
		"title": "A fracture in the ranks.",
		"description": "Two of ours are at odds. I need someone with a light touch to smooth things over. Morale is my concern—and yours now.",
		"type": "talk_to_unit",
		"target_bias": "social_errands",
		"request_depth": "personal",
	},
	"Celia": {
		"unlock_tier": "trusted",
		"title": "A matter of readiness.",
		"description": "I need you to speak with someone about their gear and discipline. Quietly. They respect you. I need them sharp, not defensive.",
		"type": "talk_to_unit",
		"target_bias": "gear_order",
		"request_depth": "personal",
	},
	"Rufus": {
		"unlock_tier": "close",
		"title": "Tools and trust.",
		"description": "I need specific parts run to the right hands. No one else I'd ask. Get it there and say nothing.",
		"type": "item_delivery",
		"request_depth": "personal",
	},
	"Inez": {
		"unlock_tier": "trusted",
		"title": "Eyes on the edge.",
		"description": "Someone on the watch line isn't right. I need you to check on them—instinct says pressure, not laziness. See what's really going on.",
		"type": "talk_to_unit",
		"target_bias": "wellness_check",
		"request_depth": "personal",
	},
	"Tariq": {
		"unlock_tier": "close",
		"title": "The question that matters.",
		"description": "There's something I need asked. Directly. No hedging. I need you to have a pointed conversation with someone and bring back the truth.",
		"type": "talk_to_unit",
		"target_bias": "pointed_conversations",
		"request_depth": "personal",
	},
	"Mira Ashdown": {
		"unlock_tier": "trusted",
		"title": "Quiet burden.",
		"description": "Patrol's taken its toll on someone. I need a discreet check—how they're holding, not what they report. You're good at that.",
		"type": "talk_to_unit",
		"target_bias": "quiet_tasks",
		"request_depth": "personal",
	},
	"Pell Rowan": {
		"unlock_tier": "close",
		"title": "Prove it to them.",
		"description": "Someone doesn't believe they're needed. I need you to talk to them—help them see their place. Earn their trust, not their performance.",
		"type": "talk_to_unit",
		"target_bias": "wellness_check",
		"request_depth": "personal",
	},
	"Tamsin Reed": {
		"unlock_tier": "trusted",
		"title": "The overlooked pain.",
		"description": "There's someone carrying more than they show. Healing load, fear—I need a gentle check. You have the courage for it.",
		"type": "talk_to_unit",
		"target_bias": "wellness_check",
		"request_depth": "personal",
	},
	"Hest \"Sparks\"": {
		"unlock_tier": "close",
		"title": "Damage control.",
		"description": "I may have said something that landed wrong. I need you to smooth things over with someone—gossip, feelings, the usual mess. Please?",
		"type": "talk_to_unit",
		"target_bias": "social_errands",
		"request_depth": "personal",
	},
	"Brother Alden": {
		"unlock_tier": "trusted",
		"title": "Peace between them.",
		"description": "Two souls are at odds. I've tried; they need a different voice. Mediation—practical, kind. Will you go?",
		"type": "talk_to_unit",
		"target_bias": "mediation",
		"request_depth": "personal",
	},
	"Oren Pike": {
		"unlock_tier": "close",
		"title": "The maintenance no one sees.",
		"description": "I need parts run to someone who'll use them, not stash them. Competence matters. Resentment of neglect—I get it. Just get it done.",
		"type": "item_delivery",
		"request_depth": "personal",
	},
	"Garrick Vale": {
		"unlock_tier": "trusted",
		"title": "Line discipline.",
		"description": "Someone's slipping. Order and duty—I need you to have a direct word. Not punishment. Clarity. They'll hear it from you.",
		"type": "talk_to_unit",
		"target_bias": "duty_conversations",
		"request_depth": "personal",
	},
	"Sabine Varr": {
		"unlock_tier": "close",
		"title": "A weak point.",
		"description": "Logistics and defenses—I've spotted a gap. I need specific supplies in the right hands. Controlled concern. No alarm.",
		"type": "item_delivery",
		"request_depth": "personal",
	},
	"Yselle Maris": {
		"unlock_tier": "trusted",
		"title": "Social currents.",
		"description": "Morale is fraying around someone. I need you to speak with them—elegance under strain. Smooth the waters. You know how.",
		"type": "talk_to_unit",
		"target_bias": "social_errands",
		"request_depth": "personal",
	},
	"Sister Meris": {
		"unlock_tier": "close",
		"title": "Discipline and care.",
		"description": "Records and difficult care—I need a conversation had. Firm but not cruel. See they're clear on expectations.",
		"type": "talk_to_unit",
		"target_bias": "discipline_conversations",
		"request_depth": "personal",
	},
	"Corvin Ash": {
		"unlock_tier": "trusted",
		"title": "Strange evidence.",
		"description": "I've found something. Ritual residue—truth in discomfort. I need you to consult with someone and bring back their read. No drama.",
		"type": "talk_to_unit",
		"target_bias": "pointed_conversations",
		"request_depth": "personal",
	},
	"Veska Moor": {
		"unlock_tier": "close",
		"title": "Fortification pressure.",
		"description": "Drills and reliability—I need specific gear in the right hands. No fuss. Just get it there so we stay sharp.",
		"type": "item_delivery",
		"request_depth": "personal",
	},
	"Ser Hadrien": {
		"unlock_tier": "trusted",
		"title": "Memory and duty.",
		"description": "Someone carries weight. Memory, grief—I need a solemn check. See they're steady. Endurance isn't infinite.",
		"type": "talk_to_unit",
		"target_bias": "solemn_check",
		"request_depth": "personal",
	},
	"Maela Thorn": {
		"unlock_tier": "close",
		"title": "Messenger's burden.",
		"description": "I need a message delivered—and a real conversation. Momentum and bravado only go so far. See how they really are.",
		"type": "talk_to_unit",
		"target_bias": "messenger_errands",
		"request_depth": "personal",
	},
}

# Personality -> challenge_state for picking the right branching content (target responds to approach).
# States: patience_indirect, direct_reassurance, solemn_patience, light_touch, perceptive_indirect, respectful_clarity, graceful_social.
static var PERSONALITY_TO_CHALLENGE_STATE: Dictionary = {
	"stoic": "patience_indirect", "guarded": "patience_indirect", "blunt": "patience_indirect",
	"warm": "direct_reassurance", "earnest": "direct_reassurance", "compassionate": "direct_reassurance", "neutral": "direct_reassurance",
	"haunted": "solemn_patience", "devout": "solemn_patience", "solemn": "solemn_patience",
	"wild": "light_touch", "spirited": "light_touch", "chaotic": "light_touch",
	"sly": "perceptive_indirect", "sardonic": "perceptive_indirect", "occult": "perceptive_indirect",
	"scholarly": "respectful_clarity", "disciplined": "respectful_clarity", "pragmatic": "respectful_clarity", "severe": "respectful_clarity",
	"flamboyant": "graceful_social",
}

# --- Content banks (static so retrieval helpers work without an instance). ---
# Per-voice-style fallback: voice_style -> { pool_name -> Array }
static var VOICE_STYLE_BANKS: Dictionary = {
	"blunt": {
		POOL_OFFER_LINES: [
			"Need a moment.",
			"Quick favor.",
			"I need something done.",
		],
		POOL_ACCEPTED_LINES: [
			"Good. Thank you.",
			"Understood. That helps.",
		],
		POOL_DECLINED_LINES: [
			"Understood.",
			"Another time, then.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When you have it.",
			"No rush. Just don't forget.",
		],
		POOL_READY_LINES: [
			"You have it? Good.",
			"Right. Let's settle this.",
		],
		POOL_COMPLETED_LINES: [
			"Thanks.",
			"Good. We're square.",
		],
	},
	"caring": {
		POOL_OFFER_LINES: [
			"Could you help me with something?",
			"When you have a moment, please.",
			"I'd be grateful for a hand.",
		],
		POOL_ACCEPTED_LINES: [
			"Thank you. Truly.",
			"I appreciate it more than you know.",
		],
		POOL_DECLINED_LINES: [
			"I understand.",
			"No trouble. Perhaps later.",
		],
		POOL_IN_PROGRESS_LINES: [
			"Take your time.",
			"I'll be here when you're ready.",
		],
		POOL_READY_LINES: [
			"You brought it? Thank you.",
			"That's a relief. Thank you.",
		],
		POOL_COMPLETED_LINES: [
			"Thank you again.",
			"You've been very kind.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"Thank you. You've become someone I can count on.",
			"I'm grateful. More than I can easily say.",
		],
	},
	"sly": {
		POOL_OFFER_LINES: [
			"A small favor.",
			"I need your eyes on something.",
			"Care to do a little listening for me?",
		],
		POOL_ACCEPTED_LINES: [
			"Clever choice.",
			"Good. I knew you'd see the angle.",
		],
		POOL_DECLINED_LINES: [
			"Fair enough.",
			"Shame. Another time, maybe.",
		],
		POOL_IN_PROGRESS_LINES: [
			"See what you can learn.",
			"Take your time. Details matter.",
		],
		POOL_READY_LINES: [
			"You have something for me?",
			"Good. Let's hear it.",
		],
		POOL_COMPLETED_LINES: [
			"Useful. Thank you.",
			"We're square. For now.",
		],
	},
	"scholarly": {
		POOL_OFFER_LINES: [
			"I need a small practical favor.",
			"A brief errand, if you please.",
			"I could use a second set of hands.",
		],
		POOL_ACCEPTED_LINES: [
			"Excellent. My thanks.",
			"Noted. I appreciate the help.",
		],
		POOL_DECLINED_LINES: [
			"Understood.",
			"No matter. I'll adapt.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When you have the result, return to me.",
			"There is no rush, only accuracy.",
		],
		POOL_READY_LINES: [
			"Ah. You have it.",
			"Good. That will do nicely.",
		],
		POOL_COMPLETED_LINES: [
			"My thanks.",
			"This is genuinely useful.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"My thanks again. You've proven remarkably dependable.",
			"I appreciate your consistency more each time.",
		],
	},
	"elegant": {
		POOL_OFFER_LINES: [
			"A delicate favor, if you would.",
			"Would you indulge me a moment?",
			"I have a small matter requiring grace.",
		],
		POOL_ACCEPTED_LINES: [
			"Splendid.",
			"You do make things easier.",
		],
		POOL_DECLINED_LINES: [
			"How tragic. Another time.",
			"No matter. The world continues.",
		],
		POOL_IN_PROGRESS_LINES: [
			"See it done with a light touch.",
			"When the matter is settled, return to me.",
		],
		POOL_READY_LINES: [
			"Perfect timing.",
			"Lovely. Let us conclude this properly.",
		],
		POOL_COMPLETED_LINES: [
			"Splendid work.",
			"My thanks. That was elegantly handled.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"Truly, you make refinement look effortless.",
			"My thanks again. You've been a delight to rely on.",
		],
	},
	"disciplined": {
		POOL_OFFER_LINES: [
			"I have a task for you.",
			"A brief matter requires attention.",
			"I need this handled properly.",
		],
		POOL_ACCEPTED_LINES: [
			"Acknowledged.",
			"Good. Thank you.",
		],
		POOL_DECLINED_LINES: [
			"Understood.",
			"Very well. Dismissed.",
		],
		POOL_IN_PROGRESS_LINES: [
			"Report when it's done.",
			"Take care of it and return.",
		],
		POOL_READY_LINES: [
			"Good. Hand it over.",
			"Understood. Let's settle accounts.",
		],
		POOL_COMPLETED_LINES: [
			"Acknowledged. Thank you.",
			"Well done.",
		],
	},
	"pragmatic": {
		POOL_OFFER_LINES: [
			"Need a hand with something.",
			"Quick favor.",
			"I've got a practical problem.",
		],
		POOL_ACCEPTED_LINES: [
			"That helps.",
			"Good. Appreciate it.",
		],
		POOL_DECLINED_LINES: [
			"No problem.",
			"Fine. Next time.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When you've got it, bring it by.",
			"No hurry. Just keep it in mind.",
		],
		POOL_READY_LINES: [
			"Good. That's what I needed.",
			"Right. Let's finish this.",
		],
		POOL_COMPLETED_LINES: [
			"Appreciate it.",
			"That solves it. Thanks.",
		],
	},
	"severe": {
		POOL_OFFER_LINES: [
			"I require your help.",
			"A matter needs handling.",
			"Do not waste my time.",
		],
		POOL_ACCEPTED_LINES: [
			"Understood.",
			"Good. I'll remember that.",
		],
		POOL_DECLINED_LINES: [
			"Very well.",
			"Go, then.",
		],
		POOL_IN_PROGRESS_LINES: [
			"I expect results.",
			"Return when the matter is settled.",
		],
		POOL_READY_LINES: [
			"Good. Present it.",
			"You've done your part.",
		],
		POOL_COMPLETED_LINES: [
			"Acknowledged.",
			"You were useful.",
		],
	},
	"solemn": {
		POOL_OFFER_LINES: [
			"I have a grave favor to ask.",
			"A quiet matter needs tending.",
			"I would ask something serious of you.",
		],
		POOL_ACCEPTED_LINES: [
			"Thank you. I do mean that.",
			"I won't forget your willingness.",
		],
		POOL_DECLINED_LINES: [
			"Understood.",
			"Another time, perhaps.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When it is done, return to me.",
			"Take the time it requires.",
		],
		POOL_READY_LINES: [
			"You've done it? Thank you.",
			"It is finished, then.",
		],
		POOL_COMPLETED_LINES: [
			"My thanks.",
			"It means more than you know.",
		],
	},
	"chaotic": {
		POOL_OFFER_LINES: [
			"Quick favor!",
			"I need something weirdly specific.",
			"Help me with a small disaster.",
		],
		POOL_ACCEPTED_LINES: [
			"Excellent.",
			"Ha! Knew you'd go for it.",
		],
		POOL_DECLINED_LINES: [
			"Alright, alright.",
			"Your loss.",
		],
		POOL_IN_PROGRESS_LINES: [
			"Come back when you've got it sorted.",
			"Let's see what turns up.",
		],
		POOL_READY_LINES: [
			"You actually did it?",
			"Perfect. Hand it over.",
		],
		POOL_COMPLETED_LINES: [
			"Fantastic. Thanks.",
			"You came through. Nice.",
		],
	},
	"earnest": {
		POOL_OFFER_LINES: [
			"Could you help me out?",
			"I've got a favor to ask.",
			"I'd really appreciate a hand.",
		],
		POOL_ACCEPTED_LINES: [
			"Thank you. Really.",
			"I appreciate it a lot.",
		],
		POOL_DECLINED_LINES: [
			"That's okay.",
			"Maybe another time.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When you can, come back to me.",
			"I'll be waiting.",
		],
		POOL_READY_LINES: [
			"You have it? Thank you.",
			"Oh, good. Thanks.",
		],
		POOL_COMPLETED_LINES: [
			"Thanks again.",
			"I won't forget this.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"Thank you again. I trust you more every time.",
			"I mean it. You've been good to me.",
		],
	},
	"warm": {
		POOL_OFFER_LINES: [
			"Got a small favor, if you're willing.",
			"Mind helping with something?",
			"I could use a kind hand.",
		],
		POOL_ACCEPTED_LINES: [
			"Thank you. That means a lot.",
			"You're good to do this.",
		],
		POOL_DECLINED_LINES: [
			"No worries.",
			"That's alright. Another time.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When you've seen to it, come by.",
			"No hurry. Just don't lose sleep over it.",
		],
		POOL_READY_LINES: [
			"You brought it? Thank you kindly.",
			"Good. That's a weight off.",
		],
		POOL_COMPLETED_LINES: [
			"Thanks again.",
			"You're a real help.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"Thank you. You're becoming one of my steady comforts.",
			"I'm grateful, truly. You've been good for this camp.",
		],
	},
	"guarded": {
		POOL_OFFER_LINES: [
			"I need something checked.",
			"A favor, nothing more.",
			"There's something I want looked into.",
		],
		POOL_ACCEPTED_LINES: [
			"Noted.",
			"Good. I appreciate it.",
		],
		POOL_DECLINED_LINES: [
			"Fine.",
			"Another time, then.",
		],
		POOL_IN_PROGRESS_LINES: [
			"See what you can find.",
			"Come back when you know more.",
		],
		POOL_READY_LINES: [
			"You've got it?",
			"Good. Let's be done with it.",
		],
		POOL_COMPLETED_LINES: [
			"Thanks.",
			"I noticed the effort.",
		],
	},
	"unsettling": {
		POOL_OFFER_LINES: [
			"I require a small indulgence.",
			"A strange favor, perhaps.",
			"There is something I need brought to light.",
		],
		POOL_ACCEPTED_LINES: [
			"...My thanks.",
			"It will not go unmarked.",
		],
		POOL_DECLINED_LINES: [
			"As you wish.",
			"Then the matter waits.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When you have what I need, return.",
			"I can be patient.",
		],
		POOL_READY_LINES: [
			"You have it? Interesting.",
			"Good. Let us conclude this.",
		],
		POOL_COMPLETED_LINES: [
			"It is noted.",
			"You have my thanks.",
		],
	},
	"kinetic": {
		POOL_OFFER_LINES: [
			"Quick one for you.",
			"Need something handled fast.",
			"I've got a favor with momentum.",
		],
		POOL_ACCEPTED_LINES: [
			"Perfect. You're on it.",
			"Nice. Knew I could ask you.",
		],
		POOL_DECLINED_LINES: [
			"No problem. Later.",
			"Alright. Catch you next time.",
		],
		POOL_IN_PROGRESS_LINES: [
			"Move quick and come back.",
			"When it's done, come find me.",
		],
		POOL_READY_LINES: [
			"You got it done? Nice.",
			"Perfect timing.",
		],
		POOL_COMPLETED_LINES: [
			"Thanks! Nicely done.",
			"That's exactly what I needed.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"Thanks again. You always keep pace.",
			"I knew I could count on your speed.",
		],
	},
	"direct": {
		POOL_OFFER_LINES: [
			"I need a practical favor.",
			"A quick task, if you're able.",
			"There is something that needs doing.",
		],
		POOL_ACCEPTED_LINES: [
			"Thank you.",
			"I appreciate the help.",
		],
		POOL_DECLINED_LINES: [
			"Understood.",
			"Another time, then.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When it's done, report back.",
			"I'll be waiting for your return.",
		],
		POOL_READY_LINES: [
			"Good. Let's finish this.",
			"You have it? Thank you.",
		],
		POOL_COMPLETED_LINES: [
			"Good work.",
			"Thanks again.",
		],
	},
}

# Per-personality fallback: personality -> { pool_name -> Array }
static var PERSONALITY_BANKS: Dictionary = {
	"heroic": {
		POOL_OFFER_LINES: [
			"I need a hand for the good of the camp.",
			"Help me see something important done.",
		],
		POOL_COMPLETED_LINES: [
			"You've done the camp a service.",
			"My thanks. That mattered.",
		],
	},
	"stoic": {
		POOL_OFFER_LINES: [
			"A task needs doing.",
			"I have a practical need.",
		],
		POOL_COMPLETED_LINES: [
			"Good.",
			"It is settled. Thank you.",
		],
	},
	"warm": {
		POOL_OFFER_LINES: [
			"Mind helping with something small?",
			"I could use a little kindness.",
		],
		POOL_COMPLETED_LINES: [
			"Thank you kindly.",
			"You're a comfort to have around.",
		],
	},
	"compassionate": {
		POOL_OFFER_LINES: [
			"Would you help me care for something?",
			"I'd be grateful for your help.",
		],
		POOL_COMPLETED_LINES: [
			"Thank you. That eased my heart.",
			"I'm grateful you saw it through.",
		],
	},
	"sly": {
		POOL_OFFER_LINES: [
			"I need someone observant.",
			"There's a small matter worth your attention.",
		],
		POOL_COMPLETED_LINES: [
			"Useful work.",
			"You saw what needed seeing.",
		],
	},
	"scholarly": {
		POOL_OFFER_LINES: [
			"I require a practical assist.",
			"A brief inquiry, if you please.",
		],
		POOL_COMPLETED_LINES: [
			"Excellent. That's useful.",
			"My thanks. The result is sound.",
		],
	},
	"flamboyant": {
		POOL_OFFER_LINES: [
			"A graceful hand is needed.",
			"I have a small matter of finesse.",
		],
		POOL_COMPLETED_LINES: [
			"Lovely work.",
			"My thanks. You handled that beautifully.",
		],
	},
	"disciplined": {
		POOL_OFFER_LINES: [
			"I have a task requiring discipline.",
			"Attend to something for me.",
		],
		POOL_COMPLETED_LINES: [
			"Well handled.",
			"Good. That is acceptable.",
		],
	},
	"pragmatic": {
		POOL_OFFER_LINES: [
			"I have a practical problem.",
			"Need something sorted.",
		],
		POOL_COMPLETED_LINES: [
			"That solves it.",
			"Good. Appreciate it.",
		],
	},
	"wild": {
		POOL_OFFER_LINES: [
			"I need eyes or hands on something.",
			"Small favor. Might be messy.",
		],
		POOL_COMPLETED_LINES: [
			"Ha. Nicely done.",
			"Good. You came through.",
		],
	},
	"sardonic": {
		POOL_OFFER_LINES: [
			"I need a favor. Try not to look too pleased.",
			"There's a small irritation needing attention.",
		],
		POOL_COMPLETED_LINES: [
			"Well, that was useful.",
			"Try not to let the praise spoil you.",
		],
	},
	"earnest": {
		POOL_OFFER_LINES: [
			"Could you help me with something?",
			"I'd really appreciate a hand.",
		],
		POOL_COMPLETED_LINES: [
			"Thank you again.",
			"I mean it. That helped.",
		],
	},
	"chaotic": {
		POOL_OFFER_LINES: [
			"I need a quick favor before something gets worse.",
			"Help me with a little camp disaster.",
		],
		POOL_COMPLETED_LINES: [
			"Perfect. That could've gone worse.",
			"Nice. You saved me some trouble.",
		],
	},
	"devout": {
		POOL_OFFER_LINES: [
			"A practical kindness is needed.",
			"Peace. I would ask a favor.",
		],
		POOL_COMPLETED_LINES: [
			"My thanks. Peace be with you.",
			"Bless you. That mattered.",
		],
	},
	"severe": {
		POOL_OFFER_LINES: [
			"I require assistance.",
			"This matter requires competence.",
		],
		POOL_COMPLETED_LINES: [
			"Accepted.",
			"You performed adequately. Thank you.",
		],
	},
	"occult": {
		POOL_OFFER_LINES: [
			"I need something uncommon attended to.",
			"There is a small matter in the dark.",
		],
		POOL_COMPLETED_LINES: [
			"It is noted.",
			"My thanks. The matter is settled.",
		],
	},
	"haunted": {
		POOL_OFFER_LINES: [
			"I'd ask a quiet favor of you.",
			"There is something I need done carefully.",
		],
		POOL_COMPLETED_LINES: [
			"Thank you. I mean that.",
			"It helps more than I expected.",
		],
	},
	"spirited": {
		POOL_OFFER_LINES: [
			"Hey, quick favor.",
			"I need something handled fast.",
		],
		POOL_COMPLETED_LINES: [
			"Thanks! That was great.",
			"You came through. Knew you would.",
		],
	},
}

# Neutral fallback: pool_name -> Array
static var NEUTRAL_BANKS: Dictionary = {
	POOL_TITLES_ITEM_DELIVERY: [
		"A small favor.",
		"Camp supplies.",
		"Need a hand.",
	],
	POOL_TITLES_TALK_TO_UNIT: [
		"A word with someone.",
		"Pass something along.",
		"Check on them.",
	],
	POOL_DESC_ITEM_DELIVERY: [
		"If you can spare %d x %s, I'd appreciate it. I'll make it worth your while.",
		"I need %d x %s for camp use. Bring it by when you can.",
	],
	POOL_DESC_TALK_TO_UNIT: [
		"Could you have a word with %s for me?",
		"I need you to check in with %s and come back to me.",
	],
	POOL_OFFER_LINES: [
		"Could you help me with something?",
		"I have a small favor to ask.",
	],
	POOL_ACCEPTED_LINES: [
		"Thank you.",
		"I appreciate it.",
	],
	POOL_DECLINED_LINES: [
		"Another time, then.",
		"No worries.",
	],
	POOL_IN_PROGRESS_LINES: [
		"When it's done, come back.",
		"I'll be here.",
	],
	POOL_READY_LINES: [
		"You have it? Thank you.",
		"Good. Let's settle this.",
	],
	POOL_COMPLETED_LINES: [
		"Thanks again.",
		"Good work.",
	],
	POOL_COMPLETED_WARM_LINES: [
		"Thank you again. You've been reliable.",
		"I appreciate it. Truly.",
	],
}

# Per-character: unit_name -> { pool_name -> Array of strings, or pool_name -> { item_tag|signature_request_bias|motive_tag|voice_style -> Array } }
static var CHARACTER_BANKS: Dictionary = {
	"Commander": {
		POOL_TITLES_ITEM_DELIVERY: [
			"Readiness first.",
			"For the camp.",
			"Quiet preparations.",
			"Something that matters.",
			"Between us.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"Check on them.",
			"A direct word.",
			"Keep us steady.",
			"I need your eyes on this.",
			"A matter of trust.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"provisions": [
				"If you can spare %d x %s, bring it to me. I'd rather keep the camp steady before anyone notices the strain.",
				"We're short in the quiet ways that matter. %d x %s would help keep everyone on their feet.",
			],
			"morale": [
				"If you have %d x %s to spare, bring it by. Small comforts carry more weight than people admit.",
				"I need %d x %s for the camp. A little ease now keeps sharper edges from showing later.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"quiet_tasks": [
				"Have a quiet word with %s for me. I need to know how they're holding, not what they think I want to hear.",
				"Check in on %s. Keep it simple, then come back and tell me where they truly stand.",
			],
		},
		POOL_OFFER_LINES: [
			"I need a practical favor.",
			"Help me keep this camp steady.",
			"There is something that needs handling quietly.",
			"I'm asking you because I need the truth, not the report.",
			"This one stays between us.",
		],
		POOL_ACCEPTED_LINES: [
			"Thank you. That takes weight off my mind.",
			"I appreciate it. Quiet work matters most.",
		],
		POOL_DECLINED_LINES: [
			"Understood. I'll find another way.",
			"Very well. Another time.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When it's done, report back.",
			"Take your time. I need the truth, not speed.",
		],
		POOL_READY_LINES: [
			"Good. Let's settle it.",
			"You have it? Thank you.",
		],
		POOL_COMPLETED_LINES: [
			"Good work. The camp is better for it.",
			"My thanks. That mattered.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"Thank you again. You've become someone I trust with quiet burdens.",
			"My thanks. You make it easier to carry command well.",
			"I don't say it often. You've earned it. Thank you.",
			"Quiet work, real weight. You've carried both.",
		],
	},
	"Kaelen": {
		POOL_TITLES_ITEM_DELIVERY: [
			"Upkeep.",
			"Readiness check.",
			"Gear first.",
			"Something I need done right.",
			"Between us.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"Check their footing.",
			"A correction.",
			"See if they're steady.",
			"I need a read on someone. You're the one.",
			"Standards. I need you to see to this.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"maintenance": [
				"If you have %d x %s, bring it to me. Gear goes bad slowly, then all at once.",
				"I need %d x %s for upkeep. Better to fix a weakness before the field finds it first.",
			],
			"provisions": [
				"Bring me %d x %s if you can spare it. Hungry soldiers get careless.",
				"I need %d x %s. Readiness starts long before steel leaves the sheath.",
			],
			"tools": [
				"If you can spare %d x %s, do it. A missing tool becomes a broken line at the wrong hour.",
				"I need %d x %s. Better to keep our hands prepared than curse what we lacked later.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"upkeep": [
				"Speak with %s for me. I need to know whether they're maintaining themselves properly.",
				"Check on %s. Not sentiment—readiness. See if they're slipping anywhere that matters.",
			],
		},
		POOL_OFFER_LINES: [
			"Need something handled.",
			"I have a practical task for you.",
			"This concerns readiness.",
			"I don't ask many. This one matters.",
			"Need it done right. That's you.",
		],
		POOL_ACCEPTED_LINES: [
			"Good. Thank you.",
			"Understood. That helps.",
		],
		POOL_DECLINED_LINES: [
			"Fine. Another time.",
			"Understood.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When you've done it, come back.",
			"No rush. Just do it properly.",
		],
		POOL_READY_LINES: [
			"You have it? Good.",
			"Right. Hand it over.",
		],
		POOL_COMPLETED_LINES: [
			"Good. That's one less weakness.",
			"Thanks. That will keep us sharp.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"You've held your end. I don't forget that.",
			"Standards met. Again. Thank you.",
		],
	},
	"Branik": {
		POOL_TITLES_ITEM_DELIVERY: [
			"Something warm.",
			"For comfort's sake.",
			"A camp kindness.",
			"Someone needs looking after.",
			"A small mercy.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"Check on them for me.",
			"A kind word.",
			"See if they're alright.",
			"I need you to see they're really okay.",
			"Comfort. They won't ask. I'm asking you.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"provisions": [
				"If you can spare %d x %s, bring it by. A fed camp complains less and heals quicker.",
				"I need %d x %s. Food and warmth solve more problems than pride ever will.",
			],
			"morale": [
				"Bring me %d x %s if you can. Small comforts keep the dark from settling too deep.",
				"I could use %d x %s. Nothing grand—just enough to make camp feel human again.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"camp_comfort": [
				"Check on %s for me, would you? Some people don't ask for comfort even when they badly need it.",
				"Have a word with %s. Nothing heavy—just make sure they're eating, resting, and not folding in on themselves.",
			],
		},
		POOL_OFFER_LINES: [
			"Mind helping me look after someone?",
			"I've got a small, human sort of favor.",
			"Could use a kind pair of hands.",
			"I trust you with this. Someone needs a friend.",
			"This one's personal. Can you help?",
		],
		POOL_ACCEPTED_LINES: [
			"Thank you. That's good of you.",
			"Appreciate it. Truly.",
		],
		POOL_DECLINED_LINES: [
			"No harm done.",
			"Alright. Maybe later.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When you've seen to it, come by.",
			"No hurry. Just do it with care.",
		],
		POOL_READY_LINES: [
			"You've got it? Thank you kindly.",
			"Good. That's a relief.",
		],
		POOL_COMPLETED_LINES: [
			"Thanks. That'll make things easier around here.",
			"You're good people. Thanks again.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"Thank you. You make this place feel more livable.",
			"I'm grateful. You've got a good heart for this work.",
			"You've looked after the vulnerable. I don't forget that.",
			"Thanks. You're one of the few I'd ask twice.",
		],
	},
	"Liora": {
		POOL_TITLES_ITEM_DELIVERY: [
			"For the infirmary.",
			"A gentle remedy.",
			"Herbs and rest.",
			"Someone who needs it most.",
			"A quiet kindness.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"See how they are.",
			"A gentle check.",
			"Tend to their spirits.",
			"I need you to reach someone I can't.",
			"Spiritual fatigue. They need a friend.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"healing": [
				"If you can spare %d x %s, I'd put it to good use. The camp is never as whole as it tries to appear.",
				"I need %d x %s for wounds and weariness. Healing has a thousand small hungers.",
			],
			"reagents": [
				"Bring me %d x %s, if you can. Some remedies begin quietly, long before anyone asks for them.",
				"I could use %d x %s. Herbs and mixtures are easier to prepare before the need turns urgent.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"wellness_check": [
				"Please check on %s for me. I want to know how they're holding in body and spirit, not merely whether they insist they're fine.",
				"Have a gentle word with %s. Some hurts sit deeper than bandages can reach.",
			],
		},
		POOL_OFFER_LINES: [
			"When you have a moment, I'd ask a kindness.",
			"There is something I'd rather not leave unattended.",
			"Could you help me tend to a quiet need?",
			"I'm asking you because I trust you with what's fragile.",
			"This one matters to me. Will you help?",
		],
		POOL_ACCEPTED_LINES: [
			"Thank you. That eases my heart.",
			"I'm grateful. Truly.",
		],
		POOL_DECLINED_LINES: [
			"I understand.",
			"That's alright. Another time.",
		],
		POOL_IN_PROGRESS_LINES: [
			"Take your time. Care should never be rushed.",
			"I'll be here when you're ready.",
		],
		POOL_READY_LINES: [
			"You brought it? Thank you.",
			"That helps more than you know.",
		],
		POOL_COMPLETED_LINES: [
			"Thank you. You've done a real kindness.",
			"I'm grateful. This will do some good.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"Thank you again. You've become a balm in more ways than one.",
			"I'm grateful for you. You help me keep this camp gentler than war deserves.",
			"You've carried emotional weight I couldn't. Thank you.",
			"I trust you with the ones who need it most. Don't forget that.",
		],
	},
	"Nyx": {
		POOL_TITLES_ITEM_DELIVERY: [
			"A few useful things.",
			"For quieter work.",
			"Odds and ends.",
			"Something I need handled right.",
			"Between us.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"Read the room.",
			"See what they say.",
			"Sound them out.",
			"I need your read. Not theirs.",
			"Trust. I'm asking you.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"records": [
				"If you can spare %d x %s, bring it to me. Information likes better tools than people think.",
				"I need %d x %s. Little things make quiet work cleaner.",
			],
			"reagents": [
				"Bring me %d x %s if you find it. Powders, inks, odd scraps—useful things rarely look heroic.",
				"I could use %d x %s. The camp tells on itself if you know how to listen properly.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"read_mood": [
				"I need your read on %s. Not their words—the pressure underneath them.",
				"Talk to %s and listen between the lines. I want to know what they're holding back.",
			],
		},
		POOL_OFFER_LINES: [
			"I need someone observant.",
			"A small errand, if you've got subtlety.",
			"Care to help me learn something useful?",
			"I'm asking you because I need the truth, not the performance.",
			"This one's between us. Can you do it?",
		],
		POOL_ACCEPTED_LINES: [
			"Good. I thought you might.",
			"Clever. I appreciate it.",
		],
		POOL_DECLINED_LINES: [
			"Fair enough.",
			"Shame. Another time.",
		],
		POOL_IN_PROGRESS_LINES: [
			"Take your time. The details matter more than speed.",
			"Come back when you've got something worth saying.",
		],
		POOL_READY_LINES: [
			"You've got it? Good.",
			"Perfect. Let's hear it.",
		],
		POOL_COMPLETED_LINES: [
			"Useful. Thank you.",
			"You noticed what mattered. Good.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"You've earned more of my trust. Don't waste it.",
			"We're square. For now. I don't say that often.",
		],
	},
	"Sorrel": {
		POOL_TITLES_ITEM_DELIVERY: [
			"Notes or samples.",
			"For study.",
			"A technical need.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"Clarify a point.",
			"Ask them for me.",
			"I need their read.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"records": [
				"If you can spare %d x %s, bring it to me. A proper record is often the difference between guessing and knowing.",
				"I need %d x %s. Notes, charcoal, paper—small things, but knowledge is built from small things.",
			],
			"reagents": [
				"Bring me %d x %s if you can. Samples and reagents have a way of answering questions people would rather avoid.",
				"I could use %d x %s. I'd like to test something before the trail goes cold.",
			],
			"tools": [
				"I need %d x %s for careful work. Precision dislikes improvisation.",
				"If you can spare %d x %s, I'd appreciate it. Technical tasks punish sloppiness.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"notes_reagents": [
				"Please speak with %s for me. I need their observation, not their guess.",
				"Have a word with %s. There is a detail I'd like clarified, and they may have seen what I did not.",
			],
		},
		POOL_OFFER_LINES: [
			"I need a small practical assist.",
			"A brief inquiry, if you please.",
			"There is something I'd like checked properly.",
		],
		POOL_ACCEPTED_LINES: [
			"Excellent. My thanks.",
			"Noted. I appreciate the help.",
		],
		POOL_DECLINED_LINES: [
			"Understood.",
			"No matter. I'll adjust.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When you have the result, return to me.",
			"Accuracy first. Speed can wait.",
		],
		POOL_READY_LINES: [
			"Ah. Good.",
			"You have it? Excellent.",
		],
		POOL_COMPLETED_LINES: [
			"My thanks. That's useful.",
			"Excellent. This gives me something solid to work with.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"My thanks again. You've become one of the few people whose observations I trust quickly.",
			"I appreciate your consistency. Reliable information is rarer than it should be.",
		],
	},
	"Darian": {
		POOL_TITLES_ITEM_DELIVERY: [
			"A touch of morale.",
			"For appearances, naturally.",
			"A civilizing detail.",
			"Something to hold the fracture.",
			"Between us.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"Smooth this over.",
			"A graceful word.",
			"Delicate business.",
			"I need your touch. The fracture's real.",
			"Morale. I'm trusting you with it.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"morale": [
				"If you can spare %d x %s, bring it to me. Morale rarely announces itself when it's fading.",
				"I need %d x %s. A little elegance keeps a hard camp from becoming an ugly one.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"social_errands": [
				"Have a word with %s for me. Nothing dramatic—just enough grace to keep a small crack from widening.",
				"Please speak with %s. A delicate nudge now may spare us a louder mess later.",
			],
		},
		POOL_OFFER_LINES: [
			"I have a small matter of finesse.",
			"Would you lend me your tact for a moment?",
			"There is a social wrinkle worth smoothing.",
		],
		POOL_ACCEPTED_LINES: [
			"Splendid.",
			"You do make refinement look easy.",
		],
		POOL_DECLINED_LINES: [
			"Alas. Another time, then.",
			"No matter. Grace survives disappointment.",
		],
		POOL_IN_PROGRESS_LINES: [
			"See it done with a light touch.",
			"When the matter is softened, return to me.",
		],
		POOL_READY_LINES: [
			"Lovely. Let's settle it properly.",
			"Perfect timing.",
		],
		POOL_COMPLETED_LINES: [
			"Splendid work.",
			"My thanks. That was elegantly handled.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"My thanks again. You have a finer touch than most.",
			"Truly, you make these small salvations look effortless.",
		],
	},
	"Celia": {
		POOL_TITLES_ITEM_DELIVERY: [
			"Gear order.",
			"Quiet protection.",
			"Set things right.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"A necessary word.",
			"See that they're set.",
			"Quiet correction.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"maintenance": [
				"If you have %d x %s to spare, bring it to me. Neglect begins quietly and kills loudly.",
				"I need %d x %s for gear order. Better to correct a weakness here than bury it later.",
			],
			"tools": [
				"Bring me %d x %s if you can. Proper tools spare us sloppier solutions.",
				"I could use %d x %s. There are things I'd rather set right before they become urgent.",
			],
			"fortification": [
				"If you can spare %d x %s, do so. Protection is built from small preparations no one remembers until they fail.",
				"I need %d x %s. Quiet defenses are still defenses.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"gear_order": [
				"Speak with %s for me. I want to know they're equipped, steady, and not ignoring the obvious.",
				"Have a quiet word with %s. Protection begins with the things people think they'll fix later.",
			],
		},
		POOL_OFFER_LINES: [
			"I have a task that needs doing properly.",
			"This is small, but not unimportant.",
			"I need help correcting a weakness.",
		],
		POOL_ACCEPTED_LINES: [
			"Acknowledged.",
			"Good. Thank you.",
		],
		POOL_DECLINED_LINES: [
			"Understood.",
			"Very well.",
		],
		POOL_IN_PROGRESS_LINES: [
			"Report back when it's done.",
			"Take care of it properly, then return.",
		],
		POOL_READY_LINES: [
			"Good. Hand it over.",
			"Understood. Let's finish this.",
		],
		POOL_COMPLETED_LINES: [
			"Well handled.",
			"Thank you. That closes one gap.",
		],
	},
	"Rufus": {
		POOL_TITLES_ITEM_DELIVERY: [
			"Tools. Parts.",
			"Fix the problem.",
			"Need components.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"Talk to them.",
			"Sort it out.",
			"Get the answer.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"tools": [
				"If you can spare %d x %s, bring it over. Things break. I'd rather be ahead of it for once.",
				"I need %d x %s. The glamorous work of not having equipment fail is still work.",
			],
			"reagents": [
				"Bring me %d x %s if you can. Powder, solvent, odd bits—none of it matters until it suddenly matters a lot.",
				"I could use %d x %s. The practical world runs on tedious components and foul-smelling surprises.",
			],
			"provisions": [
				"If you've got %d x %s to spare, bring it by. Working hungry is how people lose fingers and blame fate.",
				"I need %d x %s. Men work worse when they're half-fed and twice-proud.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"tools_parts": [
				"Talk to %s for me. Find out what's missing, what's broken, and what they're pretending can wait.",
				"Have a word with %s. I need the practical truth, not optimism.",
			],
		},
		POOL_OFFER_LINES: [
			"I've got a practical annoyance.",
			"Need a hand solving something boring and important.",
			"Quick favor. Useful kind, not pretty kind.",
		],
		POOL_ACCEPTED_LINES: [
			"Good. Appreciate it.",
			"That helps more than I'd like to admit.",
		],
		POOL_DECLINED_LINES: [
			"Fine.",
			"Next time, then.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When you've got it, bring it by.",
			"No rush. I'd rather it be right than fast.",
		],
		POOL_READY_LINES: [
			"Good. That's what I needed.",
			"Right. Hand it over.",
		],
		POOL_COMPLETED_LINES: [
			"That solves it. Thanks.",
			"Appreciate it. One less headache.",
		],
	},
	"Inez": {
		POOL_TITLES_ITEM_DELIVERY: [
			"At the edge of camp.",
			"Watchline needs.",
			"For the rough ground.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"Eyes on them.",
			"See how they move.",
			"Check the edge.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"animal_care": [
				"If you can spare %d x %s, bring it to me. Living things at the edge of camp need tending too.",
				"I need %d x %s. Feed, salve, tack—neglect shows quickest in beasts and nerves.",
			],
			"fortification": [
				"Bring me %d x %s if you can. The edges of a camp tell you first when something's wrong.",
				"I need %d x %s for the watchline. Small repairs keep bad nights from turning worse.",
			],
			"provisions": [
				"If you've got %d x %s, bring it by. Out on the edges, hunger makes people careless fast.",
				"I need %d x %s. The rougher posts shouldn't always have the leanest hands.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"watch_lines": [
				"Keep an eye on %s for me. I want to know whether they're alert or just pretending at it.",
				"Talk to %s and see how they carry themselves. The edge of camp notices weakness before the center does.",
			],
		},
		POOL_OFFER_LINES: [
			"I need eyes or hands on something.",
			"Small favor. Edge-of-camp sort.",
			"Got something that needs watching.",
		],
		POOL_ACCEPTED_LINES: [
			"Good.",
			"Thanks. That saves me time.",
		],
		POOL_DECLINED_LINES: [
			"Alright.",
			"Another time, then.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When it's done, come find me.",
			"Take your time. Just keep your eyes open.",
		],
		POOL_READY_LINES: [
			"You've got it? Good.",
			"Right. Let's finish it.",
		],
		POOL_COMPLETED_LINES: [
			"Good. You came through.",
			"Thanks. That helps keep the edges honest.",
		],
	},
	"Tariq": {
		POOL_TITLES_ITEM_DELIVERY: [
			"Clarify the matter.",
			"Notes and oddments.",
			"For a pointed inquiry.",
			"The question that matters.",
			"Truth. Not politeness.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"Ask the question.",
			"A pointed word.",
			"Clarify their meaning.",
			"I need you to ask what I can't.",
			"Difficult questions. Your specialty.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"records": [
				"If you can spare %d x %s, bring it to me. A proper question deserves better tools than memory and guesswork.",
				"I need %d x %s. Notes have a way of exposing what people hoped would stay vague.",
			],
			"reagents": [
				"Bring me %d x %s if you can. Arcane work is mostly patience, ink, and things that smell regrettable.",
				"I could use %d x %s. There is a line of thought I'd rather test than merely argue about.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"pointed_conversations": [
				"Have a word with %s for me. I need clarity, not politeness.",
				"Speak with %s. Ask the question directly and come back with the answer they tried not to give.",
			],
		},
		POOL_OFFER_LINES: [
			"I need something clarified.",
			"A brief favor, if you're capable of listening properly.",
			"There is a small ambiguity irritating me.",
			"I need the pointed truth. You're the one who'll get it.",
			"Between us—I need this asked. Properly.",
		],
		POOL_ACCEPTED_LINES: [
			"Good. That saves time.",
			"Appreciated. Try to come back with something useful.",
		],
		POOL_DECLINED_LINES: [
			"How disappointing.",
			"Very well. I'll endure the uncertainty a while longer.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When you've got a real answer, return.",
			"Take your time. Precision is rarer than enthusiasm.",
		],
		POOL_READY_LINES: [
			"You've got it? Excellent.",
			"Good. Let's remove the ambiguity.",
		],
		POOL_COMPLETED_LINES: [
			"Useful. Thank you.",
			"That is, annoyingly, exactly what I needed.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"You've given me the harder truths. I don't forget that.",
			"We're clear. You and I. That's worth something.",
		],
	},
	"Mira Ashdown": {
		POOL_TITLES_ITEM_DELIVERY: [
			"Quiet patrol need.",
			"For the watch.",
			"A small practical task.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"Check on them quietly.",
			"A careful word.",
			"See how they hold.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"provisions": [
				"If you can spare %d x %s, bring it by. The quieter posts always seem to run short first.",
				"I need %d x %s. Patrol work goes poorly when people start pretending they don't need basics.",
			],
			"fortification": [
				"Bring me %d x %s if you can. The lines hold best when someone notices the little weaknesses early.",
				"I could use %d x %s. A small repair now spares a larger mess later.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"quiet_tasks": [
				"Check in on %s for me, would you? Nothing dramatic. I just want to know how they're really doing.",
				"Have a quiet word with %s. Some people look steadier than they feel.",
			],
		},
		POOL_OFFER_LINES: [
			"I need a quiet favor.",
			"Could you help me with something small?",
			"I'd appreciate a careful hand with this.",
		],
		POOL_ACCEPTED_LINES: [
			"Thank you.",
			"I appreciate it. Really.",
		],
		POOL_DECLINED_LINES: [
			"That's alright.",
			"Understood. Maybe later.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When it's done, come find me.",
			"No rush. Just be careful with it.",
		],
		POOL_READY_LINES: [
			"You have it? Thank you.",
			"Good. That helps.",
		],
		POOL_COMPLETED_LINES: [
			"Thanks. That settles my mind a little.",
			"I appreciate it. Quiet work matters.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"Thank you again. You've made it easier to trust my worries to someone else.",
			"I'm grateful. You handle quiet things gently.",
		],
	},
	"Pell Rowan": {
		POOL_TITLES_ITEM_DELIVERY: [
			"Let me be useful.",
			"A small help.",
			"I can do my part.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"Could you ask them?",
			"Help me with this?",
			"A word, for my sake.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"provisions": [
				"If you can spare %d x %s, bring it by. I'd like to help without making a mess of it for once.",
				"I need %d x %s. It isn't much, but I'd like to prove I can be useful in the small things too.",
			],
			"tools": [
				"Bring me %d x %s if you can. I want to help properly, not just hover until somebody sighs.",
				"I could use %d x %s. I'd rather earn my keep than be told I'm trying too hard again.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"prove_useful": [
				"Could you speak with %s for me? I'd like to help, but I don't want to blunder into it.",
				"Have a word with %s. Help me figure out where I can actually do some good.",
			],
		},
		POOL_OFFER_LINES: [
			"Could you help me with something?",
			"I want to do this right.",
			"I've got a favor to ask, if that's alright.",
		],
		POOL_ACCEPTED_LINES: [
			"Thank you. Really.",
			"I appreciate it more than you think.",
		],
		POOL_DECLINED_LINES: [
			"That's okay.",
			"Right. Maybe later, then.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When you can, come back to me.",
			"I'll be here. No pressure. Well—some pressure.",
		],
		POOL_READY_LINES: [
			"You did it? Thank you.",
			"Oh—good. Really, thank you.",
		],
		POOL_COMPLETED_LINES: [
			"Thanks again. That means a lot.",
			"I appreciate it. I really do.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"Thank you again. You make it easier to believe I might actually grow into this.",
			"I mean it. You've helped me more than just with the task.",
		],
	},
	"Tamsin Reed": {
		POOL_TITLES_ITEM_DELIVERY: [
			"For the wounded.",
			"Remedies and rest.",
			"A healer's need.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"Check on them gently.",
			"See how they're healing.",
			"A soft word.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"healing": [
				"If you can spare %d x %s, bring it to me. Healing burns through supplies faster than most people realize.",
				"I need %d x %s. Bandages and remedies vanish in handfuls when people start saying they're 'fine.'",
			],
			"reagents": [
				"Bring me %d x %s if you can. A little preparation now spares panic later.",
				"I could use %d x %s. Herbs and mixtures are easier to tend before exhaustion turns sharp.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"wellness_check": [
				"Please check on %s for me. I want to know whether they're healing, not merely enduring.",
				"Have a gentle word with %s. Some people hide pain because they think it inconveniences the rest of us.",
			],
		},
		POOL_OFFER_LINES: [
			"Could I ask a small kindness?",
			"I need help tending to something before it worsens.",
			"When you have a moment, please.",
		],
		POOL_ACCEPTED_LINES: [
			"Thank you. That helps more than you know.",
			"I'm grateful. Truly.",
		],
		POOL_DECLINED_LINES: [
			"I understand.",
			"That's alright. Another time, perhaps.",
		],
		POOL_IN_PROGRESS_LINES: [
			"Take your time. Care shouldn't be rushed.",
			"I'll be here when you've seen to it.",
		],
		POOL_READY_LINES: [
			"You brought it? Thank you kindly.",
			"That will help. Thank you.",
		],
		POOL_COMPLETED_LINES: [
			"Thank you. This will do real good.",
			"I'm grateful. You've eased my work.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"Thank you again. You've become someone I can trust around fragile things.",
			"I'm grateful for you. You help me keep people a little safer.",
		],
	},
	"Hest \"Sparks\"": {
		POOL_TITLES_ITEM_DELIVERY: [
			"Where did that go?",
			"A tiny disaster.",
			"Missing, obviously.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"See what they know.",
			"Go poke around.",
			"Ask before it gets weird.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"provisions": [
				"If you can spare %d x %s, bring it over. Something wandered off, and somehow that became my problem.",
				"I need %d x %s. Don't ask why. Actually, do ask—but later.",
			],
			"reagents": [
				"Bring me %d x %s if you find any. Something fizzed, something vanished, and now I'd like to prevent a sequel.",
				"I could use %d x %s. The camp keeps producing odd shortages in the most suspiciously funny places.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"chaotic_errands": [
				"Go talk to %s for me. I want to know what they saw, heard, broke, or failed to admit.",
				"Have a word with %s. Something's off, and I'd like a version of events before rumor gets there first.",
			],
		},
		POOL_OFFER_LINES: [
			"Quick favor before this gets worse.",
			"I need help with a very specific inconvenience.",
			"Got a little camp mystery for you.",
		],
		POOL_ACCEPTED_LINES: [
			"Excellent.",
			"Knew you'd be fun to ask.",
		],
		POOL_DECLINED_LINES: [
			"Tragic.",
			"Alright, but if this explodes later I'm blaming fate.",
		],
		POOL_IN_PROGRESS_LINES: [
			"Come back when you've got something.",
			"Take your time. Chaos isn't going anywhere.",
		],
		POOL_READY_LINES: [
			"You actually found it? Nice.",
			"Perfect. Hand it over before it vanishes again.",
		],
		POOL_COMPLETED_LINES: [
			"Beautiful. Crisis downgraded.",
			"Thanks. That's one less little fire to stomp out.",
		],
	},
	"Brother Alden": {
		POOL_TITLES_ITEM_DELIVERY: [
			"A practical kindness.",
			"For peace's sake.",
			"A quiet aid.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"See if peace can hold.",
			"A gentle mediation.",
			"Check on them kindly.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"provisions": [
				"If you can spare %d x %s, bring it by. Hunger sharpens tempers faster than any sermon can dull them.",
				"I need %d x %s. Peace is easier to tend when people are warm and fed.",
			],
			"healing": [
				"Bring me %d x %s if you can. There are small hurts around camp that shouldn't have to wait their turn.",
				"I could use %d x %s. Practical aid often reaches where words cannot.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"mediation": [
				"Please speak with %s for me. I would know whether they need comfort, counsel, or simply someone willing to listen.",
				"Have a word with %s. Sometimes peace begins with one person feeling seen before the rest of us ask anything of them.",
			],
		},
		POOL_OFFER_LINES: [
			"I would ask a practical kindness.",
			"There is a small matter of peace I could use help with.",
			"When you have a moment, please.",
		],
		POOL_ACCEPTED_LINES: [
			"My thanks.",
			"Peace be with you, and thank you.",
		],
		POOL_DECLINED_LINES: [
			"I understand.",
			"Another time, then. No harm done.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When it's done, return to me.",
			"Take your time. Gentle things cannot be hurried.",
		],
		POOL_READY_LINES: [
			"You've done it? Thank you.",
			"Good. That helps more than it may seem.",
		],
		POOL_COMPLETED_LINES: [
			"My thanks. You have done a quiet good.",
			"Peace. That mattered.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"Thank you again. You bring a steadiness this camp sorely needs.",
			"I'm grateful. You make kindness easier to keep alive here.",
		],
	},
	"Oren Pike": {
		POOL_TITLES_ITEM_DELIVERY: [
			"Missing components.",
			"Maintenance again.",
			"Tools, naturally.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"Get the practical truth.",
			"Ask what broke.",
			"Sort out the problem.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"tools": [
				"If you can spare %d x %s, bring it over. Things don't fix themselves, no matter how passionately people ignore them.",
				"I need %d x %s. Every missing tool becomes my problem eventually.",
			],
			"maintenance": [
				"Bring me %d x %s if you can. I'd like to repair something before it chooses a dramatic moment to fail.",
				"I could use %d x %s. Maintenance is dull right up until it becomes urgent.",
			],
			"reagents": [
				"If you've got %d x %s, bring it by. Grease, solvent, odd compounds—annoying things, useful things.",
				"I need %d x %s. Turns out the world runs on little parts and uglier substances.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"tools_components": [
				"Talk to %s for me. I need to know what's actually missing, not what they're guessing about.",
				"Have a word with %s. Find out what broke, what's loose, and what they're pretending can wait.",
			],
		},
		POOL_OFFER_LINES: [
			"I've got a practical problem.",
			"Need help with something that should've been simple.",
			"Quick favor. Irritating kind.",
		],
		POOL_ACCEPTED_LINES: [
			"Good. Thanks.",
			"That'll save me some trouble.",
		],
		POOL_DECLINED_LINES: [
			"Fine.",
			"I'll sort it another way.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When you've got it, bring it by.",
			"No hurry. I'd rather fix it once.",
		],
		POOL_READY_LINES: [
			"You've got it? About time.",
			"Good. Hand it over.",
		],
		POOL_COMPLETED_LINES: [
			"That helps. Thanks.",
			"Good. One less thing rattling loose.",
		],
	},
	"Garrick Vale": {
		POOL_TITLES_ITEM_DELIVERY: [
			"Patrol and order.",
			"For the line.",
			"Protocol matters.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"A duty word.",
			"Check their readiness.",
			"Mind the order of things.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"fortification": [
				"If you can spare %d x %s, bring it to me. Order is built from the things people forget until the weather turns or the line breaks.",
				"I need %d x %s. Patrol and fortification both fail first at the neglected edges.",
			],
			"maintenance": [
				"Bring me %d x %s if you can. A disciplined line is only as sound as its least tended detail.",
				"I could use %d x %s. Order rarely collapses loudly at first.",
			],
			"records": [
				"If you've got %d x %s, bring it by. Reports are tedious until not having them gets someone hurt.",
				"I need %d x %s. Protocol only works if someone keeps the record straight.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"duty_conversations": [
				"Speak with %s for me. I need to know they're fit, focused, and not slipping past the standard they know better than to ignore.",
				"Have a word with %s. This is about readiness, not comfort.",
			],
		},
		POOL_OFFER_LINES: [
			"I have a matter of order to address.",
			"A brief task requiring discipline.",
			"Attend to something for me.",
		],
		POOL_ACCEPTED_LINES: [
			"Acknowledged.",
			"Good. Thank you.",
		],
		POOL_DECLINED_LINES: [
			"Understood.",
			"Very well. Carry on.",
		],
		POOL_IN_PROGRESS_LINES: [
			"Report when the task is complete.",
			"When you've seen to it, return at once.",
		],
		POOL_READY_LINES: [
			"Good. Present it.",
			"Understood. Let's conclude this.",
		],
		POOL_COMPLETED_LINES: [
			"Well handled.",
			"Thank you. That keeps the line clean.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"My thanks again. Your reliability reflects well on the whole camp.",
			"Well done. I have come to trust your follow-through.",
		],
	},
	"Sabine Varr": {
		POOL_TITLES_ITEM_DELIVERY: [
			"Defenses and details.",
			"A logistical need.",
			"Competence, please.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"See if they're sharp.",
			"A competence check.",
			"Get a useful answer.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"fortification": [
				"If you can spare %d x %s, bring it to me. Defenses are a conversation with failure conducted in advance.",
				"I need %d x %s. Logistics only look dull to people who've never watched them fail.",
			],
			"tools": [
				"Bring me %d x %s if you can. Competence is usually just the accumulation of unglamorous preparation.",
				"I could use %d x %s. I'd rather not rely on improvisation if I can help it.",
			],
			"records": [
				"If you've got %d x %s, bring it by. Vulnerabilities love poor accounting.",
				"I need %d x %s. The difference between 'manageable' and 'catastrophic' is often filed under paperwork.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"defenses_logistics": [
				"Talk to %s for me. I need to know whether they are truly prepared or merely confident.",
				"Have a word with %s. I'm after competence, not reassurance.",
			],
		},
		POOL_OFFER_LINES: [
			"I require a competent hand.",
			"There is a logistical matter worth addressing now, not later.",
			"A small weakness has my attention.",
		],
		POOL_ACCEPTED_LINES: [
			"Good.",
			"Thank you. Sensible of you.",
		],
		POOL_DECLINED_LINES: [
			"Very well.",
			"I'll make other arrangements.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When you've handled it, return.",
			"No hurry. I prefer competence to theatrics.",
		],
		POOL_READY_LINES: [
			"You have it? Excellent.",
			"Good. That closes the loop.",
		],
		POOL_COMPLETED_LINES: [
			"Useful. Thank you.",
			"Well done. That removes a liability.",
		],
	},
	"Yselle Maris": {
		POOL_TITLES_ITEM_DELIVERY: [
			"A touch of grace.",
			"For morale's sake.",
			"A civil camp is a stronger one.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"A delicate word.",
			"Smooth the tension.",
			"See how they fare.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"morale": [
				"If you can spare %d x %s, bring it to me. Morale is a shy thing; it withers before most people notice it has gone.",
				"I need %d x %s. A camp kept merely functional soon becomes a camp ready to crack.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"social_errands": [
				"Please speak with %s for me. A little grace now may spare us a sharper fracture later.",
				"Have a word with %s. I'm less interested in the official mood than in what lingers just beneath it.",
			],
		},
		POOL_OFFER_LINES: [
			"I have a small social concern.",
			"Would you lend me your tact for a moment?",
			"There is a thread worth keeping from fraying.",
		],
		POOL_ACCEPTED_LINES: [
			"Wonderful.",
			"My thanks. You do make this easier.",
		],
		POOL_DECLINED_LINES: [
			"A pity.",
			"No matter. Another time, perhaps.",
		],
		POOL_IN_PROGRESS_LINES: [
			"Handle it gently, if you would.",
			"When the air is clearer, come back to me.",
		],
		POOL_READY_LINES: [
			"Perfect. Let's settle it neatly.",
			"Ah, wonderful timing.",
		],
		POOL_COMPLETED_LINES: [
			"My thanks. That was gracefully done.",
			"Lovely work. You spared us a sharper scene.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"My thanks again. You have become one of the few people I trust with delicate matters.",
			"Truly, you make this camp easier to live in.",
		],
	},
	"Sister Meris": {
		POOL_TITLES_ITEM_DELIVERY: [
			"Records and remedy.",
			"For order's sake.",
			"A necessary provision.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"A necessary conversation.",
			"Clarify their position.",
			"See that they understand.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"records": [
				"If you can spare %d x %s, bring it to me. Records are tedious until disorder starts feeding on what no one wrote down.",
				"I need %d x %s. Discipline survives best when memory is not left to mood and convenience.",
			],
			"healing": [
				"Bring me %d x %s if you can. There are injuries that worsen because people delay the sensible thing.",
				"I could use %d x %s. Practical care should not have to compete with stubbornness.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"discipline_conversations": [
				"Speak with %s for me. I need to know whether they understand the matter clearly, not merely whether they resent it quietly.",
				"Have a necessary word with %s. Some conversations are unpleasant precisely because they are overdue.",
			],
		},
		POOL_OFFER_LINES: [
			"I require assistance with something necessary.",
			"There is a matter that should be handled plainly.",
			"I have a practical need, and little patience for delay.",
		],
		POOL_ACCEPTED_LINES: [
			"Understood. Thank you.",
			"Good. I appreciate competence.",
		],
		POOL_DECLINED_LINES: [
			"Very well.",
			"Then I will address it another way.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When it is done, return to me.",
			"Take the time required, but do not dawdle.",
		],
		POOL_READY_LINES: [
			"Good. Present it.",
			"Understood. Let us conclude this.",
		],
		POOL_COMPLETED_LINES: [
			"Accepted. Thank you.",
			"Well handled. That will suffice.",
		],
	},
	"Corvin Ash": {
		POOL_TITLES_ITEM_DELIVERY: [
			"Reagents and remnants.",
			"For a consultation.",
			"Something uncommon.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"Consult them for me.",
			"A stranger question.",
			"I need their read.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"reagents": [
				"If you can spare %d x %s, bring it to me. Some answers only appear when given the proper invitation.",
				"I need %d x %s. Reagents have a way of clarifying what ordinary thought prefers to blur.",
			],
			"records": [
				"Bring me %d x %s if you can. Notes, traces, fragments—small records often carry the shape of larger truths.",
				"I could use %d x %s. Evidence is shy, but not silent.",
			],
			"ritual": [
				"If you have %d x %s to spare, bring it by. Not every working deserves the dignity of being called a ritual, but some still require the proper pieces.",
				"I need %d x %s. Certain matters resist blunt handling.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"arcane_consultation": [
				"Speak with %s for me. I want their impression before the matter settles into a more convenient lie.",
				"Have a word with %s. There is a question I'd rather approach from the side than head-on.",
			],
		},
		POOL_OFFER_LINES: [
			"I have a small, interesting need.",
			"There is something I'd rather not leave unexamined.",
			"A curious favor, if you're willing.",
		],
		POOL_ACCEPTED_LINES: [
			"...My thanks.",
			"Good. That will be useful.",
		],
		POOL_DECLINED_LINES: [
			"As you wish.",
			"Then the question remains open a while longer.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When you have it, return.",
			"I can afford patience, if not neglect.",
		],
		POOL_READY_LINES: [
			"You have it? Good.",
			"Interesting. Let us see it.",
		],
		POOL_COMPLETED_LINES: [
			"It is noted. Thank you.",
			"You've been of use in the better sense of the phrase.",
		],
	},
	"Veska Moor": {
		POOL_TITLES_ITEM_DELIVERY: [
			"For the line.",
			"Fortification first.",
			"Drill and repair.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"See if they're reliable.",
			"A readiness check.",
			"Test the line quietly.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"fortification": [
				"If you can spare %d x %s, bring it to me. Walls and lines fail first where people assumed they were already sound.",
				"I need %d x %s. Reliability is built from repeated, unglamorous corrections.",
			],
			"maintenance": [
				"Bring me %d x %s if you can. A line that drills hard still rots if no one tends the small failures.",
				"I could use %d x %s. Readiness is maintenance with fewer excuses.",
			],
			"tools": [
				"If you have %d x %s to spare, bring it by. Proper tools save time, temper, and avoidable mistakes.",
				"I need %d x %s. I'd rather repair a weakness than lecture it.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"fortification": [
				"Speak with %s for me. I want to know whether they're dependable when no one is looking directly at them.",
				"Have a word with %s. Reliability matters more to me than enthusiasm.",
			],
		},
		POOL_OFFER_LINES: [
			"I need something handled properly.",
			"There is a weakness I'd rather correct now.",
			"A practical task, if you're up for it.",
		],
		POOL_ACCEPTED_LINES: [
			"Good.",
			"Thank you. That helps keep the line honest.",
		],
		POOL_DECLINED_LINES: [
			"Understood.",
			"Then I will manage without it.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When it's done, return.",
			"No hurry. Just do it right.",
		],
		POOL_READY_LINES: [
			"You've got it? Good.",
			"Right. Let's finish this cleanly.",
		],
		POOL_COMPLETED_LINES: [
			"Good work.",
			"Thank you. That's one less weak point.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"Thank you again. You make reliability easier to expect.",
			"Good work. I've come to trust your follow-through.",
		],
	},
	"Ser Hadrien": {
		POOL_TITLES_ITEM_DELIVERY: [
			"For memory's sake.",
			"A quiet necessity.",
			"Something for the long burden.",
			"Endurance. I need your help with it.",
			"Between us.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"A solemn check.",
			"See if they stand steady.",
			"A word of duty.",
			"Memory and grief. I need you to see them.",
			"Duty that doesn't show. Will you go?",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"records": [
				"If you can spare %d x %s, bring it to me. Memory frays faster than duty does, and both suffer when neglected.",
				"I need %d x %s. Some burdens are lighter when the record is kept true.",
			],
			"ritual": [
				"Bring me %d x %s if you can. There are things best approached with a proper stillness.",
				"I could use %d x %s. Not for spectacle—only for keeping faith with what ought not be forgotten.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"solemn_check": [
				"Please speak with %s for me. I need to know whether they still stand firm beneath what they carry.",
				"Have a quiet word with %s. Some duties grow heavier in silence, and I would know if theirs has done so.",
			],
		},
		POOL_OFFER_LINES: [
			"I would ask a quiet favor.",
			"There is a matter I should not leave untended.",
			"I need something seen to with care.",
			"I'm asking you because you don't flinch from the weight.",
			"This one carries grief. Will you check on them?",
		],
		POOL_ACCEPTED_LINES: [
			"Thank you. I do mean that.",
			"I am in your debt for the help.",
		],
		POOL_DECLINED_LINES: [
			"Understood.",
			"Another time, perhaps.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When it is done, come back to me.",
			"Take the time it asks of you.",
		],
		POOL_READY_LINES: [
			"You've done it? Thank you.",
			"Then let us settle this quietly.",
		],
		POOL_COMPLETED_LINES: [
			"My thanks.",
			"It means more than I care to dress in easier words.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"You've carried the solemn with me. I won't forget.",
			"Thank you. Endurance shared is endurance halved.",
		],
	},
	"Maela Thorn": {
		POOL_TITLES_ITEM_DELIVERY: [
			"Quick and useful.",
			"Keep things moving.",
			"A fast favor.",
		],
		POOL_TITLES_TALK_TO_UNIT: [
			"Carry the word.",
			"Go shake them awake.",
			"Fast message.",
		],
		POOL_DESC_ITEM_DELIVERY: {
			"morale": [
				"If you can spare %d x %s, bring it by. A little energy at the right moment can turn the whole camp around.",
				"I need %d x %s. Doesn't have to be grand—just enough to keep people from dragging their feet.",
			],
			"provisions": [
				"Bring me %d x %s if you can. Hard to keep momentum when everyone's running on fumes.",
				"I could use %d x %s. Fast hands still need feeding.",
			],
		},
		POOL_DESC_TALK_TO_UNIT: {
			"messenger_errands": [
				"Get a message to %s for me. Quick, clean, no wandering off halfway through.",
				"Have a word with %s. I need the message delivered before the moment goes stale.",
			],
		},
		POOL_OFFER_LINES: [
			"Quick favor for you.",
			"I need something handled with speed.",
			"Got a small job with some momentum behind it.",
		],
		POOL_ACCEPTED_LINES: [
			"Perfect.",
			"Nice. Knew you wouldn't drag your feet.",
		],
		POOL_DECLINED_LINES: [
			"Ah, shame.",
			"Alright. I'll find another pair of legs.",
		],
		POOL_IN_PROGRESS_LINES: [
			"When it's done, come find me fast.",
			"Keep it moving and come back.",
		],
		POOL_READY_LINES: [
			"You got it done? Nice.",
			"Perfect timing. Hand it over.",
		],
		POOL_COMPLETED_LINES: [
			"Thanks! That kept things moving.",
			"Nicely done. That's exactly the pace I wanted.",
		],
		POOL_COMPLETED_WARM_LINES: [
			"Thanks again. You make speed look dependable, which is rarer than you'd think.",
			"I knew I could count on your pace. Appreciate it.",
		],
	},
}

# --- Branching check content: [challenge_style][challenge_state] -> opening_line, choices (text, result_line, outcome). ---
# outcome: "success" | "fail". Exactly 3 choices per entry. Fair: correct answer follows from target's emotional state.
static var BRANCHING_CHECKS: Dictionary = {
	"wellness_check": {
		"patience_indirect": {
			"opening_line": "They look worn. Something is weighing on them, but they haven't asked for help.",
			"choices": [
				{"text": "Stay nearby without pressing; ask once if there's anything they need.", "result_line": "They nod slowly. \"Just... someone noticing. That helps. I'm managing.\"", "outcome": "success"},
				{"text": "Tell them they should rest more and take care of themselves.", "result_line": "They stiffen. \"I don't need to be managed. Leave it.\"", "outcome": "fail"},
				{"text": "Give them a moment of quiet, then ask gently how they're holding up.", "result_line": "They relax a fraction. \"...Alright. Thanks for asking.\"", "outcome": "success"},
			],
		},
		"direct_reassurance": {
			"opening_line": "They seem tired. You catch their eye and they don't look away.",
			"choices": [
				{"text": "Ask plainly: \"How are you, really?\"", "result_line": "They let out a breath. \"Better for you asking. Thanks.\"", "outcome": "success"},
				{"text": "Tell them everything will be fine and to keep their chin up.", "result_line": "They shut down. \"You don't know that. Don't.\"", "outcome": "fail"},
				{"text": "Say you're here if they want to talk; no pressure.", "result_line": "They nod. \"I appreciate it. I'm okay—but thank you.\"", "outcome": "success"},
			],
		},
		"solemn_patience": {
			"opening_line": "They stand apart. The weight they carry is not something they speak of lightly.",
			"choices": [
				{"text": "Stand with them in silence for a moment before speaking.", "result_line": "After a pause, they speak quietly. \"...Thank you. I'm still standing. I'll be alright.\"", "outcome": "success"},
				{"text": "Try to lighten the mood so they don't dwell on it.", "result_line": "They turn away. \"Don't. Some things aren't for cheering.\"", "outcome": "fail"},
				{"text": "Ask once, with gravity, if they need anything.", "result_line": "A slight nod. \"No. But I'm grateful you asked.\"", "outcome": "success"},
			],
		},
		"light_touch": {
			"opening_line": "They're a bit run-down but not broken. They notice you approaching.",
			"choices": [
				{"text": "Offer a small kindness without making it heavy.", "result_line": "They grin faintly. \"Yeah. That helps. Thanks.\"", "outcome": "success"},
				{"text": "Press them on what's wrong until they answer.", "result_line": "They back off. \"Back off. I'm not in the mood.\"", "outcome": "fail"},
				{"text": "Check in with a light touch—concern without drama.", "result_line": "They nod. \"I'm good. Just needed a second. Thanks.\"", "outcome": "success"},
			],
		},
		"perceptive_indirect": {
			"opening_line": "They're guarded but not hostile. They're watching to see how you'll approach.",
			"choices": [
				{"text": "Acknowledge you're checking in; leave room for them to answer or not.", "result_line": "A short nod. \"Noted. I'm fine. Thanks.\"", "outcome": "success"},
				{"text": "Confront them: something's wrong and they should say what.", "result_line": "They shut down. \"We're done here.\"", "outcome": "fail"},
				{"text": "Notice they're carrying something; say you're here if they want to talk.", "result_line": "A flicker of something. \"...Maybe. Thanks.\"", "outcome": "success"},
			],
		},
		"respectful_clarity": {
			"opening_line": "They look strained. They'd rather the matter be named than danced around.",
			"choices": [
				{"text": "Ask directly and calmly: \"Are you alright? Do you need anything?\"", "result_line": "They meet your eyes. \"I will be. Thank you for asking clearly.\"", "outcome": "success"},
				{"text": "Hint that they seem off and wait for them to volunteer more.", "result_line": "They're impatient. \"If you have a question, ask it.\"", "outcome": "fail"},
				{"text": "Name what you see: they're under weight. Ask if you can help.", "result_line": "A nod. \"I'm managing. I appreciate the clarity.\"", "outcome": "success"},
			],
		},
		"graceful_social": {
			"opening_line": "They're worn but composed. They notice you and don't deflect.",
			"choices": [
				{"text": "Approach with tact; ask after their wellbeing without prying.", "result_line": "They soften. \"Thank you. I'm well enough. Your concern is noted.\"", "outcome": "success"},
				{"text": "Bluntly ask what's wrong.", "result_line": "They stiffen. \"There are ways to ask. That wasn't one of them.\"", "outcome": "fail"},
				{"text": "Offer a graceful opening: you're here if they wish to speak.", "result_line": "A slight smile. \"I appreciate it. I shall be fine.\"", "outcome": "success"},
			],
		},
	},
	"read_mood": {
		"patience_indirect": {
			"opening_line": "They're not giving much away. Something sits beneath the surface.",
			"choices": [
				{"text": "Give them space but stay present; let them speak if they choose.", "result_line": "Eventually they say, quietly: \"I'm managing. Thanks for not pushing.\"", "outcome": "success"},
				{"text": "Demand to know what they're thinking.", "result_line": "They clam up. \"None of your business.\"", "outcome": "fail"},
				{"text": "Ask one careful, open question and wait for their answer.", "result_line": "They answer in kind. \"Enough. I'll be alright. Thank you.\"", "outcome": "success"},
			],
		},
		"direct_reassurance": {
			"opening_line": "Something's on their mind. They don't seem to want to hide it, only to be asked rightly.",
			"choices": [
				{"text": "Ask straight out: \"You seem off. Are you okay?\"", "result_line": "They nod. \"Yeah. Just thinking. Thanks for asking.\"", "outcome": "success"},
				{"text": "Interpret their mood and tell them what you think they feel.", "result_line": "They get defensive. \"Don't put words in my mouth.\"", "outcome": "fail"},
				{"text": "Say you've noticed something; offer to listen if they want to talk.", "result_line": "They relax a little. \"Good to know. I'm fine, but thanks.\"", "outcome": "success"},
			],
		},
		"solemn_patience": {
			"opening_line": "They're quiet. Not necessarily unhappy—something grave sits with them.",
			"choices": [
				{"text": "Respect the silence; ask once, simply, if they need anything.", "result_line": "A small shake of the head. \"No. Thank you for asking.\"", "outcome": "success"},
				{"text": "Fill the silence with talk to ease the tension.", "result_line": "They withdraw. \"I'd rather not. Leave it.\"", "outcome": "fail"},
				{"text": "Stay with them a moment without demanding answers.", "result_line": "They seem slightly easier. \"...I'm alright. Thank you.\"", "outcome": "success"},
			],
		},
		"light_touch": {
			"opening_line": "They're holding something back but not in a hostile way.",
			"choices": [
				{"text": "Keep it light: \"You seem a bit off. Want to talk or just need space?\"", "result_line": "They shrug, then nod. \"Space. But thanks for asking.\"", "outcome": "success"},
				{"text": "Push until they tell you what's wrong.", "result_line": "They shut you down. \"Drop it. I'm not in the mood.\"", "outcome": "fail"},
				{"text": "Notice they're off; offer to listen if they change their mind.", "result_line": "A brief look of thanks. \"Noted. I'm good.\"", "outcome": "success"},
			],
		},
		"perceptive_indirect": {
			"opening_line": "They're hard to read. Something's under the surface; they're waiting to see if you'll notice rightly.",
			"choices": [
				{"text": "Comment on the tension without accusing; leave room for them.", "result_line": "They weigh it. \"You're not wrong. I'll be fine. Thanks.\"", "outcome": "success"},
				{"text": "State with certainty what you think they're feeling.", "result_line": "They deflect. \"You don't know. Drop it.\"", "outcome": "fail"},
				{"text": "Listen more than you speak; ask one thing and wait.", "result_line": "They offer a sliver. \"...Things are complicated. That's all. Thanks.\"", "outcome": "success"},
			],
		},
		"respectful_clarity": {
			"opening_line": "Something's on their mind. They prefer clarity to guessing.",
			"choices": [
				{"text": "Name what you see: they're carrying something. Ask if they want to talk.", "result_line": "They nod. \"I'm dealing with it. Thank you for asking clearly.\"", "outcome": "success"},
				{"text": "Hint around the subject until they volunteer.", "result_line": "They're impatient. \"If you have a question, ask it.\"", "outcome": "fail"},
				{"text": "Ask directly and respectfully: \"Are you alright?\"", "result_line": "A short nod. \"I will be. I appreciate you asking.\"", "outcome": "success"},
			],
		},
		"graceful_social": {
			"opening_line": "They're composed but something lingers. They notice you and don't deflect.",
			"choices": [
				{"text": "Approach with tact; name that they seem troubled and offer to listen.", "result_line": "They soften. \"Thank you. I shall be well. Your concern is kind.\"", "outcome": "success"},
				{"text": "Bluntly ask what's wrong.", "result_line": "They stiffen. \"There are ways to ask. That wasn't one of them.\"", "outcome": "fail"},
				{"text": "Offer a graceful opening; say you're here if they wish to speak.", "result_line": "A slight smile. \"I appreciate it. I am well enough.\"", "outcome": "success"},
			],
		},
	},
	"mediation": {
		"patience_indirect": {
			"opening_line": "Tension around them. It's not directed at you, but it's there.",
			"choices": [
				{"text": "Give them time; then ask gently if they want to talk.", "result_line": "They soften. \"Alright. I'm managing. Thanks.\"", "outcome": "success"},
				{"text": "Confront the tension head-on and demand they address it.", "result_line": "They snap. \"Back off. You're not helping.\"", "outcome": "fail"},
				{"text": "Be present without pushing; offer a single opening.", "result_line": "They exhale. \"...Thanks. I needed that.\"", "outcome": "success"},
			],
		},
		"direct_reassurance": {
			"opening_line": "They look like they could use a calm, honest word.",
			"choices": [
				{"text": "Ask what's troubling them, simply and without preaching.", "result_line": "They take a breath. \"...Thanks. I needed that.\"", "outcome": "success"},
				{"text": "Preach at them about peace and letting go.", "result_line": "They tune out. \"Save it. That's not what I need.\"", "outcome": "fail"},
				{"text": "Listen and offer support without fixing it for them.", "result_line": "They nod. \"Peace. I'll be okay. Thank you.\"", "outcome": "success"},
			],
		},
		"solemn_patience": {
			"opening_line": "They seem burdened. The weight is real; they don't want it minimized.",
			"choices": [
				{"text": "Sit with them in silence for a moment before speaking.", "result_line": "They speak quietly. \"Thank you. That helped.\"", "outcome": "success"},
				{"text": "Tell them to look on the bright side.", "result_line": "They don't respond. The moment is lost.", "outcome": "fail"},
				{"text": "Offer a single kind word and leave room for their response.", "result_line": "They accept it. \"...I appreciate that. Thank you.\"", "outcome": "success"},
			],
		},
		"light_touch": {
			"opening_line": "Things are strained but not beyond repair. They notice you.",
			"choices": [
				{"text": "Keep it light but genuine; ask if they want to talk or need space.", "result_line": "They ease. \"Yeah. I'm good. Thanks for checking in.\"", "outcome": "success"},
				{"text": "Force a resolution and tell them to sort it out.", "result_line": "They dig in. \"Back off. Not your call.\"", "outcome": "fail"},
				{"text": "Listen and mediate with a light touch—no drama.", "result_line": "They nod. \"Thanks. That helped. We're good.\"", "outcome": "success"},
			],
		},
		"perceptive_indirect": {
			"opening_line": "They're holding something in. They're waiting to see if you'll notice without prying.",
			"choices": [
				{"text": "Acknowledge it without prying; say you're there if they want to talk.", "result_line": "They nod. \"You see it. I'm dealing. Thanks.\"", "outcome": "success"},
				{"text": "Try to fix it for them or tell them what to do.", "result_line": "They shut down. \"I don't need fixing. Leave it.\"", "outcome": "fail"},
				{"text": "Name that something's there; offer to listen.", "result_line": "A brief look of thanks. \"Noted. I appreciate it.\"", "outcome": "success"},
			],
		},
		"respectful_clarity": {
			"opening_line": "Tension is clear. They'd rather it be named than hinted at.",
			"choices": [
				{"text": "Name the tension calmly; ask if they want to talk.", "result_line": "They nod. \"I'm managing. Thank you for asking directly.\"", "outcome": "success"},
				{"text": "Hint around the subject until they open up.", "result_line": "They're impatient. \"Just ask. I'm not playing games.\"", "outcome": "fail"},
				{"text": "Ask directly and respectfully what's going on.", "result_line": "They answer. \"Enough. I'll be alright. Thanks.\"", "outcome": "success"},
			],
		},
		"graceful_social": {
			"opening_line": "There's friction, but they're composed. They notice you and don't deflect.",
			"choices": [
				{"text": "Approach with tact; name the tension and offer to help smooth it.", "result_line": "They soften. \"Thank you. I shall manage. Your concern is kind.\"", "outcome": "success"},
				{"text": "Take a side or demand they resolve it now.", "result_line": "They stiffen. \"Stay out of it. Please.\"", "outcome": "fail"},
				{"text": "Offer a graceful opening; say you're here if they wish to speak.", "result_line": "A slight nod. \"I appreciate it. We shall be well.\"", "outcome": "success"},
			],
		},
	},
	"solemn_check": {
		"patience_indirect": {
			"opening_line": "Duty weighs on them. You can see it; they haven't asked for relief.",
			"choices": [
				{"text": "Give them space; ask only if they need anything.", "result_line": "They answer quietly. \"No. I have what I need. Thank you.\"", "outcome": "success"},
				{"text": "Cheer them up or tell them to shake it off.", "result_line": "They don't respond. It wasn't what they needed.", "outcome": "fail"},
				{"text": "Acknowledge the weight without prying; offer one opening.", "result_line": "A slight nod. \"...Thank you. I'll manage.\"", "outcome": "success"},
			],
		},
		"direct_reassurance": {
			"opening_line": "They look like they're holding it together by a thread.",
			"choices": [
				{"text": "Ask directly: \"Are you alright?\"", "result_line": "They meet your eyes. \"I will be. Thanks for asking.\"", "outcome": "success"},
				{"text": "Joke to break the mood.", "result_line": "They don't smile. \"Not now. Please.\"", "outcome": "fail"},
				{"text": "Tell them you're here if they need someone.", "result_line": "A quiet \"Thank you.\" They mean it.", "outcome": "success"},
			],
		},
		"solemn_patience": {
			"opening_line": "They carry something heavy. You can feel it. They don't want it minimized.",
			"choices": [
				{"text": "Stand with them. Say nothing at first.", "result_line": "After a while: \"...Thank you. I'm still standing. I'll be alright.\"", "outcome": "success"},
				{"text": "Tell them to shake it off or look on the bright side.", "result_line": "They turn away. \"You don't understand. Don't.\"", "outcome": "fail"},
				{"text": "Ask once, with gravity, if they're steady.", "result_line": "A slow nod. \"I am. Thanks for asking.\"", "outcome": "success"},
			],
		},
		"light_touch": {
			"opening_line": "Something solemn sits with them, but they're not broken.",
			"choices": [
				{"text": "Offer a small, genuine kindness without making it heavy.", "result_line": "They nod. \"Yeah. That helps. Thanks.\"", "outcome": "success"},
				{"text": "Push for an explanation of what's wrong.", "result_line": "They close off. \"Leave it. Not now.\"", "outcome": "fail"},
				{"text": "Check in with a light touch—concern without drama.", "result_line": "A brief look of thanks. \"I'm good. Thanks for asking.\"", "outcome": "success"},
			],
		},
		"perceptive_indirect": {
			"opening_line": "Something solemn sits with them. They're waiting to see if you'll notice without pushing.",
			"choices": [
				{"text": "Notice; don't push. Offer one line: you're here if they need you.", "result_line": "They give a brief nod. \"I'm steady. Thanks. Noted.\"", "outcome": "success"},
				{"text": "Demand to know what's wrong.", "result_line": "They close off. \"Leave it.\"", "outcome": "fail"},
				{"text": "Acknowledge the weight without prying; leave room.", "result_line": "They take it in. \"...Thank you. I'll manage.\"", "outcome": "success"},
			],
		},
		"respectful_clarity": {
			"opening_line": "Duty and memory weigh on them. They prefer clarity to evasion.",
			"choices": [
				{"text": "Ask directly and with respect: \"Are you steady? Do you need anything?\"", "result_line": "They nod. \"I am. Thank you for asking clearly.\"", "outcome": "success"},
				{"text": "Hint that they seem off and wait for them to volunteer.", "result_line": "They're impatient. \"If you have a question, ask it.\"", "outcome": "fail"},
				{"text": "Name what you see: they're carrying something. Offer to help.", "result_line": "A nod. \"I'm managing. I appreciate the clarity.\"", "outcome": "success"},
			],
		},
		"graceful_social": {
			"opening_line": "They carry something heavy but with grace. They notice you.",
			"choices": [
				{"text": "Approach with tact; ask after their wellbeing without minimizing.", "result_line": "They soften. \"Thank you. I shall be well. Your concern is kind.\"", "outcome": "success"},
				{"text": "Tell them to cheer up or shake it off.", "result_line": "They stiffen. \"Some things are not for that. Please.\"", "outcome": "fail"},
				{"text": "Offer a graceful opening; say you're here if they wish to speak.", "result_line": "A slight smile. \"I appreciate it. I am steady enough.\"", "outcome": "success"},
			],
		},
	},
	"social_errands": {
		"patience_indirect": {
			"opening_line": "Things are a little strained. They haven't asked for a mediator.",
			"choices": [
				{"text": "Give space; then offer a gentle nudge toward calm.", "result_line": "They ease. \"Okay. I can work with that. Thanks.\"", "outcome": "success"},
				{"text": "Force a resolution and tell them to sort it out.", "result_line": "They dig in. \"Back off. Not your call.\"", "outcome": "fail"},
				{"text": "Listen and mediate lightly without taking over.", "result_line": "They nod. \"Thanks. That helped.\"", "outcome": "success"},
			],
		},
		"direct_reassurance": {
			"opening_line": "There's a bit of tension. They notice you and don't deflect.",
			"choices": [
				{"text": "Be friendly and direct; ask if they want to clear the air.", "result_line": "They relax. \"Good to clear the air. Thanks.\"", "outcome": "success"},
				{"text": "Take sides in the tension.", "result_line": "They get defensive. \"Stay out of it.\"", "outcome": "fail"},
				{"text": "Smooth things over without taking over.", "result_line": "They nod. \"Appreciate it. We're good.\"", "outcome": "success"},
			],
		},
		"solemn_patience": {
			"opening_line": "Quiet friction. They'd rather not make a scene.",
			"choices": [
				{"text": "Keep it calm and respectful; name the tension without escalating.", "result_line": "They appreciate it. \"Thank you. We're good.\"", "outcome": "success"},
				{"text": "Dramatize the situation or take a side.", "result_line": "They withdraw. \"Don't. Leave it.\"", "outcome": "fail"},
				{"text": "Acknowledge both sides without picking one.", "result_line": "A slow nod. \"...Alright. Thanks.\"", "outcome": "success"},
			],
		},
		"light_touch": {
			"opening_line": "Social waters are choppy. They're testing the temperature.",
			"choices": [
				{"text": "Keep it light; offer a neutral, kind word to ease the air.", "result_line": "They accept it. \"Fine. Thanks. We're good.\"", "outcome": "success"},
				{"text": "Blunder in with good intentions and take a side.", "result_line": "They roll their eyes. \"Never mind. Stay out of it.\"", "outcome": "fail"},
				{"text": "Read the room and respond in kind—no drama.", "result_line": "They seem satisfied. \"Alright. We're square. Thanks.\"", "outcome": "success"},
			],
		},
		"perceptive_indirect": {
			"opening_line": "Social waters. They're testing the temperature.",
			"choices": [
				{"text": "Read the room and respond in kind; don't push.", "result_line": "They seem satisfied. \"Alright. We're square. Thanks.\"", "outcome": "success"},
				{"text": "Blunder in with good intentions.", "result_line": "They roll their eyes. \"Never mind. Drop it.\"", "outcome": "fail"},
				{"text": "Offer a neutral, perceptive word; leave room for them.", "result_line": "They accept it. \"Fine. Thanks. Noted.\"", "outcome": "success"},
			],
		},
		"respectful_clarity": {
			"opening_line": "Tension is clear. They'd rather it be named than hinted at.",
			"choices": [
				{"text": "Name the tension calmly; offer to help smooth it.", "result_line": "They nod. \"Thanks. We're good. I appreciate the directness.\"", "outcome": "success"},
				{"text": "Hint around the subject or take a side.", "result_line": "They get defensive. \"Stay out of it. If you have something to say, say it.\"", "outcome": "fail"},
				{"text": "Ask directly and respectfully what's going on.", "result_line": "They answer. \"We're managing. Thanks for asking.\"", "outcome": "success"},
			],
		},
		"graceful_social": {
			"opening_line": "There's tension, but they're composed. They notice you.",
			"choices": [
				{"text": "Approach with tact; name the tension and offer to help smooth it.", "result_line": "They soften. \"Thank you. We shall be well. Your tact is appreciated.\"", "outcome": "success"},
				{"text": "Be crude or dismissive about the tension.", "result_line": "They stiffen. \"That was unnecessary. Please leave it.\"", "outcome": "fail"},
				{"text": "Offer a graceful opening; acknowledge both sides without escalating.", "result_line": "A slight nod. \"I appreciate it. We are well enough.\"", "outcome": "success"},
			],
		},
	},
	"pointed_conversations": {
		"patience_indirect": {
			"opening_line": "Something needs to be said. They know it; they're waiting for the right approach.",
			"choices": [
				{"text": "Approach the subject sideways; give them room to meet you.", "result_line": "They follow. \"...Alright. So.\" They clarify. \"There. Clear enough?\"", "outcome": "success"},
				{"text": "Ambush them with the question.", "result_line": "They shut down. \"Wrong way to ask. We're done.\"", "outcome": "fail"},
				{"text": "Give them a moment, then ask clearly and without accusation.", "result_line": "They answer. \"There. Clear enough? Thank you for asking straight.\"", "outcome": "success"},
			],
		},
		"direct_reassurance": {
			"opening_line": "They'd rather have it out in the open.",
			"choices": [
				{"text": "Ask the question directly.", "result_line": "They answer. \"Good. Now we're clear. Thanks.\"", "outcome": "success"},
				{"text": "Hint and imply instead of asking.", "result_line": "They're annoyed. \"Just ask. I'm not playing games.\"", "outcome": "fail"},
				{"text": "State what you need to know, plainly.", "result_line": "They nod. \"There. Done. I appreciate the directness.\"", "outcome": "success"},
			],
		},
		"solemn_patience": {
			"opening_line": "A hard topic. They're braced for it; they want it asked with gravity.",
			"choices": [
				{"text": "Ask with care but don't soften the question.", "result_line": "They answer. \"...Thank you for asking straight. There. You have it.\"", "outcome": "success"},
				{"text": "Push aggressively for an answer.", "result_line": "They refuse. \"Not like this. Leave it.\"", "outcome": "fail"},
				{"text": "One clear question. Then wait.", "result_line": "They give you the answer. \"There. I'm grateful you asked rightly.\"", "outcome": "success"},
			],
		},
		"light_touch": {
			"opening_line": "They're braced for a question but don't want it heavy-handed.",
			"choices": [
				{"text": "Ask the question without dressing it up or making it a drama.", "result_line": "They answer. \"There. Now you know. Thanks for not making it weird.\"", "outcome": "success"},
				{"text": "Dance around the subject.", "result_line": "They get impatient. \"Spit it out or leave.\"", "outcome": "fail"},
				{"text": "Be direct but not aggressive.", "result_line": "They respect it. \"Fair. Here's the answer. We're good.\"", "outcome": "success"},
			],
		},
		"perceptive_indirect": {
			"opening_line": "They're waiting for the right question. They'll answer if you ask rightly.",
			"choices": [
				{"text": "Ask the real question, without dressing it up.", "result_line": "They answer. \"There. Now you know. Thanks.\"", "outcome": "success"},
				{"text": "Dance around the subject or pretend to agree before asking.", "result_line": "They get impatient. \"Spit it out or leave. Don't play.\"", "outcome": "fail"},
				{"text": "Be direct but not aggressive; one clear question.", "result_line": "They respect it. \"Fair. Here's the answer.\"", "outcome": "success"},
			],
		},
		"respectful_clarity": {
			"opening_line": "A hard topic. They prefer the question named clearly and with respect.",
			"choices": [
				{"text": "Name the question directly and respectfully.", "result_line": "They answer. \"There. Thank you for asking clearly.\"", "outcome": "success"},
				{"text": "Be aggressive or vague about what you want to know.", "result_line": "They refuse. \"Not like this. Ask properly or leave.\"", "outcome": "fail"},
				{"text": "State what you need to know, plainly and without accusation.", "result_line": "They nod. \"There. Done. I appreciate the clarity.\"", "outcome": "success"},
			],
		},
		"graceful_social": {
			"opening_line": "A delicate matter. They're braced for it; they want it asked with tact.",
			"choices": [
				{"text": "Ask with tact; name the matter without crudity.", "result_line": "They answer. \"Thank you for asking with care. There. We are clear.\"", "outcome": "success"},
				{"text": "Be crude or escalate the tension.", "result_line": "They stiffen. \"That was not called for. Please leave it.\"", "outcome": "fail"},
				{"text": "Offer a graceful opening; state the question with clarity and respect.", "result_line": "A slight nod. \"There. I appreciate your tact. We are clear.\"", "outcome": "success"},
			],
		},
	},
}

## Returns challenge_state for branching from target personality. Fallback: "direct_reassurance".
static func get_challenge_state_for_personality(personality: String) -> String:
	var p: String = str(personality).strip_edges().to_lower()
	if p.is_empty():
		p = "neutral"
	return PERSONALITY_TO_CHALLENGE_STATE.get(p, "direct_reassurance")

## Returns branching data for style+state or {} if missing. Keys: opening_line, choices (array of {text, result_line, outcome}).
static func get_branching_data(challenge_style: String, challenge_state: String) -> Dictionary:
	var style: String = str(challenge_style).strip_edges().to_lower()
	var state: String = str(challenge_state).strip_edges().to_lower()
	if style.is_empty() or not BRANCHING_CHECKS.has(style):
		return {}
	var by_state: Variant = BRANCHING_CHECKS[style]
	if by_state is not Dictionary or not (by_state as Dictionary).has(state):
		return {}
	var entry: Dictionary = (by_state as Dictionary)[state]
	var result: Dictionary = {}
	result["opening_line"] = str(entry.get("opening_line", "")).strip_edges()
	var choices_raw: Variant = entry.get("choices", [])
	if choices_raw is Array:
		result["choices"] = (choices_raw as Array).duplicate()
	else:
		result["choices"] = []
	return result

# Compact fallback pool for failed branching check reactions (giver's response when player returns after failing).
static var FAILED_REACTION_LINES: Array = [
	"You couldn't get through to them. They're not ready to talk—or you chose the wrong approach.",
	"They shut you out. Whatever was needed, it wasn't what you said.",
	"The moment passed. They've withdrawn; perhaps another time, another approach.",
	"You misread them. They're not angry—just closed off for now.",
	"It didn't land. They needed something else; they didn't find it in your words.",
]

## Short line when player returns to giver after failing a branching check. Picks from FAILED_REACTION_LINES by giver_name hash for variety.
static func get_failed_reaction_line(giver_name: String = "") -> String:
	if FAILED_REACTION_LINES.is_empty():
		return "You couldn't get through to them. They're not ready to talk—or you chose the wrong approach."
	var idx: int = abs(str(giver_name).hash()) % FAILED_REACTION_LINES.size()
	var line: Variant = FAILED_REACTION_LINES[idx]
	return str(line) if line != null else FAILED_REACTION_LINES[0]

## Returns special camp scene for unit+tier or {}. Keys: one_time, lines (Array). Tier: "trusted" | "close".
static func get_special_camp_scene(unit_name: String, tier: String) -> Dictionary:
	var key: String = str(unit_name).strip_edges()
	var t: String = str(tier).strip_edges().to_lower()
	if key.is_empty() or t.is_empty() or not SPECIAL_CAMP_SCENES.has(key):
		return {}
	var by_tier: Variant = SPECIAL_CAMP_SCENES[key]
	if by_tier is not Dictionary or not (by_tier as Dictionary).has(t):
		return {}
	var entry: Variant = (by_tier as Dictionary)[t]
	if entry is not Dictionary:
		return {}
	var d: Dictionary = (entry as Dictionary)
	var lines_raw: Variant = d.get("lines", [])
	var lines: Array = lines_raw if lines_raw is Array else []
	return {"one_time": bool(d.get("one_time", true)), "lines": lines}

## Returns personal quest profile for unit or {}. Keys: unlock_tier, title, description, type, target_bias (optional), request_depth.
static func get_personal_quest_profile(unit_name: String) -> Dictionary:
	var key: String = str(unit_name).strip_edges()
	if key.is_empty() or not PERSONAL_QUEST_PROFILES.has(key):
		return {}
	var entry: Variant = PERSONAL_QUEST_PROFILES[key]
	if entry is not Dictionary:
		return {}
	return (entry as Dictionary).duplicate()

## Builds a personal quest offer dict compatible with camp request flow. Returns {} if profile missing or no valid target/item.
static func get_personal_quest_offer(giver_name: String, roster_names: Array, item_candidates: Array) -> Dictionary:
	var profile: Dictionary = get_personal_quest_profile(giver_name)
	if profile.is_empty():
		return {}
	var req_type: String = str(profile.get("type", "talk_to_unit")).strip_edges()
	var target_name: String = ""
	var target_amount: int = 1
	var payload: Dictionary = {}
	if req_type == "talk_to_unit":
		var allowed: Array = []
		for n in roster_names:
			var s: String = str(n).strip_edges()
			if s != "" and s != giver_name:
				allowed.append(s)
		if allowed.is_empty():
			return {}
		target_name = allowed[abs(giver_name.hash()) % allowed.size()]
		var bias: String = str(profile.get("target_bias", "wellness_check")).strip_edges()
		if bias in BRANCHING_BIASES:
			payload["branching_check"] = true
			payload["challenge_style"] = bias
			payload["challenge_id"] = "%s_personal_%s" % [giver_name, target_name]
			payload["failure_on_wrong"] = true
	elif req_type == "item_delivery":
		if item_candidates.is_empty():
			return {}
		target_name = item_candidates[abs(giver_name.hash()) % item_candidates.size()]
		target_amount = 2
	else:
		return {}
	var title: String = str(profile.get("title", "A personal request.")).strip_edges()
	var desc: String = str(profile.get("description", "")).strip_edges()
	if desc.is_empty():
		desc = "I need your help with something that matters to me."
	var out: Dictionary = {}
	out["type"] = req_type
	out["target_name"] = target_name
	out["target_amount"] = target_amount
	out["title"] = title
	out["description"] = desc
	out["reward_gold"] = 55
	out["reward_affinity"] = 2
	out["payload"] = payload
	out["request_depth"] = "personal"
	return out

# --- Optional anti-repeat (stateless by default). Set last_used_index when calling pick_from_pool to enable exclude_last_text. ---
# Caller can pass last_used_index and receive new index for next time.
const ANTI_REPEAT_NONE: int = -1

## Returns the raw pool for a character and pool name. variant_key optionally narrows (e.g. item_tag, signature_request_bias).
## Returns [] if missing or invalid. Pool may be Array or Dict; if Dict and variant_key given, returns pool[variant_key] if present.
static func get_character_pool(unit_name: String, pool_name: String, variant_key: String = "") -> Array:
	var key: String = str(unit_name).strip_edges()
	if key.is_empty() or not CHARACTER_BANKS.has(key):
		return []
	var by_pool: Variant = CHARACTER_BANKS[key]
	if by_pool is not Dictionary:
		return []
	var pool: Variant = (by_pool as Dictionary).get(pool_name, null)
	if pool == null:
		return []
	if variant_key != "" and pool is Dictionary:
		var sub: Variant = (pool as Dictionary).get(variant_key, null)
		if sub is Array:
			return sub as Array
		return []
	if pool is Array:
		return pool as Array
	return []

## Returns fallback pool: voice_style first, then personality, then neutral. variant_key optional.
static func get_fallback_pool(voice_style: String, personality: String, pool_name: String, variant_key: String = "") -> Array:
	var vs: String = str(voice_style).strip_edges().to_lower()
	var p: String = str(personality).strip_edges().to_lower()
	if p.is_empty():
		p = "neutral"
	if vs != "" and VOICE_STYLE_BANKS.has(vs):
		var by_pool: Variant = VOICE_STYLE_BANKS[vs]
		if by_pool is Dictionary:
			var pool: Variant = by_pool.get(pool_name, null)
			if variant_key != "" and pool is Dictionary:
				var sub: Variant = (pool as Dictionary).get(variant_key, null)
				if sub is Array:
					return sub as Array
			elif pool is Array:
				return pool as Array
	if p != "" and PERSONALITY_BANKS.has(p):
		var by_pool: Variant = PERSONALITY_BANKS[p]
		if by_pool is Dictionary:
			var pool: Variant = by_pool.get(pool_name, null)
			if variant_key != "" and pool is Dictionary:
				var sub: Variant = (pool as Dictionary).get(variant_key, null)
				if sub is Array:
					return sub as Array
			elif pool is Array:
				return pool as Array
	var neutral_pool: Variant = NEUTRAL_BANKS.get(pool_name, null)
	if variant_key != "" and neutral_pool is Dictionary:
		var sub: Variant = (neutral_pool as Dictionary).get(variant_key, null)
		if sub is Array:
			return sub as Array
		return []
	if neutral_pool is Array:
		return neutral_pool as Array
	return []

## Best pool: character first, then fallback (voice -> personality -> neutral). variant_key optional.
static func get_best_pool(unit_name: String, voice_style: String, personality: String, pool_name: String, variant_key: String = "") -> Array:
	var arr: Array = get_character_pool(unit_name, pool_name, variant_key)
	if arr.size() > 0:
		return arr
	return get_fallback_pool(voice_style, personality, pool_name, variant_key)

## Picks one string from pool by deterministic seed. exclude_last_index: if >= 0 and pool.size() > 1, pick different index when possible.
## Returns "" if pool empty. Optional: pass a single-element array to receive the chosen index for next call as last_used_index.
static func pick_from_pool(pool: Array, seed_value: int, exclude_last_index: int = ANTI_REPEAT_NONE) -> String:
	if pool == null or pool.size() == 0:
		return ""
	var idx: int = abs(seed_value) % pool.size()
	if exclude_last_index >= 0 and pool.size() > 1 and idx == exclude_last_index:
		idx = (idx + 1) % pool.size()
	var s: Variant = pool[idx]
	return str(s) if s != null else ""

## Same as pick_from_pool but returns both the line and the index used (for optional anti-repeat state).
static func pick_from_pool_with_index(pool: Array, seed_value: int, exclude_last_index: int = ANTI_REPEAT_NONE) -> Dictionary:
	var result: Dictionary = {"text": "", "index": ANTI_REPEAT_NONE}
	if pool == null or pool.size() == 0:
		return result
	var idx: int = abs(seed_value) % pool.size()
	if exclude_last_index >= 0 and pool.size() > 1 and idx == exclude_last_index:
		idx = (idx + 1) % pool.size()
	result["index"] = idx
	var s: Variant = pool[idx]
	result["text"] = str(s) if s != null else ""
	return result

## Returns one description template string from pool (for desc_item_delivery / desc_talk_to_unit). Templates use %d %s etc.
static func pick_description_from_pool(pool: Array, seed_value: int) -> String:
	return pick_from_pool(pool, seed_value)
