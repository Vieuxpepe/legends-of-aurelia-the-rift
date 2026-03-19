# ==============================================================================
# Script Name: SeraphinaDialogueManager.gd
# Purpose:
#   Runtime controller for Seraphina's data-driven dialogue and relationship
#   system.
#
# Overall Goal:
#   Replace a simple linear bartender interaction with a reusable branching
#   dialogue manager that evaluates hidden stats, flags, campaign progress,
#   and time-of-day routing.
#
# Project Role:
#   Attach this to the Seraphina tavern interaction node. It reads content from
#   SeraphinaDialogueDatabase.gd and writes persistent state into CampaignManager.
#   It also coordinates with the TavernDialogueUI.gd script for:
#     - typewriter text
#     - up to 4 choices
#     - locked-but-visible options
#     - hover tooltips for locked requirements
#
# Dependencies:
#   - SeraphinaDialogueDatabase.gd
#   - CampaignManager autoload
#   - Parent UI that ideally exposes:
#       dialogue_panel
#       dialogue_text
#       choice_container
#       choice_btn_1
#       choice_btn_2
#       choice_btn_3
#       choice_btn_4
#       next_btn
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
#   - Main entry point: interact()
#   - Core routing: _resolve_entry_node_id()
#   - Core evaluation: _evaluate_conditions()
#   - Core persistence: _get_relationship_state(), _apply_effects()
#   - VN choice support: _build_choice_view_models(), _present_choices()
#   - Tooltip lock reasons: _get_choice_lock_reason(), _describe_first_failed_requirement()
# ==============================================================================

extends Node
class_name SeraphinaDialogueManager

signal dialogue_started(node_id: String)
signal dialogue_finished(last_node_id: String)

@export var bartender_name: String = "Seraphina"
@export var npc_key: String = "seraphina"

# Assign ONLY the actual portrait button/rect here if you want portrait mood
# swapping and breathing animation. Leave null to disable portrait animation.
@export var portrait_node: Control

@export_group("Mood Portraits")
@export var tex_neutral: Texture2D
@export var tex_smiling: Texture2D
@export var tex_blushing: Texture2D
@export var tex_thinking: Texture2D
@export var tex_angry: Texture2D

@export_group("Routing")
@export var default_time_of_day: String = "evening"

@export_group("Animation")
@export_range(0.1, 2.0) var base_scale_factor: float = 1.0
@export var enable_idle_breathing: bool = true

@export_group("Persistence")
@export var auto_save_after_state_change: bool = true

var parent_ui = null
var visual_node: Control = null
var breathing_tween: Tween = null

var _database: Dictionary = {}
var _current_node_id: String = ""
var _current_node: Dictionary = {}
var _current_line_index: int = 0
var _conversation_active: bool = false


# ------------------------------------------------------------------------------
# Function: _ready
# Purpose:
#   Initializes the local database cache, ensures Seraphina relationship state
#   exists, resolves the portrait node safely, and starts idle breathing only on
#   that portrait node.
#
# Inputs:
#   None.
#
# Outputs:
#   None.
#
# Side Effects:
#   - Ensures Seraphina relationship state exists in CampaignManager
#   - Starts portrait breathing animation if enabled and a portrait is assigned
# ------------------------------------------------------------------------------
func _ready() -> void:
	parent_ui = get_parent()
	_database = SeraphinaDialogueDatabase.get_database()
	_ensure_relationship_state()

	# Use only the explicitly assigned portrait node.
	visual_node = portrait_node

	# Apply a safe initial mood.
	set_mood("neutral")

	if enable_idle_breathing and visual_node != null:
		call_deferred("_play_idle_breathing")


# ------------------------------------------------------------------------------
# Function: interact
# Purpose:
#   Public entry point called by the tavern interaction layer when the player
#   speaks to Seraphina.
#
# Inputs:
#   None.
#
# Outputs:
#   None.
#
# Side Effects:
#   - Connects UI buttons
#   - Resolves the correct entry node
#   - Starts a conversation sequence
# ------------------------------------------------------------------------------
func interact() -> void:
	_database = SeraphinaDialogueDatabase.get_database()
	_ensure_relationship_state()
	_prepare_ui_for_dialogue()

	_conversation_active = true
	_current_node_id = _resolve_entry_node_id()
	_enter_node(_current_node_id)

	dialogue_started.emit(_current_node_id)


