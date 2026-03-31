extends Control

const TAVERN_PANEL_BG := Color(0.13, 0.097, 0.068, 0.90)
const TAVERN_PANEL_BG_ALT := Color(0.10, 0.076, 0.052, 0.94)
const TAVERN_BORDER := Color(0.82, 0.66, 0.24, 0.96)
const TAVERN_BORDER_SOFT := Color(0.47, 0.38, 0.17, 0.94)
const TAVERN_TEXT := Color(0.94, 0.91, 0.84, 1.0)
const TAVERN_TEXT_MUTED := Color(0.76, 0.73, 0.66, 1.0)
const TAVERN_BUTTON_BG := Color(0.28, 0.21, 0.13, 0.94)
const TAVERN_BUTTON_HOVER := Color(0.37, 0.28, 0.17, 0.98)
const TAVERN_BUTTON_PRESSED := Color(0.51, 0.38, 0.21, 0.98)

@onready var leave_btn: Button = $LeaveButton
@onready var tavern_grid: GridContainer = $RosterScroll/TavernGrid
@onready var notice_board_btn: Button = get_node_or_null("NoticeBoard")
@onready var cartographer_btn: Button = get_node_or_null("CartographerButton")
@onready var gambler_btn: Button = get_node_or_null("GamblerButton")
@onready var chat_panel: Panel = get_node_or_null("ChatPanel")
@onready var chat_input: LineEdit = get_node_or_null("ChatPanel/ChatInput")
@onready var chat_send_btn: Button = get_node_or_null("ChatPanel/SendButton")
@onready var roster_scroll: ScrollContainer = get_node_or_null("RosterScroll")

var select_sound: AudioStreamPlayer
var blip_sound: AudioStreamPlayer

# --- TWEEN TRACKING ---
var _active_portrait_tween: Tween
var _active_name_tween: Tween
var _active_shake_tween: Tween
var _active_text_tween: Tween
var _dialogue_base_pos: Vector2 = Vector2(-1, -1) # Will be captured dynamically
var _dialogue_overlay_layer: CanvasLayer = null
var _dialogue_input_blocker: ColorRect = null
var _seraphina_dialogue_active: bool = false
var _seraphina_portrait_layout_captured: bool = false
var _left_portrait_default_offset_top: float = 0.0
var _left_portrait_default_offset_bottom: float = 0.0
var _choice_layout_defaults_captured: bool = false
var _choice_container_default_offset_left: float = 0.0
var _choice_container_default_offset_right: float = 0.0
var _choice_container_default_offset_top: float = 0.0
var _choice_container_default_offset_bottom: float = 0.0
var _choice_btn_default_min_size: Vector2 = Vector2.ZERO
var _choice_btn_default_font_size: int = 30

@onready var dialogue_panel: Control = $DialoguePanel
@onready var dialogue_text: RichTextLabel = $DialoguePanel/DialogueText
@onready var choice_container: Control = $DialoguePanel/ChoiceContainer
@onready var choice_btn_1: Button = $DialoguePanel/ChoiceContainer/Choice1
@onready var choice_btn_2: Button = $DialoguePanel/ChoiceContainer/Choice2
@onready var choice_btn_3: Button = $DialoguePanel/ChoiceContainer/Choice3
@onready var choice_btn_4: Button = $DialoguePanel/ChoiceContainer/Choice4
@onready var next_btn: Button = $DialoguePanel/NextButton
@onready var tavern_music: AudioStreamPlayer = get_node_or_null("TavernMusic")

@onready var seraphina_portrait: TextureButton = $SeraphinaPortrait
@onready var seraphina_controller: SeraphinaDialogueManager = $SeraphinaController

var is_waiting_for_choice: bool = false
var branch_resolved: bool = false
var current_lookup_key: String = ""

# --- DIALOGUE UI REFERENCES ---

@onready var left_portrait: TextureRect = $DialoguePanel/LeftPortrait
@onready var right_portrait: TextureRect = $DialoguePanel/RightPortrait
@onready var speaker_name: Label = $DialoguePanel/SpeakerName


# Variables for the active conversation
var current_dialogue_sequence: Array = []
var current_dialogue_index: int = 0
var active_character_a: Dictionary = {}
var active_character_b: Dictionary = {}
var active_bond_key: String = ""

# ============================================================================
# ======================= SUPPORT DATABASE: PASTE HERE =======================
# ============================================================================
# PASTE YOUR FULL SUPPORT DATABASE MEGA-SNIPPET DIRECTLY INSIDE THIS DICTIONARY.
# Example:
# var support_database = {
#     "Avatar_Kaelen_Rank1": { ... },
#     "Branik_Nyx_Rank1": { ... },
#     ...
# }
# ============================================================================
var support_database = {
	"Branik_Nyx_Rank1": {
	"req_level": 4, # Unlocked after Level 4 (Merchant's Maze)
	"script": [
		{"speaker": "Branik", "text": "Those slum alleys were too tight for a clean fight. Every time you vanished into a side street, I thought I was about to find you bleeding under a market cart."},
		{"speaker": "Nyx", "text": "And every time you stomped after me, every patrol in the district heard your boots before they heard their own thoughts."},
		{"speaker": "Branik", "text": "Boots can be mended. A throat cut in the dark can't."},
		{"speaker": "Nyx", "text": "I got us through the sewers, found the watch route, and picked enough coin off one League clerk to cover supper for three days. You want to scold me, or thank me?"}
	],
	"branch_at": 3,
	"choices": [
		{
			"text": "Branik has a point.",
			"result": "success",
			"response": [
				{"speaker": "Nyx", "text": "Ugh. Fine. I know what you're both saying."},
				{"speaker": "Nyx", "text": "I can slip through a crowd. That doesn't mean I should make a habit of doing it alone."},
				{"speaker": "Branik", "text": "That's all I wanted to hear. You scout. I cover. We both get to eat supper."},
				{"speaker": "Nyx", "text": "...You really do solve everything with supper, big guy."}
			]
		},
		{
			"text": "The coin helped.",
			"result": "fail",
			"response": [
				{"speaker": "Branik", "text": "Coin doesn't buy back a life once it's spent."},
				{"speaker": "Nyx", "text": "No, but it does buy boots, bandages, and bread. Things heroes keep forgetting cost money."},
				{"speaker": "Branik", "text": "Maybe. But next time you run that far ahead, don't expect me to call it clever."},
				{"speaker": "Nyx", "text": "Touchy. Useful, but touchy."}
			]
		}
	]
},
"Branik_Nyx_Rank2": {
	"req_level": 6, # Unlocked after Level 6 (Siege of Greyspire / Hub established)
	"script": [
		{"speaker": "Branik", "text": "You've been sleeping with one eye open since we took Greyspire. A fortress is still better than mud and rain."},
		{"speaker": "Nyx", "text": "That's because walls remember who owned them before you did. Places like this don't stay empty. They wait."},
		{"speaker": "Branik", "text": "Maybe. But we've got a forge, a roof, and stew that isn't half ash. That's more home than most folk in this war get."},
		{"speaker": "Nyx", "text": "Home, huh? Funny word for a keep full of dead knights, hidden crypts, and one blacksmith who stares at his hammer like it's the last honest thing in Aurelia."},
		{"speaker": "Branik", "text": "You're still here."},
		{"speaker": "Nyx", "text": "...Don't make it sound noble. I'm here because leaving would be inconvenient."}
	],
	"branch_at": 5,
	"choices": [
		{
			"text": "You belong here.",
			"result": "success",
			"response": [
				{"speaker": "Nyx", "text": "Careful, Commander. Keep saying things like that and I'll start acting loyal in broad daylight."},
				{"speaker": "Branik", "text": "Wouldn't hurt. The rookies watch you more than they admit."},
				{"speaker": "Nyx", "text": "That's because they're terrible judges of character."},
				{"speaker": "Branik", "text": "Maybe. Or maybe they know a stray who finally found a fire worth circling."},
				{"speaker": "Nyx", "text": "...You make it very hard to stay sarcastic."}
			]
		},
		{
			"text": "Then stay practical.",
			"result": "fail",
			"response": [
				{"speaker": "Nyx", "text": "See? Finally, someone speaking my language."},
				{"speaker": "Branik", "text": "Practical's fine. Cold isn't."},
				{"speaker": "Nyx", "text": "Cold keeps people alive."},
				{"speaker": "Branik", "text": "Only until they forget why they wanted to live in the first place."}
			]
		}
	]
},
"Branik_Nyx_Rank3": {
	"req_level": 11, # Unlocked after Level 11 (Market of Masks)
	"script": [
		{"speaker": "Branik", "text": "You disappeared again during the festival. In a crowd like that, with masked killers loose, that wasn't funny."},
		{"speaker": "Nyx", "text": "I wasn't sightseeing. I was watching the balconies, the exits, the noble boxes, the little places blades come from when rich men pretend they're safe."},
		{"speaker": "Branik", "text": "I know. That's what scared me."},
		{"speaker": "Nyx", "text": "...Scared you? Big man, I survived worse than silk masks and poisoned wine."},
		{"speaker": "Branik", "text": "That's exactly it. You've survived everything by assuming no one's coming back for you."},
		{"speaker": "Nyx", "text": "And usually I'm right. So what, now I get a lecture because I didn't die in the market?"}
	],
	"branch_at": 5,
	"choices": [
		{
			"text": "He's worried for you.",
			"result": "success",
			"response": [
				{"speaker": "Nyx", "text": "...I know he's worried. That's the problem."},
				{"speaker": "Nyx", "text": "You two keep acting like I belong in the count when you tally who's coming back."},
				{"speaker": "Branik", "text": "You do. That's not changing."},
				{"speaker": "Nyx", "text": "You say things like that so simply."},
				{"speaker": "Branik", "text": "Because some truths ought to be simple. You're one of ours."},
				{"speaker": "Nyx", "text": "...Fine. But if anyone else asks, I joined the family under protest."}
			]
		},
		{
			"text": "You handled it well.",
			"result": "fail",
			"response": [
				{"speaker": "Nyx", "text": "See? Competence recognized at last."},
				{"speaker": "Branik", "text": "That's not what I meant."},
				{"speaker": "Nyx", "text": "Maybe not. But it's easier to be useful than missed, isn't it?"},
				{"speaker": "Branik", "text": "...No. And one day I'm going to make you believe that."}
			]
		}
	]
},
"Liora_Sorrel_Rank1": {
	"req_level": 6, # Unlocked after Level 6 (Siege of Greyspire / Hub established)
	"script": [
		{"speaker": "Liora", "text": "You've spent three nights in Greyspire's archive without proper rest. Even haunted libraries do not become less dangerous when studied while exhausted."},
		{"speaker": "Sorrel", "text": "On the contrary, the archive becomes significantly more coherent once everyone else stops interrupting it."},
		{"speaker": "Liora", "text": "That is not how coherence works."},
		{"speaker": "Sorrel", "text": "Perhaps not for temples. For archives, it helps quite a lot."},
		{"speaker": "Liora", "text": "You say that as if books cannot wound people."},
		{"speaker": "Sorrel", "text": "I say it because ignorance has already wounded plenty. Greyspire hid relics, testimonies, and battle logs for decades. If the Order's truth had been shared earlier, how many lives might have changed?"}
	],
	"branch_at": 5,
	"choices": [
		{
			"text": "Truth needs compassion.",
			"result": "success",
			"response": [
				{"speaker": "Liora", "text": "Exactly. Knowledge without mercy becomes another weapon in a stronger hand."},
				{"speaker": "Sorrel", "text": "...That is a reasonable correction."},
				{"speaker": "Sorrel", "text": "Then perhaps the real failure was not that the Order kept records, but that no one taught the world how to carry them gently."},
				{"speaker": "Liora", "text": "If you keep speaking like that, Scholar, I may yet save your soul from the dust."}
			]
		},
		{
			"text": "Truth comes first.",
			"result": "fail",
			"response": [
				{"speaker": "Sorrel", "text": "A defensible position."},
				{"speaker": "Liora", "text": "Defensible, perhaps. Humane, not always."},
				{"speaker": "Sorrel", "text": "If people fear the truth, that is hardly the truth's fault."},
				{"speaker": "Liora", "text": "No. But it becomes our fault if we wield it carelessly."}
			]
		}
	]
},
"Liora_Sorrel_Rank2": {
	"req_level": 9, # Unlocked after Level 9 (Paths Diverge)
	"script": [
		{"speaker": "Sorrel", "text": "Your Valeron envoy and the League delegates used nearly identical language, you know."},
		{"speaker": "Liora", "text": "That seems unlikely. One hides greed in contracts. The other hides fear in scripture."},
		{"speaker": "Sorrel", "text": "Exactly. Different costumes, same instinct: control the Mark, control the future."},
		{"speaker": "Liora", "text": "You sound pleased to have proven everyone equally disappointing."},
		{"speaker": "Sorrel", "text": "Not pleased. Merely unsurprised."},
		{"speaker": "Liora", "text": "That may be the saddest kind of certainty there is."}
	],
	"branch_at": 5,
	"choices": [
		{
			"text": "Liora is right.",
			"result": "success",
			"response": [
				{"speaker": "Sorrel", "text": "...Yes. Perhaps I have begun treating disappointment like evidence of intelligence."},
				{"speaker": "Liora", "text": "And perhaps I have begun mistaking hope for duty."},
				{"speaker": "Sorrel", "text": "Then we are both in need of correction."},
				{"speaker": "Liora", "text": "Good. It would be terribly inconvenient if only one of us had to grow."}
			]
		},
		{
			"text": "Sorrel sees clearly.",
			"result": "fail",
			"response": [
				{"speaker": "Sorrel", "text": "Clarity is not always comfort, but I accept the compliment."},
				{"speaker": "Liora", "text": "No, Scholar. Clarity without hope is only another kind of surrender."},
				{"speaker": "Sorrel", "text": "And hope without evidence?"},
				{"speaker": "Liora", "text": "Faith. Which is not the same thing as blindness, no matter how often this continent confuses them."}
			]
		}
	]
},
"Liora_Sorrel_Rank3": {
	"req_level": 12, # Unlocked after Level 12 (Shadows in the College)
	"script": [
		{"speaker": "Liora", "text": "You've hardly spoken since we left the College."},
		{"speaker": "Sorrel", "text": "I am revising several lifelong assumptions."},
		{"speaker": "Liora", "text": "Because the Codex proved the Catalyst Mark was part of the seal."},
		{"speaker": "Sorrel", "text": "Yes. And because half the continent killed, lied, censored, and prayed around a truth they either feared or wished to own."},
		{"speaker": "Liora", "text": "I know."},
		{"speaker": "Sorrel", "text": "Do you? I thought if truth were uncovered, things would become simpler. Instead they have become heavier."},
		{"speaker": "Liora", "text": "That is because truth is not a lantern. It is a burden. The question is whether we carry it together, or let it crush someone alone."}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "Carry it together.",
			"result": "success",
			"response": [
				{"speaker": "Sorrel", "text": "...Then I would like to continue arguing with you for as long as possible."},
				{"speaker": "Liora", "text": "That may be the closest thing to affection I have ever heard from you."},
				{"speaker": "Sorrel", "text": "It is, in fact, precisely affection."},
				{"speaker": "Liora", "text": "Then I return it gladly. Faith needs questions. And scholars, however impossible, need someone to remind them whom knowledge is meant to serve."},
				{"speaker": "Sorrel", "text": "Agreed. We preserve the truth together—or not at all."}
			]
		},
		{
			"text": "Truth must be protected.",
			"result": "fail",
			"response": [
				{"speaker": "Sorrel", "text": "Protected, yes. Hidden, no. We have seen where that road ends."},
				{"speaker": "Liora", "text": "I did not mean hidden."},
				{"speaker": "Sorrel", "text": "Then say shared. Say borne. Say entrusted. Not protected, as if truth were another relic for powerful hands."},
				{"speaker": "Liora", "text": "...You are right. Forgive the habit. Too much of my life was spent hearing that word from the wrong mouths."}
			]
		}
	]
},

