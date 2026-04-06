extends Node

const FateCardCatalog = preload("res://Scripts/FateCardCatalog.gd")

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
const TITLE_UNLOCKS: Array[String] = [
	"House Familiar",
	"Luck-Touched",
	"High Roller"
]

const CARD_PANEL_BG: Color = Color(0.11, 0.08, 0.05, 0.985)
const CARD_PANEL_BG_ALT: Color = Color(0.09, 0.065, 0.04, 0.975)
const CARD_BORDER: Color = Color(0.82, 0.66, 0.24, 0.98)
const CARD_BORDER_SOFT: Color = Color(0.46, 0.36, 0.15, 0.96)
const CARD_TEXT: Color = Color(0.95, 0.92, 0.86, 1.0)
const CARD_TEXT_MUTED: Color = Color(0.76, 0.72, 0.66, 1.0)
const CARD_BUTTON_BG: Color = Color(0.28, 0.21, 0.13, 0.94)
const CARD_BUTTON_HOVER: Color = Color(0.38, 0.28, 0.16, 0.98)
const CARD_BUTTON_PRESSED: Color = Color(0.50, 0.37, 0.20, 0.98)
const FATE_HAND_CARD_WIDTH: float = 282.0
const FATE_HAND_CARD_HEIGHT: float = 320.0
## Active strip mini-cards: same footprint ratio as hand (282×320); fixed-size SubViewport clips inner UI min-size overflow.
const FATE_ACTIVE_STRIP_CARD_WIDTH: float = 168.0
const FATE_ACTIVE_STRIP_CARD_HEIGHT: float = FATE_HAND_CARD_HEIGHT * FATE_ACTIVE_STRIP_CARD_WIDTH / FATE_HAND_CARD_WIDTH
## Logical height slack (pre-scale): hand-layout VBox can exceed 320px when summaries wrap; scale this with strip width for viewport height.
const FATE_ACTIVE_STRIP_LAYOUT_OVERFLOW_H: float = 48.0
## SubViewport height in pixels = scale * (320 + overflow). Taller panel chrome below does not extend the texture—this must fit the full scaled card.
const FATE_ACTIVE_STRIP_SHELL_H: int = maxi(
	2,
	int(ceilf((FATE_HAND_CARD_HEIGHT + FATE_ACTIVE_STRIP_LAYOUT_OVERFLOW_H) * FATE_ACTIVE_STRIP_CARD_WIDTH / FATE_HAND_CARD_WIDTH))
)
## Inner chrome: title + VBox seps + bottom pad + style fudge so PanelContainer never fits the strip shorter than the shells.
const FATE_ACTIVE_BAR_MIN_HEIGHT: float = float(FATE_ACTIVE_STRIP_SHELL_H + 36 + 6 + 6 + 24 + 44)
## 3 slots + HBox separations; keeps the bar wide enough that CenterContainer cannot negative-offset the strip off-screen.
const FATE_ACTIVE_STRIP_ROW_MIN_WIDTH: float = (
	3.0 * float(int(round(FATE_ACTIVE_STRIP_CARD_WIDTH))) + 2.0 * 8.0 + 24.0
)
const FATE_HAND_SPACING: float = 174.0
const FATE_HAND_MARGIN: float = 20.0
const FATE_DRAG_START_DISTANCE: float = 10.0
const FATE_DRAG_CURSOR_OFFSET: Vector2 = Vector2(26.0, 34.0)
## Drag ghost tilts with horizontal motion (radians); pivot at card center.
const FATE_DRAG_SWING_MAX_RAD: float = 0.5
const FATE_DRAG_SWING_PER_PX: float = 0.003
const FATE_DRAG_SWING_SMOOTH: float = 22.0
const FATE_PLACE_IN_SLOT_DURATION: float = 0.38
const FATE_HAND_PAGE_SIZE: int = 6

var parent_ui: Control = null
var interaction_active: bool = false
var _fate_overlay_layer: CanvasLayer = null
var _fate_overlay_root: Control = null
var _fate_deck_panel: PanelContainer = null
var _fate_backdrop: ColorRect = null
var _fate_header_label: Label = null
var _fate_summary_label: Label = null
var _fate_feedback_label: Label = null
var _fate_active_strip: HBoxContainer = null
var _fate_hand_area: Control = null
var _fate_card_scroll: Control = null
var _fate_card_grid: Control = null
var _fate_hand_prev_button: Button = null
var _fate_hand_next_button: Button = null
var _fate_hand_page_label: Label = null
var _fate_draw_button: Button = null
var _fate_cash_button: Button = null
var _fate_close_button: Button = null
var _fate_preview_backdrop: ColorRect = null
var _fate_preview_panel: PanelContainer = null
var _fate_preview_host: Control = null
var _fate_card_fallback_portrait: Texture2D = null
var _fate_hidden_chat_panel: Control = null
var _fate_chat_panel_was_visible: bool = false
var _fate_hidden_dialogue_panel: Control = null
var _fate_dialogue_panel_was_visible: bool = false
var _fate_active_slot_nodes: Array[Control] = []
var _fate_dragging: bool = false
var _fate_drag_card_id: String = ""
var _fate_drag_card_owned: bool = false
var _fate_drag_card_active: bool = false
var _fate_drag_visual: Control = null
var _fate_drag_source_panel: Control = null
var _fate_drag_offset: Vector2 = Vector2.ZERO
var _fate_drag_hover_slot: int = -1
var _fate_drag_candidate_panel: Control = null
var _fate_drag_candidate_card_id: String = ""
var _fate_drag_candidate_owned: bool = false
var _fate_drag_candidate_active: bool = false
var _fate_drag_candidate_press_global: Vector2 = Vector2.ZERO
var _fate_drag_swing_prev_global: Vector2 = Vector2.ZERO
var _fate_drag_swing_angle: float = 0.0
var _fate_slot_placement_animating: bool = false
var _fate_place_tween: Tween = null
var _fate_hovered_panel: Control = null
var _fate_hand_cards_data: Array[Dictionary] = []
var _fate_hand_page: int = 0

func _ready() -> void:
	parent_ui = get_parent() as Control
	if gambler_button != null and not gambler_button.pressed.is_connected(interact):
		gambler_button.pressed.connect(interact)
	set_process(false)


func _process(delta: float) -> void:
	if not _fate_dragging or _fate_drag_visual == null or not is_instance_valid(_fate_drag_visual):
		set_process(false)
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var gp: Vector2 = vp.get_mouse_position()
	var dx: float = gp.x - _fate_drag_swing_prev_global.x
	_fate_drag_swing_prev_global = gp
	var target: float = clampf(dx * FATE_DRAG_SWING_PER_PX, -FATE_DRAG_SWING_MAX_RAD, FATE_DRAG_SWING_MAX_RAD)
	var t: float = 1.0 - exp(-FATE_DRAG_SWING_SMOOTH * delta)
	_fate_drag_swing_angle = lerpf(_fate_drag_swing_angle, target, t)
	_fate_drag_visual.rotation = _fate_drag_swing_angle


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
	var starter_cards: Array[String] = []
	if FateCardCatalog.STARTER_CARD_ID.strip_edges() != "":
		starter_cards.append(FateCardCatalog.STARTER_CARD_ID)
	return {
		"favor": 0,
		"chips": 0,
		"streak": 0,
		"best_streak": 0,
		"plays_used": 0,
		"last_refresh_token": token,
		"titles": [],
		"cards_owned_ids": starter_cards,
		"cards_active_slots": ["", "", ""],
		"cards_active_ids": []
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
	var owned_cards: Array[String] = _normalize_owned_card_ids(state.get("cards_owned_ids", []))
	state["cards_owned_ids"] = owned_cards
	state["cards_active_slots"] = _normalize_active_slots(
		state.get("cards_active_slots", []),
		owned_cards,
		state.get("cards_active_ids", [])
	)
	state["cards_active_ids"] = _compact_active_slots(state["cards_active_slots"])
	var active_ids_tmp: Array[String] = _compact_active_slots(state["cards_active_slots"])
	if active_ids_tmp.is_empty():
		state["cards_active_ids"] = _normalize_active_card_ids(
			state.get("cards_active_ids", []),
			owned_cards
		)
		state["cards_active_slots"] = _slots_from_active_ids(state["cards_active_ids"])
	else:
		state["cards_active_ids"] = active_ids_tmp

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
	_hide_fate_deck(false)
	var state: Dictionary = _read_state()
	var plays_left: int = _plays_left(state)
	var favor: int = int(state.get("favor", 0))
	var chips: int = int(state.get("chips", 0))
	var streak: int = int(state.get("streak", 0))
	var best_streak: int = int(state.get("best_streak", 0))
	var titles_text: String = _format_titles(state)
	var active_cards_text: String = _format_active_cards_line(state)

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
		+ "Unlocked Titles: %s\n"
		+ "Active Fate Cards: %s%s"
	) % [
		plays_left,
		maxi(0, max_plays_per_progress_level),
		favor,
		chips,
		streak,
		best_streak,
		titles_text,
		active_cards_text,
		status_text
	]

	_bind_button(parent_ui.choice_btn_1, "Safe Hand (%dG)" % maxi(1, safe_buy_in_gold), _play_safe_hand)
	_bind_button(parent_ui.choice_btn_2, "High Roll (%dG)" % maxi(1, high_buy_in_gold), _play_high_roll)
	_bind_button(parent_ui.choice_btn_3, "Fate Deck", _open_fate_deck)
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
	_show_table(_cash_in_chips_for_title_internal())


func _cash_in_chips_for_title_internal() -> String:
	var state: Dictionary = _read_state()
	var chip_cost: int = maxi(1, chips_per_title_unlock)
	var chips: int = int(state.get("chips", 0))
	if chips < chip_cost:
		return "You need %d chips to cash in." % chip_cost

	var next_title: String = _next_unlockable_title(state)
	if next_title == "":
		return "No more titles to unlock. Keep your chips."

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
	return "Unlocked title: %s" % next_title


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
	_hide_fate_deck(false)
	if parent_ui == null:
		return
	parent_ui.choice_container.hide()
	parent_ui.choice_btn_1.hide()
	parent_ui.choice_btn_2.hide()
	parent_ui.choice_btn_3.hide()
	parent_ui.choice_btn_4.hide()
	parent_ui.dialogue_panel.hide()


func _normalize_owned_card_ids(raw_ids: Variant) -> Array[String]:
	var catalog_ids: Dictionary = {}
	for card_any in FateCardCatalog.get_all_cards():
		var card: Dictionary = card_any
		var cid: String = str(card.get("id", "")).strip_edges()
		if cid != "":
			catalog_ids[cid] = true

	var normalized: Array[String] = []
	if raw_ids is Array:
		for id_v in (raw_ids as Array):
			var cid: String = str(id_v).strip_edges()
			if cid == "":
				continue
			if not catalog_ids.has(cid):
				continue
			if not normalized.has(cid):
				normalized.append(cid)

	if normalized.is_empty():
		var starter: String = FateCardCatalog.STARTER_CARD_ID.strip_edges()
		if starter != "":
			normalized.append(starter)
	return normalized


func _normalize_active_card_ids(raw_ids: Variant, owned_ids: Array[String]) -> Array[String]:
	var normalized: Array[String] = []
	if raw_ids is Array:
		for id_v in (raw_ids as Array):
			var cid: String = str(id_v).strip_edges()
			if cid == "":
				continue
			if not owned_ids.has(cid):
				continue
			if normalized.has(cid):
				continue
			normalized.append(cid)
			if normalized.size() >= FateCardCatalog.MAX_ACTIVE_CARDS:
				break
	return normalized


func _slots_from_active_ids(active_ids: Variant) -> Array[String]:
	var slots: Array[String] = []
	for _i in range(FateCardCatalog.MAX_ACTIVE_CARDS):
		slots.append("")
	if active_ids is Array:
		var write_idx: int = 0
		for id_v in (active_ids as Array):
			if write_idx >= FateCardCatalog.MAX_ACTIVE_CARDS:
				break
			var cid: String = str(id_v).strip_edges()
			if cid == "":
				continue
			slots[write_idx] = cid
			write_idx += 1
	return slots