# ------------------------------------------------------------------------------
# Function: _prepare_ui_for_dialogue
# Purpose:
#   Resets button bindings and prepares the parent dialogue UI for a fresh
#   conversation.
#
# Inputs:
#   None.
#
# Outputs:
#   None.
#
# Side Effects:
#   - Disconnects previous signals from buttons
#   - Shows dialogue panel
#   - Hides stale choices
# ------------------------------------------------------------------------------
func _prepare_ui_for_dialogue() -> void:
	if parent_ui == null:
		parent_ui = get_parent()

	if parent_ui == null:
		push_warning("SeraphinaDialogueManager could not find a valid parent UI.")
		return

	if parent_ui.has_method("_disconnect_all_pressed"):
		parent_ui._disconnect_all_pressed(parent_ui.next_btn)
		for button in _get_choice_buttons():
			parent_ui._disconnect_all_pressed(button)

	parent_ui.next_btn.pressed.connect(_on_next_pressed)

	if parent_ui.dialogue_panel != null:
		parent_ui.dialogue_panel.show()

	if parent_ui.has_method("_hide_all_choice_buttons"):
		parent_ui._hide_all_choice_buttons()
	else:
		for button in _get_choice_buttons():
			button.hide()
		parent_ui.choice_container.hide()

	parent_ui.next_btn.hide()

	# The existing tavern UI expects active speaker data in these fields.
	parent_ui.active_character_a = {"unit_name": bartender_name}
	parent_ui.active_character_b = {}


# ------------------------------------------------------------------------------
# Function: _enter_node
# Purpose:
#   Loads a node, applies its on-enter effects, marks it seen, and displays the
#   first line.
#
# Inputs:
#   node_id: String identifier of the node to enter.
#
# Outputs:
#   None.
#
# Side Effects:
#   - Mutates persistent relationship state
#   - Updates current node runtime state
#   - Writes dialogue text to the UI
# ------------------------------------------------------------------------------
func _enter_node(node_id: String) -> void:
	if not _database.has("nodes") or not _database["nodes"].has(node_id):
		push_warning("Seraphina dialogue node not found: %s" % node_id)
		_end_conversation()
		return

	_current_node_id = node_id
	_current_node = _database["nodes"][node_id]
	_current_line_index = 0

	_mark_node_seen(node_id)
	_apply_effects(_current_node.get("on_enter_effects", []))
	_persist_state_if_needed()

	_show_current_line()


# ------------------------------------------------------------------------------
# Function: _show_current_line
# Purpose:
#   Displays the current line in the active node. If the node has no lines, the
#   manager immediately resolves the post-line flow.
#
# Inputs:
#   None.
#
# Outputs:
#   None.
#
# Side Effects:
#   - Updates portrait mood
#   - Updates dialogue text
#   - Shows the next button
# ------------------------------------------------------------------------------
func _show_current_line() -> void:
	var lines: Array = _current_node.get("lines", [])

	if lines.is_empty():
		_resolve_after_lines()
		return

	if _current_line_index >= lines.size():
		_resolve_after_lines()
		return

	var line: Dictionary = lines[_current_line_index]
	var payload := {
		"speaker": str(line.get("speaker", bartender_name)),
		"text": _resolve_tokens(str(line.get("text", "")))
	}

	set_mood(str(line.get("portrait", "neutral")))

	if parent_ui.has_method("_hide_all_choice_buttons"):
		parent_ui._hide_all_choice_buttons()
	else:
		_hide_all_choices()

	if parent_ui.has_method("_display_line"):
		parent_ui._display_line(payload)
	else:
		parent_ui.dialogue_text.text = payload["text"]

	parent_ui.next_btn.show()


