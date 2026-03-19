extends Control

@onready var background = $Background
@onready var portrait_left = $PortraitLeft
@onready var portrait_right = $PortraitRight
@onready var portrait_right_small = $PortraitRightSmall
@onready var speaker_label = $DialoguePanel/SpeakerLabel
@onready var dialogue_text = $DialoguePanel/DialogueText
@onready var next_indicator = $DialoguePanel/NextIndicator
@onready var text_blip = $TextBlip
@onready var skip_button = $SkipButton
@onready var bg_music: AudioStreamPlayer = $BackgroundMusic
@export var forest_music: AudioStream # Eerie, quiet woods
@export var camp_music: AudioStream # Bartholomew's quirky theme

var current_music_type: String = ""
var music_tween: Tween
var base_volume: float = -15.0 
var current_volume_target: float = base_volume

var bg_dark_forest = preload("res://Assets/Backgrounds/dark_forest_burning.jpeg")
var bg_camp_exterior = preload("res://Assets/Backgrounds/merchant_camp_night.jpeg")

var tex_kaelen_side = preload("res://Assets/Portraits/kaelen_side.png")
var tex_kaelen_side_yell = preload("res://Assets/Portraits/kaelen_side_yell.png")
var tex_bartholomew = preload("res://Assets/Portraits/Bartholomew Portrait.png") 

var bg_tween: Tween
var speaker_pulse_tween: Tween # --- NEW TWEEN FOR BREATHING ANIMATION ---
var input_cooldown: float = 0.0
var cooldown_duration: float = 0.35

# --- ADDED 'active_side' TO EVERY LINE ---
var story_sequence = [
	{
		"speaker": "",
		"text": "The shrieks of the dying village fade into the dense, suffocating canopy of the Emberwood.",
		"portrait_left": null,
		"portrait_right": null,
		"background": bg_dark_forest,
		"music": "forest",
		"active_side": "none"
	},
	{
		"speaker": "Veteran",
		"text": "Keep moving, rookie. If Vespera's hounds catch our scent, we're dead. Don't look back.",
		"portrait_left": tex_kaelen_side,
		"portrait_right": null,
		"background": bg_dark_forest,
		"active_side": "left"
	},
	{
		"speaker": "{hero_name}",
		"text": "Wait. Look ahead through the trees... Is that a campfire?",
		"portrait_left": tex_kaelen_side,
		"portrait_right": "HERO_PORTRAIT",
		"flip_right": true,
		"background": bg_dark_forest,
		"active_side": "right"
	},
	{
		"speaker": "Veteran",
		"text": "Damn it. A Vanguard patrol? Weapons up. Stay in my shadow.",
		"portrait_left": tex_kaelen_side_yell,
		"portrait_right": "HERO_PORTRAIT",
		"flip_right": true,
		"shake": true,
		"background": bg_dark_forest,
		"active_side": "left"
	},
	{
		"speaker": "???",
		"text": "Careful with the steel! If you puncture the donkey, I will charge you for the beast AND his emotional trauma.",
		"portrait_left": tex_kaelen_side_yell,
		"portrait_right": tex_bartholomew,
		"background": bg_camp_exterior,
		"music": "camp",
		"active_side": "right"
	},
	{
		"speaker": "Veteran",
		"text": "A merchant? Are you out of your mind? The sky is literally tearing open a mile away!",
		"portrait_left": tex_kaelen_side_yell,
		"portrait_right": tex_bartholomew,
		"background": bg_camp_exterior,
		"shake": true,
		"active_side": "left"
	},
	{
		"speaker": "Bartholomew",
		"text": "Do apocalyptic horrors carry coin purses? No. Do terrified, heavily-armed refugees carry coin purses? Often, yes. It is basic economics.",
		"portrait_left": tex_kaelen_side,
		"portrait_right": tex_bartholomew,
		"background": bg_camp_exterior,
		"active_side": "right"
	},
	{
		"speaker": "Bartholomew",
		"text": "...Wait. Squinting in the dark... the battered armor, the sheer aura of underpaid exhaustion. Kaelen? Is that you?",
		"portrait_left": tex_kaelen_side,
		"portrait_right": tex_bartholomew,
		"background": bg_camp_exterior,
		"active_side": "right"
	},
	{
		"speaker": "{hero_name}",
		"text": "Kaelen? You didn't even tell me your name.",
		"portrait_left": "HERO_PORTRAIT",
		"portrait_right": tex_bartholomew,
		"flip_left": true,
		"background": bg_camp_exterior,
		"active_side": "left"
	},
	{
		"speaker": "Kaelen",
		"text": "We were a bit busy not getting sacrificed to a dark god, rookie. And Bartholomew, I thought the Merchants Guild hanged you for smuggling.",
		"portrait_left": tex_kaelen_side_yell,
		"portrait_right": tex_bartholomew,
		"background": bg_camp_exterior,
		"active_side": "left"
	},
	{
		"speaker": "Bartholomew",
		"text": "They certainly tried! But the rope snapped. A true miracle of terrible, cheap craftsmanship. Anyway, I deduce you two are heading directly into fatal danger?",
		"portrait_left": tex_kaelen_side,
		"portrait_right": tex_bartholomew,
		"background": bg_camp_exterior,
		"active_side": "right"
	},
	{
		"speaker": "Kaelen",
		"text": "We're tracking Vespera's cult, yes. Now step aside, we are moving out.",
		"portrait_left": tex_kaelen_side,
		"portrait_right": tex_bartholomew,
		"background": bg_camp_exterior,
		"active_side": "left"
	},
	{
		"speaker": "Bartholomew",
		"text": "Excellent! ''Heroes'' have a notoriously high mortality rate. Which means you will be consistently desperate for my vastly overpriced healing salves!",
		"portrait_left": tex_kaelen_side,
		"portrait_right": tex_bartholomew,
		"background": bg_camp_exterior,
		"active_side": "right"
	},
	{
		"speaker": "Bartholomew",
		"text": "I shall attach my storefront to your glorious crusade. Think of me as your mobile, highly-profitable guardian angel.",
		"portrait_left": tex_kaelen_side,
		"portrait_right": tex_bartholomew,
		"background": bg_camp_exterior,
		"active_side": "right"
	},
	{
		"speaker": "Kaelen",
		"text": "Absolutely not. We aren't babysitting a swindler. Stay here.",
		"portrait_left": tex_kaelen_side_yell,
		"portrait_right": tex_bartholomew,
		"shake": true,
		"background": bg_camp_exterior,
		"active_side": "left"
	},
	{
		"speaker": "Bartholomew",
		"text": "I have a donkey. And he is carrying the premium potions.",
		"portrait_left": tex_kaelen_side,
		"portrait_right": tex_bartholomew,
		"background": bg_camp_exterior,
		"active_side": "right"
	},
	{
		"speaker": "Kaelen",
		"text": "...Fine. But you stay at the back of the convoy.",
		"portrait_left": tex_kaelen_side,
		"portrait_right": tex_bartholomew,
		"background": bg_camp_exterior,
		"active_side": "left"
	}
]