"Avatar_Kaelen_Rank1": {
	"req_level": 2,
	"script": [
		{"speaker": "Kaelen", "text": "You kept looking back through Emberwood. At the fire, at the smoke... at ghosts that were already gone."},
		{"speaker": "Commander", "text": "There were still people in that village."},
		{"speaker": "Kaelen", "text": "I know. That's why I dragged you forward. One dead hero in the ashes helps no one."},
		{"speaker": "Commander", "text": "You say that like it's easy."},
		{"speaker": "Kaelen", "text": "It isn't. It's just necessary. So answer me straight, Commander: do you want comfort, or do you want to live long enough to matter?"}
	],
	"branch_at": 4,
	"choices": [
		{
			"text": "Teach me survival.",
			"result": "success",
			"response": [
				{"speaker": "Kaelen", "text": "Good. Then first lesson: grief waits its turn. Breathing comes first."},
				{"speaker": "Kaelen", "text": "You'll hate me for saying it now, but one day you'll give the same order to someone else."},
				{"speaker": "Commander", "text": "And if I do?"},
				{"speaker": "Kaelen", "text": "Then I'll know you learned the part that keeps people alive."}
			]
		},
		{
			"text": "I won't leave them.",
			"result": "fail",
			"response": [
				{"speaker": "Kaelen", "text": "That's a noble answer. Noble answers get graves dug all over Aurelia."},
				{"speaker": "Commander", "text": "Maybe. But I won't survive this by becoming empty."},
				{"speaker": "Kaelen", "text": "...No. And for what it's worth, that's not the worst flaw a commander can carry."}
			]
		}
	]
},
"Avatar_Kaelen_Rank2": {
	"req_level": 6,
	"script": [
		{"speaker": "Kaelen", "text": "You've been pacing the walls of Greyspire every night since we took it."},
		{"speaker": "Commander", "text": "It doesn't feel won. Not yet. More like we asked the dead to make room."},
		{"speaker": "Kaelen", "text": "That's the right feeling, unfortunately. Fortresses remember. Especially this one."},
		{"speaker": "Commander", "text": "And you? Every room here seems to know your name before I do."},
		{"speaker": "Kaelen", "text": "Aye. Most of them remember me younger and dumber."},
		{"speaker": "Kaelen", "text": "So tell me, Commander. When you look at Greyspire, do you see a graveyard... or the first place this army can call home?"}
	],
	"branch_at": 5,
	"choices": [
		{
			"text": "We'll make it home.",
			"result": "success",
			"response": [
				{"speaker": "Commander", "text": "A graveyard can still shelter the living. We build something better on top of what was lost."},
				{"speaker": "Kaelen", "text": "...That's a harder answer than hope, and a better one."},
				{"speaker": "Kaelen", "text": "Good. Keep thinking like that and these walls may yet deserve the people sleeping inside them."},
				{"speaker": "Commander", "text": "You sound relieved."},
				{"speaker": "Kaelen", "text": "Maybe I am. For the first time since Oakhaven, I can almost picture you lasting."}
			]
		},
		{
			"text": "It's still haunted.",
			"result": "fail",
			"response": [
				{"speaker": "Commander", "text": "Home shouldn't feel this heavy."},
				{"speaker": "Kaelen", "text": "No. But sometimes heavy is the best the world offers."},
				{"speaker": "Kaelen", "text": "Stay long enough, and you'll learn most shelters are built out of someone else's ruin."},
				{"speaker": "Commander", "text": "That supposed to be comforting?"},
				{"speaker": "Kaelen", "text": "Not even slightly. Just true."}
			]
		}
	]
},
"Avatar_Kaelen_Rank3": {
	"req_level": 14,
	"script": [
		{"speaker": "Commander", "text": "After Dawnkeep... I keep replaying what you showed us. The ritual. The lie. All of it."},
		{"speaker": "Kaelen", "text": "You should. If I were in your boots, I'd be deciding whether to throw me off the walls."},
		{"speaker": "Commander", "text": "Did you ever mean to tell me the whole truth before it cornered us?"},
		{"speaker": "Kaelen", "text": "I meant to tell you when I thought the truth would help more than it hurt."},
		{"speaker": "Commander", "text": "That's not an answer."},
		{"speaker": "Kaelen", "text": "No. It's the confession of an old coward who got too used to choosing burdens for other people."},
		{"speaker": "Kaelen", "text": "So here it is plain, Commander. If you want me gone after Dawnkeep, say the word. I'll obey it."}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "Stay. I need you.",
			"result": "success",
			"response": [
				{"speaker": "Commander", "text": "You lied to me. You do not get forgiven cleanly. But you're still here, and I still need you."},
				{"speaker": "Kaelen", "text": "...Fair. Probably kinder than I deserve."},
				{"speaker": "Commander", "text": "Don't mistake this for blind trust."},
				{"speaker": "Kaelen", "text": "Wouldn't dream of it. Truth be told, I'm prouder hearing that from you than I would be hearing forgiveness."},
				{"speaker": "Kaelen", "text": "You're not the frightened kid from Emberwood anymore. You're a commander. Better one than I was, if we're speaking honestly."},
				{"speaker": "Commander", "text": "Then stay beside me long enough to see what kind of commander that becomes."},
				{"speaker": "Kaelen", "text": "Aye. That, I can do."}
			]
		},
		{
			"text": "I need time.",
			"result": "fail",
			"response": [
				{"speaker": "Commander", "text": "I'm not ready to decide what you are to me after this."},
				{"speaker": "Kaelen", "text": "Fair enough."},
				{"speaker": "Kaelen", "text": "I'll keep doing the work until you decide whether I've earned the right to stand near you."},
				{"speaker": "Commander", "text": "You make it sound simple."},
				{"speaker": "Kaelen", "text": "No. I make it sound late. There's a difference."}
			]
		}
	]
},
"Avatar_Liora_Rank1": {
	"req_level": 3,
	"script": [
		{"speaker": "Liora", "text": "I meant to thank you properly for the sanctum... but every time I begin, the words sound too small."},
		{"speaker": "Commander", "text": "You don't owe me a speech. We got out. That's enough."},
		{"speaker": "Liora", "text": "It isn't, not to me. You walked into a collapsing temple for someone you barely knew."},
		{"speaker": "Commander", "text": "You were trapped. That was reason enough."},
		{"speaker": "Liora", "text": "Perhaps. But when Ephrem looked at you, it was not as a person. It was as a sign, a danger, a thing to be judged."},
		{"speaker": "Liora", "text": "Tell me honestly, Commander... when people stare at the Mark, what do you wish they would see?"}
	],
	"branch_at": 5,
	"choices": [
		{
			"text": "Just me.",
			"result": "success",
			"response": [
				{"speaker": "Commander", "text": "Just me. Not a prophecy. Not a threat. Just the person standing here."},
				{"speaker": "Liora", "text": "...Then I will try very hard to be one of the people who remembers that."},
				{"speaker": "Liora", "text": "The world may insist on symbols. I do not have to follow its example."},
				{"speaker": "Commander", "text": "That's more thanks than I needed."},
				{"speaker": "Liora", "text": "Then forgive me. I intend to keep giving it anyway."}
			]
		},
		{
			"text": "A weapon, maybe.",
			"result": "fail",
			"response": [
				{"speaker": "Liora", "text": "Do not say that so lightly."},
				{"speaker": "Commander", "text": "It isn't light. Just useful. People understand weapons."},
				{"speaker": "Liora", "text": "They understand how to fear them, command them, and spend them. That is not the same as seeing you."},
				{"speaker": "Liora", "text": "I would rather argue with you for years than watch you become something easier for them to name."}
			]
		}
	]
},
"Avatar_Liora_Rank2": {
	"req_level": 10,
	"script": [
		{"speaker": "Liora", "text": "During the Sunlit Trial, when they sealed the gates and lit the outer ring... I thought Valeron had decided to burn you alive in front of its own faithful."},
		{"speaker": "Commander", "text": "You looked like you wanted to climb into the arena yourself."},
		{"speaker": "Liora", "text": "I did. For one very undignified moment, I considered it."},
		{"speaker": "Commander", "text": "That would've been a terrible plan."},
		{"speaker": "Liora", "text": "Yes. A terrible, earnest, heartfelt plan."},
		{"speaker": "Liora", "text": "When you stood there beneath all that judgment, I realized something that frightens me, Commander: I do not merely believe in your cause anymore. I am frightened for you personally."}
	],
	"branch_at": 5,
	"choices": [
		{
			"text": "You kept me steady.",
			"result": "success",
			"response": [
				{"speaker": "Commander", "text": "Then know this: when the crowd wanted a symbol, I kept hearing your voice telling me I was still a person."},
				{"speaker": "Liora", "text": "...You should not say things like that when I am trying to remain composed."},
				{"speaker": "Commander", "text": "Was that composure?"},
				{"speaker": "Liora", "text": "Barely. But perhaps that is what steadiness is—remaining upright while your heart misbehaves."},
				{"speaker": "Commander", "text": "Then we managed it together."}
			]
		},
		{
			"text": "I had to endure.",
			"result": "fail",
			"response": [
				{"speaker": "Commander", "text": "There wasn't time to think about anything but surviving."},
				{"speaker": "Liora", "text": "No... but survival is not a small thing."},
				{"speaker": "Liora", "text": "Forgive me. I keep trying to speak like a priestess when what I mean is much simpler."},
				{"speaker": "Liora", "text": "I was afraid to lose you. There. That was the honest version."}
			]
		}
	]
},
"Avatar_Liora_Rank3": {
	"req_level": 15,
	"script": [
		{"speaker": "Commander", "text": "The marsh won't leave my head. Every voice Enric trapped, every memory dragged out of the water... and Vespera's brother among them."},
		{"speaker": "Liora", "text": "I know. The Weeping Marsh does not merely show grief. It insists you carry it away."},
		{"speaker": "Commander", "text": "It also made one thing painfully clear. The closer we get to the Spire, the more this Mark stops feeling like mine."},
		{"speaker": "Liora", "text": "Do not say that."},
		{"speaker": "Commander", "text": "Why? Because it scares you?"},
		{"speaker": "Liora", "text": "Yes. Because every chapter of this war asks more of you than any one life should be forced to give."},
		{"speaker": "Liora", "text": "And because if the day comes when you decide to vanish into duty, I do not know whether my faith will survive losing you to it."}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "Stay beside me.",
			"result": "success",
			"response": [
				{"speaker": "Commander", "text": "Then don't stand behind me, Liora. Stay beside me. If this burden has to be carried, I want your voice there when it is."},
				{"speaker": "Liora", "text": "...You ask that as if it were difficult."},
				{"speaker": "Commander", "text": "Isn't it?"},
				{"speaker": "Liora", "text": "No. Terrifying, yes. Difficult, no."},
				{"speaker": "Liora", "text": "I love the soul beneath the Mark, Commander. If the world wants a symbol, let it. I know the person I am choosing."},
				{"speaker": "Commander", "text": "Then when the dark comes, we face it together."}
			]
		},
		{
			"text": "Be ready to let go.",
			"result": "fail",
			"response": [
				{"speaker": "Liora", "text": "No."},
				{"speaker": "Commander", "text": "Liora—"},
				{"speaker": "Liora", "text": "I will be brave when bravery is demanded. I will be faithful when faith is all I have left. But I will not practice losing you in advance to make the moment cleaner."},
				{"speaker": "Liora", "text": "If sacrifice comes, it will come. Until then, let me hope without apology."}
			]
		}
	]
},
"Kaelen_SerHadrien_Rank1": {
	"req_level": 16,
	"script": [
		{"speaker": "Ser Hadrien", "text": "You still favor your left side when you are tired, Commander-Captain."},
		{"speaker": "Kaelen", "text": "Don't call me that. Not here. Not from you."},
		{"speaker": "Ser Hadrien", "text": "As you wish, Kaelen. Though I carried that title into death, and it seems unfair that you should be allowed to bury it so easily."},
		{"speaker": "Kaelen", "text": "You think I buried anything in those ruins? I left pieces of myself all over them."},
		{"speaker": "Ser Hadrien", "text": "Then answer plainly, old friend. Do you want remembrance... or absolution?"}
	],
	"branch_at": 4,
	"choices": [
		{
			"text": "Choose remembrance.",
			"result": "success",
			"response": [
				{"speaker": "Kaelen", "text": "Absolution's for saints and fools. I'll take remembrance."},
				{"speaker": "Ser Hadrien", "text": "Good. The dead are easier to honor than to erase."},
				{"speaker": "Kaelen", "text": "You always did know how to sound reassuring while saying something miserable."},
				{"speaker": "Ser Hadrien", "text": "That, at least, survived the centuries intact."}
			]
		},
		{
			"text": "He deserves peace.",
			"result": "fail",
			"response": [
				{"speaker": "Ser Hadrien", "text": "Peace is not mine to grant, Commander."},
				{"speaker": "Kaelen", "text": "And not mine to ask for."},
				{"speaker": "Ser Hadrien", "text": "No. Not while memory still has work to do."}
			]
		}
	]
},
"Kaelen_SerHadrien_Rank2": {
	"req_level": 17,
	"script": [
		{"speaker": "Kaelen", "text": "You watched the coalition camp the way a ghost watches a wedding feast."},
		{"speaker": "Ser Hadrien", "text": "I watched three broken powers negotiate over who would be permitted to save the world."},
		{"speaker": "Kaelen", "text": "Aye. Sounds like Aurelia."},
		{"speaker": "Ser Hadrien", "text": "Do you remember, before the Shattering War, when the Order still believed oaths could bind the great and the small alike?"},
		{"speaker": "Kaelen", "text": "I remember being stupid enough to believe nobility could blush."},
		{"speaker": "Ser Hadrien", "text": "And yet you still fought to gather them in one place at Level Seventeen's parley. Why?"}
	],
	"branch_at": 5,
	"choices": [
		{
			"text": "Because someone must try.",
			"result": "success",
			"response": [
				{"speaker": "Kaelen", "text": "Because if no one tries, all the dead we stacked under those old ideals really did die for nothing."},
				{"speaker": "Ser Hadrien", "text": "...There you are. The man I followed."},
				{"speaker": "Kaelen", "text": "Poor judgment on your part."},
				{"speaker": "Ser Hadrien", "text": "Perhaps. But not my only poor judgment, and certainly not my most regretted."}
			]
		},
		{
			"text": "Habit, maybe.",
			"result": "fail",
			"response": [
				{"speaker": "Kaelen", "text": "Maybe habit. Maybe spite. Hard to tell the difference at my age."},
				{"speaker": "Ser Hadrien", "text": "No, Kaelen. Habit keeps men standing. Hope is what made you speak."},
				{"speaker": "Kaelen", "text": "...You're very tiresome for a dead man."}
			]
		}
	]
},
"Kaelen_SerHadrien_Rank3": {
	"req_level": 18,
	"script": [
		{"speaker": "Ser Hadrien", "text": "The sea is wrong tonight. Even the wind recoils from the Spire."},
		{"speaker": "Kaelen", "text": "Aye. Feels like the world knows it's about to be asked for one more impossible thing."},
		{"speaker": "Ser Hadrien", "text": "You think often of the ones who fell at the first breach."},
		{"speaker": "Kaelen", "text": "I think of them every time the Commander looks at me like I might still be worth trusting."},
		{"speaker": "Ser Hadrien", "text": "And are you?"},
		{"speaker": "Kaelen", "text": "I don't know. I only know I'd spend the rest of what I've got proving it, if the world gives me the hours."},
		{"speaker": "Ser Hadrien", "text": "Then hear me at last, Kaelen: the Order did not fail because one man was imperfect. It failed because too many good men believed secrecy was cleaner than sacrifice. You at least learned to grieve the cost."},
		{"speaker": "Ser Hadrien", "text": "When the Spire opens, what do you intend to leave behind for the Commander: your guilt... or your faith?"}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "My faith.",
			"result": "success",
			"response": [
				{"speaker": "Kaelen", "text": "The faith. Gods help me, somehow I've still got enough left to pass on."},
				{"speaker": "Ser Hadrien", "text": "Good. Let the guilt die with our generation."},
				{"speaker": "Kaelen", "text": "You make that sound almost merciful."},
				{"speaker": "Ser Hadrien", "text": "It is the closest thing to mercy the dead can offer the living."},
				{"speaker": "Kaelen", "text": "...Then stay near tomorrow, old friend. If this is the last breach, I'd rather not face it without the Order at my shoulder one final time."},
				{"speaker": "Ser Hadrien", "text": "You will not."}
			]
		},
		{
			"text": "Both, probably.",
			"result": "fail",
			"response": [
				{"speaker": "Kaelen", "text": "I've carried the two together this long. Hard habit to break."},
				{"speaker": "Ser Hadrien", "text": "Then break it. The Commander will need inheritance, not haunting."},
				{"speaker": "Kaelen", "text": "...You always did know exactly where to put the blade."},
				{"speaker": "Ser Hadrien", "text": "That is why you kept me near."}
			]
		}
	]
},
"BrotherAlden_SisterMeris_Rank1": {
	"req_level": 11,
	"script": [
		{"speaker": "Brother Alden", "text": "You avoided the festival fires more carefully than the assassins."},
		{"speaker": "Sister Meris", "text": "Crowds make confession easy and mercy difficult. I preferred the blades. They were more honest."},
		{"speaker": "Brother Alden", "text": "Once, you would have called a festival crowd a flock to be guarded."},
		{"speaker": "Sister Meris", "text": "Once, I mistook control for guardianship."},
		{"speaker": "Brother Alden", "text": "And now? After the Sunlit Trial, after the Market of Masks, after seeing our own faithful turn fear into spectacle?"}
	],
	"branch_at": 4,
	"choices": [
		{
			"text": "She's changing.",
			"result": "success",
			"response": [
				{"speaker": "Sister Meris", "text": "...Slowly. Shame is less graceful work than doctrine."},
				{"speaker": "Brother Alden", "text": "Good. Grace rarely begins gracefully."},
				{"speaker": "Sister Meris", "text": "You still speak as though I might become something other than the hand that signed those orders."},
				{"speaker": "Brother Alden", "text": "I speak as though repentance is real. Otherwise all our prayers were just polished cowardice."}
			]
		},
		{
			"text": "Some wounds linger.",
			"result": "fail",
			"response": [
				{"speaker": "Sister Meris", "text": "Yes. They do."},
				{"speaker": "Brother Alden", "text": "Lingering is not the same as final."},
				{"speaker": "Sister Meris", "text": "No. But it is heavier."},
				{"speaker": "Brother Alden", "text": "Then let it be heavy. Just do not mistake weight for holiness again."}
			]
		}
	]
},
"BrotherAlden_SisterMeris_Rank2": {
	"req_level": 12,
	"script": [
		{"speaker": "Sister Meris", "text": "The College archive was worse than any cell I ever searched."},
		{"speaker": "Brother Alden", "text": "Because of what it revealed?"},
		{"speaker": "Sister Meris", "text": "Because of what it confirmed. We censored the truth, called it shelter, and built doctrine atop a wound we were too proud to name."},
		{"speaker": "Brother Alden", "text": "You always did hate being made a fool of."},
		{"speaker": "Sister Meris", "text": "I could endure being a fool. It is being an accomplice that poisons the tongue."},
		{"speaker": "Brother Alden", "text": "Then spit it out, Meris. Who are you angry with—the hierarchy, the lie... or yourself?"}
	],
	"branch_at": 5,
	"choices": [
		{
			"text": "Say it plainly.",
			"result": "success",
			"response": [
				{"speaker": "Sister Meris", "text": "...Myself first."},
				{"speaker": "Sister Meris", "text": "The hierarchy taught me certainty. Fear sharpened it. But I was the one who chose obedience every time it was easier than doubt."},
				{"speaker": "Brother Alden", "text": "There. That's the first honest prayer I've heard from you in years."},
				{"speaker": "Sister Meris", "text": "Prayer? It felt more like bloodletting."},
				{"speaker": "Brother Alden", "text": "Often the difference is smaller than we'd like."}
			]
		},
		{
			"text": "The hierarchy used you.",
			"result": "fail",
			"response": [
				{"speaker": "Sister Meris", "text": "They did. And I let them."},
				{"speaker": "Brother Alden", "text": "No one is saying you were blameless."},
				{"speaker": "Sister Meris", "text": "Good. Because I would not trust anyone who tried."},
				{"speaker": "Brother Alden", "text": "Then stop speaking as if guilt is the only honest shape a soul can take."}
			]
		}
	]
},
"BrotherAlden_SisterMeris_Rank3": {
	"req_level": 17,
	"script": [
		{"speaker": "Brother Alden", "text": "You stood outside the Valeron pavilion for a long time before entering the war camp talks."},
		{"speaker": "Sister Meris", "text": "I was deciding whether the Church still sounded holier from the outside."},
		{"speaker": "Brother Alden", "text": "And?"},
		{"speaker": "Sister Meris", "text": "No. Merely louder."},
		{"speaker": "Brother Alden", "text": "There was a time when I thought we would rebuild it together from within."},
		{"speaker": "Sister Meris", "text": "There was a time when I thought you were sentimental enough to be useless."},
		{"speaker": "Brother Alden", "text": "And now?"},
		{"speaker": "Sister Meris", "text": "Now I think sentiment may be the only thing that kept you from becoming me."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "You can rebuild.",
			"result": "success",
			"response": [
				{"speaker": "Brother Alden", "text": "Then help me make sure faith means shelter again."},
				{"speaker": "Sister Meris", "text": "...I do not know whether I deserve that work."},
				{"speaker": "Brother Alden", "text": "Deserving is vanity. Doing it anyway is repentance."},
				{"speaker": "Sister Meris", "text": "You always were intolerably difficult to argue with when you were right."},
				{"speaker": "Brother Alden", "text": "Good. Then stay difficult with me. The world after the Spire will need harder mercy than either of us was taught."},
				{"speaker": "Sister Meris", "text": "Very well. No absolution, then. Only work."},
				{"speaker": "Brother Alden", "text": "That will be enough."}
			]
		},
		{
			"text": "Some scars remain.",
			"result": "fail",
			"response": [
				{"speaker": "Sister Meris", "text": "Yes. They should."},
				{"speaker": "Brother Alden", "text": "Scars are memory, not sentence."},
				{"speaker": "Sister Meris", "text": "You say that as if my hands will forget what they signed."},
				{"speaker": "Brother Alden", "text": "No. I say it because remembering must lead somewhere better than self-damnation."}
			]
		}
	]
},
"Darian_Celia_Rank1": {
	"req_level": 10,
	"script": [
		{"speaker": "Darian", "text": "You know, most people in the Sunlit Trial looked terrified, furious, or sanctimonious. You somehow managed all three while still making armor discipline look elegant."},
		{"speaker": "Celia", "text": "Is that how you speak to every woman who nearly skewered your commander under holy orders?"},
		{"speaker": "Darian", "text": "Only the memorable ones."},
		{"speaker": "Celia", "text": "Then allow me to be clear, Lord Darian: I was not memorable. I was compromised."},
		{"speaker": "Darian", "text": "Ah. So we begin with honesty. Good. I was insufferable long before we met, and yet here I stand."},
		{"speaker": "Celia", "text": "That was not the same thing."},
		{"speaker": "Darian", "text": "No. But perhaps it is adjacent. Tell me, do you prefer being pitied, feared, or treated as if today was merely a dreadful introduction?"}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "A dreadful introduction.",
			"result": "success",
			"response": [
				{"speaker": "Celia", "text": "...That is the least offensive answer I have heard all week."},
				{"speaker": "Darian", "text": "Marvelous. Then I shall endeavor to improve from dreadful to tolerable."},
				{"speaker": "Celia", "text": "Do not rush. You have far to travel."},
				{"speaker": "Darian", "text": "There it is. A blade with wit. We may yet become friends."},
				{"speaker": "Celia", "text": "Do not grow ambitious, my lord."}
			]
		},
		{
			"text": "She deserves patience.",
			"result": "fail",
			"response": [
				{"speaker": "Celia", "text": "Patience is not required. Discipline will suffice."},
				{"speaker": "Darian", "text": "Oh, I've offended her. That is going to make future conversations much more interesting."},
				{"speaker": "Celia", "text": "If by interesting you mean brief, certainly."},
				{"speaker": "Darian", "text": "Now that one almost hurt."}
			]
		}
	]
},
"Darian_Celia_Rank2": {
	"req_level": 11,
	"script": [
		{"speaker": "Celia", "text": "You smiled through half the Market of Masks as if assassins were merely rude party guests."},
		{"speaker": "Darian", "text": "My dear Celia, if one has attended enough noble banquets, there is scarcely any difference."},
		{"speaker": "Celia", "text": "You make mockery sound like a form of etiquette."},
		{"speaker": "Darian", "text": "For the upper class, it often is. We bow, flatter, marry badly, and occasionally poison one another over dessert."},
		{"speaker": "Celia", "text": "You joke about corruption as if humor makes it lighter."},
		{"speaker": "Darian", "text": "No. I joke because if I speak plainly, I start sounding as angry as I actually am."},
		{"speaker": "Celia", "text": "And what are you angry about, precisely?"},
		{"speaker": "Darian", "text": "That people like me were raised to call rot refinement. And people like you were raised to call captivity duty."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "You're alike there.",
			"result": "success",
			"response": [
				{"speaker": "Celia", "text": "...More alike than I would prefer."},
				{"speaker": "Darian", "text": "An encouraging beginning, then. Shared distaste is practically a courtship among the nobility."},
				{"speaker": "Celia", "text": "Do not ruin the moment."},
				{"speaker": "Darian", "text": "Too late. Ruining moments is how I survive them."},
				{"speaker": "Celia", "text": "Then listen carefully, Darian. I do not need rescue from what shaped me."},
				{"speaker": "Darian", "text": "Good. Because I was beginning to suspect you were far more dangerous than I am."}
			]
		},
		{
			"text": "She's not your mirror.",
			"result": "fail",
			"response": [
				{"speaker": "Darian", "text": "No. Fair correction."},
				{"speaker": "Celia", "text": "My chains were not silk. Do not make poetry out of them."},
				{"speaker": "Darian", "text": "...Understood."},
				{"speaker": "Darian", "text": "For what it's worth, I was trying to speak plainly."},
				{"speaker": "Celia", "text": "Then perhaps plainness is a skill we both still need."}
			]
		}
	]
},
"Darian_Celia_Rank3": {
	"req_level": 17,
	"script": [
		{"speaker": "Darian", "text": "I've watched you all day, you know."},
		{"speaker": "Celia", "text": "That sounds like either a confession or a tactical concern."},
		{"speaker": "Darian", "text": "A little of both. During the Gathering Storm, every leader in that camp tried to carry themselves like history was listening. You were the only one who stood like you were listening back."},
		{"speaker": "Celia", "text": "You choose very elaborate roads just to say one kind thing."},
		{"speaker": "Darian", "text": "I was raised decorative. It's hard to recover."},
		{"speaker": "Celia", "text": "Then let me make this easier. We are nearing the Spire. Many of us may not walk back from it. If you have something real to say, Lord Darian, say it before war swallows the chance."},
		{"speaker": "Darian", "text": "...Very well. I admire you. I trust you. And somewhere between the Trial and the market blood and all the miles since, I began wanting a future that had your voice in it."}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "Tell her plainly.",
			"result": "success",
			"response": [
				{"speaker": "Darian", "text": "I love you, Celia. Not as a performance. Not as a flirtation. Simply and inconveniently."},
				{"speaker": "Celia", "text": "...That is the most dangerous thing you have ever said to me."},
				{"speaker": "Darian", "text": "I have said many dangerous things to you."},
				{"speaker": "Celia", "text": "Yes. But this is the first one I wished to hear."},
				{"speaker": "Celia", "text": "I do not know what world waits beyond the Spire. But if we live to see it, I would like to meet it beside you."},
				{"speaker": "Darian", "text": "You realize that is more than enough to ruin me permanently."},
				{"speaker": "Celia", "text": "Then try to survive it, my lord."}
			]
		},
		{
			"text": "Don't force it.",
			"result": "fail",
			"response": [
				{"speaker": "Darian", "text": "...Perhaps admiration is enough."},
				{"speaker": "Celia", "text": "No. Not enough. Only unfinished."},
				{"speaker": "Darian", "text": "That sounds almost hopeful."},
				{"speaker": "Celia", "text": "It is a soldier's answer. Live through the Spire, Darian. Then ask again without a battlefield standing behind you."}
			]
		}
	]
},
"Mira_Pell_Rank1": {
	"req_level": 2,
	"script": [
		{"speaker": "Pell", "text": "That shot in Emberwood was incredible. The one through the branches, I mean. I didn't even see the cultist until he was already falling."},
		{"speaker": "Mira", "text": "You were shouting."},
		{"speaker": "Pell", "text": "...Right. Yes. I suppose I was."},
		{"speaker": "Mira", "text": "The forest was loud enough."},
		{"speaker": "Pell", "text": "Sorry. I just thought— well, no, that's not true. I wasn't thinking at all. I was trying to be brave."},
		{"speaker": "Mira", "text": "You don't need to shout for that."}
	],
	"branch_at": 5,
	"choices": [
		{
			"text": "Listen to Mira.",
			"result": "success",
			"response": [
				{"speaker": "Pell", "text": "I am listening. Very carefully, in fact."},
				{"speaker": "Mira", "text": "Good. Then next time, breathe before you move."},
				{"speaker": "Pell", "text": "That's it? That's the secret?"},
				{"speaker": "Mira", "text": "For you? It would help."},
				{"speaker": "Pell", "text": "...I think that was an insult."},
				{"speaker": "Mira", "text": "It was advice."}
			]
		},
		{
			"text": "He meant well.",
			"result": "fail",
			"response": [
				{"speaker": "Mira", "text": "Most loud mistakes do."},
				{"speaker": "Pell", "text": "That's fair."},
				{"speaker": "Pell", "text": "Painfully fair, actually."},
				{"speaker": "Mira", "text": "Then remember it."}
			]
		}
	]
},
"Mira_Pell_Rank2": {
	"req_level": 6,
	"script": [
		{"speaker": "Pell", "text": "Greyspire's walls make everything echo. Every training mistake sounds twice as embarrassing."},
		{"speaker": "Mira", "text": "Then stop making loud ones."},
		{"speaker": "Pell", "text": "You really do have only one kind of comfort, don't you?"},
		{"speaker": "Mira", "text": "It's useful comfort."},
		{"speaker": "Pell", "text": "It is. I just... I thought taking a fortress would make me feel more like a soldier."},
		{"speaker": "Mira", "text": "And?"},
		{"speaker": "Pell", "text": "Mostly it makes me feel young. Everyone here has ghosts in these halls except me. I only have nerves."}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "Nerves become skill.",
			"result": "success",
			"response": [
				{"speaker": "Mira", "text": "Good. Keep them. Nerves mean you're paying attention."},
				{"speaker": "Pell", "text": "That's... unexpectedly reassuring."},
				{"speaker": "Mira", "text": "You think too much about looking brave."},
				{"speaker": "Pell", "text": "And you don't?"},
				{"speaker": "Mira", "text": "No. I think about surviving long enough to shoot twice."},
				{"speaker": "Pell", "text": "...I like talking to you. You make fear sound practical."}
			]
		},
		{
			"text": "You'll grow into it.",
			"result": "fail",
			"response": [
				{"speaker": "Pell", "text": "I hope so."},
				{"speaker": "Mira", "text": "Hope isn't training."},
				{"speaker": "Pell", "text": "You really won't let a comforting phrase live, will you?"},
				{"speaker": "Mira", "text": "Not if it gets you killed."}
			]
		}
	]
},
"Mira_Pell_Rank3": {
	"req_level": 10,
	"script": [
		{"speaker": "Pell", "text": "You didn't look away during the Sunlit Trial."},
		{"speaker": "Mira", "text": "No."},
		{"speaker": "Pell", "text": "Most people did, at least once. I did. When the outer ring lit. When it looked like the whole arena wanted the Commander to become a lesson."},
		{"speaker": "Mira", "text": "I know."},
		{"speaker": "Pell", "text": "You always know. That's sort of alarming."},
		{"speaker": "Mira", "text": "You looked back."},
		{"speaker": "Pell", "text": "...I did."},
		{"speaker": "Mira", "text": "That's what matters."},
		{"speaker": "Pell", "text": "You say things so simply that I don't notice they've landed until a moment later."}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "Say what you mean.",
			"result": "success",
			"response": [
				{"speaker": "Pell", "text": "What I mean is that when things go bad, I look for you."},
				{"speaker": "Mira", "text": "...Oh."},
				{"speaker": "Pell", "text": "Not because I think you need protecting. Gods, no. More because when you're there, the world feels narrower. Sharper. Less likely to swallow me whole."},
				{"speaker": "Mira", "text": "I look for you too."},
				{"speaker": "Pell", "text": "You do?"},
				{"speaker": "Mira", "text": "Yes. You're loud. It helps."},
				{"speaker": "Pell", "text": "...That is not remotely the confession I imagined, and somehow it is still the best thing anyone's said to me all month."},
				{"speaker": "Mira", "text": "Good. Stay where I can hear you, then."}
			]
		},
		{
			"text": "Take your time.",
			"result": "fail",
			"response": [
				{"speaker": "Pell", "text": "Right. Yes. Sorry. I wasn't trying to make it strange."},
				{"speaker": "Mira", "text": "It isn't strange."},
				{"speaker": "Pell", "text": "No?"},
				{"speaker": "Mira", "text": "No. Just unfinished."},
				{"speaker": "Pell", "text": "...I can live with unfinished."},
				{"speaker": "Mira", "text": "Then do that first."}
			]
		}
	]
},
"Branik_Darian_Rank1": {
	"req_level": 7,
	"script": [
		{"speaker": "Darian", "text": "You know, when I imagined my grand return to Edranor, I pictured banners, cavalry, perhaps a tasteful amount of applause. Not stealing grain under arrow fire with a former brigand."},
		{"speaker": "Branik", "text": "And yet here you are. Breathing, fed, and only half as soft as you were yesterday."},
		{"speaker": "Darian", "text": "A savage assessment. Fair, but savage."},
		{"speaker": "Branik", "text": "You shared the grain in the end. Most men born to silks would've counted sacks before faces."},
		{"speaker": "Darian", "text": "My family counted both. That's the problem."},
		{"speaker": "Branik", "text": "Then tell me plain, lordling: are you trying to mend your name... or outrun it?"}
	],
	"branch_at": 5,
	"choices": [
		{
			"text": "He wants redemption.",
			"result": "success",
			"response": [
				{"speaker": "Darian", "text": "Redemption, I think. Though I admit outrunning it has style."},
				{"speaker": "Branik", "text": "Style won't feed hungry people."},
				{"speaker": "Darian", "text": "No. But perhaps shame, if used properly, might."},
				{"speaker": "Branik", "text": "Good answer. Ugly, useful ones tend to be the real kind."},
				{"speaker": "Darian", "text": "You have a gift for making virtue sound like carpentry."}
			]
		},
		{
			"text": "Maybe both.",
			"result": "fail",
			"response": [
				{"speaker": "Darian", "text": "Possibly both. A man can be complicated."},
				{"speaker": "Branik", "text": "Aye. He can also starve a village while explaining why."},
				{"speaker": "Darian", "text": "...That was well struck."},
				{"speaker": "Branik", "text": "Then stop fencing with the question. Folks need to know what sort of man is standing beside them."}
			]
		}
	]
},
"Branik_Darian_Rank2": {
	"req_level": 8,
	"script": [
		{"speaker": "Branik", "text": "You rode through Elderglen today like the trees were judging your posture."},
		{"speaker": "Darian", "text": "They very well might have been. Your wolf-woman recruit made me feel as if the entire forest had opinions."},
		{"speaker": "Branik", "text": "Inez usually does that."},
		{"speaker": "Darian", "text": "You fit her sort of world more naturally than I do. You and the Commander and everyone else who knows how to stand in a place without trying to own it."},
		{"speaker": "Branik", "text": "That what this is about? You feeling out of place?"},
		{"speaker": "Darian", "text": "I was raised to believe land was inherited, governed, improved. Then I meet people like Inez and realize half my education was just theft with better penmanship."},
		{"speaker": "Branik", "text": "So learn new penmanship."}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "That's good advice.",
			"result": "success",
			"response": [
				{"speaker": "Darian", "text": "Gods, you make transformation sound as simple as splitting wood."},
				{"speaker": "Branik", "text": "Most hard things are simple. They're just not easy."},
				{"speaker": "Darian", "text": "...I do believe I shall steal that line for a poem."},
				{"speaker": "Branik", "text": "Steal whatever you like, long as the next village eats before your ego does."},
				{"speaker": "Darian", "text": "And there it is. Wisdom, followed immediately by assault."}
			]
		},
		{
			"text": "He's being harsh.",
			"result": "fail",
			"response": [
				{"speaker": "Branik", "text": "No. Just plain."},
				{"speaker": "Darian", "text": "Honestly, Commander, that's part of the appeal. It's difficult to romanticize oneself around him."},
				{"speaker": "Branik", "text": "Good. Keep it that way."},
				{"speaker": "Darian", "text": "You truly never learned to take a compliment, did you?"}
			]
		}
	]
},
"Branik_Darian_Rank3": {
	"req_level": 11,
	"script": [
		{"speaker": "Darian", "text": "You can read this one."},
		{"speaker": "Branik", "text": "...Since when do you carry books into a market assassination?"},
		{"speaker": "Darian", "text": "It isn't a book. It's a ledger copy. From the festival chaos. Names, grain contracts, debt notes, transport routes."},
		{"speaker": "Branik", "text": "And?"},
		{"speaker": "Darian", "text": "And I can read it because you taught me to stop pretending illiteracy in practical matters was beneath my notice."},
		{"speaker": "Branik", "text": "Thought you said I was teaching you to write, not to think."},
		{"speaker": "Darian", "text": "You're teaching both, I fear. It's ruining me wonderfully."},
		{"speaker": "Branik", "text": "Then say the important part."},
		{"speaker": "Darian", "text": "...The important part is that I haven't felt like my family's son in weeks. I feel like your student. Maybe your friend. That's a better inheritance than I expected to find in war."}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "You've earned it.",
			"result": "success",
			"response": [
				{"speaker": "Branik", "text": "Aye. You have."},
				{"speaker": "Darian", "text": "That was suspiciously easy."},
				{"speaker": "Branik", "text": "Didn't say it was permanent. Keep acting right."},
				{"speaker": "Darian", "text": "There. That's the Branik I know."},
				{"speaker": "Branik", "text": "Listen well, Darian. Blood gives you a name. The people who stay when you're worth less than the name? That's family."},
				{"speaker": "Darian", "text": "...Then for what it's worth, brother, I'm staying."}
			]
		},
		{
			"text": "Don't get sentimental.",
			"result": "fail",
			"response": [
				{"speaker": "Darian", "text": "Cruel, Commander. Accurate, but cruel."},
				{"speaker": "Branik", "text": "Let him be sentimental. Better that than false."},
				{"speaker": "Darian", "text": "See? That's why he gets the better lines."},
				{"speaker": "Branik", "text": "No. I just waste fewer words."}
			]
		}
	]
},
"Darian_Kaelen_Rank1": {
	"req_level": 7,
	"script": [
		{"speaker": "Kaelen", "text": "You looked sick when the granary gates opened."},
		{"speaker": "Darian", "text": "I was staring at my childhood in ledger form. Grain rationed upward, hunger sent downward, all dressed in seals and signatures."},
		{"speaker": "Kaelen", "text": "Welcome to noble governance."},
		{"speaker": "Darian", "text": "You say that as if you're surprised I noticed."},
		{"speaker": "Kaelen", "text": "I'm surprised you didn't excuse it."},
		{"speaker": "Darian", "text": "I used to. That's the part I'd prefer not to discuss before supper."},
		{"speaker": "Kaelen", "text": "Too bad. Were you blind then, or just comfortable?"}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "Answer him honestly.",
			"result": "success",
			"response": [
				{"speaker": "Darian", "text": "...Comfortable."},
				{"speaker": "Darian", "text": "Blindness would be kinder. I saw enough to know peasants starved. I simply learned how not to let it interrupt the music."},
				{"speaker": "Kaelen", "text": "Good. Keep that answer. Shame's useful if it doesn't turn theatrical."},
				{"speaker": "Darian", "text": "Your methods are brutish, old man."},
				{"speaker": "Kaelen", "text": "And yet effective."}
			]
		},
		{
			"text": "He was young.",
			"result": "fail",
			"response": [
				{"speaker": "Kaelen", "text": "So were the hungry."},
				{"speaker": "Darian", "text": "...All right. Point conceded with extreme violence."},
				{"speaker": "Kaelen", "text": "Good. I dislike wasting a sharp one."}
			]
		}
	]
},
"Darian_Kaelen_Rank2": {
	"req_level": 11,
	"script": [
		{"speaker": "Darian", "text": "You were unreasonably calm during the Market of Masks."},
		{"speaker": "Kaelen", "text": "No, I was tired. There's a difference."},
		{"speaker": "Darian", "text": "Assassins in a festival crowd, League nobles smiling while calculating exits, the Commander being hunted from three balconies at once... and you call that tired?"},
		{"speaker": "Kaelen", "text": "I've lived long enough to know panic's just fear dressed for attention."},
		{"speaker": "Darian", "text": "That is a terrible line. I am stealing it immediately."},
		{"speaker": "Kaelen", "text": "You steal anything not nailed down, including wisdom."},
		{"speaker": "Darian", "text": "Very true. Speaking of theft, why do I get the distinct sense you've been evaluating me the entire campaign like a horse with an injured leg?"},
		{"speaker": "Kaelen", "text": "Because I have. So tell me, noble boy: when the masks come off and the blood starts, are you still acting... or have you finally learned how to stand?"}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "He's learned.",
			"result": "success",
			"response": [
				{"speaker": "Darian", "text": "I still act. That's breeding and self-defense both. But I stand as well."},
				{"speaker": "Kaelen", "text": "...Aye. You do."},
				{"speaker": "Darian", "text": "That sounded suspiciously like praise."},
				{"speaker": "Kaelen", "text": "Don't get greedy. It's an observation."},
				{"speaker": "Darian", "text": "From you, that's practically inheritance."},
				{"speaker": "Kaelen", "text": "Gods save me, you really do need a father."}
			]
		},
		{
			"text": "He's still acting.",
			"result": "fail",
			"response": [
				{"speaker": "Darian", "text": "Commander, your cruelty continues to mature beautifully."},
				{"speaker": "Kaelen", "text": "They're not entirely wrong."},
				{"speaker": "Darian", "text": "No. But I prefer my dismantling with fewer witnesses."},
				{"speaker": "Kaelen", "text": "Learn to take the hit. That's part of standing too."}
			]
		}
	]
},
"Darian_Kaelen_Rank3": {
	"req_level": 14,
	"script": [
		{"speaker": "Darian", "text": "After Dawnkeep, half the camp looks at you like a traitor and the other half looks at you like a martyr. It must be exhausting being so divisive."},
		{"speaker": "Kaelen", "text": "It's exhausting being old around people who still think truth arrives clean."},
		{"speaker": "Darian", "text": "You realize that was nearly poetic."},
		{"speaker": "Kaelen", "text": "Don't start."},
		{"speaker": "Darian", "text": "I wasn't going to flatter you. I was going to ask why you trusted me with the Commander's flank at the keep."},
		{"speaker": "Kaelen", "text": "Because when the walls shook, you moved toward the civilians before the archers. Men show themselves in that order."},
		{"speaker": "Darian", "text": "...You noticed that?"},
		{"speaker": "Kaelen", "text": "Aye. I notice more than I say. Occupational hazard."},
		{"speaker": "Darian", "text": "Then let me ask plainly, old man. Do you still think I'm just silk over rot?"}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "Tell him no.",
			"result": "success",
			"response": [
				{"speaker": "Kaelen", "text": "No. Now I think you're silk over guilt, with a spine finally hardening underneath."},
				{"speaker": "Darian", "text": "That is somehow the kindest thing you've ever said to me."},
				{"speaker": "Kaelen", "text": "Don't spread that around."},
				{"speaker": "Darian", "text": "Perish the thought. Your reputation might survive."},
				{"speaker": "Kaelen", "text": "Listen close, Darian. A good commander needs officers who can still hear shame without drowning in it. You're getting there."},
				{"speaker": "Darian", "text": "...Then for what it's worth, if the Commander survives the Spire and needs men worth following, I intend to be one."}
			]
		},
		{
			"text": "He still doubts.",
			"result": "fail",
			"response": [
				{"speaker": "Kaelen", "text": "I doubt everyone. That's why any of you are still alive."},
				{"speaker": "Darian", "text": "An appalling answer. Very you."},
				{"speaker": "Kaelen", "text": "Earning trust is work, not weather. Keep doing it."},
				{"speaker": "Darian", "text": "...I hate how often your advice sounds like a sentence and a blessing at once."}
			]
		}
	]
},
"Nyx_Sorrel_Rank1": {
	"req_level": 6,
	"script": [
		{"speaker": "Nyx", "text": "You reorganized Greyspire's archive by century, subject, and ritual hazard rating. That's either genius or a cry for help."},
		{"speaker": "Sorrel", "text": "It is neither. It is basic archival triage."},
		{"speaker": "Nyx", "text": "You say that as if haunted fortresses routinely come with shelving problems."},
		{"speaker": "Sorrel", "text": "Most do, if their previous owners were aristocrats, knights, or cultists. Greyspire unfortunately featured all three."},
		{"speaker": "Nyx", "text": "You know, I left you a harmless smoke-vial in one of those folios. For educational purposes."},
		{"speaker": "Sorrel", "text": "Yes. And I swapped the labels on your fuse compounds. Also for educational purposes."}
	],
	"branch_at": 5,
	"choices": [
		{
			"text": "Call it even.",
			"result": "success",
			"response": [
				{"speaker": "Nyx", "text": "...All right, that's actually funny."},
				{"speaker": "Sorrel", "text": "Thank you. I spent longer on the symmetry than was strictly necessary."},
				{"speaker": "Nyx", "text": "You scare me when you start sounding proud of sabotage."},
				{"speaker": "Sorrel", "text": "And yet you are still here."},
				{"speaker": "Nyx", "text": "Mostly because I want to see what happens when I escalate."}
			]
		},
		{
			"text": "Nyx started it.",
			"result": "fail",
			"response": [
				{"speaker": "Nyx", "text": "Commander, betrayal. In front of the scholar, no less."},
				{"speaker": "Sorrel", "text": "Accuracy is not betrayal."},
				{"speaker": "Nyx", "text": "Gods, now there are two of you."},
				{"speaker": "Sorrel", "text": "An unfortunate development for your peace of mind, certainly."}
			]
		}
	]
},
"Nyx_Sorrel_Rank2": {
	"req_level": 9,
	"script": [
		{"speaker": "Sorrel", "text": "Your observation during the League council map was correct, by the way."},
		{"speaker": "Nyx", "text": "I make many correct observations. Narrow it down."},
		{"speaker": "Sorrel", "text": "The one where you said the kidnapping routes were designed by someone who thought in debt ledgers instead of streets."},
		{"speaker": "Nyx", "text": "Ah. Yes. You can always tell when rich men outsource ugliness. The plan gets neat in the wrong places."},
		{"speaker": "Sorrel", "text": "I wrote that down."},
		{"speaker": "Nyx", "text": "...Should I be offended?"},
		{"speaker": "Sorrel", "text": "No. I found it insightful. You notice systems from below. I was trained to notice them from above. Together the shape becomes clearer."}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "That's a compliment.",
			"result": "success",
			"response": [
				{"speaker": "Nyx", "text": "I know it's a compliment. I'm deciding whether I enjoy the delivery."},
				{"speaker": "Sorrel", "text": "You may file a procedural complaint later."},
				{"speaker": "Nyx", "text": "See, this is why I keep you around. Every now and then you say something so dry it loops back into wit."},
				{"speaker": "Sorrel", "text": "I was unaware I was being kept."},
				{"speaker": "Nyx", "text": "Don't get sentimental, scholar. It's embarrassing on everyone."}
			]
		},
		{
			"text": "You're both strange.",
			"result": "fail",
			"response": [
				{"speaker": "Nyx", "text": "Finally, recognition."},
				{"speaker": "Sorrel", "text": "I accept the classification if it is evenly distributed."},
				{"speaker": "Nyx", "text": "See? This is why the camp thinks we're plotting."},
				{"speaker": "Sorrel", "text": "We are frequently plotting."},
				{"speaker": "Nyx", "text": "...Fair point."}
			]
		}
	]
},
"Nyx_Sorrel_Rank3": {
	"req_level": 12,
	"script": [
		{"speaker": "Sorrel", "text": "The College archives were... enlightening. But also deeply illogical."},
		{"speaker": "Nyx", "text": "Illogical? They lied to the whole world for centuries to keep their power. That's the most logical thing I've ever heard."},
		{"speaker": "Sorrel", "text": "I suppose. I am merely frustrated that I didn't see the pattern sooner. I am a scholar. I should have recognized the omission."},
		{"speaker": "Nyx", "text": "Hey. Don't do that. You can't see a shadow if you're standing in the middle of a spotlight."},
		{"speaker": "Sorrel", "text": "A remarkably apt metaphor for cognitive bias."},
		{"speaker": "Nyx", "text": "It's a metaphor for why I like you. You're brilliant, but you're too honest for your own good. You need someone who knows how to lie to keep you safe."},
		{"speaker": "Sorrel", "text": "...And you? What do you gain from this arrangement?"},
		{"speaker": "Nyx", "text": "Maybe I just like having someone around who actually believes the truth is worth finding. Even if it's messy."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "Trust each other.",
			"result": "success",
			"response": [
				{"speaker": "Sorrel", "text": "...Then perhaps I should say this plainly. I trust your instincts, Nyx."},
				{"speaker": "Nyx", "text": "That is a dangerous sentence to hand me."},
				{"speaker": "Sorrel", "text": "Possibly. But accurate."},
				{"speaker": "Nyx", "text": "All right, scholar. Then here's one back: I trust your brain not to worship the things it studies."},
				{"speaker": "Sorrel", "text": "That may be the kindest thing you've ever said to me."},
				{"speaker": "Nyx", "text": "Don't look so pleased. You'll ruin my reputation."}
			]
		},
		{
			"text": "You're both paying.",
			"result": "fail",
			"response": [
				{"speaker": "Nyx", "text": "Well. That's uncomfortably wise."},
				{"speaker": "Sorrel", "text": "Yes. The trouble is that wisdom rarely refunds anyone."},
				{"speaker": "Nyx", "text": "No. But sometimes it helps you stop buying the same lie twice."},
				{"speaker": "Sorrel", "text": "...That is still useful."}
			]
		}
	]
},
"Hest_Nyx_Rank1": {
	"req_level": 4,
	"script": [
		{"speaker": "Hest", "text": "So. Merchant's Maze. Slums, rooftops, sewer stink, three near-deaths, and one extremely beautiful purse-lifting demonstration. I think I learned a lot."},
		{"speaker": "Nyx", "text": "You learned that if you shadow me again without warning, I may eventually sell you to a respectable chimney."},
		{"speaker": "Hest", "text": "Aw. That's almost affectionate."},
		{"speaker": "Nyx", "text": "No, gremlin. Affection sounds different. Usually less breathless and less likely to end with guards chasing us over fish crates."},
		{"speaker": "Hest", "text": "You did not look displeased."},
		{"speaker": "Nyx", "text": "I looked busy keeping you from getting stabbed over a copper clasp and half a sausage."}
	],
	"branch_at": 5,
	"choices": [
		{
			"text": "Nyx saved you.",
			"result": "success",
			"response": [
				{"speaker": "Hest", "text": "I noticed."},
				{"speaker": "Nyx", "text": "...Good. Then notice this too: next time you want to learn from me, ask first."},
				{"speaker": "Hest", "text": "And if you say no?"},
				{"speaker": "Nyx", "text": "Then sneak better."},
				{"speaker": "Hest", "text": "Ha! There you are. Knew you had standards, not principles."},
				{"speaker": "Nyx", "text": "Keep grinning like that and I'll assign you to latrine reconnaissance."}
			]
		},
		{
			"text": "Hest kept up.",
			"result": "fail",
			"response": [
				{"speaker": "Nyx", "text": "Barely. Which is still more credit than they deserve."},
				{"speaker": "Hest", "text": "I'll take barely. Barely alive is still alive."},
				{"speaker": "Nyx", "text": "A philosophy written by children and drunk smugglers."},
				{"speaker": "Hest", "text": "And yet proven effective."}
			]
		}
	]
},
"Hest_Nyx_Rank2": {
	"req_level": 6,
	"script": [
		{"speaker": "Nyx", "text": "Why is there a soot handprint on my workbench?"},
		{"speaker": "Hest", "text": "Because Greyspire is haunted, obviously."},
		{"speaker": "Nyx", "text": "Try again. The ghosts here have better taste in tools."},
		{"speaker": "Hest", "text": "...I was borrowing the little spring-loaded latch."},
		{"speaker": "Nyx", "text": "Borrowing implies I was going to see it again."},
		{"speaker": "Hest", "text": "You did see it again. It just came back attached to a trap that launched stale bread at Pell when he opened the supply chest."},
		{"speaker": "Nyx", "text": "That was you? I assumed the fortress itself had lost patience with him."}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "Teach them properly.",
			"result": "success",
			"response": [
				{"speaker": "Nyx", "text": "Gods help me, that's apparently where this is going."},
				{"speaker": "Hest", "text": "So you'll do it?"},
				{"speaker": "Nyx", "text": "On three conditions: no touching my powder, no improvising with live fuses, and no traps in the infirmary ever again."},
				{"speaker": "Hest", "text": "That last one was an accident."},
				{"speaker": "Nyx", "text": "Precisely why it's a rule now."},
				{"speaker": "Hest", "text": "...This is the nicest threat anyone's ever made me."}
			]
		},
		{
			"text": "Hest means well.",
			"result": "fail",
			"response": [
				{"speaker": "Nyx", "text": "That's the problem. Good intentions are what make amateur saboteurs so exhausting."},
				{"speaker": "Hest", "text": "You say amateur like I can't improve."},
				{"speaker": "Nyx", "text": "Oh, you can. I just prefer to survive the process."},
				{"speaker": "Hest", "text": "Harsh. Fair, but harsh."}
			]
		}
	]
},
"Hest_Nyx_Rank3": {
	"req_level": 9,
	"script": [
		{"speaker": "Hest", "text": "You were different during the council mess."},
		{"speaker": "Nyx", "text": "That's uncomfortably vague. Different how?"},
		{"speaker": "Hest", "text": "Quieter. Meaner in the eyes. Like you already knew every lock in those warehouses and exactly how much each one cost somebody."},
		{"speaker": "Nyx", "text": "Because I did."},
		{"speaker": "Hest", "text": "Yeah. I figured."},
		{"speaker": "Nyx", "text": "Listen carefully, Sparks. Cities like that eat children who think quick hands are the same thing as freedom."},
		{"speaker": "Hest", "text": "And if the child already knows that?"},
		{"speaker": "Nyx", "text": "Then they learn the harder lesson: staying alive long enough to trust someone is not weakness. It's luck. The kind most of us don't get twice."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "You got it here.",
			"result": "success",
			"response": [
				{"speaker": "Hest", "text": "...You're talking about this camp."},
				{"speaker": "Nyx", "text": "Don't make me repeat a soft thought. I have a reputation."},
				{"speaker": "Hest", "text": "Too late. I heard it. You think this is luck."},
				{"speaker": "Nyx", "text": "I think it's rare. Which means you stop treating yourself like you're one bad meal away from vanishing."},
				{"speaker": "Hest", "text": "What if I don't know how?"},
				{"speaker": "Nyx", "text": "Then stay near me, steal less, and watch how the rest of us fumble through it."},
				{"speaker": "Hest", "text": "...All right. But only because your version of caring is entertaining."}
			]
		},
		{
			"text": "They're tougher now.",
			"result": "fail",
			"response": [
				{"speaker": "Nyx", "text": "No. That's not the point."},
				{"speaker": "Hest", "text": "I am tougher, though."},
				{"speaker": "Nyx", "text": "Yes. But toughness is cheap. Belonging is expensive."},
				{"speaker": "Hest", "text": "...That is an awful sentence. I hate how good it is."},
				{"speaker": "Nyx", "text": "Get used to it. I do my best work when I'm miserable."}
			]
		}
	]
},
"Hest_Tamsin_Rank1": {
	"req_level": 4,
	"script": [
		{"speaker": "Tamsin", "text": "There were four missing salve wraps after Merchant's Maze, and then suddenly two children in the alley behind the tannery had fresh bandages. Would you like to explain that?"},
		{"speaker": "Hest", "text": "I prefer the term redistribution."},
		{"speaker": "Tamsin", "text": "You stole from the medical satchel."},
		{"speaker": "Hest", "text": "Borrowed. Generously. For public health."},
		{"speaker": "Tamsin", "text": "You cannot just take supplies because your conscience points at something wounded! There are measures, preparations, clean handling procedures—"},
		{"speaker": "Hest", "text": "Yeah, and while procedures were introducing themselves, those kids were still bleeding."}
	],
	"branch_at": 5,
	"choices": [
		{
			"text": "Tamsin, hear them.",
			"result": "success",
			"response": [
				{"speaker": "Tamsin", "text": "...I am hearing them. I am also hearing every rule I have ever been taught screaming in my head."},
				{"speaker": "Hest", "text": "Rules are loud. Blood is louder."},
				{"speaker": "Tamsin", "text": "That is not medically rigorous."},
				{"speaker": "Hest", "text": "No. But it worked."},
				{"speaker": "Tamsin", "text": "...Next time, tell me first. If we're going to save strangers in alleys, I'd prefer to do it with the correct amount of bandage."}
			]
		},
		{
			"text": "Hest stole supplies.",
			"result": "fail",
			"response": [
				{"speaker": "Hest", "text": "Such ugly phrasing for such noble outcomes."},
				{"speaker": "Tamsin", "text": "Noble outcomes get infections too, you know."},
				{"speaker": "Hest", "text": "Fine. Next time I'll steal cleaner."},
				{"speaker": "Tamsin", "text": "That is absolutely not what I meant!"}
			]
		}
	]
},
"Hest_Tamsin_Rank2": {
	"req_level": 6,
	"script": [
		{"speaker": "Tamsin", "text": "Why is there a wire loop attached to the infirmary shelf?"},
		{"speaker": "Hest", "text": "Security."},
		{"speaker": "Tamsin", "text": "Against whom?"},
		{"speaker": "Hest", "text": "People who touch your nice clean bottles with muddy hands and no respect for chemistry."},
		{"speaker": "Tamsin", "text": "...You made a trap to protect my supplies?"},
		{"speaker": "Hest", "text": "A very small trap. It just rattles spoons and humiliates them publicly."},
		{"speaker": "Tamsin", "text": "That is absurd."},
		{"speaker": "Hest", "text": "You say absurd. I say Greyspire finally has standards."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "It's thoughtful, actually.",
			"result": "success",
			"response": [
				{"speaker": "Tamsin", "text": "...It is, a little."},
				{"speaker": "Hest", "text": "Ha! Vindication."},
				{"speaker": "Tamsin", "text": "Do not celebrate yet. The wire tension is wrong, and if Pell brushes past it at speed he'll wear the entire spoon rack as a necklace."},
				{"speaker": "Hest", "text": "So you'll help me fix it?"},
				{"speaker": "Tamsin", "text": "Only because I apparently live among lunatics."},
				{"speaker": "Hest", "text": "Aww. That's practically friendship."}
			]
		},
		{
			"text": "Take the trap down.",
			"result": "fail",
			"response": [
				{"speaker": "Hest", "text": "Tyranny."},
				{"speaker": "Tamsin", "text": "No, basic infirmary safety."},
				{"speaker": "Hest", "text": "You wound me."},
				{"speaker": "Tamsin", "text": "Then sit down and I'll disinfect the metaphor."}
			]
		}
	]
},
"Hest_Tamsin_Rank3": {
	"req_level": 9,
	"script": [
		{"speaker": "Hest", "text": "You didn't shake once during the kidnapping mess."},
		{"speaker": "Tamsin", "text": "I shook plenty after. During, I was busy."},
		{"speaker": "Hest", "text": "No, I mean it. Everyone else was chasing thieves and shouting in warehouses. You were just there, tying wounds, yelling at me to stop touching broken glass, acting like panic was an optional accessory."},
		{"speaker": "Tamsin", "text": "It is optional. It just arrives uninvited."},
		{"speaker": "Hest", "text": "You know what I think? I think you're brave in a much more annoying way than Pell is."},
		{"speaker": "Tamsin", "text": "...That may be the strangest compliment I've ever received."},
		{"speaker": "Hest", "text": "Good. Because I'm trying to say thank you without sounding soft."}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "Say it anyway.",
			"result": "success",
			"response": [
				{"speaker": "Hest", "text": "...Thank you."},
				{"speaker": "Tamsin", "text": "You're welcome."},
				{"speaker": "Hest", "text": "For patching people up. For yelling at me. For making the whole army feel less like it's being held together by curses and stubbornness."},
				{"speaker": "Tamsin", "text": "It is still mostly being held together by stubbornness."},
				{"speaker": "Hest", "text": "Yeah. But now it's medically supervised stubbornness."},
				{"speaker": "Tamsin", "text": "...I think that's the nicest thing you've ever said to me."}
			]
		},
		{
			"text": "You both helped.",
			"result": "fail",
			"response": [
				{"speaker": "Hest", "text": "I know I helped. I'm very talented."},
				{"speaker": "Tamsin", "text": "That was not the part I was uncertain about."},
				{"speaker": "Hest", "text": "See? We understand each other perfectly."},
				{"speaker": "Tamsin", "text": "No, Hest. But we are improving at surviving one another."}
			]
		}
	]
},
"Inez_Mira_Rank1": {
	"req_level": 8,
	"script": [
		{"speaker": "Inez", "text": "You step quietly for someone raised outside the deep woods."},
		{"speaker": "Mira", "text": "Oakhaven had hunters."},
		{"speaker": "Inez", "text": "Not like Elderglen."},
		{"speaker": "Mira", "text": "No."},
		{"speaker": "Inez", "text": "You watched the tree line during the skirmish instead of the shrine."},
		{"speaker": "Mira", "text": "Shrines don't flank. Men do."},
		{"speaker": "Inez", "text": "...Good answer."}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "Mira learns fast.",
			"result": "success",
			"response": [
				{"speaker": "Inez", "text": "Fast is useful. Fast and careless gets buried shallow."},
				{"speaker": "Mira", "text": "I'm not careless."},
				{"speaker": "Inez", "text": "No. I noticed."},
				{"speaker": "Mira", "text": "...Was that praise?"},
				{"speaker": "Inez", "text": "Don't get hungry for it. Hunger makes noise."}
			]
		},
		{
			"text": "You're alike there.",
			"result": "fail",
			"response": [
				{"speaker": "Inez", "text": "Maybe."},
				{"speaker": "Mira", "text": "That's enough."},
				{"speaker": "Inez", "text": "For now."},
				{"speaker": "Mira", "text": "For now is still better than nothing."}
			]
		}
	]
},
"Inez_Mira_Rank2": {
	"req_level": 10,
	"script": [
		{"speaker": "Mira", "text": "You hated the Sunlit Trial."},
		{"speaker": "Inez", "text": "Crowds that cheer while someone is cornered disgust me."},
		{"speaker": "Mira", "text": "Me too."},
		{"speaker": "Inez", "text": "You kept scanning the exits instead of the arena floor."},
		{"speaker": "Mira", "text": "I wanted to know where they'd come from if it turned into an execution."},
		{"speaker": "Inez", "text": "Good instinct."},
		{"speaker": "Mira", "text": "It wasn't instinct. Oakhaven taught me what crowds look like right before they stop being people and become weather."},
		{"speaker": "Inez", "text": "...Then Oakhaven taught you something cruel and useful both."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "Tell her that.",
			"result": "success",
			"response": [
				{"speaker": "Inez", "text": "Listen carefully, Mira. What was done to your village was not a lesson you deserved."},
				{"speaker": "Mira", "text": "...I know."},
				{"speaker": "Inez", "text": "Good. Remember that while you keep the skill. Throw away the lie that pain had to shape you to make you useful."},
				{"speaker": "Mira", "text": "You make that sound possible."},
				{"speaker": "Inez", "text": "It is possible. Hard. But possible."}
			]
		},
		{
			"text": "Useful still matters.",
			"result": "fail",
			"response": [
				{"speaker": "Inez", "text": "Useful is not the same as right."},
				{"speaker": "Mira", "text": "I know that."},
				{"speaker": "Inez", "text": "Then don't let adults turn your scars into strategy and call that wisdom."},
				{"speaker": "Mira", "text": "...All right."}
			]
		}
	]
},
"Inez_Mira_Rank3": {
	"req_level": 13,
	"script": [
		{"speaker": "Inez", "text": "On the Black Coast, when the rain cut sightlines, you compensated before the archers on the wall did."},
		{"speaker": "Mira", "text": "Wind changed off the sea."},
		{"speaker": "Inez", "text": "Yes. And you read it."},
		{"speaker": "Mira", "text": "You told me to watch leaves, cloth, fur, ash... whatever the world gives away first."},
		{"speaker": "Inez", "text": "I did."},
		{"speaker": "Mira", "text": "You also said not to chase praise."},
		{"speaker": "Inez", "text": "Correct."},
		{"speaker": "Mira", "text": "Then I'll say this before you can stop me. I wanted you to see it."},
		{"speaker": "Inez", "text": "...I did see it."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "You impressed her.",
			"result": "success",
			"response": [
				{"speaker": "Inez", "text": "More than that. You listened. Most don't."},
				{"speaker": "Mira", "text": "You make listening sound rare."},
				{"speaker": "Inez", "text": "It is. Especially in war."},
				{"speaker": "Inez", "text": "If you want it plain: I would trust you in my forest, at my back, or watching a trail I meant to walk later. I do not say that lightly."},
				{"speaker": "Mira", "text": "...Thank you."},
				{"speaker": "Inez", "text": "Good. That's enough gratitude. Tomorrow we work on moving over wet stone without announcing your knees."}
			]
		},
		{
			"text": "Keep training her.",
			"result": "fail",
			"response": [
				{"speaker": "Inez", "text": "I intend to."},
				{"speaker": "Mira", "text": "That sounded almost disappointed."},
				{"speaker": "Inez", "text": "No. Just unfinished."},
				{"speaker": "Mira", "text": "You do that a lot."},
				{"speaker": "Inez", "text": "So do forests. The useful ones keep growing."}
			]
		}
	]
},
"OrenPike_Rufus_Rank1": {
	"req_level": 6,
	"script": [
		{"speaker": "Oren Pike", "text": "You load a hand-cannon like you expect the barrel to apologize afterward."},
		{"speaker": "Rufus", "text": "And you talk like every tool in Greyspire personally offended your ancestors."},
		{"speaker": "Oren Pike", "text": "Most of them have. Half this fortress was maintained by zealots, amateurs, or noble sons with decorative wrists."},
		{"speaker": "Rufus", "text": "Fair. Still, my shots landed during the siege."},
		{"speaker": "Oren Pike", "text": "Aye. Sloppy hands, solid instincts."},
		{"speaker": "Rufus", "text": "...That might be the nicest insult I've had all month."},
		{"speaker": "Oren Pike", "text": "Then answer me this, cannoneer: you want praise, or do you want your recoil arm to still function by winter?"}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "Take the lesson.",
			"result": "success",
			"response": [
				{"speaker": "Rufus", "text": "All right, all right. Show me what I'm doing wrong."},
				{"speaker": "Oren Pike", "text": "Grip too tight here, too loose there. You're fighting the weight instead of letting it settle into you."},
				{"speaker": "Rufus", "text": "That sounds suspiciously philosophical for a man who smells like oil."},
				{"speaker": "Oren Pike", "text": "Tools punish vanity. That's philosophy enough."},
				{"speaker": "Rufus", "text": "...Huh. Fine. You keep talking like that, I might start improving on purpose."}
			]
		},
		{
			"text": "His shots worked.",
			"result": "fail",
			"response": [
				{"speaker": "Oren Pike", "text": "So does a cracked wheel right up until it shears off."},
				{"speaker": "Rufus", "text": "Charming. You always flirt like this?"},
				{"speaker": "Oren Pike", "text": "Only with people trying to break my artillery."},
				{"speaker": "Rufus", "text": "Then I suppose I'm honored."}
			]
		}
	]
},
"OrenPike_Rufus_Rank2": {
	"req_level": 9,
	"script": [
		{"speaker": "Rufus", "text": "You were right about the warehouse drawbridges."},
		{"speaker": "Oren Pike", "text": "I make a habit of being right about structures that don't want to fall on my head."},
		{"speaker": "Rufus", "text": "No, I mean the kidnap routes. The council district was built to move cargo fast and people quietly. Once you said that, the whole place made sense."},
		{"speaker": "Oren Pike", "text": "That's the League for you. Elegant canals on the surface, ugly accounting under the floorboards."},
		{"speaker": "Rufus", "text": "You sound like a man who's been cheated by rich employers before."},
		{"speaker": "Oren Pike", "text": "I've been hired by them. Worse condition, usually."},
		{"speaker": "Rufus", "text": "Heh. Fair enough. Still, you saw that whole map like it was a machine. I liked that."},
		{"speaker": "Oren Pike", "text": "And I liked that you didn't freeze when the abductors doubled back. Means you're teachable, which is more than I can say for half the camp."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "You work well together.",
			"result": "success",
			"response": [
				{"speaker": "Rufus", "text": "That's one way to say we both hate being outsmarted by architecture."},
				{"speaker": "Oren Pike", "text": "No. It means you see pressure points instead of just targets."},
				{"speaker": "Rufus", "text": "...Coming from you, that's dangerously close to respect."},
				{"speaker": "Oren Pike", "text": "Don't grin at me. It'll ruin the moment."},
				{"speaker": "Rufus", "text": "Too late. I'm keeping this one."}
			]
		},
		{
			"text": "You just complain alike.",
			"result": "fail",
			"response": [
				{"speaker": "Rufus", "text": "Commander, that's not unfair."},
				{"speaker": "Oren Pike", "text": "No, but it's incomplete. There's complaining, and then there's professional assessment."},
				{"speaker": "Rufus", "text": "See? That's exactly what I mean. Same language, different boots."},
				{"speaker": "Oren Pike", "text": "...I dislike how much sense that makes."}
			]
		}
	]
},
"OrenPike_Rufus_Rank3": {
	"req_level": 11,
	"script": [
		{"speaker": "Oren Pike", "text": "You held that western balcony better than I expected in the Market of Masks."},
		{"speaker": "Rufus", "text": "Expected me to panic?"},
		{"speaker": "Oren Pike", "text": "Expected you to chase the obvious shot and miss the real one. Most gunners do when crowds get involved."},
		{"speaker": "Rufus", "text": "Dock work teaches you quick. If a crate swings wrong in a crowd, the idiot under it usually isn't the one who caused the problem."},
		{"speaker": "Oren Pike", "text": "Hnh. That's almost wisdom."},
		{"speaker": "Rufus", "text": "Careful. Say something nice like that too often and I'll start thinking you enjoy my company."},
		{"speaker": "Oren Pike", "text": "I enjoy competence. Your company's just attached to it."},
		{"speaker": "Rufus", "text": "...That is the most Oren Pike thing I've ever heard."},
		{"speaker": "Oren Pike", "text": "Then hear one more: if we survive this war, I'd rather build with men who understand weight than nobles who understand signatures. You interested?"}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "Take the offer.",
			"result": "success",
			"response": [
				{"speaker": "Rufus", "text": "...Yeah. I think I am."},
				{"speaker": "Rufus", "text": "No guild debts, no polished liars, no 'honorable' shortages. Just work that does what it's meant to do."},
				{"speaker": "Oren Pike", "text": "Exactly."},
				{"speaker": "Rufus", "text": "All right then. If the world doesn't end at the Spire, you and I are building something sturdier than the one we got."},
				{"speaker": "Oren Pike", "text": "Good. First rule: no decorative arches unless they can survive weather and fools."},
				{"speaker": "Rufus", "text": "See? This is why I trust you."}
			]
		},
		{
			"text": "That sounds dangerous.",
			"result": "fail",
			"response": [
				{"speaker": "Rufus", "text": "Dangerous, yes. Also suspiciously hopeful."},
				{"speaker": "Oren Pike", "text": "Don't spread that around."},
				{"speaker": "Rufus", "text": "Too late. I've already decided to be insufferably touched by it."},
				{"speaker": "Oren Pike", "text": "...I may revoke the offer on personality grounds."}
			]
		}
	]
},
"Pell_Veska_Rank1": {
	"req_level": 14,
	"script": [
		{"speaker": "Pell", "text": "You held the south gate almost by yourself at Dawnkeep."},
		{"speaker": "Veska Moor", "text": "No. I held it with a shield, a wall, and several enemies making poor life choices."},
		{"speaker": "Pell", "text": "Right. Yes. Of course. Still, it was incredible."},
		{"speaker": "Veska Moor", "text": "You use that word too much."},
		{"speaker": "Pell", "text": "...Sorry. I just meant— when the keep started collapsing and everyone split to the tunnels, you didn't move an inch."},
		{"speaker": "Veska Moor", "text": "That was the job."},
		{"speaker": "Pell", "text": "How do you make it sound that simple?"}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "Ask her to teach you.",
			"result": "success",
			"response": [
				{"speaker": "Pell", "text": "Then... would you teach me? How to stand like that, I mean."},
				{"speaker": "Veska Moor", "text": "...Maybe."},
				{"speaker": "Pell", "text": "Maybe?"},
				{"speaker": "Veska Moor", "text": "If you stop admiring courage long enough to practice it."},
				{"speaker": "Pell", "text": "That sounded harsh, but I think it was also permission."},
				{"speaker": "Veska Moor", "text": "Good. You're listening already."}
			]
		},
		{
			"text": "He means respect.",
			"result": "fail",
			"response": [
				{"speaker": "Veska Moor", "text": "Respect is fine. Worship is useless."},
				{"speaker": "Pell", "text": "I wasn't worshipping!"},
				{"speaker": "Veska Moor", "text": "Then breathe. Heroes who forget to breathe become memorials."},
				{"speaker": "Pell", "text": "...That is a horrible sentence. I will remember it forever."}
			]
		}
	]
},
"Pell_Veska_Rank2": {
	"req_level": 15,
	"script": [
		{"speaker": "Veska Moor", "text": "You overcommitted in the marsh."},
		{"speaker": "Pell", "text": "I thought if I reached the totem first, the wraiths would turn."},
		{"speaker": "Veska Moor", "text": "And instead you sank to the knee in poison and nearly lost your spear."},
		{"speaker": "Pell", "text": "When you say it like that, it sounds less tactical."},
		{"speaker": "Veska Moor", "text": "That's because it wasn't tactical. It was panic dressed as initiative."},
		{"speaker": "Pell", "text": "...You really do hit exactly where it hurts."},
		{"speaker": "Veska Moor", "text": "Good. Better me than a grave."},
		{"speaker": "Pell", "text": "Then tell me straight. What's the difference between bravery and whatever that was?"}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "Hear her answer.",
			"result": "success",
			"response": [
				{"speaker": "Veska Moor", "text": "Bravery holds the line when fear says run. What you did was sprint toward fear so you wouldn't have to feel it catch up."},
				{"speaker": "Pell", "text": "...That is painfully accurate."},
				{"speaker": "Veska Moor", "text": "Good. Use the pain."},
				{"speaker": "Pell", "text": "You make growth sound like being beaten into shape with a shield rim."},
				{"speaker": "Veska Moor", "text": "For some people, that's close enough."},
				{"speaker": "Pell", "text": "...All right. Then keep teaching me. I'd rather bruise here than fail later."}
			]
		},
		{
			"text": "He was trying.",
			"result": "fail",
			"response": [
				{"speaker": "Veska Moor", "text": "I know. That's why I'm correcting him instead of burying him."},
				{"speaker": "Pell", "text": "Commander, I think that's her version of concern."},
				{"speaker": "Veska Moor", "text": "It is."},
				{"speaker": "Pell", "text": "...Strangely enough, that helps."}
			]
		}
	]
},
"Pell_Veska_Rank3": {
	"req_level": 17,
	"script": [
		{"speaker": "Pell", "text": "During the war camp talks, when the officers started posturing, I almost stepped in. Then I heard your voice in my head telling me not to confuse movement with usefulness."},
		{"speaker": "Veska Moor", "text": "Good. My voice should be haunting at least one person by now."},
		{"speaker": "Pell", "text": "You joke, but it worked. I stayed with the supply lane instead. No one noticed. Which, oddly enough, felt... right."},
		{"speaker": "Veska Moor", "text": "Because the carts reached the center. The wounded got through. The commanders kept talking instead of starving."},
		{"speaker": "Pell", "text": "Exactly."},
		{"speaker": "Veska Moor", "text": "Then you've started learning the ugly version of knighthood."},
		{"speaker": "Pell", "text": "Ugly version?"},
		{"speaker": "Veska Moor", "text": "The real one. Less cheering. More carrying. Less glory. More staying where you're needed after everyone important has ridden elsewhere."},
		{"speaker": "Pell", "text": "...I think I understand that now. At least more than I did when we met."}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "She's proud of you.",
			"result": "success",
			"response": [
				{"speaker": "Veska Moor", "text": "...Yes. I am."},
				{"speaker": "Pell", "text": "Oh."},
				{"speaker": "Veska Moor", "text": "Don't make that face. You'll ruin it."},
				{"speaker": "Pell", "text": "Sorry. It's just— I think I've wanted to hear that for a while."},
				{"speaker": "Veska Moor", "text": "Then hear the rest too. You're still green. Still too eager. Still likely to say something embarrassing before breakfast."},
				{"speaker": "Pell", "text": "That sounds much more familiar."},
				{"speaker": "Veska Moor", "text": "Good. But when the line breaks now, I trust you to help build it again. That's worth more than praise."}
			]
		},
		{
			"text": "He's getting there.",
			"result": "fail",
			"response": [
				{"speaker": "Veska Moor", "text": "He is."},
				{"speaker": "Pell", "text": "That somehow sounds like both approval and a warning."},
				{"speaker": "Veska Moor", "text": "Because it is."},
				{"speaker": "Pell", "text": "...Honestly, I think I like your version better than flattery anyway."}
			]
		}
	]
},
"Sabine_Varr_Yselle_Maris_Rank1": {
	"req_level": 11,
	"script": [
		{"speaker": "Sabine Varr", "text": "Your troupe changed formation twice during the festival without any verbal signal."},
		{"speaker": "Yselle Maris", "text": "And you counted. Charming."},
		{"speaker": "Sabine Varr", "text": "I count everything in a crowd."},
		{"speaker": "Yselle Maris", "text": "As do I. Only my counting wears ribbons and yours carries a bow."},
		{"speaker": "Sabine Varr", "text": "You were moving civilians away from the stage before the first assassin revealed himself."},
		{"speaker": "Yselle Maris", "text": "Of course. A dancer who cannot read panic is merely decorative, and I've worked very hard not to be merely decorative."},
		{"speaker": "Sabine Varr", "text": "Hnh. Sensible."}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "You respect her.",
			"result": "success",
			"response": [
				{"speaker": "Sabine Varr", "text": "I respect competence. She has it."},
				{"speaker": "Yselle Maris", "text": "My, my. Straight to a lady's heart with that kind of poetry."},
				{"speaker": "Sabine Varr", "text": "Don't make me regret speaking."},
				{"speaker": "Yselle Maris", "text": "Too late. I intend to treasure this dry little moment forever."},
				{"speaker": "Sabine Varr", "text": "...Insufferable."}
			]
		},
		{
			"text": "You'd both know crowds.",
			"result": "fail",
			"response": [
				{"speaker": "Yselle Maris", "text": "True. We simply sell different forms of reassurance."},
				{"speaker": "Sabine Varr", "text": "Mine is less likely to involve sequins."},
				{"speaker": "Yselle Maris", "text": "And sadly poorer for it."},
				{"speaker": "Sabine Varr", "text": "Debatable."}
			]
		}
	]
},
"Sabine_Varr_Yselle_Maris_Rank2": {
	"req_level": 12,
	"script": [
		{"speaker": "Yselle Maris", "text": "You looked deeply offended by the College."},
		{"speaker": "Sabine Varr", "text": "I dislike institutions that call themselves neutral while hiding knives in the shelving."},
		{"speaker": "Yselle Maris", "text": "Understandable. I usually reserve that expression for theater critics."},
		{"speaker": "Sabine Varr", "text": "You joke, but your performers moved through that library like scouts."},
		{"speaker": "Yselle Maris", "text": "Every troupe learns how to pack up quickly when patronage turns hostile."},
		{"speaker": "Sabine Varr", "text": "That's not a sentence anyone should have to say casually."},
		{"speaker": "Yselle Maris", "text": "...No. But it is a useful education. One learns how beauty is treated when money becomes frightened."},
		{"speaker": "Sabine Varr", "text": "And what did you learn?"}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "Tell her plainly.",
			"result": "success",
			"response": [
				{"speaker": "Yselle Maris", "text": "That people call art frivolous right up until they need a crowd calmed, a rumor redirected, or a city reminded it still has a soul."},
				{"speaker": "Sabine Varr", "text": "...That's well said."},
				{"speaker": "Yselle Maris", "text": "Be still, my heart. Is this another compliment?"},
				{"speaker": "Sabine Varr", "text": "Don't celebrate. I'm still assessing you."},
				{"speaker": "Yselle Maris", "text": "Darling, if you keep assessing me like that, I may begin performing specifically for your approval."},
				{"speaker": "Sabine Varr", "text": "That sounds like a threat."}
			]
		},
		{
			"text": "She's half teasing.",
			"result": "fail",
			"response": [
				{"speaker": "Yselle Maris", "text": "Only half? How restrained of me."},
				{"speaker": "Sabine Varr", "text": "No. She's right enough to be irritating."},
				{"speaker": "Yselle Maris", "text": "Now that one I shall embroider on a pillow."},
				{"speaker": "Sabine Varr", "text": "I regret everything."}
			]
		}
	]
},
"Sabine_Varr_Yselle_Maris_Rank3": {
	"req_level": 17,
	"script": [
		{"speaker": "Sabine Varr", "text": "During the coalition camp, you spent more time with the ordinary soldiers than the delegates."},
		{"speaker": "Yselle Maris", "text": "Naturally. Delegates negotiate with words. Armies negotiate with mood."},
		{"speaker": "Sabine Varr", "text": "You were steadying morale before the talks even began."},
		{"speaker": "Yselle Maris", "text": "And you were placing archers where they could see every approach without seeming to threaten the tents. We both have our little social talents."},
		{"speaker": "Sabine Varr", "text": "Mine are less little."},
		{"speaker": "Yselle Maris", "text": "Mm. There's the woman I was hoping to find under all that discipline."},
		{"speaker": "Sabine Varr", "text": "Careful."},
		{"speaker": "Yselle Maris", "text": "No. Carefulness is for strangers. We've marched too far for that. So let me risk one honest observation: when you stand watch, Sabine, people breathe easier. I find that very difficult not to admire."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "Answer honestly.",
			"result": "success",
			"response": [
				{"speaker": "Sabine Varr", "text": "...And when you move through a frightened camp, people remember they're still human. I admire that too."},
				{"speaker": "Yselle Maris", "text": "There it is. Worth waiting half a war for."},
				{"speaker": "Sabine Varr", "text": "Don't become unbearable."},
				{"speaker": "Yselle Maris", "text": "Too late. I'm radiant with vindication."},
				{"speaker": "Sabine Varr", "text": "Gods preserve me."},
				{"speaker": "Yselle Maris", "text": "No, darling. That was your job. I merely noticed how well you did it."}
			]
		},
		{
			"text": "She means it.",
			"result": "fail",
			"response": [
				{"speaker": "Sabine Varr", "text": "I know she means it. That's the problem."},
				{"speaker": "Yselle Maris", "text": "Ah. So I do still unsettle you."},
				{"speaker": "Sabine Varr", "text": "You unsettle everyone. You just happen to do it elegantly."},
				{"speaker": "Yselle Maris", "text": "I will accept that as progress."}
			]
		}
	]
},
"BrotherAlden_Liora_Rank1": {
	"req_level": 9,
	"script": [
		{"speaker": "Brother Alden", "text": "You stood too straight in that mountain pass, Liora. People do that when they expect diplomacy to become a funeral."},
		{"speaker": "Liora", "text": "And you stood as if the cliffs themselves had confessed their sins to you. I thought that was simply your face."},
		{"speaker": "Brother Alden", "text": "Cruel. Fair, but cruel."},
		{"speaker": "Liora", "text": "I was frightened, Alden. Valeron envoys speak of peace the way surgeons speak of knives—very cleanly, and never to the ones being cut."},
		{"speaker": "Brother Alden", "text": "Aye. I noticed."},
		{"speaker": "Liora", "text": "Then answer me this: why did you stay with the faith after seeing what men like Ephrem made of it?"},
		{"speaker": "Brother Alden", "text": "Because abandoning mercy to zealots felt like handing wolves the shepherd's crook. Do you think me a fool for that?"}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "No, just stubborn.",
			"result": "success",
			"response": [
				{"speaker": "Liora", "text": "No. Not a fool. Merely stubborn in the most exhausting possible direction."},
				{"speaker": "Brother Alden", "text": "Good. I was hoping we'd agree on that much."},
				{"speaker": "Liora", "text": "I stayed for the same reason, I think. Not because Valeron deserved loyalty, but because the people beneath it still deserved comfort."},
				{"speaker": "Brother Alden", "text": "There. That's the root of it."},
				{"speaker": "Liora", "text": "Then perhaps we are both too devout to leave holiness to cowards."}
			]
		},
		{
			"text": "Faith should be simpler.",
			"result": "fail",
			"response": [
				{"speaker": "Brother Alden", "text": "It should. But simple things are often the first to be stolen by powerful hands."},
				{"speaker": "Liora", "text": "You make belief sound like a field one must keep reclaiming."},
				{"speaker": "Brother Alden", "text": "Sometimes it is. The work is ugly. The reason for it is not."},
				{"speaker": "Liora", "text": "...I will have to think on that."}
			]
		}
	]
},
"BrotherAlden_Liora_Rank2": {
	"req_level": 10,
	"script": [
		{"speaker": "Liora", "text": "During the Sunlit Trial, when the fire rings closed in, I nearly stepped into the arena."},
		{"speaker": "Brother Alden", "text": "I know. I was preparing to drag you back by the sleeves."},
		{"speaker": "Liora", "text": "You make that sound undignified."},
		{"speaker": "Brother Alden", "text": "It would have been. Which is one of the many reasons I was prepared to do it."},
		{"speaker": "Liora", "text": "I could not bear the sight of the faithful watching that cruelty and calling it purification."},
		{"speaker": "Brother Alden", "text": "Nor could I. But rage is easy in an arena. Endurance is harder."},
		{"speaker": "Liora", "text": "I am growing tired of endurance being the holiest thing left to us."},
		{"speaker": "Brother Alden", "text": "Then what would you rather faith become, Liora, if we live long enough to ask it properly?"}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "A refuge again.",
			"result": "success",
			"response": [
				{"speaker": "Liora", "text": "A refuge. Not a tribunal. Not a cage. A place where frightened people are made gentler, not smaller."},
				{"speaker": "Brother Alden", "text": "...A good answer."},
				{"speaker": "Liora", "text": "And you?"},
				{"speaker": "Brother Alden", "text": "Much the same. A faith that feeds before it judges. That listens before it instructs. That fears power in itself more than dissent in others."},
				{"speaker": "Liora", "text": "That almost sounds like hope."},
				{"speaker": "Brother Alden", "text": "Careful. We are both in danger of becoming sentimental."}
			]
		},
		{
			"text": "Something honest.",
			"result": "fail",
			"response": [
				{"speaker": "Liora", "text": "Something honest, at least."},
				{"speaker": "Brother Alden", "text": "Honesty is a start. Not a shelter."},
				{"speaker": "Liora", "text": "No. But perhaps the first stone of one."},
				{"speaker": "Brother Alden", "text": "Aye. Provided we build with more than anger."}
			]
		}
	]
},
"BrotherAlden_Liora_Rank3": {
	"req_level": 14,
	"script": [
		{"speaker": "Brother Alden", "text": "Dawnkeep shook more than those walls, didn't it?"},
		{"speaker": "Liora", "text": "You mean when Kaelen tore open the lie everyone had been kneeling around for years? Yes. I am still deciding whether I feel vindicated or merely exhausted."},
		{"speaker": "Brother Alden", "text": "Both is allowed."},
		{"speaker": "Liora", "text": "Is it? Because every time another secret breaks open, I feel less like a priestess and more like a woman carrying splinters from a fallen altar."},
		{"speaker": "Brother Alden", "text": "Then carry them. But do not mistake splinters for the whole of the sacred."},
		{"speaker": "Liora", "text": "You always say these things as though faith were a stubborn fire no one can quite smother."},
		{"speaker": "Brother Alden", "text": "Perhaps it is. Or perhaps I am only old enough to know that God survives our institutions more easily than they survive themselves."},
		{"speaker": "Liora", "text": "And if the Spire takes the Commander? If this war devours the last people who still make belief bearable?"},
		{"speaker": "Brother Alden", "text": "Then we grieve honestly, and still build. That is the vow. Not because loss is small, but because mercy without survivors is only memory."}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "Stay and build with me.",
			"result": "success",
			"response": [
				{"speaker": "Liora", "text": "...Then if we live, stay. Help me build whatever comes after this ruin."},
				{"speaker": "Brother Alden", "text": "I intend to. Someone has to remind you when your anger starts dressing itself as doctrine."},
				{"speaker": "Liora", "text": "And someone must remind you that patience can become cowardice if left unattended."},
				{"speaker": "Brother Alden", "text": "Good. Then we are properly matched for the labor ahead."},
				{"speaker": "Liora", "text": "No absolution. No easy hymns. Just work."},
				{"speaker": "Brother Alden", "text": "The truest liturgy I've heard all year."}
			]
		},
		{
			"text": "We may lose too much.",
			"result": "fail",
			"response": [
				{"speaker": "Liora", "text": "I am afraid there will be too little left to rebuild."},
				{"speaker": "Brother Alden", "text": "There may be. But little is not the same as nothing."},
				{"speaker": "Liora", "text": "You make survival sound like a sacrament."},
				{"speaker": "Brother Alden", "text": "Sometimes it is the only one war leaves intact."}
			]
		}
	]
},
"CorvinAsh_Sorrel_Rank1": {
	"req_level": 13,
	"script": [
		{"speaker": "Corvin Ash", "text": "You watched the sea during the Black Coast assault with the expression of someone trying to take notes on a nightmare."},
		{"speaker": "Sorrel", "text": "I was studying the interaction between tidal pressure and ritual conduits."},
		{"speaker": "Corvin Ash", "text": "Of course you were. I find it reassuring that terror has not interrupted your methodology."},
		{"speaker": "Sorrel", "text": "And I find it alarming that you sound reassured by anything involving the Obsidian Circle."},
		{"speaker": "Corvin Ash", "text": "Not reassured by them. By you. There is a difference."},
		{"speaker": "Sorrel", "text": "...That may be the least comforting compliment I have ever received."},
		{"speaker": "Corvin Ash", "text": "Accept it anyway. Tell me, scholar: when you looked at the fortress, did you see knowledge to preserve... or knowledge that ought never be repeated?"}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "Both, unfortunately.",
			"result": "success",
			"response": [
				{"speaker": "Sorrel", "text": "Both. That is the problem. To erase it entirely would be ignorance. To preserve it carelessly would be vanity."},
				{"speaker": "Corvin Ash", "text": "...Good. You do understand the shape of the danger."},
				{"speaker": "Sorrel", "text": "You sound relieved."},
				{"speaker": "Corvin Ash", "text": "I am. Brilliant people become much harder to tolerate once they stop fearing themselves."},
				{"speaker": "Sorrel", "text": "That was almost kind."}
			]
		},
		{
			"text": "Some things should die.",
			"result": "fail",
			"response": [
				{"speaker": "Corvin Ash", "text": "A tempting answer. Convenient, too."},
				{"speaker": "Sorrel", "text": "You disagree."},
				{"speaker": "Corvin Ash", "text": "I distrust forgetting more than I distrust horror. Horror at least announces itself. Oblivion lies politely."},
				{"speaker": "Sorrel", "text": "...I dislike how elegant that is."}
			]
		}
	]
},
"CorvinAsh_Sorrel_Rank2": {
	"req_level": 15,
	"script": [
		{"speaker": "Sorrel", "text": "The Weeping Marsh was intolerable."},
		{"speaker": "Corvin Ash", "text": "Because it was cruel, or because it was honest?"},
		{"speaker": "Sorrel", "text": "Must you always phrase things as if emotional injury were a seminar topic?"},
		{"speaker": "Corvin Ash", "text": "Only when the distinction matters. Enric's totems did not merely torment the dead. They harvested memory, curated grief, and weaponized witness. That is a very specific obscenity."},
		{"speaker": "Sorrel", "text": "...Yes."},
		{"speaker": "Corvin Ash", "text": "You are quieter than usual."},
		{"speaker": "Sorrel", "text": "I am thinking about how easily scholarship can become desecration once empathy is treated as inefficiency."},
		{"speaker": "Corvin Ash", "text": "Good. Keep that thought close. It is rarer than genius and more useful than brilliance."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "He's warning you.",
			"result": "success",
			"response": [
				{"speaker": "Sorrel", "text": "I know he is."},
				{"speaker": "Corvin Ash", "text": "And do you resent it?"},
				{"speaker": "Sorrel", "text": "No. I resent that I need it."},
				{"speaker": "Corvin Ash", "text": "Then you are less lost than most scholars ever become."},
				{"speaker": "Sorrel", "text": "...I cannot decide whether you are encouraging or horrifying."},
				{"speaker": "Corvin Ash", "text": "Must I choose?"}
			]
		},
		{
			"text": "You are not Enric.",
			"result": "fail",
			"response": [
				{"speaker": "Sorrel", "text": "I know I am not Enric."},
				{"speaker": "Corvin Ash", "text": "And yet the distance between curiosity and violation is smaller than bright minds prefer to admit."},
				{"speaker": "Sorrel", "text": "...Yes."},
				{"speaker": "Corvin Ash", "text": "Good. Agreement is an underrated form of safety."}
			]
		}
	]
},
"CorvinAsh_Sorrel_Rank3": {
	"req_level": 17,
	"script": [
		{"speaker": "Corvin Ash", "text": "You looked displeased by the coalition camp."},
		{"speaker": "Sorrel", "text": "Displeased? I was watching three governments politely calculate how much apocalypse they were willing to tolerate for leverage."},
		{"speaker": "Corvin Ash", "text": "Ah. Then displeased was too soft a word."},
		{"speaker": "Sorrel", "text": "And you? You moved through those tents as if you were taking their moral temperatures."},
		{"speaker": "Corvin Ash", "text": "I was. Most powerful people are most legible when they believe history is watching."},
		{"speaker": "Sorrel", "text": "That sounds like something you enjoy."},
		{"speaker": "Corvin Ash", "text": "No. But I have become skilled at looking directly at corruption without needing it to be theatrical first."},
		{"speaker": "Sorrel", "text": "I think I understand you better now. That may not comfort either of us."},
		{"speaker": "Corvin Ash", "text": "Probably not. So answer honestly, Sorrel: when all this ends, do you intend to become the kind of scholar who keeps dangerous truths from the world... or the kind who hands them over and hopes virtue catches up?"}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "Neither. I choose witness.",
			"result": "success",
			"response": [
				{"speaker": "Sorrel", "text": "Neither. I choose witness. Record clearly, share carefully, and refuse both cowardly secrecy and hungry display."},
				{"speaker": "Corvin Ash", "text": "...An ambitious answer."},
				{"speaker": "Sorrel", "text": "A necessary one."},
				{"speaker": "Corvin Ash", "text": "Yes. And difficult enough that I almost believe you will manage it."},
				{"speaker": "Sorrel", "text": "Almost?"},
				{"speaker": "Corvin Ash", "text": "Do not become spoiled, scholar. Full trust would ruin my mystique."},
				{"speaker": "Sorrel", "text": "...For what it is worth, I think your mystique is mostly posture."},
				{"speaker": "Corvin Ash", "text": "Cruel. Accurate, but cruel."}
			]
		},
		{
			"text": "Truth should be free.",
			"result": "fail",
			"response": [
				{"speaker": "Corvin Ash", "text": "Free things are usually paid for by someone unseen."},
				{"speaker": "Sorrel", "text": "...That is obnoxiously persuasive."},
				{"speaker": "Corvin Ash", "text": "I practice."},
				{"speaker": "Sorrel", "text": "Yes. I had noticed."},
				{"speaker": "Corvin Ash", "text": "Then notice this too: your conscience is better than your slogan. Keep listening to it."}
			]
		}
	]
},
"CorvinAsh_Tariq_Rank1": {
	"req_level": 13,
	"script": [
		{"speaker": "Tariq", "text": "You were awfully calm on the Black Coast for a man standing ankle-deep in ritual runoff and sea fog."},
		{"speaker": "Corvin Ash", "text": "You were awfully sarcastic for one dodging shadow-laced ballista fire."},
		{"speaker": "Tariq", "text": "It's an old survival reflex."},
		{"speaker": "Corvin Ash", "text": "As is composure."},
		{"speaker": "Tariq", "text": "Mm. I wondered. Most people either fear the dark openly or pretend not to. You simply look at it as if it owes you precision."},
		{"speaker": "Corvin Ash", "text": "And you look at dangerous knowledge as if it ought to at least be indexed properly before it kills anyone."},
		{"speaker": "Tariq", "text": "...I dislike how seen that makes me feel."},
		{"speaker": "Corvin Ash", "text": "Likewise."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "Then keep talking.",
			"result": "success",
			"response": [
				{"speaker": "Tariq", "text": "Gods, what a dreadful suggestion."},
				{"speaker": "Corvin Ash", "text": "And yet here you are, still standing beside me."},
				{"speaker": "Tariq", "text": "Only because intelligent company is so rare in this army."},
				{"speaker": "Corvin Ash", "text": "Ah. Mutual insult as respect. A classic foundation."},
				{"speaker": "Tariq", "text": "At last, someone with standards."}
			]
		},
		{
			"text": "You two are alike.",
			"result": "fail",
			"response": [
				{"speaker": "Tariq", "text": "Commander, what a deeply unpleasant thing to say aloud."},
				{"speaker": "Corvin Ash", "text": "No, let them continue. I am curious how far the blasphemy extends."},
				{"speaker": "Tariq", "text": "...See? This is exactly what I mean."},
				{"speaker": "Corvin Ash", "text": "And yet not inaccurate."}
			]
		}
	]
},
"CorvinAsh_Tariq_Rank2": {
	"req_level": 15,
	"script": [
		{"speaker": "Corvin Ash", "text": "The Marsh offended you."},
		{"speaker": "Tariq", "text": "Yes. Congratulations on noticing that the scholar was upset by memory being butchered into ammunition."},
		{"speaker": "Corvin Ash", "text": "Sarcasm noted. But my point is narrower: Enric disgusted you more as a technician than as a butcher."},
		{"speaker": "Tariq", "text": "...Because he was sloppy."},
		{"speaker": "Corvin Ash", "text": "Exactly."},
		{"speaker": "Tariq", "text": "Don't look so pleased. It's a vile thing to have in common."},
		{"speaker": "Corvin Ash", "text": "Not commonality. Distinction. Some people dabble in darkness because they enjoy the posture. Others study it because they understand the cost of getting it wrong."},
		{"speaker": "Tariq", "text": "And which of those do you think we are?"}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "The second, I think.",
			"result": "success",
			"response": [
				{"speaker": "Corvin Ash", "text": "I hope so. Otherwise this conversation becomes much less interesting."},
				{"speaker": "Tariq", "text": "That's almost charming in an appalling way."},
				{"speaker": "Corvin Ash", "text": "You say charming. I prefer exact."},
				{"speaker": "Tariq", "text": "There it is. The awful little difference that keeps me talking to you."},
				{"speaker": "Corvin Ash", "text": "...Likewise."}
			]
		},
		{
			"text": "You're still dangerous.",
			"result": "fail",
			"response": [
				{"speaker": "Tariq", "text": "Well, yes. That was never in doubt."},
				{"speaker": "Corvin Ash", "text": "Dangerous is not the same as lost."},
				{"speaker": "Tariq", "text": "Nor is it the same as safe. Important distinction."},
				{"speaker": "Corvin Ash", "text": "One I assume you are intelligent enough to keep making."}
			]
		}
	]
},
"CorvinAsh_Tariq_Rank3": {
	"req_level": 17,
	"script": [
		{"speaker": "Tariq", "text": "You looked almost entertained during the coalition talks."},
		{"speaker": "Corvin Ash", "text": "Not entertained. Merely unsurprised. There is a difference."},
		{"speaker": "Tariq", "text": "Ah yes. The scholar's favorite distinction: not amused, simply vindicated."},
		{"speaker": "Corvin Ash", "text": "And you? You spent the entire camp counting which leaders were frightened of the Spire and which were frightened of losing control of the response to it."},
		{"speaker": "Tariq", "text": "The second group was larger. Distressingly so."},
		{"speaker": "Corvin Ash", "text": "Power rarely minds apocalypse if it believes it can invoice afterward."},
		{"speaker": "Tariq", "text": "...That is one of the worst things you have ever said to me."},
		{"speaker": "Corvin Ash", "text": "One of the truest, too."},
		{"speaker": "Tariq", "text": "Perhaps. Which leaves us with an unpleasant question, Corvin. When this ends, what becomes of men like us—those who understand too much to be harmless and too little to pretend innocence?"}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "Make yourselves useful.",
			"result": "success",
			"response": [
				{"speaker": "Corvin Ash", "text": "We become useful on purpose, rather than incidentally."},
				{"speaker": "Tariq", "text": "That's alarmingly noble."},
				{"speaker": "Corvin Ash", "text": "Don't spread it around."},
				{"speaker": "Tariq", "text": "No, I think I shall. Very quietly. In footnotes."},
				{"speaker": "Corvin Ash", "text": "You are intolerable."},
				{"speaker": "Tariq", "text": "And you continue to answer me anyway. Curious."},
				{"speaker": "Corvin Ash", "text": "...Intelligent company remains rare."}
			]
		},
		{
			"text": "Stay watched, both.",
			"result": "fail",
			"response": [
				{"speaker": "Tariq", "text": "That may be the wisest answer, unfortunately."},
				{"speaker": "Corvin Ash", "text": "Agreed. The dangerous should be witnessed, especially by one another."},
				{"speaker": "Tariq", "text": "How grimly intimate."},
				{"speaker": "Corvin Ash", "text": "And yet not inaccurate."},
				{"speaker": "Tariq", "text": "...No. Not inaccurate at all."}
			]
		}
	]
},
"Avatar_SerHadrien_Rank1": {
	"req_level": 16,
	"script": [
		{"speaker": "Ser Hadrien", "text": "You carry the Veilbreaker like someone expecting it to accuse you."},
		{"speaker": "Commander", "text": "It came out of a vault built by people who believed my existence should end in sacrifice. I think a little suspicion is fair."},
		{"speaker": "Ser Hadrien", "text": "Fair, yes. But incomplete."},
		{"speaker": "Commander", "text": "You were one of them."},
		{"speaker": "Ser Hadrien", "text": "I was. Which is why I can tell you this plainly: the Order feared what the Mark could become, but it feared even more what the world would become if no bearer ever rose worthy of choosing."},
		{"speaker": "Commander", "text": "That sounds dangerously close to destiny."},
		{"speaker": "Ser Hadrien", "text": "No. Destiny is what institutions call it when they want obedience without guilt. I mean burden. The less flattering word."}
	],
	"branch_at": 6,
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
				{"speaker": "Ser Hadrien", "text": "Then you are still human. The Order should have treasured that more carefully than it did."}
			]
		},
		{
			"text": "Then the Order was wrong.",
			"result": "fail",
			"response": [
				{"speaker": "Ser Hadrien", "text": "Often. But not always in the same place."},
				{"speaker": "Commander", "text": "That sounds like a knight's answer."},
				{"speaker": "Ser Hadrien", "text": "It is a dead man's answer. More difficult to polish, sadly."},
				{"speaker": "Commander", "text": "...I still don't know whether to trust your ghosts."}
			]
		}
	]
},
"Avatar_SerHadrien_Rank2": {
	"req_level": 17,
	"script": [
		{"speaker": "Commander", "text": "You watched the coalition camp as if you'd seen this exact argument before."},
		{"speaker": "Ser Hadrien", "text": "Not this exact one. Only its ancestors."},
		{"speaker": "Commander", "text": "Kings bargaining. Priests hedging. Merchants smiling with their hands closed."},
		{"speaker": "Ser Hadrien", "text": "Aurelia has always known how to decorate its fear."},
		{"speaker": "Commander", "text": "And yet you still believed something worth saving survived long enough to build the Order."},
		{"speaker": "Ser Hadrien", "text": "Yes."},
		{"speaker": "Commander", "text": "Why?"},
		{"speaker": "Ser Hadrien", "text": "Because once, on a field very much like this one, I saw soldiers share their water before their banners. That was enough to ruin my cynicism permanently."},
		{"speaker": "Commander", "text": "...You put a great deal of faith in very small mercies."}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "Maybe that's enough.",
			"result": "success",
			"response": [
				{"speaker": "Ser Hadrien", "text": "It often must be."},
				{"speaker": "Commander", "text": "I keep waiting for the world to justify the scale of what it asks from us."},
				{"speaker": "Ser Hadrien", "text": "It will not. That is why we justify one another instead."},
				{"speaker": "Commander", "text": "...That is either beautiful or devastating."},
				{"speaker": "Ser Hadrien", "text": "Usually both. The older truths tend to be."},
				{"speaker": "Commander", "text": "Then perhaps I understand the Order a little better than I did yesterday."}
			]
		},
		{
			"text": "Mercy feels too small.",
			"result": "fail",
			"response": [
				{"speaker": "Commander", "text": "Small mercies feel thin beside the Spire."},
				{"speaker": "Ser Hadrien", "text": "Yes. But thin things still bind wounds."},
				{"speaker": "Commander", "text": "You really were a knight."},
				{"speaker": "Ser Hadrien", "text": "Unfortunately. We specialized in saying unbearable things with sincerity."}
			]
		}
	]
},
"Avatar_SerHadrien_Rank3": {
	"req_level": 18,
	"script": [
		{"speaker": "Ser Hadrien", "text": "The Spire is already changing the sky. I can feel the old breach stirring in it."},
		{"speaker": "Commander", "text": "Everyone keeps speaking to me like I'm halfway gone already."},
		{"speaker": "Ser Hadrien", "text": "Because everyone fears you are. Not because they see less of you, but because they cannot bear the thought of seeing less tomorrow."},
		{"speaker": "Commander", "text": "And you?"},
		{"speaker": "Ser Hadrien", "text": "I have stood beside men asked to die for causes too large to love them back. I would not insult you by pretending not to recognize the look."},
		{"speaker": "Commander", "text": "Then tell me honestly, Hadrien. Am I a person to you... or the final shape of your Order's unfinished prayer?"},
		{"speaker": "Ser Hadrien", "text": "...At first, perhaps the second. The dead are not immune to longing."},
		{"speaker": "Ser Hadrien", "text": "Now? Now you are the Commander who kept choosing people when symbols would have been easier. That is not prayer. That is character."},
		{"speaker": "Commander", "text": "You make it sound like that still matters."}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "It matters most.",
			"result": "success",
			"response": [
				{"speaker": "Ser Hadrien", "text": "It matters most."},
				{"speaker": "Commander", "text": "...Even if the choice at the end is ugly?"},
				{"speaker": "Ser Hadrien", "text": "Especially then. Any fool can look noble in a hymn. Character is what remains when the hymn has burned away."},
				{"speaker": "Commander", "text": "I think I needed to hear that from someone who remembers the first breach."},
				{"speaker": "Ser Hadrien", "text": "Then hear one thing more: whatever happens atop that Spire, the dead will not own your name. You do."},
				{"speaker": "Commander", "text": "...Thank you, Hadrien."},
				{"speaker": "Ser Hadrien", "text": "Go earn the thanks later. I would much prefer to give them to a survivor."}
			]
		},
		{
			"text": "Maybe nothing matters.",
			"result": "fail",
			"response": [
				{"speaker": "Ser Hadrien", "text": "No. That is the abyss talking, not you."},
				{"speaker": "Commander", "text": "How can you tell the difference?"},
				{"speaker": "Ser Hadrien", "text": "Because despair always claims to be clarity. Real clarity is quieter."},
				{"speaker": "Commander", "text": "...I will try to remember that."},
				{"speaker": "Ser Hadrien", "text": "Do. It may be the last kindness you owe yourself before dawn."}
			]
		}
	]
},
"CorvinAsh_SerHadrien_Rank1": {
	"req_level": 16,
	"script": [
		{"speaker": "Corvin Ash", "text": "You endure animation with more dignity than most living knights endure breakfast."},
		{"speaker": "Ser Hadrien", "text": "And you speak to revenants with more curiosity than is likely healthy."},
		{"speaker": "Corvin Ash", "text": "Healthy is such a provincial standard."},
		{"speaker": "Ser Hadrien", "text": "So I have observed."},
		{"speaker": "Corvin Ash", "text": "You resent being studied."},
		{"speaker": "Ser Hadrien", "text": "No. I resent being reduced. There is a distinction scholars and warlocks alike rarely keep long."},
		{"speaker": "Corvin Ash", "text": "...Fair. Then let me amend the question. What does it feel like to outlive your century and still be asked to serve it?"}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "Let him answer fully.",
			"result": "success",
			"response": [
				{"speaker": "Ser Hadrien", "text": "Like being mistaken for an answer when one is in fact only evidence."},
				{"speaker": "Corvin Ash", "text": "That is an excellent sentence."},
				{"speaker": "Ser Hadrien", "text": "It is also an unpleasant life."},
				{"speaker": "Corvin Ash", "text": "The two are rarely strangers."},
				{"speaker": "Ser Hadrien", "text": "...You are more honest than most men who traffic in forbidden things."}
			]
		},
		{
			"text": "Don't prod him.",
			"result": "fail",
			"response": [
				{"speaker": "Corvin Ash", "text": "Commander, the dead are sturdier than the living. Usually."},
				{"speaker": "Ser Hadrien", "text": "Do not worry. I have survived ruder forms of scholarship."},
				{"speaker": "Corvin Ash", "text": "High praise indeed."},
				{"speaker": "Ser Hadrien", "text": "Do not grow ambitious."}
			]
		}
	]
},
"CorvinAsh_SerHadrien_Rank2": {
	"req_level": 17,
	"script": [
		{"speaker": "Ser Hadrien", "text": "You moved through the coalition camp like a man taking measurements for a crypt."},
		{"speaker": "Corvin Ash", "text": "How flattering. I thought I looked more diplomatic than that."},
		{"speaker": "Ser Hadrien", "text": "You did not."},
		{"speaker": "Corvin Ash", "text": "Good. Diplomacy makes me itch."},
		{"speaker": "Ser Hadrien", "text": "And yet you listened more carefully than the envoys did."},
		{"speaker": "Corvin Ash", "text": "Because they were listening for advantage. I was listening for appetite."},
		{"speaker": "Ser Hadrien", "text": "You assume power always hungers."},
		{"speaker": "Corvin Ash", "text": "No. I merely distrust any power that claims it does not."},
		{"speaker": "Ser Hadrien", "text": "...You would have hated the Order."}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "Would he have?",
			"result": "success",
			"response": [
				{"speaker": "Corvin Ash", "text": "At first? Probably."},
				{"speaker": "Corvin Ash", "text": "Any institution that wraps sacrifice in noble language invites my suspicion."},
				{"speaker": "Ser Hadrien", "text": "Fair."},
				{"speaker": "Corvin Ash", "text": "But I suspect I would have admired the parts of it that knew the abyss by name and feared it anyway."},
				{"speaker": "Ser Hadrien", "text": "...Then perhaps you would have hated us properly. A rare courtesy."},
				{"speaker": "Corvin Ash", "text": "I do my best to be precise in all things."}
			]
		},
		{
			"text": "The Order meant well.",
			"result": "fail",
			"response": [
				{"speaker": "Corvin Ash", "text": "So do scalpels. That does not make every cut merciful."},
				{"speaker": "Ser Hadrien", "text": "No. But intention is not nothing."},
				{"speaker": "Corvin Ash", "text": "Agreed. It is simply less than institutions insist."},
				{"speaker": "Ser Hadrien", "text": "...A verdict I cannot wholly contest."}
			]
		}
	]
},
"CorvinAsh_SerHadrien_Rank3": {
	"req_level": 18,
	"script": [
		{"speaker": "Corvin Ash", "text": "The Spire is almost beautiful from a distance."},
		{"speaker": "Ser Hadrien", "text": "So are many fatal things."},
		{"speaker": "Corvin Ash", "text": "Mm. You understand me better than most."},
		{"speaker": "Ser Hadrien", "text": "I understand the danger of reverence without discipline."},
		{"speaker": "Corvin Ash", "text": "And yet you still speak to me."},
		{"speaker": "Ser Hadrien", "text": "Because men who understand darkness honestly are rarer than men who fear it loudly."},
		{"speaker": "Corvin Ash", "text": "...That may be the nearest thing to respect I have heard from a dead knight."},
		{"speaker": "Ser Hadrien", "text": "Do not become spoiled."},
		{"speaker": "Corvin Ash", "text": "Perish the thought. One final question, then. When all this ends, what becomes of a man who has already outlived the age that made him?"},
		{"speaker": "Ser Hadrien", "text": "If he is fortunate? A warning. If he is wiser still, a witness."}
	],
	"branch_at": 9,
	"choices": [
		{
			"text": "And you are both.",
			"result": "success",
			"response": [
				{"speaker": "Ser Hadrien", "text": "Perhaps."},
				{"speaker": "Corvin Ash", "text": "You know, for someone composed almost entirely of memory and regret, you are remarkably disciplined company."},
				{"speaker": "Ser Hadrien", "text": "And you, for a man fascinated by ruin, are less eager to become it than I expected."},
				{"speaker": "Corvin Ash", "text": "...A meaningful compliment from either of us is starting to feel like a breach of etiquette."},
				{"speaker": "Ser Hadrien", "text": "Then let us commit one more before the Spire. Whatever you study after this, Corvin Ash, do not let your mind become a temple to the abyss."},
				{"speaker": "Corvin Ash", "text": "...No. I think I would rather remain its witness."}
			]
		},
		{
			"text": "Some warnings go unheard.",
			"result": "fail",
			"response": [
				{"speaker": "Ser Hadrien", "text": "Most do."},
				{"speaker": "Corvin Ash", "text": "Cheerful."},
				{"speaker": "Ser Hadrien", "text": "Accurate."},
				{"speaker": "Corvin Ash", "text": "...Yes. Unfortunately, that is what makes it worth saying anyway."},
				{"speaker": "Ser Hadrien", "text": "Good. Then perhaps you are not lost after all."}
			]
		}
	]
},
"Kaelen_Tariq_Rank1": {
	"req_level": 12,
	"script": [
		{"speaker": "Tariq", "text": "You looked deeply unhappy in the College."},
		{"speaker": "Kaelen", "text": "I was in a building full of scholars, old lies, and my own unfinished mistakes. Hard place to grin."},
		{"speaker": "Tariq", "text": "I had assumed your people preferred old lies hidden in vaults, not shelved neatly with index tabs."},
		{"speaker": "Kaelen", "text": "My people preferred catastrophe delayed. Different vice."},
		{"speaker": "Tariq", "text": "Mm. A better slogan than a defense."},
		{"speaker": "Kaelen", "text": "Didn't say it was a defense."},
		{"speaker": "Tariq", "text": "Then let me ask the rude version, since no one else in this camp seems willing: how much of the Commander's life was shaped by your secrets before they ever knew your name?"}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "Answer him plainly.",
			"result": "success",
			"response": [
				{"speaker": "Kaelen", "text": "...Too much."},
				{"speaker": "Tariq", "text": "There. Honesty survives after all."},
				{"speaker": "Kaelen", "text": "Don't sound so pleased. It doesn't make me cleaner."},
				{"speaker": "Tariq", "text": "No. It makes you tolerable."},
				{"speaker": "Kaelen", "text": "From you, scholar, that may be the warmest blessing I'll get this year."}
			]
		},
		{
			"text": "He did what he had to.",
			"result": "fail",
			"response": [
				{"speaker": "Tariq", "text": "Ah, the old anthem of necessary men. Always a hit with institutions."},
				{"speaker": "Kaelen", "text": "Careful. You'll make me sound more noble than I was."},
				{"speaker": "Tariq", "text": "Perish the thought. I'm aiming for accurate, not flattering."},
				{"speaker": "Kaelen", "text": "...Then keep aiming. Accuracy I can live with."}
			]
		}
	]
},
"Kaelen_Tariq_Rank2": {
	"req_level": 14,
	"script": [
		{"speaker": "Kaelen", "text": "You watched me hard at Dawnkeep."},
		{"speaker": "Tariq", "text": "Naturally. The old veteran with a relic, a fortress full of soldiers, and a confession large enough to split a campaign deserves attention."},
		{"speaker": "Kaelen", "text": "You say the sweetest things."},
		{"speaker": "Tariq", "text": "Only to people who've earned them."},
		{"speaker": "Kaelen", "text": "So what's the verdict?"},
		{"speaker": "Tariq", "text": "That you're exactly what I feared. And slightly better than I expected."},
		{"speaker": "Kaelen", "text": "...That's not bad."},
		{"speaker": "Tariq", "text": "No. It isn't. Which is infuriating."},
		{"speaker": "Kaelen", "text": "Go on, then. Finish the insult."},
		{"speaker": "Tariq", "text": "You manipulated history, buried truth, and steered a marked soul into catastrophe. Yet when the keep broke, you still looked more ashamed of the lives touched than proud of the plan preserved. That complicates hating you cleanly."}
	],
	"branch_at": 9,
	"choices": [
		{
			"text": "Complication suits him.",
			"result": "success",
			"response": [
				{"speaker": "Kaelen", "text": "Aye. That's me all over. Hard to file and worse to trust."},
				{"speaker": "Tariq", "text": "And yet here we remain."},
				{"speaker": "Kaelen", "text": "You stayed because I'm useful."},
				{"speaker": "Tariq", "text": "At first. Now I stay because you are one of the few men here who understands that strategy without remorse is just elegant butchery."},
				{"speaker": "Kaelen", "text": "...Careful, Tariq. I might start thinking you respect me."},
				{"speaker": "Tariq", "text": "Do not ruin this with optimism."}
			]
		},
		{
			"text": "You still distrust him.",
			"result": "fail",
			"response": [
				{"speaker": "Tariq", "text": "Of course I distrust him."},
				{"speaker": "Kaelen", "text": "Good. Means you're paying attention."},
				{"speaker": "Tariq", "text": "And there it is. The most irritating part of all—your worst qualities often arrive carrying useful advice."},
				{"speaker": "Kaelen", "text": "I've had years to practice."}
			]
		}
	]
},
"Kaelen_Tariq_Rank3": {
	"req_level": 17,
	"script": [
		{"speaker": "Tariq", "text": "The coalition camp was almost funny."},
		{"speaker": "Kaelen", "text": "Almost."},
		{"speaker": "Tariq", "text": "A theocracy, a merchant power, and a wounded monarchy all discussing apocalypse as if it were a border dispute with unfortunate weather."},
		{"speaker": "Kaelen", "text": "You've got a gift for making politics sound as ugly as it is."},
		{"speaker": "Tariq", "text": "No, I merely remove the silk wrapping."},
		{"speaker": "Kaelen", "text": "And? What'd you make of the Commander in all that noise?"},
		{"speaker": "Tariq", "text": "That they were the only person in the camp still speaking as if ordinary lives existed beyond leverage."},
		{"speaker": "Kaelen", "text": "...Aye."},
		{"speaker": "Tariq", "text": "Which raises a final question. When the Spire is done, what exactly do you think you've prepared them to become? A savior? A seal? A ruler? Or merely someone strong enough to survive what your generation could not?"}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "The last one, I hope.",
			"result": "success",
			"response": [
				{"speaker": "Kaelen", "text": "The last one. If I've done anything right, it's that."},
				{"speaker": "Tariq", "text": "...Good."},
				{"speaker": "Kaelen", "text": "You sound relieved."},
				{"speaker": "Tariq", "text": "I am. Aurelia has had enough symbols. It could stand to keep one good commander."},
				{"speaker": "Kaelen", "text": "For a man who sells his warmth in splinters, that was near sentimental."},
				{"speaker": "Tariq", "text": "Say that again and I'll deny it to the grave."},
				{"speaker": "Kaelen", "text": "Fair enough. But for what it's worth, scholar... if I don't walk back from the Spire, keep needling them. The Commander will need honest irritation nearby."},
				{"speaker": "Tariq", "text": "...That, at least, I can promise."}
			]
		},
		{
			"text": "He doesn't know yet.",
			"result": "fail",
			"response": [
				{"speaker": "Kaelen", "text": "No. I don't."},
				{"speaker": "Tariq", "text": "An unexpectedly responsible answer."},
				{"speaker": "Kaelen", "text": "Don't sound so shocked. Age has done some work on me."},
				{"speaker": "Tariq", "text": "Yes. Mostly damage, but not exclusively."},
				{"speaker": "Kaelen", "text": "...I'll take that as fondness and die confused."}
			]
		}
	]
},
"Celia_SisterMeris_Rank1": {
	"req_level": 11,
	"script": [
		{"speaker": "Sister Meris", "text": "You kept your mount away from the central stage during the festival."},
		{"speaker": "Celia", "text": "Low banners, crowded lanes, too many blind corners. A pegasus is graceful until a city tries to strangle it."},
		{"speaker": "Sister Meris", "text": "Practical. I expected something sharper."},
		{"speaker": "Celia", "text": "You mean resentment?"},
		{"speaker": "Sister Meris", "text": "...Yes."},
		{"speaker": "Celia", "text": "I have that too. I am merely disciplined enough not to waste it in public."},
		{"speaker": "Sister Meris", "text": "Then allow me to be direct. There was a time I would have commended a woman like you for obedience. I now suspect that was simply cowardice dressed as doctrine."}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "Let her continue.",
			"result": "success",
			"response": [
				{"speaker": "Celia", "text": "...Go on."},
				{"speaker": "Sister Meris", "text": "I mistook compliance for virtue because it made institutions easier to manage."},
				{"speaker": "Celia", "text": "And women easier to sacrifice."},
				{"speaker": "Sister Meris", "text": "...Yes."},
				{"speaker": "Celia", "text": "Good. If we are to speak at all, let it at least be in clean wounds rather than polished lies."}
			]
		},
		{
			"text": "That was the system.",
			"result": "fail",
			"response": [
				{"speaker": "Celia", "text": "No. Do not hide inside the word 'system.' Systems do not hold pens or sign orders."},
				{"speaker": "Sister Meris", "text": "...A deserved correction."},
				{"speaker": "Celia", "text": "Then accept it as one."},
				{"speaker": "Sister Meris", "text": "I do."}
			]
		}
	]
},
"Celia_SisterMeris_Rank2": {
	"req_level": 12,
	"script": [
		{"speaker": "Celia", "text": "The College unsettled you."},
		{"speaker": "Sister Meris", "text": "Archives often do. Shelves are where institutions keep the parts of themselves they hope no one reads closely."},
		{"speaker": "Celia", "text": "And yet you walked those halls like a woman already preparing her own indictment."},
		{"speaker": "Sister Meris", "text": "That is because I was."},
		{"speaker": "Celia", "text": "When the Codex page confirmed the Mark's true purpose, what did you feel first?"},
		{"speaker": "Sister Meris", "text": "Shame."},
		{"speaker": "Celia", "text": "Only shame? Not relief that the Church's oldest lie had finally cracked?"},
		{"speaker": "Sister Meris", "text": "Relief is for the innocent. I had no right to it."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "That's not enough.",
			"result": "success",
			"response": [
				{"speaker": "Celia", "text": "No. Shame is not enough."},
				{"speaker": "Sister Meris", "text": "...I know."},
				{"speaker": "Celia", "text": "Good. Because if you stop at guilt, all you have done is center yourself in a wound you helped deepen."},
				{"speaker": "Sister Meris", "text": "You strike cleanly."},
				{"speaker": "Celia", "text": "I was trained to. I am simply applying the discipline elsewhere now."},
				{"speaker": "Sister Meris", "text": "...Then keep doing so. I deserve sharper company than comfort."}
			]
		},
		{
			"text": "Shame matters too.",
			"result": "fail",
			"response": [
				{"speaker": "Sister Meris", "text": "It does. But Celia is right to despise it as a resting place."},
				{"speaker": "Celia", "text": "I do not despise it. I despise people who kneel prettily inside it and call that transformation."},
				{"speaker": "Sister Meris", "text": "...Then I will try not to become one of them."},
				{"speaker": "Celia", "text": "Try harder than that."}
			]
		}
	]
},
"Celia_SisterMeris_Rank3": {
	"req_level": 17,
	"script": [
		{"speaker": "Sister Meris", "text": "You spoke to the Valeron officers today as if you feared neither their rank nor their judgment."},
		{"speaker": "Celia", "text": "I have lived under both. Familiarity breeds efficiency."},
		{"speaker": "Sister Meris", "text": "You would have made an extraordinary commander inside the old Church."},
		{"speaker": "Celia", "text": "That is not a compliment."},
		{"speaker": "Sister Meris", "text": "No. It is an indictment of what the old Church valued."},
		{"speaker": "Celia", "text": "...Good. Then perhaps we are finally speaking the same language."},
		{"speaker": "Sister Meris", "text": "Perhaps. Which leaves me one question before the Spire swallows our chance. If anything of Valeron remains afterward, what would you demand of it first?"},
		{"speaker": "Celia", "text": "That it stop confusing obedience with holiness. That it cease feeding frightened girls to institutions and calling the result discipline."},
		{"speaker": "Sister Meris", "text": "...Then hear my answer in return. If I live, I will spend whatever remains of me making certain women like you never again have to earn permission to belong to themselves."}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "Hold her to it.",
			"result": "success",
			"response": [
				{"speaker": "Celia", "text": "Good. Because I intend to hold you to that with appalling rigor."},
				{"speaker": "Sister Meris", "text": "I expected no less."},
				{"speaker": "Celia", "text": "This is not forgiveness, Meris."},
				{"speaker": "Sister Meris", "text": "No. It is work."},
				{"speaker": "Celia", "text": "...Then work beside me, if the world permits it. The Church has had enough wardens. It may finally need women willing to say 'no' in the right places."},
				{"speaker": "Sister Meris", "text": "A severe invitation."},
				{"speaker": "Celia", "text": "The only kind worth making."}
			]
		},
		{
			"text": "Words are easy.",
			"result": "fail",
			"response": [
				{"speaker": "Celia", "text": "Words are easy."},
				{"speaker": "Sister Meris", "text": "Yes. Which is why I will measure myself by labor, not speeches."},
				{"speaker": "Celia", "text": "See that you do."},
				{"speaker": "Sister Meris", "text": "You have my intention."},
				{"speaker": "Celia", "text": "After the Spire, intention will no longer be enough for any of us."}
			]
		}
	]
},
"Darian_YselleMaris_Rank1": {
	"req_level": 11,
	"script": [
		{"speaker": "Yselle Maris", "text": "You smiled through the entire festival panic like a man auditioning for his own assassination."},
		{"speaker": "Darian", "text": "And you danced through it like elegance itself had decided panic was beneath good posture."},
		{"speaker": "Yselle Maris", "text": "Flattery in the middle of a corpse count. Bold."},
		{"speaker": "Darian", "text": "Professional courtesy. I recognize a fellow survivor of cultivated rooms."},
		{"speaker": "Yselle Maris", "text": "Ah. So that's what this is. Not flirtation—taxonomy."},
		{"speaker": "Darian", "text": "Please. It can be both."},
		{"speaker": "Yselle Maris", "text": "...Dangerous answer. I approve."}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "You're both performing.",
			"result": "success",
			"response": [
				{"speaker": "Darian", "text": "Naturally. One should never waste a live audience."},
				{"speaker": "Yselle Maris", "text": "And one should never trust a room until one has made it look where one wishes."},
				{"speaker": "Darian", "text": "Gods, that's attractive."},
				{"speaker": "Yselle Maris", "text": "Careful, lordling. Compliment me like that and I may begin charging consultation fees."},
				{"speaker": "Darian", "text": "Worth every coin."}
			]
		},
		{
			"text": "Try sincerity instead.",
			"result": "fail",
			"response": [
				{"speaker": "Yselle Maris", "text": "Commander, what a cruel thing to request in public."},
				{"speaker": "Darian", "text": "Quite. We have reputations to maintain."},
				{"speaker": "Yselle Maris", "text": "And masks to keep artfully misaligned."},
				{"speaker": "Darian", "text": "...See? She understands me perfectly."}
			]
		}
	]
},
"Darian_YselleMaris_Rank2": {
	"req_level": 12,
	"script": [
		{"speaker": "Darian", "text": "You moved through the College like a woman casing a theater rather than a library."},
		{"speaker": "Yselle Maris", "text": "My dear Darian, libraries and theaters are cousins. Both depend on timing, audience management, and a desperate hope that the people in charge know what they're doing."},
		{"speaker": "Darian", "text": "And when they do not?"},
		{"speaker": "Yselle Maris", "text": "Then the performers learn to survive around them."},
		{"speaker": "Darian", "text": "...There it is. The real answer under the velvet."},
		{"speaker": "Yselle Maris", "text": "Please. Velvet is expensive. Mine is mostly illusion and good posture."},
		{"speaker": "Darian", "text": "You joke, but I know that craft. Looking expensive is often cheaper than being safe."},
		{"speaker": "Yselle Maris", "text": "...Mm. You do understand after all."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "Talk plainly now.",
			"result": "success",
			"response": [
				{"speaker": "Darian", "text": "I was raised among people who mistook polish for virtue. I know exactly how useful appearance becomes when substance is denied."},
				{"speaker": "Yselle Maris", "text": "And yet here you are, trying to grow one beneath the other."},
				{"speaker": "Darian", "text": "A vulgar hobby, I know."},
				{"speaker": "Yselle Maris", "text": "No. Merely difficult."},
				{"speaker": "Darian", "text": "You make that sound almost tender."},
				{"speaker": "Yselle Maris", "text": "Do not become greedy, darling. I have a mystique to preserve."}
			]
		},
		{
			"text": "You both know masks.",
			"result": "fail",
			"response": [
				{"speaker": "Yselle Maris", "text": "Too well, perhaps."},
				{"speaker": "Darian", "text": "Speak for yourself. Mine are curated with noble precision."},
				{"speaker": "Yselle Maris", "text": "And crack under pressure with charming regularity."},
				{"speaker": "Darian", "text": "...I walked directly into that one."}
			]
		}
	]
},
"Darian_YselleMaris_Rank3": {
	"req_level": 17,
	"script": [
		{"speaker": "Yselle Maris", "text": "You were almost respectable in the coalition camp."},
		{"speaker": "Darian", "text": "Almost? I am wounded."},
		{"speaker": "Yselle Maris", "text": "Don't be. Respectable is terribly overrated. But you did speak to the League envoys like a man who'd finally learned the difference between breeding and backbone."},
		{"speaker": "Darian", "text": "...That is either the finest compliment I've had this year or the most elegant insult."},
		{"speaker": "Yselle Maris", "text": "Why choose?"},
		{"speaker": "Darian", "text": "Because we are approaching the Spire, and all our cleverness is beginning to feel suspiciously mortal."},
		{"speaker": "Yselle Maris", "text": "...There you are. I was wondering if you'd show me the man beneath the embroidery before the world ended."},
		{"speaker": "Darian", "text": "Dangerous request. He is less polished than the rest."},
		{"speaker": "Yselle Maris", "text": "Good. I've had enough polish for one lifetime. Tell me something true, then. When this is over, what do you want if no one is watching?"}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "Give her truth.",
			"result": "success",
			"response": [
				{"speaker": "Darian", "text": "...A room where I don't have to be amusing to be welcome. Music without an audience. Company sharp enough to mock me honestly and stay anyway."},
				{"speaker": "Yselle Maris", "text": "...Oh."},
				{"speaker": "Darian", "text": "Was that too sincere?"},
				{"speaker": "Yselle Maris", "text": "Appallingly so. I hate how much I liked it."},
				{"speaker": "Darian", "text": "Then for what it's worth, I suspect you'd suit the room rather well."},
				{"speaker": "Yselle Maris", "text": "Careful, darling. Keep speaking like that and I may arrive with wine, impossible standards, and no intention of leaving."},
				{"speaker": "Darian", "text": "Then I shall endeavor to survive the Spire with the furniture arranged accordingly."}
			]
		},
		{
			"text": "Keep the wit up.",
			"result": "fail",
			"response": [
				{"speaker": "Darian", "text": "I want silk cushions, obedient servants, and admirers too blind to notice my flaws."},
				{"speaker": "Yselle Maris", "text": "...Coward."},
				{"speaker": "Darian", "text": "Yes. A little."},
				{"speaker": "Yselle Maris", "text": "Pity. I had hoped for better than a joke."},
				{"speaker": "Darian", "text": "...Then perhaps ask me again if we live."}
			]
		}
	]
},
"Inez_MaelaThorn_Rank1": {
	"req_level": 13,
	"script": [
		{"speaker": "Maela Thorn", "text": "You know, most people say 'thank you' after someone scouts a cliffside fort in a storm."},
		{"speaker": "Inez", "text": "Most people do not circle a coastal stronghold three times because they enjoy showing off against ballista fire."},
		{"speaker": "Maela Thorn", "text": "Ah. So you were watching."},
		{"speaker": "Inez", "text": "Hard not to. You flew like a dare with feathers."},
		{"speaker": "Maela Thorn", "text": "That is the nicest thing anyone's said to me all week."},
		{"speaker": "Inez", "text": "It was not praise. It was a risk assessment."},
		{"speaker": "Maela Thorn", "text": "Mm. And what was the verdict, then? Brilliant or reckless?"}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "Probably both.",
			"result": "success",
			"response": [
				{"speaker": "Inez", "text": "Both."},
				{"speaker": "Maela Thorn", "text": "See? We understand each other already."},
				{"speaker": "Inez", "text": "No. We do not."},
				{"speaker": "Maela Thorn", "text": "Not yet. But you noticed the route I opened for the landing teams. That means you're at least speaking my dialect."},
				{"speaker": "Inez", "text": "...Keep flying usefully and I may learn a little more of it."}
			]
		},
		{
			"text": "Mostly reckless.",
			"result": "fail",
			"response": [
				{"speaker": "Maela Thorn", "text": "Commander, your cruelty is underappreciated."},
				{"speaker": "Inez", "text": "No. It's accurate."},
				{"speaker": "Maela Thorn", "text": "You are both impossible."},
				{"speaker": "Inez", "text": "And yet still alive. Try imitating that part."}
			]
		}
	]
},
"Inez_MaelaThorn_Rank2": {
	"req_level": 14,
	"script": [
		{"speaker": "Inez", "text": "You nearly broke formation at Dawnkeep when the west tower fell."},
		{"speaker": "Maela Thorn", "text": "I saw the collapse before the signal came. If I'd dived sooner, I could've harried the flank faster."},
		{"speaker": "Inez", "text": "Or died where no one could reach you."},
		{"speaker": "Maela Thorn", "text": "That's the problem with groundfolk. You always think in falling."},
		{"speaker": "Inez", "text": "No. I think in return paths."},
		{"speaker": "Maela Thorn", "text": "...Hnh."},
		{"speaker": "Inez", "text": "A scout's first duty is not getting somewhere dramatic. It's bringing the knowledge back alive."},
		{"speaker": "Maela Thorn", "text": "You say that like you've buried enough fools to get tired of admiring them."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "Listen to her.",
			"result": "success",
			"response": [
				{"speaker": "Maela Thorn", "text": "...All right. That's fair."},
				{"speaker": "Inez", "text": "Good."},
				{"speaker": "Maela Thorn", "text": "Don't sound so smug. I still think your way is slower."},
				{"speaker": "Inez", "text": "Slower is fine. Dead is slower."},
				{"speaker": "Maela Thorn", "text": "...Gods, I hate how good that line is."},
				{"speaker": "Inez", "text": "Then remember it."}
			]
		},
		{
			"text": "Speed matters too.",
			"result": "fail",
			"response": [
				{"speaker": "Inez", "text": "Yes. After judgment."},
				{"speaker": "Maela Thorn", "text": "See? That's where we differ. I trust my instincts."},
				{"speaker": "Inez", "text": "Then sharpen them until they stop mistaking momentum for wisdom."},
				{"speaker": "Maela Thorn", "text": "...You really don't waste any arrows in conversation, do you?"}
			]
		}
	]
},
"Inez_MaelaThorn_Rank3": {
	"req_level": 17,
	"script": [
		{"speaker": "Maela Thorn", "text": "You know what I hate most about the coalition camp?"},
		{"speaker": "Inez", "text": "That no one lets you land on the command tents?"},
		{"speaker": "Maela Thorn", "text": "...All right, second-most. First is how every faction talks about terrain like it's theirs because they drew a border across it once."},
		{"speaker": "Inez", "text": "Good. I was waiting to see if you noticed."},
		{"speaker": "Maela Thorn", "text": "I notice plenty. I just make it look cheerful."},
		{"speaker": "Inez", "text": "Yes. Like a hawk pretending it is decorative."},
		{"speaker": "Maela Thorn", "text": "Again, alarmingly flattering."},
		{"speaker": "Inez", "text": "Do not get used to it."},
		{"speaker": "Maela Thorn", "text": "Too late. So answer me something, forest-heart. When all this is over, do you think there'll be any wild places left that don't belong to a crown, a guild, or a shrine?"}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "Only if we guard them.",
			"result": "success",
			"response": [
				{"speaker": "Inez", "text": "Only if people like us guard them before someone names ownership holy again."},
				{"speaker": "Maela Thorn", "text": "...People like us?"},
				{"speaker": "Inez", "text": "Fast eyes. Sharp instincts. Poor tolerance for fences."},
				{"speaker": "Maela Thorn", "text": "Well. That's practically a vow."},
				{"speaker": "Inez", "text": "No. It's a practical arrangement."},
				{"speaker": "Maela Thorn", "text": "Mm. And if I choose to hear affection in it anyway?"},
				{"speaker": "Inez", "text": "...That is your business. Just be on time when I call."},
				{"speaker": "Maela Thorn", "text": "There it is. That's how your kind says 'stay near me,' isn't it?"}
			]
		},
		{
			"text": "Maybe nowhere stays wild.",
			"result": "fail",
			"response": [
				{"speaker": "Maela Thorn", "text": "That's a grim answer."},
				{"speaker": "Inez", "text": "A cautious one."},
				{"speaker": "Maela Thorn", "text": "Then let me improve it. If nowhere stays wild on its own, we'll simply have to help."},
				{"speaker": "Inez", "text": "...That is reckless."},
				{"speaker": "Maela Thorn", "text": "And useful. You said yourself the combination has merit."}
			]
		}
	]
},
"Branik_Inez_Rank1": {
	"req_level": 8,
	"script": [
		{"speaker": "Branik", "text": "Your wolf nearly took my hand off when I offered him dried meat."},
		{"speaker": "Inez", "text": "Because you reached first and thought second."},
		{"speaker": "Branik", "text": "Fair. Usually works better with people."},
		{"speaker": "Inez", "text": "He is not people."},
		{"speaker": "Branik", "text": "No. But he's got taste. He stopped growling after he smelled the stew pot."},
		{"speaker": "Inez", "text": "...He did."},
		{"speaker": "Branik", "text": "You don't trust camps easy, do you? Not after Elderglen."}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "She's still wary.",
			"result": "success",
			"response": [
				{"speaker": "Inez", "text": "Wary keeps things alive."},
				{"speaker": "Branik", "text": "Aye. So does eating while the food's warm."},
				{"speaker": "Inez", "text": "That your answer to everything?"},
				{"speaker": "Branik", "text": "Not everything. Just fear, grief, weather, and people too stubborn to sit down."},
				{"speaker": "Inez", "text": "...Your methods are rustic."},
				{"speaker": "Branik", "text": "And effective. Like your wolf."}
			]
		},
		{
			"text": "He likes you already.",
			"result": "fail",
			"response": [
				{"speaker": "Inez", "text": "He likes the stew."},
				{"speaker": "Branik", "text": "I've won folk over with less."},
				{"speaker": "Inez", "text": "He's wiser than folk, then."},
				{"speaker": "Branik", "text": "...I think that was an insult."}
			]
		}
	]
},
"Branik_Inez_Rank2": {
	"req_level": 10,
	"script": [
		{"speaker": "Inez", "text": "You moved the wounded first during the Sunlit Trial."},
		{"speaker": "Branik", "text": "Someone had to. Arena crowds don't think much once they smell blood and spectacle together."},
		{"speaker": "Inez", "text": "You read crowds like I read tree lines."},
		{"speaker": "Branik", "text": "Used to lead worse kinds of groups than this one. You learn where panic runs before the legs do."},
		{"speaker": "Inez", "text": "You speak of your old life too easily for a man ashamed of it."},
		{"speaker": "Branik", "text": "No. I speak of it plainly. Shame's easier to carry when you stop dressing it up."},
		{"speaker": "Inez", "text": "...That is not how most men talk about guilt."},
		{"speaker": "Branik", "text": "Most men are still hoping it'll excuse them."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "That's why she trusts you.",
			"result": "success",
			"response": [
				{"speaker": "Inez", "text": "...Partly."},
				{"speaker": "Branik", "text": "Only partly?"},
				{"speaker": "Inez", "text": "The rest is because when danger started, you did not look heroic. You looked useful."},
				{"speaker": "Branik", "text": "Hnh. That's one of the nicer things I've heard."},
				{"speaker": "Inez", "text": "Do not get vain. I can take it back."},
				{"speaker": "Branik", "text": "Too late. I'm keeping it with the good spoons."}
			]
		},
		{
			"text": "You understand loss alike.",
			"result": "fail",
			"response": [
				{"speaker": "Inez", "text": "Perhaps."},
				{"speaker": "Branik", "text": "Enough of it, anyway."},
				{"speaker": "Inez", "text": "Loss teaches badly. But it teaches."},
				{"speaker": "Branik", "text": "Aye. I'd still rather have learned some other way."}
			]
		}
	]
},
"Branik_Inez_Rank3": {
	"req_level": 13,
	"script": [
		{"speaker": "Branik", "text": "Your wolf followed me to the cookfire again."},
		{"speaker": "Inez", "text": "That means he has judged you edible-adjacent, not trustworthy."},
		{"speaker": "Branik", "text": "Still progress."},
		{"speaker": "Inez", "text": "Mm."},
		{"speaker": "Branik", "text": "You were good on the Black Coast. Kept the landing lanes clear, read the wind clean, didn't let the sea spook you."},
		{"speaker": "Inez", "text": "I dislike the sea. It hides too much and belongs to no one sensible."},
		{"speaker": "Branik", "text": "That's why I thought you'd hate it."},
		{"speaker": "Inez", "text": "I did. I simply did the work anyway."},
		{"speaker": "Branik", "text": "...Aye. That's the kind that matters."},
		{"speaker": "Inez", "text": "You say that as if you have decided something."}
	],
	"branch_at": 9,
	"choices": [
		{
			"text": "Say it plainly.",
			"result": "success",
			"response": [
				{"speaker": "Branik", "text": "I decided I'd trust you watching any road I meant to walk later. That's as close to peace of mind as this war gives me."},
				{"speaker": "Inez", "text": "...That is not a small thing."},
				{"speaker": "Branik", "text": "No. It isn't."},
				{"speaker": "Inez", "text": "Then hear mine in return. If the camp fell in the night, I would send the young and wounded toward your fire first."},
				{"speaker": "Branik", "text": "That's trust enough for me."},
				{"speaker": "Inez", "text": "Good. Because I do not hand it out prettily."},
				{"speaker": "Branik", "text": "Neither do I. Works out fine."}
			]
		},
		{
			"text": "You both notice everything.",
			"result": "fail",
			"response": [
				{"speaker": "Inez", "text": "Not everything. Enough."},
				{"speaker": "Branik", "text": "Enough keeps folks alive."},
				{"speaker": "Inez", "text": "Yes. The rest is noise."},
				{"speaker": "Branik", "text": "...You're growing on me, you know."},
				{"speaker": "Inez", "text": "Keep that to yourself. I have a reputation for silence."}
			]
		}
	]
},
"Branik_Tamsin_Rank1": {
	"req_level": 3,
	"script": [
		{"speaker": "Tamsin", "text": "That is not how poultices are supposed to be stacked."},
		{"speaker": "Branik", "text": "They're not stacked. They're drying."},
		{"speaker": "Tamsin", "text": "On the stew stones."},
		{"speaker": "Branik", "text": "Warm stones. Good for drying."},
		{"speaker": "Tamsin", "text": "Good for smelling like onions."},
		{"speaker": "Branik", "text": "...Hadn't considered that."},
		{"speaker": "Tamsin", "text": "I can tell."}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "Show him properly.",
			"result": "success",
			"response": [
				{"speaker": "Tamsin", "text": "Fine. Lift those, please. No, gently. They're medicine, not potatoes."},
				{"speaker": "Branik", "text": "Most things improve if you handle them like potatoes."},
				{"speaker": "Tamsin", "text": "That is a horrifying philosophy for a field hospital."},
				{"speaker": "Branik", "text": "And yet you're smiling."},
				{"speaker": "Tamsin", "text": "...Only because this is less upsetting than trying to stop Nyx from storing powder next to tinctures."}
			]
		},
		{
			"text": "Onion medicine works.",
			"result": "fail",
			"response": [
				{"speaker": "Tamsin", "text": "Commander, no. That is not how medicine works."},
				{"speaker": "Branik", "text": "It was worth a try."},
				{"speaker": "Tamsin", "text": "No, it absolutely was not."},
				{"speaker": "Branik", "text": "...You sound just like my daughter when I improvised."}
			]
		}
	]
},
"Branik_Tamsin_Rank2": {
	"req_level": 6,
	"script": [
		{"speaker": "Branik", "text": "You're still awake."},
		{"speaker": "Tamsin", "text": "Greyspire's infirmary inventory was inaccurate, half the bandages are too coarse, three of the tonic jars were mislabeled, and someone keeps moving my mortar."},
		{"speaker": "Branik", "text": "Oren used it to crack walnuts."},
		{"speaker": "Tamsin", "text": "...Of course he did."},
		{"speaker": "Branik", "text": "You've been running since the siege ended."},
		{"speaker": "Tamsin", "text": "Because if I stop, I start thinking about how many people nearly didn't make it inside these walls."},
		{"speaker": "Branik", "text": "Aye."},
		{"speaker": "Tamsin", "text": "You always say 'aye' like it counts as emotional support."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "It sort of does.",
			"result": "success",
			"response": [
				{"speaker": "Branik", "text": "It means I hear you. And that you've done enough work for one night."},
				{"speaker": "Tamsin", "text": "There is still so much left."},
				{"speaker": "Branik", "text": "There always is. That's why we take turns carrying it."},
				{"speaker": "Tamsin", "text": "...You really do sound like a campfire with shoulders."},
				{"speaker": "Branik", "text": "That's one of the kinder insults I've had."},
				{"speaker": "Tamsin", "text": "It wasn't an insult."}
			]
		},
		{
			"text": "You need rest too.",
			"result": "fail",
			"response": [
				{"speaker": "Tamsin", "text": "I know. I just don't know how to stop before everything is right."},
				{"speaker": "Branik", "text": "Then start by learning this: in war, 'better' is sometimes the only kind of right you get."},
				{"speaker": "Tamsin", "text": "...I don't like that lesson."},
				{"speaker": "Branik", "text": "No. But it keeps healers alive too."}
			]
		}
	]
},
"Branik_Tamsin_Rank3": {
	"req_level": 9,
	"script": [
		{"speaker": "Tamsin", "text": "The mountain pass should not have been survivable."},
		{"speaker": "Branik", "text": "Most things are, if you get enough stubborn people pulling the same rope."},
		{"speaker": "Tamsin", "text": "That isn't anatomy, strategy, or theology. That's just Branik."},
		{"speaker": "Branik", "text": "Has worked so far."},
		{"speaker": "Tamsin", "text": "You carried the envoy's clerk, the broken supply chest, and two wounded soldiers in one afternoon."},
		{"speaker": "Branik", "text": "Aye."},
		{"speaker": "Tamsin", "text": "And then you still came to the infirmary asking if I had eaten."},
		{"speaker": "Branik", "text": "Had you?"},
		{"speaker": "Tamsin", "text": "...No."},
		{"speaker": "Branik", "text": "Thought so."}
	],
	"branch_at": 9,
	"choices": [
		{
			"text": "She notices you too.",
			"result": "success",
			"response": [
				{"speaker": "Tamsin", "text": "I do notice, you know."},
				{"speaker": "Branik", "text": "Notice what?"},
				{"speaker": "Tamsin", "text": "That everyone rests easier when you're near. That you feed people before they ask. That you make a camp feel less temporary."},
				{"speaker": "Branik", "text": "...That's kind of you."},
				{"speaker": "Tamsin", "text": "It's true. And for the record, I've started setting aside the least-burnt tea water because I know you'll pretend not to care and drink it anyway."},
				{"speaker": "Branik", "text": "That's practically friendship, isn't it?"},
				{"speaker": "Tamsin", "text": "It may even be organized friendship. Which is rarer."}
			]
		},
		{
			"text": "He mothers everyone.",
			"result": "fail",
			"response": [
				{"speaker": "Branik", "text": "That's not the word I'd choose."},
				{"speaker": "Tamsin", "text": "No, but it's not entirely wrong either."},
				{"speaker": "Branik", "text": "...I'll accept 'overly invested in whether fools eat properly.'"},
				{"speaker": "Tamsin", "text": "Fine. But that's a very long way to say the same thing."}
			]
		}
	]
},
"Nyx_Rufus_Rank1": {
	"req_level": 4,
	"script": [
		{"speaker": "Nyx", "text": "You were aiming at me from that rooftop longer than you needed to."},
		{"speaker": "Rufus", "text": "I was deciding whether you were a saboteur, a thief, or one of those people who's both and smug about it."},
		{"speaker": "Nyx", "text": "And what did you decide?"},
		{"speaker": "Rufus", "text": "That you moved like somebody who learned streets before letters."},
		{"speaker": "Nyx", "text": "...Huh."},
		{"speaker": "Rufus", "text": "Didn't say it as pity."},
		{"speaker": "Nyx", "text": "Good. I'd have pushed you off the roof for that."},
		{"speaker": "Rufus", "text": "Yeah. I figured we'd understand each other better after I climbed down."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "You read each other.",
			"result": "success",
			"response": [
				{"speaker": "Nyx", "text": "Only because debt leaves the same stink on everyone who survives it."},
				{"speaker": "Rufus", "text": "There it is. That's the sentence I was waiting for."},
				{"speaker": "Nyx", "text": "Don't get sentimental, cannoneer."},
				{"speaker": "Rufus", "text": "Wouldn't dream of it. Just nice talking to someone who knows what a ledger feels like when it's pressed against your throat."},
				{"speaker": "Nyx", "text": "...Yeah. Nice. In a miserable sort of way."}
			]
		},
		{
			"text": "You were enemies first.",
			"result": "fail",
			"response": [
				{"speaker": "Rufus", "text": "Sure. For about ten minutes."},
				{"speaker": "Nyx", "text": "Some people take longer to recognize quality."},
				{"speaker": "Rufus", "text": "You call that quality?"},
				{"speaker": "Nyx", "text": "I call it surviving the League with your sense of humor mostly intact."}
			]
		}
	]
},
"Nyx_Rufus_Rank2": {
	"req_level": 6,
	"script": [
		{"speaker": "Rufus", "text": "Greyspire's nice and all, but these walls creak like they owe somebody money."},
		{"speaker": "Nyx", "text": "Everything owes somebody money. Walls just complain less poetically."},
		{"speaker": "Rufus", "text": "Heh. Fair."},
		{"speaker": "Nyx", "text": "You settling in, or still waiting for the commander to hand you back to a merchant house in neat pieces?"},
		{"speaker": "Rufus", "text": "Bit of both. Hard habit to break, expecting every roof to come with a price tag hidden under it."},
		{"speaker": "Nyx", "text": "Mm."},
		{"speaker": "Rufus", "text": "You too, huh?"},
		{"speaker": "Nyx", "text": "You don't grow up in the League and mistake shelter for generosity. Not twice."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "This roof is different.",
			"result": "success",
			"response": [
				{"speaker": "Nyx", "text": "...Maybe."},
				{"speaker": "Rufus", "text": "Maybe's a start."},
				{"speaker": "Nyx", "text": "Don't push it. I only just stopped counting the exits every time I sit down to eat."},
				{"speaker": "Rufus", "text": "Same. Still weird hearing people say 'our stores' and not reach for a lock afterward."},
				{"speaker": "Nyx", "text": "...Gods. You really do get it."},
				{"speaker": "Rufus", "text": "Told you. Dock debt, same language."}
			]
		},
		{
			"text": "Paranoia keeps you sharp.",
			"result": "fail",
			"response": [
				{"speaker": "Nyx", "text": "It does. Also keeps you tired."},
				{"speaker": "Rufus", "text": "Yeah. Sharp's overrated when it means sleeping like a knife."},
				{"speaker": "Nyx", "text": "...That's disgustingly well put."},
				{"speaker": "Rufus", "text": "Comes from years of being poor with a vocabulary."}
			]
		}
	]
},
"Nyx_Rufus_Rank3": {
	"req_level": 11,
	"script": [
		{"speaker": "Nyx", "text": "You were watching the nobles during the festival more than the assassins."},
		{"speaker": "Rufus", "text": "Assassins I understand. Rich men pretending surprise at consequences? That's worth studying."},
		{"speaker": "Nyx", "text": "Ha. You really are one of mine."},
		{"speaker": "Rufus", "text": "Careful. I've seen your kind of family. Lot of knives. Not enough chairs."},
		{"speaker": "Nyx", "text": "Chairs are how they make you stay for lectures."},
		{"speaker": "Rufus", "text": "And here I thought it was the stew."},
		{"speaker": "Nyx", "text": "That too."},
		{"speaker": "Rufus", "text": "For what it's worth, when the crowd turned and the stage guards froze, I knew where you were without looking. Left alley. Fast exit. Backup route through the awnings."},
		{"speaker": "Nyx", "text": "...You trust me that much?"}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "He trusts your instincts.",
			"result": "success",
			"response": [
				{"speaker": "Rufus", "text": "Yeah. I do."},
				{"speaker": "Nyx", "text": "That's either flattering or medically concerning."},
				{"speaker": "Rufus", "text": "Probably both. But you've got the kind of instincts that come from surviving when nobody planned for you to."},
				{"speaker": "Nyx", "text": "...That's one hell of a thing to say to someone."},
				{"speaker": "Rufus", "text": "Take it, then. I mean it."},
				{"speaker": "Nyx", "text": "...All right. Then here's one back: if this army ever fractures, you're one of the few I'd still bet on to bring people home instead of just winning the street."},
				{"speaker": "Rufus", "text": "Coming from you? That's damn near sacred."}
			]
		},
		{
			"text": "Trust is risky.",
			"result": "fail",
			"response": [
				{"speaker": "Nyx", "text": "No kidding."},
				{"speaker": "Rufus", "text": "Yeah. But so's not trusting anyone until it's too late."},
				{"speaker": "Nyx", "text": "...You always sound like a laborer and a philosopher got trapped in the same coat."},
				{"speaker": "Rufus", "text": "Cheaper than owning two coats."}
			]
		}
	]
},
"Hest_YselleMaris_Rank1": {
	"req_level": 11,
	"script": [
		{"speaker": "Hest", "text": "You're impossible, you know that?"},
		{"speaker": "Yselle Maris", "text": "Such a promising opening line. Do continue."},
		{"speaker": "Hest", "text": "During the festival, people were screaming, guards were tripping over their own boots, and you were still smiling like the whole thing had been choreographed."},
		{"speaker": "Yselle Maris", "text": "Darling, if panic notices you noticing it, panic wins."},
		{"speaker": "Hest", "text": "See? Impossible."},
		{"speaker": "Yselle Maris", "text": "No. Practiced."},
		{"speaker": "Hest", "text": "That's worse somehow."},
		{"speaker": "Yselle Maris", "text": "Only if you were hoping I sprang fully formed from silk and bad decisions."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "She worked for it.",
			"result": "success",
			"response": [
				{"speaker": "Hest", "text": "Yeah, I figured. Nobody moves a crowd like that by accident."},
				{"speaker": "Yselle Maris", "text": "Good. I do hate being mistaken for effortless. It's terrible for discipline."},
				{"speaker": "Hest", "text": "So how'd you do it?"},
				{"speaker": "Yselle Maris", "text": "Stagecraft, sweetheart. You learn where eyes go first, and then you teach fear to follow fashionably behind."},
				{"speaker": "Hest", "text": "...Gods, I want to learn that."}
			]
		},
		{
			"text": "You're still impossible.",
			"result": "fail",
			"response": [
				{"speaker": "Yselle Maris", "text": "Oh, absolutely. But impossible women survive cities better than obedient ones."},
				{"speaker": "Hest", "text": "...That is a very good line."},
				{"speaker": "Yselle Maris", "text": "I know. Try not to steal it until you've earned the posture."},
				{"speaker": "Hest", "text": "Rude. Fair, but rude."}
			]
		}
	]
},
"Hest_YselleMaris_Rank2": {
	"req_level": 12,
	"script": [
		{"speaker": "Yselle Maris", "text": "I found one of your little ribbon markers in the archive stacks."},
		{"speaker": "Hest", "text": "Ah. That means I was improving the place."},
		{"speaker": "Yselle Maris", "text": "By leaving bright bits of cloth in a maze of forbidden knowledge?"},
		{"speaker": "Hest", "text": "Exactly. If a library wants to behave like a deathtrap, the least it can do is accept stage cues."},
		{"speaker": "Yselle Maris", "text": "...I am horrified by how much sense that makes."},
		{"speaker": "Hest", "text": "Thank you."},
		{"speaker": "Yselle Maris", "text": "That was not praise."},
		{"speaker": "Hest", "text": "No, but you didn't throw the ribbons away either."},
		{"speaker": "Yselle Maris", "text": "...No. I color-coded your exits."}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "You improved them?",
			"result": "success",
			"response": [
				{"speaker": "Hest", "text": "You improved my markers?"},
				{"speaker": "Yselle Maris", "text": "A little. You were thinking like a sprinter. I was thinking like an audience manager."},
				{"speaker": "Hest", "text": "That's the nicest sabotage anyone's ever done to me."},
				{"speaker": "Yselle Maris", "text": "Correction. Mentorship."},
				{"speaker": "Hest", "text": "...Oh, that's worse. Now I have to impress you on purpose."},
				{"speaker": "Yselle Maris", "text": "Yes, darling. That was always the plan."}
			]
		},
		{
			"text": "She's judging you.",
			"result": "fail",
			"response": [
				{"speaker": "Hest", "text": "I know she's judging me. That's half the fun."},
				{"speaker": "Yselle Maris", "text": "And the other half?"},
				{"speaker": "Hest", "text": "That sometimes you look impressed before you remember not to."},
				{"speaker": "Yselle Maris", "text": "...You are far too observant for your age."}
			]
		}
	]
},
"Hest_YselleMaris_Rank3": {
	"req_level": 17,
	"script": [
		{"speaker": "Hest", "text": "The coalition camp was disgusting."},
		{"speaker": "Yselle Maris", "text": "My word. Straight to the thesis."},
		{"speaker": "Hest", "text": "No ribbons on that one. Just true. Everyone looked polished enough to eat off, and half of them were still trying to decide how much apocalypse they could profit from."},
		{"speaker": "Yselle Maris", "text": "Mm. You are learning to read elite manners properly. I feel both proud and vaguely responsible."},
		{"speaker": "Hest", "text": "You should. You taught me the difference between grace and camouflage."},
		{"speaker": "Yselle Maris", "text": "...That is an unexpectedly elegant sentence from you."},
		{"speaker": "Hest", "text": "Yeah, well. Maybe some of your impossible leaked."},
		{"speaker": "Yselle Maris", "text": "Careful. If you keep speaking like that, I'll start thinking the lessons took."},
		{"speaker": "Hest", "text": "Then let me ask before the Spire ruins everyone's mood permanently. Was I just amusing to train, or did you actually want me sharper?"}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "She wanted both.",
			"result": "success",
			"response": [
				{"speaker": "Yselle Maris", "text": "Both, obviously. But mostly the second."},
				{"speaker": "Hest", "text": "...Oh."},
				{"speaker": "Yselle Maris", "text": "Do not make that face. I dislike sincerity when it ambushes me."},
				{"speaker": "Hest", "text": "Too bad. You made me better."},
				{"speaker": "Yselle Maris", "text": "No, darling. You made yourself better. I merely pointed out where your chaos was wasting style."},
				{"speaker": "Hest", "text": "That is such a you answer."},
				{"speaker": "Yselle Maris", "text": "And you adore it."}
			]
		},
		{
			"text": "You were entertaining.",
			"result": "fail",
			"response": [
				{"speaker": "Yselle Maris", "text": "Well, yes. But do not pout. Entertainment is a sacred profession."},
				{"speaker": "Hest", "text": "...That's not a no, though."},
				{"speaker": "Yselle Maris", "text": "No, it isn't. You were also worth the effort. There. A compromise."},
				{"speaker": "Hest", "text": "I'll take it. Grudgingly."}
			]
		}
	]
},
"MaelaThorn_Pell_Rank1": {
	"req_level": 13,
	"script": [
		{"speaker": "Pell", "text": "That dive over the Black Coast wall was incredible."},
		{"speaker": "Maela Thorn", "text": "There it is. Knew you'd say it."},
		{"speaker": "Pell", "text": "Because it was! You came out of the rain like a knife with feathers."},
		{"speaker": "Maela Thorn", "text": "Gods, keep talking. I'll never need a mirror again."},
		{"speaker": "Pell", "text": "...Was that too much?"},
		{"speaker": "Maela Thorn", "text": "Far too much. Which is why I like it."},
		{"speaker": "Pell", "text": "I just meant you made the whole landing look possible."},
		{"speaker": "Maela Thorn", "text": "And you made the whole beach look nervous. We all have talents."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "She's teasing you.",
			"result": "success",
			"response": [
				{"speaker": "Pell", "text": "I noticed."},
				{"speaker": "Maela Thorn", "text": "Good. Means you're trainable."},
				{"speaker": "Pell", "text": "Is everyone in this army secretly trying to train me?"},
				{"speaker": "Maela Thorn", "text": "Not secretly. You're just slow."},
				{"speaker": "Pell", "text": "...That was very mean."},
				{"speaker": "Maela Thorn", "text": "Yes. You'll survive it."}
			]
		},
		{
			"text": "You did great, Pell.",
			"result": "fail",
			"response": [
				{"speaker": "Pell", "text": "Thank you."},
				{"speaker": "Maela Thorn", "text": "Oh no, now he's encouraged."},
				{"speaker": "Pell", "text": "I was already encouraged."},
				{"speaker": "Maela Thorn", "text": "That explains so much."}
			]
		}
	]
},
"MaelaThorn_Pell_Rank2": {
	"req_level": 14,
	"script": [
		{"speaker": "Maela Thorn", "text": "You almost got flattened at Dawnkeep."},
		{"speaker": "Pell", "text": "I did not get flattened."},
		{"speaker": "Maela Thorn", "text": "No, because I yelled before the tower stones came down."},
		{"speaker": "Pell", "text": "...Right. Yes. Thank you for that, by the way."},
		{"speaker": "Maela Thorn", "text": "You're welcome. Try not to make a habit of needing rescue from masonry."},
		{"speaker": "Pell", "text": "In my defense, there was a lot of masonry."},
		{"speaker": "Maela Thorn", "text": "And none of it was subtle."},
		{"speaker": "Pell", "text": "...You sound like Veska when you're annoyed."},
		{"speaker": "Maela Thorn", "text": "Cruel."}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "She saved you, though.",
			"result": "success",
			"response": [
				{"speaker": "Pell", "text": "Yes. She did. I know I joke when I'm embarrassed, but I did notice."},
				{"speaker": "Maela Thorn", "text": "...Good."},
				{"speaker": "Pell", "text": "And for the record, your signal came exactly when I needed it."},
				{"speaker": "Maela Thorn", "text": "That's because I was watching you."},
				{"speaker": "Pell", "text": "...Oh."},
				{"speaker": "Maela Thorn", "text": "Don't make that face. You looked like you were about to get heroic in a structurally unsound direction. Someone had to intervene."}
			]
		},
		{
			"text": "You both survived.",
			"result": "fail",
			"response": [
				{"speaker": "Maela Thorn", "text": "Barely is a survival category, yes."},
				{"speaker": "Pell", "text": "Gods, everyone in this army is vicious."},
				{"speaker": "Maela Thorn", "text": "No. Just invested in keeping you upright long enough to improve."},
				{"speaker": "Pell", "text": "...That is almost sweet if I squint."}
			]
		}
	]
},
"MaelaThorn_Pell_Rank3": {
	"req_level": 17,
	"script": [
		{"speaker": "Pell", "text": "You were awful in the coalition camp."},
		{"speaker": "Maela Thorn", "text": "Excuse me?"},
		{"speaker": "Pell", "text": "No, I mean— wonderfully awful. You kept circling the tents low enough to annoy every officer with polished boots."},
		{"speaker": "Maela Thorn", "text": "...That is a better recovery than I expected from you."},
		{"speaker": "Pell", "text": "I've been learning."},
		{"speaker": "Maela Thorn", "text": "So you have. Most people just see noise when I do that. You noticed I was testing who flinched from pressure first."},
		{"speaker": "Pell", "text": "You make people reveal themselves. I think that's what I like about you."},
		{"speaker": "Maela Thorn", "text": "...Dangerous sentence, knightling."},
		{"speaker": "Pell", "text": "I know."},
		{"speaker": "Maela Thorn", "text": "Then answer carefully. When the Spire is over, do you still want all that noble, orderly heroism you used to talk about?"}
	],
	"branch_at": 9,
	"choices": [
		{
			"text": "Not the old kind.",
			"result": "success",
			"response": [
				{"speaker": "Pell", "text": "Not the old kind. I think I want something livelier. Less polished. More honest about risk and joy both."},
				{"speaker": "Maela Thorn", "text": "...Now that is interesting."},
				{"speaker": "Pell", "text": "You sound pleased."},
				{"speaker": "Maela Thorn", "text": "I am. Means you might survive becoming worth teasing for the rest of your life."},
				{"speaker": "Pell", "text": "That sounds suspiciously specific."},
				{"speaker": "Maela Thorn", "text": "Good. Then hear it properly: if we live, I intend to keep bothering you until you stop blushing every time I say something reckless."},
				{"speaker": "Pell", "text": "...I don't think that is physically possible."},
				{"speaker": "Maela Thorn", "text": "Excellent. Then I won't get bored."}
			]
		},
		{
			"text": "Order still matters.",
			"result": "fail",
			"response": [
				{"speaker": "Pell", "text": "It still matters. I just... maybe I don't want it to be joyless anymore."},
				{"speaker": "Maela Thorn", "text": "...Better answer."},
				{"speaker": "Pell", "text": "Was there a wrong one?"},
				{"speaker": "Maela Thorn", "text": "Several. You dodged most of them."},
				{"speaker": "Pell", "text": "That sounded almost like praise."},
				{"speaker": "Maela Thorn", "text": "Don't get greedy."}
			]
		}
	]
},
"Nyx_OrenPike_Rank1": {
	"req_level": 6,
	"script": [
		{"speaker": "Oren Pike", "text": "If I find one more spring missing from my toolkit, I'm soldering your gloves shut."},
		{"speaker": "Nyx", "text": "Empty threat. You'd miss my hands the moment a lock stopped cooperating."},
		{"speaker": "Oren Pike", "text": "I'd miss the springs more."},
		{"speaker": "Nyx", "text": "Liar. You were impressed with the trap I rigged on the west stair."},
		{"speaker": "Oren Pike", "text": "I was impressed it didn't kill Pell."},
		{"speaker": "Nyx", "text": "Such low standards. We really are colleagues."},
		{"speaker": "Oren Pike", "text": "...Don't say that like it's contagious."}
	],
	"branch_at": 6,
	"choices": [
		{
			"text": "You are colleagues.",
			"result": "success",
			"response": [
				{"speaker": "Nyx", "text": "See? Recognized at last."},
				{"speaker": "Oren Pike", "text": "Recognized as a menace with decent instincts."},
				{"speaker": "Nyx", "text": "And you as a joyless engineer with admirable spite."},
				{"speaker": "Oren Pike", "text": "...That's almost respectful."},
				{"speaker": "Nyx", "text": "Don't get sentimental. Greyspire's walls are thin enough without that echoing around."}
			]
		},
		{
			"text": "Stop stealing parts.",
			"result": "fail",
			"response": [
				{"speaker": "Nyx", "text": "I prefer 'resource redistribution.'"},
				{"speaker": "Oren Pike", "text": "I prefer 'toolbox integrity.'"},
				{"speaker": "Nyx", "text": "Gods, you make maintenance sound erotic."},
				{"speaker": "Oren Pike", "text": "...Leave my workshop."}
			]
		}
	]
},
"Nyx_OrenPike_Rank2": {
	"req_level": 9,
	"script": [
		{"speaker": "Nyx", "text": "You saw the warehouse district fast."},
		{"speaker": "Oren Pike", "text": "Built by cowards with a budget. Easy pattern once you know the smell."},
		{"speaker": "Nyx", "text": "Hnh. I liked that line."},
		{"speaker": "Oren Pike", "text": "Don't. It'll encourage me."},
		{"speaker": "Nyx", "text": "Too late. You called the drawbridge timings, the blind corners, the false storage lanes. I called the escape ropes and the debt routes. We made a very unpleasant map together."},
		{"speaker": "Oren Pike", "text": "A useful one."},
		{"speaker": "Nyx", "text": "That's what I mean. You don't look at a city like a tourist or a commander. You look at it like a machine somebody rigged against the poor."},
		{"speaker": "Oren Pike", "text": "...And you look at it like someone who learned where the gears cut first."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "That's mutual respect.",
			"result": "success",
			"response": [
				{"speaker": "Nyx", "text": "Ugh. Don't call it that in front of him."},
				{"speaker": "Oren Pike", "text": "Too late."},
				{"speaker": "Nyx", "text": "Fine. I respect your eye. There. Ruined my whole afternoon saying it."},
				{"speaker": "Oren Pike", "text": "...Likewise."},
				{"speaker": "Nyx", "text": "Gods, you made that sound like a burial vow."},
				{"speaker": "Oren Pike", "text": "I don't practice warmth. Only accuracy."}
			]
		},
		{
			"text": "You're both just cynical.",
			"result": "fail",
			"response": [
				{"speaker": "Nyx", "text": "No. Cynical's decorative. We're practical."},
				{"speaker": "Oren Pike", "text": "Decorative cynics don't survive warehouse districts."},
				{"speaker": "Nyx", "text": "...That was disturbingly elegant."},
				{"speaker": "Oren Pike", "text": "Don't repeat it. I have a reputation for useful ugliness."}
			]
		}
	]
},
"Nyx_OrenPike_Rank3": {
	"req_level": 13,
	"script": [
		{"speaker": "Oren Pike", "text": "The Black Coast would've gone worse without your signal flares."},
		{"speaker": "Nyx", "text": "And without your tide calculations, my signal flares would've gone directly into the sea. So let's call that marriage of convenience."},
		{"speaker": "Oren Pike", "text": "I wouldn't insult marriage that way."},
		{"speaker": "Nyx", "text": "...That was almost a joke."},
		{"speaker": "Oren Pike", "text": "Don't spread it around."},
		{"speaker": "Nyx", "text": "Too late. I'm treasuring it."},
		{"speaker": "Oren Pike", "text": "Gods."},
		{"speaker": "Nyx", "text": "No, listen. On the coast, when the rain hit and the stairs vanished under everyone else's feet, I knew where you'd reroute the landing gear before you shouted it. That's not normal."},
		{"speaker": "Oren Pike", "text": "No. That's practice."},
		{"speaker": "Nyx", "text": "No. That's trust in the ugly little way our sort uses the word."}
	],
	"branch_at": 9,
	"choices": [
		{
			"text": "Say it plainly.",
			"result": "success",
			"response": [
				{"speaker": "Oren Pike", "text": "...All right. I trust your instincts when structures fail and plans go rotten. You notice where systems crack before most people notice they were trapped inside one."},
				{"speaker": "Nyx", "text": "...Well. That's disgustingly specific."},
				{"speaker": "Oren Pike", "text": "You wanted plain."},
				{"speaker": "Nyx", "text": "I did. Still not emotionally prepared for it."},
				{"speaker": "Oren Pike", "text": "Tough."},
				{"speaker": "Nyx", "text": "...For what it's worth, if the world survives the Spire and anyone tries to build another clever machine for crushing small people under big paperwork, I want to be there when you break it."},
				{"speaker": "Oren Pike", "text": "Good. Bring your own springs."}
			]
		},
		{
			"text": "Keep it ugly.",
			"result": "fail",
			"response": [
				{"speaker": "Nyx", "text": "Fair. We do our best work ugly."},
				{"speaker": "Oren Pike", "text": "Clean things are often lies."},
				{"speaker": "Nyx", "text": "...That one I'm stealing."},
				{"speaker": "Oren Pike", "text": "You already stole three screws and a brace pin. Might as well take the sentence too."}
			]
		}
	]
},
"BrotherAlden_Tamsin_Rank1": {
	"req_level": 9,
	"script": [
		{"speaker": "Brother Alden", "text": "You wrapped the envoy's clerk before you finished shaking."},
		{"speaker": "Tamsin", "text": "I was not shaking that badly."},
		{"speaker": "Brother Alden", "text": "No. Which is why I noticed."},
		{"speaker": "Tamsin", "text": "...The mountain pass was too narrow. Everyone kept speaking as if diplomacy and murder were simply taking turns."},
		{"speaker": "Brother Alden", "text": "In Aurelia, they often are."},
		{"speaker": "Tamsin", "text": "That is a terrible thing to say calmly."},
		{"speaker": "Brother Alden", "text": "It is also a useful thing to hear early."},
		{"speaker": "Tamsin", "text": "I don't feel useful. I feel like I'm one scream away from dropping a whole tray of bandages into a ravine."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "You held steady.",
			"result": "success",
			"response": [
				{"speaker": "Brother Alden", "text": "No, child. You felt fear and still kept your hands useful. That's steadiness."},
				{"speaker": "Tamsin", "text": "...That sounds much nobler than it felt."},
				{"speaker": "Brother Alden", "text": "Most virtues do from the outside."},
				{"speaker": "Tamsin", "text": "You make panic sound almost respectable."},
				{"speaker": "Brother Alden", "text": "Only the kind that keeps working."},
				{"speaker": "Tamsin", "text": "...I think I needed that."}
			]
		},
		{
			"text": "Everyone was scared.",
			"result": "fail",
			"response": [
				{"speaker": "Tamsin", "text": "I know. That somehow makes it worse, not better."},
				{"speaker": "Brother Alden", "text": "Because you expected healers to be made of calmer clay?"},
				{"speaker": "Tamsin", "text": "...Yes, a little."},
				{"speaker": "Brother Alden", "text": "Then let that illusion die young. Calm is a skill. Care is the calling."}
			]
		}
	]
},
"BrotherAlden_Tamsin_Rank2": {
	"req_level": 11,
	"script": [
		{"speaker": "Tamsin", "text": "I hated the festival."},
		{"speaker": "Brother Alden", "text": "Sensible. It became theatrical in all the wrong ways."},
		{"speaker": "Tamsin", "text": "No, I mean before the blood. All those smiling faces, all that music, and underneath it everyone waiting for something to go wrong."},
		{"speaker": "Brother Alden", "text": "You noticed the strain under the paint."},
		{"speaker": "Tamsin", "text": "I notice too much lately."},
		{"speaker": "Brother Alden", "text": "That is often the price of surviving long enough to become competent."},
		{"speaker": "Tamsin", "text": "You say these things like they're comforting."},
		{"speaker": "Brother Alden", "text": "No. I say them like they're true."},
		{"speaker": "Tamsin", "text": "...When the first knife came out, I didn't think 'help the wounded.' I thought, very clearly, 'I want to go home.'"}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "That's human, Tamsin.",
			"result": "success",
			"response": [
				{"speaker": "Brother Alden", "text": "Good. Hold on to that."},
				{"speaker": "Tamsin", "text": "To wanting to run?"},
				{"speaker": "Brother Alden", "text": "To being human before being useful. If you reverse the order too long, the work hollows you out."},
				{"speaker": "Tamsin", "text": "...Did that happen to you?"},
				{"speaker": "Brother Alden", "text": "Near enough that I know the road by smell now."},
				{"speaker": "Tamsin", "text": "...Then keep talking to me before I wander onto it."}
			]
		},
		{
			"text": "You still did the work.",
			"result": "fail",
			"response": [
				{"speaker": "Tamsin", "text": "Yes. But it felt ugly."},
				{"speaker": "Brother Alden", "text": "Most honest work in war does."},
				{"speaker": "Tamsin", "text": "That is not helping."},
				{"speaker": "Brother Alden", "text": "No. But perhaps it will stop you mistaking ugliness for failure."}
			]
		}
	]
},
"BrotherAlden_Tamsin_Rank3": {
	"req_level": 14,
	"script": [
		{"speaker": "Brother Alden", "text": "You've organized the infirmary twice since Dawnkeep and are pretending that is a normal response to betrayal."},
		{"speaker": "Tamsin", "text": "It is a very practical response to betrayal."},
		{"speaker": "Brother Alden", "text": "So is vomiting. We each have our talents."},
		{"speaker": "Tamsin", "text": "...That was awful."},
		{"speaker": "Brother Alden", "text": "And yet it made you laugh."},
		{"speaker": "Tamsin", "text": "Only because otherwise I might start crying over supply ledgers."},
		{"speaker": "Brother Alden", "text": "The keep shook more than the walls, didn't it?"},
		{"speaker": "Tamsin", "text": "Yes. I keep thinking that if even truth can be rationed by people we trust, then what exactly are we building toward?"},
		{"speaker": "Brother Alden", "text": "A fair question. A dangerous one, too."},
		{"speaker": "Tamsin", "text": "Do you have an answer, or just another beautiful warning?"}
	],
	"branch_at": 9,
	"choices": [
		{
			"text": "He has an answer.",
			"result": "success",
			"response": [
				{"speaker": "Brother Alden", "text": "A small one. We build toward the people who still ask that question instead of surrendering to the lie."},
				{"speaker": "Tamsin", "text": "...That's all?"},
				{"speaker": "Brother Alden", "text": "Often that's all faith ever was: choosing who you will keep tending when certainty rots."},
				{"speaker": "Tamsin", "text": "You make care sound like doctrine."},
				{"speaker": "Brother Alden", "text": "Done properly, it is."},
				{"speaker": "Tamsin", "text": "...Then if we survive the Spire, I want to keep doing this. Not just patching bodies. Keeping people whole where I can."},
				{"speaker": "Brother Alden", "text": "Good. Then the world after this may yet deserve you."}
			]
		},
		{
			"text": "Maybe there is no answer.",
			"result": "fail",
			"response": [
				{"speaker": "Brother Alden", "text": "There is always an answer. It is merely smaller than frightened people prefer."},
				{"speaker": "Tamsin", "text": "You and your small answers."},
				{"speaker": "Brother Alden", "text": "Small answers have kept more souls alive than grand ones in my experience."},
				{"speaker": "Tamsin", "text": "...I hate that you're probably right."}
			]
		}
	]
},
"GarrickVale_VeskaMoor_Rank1": {
	"req_level": 14,
	"script": [
		{"speaker": "Garrick Vale", "text": "Your shield line at Dawnkeep held longer than the stone did."},
		{"speaker": "Veska Moor", "text": "Stone was decorative. I wasn't."},
		{"speaker": "Garrick Vale", "text": "...Concise."},
		{"speaker": "Veska Moor", "text": "You looked offended by how the outer gate was being defended."},
		{"speaker": "Garrick Vale", "text": "Not offended. Corrective by instinct, perhaps."},
		{"speaker": "Veska Moor", "text": "There's the officer in you. Always hearing formations go wrong before he sees them."},
		{"speaker": "Garrick Vale", "text": "And there's the veteran in you. Knowing when formations matter less than stubborn weight and timing."},
		{"speaker": "Veska Moor", "text": "...You learn fast."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "You respect each other.",
			"result": "success",
			"response": [
				{"speaker": "Garrick Vale", "text": "I respect soldiers who understand holding ground is more than looking proper in armor."},
				{"speaker": "Veska Moor", "text": "And I respect officers who notice the difference."},
				{"speaker": "Garrick Vale", "text": "A rare alignment."},
				{"speaker": "Veska Moor", "text": "Do not get precious. It is only the first one."},
				{"speaker": "Garrick Vale", "text": "...Fair enough."}
			]
		},
		{
			"text": "You're both severe.",
			"result": "fail",
			"response": [
				{"speaker": "Veska Moor", "text": "Severity keeps walls standing."},
				{"speaker": "Garrick Vale", "text": "And armies fed, if applied correctly."},
				{"speaker": "Veska Moor", "text": "So long as it isn't mistaken for vanity."},
				{"speaker": "Garrick Vale", "text": "On that, we agree."}
			]
		}
	]
},
"GarrickVale_VeskaMoor_Rank2": {
	"req_level": 15,
	"script": [
		{"speaker": "Veska Moor", "text": "The Marsh slowed your cavalry instincts."},
		{"speaker": "Garrick Vale", "text": "That obvious?"},
		{"speaker": "Veska Moor", "text": "To anyone who's watched mounted officers learn mud is a political equalizer, yes."},
		{"speaker": "Garrick Vale", "text": "...Harsh."},
		{"speaker": "Veska Moor", "text": "Accurate."},
		{"speaker": "Garrick Vale", "text": "The swamp punished lines, momentum, and visibility all at once. It was a lesson in humility."},
		{"speaker": "Veska Moor", "text": "Good. Marshes are excellent teachers when cliffs aren't available."},
		{"speaker": "Garrick Vale", "text": "And what did it teach you?"},
		{"speaker": "Veska Moor", "text": "That your instinct is still to protect the shape of the army. Mine is to protect the people inside it. Both matter. One matters first."}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "She has a point.",
			"result": "success",
			"response": [
				{"speaker": "Garrick Vale", "text": "...Aye. She does."},
				{"speaker": "Garrick Vale", "text": "I was raised to think discipline preserved lives. Sometimes it does. Sometimes it only preserves appearances."},
				{"speaker": "Veska Moor", "text": "Good. Keep separating the two."},
				{"speaker": "Garrick Vale", "text": "You make instruction sound like a weather report."},
				{"speaker": "Veska Moor", "text": "And you make correction sound noble. We all have our flaws."},
				{"speaker": "Garrick Vale", "text": "...That was very nearly humor."}
			]
		},
		{
			"text": "Shape matters too.",
			"result": "fail",
			"response": [
				{"speaker": "Garrick Vale", "text": "It does."},
				{"speaker": "Veska Moor", "text": "After people. Never before."},
				{"speaker": "Garrick Vale", "text": "...Yes. That is the part I'm still unlearning."},
				{"speaker": "Veska Moor", "text": "Then unlearn faster. The Spire won't wait for your philosophy to catch up."}
			]
		}
	]
},
"GarrickVale_VeskaMoor_Rank3": {
	"req_level": 17,
	"script": [
		{"speaker": "Garrick Vale", "text": "You spent the coalition talks outside the main pavilion."},
		{"speaker": "Veska Moor", "text": "That's where the soldiers were. Tents don't win wars. Feet do."},
		{"speaker": "Garrick Vale", "text": "You don't care for commanders much, do you?"},
		{"speaker": "Veska Moor", "text": "I care for the kind who remember they are made of the same flesh as their lines. The rest are weather."},
		{"speaker": "Garrick Vale", "text": "...That is a severe standard."},
		{"speaker": "Veska Moor", "text": "It keeps me from admiring uniforms too easily."},
		{"speaker": "Garrick Vale", "text": "Fair."},
		{"speaker": "Veska Moor", "text": "And you? You stood in there listening to kings, merchants, and clergy arrange one another politely. Why?"},
		{"speaker": "Garrick Vale", "text": "Because someone had to see whether anything honorable could still be salvaged from the posture."},
		{"speaker": "Veska Moor", "text": "...And can it?"}
	],
	"branch_at": 9,
	"choices": [
		{
			"text": "Tell her honestly.",
			"result": "success",
			"response": [
				{"speaker": "Garrick Vale", "text": "Not from posture alone. Only from people willing to strip it away and still stand beside one another after."},
				{"speaker": "Veska Moor", "text": "...Good answer."},
				{"speaker": "Garrick Vale", "text": "High praise, from you."},
				{"speaker": "Veska Moor", "text": "Don't grow vain."},
				{"speaker": "Garrick Vale", "text": "Wouldn't dare."},
				{"speaker": "Veska Moor", "text": "If we survive the Spire, keep that answer. Armies after disasters need fewer banners and more people who know the difference between order and vanity."},
				{"speaker": "Garrick Vale", "text": "...Then perhaps I shall have earned your respect fully by then."},
				{"speaker": "Veska Moor", "text": "Perhaps. Keep working."}
			]
		},
		{
			"text": "Honor survives in people.",
			"result": "fail",
			"response": [
				{"speaker": "Veska Moor", "text": "Sometimes. If they're stubborn."},
				{"speaker": "Garrick Vale", "text": "And if they are not?"},
				{"speaker": "Veska Moor", "text": "Then people like us have to be."},
				{"speaker": "Garrick Vale", "text": "...A grim comfort."},
				{"speaker": "Veska Moor", "text": "Still comfort."}
			]
		}
	]
},
"Rufus_SabineVarr_Rank1": {
	"req_level": 11,
	"script": [
		{"speaker": "Sabine Varr", "text": "You repositioned twice during the festival before I gave the signal."},
		{"speaker": "Rufus", "text": "Crowd was leaning wrong. Too much space opening near the west awning. Felt like something ugly wanted through."},
		{"speaker": "Sabine Varr", "text": "Good eye."},
		{"speaker": "Rufus", "text": "...You're Sabine, right? The one who speaks like every sentence passed inspection."},
		{"speaker": "Sabine Varr", "text": "And you're Rufus. The one who somehow makes street instincts sound like a trade profession."},
		{"speaker": "Rufus", "text": "Dock work, actually. Streets just charge less rent."},
		{"speaker": "Sabine Varr", "text": "...That was almost clever."},
		{"speaker": "Rufus", "text": "Almost? Cruel."}
	],
	"branch_at": 7,
	"choices": [
		{
			"text": "She meant it.",
			"result": "success",
			"response": [
				{"speaker": "Rufus", "text": "You really think so?"},
				{"speaker": "Sabine Varr", "text": "Do not make me repeat myself. It cheapens the first version."},
				{"speaker": "Rufus", "text": "...Right. Noted."},
				{"speaker": "Sabine Varr", "text": "Your sense for panic vectors is useful. Refine it, and you'll become difficult to surprise."},
				{"speaker": "Rufus", "text": "That sounded suspiciously like mentoring."},
				{"speaker": "Sabine Varr", "text": "Try not to embarrass us both by naming it."}
			]
		},
		{
			"text": "You both sound mean.",
			"result": "fail",
			"response": [
				{"speaker": "Rufus", "text": "Oh, she's definitely mean. I'm still deciding whether I admire it."},
				{"speaker": "Sabine Varr", "text": "And yet you're still here."},
				{"speaker": "Rufus", "text": "Yeah. Funny how that works."},
				{"speaker": "Sabine Varr", "text": "Indeed."}
			]
		}
	]
},
"Rufus_SabineVarr_Rank2": {
	"req_level": 13,
	"script": [
		{"speaker": "Rufus", "text": "You hated the Black Coast."},
		{"speaker": "Sabine Varr", "text": "I hate operations that require elegance from weather."},
		{"speaker": "Rufus", "text": "Heh. That's one way to say 'sea fort in a storm was terrible.'"},
		{"speaker": "Sabine Varr", "text": "Precision matters."},
		{"speaker": "Rufus", "text": "Yeah. So does not drowning."},
		{"speaker": "Sabine Varr", "text": "...Fair."},
		{"speaker": "Rufus", "text": "You know, when the rain hit, I kept listening for your calls. Not because they were loud. Because they were clean."},
		{"speaker": "Sabine Varr", "text": "That is called discipline."},
		{"speaker": "Rufus", "text": "Maybe. Where I come from, it's called trusting someone to keep their head while the rest of the dock loses theirs."}
	],
	"branch_at": 8,
	"choices": [
		{
			"text": "That matters to him.",
			"result": "success",
			"response": [
				{"speaker": "Sabine Varr", "text": "...I know it does."},
				{"speaker": "Rufus", "text": "You say that like it's heavier than a compliment."},
				{"speaker": "Sabine Varr", "text": "It is. Reliability is a much more intimate thing."},
				{"speaker": "Rufus", "text": "...All right. That's a line worth keeping."},
				{"speaker": "Sabine Varr", "text": "Then keep it quietly."},
				{"speaker": "Rufus", "text": "No promises. It's one of the nicer things anyone's said to me lately."}
			]
		},
		{
			"text": "You're useful together.",
			"result": "fail",
			"response": [
				{"speaker": "Rufus", "text": "Useful is underselling it, Commander."},
				{"speaker": "Sabine Varr", "text": "Do not preen."},
				{"speaker": "Rufus", "text": "Too late. The sea already failed to drown me. I feel magnificent."},
				{"speaker": "Sabine Varr", "text": "...Appalling."}
			]
		}
	]
},
"Rufus_SabineVarr_Rank3": {
	"req_level": 17,
	"script": [
		{"speaker": "Sabine Varr", "text": "You were angrier than usual in the coalition camp."},
		{"speaker": "Rufus", "text": "Was it that obvious?"},
		{"speaker": "Sabine Varr", "text": "To anyone with eyes."},
		{"speaker": "Rufus", "text": "Right. Well. Hard not to be, listening to polished folk discuss survival like it's a commodity class."},
		{"speaker": "Sabine Varr", "text": "And yet you held your tongue."},
		{"speaker": "Rufus", "text": "Mostly because if I opened my mouth, I'd have started with 'I've unloaded grain in storms with more honesty than this entire tent.'"},
		{"speaker": "Sabine Varr", "text": "...That would have been memorable."},
		{"speaker": "Rufus", "text": "You mean career-ending."},
		{"speaker": "Sabine Varr", "text": "Sometimes the two are cousins."},
		{"speaker": "Rufus", "text": "...You know what's funny? I kept wanting to look over and see what your face was doing every time one of them said something rotten. Like if you looked disgusted too, I could bear the room better."}
	],
	"branch_at": 9,
	"choices": [
		{
			"text": "Tell her that.",
			"result": "success",
			"response": [
				{"speaker": "Rufus", "text": "There. That's the truth of it."},
				{"speaker": "Sabine Varr", "text": "...I see."},
				{"speaker": "Rufus", "text": "Sorry. Too much?"},
				{"speaker": "Sabine Varr", "text": "No. Merely rarer than I expected from you."},
				{"speaker": "Rufus", "text": "I can go back to jokes if you prefer."},
				{"speaker": "Sabine Varr", "text": "Don't. Not this time."},
				{"speaker": "Sabine Varr", "text": "For what it is worth, I looked for you too. You remind me that anger can still belong to decent men, not just ambitious ones."},
				{"speaker": "Rufus", "text": "...Gods. That's the sort of sentence a man keeps."},
				{"speaker": "Sabine Varr", "text": "Then do not waste it."}
			]
		},
		{
			"text": "Keep it light.",
			"result": "fail",
			"response": [
				{"speaker": "Rufus", "text": "Never mind. Forget it. Just thought the tent needed better company, that's all."},
				{"speaker": "Sabine Varr", "text": "...Coward."},
				{"speaker": "Rufus", "text": "Harsh."},
				{"speaker": "Sabine Varr", "text": "Accurate. Try again another time, when the world is less convenient an excuse."},
				{"speaker": "Rufus", "text": "...All right. Fair enough."}
			]
		}
	]
}
}
# ============================================================================
# ===================== END SUPPORT DATABASE PASTE AREA ======================
# ============================================================================