# ------------------------------------------------------------------------------
# Function: _on_next_pressed
# Purpose:
#   Advances within the current node.
#
# Important Behavior:
#   - If the UI is currently typewriting text, the first press instantly reveals
#     the full line.
#   - The next press advances the dialogue.
#
# Inputs:
#   None. Triggered by UI signal.
#
# Outputs:
#   None.
#
# Side Effects:
#   - Advances node line index
#   - May transition to other nodes
# ------------------------------------------------------------------------------
func _on_next_pressed() -> void:
	if not _conversation_active:
		return

	# If the UI supports typewriter state, allow the player to instantly finish
	# the current line before actually advancing.
	if parent_ui != null and parent_ui.has_method("_is_text_typing"):
		if parent_ui._is_text_typing():
			parent_ui._finish_typing()
			return

	var lines: Array = _current_node.get("lines", [])
	if _current_line_index < lines.size() - 1:
		_current_line_index += 1
		_show_current_line()
		return

	_current_line_index = lines.size()
	_resolve_after_lines()


# ------------------------------------------------------------------------------
# Function: _resolve_after_lines
# Purpose:
#   Determines what happens after the node's last line has been shown.
#
# Inputs:
#   None.
#
# Outputs:
#   None.
#
# Side Effects:
#   - May present choices
#   - May jump automatically to another node
#   - May end the conversation
# ------------------------------------------------------------------------------
func _resolve_after_lines() -> void:
	var choice_view_models: Array = _build_choice_view_models(_current_node.get("choices", []))

	if not choice_view_models.is_empty():
		_present_choices(choice_view_models)
		return

	var auto_next: String = str(_current_node.get("auto_next", ""))
	if auto_next != "":
		_enter_node(auto_next)
		return

	_end_conversation()


# ------------------------------------------------------------------------------
# Function: _present_choices
# Purpose:
#   Renders current node choices to the existing UI button set.
#
# Inputs:
#   choice_view_models: Array of choice dictionaries enriched with:
#     - "__locked": bool
#     - "__lock_reason": String
#
# Outputs:
#   None.
#
# Side Effects:
#   - Binds choice buttons
#   - Hides the next button
# ------------------------------------------------------------------------------
func _present_choices(choice_view_models: Array) -> void:
	var buttons: Array = _get_choice_buttons()

	_hide_all_choices()
	parent_ui.next_btn.hide()

	var visible_count: int = mini(choice_view_models.size(), buttons.size())

	for i in range(visible_count):
		var button: Button = buttons[i]
		var choice_vm: Dictionary = choice_view_models[i]

		if parent_ui.has_method("_apply_choice_button_state"):
			parent_ui._apply_choice_button_state(button, choice_vm)
		else:
			# Safe fallback if the upgraded UI helper is not yet installed.
			button.text = str(choice_vm.get("text", ""))
			button.tooltip_text = str(choice_vm.get("__lock_reason", ""))
			button.modulate = Color(0.55, 0.55, 0.55, 1) if bool(choice_vm.get("__locked", false)) else Color(1, 1, 1, 1)
			button.show()

		if parent_ui.has_method("_disconnect_all_pressed"):
			parent_ui._disconnect_all_pressed(button)

		button.pressed.connect(_on_choice_selected.bind(choice_vm), CONNECT_ONE_SHOT)

	if visible_count > 0:
		parent_ui.choice_container.show()


# ------------------------------------------------------------------------------
# Function: _on_choice_selected
# Purpose:
#   Applies the chosen option's effects and advances to its target node.
#
# Inputs:
#   choice: Dictionary describing the chosen branch.
#
# Outputs:
#   None.
#
# Side Effects:
#   - Mutates persistent relationship state
#   - Changes current node
# ------------------------------------------------------------------------------
func _on_choice_selected(choice: Dictionary) -> void:
	if not _conversation_active:
		return

	# Locked choices remain visible, show a reason, and do not advance.
	if bool(choice.get("__locked", false)):
		var reason: String = str(choice.get("__lock_reason", "Requirement not met."))
		if parent_ui != null and parent_ui.has_method("_show_system_message"):
			parent_ui._show_system_message(reason, Color(0.8, 0.8, 0.8))
		return

	_hide_all_choices()

	_apply_effects(choice.get("effects", []))
	_persist_state_if_needed()

	var next_node_id: String = str(choice.get("next", ""))
	if next_node_id == "":
		_end_conversation()
		return

	_enter_node(next_node_id)


