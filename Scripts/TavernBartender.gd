# ==============================================================================
# Script Name: TavernBartender.gd
# Purpose:
#   Drives Seraphina's full tavern interaction flow using a data-driven dialogue
#   database rather than hardcoded conversation branches.
#
# Overall Goal:
#   Replace a simple linear bartender interaction with a reusable narrative
#   system that supports:
#     - Multi-axis relationship tracking
#     - Persistent memory flags
#     - Conditional dialogue routing
#     - Level and time-based entry points
#     - Portrait mood switching
#     - Existing tavern UI integration
#     - SilentWolf notice-board retrieval
#
# How This Fits Into The Project:
#   This script acts as the runtime conversation controller for Seraphina. It
#   reads and writes persistent narrative state from CampaignManager, evaluates
#   dialogue conditions, applies state changes from player choices, and updates
#   the tavern UI.
#
# Dependencies:
#   - CampaignManager.gd
#       Expected helpers:
#         ensure_seraphina_state()
#         get_seraphina_state()
#         sync_seraphina_legacy_cache()
#         save_current_progress()
#       Expected fields:
#         npc_relationships
#         current_level_index
#         camp_time_of_day
#         seraphina_romance_rank
#   - Parent tavern UI node
#       Expected members:
#         dialogue_panel
#         dialogue_text
#         choice_container
#         choice_btn_1
#         choice_btn_2
#         next_btn
#         active_character_a
#         active_character_b
#       Optional methods:
#         _display_line(line_dict)
#         _disconnect_all_pressed(button)
#         _show_system_message(text, color)
#   - SilentWolf autoload for the notice-board feature
#
# AI / Code Review Guidance:
#   Entry Points:
#     - interact()
#     - _fetch_silentwolf_motd()
#
#   Core Logic Sections:
#     - _resolve_entry_node_id()
#     - _conditions_pass()
#     - _apply_effects()
#     - _show_node()
#
#   Configuration Area:
#     - _build_dialogue_database()
#
#   Extension Points:
#     - Add new entry rules in the database
#     - Add new dialogue nodes in the database
#     - Add new effect types in _apply_effects()
#     - Add new condition operators in _conditions_pass()
# ==============================================================================

extends Node

@export var bartender_name: String = "Seraphina"

# --- REQUIRED NODE REFERENCES ---
@export var portrait_node: TextureButton
@export var dialogue_manager: Node

# --- MOOD PORTRAITS ---
@export_group("Mood Portraits")
@export var tex_neutral: Texture2D
@export var tex_smiling: Texture2D
@export var tex_blushing: Texture2D
@export var tex_thinking: Texture2D
@export var tex_angry: Texture2D

# --- SETTINGS ---
@export_range(0.1, 2.0) var base_scale_factor: float = 1.0

var parent_ui: Control = null
var visual_node: Control = null
var breathing_tween: Tween = null
var admin_input_box: LineEdit = null

# Runtime dialogue state.
var dialogue_db: Dictionary = {}
var portrait_map: Dictionary = {}
var current_node_id: String = ""
var current_node_data: Dictionary = {}
var interaction_active: bool = false

# ==============================================================================
# CORE INITIALIZATION
# ==============================================================================

# Function:
#   _ready
# Purpose:
#   Initializes portrait lookup data, builds the full dialogue database, and
#   starts the ambient breathing animation for the bartender portrait node.
# Inputs:
#   None.
# Outputs:
#   None.
# Side Effects:
#   Populates internal dictionaries and schedules animation setup.
func _ready() -> void:
	parent_ui = get_parent() as Control

	# Build the full dialogue database once at startup.
	dialogue_db = _build_dialogue_database()

	# Use the explicitly assigned portrait node only.
	visual_node = portrait_node

	if visual_node == null:
		push_warning("TavernBartender.gd: portrait_node is not assigned.")
		return

	# Connect the portrait click once.
	if portrait_node != null and not portrait_node.pressed.is_connected(interact):
		portrait_node.pressed.connect(interact)

	# Force a valid starting portrait before any interaction.
	_set_mood("neutral")

	# Start the idle breathing only on the portrait.
	call_deferred("_play_idle_breathing")