func _ready() -> void:
	if tavern_music and not tavern_music.playing:
		tavern_music.play()
	_ensure_dialogue_over_fx()
	_apply_grand_tavern_theme()
	select_sound = AudioStreamPlayer.new()
	blip_sound = AudioStreamPlayer.new()
	add_child(select_sound)
	add_child(blip_sound)
	if seraphina_portrait != null and not seraphina_portrait.pressed.is_connected(_on_seraphina_portrait_pressed):
		seraphina_portrait.pressed.connect(_on_seraphina_portrait_pressed)
	if seraphina_controller != null:
		if not seraphina_controller.dialogue_started.is_connected(_on_seraphina_dialogue_started):
			seraphina_controller.dialogue_started.connect(_on_seraphina_dialogue_started)
		if not seraphina_controller.dialogue_finished.is_connected(_on_seraphina_dialogue_finished):
			seraphina_controller.dialogue_finished.connect(_on_seraphina_dialogue_finished)
	leave_btn.pressed.connect(_on_leave_pressed)
	next_btn.pressed.connect(_advance_dialogue)

	dialogue_panel.hide()
	choice_container.hide()
	_set_dialogue_modal_blocker(false)
	_populate_tavern_roster()


func _make_panel_style(bg: Color, border: Color, radius: int = 18, border_px: int = 2, pad_h: int = 14, pad_v: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_px
	sb.border_width_top = border_px
	sb.border_width_right = border_px
	sb.border_width_bottom = border_px
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_right = radius
	sb.corner_radius_bottom_left = radius
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


func _make_button_style(bg: Color, border: Color, radius: int = 14, border_px: int = 2, pad_h: int = 14, pad_v: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_px
	sb.border_width_top = border_px
	sb.border_width_right = border_px
	sb.border_width_bottom = border_px
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_right = radius
	sb.corner_radius_bottom_left = radius
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


func _style_button(btn: Button, font_size: int = 26) -> void:
	if btn == null:
		return
	btn.add_theme_stylebox_override("normal", _make_button_style(TAVERN_BUTTON_BG, TAVERN_BORDER_SOFT))
	btn.add_theme_stylebox_override("hover", _make_button_style(TAVERN_BUTTON_HOVER, TAVERN_BORDER))
	btn.add_theme_stylebox_override("pressed", _make_button_style(TAVERN_BUTTON_PRESSED, TAVERN_BORDER))
	btn.add_theme_stylebox_override("focus", _make_button_style(TAVERN_BUTTON_HOVER, TAVERN_BORDER))
	btn.add_theme_stylebox_override("disabled", _make_button_style(Color(0.20, 0.20, 0.20, 0.9), Color(0.36, 0.36, 0.36, 0.9)))
	btn.add_theme_color_override("font_color", TAVERN_TEXT)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.78, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.93, 0.70, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.62, 0.62, 0.62, 1.0))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("outline_size", 4)
	btn.add_theme_font_size_override("font_size", font_size)


