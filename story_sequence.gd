# ==============================================================================
# Purpose / Dependencies / AI Guidance
# ==============================================================================
# Purpose
# Controls the prologue + dialogue playback for the story sequence modal UI,
# including music/volume transitions, portrait/background animations, and the
# typewriter text reveal.
#
# Dependencies
# - Scene nodes:
#   - $Background (TextureRect), $LineIllustration (TextureRect, optional beat art)
#   - $PortraitLeft (TextureRect), $PortraitRight (TextureRect)
#   - $DialoguePanel/SpeakerLabel (Label), $DialoguePanel/DialogueText (RichTextLabel)
#   - $DialoguePanel/NextIndicator (TextureButton), $TextBlip (AudioStreamPlayer), $SkipButton (TextureButton)
# - Autoload/singletons:
#   - CampaignManager.player_roster (used to replace {hero_name}/{weapon_name} and resolve HERO_PORTRAIT).
#
# AI/Reviewer Guidance
# - Entry points: _ready() starts the first line; _process() advances/finishes typing; _play_line() renders one dictionary entry.
# - Data contract: each `story_sequence` element is a Dictionary supporting keys like:
#   `speaker`, `text`, `portrait_left`, `portrait_right`, `background`, `music`, `volume`,
#   `shake`, `active_side`, `flip_left`, `flip_right`, `fit_background`, `line_illustration` (Texture2D, optional).
# - Job intro beat art: [member job_intro_art_sets] ([class_name JobIntroArtSet]) + [member job_intro_illustration_interval]; per-class textures every N lines of the splice.
# - Job-aware intro: after the shared 'one life moves quietly' beat, [method _build_story_playback_sequence]
#   splices a long personal life-to-now Oakhaven block (~17 lines) per character class [code]job_name[/code]
#   ([code]CampaignManager.custom_avatar.class_name[/code] or [member ClassData.job_name]). Lines may use [code]{hero_name}[/code], [code]{weapon_name}[/code].
# ==============================================================================
extends Control

@onready var background: TextureRect = $Background
@onready var portrait_left: TextureRect = $PortraitLeft
@onready var portrait_right: TextureRect = $PortraitRight
@onready var speaker_label: Label = $DialoguePanel/SpeakerLabel
@onready var dialogue_text: RichTextLabel = $DialoguePanel/DialogueText
@onready var next_indicator: TextureButton = $DialoguePanel/NextIndicator
@onready var text_blip: AudioStreamPlayer = $TextBlip
@onready var skip_button: TextureButton = $SkipButton
@onready var line_illustration: TextureRect = get_node_or_null("LineIllustration") as TextureRect

# --- MUSIC LOGIC ---
@onready var bg_music: AudioStreamPlayer = $BackgroundMusic
@export var peaceful_music: AudioStream
@export var tense_music: AudioStream
@export var vespera_music: AudioStream

## If > 0, every Nth line of the job-specific prologue splice gets a [code]line_illustration[/code]. Set to 0 to disable.
@export var job_intro_illustration_interval: int = 4
## One entry per class; [member JobIntroArtSet.job_name] must match [member ClassData.job_name]. Unused jobs simply show no beat art.
@export var job_intro_art_sets: Array[JobIntroArtSet] = []
## If no set matches the hero job (or it has no textures), these cycle instead—optional.
@export var job_intro_fallback_beats: Array[Texture2D] = []

var current_music_type: String = ""
var music_tween: Tween
var base_volume: float = -15.0
var current_volume_target: float = base_volume

# --- ASSETS ---
# Existing
var bg_peaceful_village: Texture2D = preload("res://Assets/Backgrounds/peaceful_village.jpeg")
var bg_attacked_village: Texture2D = preload("res://Assets/Backgrounds/attacked_village.png")
var bg_vespera_descent: Texture2D = preload("res://Assets/Backgrounds/vespera_descent.png")
var bg_burning_village: Texture2D = preload("res://Assets/Backgrounds/burning_village.png")

# NEW (Prologue slides) - create these files and place them in this folder.
# If you want different names/paths, just update these 4 lines.
var bg_prologue_void: Texture2D = preload("res://Assets/Backgrounds/prologue_void.png")
var bg_prologue_shattering_war: Texture2D = preload("res://Assets/Backgrounds/prologue_shattering_war.png")
var bg_prologue_catalyst_mark: Texture2D = preload("res://Assets/Backgrounds/prologue_catalyst_mark.png")
var bg_prologue_map: Texture2D = preload("res://Assets/Backgrounds/prologue_map.png")

# Base Portraits
var tex_vespera: Texture2D = preload("res://Assets/Portraits/vespera.png")
var tex_elder: Texture2D = preload("res://Assets/Portraits/elder.png")
var tex_kaelen_front: Texture2D = preload("res://Assets/Portraits/kaelen_front.png")
var tex_kaelen_front_yell: Texture2D = preload("res://Assets/Portraits/kaelen_front_yell.png")
var tex_kaelen_side: Texture2D = preload("res://Assets/Portraits/kaelen_side.png")
var tex_kaelen_side_yell: Texture2D = preload("res://Assets/Portraits/kaelen_side_yell.png")

# Vespera Expressions & Blink
var tex_vespera_smirk: Texture2D = preload("res://Assets/Portraits/vespera_smirk.png")
var tex_vespera_intrigued: Texture2D = preload("res://Assets/Portraits/vespera_intrigued.png")
var tex_vespera_disgusted: Texture2D = preload("res://Assets/Portraits/vespera_disgusted.png")
var tex_vespera_angry: Texture2D = preload("res://Assets/Portraits/vespera_angry.png")
var tex_vespera_blink: Texture2D = preload("res://Assets/Portraits/vespera_blink.png")
var tex_acolyte: Texture2D = preload("res://Assets/Portraits/shadow_acolyte.png")

var bg_tween: Tween
var blink_tween: Tween
var speaker_pulse_tween: Tween # --- TWEEN FOR BREATHING ANIMATION ---

var input_cooldown: float = 0.0
var cooldown_duration: float = 0.35