# Function:
#   _play_idle_breathing
# Purpose:
#   Applies a subtle looped scale tween to Seraphina's visual node to keep the
#   tavern portrait from feeling static.
# Inputs:
#   None.
# Outputs:
#   None.
# Side Effects:
#   Modifies the scale and pivot of the bartender visual node.
func _play_idle_breathing() -> void:
	# Safety check: do not animate the whole parent scene by accident.
	if visual_node == null:
		return

	# Kill any previous tween before creating a new looping one.
	if breathing_tween != null:
		breathing_tween.kill()
		breathing_tween = null

	visual_node.scale = Vector2(base_scale_factor, base_scale_factor)

	# Pivot around the center of the portrait only.
	if visual_node.size != Vector2.ZERO:
		visual_node.pivot_offset = visual_node.size / 2.0

	var inhale := Vector2(base_scale_factor * 1.03, base_scale_factor * 1.03)
	var exhale := Vector2(base_scale_factor, base_scale_factor)

	breathing_tween = create_tween()
	breathing_tween.set_loops()

	breathing_tween.tween_property(
		visual_node,
		"scale",
		inhale,
		2.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	breathing_tween.tween_property(
		visual_node,
		"scale",
		exhale,
		2.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
# ==============================================================================
# PUBLIC INTERACTION ENTRY
# ==============================================================================

# Function:
#   interact
# Purpose:
#   Starts a Seraphina interaction by resolving the correct entry node based on
#   campaign progression, time of day, and relationship state.
# Inputs:
#   None.
# Outputs:
#   None.
# Side Effects:
#   Opens the tavern dialogue UI, updates portrait mood, and begins a dialogue
#   session.
func interact() -> void:
	print("Seraphina portrait clicked")

	_ensure_campaign_state()
	_reset_mood()

	if parent_ui == null:
		push_warning("TavernBartender requires a valid parent UI node.")
		return

	interaction_active = true

	# Force the tavern UI into a clean dialogue state immediately.
	parent_ui.dialogue_panel.show()
	parent_ui.choice_container.hide()
	parent_ui.choice_btn_1.hide()
	parent_ui.choice_btn_2.hide()
	parent_ui.next_btn.hide()

	parent_ui.active_character_a = {"unit_name": bartender_name}
	parent_ui.active_character_b = {}

	current_node_id = _resolve_entry_node_id()
	_show_node(current_node_id)

# ==============================================================================
# CAMPAIGN STATE ACCESS
# ==============================================================================

# Function:
#   _ensure_campaign_state
# Purpose:
#   Ensures the shared Seraphina relationship state exists before any dialogue
#   evaluation or mutation occurs.
# Inputs:
#   None.
# Outputs:
#   None.
# Side Effects:
#   May create default Seraphina state in CampaignManager.
func _ensure_campaign_state() -> void:
	if CampaignManager.has_method("ensure_seraphina_state"):
		CampaignManager.ensure_seraphina_state()


# Function:
#   _get_seraphina_state_copy
# Purpose:
#   Returns a deep copy of Seraphina's persistent relationship state so runtime
#   modifications can be safely applied and then committed.
# Inputs:
#   None.
# Outputs:
#   Dictionary representing Seraphina's state.
# Side Effects:
#   None.
func _get_seraphina_state_copy() -> Dictionary:
	_ensure_campaign_state()

	if CampaignManager.has_method("get_seraphina_state"):
		return CampaignManager.get_seraphina_state().duplicate(true)

	if CampaignManager.npc_relationships.has("seraphina"):
		return CampaignManager.npc_relationships["seraphina"].duplicate(true)

	return {
		"affection": 0,
		"trust": 0,
		"professionalism": 0,
		"flags": {},
		"seen_nodes": {},
		"counters": {}
	}


# Function:
#   _commit_seraphina_state
# Purpose:
#   Writes updated state back into CampaignManager, refreshes legacy compatibility
#   mirrors, and optionally persists progress to the active save slot.
# Inputs:
#   state: Dictionary
# Outputs:
#   None.
# Side Effects:
#   Mutates CampaignManager persistent state and may trigger rank-up messaging.
func _commit_seraphina_state(state: Dictionary) -> void:
	var previous_rank: int = int(CampaignManager.seraphina_romance_rank)

	CampaignManager.npc_relationships["seraphina"] = state.duplicate(true)

	if CampaignManager.has_method("sync_seraphina_legacy_cache"):
		CampaignManager.sync_seraphina_legacy_cache()

	var new_rank: int = int(CampaignManager.seraphina_romance_rank)
	if new_rank > previous_rank:
		_show_rank_update_notification(previous_rank, new_rank)

	if CampaignManager.has_method("save_current_progress"):
		CampaignManager.save_current_progress()


# Function:
#   _get_runtime_context
# Purpose:
#   Builds a consolidated context dictionary used by condition evaluation.
# Inputs:
#   None.
# Outputs:
#   Dictionary with campaign, relationship, flags, seen node, and counter data.
# Side Effects:
#   None.
func _get_runtime_context() -> Dictionary:
	var state: Dictionary = _get_seraphina_state_copy()
	var flags: Dictionary = state.get("flags", {})
	var seen_nodes: Dictionary = state.get("seen_nodes", {})
	var counters: Dictionary = state.get("counters", {})

	return {
		"level_index": int(CampaignManager.current_level_index),
		"max_unlocked_index": int(CampaignManager.max_unlocked_index),
		"time_of_day": str(CampaignManager.camp_time_of_day).to_lower(),
		"state": state,
		"flags": flags,
		"seen_nodes": seen_nodes,
		"counters": counters
	}

# ==============================================================================
# DIALOGUE DATABASE
# ==============================================================================

# Function:
#   _build_dialogue_database
# Purpose:
#   Defines all entry rules and dialogue nodes for Seraphina in a data-driven
#   structure. This is the primary configuration area for the narrative system.
# Inputs:
#   None.
# Outputs:
#   Dictionary containing entry rules and nodes.
# Side Effects:
#   None.
func _build_dialogue_database() -> Dictionary:
	return {
		"entry_rules": [
			{
				"target": "busy_repeat_visit",
				"conditions": {
					"flag_true": "met_this_visit"
				}
			},
			{
				"target": "after_hours_open",
				"conditions": {
					"all": [
						{"level_gte": 2},
						{"time_is": "night"},
						{"flag_true": "drank_the_special"},
						{"flag_false": "after_hours_talk"},
						{"stat_gte": {"trust": 35, "affection": 20}}
					]
				}
			},
			{
				"target": "late_campaign_return",
				"conditions": {
					"all": [
						{"level_gte": 2},
						{"counter_gte": {"times_spoken": 4}},
						{"stat_gte": {"trust": 28}}
					]
				}
			},
			{
				"target": "special_followup",
				"conditions": {
					"all": [
						{"flag_true": "drank_the_special"},
						{"flag_false": "discussed_special_aftertaste"}
					]
				}
			},
			{
				"target": "scar_followup",
				"conditions": {
					"all": [
						{"flag_true": "asked_about_scar"},
						{"not_seen_node": "scar_followup"}
					]
				}
			},
			{
				"target": "regular_evening",
				"conditions": {
					"all": [
						{"flag_true": "met_seraphina"},
						{"time_is": "evening"}
					]
				}
			},
			{
				"target": "first_meeting",
				"conditions": {
					"flag_false": "met_seraphina"
				}
			},
			{
				"target": "default_root",
				"conditions": {}
			}
		],

		"nodes": {
			"busy_repeat_visit": {
				"speaker": "Seraphina",
				"portrait": "thinking",
				"text": "You already had your private minute for this stop. Ask for the board or let me work.",
				"choices": [
					{
						"text": "What is the word tonight.",
						"special_action": "motd"
					},
					{
						"text": "Fair enough.",
						"special_action": "close"
					}
				]
			},

			"first_meeting": {
				"speaker": "Seraphina",
				"portrait": "neutral",
				"text": "New face. Keep the mud near the door and the questions short.",
				"choices": [
					{
						"text": "I need information and a table in the corner.",
						"effects": [
							{"set_flag": "met_seraphina", "value": true},
							{"set_flag": "met_this_visit", "value": true},
							{"increment_counter": "times_spoken", "amount": 1},
							{"delta": {"trust": 2, "professionalism": 3}}
						],
						"next": "first_meeting_professional"
					},
					{
						"text": "Long march. Something quiet and whatever passes for clean here.",
						"effects": [
							{"set_flag": "met_seraphina", "value": true},
							{"set_flag": "met_this_visit", "value": true},
							{"increment_counter": "times_spoken", "amount": 1},
							{"delta": {"affection": 2, "trust": 1, "professionalism": 1}}
						],
						"next": "first_meeting_soft"
					}
				]
			},

			"first_meeting_professional": {
				"speaker": "Seraphina",
				"portrait": "thinking",
				"text": "Corner table is free. Information costs less if you do not waste my time.",
				"next": "default_root"
			},

			"first_meeting_soft": {
				"speaker": "Seraphina",
				"portrait": "smiling",
				"text": "Quiet is available. Clean depends on your standards.",
				"next": "default_root"
			},

			"default_root": {
				"speaker": "Seraphina",
				"portrait": "neutral",
				"text": "You made it back. The room is loud, the ale is average, and the gossip is worse. Speak.",
				"on_enter_effects": [
					{"set_flag": "met_seraphina", "value": true},
					{"set_flag": "met_this_visit", "value": true},
					{"increment_counter": "times_spoken", "amount": 1}
				],
				"choices": [
					{
						"text": "What is the word tonight.",
						"special_action": "motd"
					},
					{
						"text": "Stay and talk for a while.",
						"next": "talk_hub_one"
					}
				]
			},

			"regular_evening": {
				"speaker": "Seraphina",
				"portrait": "smiling",
				"text": "Back again. Sit if you are staying. Speak if you are not.",
				"on_enter_effects": [
					{"set_flag": "met_seraphina", "value": true},
					{"set_flag": "met_this_visit", "value": true},
					{"increment_counter": "times_spoken", "amount": 1},
					{"delta": {"affection": 1}}
				],
				"choices": [
					{
						"text": "What is the word tonight.",
						"special_action": "motd"
					},
					{
						"text": "Stay and talk for a while.",
						"next": "talk_hub_one"
					}
				]
			},

			"special_followup": {
				"speaker": "Seraphina",
				"portrait": "smiling",
				"text": "You still look like you regret the special. That means it worked.",
				"on_enter_effects": [
					{"set_flag": "met_seraphina", "value": true},
					{"set_flag": "met_this_visit", "value": true},
					{"increment_counter": "times_spoken", "amount": 1}
				],
				"choices": [
					{
						"text": "What exactly was in it.",
						"effects": [
							{"set_flag": "discussed_special_aftertaste", "value": true},
							{"delta": {"trust": 2, "professionalism": 1}}
						],
						"next": "special_aftertaste_query"
					},
					{
						"text": "It did the job.",
						"effects": [
							{"set_flag": "discussed_special_aftertaste", "value": true},
							{"delta": {"affection": 1, "professionalism": 2}}
						],
						"next": "special_aftertaste_brief"
					}
				]
			},

			"special_aftertaste_query": {
				"speaker": "Seraphina",
				"portrait": "thinking",
				"text": "Juniper, clove, black citrus peel, and one ingredient I do not name for free. The point is not taste. The point is clarity.",
				"next": "talk_hub_two"
			},

			"special_aftertaste_brief": {
				"speaker": "Seraphina",
				"portrait": "smiling",
				"text": "That is the correct review. It was never meant to be pleasant.",
				"next": "talk_hub_two"
			},

			"scar_followup": {
				"speaker": "Seraphina",
				"portrait": "thinking",
				"text": "You keep looking at the scar. Either ask about it or stop staring.",
				"on_enter_effects": [
					{"set_flag": "met_seraphina", "value": true},
					{"set_flag": "met_this_visit", "value": true},
					{"increment_counter": "times_spoken", "amount": 1}
				],
				"choices": [
					{
						"text": "Then I am asking.",
						"effects": [
							{"delta": {"trust": 3}}
						],
						"next": "scar_answer"
					},
					{
						"text": "Fair point. Change of subject.",
						"effects": [
							{"delta": {"professionalism": 2}}
						],
						"next": "talk_hub_two"
					}
				]
			},

			"scar_answer": {
				"speaker": "Seraphina",
				"portrait": "neutral",
				"text": "Dockside knife. Bad angle, slow healer, useful reminder. People become careless when they think tavern work is soft work.",
				"next": "talk_hub_two"
			},

			"late_campaign_return": {
				"speaker": "Seraphina",
				"portrait": "thinking",
				"text": "The streets get quieter every week. That worries me more than shouting ever did.",
				"on_enter_effects": [
					{"set_flag": "met_seraphina", "value": true},
					{"set_flag": "met_this_visit", "value": true},
					{"increment_counter": "times_spoken", "amount": 1},
					{"delta": {"trust": 1}}
				],
				"choices": [
					{
						"text": "You think the city is folding in on itself.",
						"effects": [
							{"delta": {"trust": 3, "professionalism": 1}}
						],
						"next": "city_pressure_response"
					},
					{
						"text": "You still watch the door every time I enter.",
						"effects": [
							{"delta": {"affection": 2, "trust": 2}}
						],
						"next": "door_watch_response"
					}
				]
			},

			"city_pressure_response": {
				"speaker": "Seraphina",
				"portrait": "thinking",
				"text": "Cities do not collapse all at once. They narrow. Fewer shipments. Fewer jokes. More people listening before they speak.",
				"next": "talk_hub_two"
			},

			"door_watch_response": {
				"speaker": "Seraphina",
				"portrait": "blushing",
				"text": "Habit first. Inventory second. Recognition somewhere after that. Do not make me rank it more precisely than necessary.",
				"next": "talk_hub_two"
			},

			"after_hours_open": {
				"speaker": "Seraphina",
				"portrait": "thinking",
				"text": "Chairs are up. Fire is low. If you planned to leave, now would be the efficient time.",
				"on_enter_effects": [
					{"set_flag": "met_seraphina", "value": true},
					{"set_flag": "met_this_visit", "value": true},
					{"increment_counter": "times_spoken", "amount": 1}
				],
				"choices": [
					{
						"text": "Then I will stay until you finish closing.",
						"effects": [
							{"set_flag": "after_hours_talk", "value": true},
							{"delta": {"affection": 4, "trust": 4, "professionalism": 1}}
						],
						"next": "after_hours_conversation"
					},
					{
						"text": "Another time.",
						"effects": [
							{"delta": {"professionalism": 1}}
						],
						"next": "after_hours_declined"
					}
				]
			},

			"after_hours_conversation": {
				"speaker": "Seraphina",
				"portrait": "blushing",
				"text": "I keep the ledger, count the bottles, and notice who returns. You have been consistent. In this line of work, consistency is not a small thing.",
				"next": "after_hours_close"
			},

			"after_hours_declined": {
				"speaker": "Seraphina",
				"portrait": "neutral",
				"text": "Reasonable. Better to leave on time than overstay on sentiment.",
				"next": "after_hours_close"
			},

			"after_hours_close": {
				"speaker": "Seraphina",
				"portrait": "smiling",
				"text": "That is enough honesty for one night.",
				"choices": [
					{
						"text": "Understood.",
						"special_action": "close"
					}
				]
			},

			"talk_hub_one": {
				"speaker": "Seraphina",
				"portrait": "neutral",
				"text": "Choose the subject carefully. Some answers are cheaper than others.",
				"choices": [
					{
						"text": "Ask about the scar.",
						"conditions": {
							"all": [
								{"stat_gte": {"trust": 10}},
								{"flag_false": "asked_about_scar"}
							]
						},
						"effects": [
							{"set_flag": "asked_about_scar", "value": true},
							{"delta": {"trust": 2}}
						],
						"next": "scar_answer"
					},
					{
						"text": "Order the house special.",
						"conditions": {
							"all": [
								{"level_gte": 1},
								{"flag_false": "drank_the_special"}
							]
						},
						"next": "special_offer"
					},
					{
						"text": "Why do you watch the door so closely.",
						"next": "door_reason"
					},
					{
						"text": "Leave it there.",
						"special_action": "close"
					}
				]
			},

			"special_offer": {
				"speaker": "Seraphina",
				"portrait": "thinking",
				"text": "I can pour the special. I do not refund mistakes.",
				"choices": [
					{
						"text": "Pour it.",
						"effects": [
							{"set_flag": "drank_the_special", "value": true},
							{"delta": {"affection": 3, "trust": 2, "professionalism": -1}}
						],
						"next": "drink_special_response"
					},
					{
						"text": "I will keep my judgment intact.",
						"effects": [
							{"delta": {"professionalism": 2}}
						],
						"next": "talk_hub_two"
					}
				]
			},

			"drink_special_response": {
				"speaker": "Seraphina",
				"portrait": "smiling",
				"text": "Good. Either you have a strong constitution or a weak sense of self-preservation.",
				"next": "talk_hub_two"
			},

			"door_reason": {
				"speaker": "Seraphina",
				"portrait": "thinking",
				"text": "Because trouble almost always announces itself by entering badly. The door gives me a full second of warning. That second pays rent.",
				"effects_on_exit": [
					{"delta": {"trust": 2, "professionalism": 1}}
				],
				"next": "talk_hub_two"
			},

			"talk_hub_two": {
				"speaker": "Seraphina",
				"portrait": "neutral",
				"text": "Anything else.",
				"choices": [
					{
						"text": "How is business holding.",
						"conditions": {
							"stat_gte": {"professionalism": 10}
						},
						"effects": [
							{"delta": {"professionalism": 2, "trust": 1}}
						],
						"next": "business_response"
					},
					{
						"text": "What keeps you here, specifically.",
						"conditions": {
							"stat_gte": {"trust": 18}
						},
						"effects": [
							{"delta": {"affection": 2, "trust": 2}}
						],
						"next": "why_here_response"
					},
					{
						"text": "What is the word tonight.",
						"special_action": "motd"
					},
					{
						"text": "That is enough for now.",
						"special_action": "close"
					}
				]
			},

			"business_response": {
				"speaker": "Seraphina",
				"portrait": "thinking",
				"text": "Margins are narrower, suppliers are slower, and soldiers drink like they expect not to wake. So, by tavern standards, stable.",
				"next": "end_node"
			},

			"why_here_response": {
				"speaker": "Seraphina",
				"portrait": "smiling",
				"text": "Because people speak more honestly when they are tired, and because this room lets me see the city one table at a time. Lately, it also lets me see when you return.",
				"next": "end_node"
			},

			"end_node": {
				"speaker": "Seraphina",
				"portrait": "neutral",
				"text": "That will have to do for tonight.",
				"choices": [
					{
						"text": "Understood.",
						"special_action": "close"
					}
				]
			}
		}
	}

# ==============================================================================
# ENTRY RESOLUTION AND CONDITION EVALUATION
# ==============================================================================

# Function:
#   _resolve_entry_node_id
# Purpose:
#   Evaluates entry rules from the dialogue database and returns the first valid
#   target node for the current context.
# Inputs:
#   None.
# Outputs:
#   String node id.
# Side Effects:
#   None.
func _resolve_entry_node_id() -> String:
	var ctx: Dictionary = _get_runtime_context()
	var entry_rules: Array = dialogue_db.get("entry_rules", [])

	for rule in entry_rules:
		var conditions: Dictionary = rule.get("conditions", {})
		if _conditions_pass(conditions, ctx):
			return str(rule.get("target", "default_root"))

	return "default_root"


# Function:
#   _conditions_pass
# Purpose:
#   Recursively evaluates a condition block against the current runtime context.
# Inputs:
#   conditions: Dictionary
#   ctx: Dictionary
# Outputs:
#   bool
# Side Effects:
#   None.
func _conditions_pass(conditions: Dictionary, ctx: Dictionary) -> bool:
	if conditions.is_empty():
		return true

	if conditions.has("all"):
		for sub_condition in conditions["all"]:
			if not _conditions_pass(sub_condition, ctx):
				return false

	if conditions.has("any"):
		var any_passed: bool = false
		for sub_condition in conditions["any"]:
			if _conditions_pass(sub_condition, ctx):
				any_passed = true
				break
		if not any_passed:
			return false

	if conditions.has("not"):
		if _conditions_pass(conditions["not"], ctx):
			return false

	var flags: Dictionary = ctx.get("flags", {})
	var state: Dictionary = ctx.get("state", {})
	var seen_nodes: Dictionary = ctx.get("seen_nodes", {})
	var counters: Dictionary = ctx.get("counters", {})
	var level_index: int = int(ctx.get("level_index", 0))
	var time_of_day: String = str(ctx.get("time_of_day", "evening")).to_lower()

	if conditions.has("flag_true"):
		if not bool(flags.get(str(conditions["flag_true"]), false)):
			return false

	if conditions.has("flag_false"):
		if bool(flags.get(str(conditions["flag_false"]), false)):
			return false

	if conditions.has("level_gte"):
		if level_index < int(conditions["level_gte"]):
			return false

	if conditions.has("level_lte"):
		if level_index > int(conditions["level_lte"]):
			return false

	if conditions.has("time_is"):
		var target_time = conditions["time_is"]
		if target_time is Array:
			var match_found: bool = false
			for value in target_time:
				if time_of_day == str(value).to_lower():
					match_found = true
					break
			if not match_found:
				return false
		else:
			if time_of_day != str(target_time).to_lower():
				return false

	if conditions.has("seen_node"):
		if not bool(seen_nodes.get(str(conditions["seen_node"]), false)):
			return false

	if conditions.has("not_seen_node"):
		if bool(seen_nodes.get(str(conditions["not_seen_node"]), false)):
			return false

	if conditions.has("stat_gte"):
		var required_stats: Dictionary = conditions["stat_gte"]
		for stat_key in required_stats.keys():
			if int(state.get(str(stat_key), 0)) < int(required_stats[stat_key]):
				return false

	if conditions.has("stat_lte"):
		var max_stats: Dictionary = conditions["stat_lte"]
		for stat_key in max_stats.keys():
			if int(state.get(str(stat_key), 0)) > int(max_stats[stat_key]):
				return false

	if conditions.has("counter_gte"):
		var required_counters: Dictionary = conditions["counter_gte"]
		for counter_key in required_counters.keys():
			if int(counters.get(str(counter_key), 0)) < int(required_counters[counter_key]):
				return false

	return true

# ==============================================================================
# NODE DISPLAY AND FLOW CONTROL
# ==============================================================================

# Function:
#   _show_node
# Purpose:
#   Displays a single dialogue node, applies on-enter effects, updates seen-node
#   tracking, and configures either next-step flow or player choices.
# Inputs:
#   node_id: String
# Outputs:
#   None.
# Side Effects:
#   Mutates relationship state, updates UI, changes portrait mood.
func _show_node(node_id: String) -> void:
	var nodes: Dictionary = dialogue_db.get("nodes", {})
	if not nodes.has(node_id):
		push_warning("TavernBartender missing dialogue node: %s" % node_id)
		_close_interaction()
		return

	current_node_id = node_id
	current_node_data = nodes[node_id]

	_mark_node_seen(node_id)

	var on_enter_effects: Array = current_node_data.get("on_enter_effects", [])
	if not on_enter_effects.is_empty():
		_apply_effects(on_enter_effects)

	_display_current_node(current_node_data)
	_configure_navigation_for_current_node()


# Function:
#   _display_current_node
# Purpose:
#   Renders the current node text and speaker to the tavern UI and applies the
#   requested portrait mood.
# Inputs:
#   node_data: Dictionary
# Outputs:
#   None.
# Side Effects:
#   Updates UI labels, portrait, panel visibility, and active speaker data.
func _display_current_node(node_data: Dictionary) -> void:
	var speaker_name: String = str(node_data.get("speaker", bartender_name))
	var line_text: String = str(node_data.get("text", ""))
	var portrait_tag: String = str(node_data.get("portrait", "neutral")).to_lower()

	_set_mood(portrait_tag)

	if parent_ui == null:
		return

	# Always force the dialogue panel visible when a line is shown.
	parent_ui.dialogue_panel.show()

	parent_ui.active_character_a = {"unit_name": speaker_name}
	parent_ui.active_character_b = {}

	if parent_ui.has_method("_display_line"):
		parent_ui._display_line({
			"speaker": speaker_name,
			"text": line_text
		})
	else:
		parent_ui.dialogue_text.text = line_text
		if parent_ui.has_node("SpeakerName"):
			parent_ui.speaker_name.text = speaker_name

# Function:
#   _configure_navigation_for_current_node
# Purpose:
#   Sets up the choice buttons or the next button depending on the shape of the
#   current node.
# Inputs:
#   None.
# Outputs:
#   None.
# Side Effects:
#   Binds button signals and changes button visibility.
func _configure_navigation_for_current_node() -> void:
	_hide_next_button()
	_hide_choice_container()

	var choices: Array = _get_available_choices_for_node(current_node_data)

	if not choices.is_empty():
		_show_choice_container()
		_bind_choice_buttons(choices)
		return

	if current_node_data.has("next") or current_node_data.has("effects_on_exit"):
		_show_next_button()
		_bind_next_button()
		return

	_show_choice_container()
	_bind_choice_buttons([
		{
			"text": "Leave it there.",
			"special_action": "close"
		}
	])


# Function:
#   _get_available_choices_for_node
# Purpose:
#   Filters a node's declared choices against the runtime context. The current
#   tavern UI only supports two visible buttons, so the first two valid choices
#   are returned.
# Inputs:
#   node_data: Dictionary
# Outputs:
#   Array of visible choice dictionaries.
# Side Effects:
#   None.
func _get_available_choices_for_node(node_data: Dictionary) -> Array:
	var visible_choices: Array = []
	var ctx: Dictionary = _get_runtime_context()
	var node_choices: Array = node_data.get("choices", [])

	for choice in node_choices:
		var conditions: Dictionary = choice.get("conditions", {})
		if _conditions_pass(conditions, ctx):
			visible_choices.append(choice)

	if visible_choices.size() > 2:
		return [visible_choices[0], visible_choices[1]]

	return visible_choices


# Function:
#   _bind_choice_buttons
# Purpose:
#   Assigns up to two choice dictionaries to the UI buttons.
# Inputs:
#   visible_choices: Array
# Outputs:
#   None.
# Side Effects:
#   Rewires button pressed handlers and updates button labels.
func _bind_choice_buttons(visible_choices: Array) -> void:
	_disconnect_button(parent_ui.choice_btn_1)
	_disconnect_button(parent_ui.choice_btn_2)

	parent_ui.choice_btn_1.hide()
	parent_ui.choice_btn_2.hide()

	if visible_choices.size() >= 1:
		parent_ui.choice_btn_1.text = str(visible_choices[0].get("text", "Continue"))
		parent_ui.choice_btn_1.show()
		parent_ui.choice_btn_1.pressed.connect(_on_choice_selected.bind(visible_choices[0]), CONNECT_ONE_SHOT)

	if visible_choices.size() >= 2:
		parent_ui.choice_btn_2.text = str(visible_choices[1].get("text", "Continue"))
		parent_ui.choice_btn_2.show()
		parent_ui.choice_btn_2.pressed.connect(_on_choice_selected.bind(visible_choices[1]), CONNECT_ONE_SHOT)


# Function:
#   _bind_next_button
# Purpose:
#   Connects the next button to the current node's continuation logic.
# Inputs:
#   None.
# Outputs:
#   None.
# Side Effects:
#   Rewires next button pressed handler.
func _bind_next_button() -> void:
	_disconnect_button(parent_ui.next_btn)
	parent_ui.next_btn.pressed.connect(_advance_from_current_node, CONNECT_ONE_SHOT)


# Function:
#   _advance_from_current_node
# Purpose:
#   Applies any node-level exit effects and advances to the next node, or closes
#   the interaction if no next node exists.
# Inputs:
#   None.
# Outputs:
#   None.
# Side Effects:
#   Mutates relationship state and changes current dialogue node.
func _advance_from_current_node() -> void:
	var exit_effects: Array = current_node_data.get("effects_on_exit", [])
	if not exit_effects.is_empty():
		_apply_effects(exit_effects)

	if current_node_data.has("next"):
		_show_node(str(current_node_data["next"]))
		return

	_close_interaction()

# ==============================================================================
# CHOICE RESOLUTION
# ==============================================================================

# Function:
#   _on_choice_selected
# Purpose:
#   Handles player selection from the dialogue UI, applies effects, and routes
#   to the next node or special action.
# Inputs:
#   choice: Dictionary
# Outputs:
#   None.
# Side Effects:
#   Mutates relationship state, changes dialogue flow, may call SilentWolf.
func _on_choice_selected(choice: Dictionary) -> void:
	_hide_choice_container()
	_hide_next_button()

	var choice_effects: Array = choice.get("effects", [])
	if not choice_effects.is_empty():
		_apply_effects(choice_effects)

	if choice.has("special_action"):
		var action_name: String = str(choice.get("special_action", ""))

		if action_name == "motd":
			_fetch_silentwolf_motd()
			return

		if action_name == "close":
			_close_interaction()
			return

	if choice.has("next"):
		_show_node(str(choice["next"]))
		return

	_close_interaction()

# ==============================================================================
# STATE MUTATION
# ==============================================================================

# Function:
#   _apply_effects
# Purpose:
#   Applies declarative effect dictionaries to Seraphina's relationship state.
# Inputs:
#   effects: Array
# Outputs:
#   None.
# Side Effects:
#   Mutates CampaignManager state and may update time of day.
func _apply_effects(effects: Array) -> void:
	var state: Dictionary = _get_seraphina_state_copy()
	var flags: Dictionary = state.get("flags", {})
	var seen_nodes: Dictionary = state.get("seen_nodes", {})
	var counters: Dictionary = state.get("counters", {})

	for effect in effects:
		if effect.has("delta"):
			var delta_map: Dictionary = effect["delta"]
			for stat_key in delta_map.keys():
				var current_value: int = int(state.get(str(stat_key), 0))
				var delta_value: int = int(delta_map[stat_key])
				state[str(stat_key)] = clampi(current_value + delta_value, 0, 100)

		if effect.has("set_stat"):
			var set_map: Dictionary = effect["set_stat"]
			for stat_key in set_map.keys():
				state[str(stat_key)] = clampi(int(set_map[stat_key]), 0, 100)

		if effect.has("set_flag"):
			var flag_key: String = str(effect["set_flag"])
			var flag_value: bool = bool(effect.get("value", true))
			flags[flag_key] = flag_value

		if effect.has("increment_counter"):
			var counter_key: String = str(effect["increment_counter"])
			var amount: int = int(effect.get("amount", 1))
			counters[counter_key] = int(counters.get(counter_key, 0)) + amount

		if effect.has("set_counter"):
			var target_counter_key: String = str(effect["set_counter"])
			counters[target_counter_key] = int(effect.get("value", 0))

		if effect.has("mark_seen_node"):
			seen_nodes[str(effect["mark_seen_node"])] = true

		if effect.has("set_time_of_day"):
			CampaignManager.camp_time_of_day = str(effect["set_time_of_day"]).to_lower()

	state["flags"] = flags
	state["seen_nodes"] = seen_nodes
	state["counters"] = counters
	_commit_seraphina_state(state)


# Function:
#   _mark_node_seen
# Purpose:
#   Marks a node as seen immediately when it is shown.
# Inputs:
#   node_id: String
# Outputs:
#   None.
# Side Effects:
#   Mutates Seraphina's persistent seen-node history.
func _mark_node_seen(node_id: String) -> void:
	var state: Dictionary = _get_seraphina_state_copy()
	var seen_nodes: Dictionary = state.get("seen_nodes", {})
	seen_nodes[node_id] = true
	state["seen_nodes"] = seen_nodes
	_commit_seraphina_state(state)

# ==============================================================================
# PORTRAIT MOOD CONTROL
# ==============================================================================

# Function:
#   _set_mood
# Purpose:
#   Maps a dialogue mood tag to an exported portrait texture and applies it to
#   the visual node.
# Inputs:
#   mood_name: String
# Outputs:
#   None.
# Side Effects:
#   Changes the portrait texture shown in the tavern UI.
func _set_mood(mood_name: String) -> void:
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

	# Never assign a null texture if one was forgotten in the Inspector.
	if target_tex == null:
		push_warning("TavernBartender.gd: target mood texture is null.")
		return

	if visual_node is TextureButton:
		(visual_node as TextureButton).texture_normal = target_tex
		(visual_node as TextureButton).texture_pressed = target_tex
		(visual_node as TextureButton).texture_hover = target_tex
		(visual_node as TextureButton).texture_disabled = target_tex
	elif visual_node is TextureRect:
		(visual_node as TextureRect).texture = target_tex

	if visual_node.size != Vector2.ZERO:
		visual_node.pivot_offset = visual_node.size / 2.0

# Function:
#   _reset_mood
# Purpose:
#   Returns Seraphina's portrait to the neutral default.
# Inputs:
#   None.
# Outputs:
#   None.
# Side Effects:
#   Changes portrait texture.
func _reset_mood() -> void:
	_set_mood("neutral")

# ==============================================================================
# UI HELPERS
# ==============================================================================

# Function:
#   _disconnect_button
# Purpose:
#   Clears prior pressed-signal handlers using the parent UI helper if available.
# Inputs:
#   button: BaseButton
# Outputs:
#   None.
# Side Effects:
#   Disconnects button handlers.
func _disconnect_button(button: BaseButton) -> void:
	if button == null:
		return

	if parent_ui != null and parent_ui.has_method("_disconnect_all_pressed"):
		parent_ui._disconnect_all_pressed(button)


# Function:
#   _show_choice_container
# Purpose:
#   Makes the choice container visible.
# Inputs:
#   None.
# Outputs:
#   None.
# Side Effects:
#   UI visibility change.
func _show_choice_container() -> void:
	if parent_ui == null:
		return
	parent_ui.choice_container.show()


# Function:
#   _hide_choice_container
# Purpose:
#   Hides the choice container and both buttons.
# Inputs:
#   None.
# Outputs:
#   None.
# Side Effects:
#   UI visibility change.
func _hide_choice_container() -> void:
	if parent_ui == null:
		return
	parent_ui.choice_container.hide()
	parent_ui.choice_btn_1.hide()
	parent_ui.choice_btn_2.hide()


# Function:
#   _show_next_button
# Purpose:
#   Makes the next button visible.
# Inputs:
#   None.
# Outputs:
#   None.
# Side Effects:
#   UI visibility change.
func _show_next_button() -> void:
	if parent_ui == null:
		return
	parent_ui.next_btn.show()


# Function:
#   _hide_next_button
# Purpose:
#   Hides the next button.
# Inputs:
#   None.
# Outputs:
#   None.
# Side Effects:
#   UI visibility change.
func _hide_next_button() -> void:
	if parent_ui == null:
		return
	parent_ui.next_btn.hide()


# Function:
#   _close_interaction
# Purpose:
#   Ends the current conversation and hides choice navigation. The main dialogue
#   panel remains under parent UI control.
# Inputs:
#   None.
# Outputs:
#   None.
# Side Effects:
#   Clears current node tracking and hides interaction controls.
func _close_interaction() -> void:
	interaction_active = false
	current_node_id = ""
	current_node_data = {}
	_hide_choice_container()
	_hide_next_button()
	_reset_mood()

# ==============================================================================
# SILENTWOLF NOTICE BOARD
# ==============================================================================

# Function:
#   _fetch_silentwolf_motd
# Purpose:
#   Retrieves the latest notice-board message from SilentWolf and displays it in
#   the tavern dialogue text area.
# Inputs:
#   None.
# Outputs:
#   None.
# Side Effects:
#   Performs an asynchronous network request and updates the dialogue UI.
func _fetch_silentwolf_motd() -> void:
	_hide_choice_container()
	_hide_next_button()
	_set_mood("thinking")

	if parent_ui == null:
		return

	parent_ui.dialogue_panel.show()
	parent_ui.dialogue_text.text = "Seraphina checks the notice board."

	var _sw_result = await SilentWolf.Scores.get_scores(1, "motd").sw_get_scores_complete
	var scores = SilentWolf.Scores.scores

	if not scores.is_empty():
		var message: String = str(scores[0].get("metadata", {}).get("message", "The notice board is blank."))
		parent_ui.dialogue_text.text = message
	else:
		parent_ui.dialogue_text.text = "The roads are quiet tonight."

	_show_next_button()
	_bind_close_after_notice()

# Function:
#   _bind_close_after_notice
# Purpose:
#   Configures the next button to close the interaction after a notice-board
#   message has been shown.
# Inputs:
#   None.
# Outputs:
#   None.
# Side Effects:
#   Rebinds the next button.
func _bind_close_after_notice() -> void:
	_disconnect_button(parent_ui.next_btn)
	parent_ui.next_btn.pressed.connect(_close_interaction, CONNECT_ONE_SHOT)


# Function:
#   _input
# Purpose:
#   Opens the admin MOTD input box when the configured key is pressed.
# Inputs:
#   event: InputEvent
# Outputs:
#   None.
# Side Effects:
#   Spawns a LineEdit overlay for MOTD entry.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_U:
			_show_admin_input()
			return

		# Debug hotkey: force a maxed Seraphina relationship state.
		if event.keycode == KEY_I:
			_debug_max_seraphina_relationship()
			return


# Function:
#   _show_admin_input
# Purpose:
#   Creates a temporary admin text field for MOTD submission.
# Inputs:
#   None.
# Outputs:
#   None.
# Side Effects:
#   Adds a child LineEdit to the parent UI.
func _show_admin_input() -> void:
	if admin_input_box != null:
		return

	admin_input_box = LineEdit.new()
	admin_input_box.placeholder_text = "Type MOTD and press Enter."
	admin_input_box.alignment = HORIZONTAL_ALIGNMENT_CENTER
	admin_input_box.custom_minimum_size = Vector2(800, 60)

	parent_ui.add_child(admin_input_box)
	admin_input_box.set_anchors_preset(Control.PRESET_CENTER)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.95)
	style.set_border_width_all(3)
	style.border_color = Color.CYAN
	style.set_content_margin_all(10)

	admin_input_box.add_theme_stylebox_override("normal", style)
	admin_input_box.add_theme_font_size_override("font_size", 24)
	admin_input_box.grab_focus()
	admin_input_box.text_submitted.connect(_on_motd_submitted, CONNECT_ONE_SHOT)


# Function:
#   _on_motd_submitted
# Purpose:
#   Pushes a new MOTD to SilentWolf using a timestamp-based score for overwrite
#   ordering.
# Inputs:
#   new_text: String
# Outputs:
#   None.
# Side Effects:
#   Performs an asynchronous network write and shows a system message.
func _on_motd_submitted(new_text: String) -> void:
	if new_text.strip_edges() != "":
		var fresh_score: int = int(Time.get_unix_time_from_system())
		await SilentWolf.Scores.save_score("SYSTEM", fresh_score, "motd", {"message": new_text}).sw_save_score_complete

		if parent_ui.has_method("_show_system_message"):
			parent_ui._show_system_message("Notice board updated.", Color.GREEN)

	_cleanup_admin_input()


# Function:
#   _cleanup_admin_input
# Purpose:
#   Removes the temporary MOTD input field.
# Inputs:
#   None.
# Outputs:
#   None.
# Side Effects:
#   Frees the LineEdit node.
func _cleanup_admin_input() -> void:
	if admin_input_box != null:
		admin_input_box.queue_free()
		admin_input_box = null

# ==============================================================================
# SYSTEM MESSAGING
# ==============================================================================

# Function:
#   _show_rank_update_notification
# Purpose:
#   Displays a system-level relationship progression message when Seraphina's
#   legacy compatibility rank changes.
# Inputs:
#   previous_rank: int
#   new_rank: int
# Outputs:
#   None.
# Side Effects:
#   Shows a parent UI system message if supported.
func _show_rank_update_notification(previous_rank: int, new_rank: int) -> void:
	if not parent_ui.has_method("_show_system_message"):
		return

	var rank_names := ["Stranger", "Regular", "Confidant", "Partner"]
	var safe_rank: int = clampi(new_rank, 0, rank_names.size() - 1)
	parent_ui._show_system_message("Relationship status updated: " + rank_names[safe_rank], Color.GOLD)

# Function:
#   _debug_print_seraphina_state
# Purpose:
#   Prints Seraphina's full persisted relationship state for debugging.
# Inputs:
#   None.
# Outputs:
#   None.
# Side Effects:
#   Writes a formatted dump to the Godot Output panel and optionally shows a
#   short system message in the tavern UI.
func _debug_print_seraphina_state() -> void:
	_ensure_campaign_state()

	var state: Dictionary = _get_seraphina_state_copy()
	var flags: Dictionary = state.get("flags", {})
	var seen_nodes: Dictionary = state.get("seen_nodes", {})
	var counters: Dictionary = state.get("counters", {})

	var report := ""
	report += "\n================ SERAPHINA DEBUG ================\n"
	report += "Affection: %d\n" % int(state.get("affection", 0))
	report += "Trust: %d\n" % int(state.get("trust", 0))
	report += "Professionalism: %d\n" % int(state.get("professionalism", 0))
	report += "Legacy Rank Cache: %d\n" % int(CampaignManager.seraphina_romance_rank)
	report += "Current Level Index: %d\n" % int(CampaignManager.current_level_index)
	report += "Time Of Day: %s\n" % str(CampaignManager.get("camp_time_of_day"))
	report += "\nFlags:\n"

	for key in flags.keys():
		report += "  - %s: %s\n" % [str(key), str(flags[key])]

	report += "\nCounters:\n"
	for key in counters.keys():
		report += "  - %s: %s\n" % [str(key), str(counters[key])]

	report += "\nSeen Nodes:\n"
	if seen_nodes.is_empty():
		report += "  - none\n"
	else:
		for key in seen_nodes.keys():
			report += "  - %s: %s\n" % [str(key), str(seen_nodes[key])]

	report += "=================================================\n"

	print(report)

	if parent_ui != null and parent_ui.has_method("_show_system_message"):
		parent_ui._show_system_message("Seraphina debug state printed to Output.", Color.CYAN)

# Function:
#   _debug_max_seraphina_relationship
# Purpose:
#   Debug helper that forcefully sets Seraphina's relationship state to a
#   near-maximum configuration so late branches can be tested immediately.
# Inputs:
#   None.
# Outputs:
#   None.
# Side Effects:
#   - Overwrites Seraphina relationship stats
#   - Sets important progression flags
#   - Sets counters high enough for advanced routing
#   - Forces campaign conditions useful for testing late scenes
#   - Syncs legacy cache and saves progress
func _debug_max_seraphina_relationship() -> void:
	_ensure_campaign_state()

	var state: Dictionary = _get_seraphina_state_copy()

	# Max all three hidden stats.
	state["affection"] = 100
	state["trust"] = 100
	state["professionalism"] = 100

	# Ensure nested containers exist.
	if not state.has("flags") or typeof(state["flags"]) != TYPE_DICTIONARY:
		state["flags"] = {}
	if not state.has("seen_nodes") or typeof(state["seen_nodes"]) != TYPE_DICTIONARY:
		state["seen_nodes"] = {}
	if not state.has("counters") or typeof(state["counters"]) != TYPE_DICTIONARY:
		state["counters"] = {}

	var flags: Dictionary = state["flags"]
	var seen_nodes: Dictionary = state["seen_nodes"]
	var counters: Dictionary = state["counters"]

	# Core progression flags.
	flags["met_seraphina"] = true
	flags["met_this_visit"] = false
	flags["asked_about_scar"] = true
	flags["drank_the_special"] = true
	flags["discussed_special_aftertaste"] = true
	flags["after_hours_talk"] = false

	# Enough history to unlock deeper branches.
	counters["times_spoken"] = 10

	# Mark useful nodes as already seen.
	seen_nodes["first_meeting"] = true
	seen_nodes["first_meeting_soft"] = true
	seen_nodes["default_root"] = true
	seen_nodes["talk_hub_one"] = true
	seen_nodes["talk_hub_two"] = true
	seen_nodes["door_reason"] = true
	seen_nodes["scar_answer"] = true
	seen_nodes["special_offer"] = true
	seen_nodes["drink_special_response"] = true

	state["flags"] = flags
	state["seen_nodes"] = seen_nodes
	state["counters"] = counters

	# Force campaign conditions for late-scene testing.
	CampaignManager.current_level_index = max(CampaignManager.current_level_index, 2)
	CampaignManager.max_unlocked_index = max(CampaignManager.max_unlocked_index, 2)
	CampaignManager.camp_time_of_day = "night"

	_commit_seraphina_state(state)

	print("")
	print("================ SERAPHINA MAX DEBUG APPLIED ================")
	print("Affection: ", state["affection"])
	print("Trust: ", state["trust"])
	print("Professionalism: ", state["professionalism"])
	print("Legacy Rank Cache: ", CampaignManager.seraphina_romance_rank)
	print("Current Level Index: ", CampaignManager.current_level_index)
	print("Time Of Day: ", CampaignManager.camp_time_of_day)
	print("")
	print("Flags:")
	for key in flags.keys():
		print("  - ", key, ": ", flags[key])
	print("")
	print("Counters:")
	for key in counters.keys():
		print("  - ", key, ": ", counters[key])
	print("")
	print("Seen Nodes:")
	for key in seen_nodes.keys():
		print("  - ", key, ": ", seen_nodes[key])
	print("============================================================")
	print("")