func _apply_grand_tavern_theme() -> void:
	# Main dialogue shell
	if dialogue_panel is Panel:
		var panel := dialogue_panel as Panel
		panel.add_theme_stylebox_override("panel", _make_panel_style(TAVERN_PANEL_BG, TAVERN_BORDER, 20, 2, 18, 14))

	if dialogue_text != null:
		dialogue_text.add_theme_stylebox_override("normal", _make_panel_style(TAVERN_PANEL_BG_ALT, TAVERN_BORDER_SOFT, 14, 1, 18, 12))
		dialogue_text.add_theme_color_override("default_color", TAVERN_TEXT)
		dialogue_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
		dialogue_text.add_theme_constant_override("outline_size", 4)
		dialogue_text.add_theme_font_size_override("normal_font_size", 34)

	if speaker_name != null:
		speaker_name.add_theme_color_override("font_color", Color(1.0, 0.93, 0.64, 1.0))
		speaker_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		speaker_name.add_theme_constant_override("outline_size", 4)
		speaker_name.add_theme_font_size_override("font_size", 34)

	if choice_container is VBoxContainer:
		(choice_container as VBoxContainer).add_theme_constant_override("separation", 10)

	_style_button(next_btn, 30)
	_style_button(choice_btn_1, 30)
	_style_button(choice_btn_2, 30)
	_style_button(choice_btn_3, 30)
	_style_button(choice_btn_4, 30)
	for btn in get_choice_buttons():
		if btn != null:
			btn.custom_minimum_size = Vector2(1200, 66)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Top-right utility and side controls
	_style_button(leave_btn, 34)
	_style_button(notice_board_btn, 22)
	_style_button(cartographer_btn, 22)
	_style_button(gambler_btn, 22)
	_style_button(chat_send_btn, 20)

	if chat_panel != null:
		chat_panel.add_theme_stylebox_override("panel", _make_panel_style(TAVERN_PANEL_BG, TAVERN_BORDER_SOFT, 16, 2, 12, 10))

	if chat_input != null:
		chat_input.add_theme_stylebox_override("normal", _make_panel_style(TAVERN_PANEL_BG_ALT, TAVERN_BORDER_SOFT, 10, 1, 10, 7))
		chat_input.add_theme_stylebox_override("focus", _make_panel_style(TAVERN_PANEL_BG_ALT, TAVERN_BORDER, 10, 2, 10, 7))
		chat_input.add_theme_color_override("font_color", TAVERN_TEXT)
		chat_input.add_theme_color_override("font_placeholder_color", TAVERN_TEXT_MUTED)
		chat_input.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		chat_input.add_theme_constant_override("outline_size", 3)
		chat_input.add_theme_font_size_override("font_size", 20)

	if roster_scroll != null:
		roster_scroll.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.03, 0.03, 0.56), TAVERN_BORDER_SOFT, 12, 1, 8, 8))