# --- STORY SEQUENCE ---
# Added a Wind-Waker-style prologue (4 slides) + the extra bridge line.
# Then your existing Oakhaven lines start unchanged.
var _story_sequence_template: Array[Dictionary] = [
	# --- PROLOGUE SLIDES ---
	{
		"speaker": "",
		"text": "This is one of the truths the continent refuses to name. Beyond the firmament lies an ancient Hunger—vast, patient, and unmoved by prayer. To it, kingdoms are sparks. People are ash on the wind.",
		"portrait_left": null,
		"portrait_right": null,
		"background": bg_prologue_void,
		"music": "peaceful",
		"active_side": "none",
		"fit_background": true
	},
	{
		"speaker": "",
		"text": "Long ago, Aurelia learned the price of being noticed. When the veil tore, the land broke before it. A war followed—waged with crowns, with sorcery… and with lives.",
		"portrait_left": null,
		"portrait_right": null,
		"background": bg_prologue_shattering_war,
		"active_side": "none",
		"fit_background": true
	},
	{
		"speaker": "",
		"text": "They sealed the breach, but they could not erase what it touched. From that night onward, certain bloodlines carried a sign—a Catalyst Mark… a lock and a key, waiting for the wrong hand to turn it.",
		"portrait_left": null,
		"portrait_right": null,
		"background": bg_prologue_catalyst_mark,
		"active_side": "none",
		"fit_background": true
	},
	{
		"speaker": "",
		"text": "Two centuries passed. The war became history. The fear became policy. Empires sanctified silence. Merchants priced survival. Monarchs called it ‘order.’ And while the powerful argued over borders… the Hunger waited.",
		"portrait_left": null,
		"portrait_right": null,
		"background": bg_prologue_map,
		"active_side": "none",
		"fit_background": true
	},

	# --- ORIGINAL OPENING (NOW WITH THE EXTRA BRIDGE LINE ADDED) ---
	{
		"speaker": "",
		"text": "For two centuries since the Shattering War, the continent of Aurelia has bled from endless political scheming.",
		"portrait_left": null,
		"portrait_right": null,
		"background": bg_peaceful_village,
		"active_side": "none"
	},
	# NEW BRIDGE LINE (requested)
	{
		"speaker": "",
		"text": "Not every place on Aurelia belongs to kings, guilds, or gods—some corners still dare to live quietly.",
		"portrait_left": null,
		"portrait_right": null,
		"background": bg_peaceful_village,
		"active_side": "none"
	},
	{
		"speaker": "",
		"text": "In a forgotten corner of Aurelia, far from crowns and cathedrals, one life moves quietly—tending the soil, marked by unseen fate, unaware the stars have already begun to watch.",
		"portrait_left": null,
		"portrait_right": null,
		"background": bg_peaceful_village,
		"active_side": "none"
	},	
	{
		"speaker": "",
		"text": "Nestled deep within the Emberwood lies Oakhaven. A quiet sanctuary dedicated to cultivating the medicinal Lumina root.",
		"portrait_left": null,
		"portrait_right": null,
		"background": bg_peaceful_village,
		"active_side": "none"
	},
	{
		"speaker": "",
		"text": "Here, the villagers ask only for peace, far from the greedy eyes of the Merchant League and the strict edicts of the Theocracy.",
		"portrait_left": null,
		"portrait_right": null,
		"background": bg_peaceful_village,
		"active_side": "none"
	},
	{
		"speaker": "",
		"text": "However, isolation is a fragile shield. Tonight, the sky itself begins to fracture.",
		"portrait_left": null,
		"portrait_right": null,
		"background": bg_attacked_village,
		"music": "none",
		"shake": true,
		"active_side": "none"
	},

	# --- VESPERA MONOLOGUE SEQUENCE ---
	{
		"speaker": "Lady Vespera",
		"text": "You look up and see only ruin and terror.",
		"portrait_left": null,
		"portrait_right": null,
		"background": bg_vespera_descent,
		"music": "vespera",
		"volume": -15.0,
		"fit_background": true,
		"active_side": "none"
	},
	{
		"speaker": "Lady Vespera",
		"text": "But this is not the end. It is the shattering of a cage we have been locked inside for centuries.",
		"portrait_left": null,
		"portrait_right": null,
		"background": bg_vespera_descent,
		"fit_background": true,
		"active_side": "none"
	},
	{
		"speaker": "Lady Vespera",
		"text": "For too long, Aurelia has bled for the vanity of kings and the silence of false gods. No more children will be fed to their wars.",
		"portrait_left": null,
		"portrait_right": null,
		"background": bg_vespera_descent,
		"fit_background": true,
		"active_side": "none"
	},
	{
		"speaker": "Lady Vespera",
		"text": "The cycle of suffering ends tonight. Let the Summoner's truth wash away this broken world.",
		"portrait_left": null,
		"portrait_right": null,
		"background": bg_vespera_descent,
		"shake": true,
		"fit_background": true,
		"active_side": "none"
	},

	# --- CONFRONTATION SEQUENCE WITH EXPRESSIONS ---
	{
		"speaker": "Shadow Acolyte",
		"text": "My Lady. The perimeter is secured. The survivors have been corralled into the town square.",
		"portrait_left": tex_vespera,
		"portrait_right": tex_acolyte,
		"background": bg_burning_village,
		"volume": -20.0,
		"flip_right": true,
		"active_side": "right"
	},
	{
		"speaker": "Lady Vespera",
		"text": "Good. The ley lines here run thick with generations of sorrow. Bind them. The Summoner requires their blood to tear the veil.",
		"portrait_left": tex_vespera,
		"portrait_right": tex_acolyte,
		"background": bg_burning_village,
		"flip_right": true,
		"active_side": "left"
	},
	{
		"speaker": "Oakhaven Elder",
		"text": "Please... the sky is bleeding. What are you bringing into our world?!",
		"portrait_left": tex_vespera,
		"portrait_right": tex_elder,
		"background": bg_burning_village,
		"active_side": "right"
	},
	{
		"speaker": "Lady Vespera",
		"text": "Salvation, old fool. A pity your fragile mind will snap before you witness the dawn.",
		"portrait_left": tex_vespera_smirk,
		"portrait_right": null,
		"background": bg_burning_village,
		"active_side": "left"
	},
	{
		"speaker": "{hero_name}",
		"text": "Step away from him. Your ritual ends now.",
		"portrait_left": tex_vespera_smirk,
		"portrait_right": "HERO_PORTRAIT",
		"background": bg_burning_village,
		"active_side": "right"
	},
	{
		"speaker": "Lady Vespera",
		"text": "Such hollow conviction from a peasant. Do you truly think your little—",
		"portrait_left": tex_vespera_smirk,
		"portrait_right": "HERO_PORTRAIT",
		"background": bg_burning_village,
		"active_side": "left"
	},
	{
		"speaker": "Lady Vespera",
		"text": "...Wait. Look closer at you. What is that vile resonance?",
		"portrait_left": tex_vespera_intrigued,
		"portrait_right": "HERO_PORTRAIT",
		"background": bg_burning_village,
		"active_side": "left"
	},
	{
		"speaker": "Lady Vespera",
		"text": "There is a creeping rot taking root inside your very soul. A shadow wrapped tightly around your heart.",
		"portrait_left": tex_vespera_intrigued,
		"portrait_right": "HERO_PORTRAIT",
		"background": bg_burning_village,
		"active_side": "left"
	},
	{
		"speaker": "Lady Vespera",
		"text": "I cannot quite place the stench... but it matters little. Corrupted or not, your blood will still pry open the rift.",
		"portrait_left": tex_vespera_disgusted,
		"portrait_right": "HERO_PORTRAIT",
		"background": bg_burning_village,
		"active_side": "left"
	},
	{
		"speaker": "Kaelen",
		"text": "Back away from the kid, you bloodsucking parasite!",
		"portrait_left": tex_vespera_disgusted,
		"portrait_right": tex_kaelen_side_yell,
		"flip_right": true,
		"shake": true,
		"background": bg_burning_village,
		"active_side": "right"
	},
	{
		"speaker": "Lady Vespera",
		"text": "Ah. The stray dog of the Vanguard bares his teeth at last. Have you come to die with the rest of this filth, Kaelen?",
		"portrait_left": tex_vespera_angry,
		"portrait_right": tex_kaelen_side,
		"flip_right": true,
		"background": bg_burning_village,
		"active_side": "left"
	},
	{
		"speaker": "Kaelen",
		"text": "Are you suicidal, rookie? You're staring down a god's shadow with empty hands. One flick of her wrist and she'll flay you alive!",
		"portrait_left": tex_vespera_angry,
		"portrait_right": tex_kaelen_side_yell,
		"flip_right": true,
		"background": bg_burning_village,
		"active_side": "right"
	},
	{
		"speaker": "Kaelen",
		"text": "Catch this {weapon_name} and guard the flank! We aren't here to play hero, we are here to survive. Move!",
		"portrait_left": tex_vespera_angry,
		"portrait_right": tex_kaelen_side_yell,
		"flip_right": true,
		"shake": true,
		"background": bg_burning_village,
		"active_side": "right"
	}
]