func _compact_active_slots(slots: Variant) -> Array[String]:
	var compact: Array[String] = []
	if slots is Array:
		for id_v in (slots as Array):
			var cid: String = str(id_v).strip_edges()
			if cid != "":
				compact.append(cid)
	return compact


func _normalize_active_slots(raw_slots: Variant, owned_ids: Array[String], fallback_ids: Variant = []) -> Array[String]:
	var slots: Array[String] = _slots_from_active_ids([])
	var used: Dictionary = {}
	var had_any: bool = false
	if raw_slots is Array:
		var raw_arr: Array = raw_slots as Array
		for i in range(mini(FateCardCatalog.MAX_ACTIVE_CARDS, raw_arr.size())):
			var cid: String = str(raw_arr[i]).strip_edges()
			if cid == "" or not owned_ids.has(cid) or used.has(cid):
				continue
			slots[i] = cid
			used[cid] = true
			had_any = true
	if had_any:
		return slots
	var normalized_ids: Array[String] = _normalize_active_card_ids(fallback_ids, owned_ids)
	return _slots_from_active_ids(normalized_ids)


func _format_active_cards_line(state: Dictionary) -> String:
	var raw_active: Variant = state.get("cards_active_ids", [])
	var active_ids: Array[String] = _normalize_active_card_ids(
		raw_active,
		_normalize_owned_card_ids(state.get("cards_owned_ids", []))
	)
	if active_ids.is_empty():
		return "None"
	var names: Array[String] = []
	for cid in active_ids:
		var card: Dictionary = FateCardCatalog.get_card(cid)
		var cname: String = str(card.get("name", cid)).strip_edges()
		if cname != "":
			names.append(cname)
	return ", ".join(names) if not names.is_empty() else "None"


func _open_fate_deck() -> void:
	if parent_ui == null:
		return
	interaction_active = true
	_ensure_fate_deck_ui()
	_prepare_modal_state_for_fate_deck()
	_refresh_fate_deck_ui("")
	_render_fate_hand_page()
	_hide_fate_preview()
	if _fate_backdrop != null:
		_fate_backdrop.show()
	if _fate_deck_panel != null:
		_fate_deck_panel.show()
	if _fate_hand_area != null:
		_fate_hand_area.show()


func _hide_fate_deck(restore_table: bool = true, status_line: String = "") -> void:
	_clear_drag_session()
	_fate_hand_page = 0
	_hide_fate_preview()
	if _fate_backdrop != null:
		_fate_backdrop.hide()
	if _fate_deck_panel != null:
		_fate_deck_panel.hide()
	if _fate_hand_area != null:
		_fate_hand_area.hide()
	_restore_modal_state_after_fate_deck(restore_table)
	if restore_table:
		_show_table(status_line)


func _ensure_fate_deck_ui() -> void:
	if parent_ui == null:
		return
	if _fate_deck_panel != null and is_instance_valid(_fate_deck_panel):
		return

	_fate_card_fallback_portrait = _load_texture_safe("res://Assets/Portraits/FateCardMatte/Portrait Hero 1.png")

	_fate_overlay_layer = CanvasLayer.new()
	_fate_overlay_layer.name = "FateDeckOverlayLayer"
	_fate_overlay_layer.layer = 120
	var overlay_parent: Node = get_tree().current_scene if get_tree() != null else parent_ui
	if overlay_parent == null:
		overlay_parent = parent_ui
	overlay_parent.add_child(_fate_overlay_layer)

	_fate_overlay_root = Control.new()
	_fate_overlay_root.name = "FateDeckOverlayRoot"
	_fate_overlay_root.anchor_left = 0.0
	_fate_overlay_root.anchor_top = 0.0
	_fate_overlay_root.anchor_right = 1.0
	_fate_overlay_root.anchor_bottom = 1.0
	_fate_overlay_root.offset_left = 0.0
	_fate_overlay_root.offset_top = 0.0
	_fate_overlay_root.offset_right = 0.0
	_fate_overlay_root.offset_bottom = 0.0
	_fate_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fate_overlay_layer.add_child(_fate_overlay_root)

	_fate_backdrop = ColorRect.new()
	_fate_backdrop.name = "FateDeckBackdrop"
	_fate_backdrop.anchor_left = 0.0
	_fate_backdrop.anchor_top = 0.0
	_fate_backdrop.anchor_right = 1.0
	_fate_backdrop.anchor_bottom = 1.0
	_fate_backdrop.offset_left = 0.0
	_fate_backdrop.offset_top = 0.0
	_fate_backdrop.offset_right = 0.0
	_fate_backdrop.offset_bottom = 0.0
	_fate_backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	_fate_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_fate_overlay_root.add_child(_fate_backdrop)

	_fate_deck_panel = PanelContainer.new()
	_fate_deck_panel.name = "FateDeckPanel"
	_fate_deck_panel.anchor_left = 0.12
	_fate_deck_panel.anchor_top = 0.10
	_fate_deck_panel.anchor_right = 0.88
	_fate_deck_panel.anchor_bottom = 0.92
	_fate_deck_panel.offset_left = 0.0
	_fate_deck_panel.offset_top = 0.0
	_fate_deck_panel.offset_right = 0.0
	_fate_deck_panel.offset_bottom = 0.0
	_fate_deck_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_fate_deck_panel.add_theme_stylebox_override("panel", _make_panel_style(CARD_PANEL_BG, CARD_BORDER, 20, 2, 16, 14))
	_fate_deck_panel.clip_contents = false
	_fate_overlay_root.add_child(_fate_deck_panel)

	var root_margin: MarginContainer = MarginContainer.new()
	root_margin.add_theme_constant_override("margin_left", 16)
	root_margin.add_theme_constant_override("margin_right", 16)
	root_margin.add_theme_constant_override("margin_top", 16)
	root_margin.add_theme_constant_override("margin_bottom", 16)
	_fate_deck_panel.add_child(root_margin)

	var deck_scroll: ScrollContainer = ScrollContainer.new()
	deck_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	deck_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root_margin.add_child(deck_scroll)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_scroll.add_child(root)

	_fate_header_label = Label.new()
	_fate_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fate_header_label.add_theme_font_size_override("font_size", 30)
	_fate_header_label.add_theme_color_override("font_color", CARD_TEXT)
	_fate_header_label.text = "FATE DECK"
	root.add_child(_fate_header_label)

	_fate_summary_label = Label.new()
	_fate_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fate_summary_label.add_theme_font_size_override("font_size", 18)
	_fate_summary_label.add_theme_color_override("font_color", CARD_TEXT_MUTED)
	_fate_summary_label.text = "Select up to %d active cards. Active cards are reserved for future Fate Gambler map modifiers." % FateCardCatalog.MAX_ACTIVE_CARDS
	root.add_child(_fate_summary_label)

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	root.add_child(action_row)

	_fate_draw_button = Button.new()
	_fate_draw_button.text = "Draw Card (%d Chips)" % maxi(1, FateCardCatalog.DRAW_CHIP_COST)
	_fate_draw_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(_fate_draw_button, 20)
	_fate_draw_button.pressed.connect(_on_draw_card_pressed)
	action_row.add_child(_fate_draw_button)

	_fate_cash_button = Button.new()
	_fate_cash_button.text = "Cash Chips (%d)" % maxi(1, chips_per_title_unlock)
	_fate_cash_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(_fate_cash_button, 20)
	_fate_cash_button.pressed.connect(_on_cash_title_pressed)
	action_row.add_child(_fate_cash_button)

	_fate_close_button = Button.new()
	_fate_close_button.text = "Back To Table"
	_fate_close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(_fate_close_button, 20)
	_fate_close_button.pressed.connect(_on_close_fate_deck_pressed)
	action_row.add_child(_fate_close_button)

	_fate_feedback_label = Label.new()
	_fate_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fate_feedback_label.add_theme_font_size_override("font_size", 16)
	_fate_feedback_label.add_theme_color_override("font_color", CARD_TEXT)
	_fate_feedback_label.text = ""
	root.add_child(_fate_feedback_label)

	var active_bar_panel: PanelContainer = PanelContainer.new()
	active_bar_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.12, 0.09, 0.06, 0.98), CARD_BORDER_SOFT, 12, 1, 8, 8))
	active_bar_panel.clip_contents = false
	active_bar_panel.custom_minimum_size = Vector2(FATE_ACTIVE_STRIP_ROW_MIN_WIDTH, FATE_ACTIVE_BAR_MIN_HEIGHT)
	active_bar_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(active_bar_panel)

	var active_bar_root: VBoxContainer = VBoxContainer.new()
	active_bar_root.add_theme_constant_override("separation", 6)
	active_bar_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	active_bar_root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	active_bar_panel.add_child(active_bar_root)

	var active_title: Label = Label.new()
	active_title.text = "ACTIVE DECK"
	active_title.add_theme_font_size_override("font_size", 14)
	active_title.add_theme_color_override("font_color", CARD_TEXT_MUTED)
	active_bar_root.add_child(active_title)

	var active_hint: Label = Label.new()
	active_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_hint.add_theme_font_size_override("font_size", 12)
	active_hint.add_theme_color_override("font_color", CARD_TEXT_MUTED)
	active_hint.text = "Drag cards into slots. Left-click an active card to preview it. Right-click to remove it."
	active_bar_root.add_child(active_hint)

	_fate_active_strip = HBoxContainer.new()
	_fate_active_strip.add_theme_constant_override("separation", 8)
	_fate_active_strip.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_fate_active_strip.alignment = BoxContainer.ALIGNMENT_BEGIN
	_fate_active_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fate_active_strip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_fate_active_strip.custom_minimum_size = Vector2(0.0, float(FATE_ACTIVE_STRIP_SHELL_H))
	active_bar_root.add_child(_fate_active_strip)

	var active_strip_bottom_pad: Control = Control.new()
	active_strip_bottom_pad.custom_minimum_size = Vector2(0, 24)
	active_bar_root.add_child(active_strip_bottom_pad)

	var hand_hint: Label = Label.new()
	hand_hint.add_theme_font_size_override("font_size", 13)
	hand_hint.add_theme_color_override("font_color", CARD_TEXT_MUTED)
	hand_hint.text = "Drag cards from the hand into active slots."
	root.add_child(hand_hint)

	var hand_nav_row: HBoxContainer = HBoxContainer.new()
	hand_nav_row.add_theme_constant_override("separation", 8)
	root.add_child(hand_nav_row)

	_fate_hand_prev_button = Button.new()
	_fate_hand_prev_button.text = "<"
	_fate_hand_prev_button.custom_minimum_size = Vector2(56, 28)
	_style_button(_fate_hand_prev_button, 16)
	_fate_hand_prev_button.pressed.connect(_on_fate_prev_page_pressed)
	hand_nav_row.add_child(_fate_hand_prev_button)

	_fate_hand_page_label = Label.new()
	_fate_hand_page_label.text = "HAND 1/1"
	_fate_hand_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fate_hand_page_label.add_theme_font_size_override("font_size", 14)
	_fate_hand_page_label.add_theme_color_override("font_color", CARD_TEXT)
	hand_nav_row.add_child(_fate_hand_page_label)

	_fate_hand_next_button = Button.new()
	_fate_hand_next_button.text = ">"
	_fate_hand_next_button.custom_minimum_size = Vector2(56, 28)
	_style_button(_fate_hand_next_button, 16)
	_fate_hand_next_button.pressed.connect(_on_fate_next_page_pressed)
	hand_nav_row.add_child(_fate_hand_next_button)

	_fate_hand_area = Control.new()
	_fate_hand_area.name = "FateHandArea"
	_fate_hand_area.anchor_left = 0.08
	_fate_hand_area.anchor_top = 0.46
	_fate_hand_area.anchor_right = 0.92
	_fate_hand_area.anchor_bottom = 0.88
	_fate_hand_area.offset_left = 0.0
	_fate_hand_area.offset_top = 0.0
	_fate_hand_area.offset_right = 0.0
	_fate_hand_area.offset_bottom = 0.0
	_fate_hand_area.mouse_filter = Control.MOUSE_FILTER_PASS
	_fate_overlay_root.add_child(_fate_hand_area)

	_fate_card_scroll = Control.new()
	_fate_card_scroll.anchor_left = 0.0
	_fate_card_scroll.anchor_top = 0.0
	_fate_card_scroll.anchor_right = 1.0
	_fate_card_scroll.anchor_bottom = 1.0
	_fate_card_scroll.offset_left = 0.0
	_fate_card_scroll.offset_top = 0.0
	_fate_card_scroll.offset_right = 0.0
	_fate_card_scroll.offset_bottom = 0.0
	_fate_card_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_fate_hand_area.add_child(_fate_card_scroll)

	_fate_card_grid = Control.new()
	_fate_card_grid.custom_minimum_size = Vector2(620, 520)
	_fate_card_scroll.add_child(_fate_card_grid)

	_fate_preview_backdrop = ColorRect.new()
	_fate_preview_backdrop.anchor_left = 0.0
	_fate_preview_backdrop.anchor_top = 0.0
	_fate_preview_backdrop.anchor_right = 1.0
	_fate_preview_backdrop.anchor_bottom = 1.0
	_fate_preview_backdrop.offset_left = 0.0
	_fate_preview_backdrop.offset_top = 0.0
	_fate_preview_backdrop.offset_right = 0.0
	_fate_preview_backdrop.offset_bottom = 0.0
	_fate_preview_backdrop.color = Color(0.0, 0.0, 0.0, 0.68)
	_fate_preview_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_fate_preview_backdrop.z_as_relative = false
	_fate_preview_backdrop.z_index = 200
	_fate_preview_backdrop.gui_input.connect(_on_fate_preview_backdrop_input)
	_fate_overlay_root.add_child(_fate_preview_backdrop)

	_fate_preview_panel = PanelContainer.new()
	_fate_preview_panel.anchor_left = 0.5
	_fate_preview_panel.anchor_top = 0.5
	_fate_preview_panel.anchor_right = 0.5
	_fate_preview_panel.anchor_bottom = 0.5
	_fate_preview_panel.offset_left = -190.0
	_fate_preview_panel.offset_top = -300.0
	_fate_preview_panel.offset_right = 190.0
	_fate_preview_panel.offset_bottom = 300.0
	_fate_preview_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_fate_preview_panel.z_as_relative = false
	_fate_preview_panel.z_index = 201
	_fate_preview_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.11, 0.08, 0.05, 0.99), CARD_BORDER, 16, 2, 10, 10))
	_fate_overlay_root.add_child(_fate_preview_panel)

	_fate_preview_host = Control.new()
	_fate_preview_host.anchor_left = 0.0
	_fate_preview_host.anchor_top = 0.0
	_fate_preview_host.anchor_right = 1.0
	_fate_preview_host.anchor_bottom = 1.0
	_fate_preview_host.offset_left = 0.0
	_fate_preview_host.offset_top = 0.0
	_fate_preview_host.offset_right = 0.0
	_fate_preview_host.offset_bottom = 0.0
	_fate_preview_panel.add_child(_fate_preview_host)

	if not parent_ui.resized.is_connected(_on_parent_ui_resized):
		parent_ui.resized.connect(_on_parent_ui_resized)
	if _fate_overlay_root != null and not _fate_overlay_root.resized.is_connected(_on_parent_ui_resized):
		_fate_overlay_root.resized.connect(_on_parent_ui_resized)

	_fate_backdrop.hide()
	_fate_deck_panel.hide()
	if _fate_hand_area != null:
		_fate_hand_area.hide()
	_hide_fate_preview()
	_on_parent_ui_resized()