func _ensure_dialogue_over_fx() -> void:
	# Keep tavern VFX visible while guaranteeing dialogue choices/text are always
	# rendered above particle and glow CanvasLayers.
	if dialogue_panel == null:
		return

	var current_parent := dialogue_panel.get_parent()
	if current_parent is CanvasLayer and (current_parent as CanvasLayer).layer >= 20:
		_dialogue_overlay_layer = current_parent
		_ensure_dialogue_input_blocker()
		return

	var overlay := CanvasLayer.new()
	overlay.name = "DialogueOverlay"
	overlay.layer = 20
	add_child(overlay)
	move_child(overlay, get_child_count() - 1)

	if current_parent != null:
		current_parent.remove_child(dialogue_panel)
	overlay.add_child(dialogue_panel)
	_dialogue_overlay_layer = overlay
	_ensure_dialogue_input_blocker()


func _ensure_dialogue_input_blocker() -> void:
	if _dialogue_overlay_layer == null:
		return

	var existing := _dialogue_overlay_layer.get_node_or_null("DialogueInputBlocker")
	if existing is ColorRect:
		_dialogue_input_blocker = existing
	else:
		var blocker := ColorRect.new()
		blocker.name = "DialogueInputBlocker"
		blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
		blocker.offset_left = 0.0
		blocker.offset_top = 0.0
		blocker.offset_right = 0.0
		blocker.offset_bottom = 0.0
		blocker.color = Color(0.03, 0.02, 0.01, 0.33)
		blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		_dialogue_overlay_layer.add_child(blocker)
		_dialogue_overlay_layer.move_child(blocker, 0)
		_dialogue_input_blocker = blocker

	# Keep the interactive dialogue panel above the blocker.
	dialogue_panel.z_as_relative = false
	dialogue_panel.z_index = 10
	_set_dialogue_modal_blocker(false)


