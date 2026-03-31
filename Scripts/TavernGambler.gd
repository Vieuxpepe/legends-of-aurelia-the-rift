extends Node

@export var gambler_name: String = "Velka the Gambler"
@export var gambler_button: BaseButton

@export var max_plays_per_progress_level: int = 2
@export var safe_buy_in_gold: int = 12
@export var high_buy_in_gold: int = 30
@export var safe_win_chance: float = 0.62
@export var high_win_chance: float = 0.34
@export var safe_favor_gain: int = 1
@export var high_favor_gain: int = 3
@export var safe_chip_gain: int = 1
@export var high_chip_gain: int = 2
@export var safe_favor_loss: int = 1
@export var high_favor_loss: int = 2
@export var chips_per_title_unlock: int = 5

const GAMBLER_STATE_KEY: String = "tavern_gambler"
const TITLE_UNLOCKS: PackedStringArray = PackedStringArray([
	"House Familiar",
	"Luck-Touched",
	"High Roller"
])

var parent_ui: Control = null
var interaction_active: bool = false

func _ready() -> void:
	parent_ui = get_parent() as Control
	if gambler_button != null and not gambler_button.pressed.is_connected(interact):
		gambler_button.pressed.connect(interact)


func interact() -> void:
	if parent_ui == null:
		return
	interaction_active = true
	_show_table("")


func _get_progress_token() -> int:
	if CampaignManager == null:
		return 0
	if CampaignManager.has_method("get"):
		return int(CampaignManager.get("camp_request_progress_level"))
	return int(CampaignManager.camp_request_progress_level)


func _default_state(token: int) -> Dictionary:
	return {
		"favor": 0,
		"chips": 0,
		"streak": 0,
		"best_streak": 0,
		"plays_used": 0,
		"last_refresh_token": token,
		"titles": []
	}


func _read_state() -> Dictionary:
	var token: int = _get_progress_token()
	if CampaignManager == null:
		return _default_state(token)
	if not CampaignManager.npc_relationships is Dictionary:
		CampaignManager.npc_relationships = {}

	var raw_state: Variant = CampaignManager.npc_relationships.get(GAMBLER_STATE_KEY, {})
	var state: Dictionary = {}
	if raw_state is Dictionary:
		state = (raw_state as Dictionary).duplicate(true)

	if state.is_empty():
		state = _default_state(token)

	state["favor"] = int(state.get("favor", 0))
	state["chips"] = int(state.get("chips", 0))
	state["streak"] = int(state.get("streak", 0))
	state["best_streak"] = int(state.get("best_streak", 0))
	state["plays_used"] = int(state.get("plays_used", 0))
	state["last_refresh_token"] = int(state.get("last_refresh_token", token))

	if int(state["last_refresh_token"]) != token:
		state["last_refresh_token"] = token
		state["plays_used"] = 0
		state["streak"] = 0

	var normalized_titles: Array[String] = []
	var raw_titles: Variant = state.get("titles", [])
	if raw_titles is Array:
		for title_v in raw_titles:
			var title: String = str(title_v).strip_edges()
			if title != "" and not normalized_titles.has(title):
				normalized_titles.append(title)
	state["titles"] = normalized_titles

	return state


func _write_state(state: Dictionary, save_now: bool = true) -> void:
	if CampaignManager == null:
		return
	if not CampaignManager.npc_relationships is Dictionary:
		CampaignManager.npc_relationships = {}
	CampaignManager.npc_relationships[GAMBLER_STATE_KEY] = state.duplicate(true)
	if save_now and CampaignManager.has_method("save_current_progress"):
		CampaignManager.save_current_progress()


func _plays_left(state: Dictionary) -> int:
	var max_plays: int = maxi(0, max_plays_per_progress_level)
	var used: int = maxi(0, int(state.get("plays_used", 0)))
	return maxi(0, max_plays - used)


func _format_titles(state: Dictionary) -> String:
	var raw_titles: Variant = state.get("titles", [])
	if not raw_titles is Array or (raw_titles as Array).is_empty():
		return "None yet"
	var titles: Array[String] = []
	for title_v in (raw_titles as Array):
		var title: String = str(title_v).strip_edges()
		if title != "":
			titles.append(title)
	return ", ".join(titles)


func _next_unlockable_title(state: Dictionary) -> String:
	var owned_titles: Array[String] = []
	var raw_titles: Variant = state.get("titles", [])
	if raw_titles is Array:
		for title_v in (raw_titles as Array):
			var title: String = str(title_v).strip_edges()
			if title != "":
				owned_titles.append(title)
	for title in TITLE_UNLOCKS:
		if not owned_titles.has(title):
			return title
	return ""