func _prepare_modal_state_for_fate_deck() -> void:
	if parent_ui == null:
		return
	var dialogue_panel: Control = _resolve_parent_ui_control("dialogue_panel", "DialoguePanel")
	if dialogue_panel != null:
		_fate_hidden_dialogue_panel = dialogue_panel
		_fate_dialogue_panel_was_visible = dialogue_panel.visible
		dialogue_panel.hide()
	var choice_container: Control = _resolve_parent_ui_control("choice_container", "DialoguePanel/ChoiceContainer")
	if choice_container != null:
		choice_container.hide()
	for btn_key in ["choice_btn_1", "choice_btn_2", "choice_btn_3", "choice_btn_4", "next_btn"]:
		var btn_node: Control = _resolve_parent_ui_control(btn_key, "")
		if btn_node != null:
			btn_node.hide()
	var chat_panel: Control = parent_ui.get_node_or_null("ChatPanel") as Control
	if chat_panel != null:
		_fate_hidden_chat_panel = chat_panel
		_fate_chat_panel_was_visible = chat_panel.visible
		chat_panel.hide()


func _restore_modal_state_after_fate_deck(restore_dialogue: bool) -> void:
	if _fate_hidden_dialogue_panel != null and is_instance_valid(_fate_hidden_dialogue_panel):
		if restore_dialogue and _fate_dialogue_panel_was_visible:
			_fate_hidden_dialogue_panel.show()
	_fate_hidden_dialogue_panel = null
	_fate_dialogue_panel_was_visible = false

	if _fate_hidden_chat_panel != null and is_instance_valid(_fate_hidden_chat_panel):
		if _fate_chat_panel_was_visible:
			_fate_hidden_chat_panel.show()
	_fate_hidden_chat_panel = null
	_fate_chat_panel_was_visible = false


func _resolve_parent_ui_control(property_name: String, fallback_path: String) -> Control:
	if parent_ui == null:
		return null
	if property_name.strip_edges() != "":
		var v: Variant = parent_ui.get(property_name)
		if v is Control:
			return v as Control
	if fallback_path.strip_edges() != "":
		return parent_ui.get_node_or_null(fallback_path) as Control
	return null


func _on_draw_card_pressed() -> void:
	_refresh_fate_deck_ui(_draw_fate_card())


func _on_cash_title_pressed() -> void:
	_refresh_fate_deck_ui(_cash_in_chips_for_title_internal())


func _on_close_fate_deck_pressed() -> void:
	_hide_fate_deck(true, "")


func _draw_fate_card() -> String:
	var state: Dictionary = _read_state()
	var chips: int = int(state.get("chips", 0))
	var cost: int = maxi(1, FateCardCatalog.DRAW_CHIP_COST)
	if chips < cost:
		return "Not enough chips to draw. Need %d." % cost

	var owned_ids: Array[String] = _normalize_owned_card_ids(state.get("cards_owned_ids", []))
	var missing_cards: Array[String] = []
	for card_any in FateCardCatalog.get_all_cards():
		var card: Dictionary = card_any
		var cid: String = str(card.get("id", "")).strip_edges()
		if cid != "" and not owned_ids.has(cid):
			missing_cards.append(cid)

	if missing_cards.is_empty():
		return "Deck complete. No cards left to draw."

	var pick_index: int = randi() % missing_cards.size()
	var unlocked_id: String = missing_cards[pick_index]
	var unlocked_card: Dictionary = FateCardCatalog.get_card(unlocked_id)
	var unlocked_name: String = str(unlocked_card.get("name", unlocked_id)).strip_edges()

	owned_ids.append(unlocked_id)
	state["cards_owned_ids"] = owned_ids
	state["chips"] = chips - cost
	var slots: Array[String] = _normalize_active_slots(
		state.get("cards_active_slots", []),
		owned_ids,
		state.get("cards_active_ids", [])
	)
	state["cards_active_slots"] = slots
	state["cards_active_ids"] = _compact_active_slots(slots)
	_write_state(state, true)

	return "Drawn card: %s (%s)." % [
		unlocked_name,
		str(unlocked_card.get("rarity", "unknown")).capitalize()
	]


func _toggle_fate_card(card_id: String) -> String:
	var wanted_id: String = card_id.strip_edges()
	if wanted_id == "":
		return ""
	var state: Dictionary = _read_state()
	var owned_ids: Array[String] = _normalize_owned_card_ids(state.get("cards_owned_ids", []))
	if not owned_ids.has(wanted_id):
		return "Card locked."

	var slots: Array[String] = _normalize_active_slots(
		state.get("cards_active_slots", []),
		owned_ids,
		state.get("cards_active_ids", [])
	)
	var card: Dictionary = FateCardCatalog.get_card(wanted_id)
	var card_name: String = str(card.get("name", wanted_id)).strip_edges()
	for i in range(FateCardCatalog.MAX_ACTIVE_CARDS):
		if slots[i] == wanted_id:
			slots[i] = ""
			state["cards_active_slots"] = slots
			state["cards_active_ids"] = _compact_active_slots(slots)
			_write_state(state, true)
			return "Removed from active deck: %s." % card_name

	var first_empty: int = -1
	for i in range(FateCardCatalog.MAX_ACTIVE_CARDS):
		if str(slots[i]).strip_edges() == "":
			first_empty = i
			break
	if first_empty == -1:
		return "Active deck full (%d). Remove a card first." % FateCardCatalog.MAX_ACTIVE_CARDS

	slots[first_empty] = wanted_id
	state["cards_active_slots"] = slots
	state["cards_active_ids"] = _compact_active_slots(slots)
	_write_state(state, true)
	return "Set active: %s." % card_name


func _fate_active_slot_inner_panel(slot_root: Control) -> PanelContainer:
	if slot_root is PanelContainer:
		return slot_root as PanelContainer
	# Shell (Control) -> SubViewportContainer -> SubViewport -> PanelContainer
	for d1 in slot_root.get_children():
		if d1 is SubViewportContainer:
			for d2 in d1.get_children():
				if d2 is SubViewport:
					for d3 in d2.get_children():
						if d3 is PanelContainer:
							return d3 as PanelContainer
	return null


func _assign_card_to_active_slot(card_id: String, slot_index: int) -> String:
	if slot_index < 0 or slot_index >= FateCardCatalog.MAX_ACTIVE_CARDS:
		return ""
	var wanted_id: String = card_id.strip_edges()
	if wanted_id == "":
		return ""
	var state: Dictionary = _read_state()
	var owned_ids: Array[String] = _normalize_owned_card_ids(state.get("cards_owned_ids", []))
	if not owned_ids.has(wanted_id):
		return "Card locked."

	var slots: Array[String] = _normalize_active_slots(
		state.get("cards_active_slots", []),
		owned_ids,
		state.get("cards_active_ids", [])
	)
	for i in range(FateCardCatalog.MAX_ACTIVE_CARDS):
		if slots[i] == wanted_id:
			slots[i] = ""
	slots[slot_index] = wanted_id
	state["cards_active_slots"] = slots
	state["cards_active_ids"] = _compact_active_slots(slots)
	_write_state(state, true)

	var card: Dictionary = FateCardCatalog.get_card(wanted_id)
	var card_name: String = str(card.get("name", wanted_id)).strip_edges()
	return "Placed %s in Slot %d." % [card_name, slot_index + 1]


