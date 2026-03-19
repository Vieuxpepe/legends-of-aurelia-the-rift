# ==============================================================================
# Script Name: SeraphinaDialogueDatabase.gd
# Purpose:
#   Stores Seraphina's full dialogue content and routing rules as plain data.
#
# Overall Goal:
#   Keep narrative content, branching requirements, and state mutations out of
#   the runtime manager so writers and designers can extend the conversation
#   system without rewriting control flow code.
#
# Project Role:
#   This script is consumed by SeraphinaDialogueManager.gd. It returns:
#     - A default persistent relationship state
#     - Entry routing rules
#     - Node definitions containing lines, conditions, and choice effects
#
# Dependencies:
#   No scene dependency. Returns plain Dictionary data only.
#
# AI / Reviewer Notes:
#   - Entry point: get_database()
#   - Configuration area: _build_entry_rules(), _build_nodes()
#   - Persistence shape: get_default_state()
#   - Extension point: add rules or nodes here without changing the manager
# ==============================================================================

extends RefCounted
class_name SeraphinaDialogueDatabase


# ------------------------------------------------------------------------------
# Function: get_default_state
# Purpose:
#   Returns the persistent default relationship state for Seraphina.
#
# Inputs:
#   None.
#
# Outputs:
#   Dictionary containing stats, flags, seen nodes, and counters.
#
# Side Effects:
#   None.
# ------------------------------------------------------------------------------
static func get_default_state() -> Dictionary:
	return {
		"affection": 0,
		"trust": 0,
		"professionalism": 0,
		"flags": {
			"met_seraphina": false,
			"met_this_visit": false,
			"asked_about_scar": false,
			"drank_the_special": false,
			"discussed_special_aftertaste": false,
			"after_hours_talk": false
		},
		"seen_nodes": {},
		"counters": {
			"times_spoken": 0
		}
	}


# ------------------------------------------------------------------------------
# Function: get_database
# Purpose:
#   Returns the full database consumed by the runtime dialogue manager.
#
# Inputs:
#   None.
#
# Outputs:
#   Dictionary with:
#     - entry_rules: ordered routing rules
#     - nodes: all dialogue nodes by id
#
# Side Effects:
#   None.
# ------------------------------------------------------------------------------
static func get_database() -> Dictionary:
	return {
		"entry_rules": _build_entry_rules(),
		"nodes": _build_nodes()
	}


# ------------------------------------------------------------------------------
# Function: _build_entry_rules
# Purpose:
#   Defines how the manager selects the first node when the player interacts
#   with Seraphina.
#
# Inputs:
#   None.
#
# Outputs:
#   Array of Dictionaries sorted by priority. Higher priority resolves first.
#
# Side Effects:
#   None.
#
# Notes:
#   These rules are intentionally declarative. The manager evaluates them
#   generically using the condition engine.
# ------------------------------------------------------------------------------
static func _build_entry_rules() -> Array:
	return [
		{
			"id": "repeat_visit",
			"priority": 100,
			"node_id": "entry_repeat_visit",
			"conditions": {
				"all": [
					{"type": "flag_true", "key": "met_this_visit"}
				]
			}
		},
		{
			"id": "closing_time_scene",
			"priority": 95,
			"node_id": "entry_closing_time",
			"conditions": {
				"all": [
					{"type": "flag_false", "key": "met_this_visit"},
					{"type": "flag_false", "key": "after_hours_talk"},
					{"type": "stat_gte", "key": "affection", "value": 35},
					{"type": "stat_gte", "key": "trust", "value": 30},
					{"type": "stat_gte", "key": "professionalism", "value": 20},
					{"type": "time_is", "value": "night"},
					{"type": "level_gte", "value": 2}
				]
			}
		},
		{
			"id": "special_followup",
			"priority": 90,
			"node_id": "entry_special_followup",
			"conditions": {
				"all": [
					{"type": "flag_false", "key": "met_this_visit"},
					{"type": "flag_true", "key": "drank_the_special"},
					{"type": "flag_false", "key": "discussed_special_aftertaste"},
					{"type": "level_gte", "value": 1}
				]
			}
		},
		{
			"id": "scar_followup",
			"priority": 80,
			"node_id": "entry_scar_followup",
			"conditions": {
				"all": [
					{"type": "flag_false", "key": "met_this_visit"},
					{"type": "flag_false", "key": "asked_about_scar"},
					{"type": "stat_gte", "key": "trust", "value": 45},
					{"type": "level_gte", "value": 1},
					{
						"any": [
							{"type": "time_is", "value": "evening"},
							{"type": "time_is", "value": "night"}
						]
					}
				]
			}
		},
		{
			"id": "professional_regular",
			"priority": 40,
			"node_id": "entry_professional_regular",
			"conditions": {
				"all": [
					{"type": "flag_false", "key": "met_this_visit"},
					{"type": "stat_gte", "key": "professionalism", "value": 25}
				]
			}
		},
		{
			"id": "warm_regular",
			"priority": 30,
			"node_id": "entry_warm_regular",
			"conditions": {
				"all": [
					{"type": "flag_false", "key": "met_this_visit"},
					{
						"any": [
							{"type": "stat_gte", "key": "affection", "value": 15},
							{"type": "stat_gte", "key": "trust", "value": 15}
						]
					}
				]
			}
		},
		{
			"id": "cold_regular",
			"priority": 10,
			"node_id": "entry_cold_regular",
			"conditions": {
				"all": [
					{"type": "flag_false", "key": "met_this_visit"},
					{"type": "flag_true", "key": "met_seraphina"}
				]
			}
		},
		{
			"id": "first_meeting",
			"priority": 0,
			"node_id": "entry_first_meeting",
			"conditions": {}
		}
	]


