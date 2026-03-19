# ==============================================================================
# Script Name: TavernDialogueUI.gd
# Purpose:
#   Provides the upgraded tavern dialogue UI layer for Seraphina and other
#   similar NPC conversations.
#
# Overall Goal:
#   Upgrade the tavern UI so it supports:
#     - Up to 4 dynamic choice buttons
#     - Locked-but-visible dialogue options
#     - Hover tooltips for locked requirements
#     - Typewriter-style dialogue reveal
#     - "Next to finish typing, next again to advance" behavior
#
# How This Fits Into The Project:
#   This script sits on the tavern UI Control scene and is consumed by
#   SeraphinaDialogueManager.gd. The dialogue manager decides what content to
#   show. This UI script decides how that content is presented visually.
#
# Dependencies:
#   - Must live on the parent tavern UI node used by SeraphinaDialogueManager
#   - Expected by the manager:
#       dialogue_panel
#       dialogue_text
#       choice_container
#       choice_btn_1
#       choice_btn_2
#       choice_btn_3
#       choice_btn_4
#       next_btn
#       active_character_a
#       active_character_b
#       _display_line(line_dict)
#       _disconnect_all_pressed(button)
#       _hide_all_choice_buttons()
#       _apply_choice_button_state(button, choice_view_model)
#       _is_text_typing()
#       _finish_typing()
#       get_choice_buttons()
#       _show_system_message(text, color)
#
# AI / Reviewer Notes:
#   - Main UI entry point: _display_line()
#   - Typewriter control: _start_typewriter(), _finish_typing(), _process()
#   - Choice rendering helper: _apply_choice_button_state()
#   - Signal cleanup helper: _disconnect_all_pressed()
#   - Extension point: add portraits, nameplates, sound, or per-character skins
# ==============================================================================

extends Control
class_name TavernDialogueUI

# ------------------------------------------------------------------------------
# EXPORTED NODE PATHS
# ------------------------------------------------------------------------------
# These default paths can be reassigned in the Inspector if your scene tree uses
# different names. The manager accesses the resolved members, not the paths.
@export_group("Required UI Nodes")
@export_node_path("Control") var dialogue_panel_path: NodePath = ^"DialoguePanel"
@export_node_path("RichTextLabel") var dialogue_text_path: NodePath = ^"DialoguePanel/DialogueText"
@export_node_path("Control") var choice_container_path: NodePath = ^"ChoiceContainer"
@export_node_path("Button") var choice_btn_1_path: NodePath = ^"ChoiceContainer/ChoiceBtn1"
@export_node_path("Button") var choice_btn_2_path: NodePath = ^"ChoiceContainer/ChoiceBtn2"
@export_node_path("Button") var choice_btn_3_path: NodePath = ^"ChoiceContainer/ChoiceBtn3"
@export_node_path("Button") var choice_btn_4_path: NodePath = ^"ChoiceContainer/ChoiceBtn4"
@export_node_path("Button") var next_btn_path: NodePath = ^"DialoguePanel/NextButton"

# Optional presentation nodes.
@export_group("Optional UI Nodes")
@export_node_path("Label") var speaker_name_label_path: NodePath
@export_node_path("Label") var system_message_label_path: NodePath

# ------------------------------------------------------------------------------
# TYPEWRITER CONFIGURATION
# ------------------------------------------------------------------------------
@export_group("Typewriter")
@export var enable_typewriter: bool = true
@export_range(10.0, 240.0, 1.0) var characters_per_second: float = 60.0
@export var auto_scroll_rich_text: bool = true

# ------------------------------------------------------------------------------
# CHOICE PRESENTATION CONFIGURATION
# ------------------------------------------------------------------------------
@export_group("Choice Visuals")
@export var hard_disable_locked_choices: bool = false
@export var unlocked_button_modulate: Color = Color(1, 1, 1, 1)
@export var locked_button_modulate: Color = Color(0.55, 0.55, 0.55, 1)