func _clear_active_slot(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= FateCardCatalog.MAX_ACTIVE_CARDS:
		return ""
	var state: Dictionary = _read_state()
	var owned_ids: Array[String] = _normalize_owned_card_ids(state.get("cards_owned_ids", []))
	var slots: Array[String] = _normalize_active_slots(
		state.get("cards_active_slots", []),
		owned_ids,
		state.get("cards_active_ids", [])
	)
	var wanted_id: String = str(slots[slot_index]).strip_edges()
	if wanted_id == "":
		return ""
	slots[slot_index] = ""
	state["cards_active_slots"] = slots
	state["cards_active_ids"] = _compact_active_slots(slots)
	_write_state(state, true)
	var card: Dictionary = FateCardCatalog.get_card(wanted_id)
	var card_name: String = str(card.get("name", wanted_id)).strip_edges()
	return "Removed from active deck: %s." % card_name


func _set_fate_active_slot_hover(slot_root: Control, hovered: bool) -> void:
	if slot_root == null or not is_instance_valid(slot_root):
		return
	if str(slot_root.get_meta("_slot_card_id", "")).strip_edges() == "":
		return
	var old_tween: Variant = slot_root.get_meta("_hover_tween", null)
	if old_tween is Tween and is_instance_valid(old_tween):
		(old_tween as Tween).kill()
	slot_root.pivot_offset = slot_root.size * 0.5
	slot_root.z_index = 18 if hovered else 0
	var tw: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(slot_root, "scale", Vector2(1.035, 1.035) if hovered else Vector2.ONE, 0.10 if hovered else 0.08)
	tw.tween_property(slot_root, "rotation_degrees", 0.0, 0.10 if hovered else 0.08)
	slot_root.set_meta("_hover_tween", tw)


func _on_fate_active_slot_mouse_entered(slot_root: Control) -> void:
	if _fate_dragging or _fate_slot_placement_animating:
		return
	_set_fate_active_slot_hover(slot_root, true)


func _on_fate_active_slot_mouse_exited(slot_root: Control) -> void:
	if _fate_slot_placement_animating:
		return
	_set_fate_active_slot_hover(slot_root, false)


func _play_fate_active_slot_remove_feedback(slot_root: Control) -> void:
	if slot_root == null or not is_instance_valid(slot_root):
		return
	var old_hover_tween: Variant = slot_root.get_meta("_hover_tween", null)
	if old_hover_tween is Tween and is_instance_valid(old_hover_tween):
		(old_hover_tween as Tween).kill()
	slot_root.pivot_offset = slot_root.size * 0.5
	slot_root.z_index = 24
	var base_scale: Vector2 = slot_root.scale
	var base_rotation: float = slot_root.rotation_degrees
	var base_modulate: Color = slot_root.modulate
	var tw: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(slot_root, "scale", base_scale * 1.045, 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(slot_root, "modulate", Color(1.0, 0.86, 0.86, 1.0), 0.05)
	tw.chain().tween_property(slot_root, "rotation_degrees", -2.2, 0.04)
	tw.chain().tween_property(slot_root, "rotation_degrees", 2.8, 0.06)
	tw.chain().tween_property(slot_root, "rotation_degrees", 0.0, 0.05)
	tw.parallel().tween_property(slot_root, "scale", base_scale * 0.92, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(slot_root, "modulate:a", 0.0, 0.11)
	await tw.finished
	if is_instance_valid(slot_root):
		slot_root.scale = base_scale
		slot_root.rotation_degrees = base_rotation
		slot_root.modulate = base_modulate
		slot_root.z_index = 0


func _slot_from_global_position(global_pos: Vector2) -> int:
	for node in _fate_active_slot_nodes:
		if node == null or not is_instance_valid(node):
			continue
		var rect: Rect2 = node.get_global_rect()
		if rect.has_point(global_pos):
			return int(node.get_meta("_slot_index", -1))
	return -1


func _set_drag_hover_slot(slot_index: int) -> void:
	_fate_drag_hover_slot = slot_index
	for node in _fate_active_slot_nodes:
		if node == null or not is_instance_valid(node):
			continue
		var idx: int = int(node.get_meta("_slot_index", -1))
		var border_color: Variant = node.get_meta("_slot_border", CARD_BORDER_SOFT)
		var border: Color = CARD_BORDER_SOFT
		if border_color is Color:
			border = border_color
		var is_hovered: bool = (idx == slot_index)
		var bg: Color = Color(0.14, 0.11, 0.07, 0.99) if is_hovered else Color(0.10, 0.075, 0.05, 0.98)
		var bw: int = 2 if is_hovered else 1
		var slot_panel: PanelContainer = _fate_active_slot_inner_panel(node)
		if slot_panel != null:
			slot_panel.add_theme_stylebox_override("panel", _make_panel_style(bg, border, 10, bw, 6, 6))


func _clear_drag_session() -> void:
	if _fate_place_tween != null:
		if is_instance_valid(_fate_place_tween):
			_fate_place_tween.kill()
		_fate_place_tween = null
	_fate_slot_placement_animating = false
	set_process(false)
	_fate_drag_swing_angle = 0.0
	_fate_drag_swing_prev_global = Vector2.ZERO
	_fate_dragging = false
	_set_hovered_hand_card(null)
	if _fate_drag_source_panel != null and is_instance_valid(_fate_drag_source_panel):
		_fate_drag_source_panel.visible = true
	_fate_drag_source_panel = null
	_fate_drag_card_id = ""
	_fate_drag_card_owned = false
	_fate_drag_card_active = false
	_fate_drag_candidate_panel = null
	_fate_drag_candidate_card_id = ""
	_fate_drag_candidate_owned = false
	_fate_drag_candidate_active = false
	_fate_drag_candidate_press_global = Vector2.ZERO
	_fate_drag_offset = Vector2.ZERO
	if _fate_drag_visual != null and is_instance_valid(_fate_drag_visual):
		_fate_drag_visual.hide()
		if _fate_drag_visual.get_parent() != null:
			_fate_drag_visual.get_parent().remove_child(_fate_drag_visual)
		_fate_drag_visual.queue_free()
	_fate_drag_visual = null
	_fate_drag_hover_slot = -1
	_set_drag_hover_slot(-1)


func _begin_drag_from_candidate(global_pos: Vector2) -> void:
	if _fate_drag_candidate_panel == null or not is_instance_valid(_fate_drag_candidate_panel):
		return
	_set_hovered_hand_card(null)
	_hide_fate_preview()
	_fate_dragging = true
	_fate_drag_card_id = _fate_drag_candidate_card_id
	_fate_drag_card_owned = _fate_drag_candidate_owned
	_fate_drag_card_active = _fate_drag_candidate_active

	_fate_drag_source_panel = _fate_drag_candidate_panel
	var source_global: Vector2 = _fate_drag_source_panel.global_position
	var source_parent: Node = _fate_drag_source_panel.get_parent()
	if source_parent != null:
		source_parent.remove_child(_fate_drag_source_panel)
	_fate_drag_visual = _fate_drag_source_panel
	_fate_overlay_root.add_child(_fate_drag_visual)
	# Reparenting onto full-rect overlay can let PanelContainer stretch to viewport height; the
	# hand VBox uses SIZE_EXPAND_FILL + an expand spacer, so excess height becomes a tall dark band.
	var drag_card_size: Vector2 = Vector2(FATE_HAND_CARD_WIDTH, FATE_HAND_CARD_HEIGHT)
	_fate_drag_visual.anchor_left = 0.0
	_fate_drag_visual.anchor_top = 0.0
	_fate_drag_visual.anchor_right = 0.0
	_fate_drag_visual.anchor_bottom = 0.0
	_fate_drag_visual.offset_left = 0.0
	_fate_drag_visual.offset_top = 0.0
	_fate_drag_visual.offset_right = drag_card_size.x
	_fate_drag_visual.offset_bottom = drag_card_size.y
	_fate_drag_visual.custom_minimum_size = drag_card_size
	_fate_drag_visual.size = drag_card_size
	_fate_drag_visual.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_fate_drag_visual.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_fate_drag_visual.clip_contents = true
	_fate_drag_visual.pivot_offset = drag_card_size * 0.5
	_fate_drag_visual.global_position = source_global
	_fate_drag_visual.scale = Vector2.ONE
	_fate_drag_visual.modulate = Color(1.0, 1.0, 1.0, 0.93)
	_fate_drag_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fate_drag_visual.rotation = 0.0
	_fate_drag_visual.z_as_relative = false
	_fate_drag_visual.z_index = 260
	_fate_drag_offset = FATE_DRAG_CURSOR_OFFSET
	_fate_drag_swing_angle = 0.0
	_fate_drag_swing_prev_global = global_pos
	set_process(true)
	_update_drag_visual(global_pos)


func _prepare_fate_drag_visual(card_visual: Control) -> void:
	if card_visual == null:
		return
	card_visual.visible = true
	card_visual.anchor_left = 0.0
	card_visual.anchor_top = 0.0
	card_visual.anchor_right = 0.0
	card_visual.anchor_bottom = 0.0
	card_visual.position = Vector2.ZERO
	card_visual.custom_minimum_size = Vector2(FATE_HAND_CARD_WIDTH, 252.0)
	card_visual.size = card_visual.custom_minimum_size
	card_visual.clip_contents = true
	var body: VBoxContainer = card_visual.get_child(0) as VBoxContainer
	if body == null:
		return
	for i in range(body.get_child_count() - 1, -1, -1):
		var child_node: Node = body.get_child(i)
		if child_node is Button:
			child_node.queue_free()
			continue
		if child_node is PanelContainer or child_node is HBoxContainer or child_node is Label:
			continue
		if child_node is Control:
			child_node.queue_free()


func _update_drag_visual(global_pos: Vector2) -> void:
	if _fate_drag_visual == null or not is_instance_valid(_fate_drag_visual):
		return
	_fate_drag_visual.global_position = global_pos - _fate_drag_offset
	_set_drag_hover_slot(_slot_from_global_position(global_pos))


func _fate_active_slot_shell_at(slot_index: int) -> Control:
	for node in _fate_active_slot_nodes:
		if node == null or not is_instance_valid(node):
			continue
		if int(node.get_meta("_slot_index", -1)) == slot_index:
			return node
	return null


func _start_fate_slot_placement_tween(card_id: String, slot_index: int) -> void:
	var v: Control = _fate_drag_visual
	if v == null or not is_instance_valid(v):
		_clear_drag_session()
		_refresh_fate_deck_ui("")
		return
	var slot_node: Control = _fate_active_slot_shell_at(slot_index)
	if slot_node == null:
		var res_fallback: String = _assign_card_to_active_slot(card_id, slot_index)
		_clear_drag_session()
		_refresh_fate_deck_ui(res_fallback)
		return
	set_process(false)
	_fate_drag_swing_angle = 0.0
	v.rotation = 0.0
	_fate_dragging = false
	_set_hovered_hand_card(null)
	_fate_slot_placement_animating = true
	if _fate_place_tween != null and is_instance_valid(_fate_place_tween):
		_fate_place_tween.kill()
	var slot_center: Vector2 = slot_node.get_global_rect().get_center()
	var end_scale: float = FATE_ACTIVE_STRIP_CARD_WIDTH / FATE_HAND_CARD_WIDTH
	var sz: Vector2 = Vector2(FATE_HAND_CARD_WIDTH, FATE_HAND_CARD_HEIGHT)
	var end_scale_v: Vector2 = Vector2(end_scale, end_scale)
	var end_pos: Vector2 = slot_center - (sz * end_scale_v) * 0.5
	var tw: Tween = create_tween()
	_fate_place_tween = tw
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(v, "global_position", end_pos, FATE_PLACE_IN_SLOT_DURATION)
	tw.tween_property(v, "scale", end_scale_v, FATE_PLACE_IN_SLOT_DURATION)
	tw.tween_property(v, "modulate", Color(1.0, 1.0, 1.0, 1.0), FATE_PLACE_IN_SLOT_DURATION)
	tw.chain().tween_callback(_finish_fate_slot_placement.bind(card_id, slot_index))


func _finish_fate_slot_placement(card_id: String, slot_index: int) -> void:
	_fate_slot_placement_animating = false
	_fate_place_tween = null
	var result_line: String = _assign_card_to_active_slot(card_id, slot_index)
	_clear_drag_session()
	_refresh_fate_deck_ui(result_line)


func _finish_drag(global_pos: Vector2) -> void:
	if not _fate_dragging:
		return
	if _fate_slot_placement_animating:
		return
	var target_slot: int = _slot_from_global_position(global_pos)
	var dragged_id: String = _fate_drag_card_id.strip_edges()
	if target_slot == -1:
		_clear_drag_session()
		_refresh_fate_deck_ui("")
		return
	if dragged_id == "":
		_clear_drag_session()
		_refresh_fate_deck_ui("")
		return
	var state_pre: Dictionary = _read_state()
	var owned_pre: Array[String] = _normalize_owned_card_ids(state_pre.get("cards_owned_ids", []))
	if not owned_pre.has(dragged_id):
		_clear_drag_session()
		_refresh_fate_deck_ui("Card locked.")
		return
	_start_fate_slot_placement_tween(dragged_id, target_slot)


func _is_fate_deck_open() -> bool:
	return _fate_deck_panel != null and is_instance_valid(_fate_deck_panel) and _fate_deck_panel.visible


func _input(event: InputEvent) -> void:
	if not _is_fate_deck_open():
		return
	if _fate_slot_placement_animating:
		return
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _fate_dragging and mm != null:
			_update_drag_visual(mm.global_position)
		elif mm != null:
			_update_hand_hover(mm.global_position)
			if _fate_drag_candidate_panel != null:
				if mm.global_position.distance_to(_fate_drag_candidate_press_global) >= FATE_DRAG_START_DISTANCE:
					_begin_drag_from_candidate(mm.global_position)
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or mb.is_echo():
			return
		if mb.pressed:
			_update_hand_hover(mb.global_position)
		if mb.pressed and not _fate_dragging and (_fate_drag_candidate_panel == null or not is_instance_valid(_fate_drag_candidate_panel)):
			var picked: Control = _pick_top_hand_card_at(mb.global_position)
			if picked != null:
				var local_on_card: Vector2 = picked.get_global_transform_with_canvas().affine_inverse() * mb.global_position
				if local_on_card.y >= (picked.size.y - 46.0):
					return
				_fate_drag_candidate_panel = picked
				var card_meta: Variant = picked.get_meta("_card_data", {})
				var card_dict: Dictionary = card_meta if card_meta is Dictionary else {}
				_fate_drag_candidate_card_id = str(card_dict.get("id", "")).strip_edges()
				_fate_drag_candidate_owned = bool(picked.get_meta("_card_owned", false))
				_fate_drag_candidate_active = bool(picked.get_meta("_card_active", false))
				_fate_drag_candidate_press_global = mb.global_position
				get_viewport().set_input_as_handled()
				return
		if not mb.pressed:
			if _fate_dragging:
				_finish_drag(mb.global_position)
				return
			if _fate_drag_candidate_panel != null and is_instance_valid(_fate_drag_candidate_panel):
				var card_meta: Variant = _fate_drag_candidate_panel.get_meta("_card_data", {})
				var card: Dictionary = card_meta if card_meta is Dictionary else {}
				_show_fate_preview(card, _fate_drag_candidate_owned, _fate_drag_candidate_active)
			_fate_drag_candidate_panel = null
			_fate_drag_candidate_card_id = ""
			_fate_drag_candidate_owned = false
			_fate_drag_candidate_active = false
			_fate_drag_candidate_press_global = Vector2.ZERO



func _refresh_fate_deck_ui(feedback_line: String) -> void:
	if _fate_deck_panel == null or _fate_card_grid == null:
		return
	if _fate_dragging:
		_clear_drag_session()
	var state: Dictionary = _read_state()
	var owned_ids: Array[String] = _normalize_owned_card_ids(state.get("cards_owned_ids", []))
	var active_slots: Array[String] = _normalize_active_slots(
		state.get("cards_active_slots", []),
		owned_ids,
		state.get("cards_active_ids", [])
	)
	var active_ids: Array[String] = _compact_active_slots(active_slots)
	state["cards_owned_ids"] = owned_ids
	state["cards_active_slots"] = active_slots
	state["cards_active_ids"] = active_ids
	_write_state(state, false)

	var chips: int = int(state.get("chips", 0))
	var titles_text: String = _format_titles(state)
	var active_text: String = _format_active_cards_line(state)
	if _fate_summary_label != null:
		_fate_summary_label.text = (
			"Chips: %d   |   Active: %d / %d\n"
			+ "Titles: %s\n"
			+ "Select up to %d cards. Portrait-top layout mirrors tactical card read flow."
		) % [
			chips,
			active_ids.size(),
			FateCardCatalog.MAX_ACTIVE_CARDS,
			titles_text,
			FateCardCatalog.MAX_ACTIVE_CARDS
		]
	if _fate_feedback_label != null:
		_fate_feedback_label.text = feedback_line.strip_edges() if feedback_line.strip_edges() != "" else "Current active cards: %s" % active_text
	if _fate_draw_button != null:
		_fate_draw_button.disabled = chips < maxi(1, FateCardCatalog.DRAW_CHIP_COST)
	if _fate_cash_button != null:
		_fate_cash_button.disabled = int(state.get("chips", 0)) < maxi(1, chips_per_title_unlock)
	_rebuild_active_cards_strip(active_slots)

	_set_hovered_hand_card(null)

	var cards: Array[Dictionary] = FateCardCatalog.get_all_cards()
	cards.sort_custom(func(a, b):
		var rarity_a: int = FateCardCatalog.get_rarity_rank(str(a.get("rarity", "")))
		var rarity_b: int = FateCardCatalog.get_rarity_rank(str(b.get("rarity", "")))
		if rarity_a == rarity_b:
			return str(a.get("name", "")).nocasecmp_to(str(b.get("name", ""))) < 0
		return rarity_a > rarity_b
	)

	_fate_hand_cards_data.clear()
	for card in cards:
		var cid: String = str(card.get("id", "")).strip_edges()
		var owned: bool = owned_ids.has(cid)
		var active: bool = active_slots.has(cid)
		_fate_hand_cards_data.append({
			"card": card,
			"owned": owned,
			"active": active
		})

	var page_count: int = _get_fate_hand_page_count()
	_fate_hand_page = clampi(_fate_hand_page, 0, maxi(0, page_count - 1))
	_render_fate_hand_page()


func _build_fate_card_widget(
	card: Dictionary,
	owned: bool,
	active: bool,
	preview_mode: bool = false,
	active_strip_slot: int = -1
) -> Control:
	var is_active_strip_mini: bool = (active_strip_slot >= 0)
	var strip_has_card: bool = str(card.get("id", "")).strip_edges() != ""

	var panel_w: float
	var panel_h: float
	var portrait_min_h: float
	var body_separation: int
	var panel_style_radius: int
	var panel_pad_h: int
	var panel_pad_v: int
	var portrait_frame_radius: int
	var border_px: int
	var chip_font: int
	var name_font: int
	var summary_font: int
	var portrait_edge: float
	var chip_row_separation: int = 6

	if is_active_strip_mini:
		# Lay out at full hand size (282×320), then uniform-scale inside SubViewport so proportions match the hand exactly.
		panel_w = FATE_HAND_CARD_WIDTH
		panel_h = FATE_HAND_CARD_HEIGHT
		portrait_min_h = 174.0
		body_separation = 6
		panel_style_radius = 14
		panel_pad_h = 8
		panel_pad_v = 8
		portrait_frame_radius = 10
		border_px = 3 if strip_has_card and active else (2 if strip_has_card else 1)
		chip_font = 11
		name_font = 18
		summary_font = 13
		portrait_edge = 2.0
	elif preview_mode:
		panel_w = 320.0
		panel_h = 560.0
		portrait_min_h = 298.0
		body_separation = 6
		panel_style_radius = 14
		panel_pad_h = 8
		panel_pad_v = 8
		portrait_frame_radius = 10
		border_px = 3 if active else 2
		chip_font = 11
		name_font = 22
		summary_font = 16
		portrait_edge = 2.0
		chip_row_separation = 6
	else:
		panel_w = FATE_HAND_CARD_WIDTH
		panel_h = FATE_HAND_CARD_HEIGHT
		portrait_min_h = 174.0
		body_separation = 6
		panel_style_radius = 14
		panel_pad_h = 8
		panel_pad_v = 8
		portrait_frame_radius = 10
		border_px = 3 if active else 2
		chip_font = 11
		name_font = 18
		summary_font = 13
		portrait_edge = 2.0
		chip_row_separation = 6

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	if is_active_strip_mini:
		# SubViewport will clip to fixed (panel_w × panel_h); shrink so inflated child mins do not widen the strip.
		panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	else:
		panel.size = panel.custom_minimum_size
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_PASS if is_active_strip_mini else Control.MOUSE_FILTER_STOP

	var rarity: String = str(card.get("rarity", "common"))
	var rarity_color: Color = FateCardCatalog.get_rarity_color(rarity)
	var bg: Color
	if is_active_strip_mini:
		bg = Color(0.13, 0.09, 0.06, 0.98) if strip_has_card else Color(0.10, 0.075, 0.05, 0.98)
	elif owned:
		bg = Color(0.13, 0.09, 0.06, 0.98)
	else:
		bg = Color(0.08, 0.08, 0.08, 0.90)
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(bg, rarity_color, panel_style_radius, border_px, panel_pad_h, panel_pad_v)
	)

	var body: VBoxContainer = VBoxContainer.new()
	body.anchor_left = 0.0
	body.anchor_top = 0.0
	body.anchor_right = 1.0
	body.anchor_bottom = 1.0
	body.offset_left = 0.0
	body.offset_top = 0.0
	body.offset_right = 0.0
	body.offset_bottom = 0.0
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", body_separation)
	panel.add_child(body)

	var portrait_frame: PanelContainer = PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(0, int(round(portrait_min_h)))
	portrait_frame.clip_contents = true
	portrait_frame.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.06, 0.06, 0.06, 1.0),
			Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.75),
			portrait_frame_radius,
			1,
			0,
			0
		)
	)
	body.add_child(portrait_frame)

	if is_active_strip_mini and not strip_has_card:
		var empty_bg: ColorRect = ColorRect.new()
		empty_bg.anchor_left = 0.0
		empty_bg.anchor_top = 0.0
		empty_bg.anchor_right = 1.0
		empty_bg.anchor_bottom = 1.0
		empty_bg.offset_left = portrait_edge
		empty_bg.offset_top = portrait_edge
		empty_bg.offset_right = -portrait_edge
		empty_bg.offset_bottom = -portrait_edge
		empty_bg.color = Color(0.10, 0.10, 0.10, 0.95)
		portrait_frame.add_child(empty_bg)
		var empty_mark: Label = Label.new()
		empty_mark.text = "+"
		empty_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_mark.anchor_left = 0.0
		empty_mark.anchor_top = 0.0
		empty_mark.anchor_right = 1.0
		empty_mark.anchor_bottom = 1.0
		empty_mark.add_theme_font_size_override("font_size", maxi(12, 22))
		empty_mark.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45, 0.9))
		portrait_frame.add_child(empty_mark)
	else:
		var portrait_underlay: ColorRect = ColorRect.new()
		portrait_underlay.anchor_left = 0.0
		portrait_underlay.anchor_top = 0.0
		portrait_underlay.anchor_right = 1.0
		portrait_underlay.anchor_bottom = 1.0
		portrait_underlay.offset_left = portrait_edge
		portrait_underlay.offset_top = portrait_edge
		portrait_underlay.offset_right = -portrait_edge
		portrait_underlay.offset_bottom = -portrait_edge
		portrait_underlay.color = Color(0.03, 0.03, 0.03, 1.0)
		portrait_underlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_underlay.z_index = 0
		portrait_frame.add_child(portrait_underlay)
		var portrait: TextureRect = TextureRect.new()
		portrait.anchor_left = 0.0
		portrait.anchor_top = 0.0
		portrait.anchor_right = 1.0
		portrait.anchor_bottom = 1.0
		portrait.offset_left = portrait_edge
		portrait.offset_top = portrait_edge
		portrait.offset_right = -portrait_edge
		portrait.offset_bottom = -portrait_edge
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		portrait.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		portrait.texture = _load_card_portrait(card)
		portrait.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		portrait.modulate = Color(1.0, 1.0, 1.0, 1.0)
		portrait.z_index = 1
		portrait_frame.add_child(portrait)
		# Keep the portrait stack minimal and opaque; decorative overlays can mask the art if
		# they inherit an unexpected size during hand/drag layout changes.

	var chip_row: HBoxContainer = HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", chip_row_separation)
	if is_active_strip_mini:
		chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(chip_row)
	if is_active_strip_mini:
		var slot_n: int = active_strip_slot + 1
		chip_row.add_child(
			_fate_active_strip_chip_with_tip(
				str(slot_n),
				CARD_TEXT_MUTED,
				Color(0.11, 0.11, 0.11, 0.95),
				chip_font,
				"Slot %d" % slot_n
			)
		)
		if strip_has_card:
			var r_disp: String = str(rarity).strip_edges().capitalize()
			chip_row.add_child(
				_fate_active_strip_chip_with_tip(
					_fate_active_strip_rarity_letter(rarity),
					rarity_color,
					Color(0.10, 0.10, 0.10, 0.95),
					chip_font,
					"Rarity: %s" % r_disp
				)
			)
			chip_row.add_child(
				_fate_active_strip_chip_with_tip(
					"A",
					Color(0.38, 0.98, 0.67, 1.0),
					Color(0.06, 0.18, 0.11, 0.96),
					chip_font,
					"Active in deck"
				)
			)
		else:
			chip_row.add_child(
				_fate_active_strip_chip_with_tip(
					"—",
					CARD_TEXT_MUTED,
					Color(0.12, 0.12, 0.12, 0.96),
					chip_font,
					"Empty slot"
				)
			)
	else:
		chip_row.add_child(_build_card_chip(rarity.to_upper(), rarity_color, Color(0.10, 0.10, 0.10, 0.95), chip_font, false))
		if active:
			chip_row.add_child(
				_build_card_chip(
					"ACTIVE",
					Color(0.38, 0.98, 0.67, 1.0),
					Color(0.06, 0.18, 0.11, 0.96),
					chip_font,
					false
				)
			)
		elif not owned:
			chip_row.add_child(_build_card_chip("LOCKED", CARD_TEXT_MUTED, Color(0.12, 0.12, 0.12, 0.96), chip_font, false))

	var name_label: Label = Label.new()
	if is_active_strip_mini:
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", name_font)
	name_label.add_theme_color_override("font_color", CARD_TEXT)
	name_label.add_theme_constant_override("outline_size", 4 if preview_mode else 3)
	name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	if is_active_strip_mini and not strip_has_card:
		name_label.text = "EMPTY SLOT"
	else:
		name_label.text = str(card.get("name", "Unknown Card")).to_upper()
	if is_active_strip_mini:
		name_label.max_lines_visible = 2
	body.add_child(name_label)
	if strip_has_card or not is_active_strip_mini:
		var accent_rule: ColorRect = ColorRect.new()
		accent_rule.custom_minimum_size = Vector2(0.0, 2.0 if not preview_mode else 3.0)
		accent_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		accent_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		accent_rule.color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.32 if owned or active else 0.20)
		body.add_child(accent_rule)

	var summary_label: Label = Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", summary_font)
	summary_label.add_theme_color_override("font_color", CARD_TEXT_MUTED)
	if is_active_strip_mini:
		summary_label.max_lines_visible = 4
	if is_active_strip_mini and not strip_has_card:
		summary_label.text = "Drag a card here from your hand."
	else:
		summary_label.text = str(card.get("summary", ""))
	body.add_child(summary_label)

	if is_active_strip_mini:
		# Same vertical rhythm as hand (spacer + 34px action band) without a real button.
		var strip_spacer: Control = Control.new()
		strip_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(strip_spacer)
		var strip_action_band: Control = Control.new()
		strip_action_band.custom_minimum_size = Vector2(0, 34)
		strip_action_band.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		body.add_child(strip_action_band)

	if not preview_mode and not is_active_strip_mini:
		var spacer: Control = Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(spacer)
		var action_btn: Button = Button.new()
		action_btn.custom_minimum_size = Vector2(0, 34)
		action_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(action_btn, 17)
		var card_id: String = str(card.get("id", "")).strip_edges()
		if not owned:
			action_btn.text = "Locked"
			action_btn.disabled = true
		elif active:
			action_btn.text = "Active"
			action_btn.pressed.connect(_on_fate_card_button_pressed.bind(card_id))
		else:
			action_btn.text = "Set Active"
			action_btn.pressed.connect(_on_fate_card_button_pressed.bind(card_id))
		body.add_child(action_btn)

	var desc: String = str(card.get("description", "")).strip_edges()
	if desc != "":
		panel.tooltip_text = desc
	if not preview_mode and not is_active_strip_mini:
		panel.set_meta("_card_data", card.duplicate(true))
		panel.set_meta("_card_owned", owned)
		panel.set_meta("_card_active", active)

	if is_active_strip_mini:
		var strip_scale: float = FATE_ACTIVE_STRIP_CARD_WIDTH / FATE_HAND_CARD_WIDTH
		var w_i: int = maxi(2, int(round(FATE_ACTIVE_STRIP_CARD_WIDTH)))
		var h_i: int = maxi(2, FATE_ACTIVE_STRIP_SHELL_H)
		var vp: SubViewport = SubViewport.new()
		vp.transparent_bg = true
		vp.size = Vector2i(w_i, h_i)
		var vp_host: SubViewportContainer = SubViewportContainer.new()
		vp_host.stretch = false
		vp_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vp_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vp_host.set_anchors_preset(Control.PRESET_FULL_RECT)
		vp_host.offset_left = 0.0
		vp_host.offset_top = 0.0
		vp_host.offset_right = 0.0
		vp_host.offset_bottom = 0.0
		var shell: Control = Control.new()
		shell.clip_contents = false
		shell.custom_minimum_size = Vector2(float(w_i), float(h_i))
		shell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		shell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		shell.mouse_filter = Control.MOUSE_FILTER_STOP
		shell.set_meta("_slot_index", active_strip_slot)
		shell.set_meta("_slot_border", rarity_color if strip_has_card else CARD_BORDER_SOFT)
		shell.set_meta("_slot_card_id", str(card.get("id", "")).strip_edges() if strip_has_card else "")
		shell.gui_input.connect(_on_fate_active_slot_gui_input.bind(shell))
		if strip_has_card:
			shell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			shell.mouse_entered.connect(_on_fate_active_slot_mouse_entered.bind(shell))
			shell.mouse_exited.connect(_on_fate_active_slot_mouse_exited.bind(shell))
		if panel.tooltip_text.strip_edges() != "":
			shell.tooltip_text = "%s\nLeft-click to preview. Right-click to remove from active deck." % panel.tooltip_text if strip_has_card else panel.tooltip_text
		panel.position = Vector2.ZERO
		panel.pivot_offset = Vector2.ZERO
		panel.custom_minimum_size = Vector2(FATE_HAND_CARD_WIDTH, FATE_HAND_CARD_HEIGHT)
		panel.size = panel.custom_minimum_size
		panel.scale = Vector2(strip_scale, strip_scale)
		vp.add_child(panel)
		vp_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vp_host.add_child(vp)
		shell.add_child(vp_host)
		var rescale_strip_card := func () -> void:
			if not is_instance_valid(panel) or not is_instance_valid(vp) or not is_instance_valid(vp_host):
				return
			vp_host.stretch = false
			vp.size = Vector2i(w_i, h_i)
			panel.custom_minimum_size = Vector2(FATE_HAND_CARD_WIDTH, FATE_HAND_CARD_HEIGHT)
			panel.size = panel.custom_minimum_size
			panel.scale = Vector2(strip_scale, strip_scale)
		shell.ready.connect(rescale_strip_card)
		return shell

	return panel


