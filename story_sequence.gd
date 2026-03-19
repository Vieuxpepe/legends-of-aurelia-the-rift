extends Control

@onready var background = $Background
@onready var portrait_left = $PortraitLeft
@onready var portrait_right = $PortraitRight
@onready var speaker_label = $DialoguePanel/SpeakerLabel
@onready var dialogue_text = $DialoguePanel/DialogueText
@onready var next_indicator = $DialoguePanel/NextIndicator
@onready var text_blip = $TextBlip
@onready var skip_button = $SkipButton

# --- MUSIC LOGIC ---
@onready var bg_music: AudioStreamPlayer = $BackgroundMusic
@export var peaceful_music: AudioStream
@export var tense_music: AudioStream
@export var vespera_music: AudioStream

var current_music_type: String = ""
var music_tween: Tween
var base_volume: float = -15.0
var current_volume_target: float = base_volume

# --- ASSETS ---
# Existing
var bg_peaceful_village = preload("res://Assets/Backgrounds/peaceful_village.jpeg")
var bg_attacked_village = preload("res://Assets/Backgrounds/attacked_village.png")
var bg_vespera_descent = preload("res://Assets/Backgrounds/vespera_descent.png")
var bg_burning_village = preload("res://Assets/Backgrounds/burning_village.png")

# NEW (Prologue slides) - create these files and place them in this folder.
# If you want different names/paths, just update these 4 lines.
var bg_prologue_void = preload("res://Assets/Backgrounds/prologue_void.png")
var bg_prologue_shattering_war = preload("res://Assets/Backgrounds/prologue_shattering_war.png")
var bg_prologue_catalyst_mark = preload("res://Assets/Backgrounds/prologue_catalyst_mark.png")
var bg_prologue_map = preload("res://Assets/Backgrounds/prologue_map.png")

# Base Portraits
var tex_vespera = preload("res://Assets/Portraits/vespera.png")
var tex_elder = preload("res://Assets/Portraits/elder.png")
var tex_kaelen_front = preload("res://Assets/Portraits/kaelen_front.png")
var tex_kaelen_front_yell = preload("res://Assets/Portraits/kaelen_front_yell.png")
var tex_kaelen_side = preload("res://Assets/Portraits/kaelen_side.png")
var tex_kaelen_side_yell = preload("res://Assets/Portraits/kaelen_side_yell.png")

# Vespera Expressions & Blink
var tex_vespera_smirk = preload("res://Assets/Portraits/vespera_smirk.png")
var tex_vespera_intrigued = preload("res://Assets/Portraits/vespera_intrigued.png")
var tex_vespera_disgusted = preload("res://Assets/Portraits/vespera_disgusted.png")
var tex_vespera_angry = preload("res://Assets/Portraits/vespera_angry.png")
var tex_vespera_blink = preload("res://Assets/Portraits/vespera_blink.png")
var tex_acolyte = preload("res://Assets/Portraits/shadow_acolyte.png")

var bg_tween: Tween
var blink_tween: Tween
var speaker_pulse_tween: Tween # --- TWEEN FOR BREATHING ANIMATION ---

var input_cooldown: float = 0.0
var cooldown_duration: float = 0.35

# --- STORY SEQUENCE ---
# Added a Wind-Waker-style prologue (4 slides) + the extra bridge line.
# Then your existing Oakhaven lines start unchanged.
var story_sequence = [
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

var current_line_index: int = 0
var is_typing: bool = false
var type_speed: float = 0.03
var is_ending: bool = false

func _ready() -> void:
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

	var line_data = story_sequence[index]

	if line_data.has("volume"):
		current_volume_target = line_data["volume"]
	elif line_data.has("music") and line_data["music"] != "none" and not line_data.has("volume"):
		current_volume_target = base_volume

	if line_data.has("music"):
		_change_music(line_data["music"], current_volume_target)
	elif bg_music.playing and abs(bg_music.volume_db - current_volume_target) > 0.1:
		var vol_tween = create_tween()
		vol_tween.tween_property(bg_music, "volume_db", current_volume_target, 2.5)

	var mc_name = "Hero"
	var mc_portrait = null
	var mc_weapon = "blade"

	if CampaignManager.player_roster.size() > 0:
		var hero = CampaignManager.player_roster[0]
		mc_name = hero.get("unit_name", "Hero")
		mc_portrait = hero.get("portrait")
		if hero.get("weapon") != null:
			mc_weapon = hero.weapon.weapon_name

	var final_text = line_data["text"].replace("{hero_name}", mc_name).replace("{weapon_name}", mc_weapon)
	var final_speaker = line_data["speaker"].replace("{hero_name}", mc_name)

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
