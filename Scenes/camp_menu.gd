extends Control

const TASK_LOG_SCRIPT := preload("res://Scripts/TaskLog.gd")

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
@onready var masterwork_sound = $MasterworkSound
@onready var select_sound: AudioStreamPlayer = get_node_or_null("%SelectSound") 
@onready var save_popup: Panel = get_node_or_null("%SavePopup") # The new wrapper
@onready var blacksmith_portrait = get_node_or_null("%BlacksmithPortrait")
@onready var blacksmith_label = get_node_or_null("%BlacksmithDialogue")
@onready var open_save_menu_btn: Button = get_node_or_null("%OpenSaveMenuButton")
@onready var close_save_btn: Button = get_node_or_null("%CloseSaveButton")
@onready var use_button = $UseButton # Adjust path if it's inside a container
@onready var use_item_sound = get_node_or_null("%UseItemSound") # Make sure to add this AudioStreamPlayer in the editor!
@onready var refresh_shop_btn = get_node_or_null("%RefreshShopButton")

# Track which item is currently "highlighted"
var selected_shop_resource: Resource = null

@onready var dragon_ranch_panel = $DragonRanchPanel
@onready var open_ranch_btn = $OpenRanchButton


# --- DRAGON HERDER (MORGRA) REFERENCES ---
@onready var herder_portrait = get_node_or_null("%HerderPortrait")
@onready var herder_label = get_node_or_null("%HerderDialogue")
@onready var herder_blip = get_node_or_null("%HerderBlip")
var herder_tween: Tween
var herder_idle_timer: Timer


# --- SKILL TREE REFERENCES ---
@onready var open_skills_btn = get_node_or_null("%OpenSkillsButton")
@onready var skill_tree_panel = get_node_or_null("%SkillTreePanel")
@onready var skill_title_label = get_node_or_null("%SkillTitleLabel")
@onready var skill_points_label = get_node_or_null("%SkillPointsLabel")
@onready var tree_canvas = get_node_or_null("%TreeCanvas")
@onready var close_skills_btn = get_node_or_null("%CloseSkillsButton")

@onready var skill_info_panel = get_node_or_null("%SkillInfoPanel")
@onready var skill_name_label = get_node_or_null("%SkillNameLabel")
@onready var skill_desc_label = get_node_or_null("%SkillDescLabel")
@onready var unlock_skill_btn = get_node_or_null("%UnlockSkillButton")

var selected_skill_node: Resource = null

@onready var swap_ability_btn = get_node_or_null("%SwapAbilityButton")

# --- QUANTITY POPUP REFERENCES ---
@onready var quantity_popup = get_node_or_null("%QuantityPopup")
@onready var qty_item_name = get_node_or_null("%ItemNameLabel")
@onready var qty_price_label = get_node_or_null("%PriceLabel")
@onready var qty_slider = get_node_or_null("%AmountSlider")
@onready var qty_amount_label = get_node_or_null("%AmountLabel")
@onready var qty_confirm_btn = get_node_or_null("%ConfirmButton")
@onready var qty_cancel_btn = get_node_or_null("%CancelButton")

# --- JUKEBOX REFERENCES ---
@onready var jukebox_btn = get_node_or_null("%JukeboxButton")
@onready var jukebox_panel = get_node_or_null("%JukeboxPanel")
@onready var jukebox_list = get_node_or_null("%JukeboxList")
@onready var close_jukebox_btn = get_node_or_null("%CloseJukeboxButton")

# NEW CONTROLS
@onready var jukebox_now_playing = get_node_or_null("%JukeboxNowPlaying")
@onready var jukebox_volume_slider = get_node_or_null("%JukeboxVolumeSlider")
@onready var jukebox_skip_btn = get_node_or_null("%JukeboxSkipButton")
@onready var jukebox_stop_btn = get_node_or_null("%JukeboxStopButton")

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
const JUKEBOX_SORT_UNLOCK: String = "unlock"
const JUKEBOX_SORT_ALPHA: String = "alpha"
var _jukebox_track_sort_mode: String = JUKEBOX_SORT_UNLOCK

var qty_mode: String = "" # Tracks if we are "buy"ing or "sell"ing
var qty_base_price: int = 0
var qty_max_amount: int = 1

var merchant_tween: Tween
var blacksmith_tween: Tween

# --- NEW BLACKSMITH REFERENCES ---
@onready var blueprint_stock_label = get_node_or_null("BlacksmithPanel/BlueprintStockPanel/StockLabel")
@onready var blacksmith_panel = $BlacksmithPanel
@onready var material_scroll = $BlacksmithPanel/MaterialScroll
@onready var material_grid = $BlacksmithPanel/MaterialScroll/MaterialGrid
@onready var open_blacksmith_btn = get_node_or_null("%OpenBlacksmithButton")
@onready var close_blacksmith_btn = get_node_or_null("%CloseBlacksmithButton")
@export var haldor_normal: Texture2D
@export var haldor_impressed: Texture2D
signal name_confirmed(new_name: String)
var last_blacksmith_lore_index: int = -1 # Tracks the last line to prevent repeats

@onready var slot1 = $BlacksmithPanel/Anvil/Slot1
@onready var slot2 = $BlacksmithPanel/Anvil/Slot2
@onready var slot3 = $BlacksmithPanel/Anvil/Slot3
@onready var craft_button = $BlacksmithPanel/CraftButton
@onready var recipe_result_label = $BlacksmithPanel/RecipeResultLabel
@onready var result_icon = $BlacksmithPanel/ResultIcon

# --- RECIPE BOOK REFERENCES ---
@onready var recipe_book_btn = get_node_or_null("%RecipeBookButton")
@onready var recipe_book_panel = get_node_or_null("%RecipeBookPanel")
@onready var recipe_list_text = get_node_or_null("%RecipeListText")
@onready var close_book_btn = get_node_or_null("%CloseBookButton")

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
@onready var inventory_desc = $InventoryDescLabel
@onready var roster_scroll = $RosterScroll
@onready var roster_grid = $RosterScroll/RosterGrid
var selected_roster_index: int = 0
@onready var stats_label = get_node_or_null("%StatsLabel")
@onready var inspect_unit_btn: Button = get_node_or_null("%InspectUnitButton")
@onready var unit_info_panel: Panel = get_node_or_null("%UnitInfoPanel")
@onready var next_battle_button = $NextBattleButton
@onready var gold_label = $GoldLabel
@onready var portrait_rect = $PortraitRect
@onready var warning_dialog = $WarningDialog
@onready var rep_popup = $RepPopupLabel
var idle_timer: Timer
# --- NEW GRID INVENTORY REFERENCES ---
@onready var inv_scroll = $InventoryScroll
@onready var unit_grid = $InventoryScroll/InventoryVBox/UnitGrid
@onready var convoy_grid = $InventoryScroll/InventoryVBox/ConvoyGrid
@onready var equip_button = $EquipButton
@onready var unequip_button = $UnequipButton
@onready var category_tabs = $CategoryTabs

var selected_inventory_meta: Dictionary = {}
var inventory_mapping: Array[Dictionary] = []

# --- NEW SHOP REFERENCES ---
@onready var shop_scroll = $ShopScroll
@onready var shop_grid = $ShopScroll/ShopGrid
var selected_shop_meta: Dictionary = {}

@onready var buy_button = $BuyButton
@onready var shop_desc = $ShopDescriptionLabel

@onready var merchant_portrait = $MerchantPortrait
@onready var merchant_label = $MerchantDialogue

@onready var sell_button = $SellButton
@onready var sell_confirmation = $SellConfirmation

@onready var buy_confirmation = $BuyConfirmation
@onready var merchant_blip = $MerchantBlip
@onready var talk_sound = $TalkSound



# This holds the temporary inventory for the current camp visit
var shop_stock: Array[Resource] = []

var discounted_item: Resource = null

# --- NEW HAGGLE REFERENCES ---
@onready var haggle_button = $HaggleButton
@onready var haggle_confirmation = $HaggleConfirmation
@onready var haggle_panel = $HagglePanel
@onready var haggle_target_zone = $HagglePanel/TargetZone
@onready var haggle_player_bar = $HagglePanel/PlayerBar
@onready var haggle_progress = $HagglePanel/HaggleProgress
@onready var camp_music = $CampMusic
@onready var minigame_music = $MinigameMusic