# ------------------------------------------------------------------------------
# SYSTEM MESSAGE CONFIGURATION
# ------------------------------------------------------------------------------
@export_group("System Message")
@export var system_message_duration: float = 1.8

# ------------------------------------------------------------------------------
# RESOLVED NODE REFERENCES
# ------------------------------------------------------------------------------
# These are the members expected by the dialogue manager.
var dialogue_panel: Control = null
var dialogue_text: RichTextLabel = null
var choice_container: Control = null
var choice_btn_1: Button = null
var choice_btn_2: Button = null
var choice_btn_3: Button = null
var choice_btn_4: Button = null
var next_btn: Button = null

# Optional nodes.
var speaker_name_label: Label = null
var system_message_label: Label = null

# Existing project-facing runtime fields.
var active_character_a: Dictionary = {}
var active_character_b: Dictionary = {}

# ------------------------------------------------------------------------------
# INTERNAL TYPEWRITER STATE
# ------------------------------------------------------------------------------
var _full_text: String = ""
var _typing_active: bool = false
var _typing_progress: float = 0.0
var _last_visible_characters: int = 0
var _system_message_tween: Tween = null


# ------------------------------------------------------------------------------
# Function: _ready
# Purpose:
#   Resolves all exported node paths and validates the required UI surface.
#
# Inputs:
#   None.
#
# Outputs:
#   None.
#
# Side Effects:
#   - Populates node references
#   - Hides stale choices
#   - Ensures dialogue text starts in a safe state
# ------------------------------------------------------------------------------
func _ready() -> void:
	dialogue_panel = get_node_or_null(dialogue_panel_path)
	dialogue_text = get_node_or_null(dialogue_text_path)
	choice_container = get_node_or_null(choice_container_path)
	choice_btn_1 = get_node_or_null(choice_btn_1_path)
	choice_btn_2 = get_node_or_null(choice_btn_2_path)
	choice_btn_3 = get_node_or_null(choice_btn_3_path)
	choice_btn_4 = get_node_or_null(choice_btn_4_path)
	next_btn = get_node_or_null(next_btn_path)

	if speaker_name_label_path != NodePath():
		speaker_name_label = get_node_or_null(speaker_name_label_path)

	if system_message_label_path != NodePath():
		system_message_label = get_node_or_null(system_message_label_path)

	_validate_required_nodes()
	_hide_all_choice_buttons()

	if next_btn != null:
		next_btn.hide()

	if dialogue_text != null:
		dialogue_text.visible_characters = -1
		dialogue_text.text = ""


# ------------------------------------------------------------------------------
# Function: _process
# Purpose:
#   Drives the typewriter effect by gradually increasing visible characters over
#   time.
#
# Inputs:
#   delta: float
#
# Outputs:
#   None.
#
# Side Effects:
#   - Updates dialogue_text.visible_characters
# ------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not _typing_active:
		return

	if dialogue_text == null:
		_typing_active = false
		return

	if not enable_typewriter:
		_finish_typing()
		return

	if _full_text.is_empty():
		_typing_active = false
		dialogue_text.visible_characters = -1
		return

	_typing_progress += delta * characters_per_second

	var total_chars: int = _full_text.length()
	var target_visible: int = clampi(int(floor(_typing_progress)), 0, total_chars)

	if target_visible != _last_visible_characters:
		dialogue_text.visible_characters = target_visible
		_last_visible_characters = target_visible

		if auto_scroll_rich_text:
			dialogue_text.scroll_to_line(dialogue_text.get_line_count())

	if target_visible >= total_chars:
		_finish_typing()