# ------------------------------------------------------------------------------
# Function: _build_nodes
# Purpose:
#   Defines all dialogue nodes and choice outcomes for Seraphina.
#
# Inputs:
#   None.
#
# Outputs:
#   Dictionary keyed by node id.
#
# Side Effects:
#   None.
#
# Notes:
#   Every node can contain:
#     - on_enter_effects
#     - lines
#     - choices
#     - auto_next
#
#   The manager interprets these generically.
# ------------------------------------------------------------------------------
static func _build_nodes() -> Dictionary:
	return {
		# ----------------------------------------------------------------------
		# Entry nodes
		# ----------------------------------------------------------------------
		"entry_first_meeting": {
			"on_enter_effects": [
				{"type": "set_flag", "key": "met_seraphina", "value": true},
				{"type": "set_flag", "key": "met_this_visit", "value": true},
				{"type": "add_counter", "key": "times_spoken", "value": 1}
			],
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "neutral",
					"text": "Welcome to the Grand Tavern. If you want noise, sit near the stage. If you want a straight answer, sit here."
				}
			],
			"choices": [
				{
					"text": "Pour something that keeps the dust out of my throat.",
					"next": "topic_house_special",
					"effects": [
						{"type": "add_stat", "key": "professionalism", "value": 2},
						{"type": "add_stat", "key": "trust", "value": 1}
					]
				},
				{
					"text": "You hear things before the guard does. What changed today.",
					"next": "topic_rumors",
					"effects": [
						{"type": "add_stat", "key": "trust", "value": 2},
						{"type": "add_stat", "key": "professionalism", "value": 1}
					]
				},
				{
					"text": "You always greet strangers like a drawn blade.",
					"next": "result_first_meeting_edge",
					"effects": [
						{"type": "add_stat", "key": "affection", "value": 1},
						{"type": "add_stat", "key": "trust", "value": 1}
					]
				}
			]
		},

		"entry_cold_regular": {
			"on_enter_effects": [
				{"type": "set_flag", "key": "met_this_visit", "value": true},
				{"type": "add_counter", "key": "times_spoken", "value": 1}
			],
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "neutral",
					"text": "You are back. That either means the city was kinder than expected or you enjoy bad seating."
				}
			],
			"choices": [
				{
					"text": "Same seat. Better drink.",
					"next": "topic_house_special",
					"effects": [
						{"type": "add_stat", "key": "professionalism", "value": 2},
						{"type": "add_stat", "key": "affection", "value": 1}
					]
				},
				{
					"text": "Start with the part people are lying about.",
					"next": "topic_rumors",
					"effects": [
						{"type": "add_stat", "key": "trust", "value": 2}
					]
				},
				{
					"text": "Rough day, or is this the standard welcome for repeat customers.",
					"next": "result_cold_regular_probe",
					"effects": [
						{"type": "add_stat", "key": "affection", "value": 1},
						{"type": "add_stat", "key": "trust", "value": 1}
					]
				}
			]
		},

		"entry_warm_regular": {
			"on_enter_effects": [
				{"type": "set_flag", "key": "met_this_visit", "value": true},
				{"type": "add_counter", "key": "times_spoken", "value": 1}
			],
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "smiling",
					"text": "You made it back. Sit down before somebody mistakes you for decoration."
				}
			],
			"choices": [
				{
					"text": "How are you holding up.",
					"next": "topic_personal_check_in",
					"effects": [
						{"type": "add_stat", "key": "affection", "value": 3},
						{"type": "add_stat", "key": "trust", "value": 2}
					]
				},
				{
					"text": "Same drink as last time.",
					"next": "topic_house_special",
					"effects": [
						{"type": "add_stat", "key": "professionalism", "value": 2},
						{"type": "add_stat", "key": "affection", "value": 1}
					]
				},
				{
					"text": "I would hate to disappoint the furniture. What did I miss.",
					"next": "topic_rumors",
					"effects": [
						{"type": "add_stat", "key": "affection", "value": 2},
						{"type": "add_stat", "key": "trust", "value": 1}
					]
				}
			]
		},

		"entry_professional_regular": {
			"on_enter_effects": [
				{"type": "set_flag", "key": "met_this_visit", "value": true},
				{"type": "add_counter", "key": "times_spoken", "value": 1}
			],
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "thinking",
					"text": "Ledger is balanced, casks arrived late, and the city is still pretending that passes for stability."
				}
			],
			"choices": [
				{
					"text": "Need someone to lean on the suppliers.",
					"next": "topic_supply_ledger",
					"effects": [
						{"type": "add_stat", "key": "professionalism", "value": 4},
						{"type": "add_stat", "key": "trust", "value": 1}
					]
				},
				{
					"text": "Then pour something honest and tell me what matters.",
					"next": "topic_rumors",
					"effects": [
						{"type": "add_stat", "key": "trust", "value": 2}
					]
				},
				{
					"text": "Which costs you more tonight, coin or patience.",
					"next": "result_professional_triage",
					"effects": [
						{"type": "add_stat", "key": "professionalism", "value": 2},
						{"type": "add_stat", "key": "trust", "value": 2}
					]
				}
			]
		},

		"entry_repeat_visit": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "thinking",
					"text": "You already had my attention once today. Unless the roof is burning, make it brief."
				}
			],
			"choices": []
		},

		"entry_special_followup": {
			"on_enter_effects": [
				{"type": "set_flag", "key": "met_this_visit", "value": true},
				{"type": "add_counter", "key": "times_spoken", "value": 1}
			],
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "smiling",
					"text": "You handled last night's special better than most. I wanted a second opinion once the headache cleared."
				}
			],
			"choices": [
				{
					"text": "It tasted like a wager between a chemist and a smuggler.",
					"next": "result_special_honest",
					"effects": [
						{"type": "set_flag", "key": "discussed_special_aftertaste", "value": true},
						{"type": "add_stat", "key": "trust", "value": 2},
						{"type": "add_stat", "key": "affection", "value": 1}
					]
				},
				{
					"text": "It was memorable.",
					"next": "result_special_polite",
					"effects": [
						{"type": "set_flag", "key": "discussed_special_aftertaste", "value": true},
						{"type": "add_stat", "key": "professionalism", "value": 1}
					]
				},
				{
					"text": "It tasted like you were trying to prove a point. Did it work.",
					"next": "result_special_analytic",
					"effects": [
						{"type": "set_flag", "key": "discussed_special_aftertaste", "value": true},
						{"type": "add_stat", "key": "trust", "value": 2},
						{"type": "add_stat", "key": "professionalism", "value": 2}
					]
				}
			]
		},

		"entry_scar_followup": {
			"on_enter_effects": [
				{"type": "set_flag", "key": "met_this_visit", "value": true},
				{"type": "add_counter", "key": "times_spoken", "value": 1}
			],
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "thinking",
					"text": "You have asked three careful questions and looked at the scar six times. If there is a question, ask it properly."
				}
			],
			"choices": [
				{
					"text": "Only if you want to answer.",
					"next": "result_scar_respectful",
					"effects": [
						{"type": "set_flag", "key": "asked_about_scar", "value": true},
						{"type": "add_stat", "key": "trust", "value": 4},
						{"type": "add_stat", "key": "affection", "value": 2},
						{"type": "add_stat", "key": "professionalism", "value": 1}
					]
				},
				{
					"text": "Whoever gave it to you—did they live long enough to regret it.",
					"next": "result_scar_hardline",
					"effects": [
						{"type": "set_flag", "key": "asked_about_scar", "value": true},
						{"type": "add_stat", "key": "trust", "value": 2},
						{"type": "add_stat", "key": "professionalism", "value": 1}
					]
				},
				{
					"text": "Leave it there. I do not need to know.",
					"next": "result_scar_leave",
					"effects": [
						{"type": "set_flag", "key": "asked_about_scar", "value": true},
						{"type": "add_stat", "key": "trust", "value": 2},
						{"type": "add_stat", "key": "professionalism", "value": 2}
					]
				},
				{
					"text": "I asked because old wounds have a way of choosing their hour.",
					"next": "result_scar_shared_wound",
					"effects": [
						{"type": "set_flag", "key": "asked_about_scar", "value": true},
						{"type": "add_stat", "key": "trust", "value": 3},
						{"type": "add_stat", "key": "affection", "value": 3}
					]
				}
			]
		},

		"entry_closing_time": {
			"on_enter_effects": [
				{"type": "set_flag", "key": "met_this_visit", "value": true},
				{"type": "add_counter", "key": "times_spoken", "value": 1}
			],
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "thinking",
					"text": "Most nights I close alone. Tonight the place is quiet enough to hear bad decisions forming."
				}
			],
			"choices": [
				{
					"text": "Then let me stay until the chairs are up.",
					"next": "result_after_hours_help",
					"effects": [
						{"type": "set_flag", "key": "after_hours_talk", "value": true},
						{"type": "add_stat", "key": "affection", "value": 4},
						{"type": "add_stat", "key": "trust", "value": 3},
						{"type": "add_stat", "key": "professionalism", "value": 2}
					]
				},
				{
					"text": "You need rest more than company. Lock up early.",
					"next": "result_after_hours_distance",
					"effects": [
						{"type": "set_flag", "key": "after_hours_talk", "value": true},
						{"type": "add_stat", "key": "trust", "value": 3},
						{"type": "add_stat", "key": "professionalism", "value": 3}
					]
				},
				{
					"text": "That does not sound like bad decisions. It sounds like loneliness.",
					"next": "result_after_hours_honest",
					"effects": [
						{"type": "set_flag", "key": "after_hours_talk", "value": true},
						{"type": "add_stat", "key": "trust", "value": 4},
						{"type": "add_stat", "key": "affection", "value": 2}
					]
				},
				{
					"text": "Then I should leave before I become one of them.",
					"next": "result_after_hours_deflect",
					"effects": [
						{"type": "set_flag", "key": "after_hours_talk", "value": true},
						{"type": "add_stat", "key": "affection", "value": 2},
						{"type": "add_stat", "key": "professionalism", "value": 1}
					]
				}
			]
		},

		# ----------------------------------------------------------------------
		# Topic nodes
		# ----------------------------------------------------------------------
		"topic_house_special": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "neutral",
					"text": "House special is on the left. The one on the right strips paint. I only serve that to men who ask for discounts."
				}
			],
			"choices": [
				{
					"text": "I will take the left glass.",
					"next": "result_house_special",
					"effects": [
						{"type": "set_flag", "key": "drank_the_special", "value": true},
						{"type": "add_stat", "key": "affection", "value": 1},
						{"type": "add_stat", "key": "trust", "value": 1}
					]
				},
				{
					"text": "What is actually in it.",
					"next": "result_special_recipe",
					"effects": [
						{"type": "add_stat", "key": "professionalism", "value": 3},
						{"type": "add_stat", "key": "trust", "value": 1}
					]
				},
				{
					"text": "Pour the one on the right. It has been that kind of day.",
					"next": "result_house_special_strong",
					"effects": [
						{"type": "add_stat", "key": "trust", "value": 2},
						{"type": "add_stat", "key": "affection", "value": 1}
					]
				}
			]
		},

		"topic_rumors": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "neutral",
					"text": "Rumors are cheaper before midnight and less accurate after it. Choose which flaw you prefer."
				}
			],
			"choices": [
				{
					"text": "Harbor first.",
					"next": "result_rumor_harbor",
					"effects": [
						{"type": "add_stat", "key": "trust", "value": 1},
						{"type": "add_stat", "key": "professionalism", "value": 2}
					]
				},
				{
					"text": "Tell me what the couriers are not saying.",
					"next": "result_rumor_couriers",
					"effects": [
						{"type": "add_stat", "key": "trust", "value": 3}
					]
				},
				{
					"text": "Which rumor do you believe least.",
					"next": "result_rumor_skeptical",
					"effects": [
						{"type": "add_stat", "key": "trust", "value": 2},
						{"type": "add_stat", "key": "professionalism", "value": 1}
					]
				},
				{
					"text": "Which rumor gets people killed if ignored.",
					"next": "result_rumor_danger",
					"effects": [
						{"type": "add_stat", "key": "trust", "value": 2},
						{"type": "add_stat", "key": "professionalism", "value": 2}
					]
				}
			]
		},

		"topic_personal_check_in": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "thinking",
					"text": "I sleep when the keg room stops rattling and eat when the kitchen remembers I exist."
				}
			],
			"choices": [
				{
					"text": "That sounds unsustainable.",
					"next": "result_personal_concern",
					"effects": [
						{"type": "add_stat", "key": "trust", "value": 2},
						{"type": "add_stat", "key": "affection", "value": 2}
					]
				},
				{
					"text": "You say that like it does not bother you.",
					"next": "result_personal_mask",
					"effects": [
						{"type": "add_stat", "key": "trust", "value": 3}
					]
				},
				{
					"text": "Say the word and I can take something off your hands.",
					"next": "result_personal_offer",
					"effects": [
						{"type": "add_stat", "key": "professionalism", "value": 2},
						{"type": "add_stat", "key": "affection", "value": 2},
						{"type": "add_stat", "key": "trust", "value": 1}
					]
				},
				{
					"text": "That is the grimmest description of supper I have heard all week.",
					"next": "result_personal_dry_humor",
					"effects": [
						{"type": "add_stat", "key": "affection", "value": 2},
						{"type": "add_stat", "key": "trust", "value": 1}
					]
				}
			]
		},

		"topic_supply_ledger": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "thinking",
					"text": "Suppliers raise prices every time the road gets bloody. They call it scarcity. I call it theater."
				}
			],
			"choices": [
				{
					"text": "I can make sure the next cart arrives unbothered.",
					"next": "result_supply_protection",
					"effects": [
						{"type": "add_stat", "key": "professionalism", "value": 3},
						{"type": "add_stat", "key": "trust", "value": 2}
					]
				},
				{
					"text": "Then raise your prices before they do.",
					"next": "result_supply_pricing",
					"effects": [
						{"type": "add_stat", "key": "professionalism", "value": 4}
					]
				},
				{
					"text": "Name the worst offender. I would rather bargain with the man than his excuses.",
					"next": "result_supply_pressure",
					"effects": [
						{"type": "add_stat", "key": "professionalism", "value": 2},
						{"type": "add_stat", "key": "trust", "value": 2}
					]
				}
			]
		},

		# ----------------------------------------------------------------------
		# Result nodes
		# ----------------------------------------------------------------------
		"result_first_meeting_edge": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "smiling",
					"text": "Only the ones who look like they count exits before they count cups. Sit down. You can have honesty or comfort, but I am fresh out of both at once."
				}
			],
			"choices": []
		},

		"result_cold_regular_probe": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "thinking",
					"text": "Standard welcome. Rough days cost extra."
				},
				{
					"speaker": "Seraphina",
					"portrait": "smiling",
					"text": "You are still here, so either I am improving or your judgment is not."
				}
			],
			"choices": []
		},

		"result_professional_triage": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "thinking",
					"text": "Patience. Coin can be counted. Patience has a way of bleeding out while everyone insists the wound is minor."
				}
			],
			"choices": []
		},

		"result_house_special": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "smiling",
					"text": "Good. It means you plan to remember the conversation."
				}
			],
			"choices": []
		},

		"result_house_special_strong": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "smiling",
					"text": "No. You can have a generous pour of the left and the illusion of self-destruction. I do not waste the right glass on people I might need conscious."
				}
			],
			"choices": []
		},

		"result_special_recipe": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "thinking",
					"text": "Juniper, burnt orange, and a small amount of restraint. The restraint is the expensive part."
				}
			],
			"choices": []
		},

		"result_rumor_harbor": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "neutral",
					"text": "Three ships unloaded with half their manifests missing. Somebody is paying for silence in clean coin."
				}
			],
			"choices": []
		},

		"result_rumor_couriers": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "neutral",
					"text": "Couriers keep changing routes. That usually means somebody started reading their messages."
				}
			],
			"choices": []
		},

		"result_rumor_skeptical": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "thinking",
					"text": "The one about peace. Whenever merchants start using that word, somebody richer is preparing for war."
				}
			],
			"choices": []
		},

		"result_rumor_danger": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "neutral",
					"text": "Missing lamp oil in the lower ward. Not glamorous enough for gossip, which is exactly why it matters. Someone is stockpiling for a night they do not intend to survive politely."
				}
			],
			"choices": []
		},

		"result_personal_concern": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "smiling",
					"text": "It is. Still, concern is rarer than coin. I notice both."
				}
			],
			"choices": []
		},

		"result_personal_mask": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "thinking",
					"text": "Of course it bothers me. I just prefer choosing when people can see it."
				}
			],
			"choices": []
		},

		"result_personal_offer": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "smiling",
					"text": "Careful. Useful offers are how I start depending on people."
				},
				{
					"speaker": "Seraphina",
					"portrait": "thinking",
					"text": "Still... if the cellar starts another argument with gravity, I may remember you said that."
				}
			],
			"choices": []
		},

		"result_personal_dry_humor": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "smiling",
					"text": "That is because you have not heard the breakfast version. It is worse."
				}
			],
			"choices": []
		},

		"result_supply_protection": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "smiling",
					"text": "Useful, direct, and probably illegal. You are learning the district."
				}
			],
			"choices": []
		},

		"result_supply_pricing": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "thinking",
					"text": "Practical. Customers forgive prices faster than empty shelves."
				}
			],
			"choices": []
		},

		"result_supply_pressure": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "neutral",
					"text": "There is a man on Lantern Street who mistakes a polished ring for leverage. If you speak to him, do it gently enough that he keeps talking and firmly enough that he remembers why."
				}
			],
			"choices": []
		},

		"result_special_honest": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "smiling",
					"text": "Good. I was aiming for controlled damage. That means the balance was close."
				}
			],
			"choices": []
		},

		"result_special_polite": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "thinking",
					"text": "That is the kind answer. It is also not an answer."
				}
			],
			"choices": []
		},

		"result_special_analytic": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "thinking",
					"text": "It did. Half the city drinks to forget. I wanted something that forced a person to notice what they were carrying before it settled in their bones."
				}
			],
			"choices": []
		},

		"result_scar_respectful": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "thinking",
					"text": "Dockside debt collector. Years ago. I misread the room and he misread my reach."
				},
				{
					"speaker": "Seraphina",
					"portrait": "neutral",
					"text": "You asked correctly. That matters more than the question."
				}
			],
			"choices": []
		},

		"result_scar_hardline": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "neutral",
					"text": "Long enough."
				},
				{
					"speaker": "Seraphina",
					"portrait": "thinking",
					"text": "People think that is a cruel question. It is not. Surviving something means wanting the measure taken properly."
				}
			],
			"choices": []
		},

		"result_scar_leave": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "neutral",
					"text": "A rare instinct. Most people push harder when they notice old damage."
				}
			],
			"choices": []
		},

		"result_scar_shared_wound": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "thinking",
					"text": "There it is. An honest reason."
				},
				{
					"speaker": "Seraphina",
					"portrait": "neutral",
					"text": "Dockside debt collector. Years ago. The scar stayed longer than his reputation did."
				},
				{
					"speaker": "Seraphina",
					"portrait": "smiling",
					"text": "Old wounds do choose their hour. Best we can do is decide whether they speak for us."
				}
			],
			"choices": []
		},

		"result_after_hours_help": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "blushing",
					"text": "Stack the last two chairs. Then sit. Five minutes of quiet is easier when it is shared."
				}
			],
			"choices": []
		},

		"result_after_hours_distance": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "smiling",
					"text": "Responsible. I respect that more than you probably intended."
				}
			],
			"choices": []
		},

		"result_after_hours_honest": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "thinking",
					"text": "You say that as though naming it makes it smaller."
				},
				{
					"speaker": "Seraphina",
					"portrait": "smiling",
					"text": "Still... it is easier to argue with loneliness when someone else has already caught it in the room."
				}
			],
			"choices": []
		},

		"result_after_hours_deflect": {
			"lines": [
				{
					"speaker": "Seraphina",
					"portrait": "smiling",
					"text": "Too late. You are at least a minor one."
				},
				{
					"speaker": "Seraphina",
					"portrait": "neutral",
					"text": "Stay for one minute, then. I will call it poor judgment and keep my pride intact."
				}
			],
			"choices": []
		}
	}