## Playback list (template + job intro splice). Built in [method _ready].
var story_sequence: Array[Dictionary] = []

## Index in [member _story_sequence_template] where class intro is inserted: before "Nestled deep within the Emberwood…".
const _PROLOGUE_JOB_INSERT_INDEX: int = 7

func _build_story_playback_sequence() -> Array[Dictionary]:
	var out: Array[Dictionary] = _story_sequence_template.duplicate(true)
	var job_key: String = _resolve_prologue_job_key()
	var chunk: Array[Dictionary] = _class_job_full_intro_lines(job_key)
	var at: int = clampi(_PROLOGUE_JOB_INSERT_INDEX, 0, out.size())
	for i in range(chunk.size()):
		out.insert(at + i, chunk[i].duplicate(true))
	_apply_job_intro_illustrations(out, at, chunk.size(), job_key)
	return out


func _beat_textures_for_job(job_key: String) -> Array[Texture2D]:
	for s in job_intro_art_sets:
		if s == null:
			continue
		if str(s.job_name).strip_edges() == job_key:
			return s.beat_textures
	return job_intro_fallback_beats


func _apply_job_intro_illustrations(seq: Array[Dictionary], chunk_start: int, chunk_len: int, job_key: String) -> void:
	if job_intro_illustration_interval <= 0:
		return
	var beats: Array[Texture2D] = _beat_textures_for_job(job_key)
	if beats.is_empty():
		return
	var n_tex: int = beats.size()
	for i in range(chunk_len):
		if (i + 1) % job_intro_illustration_interval != 0:
			continue
		var slot: int = int((i + 1) / job_intro_illustration_interval) - 1
		var tex: Texture2D = beats[slot % n_tex]
		if tex != null:
			seq[chunk_start + i]["line_illustration"] = tex


func _resolve_prologue_job_key() -> String:
	if CampaignManager == null:
		return "Mercenary"
	var av: Variant = CampaignManager.custom_avatar
	var raw: String = ""
	if av is Dictionary:
		var d: Dictionary = av
		raw = str(d.get("class_name", d.get("unit_class", ""))).strip_edges()
		if raw == "" and d.get("class_data") is ClassData:
			raw = str((d.get("class_data") as ClassData).job_name).strip_edges()
	if raw == "" and CampaignManager.player_roster.size() > 0:
		var hero: Dictionary = CampaignManager.player_roster[0]
		if hero is Dictionary:
			raw = str(hero.get("class_name", hero.get("unit_class", ""))).strip_edges()
	if raw == "":
		return "Mercenary"
	return raw


func _class_intro_line(text: String) -> Dictionary:
	return {
		"speaker": "",
		"text": text,
		"portrait_left": null,
		"portrait_right": null,
		"background": bg_peaceful_village,
		"active_side": "none"
	}