# ------------------------------------------------------------------------------
# Function: _resolve_entry_node_id
# Purpose:
#   Selects the first node to load by evaluating the database entry rules against
#   the current campaign and relationship context.
#
# Inputs:
#   None.
#
# Outputs:
#   String node id.
#
# Side Effects:
#   None.
# ------------------------------------------------------------------------------
func _resolve_entry_node_id() -> String:
	var rules: Array = _database.get("entry_rules", [])
	var context: Dictionary = _build_context()

	# Defensive sort in case the data file is edited out of order.
	rules.sort_custom(func(a, b): return int(a.get("priority", 0)) > int(b.get("priority", 0)))

	for rule in rules:
		if _evaluate_conditions(rule.get("conditions", {}), context):
			var node_id: String = str(rule.get("node_id", ""))
			if not node_id.is_empty():
				return node_id
			# Rule matched but node_id missing; skip and continue to next rule.

	return "entry_first_meeting"


# ------------------------------------------------------------------------------
# Function: _build_context
# Purpose:
#   Builds a runtime context object used by the condition engine.
#
# Inputs:
#   None.
#
# Outputs:
#   Dictionary containing state, level index, campaign progress, and time data.
#
# Side Effects:
#   None.
# ------------------------------------------------------------------------------
func _build_context() -> Dictionary:
	return {
		"state": _get_relationship_state(),
		"level_index": int(CampaignManager.current_level_index),
		"max_unlocked_index": int(CampaignManager.max_unlocked_index),
		"time_of_day": _get_time_of_day()
	}


# ------------------------------------------------------------------------------
# Function: _evaluate_conditions
# Purpose:
#   Generic recursive evaluator for all data-driven condition blocks.
#
# Inputs:
#   definition: Dictionary or empty Variant.
#   context: Dictionary from _build_context().
#
# Outputs:
#   bool indicating whether the condition passes.
#
# Side Effects:
#   None.
#
# Supported Primitives:
#   flag_true, flag_false
#   stat_gte, stat_lte, stat_eq
#   counter_gte, counter_lte, counter_eq
#   level_gte, level_lte, level_eq
#   max_unlocked_gte
#   time_is, time_in
#   seen_node, not_seen_node
# ------------------------------------------------------------------------------
func _evaluate_conditions(definition, context: Dictionary) -> bool:
	if definition == null:
		return true

	if typeof(definition) != TYPE_DICTIONARY:
		return true

	var block: Dictionary = definition
	if block.is_empty():
		return true

	if block.has("all"):
		for child in block["all"]:
			if not _evaluate_conditions(child, context):
				return false
		return true

	if block.has("any"):
		for child in block["any"]:
			if _evaluate_conditions(child, context):
				return true
		return false

	if block.has("not"):
		return not _evaluate_conditions(block["not"], context)

	var state: Dictionary = context["state"]
	var flags: Dictionary = state.get("flags", {})
	var seen_nodes: Dictionary = state.get("seen_nodes", {})
	var counters: Dictionary = state.get("counters", {})

	var condition_type: String = str(block.get("type", ""))
	var key: String = str(block.get("key", ""))
	var value = block.get("value")
	var current_time: String = str(context.get("time_of_day", default_time_of_day)).to_lower()

	match condition_type:
		"flag_true":
			return bool(flags.get(key, false))

		"flag_false":
			return not bool(flags.get(key, false))

		"stat_gte":
			return int(state.get(key, 0)) >= int(value)

		"stat_lte":
			return int(state.get(key, 0)) <= int(value)

		"stat_eq":
			return int(state.get(key, 0)) == int(value)

		"counter_gte":
			return int(counters.get(key, 0)) >= int(value)

		"counter_lte":
			return int(counters.get(key, 0)) <= int(value)

		"counter_eq":
			return int(counters.get(key, 0)) == int(value)

		"level_gte":
			return int(context.get("level_index", 0)) >= int(value)

		"level_lte":
			return int(context.get("level_index", 0)) <= int(value)

		"level_eq":
			return int(context.get("level_index", 0)) == int(value)

		"max_unlocked_gte":
			return int(context.get("max_unlocked_index", 0)) >= int(value)

		"time_is":
			return current_time == str(value).to_lower()

		"time_in":
			for item in block.get("values", []):
				if current_time == str(item).to_lower():
					return true
			return false

		"seen_node":
			return bool(seen_nodes.get(key, false))

		"not_seen_node":
			return not bool(seen_nodes.get(key, false))

		_:
			# Unknown condition types fail closed to avoid accidental unlocks.
			push_warning("Unknown Seraphina condition type: %s" % condition_type)
			return false