@export var minigame_music_tracks: Array[AudioStream] = []
@export var camp_music_tracks: Array[AudioStream] = []

@onready var talk_button = $TalkButton
@onready var talk_panel = $TalkPanel
@onready var talk_text = $TalkPanel/HBoxContainer/TalkText
@onready var quest_item_icon = $TalkPanel/HBoxContainer/QuestItemIcon
@onready var option1 = $TalkPanel/VBoxContainer/Option1
@onready var option2 = $TalkPanel/VBoxContainer/Option2
@onready var option3 = $TalkPanel/VBoxContainer/Option3

# World Map / Explore Camp
@onready var world_map_button = get_node_or_null("%WorldMapButton")
@onready var explore_camp_btn: Button = get_node_or_null("%ExploreCampButton")

var _task_log: TaskLog = null
var _task_log_button: Button = null

var current_talk_state: String = "idle"

# Haggle Mini-game Variables
var has_haggled_this_visit: bool = false
var haggle_active: bool = false
var player_velocity: float = 0.0
var target_velocity: float = 0.0
var target_timer: float = 0.0
var base_target_height: float = 0.0
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

## Initializes the camp UI: connects all buttons, populates shop/roster/inventory, starts music and ambient.
## Purpose: Single entry point for camp setup; gates (e.g. blacksmith, world map) use CampaignManager.max_unlocked_index.
## Inputs: None.  Outputs: None.
## Side effects: Connects signals, populates grids, may append test data (dragon meat / hatch) if DragonManager is empty.
func _ready() -> void:
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
	if get_node_or_null("%BlacksmithTalkButton"):
		get_node_or_null("%BlacksmithTalkButton").pressed.connect(_on_blacksmith_talk_pressed)
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
	if close_jukebox_btn: close_jukebox_btn.pressed.connect(func(): jukebox_panel.visible = false)
	if jukebox_list: jukebox_list.item_selected.connect(_on_jukebox_track_selected)
	
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
	
	talk_button.pressed.connect(_on_talk_pressed)
	option1.pressed.connect(_on_option1_pressed)
	option2.pressed.connect(_on_option2_pressed)
	option3.pressed.connect(_on_option3_pressed)	
	
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
		open_blacksmith_btn.visible = CampaignManager.blacksmith_unlocked
		
		# --- NEW: HIDE UNTIL LEVEL 3 IS CLEARED ---
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
		
	var panel_height = haggle_panel.size.y
	var bar_height = haggle_player_bar.size.y
	var target_height = haggle_target_zone.size.y
	
	# 1. Player Input (Hold Space or Click to rise, release to fall)
	if Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		player_velocity -= 800 * delta # Fly up
	else:
		player_velocity += 800 * delta # Gravity
		
	player_velocity = clamp(player_velocity, -400, 400)
	haggle_player_bar.position.y += player_velocity * delta
	
	# Clamp player to panel bounds
	if haggle_player_bar.position.y < 0:
		haggle_player_bar.position.y = 0
		player_velocity = 0
	elif haggle_player_bar.position.y > panel_height - bar_height:
		haggle_player_bar.position.y = panel_height - bar_height
		player_velocity = 0

	# 2. Target AI (Moves randomly)
	target_timer -= delta
	if target_timer <= 0:
		target_timer = randf_range(0.5, 1.5)
		target_velocity = randf_range(-300, 300)
		
	haggle_target_zone.position.y += target_velocity * delta
	haggle_target_zone.position.y = clamp(haggle_target_zone.position.y, 0, panel_height - target_height)

	# 3. Collision / Progress Check
	var player_rect = Rect2(haggle_player_bar.position, haggle_player_bar.size)
	var target_rect = Rect2(haggle_target_zone.position, haggle_target_zone.size)
	
	if player_rect.intersects(target_rect):
		haggle_progress.value += 15 * delta # Fill bar
		haggle_target_zone.color = Color.GREEN
	else:
		haggle_progress.value -= 10 * delta # Drain bar
		haggle_target_zone.color = Color.RED
		
	# 4. Win/Loss Condition
	if haggle_progress.value >= 100:
		_end_haggle_minigame(true)
	elif haggle_progress.value <= 0 and haggle_progress.max_value > 0:
		# Need a small grace period so they don't lose instantly at 0
		_end_haggle_minigame(false)

func _on_haggle_pressed() -> void:
	if has_haggled_this_visit:
		# Use the new WarningDialog instead of buy_confirmation!
		warning_dialog.dialog_text = "Bartholomew's patience has run out for today!"
		warning_dialog.popup_centered()
		return
	haggle_confirmation.popup_centered()

func _start_haggle_minigame() -> void:
	has_haggled_this_visit = true
	CampaignManager.camp_has_haggled = true
	haggle_active = true
	haggle_panel.visible = true
	
	# --- NEW DIFFICULTY SCALING ---
	# Shrink the target by 6 pixels per reputation level.
	var new_height = base_target_height - (CampaignManager.merchant_reputation * 6.0)
	# Clamp it so it never gets smaller than 25 pixels high
	haggle_target_zone.size.y = max(new_height, 25.0)
	
	haggle_progress.value = 30 # Start with a little progress
	haggle_player_bar.position.y = haggle_panel.size.y / 2
	haggle_target_zone.position.y = haggle_panel.size.y / 2
	
	# --- SWAP MUSIC ---
	if camp_music.playing: 
		camp_music.stream_paused = true
		
	# Play a random track from your new array
	_play_random_minigame_music()

func _end_haggle_minigame(won: bool) -> void:
	haggle_active = false
	haggle_panel.visible = false
	
	# Swap Music back
	if minigame_music.playing: 
		minigame_music.stop()
	if camp_music.stream_paused: 
		camp_music.stream_paused = false
	
	if won:
		CampaignManager.merchant_reputation += 1
		_update_merchant_text("haggle_win")
	else:
		CampaignManager.merchant_reputation -= 1
		if CampaignManager.merchant_reputation < 0:
			CampaignManager.merchant_reputation = 0
		_update_merchant_text("haggle_lose")
		
	# Trigger the visual feedback and refresh the shop
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
	
	# Stack the 50% deal if it's the discounted item!
	if item == discounted_item:
		final_price = int((base_price / 2.0) * final_multiplier)
		
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
		var is_on_sale: bool = (item == discounted_item)

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

		var price_lbl := _add_item_corner_label(btn, Color.YELLOW if is_on_sale else Color.KHAKI)
		price_lbl.text = str(final_price) + "G"

		if item.get_meta("is_locked", false) == true:
			_add_item_lock_star(btn)

		var meta := {"index": i, "item": item, "price": final_price, "is_sale": is_on_sale, "rep_text": rep_bonus_text}
		btn.set_meta("shop_data", meta)
		btn.pressed.connect(func(): _on_shop_grid_item_clicked(btn, meta))
						
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
		
	var text_details = _get_item_detailed_info(item, meta["price"], 1, current_equipped)
	
	if meta["is_sale"]:
		text_details = "[center][color=yellow]--- 50% OFF DAILY DEAL ---[/color][/center]\n" + text_details
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
	_refresh_gold_label()
	var inv_target: Vector2 = (inventory_desc.global_position + inventory_desc.size / 2.0) if inventory_desc else (get_viewport_rect().get_center())
	_animate_buy_item_fly_in(shop_origin, inv_target, dup_item)
	_populate_inventory()
	_populate_shop()
	shop_desc.text = ""
		
