extends Panel

const _CampUiSkin = preload("res://Scripts/UI/CampUiSkin.gd")

@onready var enclosure: Control = $EnclosureArea
@onready var close_btn: Button = $CloseRanchButton
@onready var shake_root: Control = get_node_or_null("ShakeRoot") if has_node("ShakeRoot") else enclosure

# --- NEW REFERENCES ---
@onready var favorite_label: Label = get_node_or_null("FavoriteDragonLabel")
# Debug Buttons
@onready var debug_anger_btn: Button = get_node_or_null("DebugMorgraPanel/BtnAnger")
@onready var debug_neutral_btn: Button = get_node_or_null("DebugMorgraPanel/BtnNeutral")
@onready var debug_adore_btn: Button = get_node_or_null("DebugMorgraPanel/BtnAdore")
@onready var debug_reset_btn: Button = get_node_or_null("DebugMorgraPanel/BtnReset")

# --- INFO CARD UI ---
@onready var info_card: Control = $DragonInfoCard
@onready var info_card_scroll: ScrollContainer = get_node_or_null("DragonInfoCard/InfoCardColumn/InfoCardScroll") as ScrollContainer
@onready var name_row_panel: PanelContainer = get_node_or_null("DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/NameRowPanel") as PanelContainer
@onready var identity_plate: PanelContainer = get_node_or_null("DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/IdentityPlate") as PanelContainer
@onready var growth_plate: PanelContainer = get_node_or_null("DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/GrowthPlate") as PanelContainer
@onready var stats_plate: PanelContainer = get_node_or_null("DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/StatsPlate") as PanelContainer
@onready var care_plate: PanelContainer = get_node_or_null("DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/CarePlate") as PanelContainer
@onready var training_plate: PanelContainer = get_node_or_null("DragonInfoCard/InfoCardColumn/TrainingPlate") as PanelContainer
@onready var name_input: LineEdit = $DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/NameRowPanel/NameRowMargin/HBoxContainer/NameInput
@onready var save_name_btn: Button = $DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/NameRowPanel/NameRowMargin/HBoxContainer/SaveNameBtn
@onready var details_label: RichTextLabel = $DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/IdentityPlate/IdentityMargin/IdentityBlock/DetailsLabel
@onready var traits_label: RichTextLabel = $DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/IdentityPlate/IdentityMargin/IdentityBlock/TraitsLabel
@onready var stats_section_header: Label = get_node_or_null("DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/StatsPlate/StatsMargin/StatsVBox/StatsSectionHeader")
@onready var care_actions_header: Label = get_node_or_null("DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/CarePlate/CareMargin/CareVBox/CareActionsHeader")
@onready var growth_section: VBoxContainer = get_node_or_null("DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/GrowthPlate/GrowthMargin/GrowthSection")
@onready var growth_section_header: Label = get_node_or_null("DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/GrowthPlate/GrowthMargin/GrowthSection/GrowthSectionHeader")
@onready var dragon_growth_bar: ProgressBar = get_node_or_null("DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/GrowthPlate/GrowthMargin/GrowthSection/DragonGrowthBar")
@onready var growth_fraction_label: Label = get_node_or_null("DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/GrowthPlate/GrowthMargin/GrowthSection/GrowthFractionLabel")
@onready var happiness_bar_label: Label = get_node_or_null("DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/GrowthPlate/GrowthMargin/GrowthSection/HappinessBarLabel")
@onready var dragon_happiness_bar: ProgressBar = get_node_or_null("DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/GrowthPlate/GrowthMargin/GrowthSection/DragonHappinessBar")
@onready var happiness_mood_label: Label = get_node_or_null("DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/GrowthPlate/GrowthMargin/GrowthSection/HappinessMoodLabel")
@onready var growth_bonus_label: RichTextLabel = get_node_or_null("DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/GrowthPlate/GrowthMargin/GrowthSection/GrowthBonusLabel")
@onready var feed_btn: Button = $DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/CarePlate/CareMargin/CareVBox/CareActionsRow/FeedButton
@onready var close_card_btn: Button = $DragonInfoCard/InfoCardColumn/CloseCardBtn
@onready var dragon_stats_popup: Panel = get_node_or_null("DragonStatsPopup") as Panel
@onready var open_dragon_stats_btn: Button = get_node_or_null("DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/StatsPlate/StatsMargin/StatsVBox/OpenDragonStatsBtn") as Button
@onready var close_dragon_stats_btn: Button = get_node_or_null("DragonStatsPopup/PopupVBox/StatsPopupHeader/CloseDragonStatsBtn") as Button
@onready var dragon_stats_popup_title: Label = get_node_or_null("DragonStatsPopup/PopupVBox/StatsPopupHeader/DragonStatsPopupTitle") as Label
@onready var stats_popup_scroll: ScrollContainer = get_node_or_null("DragonStatsPopup/PopupVBox/StatsPopupScroll") as ScrollContainer
@onready var stats_popup_header: HBoxContainer = get_node_or_null("DragonStatsPopup/PopupVBox/StatsPopupHeader") as HBoxContainer
@onready var stats_popup_resize_grip: Control = get_node_or_null("DragonStatsPopup/ResizeGrip") as Control
@onready var stats_dossier_mini: VBoxContainer = get_node_or_null("DragonStatsPopup/PopupVBox/StatsPopupScroll/StatsDossierMini") as VBoxContainer

var _dragon_stats_dossier_built: bool = false
var _dossier_profile_slots: Dictionary = {}
var _dossier_stat_cells: Dictionary = {}
var _dossier_ability_name_label: Label
var _dossier_pet_value_label: Label

## Stats popup dossier — typography & row scale (keep in sync with _ranch_refresh_stats_dossier).
const RANCH_DOSSIER_FONT_SECTION := 22
const RANCH_DOSSIER_FONT_PROFILE_CAPTION := 17
const RANCH_DOSSIER_FONT_PROFILE_VALUE := 21
const RANCH_DOSSIER_FONT_STAT := 21
const RANCH_DOSSIER_FONT_ABILITY := 19
const RANCH_DOSSIER_FONT_PET_TITLE := 18
const RANCH_DOSSIER_FONT_PET_VALUE := 19
const RANCH_DOSSIER_PROFILE_CHIP_H := 42.0
const RANCH_DOSSIER_PROFILE_BLOCK_MIN_H := 92.0
const RANCH_DOSSIER_STAT_CELL_MIN_H := 112.0
const RANCH_DOSSIER_STAT_CHIP := Vector2(64.0, 38.0)
const RANCH_DOSSIER_BAR_H := 22.0
const RANCH_DOSSIER_FULL_ROW_MIN_H := 64.0
const RANCH_DOSSIER_PET_CHIP := Vector2(84.0, 38.0)
const RANCH_DOSSIER_UI_VERSION := 3
const DRAGON_STATS_POPUP_MIN_SIZE := Vector2(400, 280)

var _ranch_dossier_ui_version_applied: int = -1
var _dsp_dragging: bool = false
var _dsp_drag_ofs: Vector2 = Vector2.ZERO
var _dsp_resizing: bool = false
var _dsp_resize_start_mouse: Vector2 = Vector2.ZERO
var _dsp_resize_start_size: Vector2 = Vector2.ZERO

@onready var parent_a_sprite = $BreedPanel/ParentABtn/Sprite
@onready var parent_b_sprite = $BreedPanel/ParentBBtn/Sprite

const SOCIAL_INTERACTION_MIN_DELAY: float = 4.0
const SOCIAL_INTERACTION_MAX_DELAY: float = 8.0
const SOCIAL_PAIR_COOLDOWN: float = 12.0
const SOCIAL_MIN_DISTANCE_BIAS: float = 420.0

var social_interaction_timer: float = 0.0
var social_pair_cooldowns: Dictionary = {}
var is_social_animating: bool = false

var breed_preview_fx_root: Control
var breed_prediction_backplate: ColorRect
var breed_compat_bar_bg: ColorRect
var breed_compat_bar_fill: ColorRect
var breed_compat_value_label: Label
var breed_mutation_label: RichTextLabel
var breed_resonance_glow: ColorRect
var breed_resonance_ring: ColorRect

var breed_parent_a_tween: Tween
var breed_parent_b_tween: Tween
var breed_resonance_tween: Tween
var breed_confirm_tween: Tween

@onready var training_status_block: VBoxContainer = get_node_or_null("DragonInfoCard/InfoCardColumn/TrainingPlate/TrainingMargin/TrainingVBox/TrainingStatusBlock")
@onready var training_section_header: Label = get_node_or_null("DragonInfoCard/InfoCardColumn/TrainingPlate/TrainingMargin/TrainingVBox/TrainingStatusBlock/TrainingSectionHeader")
@onready var training_fatigue_bar: ProgressBar = get_node_or_null("DragonInfoCard/InfoCardColumn/TrainingPlate/TrainingMargin/TrainingVBox/TrainingStatusBlock/TrainingFatigueBar")
@onready var training_fatigue_caption: Label = get_node_or_null("DragonInfoCard/InfoCardColumn/TrainingPlate/TrainingMargin/TrainingVBox/TrainingStatusBlock/TrainingFatigueCaption")
@onready var training_meta_label: RichTextLabel = get_node_or_null("DragonInfoCard/InfoCardColumn/TrainingPlate/TrainingMargin/TrainingVBox/TrainingStatusBlock/TrainingMetaLabel")
@onready var training_program_option: OptionButton = get_node_or_null("DragonInfoCard/InfoCardColumn/TrainingPlate/TrainingMargin/TrainingVBox/TrainingOptionsRow/TrainingProgramOption")
@onready var training_intensity_option: OptionButton = get_node_or_null("DragonInfoCard/InfoCardColumn/TrainingPlate/TrainingMargin/TrainingVBox/TrainingOptionsRow/TrainingIntensityOption")
@onready var training_preview_label: RichTextLabel = get_node_or_null("DragonInfoCard/InfoCardColumn/TrainingPlate/TrainingMargin/TrainingVBox/TrainingPreviewLabel")
@onready var training_selection_help_label: RichTextLabel = get_node_or_null("DragonInfoCard/InfoCardColumn/TrainingPlate/TrainingMargin/TrainingVBox/TrainingSelectionHelpLabel")
@onready var train_dragon_btn: Button = get_node_or_null("DragonInfoCard/InfoCardColumn/TrainingPlate/TrainingMargin/TrainingVBox/TrainingActionsRow/TrainDragonBtn")
@onready var rest_dragon_btn: Button = get_node_or_null("DragonInfoCard/InfoCardColumn/TrainingPlate/TrainingMargin/TrainingVBox/TrainingActionsRow/RestDragonBtn")

var is_training_animating: bool = false
var training_program_ids: Array[String] = []

var _info_card_stat_tween: Tween
var _info_card_nudge_tween: Tween
var _info_card_nudge_restore_ot: float = 0.0
var _info_card_nudge_restore_ob: float = 0.0
var _info_card_nudge_restore_pending: bool = false
const RANCH_INFO_CARD_STAT_TWEEN_SEC := 0.34

# --- BREEDING UI REFERENCES ---
@onready var open_breed_btn = $OpenBreedBtn # Adjust paths if you put them in containers!
@onready var breed_panel = $BreedPanel
@onready var close_breed_btn = $BreedPanel/CloseBreedBtn
@onready var parent_a_btn = $BreedPanel/ParentABtn
@onready var parent_b_btn = $BreedPanel/ParentBBtn
@onready var prediction_label = $BreedPanel/PredictionLabel
@onready var confirm_breed_btn = $BreedPanel/ConfirmBreedBtn

@onready var breed_selection_popup = $BreedSelectionPopup
@onready var close_selection_btn = $BreedSelectionPopup/CloseSelectionBtn
@onready var selection_vbox = $BreedSelectionPopup/ScrollContainer/SelectionVBox

# Memory for the currently selected parents
var selected_parent_a_index: int = -1
var selected_parent_b_index: int = -1
var selecting_for_slot: String = "" # Will be "A" or "B"
var _info_card_was_visible_before_breed: bool = false

var is_hatch_animating: bool = false

const DRAGON_ACTOR_SCENE: PackedScene = preload("res://Scenes/DragonActor.tscn")
const MEAT_ICON: Texture2D = preload("res://Assets/Sprites/UI/meat_icon.png")

@onready var hatch_btn: Button = get_node_or_null("HatchEggButton")
const EGG_ICON: Texture2D = preload("res://Assets/Sprites/UI/egg_icon.png") # UPDATE THIS PATH to your egg sprite!

@onready var hunt_btn: Button = get_node_or_null("DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/CarePlate/CareMargin/CareVBox/CareActionsRow/HuntRabbitBtn")
@onready var care_actions_help_label: RichTextLabel = get_node_or_null("DragonInfoCard/InfoCardColumn/InfoCardScroll/VBoxContainer/CarePlate/CareMargin/CareVBox/CareActionsHelpLabel")
const RABBIT_COST: int = 15
var is_hunt_animating: bool = false

@onready var header_label: Label = get_node_or_null("HeaderLabel")
@onready var breed_title_label: Label = get_node_or_null("BreedPanel/TitleLabel")
@onready var herder_portrait_rect: TextureRect = get_node_or_null("HerderPortrait")
@onready var herder_dialogue_label: Label = get_node_or_null("HerderDialogue")
@onready var breed_scroll: ScrollContainer = get_node_or_null("BreedSelectionPopup/ScrollContainer")

var enclosure_pen_border: Panel
var breed_dimmer: ColorRect
var herder_dialogue_plate: Panel

## Breeding modal: dimmer + panel alpha stack; keep dim light so the station stays readable.
const BREED_STATION_DIMMER_COLOR := Color(0.02, 0.015, 0.012, 0.22)
const BREED_STATION_PANEL_BG := Color(0.13, 0.097, 0.068, 1.0)
## Parent slot: dragon art in upper region; caption strip below (avoids text drawn over sprite).
const BREED_SLOT_SPRITE_BOTTOM_ANCHOR := 0.64

var selected_dragon_uid: String = ""
var is_feed_animating: bool = false
var actor_by_uid: Dictionary = {}

var is_pet_animating: bool = false

func _ready() -> void:
	close_btn.pressed.connect(func(): hide())
	visibility_changed.connect(_on_visibility_changed)

	save_name_btn.pressed.connect(_on_save_name_pressed)
	close_card_btn.pressed.connect(func():
		if dragon_stats_popup != null:
			dragon_stats_popup.hide()
		_dsp_dragging = false
		_dsp_resizing = false
		info_card.hide()
		selected_dragon_uid = ""
		_refresh_actor_selection()
	)
	feed_btn.pressed.connect(_on_feed_pressed)

	# --- BREEDING CONNECTIONS ---
	if open_breed_btn:
		open_breed_btn.pressed.connect(_open_breeding_station)
	if close_breed_btn:
		close_breed_btn.pressed.connect(_close_breeding_station)
	if close_selection_btn:
		close_selection_btn.pressed.connect(func(): breed_selection_popup.hide())

	if parent_a_btn:
		parent_a_btn.pressed.connect(func(): _open_parent_selector("A"))
	if parent_b_btn:
		parent_b_btn.pressed.connect(func(): _open_parent_selector("B"))
	if confirm_breed_btn:
		confirm_breed_btn.pressed.connect(_on_confirm_breed_pressed)

	# Connect Debug Buttons
	if debug_anger_btn: debug_anger_btn.pressed.connect(_debug_force_anger)
	if debug_neutral_btn: debug_neutral_btn.pressed.connect(_debug_force_neutral)
	if debug_adore_btn: debug_adore_btn.pressed.connect(_debug_force_adore)
	if debug_reset_btn: debug_reset_btn.pressed.connect(_debug_reset_morgra)

	if hatch_btn != null:
		hatch_btn.pressed.connect(_on_hatch_pressed)
		hatch_btn.disabled = is_feed_animating or is_pet_animating or is_hunt_animating or is_hatch_animating or is_training_animating

	if hunt_btn != null:
		hunt_btn.pressed.connect(_on_hunt_pressed)

	if training_program_option != null:
		training_program_option.item_selected.connect(_on_training_selection_changed)

	if training_intensity_option != null:
		training_intensity_option.item_selected.connect(_on_training_selection_changed)

	if train_dragon_btn != null:
		train_dragon_btn.pressed.connect(_on_train_pressed)

	if rest_dragon_btn != null:
		rest_dragon_btn.pressed.connect(_on_rest_pressed)

	if open_dragon_stats_btn != null:
		open_dragon_stats_btn.pressed.connect(_on_open_dragon_stats_pressed)
	if close_dragon_stats_btn != null:
		close_dragon_stats_btn.pressed.connect(_on_close_dragon_stats_pressed)
	if stats_popup_header != null:
		stats_popup_header.mouse_default_cursor_shape = Control.CURSOR_MOVE
		stats_popup_header.tooltip_text = "Drag to move"
		stats_popup_header.gui_input.connect(_on_dragon_stats_popup_header_gui_input)
	if stats_popup_resize_grip != null:
		stats_popup_resize_grip.mouse_default_cursor_shape = Control.CURSOR_BDIAGSIZE
		stats_popup_resize_grip.tooltip_text = "Drag to resize"
		stats_popup_resize_grip.gui_input.connect(_on_dragon_stats_popup_resize_gui_input)
	if dragon_stats_popup_title != null:
		dragon_stats_popup_title.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_setup_training_ui()

	_ensure_breeding_station_fx_ui()
	set_process(true)
	social_interaction_timer = _roll_next_social_time()

	var dbg_panel: Node = get_node_or_null("DebugMorgraPanel")
	if dbg_panel != null:
		dbg_panel.visible = OS.is_debug_build()

	if OS.is_debug_build():
		# Dev-only inventory / stage shortcuts for ranch testing.
		var debug_rose := ConsumableData.new()
		debug_rose.item_name = "Dragon Rose"
		CampaignManager.global_inventory.append(debug_rose)
		for d in DragonManager.player_dragons:
			d["stage"] = 3

	_ensure_enclosure_pen_frame()
	_ensure_breed_dimmer()
	_ensure_herder_chrome()
	_apply_ranch_camp_skin()

func _on_visibility_changed() -> void:
	if visible:
		_spawn_dragons()
		_refresh_training_controls()
		_update_favorite_display()
		call_deferred("_sync_herder_corner_layout")
		call_deferred("_ranch_reassert_info_card_input_fix")
	else:
		if dragon_stats_popup != null:
			dragon_stats_popup.hide()
		_dsp_dragging = false
		_dsp_resizing = false
		_ranch_kill_info_card_nudge_tween()
		info_card.hide()
		selected_dragon_uid = ""
		is_feed_animating = false
		is_training_animating = false
		_close_breeding_station()
		if breed_selection_popup != null:
			breed_selection_popup.hide()
		_clear_dragons()
		is_social_animating = false
		social_pair_cooldowns.clear()
		social_interaction_timer = _roll_next_social_time()
func _spawn_dragons() -> void:
	_clear_dragons()

	if not DragonManager or DragonManager.player_dragons.is_empty():
		return

	for d_data in DragonManager.player_dragons:
		var uid: String = str(d_data.get("uid", ""))
		if uid == "":
			continue

		var actor: DragonActor = DRAGON_ACTOR_SCENE.instantiate()
		actor.set_meta("is_dragon", true)

		enclosure.add_child(actor)
		actor.setup(d_data)

		actor.position = Vector2(
			randf_range(0.0, max(0.0, enclosure.size.x - actor.size.x)),
			randf_range(0.0, max(0.0, enclosure.size.y - actor.size.y))
		)

		actor_by_uid[uid] = actor

		actor.gui_input.connect(_on_dragon_input.bind(uid))
		actor.mouse_entered.connect(_on_actor_mouse_entered.bind(uid))
		actor.mouse_exited.connect(_on_actor_mouse_exited.bind(uid))

	_refresh_actor_selection()

func _clear_dragons() -> void:
	actor_by_uid.clear()

	for child in enclosure.get_children():
		if child.has_meta("is_dragon"):
			child.queue_free()

func _get_dragon_index_by_uid(uid: String) -> int:
	if uid == "":
		return -1

	for i in range(DragonManager.player_dragons.size()):
		var d: Dictionary = DragonManager.player_dragons[i]
		if str(d.get("uid", "")) == uid:
			return i

	return -1

func _get_selected_index() -> int:
	return _get_dragon_index_by_uid(selected_dragon_uid)

func _get_actor_by_uid(uid: String) -> DragonActor:
	if not actor_by_uid.has(uid):
		return null

	var actor: Variant = actor_by_uid[uid]
	if actor is DragonActor and is_instance_valid(actor):
		return actor

	actor_by_uid.erase(uid)
	return null

func _refresh_actor_selection() -> void:
	for uid in actor_by_uid.keys():
		var actor: DragonActor = _get_actor_by_uid(str(uid))
		if actor != null:
			actor.set_selected(str(uid) == selected_dragon_uid)

func _on_actor_mouse_entered(uid: String) -> void:
	var actor: DragonActor = _get_actor_by_uid(uid)
	if actor != null:
		actor.set_hovered(true)

func _on_actor_mouse_exited(uid: String) -> void:
	var actor: DragonActor = _get_actor_by_uid(uid)
	if actor != null:
		actor.set_hovered(false)

# ==========================================
# INFO CARD LOGIC
# ==========================================

func _on_dragon_input(event: InputEvent, uid: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var animate_bars: bool = selected_dragon_uid != uid
			selected_dragon_uid = uid
			_update_info_card(animate_bars)
			_refresh_actor_selection()
			info_card.show()
			if animate_bars:
				call_deferred("_ranch_play_info_card_dragon_switch_nudge")

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var animate_bars_r: bool = selected_dragon_uid != uid
			selected_dragon_uid = uid
			_update_info_card(animate_bars_r)
			_refresh_actor_selection()
			info_card.show()
			if animate_bars_r:
				call_deferred("_ranch_play_info_card_dragon_switch_nudge")
			_pet_dragon(uid)


func _ranch_dossier_add_profile_slot(row: HBoxContainer, key: String, caption: String) -> void:
	var slot := VBoxContainer.new()
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.add_theme_constant_override("separation", 6)
	var cap := Label.new()
	cap.text = caption
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_CampUiSkin.style_label(cap, _CampUiSkin.CAMP_MUTED, RANCH_DOSSIER_FONT_PROFILE_CAPTION, 1)
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(0, RANCH_DOSSIER_PROFILE_CHIP_H)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vl := Label.new()
	_CampUiSkin.style_label(vl, _CampUiSkin.CAMP_TEXT, RANCH_DOSSIER_FONT_PROFILE_VALUE, 2)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chip.add_child(vl)
	_CampUiSkin.style_dossier_value_chip(chip, _CampUiSkin.CAMP_BORDER_SOFT)
	slot.add_child(cap)
	slot.add_child(chip)
	row.add_child(slot)
	_dossier_profile_slots[key] = {"value": vl}


func _ranch_make_dossier_stat_cell(stat_key: String, short_name: String) -> PanelContainer:
	var panel_c := PanelContainer.new()
	panel_c.name = "DossierStat_" + stat_key
	panel_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_c.custom_minimum_size = Vector2(0, RANCH_DOSSIER_STAT_CELL_MIN_H)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	panel_c.add_child(margin)
	var fill_col := _CampUiSkin.dossier_stat_fill_color(stat_key, 0)
	_CampUiSkin.style_dossier_row_panel(panel_c, fill_col)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 10)
	var nl := Label.new()
	nl.text = short_name
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_CampUiSkin.style_label(nl, fill_col, RANCH_DOSSIER_FONT_STAT, 2)
	var chip := PanelContainer.new()
	chip.custom_minimum_size = RANCH_DOSSIER_STAT_CHIP
	var vl := Label.new()
	_CampUiSkin.style_label(vl, _CampUiSkin.CAMP_TEXT, RANCH_DOSSIER_FONT_STAT, 2)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chip.add_child(vl)
	_CampUiSkin.style_dossier_value_chip(chip, fill_col)
	hrow.add_child(nl)
	hrow.add_child(chip)
	vbox.add_child(hrow)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, RANCH_DOSSIER_BAR_H)
	vbox.add_child(bar)
	_dossier_stat_cells[stat_key] = {"panel": panel_c, "name": nl, "chip": chip, "value": vl, "bar": bar}
	return panel_c