# ------------------------------------------------------------------------------
# Function: _build_choice_view_models
# Purpose:
#   Builds choice payloads for the UI while preserving locked choices so they
#   remain visible but unavailable.
#
# Inputs:
#   raw_choices: Array of original database choice dictionaries.
#
# Outputs:
#   Array of choice view models.
#
# Side Effects:
#   None.
# ------------------------------------------------------------------------------
func _build_choice_view_models(raw_choices: Array) -> Array:
	var context: Dictionary = _build_context()
	var result: Array = []

	for choice in raw_choices:
		var unlocked: bool = _evaluate_conditions(choice.get("conditions", {}), context)

		var vm: Dictionary = choice.duplicate(true)
		vm["__locked"] = not unlocked
		vm["__lock_reason"] = "" if unlocked else _get_choice_lock_reason(choice, context)

		result.append(vm)

	return result


# ------------------------------------------------------------------------------
# Function: _get_choice_lock_reason
# Purpose:
#   Returns the text shown in the tooltip for a locked choice.
#
# Inputs:
#   choice: Dictionary
#   context: Dictionary
#
# Outputs:
#   String
#
# Side Effects:
#   None.
#
# Notes:
#   If the database provides "lock_reason", that exact text is used.
#   Otherwise the manager derives a generic explanation.
# ------------------------------------------------------------------------------
func _get_choice_lock_reason(choice: Dictionary, context: Dictionary) -> String:
	if choice.has("lock_reason"):
		return str(choice.get("lock_reason", "Requirement not met."))

	var conditions = choice.get("conditions", {})
	return _describe_first_failed_requirement(conditions, context)


# ------------------------------------------------------------------------------
# Function: _describe_first_failed_requirement
# Purpose:
#   Produces a user-facing explanation for the first failed requirement in a
#   condition tree.
#
# Inputs:
#   definition: Variant
#   context: Dictionary
#
# Outputs:
#   String
#
# Side Effects:
#   None.
# ------------------------------------------------------------------------------
func _describe_first_failed_requirement(definition, context: Dictionary) -> String:
	if definition == null:
		return "Requirement not met."

	if typeof(definition) != TYPE_DICTIONARY:
		return "Requirement not met."

	var block: Dictionary = definition
	if block.is_empty():
		return "Requirement not met."

	if block.has("all"):
		for child in block["all"]:
			if not _evaluate_conditions(child, context):
				return _describe_first_failed_requirement(child, context)
		return "Requirement not met."

	if block.has("any"):
		for child in block["any"]:
			if _evaluate_conditions(child, context):
				return ""
		return "Requires one of several conditions."

	if block.has("not"):
		if _evaluate_conditions(block["not"], context):
			return "This option is not currently available."
		return ""

	var condition_type: String = str(block.get("type", ""))
	var key: String = str(block.get("key", ""))
	var value = block.get("value")

	match condition_type:
		"flag_true":
			return "Requires %s." % _humanize_requirement_key(key)

		"flag_false":
			return "This option is no longer available."

		"stat_gte":
			return "Requires higher %s." % _humanize_requirement_key(key)

		"stat_lte":
			return "%s is currently too high." % _humanize_requirement_key(key)

		"stat_eq":
			return "Requires exact %s value." % _humanize_requirement_key(key)

		"counter_gte":
			return "Requires more prior conversations."

		"counter_lte":
			return "This option has expired."

		"counter_eq":
			return "Requires a specific prior interaction count."

		"level_gte":
			return "Requires later story progress."

		"level_lte":
			return "Only available earlier in the story."

		"level_eq":
			return "Only available at this story stage."

		"max_unlocked_gte":
			return "Requires later campaign progress."

		"time_is":
			return "Available only during %s." % str(value).capitalize()

		"time_in":
			return "Available only at specific times."

		"seen_node":
			return "Requires a prior conversation."

		"not_seen_node":
			return "You have already discussed this."

		_:
			return "Requirement not met."