func _on_fate_card_button_pressed(card_id: String) -> void:
	_refresh_fate_deck_ui(_toggle_fate_card(card_id))


func _load_texture_safe(path: String) -> Texture2D:
	var clean_path: String = path.strip_edges()
	if clean_path == "":
		return null
	if ResourceLoader.exists(clean_path):
		var res: Resource = load(clean_path)
		if res is Texture2D:
			return res as Texture2D
	return null


func _load_card_portrait(card: Dictionary) -> Texture2D:
	var resolved_card: Dictionary = _resolve_fate_card_portrait_card(card)
	var path: String = str(resolved_card.get("portrait_path", "")).strip_edges()
	var loaded: Texture2D = _load_texture_safe(path)
	if loaded != null:
		return loaded
	return _fate_card_fallback_portrait


func _resolve_fate_card_portrait_card(card: Dictionary) -> Dictionary:
	var direct_path: String = str(card.get("portrait_path", "")).strip_edges()
	if direct_path != "":
		return card
	var wanted_id: String = str(card.get("id", "")).strip_edges().to_lower()
	if wanted_id != "":
		var by_id: Dictionary = FateCardCatalog.get_card(wanted_id)
		if not by_id.is_empty():
			return by_id
	var wanted_name: String = str(card.get("name", "")).strip_edges().to_lower()
	if wanted_name != "":
		for card_any in FateCardCatalog.get_all_cards():
			var catalog_card: Dictionary = card_any
			if str(catalog_card.get("name", "")).strip_edges().to_lower() == wanted_name:
				return catalog_card.duplicate(true)
	return card