# --- POPULATE THE CONVOY ---
func _populate_inventory() -> void:
	_clear_grids()
	if inventory_desc: inventory_desc.text = "Select an item to view details."
	
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

	var location_text = ""
	if meta["source"] == "convoy": location_text = "[color=gray]Location: Convoy[/color]"
	elif meta["source"] == "unit": location_text = "[color=cyan]Location: Personal Backpack[/color]"
	elif meta["source"] == "other_unit": location_text = "[color=orange]Location: " + meta["owner_name"] + "'s Backpack[/color]"

	# --- WEAPON COMPARE FETCH ---
	var current_equipped = null
	if selected_roster_index >= 0 and selected_roster_index < CampaignManager.player_roster.size():
		current_equipped = CampaignManager.player_roster[selected_roster_index].get("equipped_weapon")

	var desc = _get_item_detailed_info(item, sell_val, count, current_equipped)
	if inventory_desc: inventory_desc.text = location_text + "\n\n" + desc

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
	
	# --- 2. Simplified roster summary: name + level only (details in Unit Info panel). ---
	var unit_name: String = unit_data.get("unit_name", "Hero")
	var current_level: int = unit_data.get("level", 1)
	if stats_label:
		stats_label.text = "[center][font_size=24][color=cyan]" + unit_name.to_upper() + "[/color][/font_size]\n[color=gray]Lv " + str(current_level) + "[/color][/center]"

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

	# --- Resolve panel controls (Unique Names or first-by-type fallback) ---
	var portrait_ctl: TextureRect = get_node_or_null("%UnitInfoPortrait") as TextureRect
	if portrait_ctl == null and unit_info_panel.get_child_count() > 0:
		var first = unit_info_panel.get_child(0)
		if first is TextureRect:
			portrait_ctl = first
	var name_ctl: Label = get_node_or_null("%UnitInfoName") as Label
	if name_ctl == null:
		for c in unit_info_panel.get_children():
			if c is Label and name_ctl == null:
				name_ctl = c
				break
	var stats_ctl: RichTextLabel = get_node_or_null("%UnitInfoStats") as RichTextLabel
	if stats_ctl == null:
		for c in unit_info_panel.get_children():
			if c is RichTextLabel:
				stats_ctl = c
				break
	var close_btn: Button = get_node_or_null("%UnitInfoCloseButton") as Button
	if close_btn == null:
		for c in unit_info_panel.get_children():
			if c is Button:
				close_btn = c
				break

	# --- Portrait ---
	var tex: Texture2D = null
	var custom_portrait = unit_data.get("portrait")
	if custom_portrait is String and ResourceLoader.exists(custom_portrait):
		custom_portrait = load(custom_portrait)
	if custom_portrait is Texture2D:
		tex = custom_portrait
	var base_data = unit_data.get("data")
	if tex == null and base_data != null and base_data.get("portrait") != null:
		tex = base_data.get("portrait")
	if portrait_ctl != null:
		portrait_ctl.texture = tex
		portrait_ctl.visible = tex != null

	# --- Name ---
	var unit_name: String = unit_data.get("unit_name", "Hero")
	if name_ctl != null:
		name_ctl.text = unit_name

	# --- Class and level ---
	var display_class: String = unit_data.get("unit_class", "Unknown Class")
	var class_res = unit_data.get("class_data")
	if class_res is String and ResourceLoader.exists(class_res):
		class_res = load(class_res)
	if display_class == "Unknown Class" and base_data != null and base_data.get("character_class") != null:
		display_class = base_data.character_class.job_name
	elif class_res != null and class_res.get("job_name") != null:
		display_class = class_res.job_name
	var lv: int = unit_data.get("level", 1)

	# --- Combat stats (for Phase 1 bars and BBCode) ---
	var hp: int = unit_data.get("current_hp", 0)
	var max_hp: int = unit_data.get("max_hp", 0)
	var str_val: int = unit_data.get("strength", 0)
	var mag_val: int = unit_data.get("magic", 0)
	var def_val: int = unit_data.get("defense", 0)
	var res_val: int = unit_data.get("resistance", 0)
	var spd_val: int = unit_data.get("speed", 0)
	var agi_val: int = unit_data.get("agility", 0)

	# --- Growth rates: total = Personal (base_data) + Class Bonus (class_res); clamp 0–100 for display ---
	var growth_hp: int = 0
	var growth_str: int = 0
	var growth_mag: int = 0
	var growth_def: int = 0
	var growth_res: int = 0
	var growth_spd: int = 0
	var growth_agi: int = 0
	# Resource.get(property) takes one argument only; use null check for default.
	if base_data is Resource:
		var v
		v = base_data.get("hp_growth"); growth_hp = int(v) if v != null else 0
		v = base_data.get("str_growth"); growth_str = int(v) if v != null else 0
		v = base_data.get("mag_growth"); growth_mag = int(v) if v != null else 0
		v = base_data.get("def_growth"); growth_def = int(v) if v != null else 0
		v = base_data.get("res_growth"); growth_res = int(v) if v != null else 0
		v = base_data.get("spd_growth"); growth_spd = int(v) if v != null else 0
		v = base_data.get("agi_growth"); growth_agi = int(v) if v != null else 0
	if class_res != null:
		# Add class bonus to personal growth; clamp total to 0–100 (Resource.get has no default arg)
		var b
		b = class_res.get("hp_growth_bonus"); growth_hp = clampi(growth_hp + (int(b) if b != null else 0), 0, 100)
		b = class_res.get("str_growth_bonus"); growth_str = clampi(growth_str + (int(b) if b != null else 0), 0, 100)
		b = class_res.get("mag_growth_bonus"); growth_mag = clampi(growth_mag + (int(b) if b != null else 0), 0, 100)
		b = class_res.get("def_growth_bonus"); growth_def = clampi(growth_def + (int(b) if b != null else 0), 0, 100)
		b = class_res.get("res_growth_bonus"); growth_res = clampi(growth_res + (int(b) if b != null else 0), 0, 100)
		b = class_res.get("spd_growth_bonus"); growth_spd = clampi(growth_spd + (int(b) if b != null else 0), 0, 100)
		b = class_res.get("agi_growth_bonus"); growth_agi = clampi(growth_agi + (int(b) if b != null else 0), 0, 100)
	else:
		# Personal only; still clamp for display
		growth_hp = clampi(growth_hp, 0, 100)
		growth_str = clampi(growth_str, 0, 100)
		growth_mag = clampi(growth_mag, 0, 100)
		growth_def = clampi(growth_def, 0, 100)
		growth_res = clampi(growth_res, 0, 100)
		growth_spd = clampi(growth_spd, 0, 100)
		growth_agi = clampi(growth_agi, 0, 100)

	# --- Equipment and ability (loadout) ---
	var wpn = unit_data.get("equipped_weapon")
	if wpn is String and ResourceLoader.exists(wpn):
		wpn = load(wpn)
	var wpn_name: String = wpn.get("weapon_name") if wpn != null and wpn.get("weapon_name") != null else "Unarmed"
	var active_ab: String = unit_data.get("ability", "None")
	if active_ab == "":
		active_ab = "None"

	# --- BBCode polish: headers and textual data for reference; focus remains on animating bars ---
	var lines: Array[String] = []
	lines.append("Class: [color=cyan]" + display_class + "[/color]   Level: " + str(lv))
	lines.append("")
	lines.append("[color=gold]-- COMBAT STATS --[/color]")
	lines.append("HP: " + str(hp) + " / " + str(max_hp))
	lines.append("[color=coral]STR:[/color] " + str(str_val) + "   [color=orchid]MAG:[/color] " + str(mag_val))
	lines.append("[color=palegreen]DEF:[/color] " + str(def_val) + "   [color=aquamarine]RES:[/color] " + str(res_val))
	lines.append("[color=skyblue]SPD:[/color] " + str(spd_val) + "   [color=wheat]AGI:[/color] " + str(agi_val))
	lines.append("")
	lines.append("[color=cyan]-- GROWTH POTENTIAL --[/color]")
	lines.append("[color=coral]STR[/color] " + str(growth_str) + "%   [color=orchid]MAG[/color] " + str(growth_mag) + "%   [color=palegreen]DEF[/color] " + str(growth_def) + "%")
	lines.append("[color=aquamarine]RES[/color] " + str(growth_res) + "%   [color=skyblue]SPD[/color] " + str(growth_spd) + "%   [color=wheat]AGI[/color] " + str(growth_agi) + "%   [color=lime]HP[/color] " + str(growth_hp) + "%")
	lines.append("")
	lines.append("[color=orange]-- LOADOUT --[/color]")
	lines.append("Weapon: [color=yellow]" + str(wpn_name) + "[/color]")
	lines.append("Ability: [color=orange]" + str(active_ab) + "[/color]")
	lines.append("")
	lines.append("[color=gold]-- RELATIONSHIPS --[/color]")
	var unit_id: String = unit_data.get("unit_name", "Hero")
	var candidate_ids: Array = []
	for u in CampaignManager.player_roster:
		var other_name: String = u.get("unit_name", "")
		if other_name != unit_id and not other_name.is_empty():
			candidate_ids.append(other_name)
	var rel_entries: Array = CampaignManager.get_top_relationship_entries_for_unit(unit_id, candidate_ids, 9)
	if rel_entries.is_empty():
		lines.append("No notable bonds yet.")
	else:
		for entry in rel_entries:
			lines.append("• " + CampaignManager.format_relationship_row_bbcode(entry))
	var stats_bb: String = "[font_size=20]\n".join(lines) + "[/font_size]"
	if stats_ctl != null:
		stats_ctl.bbcode_enabled = true
		stats_ctl.text = stats_bb

	# --- Phase 1: Combat stat bars (%HpStatBar … %AgiStatBar); cap for display, reset and attach sheen ---
	var stat_bar_cap: float = 50.0
	var stat_bar_keys: Array[String] = ["Hp", "Str", "Mag", "Def", "Res", "Spd", "Agi"]
	var stat_bar_values: Array[float] = [float(mini(hp, int(stat_bar_cap))), float(str_val), float(mag_val), float(def_val), float(res_val), float(spd_val), float(agi_val)]
	var combat_bars: Array[Dictionary] = []
	for i in range(stat_bar_keys.size()):
		var bar: ProgressBar = get_node_or_null("%" + stat_bar_keys[i] + "StatBar") as ProgressBar
		if bar != null:
			bar.min_value = 0.0
			bar.max_value = stat_bar_cap
			bar.value = 0.0
			bar.show_percentage = false
			bar.modulate.a = 0.0
			var sheen_rect: ColorRect = _attach_unit_info_bar_sheen(bar)
			combat_bars.append({"bar": bar, "value": minf(stat_bar_values[i], stat_bar_cap), "sheen": sheen_rect})

	# --- Phase 2: Growth potential bars (%HpGrowthBar … %AgiGrowthBar); reset and attach sheen ---
	var growth_bars: Array[Dictionary] = []
	var bar_keys: Array[String] = ["Hp", "Str", "Mag", "Def", "Res", "Spd", "Agi"]
	var bar_values: Array[int] = [growth_hp, growth_str, growth_mag, growth_def, growth_res, growth_spd, growth_agi]
	for i in range(bar_keys.size()):
		var bar: ProgressBar = get_node_or_null("%" + bar_keys[i] + "GrowthBar") as ProgressBar
		if bar != null:
			bar.min_value = 0.0
			bar.max_value = 100.0
			bar.value = 0.0
			bar.show_percentage = false
			bar.modulate.a = 0.0
			var sheen_rect: ColorRect = _attach_unit_info_bar_sheen(bar)
			growth_bars.append({"bar": bar, "value": bar_values[i], "sheen": sheen_rect})

	# --- Close button ---
	if close_btn != null:
		if not close_btn.pressed.is_connected(_hide_unit_info_panel):
			close_btn.pressed.connect(_hide_unit_info_panel)

	# --- Show panel with snappy pop-in (scale 0.8 -> 1.0 in 0.12s, near-instant feel) ---
	unit_info_panel.visible = true
	unit_info_panel.scale = Vector2(0.8, 0.8)
	var open_tween := create_tween()
	open_tween.tween_property(unit_info_panel, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await open_tween.finished

	# --- Phase 1: Sequential combat stat bar reveal; cascade stagger 0.04s (fade 0.10s, fill 0.25s, sheen) ---
	for j in range(combat_bars.size()):
		var entry: Dictionary = combat_bars[j]
		var progress_bar: ProgressBar = entry["bar"]
		var target_val: float = float(entry["value"])
		var sheen_rect: ColorRect = entry["sheen"]
		var row_tw := create_tween().set_parallel(true)
		row_tw.tween_property(progress_bar, "modulate:a", 1.0, 0.10)
		row_tw.tween_property(progress_bar, "value", target_val, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_animate_unit_info_bar_sheen(sheen_rect, progress_bar)
		await row_tw.finished
		await get_tree().create_timer(0.04).timeout

	# --- Phase 2: Sequential growth bar reveal (after Phase 1); same cascade stagger 0.04s ---
	for j in range(growth_bars.size()):
		var entry: Dictionary = growth_bars[j]
		var progress_bar: ProgressBar = entry["bar"]
		var target_val: float = float(entry["value"])
		var sheen_rect: ColorRect = entry["sheen"]
		var row_tw := create_tween().set_parallel(true)
		row_tw.tween_property(progress_bar, "modulate:a", 1.0, 0.10)
		row_tw.tween_property(progress_bar, "value", target_val, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_animate_unit_info_bar_sheen(sheen_rect, progress_bar)
		await row_tw.finished
		await get_tree().create_timer(0.04).timeout

# --- Sheen helpers (adapted from BattleField.gd level-up bar juice): diagonal highlight sweep across growth bars. ---
## Attaches a diagonal white ColorRect as child of the ProgressBar for sheen effect. Bar clips contents so sheen doesn't overflow.
## Purpose: Visual "juice" so the fill feels responsive; sheen position is animated in _animate_unit_info_bar_sheen.
## Inputs: bar (ProgressBar). Outputs: ColorRect (the sheen node). Side effects: Sets bar.clip_contents = true; adds sheen as child.
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

## Animates the sheen across the bar: fade in, move position.x to bar_width+30, fade out. Optimized: sweep 0.28s to match faster bar fill (0.25s).
## Purpose: Diagonal light sweep in sync with bar fill. Timings: fade in 0.05s, sweep 0.28s, fade out 0.06s (overclocked).
## Inputs: sheen (ColorRect from _attach_unit_info_bar_sheen), bar (ProgressBar). Outputs: None. Side effects: Creates tween on sheen.
func _animate_unit_info_bar_sheen(sheen: ColorRect, bar: ProgressBar) -> void:
	if sheen == null or bar == null:
		return
	var bar_width: float = maxf(bar.size.x, bar.custom_minimum_size.x)
	bar_width = maxf(bar_width, 120.0)
	sheen.position = Vector2(-70, -8)
	sheen.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(sheen, "modulate:a", 1.0, 0.05)
	tw.parallel().tween_property(sheen, "position:x", bar_width + 30.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(sheen, "modulate:a", 0.0, 0.06)

## Hides the unit info panel. Called by %UnitInfoCloseButton.
func _hide_unit_info_panel() -> void:
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
				
	elif meta["source"] == "convoy" or meta["source"] == "other_unit":
		if unit_data["inventory"].size() >= 5:
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
		
	_populate_inventory()
	_on_roster_item_selected(unit_idx)
	if inventory_desc: inventory_desc.text = "Action successful. Select an item to view details."
	
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
	
	_populate_inventory()
	_on_roster_item_selected(unit_idx)
	if inventory_desc: inventory_desc.text = "Action successful. Select an item to view details."
	
	
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

# Generates the multi-line text for the Shop and Inventory Panels
func _get_item_detailed_info(item: Resource, price: int, stack_count: int = 1, compare_item: Resource = null) -> String:
	var info = ""
	var i_name = item.get("weapon_name") if item.get("weapon_name") != null else item.get("item_name")
	if i_name == null: i_name = "Unknown Item"
	
	var final_price = price
	
	var rarity = item.get("rarity") if item.get("rarity") != null else "Common"
	var rarity_color = "white"
	match rarity:
		"Uncommon": rarity_color = "lime"
		"Rare": rarity_color = "deepskyblue"
		"Epic": rarity_color = "mediumorchid"
		"Legendary": rarity_color = "gold"
		
	info += "[center][font_size=26][color=" + rarity_color + "]" + str(i_name).to_upper() + "[/color][/font_size][/center]\n"
		
	var stack_text = ""
	if stack_count > 1:
		stack_text = "   |   [color=white]Owned: x" + str(stack_count) + "[/color]"
		
	info += "[center][ [color=" + rarity_color + "]" + rarity + "[/color] ]   |   Value: [color=khaki]" + str(final_price) + "G[/color]" + stack_text + "[/center]\n"
	info += "[color=gray]------------------------------------------------[/color]\n"
	
	if item is WeaponData:
		if item.get("current_durability") != null and item.current_durability <= 0:
			info += "[color=red]BROKEN! Effectiveness halved. Needs repair.[/color]\n\n"
			
		var w_type_str = "Unknown"
		if item.get("weapon_type") != null:
			w_type_str = WeaponData.get_weapon_type_name(int(item.weapon_type))
		var d_type_str = "Physical" if item.get("damage_type") != null and item.damage_type == 0 else "Magical"
		
		info += "[color=gray]Type:[/color] " + w_type_str + " (" + d_type_str + ")\n"
		info += "[color=coral]Might:[/color] " + str(item.might) + "   [color=khaki]Hit:[/color] +" + str(item.hit_bonus) + "\n"
		info += "[color=palegreen]Range:[/color] " + str(item.min_range) + "-" + str(item.max_range) + "\n"
		
		if item.get("current_durability") != null:
			info += "[color=lightskyblue]Durability:[/color] " + str(item.current_durability) + " / " + str(item.max_durability) + "\n"
		
		var effects = []
		if item.get("is_healing_staff") == true:
			effects.append("Restores " + str(item.effect_amount) + " HP")
			
		if item.get("is_buff_staff") == true or item.get("is_debuff_staff") == true:
			var word = "Grants +" if item.get("is_buff_staff") == true else "Inflicts -"
			if item.get("affected_stat") != null and str(item.affected_stat) != "":
				var stats = str(item.affected_stat).split(",")
				var formatted_stats = []
				for s in stats: formatted_stats.append(s.strip_edges().capitalize())
				effects.append(word + str(item.effect_amount) + " to " + ", ".join(formatted_stats))
			
		if effects.size() > 0:
			info += "[color=plum]Effect:[/color] " + " & ".join(effects) + "\n"
		
		# --- WEAPON COMPARE LOGIC ---
		if compare_item != null and compare_item is WeaponData and item != compare_item:
			if item.damage_type == compare_item.damage_type:
				info += "\n[color=gray]--- VS EQUIPPED (" + compare_item.weapon_name + ") ---[/color]\n"
				
				var m_diff = item.might - compare_item.might
				var h_diff = item.hit_bonus - compare_item.hit_bonus
				
				var m_color = "lime" if m_diff > 0 else ("red" if m_diff < 0 else "gray")
				var h_color = "lime" if h_diff > 0 else ("red" if h_diff < 0 else "gray")
				
				var m_sign = "+" if m_diff > 0 else ""
				var h_sign = "+" if h_diff > 0 else ""
				
				info += "Might: [color=" + m_color + "]" + m_sign + str(m_diff) + "[/color]  |  "
				info += "Hit: [color=" + h_color + "]" + h_sign + str(h_diff) + "[/color]\n"
	
	elif item is ConsumableData:
		info += "[color=gray]Type:[/color] Consumable\n"
		var effects = []
		if item.heal_amount > 0: effects.append("Restores " + str(item.heal_amount) + " HP")
		var boosts = []
		if item.hp_boost > 0: boosts.append("+" + str(item.hp_boost) + " HP")
		if item.str_boost > 0: boosts.append("+" + str(item.str_boost) + " STR")
		if item.mag_boost > 0: boosts.append("+" + str(item.mag_boost) + " MAG")
		if item.def_boost > 0: boosts.append("+" + str(item.def_boost) + " DEF")
		if item.res_boost > 0: boosts.append("+" + str(item.res_boost) + " RES")
		if item.spd_boost > 0: boosts.append("+" + str(item.spd_boost) + " SPD")
		if item.agi_boost > 0: boosts.append("+" + str(item.agi_boost) + " AGI")
		
		if boosts.size() > 0: effects.append("Permanent Boost: " + ", ".join(boosts))
		if effects.size() > 0: info += "[color=plum]Effect:[/color]\n" + "\n".join(effects) + "\n"
			
	elif item is ChestKeyData:
		info += "[color=gray]Type:[/color] Key\nOpens locked chests.\n"

	elif item != null and item.get_class() == "MaterialData":
		info += "[color=gray]Type:[/color] Crafting Material\n"

	info += "[color=gray]------------------------------------------------[/color]\n"
	if item.get("description") != null and item.description.strip_edges() != "":
		info += "[color=silver][i]\"" + item.description + "\"[/i][/color]"
	else:
		info += "[color=dimgray][i]No description available.[/i][/color]"
		
	return info
				
func _reset_idle_timer() -> void:
	# Picks a random time between 15 and 30 seconds
	idle_timer.start(randf_range(15.0, 30.0))

func _on_idle_timer_timeout() -> void:
	# Only speak if the player isn't in the middle of the haggling mini-game
	if not haggle_active:
		_update_merchant_text("idle")
	_reset_idle_timer()

func _on_talk_pressed() -> void:
	if talk_sound.stream != null:
		talk_sound.play()
		
	talk_panel.visible = true
	_refresh_talk_ui()

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

	text += "\n\nReward: %dG | +%d Reputation" % [CampaignManager.merchant_quest_reward, rep_reward]
	text += "\nProgress: %d / %d" % [owned, amt]

	return text

func _refresh_talk_ui() -> void:
	var mc_name: String = "Hero"
	if CampaignManager.player_roster.size() > 0:
		mc_name = str(CampaignManager.player_roster[0]["unit_name"])

	if CampaignManager.merchant_quest_active:
		current_talk_state = "active"

		var quest_item: Resource = _find_quest_item_resource(CampaignManager.merchant_quest_item_name)
		if quest_item != null and quest_item.get("icon") != null:
			quest_item_icon.texture = quest_item.icon
			quest_item_icon.visible = true
		else:
			quest_item_icon.visible = false

		talk_text.text = _get_active_quest_status_text(mc_name)

		option1.text = "Turn in items."
		option2.text = "Show progress."
		option3.text = "Abandon contract."
		option3.visible = true
	else:
		current_talk_state = "idle"

		quest_item_icon.visible = false
		talk_text.text = _line("idle_open", {"name": mc_name})

		option1.text = "Got any work?"
		option2.text = "Tell me a rumor."
		option3.text = "Never mind."
		option3.visible = true
			
func _on_option1_pressed() -> void:
	if current_talk_state == "idle":
		_generate_procedural_quest()
	elif current_talk_state == "active":
		_try_complete_quest()
		
func _on_option2_pressed() -> void:
	var mc_name: String = "Hero"
	if CampaignManager.player_roster.size() > 0:
		mc_name = str(CampaignManager.player_roster[0]["unit_name"])

	if current_talk_state == "idle":
		talk_panel.visible = false
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

		talk_text.text += "\n\nReward: %dG | +%d Reputation" % [CampaignManager.merchant_quest_reward, rep_reward]
		talk_text.text += "\nProgress: %d / %d" % [found, amt]
				
func _on_option3_pressed() -> void:
	var mc_name: String = "Hero"
	if CampaignManager.player_roster.size() > 0:
		mc_name = str(CampaignManager.player_roster[0]["unit_name"])

	if current_talk_state == "idle":
		talk_panel.visible = false
	else:
		CampaignManager.merchant_reputation = max(CampaignManager.merchant_reputation - 1, 0)
		_populate_shop()

		CampaignManager.merchant_quest_active = false
		CampaignManager.merchant_quest_item_name = ""
		CampaignManager.merchant_quest_target_amount = 0
		CampaignManager.merchant_quest_reward = 0

		talk_panel.visible = false
		_play_typewriter_animation(_line("abandon", {"name": mc_name}))

		
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

		talk_panel.visible = false
		_play_typewriter_animation(
			_line("quest_complete", {
				"reward": reward_gold,
				"name": mc_name
			}) + " (+" + str(reward_rep) + " Reputation)"
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

		talk_text.text += "\n\nReward: %dG | +%d Reputation" % [CampaignManager.merchant_quest_reward, reward_rep]
		talk_text.text += "\nProgress: %d / %d" % [items_found, target_amount]

	
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
		# Start the popup invisible and slightly smaller for a "pop-in" effect
		save_popup.modulate.a = 0.0
		save_popup.scale = Vector2(0.9, 0.9)
		save_popup.pivot_offset = save_popup.size / 2.0
		save_popup.visible = true
		
		var tween = create_tween().set_parallel(true)
		tween.tween_property(save_popup, "modulate:a", 1.0, 0.2)
		tween.tween_property(save_popup, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		if save_slot_1:
			save_slot_1.grab_focus()

func _on_back_pressed() -> void:
	if select_sound: select_sound.play()
	
	if save_popup:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(save_popup, "modulate:a", 0.0, 0.15)
		tween.tween_property(save_popup, "scale", Vector2(0.9, 0.9), 0.15)
		
		await tween.finished
		save_popup.visible = false

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
		
		var original_text = clicked_button.text
		clicked_button.text = "--- SAVED SUCCESSFULLY ---"
		clicked_button.modulate = Color(0.2, 1.0, 0.2)
		
		clicked_button.pivot_offset = clicked_button.size / 2.0
		var pop_tween = create_tween()
		pop_tween.tween_property(clicked_button, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pop_tween.tween_property(clicked_button, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		await get_tree().create_timer(0.8).timeout
		
		clicked_button.modulate = Color.WHITE
		clicked_button.text = original_text

	_on_back_pressed()

func _update_slot_labels() -> void:
	# Now they will look exactly like the Main Menu buttons!
	if save_slot_1: save_slot_1.text = _get_camp_slot_preview(1)
	if save_slot_2: save_slot_2.text = _get_camp_slot_preview(2)
	if save_slot_3: save_slot_3.text = _get_camp_slot_preview(3)

# --- NEW: GENERATE BEAUTIFUL SLOT TEXT ---
func _get_camp_slot_preview(slot_num: int) -> String:
	var path = CampaignManager.get_save_path(slot_num, false)
	
	if not FileAccess.file_exists(path):
		return "Slot %d: (Empty)" % slot_num
		
	var file = FileAccess.open(path, FileAccess.READ)
	var save_data = file.get_var()
	file.close()
	
	var roster = save_data.get("player_roster", [])
	var leader_name = "Unknown"
	var leader_lvl = 1
	
	if roster.size() > 0:
		leader_name = roster[0].get("unit_name", "Hero")
		leader_lvl = roster[0].get("level", 1)
		
	var gold = save_data.get("global_gold", 0)
	var map_idx = save_data.get("current_level_index", 0) + 1 
	
	return "Slot %d: %s (Lv %d)  |  Map %d  |  %dG" % [slot_num, leader_name, leader_lvl, map_idx, gold]

func _on_inventory_item_selected(list_index: int) -> void:
	if inventory_mapping.is_empty() or list_index >= inventory_mapping.size(): return
	var mapped_data = inventory_mapping[list_index]
	
	if mapped_data["source"] == "header" or mapped_data["source"] == "empty":
		if inventory_desc: inventory_desc.text = ""
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
	
	var location_text = ""
	if mapped_data["source"] == "convoy": location_text = "[color=gray]Location: Convoy[/color]"
	elif mapped_data["source"] == "unit": location_text = "[color=cyan]Location: Personal Backpack[/color]"
	elif mapped_data["source"] == "other_unit": location_text = "[color=orange]Location: " + mapped_data["owner_name"] + "'s Backpack[/color]"
	
	var desc = _get_item_detailed_info(item, sell_val)
	if inventory_desc: inventory_desc.text = location_text + "\n\n" + desc

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
	# --- 1. OPTIONAL: THE TEST CHEAT ---
	CampaignManager.has_recipe_book = false 
	
	blacksmith_panel.visible = true
	
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

	# --- 3. REFRESH BUTTON VISIBILITY ---
	if recipe_book_btn: 
		recipe_book_btn.visible = CampaignManager.has_recipe_book

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
		btn.add_theme_font_size_override("font_size", 20)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		style.border_width_bottom = 2
		style.border_color = Color(0.3, 0.3, 0.3)
		btn.add_theme_stylebox_override("normal", style)
		
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
			count_lbl.add_theme_font_size_override("font_size", 24)
			count_lbl.add_theme_color_override("font_color", Color.WHITE)
			count_lbl.add_theme_constant_override("outline_size", 8)
			count_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
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

# This function is now bound directly to the Button being dragged!
# This function is now bound directly to the Button being dragged!
func _get_drag_material(_at_position: Vector2, btn: Button, meta: Dictionary) -> Variant:
	var item = meta["item"]
	
	# 1. Hide the OS drag badges (like the forbidden circle)
	Input.set_custom_mouse_cursor(empty_cursor, Input.CURSOR_CAN_DROP)
	Input.set_custom_mouse_cursor(empty_cursor, Input.CURSOR_FORBIDDEN)
	
	# 2. Create the item icon that will act as our "mouse"
	var preview = TextureRect.new()
	preview.texture = item.get("icon")
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(88, 88) 
	preview.modulate.a = 1.0 
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE # <--- PREVENTS GHOST BLOCKING
	
	# Offset it so the mouse pointer is directly in the center of the icon
	var c = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE # <--- PREVENTS GHOST BLOCKING
	c.z_index = 1000
	c.add_child(preview)
	preview.position = -preview.custom_minimum_size / 2.0
	
	# Set the preview on the specific button being dragged
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
	
	if shop_buy_sound and shop_buy_sound.stream: shop_buy_sound.play() 
	
	_update_anvil_visuals()
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
		recipe_result_label.text = "[center][color=gray]Drop materials here.[/color][/center]"
		return
		
	current_ingredients.sort()
	
# --- NEW & IMPROVED: SMART SALVAGE ---
	if current_ingredients.size() == 1 and weapon_count == 1:
		if last_weapon != null and last_weapon.get_meta("is_locked", false) == true: 
			recipe_result_label.text = "[center][color=red]Cannot salvage a locked item![/color][/center]"
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
					return
			current_recipe = recipe.duplicate() 
			
			# --- 1. IS IT A SMELTING JOB? ---
			if recipe.get("is_smelt", false):
				if not CampaignManager.has_smelter:
					recipe_result_label.text = "[center][color=red]Requires a Dwarven Crucible to melt ores![/color][/center]"
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
					var stats_text = _get_item_detailed_info(preview_item, sell_val)
					recipe_result_label.text = "[center][color=cyan]--- CRAFTING: " + recipe["name"].to_upper() + " ---[/color][/center]\n\n" + stats_text
				
			craft_button.disabled = false
			return
			
	# 2. Check Universal Repair 
	if current_ingredients.size() == 2 and broken_weapon_on_anvil != null:
		if current_ingredients.has("Iron Ingot"): # Changed from Bone to Steel Ingot for better logic!
			var w_name = broken_weapon_on_anvil.weapon_name
			current_recipe = {"type": "repair", "weapon": broken_weapon_on_anvil}
			
			result_icon.texture = broken_weapon_on_anvil.get("icon")
			var cost = broken_weapon_on_anvil.get("gold_cost")
			var sell_val = int(cost / 2) if cost != null else 0
			var stats_text = _get_item_detailed_info(broken_weapon_on_anvil, sell_val)
			
			stats_text = stats_text.replace("[color=red]BROKEN! Effectiveness halved. Needs repair.[/color]\n\n", "")
			stats_text = "[color=lime]WILL BE FULLY REPAIRED[/color]\n\n" + stats_text
			
			recipe_result_label.text = "[center][color=lime]--- REPAIRING: " + w_name.to_upper() + " ---[/color][/center]\n\n" + stats_text
			
			craft_button.text = "REPAIR"
			craft_button.disabled = false
			return
			
	recipe_result_label.text = "[center][color=red]Invalid Recipe.[/color][/center]"
	
func _on_craft_pressed() -> void:
	if current_recipe.is_empty(): return
	
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
	if select_sound: select_sound.play()
	
	# Safety Check: If the panel node is missing, stop here to avoid the crash!
	if recipe_book_panel == null:
		push_error("Error: RecipeBookPanel node not found. Check Unique Name (%) in Editor.")
		return

	var txt = "[center][color=gold][b]--- BARTHOLOMEW'S FORGE NOTES ---[/b][/color][/center]\n\n"
	
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
	
	var txt = "[center][color=gold]--- DEPLOYMENT STOCK ---[/color][/center]\n\n"
	
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
	var unit_data = CampaignManager.player_roster[unit_idx]
	
	# --- JUICE: TRACK GAINS FOR FEEDBACK ---
	var feedback_list = []
	
	# ==========================================
	# NEW: EGG CONSUMPTION LOGIC (SOUL ABSORPTION)
	# ==========================================
	var item_name_lower = str(item.item_name).to_lower()
	if "egg" in item_name_lower:
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

		if use_item_sound:
			use_item_sound.pitch_scale = randf_range(0.9, 1.1)
			use_item_sound.play()
	
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
		inventory_desc.text = "Transaction complete."

# ==========================================
# INVENTORY DRAG AND DROP
# ==========================================
func _get_drag_inventory(_at_position: Vector2, btn: Button, meta: Dictionary) -> Variant:
	var item = meta["item"]
	Input.set_custom_mouse_cursor(empty_cursor, Input.CURSOR_CAN_DROP)
	Input.set_custom_mouse_cursor(empty_cursor, Input.CURSOR_FORBIDDEN)
	
	var preview = TextureRect.new()
	preview.texture = item.get("icon")
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.custom_minimum_size = Vector2(88, 88)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var c = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.z_index = 1000
	c.add_child(preview)
	preview.position = -preview.custom_minimum_size / 2.0
	
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
	_crossfade_music(stream)
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
	_start_playlist_playback()

## Returns playlist names sorted A–Z for deterministic UI.
func _jukebox_sorted_playlist_names() -> Array[String]:
	var names: Array[String] = []
	for k in CampaignManager.saved_music_playlists.keys():
		names.append(str(k))
	names.sort()
	return names

func _open_jukebox() -> void:
	if jukebox_panel == null or jukebox_list == null: return
	if select_sound: select_sound.play()
	if not _jukebox_playlist_ui_created:
		_create_jukebox_playlist_ui()
	jukebox_list.clear()
	# Option 0: default ambient
	jukebox_list.add_item("⛺ Default Camp Ambiance")
	jukebox_list.set_item_metadata(0, "DEFAULT")
	var index: int = 1
	# Playlists (sorted A–Z)
	for pl_name in _jukebox_sorted_playlist_names():
		jukebox_list.add_item("📋 " + pl_name)
		jukebox_list.set_item_metadata(index, "PLAYLIST|" + pl_name)
		index += 1
	# Unlocked tracks: filter by favorites if on, then sort
	var track_entries: Array[Dictionary] = []
	for saved_str in CampaignManager.unlocked_music_paths:
		var parts = saved_str.split("|")
		if parts.size() != 2:
			continue
		var t_name: String = parts[0]
		var path: String = parts[1]
		if _jukebox_favorites_only_cb != null and _jukebox_favorites_only_cb.button_pressed:
			if path not in CampaignManager.favorite_music_paths:
				continue
		track_entries.append({"name": t_name, "path": path})
	if _jukebox_track_sort_mode == JUKEBOX_SORT_ALPHA:
		track_entries.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)
	for entry in track_entries:
		var path: String = entry.path
		var t_name: String = entry.name
		var star: String = "★ " if path in CampaignManager.favorite_music_paths else ""
		jukebox_list.add_item("🎶 " + star + t_name)
		jukebox_list.set_item_metadata(index, path)
		index += 1
	_refresh_jukebox_playlist_option()
	_update_now_playing_ui()
	jukebox_panel.visible = true

func _create_jukebox_playlist_ui() -> void:
	if jukebox_panel == null or _jukebox_playlist_ui_created: return
	var row = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_TOP_LEFT)
	row.offset_left = 20.0
	row.offset_top = 95.0
	row.offset_right = 360.0
	row.offset_bottom = 130.0
	var mode_lbl = Label.new()
	mode_lbl.text = "Mode:"
	row.add_child(mode_lbl)
	_jukebox_mode_option = OptionButton.new()
	_jukebox_mode_option.add_item("Default", 0)
	_jukebox_mode_option.add_item("Loop track", 1)
	_jukebox_mode_option.add_item("Loop playlist", 2)
	_jukebox_mode_option.add_item("Shuffle playlist", 3)
	_jukebox_mode_option.item_selected.connect(_on_jukebox_mode_selected)
	row.add_child(_jukebox_mode_option)
	var pl_lbl = Label.new()
	pl_lbl.text = " Playlist:"
	row.add_child(pl_lbl)
	_jukebox_playlist_option = OptionButton.new()
	_jukebox_playlist_option.item_selected.connect(_on_jukebox_playlist_option_selected)
	row.add_child(_jukebox_playlist_option)
	_jukebox_new_playlist_btn = Button.new()
	_jukebox_new_playlist_btn.text = "New"
	_jukebox_new_playlist_btn.pressed.connect(_on_jukebox_new_playlist_pressed)
	row.add_child(_jukebox_new_playlist_btn)
	_jukebox_rename_playlist_btn = Button.new()
	_jukebox_rename_playlist_btn.text = "Rename"
	_jukebox_rename_playlist_btn.pressed.connect(_on_jukebox_rename_playlist_pressed)
	row.add_child(_jukebox_rename_playlist_btn)
	_jukebox_delete_playlist_btn = Button.new()
	_jukebox_delete_playlist_btn.text = "Delete"
	_jukebox_delete_playlist_btn.pressed.connect(_on_jukebox_delete_playlist_pressed)
	row.add_child(_jukebox_delete_playlist_btn)
	_jukebox_add_to_playlist_btn = Button.new()
	_jukebox_add_to_playlist_btn.text = "Add to playlist"
	_jukebox_add_to_playlist_btn.pressed.connect(_on_jukebox_add_to_playlist_pressed)
	row.add_child(_jukebox_add_to_playlist_btn)
	_jukebox_remove_from_playlist_btn = Button.new()
	_jukebox_remove_from_playlist_btn.text = "Remove from playlist"
	_jukebox_remove_from_playlist_btn.pressed.connect(_on_jukebox_remove_from_playlist_pressed)
	row.add_child(_jukebox_remove_from_playlist_btn)
	_jukebox_move_up_btn = Button.new()
	_jukebox_move_up_btn.text = "Move Up"
	_jukebox_move_up_btn.pressed.connect(_on_jukebox_move_up_pressed)
	row.add_child(_jukebox_move_up_btn)
	_jukebox_move_down_btn = Button.new()
	_jukebox_move_down_btn.text = "Move Down"
	_jukebox_move_down_btn.pressed.connect(_on_jukebox_move_down_pressed)
	row.add_child(_jukebox_move_down_btn)
	jukebox_panel.add_child(row)
	var row2 = HBoxContainer.new()
	row2.set_anchors_preset(Control.PRESET_TOP_LEFT)
	row2.offset_left = 20.0
	row2.offset_top = 132.0
	row2.offset_right = 380.0
	row2.offset_bottom = 165.0
	_jukebox_favorite_btn = Button.new()
	_jukebox_favorite_btn.text = "★ Favorite"
	_jukebox_favorite_btn.pressed.connect(_on_jukebox_favorite_pressed)
	row2.add_child(_jukebox_favorite_btn)
	_jukebox_favorites_only_cb = CheckButton.new()
	_jukebox_favorites_only_cb.text = "Favorites only"
	_jukebox_favorites_only_cb.toggled.connect(func(_on): _open_jukebox())
	row2.add_child(_jukebox_favorites_only_cb)
	var sort_lbl = Label.new()
	sort_lbl.text = " Sort:"
	row2.add_child(sort_lbl)
	_jukebox_track_sort_option = OptionButton.new()
	_jukebox_track_sort_option.add_item("Unlock order", 0)
	_jukebox_track_sort_option.add_item("A–Z", 1)
	_jukebox_track_sort_option.item_selected.connect(_on_jukebox_track_sort_selected)
	row2.add_child(_jukebox_track_sort_option)
	jukebox_panel.add_child(row2)
	_jukebox_playlist_popup = PopupMenu.new()
	_jukebox_playlist_popup.id_pressed.connect(_on_jukebox_add_to_playlist_id_pressed)
	jukebox_panel.add_child(_jukebox_playlist_popup)
	_jukebox_playlist_ui_created = true
	_sync_jukebox_mode_option()
	_sync_jukebox_sort_option()

func _refresh_jukebox_playlist_option() -> void:
	if _jukebox_playlist_option == null: return
	_jukebox_playlist_option.clear()
	_jukebox_playlist_names_ordered.clear()
	_jukebox_playlist_option.add_item("(None)", -1)
	for pl_name in _jukebox_sorted_playlist_names():
		_jukebox_playlist_names_ordered.append(pl_name)
		_jukebox_playlist_option.add_item(pl_name, _jukebox_playlist_names_ordered.size() - 1)

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
	pass

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

func _on_jukebox_add_to_playlist_pressed() -> void:
	var idx = jukebox_list.get_selected_items()
	if idx.is_empty(): return
	var meta = jukebox_list.get_item_metadata(idx[0])
	var path_str = str(meta)
	if path_str == "DEFAULT" or path_str.begins_with("PLAYLIST|"): return
	if not ResourceLoader.exists(path_str): return
	_jukebox_playlist_popup.clear()
	for i in _jukebox_playlist_names_ordered.size():
		_jukebox_playlist_popup.add_item(_jukebox_playlist_names_ordered[i], i)
	if _jukebox_playlist_popup.item_count == 0: return
	_jukebox_playlist_popup.set_meta("add_track_path", path_str)
	_jukebox_playlist_popup.popup(Rect2i(jukebox_panel.global_position + Vector2(20, 130), Vector2(180, 120)))

func _on_jukebox_remove_from_playlist_pressed() -> void:
	if _jukebox_playlist_option == null: return
	var sel_idx: int = _jukebox_playlist_option.selected
	var sel_id: int = _jukebox_playlist_option.get_item_id(sel_idx)
	if sel_id < 0 or sel_id >= _jukebox_playlist_names_ordered.size(): return
	var pl_name: String = _jukebox_playlist_names_ordered[sel_id]
	var idx = jukebox_list.get_selected_items()
	if idx.is_empty(): return
	var meta = jukebox_list.get_item_metadata(idx[0])
	var path_str = str(meta)
	if path_str == "DEFAULT" or path_str.begins_with("PLAYLIST|"): return
	var arr: Array = CampaignManager.saved_music_playlists.get(pl_name, [])
	arr.erase(path_str)
	CampaignManager.saved_music_playlists[pl_name] = arr
	if jukebox_active_playlist_name == pl_name:
		jukebox_active_playlist_tracks.clear()
		for a in arr:
			jukebox_active_playlist_tracks.append(str(a))
		if jukebox_playlist_index >= jukebox_active_playlist_tracks.size():
			jukebox_playlist_index = max(0, jukebox_active_playlist_tracks.size() - 1)
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
	var idx = jukebox_list.get_selected_items()
	if idx.is_empty(): return
	var meta = jukebox_list.get_item_metadata(idx[0])
	var path_str = str(meta)
	if path_str == "DEFAULT" or path_str.begins_with("PLAYLIST|"): return
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
	var idx = jukebox_list.get_selected_items()
	if idx.is_empty(): return
	var meta = jukebox_list.get_item_metadata(idx[0])
	var path_str = str(meta)
	if path_str == "DEFAULT" or path_str.begins_with("PLAYLIST|"): return
	if path_str in CampaignManager.favorite_music_paths:
		CampaignManager.favorite_music_paths.erase(path_str)
	else:
		CampaignManager.favorite_music_paths.append(path_str)
	_open_jukebox()

func _on_jukebox_track_sort_selected(idx: int) -> void:
	_jukebox_track_sort_mode = JUKEBOX_SORT_ALPHA if idx == 1 else JUKEBOX_SORT_UNLOCK
	_open_jukebox()

func _on_jukebox_add_to_playlist_id_pressed(id: int) -> void:
	var path_str: String = _jukebox_playlist_popup.get_meta("add_track_path", "")
	if path_str.is_empty(): return
	if id < 0 or id >= _jukebox_playlist_names_ordered.size(): return
	var pl_name: String = _jukebox_playlist_names_ordered[id]
	var arr: Array = CampaignManager.saved_music_playlists.get(pl_name, [])
	if path_str in arr:
		_jukebox_show_feedback("Already in playlist")
		return
	arr.append(path_str)
	CampaignManager.saved_music_playlists[pl_name] = arr

func _on_jukebox_track_selected(index: int) -> void:
	if select_sound: select_sound.play()
	var meta = jukebox_list.get_item_metadata(index)
	var track_name = jukebox_list.get_item_text(index)
	var meta_str = str(meta)
	if _jukebox_favorite_btn != null:
		if meta_str != "DEFAULT" and not meta_str.begins_with("PLAYLIST|"):
			_jukebox_favorite_btn.text = "☆ Unfavorite" if meta_str in CampaignManager.favorite_music_paths else "★ Favorite"
		else:
			_jukebox_favorite_btn.text = "★ Favorite"
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
		_update_now_playing_ui(track_name)

func _get_display_name_for_path(path: String) -> String:
	for saved_str in CampaignManager.unlocked_music_paths:
		var parts = saved_str.split("|")
		if parts.size() == 2 and parts[1] == path:
			return parts[0]
	return path.get_file().get_basename()

func _update_now_playing_ui(override_name: String = "") -> void:
	if jukebox_now_playing == null: return
	var mode_str: String = ""
	match jukebox_playback_mode:
		JUKEBOX_MODE_DEFAULT: mode_str = "Default"
		JUKEBOX_MODE_LOOP_TRACK: mode_str = "Loop track"
		JUKEBOX_MODE_LOOP_PLAYLIST: mode_str = "Loop playlist"
		JUKEBOX_MODE_SHUFFLE_PLAYLIST: mode_str = "Shuffle"
		_: mode_str = "Default"
	if override_name != "":
		jukebox_now_playing.text = "[center]Now Playing:\n[color=gold]" + override_name + "[/color]\n[color=gray]" + mode_str + "[/color][/center]"
		return
	if not jukebox_active_playlist_name.is_empty() and jukebox_active_playlist_tracks.size() > 0:
		var idx: int = jukebox_playlist_index
		if jukebox_playback_mode == JUKEBOX_MODE_SHUFFLE_PLAYLIST and idx < jukebox_shuffled_indices.size():
			idx = jukebox_shuffled_indices[idx]
		if idx < jukebox_active_playlist_tracks.size():
			var cur_path: String = jukebox_active_playlist_tracks[idx]
			var name_str: String = _get_display_name_for_path(cur_path)
			var one_based: int = jukebox_playlist_index + 1
			jukebox_now_playing.text = "[center]Now Playing:\n[color=gold]" + name_str + "[/color]\n[color=cyan]" + jukebox_active_playlist_name + "[/color] (" + str(one_based) + "/" + str(jukebox_active_playlist_tracks.size()) + ")\n[color=gray]" + mode_str + "[/color][/center]"
		else:
			jukebox_now_playing.text = "[center]Now Playing:\n[color=cyan]" + jukebox_active_playlist_name + "[/color]\n[color=gray]" + mode_str + "[/color][/center]"
		return
	if is_playing_custom_track and current_custom_track != null:
		var name_str: String = CampaignManager.jukebox_last_track_path.get_file().get_basename() if CampaignManager.jukebox_last_track_path != "" else "Custom Track"
		if CampaignManager.jukebox_last_track_path != "":
			name_str = _get_display_name_for_path(CampaignManager.jukebox_last_track_path)
		jukebox_now_playing.text = "[center]Now Playing:\n[color=gold]🎶 " + name_str + "[/color]\n[color=gray]" + mode_str + "[/color][/center]"
		return
	if camp_music.playing:
		jukebox_now_playing.text = "[center]Now Playing:\n[color=lime]⛺ Default Camp Ambiance[/color]\n[color=gray]" + mode_str + "[/color][/center]"
		return
	jukebox_now_playing.text = "[center]Now Playing:\n[color=gray]Stopped[/color]\n[color=gray]" + mode_str + "[/color][/center]"

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
	_update_now_playing_ui("⛺ Default Camp Ambiance")

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

func _crossfade_music(new_stream: AudioStream) -> void:
	var temp_player = AudioStreamPlayer.new()
	temp_player.stream = new_stream
	temp_player.volume_db = -40.0
	add_child(temp_player)
	temp_player.play()
	var t = create_tween().set_parallel(true)
	t.tween_property(camp_music, "volume_db", -40.0, 2.0).set_trans(Tween.TRANS_SINE)
	t.tween_property(temp_player, "volume_db", user_music_volume, 2.0).set_trans(Tween.TRANS_SINE)
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

	var unlocked := CampaignManager.max_unlocked_index >= 2
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