# ------------------------------------------------------------------------------
# Function: _humanize_requirement_key
# Purpose:
#   Converts internal stat/flag keys into nicer tooltip text.
#
# Inputs:
#   raw_key: String
#
# Outputs:
#   String
#
# Side Effects:
#   None.
# ------------------------------------------------------------------------------
func _humanize_requirement_key(raw_key: String) -> String:
	var words: PackedStringArray = raw_key.split("_")
	for i in range(words.size()):
		words[i] = words[i].capitalize()
	return " ".join(words)


# ------------------------------------------------------------------------------
# Function: _apply_effects
# Purpose:
#   Applies choice or node effects to the persistent Seraphina relationship
#   state.
#
# Inputs:
#   effects: Array of effect dictionaries.
#
# Outputs:
#   None.
#
# Side Effects:
#   - Mutates CampaignManager NPC relationship data
#
# Supported Effects:
#   add_stat, set_stat
#   set_flag, clear_flag
#   add_counter, set_counter
# ------------------------------------------------------------------------------
func _apply_effects(effects: Array) -> void:
	var state: Dictionary = _get_relationship_state()
	var flags: Dictionary = state.get("flags", {})
	var counters: Dictionary = state.get("counters", {})

	for effect in effects:
		var effect_type: String = str(effect.get("type", ""))
		var key: String = str(effect.get("key", ""))
		var value = effect.get("value")

		match effect_type:
			"add_stat":
				var current_stat: int = int(state.get(key, 0))
				state[key] = clampi(current_stat + int(value), 0, 100)

			"set_stat":
				state[key] = clampi(int(value), 0, 100)

			"set_flag":
				flags[key] = bool(value)

			"clear_flag":
				flags[key] = false

			"add_counter":
				var current_counter: int = int(counters.get(key, 0))
				counters[key] = current_counter + int(value)

			"set_counter":
				counters[key] = int(value)

			_:
				push_warning("Unknown Seraphina effect type: %s" % effect_type)

	state["flags"] = flags
	state["counters"] = counters


# ------------------------------------------------------------------------------
# Function: _mark_node_seen
# Purpose:
#   Marks the current node as seen in persistent state.
#
# Inputs:
#   node_id: String node identifier.
#
# Outputs:
#   None.
#
# Side Effects:
#   - Mutates CampaignManager NPC relationship data
# ------------------------------------------------------------------------------
func _mark_node_seen(node_id: String) -> void:
	var state: Dictionary = _get_relationship_state()
	var seen_nodes: Dictionary = state.get("seen_nodes", {})
	seen_nodes[node_id] = true
	state["seen_nodes"] = seen_nodes