func _load_texture_from_source_image(path: String) -> Texture2D:
	if path == "":
		return null
	var img := Image.new()
	var err: Error = img.load(path)
	if err != OK:
		return null
	return _image_to_dark_matte_texture(img)


func _load_texture_from_resource_image(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res is Texture2D:
		return _texture_to_dark_matte_texture(res as Texture2D)
	return null


func _texture_to_dark_matte_texture(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null:
		return tex
	if img.get_width() <= 0 or img.get_height() <= 0:
		return tex
	var rebuilt: Texture2D = _image_to_dark_matte_texture(img)
	return rebuilt if rebuilt != null else tex


func _image_to_dark_matte_texture(source_img: Image) -> Texture2D:
	if source_img == null:
		return null
	if source_img.get_width() <= 0 or source_img.get_height() <= 0:
		return null
	# Composite alpha onto dark matte to prevent white portrait wash/halos.
	var img := source_img.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var matte := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	matte.fill(Color(0.03, 0.03, 0.03, 1.0))
	matte.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i.ZERO)
	return ImageTexture.create_from_image(matte)


func _on_parent_ui_resized() -> void:
	if _fate_deck_panel == null or _fate_card_grid == null:
		return
	_layout_fate_hand_cards()


func _get_fate_hand_page_count() -> int:
	if _fate_hand_cards_data.is_empty():
		return 1
	return maxi(1, int(ceil(float(_fate_hand_cards_data.size()) / float(FATE_HAND_PAGE_SIZE))))


func _render_fate_hand_page() -> void:
	if _fate_card_grid == null:
		return
	for child in _fate_card_grid.get_children():
		child.queue_free()
	_set_hovered_hand_card(null)
	_clear_drag_session()

	var total_pages: int = _get_fate_hand_page_count()
	_fate_hand_page = clampi(_fate_hand_page, 0, maxi(0, total_pages - 1))
	var start_idx: int = _fate_hand_page * FATE_HAND_PAGE_SIZE
	var end_idx: int = mini(_fate_hand_cards_data.size(), start_idx + FATE_HAND_PAGE_SIZE)

	for i in range(start_idx, end_idx):
		var entry: Dictionary = _fate_hand_cards_data[i]
		var card_v: Variant = entry.get("card", {})
		var card: Dictionary = card_v if card_v is Dictionary else {}
		var owned: bool = bool(entry.get("owned", false))
		var active: bool = bool(entry.get("active", false))
		_fate_card_grid.add_child(_build_fate_card_widget(card, owned, active, false))

	if _fate_hand_page_label != null:
		_fate_hand_page_label.text = "HAND %d/%d" % [_fate_hand_page + 1, total_pages]
	if _fate_hand_prev_button != null:
		_fate_hand_prev_button.disabled = total_pages <= 1
		_fate_hand_prev_button.visible = total_pages > 1
	if _fate_hand_next_button != null:
		_fate_hand_next_button.disabled = total_pages <= 1
		_fate_hand_next_button.visible = total_pages > 1

	_on_parent_ui_resized()


func _on_fate_prev_page_pressed() -> void:
	var total_pages: int = _get_fate_hand_page_count()
	if total_pages <= 1:
		return
	_fate_hand_page = posmod(_fate_hand_page - 1, total_pages)
	_render_fate_hand_page()


func _on_fate_next_page_pressed() -> void:
	var total_pages: int = _get_fate_hand_page_count()
	if total_pages <= 1:
		return
	_fate_hand_page = posmod(_fate_hand_page + 1, total_pages)
	_render_fate_hand_page()


func _layout_fate_hand_cards() -> void:
	if _fate_card_grid == null or _fate_hand_area == null:
		return
	var cards: Array[Control] = []
	for child in _fate_card_grid.get_children():
		if child is Control:
			cards.append(child as Control)
	var count: int = cards.size()
	if count == 0:
		_fate_card_grid.custom_minimum_size = Vector2(640, 520)
		return

	var area_w: float = maxf(320.0, _fate_hand_area.size.x)
	var area_h: float = maxf(260.0, _fate_hand_area.size.y)
	var center_index: float = (float(count) - 1.0) * 0.5
	var spread: float = FATE_HAND_SPACING
	if count > 1:
		var fit_spread: float = (area_w - (FATE_HAND_MARGIN * 2.0) - FATE_HAND_CARD_WIDTH) / float(count - 1)
		spread = clampf(fit_spread, 128.0, FATE_HAND_SPACING)
	var max_curve_dist: float = absf((float(count - 1)) - center_index)
	var max_curve_offset: float = pow(max_curve_dist, 1.35) * 8.0
	var base_y_max: float = area_h - FATE_HAND_CARD_HEIGHT - max_curve_offset - 8.0
	var base_y: float = clampf(base_y_max, -10.0, 24.0)
	var hand_w: float = (float(count - 1) * spread) + FATE_HAND_CARD_WIDTH
	var start_x: float = clampf((area_w - hand_w) * 0.5, 6.0, area_w - hand_w - 6.0)
	if hand_w >= area_w - 10.0:
		start_x = 6.0
	var max_bottom: float = 0.0
	for i in range(count):
		var card: Control = cards[i]
		card.scale = Vector2.ONE
		var dist: float = float(i) - center_index
		var curve: float = absf(dist)
		var x_pos: float = start_x + (float(i) * spread)
		var y_pos: float = base_y + pow(curve, 1.35) * 8.0
		card.position = Vector2(x_pos, y_pos)
		card.rotation_degrees = clampf(dist * 3.3, -11.0, 11.0)
		card.pivot_offset = Vector2(FATE_HAND_CARD_WIDTH * 0.5, FATE_HAND_CARD_HEIGHT)
		card.z_index = i
		card.set_meta("_hand_base_pos", card.position)
		card.set_meta("_hand_base_rot", card.rotation_degrees)
		max_bottom = maxf(max_bottom, y_pos + FATE_HAND_CARD_HEIGHT + 10.0)

	var grid_w: float = maxf(area_w, hand_w + 12.0)
	var grid_h: float = maxf(area_h, max_bottom + 6.0)
	_fate_card_grid.custom_minimum_size = Vector2(grid_w, grid_h)
	_fate_card_grid.size = Vector2(grid_w, grid_h)


func _on_fate_card_hovered(card_panel: Control) -> void:
	if card_panel == null:
		return
	if _fate_dragging or _fate_slot_placement_animating:
		return
	if not card_panel.has_meta("_hand_base_pos"):
		return
	var base_pos: Vector2 = card_panel.get_meta("_hand_base_pos", card_panel.position)
	card_panel.z_index = 999
	var t: Tween = card_panel.create_tween()
	t.set_parallel(true)
	t.tween_property(card_panel, "position", base_pos + Vector2(0.0, -30.0), 0.11)
	t.tween_property(card_panel, "scale", Vector2(1.08, 1.08), 0.11)
	t.tween_property(card_panel, "rotation_degrees", 0.0, 0.11)


func _on_fate_card_unhovered(card_panel: Control) -> void:
	if card_panel == null:
		return
	if _fate_dragging or _fate_slot_placement_animating:
		return
	if not card_panel.has_meta("_hand_base_pos"):
		return
	var base_pos: Vector2 = card_panel.get_meta("_hand_base_pos", card_panel.position)
	var base_rot: float = float(card_panel.get_meta("_hand_base_rot", 0.0))
	card_panel.z_index = int(_get_child_card_index(card_panel))
	var t: Tween = card_panel.create_tween()
	t.set_parallel(true)
	t.tween_property(card_panel, "position", base_pos, 0.10)
	t.tween_property(card_panel, "scale", Vector2.ONE, 0.10)
	t.tween_property(card_panel, "rotation_degrees", base_rot, 0.10)


func _get_child_card_index(card_panel: Control) -> int:
	if _fate_card_grid == null or card_panel == null:
		return 0
	return card_panel.get_index()


func _on_fate_card_gui_input(event: InputEvent, card_panel: Control) -> void:
	if card_panel == null:
		return
	if _fate_slot_placement_animating:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or mb.is_echo():
			return
		if mb.pressed:
			_fate_drag_candidate_panel = card_panel
			var card_meta: Variant = card_panel.get_meta("_card_data", {})
			var card_dict: Dictionary = card_meta if card_meta is Dictionary else {}
			_fate_drag_candidate_card_id = str(card_dict.get("id", "")).strip_edges()
			_fate_drag_candidate_owned = bool(card_panel.get_meta("_card_owned", false))
			_fate_drag_candidate_active = bool(card_panel.get_meta("_card_active", false))
			_fate_drag_candidate_press_global = mb.global_position
			card_panel.accept_event()


func _pick_top_hand_card_at(global_pos: Vector2) -> Control:
	if _fate_card_grid == null:
		return null
	var best: Control = null
	var best_z: int = -999999
	for child in _fate_card_grid.get_children():
		if not child is Control:
			continue
		var card: Control = child as Control
		if not card.visible or not card.has_meta("_card_data"):
			continue
		var local_pos: Vector2 = card.get_global_transform_with_canvas().affine_inverse() * global_pos
		var rect: Rect2 = Rect2(Vector2.ZERO, card.size)
		if not rect.has_point(local_pos):
			continue
		var z: int = card.z_index
		if best == null or z >= best_z:
			best = card
			best_z = z
	return best


func _update_hand_hover(global_pos: Vector2) -> void:
	if _fate_dragging or _fate_slot_placement_animating:
		_set_hovered_hand_card(null)
		return
	var picked: Control = _pick_top_hand_card_at(global_pos)
	_set_hovered_hand_card(picked)


func _set_hovered_hand_card(card_panel: Control) -> void:
	if _fate_hovered_panel == card_panel:
		return
	if _fate_hovered_panel != null and is_instance_valid(_fate_hovered_panel):
		_on_fate_card_unhovered(_fate_hovered_panel)
	_fate_hovered_panel = card_panel
	if _fate_hovered_panel != null and is_instance_valid(_fate_hovered_panel):
		_on_fate_card_hovered(_fate_hovered_panel)


func _show_fate_preview(card: Dictionary, owned: bool, active: bool) -> void:
	if _fate_preview_backdrop == null or _fate_preview_panel == null or _fate_preview_host == null:
		return
	for child in _fate_preview_host.get_children():
		child.queue_free()
	var preview_card: Control = _build_fate_card_widget(card, owned, active, true)
	preview_card.anchor_left = 0.5
	preview_card.anchor_top = 0.5
	preview_card.anchor_right = 0.5
	preview_card.anchor_bottom = 0.5
	preview_card.offset_left = -170.0
	preview_card.offset_top = -280.0
	preview_card.offset_right = 170.0
	preview_card.offset_bottom = 280.0
	_fate_preview_host.add_child(preview_card)
	_fate_preview_backdrop.show()
	_fate_preview_panel.show()


func _on_fate_active_slot_gui_input(event: InputEvent, slot_root: Control) -> void:
	if slot_root == null or _fate_dragging or _fate_slot_placement_animating:
		return
	if event is not InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.is_echo():
		return
	var slot_card_id: String = str(slot_root.get_meta("_slot_card_id", "")).strip_edges()
	if slot_card_id == "":
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		var card: Dictionary = FateCardCatalog.get_card(slot_card_id)
		if not card.is_empty():
			slot_root.accept_event()
			_show_fate_preview(card, true, true)
		return
	if mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	var slot_index: int = int(slot_root.get_meta("_slot_index", -1))
	_fate_slot_placement_animating = true
	await _play_fate_active_slot_remove_feedback(slot_root)
	var result_line: String = _clear_active_slot(slot_index)
	_fate_slot_placement_animating = false
	if result_line != "":
		slot_root.accept_event()
		_refresh_fate_deck_ui(result_line)


func _build_fate_drag_visual(card: Dictionary, _owned: bool, active: bool) -> Control:
	var rank: int = FateCardCatalog.get_rarity_rank(str(card.get("rarity", "common")))
	var rarity_color: Color = FateCardCatalog.get_rarity_color(str(card.get("rarity", "common")))

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(226, 300)
	panel.size = panel.custom_minimum_size
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.11, 0.08, 0.05, 0.97),
			rarity_color if rank > 0 else CARD_BORDER_SOFT,
			10,
			2 if active else 1,
			6,
			6
		)
	)

	var portrait_underlay: ColorRect = ColorRect.new()
	portrait_underlay.anchor_left = 0.0
	portrait_underlay.anchor_top = 0.0
	portrait_underlay.anchor_right = 1.0
	portrait_underlay.anchor_bottom = 1.0
	portrait_underlay.offset_left = 2.0
	portrait_underlay.offset_top = 2.0
	portrait_underlay.offset_right = -2.0
	portrait_underlay.offset_bottom = -50.0
	portrait_underlay.color = Color(0.03, 0.03, 0.03, 1.0)
	portrait_underlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_underlay.z_index = 0
	panel.add_child(portrait_underlay)

	var portrait: TextureRect = TextureRect.new()
	portrait.anchor_left = 0.0
	portrait.anchor_top = 0.0
	portrait.anchor_right = 1.0
	portrait.anchor_bottom = 1.0
	portrait.offset_left = 2.0
	portrait.offset_top = 2.0
	portrait.offset_right = -2.0
	portrait.offset_bottom = -50.0
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	portrait.texture = _load_card_portrait(card)
	portrait.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	portrait.modulate = Color(1.0, 1.0, 1.0, 1.0)
	portrait.z_index = 1
	panel.add_child(portrait)
	# Drag visuals also keep a plain portrait stack so the ghost matches the hand card art.

	var name_label: Label = Label.new()
	name_label.anchor_left = 0.0
	name_label.anchor_top = 1.0
	name_label.anchor_right = 1.0
	name_label.anchor_bottom = 1.0
	name_label.offset_left = 6.0
	name_label.offset_top = -42.0
	name_label.offset_right = -6.0
	name_label.offset_bottom = -20.0
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", CARD_TEXT)
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	name_label.text = str(card.get("name", "Card")).to_upper()
	name_label.clip_text = true
	panel.add_child(name_label)

	return panel


