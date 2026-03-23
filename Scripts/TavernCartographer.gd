extends Node

@export var cartographer_name: String = "Cartographer"
@export var cartographer_button: BaseButton

var parent_ui: Control = null
var stock: Array[Dictionary] = []
var current_index: int = 0
var interaction_active: bool = false

func _ready() -> void:
	parent_ui = get_parent() as Control
	if cartographer_button != null and not cartographer_button.pressed.is_connected(interact):
		cartographer_button.pressed.connect(interact)

func interact() -> void:
	if parent_ui == null:
		return

	stock = CampaignManager.get_expedition_cartographer_shop_entries()
	current_index = 0
	interaction_active = true
	_show_offer()

func _build_expedition_ledger_section() -> String:
	var header: String = "Expedition ledger (your charts)"
	var owned: Array[String] = CampaignManager.get_owned_expedition_maps()
	if owned.is_empty():
		return "%s\nNo expedition charts in your satchel yet." % header
	var lines: PackedStringArray = PackedStringArray([header])
	for map_id in owned:
		var done: bool = CampaignManager.has_completed_expedition(map_id)
		lines.append(ExpeditionMapDatabase.build_cartographer_ledger_entry(map_id, done, CampaignManager.get_expedition_outcome_note(map_id)))
	return "\n".join(lines)

func _ledger_separator() -> String:
	return "\n\n—\n\n"

func _show_offer() -> void:
	if parent_ui == null:
		return

	parent_ui.dialogue_panel.show()
	parent_ui.choice_container.show()
	parent_ui.next_btn.hide()
	parent_ui.active_character_a = {"unit_name": cartographer_name}
	parent_ui.active_character_b = {}

	if stock.is_empty():
		if parent_ui.has_node("DialoguePanel/SpeakerName"):
			parent_ui.speaker_name.text = cartographer_name
		var ledger_empty: String = _build_expedition_ledger_section()
		parent_ui.dialogue_text.text = ledger_empty + _ledger_separator() + "No expedition maps are in stock tonight. Come back after the roads change."
		_bind_button(parent_ui.choice_btn_1, "Leave", _close_interaction)
		_hide_button(parent_ui.choice_btn_2)
		_hide_button(parent_ui.choice_btn_3)
		_hide_button(parent_ui.choice_btn_4)
		return

	current_index = clampi(current_index, 0, stock.size() - 1)
	var map_data: Dictionary = stock[current_index]
	var map_id: String = str(map_data.get("id", ""))
	var display_name: String = str(map_data.get("display_name", "Unknown Expedition"))
	var description: String = str(map_data.get("description", ""))
	var price: int = int(map_data.get("price", 0))
	var rarity: String = str(map_data.get("rarity", "Common"))
	var recommended_level: int = int(map_data.get("recommended_level", 1))
	var owned_maps: Array[String] = CampaignManager.get_owned_expedition_maps()
	var owned: bool = owned_maps.has(map_id)

	if parent_ui.has_node("DialoguePanel/SpeakerName"):
		parent_ui.speaker_name.text = cartographer_name

	var status_line: String = "Owned" if owned else "Unowned"
	var completed: bool = CampaignManager.has_completed_expedition(map_id)
	var repeatable: bool = ExpeditionMapDatabase.is_entry_repeatable(map_data)
	var run_line: String = "Run: %s | Contract: %s" % [
		("Completed" if completed else "Not completed"),
		("Repeatable" if repeatable else "One-time")
	]
	var hazard_pitch: String = str(map_data.get("world_map_hazard_pitch", "")).strip_edges()
	var hazard_line: String = ("%s\n" % hazard_pitch) if hazard_pitch != "" else ""

	var mod_line: String = ExpeditionMapDatabase.build_expedition_modifier_ui_line(map_data)
	var modifier_block: String = ("%s\n" % mod_line) if mod_line != "" else ""

	var survey_line: String = ""
	if completed:
		var sn: String = CampaignManager.get_expedition_outcome_note(map_id)
		if sn != "":
			survey_line = "Survey: %s\n" % sn

	var ledger: String = _build_expedition_ledger_section()
	var offer_body: String = "%s%s%s%s\n%s\nRarity: %s | Recommended Lv.%d | Price: %dG | %s\n%s\nStock %d/%d" % [
		hazard_line,
		modifier_block,
		survey_line,
		display_name,
		description,
		rarity,
		recommended_level,
		price,
		status_line,
		run_line,
		current_index + 1,
		stock.size()
	]
	parent_ui.dialogue_text.text = ledger + _ledger_separator() + offer_body

	var buy_text: String = "Already Owned" if owned and not bool(map_data.get("consumable", false)) else "Buy (%dG)" % price
	_bind_button(parent_ui.choice_btn_1, buy_text, _attempt_purchase.bind(map_data))
	_bind_button(parent_ui.choice_btn_2, "Previous", _cycle_stock.bind(-1))
	_bind_button(parent_ui.choice_btn_3, "Next", _cycle_stock.bind(1))
	_bind_button(parent_ui.choice_btn_4, "Leave", _close_interaction)

func _attempt_purchase(map_data: Dictionary) -> void:
	var map_id: String = str(map_data.get("id", "")).strip_edges()
	var map_name: String = str(map_data.get("display_name", "Expedition Map"))
	var price: int = max(0, int(map_data.get("price", 0)))
	var is_consumable: bool = bool(map_data.get("consumable", false))

	if map_id == "":
		_show_feedback("That map ledger entry is corrupted.", Color.ORANGE_RED)
		return

	if CampaignManager.has_expedition_map(map_id):
		_show_feedback("You already own %s." % map_name, Color.ORANGE_RED)
		_show_offer()
		return

	if is_consumable:
		_show_feedback("%s is marked consumable, but stack tracking is not enabled yet.", Color.ORANGE_RED)
		_show_offer()
		return

	if CampaignManager.global_gold < price:
		_show_feedback("Not enough gold for %s." % map_name, Color.ORANGE_RED)
		_show_offer()
		return

	CampaignManager.global_gold -= price
	var added: bool = CampaignManager.add_expedition_map(map_id)
	if not added:
		CampaignManager.global_gold += price
		_show_feedback("Purchase blocked. You already own %s." % map_name, Color.ORANGE_RED)
		_show_offer()
		return

	CampaignManager.save_current_progress()
	_show_feedback("Purchased %s. Expedition route charted." % map_name, Color.LIME_GREEN)
	_show_offer()

func _cycle_stock(step: int) -> void:
	if stock.is_empty():
		return
	current_index = wrapi(current_index + step, 0, stock.size())
	_show_offer()

func _bind_button(button: BaseButton, label: String, callable: Callable) -> void:
	if button == null:
		return
	_disconnect_button(button)
	button.text = label
	button.show()
	button.pressed.connect(callable, CONNECT_ONE_SHOT)

func _hide_button(button: BaseButton) -> void:
	if button == null:
		return
	_disconnect_button(button)
	button.hide()

func _disconnect_button(button: BaseButton) -> void:
	if button == null:
		return
	if parent_ui != null and parent_ui.has_method("_disconnect_all_pressed"):
		parent_ui._disconnect_all_pressed(button)

func _show_feedback(message: String, color: Color) -> void:
	if parent_ui != null and parent_ui.has_method("_show_system_message"):
		parent_ui._show_system_message(message, color)

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