# ------------------------------------------------------------------------------
# Function: _get_relationship_state
# Purpose:
#   Retrieves Seraphina's persistent relationship state from CampaignManager.
#
# Inputs:
#   None.
#
# Outputs:
#   Dictionary reference representing Seraphina's saved state.
#
# Side Effects:
#   - Ensures the state exists before returning it
# ------------------------------------------------------------------------------
func _get_relationship_state() -> Dictionary:
	_ensure_relationship_state()

	if CampaignManager.has_method("get_seraphina_state"):
		return CampaignManager.get_seraphina_state()

	# Defensive fallback for projects that have not yet added the helper.
	if not CampaignManager.has_meta("seraphina_state_fallback"):
		CampaignManager.set_meta("seraphina_state_fallback", SeraphinaDialogueDatabase.get_default_state())

	return CampaignManager.get_meta("seraphina_state_fallback")


# ------------------------------------------------------------------------------
# Function: _ensure_relationship_state
# Purpose:
#   Requests CampaignManager to initialize Seraphina's state if it does not yet
#   exist.
#
# Inputs:
#   None.
#
# Outputs:
#   None.
#
# Side Effects:
#   - May create default persistent state
# ------------------------------------------------------------------------------
func _ensure_relationship_state() -> void:
	if CampaignManager.has_method("ensure_seraphina_state"):
		CampaignManager.ensure_seraphina_state()


# ------------------------------------------------------------------------------
# Function: _persist_state_if_needed
# Purpose:
#   Saves progress after a state change when enabled.
#
# Inputs:
#   None.
#
# Outputs:
#   None.
#
# Side Effects:
#   - May trigger CampaignManager.save_current_progress()
# ------------------------------------------------------------------------------
func _persist_state_if_needed() -> void:
	if not auto_save_after_state_change:
		return

	if CampaignManager.has_method("save_current_progress"):
		CampaignManager.save_current_progress()


# ------------------------------------------------------------------------------
# Function: _get_time_of_day
# Purpose:
#   Retrieves the current time-of-day token used by routing rules.
#
# Inputs:
#   None.
#
# Outputs:
#   String such as "morning", "evening", or "night".
#
# Side Effects:
#   None.
# ------------------------------------------------------------------------------
func _get_time_of_day() -> String:
	var raw_value = CampaignManager.get("camp_time_of_day")
	if raw_value == null:
		return default_time_of_day
	return str(raw_value).to_lower()


# ------------------------------------------------------------------------------
# Function: _resolve_tokens
# Purpose:
#   Performs lightweight token replacement inside dialogue text.
#
# Inputs:
#   raw_text: String with optional tokens.
#
# Outputs:
#   Final text with tokens resolved.
#
# Side Effects:
#   None.
#
# Supported Tokens:
#   {player_name}
# ------------------------------------------------------------------------------
func _resolve_tokens(raw_text: String) -> String:
	var player_name: String = "Commander"

	if CampaignManager.custom_avatar is Dictionary:
		player_name = str(CampaignManager.custom_avatar.get("unit_name", "Commander"))

	return raw_text.replace("{player_name}", player_name)


# ------------------------------------------------------------------------------
# Function: _get_choice_buttons
# Purpose:
#   Returns the supported UI choice buttons in render order.
#
# Inputs:
#   None.
#
# Outputs:
#   Array[Button]
#
# Side Effects:
#   None.
#
# Notes:
#   Prefers the upgraded UI helper. Falls back to direct field access.
# ------------------------------------------------------------------------------
func _get_choice_buttons() -> Array:
	if parent_ui != null and parent_ui.has_method("get_choice_buttons"):
		return parent_ui.get_choice_buttons()

	var buttons: Array = []

	if parent_ui.choice_btn_1 != null:
		buttons.append(parent_ui.choice_btn_1)
	if parent_ui.choice_btn_2 != null:
		buttons.append(parent_ui.choice_btn_2)

	# Optional third and fourth buttons.
	if "choice_btn_3" in parent_ui and parent_ui.choice_btn_3 != null:
		buttons.append(parent_ui.choice_btn_3)
	if "choice_btn_4" in parent_ui and parent_ui.choice_btn_4 != null:
		buttons.append(parent_ui.choice_btn_4)

	return buttons