# ------------------------------------------------------------------------------
# Function: _validate_required_nodes
# Purpose:
#   Warns in the debugger if critical UI nodes are missing.
#
# Inputs:
#   None.
#
# Outputs:
#   None.
#
# Side Effects:
#   - Emits warnings in the debugger
# ------------------------------------------------------------------------------
func _validate_required_nodes() -> void:
	if dialogue_panel == null:
		push_warning("TavernDialogueUI: dialogue_panel could not be resolved.")
	if dialogue_text == null:
		push_warning("TavernDialogueUI: dialogue_text could not be resolved.")
	if choice_container == null:
		push_warning("TavernDialogueUI: choice_container could not be resolved.")
	if next_btn == null:
		push_warning("TavernDialogueUI: next_btn could not be resolved.")

	var buttons: Array = get_choice_buttons()
	if buttons.is_empty():
		push_warning("TavernDialogueUI: no choice buttons were resolved.")


# ------------------------------------------------------------------------------
# Function: _display_line
# Purpose:
#   Main entry point used by the dialogue manager to display a new spoken line.
#
# Inputs:
#   line_dict: Dictionary with at least:
#     - "speaker": String
#     - "text": String
#
# Outputs:
#   None.
#
# Side Effects:
#   - Opens the dialogue panel
#   - Updates speaker label if present
#   - Starts the typewriter effect
# ------------------------------------------------------------------------------
func _display_line(line_dict: Dictionary) -> void:
	if dialogue_panel != null:
		dialogue_panel.show()

	var speaker: String = str(line_dict.get("speaker", ""))
	var text_value: String = str(line_dict.get("text", ""))

	if speaker_name_label != null:
		speaker_name_label.text = speaker

	_start_typewriter(text_value)


# ------------------------------------------------------------------------------
# Function: _start_typewriter
# Purpose:
#   Loads a new line into the RichTextLabel and starts the typewriter reveal.
#
# Inputs:
#   new_text: String
#
# Outputs:
#   None.
#
# Side Effects:
#   - Resets internal typewriter state
#   - Updates dialogue_text
# ------------------------------------------------------------------------------
func _start_typewriter(new_text: String) -> void:
	if dialogue_text == null:
		return

	_full_text = new_text
	_typing_progress = 0.0
	_last_visible_characters = 0

	dialogue_text.text = _full_text

	if not enable_typewriter:
		dialogue_text.visible_characters = -1
		_typing_active = false
		return

	if _full_text.is_empty():
		dialogue_text.visible_characters = -1
		_typing_active = false
		return

	dialogue_text.visible_characters = 0
	_typing_active = true


# ------------------------------------------------------------------------------
# Function: _is_text_typing
# Purpose:
#   Lets the dialogue manager know whether pressing "Next" should finish the
#   current line or truly advance to the next one.
#
# Inputs:
#   None.
#
# Outputs:
#   bool
#
# Side Effects:
#   None.
# ------------------------------------------------------------------------------
func _is_text_typing() -> bool:
	return _typing_active


# ------------------------------------------------------------------------------
# Function: _finish_typing
# Purpose:
#   Instantly completes the current typewriter reveal.
#
# Inputs:
#   None.
#
# Outputs:
#   None.
#
# Side Effects:
#   - Reveals the full line immediately
# ------------------------------------------------------------------------------
func _finish_typing() -> void:
	if dialogue_text == null:
		_typing_active = false
		return

	_typing_active = false
	dialogue_text.visible_characters = -1
	_last_visible_characters = _full_text.length()

	if auto_scroll_rich_text:
		dialogue_text.scroll_to_line(dialogue_text.get_line_count())


# ------------------------------------------------------------------------------
# Function: get_choice_buttons
# Purpose:
#   Returns the currently resolved choice buttons in UI order.
#
# Inputs:
#   None.
#
# Outputs:
#   Array of Button
#
# Side Effects:
#   None.
# ------------------------------------------------------------------------------
func get_choice_buttons() -> Array:
	var buttons: Array = []

	if choice_btn_1 != null:
		buttons.append(choice_btn_1)
	if choice_btn_2 != null:
		buttons.append(choice_btn_2)
	if choice_btn_3 != null:
		buttons.append(choice_btn_3)
	if choice_btn_4 != null:
		buttons.append(choice_btn_4)

	return buttons


