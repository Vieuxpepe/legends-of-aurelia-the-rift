# Full-screen scripted dialogue beat: Haldor forge solos, roster bond scenes, world encounters.
# Replaces the removed HaldorSoloScene; entered via [method CampaignManager.begin_narrative_beat] → [member CampaignManager.NARRATIVE_BEAT_SCENE_PATH].
# Data from [method DialogueDatabase.get_narrative_beat_playback_lines]; return path on [member CampaignManager.narrative_beat_return_scene_path].
extends Control

@onready var background: TextureRect = $Background
@onready var portrait_left: TextureRect = $PortraitLeft
@onready var portrait_right: TextureRect = $PortraitRight
@onready var dialogue_panel: Panel = $DialoguePanel
@onready var speaker_label: Label = $DialoguePanel/SpeakerLabel
@onready var dialogue_text: RichTextLabel = $DialoguePanel/DialogueText
@onready var next_indicator: TextureButton = $DialoguePanel/NextIndicator
@onready var text_blip: AudioStreamPlayer = $TextBlip
@onready var skip_button: TextureButton = $SkipButton
@onready var line_illustration: TextureRect = get_node_or_null("LineIllustration") as TextureRect

@onready var bg_music: AudioStreamPlayer = $BackgroundMusic
@export var peaceful_music: AudioStream
@export var tense_music: AudioStream
@export var vespera_music: AudioStream
## Default BGM when line [code]music: "haldor_solo"[/code] (shared campfire track for early roster beats too).
@export var haldor_solo_music: AudioStream

var story_sequence: Array[Dictionary] = []
var active_beat_id: String = ""

var music_tween: Tween
var speaker_pulse_tween: Tween
var _line_tween: Tween
var _portrait_breathe_target: TextureRect = null

var current_line_index: int = 0
var is_typing: bool = false
var type_speed: float = 0.03
var is_ending: bool = false

var input_cooldown: float = 0.0
var cooldown_duration: float = 0.35
var current_music_type: String = ""
var base_volume: float = -15.0
var current_volume_target: float = base_volume

var _inject_tail: Array[Dictionary] = []
var _awaiting_choice: bool = false
var _line_in_progress: Dictionary = {}
var _choice_row: HBoxContainer
var _choice_canvas: CanvasLayer
var _choice_holder: Control
var _dialogue_click_backdrop: ColorRect
var _continue_hint_layer: CanvasLayer
var _continue_hint: Label


func _ready() -> void:
	active_beat_id = str(CampaignManager.pending_narrative_beat_id).strip_edges()
	story_sequence = DialogueDatabase.get_narrative_beat_playback_lines(active_beat_id)
	if line_illustration != null:
		line_illustration.visible = false
	if bg_music != null:
		bg_music.bus = "Music"
	var resolved_solo_bgm: AudioStream = _load_haldor_solo_bgm()
	if resolved_solo_bgm != null:
		haldor_solo_music = resolved_solo_bgm
	_ensure_audio_stream_loops(haldor_solo_music)
	# RichTextLabel defaults to MOUSE_FILTER_STOP and overlaps the choice row; it would eat clicks on tone buttons.
	if dialogue_text:
		dialogue_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if speaker_label:
		speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_dialogue_click_backdrop()
	_setup_continue_hint()
	_setup_choice_row()
	if next_indicator:
		next_indicator.visible = false
	_set_continue_hint_visible(false)
	if skip_button:
		skip_button.pressed.connect(_on_skip_pressed)
		skip_button.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_interval(2.0)
		tween.tween_property(skip_button, "modulate:a", 0.7, 1.0)

	if story_sequence.is_empty():
		call_deferred("_abort_invalid_scene")
		return

	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_present_line_data(story_sequence[0])


## Full-panel hit target behind speaker/text/next so clicks reach a leaf Control. Do not use Panel.gui_input — it can run for subtree input and steal TextureButton clicks.
func _setup_dialogue_click_backdrop() -> void:
	_dialogue_click_backdrop = ColorRect.new()
	_dialogue_click_backdrop.name = "DialogueClickBackdrop"
	_dialogue_click_backdrop.color = Color(1, 1, 1, 0)
	_dialogue_click_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialogue_click_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialogue_click_backdrop.gui_input.connect(_on_dialogue_click_backdrop_gui_input)
	dialogue_panel.add_child(_dialogue_click_backdrop)
	dialogue_panel.move_child(_dialogue_click_backdrop, 0)