func _ensure_dragon_stats_dossier_ui() -> void:
	if stats_dossier_mini == null:
		return
	if _ranch_dossier_ui_version_applied != RANCH_DOSSIER_UI_VERSION:
		for c in stats_dossier_mini.get_children():
			stats_dossier_mini.remove_child(c)
			c.queue_free()
		_dragon_stats_dossier_built = false
		_dossier_profile_slots.clear()
		_dossier_stat_cells.clear()
		_dossier_ability_name_label = null
		_dossier_pet_value_label = null
		_ranch_dossier_ui_version_applied = RANCH_DOSSIER_UI_VERSION
	if _dragon_stats_dossier_built:
		return
	var root := stats_dossier_mini
	var ph := Label.new()
	ph.text = "Profile"
	_CampUiSkin.style_label(ph, _CampUiSkin.CAMP_BORDER, RANCH_DOSSIER_FONT_SECTION, 0)
	root.add_child(ph)
	var profile_blk := PanelContainer.new()
	profile_blk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_blk.custom_minimum_size = Vector2(0, RANCH_DOSSIER_PROFILE_BLOCK_MIN_H)
	var p_margin := MarginContainer.new()
	p_margin.add_theme_constant_override("margin_left", 10)
	p_margin.add_theme_constant_override("margin_right", 10)
	p_margin.add_theme_constant_override("margin_top", 10)
	p_margin.add_theme_constant_override("margin_bottom", 10)
	var phrow := HBoxContainer.new()
	phrow.add_theme_constant_override("separation", 10)
	phrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_margin.add_child(phrow)
	profile_blk.add_child(p_margin)
	_CampUiSkin.style_dossier_row_panel(profile_blk, _CampUiSkin.CAMP_BORDER_SOFT)
	root.add_child(profile_blk)
	_ranch_dossier_add_profile_slot(phrow, "level", "Level")
	_ranch_dossier_add_profile_slot(phrow, "experience", "Experience")
	_ranch_dossier_add_profile_slot(phrow, "bond", "Bond")
	_ranch_dossier_add_profile_slot(phrow, "happiness", "Happiness")
	var ch := Label.new()
	ch.text = "Combat"
	_CampUiSkin.style_label(ch, _CampUiSkin.CAMP_BORDER, RANCH_DOSSIER_FONT_SECTION, 0)
	root.add_child(ch)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(grid)
	var stat_pairs: Array = [
		["max_hp", "Health"], ["strength", "Strength"], ["magic", "Magic"], ["defense", "Defense"],
		["resistance", "Resistance"], ["speed", "Speed"], ["agility", "Agility"], ["move_range", "Movement"],
	]
	for pair in stat_pairs:
		grid.add_child(_ranch_make_dossier_stat_cell(str(pair[0]), str(pair[1])))
	var ab_panel := PanelContainer.new()
	ab_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ab_panel.custom_minimum_size = Vector2(0, RANCH_DOSSIER_FULL_ROW_MIN_H)
	var ab_fill := _CampUiSkin.CAMP_ACCENT_CYAN.darkened(0.28)
	_CampUiSkin.style_dossier_row_panel(ab_panel, ab_fill)
	var ab_margin := MarginContainer.new()
	ab_margin.add_theme_constant_override("margin_left", 10)
	ab_margin.add_theme_constant_override("margin_right", 10)
	ab_margin.add_theme_constant_override("margin_top", 10)
	ab_margin.add_theme_constant_override("margin_bottom", 10)
	var abh := HBoxContainer.new()
	ab_margin.add_child(abh)
	ab_panel.add_child(ab_margin)
	var ab_title := Label.new()
	ab_title.text = "Ability"
	ab_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_CampUiSkin.style_label(ab_title, _CampUiSkin.CAMP_TEXT, RANCH_DOSSIER_FONT_ABILITY, 1)
	_dossier_ability_name_label = Label.new()
	_dossier_ability_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_CampUiSkin.style_label(_dossier_ability_name_label, _CampUiSkin.CAMP_ACCENT_CYAN, RANCH_DOSSIER_FONT_ABILITY, 2)
	abh.add_child(ab_title)
	abh.add_child(_dossier_ability_name_label)
	root.add_child(ab_panel)
	var pet_panel := PanelContainer.new()
	pet_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pet_panel.custom_minimum_size = Vector2(0, RANCH_DOSSIER_FULL_ROW_MIN_H)
	_CampUiSkin.style_dossier_row_panel(pet_panel, _CampUiSkin.CAMP_MUTED.darkened(0.35))
	var pet_margin := MarginContainer.new()
	pet_margin.add_theme_constant_override("margin_left", 10)
	pet_margin.add_theme_constant_override("margin_right", 10)
	pet_margin.add_theme_constant_override("margin_top", 10)
	pet_margin.add_theme_constant_override("margin_bottom", 10)
	var pet_h := HBoxContainer.new()
	pet_margin.add_child(pet_h)
	pet_panel.add_child(pet_margin)
	var pet_title := Label.new()
	pet_title.text = "Pet cooldown"
	pet_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_CampUiSkin.style_label(pet_title, _CampUiSkin.CAMP_MUTED, RANCH_DOSSIER_FONT_PET_TITLE, 1)
	var pet_chip := PanelContainer.new()
	pet_chip.custom_minimum_size = RANCH_DOSSIER_PET_CHIP
	_dossier_pet_value_label = Label.new()
	_CampUiSkin.style_label(_dossier_pet_value_label, _CampUiSkin.CAMP_TEXT, RANCH_DOSSIER_FONT_PET_VALUE, 2)
	_dossier_pet_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dossier_pet_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dossier_pet_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dossier_pet_value_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pet_chip.add_child(_dossier_pet_value_label)
	_CampUiSkin.style_dossier_value_chip(pet_chip, _CampUiSkin.CAMP_MUTED)
	pet_h.add_child(pet_title)
	pet_h.add_child(pet_chip)
	root.add_child(pet_panel)
	_dragon_stats_dossier_built = true


func _ranch_update_dragon_stats_popup_title(d: Dictionary) -> void:
	if dragon_stats_popup_title == null:
		return
	var dn: String = str(d.get("name", "Dragon")).strip_edges()
	if dn.is_empty():
		dn = "Dragon"
	dragon_stats_popup_title.text = "Dragon stats — %s" % dn


func _on_open_dragon_stats_pressed() -> void:
	var idx: int = _get_selected_index()
	if idx < 0 or idx >= DragonManager.player_dragons.size():
		return
	var d: Dictionary = DragonManager.player_dragons[idx]
	_ranch_update_dragon_stats_popup_title(d)
	_ranch_refresh_stats_dossier(d)
	if dragon_stats_popup != null:
		dragon_stats_popup.show()


func _on_close_dragon_stats_pressed() -> void:
	if dragon_stats_popup != null:
		dragon_stats_popup.hide()
	_dsp_dragging = false
	_dsp_resizing = false


func _on_dragon_stats_popup_header_gui_input(event: InputEvent) -> void:
	if dragon_stats_popup == null or not dragon_stats_popup.visible:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	_dsp_resizing = false
	_dsp_dragging = true
	_dsp_drag_ofs = dragon_stats_popup.get_global_mouse_position() - dragon_stats_popup.global_position
	dragon_stats_popup.accept_event()


func _on_dragon_stats_popup_resize_gui_input(event: InputEvent) -> void:
	if dragon_stats_popup == null or not dragon_stats_popup.visible:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	_dsp_dragging = false
	_dsp_resizing = true
	_dsp_resize_start_mouse = dragon_stats_popup.get_global_mouse_position()
	_dsp_resize_start_size = dragon_stats_popup.size
	dragon_stats_popup.accept_event()


func _ranch_process_dragon_stats_popup_interaction() -> void:
	if dragon_stats_popup == null or not dragon_stats_popup.visible:
		_dsp_dragging = false
		_dsp_resizing = false
		return
	if not _dsp_dragging and not _dsp_resizing:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_dsp_dragging = false
		_dsp_resizing = false
		return
	var parent_c := dragon_stats_popup.get_parent() as Control
	if parent_c == null:
		return
	if _dsp_dragging:
		var mouse_g := dragon_stats_popup.get_global_mouse_position()
		var new_global := mouse_g - _dsp_drag_ofs
		var new_local := new_global - parent_c.global_position
		var sz := dragon_stats_popup.size
		new_local.x = clampf(new_local.x, 0.0, maxf(0.0, parent_c.size.x - sz.x))
		new_local.y = clampf(new_local.y, 0.0, maxf(0.0, parent_c.size.y - sz.y))
		dragon_stats_popup.position = new_local
	elif _dsp_resizing:
		var mouse_g := dragon_stats_popup.get_global_mouse_position()
		var delta_px := mouse_g - _dsp_resize_start_mouse
		var new_size := _dsp_resize_start_size + delta_px
		new_size.x = maxf(new_size.x, DRAGON_STATS_POPUP_MIN_SIZE.x)
		new_size.y = maxf(new_size.y, DRAGON_STATS_POPUP_MIN_SIZE.y)
		var max_sz: Vector2 = parent_c.size - dragon_stats_popup.position
		new_size.x = clampf(new_size.x, DRAGON_STATS_POPUP_MIN_SIZE.x, maxf(DRAGON_STATS_POPUP_MIN_SIZE.x, max_sz.x))
		new_size.y = clampf(new_size.y, DRAGON_STATS_POPUP_MIN_SIZE.y, maxf(DRAGON_STATS_POPUP_MIN_SIZE.y, max_sz.y))
		dragon_stats_popup.size = new_size


func _ranch_refresh_stats_dossier(d: Dictionary) -> void:
	_ensure_dragon_stats_dossier_ui()
	if not _dragon_stats_dossier_built:
		return
	for key in _dossier_profile_slots:
		var slot: Dictionary = _dossier_profile_slots[key]
		var vl: Label = slot["value"] as Label
		if vl == null:
			continue
		match key:
			"level":
				vl.text = str(int(d.get("level", 1)))
			"experience":
				vl.text = str(int(d.get("experience", 0)))
			"bond":
				vl.text = str(int(d.get("bond", 0)))
			"happiness":
				vl.text = str(int(d.get("happiness", 50)))
		_CampUiSkin.style_label(vl, _CampUiSkin.CAMP_TEXT, RANCH_DOSSIER_FONT_PROFILE_VALUE, 2)
	for stat_key in _dossier_stat_cells:
		var w: Dictionary = _dossier_stat_cells[stat_key]
		var raw: int = int(d.get(stat_key, 0))
		var fill_col := _CampUiSkin.dossier_stat_fill_color(stat_key, raw)
		var overcap: bool = raw >= int(_CampUiSkin.UNIT_DOSSIER_STAT_BAR_CAP)
		var disp: float = _CampUiSkin.dossier_stat_bar_display_value(raw)
		var bar: ProgressBar = w["bar"] as ProgressBar
		var panel: Control = w["panel"] as Control
		var chip: Control = w["chip"] as Control
		var nl: Label = w["name"] as Label
		var vl2: Label = w["value"] as Label
		vl2.text = str(raw)
		_CampUiSkin.style_label(vl2, _CampUiSkin.CAMP_TEXT, RANCH_DOSSIER_FONT_STAT, 2)
		if bar != null:
			bar.max_value = _CampUiSkin.UNIT_DOSSIER_STAT_BAR_CAP
			bar.value = disp
			_CampUiSkin.style_dossier_stat_bar(bar, fill_col, overcap)
		if panel != null:
			_CampUiSkin.style_dossier_row_panel(panel, fill_col, overcap)
		if chip != null:
			_CampUiSkin.style_dossier_value_chip(chip, fill_col)
		if nl != null:
			_CampUiSkin.style_label(nl, fill_col, RANCH_DOSSIER_FONT_STAT, 2)
	if _dossier_ability_name_label != null:
		_dossier_ability_name_label.text = str(d.get("ability", "None")).to_upper()
		_CampUiSkin.style_label(_dossier_ability_name_label, _CampUiSkin.CAMP_ACCENT_CYAN, RANCH_DOSSIER_FONT_ABILITY, 2)
	if _dossier_pet_value_label != null:
		var pet_cd: int = max(0, int(d.get("pet_cooldown_until", 0)) - int(Time.get_unix_time_from_system()))
		_dossier_pet_value_label.text = "%ds" % pet_cd
		_CampUiSkin.style_label(_dossier_pet_value_label, _CampUiSkin.CAMP_TEXT, RANCH_DOSSIER_FONT_PET_VALUE, 2)


func _ranch_escape_bbcode(raw: String) -> String:
	return str(raw).replace("[", "(").replace("]", ")")


func _update_info_card(animate_bars: bool = false) -> void:
	if not animate_bars:
		_ranch_kill_info_card_stat_tween()

	var selected_index: int = _get_selected_index()
	if selected_index < 0 or selected_index >= DragonManager.player_dragons.size():
		_ranch_kill_info_card_stat_tween()
		if open_dragon_stats_btn != null:
			open_dragon_stats_btn.disabled = true
		if care_actions_help_label != null:
			care_actions_help_label.text = (
				"[color=#9a8f82]Select a dragon to see care options. "
				+ "Hover Feed or Throw rabbit for full details.[/color]"
			)
		if feed_btn != null:
			feed_btn.tooltip_text = DragonManager.get_ranch_care_tooltip_feed()
		if hunt_btn != null:
			hunt_btn.tooltip_text = DragonManager.get_ranch_care_tooltip_hunt(RABBIT_COST)
		_ranch_sync_rail_rich_min_heights()
		return

	if open_dragon_stats_btn != null:
		open_dragon_stats_btn.disabled = false

	var d: Dictionary = DragonManager.player_dragons[selected_index]

	name_input.text = str(d["name"])

	var stage_str: String = "Egg"
	if d["stage"] == 1:
		stage_str = "Baby"
	elif d["stage"] == 2:
		stage_str = "Juvenile"
	elif d["stage"] == 3:
		stage_str = "Adult"

	var gen_n: int = int(d.get("generation", 1))
	var bond_n: int = int(d.get("bond", 0))
	var elem_s: String = _ranch_escape_bbcode(str(d.get("element", "?")))
	var mood_s: String = _ranch_escape_bbcode(str(d.get("mood", "Curious")))
	details_label.bbcode_enabled = true
	details_label.text = (
		"[color=#d4a74a]Lineage[/color]  "
		+ "[font_size=15][color=#f5f0e6]Gen %d[/color]  ·  [color=#ffbe78]%s[/color]  ·  [color=#e4ddd2]%s[/color][/font_size]\n"
		+ "[color=#d4a74a]Temperament[/color]  "
		+ "[font_size=15][color=#f5f0e6]Bond %d[/color]  ·  [color=#8fd4f0]%s[/color][/font_size]"
	) % [gen_n, elem_s, _ranch_escape_bbcode(stage_str), bond_n, mood_s]

	var traits_array: Array = d.get("traits", [])
	traits_label.bbcode_enabled = true
	if traits_array.is_empty():
		traits_label.text = "[color=#d4a74a]Traits[/color]  [color=#9a9285]— None yet —[/color]"
	else:
		var trait_parts := PackedStringArray()
		for tr in traits_array:
			trait_parts.append("[color=#f0e8dc]%s[/color]" % _ranch_escape_bbcode(str(tr)))
		traits_label.text = (
			"[color=#d4a74a]Traits[/color]  "
			+ "  [color=#6b5f4d]·[/color]  ".join(trait_parts)
		)

	var happiness_value: int = int(d.get("happiness", 50))
	var happiness_state: String = DragonManager.get_happiness_state_name(happiness_value)
	var growth_mult: float = DragonManager.get_happiness_growth_multiplier_for_value(happiness_value)
	var growth_bonus_pct: int = int(round((growth_mult - 1.0) * 100.0))
	var growth_bonus_text: String = ("+" if growth_bonus_pct >= 0 else "") + str(growth_bonus_pct) + "% GP"
	_ranch_refresh_stats_dossier(d)
	if dragon_stats_popup != null and dragon_stats_popup.visible:
		_ranch_update_dragon_stats_popup_title(d)

	var required_gp: int = 50 if d["stage"] == 1 else 150
	var gp_now: int = int(d.get("growth_points", 0))

	var tween_stats: bool = animate_bars

	if dragon_happiness_bar != null:
		dragon_happiness_bar.max_value = 100.0
		if not tween_stats:
			dragon_happiness_bar.value = float(happiness_value)
			_ranch_apply_happiness_bar_fill(dragon_happiness_bar, happiness_value)
	if happiness_mood_label != null and not tween_stats:
		happiness_mood_label.text = "%d / 100  ·  %s" % [happiness_value, happiness_state]
	if growth_bonus_label != null and not tween_stats:
		growth_bonus_label.text = "[color=#c9a050]Growth bonus:[/color]  %s" % growth_bonus_text

	var growth_bar_tween_eligible: bool = false
	var growth_start_from_zero: bool = false

	if d["stage"] == 3:
		if dragon_growth_bar != null:
			dragon_growth_bar.visible = false
		if growth_fraction_label != null:
			growth_fraction_label.text = "Max level"
		feed_btn.disabled = true
		feed_btn.text = "Fully Grown"
	else:
		if dragon_growth_bar != null:
			growth_start_from_zero = not dragon_growth_bar.visible
			dragon_growth_bar.visible = true
			dragon_growth_bar.max_value = float(required_gp)
			growth_bar_tween_eligible = true
			if not tween_stats:
				dragon_growth_bar.value = float(clampi(gp_now, 0, required_gp))
				_ranch_apply_growth_bar_fill(dragon_growth_bar, float(gp_now) / float(max(1, required_gp)))
		if growth_fraction_label != null and not tween_stats:
			growth_fraction_label.text = "%d / %d  growth points" % [gp_now, required_gp]
		feed_btn.disabled = is_feed_animating or is_pet_animating or is_hunt_animating or is_training_animating
		feed_btn.text = "Feed (Use Meat)"

	if hunt_btn != null:
		hunt_btn.disabled = is_feed_animating or is_pet_animating or is_hunt_animating or is_training_animating or int(d.get("stage", 1)) <= 0
		hunt_btn.text = "Throw Rabbit (%d Gold)" % RABBIT_COST

	if feed_btn != null:
		feed_btn.tooltip_text = DragonManager.get_ranch_care_tooltip_feed()
	if hunt_btn != null:
		hunt_btn.tooltip_text = DragonManager.get_ranch_care_tooltip_hunt(RABBIT_COST)

	_update_care_actions_help(int(d.get("stage", DragonManager.DragonStage.BABY)))

	var fatigue_value: int = int(d.get("fatigue", 0))
	var sessions_value: int = int(d.get("training_sessions", 0))
	var ranch_action_used: bool = _dragon_has_used_ranch_action(d)
	var ranch_action_text: String = "USED" if ranch_action_used else "READY"

	if training_fatigue_bar != null:
		training_fatigue_bar.max_value = 100.0
		if not tween_stats:
			training_fatigue_bar.value = float(fatigue_value)
			_ranch_apply_fatigue_bar_fill(training_fatigue_bar, fatigue_value)
	if training_fatigue_caption != null and not tween_stats:
		training_fatigue_caption.text = "Fatigue  %d / 100" % fatigue_value
	if training_meta_label != null:
		training_meta_label.bbcode_enabled = true
		training_meta_label.scroll_active = false
		training_meta_label.text = (
			"Sessions: %d\n" % sessions_value +
			"Level action: [color=%s]%s[/color]" % [
				"#ffaa66" if ranch_action_used else "#77ee99",
				ranch_action_text
			]
		)
		_ranch_configure_card_richtext_rail(training_meta_label)

	if tween_stats:
		_ranch_kill_info_card_stat_tween()
		var tw := create_tween()
		tw.set_parallel(true)
		tw.set_ease(Tween.EASE_OUT)
		tw.set_trans(Tween.TRANS_CUBIC)
		_info_card_stat_tween = tw

		if dragon_happiness_bar != null:
			var h0: float = dragon_happiness_bar.value
			var h1: float = float(happiness_value)
			tw.tween_method(_ranch_info_card_apply_happiness_display, h0, h1, RANCH_INFO_CARD_STAT_TWEEN_SEC)

		if training_fatigue_bar != null:
			var f0: float = training_fatigue_bar.value
			var f1: float = float(fatigue_value)
			tw.tween_method(_ranch_info_card_apply_fatigue_display, f0, f1, RANCH_INFO_CARD_STAT_TWEEN_SEC)

		if growth_bar_tween_eligible and dragon_growth_bar != null and dragon_growth_bar.visible:
			var g1: float = float(clampi(gp_now, 0, required_gp))
			var g0: float = 0.0 if growth_start_from_zero else dragon_growth_bar.value
			if growth_start_from_zero:
				_ranch_info_card_apply_growth_display(0.0, required_gp)
			tw.tween_method(_ranch_info_card_apply_growth_display.bind(required_gp), g0, g1, RANCH_INFO_CARD_STAT_TWEEN_SEC)

	_refresh_training_controls()


func _on_save_name_pressed() -> void:
	var selected_index: int = _get_selected_index()
	if selected_index < 0 or selected_index >= DragonManager.player_dragons.size():
		return

	var new_name: String = name_input.text.strip_edges()
	if new_name == "":
		return

	DragonManager.player_dragons[selected_index]["name"] = new_name

	var actor: DragonActor = _get_actor_by_uid(selected_dragon_uid)
	if actor != null:
		actor.refresh_name_only()

	_update_info_card()
	_refresh_actor_selection()

func _on_feed_pressed() -> void:
	if is_feed_animating or is_pet_animating or is_hatch_animating or is_training_animating:
		return

	var selected_index: int = _get_selected_index()
	if selected_index < 0 or selected_index >= DragonManager.player_dragons.size():
		return

	var actor: DragonActor = _get_actor_by_uid(selected_dragon_uid)
	if actor == null:
		return

	var meat_index: int = -1
	for i in range(CampaignManager.global_inventory.size()):
		var item = CampaignManager.global_inventory[i]
		if item is ConsumableData:
			var i_name: String = item.item_name
			if "Meat" in i_name or "meat" in i_name:
				meat_index = i
				break

	if meat_index == -1:
		feed_btn.text = "No Meat in Inventory!"
		var _feed_wr: WeakRef = weakref(feed_btn)
		get_tree().create_timer(1.5).timeout.connect(func():
			var b: Button = _feed_wr.get_ref() as Button
			if b != null:
				b.text = "Feed (Use Meat)"
		)
		return

	is_feed_animating = true
	feed_btn.disabled = true

	CampaignManager.global_inventory.remove_at(meat_index)
	var result: Dictionary = DragonManager.feed_dragon(selected_index, 25)
	_update_info_card()

	await _play_feed_projectile(actor)

	if result.get("evolved", false):
		_shake_enclosure(10.0, 0.22)

		var updated_data: Dictionary = DragonManager.player_dragons[selected_index]
		actor.play_evolution_fx(
			updated_data,
			int(result.get("old_stage", -1)),
			int(result.get("new_stage", -1))
		)

		await get_tree().create_timer(0.12).timeout
		_shake_enclosure(6.0, 0.15)
	else:
		actor.refresh_from_data(DragonManager.player_dragons[selected_index])
		actor.play_feed_bounce(int(result.get("growth_added", 25)))
		_shake_enclosure(3.0, 0.10)

	await get_tree().create_timer(0.20).timeout

	is_feed_animating = false
	_update_info_card()
	_trigger_morgra("feed")
	
# ==========================================
# JUICE / FX
# ==========================================