func _set_dialogue_modal_blocker(active: bool) -> void:
	if _dialogue_input_blocker == null:
		return
	_dialogue_input_blocker.color = Color(0.005, 0.004, 0.003, 0.90) if _seraphina_dialogue_active else Color(0.03, 0.02, 0.01, 0.50)
	_dialogue_input_blocker.visible = active


func _on_seraphina_dialogue_started(_node_id: String) -> void:
	_seraphina_dialogue_active = true
	_assign_seraphina_to_left_portrait()
	_apply_seraphina_choice_layout()
	_set_dialogue_modal_blocker(true)


func _on_seraphina_dialogue_finished(_last_node_id: String) -> void:
	_seraphina_dialogue_active = false
	_set_dialogue_modal_blocker(false)
	_restore_default_choice_layout()
	_restore_left_portrait_layout()
	# Restore neutral portrait visibility state after Seraphina closes.
	if right_portrait != null:
		right_portrait.visible = true


func _assign_seraphina_to_left_portrait() -> void:
	if left_portrait == null:
		return

	if not _seraphina_portrait_layout_captured:
		_left_portrait_default_offset_top = left_portrait.offset_top
		_left_portrait_default_offset_bottom = left_portrait.offset_bottom
		_seraphina_portrait_layout_captured = true

	var seraphina_tex: Texture2D = null
	if seraphina_portrait != null:
		seraphina_tex = seraphina_portrait.texture_normal

	if seraphina_tex != null:
		left_portrait.texture = seraphina_tex
	# Sit slightly lower so it overlaps the dialogue panel more naturally.
	left_portrait.offset_top = _left_portrait_default_offset_top + 28.0
	left_portrait.offset_bottom = _left_portrait_default_offset_bottom + 28.0
	left_portrait.modulate = Color.WHITE
	left_portrait.visible = true

	if right_portrait != null:
		right_portrait.texture = null
		right_portrait.visible = false