func _setup_continue_hint() -> void:
	_continue_hint_layer = CanvasLayer.new()
	_continue_hint_layer.name = "ContinueHintLayer"
	_continue_hint_layer.layer = 90
	add_child(_continue_hint_layer)
	_continue_hint = Label.new()
	_continue_hint.name = "ContinueHintLabel"
	_continue_hint.text = "Press space to continue..."
	_continue_hint.add_theme_font_size_override("font_size", 17)
	_continue_hint.modulate = Color(1, 1, 1, 0.5)
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_continue_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_continue_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_continue_hint.offset_left = -420.0
	_continue_hint.offset_top = -44.0
	_continue_hint.offset_right = -28.0
	_continue_hint.offset_bottom = -18.0
	_continue_hint_layer.add_child(_continue_hint)
	_continue_hint.visible = false


func _set_continue_hint_visible(on: bool) -> void:
	if _continue_hint != null:
		_continue_hint.visible = on


func _set_choice_canvas_visible(on: bool) -> void:
	if _choice_canvas != null:
		_choice_canvas.visible = on


func _setup_choice_row() -> void:
	# CanvasLayer keeps choices above portraits / panel stacking; avoids lost hits from deep Control trees.
	_choice_canvas = CanvasLayer.new()
	_choice_canvas.name = "ChoiceToneCanvas"
	_choice_canvas.layer = 80
	add_child(_choice_canvas)
	_choice_holder = Control.new()
	_choice_holder.name = "ChoiceHolder"
	_choice_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_canvas.add_child(_choice_holder)
	_choice_row = HBoxContainer.new()
	_choice_row.name = "ChoiceToneRow"
	_choice_row.add_theme_constant_override("separation", 10)
	_choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_row.visible = false
	_choice_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_choice_holder.add_child(_choice_row)
	_choice_row.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# Invisible full-screen CanvasLayers can still block input to layers below in some setups — keep off until choices show.
	_choice_canvas.visible = false


func _refresh_choice_row_layout() -> void:
	if _choice_row == null or dialogue_panel == null:
		return
	var pr: Rect2 = dialogue_panel.get_global_rect()
	_choice_row.position = pr.position + Vector2(24.0, pr.size.y - 118.0)
	_choice_row.size = Vector2(maxf(80.0, pr.size.x - 48.0), 90.0)


func _on_viewport_size_changed() -> void:
	if _choice_row != null and _choice_row.visible:
		_refresh_choice_row_layout()


func _abort_invalid_scene() -> void:
	if active_beat_id != "":
		push_warning("NarrativeBeatScene: no lines for beat id '%s'; returning." % active_beat_id)
	CampaignManager.pending_narrative_beat_id = ""
	SceneTransition.change_scene_to_file(CampaignManager.narrative_beat_return_scene_path)


func _process(delta: float) -> void:
	if is_ending:
		return
	if input_cooldown > 0.0:
		input_cooldown -= delta


## Space / ui_accept — mouse still uses [method _on_dialogue_click_backdrop_gui_input].
func _unhandled_input(event: InputEvent) -> void:
	if is_ending or _awaiting_choice:
		return
	if input_cooldown > 0.0:
		return
	var want: bool = event.is_action_pressed("ui_accept")
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE:
			want = true
	if not want:
		return
	get_viewport().set_input_as_handled()
	input_cooldown = cooldown_duration
	if is_typing:
		_finish_typing()
	else:
		_advance_dialogue()


func _on_dialogue_click_backdrop_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_dialogue_click_backdrop.accept_event()
	get_viewport().set_input_as_handled()
	_try_advance_dialogue_from_ui()


func _try_advance_dialogue_from_ui() -> void:
	if is_ending or _awaiting_choice:
		return
	if input_cooldown > 0.0:
		return
	input_cooldown = cooldown_duration
	if is_typing:
		_finish_typing()
	else:
		_advance_dialogue()


func _advance_dialogue() -> void:
	if _inject_tail.size() > 0:
		_present_line_data(_inject_tail.pop_front())
		return
	current_line_index += 1
	if current_line_index >= story_sequence.size():
		_end_sequence(true)
		return
	_present_line_data(story_sequence[current_line_index])