func _class_job_full_intro_lines(job_key: String) -> Array[Dictionary]:
	var merc_fallback: PackedStringArray = PackedStringArray([
		"{hero_name} never asked to be anyone's song—just fed, dry, and left alone long enough to remember what boredom felt like.",
		"You grew up where maps changed whenever a noble sneezed, which taught you two skills: hauling, and knowing when to vanish into the joke instead of the argument.",
		"You learned {weapon_name} the practical way—splitting wood, splitting differences, and once splitting a taxman's patience until he decided you weren't worth the paperwork.",
		"You've seen ugly roads, but you've also seen strangers share bread without a sermon attached; that second part made you softer than you admit.",
		"You marched with a company that stopped existing somewhere between a bridge and a bad decision. You kept their punchlines anyway; dead men shouldn't lose their timing.",
		"Oakhaven found you between wars like a dog finds a porch—suspicious, grateful, already half in love with the smell of stew.",
		"The Lumina gave you a row instead of a rank. Honest dirt beats honest blood; you told yourself that, and were surprised how often it felt true.",
		"You know which kid hides bruises under sleeves and which elder steals extra sugar—information you never use as a weapon, only as an excuse to be nearby when things go sideways.",
		"At the eastern fence the old soldiers spar like they're flirting with gravity. You watch to enjoy them, not to measure kills; it's the most peace you've bought in years.",
		"No one salutes. They nod. You've started nodding back like it means something—because here, maybe it does.",
		"You still sleep with {weapon_name} close. The village teases you. You tease back that their snoring could wake the Rift; everyone laughs, and nobody feels judged.",
		"The Catalyst Mark arrived like a bruise from a fight you don't remember—an ache that hums when the sky gets ideas.",
		"You hid it because panic spreads faster than courage, and Oakhaven has enough stories without adding you as the fireproof headline.",
		"The Elder put you on storehouse watch and pretended it was routine. You pretended you didn't notice the trust in that; trust is a heavy thing to hold correctly.",
		"You've laughed at a bad harvest joke, carried water for a fever you couldn't name, and lost a game of dice to a child who cheated adorably. You'd do it again tomorrow.",
		"Tonight the air feels like someone swapped recipes—metal where there should be rain, tension where there should be crickets.",
		"If trouble comes, your body answers before your mouth finishes arguing. You're not proud of how fast that happens—but you're very proud of who you're standing beside when it does.",
	])
	var texts: PackedStringArray = merc_fallback
	match job_key:
		"Archer":
			texts = PackedStringArray([
				"{hero_name} grew up fluent in wind—how it lies, how it tells the truth if you listen through the leaves instead of through your pride.",
				"Your first bow was a hand-me-down that creaked like gossip. You loved it anyway; love is half the accuracy, or so you tell bad shots to make them smile.",
				"You learned to feed people before you learned to fight for them—rabbit stew first, arguments about borders later.",
				"Oakhaven found you with string-burn and stubborn humor, escaping a levy that wanted archers as parade pieces—and cannon fodder with good posture.",
				"They handed you a Lumina row. You thought it was a joke until the soil taught you patience tastes better than adrenaline.",
				"Clean air here makes your ears picky; you can hear laughter three cottages away, which is inconvenient and also the best kind of spy work.",
				"You still map sightlines out of habit—then use the knowledge to hang lanterns where kids won't trip, not to tally victims.",
				"The veterans call you a dreamer. You teach their grandkids to aim at clouds so nobody gets hurt learning.",
				"{weapon_name} lives by your bed like a loyal mutt—scuffed, honest, always happy to work if you treat it right.",
				"You promised yourself Oakhaven was temporary. Then someone remembered your favorite tea without being asked, and your plans got politely sabotaged.",
				"The Catalyst Mark bloomed like sunlight behind the eyes—startling, warm, and entirely too interested in your pulse.",
				"You hid it because awe turns into rumor, and rumor turns into trouble for the people who fed you.",
				"The Elder sends you to the ridge before storms without making it sound like an order. You appreciate that; orders never came with hot soup before.",
				"You love this place in the sideways way you love a perfect shot—quiet pride, sharp attention, endless willingness to do it again.",
				"Tonight the Emberwood sounds like it's holding its breath. You've heard that joke from the trees before; you still listen politely.",
				"If someone ever asks you to loose an arrow at a face you know, you'll choose another answer—even if it costs you.",
				"Distance kept you safe once. Oakhaven is teaching you closeness might be braver—and the Mark might be insisting you find out.",
			])
		"Warrior":
			texts = PackedStringArray([
				"{hero_name} comes from a place where fights started over fences and ended over forgiveness—sometimes on the same afternoon.",
				"You learned {weapon_name} as a kitchen cousin first: kindling, joints, the polite violence of getting dinner finished before dark.",
				"Drill sergeants called you reliable; friends called you 'the one who remembers birthdays.' Both titles felt heavier than the armor.",
				"You've seen mud and nonsense called glory. You prefer the version where glory is everyone going home sore but upright.",
				"A bridge broke your company—literally and spiritually. You kept the jokes anyway, because grief without laughter turns sharp.",
				"Oakhaven took you in with soil instead of standards. You didn't know you needed that until your shoulders unclenched for the first time in years.",
				"You spar at the eastern fence and apologize when you win too hard; you mean it, which makes people want to fight you again.",
				"Villagers nod instead of saluting. You try not to brag about how good a nod feels compared to a medal.",
				"You still sleep with steel close. It's habit, not heroism—like keeping slippers by the bed, except slippers never saved anyone from wolves.",
				"The Catalyst Mark arrived like a second heartbeat that can't agree on tempo—you thought you were done being surprising.",
				"You hid it because you didn't want to be anyone's omen. Oakhaven has enough scary stories; you'd rather be the punchline to a harmless one.",
				"The Elder gives you storehouse duty and pretends it's not because you pace when you're worried. You pretend you don't pace. Everyone loses politely.",
				"You love Oakhaven embarrassingly hard—like a stray who found a window seat and refuses to pretend indifference.",
				"Tonight's thunder sounds like a drumline that's forgotten the party. Your body wants to march anyway; your sense of humor tells it to sit down.",
				"You told yourself you were finished becoming anything new. The lie was cozy until the sky started negotiating.",
				"When trouble comes, your hands move first and your conscience catches up breathing hard—you're good at buying time for the conscience.",
				"You never wanted legend. You wanted to be the person who carries the heavy crate, tells the scared kid a joke, and stays until the job is done.",
			])
		"Knight":
			texts = PackedStringArray([
				"{hero_name} took oaths young—some heartfelt, some theatrical, all spoken in rooms that smelled like wine and Important Decisions.",
				"You learned armor as choreography: how to bow in steel without falling over, how to make protection look like poise instead of panic.",
				"Your order unraveled in paperwork you weren't allowed to read. You held a line that stopped mattering; you still held it, because habits die politely.",
				"You sold your horse for grain and didn't tell anyone you cried about it. Companionship doesn't always come on two legs.",
				"Oakhaven found you mid-identity crisis and offered a shovel. It was embarrassingly healing.",
				"Lumina dirt stuck under your nails. You complained like a noble, then laughed when a kid called you 'Lord Turnip' and meant it affectionately.",
				"They tease the knight who weeds. You lean into it—better jokes than statues, and the beets don't care about heraldry.",
				"You square your shoulders when children sprint by because you've learned to be scenery they can hide behind without knowing they're hiding.",
				"{weapon_name} remembers parade drills; your hands remember bandages. You're getting better at listening to the second memory.",
				"The Catalyst Mark arrived like a brand that forgot to ask permission—rude, intimate, weirdly insistent.",
				"You hid it because you've seen what happens when people mistake you for a miracle. You'd rather be mistaken for dependable.",
				"The Elder pretends not to notice your dramatic silences. You pretend not to notice they leave extra bread when you've had a long watch.",
				"You're scared of becoming a poster again. Posters don't get to choose who stands behind them; people do.",
				"Tonight wind tugs at torch smoke like a banner that wants to dance. You let nostalgia have one song, then you get back to work.",
				"You owe Oakhaven nothing on parchment. You owe it something better: showing up when the roof leaks and nobody's watching.",
				"If the heavens keep accounts, you hope there's a column for 'fixed the gate' right next to the one for 'swore loudly.'",
				"Knighthood was a role you played until it fit. The Mark might be offering a new script—one where you're allowed to be afraid and brave at the same time.",
			])
		"Mercenary":
			texts = merc_fallback
		"Thief":
			texts = PackedStringArray([
				"{hero_name} grew up where a ledger could lie and a lock could tell the truth—and where sharing a stolen orange still counted as community service.",
				"You learned fingers before philosophy, mostly because philosophy doesn't fill a stomach on a cold morning.",
				"You didn't flee to Oakhaven for a halo. You came because mud doesn't charge import fees and the trees don't ask for references.",
				"The crossing cost a tooth and a name you were happy to trade for a blanket that didn't smell like city smoke.",
				"Lumina chores handed you the keys to decency: storerooms, sickbeds, kitchens—places a dagger can't buy you, but a good reputation can.",
				"You still notice who drinks too much and who hums when they're lying; now you use it to leave apples on doorsteps, not to score points.",
				"Trust files slower for you than for most. Oakhaven keeps sandpapering your edges with small kindnesses until trust feels less like a trap.",
				"You've been caught twice in your life. Here, people pretend not to notice your old tells—until you stop needing them.",
				"They call you charming; you call them kind and mean it. That's dangerously new for you.",
				"{weapon_name} is for emergencies you invent in your head and real ones you pray never arrive—the kind where your friends need covering, not corpses.",
				"The Catalyst Mark showed up like an uninvited houseguest who refuses to explain the rules. You hid it before it invited gossip.",
				"You hide it the way you've hidden harder things: with a smile that doesn't reach tired eyes, and with work that keeps hands busy.",
				"At night you count exits out of habit—then realize you've started counting faces you don't want to leave behind.",
				"Oakhaven was supposed to be a pause. Now it's a stubborn little hope with your name scribbled in the margins.",
				"The Elder once put a second bowl in front of you without a speech. You ate like it wasn't a sacrament, even though it was.",
				"Tonight feels like someone left a window cracked for fresh air—or for trouble. Either way, you know how to close it quietly.",
				"You used to worship escape routes. Lately you worship the idea of dragging everyone through the right door at once. The Mark might force the issue.",
			])
		"Mage":
			texts = PackedStringArray([
				"{hero_name} grew up treating curiosity like a pet—fed it scraps, hid it from serious people, and taught it tricks when nobody was looking.",
				"Wonder used to be cheap: ash doodles in the hearth, a tutor sneezing mid-prophecy, laughter mistaken for ritual.",
				"Hard years priced wonder into something you hoarded like coin. Oakhaven priced it back down to soil, sun, and an honest blister.",
				"You arrived carrying debt, a half-burned primer, and the habit of eavesdropping for the interesting bits—never the cruel ones, if you could help it.",
				"The Lumina made you dig before you dabbled. You complained theatrically, then felt weirdly proud when your first cuttings lived.",
				"They said mastery starts where vanity ends. You rolled your eyes, then noticed your vanity had shrunk two sizes without asking.",
				"You memorized herbs until your dreams resembled a well-organized pantry—except for the nights the pantry caught fire and whispered your name.",
				"The archivist once caught you drawing sigils in spilled wine. She left a second candle, a biscuit, and no lecture. You've been loyal to her ever since.",
				"Villagers tease your 'thinking face.' You tease back that their jokes are statistically improbable and still funny.",
				"You mix fevers away with steady hands and bad puns; panic doesn't survive either treatment for long.",
				"You've quietly prevented disasters—wrong doses, sparks that wanted to be bonfires—then downplayed your heroism because praise makes you awkward.",
				"The Catalyst Mark arrived like a footnote that decided to become a chapter—interesting, alarming, hard to shelve.",
				"You hid it because surprise and scholarship don't mix; you'd rather introduce new ideas with citations and tea.",
				"The Elder gave you keys you swore you shouldn't hold. You accepted because saying no felt ruder than being trusted.",
				"You care about these people with embarrassing specificity—who likes extra honey, who pretends they don't need sleep, who laughs too loud when they're sad.",
				"You dreamed a library drowned and woke clutching {weapon_name} like a bookmark. You haven't told anyone; some nightmares prefer privacy.",
				"Useful became your favorite disguise. The Mark threatens to make you visible—and maybe that's not the catastrophe you assumed.",
			])
		"Paladin":
			texts = PackedStringArray([
				"{hero_name} first met the divine as wind snapping through a banner—loud, honest, and impossible to polish into something comfortable.",
				"You trained with people who could set a bone and hold a line without turning into stone. You liked them; that was inconvenient professionally.",
				"Your prayers smell like sweat, metal, and bread; your best theology happens with your hands in dishwater, not only in incense.",
				"The Theocracy wanted you signing receipts for miracles. You left when the receipts started weighing more than the mercy.",
				"Oakhaven didn't ask which heaven you invoice. It asked if you could haul water while someone sweated through a fever—and you could, and you did.",
				"Lumina rows became your quiet chapel: straight lines, patient repetition, crickets applauding without ulterior motives.",
				"When villagers thank the sky for rain, you smile and pass the bucket. Arguments with weather rarely help thirsty fields.",
				"You remember who needs a softer voice, a firmer stool, or a joke disguised as courage—small liturgies that keep a town standing.",
				"{weapon_name} is the kind of creed you can lug through mud: heavy, honest, less interested in speeches than in outcomes.",
				"The Catalyst Mark arrived like an order you didn't issue—pressed against your sternum like a seal you didn't ask for but might deserve.",
				"You hid it because you've seen hope curdle into spectacle. You'd rather be the boring kind of blessed: reliable, tired, on time.",
				"The Elder walks night rounds with you sometimes and pretends it's coincidence. You pretend you believe them. It's a pleasant conspiracy.",
				"You love Oakhaven for letting you be useful without applauding your ego. Applause rusts faster than plate in salt air.",
				"Tonight iron rides the wind under the smell of soil—like someone tuned a bell wrong and the world is listening anyway.",
				"You promised yourself small good deeds until the world behaved. The world is rude; your stubbornness is complimentary.",
				"If your god watches, you hope They reward the violence that opens doors—not the violence that slams them on fingers.",
				"Paladin was a uniform people handed you. The Mark might be asking for a person underneath—awkward, afraid, still willing.",
			])
		"Spellblade":
			texts = PackedStringArray([
				"{hero_name} picked up spellblade work because the world kept asking impossible multiple-choice questions and you cheat by selecting both.",
				"One teacher wanted perfect lunges; another wanted perfect pronunciation. You wanted lunch; life demanded synthesis.",
				"You left home after a training night went comedy-tragic—sparks, apologies, and a very stern letter you framed as 'creative differences.'",
				"The road offered opinions like bad cider. You learned to smile, nod, and keep your specialties politely vague.",
				"Oakhaven took you in as winter insurance: hands for the row, shoulders for sacks, no pedigree exam. You nearly hugged someone; you settled for hauling.",
				"Your table holds blade oil and chalked circles like roommates who argue and still pay rent on time.",
				"Lumina dirt reminds you that power without patience turns sloppy; sloppiness ruins soup, marriages, and wards—usually in that order.",
				"Under panic you reach for {weapon_name}. Under shame you reach for verse. Under normal days you reach for the kettle like a civilized gremlin.",
				"Veterans call you 'too clever.' You repay the compliment by fixing their gear and pretending not to notice when they're impressed.",
				"When a beam fell, you used your shoulder—not because magic failed, but because theatrics don't matter when a child's laughing.",
				"The Catalyst Mark chimed like harmony that can't decide a key—interesting musically, terrifying politically.",
				"You hid it because mixed talents attract mixed prices; Oakhaven already paid yours in bread and bad jokes.",
				"Balance isn't peace; it's practice, like walking a fence while carrying two buckets. You're getting fewer spills.",
				"You love Oakhaven for letting you be complicated without auditioning for a tragedy.",
				"If the world demands a single label, you've always answered with survival first and principles second—then secretly upgraded the principles when nobody was looking.",
				"You don't want to be a cautionary tale; you want to be the one who makes the tale end with everyone annoying each other at dinner.",
				"{weapon_name} is solid fact; the hum under your skin is rude theory. Together they're a career; separately they're a headache you oddly cherish.",
			])
		"Cleric":
			texts = PackedStringArray([
				"{hero_name} met holiness in steam—laundry boiling, linens folded warm, the stubborn religion of 'let me make you comfortable.'",
				"You took minor vows early because someone had to hold the bucket, hold the hand, hold the joke when pain made silence unbearable.",
				"The Theocracy wanted soul receipts; you wanted pulses to steady and fevers to break. You remain cheerfully bad at paperwork.",
				"Oakhaven traded incense for earth. You traded lofty speeches for listening—an upgrade, as far as you're concerned.",
				"The Lumina rows taught you liturgy without velvet: kneel in dirt, bless the seeds, swear at weeds with affection.",
				"They call you steady. You call yourself 'running on tea and spite for suffering.' Both descriptions are affectionate.",
				"You notice who flinches at bells, blood, or bad memories—and you change the subject to onions, weather, or something safely ridiculous.",
				"The Elder treats your doubt like weather: work with it, bring a cloak, don't shame clouds for raining.",
				"{weapon_name} sits by your kit like a tool you're not eager to use—because you'd rather win with soup, but you're not naive about the world.",
				"The Catalyst Mark arrived as warmth that wasn't quite fever—like a candle moved too close, intimate and insistent.",
				"You hid the glow because sickrooms need steadier miracles than fireworks—calm hands beat astonished crowds.",
				"You pray in rhythm with your steps along the row; heaven can hear you fine without marble acoustics.",
				"You love Oakhaven the way medics love a ward that laughs between bandages—messy, alive, worth staying up for.",
				"Tonight iron rides the breeze under pollen. You make a face at drama weather and prepare extra cloth anyway.",
				"You promised small kindnesses until the world behaved. The world is stubborn; you're stubborner.",
				"If grace keeps books, you hope there's a column for 'remembered birthdays' beside 'saved lives.'",
				"Cleric was a calling you answered with sleeves rolled. The Mark might be a second calling—rude, bright, and oddly hopeful.",
			])
		"Monk":
			texts = PackedStringArray([
				"{hero_name} learned the body before dogma—how breath can be a joke told to panic until panic laughs and gives up.",
				"You were taken in young—or ran until someone offered tea and a schedule. Both paths left you fond of routine and second chances.",
				"They taught you forms meant to argue with your worst impulses; you treated yours like a chatty rival instead of an enemy.",
				"You broke a small vow once, apologized like an adult, and discovered penance feels nicer when it builds muscle instead of shame.",
				"Oakhaven found you between temples, carrying two hands' worth of belongings and a stubborn habit of arriving early to help.",
				"Lumina labor fits your training like a familiar kata: bend, breathe, let roots humiliate your ego in a friendly way.",
				"Villagers call you calm. You think of it as 'borrowed calm'—a coat you lend so others don't shiver.",
				"You overhear pain before it's announced because caring trained your ears before your pride did.",
				"{weapon_name} leans nearby like a backup plan—staff, steel, whatever the day needed when philosophy had to share space with dinner.",
				"The Catalyst Mark arrived like warmth that took Pilates without permission—unhelpfully disciplined, strangely persuasive.",
				"You hid it because wonder distracts hungry eyes, and hungry eyes make mistakes that bruise whole villages.",
				"The Elder times your crate-stacking contests with a smirk. You pretend not to compete. You absolutely compete, kindly.",
				"You love Oakhaven like a favorite practice hall: imperfect, forgiving, stocked with people who deserve your best attention.",
				"Tonight thunder purrs like a coach clearing a throat before a friendly bout.",
				"You hoped discipline would keep tragedy theoretical. Instead it gave you better tools when theory failed—still a gift.",
				"If peace is practice, your calluses are diplomas. The Mark might enroll you in a harder class; you're stubborn enough to attend.",
				"You chased emptiness as rest. Now emptiness feels less like absence and more like room—room you're willing to share.",
			])
		"Fire Sage":
			texts = PackedStringArray([
				"{hero_name} fell for fire early—not for destruction, but because heat tells the truth faster than most people dare to.",
				"They called it a gift in salons and a curse in ashes. You decided it's temperament: powerful, teachable, and tired of bad press.",
				"You trained under leaky ceilings where mistakes glowed honest. Humbling, loud, occasionally hilarious if you survived with eyebrows intact.",
				"Oakhaven sounded absurd—so much water, so much patience—until you realized damp earth is the kindest leash fire ever wore.",
				"Lumina work shoved your hands into cool loam until your temper learned to simmer instead of shout. You complained beautifully.",
				"Villagers tease your 'oven hands.' You bake bread on purpose now, so the joke becomes tradition instead of fear.",
				"You count breaths like a cook counts embers—enough to warm, not enough to scorch the roof.",
				"Night feels honest: flame doesn't pretend it isn't hungry; people could learn from that, within reason.",
				"{weapon_name} is a reminder fire answers to bodies—to grip, to aim, to someone stubborn enough to say 'not today' to wild sparks.",
				"The Catalyst Mark flared like a familiar spice you swore you measured right—startling, aromatic, demanding attention.",
				"You hid the glow because neighbors deserve sleep without worrying their thatch is debating spontaneous combustion.",
				"The Elder assigned you the far beds during fevers and called it ventilation. You counted it as kindness and repaid it with extra firewood anyway.",
				"You love Oakhaven for teaching you warmth can be domestic—hearth not holocaust, comfort not conquest.",
				"Tonight the storm smells like a forge got chatty with the sky—odd, electric, impossible to ignore.",
				"You once thought mastery meant never flinching. Now you think it means flinching on purpose for the right reasons.",
				"If you're a sage, you're the sort people consult for heat and leave with instructions and a slightly singed sleeve—still smiling.",
				"Fire listens to {hero_name} more than it used to—exciting, terrifying, and weirdly like partnership. Oakhaven's about to find out what kind.",
			])
		_:
			texts = merc_fallback
	var out: Array[Dictionary] = []
	for line in texts:
		out.append(_class_intro_line(line))
	return out