func _restore_left_portrait_layout() -> void:
	if not _seraphina_portrait_layout_captured:
		return
	if left_portrait == null:
		return
	left_portrait.offset_top = _left_portrait_default_offset_top
	left_portrait.offset_bottom = _left_portrait_default_offset_bottom


func _capture_default_choice_layout_once() -> void:
	if _choice_layout_defaults_captured:
		return
	if choice_container == null:
		return

	_choice_container_default_offset_left = choice_container.offset_left
	_choice_container_default_offset_right = choice_container.offset_right
	_choice_container_default_offset_top = choice_container.offset_top
	_choice_container_default_offset_bottom = choice_container.offset_bottom

	if choice_btn_1 != null:
		_choice_btn_default_min_size = choice_btn_1.custom_minimum_size
		_choice_btn_default_font_size = int(choice_btn_1.get_theme_font_size("font_size"))

	_choice_layout_defaults_captured = true


func _apply_seraphina_choice_layout() -> void:
	_capture_default_choice_layout_once()
	if choice_container == null:
		return

	# Shift choices right to preserve the left portrait readability.
	choice_container.offset_left = _choice_container_default_offset_left + 190.0
	choice_container.offset_right = _choice_container_default_offset_right + 190.0

	for btn in get_choice_buttons():
		if btn == null:
			continue
		btn.custom_minimum_size = Vector2(900, 56)
		btn.add_theme_font_size_override("font_size", 24)