# ------------------------------------------------------------------------------
# Function: _hide_all_choice_buttons
# Purpose:
#   Hides every choice button, clears tooltips, and hides the choice container.
#
# Inputs:
#   None.
#
# Outputs:
#   None.
#
# Side Effects:
#   - Mutates visibility and button state
# ------------------------------------------------------------------------------
func _hide_all_choice_buttons() -> void:
	for button in get_choice_buttons():
		if button == null:
			continue

		button.hide()
		button.disabled = false
		button.text = ""
		button.tooltip_text = ""
		button.modulate = unlocked_button_modulate

	if choice_container != null:
		choice_container.hide()


# ------------------------------------------------------------------------------
# Function: _apply_choice_button_state
# Purpose:
#   Configures one choice button from the manager-provided choice view model.
#
# Inputs:
#   button: Button
#   choice_view_model: Dictionary expected to contain:
#     - "text": String
#     - "__locked": bool
#     - "__lock_reason": String
#
# Outputs:
#   None.
#
# Side Effects:
#   - Updates button text
#   - Applies locked/unlocked visuals
#   - Sets tooltip text for locked options
# ------------------------------------------------------------------------------
func _apply_choice_button_state(button: Button, choice_view_model: Dictionary) -> void:
	if button == null:
		return

	var is_locked: bool = bool(choice_view_model.get("__locked", false))
	var display_text: String = str(choice_view_model.get("text", ""))
	var lock_reason: String = str(choice_view_model.get("__lock_reason", ""))

	button.text = display_text
	button.tooltip_text = lock_reason if is_locked else ""
	button.show()

	# Default behavior: keep locked options clickable so the manager can decide
	# what to do, while visually graying them out. This preserves tooltips and
	# lets you optionally show a system message on click.
	button.disabled = hard_disable_locked_choices and is_locked
	button.modulate = locked_button_modulate if is_locked else unlocked_button_modulate


# ------------------------------------------------------------------------------
# Function: _disconnect_all_pressed
# Purpose:
#   Safely disconnects all existing handlers from a button's pressed signal.
#
# Inputs:
#   button: BaseButton
#
# Outputs:
#   None.
#
# Side Effects:
#   - Disconnects signal callables from the button
# ------------------------------------------------------------------------------
func _disconnect_all_pressed(button: BaseButton) -> void:
	if button == null:
		return

	var connections: Array = button.get_signal_connection_list("pressed")
	for connection in connections:
		if not connection.has("callable"):
			continue

		var callable: Callable = connection["callable"]
		if button.pressed.is_connected(callable):
			button.pressed.disconnect(callable)


# ------------------------------------------------------------------------------
# Function: _show_system_message
# Purpose:
#   Displays a short temporary UI message. Used by the dialogue manager for
#   rank-up notices or locked-choice feedback.
#
# Inputs:
#   text_value: String
#   color_value: Color
#
# Outputs:
#   None.
#
# Side Effects:
#   - Updates the optional system_message_label if assigned
#   - Falls back to printing if no label is configured
# ------------------------------------------------------------------------------
func _show_system_message(text_value: String, color_value: Color = Color.WHITE) -> void:
	if system_message_label == null:
		print(text_value)
		return

	system_message_label.text = text_value
	system_message_label.add_theme_color_override("font_color", color_value)
	system_message_label.modulate = Color(1, 1, 1, 1)
	system_message_label.show()

	if _system_message_tween != null:
		_system_message_tween.kill()
		_system_message_tween = null

	_system_message_tween = create_tween()
	_system_message_tween.tween_interval(system_message_duration)
	_system_message_tween.tween_property(system_message_label, "modulate:a", 0.0, 0.35)
	_system_message_tween.finished.connect(func():
		if system_message_label != null:
			system_message_label.hide()
	)