func _show_table(status_line: String) -> void:
	if parent_ui == null:
		return
	var state: Dictionary = _read_state()
	var plays_left: int = _plays_left(state)
	var favor: int = int(state.get("favor", 0))
	var chips: int = int(state.get("chips", 0))
	var streak: int = int(state.get("streak", 0))
	var best_streak: int = int(state.get("best_streak", 0))
	var titles_text: String = _format_titles(state)

	parent_ui.dialogue_panel.show()
	parent_ui.choice_container.show()
	parent_ui.next_btn.hide()
	parent_ui.active_character_a = {"unit_name": gambler_name}
	parent_ui.active_character_b = {}
	if parent_ui.has_node("DialoguePanel/SpeakerName"):
		parent_ui.speaker_name.text = gambler_name

	var status_text: String = ""
	if status_line.strip_edges() != "":
		status_text = "\n\n" + status_line.strip_edges()

	parent_ui.dialogue_text.text = (
		"\"Cards, bones, and bad decisions. Pull up a chair.\"\n\n"
		+ "House Rule: this table never pays out gold.\n"
		+ "You spend gold for non-tradeable Favor and Lucky Chips only.\n\n"
		+ "Plays left this chapter: %d / %d\n"
		+ "Favor: %d | Chips: %d | Streak: %d (Best %d)\n"
		+ "Unlocked Titles: %s%s"
	) % [
		plays_left,
		maxi(0, max_plays_per_progress_level),
		favor,
		chips,
		streak,
		best_streak,
		titles_text,
		status_text
	]

	_bind_button(parent_ui.choice_btn_1, "Safe Hand (%dG)" % maxi(1, safe_buy_in_gold), _play_safe_hand)
	_bind_button(parent_ui.choice_btn_2, "High Roll (%dG)" % maxi(1, high_buy_in_gold), _play_high_roll)
	_bind_button(parent_ui.choice_btn_3, "Cash Chips (%d)" % maxi(1, chips_per_title_unlock), _cash_in_chips_for_title)
	_bind_button(parent_ui.choice_btn_4, "Leave", _close_interaction)

	var out_of_plays: bool = plays_left <= 0
	if out_of_plays:
		parent_ui.choice_btn_1.disabled = true
		parent_ui.choice_btn_2.disabled = true
		parent_ui.choice_btn_1.text = "No Plays Left"
		parent_ui.choice_btn_2.text = "No Plays Left"
	else:
		parent_ui.choice_btn_1.disabled = false
		parent_ui.choice_btn_2.disabled = false


func _play_safe_hand() -> void:
	_resolve_wager(
		maxi(1, safe_buy_in_gold),
		clampf(safe_win_chance, 0.01, 0.99),
		safe_favor_gain,
		safe_chip_gain,
		safe_favor_loss,
		"Safe Hand"
	)


func _play_high_roll() -> void:
	_resolve_wager(
		maxi(1, high_buy_in_gold),
		clampf(high_win_chance, 0.01, 0.99),
		high_favor_gain,
		high_chip_gain,
		high_favor_loss,
		"High Roll"
	)


func _resolve_wager(
	buy_in_gold: int,
	win_chance: float,
	favor_gain: int,
	chip_gain: int,
	favor_loss: int,
	label: String
) -> void:
	var state: Dictionary = _read_state()
	if _plays_left(state) <= 0:
		_show_table("The house closes your tab until the next chapter.")
		return
	if CampaignManager == null:
		_show_table("No campaign context available.")
		return
	if int(CampaignManager.global_gold) < buy_in_gold:
		_show_table("Not enough gold for %s." % label)
		return

	CampaignManager.global_gold = int(CampaignManager.global_gold) - buy_in_gold
	state["plays_used"] = int(state.get("plays_used", 0)) + 1

	var won: bool = randf() < win_chance
	var result_line: String = ""
	if won:
		state["favor"] = int(state.get("favor", 0)) + maxi(0, favor_gain)
		state["chips"] = int(state.get("chips", 0)) + maxi(0, chip_gain)
		state["streak"] = int(state.get("streak", 0)) + 1
		state["best_streak"] = maxi(int(state.get("best_streak", 0)), int(state.get("streak", 0)))
		result_line = "%s won. +%d Favor, +%d Chips." % [label, maxi(0, favor_gain), maxi(0, chip_gain)]
	else:
		state["favor"] = int(state.get("favor", 0)) - maxi(0, favor_loss)
		state["streak"] = 0
		result_line = "%s lost. The house keeps your gold." % label

	state["favor"] = clampi(int(state.get("favor", 0)), -99, 999)
	state["chips"] = clampi(int(state.get("chips", 0)), 0, 999)
	state["plays_used"] = clampi(int(state.get("plays_used", 0)), 0, 999)

	_write_state(state, true)
	_show_table(result_line)


func _cash_in_chips_for_title() -> void:
	var state: Dictionary = _read_state()
	var chip_cost: int = maxi(1, chips_per_title_unlock)
	var chips: int = int(state.get("chips", 0))
	if chips < chip_cost:
		_show_table("You need %d chips to cash in." % chip_cost)
		return

	var next_title: String = _next_unlockable_title(state)
	if next_title == "":
		_show_table("No more titles to unlock. Keep your chips.")
		return

	state["chips"] = chips - chip_cost
	var titles: Array[String] = []
	var raw_titles: Variant = state.get("titles", [])
	if raw_titles is Array:
		for title_v in (raw_titles as Array):
			var title: String = str(title_v).strip_edges()
			if title != "":
				titles.append(title)
	if not titles.has(next_title):
		titles.append(next_title)
	state["titles"] = titles

	_write_state(state, true)
	_show_table("Unlocked title: %s" % next_title)


func _bind_button(button: BaseButton, label: String, callable: Callable) -> void:
	if button == null:
		return
	_disconnect_button(button)
	button.text = label
	button.disabled = false
	button.show()
	button.pressed.connect(callable, CONNECT_ONE_SHOT)


func _disconnect_button(button: BaseButton) -> void:
	if button == null:
		return
	if parent_ui != null and parent_ui.has_method("_disconnect_all_pressed"):
		parent_ui._disconnect_all_pressed(button)


func _close_interaction() -> void:
	interaction_active = false
	if parent_ui == null:
		return
	parent_ui.choice_container.hide()
	parent_ui.choice_btn_1.hide()
	parent_ui.choice_btn_2.hide()
	parent_ui.choice_btn_3.hide()
	parent_ui.choice_btn_4.hide()
	parent_ui.dialogue_panel.hide()