func _restore_default_choice_layout() -> void:
	if not _choice_layout_defaults_captured:
		return
	if choice_container != null:
		choice_container.offset_left = _choice_container_default_offset_left
		choice_container.offset_right = _choice_container_default_offset_right
		choice_container.offset_top = _choice_container_default_offset_top
		choice_container.offset_bottom = _choice_container_default_offset_bottom

	for btn in get_choice_buttons():
		if btn == null:
			continue
		btn.custom_minimum_size = _choice_btn_default_min_size
		btn.add_theme_font_size_override("font_size", _choice_btn_default_font_size)


func _on_leave_pressed() -> void:
	CampaignManager.save_current_progress()
	
	SceneTransition.change_scene_to_file("res://Scenes/CityMenu.tscn")


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _is_avatar_unit(unit: Dictionary) -> bool:
	if unit.get("is_avatar", false):
		return true
	if CampaignManager.player_roster.size() > 0 and unit == CampaignManager.player_roster[0]:
		return true
	return false


func _sanitize_support_name(support_name: String) -> String:
	return support_name.replace(" ", "").replace("'", "").replace("-", "")


func _support_token_from_unit(unit: Dictionary) -> String:
	if unit.is_empty():
		return ""
	if _is_avatar_unit(unit):
		return "Avatar"
	return _sanitize_support_name(String(unit.get("unit_name", "")))


func _find_unit_by_support_token(token: String) -> Dictionary:
	if token == "Avatar" and CampaignManager.player_roster.size() > 0:
		return CampaignManager.player_roster[0]

	for unit in CampaignManager.player_roster:
		if _support_token_from_unit(unit) == token:
			return unit

	return {}


func _get_next_support_rank(points: int, rank: int) -> int:
	if rank == 0 and points >= 5:
		return 1
	if rank == 1 and points >= 10:
		return 2
	if rank == 2 and points >= 15:
		return 3
	return 0


func _speaker_matches_character(speaker: String, unit: Dictionary) -> bool:
	if unit.is_empty():
		return false

	var unit_name := String(unit.get("unit_name", ""))
	if speaker == unit_name:
		return true

	if _is_avatar_unit(unit) and (speaker == "Commander" or speaker == "Avatar"):
		return true

	return _sanitize_support_name(speaker) == _support_token_from_unit(unit)


func _get_display_speaker_name(raw_speaker: String) -> String:
	if raw_speaker == "Commander" or raw_speaker == "Avatar":
		if not active_character_a.is_empty() and _is_avatar_unit(active_character_a):
			return String(active_character_a.get("unit_name", "Commander"))
		if not active_character_b.is_empty() and _is_avatar_unit(active_character_b):
			return String(active_character_b.get("unit_name", "Commander"))
	return raw_speaker


func _get_unit_portrait(unit: Dictionary) -> Texture2D:
	var p_tex = unit.get("portrait", null)
	if p_tex is Texture2D:
		return p_tex

	var data_res = unit.get("data", null)
	if data_res is Resource:
		var portrait = data_res.get("portrait")
		if portrait is Texture2D:
			return portrait

	return null


func _disconnect_all_pressed(button: BaseButton) -> void:
	if button == null:
		return

	var connections := button.get_signal_connection_list("pressed")
	for connection in connections:
		if connection.has("callable"):
			var callable: Callable = connection["callable"]
			if button.pressed.is_connected(callable):
				button.pressed.disconnect(callable)

# ==============================================================================
# Function Name: _get_pending_support_for
# Purpose: Determines if a given unit has any valid, unviewed support conversations 
#          available based on current bond points, database existence, and campaign progression.
# Inputs: 
#   - unit (Dictionary): The character data dictionary from the player's roster.
# Outputs: 
#   - Dictionary: Returns a dictionary containing the bond_key, partner unit data, 
#     and target_rank if a support is pending. Returns an empty dictionary {} if none are available.
# Side Effects: None. Read-only function.
# AI/Code Reviewer Guidance:
#   - Core Logic: Iterates through CampaignManager.support_bonds to find point thresholds.
#   - Fix Applied: Added strict validation to ensure the lookup_key exists in support_database 
#     before triggering the UI alert, preventing generic fallback text from ranking up units.
# ==============================================================================
func _get_pending_support_for(unit: Dictionary) -> Dictionary:
	var my_token := _support_token_from_unit(unit)

	for bond_key in CampaignManager.support_bonds.keys():
		var key_str := String(bond_key)
		var parts: PackedStringArray = CampaignManager.parse_relationship_key(key_str)
		if parts.size() < 2:
			continue
		if my_token != parts[0] and my_token != parts[1]:
			continue
		var data := CampaignManager.get_support_bond(parts[0], parts[1])
		var pts := int(data.get("points", 0))
		var rank := int(data.get("rank", 0))
		
		# Determine if enough points have been accumulated for the next tier
		var next_rank := _get_next_support_rank(pts, rank)

		# If next_rank is 0, they have not met the point threshold, or they are at the max rank cap
		if next_rank == 0:
			continue

		var lookup_key := key_str + "_Rank" + str(next_rank)
		
		# --- FIX: STRICT DATABASE VALIDATION ---
		# Abort if the dialogue entry does not exist in the database.
		# This prevents unwritten bonds from triggering the generic fallback dialogue and ranking up.
		if not support_database.has(lookup_key):
			continue
			
		var req_level := int(support_database[lookup_key].get("req_level", 0))

		# Verify the player has progressed far enough in the campaign to view this specific dialogue
		if CampaignManager.max_unlocked_index < req_level:
			continue

		# Identify the partner unit from the roster using the opposite token
		var partner_token := parts[1] if parts[0] == my_token else parts[0]
		var partner_unit := _find_unit_by_support_token(partner_token)

		if not partner_unit.is_empty():
			return {
				"bond_key": key_str,
				"partner": partner_unit,
				"target_rank": next_rank
			}

	return {}

# ============================================================================
# 1. BUILD THE INTERACTIVE ROSTER GRID
# ============================================================================

# ==============================================================================
# Function Name: _populate_tavern_roster
# Purpose: Builds the interactive grid of character portraits for the tavern.
# Inputs: None.
# Outputs: None.
# Side Effects: Clears and instantiates Button nodes inside tavern_grid.
# AI/Code Reviewer Guidance:
#   - Entry Point: Called on _ready and after a conversation ends.
#   - Core Logic: Instantiates buttons, applies portraits, checks for pending 
#     supports to add alert icons, and now assigns dynamic progression tooltips.
# ==============================================================================
func _populate_tavern_roster() -> void:
	for child in tavern_grid.get_children():
		child.queue_free()

	var roster = CampaignManager.player_roster

	for unit in roster:
		if unit.get("is_dragon", false):
			continue
		if not unit.has("unit_name"):
			continue

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(100, 100)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var p_tex := _get_unit_portrait(unit)
		if p_tex != null:
			btn.icon = p_tex
			btn.expand_icon = true
		else:
			btn.text = str(unit["unit_name"]).substr(0, 4)

		# --- NEW: ASSIGN PROGRESSION TOOLTIP ---
		btn.tooltip_text = _build_support_tooltip(unit)

		var pending := _get_pending_support_for(unit)
		var has_pending_support := not pending.is_empty()

		if has_pending_support:
			var alert_lbl := Label.new()
			alert_lbl.text = "!"
			alert_lbl.add_theme_font_size_override("font_size", 32)
			alert_lbl.add_theme_color_override("font_color", Color.YELLOW)
			alert_lbl.add_theme_constant_override("outline_size", 6)
			alert_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			btn.add_child(alert_lbl)
			alert_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)

			var pulse := create_tween().set_loops(9999)
			pulse.tween_property(alert_lbl, "scale", Vector2(1.2, 1.2), 0.5)
			pulse.tween_property(alert_lbl, "scale", Vector2(1.0, 1.0), 0.5)

		btn.pressed.connect(_on_character_clicked.bind(unit))
		tavern_grid.add_child(btn)

# ============================================================================
# 2. LOGIC: FINDING SUPPORT PARTNERS
# ============================================================================

func _on_character_clicked(unit: Dictionary) -> void:
	if select_sound.stream != null:
		select_sound.play()

	var pending := _get_pending_support_for(unit)

	if not pending.is_empty():
		_start_support_conversation(
			unit,
			pending["partner"],
			String(pending["bond_key"]),
			int(pending["target_rank"])
		)
	else:
		_play_idle_bark(unit)


# ============================================================================
# 3.5. IDLE TAVERN CHATTER
# ============================================================================

func _play_idle_bark(char_a: Dictionary) -> void:
	active_character_a = char_a
	active_character_b = {}
	active_bond_key = ""
	current_lookup_key = ""
	branch_resolved = false

	left_portrait.texture = _get_unit_portrait(char_a)
	right_portrait.texture = null

	var barks = [
		"The ale here tastes like rusted iron. I'll take two.",
		"Rest while you can. Tomorrow we bleed.",
		"My gear is maintained and ready. Just give the order.",
		"A tavern is just a battlefield where no one has drawn steel yet.",
		"Are you paying for my tab? Excellent."
	]

	current_dialogue_sequence = [
		{"speaker": char_a["unit_name"], "text": barks[randi() % barks.size()]}
	]

	current_dialogue_index = 0
	dialogue_panel.show()
	choice_container.hide()
	_set_dialogue_modal_blocker(true)
	next_btn.show()
	_advance_dialogue()
	# Refresh tavern roster UI after bark/dialogue start.
	_populate_tavern_roster()


# ============================================================================
# 3. THE DIALOGUE SYSTEM
# ============================================================================

func _start_support_conversation(char_a: Dictionary, char_b: Dictionary, bond_key: String, target_rank: int) -> void:
	active_character_a = char_a
	active_character_b = char_b
	active_bond_key = bond_key
	current_lookup_key = bond_key + "_Rank" + str(target_rank)
	branch_resolved = false
	is_waiting_for_choice = false

	left_portrait.texture = _get_unit_portrait(char_a)
	right_portrait.texture = _get_unit_portrait(char_b)

	if support_database.has(current_lookup_key):
		var db_entry = support_database[current_lookup_key]
		current_dialogue_sequence = db_entry.get("script", []).duplicate(true)
	else:
		current_dialogue_sequence = [
			{"speaker": char_a["unit_name"], "text": "We make a good team out there."},
			{"speaker": char_b["unit_name"], "text": "Agreed. Let's keep watching each other's backs."}
		]

	current_dialogue_index = 0
	dialogue_panel.show()
	choice_container.hide()
	_set_dialogue_modal_blocker(true)
	next_btn.show()
	_advance_dialogue()


func _advance_dialogue() -> void:
	if is_waiting_for_choice:
		return

	# If the current line is still typing, first press finishes it instantly.
	if _is_text_typing():
		_finish_typing()
		return

	var data = support_database.get(current_lookup_key, null)

	# Show the choice AFTER the line at branch_at has already been displayed.
	if data and not branch_resolved and current_dialogue_index == int(data.get("branch_at", -999)) + 1:
		_show_choices(data["choices"])
		return

	if current_dialogue_index >= current_dialogue_sequence.size():
		_end_conversation()
		return

	var line: Dictionary = current_dialogue_sequence[current_dialogue_index]
	_display_line(line)
	current_dialogue_index += 1
	
# ==============================================================================
# Function Name: _display_line
# Purpose: Updates the dialogue UI with the current speaker and text while safely
#          executing visual polish animations.
# Inputs: line (Dictionary) - A dictionary containing "speaker" and "text" keys.
# Outputs: None.
# Side Effects: Kills active tweens on UI elements to prevent stacking. Resets 
#               scale, position, and modulate properties to baselines before 
#               applying new animations. Plays audio.
# AI/Code Reviewer Guidance:
#   - Entry Point: Called sequentially by _advance_dialogue().
#   - Core Logic Sections: Audio, Portrait State, Tween Cleanup, Animation Application.
#   - Important Fix: Captures _dialogue_base_pos once to prevent the panel from 
#     drifting off-screen when screen shake is interrupted by rapid inputs.
# ==============================================================================
func _display_line(line: Dictionary) -> void:
	dialogue_panel.show()
	_set_dialogue_modal_blocker(true)

	var final_speaker: String = _get_display_speaker_name(String(line["speaker"]))
	var final_text: String = str(line["text"])

	speaker_name.text = final_speaker
	
	# --- BASELINE CAPTURE ---
	if _dialogue_base_pos == Vector2(-1, -1):
		_dialogue_base_pos = dialogue_panel.position

	# --- 1. DYNAMIC AUDIO ---
	if blip_sound.stream != null:
		blip_sound.pitch_scale = randf_range(0.8, 1.2)
		blip_sound.play()

	# --- 2. PORTRAIT FOCUS ---
	var active_portrait = null

	if _seraphina_dialogue_active:
		# Keep Seraphina on the left portrait slot and hide the right side.
		_assign_seraphina_to_left_portrait()
		active_portrait = left_portrait
	
	if active_character_b.is_empty():
		left_portrait.modulate = Color.WHITE
		right_portrait.modulate = Color(0, 0, 0, 0)
		active_portrait = left_portrait
	else:
		if _speaker_matches_character(String(line["speaker"]), active_character_a):
			left_portrait.modulate = Color.WHITE
			right_portrait.modulate = Color(0.4, 0.4, 0.4)
			active_portrait = left_portrait
		elif _speaker_matches_character(String(line["speaker"]), active_character_b):
			left_portrait.modulate = Color(0.4, 0.4, 0.4)
			right_portrait.modulate = Color.WHITE
			active_portrait = right_portrait
		else:
			left_portrait.modulate = Color.WHITE
			right_portrait.modulate = Color.WHITE
			
	# --- 3. JUICE: BOUNCE & SLIDING NAMEPLATE ---
	if active_portrait != null:
		if _active_portrait_tween and _active_portrait_tween.is_valid():
			_active_portrait_tween.kill()
		
		active_portrait.scale = Vector2.ONE
		active_portrait.pivot_offset = active_portrait.size / 2.0
		
		_active_portrait_tween = create_tween()
		_active_portrait_tween.tween_property(active_portrait, "scale", Vector2(1.05, 1.05), 0.05).set_trans(Tween.TRANS_SINE)
		_active_portrait_tween.tween_property(active_portrait, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BOUNCE)

		if _active_name_tween and _active_name_tween.is_valid():
			_active_name_tween.kill()

		var target_name_x = active_portrait.position.x + (active_portrait.size.x / 2.0) - (speaker_name.size.x / 2.0)
		
		_active_name_tween = create_tween()
		_active_name_tween.tween_property(speaker_name, "position:x", target_name_x, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# --- 4. INTENSITY CHECK (Screen Shake & Flash) ---
	var is_intense = final_text.ends_with("!") or (final_text == final_text.to_upper() and final_text.length() > 5)
	
	if _active_shake_tween and _active_shake_tween.is_valid():
		_active_shake_tween.kill()
	
	# Always reset to baseline before applying shakes
	dialogue_panel.position = _dialogue_base_pos
	speaker_name.modulate = Color.WHITE
	
	if is_intense:
		_active_shake_tween = create_tween()
		for i in range(4):
			var offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
			_active_shake_tween.tween_property(dialogue_panel, "position", _dialogue_base_pos + offset, 0.03)
		_active_shake_tween.tween_property(dialogue_panel, "position", _dialogue_base_pos, 0.03)
		
		speaker_name.modulate = Color(1.5, 0.5, 0.5, 1.0)
		var c_tw = create_tween()
		c_tw.tween_property(speaker_name, "modulate", Color.WHITE, 0.3)
	else:
		if _active_text_tween and _active_text_tween.is_valid():
			_active_text_tween.kill()
			
		dialogue_text.pivot_offset = dialogue_text.size / 2.0
		dialogue_text.scale = Vector2(0.98, 0.98)
		
		_active_text_tween = create_tween()
		_active_text_tween.tween_property(dialogue_text, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# --- 5. TYPEWRITER ---
	_start_typewriter(final_text)


func _input(event: InputEvent) -> void:
	if not _seraphina_dialogue_active:
		return
	if dialogue_panel == null or not dialogue_panel.visible:
		return
	if choice_container != null and choice_container.visible:
		return
	if next_btn == null or not next_btn.visible:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not mb.is_echo():
			var click_pos := mb.position
			# If clicking the actual Next button, let that button process naturally.
			if next_btn.get_global_rect().has_point(click_pos):
				return

			# If choices are visible for any reason, do not hijack selection clicks.
			for btn in get_choice_buttons():
				if btn != null and btn.visible and btn.get_global_rect().has_point(click_pos):
					return

			next_btn.emit_signal("pressed")
			get_viewport().set_input_as_handled()
			
func _show_choices(choices: Array) -> void:
	is_waiting_for_choice = true
	choice_container.show()
	_set_dialogue_modal_blocker(true)
	next_btn.hide()

	var buttons := get_choice_buttons()

	for button in buttons:
		_disconnect_all_pressed(button)
		button.hide()
		button.disabled = false
		button.tooltip_text = ""
		button.modulate = Color(1, 1, 1, 1)

	var count := mini(choices.size(), buttons.size())

	for i in range(count):
		var button: Button = buttons[i]
		var choice_data: Dictionary = choices[i]

		button.text = str(choice_data.get("text", "Choice"))
		button.show()
		button.pressed.connect(_on_choice_selected.bind(choice_data), CONNECT_ONE_SHOT)

func _on_choice_selected(choice_data: Dictionary) -> void:
	if select_sound.stream != null:
		select_sound.play()

	choice_container.hide()
	next_btn.show()
	is_waiting_for_choice = false
	branch_resolved = true

	current_dialogue_sequence.append_array(choice_data.get("response", []))

	if choice_data.get("result", "success") == "fail":
		active_bond_key = "FAIL_" + active_bond_key

	_advance_dialogue()


# ==============================================================================
# Function Name: _end_conversation
# Purpose: Concludes the active dialogue, applies support point rewards or 
#          penalties based on choices, and saves campaign progress.
# Inputs: None (Relies on active_bond_key state).
# Outputs: None.
# Side Effects: Modifies CampaignManager.support_bonds, triggers save, 
#               refreshes the tavern roster UI.
# AI/Code Reviewer Guidance:
#   - Core Logic: Checks if active_bond_key contains the "FAIL_" prefix.
#   - Fix Applied: directly manipulates the support_bonds dictionary using 
#     the validated real_key to prevent Avatar naming mismatches.
# ==============================================================================
func _end_conversation() -> void:
	dialogue_panel.hide()
	_set_dialogue_modal_blocker(false)

	if active_bond_key.begins_with("FAIL_"):
		var real_key := active_bond_key.replace("FAIL_", "")
		
		# Directly penalize using the validated key instead of raw unit names
		if CampaignManager.support_bonds.has(real_key):
			CampaignManager.support_bonds[real_key]["points"] = max(0, CampaignManager.support_bonds[real_key]["points"] - 3)
		
		_show_system_message("The bond was weakened... (-3 Points)", Color.RED)
		
	elif active_bond_key != "":
		if CampaignManager.support_bonds.has(active_bond_key):
			CampaignManager.support_bonds[active_bond_key]["rank"] += 1
			CampaignManager.support_bonds[active_bond_key]["points"] = 0
			_show_system_message("Support Rank Increased", Color.GREEN)

	current_lookup_key = ""
	active_bond_key = ""
	branch_resolved = false
	is_waiting_for_choice = false

	CampaignManager.save_current_progress()
	_populate_tavern_roster()

# ============================================================================
# 4. FLOATING SYSTEM MESSAGE
# ============================================================================

func _show_system_message(msg: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)

	add_child(lbl)
	lbl.global_position = get_viewport_rect().size / 2.0 - Vector2(150, 0)

	var t = create_tween().set_parallel(true)
	t.tween_property(lbl, "position:y", lbl.position.y - 100, 2.0).set_ease(Tween.EASE_OUT)
	t.tween_property(lbl, "modulate:a", 0.0, 2.0).set_delay(1.0)
	t.chain().tween_callback(lbl.queue_free)

# ==============================================================================
# Function Name: _build_support_tooltip
# Purpose: Generates a multi-line string detailing all active support bonds 
#          and their exact point progression for a specific unit.
# Inputs: unit (Dictionary) - The character data dictionary.
# Outputs: String - A formatted tooltip text block.
# Side Effects: None. Read-only function.
# AI/Code Reviewer Guidance:
#   - Core Logic: Iterates through CampaignManager.support_bonds.
#   - Calculation: Determines the ceiling for the next rank based on current rank.
# ==============================================================================
func _build_support_tooltip(unit: Dictionary) -> String:
	var my_token := _support_token_from_unit(unit)
	var unit_name := String(unit.get("unit_name", "Unknown"))
	var tooltip := unit_name + " - Support Bonds:\n"
	var has_bonds := false

	for bond_key in CampaignManager.support_bonds.keys():
		var key_str := String(bond_key)
		var parts: PackedStringArray = CampaignManager.parse_relationship_key(key_str)
		if parts.size() < 2:
			continue
		if my_token == parts[0] or my_token == parts[1]:
			has_bonds = true
			var partner_token := parts[1] if parts[0] == my_token else parts[0]
			var data := CampaignManager.get_support_bond(parts[0], parts[1])
			var pts := int(data.get("points", 0))
			var rank := int(data.get("rank", 0))

			var progress_str := ""
			if rank == 0:
				progress_str = str(pts) + "/5 pts"
			elif rank == 1:
				progress_str = str(pts) + "/10 pts"
			elif rank == 2:
				progress_str = str(pts) + "/15 pts"
			else:
				progress_str = "MAX"

			tooltip += "  • " + partner_token + ": Rank " + str(rank) + " (" + progress_str + ")\n"

	if not has_bonds:
		tooltip += "  No active bonds."

	return tooltip
	
var _typewriter_tween: Tween = null
var _is_typing_line: bool = false
var _full_line_text: String = ""

@export_range(10.0, 200.0) var typewriter_characters_per_second: float = 55.0

func get_choice_buttons() -> Array:
	return [choice_btn_1, choice_btn_2, choice_btn_3, choice_btn_4]
	

func _hide_all_choice_buttons() -> void:
	for button in get_choice_buttons():
		if button == null:
			continue
		button.hide()
		button.disabled = false
		button.text = ""
		button.tooltip_text = ""
		button.modulate = Color(1, 1, 1, 1)

	choice_container.hide()
	
func _apply_choice_button_state(button: Button, choice_view_model: Dictionary) -> void:
	if button == null:
		return

	var is_locked: bool = bool(choice_view_model.get("__locked", false))
	var lock_reason: String = str(choice_view_model.get("__lock_reason", ""))

	button.text = str(choice_view_model.get("text", ""))
	button.tooltip_text = lock_reason

	# Keep locked buttons clickable so the manager can intercept the press
	# and show the lock reason. This also preserves tooltip hover behavior.
	button.disabled = false
	button.show()

	if is_locked:
		button.modulate = Color(0.84, 0.84, 0.84, 0.92)
		button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	else:
		button.modulate = Color(1, 1, 1, 1)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
func _on_seraphina_portrait_pressed() -> void:
	print("Seraphina portrait clicked")

	if seraphina_controller == null:
		push_warning("GrandTavern.gd: SeraphinaController not found.")
		return

	seraphina_controller.interact()



func _start_typewriter(text: String) -> void:
	if _typewriter_tween != null:
		_typewriter_tween.kill()
		_typewriter_tween = null

	_full_line_text = text
	_is_typing_line = true

	dialogue_text.text = text
	dialogue_text.visible_characters = 0

	var char_count: int = text.length()
	if char_count <= 0:
		_is_typing_line = false
		dialogue_text.visible_characters = -1
		return

	var duration: float = max(0.01, float(char_count) / typewriter_characters_per_second)

	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(dialogue_text, "visible_characters", char_count, duration)

	_typewriter_tween.finished.connect(
		func() -> void:
			_is_typing_line = false
			dialogue_text.visible_characters = -1
			_typewriter_tween = null,
		CONNECT_ONE_SHOT
	)


func _is_text_typing() -> bool:
	return _is_typing_line


func _finish_typing() -> void:
	if not _is_typing_line:
		return

	if _typewriter_tween != null:
		_typewriter_tween.kill()
		_typewriter_tween = null

	dialogue_text.visible_characters = -1
	_is_typing_line = false
