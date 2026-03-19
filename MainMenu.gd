## Main Menu with Enhanced Sounds (no background changes)
##
## This script enhances your existing menu by adding hover/click sound effects,
## looping menu music and a smooth fade‑in for the UI panels.  It does not
## modify any existing TextureRect background in the scene.  All indentation
## uses tabs to avoid spacing errors.

extends Control

@onready var start_button: TextureButton = $VBoxContainer/StartButton
@onready var quit_button: TextureButton = $VBoxContainer/QuitButton

# --- CAMPAIGN MENU REFERENCES ---
@onready var campaign_vbox: VBoxContainer = $CampaignMenu
@onready var continue_button: TextureButton = $CampaignMenu/ContinueButton
@onready var new_game_button: TextureButton = $CampaignMenu/NewGameButton
@onready var main_vbox: VBoxContainer = $VBoxContainer

@onready var auto_slot_1_btn: Button = get_node_or_null("%AutoSlot1Button")
@onready var auto_slot_2_btn: Button = get_node_or_null("%AutoSlot2Button")
@onready var auto_slot_3_btn: Button = get_node_or_null("%AutoSlot3Button")

# --- LOAD GAME & SLOTS CONTAINER ---
@onready var load_game_button: TextureButton = get_node_or_null("%LoadGameButton")
@onready var slots_container: VBoxContainer = get_node_or_null("%SlotsContainer")

# --- SAVE SLOT BUTTONS ---
@onready var slot_1_btn: Button = get_node_or_null("%Slot1Button")
@onready var slot_2_btn: Button = get_node_or_null("%Slot2Button")
@onready var slot_3_btn: Button = get_node_or_null("%Slot3Button")

# --- DELETE BUTTONS & DIALOG ---
@onready var del_slot_1_btn: Button = get_node_or_null("%DeleteSlot1")
@onready var del_slot_2_btn: Button = get_node_or_null("%DeleteSlot2")
@onready var del_slot_3_btn: Button = get_node_or_null("%DeleteSlot3")
@onready var delete_dialog: ConfirmationDialog = get_node_or_null("%DeleteConfirmation")

var pending_delete_slot: int = 0

# Audio resources (replace with your own asset paths)
var SFX_HOVER: AudioStream = preload("res://audio/menu_hover.wav")
var SFX_CLICK: AudioStream = preload("res://audio/menu_click.wav")
var MENU_MUSIC: AudioStream = preload("res://audio/Menu Music (Remastered).wav")

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer

# --- UX: script-only feedback (no new nodes). Entry: _ready wires these. ---
func _button_press_feedback(control: Control) -> void:
	if control == null:
		return
	var t := create_tween()
	t.tween_property(control, "scale", Vector2(0.94, 0.94), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(control, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _button_hover_entered(control: Control) -> void:
	if control == null:
		return
	var t := create_tween()
	t.tween_property(control, "scale", Vector2(1.03, 1.03), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _button_hover_exited(control: Control) -> void:
	if control == null:
		return
	var t := create_tween()
	t.tween_property(control, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Returns the slot or auto-slot Button for slot_num (1–3) and is_auto; used for load-fail feedback.
func _get_slot_button(slot_num: int, is_auto: bool) -> Button:
	match slot_num:
		1: return auto_slot_1_btn if is_auto else slot_1_btn
		2: return auto_slot_2_btn if is_auto else slot_2_btn
		3: return auto_slot_3_btn if is_auto else slot_3_btn
	return null

func _ready() -> void:
	# Initial focus and button connections
	start_button.grab_focus()
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	if load_game_button:
		load_game_button.pressed.connect(_on_load_game_pressed)
	if slot_1_btn:
		slot_1_btn.pressed.connect(func(): _on_slot_pressed(1))
	if slot_2_btn:
		slot_2_btn.pressed.connect(func(): _on_slot_pressed(2))
	if slot_3_btn:
		slot_3_btn.pressed.connect(func(): _on_slot_pressed(3))
	if del_slot_1_btn:
		del_slot_1_btn.pressed.connect(func(): _on_delete_pressed(1))
	if del_slot_2_btn:
		del_slot_2_btn.pressed.connect(func(): _on_delete_pressed(2))
	if del_slot_3_btn:
		del_slot_3_btn.pressed.connect(func(): _on_delete_pressed(3))
	if auto_slot_1_btn:
		auto_slot_1_btn.pressed.connect(func(): _on_slot_pressed(1, true))
	if auto_slot_2_btn:
		auto_slot_2_btn.pressed.connect(func(): _on_slot_pressed(2, true))
	if auto_slot_3_btn:
		auto_slot_3_btn.pressed.connect(func(): _on_slot_pressed(3, true))
	if delete_dialog:
		delete_dialog.confirmed.connect(_on_delete_confirmed)
	# Hide slots container initially
	if slots_container:
		slots_container.visible = false
	_refresh_save_ui()
	# Create music and sfx players
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = MENU_MUSIC
	_music_player.autoplay = true
	_music_player.volume_db = -6.0
	add_child(_music_player)
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "SFX"
	add_child(_sfx_player)
	# Connect sounds, press feedback, and hover scale to buttons
	var buttons: Array = [
		start_button,
		quit_button,
		continue_button,
		new_game_button,
		load_game_button,
		slot_1_btn,
		slot_2_btn,
		slot_3_btn,
		auto_slot_1_btn,
		auto_slot_2_btn,
		auto_slot_3_btn,
		del_slot_1_btn,
		del_slot_2_btn,
		del_slot_3_btn
	]
	for b in buttons:
		if b == null:
			continue
		b.mouse_entered.connect(func():
			_sfx_player.stream = SFX_HOVER
			_sfx_player.pitch_scale = randf_range(0.95, 1.05)
			_sfx_player.play()
		)
		# Pass button ref into lambdas so hover/press feedback targets the correct control
		var ctrl: Control = b
		b.mouse_entered.connect(func(): _button_hover_entered(ctrl))
		b.mouse_exited.connect(func(): _button_hover_exited(ctrl))
		b.pressed.connect(func():
			_sfx_player.stream = SFX_CLICK
			_sfx_player.pitch_scale = randf_range(0.9, 1.1)
			_sfx_player.play()
		)
		b.pressed.connect(func(): _button_press_feedback(ctrl))
	# Entrance: fade in + slight scale up for a polished open
	main_vbox.modulate.a = 0.0
	main_vbox.scale = Vector2(0.97, 0.97)
	campaign_vbox.modulate.a = 0.0
	campaign_vbox.scale = Vector2(0.97, 0.97)
	if slots_container:
		slots_container.modulate.a = 0.0
		slots_container.scale = Vector2(0.97, 0.97)
	var fade_tween := create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(main_vbox, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(main_vbox, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(campaign_vbox, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(campaign_vbox, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if slots_container:
		fade_tween.tween_property(slots_container, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		fade_tween.tween_property(slots_container, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _refresh_save_ui() -> void:
	# Check for Manual Saves
	var has_slot1 = FileAccess.file_exists(CampaignManager.get_save_path(1, false))
	var has_slot2 = FileAccess.file_exists(CampaignManager.get_save_path(2, false))
	var has_slot3 = FileAccess.file_exists(CampaignManager.get_save_path(3, false))
	# Check for Auto-Saves
	var has_auto1 = FileAccess.file_exists(CampaignManager.get_save_path(1, true))
	var has_auto2 = FileAccess.file_exists(CampaignManager.get_save_path(2, true))
	var has_auto3 = FileAccess.file_exists(CampaignManager.get_save_path(3, true))
	# Determine active slots
	var slot1_active = has_slot1 or has_auto1
	var slot2_active = has_slot2 or has_auto2
	var slot3_active = has_slot3 or has_auto3
	
	# Update main slot buttons visually
	if slot_1_btn:
		slot_1_btn.visible = slot1_active
		if slot1_active: _update_save_slot_ui(slot_1_btn, 1, false)
	if slot_2_btn:
		slot_2_btn.visible = slot2_active
		if slot2_active: _update_save_slot_ui(slot_2_btn, 2, false)
	if slot_3_btn:
		slot_3_btn.visible = slot3_active
		if slot3_active: _update_save_slot_ui(slot_3_btn, 3, false)
		
	# Update auto-save buttons visually
	if auto_slot_1_btn:
		auto_slot_1_btn.visible = has_auto1
		if has_auto1: _update_save_slot_ui(auto_slot_1_btn, 1, true)
	if auto_slot_2_btn:
		auto_slot_2_btn.visible = has_auto2
		if has_auto2: _update_save_slot_ui(auto_slot_2_btn, 2, true)
	if auto_slot_3_btn:
		auto_slot_3_btn.visible = has_auto3
		if has_auto3: _update_save_slot_ui(auto_slot_3_btn, 3, true)
		
	# Update delete buttons visibility
	if del_slot_1_btn:
		del_slot_1_btn.visible = slot1_active
	if del_slot_2_btn:
		del_slot_2_btn.visible = slot2_active
	if del_slot_3_btn:
		del_slot_3_btn.visible = slot3_active
		
	# Show or hide Continue/Load buttons
	var has_any_saves = slot1_active or slot2_active or slot3_active
	continue_button.visible = has_any_saves
	if load_game_button:
		load_game_button.visible = has_any_saves

# --- THE NEW DYNAMIC UI FUNCTION ---
func _update_save_slot_ui(slot_button: Button, slot_num: int, is_auto: bool) -> void:
	var path = CampaignManager.get_save_path(slot_num, is_auto)
	
	# 1. Safely get references to the internal nodes
	# Using get_node_or_null prevents crashes if the nodes aren't set up perfectly yet
	var portrait_rect = slot_button.get_node_or_null("MarginContainer/HBox/Portrait") as TextureRect
	var name_label = slot_button.get_node_or_null("MarginContainer/HBox/TextVBox/NameLabel") as Label
	var loc_label = slot_button.get_node_or_null("MarginContainer/HBox/TextVBox/LocationLabel") as Label
	var gold_label = slot_button.get_node_or_null("MarginContainer/HBox/GoldLabel") as Label
	
	# If this happens to be a button you haven't converted to the new layout yet, skip it.
	if not name_label: return
	
	var prefix = "Auto: " if is_auto else "Slot " + str(slot_num) + ": "

	# 2. Check if file exists
	if not FileAccess.file_exists(path):
		name_label.text = prefix + "Empty"
		name_label.add_theme_color_override("font_color", Color.GRAY)
		if loc_label: loc_label.text = ""
		if gold_label: gold_label.text = ""
		if portrait_rect: portrait_rect.texture = null
		return
		
	# 3. Load the data
	var file = FileAccess.open(path, FileAccess.READ)
	var save_data = file.get_var()
	file.close()
	
	if typeof(save_data) != TYPE_DICTIONARY:
		name_label.text = prefix + "[ CORRUPTED DATA ]"
		name_label.add_theme_color_override("font_color", Color.RED)
		return
	
	# 4. Extract data safely
	var roster = save_data.get("player_roster", [])
	var leader_name = "Unknown"
	var leader_lvl = 1
	var portrait_path = ""
	
	if roster.size() > 0:
		leader_name = roster[0].get("unit_name", "Hero")
		leader_lvl = roster[0].get("level", 1)
		portrait_path = roster[0].get("portrait", "")
		
	var gold = save_data.get("global_gold", 0)
	var map_idx = save_data.get("current_level_index", 0) + 1 
	
	# 5. Apply the Data to the UI
	name_label.text = prefix + leader_name.to_upper() + " (Lv " + str(leader_lvl) + ")"
	name_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2)) # Gold
	
	if loc_label:
		loc_label.text = "Location: Map " + str(map_idx)
		loc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	
	if gold_label:
		gold_label.text = str(gold) + " G"
		gold_label.add_theme_color_override("font_color", Color.WHITE)
	
	if portrait_rect:
		if portrait_path is String and ResourceLoader.exists(portrait_path):
			portrait_rect.texture = load(portrait_path)
		elif portrait_path is Texture2D:
			portrait_rect.texture = portrait_path

func _on_start_pressed() -> void:
	# Smooth transition: fade out main, then show campaign and fade it in
	var t := create_tween()
	t.tween_property(main_vbox, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		main_vbox.visible = false
		campaign_vbox.visible = true
		campaign_vbox.modulate.a = 0.0
		campaign_vbox.scale = Vector2(0.98, 0.98)
	)
	t.tween_property(campaign_vbox, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(campaign_vbox, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		if continue_button.visible:
			continue_button.grab_focus()
		else:
			new_game_button.grab_focus()
	)

func _on_new_game_pressed() -> void:
	# Reset old campaign data and set starting level
	if CampaignManager.has_method("reset_campaign_data"):
		CampaignManager.reset_campaign_data()
	CampaignManager.current_level_index = 0
	# Select first empty slot for autosave
	CampaignManager.active_save_slot = 1
	for i in range(1, 4):
		if not FileAccess.file_exists(CampaignManager.get_save_path(i, false)) and not FileAccess.file_exists(CampaignManager.get_save_path(i, true)):
			CampaignManager.active_save_slot = i
			break
	SceneTransition.change_scene_to_file("res://Scenes/character_creation.tscn")

func _on_continue_pressed() -> void:
	var newest_slot = -1
	var newest_is_auto = false
	var newest_time = 0
	for i in range(1, 4):
		var man_path = CampaignManager.get_save_path(i, false)
		if FileAccess.file_exists(man_path):
			var mod_time = FileAccess.get_modified_time(man_path)
			if mod_time > newest_time:
				newest_time = mod_time
				newest_slot = i
				newest_is_auto = false
		var auto_path = CampaignManager.get_save_path(i, true)
		if FileAccess.file_exists(auto_path):
			var mod_time2 = FileAccess.get_modified_time(auto_path)
			if mod_time2 > newest_time:
				newest_time = mod_time2
				newest_slot = i
				newest_is_auto = true
	if newest_slot != -1:
		_on_slot_pressed(newest_slot, newest_is_auto)

func _on_load_game_pressed() -> void:
	if slots_container == null:
		return
	var showing: bool = not slots_container.visible
	if showing:
		slots_container.visible = true
		slots_container.modulate.a = 0.0
		slots_container.scale = Vector2(0.96, 0.96)
		var t := create_tween()
		t.tween_property(slots_container, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(slots_container, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# Focus first visible slot for keyboard nav
		if slot_1_btn and slot_1_btn.visible:
			slot_1_btn.grab_focus()
		elif slot_2_btn and slot_2_btn.visible:
			slot_2_btn.grab_focus()
		elif slot_3_btn and slot_3_btn.visible:
			slot_3_btn.grab_focus()
	else:
		var t := create_tween()
		t.tween_property(slots_container, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_callback(func(): slots_container.visible = false)
		if load_game_button:
			load_game_button.grab_focus()

func _on_slot_pressed(slot_num: int, is_auto: bool = false) -> void:
	if CampaignManager.load_game(slot_num, is_auto):
		SceneTransition.change_scene_to_file("res://Scenes/camp_menu.tscn")
	else:
		var btn: Button = _get_slot_button(slot_num, is_auto)
		if btn != null:
			_flash_slot_error(btn)
		print("Error: Failed to load save slot ", slot_num)

## Brief red flash on a control (e.g. slot button) to indicate load or action failure.
func _flash_slot_error(control: Control) -> void:
	if control == null:
		return
	var t := create_tween()
	t.tween_property(control, "modulate", Color(1.0, 0.35, 0.35), 0.08).set_trans(Tween.TRANS_SINE)
	t.tween_property(control, "modulate", Color.WHITE, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_delete_pressed(slot_num: int) -> void:
	pending_delete_slot = slot_num
	if delete_dialog:
		delete_dialog.dialog_text = "Are you sure you want to permanently delete Save Slot %d?" % slot_num
		delete_dialog.popup_centered()
	else:
		print("!!! ERROR: The game cannot find %DeleteConfirmation in the Scene Tree!")

func _on_delete_confirmed() -> void:
	if CampaignManager.has_method("delete_game"):
		CampaignManager.delete_game(pending_delete_slot)
	await get_tree().create_timer(0.1).timeout
	_refresh_save_ui()
	if not continue_button.visible:
		new_game_button.grab_focus()
		if slots_container:
			slots_container.visible = false