var current_line_index: int = 0
var is_typing: bool = false
var type_speed: float = 0.03
var is_ending: bool = false

func _ready() -> void:
	story_sequence = _build_story_playback_sequence()
	if bg_music != null:
		bg_music.bus = "Music"
	next_indicator.visible = false

	# --- SKIP BUTTON LOGIC ---
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)

		# Optional: Fade in the button after 2 seconds so it doesn't distract immediately
		skip_button.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_interval(2.0)
		tween.tween_property(skip_button, "modulate:a", 0.7, 1.0) # Slightly transparent

	_play_line(current_line_index)
	_start_blink_loop()

func _process(delta: float) -> void:
	if is_ending: return
	if input_cooldown > 0.0:
		input_cooldown -= delta
		return
	if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if is_typing:
			_finish_typing()
			input_cooldown = cooldown_duration
		else:
			_next_line()
			input_cooldown = cooldown_duration

func _start_blink_loop() -> void:
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()

	blink_tween = create_tween()
	blink_tween.tween_interval(randf_range(2.0, 6.0))
	blink_tween.tween_callback(_do_blink)

func _do_blink() -> void:
	if portrait_left.texture == tex_vespera and portrait_left.visible and portrait_left.modulate.a > 0.9:
		var blink_act = create_tween()
		blink_act.tween_callback(func(): portrait_left.texture = tex_vespera_blink)
		blink_act.tween_interval(0.15)
		blink_act.tween_callback(func():
			if portrait_left.texture == tex_vespera_blink:
				portrait_left.texture = tex_vespera
		)
	_start_blink_loop()