func _hide_fate_preview() -> void:
	if _fate_preview_backdrop != null:
		_fate_preview_backdrop.hide()
	if _fate_preview_panel != null:
		_fate_preview_panel.hide()
	if _fate_preview_host != null:
		for child in _fate_preview_host.get_children():
			child.queue_free()


func _on_fate_preview_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not mb.is_echo():
			_hide_fate_preview()


func _rebuild_active_cards_strip(active_slots: Array[String]) -> void:
	if _fate_active_strip == null:
		return
	_fate_active_slot_nodes.clear()
	for child in _fate_active_strip.get_children():
		child.queue_free()

	for slot_index in range(FateCardCatalog.MAX_ACTIVE_CARDS):
		var slot_value: String = ""
		if slot_index < active_slots.size():
			slot_value = str(active_slots[slot_index]).strip_edges()
		var has_card: bool = slot_value != ""
		var card: Dictionary = {}
		if has_card:
			card = FateCardCatalog.get_card(slot_value)
		var slot_node: Control = _build_active_slot_widget(slot_index, card, has_card)
		_fate_active_strip.add_child(slot_node)
		_fate_active_slot_nodes.append(slot_node)
	_set_drag_hover_slot(-1)


func _build_active_slot_widget(slot_index: int, card: Dictionary, has_card: bool) -> Control:
	return _build_fate_card_widget(card, has_card, has_card, false, slot_index)


func _fate_active_strip_rarity_letter(rarity: String) -> String:
	match FateCardCatalog.get_rarity_rank(rarity):
		1:
			return "C"
		2:
			return "R"
		3:
			return "E"
		4:
			return "L"
		_:
			return "?"


func _fate_active_strip_chip_with_tip(text: String, border: Color, bg: Color, font_size: int, tip: String) -> Control:
	var chip: Control = _build_card_chip(text, border, bg, font_size, true)
	chip.tooltip_text = tip.strip_edges()
	return chip


func _build_card_chip(text: String, border: Color, bg: Color, font_size: int = 11, compact: bool = false) -> Control:
	var chip_panel: PanelContainer = PanelContainer.new()
	var chip_radius: int = 5 if compact else 8
	var chip_pad_h: int = 3 if compact else 6
	var chip_pad_v: int = 1 if compact else 2
	chip_panel.add_theme_stylebox_override("panel", _make_panel_style(bg, border, chip_radius, 1, chip_pad_h, chip_pad_v))
	var chip_label: Label = Label.new()
	chip_label.text = text
	chip_label.add_theme_font_size_override("font_size", font_size)
	chip_label.add_theme_color_override("font_color", border)
	chip_panel.add_child(chip_label)
	return chip_panel