var current_line_index: int = 0
var is_typing: bool = false
var type_speed: float = 0.03
var is_ending: bool = false

func _ready() -> void:
	next_indicator.visible = false
	# Ensure the small portrait is hidden at start
	if portrait_right_small: portrait_right_small.visible = false
	
	# --- ADD THIS SKIP LOGIC ---
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)
		skip_button.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_interval(2.0)
		tween.tween_property(skip_button, "modulate:a", 0.7, 1.0)
	# ---------------------------
		
	_play_line(current_line_index)

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

func _play_line(index: int) -> void:
	if index >= story_sequence.size():
		_end_sequence()
		return
		
	var line_data = story_sequence[index]
	
	# --- AUDIO LOGIC ---
	if line_data.has("volume"):
		current_volume_target = line_data["volume"]
	elif line_data.has("music") and line_data["music"] != "none" and not line_data.has("volume"):
		current_volume_target = base_volume
	
	if line_data.has("music"):
		_change_music(line_data["music"], current_volume_target)
	
	# --- NAME REPLACEMENT ---
	var mc_name = "Hero"
	var mc_portrait = null
	
	if CampaignManager.player_roster.size() > 0:
		var hero = CampaignManager.player_roster[0]
		mc_name = hero.get("unit_name", "Hero")
		mc_portrait = hero.get("portrait")
	
	var final_text = line_data["text"].replace("{hero_name}", mc_name)
	var final_speaker = line_data["speaker"].replace("{hero_name}", mc_name)
	
	# --- SPEAKER LABEL VISIBILITY ---
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
		
	# --- PORTRAIT LOGIC ---
	var left_img = line_data["portrait_left"]
	if left_img is String and left_img == "HERO_PORTRAIT": left_img = mc_portrait
		
	var right_img = line_data["portrait_right"]
	if right_img is String and right_img == "HERO_PORTRAIT": right_img = mc_portrait
		
	var flip_l = line_data.get("flip_left", false)
	var flip_r = line_data.get("flip_right", false)
	
	_update_portrait(portrait_left, left_img, flip_l)

	# 2. NEW LOGIC: CHOOSE WHICH RIGHT PORTRAIT TO USE
	if right_img == tex_bartholomew:
		# If it's the dwarf, use the Small node, hide the Big node
		portrait_right.visible = false 
		_update_portrait(portrait_right_small, right_img, flip_r)
	else:
		# If it's anyone else, use Big node, hide Small node
		portrait_right_small.visible = false
		_update_portrait(portrait_right, right_img, flip_r)
	
	# --- PULSE / HIGHLIGHT ANIMATION ---
	if speaker_pulse_tween and speaker_pulse_tween.is_valid():
		speaker_pulse_tween.kill()
	speaker_pulse_tween = create_tween().set_loops()
	
	# Reset all portraits to dim
	portrait_left.self_modulate = Color(0.4, 0.4, 0.4)
	portrait_right.self_modulate = Color(0.4, 0.4, 0.4)
	portrait_right_small.self_modulate = Color(0.4, 0.4, 0.4) # Don't forget small!
	
	portrait_left.scale = Vector2.ONE
	portrait_right.scale = Vector2.ONE
	portrait_right_small.scale = Vector2.ONE # Reset scale for small too
	
	var active_side = line_data.get("active_side", "none")
	var target_portrait = null
	
	if active_side == "left" and portrait_left.visible:
		target_portrait = portrait_left
	elif active_side == "right":
		# Check which right portrait is actually active
		if portrait_right.visible:
			target_portrait = portrait_right
		elif portrait_right_small.visible:
			target_portrait = portrait_right_small
		
	if target_portrait != null:
		# Brighten the active speaker
		target_portrait.self_modulate = Color.WHITE
		target_portrait.pivot_offset = target_portrait.size / 2.0
		
		# Pulse Animation
		speaker_pulse_tween.tween_property(target_portrait, "scale", Vector2(1.03, 1.03), 1.2).set_trans(Tween.TRANS_SINE)
		speaker_pulse_tween.tween_property(target_portrait, "scale", Vector2(1.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE)
		
		# Slide label to active speaker
		var target_x = target_portrait.global_position.x + (target_portrait.size.x / 2.0) - (speaker_label.size.x / 2.0)
		
		# Clamp so label doesn't go off screen
		var max_x = get_viewport_rect().size.x - speaker_label.size.x - 20.0
		var clamped_x = clamp(target_x, 20.0, max_x)
		
		var label_slide = create_tween()
		label_slide.tween_property(speaker_label, "global_position:x", clamped_x, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# --- SHAKE LOGIC ---
	if line_data.get("shake", false):
		_shake_node(background, 10.0, 0.4)
		
		# Shake whichever right portrait is visible
		if portrait_right.visible:
			_shake_node(portrait_right, 15.0, 0.4)
		elif portrait_right_small.visible:
			_shake_node(portrait_right_small, 15.0, 0.4)
	
	# --- TYPING ---
	dialogue_text.visible_characters = 0
	is_typing = true
	next_indicator.visible = false
	
	var total_chars = dialogue_text.text.length()
	var duration = total_chars * type_speed
	var tween = create_tween()
	tween.tween_method(_update_typing, 0, total_chars, duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(_finish_typing)

func _change_music(type: String, target_volume: float) -> void:
	if type == current_music_type: return
	current_music_type = type
	
	if music_tween and music_tween.is_valid(): music_tween.kill()
	music_tween = create_tween()
	
	var next_stream: AudioStream = null
	if type == "forest": next_stream = forest_music
	elif type == "camp": next_stream = camp_music
		
	if next_stream == null: return
		
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

# This helper remains the same, we just call it on different nodes now
func _update_portrait(portrait_node: TextureRect, new_texture: Texture2D, flip: bool) -> void:
	# Small optimization: if it's already set, don't restart animation
	if portrait_node.texture == new_texture and portrait_node.flip_h == flip and portrait_node.visible: 
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
	if background.texture == new_texture: return
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
		
		if bg_tween and bg_tween.is_valid(): bg_tween.kill()
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
	$DialoguePanel.visible = false
	portrait_left.visible = false
	portrait_right.visible = false
	# Ensure small portrait is hidden too
	if portrait_right_small: portrait_right_small.visible = false
	
	if bg_music:
		var tween = create_tween()
		tween.tween_property(bg_music, "volume_db", -40.0, 2.0)
	await get_tree().create_timer(2.0).timeout
	
	SceneTransition.change_scene_to_file("res://Scenes/camp_menu.tscn")

func _on_skip_pressed() -> void:
	if is_ending: return
	
	if text_blip:
		text_blip.pitch_scale = 1.5
		text_blip.play()
		
	var tween = create_tween().set_parallel(true)
	tween.tween_property($DialoguePanel, "modulate:a", 0.0, 0.5)
	tween.tween_property(portrait_left, "modulate:a", 0.0, 0.5)
	tween.tween_property(portrait_right, "modulate:a", 0.0, 0.5)
	if portrait_right_small: tween.tween_property(portrait_right_small, "modulate:a", 0.0, 0.5)
	tween.tween_property(skip_button, "modulate:a", 0.0, 0.5)
	
	if bg_music:
		tween.tween_property(bg_music, "volume_db", -80.0, 0.5)
		
	await tween.finished
	_end_sequence_instant()

func _end_sequence_instant() -> void:
	is_ending = true
	SceneTransition.change_scene_to_file("res://Scenes/camp_menu.tscn")