func _play_line(index: int) -> void:
	if index >= story_sequence.size():
		_end_sequence()
		return
	var line_data: Dictionary = story_sequence[index]

	if line_data.has("volume"):
		current_volume_target = line_data["volume"]
	elif line_data.has("music") and line_data["music"] != "none" and not line_data.has("volume"):
		current_volume_target = base_volume

	if line_data.has("music"):
		_change_music(line_data["music"], current_volume_target)
	elif bg_music.playing and abs(bg_music.volume_db - current_volume_target) > 0.1:
		var vol_tween = create_tween()
		vol_tween.tween_property(bg_music, "volume_db", current_volume_target, 2.5)

	var mc_name: String = "Hero"
	var mc_portrait: Texture2D = null
	var mc_weapon: String = "blade"

	if CampaignManager.player_roster.size() > 0:
		var hero = CampaignManager.player_roster[0]
		mc_name = hero.get("unit_name", "Hero")
		mc_portrait = hero.get("portrait")
		var wpn: Variant = hero.get("weapon", null)
		if wpn != null and wpn is WeaponData:
			mc_weapon = (wpn as WeaponData).weapon_name
		else:
			var eq: Variant = hero.get("equipped_weapon", null)
			if eq != null and eq is WeaponData:
				mc_weapon = (eq as WeaponData).weapon_name

	var final_text: String = line_data["text"].replace("{hero_name}", mc_name).replace("{weapon_name}", mc_weapon)
	var final_speaker: String = line_data["speaker"].replace("{hero_name}", mc_name)

	if final_speaker == "":
		speaker_label.text = ""
		if speaker_label.get_parent() is Panel or speaker_label.get_parent() is NinePatchRect:
			speaker_label.get_parent().self_modulate.a = 0.0
	else:
		speaker_label.text = final_speaker
		if speaker_label.get_parent() is Panel or speaker_label.get_parent() is NinePatchRect:
			speaker_label.get_parent().self_modulate.a = 1.0

	dialogue_text.text = final_text

	if line_data["background"] != null:
		_animate_background(line_data["background"], line_data.get("fit_background", false))

	if line_illustration != null:
		if line_data.has("line_illustration") and line_data["line_illustration"] != null:
			line_illustration.texture = line_data["line_illustration"]
			line_illustration.visible = true
		else:
			line_illustration.visible = false

	var left_img = line_data["portrait_left"]
	if left_img is String and left_img == "HERO_PORTRAIT":
		left_img = mc_portrait

	var right_img = line_data["portrait_right"]
	if right_img is String and right_img == "HERO_PORTRAIT":
		right_img = mc_portrait

	var flip_l = line_data.get("flip_left", false)
	var flip_r = line_data.get("flip_right", false)

	_update_portrait(portrait_left, left_img, flip_l)
	_update_portrait(portrait_right, right_img, flip_r)

	# --- ACTIVE SPEAKER HIGHLIGHT, PULSE & LABEL SLIDE ---
	if speaker_pulse_tween and speaker_pulse_tween.is_valid():
		speaker_pulse_tween.kill()
	speaker_pulse_tween = create_tween().set_loops()

	portrait_left.self_modulate = Color(0.4, 0.4, 0.4)
	portrait_right.self_modulate = Color(0.4, 0.4, 0.4)
	portrait_left.scale = Vector2.ONE
	portrait_right.scale = Vector2.ONE

	var active_side = line_data.get("active_side", "none")
	var target_portrait = null

	if active_side == "left" and portrait_left.visible:
		target_portrait = portrait_left
	elif active_side == "right" and portrait_right.visible:
		target_portrait = portrait_right

	if target_portrait != null:
		target_portrait.self_modulate = Color.WHITE
		target_portrait.pivot_offset = Vector2(target_portrait.size.x / 2.0, target_portrait.size.y)

		speaker_pulse_tween.tween_property(target_portrait, "scale", Vector2(1.03, 1.03), 1.2).set_trans(Tween.TRANS_SINE)
		speaker_pulse_tween.tween_property(target_portrait, "scale", Vector2(1.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE)

		var target_x = target_portrait.global_position.x + (target_portrait.size.x / 2.0) - (speaker_label.size.x / 2.0)
		var max_x = get_viewport_rect().size.x - speaker_label.size.x - 20.0
		var clamped_x = clamp(target_x, 20.0, max_x)

		speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var label_slide = create_tween()
		label_slide.tween_property(speaker_label, "global_position:x", clamped_x, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		if final_speaker != "":
			var center_x = (get_viewport_rect().size.x / 2.0) - (speaker_label.size.x / 2.0)
			var label_slide = create_tween()
			label_slide.tween_property(speaker_label, "global_position:x", center_x, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if line_data.get("shake", false):
		_shake_node(background, 10.0, 0.4)
		_shake_node(portrait_right, 15.0, 0.4)

	dialogue_text.visible_characters = 0
	is_typing = true
	next_indicator.visible = false

	var total_chars = dialogue_text.text.length()
	var duration = total_chars * type_speed

	var tween = create_tween()
	tween.tween_method(_update_typing, 0, total_chars, duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(_finish_typing)

func _change_music(type: String, target_volume: float) -> void:
	if type == current_music_type:
		return
	current_music_type = type

	if music_tween and music_tween.is_valid():
		music_tween.kill()

	music_tween = create_tween()

	if type == "none":
		if bg_music.playing:
			music_tween.tween_property(bg_music, "volume_db", -40.0, 2.5)
			music_tween.tween_callback(func(): bg_music.stop())
		return

	var next_stream: AudioStream = null
	if type == "peaceful":
		next_stream = peaceful_music
	elif type == "tense":
		next_stream = tense_music
	elif type == "vespera":
		next_stream = vespera_music

	if next_stream == null:
		return

	if bg_music.playing:
		music_tween.tween_property(bg_music, "volume_db", -40.0, 2.5)
		music_tween.tween_callback(func():
			bg_music.stream = next_stream
			bg_music.play()
			var fade_in = create_tween()
			fade_in.tween_property(bg_music, "volume_db", target_volume, 2.5)
		)
	else:
		bg_music.stream = next_stream
		bg_music.volume_db = -40.0
		bg_music.play()
		music_tween.tween_property(bg_music, "volume_db", target_volume, 2.5)

func _update_portrait(portrait_node: TextureRect, new_texture: Texture2D, flip: bool) -> void:
	if portrait_node.texture == tex_vespera_blink and new_texture != tex_vespera:
		portrait_node.texture = tex_vespera

	if portrait_node.texture == new_texture and portrait_node.flip_h == flip:
		return

	var was_visible = portrait_node.texture != null and portrait_node.visible
	portrait_node.texture = new_texture
	portrait_node.flip_h = flip

	if new_texture != null:
		portrait_node.visible = true
		if not was_visible:
			portrait_node.modulate.a = 0.0
			var tween = create_tween()
			tween.tween_property(portrait_node, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	else:
		if was_visible:
			var tween = create_tween()
			tween.tween_property(portrait_node, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
			tween.tween_callback(func(): portrait_node.visible = false)
		else:
			portrait_node.visible = false

func _shake_node(node: Control, intensity: float, duration: float) -> void:
	var original_pos = node.position
	var shake_tween = create_tween()
	var steps = int(duration / 0.05)

	for i in range(steps):
		var random_offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		shake_tween.tween_property(node, "position", original_pos + random_offset, 0.05)

	shake_tween.tween_property(node, "position", original_pos, 0.05)

func _animate_background(new_texture: Texture2D, fit: bool = false) -> void:
	if background.texture == new_texture:
		return

	var fade_tween = create_tween()
	fade_tween.tween_property(background, "modulate", Color.BLACK, 0.4).set_trans(Tween.TRANS_SINE)
	fade_tween.tween_callback(func():
		background.texture = new_texture
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background.scale = Vector2(1.0, 1.0)
		background.pivot_offset = background.size / 2.0

		var fade_in = create_tween()
		fade_in.tween_property(background, "modulate", Color.WHITE, 0.4).set_trans(Tween.TRANS_SINE)

		if bg_tween and bg_tween.is_valid():
			bg_tween.kill()

		if not fit:
			bg_tween = create_tween()
			bg_tween.tween_property(background, "scale", Vector2(1.15, 1.15), 25.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	)

func _update_typing(count: int) -> void:
	if count > dialogue_text.visible_characters and count % 2 == 0:
		var current_char = dialogue_text.text.substr(count - 1, 1)
		if current_char != " " and text_blip.stream != null:
			text_blip.play()
	dialogue_text.visible_characters = count

func _finish_typing() -> void:
	dialogue_text.visible_characters = -1
	is_typing = false
	next_indicator.visible = true

func _next_line() -> void:
	current_line_index += 1
	_play_line(current_line_index)

func _end_sequence() -> void:
	is_ending = true
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()
	$DialoguePanel.visible = false
	portrait_left.visible = false
	portrait_right.visible = false
	if bg_music:
		var tween = create_tween()
		tween.tween_property(bg_music, "volume_db", -40.0, 2.0)
	await get_tree().create_timer(2.0).timeout
	SceneTransition.change_scene_to_file("res://Scenes/Levels/Level1.tscn")

func _on_skip_pressed() -> void:
	if is_ending: return

	if text_blip:
		text_blip.pitch_scale = 1.5
		text_blip.play()

	var tween = create_tween().set_parallel(true)
	tween.tween_property($DialoguePanel, "modulate:a", 0.0, 0.5)
	tween.tween_property(portrait_left, "modulate:a", 0.0, 0.5)
	tween.tween_property(portrait_right, "modulate:a", 0.0, 0.5)
	tween.tween_property(skip_button, "modulate:a", 0.0, 0.5)

	if bg_music:
		tween.tween_property(bg_music, "volume_db", -80.0, 0.5)

	await tween.finished
	_end_sequence_instant()

func _end_sequence_instant() -> void:
	is_ending = true
	if blink_tween and blink_tween.is_valid():
		blink_tween.kill()

	SceneTransition.change_scene_to_file("res://Scenes/Levels/Level1.tscn")