# ------------------------------------------------------------------------------
# Function: _hide_all_choices
# Purpose:
#   Hides all choice buttons and the choice container.
#
# Inputs:
#   None.
#
# Outputs:
#   None.
#
# Side Effects:
#   - Mutates parent UI visibility
# ------------------------------------------------------------------------------
func _hide_all_choices() -> void:
	if parent_ui == null:
		return

	if parent_ui.has_method("_hide_all_choice_buttons"):
		parent_ui._hide_all_choice_buttons()
		return

	for button in _get_choice_buttons():
		button.hide()

	parent_ui.choice_container.hide()


# ------------------------------------------------------------------------------
# Function: _end_conversation
# Purpose:
#   Cleanly closes the active Seraphina conversation.
#
# Inputs:
#   None.
#
# Outputs:
#   None.
#
# Side Effects:
#   - Hides dialogue controls
#   - Emits dialogue_finished
# ------------------------------------------------------------------------------
func _end_conversation() -> void:
	_conversation_active = false
	_hide_all_choices()

	if parent_ui != null:
		parent_ui.next_btn.hide()
		parent_ui.dialogue_panel.hide()

	reset_mood()
	dialogue_finished.emit(_current_node_id)


# ------------------------------------------------------------------------------
# Function: _play_idle_breathing
# Purpose:
#   Applies a subtle idle scale tween to Seraphina's explicitly assigned portrait
#   node only.
#
# Inputs:
#   None.
#
# Outputs:
#   None.
#
# Side Effects:
#   - Starts an infinite tween on the portrait only
# ------------------------------------------------------------------------------
func _play_idle_breathing() -> void:
	if visual_node == null:
		return

	if breathing_tween != null:
		breathing_tween.kill()
		breathing_tween = null

	visual_node.scale = Vector2(base_scale_factor, base_scale_factor)

	if visual_node.size != Vector2.ZERO:
		visual_node.pivot_offset = visual_node.size / 2.0

	var inhale := Vector2(base_scale_factor * 1.03, base_scale_factor * 1.03)
	var exhale := Vector2(base_scale_factor, base_scale_factor)

	breathing_tween = create_tween()
	breathing_tween.set_loops()
	breathing_tween.tween_property(visual_node, "scale", inhale, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breathing_tween.tween_property(visual_node, "scale", exhale, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ------------------------------------------------------------------------------
# Function: set_mood
# Purpose:
#   Maps a portrait tag from the data file to the actual Seraphina texture.
#
# Inputs:
#   mood_name: String portrait tag.
#
# Outputs:
#   None.
#
# Side Effects:
#   - Replaces the active portrait texture on the visual node
# ------------------------------------------------------------------------------
func set_mood(mood_name: String) -> void:
	if visual_node == null:
		return

	var target_tex: Texture2D = tex_neutral

	match mood_name.to_lower():
		"smiling":
			target_tex = tex_smiling if tex_smiling != null else tex_neutral
		"blushing":
			target_tex = tex_blushing if tex_blushing != null else tex_neutral
		"thinking":
			target_tex = tex_thinking if tex_thinking != null else tex_neutral
		"angry":
			target_tex = tex_angry if tex_angry != null else tex_neutral
		_:
			target_tex = tex_neutral

	if target_tex == null:
		return

	if visual_node is TextureButton:
		var tex_button := visual_node as TextureButton
		tex_button.texture_normal = target_tex
		tex_button.texture_pressed = target_tex
		tex_button.texture_hover = target_tex
		tex_button.texture_disabled = target_tex
	elif visual_node is TextureRect:
		var tex_rect := visual_node as TextureRect
		tex_rect.texture = target_tex

	if visual_node.size != Vector2.ZERO:
		visual_node.pivot_offset = visual_node.size / 2.0


# ------------------------------------------------------------------------------
# Function: reset_mood
# Purpose:
#   Convenience wrapper to restore the neutral portrait.
#
# Inputs:
#   None.
#
# Outputs:
#   None.
#
# Side Effects:
#   - Updates portrait texture
# ------------------------------------------------------------------------------
func reset_mood() -> void:
	set_mood("neutral")