func _build_rarity_particles_node(rarity: String, preview_mode: bool) -> CPUParticles2D:
	var rank: int = FateCardCatalog.get_rarity_rank(rarity)
	if rank < 2:
		return null
	var p: CPUParticles2D = CPUParticles2D.new()
	p.position = Vector2(142.0, 86.0) if not preview_mode else Vector2(160.0, 132.0)
	p.amount = 6 + (rank * 4)
	p.lifetime = 1.15
	p.one_shot = false
	p.explosiveness = 0.08
	p.randomness = 0.55
	p.emitting = true
	p.modulate = FateCardCatalog.get_rarity_color(rarity)
	p.z_index = 5
	p.z_as_relative = false
	return p


func _build_rarity_glow_overlay(rarity_color: Color, rarity_rank: int, preview_mode: bool) -> ColorRect:
	var glow: ColorRect = ColorRect.new()
	glow.anchor_left = 0.0
	glow.anchor_top = 0.0
	glow.anchor_right = 1.0
	glow.anchor_bottom = 1.0
	glow.offset_left = 1.0
	glow.offset_top = 1.0
	glow.offset_right = -1.0
	glow.offset_bottom = -1.0
	# Keep rarity color off the portrait art itself; border/accent already carry the color identity.
	glow.color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return glow


func _add_rarity_sheen_animation(portrait_frame: Control, rarity_rank: int, preview_mode: bool) -> void:
	if portrait_frame == null or rarity_rank < 1:
		return
	var stripe: ColorRect = ColorRect.new()
	var stripe_alpha: float = clampf(0.05 + (0.015 * float(rarity_rank)), 0.05, 0.12)
	stripe.color = Color(1.0, 1.0, 1.0, stripe_alpha)
	stripe.custom_minimum_size = Vector2(44.0 if not preview_mode else 58.0, 360.0 if not preview_mode else 420.0)
	stripe.size = stripe.custom_minimum_size
	stripe.position = Vector2(-88.0, -64.0)
	stripe.rotation_degrees = 18.0
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	stripe.material = mat
	portrait_frame.add_child(stripe)

	var travel_width: float = 420.0 if not preview_mode else 560.0
	var sweep_time: float = clampf(0.78 - (0.06 * float(rarity_rank)), 0.5, 0.78)
	var pause_time: float = clampf(3.3 - (0.35 * float(rarity_rank)), 1.7, 3.3)
	var tw: Tween = stripe.create_tween()
	tw.set_loops()
	tw.tween_property(stripe, "position:x", travel_width, sweep_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(pause_time)
	tw.tween_property(stripe, "position:x", -88.0, 0.01)


func _build_fate_card_chrome_layer(rarity_color: Color, active: bool, preview_mode: bool, dimmed: bool) -> Control:
	var chrome: Control = Control.new()
	chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	chrome.offset_left = 0.0
	chrome.offset_top = 0.0
	chrome.offset_right = 0.0
	chrome.offset_bottom = 0.0
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_alpha: float = 0.20 if active else 0.14
	if preview_mode:
		top_alpha += 0.04
	if dimmed:
		top_alpha *= 0.45

	var backdrop: TextureRect = TextureRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.offset_left = 1.0
	backdrop.offset_top = 1.0
	backdrop.offset_right = -1.0
	backdrop.offset_bottom = -1.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.texture = _make_fate_vertical_gradient_texture(
		Color(rarity_color.r, rarity_color.g, rarity_color.b, top_alpha),
		Color(0.0, 0.0, 0.0, 0.03),
		Color(0.0, 0.0, 0.0, 0.18),
		8,
		256
	)
	chrome.add_child(backdrop)

	var crown: TextureRect = TextureRect.new()
	crown.anchor_left = 0.0
	crown.anchor_top = 0.0
	crown.anchor_right = 1.0
	crown.anchor_bottom = 0.0
	crown.offset_left = 12.0
	crown.offset_top = 8.0
	crown.offset_right = -12.0
	crown.offset_bottom = 52.0 if not preview_mode else 68.0
	crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crown.texture = _make_fate_vertical_gradient_texture(
		Color(1.0, 1.0, 1.0, 0.08 if not dimmed else 0.04),
		Color(1.0, 1.0, 1.0, 0.02),
		Color(1.0, 1.0, 1.0, 0.0),
		8,
		88
	)
	chrome.add_child(crown)

	_add_fate_corner_trim(
		chrome,
		rarity_color,
		9.0 if preview_mode else 7.0,
		24.0 if preview_mode else 18.0,
		2.0,
		0.48 if dimmed else 0.64
	)
	return chrome


func _build_fate_rarity_sigil(rarity: String, rarity_color: Color, preview_mode: bool) -> Control:
	var sigil_root: Control = Control.new()
	sigil_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	sigil_root.offset_left = 0.0
	sigil_root.offset_top = 0.0
	sigil_root.offset_right = 0.0
	sigil_root.offset_bottom = 0.0
	sigil_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sigil: PanelContainer = PanelContainer.new()
	var sigil_w: float = 38.0 if preview_mode else 34.0
	var sigil_h: float = 28.0 if preview_mode else 24.0
	sigil.anchor_left = 1.0
	sigil.anchor_top = 0.0
	sigil.anchor_right = 1.0
	sigil.anchor_bottom = 0.0
	sigil.offset_left = -sigil_w - 10.0
	sigil.offset_top = 10.0
	sigil.offset_right = -10.0
	sigil.offset_bottom = 10.0 + sigil_h
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sigil.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.09, 0.07, 0.05, 0.94), Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.92), 8, 2, 5, 3)
	)

	var sigil_label: Label = Label.new()
	sigil_label.text = _fate_active_strip_rarity_letter(rarity)
	sigil_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sigil_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sigil_label.add_theme_font_size_override("font_size", 14 if preview_mode else 12)
	sigil_label.add_theme_constant_override("outline_size", 2)
	sigil_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	sigil_label.add_theme_color_override("font_color", rarity_color)
	sigil.add_child(sigil_label)
	sigil_root.add_child(sigil)
	return sigil_root


func _add_fate_corner_trim(target: Control, rarity_color: Color, inset: float, segment_length: float, thickness: float, alpha: float) -> void:
	if target == null:
		return
	var trim_color: Color = Color(rarity_color.r, rarity_color.g, rarity_color.b, alpha)
	var top_left_h: ColorRect = ColorRect.new()
	top_left_h.anchor_left = 0.0
	top_left_h.anchor_right = 0.0
	top_left_h.anchor_top = 0.0
	top_left_h.anchor_bottom = 0.0
	top_left_h.offset_left = inset
	top_left_h.offset_top = inset
	top_left_h.offset_right = inset + segment_length
	top_left_h.offset_bottom = inset + thickness
	top_left_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left_h.color = trim_color
	target.add_child(top_left_h)

	var top_left_v: ColorRect = ColorRect.new()
	top_left_v.anchor_left = 0.0
	top_left_v.anchor_right = 0.0
	top_left_v.anchor_top = 0.0
	top_left_v.anchor_bottom = 0.0
	top_left_v.offset_left = inset
	top_left_v.offset_top = inset
	top_left_v.offset_right = inset + thickness
	top_left_v.offset_bottom = inset + segment_length
	top_left_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left_v.color = trim_color
	target.add_child(top_left_v)

	var top_right_h: ColorRect = ColorRect.new()
	top_right_h.anchor_left = 1.0
	top_right_h.anchor_right = 1.0
	top_right_h.anchor_top = 0.0
	top_right_h.anchor_bottom = 0.0
	top_right_h.offset_left = -inset - segment_length
	top_right_h.offset_top = inset
	top_right_h.offset_right = -inset
	top_right_h.offset_bottom = inset + thickness
	top_right_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_right_h.color = trim_color
	target.add_child(top_right_h)

	var top_right_v: ColorRect = ColorRect.new()
	top_right_v.anchor_left = 1.0
	top_right_v.anchor_right = 1.0
	top_right_v.anchor_top = 0.0
	top_right_v.anchor_bottom = 0.0
	top_right_v.offset_left = -inset - thickness
	top_right_v.offset_top = inset
	top_right_v.offset_right = -inset
	top_right_v.offset_bottom = inset + segment_length
	top_right_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_right_v.color = trim_color
	target.add_child(top_right_v)

	var bottom_left_h: ColorRect = ColorRect.new()
	bottom_left_h.anchor_left = 0.0
	bottom_left_h.anchor_right = 0.0
	bottom_left_h.anchor_top = 1.0
	bottom_left_h.anchor_bottom = 1.0
	bottom_left_h.offset_left = inset
	bottom_left_h.offset_top = -inset - thickness
	bottom_left_h.offset_right = inset + segment_length
	bottom_left_h.offset_bottom = -inset
	bottom_left_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_left_h.color = trim_color
	target.add_child(bottom_left_h)

	var bottom_left_v: ColorRect = ColorRect.new()
	bottom_left_v.anchor_left = 0.0
	bottom_left_v.anchor_right = 0.0
	bottom_left_v.anchor_top = 1.0
	bottom_left_v.anchor_bottom = 1.0
	bottom_left_v.offset_left = inset
	bottom_left_v.offset_top = -inset - segment_length
	bottom_left_v.offset_right = inset + thickness
	bottom_left_v.offset_bottom = -inset
	bottom_left_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_left_v.color = trim_color
	target.add_child(bottom_left_v)

	var bottom_right_h: ColorRect = ColorRect.new()
	bottom_right_h.anchor_left = 1.0
	bottom_right_h.anchor_right = 1.0
	bottom_right_h.anchor_top = 1.0
	bottom_right_h.anchor_bottom = 1.0
	bottom_right_h.offset_left = -inset - segment_length
	bottom_right_h.offset_top = -inset - thickness
	bottom_right_h.offset_right = -inset
	bottom_right_h.offset_bottom = -inset
	bottom_right_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_right_h.color = trim_color
	target.add_child(bottom_right_h)

	var bottom_right_v: ColorRect = ColorRect.new()
	bottom_right_v.anchor_left = 1.0
	bottom_right_v.anchor_right = 1.0
	bottom_right_v.anchor_top = 1.0
	bottom_right_v.anchor_bottom = 1.0
	bottom_right_v.offset_left = -inset - thickness
	bottom_right_v.offset_top = -inset - segment_length
	bottom_right_v.offset_right = -inset
	bottom_right_v.offset_bottom = -inset
	bottom_right_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_right_v.color = trim_color
	target.add_child(bottom_right_v)


func _make_fate_vertical_gradient_texture(top: Color, middle: Color, bottom: Color, width: int = 8, height: int = 256) -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.add_point(0.0, top)
	gradient.add_point(0.42, middle)
	gradient.add_point(1.0, bottom)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.width = width
	texture.height = height
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.gradient = gradient
	return texture


func _make_panel_style(
	bg: Color,
	border: Color,
	radius: int = 12,
	border_px: int = 2,
	pad_h: int = 8,
	pad_v: int = 8
) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_px)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


func _make_button_style(
	bg: Color,
	border: Color,
	radius: int = 10,
	border_px: int = 2,
	pad_h: int = 10,
	pad_v: int = 7
) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_px)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


func _style_button(btn: Button, font_size: int = 18) -> void:
	if btn == null:
		return
	btn.add_theme_stylebox_override("normal", _make_button_style(CARD_BUTTON_BG, CARD_BORDER_SOFT))
	btn.add_theme_stylebox_override("hover", _make_button_style(CARD_BUTTON_HOVER, CARD_BORDER))
	btn.add_theme_stylebox_override("pressed", _make_button_style(CARD_BUTTON_PRESSED, CARD_BORDER))
	btn.add_theme_stylebox_override("focus", _make_button_style(CARD_BUTTON_HOVER, CARD_BORDER))
	btn.add_theme_stylebox_override("disabled", _make_button_style(Color(0.20, 0.20, 0.20, 0.94), Color(0.36, 0.36, 0.36, 0.90)))
	btn.add_theme_color_override("font_color", CARD_TEXT)
	btn.add_theme_color_override("font_disabled_color", Color(0.72, 0.72, 0.72, 0.75))
	btn.add_theme_font_size_override("font_size", font_size)