func _play_feed_projectile(target_actor: DragonActor) -> void:
	if target_actor == null or not is_instance_valid(target_actor):
		return

	var meat: TextureRect = TextureRect.new()
	meat.texture = MEAT_ICON
	meat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	meat.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	meat.size = Vector2(28, 28)
	meat.scale = Vector2.ONE
	meat.rotation = 0.0
	meat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meat.z_index = 100

	enclosure.add_child(meat)

	var start_global: Vector2 = feed_btn.global_position + (feed_btn.size * 0.5)
	var end_global: Vector2 = target_actor.global_position + Vector2(target_actor.size.x * 0.55, target_actor.size.y * 0.35)
	var mid_global: Vector2 = (start_global + end_global) * 0.5 + Vector2(0, -70)

	meat.global_position = start_global - (meat.size * 0.5)

	var tw: Tween = create_tween()
	tw.tween_property(meat, "global_position", mid_global - (meat.size * 0.5), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(meat, "scale", Vector2(1.15, 1.15), 0.16)
	tw.parallel().tween_property(meat, "rotation", deg_to_rad(-12.0), 0.16)

	tw.tween_property(meat, "global_position", end_global - (meat.size * 0.5), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(meat, "scale", Vector2(0.85, 0.85), 0.14)
	tw.parallel().tween_property(meat, "rotation", deg_to_rad(10.0), 0.14)

	await tw.finished

	if is_instance_valid(meat):
		meat.queue_free()

func _shake_enclosure(power: float = 8.0, duration: float = 0.18) -> void:
	if shake_root == null or not is_instance_valid(shake_root):
		return

	var original: Vector2 = shake_root.position
	var tw: Tween = create_tween()

	for i in range(4):
		var offset: Vector2 = Vector2(
			randf_range(-power, power),
			randf_range(-power * 0.55, power * 0.55)
		)
		tw.tween_property(shake_root, "position", original + offset, duration / 8.0)

	tw.tween_property(shake_root, "position", original, duration / 4.0).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _pet_dragon(uid: String) -> void:
	if is_feed_animating or is_pet_animating or is_hatch_animating or is_training_animating:
		return

	var actor: DragonActor = _get_actor_by_uid(uid)
	if actor == null:
		return

	var index: int = _get_dragon_index_by_uid(uid)
	if index == -1:
		return

	is_pet_animating = true

	var result: Dictionary = DragonManager.pet_dragon(index)

	actor.refresh_from_data(DragonManager.player_dragons[index])
	_update_info_card()

	if bool(result.get("on_cooldown", false)):
		actor._spawn_float_text(str(result.get("float_text", "Wait")), Color(1.0, 0.75, 0.25))
		await get_tree().create_timer(0.15).timeout
		is_pet_animating = false
		_update_info_card()
		return

	actor.play_pet_reaction(result)

	if str(result.get("reaction", "")) == "annoyed":
		_shake_enclosure(2.0, 0.08)

	await get_tree().create_timer(0.15).timeout

	is_pet_animating = false
	_update_info_card()
	
func _ranch_apply_happiness_bar_fill(bar: ProgressBar, happy: int) -> void:
	var t: float = clampf(float(happy) / 100.0, 0.0, 1.0)
	var col: Color = _CampUiSkin.CAMP_ACTION_SECONDARY.lerp(_CampUiSkin.CAMP_ACCENT_GREEN, t)
	if happy < 35:
		col = col.lerp(Color(0.92, 0.38, 0.28), 1.0 - t)
	_CampUiSkin.set_progress_bar_fill_color(bar, col)


func _ranch_apply_fatigue_bar_fill(bar: ProgressBar, fatigue: int) -> void:
	var t: float = clampf(float(fatigue) / 100.0, 0.0, 1.0)
	var col: Color = _CampUiSkin.CAMP_BORDER.lerp(Color(0.92, 0.32, 0.24), t)
	_CampUiSkin.set_progress_bar_fill_color(bar, col)


func _ranch_apply_growth_bar_fill(bar: ProgressBar, ratio: float) -> void:
	var t: float = clampf(ratio, 0.0, 1.0)
	var col: Color = Color(0.18, 0.26, 0.32).lerp(_CampUiSkin.CAMP_ACCENT_CYAN, t)
	_CampUiSkin.set_progress_bar_fill_color(bar, col)


func _ranch_kill_info_card_stat_tween() -> void:
	if _info_card_stat_tween != null and is_instance_valid(_info_card_stat_tween):
		_info_card_stat_tween.kill()
	_info_card_stat_tween = null


func _ranch_kill_info_card_nudge_tween() -> void:
	if _info_card_nudge_tween != null and is_instance_valid(_info_card_nudge_tween):
		_info_card_nudge_tween.kill()
	_info_card_nudge_tween = null
	if info_card != null and is_instance_valid(info_card):
		info_card.scale = Vector2.ONE
		if _info_card_nudge_restore_pending:
			info_card.offset_top = _info_card_nudge_restore_ot
			info_card.offset_bottom = _info_card_nudge_restore_ob
			_info_card_nudge_restore_pending = false


func _ranch_on_info_card_nudge_tween_finished() -> void:
	_info_card_nudge_restore_pending = false


## Subtle “bob” when the selected dragon changes so the info panel feels like it refreshed.
func _ranch_play_info_card_dragon_switch_nudge() -> void:
	if info_card == null or not is_instance_valid(info_card) or not info_card.visible:
		return
	_ranch_kill_info_card_nudge_tween()
	var ot0: float = info_card.offset_top
	var ob0: float = info_card.offset_bottom
	var lift: float = 7.0
	_info_card_nudge_restore_ot = ot0
	_info_card_nudge_restore_ob = ob0
	_info_card_nudge_restore_pending = true
	info_card.scale = Vector2.ONE
	info_card.pivot_offset = info_card.size * 0.5
	var tw := info_card.create_tween()
	_info_card_nudge_tween = tw
	tw.finished.connect(_ranch_on_info_card_nudge_tween_finished, CONNECT_ONE_SHOT)
	tw.tween_property(info_card, "scale", Vector2(1.024, 1.024), 0.085).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(info_card, "offset_top", ot0 - lift, 0.085)
	tw.parallel().tween_property(info_card, "offset_bottom", ob0 - lift, 0.085)
	tw.tween_property(info_card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(info_card, "offset_top", ot0, 0.24)
	tw.parallel().tween_property(info_card, "offset_bottom", ob0, 0.24)


func _ranch_info_card_apply_happiness_display(v: float) -> void:
	if dragon_happiness_bar == null:
		return
	var iv: int = int(round(v))
	dragon_happiness_bar.value = v
	_ranch_apply_happiness_bar_fill(dragon_happiness_bar, iv)
	if happiness_mood_label != null:
		var state: String = DragonManager.get_happiness_state_name(iv)
		happiness_mood_label.text = "%d / 100  ·  %s" % [iv, state]
	if growth_bonus_label != null:
		var growth_mult: float = DragonManager.get_happiness_growth_multiplier_for_value(iv)
		var growth_bonus_pct: int = int(round((growth_mult - 1.0) * 100.0))
		var growth_bonus_text: String = ("+" if growth_bonus_pct >= 0 else "") + str(growth_bonus_pct) + "% GP"
		growth_bonus_label.text = "[color=#c9a050]Growth bonus:[/color]  %s" % growth_bonus_text


func _ranch_info_card_apply_fatigue_display(v: float) -> void:
	if training_fatigue_bar == null:
		return
	var iv: int = int(round(v))
	training_fatigue_bar.value = v
	_ranch_apply_fatigue_bar_fill(training_fatigue_bar, iv)
	if training_fatigue_caption != null:
		training_fatigue_caption.text = "Fatigue  %d / 100" % iv


func _ranch_info_card_apply_growth_display(v: float, gp_cap: int) -> void:
	if dragon_growth_bar == null:
		return
	var cap_i: int = maxi(1, gp_cap)
	var gv: float = clampf(v, 0.0, float(cap_i))
	dragon_growth_bar.value = gv
	_ranch_apply_growth_bar_fill(dragon_growth_bar, gv / float(cap_i))
	if growth_fraction_label != null:
		growth_fraction_label.text = "%d / %d  growth points" % [int(round(gv)), cap_i]


func _on_hunt_pressed() -> void:
	if is_feed_animating or is_pet_animating or is_hunt_animating or is_hatch_animating or is_training_animating:
		return

	var selected_index: int = _get_selected_index()
	if selected_index < 0 or selected_index >= DragonManager.player_dragons.size():
		return

	var actor: DragonActor = _get_actor_by_uid(selected_dragon_uid)
	if actor == null:
		return

	if _get_player_gold() < RABBIT_COST:
		if hunt_btn != null:
			hunt_btn.text = "Need %d Gold!" % RABBIT_COST
			var _hunt_wr: WeakRef = weakref(hunt_btn)
			get_tree().create_timer(1.2).timeout.connect(func():
				var b: Button = _hunt_wr.get_ref() as Button
				if b != null:
					b.text = "Throw Rabbit (%d Gold)" % RABBIT_COST
			)
		else:
			actor.show_float_text("Need %d Gold" % RABBIT_COST, Color(1.0, 0.55, 0.25))
		return

	if not _spend_player_gold(RABBIT_COST):
		return

	is_hunt_animating = true
	_update_info_card()
	_trigger_morgra("hunt")
	var throw_result: Dictionary = await _play_rabbit_throw(actor)
	var rabbit_node: Control = throw_result.get("rabbit", null)

	if rabbit_node != null and is_instance_valid(rabbit_node):
		await _run_hunt_chase_simultaneous(actor, rabbit_node)
	else:
		var fallback_target: Vector2 = actor.position + Vector2(actor.size.x * 0.5, actor.size.y * 0.35)
		var fallback_time: float = actor.begin_hunt_step(fallback_target, true)
		await get_tree().create_timer(fallback_time).timeout

	var result: Dictionary = DragonManager.throw_rabbit_for_hunt(selected_index)

	actor.refresh_from_data(DragonManager.player_dragons[selected_index])
	actor.end_hunt_chase(result)
	_update_info_card()

	if rabbit_node != null and is_instance_valid(rabbit_node):
		rabbit_node.queue_free()

	await get_tree().create_timer(0.15).timeout
	is_hunt_animating = false
	_update_info_card()
	
func _play_rabbit_escape_step(rabbit: Control, next_pos: Vector2) -> float:
	var current_pos: Vector2 = rabbit.position
	var rise_time: float = 0.07
	var fall_time: float = 0.08
	var settle_time: float = 0.04

	var peak_pos: Vector2 = (current_pos + next_pos) * 0.5 + Vector2(0.0, -12.0)

	var facing_sign: float = sign(next_pos.x - current_pos.x)
	if facing_sign == 0.0:
		facing_sign = -1.0 if randf() < 0.5 else 1.0

	var shadow: Control = _get_rabbit_shadow(rabbit)
	var foot_pos: Vector2 = current_pos + Vector2(rabbit.size.x * 0.5, rabbit.size.y * 0.78)
	_spawn_rabbit_dust(foot_pos, 0.7)

	var tw: Tween = create_tween()
	tw.tween_property(rabbit, "position", peak_pos, rise_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(rabbit, "rotation", deg_to_rad(-10.0 * facing_sign), rise_time)
	tw.parallel().tween_property(rabbit, "scale", Vector2(1.06, 0.94), rise_time)

	if shadow != null:
		tw.parallel().tween_property(shadow, "scale", Vector2(0.72, 0.72), rise_time)
		tw.parallel().tween_property(shadow, "modulate:a", 0.12, rise_time)

	tw.tween_property(rabbit, "position", next_pos, fall_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(rabbit, "rotation", deg_to_rad(8.0 * facing_sign), fall_time)
	tw.parallel().tween_property(rabbit, "scale", Vector2(0.96, 1.04), fall_time)

	if shadow != null:
		tw.parallel().tween_property(shadow, "scale", Vector2.ONE, fall_time)
		tw.parallel().tween_property(shadow, "modulate:a", 0.22, fall_time)

	tw.tween_callback(func() -> void:
		_spawn_rabbit_dust(next_pos + Vector2(rabbit.size.x * 0.5, rabbit.size.y * 0.78), 0.9)
	)

	tw.tween_property(rabbit, "rotation", 0.0, settle_time)
	tw.parallel().tween_property(rabbit, "scale", Vector2.ONE, settle_time)

	return rise_time + fall_time + settle_time

func _run_hunt_chase_simultaneous(actor: DragonActor, rabbit: Control) -> void:
	if actor == null or rabbit == null:
		return

	var current_pos: Vector2 = rabbit.position
	var hop_count: int = randi_range(3, 5)

	var rabbit_center: Vector2 = current_pos + rabbit.size * 0.5
	var dragon_center: Vector2 = actor.position + actor.size * 0.5
	var away_vec: Vector2 = rabbit_center - dragon_center

	if away_vec.length() <= 0.001:
		away_vec = Vector2(randf_range(-1.0, 1.0), randf_range(-0.7, 0.7))

	var heading: Vector2 = (
		away_vec.normalized() * 0.30 +
		Vector2(randf_range(-1.0, 1.0), randf_range(-0.8, 0.8)).normalized() * 0.70
	).normalized()

	for i in range(hop_count):
		if current_pos.x < 35.0:
			heading.x = abs(heading.x)
		elif current_pos.x > enclosure.size.x - rabbit.size.x - 35.0:
			heading.x = -abs(heading.x)

		if current_pos.y < 20.0:
			heading.y = abs(heading.y)
		elif current_pos.y > enclosure.size.y - rabbit.size.y - 20.0:
			heading.y = -abs(heading.y)

		var jitter: Vector2 = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-0.9, 0.9)
		)

		var chase_heading: Vector2 = heading
		var did_double_back: bool = randf() < 0.24 and i < hop_count - 1

		# Normal panicked wobble
		heading = (heading * 0.45 + jitter * 0.55).normalized()

		# Occasional sharp panic reversal
		if did_double_back:
			var old_heading: Vector2 = heading
			heading = Vector2(
				-old_heading.x + randf_range(-0.35, 0.35),
				(old_heading.y * randf_range(-0.35, 0.35)) + randf_range(-0.45, 0.45)
			).normalized()

			if heading.length() <= 0.001:
				heading = Vector2(-1.0 if randf() < 0.5 else 1.0, randf_range(-0.4, 0.4)).normalized()

			# Dragon commits to the previous direction and overshoots a little.
			chase_heading = old_heading.normalized()
		else:
			chase_heading = heading

		if randf() < 0.18:
			heading.y *= -1.0

		var step_len: float = randf_range(48.0, 92.0)

		var next_pos: Vector2 = current_pos + Vector2(
			heading.x * step_len,
			heading.y * step_len * 0.55
		)

		next_pos.x = float(clamp(next_pos.x, 0.0, max(0.0, enclosure.size.x - rabbit.size.x)))
		next_pos.y = float(clamp(next_pos.y, 0.0, max(0.0, enclosure.size.y - rabbit.size.y)))

		if next_pos.distance_to(current_pos) < 16.0:
			next_pos.x = float(clamp(
				current_pos.x + (-45.0 if randf() < 0.5 else 45.0),
				0.0,
				max(0.0, enclosure.size.x - rabbit.size.x)
			))

		var chase_pos: Vector2 = current_pos + Vector2(
			chase_heading.x * step_len * 0.90,
			chase_heading.y * step_len * 0.40
		)

		chase_pos.x = float(clamp(chase_pos.x, 0.0, max(0.0, enclosure.size.x - rabbit.size.x)))
		chase_pos.y = float(clamp(chase_pos.y, 0.0, max(0.0, enclosure.size.y - rabbit.size.y)))

		var rabbit_target_center: Vector2 = next_pos + rabbit.size * 0.5
		var dragon_target_center: Vector2 = rabbit_target_center
		var overshoot_bonus: float = 0.0
		var is_final: bool = i == hop_count - 1

		if did_double_back:
			dragon_target_center = chase_pos + rabbit.size * 0.5
			overshoot_bonus = 22.0

		var rabbit_time: float = _play_rabbit_escape_step(rabbit, next_pos)
		var dragon_time: float = actor.begin_hunt_step(dragon_target_center, is_final, overshoot_bonus)

		await get_tree().create_timer(max(rabbit_time, dragon_time) + 0.02).timeout
		current_pos = next_pos
		
func _make_rabbit_decoy() -> Control:
	var root: Control = Control.new()
	root.size = Vector2(26, 20)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = 90

	var shadow: ColorRect = ColorRect.new()
	shadow.name = "Shadow"
	shadow.color = Color(0.0, 0.0, 0.0, 0.22)
	shadow.position = Vector2(7, 15)
	shadow.size = Vector2(12, 4)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shadow)

	var body: ColorRect = ColorRect.new()
	body.color = Color(0.92, 0.92, 0.92, 1.0)
	body.position = Vector2(6, 8)
	body.size = Vector2(14, 8)
	root.add_child(body)

	var head: ColorRect = ColorRect.new()
	head.color = Color(0.95, 0.95, 0.95, 1.0)
	head.position = Vector2(1, 6)
	head.size = Vector2(8, 7)
	root.add_child(head)

	var ear1: ColorRect = ColorRect.new()
	ear1.color = Color(0.95, 0.95, 0.95, 1.0)
	ear1.position = Vector2(2, 0)
	ear1.size = Vector2(2, 7)
	root.add_child(ear1)

	var ear2: ColorRect = ColorRect.new()
	ear2.color = Color(0.95, 0.95, 0.95, 1.0)
	ear2.position = Vector2(5, 1)
	ear2.size = Vector2(2, 6)
	root.add_child(ear2)

	return root
	
func _play_rabbit_throw(target_actor: DragonActor) -> Dictionary:
	var rabbit: Control = _make_rabbit_decoy()
	enclosure.add_child(rabbit)

	var shadow: Control = _get_rabbit_shadow(rabbit)

	var start_global: Vector2
	if hunt_btn != null:
		start_global = hunt_btn.global_position + (hunt_btn.size * 0.5)
	else:
		start_global = global_position + Vector2(size.x * 0.5, 40.0)

	var landing_local: Vector2 = target_actor.position + Vector2(
		randf_range(-70.0, 70.0),
		randf_range(15.0, 55.0)
	)

	landing_local.x = float(clamp(landing_local.x, 0.0, max(0.0, enclosure.size.x - rabbit.size.x)))
	landing_local.y = float(clamp(landing_local.y, 0.0, max(0.0, enclosure.size.y - rabbit.size.y)))

	var landing_global: Vector2 = enclosure.global_position + landing_local
	var mid_global: Vector2 = (start_global + landing_global) * 0.5 + Vector2(0, -80)

	rabbit.global_position = start_global - (rabbit.size * 0.5)

	if shadow != null:
		shadow.scale = Vector2(0.85, 0.85)
		shadow.modulate.a = 0.18

	var tw: Tween = create_tween()
	tw.tween_property(rabbit, "global_position", mid_global - (rabbit.size * 0.5), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(rabbit, "rotation", deg_to_rad(-12.0), 0.18)

	if shadow != null:
		tw.parallel().tween_property(shadow, "scale", Vector2(0.68, 0.68), 0.18)
		tw.parallel().tween_property(shadow, "modulate:a", 0.10, 0.18)

	tw.tween_property(rabbit, "global_position", landing_global - (rabbit.size * 0.5), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(rabbit, "rotation", deg_to_rad(8.0), 0.16)

	if shadow != null:
		tw.parallel().tween_property(shadow, "scale", Vector2.ONE, 0.16)
		tw.parallel().tween_property(shadow, "modulate:a", 0.22, 0.16)

	await tw.finished

	_spawn_rabbit_dust(rabbit.position + Vector2(rabbit.size.x * 0.5, rabbit.size.y * 0.78), 0.9)

	var settle: Tween = create_tween()
	settle.tween_property(rabbit, "position:y", rabbit.position.y - 8.0, 0.08).set_trans(Tween.TRANS_SINE)
	settle.tween_property(rabbit, "position:y", rabbit.position.y, 0.10).set_trans(Tween.TRANS_BOUNCE)
	await settle.finished

	return {
		"rabbit": rabbit,
		"target_pos": landing_local
	}
		
func _get_camp_menu() -> Node:
	var p: Node = get_parent()
	if p != null and p.has_method("get_party_gold") and p.has_method("spend_party_gold"):
		return p
	return null

func _get_player_gold() -> int:
	var camp_menu := _get_camp_menu()
	if camp_menu != null:
		return int(camp_menu.get_party_gold())

	return int(CampaignManager.global_gold)

func _spend_player_gold(amount: int) -> bool:
	var camp_menu := _get_camp_menu()
	if camp_menu != null:
		return bool(camp_menu.spend_party_gold(amount))

	if CampaignManager.global_gold < amount:
		return false

	CampaignManager.global_gold -= amount
	return true
func _get_rabbit_shadow(rabbit: Control) -> Control:
	if rabbit == null:
		return null
	return rabbit.get_node_or_null("Shadow")


func _spawn_rabbit_dust(at_pos: Vector2, strength: float = 1.0) -> void:
	for i in range(4):
		var puff: ColorRect = ColorRect.new()
		puff.color = Color(0.82, 0.74, 0.62, 0.78)
		puff.size = Vector2(4, 4)
		puff.pivot_offset = puff.size * 0.5
		puff.position = at_pos + Vector2(
			randf_range(-7.0, 7.0),
			randf_range(-3.0, 2.0)
		)
		puff.mouse_filter = Control.MOUSE_FILTER_IGNORE
		puff.z_index = 84
		enclosure.add_child(puff)

		var drift: Vector2 = Vector2(
			randf_range(-16.0, 16.0),
			randf_range(-16.0, -6.0)
		) * strength

		var tw: Tween = puff.create_tween()
		tw.tween_property(puff, "position", puff.position + drift, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(puff, "scale", Vector2(1.8, 1.8), 0.24)
		tw.parallel().tween_property(puff, "modulate:a", 0.0, 0.24)
		tw.finished.connect(func() -> void:
			if is_instance_valid(puff):
				puff.queue_free()
		)
# ==========================================
# EPIC EGG HATCHING
# ==========================================
func _find_egg_index() -> int:
	for i in range(CampaignManager.global_inventory.size()):
		var item = CampaignManager.global_inventory[i]
		if item is ConsumableData:
			var i_name: String = str(item.item_name).to_lower()
			if "egg" in i_name:
				return i
	return -1

func _set_hatch_btn_temp_text(text: String, reset_text: String = "Hatch Egg", delay: float = 1.5) -> void:
	if hatch_btn == null: return
	hatch_btn.text = text
	var _hatch_wr: WeakRef = weakref(hatch_btn)
	get_tree().create_timer(delay).timeout.connect(func():
		var b: Button = _hatch_wr.get_ref() as Button
		if b != null:
			b.text = reset_text
	)

func _get_element_reveal_color(element_name: String) -> Color:
	match element_name:
		"Fire": return Color(1.0, 0.45, 0.08, 1.0)
		"Ice": return Color(0.72, 0.92, 1.0, 1.0)
		"Lightning": return Color(1.0, 0.92, 0.22, 1.0)
		"Earth": return Color(0.52, 0.36, 0.18, 1.0)
		"Wind": return Color(0.82, 1.0, 0.92, 1.0)
		_: return Color.WHITE

func _on_hatch_pressed() -> void:
	if is_feed_animating or is_pet_animating or is_hunt_animating or is_hatch_animating or is_training_animating:
		return
		
	_trigger_morgra("hatch")
	
	# Find ALL eggs in the inventory
	var found_eggs = []
	for i in range(CampaignManager.global_inventory.size()):
		var item = CampaignManager.global_inventory[i]
		if item is ConsumableData:
			var i_name = str(item.item_name).to_lower()
			if "egg" in i_name:
				found_eggs.append({"index": i, "item": item})

	if found_eggs.is_empty():
		_set_hatch_btn_temp_text("No Eggs in Inventory!")
		return

		
	# --- OPEN THE EGG SELECTOR MENU ---
	selecting_for_slot = "EGG"
	for child in selection_vbox.get_children():
		child.queue_free()
		
	var title = Label.new()
	title.text = "--- CHOOSE AN EGG ---"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.GOLD)
	selection_vbox.add_child(title)
		
	for egg_data in found_eggs:
		var idx = egg_data["index"]
		var item = egg_data["item"]
		
		var btn = Button.new()
		btn.text = str(item.item_name)
		btn.custom_minimum_size = Vector2(0, 60)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		style.border_width_bottom = 2
		style.border_color = Color.GOLD if "Bred" in item.item_name else Color.GRAY
		btn.add_theme_stylebox_override("normal", style)
		
		if item.get("icon") != null:
			btn.icon = item.icon
			btn.expand_icon = true
			
		btn.pressed.connect(func(): _on_egg_chosen(idx))
		selection_vbox.add_child(btn)

	breed_selection_popup.show()
	if breed_selection_popup != null:
		breed_selection_popup.move_to_front()

func _on_egg_chosen(egg_index: int) -> void:
	breed_selection_popup.hide()
	is_hatch_animating = true
	info_card.hide()
	
	# Grab the exact item data
	var egg_item = CampaignManager.global_inventory[egg_index]
	var is_bred_egg = "bred" in str(egg_item.item_name).to_lower()
	var egg_uid = egg_item.get_meta("egg_uid", "")
	
	# Consume the exact egg
	CampaignManager.global_inventory.remove_at(egg_index)

	# --- PULL FROM QUEUE IF BRED, OTHERWISE ROLL WILD ---
	var new_baby: Dictionary
	if is_bred_egg:
		new_baby = DragonManager.hatch_bred_egg(egg_uid)
	else:
		new_baby = DragonManager.hatch_egg()

	if new_baby.is_empty():
		is_hatch_animating = false
		_set_hatch_btn_temp_text("Hatch Failed!")
		return

	# ==========================================
	# THE CINEMATIC LOGIC
	# ==========================================
	var traits_array: Array = new_baby.get("traits", [])
	var is_rare_hatch: bool = traits_array.size() >= 2
	var elem_color: Color = _get_element_reveal_color(str(new_baby.get("element", "")))
	var bg_glow_color: Color = Color(1.0, 0.85, 0.2, 1.0) if is_rare_hatch else elem_color

	var camp_music: AudioStreamPlayer = get_node_or_null("../CampMusic")
	var masterwork_sound: AudioStreamPlayer = get_node_or_null("../MasterworkSound")

	var stashed_dragons: Array = _breed_hide_enclosure_dragons()

	var hatch_layer := CanvasLayer.new()
	hatch_layer.layer = 150
	add_child(hatch_layer)

	var vp_size: Vector2 = get_viewport_rect().size
	var center: Vector2 = vp_size * 0.5

	var stage_root := Control.new()
	stage_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_root.size = vp_size
	stage_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hatch_layer.add_child(stage_root)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.0)
	dimmer.size = vp_size
	stage_root.add_child(dimmer)

	var rim_glow: Color = bg_glow_color.lightened(0.08)
	var rim_mix: float = 0.2 if is_rare_hatch else 0.35

	var ritual_ring := Panel.new()
	ritual_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ritual_ring.size = Vector2(300, 300)
	ritual_ring.pivot_offset = ritual_ring.size * 0.5
	ritual_ring.position = center - ritual_ring.size * 0.5
	ritual_ring.z_index = 4
	ritual_ring.modulate.a = 0.0
	ritual_ring.add_theme_stylebox_override("panel", _breed_make_ritual_ring_style(rim_glow, 3, 150))
	stage_root.add_child(ritual_ring)

	var core_panel := Panel.new()
	core_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	core_panel.size = Vector2(248, 248)
	core_panel.pivot_offset = core_panel.size * 0.5
	core_panel.position = center - core_panel.size * 0.5
	core_panel.z_index = 5
	core_panel.scale = Vector2(0.52, 0.52)
	core_panel.modulate.a = 0.0
	core_panel.add_theme_stylebox_override(
		"panel",
		_breed_make_ritual_core_style(bg_glow_color, rim_glow.lerp(elem_color, rim_mix), 0.15, 2, 124)
	)
	stage_root.add_child(core_panel)

	var beam_panel := Panel.new()
	beam_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beam_panel.size = Vector2(32, 260)
	beam_panel.pivot_offset = beam_panel.size * 0.5
	beam_panel.position = center - beam_panel.size * 0.5 + Vector2(0, 12)
	beam_panel.z_index = 6
	beam_panel.scale = Vector2(0.25, 0.18)
	beam_panel.modulate.a = 0.0
	beam_panel.add_theme_stylebox_override("panel", _breed_make_energy_beam_style(bg_glow_color, 16))
	stage_root.add_child(beam_panel)

	var egg_corona := Panel.new()
	egg_corona.mouse_filter = Control.MOUSE_FILTER_IGNORE
	egg_corona.size = Vector2(200, 200)
	egg_corona.pivot_offset = egg_corona.size * 0.5
	egg_corona.position = center - egg_corona.size * 0.5 + Vector2(0, 130)
	egg_corona.z_index = 12
	egg_corona.scale = Vector2(0.92, 0.92)
	egg_corona.modulate.a = 0.0
	var hatch_corona_sb := StyleBoxFlat.new()
	hatch_corona_sb.bg_color = Color(bg_glow_color.r, bg_glow_color.g, bg_glow_color.b, 0.12)
	hatch_corona_sb.border_color = rim_glow
	hatch_corona_sb.set_border_width_all(2)
	hatch_corona_sb.set_corner_radius_all(100)
	hatch_corona_sb.shadow_color = Color(bg_glow_color.r, bg_glow_color.g, bg_glow_color.b, 0.5)
	hatch_corona_sb.shadow_size = 16
	egg_corona.add_theme_stylebox_override("panel", hatch_corona_sb)
	stage_root.add_child(egg_corona)

	var temp_egg := TextureRect.new()
	temp_egg.texture = EGG_ICON
	temp_egg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	temp_egg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	temp_egg.custom_minimum_size = Vector2(128, 160)
	temp_egg.size = Vector2(128, 160)
	temp_egg.pivot_offset = temp_egg.size * 0.5
	temp_egg.position = center - temp_egg.size * 0.5 + Vector2(0, 130)
	temp_egg.z_index = 15
	temp_egg.modulate.a = 0.0
	stage_root.add_child(temp_egg)

	var flash := ColorRect.new()
	flash.z_index = 90
	flash.size = vp_size
	flash.color = Color(bg_glow_color.r * 0.22 + 0.78, bg_glow_color.g * 0.22 + 0.78, bg_glow_color.b * 0.22 + 0.78, 0.0)
	stage_root.add_child(flash)

	var orig_vol: float = 0.0
	if camp_music != null and camp_music.playing:
		orig_vol = camp_music.volume_db
		create_tween().tween_property(camp_music, "volume_db", -15.0, 0.8)

	var intro_tw := create_tween().set_parallel(true)
	intro_tw.tween_property(dimmer, "color:a", 0.92, 1.2)
	intro_tw.tween_property(ritual_ring, "modulate:a", 0.95, 1.0)
	intro_tw.tween_property(core_panel, "modulate:a", 0.22, 1.0)
	intro_tw.tween_property(core_panel, "scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(beam_panel, "modulate:a", 0.11, 0.95)
	intro_tw.tween_property(beam_panel, "scale", Vector2(0.48, 0.34), 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var egg_settled_pos: Vector2 = center - temp_egg.size * 0.5
	var corona_settled_pos: Vector2 = center - egg_corona.size * 0.5
	intro_tw.tween_property(temp_egg, "position", egg_settled_pos, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(egg_corona, "position", corona_settled_pos, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(egg_corona, "modulate:a", 0.88, 0.9)
	intro_tw.tween_property(egg_corona, "scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(temp_egg, "modulate:a", 1.0, 0.8)
	await intro_tw.finished

	var spark_color: Color = Color(1.0, 0.82, 0.38) if is_rare_hatch else elem_color
	var ambient_sparks: CPUParticles2D = _spawn_breed_ambient_sparks(stage_root, center + Vector2(0, 28), spark_color)

	for i in range(3):
		var pulse_tw := create_tween().set_parallel(true)
		pulse_tw.tween_property(core_panel, "scale", Vector2(1.12, 1.12), 0.16).set_trans(Tween.TRANS_SINE)
		pulse_tw.tween_property(core_panel, "modulate:a", 0.34, 0.16)
		pulse_tw.tween_property(ritual_ring, "rotation", ritual_ring.rotation + 0.52, 0.16)
		pulse_tw.tween_property(beam_panel, "modulate:a", 0.20, 0.16)
		pulse_tw.tween_property(beam_panel, "scale", Vector2(0.56, 0.44), 0.16)
		pulse_tw.tween_property(egg_corona, "scale", Vector2(1.06, 1.06), 0.16).set_trans(Tween.TRANS_SINE)
		pulse_tw.tween_property(temp_egg, "scale", Vector2(1.06, 1.06), 0.16).set_trans(Tween.TRANS_SINE)
		pulse_tw.tween_property(temp_egg, "rotation", deg_to_rad(7.0), 0.08)
		pulse_tw.chain().tween_property(temp_egg, "rotation", deg_to_rad(-7.0), 0.08)
		await pulse_tw.finished

		var release_tw := create_tween().set_parallel(true)
		release_tw.tween_property(core_panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE)
		release_tw.tween_property(core_panel, "modulate:a", 0.20, 0.14)
		release_tw.tween_property(beam_panel, "scale", Vector2(0.48, 0.34), 0.14)
		release_tw.tween_property(beam_panel, "modulate:a", 0.11, 0.14)
		release_tw.tween_property(egg_corona, "scale", Vector2.ONE, 0.14)
		release_tw.tween_property(temp_egg, "scale", Vector2.ONE, 0.14)
		release_tw.tween_property(temp_egg, "rotation", 0.0, 0.14)
		await release_tw.finished

	if ambient_sparks != null and is_instance_valid(ambient_sparks):
		ambient_sparks.emitting = false

	var shake_tw := create_tween()
	for i in range(8):
		var x_off: float = randf_range(-14.0, 14.0)
		var y_off: float = randf_range(-6.0, 6.0)
		shake_tw.tween_property(temp_egg, "position", (center - temp_egg.size * 0.5) + Vector2(x_off, y_off), 0.035)
		shake_tw.parallel().tween_property(temp_egg, "rotation", deg_to_rad(randf_range(-20.0, 20.0)), 0.035)
		shake_tw.parallel().tween_property(temp_egg, "modulate", Color(1.6, 1.6, 1.6, 1.0), 0.035)

	shake_tw.tween_property(temp_egg, "position", center - temp_egg.size * 0.5, 0.04)
	shake_tw.parallel().tween_property(temp_egg, "rotation", 0.0, 0.04)
	await shake_tw.finished

	if masterwork_sound != null and masterwork_sound.stream != null:
		var boom := AudioStreamPlayer.new()
		boom.stream = masterwork_sound.stream
		boom.pitch_scale = 0.72
		boom.volume_db = -10.0
		add_child(boom)
		boom.play()
		boom.finished.connect(boom.queue_free)

	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = false
	burst.explosiveness = 0.95
	burst.amount = 140
	burst.lifetime = 1.15
	burst.spread = 180.0
	burst.initial_velocity_min = 260.0
	burst.initial_velocity_max = 520.0
	burst.scale_amount_min = 6.0
	burst.scale_amount_max = 12.0
	burst.color = elem_color
	burst.position = center
	burst.z_index = 8
	stage_root.add_child(burst)

	var rare_burst: CPUParticles2D = null
	if is_rare_hatch:
		rare_burst = CPUParticles2D.new()
		rare_burst.one_shot = true
		rare_burst.emitting = false
		rare_burst.explosiveness = 0.85
		rare_burst.amount = 80
		rare_burst.lifetime = 1.5
		rare_burst.spread = 180.0
		rare_burst.initial_velocity_min = 400.0
		rare_burst.initial_velocity_max = 850.0
		rare_burst.scale_amount_min = 5.0
		rare_burst.scale_amount_max = 16.0
		rare_burst.color = Color(1.0, 0.85, 0.2, 1.0)
		rare_burst.position = center
		rare_burst.z_index = 8
		stage_root.add_child(rare_burst)

	var pop_tw := create_tween().set_parallel(true)
	pop_tw.tween_property(flash, "color:a", 0.74, 0.07)
	pop_tw.tween_property(core_panel, "modulate:a", 0.68, 0.07)
	pop_tw.tween_property(beam_panel, "modulate:a", 0.58, 0.07)
	await pop_tw.finished

	burst.emitting = true
	if rare_burst != null:
		rare_burst.emitting = true

	_shake_enclosure(14.0, 0.30)

	if is_instance_valid(temp_egg):
		temp_egg.queue_free()
	if is_instance_valid(egg_corona):
		egg_corona.queue_free()

	var showcase_actor: DragonActor = DRAGON_ACTOR_SCENE.instantiate()
	showcase_actor.z_index = 25
	stage_root.add_child(showcase_actor)

	if showcase_actor != null and is_instance_valid(showcase_actor):
		showcase_actor.setup(new_baby)
		showcase_actor.set_cinematic_mode(true)
		showcase_actor.position = center - (showcase_actor.size * 0.5)
		showcase_actor.scale = Vector2(0.12, 0.12)
		showcase_actor.modulate.a = 0.0
	else:
		_breed_restore_enclosure_dragons(stashed_dragons)
		if is_instance_valid(hatch_layer):
			hatch_layer.queue_free()
		is_hatch_animating = false
		return

	var name_lbl := Label.new()
	name_lbl.z_index = 100
	if is_rare_hatch:
		name_lbl.text = "⭐ RARE HATCH! ⭐\n" + str(new_baby.get("name", "DRAGON")).to_upper()
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0)) 
	else:
		name_lbl.text = "YOU HATCHED A " + str(new_baby.get("name", "DRAGON")).to_upper() + "!"
		name_lbl.add_theme_color_override("font_color", elem_color)
		
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 44)
	name_lbl.add_theme_constant_override("outline_size", 10)
	name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	name_lbl.position = Vector2(0, center.y - 280.0)
	name_lbl.size.x = vp_size.x
	name_lbl.modulate.a = 0.0
	stage_root.add_child(name_lbl)

	var trait_lbl := Label.new()
	trait_lbl.z_index = 100
	if traits_array.is_empty():
		trait_lbl.text = "No special traits."
		trait_lbl.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	else:
		trait_lbl.text = "Traits: " + ", ".join(traits_array)
		trait_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0) if is_rare_hatch else Color.GOLD)

	trait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trait_lbl.add_theme_font_size_override("font_size", 30)
	trait_lbl.add_theme_constant_override("outline_size", 8)
	trait_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	trait_lbl.position = Vector2(0, center.y + 145.0)
	trait_lbl.size.x = vp_size.x
	trait_lbl.modulate.a = 0.0
	stage_root.add_child(trait_lbl)

	var element_lbl := Label.new()
	element_lbl.z_index = 100
	element_lbl.text = str(new_baby.get("element", "Unknown")) + " Element"
	element_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	element_lbl.add_theme_font_size_override("font_size", 26)
	element_lbl.add_theme_color_override("font_color", Color.WHITE)
	element_lbl.add_theme_constant_override("outline_size", 8)
	element_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	element_lbl.position = Vector2(0, center.y + 108.0)
	element_lbl.size.x = vp_size.x
	element_lbl.modulate.a = 0.0
	stage_root.add_child(element_lbl)

	var reveal_tw := create_tween().set_parallel(true)
	reveal_tw.tween_property(flash, "color:a", 0.0, 0.35)
	reveal_tw.tween_property(core_panel, "modulate:a", 0.28, 0.45)
	reveal_tw.tween_property(beam_panel, "modulate:a", 0.0, 0.30)
	reveal_tw.tween_property(showcase_actor, "scale", Vector2(2.35, 2.35), 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	reveal_tw.tween_property(showcase_actor, "modulate:a", 1.0, 0.25)
	reveal_tw.tween_property(name_lbl, "modulate:a", 1.0, 0.35)
	reveal_tw.tween_property(trait_lbl, "modulate:a", 1.0, 0.45)
	reveal_tw.tween_property(element_lbl, "modulate:a", 1.0, 0.40)
	await reveal_tw.finished

	var pride_tw := create_tween()
	pride_tw.tween_property(showcase_actor, "scale", Vector2(2.48, 2.48), 0.16).set_trans(Tween.TRANS_SINE)
	pride_tw.tween_property(showcase_actor, "scale", Vector2(2.35, 2.35), 0.18).set_trans(Tween.TRANS_BOUNCE)
	await pride_tw.finished

	await get_tree().create_timer(3.0).timeout

	var cleanup_tw := create_tween().set_parallel(true)
	cleanup_tw.tween_property(dimmer, "color:a", 0.0, 0.55)
	cleanup_tw.tween_property(ritual_ring, "modulate:a", 0.0, 0.45)
	cleanup_tw.tween_property(core_panel, "modulate:a", 0.0, 0.45)
	cleanup_tw.tween_property(beam_panel, "modulate:a", 0.0, 0.45)
	cleanup_tw.tween_property(flash, "color:a", 0.0, 0.45)
	cleanup_tw.tween_property(showcase_actor, "modulate:a", 0.0, 0.45)
	cleanup_tw.tween_property(name_lbl, "modulate:a", 0.0, 0.45)
	cleanup_tw.tween_property(trait_lbl, "modulate:a", 0.0, 0.45)
	cleanup_tw.tween_property(element_lbl, "modulate:a", 0.0, 0.45)

	if camp_music != null:
		cleanup_tw.tween_property(camp_music, "volume_db", orig_vol, 0.7)

	await cleanup_tw.finished

	_breed_restore_enclosure_dragons(stashed_dragons)
	if is_instance_valid(hatch_layer):
		hatch_layer.queue_free()

	# If the ranch was closed during the cinematic, abort safely.
	if not is_instance_valid(self) or not visible:
		is_hatch_animating = false
		return

	_spawn_dragons()

	# Let the freshly spawned actors enter the tree properly.
	await get_tree().process_frame

	if not is_instance_valid(self) or not visible:
		is_hatch_animating = false
		return

	selected_dragon_uid = str(new_baby.get("uid", ""))
	_refresh_actor_selection()

	var final_actor: DragonActor = _get_actor_by_uid(selected_dragon_uid)
	if final_actor != null and is_instance_valid(final_actor):
		final_actor.position = (enclosure.size - final_actor.size) * 0.5
		final_actor.scale = Vector2.ZERO

		if is_instance_valid(final_actor):
			final_actor.set_cinematic_mode(true)

		var final_tw := create_tween()
		final_tw.tween_property(final_actor, "scale", Vector2(1.18, 1.18), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		final_tw.tween_property(final_actor, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BOUNCE)
		await final_tw.finished

		if final_actor != null and is_instance_valid(final_actor):
			final_actor.set_cinematic_mode(false)

	_update_info_card()
	info_card.show()
	is_hatch_animating = false
	
# ==========================================
# BREEDING STATION UI
# ==========================================

func _open_breeding_station() -> void:
	selected_parent_a_index = -1
	selected_parent_b_index = -1
	if info_card != null and is_instance_valid(info_card):
		_info_card_was_visible_before_breed = info_card.visible
		info_card.hide()
	_set_herder_chrome_visible(false)
	_ensure_breeding_station_fx_ui()
	_refresh_breeding_ui()
	if breed_dimmer != null and is_instance_valid(breed_dimmer):
		breed_dimmer.color = BREED_STATION_DIMMER_COLOR
		breed_dimmer.visible = true
	breed_panel.show()
	_ranch_raise_breeding_station_input_stack()

func _open_parent_selector(slot: String) -> void:
	selecting_for_slot = slot
	
	# Clear the old list
	for child in selection_vbox.get_children():
		child.queue_free()
		
	# Populate with valid Adult dragons
	var found_any = false
	for i in range(DragonManager.player_dragons.size()):
		var d = DragonManager.player_dragons[i]
		
		# Rule: Must be Adult, and must not be on cooldown
		if d.get("stage", 0) < DragonManager.DragonStage.ADULT: continue
		if d.get("breed_cooldown", 0) > 0: continue
		
		# Prevent selecting the same dragon for both slots
		if slot == "A" and selected_parent_b_index == i: continue
		if slot == "B" and selected_parent_a_index == i: continue
		
		found_any = true
		var btn := Button.new()
		var d_name = str(d.get("name", "Dragon"))
		var d_gen = str(d.get("generation", 1))
		var d_elem = str(d.get("element", "Unknown"))
		
		btn.text = "Gen " + d_gen + " " + d_name + " (" + d_elem + ")"
		btn.pressed.connect(func(): _on_parent_chosen(i))
		selection_vbox.add_child(btn)
		_CampUiSkin.style_button(btn, false, 18, 48.0)
		
	if not found_any:
		var lbl := Label.new()
		lbl.text = "No eligible adult dragons available!"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		selection_vbox.add_child(lbl)
		_CampUiSkin.style_label(lbl, _CampUiSkin.CAMP_MUTED, 17)
		
	breed_selection_popup.show()
	if breed_selection_popup != null:
		breed_selection_popup.move_to_front()

func _on_parent_chosen(dragon_index: int) -> void:
	if selecting_for_slot == "A":
		selected_parent_a_index = dragon_index
	elif selecting_for_slot == "B":
		selected_parent_b_index = dragon_index
		
	breed_selection_popup.hide()
	_refresh_breeding_ui()

func _refresh_breeding_ui() -> void:
	_ensure_breeding_station_fx_ui()
	_layout_breeding_station_fx_ui()

	var has_rose: bool = DragonManager._find_inventory_consumable_index_by_name(DragonManager.BREED_REQUIRED_ITEM_NAME) != -1

	# Parent A (caption strip + anchored art — no label drawn over dragon)
	var chrome_a: Dictionary = _ranch_ensure_breed_slot_chrome(parent_a_btn)
	_ranch_style_breed_slot_caption(chrome_a.caption)
	if selected_parent_a_index != -1:
		var pA: Dictionary = DragonManager.player_dragons[selected_parent_a_index]
		var elem_a: String = str(pA.get("element", "Unknown"))
		var color_a: Color = _get_element_reveal_color(elem_a)

		parent_a_btn.text = ""
		chrome_a.caption.text = "%s\nGen %d  •  Bond %d  •  Happy %d" % [
			str(pA.get("name", "Dragon")),
			int(pA.get("generation", 1)),
			int(pA.get("bond", 0)),
			int(pA.get("happiness", 50))
		]
		_set_parent_button_style(parent_a_btn, color_a, true)
		_ranch_style_breed_slot_strip(chrome_a.strip, color_a, true)

		if parent_a_sprite != null:
			parent_a_sprite.texture = load("res://Assets/Sprites/" + elem_a.to_lower() + "_dragon_sprite.png")
			parent_a_sprite.show()

		_start_parent_slot_pulse("A", parent_a_sprite, parent_a_btn, color_a)
		_ranch_layout_breed_slot(parent_a_btn, parent_a_sprite, chrome_a.strip, chrome_a.caption, true)
	else:
		parent_a_btn.text = ""
		chrome_a.caption.text = "Parent A\nChoose an adult dragon"
		_set_parent_button_style(parent_a_btn, Color.WHITE, false)
		_ranch_style_breed_slot_strip(chrome_a.strip, _CampUiSkin.CAMP_BORDER_SOFT, false)
		if parent_a_sprite != null:
			parent_a_sprite.hide()

		_kill_breed_ui_tween(breed_parent_a_tween)
		if parent_a_sprite != null:
			parent_a_sprite.scale = Vector2.ONE
			parent_a_sprite.modulate = Color.WHITE
		_ranch_layout_breed_slot(parent_a_btn, parent_a_sprite, chrome_a.strip, chrome_a.caption, false)

	# Parent B
	var chrome_b: Dictionary = _ranch_ensure_breed_slot_chrome(parent_b_btn)
	_ranch_style_breed_slot_caption(chrome_b.caption)
	if selected_parent_b_index != -1:
		var pB: Dictionary = DragonManager.player_dragons[selected_parent_b_index]
		var elem_b: String = str(pB.get("element", "Unknown"))
		var color_b: Color = _get_element_reveal_color(elem_b)

		parent_b_btn.text = ""
		chrome_b.caption.text = "%s\nGen %d  •  Bond %d  •  Happy %d" % [
			str(pB.get("name", "Dragon")),
			int(pB.get("generation", 1)),
			int(pB.get("bond", 0)),
			int(pB.get("happiness", 50))
		]
		_set_parent_button_style(parent_b_btn, color_b, true)
		_ranch_style_breed_slot_strip(chrome_b.strip, color_b, true)

		if parent_b_sprite != null:
			parent_b_sprite.texture = load("res://Assets/Sprites/" + elem_b.to_lower() + "_dragon_sprite.png")
			parent_b_sprite.show()

		_start_parent_slot_pulse("B", parent_b_sprite, parent_b_btn, color_b)
		_ranch_layout_breed_slot(parent_b_btn, parent_b_sprite, chrome_b.strip, chrome_b.caption, true)
	else:
		parent_b_btn.text = ""
		chrome_b.caption.text = "Parent B\nChoose an adult dragon"
		_set_parent_button_style(parent_b_btn, Color.WHITE, false)
		_ranch_style_breed_slot_strip(chrome_b.strip, _CampUiSkin.CAMP_BORDER_SOFT, false)
		if parent_b_sprite != null:
			parent_b_sprite.hide()

		_kill_breed_ui_tween(breed_parent_b_tween)
		if parent_b_sprite != null:
			parent_b_sprite.scale = Vector2.ONE
			parent_b_sprite.modulate = Color.WHITE
		_ranch_layout_breed_slot(parent_b_btn, parent_b_sprite, chrome_b.strip, chrome_b.caption, false)

	if selected_parent_a_index == -1 or selected_parent_b_index == -1:
		prediction_label.text = "[center][color=gray]Select two adult dragons to see resonance, compatibility, and predicted quality.[/color][/center]"
		confirm_breed_btn.disabled = true
		confirm_breed_btn.text = "Waiting for parents..."
		breed_compat_bar_fill.size.x = 0.0
		breed_compat_value_label.text = "Compatibility: --"
		breed_mutation_label.text = "[center][color=gray]No bloodline preview yet.[/color][/center]"
		breed_prediction_backplate.color = Color(0.07, 0.055, 0.04, 0.88)
		_stop_breeding_preview_fx()
		return

	var preview: Dictionary = DragonManager.get_breeding_preview(selected_parent_a_index, selected_parent_b_index)

	if not bool(preview.get("success", false)):
		prediction_label.text = "[center][color=red]%s[/color][/center]" % str(preview.get("error", "Preview failed."))
		confirm_breed_btn.disabled = true
		confirm_breed_btn.text = "Cannot breed"
		breed_compat_bar_fill.size.x = 0.0
		breed_compat_value_label.text = "Compatibility: 0"
		breed_mutation_label.text = "[center][color=gray]Breeding preview unavailable.[/color][/center]"
		breed_prediction_backplate.color = Color(0.18, 0.06, 0.05, 0.90)
		_stop_breeding_preview_fx()
		return

	var quality: String = str(preview.get("quality", "Common"))
	var quality_color: Color = _get_quality_color(quality)
	var quality_hex: String = quality_color.to_html(false)

	var score: int = int(preview.get("compatibility_score", 0))
	var tier: String = str(preview.get("compatibility_tier", "Unknown"))
	var generation: int = int(preview.get("generation", 1))
	var element_text: String = str(preview.get("element_text", "Unknown"))
	var mutated_traits: Array = preview.get("mutated_traits", [])
	var guaranteed_traits: Array = preview.get("guaranteed_traits", [])
	var possible_traits: Array = preview.get("possible_traits", [])
	var resonance_tags: Array = preview.get("resonance_tags", [])

	var tag_text: String = "None"
	if not resonance_tags.is_empty():
		tag_text = " • ".join(resonance_tags)

	var mutation_text: String = "None"
	if not mutated_traits.is_empty():
		mutation_text = ", ".join(mutated_traits)

	var guaranteed_text: String = "None"
	if not guaranteed_traits.is_empty():
		guaranteed_text = ", ".join(guaranteed_traits)

	var possible_text: String = "None"
	if not possible_traits.is_empty():
		possible_text = ", ".join(possible_traits)

	prediction_label.text = (
		"[center]" +
		"[color=%s][b]%s OFFSPRING[/b][/color]\n" % [quality_hex, quality] +
		"Generation: [color=lime]%d[/color]\n" % generation +
		"Element: [color=cyan]%s[/color]\n" % element_text +
		"Tier: [color=white]%s[/color]\n" % tier +
		"[color=gray]%s[/color]" % tag_text +
		"[/center]"
	)

	breed_mutation_label.text = (
		"[center]" +
		"[color=gold]Mutations:[/color] %s\n" % mutation_text +
		"[color=lime]Guaranteed:[/color] %s\n" % guaranteed_text +
		"[color=white]Possible Pool:[/color] %s" % possible_text +
		"[/center]"
	)

	var bar_width: float = breed_compat_bar_bg.size.x * (float(score) / 100.0)
	breed_compat_bar_fill.color = quality_color
	breed_compat_bar_fill.size = Vector2(bar_width, breed_compat_bar_bg.size.y)
	breed_compat_value_label.text = "Compatibility: %d / 100" % score

	var backplate_color: Color = quality_color.darkened(0.78)
	backplate_color.a = 0.92
	breed_prediction_backplate.color = backplate_color

	if has_rose:
		confirm_breed_btn.disabled = false
		confirm_breed_btn.text = "BREED DRAGONS\n(-1 Dragon Rose)"
	else:
		confirm_breed_btn.disabled = true
		confirm_breed_btn.text = "MISSING DRAGON ROSE"

	_start_breeding_preview_fx(preview)
	
func _resource_has_property(obj: Object, prop_name: String) -> bool:
	if obj == null:
		return false

	for prop in obj.get_property_list():
		if str(prop.get("name", "")) == prop_name:
			return true

	return false


func _infer_breed_quality(result: Dictionary) -> String:
	if result.has("quality"):
		return str(result.get("quality", "Common"))

	var gen: int = int(result.get("generation", 1))
	var mutated: Array = result.get("mutated_traits", [])
	var inherited: Array = result.get("inherited_traits", [])

	var score: int = 0
	score += gen * 10
	score += mutated.size() * 24
	score += inherited.size() * 6

	if score >= 95:
		return "Legendary"
	elif score >= 70:
		return "Epic"
	elif score >= 45:
		return "Rare"
	return "Common"


func _get_breed_quality_color(quality: String) -> Color:
	match quality:
		"Legendary":
			return Color(1.0, 0.86, 0.25, 1.0)
		"Epic":
			return Color(0.82, 0.58, 1.0, 1.0)
		"Rare":
			return Color(0.45, 0.85, 1.0, 1.0)
		_:
			return Color(0.92, 0.92, 0.92, 1.0)


func _get_breed_element_mix_color(parent_a: Dictionary, parent_b: Dictionary) -> Color:
	var color_a: Color = _get_element_reveal_color(str(parent_a.get("element", "")))
	var color_b: Color = _get_element_reveal_color(str(parent_b.get("element", "")))
	return color_a.lerp(color_b, 0.5)


func _spawn_breeding_cinematic_actor(
	stage_root: Control,
	dragon_data: Dictionary,
	start_pos: Vector2,
	face_dir: float,
	z_idx: int = 20
) -> DragonActor:
	var actor: DragonActor = DRAGON_ACTOR_SCENE.instantiate()
	actor.facing = -1.0 if face_dir < 0.0 else 1.0
	stage_root.add_child(actor)
	actor.z_index = z_idx
	actor.setup(dragon_data)
	actor.set_cinematic_mode(true)
	actor.position = start_pos
	actor.scale = Vector2(0.95, 0.95)
	actor.modulate.a = 0.0
	return actor


func _spawn_magic_burst(
	stage_root: Control,
	at_pos: Vector2,
	color: Color,
	amount: int = 90,
	lifetime: float = 1.0,
	speed_min: float = 160.0,
	speed_max: float = 360.0,
	spread: float = 180.0,
	scale_min: float = 5.0,
	scale_max: float = 12.0
) -> CPUParticles2D:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.emitting = false
	burst.explosiveness = 0.90
	burst.amount = amount
	burst.lifetime = lifetime
	burst.spread = spread
	burst.initial_velocity_min = speed_min
	burst.initial_velocity_max = speed_max
	burst.scale_amount_min = scale_min
	burst.scale_amount_max = scale_max
	burst.color = color
	burst.position = at_pos
	stage_root.add_child(burst)
	burst.emitting = true

	var _burst_wr: WeakRef = weakref(burst)
	get_tree().create_timer(lifetime + 0.6).timeout.connect(func() -> void:
		var n: Node = _burst_wr.get_ref() as Node
		if n != null:
			n.queue_free()
	)

	return burst


func _breed_hide_enclosure_dragons() -> Array:
	var stashed: Array = []
	if enclosure == null or not is_instance_valid(enclosure):
		return stashed
	for child in enclosure.get_children():
		if child.has_meta("is_dragon") and child is CanvasItem:
			stashed.append({"node": child, "vis": (child as CanvasItem).visible})
			(child as CanvasItem).visible = false
	return stashed


func _breed_restore_enclosure_dragons(stashed: Array) -> void:
	for entry in stashed:
		if entry is Dictionary:
			var n: Variant = entry.get("node")
			if n is CanvasItem and is_instance_valid(n):
				(n as CanvasItem).visible = bool(entry.get("vis", true))


func _breed_make_ritual_ring_style(rim: Color, width: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = rim
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	return sb


func _breed_make_ritual_core_style(fill: Color, rim: Color, fill_a: float, rim_w: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(fill.r, fill.g, fill.b, fill_a)
	sb.border_color = rim
	sb.set_border_width_all(rim_w)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(fill.r, fill.g, fill.b, 0.5)
	sb.shadow_size = 22
	sb.shadow_offset = Vector2(0, 0)
	return sb


func _breed_make_energy_beam_style(fill: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(fill.r, fill.g, fill.b, 0.52)
	sb.border_color = fill.lightened(0.38)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(fill.r, fill.g, fill.b, 0.4)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 0)
	return sb


func _spawn_breed_ambient_sparks(stage_root: Control, at_pos: Vector2, color: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.z_index = 8
	p.position = at_pos
	p.emitting = true
	p.amount = 56
	p.lifetime = 1.1
	p.preprocess = 0.45
	p.explosiveness = 0.0
	p.randomness = 0.42
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 26.0
	p.initial_velocity_max = 118.0
	p.angular_velocity_min = -1.4
	p.angular_velocity_max = 1.4
	p.scale_amount_min = 3.0
	p.scale_amount_max = 9.0
	p.color = color
	stage_root.add_child(p)
	return p


func _build_bred_egg_item(result: Dictionary, parent_a: Dictionary, parent_b: Dictionary) -> ConsumableData:
	var egg := ConsumableData.new()
	var quality: String = _infer_breed_quality(result)
	var generation: int = int(result.get("generation", 1))
	var baby: Dictionary = result.get("baby", {})
	var mutated_traits: Array = result.get("mutated_traits", [])
	var inherited_traits: Array = result.get("inherited_traits", [])

	var all_traits: Array = []
	for t in baby.get("traits", []):
		if not all_traits.has(t):
			all_traits.append(t)

	var trait_string: String = "None"
	if not all_traits.is_empty():
		trait_string = ", ".join(all_traits)

	var mutation_string: String = "None"
	if not mutated_traits.is_empty():
		mutation_string = ", ".join(mutated_traits)

	var inherited_string: String = "None"
	if not inherited_traits.is_empty():
		inherited_string = ", ".join(inherited_traits)

	egg.item_name = "%s Bred Egg (Gen %d)" % [quality, generation]
	egg.description = (
		"A carefully bred dragon egg.\n" +
		"Parents: %s & %s\n" % [str(parent_a.get("name", "Unknown")), str(parent_b.get("name", "Unknown"))] +
		"Element: %s\n" % str(result.get("element", "Unknown")) +
		"Generation: %d\n" % generation +
		"Traits: %s\n" % trait_string +
		"Mutations: %s\n" % mutation_string +
		"Inherited: %s" % inherited_string
	)
	egg.rarity = quality
	egg.gold_cost = 250
	egg.set_meta("baby_uid", str(baby.get("uid", "")))
	egg.set_meta("egg_uid", str(result.get("egg", {}).get("egg_uid", "")))

	if _resource_has_property(egg, "icon"):
		egg.set("icon", EGG_ICON)
	elif _resource_has_property(egg, "texture"):
		egg.set("texture", EGG_ICON)

	return egg


func _play_breeding_cinematic(result: Dictionary, parent_a: Dictionary, parent_b: Dictionary) -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var center: Vector2 = vp_size * 0.5

	var quality: String = _infer_breed_quality(result)
	var quality_color: Color = _get_breed_quality_color(quality)
	var mix_color: Color = _get_breed_element_mix_color(parent_a, parent_b)
	var accent_color: Color = mix_color.lerp(quality_color, 0.45)
	var stashed_dragons: Array = _breed_hide_enclosure_dragons()

	var layer := CanvasLayer.new()
	layer.layer = 160
	add_child(layer)

	var stage_root := Control.new()
	stage_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_root.size = vp_size
	layer.add_child(stage_root)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0.02, 0.01, 0.04, 0.0)
	dimmer.size = vp_size
	stage_root.add_child(dimmer)

	var ritual_ring := Panel.new()
	ritual_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ritual_ring.size = Vector2(300, 300)
	ritual_ring.pivot_offset = ritual_ring.size * 0.5
	ritual_ring.position = center - ritual_ring.size * 0.5
	ritual_ring.z_index = 4
	ritual_ring.modulate.a = 0.0
	ritual_ring.add_theme_stylebox_override("panel", _breed_make_ritual_ring_style(accent_color.lightened(0.12), 3, 150))
	stage_root.add_child(ritual_ring)

	var core_panel := Panel.new()
	core_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	core_panel.size = Vector2(248, 248)
	core_panel.pivot_offset = core_panel.size * 0.5
	core_panel.position = center - core_panel.size * 0.5
	core_panel.z_index = 5
	core_panel.scale = Vector2(0.5, 0.5)
	core_panel.modulate.a = 0.0
	core_panel.add_theme_stylebox_override(
		"panel",
		_breed_make_ritual_core_style(accent_color, quality_color.lerp(accent_color, 0.42), 0.15, 2, 124)
	)
	stage_root.add_child(core_panel)

	var beam_panel := Panel.new()
	beam_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beam_panel.size = Vector2(34, 272)
	beam_panel.pivot_offset = beam_panel.size * 0.5
	beam_panel.position = center - beam_panel.size * 0.5 + Vector2(0, -18)
	beam_panel.z_index = 6
	beam_panel.scale = Vector2(0.3, 0.2)
	beam_panel.modulate.a = 0.0
	beam_panel.add_theme_stylebox_override("panel", _breed_make_energy_beam_style(accent_color, 16))
	stage_root.add_child(beam_panel)

	var left_actor: DragonActor = _spawn_breeding_cinematic_actor(
		stage_root,
		parent_a.duplicate(true),
		Vector2(-260.0, center.y - 120.0),
		1.0,
		22
	)

	var right_actor: DragonActor = _spawn_breeding_cinematic_actor(
		stage_root,
		parent_b.duplicate(true),
		Vector2(vp_size.x + 60.0, center.y - 120.0),
		-1.0,
		22
	)

	left_actor.set_facing_immediate(1.0)
	right_actor.set_facing_immediate(-1.0)

	var left_target: Vector2 = Vector2(center.x - 285.0 - left_actor.size.x * 0.5, center.y - 120.0)
	var right_target: Vector2 = Vector2(center.x + 285.0 - right_actor.size.x * 0.5, center.y - 120.0)

	var intro_tw := create_tween().set_parallel(true)
	intro_tw.tween_property(dimmer, "color:a", 0.92, 0.55)
	intro_tw.tween_property(ritual_ring, "modulate:a", 0.95, 0.55)
	intro_tw.tween_property(core_panel, "modulate:a", 0.22, 0.55)
	intro_tw.tween_property(core_panel, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(beam_panel, "modulate:a", 0.12, 0.50)
	intro_tw.tween_property(beam_panel, "scale", Vector2(0.55, 0.35), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(left_actor, "position", left_target, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(right_actor, "position", right_target, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro_tw.tween_property(left_actor, "modulate:a", 1.0, 0.25)
	intro_tw.tween_property(right_actor, "modulate:a", 1.0, 0.25)
	await intro_tw.finished

	var ambient_sparks: CPUParticles2D = _spawn_breed_ambient_sparks(stage_root, center + Vector2(0, 8), accent_color)

	left_actor.play_cinematic_pulse(0.7)
	right_actor.play_cinematic_pulse(0.7)

	var stance_tw := create_tween().set_parallel(true)
	stance_tw.tween_property(left_actor, "scale", Vector2(1.03, 1.03), 0.14).set_trans(Tween.TRANS_SINE)
	stance_tw.tween_property(right_actor, "scale", Vector2(1.03, 1.03), 0.14).set_trans(Tween.TRANS_SINE)
	stance_tw.chain().tween_property(left_actor, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BOUNCE)
	stance_tw.parallel().tween_property(right_actor, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BOUNCE)
	await stance_tw.finished

	left_actor.play_cinematic_roar(0.92, 1.00, 1.0)
	await get_tree().create_timer(0.14).timeout
	right_actor.play_cinematic_roar(0.94, 1.02, 1.0)

	for i in range(3):
		left_actor.play_cinematic_pulse(0.85 + i * 0.15)
		right_actor.play_cinematic_pulse(0.85 + i * 0.15)

		var charge_tw := create_tween().set_parallel(true)
		charge_tw.tween_property(core_panel, "modulate:a", 0.30 + float(i) * 0.09, 0.16)
		charge_tw.tween_property(core_panel, "scale", Vector2(1.05 + float(i) * 0.08, 1.05 + float(i) * 0.08), 0.16)
		charge_tw.tween_property(beam_panel, "modulate:a", 0.24 + float(i) * 0.12, 0.16)
		charge_tw.tween_property(beam_panel, "scale", Vector2(0.62 + float(i) * 0.18, 0.55 + float(i) * 0.20), 0.16)
		charge_tw.tween_property(ritual_ring, "rotation", ritual_ring.rotation + 0.62, 0.16)
		await charge_tw.finished

		_spawn_magic_burst(
			stage_root,
			center + Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0)),
			accent_color.lightened(0.08),
			32,
			0.58,
			55.0,
			145.0,
			185.0,
			2.5,
			7.0
		)

		var release_tw := create_tween().set_parallel(true)
		release_tw.tween_property(core_panel, "modulate:a", 0.20, 0.12)
		release_tw.tween_property(beam_panel, "modulate:a", 0.12, 0.12)
		await release_tw.finished

	if ambient_sparks != null and is_instance_valid(ambient_sparks):
		ambient_sparks.emitting = false

	var egg_corona := Panel.new()
	egg_corona.mouse_filter = Control.MOUSE_FILTER_IGNORE
	egg_corona.size = Vector2(210, 210)
	egg_corona.pivot_offset = egg_corona.size * 0.5
	egg_corona.position = center - egg_corona.size * 0.5 + Vector2(0, 28)
	egg_corona.z_index = 28
	egg_corona.scale = Vector2(0.6, 0.6)
	egg_corona.modulate = Color(1, 1, 1, 0)
	var corona_sb := StyleBoxFlat.new()
	corona_sb.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.14)
	corona_sb.border_color = quality_color.lightened(0.15)
	corona_sb.set_border_width_all(2)
	corona_sb.set_corner_radius_all(105)
	corona_sb.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.55)
	corona_sb.shadow_size = 18
	corona_sb.shadow_offset = Vector2(0, 0)
	egg_corona.add_theme_stylebox_override("panel", corona_sb)
	stage_root.add_child(egg_corona)

	var egg := TextureRect.new()
	egg.texture = EGG_ICON
	egg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	egg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	egg.size = Vector2(112, 140)
	egg.pivot_offset = egg.size * 0.5
	egg.position = center - egg.size * 0.5 + Vector2(0, 30)
	egg.scale = Vector2(0.18, 0.18)
	egg.modulate = Color(1, 1, 1, 0.0)
	egg.z_index = 30
	stage_root.add_child(egg)

	var flash := ColorRect.new()
	flash.z_index = 90
	flash.color = Color(quality_color.r * 0.22 + 0.78, quality_color.g * 0.22 + 0.78, quality_color.b * 0.22 + 0.78, 0.0)
	flash.size = vp_size
	stage_root.add_child(flash)

	_spawn_magic_burst(stage_root, center, accent_color, 155, 1.05, 190.0, 540.0, 180.0, 5.0, 14.0)

	if quality == "Epic" or quality == "Legendary":
		_spawn_magic_burst(stage_root, center, quality_color, 105, 1.25, 340.0, 760.0, 180.0, 4.0, 16.0)

	var materialize_tw := create_tween().set_parallel(true)
	materialize_tw.tween_property(flash, "color:a", 0.72, 0.07)
	materialize_tw.tween_property(core_panel, "modulate:a", 0.68, 0.07)
	materialize_tw.tween_property(beam_panel, "modulate:a", 0.62, 0.07)
	await materialize_tw.finished

	var reveal_tw := create_tween().set_parallel(true)
	reveal_tw.tween_property(flash, "color:a", 0.0, 0.28)
	reveal_tw.tween_property(egg, "modulate:a", 1.0, 0.16)
	reveal_tw.tween_property(egg, "scale", Vector2(1.35, 1.35), 0.44).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	reveal_tw.tween_property(egg, "position:y", egg.position.y - 28.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal_tw.tween_property(egg_corona, "modulate:a", 0.92, 0.30)
	reveal_tw.tween_property(egg_corona, "scale", Vector2(1.12, 1.12), 0.40).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	reveal_tw.tween_property(core_panel, "modulate:a", 0.32, 0.36)
	reveal_tw.tween_property(beam_panel, "modulate:a", 0.0, 0.26)
	await reveal_tw.finished

	var egg_settle_tw := create_tween()
	egg_settle_tw.tween_property(egg, "position:y", egg.position.y + 18.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	egg_settle_tw.tween_property(egg, "position:y", egg.position.y, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	egg_settle_tw.parallel().tween_property(egg, "scale", Vector2(1.20, 1.20), 0.26).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	egg_settle_tw.parallel().tween_property(egg_corona, "scale", Vector2(1.0, 1.0), 0.26).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await egg_settle_tw.finished

	left_actor.play_cinematic_pulse(1.0)
	right_actor.play_cinematic_pulse(1.0)
	if quality == "Epic" or quality == "Legendary":
		left_actor.play_cinematic_roar(0.96, 1.06, 1.0)
		right_actor.play_cinematic_roar(0.96, 1.08, 1.0)

	var title := Label.new()
	title.z_index = 100
	title.text = "%s EGG CREATED!" % quality.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_color_override("font_color", quality_color)
	title.position = Vector2(0, center.y - 280.0)
	title.size.x = vp_size.x
	title.modulate.a = 0.0
	stage_root.add_child(title)

	var subtitle := Label.new()
	subtitle.z_index = 100
	subtitle.text = "Gen %d • %s Bloodline" % [
		int(result.get("generation", 1)),
		str(result.get("element", "Unknown"))
	]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_constant_override("outline_size", 8)
	subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	subtitle.add_theme_color_override("font_color", Color.WHITE)
	subtitle.position = Vector2(0, center.y + 145.0)
	subtitle.size.x = vp_size.x
	subtitle.modulate.a = 0.0
	stage_root.add_child(subtitle)

	var mutation_note := Label.new()
	mutation_note.z_index = 100
	var mutation_list: Array = result.get("mutated_traits", [])
	if mutation_list.is_empty():
		mutation_note.text = "Inherited traits are sleeping inside the egg."
	else:
		mutation_note.text = "Mutation Surge: " + ", ".join(mutation_list)
	mutation_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mutation_note.add_theme_font_size_override("font_size", 24)
	mutation_note.add_theme_constant_override("outline_size", 6)
	mutation_note.add_theme_color_override("font_outline_color", Color.BLACK)
	mutation_note.add_theme_color_override("font_color", accent_color)
	mutation_note.position = Vector2(0, center.y + 182.0)
	mutation_note.size.x = vp_size.x
	mutation_note.modulate.a = 0.0
	stage_root.add_child(mutation_note)

	var text_tw := create_tween().set_parallel(true)
	text_tw.tween_property(title, "modulate:a", 1.0, 0.28)
	text_tw.tween_property(subtitle, "modulate:a", 1.0, 0.34)
	text_tw.tween_property(mutation_note, "modulate:a", 1.0, 0.40)
	await text_tw.finished

	await get_tree().create_timer(2.7).timeout

	var outro_tw := create_tween().set_parallel(true)
	outro_tw.tween_property(dimmer, "color:a", 0.0, 0.50)
	outro_tw.tween_property(ritual_ring, "modulate:a", 0.0, 0.40)
	outro_tw.tween_property(core_panel, "modulate:a", 0.0, 0.40)
	outro_tw.tween_property(beam_panel, "modulate:a", 0.0, 0.40)
	outro_tw.tween_property(egg_corona, "modulate:a", 0.0, 0.40)
	outro_tw.tween_property(flash, "color:a", 0.0, 0.35)
	outro_tw.tween_property(left_actor, "modulate:a", 0.0, 0.40)
	outro_tw.tween_property(right_actor, "modulate:a", 0.0, 0.40)
	outro_tw.tween_property(egg, "modulate:a", 0.0, 0.40)
	outro_tw.tween_property(title, "modulate:a", 0.0, 0.40)
	outro_tw.tween_property(subtitle, "modulate:a", 0.0, 0.40)
	outro_tw.tween_property(mutation_note, "modulate:a", 0.0, 0.40)
	await outro_tw.finished

	_breed_restore_enclosure_dragons(stashed_dragons)
	if is_instance_valid(layer):
		layer.queue_free()
			
func _on_confirm_breed_pressed() -> void:
	if selected_parent_a_index == -1 or selected_parent_b_index == -1:
		return

	confirm_breed_btn.disabled = true

	var parent_a_snapshot: Dictionary = DragonManager.player_dragons[selected_parent_a_index].duplicate(true)
	var parent_b_snapshot: Dictionary = DragonManager.player_dragons[selected_parent_b_index].duplicate(true)

	var result: Dictionary = DragonManager.breed_dragons(selected_parent_a_index, selected_parent_b_index)

	if not bool(result.get("success", false)):
		prediction_label.text = "[center][color=red]ERROR: " + str(result.get("error", "Unknown error")) + "[/color][/center]"
		_refresh_breeding_ui()
		return
		
	_close_breeding_station()
	
	var bred_egg: ConsumableData = _build_bred_egg_item(result, parent_a_snapshot, parent_b_snapshot)
	CampaignManager.global_inventory.append(bred_egg)

	breed_panel.hide()

	await _play_breeding_cinematic(result, parent_a_snapshot, parent_b_snapshot)

	_spawn_dragons()
	_refresh_actor_selection()

	if selected_dragon_uid != "":
		_update_info_card()

	_refresh_breeding_ui()
	_trigger_morgra("breed")
	
func _kill_breed_ui_tween(tw: Tween) -> void:
	if tw != null and is_instance_valid(tw):
		tw.kill()


func _close_breeding_station() -> void:
	_stop_breeding_preview_fx()
	if breed_dimmer != null:
		breed_dimmer.visible = false
	if breed_panel != null:
		breed_panel.hide()
	_set_herder_chrome_visible(true)
	if visible and info_card != null and is_instance_valid(info_card) and _info_card_was_visible_before_breed:
		info_card.show()
	_info_card_was_visible_before_breed = false


func _set_herder_chrome_visible(on: bool) -> void:
	if herder_portrait_rect != null and is_instance_valid(herder_portrait_rect):
		herder_portrait_rect.visible = on
	if herder_dialogue_label != null and is_instance_valid(herder_dialogue_label):
		herder_dialogue_label.visible = on
	if favorite_label != null and is_instance_valid(favorite_label):
		favorite_label.visible = on
	if herder_dialogue_plate != null and is_instance_valid(herder_dialogue_plate):
		herder_dialogue_plate.visible = on


func _ranch_raise_breeding_station_input_stack() -> void:
	# Full-screen dimmer must stay under the station UI in both draw and input order.
	# Large z_index gap avoids tie-breaking glitches with other ranch controls; move_to_front
	# ensures the modal is the last child of this panel so it wins over leftover siblings.
	if breed_panel != null and is_instance_valid(breed_panel):
		breed_panel.move_to_front()
	if breed_selection_popup != null and is_instance_valid(breed_selection_popup):
		breed_selection_popup.move_to_front()


func _get_quality_color(quality: String) -> Color:
	match quality:
		"Legendary":
			return Color(1.0, 0.86, 0.24, 1.0)
		"Epic":
			return Color(0.82, 0.58, 1.0, 1.0)
		"Rare":
			return Color(0.40, 0.82, 1.0, 1.0)
		_:
			return Color(0.92, 0.92, 0.92, 1.0)


func _get_element_mix_color(element_a: String, element_b: String) -> Color:
	var c1: Color = _get_element_reveal_color(element_a)
	var c2: Color = _get_element_reveal_color(element_b)
	return c1.lerp(c2, 0.5)


func _ensure_breeding_station_fx_ui() -> void:
	if breed_panel == null:
		return

	if breed_preview_fx_root != null and is_instance_valid(breed_preview_fx_root):
		return

	breed_preview_fx_root = Control.new()
	breed_preview_fx_root.name = "BreedPreviewFXRoot"
	breed_preview_fx_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breed_preview_fx_root.size = breed_panel.size
	breed_panel.add_child(breed_preview_fx_root)
	_ranch_reorder_breed_fx_before_prediction()

	breed_prediction_backplate = ColorRect.new()
	breed_prediction_backplate.color = Color(0.07, 0.055, 0.04, 0.94)
	breed_prediction_backplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breed_prediction_backplate.z_index = -1
	breed_preview_fx_root.add_child(breed_prediction_backplate)

	breed_compat_bar_bg = ColorRect.new()
	breed_compat_bar_bg.color = Color(0.09, 0.07, 0.05, 0.94)
	breed_compat_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breed_preview_fx_root.add_child(breed_compat_bar_bg)

	breed_compat_bar_fill = ColorRect.new()
	breed_compat_bar_fill.color = Color(0.7, 0.7, 0.7, 1.0)
	breed_compat_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breed_preview_fx_root.add_child(breed_compat_bar_fill)

	breed_compat_value_label = Label.new()
	breed_compat_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breed_compat_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_CampUiSkin.style_label(breed_compat_value_label, _CampUiSkin.CAMP_TEXT, 16)
	breed_preview_fx_root.add_child(breed_compat_value_label)

	breed_mutation_label = RichTextLabel.new()
	breed_mutation_label.bbcode_enabled = true
	breed_mutation_label.fit_content = true
	breed_mutation_label.scroll_active = false
	breed_mutation_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breed_preview_fx_root.add_child(breed_mutation_label)

	breed_resonance_glow = ColorRect.new()
	breed_resonance_glow.color = Color(1, 1, 1, 0.18)
	breed_resonance_glow.size = Vector2(90, 90)
	breed_resonance_glow.pivot_offset = breed_resonance_glow.size * 0.5
	breed_resonance_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breed_preview_fx_root.add_child(breed_resonance_glow)

	breed_resonance_ring = ColorRect.new()
	breed_resonance_ring.color = Color(1, 1, 1, 0.08)
	breed_resonance_ring.size = Vector2(124, 124)
	breed_resonance_ring.pivot_offset = breed_resonance_ring.size * 0.5
	breed_resonance_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	breed_preview_fx_root.add_child(breed_resonance_ring)

	_layout_breeding_station_fx_ui()


func _ranch_reorder_breed_fx_before_prediction() -> void:
	if breed_panel == null or breed_preview_fx_root == null or prediction_label == null:
		return
	if not is_instance_valid(breed_panel) or not is_instance_valid(breed_preview_fx_root):
		return
	var tidx: int = prediction_label.get_index()
	if breed_preview_fx_root.get_index() != tidx:
		breed_panel.move_child(breed_preview_fx_root, tidx)


func _layout_breeding_station_fx_ui() -> void:
	if breed_preview_fx_root == null or prediction_label == null:
		return

	_ranch_reorder_breed_fx_before_prediction()
	breed_preview_fx_root.size = breed_panel.size

	var card_pos: Vector2 = prediction_label.position - Vector2(14, 14)
	var card_size: Vector2 = Vector2(max(prediction_label.size.x + 28.0, 380.0), 210.0)

	breed_prediction_backplate.position = card_pos
	breed_prediction_backplate.size = card_size

	breed_compat_bar_bg.position = card_pos + Vector2(18.0, 132.0)
	breed_compat_bar_bg.size = Vector2(card_size.x - 36.0, 16.0)

	breed_compat_bar_fill.position = breed_compat_bar_bg.position
	breed_compat_bar_fill.size = Vector2(0.0, breed_compat_bar_bg.size.y)

	breed_compat_value_label.position = breed_compat_bar_bg.position + Vector2(0.0, -28.0)
	breed_compat_value_label.size = Vector2(breed_compat_bar_bg.size.x, 24.0)

	breed_mutation_label.position = card_pos + Vector2(18.0, 154.0)
	breed_mutation_label.size = Vector2(card_size.x - 36.0, 52.0)

	if parent_a_btn != null and parent_b_btn != null:
		var left_center: Vector2 = parent_a_btn.position + parent_a_btn.size * 0.5
		var right_center: Vector2 = parent_b_btn.position + parent_b_btn.size * 0.5
		var mid: Vector2 = (left_center + right_center) * 0.5 + Vector2(0.0, 8.0)

		breed_resonance_glow.position = mid - breed_resonance_glow.size * 0.5
		breed_resonance_ring.position = mid - breed_resonance_ring.size * 0.5

	if confirm_breed_btn != null and is_instance_valid(confirm_breed_btn):
		confirm_breed_btn.move_to_front()
	if close_breed_btn != null and is_instance_valid(close_breed_btn):
		close_breed_btn.move_to_front()


## Slot buttons only covered the label strip; dragon art sits in a child rect above. Merge rects so the whole card is clickable / shows hand cursor.
func _ranch_expand_breed_parent_slot_hit_areas() -> void:
	if breed_panel == null or not is_instance_valid(breed_panel):
		return
	if parent_a_btn != null and parent_a_sprite != null:
		_ranch_expand_button_to_cover_sprite(parent_a_btn, parent_a_sprite)
	if parent_b_btn != null and parent_b_sprite != null:
		_ranch_expand_button_to_cover_sprite(parent_b_btn, parent_b_sprite)


func _ranch_expand_button_to_cover_sprite(btn: Button, sprite_node: TextureRect) -> void:
	var btn_rect := Rect2(btn.position, btn.size)
	var sprite_top_left: Vector2 = btn.position + sprite_node.position
	var sprite_rect_panel := Rect2(sprite_top_left, sprite_node.size)
	var u: Rect2 = btn_rect.merge(sprite_rect_panel)
	btn.position = u.position
	btn.size = u.size
	sprite_node.position = sprite_top_left - u.position


func _ranch_ensure_breed_slot_chrome(btn: Button) -> Dictionary:
	var strip: Panel = btn.get_node_or_null("BreedSlotCaptionStrip") as Panel
	if strip == null:
		strip = Panel.new()
		strip.name = "BreedSlotCaptionStrip"
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(strip)
	var cap: Label = btn.get_node_or_null("BreedSlotCaption") as Label
	if cap == null:
		cap = Label.new()
		cap.name = "BreedSlotCaption"
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cap.clip_text = false
		btn.add_child(cap)
	return {"strip": strip, "caption": cap}


func _ranch_style_breed_slot_caption(lbl: Label) -> void:
	if lbl == null:
		return
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", _CampUiSkin.CAMP_TEXT)
	lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.019, 0.014, 0.94))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.62))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 2)


func _ranch_style_breed_slot_strip(panel: Panel, accent: Color, active: bool) -> void:
	if panel == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.042, 0.028, 0.88)
	if active:
		sb.border_color = accent.darkened(0.35)
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
	else:
		sb.border_color = Color(0.35, 0.29, 0.18, 0.45)
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	panel.add_theme_stylebox_override("panel", sb)


func _ranch_layout_breed_slot(btn: Button, sprite: TextureRect, strip: Panel, caption: Label, filled: bool) -> void:
	if btn == null or sprite == null or strip == null or caption == null:
		return
	var a0 := BREED_SLOT_SPRITE_BOTTOM_ANCHOR
	strip.layout_mode = 1
	caption.layout_mode = 1
	sprite.layout_mode = 1

	if filled and sprite.visible:
		sprite.anchor_left = 0.0
		sprite.anchor_top = 0.0
		sprite.anchor_right = 1.0
		sprite.anchor_bottom = a0
		sprite.offset_left = 14.0
		sprite.offset_top = 12.0
		sprite.offset_right = -14.0
		sprite.offset_bottom = -4.0

		strip.visible = true
		strip.anchor_left = 0.0
		strip.anchor_top = a0
		strip.anchor_right = 1.0
		strip.anchor_bottom = 1.0
		strip.offset_left = 10.0
		strip.offset_top = 0.0
		strip.offset_right = -10.0
		strip.offset_bottom = -10.0

		caption.anchor_left = 0.0
		caption.anchor_top = a0
		caption.anchor_right = 1.0
		caption.anchor_bottom = 1.0
		caption.offset_left = 12.0
		caption.offset_top = 4.0
		caption.offset_right = -12.0
		caption.offset_bottom = -12.0
	else:
		sprite.anchor_left = 0.0
		sprite.anchor_top = 0.0
		sprite.anchor_right = 1.0
		sprite.anchor_bottom = a0
		sprite.offset_left = 14.0
		sprite.offset_top = 12.0
		sprite.offset_right = -14.0
		sprite.offset_bottom = -4.0

		strip.visible = true
		strip.anchor_left = 0.0
		strip.anchor_top = 0.38
		strip.anchor_right = 1.0
		strip.anchor_bottom = 1.0
		strip.offset_left = 14.0
		strip.offset_top = 0.0
		strip.offset_right = -14.0
		strip.offset_bottom = -14.0

		caption.anchor_left = 0.0
		caption.anchor_top = 0.38
		caption.anchor_right = 1.0
		caption.anchor_bottom = 1.0
		caption.offset_left = 16.0
		caption.offset_top = 6.0
		caption.offset_right = -16.0
		caption.offset_bottom = -16.0

	var zi: int = 0
	btn.move_child(sprite, zi)
	zi += 1
	btn.move_child(strip, zi)
	zi += 1
	btn.move_child(caption, zi)


func _set_parent_button_style(btn: Button, color: Color, active: bool) -> void:
	if btn == null:
		return

	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.focus_mode = Control.FOCUS_ALL
	btn.clip_contents = true
	if btn == parent_a_btn:
		btn.tooltip_text = "Choose the first parent (must be an adult with a clear breeding cooldown)."
	elif btn == parent_b_btn:
		btn.tooltip_text = "Choose the second parent (must be an adult with a clear breeding cooldown)."

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2

	style.shadow_color = Color(0, 0, 0, 0.30)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 5)

	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", _CampUiSkin.CAMP_TEXT)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.94, 1.0))
	btn.add_theme_color_override("font_pressed_color", _CampUiSkin.CAMP_TEXT)
	btn.add_theme_color_override("font_focus_color", _CampUiSkin.CAMP_TEXT)

	if active:
		style.bg_color = color.darkened(0.72)
		style.border_color = color
		btn.modulate = Color(1.05, 1.05, 1.05, 1.0)
	else:
		style.bg_color = _CampUiSkin.CAMP_ACTION_SECONDARY.darkened(0.06)
		style.border_color = _CampUiSkin.CAMP_BORDER_SOFT
		btn.modulate = Color.WHITE

	btn.add_theme_stylebox_override("normal", style)

	var style_hover: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	style_hover.bg_color = style.bg_color.lightened(0.14)
	style_hover.border_color = style.border_color.lightened(0.12)
	style_hover.shadow_size = 8
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	style_pressed.bg_color = style.bg_color.darkened(0.10)
	style_pressed.border_color = style.border_color.darkened(0.06)
	style_pressed.shadow_size = 3
	style_pressed.shadow_offset = Vector2(0, 2)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	var style_focus: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	style_focus.border_color = style.border_color.lerp(_CampUiSkin.CAMP_ACCENT_CYAN, 0.45)
	style_focus.border_width_left = 3
	style_focus.border_width_top = 3
	style_focus.border_width_right = 3
	style_focus.border_width_bottom = 3
	btn.add_theme_stylebox_override("focus", style_focus)

	var style_disabled: StyleBoxFlat = style.duplicate() as StyleBoxFlat
	style_disabled.bg_color = style.bg_color.darkened(0.18)
	style_disabled.border_color = style.border_color.darkened(0.22)
	style_disabled.shadow_size = 0
	btn.add_theme_stylebox_override("disabled", style_disabled)


func _start_parent_slot_pulse(slot_name: String, sprite_node: TextureRect, btn: Button, color: Color) -> void:
	if sprite_node == null or btn == null:
		return

	sprite_node.pivot_offset = sprite_node.size * 0.5
	sprite_node.modulate = color.lerp(Color.WHITE, 0.35)
	sprite_node.scale = Vector2.ONE

	var tw: Tween = create_tween().set_loops()
	tw.tween_property(sprite_node, "scale", Vector2(1.08, 1.08), 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(sprite_node, "modulate", color.lerp(Color.WHITE, 0.55), 0.42)
	tw.tween_property(sprite_node, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(sprite_node, "modulate", color.lerp(Color.WHITE, 0.30), 0.42)

	if slot_name == "A":
		_kill_breed_ui_tween(breed_parent_a_tween)
		breed_parent_a_tween = tw
	else:
		_kill_breed_ui_tween(breed_parent_b_tween)
		breed_parent_b_tween = tw


func _stop_breeding_preview_fx() -> void:
	_kill_breed_ui_tween(breed_parent_a_tween)
	_kill_breed_ui_tween(breed_parent_b_tween)
	_kill_breed_ui_tween(breed_resonance_tween)
	_kill_breed_ui_tween(breed_confirm_tween)

	if parent_a_sprite != null:
		parent_a_sprite.scale = Vector2.ONE
		parent_a_sprite.modulate = Color.WHITE
	if parent_b_sprite != null:
		parent_b_sprite.scale = Vector2.ONE
		parent_b_sprite.modulate = Color.WHITE
	if confirm_breed_btn != null:
		confirm_breed_btn.modulate = Color.WHITE

	if breed_resonance_glow != null:
		breed_resonance_glow.scale = Vector2.ONE
		breed_resonance_glow.modulate.a = 0.0
	if breed_resonance_ring != null:
		breed_resonance_ring.scale = Vector2.ONE
		breed_resonance_ring.modulate.a = 0.0


func _start_breeding_preview_fx(preview: Dictionary) -> void:
	_layout_breeding_station_fx_ui()

	var score: float = float(int(preview.get("compatibility_score", 0))) / 100.0
	var quality: String = str(preview.get("quality", "Common"))
	var quality_color: Color = _get_quality_color(quality)
	var mix_color: Color = _get_element_mix_color(
		str(preview.get("element_a", "")),
		str(preview.get("element_b", ""))
	)
	var final_color: Color = mix_color.lerp(quality_color, 0.40)

	if breed_resonance_glow != null:
		breed_resonance_glow.color = final_color
		breed_resonance_glow.scale = Vector2(0.75, 0.75)
		breed_resonance_glow.modulate.a = 0.12

	if breed_resonance_ring != null:
		breed_resonance_ring.color = quality_color
		breed_resonance_ring.scale = Vector2(0.85, 0.85)
		breed_resonance_ring.modulate.a = 0.08

	_kill_breed_ui_tween(breed_resonance_tween)
	breed_resonance_tween = create_tween().set_loops()

	var pulse_scale: float = 1.05 + (score * 0.35)
	var pulse_alpha: float = 0.18 + (score * 0.22)
	var ring_scale: float = 1.18 + (score * 0.28)

	breed_resonance_tween.tween_property(breed_resonance_glow, "scale", Vector2(pulse_scale, pulse_scale), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breed_resonance_tween.parallel().tween_property(breed_resonance_glow, "modulate:a", pulse_alpha, 0.45)
	breed_resonance_tween.parallel().tween_property(breed_resonance_ring, "scale", Vector2(ring_scale, ring_scale), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	breed_resonance_tween.parallel().tween_property(breed_resonance_ring, "modulate:a", 0.16 + (score * 0.12), 0.45)

	breed_resonance_tween.tween_property(breed_resonance_glow, "scale", Vector2(0.85, 0.85), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breed_resonance_tween.parallel().tween_property(breed_resonance_glow, "modulate:a", 0.12, 0.45)
	breed_resonance_tween.parallel().tween_property(breed_resonance_ring, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breed_resonance_tween.parallel().tween_property(breed_resonance_ring, "modulate:a", 0.06, 0.45)

	if confirm_breed_btn != null and not confirm_breed_btn.disabled:
		_kill_breed_ui_tween(breed_confirm_tween)
		breed_confirm_tween = create_tween().set_loops()
		breed_confirm_tween.tween_property(confirm_breed_btn, "modulate", Color(1.08, 1.08, 1.08, 1.0), 0.42)
		breed_confirm_tween.tween_property(confirm_breed_btn, "modulate", Color.WHITE, 0.42)

func _process(delta: float) -> void:
	_ranch_process_dragon_stats_popup_interaction()
	_tick_social_pair_cooldowns(delta)

	if not visible:
		return

	if _is_ranch_busy_for_social():
		return

	if actor_by_uid.size() < 2:
		return

	social_interaction_timer -= delta
	if social_interaction_timer > 0.0:
		return

	social_interaction_timer = _roll_next_social_time()
	call_deferred("_try_start_social_interaction")


func _tick_social_pair_cooldowns(delta: float) -> void:
	if social_pair_cooldowns.is_empty():
		return

	var to_erase: Array = []
	for pair_key in social_pair_cooldowns.keys():
		var new_value: float = float(social_pair_cooldowns[pair_key]) - delta
		if new_value <= 0.0:
			to_erase.append(pair_key)
		else:
			social_pair_cooldowns[pair_key] = new_value

	for pair_key in to_erase:
		social_pair_cooldowns.erase(pair_key)


func _roll_next_social_time() -> float:
	return randf_range(SOCIAL_INTERACTION_MIN_DELAY, SOCIAL_INTERACTION_MAX_DELAY)


func _is_ranch_busy_for_social() -> bool:
	return is_feed_animating or is_pet_animating or is_hunt_animating or is_hatch_animating or is_social_animating or is_training_animating

func _make_social_pair_key(uid_a: String, uid_b: String) -> String:
	if uid_a < uid_b:
		return uid_a + "|" + uid_b
	return uid_b + "|" + uid_a


func _try_start_social_interaction() -> void:
	if not visible:
		return
	if _is_ranch_busy_for_social():
		return
	if actor_by_uid.size() < 2:
		return

	var picked: Dictionary = _pick_social_pair()
	if picked.is_empty():
		return

	await _run_social_interaction(
		str(picked.get("uid_a", "")),
		str(picked.get("uid_b", "")),
		str(picked.get("type", "greet"))
	)

func _pick_social_pair() -> Dictionary:
	var valid_uids: Array = []

	for uid in actor_by_uid.keys():
		var actor: DragonActor = _get_actor_by_uid(str(uid))
		if actor != null:
			valid_uids.append(str(uid))

	if valid_uids.size() < 2:
		return {}

	var entries: Array = []
	var total_weight: float = 0.0

	for i in range(valid_uids.size()):
		for j in range(i + 1, valid_uids.size()):
			var uid_a: String = str(valid_uids[i])
			var uid_b: String = str(valid_uids[j])

			var pair_key: String = _make_social_pair_key(uid_a, uid_b)
			if social_pair_cooldowns.has(pair_key):
				continue

			var actor_a: DragonActor = _get_actor_by_uid(uid_a)
			var actor_b: DragonActor = _get_actor_by_uid(uid_b)
			if actor_a == null or actor_b == null:
				continue

			var dragon_a: Dictionary = DragonManager.get_dragon_by_uid(uid_a)
			var dragon_b: Dictionary = DragonManager.get_dragon_by_uid(uid_b)
			if dragon_a.is_empty() or dragon_b.is_empty():
				continue

			var weight: float = _get_social_pair_weight(actor_a, actor_b, dragon_a, dragon_b)
			if weight <= 0.0:
				continue

			var social_score: int = DragonManager.get_social_score(uid_a, uid_b)
			var interaction_type: String = _determine_social_interaction_type(dragon_a, dragon_b, social_score)

			entries.append({
				"uid_a": uid_a,
				"uid_b": uid_b,
				"type": interaction_type,
				"weight": weight
			})
			total_weight += weight

	if entries.is_empty() or total_weight <= 0.0:
		return {}

	var roll: float = randf() * total_weight
	var running: float = 0.0

	for entry in entries:
		running += float(entry["weight"])
		if roll <= running:
			return entry

	return entries[entries.size() - 1]


func _get_social_pair_weight(actor_a: DragonActor, actor_b: DragonActor, dragon_a: Dictionary, dragon_b: Dictionary) -> float:
	var center_a: Vector2 = actor_a.position + actor_a.size * 0.5
	var center_b: Vector2 = actor_b.position + actor_b.size * 0.5
	var distance: float = center_a.distance_to(center_b)

	var distance_bias: float = clampf(1.0 - (distance / SOCIAL_MIN_DISTANCE_BIAS), 0.15, 1.0)
	var stage_a: int = int(dragon_a.get("stage", 2))
	var stage_b: int = int(dragon_b.get("stage", 2))
	# Babies seek interaction more; adults slightly less often.
	if stage_a == 1 or stage_b == 1:
		distance_bias *= 1.20
	elif stage_a == 3 and stage_b == 3:
		distance_bias *= 0.85
	distance_bias = clampf(distance_bias, 0.10, 1.25)
	var avg_happiness: float = (
		float(int(dragon_a.get("happiness", 50))) +
		float(int(dragon_b.get("happiness", 50)))
	) / 2.0

	var social_score: int = DragonManager.get_social_score(
		str(dragon_a.get("uid", "")),
		str(dragon_b.get("uid", ""))
	)

	var weight: float = 0.35
	weight += distance_bias * 0.90
	weight += (avg_happiness / 100.0) * 0.65
	weight += (abs(float(social_score)) / 100.0) * 0.55

	if str(dragon_a.get("element", "")) == str(dragon_b.get("element", "")):
		weight += 0.25

	var mood_a: String = str(dragon_a.get("mood", ""))
	var mood_b: String = str(dragon_b.get("mood", ""))

	if mood_a == "Affectionate" or mood_b == "Affectionate":
		weight += 0.25
	if mood_a == "Irritated" or mood_b == "Irritated":
		weight += 0.20

	return max(weight, 0.0)


func _traits_have_any(traits: Array, wanted: Array) -> bool:
	if traits == null or wanted == null:
		return false
	for t in traits:
		if wanted.has(t):
			return true
	return false


func _stage_social_bias(stage: int) -> Dictionary:
	# Weight nudges based on life stage.
	# 1 = Baby (more playful), 2 = Juvenile (balanced), 3 = Adult (calmer).
	match stage:
		1:
			return {"play": 1.6, "greet": 1.2, "mock_chase": 1.3, "rival_stare": 0.7}
		2:
			return {"play": 1.0, "greet": 1.0, "mock_chase": 1.0, "rival_stare": 1.0}
		3:
			return {"play": 0.55, "greet": 1.15, "mock_chase": 0.65, "rival_stare": 0.9, "nuzzle": 1.2}
		_:
			return {"play": 0.8, "greet": 1.0, "mock_chase": 0.85, "rival_stare": 1.0}


func _determine_social_interaction_type(dragon_a: Dictionary, dragon_b: Dictionary, social_score: int) -> String:
	var avg_happiness: float = (
		float(int(dragon_a.get("happiness", 50))) +
		float(int(dragon_b.get("happiness", 50)))
	) / 2.0

	var traits_a: Array = dragon_a.get("traits", [])
	var traits_b: Array = dragon_b.get("traits", [])
	var stage_a: int = int(dragon_a.get("stage", 2))
	var stage_b: int = int(dragon_b.get("stage", 2))
	var bias_a: Dictionary = _stage_social_bias(stage_a)
	var bias_b: Dictionary = _stage_social_bias(stage_b)
	var bias_play: float = (float(bias_a.get("play", 1.0)) + float(bias_b.get("play", 1.0))) * 0.5
	var bias_greet: float = (float(bias_a.get("greet", 1.0)) + float(bias_b.get("greet", 1.0))) * 0.5
	var bias_mock: float = (float(bias_a.get("mock_chase", 1.0)) + float(bias_b.get("mock_chase", 1.0))) * 0.5
	var bias_rival: float = (float(bias_a.get("rival_stare", 1.0)) + float(bias_b.get("rival_stare", 1.0))) * 0.5
	var bias_nuzzle: float = (float(bias_a.get("nuzzle", 1.0)) + float(bias_b.get("nuzzle", 1.0))) * 0.5

	var gentle: bool = (
		_traits_have_any(traits_a, ["Loyal", "Gentle Soul", "Guardian", "Heartbound", "Soulkeeper", "Warden"]) or
		_traits_have_any(traits_b, ["Loyal", "Gentle Soul", "Guardian", "Heartbound", "Soulkeeper", "Warden"])
	)

	var aggressive: bool = (
		_traits_have_any(traits_a, ["Fierce", "Vicious", "Dominant", "Savage", "Blood Frenzy", "Tyrant"]) or
		_traits_have_any(traits_b, ["Fierce", "Vicious", "Dominant", "Savage", "Blood Frenzy", "Tyrant"])
	)

	var playful: bool = (
		_traits_have_any(traits_a, ["Swift", "Keen Hunter", "Sky Dancer", "Lightning Reflexes", "Apex Hunter", "Zephyr Lord"]) or
		_traits_have_any(traits_b, ["Swift", "Keen Hunter", "Sky Dancer", "Lightning Reflexes", "Apex Hunter", "Zephyr Lord"])
	)

	var mood_a: String = str(dragon_a.get("mood", ""))
	var mood_b: String = str(dragon_b.get("mood", ""))

	# Age-stage integration:
	# - Babies skew playful and less confrontational.
	# - Adults skew calmer (more greet/nuzzle, less chase/zoom-style play).
	var rival_trigger_chance: float = clampf(0.65 * bias_rival, 0.15, 0.85)
	if social_score <= -25 or ((mood_a == "Irritated" or mood_b == "Irritated") and aggressive and randf() < rival_trigger_chance):
		return "rival_stare"

	var nuzzle_bonus_chance: float = clampf(0.65 * bias_nuzzle, 0.20, 0.90)
	if social_score >= 30 and gentle and randf() < nuzzle_bonus_chance:
		return "nuzzle"

	var play_chance: float = clampf(0.55 * bias_play, 0.15, 0.85)
	if playful and avg_happiness >= 50.0 and randf() < play_chance:
		return "play"

	var mock_chance: float = clampf(0.35 * bias_mock, 0.10, 0.70)
	if aggressive and avg_happiness >= 45.0 and randf() < mock_chance:
		return "mock_chase"

	var affectionate_nuzzle_chance: float = clampf(0.55 * bias_nuzzle, 0.15, 0.90)
	if (mood_a == "Affectionate" or mood_b == "Affectionate") and randf() < affectionate_nuzzle_chance:
		return "nuzzle"

	# Default: greeting, slightly boosted for older stages.
	if randf() < clampf(0.10 * bias_greet, 0.0, 0.25):
		return "nuzzle"
	return "greet"
	
func _run_social_interaction(uid_a: String, uid_b: String, interaction_type: String) -> void:
	if uid_a == "" or uid_b == "" or uid_a == uid_b:
		return
	if _is_ranch_busy_for_social():
		return

	var actor_a: DragonActor = _get_actor_by_uid(uid_a)
	var actor_b: DragonActor = _get_actor_by_uid(uid_b)
	if actor_a == null or actor_b == null:
		return

	var dragon_a: Dictionary = DragonManager.get_dragon_by_uid(uid_a)
	var dragon_b: Dictionary = DragonManager.get_dragon_by_uid(uid_b)
	if dragon_a.is_empty() or dragon_b.is_empty():
		return

	is_social_animating = true
	social_pair_cooldowns[_make_social_pair_key(uid_a, uid_b)] = SOCIAL_PAIR_COOLDOWN

	var start_a: Vector2 = actor_a.position
	var start_b: Vector2 = actor_b.position

	actor_a.set_cinematic_mode(true)
	actor_b.set_cinematic_mode(true)

	var center_a: Vector2 = actor_a.position + actor_a.size * 0.5
	var center_b: Vector2 = actor_b.position + actor_b.size * 0.5
	var meet_center: Vector2 = (center_a + center_b) * 0.5 + Vector2(randf_range(-20.0, 20.0), randf_range(-12.0, 12.0))

	var spacing: float = max(actor_a.size.x, actor_b.size.x) * 0.55

	var target_a: Vector2 = meet_center - actor_a.size * 0.5 + Vector2(-spacing, 0.0)
	var target_b: Vector2 = meet_center - actor_b.size * 0.5 + Vector2(spacing, 0.0)

	target_a = _clamp_actor_target_to_enclosure(target_a, actor_a)
	target_b = _clamp_actor_target_to_enclosure(target_b, actor_b)

	if target_a.x < target_b.x:
		actor_a.set_facing_immediate(1.0)
		actor_b.set_facing_immediate(-1.0)
	else:
		actor_a.set_facing_immediate(-1.0)
		actor_b.set_facing_immediate(1.0)

	var meet_tw := create_tween().set_parallel(true)
	meet_tw.tween_property(actor_a, "position", target_a, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	meet_tw.tween_property(actor_b, "position", target_b, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await meet_tw.finished

	match interaction_type:
		"greet":
			await _play_social_greet(actor_a, actor_b)
			_apply_social_interaction_effects(uid_a, uid_b, "greet")

		"nuzzle":
			await _play_social_nuzzle(actor_a, actor_b)
			_apply_social_interaction_effects(uid_a, uid_b, "nuzzle")

		"play":
			await _play_social_play(actor_a, actor_b)
			_apply_social_interaction_effects(uid_a, uid_b, "play")

		"mock_chase":
			await _play_social_mock_chase(actor_a, actor_b)
			_apply_social_interaction_effects(uid_a, uid_b, "mock_chase")

		"rival_stare":
			await _play_social_rival_stare(actor_a, actor_b)
			_apply_social_interaction_effects(uid_a, uid_b, "rival_stare")

		_:
			await _play_social_greet(actor_a, actor_b)
			_apply_social_interaction_effects(uid_a, uid_b, "greet")

	actor_a = _get_actor_by_uid(uid_a)
	actor_b = _get_actor_by_uid(uid_b)

	if is_instance_valid(actor_a):
		actor_a.refresh_from_data(DragonManager.get_dragon_by_uid(uid_a))
	if is_instance_valid(actor_b):
		actor_b.refresh_from_data(DragonManager.get_dragon_by_uid(uid_b))

	if selected_dragon_uid == uid_a or selected_dragon_uid == uid_b:
		_update_info_card()

	await get_tree().create_timer(0.20).timeout

	actor_a = _get_actor_by_uid(uid_a)
	actor_b = _get_actor_by_uid(uid_b)

	if is_instance_valid(actor_a) and is_instance_valid(actor_b):
		var return_tw := create_tween().set_parallel(true)
		return_tw.tween_property(actor_a, "position", _clamp_actor_target_to_enclosure(start_a, actor_a), 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return_tw.tween_property(actor_b, "position", _clamp_actor_target_to_enclosure(start_b, actor_b), 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await return_tw.finished
	else:
		if is_instance_valid(actor_a):
			var tw_a := create_tween()
			tw_a.tween_property(actor_a, "position", _clamp_actor_target_to_enclosure(start_a, actor_a), 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await tw_a.finished
		if is_instance_valid(actor_b):
			var tw_b := create_tween()
			tw_b.tween_property(actor_b, "position", _clamp_actor_target_to_enclosure(start_b, actor_b), 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await tw_b.finished

	if is_instance_valid(actor_a):
		actor_a.set_cinematic_mode(false)
	if is_instance_valid(actor_b):
		actor_b.set_cinematic_mode(false)

	is_social_animating = false
	
func _clamp_actor_target_to_enclosure(target: Vector2, actor: DragonActor) -> Vector2:
	var out: Vector2 = target
	out.x = clampf(out.x, 0.0, max(0.0, enclosure.size.x - actor.size.x))
	out.y = clampf(out.y, 0.0, max(0.0, enclosure.size.y - actor.size.y))
	return out


func _play_social_greet(actor_a: DragonActor, actor_b: DragonActor) -> void:
	actor_a.play_cinematic_pulse(0.65)
	actor_b.play_cinematic_pulse(0.65)

	if actor_a.has_method("show_float_text"):
		actor_a.show_float_text("Chirp!", Color(0.85, 1.0, 0.90))
	if actor_b.has_method("show_float_text"):
		actor_b.show_float_text("Chirp!", Color(0.85, 1.0, 0.90))

	await get_tree().create_timer(0.55).timeout


func _play_social_nuzzle(actor_a: DragonActor, actor_b: DragonActor) -> void:
	var orig_a: Vector2 = actor_a.position
	var orig_b: Vector2 = actor_b.position

	var dir: Vector2 = (actor_b.position - actor_a.position).normalized()
	if dir.length() <= 0.001:
		dir = Vector2.RIGHT

	var tw := create_tween().set_parallel(true)
	tw.tween_property(actor_a, "position", orig_a + dir * 10.0, 0.12)
	tw.tween_property(actor_b, "position", orig_b - dir * 10.0, 0.12)
	tw.tween_property(actor_a, "scale", Vector2(1.04, 1.04), 0.12)
	tw.tween_property(actor_b, "scale", Vector2(1.04, 1.04), 0.12)
	await tw.finished

	if actor_a.has_method("show_float_text"):
		actor_a.show_float_text("♥", Color(1.0, 0.70, 0.88))
	if actor_b.has_method("show_float_text"):
		actor_b.show_float_text("♥", Color(1.0, 0.70, 0.88))

	var back_tw := create_tween().set_parallel(true)
	back_tw.tween_property(actor_a, "position", orig_a, 0.14).set_trans(Tween.TRANS_BOUNCE)
	back_tw.tween_property(actor_b, "position", orig_b, 0.14).set_trans(Tween.TRANS_BOUNCE)
	back_tw.tween_property(actor_a, "scale", Vector2.ONE, 0.14)
	back_tw.tween_property(actor_b, "scale", Vector2.ONE, 0.14)
	await back_tw.finished


func _play_social_play(actor_a: DragonActor, actor_b: DragonActor) -> void:
	var orig_a: Vector2 = actor_a.position
	var orig_b: Vector2 = actor_b.position

	actor_a.play_cinematic_pulse(0.85)
	actor_b.play_cinematic_pulse(0.85)

	var mid: Vector2 = (orig_a + orig_b) * 0.5

	var tw := create_tween().set_parallel(true)
	tw.tween_property(actor_a, "position", mid + Vector2(-34.0, -18.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(actor_b, "position", mid + Vector2(34.0, 18.0), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished

	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(actor_a, "position", orig_b, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(actor_b, "position", orig_a, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw2.finished

	if actor_a.has_method("show_float_text"):
		actor_a.show_float_text("!", Color(0.95, 0.95, 0.60))
	if actor_b.has_method("show_float_text"):
		actor_b.show_float_text("!", Color(0.95, 0.95, 0.60))

	var tw3 := create_tween().set_parallel(true)
	tw3.tween_property(actor_a, "position", orig_a, 0.20).set_trans(Tween.TRANS_BOUNCE)
	tw3.tween_property(actor_b, "position", orig_b, 0.20).set_trans(Tween.TRANS_BOUNCE)
	await tw3.finished


func _play_social_mock_chase(actor_a: DragonActor, actor_b: DragonActor) -> void:
	var start_b: Vector2 = actor_b.position
	var flee_target: Vector2 = _clamp_actor_target_to_enclosure(
		start_b + Vector2(randf_range(-70.0, 70.0), randf_range(-30.0, 30.0)),
		actor_b
	)

	actor_a.play_cinematic_pulse(0.80)
	actor_b.play_cinematic_pulse(0.60)

	if actor_a.has_method("show_float_text"):
		actor_a.show_float_text("Rrr!", Color(1.0, 0.62, 0.62))

	var tw := create_tween().set_parallel(true)
	tw.tween_property(actor_b, "position", flee_target, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(actor_a, "position", _clamp_actor_target_to_enclosure(flee_target + Vector2(-24.0, 0.0), actor_a), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished

	await get_tree().create_timer(0.16).timeout


func _play_social_rival_stare(actor_a: DragonActor, actor_b: DragonActor) -> void:
	actor_a.play_cinematic_roar(0.85, 1.00, 1.0)
	await get_tree().create_timer(0.08).timeout
	actor_b.play_cinematic_roar(0.88, 1.02, 1.0)

	if actor_a.has_method("show_float_text"):
		actor_a.show_float_text("Hss!", Color(1.0, 0.50, 0.50))
	if actor_b.has_method("show_float_text"):
		actor_b.show_float_text("Hss!", Color(1.0, 0.50, 0.50))

	_shake_enclosure(2.0, 0.10)
	await get_tree().create_timer(0.55).timeout
	
func _apply_social_interaction_effects(uid_a: String, uid_b: String, interaction_type: String) -> void:
	var index_a: int = _get_dragon_index_by_uid(uid_a)
	var index_b: int = _get_dragon_index_by_uid(uid_b)
	if index_a == -1 or index_b == -1:
		return

	var dragon_a: Dictionary = DragonManager.player_dragons[index_a]
	var dragon_b: Dictionary = DragonManager.player_dragons[index_b]

	var social_delta: int = 0
	var happy_delta_a: int = 0
	var happy_delta_b: int = 0

	match interaction_type:
		"greet":
			social_delta = 1
			happy_delta_a = 1
			happy_delta_b = 1

		"nuzzle":
			social_delta = 3
			happy_delta_a = 2
			happy_delta_b = 2

		"play":
			social_delta = 2
			happy_delta_a = 3
			happy_delta_b = 3

		"mock_chase":
			social_delta = 1
			happy_delta_a = 2
			happy_delta_b = 1

		"rival_stare":
			social_delta = -2
			happy_delta_a = -1
			happy_delta_b = -1

		_:
			social_delta = 0

	# Age-stage tuning: babies react more strongly; adults are more even-keeled.
	var stage_a: int = int(dragon_a.get("stage", 2))
	var stage_b: int = int(dragon_b.get("stage", 2))
	if interaction_type == "play":
		if stage_a == 1: happy_delta_a += 1
		if stage_b == 1: happy_delta_b += 1
		if stage_a == 3: happy_delta_a = max(happy_delta_a - 1, 0)
		if stage_b == 3: happy_delta_b = max(happy_delta_b - 1, 0)
	elif interaction_type == "mock_chase":
		if stage_a == 1: happy_delta_a += 1
		if stage_b == 1: happy_delta_b += 1
		if stage_a == 3: happy_delta_a = max(happy_delta_a - 1, -2)
		if stage_b == 3: happy_delta_b = max(happy_delta_b - 1, -2)
	elif interaction_type == "rival_stare":
		# Babies get less upset by staring contests.
		if stage_a == 1: happy_delta_a = min(happy_delta_a + 1, 0)
		if stage_b == 1: happy_delta_b = min(happy_delta_b + 1, 0)

	DragonManager.change_social_score(uid_a, uid_b, social_delta)

	dragon_a["happiness"] = clampi(int(dragon_a.get("happiness", 50)) + happy_delta_a, 0, 100)
	dragon_b["happiness"] = clampi(int(dragon_b.get("happiness", 50)) + happy_delta_b, 0, 100)

	DragonManager._refresh_dragon_mood(dragon_a)
	DragonManager._refresh_dragon_mood(dragon_b)	
	
func _setup_training_ui() -> void:
	if training_program_option == null or training_intensity_option == null:
		return

	training_program_ids.clear()
	training_program_option.clear()

	var programs: Array = DragonManager.get_training_program_list()
	for program_var in programs:
		var program: Dictionary = program_var
		var program_id: String = str(program.get("id", ""))
		var display_name: String = str(program.get("display_name", program_id))
		if program_id == "":
			continue

		training_program_ids.append(program_id)
		training_program_option.add_item(display_name)

	if training_program_option.item_count > 0:
		training_program_option.select(0)

	training_intensity_option.clear()
	training_intensity_option.add_item("Light")
	training_intensity_option.add_item("Normal")
	training_intensity_option.add_item("Intense")
	training_intensity_option.select(DragonManager.TRAINING_INTENSITY_NORMAL)

	for i in range(training_program_option.item_count):
		var pid: String = training_program_ids[i]
		var tip: String = DragonManager.get_training_program_tooltip_plain(pid)
		training_program_option.set_item_tooltip(
			i,
			_CampUiSkin.plain_tooltip_word_wrap(tip)
		)

	training_intensity_option.set_item_tooltip(
		0,
		_CampUiSkin.plain_tooltip_word_wrap(
			DragonManager.get_training_intensity_tooltip_plain(DragonManager.TRAINING_INTENSITY_LIGHT)
		)
	)
	training_intensity_option.set_item_tooltip(
		1,
		_CampUiSkin.plain_tooltip_word_wrap(
			DragonManager.get_training_intensity_tooltip_plain(DragonManager.TRAINING_INTENSITY_NORMAL)
		)
	)
	training_intensity_option.set_item_tooltip(
		2,
		_CampUiSkin.plain_tooltip_word_wrap(
			DragonManager.get_training_intensity_tooltip_plain(DragonManager.TRAINING_INTENSITY_INTENSE)
		)
	)

	if training_preview_label != null:
		training_preview_label.bbcode_enabled = true
		training_preview_label.scroll_active = false

	if training_selection_help_label != null:
		training_selection_help_label.bbcode_enabled = true
		training_selection_help_label.scroll_active = false

	_ranch_theme_option_button_popup(training_program_option)
	_ranch_theme_option_button_popup(training_intensity_option)

	_refresh_training_controls()


func _get_selected_training_program_id() -> String:
	if training_program_option == null:
		return ""

	var selected_idx: int = training_program_option.get_selected()
	if selected_idx < 0 or selected_idx >= training_program_ids.size():
		return ""

	return training_program_ids[selected_idx]


func _get_selected_training_intensity() -> int:
	if training_intensity_option == null:
		return DragonManager.TRAINING_INTENSITY_NORMAL

	var selected_idx: int = training_intensity_option.get_selected()

	match selected_idx:
		DragonManager.TRAINING_INTENSITY_LIGHT:
			return DragonManager.TRAINING_INTENSITY_LIGHT
		DragonManager.TRAINING_INTENSITY_INTENSE:
			return DragonManager.TRAINING_INTENSITY_INTENSE
		_:
			return DragonManager.TRAINING_INTENSITY_NORMAL


func _on_training_selection_changed(_index: int) -> void:
	_refresh_training_controls()


func _ranch_theme_option_button_popup(ob: OptionButton) -> void:
	if ob == null:
		return
	var pop: PopupMenu = ob.get_popup()
	if pop == null:
		return
	var base_theme: Theme = ThemeDB.get_project_theme()
	if base_theme == null:
		base_theme = ThemeDB.get_default_theme()
	var th: Theme = base_theme.duplicate() if base_theme != null else Theme.new()
	th.set_stylebox(
		"panel",
		"TooltipPanel",
		_CampUiSkin.make_panel_style(
			_CampUiSkin.CAMP_PANEL_BG_ALT,
			_CampUiSkin.CAMP_BORDER_SOFT,
			14,
			6
		)
	)
	th.set_color("font_color", "TooltipLabel", _CampUiSkin.CAMP_TEXT)
	th.set_font_size("font_size", "TooltipLabel", 14)
	pop.theme = th


func _update_care_actions_help(dragon_stage: int) -> void:
	if care_actions_help_label == null:
		return
	care_actions_help_label.text = (
		DragonManager.get_ranch_care_help_feed_bbcode(dragon_stage)
		+ "\n\n"
		+ DragonManager.get_ranch_care_help_hunt_bbcode(dragon_stage, RABBIT_COST)
	)


func _update_training_selection_help() -> void:
	if training_selection_help_label == null:
		return
	if training_program_option == null or training_intensity_option == null:
		return

	var program_id: String = _get_selected_training_program_id()
	var intensity: int = _get_selected_training_intensity()

	if program_id == "":
		training_selection_help_label.text = (
			"[color=#9a8f82]Choose a training program and intensity. "
			+ "Hover an option in the menus for a short summary.[/color]"
		)
		return

	training_selection_help_label.text = (
		DragonManager.get_training_program_player_help_bbcode(program_id)
		+ "\n\n"
		+ DragonManager.get_training_intensity_player_help_bbcode(intensity)
	)


func _refresh_training_controls() -> void:
	_update_training_selection_help()

	if training_preview_label == null and train_dragon_btn == null and rest_dragon_btn == null:
		_ranch_sync_rail_rich_min_heights()
		return

	var selected_index: int = _get_selected_index()
	if selected_index < 0 or selected_index >= DragonManager.player_dragons.size():
		if training_preview_label != null:
			training_preview_label.text = "[color=gray]Select a dragon first.[/color]"
		if train_dragon_btn != null:
			train_dragon_btn.disabled = true
			train_dragon_btn.text = "Train"
		if rest_dragon_btn != null:
			rest_dragon_btn.disabled = true
			rest_dragon_btn.text = "Rest Dragon"
		if training_program_option != null:
			training_program_option.disabled = true
		if training_intensity_option != null:
			training_intensity_option.disabled = true
		_ranch_refresh_training_richtext_after_copy_change()
		return

	var dragon: Dictionary = DragonManager.player_dragons[selected_index]
	var already_used: bool = _dragon_has_used_ranch_action(dragon)

	var controls_busy: bool = (
		is_feed_animating or
		is_pet_animating or
		is_hunt_animating or
		is_hatch_animating or
		is_training_animating
	)

	if training_program_option != null:
		training_program_option.disabled = controls_busy or already_used

	if training_intensity_option != null:
		training_intensity_option.disabled = controls_busy or already_used

	if already_used:
		if training_preview_label != null:
			training_preview_label.text = "[color=orange]This dragon already used its ranch action for this level.[/color]"

		if train_dragon_btn != null:
			train_dragon_btn.disabled = true
			train_dragon_btn.text = "Already Used"

		if rest_dragon_btn != null:
			rest_dragon_btn.disabled = true
			rest_dragon_btn.text = "Already Used"

		_ranch_refresh_training_richtext_after_copy_change()
		return

	var program_id: String = _get_selected_training_program_id()
	var intensity: int = _get_selected_training_intensity()

	if program_id == "":
		if training_preview_label != null:
			training_preview_label.text = "[color=gray]No training program selected.[/color]"
		if train_dragon_btn != null:
			train_dragon_btn.disabled = true
			train_dragon_btn.text = "Train"
		if rest_dragon_btn != null:
			rest_dragon_btn.disabled = true
			rest_dragon_btn.text = "Rest Dragon"
		_ranch_refresh_training_richtext_after_copy_change()
		return

	var preview: Dictionary = DragonManager.get_training_preview(selected_index, program_id, intensity)

	if training_preview_label != null:
		if bool(preview.get("ok", false)):
			var possible_stats: Array = preview.get("possible_stats", [])
			var stat_text: String = "None"
			if not possible_stats.is_empty():
				var disp: PackedStringArray = PackedStringArray()
				for sk in possible_stats:
					disp.append(DragonManager.get_training_stat_display_name(str(sk)))
				stat_text = ", ".join(disp)

			training_preview_label.text = (
				"%s\n" % str(preview.get("program_name", "Training")) +
				"Cost: [color=gold]%d gold[/color]\n" % int(preview.get("gold_cost", 0)) +
				"Happiness: [color=salmon]-%d[/color]   Fatigue: [color=orange]+%d[/color]\n" % [
					int(preview.get("happiness_loss", 0)),
					int(preview.get("fatigue_gain", 0))
				] +
				"Possible gains: [color=cyan]%s[/color]" % stat_text
			)
		else:
			training_preview_label.text = "[color=red]%s[/color]" % str(preview.get("error", "Training unavailable."))

	if train_dragon_btn != null:
		train_dragon_btn.disabled = controls_busy or not bool(preview.get("ok", false))
		train_dragon_btn.text = "Train (%d Gold)" % int(preview.get("gold_cost", 0))

	if rest_dragon_btn != null:
		var fatigue_value: int = int(dragon.get("fatigue", 0))
		rest_dragon_btn.disabled = controls_busy or fatigue_value <= 0
		rest_dragon_btn.text = "Rest Dragon"

	_ranch_refresh_training_richtext_after_copy_change()

func _set_train_btn_temp_text(text: String, delay: float = 1.2) -> void:
	if train_dragon_btn == null:
		return

	train_dragon_btn.text = text
	var _ranch_self_wr: WeakRef = weakref(self)
	get_tree().create_timer(delay).timeout.connect(func():
		if _ranch_self_wr.get_ref() != null:
			_refresh_training_controls()
	)


func _on_train_pressed() -> void:
	if is_feed_animating or is_pet_animating or is_hunt_animating or is_hatch_animating or is_training_animating:
		return

	var selected_index: int = _get_selected_index()
	if selected_index < 0 or selected_index >= DragonManager.player_dragons.size():
		return

	var program_id: String = _get_selected_training_program_id()
	var intensity: int = _get_selected_training_intensity()
	var preview: Dictionary = DragonManager.get_training_preview(selected_index, program_id, intensity)

	if not bool(preview.get("ok", false)):
		_set_train_btn_temp_text(str(preview.get("error", "Training failed.")))
		_refresh_training_controls()
		return

	var actor: DragonActor = _get_actor_by_uid(selected_dragon_uid)
	is_training_animating = true
	_refresh_training_controls()
	_update_info_card()

	var result: Dictionary = DragonManager.train_dragon(selected_index, program_id, intensity)

	if not bool(result.get("ok", false)):
		is_training_animating = false
		_refresh_training_controls()
		_update_info_card()
		_set_train_btn_temp_text(str(result.get("error", "Training failed.")))
		return
	
	_mark_selected_dragon_ranch_action_used()

	if actor != null:
		await _play_training_fx(actor, result)
		actor.refresh_from_data(DragonManager.player_dragons[selected_index])

	is_training_animating = false
	_update_info_card()
	_refresh_training_controls()


func _on_rest_pressed() -> void:
	if is_feed_animating or is_pet_animating or is_hunt_animating or is_hatch_animating or is_training_animating:
		return

	var selected_index: int = _get_selected_index()
	if selected_index < 0 or selected_index >= DragonManager.player_dragons.size():
		return

	var dragon: Dictionary = DragonManager.player_dragons[selected_index]
	if _dragon_has_used_ranch_action(dragon):
		_refresh_training_controls()
		return

	is_training_animating = true
	_refresh_training_controls()

	var result: Dictionary = DragonManager.rest_dragon(selected_index, 25)
	var actor: DragonActor = _get_actor_by_uid(selected_dragon_uid)

	if bool(result.get("ok", false)):
		_mark_selected_dragon_ranch_action_used()

		if actor != null:
			actor.set_cinematic_mode(true)
			actor.play_cinematic_pulse(0.55)
			if actor.has_method("show_float_text"):
				actor.show_float_text("Rested", Color(0.70, 1.0, 0.85))
			await get_tree().create_timer(0.35).timeout
			actor.set_cinematic_mode(false)
			actor.refresh_from_data(DragonManager.player_dragons[selected_index])

	is_training_animating = false
	_update_info_card()
	_refresh_training_controls()

func _play_training_fx(actor: DragonActor, result: Dictionary) -> void:
	if actor == null or not is_instance_valid(actor):
		return
		
	_trigger_morgra("train")
	actor.set_cinematic_mode(true)
	actor.play_cinematic_pulse(0.90)

	if actor.has_method("show_float_text"):
		actor.show_float_text("Training!", Color(0.65, 0.90, 1.0))

	_shake_enclosure(3.0, 0.10)
	await get_tree().create_timer(0.30).timeout

	var stat_gains: Dictionary = result.get("stat_gains", {})
	for stat_key in stat_gains.keys():
		var amount: int = int(stat_gains.get(stat_key, 0))
		if amount > 0 and actor.has_method("show_float_text"):
			actor.show_float_text("+" + str(amount) + " " + str(stat_key).capitalize(), Color(1.0, 0.90, 0.55))
			await get_tree().create_timer(0.18).timeout

	if bool(result.get("breakthrough", false)):
		actor.play_cinematic_roar(0.92, 1.04, 1.0)
		if actor.has_method("show_float_text"):
			actor.show_float_text("Breakthrough!", Color(1.0, 0.78, 0.30))
		_shake_enclosure(6.0, 0.15)
		await get_tree().create_timer(0.35).timeout

	actor.set_cinematic_mode(false)

func _dragon_has_used_ranch_action(dragon: Dictionary) -> bool:
	return bool(dragon.get("ranch_action_used_this_level", false))


func _mark_selected_dragon_ranch_action_used() -> void:
	var selected_index: int = _get_selected_index()
	if selected_index < 0 or selected_index >= DragonManager.player_dragons.size():
		return

	DragonManager.player_dragons[selected_index]["ranch_action_used_this_level"] = true

# ==========================================
# MORGRA DIALOGUE TRIGGER
# ==========================================
func _trigger_morgra(category: String) -> void:
	var camp_menu = get_parent()
	if camp_menu.has_method("_update_herder_text"):
		camp_menu._update_herder_text(category)

# Call this inside _on_visibility_changed() or whenever a dragon is hatched/removed
func _update_favorite_display() -> void:
	if not favorite_label:
		return
	favorite_label.modulate = Color.WHITE
	var fav_uid = CampaignManager.morgra_favorite_dragon_uid
	if fav_uid == "":
		favorite_label.text = "Morgra's Favorite: None"
		_CampUiSkin.style_label(favorite_label, _CampUiSkin.CAMP_MUTED, 15)
		return

	var fav_name = ""
	for d in DragonManager.player_dragons:
		if str(d.get("uid", "")) == fav_uid:
			fav_name = str(d.get("name", "Unknown"))
			break

	if fav_name != "":
		favorite_label.text = "Morgra's Favorite: " + fav_name
		_CampUiSkin.style_label(favorite_label, _CampUiSkin.CAMP_BORDER, 16)
	else:
		favorite_label.text = "Morgra's Favorite: Missing"
		_CampUiSkin.style_label(favorite_label, _CampUiSkin.CAMP_MUTED, 15)

# ==========================================
# DEBUG TESTING FUNCTIONS
# ==========================================

func _debug_force_anger() -> void:
	CampaignManager.morgra_anger_duration = 3
	CampaignManager.morgra_neutral_duration = 0
	_trigger_morgra("welcome") # Refresh her dialogue immediately
	print("DEBUG: Morgra is now Furious.")

func _debug_force_neutral() -> void:
	CampaignManager.morgra_anger_duration = 0
	CampaignManager.morgra_neutral_duration = 2
	_trigger_morgra("welcome")
	print("DEBUG: Morgra is now Neutral.")

func _debug_force_adore() -> void:
	CampaignManager.morgra_anger_duration = 0
	CampaignManager.morgra_neutral_duration = 0
	# Ensure she has a favorite to adore!
	if CampaignManager.morgra_favorite_dragon_uid == "" and DragonManager.player_dragons.size() > 0:
		CampaignManager.morgra_favorite_dragon_uid = str(DragonManager.player_dragons[0].get("uid", ""))
	
	CampaignManager.morgra_favorite_survived_battles = 10
	_update_favorite_display()
	_trigger_morgra("welcome")
	print("DEBUG: Morgra is now Adoring.")

func _debug_reset_morgra() -> void:
	CampaignManager.morgra_anger_duration = 0
	CampaignManager.morgra_neutral_duration = 0
	CampaignManager.morgra_favorite_survived_battles = 0
	_trigger_morgra("welcome")
	print("DEBUG: Morgra states reset.")


# --- Camp-aligned chrome -----------------------------------------------------
func _ensure_enclosure_pen_frame() -> void:
	if enclosure == null:
		return
	if enclosure_pen_border != null and is_instance_valid(enclosure_pen_border):
		_sync_enclosure_pen_rect()
		return
	enclosure_pen_border = Panel.new()
	enclosure_pen_border.name = "EnclosurePenBorder"
	enclosure_pen_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enclosure_pen_border.layout_mode = enclosure.layout_mode
	add_child(enclosure_pen_border)
	move_child(enclosure_pen_border, enclosure.get_index())
	_sync_enclosure_pen_rect()
	if not enclosure.resized.is_connected(_on_enclosure_pen_resized):
		enclosure.resized.connect(_on_enclosure_pen_resized)
	_CampUiSkin.style_panel(enclosure_pen_border, _CampUiSkin.CAMP_PANEL_BG_SOFT, _CampUiSkin.CAMP_BORDER_SOFT, 22, 8)
	enclosure.color = Color(0.055, 0.042, 0.030, 1.0)


func _on_enclosure_pen_resized() -> void:
	_sync_enclosure_pen_rect()
	_sync_herder_corner_layout()


func _sync_enclosure_pen_rect() -> void:
	if enclosure_pen_border == null or enclosure == null:
		return
	var pad := 8.0
	enclosure_pen_border.layout_mode = enclosure.layout_mode
	enclosure_pen_border.anchor_left = enclosure.anchor_left
	enclosure_pen_border.anchor_top = enclosure.anchor_top
	enclosure_pen_border.anchor_right = enclosure.anchor_right
	enclosure_pen_border.anchor_bottom = enclosure.anchor_bottom
	enclosure_pen_border.offset_left = enclosure.offset_left - pad
	enclosure_pen_border.offset_top = enclosure.offset_top - pad
	enclosure_pen_border.offset_right = enclosure.offset_right + pad
	enclosure_pen_border.offset_bottom = enclosure.offset_bottom + pad
	enclosure_pen_border.grow_horizontal = enclosure.grow_horizontal
	enclosure_pen_border.grow_vertical = enclosure.grow_vertical


func _sync_herder_corner_layout() -> void:
	if enclosure == null or not is_instance_valid(enclosure):
		return
	if herder_portrait_rect == null and herder_dialogue_label == null and favorite_label == null:
		return
	var m := 14.0
	var portrait_w := 290.0
	var portrait_h := 285.0
	var text_strip_h := 68.0
	var fav_w := 236.0
	var gap := 12.0
	var L := enclosure.offset_left + m
	var R := enclosure.offset_right - m
	var B := enclosure.offset_bottom - m
	var pb := B - text_strip_h - gap
	var pt := pb - portrait_h
	if herder_portrait_rect != null:
		herder_portrait_rect.offset_left = L
		herder_portrait_rect.offset_top = pt
		herder_portrait_rect.offset_right = L + portrait_w
		herder_portrait_rect.offset_bottom = pb
		herder_portrait_rect.z_index = 25
	var dt := pb + gap
	# Dialogue bubble uses half the width it had when it spanned to the favorite column reserve.
	var dr_full: float = R - fav_w - gap
	var dialogue_w: float = (dr_full - L) * 0.5
	var dr: float = L + maxf(dialogue_w, 120.0)
	if herder_dialogue_label != null:
		herder_dialogue_label.offset_left = L
		herder_dialogue_label.offset_top = dt
		herder_dialogue_label.offset_right = dr
		herder_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		herder_dialogue_label.z_index = 26
		herder_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if favorite_label != null:
		var fl: float = dr + gap
		favorite_label.offset_left = fl
		favorite_label.offset_right = R
		favorite_label.offset_top = dt
		favorite_label.z_index = 26
		favorite_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	call_deferred("_ranch_finalize_herder_bubble_size")


func refit_herder_dialogue_bubble() -> void:
	call_deferred("_ranch_finalize_herder_bubble_size")


func _ranch_apply_herder_plate_padding() -> void:
	if herder_dialogue_plate == null or not is_instance_valid(herder_dialogue_plate):
		return
	if herder_dialogue_label == null or not is_instance_valid(herder_dialogue_label):
		return
	var dp := 8.0
	herder_dialogue_plate.offset_left = herder_dialogue_label.offset_left - dp
	herder_dialogue_plate.offset_top = herder_dialogue_label.offset_top - dp
	herder_dialogue_plate.offset_right = herder_dialogue_label.offset_right + dp
	herder_dialogue_plate.offset_bottom = herder_dialogue_label.offset_bottom + dp
	herder_dialogue_plate.z_index = 24


func _ranch_finalize_herder_bubble_size() -> void:
	if herder_dialogue_label == null or not is_instance_valid(herder_dialogue_label):
		return
	if enclosure == null or not is_instance_valid(enclosure):
		return
	var lbl := herder_dialogue_label
	var m := 14.0
	var B := enclosure.offset_bottom - m
	var w: float = lbl.offset_right - lbl.offset_left
	if w < 4.0:
		return
	var font: Font = lbl.get_theme_font("font")
	var font_size: int = lbl.get_theme_font_size("font_size")
	var txt: String = lbl.text
	var text_h: float
	if txt.is_empty():
		text_h = lbl.get_line_height()
	else:
		var block: Vector2 = font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, w, font_size)
		text_h = float(block.y)
	var pad_y := 22.0
	var height_extra := 10.0
	var min_h := lbl.get_line_height() + pad_y
	var max_h := maxf(40.0, B - lbl.offset_top - 4.0)
	var h := clampf(text_h + pad_y + height_extra, min_h, max_h)
	lbl.offset_bottom = lbl.offset_top + h
	if favorite_label != null and is_instance_valid(favorite_label):
		favorite_label.offset_top = lbl.offset_top
		favorite_label.offset_bottom = lbl.offset_bottom
	_ranch_apply_herder_plate_padding()


func _ensure_breed_dimmer() -> void:
	if breed_dimmer != null and is_instance_valid(breed_dimmer):
		return
	breed_dimmer = ColorRect.new()
	breed_dimmer.name = "BreedDimmer"
	breed_dimmer.color = BREED_STATION_DIMMER_COLOR
	breed_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	breed_dimmer.visible = false
	breed_dimmer.layout_mode = 1
	breed_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	breed_dimmer.offset_left = 0.0
	breed_dimmer.offset_top = 0.0
	breed_dimmer.offset_right = 0.0
	breed_dimmer.offset_bottom = 0.0
	breed_dimmer.z_index = 800
	add_child(breed_dimmer)
	# z_index must stay within RenderingServer.CANVAS_ITEM_Z_MAX (4096).
	if breed_panel != null:
		breed_panel.z_index = 3000
	if breed_selection_popup != null:
		breed_selection_popup.z_index = 3100


func _ensure_herder_chrome() -> void:
	var stale_portrait_frame: Node = get_node_or_null("HerderPortraitFrame")
	if stale_portrait_frame != null:
		stale_portrait_frame.queue_free()
	if herder_portrait_rect != null:
		herder_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if herder_dialogue_label != null:
		var dp := 8.0
		if herder_dialogue_plate == null or not is_instance_valid(herder_dialogue_plate):
			herder_dialogue_plate = Panel.new()
			herder_dialogue_plate.name = "HerderDialoguePlate"
			herder_dialogue_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
			herder_dialogue_plate.layout_mode = herder_dialogue_label.layout_mode
			add_child(herder_dialogue_plate)
			move_child(herder_dialogue_plate, herder_dialogue_label.get_index())
			_CampUiSkin.style_panel(herder_dialogue_plate, _CampUiSkin.CAMP_PANEL_BG, _CampUiSkin.CAMP_BORDER_SOFT, 18, 6)
		_CampUiSkin.style_label(herder_dialogue_label, _CampUiSkin.CAMP_TEXT, 17, 1)

	_sync_herder_corner_layout()

	_ranch_apply_herder_plate_padding()
	if herder_dialogue_label != null:
		herder_dialogue_label.z_index = 26


func _ranch_style_dragon_card_section_plate(plate: PanelContainer) -> void:
	if plate == null:
		return
	_CampUiSkin.style_panel_surface(
		plate,
		Color(
			_CampUiSkin.CAMP_PANEL_BG.r,
			_CampUiSkin.CAMP_PANEL_BG.g,
			_CampUiSkin.CAMP_PANEL_BG.b,
			0.92
		),
		_CampUiSkin.CAMP_BORDER_SOFT,
		14,
		3
	)


func _ranch_configure_card_richtext_rail(rtl: RichTextLabel) -> void:
	if rtl == null:
		return
	# fit_content shrinks the control rect to text width; centered strips miss button hit targets on the midline.
	rtl.fit_content = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.focus_mode = Control.FOCUS_NONE
	rtl.clip_contents = true
	rtl.selection_enabled = false
	rtl.shortcut_keys_enabled = false


func _ranch_sync_rail_rich_min_heights() -> void:
	call_deferred("_ranch_sync_rail_rich_min_heights_impl")


func _ranch_sync_rail_rich_min_heights_impl() -> void:
	var rails: Array[RichTextLabel] = [
		details_label,
		traits_label,
		training_meta_label,
		training_preview_label,
		training_selection_help_label,
		care_actions_help_label,
		growth_bonus_label,
	]
	for rtl in rails:
		if rtl == null or not is_instance_valid(rtl):
			continue
		var h: float = clampf(rtl.get_content_height(), 1.0, 4000.0)
		rtl.custom_minimum_size.y = ceil(h)


func _ranch_refresh_training_richtext_after_copy_change() -> void:
	if training_preview_label != null:
		_ranch_configure_card_richtext_rail(training_preview_label)
	if training_selection_help_label != null:
		_ranch_configure_card_richtext_rail(training_selection_help_label)
	_ranch_sync_rail_rich_min_heights()


func _ranch_fix_info_card_interaction_layers() -> void:
	# Scroll under training/close so overlaps prefer the strip below; keep indices modest so nothing “vanishes” behind siblings.
	if info_card_scroll != null:
		info_card_scroll.z_index = 0
		info_card_scroll.clip_contents = true
	if training_plate != null:
		training_plate.z_index = 10
	if close_card_btn != null:
		close_card_btn.z_index = 11
	# Full-width RichText rails + content height so layout matches visuals; option/action rows stay above.
	for n in [
		details_label,
		traits_label,
		training_meta_label,
		training_preview_label,
		training_selection_help_label,
		care_actions_help_label,
		growth_bonus_label,
	]:
		if n is RichTextLabel:
			_ranch_configure_card_richtext_rail(n as RichTextLabel)

	# Default VBoxContainer horizontal flag is shrink: training content stays narrow and centered inside
	# the plate. Clicks in the left/right bands hit Margin/Panel (mouse STOP), matching a tall dead zone.
	if training_status_block != null:
		training_status_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var training_vbox: VBoxContainer = null
	if training_program_option != null:
		var opt_row: Control = training_program_option.get_parent() as Control
		if opt_row != null:
			opt_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			opt_row.z_index = 6
			# MOUSE_FILTER_IGNORE on the row makes clicks in the seam between OptionButtons miss both
			# children and fall through to the VBox (dead zone). Default STOP + overlap closes the seam.
			if opt_row is HBoxContainer:
				(opt_row as HBoxContainer).add_theme_constant_override("separation", -3)
			training_vbox = opt_row.get_parent() as VBoxContainer
	if train_dragon_btn != null:
		var act_row: Control = train_dragon_btn.get_parent() as Control
		if act_row != null:
			act_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			act_row.z_index = 8
			if act_row is HBoxContainer:
				(act_row as HBoxContainer).add_theme_constant_override("separation", -3)
		if training_vbox == null and act_row != null:
			training_vbox = act_row.get_parent() as VBoxContainer
	if training_vbox != null and training_plate != null:
		training_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_ranch_sync_rail_rich_min_heights()


func _ranch_style_scroll_interactive(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	_CampUiSkin.style_scroll(scroll, false)
	# Helps mouse/touch reach nested Controls when the scroll node does not use STOP.
	scroll.mouse_force_pass_scroll_events = true


func _ranch_reassert_info_card_input_fix() -> void:
	if not is_instance_valid(self) or not visible:
		return
	if info_card_scroll != null:
		_ranch_style_scroll_interactive(info_card_scroll)
	_ranch_fix_info_card_interaction_layers()


func _apply_info_card_separators() -> void:
	var vbox: Node = info_card.get_node_or_null("InfoCardColumn/InfoCardScroll/VBoxContainer")
	if vbox == null:
		return
	for child in vbox.get_children():
		if child is HSeparator:
			var line := StyleBoxFlat.new()
			line.bg_color = Color(0.42, 0.35, 0.22, 0.45)
			line.set_content_margin_all(2.0)
			child.add_theme_stylebox_override("separator", line)


func _apply_ranch_camp_skin() -> void:
	_CampUiSkin.style_panel(self, _CampUiSkin.CAMP_PANEL_BG, _CampUiSkin.CAMP_BORDER, 24, 12)
	if info_card != null:
		_CampUiSkin.style_panel(info_card, _CampUiSkin.CAMP_PANEL_BG_ALT, _CampUiSkin.CAMP_BORDER_SOFT, 20, 6)
		# Clipping the card panel can make bottom controls miss input near tall scroll content / rounded corners.
		info_card.clip_contents = false
		# Sit above ranch siblings (hatch/breed/herder) if z ties; DragonStatsPopup uses much higher z.
		info_card.z_index = 40
	if enclosure != null:
		enclosure.clip_contents = true
		enclosure.z_index = 0
	if info_card_scroll != null:
		_ranch_style_scroll_interactive(info_card_scroll)
	if name_row_panel != null:
		_CampUiSkin.style_panel_surface(
			name_row_panel,
			_CampUiSkin.CAMP_PANEL_BG_SOFT.lightened(0.04),
			_CampUiSkin.CAMP_BORDER,
			16,
			3
		)
	if identity_plate != null:
		_CampUiSkin.style_panel_surface(
			identity_plate,
			Color(
				_CampUiSkin.CAMP_PANEL_BG.r,
				_CampUiSkin.CAMP_PANEL_BG.g,
				_CampUiSkin.CAMP_PANEL_BG.b,
				0.92
			),
			_CampUiSkin.CAMP_BORDER_SOFT,
			14,
			3
		)
	_ranch_style_dragon_card_section_plate(growth_plate)
	_ranch_style_dragon_card_section_plate(stats_plate)
	_ranch_style_dragon_card_section_plate(care_plate)
	_ranch_style_dragon_card_section_plate(training_plate)

	if header_label != null:
		_CampUiSkin.style_label(header_label, _CampUiSkin.CAMP_BORDER, 24)
		header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_CampUiSkin.style_button(close_btn, false, 18, 44.0)
	if name_input != null:
		_CampUiSkin.style_line_edit(name_input, 17, 40.0)
	if save_name_btn != null:
		_CampUiSkin.style_button(save_name_btn, true, 15, 40.0)

	const card_sec: int = 13
	const card_body: int = 14
	const card_cap: int = 12

	if details_label != null:
		_CampUiSkin.style_rich_label_flat(details_label, card_body)
		details_label.add_theme_color_override("default_color", _CampUiSkin.CAMP_TEXT)
	if traits_label != null:
		_CampUiSkin.style_rich_label_flat(traits_label, card_body)
		traits_label.add_theme_color_override("default_color", _CampUiSkin.CAMP_TEXT)
	if stats_section_header != null:
		_CampUiSkin.style_label(stats_section_header, _CampUiSkin.CAMP_BORDER, card_sec, 0)
	if care_actions_header != null:
		_CampUiSkin.style_label(care_actions_header, _CampUiSkin.CAMP_BORDER, card_sec, 0)

	if growth_section_header != null:
		_CampUiSkin.style_label(growth_section_header, _CampUiSkin.CAMP_BORDER, card_sec, 0)
	if happiness_bar_label != null:
		_CampUiSkin.style_label(happiness_bar_label, _CampUiSkin.CAMP_MUTED, card_cap, 0)
	if growth_fraction_label != null:
		_CampUiSkin.style_label(growth_fraction_label, _CampUiSkin.CAMP_MUTED, card_cap, 0)
	if happiness_mood_label != null:
		_CampUiSkin.style_label(happiness_mood_label, _CampUiSkin.CAMP_TEXT, card_cap, 0)
	if growth_bonus_label != null:
		_CampUiSkin.style_rich_label_flat(growth_bonus_label, card_cap)
	if dragon_growth_bar != null:
		_CampUiSkin.style_progress_bar(dragon_growth_bar, 16.0)
	if dragon_happiness_bar != null:
		_CampUiSkin.style_progress_bar(dragon_happiness_bar, 16.0)
	if training_section_header != null:
		_CampUiSkin.style_label(training_section_header, _CampUiSkin.CAMP_BORDER, card_sec, 0)
	if training_fatigue_caption != null:
		_CampUiSkin.style_label(training_fatigue_caption, _CampUiSkin.CAMP_MUTED, card_cap, 0)
	if training_fatigue_bar != null:
		_CampUiSkin.style_progress_bar(training_fatigue_bar, 16.0)
	if training_meta_label != null:
		_CampUiSkin.style_rich_label_flat(training_meta_label, card_body)

	if training_preview_label != null:
		_CampUiSkin.style_rich_label_flat(training_preview_label, card_body)

	if training_selection_help_label != null:
		_CampUiSkin.style_rich_label_flat(training_selection_help_label, card_cap)

	if training_program_option != null:
		_CampUiSkin.style_option_button(training_program_option, 14, 34.0)
	if training_intensity_option != null:
		_CampUiSkin.style_option_button(training_intensity_option, 14, 34.0)

	if train_dragon_btn != null:
		_CampUiSkin.style_button(train_dragon_btn, true, 15, 36.0)
	if rest_dragon_btn != null:
		_CampUiSkin.style_button(rest_dragon_btn, false, 15, 36.0)

	if feed_btn != null:
		_CampUiSkin.style_button(feed_btn, true, 15, 36.0)
	if hunt_btn != null:
		_CampUiSkin.style_button(hunt_btn, false, 15, 36.0)
	if care_actions_help_label != null:
		_CampUiSkin.style_rich_label_flat(care_actions_help_label, card_cap)

	_ranch_fix_info_card_interaction_layers()

	if close_card_btn != null:
		_CampUiSkin.style_button(close_card_btn, false, 15, 34.0)
	if open_dragon_stats_btn != null:
		_CampUiSkin.style_button(open_dragon_stats_btn, false, 15, 36.0)

	if dragon_stats_popup != null:
		_CampUiSkin.style_panel(dragon_stats_popup, _CampUiSkin.CAMP_PANEL_BG, _CampUiSkin.CAMP_BORDER, 22, 10)
	if dragon_stats_popup_title != null:
		_CampUiSkin.style_label(dragon_stats_popup_title, _CampUiSkin.CAMP_BORDER, 26, 1)
	if close_dragon_stats_btn != null:
		_CampUiSkin.style_button(close_dragon_stats_btn, false, 19, 46.0)
	if stats_popup_scroll != null:
		_ranch_style_scroll_interactive(stats_popup_scroll)

	if hatch_btn != null:
		_CampUiSkin.style_button(hatch_btn, true, 22, 52.0)
	if open_breed_btn != null:
		_CampUiSkin.style_button(open_breed_btn, true, 22, 52.0)

	if breed_panel != null:
		_CampUiSkin.style_panel(breed_panel, BREED_STATION_PANEL_BG, _CampUiSkin.CAMP_BORDER, 24, 12)
	if close_breed_btn != null:
		_CampUiSkin.style_button(close_breed_btn, false, 18, 44.0)
	if breed_title_label != null:
		_CampUiSkin.style_label(breed_title_label, _CampUiSkin.CAMP_BORDER, 22)
		breed_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if prediction_label != null:
		_CampUiSkin.style_rich_label(prediction_label, 17, _CampUiSkin.CAMP_PANEL_BG_SOFT, _CampUiSkin.CAMP_BORDER_SOFT, true)
		prediction_label.custom_minimum_size = Vector2(0, 120)

	if confirm_breed_btn != null:
		_CampUiSkin.style_button(confirm_breed_btn, true, 20, 52.0)

	if breed_selection_popup != null:
		_CampUiSkin.style_panel(breed_selection_popup, BREED_STATION_PANEL_BG, _CampUiSkin.CAMP_BORDER, 22, 10)
	if close_selection_btn != null:
		_CampUiSkin.style_button(close_selection_btn, false, 18, 44.0)
	if breed_scroll != null:
		_ranch_style_scroll_interactive(breed_scroll)

	if favorite_label != null:
		_update_favorite_display()

	_ensure_dragon_stats_dossier_ui()

	if debug_anger_btn != null:
		_CampUiSkin.style_button(debug_anger_btn, false, 14, 36.0)
	if debug_neutral_btn != null:
		_CampUiSkin.style_button(debug_neutral_btn, false, 14, 36.0)
	if debug_adore_btn != null:
		_CampUiSkin.style_button(debug_adore_btn, false, 14, 36.0)
	if debug_reset_btn != null:
		_CampUiSkin.style_button(debug_reset_btn, false, 14, 36.0)

	if breed_compat_value_label != null:
		_CampUiSkin.style_label(breed_compat_value_label, _CampUiSkin.CAMP_TEXT, 16)
	if breed_mutation_label != null:
		_CampUiSkin.style_rich_label(breed_mutation_label, 15)
		breed_mutation_label.fit_content = true
		breed_mutation_label.scroll_active = false

	_ranch_expand_breed_parent_slot_hit_areas()
	if parent_a_btn != null:
		_set_parent_button_style(parent_a_btn, Color.WHITE, false)
	if parent_b_btn != null:
		_set_parent_button_style(parent_b_btn, Color.WHITE, false)

	_apply_info_card_separators()