func _present_line_data(line_data: Dictionary) -> void:
	_line_in_progress = line_data
	if _line_tween != null and _line_tween.is_valid():
		_line_tween.kill()
		_line_tween = null

	if line_data.has("volume"):
		current_volume_target = line_data["volume"]
	elif line_data.has("music") and line_data["music"] != "none" and not line_data.has("volume"):
		current_volume_target = base_volume

	if line_data.has("music"):
		_change_music(str(line_data["music"]), current_volume_target)
	elif bg_music.playing and abs(bg_music.volume_db - current_volume_target) > 0.1:
		var vol_tween = create_tween()
		vol_tween.tween_property(bg_music, "volume_db", current_volume_target, 2.5)

	var mc_name: String = "Hero"
	var mc_portrait: Texture2D = null
	var mc_weapon: String = "blade"

	if CampaignManager.player_roster.size() > 0:
		var hero = CampaignManager.player_roster[0]
		mc_name = str(hero.get("unit_name", "Hero"))
		mc_portrait = hero.get("portrait")
		var wpn: Variant = hero.get("weapon", null)
		if wpn != null and wpn is WeaponData:
			mc_weapon = (wpn as WeaponData).weapon_name
		else:
			var eq: Variant = hero.get("equipped_weapon", null)
			if eq != null and eq is WeaponData:
				mc_weapon = (eq as WeaponData).weapon_name

	var raw_text: String = str(line_data.get("text", ""))
	var raw_speaker: String = str(line_data.get("speaker", ""))
	var final_text: String = raw_text.replace("{hero_name}", mc_name).replace("{weapon_name}", mc_weapon)
	var final_speaker: String = raw_speaker.replace("{hero_name}", mc_name)

	if final_speaker.strip_edges() == "":
		speaker_label.text = ""
		if speaker_label.get_parent() is Panel or speaker_label.get_parent() is NinePatchRect:
			speaker_label.get_parent().self_modulate.a = 0.0
	else:
		speaker_label.text = final_speaker
		if speaker_label.get_parent() is Panel or speaker_label.get_parent() is NinePatchRect:
			speaker_label.get_parent().self_modulate.a = 1.0

	dialogue_text.text = final_text

	var bg_tex: Variant = line_data.get("background", null)
	if bg_tex is Texture2D:
		_animate_background(bg_tex as Texture2D, bool(line_data.get("fit_background", false)))

	var left_img: Variant = line_data.get("portrait_left", null)
	if left_img is String and str(left_img) == "HERO_PORTRAIT":
		left_img = mc_portrait

	var right_img: Variant = line_data.get("portrait_right", null)
	if right_img is String and str(right_img) == "HERO_PORTRAIT":
		right_img = mc_portrait

	var flip_l: bool = bool(line_data.get("flip_left", false))
	var flip_r: bool = bool(line_data.get("flip_right", false))

	var li_tex: Texture2D = left_img if left_img is Texture2D else null
	var ri_tex: Texture2D = right_img if right_img is Texture2D else null
	_update_portrait(portrait_left, li_tex, flip_l)
	_update_portrait(portrait_right, ri_tex, flip_r)

	var active_side: String = str(line_data.get("active_side", "none"))
	var target_portrait: TextureRect = null
	if active_side == "left" and portrait_left.visible:
		target_portrait = portrait_left
	elif active_side == "right" and portrait_right.visible:
		target_portrait = portrait_right

	var continue_breathe: bool = target_portrait != null and target_portrait == _portrait_breathe_target
	if not continue_breathe:
		if speaker_pulse_tween and speaker_pulse_tween.is_valid():
			speaker_pulse_tween.kill()
		portrait_left.scale = Vector2.ONE
		portrait_right.scale = Vector2.ONE
		_portrait_breathe_target = target_portrait

	portrait_left.self_modulate = Color(0.4, 0.4, 0.4)
	portrait_right.self_modulate = Color(0.4, 0.4, 0.4)

	if target_portrait != null:
		target_portrait.self_modulate = Color.WHITE
		target_portrait.pivot_offset = Vector2(target_portrait.size.x / 2.0, target_portrait.size.y)
		if not continue_breathe:
			speaker_pulse_tween = create_tween().set_loops()
			speaker_pulse_tween.tween_property(target_portrait, "scale", Vector2(1.03, 1.03), 1.2).set_trans(Tween.TRANS_SINE)
			speaker_pulse_tween.tween_property(target_portrait, "scale", Vector2(1.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE)
		var target_x = target_portrait.global_position.x + (target_portrait.size.x / 2.0) - (speaker_label.size.x / 2.0)
		var max_x = get_viewport_rect().size.x - speaker_label.size.x - 20.0
		var clamped_x = clampf(target_x, 20.0, max_x)
		speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var label_slide = create_tween()
		label_slide.tween_property(speaker_label, "global_position:x", clamped_x, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif final_speaker.strip_edges() != "":
		var center_x = (get_viewport_rect().size.x / 2.0) - (speaker_label.size.x / 2.0)
		var label_slide2 = create_tween()
		label_slide2.tween_property(speaker_label, "global_position:x", center_x, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if bool(line_data.get("shake", false)):
		_shake_node(background, 10.0, 0.4)
		_shake_node(portrait_right, 15.0, 0.4)

	dialogue_text.visible_characters = 0
	is_typing = true
	_set_continue_hint_visible(false)
	_set_choice_canvas_visible(false)
	_choice_row.visible = false
	_awaiting_choice = false
	_clear_choice_buttons()

	var total_chars: int = dialogue_text.text.length()
	if total_chars <= 0:
		_finish_typing()
		return
	var duration: float = total_chars * type_speed
	_line_tween = create_tween()
	_line_tween.tween_method(_update_typing, 0, total_chars, duration).set_trans(Tween.TRANS_LINEAR)
	_line_tween.tween_callback(_finish_typing)


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
	if type == "haldor_solo":
		next_stream = haldor_solo_music if haldor_solo_music != null else peaceful_music
	elif type == "peaceful":
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
	if portrait_node.texture == new_texture and portrait_node.flip_h == flip:
		return
	var old_tex: Texture2D = portrait_node.texture as Texture2D
	var was_visible: bool = portrait_node.texture != null and portrait_node.visible
	portrait_node.flip_h = flip

	if new_texture != null:
		portrait_node.visible = true
		if was_visible and old_tex != null and old_tex != new_texture:
			var fade_out_s: float = 0.11
			var fade_in_s: float = 0.14
			var tw = create_tween()
			tw.tween_property(portrait_node, "modulate:a", 0.0, fade_out_s).set_trans(Tween.TRANS_SINE)
			tw.tween_callback(func():
				portrait_node.texture = new_texture
				var tw2 = create_tween()
				tw2.tween_property(portrait_node, "modulate:a", 1.0, fade_in_s).set_trans(Tween.TRANS_SINE)
			)
		elif not was_visible:
			portrait_node.texture = new_texture
			portrait_node.modulate.a = 0.0
			var tween = create_tween()
			tween.tween_property(portrait_node, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
		else:
			portrait_node.texture = new_texture
			portrait_node.modulate.a = 1.0
	else:
		if was_visible:
			var tween2 = create_tween()
			tween2.tween_property(portrait_node, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
			tween2.tween_callback(func(): portrait_node.visible = false)
		else:
			portrait_node.visible = false


func _load_haldor_solo_bgm() -> AudioStream:
	for path in [
		"res://Assets/Haldor/Haldor\u2019s Quiet Hour.mp3",
		"res://Assets/Haldor/Haldor's Quiet Hour.mp3",
	]:
		if ResourceLoader.exists(path):
			var st: AudioStream = load(path) as AudioStream
			if st != null:
				return st
	return haldor_solo_music


func _ensure_audio_stream_loops(stream: AudioStream) -> void:
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


func _shake_node(node: Control, intensity: float, duration: float) -> void:
	var original_pos = node.position
	var shake_tween = create_tween()
	var steps: int = int(duration / 0.05)
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
	)


func _update_typing(count: int) -> void:
	if count > dialogue_text.visible_characters and count % 2 == 0:
		var body: String = dialogue_text.text
		if count > 0 and count <= body.length():
			var current_char = body.substr(count - 1, 1)
			if current_char != " " and text_blip.stream != null:
				text_blip.play()
	dialogue_text.visible_characters = count


func _finish_typing() -> void:
	if _line_tween != null and _line_tween.is_valid():
		_line_tween.kill()
		_line_tween = null
	dialogue_text.visible_characters = -1
	is_typing = false
	var pc: Variant = _line_in_progress.get("player_choice", null)
	if pc != null and pc is Dictionary:
		_show_tone_choice(pc as Dictionary)
	else:
		_set_continue_hint_visible(true)


func _default_tone_id(pc: Dictionary) -> String:
	var opts: Variant = pc.get("options", [])
	if opts is Array and (opts as Array).size() > 0:
		var first: Variant = (opts as Array)[0]
		if first is Dictionary:
			var id0: String = str((first as Dictionary).get("id", "stoic")).strip_edges()
			if id0 != "":
				return id0
	var react: Variant = pc.get("reactions", null)
	if react is Dictionary and (react as Dictionary).size() > 0:
		return str((react as Dictionary).keys()[0])
	return "stoic"


func _show_tone_choice(pc: Dictionary) -> void:
	_clear_choice_buttons()
	var opts: Variant = pc.get("options", [])
	if not (opts is Array):
		_set_continue_hint_visible(true)
		return
	for o_raw in opts as Array:
		if not (o_raw is Dictionary):
			continue
		var o: Dictionary = o_raw as Dictionary
		var tid: String = str(o.get("id", "")).strip_edges()
		var lbl: String = str(o.get("label", "")).strip_edges()
		if tid == "" or lbl == "":
			continue
		var btn: Button = Button.new()
		btn.text = lbl
		btn.add_theme_font_size_override("font_size", 22)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.focus_mode = Control.FOCUS_ALL
		btn.custom_minimum_size = Vector2(120.0, 44.0)
		btn.pressed.connect(_on_tone_chosen.bind(tid))
		_choice_row.add_child(btn)
	if _choice_row.get_child_count() == 0:
		_set_continue_hint_visible(true)
		return
	_refresh_choice_row_layout()
	call_deferred("_refresh_choice_row_layout")
	_choice_row.visible = true
	_set_choice_canvas_visible(true)
	_awaiting_choice = true
	_set_continue_hint_visible(false)
	var first_btn: Node = _choice_row.get_child(0)
	if first_btn is Control:
		(first_btn as Control).grab_focus()


func _clear_choice_buttons() -> void:
	for c in _choice_row.get_children():
		c.queue_free()


func _on_tone_chosen(tone_id: String) -> void:
	if not _awaiting_choice:
		return
	_awaiting_choice = false
	_choice_row.visible = false
	_set_choice_canvas_visible(false)
	_clear_choice_buttons()
	var pc: Variant = _line_in_progress.get("player_choice", null)
	if pc == null or not (pc is Dictionary):
		_advance_dialogue()
		return
	var react: Variant = (pc as Dictionary).get("reactions", null)
	if react == null or not (react is Dictionary):
		_advance_dialogue()
		return
	var arr: Variant = (react as Dictionary).get(tone_id, [])
	_inject_tail.clear()
	if arr is Array:
		for item in arr as Array:
			if item is Dictionary:
				_inject_tail.append((item as Dictionary).duplicate(true))
	if _inject_tail.size() > 0:
		_present_line_data(_inject_tail.pop_front())
	else:
		_advance_dialogue()


func _end_sequence(mark_seen: bool) -> void:
	is_ending = true
	if speaker_pulse_tween and speaker_pulse_tween.is_valid():
		speaker_pulse_tween.kill()
	_portrait_breathe_target = null
	if mark_seen and active_beat_id != "":
		CampaignManager.mark_narrative_beat_seen(active_beat_id)
		CampaignManager.try_grant_narrative_beat_rewards(active_beat_id)
	CampaignManager.pending_narrative_beat_id = ""
	$DialoguePanel.visible = false
	_set_continue_hint_visible(false)
	_set_choice_canvas_visible(false)
	if _choice_row != null:
		_choice_row.visible = false
	portrait_left.visible = false
	portrait_right.visible = false
	if bg_music:
		var tween = create_tween()
		tween.tween_property(bg_music, "volume_db", -40.0, 2.0)
	await get_tree().create_timer(2.0).timeout
	SceneTransition.change_scene_to_file(CampaignManager.narrative_beat_return_scene_path)


func _on_skip_pressed() -> void:
	if is_ending:
		return
	if _awaiting_choice:
		var pc: Variant = _line_in_progress.get("player_choice", null)
		if pc is Dictionary:
			_on_tone_chosen(_default_tone_id(pc as Dictionary))
		return
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
	_end_sequence_instant(true)


func _end_sequence_instant(mark_seen: bool) -> void:
	is_ending = true
	if mark_seen and active_beat_id != "":
		CampaignManager.mark_narrative_beat_seen(active_beat_id)
		CampaignManager.try_grant_narrative_beat_rewards(active_beat_id)
	CampaignManager.pending_narrative_beat_id = ""
	SceneTransition.change_scene_to_file(CampaignManager.narrative_beat_return_scene_path)
