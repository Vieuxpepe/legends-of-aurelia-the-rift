 # ==============================================================================
 # Purpose / Dependencies / AI Guidance
 # ==============================================================================
 # Purpose
 # Camp / hub controller between battles. Owns the camp UI flow: save/load,
 # shop (buy/sell/haggle), blacksmith crafting/recipes, dragon ranch, skill tree,
 # jukebox, inventory/convoy + equip, quest/dialogue panels, and navigation to
 # World Map / next battle.
 #
 # Dependencies
 # - Autoloads/singletons:
 #   - CampaignManager: player_roster, global_inventory, save/load, progression gates,
 #     shop stock, unlocks, settings/state used across camp subsystems.
 #   - PlayerStats / Inventory (if present as autoloads in this project): camp UI reads/writes
 #     player stats and item ownership via the project’s global state layer.
 #   - DragonManager: dragon roster + hatch/ownership flows used by the ranch panel.
 #   - DialogueDatabase: merchant/herder/blacksmith talk lines + selection helpers.
 #   - SceneTransition: scene changes to map/levels/arena.
 #
 # AI/Reviewer Guidance
 # - Entry point: `_ready()` wires signals and performs initial population.
 # - Core UI refresh: `_populate_*` helpers rebuild labels/grids and panel content.
 # - Signal callbacks: `_on_*` methods are the primary UI event handlers.
 # - Node access convention: this script primarily uses `%UniqueName` via `get_node_or_null`
 #   to avoid brittle paths; keep Unique Names in the scene in sync with these references.
 # ==============================================================================
extends Control

const TASK_LOG_SCRIPT := preload("res://Scripts/TaskLog.gd")
const PromotionChoiceUiHelpers = preload("res://Scripts/Core/BattleField/BattleFieldPromotionChoiceUiHelpers.gd")
const PromotionFlowSharedHelpers = preload("res://Scripts/Core/PromotionFlowSharedHelpers.gd")
const CAMP_PANEL_BG := Color(0.13, 0.097, 0.068, 0.88)
const CAMP_PANEL_BG_ALT := Color(0.17, 0.126, 0.083, 0.94)
const CAMP_PANEL_BG_SOFT := Color(0.08, 0.061, 0.043, 0.82)
const CAMP_BORDER := Color(0.82, 0.66, 0.24, 0.96)
const CAMP_BORDER_SOFT := Color(0.47, 0.38, 0.17, 0.94)
const CAMP_TEXT := Color(0.94, 0.91, 0.84, 1.0)
const CAMP_MUTED := Color(0.73, 0.68, 0.60, 1.0)
const CAMP_ACCENT_CYAN := Color(0.48, 0.87, 1.0, 1.0)
const CAMP_ACCENT_GREEN := Color(0.40, 0.94, 0.54, 1.0)
const CAMP_ACTION_PRIMARY := Color(0.76, 0.58, 0.19, 0.96)
const CAMP_ACTION_SECONDARY := Color(0.28, 0.21, 0.13, 0.94)
const CAMP_UNIT_INFO_STAT_BAR_CAP := 50.0
const CAMP_UNIT_INFO_STAT_TIER_CYAN := Color(0.28, 0.88, 1.0, 1.0)
const CAMP_UNIT_INFO_STAT_TIER_PURPLE := Color(0.76, 0.48, 1.0, 1.0)
const CAMP_UNIT_INFO_STAT_TIER_ORANGE := Color(1.0, 0.64, 0.22, 1.0)
const CAMP_UNIT_INFO_STAT_TIER_WHITE := Color(0.96, 0.96, 0.98, 1.0)
const CAMP_QM_DESC_FONT_SIZE := 23
const CAMP_QM_DESC_STYLE_MARGIN_H := 18
const CAMP_QM_DESC_STYLE_MARGIN_V := 14
## Debug: show the camp Blacksmith button without clearing level 3+. Set to false for release / real progression tests.
const DEBUG_CAMP_ALWAYS_SHOW_BLACKSMITH := true

# =============================================================================
# camp_menu.gd – Camp / Hub Scene Controller
# =============================================================================
#
# Purpose: Central hub between battles. Handles save/load, shop (buy/sell/haggle),
# blacksmith (crafting, recipe book), dragon ranch, skill tree, jukebox, merchant
# dialogue/quests, inventory/convoy, roster/equip, and navigation to World Map
# or next battle. Fits into the flow: Battle -> Camp (this) -> World Map or
# Next Battle -> Level select / Arena / Story.
#
# Dependencies (autoloads / scenes):
#   - CampaignManager: save/load, player_roster, global_inventory, camp_shop_stock,
#     max_unlocked_index, blacksmith_unlocked. See save/load and progression gates.
#   - DragonManager: player_dragons, hatch_egg(). See dragon ranch and inventory.
#   - DialogueDatabase: talk_lines for merchant/herder/blacksmith. See _line(), _pick_line().
#   - SceneTransition: change_scene_to_file() for World Map, Arena, levels.
#   - SilentWolf: (optional) if used elsewhere for scores; camp uses local/CampaignManager.
#
# --- AI/Reviewer: Main entry and sections ---
#   Entry: _ready() wires all buttons and populates shop/roster/inventory.
#   Save: _on_save_clicked, _try_to_save, _on_overwrite_confirmed, _proceed_with_save, _update_slot_labels.
#   Shop: _populate_shop, _on_buy_pressed, _on_sell_pressed, haggle minigame, quantity popup.
#   Blacksmith: open_blacksmith, _on_craft_pressed, anvil slots, recipe book, _try_unlock_recipe.
#   Roster/Equip: _populate_roster, _on_roster_item_selected, _on_equip_pressed, _on_unequip_pressed.
#   Inventory: _populate_inventory, _clear_grids, _build_unit_grid, _build_shared_grid, category_tabs.
#   Navigation: _on_next_battle_pressed, _on_world_map_pressed.
#   Extension: Add new panels in _ready() and follow existing % Unique Name pattern for nodes.
#
# =============================================================================

# Use % for Unique Name access - this ignores the path entirely!
@onready var main_camp_vbox: VBoxContainer = get_node_or_null("%MainVBox") # Only if you use a container
@onready var save_slot_vbox: VBoxContainer = get_node_or_null("%SaveSlotContainer")
@onready var overwrite_dialog: ConfirmationDialog = get_node_or_null("%OverwriteConfirmation")
@onready var save_confirm_sound: AudioStreamPlayer = get_node_or_null("%SaveConfirmSound")
@onready var shop_buy_sound: AudioStreamPlayer = get_node_or_null("%ShopBuySound")
@onready var shop_sell_sound: AudioStreamPlayer = get_node_or_null("%ShopSellSound")
@export var campfire_ambient: AudioStream # Drag your fire crackling sound here!
@onready var masterwork_sound: AudioStreamPlayer = $MasterworkSound
@onready var select_sound: AudioStreamPlayer = get_node_or_null("%SelectSound") 
@onready var save_popup: Panel = get_node_or_null("%SavePopup") # The new wrapper
@onready var blacksmith_portrait: TextureRect = get_node_or_null("%BlacksmithPortrait")
@onready var blacksmith_label: Label = get_node_or_null("%BlacksmithDialogue")
@onready var open_save_menu_btn: Button = get_node_or_null("%OpenSaveMenuButton")
@onready var close_save_btn: Button = get_node_or_null("%CloseSaveButton")
@onready var use_button: Button = $UseButton # Adjust path if it's inside a container
@onready var use_item_sound: AudioStreamPlayer = get_node_or_null("%UseItemSound") # Make sure to add this AudioStreamPlayer in the editor!
@onready var refresh_shop_btn: Button = get_node_or_null("%RefreshShopButton")

# Track which item is currently "highlighted"
var selected_shop_resource: Resource = null

@onready var dragon_ranch_panel: Control = $DragonRanchPanel
@onready var open_ranch_btn: Button = $OpenRanchButton


# --- DRAGON HERDER (MORGRA) REFERENCES ---
@onready var herder_portrait: TextureRect = get_node_or_null("%HerderPortrait")
@onready var herder_label: Label = get_node_or_null("%HerderDialogue")
@onready var herder_blip: AudioStreamPlayer = get_node_or_null("%HerderBlip")
var herder_tween: Tween
var herder_idle_timer: Timer


# --- SKILL TREE REFERENCES ---
@onready var open_skills_btn: Button = get_node_or_null("%OpenSkillsButton")
@onready var skill_tree_panel: Control = get_node_or_null("%SkillTreePanel")
@onready var skill_title_label: Label = get_node_or_null("%SkillTitleLabel")
@onready var skill_points_label: Label = get_node_or_null("%SkillPointsLabel")
@onready var tree_canvas: Control = get_node_or_null("%TreeCanvas")
@onready var close_skills_btn: Button = get_node_or_null("%CloseSkillsButton")

@onready var skill_info_panel: Control = get_node_or_null("%SkillInfoPanel")
@onready var skill_name_label: Label = get_node_or_null("%SkillNameLabel")
@onready var skill_desc_label: RichTextLabel = get_node_or_null("%SkillDescLabel")
@onready var unlock_skill_btn: Button = get_node_or_null("%UnlockSkillButton")

var selected_skill_node: Resource = null

@onready var swap_ability_btn: Button = get_node_or_null("%SwapAbilityButton")

# --- QUANTITY POPUP REFERENCES ---
@onready var quantity_popup: Control = get_node_or_null("%QuantityPopup")
@onready var qty_item_name: Label = get_node_or_null("%ItemNameLabel")
@onready var qty_price_label: Label = get_node_or_null("%PriceLabel")
@onready var qty_slider: HSlider = get_node_or_null("%AmountSlider")
@onready var qty_amount_label: Label = get_node_or_null("%AmountLabel")
@onready var qty_confirm_btn: Button = get_node_or_null("%ConfirmButton")
@onready var qty_cancel_btn: Button = get_node_or_null("%CancelButton")

# --- JUKEBOX REFERENCES ---
@onready var jukebox_btn: Button = get_node_or_null("%JukeboxButton")
@onready var jukebox_panel: Control = get_node_or_null("%JukeboxPanel")
@onready var jukebox_list: ItemList = get_node_or_null("%JukeboxList")
@onready var close_jukebox_btn: Button = get_node_or_null("%CloseJukeboxButton")

# NEW CONTROLS
@onready var jukebox_now_playing: RichTextLabel = get_node_or_null("%JukeboxNowPlaying")
@onready var jukebox_volume_slider: HSlider = get_node_or_null("%JukeboxVolumeSlider")
@onready var jukebox_skip_btn: Button = get_node_or_null("%JukeboxSkipButton")
@onready var jukebox_stop_btn: Button = get_node_or_null("%JukeboxStopButton")

# Playback modes (persisted as string in CampaignManager.jukebox_last_mode).
const JUKEBOX_MODE_DEFAULT: String = "default"
const JUKEBOX_MODE_LOOP_TRACK: String = "loop_track"
const JUKEBOX_MODE_LOOP_PLAYLIST: String = "loop_playlist"
const JUKEBOX_MODE_SHUFFLE_PLAYLIST: String = "shuffle_playlist"

var is_playing_custom_track: bool = false
var current_custom_track: AudioStream = null
var user_music_volume: float = 0.0 # Stores the chosen volume in dB
var jukebox_playback_mode: String = JUKEBOX_MODE_DEFAULT
var jukebox_active_playlist_name: String = ""
var jukebox_active_playlist_tracks: Array[String] = []
var jukebox_playlist_index: int = 0
var jukebox_shuffled_indices: Array[int] = []
var _jukebox_playlist_ui_created: bool = false
var _jukebox_mode_option: OptionButton = null
var _jukebox_playlist_option: OptionButton = null
var _jukebox_add_to_playlist_btn: Button = null
var _jukebox_remove_from_playlist_btn: Button = null
var _jukebox_new_playlist_btn: Button = null
var _jukebox_rename_playlist_btn: Button = null
var _jukebox_delete_playlist_btn: Button = null
var _jukebox_playlist_popup: PopupMenu = null
var _jukebox_playlist_names_ordered: Array[String] = []
var _jukebox_move_up_btn: Button = null
var _jukebox_move_down_btn: Button = null
var _jukebox_favorite_btn: Button = null
var _jukebox_favorites_only_cb: CheckButton = null
var _jukebox_track_sort_option: OptionButton = null
var _jukebox_duplicate_playlist_btn: Button = null
var _jukebox_add_favorites_btn: Button = null
var _jukebox_add_source_btn: Button = null
var _jukebox_meta_row: HBoxContainer = null
var _jukebox_chip_source: Label = null
var _jukebox_chip_mood: Label = null
var _jukebox_chip_length: Label = null
var _jukebox_chip_favorite: Label = null
var _jukebox_up_next_label: RichTextLabel = null
var _jukebox_show_lyrics_btn: Button = null
var _jukebox_status_line: String = ""
var _jukebox_status_serial: int = 0
## Runtime track browser (ItemList text contrast is unreliable with project theme). Same indices as legacy list.
var _jukebox_tracks_scroll: ScrollContainer = null
var _jukebox_tracks_vbox: VBoxContainer = null
var _jukebox_runtime_rows: Array[Button] = []
const JUKEBOX_SORT_UNLOCK: String = "unlock"
const JUKEBOX_SORT_ALPHA: String = "alpha"
const JUKEBOX_DISC_RESOURCE_DIR: String = "res://Resources/Music Discs"
var _jukebox_track_sort_mode: String = JUKEBOX_SORT_UNLOCK
var _jukebox_disc_data_cache: Dictionary = {}

var qty_mode: String = "" # Tracks if we are "buy"ing or "sell"ing
var qty_base_price: int = 0
var qty_max_amount: int = 1

var merchant_tween: Tween
var blacksmith_tween: Tween

# --- NEW BLACKSMITH REFERENCES ---
@onready var blueprint_stock_label: RichTextLabel = get_node_or_null("BlacksmithPanel/BlueprintStockPanel/StockLabel")
@onready var blueprint_stock_panel: Panel = get_node_or_null("BlacksmithPanel/BlueprintStockPanel") as Panel
@onready var blacksmith_panel: Control = $BlacksmithPanel
@onready var material_scroll: ScrollContainer = $BlacksmithPanel/MaterialScroll
@onready var material_grid: GridContainer = $BlacksmithPanel/MaterialScroll/MaterialGrid
@onready var anvil_row: HBoxContainer = get_node_or_null("BlacksmithPanel/Anvil") as HBoxContainer
@onready var blacksmith_talk_button: Button = get_node_or_null("%BlacksmithTalkButton")
@onready var open_blacksmith_btn: Button = get_node_or_null("%OpenBlacksmithButton")
@onready var close_blacksmith_btn: Button = get_node_or_null("%CloseBlacksmithButton")
@export var haldor_normal: Texture2D
@export var haldor_impressed: Texture2D
signal promotion_chosen(chosen_class_res: Resource)
signal name_confirmed(new_name: String)
var last_blacksmith_lore_index: int = -1 # Tracks the last line to prevent repeats

@onready var slot1: Control = $BlacksmithPanel/Anvil/Slot1
@onready var slot2: Control = $BlacksmithPanel/Anvil/Slot2
@onready var slot3: Control = $BlacksmithPanel/Anvil/Slot3
@onready var craft_button: Button = $BlacksmithPanel/CraftButton
@onready var recipe_result_label: RichTextLabel = $BlacksmithPanel/RecipeResultLabel
@onready var result_icon: TextureRect = $BlacksmithPanel/ResultIcon

# --- RECIPE BOOK REFERENCES ---
@onready var recipe_book_btn: Button = get_node_or_null("%RecipeBookButton")
@onready var recipe_book_panel: Panel = get_node_or_null("%RecipeBookPanel")
@onready var recipe_list_text: RichTextLabel = get_node_or_null("%RecipeListText")
@onready var close_book_btn: Button = get_node_or_null("%CloseBookButton")

var _blacksmith_dimmer: ColorRect = null
var _blacksmith_title_lbl: Label = null
var _blacksmith_hdr_materials: Label = null
var _blacksmith_hdr_deployment: Label = null
var _blacksmith_hdr_preview: Label = null
var _blacksmith_anvil_plate: Panel = null
var _blacksmith_anvil_hint_lbl: Label = null
var _blacksmith_anvil_hint_strip: Panel = null
var _blacksmith_workbench_divider: Panel = null
var _blacksmith_socket_labels: Array[Label] = []
var _blacksmith_runesmith_status_lbl: Label = null
var _blacksmith_runesmith_status_tween: Tween = null
var _blacksmith_craft_ready_tween: Tween = null
var _blacksmith_was_craft_ready: bool = false

var last_monologue_text: String = ""

# This array tracks what is currently sitting on the 3 anvil slots
var anvil_items: Array[Resource] = [null, null, null]
var anvil_indices: Array[int] = [-1, -1, -1]
var empty_cursor: ImageTexture

# --- Tracks the valid recipe currently on the anvil ---
var current_recipe: Dictionary = {} 

# Slot Buttons (Now using Unique Names for loose nodes)
@onready var save_slot_1: Button = get_node_or_null("%SaveSlot1")
@onready var save_slot_2: Button = get_node_or_null("%SaveSlot2")
@onready var save_slot_3: Button = get_node_or_null("%SaveSlot3")
@onready var save_button: Button = get_node_or_null("%SaveButton")
@onready var back_button: Button = get_node_or_null("%BackButton")
@onready var inventory_desc: RichTextLabel = $InventoryDescLabel
@onready var roster_scroll: ScrollContainer = $RosterScroll
@onready var roster_grid: GridContainer = $RosterScroll/RosterGrid
var selected_roster_index: int = 0
## Set in `_camp_apply_ui_overhaul` so commander stats/portrait can relayout after roster text changes without a full UI pass.
var _camp_commander_card: Rect2 = Rect2()
@onready var stats_label: RichTextLabel = get_node_or_null("%StatsLabel")
@onready var inspect_unit_btn: Button = get_node_or_null("%InspectUnitButton")
@onready var unit_info_panel: Panel = get_node_or_null("%UnitInfoPanel")
@onready var next_battle_button: Button = $NextBattleButton
@onready var gold_label: Label = $GoldLabel
@onready var portrait_rect: TextureRect = $PortraitRect
@onready var warning_dialog: AcceptDialog = $WarningDialog
@onready var rep_popup: Label = $RepPopupLabel
var idle_timer: Timer
# --- NEW GRID INVENTORY REFERENCES ---
@onready var inv_scroll: ScrollContainer = $InventoryScroll
@onready var unit_grid: GridContainer = $InventoryScroll/InventoryVBox/UnitGrid
@onready var convoy_grid: GridContainer = $InventoryScroll/InventoryVBox/ConvoyGrid
@onready var equip_button: Button = $EquipButton
@onready var unequip_button: Button = $UnequipButton
@onready var category_tabs: Control = $CategoryTabs

var selected_inventory_meta: Dictionary = {}
## After equip/give/store, flash this item's button once grids rebuild.
var _camp_inv_flash_item: Resource = null
var inventory_mapping: Array[Dictionary] = []

# --- NEW SHOP REFERENCES ---
@onready var shop_scroll: ScrollContainer = $ShopScroll
@onready var shop_grid: GridContainer = $ShopScroll/ShopGrid
var selected_shop_meta: Dictionary = {}

@onready var buy_button: Button = $BuyButton
@onready var shop_desc: RichTextLabel = $ShopDescriptionLabel
@onready var sort_button: Button = $SortButton

@onready var merchant_portrait: TextureRect = $MerchantPortrait
@onready var merchant_label: RichTextLabel = $MerchantDialogue

@onready var sell_button: Button = $SellButton
@onready var sell_confirmation: ConfirmationDialog = $SellConfirmation

@onready var buy_confirmation: ConfirmationDialog = $BuyConfirmation
@onready var merchant_blip: AudioStreamPlayer = $MerchantBlip
@onready var talk_sound: AudioStreamPlayer = $TalkSound



# This holds the temporary inventory for the current camp visit
var shop_stock: Array[Resource] = []

var discounted_item: Resource = null

# --- NEW HAGGLE REFERENCES ---
@onready var haggle_button: Button = $HaggleButton
@onready var haggle_confirmation: ConfirmationDialog = $HaggleConfirmation
@onready var haggle_panel: Panel = $HagglePanel
@onready var haggle_target_zone: Control = $HagglePanel/TargetZone
@onready var haggle_player_bar: Control = $HagglePanel/PlayerBar
@onready var haggle_progress: ProgressBar = $HagglePanel/HaggleProgress
@onready var camp_music: AudioStreamPlayer = $CampMusic
@onready var minigame_music: AudioStreamPlayer = $MinigameMusic


@export var minigame_music_tracks: Array[AudioStream] = []
@export var camp_music_tracks: Array[AudioStream] = []

@onready var talk_button: Button = $TalkButton
@onready var talk_panel: Panel = $TalkPanel
@onready var talk_text: Label = $TalkPanel/TalkContentVBox/TalkText
@onready var quest_item_icon: TextureRect = $TalkPanel/TalkContentVBox/QuestItemIcon
@onready var option1: Button = $TalkPanel/VBoxContainer/Option1
@onready var option2: Button = $TalkPanel/VBoxContainer/Option2
@onready var option3: Button = $TalkPanel/VBoxContainer/Option3
@onready var roster_header_button: Button = get_node_or_null("Roster")
@onready var inventory_header_button: Button = get_node_or_null("Button")
@onready var merchant_header_button: Button = get_node_or_null("Button2")
@onready var portrait_panel: Panel = get_node_or_null("PortraitRect2")
@onready var merchant_frame: Sprite2D = get_node_or_null("EmptyFrame")
@onready var background_texture: TextureRect = get_node_or_null("ColorRect")

# World Map / Explore Camp
@onready var world_map_button: Button = get_node_or_null("%WorldMapButton")
@onready var explore_camp_btn: Button = get_node_or_null("%ExploreCampButton")

var _task_log: TaskLog = null
var _task_log_button: Button = null
var _camp_cards_layer: Control = null
var _camp_cards: Dictionary = {}
var _inventory_desc_scroll: ScrollContainer = null
var _shop_desc_scroll: ScrollContainer = null
## Quartermaster item panel layout (set in `_camp_apply_ui_overhaul`; used by `_refit_quartermaster_item_panel`).
var _camp_qm_detail_x: float = 0.0
var _camp_qm_detail_w: float = 0.0
var _camp_qm_desc_y: float = 0.0
var _camp_qm_desc_max_h: float = 300.0
var _camp_qm_desc_min_h: float = 72.0
var _camp_unit_info_dimmer: ColorRect = null
var _merchant_talk_modal: Control = null
var _merchant_talk_dimmer: ColorRect = null
var _merchant_talk_open_close_tween: Tween = null
var _merchant_talk_stagger_tween: Tween = null
var _merchant_talk_header_label: Label = null
var _merchant_abandon_confirm: ConfirmationDialog = null
var _merchant_talk_quest_bar: ProgressBar = null
const MERCHANT_TALK_HEADER_H := 26.0
const MERCHANT_TALK_QUEST_BAR_H := 22.0
var _camp_unit_info_root: VBoxContainer = null
var _camp_unit_info_portrait: TextureRect = null
var _camp_unit_info_name: Label = null
var _camp_unit_info_meta_label: Label = null
var _camp_unit_info_summary_text: RichTextLabel = null
var _camp_unit_info_weapon_badge: Label = null
var _camp_unit_info_weapon_icon: TextureRect = null
var _camp_unit_info_weapon_name: Label = null
var _camp_unit_info_record_text: RichTextLabel = null
var _camp_unit_info_relationships_root: VBoxContainer = null
var _camp_unit_info_close_btn: Button = null
var _camp_unit_info_primary_widgets: Dictionary = {}
var _camp_unit_info_stat_widgets: Dictionary = {}
var _camp_unit_info_growth_widgets: Dictionary = {}
var _camp_unit_info_anim_tween: Tween = null
var _camp_unit_info_left_scroll: ScrollContainer = null
var _camp_unit_info_left_root: VBoxContainer = null
var _camp_unit_info_right_scroll: ScrollContainer = null
var _camp_unit_info_right_root: VBoxContainer = null
var _camp_save_dimmer: ColorRect = null
var _camp_save_root: VBoxContainer = null
var _camp_save_title: Label = null
var _camp_save_subtitle: Label = null
var _camp_save_footer: Label = null
var _camp_save_header_badge: Label = null
var _camp_save_slots_root: VBoxContainer = null
var _camp_jukebox_dimmer: ColorRect = null
var _camp_jukebox_root: VBoxContainer = null
var _camp_jukebox_library_panel: Panel = null
var _camp_jukebox_control_panel: Panel = null
var _camp_jukebox_control_scroll: ScrollContainer = null
var _camp_jukebox_control_root: VBoxContainer = null
var _camp_jukebox_mode_row: HBoxContainer = null
var _camp_jukebox_playlist_row: HBoxContainer = null
var _camp_jukebox_playlist_tools_row: GridContainer = null
var _camp_jukebox_manage_row: GridContainer = null
var _camp_jukebox_filter_row: HBoxContainer = null
var _camp_jukebox_filter_tools_row: GridContainer = null
var _camp_jukebox_transport_row: HBoxContainer = null
var _camp_jukebox_library_badge: Label = null
var _camp_jukebox_deck_badge: Label = null
var _camp_jukebox_volume_label: Label = null
var _camp_jukebox_list_hint: Label = null
var _camp_jukebox_title: Label = null
var _camp_jukebox_subtitle: Label = null
var _camp_jukebox_lyrics_dimmer: ColorRect = null
var _camp_jukebox_lyrics_modal: Panel = null
var _camp_jukebox_lyrics_title: Label = null
var _camp_jukebox_lyrics_track_label: Label = null
var _camp_jukebox_lyrics_body: RichTextLabel = null
var _camp_jukebox_lyrics_close_btn: Button = null

var current_talk_state: String = "idle"

# Haggle Mini-game Variables
var has_haggled_this_visit: bool = false
var haggle_active: bool = false
var player_velocity: float = 0.0
var target_velocity: float = 0.0
var target_timer: float = 0.0
var base_target_height: float = 0.0
var haggle_grace_timer: float = 0.0
var haggle_mid_line_fired: bool = false
var haggle_last_overlap: bool = false
var _haggle_playfield_top: float = 0.0
var _haggle_playfield_h: float = 0.0
var _haggle_playfield_global_rect: Rect2 = Rect2()
var _haggle_walk_away_btn: Button = null
var _haggle_bar_w: float = 76.0
var _haggle_target_neutral_color: Color = Color(0.58, 0.48, 0.22, 0.95)
var _haggle_progress_pulse_tween: Tween = null
const HAGGLE_GRACE_SEC := 0.85
const HAGGLE_TARGET_BASE_H := 72.0
var pending_save_slot: int = 0

func _pick_line(key: String) -> String:
	var arr: Array = DialogueDatabase.talk_lines.get(key, [])
	if arr.is_empty():
		return ""
	return arr[randi() % arr.size()]

func _line(key: String, data: Dictionary) -> String:
	var template := _pick_line(key)
	return template.format(data)

func _plural_suffix(count: int, word: String) -> String:
	if count == 1:
		return ""
	# Avoid obvious double-plural when the name already ends with s
	return "" if word.to_lower().ends_with("s") else "s"

func _setup_task_log_button() -> void:
	if _task_log_button != null:
		return
	_task_log_button = Button.new()
	_task_log_button.text = "Tasks"
	_task_log_button.focus_mode = Control.FOCUS_ALL
	_task_log_button.anchors_preset = Control.PRESET_BOTTOM_WIDE
	_task_log_button.anchor_left = 0.5
	_task_log_button.anchor_right = 0.5
	_task_log_button.anchor_top = 1.0
	_task_log_button.anchor_bottom = 1.0
	_task_log_button.offset_left = -350.0
	_task_log_button.offset_right = -150.0
	_task_log_button.offset_top = -126.0
	_task_log_button.offset_bottom = -49.0
	add_child(_task_log_button)
	_task_log_button.pressed.connect(_on_task_log_pressed)

func _ensure_task_log() -> void:
	if _task_log != null and is_instance_valid(_task_log):
		return
	_task_log = TASK_LOG_SCRIPT.new()
	add_child(_task_log)

func _on_task_log_pressed() -> void:
	_ensure_task_log()
	if _task_log != null:
		_task_log.open_and_refresh()

func _camp_make_panel_style(
	bg: Color = CAMP_PANEL_BG,
	border: Color = CAMP_BORDER,
	radius: int = 24,
	shadow_size: int = 12
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 6)
	return style

func _camp_style_merchant_talk_option(btn: Button, dangerous: bool, font_size: int = 16, min_h: float = 38.0) -> void:
	if btn == null:
		return
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.custom_minimum_size.y = min_h
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", CAMP_TEXT)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", CAMP_TEXT)
	btn.add_theme_color_override("font_focus_color", CAMP_TEXT)
	var fill: Color = CAMP_ACTION_SECONDARY
	var border_n: Color = CAMP_BORDER_SOFT
	var border_h: Color = CAMP_BORDER
	var border_f: Color = Color(0.96, 0.84, 0.42, 1.0)
	if dangerous:
		border_n = Color(0.68, 0.30, 0.26, 1.0)
		border_h = Color(0.88, 0.40, 0.34, 1.0)
		border_f = Color(1.0, 0.52, 0.42, 1.0)
	btn.add_theme_stylebox_override("normal", _camp_make_button_style(fill, border_n))
	btn.add_theme_stylebox_override("hover", _camp_make_button_style(fill.lightened(0.12), border_h))
	btn.add_theme_stylebox_override("pressed", _camp_make_button_style(fill.darkened(0.08), border_h))
	var focus_st := _camp_make_button_style(fill.lightened(0.06), border_f, 18, 8)
	focus_st.border_width_left = 3
	focus_st.border_width_top = 3
	focus_st.border_width_right = 3
	focus_st.border_width_bottom = 3
	btn.add_theme_stylebox_override("focus", focus_st)
	btn.add_theme_stylebox_override(
		"disabled",
		_camp_make_button_style(fill.darkened(0.10), border_n.darkened(0.15), 18, 0)
	)


func _camp_make_button_style(
	fill: Color,
	border: Color,
	radius: int = 18,
	shadow_size: int = 6
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0, 4)
	return style

func _camp_set_rect(control: Control, pos: Vector2, size: Vector2) -> void:
	if control == null:
		return
	control.layout_mode = 0
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = pos.x
	control.offset_top = pos.y
	control.offset_right = pos.x + size.x
	control.offset_bottom = pos.y + size.y


func _camp_inventory_desc_set_text(bbcode: String) -> void:
	if inventory_desc == null:
		return
	inventory_desc.text = bbcode
	_queue_refit_quartermaster_item_panel()


func _queue_refit_quartermaster_item_panel() -> void:
	if not is_inside_tree():
		return
	call_deferred("_refit_quartermaster_item_panel")


func _refit_quartermaster_item_panel() -> void:
	if inventory_desc == null or _inventory_desc_scroll == null:
		return
	if equip_button == null or unequip_button == null or use_button == null or sell_button == null:
		return
	if _camp_qm_detail_w < 48.0:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if inventory_desc == null or not is_instance_valid(inventory_desc):
		return
	var iw: float = _camp_qm_detail_w
	var ix: float = _camp_qm_detail_x
	var iy: float = _camp_qm_desc_y
	inventory_desc.custom_minimum_size = Vector2.ZERO
	var ch: float = inventory_desc.get_content_height()
	# StyleBox content margins are inside the label; height floor includes a little slack for rounding.
	var want_h: float = ch + float(CAMP_QM_DESC_STYLE_MARGIN_V) * 2.0 + 12.0
	var scroll_h: float = clampf(want_h, _camp_qm_desc_min_h, _camp_qm_desc_max_h)
	# Snug fit when everything fits — avoids a pointless scrollbar / dead air.
	if scroll_h >= want_h - 2.0:
		scroll_h = want_h
	_camp_set_rect(_inventory_desc_scroll, Vector2(ix, iy), Vector2(iw, scroll_h))
	var action_gap := 12.0
	var row_step := 54.0
	var btn_h := 44.0
	var action_y1 := iy + scroll_h + action_gap
	var action_y2 := action_y1 + row_step
	var action_button_w := (iw - 12.0) * 0.5
	_camp_set_rect(equip_button, Vector2(ix, action_y1), Vector2(action_button_w, btn_h))
	_camp_set_rect(unequip_button, Vector2(ix + action_button_w + 12.0, action_y1), Vector2(action_button_w, btn_h))
	_camp_set_rect(use_button, Vector2(ix, action_y2), Vector2(action_button_w, btn_h))
	_camp_set_rect(sell_button, Vector2(ix + action_button_w + 12.0, action_y2), Vector2(action_button_w, btn_h))

func _camp_prepare_for_container(control: Control, expand_horizontal: bool = true) -> void:
	if control == null:
		return
	control.layout_mode = 2
	control.position = Vector2.ZERO
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
	if expand_horizontal:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _camp_style_button(button: Button, primary: bool = false, font_size: int = 22, min_height: float = 52.0) -> void:
	if button == null:
		return
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size.y = min_height
	button.add_theme_font_size_override("font_size", font_size)
	var base_font_color := Color(0.12, 0.09, 0.04, 1.0) if primary else CAMP_TEXT
	button.add_theme_color_override("font_color", base_font_color)
	button.add_theme_color_override("font_hover_color", Color(0.08, 0.06, 0.03, 1.0) if primary else Color(1, 1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(0.08, 0.06, 0.03, 1.0) if primary else CAMP_TEXT)
	button.add_theme_color_override("font_focus_color", base_font_color)
	var base_fill := CAMP_ACTION_PRIMARY if primary else CAMP_ACTION_SECONDARY
	var base_border := CAMP_ACCENT_CYAN if primary else CAMP_BORDER_SOFT
	button.add_theme_stylebox_override("normal", _camp_make_button_style(base_fill, base_border))
	button.add_theme_stylebox_override("hover", _camp_make_button_style(base_fill.lightened(0.08) if primary else base_fill.lightened(0.12), CAMP_BORDER))
	button.add_theme_stylebox_override("pressed", _camp_make_button_style(base_fill.darkened(0.08), CAMP_ACCENT_CYAN if primary else CAMP_BORDER))
	button.add_theme_stylebox_override("focus", _camp_make_button_style(base_fill, CAMP_ACCENT_CYAN))
	button.add_theme_stylebox_override("disabled", _camp_make_button_style(base_fill.darkened(0.10), base_border.darkened(0.12), 18, 0))

func _camp_style_section_badge(button: Button, text_value: String, font_color: Color = CAMP_BORDER) -> void:
	if button == null:
		return
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_focus_color", font_color)
	var clear_style := StyleBoxFlat.new()
	clear_style.bg_color = Color(0, 0, 0, 0)
	clear_style.border_width_left = 0
	clear_style.border_width_top = 0
	clear_style.border_width_right = 0
	clear_style.border_width_bottom = 0
	button.add_theme_stylebox_override("normal", clear_style)
	button.add_theme_stylebox_override("hover", clear_style)
	button.add_theme_stylebox_override("pressed", clear_style)
	button.add_theme_stylebox_override("focus", clear_style)
	button.add_theme_stylebox_override("disabled", clear_style)

func _camp_style_rich_label(
	label: Control,
	font_size: int = 18,
	panel_bg: Color = CAMP_PANEL_BG_SOFT,
	border: Color = CAMP_BORDER_SOFT,
	scrollable: bool = false
) -> void:
	if label == null:
		return
	if label is RichTextLabel:
		var rtl: RichTextLabel = label as RichTextLabel
		rtl.fit_content = false
		rtl.scroll_active = scrollable
		rtl.scroll_following = false
		rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rtl.mouse_filter = Control.MOUSE_FILTER_STOP if scrollable else Control.MOUSE_FILTER_IGNORE
		rtl.add_theme_font_size_override("normal_font_size", font_size)
		rtl.add_theme_color_override("default_color", CAMP_TEXT)
		rtl.add_theme_stylebox_override("normal", _camp_make_panel_style(panel_bg, border, 18, 0))
		return
	if label is Label:
		var plain: Label = label as Label
		plain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		plain.add_theme_font_size_override("font_size", font_size)
		plain.add_theme_color_override("font_color", CAMP_TEXT)
		plain.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.01, 0.96))
		plain.add_theme_constant_override("outline_size", 2)
		plain.add_theme_stylebox_override("normal", _camp_make_panel_style(panel_bg, border, 18, 0))

func _camp_style_scroll(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var vbar := scroll.get_v_scroll_bar()
	if vbar != null:
		vbar.custom_minimum_size.x = 10.0
		vbar.add_theme_stylebox_override("scroll", _camp_make_button_style(Color(0.09, 0.07, 0.05, 0.72), Color(0, 0, 0, 0), 8, 0))
		vbar.add_theme_stylebox_override("grabber", _camp_make_button_style(CAMP_BORDER_SOFT, CAMP_BORDER_SOFT, 8, 0))
		vbar.add_theme_stylebox_override("grabber_highlight", _camp_make_button_style(CAMP_BORDER, CAMP_BORDER, 8, 0))
		vbar.add_theme_stylebox_override("grabber_pressed", _camp_make_button_style(CAMP_ACCENT_CYAN, CAMP_ACCENT_CYAN, 8, 0))

func _camp_style_tabs(tab_bar: TabBar) -> void:
	if tab_bar == null:
		return
	tab_bar.clip_tabs = true
	tab_bar.add_theme_font_size_override("font_size", 18)
	tab_bar.add_theme_stylebox_override("tab_selected", _camp_make_button_style(CAMP_ACTION_PRIMARY, CAMP_ACCENT_CYAN, 14, 0))
	tab_bar.add_theme_stylebox_override("tab_hovered", _camp_make_button_style(Color(0.35, 0.27, 0.15, 0.98), CAMP_BORDER, 14, 0))
	tab_bar.add_theme_stylebox_override("tab_unselected", _camp_make_button_style(Color(0.18, 0.13, 0.08, 0.92), CAMP_BORDER_SOFT, 14, 0))
	tab_bar.add_theme_stylebox_override("tab_disabled", _camp_make_button_style(Color(0.12, 0.09, 0.06, 0.82), CAMP_BORDER_SOFT.darkened(0.15), 14, 0))

func _camp_style_panel(panel: Panel, bg: Color = CAMP_PANEL_BG_SOFT, border: Color = CAMP_BORDER_SOFT, radius: int = 18, shadow_size: int = 8) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", _camp_make_panel_style(bg, border, radius, shadow_size))

func _camp_style_label(label: Label, color: Color = CAMP_TEXT, font_size: int = 18, outline_size: int = 2) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.01, 0.96))
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_font_size_override("font_size", font_size)

func _camp_style_option_button(option: OptionButton, font_size: int = 16, min_height: float = 40.0) -> void:
	if option == null:
		return
	option.focus_mode = Control.FOCUS_ALL
	option.mouse_filter = Control.MOUSE_FILTER_STOP
	option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	option.custom_minimum_size.y = min_height
	option.add_theme_font_size_override("font_size", font_size)
	option.add_theme_color_override("font_color", CAMP_TEXT)
	option.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	option.add_theme_color_override("font_pressed_color", CAMP_TEXT)
	option.add_theme_color_override("font_focus_color", CAMP_TEXT)
	var normal_style := _camp_make_button_style(Color(0.20, 0.15, 0.09, 0.96), CAMP_BORDER_SOFT, 14, 4)
	var hover_style := _camp_make_button_style(Color(0.24, 0.18, 0.10, 0.98), CAMP_BORDER, 14, 4)
	var pressed_style := _camp_make_button_style(Color(0.16, 0.12, 0.08, 0.98), CAMP_ACCENT_CYAN, 14, 4)
	option.add_theme_stylebox_override("normal", normal_style)
	option.add_theme_stylebox_override("hover", hover_style)
	option.add_theme_stylebox_override("pressed", pressed_style)
	option.add_theme_stylebox_override("focus", pressed_style)
	option.add_theme_stylebox_override("disabled", normal_style)

func _camp_style_check_button(check: BaseButton, font_size: int = 16) -> void:
	if check == null:
		return
	check.focus_mode = Control.FOCUS_ALL
	check.mouse_filter = Control.MOUSE_FILTER_STOP
	check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	check.add_theme_font_size_override("font_size", font_size)
	check.add_theme_color_override("font_color", CAMP_TEXT)
	check.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	check.add_theme_color_override("font_pressed_color", CAMP_TEXT)
	check.add_theme_color_override("font_focus_color", CAMP_TEXT)

func _camp_style_slider(slider: Range) -> void:
	if slider == null:
		return
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	var groove := _camp_make_button_style(Color(0.08, 0.06, 0.04, 0.94), Color(0, 0, 0, 0), 8, 0)
	var grabber := _camp_make_button_style(CAMP_BORDER, CAMP_BORDER, 10, 2)
	var grabber_highlight := _camp_make_button_style(CAMP_ACCENT_CYAN, CAMP_ACCENT_CYAN, 10, 2)
	if slider is Slider:
		var s := slider as Slider
		s.add_theme_stylebox_override("slider", groove)
		s.add_theme_stylebox_override("grabber_area", groove)
		s.add_theme_stylebox_override("grabber_area_highlight", _camp_make_button_style(Color(0.15, 0.12, 0.08, 0.98), CAMP_BORDER_SOFT, 8, 0))
		s.add_theme_stylebox_override("grabber", grabber)
		s.add_theme_stylebox_override("grabber_highlight", grabber_highlight)

func _camp_style_item_list(list: ItemList) -> void:
	if list == null:
		return
	list.mouse_filter = Control.MOUSE_FILTER_STOP
	list.focus_mode = Control.FOCUS_ALL
	list.select_mode = ItemList.SELECT_MULTI
	list.add_theme_font_size_override("font_size", 18)
	list.add_theme_color_override("font_color", CAMP_TEXT)
	list.add_theme_color_override("font_selected_color", CAMP_TEXT)
	list.add_theme_color_override("font_hovered_color", Color(1, 1, 1, 1))
	list.add_theme_color_override("font_hovered_selected_color", Color(1, 1, 1, 1))
	list.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.92))
	list.add_theme_constant_override("outline_size", 2)
	list.add_theme_color_override("guide_color", CAMP_BORDER_SOFT)
	var panel_style := _camp_make_panel_style(Color(0.08, 0.06, 0.04, 0.94), CAMP_BORDER_SOFT, 16, 0)
	panel_style.content_margin_left = 10.0
	panel_style.content_margin_top = 20.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_bottom = 8.0
	list.add_theme_stylebox_override("panel", panel_style)
	list.add_theme_stylebox_override("cursor", _camp_make_button_style(Color(0.13, 0.10, 0.07, 0.98), CAMP_ACCENT_CYAN, 12, 0))
	list.add_theme_stylebox_override("cursor_unfocused", _camp_make_button_style(Color(0.10, 0.08, 0.06, 0.96), CAMP_BORDER, 12, 0))
	list.add_theme_stylebox_override("selected", _camp_make_button_style(Color(0.12, 0.09, 0.06, 0.98), CAMP_BORDER, 12, 0))
	list.add_theme_stylebox_override("selected_focus", _camp_make_button_style(Color(0.14, 0.10, 0.07, 0.98), CAMP_ACCENT_CYAN, 12, 0))

func _jukebox_make_meta_chip(text_value: String, accent: Color = CAMP_ACCENT_CYAN) -> Label:
	var chip := Label.new()
	chip.text = text_value
	chip.clip_text = true
	chip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.custom_minimum_size = Vector2(0.0, 28.0)
	chip.add_theme_stylebox_override("normal", _camp_make_button_style(Color(0.13, 0.10, 0.07, 0.95), accent.lerp(CAMP_BORDER_SOFT, 0.35), 10, 2))
	_camp_style_label(chip, CAMP_MUTED, 13, 1)
	return chip

func _jukebox_make_section_shell(title_text: String, accent: Color = CAMP_BORDER) -> Dictionary:
	var panel := Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_camp_style_panel(panel, Color(0.11, 0.09, 0.06, 0.94), accent.lerp(CAMP_BORDER_SOFT, 0.35), 14, 5)

	var root := VBoxContainer.new()
	root.name = "SectionRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("margin_left", 12)
	root.add_theme_constant_override("margin_top", 12)
	root.add_theme_constant_override("margin_right", 12)
	root.add_theme_constant_override("margin_bottom", 12)
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	var title := Label.new()
	title.name = "SectionTitle"
	_camp_style_label(title, accent, 18, 2)
	title.text = title_text
	root.add_child(title)

	var divider := Panel.new()
	divider.custom_minimum_size = Vector2(0.0, 2.0)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.add_theme_stylebox_override("panel", _camp_make_panel_style(accent.lerp(Color(1, 1, 1, 1), 0.18), Color(0, 0, 0, 0), 3, 0))
	root.add_child(divider)

	var body := VBoxContainer.new()
	body.name = "SectionBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_theme_constant_override("separation", 8)
	root.add_child(body)

	return {
		"panel": panel,
		"root": root,
		"title": title,
		"body": body,
	}

func _refresh_camp_jukebox_section_heights() -> void:
	if _camp_jukebox_control_root == null:
		return
	var min_by_section := {
		"OverviewSection": 260.0,
		"PlaylistSection": 286.0,
		"FilterSection": 196.0,
		"TransportSection": 176.0,
	}
	for section_name in min_by_section.keys():
		var panel := _camp_jukebox_control_root.get_node_or_null(section_name) as Panel
		if panel == null:
			continue
		var body := panel.get_node_or_null("SectionRoot/SectionBody") as VBoxContainer
		var fallback_min := float(min_by_section[section_name])
		if body == null:
			panel.custom_minimum_size.y = fallback_min
			continue
		panel.custom_minimum_size.y = maxf(fallback_min, body.get_combined_minimum_size().y + 52.0)

func _jukebox_infer_source(display_name: String, path: String) -> String:
	var upper_name := display_name.to_upper()
	if upper_name.find("THEME") != -1:
		return "Theme"
	if upper_name.find("OVERWORLD") != -1:
		return "Overworld"
	if upper_name.find("CREDITS") != -1:
		return "Credits"
	if upper_name.find("VILLAGE") != -1:
		return "Village"
	if upper_name.find("BOSS") != -1 or upper_name.find("VILLAIN") != -1:
		return "Boss"
	if path.find("/Music Discs/") != -1:
		return "Music Disc"
	return "Archive"

func _jukebox_collect_disc_resource_paths(root_path: String, out_paths: Array[String]) -> void:
	var dir := DirAccess.open(root_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var full_path := root_path.path_join(name)
		if dir.current_is_dir():
			_jukebox_collect_disc_resource_paths(full_path, out_paths)
		else:
			var extension := full_path.get_extension().to_lower()
			if extension == "tres" or extension == "res":
				out_paths.append(full_path)
	dir.list_dir_end()

func _jukebox_find_disc_data_for_track_path(track_path: String) -> ConsumableData:
	var clean_path := track_path.strip_edges()
	if clean_path.is_empty():
		return null
	var cached_variant: Variant = _jukebox_disc_data_cache.get(clean_path)
	if cached_variant is ConsumableData:
		return cached_variant as ConsumableData
	var disc_paths: Array[String] = []
	_jukebox_collect_disc_resource_paths(JUKEBOX_DISC_RESOURCE_DIR, disc_paths)
	for disc_path in disc_paths:
		var disc_data := load(disc_path) as ConsumableData
		if disc_data == null or disc_data.unlocked_music_track == null:
			continue
		if disc_data.unlocked_music_track.resource_path == clean_path:
			_jukebox_disc_data_cache[clean_path] = disc_data
			return disc_data
	return null

func _jukebox_current_track_path() -> String:
	if not jukebox_active_playlist_name.is_empty() and jukebox_active_playlist_tracks.size() > 0:
		var idx: int = jukebox_playlist_index
		if jukebox_playback_mode == JUKEBOX_MODE_SHUFFLE_PLAYLIST and idx < jukebox_shuffled_indices.size():
			idx = jukebox_shuffled_indices[idx]
		if idx >= 0 and idx < jukebox_active_playlist_tracks.size():
			return str(jukebox_active_playlist_tracks[idx])
	if is_playing_custom_track and CampaignManager.jukebox_last_track_path != "":
		return CampaignManager.jukebox_last_track_path
	return ""

func _jukebox_current_track_name() -> String:
	var track_path := _jukebox_current_track_path()
	if track_path.is_empty():
		return "Camp Ambiance"
	return _get_display_name_for_path(track_path)

func _jukebox_refresh_lyrics_button() -> void:
	if _jukebox_show_lyrics_btn == null:
		return
	var track_path := _jukebox_current_track_path()
	_jukebox_show_lyrics_btn.disabled = track_path.is_empty()
	_jukebox_show_lyrics_btn.text = "Show Lyrics" if not track_path.is_empty() else "No Lyrics"

func _jukebox_infer_mood(display_name: String) -> String:
	var upper_name := display_name.to_upper()
	if upper_name.find("EPIC") != -1 or upper_name.find("BOSS") != -1:
		return "Intense"
	if upper_name.find("HERO") != -1:
		return "Resolute"
	if upper_name.find("VILLAIN") != -1 or upper_name.find("CRAZY") != -1:
		return "Uneasy"
	if upper_name.find("VILLAGE") != -1:
		return "Calm"
	if upper_name.find("OVERWORLD") != -1:
		return "Travel"
	return "Atmospheric"

func _jukebox_estimated_length_label(display_name: String) -> String:
	var seed := maxi(0, display_name.length())
	var minutes := 2 + int(seed % 3)
	var seconds := 18 + int((seed * 13) % 40)
	return "%d:%02d" % [minutes, seconds]

func _jukebox_selected_track_paths() -> Array[String]:
	var paths: Array[String] = []
	for i in range(_jukebox_runtime_rows.size()):
		var b: Button = _jukebox_runtime_rows[i]
		if not b.toggle_mode or not b.button_pressed:
			continue
		var meta_str := str(b.get_meta("jb_meta", ""))
		if meta_str == "DEFAULT" or meta_str.begins_with("PLAYLIST|"):
			continue
		if not ResourceLoader.exists(meta_str):
			continue
		if meta_str not in paths:
			paths.append(meta_str)
	return paths

func _jukebox_set_status(msg: String, seconds: float = 2.2) -> void:
	_jukebox_status_line = msg
	_jukebox_status_serial += 1
	var serial := _jukebox_status_serial
	_update_now_playing_ui()
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout
	if serial != _jukebox_status_serial:
		return
	_jukebox_status_line = ""
	_update_now_playing_ui()

func _jukebox_ensure_control_deck_scroll_margins() -> void:
	if _camp_jukebox_control_scroll == null or _camp_jukebox_control_root == null:
		return
	if _camp_jukebox_control_scroll.get_child_count() != 1:
		return
	var only: Control = _camp_jukebox_control_scroll.get_child(0) as Control
	if only != _camp_jukebox_control_root:
		return
	var deck_inner := MarginContainer.new()
	deck_inner.name = "ControlDeckInnerMargins"
	deck_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_inner.add_theme_constant_override("margin_left", 2)
	deck_inner.add_theme_constant_override("margin_right", 28)
	deck_inner.add_theme_constant_override("margin_bottom", 28)
	_camp_jukebox_control_scroll.remove_child(_camp_jukebox_control_root)
	_camp_jukebox_control_scroll.add_child(deck_inner)
	deck_inner.add_child(_camp_jukebox_control_root)

func _jukebox_migrate_library_to_runtime_list() -> void:
	if _camp_jukebox_library_panel == null:
		return
	var library_root := _camp_jukebox_library_panel.get_node_or_null("LibraryRoot") as VBoxContainer
	if library_root == null:
		return
	if _jukebox_tracks_scroll != null and is_instance_valid(_jukebox_tracks_scroll) and _jukebox_tracks_scroll.get_parent() == library_root:
		return
	if jukebox_list != null and jukebox_list.get_parent() == library_root:
		library_root.remove_child(jukebox_list)
		jukebox_panel.add_child(jukebox_list)
		jukebox_list.visible = false
		jukebox_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
		jukebox_list.custom_minimum_size = Vector2.ZERO
	_jukebox_tracks_scroll = ScrollContainer.new()
	_jukebox_tracks_scroll.name = "JukeboxTracksScroll"
	_jukebox_tracks_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_jukebox_tracks_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jukebox_tracks_scroll.clip_contents = true
	_jukebox_tracks_vbox = VBoxContainer.new()
	_jukebox_tracks_vbox.name = "JukeboxTracksVBox"
	_jukebox_tracks_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jukebox_tracks_vbox.add_theme_constant_override("separation", 6)
	_jukebox_tracks_scroll.add_child(_jukebox_tracks_vbox)
	library_root.add_child(_jukebox_tracks_scroll)
	var hint_node := library_root.get_node_or_null("ListHint")
	if hint_node != null:
		library_root.move_child(_jukebox_tracks_scroll, hint_node.get_index())
	else:
		library_root.move_child(_jukebox_tracks_scroll, mini(1, library_root.get_child_count() - 1))
	_camp_style_scroll(_jukebox_tracks_scroll)

func _jukebox_is_track_meta(meta: String) -> bool:
	return meta != "DEFAULT" and not meta.begins_with("PLAYLIST|")

func _jukebox_library_row_stylebox(fill: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var s := _camp_make_button_style(fill, border, radius, 0)
	s.shadow_size = 0
	s.shadow_offset = Vector2.ZERO
	s.content_margin_left = 14.0
	s.content_margin_right = 12.0
	s.content_margin_top = 10.0
	s.content_margin_bottom = 10.0
	return s

func _jukebox_apply_runtime_row_theme(btn: Button, meta: String) -> void:
	btn.theme_type_variation = &""
	var fill := Color(0.22, 0.17, 0.11, 1.0)
	var border := CAMP_BORDER
	var hover := Color(0.30, 0.24, 0.15, 1.0)
	var accent := CAMP_ACCENT_CYAN
	var fg := Color(1.0, 0.97, 0.88, 1.0)
	if meta == "DEFAULT":
		fill = Color(0.12, 0.14, 0.09, 0.98)
		border = CAMP_ACCENT_GREEN
		hover = Color(0.15, 0.18, 0.11, 0.98)
		accent = CAMP_ACCENT_GREEN
		fg = Color(0.78, 1.0, 0.88, 1.0)
	elif meta.begins_with("PLAYLIST|"):
		fill = Color(0.10, 0.12, 0.15, 0.98)
		border = CAMP_ACCENT_CYAN
		hover = Color(0.14, 0.17, 0.21, 0.98)
		fg = Color(0.82, 0.95, 1.0, 1.0)
	elif _jukebox_is_track_meta(meta) and meta in CampaignManager.favorite_music_paths:
		border = Color(0.96, 0.81, 0.34, 1.0)
		hover = Color(0.33, 0.24, 0.11, 0.98)
		accent = Color(1.0, 0.85, 0.34, 1.0)
	var pressed_fill := hover.lerp(accent, 0.18)
	var outline := Color(0.0, 0.0, 0.0, 0.97)
	btn.add_theme_font_size_override("font_size", 19)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_hover_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_disabled_color", CAMP_MUTED)
	btn.add_theme_color_override("font_focus_color", fg)
	btn.add_theme_color_override("font_outline_color", outline)
	btn.add_theme_constant_override("outline_size", 3)
	var normal_sb := _jukebox_library_row_stylebox(fill, border)
	var hover_sb := _jukebox_library_row_stylebox(hover, CAMP_BORDER)
	var pressed_sb := _jukebox_library_row_stylebox(pressed_fill, accent)
	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_stylebox_override("focus", hover_sb)
	btn.add_theme_stylebox_override("disabled", normal_sb)

func _jukebox_clear_runtime_rows() -> void:
	_jukebox_runtime_rows.clear()
	if _jukebox_tracks_vbox == null:
		return
	while _jukebox_tracks_vbox.get_child_count() > 0:
		var c: Node = _jukebox_tracks_vbox.get_child(0)
		_jukebox_tracks_vbox.remove_child(c)
		c.free()

func _jukebox_runtime_row_count() -> int:
	return _jukebox_runtime_rows.size()

func _jukebox_rebuild_runtime_rows(entries: Array[Dictionary]) -> void:
	_jukebox_clear_runtime_rows()
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var label_text: String = str(entry.get("text", ""))
		var meta: String = str(entry.get("meta", ""))
		var btn := Button.new()
		btn.text = label_text
		btn.toggle_mode = _jukebox_is_track_meta(meta)
		btn.focus_mode = Control.FOCUS_ALL
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.custom_minimum_size.y = 54.0
		_jukebox_apply_runtime_row_theme(btn, meta)
		btn.set_meta("jb_meta", meta)
		btn.set_meta("jb_idx", i)
		if btn.toggle_mode:
			btn.toggled.connect(_on_jukebox_runtime_track_row_toggled.bind(i))
		else:
			btn.pressed.connect(_on_jukebox_runtime_special_row_pressed.bind(i))
		_jukebox_tracks_vbox.add_child(btn)
		_jukebox_runtime_rows.append(btn)

func _on_jukebox_runtime_special_row_pressed(list_index: int) -> void:
	for j in range(_jukebox_runtime_rows.size()):
		var other: Button = _jukebox_runtime_rows[j]
		if other.toggle_mode:
			other.set_pressed_no_signal(false)
	_on_jukebox_track_selected(list_index)

func _on_jukebox_runtime_track_row_toggled(pressed: bool, list_index: int) -> void:
	if pressed:
		_on_jukebox_track_selected(list_index)

func _jukebox_get_selected_row_indices() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i in range(_jukebox_runtime_rows.size()):
		var b: Button = _jukebox_runtime_rows[i]
		if b.button_pressed:
			out.append(i)
	return out

func _jukebox_first_selected_track_meta() -> String:
	for b in _jukebox_runtime_rows:
		if not b.toggle_mode or not b.button_pressed:
			continue
		var m: String = str(b.get_meta("jb_meta", ""))
		if _jukebox_is_track_meta(m):
			return m
	return ""

func _close_jukebox() -> void:
	_close_jukebox_lyrics()
	if _camp_jukebox_dimmer != null:
		_camp_jukebox_dimmer.visible = false
	if jukebox_panel != null:
		jukebox_panel.visible = false

func _ensure_camp_jukebox_modal() -> void:
	if jukebox_panel == null:
		return
	if _camp_jukebox_dimmer == null or not is_instance_valid(_camp_jukebox_dimmer):
		_camp_jukebox_dimmer = ColorRect.new()
		_camp_jukebox_dimmer.name = "CampJukeboxDimmer"
		_camp_jukebox_dimmer.color = Color(0, 0, 0, 0.74)
		_camp_jukebox_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_camp_jukebox_dimmer.visible = false
		_camp_jukebox_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_camp_jukebox_dimmer)
		move_child(_camp_jukebox_dimmer, max(0, jukebox_panel.get_index()))

	jukebox_panel.visible = false
	jukebox_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	jukebox_panel.z_index = 44
	_camp_style_panel(jukebox_panel, CAMP_PANEL_BG_ALT, CAMP_BORDER, 22, 12)

	var old_title := jukebox_panel.get_node_or_null("Label") as Label
	if old_title != null:
		old_title.visible = false

	if _camp_jukebox_root == null or not is_instance_valid(_camp_jukebox_root):
		_camp_jukebox_root = VBoxContainer.new()
		_camp_jukebox_root.name = "CampJukeboxRoot"
		_camp_jukebox_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
		_camp_jukebox_root.add_theme_constant_override("separation", 14)
		jukebox_panel.add_child(_camp_jukebox_root)

		var header_row := HBoxContainer.new()
		header_row.name = "JukeboxHeaderRow"
		header_row.add_theme_constant_override("separation", 16)
		_camp_jukebox_root.add_child(header_row)

		var header_left := VBoxContainer.new()
		header_left.name = "HeaderLeft"
		header_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_left.add_theme_constant_override("separation", 4)
		header_row.add_child(header_left)

		var badge := Label.new()
		badge.name = "HeaderBadge"
		header_left.add_child(badge)
		_camp_jukebox_title = Label.new()
		_camp_jukebox_title.name = "HeaderTitle"
		header_left.add_child(_camp_jukebox_title)
		_camp_jukebox_subtitle = Label.new()
		_camp_jukebox_subtitle.name = "HeaderSubtitle"
		_camp_jukebox_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		header_left.add_child(_camp_jukebox_subtitle)

		if close_jukebox_btn != null and close_jukebox_btn.get_parent() != header_row:
			if close_jukebox_btn.get_parent() != null:
				close_jukebox_btn.get_parent().remove_child(close_jukebox_btn)
			_camp_prepare_for_container(close_jukebox_btn, false)
			header_row.add_child(close_jukebox_btn)

		var divider := Panel.new()
		divider.name = "JukeboxDivider"
		divider.custom_minimum_size = Vector2(0.0, 3.0)
		divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		divider.add_theme_stylebox_override("panel", _camp_make_panel_style(Color(0.62, 0.48, 0.18, 0.92), Color(0, 0, 0, 0), 4, 0))
		_camp_jukebox_root.add_child(divider)

		var body := HBoxContainer.new()
		body.name = "JukeboxBody"
		body.add_theme_constant_override("separation", 16)
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_camp_jukebox_root.add_child(body)

		_camp_jukebox_library_panel = Panel.new()
		_camp_jukebox_library_panel.name = "LibraryPanel"
		_camp_jukebox_library_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_camp_jukebox_library_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_camp_jukebox_library_panel.size_flags_stretch_ratio = 1.08
		_camp_style_panel(_camp_jukebox_library_panel, Color(0.09, 0.07, 0.05, 0.92), CAMP_BORDER_SOFT, 16, 6)
		body.add_child(_camp_jukebox_library_panel)

		_camp_jukebox_control_panel = Panel.new()
		_camp_jukebox_control_panel.name = "ControlPanel"
		_camp_jukebox_control_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_camp_jukebox_control_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_camp_jukebox_control_panel.size_flags_stretch_ratio = 0.92
		_camp_jukebox_control_panel.clip_contents = true
		_camp_style_panel(_camp_jukebox_control_panel, Color(0.09, 0.07, 0.05, 0.92), CAMP_BORDER_SOFT, 16, 6)
		body.add_child(_camp_jukebox_control_panel)

		var library_root := VBoxContainer.new()
		library_root.name = "LibraryRoot"
		library_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
		library_root.add_theme_constant_override("separation", 10)
		_camp_jukebox_library_panel.add_child(library_root)

		_camp_jukebox_library_badge = Label.new()
		_camp_jukebox_library_badge.name = "LibraryBadge"
		library_root.add_child(_camp_jukebox_library_badge)

		if jukebox_list != null:
			if jukebox_list.get_parent() != null:
				jukebox_list.get_parent().remove_child(jukebox_list)
			jukebox_panel.add_child(jukebox_list)
			jukebox_list.visible = false
			jukebox_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
			jukebox_list.custom_minimum_size = Vector2.ZERO

		_camp_jukebox_list_hint = Label.new()
		_camp_jukebox_list_hint.name = "ListHint"
		_camp_jukebox_list_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		library_root.add_child(_camp_jukebox_list_hint)

		_camp_jukebox_control_scroll = ScrollContainer.new()
		_camp_jukebox_control_scroll.name = "ControlScroll"
		_camp_jukebox_control_scroll.clip_contents = true
		_camp_jukebox_control_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
		_camp_jukebox_control_panel.add_child(_camp_jukebox_control_scroll)

		var deck_inner := MarginContainer.new()
		deck_inner.name = "ControlDeckInnerMargins"
		deck_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		deck_inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
		deck_inner.add_theme_constant_override("margin_left", 2)
		deck_inner.add_theme_constant_override("margin_right", 28)
		deck_inner.add_theme_constant_override("margin_bottom", 28)
		_camp_jukebox_control_scroll.add_child(deck_inner)

		_camp_jukebox_control_root = VBoxContainer.new()
		_camp_jukebox_control_root.name = "ControlRoot"
		_camp_jukebox_control_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_camp_jukebox_control_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_camp_jukebox_control_root.add_theme_constant_override("separation", 12)
		deck_inner.add_child(_camp_jukebox_control_root)

		_camp_jukebox_deck_badge = Label.new()
		_camp_jukebox_deck_badge.name = "DeckBadge"
		_camp_jukebox_control_root.add_child(_camp_jukebox_deck_badge)

		var overview_section: Dictionary = _jukebox_make_section_shell("NOW PLAYING", CAMP_ACCENT_CYAN)
		var overview_panel := overview_section["panel"] as Panel
		overview_panel.name = "OverviewSection"
		var overview_body := overview_section["body"] as VBoxContainer
		_camp_jukebox_control_root.add_child(overview_panel)

		if jukebox_now_playing != null and jukebox_now_playing.get_parent() != overview_body:
			if jukebox_now_playing.get_parent() != null:
				jukebox_now_playing.get_parent().remove_child(jukebox_now_playing)
			_camp_prepare_for_container(jukebox_now_playing, true)
			overview_body.add_child(jukebox_now_playing)
		if _jukebox_meta_row == null or not is_instance_valid(_jukebox_meta_row):
			_jukebox_meta_row = HBoxContainer.new()
			_jukebox_meta_row.name = "MetaRow"
			_jukebox_meta_row.add_theme_constant_override("separation", 8)
			_jukebox_chip_source = _jukebox_make_meta_chip("SOURCE")
			_jukebox_chip_mood = _jukebox_make_meta_chip("MOOD")
			_jukebox_chip_length = _jukebox_make_meta_chip("LENGTH")
			_jukebox_chip_favorite = _jukebox_make_meta_chip("FAVORITE")
			_jukebox_meta_row.add_child(_jukebox_chip_source)
			_jukebox_meta_row.add_child(_jukebox_chip_mood)
			_jukebox_meta_row.add_child(_jukebox_chip_length)
			_jukebox_meta_row.add_child(_jukebox_chip_favorite)
		if _jukebox_meta_row.get_parent() != overview_body:
			if _jukebox_meta_row.get_parent() != null:
				_jukebox_meta_row.get_parent().remove_child(_jukebox_meta_row)
			_camp_prepare_for_container(_jukebox_meta_row, true)
			overview_body.add_child(_jukebox_meta_row)
		_jukebox_show_lyrics_btn = Button.new()
		_jukebox_show_lyrics_btn.name = "ShowLyricsButton"
		_jukebox_show_lyrics_btn.text = "Show Lyrics"
		_jukebox_show_lyrics_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_jukebox_show_lyrics_btn.pressed.connect(_on_jukebox_show_lyrics_pressed)
		_camp_style_button(_jukebox_show_lyrics_btn, false, 15, 38.0)
		overview_body.add_child(_jukebox_show_lyrics_btn)
		if _jukebox_up_next_label == null or not is_instance_valid(_jukebox_up_next_label):
			_jukebox_up_next_label = RichTextLabel.new()
			_jukebox_up_next_label.name = "UpNextLabel"
			_jukebox_up_next_label.bbcode_enabled = true
			_jukebox_up_next_label.scroll_active = false
			_jukebox_up_next_label.fit_content = true
			_jukebox_up_next_label.custom_minimum_size = Vector2(0.0, 92.0)
			_camp_style_rich_label(_jukebox_up_next_label, 14, Color(0.09, 0.07, 0.05, 0.94), CAMP_BORDER_SOFT)
		if _jukebox_up_next_label.get_parent() != overview_body:
			if _jukebox_up_next_label.get_parent() != null:
				_jukebox_up_next_label.get_parent().remove_child(_jukebox_up_next_label)
			_camp_prepare_for_container(_jukebox_up_next_label, true)
			overview_body.add_child(_jukebox_up_next_label)

		var playlist_section: Dictionary = _jukebox_make_section_shell("PLAYLIST COMMAND", CAMP_BORDER)
		var playlist_panel := playlist_section["panel"] as Panel
		playlist_panel.name = "PlaylistSection"
		var playlist_body := playlist_section["body"] as VBoxContainer
		_camp_jukebox_control_root.add_child(playlist_panel)

		_camp_jukebox_mode_row = HBoxContainer.new()
		_camp_jukebox_mode_row.name = "ModeRow"
		_camp_jukebox_mode_row.add_theme_constant_override("separation", 10)
		playlist_body.add_child(_camp_jukebox_mode_row)

		_camp_jukebox_playlist_row = HBoxContainer.new()
		_camp_jukebox_playlist_row.name = "PlaylistRow"
		_camp_jukebox_playlist_row.add_theme_constant_override("separation", 10)
		playlist_body.add_child(_camp_jukebox_playlist_row)
		_camp_jukebox_playlist_tools_row = GridContainer.new()
		_camp_jukebox_playlist_tools_row.name = "PlaylistToolsRow"
		_camp_jukebox_playlist_tools_row.columns = 2
		_camp_jukebox_playlist_tools_row.add_theme_constant_override("h_separation", 8)
		_camp_jukebox_playlist_tools_row.add_theme_constant_override("v_separation", 8)
		playlist_body.add_child(_camp_jukebox_playlist_tools_row)

		_camp_jukebox_manage_row = GridContainer.new()
		_camp_jukebox_manage_row.name = "ManageRow"
		_camp_jukebox_manage_row.columns = 2
		_camp_jukebox_manage_row.add_theme_constant_override("h_separation", 10)
		_camp_jukebox_manage_row.add_theme_constant_override("v_separation", 10)
		playlist_body.add_child(_camp_jukebox_manage_row)

		var filter_section: Dictionary = _jukebox_make_section_shell("CURATION TOOLS", CAMP_ACCENT_GREEN)
		var filter_panel := filter_section["panel"] as Panel
		filter_panel.name = "FilterSection"
		var filter_body := filter_section["body"] as VBoxContainer
		_camp_jukebox_control_root.add_child(filter_panel)

		_camp_jukebox_filter_row = HBoxContainer.new()
		_camp_jukebox_filter_row.name = "FilterRow"
		_camp_jukebox_filter_row.add_theme_constant_override("separation", 10)
		filter_body.add_child(_camp_jukebox_filter_row)
		_camp_jukebox_filter_tools_row = GridContainer.new()
		_camp_jukebox_filter_tools_row.name = "FilterToolsRow"
		_camp_jukebox_filter_tools_row.columns = 2
		_camp_jukebox_filter_tools_row.add_theme_constant_override("h_separation", 8)
		_camp_jukebox_filter_tools_row.add_theme_constant_override("v_separation", 8)
		_camp_jukebox_filter_tools_row.add_theme_constant_override("separation", 10)
		filter_body.add_child(_camp_jukebox_filter_tools_row)

		var transport_section: Dictionary = _jukebox_make_section_shell("TRANSPORT & VOLUME", CAMP_BORDER)
		var transport_panel := transport_section["panel"] as Panel
		transport_panel.name = "TransportSection"
		var transport_body := transport_section["body"] as VBoxContainer
		_camp_jukebox_control_root.add_child(transport_panel)

		_camp_jukebox_volume_label = Label.new()
		_camp_jukebox_volume_label.name = "VolumeLabel"
		transport_body.add_child(_camp_jukebox_volume_label)

		if jukebox_volume_slider != null and jukebox_volume_slider.get_parent() != transport_body:
			if jukebox_volume_slider.get_parent() != null:
				jukebox_volume_slider.get_parent().remove_child(jukebox_volume_slider)
			_camp_prepare_for_container(jukebox_volume_slider, true)
			transport_body.add_child(jukebox_volume_slider)

		_camp_jukebox_transport_row = HBoxContainer.new()
		_camp_jukebox_transport_row.name = "TransportRow"
		_camp_jukebox_transport_row.add_theme_constant_override("separation", 10)
		transport_body.add_child(_camp_jukebox_transport_row)

		if jukebox_skip_btn != null and jukebox_skip_btn.get_parent() != _camp_jukebox_transport_row:
			if jukebox_skip_btn.get_parent() != null:
				jukebox_skip_btn.get_parent().remove_child(jukebox_skip_btn)
			_camp_prepare_for_container(jukebox_skip_btn, true)
			_camp_jukebox_transport_row.add_child(jukebox_skip_btn)
		if jukebox_stop_btn != null and jukebox_stop_btn.get_parent() != _camp_jukebox_transport_row:
			if jukebox_stop_btn.get_parent() != null:
				jukebox_stop_btn.get_parent().remove_child(jukebox_stop_btn)
			_camp_prepare_for_container(jukebox_stop_btn, true)
			_camp_jukebox_transport_row.add_child(jukebox_stop_btn)

		# Prevent section collapse in the scroll deck: each section keeps enough
		# vertical space to contain its controls cleanly.
		if overview_panel != null:
			overview_panel.custom_minimum_size.y = maxf(260.0, overview_body.get_combined_minimum_size().y + 52.0)
		if playlist_panel != null:
			playlist_panel.custom_minimum_size.y = maxf(286.0, playlist_body.get_combined_minimum_size().y + 52.0)
		if filter_panel != null:
			filter_panel.custom_minimum_size.y = maxf(196.0, filter_body.get_combined_minimum_size().y + 52.0)
		if transport_panel != null:
			transport_panel.custom_minimum_size.y = maxf(176.0, transport_body.get_combined_minimum_size().y + 52.0)

	_rebuild_jukebox_playlist_ui()
	_refresh_camp_jukebox_section_heights()

	_jukebox_ensure_control_deck_scroll_margins()
	if _camp_jukebox_playlist_tools_row != null:
		_camp_jukebox_playlist_tools_row.columns = 2
	_jukebox_migrate_library_to_runtime_list()

	_camp_style_label(_camp_jukebox_title, CAMP_BORDER, 32, 2)
	_camp_style_label(_camp_jukebox_subtitle, CAMP_MUTED, 17, 1)
	if _camp_jukebox_title != null:
		_camp_jukebox_title.text = "CAMP JUKEBOX"
	if _camp_jukebox_subtitle != null:
		_camp_jukebox_subtitle.text = "Review unlocked camp tracks, curate playlists, and control the war-table ambiance without leaving camp."
		_camp_jukebox_subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header_badge := _camp_jukebox_root.get_node_or_null("JukeboxHeaderRow/HeaderLeft/HeaderBadge") as Label
	_camp_style_label(header_badge, CAMP_MUTED, 15, 1)
	if header_badge != null:
		header_badge.text = "AMBIANCE DOSSIER"
	_camp_style_label(_camp_jukebox_library_badge, CAMP_ACCENT_GREEN, 20, 1)
	_camp_style_label(_camp_jukebox_deck_badge, CAMP_BORDER, 20, 1)
	if _camp_jukebox_library_badge != null:
		_camp_jukebox_library_badge.text = "TRACK LIBRARY"
	if _camp_jukebox_deck_badge != null:
		_camp_jukebox_deck_badge.text = "CONTROL DECK"
	_camp_style_label(_camp_jukebox_list_hint, CAMP_MUTED, 14, 1)
	if _camp_jukebox_list_hint != null:
		_camp_jukebox_list_hint.text = "Click a track to play it. Toggle-select unlocked tracks to file them into playlists, favorites, or reorder actions."
	_camp_style_label(_camp_jukebox_volume_label, CAMP_MUTED, 15, 1)
	if _camp_jukebox_volume_label != null:
		_camp_jukebox_volume_label.text = "MASTER VOLUME"
	if close_jukebox_btn != null:
		close_jukebox_btn.text = "Close"
		_camp_style_button(close_jukebox_btn, false, 18, 42.0)
		close_jukebox_btn.custom_minimum_size = Vector2(144.0, 42.0)
	if jukebox_now_playing != null:
		_camp_style_rich_label(jukebox_now_playing, 18, Color(0.08, 0.06, 0.04, 0.94), CAMP_BORDER)
		jukebox_now_playing.fit_content = false
		jukebox_now_playing.custom_minimum_size = Vector2(0.0, 128.0)
		jukebox_now_playing.bbcode_enabled = true
	if _jukebox_chip_source != null:
		_jukebox_chip_source.text = "SOURCE"
	if _jukebox_chip_mood != null:
		_jukebox_chip_mood.text = "MOOD"
	if _jukebox_chip_length != null:
		_jukebox_chip_length.text = "LENGTH"
	if _jukebox_chip_favorite != null:
		_jukebox_chip_favorite.text = "FAVORITE"
	if jukebox_volume_slider != null:
		_camp_style_slider(jukebox_volume_slider)
		jukebox_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if jukebox_skip_btn != null:
		jukebox_skip_btn.text = "Skip Track"
		_camp_style_button(jukebox_skip_btn, false, 16, 40.0)
		jukebox_skip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if jukebox_stop_btn != null:
		jukebox_stop_btn.text = "Stop Music"
		_camp_style_button(jukebox_stop_btn, false, 16, 40.0)
		jukebox_stop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh_camp_jukebox_section_heights()
	_camp_style_scroll(_camp_jukebox_control_scroll)
	_ensure_camp_jukebox_lyrics_modal()
	_layout_camp_jukebox_lyrics_modal()

func _layout_camp_jukebox_panel() -> void:
	if jukebox_panel == null or _camp_jukebox_root == null:
		return
	var view_size := get_viewport_rect().size
	if view_size.x < 100.0 or view_size.y < 100.0:
		return
	if _camp_jukebox_dimmer != null:
		_camp_jukebox_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		move_child(_camp_jukebox_dimmer, max(0, jukebox_panel.get_index()))
	move_child(jukebox_panel, get_child_count() - 1)
	var panel_size := Vector2(minf(view_size.x * 0.82, 1280.0), minf(view_size.y * 0.82, 860.0))
	var panel_pos := (view_size - panel_size) * 0.5
	_camp_set_rect(jukebox_panel, panel_pos, panel_size)
	_camp_jukebox_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	_layout_camp_jukebox_lyrics_modal()

func _ensure_camp_jukebox_lyrics_modal() -> void:
	if jukebox_panel == null:
		return
	if _camp_jukebox_lyrics_dimmer == null or not is_instance_valid(_camp_jukebox_lyrics_dimmer):
		_camp_jukebox_lyrics_dimmer = ColorRect.new()
		_camp_jukebox_lyrics_dimmer.name = "JukeboxLyricsDimmer"
		_camp_jukebox_lyrics_dimmer.color = Color(0, 0, 0, 0.58)
		_camp_jukebox_lyrics_dimmer.visible = false
		_camp_jukebox_lyrics_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		_camp_jukebox_lyrics_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		jukebox_panel.add_child(_camp_jukebox_lyrics_dimmer)
	if _camp_jukebox_lyrics_modal == null or not is_instance_valid(_camp_jukebox_lyrics_modal):
		_camp_jukebox_lyrics_modal = Panel.new()
		_camp_jukebox_lyrics_modal.name = "JukeboxLyricsModal"
		_camp_jukebox_lyrics_modal.visible = false
		_camp_jukebox_lyrics_modal.mouse_filter = Control.MOUSE_FILTER_STOP
		_camp_jukebox_lyrics_modal.z_index = 92
		_camp_style_panel(_camp_jukebox_lyrics_modal, Color(0.09, 0.07, 0.05, 0.96), CAMP_BORDER, 20, 10)
		jukebox_panel.add_child(_camp_jukebox_lyrics_modal)

		var root := VBoxContainer.new()
		root.name = "LyricsRoot"
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
		root.add_theme_constant_override("separation", 12)
		_camp_jukebox_lyrics_modal.add_child(root)

		var header := HBoxContainer.new()
		header.name = "LyricsHeader"
		header.add_theme_constant_override("separation", 12)
		root.add_child(header)

		var title_stack := VBoxContainer.new()
		title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_stack.add_theme_constant_override("separation", 4)
		header.add_child(title_stack)

		_camp_jukebox_lyrics_title = Label.new()
		_camp_jukebox_lyrics_title.name = "LyricsTitle"
		title_stack.add_child(_camp_jukebox_lyrics_title)

		_camp_jukebox_lyrics_track_label = Label.new()
		_camp_jukebox_lyrics_track_label.name = "LyricsTrack"
		_camp_jukebox_lyrics_track_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_stack.add_child(_camp_jukebox_lyrics_track_label)

		_camp_jukebox_lyrics_close_btn = Button.new()
		_camp_jukebox_lyrics_close_btn.text = "Close"
		_camp_jukebox_lyrics_close_btn.pressed.connect(_close_jukebox_lyrics)
		_camp_style_button(_camp_jukebox_lyrics_close_btn, false, 15, 40.0)
		header.add_child(_camp_jukebox_lyrics_close_btn)

		var divider := Panel.new()
		divider.custom_minimum_size = Vector2(0.0, 3.0)
		divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		divider.add_theme_stylebox_override("panel", _camp_make_panel_style(Color(0.62, 0.48, 0.18, 0.92), Color(0, 0, 0, 0), 4, 0))
		root.add_child(divider)

		_camp_jukebox_lyrics_body = RichTextLabel.new()
		_camp_jukebox_lyrics_body.name = "LyricsBody"
		_camp_jukebox_lyrics_body.bbcode_enabled = false
		_camp_jukebox_lyrics_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_camp_jukebox_lyrics_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_camp_jukebox_lyrics_body.custom_minimum_size = Vector2(0.0, 320.0)
		_camp_style_rich_label(_camp_jukebox_lyrics_body, 18, Color(0.08, 0.06, 0.04, 0.95), CAMP_BORDER_SOFT, true)
		root.add_child(_camp_jukebox_lyrics_body)

	_camp_style_label(_camp_jukebox_lyrics_title, CAMP_BORDER, 24, 2)
	_camp_style_label(_camp_jukebox_lyrics_track_label, CAMP_MUTED, 16, 1)
	if _camp_jukebox_lyrics_title != null:
		_camp_jukebox_lyrics_title.text = "TRACK LYRICS"
	if _camp_jukebox_lyrics_track_label != null:
		_camp_jukebox_lyrics_track_label.text = "No active lyrical track selected."

func _layout_camp_jukebox_lyrics_modal() -> void:
	if jukebox_panel == null:
		return
	if _camp_jukebox_lyrics_dimmer != null:
		_camp_jukebox_lyrics_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _camp_jukebox_lyrics_modal == null:
		return
	var modal_size := Vector2(minf(jukebox_panel.size.x * 0.62, 760.0), minf(jukebox_panel.size.y * 0.76, 620.0))
	var modal_pos := (jukebox_panel.size - modal_size) * 0.5
	_camp_set_rect(_camp_jukebox_lyrics_modal, modal_pos, modal_size)

func _close_jukebox_lyrics() -> void:
	if _camp_jukebox_lyrics_dimmer != null:
		_camp_jukebox_lyrics_dimmer.visible = false
	if _camp_jukebox_lyrics_modal != null:
		_camp_jukebox_lyrics_modal.visible = false

func _on_jukebox_show_lyrics_pressed() -> void:
	_ensure_camp_jukebox_lyrics_modal()
	_layout_camp_jukebox_lyrics_modal()
	var track_path := _jukebox_current_track_path()
	var track_name := _jukebox_current_track_name()
	var lyrics_text := ""
	if track_path.is_empty():
		lyrics_text = "No lyrics are available while the default camp ambience is playing."
	else:
		var disc_data := _jukebox_find_disc_data_for_track_path(track_path)
		if disc_data != null and not disc_data.track_lyrics.strip_edges().is_empty():
			lyrics_text = disc_data.track_lyrics.strip_edges()
			if not disc_data.track_title.strip_edges().is_empty():
				track_name = disc_data.track_title.strip_edges()
		else:
			lyrics_text = "No lyrics are archived for this track yet.\n\nTo add them, open the matching music disc resource that uses ConsumableData and fill the track_lyrics field."
	if _camp_jukebox_lyrics_track_label != null:
		_camp_jukebox_lyrics_track_label.text = "TRACK // " + track_name
	if _camp_jukebox_lyrics_body != null:
		_camp_jukebox_lyrics_body.text = lyrics_text
		_camp_jukebox_lyrics_body.scroll_to_line(0)
	if _camp_jukebox_lyrics_dimmer != null:
		_camp_jukebox_lyrics_dimmer.visible = true
		jukebox_panel.move_child(_camp_jukebox_lyrics_dimmer, max(0, jukebox_panel.get_child_count() - 2))
	if _camp_jukebox_lyrics_modal != null:
		_camp_jukebox_lyrics_modal.visible = true
		jukebox_panel.move_child(_camp_jukebox_lyrics_modal, jukebox_panel.get_child_count() - 1)

func _format_camp_record_timestamp(unix_time: int) -> String:
	if unix_time <= 0:
		return "UPDATED: ARCHIVE DATE UNKNOWN"
	var date_info: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	return "UPDATED: %02d/%02d/%04d  %02d:%02d" % [
		int(date_info.get("day", 1)),
		int(date_info.get("month", 1)),
		int(date_info.get("year", 2000)),
		int(date_info.get("hour", 0)),
		int(date_info.get("minute", 0))
	]

func _style_camp_save_slot_button(button: Button, slot_index: int) -> void:
	if button == null:
		return
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.clip_text = false
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, 138.0)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", CAMP_TEXT)
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_pressed_color", CAMP_TEXT)
	button.add_theme_color_override("font_focus_color", CAMP_TEXT)
	var normal_style := _camp_make_button_style(Color(0.16, 0.12, 0.08, 0.96), CAMP_BORDER_SOFT, 20, 8)
	normal_style.border_width_left = 6
	normal_style.content_margin_left = 24.0
	normal_style.content_margin_right = 20.0
	normal_style.content_margin_top = 18.0
	normal_style.content_margin_bottom = 18.0
	var hover_style := _camp_make_button_style(Color(0.20, 0.15, 0.09, 0.98), CAMP_BORDER, 20, 8)
	hover_style.border_width_left = 6
	hover_style.content_margin_left = 24.0
	hover_style.content_margin_right = 20.0
	hover_style.content_margin_top = 18.0
	hover_style.content_margin_bottom = 18.0
	var pressed_style := _camp_make_button_style(Color(0.14, 0.10, 0.07, 0.98), CAMP_ACCENT_CYAN, 20, 8)
	pressed_style.border_width_left = 6
	pressed_style.content_margin_left = 24.0
	pressed_style.content_margin_right = 20.0
	pressed_style.content_margin_top = 18.0
	pressed_style.content_margin_bottom = 18.0
	var focus_style := _camp_make_button_style(Color(0.18, 0.13, 0.08, 0.98), CAMP_ACCENT_CYAN, 20, 8)
	focus_style.border_width_left = 6
	focus_style.content_margin_left = 24.0
	focus_style.content_margin_right = 20.0
	focus_style.content_margin_top = 18.0
	focus_style.content_margin_bottom = 18.0
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", focus_style)
	button.add_theme_stylebox_override("disabled", normal_style)
	button.text = ""
	_camp_apply_save_slot_preview(button, _get_camp_slot_preview_data(slot_index))

func _camp_ensure_save_slot_visuals(button: Button) -> Dictionary:
	var root := button.get_node_or_null("SlotCardContent") as VBoxContainer
	if root == null:
		root = VBoxContainer.new()
		root.name = "SlotCardContent"
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
		root.add_theme_constant_override("separation", 6)
		button.add_child(root)

	var badge_label := root.get_node_or_null("BadgeLabel") as Label
	if badge_label == null:
		badge_label = Label.new()
		badge_label.name = "BadgeLabel"
		badge_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		root.add_child(badge_label)

	var content_row := root.get_node_or_null("ContentRow") as HBoxContainer
	if content_row == null:
		content_row = HBoxContainer.new()
		content_row.name = "ContentRow"
		content_row.add_theme_constant_override("separation", 12)
		content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		root.add_child(content_row)

	var portrait_frame := content_row.get_node_or_null("PortraitFrame") as Panel
	if portrait_frame == null:
		portrait_frame = Panel.new()
		portrait_frame.name = "PortraitFrame"
		portrait_frame.custom_minimum_size = Vector2(72.0, 72.0)
		portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content_row.add_child(portrait_frame)

	var portrait_rect := portrait_frame.get_node_or_null("PortraitRect") as TextureRect
	if portrait_rect == null:
		portrait_rect = TextureRect.new()
		portrait_rect.name = "PortraitRect"
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		portrait_frame.add_child(portrait_rect)

	var text_root := content_row.get_node_or_null("TextRoot") as VBoxContainer
	if text_root == null:
		text_root = VBoxContainer.new()
		text_root.name = "TextRoot"
		text_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_root.add_theme_constant_override("separation", 4)
		content_row.add_child(text_root)

	var title_label := text_root.get_node_or_null("TitleLabel") as Label
	if title_label == null:
		title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_root.add_child(title_label)

	var meta_label := text_root.get_node_or_null("MetaLabel") as Label
	if meta_label == null:
		meta_label = Label.new()
		meta_label.name = "MetaLabel"
		meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_root.add_child(meta_label)

	var stamp_label := text_root.get_node_or_null("StampLabel") as Label
	if stamp_label == null:
		stamp_label = Label.new()
		stamp_label.name = "StampLabel"
		stamp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_root.add_child(stamp_label)

	_camp_style_label(badge_label, CAMP_ACCENT_CYAN.lerp(CAMP_MUTED, 0.35), 14, 1)
	_camp_style_panel(portrait_frame, Color(0.11, 0.09, 0.06, 0.96), CAMP_BORDER_SOFT, 10, 4)
	_camp_style_label(title_label, CAMP_BORDER, 21, 1)
	_camp_style_label(meta_label, CAMP_TEXT, 16, 1)
	_camp_style_label(stamp_label, CAMP_ACCENT_CYAN.lerp(CAMP_MUTED, 0.25), 14, 1)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.76, 1.0))
	meta_label.add_theme_color_override("font_color", CAMP_TEXT.lerp(CAMP_MUTED, 0.18))
	stamp_label.add_theme_color_override("font_color", CAMP_ACCENT_CYAN.lerp(CAMP_TEXT, 0.45))
	return {
		"root": root,
		"badge": badge_label,
		"portrait_frame": portrait_frame,
		"portrait": portrait_rect,
		"title": title_label,
		"meta": meta_label,
		"stamp": stamp_label
	}

func _camp_apply_save_slot_preview(button: Button, preview: Dictionary) -> void:
	if button == null:
		return
	var widgets := _camp_ensure_save_slot_visuals(button)
	var badge_label: Label = widgets["badge"]
	var portrait_frame: Panel = widgets["portrait_frame"]
	var portrait_rect: TextureRect = widgets["portrait"]
	var title_label: Label = widgets["title"]
	var meta_label: Label = widgets["meta"]
	var stamp_label: Label = widgets["stamp"]
	if badge_label != null:
		badge_label.text = str(preview.get("badge", ""))
	var portrait_value: Variant = preview.get("portrait")
	if portrait_rect != null:
		if portrait_value is String and ResourceLoader.exists(str(portrait_value)):
			portrait_rect.texture = load(str(portrait_value))
		elif portrait_value is Texture2D:
			portrait_rect.texture = portrait_value as Texture2D
		else:
			portrait_rect.texture = null
	if portrait_frame != null:
		portrait_frame.visible = portrait_rect != null and portrait_rect.texture != null
	if title_label != null:
		title_label.text = str(preview.get("title", ""))
	if meta_label != null:
		meta_label.text = str(preview.get("meta", ""))
	if stamp_label != null:
		stamp_label.text = str(preview.get("stamp", ""))

func _get_camp_slot_preview_data(slot_num: int) -> Dictionary:
	var path = CampaignManager.get_save_path(slot_num, false)
	if not FileAccess.file_exists(path):
		return {
			"badge": "SLOT %d  //  EMPTY RECORD" % slot_num,
			"title": "No manual field archive written yet.",
			"meta": "Store the current campaign state here.",
			"stamp": "READY FOR ARCHIVAL",
			"portrait": null
		}

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"badge": "SLOT %d  //  RECORD UNREADABLE" % slot_num,
			"title": "Archive data could not be opened.",
			"meta": "Try saving into this slot again.",
			"stamp": "UPDATED: ARCHIVE DATE UNKNOWN",
			"portrait": null
		}
	var save_data = file.get_var()
	file.close()

	var roster = save_data.get("player_roster", [])
	var leader_name = "Unknown"
	var leader_lvl = 1
	var portrait_value: Variant = null
	if roster.size() > 0:
		leader_name = roster[0].get("unit_name", "Hero")
		leader_lvl = roster[0].get("level", 1)
		portrait_value = roster[0].get("portrait", null)
	var gold = save_data.get("global_gold", 0)
	var map_idx = save_data.get("current_level_index", 0) + 1
	var modified_time := int(FileAccess.get_modified_time(path))
	return {
		"badge": "SLOT %d  //  MANUAL FIELD RECORD" % slot_num,
		"title": "%s  LV %d" % [str(leader_name).to_upper(), int(leader_lvl)],
		"meta": "FIELD RECORD: MAP %d  |  GOLD %d" % [int(map_idx), int(gold)],
		"stamp": _format_camp_record_timestamp(modified_time),
		"portrait": portrait_value
	}

func _ensure_camp_save_records_popup() -> void:
	if save_popup == null:
		return
	if _camp_save_dimmer == null or not is_instance_valid(_camp_save_dimmer):
		_camp_save_dimmer = ColorRect.new()
		_camp_save_dimmer.name = "CampSaveDimmer"
		_camp_save_dimmer.color = Color(0, 0, 0, 0.76)
		_camp_save_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_camp_save_dimmer.visible = false
		_camp_save_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_camp_save_dimmer)
		move_child(_camp_save_dimmer, max(0, save_popup.get_index()))

	save_popup.visible = false
	save_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	save_popup.z_index = 42
	_camp_style_panel(save_popup, CAMP_PANEL_BG_ALT, CAMP_BORDER, 22, 12)

	if _camp_save_root == null or not is_instance_valid(_camp_save_root):
		_camp_save_root = VBoxContainer.new()
		_camp_save_root.name = "CampSaveRoot"
		_camp_save_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 28)
		_camp_save_root.add_theme_constant_override("separation", 14)
		save_popup.add_child(_camp_save_root)

	if _camp_save_header_badge == null or not is_instance_valid(_camp_save_header_badge):
		_camp_save_header_badge = Label.new()
		_camp_save_root.add_child(_camp_save_header_badge)

	if _camp_save_title == null or not is_instance_valid(_camp_save_title):
		_camp_save_title = Label.new()
		_camp_save_root.add_child(_camp_save_title)

	if _camp_save_subtitle == null or not is_instance_valid(_camp_save_subtitle):
		_camp_save_subtitle = Label.new()
		_camp_save_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_camp_save_root.add_child(_camp_save_subtitle)

	var divider := save_popup.get_node_or_null("CampSaveDivider") as Panel
	if divider == null:
		divider = Panel.new()
		divider.name = "CampSaveDivider"
		_camp_save_root.add_child(divider)
	divider.custom_minimum_size = Vector2(0.0, 3.0)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.add_theme_stylebox_override("panel", _camp_make_panel_style(Color(0.62, 0.48, 0.18, 0.92), Color(0, 0, 0, 0), 4, 0))

	var header_row := save_popup.get_node_or_null("CampSaveHeaderRow") as HBoxContainer
	if header_row == null:
		header_row = HBoxContainer.new()
		header_row.name = "CampSaveHeaderRow"
		header_row.add_theme_constant_override("separation", 14)
		_camp_save_root.add_child(header_row)
	elif header_row.get_parent() != _camp_save_root:
		if header_row.get_parent() != null:
			header_row.get_parent().remove_child(header_row)
		_camp_save_root.add_child(header_row)

	var spacer := header_row.get_node_or_null("HeaderSpacer") as Control
	if spacer == null:
		spacer = Control.new()
		spacer.name = "HeaderSpacer"
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_row.add_child(spacer)
	if close_save_btn != null and close_save_btn.get_parent() != header_row:
		if close_save_btn.get_parent() != null:
			close_save_btn.get_parent().remove_child(close_save_btn)
		header_row.add_child(close_save_btn)
	if close_save_btn != null:
		close_save_btn.layout_mode = 2
		close_save_btn.text = "Close"
		_camp_style_button(close_save_btn, false, 18, 42.0)
		close_save_btn.custom_minimum_size = Vector2(150.0, 42.0)

	if save_slot_vbox != null and save_slot_vbox.get_parent() != _camp_save_root:
		if save_slot_vbox.get_parent() != null:
			save_slot_vbox.get_parent().remove_child(save_slot_vbox)
		_camp_save_root.add_child(save_slot_vbox)
	_camp_save_slots_root = save_slot_vbox
	if save_slot_vbox != null:
		save_slot_vbox.layout_mode = 2
		save_slot_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
		save_slot_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		save_slot_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		save_slot_vbox.add_theme_constant_override("separation", 16)
		save_slot_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN

	for slot_info in [
		{"button": save_slot_1, "index": 1},
		{"button": save_slot_2, "index": 2},
		{"button": save_slot_3, "index": 3}
	]:
		var slot_button: Button = slot_info["button"]
		var slot_index: int = int(slot_info["index"])
		if slot_button == null:
			continue
		if slot_button.get_parent() != save_slot_vbox:
			if slot_button.get_parent() != null:
				slot_button.get_parent().remove_child(slot_button)
			save_slot_vbox.add_child(slot_button)
		_style_camp_save_slot_button(slot_button, slot_index)

	if _camp_save_footer == null or not is_instance_valid(_camp_save_footer):
		_camp_save_footer = Label.new()
		_camp_save_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_camp_save_root.add_child(_camp_save_footer)

	_camp_style_label(_camp_save_header_badge, CAMP_MUTED, 16, 1)
	_camp_save_header_badge.text = "ARCHIVE DOSSIER"
	_camp_style_label(_camp_save_title, CAMP_BORDER, 34, 2)
	_camp_save_title.text = "SAVE RECORDS"
	_camp_style_label(_camp_save_subtitle, CAMP_MUTED, 18, 1)
	_camp_save_subtitle.text = "Store the current war-camp state in a manual field record. Existing records can be inspected and overwritten after confirmation."
	_camp_style_label(_camp_save_footer, CAMP_ACCENT_CYAN, 15, 1)
	_camp_save_footer.text = "TIP: Manual records preserve your current roster, map progress, convoy, gold, and active camp state."

func _layout_camp_save_records_popup() -> void:
	if save_popup == null or _camp_save_root == null or not is_instance_valid(_camp_save_root):
		return
	var view_size := get_viewport_rect().size
	if view_size.x < 100.0 or view_size.y < 100.0:
		return
	if _camp_save_dimmer != null:
		_camp_save_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var popup_size := Vector2(minf(view_size.x * 0.58, 940.0), minf(view_size.y * 0.68, 720.0))
	var popup_pos := (view_size - popup_size) * 0.5
	if _camp_save_dimmer != null:
		move_child(_camp_save_dimmer, max(0, save_popup.get_index()))
	move_child(save_popup, get_child_count() - 1)
	_camp_set_rect(save_popup, popup_pos, popup_size)
	_camp_save_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 28)
	if _camp_save_slots_root != null:
		_camp_save_slots_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_camp_save_slots_root.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _camp_style_dossier_richtext(label: RichTextLabel, font_size: int = 18) -> void:
	if label == null:
		return
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", CAMP_TEXT)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.01, 0.96))
	label.add_theme_constant_override("outline_size", 1)
	var clear_style := StyleBoxFlat.new()
	clear_style.bg_color = Color(0, 0, 0, 0)
	label.add_theme_stylebox_override("normal", clear_style)

func _camp_unit_info_primary_bar_definitions() -> Array[Dictionary]:
	return [
		{"key": "hp", "label": "HP"},
		{"key": "poise", "label": "POISE"},
		{"key": "xp", "label": "XP"},
	]

func _camp_unit_info_stat_definitions() -> Array[Dictionary]:
	return [
		{"key": "strength"},
		{"key": "magic"},
		{"key": "defense"},
		{"key": "resistance"},
		{"key": "speed"},
		{"key": "agility"},
	]

func _camp_unit_info_primary_fill_color(bar_key: String, current_value: int, max_value: int) -> Color:
	match bar_key:
		"hp":
			if max_value <= 0:
				return CAMP_MUTED
			var ratio := clampf(float(current_value) / float(max_value), 0.0, 1.0)
			if ratio >= 0.67:
				return Color(0.30, 0.88, 0.52, 1.0)
			if ratio >= 0.34:
				return Color(0.92, 0.78, 0.28, 1.0)
			return Color(0.92, 0.38, 0.30, 1.0)
		"poise":
			if max_value <= 0:
				return CAMP_MUTED
			var poise_ratio := clampf(float(current_value) / float(max_value), 0.0, 1.0)
			if poise_ratio >= 0.67:
				return Color(0.48, 0.90, 1.0, 1.0)
			if poise_ratio >= 0.34:
				return Color(0.88, 0.78, 0.30, 1.0)
			return Color(0.93, 0.42, 0.30, 1.0)
		"xp":
			return Color(0.98, 0.84, 0.36, 1.0)
		_:
			return CAMP_BORDER

func _camp_style_unit_info_primary_bar(bar: ProgressBar, fill: Color, bar_key: String = "") -> void:
	if bar == null:
		return
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.clip_contents = true
	var radius := 5
	var border := Color(0.38, 0.33, 0.22, 0.92)
	match bar_key:
		"hp":
			radius = 7
			border = Color(0.54, 0.28, 0.22, 0.94)
		"poise":
			radius = 3
			border = Color(0.22, 0.46, 0.56, 0.94)
		"xp":
			radius = 2
			border = Color(0.56, 0.46, 0.18, 0.94)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.06, 0.05, 0.98)
	bg_style.border_color = border
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(radius)
	bg_style.shadow_color = Color(0.0, 0.0, 0.0, 0.24)
	bg_style.shadow_size = 2
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.border_color = fill.lightened(0.18)
	fill_style.set_border_width_all(1)
	fill_style.set_corner_radius_all(radius)
	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)

func _camp_unit_info_stat_fill_color(stat_key: String, stat_value: int) -> Color:
	if stat_value >= 200:
		return CAMP_UNIT_INFO_STAT_TIER_WHITE
	if stat_value >= 150:
		return CAMP_UNIT_INFO_STAT_TIER_ORANGE
	if stat_value >= 100:
		return CAMP_UNIT_INFO_STAT_TIER_PURPLE
	if stat_value >= 50:
		return CAMP_UNIT_INFO_STAT_TIER_CYAN
	match stat_key:
		"strength":
			return Color(0.94, 0.48, 0.36, 1.0)
		"magic":
			return Color(0.78, 0.48, 0.96, 1.0)
		"defense":
			return Color(0.50, 0.88, 0.50, 1.0)
		"resistance":
			return Color(0.38, 0.90, 0.82, 1.0)
		"speed":
			return Color(0.46, 0.76, 1.0, 1.0)
		"agility":
			return Color(0.96, 0.82, 0.44, 1.0)
		_:
			return CAMP_BORDER

func _camp_style_unit_info_stat_bar(bar: ProgressBar, fill: Color, overcap: bool) -> void:
	if bar == null:
		return
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.clip_contents = true
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.06, 0.05, 0.98)
	bg_style.border_color = fill if overcap else Color(0.24, 0.22, 0.18, 1.0)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(5)
	bg_style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	bg_style.shadow_size = 2
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.border_color = fill.lightened(0.18)
	fill_style.set_border_width_all(1)
	fill_style.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)

func _camp_unit_info_stat_display_value(raw_value: int) -> float:
	if raw_value <= 0:
		return 0.0
	var cap_int := int(CAMP_UNIT_INFO_STAT_BAR_CAP)
	if raw_value < cap_int:
		return float(raw_value)
	var wrapped := raw_value % cap_int
	if wrapped == 0:
		return CAMP_UNIT_INFO_STAT_BAR_CAP
	return float(wrapped)

func _camp_weapon_type_name_safe(w_type: int) -> String:
	match int(w_type):
		0: return "Sword"
		1: return "Lance"
		2: return "Axe"
		3: return "Bow"
		4: return "Tome"
		5: return "None"
		6: return "Knife"
		7: return "Firearm"
		8: return "Fist"
		9: return "Instrument"
		10: return "Dark Tome"
		_: return "Unknown"

func _camp_weapon_marker(item: Resource) -> String:
	if item == null:
		return "--"
	if item.get("is_healing_staff") == true or item.get("is_buff_staff") == true or item.get("is_debuff_staff") == true:
		return "STF"
	if item.get("weapon_type") == null:
		return "--"
	match int(item.weapon_type):
		0: return "SWD"
		1: return "LNC"
		2: return "AXE"
		3: return "BOW"
		4: return "TOM"
		6: return "KNF"
		7: return "GUN"
		8: return "FST"
		9: return "INS"
		10: return "DRK"
		_: return "--"

func _camp_format_class_weapon_permissions(class_res: Resource) -> String:
	if class_res == null:
		return "Weapons: Unknown"
	var parts: Array[String] = []
	if class_res.get("allowed_weapon_types") != null:
		for raw_type in class_res.allowed_weapon_types:
			parts.append(_camp_weapon_type_name_safe(int(raw_type)))
	if class_res.get("can_use_healing_staff") == true:
		parts.append("Healing Staff")
	if class_res.get("can_use_buff_staff") == true:
		parts.append("Buff Staff")
	if class_res.get("can_use_debuff_staff") == true:
		parts.append("Debuff Staff")
	return "Weapons: None" if parts.is_empty() else "Weapons: " + ", ".join(parts)


func _format_class_weapon_permissions(class_res: Resource) -> String:
	return _camp_format_class_weapon_permissions(class_res)


func _ask_for_promotion_choice(options: Array) -> Resource:
	return await PromotionChoiceUiHelpers.ask_for_promotion_choice(self, options)

func _camp_unit_info_primary_description(bar_key: String) -> String:
	match bar_key:
		"hp":
			return "Life total. If HP reaches 0, the unit is defeated or forced out of the fight."
		"poise":
			return "Stagger resistance. Higher Poise helps resist breaks, shock, and forced openings. It is usually improved by sturdier classes, defensive bonuses, certain gear, dragon effects, or traits."
		"xp":
			return "Current experience toward the next level, where the unit can gain stronger stats and improve overall combat power."
		_:
			return ""

func _camp_unit_info_stat_label(stat_key: String) -> String:
	match stat_key:
		"strength":
			return "STRENGTH"
		"magic":
			return "MAGIC"
		"defense":
			return "DEFENSE"
		"resistance":
			return "RESISTANCE"
		"speed":
			return "SPEED"
		"agility":
			return "AGILITY"
		_:
			return stat_key.to_upper()

func _camp_unit_info_stat_description(stat_key: String) -> String:
	match stat_key:
		"strength":
			return "Raises damage with swords, lances, axes, bows, and many physical techniques."
		"magic":
			return "Raises damage with spells, magic weapons, and abilities that scale from magical power."
		"defense":
			return "Reduces damage taken from physical attacks like blades, arrows, claws, and blunt impacts."
		"resistance":
			return "Reduces damage taken from spells, elemental attacks, curses, and other magical effects."
		"speed":
			return "Helps this unit strike twice before slower enemies and avoid being struck twice by faster ones."
		"agility":
			return "Improves dodge and evasive reactions, and it is the main stat feeding base critical chance before weapon, skill, and battle bonuses."
		_:
			return ""

func _camp_unit_info_stat_hint_specs(stat_key: String) -> Array[Dictionary]:
	match stat_key:
		"speed":
			return [
				{"text": "x2", "color": Color(0.45, 0.78, 1.0, 1.0)},
				{"text": "TEMPO", "color": Color(0.58, 0.84, 1.0, 1.0)},
			]
		"agility":
			return [
				{"text": "CRIT", "color": Color(1.0, 0.78, 0.30, 1.0)},
				{"text": "EVADE", "color": Color(0.60, 0.94, 0.76, 1.0)},
			]
		_:
			return []

func _camp_unit_info_growth_label(stat_key: String) -> String:
	match stat_key:
		"hp":
			return "HEALTH GROWTH"
		"strength":
			return "STRENGTH GROWTH"
		"magic":
			return "MAGIC GROWTH"
		"defense":
			return "DEFENSE GROWTH"
		"resistance":
			return "RESISTANCE GROWTH"
		"speed":
			return "SPEED GROWTH"
		"agility":
			return "AGILITY GROWTH"
		_:
			return stat_key.replace("_", " ").to_upper()

func _camp_collect_growth_totals(base_data: Resource, class_res: Resource) -> Dictionary:
	var totals := {
		"hp": 0,
		"strength": 0,
		"magic": 0,
		"defense": 0,
		"resistance": 0,
		"speed": 0,
		"agility": 0,
	}
	if base_data != null:
		var raw_hp = base_data.get("hp_growth")
		var raw_str = base_data.get("str_growth")
		var raw_mag = base_data.get("mag_growth")
		var raw_def = base_data.get("def_growth")
		var raw_res = base_data.get("res_growth")
		var raw_spd = base_data.get("spd_growth")
		var raw_agi = base_data.get("agi_growth")
		totals["hp"] = int(raw_hp) if raw_hp != null else 0
		totals["strength"] = int(raw_str) if raw_str != null else 0
		totals["magic"] = int(raw_mag) if raw_mag != null else 0
		totals["defense"] = int(raw_def) if raw_def != null else 0
		totals["resistance"] = int(raw_res) if raw_res != null else 0
		totals["speed"] = int(raw_spd) if raw_spd != null else 0
		totals["agility"] = int(raw_agi) if raw_agi != null else 0
	if class_res != null:
		var bonus_map := {
			"hp": "hp_growth_bonus",
			"strength": "str_growth_bonus",
			"magic": "mag_growth_bonus",
			"defense": "def_growth_bonus",
			"resistance": "res_growth_bonus",
			"speed": "spd_growth_bonus",
			"agility": "agi_growth_bonus",
		}
		for key in bonus_map.keys():
			var raw_bonus = class_res.get(bonus_map[key])
			totals[key] = clampi(int(totals[key]) + (int(raw_bonus) if raw_bonus != null else 0), 0, 100)
	else:
		for key in totals.keys():
			totals[key] = clampi(int(totals[key]), 0, 100)
	return totals

func _camp_resolve_poise_values(unit_data: Dictionary) -> Dictionary:
	var max_hp: int = max(1, int(unit_data.get("max_hp", unit_data.get("current_hp", 1))))
	var defense_value: int = int(unit_data.get("defense", 0))
	var temp_def_bonus: int = int(unit_data.get("inner_peace_def_bonus_temp", 0))
	var temp_def_penalty: int = int(unit_data.get("frenzy_def_penalty_temp", 0))
	var defend_bonus: int = int(unit_data.get("defense_bonus", 0))
	var is_defending: bool = bool(unit_data.get("is_defending", false))
	var computed_defense: int = defense_value + temp_def_bonus - temp_def_penalty
	if is_defending:
		computed_defense += defend_bonus

	var computed_max_poise: int = max_hp + (computed_defense * 2) + (25 if is_defending else 0)
	var max_poise: int = max(1, int(unit_data.get("max_poise", computed_max_poise)))
	var current_value: Variant = null
	if unit_data.has("current_poise"):
		current_value = unit_data.get("current_poise")
	elif unit_data.has("poise"):
		current_value = unit_data.get("poise")
	var current_poise: int = max_poise if current_value == null else clampi(int(current_value), 0, max_poise)
	return {
		"current": current_poise,
		"max": max_poise,
	}

func _camp_build_unit_info_summary_text(unit_data: Dictionary) -> String:
	var lines: Array[String] = []
	var ability: String = str(unit_data.get("ability", "None"))
	if ability.is_empty():
		ability = "None"
	lines.append("[color=gold]Active Ability[/color]: [color=#%s]%s[/color]" % [CAMP_ACCENT_CYAN.to_html(false), ability.to_upper()])
	var inventory: Array = unit_data.get("inventory", [])
	lines.append("[color=gold]Carried Items[/color]: %d" % inventory.size())
	var trait_lines: PackedStringArray = UnitTraitsDisplay.trait_lines_from_roster_dict(unit_data)
	if trait_lines.size() > 0:
		lines.append("[color=gold]Traits[/color]: %s" % ", ".join(trait_lines))
	return "[font_size=18]" + "\n".join(lines) + "[/font_size]"

func _camp_build_unit_info_record_text(unit_data: Dictionary, class_res: Resource) -> String:
	var lines: Array[String] = []
	lines.append("[color=gold]Field Doctrine[/color]")
	lines.append("Class: [color=cyan]%s[/color]" % str(unit_data.get("unit_class", "Unknown")))
	lines.append("Move: %d" % int(unit_data.get("move_range", 0)))
	lines.append("")

	if class_res != null:
		lines.append("[color=gold]Weapon Permissions[/color]")
		lines.append(_camp_format_class_weapon_permissions(class_res))
		lines.append("")

		lines.append("[color=gold]Class Bonuses[/color]")
		var class_bonus_parts: Array[String] = []
		for pair in [
			["hp_bonus", "HP", ""],
			["str_bonus", "STR", "coral"],
			["mag_bonus", "MAG", "orchid"],
			["def_bonus", "DEF", "palegreen"],
			["res_bonus", "RES", "aquamarine"],
			["spd_bonus", "SPD", "skyblue"],
			["agi_bonus", "AGI", "wheat"],
		]:
			var key: String = String(pair[0])
			var raw_val = class_res.get(key)
			if raw_val == null or int(raw_val) == 0:
				continue
			var chunk := "%s %+d" % [String(pair[1]), int(raw_val)]
			var tint: String = String(pair[2])
			class_bonus_parts.append(chunk if tint == "" else "[color=%s]%s[/color]" % [tint, chunk])
		lines.append("None" if class_bonus_parts.is_empty() else ", ".join(class_bonus_parts))
		lines.append("")

		lines.append("[color=gold]Promotion Bonuses[/color]")
		var promo_parts: Array[String] = []
		for pair in [
			["promo_hp_bonus", "HP", ""],
			["promo_str_bonus", "STR", "coral"],
			["promo_mag_bonus", "MAG", "orchid"],
			["promo_def_bonus", "DEF", "palegreen"],
			["promo_res_bonus", "RES", "aquamarine"],
			["promo_spd_bonus", "SPD", "skyblue"],
			["promo_agi_bonus", "AGI", "wheat"],
		]:
			var key: String = String(pair[0])
			var raw_val = class_res.get(key)
			if raw_val == null or int(raw_val) == 0:
				continue
			var chunk := "%s %+d" % [String(pair[1]), int(raw_val)]
			var tint: String = String(pair[2])
			promo_parts.append(chunk if tint == "" else "[color=%s]%s[/color]" % [tint, chunk])
		lines.append("None" if promo_parts.is_empty() else ", ".join(promo_parts))
		lines.append("")

	if unit_data.get("unlocked_abilities") != null and (unit_data.get("unlocked_abilities") as Array).size() > 0:
		lines.append("[color=gold]Abilities[/color]")
		lines.append(", ".join(unit_data.get("unlocked_abilities")))
		lines.append("")
	elif str(unit_data.get("ability", "")).strip_edges() != "":
		lines.append("[color=gold]Ability[/color]")
		lines.append(str(unit_data.get("ability")))
		lines.append("")

	lines.append("[color=gold]Inventory[/color]")
	var inventory: Array = unit_data.get("inventory", [])
	if inventory.is_empty():
		lines.append("None")
	else:
		for item_raw in inventory:
			var item_value: Variant = item_raw
			var item: Resource = null
			if item_value is String and ResourceLoader.exists(item_value):
				item = load(item_value)
			elif item_value is Resource:
				item = item_value
			if item == null:
				continue
			var item_name: String = str(item.get("weapon_name")) if item.get("weapon_name") != null else str(item.get("item_name"))
			if item is WeaponData:
				var w_type := _camp_weapon_type_name_safe(int(item.weapon_type))
				lines.append("- %s (%s)" % [item_name, w_type])
				lines.append("  Mt %d | Hit %+d | Rng %d-%d" % [int(item.might), int(item.hit_bonus), int(item.min_range), int(item.max_range)])
			else:
				lines.append("- " + item_name)

	lines.append("")
	lines.append("[color=gold]Notes[/color]")
	lines.append("Growth outlook and bond cards are surfaced above.")
	lines.append("Crit readiness is mainly explained through Agility and weapon effects.")

	return "[font_size=20]" + "\n".join(lines) + "[/font_size]"

func _camp_build_unit_info_relationship_cards(unit_data: Dictionary) -> void:
	if _camp_unit_info_relationships_root == null:
		return
	for child in _camp_unit_info_relationships_root.get_children():
		child.queue_free()

	var unit_id: String = str(unit_data.get("unit_name", "Hero"))
	var candidate_ids: Array = []
	for ally_raw in CampaignManager.player_roster:
		var ally: Dictionary = ally_raw as Dictionary
		var other_name: String = str(ally.get("unit_name", ""))
		if not other_name.is_empty() and other_name != unit_id:
			candidate_ids.append(other_name)

	var rel_entries: Array = CampaignManager.get_top_relationship_entries_for_unit(unit_id, candidate_ids, 6)
	if rel_entries.is_empty():
		var empty_label := Label.new()
		_camp_style_label(empty_label, CAMP_MUTED, 16, 2)
		empty_label.text = "No notable bonds in this deployment yet."
		_camp_unit_info_relationships_root.add_child(empty_label)
		return

	for entry_raw in rel_entries:
		var entry: Dictionary = entry_raw as Dictionary
		var stat: String = str(entry.get("stat", ""))
		var value: int = int(entry.get("value", 0))
		var formed: bool = bool(entry.get("formed", false))
		var partner_id: String = str(entry.get("partner_id", "?"))
		var tint: Color = CampaignManager.get_relationship_type_color(stat)
		var effect_hint: String = CampaignManager.get_relationship_effect_hint(stat, value)

		var card := Panel.new()
		card.custom_minimum_size = Vector2(0, 96)
		_camp_style_panel(card, Color(0.11, 0.10, 0.08, 0.92), tint.lightened(0.08), 12, 7)
		_camp_unit_info_relationships_root.add_child(card)

		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		box.add_theme_constant_override("separation", 5)
		card.add_child(box)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 8)
		box.add_child(top_row)

		var partner_label := Label.new()
		partner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_camp_style_label(partner_label, CAMP_TEXT, 18, 2)
		partner_label.text = partner_id
		top_row.add_child(partner_label)

		var state_chip := Panel.new()
		state_chip.custom_minimum_size = Vector2(150, 28)
		_camp_style_panel(state_chip, Color(0.10, 0.09, 0.07, 0.96), tint, 8, 5)
		top_row.add_child(state_chip)

		var state_label := Label.new()
		state_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
		_camp_style_label(state_label, CAMP_TEXT, 15, 2)
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		state_label.text = ("%s FORMED" % CampaignManager.get_relationship_type_display_name(stat).to_upper()) if formed else ("%s %d" % [CampaignManager.get_relationship_type_display_name(stat).to_upper(), value])
		state_chip.add_child(state_label)

		var hint_label := Label.new()
		_camp_style_label(hint_label, tint.lightened(0.18), 16, 2)
		hint_label.text = effect_hint
		box.add_child(hint_label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 14)
		bar.max_value = 100.0
		bar.value = clampf(float(value), 0.0, 100.0)
		_camp_style_unit_info_stat_bar(bar, tint, formed)
		box.add_child(bar)
		var sheen := _attach_unit_info_bar_sheen(bar)
		_animate_unit_info_bar_sheen(sheen, bar, 0.02)

func _ensure_camp_detailed_unit_info_panel() -> void:
	if unit_info_panel == null:
		return
	if _camp_unit_info_root != null and is_instance_valid(_camp_unit_info_root):
		return

	for child in unit_info_panel.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _camp_unit_info_dimmer == null or not is_instance_valid(_camp_unit_info_dimmer):
		_camp_unit_info_dimmer = ColorRect.new()
		_camp_unit_info_dimmer.name = "CampUnitInfoDimmer"
		_camp_unit_info_dimmer.color = Color(0, 0, 0, 0.78)
		_camp_unit_info_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_camp_unit_info_dimmer.visible = false
		_camp_unit_info_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_camp_unit_info_dimmer)
		move_child(_camp_unit_info_dimmer, get_child_count() - 1)

	unit_info_panel.visible = false
	unit_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	unit_info_panel.z_index = 40
	_camp_style_panel(unit_info_panel, CAMP_PANEL_BG_ALT, CAMP_BORDER, 20, 12)

	_camp_unit_info_root = VBoxContainer.new()
	_camp_unit_info_root.name = "CampDossierRoot"
	_camp_unit_info_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 22)
	_camp_unit_info_root.add_theme_constant_override("separation", 16)
	unit_info_panel.add_child(_camp_unit_info_root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	_camp_unit_info_root.add_child(header)

	var portrait_frame := Panel.new()
	portrait_frame.custom_minimum_size = Vector2(210, 210)
	_camp_style_panel(portrait_frame, Color(0.08, 0.06, 0.04, 0.92), CAMP_BORDER_SOFT, 16, 8)
	header.add_child(portrait_frame)

	_camp_unit_info_portrait = TextureRect.new()
	_camp_unit_info_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_camp_unit_info_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_camp_unit_info_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	portrait_frame.add_child(_camp_unit_info_portrait)

	var header_text := VBoxContainer.new()
	header_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_text.add_theme_constant_override("separation", 8)
	header.add_child(header_text)

	_camp_unit_info_name = Label.new()
	_camp_style_label(_camp_unit_info_name, CAMP_BORDER, 38, 3)
	header_text.add_child(_camp_unit_info_name)

	_camp_unit_info_meta_label = Label.new()
	_camp_style_label(_camp_unit_info_meta_label, CAMP_MUTED, 22, 2)
	header_text.add_child(_camp_unit_info_meta_label)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 3)
	divider.color = Color(CAMP_BORDER.r, CAMP_BORDER.g, CAMP_BORDER.b, 0.55)
	header_text.add_child(divider)

	var weapon_row := HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 10)
	header_text.add_child(weapon_row)

	var weapon_pair_frame := Panel.new()
	weapon_pair_frame.custom_minimum_size = Vector2(114, 48)
	_camp_style_panel(weapon_pair_frame, Color(0.16, 0.13, 0.09, 0.94), CAMP_BORDER_SOFT, 10, 6)
	weapon_row.add_child(weapon_pair_frame)

	var weapon_pair_inner := HBoxContainer.new()
	weapon_pair_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	weapon_pair_inner.add_theme_constant_override("separation", 6)
	weapon_pair_frame.add_child(weapon_pair_inner)

	var weapon_badge_panel := Panel.new()
	weapon_badge_panel.custom_minimum_size = Vector2(50, 32)
	_camp_style_panel(weapon_badge_panel, Color(0.24, 0.18, 0.10, 0.96), CAMP_BORDER, 8, 5)
	weapon_pair_inner.add_child(weapon_badge_panel)

	_camp_unit_info_weapon_badge = Label.new()
	_camp_unit_info_weapon_badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
	_camp_style_label(_camp_unit_info_weapon_badge, CAMP_BORDER, 16, 2)
	_camp_unit_info_weapon_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_camp_unit_info_weapon_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	weapon_badge_panel.add_child(_camp_unit_info_weapon_badge)

	var weapon_icon_panel := Panel.new()
	weapon_icon_panel.custom_minimum_size = Vector2(32, 32)
	_camp_style_panel(weapon_icon_panel, Color(0.11, 0.10, 0.08, 0.96), CAMP_BORDER_SOFT, 8, 4)
	weapon_pair_inner.add_child(weapon_icon_panel)

	_camp_unit_info_weapon_icon = TextureRect.new()
	_camp_unit_info_weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_camp_unit_info_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_camp_unit_info_weapon_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
	weapon_icon_panel.add_child(_camp_unit_info_weapon_icon)

	_camp_unit_info_weapon_name = Label.new()
	_camp_unit_info_weapon_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_style_label(_camp_unit_info_weapon_name, CAMP_TEXT, 22, 2)
	weapon_row.add_child(_camp_unit_info_weapon_name)

	_camp_unit_info_summary_text = RichTextLabel.new()
	_camp_unit_info_summary_text.custom_minimum_size = Vector2(0, 82)
	_camp_style_dossier_richtext(_camp_unit_info_summary_text, 18)
	header_text.add_child(_camp_unit_info_summary_text)

	var close_box := VBoxContainer.new()
	close_box.alignment = BoxContainer.ALIGNMENT_END
	header.add_child(close_box)

	_camp_unit_info_close_btn = Button.new()
	_camp_unit_info_close_btn.custom_minimum_size = Vector2(190, 60)
	_camp_style_button(_camp_unit_info_close_btn, false, 22, 60.0)
	_camp_unit_info_close_btn.text = "Close"
	if not _camp_unit_info_close_btn.pressed.is_connected(_hide_unit_info_panel):
		_camp_unit_info_close_btn.pressed.connect(_hide_unit_info_panel)
	close_box.add_child(_camp_unit_info_close_btn)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	_camp_unit_info_root.add_child(body)

	var left_panel := Panel.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.0
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_camp_style_panel(left_panel, Color(0.09, 0.07, 0.05, 0.90), CAMP_BORDER_SOFT, 14, 6)
	body.add_child(left_panel)

	var right_panel := Panel.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.0
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_camp_style_panel(right_panel, Color(0.09, 0.07, 0.05, 0.90), CAMP_BORDER_SOFT, 14, 6)
	body.add_child(right_panel)

	var left_scroll := ScrollContainer.new()
	left_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	left_panel.add_child(left_scroll)
	_camp_style_scroll(left_scroll)
	_camp_unit_info_left_scroll = left_scroll

	var left_root := VBoxContainer.new()
	left_root.custom_minimum_size = Vector2(0, 760)
	left_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_root.add_theme_constant_override("separation", 12)
	left_scroll.add_child(left_root)
	_camp_unit_info_left_root = left_root

	var core_status := Label.new()
	_camp_style_label(core_status, CAMP_BORDER, 22, 2)
	core_status.text = "Core Status"
	left_root.add_child(core_status)

	var primary_root := VBoxContainer.new()
	primary_root.add_theme_constant_override("separation", 10)
	left_root.add_child(primary_root)
	_camp_unit_info_primary_widgets.clear()
	for bar_def in _camp_unit_info_primary_bar_definitions():
		var bar_key: String = str(bar_def.get("key", ""))
		var block := Panel.new()
		block.custom_minimum_size = Vector2(0, 108)
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_camp_style_panel(block, Color(0.10, 0.09, 0.07, 0.90), CAMP_BORDER_SOFT, 10, 4)
		primary_root.add_child(block)

		var block_box := VBoxContainer.new()
		block_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		block_box.add_theme_constant_override("separation", 6)
		block.add_child(block_box)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		block_box.add_child(row)

		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var value_chip := Panel.new()
		value_chip.custom_minimum_size = Vector2(118, 32)
		row.add_child(value_chip)

		var value_label := Label.new()
		value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 2)
		value_chip.add_child(value_label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 20)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block_box.add_child(bar)

		var desc_label := Label.new()
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(0, 32)
		block_box.add_child(desc_label)

		var sheen := _attach_unit_info_bar_sheen(bar)
		_camp_unit_info_primary_widgets[bar_key] = {
			"panel": block,
			"name": name_label,
			"value_chip": value_chip,
			"value": value_label,
			"bar": bar,
			"desc": desc_label,
			"sheen": sheen,
		}

	var combat_profile := Label.new()
	_camp_style_label(combat_profile, CAMP_BORDER, 22, 2)
	combat_profile.text = "Combat Profile"
	left_root.add_child(combat_profile)

	var stat_root := GridContainer.new()
	stat_root.columns = 1
	stat_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_root.add_theme_constant_override("v_separation", 12)
	left_root.add_child(stat_root)
	_camp_unit_info_stat_widgets.clear()
	for stat_def in _camp_unit_info_stat_definitions():
		var stat_key: String = str(stat_def.get("key", ""))
		var stat_block := Panel.new()
		stat_block.custom_minimum_size = Vector2(0, 154)
		stat_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_camp_style_panel(stat_block, Color(0.10, 0.09, 0.07, 0.88), CAMP_BORDER_SOFT, 10, 4)
		stat_root.add_child(stat_block)

		var stat_box := VBoxContainer.new()
		stat_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		stat_box.add_theme_constant_override("separation", 10)
		stat_block.add_child(stat_box)

		var stat_row := HBoxContainer.new()
		stat_row.add_theme_constant_override("separation", 12)
		stat_box.add_child(stat_row)

		var stat_name := Label.new()
		stat_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_row.add_child(stat_name)

		var stat_hints := HBoxContainer.new()
		stat_hints.add_theme_constant_override("separation", 5)
		stat_row.add_child(stat_hints)

		var value_chip := Panel.new()
		value_chip.custom_minimum_size = Vector2(118, 38)
		stat_row.add_child(value_chip)

		var value_label := Label.new()
		value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 1)
		value_chip.add_child(value_label)

		var stat_bar := ProgressBar.new()
		stat_bar.custom_minimum_size = Vector2(0, 20)
		stat_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_box.add_child(stat_bar)

		var stat_desc := Label.new()
		stat_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stat_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_desc.custom_minimum_size = Vector2(0, 54)
		stat_box.add_child(stat_desc)

		var sheen := _attach_unit_info_bar_sheen(stat_bar)
		_camp_unit_info_stat_widgets[stat_key] = {
			"panel": stat_block,
			"name": stat_name,
			"hints": stat_hints,
			"value_chip": value_chip,
			"value": value_label,
			"bar": stat_bar,
			"desc": stat_desc,
			"sheen": sheen,
		}

	var right_scroll := ScrollContainer.new()
	right_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	right_panel.add_child(right_scroll)
	_camp_style_scroll(right_scroll)
	_camp_unit_info_right_scroll = right_scroll

	var right_root := VBoxContainer.new()
	right_root.custom_minimum_size = Vector2(0, 760)
	right_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_root.add_theme_constant_override("separation", 12)
	right_scroll.add_child(right_root)
	_camp_unit_info_right_root = right_root

	var growth_title := Label.new()
	_camp_style_label(growth_title, CAMP_BORDER, 22, 2)
	growth_title.text = "Growth Outlook"
	right_root.add_child(growth_title)

	var growth_root := VBoxContainer.new()
	growth_root.add_theme_constant_override("separation", 8)
	right_root.add_child(growth_root)
	_camp_unit_info_growth_widgets.clear()
	for growth_key in ["hp", "strength", "magic", "defense", "resistance", "speed", "agility"]:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(0, 60)
		_camp_style_panel(panel, Color(0.10, 0.09, 0.07, 0.84), CAMP_BORDER_SOFT, 10, 4)
		growth_root.add_child(panel)

		var panel_box := VBoxContainer.new()
		panel_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		panel_box.add_theme_constant_override("separation", 5)
		panel.add_child(panel_box)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		panel_box.add_child(row)

		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var value_chip := Panel.new()
		value_chip.custom_minimum_size = Vector2(96, 24)
		row.add_child(value_chip)

		var value_label := Label.new()
		value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 1)
		value_chip.add_child(value_label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 14)
		panel_box.add_child(bar)

		var sheen := _attach_unit_info_bar_sheen(bar)
		_camp_unit_info_growth_widgets[growth_key] = {
			"panel": panel,
			"name": name_label,
			"value_chip": value_chip,
			"value": value_label,
			"bar": bar,
			"sheen": sheen,
		}

	var bond_title := Label.new()
	_camp_style_label(bond_title, CAMP_BORDER, 22, 2)
	bond_title.text = "Bond Network"
	right_root.add_child(bond_title)

	_camp_unit_info_relationships_root = VBoxContainer.new()
	_camp_unit_info_relationships_root.add_theme_constant_override("separation", 10)
	right_root.add_child(_camp_unit_info_relationships_root)

	var record_title := Label.new()
	_camp_style_label(record_title, CAMP_BORDER, 22, 2)
	record_title.text = "Field Record"
	right_root.add_child(record_title)

	_camp_unit_info_record_text = RichTextLabel.new()
	_camp_unit_info_record_text.custom_minimum_size = Vector2(0, 320)
	_camp_style_dossier_richtext(_camp_unit_info_record_text, 20)
	right_root.add_child(_camp_unit_info_record_text)

	_layout_camp_detailed_unit_info_panel()

func _layout_camp_detailed_unit_info_panel() -> void:
	if unit_info_panel == null:
		return
	var view_size := get_viewport_rect().size
	if view_size.x < 100.0 or view_size.y < 100.0:
		return
	if _camp_unit_info_dimmer != null:
		_camp_unit_info_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _camp_unit_info_root == null or not is_instance_valid(_camp_unit_info_root):
		return
	var panel_size := Vector2(minf(view_size.x * 0.88, 1400.0), minf(view_size.y * 0.88, 940.0))
	var panel_pos := (view_size - panel_size) * 0.5
	_camp_set_rect(unit_info_panel, panel_pos, panel_size)
	if _camp_unit_info_left_root != null and _camp_unit_info_left_scroll != null:
		_camp_unit_info_left_root.custom_minimum_size.x = maxf(0.0, _camp_unit_info_left_scroll.size.x - 18.0)
	if _camp_unit_info_right_root != null and _camp_unit_info_right_scroll != null:
		_camp_unit_info_right_root.custom_minimum_size.x = maxf(0.0, _camp_unit_info_right_scroll.size.x - 18.0)

func _refresh_camp_unit_info_growth_widgets(growth_totals: Dictionary, animate: bool, tween: Tween = null) -> void:
	var index := 0
	for stat_key in ["hp", "strength", "magic", "defense", "resistance", "speed", "agility"]:
		if not _camp_unit_info_growth_widgets.has(stat_key):
			continue
		var widgets: Dictionary = _camp_unit_info_growth_widgets[stat_key]
		var panel := widgets.get("panel") as Panel
		var name_label := widgets.get("name") as Label
		var value_chip := widgets.get("value_chip") as Panel
		var value_label := widgets.get("value") as Label
		var bar := widgets.get("bar") as ProgressBar
		var sheen := widgets.get("sheen") as ColorRect
		var growth_value: int = int(growth_totals.get(stat_key, 0))
		var fill_color := _camp_unit_info_stat_fill_color(stat_key, growth_value)
		if name_label != null:
			name_label.text = _camp_unit_info_growth_label(stat_key)
			_camp_style_label(name_label, fill_color, 15, 2)
		if value_chip != null:
			_camp_style_panel(value_chip, Color(0.10, 0.09, 0.07, 0.98), fill_color.lightened(0.10), 6, 3)
		if value_label != null:
			value_label.text = "%d%%" % growth_value
			_camp_style_label(value_label, CAMP_TEXT, 14, 1)
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if panel != null:
			_camp_style_panel(panel, Color(0.10, 0.09, 0.07, 0.84), fill_color if growth_value > 0 else CAMP_BORDER_SOFT, 10, 4)
		if bar != null:
			bar.max_value = 100.0
			_camp_style_unit_info_stat_bar(bar, fill_color, growth_value >= 50)
			var target := clampf(float(growth_value), 0.0, 100.0)
			if not animate or tween == null:
				bar.value = target
			else:
				bar.value = 0.0
				var delay := 0.08 + float(index) * 0.03
				if panel != null:
					panel.modulate = Color(1, 1, 1, 0)
					tween.tween_property(panel, "modulate", Color.WHITE, 0.14).set_delay(delay)
				tween.tween_property(bar, "value", target, 0.24).set_delay(delay)
				if sheen != null:
					_animate_unit_info_bar_sheen(sheen, bar, delay + 0.03)
		index += 1

func _ensure_camp_cards() -> void:
	if _camp_cards_layer == null or not is_instance_valid(_camp_cards_layer):
		_camp_cards_layer = Control.new()
		_camp_cards_layer.name = "CampCardsLayer"
		_camp_cards_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_camp_cards_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_camp_cards_layer)
		if background_texture != null:
			move_child(_camp_cards_layer, background_texture.get_index() + 1)
	for card_name in ["roster", "commander", "inventory", "merchant", "shop", "nav"]:
		if not _camp_cards.has(card_name) or not is_instance_valid(_camp_cards[card_name]):
			var card := Panel.new()
			card.name = "CampCard_%s" % card_name
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_camp_cards_layer.add_child(card)
			_camp_cards[card_name] = card

func _ensure_camp_detail_scroll_wrappers() -> void:
	if inventory_desc != null and (_inventory_desc_scroll == null or not is_instance_valid(_inventory_desc_scroll)):
		_inventory_desc_scroll = ScrollContainer.new()
		_inventory_desc_scroll.name = "InventoryDescScroll"
		_inventory_desc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_inventory_desc_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_inventory_desc_scroll)
		if inventory_desc.get_parent() != null:
			inventory_desc.get_parent().remove_child(inventory_desc)
		_inventory_desc_scroll.add_child(inventory_desc)
	if shop_desc != null and (_shop_desc_scroll == null or not is_instance_valid(_shop_desc_scroll)):
		_shop_desc_scroll = ScrollContainer.new()
		_shop_desc_scroll.name = "ShopDescScroll"
		_shop_desc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_shop_desc_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_shop_desc_scroll)
		if shop_desc.get_parent() != null:
			shop_desc.get_parent().remove_child(shop_desc)
		_shop_desc_scroll.add_child(shop_desc)

## Positions commander-column stats, mid-row buttons, portrait, and footer actions inside the commander card.
## Stats height: `get_content_height()` often under-reports BBCode stacks; we blend it with a small floor and cap,
## then shrink further if the portrait band would be shorter than `portrait_min_h`.
## Portrait: `KEEP_ASPECT_CENTERED` keeps the full bust visible in a wide frame (no head-chop from COVERED crop).
func _layout_camp_commander_column() -> void:
	if _camp_commander_card.size.x < 10.0 or _camp_commander_card.size.y < 10.0:
		return
	var left_x: float = _camp_commander_card.position.x
	var commander_y: float = _camp_commander_card.position.y
	var left_w: float = _camp_commander_card.size.x
	var commander_h: float = _camp_commander_card.size.y

	var stats_pad_top := 10.0
	var gap_after_stats := 8.0
	var mid_row_h := 40.0
	var gap_before_portrait := 8.0
	var footer_reserve := 62.0
	var footer_gap := 12.0
	var portrait_min_h := 148.0
	var stats_h_min := 88.0
	var stats_h_max := 178.0
	# Rough visual floor for name + Lv + HP + class + weapon (single-line weapon); avoids empty band when `get_content_height()` is low.
	var stats_visual_floor := 136.0

	var commander_bottom_y: float = commander_y + commander_h - footer_reserve
	var portrait_max_bottom: float = commander_bottom_y - footer_gap

	var stats_w := left_w - 44.0
	var stats_h := 168.0
	if stats_label != null:
		# Wide temporary height so wrapped BBCode measures correctly at final width.
		_camp_set_rect(stats_label, Vector2(left_x + 22.0, commander_y + stats_pad_top), Vector2(stats_w, 900.0))
		var raw_content_h: float = stats_label.get_content_height()
		stats_h = clampf(raw_content_h + 12.0, stats_h_min, stats_h_max)
		if raw_content_h < 72.0:
			stats_h = maxf(stats_h, stats_visual_floor)
		var tentative_mid_y: float = commander_y + stats_pad_top + stats_h + gap_after_stats
		var tentative_portrait_y: float = tentative_mid_y + mid_row_h + gap_before_portrait
		var tentative_portrait_h: float = portrait_max_bottom - tentative_portrait_y
		while tentative_portrait_h < portrait_min_h and stats_h > stats_h_min + 1.0:
			stats_h -= 6.0
			tentative_mid_y = commander_y + stats_pad_top + stats_h + gap_after_stats
			tentative_portrait_y = tentative_mid_y + mid_row_h + gap_before_portrait
			tentative_portrait_h = portrait_max_bottom - tentative_portrait_y
		_camp_set_rect(stats_label, Vector2(left_x + 22.0, commander_y + stats_pad_top), Vector2(stats_w, stats_h))
		stats_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	var commander_top_button_y := commander_y + stats_pad_top + stats_h + gap_after_stats
	var commander_top_button_w := (left_w - 56.0) / 2.0
	if swap_ability_btn != null:
		_camp_set_rect(swap_ability_btn, Vector2(left_x + 22.0, commander_top_button_y), Vector2(commander_top_button_w, mid_row_h))
	if jukebox_btn != null:
		_camp_set_rect(jukebox_btn, Vector2(left_x + 34.0 + commander_top_button_w, commander_top_button_y), Vector2(commander_top_button_w, mid_row_h))

	var portrait_frame_y: float = commander_top_button_y + mid_row_h + gap_before_portrait
	var portrait_frame_h: float = maxf(1.0, portrait_max_bottom - portrait_frame_y)

	if portrait_panel != null:
		_camp_set_rect(portrait_panel, Vector2(left_x + 44.0, portrait_frame_y), Vector2(left_w - 88.0, portrait_frame_h))
	if portrait_rect != null:
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var inset := 8.0
		_camp_set_rect(
			portrait_rect,
			Vector2(left_x + 44.0 + inset, portrait_frame_y + inset),
			Vector2(left_w - 88.0 - inset * 2.0, maxf(64.0, portrait_frame_h - inset * 2.0))
		)

	var commander_bottom_w := (left_w - 56.0) / 2.0
	if inspect_unit_btn != null:
		_camp_set_rect(inspect_unit_btn, Vector2(left_x + 22.0, commander_bottom_y), Vector2(commander_bottom_w, 44.0))
	if open_save_menu_btn != null:
		_camp_set_rect(open_save_menu_btn, Vector2(left_x + 34.0 + commander_bottom_w, commander_bottom_y), Vector2(commander_bottom_w, 44.0))


func _camp_apply_ui_overhaul() -> void:
	_ensure_camp_cards()
	_ensure_camp_detail_scroll_wrappers()
	_ensure_camp_save_records_popup()
	_ensure_camp_jukebox_modal()
	var view_size := get_viewport_rect().size
	if view_size.x < 100.0 or view_size.y < 100.0:
		return

	var margin := 38.0
	var gap := 24.0
	var left_w := clampf(view_size.x * 0.22, 360.0, 430.0)
	var right_w := clampf(view_size.x * 0.23, 400.0, 460.0)
	var center_w := view_size.x - margin * 2.0 - left_w - right_w - gap * 2.0
	if center_w < 760.0:
		var deficit := 760.0 - center_w
		right_w = max(360.0, right_w - deficit * 0.45)
		left_w = max(330.0, left_w - deficit * 0.30)
		center_w = view_size.x - margin * 2.0 - left_w - right_w - gap * 2.0

	var left_x := margin
	var center_x := left_x + left_w + gap
	var right_x := center_x + center_w + gap
	var top_y := 34.0
	var roster_h := clampf(view_size.y * 0.33, 320.0, 370.0)
	var merchant_h := clampf(view_size.y * 0.34, 340.0, 390.0)
	var nav_h := 148.0
	var nav_y := view_size.y - nav_h - 30.0
	var side_bottom_y := view_size.y - 34.0
	var commander_y := top_y + roster_h + gap
	var commander_h := nav_y - commander_y - gap
	var inventory_h := nav_y - top_y - gap
	var shop_y := top_y + merchant_h + gap
	var shop_h := side_bottom_y - shop_y
	var nav_w := minf(center_w, 840.0)
	var nav_x := center_x + (center_w - nav_w) / 2.0

	var card_styles := {
		"roster": _camp_make_panel_style(CAMP_PANEL_BG, CAMP_BORDER),
		"commander": _camp_make_panel_style(CAMP_PANEL_BG, CAMP_BORDER),
		"inventory": _camp_make_panel_style(CAMP_PANEL_BG_ALT, CAMP_BORDER),
		"merchant": _camp_make_panel_style(CAMP_PANEL_BG, CAMP_BORDER),
		"shop": _camp_make_panel_style(CAMP_PANEL_BG_ALT, CAMP_BORDER_SOFT),
		"nav": _camp_make_panel_style(CAMP_PANEL_BG_ALT, CAMP_BORDER)
	}
	var card_rects := {
		"roster": Rect2(left_x, top_y, left_w, roster_h),
		"commander": Rect2(left_x, commander_y, left_w, commander_h),
		"inventory": Rect2(center_x, top_y, center_w, inventory_h),
		"merchant": Rect2(right_x, top_y, right_w, merchant_h),
		"shop": Rect2(right_x, shop_y, right_w, shop_h),
		"nav": Rect2(nav_x, nav_y, nav_w, nav_h)
	}
	for card_name in card_rects.keys():
		var card: Panel = _camp_cards[card_name]
		card.add_theme_stylebox_override("panel", card_styles[card_name])
		var rect: Rect2 = card_rects[card_name]
		_camp_set_rect(card, rect.position, rect.size)

	_camp_commander_card = Rect2(left_x, commander_y, left_w, commander_h)

	if background_texture != null:
		background_texture.modulate = Color(1, 1, 1, 0.32)

	_camp_style_section_badge(roster_header_button, "ROSTER DOSSIER", CAMP_ACCENT_GREEN)
	_camp_style_section_badge(inventory_header_button, "QUARTERMASTER", CAMP_BORDER)
	_camp_style_section_badge(merchant_header_button, "MERCHANT STOCK", CAMP_ACCENT_GREEN)

	_camp_style_rich_label(stats_label, 20, Color(0.07, 0.06, 0.04, 0.88), CAMP_BORDER_SOFT)
	_camp_style_rich_label(inventory_desc, CAMP_QM_DESC_FONT_SIZE, Color(0.08, 0.06, 0.04, 0.88), CAMP_BORDER_SOFT, false)
	if inventory_desc is RichTextLabel:
		var inv_rtl: RichTextLabel = inventory_desc as RichTextLabel
		var inv_panel: StyleBox = inv_rtl.get_theme_stylebox("normal")
		if inv_panel != null and inv_panel is StyleBoxFlat:
			var inv_st: StyleBoxFlat = (inv_panel as StyleBoxFlat).duplicate() as StyleBoxFlat
			inv_st.content_margin_left = CAMP_QM_DESC_STYLE_MARGIN_H
			inv_st.content_margin_right = CAMP_QM_DESC_STYLE_MARGIN_H
			inv_st.content_margin_top = CAMP_QM_DESC_STYLE_MARGIN_V
			inv_st.content_margin_bottom = CAMP_QM_DESC_STYLE_MARGIN_V
			inv_rtl.add_theme_stylebox_override("normal", inv_st)
		inv_rtl.add_theme_constant_override("line_separation", 3)
		# Avoid heavy bold glyph (same face as body — easier to read on pixel fonts).
		var inv_nf: Font = inv_rtl.get_theme_font("normal_font")
		if inv_nf != null:
			inv_rtl.add_theme_font_override("bold_font", inv_nf)
	_camp_style_rich_label(shop_desc, 16, Color(0.08, 0.06, 0.04, 0.88), CAMP_BORDER_SOFT, false)
	_camp_style_rich_label(merchant_label, 18, Color(0.08, 0.06, 0.04, 0.90), CAMP_BORDER)

	_camp_style_scroll(roster_scroll)
	_camp_style_scroll(inv_scroll)
	_camp_style_scroll(shop_scroll)
	_camp_style_scroll(_inventory_desc_scroll)
	_camp_style_scroll(_shop_desc_scroll)
	_camp_style_tabs(category_tabs)

	if portrait_panel != null:
		portrait_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_panel.add_theme_stylebox_override("panel", _camp_make_panel_style(Color(0.08, 0.06, 0.04, 0.92), CAMP_BORDER_SOFT, 22, 0))
	if merchant_frame != null:
		merchant_frame.visible = false

	if gold_label != null:
		gold_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.32, 1.0))
		gold_label.add_theme_font_size_override("font_size", 22)
		gold_label.add_theme_constant_override("outline_size", 2)
		gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	if roster_header_button != null:
		_camp_set_rect(roster_header_button, Vector2(left_x + 22.0, top_y + 16.0), Vector2(left_w - 44.0, 28.0))
	if roster_scroll != null:
		_camp_set_rect(roster_scroll, Vector2(left_x + 22.0, top_y + 54.0), Vector2(left_w - 44.0, roster_h - 126.0))
	if roster_grid != null:
		roster_grid.columns = 4

	if open_ranch_btn != null:
		open_ranch_btn.text = "Dragon Ranch"
		_camp_style_button(open_ranch_btn, false, 18, 42.0)
	if open_skills_btn != null:
		open_skills_btn.text = "Skill Tree"
		_camp_style_button(open_skills_btn, false, 18, 42.0)
	var top_left_button_y := top_y + roster_h - 60.0
	var top_left_button_w := (left_w - 56.0) / 2.0
	_camp_set_rect(open_ranch_btn, Vector2(left_x + 22.0, top_left_button_y), Vector2(top_left_button_w, 42.0))
	_camp_set_rect(open_skills_btn, Vector2(left_x + 34.0 + top_left_button_w, top_left_button_y), Vector2(top_left_button_w, 42.0))

	if swap_ability_btn != null:
		swap_ability_btn.text = "Swap Ability"
		_camp_style_button(swap_ability_btn, false, 17, 40.0)
	if jukebox_btn != null:
		jukebox_btn.text = "Jukebox"
		_camp_style_button(jukebox_btn, false, 17, 40.0)
	if inspect_unit_btn != null:
		inspect_unit_btn.text = "Unit Dossier"
		_camp_style_button(inspect_unit_btn, false, 18, 44.0)
	if open_save_menu_btn != null:
		open_save_menu_btn.text = "Save Records"
		_camp_style_button(open_save_menu_btn, false, 18, 44.0)
	_layout_camp_commander_column()

	var inv_card_pad := 22.0
	var inv_col_gap := 20.0
	var inv_content_w: float = center_w - inv_card_pad * 2.0
	# Wide readout uses horizontal space; keep grid ≥ ~304px for five slots.
	var inventory_detail_w: float = clampf(inv_content_w * 0.48, 352.0, 520.0)
	var inventory_detail_x: float = center_x + inv_card_pad
	var inventory_grid_x: float = inventory_detail_x + inventory_detail_w + inv_col_gap
	var inventory_grid_w: float = center_x + center_w - inv_card_pad - inventory_grid_x
	if inventory_grid_w < 304.0:
		var grid_short: float = 304.0 - inventory_grid_w
		inventory_detail_w = maxf(312.0, inventory_detail_w - grid_short)
		inventory_grid_x = inventory_detail_x + inventory_detail_w + inv_col_gap
		inventory_grid_w = center_x + center_w - inv_card_pad - inventory_grid_x
	if inventory_header_button != null:
		_camp_set_rect(inventory_header_button, Vector2(center_x + 22.0, top_y + 16.0), Vector2(240.0, 28.0))
	if sort_button != null:
		sort_button.text = "Sort"
		_camp_style_button(sort_button, false, 16, 36.0)
		_camp_set_rect(sort_button, Vector2(inventory_grid_x, top_y + 16.0), Vector2(82.0, 36.0))
	if category_tabs != null:
		_camp_set_rect(category_tabs, Vector2(inventory_grid_x + 92.0, top_y + 16.0), Vector2(inventory_grid_w - 92.0, 38.0))
	var inventory_desc_y := top_y + 72.0
	var gold_row_y := top_y + inventory_h - 62.0
	_camp_qm_detail_x = inventory_detail_x
	_camp_qm_detail_w = inventory_detail_w
	_camp_qm_desc_y = inventory_desc_y
	# Leave room for two button rows + gaps before the gold strip.
	_camp_qm_desc_max_h = maxf(96.0, gold_row_y - inventory_desc_y - 126.0)
	if _inventory_desc_scroll != null:
		_camp_set_rect(
			_inventory_desc_scroll,
			Vector2(inventory_detail_x, inventory_desc_y),
			Vector2(inventory_detail_w, minf(200.0, _camp_qm_desc_max_h))
		)
	if inventory_desc != null and _inventory_desc_scroll != null:
		inventory_desc.layout_mode = 2
		inventory_desc.position = Vector2.ZERO
		inventory_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inventory_desc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		inventory_desc.custom_minimum_size = Vector2.ZERO
		inventory_desc.fit_content = true
		inventory_desc.scroll_active = false
		inventory_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if equip_button != null:
		_camp_style_button(equip_button, false, 18, 44.0)
	if unequip_button != null:
		_camp_style_button(unequip_button, false, 18, 44.0)
	if use_button != null:
		_camp_style_button(use_button, false, 18, 44.0)
	if sell_button != null:
		_camp_style_button(sell_button, false, 18, 44.0)
	_queue_refit_quartermaster_item_panel()
	if gold_label != null:
		_camp_set_rect(gold_label, Vector2(inventory_detail_x, top_y + inventory_h - 62.0), Vector2(inventory_detail_w, 36.0))
	if inv_scroll != null:
		_camp_set_rect(inv_scroll, Vector2(inventory_grid_x, top_y + 68.0), Vector2(inventory_grid_w, inventory_h - 92.0))
	if unit_grid != null:
		unit_grid.columns = 5
	if convoy_grid != null:
		convoy_grid.columns = 5

	if open_blacksmith_btn != null:
		open_blacksmith_btn.text = "Blacksmith"
		_camp_style_button(open_blacksmith_btn, false, 17, 42.0)
	if haggle_button != null:
		haggle_button.text = "Haggle"
		_camp_style_button(haggle_button, false, 17, 42.0)
	if talk_button != null:
		talk_button.text = "Talk"
		_camp_style_button(talk_button, false, 17, 42.0)
	var merchant_button_gap := 10.0
	var merchant_button_w := (right_w - 48.0 - merchant_button_gap * 2.0) / 3.0
	var merchant_buttons_y := top_y + 18.0
	_camp_set_rect(open_blacksmith_btn, Vector2(right_x + 24.0, merchant_buttons_y), Vector2(merchant_button_w, 42.0))
	_camp_set_rect(haggle_button, Vector2(right_x + 24.0 + merchant_button_w + merchant_button_gap, merchant_buttons_y), Vector2(merchant_button_w, 42.0))
	_camp_set_rect(talk_button, Vector2(right_x + 24.0 + (merchant_button_w + merchant_button_gap) * 2.0, merchant_buttons_y), Vector2(merchant_button_w, 42.0))

	_camp_set_rect(merchant_portrait, Vector2(right_x + 42.0, top_y + 78.0), Vector2(right_w - 84.0, 172.0))
	_camp_set_rect(merchant_label, Vector2(right_x + 24.0, top_y + 266.0), Vector2(right_w - 48.0, merchant_h - 288.0))

	if merchant_header_button != null:
		_camp_set_rect(merchant_header_button, Vector2(right_x + 22.0, shop_y + 16.0), Vector2(220.0, 28.0))
	var buy_button_h := 44.0
	var buy_button_y := shop_y + shop_h - 54.0
	var shop_desc_h := 166.0
	var shop_desc_gap := 46.0
	var shop_desc_y := buy_button_y - shop_desc_gap - shop_desc_h
	var shop_scroll_top := shop_y + 54.0
	var shop_scroll_h := maxf(120.0, shop_desc_y - shop_scroll_top - 12.0)
	if shop_scroll != null:
		_camp_set_rect(shop_scroll, Vector2(right_x + 24.0, shop_scroll_top), Vector2(right_w - 48.0, shop_scroll_h))
	if shop_grid != null:
		shop_grid.columns = 4
	if _shop_desc_scroll != null:
		_camp_set_rect(_shop_desc_scroll, Vector2(right_x + 24.0, shop_desc_y), Vector2(right_w - 48.0, shop_desc_h))
	if shop_desc != null and _shop_desc_scroll != null:
		_camp_set_rect(shop_desc, Vector2.ZERO, Vector2(right_w - 62.0, shop_desc_h))
		shop_desc.fit_content = true
		shop_desc.custom_minimum_size = Vector2(right_w - 62.0, 0.0)
	if buy_button != null:
		buy_button.top_level = false
		buy_button.z_index = 1
		buy_button.text = "Buy"
		_camp_style_button(buy_button, true, 18, 44.0)
		_camp_set_rect(buy_button, Vector2(right_x + 24.0, buy_button_y), Vector2(right_w - 48.0, buy_button_h))

	if next_battle_button != null:
		_camp_style_button(next_battle_button, true, 28, 58.0)
		_camp_set_rect(next_battle_button, Vector2(nav_x + 24.0, nav_y + 18.0), Vector2(nav_w - 48.0, 58.0))
	if world_map_button != null:
		_camp_style_button(world_map_button, false, 20, 44.0)
	if explore_camp_btn != null:
		_camp_style_button(explore_camp_btn, false, 20, 44.0)
	if _task_log_button != null:
		_task_log_button.text = "Tasks"
		_camp_style_button(_task_log_button, false, 20, 44.0)
	if _camp_unit_info_root != null and is_instance_valid(_camp_unit_info_root):
		_layout_camp_detailed_unit_info_panel()
	_layout_camp_save_records_popup()
	_layout_camp_jukebox_panel()

	var nav_secondary: Array[Control] = []
	if world_map_button != null and world_map_button.visible:
		nav_secondary.append(world_map_button)
	if explore_camp_btn != null and explore_camp_btn.visible:
		nav_secondary.append(explore_camp_btn)
	if _task_log_button != null:
		nav_secondary.append(_task_log_button)
	var secondary_gap := 14.0
	var secondary_width := minf(220.0, (nav_w - 48.0 - secondary_gap * maxf(float(nav_secondary.size() - 1), 0.0)) / maxf(float(nav_secondary.size()), 1.0))
	var total_secondary_width := secondary_width * nav_secondary.size() + secondary_gap * maxf(float(nav_secondary.size() - 1), 0.0)
	var secondary_x := nav_x + (nav_w - total_secondary_width) / 2.0
	for nav_button in nav_secondary:
		_camp_set_rect(nav_button, Vector2(secondary_x, nav_y + 88.0), Vector2(secondary_width, 44.0))
		secondary_x += secondary_width + secondary_gap

	_ensure_haggle_walk_away_button()
	_style_haggle_minigame_chrome()
	if not haggle_active:
		_camp_layout_haggle_panel()
	_sync_haggle_button_availability()
	_camp_layout_blacksmith_panel()
	if _blacksmith_dimmer != null and _blacksmith_dimmer.visible:
		_camp_layout_blacksmith_dimmer()
	_camp_layout_merchant_talk_panel()
	_sync_merchant_talk_button_state()


func _ensure_blacksmith_dimmer() -> void:
	if _blacksmith_dimmer != null and is_instance_valid(_blacksmith_dimmer):
		return
	_blacksmith_dimmer = ColorRect.new()
	_blacksmith_dimmer.name = "BlacksmithCampDimmer"
	_blacksmith_dimmer.color = Color(0.02, 0.014, 0.01, 0.82)
	_blacksmith_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_blacksmith_dimmer.z_index = 70
	_blacksmith_dimmer.visible = false
	add_child(_blacksmith_dimmer)
	if blacksmith_panel != null:
		move_child(_blacksmith_dimmer, blacksmith_panel.get_index())


func _camp_layout_blacksmith_dimmer() -> void:
	if _blacksmith_dimmer == null or not is_instance_valid(_blacksmith_dimmer):
		return
	var vs: Vector2 = get_viewport_rect().size
	_camp_set_rect(_blacksmith_dimmer, Vector2.ZERO, vs)


func _ensure_blacksmith_chrome_labels() -> void:
	if blacksmith_panel == null:
		return
	if _blacksmith_title_lbl == null:
		_blacksmith_title_lbl = Label.new()
		_blacksmith_title_lbl.name = "BlacksmithForgeTitle"
		_blacksmith_title_lbl.text = "HALDOR'S FORGE"
		_blacksmith_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		blacksmith_panel.add_child(_blacksmith_title_lbl)
	if _blacksmith_hdr_materials == null:
		_blacksmith_hdr_materials = Label.new()
		_blacksmith_hdr_materials.name = "BlacksmithHdrMaterials"
		_blacksmith_hdr_materials.text = "CONVOY MATERIALS"
		blacksmith_panel.add_child(_blacksmith_hdr_materials)
	if _blacksmith_hdr_deployment == null:
		_blacksmith_hdr_deployment = Label.new()
		_blacksmith_hdr_deployment.name = "BlacksmithHdrDeployment"
		_blacksmith_hdr_deployment.text = "DEPLOYMENT STOCK"
		_blacksmith_hdr_deployment.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		blacksmith_panel.add_child(_blacksmith_hdr_deployment)
	if _blacksmith_hdr_preview == null:
		_blacksmith_hdr_preview = Label.new()
		_blacksmith_hdr_preview.name = "BlacksmithHdrPreview"
		_blacksmith_hdr_preview.text = "OUTCOME"
		_blacksmith_hdr_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		blacksmith_panel.add_child(_blacksmith_hdr_preview)
	if _blacksmith_runesmith_status_lbl == null:
		_blacksmith_runesmith_status_lbl = Label.new()
		_blacksmith_runesmith_status_lbl.name = "BlacksmithRunesmithStatus"
		_blacksmith_runesmith_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_blacksmith_runesmith_status_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_blacksmith_runesmith_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blacksmith_panel.add_child(_blacksmith_runesmith_status_lbl)
	_camp_style_label(_blacksmith_title_lbl, CAMP_BORDER, 28, 2)
	_camp_style_label(_blacksmith_hdr_materials, CAMP_MUTED, 18, 1)
	_camp_style_label(_blacksmith_hdr_deployment, CAMP_MUTED, 18, 1)
	_camp_style_label(_blacksmith_hdr_preview, CAMP_MUTED, 18, 1)
	_camp_style_label(_blacksmith_runesmith_status_lbl, CAMP_MUTED, 16, 1)
	for lbl in [_blacksmith_title_lbl, _blacksmith_hdr_materials, _blacksmith_hdr_deployment, _blacksmith_hdr_preview, _blacksmith_runesmith_status_lbl]:
		if lbl != null:
			lbl.z_index = 24
	_refresh_blacksmith_runesmith_status_label()


func _runesmithing_forge_status_text() -> String:
	var t: int = CampaignManager.get_runesmithing_unlock_tier()
	if t >= CampaignManager.RUNESMITHING_TIER_ADVANCED:
		return "Runesmithing: advanced tier available."
	if t >= CampaignManager.RUNESMITHING_TIER_BASIC:
		return "Runesmithing: basic tier available."
	return "Runesmithing: locked (unlocks via campaign progression)."


func _refresh_blacksmith_runesmith_status_label() -> void:
	_update_blacksmith_runesmith_status_label()


func _update_blacksmith_runesmith_status_label() -> void:
	if _blacksmith_runesmith_status_lbl == null or not is_instance_valid(_blacksmith_runesmith_status_lbl):
		return
	var new_text: String = _runesmithing_forge_status_text()
	var old_text: String = _blacksmith_runesmith_status_lbl.text
	_blacksmith_runesmith_status_lbl.text = new_text
	var forge_visible: bool = (
		blacksmith_panel != null
		and is_instance_valid(blacksmith_panel)
		and blacksmith_panel.visible
	)
	if not forge_visible or new_text == old_text:
		return
	_play_blacksmith_runesmith_status_emphasis()


func _play_blacksmith_runesmith_status_emphasis() -> void:
	if _blacksmith_runesmith_status_lbl == null or not is_instance_valid(_blacksmith_runesmith_status_lbl):
		return
	if _blacksmith_runesmith_status_tween != null and _blacksmith_runesmith_status_tween.is_valid():
		_blacksmith_runesmith_status_tween.kill()
	_blacksmith_runesmith_status_tween = null
	_blacksmith_runesmith_status_lbl.modulate = Color.WHITE
	var tw: Tween = create_tween()
	_blacksmith_runesmith_status_tween = tw
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(
		_blacksmith_runesmith_status_lbl,
		"modulate",
		Color(1.11, 1.06, 0.95, 1.0),
		0.1
	)
	tw.tween_property(
		_blacksmith_runesmith_status_lbl,
		"modulate",
		Color.WHITE,
		0.3
	)
	var tw_done: Tween = tw
	tw.tween_callback(func():
		if _blacksmith_runesmith_status_tween == tw_done:
			_blacksmith_runesmith_status_tween = null
	)


func _ensure_blacksmith_anvil_plate() -> void:
	if blacksmith_panel == null or anvil_row == null:
		return
	if _blacksmith_anvil_plate != null and is_instance_valid(_blacksmith_anvil_plate):
		return
	_blacksmith_anvil_plate = Panel.new()
	_blacksmith_anvil_plate.name = "AnvilBackingPlate"
	_blacksmith_anvil_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blacksmith_anvil_plate.z_index = 3
	blacksmith_panel.add_child(_blacksmith_anvil_plate)
	move_child(_blacksmith_anvil_plate, anvil_row.get_index())


func _camp_layout_blacksmith_panel() -> void:
	if blacksmith_panel == null or not is_instance_valid(blacksmith_panel):
		return
	var view_size: Vector2 = get_viewport_rect().size
	if view_size.x < 100.0 or view_size.y < 100.0:
		return

	_ensure_blacksmith_chrome_labels()
	_ensure_blacksmith_anvil_plate()
	_ensure_blacksmith_workbench_chrome()

	blacksmith_panel.rotation = 0.0
	blacksmith_panel.z_index = 80
	var margin: float = 22.0
	_camp_set_rect(blacksmith_panel, Vector2(margin, margin), Vector2(view_size.x - margin * 2.0, view_size.y - margin * 2.0))
	if blacksmith_panel is Panel:
		_camp_style_panel(blacksmith_panel as Panel, CAMP_PANEL_BG_ALT, CAMP_BORDER, 22, 12)

	var pw: float = blacksmith_panel.size.x
	var ph: float = blacksmith_panel.size.y
	var pad: float = 18.0
	var left_col_w: float = clampf(pw * 0.20, 268.0, 340.0)
	var right_col_w: float = clampf(pw * 0.22, 260.0, 360.0)
	var mid_x: float = pad + left_col_w + pad
	var mid_w: float = maxf(320.0, pw - mid_x - right_col_w - pad * 2.0)

	var title_y: float = 10.0
	var title_h: float = 40.0
	var rune_line_gap: float = 4.0
	var rune_status_h: float = 30.0
	var row_top: float = title_y + title_h + rune_line_gap + rune_status_h + 8.0
	var sec_h: float = 26.0
	var list_top: float = row_top + sec_h + 6.0
	var bottom_reserve: float = 58.0
	var bp_h: float = clampf(ph * 0.26, 168.0, 248.0)

	if _blacksmith_title_lbl != null:
		_camp_set_rect(_blacksmith_title_lbl, Vector2(pad, title_y), Vector2(pw - pad * 2.0, title_h))
	if _blacksmith_runesmith_status_lbl != null:
		_camp_set_rect(
			_blacksmith_runesmith_status_lbl,
			Vector2(pad, title_y + title_h + rune_line_gap),
			Vector2(pw - pad * 2.0, rune_status_h)
		)
		_refresh_blacksmith_runesmith_status_label()
	if _blacksmith_hdr_materials != null:
		_camp_set_rect(_blacksmith_hdr_materials, Vector2(pad, row_top), Vector2(left_col_w, sec_h))
	if _blacksmith_hdr_deployment != null:
		_camp_set_rect(
			_blacksmith_hdr_deployment,
			Vector2(pw - pad - right_col_w, row_top),
			Vector2(right_col_w, sec_h)
		)

	if material_scroll != null:
		_camp_style_scroll(material_scroll)
		material_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
		material_scroll.z_index = 8
		_camp_set_rect(
			material_scroll,
			Vector2(pad, list_top),
			Vector2(left_col_w, maxf(160.0, ph - list_top - bottom_reserve))
		)
	if material_grid != null:
		material_grid.columns = 4

	if blueprint_stock_panel != null:
		_camp_style_panel(blueprint_stock_panel, CAMP_PANEL_BG_SOFT, CAMP_BORDER_SOFT, 16, 4)
		blueprint_stock_panel.z_index = 8
		_camp_set_rect(
			blueprint_stock_panel,
			Vector2(pw - pad - right_col_w, list_top),
			Vector2(right_col_w, bp_h)
		)
	if blueprint_stock_label != null:
		_camp_style_rich_label(blueprint_stock_label, 20, Color(0.10, 0.074, 0.048, 0.92), CAMP_BORDER_SOFT, true)
		_camp_set_rect(blueprint_stock_label, Vector2(10.0, 10.0), Vector2(right_col_w - 20.0, maxf(40.0, bp_h - 20.0)))

	var portrait_w: float = clampf(mid_w * 0.70, 248.0, 400.0)
	var portrait_h: float = clampf(portrait_w * 0.48, 132.0, 200.0)
	var portrait_x: float = mid_x + (mid_w - portrait_w) * 0.5
	if blacksmith_portrait != null:
		blacksmith_portrait.z_index = 6
		_camp_set_rect(blacksmith_portrait, Vector2(portrait_x, row_top), Vector2(portrait_w, portrait_h))

	var dialogue_y: float = row_top + portrait_h + 10.0
	var dialogue_h: float = clampf(ph * 0.14, 96.0, 148.0)
	if blacksmith_label != null:
		blacksmith_label.z_index = 7
		_camp_style_label(blacksmith_label, CAMP_TEXT, 22, 2)
		blacksmith_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_camp_set_rect(blacksmith_label, Vector2(mid_x + 6.0, dialogue_y), Vector2(mid_w - 12.0, dialogue_h))

	var talk_w: float = 118.0
	if blacksmith_talk_button != null:
		blacksmith_talk_button.z_index = 12
		_camp_style_button(blacksmith_talk_button, false, 19, 42.0)
		_camp_set_rect(
			blacksmith_talk_button,
			Vector2(mid_x + mid_w - talk_w - 6.0, row_top + 2.0),
			Vector2(talk_w, 42.0)
		)

	var anvil_slot: float = clampf(mid_w * 0.095, 84.0, 104.0)
	var anvil_gap: float = 22.0
	var anvil_total_w: float = anvil_slot * 3.0 + anvil_gap * 2.0
	var craft_h: float = 46.0
	var craft_y: float = dialogue_y + dialogue_h + 16.0
	if _blacksmith_workbench_divider != null:
		_blacksmith_workbench_divider.z_index = 5
		_camp_style_panel(
			_blacksmith_workbench_divider,
			Color(0.14, 0.10, 0.065, 0.55),
			Color(0.55, 0.44, 0.20, 0.65),
			2,
			0
		)
		_camp_set_rect(
			_blacksmith_workbench_divider,
			Vector2(mid_x + 10.0, craft_y - 10.0),
			Vector2(mid_w - 20.0, 3.0)
		)
	if craft_button != null:
		craft_button.z_index = 12
		_camp_style_button(craft_button, true, 20, craft_h)
		_camp_set_rect(craft_button, Vector2(mid_x + (mid_w - 172.0) * 0.5, craft_y), Vector2(172.0, craft_h))
	var craft_bottom: float = craft_y + craft_h
	var socket_lbl_gap_after_craft: float = 10.0
	var socket_lbl_h: float = 24.0
	var socket_lbl_y: float = craft_bottom + socket_lbl_gap_after_craft
	var anvil_y: float = socket_lbl_y + socket_lbl_h + 8.0
	if anvil_row != null:
		anvil_row.z_index = 12
		anvil_row.add_theme_constant_override("separation", int(anvil_gap))
		_camp_set_rect(
			anvil_row,
			Vector2(mid_x + (mid_w - anvil_total_w) * 0.5, anvil_y),
			Vector2(anvil_total_w, anvil_slot)
		)
	for s in [slot1, slot2, slot3]:
		if s != null:
			s.custom_minimum_size = Vector2(anvil_slot, anvil_slot)

	var anvil_row_left: float = mid_x + (mid_w - anvil_total_w) * 0.5
	for si in range(_blacksmith_socket_labels.size()):
		var slbl: Label = _blacksmith_socket_labels[si]
		if slbl != null:
			slbl.z_index = 14
			_camp_style_label(slbl, CAMP_BORDER, 18, 1)
			var lbl_w: float = 28.0
			var cx: float = anvil_row_left + si * (anvil_slot + anvil_gap) + anvil_slot * 0.5 - lbl_w * 0.5
			_camp_set_rect(slbl, Vector2(cx, socket_lbl_y), Vector2(lbl_w, socket_lbl_h))
	var hint_strip_pad_h: float = 8.0
	var hint_inner_pad: float = 10.0
	if _blacksmith_anvil_hint_strip != null:
		_blacksmith_anvil_hint_strip.z_index = 11
		_camp_style_panel(
			_blacksmith_anvil_hint_strip,
			Color(0.14, 0.108, 0.072, 0.88),
			Color(0.42, 0.34, 0.18, 0.72),
			12,
			0
		)
		_camp_set_rect(
			_blacksmith_anvil_hint_strip,
			Vector2(mid_x + hint_strip_pad_h, anvil_y + anvil_slot + 4.0),
			Vector2(mid_w - hint_strip_pad_h * 2.0, 72.0)
		)
	if _blacksmith_anvil_hint_lbl != null:
		_blacksmith_anvil_hint_lbl.z_index = 15
		_camp_style_label(_blacksmith_anvil_hint_lbl, CAMP_TEXT, 20, 1)
		_camp_set_rect(
			_blacksmith_anvil_hint_lbl,
			Vector2(mid_x + hint_strip_pad_h + hint_inner_pad, anvil_y + anvil_slot + 10.0),
			Vector2(mid_w - (hint_strip_pad_h + hint_inner_pad) * 2.0, 58.0)
		)

	var recipe_book_y: float = anvil_y + anvil_slot + 86.0
	var recipe_book_btn_w: float = 240.0
	if recipe_book_btn != null:
		recipe_book_btn.z_index = 12
		_camp_style_button(recipe_book_btn, false, 19, 42.0)
		_camp_set_rect(
			recipe_book_btn,
			Vector2(mid_x + (mid_w - recipe_book_btn_w) * 0.5, recipe_book_y),
			Vector2(recipe_book_btn_w, 42.0)
		)
		_sync_blacksmith_recipe_book_button_state()

	var preview_hdr_y: float = list_top + bp_h + 12.0
	if _blacksmith_hdr_preview != null:
		_camp_set_rect(
			_blacksmith_hdr_preview,
			Vector2(pw - pad - right_col_w, preview_hdr_y),
			Vector2(right_col_w, sec_h)
		)
	var icon_side: float = clampf(minf(136.0, right_col_w - 40.0), 100.0, 168.0)
	var icon_x: float = pw - pad - right_col_w + (right_col_w - icon_side) * 0.5
	var icon_y: float = preview_hdr_y + sec_h + 6.0
	if result_icon != null:
		result_icon.rotation = 0.0
		result_icon.z_index = 9
		_camp_set_rect(result_icon, Vector2(icon_x, icon_y), Vector2(icon_side, icon_side))
	var rtl_h: float = clampf(ph - (icon_y + icon_side) - bottom_reserve - 4.0, 96.0, 220.0)
	if recipe_result_label != null:
		recipe_result_label.rotation = 0.0
		recipe_result_label.z_index = 9
		_camp_style_rich_label(
			recipe_result_label,
			21,
			Color(0.11, 0.082, 0.055, 0.90),
			CAMP_BORDER_SOFT,
			true
		)
		_camp_set_rect(
			recipe_result_label,
			Vector2(pw - pad - right_col_w + 8.0, icon_y + icon_side + 8.0),
			Vector2(right_col_w - 16.0, rtl_h)
		)

	if _blacksmith_anvil_plate != null:
		_camp_style_panel(_blacksmith_anvil_plate, Color(0.09, 0.065, 0.042, 0.55), CAMP_BORDER_SOFT, 16, 0)
		var plate_top: float = craft_y - 10.0
		var plate_bot: float = recipe_book_y + 44.0
		_camp_set_rect(
			_blacksmith_anvil_plate,
			Vector2(mid_x + 4.0, plate_top),
			Vector2(mid_w - 8.0, plate_bot - plate_top)
		)

	if recipe_book_panel != null:
		_camp_style_panel(recipe_book_panel, CAMP_PANEL_BG, CAMP_BORDER_SOFT, 18, 8)
		recipe_book_panel.z_index = 30
		var book_w: float = clampf(mid_w * 0.92, 420.0, 620.0)
		var book_h: float = clampf(ph * 0.52, 320.0, 520.0)
		_camp_set_rect(
			recipe_book_panel,
			Vector2(mid_x + (mid_w - book_w) * 0.5, list_top + 28.0),
			Vector2(book_w, book_h)
		)
		if recipe_list_text != null:
			_camp_style_rich_label(recipe_list_text, 19, CAMP_PANEL_BG_SOFT, CAMP_BORDER_SOFT, true)
			_camp_set_rect(recipe_list_text, Vector2(14.0, 14.0), Vector2(book_w - 28.0, book_h - 52.0))
		if close_book_btn != null:
			_camp_style_button(close_book_btn, false, 15, 34.0)
			close_book_btn.text = "✕"
			close_book_btn.z_index = 31
			_camp_set_rect(close_book_btn, Vector2(book_w - 48.0, 8.0), Vector2(40.0, 34.0))

	if close_blacksmith_btn != null:
		close_blacksmith_btn.z_index = 25
		_camp_style_button(close_blacksmith_btn, false, 19, 44.0)
		_camp_set_rect(close_blacksmith_btn, Vector2(pw - 148.0, ph - 56.0), Vector2(130.0, 44.0))

	_blacksmith_style_slot_backdrops()


func _blacksmith_finish_recipe_check() -> void:
	_sync_blacksmith_anvil_hint()
	_blacksmith_update_craft_ready_affordance()


func _ensure_blacksmith_workbench_chrome() -> void:
	if blacksmith_panel == null:
		return
	if _blacksmith_anvil_hint_strip == null:
		_blacksmith_anvil_hint_strip = Panel.new()
		_blacksmith_anvil_hint_strip.name = "BlacksmithAnvilHintStrip"
		_blacksmith_anvil_hint_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blacksmith_panel.add_child(_blacksmith_anvil_hint_strip)
	if _blacksmith_anvil_hint_lbl == null:
		_blacksmith_anvil_hint_lbl = Label.new()
		_blacksmith_anvil_hint_lbl.name = "BlacksmithAnvilHint"
		_blacksmith_anvil_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_blacksmith_anvil_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blacksmith_panel.add_child(_blacksmith_anvil_hint_lbl)
	if _blacksmith_workbench_divider == null:
		_blacksmith_workbench_divider = Panel.new()
		_blacksmith_workbench_divider.name = "BlacksmithWorkbenchDivider"
		_blacksmith_workbench_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blacksmith_panel.add_child(_blacksmith_workbench_divider)
	while _blacksmith_socket_labels.size() < 3:
		var n := _blacksmith_socket_labels.size() + 1
		var sl := Label.new()
		sl.name = "BlacksmithSocketIdx%d" % n
		sl.text = str(n)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		blacksmith_panel.add_child(sl)
		_blacksmith_socket_labels.append(sl)


func _sync_blacksmith_anvil_hint() -> void:
	if _blacksmith_anvil_hint_lbl == null or not is_instance_valid(_blacksmith_anvil_hint_lbl):
		return
	if blacksmith_panel == null or not blacksmith_panel.visible:
		_blacksmith_anvil_hint_lbl.visible = false
		if _blacksmith_anvil_hint_strip != null and is_instance_valid(_blacksmith_anvil_hint_strip):
			_blacksmith_anvil_hint_strip.visible = false
		return
	var filled: int = 0
	for it in anvil_items:
		if it != null:
			filled += 1
	var show_hint: bool = filled < 3 and craft_button != null and craft_button.disabled
	_blacksmith_anvil_hint_lbl.visible = show_hint
	if _blacksmith_anvil_hint_strip != null and is_instance_valid(_blacksmith_anvil_hint_strip):
		_blacksmith_anvil_hint_strip.visible = show_hint
	if not show_hint:
		return
	match filled:
		0:
			_blacksmith_anvil_hint_lbl.text = "Drag materials from convoy into the sockets, or double-click a stack to send one."
		1:
			_blacksmith_anvil_hint_lbl.text = "Add more to the sockets — salvage uses one weapon; most recipes need three materials."
		2:
			_blacksmith_anvil_hint_lbl.text = "One more socket. Fill all three to test a forge pattern (unless you are salvaging a single weapon)."


func _blacksmith_stop_craft_ready_affordance() -> void:
	if _blacksmith_craft_ready_tween != null and _blacksmith_craft_ready_tween.is_valid():
		_blacksmith_craft_ready_tween.kill()
	_blacksmith_craft_ready_tween = null
	_blacksmith_was_craft_ready = false
	if craft_button != null and is_instance_valid(craft_button):
		craft_button.modulate = Color.WHITE


func _blacksmith_play_craft_ready_tick_sound() -> void:
	if select_sound != null and select_sound.stream != null:
		select_sound.pitch_scale = 1.18
		select_sound.play()


func _blacksmith_update_craft_ready_affordance() -> void:
	if craft_button == null or not is_instance_valid(craft_button):
		return
	if craft_button.disabled:
		_blacksmith_stop_craft_ready_affordance()
		return
	if not _blacksmith_was_craft_ready:
		_blacksmith_was_craft_ready = true
		_blacksmith_play_craft_ready_tick_sound()
	if _blacksmith_craft_ready_tween != null and _blacksmith_craft_ready_tween.is_valid():
		return
	_blacksmith_craft_ready_tween = create_tween().set_loops()
	_blacksmith_craft_ready_tween.tween_property(craft_button, "modulate", Color(1.2, 1.14, 0.92), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_blacksmith_craft_ready_tween.tween_property(craft_button, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _blacksmith_slot_receive_juice(slot_index: int) -> void:
	var slots: Array = [slot1, slot2, slot3]
	if slot_index < 0 or slot_index >= slots.size():
		return
	var tr: Control = slots[slot_index] as Control
	if tr == null or not is_instance_valid(tr):
		return
	var orig: Vector2 = Vector2.ONE
	tr.scale = orig
	var tw := create_tween()
	tw.tween_property(tr, "scale", orig * 1.14, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(tr, "scale", orig, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if shop_buy_sound != null and shop_buy_sound.stream != null:
		shop_buy_sound.pitch_scale = 0.88
		shop_buy_sound.play()
	elif select_sound != null and select_sound.stream != null:
		select_sound.pitch_scale = 1.22
		select_sound.play()


func _blacksmith_forge_success_panel_juice() -> void:
	if blacksmith_portrait != null and is_instance_valid(blacksmith_portrait):
		_shake_node(blacksmith_portrait)
	if result_icon != null and is_instance_valid(result_icon):
		var hi := Color(1.85, 1.75, 1.25, 1.0)
		var rtw := create_tween()
		rtw.tween_property(result_icon, "modulate", hi, 0.09)
		rtw.tween_property(result_icon, "modulate", Color.WHITE, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if select_sound != null and select_sound.stream != null:
		select_sound.pitch_scale = 1.14
		select_sound.play()
	await get_tree().create_timer(0.30).timeout


func _blacksmith_make_forge_slot_style() -> StyleBoxFlat:
	var st := _camp_make_panel_style(
		Color(0.045, 0.032, 0.022, 1.0),
		Color(0.88, 0.72, 0.32, 0.98),
		10,
		5
	)
	st.border_width_left = 3
	st.border_width_top = 3
	st.border_width_right = 3
	st.border_width_bottom = 3
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 6
	st.shadow_offset = Vector2(0, 4)
	return st


func _blacksmith_ensure_forge_slot_frame(slot: Control) -> void:
	if slot == null or not is_instance_valid(slot):
		return
	var frame: Panel = slot.get_node_or_null("ForgeSlotFrame") as Panel
	if frame == null:
		frame = Panel.new()
		frame.name = "ForgeSlotFrame"
		slot.add_child(frame)
		slot.move_child(frame, 0)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.show_behind_parent = true
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = -4.0
	frame.offset_top = -4.0
	frame.offset_right = 4.0
	frame.offset_bottom = 4.0
	frame.add_theme_stylebox_override("panel", _blacksmith_make_forge_slot_style())


func _sync_blacksmith_recipe_book_button_state() -> void:
	if recipe_book_btn == null or not is_instance_valid(recipe_book_btn):
		return
	recipe_book_btn.visible = true
	var has_book: bool = CampaignManager.has_recipe_book
	recipe_book_btn.disabled = not has_book
	if has_book:
		recipe_book_btn.tooltip_text = ""
	else:
		recipe_book_btn.tooltip_text = "Locked until you obtain the Blacksmith's Tome. Then you can read Haldor's forge notes and recipe list here."


func _blacksmith_style_slot_backdrops() -> void:
	# Recessed pit is drawn by ForgeSlotFrame Panel; keep ColorRects transparent so the frame shows.
	var slot_fill := Color(0, 0, 0, 0)
	var preview_fill := Color(0.10, 0.076, 0.048, 0.78)
	for slot in [slot1, slot2, slot3]:
		if slot == null:
			continue
		_blacksmith_ensure_forge_slot_frame(slot)
		for c in slot.get_children():
			if c is ColorRect:
				(c as ColorRect).color = slot_fill
	if recipe_result_label != null:
		for c in recipe_result_label.get_children():
			if c is ColorRect:
				(c as ColorRect).color = preview_fill
	if result_icon != null:
		_blacksmith_ensure_forge_slot_frame(result_icon)
		for c in result_icon.get_children():
			if c is ColorRect:
				(c as ColorRect).color = Color(0, 0, 0, 0)
		var preview_frame: Panel = result_icon.get_node_or_null("ForgeSlotFrame") as Panel
		if preview_frame != null:
			preview_frame.add_theme_stylebox_override("panel", _blacksmith_make_forge_slot_style())


func _ensure_merchant_talk_modal() -> void:
	if _merchant_talk_modal != null and is_instance_valid(_merchant_talk_modal):
		return
	var modal := Control.new()
	modal.name = "MerchantTalkModal"
	modal.visible = false
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.z_index = 120
	add_child(modal)
	_merchant_talk_modal = modal

	var dim := ColorRect.new()
	dim.name = "MerchantTalkDimmer"
	dim.color = Color.WHITE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_merchant_talk_dimmer_gui_input)
	modal.add_child(dim)
	_merchant_talk_dimmer = dim
	var dim_shader_path := "res://merchant_talk_dimmer.gdshader"
	if ResourceLoader.exists(dim_shader_path):
		var sh: Shader = load(dim_shader_path) as Shader
		if sh != null:
			var mat := ShaderMaterial.new()
			mat.shader = sh
			mat.set_shader_parameter("dim_rgb", Vector3(0.03, 0.022, 0.014))
			mat.set_shader_parameter("base_alpha", 0.78)
			dim.material = mat

	if talk_panel != null and talk_panel.get_parent() != modal:
		var par: Node = talk_panel.get_parent()
		if par != null:
			par.remove_child(talk_panel)
		modal.add_child(talk_panel)


func _on_merchant_talk_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_close_merchant_talk_panel()


func _merchant_talk_kill_modal_tweens() -> void:
	if _merchant_talk_open_close_tween != null and _merchant_talk_open_close_tween.is_valid():
		_merchant_talk_open_close_tween.kill()
	_merchant_talk_open_close_tween = null
	if _merchant_talk_stagger_tween != null and _merchant_talk_stagger_tween.is_valid():
		_merchant_talk_stagger_tween.kill()
	_merchant_talk_stagger_tween = null


func _merchant_talk_stop_icon_pulse() -> void:
	if quest_item_icon != null:
		if quest_item_icon.has_meta("_mt_pulse_tw"):
			var ptw: Variant = quest_item_icon.get_meta("_mt_pulse_tw")
			if ptw is Tween and (ptw as Tween).is_valid():
				(ptw as Tween).kill()
			quest_item_icon.remove_meta("_mt_pulse_tw")
		quest_item_icon.scale = Vector2.ONE


func _merchant_talk_reset_modal_visuals() -> void:
	_merchant_talk_stop_icon_pulse()
	if _merchant_talk_dimmer != null:
		_merchant_talk_dimmer.modulate = Color.WHITE
	if talk_panel != null:
		talk_panel.scale = Vector2.ONE
		talk_panel.modulate = Color.WHITE
		talk_panel.pivot_offset = Vector2.ZERO
	for b in [option1, option2, option3]:
		if b != null:
			b.modulate = Color.WHITE
			b.scale = Vector2.ONE


func _merchant_talk_play_open_sfx() -> void:
	if select_sound != null and select_sound.stream != null:
		select_sound.pitch_scale = 1.12
		select_sound.play()
	elif talk_sound != null and talk_sound.stream != null:
		talk_sound.pitch_scale = 1.05
		talk_sound.play()


func _merchant_talk_play_close_sfx() -> void:
	if select_sound != null and select_sound.stream != null:
		select_sound.pitch_scale = 0.88
		select_sound.play()


func _merchant_talk_play_hover_sfx() -> void:
	if merchant_blip != null and merchant_blip.stream != null:
		merchant_blip.pitch_scale = 1.35
		merchant_blip.volume_db = -26.0
		merchant_blip.play()


func _merchant_talk_play_confirm_sfx(risky: bool) -> void:
	if risky:
		if shop_sell_sound != null and shop_sell_sound.stream != null:
			shop_sell_sound.pitch_scale = 0.95
			shop_sell_sound.play()
		elif select_sound != null and select_sound.stream != null:
			select_sound.pitch_scale = 0.82
			select_sound.play()
	else:
		if shop_buy_sound != null and shop_buy_sound.stream != null:
			shop_buy_sound.pitch_scale = 1.02
			shop_buy_sound.play()
		elif select_sound != null and select_sound.stream != null:
			select_sound.pitch_scale = 1.0
			select_sound.play()


func _ensure_merchant_talk_quest_bar() -> void:
	if talk_panel == null:
		return
	if _merchant_talk_quest_bar != null and is_instance_valid(_merchant_talk_quest_bar):
		return
	var bar := ProgressBar.new()
	bar.name = "MerchantTalkQuestBar"
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.step = 0.1
	bar.show_percentage = false
	bar.custom_minimum_size.y = MERCHANT_TALK_QUEST_BAR_H
	bar.visible = false
	talk_panel.add_child(bar)
	_merchant_talk_quest_bar = bar
	_style_merchant_talk_quest_bar(bar)


func _style_merchant_talk_quest_bar(bar: ProgressBar) -> void:
	if bar == null:
		return
	var bg := _camp_make_panel_style(Color(0.06, 0.045, 0.032, 0.95), CAMP_BORDER_SOFT.darkened(0.2), 10, 0)
	var fill := _camp_make_panel_style(Color(0.35, 0.62, 0.38, 0.92), CAMP_ACCENT_GREEN.darkened(0.15), 8, 0)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)


func _update_merchant_talk_quest_bar() -> void:
	_ensure_merchant_talk_quest_bar()
	if _merchant_talk_quest_bar == null:
		return
	if not CampaignManager.merchant_quest_active:
		_merchant_talk_quest_bar.visible = false
		return
	var tgt: int = maxi(1, int(CampaignManager.merchant_quest_target_amount))
	var found: int = _count_party_items_for_quest(str(CampaignManager.merchant_quest_item_name), true)
	_merchant_talk_quest_bar.visible = true
	_merchant_talk_quest_bar.max_value = 100.0
	_merchant_talk_quest_bar.value = clampf(100.0 * float(found) / float(tgt), 0.0, 100.0)


func _ensure_merchant_talk_header() -> void:
	if talk_panel == null:
		return
	if _merchant_talk_header_label != null and is_instance_valid(_merchant_talk_header_label):
		return
	var hdr := Label.new()
	hdr.name = "MerchantTalkHeader"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.add_theme_color_override("font_color", Color(0.82, 0.72, 0.42, 1.0))
	hdr.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.92))
	hdr.add_theme_constant_override("outline_size", 2)
	hdr.text = "BARTHOLOMEW"
	talk_panel.add_child(hdr)
	talk_panel.move_child(hdr, 0)
	_merchant_talk_header_label = hdr


func _ensure_merchant_abandon_confirm() -> void:
	if _merchant_abandon_confirm != null and is_instance_valid(_merchant_abandon_confirm):
		return
	var d := ConfirmationDialog.new()
	d.name = "MerchantAbandonConfirm"
	d.dialog_text = "Abandon this contract? You will lose 1 reputation with the merchant."
	d.ok_button_text = "Abandon"
	d.cancel_button_text = "Keep contract"
	d.exclusive = true
	# ConfirmationDialog extends Window — no CanvasItem z_index; keep above game UI when windowed.
	d.always_on_top = true
	add_child(d)
	d.confirmed.connect(_on_merchant_abandon_confirmed)
	_merchant_abandon_confirm = d


func _on_merchant_abandon_confirmed() -> void:
	var mc_name: String = "Hero"
	if CampaignManager.player_roster.size() > 0:
		mc_name = str(CampaignManager.player_roster[0]["unit_name"])
	CampaignManager.merchant_reputation = max(CampaignManager.merchant_reputation - 1, 0)
	_populate_shop()
	CampaignManager.merchant_quest_active = false
	CampaignManager.merchant_quest_item_name = ""
	CampaignManager.merchant_quest_target_amount = 0
	CampaignManager.merchant_quest_reward = 0
	_merchant_talk_play_confirm_sfx(true)
	_close_merchant_talk_panel()
	_play_typewriter_animation(_line("abandon", {"name": mc_name}))


func _merchant_talk_btn_hover_enter(btn: Button) -> void:
	if btn == null or _merchant_talk_modal == null or not _merchant_talk_modal.visible:
		return
	_merchant_talk_play_hover_sfx()
	if btn.has_meta("_mt_htw"):
		var o: Variant = btn.get_meta("_mt_htw")
		if o is Tween and (o as Tween).is_valid():
			(o as Tween).kill()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	btn.set_meta("_mt_htw", tw)
	btn.pivot_offset = Vector2(btn.size.x * 0.5, btn.size.y * 0.5)
	tw.tween_property(btn, "scale", Vector2(1.02, 1.02), 0.08)


func _merchant_talk_btn_hover_exit(btn: Button) -> void:
	if btn == null:
		return
	if btn.has_meta("_mt_htw"):
		var o: Variant = btn.get_meta("_mt_htw")
		if o is Tween and (o as Tween).is_valid():
			(o as Tween).kill()
		btn.remove_meta("_mt_htw")
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.08)


func _merchant_talk_wire_option_fx(btn: Button) -> void:
	if btn == null:
		return
	if btn.has_meta("_mt_fx_wired") and bool(btn.get_meta("_mt_fx_wired")):
		return
	btn.set_meta("_mt_fx_wired", true)
	btn.mouse_entered.connect(_merchant_talk_btn_hover_enter.bind(btn))
	btn.mouse_exited.connect(_merchant_talk_btn_hover_exit.bind(btn))


func _merchant_talk_stagger_buttons_in() -> void:
	if _merchant_talk_modal == null or not _merchant_talk_modal.visible:
		return
	_merchant_talk_stagger_tween = create_tween()
	var tw: Tween = _merchant_talk_stagger_tween
	for b in [option1, option2, option3]:
		if b != null:
			tw.tween_property(b, "modulate:a", 1.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.032)
	tw.tween_callback(func():
		_merchant_talk_start_icon_pulse_if_quest()
		_merchant_talk_grab_primary_focus()
	)


func _merchant_talk_start_icon_pulse_if_quest() -> void:
	if quest_item_icon == null or not quest_item_icon.visible or _merchant_talk_modal == null:
		return
	if not _merchant_talk_modal.visible:
		return
	_merchant_talk_stop_icon_pulse()
	quest_item_icon.pivot_offset = quest_item_icon.size * 0.5
	var tw := create_tween().set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(quest_item_icon, "scale", Vector2(1.035, 1.035), 0.55)
	tw.tween_property(quest_item_icon, "scale", Vector2.ONE, 0.55)
	quest_item_icon.set_meta("_mt_pulse_tw", tw)


func _merchant_talk_flash_progress_text() -> void:
	if talk_text == null:
		return
	var base: Color = talk_text.modulate
	var tw := create_tween()
	tw.tween_property(talk_text, "modulate", Color(1.28, 1.15, 0.82, 1.0), 0.07)
	tw.tween_property(talk_text, "modulate", base, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _merchant_talk_play_open_animation() -> void:
	if talk_panel == null or _merchant_talk_modal == null or not _merchant_talk_modal.visible:
		return
	_camp_layout_merchant_talk_panel_inner()
	talk_panel.pivot_offset = talk_panel.size * 0.5
	talk_panel.scale = Vector2(0.96, 0.96)
	talk_panel.modulate.a = 0.0
	if _merchant_talk_dimmer != null:
		_merchant_talk_dimmer.modulate = Color(1, 1, 1, 0)
	for b in [option1, option2, option3]:
		if b != null:
			b.modulate.a = 0.0
			b.scale = Vector2.ONE
			b.pivot_offset = Vector2(b.size.x * 0.5, b.size.y * 0.5)
	_merchant_talk_play_open_sfx()
	_merchant_talk_kill_modal_tweens()
	var tw := create_tween()
	_merchant_talk_open_close_tween = tw
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _merchant_talk_dimmer != null:
		tw.tween_property(_merchant_talk_dimmer, "modulate:a", 1.0, 0.16)
	tw.tween_property(talk_panel, "modulate:a", 1.0, 0.14)
	tw.tween_property(talk_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(_merchant_talk_stagger_buttons_in)


func _merchant_talk_play_close_animation() -> void:
	if _merchant_talk_modal == null:
		_sync_merchant_talk_button_caption()
		return
	if talk_panel == null or not _merchant_talk_modal.visible:
		_merchant_talk_reset_modal_visuals()
		_merchant_talk_modal.visible = false
		_sync_merchant_talk_button_caption()
		return
	_merchant_talk_stop_icon_pulse()
	_merchant_talk_kill_modal_tweens()
	_merchant_talk_play_close_sfx()
	var tw := create_tween()
	_merchant_talk_open_close_tween = tw
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _merchant_talk_dimmer != null:
		tw.tween_property(_merchant_talk_dimmer, "modulate:a", 0.0, 0.12)
	tw.tween_property(talk_panel, "modulate:a", 0.0, 0.11)
	tw.tween_property(talk_panel, "scale", Vector2(0.94, 0.94), 0.12)
	tw.chain().tween_callback(func():
		_merchant_talk_reset_modal_visuals()
		_merchant_talk_modal.visible = false
		_sync_merchant_talk_button_caption()
	)


func _merchant_talk_show_modal_animated() -> void:
	_ensure_merchant_talk_modal()
	if _merchant_talk_modal == null:
		return
	_merchant_talk_kill_modal_tweens()
	_merchant_talk_modal.visible = true
	if talk_panel != null:
		talk_panel.visible = true
	call_deferred("_merchant_talk_play_open_animation")


func _camp_layout_merchant_talk_panel() -> void:
	if talk_panel == null:
		return
	_ensure_merchant_talk_modal()
	var box: Vector2 = size
	if box.x < 64.0 or box.y < 64.0:
		box = get_viewport().get_visible_rect().size
	if _merchant_talk_modal != null:
		_camp_set_rect(_merchant_talk_modal, Vector2.ZERO, box)
	if _merchant_talk_dimmer != null:
		_camp_set_rect(_merchant_talk_dimmer, Vector2.ZERO, box)
	talk_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_w: float = clampf(box.x * 0.46, 400.0, 640.0)
	var panel_h: float = clampf(box.y * 0.58, 300.0, 560.0)
	var pos := Vector2((box.x - panel_w) * 0.5, (box.y - panel_h) * 0.5)
	_camp_set_rect(talk_panel, pos, Vector2(panel_w, panel_h))
	_camp_style_panel(talk_panel, CAMP_PANEL_BG_ALT, CAMP_BORDER, 20, 10)
	call_deferred("_camp_layout_merchant_talk_panel_inner")
	if _merchant_talk_modal != null and _merchant_talk_modal.visible:
		call_deferred("_camp_layout_merchant_talk_panel_inner")


func _camp_layout_merchant_talk_panel_inner() -> void:
	if talk_panel == null or not is_instance_valid(talk_panel):
		return
	var sz: Vector2 = talk_panel.size
	if sz.x < 32.0 or sz.y < 40.0:
		return
	var m := 12.0
	_ensure_merchant_talk_header()
	var header_h: float = MERCHANT_TALK_HEADER_H
	var top_y0: float = m + header_h + 6.0
	var bar_reserve: float = MERCHANT_TALK_QUEST_BAR_H + 10.0 if CampaignManager.merchant_quest_active else 0.0
	var vbox_min_h: float = maxf(100.0, sz.y * 0.26)
	var text_block_h: float = maxf(88.0, sz.y - top_y0 - vbox_min_h - m - 8.0 - bar_reserve)
	if _merchant_talk_header_label != null:
		_camp_set_rect(_merchant_talk_header_label, Vector2(m, m), Vector2(sz.x - 2.0 * m, header_h))
	var talk_bg: Panel = talk_panel.get_node_or_null("TalkBackground") as Panel
	if talk_bg != null:
		_camp_style_panel(talk_bg, Color(0.07, 0.052, 0.036, 0.94), CAMP_BORDER_SOFT, 18, 0)
		_camp_set_rect(talk_bg, Vector2(m, top_y0), Vector2(sz.x - 2.0 * m, text_block_h))
	var content_vbox: VBoxContainer = talk_panel.get_node_or_null("TalkContentVBox") as VBoxContainer
	if content_vbox != null:
		content_vbox.add_theme_constant_override("separation", 8)
		_camp_set_rect(content_vbox, Vector2(m + 10.0, top_y0 + 10.0), Vector2(sz.x - 2.0 * m - 20.0, text_block_h - 20.0))
		var tail: Control = content_vbox.get_node_or_null("TalkContentTailSpacer") as Control
		if tail != null:
			tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_update_merchant_talk_quest_bar()
	var after_text: float = top_y0 + text_block_h + 6.0
	if CampaignManager.merchant_quest_active and _merchant_talk_quest_bar != null:
		_camp_set_rect(
			_merchant_talk_quest_bar,
			Vector2(m + 6.0, after_text),
			Vector2(sz.x - 2.0 * m - 12.0, MERCHANT_TALK_QUEST_BAR_H)
		)
		after_text += MERCHANT_TALK_QUEST_BAR_H + 8.0
	var vbox_top: float = after_text + 4.0
	var vbox: VBoxContainer = talk_panel.get_node_or_null("VBoxContainer") as VBoxContainer
	if vbox != null:
		vbox.add_theme_constant_override("separation", 10)
		_camp_set_rect(vbox, Vector2(m, vbox_top), Vector2(sz.x - 2.0 * m, maxf(100.0, sz.y - vbox_top - m)))
	if talk_text != null:
		_camp_style_label(talk_text, CAMP_TEXT, 20, 2)
		talk_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		talk_text.custom_minimum_size = Vector2.ZERO
		talk_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Natural text height + icon grouped; tail spacer absorbs extra panel height (icon sits higher).
		talk_text.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var opt3_danger: bool = CampaignManager.merchant_quest_active
	_camp_style_merchant_talk_option(option1, false)
	_camp_style_merchant_talk_option(option2, false)
	_camp_style_merchant_talk_option(option3, opt3_danger)
	for ob in [option1, option2, option3]:
		if ob is Button:
			_merchant_talk_wire_option_fx(ob as Button)
	if quest_item_icon != null:
		quest_item_icon.custom_minimum_size = Vector2(84, 84)
		quest_item_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _on_camp_ui_resized() -> void:
	call_deferred("_camp_apply_ui_overhaul")

## Initializes the camp UI: connects all buttons, populates shop/roster/inventory, starts music and ambient.
## Purpose: Single entry point for camp setup; gates (e.g. blacksmith, world map) use CampaignManager.max_unlocked_index.
## Inputs: None.  Outputs: None.
## Side effects: Connects signals, populates grids, may append test data (dragon meat / hatch) if DragonManager is empty.
func _ready() -> void:
	if camp_music != null:
		camp_music.bus = "Music"
	if minigame_music != null:
		minigame_music.bus = "Music"
	# Single source of truth for default camp music (shared with CampExplore).
	if camp_music_tracks.is_empty():
		camp_music_tracks = DefaultCampMusic.get_default_camp_music_tracks()

	# --- TEMP DRAGON MEAT TEST ---
	# Use a loadable consumable so it has path/original_path and serializes correctly (otherwise save warns and drops the item).
	var meat_template = load("res://Resources/Consumables/Vulnerary.tres") as Resource
	if meat_template != null:
		var test_meat = CampaignManager.make_unique_item(meat_template)
		if test_meat != null:
			test_meat.set("item_name", "Fresh Meat")
			test_meat.set("description", "A perfect snack for a growing dragon.")
			test_meat.set("gold_cost", 15)
			CampaignManager.global_inventory.append(test_meat)
	
	# --- CREATE INVISIBLE CURSOR FOR DRAGGING ---
	var invisible_img = Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	empty_cursor = ImageTexture.create_from_image(invisible_img)
	if blacksmith_panel: blacksmith_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# 1. SAFETY CHECKS: Check if nodes exist before connecting to avoid 'null instance' crashes
	if save_button: 
		save_button.pressed.connect(_on_save_clicked)
	else:
		print("!!! WARNING: SaveButton not found. Access it as a Unique Name (%) in the editor.")

	# 2. CONNECT SLOT BUTTONS
	if save_slot_1: save_slot_1.pressed.connect(func(): _try_to_save(1))
	if save_slot_2: save_slot_2.pressed.connect(func(): _try_to_save(2))
	if save_slot_3: save_slot_3.pressed.connect(func(): _try_to_save(3))
	if close_save_btn: close_save_btn.pressed.connect(_on_back_pressed)
	if blacksmith_talk_button != null:
		blacksmith_talk_button.pressed.connect(_on_blacksmith_talk_pressed)
	if overwrite_dialog:
		overwrite_dialog.confirmed.connect(_on_overwrite_confirmed)
	
	if back_button: 
		back_button.pressed.connect(_on_back_pressed)
		
	if open_save_menu_btn:
		open_save_menu_btn.pressed.connect(_on_save_clicked)
		
	# Initial UI state
	_update_slot_labels()	
	

	_update_merchant_text("welcome")
	
	_refresh_gold_label()
	
	# --- TEMP DRAGON TEST (Delete this later!) ---
	# We only hatch test eggs if the player doesn't have any dragons yet.
	if DragonManager.player_dragons.is_empty():
		print("Spawning test dragons...")
		DragonManager.hatch_egg()
		DragonManager.hatch_egg() 
		DragonManager.hatch_egg()
		# Now you have 3 Gen-1 baby dragons!
	if open_ranch_btn:
		open_ranch_btn.pressed.connect(_open_dragon_ranch)
	# --- SYNC CAMP UI WHEN RANCH CLOSES ---
	if dragon_ranch_panel:
		dragon_ranch_panel.visibility_changed.connect(func():
			if not dragon_ranch_panel.visible:
				_populate_inventory() # Show new eggs / hide consumed meat & roses
				_refresh_gold_label() # Update gold if they threw rabbits
				if herder_idle_timer:
					herder_idle_timer.stop()
		)
	next_battle_button.pressed.connect(_on_next_battle_pressed)
	equip_button.pressed.connect(_on_equip_pressed)
	unequip_button.pressed.connect(_on_unequip_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	sell_confirmation.confirmed.connect(_on_sell_confirmed)
	buy_button.pressed.connect(_on_buy_pressed)
	category_tabs.tab_selected.connect(_on_tab_selected)	
	buy_confirmation.confirmed.connect(_on_buy_confirmed)
	# --- QUANTITY POPUP CONNECTIONS ---
	if quantity_popup:
		qty_slider.value_changed.connect(_on_qty_slider_changed)
		qty_confirm_btn.pressed.connect(_on_qty_confirm_pressed)
		qty_cancel_btn.pressed.connect(func(): quantity_popup.visible = false)
	use_button.pressed.connect(_on_use_pressed)
	# --- JUKEBOX CONNECTIONS ---
	if jukebox_btn: jukebox_btn.pressed.connect(_open_jukebox)
	if close_jukebox_btn: close_jukebox_btn.pressed.connect(_close_jukebox)
	
	if jukebox_volume_slider:
		jukebox_volume_slider.value_changed.connect(_on_jukebox_volume_changed)
		# Restore persisted volume if available
		user_music_volume = CampaignManager.jukebox_volume_db
		jukebox_volume_slider.value = db_to_linear(user_music_volume)
	else:
		user_music_volume = CampaignManager.jukebox_volume_db

	if jukebox_skip_btn: jukebox_skip_btn.pressed.connect(_on_jukebox_skip_pressed)
	if jukebox_stop_btn: jukebox_stop_btn.pressed.connect(_on_jukebox_stop_pressed)

	camp_music.finished.connect(_on_camp_music_finished)
	jukebox_playback_mode = CampaignManager.jukebox_last_mode if CampaignManager.jukebox_last_mode in [JUKEBOX_MODE_DEFAULT, JUKEBOX_MODE_LOOP_TRACK, JUKEBOX_MODE_LOOP_PLAYLIST, JUKEBOX_MODE_SHUFFLE_PLAYLIST] else JUKEBOX_MODE_DEFAULT
	_jukebox_track_sort_mode = JUKEBOX_SORT_ALPHA if CampaignManager.jukebox_sort_mode == JUKEBOX_SORT_ALPHA else JUKEBOX_SORT_UNLOCK
	_restore_jukebox_session()	
	if swap_ability_btn: swap_ability_btn.pressed.connect(_on_swap_ability_pressed)
	# --- SKILL TREE CONNECTIONS ---
	if open_skills_btn: open_skills_btn.pressed.connect(_open_skill_tree)
	if close_skills_btn: close_skills_btn.pressed.connect(func(): skill_tree_panel.visible = false)
	if unlock_skill_btn: unlock_skill_btn.pressed.connect(_on_unlock_skill_pressed)
	
	minigame_music.finished.connect(_on_minigame_music_finished)
	_setup_task_log_button()
	base_target_height = haggle_target_zone.size.y
	
	haggle_button.pressed.connect(_on_haggle_pressed)
	haggle_confirmation.confirmed.connect(_start_haggle_minigame)
	if haggle_confirmation != null:
		haggle_confirmation.about_to_popup.connect(_apply_haggle_confirmation_theme)
		call_deferred("_apply_haggle_confirmation_theme")
	
	talk_button.pressed.connect(_on_talk_pressed)
	option1.pressed.connect(_on_option1_pressed)
	option2.pressed.connect(_on_option2_pressed)
	option3.pressed.connect(_on_option3_pressed)
	if blacksmith_panel != null:
		blacksmith_panel.visibility_changed.connect(_sync_merchant_talk_button_state)

	# --- BLACKSMITH DRAG & DROP CONNECTIONS ---
	# 1. Forward the drag signals to our custom functions
	slot1.set_drag_forwarding(Callable(), _can_drop_slot, _drop_slot.bind(0))
	slot2.set_drag_forwarding(Callable(), _can_drop_slot, _drop_slot.bind(1))
	slot3.set_drag_forwarding(Callable(), _can_drop_slot, _drop_slot.bind(2))
	
	# 2. Allow clicking slots to remove items from the anvil
	slot1.gui_input.connect(_on_slot_gui_input.bind(0))
	slot2.gui_input.connect(_on_slot_gui_input.bind(1))
	slot3.gui_input.connect(_on_slot_gui_input.bind(2))
	
	# --- BLACKSMITH BUTTON CONNECTIONS ---
	if open_blacksmith_btn:
		open_blacksmith_btn.pressed.connect(open_blacksmith)
		if DEBUG_CAMP_ALWAYS_SHOW_BLACKSMITH:
			open_blacksmith_btn.visible = true
		else:
			open_blacksmith_btn.visible = CampaignManager.blacksmith_unlocked
			# HIDE UNTIL LEVEL 3 IS CLEARED
			if CampaignManager.max_unlocked_index >= 3:
				open_blacksmith_btn.visible = true
			else:
				open_blacksmith_btn.visible = false
	if close_blacksmith_btn:
		close_blacksmith_btn.pressed.connect(close_blacksmith)
	if craft_button:
		craft_button.pressed.connect(_on_craft_pressed)
	if recipe_book_btn: recipe_book_btn.pressed.connect(_open_recipe_book)
	if close_book_btn: close_book_btn.pressed.connect(_close_recipe_book)	
	
	_populate_inventory()
	
# --- UPDATED SHOP INITIALIZATION ---
	if CampaignManager.camp_shop_stock.is_empty():
		_generate_shop_inventory()
		_apply_random_discount()
		
		CampaignManager.camp_shop_stock = shop_stock.duplicate()
		CampaignManager.camp_discount_item = discounted_item
		CampaignManager.camp_has_haggled = false
		has_haggled_this_visit = false
	else:
		shop_stock = CampaignManager.camp_shop_stock.duplicate()
		discounted_item = CampaignManager.camp_discount_item
		has_haggled_this_visit = CampaignManager.camp_has_haggled

	# --- NEW: SETUP DRAG AND DROP & REFRESH ---
	if unit_grid: unit_grid.set_drag_forwarding(Callable(), _can_drop_inv, _drop_on_unit)
	if convoy_grid: convoy_grid.set_drag_forwarding(Callable(), _can_drop_inv, _drop_on_convoy)
	if refresh_shop_btn: refresh_shop_btn.pressed.connect(_on_refresh_shop_pressed)	
	_populate_shop()
	_play_merchant_idle()
	
	_populate_roster()
	if CampaignManager.player_roster.size() > 0:
		_on_roster_item_selected(0)

	idle_timer = Timer.new()
	idle_timer.timeout.connect(_on_idle_timer_timeout)
	add_child(idle_timer)
	_reset_idle_timer()
	
	# --- DRAGON HERDER IDLE TIMER ---
	herder_idle_timer = Timer.new()
	herder_idle_timer.timeout.connect(_on_herder_idle_timeout)
	add_child(herder_idle_timer)
	
	# --- 1. UI FADE-IN POLISH ---
	self.modulate.a = 0.0
	var fade_in = create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# --- 2. CONNECT HOVER SOUNDS ---
	_connect_hover_sounds(self)

	# --- 3. AMBIENT CAMPFIRE LOOP ---
	if campfire_ambient != null:
		var ambient_player = AudioStreamPlayer.new()
		ambient_player.stream = campfire_ambient
		ambient_player.volume_db = -12.0 # Keep it quiet and cozy behind the music
		add_child(ambient_player)
		ambient_player.play()
		# Force it to loop infinitely even if the raw audio file isn't set to loop
		ambient_player.finished.connect(ambient_player.play)
	
	# --- WORLD MAP BUTTON LOGIC ---
	# Show World Map and "Continue Story" only after Level 2 is cleared (max_unlocked_index >= 2).
	if world_map_button:
		world_map_button.pressed.connect(_on_world_map_pressed)
		if CampaignManager.max_unlocked_index >= 2:
			world_map_button.visible = true
			next_battle_button.text = "Continue Story"
		else:
			world_map_button.visible = false
			next_battle_button.text = "Next Battle"

	# --- EXPLORE CAMP BUTTON ---
	if explore_camp_btn:
		explore_camp_btn.pressed.connect(_on_explore_camp_pressed)
	if not resized.is_connected(_on_camp_ui_resized):
		resized.connect(_on_camp_ui_resized)
	call_deferred("_camp_apply_ui_overhaul")


## Opens the walkable Explore Camp scene. Does not save; returning restores camp menu.
## Inputs: None.  Outputs: None.  Side effects: Scene change to CampExplore.
func _on_explore_camp_pressed() -> void:
	SceneTransition.change_scene_to_file("res://Scenes/CampExplore.tscn")


## Saves progress and opens the World Map scene. Called when World Map button is pressed.
## Inputs: None.  Outputs: None.  Side effects: Persists via CampaignManager, then scene change.
func _on_world_map_pressed() -> void:
	CampaignManager.save_current_progress()
	SceneTransition.change_scene_to_file("res://Scenes/UI/WorldMap.tscn")

# --- MINIGAME PHYSICS (STARDEW STYLE) ---
func _process(delta: float) -> void:
	if not haggle_active:
		return

	var top_y: float = _haggle_playfield_top
	var panel_height: float = _haggle_playfield_h
	var bar_height: float = haggle_player_bar.size.y
	var target_height: float = haggle_target_zone.size.y

	var boost: bool = Input.is_action_pressed("haggle_boost")
	if not boost and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		boost = _haggle_playfield_global_rect.has_point(get_viewport().get_mouse_position())

	if boost:
		player_velocity -= 800.0 * delta
	else:
		player_velocity += 800.0 * delta

	player_velocity = clampf(player_velocity, -400.0, 400.0)
	haggle_player_bar.position.y += player_velocity * delta

	var min_py: float = top_y
	var max_py: float = top_y + maxf(4.0, panel_height - bar_height)
	haggle_player_bar.position.y = clampf(haggle_player_bar.position.y, min_py, max_py)
	if haggle_player_bar.position.y <= min_py + 0.5 or haggle_player_bar.position.y >= max_py - 0.5:
		player_velocity = 0.0

	target_timer -= delta
	if target_timer <= 0.0:
		target_timer = randf_range(0.5, 1.5)
		var spd: float = 300.0
		if haggle_progress.value > 55.0:
			spd = 430.0
		target_velocity = randf_range(-spd, spd)

	haggle_target_zone.position.y += target_velocity * delta
	var tgt_min: float = top_y
	var tgt_max: float = top_y + maxf(4.0, panel_height - target_height)
	haggle_target_zone.position.y = clampf(haggle_target_zone.position.y, tgt_min, tgt_max)

	var player_rect := Rect2(haggle_player_bar.position, haggle_player_bar.size)
	var target_rect := Rect2(haggle_target_zone.position, haggle_target_zone.size)
	var overlapping: bool = player_rect.intersects(target_rect)

	if overlapping:
		haggle_progress.value = minf(100.0, haggle_progress.value + 15.0 * delta)
		haggle_target_zone.color = Color(0.32, 0.62, 0.38, 0.98)
	else:
		haggle_progress.value = maxf(0.0, haggle_progress.value - 10.0 * delta)
		haggle_target_zone.color = Color(0.52, 0.26, 0.24, 0.95)

	if overlapping != haggle_last_overlap:
		haggle_last_overlap = overlapping
		_haggle_overlap_juice(overlapping)

	if not haggle_mid_line_fired and haggle_progress.value >= 50.0:
		haggle_mid_line_fired = true
		_haggle_play_mid_bark()

	if haggle_progress.value > 1.0:
		haggle_grace_timer = 0.0
	elif haggle_progress.value <= 0.0:
		haggle_grace_timer += delta
		if haggle_grace_timer >= HAGGLE_GRACE_SEC:
			_end_haggle_minigame(false)

	if haggle_progress.value >= 100.0:
		_end_haggle_minigame(true)


func _haggle_overlap_juice(overlapping: bool) -> void:
	if merchant_blip != null and merchant_blip.stream != null:
		merchant_blip.pitch_scale = 1.12 if overlapping else 0.84
		merchant_blip.play()
	if haggle_progress == null:
		return
	if _haggle_progress_pulse_tween != null and _haggle_progress_pulse_tween.is_valid():
		_haggle_progress_pulse_tween.kill()
	_haggle_progress_pulse_tween = create_tween()
	var bump: Color = Color(1.12, 1.08, 0.95, 1.0) if overlapping else Color(1.0, 0.9, 0.9, 1.0)
	_haggle_progress_pulse_tween.tween_property(haggle_progress, "modulate", bump, 0.06)
	_haggle_progress_pulse_tween.tween_property(haggle_progress, "modulate", Color.WHITE, 0.14)


func _haggle_play_mid_bark() -> void:
	var mc_name: String = "Hero"
	if CampaignManager.player_roster.size() > 0:
		mc_name = str(CampaignManager.player_roster[0]["unit_name"])
	var arr: Array = DialogueDatabase.merchant_lines.get("haggle_mid", [])
	if arr.is_empty():
		return
	var line: String = str(arr[randi() % arr.size()])
	_play_typewriter_animation(line % mc_name)


func _apply_haggle_confirmation_theme() -> void:
	var d: ConfirmationDialog = haggle_confirmation
	if d == null or not is_instance_valid(d):
		return
	# Embedded subwindow so camp theme overrides draw (native OS windows ignore panel styles).
	d.popup_window = false
	d.unresizable = true
	d.exclusive = true
	d.transient = true
	d.min_size = Vector2i(700, 400)
	d.title = "Bartholomew — terms of the haggle"

	var panel_st := _camp_make_panel_style(CAMP_PANEL_BG_ALT, CAMP_BORDER, 22, 14)
	d.add_theme_stylebox_override("panel", panel_st)
	d.add_theme_color_override("title_color", Color(0.93, 0.80, 0.44, 1.0))
	d.add_theme_font_size_override("title_font_size", 19)
	d.add_theme_constant_override("title_height", 40)
	d.add_theme_color_override("close_color", CAMP_MUTED)
	d.add_theme_color_override("close_hover_color", CAMP_BORDER)
	d.add_theme_color_override("close_pressed_color", CAMP_BORDER.darkened(0.12))
	d.add_theme_constant_override("buttons_separation", 18)

	var body_well := _camp_make_panel_style(Color(0.085, 0.062, 0.04, 0.94), CAMP_BORDER_SOFT, 16, 0)
	body_well.content_margin_left = 16
	body_well.content_margin_right = 16
	body_well.content_margin_top = 12
	body_well.content_margin_bottom = 12

	var dl: Label = d.get_label()
	if dl != null:
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		dl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		dl.add_theme_font_size_override("font_size", 16)
		dl.add_theme_color_override("font_color", CAMP_TEXT)
		dl.add_theme_color_override("font_outline_color", Color(0.03, 0.022, 0.015, 0.92))
		dl.add_theme_constant_override("outline_size", 1)
		dl.add_theme_constant_override("line_spacing", 3)
		dl.add_theme_stylebox_override("normal", body_well)

	var okb: Button = d.get_ok_button()
	if okb != null:
		_camp_style_button(okb, true, 17, 44.0)
		okb.custom_minimum_size.x = maxf(okb.custom_minimum_size.x, 132.0)
	var cb: Button = d.get_cancel_button()
	if cb != null:
		_camp_style_button(cb, false, 17, 44.0)
		cb.custom_minimum_size.x = maxf(cb.custom_minimum_size.x, 132.0)


func _build_haggle_confirmation_dialog_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Overlap my bar with yours (hold Space or click inside the play area) to fill the patience meter.")
	lines.append("Late game: the target jitters faster above 50%%.")
	lines.append("")
	lines.append("Win: +1 reputation, an extra cut on today's spotlight deal (stacks up to 15%%), and a chance at a second half-price shelf item.")
	lines.append("Lose after hovering at empty too long: −1 reputation.")
	lines.append("Esc or Walk away: stop — no reputation change, but this visit's haggle is spent.")
	var rep: int = CampaignManager.merchant_reputation
	if rep > 0:
		var pct: int = mini(rep * 2, 20)
		lines.append("")
		lines.append("Your standing already trims all prices by %d%% (max 20%%)." % pct)
	return "\n".join(lines)


func _ensure_haggle_walk_away_button() -> void:
	if haggle_panel == null:
		return
	if _haggle_walk_away_btn != null and is_instance_valid(_haggle_walk_away_btn):
		return
	var b := Button.new()
	b.name = "HaggleWalkAway"
	b.text = "Walk away"
	b.focus_mode = Control.FOCUS_NONE
	haggle_panel.add_child(b)
	_haggle_walk_away_btn = b
	_camp_style_button(b, false, 15, 34.0)
	b.pressed.connect(_end_haggle_concede)


func _style_haggle_minigame_chrome() -> void:
	if haggle_panel != null:
		haggle_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if haggle_target_zone is ColorRect:
		(haggle_target_zone as ColorRect).color = _haggle_target_neutral_color
	if haggle_player_bar is ColorRect:
		(haggle_player_bar as ColorRect).color = Color(0.38, 0.52, 0.68, 0.98)
	if haggle_progress != null:
		var bg := _camp_make_panel_style(Color(0.06, 0.045, 0.032, 0.95), CAMP_BORDER_SOFT.darkened(0.2), 8, 0)
		var fill := _camp_make_panel_style(Color(0.42, 0.55, 0.32, 0.92), CAMP_ACCENT_GREEN.darkened(0.12), 6, 0)
		haggle_progress.add_theme_stylebox_override("background", bg)
		haggle_progress.add_theme_stylebox_override("fill", fill)


func _camp_layout_haggle_panel() -> void:
	if haggle_panel == null:
		return
	var view_size: Vector2 = get_viewport_rect().size
	if view_size.x < 100.0 or view_size.y < 100.0:
		return
	var panel_w: float = 136.0
	var panel_h: float = clampf(view_size.y * 0.44, 340.0, 520.0)
	var pos := Vector2((view_size.x - panel_w) * 0.5, (view_size.y - panel_h) * 0.5)
	_camp_set_rect(haggle_panel, pos, Vector2(panel_w, panel_h))
	_camp_style_panel(haggle_panel, CAMP_PANEL_BG_ALT, CAMP_BORDER, 18, 8)
	haggle_panel.z_index = 420

	var pad: float = 12.0
	var prog_h: float = 22.0
	var btn_h: float = 36.0
	var title_h: float = 26.0
	_haggle_playfield_top = pad + title_h
	_haggle_playfield_h = maxf(120.0, panel_h - _haggle_playfield_top - pad * 2.0 - prog_h - btn_h - 6.0)

	var cx: float = (panel_w - _haggle_bar_w) * 0.5
	haggle_player_bar.position = Vector2(cx, _haggle_playfield_top + _haggle_playfield_h * 0.5)
	haggle_player_bar.size = Vector2(_haggle_bar_w, 36.0)
	haggle_target_zone.position = Vector2(cx, _haggle_playfield_top + _haggle_playfield_h * 0.45)
	haggle_target_zone.size = Vector2(_haggle_bar_w, maxf(28.0, base_target_height))

	var pf_top_left: Vector2 = haggle_panel.global_position + Vector2(cx, _haggle_playfield_top)
	_haggle_playfield_global_rect = Rect2(pf_top_left, Vector2(_haggle_bar_w, _haggle_playfield_h))

	if haggle_progress != null:
		var py: float = panel_h - pad - btn_h - prog_h - 4.0
		_camp_set_rect(haggle_progress, Vector2(pad, py), Vector2(panel_w - pad * 2.0, prog_h))
	if _haggle_walk_away_btn != null:
		_camp_set_rect(_haggle_walk_away_btn, Vector2(pad, panel_h - pad - btn_h), Vector2(panel_w - pad * 2.0, btn_h))


func _haggle_restore_camp_music() -> void:
	if minigame_music.playing:
		minigame_music.stop()
	if camp_music.stream_paused:
		camp_music.stream_paused = false


func _finish_haggle_session() -> void:
	haggle_active = false
	has_haggled_this_visit = true
	CampaignManager.camp_has_haggled = true
	_sync_merchant_talk_button_state()
	player_velocity = 0.0
	target_velocity = 0.0
	target_timer = 0.0
	haggle_grace_timer = 0.0
	haggle_last_overlap = false
	_haggle_restore_camp_music()
	_sync_haggle_button_availability()


func _on_haggle_pressed() -> void:
	if haggle_active:
		return
	if shop_stock.is_empty():
		warning_dialog.dialog_text = "I have nothing on the shelves to argue about. Come back when stock exists."
		warning_dialog.popup_centered()
		return
	if has_haggled_this_visit:
		warning_dialog.dialog_text = "Bartholomew's patience has run out for today!"
		warning_dialog.popup_centered()
		return
	haggle_confirmation.dialog_text = _build_haggle_confirmation_dialog_text()
	haggle_confirmation.popup_centered()


func _start_haggle_minigame() -> void:
	_ensure_haggle_walk_away_button()
	_camp_layout_haggle_panel()
	_style_haggle_minigame_chrome()
	haggle_active = true
	_sync_merchant_talk_button_state()
	haggle_panel.visible = true
	haggle_mid_line_fired = false
	haggle_grace_timer = 0.0
	haggle_last_overlap = false
	haggle_progress.modulate = Color.WHITE

	var rep: int = CampaignManager.merchant_reputation
	var rel_base: float = minf(base_target_height, _haggle_playfield_h * 0.28)
	if rel_base < 32.0:
		rel_base = minf(HAGGLE_TARGET_BASE_H, _haggle_playfield_h * 0.28)
	var new_height: float = maxf(25.0, rel_base - float(rep) * 6.0)
	haggle_target_zone.size = Vector2(_haggle_bar_w, new_height)
	haggle_player_bar.position.y = clampf(
		_haggle_playfield_top + _haggle_playfield_h * 0.5,
		_haggle_playfield_top,
		_haggle_playfield_top + maxf(4.0, _haggle_playfield_h - haggle_player_bar.size.y)
	)
	haggle_target_zone.position.y = clampf(
		_haggle_playfield_top + _haggle_playfield_h * 0.45,
		_haggle_playfield_top,
		_haggle_playfield_top + maxf(4.0, _haggle_playfield_h - haggle_target_zone.size.y)
	)

	haggle_progress.max_value = 100.0
	haggle_progress.value = 30.0

	if camp_music.playing:
		camp_music.stream_paused = true
	_play_random_minigame_music()


func _end_haggle_concede() -> void:
	if not haggle_active:
		return
	_finish_haggle_session()
	haggle_panel.visible = false
	_update_merchant_text("haggle_concede")
	_show_haggle_concede_popup()
	_populate_shop()


func _show_haggle_concede_popup() -> void:
	if rep_popup == null:
		return
	rep_popup.visible = true
	rep_popup.modulate.a = 1.0
	var start_pos: Vector2 = rep_popup.position
	rep_popup.text = "Walked away — no reputation change"
	rep_popup.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65, 1.0))
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(rep_popup, "position:y", start_pos.y - 50, 1.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(rep_popup, "modulate:a", 0.0, 1.6)
	tween.chain().tween_callback(func():
		if is_instance_valid(rep_popup):
			rep_popup.visible = false
			rep_popup.position = start_pos
	)


func _end_haggle_minigame(won: bool) -> void:
	if not haggle_active:
		return
	_finish_haggle_session()
	haggle_panel.visible = false

	var got_second_deal: bool = false
	if won:
		CampaignManager.merchant_reputation += 1
		CampaignManager.camp_haggle_extra_off = clampf(CampaignManager.camp_haggle_extra_off + 0.05, 0.0, 0.15)
		if randf() < 0.22 and shop_stock.size() >= 2:
			var opts: Array[Resource] = []
			for it in shop_stock:
				if it == null:
					continue
				if it == discounted_item:
					continue
				if it == CampaignManager.camp_second_discount_item:
					continue
				opts.append(it)
			if opts.size() > 0:
				CampaignManager.camp_second_discount_item = opts[randi() % opts.size()]
				got_second_deal = true
		if got_second_deal:
			_update_merchant_text("haggle_win_extra")
		else:
			_update_merchant_text("haggle_win")
	else:
		CampaignManager.merchant_reputation -= 1
		if CampaignManager.merchant_reputation < 0:
			CampaignManager.merchant_reputation = 0
		_update_merchant_text("haggle_lose")

	_show_rep_popup(won)
	_populate_shop()
	
func _update_merchant_text(category: String) -> void:
	var mc_name = "Hero"
	if CampaignManager.player_roster.size() > 0:
		mc_name = CampaignManager.player_roster[0]["unit_name"]
	
	var lines = DialogueDatabase.merchant_lines[category]
	var full_text = lines[randi() % lines.size()] % mc_name
	
	_play_typewriter_animation(full_text)
	
	# Reset the timer so he waits 15-30s after ANY dialogue
	if idle_timer != null:
		_reset_idle_timer()

func _apply_random_discount() -> void:
	CampaignManager.camp_haggle_extra_off = 0.0
	CampaignManager.camp_second_discount_item = null
	if shop_stock.is_empty():
		discounted_item = null
		return
		
	# Pick a random item from the shop stock
	var random_index = randi() % shop_stock.size()
	discounted_item = shop_stock[random_index]
	
	# After picking the item, announce it!
	_update_merchant_welcome_with_discount()

func _update_merchant_welcome_with_discount() -> void:
	var mc_name = "Hero"
	if CampaignManager.player_roster.size() > 0:
		mc_name = CampaignManager.player_roster[0]["unit_name"]

	var wname = discounted_item.get("weapon_name")
	var item_name = discounted_item.get("item_name") if wname == null else wname

	var sale_lines = [
		"%s. Today the %s is 50%% off. A rare lapse in greed.",
		"%s. The %s is half price. The curse remains full price.",
		"%s. I marked down the %s. The donkey called me sentimental.",
		"%s. The %s is discounted. Blame the goblin market for setting a precedent.",
		"%s. Take the %s while it is cheaper. My patience is not.",
		"%s. The %s is on sale. If the Merchants Guild asks, you imagined it.",
		"%s. I am trimming the price on the %s. Do not mistake this for mercy.",
		"%s. The %s is reduced. I acquired it from a tomb that disliked me.",
		"%s. The %s is cheaper today. Paladins do not haggle, but you might.",
		"%s. Discount on the %s. I need coin for certain guild problems.",
		"%s. The %s is marked down. Dwarven ledgers would weep.",
		"%s. The %s is on a 50%% reduction. The donkey demanded honesty.",
		"%s. The %s is half price. Do not drop it, or it will start talking again.",
		"%s. The %s is discounted. I would sell my shadow for this margin.",
		"%s. The %s is cheaper. Buy it now, or I sell it to your rival."
	]

	var full_text = sale_lines[randi() % sale_lines.size()]
	var final_string = full_text % [mc_name, item_name]
	_play_typewriter_animation(final_string)

# --- SHOP PRICE CALCULATION ---
func _get_final_price(item: Resource) -> int:
	var base_price = item.get("gold_cost") if item.get("gold_cost") != null else 0
	
	# Reputation discount: 2% off per reputation level, capped at 20% max
	var rep_discount = min(CampaignManager.merchant_reputation * 0.02, 0.20)
	var final_multiplier = 1.0 - rep_discount
	
	var final_price = int(base_price * final_multiplier)
	var spotlight: bool = (item == discounted_item)
	var second_deal: bool = (item == CampaignManager.camp_second_discount_item)
	if spotlight or second_deal:
		final_price = int((base_price / 2.0) * final_multiplier)
	if spotlight:
		var extra: float = clampf(CampaignManager.camp_haggle_extra_off, 0.0, 0.2)
		final_price = int(roundf(float(final_price) * (1.0 - extra)))
	return final_price

func _play_typewriter_animation(new_text: String) -> void:
	merchant_label.text = new_text
	merchant_label.visible_characters = 0 
	
	# THE FIX: Kill the old animation if they clicked quickly!
	if merchant_tween and merchant_tween.is_valid():
		merchant_tween.kill()
	
	var duration = new_text.length() * 0.04 
	merchant_tween = create_tween()
	merchant_tween.tween_method(_set_visible_characters, 0, new_text.length(), duration).set_trans(Tween.TRANS_LINEAR)
	
func _set_visible_characters(count: int) -> void:
	# Only play the sound if a NEW character has actually appeared
	if count > merchant_label.visible_characters:
		# Don't play blips for empty spaces to make it sound more natural
		var current_char = merchant_label.text.substr(count - 1, 1)
		if current_char != " " and merchant_blip.stream != null:
			merchant_blip.play()
			
	merchant_label.visible_characters = count
	
func _generate_shop_inventory() -> void:
	shop_stock.clear()
	
	# Request a dynamically scaled item pool from the database
	var safe_item_pool = ItemDatabase.get_leveled_shop_pool(CampaignManager.max_unlocked_index)
	
	if safe_item_pool.is_empty():
		return
		
	var rep = CampaignManager.merchant_reputation
	
	# Perk 1: Shop grows larger as you become better friends (+1 slot per 2 rep). Intentional integer truncation.
	var base_amount = randi_range(5, 6)
	var total_slots = base_amount + int(rep / 2.0) 
	
	# Fill the shop stock with random pulls from the safe pool
	for i in range(total_slots):
		var random_index = randi() % safe_item_pool.size()
		var dup_item = CampaignManager.duplicate_item(safe_item_pool[random_index])
		
		# Perk 2: The Black Market Upgrade!
		if dup_item is WeaponData and randi() % 100 < (rep * 3):
			dup_item.weapon_name = "Fine " + dup_item.weapon_name
			dup_item.might += 1
			dup_item.hit_bonus += 5
			dup_item.gold_cost = int(dup_item.gold_cost * 1.5) # Costs 50% more!
			
			if dup_item.rarity == "Common": dup_item.rarity = "Uncommon"
			elif dup_item.rarity == "Uncommon": dup_item.rarity = "Rare"
			
		shop_stock.append(dup_item)
										
func _on_tab_selected(_tab_index: int) -> void:
	# Simply refresh the list whenever a new tab is clicked
	_populate_inventory()

## Populates the shop grid with stock items. Uses _style_item_button (rarity + daily-deal gold); price tags via _add_item_corner_label (20px, 4px margin); lock star if is_locked.
## Purpose: Rebuild shop_grid for current shop_stock; integrates with _get_shop_button_center / _animate_buy_item_fly_in for overclocked buy juice. Inputs: None. Outputs: None. Side effects: Clears shop_grid, adds buttons, clears selected_shop_meta.
func _populate_shop() -> void:
	for child in shop_grid.get_children():
		child.queue_free()
	selected_shop_meta.clear()
	buy_button.disabled = true

	var rep_bonus_text := ""
	if CampaignManager.merchant_reputation > 0:
		rep_bonus_text = " (Rep Discount: " + str(CampaignManager.merchant_reputation * 2) + "%)"

	for i in range(shop_stock.size()):
		var item = shop_stock[i]
		var final_price := _get_final_price(item)
		var is_on_sale: bool = (item == discounted_item or item == CampaignManager.camp_second_discount_item)
		var deal_tag: String = ""
		if item == discounted_item:
			deal_tag = "spotlight"
		elif item == CampaignManager.camp_second_discount_item:
			deal_tag = "second"

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(88, 88)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.add_theme_font_size_override("font_size", 20)
		shop_grid.add_child(btn)

		var state := {"is_empty": false, "is_on_sale": is_on_sale}
		_style_item_button(btn, item, state)

		if item.get("icon") != null:
			btn.icon = item.icon
			btn.expand_icon = true
		else:
			var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
			btn.text = str(i_name).substr(0, 3) if i_name else "???"

		var tag_color: Color = Color.KHAKI
		if is_on_sale:
			tag_color = Color(0.45, 0.95, 0.72, 1.0) if deal_tag == "second" else Color.YELLOW
		var price_lbl := _add_item_corner_label(btn, tag_color)
		price_lbl.text = str(final_price) + "G"

		if item.get_meta("is_locked", false) == true:
			_add_item_lock_star(btn)

		var meta := {"index": i, "item": item, "price": final_price, "is_sale": is_on_sale, "deal_tag": deal_tag, "rep_text": rep_bonus_text}
		btn.set_meta("shop_data", meta)
		btn.pressed.connect(func(): _on_shop_grid_item_clicked(btn, meta))
	_sync_haggle_button_availability()

func _sync_haggle_button_availability() -> void:
	if haggle_button == null:
		return
	haggle_button.disabled = shop_stock.is_empty() or haggle_active

func _on_shop_grid_item_clicked(btn: Button, meta: Dictionary) -> void:
	if select_sound and select_sound.stream != null:
		select_sound.pitch_scale = 1.2
		select_sound.play()
		
	selected_shop_meta = meta
	
	for child in shop_grid.get_children():
		child.modulate = Color.WHITE
	btn.modulate = Color(1.5, 1.5, 1.5)
	
	var item = meta["item"]
	
	# --- WEAPON COMPARE FETCH ---
	var current_equipped = null
	if selected_roster_index >= 0 and selected_roster_index < CampaignManager.player_roster.size():
		current_equipped = CampaignManager.player_roster[selected_roster_index].get("equipped_weapon")
		
	var text_details = _get_item_detailed_info(item, meta["price"], 1, current_equipped, "Merchant stock")
	
	if meta.get("deal_tag", "") == "spotlight":
		var extra_pct: int = int(roundf(CampaignManager.camp_haggle_extra_off * 100.0))
		var bonus_line: String = ""
		if extra_pct > 0:
			bonus_line = "[color=#b8f0c8]Haggle sweetener: −%d%% on this slot.[/color]\n" % extra_pct
		text_details = (
			"[center][font_size=15][color=#e8c040]Daily spotlight[/color][color=#6e624c] · [/color]"
			+ "[color=#9cdf7a]−50%[/color][/font_size][/center]\n"
			+ bonus_line + "\n"
			+ text_details
		)
	elif meta.get("deal_tag", "") == "second":
		text_details = (
			"[center][font_size=15][color=#7ae8c8]Haggle bonus shelf[/color][color=#6e624c] · [/color]"
			+ "[color=#9cdf7a]−50%[/color][/font_size][/center]\n\n"
			+ text_details
		)
	if meta["rep_text"] != "":
		text_details += "\n[color=lime]" + meta["rep_text"] + "[/color]"
		
	shop_desc.text = text_details
	buy_button.disabled = false
	
func _on_buy_pressed() -> void:
	if selected_shop_meta.is_empty(): return
	var item = selected_shop_meta["item"]
	var final_price = selected_shop_meta["price"]
	var item_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
	
	# Determine if it's a stackable item (Potions, Materials, Keys)
	var is_stackable = (item is ConsumableData) or (item is ChestKeyData) or (item is MaterialData)
	
	if is_stackable:
		# Max amount is based on how much gold they currently have!
		var max_can_afford = int(CampaignManager.global_gold / max(1, final_price))
		if max_can_afford < 1:
			_update_merchant_text("poor")
			return
			
		qty_mode = "buy"
		qty_base_price = final_price
		qty_max_amount = min(max_can_afford, 99) # Cap at 99 so the slider isn't impossible to use
		_open_quantity_popup(item_name, qty_max_amount, final_price)
	else:
		# Standard 1-item buy confirmation for Weapons/Armor
		buy_confirmation.dialog_text = "Buy " + str(item_name) + " for " + str(final_price) + "G?"
		buy_confirmation.popup_centered()
		
# --- AI/Reviewer: Shop transaction "juice" – flying gold (sell) and flying item (buy). ---
# Helpers: _animate_sell_gold_fountain (coins burst then suck to gold_label), _animate_buy_item_fly_in (icon arcs to inventory).
# Audio: shop_sell_sound at burst start; shop_buy_sound at item pop. Gold label updates when coins impact.

## Spawns a burst of gold coins at origin, tweens them outward then into gold_label; updates label as coins hit.
## Purpose: Visual feedback for selling. Optimized timings: burst 0.14s, hang 0.04s + i*0.02s, fly 0.18s, pulse 0.08s (overclocked ~45%).
## Inputs: origin_global (Vector2), gold_gained (int). Outputs: None. Side effects: Adds temporary Controls, updates gold_label, plays shop_sell_sound.
func _animate_sell_gold_fountain(origin_global: Vector2, gold_gained: int) -> void:
	if gold_label == null || gold_gained <= 0:
		return
	if shop_sell_sound:
		shop_sell_sound.play()
	var visual_gold_ref: Array = [CampaignManager.global_gold - gold_gained]
	var coin_count: int = mini(gold_gained, 12)
	var gold_per_coin: int = ceili(float(gold_gained) / float(coin_count))
	var target_center: Vector2 = gold_label.global_position + (gold_label.size / 2.0)
	for i in range(coin_count):
		var coin := ColorRect.new()
		coin.custom_minimum_size = Vector2(14, 14)
		coin.color = Color(1.0, 0.82, 0.15)
		coin.position = origin_global - (coin.custom_minimum_size / 2.0)
		add_child(coin)
		coin.z_index = 200
		var t := create_tween()
		var burst_offset := Vector2(randf_range(-55, 55), randf_range(-65, -25))
		t.tween_property(coin, "global_position", origin_global + burst_offset - (coin.custom_minimum_size / 2.0), 0.14).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.04 + (i * 0.02))
		var dest := target_center - (coin.custom_minimum_size / 2.0)
		t.tween_property(coin, "global_position", dest, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		var is_last: bool = (i == coin_count - 1)
		t.tween_callback(func():
			coin.queue_free()
			visual_gold_ref[0] += gold_per_coin
			if is_last || visual_gold_ref[0] >= CampaignManager.global_gold:
				visual_gold_ref[0] = CampaignManager.global_gold
			gold_label.text = "Gold: %dG" % visual_gold_ref[0]
			gold_label.scale = Vector2(1.08, 1.08)
			var pulse := create_tween()
			pulse.tween_property(gold_label, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_BOUNCE)
		)

## Spawns a flying item icon from origin to target (pop, arc, shrink). Plays shop_buy_sound at pop.
## Purpose: Visual feedback for buying. Optimized timings: pop 0.09s/0.05s, arc 0.13s/0.14s, shrink 0.09s (overclocked ~40–50%).
## Inputs: origin_global, target_global (Vector2), item (Resource with optional "icon"). Outputs: None. Side effects: Adds TextureRect, plays shop_buy_sound.
func _animate_buy_item_fly_in(origin_global: Vector2, target_global: Vector2, item: Resource) -> void:
	var fly: Control
	if item != null and item.get("icon") != null:
		var tex := TextureRect.new()
		tex.texture = item.get("icon")
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fly = tex
	else:
		var rect := ColorRect.new()
		rect.color = Color(0.4, 0.6, 0.9)
		fly = rect
	fly.custom_minimum_size = Vector2(48, 48)
	fly.position = origin_global - (fly.custom_minimum_size / 2.0)
	fly.z_index = 200
	add_child(fly)
	if shop_buy_sound:
		shop_buy_sound.play()
	fly.scale = Vector2.ZERO
	var t := create_tween()
	t.tween_property(fly, "scale", Vector2(1.15, 1.15), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(fly, "scale", Vector2(1.0, 1.0), 0.05)
	var mid := origin_global.lerp(target_global, 0.5) + Vector2(0, -60)
	t.tween_property(fly, "global_position", mid - (fly.custom_minimum_size / 2.0), 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(fly, "global_position", target_global - (fly.custom_minimum_size / 2.0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(fly, "scale", Vector2(0.2, 0.2), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(fly.queue_free)

## Returns global center of the shop grid button at index (for fly-in origin). Safe if child missing.
## Inputs: index (int). Outputs: Vector2. Side effects: None.
func _get_shop_button_center(index: int) -> Vector2:
	if shop_grid == null || index < 0 || index >= shop_grid.get_child_count():
		return get_viewport_rect().get_center()
	var btn: Control = shop_grid.get_child(index)
	return btn.global_position + (btn.size / 2.0)

## Completes a single-item purchase: deducts gold, adds item, runs fly-in animation, then refreshes UI.
## Purpose: Buy flow with juice. Captures shop button center before repopulating for animation origin.
## Inputs: None (uses selected_shop_meta). Outputs: None. Side effects: CampaignManager, shop_stock, gold_label, inventory, shop grid; plays shop_buy_sound during animation.
func _on_buy_confirmed() -> void:
	if selected_shop_meta.is_empty(): return
	var index: int = selected_shop_meta["index"]
	var item = selected_shop_meta["item"]
	var final_price: int = selected_shop_meta["price"]
	if CampaignManager.global_gold < final_price:
		_update_merchant_text("poor")
		return
	var shop_origin: Vector2 = _get_shop_button_center(index)
	CampaignManager.global_gold -= final_price
	var dup_item = CampaignManager.duplicate_item(item)
	var is_recipe: bool = _try_unlock_recipe(dup_item)
	if not is_recipe:
		CampaignManager.global_inventory.append(dup_item)
	_update_merchant_text("buy")
	shop_stock.remove_at(index)
	CampaignManager.camp_shop_stock = shop_stock.duplicate()
	if item == discounted_item:
		discounted_item = null
		CampaignManager.camp_discount_item = null
	if item == CampaignManager.camp_second_discount_item:
		CampaignManager.camp_second_discount_item = null
	_refresh_gold_label()
	var inv_target: Vector2 = (inventory_desc.global_position + inventory_desc.size / 2.0) if inventory_desc else (get_viewport_rect().get_center())
	_animate_buy_item_fly_in(shop_origin, inv_target, dup_item)
	_populate_inventory()
	_populate_shop()
	shop_desc.text = ""
		
# --- POPULATE THE CONVOY ---
func _populate_inventory() -> void:
	_clear_grids()
	_camp_inventory_desc_set_text("Select an item to view details.")
	
	# 1. FIND THE CURRENTLY SELECTED UNIT
	var unit_data = null
	var unit_idx = -1
	if selected_roster_index >= 0 and selected_roster_index < CampaignManager.player_roster.size():
		unit_idx = selected_roster_index
		unit_data = CampaignManager.player_roster[unit_idx]

	# 2. BUILD THE UNIT'S PERSONAL 5-SLOT GRID
	if unit_data != null:
		if not unit_data.has("inventory"): unit_data["inventory"] = []
		_build_unit_grid(unit_data, unit_idx)

	# 3. GATHER THE SHARED POOL (Convoy + Other Units)
	var current_tab = category_tabs.current_tab
	var shared_pool = []

	# A. Gather Pure Convoy Items
	for i in range(CampaignManager.global_inventory.size()):
		shared_pool.append({"source": "convoy", "index": i, "item": CampaignManager.global_inventory[i]})

	# B. Gather Other Units' Items
	for u_idx in range(CampaignManager.player_roster.size()):
		if u_idx == unit_idx: continue # Skip the currently selected unit
		
		var other_data = CampaignManager.player_roster[u_idx]
		if other_data.has("inventory"):
			for inv_idx in range(other_data["inventory"].size()):
				var o_item = other_data["inventory"][inv_idx]
				if o_item != null:
					shared_pool.append({
						"source": "other_unit", "unit_index": u_idx, "inv_index": inv_idx,
						"item": o_item, "owner_name": other_data["unit_name"],
						"is_equipped": (o_item == other_data.get("equipped_weapon"))
					})

	# C. FILTER AND STACK FOR THE CONVOY GRID
	var filtered_items = []
	var stacked_materials = {}

	for data in shared_pool:
		var item = data["item"]
		var should_show = false
		
		match current_tab:
			0: should_show = true
			1: if item is WeaponData: should_show = true
			2: if not (item is WeaponData): should_show = true
			3: if data["source"] == "convoy": should_show = true # CONVOY ONLY TAB
		
		if should_show:
			var can_stack = (item is ConsumableData) or (item is ChestKeyData) or (item is MaterialData)
			
			if can_stack and data["source"] == "convoy":
				var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
				if stacked_materials.has(i_name):
					stacked_materials[i_name]["count"] += 1
				else:
					stacked_materials[i_name] = {"count": 1, "data": data}
			else:
				filtered_items.append({"data": data, "count": 1})

	for key in stacked_materials.keys():
		filtered_items.append(stacked_materials[key])

	# 4. BUILD THE SHARED GRID
	_build_shared_grid(filtered_items)
	_camp_try_flash_pending_inv_slot()

	# --- FORCE MATERIAL SCROLL SIZE (Prevents the invisible wall bug!) ---
	if material_scroll:
		material_scroll.set_anchors_preset(Control.PRESET_TOP_LEFT)
		material_scroll.size = Vector2(400, 500) # Restricts the glass to the left side
func _clear_grids() -> void:
	for child in unit_grid.get_children(): child.queue_free()
	for child in convoy_grid.get_children(): child.queue_free()
	selected_inventory_meta.clear()
	equip_button.disabled = true
	unequip_button.disabled = true
	sell_button.disabled = true

# --- AI/Reviewer: Centralized item button styling for Convoy and Shop. Rarity borders, equipped/sale glow, empty-slot look, hover juice (0.1s scale 1.05). Used by _build_unit_grid, _build_shared_grid, _populate_shop. ---
## Applies a unified StyleBoxFlat and optional hover juice to item/convoy/shop buttons.
##
## Purpose: Single source for item button look—rounded corners (8px), subtle inner shadow, rarity-based border (Common=Dark Gray, Uncommon=Lime, Rare=DeepSkyBlue, Epic=MediumOrchid, Legendary=Gold). state.is_equipped or state.is_on_sale → gold border width 3 + modulate boost; state.is_empty → dark semi-transparent slot with dimmed border. Hover: 0.1s tween scale 1.05 and brightness (only when not empty).
##
## Inputs: btn (Button), item (Resource or null for empty slot), state (Dictionary: is_equipped, is_empty, is_on_sale optional).
##
## Outputs: None.
##
## Side effects: Overrides normal/disabled style on btn; connects mouse_entered/mouse_exited for snappy hover tween.
func _style_item_button(btn: Button, item: Resource, state: Dictionary) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 3
	style.shadow_offset = Vector2(1, 1)

	var is_empty: bool = state.get("is_empty", false)
	var is_equipped: bool = state.get("is_equipped", false)
	var is_on_sale: bool = state.get("is_on_sale", false)

	if is_empty:
		style.bg_color = Color(0.06, 0.06, 0.06, 0.5)
		style.border_color = Color(0.2, 0.2, 0.2, 0.7)
		style.set_border_width_all(1)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("disabled", style)
		return

	# Rarity-based border: Common = Dark Gray, Uncommon = Lime, Rare = DeepSkyBlue, Epic = MediumOrchid, Legendary = Gold
	var border_color := Color(0.35, 0.35, 0.35)
	if item != null:
		var rarity_var = item.get("rarity")
		var rarity: String = str(rarity_var) if rarity_var != null else "Common"
		match rarity:
			"Uncommon": border_color = Color(0.2, 1.0, 0.2)
			"Rare": border_color = Color(0.0, 0.75, 1.0)
			"Epic": border_color = Color(0.85, 0.44, 1.0)
			"Legendary": border_color = Color(1.0, 0.84, 0.0)

	if is_equipped or is_on_sale:
		border_color = Color(1.0, 0.84, 0.0)
		style.set_border_width_all(3)
		btn.modulate = Color(1.05, 1.05, 1.05)
		btn.set_meta("hover_base_modulate", Color(1.05, 1.05, 1.05))
	else:
		style.set_border_width_all(2)
		btn.set_meta("hover_base_modulate", Color.WHITE)

	style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	style.border_color = border_color
	btn.add_theme_stylebox_override("normal", style)

	# Snappy hover juice: 0.1s tween scale 1.05 and brightness (only when not disabled/empty)
	if not btn.mouse_entered.is_connected(_on_item_button_hover_entered):
		btn.mouse_entered.connect(_on_item_button_hover_entered.bind(btn))
	if not btn.mouse_exited.is_connected(_on_item_button_hover_exited):
		btn.mouse_exited.connect(_on_item_button_hover_exited.bind(btn))

## Called when mouse enters an item button; runs 0.1s scale/brightness tween (snappy hover juice).
func _on_item_button_hover_entered(btn: Button) -> void:
	if btn == null or btn.disabled:
		return
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(btn, "modulate", Color(1.15, 1.15, 1.15), 0.1)

## Called when mouse exits an item button; restores scale and modulate to base (equipped/sale keep slight boost).
func _on_item_button_hover_exited(btn: Button) -> void:
	if btn == null:
		return
	var base_modulate: Color = btn.get_meta("hover_base_modulate", Color.WHITE)
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(btn, "modulate", base_modulate, 0.1)

## Adds a small gold star overlay (top-right, 4px margin) to indicate locked/favorite item.
## Purpose: Visual indicator for is_locked meta; mouse_filter IGNORE so it does not block clicks. Inputs: btn (parent). Outputs: None. Side effects: Adds one Label child to btn.
func _add_item_lock_star(btn: Button) -> void:
	var lock_lbl := Label.new()
	lock_lbl.text = "★"
	lock_lbl.add_theme_font_size_override("font_size", 20)
	lock_lbl.add_theme_color_override("font_color", Color.GOLD)
	lock_lbl.add_theme_constant_override("outline_size", 4)
	lock_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lock_lbl)
	lock_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lock_lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lock_lbl.offset_top = 4
	lock_lbl.offset_right = -4

## Creates a bottom-right label (font 20px, 4px margin) for price or stack count.
## Purpose: Unified price tags (shop) and stack counters (convoy). Inputs: btn (parent), font_color (default KHAKI). Outputs: Label (caller sets text). Side effects: Adds one Label child to btn; mouse_filter IGNORE.
func _add_item_corner_label(btn: Button, font_color: Color = Color.KHAKI) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", font_color)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lbl.offset_right = -4
	lbl.offset_bottom = -4
	return lbl


func _add_item_equipped_badge(btn: Button) -> void:
	if btn == null or btn.get_node_or_null("EquippedBadge") != null:
		return
	var badge := Label.new()
	badge.name = "EquippedBadge"
	badge.text = "E"
	badge.add_theme_font_size_override("font_size", 15)
	badge.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	badge.add_theme_constant_override("outline_size", 4)
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(badge)
	badge.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	badge.offset_left = 4
	badge.offset_bottom = -2
	badge.grow_horizontal = Control.GROW_DIRECTION_END


func _play_camp_inv_sfx_equip() -> void:
	if select_sound != null and select_sound.stream != null:
		select_sound.pitch_scale = randf_range(0.86, 0.98)
		select_sound.play()


func _play_camp_inv_sfx_use() -> void:
	if use_item_sound != null and use_item_sound.stream != null:
		use_item_sound.pitch_scale = randf_range(1.08, 1.24)
		use_item_sound.play()
	elif select_sound != null and select_sound.stream != null:
		select_sound.pitch_scale = randf_range(1.14, 1.28)
		select_sound.play()


func _play_camp_inv_sfx_invalid() -> void:
	if select_sound != null and select_sound.stream != null:
		select_sound.pitch_scale = randf_range(0.70, 0.82)
		select_sound.play()


func _play_camp_inv_slot_flash(btn: Button) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	var peak := Vector2(1.11, 1.11)
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", peak, 0.085)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.11)
	var base_col: Color = btn.get_meta("hover_base_modulate", Color.WHITE)
	var tw2 := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(btn, "modulate", base_col * Color(1.32, 1.22, 1.05), 0.07)
	tw2.tween_property(btn, "modulate", base_col, 0.13)


func _camp_try_flash_pending_inv_slot() -> void:
	if _camp_inv_flash_item == null:
		return
	var want: Resource = _camp_inv_flash_item
	_camp_inv_flash_item = null
	for grid in [unit_grid, convoy_grid]:
		if grid == null:
			continue
		for c in grid.get_children():
			if c is Button and (c as Button).has_meta("inv_data"):
				var d: Dictionary = (c as Button).get_meta("inv_data") as Dictionary
				if d.get("item") == want:
					_play_camp_inv_slot_flash(c as Button)
					return

## Builds the unit's 5-slot personal inventory grid. Uses _style_item_button for unified look; lock star overlay (top-right, non-blocking); equips/drag/press wired.
## Purpose: Populate unit_grid with item buttons or empty slots. Inputs: unit_data, unit_idx. Outputs: None. Side effects: Adds buttons to unit_grid, connects gui_input/pressed/drag.
func _build_unit_grid(unit_data: Dictionary, unit_idx: int) -> void:
	var inv = unit_data.get("inventory", [])
	var equipped = unit_data.get("equipped_weapon")

	for i in range(5):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(88, 88)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.add_theme_font_size_override("font_size", 20)
		unit_grid.add_child(btn)

		if i < inv.size() and inv[i] != null:
			var item = inv[i]
			var state := {"is_empty": false, "is_equipped": (item == equipped)}
			_style_item_button(btn, item, state)

			btn.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
					if item != null:
						var is_locked = item.get_meta("is_locked", false)
						item.set_meta("is_locked", not is_locked)
						if select_sound: select_sound.play()
						_populate_inventory()
			)

			if item.get("icon") != null:
				btn.icon = item.icon
				btn.expand_icon = true
			else:
				var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
				btn.text = str(i_name).substr(0, 3) if i_name else "???"

			if item != null and item.get_meta("is_locked", false) == true:
				_add_item_lock_star(btn)
			if state.get("is_equipped", false):
				_add_item_equipped_badge(btn)

			var meta = {"source": "unit", "unit_index": unit_idx, "inv_index": i, "item": item, "count": 1}
			btn.set_meta("inv_data", meta)
			btn.set_drag_forwarding(_get_drag_inventory.bind(btn, meta), Callable(), Callable())
			btn.pressed.connect(func(): _on_grid_item_clicked(btn, meta))
		else:
			_style_item_button(btn, null, {"is_empty": true})
			btn.disabled = true
												
## Builds the shared convoy/other-units grid. Uses _style_item_button; stack counter and lock star via helpers; owner tag for other_unit.
## Purpose: Populate convoy_grid with filtered items. Inputs: filtered_items (Array of {data, count}). Outputs: None. Side effects: Adds buttons to convoy_grid.
func _build_shared_grid(filtered_items: Array) -> void:
	for item_dict in filtered_items:
		var data = item_dict["data"]
		var item = data["item"]
		var count: int = item_dict["count"]

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(88, 88)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.add_theme_font_size_override("font_size", 20)
		convoy_grid.add_child(btn)

		var state := {"is_empty": false, "is_equipped": data.get("is_equipped", false)}
		_style_item_button(btn, item, state)

		btn.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
				if item != null:
					var is_locked = item.get_meta("is_locked", false)
					item.set_meta("is_locked", not is_locked)
					if select_sound: select_sound.play()
					_populate_inventory()
		)

		if item.get("icon") != null:
			btn.icon = item.icon
			btn.expand_icon = true
		else:
			var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
			btn.text = str(i_name).substr(0, 3) if i_name else "???"

		if item != null and item.get_meta("is_locked", false) == true:
			_add_item_lock_star(btn)
		if state.get("is_equipped", false):
			_add_item_equipped_badge(btn)

		if count > 1:
			var count_lbl := _add_item_corner_label(btn, Color.WHITE)
			count_lbl.text = "x" + str(count)

		if data["source"] == "other_unit":
			var owner_lbl := Label.new()
			owner_lbl.text = str(data["owner_name"]).substr(0, 3).to_upper()
			owner_lbl.add_theme_font_size_override("font_size", 18)
			owner_lbl.add_theme_color_override("font_color", Color.ORANGE)
			owner_lbl.add_theme_constant_override("outline_size", 6)
			owner_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			owner_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(owner_lbl)
			owner_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
			owner_lbl.offset_left = 4
			owner_lbl.offset_top = 4

		var meta: Dictionary = data.duplicate()
		meta["count"] = count
		btn.set_meta("inv_data", meta)
		btn.pressed.connect(func(): _on_grid_item_clicked(btn, meta))
					
func _on_grid_item_clicked(btn: Button, meta: Dictionary) -> void:
	if select_sound and select_sound.stream != null:
		select_sound.pitch_scale = 1.2
		select_sound.play()

	selected_inventory_meta = meta

	for child in unit_grid.get_children() + convoy_grid.get_children():
		child.modulate = Color.WHITE
	btn.modulate = Color(1.5, 1.5, 1.5)

	var item = meta["item"]
	var count = meta.get("count", 1)
	var sell_val = int(item.get("gold_cost") / 2) if item.get("gold_cost") != null else 0

	var inv_ctx: String = ""
	match meta["source"]:
		"convoy":
			inv_ctx = "Convoy supplies"
		"unit":
			inv_ctx = "Personal loadout"
		"other_unit":
			inv_ctx = str(meta.get("owner_name", "Ally")) + "'s pack"

	var current_equipped = null
	if selected_roster_index >= 0 and selected_roster_index < CampaignManager.player_roster.size():
		current_equipped = CampaignManager.player_roster[selected_roster_index].get("equipped_weapon")

	var desc = _get_item_detailed_info(item, sell_val, count, current_equipped, inv_ctx)
	_camp_inventory_desc_set_text(desc)

	# --- DYNAMIC BUTTON ENABLE/DISABLE LOGIC ---
	equip_button.disabled = false
	var is_locked = item.get_meta("is_locked", false)
	sell_button.disabled = is_locked # Prevents selling locked items!
	use_button.disabled = not (item is ConsumableData) or is_locked
	
	if meta["source"] == "unit":
		var unit_data = CampaignManager.player_roster[meta["unit_index"]]
		var is_equipped = (meta["item"] == unit_data.get("equipped_weapon"))
		equip_button.text = "Unequip" if is_equipped else "Equip"
		unequip_button.text = "Store"
		unequip_button.disabled = false
		if not (meta["item"] is WeaponData): equip_button.disabled = true
			
	elif meta["source"] == "other_unit":
		equip_button.text = "Give"
		unequip_button.text = "Store"
		unequip_button.disabled = false
		
	else: 
		equip_button.text = "Give"
		unequip_button.text = "---"
		unequip_button.disabled = true
			
# --- AI/Reviewer: Roster grid uses class tier border colors (Rookie/Normal/Promoted/Ascended) via _get_class_tier_color. Selection highlight applied in _populate_roster and _on_roster_item_selected. ---
## Maps a class name to its tier border color for roster buttons (instant visual feedback on unit tier).
##
## Purpose: Central tier→color mapping. Rookie #8c8c8c, Normal #4a9eff, Promoted #ffcc00, Ascended #00ffff. Unknown classes default to Normal.
##
## Inputs: job_or_class_name (String). Outputs: Color. Side effects: None.
func _get_class_tier_color(job_or_class_name: String) -> Color:
	var key := job_or_class_name.strip_edges().to_lower()
	if key.is_empty():
		return Color(0.29, 0.62, 1.0) # Normal default
	# Rookie (Bronze/Iron)
	var rookie: PackedStringArray = ["recruit", "apprentice", "urchin", "novice", "villager"]
	if key in rookie:
		return Color(0.55, 0.55, 0.55) # #8c8c8c
	# Normal (Steel/Blue)
	var normal: PackedStringArray = ["archer", "cleric", "knight", "mage", "mercenary", "monk", "monster", "paladin", "spellblade", "thief", "warrior", "flier", "dancer", "beastmaster", "cannoneer"]
	if key in normal:
		return Color(0.29, 0.62, 1.0) # #4a9eff
	# Promoted (Gold/Orange)
	var promoted: PackedStringArray = ["assassin", "berserker", "blademaster", "bladeweaver", "bowknight", "deathknight", "divinesage", "firesage", "general", "greatknight", "heavyarcher", "hero", "highpaladin", "falconknight", "skyvanguard", "muse", "bladedancer", "wildwarden", "packleader", "siegemaster", "dreadnought"]
	if key in promoted:
		return Color(1.0, 0.8, 0.0) # #ffcc00
	# Ascended (Celestial/Cyan)
	var ascended: PackedStringArray = ["dawnexalt", "voidstrider", "riftarchon"]
	if key in ascended:
		return Color(0.0, 1.0, 1.0) # #00ffff
	return Color(0.29, 0.62, 1.0) # Normal default for unknown

## Populates the roster grid with unit buttons; applies class-tier border colors and selected-state cyan highlight.
##
## Purpose: Build roster_grid with 8px rounded StyleBoxFlat, dark charcoal bg (#1a1a1a), tier-colored border (width 3). Selected unit gets cyan glow and double border. Class name resolved from unit_class, class_data.job_name, or base data.
##
## Inputs: None. Outputs: None. Side effects: Clears roster_grid, adds buttons, connects pressed.
func _populate_roster() -> void:
	for child in roster_grid.get_children():
		child.queue_free()

	for i in range(CampaignManager.player_roster.size()):
		var unit_data = CampaignManager.player_roster[i]
		var class_name_for_tier: String = _resolve_unit_class_name(unit_data)
		var tier_color: Color = _get_class_tier_color(class_name_for_tier)
		var is_selected: bool = (i == selected_roster_index)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(88, 88)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(8)
		style.bg_color = Color(0.102, 0.102, 0.102) # #1a1a1a dark charcoal
		style.set_border_width_all(3)
		style.border_color = Color.CYAN if is_selected else tier_color
		if is_selected:
			btn.modulate = Color(1.15, 1.15, 1.15)
		btn.add_theme_stylebox_override("normal", style)
		btn.set_meta("tier_color", tier_color)

		# Bulletproof sprite: battle_sprite, then data.battle_sprite, then data.unit_sprite
		var sprite_tex = null
		if unit_data.get("battle_sprite") != null:
			sprite_tex = unit_data["battle_sprite"]
		elif unit_data.get("data") != null and unit_data["data"].get("battle_sprite") != null:
			sprite_tex = unit_data["data"].battle_sprite
		elif unit_data.get("data") != null and unit_data["data"].get("unit_sprite") != null:
			sprite_tex = unit_data["data"].unit_sprite
		if sprite_tex != null:
			btn.icon = sprite_tex
			btn.expand_icon = true
		else:
			btn.text = str(unit_data.get("unit_name", "???")).substr(0, 3).to_upper()

		# Level tag: bottom-right, 4px margin (consistent with item corner labels)
		var lvl_lbl := Label.new()
		lvl_lbl.text = "Lv" + str(unit_data.get("level", 1))
		lvl_lbl.add_theme_font_size_override("font_size", 18)
		lvl_lbl.add_theme_color_override("font_color", Color.WHITE)
		lvl_lbl.add_theme_constant_override("outline_size", 6)
		lvl_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lvl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lvl_lbl)
		lvl_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		lvl_lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		lvl_lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
		lvl_lbl.offset_right = -4
		lvl_lbl.offset_bottom = -4

		var uid: String = unit_data.get("unit_name", "Hero")
		var cands: Array = []
		for u in CampaignManager.player_roster:
			var oname: String = u.get("unit_name", "")
			if oname != uid and not oname.is_empty():
				cands.append(oname)
		var rels: Array = CampaignManager.get_top_relationship_entries_for_unit(uid, cands, 5)
		var tip_parts: Array = []
		for e in rels:
			tip_parts.append(CampaignManager.format_relationship_tooltip(e))
		btn.tooltip_text = "\n".join(tip_parts) if not tip_parts.is_empty() else "No bonds with current roster."

		var badge_box := HBoxContainer.new()
		badge_box.name = "RelationshipBadges"
		badge_box.add_theme_constant_override("separation", 2)
		badge_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
		badge_box.offset_left = 4
		badge_box.offset_top = 4
		badge_box.offset_right = 50
		badge_box.offset_bottom = 22
		var top_rels: Array = CampaignManager.get_top_relationship_entries_for_unit(uid, cands, 3)
		for e in top_rels:
			var stat: String = e.get("stat", "")
			var col: Color = CampaignManager.get_relationship_type_color(stat)
			var tip: String = CampaignManager.format_relationship_tooltip(e)
			var rect := ColorRect.new()
			rect.custom_minimum_size = Vector2(14, 14)
			rect.size = Vector2(14, 14)
			rect.color = col
			rect.tooltip_text = tip
			rect.mouse_filter = Control.MOUSE_FILTER_STOP
			badge_box.add_child(rect)
		btn.add_child(badge_box)

		btn.pressed.connect(func():
			if select_sound and select_sound.stream != null:
				select_sound.play()
			_on_roster_item_selected(i)
		)
		roster_grid.add_child(btn)

## Resolves the unit's class name from unit_data for tier color lookup.
## Purpose: Prefer unit_class string, then class_data.job_name, then base data character_class.job_name. Inputs: unit_data (Dictionary). Outputs: String. Side effects: None.
func _resolve_unit_class_name(unit_data: Dictionary) -> String:
	var name_from_key: Variant = unit_data.get("unit_class")
	if name_from_key != null and str(name_from_key).strip_edges().length() > 0:
		return str(name_from_key)
	var class_res: Variant = unit_data.get("class_data")
	if class_res is String and ResourceLoader.exists(class_res):
		class_res = load(class_res)
	if class_res != null and class_res.get("job_name") != null:
		return str(class_res.get("job_name"))
	var base_data: Variant = unit_data.get("data")
	if base_data is String and ResourceLoader.exists(base_data):
		base_data = load(base_data)
	if base_data != null and base_data.get("character_class") != null:
		var cc = base_data.get("character_class")
		if cc != null and cc.get("job_name") != null:
			return str(cc.get("job_name"))
	return ""

func _on_roster_item_selected(index: int) -> void:
	# --- NEW VISUAL HIGHLIGHT LOGIC ---
	selected_roster_index = index
	var current_idx = 0
	for child in roster_grid.get_children():
		if child is Button:
			var h_style = child.get_theme_stylebox("normal").duplicate()
			if current_idx == index:
				child.modulate = Color(1.5, 1.5, 1.5)
				h_style.border_color = Color.CYAN
				h_style.set_border_width_all(3)
				child.add_theme_stylebox_override("normal", h_style)
			else:
				child.modulate = Color.WHITE
				var tier_color_restore: Color = child.get_meta("tier_color", Color(0.29, 0.62, 1.0))
				h_style.border_color = tier_color_restore
				h_style.set_border_width_all(3)
				child.add_theme_stylebox_override("normal", h_style)
		current_idx += 1
	# ----------------------------------
	
	# 1. Safety Check: Ensure the roster isn't empty
	if CampaignManager.player_roster.is_empty(): return
	var unit_data = CampaignManager.player_roster[index]
	
	# 2. Safety Check: If 'data' is still a path string, re-load it now
	var base_data = unit_data.get("data") 
	if base_data is String:
		if ResourceLoader.exists(base_data):
			base_data = load(base_data)
			unit_data["data"] = base_data 

	# --- 1. SHOW PORTRAIT ---
	var custom_portrait = unit_data.get("portrait")
	if custom_portrait is String and ResourceLoader.exists(custom_portrait):
		custom_portrait = load(custom_portrait)
		unit_data["portrait"] = custom_portrait

	if custom_portrait is Texture2D:
		portrait_rect.texture = custom_portrait
		portrait_rect.visible = true
	elif base_data != null and base_data.get("portrait") != null:
		portrait_rect.texture = base_data.portrait
		portrait_rect.visible = true
	else:
		portrait_rect.visible = false
	
	# --- 2. Commander card: name, level, HP, class (details in Unit Dossier panel). ---
	var unit_name: String = str(unit_data.get("unit_name", "Hero"))
	var current_level: int = int(unit_data.get("level", 1))
	var cur_hp: int = int(unit_data.get("current_hp", 0))
	var max_hp: int = maxi(1, int(unit_data.get("max_hp", cur_hp)))
	var weapon_value: Variant = unit_data.get("equipped_weapon")
	var weapon_res: Resource = null
	if weapon_value is String and ResourceLoader.exists(weapon_value):
		weapon_res = load(weapon_value)
		unit_data["equipped_weapon"] = weapon_res
	elif weapon_value is Resource:
		weapon_res = weapon_value
	var weapon_marker: String = _camp_weapon_marker(weapon_res) if weapon_res != null else "--"
	var weapon_title: String = "UNARMED" if weapon_res == null else _get_item_display_name(weapon_res)
	var class_title: String = _resolve_unit_class_name(unit_data).strip_edges()
	if class_title.is_empty():
		class_title = str(unit_data.get("unit_class", "")).strip_edges()
	if class_title.is_empty():
		class_title = "—"
	var hp_color := "#9bea9b" if cur_hp > float(max_hp) * 0.35 else "#e8a077"
	if stats_label:
		stats_label.bbcode_enabled = true
		stats_label.text = (
			"[center]"
			+ "[font_size=32][color=#7bdcff]" + unit_name.to_upper() + "[/color][/font_size]\n"
			+ "[font_size=22][color=#cfc7be]Lv " + str(current_level) + "[/color][/font_size]\n"
			+ "[font_size=20][color=" + hp_color + "]HP " + str(cur_hp) + " / " + str(max_hp) + "[/color][/font_size]\n"
			+ "[font_size=18][color=#d4b87a]" + class_title.to_upper() + "[/color][/font_size]\n"
			+ "[font_size=18][color=#e8dbc0]" + weapon_marker + " " + weapon_title.to_upper() + "[/color][/font_size]"
			+ "[/center]"
		)

	# --- 3. Weapon sync: ensure equipped weapon is in unit inventory (data integrity). ---
	var wpn = unit_data.get("equipped_weapon")
	if wpn is String and ResourceLoader.exists(wpn):
		wpn = load(wpn)
		unit_data["equipped_weapon"] = wpn
	if wpn is WeaponData:
		if not unit_data.has("inventory"): unit_data["inventory"] = []
		if not unit_data["inventory"].has(wpn):
			if unit_data["inventory"].size() < 5:
				unit_data["inventory"].append(wpn)
			else:
				CampaignManager.global_inventory.append(wpn)
				unit_data["equipped_weapon"] = null

	# --- 4. Inspect button: wire once, then show for selected unit (opens unit_info_panel like BattleField). ---
	if inspect_unit_btn != null:
		if not inspect_unit_btn.pressed.is_connected(_on_inspect_unit_pressed):
			inspect_unit_btn.pressed.connect(_on_inspect_unit_pressed)
		inspect_unit_btn.visible = true

	_populate_inventory()

	if swap_ability_btn:
		var ab_list = unit_data.get("unlocked_abilities", [])
		swap_ability_btn.visible = ab_list.size() > 1

	# --- 5. Skill tree button: visible only if class has a skill tree. ---
	var class_res = unit_data.get("class_data")
	if class_res is String and ResourceLoader.exists(class_res):
		class_res = load(class_res)
	if open_skills_btn:
		open_skills_btn.visible = false
		if class_res != null:
			# Use "in" to safely check if the property exists on the Resource
			if "class_skill_tree" in class_res and class_res.class_skill_tree != null:
				open_skills_btn.visible = true
				
				# Check for available points
				var sp = unit_data.get("skill_points", 0)
				if sp > 0:
					open_skills_btn.text = "SKILL TREE (" + str(sp) + ")"
					open_skills_btn.modulate = Color(0.2, 1.0, 0.2) # Glowing Green
				else:
					open_skills_btn.text = "Skill Tree"
					open_skills_btn.modulate = Color.WHITE

	if _camp_commander_card.size.x > 10.0:
		_layout_camp_commander_column()

# --- AI/Reviewer: Unit Info panel = inspection flow (like BattleField detailed_unit_info). Entry: InspectUnitButton -> _on_inspect_unit_pressed -> _update_unit_info. ---
# Panel uses %UnitInfoPanel, %UnitInfoPortrait, %UnitInfoName, %UnitInfoStats (RichTextLabel), %UnitInfoCloseButton. Pop-in tween on show.

## Called when %InspectUnitButton is pressed. Opens unit_info_panel for the currently selected roster unit.
## Inputs: None. Outputs: None. Side effects: Calls _update_unit_info with CampaignManager.player_roster[selected_roster_index].
func _on_inspect_unit_pressed() -> void:
	if CampaignManager.player_roster.is_empty() or selected_roster_index < 0 or selected_roster_index >= CampaignManager.player_roster.size():
		return
	var unit_data: Dictionary = CampaignManager.player_roster[selected_roster_index]
	_update_unit_info(unit_data)

# --- AI/Reviewer: Unit Info has two theatrical phases. Phase 1 = combat stat bars (%HpStatBar … %AgiStatBar), Phase 2 = growth bars (%HpGrowthBar … %AgiGrowthBar). Optimized timings: panel pop-in 0.12s, bar fade 0.10s, fill 0.25s, cascade stagger 0.04s between bars. Phase 2 starts after Phase 1 completes. ---
## Populates and shows the unit_info_panel with portrait, name, BBCode reference text, and two sequential bar phases (combat stats then growth potential) with sheen.
##
## Purpose: Phase 1 reveals combat stats one-by-one with fill + sheen; Phase 2 reveals growth % the same way. Overclocked: pop-in 0.12s (near-instant), bar fill 0.25s, stagger 0.04s (cascade feel). %UnitInfoStats keeps headers/text for reference.
##
## Inputs: unit_data (Dictionary) – roster unit (unit_name, level, portrait, unit_class, data, class_data, combat stats, equipped_weapon, ability).
##
## Outputs: None.
##
## Side effects: Sets portrait/name/stats/close; Phase 1/2: reset bars, attach sheen, sequential reveal with optimized timings; populates %UnitInfoStats BBCode.
func _update_unit_info(unit_data: Dictionary) -> void:
	if unit_info_panel == null:
		return
	_ensure_camp_detailed_unit_info_panel()
	_layout_camp_detailed_unit_info_panel()

	var base_data_value: Variant = unit_data.get("data")
	var base_data: Resource = null
	if base_data_value is String and ResourceLoader.exists(base_data_value):
		base_data = load(base_data_value)
		unit_data["data"] = base_data
	elif base_data_value is Resource:
		base_data = base_data_value
	var class_res_value: Variant = unit_data.get("class_data")
	var class_res: Resource = null
	if class_res_value is String and ResourceLoader.exists(class_res_value):
		class_res = load(class_res_value)
		unit_data["class_data"] = class_res
	elif class_res_value is Resource:
		class_res = class_res_value
	var weapon_value: Variant = unit_data.get("equipped_weapon")
	var weapon: Resource = null
	if weapon_value is String and ResourceLoader.exists(weapon_value):
		weapon = load(weapon_value)
		unit_data["equipped_weapon"] = weapon
	elif weapon_value is Resource:
		weapon = weapon_value
	var portrait: Texture2D = null
	var custom_portrait = unit_data.get("portrait")
	if custom_portrait is String and ResourceLoader.exists(custom_portrait):
		custom_portrait = load(custom_portrait)
		unit_data["portrait"] = custom_portrait
	if custom_portrait is Texture2D:
		portrait = custom_portrait
	elif base_data != null and base_data.get("portrait") != null:
		portrait = base_data.portrait

	var class_label: String = str(unit_data.get("unit_class", "Unknown Class"))
	if class_res != null and class_res.get("job_name") != null:
		class_label = class_res.job_name
	elif base_data != null and base_data.get("character_class") != null and base_data.character_class != null and base_data.character_class.get("job_name") != null:
		class_label = base_data.character_class.job_name

	var level: int = int(unit_data.get("level", 1))
	var move_range: int = int(unit_data.get("move_range", 0))
	var current_hp: int = int(unit_data.get("current_hp", 0))
	var max_hp: int = max(1, int(unit_data.get("max_hp", current_hp)))
	var poise_values: Dictionary = _camp_resolve_poise_values(unit_data)
	var current_poise: int = int(poise_values.get("current", 0))
	var max_poise: int = int(poise_values.get("max", 1))
	var xp_current: int = int(unit_data.get("experience", 0))
	var xp_max: int = max(1, 200 + ((level - 1) * 200))
	var growth_totals: Dictionary = _camp_collect_growth_totals(base_data, class_res)

	if _camp_unit_info_portrait != null:
		_camp_unit_info_portrait.texture = portrait
	if _camp_unit_info_name != null:
		_camp_unit_info_name.text = str(unit_data.get("unit_name", "Hero")).to_upper()
	if _camp_unit_info_meta_label != null:
		_camp_unit_info_meta_label.text = "LV %d  |  MOVE %d  |  CLASS %s" % [level, move_range, class_label.to_upper()]
	if _camp_unit_info_summary_text != null:
		_camp_unit_info_summary_text.text = _camp_build_unit_info_summary_text(unit_data)
	if _camp_unit_info_record_text != null:
		_camp_unit_info_record_text.text = _camp_build_unit_info_record_text(unit_data, class_res)

	if _camp_unit_info_weapon_badge != null and _camp_unit_info_weapon_name != null and _camp_unit_info_weapon_icon != null:
		if weapon == null:
			_camp_unit_info_weapon_badge.text = "--"
			_camp_unit_info_weapon_name.text = "UNARMED"
			_camp_unit_info_weapon_icon.texture = null
		else:
			_camp_unit_info_weapon_badge.text = _camp_weapon_marker(weapon)
			var weapon_name_value: Variant = weapon.get("weapon_name")
			if weapon_name_value == null:
				weapon_name_value = weapon.get("item_name")
			if weapon_name_value == null:
				weapon_name_value = "UNARMED"
			_camp_unit_info_weapon_name.text = str(weapon_name_value).to_upper()
			_camp_unit_info_weapon_icon.texture = weapon.get("icon") if weapon.get("icon") != null else null

	if _camp_unit_info_anim_tween != null:
		_camp_unit_info_anim_tween.kill()
		_camp_unit_info_anim_tween = null

	if _camp_unit_info_dimmer != null:
		_camp_unit_info_dimmer.visible = true
		_camp_unit_info_dimmer.modulate = Color(1, 1, 1, 0)
	if unit_info_panel != null:
		unit_info_panel.visible = true
		unit_info_panel.modulate = Color(1, 1, 1, 0)
		unit_info_panel.scale = Vector2(0.96, 0.96)
		move_child(unit_info_panel, get_child_count() - 1)
		if _camp_unit_info_dimmer != null:
			move_child(_camp_unit_info_dimmer, unit_info_panel.get_index() - 1)

	_camp_build_unit_info_relationship_cards(unit_data)

	var animate_tween := create_tween().set_parallel(true)
	_camp_unit_info_anim_tween = animate_tween
	if _camp_unit_info_dimmer != null:
		animate_tween.tween_property(_camp_unit_info_dimmer, "modulate", Color.WHITE, 0.16)
	animate_tween.tween_property(unit_info_panel, "modulate", Color.WHITE, 0.16)
	animate_tween.tween_property(unit_info_panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var primary_rows := {
		"hp": {"current": current_hp, "max": max_hp, "text": "%d/%d" % [current_hp, max_hp]},
		"poise": {"current": current_poise, "max": max_poise, "text": "%d/%d" % [current_poise, max_poise]},
		"xp": {"current": xp_current, "max": xp_max, "text": "%d/%d" % [xp_current, xp_max]},
	}

	var primary_defs := _camp_unit_info_primary_bar_definitions()
	for idx in range(primary_defs.size()):
		var bar_key: String = str(primary_defs[idx].get("key", ""))
		if not _camp_unit_info_primary_widgets.has(bar_key):
			continue
		var widgets: Dictionary = _camp_unit_info_primary_widgets[bar_key]
		var row_data: Dictionary = primary_rows.get(bar_key, {})
		var current_value: int = int(row_data.get("current", 0))
		var max_value: int = max(1, int(row_data.get("max", 1)))
		var fill_color := _camp_unit_info_primary_fill_color(bar_key, current_value, max_value)
		var panel := widgets.get("panel") as Panel
		var name_label := widgets.get("name") as Label
		var value_chip := widgets.get("value_chip") as Panel
		var value_label := widgets.get("value") as Label
		var bar := widgets.get("bar") as ProgressBar
		var desc_label := widgets.get("desc") as Label
		var sheen := widgets.get("sheen") as ColorRect
		if panel != null:
			var panel_border := Color(min(fill_color.r + 0.08, 1.0), min(fill_color.g + 0.08, 1.0), min(fill_color.b + 0.08, 1.0), 0.76)
			var tinted_fill := Color(lerpf(0.10, fill_color.r, 0.10), lerpf(0.09, fill_color.g, 0.10), lerpf(0.07, fill_color.b, 0.10), 0.92)
			_camp_style_panel(panel, tinted_fill, panel_border, 10, 4)
			panel.modulate = Color(1, 1, 1, 0)
			animate_tween.tween_property(panel, "modulate", Color.WHITE, 0.18).set_delay(float(idx) * 0.05)
		if name_label != null:
			name_label.text = str(primary_defs[idx].get("label", bar_key))
			_camp_style_label(name_label, fill_color, 16, 2)
		if value_chip != null:
			_camp_style_panel(value_chip, Color(0.10, 0.09, 0.07, 0.98), fill_color.lightened(0.10), 6, 3)
		if value_label != null:
			value_label.text = str(row_data.get("text", "0/0"))
			_camp_style_label(value_label, CAMP_TEXT, 18, 2)
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if bar != null:
			bar.max_value = float(max_value)
			bar.value = 0.0
			_camp_style_unit_info_primary_bar(bar, fill_color, bar_key)
			animate_tween.tween_property(bar, "value", clampf(float(current_value), 0.0, float(max_value)), 0.30).set_delay(float(idx) * 0.05)
			if sheen != null:
				_animate_unit_info_bar_sheen(sheen, bar, float(idx) * 0.05 + 0.05)
		if desc_label != null:
			desc_label.text = _camp_unit_info_primary_description(bar_key)
			_camp_style_label(desc_label, CAMP_MUTED, 13, 1)
			desc_label.modulate = Color(1, 1, 1, 0)
			animate_tween.tween_property(desc_label, "modulate", Color.WHITE, 0.16).set_delay(float(idx) * 0.05 + 0.03)

	var stat_defs := _camp_unit_info_stat_definitions()
	for idx in range(stat_defs.size()):
		var stat_key: String = str(stat_defs[idx].get("key", ""))
		if not _camp_unit_info_stat_widgets.has(stat_key):
			continue
		var raw_value: int = int(unit_data.get(stat_key, 0))
		var display_value: float = _camp_unit_info_stat_display_value(raw_value)
		var fill_color := _camp_unit_info_stat_fill_color(stat_key, raw_value)
		var overcap: bool = raw_value >= int(CAMP_UNIT_INFO_STAT_BAR_CAP)
		var widgets: Dictionary = _camp_unit_info_stat_widgets[stat_key]
		var panel := widgets.get("panel") as Panel
		var name_label := widgets.get("name") as Label
		var hints_root := widgets.get("hints") as HBoxContainer
		var value_chip := widgets.get("value_chip") as Panel
		var value_label := widgets.get("value") as Label
		var bar := widgets.get("bar") as ProgressBar
		var desc_label := widgets.get("desc") as Label
		var sheen := widgets.get("sheen") as ColorRect
		if panel != null:
			var tinted_fill := Color(lerpf(0.10, fill_color.r, 0.16), lerpf(0.09, fill_color.g, 0.16), lerpf(0.07, fill_color.b, 0.16), 0.92)
			var stat_border := fill_color if overcap else fill_color.darkened(0.08)
			_camp_style_panel(panel, tinted_fill, stat_border, 10, 4)
			panel.modulate = Color(1, 1, 1, 0)
			animate_tween.tween_property(panel, "modulate", Color.WHITE, 0.16).set_delay(0.16 + float(idx) * 0.04)
		if name_label != null:
			name_label.text = _camp_unit_info_stat_label(stat_key)
			_camp_style_label(name_label, fill_color, 19, 2)
		if hints_root != null:
			for child in hints_root.get_children():
				hints_root.remove_child(child)
				child.queue_free()
			for spec in _camp_unit_info_stat_hint_specs(stat_key):
				var chip := Panel.new()
				chip.custom_minimum_size = Vector2(48, 20)
				var chip_color: Color = spec.get("color", fill_color)
				_camp_style_panel(chip, Color(0.10, 0.09, 0.07, 0.95), chip_color, 5, 2)
				hints_root.add_child(chip)
				var chip_label := Label.new()
				chip_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 1)
				_camp_style_label(chip_label, chip_color, 10, 1)
				chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				chip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				chip_label.text = str(spec.get("text", ""))
				chip.add_child(chip_label)
		if value_chip != null:
			_camp_style_panel(value_chip, Color(0.10, 0.09, 0.07, 0.98), fill_color, 6, 3)
		if value_label != null:
			value_label.text = str(raw_value)
			_camp_style_label(value_label, CAMP_TEXT, 18, 1)
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if bar != null:
			bar.max_value = CAMP_UNIT_INFO_STAT_BAR_CAP
			bar.value = 0.0
			_camp_style_unit_info_stat_bar(bar, fill_color, overcap)
			animate_tween.tween_property(bar, "value", display_value, 0.24).set_delay(0.16 + float(idx) * 0.04)
			if sheen != null:
				_animate_unit_info_bar_sheen(sheen, bar, 0.20 + float(idx) * 0.04)
		if desc_label != null:
			desc_label.text = _camp_unit_info_stat_description(stat_key)
			_camp_style_label(desc_label, CAMP_MUTED, 15, 1)
			desc_label.modulate = Color(1, 1, 1, 0)
			animate_tween.tween_property(desc_label, "modulate", Color.WHITE, 0.18).set_delay(0.19 + float(idx) * 0.04)

	_refresh_camp_unit_info_growth_widgets(growth_totals, true, animate_tween)

	animate_tween.finished.connect(func():
		_camp_unit_info_anim_tween = null
	, CONNECT_ONE_SHOT)

# --- Sheen helpers (adapted from BattleField.gd level-up bar juice): diagonal highlight sweep across growth bars. ---
func _attach_unit_info_bar_sheen(bar: ProgressBar) -> ColorRect:
	bar.clip_contents = true
	var sheen: ColorRect = ColorRect.new()
	sheen.name = "UnitInfoSheen"
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheen.color = Color(1.0, 1.0, 1.0, 0.18)
	sheen.size = Vector2(46, maxf(28.0, bar.custom_minimum_size.y + 12.0))
	sheen.position = Vector2(-70, -8)
	sheen.rotation_degrees = 16.0
	sheen.modulate.a = 0.0
	bar.add_child(sheen)
	return sheen

func _animate_unit_info_bar_sheen(sheen: ColorRect, bar: ProgressBar, delay: float = 0.0) -> void:
	if sheen == null or bar == null:
		return
	var bar_width: float = maxf(bar.size.x, bar.custom_minimum_size.x)
	bar_width = maxf(bar_width, 120.0)
	sheen.position = Vector2(-70, -8)
	sheen.modulate.a = 0.0
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(sheen, "modulate:a", 1.0, 0.05)
	tw.parallel().tween_property(sheen, "position:x", bar_width + 30.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(sheen, "modulate:a", 0.0, 0.06)

func _hide_unit_info_panel() -> void:
	if _camp_unit_info_anim_tween != null:
		_camp_unit_info_anim_tween.kill()
		_camp_unit_info_anim_tween = null
	if _camp_unit_info_dimmer != null:
		_camp_unit_info_dimmer.visible = false
	if unit_info_panel != null:
		unit_info_panel.visible = false

# --- EQUIP LOGIC ---
func _on_equip_pressed() -> void:
	if selected_inventory_meta.is_empty(): return
	var meta = selected_inventory_meta
	var item = meta.get("item")
	if item == null: return
	
	var unit_idx = selected_roster_index
	var unit_data = CampaignManager.player_roster[unit_idx]
	if not unit_data.has("inventory"): unit_data["inventory"] = []
	
	if meta["source"] == "unit":
		if item is WeaponData:
			if unit_data.get("equipped_weapon") == item:
				unit_data["equipped_weapon"] = null
			else:
				unit_data["equipped_weapon"] = item
			_camp_inv_flash_item = item
			_play_camp_inv_sfx_equip()

	elif meta["source"] == "convoy" or meta["source"] == "other_unit":
		if unit_data["inventory"].size() >= 5:
			_play_camp_inv_sfx_invalid()
			warning_dialog.dialog_text = unit_data["unit_name"] + "'s backpack is full!"
			warning_dialog.popup_centered()
			return
			
		if meta["source"] == "convoy":
			CampaignManager.global_inventory.remove_at(meta["index"])
		else:
			var other_unit = CampaignManager.player_roster[meta["unit_index"]]
			other_unit["inventory"].remove_at(meta["inv_index"])
			if other_unit.get("equipped_weapon") == item:
				other_unit["equipped_weapon"] = null
				
		unit_data["inventory"].append(item)
		_camp_inv_flash_item = item
		_play_camp_inv_sfx_equip()

	_populate_inventory()
	_on_roster_item_selected(unit_idx)
	_camp_inventory_desc_set_text("Action successful. Select an item to view details.")
	
# --- UNEQUIP LOGIC ---
func _on_unequip_pressed() -> void:
	if selected_inventory_meta.is_empty(): return
	var meta = selected_inventory_meta
	if meta["source"] == "convoy": return 
	
	var unit_idx = selected_roster_index
	var item = meta["item"]
	
	if meta["source"] == "unit":
		var unit_data = CampaignManager.player_roster[unit_idx]
		unit_data["inventory"].remove_at(meta["inv_index"])
		if unit_data.get("equipped_weapon") == item:
			unit_data["equipped_weapon"] = null
	else:
		var other_unit = CampaignManager.player_roster[meta["unit_index"]]
		other_unit["inventory"].remove_at(meta["inv_index"])
		if other_unit.get("equipped_weapon") == item:
			other_unit["equipped_weapon"] = null
	
	var to_append: Resource = CampaignManager.make_unique_item(item)
	if to_append != null:
		if not to_append.has_meta("original_path") and item.resource_path != "":
			to_append.set_meta("original_path", item.resource_path)
		elif not to_append.has_meta("original_path") and item.has_meta("original_path"):
			to_append.set_meta("original_path", item.get_meta("original_path"))
		CampaignManager.global_inventory.append(to_append)
		_camp_inv_flash_item = to_append

	_play_camp_inv_sfx_equip()
	_populate_inventory()
	_on_roster_item_selected(unit_idx)
	_camp_inventory_desc_set_text("Action successful. Select an item to view details.")
	
	
func _on_next_battle_pressed() -> void:
	# 1. Finalize all changes made in camp
	if CampaignManager.active_save_slot != -1:
		CampaignManager.save_game(CampaignManager.active_save_slot)
	
	# 2. Smart Redirection
	if CampaignManager.max_unlocked_index >= 2:
		# If we have the map unlocked, go there instead of blindly loading a level
		SceneTransition.change_scene_to_file("res://Scenes/UI/WorldMap.tscn")
	else:
		# --- THE FIX: USE THE CORRECT MANAGER FUNCTION ---
		# Since we are LEAVING camp, we use enter_level_from_map so it checks
		# the 'pre_battle_transitions' array!
		CampaignManager.enter_level_from_map(CampaignManager.current_level_index)
			

func _on_sell_pressed() -> void:
	if selected_inventory_meta.is_empty(): return
	var item = selected_inventory_meta["item"]
	var count = selected_inventory_meta.get("count", 1) 
	
	var cost = item.get("gold_cost") if item.get("gold_cost") != null else 0
	var sell_price = int(cost / 2)
	var item_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
	
	var is_stackable = (item is ConsumableData) or (item is ChestKeyData) or (item is MaterialData)
	
	if is_stackable and count > 1:
		qty_mode = "sell"
		qty_base_price = sell_price
		qty_max_amount = count
		_open_quantity_popup(item_name, qty_max_amount, sell_price)
	else:
		sell_confirmation.dialog_text = "Sell " + str(item_name) + " for " + str(sell_price) + "G?"
		sell_confirmation.popup_centered()
					
## Completes a single-item sell: adds gold, removes item, runs gold fountain to gold_label, then refreshes UI.
## Purpose: Sell flow with juice. Origin for coins is center of inventory area; gold label ticks up as coins hit.
## Inputs: None (uses selected_inventory_meta). Outputs: None. Side effects: CampaignManager, gold_label (via animation), inventory; plays shop_sell_sound at burst.
func _on_sell_confirmed() -> void:
	if selected_inventory_meta.is_empty(): return
	var meta: Dictionary = selected_inventory_meta
	var item = meta["item"]
	var sell_price: int = int(item.get("gold_cost") / 2) if item.get("gold_cost") != null else 0
	CampaignManager.global_gold += sell_price
	if meta["source"] == "convoy":
		CampaignManager.global_inventory.remove_at(meta["index"])
	else:
		var tgt_unit: Dictionary = CampaignManager.player_roster[meta["unit_index"]]
		tgt_unit["inventory"].remove_at(meta["inv_index"])
		if tgt_unit.get("equipped_weapon") == item:
			tgt_unit["equipped_weapon"] = null
	_update_merchant_text("sell")
	var sell_origin: Vector2 = (inv_scroll.global_position + inv_scroll.size / 2.0) if inv_scroll else get_viewport_rect().get_center()
	_animate_sell_gold_fountain(sell_origin, sell_price)
	_populate_inventory()
	_on_roster_item_selected(selected_roster_index)
		
func _play_merchant_idle() -> void:
	if not is_instance_valid(merchant_portrait): return
	
	var tween = create_tween().set_loops()
	# Subtle scale up and down to simulate breathing
	tween.tween_property(merchant_portrait, "scale", Vector2(1.02, 1.02), 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(merchant_portrait, "scale", Vector2(1.0, 1.0), 2.0).set_trans(Tween.TRANS_SINE)

func _on_sort_pressed() -> void:
	if CampaignManager.global_inventory.is_empty(): return
	CampaignManager.global_inventory.sort_custom(func(a, b):
		var weight_a = _get_item_weight(a)
		var weight_b = _get_item_weight(b)
		if weight_a != weight_b: return weight_a > weight_b 
			
		if a is WeaponData and b is WeaponData:
			if a.damage_type != b.damage_type: return a.damage_type > b.damage_type
		
		var price_a = a.get("gold_cost") if a.get("gold_cost") != null else 0
		var price_b = b.get("gold_cost") if b.get("gold_cost") != null else 0
		if price_a != price_b: return price_a > price_b
			
		var name_a = a.get("weapon_name") if a.get("weapon_name") != null else a.get("item_name")
		var name_b = b.get("weapon_name") if b.get("weapon_name") != null else b.get("item_name")
		return str(name_a) < str(name_b)
	)
	_populate_inventory()
	
# Helper function to categorize items by priority
func _get_item_weight(item: Resource) -> int:
	if item is WeaponData:
		# Staves usually sit at the very top or bottom of weapon lists
		if item.is_healing_staff: return 100
		if item.is_buff_staff: return 95
		if item.is_debuff_staff: return 90
		# Standard combat weapons
		return 80
		
	if item is ConsumableData:
		# Check for the permanent boost group you created
		var is_booster = item.hp_boost > 0 or item.str_boost > 0 or item.mag_boost > 0 or \
						 item.def_boost > 0 or item.res_boost > 0 or item.spd_boost > 0 or item.agi_boost > 0
		return 60 if is_booster else 50
		
	if item is ChestKeyData:
		return 40
		
	return 0

func _show_rep_popup(won: bool) -> void:
	rep_popup.visible = true
	rep_popup.modulate.a = 1.0 # Reset opacity to fully visible
	
	# Store the original position so it resets properly for the next visit
	var start_pos = rep_popup.position
	
	if won:
		rep_popup.text = "+1 Reputation"
		rep_popup.add_theme_color_override("font_color", Color.GREEN)
	else:
		rep_popup.text = "-1 Reputation"
		rep_popup.add_theme_color_override("font_color", Color.RED)
		
	var tween = create_tween()
	
	# Step 1: Float up and fade out simultaneously
	tween.set_parallel(true)
	tween.tween_property(rep_popup, "position:y", start_pos.y - 60, 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(rep_popup, "modulate:a", 0.0, 2.0)
	
	# Step 2: Reset everything once the animation finishes
	tween.chain().tween_callback(func():
		rep_popup.visible = false
		rep_popup.position = start_pos
	)

# Creates a compact tag for the ItemLists (e.g., "[Heal: 15 | +4 STR | +4 SPD]")
func _get_item_effect_tag(item: Resource) -> String:
	var tags = []
	
	if item is WeaponData:
		# These are now independent 'if' statements so they can stack
		if item.is_healing_staff:
			tags.append("Heal: " + str(item.effect_amount))
			
		if item.is_buff_staff or item.is_debuff_staff:
			var sign_char = "+" if item.is_buff_staff else "-"
			
			# Split the string by comma in case there are multiple stats
			var stats = item.affected_stat.split(",")
			for s in stats:
				var clean_stat = _get_stat_abbr(s)
				tags.append(sign_char + str(item.effect_amount) + " " + clean_stat)
				
		if tags.size() > 0:
			return " [" + " | ".join(tags) + "]"
			
	elif item is ConsumableData:
		if item.heal_amount > 0:
			tags.append("Heal: " + str(item.heal_amount))
			
		var boosts = []
		if item.hp_boost > 0: boosts.append("+" + str(item.hp_boost) + " HP")
		if item.str_boost > 0: boosts.append("+" + str(item.str_boost) + " STR")
		if item.mag_boost > 0: boosts.append("+" + str(item.mag_boost) + " MAG")
		if item.def_boost > 0: boosts.append("+" + str(item.def_boost) + " DEF")
		if item.res_boost > 0: boosts.append("+" + str(item.res_boost) + " RES")
		if item.spd_boost > 0: boosts.append("+" + str(item.spd_boost) + " SPD")
		if item.agi_boost > 0: boosts.append("+" + str(item.agi_boost) + " AGI")
		
		if boosts.size() > 0:
			tags.append(", ".join(boosts))
			
		if tags.size() > 0:
			return " [" + " | ".join(tags) + "]"
			
	return ""

# Helper to map full words to standard 3-letter RPG tags safely
func _get_stat_abbr(stat_name: String) -> String:
	match stat_name.strip_edges().to_lower():
		"strength": return "STR"
		"magic": return "MAG"
		"defense": return "DEF"
		"resistance": return "RES"
		"speed": return "SPD"
		"agility": return "AGI"
		"hp": return "HP"
		_: return stat_name.strip_edges().to_upper().substr(0, 3)

func _camp_inv_bb_escape(s: String) -> String:
	return str(s).replace("[", "[lb]")


func _camp_inv_soft_rule() -> String:
	# Centered hairline: light horizontal box-drawing reads as one bar in pixel fonts;
	# spaced middots looked like chunky, uneven dots.
	const RULE_LEN := 52
	var seg := "\u2500".repeat(RULE_LEN)
	return "[center][font_size=11][color=#b09870]%s[/color][/font_size][/center]" % seg


func _camp_inv_rarity_title_hex(rarity: String) -> String:
	match rarity:
		"Uncommon":
			return "#8ce8a8"
		"Rare":
			return "#7fd4ff"
		"Epic":
			return "#d0a0ff"
		"Legendary":
			return "#ffcf6a"
		_:
			return "#f2ebe0"


func _camp_inv_section_heading(title: String) -> String:
	return (
		"[font_size=22][color=#c4943a]▍ [/color][color=#f0d78c]%s[/color][/font_size]"
		% _camp_inv_bb_escape(str(title).to_upper())
	)


func _camp_inv_kv(label: String, value_bb: String) -> String:
	return (
		"[font_size=22][color=#b0a090]%s[/color][color=#4f4638]   [/color]%s[/font_size]"
		% [_camp_inv_bb_escape(label), value_bb]
	)


## Tightens BBCode font_size tags for narrow forge OUTCOME readouts (lifts tiny rules, caps huge titles).
func _camp_bbcode_clamp_font_sizes(text: String, min_size: int = 17, max_size: int = 22) -> String:
	var re := RegEx.new()
	if re.compile("\\[font_size=(\\d+)\\]") != OK:
		return text
	var out := text
	while true:
		var m: RegExMatch = re.search(out)
		if m == null:
			break
		var n: int = int(m.get_string(1))
		var c: int = clampi(n, min_size, max_size)
		var rep := "[font_size=%d]" % c
		out = out.substr(0, m.get_start()) + rep + out.substr(m.get_end())
	return out


## Shared layout for Quartermaster item panel, shop card, and forge readouts.
func _get_item_detailed_info(
		item: Resource,
		price: int,
		stack_count: int = 1,
		compare_item: Resource = null,
		context_header_plain: String = "",
		forge_readout: bool = false
) -> String:
	var lines: PackedStringArray = []

	if context_header_plain.strip_edges() != "":
		lines.append(
			"[font_size=17][color=#928575]%s[/color][/font_size]"
			% _camp_inv_bb_escape(context_header_plain.strip_edges())
		)

	var i_name: String = str(item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name"))
	if i_name.strip_edges() == "":
		i_name = "Unknown Item"

	var rarity: String = str(item.get("rarity") if item.get("rarity") != null else "Common")
	var title_hex: String = _camp_inv_rarity_title_hex(rarity)
	lines.append("[center][font_size=26][color=%s]%s[/color][/font_size][/center]" % [title_hex, _camp_inv_bb_escape(i_name.to_upper())])

	var stack_bb: String = ""
	if stack_count > 1:
		stack_bb = (
			"[color=#4a4236] · [/color][color=#c8b8a0]Stock[/color][color=#4a4236] [/color][color=#f2ebe0]×%d[/color]"
			% stack_count
		)

	lines.append(
		"[center][font_size=21][color=%s]%s[/color][color=#4a4236]  ·  [/color]"
		% [title_hex, _camp_inv_bb_escape(rarity)]
		+ "[color=#b8a898]Value[/color][color=#4a4236] [/color][color=#e8c97c]%d[/color][color=#9a8b78]g[/color]%s[/font_size][/center]"
		% [int(price), stack_bb]
	)

	lines.append(_camp_inv_soft_rule())

	if item is WeaponData:
		if item.get("current_durability") != null and item.current_durability <= 0:
			lines.append("[font_size=22][color=#ff9a8a]Broken[/color][color=#8a7868] — [/color][color=#c4bba8]Half effectiveness until repaired.[/color][/font_size]")

		lines.append(_camp_inv_section_heading("Combat profile"))

		var w_type_str: String = "Unknown"
		if item.get("weapon_type") != null:
			w_type_str = WeaponData.get_weapon_type_name(int(item.weapon_type))
		var d_type_str: String = "Physical" if item.get("damage_type") != null and item.damage_type == 0 else "Magical"
		lines.append(
			_camp_inv_kv(
				"Class",
				"[color=#f5ecd8]%s[/color][color=#4f4638] · [/color][color=#a89888]%s[/color]" % [w_type_str, d_type_str]
			)
		)
		lines.append(_camp_inv_kv("Might", "[color=#ffc9a8]%d[/color]" % int(item.might)))
		lines.append(_camp_inv_kv("Hit", "[color=#f0d78c]+%d[/color]" % int(item.hit_bonus)))
		lines.append(
			_camp_inv_kv(
				"Reach",
				"[color=#b8e8c0]%d[/color][color=#5a5248]–[/color][color=#b8e8c0]%d[/color]" % [int(item.min_range), int(item.max_range)]
			)
		)

		if item.get("current_durability") != null:
			lines.append(
				_camp_inv_kv(
					"Durability",
					"[color=#a8d8f0]%d[/color][color=#5a5248]/[/color][color=#8a98a8]%d[/color]"
					% [int(item.current_durability), int(item.max_durability)]
				)
			)

		var rune_camp: String = WeaponRuneDisplayHelpers.format_runes_bbcode_for_item_variant(item)
		if rune_camp != "":
			lines.append(_camp_inv_section_heading("Runes"))
			for rune_line in rune_camp.split("\n"):
				var rl: String = rune_line.strip_edges()
				if rl != "":
					lines.append("[font_size=21]%s[/font_size]" % rl)

		if compare_item != null and compare_item is WeaponData and item != compare_item:
			if item.damage_type == compare_item.damage_type:
				var m_diff_cmp: int = int(item.might) - int(compare_item.might)
				var h_diff_cmp: int = int(item.hit_bonus) - int(compare_item.hit_bonus)
				if m_diff_cmp != 0 or h_diff_cmp != 0:
					var cmp_parts: PackedStringArray = []
					if m_diff_cmp != 0:
						var m_hex: String = "#8ce8a8" if m_diff_cmp > 0 else "#ff9a8a"
						cmp_parts.append("[color=%s]%s Might[/color]" % [m_hex, "%+d" % m_diff_cmp])
					if h_diff_cmp != 0:
						var h_hex: String = "#8ce8a8" if h_diff_cmp > 0 else "#ff9a8a"
						cmp_parts.append("[color=%s]%s Hit[/color]" % [h_hex, "%+d" % h_diff_cmp])
					var cmp_sep: String = "[color=#4f4638] · [/color]"
					lines.append(
						"[font_size=21][color=#8a7868]Δ vs equipped[/color][color=#4f4638] · [/color]%s[/font_size]"
						% cmp_sep.join(cmp_parts)
					)

		var w_effects: Array = []
		if item.get("is_healing_staff") == true:
			w_effects.append("Restores %d HP" % int(item.effect_amount))

		if item.get("is_buff_staff") == true or item.get("is_debuff_staff") == true:
			var word: String = "Grants +" if item.get("is_buff_staff") == true else "Inflicts -"
			if item.get("affected_stat") != null and str(item.affected_stat) != "":
				var stats_split: PackedStringArray = str(item.affected_stat).split(",")
				var formatted_stats: PackedStringArray = []
				for s in stats_split:
					formatted_stats.append(s.strip_edges().capitalize())
				w_effects.append(word + str(item.effect_amount) + " to " + ", ".join(formatted_stats))

		if w_effects.size() > 0:
			lines.append(_camp_inv_section_heading("Weapon effects"))
			for e in w_effects:
				lines.append("[font_size=21][color=#e8d0ff]◆[/color][color=#4a4236] [/color][color=#ece2d8]%s[/color][/font_size]" % _camp_inv_bb_escape(str(e)))

	elif item is ConsumableData:
		lines.append(_camp_inv_section_heading("Overview"))
		lines.append(_camp_inv_kv("Kind", "[color=#f5ecd8]Consumable[/color]"))

		var c_effects: Array = []
		if item.heal_amount > 0:
			c_effects.append("Restores %d HP" % int(item.heal_amount))
		var boosts: PackedStringArray = []
		if item.hp_boost > 0:
			boosts.append("+%d HP (max)" % int(item.hp_boost))
		if item.str_boost > 0:
			boosts.append("+%d STR" % int(item.str_boost))
		if item.mag_boost > 0:
			boosts.append("+%d MAG" % int(item.mag_boost))
		if item.def_boost > 0:
			boosts.append("+%d DEF" % int(item.def_boost))
		if item.res_boost > 0:
			boosts.append("+%d RES" % int(item.res_boost))
		if item.spd_boost > 0:
			boosts.append("+%d SPD" % int(item.spd_boost))
		if item.agi_boost > 0:
			boosts.append("+%d AGI" % int(item.agi_boost))

		if boosts.size() > 0:
			c_effects.append("Permanent: " + ", ".join(boosts))

		if c_effects.size() > 0:
			lines.append(_camp_inv_section_heading("Effects"))
			for e2 in c_effects:
				lines.append("[font_size=21][color=#e8d0ff]◆[/color][color=#4a4236] [/color][color=#ece2d8]%s[/color][/font_size]" % _camp_inv_bb_escape(str(e2)))

	elif item is ChestKeyData:
		lines.append(_camp_inv_section_heading("Overview"))
		lines.append(_camp_inv_kv("Kind", "[color=#f5ecd8]Key[/color]"))
		lines.append("[font_size=21][color=#c4bba8]Opens locked chests on the field.[/color][/font_size]")

	elif item is MaterialData:
		lines.append(_camp_inv_section_heading("Overview"))
		lines.append(_camp_inv_kv("Kind", "[color=#f5ecd8]Crafting material[/color]"))

	else:
		lines.append(_camp_inv_section_heading("Overview"))
		lines.append("[font_size=21][color=#c4bba8]Miscellaneous inventory — still salable at standard rates.[/color][/font_size]")

	lines.append(_camp_inv_soft_rule())
	lines.append(_camp_inv_section_heading("Details"))

	var raw_desc: String = str(item.description) if item.get("description") != null else ""
	if raw_desc.strip_edges() != "":
		for piece: String in raw_desc.split("\n"):
			var row: String = piece.strip_edges()
			if row == "":
				continue
			lines.append(
				"[font_size=22][color=#9a8b78]▸[/color][color=#4a4236] [/color][color=#e8dfd4][i]%s[/i][/color][/font_size]"
				% _camp_inv_bb_escape(row)
			)
	else:
		lines.append("[font_size=22][color=#7a7064][i]No written notes on this entry.[/i][/color][/font_size]")

	var body := "\n".join(lines)
	if forge_readout:
		body = _camp_bbcode_clamp_font_sizes(body, 19, 24)
	return body


func _reset_idle_timer() -> void:
	# Picks a random time between 15 and 30 seconds
	idle_timer.start(randf_range(15.0, 30.0))

func _on_idle_timer_timeout() -> void:
	# Only speak if the player isn't in the middle of the haggling mini-game
	if not haggle_active:
		_update_merchant_text("idle")
	_reset_idle_timer()


func _sync_merchant_talk_button_caption() -> void:
	if talk_button == null:
		return
	var open: bool = _merchant_talk_modal != null and _merchant_talk_modal.visible
	talk_button.text = "Close" if open else "Talk"


func _sync_merchant_talk_button_state() -> void:
	if talk_button == null:
		return
	var blocked: bool = haggle_active or (
		blacksmith_panel != null and is_instance_valid(blacksmith_panel) and blacksmith_panel.visible
	)
	talk_button.disabled = blocked
	if blocked:
		_close_merchant_talk_panel(true)
	else:
		_sync_merchant_talk_button_caption()
	if blacksmith_panel != null and is_instance_valid(blacksmith_panel) and blacksmith_panel.visible:
		_refresh_blacksmith_runesmith_status_label()


func _close_merchant_talk_panel(instant: bool = false) -> void:
	if instant:
		_merchant_talk_kill_modal_tweens()
		_merchant_talk_reset_modal_visuals()
		if _merchant_talk_modal != null:
			_merchant_talk_modal.visible = false
		_sync_merchant_talk_button_caption()
		return
	if _merchant_talk_modal == null or not _merchant_talk_modal.visible:
		_sync_merchant_talk_button_caption()
		return
	_merchant_talk_play_close_animation()


func _merchant_talk_grab_primary_focus() -> void:
	if option1 != null and _merchant_talk_modal != null and _merchant_talk_modal.visible:
		option1.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if haggle_active and event.is_action_pressed("camp_cancel"):
		_end_haggle_concede()
		get_viewport().set_input_as_handled()
		return
	if _merchant_talk_modal == null or not _merchant_talk_modal.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_merchant_talk_panel()

func _on_talk_pressed() -> void:
	if talk_button != null and talk_button.disabled:
		return
	if _merchant_talk_modal != null and _merchant_talk_modal.visible:
		_close_merchant_talk_panel()
		return

	_camp_layout_merchant_talk_panel()
	_refresh_talk_ui()
	_merchant_talk_show_modal_animated()
	_sync_merchant_talk_button_caption()

func _get_item_display_name(item: Resource) -> String:
	if item == null:
		return "Unknown"

	var weapon_name_raw: Variant = item.get("weapon_name")
	if weapon_name_raw != null:
		var weapon_name: String = str(weapon_name_raw).strip_edges()
		if weapon_name != "":
			return weapon_name

	var item_name_raw: Variant = item.get("item_name")
	if item_name_raw != null:
		var item_name: String = str(item_name_raw).strip_edges()
		if item_name != "":
			return item_name

	return "Unknown"


func _is_valid_merchant_quest_candidate(item: Resource) -> bool:
	if item == null:
		return false

	var item_name: String = _get_item_display_name(item)
	if item_name == "Unknown":
		return false

	# Never request special progression items
	if item_name == "Blacksmith's Tome" or item_name == "Dwarven Crucible":
		return false

	# Never request jukebox/music unlock consumables
	var unlocked_track_raw: Variant = item.get("unlocked_music_track")
	if unlocked_track_raw != null:
		return false

	var price_raw: Variant = item.get("gold_cost")
	var price: int = int(price_raw) if price_raw != null else 0
	if price <= 0:
		return false

	# Best-feeling quest items: materials / consumables / keys
	if item is MaterialData:
		return true
	if item is ConsumableData:
		return true
	if item is ChestKeyData:
		return true

	# Weapons only later, and only modest ones
	if item is WeaponData:
		var rarity_raw: Variant = item.get("rarity")
		var rarity: String = str(rarity_raw) if rarity_raw != null else "Common"
		var allowed_rarity: bool = rarity == "Common" or rarity == "Uncommon" or (rarity == "Rare" and CampaignManager.max_unlocked_index >= 4)
		var is_staff_like: bool = (
			item.get("is_healing_staff") == true
			or item.get("is_buff_staff") == true
			or item.get("is_debuff_staff") == true
		)

		return CampaignManager.merchant_quests_completed >= 3 and allowed_rarity and not is_staff_like and price <= 400

	return false


func _get_merchant_quest_weight(item: Resource) -> int:
	if item is MaterialData:
		return 10
	if item is ConsumableData:
		return 6
	if item is ChestKeyData:
		return 3
	if item is WeaponData:
		return 2
	return 1



func _build_merchant_quest_candidates() -> Array[Resource]:
	var weighted_candidates: Array[Resource] = []
	var seen_names: Dictionary = {}

	for item in ItemDatabase.master_item_pool:
		if item == null:
			continue
		if not _is_valid_merchant_quest_candidate(item):
			continue

		var item_name: String = _get_item_display_name(item)
		if seen_names.has(item_name):
			continue

		seen_names[item_name] = true

		var weight: int = _get_merchant_quest_weight(item)
		for i in range(weight):
			weighted_candidates.append(item)

	return weighted_candidates
	
func _get_merchant_quest_amount(item: Resource) -> int:
	var price_raw: Variant = item.get("gold_cost")
	var price: int = int(price_raw) if price_raw != null else 50
	var progress_bonus: int = int(CampaignManager.max_unlocked_index / 2.0)

	if item is MaterialData:
		if price <= 50:
			return clampi(randi_range(3 + progress_bonus, 6 + progress_bonus), 3, 8)
		return clampi(randi_range(2 + progress_bonus, 4 + progress_bonus), 2, 6)

	if item is ConsumableData:
		if price <= 50:
			return randi_range(2, 4)
		return randi_range(1, 3)

	if item is ChestKeyData:
		return 1 if CampaignManager.max_unlocked_index < 4 else randi_range(1, 2)

	if item is WeaponData:
		return 1 if price > 150 else randi_range(1, 2)

	return randi_range(1, 2)
	
func _calculate_merchant_quest_reward(item: Resource, amount: int) -> int:
	var base_value_raw: Variant = item.get("gold_cost")
	var base_value: int = int(base_value_raw) if base_value_raw != null else 50
	base_value = max(base_value, 20)

	var total_value: int = base_value * amount
	var progression_mult: float = 1.0 + (float(CampaignManager.max_unlocked_index) * 0.08)
	var reputation_mult: float = 1.0 + (float(min(CampaignManager.merchant_reputation, 10)) * 0.03)
	var history_mult: float = 1.0 + (float(min(CampaignManager.merchant_quests_completed, 10)) * 0.02)

	var category_mult: float = 1.0
	if item is MaterialData:
		category_mult = 1.25
	elif item is ConsumableData:
		category_mult = 1.15
	elif item is ChestKeyData:
		category_mult = 1.60
	elif item is WeaponData:
		category_mult = 1.35

	var reward: int = int(round(total_value * progression_mult * reputation_mult * history_mult * category_mult))
	return max(reward, 60 + (amount * 15))

func _get_active_quest_rep_reward() -> int:
	var item: Resource = _find_quest_item_resource(CampaignManager.merchant_quest_item_name)
	if item == null:
		return 1

	var rep_reward: int = 1

	if item is WeaponData or item is ChestKeyData:
		rep_reward = 2
	elif item is MaterialData and CampaignManager.merchant_quest_target_amount >= 5:
		rep_reward = 2

	if CampaignManager.max_unlocked_index >= 6 and CampaignManager.merchant_quests_completed >= 5:
		rep_reward += 1

	return clampi(rep_reward, 1, 3)
	
func _quest_item_matches(item: Resource, item_name: String, ignore_locked: bool = true) -> bool:
	if item == null:
		return false

	var is_locked: bool = bool(item.get_meta("is_locked", false))
	if ignore_locked and is_locked:
		return false

	return _get_item_display_name(item) == item_name

func _count_party_items_for_quest(item_name: String, ignore_locked: bool = true) -> int:
	var total: int = 0

	for item in CampaignManager.global_inventory:
		if item != null and _quest_item_matches(item, item_name, ignore_locked):
			total += 1

	for unit_data in CampaignManager.player_roster:
		var inv_raw: Variant = unit_data.get("inventory", [])
		var inv: Array = inv_raw if inv_raw is Array else []

		for item in inv:
			if item != null and _quest_item_matches(item, item_name, ignore_locked):
				total += 1

	return total
	
func _remove_party_items_for_quest(item_name: String, amount: int) -> int:
	var removed: int = 0

	# Remove from convoy first
	for i in range(CampaignManager.global_inventory.size() - 1, -1, -1):
		if removed >= amount:
			break

		var item: Resource = CampaignManager.global_inventory[i]
		if item != null and _quest_item_matches(item, item_name, true):
			CampaignManager.global_inventory.remove_at(i)
			removed += 1

	# Then remove from unit backpacks
	for unit_data in CampaignManager.player_roster:
		if removed >= amount:
			break

		var inv_raw: Variant = unit_data.get("inventory", [])
		var inv: Array = inv_raw if inv_raw is Array else []

		for i in range(inv.size() - 1, -1, -1):
			if removed >= amount:
				break

			var item: Resource = inv[i]
			if item != null and _quest_item_matches(item, item_name, true):
				if unit_data.get("equipped_weapon") == item:
					unit_data["equipped_weapon"] = null
				inv.remove_at(i)
				removed += 1

	return removed


func _merchant_quest_progress_block(reward_gold: int, rep_reward: int, found: int, target: int) -> String:
	# Avoid "+N" next to tall letters — pixel fonts often read "+2" as "-2".
	return "Pays %d gold and %d reputation on delivery.\nProgress: %d / %d" % [reward_gold, rep_reward, found, target]


func _get_active_quest_status_text(mc_name: String) -> String:
	var amt: int = CampaignManager.merchant_quest_target_amount
	var item_name: String = str(CampaignManager.merchant_quest_item_name)
	var plural: String = _plural_suffix(amt, item_name)
	var owned: int = _count_party_items_for_quest(item_name, true)
	var rep_reward: int = _get_active_quest_rep_reward()

	var text: String = _line("quest_waiting", {
		"amount": amt,
		"item": item_name,
		"plural": plural,
		"name": mc_name
	})

	text += "\n\n" + _merchant_quest_progress_block(CampaignManager.merchant_quest_reward, rep_reward, owned, amt)

	return text

func _refresh_talk_ui() -> void:
	var mc_name: String = "Hero"
	if CampaignManager.player_roster.size() > 0:
		mc_name = str(CampaignManager.player_roster[0]["unit_name"])

	if CampaignManager.merchant_quest_active:
		current_talk_state = "active"
		if _merchant_talk_header_label != null:
			_merchant_talk_header_label.text = "CONTRACT"

		var quest_item: Resource = _find_quest_item_resource(CampaignManager.merchant_quest_item_name)
		if quest_item != null and quest_item.get("icon") != null:
			quest_item_icon.texture = quest_item.icon
			quest_item_icon.visible = true
		else:
			quest_item_icon.visible = false

		talk_text.text = _get_active_quest_status_text(mc_name)

		option1.text = "Turn in items."
		option2.text = "Show progress."
		option3.text = "⚠ Abandon contract."
		option3.visible = true
	else:
		current_talk_state = "idle"
		if _merchant_talk_header_label != null:
			_merchant_talk_header_label.text = "BARTHOLOMEW"

		quest_item_icon.visible = false
		talk_text.text = _line("idle_open", {"name": mc_name})

		option1.text = "Got any work?"
		option2.text = "Tell me a rumor."
		option3.text = "Never mind."
		option3.visible = true
	_update_merchant_talk_quest_bar()
	if _merchant_talk_modal != null and _merchant_talk_modal.visible:
		call_deferred("_camp_layout_merchant_talk_panel_inner")

func _on_option1_pressed() -> void:
	_merchant_talk_play_confirm_sfx(false)
	if current_talk_state == "idle":
		_generate_procedural_quest()
	elif current_talk_state == "active":
		_try_complete_quest()

func _on_option2_pressed() -> void:
	_merchant_talk_play_confirm_sfx(false)
	var mc_name: String = "Hero"
	if CampaignManager.player_roster.size() > 0:
		mc_name = str(CampaignManager.player_roster[0]["unit_name"])

	if current_talk_state == "idle":
		_close_merchant_talk_panel()
		_play_typewriter_animation(_line("rumors", {"name": mc_name}))
	elif current_talk_state == "active":
		var amt: int = CampaignManager.merchant_quest_target_amount
		var item_name: String = str(CampaignManager.merchant_quest_item_name)
		var plural: String = _plural_suffix(amt, item_name)
		var found: int = _count_party_items_for_quest(item_name, true)
		var missing: int = max(amt - found, 0)
		var rep_reward: int = _get_active_quest_rep_reward()

		talk_text.text = _line("quest_short", {
			"found": found,
			"amount": amt,
			"missing": missing,
			"item": item_name,
			"plural": plural
		})

		talk_text.text += "\n\n" + _merchant_quest_progress_block(
			CampaignManager.merchant_quest_reward,
			rep_reward,
			found,
			amt
		)
		_merchant_talk_flash_progress_text()

func _on_option3_pressed() -> void:
	if current_talk_state == "idle":
		_merchant_talk_play_confirm_sfx(false)
		_close_merchant_talk_panel()
	else:
		_ensure_merchant_abandon_confirm()
		_merchant_abandon_confirm.popup_centered()

		
func _generate_procedural_quest() -> void:
	if ItemDatabase.master_item_pool.is_empty():
		return

	if CampaignManager.merchant_quest_active:
		_refresh_talk_ui()
		return

	var candidates: Array[Resource] = _build_merchant_quest_candidates()
	if candidates.is_empty():
		talk_text.text = "I have no worthwhile contracts right now. Come back after the next battle."
		return

	var random_index: int = randi() % candidates.size()
	var chosen_item: Resource = candidates[random_index]
	var chosen_name: String = _get_item_display_name(chosen_item)
	var chosen_amount: int = _get_merchant_quest_amount(chosen_item)
	var chosen_reward: int = _calculate_merchant_quest_reward(chosen_item, chosen_amount)

	CampaignManager.merchant_quest_item_name = chosen_name
	CampaignManager.merchant_quest_target_amount = chosen_amount
	CampaignManager.merchant_quest_reward = chosen_reward
	CampaignManager.merchant_quest_active = true

	_refresh_talk_ui()
	
func _try_complete_quest() -> void:
	var target_name: String = str(CampaignManager.merchant_quest_item_name)
	var target_amount: int = int(CampaignManager.merchant_quest_target_amount)
	var items_found: int = _count_party_items_for_quest(target_name, true)

	if items_found >= target_amount:
		var removed: int = _remove_party_items_for_quest(target_name, target_amount)
		if removed < target_amount:
			talk_text.text = "Something went wrong while gathering the items. Try again."
			return

		var reward_gold: int = int(CampaignManager.merchant_quest_reward)
		var reward_rep: int = _get_active_quest_rep_reward()

		CampaignManager.global_gold += reward_gold
		CampaignManager.merchant_reputation += reward_rep
		CampaignManager.merchant_quests_completed += 1

		CampaignManager.merchant_quest_active = false
		CampaignManager.merchant_quest_item_name = ""
		CampaignManager.merchant_quest_target_amount = 0
		CampaignManager.merchant_quest_reward = 0

		var mc_name: String = "Hero"
		if CampaignManager.player_roster.size() > 0:
			mc_name = str(CampaignManager.player_roster[0]["unit_name"])

		_close_merchant_talk_panel()
		_play_typewriter_animation(
			"%s You gain %d merchant reputation." % [_line("quest_complete", {"reward": reward_gold, "name": mc_name}), reward_rep]
		)

		_refresh_gold_label()
		_populate_inventory()
		_populate_shop()
	else:
		var plural: String = _plural_suffix(target_amount, target_name)
		var missing: int = max(target_amount - items_found, 0)
		var reward_rep: int = _get_active_quest_rep_reward()

		talk_text.text = _line("quest_short", {
			"found": items_found,
			"amount": target_amount,
			"missing": missing,
			"item": target_name,
			"plural": plural
		})

		talk_text.text += "\n\n" + _merchant_quest_progress_block(
			CampaignManager.merchant_quest_reward,
			reward_rep,
			items_found,
			target_amount
		)


func _find_quest_item_resource(item_name: String) -> Resource:
	if ItemDatabase.master_item_pool.is_empty(): # <--- CHANGED THIS LINE
		return null

	for item in ItemDatabase.master_item_pool: # <--- CHANGED THIS LINE
		if item != null and _get_item_display_name(item) == item_name:
			return item

	return null
	
func _play_random_camp_music() -> void:
	if camp_music_tracks.is_empty():
		return
		
	var random_track = camp_music_tracks[randi() % camp_music_tracks.size()]
	
	if camp_music_tracks.size() > 1 and camp_music.stream == random_track:
		_play_random_camp_music() # Reroll to avoid repeats
		return
		
	if not camp_music.playing:
		camp_music.stream = random_track
		camp_music.volume_db = user_music_volume
		camp_music.play()
		return
		
	_crossfade_music(random_track)
	
func _play_random_minigame_music() -> void:
	if minigame_music_tracks.is_empty():
		return
		
	var random_track = minigame_music_tracks[randi() % minigame_music_tracks.size()]
	
	# Prevent the same song from playing twice in a row
	if minigame_music_tracks.size() > 1 and minigame_music.stream == random_track:
		_play_random_minigame_music() # Reroll
		return
		
	minigame_music.stream = random_track
	minigame_music.play()

func _on_minigame_music_finished() -> void:
	# If the minigame is still active when the song ends, play another
	if haggle_active:
		_play_random_minigame_music()

func _on_save_clicked() -> void:
	if select_sound: select_sound.play()
	
	if save_popup:
		_layout_camp_save_records_popup()
		if _camp_save_dimmer != null:
			_camp_save_dimmer.visible = true
			_camp_save_dimmer.modulate = Color(1, 1, 1, 0.0)
			move_child(_camp_save_dimmer, max(0, save_popup.get_index()))
		move_child(save_popup, get_child_count() - 1)
		# Start the popup invisible and slightly smaller for a "pop-in" effect
		save_popup.modulate.a = 0.0
		save_popup.scale = Vector2(0.9, 0.9)
		save_popup.pivot_offset = save_popup.size / 2.0
		save_popup.visible = true
		
		var tween = create_tween().set_parallel(true)
		if _camp_save_dimmer != null:
			tween.tween_property(_camp_save_dimmer, "modulate:a", 1.0, 0.18)
		tween.tween_property(save_popup, "modulate:a", 1.0, 0.2)
		tween.tween_property(save_popup, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		if save_slot_1:
			save_slot_1.grab_focus()

func _on_back_pressed() -> void:
	if select_sound: select_sound.play()
	
	if save_popup:
		var tween = create_tween().set_parallel(true)
		if _camp_save_dimmer != null and _camp_save_dimmer.visible:
			tween.tween_property(_camp_save_dimmer, "modulate:a", 0.0, 0.15)
		tween.tween_property(save_popup, "modulate:a", 0.0, 0.15)
		tween.tween_property(save_popup, "scale", Vector2(0.9, 0.9), 0.15)
		
		await tween.finished
		save_popup.visible = false
		if _camp_save_dimmer != null:
			_camp_save_dimmer.visible = false

func _try_to_save(slot: int) -> void:
	# Standard click sound when picking a slot
	if select_sound: select_sound.play() 
	
	var path = CampaignManager.get_save_path(slot, false) 
	
	if FileAccess.file_exists(path):
		pending_save_slot = slot
		if overwrite_dialog:
			overwrite_dialog.dialog_text = "Slot " + str(slot) + " already has save data. Overwrite?"
			overwrite_dialog.popup_centered()
	else:
		_proceed_with_save(slot)

func _on_overwrite_confirmed() -> void:
	# The player clicked "Yes" on the warning, so we overwrite.
	_proceed_with_save(pending_save_slot)

func _proceed_with_save(slot: int) -> void:
	CampaignManager.active_save_slot = slot
	CampaignManager.save_game(slot)
	_update_slot_labels()
	
	var clicked_button: Button = null
	if slot == 1: clicked_button = save_slot_1
	elif slot == 2: clicked_button = save_slot_2
	elif slot == 3: clicked_button = save_slot_3
	
	if clicked_button:
		# --- THE JUICE UPDATED ---
		# Play the specific "Save Success" sound!
		if save_confirm_sound: save_confirm_sound.play()
		
		var original_preview := _get_camp_slot_preview_data(slot)
		_camp_apply_save_slot_preview(clicked_button, {
			"badge": "SLOT %d  //  RECORD WRITTEN" % slot,
			"title": "Campaign saved successfully.",
			"meta": "Manual field archive updated.",
			"stamp": "Returning to camp..."
		})
		clicked_button.modulate = Color(0.2, 1.0, 0.2)
		
		clicked_button.pivot_offset = clicked_button.size / 2.0
		var pop_tween = create_tween()
		pop_tween.tween_property(clicked_button, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pop_tween.tween_property(clicked_button, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		await get_tree().create_timer(0.8).timeout
		
		clicked_button.modulate = Color.WHITE
		_camp_apply_save_slot_preview(clicked_button, original_preview)

	_on_back_pressed()

func _update_slot_labels() -> void:
	if save_slot_1:
		_style_camp_save_slot_button(save_slot_1, 1)
	if save_slot_2:
		_style_camp_save_slot_button(save_slot_2, 2)
	if save_slot_3:
		_style_camp_save_slot_button(save_slot_3, 3)

func _get_camp_slot_preview(slot_num: int) -> String:
	var preview := _get_camp_slot_preview_data(slot_num)
	return "%s\n%s\n%s\n%s" % [
		str(preview.get("badge", "")),
		str(preview.get("title", "")),
		str(preview.get("meta", "")),
		str(preview.get("stamp", ""))
	]

func _on_inventory_item_selected(list_index: int) -> void:
	if inventory_mapping.is_empty() or list_index >= inventory_mapping.size(): return
	var mapped_data = inventory_mapping[list_index]
	
	if mapped_data["source"] == "header" or mapped_data["source"] == "empty":
		_camp_inventory_desc_set_text("")
		equip_button.disabled = true
		unequip_button.disabled = true
		sell_button.disabled = true
		return
		
	equip_button.disabled = false
	sell_button.disabled = false
	
	# --- DYNAMIC BUTTON TEXT ---
	if mapped_data["source"] == "unit":
		var unit_data = CampaignManager.player_roster[mapped_data["unit_index"]]
		var is_equipped = (mapped_data["item"] == unit_data.get("equipped_weapon"))
		
		equip_button.text = "Unequip" if is_equipped else "Equip"
		unequip_button.text = "Store"
		unequip_button.disabled = false
		if not (mapped_data["item"] is WeaponData): equip_button.disabled = true
			
	elif mapped_data["source"] == "other_unit":
		equip_button.text = "Give"
		unequip_button.text = "Store"
		unequip_button.disabled = false
		
	else: # Convoy
		equip_button.text = "Give"
		unequip_button.text = "---"
		unequip_button.disabled = true

	var item = mapped_data["item"]
	var sell_val = int(item.get("gold_cost") / 2) if item.get("gold_cost") != null else 0

	var inv_ctx: String = ""
	match mapped_data["source"]:
		"convoy":
			inv_ctx = "Convoy supplies"
		"unit":
			inv_ctx = "Personal loadout"
		"other_unit":
			inv_ctx = str(mapped_data.get("owner_name", "Ally")) + "'s pack"

	var list_equipped: Resource = null
	if selected_roster_index >= 0 and selected_roster_index < CampaignManager.player_roster.size():
		list_equipped = CampaignManager.player_roster[selected_roster_index].get("equipped_weapon")

	var desc = _get_item_detailed_info(item, sell_val, 1, list_equipped, inv_ctx)
	_camp_inventory_desc_set_text(desc)

func _get_item_display_text(item: Resource) -> String:
	var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
	var dur_str = ""
	var broken_tag = ""
	
	if item.get("current_durability") != null:
		dur_str = " [%d/%d]" % [item.current_durability, item.max_durability]
		if item.current_durability <= 0:
			broken_tag = "[BROKEN] "
	elif item.get("uses") != null:
		dur_str = " (" + str(item.uses) + " Uses)"
			
	return "%s%s%s" % [broken_tag, i_name, dur_str]


# Scans the entire scene and adds a subtle high-pitched tick to every button hover
func _connect_hover_sounds(node: Node) -> void:
	for child in node.get_children():
		if child is BaseButton:
			child.mouse_entered.connect(func():
				if select_sound and select_sound.stream != null:
					# Create an independent, temporary audio player for the tick!
					var tick_player = AudioStreamPlayer.new()
					tick_player.stream = select_sound.stream
					tick_player.pitch_scale = randf_range(1.5, 1.8) # Pitch it way up to a 'tick'
					tick_player.volume_db = -15.0 # Make it much softer than a real click
					add_child(tick_player)
					tick_player.play()
					
					# Delete the temporary player the moment the tick finishes playing
					tick_player.finished.connect(tick_player.queue_free)
			)
		# Recursive call to check inside panels and containers
		_connect_hover_sounds(child)
# Returns a hex color string (e.g. "#00ff00") based on how low the durability is
func _get_durability_color(current: int, max_dur: int) -> String:
	if max_dur <= 0: return "#ffffff" # Fallback
	var ratio = float(current) / float(max_dur)
	
	if ratio > 0.5:
		return "#88ff88" # Healthy Green
	elif ratio > 0.2:
		return "#ffff88" # Warning Yellow
	elif current > 0:
		return "#ff8888" # Danger Red
	else:
		return "#ff0000" # Broken!

# Returns the specific color name for a given rarity string
func _get_rarity_color_tag(rarity: String) -> String:
	match rarity:
		"Uncommon": return "lime"
		"Rare": return "deepskyblue"
		"Epic": return "mediumorchid"
		"Legendary": return "gold"
		_: return "white"
# Decides the color for the entire ItemList row

# Decides the color for the entire ItemList row
func _get_item_row_color(item: Resource) -> Color:
	# 1. Highest Priority: Is it broken or dying?
	if item.get("current_durability") != null:
		if item.current_durability <= 0:
			return Color(1.0, 0.2, 0.2) # Bright Red for Broken!
		var ratio = float(item.current_durability) / float(item.max_durability)
		if ratio <= 0.25:
			return Color(1.0, 1.0, 0.2) # Yellow Warning
			
	# 2. Second Priority: Rarity Colors
	var rarity = item.get("rarity") if item.get("rarity") != null else "Common"
	match rarity:
		"Uncommon": return Color(0.2, 1.0, 0.2) # Lime Green
		"Rare": return Color(0.0, 0.75, 1.0) # Deep Sky Blue
		"Epic": return Color(0.8, 0.2, 1.0) # Purple
		"Legendary": return Color(1.0, 0.8, 0.2) # Gold
		
	return Color.WHITE # Default

# ==========================================
# BLACKSMITH: DRAG AND DROP SYSTEM
# ==========================================

func open_blacksmith() -> void:
	_ensure_blacksmith_dimmer()
	if _blacksmith_dimmer != null:
		_blacksmith_dimmer.visible = true
		_camp_layout_blacksmith_dimmer()

	blacksmith_panel.visible = true
	if recipe_book_panel != null:
		recipe_book_panel.visible = false
	call_deferred("_camp_layout_blacksmith_panel")

	# --- THE SILVER BULLET FIX ---
	# Forces Godot to push the Blacksmith Panel over absolutely everything else!
	blacksmith_panel.move_to_front() 
	
	anvil_items = [null, null, null] # Clear the anvil slots

	# --- 2. UNIVERSAL AUTO-UNLOCK SYSTEM ---
	
	# A. Scan the Global Convoy (Backwards for safe deletion)
	for i in range(CampaignManager.global_inventory.size() - 1, -1, -1):
		var item = CampaignManager.global_inventory[i]
		if item != null and _try_unlock_recipe(item):
			CampaignManager.global_inventory.remove_at(i)
			
	# B. Scan Every Unit's Personal Backpack
	for unit in CampaignManager.player_roster:
		if unit.has("inventory") and unit["inventory"] != null:
			for i in range(unit["inventory"].size() - 1, -1, -1):
				var item = unit["inventory"][i]
				if item != null and _try_unlock_recipe(item):
					unit["inventory"].remove_at(i)

	# --- 3. Recipe book button (always shown; disabled until Blacksmith's Tome) ---
	_sync_blacksmith_recipe_book_button_state()

	# --- 4. REFRESH UI ---
	_update_anvil_visuals()
	_populate_material_list()
	check_blacksmith_recipe()
	if haldor_normal: blacksmith_portrait.texture = haldor_normal
	
	# Only play the welcome text if he didn't just announce a new recipe
	if blacksmith_label.text == "" or blacksmith_label.text.begins_with("The forge"):
		_update_blacksmith_text("welcome")
		
	_play_blacksmith_idle()
	_populate_inventory()
	_refresh_blueprint_stock()
	
func _try_unlock_recipe(item: Resource) -> bool:
	var i_name = str(item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name"))
	
	if i_name == "Blacksmith's Tome":
		CampaignManager.has_recipe_book = true
		return false 
		
	# --- NEW: DETECT THE SMELTER ITEM ---
	if i_name == "Dwarven Crucible":
		CampaignManager.has_smelter = true
		return false # Keep it in the inventory as a key item!
		
	if i_name.begins_with("Recipe:"):
		var name_parts = i_name.split(":")
		if name_parts.size() > 1:
			var recipe_to_unlock = name_parts[1].strip_edges()
			var is_valid = false
			for r in RecipeDatabase.master_recipes:
				if r["name"] == recipe_to_unlock:
					is_valid = true
					break
					
			if is_valid:
				if not CampaignManager.unlocked_recipes.has(recipe_to_unlock):
					CampaignManager.unlocked_recipes.append(recipe_to_unlock)
					if select_sound:
						select_sound.pitch_scale = 1.5
						select_sound.play()
					_play_typewriter_animation("Learned new craft: " + recipe_to_unlock)
				return true 
	return false
					
# A little extra "Juice" for when he's impressed
func _shake_node(node: Control) -> void:
	var original_pos = node.position
	var tween = create_tween()
	for i in range(5):
		var offset = Vector2(randf_range(-5, 5), randf_range(-5, 5))
		tween.tween_property(node, "position", original_pos + offset, 0.05)
	tween.tween_property(node, "position", original_pos, 0.05)
	
func _populate_material_list() -> void:
	for child in material_grid.get_children():
		child.queue_free()
		
	var display_items = []
	
	# 1. Compress the array for stacking (Excluding items currently on the anvil!)
	for i in range(CampaignManager.global_inventory.size()):
		if i in anvil_indices:
			continue # SKIP items that are already sitting on the anvil!
			
		var item = CampaignManager.global_inventory[i]
		if item == null: continue
			
		var can_stack = (item is ConsumableData) or (item is ChestKeyData) or (item is MaterialData)
		var found_stack = false
		
		if can_stack:
			for d in display_items:
				var d_name = d.item.get("weapon_name") if d.item.get("weapon_name") != null else d.item.get("item_name")
				var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
				
				if d_name != null and i_name != null and d_name == i_name:
					d.count += 1
					d.indices.append(i)
					found_stack = true
					break
					
		if not found_stack:
			display_items.append({"item": item, "count": 1, "indices": [i]})
			
	# 2. Build the Buttons
	for d in display_items:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(88, 88)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_camp_style_button(btn, false, 18, 88.0)
		var chit_n := _camp_make_button_style(CAMP_ACTION_SECONDARY.darkened(0.04), CAMP_BORDER, 12, 5)
		chit_n.border_width_left = 3
		chit_n.border_width_top = 3
		chit_n.border_width_right = 3
		chit_n.border_width_bottom = 3
		var chit_h := chit_n.duplicate() as StyleBoxFlat
		chit_h.bg_color = CAMP_ACTION_SECONDARY.lightened(0.1)
		chit_h.border_color = CAMP_BORDER
		btn.add_theme_stylebox_override("normal", chit_n)
		btn.add_theme_stylebox_override("hover", chit_h)
		btn.add_theme_stylebox_override("pressed", chit_n)

		var item = d.item
		var count = d.count
		var first_available_index = d.indices[0] # The exact index of the first item in this stack
		
		if item.get("icon") != null:
			btn.icon = item.icon
			btn.expand_icon = true
		else:
			var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
			btn.text = str(i_name).substr(0, 3) if i_name else "???"
			
		# Stack Counter
		if count > 1:
			var count_lbl = Label.new()
			count_lbl.text = "x" + str(count)
			count_lbl.add_theme_font_size_override("font_size", 20)
			count_lbl.add_theme_color_override("font_color", CAMP_BORDER)
			count_lbl.add_theme_constant_override("outline_size", 4)
			count_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 0.95))
			btn.add_child(count_lbl)
			
			count_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			count_lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			count_lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
			count_lbl.offset_right = -6
			count_lbl.offset_bottom = -4
			
		# Add hover juice
		btn.mouse_entered.connect(func():
			var tween = create_tween().set_parallel(true)
			tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)
			tween.tween_property(btn, "modulate", Color(1.2, 1.15, 1.0), 0.1)
		)
		btn.mouse_exited.connect(func():
			var tween = create_tween().set_parallel(true)
			tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
			tween.tween_property(btn, "modulate", Color.WHITE, 0.1)
		)
		
		# --- ATTACH DRAG DATA ---
		var meta = {"item": item, "convoy_index": first_available_index}
		btn.set_drag_forwarding(_get_drag_material.bind(btn, meta), Callable(), Callable())
		
		# --- THE DOUBLE-CLICK FIX ---
		btn.gui_input.connect(func(event: InputEvent):
			# If the player Double-Clicks the Left Mouse Button, send it instantly!
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
				if select_sound and select_sound.stream != null:
					select_sound.play()
				_auto_send_to_anvil(meta)
		)
		
		material_grid.add_child(btn)


func _camp_make_item_drag_preview(item: Resource, preview_side: float = 88.0) -> Control:
	var sz := Vector2(preview_side, preview_side)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = 1000
	var tex: Texture2D = null
	if item != null:
		tex = item.get("icon") as Texture2D
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = sz
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tr)
		tr.position = -sz * 0.5
	else:
		var shell := Panel.new()
		shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shell.custom_minimum_size = sz
		shell.size = sz
		shell.position = -sz * 0.5
		_camp_style_panel(shell, Color(0.12, 0.09, 0.058, 0.95), CAMP_BORDER_SOFT, 14, 0)
		root.add_child(shell)
		var lbl := Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var i_name: String = ""
		if item != null:
			i_name = str(item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name"))
		if i_name.strip_edges() == "":
			i_name = "?"
		var short := i_name.substr(0, mini(4, i_name.length())).to_upper()
		lbl.text = short
		var fs: int = int(clampf(preview_side * 0.28, 18.0, 28.0))
		_camp_style_label(lbl, CAMP_BORDER, fs, 2)
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.offset_left = 4.0
		lbl.offset_top = 4.0
		lbl.offset_right = -4.0
		lbl.offset_bottom = -4.0
		shell.add_child(lbl)
	return root


# This function is now bound directly to the Button being dragged!
func _get_drag_material(_at_position: Vector2, btn: Button, meta: Dictionary) -> Variant:
	var item = meta["item"]

	# 1. Hide the OS drag badges (like the forbidden circle)
	Input.set_custom_mouse_cursor(empty_cursor, Input.CURSOR_CAN_DROP)
	Input.set_custom_mouse_cursor(empty_cursor, Input.CURSOR_FORBIDDEN)

	var c := _camp_make_item_drag_preview(item, 88.0)
	btn.set_drag_preview(c)
	
	if select_sound and select_sound.stream: select_sound.play()
	
	# 3. Package the exact index and item to drop on the anvil
	return {"type": "blacksmith_material", "item": item, "convoy_index": meta["convoy_index"]}
		
# Called automatically when hovering over a Slot. Determines if the drop is allowed.
func _can_drop_slot(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("type") == "blacksmith_material"

# Called automatically when you let go of the mouse over a Slot
func _drop_slot(_at_position: Vector2, data: Variant, slot_index: int) -> void:
	var item = data["item"]
	var c_idx = data.get("convoy_index", -1)
	
	# Checks if this specific convoy slot is already sitting on the anvil
	if c_idx != -1 and c_idx in anvil_indices: 
		if select_sound and select_sound.stream: 
			select_sound.pitch_scale = 0.5
			select_sound.play()
		return 
		
	if select_sound and select_sound.stream:
		select_sound.pitch_scale = 1.0

	anvil_items[slot_index] = item
	anvil_indices[slot_index] = c_idx

	_update_anvil_visuals()
	_blacksmith_slot_receive_juice(slot_index)
	check_blacksmith_recipe()
	
	# THE FIX: Safely rebuild the UI
	call_deferred("_populate_material_list")
	
# Allows the player to click an item on the anvil to put it back
func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if anvil_items[slot_index] != null:
			anvil_items[slot_index] = null
			anvil_indices[slot_index] = -1 
			if select_sound and select_sound.stream: select_sound.play()
			_update_anvil_visuals()
			check_blacksmith_recipe()
			
			# THE FIX: Safely rebuild the UI
			call_deferred("_populate_material_list")
			
# Visually updates the 3 TextureRects
func _update_anvil_visuals() -> void:
	var slots = [slot1, slot2, slot3]
	
	for i in range(3):
		if anvil_items[i] != null:
			slots[i].texture = anvil_items[i].get("icon")
			slots[i].modulate = Color.WHITE
		else:
			slots[i].texture = null
			# Optional: If using ColorRects instead of TextureRects, change their colors here to look like empty slots.
			slots[i].modulate = Color(0.2, 0.2, 0.2, 0.5)

func check_blacksmith_recipe() -> void:
	current_recipe.clear()
	craft_button.disabled = true
	craft_button.text = "CRAFT" # Default text
	result_icon.texture = null
	
	# --- THE FIX: Define the variables right here! ---
	var current_ingredients = []
	var weapon_count = 0
	var broken_weapon_on_anvil: Resource = null
	var last_weapon: Resource = null
	
	for item in anvil_items:
		if item != null:
			var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
			current_ingredients.append(i_name)
			
			# --- THE FIX: Update the tracking variables inside the loop ---
			if item is WeaponData:
				weapon_count += 1
				last_weapon = item
				if item.get("current_durability") != null and item.current_durability < item.max_durability:
					broken_weapon_on_anvil = item
				
	if current_ingredients.is_empty():
		recipe_result_label.text = "[center][color=gray]Outcome preview appears here when a pattern matches.[/color][/center]"
		_blacksmith_finish_recipe_check()
		return

	current_ingredients.sort()
	
# --- NEW & IMPROVED: SMART SALVAGE ---
	if current_ingredients.size() == 1 and weapon_count == 1:
		if last_weapon != null and last_weapon.get_meta("is_locked", false) == true:
			recipe_result_label.text = "[center][color=red]Cannot salvage a locked item![/color][/center]"
			_blacksmith_finish_recipe_check()
			return
		var yield_name = ""
		
		# 1. First, check if the item has a "Base Recipe" tag (for Masterworks/Renamed items)
		var base_name = last_weapon.get_meta("base_recipe_name", "")
		
		# 2. Try to find the recipe using the tag, or the current name as a fallback
		for recipe in RecipeDatabase.master_recipes:
			if recipe["name"] == base_name or recipe["name"] == last_weapon.weapon_name:
				if recipe.has("ingredients") and recipe["ingredients"].size() > 0:
					yield_name = recipe["ingredients"][0]
					break
		
		# 3. FALLBACK: Only if it's NOT a crafted item (found loot), use rarity
		if yield_name == "":
			match last_weapon.rarity:
				"Common": yield_name = "Iron Ore"
				"Uncommon": yield_name = "Steel Ingot"
				"Rare": yield_name = "Silver Ore"
				"Epic", "Legendary": yield_name = "Mythril Ingot"
			
		# 3. Locate the actual Resource file in your database
		var yield_res = _find_quest_item_resource(yield_name)
		if yield_res == null:
			recipe_result_label.text = "[center][color=red]Cannot salvage: " + yield_name + " not found in Pool.[/color][/center]"
			_blacksmith_finish_recipe_check()
			return

		current_recipe = {"type": "salvage", "weapon": last_weapon, "yield_res": yield_res}
		
		# 4. Update UI
		result_icon.texture = yield_res.get("icon")
		recipe_result_label.text = "[center][color=orange]--- SALVAGING: " + last_weapon.weapon_name.to_upper() + " ---[/color][/center]\n\n"
		recipe_result_label.text += "[center]Reclaiming primary material:\n[color=cyan]1x " + yield_name + "[/color][/center]"
		
		if broken_weapon_on_anvil != null:
			recipe_result_label.text += "\n\n[center][color=gray][i](Tip: Add a Steel Ingot to REPAIR instead!)[/i][/color][/center]"
		
		craft_button.text = "SALVAGE"
		craft_button.disabled = false
		_blacksmith_finish_recipe_check()
		return

	# 1. Check Crafting & Smelting
	for recipe in RecipeDatabase.master_recipes:
		# --- THE FIX: SAFETY CHECK ---
		if not recipe.has("ingredients"):
			push_error("WARNING: A recipe is missing the 'ingredients' key! Recipe name: ", recipe.get("name", "Unknown"))
			continue # Skip this broken recipe and prevent the crash
			
		var req_ingredients = recipe["ingredients"].duplicate()
		req_ingredients.sort()
		
		if current_ingredients == req_ingredients:
			# --- THE EXPLOIT FIX: Check if they actually know the recipe! ---
			# We bypass this check for Smelting and Repairing, as those are basic skills.
			if not recipe.get("is_smelt", false) and not recipe.get("is_structure", false):
				if not CampaignManager.unlocked_recipes.has(recipe["name"]):
					recipe_result_label.text = "[center][color=red]You haven't discovered this recipe yet![/color][/center]"
					_blacksmith_finish_recipe_check()
					return
			current_recipe = recipe.duplicate() 
			
			# --- 1. IS IT A SMELTING JOB? ---
			if recipe.get("is_smelt", false):
				if not CampaignManager.has_smelter:
					recipe_result_label.text = "[center][color=red]Requires a Dwarven Crucible to melt ores![/color][/center]"
					_blacksmith_finish_recipe_check()
					return

				current_recipe["type"] = "smelt"
				craft_button.text = "SMELT"
				
				var preview_item = load(recipe["result"])
				if preview_item:
					result_icon.texture = preview_item.get("icon")
					recipe_result_label.text = "[center][color=cyan]--- SMELTING: " + recipe["name"].to_upper() + " ---[/color][/center]\n\n"
					
			# --- 2. IS IT A STRUCTURE BLUEPRINT? ---
			elif recipe.get("is_structure", false):
				current_recipe["type"] = "structure"
				craft_button.text = "BUILD"
				
				# Load a temporary icon if you provided one
				if recipe.has("icon_path") and ResourceLoader.exists(recipe["icon_path"]):
					result_icon.texture = load(recipe["icon_path"])
				else:
					result_icon.texture = null # Fallback if no icon
					
				recipe_result_label.text = "[center][color=gold]--- ENGINEERING: " + recipe["name"].to_upper() + " ---[/color][/center]\n\n[color=gray]Type:[/color] Battlefield Deployment\nIncreases blueprint stock by +1."
				
			# --- 3. STANDARD WEAPON CRAFTING ---
			else:
				current_recipe["type"] = "craft"
				craft_button.text = "CRAFT"
				
				var preview_item = load(recipe["result"])
				if preview_item:
					result_icon.texture = preview_item.get("icon")
					var cost = preview_item.get("gold_cost")
					var sell_val = int(cost / 2) if cost != null else 0
					var stats_text = _get_item_detailed_info(preview_item, sell_val, 1, null, "Forge preview", true)
					recipe_result_label.text = "[center][color=cyan]--- CRAFTING: " + recipe["name"].to_upper() + " ---[/color][/center]\n\n" + stats_text
				
			craft_button.disabled = false
			_blacksmith_finish_recipe_check()
			return

	# 2. Check Universal Repair 
	if current_ingredients.size() == 2 and broken_weapon_on_anvil != null:
		if current_ingredients.has("Iron Ingot"): # Changed from Bone to Steel Ingot for better logic!
			var w_name = broken_weapon_on_anvil.weapon_name
			current_recipe = {"type": "repair", "weapon": broken_weapon_on_anvil}
			
			result_icon.texture = broken_weapon_on_anvil.get("icon")
			var cost = broken_weapon_on_anvil.get("gold_cost")
			var sell_val = int(cost / 2) if cost != null else 0
			var stats_text = _get_item_detailed_info(broken_weapon_on_anvil, sell_val, 1, null, "Repair preview", true)
			
			stats_text = stats_text.replace(
				"[font_size=17][color=#ff9a8a]Broken[/color][color=#8a7868] — [/color][color=#c4bba8]Half effectiveness until repaired.[/color][/font_size]\n",
				""
			)
			stats_text = "[color=lime]WILL BE FULLY REPAIRED[/color]\n\n" + stats_text
			
			recipe_result_label.text = "[center][color=lime]--- REPAIRING: " + w_name.to_upper() + " ---[/color][/center]\n\n" + stats_text
			
			craft_button.text = "REPAIR"
			craft_button.disabled = false
			_blacksmith_finish_recipe_check()
			return

	var invalid_body := "[center][color=#c45c5c]No known forge pattern for this mix.[/color][/center]\n\n"
	invalid_body += "[center][color=gray]Try different materials or check ingredient counts.[/color][/center]"
	if CampaignManager.has_recipe_book:
		invalid_body += "\n\n[center][color=#c4a060]Open Recipe Book for known recipes and blueprints.[/color][/center]"
	else:
		invalid_body += "\n\n[center][color=gray][i]The full recipe list unlocks with the Blacksmith's Tome.[/i][/color][/center]"
	recipe_result_label.text = invalid_body
	_blacksmith_finish_recipe_check()


func _on_craft_pressed() -> void:
	if current_recipe.is_empty():
		return
	_blacksmith_stop_craft_ready_affordance()

	var is_masterwork = false
	
	# 1. RUN MINIGAME (Skip for salvaging)
	if current_recipe["type"] != "salvage":
		blacksmith_panel.visible = false
		is_masterwork = await _run_forge_minigame()
		blacksmith_panel.visible = true
	else:
		# Play a heavy crunching/breaking sound instead!
		if shop_sell_sound and shop_sell_sound.stream: 
			shop_sell_sound.pitch_scale = 0.6
			shop_sell_sound.play()
	
	# 2. CONSUME INGREDIENTS
	# Consume the ingredients on the anvil (This safely deletes the items from convoy)
	for anvil_item in anvil_items:
		if anvil_item != null:
			# If it's a repair, don't delete the weapon itself!
			if current_recipe.get("type") == "repair" and anvil_item == current_recipe["weapon"]:
				continue
				
			for i in range(CampaignManager.global_inventory.size() -1, -1, -1):
				var convoy_item = CampaignManager.global_inventory[i]
				if convoy_item == anvil_item:
					CampaignManager.global_inventory.remove_at(i)
					break
						
	# 3. EXECUTE RESULT BASED ON TYPE
	if current_recipe["type"] == "craft" or current_recipe["type"] == "smelt":
		var new_item = load(current_recipe["result"])
		if new_item:
			var crafted_item = CampaignManager.duplicate_item(new_item)
			crafted_item.set_meta("base_recipe_name", current_recipe["name"])
						
			if is_masterwork and crafted_item is WeaponData:
				# --- MASTERWORK WEAPON ---
				await _play_dynamic_crafting_visuals(crafted_item.get("icon"), true)
				var bonuses = "+2 Might | +10 Hit | +10 Durability"
				var custom_name = await _ask_for_masterwork_name(crafted_item.weapon_name, bonuses)
				
				if haldor_impressed: blacksmith_portrait.texture = haldor_impressed
				_shake_node(blacksmith_portrait)
				
				crafted_item.weapon_name = custom_name
				crafted_item.might += 2
				crafted_item.hit_bonus += 10
				crafted_item.max_durability += 10
				crafted_item.current_durability = crafted_item.max_durability
				crafted_item.rarity = "Legendary"
				if "gold_cost" in crafted_item: crafted_item.gold_cost *= 2
				crafted_item.resource_path = "" 
				_update_blacksmith_text("craft_masterwork")
				
			elif is_masterwork and current_recipe["type"] == "smelt":
				# --- MASTERWORK SMELTING (Double Yield) ---
				await _play_dynamic_crafting_visuals(crafted_item.get("icon"), true)
				var bonus_ingot = CampaignManager.duplicate_item(new_item)
				CampaignManager.global_inventory.append(bonus_ingot)
				
				if haldor_impressed: blacksmith_portrait.texture = haldor_impressed
				_play_typewriter_animation("A perfect melt! We yielded extra materials!")
			else:
				# --- NORMAL CRAFT/SMELT ---
				await _play_dynamic_crafting_visuals(crafted_item.get("icon"), false)
				if current_recipe["type"] == "smelt":
					_play_typewriter_animation("Ore refined. It's ready for the hammer.")
				else:
					_update_blacksmith_text("craft_normal")
			
			CampaignManager.global_inventory.append(crafted_item)
	
	# --- STRUCTURE CRAFTING LOGIC ---
	elif current_recipe["type"] == "structure":
		# Find the blueprint in the global manager and add +1 to its count!
		var found_struct = false
		for struct in CampaignManager.player_structures:
			if struct["name"] == current_recipe["name"]:
				struct["count"] += 1
				found_struct = true
				break
				
		# Failsafe: If the player somehow crafts a barricade they don't own the blueprint for yet!
		if not found_struct:
			print("WARNING: Crafted a structure that isn't in the global Blueprint List!")
			
		# Visual feedback
		var fake_tex = load(current_recipe["icon_path"]) if current_recipe.has("icon_path") else null
		await _play_dynamic_crafting_visuals(fake_tex, is_masterwork)
		
		if is_masterwork:
			# Masterwork bonus: You built TWO structures instead of one!
			for struct in CampaignManager.player_structures:
				if struct["name"] == current_recipe["name"]:
					struct["count"] += 1 
					break
			_play_typewriter_animation("Brilliant engineering! I managed to build two from the same materials!")
		else:
			_play_typewriter_animation("Blueprint assembled. It's ready for the battlefield.")		
	
	elif current_recipe["type"] == "repair":
		var repaired_weapon = current_recipe["weapon"]
		repaired_weapon.current_durability = repaired_weapon.max_durability
		
		await _play_dynamic_crafting_visuals(repaired_weapon.get("icon"), is_masterwork)
		
		if is_masterwork:
			repaired_weapon.current_durability += 10 
			repaired_weapon.max_durability += 10
			repaired_weapon.resource_path = "" 
			if haldor_impressed: blacksmith_portrait.texture = haldor_impressed
			_update_blacksmith_text("repair_masterwork")
		else:
			_update_blacksmith_text("repair_normal")
	
	elif current_recipe["type"] == "salvage":
		var salvaged_mat = CampaignManager.duplicate_item(current_recipe["yield_res"])
		CampaignManager.global_inventory.append(salvaged_mat)
		
		await _play_dynamic_crafting_visuals(salvaged_mat.get("icon"), false)
		_update_blacksmith_text("salvage")

	await _blacksmith_forge_success_panel_juice()

	# 4. CLEAN UP & REFRESH
	anvil_items = [null, null, null]
	anvil_indices = [-1, -1, -1]
	_update_anvil_visuals()
	_populate_material_list()
	_populate_inventory() 
	check_blacksmith_recipe()
	_refresh_blueprint_stock()
		
# ==========================================
# THE FORGE MINIGAME
# ==========================================
func _run_forge_minigame() -> bool:
	var qte_layer = CanvasLayer.new()
	qte_layer.layer = 100 
	add_child(qte_layer)
	
	var vp_size = get_viewport_rect().size
	
	# Dim the screen slightly
	var screen_dimmer = ColorRect.new()
	screen_dimmer.size = vp_size
	screen_dimmer.color = Color(0, 0, 0, 0.5)
	qte_layer.add_child(screen_dimmer)
	
	# The Anvil Bar (Heated metal colors)
	var bar_bg = ColorRect.new()
	bar_bg.size = Vector2(500, 40)
	bar_bg.position = (vp_size - bar_bg.size) / 2.0
	bar_bg.color = Color(0.2, 0.05, 0.05, 0.95) # Dark iron
	qte_layer.add_child(bar_bg)
	
	# The "Perfect Strike" Zone
	var perfect_zone = ColorRect.new()
	perfect_zone.size = Vector2(40, 40)
	perfect_zone.color = Color(1.0, 0.6, 0.0, 1.0) # Glowing orange/gold
	# Randomize where the sweet spot is!
	perfect_zone.position = Vector2(randf_range(100, 400), 0)
	bar_bg.add_child(perfect_zone)
	
	# The Hammer Cursor
	var cursor = ColorRect.new()
	cursor.size = Vector2(12, 60)
	cursor.position = Vector2(0, -10)
	cursor.color = Color.WHITE
	bar_bg.add_child(cursor)
	
	var help_text = Label.new()
	help_text.text = "STRIKE THE IRON! (SPACE)"
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.add_theme_font_size_override("font_size", 32)
	bar_bg.add_child(help_text)
	help_text.position = Vector2(0, -50)
	help_text.size.x = bar_bg.size.x
	
	# THE TIMING LOOP
	var total_ms = 800 # 0.8 seconds to react (Fair but requires focus)
	var start_ms = Time.get_ticks_msec()
	var is_masterwork = false
	var pressed = false
	
	while true:
		await get_tree().process_frame
		var elapsed_ms = Time.get_ticks_msec() - start_ms
		
		if elapsed_ms >= total_ms:
			break
			
		var progress = float(elapsed_ms) / float(total_ms)
		cursor.position.x = progress * bar_bg.size.x
		
		if Input.is_action_just_pressed("ui_accept"):
			pressed = true
			var cursor_center = cursor.position.x + (cursor.size.x / 2.0)
			var tz_start = perfect_zone.position.x
			var tz_end = tz_start + perfect_zone.size.x
			
			if cursor_center >= tz_start and cursor_center <= tz_end:
				is_masterwork = true
				help_text.text = "MASTERWORK!"
				help_text.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
				cursor.color = Color.YELLOW
				
				# The QTE Ping (Epic visual sound happens after this!)
				if select_sound and select_sound.stream: 
					select_sound.pitch_scale = 1.5 
					select_sound.play()
			else:
				is_masterwork = false
				help_text.text = "NORMAL CRAFT"
				cursor.color = Color.GRAY
				
				# --- NORMAL STRIKE SOUND (Missed Sweet Spot) ---
				if masterwork_sound and masterwork_sound.stream: 
					masterwork_sound.pitch_scale = 0.8 # Deeper, heavy thud
					masterwork_sound.play()
			break
			
	if not pressed:
		is_masterwork = false
		help_text.text = "NORMAL CRAFT"
		
		# --- NORMAL STRIKE SOUND (Did not press anything) ---
		if masterwork_sound and masterwork_sound.stream: 
			masterwork_sound.pitch_scale = 0.8 
			masterwork_sound.play()
		
	# Hold the result on screen for a split second so they see what they got
	await get_tree().create_timer(0.6).timeout 
	qte_layer.queue_free()
	
	return is_masterwork
	
func close_blacksmith() -> void:
	if select_sound and select_sound.stream: select_sound.play()
	
	# Clear the anvil array AND indices
	for i in range(3):
		anvil_items[i] = null
		anvil_indices[i] = -1 # Clear the index!
		
	# Wipe the recipe memory
	check_blacksmith_recipe()

	blacksmith_panel.visible = false
	if recipe_book_panel != null:
		recipe_book_panel.visible = false
	_blacksmith_stop_craft_ready_affordance()
	if _blacksmith_dimmer != null:
		_blacksmith_dimmer.visible = false

# ==========================================
# SYSTEM NOTIFICATIONS (DRAG END)
# ==========================================
func _notification(what: int) -> void:
	# This triggers the millisecond a drag-and-drop ends
	if what == NOTIFICATION_DRAG_END:
		# Restore the normal mouse cursors!
		Input.set_custom_mouse_cursor(null, Input.CURSOR_CAN_DROP)
		Input.set_custom_mouse_cursor(null, Input.CURSOR_FORBIDDEN)

func _open_recipe_book() -> void:
	if not CampaignManager.has_recipe_book:
		return
	if select_sound: select_sound.play()

	# Safety Check: If the panel node is missing, stop here to avoid the crash!
	if recipe_book_panel == null:
		push_error("Error: RecipeBookPanel node not found. Check Unique Name (%) in Editor.")
		return

	var txt = "[center][color=#e8c040]— HALDOR'S FORGE NOTES —[/color][/center]\n\n"
	
	# --- NEW: DISPLAY CURRENT BLUEPRINT STOCK ---
	txt += "[color=cyan]--- CURRENT BLUEPRINTS ---[/color]\n"
	for struct in CampaignManager.player_structures:
		var s_name = struct.get("name", "Unknown")
		var s_count = struct.get("count", 0)
		txt += "[color=white]" + s_name + ": " + str(s_count) + "[/color]\n"
	txt += "\n"
	# --------------------------------------------
	
	for recipe in RecipeDatabase.master_recipes:
		if CampaignManager.unlocked_recipes.has(recipe["name"]):
			txt += "[color=cyan]" + recipe["name"].to_upper() + "[/color]\n"
			txt += "[color=gray]Requires:[/color] " + ", ".join(recipe["ingredients"]) + "\n\n"
		else:
			txt += "[color=dimgray]??? (Undiscovered Recipe)[/color]\n\n"
			
	if recipe_list_text: 
		recipe_list_text.text = txt
		
	# Now this line is safe
	recipe_book_panel.visible = true

func _close_recipe_book() -> void:
	if select_sound and select_sound.stream: select_sound.play()
	if recipe_book_panel: recipe_book_panel.visible = false

# ==========================================
# MASTERWORK NAMING UI
# ==========================================
func _ask_for_masterwork_name(base_name: String, bonus_text: String) -> String:
	var rename_layer = CanvasLayer.new()
	rename_layer.layer = 110 
	add_child(rename_layer)

	var vp_size = get_viewport_rect().size

	var dimmer = ColorRect.new()
	dimmer.size = vp_size
	dimmer.color = Color(0, 0, 0, 0.85)
	rename_layer.add_child(dimmer)

	# Made the box slightly taller to fit the stats (220 instead of 200)
	var box = ColorRect.new()
	box.size = Vector2(400, 220)
	box.position = (vp_size - box.size) / 2.0
	box.color = Color(0.1, 0.1, 0.1, 0.95)
	rename_layer.add_child(box)

	var title = Label.new()
	title.text = "NAME YOUR MASTERWORK!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.GOLD)
	title.add_theme_font_size_override("font_size", 24)
	title.position = Vector2(0, 20)
	title.size.x = box.size.x
	box.add_child(title)

	var line_edit = LineEdit.new()
	line_edit.size = Vector2(320, 40)
	line_edit.position = Vector2(40, 65)
	line_edit.placeholder_text = "Masterwork " + base_name
	line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(line_edit)
	
	# --- THE NEW STAT BONUS DISPLAY ---
	var stat_label = Label.new()
	stat_label.text = bonus_text
	stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2)) # Bright Lime Green
	stat_label.position = Vector2(0, 115)
	stat_label.size.x = box.size.x
	box.add_child(stat_label)

	var confirm_btn = Button.new()
	confirm_btn.text = "Forge Legend"
	confirm_btn.size = Vector2(160, 40)
	confirm_btn.position = Vector2(120, 155) # Shifted down slightly
	box.add_child(confirm_btn)

	line_edit.grab_focus() 

	var confirm_func = func(_dummy_arg = ""):
		var final_name = line_edit.text.strip_edges()
		if final_name == "": 
			final_name = "Masterwork " + base_name
		emit_signal("name_confirmed", final_name)

	confirm_btn.pressed.connect(confirm_func)
	line_edit.text_submitted.connect(confirm_func)

	var chosen_name = await self.name_confirmed 
	
	rename_layer.queue_free()
	return chosen_name

# ==========================================
# DYNAMIC CRAFTING VISUALS
# ==========================================
func _play_dynamic_crafting_visuals(item_texture: Texture2D, is_masterwork: bool) -> void:
	# 1. AUDIO DUCKING
	var original_bgm_vol: float = 0.0
	if camp_music and camp_music.playing:
		original_bgm_vol = camp_music.volume_db
		var duck_tween = create_tween()
		duck_tween.tween_property(camp_music, "volume_db", original_bgm_vol - 15.0, 0.2)
		
	# 2. SOUND EFFECTS
	if masterwork_sound and masterwork_sound.stream: 
		masterwork_sound.pitch_scale = 1.0 if is_masterwork else 0.8
		masterwork_sound.play()
		
		if is_masterwork:
			# Magical Echo for Masterwork
			get_tree().create_timer(0.4).timeout.connect(func():
				var echo = AudioStreamPlayer.new()
				echo.stream = masterwork_sound.stream
				echo.pitch_scale = 1.5
				echo.volume_db = masterwork_sound.volume_db - 5.0
				add_child(echo)
				echo.play()
				echo.finished.connect(echo.queue_free)
			)

	var fx_layer = CanvasLayer.new()
	fx_layer.layer = 120 
	add_child(fx_layer)
	var vp_size = get_viewport_rect().size
	
	# 3. BLINDING FLASH (Masterwork Only)
	if is_masterwork:
		var flash = ColorRect.new()
		flash.size = vp_size
		flash.color = Color.WHITE
		fx_layer.add_child(flash)
		var f_tween = create_tween()
		f_tween.tween_property(flash, "color:a", 0.0, 0.4)

	# 4. ITEM ICON
	var icon = TextureRect.new()
	icon.texture = item_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(200, 200)
	icon.position = (vp_size - icon.custom_minimum_size) / 2.0
	icon.pivot_offset = icon.custom_minimum_size / 2.0
	icon.modulate = Color(1.5, 1.5, 1.2, 1.0) if is_masterwork else Color.WHITE
	fx_layer.add_child(icon)
	
	# 5. "SENT TO CONVOY" LABEL
	var msg = Label.new()
	if is_masterwork:
		msg.text = "LEGEND FORGED!"
	else:
		if current_recipe.get("type") == "repair":
			msg.text = "REPAIRED!"
		elif current_recipe.get("type") == "salvage":
			msg.text = "SALVAGED!"
		else:
			msg.text = "SENT TO CONVOY"
	
	
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 28)
	msg.add_theme_color_override("font_color", Color.GOLD if is_masterwork else Color.WHITE)
	msg.position = Vector2(0, icon.position.y + 220)
	msg.size.x = vp_size.x
	msg.modulate.a = 0.0 # Start hidden
	fx_layer.add_child(msg)

	# 6. ANIMATION TWEEN
	var tween = create_tween().set_parallel(true)
	icon.scale = Vector2(0.1, 0.1)
	
	# Timing: Masterwork stays 2s, Normal stays 0.8s
	var hold_time = 2.0 if is_masterwork else 0.8
	
	tween.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(msg, "modulate:a", 1.0, 0.3)
	
	# Fade everything out after the hold time
	tween.chain().set_parallel(true)
	tween.tween_property(icon, "modulate:a", 0.0, 0.4).set_delay(hold_time)
	tween.tween_property(msg, "modulate:a", 0.0, 0.4).set_delay(hold_time)
	
	await tween.finished
	
	# 7. RESTORE BGM
	if camp_music:
		var restore_tween = create_tween()
		restore_tween.tween_property(camp_music, "volume_db", original_bgm_vol, 1.0)
	
	fx_layer.queue_free()

func _update_blacksmith_text(category: String) -> void:
	if not blacksmith_label: return
	
	var lines = DialogueDatabase.blacksmith_lines[category]
	var full_text = lines[randi() % lines.size()]
	
	blacksmith_label.text = full_text
	blacksmith_label.visible_characters = 0
	
	# THE FIX: Kill the old animation
	if blacksmith_tween and blacksmith_tween.is_valid():
		blacksmith_tween.kill()
	
	var duration = full_text.length() * 0.04
	blacksmith_tween = create_tween()
	blacksmith_tween.tween_method(_set_blacksmith_visible_chars, 0, full_text.length(), duration)
	
func _set_blacksmith_visible_chars(count: int) -> void:
	if count > blacksmith_label.visible_characters:
		var current_char = blacksmith_label.text.substr(count - 1, 1)
		if current_char != " " and merchant_blip and merchant_blip.stream != null:
			merchant_blip.play() # Reuse the blip sound!
	blacksmith_label.visible_characters = count
	
func _play_blacksmith_idle() -> void:
	if not blacksmith_portrait: return
	var tween = create_tween().set_loops()
	tween.tween_property(blacksmith_portrait, "scale", Vector2(1.02, 1.02), 2.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(blacksmith_portrait, "scale", Vector2(1.0, 1.0), 2.5).set_trans(Tween.TRANS_SINE)

func _on_blacksmith_talk_pressed() -> void:
	if select_sound: select_sound.play()
	
	var available_lines = []
	
	# 1. Filter the lines based on how far the player is in the game
	for mono in DialogueDatabase.blacksmith_monologues:
		# max_unlocked_index is the variable you used for the World Map button!
		if CampaignManager.max_unlocked_index >= mono["unlock_level"]:
			available_lines.append(mono["text"])
			
	if available_lines.is_empty(): return
	
	# 2. Pick a random line, ensuring it's not the exact same as the last one
	var chosen_text = available_lines[randi() % available_lines.size()]
	
	while chosen_text == last_monologue_text and available_lines.size() > 1:
		chosen_text = available_lines[randi() % available_lines.size()]
		
	# Remember this line for next time
	last_monologue_text = chosen_text
	
	# 3. Animate the text in the Blacksmith's dialogue box
	if blacksmith_label:
		blacksmith_label.text = chosen_text
		blacksmith_label.visible_characters = 0
		
		var duration = chosen_text.length() * 0.04
		var tween = create_tween()
		
		# This uses the specific Blacksmith text function so the Merchant doesn't talk!
		tween.tween_method(_set_blacksmith_visible_chars, 0, chosen_text.length(), duration)
		
	if blacksmith_portrait:
		_shake_node(blacksmith_portrait)

func _refresh_blueprint_stock() -> void:
	if blueprint_stock_label == null: return
	
	var txt = ""
	
	for struct in CampaignManager.player_structures:
		var s_name = struct.get("name", "Unknown")
		var s_count = struct.get("count", 0)
		
		# Color it red if out of stock, white if available
		var count_color = "white" if s_count > 0 else "red"
		txt += "[color=gray]" + s_name + ":[/color] [color=" + count_color + "]" + str(s_count) + "[/color]\n"
		
	blueprint_stock_label.text = txt

# --- NEW QUALITY OF LIFE: CLICK TO SEND ---
func _auto_send_to_anvil(meta: Dictionary) -> void:
	# Find the first empty slot on the anvil (0, 1, or 2)
	var empty_slot = -1
	for i in range(3):
		if anvil_items[i] == null:
			empty_slot = i
			break
			
	# If we found an empty spot, automatically trigger the drop logic!
	if empty_slot != -1:
		anvil_items[empty_slot] = meta["item"]
		anvil_indices[empty_slot] = meta["convoy_index"]
		
		if shop_buy_sound and shop_buy_sound.stream: shop_buy_sound.play()
		
		_update_anvil_visuals()
		check_blacksmith_recipe()
		
		# THE FIX: Wait until the mouse click is fully resolved before rebuilding the UI!
		call_deferred("_populate_material_list") 
	else:
		# Anvil is full! (Fallback to select_sound if invalid_sound doesn't exist)
		if select_sound and select_sound.stream != null: 
			select_sound.play()
func _on_use_pressed() -> void:
	if selected_inventory_meta.is_empty(): return
	var meta = selected_inventory_meta
	var item = meta.get("item")
	
	if not (item is ConsumableData): return
	
	var unit_idx = selected_roster_index
	if unit_idx < 0 or unit_idx >= CampaignManager.player_roster.size():
		return
	var unit_data = CampaignManager.player_roster[unit_idx]
	
	# --- JUICE: TRACK GAINS FOR FEEDBACK ---
	var feedback_list = []
	var should_consume_item: bool = false
	
	# ==========================================
	# PROMOTION ITEM LOGIC (SHARED WITH BATTLEFIELD RULES)
	# ==========================================
	var item_name_lower = str(item.item_name).to_lower()
	if item.get("is_promotion_item") == true:
		var current_class: Resource = PromotionFlowSharedHelpers.resolve_current_class_from_roster_unit(unit_data)
		var promotion_options: Array[Resource] = PromotionFlowSharedHelpers.get_promotion_options(current_class)
		if not PromotionFlowSharedHelpers.can_unit_promote(int(unit_data.get("level", 1)), current_class):
			_play_camp_inv_sfx_invalid()
			if warning_dialog:
				warning_dialog.dialog_text = "Cannot Promote!"
				warning_dialog.popup_centered()
			return

		var chosen_advanced_class: Resource = await _ask_for_promotion_choice(promotion_options)
		if chosen_advanced_class == null:
			return

		var promo_result: Dictionary = PromotionFlowSharedHelpers.apply_promotion_to_roster_unit(unit_data, chosen_advanced_class)
		var promoted_name: String = str(promo_result.get("new_class_name", "Advanced Class"))
		var promo_gains: Dictionary = promo_result.get("gains", {})
		feedback_list.append("CLASS CHANGE: " + promoted_name.to_upper())
		var hp_gain: int = int(promo_gains.get("hp", 0))
		if hp_gain != 0:
			feedback_list.append("%+d MAX HP" % hp_gain)
		var gain_labels := {"str": "STR", "mag": "MAG", "def": "DEF", "res": "RES", "spd": "SPD", "agi": "AGI"}
		for short_key in gain_labels.keys():
			var amount: int = int(promo_gains.get(short_key, 0))
			if amount != 0:
				feedback_list.append("%+d %s" % [amount, gain_labels[short_key]])
		_play_camp_inv_sfx_use()
		should_consume_item = true

	# ==========================================
	# NEW: EGG CONSUMPTION LOGIC (SOUL ABSORPTION)
	# ==========================================
	elif "egg" in item_name_lower:
		var element = "Fire" # Fallback
		var egg_uid = item.get_meta("egg_uid", "")
		var found_in_queue = false
		
		# If it's a Bred Egg, search the queue to find its exact element!
		if egg_uid != "":
			for i in range(DragonManager.unhatched_eggs.size()):
				if str(DragonManager.unhatched_eggs[i].get("egg_uid", "")) == egg_uid:
					element = str(DragonManager.unhatched_eggs[i].get("element", "Fire"))
					# CRITICAL: Remove the unborn baby from the queue so it can't be hatched anymore!
					DragonManager.unhatched_eggs.remove_at(i)
					found_in_queue = true
					break
					
		# If it's a Mystery Egg (or queue failed), it grants a random elemental stat!
		if egg_uid == "" or not found_in_queue:
			var elements = ["Fire", "Ice", "Lightning", "Earth", "Wind"]
			element = elements[randi() % elements.size()]
			
		# Apply the Permanent Stat Boost based on the Element!
		match element:
			"Fire":
				unit_data["strength"] += 1
				feedback_list.append("+1 STR (Fire Soul)")
			"Ice":
				unit_data["resistance"] += 1
				feedback_list.append("+1 RES (Ice Soul)")
			"Lightning":
				unit_data["speed"] += 1
				feedback_list.append("+1 SPD (Lightning Soul)")
			"Earth":
				unit_data["defense"] += 1
				feedback_list.append("+1 DEF (Earth Soul)")
			"Wind":
				unit_data["agility"] += 1
				feedback_list.append("+1 AGI (Wind Soul)")
				
		# Play a cool, deep sound for consuming a dragon soul!
		if masterwork_sound and masterwork_sound.stream: 
			masterwork_sound.pitch_scale = 0.7 # Deep rumbling absorption
			masterwork_sound.play()
		should_consume_item = true
			
	# ==========================================
	# EXISTING LOGIC: POTIONS, MUSIC, STAT BOOSTS
	# ==========================================
	else:
		# --- JUKEBOX DISC LOGIC ---
		if item.get("unlocked_music_track") != null and item.unlocked_music_track != null:
			var track_path = item.unlocked_music_track.resource_path
			var t_name = item.get("track_title") if item.get("track_title") != "" else "Unknown Track"
			var save_string = t_name + "|" + track_path
			
			if CampaignManager.unlocked_music_paths.has(save_string):
				_play_camp_inv_sfx_invalid()
				if warning_dialog:
					warning_dialog.dialog_text = "You already unlocked this track!"
					warning_dialog.popup_centered()
				return
				
			CampaignManager.unlocked_music_paths.append(save_string)
			feedback_list.append("🎶 UNLOCKED: " + t_name)
		
		# --- HEALING LOGIC ---
		var heal_val = item.heal_amount if item.heal_amount != null else 0
		if heal_val > 0:
			var actual_heal = min(heal_val, unit_data["max_hp"] - unit_data["current_hp"])
			unit_data["current_hp"] += actual_heal
			feedback_list.append("+ " + str(actual_heal) + " HP")
			
		# --- STANDARD STAT BOOSTERS ---
		var hp_b = item.hp_boost if item.hp_boost != null else 0
		if hp_b > 0:
			unit_data["max_hp"] += hp_b
			unit_data["current_hp"] += hp_b
			feedback_list.append("+ " + str(hp_b) + " MAX HP")
			
		var stats = {"strength": "STR", "magic": "MAG", "defense": "DEF", "resistance": "RES", "speed": "SPD", "agility": "AGI"}
		for key in stats.keys():
			var boost_key = key.substr(0, 3) + "_boost" 
			var boost_val = item.get(boost_key) 
			
			if boost_val != null and boost_val > 0:
				unit_data[key] += boost_val
				feedback_list.append("+ " + str(boost_val) + " " + stats[key])

		_play_camp_inv_sfx_use()
		should_consume_item = true

	if not should_consume_item:
		return
	
	# --- EXECUTE CONSUMPTION (REMOVE THE ITEM) ---
	if meta["source"] == "unit":
		unit_data["inventory"].remove_at(meta["inv_index"])
	elif meta["source"] == "convoy":
		CampaignManager.global_inventory.remove_at(meta["index"])
	elif meta["source"] == "other_unit":
		var other_unit = CampaignManager.player_roster[meta["unit_index"]]
		other_unit["inventory"].remove_at(meta["inv_index"])

	# --- THE JUICE SEQUENCE ---
	if portrait_rect: _shake_node(portrait_rect)
	if stats_label: _shake_node(stats_label)
	
	if portrait_rect:
		var flash = create_tween()
		flash.tween_property(portrait_rect, "modulate", Color(2.5, 2.5, 2.5, 1), 0.1)
		flash.tween_property(portrait_rect, "modulate", Color.WHITE, 0.2)
	
	_spawn_use_feedback(feedback_list)

	# Refresh UI
	_populate_inventory()
	_on_roster_item_selected(unit_idx)
				
func _spawn_use_feedback(lines: Array) -> void:
	if lines.is_empty(): return
	
	# Create a container for the scrolling text
	var container = VBoxContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	
	# Position it over the character's name/portrait area
	container.global_position = portrait_rect.global_position + Vector2(20, 50)
	
	for line in lines:
		var lbl = Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 28)
		lbl.add_theme_color_override("font_color", Color.CYAN if "HP" not in line else Color.LIME)
		lbl.add_theme_constant_override("outline_size", 8)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		container.add_child(lbl)
	
	# Animate the whole container floating up and vanishing
	var t = create_tween()
	t.tween_property(container, "global_position:y", container.global_position.y - 100, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(container, "modulate:a", 0.0, 1.5).set_delay(0.5)
	t.tween_callback(container.queue_free)

# ==========================================
# BULK BUY / SELL QUANTITY LOGIC
# ==========================================

func _open_quantity_popup(i_name: String, max_amt: int, _price: int) -> void:
	qty_item_name.text = i_name
	qty_slider.min_value = 1
	qty_slider.max_value = max_amt
	qty_slider.value = 1
	_on_qty_slider_changed(1) # Initialize the text immediately
	
	quantity_popup.visible = true

func _on_qty_slider_changed(value: float) -> void:
	var amt = int(value)
	qty_amount_label.text = "x" + str(amt)
	qty_price_label.text = "Total: " + str(amt * qty_base_price) + "G"
	
	# Optional: Tiny tick sound when sliding
	# if select_sound: select_sound.play() 

## Handles quantity-popup confirm: bulk buy (item fly-in from shop slot) or bulk sell (gold fountain to gold_label).
## Purpose: Same juice as single buy/sell; origin for buy = shop button center, for sell = inventory/popup center. Audio synced to animations.
## Inputs: None (uses qty_mode, qty_slider, qty_base_price, selected_shop_meta / selected_inventory_meta). Outputs: None. Side effects: CampaignManager, UI, animations, sounds.
func _on_qty_confirm_pressed() -> void:
	quantity_popup.visible = false
	var amt: int = int(qty_slider.value)
	var total_price: int = amt * qty_base_price
	if qty_mode == "buy":
		var item = selected_shop_meta["item"]
		var index: int = selected_shop_meta["index"]
		var shop_origin: Vector2 = _get_shop_button_center(index)
		CampaignManager.global_gold -= total_price
		for i in range(amt):
			CampaignManager.global_inventory.append(CampaignManager.duplicate_item(item))
		shop_stock.remove_at(index)
		CampaignManager.camp_shop_stock = shop_stock.duplicate()
		if item == discounted_item:
			discounted_item = null
			CampaignManager.camp_discount_item = null
		if item == CampaignManager.camp_second_discount_item:
			CampaignManager.camp_second_discount_item = null
		_update_merchant_text("buy")
		_refresh_gold_label()
		var inv_target: Vector2 = (inventory_desc.global_position + inventory_desc.size / 2.0) if inventory_desc else get_viewport_rect().get_center()
		_animate_buy_item_fly_in(shop_origin, inv_target, item)
	elif qty_mode == "sell":
		var item = selected_inventory_meta["item"]
		var meta: Dictionary = selected_inventory_meta
		var base_name: String = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
		CampaignManager.global_gold += total_price
		var target_inventory: Array = CampaignManager.global_inventory if meta["source"] == "convoy" else CampaignManager.player_roster[meta["unit_index"]]["inventory"]
		var removed: int = 0
		for i in range(target_inventory.size() - 1, -1, -1):
			var inv_item = target_inventory[i]
			var i_name: String = inv_item.get("weapon_name") if inv_item.get("weapon_name") != null else inv_item.get("item_name")
			if i_name == base_name:
				target_inventory.remove_at(i)
				removed += 1
				if removed >= amt:
					break
		_update_merchant_text("sell")
		var sell_origin: Vector2 = (quantity_popup.global_position + quantity_popup.size / 2.0) if quantity_popup else get_viewport_rect().get_center()
		_animate_sell_gold_fountain(sell_origin, total_price)
	_refresh_gold_label()
	_populate_inventory()
	_populate_shop()
	shop_desc.text = ""
	if inventory_desc:
		_camp_inventory_desc_set_text("Transaction complete.")

# ==========================================
# INVENTORY DRAG AND DROP
# ==========================================
func _get_drag_inventory(_at_position: Vector2, btn: Button, meta: Dictionary) -> Variant:
	var item = meta["item"]
	Input.set_custom_mouse_cursor(empty_cursor, Input.CURSOR_CAN_DROP)
	Input.set_custom_mouse_cursor(empty_cursor, Input.CURSOR_FORBIDDEN)

	var c := _camp_make_item_drag_preview(item, 88.0)
	btn.set_drag_preview(c)
	if select_sound: select_sound.play()
	return {"type": "inventory_item", "meta": meta}

func _can_drop_inv(_at_pos: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("type") == "inventory_item"

func _drop_on_unit(_at_pos: Vector2, data: Variant) -> void:
	var meta = data["meta"]
	if meta["source"] == "unit": return # Already in backpack
	
	var item = meta["item"]
	var unit_idx = selected_roster_index
	var unit_data = CampaignManager.player_roster[unit_idx]
	
	if unit_data["inventory"].size() >= 5:
		warning_dialog.dialog_text = unit_data["unit_name"] + "'s backpack is full!"
		warning_dialog.popup_centered()
		return
		
	if meta["source"] == "convoy":
		CampaignManager.global_inventory.remove_at(meta["index"])
	elif meta["source"] == "other_unit":
		CampaignManager.player_roster[meta["unit_index"]]["inventory"].remove_at(meta["inv_index"])
		
	unit_data["inventory"].append(item)
	if shop_buy_sound: shop_buy_sound.play() # Nice thud sound
	_populate_inventory()
	_on_roster_item_selected(unit_idx)

func _drop_on_convoy(_at_pos: Vector2, data: Variant) -> void:
	var meta = data["meta"]
	if meta["source"] == "convoy": return # Already in convoy
	
	var item = meta["item"]
	var unit_idx = selected_roster_index
	
	if meta["source"] == "unit":
		var unit_data = CampaignManager.player_roster[unit_idx]
		unit_data["inventory"].remove_at(meta["inv_index"])
		if unit_data.get("equipped_weapon") == item:
			unit_data["equipped_weapon"] = null
	elif meta["source"] == "other_unit":
		var other_unit = CampaignManager.player_roster[meta["unit_index"]]
		other_unit["inventory"].remove_at(meta["inv_index"])
		if other_unit.get("equipped_weapon") == item:
			other_unit["equipped_weapon"] = null
	
	var to_append: Resource = CampaignManager.make_unique_item(item)
	if to_append != null:
		if not to_append.has_meta("original_path") and item.resource_path != "":
			to_append.set_meta("original_path", item.resource_path)
		elif not to_append.has_meta("original_path") and item.has_meta("original_path"):
			to_append.set_meta("original_path", item.get_meta("original_path"))
		CampaignManager.global_inventory.append(to_append)
	if shop_buy_sound: shop_buy_sound.play()
	_populate_inventory()
	_on_roster_item_selected(unit_idx)

# ==========================================
# REFRESH SHOP & WANTED MENU LOGIC
# ==========================================
func _on_refresh_shop_pressed() -> void:
	var cost = 100
	if CampaignManager.global_gold >= cost:
		CampaignManager.global_gold -= cost
		_refresh_gold_label()
		if shop_buy_sound: shop_buy_sound.play()
		
		_generate_shop_inventory()
		_apply_random_discount()
		
		CampaignManager.camp_shop_stock = shop_stock.duplicate()
		CampaignManager.camp_discount_item = discounted_item
		_populate_shop()
		
		_play_typewriter_animation("I rummaged through the back of the cart. Enjoy.")
	else:
		_update_merchant_text("poor")

# ==========================================
# DEDICATED JUKEBOX SYSTEM (playlists, playback modes, persistence)
# ==========================================

## Restores last session from CampaignManager: default ambiance, single track, or playlist.
func _restore_jukebox_session() -> void:
	var last_mode: String = CampaignManager.jukebox_last_mode
	var last_track: String = CampaignManager.jukebox_last_track_path.strip_edges()
	var last_playlist: String = CampaignManager.jukebox_last_playlist_name.strip_edges()
	if camp_music:
		camp_music.volume_db = user_music_volume
	if last_mode == JUKEBOX_MODE_LOOP_TRACK and last_track != "" and ResourceLoader.exists(last_track):
		var stream = load(last_track) as AudioStream
		if stream != null:
			is_playing_custom_track = true
			current_custom_track = stream
			camp_music.stream = stream
			camp_music.play()
			_update_now_playing_ui()
			return
	if (last_mode == JUKEBOX_MODE_LOOP_PLAYLIST or last_mode == JUKEBOX_MODE_SHUFFLE_PLAYLIST) and last_playlist != "":
		var tracks: Array = CampaignManager.saved_music_playlists.get(last_playlist, [])
		if tracks.size() > 0:
			jukebox_active_playlist_name = last_playlist
			jukebox_active_playlist_tracks.clear()
			for t in tracks:
				jukebox_active_playlist_tracks.append(str(t))
			_start_playlist_playback()
			return
	_play_random_camp_music()

## Starts or resumes playlist playback from current index; respects shuffle/loop mode.
func _start_playlist_playback() -> void:
	if jukebox_active_playlist_tracks.is_empty():
		jukebox_active_playlist_name = ""
		_update_now_playing_ui()
		return
	# Drop stale/invalid paths so broken playlist entries do not trap playback.
	var sanitized_tracks: Array[String] = []
	for track_path in jukebox_active_playlist_tracks:
		var path_str := str(track_path).strip_edges()
		if path_str != "" and ResourceLoader.exists(path_str):
			sanitized_tracks.append(path_str)
	var removed_count := jukebox_active_playlist_tracks.size() - sanitized_tracks.size()
	if sanitized_tracks.size() != jukebox_active_playlist_tracks.size():
		jukebox_active_playlist_tracks = sanitized_tracks
		if not jukebox_active_playlist_name.is_empty():
			CampaignManager.saved_music_playlists[jukebox_active_playlist_name] = sanitized_tracks.duplicate()
		jukebox_shuffled_indices.clear()
		if removed_count > 0:
			_jukebox_set_status("Archive reconciled: %d missing entries removed." % removed_count, 3.0)
	if jukebox_active_playlist_tracks.is_empty():
		jukebox_active_playlist_name = ""
		jukebox_playlist_index = 0
		jukebox_shuffled_indices.clear()
		is_playing_custom_track = false
		current_custom_track = null
		CampaignManager.jukebox_last_playlist_name = ""
		CampaignManager.jukebox_last_track_path = ""
		_play_random_camp_music()
		_update_now_playing_ui()
		return
	if jukebox_playback_mode == JUKEBOX_MODE_SHUFFLE_PLAYLIST and jukebox_shuffled_indices.is_empty():
		jukebox_shuffled_indices.resize(jukebox_active_playlist_tracks.size())
		for i in jukebox_active_playlist_tracks.size():
			jukebox_shuffled_indices[i] = i
		jukebox_shuffled_indices.shuffle()
	var idx: int = jukebox_playlist_index
	if jukebox_playback_mode == JUKEBOX_MODE_SHUFFLE_PLAYLIST and idx < jukebox_shuffled_indices.size():
		idx = jukebox_shuffled_indices[idx]
	if idx >= jukebox_active_playlist_tracks.size():
		idx = 0
		jukebox_playlist_index = 0
	var path: String = jukebox_active_playlist_tracks[idx]
	if not ResourceLoader.exists(path):
		_advance_playlist_or_stop()
		return
	var stream = load(path) as AudioStream
	if stream == null:
		_advance_playlist_or_stop()
		return
	is_playing_custom_track = true
	current_custom_track = stream
	_crossfade_music(stream, 0.65)
	_update_now_playing_ui()

## Advances to next playlist track or loops; stops if playlist empty.
func _advance_playlist_or_stop() -> void:
	if jukebox_active_playlist_name.is_empty() or jukebox_active_playlist_tracks.is_empty():
		_update_now_playing_ui()
		return
	jukebox_playlist_index += 1
	if jukebox_playlist_index >= jukebox_active_playlist_tracks.size():
		jukebox_playlist_index = 0
		if jukebox_playback_mode != JUKEBOX_MODE_LOOP_PLAYLIST and jukebox_playback_mode != JUKEBOX_MODE_SHUFFLE_PLAYLIST:
			jukebox_active_playlist_name = ""
			jukebox_active_playlist_tracks.clear()
			jukebox_playlist_index = 0
			jukebox_shuffled_indices.clear()
			is_playing_custom_track = false
			current_custom_track = null
			camp_music.stop()
			_play_random_camp_music()
			_update_now_playing_ui()
			return
	_jukebox_set_status("Deck advanced to Track %d/%d." % [jukebox_playlist_index + 1, jukebox_active_playlist_tracks.size()], 2.0)
	_start_playlist_playback()

## Returns playlist names sorted A–Z for deterministic UI.
func _jukebox_sorted_playlist_names() -> Array[String]:
	var names: Array[String] = []
	for k in CampaignManager.saved_music_playlists.keys():
		names.append(str(k))
	names.sort()
	return names

func _open_jukebox() -> void:
	if jukebox_panel == null:
		return
	if select_sound:
		select_sound.play()
	_ensure_camp_jukebox_modal()
	_layout_camp_jukebox_panel()
	if not _jukebox_playlist_ui_created:
		_create_jukebox_playlist_ui()
	_jukebox_migrate_library_to_runtime_list()
	if _jukebox_tracks_vbox == null:
		return
	if _jukebox_favorites_only_cb != null:
		_jukebox_favorites_only_cb.set_pressed_no_signal(CampaignManager.jukebox_favorites_only)
	var row_entries: Array[Dictionary] = []
	row_entries.append({"text": "DEFAULT CAMP AMBIANCE", "meta": "DEFAULT"})
	for playlist_name in _jukebox_sorted_playlist_names():
		row_entries.append({"text": "[PLAYLIST] " + playlist_name, "meta": "PLAYLIST|" + playlist_name})
	var jukebox_entries: Array[Dictionary] = []
	for saved_track in CampaignManager.unlocked_music_paths:
		var parts := str(saved_track).split("|")
		if parts.size() != 2:
			continue
		var track_name := parts[0]
		var track_path := parts[1]
		if _jukebox_favorites_only_cb != null and _jukebox_favorites_only_cb.button_pressed and track_path not in CampaignManager.favorite_music_paths:
			continue
		jukebox_entries.append({"name": track_name, "path": track_path})
	if _jukebox_track_sort_mode == JUKEBOX_SORT_ALPHA:
		jukebox_entries.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0)
	for entry in jukebox_entries:
		var entry_path := str(entry.get("path", ""))
		var entry_name := str(entry.get("name", ""))
		var entry_prefix := "[FAVORITE] " if entry_path in CampaignManager.favorite_music_paths else ""
		row_entries.append({"text": entry_prefix + entry_name, "meta": entry_path})
	if _camp_jukebox_library_badge != null:
		var library_suffix := "FAVORITES %d" % jukebox_entries.size() if (_jukebox_favorites_only_cb != null and _jukebox_favorites_only_cb.button_pressed) else "%d UNLOCKED" % jukebox_entries.size()
		_camp_jukebox_library_badge.text = "TRACK LIBRARY // " + library_suffix
	_jukebox_rebuild_runtime_rows(row_entries)
	_refresh_jukebox_playlist_option()
	if _jukebox_runtime_rows.size() > 0:
		var restored_index := clampi(CampaignManager.jukebox_last_selected_list_item, 0, _jukebox_runtime_rows.size() - 1)
		for j in range(_jukebox_runtime_rows.size()):
			var rb: Button = _jukebox_runtime_rows[j]
			if rb.toggle_mode:
				rb.set_pressed_no_signal(j == restored_index)
	_update_now_playing_ui()
	if _camp_jukebox_dimmer != null:
		_camp_jukebox_dimmer.visible = true
		move_child(_camp_jukebox_dimmer, max(0, get_child_count() - 2))
	jukebox_panel.visible = true
	move_child(jukebox_panel, get_child_count() - 1)

func _jukebox_clear_row_container(row: Container) -> void:
	if row == null:
		return
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()

func _rebuild_jukebox_playlist_ui() -> void:
	if _camp_jukebox_mode_row == null or _camp_jukebox_playlist_row == null or _camp_jukebox_playlist_tools_row == null or _camp_jukebox_manage_row == null or _camp_jukebox_filter_row == null or _camp_jukebox_filter_tools_row == null:
		return
	var legacy_controls: Array[Control] = [
		_jukebox_mode_option,
		_jukebox_playlist_option,
		_jukebox_add_to_playlist_btn,
		_jukebox_remove_from_playlist_btn,
		_jukebox_new_playlist_btn,
		_jukebox_rename_playlist_btn,
		_jukebox_delete_playlist_btn,
		_jukebox_move_up_btn,
		_jukebox_move_down_btn,
		_jukebox_favorite_btn,
		_jukebox_favorites_only_cb,
		_jukebox_track_sort_option,
		_jukebox_duplicate_playlist_btn,
		_jukebox_add_favorites_btn,
		_jukebox_add_source_btn
	]
	for control in legacy_controls:
		if control != null and is_instance_valid(control) and control.get_parent() != null:
			control.get_parent().remove_child(control)
			control.queue_free()
	_jukebox_clear_row_container(_camp_jukebox_mode_row)
	_jukebox_clear_row_container(_camp_jukebox_playlist_row)
	_jukebox_clear_row_container(_camp_jukebox_playlist_tools_row)
	_jukebox_clear_row_container(_camp_jukebox_manage_row)
	_jukebox_clear_row_container(_camp_jukebox_filter_row)
	_jukebox_clear_row_container(_camp_jukebox_filter_tools_row)
	_jukebox_mode_option = null
	_jukebox_playlist_option = null
	_jukebox_add_to_playlist_btn = null
	_jukebox_remove_from_playlist_btn = null
	_jukebox_new_playlist_btn = null
	_jukebox_rename_playlist_btn = null
	_jukebox_delete_playlist_btn = null
	_jukebox_move_up_btn = null
	_jukebox_move_down_btn = null
	_jukebox_favorite_btn = null
	_jukebox_favorites_only_cb = null
	_jukebox_track_sort_option = null
	_jukebox_duplicate_playlist_btn = null
	_jukebox_add_favorites_btn = null
	_jukebox_add_source_btn = null
	_jukebox_playlist_ui_created = false
	_create_jukebox_playlist_ui()

func _create_jukebox_playlist_ui() -> void:
	if jukebox_panel == null or _jukebox_playlist_ui_created:
		return
	if _camp_jukebox_mode_row == null or _camp_jukebox_playlist_row == null or _camp_jukebox_playlist_tools_row == null or _camp_jukebox_manage_row == null or _camp_jukebox_filter_row == null or _camp_jukebox_filter_tools_row == null:
		return
	var mode_text_label := Label.new()
	mode_text_label.text = "PLAYBACK MODE"
	_camp_style_label(mode_text_label, CAMP_MUTED, 15, 1)
	_camp_jukebox_mode_row.add_child(mode_text_label)
	_jukebox_mode_option = OptionButton.new()
	_jukebox_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jukebox_mode_option.add_item("Default", 0)
	_jukebox_mode_option.add_item("Loop track", 1)
	_jukebox_mode_option.add_item("Loop playlist", 2)
	_jukebox_mode_option.add_item("Shuffle playlist", 3)
	_jukebox_mode_option.item_selected.connect(_on_jukebox_mode_selected)
	_camp_style_option_button(_jukebox_mode_option, 15, 38.0)
	_camp_jukebox_mode_row.add_child(_jukebox_mode_option)

	var playlist_text_label := Label.new()
	playlist_text_label.text = "ACTIVE PLAYLIST"
	_camp_style_label(playlist_text_label, CAMP_MUTED, 15, 1)
	_camp_jukebox_playlist_row.add_child(playlist_text_label)
	_jukebox_playlist_option = OptionButton.new()
	_jukebox_playlist_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jukebox_playlist_option.item_selected.connect(_on_jukebox_playlist_option_selected)
	_camp_style_option_button(_jukebox_playlist_option, 15, 38.0)
	_camp_jukebox_playlist_row.add_child(_jukebox_playlist_option)
	playlist_text_label.custom_minimum_size = Vector2(128.0, 0.0)
	_jukebox_new_playlist_btn = Button.new()
	_jukebox_new_playlist_btn.text = "New Playlist"
	_jukebox_new_playlist_btn.pressed.connect(_on_jukebox_new_playlist_pressed)
	_camp_style_button(_jukebox_new_playlist_btn, false, 15, 38.0)
	_jukebox_new_playlist_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_jukebox_playlist_tools_row.add_child(_jukebox_new_playlist_btn)
	_jukebox_rename_playlist_btn = Button.new()
	_jukebox_rename_playlist_btn.text = "Rename"
	_jukebox_rename_playlist_btn.pressed.connect(_on_jukebox_rename_playlist_pressed)
	_camp_style_button(_jukebox_rename_playlist_btn, false, 15, 38.0)
	_jukebox_rename_playlist_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_jukebox_playlist_tools_row.add_child(_jukebox_rename_playlist_btn)
	_jukebox_delete_playlist_btn = Button.new()
	_jukebox_delete_playlist_btn.text = "Delete"
	_jukebox_delete_playlist_btn.pressed.connect(_on_jukebox_delete_playlist_pressed)
	_camp_style_button(_jukebox_delete_playlist_btn, false, 15, 38.0)
	_jukebox_delete_playlist_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_jukebox_playlist_tools_row.add_child(_jukebox_delete_playlist_btn)
	_jukebox_duplicate_playlist_btn = Button.new()
	_jukebox_duplicate_playlist_btn.text = "Duplicate"
	_jukebox_duplicate_playlist_btn.pressed.connect(_on_jukebox_duplicate_playlist_pressed)
	_camp_style_button(_jukebox_duplicate_playlist_btn, false, 15, 38.0)
	_jukebox_duplicate_playlist_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_jukebox_playlist_tools_row.add_child(_jukebox_duplicate_playlist_btn)

	_jukebox_add_to_playlist_btn = Button.new()
	_jukebox_add_to_playlist_btn.text = "Add Selected Track"
	_jukebox_add_to_playlist_btn.pressed.connect(_on_jukebox_add_to_playlist_pressed)
	_camp_style_button(_jukebox_add_to_playlist_btn, false, 15, 38.0)
	_jukebox_add_to_playlist_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_jukebox_manage_row.add_child(_jukebox_add_to_playlist_btn)
	_jukebox_remove_from_playlist_btn = Button.new()
	_jukebox_remove_from_playlist_btn.text = "Remove from Playlist"
	_jukebox_remove_from_playlist_btn.pressed.connect(_on_jukebox_remove_from_playlist_pressed)
	_camp_style_button(_jukebox_remove_from_playlist_btn, false, 15, 38.0)
	_jukebox_remove_from_playlist_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_jukebox_manage_row.add_child(_jukebox_remove_from_playlist_btn)
	_jukebox_move_up_btn = Button.new()
	_jukebox_move_up_btn.text = "Move Up"
	_jukebox_move_up_btn.pressed.connect(_on_jukebox_move_up_pressed)
	_camp_style_button(_jukebox_move_up_btn, false, 15, 38.0)
	_jukebox_move_up_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_jukebox_manage_row.add_child(_jukebox_move_up_btn)
	_jukebox_move_down_btn = Button.new()
	_jukebox_move_down_btn.text = "Move Down"
	_jukebox_move_down_btn.pressed.connect(_on_jukebox_move_down_pressed)
	_camp_style_button(_jukebox_move_down_btn, false, 15, 38.0)
	_jukebox_move_down_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_jukebox_manage_row.add_child(_jukebox_move_down_btn)

	_jukebox_favorite_btn = Button.new()
	_jukebox_favorite_btn.text = "Mark Favorite"
	_jukebox_favorite_btn.pressed.connect(_on_jukebox_favorite_pressed)
	_camp_style_button(_jukebox_favorite_btn, false, 15, 38.0)
	_jukebox_favorite_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_jukebox_filter_row.add_child(_jukebox_favorite_btn)
	_jukebox_favorites_only_cb = CheckButton.new()
	_jukebox_favorites_only_cb.text = "Favorites Only"
	_jukebox_favorites_only_cb.toggled.connect(_on_jukebox_favorites_only_toggled)
	_camp_style_check_button(_jukebox_favorites_only_cb, 15)
	_jukebox_favorites_only_cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_jukebox_filter_row.add_child(_jukebox_favorites_only_cb)
	_jukebox_add_favorites_btn = Button.new()
	_jukebox_add_favorites_btn.text = "Add All Favorites"
	_jukebox_add_favorites_btn.pressed.connect(_on_jukebox_add_all_favorites_pressed)
	_camp_style_button(_jukebox_add_favorites_btn, false, 15, 38.0)
	_jukebox_add_favorites_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_jukebox_filter_tools_row.add_child(_jukebox_add_favorites_btn)
	_jukebox_add_source_btn = Button.new()
	_jukebox_add_source_btn.text = "Add All Same Source"
	_jukebox_add_source_btn.pressed.connect(_on_jukebox_add_all_source_pressed)
	_camp_style_button(_jukebox_add_source_btn, false, 15, 38.0)
	_jukebox_add_source_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_jukebox_filter_tools_row.add_child(_jukebox_add_source_btn)
	var sort_text_label := Label.new()
	sort_text_label.text = "TRACK SORT"
	_camp_style_label(sort_text_label, CAMP_MUTED, 15, 1)
	sort_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_jukebox_filter_tools_row.add_child(sort_text_label)
	_jukebox_track_sort_option = OptionButton.new()
	_jukebox_track_sort_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jukebox_track_sort_option.add_item("Unlock Order", 0)
	_jukebox_track_sort_option.add_item("A-Z", 1)
	_jukebox_track_sort_option.item_selected.connect(_on_jukebox_track_sort_selected)
	_camp_style_option_button(_jukebox_track_sort_option, 15, 38.0)
	_camp_jukebox_filter_tools_row.add_child(_jukebox_track_sort_option)

	if _jukebox_playlist_popup == null or not is_instance_valid(_jukebox_playlist_popup):
		_jukebox_playlist_popup = PopupMenu.new()
		_jukebox_playlist_popup.id_pressed.connect(_on_jukebox_add_to_playlist_id_pressed)
		jukebox_panel.add_child(_jukebox_playlist_popup)

	_jukebox_playlist_ui_created = true
	_sync_jukebox_mode_option()
	_sync_jukebox_sort_option()

func _refresh_jukebox_playlist_option() -> void:
	if _jukebox_playlist_option == null: return
	var previous_playlist_name := ""
	var previous_index := _jukebox_playlist_option.selected
	if previous_index >= 0:
		var previous_id := _jukebox_playlist_option.get_item_id(previous_index)
		if previous_id >= 0 and previous_id < _jukebox_playlist_names_ordered.size():
			previous_playlist_name = _jukebox_playlist_names_ordered[previous_id]
	if previous_playlist_name.is_empty():
		previous_playlist_name = jukebox_active_playlist_name
	_jukebox_playlist_option.clear()
	_jukebox_playlist_names_ordered.clear()
	_jukebox_playlist_option.add_item("(None)", -1)
	var selected_option_index := 0
	for pl_name in _jukebox_sorted_playlist_names():
		_jukebox_playlist_names_ordered.append(pl_name)
		_jukebox_playlist_option.add_item(pl_name, _jukebox_playlist_names_ordered.size() - 1)
		if pl_name == previous_playlist_name:
			selected_option_index = _jukebox_playlist_option.item_count - 1
	_jukebox_playlist_option.select(selected_option_index)

func _sync_jukebox_mode_option() -> void:
	if _jukebox_mode_option == null: return
	match jukebox_playback_mode:
		JUKEBOX_MODE_DEFAULT: _jukebox_mode_option.select(0)
		JUKEBOX_MODE_LOOP_TRACK: _jukebox_mode_option.select(1)
		JUKEBOX_MODE_LOOP_PLAYLIST: _jukebox_mode_option.select(2)
		JUKEBOX_MODE_SHUFFLE_PLAYLIST: _jukebox_mode_option.select(3)
		_: _jukebox_mode_option.select(0)

func _sync_jukebox_sort_option() -> void:
	if _jukebox_track_sort_option == null: return
	_jukebox_track_sort_option.select(1 if _jukebox_track_sort_mode == JUKEBOX_SORT_ALPHA else 0)

## Shows a brief message on the now-playing label, then restores normal text.
func _jukebox_show_feedback(msg: String) -> void:
	if jukebox_now_playing == null: return
	var _prev_text: String = jukebox_now_playing.text
	jukebox_now_playing.text = "[center][color=gray]" + msg + "[/color][/center]"
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(jukebox_now_playing):
		_update_now_playing_ui()

func _on_jukebox_mode_selected(idx: int) -> void:
	match idx:
		0: jukebox_playback_mode = JUKEBOX_MODE_DEFAULT
		1: jukebox_playback_mode = JUKEBOX_MODE_LOOP_TRACK
		2: jukebox_playback_mode = JUKEBOX_MODE_LOOP_PLAYLIST
		3: jukebox_playback_mode = JUKEBOX_MODE_SHUFFLE_PLAYLIST
		_: jukebox_playback_mode = JUKEBOX_MODE_DEFAULT
	CampaignManager.jukebox_last_mode = jukebox_playback_mode

func _on_jukebox_playlist_option_selected(_idx: int) -> void:
	if _jukebox_playlist_option == null:
		return
	var selected_index := _jukebox_playlist_option.selected
	var selected_id := _jukebox_playlist_option.get_item_id(selected_index)
	if selected_id < 0 or selected_id >= _jukebox_playlist_names_ordered.size():
		if jukebox_playback_mode == JUKEBOX_MODE_LOOP_PLAYLIST or jukebox_playback_mode == JUKEBOX_MODE_SHUFFLE_PLAYLIST:
			jukebox_active_playlist_name = ""
			jukebox_active_playlist_tracks.clear()
			jukebox_playlist_index = 0
			jukebox_shuffled_indices.clear()
			CampaignManager.jukebox_last_playlist_name = ""
			_update_now_playing_ui()
		return
	var playlist_name := _jukebox_playlist_names_ordered[selected_id]
	if jukebox_playback_mode == JUKEBOX_MODE_LOOP_PLAYLIST or jukebox_playback_mode == JUKEBOX_MODE_SHUFFLE_PLAYLIST:
		var tracks: Array = CampaignManager.saved_music_playlists.get(playlist_name, [])
		jukebox_active_playlist_name = playlist_name
		jukebox_active_playlist_tracks.clear()
		for track in tracks:
			jukebox_active_playlist_tracks.append(str(track))
		jukebox_playlist_index = 0
		jukebox_shuffled_indices.clear()
		CampaignManager.jukebox_last_playlist_name = playlist_name
		if jukebox_active_playlist_tracks.is_empty():
			_update_now_playing_ui()
		else:
			_start_playlist_playback()
			_update_now_playing_ui()
	else:
		_jukebox_show_feedback("Playlist target: " + playlist_name)

func _on_jukebox_new_playlist_pressed() -> void:
	var dialog = AcceptDialog.new()
	var line_edit = LineEdit.new()
	line_edit.placeholder_text = "Playlist name"
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v = VBoxContainer.new()
	v.add_child(line_edit)
	dialog.add_child(v)
	dialog.dialog_text = "New playlist"
	dialog.confirmed.connect(func():
		var name_str = line_edit.text.strip_edges()
		if name_str.is_empty(): return
		if CampaignManager.saved_music_playlists.has(name_str):
			return
		CampaignManager.saved_music_playlists[name_str] = []
		_refresh_jukebox_playlist_option()
		_open_jukebox()
	)
	add_child(dialog)
	dialog.popup_centered()
	line_edit.grab_focus()

func _on_jukebox_rename_playlist_pressed() -> void:
	if _jukebox_playlist_option == null: return
	var sel_idx: int = _jukebox_playlist_option.selected
	var sel_id: int = _jukebox_playlist_option.get_item_id(sel_idx)
	if sel_id < 0 or sel_id >= _jukebox_playlist_names_ordered.size(): return
	var old_name: String = _jukebox_playlist_names_ordered[sel_id]
	var dialog = AcceptDialog.new()
	var line_edit = LineEdit.new()
	line_edit.placeholder_text = old_name
	line_edit.text = old_name
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v = VBoxContainer.new()
	v.add_child(line_edit)
	dialog.add_child(v)
	dialog.dialog_text = "Rename playlist"
	dialog.confirmed.connect(func():
		var new_name = line_edit.text.strip_edges()
		if new_name.is_empty() or new_name == old_name: return
		if CampaignManager.saved_music_playlists.has(new_name): return
		var tracks = CampaignManager.saved_music_playlists[old_name]
		CampaignManager.saved_music_playlists.erase(old_name)
		CampaignManager.saved_music_playlists[new_name] = tracks
		if jukebox_active_playlist_name == old_name:
			jukebox_active_playlist_name = new_name
		_refresh_jukebox_playlist_option()
		_open_jukebox()
	)
	add_child(dialog)
	dialog.popup_centered()
	line_edit.grab_focus()

func _on_jukebox_delete_playlist_pressed() -> void:
	if _jukebox_playlist_option == null: return
	var sel_idx: int = _jukebox_playlist_option.selected
	var sel_id: int = _jukebox_playlist_option.get_item_id(sel_idx)
	if sel_id < 0 or sel_id >= _jukebox_playlist_names_ordered.size(): return
	var pl_name: String = _jukebox_playlist_names_ordered[sel_id]
	CampaignManager.saved_music_playlists.erase(pl_name)
	if jukebox_active_playlist_name == pl_name:
		jukebox_active_playlist_name = ""
		jukebox_active_playlist_tracks.clear()
		jukebox_playlist_index = 0
		jukebox_shuffled_indices.clear()
		is_playing_custom_track = false
		current_custom_track = null
		camp_music.stop()
		_play_random_camp_music()
	_refresh_jukebox_playlist_option()
	_update_now_playing_ui()
	_open_jukebox()

func _on_jukebox_duplicate_playlist_pressed() -> void:
	if _jukebox_playlist_option == null: return
	var sel_idx: int = _jukebox_playlist_option.selected
	var sel_id: int = _jukebox_playlist_option.get_item_id(sel_idx)
	if sel_id < 0 or sel_id >= _jukebox_playlist_names_ordered.size(): return
	var source_name: String = _jukebox_playlist_names_ordered[sel_id]
	var target_name := source_name + " Copy"
	var counter := 2
	while CampaignManager.saved_music_playlists.has(target_name):
		target_name = "%s Copy %d" % [source_name, counter]
		counter += 1
	var source_tracks: Array = CampaignManager.saved_music_playlists.get(source_name, [])
	CampaignManager.saved_music_playlists[target_name] = source_tracks.duplicate()
	_refresh_jukebox_playlist_option()
	_jukebox_set_status("Duplicated playlist: " + target_name, 2.4)
	_open_jukebox()

func _on_jukebox_add_to_playlist_pressed() -> void:
	var selected_paths := _jukebox_selected_track_paths()
	if selected_paths.is_empty(): return
	_jukebox_playlist_popup.clear()
	for i in _jukebox_playlist_names_ordered.size():
		_jukebox_playlist_popup.add_item(_jukebox_playlist_names_ordered[i], i)
	if _jukebox_playlist_popup.item_count == 0: return
	_jukebox_playlist_popup.set_meta("add_track_paths", selected_paths)
	_jukebox_playlist_popup.popup(Rect2i(jukebox_panel.global_position + Vector2(20, 130), Vector2(180, 120)))

func _on_jukebox_remove_from_playlist_pressed() -> void:
	if _jukebox_playlist_option == null: return
	var sel_idx: int = _jukebox_playlist_option.selected
	var sel_id: int = _jukebox_playlist_option.get_item_id(sel_idx)
	if sel_id < 0 or sel_id >= _jukebox_playlist_names_ordered.size(): return
	var pl_name: String = _jukebox_playlist_names_ordered[sel_id]
	var selected_paths := _jukebox_selected_track_paths()
	if selected_paths.is_empty(): return
	var arr: Array = CampaignManager.saved_music_playlists.get(pl_name, [])
	for path_str in selected_paths:
		arr.erase(path_str)
	CampaignManager.saved_music_playlists[pl_name] = arr
	if jukebox_active_playlist_name == pl_name:
		jukebox_active_playlist_tracks.clear()
		for a in arr:
			jukebox_active_playlist_tracks.append(str(a))
		if jukebox_playlist_index >= jukebox_active_playlist_tracks.size():
			jukebox_playlist_index = max(0, jukebox_active_playlist_tracks.size() - 1)
	_jukebox_set_status("Removed %d track(s) from %s." % [selected_paths.size(), pl_name], 2.2)
	_open_jukebox()

## Move selected track up in the selected playlist; syncs active playlist and playing index if needed.
func _on_jukebox_move_up_pressed() -> void:
	_jukebox_move_track_in_playlist(-1)

## Move selected track down in the selected playlist; syncs active playlist and playing index if needed.
func _on_jukebox_move_down_pressed() -> void:
	_jukebox_move_track_in_playlist(1)

func _jukebox_move_track_in_playlist(direction: int) -> void:
	if _jukebox_playlist_option == null: return
	var sel_idx: int = _jukebox_playlist_option.selected
	var sel_id: int = _jukebox_playlist_option.get_item_id(sel_idx)
	if sel_id < 0 or sel_id >= _jukebox_playlist_names_ordered.size(): return
	var pl_name: String = _jukebox_playlist_names_ordered[sel_id]
	var path_str := _jukebox_first_selected_track_meta()
	if path_str.is_empty():
		return
	var arr: Array = CampaignManager.saved_music_playlists.get(pl_name, [])
	var i: int = arr.find(path_str)
	if i < 0: return
	var new_i: int = i + direction
	if new_i < 0 or new_i >= arr.size(): return
	var tmp = arr[i]
	arr[i] = arr[new_i]
	arr[new_i] = tmp
	CampaignManager.saved_music_playlists[pl_name] = arr
	if jukebox_active_playlist_name == pl_name:
		jukebox_active_playlist_tracks.clear()
		for a in arr:
			jukebox_active_playlist_tracks.append(str(a))
		if jukebox_playlist_index == i:
			jukebox_playlist_index = new_i
		elif jukebox_playlist_index == new_i:
			jukebox_playlist_index = i
	_open_jukebox()

func _on_jukebox_favorite_pressed() -> void:
	var path_str := _jukebox_first_selected_track_meta()
	if path_str.is_empty():
		return
	if path_str in CampaignManager.favorite_music_paths:
		CampaignManager.favorite_music_paths.erase(path_str)
	else:
		CampaignManager.favorite_music_paths.append(path_str)
	_open_jukebox()

func _on_jukebox_track_sort_selected(idx: int) -> void:
	_jukebox_track_sort_mode = JUKEBOX_SORT_ALPHA if idx == 1 else JUKEBOX_SORT_UNLOCK
	CampaignManager.jukebox_sort_mode = _jukebox_track_sort_mode
	_open_jukebox()

func _on_jukebox_favorites_only_toggled(enabled: bool) -> void:
	CampaignManager.jukebox_favorites_only = enabled
	_open_jukebox()

func _on_jukebox_add_to_playlist_id_pressed(id: int) -> void:
	var selected_paths_variant: Variant = _jukebox_playlist_popup.get_meta("add_track_paths", [])
	var selected_paths: Array[String] = []
	if selected_paths_variant is Array:
		for v in selected_paths_variant:
			var s := str(v)
			if s != "":
				selected_paths.append(s)
	if selected_paths.is_empty():
		return
	if id < 0 or id >= _jukebox_playlist_names_ordered.size(): return
	var pl_name: String = _jukebox_playlist_names_ordered[id]
	var arr: Array = CampaignManager.saved_music_playlists.get(pl_name, [])
	var added_count := 0
	for path_str in selected_paths:
		if path_str in arr:
			continue
		arr.append(path_str)
		added_count += 1
	CampaignManager.saved_music_playlists[pl_name] = arr
	if jukebox_active_playlist_name == pl_name:
		jukebox_active_playlist_tracks.clear()
		for a in arr:
			jukebox_active_playlist_tracks.append(str(a))
		if jukebox_playlist_index >= jukebox_active_playlist_tracks.size():
			jukebox_playlist_index = max(0, jukebox_active_playlist_tracks.size() - 1)
	if added_count == 0:
		_jukebox_set_status("Selected tracks were already in %s." % pl_name, 2.0)
	else:
		_jukebox_set_status("Added %d track(s) to %s." % [added_count, pl_name], 2.2)
	_open_jukebox()

func _on_jukebox_add_all_favorites_pressed() -> void:
	if _jukebox_playlist_option == null: return
	var sel_idx: int = _jukebox_playlist_option.selected
	var sel_id: int = _jukebox_playlist_option.get_item_id(sel_idx)
	if sel_id < 0 or sel_id >= _jukebox_playlist_names_ordered.size():
		_jukebox_set_status("Choose a playlist first.", 2.0)
		return
	var pl_name: String = _jukebox_playlist_names_ordered[sel_id]
	var arr: Array = CampaignManager.saved_music_playlists.get(pl_name, [])
	var added_count := 0
	for path_str in CampaignManager.favorite_music_paths:
		if not ResourceLoader.exists(path_str):
			continue
		if path_str in arr:
			continue
		arr.append(path_str)
		added_count += 1
	CampaignManager.saved_music_playlists[pl_name] = arr
	_jukebox_set_status("Added %d favorite track(s) to %s." % [added_count, pl_name], 2.4)
	_open_jukebox()

func _on_jukebox_add_all_source_pressed() -> void:
	if _jukebox_playlist_option == null: return
	var sel_idx: int = _jukebox_playlist_option.selected
	var sel_id: int = _jukebox_playlist_option.get_item_id(sel_idx)
	if sel_id < 0 or sel_id >= _jukebox_playlist_names_ordered.size():
		_jukebox_set_status("Choose a playlist first.", 2.0)
		return
	var selected_meta := _jukebox_first_selected_track_meta()
	if selected_meta.is_empty():
		_jukebox_set_status("Select a track to infer source.", 2.0)
		return
	if selected_meta == "DEFAULT" or selected_meta.begins_with("PLAYLIST|"):
		_jukebox_set_status("Select a real track first.", 2.0)
		return
	var selected_name := _get_display_name_for_path(selected_meta)
	var source_key := _jukebox_infer_source(selected_name, selected_meta)
	var pl_name: String = _jukebox_playlist_names_ordered[sel_id]
	var arr: Array = CampaignManager.saved_music_playlists.get(pl_name, [])
	var added_count := 0
	for raw_track in CampaignManager.unlocked_music_paths:
		var parts := str(raw_track).split("|")
		if parts.size() != 2:
			continue
		var name_part := str(parts[0])
		var path_part := str(parts[1])
		if not ResourceLoader.exists(path_part):
			continue
		if _jukebox_infer_source(name_part, path_part) != source_key:
			continue
		if path_part in arr:
			continue
		arr.append(path_part)
		added_count += 1
	CampaignManager.saved_music_playlists[pl_name] = arr
	_jukebox_set_status("Added %d '%s' track(s) to %s." % [added_count, source_key, pl_name], 2.6)
	_open_jukebox()

func _on_jukebox_track_selected(index: int) -> void:
	if select_sound: select_sound.play()
	CampaignManager.jukebox_last_selected_list_item = maxi(0, index)
	if index < 0 or index >= _jukebox_runtime_rows.size():
		return
	var row_btn: Button = _jukebox_runtime_rows[index]
	var meta_str: String = str(row_btn.get_meta("jb_meta", ""))
	var track_name: String = row_btn.text
	var clean_track_name: String = track_name.replace("[FAVORITE] ", "").replace("[PLAYLIST] ", "")
	if _jukebox_favorite_btn != null:
		if meta_str != "DEFAULT" and not meta_str.begins_with("PLAYLIST|"):
			_jukebox_favorite_btn.text = "Unfavorite" if meta_str in CampaignManager.favorite_music_paths else "Mark Favorite"
		else:
			_jukebox_favorite_btn.text = "Mark Favorite"
	if meta_str == "DEFAULT":
		is_playing_custom_track = false
		current_custom_track = null
		jukebox_active_playlist_name = ""
		jukebox_active_playlist_tracks.clear()
		jukebox_playlist_index = 0
		jukebox_shuffled_indices.clear()
		_play_random_camp_music()
		CampaignManager.jukebox_last_mode = JUKEBOX_MODE_DEFAULT
		CampaignManager.jukebox_last_track_path = ""
		CampaignManager.jukebox_last_playlist_name = ""
		if _jukebox_chip_source != null:
			_jukebox_chip_source.text = "Source: Camp"
		if _jukebox_chip_mood != null:
			_jukebox_chip_mood.text = "Mood: Ambient"
		if _jukebox_chip_length != null:
			_jukebox_chip_length.text = "Length: Live"
		if _jukebox_chip_favorite != null:
			_jukebox_chip_favorite.text = "Favorite: N/A"
		_update_now_playing_ui()
		return
	if meta_str.begins_with("PLAYLIST|"):
		var pl_name = meta_str.substr(9)
		var tracks: Array = CampaignManager.saved_music_playlists.get(pl_name, [])
		jukebox_active_playlist_name = pl_name
		jukebox_active_playlist_tracks.clear()
		for t in tracks:
			jukebox_active_playlist_tracks.append(str(t))
		jukebox_playlist_index = 0
		jukebox_shuffled_indices.clear()
		CampaignManager.jukebox_last_track_path = ""
		CampaignManager.jukebox_last_playlist_name = pl_name
		_start_playlist_playback()
		_update_now_playing_ui()
		return
	var path = meta_str
	if ResourceLoader.exists(path):
		var stream = load(path) as AudioStream
		if stream != null:
			is_playing_custom_track = true
			current_custom_track = stream
			jukebox_active_playlist_name = ""
			jukebox_active_playlist_tracks.clear()
			jukebox_playlist_index = 0
			jukebox_shuffled_indices.clear()
			CampaignManager.jukebox_last_track_path = path
			CampaignManager.jukebox_last_playlist_name = ""
			_crossfade_music(stream)
		_refresh_jukebox_meta_chips(path, clean_track_name)
		_update_now_playing_ui(clean_track_name)

func _get_display_name_for_path(path: String) -> String:
	for saved_str in CampaignManager.unlocked_music_paths:
		var parts = saved_str.split("|")
		if parts.size() == 2 and parts[1] == path:
			return parts[0]
	return path.get_file().get_basename()

func _refresh_jukebox_meta_chips(path: String, display_name: String = "") -> void:
	var shown_name := display_name if display_name != "" else _get_display_name_for_path(path)
	var source_text := _jukebox_infer_source(shown_name, path)
	var mood_text := _jukebox_infer_mood(shown_name)
	var length_text := _jukebox_estimated_length_label(shown_name)
	var favorite_text := "Yes" if path in CampaignManager.favorite_music_paths else "No"
	if _jukebox_chip_source != null:
		_jukebox_chip_source.text = "Source: " + source_text
	if _jukebox_chip_mood != null:
		_jukebox_chip_mood.text = "Mood: " + mood_text
	if _jukebox_chip_length != null:
		_jukebox_chip_length.text = "Length: " + length_text
	if _jukebox_chip_favorite != null:
		_jukebox_chip_favorite.text = "Favorite: " + favorite_text

func _refresh_jukebox_up_next() -> void:
	if _jukebox_up_next_label == null:
		return
	if jukebox_active_playlist_name.is_empty() or jukebox_active_playlist_tracks.is_empty():
		_jukebox_up_next_label.text = "[color=#b6ad9b]UP NEXT\nNo queued playlist tracks.[/color]"
		return
	var lines: Array[String] = []
	var count: int = mini(5, jukebox_active_playlist_tracks.size())
	for step in range(count):
		var virtual_index := (jukebox_playlist_index + step) % jukebox_active_playlist_tracks.size()
		var actual_index := virtual_index
		if jukebox_playback_mode == JUKEBOX_MODE_SHUFFLE_PLAYLIST and virtual_index < jukebox_shuffled_indices.size():
			actual_index = jukebox_shuffled_indices[virtual_index]
		var path := str(jukebox_active_playlist_tracks[actual_index])
		var marker := "Now" if step == 0 else str(step)
		lines.append("[color=#e8dbc0]%s.[/color] %s" % [marker, _get_display_name_for_path(path)])
	_jukebox_up_next_label.text = "[color=#8ccbe6]UP NEXT // %s[/color]\n%s" % [jukebox_active_playlist_name, "\n".join(lines)]

func _update_now_playing_ui(override_name: String = "") -> void:
	if jukebox_now_playing == null:
		return
	var mode_str: String = ""
	match jukebox_playback_mode:
		JUKEBOX_MODE_DEFAULT:
			mode_str = "Default"
		JUKEBOX_MODE_LOOP_TRACK:
			mode_str = "Loop Track"
		JUKEBOX_MODE_LOOP_PLAYLIST:
			mode_str = "Loop Playlist"
		JUKEBOX_MODE_SHUFFLE_PLAYLIST:
			mode_str = "Shuffle Playlist"
		_:
			mode_str = "Default"
	var status_line := ""
	if _jukebox_status_line != "":
		status_line = "\n[color=cyan]%s[/color]" % _jukebox_status_line
	if _camp_jukebox_deck_badge != null:
		_camp_jukebox_deck_badge.text = "CONTROL DECK // " + mode_str.to_upper()
	_jukebox_refresh_lyrics_button()
	if override_name != "":
		jukebox_now_playing.text = "[center][color=#f2bf59]NOW PLAYING[/color]\n[color=#fff0c8]%s[/color]\n[color=#8ccbe6]%s[/color]%s[/center]" % [override_name, mode_str.to_upper(), status_line]
		_refresh_jukebox_up_next()
		return
	if not jukebox_active_playlist_name.is_empty() and jukebox_active_playlist_tracks.size() > 0:
		var idx: int = jukebox_playlist_index
		if jukebox_playback_mode == JUKEBOX_MODE_SHUFFLE_PLAYLIST and idx < jukebox_shuffled_indices.size():
			idx = jukebox_shuffled_indices[idx]
		if idx < jukebox_active_playlist_tracks.size():
			var cur_path: String = jukebox_active_playlist_tracks[idx]
			var name_str: String = _get_display_name_for_path(cur_path)
			var one_based: int = jukebox_playlist_index + 1
			jukebox_now_playing.text = "[center][color=#f2bf59]NOW PLAYING[/color]\n[color=#fff0c8]%s[/color]\n[color=#8ccbe6]PLAYLIST // %s (%d/%d)[/color]\n[color=#b6ad9b]%s[/color]%s[/center]" % [name_str, jukebox_active_playlist_name, one_based, jukebox_active_playlist_tracks.size(), mode_str.to_upper(), status_line]
			_refresh_jukebox_meta_chips(cur_path, name_str)
		else:
			jukebox_now_playing.text = "[center][color=#f2bf59]NOW PLAYING[/color]\n[color=#8ccbe6]PLAYLIST // %s[/color]\n[color=#b6ad9b]%s[/color]%s[/center]" % [jukebox_active_playlist_name, mode_str.to_upper(), status_line]
		_refresh_jukebox_up_next()
		return
	if is_playing_custom_track and current_custom_track != null:
		var name_str: String = "Custom Track"
		if CampaignManager.jukebox_last_track_path != "":
			name_str = _get_display_name_for_path(CampaignManager.jukebox_last_track_path)
		jukebox_now_playing.text = "[center][color=#f2bf59]NOW PLAYING[/color]\n[color=#fff0c8]%s[/color]\n[color=#b6ad9b]TRACK // %s[/color]%s[/center]" % [name_str, mode_str.to_upper(), status_line]
		if CampaignManager.jukebox_last_track_path != "":
			_refresh_jukebox_meta_chips(CampaignManager.jukebox_last_track_path, name_str)
		_refresh_jukebox_up_next()
		return
	if camp_music.playing:
		jukebox_now_playing.text = "[center][color=#f2bf59]NOW PLAYING[/color]\n[color=#9ce8b5]CAMP AMBIANCE[/color]\n[color=#b6ad9b]%s[/color]%s[/center]" % [mode_str.to_upper(), status_line]
		if _jukebox_chip_source != null:
			_jukebox_chip_source.text = "Source: Camp"
		if _jukebox_chip_mood != null:
			_jukebox_chip_mood.text = "Mood: Ambient"
		if _jukebox_chip_length != null:
			_jukebox_chip_length.text = "Length: Live"
		if _jukebox_chip_favorite != null:
			_jukebox_chip_favorite.text = "Favorite: N/A"
		_refresh_jukebox_up_next()
		return
	jukebox_now_playing.text = "[center][color=#f2bf59]NOW PLAYING[/color]\n[color=#9f9688]STOPPED[/color]\n[color=#b6ad9b]%s[/color]%s[/center]" % [mode_str.to_upper(), status_line]
	_refresh_jukebox_up_next()

func _on_jukebox_volume_changed(value: float) -> void:
	if value <= 0.001:
		user_music_volume = -80.0
	else:
		user_music_volume = linear_to_db(value)
	CampaignManager.jukebox_volume_db = user_music_volume
	if camp_music:
		camp_music.volume_db = user_music_volume

func _on_jukebox_skip_pressed() -> void:
	if select_sound: select_sound.play()
	if not jukebox_active_playlist_name.is_empty() and jukebox_active_playlist_tracks.size() > 0:
		_advance_playlist_or_stop()
		return
	is_playing_custom_track = false
	current_custom_track = null
	camp_music.stop()
	_play_random_camp_music()
	_update_now_playing_ui("Camp Ambiance")

func _on_jukebox_stop_pressed() -> void:
	if select_sound: select_sound.play()
	is_playing_custom_track = false
	current_custom_track = null
	jukebox_active_playlist_name = ""
	jukebox_active_playlist_tracks.clear()
	jukebox_playlist_index = 0
	jukebox_shuffled_indices.clear()
	CampaignManager.jukebox_last_track_path = ""
	CampaignManager.jukebox_last_playlist_name = ""
	camp_music.stop()
	_update_now_playing_ui()

func _on_camp_music_finished() -> void:
	if not jukebox_active_playlist_name.is_empty() and jukebox_active_playlist_tracks.size() > 0:
		_advance_playlist_or_stop()
		return
	if is_playing_custom_track and current_custom_track != null:
		if jukebox_playback_mode == JUKEBOX_MODE_LOOP_TRACK:
			camp_music.stream = current_custom_track
			camp_music.play()
		else:
			_play_random_camp_music()
		return
	_play_random_camp_music()

func _crossfade_music(new_stream: AudioStream, fade_seconds: float = 2.0) -> void:
	var temp_player = AudioStreamPlayer.new()
	temp_player.stream = new_stream
	temp_player.volume_db = -40.0
	add_child(temp_player)
	temp_player.play()
	var t = create_tween().set_parallel(true)
	var fade_time := clampf(fade_seconds, 0.20, 4.0)
	t.tween_property(camp_music, "volume_db", -40.0, fade_time).set_trans(Tween.TRANS_SINE)
	t.tween_property(temp_player, "volume_db", user_music_volume, fade_time).set_trans(Tween.TRANS_SINE)
	await t.finished
	camp_music.stop()
	camp_music.stream = new_stream
	camp_music.play(temp_player.get_playback_position())
	camp_music.volume_db = user_music_volume
	temp_player.queue_free()
		

# ==========================================
# SKILL TREE SYSTEM
# ==========================================
func _open_skill_tree() -> void:
	if select_sound: select_sound.play()
	skill_tree_panel.visible = true
	skill_info_panel.visible = false
	selected_skill_node = null
	
	# --- FORCE BEAUTIFUL UI STYLING ---
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.05, 0.08, 0.98) # Solid dark background!
	bg_style.set_border_width_all(4)
	bg_style.border_color = Color(0.8, 0.6, 0.2) # Gold Border
	skill_tree_panel.add_theme_stylebox_override("panel", bg_style)
	
	_build_skill_tree_ui()
	
	# --- THE FIX: AUTO-CENTER THE SCROLL VIEW ---
	# We MUST wait 1 frame, otherwise Godot's UI engine overrides our scroll position!
	await get_tree().process_frame
	
	var scroll_container = tree_canvas.get_parent()
	if scroll_container is ScrollContainer:
		# Calculate the exact center by taking the canvas size and subtracting the screen window size
		var center_x = (tree_canvas.custom_minimum_size.x - scroll_container.size.x) / 2.0
		var center_y = (tree_canvas.custom_minimum_size.y - scroll_container.size.y) / 2.0
		
		# Snap the scrollbars to the middle!
		scroll_container.scroll_horizontal = int(center_x)
		scroll_container.scroll_vertical = int(center_y)
		
func _build_skill_tree_ui() -> void:
	# 1. Clean up old nodes and lines
	for child in tree_canvas.get_children():
		child.queue_free()
		
	var unit_data = CampaignManager.player_roster[selected_roster_index]
	var class_data = unit_data.get("class_data")

	# Ensure it's a loaded Resource
	if class_data is String and ResourceLoader.exists(class_data):
		class_data = load(class_data)
		unit_data["class_data"] = class_data

	# THE REAL FIX: Use "in" instead of .get() for Custom Resources!
	if class_data == null or not ("class_skill_tree" in class_data) or class_data.class_skill_tree == null:
		skill_title_label.text = "No Skill Tree Available"
		skill_points_label.text = ""
		return
		
	var tree = class_data.class_skill_tree
	skill_title_label.text = tree.tree_name.to_upper()
	
	var pts = unit_data.get("skill_points", 0)
	skill_points_label.text = "SKILL POINTS: " + str(pts)
	var unlocked_list = unit_data.get("unlocked_skills", [])
	
	var canvas_center = tree_canvas.custom_minimum_size / 2.0
	var spacing = 150.0 # Distance between nodes
	
	# Dictionary to store exact positions so we can draw lines between them
	var node_positions = {}
	var node_resources = {}
	
	# FIRST PASS: Calculate positions and save them
	for skill in tree.skills:
		if skill == null: continue
		var pos = canvas_center + (skill.grid_position * spacing)
		node_positions[skill.skill_id] = pos
		node_resources[skill.skill_id] = skill
		
	# SECOND PASS: Draw the Lines (Behind the buttons)
	for skill in tree.skills:
		if skill == null or skill.required_skill_id == "": continue
		
		var start_pos = node_positions.get(skill.required_skill_id)
		var end_pos = node_positions.get(skill.skill_id)
		
		if start_pos != null and end_pos != null:
			var line = Line2D.new()
			line.add_point(start_pos)
			line.add_point(end_pos)
			line.width = 6.0
			
			# Color the line based on whether the DESTINATION is unlocked
			if unlocked_list.has(skill.skill_id):
				line.default_color = Color(1.0, 0.8, 0.2, 0.8) # Gold (Unlocked path)
			else:
				line.default_color = Color(0.3, 0.3, 0.3, 0.8) # Gray (Locked path)
			tree_canvas.add_child(line)

	# THIRD PASS: Spawn the Buttons
	for skill in tree.skills:
		if skill == null: continue
		
		var pos = node_positions[skill.skill_id]
		var is_unlocked = unlocked_list.has(skill.skill_id)
		var req = skill.required_skill_id
		
		var req_is_empty = true
		if req != null and str(req).strip_edges() != "" and str(req).to_lower() != "none":
			req_is_empty = false
			
		var is_available = not is_unlocked and (req_is_empty or unlocked_list.has(str(req).strip_edges()))
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.position = pos - (btn.custom_minimum_size / 2.0)
		btn.pivot_offset = btn.custom_minimum_size / 2.0
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
		style.corner_radius_top_left = 40
		style.corner_radius_top_right = 40
		style.corner_radius_bottom_left = 40
		style.corner_radius_bottom_right = 40
		style.set_border_width_all(4)
		
		if is_unlocked:
			style.border_color = Color(1.0, 0.8, 0.2) # Gold
			btn.modulate = Color.WHITE
			btn.icon = skill.icon
		elif is_available:
			style.border_color = Color(0.2, 0.8, 1.0) # Cyan (Buyable!)
			btn.modulate = Color.WHITE
			btn.icon = skill.icon
		else:
			style.border_color = Color(0.3, 0.3, 0.3) # Gray
			btn.modulate = Color(0.3, 0.3, 0.3) # Darkened out
			btn.icon = skill.icon
			
		btn.add_theme_stylebox_override("normal", style)
		btn.expand_icon = true
		btn.pressed.connect(_on_skill_node_clicked.bind(skill))
		
		# --- THE FIX: ADD IT TO THE TREE FIRST ---
		tree_canvas.add_child(btn)
		
		# --- NOW WE CAN ANIMATE IT SAFELY ---
		if is_available:
			var t = create_tween().set_loops()
			t.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.8).set_trans(Tween.TRANS_SINE)
			t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)
		
func _on_skill_node_clicked(skill: Resource) -> void:
	if select_sound: select_sound.play()
	selected_skill_node = skill
	
	var unit_data = CampaignManager.player_roster[selected_roster_index]
	var unlocked_list = unit_data.get("unlocked_skills", [])
	var pts = unit_data.get("skill_points", 0)
	
	var is_unlocked = unlocked_list.has(skill.skill_id)
	var req = skill.required_skill_id
	
	# --- THE ULTRA-BULLETPROOF FIX ---
	var req_is_empty = true
	if req != null and str(req).strip_edges() != "" and str(req).to_lower() != "none":
		req_is_empty = false
		
	var is_available = not is_unlocked and (req_is_empty or unlocked_list.has(str(req).strip_edges()))
	
	skill_name_label.text = skill.skill_name
	var desc = skill.description
	
	desc += "\n\n[color=gray]Effect:[/color] "
	if skill.effect_type == 0: # STAT_BOOST
		desc += "[color=lime]+" + str(skill.boost_amount) + " " + skill.stat_to_boost.to_upper() + "[/color]"
	else:
		desc += "[color=orange]Unlocks Ability: " + skill.ability_to_unlock + "[/color]"
		
	skill_desc_label.text = desc
	
	if is_unlocked:
		unlock_skill_btn.text = "ALREADY UNLOCKED"
		unlock_skill_btn.disabled = true
	elif not is_available:
		unlock_skill_btn.text = "LOCKED (Path Required)"
		unlock_skill_btn.disabled = true
	elif pts <= 0:
		unlock_skill_btn.text = "NOT ENOUGH POINTS"
		unlock_skill_btn.disabled = true
	else:
		unlock_skill_btn.text = "UNLOCK (Cost: 1 SP)"
		unlock_skill_btn.disabled = false
		
	skill_info_panel.visible = true
	
func _on_unlock_skill_pressed() -> void:
	if selected_skill_node == null: return
	
	var unit_data = CampaignManager.player_roster[selected_roster_index]
	var pts = unit_data.get("skill_points", 0)
	
	if pts <= 0: return # Failsafe
	
	# 1. Deduct point and save unlock
	unit_data["skill_points"] -= 1
	if not unit_data.has("unlocked_skills"): unit_data["unlocked_skills"] = []
	unit_data["unlocked_skills"].append(selected_skill_node.skill_id)
	
	# 2. APPLY THE EFFECTS DIRECTLY TO THE SAVE DICTIONARY
	if selected_skill_node.effect_type == 0: # STAT BOOST
		var stat = selected_skill_node.stat_to_boost
		var amt = selected_skill_node.boost_amount
		
		# e.g., unit_data["strength"] += 2
		# Godot maps "str" to "strength" in your UI, so we need to match your dict keys:
		var dict_key = stat
		if stat == "str": dict_key = "strength"
		elif stat == "mag": dict_key = "magic"
		elif stat == "def": dict_key = "defense"
		elif stat == "res": dict_key = "resistance"
		elif stat == "spd": dict_key = "speed"
		elif stat == "agi": dict_key = "agility"
		
		if stat == "hp":
			unit_data["max_hp"] += amt
			unit_data["current_hp"] += amt
		else:
			if unit_data.has(dict_key):
				unit_data[dict_key] += amt
			else:
				unit_data[dict_key] = amt
				
	elif selected_skill_node.effect_type == 1: # ABILITY UNLOCK
		var new_ab = selected_skill_node.ability_to_unlock
		unit_data["ability"] = new_ab
		
		# Add it to the arsenal list so it can be swapped later!
		if not unit_data.has("unlocked_abilities"): unit_data["unlocked_abilities"] = []
		if not unit_data["unlocked_abilities"].has(new_ab):
			unit_data["unlocked_abilities"].append(new_ab)
		
	# 3. JUICE AND REFRESH
	if masterwork_sound and masterwork_sound.stream: 
		masterwork_sound.pitch_scale = 1.5
		masterwork_sound.play()
		
	# Rebuild the main UI stats panel to reflect the new stat!
	_on_roster_item_selected(selected_roster_index) 
	
	# Rebuild the visual tree so the lines turn gold
	_build_skill_tree_ui()
	
	# Hide the popup
	skill_info_panel.visible = false
	selected_skill_node = null

func _on_swap_ability_pressed() -> void:
	if select_sound: select_sound.play()
	
	var unit_data = CampaignManager.player_roster[selected_roster_index]
	var ab_list = unit_data.get("unlocked_abilities", [])
	
	if ab_list.size() <= 1: return
	
	var current_ab = unit_data.get("ability", "")
	var idx = ab_list.find(current_ab)
	
	# Move to the next ability, wrap around to 0 if at the end
	idx = (idx + 1) % ab_list.size()
	unit_data["ability"] = ab_list[idx]
	
	# Add a cool sound/shake effect
	if masterwork_sound and masterwork_sound.stream:
		masterwork_sound.pitch_scale = 2.0
		masterwork_sound.play()
		
	# Refresh the UI to show the new ability name
	_on_roster_item_selected(selected_roster_index)

func get_party_gold() -> int:
	return int(CampaignManager.global_gold)

func can_afford_gold(amount: int) -> bool:
	return CampaignManager.global_gold >= amount

func spend_party_gold(amount: int) -> bool:
	if amount <= 0:
		return true

	if CampaignManager.global_gold < amount:
		return false

	CampaignManager.global_gold -= amount
	_refresh_gold_label()
	return true

func add_party_gold(amount: int) -> void:
	if amount == 0:
		return

	CampaignManager.global_gold += amount
	_refresh_gold_label()

func _refresh_gold_label() -> void:
	if gold_label == null:
		return

	gold_label.text = "Gold: %dG" % int(CampaignManager.global_gold)

func _refresh_world_map_button() -> void:
	if world_map_button == null or next_battle_button == null:
		return

	var unlocked: bool = int(CampaignManager.max_unlocked_index) >= 2
	world_map_button.visible = unlocked
	next_battle_button.text = "Continue Story" if unlocked else "Next Battle"

# ==========================================
# --- DRAGON HERDER (MORGRA) LOGIC ---
# ==========================================

func _open_dragon_ranch() -> void:
	if select_sound: select_sound.play()
	dragon_ranch_panel.visible = true
	
	_play_herder_idle()
	
	# Mixes it up so she sometimes mentions training or breeding instead of just "welcome"
	var categories = ["welcome", "welcome", "welcome", "train", "breed"]
	_update_herder_text(categories[randi() % categories.size()])
	
	# START THE IDLE TIMER
	_reset_herder_idle_timer()

func _update_herder_text(category: String) -> void:
	if not herder_label: return
	
	var full_text = MorgraDialogue.get_line(category)
	
	herder_label.text = full_text
	herder_label.visible_characters = 0

	if dragon_ranch_panel and dragon_ranch_panel.has_method("refit_herder_dialogue_bubble"):
		dragon_ranch_panel.refit_herder_dialogue_bubble()

	if herder_tween and herder_tween.is_valid():
		herder_tween.kill()
		
	var duration = full_text.length() * 0.04
	herder_tween = create_tween()
	herder_tween.tween_method(_set_herder_visible_chars, 0, full_text.length(), duration)
	
	# NEW: Reset the idle timer every time she speaks manually, 
	# so she doesn't interrupt herself!
	_reset_herder_idle_timer()
	
func _set_herder_visible_chars(count: int) -> void:
	if count > herder_label.visible_characters:
		var current_char = herder_label.text.substr(count - 1, 1)
		# Skip spaces for audio to make it sound more like organic speech
		if current_char != " " and herder_blip and herder_blip.stream != null:
			herder_blip.pitch_scale = randf_range(0.85, 1.0) # Slightly deeper orcish voice
			herder_blip.play()
			
	herder_label.visible_characters = count

func _play_herder_idle() -> void:
	if not herder_portrait: return
	
	# Prevent duplicate tweens from stacking
	herder_portrait.scale = Vector2.ONE 
	
	var tw = create_tween().set_loops()
	# Slow, confident breathing animation
	tw.tween_property(herder_portrait, "scale", Vector2(1.02, 1.02), 2.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(herder_portrait, "scale", Vector2(1.0, 1.0), 2.5).set_trans(Tween.TRANS_SINE)

func _reset_herder_idle_timer() -> void:
	# She speaks a little less frequently than the merchant (every 20 to 45 seconds)
	if herder_idle_timer:
		herder_idle_timer.start(randf_range(20.0, 45.0))

func _on_herder_idle_timeout() -> void:
	# Only speak if the Ranch panel is actually open!
	if dragon_ranch_panel and dragon_ranch_panel.visible:
		_update_herder_text("idle")
	_reset_herder_idle_timer()
