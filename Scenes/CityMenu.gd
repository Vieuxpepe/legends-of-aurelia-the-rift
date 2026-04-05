extends Control
const AUCTION_LISTING_DATA_SCRIPT: GDScript = preload("res://Scripts/UI/Auction/AuctionListingData.gd")
const AUCTION_UUID = preload("res://addons/silent_wolf/utils/UUID.gd")
const AUCTION_LISTINGS_DOCUMENT_FALLBACK: String = "auction_house_listings_v1"
const AUCTION_SETTLEMENT_LOCK_SECONDS: int = 20
const AUCTION_NOTIFICATION_HISTORY_MAX: int = 8
const AUCTION_SHARED_CACHE_PATH: String = "user://auction_house_shared_cache_v1.json"
const CampUiSkin = preload("res://Scripts/UI/CampUiSkin.gd")
## Full black scrim — anything less and the city still reads through the blend.
const ARENA_EPIC_DIMMER_BASE := Color(0, 0, 0, 1)

# CityMenu.gd – Arena 2.0 (Juiced, Ranked, & Token Shop)
@onready var back_button: Button = $BackButton
@onready var auction_house_button: Button = get_node_or_null("AuctionHouseButton")
@onready var auction_panel: Panel = get_node_or_null("AuctionPanel")
@onready var auction_close_button: Button = get_node_or_null("AuctionPanel/CloseAuctionButton")
@onready var auction_refresh_button: Button = get_node_or_null("AuctionPanel/RefreshButton")
@onready var auction_status_label: Label = get_node_or_null("AuctionPanel/StatusLabel")
@onready var auction_my_gold_label: Label = get_node_or_null("AuctionPanel/MyGoldLabel")
@onready var auction_market_badge_label: RichTextLabel = get_node_or_null("AuctionPanel/MarketBadgeLabel")
@onready var auction_search_input: LineEdit = get_node_or_null("AuctionPanel/SearchInput")
@onready var auction_status_filter_option: OptionButton = get_node_or_null("AuctionPanel/StatusFilterOption")
@onready var auction_sort_option: OptionButton = get_node_or_null("AuctionPanel/SortOption")
@onready var auction_clear_filters_button: Button = get_node_or_null("AuctionPanel/ClearFiltersButton")
@onready var auction_listings_container: VBoxContainer = get_node_or_null("AuctionPanel/ListingsScroll/ListingsContainer")
@onready var auction_selected_listing_label: RichTextLabel = get_node_or_null("AuctionPanel/SelectedListingLabel")
@onready var auction_selected_listing_icon: TextureRect = get_node_or_null("AuctionPanel/SelectedListingIconFrame/SelectedListingIcon")
@onready var auction_bid_input: LineEdit = get_node_or_null("AuctionPanel/BidInput")
@onready var auction_place_bid_button: Button = get_node_or_null("AuctionPanel/PlaceBidButton")
@onready var auction_notifications_label: RichTextLabel = get_node_or_null("AuctionPanel/NotificationsLabel")
@onready var auction_my_item_option: OptionButton = get_node_or_null("AuctionPanel/MyItemOption")
@onready var auction_listing_start_bid_input: LineEdit = get_node_or_null("AuctionPanel/ListingStartBidInput")
@onready var auction_listing_min_inc_input: LineEdit = get_node_or_null("AuctionPanel/ListingMinIncInput")
@onready var auction_create_listing_button: Button = get_node_or_null("AuctionPanel/CreateListingButton")
@onready var auction_listing_draft_panel: Panel = get_node_or_null("AuctionPanel/ListingDraftPanel")
@onready var auction_listing_draft_item_option: OptionButton = get_node_or_null("AuctionPanel/ListingDraftPanel/DraftItemOption")
@onready var auction_listing_draft_title: Label = get_node_or_null("AuctionPanel/ListingDraftPanel/DraftTitle")
@onready var auction_listing_draft_uid: Label = get_node_or_null("AuctionPanel/ListingDraftPanel/DraftUid")
@onready var auction_listing_draft_icon: TextureRect = get_node_or_null("AuctionPanel/ListingDraftPanel/DraftIconFrame/DraftIcon")
@onready var auction_listing_draft_details: RichTextLabel = get_node_or_null("AuctionPanel/ListingDraftPanel/DraftDetailsPanel/DraftDetailsScroll/DraftDetails")
@onready var auction_listing_draft_start_bid_input: LineEdit = get_node_or_null("AuctionPanel/ListingDraftPanel/DraftStartBidInput")
@onready var auction_listing_draft_min_inc_input: LineEdit = get_node_or_null("AuctionPanel/ListingDraftPanel/DraftMinIncInput")
@onready var auction_listing_draft_cancel_button: Button = get_node_or_null("AuctionPanel/ListingDraftPanel/DraftCancelButton")
@onready var auction_listing_draft_confirm_button: Button = get_node_or_null("AuctionPanel/ListingDraftPanel/DraftConfirmButton")

@onready var shop_desc_label: RichTextLabel = $TokenShopPanel/ShopDescription
@onready var shop_item_preview: TextureRect = $TokenShopPanel/ShopItemPreview

# --- Scavenger Network References ---
@onready var scavenger_button: Button = get_node_or_null("ScavengerButton")
@onready var scavenger_ui: Control = get_node_or_null("ScavengerUI")

# --- Roadmap References ---
@onready var roadmap_bar: ProgressBar = $TokenShopPanel/RankRoadmap/RoadmapBar
@onready var markers_container: HBoxContainer = $TokenShopPanel/RankRoadmap/MarkersContainer

# --- Token Shop References ---
@onready var token_shop_panel: Panel = $TokenShopPanel
@onready var open_shop_btn: Button = $OpenShopButton
@onready var close_shop_btn: Button = $TokenShopPanel/CloseShopButton
@onready var shop_token_display: Label = $TokenShopPanel/ShopTokenDisplay
@onready var shop_items_grid: GridContainer = $TokenShopPanel/ShopItemsGrid

# --- Audio References ---
@onready var city_bgm: AudioStreamPlayer = get_node_or_null("%CityMusic")
@onready var arena_bgm: AudioStreamPlayer = get_node_or_null("%ArenaMusic")
@onready var shop_bgm: AudioStreamPlayer = get_node_or_null("%ShopMusic")

# Shop NPC & Feedback
@onready var gladiator_portrait: TextureRect = $TokenShopPanel/GladiatorPortrait
@onready var gladiator_label: Label = $TokenShopPanel/GladiatorDialogue
@onready var token_buy_sound: AudioStreamPlayer = $TokenShopPanel/BuySound
@onready var gladiator_blip: AudioStreamPlayer = $TokenShopPanel/TextBlipSound
@onready var select_sound: AudioStreamPlayer = $TokenShopPanel/SelectSound

# Shop Description Panel
@onready var item_stats_label: RichTextLabel = $TokenShopPanel/ItemDescriptionPanel/ItemStatsLabel
@onready var large_item_preview: TextureRect = $TokenShopPanel/ItemDescriptionPanel/LargeItemPreview
@onready var token_purchase_btn: Button = $TokenShopPanel/TokenPurchaseButton

@export var token_shop_items: Array[Resource] = []
@export_group("Auction House")
@export var auction_use_default_if_empty: bool = true
@export var auction_listings_document_name: String = "auction_house_listings_v1"
@export var auction_leaderboard_name: String = "city_live_auction_v1"
@export_range(3.0, 60.0, 1.0) var auction_refresh_seconds: float = 8.0
@export_range(1, 168, 1) var auction_listing_duration_hours: int = 72
@export var auction_listings: Array[Resource] = []
var highlighted_item: Resource = null
var gladiator_tween: Tween
var _auction_selected_listing_id: String = ""
var _auction_highest_by_listing: Dictionary = {}
var _auction_fetch_in_flight: bool = false
var _auction_bid_in_flight: bool = false
var _auction_listing_in_flight: bool = false
var _auction_refresh_queued: bool = false
var _auction_poll_timer: Timer = null
var _auction_cloud_listings_by_id: Dictionary = {}
var _auction_notifications: Array[String] = []
var _auction_theme_applied: bool = false
var _auction_icon_lookup_by_title: Dictionary = {}
var _auction_icon_lookup_built: bool = false
var _auction_row_icon_by_listing: Dictionary = {}
var _auction_search_query: String = ""
var _auction_status_filter_index: int = 0
var _auction_sort_mode_index: int = 0

const AUCTION_ICON_SCAN_DIRS: Array[String] = [
	"res://Resources/Materials/",
	"res://Resources/Materials/GeneratedMaterials/",
	"res://Resources/GeneratedItems/",
	"res://Resources/Weapons/",
	"res://Resources/Consumables/"
]

const AUCTION_THEME_PANEL_BG := Color(0.13, 0.10, 0.07, 0.93)
const AUCTION_THEME_PANEL_BG_ALT := Color(0.17, 0.12, 0.08, 0.96)
const AUCTION_THEME_SURFACE := Color(0.09, 0.07, 0.05, 0.94)
const AUCTION_THEME_BORDER := Color(0.88, 0.72, 0.31, 0.90)
const AUCTION_THEME_BORDER_SOFT := Color(0.74, 0.56, 0.22, 0.72)
const AUCTION_THEME_TEXT := Color(0.94, 0.92, 0.86, 1.0)
const AUCTION_THEME_MUTED := Color(0.66, 0.70, 0.76, 1.0)
const AUCTION_THEME_ACCENT := Color(0.52, 0.90, 1.0, 1.0)
const AUCTION_THEME_GOOD := Color(0.58, 0.92, 0.56, 1.0)
const AUCTION_THEME_WARN := Color(1.0, 0.76, 0.42, 1.0)
const AUCTION_THEME_DANGER := Color(0.99, 0.47, 0.44, 1.0)

# The exact payouts for reaching each rank index
var rank_reward_payouts = [
	{"tokens": 0, "text": "Starting Rank"},       # 0 - Bronze
	{"tokens": 25, "text": "25 Tokens"},          # 1 - Silver
	{"tokens": 50, "text": "50 Tokens"},          # 2 - Gold
	{"tokens": 100, "text": "100 Tokens"},        # 3 - Platinum
	{"tokens": 250, "text": "250 Tokens"},        # 4 - Diamond
	{"tokens": 500, "text": "500 Tokens"}         # 5 - Grandmaster
]

const DEFAULT_AUCTION_LISTINGS: Array[Dictionary] = [
	{
		"listing_id": "war_table_relic_blade",
		"title": "War-Table Relic Blade",
		"summary": "A battle-forged relic with unstable runes. Highest verified bid secures extraction rights this cycle.",
		"starting_bid": 450,
		"min_increment": 25,
		"end_timestamp_unix": 0
	},
	{
		"listing_id": "sunken_vault_map",
		"title": "Sunken Vault Cartography Set",
		"summary": "Survey bundle rumored to point toward submerged chapter vaults and sealed convoy routes.",
		"starting_bid": 320,
		"min_increment": 20,
		"end_timestamp_unix": 0
	},
	{
		"listing_id": "dragon_harness_proto",
		"title": "Dragon Harness Prototype",
		"summary": "Experimental riding rig assembled by outlaw smiths. Untested under raid pressure.",
		"starting_bid": 900,
		"min_increment": 50,
		"end_timestamp_unix": 0
	}
]

var gladiator_lines = {
	"welcome": [
		"Blood, sweat, and tokens. What are you buying, Champion?",
		"The Arena demands a show, but my shop demands tokens.",
		"Only the finest gear for those who survive the sands.",
		"Step up. Don't bleed on the merchandise."
	],
	"buy": [
		"A worthy choice. May it taste the blood of your enemies.",
		"Hah! I knew you had your eye on that one.",
		"Sold! Try not to break it in the first round.",
		"A fine weapon for a brutal arena."
	],
	"poor": [
		"You lack the tokens, Champion. Go win some matches.",
		"This isn't a charity. Return when you have the currency of victors.",
		"Your purse is as empty as a rookie's threat.",
		"I don't take promises. I take Gladiator Tokens."
	]
}

# --- Matchmaking Lobby References ---
@onready var arena_button: Button = $ArenaButton
@onready var arena_panel: Control = $ArenaPanel
@onready var close_arena_button: Button = $ArenaPanel/CloseArenaButton
@onready var refresh_matches_button: Button = $ArenaPanel/RefreshMatchesButton
@onready var opponent_container: VBoxContainer = $ArenaPanel/ScrollContainer/OpponentContainer
@onready var status_label: Label = $ArenaPanel/StatusLabel

@onready var token_display: Label = $ArenaSetupPanel/TokenDisplayLabel # Adjust path if needed
@onready var leaderboard_btn: Button = $ArenaPanel/LeaderboardButton
@onready var leaderboard_panel: Panel = $ArenaPanel/LeaderboardPanel
@onready var leaderboard_container: VBoxContainer = $ArenaPanel/LeaderboardPanel/ScrollContainer/LeaderboardContainer
@onready var close_leaderboard_btn: Button = $ArenaPanel/LeaderboardPanel/CloseButton

@onready var ghost_inspect_panel: Panel = $ArenaPanel/LeaderboardPanel/GhostInspectPanel
@onready var ghost_team_grid: GridContainer = $ArenaPanel/LeaderboardPanel/GhostInspectPanel/GhostTeamGrid
@onready var ghost_title: Label = $ArenaPanel/LeaderboardPanel/GhostInspectPanel/GhostTitle
@onready var arena_opponent_scroll: ScrollContainer = $ArenaPanel/ScrollContainer
@onready var leaderboard_scroll: ScrollContainer = $ArenaPanel/LeaderboardPanel/ScrollContainer

# --- Team Setup References ---
@onready var arena_setup_panel: Control = $ArenaSetupPanel
@onready var arena_setup_title_label: Label = $ArenaSetupPanel/TitleLabel
@onready var roster_grid: GridContainer = $ArenaSetupPanel/RosterGrid
@onready var team_grid: GridContainer = $ArenaSetupPanel/TeamGrid
@onready var confirm_team_btn: Button = $ArenaSetupPanel/ConfirmTeamButton
@onready var close_setup_btn: Button = $ArenaSetupPanel/CloseSetupButton

var _arena_setup_instruction_label: Label = null
var _arena_setup_identity_label: Label = null
var _arena_setup_lock_banner: Label = null
var _unit_info_hover_timer: Timer
var _arena_opp_confirm_panel: Panel = null
var _arena_opp_confirm_richtext: RichTextLabel = null
var _arena_opp_confirm_pending: Dictionary = {}

# --- Unit Info Panel References ---
@onready var unit_info_panel: Control = $UnitInfoPanel
@onready var info_portrait: TextureRect = $UnitInfoPanel/MarginContainer/VBox/PortraitRect
@onready var info_name: Label = $UnitInfoPanel/MarginContainer/VBox/NameLabel
@onready var info_class: Label = $UnitInfoPanel/MarginContainer/VBox/ClassLabel
@onready var info_level: Label = $UnitInfoPanel/MarginContainer/VBox/LevelLabel
@onready var info_hp: Label = $UnitInfoPanel/MarginContainer/VBox/HPLabel
@onready var info_stats: Label = $UnitInfoPanel/MarginContainer/VBox/StatsLabel
@onready var info_weapon: Label = $UnitInfoPanel/MarginContainer/VBox/WeaponLabel

# --- Defence Rewards Popup (Standard) ---
@onready var defense_popup: Panel = $DefensePopup
@onready var defense_label: Label = $DefensePopup/Panel/Label
@onready var defense_ok_button: Button = $DefensePopup/Panel/OkButton

# ==========================================
# --- RANKED RESULTS UI ---
# ==========================================
@onready var arena_result_panel: Panel = $ArenaResultSequence/Panel
@onready var arena_result_flash: ColorRect = $ArenaResultSequence/FlashRect
@onready var arena_result_sequence: Control = $ArenaResultSequence
@onready var arena_result_title: Label = $ArenaResultSequence/Panel/TitleLabel
@onready var arena_result_rank_icon: TextureRect = $ArenaResultSequence/Panel/RankIcon
@onready var arena_result_rank_name: Label = $ArenaResultSequence/Panel/RankNameLabel
@onready var arena_result_rating_label: Label = $ArenaResultSequence/Panel/RatingLabel
@onready var arena_result_delta_label: Label = $ArenaResultSequence/Panel/MMRDeltaLabel
@onready var arena_result_bar: ProgressBar = $ArenaResultSequence/Panel/RankBar
@onready var arena_result_bar_value: Label = $ArenaResultSequence/Panel/RankBarValue
@onready var arena_result_stamp: Label = $ArenaResultSequence/Panel/StampLabel
@onready var arena_result_rewards: RichTextLabel = $ArenaResultSequence/Panel/RewardsLabel
@onready var arena_result_burst: CPUParticles2D = $ArenaResultSequence/BurstParticles
@onready var arena_result_dimmer: ColorRect = $ArenaResultSequence/Dimmer
@onready var arena_result_epic_spark: CPUParticles2D = $ArenaResultSequence/EpicSparkBurst

@onready var streak_badge: Control = $GladiatorStreakBadge
@onready var streak_label: Label = $GladiatorStreakBadge/Label
@onready var streak_sub_label: Label = $GladiatorStreakBadge/SubLabel
@onready var streak_flame_particles: CPUParticles2D = $GladiatorStreakBadge/FlameParticles

var selected_team: Array = []
var rank_hierarchy: Array[String] = ["Bronze", "Silver", "Gold", "Platinum", "Diamond", "Grandmaster"]
var _arena_result_panel_rest_pos: Vector2 = Vector2.ZERO
var _arena_stamp_offset_top_default: float = -155.0

@onready var tavern_button: Button = $TavernButton

# ==========================================
# --- INITIALIZATION ---
# ==========================================

func _ready() -> void:
	if city_bgm != null:
		city_bgm.bus = "Music"
	if arena_bgm != null:
		arena_bgm.bus = "Music"
	if shop_bgm != null:
		shop_bgm.bus = "Music"
	if token_buy_sound != null:
		token_buy_sound.bus = "SFX"
	if gladiator_blip != null:
		gladiator_blip.bus = "SFX"
	if select_sound != null:
		select_sound.bus = "SFX"
	if back_button: back_button.pressed.connect(_on_back_pressed)
	if arena_button: arena_button.pressed.connect(_open_setup_panel)
	if close_arena_button: close_arena_button.pressed.connect(_close_arena)
	if refresh_matches_button: refresh_matches_button.pressed.connect(_fetch_matches)
	if confirm_team_btn: confirm_team_btn.pressed.connect(_lock_team_and_search)
	if close_setup_btn: close_setup_btn.pressed.connect(_close_arena)
	if leaderboard_btn: leaderboard_btn.pressed.connect(_show_leaderboard)
	if close_leaderboard_btn:
		close_leaderboard_btn.pressed.connect(func():
			leaderboard_panel.hide()
			_hide_unit_info_panel_immediate()
		)
	if auction_house_button: auction_house_button.pressed.connect(_open_auction_house)
	if auction_close_button: auction_close_button.pressed.connect(_close_auction_house)
	if auction_refresh_button: auction_refresh_button.pressed.connect(_refresh_auction_house_async)
	if auction_place_bid_button: auction_place_bid_button.pressed.connect(_on_auction_place_bid_pressed)
	if auction_bid_input: auction_bid_input.text_submitted.connect(_on_auction_bid_text_submitted)
	if auction_search_input: auction_search_input.text_changed.connect(_on_auction_search_text_changed)
	if auction_status_filter_option: auction_status_filter_option.item_selected.connect(_on_auction_status_filter_selected)
	if auction_sort_option: auction_sort_option.item_selected.connect(_on_auction_sort_selected)
	if auction_clear_filters_button: auction_clear_filters_button.pressed.connect(_on_auction_clear_filters_pressed)
	if auction_create_listing_button: auction_create_listing_button.pressed.connect(_on_auction_create_listing_pressed)
	if auction_listing_draft_cancel_button: auction_listing_draft_cancel_button.pressed.connect(_close_auction_listing_draft)
	if auction_listing_draft_confirm_button: auction_listing_draft_confirm_button.pressed.connect(_on_auction_confirm_listing_pressed)
	if auction_listing_draft_item_option: auction_listing_draft_item_option.item_selected.connect(_on_auction_listing_draft_item_selected)
	# --- SMOOTH MUSIC START ---
	if city_bgm and not city_bgm.playing:
		city_bgm.volume_db = 0.0
		city_bgm.play()
	if arena_bgm: 
		arena_bgm.stop()
	if shop_bgm:
		shop_bgm.stop()
	open_shop_btn.pressed.connect(_open_token_shop)
	close_shop_btn.pressed.connect(_close_token_shop)
	token_purchase_btn.pressed.connect(_on_token_purchase_pressed)
	if tavern_button: tavern_button.pressed.connect(_open_tavern)
	if scavenger_button: scavenger_button.pressed.connect(_open_scavenger_network)
	if arena_panel: arena_panel.hide()
	if arena_setup_panel: arena_setup_panel.hide()
	if auction_panel: auction_panel.hide()
	if auction_listing_draft_panel: auction_listing_draft_panel.hide()
	if unit_info_panel: unit_info_panel.hide()
	if defense_popup: defense_popup.hide()
	if arena_result_sequence: arena_result_sequence.hide()
	if arena_result_stamp:
		_arena_stamp_offset_top_default = arena_result_stamp.offset_top
	if ghost_inspect_panel: ghost_inspect_panel.hide()
	
	$ArenaPanel/LeaderboardPanel/GhostInspectPanel/CloseButton.pressed.connect(func():
		ghost_inspect_panel.hide()
		_hide_unit_info_panel_immediate()
	)
	
	ArenaManager.current_opponent_data = {}
	ArenaManager.restore_local_arena_team_from_saved_identity()
	
	_configure_arena_ui_fx()
	_apply_enter_arena_ui_theme()
	_refresh_gladiator_badge()
	_ensure_auction_listings()
	_setup_auction_filter_controls()
	_refresh_auction_my_item_options()
	_setup_auction_poll_timer()
	_refresh_auction_notifications_view()
	_apply_auction_ui_theme()
	_refresh_auction_control_state()

	if ArenaManager.last_match_result != "":
		# The player just finished a match! Clear the shop so it rerolls next time they open it.
		CampaignManager.active_shop_inventory.clear()
		await _play_arena_result_sequence()
		ArenaManager.last_match_result = ""
	
	call_deferred("_check_offline_rewards")

	_unit_info_hover_timer = Timer.new()
	_unit_info_hover_timer.wait_time = 0.14
	_unit_info_hover_timer.one_shot = true
	_unit_info_hover_timer.timeout.connect(_on_unit_info_hover_timer_timeout)
	add_child(_unit_info_hover_timer)
	if arena_setup_panel:
		arena_setup_panel.mouse_exited.connect(_schedule_unit_info_hide)
	if unit_info_panel:
		unit_info_panel.mouse_entered.connect(_cancel_unit_info_hide)
		unit_info_panel.mouse_exited.connect(_schedule_unit_info_hide)
	if ghost_inspect_panel:
		ghost_inspect_panel.mouse_exited.connect(_schedule_unit_info_hide)


func _on_unit_info_hover_timer_timeout() -> void:
	if unit_info_panel:
		unit_info_panel.hide()


func _cancel_unit_info_hide() -> void:
	if _unit_info_hover_timer and not _unit_info_hover_timer.is_stopped():
		_unit_info_hover_timer.stop()


func _schedule_unit_info_hide() -> void:
	if unit_info_panel == null or not unit_info_panel.visible:
		return
	if _unit_info_hover_timer:
		_unit_info_hover_timer.start()


func _hide_unit_info_panel_immediate() -> void:
	_cancel_unit_info_hide()
	if unit_info_panel:
		unit_info_panel.hide()


func _arena_setup_punch_button(btn: Button) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	if btn.size.x < 2.0 or btn.size.y < 2.0:
		call_deferred("_arena_setup_punch_button", btn)
		return
	btn.pivot_offset = btn.size * 0.5
	var tw: Tween = create_tween()
	tw.tween_property(btn, "scale", Vector2(1.11, 1.11), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _arena_setup_animate_team_slot_by_index(slot_index: int) -> void:
	if team_grid == null:
		return
	if slot_index < 0 or slot_index >= team_grid.get_child_count():
		return
	var b: Button = team_grid.get_child(slot_index) as Button
	if b and not b.disabled:
		_arena_setup_punch_button(b)


func _configure_arena_ui_fx() -> void:
	if arena_result_bar:
		arena_result_bar.min_value = 0.0
		arena_result_bar.max_value = 100.0
	if arena_result_flash:
		arena_result_flash.z_index = 2
	if arena_result_burst:
		arena_result_burst.z_index = 3
	if arena_result_epic_spark:
		arena_result_epic_spark.z_index = 3


func _apply_enter_arena_ui_theme() -> void:
	if arena_panel == null:
		return
	CampUiSkin.style_panel_surface(arena_panel, CampUiSkin.CAMP_PANEL_BG, CampUiSkin.CAMP_BORDER, 24, 12)
	if arena_setup_panel:
		CampUiSkin.style_panel_surface(arena_setup_panel, CampUiSkin.CAMP_PANEL_BG, CampUiSkin.CAMP_BORDER, 22, 10)
	if leaderboard_panel:
		CampUiSkin.style_panel_surface(leaderboard_panel, CampUiSkin.CAMP_PANEL_BG_ALT, CampUiSkin.CAMP_BORDER_SOFT, 20, 8)
	if ghost_inspect_panel:
		CampUiSkin.style_panel_surface(ghost_inspect_panel, CampUiSkin.CAMP_PANEL_BG_SOFT, CampUiSkin.CAMP_BORDER_SOFT, 16, 4)

	if arena_opponent_scroll:
		var opp_scroll_style := CampUiSkin.make_panel_style(CampUiSkin.CAMP_PANEL_BG_SOFT, CampUiSkin.CAMP_BORDER_SOFT, 14, 4)
		opp_scroll_style.content_margin_top = 14
		opp_scroll_style.content_margin_left = 12
		opp_scroll_style.content_margin_right = 12
		opp_scroll_style.content_margin_bottom = 18
		arena_opponent_scroll.add_theme_stylebox_override("panel", opp_scroll_style)
	if opponent_container:
		opponent_container.add_theme_constant_override("separation", 14)
	if leaderboard_scroll:
		leaderboard_scroll.add_theme_stylebox_override(
			"panel",
			CampUiSkin.make_panel_style(CampUiSkin.CAMP_PANEL_BG_SOFT, CampUiSkin.CAMP_BORDER_SOFT, 12, 2)
		)

	var arena_title: Label = arena_panel.get_node_or_null("TitleLabel") as Label
	if arena_title:
		CampUiSkin.style_label(arena_title, CampUiSkin.CAMP_TEXT, 26, 2)
		arena_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if status_label:
		CampUiSkin.style_label(status_label, CampUiSkin.CAMP_MUTED, 15, 1)
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if arena_setup_title_label:
		CampUiSkin.style_label(arena_setup_title_label, CampUiSkin.CAMP_ACCENT_CYAN, 21, 1)
		arena_setup_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if token_display:
		CampUiSkin.style_label(token_display, CampUiSkin.CAMP_ACTION_PRIMARY.lightened(0.12), 16, 0)
		token_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ghost_title:
		CampUiSkin.style_label(ghost_title, CampUiSkin.CAMP_TEXT, 17, 1)
	if leaderboard_panel:
		var leaderboard_title: Label = leaderboard_panel.get_node_or_null("LeaderboardTitle") as Label
		if leaderboard_title:
			CampUiSkin.style_label(leaderboard_title, CampUiSkin.CAMP_ACCENT_CYAN, 22, 2)

	CampUiSkin.style_button(arena_button, false, 20, 48)
	CampUiSkin.style_button(close_arena_button, false, 17, 40)
	if close_arena_button:
		close_arena_button.custom_minimum_size = Vector2(44, 44)
	CampUiSkin.style_button(refresh_matches_button, true, 17, 48)
	CampUiSkin.style_button(leaderboard_btn, false, 16, 44)
	CampUiSkin.style_button(close_leaderboard_btn, false, 17, 44)
	CampUiSkin.style_button(confirm_team_btn, true, 18, 52)
	CampUiSkin.style_button(close_setup_btn, false, 16, 48)
	if confirm_team_btn:
		confirm_team_btn.add_theme_constant_override("outline_size", 1)
	if close_setup_btn:
		close_setup_btn.add_theme_constant_override("outline_size", 1)
	var ghost_close: Button = get_node_or_null("ArenaPanel/LeaderboardPanel/GhostInspectPanel/CloseButton") as Button
	if ghost_close:
		CampUiSkin.style_button(ghost_close, false, 16, 36)
		ghost_close.custom_minimum_size = Vector2(36, 36)

	_apply_unit_info_panel_theme()

	_layout_arena_setup_feedback_nodes()


func _apply_unit_info_panel_theme() -> void:
	if unit_info_panel == null:
		return
	CampUiSkin.style_panel_surface(unit_info_panel, CampUiSkin.CAMP_PANEL_BG_ALT, CampUiSkin.CAMP_BORDER_SOFT, 18, 6)
	if info_name:
		CampUiSkin.style_label(info_name, CampUiSkin.CAMP_ACCENT_CYAN, 17, 0)
	if info_class:
		CampUiSkin.style_label(info_class, CampUiSkin.CAMP_MUTED, 14, 0)
	if info_level:
		CampUiSkin.style_label(info_level, CampUiSkin.CAMP_TEXT, 14, 0)
	if info_hp:
		CampUiSkin.style_label(info_hp, CampUiSkin.CAMP_TEXT, 14, 0)
	if info_stats:
		CampUiSkin.style_label(info_stats, CampUiSkin.CAMP_TEXT, 14, 0)
	if info_weapon:
		CampUiSkin.style_label(info_weapon, CampUiSkin.CAMP_MUTED, 13, 0)


func _arena_epic_play_blip(won: bool, bright: bool = true) -> void:
	if gladiator_blip == null:
		return
	gladiator_blip.pitch_scale = randf_range(1.65, 2.15) if (won and bright) else randf_range(0.82, 1.12)
	gladiator_blip.play()


func _arena_epic_prime_for_reveal() -> void:
	if arena_result_title != null:
		arena_result_title.modulate.a = 0.0
		arena_result_title.scale = Vector2(0.82, 0.82)
	if arena_result_rank_icon != null:
		arena_result_rank_icon.modulate.a = 0.0
		arena_result_rank_icon.scale = Vector2(0.28, 0.28)
	if arena_result_rank_name != null:
		arena_result_rank_name.modulate.a = 0.0
		arena_result_rank_name.scale = Vector2(0.92, 0.92)
	if arena_result_rating_label != null:
		arena_result_rating_label.modulate.a = 0.0
	if arena_result_delta_label != null:
		arena_result_delta_label.modulate.a = 0.0
	if arena_result_bar != null:
		arena_result_bar.modulate.a = 0.0
	if arena_result_bar_value != null:
		arena_result_bar_value.modulate.a = 0.0


func _arena_epic_stagger_reveal_header(won: bool) -> void:
	await get_tree().process_frame
	if arena_result_title != null:
		arena_result_title.pivot_offset = Vector2(arena_result_title.size.x * 0.5, arena_result_title.size.y * 0.5)
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(arena_result_title, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
		tw.tween_property(arena_result_title, "scale", Vector2.ONE, 0.52).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		await tw.finished
		_arena_epic_play_blip(won, true)
		await get_tree().create_timer(0.05).timeout

	if arena_result_rank_icon != null:
		arena_result_rank_icon.pivot_offset = arena_result_rank_icon.size * 0.5
		var tw2: Tween = create_tween().set_parallel(true)
		tw2.tween_property(arena_result_rank_icon, "modulate:a", 1.0, 0.22)
		tw2.tween_property(arena_result_rank_icon, "scale", Vector2.ONE, 0.58).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw2.finished
		_arena_epic_play_blip(won, true)
		await get_tree().create_timer(0.05).timeout

	if arena_result_rank_name != null:
		arena_result_rank_name.pivot_offset = Vector2(arena_result_rank_name.size.x * 0.5, arena_result_rank_name.size.y * 0.5)
		var tw3: Tween = create_tween().set_parallel(true)
		tw3.tween_property(arena_result_rank_name, "modulate:a", 1.0, 0.22)
		tw3.tween_property(arena_result_rank_name, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw3.finished
		_arena_epic_play_blip(won, not won)
		await get_tree().create_timer(0.06).timeout

	if arena_result_rating_label != null and arena_result_delta_label != null:
		var tw4: Tween = create_tween().set_parallel(true)
		tw4.tween_property(arena_result_rating_label, "modulate:a", 1.0, 0.26)
		tw4.tween_property(arena_result_delta_label, "modulate:a", 1.0, 0.26)
		await tw4.finished
		_arena_epic_play_blip(won, won)
		await get_tree().create_timer(0.05).timeout

	if arena_result_bar != null and arena_result_bar_value != null:
		var tw5: Tween = create_tween().set_parallel(true)
		tw5.tween_property(arena_result_bar, "modulate:a", 1.0, 0.3)
		tw5.tween_property(arena_result_bar_value, "modulate:a", 1.0, 0.3)
		await tw5.finished
		if select_sound != null:
			select_sound.pitch_scale = 1.05 if won else 0.92
			select_sound.play()


func _arena_epic_anticipation_flash() -> void:
	if arena_result_flash == null:
		return
	arena_result_flash.color = Color(1.0, 0.93, 0.72, 1.0)
	arena_result_flash.show()
	arena_result_flash.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(arena_result_flash, "modulate:a", 0.12, 0.07)
	tw.tween_property(arena_result_flash, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD)
	await tw.finished
	arena_result_flash.hide()


func _arena_epic_reveal_spoils_finale(won: bool) -> void:
	if arena_result_rewards == null:
		return
	await get_tree().process_frame
	arena_result_rewards.pivot_offset = Vector2(arena_result_rewards.size.x * 0.5, arena_result_rewards.size.y * 0.5)
	arena_result_rewards.scale = Vector2(0.9, 0.9)
	arena_result_rewards.modulate.a = 0.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(arena_result_rewards, "modulate:a", 1.0, (0.45 if won else 0.55)).set_trans(Tween.TRANS_SINE)
	tw.tween_property(arena_result_rewards, "scale", Vector2.ONE, 0.52).set_trans(Tween.TRANS_ELASTIC if won else Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if won and token_buy_sound != null:
		token_buy_sound.pitch_scale = 1.12
		token_buy_sound.play()
	elif not won and gladiator_blip != null:
		gladiator_blip.pitch_scale = 0.78
		gladiator_blip.play()
	await tw.finished
	if won and arena_result_flash != null:
		arena_result_flash.color = CampUiSkin.CAMP_BORDER.lerp(Color(1, 1, 1, 1), 0.4)
		arena_result_flash.show()
		arena_result_flash.modulate.a = 0.0
		var gl: Tween = create_tween()
		gl.tween_property(arena_result_flash, "modulate:a", 0.1, 0.06)
		gl.tween_property(arena_result_flash, "modulate:a", 0.0, 0.25)
		await gl.finished
		arena_result_flash.hide()
	await get_tree().create_timer(0.14 if won else 0.22).timeout


func _arena_epic_dimmer_pulse_rank(rank_color: Color) -> void:
	if arena_result_dimmer == null:
		return
	# Brief lift from pure black so the tier-colored pulse still reads.
	var warm: Color = rank_color.lerp(Color(0.2, 0.14, 0.09, 1.0), 0.52)
	var tw: Tween = create_tween()
	tw.tween_property(arena_result_dimmer, "color", warm, 0.11).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(arena_result_dimmer, "color", ARENA_EPIC_DIMMER_BASE, 0.72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _configure_epic_spark_burst(accent: Color) -> void:
	if arena_result_epic_spark == null:
		return
	var p: CPUParticles2D = arena_result_epic_spark
	p.emitting = false
	p.one_shot = true
	p.amount = 150
	p.lifetime = 1.4
	p.explosiveness = 0.9
	p.direction = Vector2(0.0, -1.0)
	p.spread = 130.0
	p.gravity = Vector2(0.0, 38.0)
	p.initial_velocity_min = 95.0
	p.initial_velocity_max = 310.0
	p.scale_amount_min = 1.4
	p.scale_amount_max = 4.2
	p.color = accent.lerp(Color(1.0, 0.98, 0.85, 1.0), 0.4)


func _camp_hex(c: Color) -> String:
	return "%02x%02x%02x" % [clampi(int(c.r * 255.0), 0, 255), clampi(int(c.g * 255.0), 0, 255), clampi(int(c.b * 255.0), 0, 255)]


func _apply_arena_result_camp_theme(won: bool, mmr_delta: int) -> void:
	var gold_c: Color = CampUiSkin.CAMP_ACTION_PRIMARY
	var token_c: Color = Color(1.0, 0.72, 0.35, 1.0)
	var defeat_c: Color = Color(0.88, 0.38, 0.34, 1.0)
	var title_win: Color = CampUiSkin.CAMP_ACCENT_GREEN
	var title_loss: Color = Color(0.92, 0.42, 0.38, 1.0)
	var outline: Color = Color(0.04, 0.03, 0.02, 0.94)

	if arena_result_panel:
		# Camp panel colors are ~0.88 alpha; that lets the city show *through the card*. Force opaque.
		var panel_bg: Color = CampUiSkin.CAMP_PANEL_BG
		panel_bg.a = 1.0
		arena_result_panel.add_theme_stylebox_override(
			"panel",
			CampUiSkin.make_panel_style(panel_bg, CampUiSkin.CAMP_BORDER, 22, 14)
		)

	if arena_result_title:
		arena_result_title.text = "ARENA VICTORY" if won else "ARENA DEFEAT"
		arena_result_title.add_theme_font_size_override("font_size", 48)
		arena_result_title.add_theme_color_override("font_color", title_win if won else title_loss)
		arena_result_title.add_theme_constant_override("outline_size", 3)
		arena_result_title.add_theme_color_override("font_outline_color", outline)

	if arena_result_rating_label:
		arena_result_rating_label.add_theme_color_override("font_color", CampUiSkin.CAMP_MUTED)
		arena_result_rating_label.add_theme_font_size_override("font_size", 22)
		arena_result_rating_label.add_theme_constant_override("outline_size", 1)
		arena_result_rating_label.add_theme_color_override("font_outline_color", outline)

	if arena_result_delta_label:
		var delta_col: Color = CampUiSkin.CAMP_ACCENT_CYAN if mmr_delta >= 0 else Color(0.95, 0.45, 0.48, 1.0)
		arena_result_delta_label.add_theme_color_override("font_color", delta_col)
		arena_result_delta_label.add_theme_font_size_override("font_size", 28)
		arena_result_delta_label.add_theme_constant_override("outline_size", 2)
		arena_result_delta_label.add_theme_color_override("font_outline_color", outline)

	if arena_result_rank_name:
		arena_result_rank_name.add_theme_font_size_override("font_size", 30)
		arena_result_rank_name.add_theme_constant_override("outline_size", 2)
		arena_result_rank_name.add_theme_color_override("font_outline_color", outline)

	if arena_result_bar_value:
		arena_result_bar_value.add_theme_color_override("font_color", CampUiSkin.CAMP_TEXT)
		arena_result_bar_value.add_theme_font_size_override("font_size", 26)
		arena_result_bar_value.add_theme_constant_override("outline_size", 1)
		arena_result_bar_value.add_theme_color_override("font_outline_color", outline)

	if arena_result_rewards:
		arena_result_rewards.scroll_active = false
		arena_result_rewards.add_theme_color_override("default_color", CampUiSkin.CAMP_TEXT)
		if won:
			arena_result_rewards.text = (
				"[center][font_size=22][color=#%s]Spoils[/color][/font_size]\n[font_size=24][color=#%s]+%d gold[/color]  ·  [color=#%s]+%d gladiator tokens[/color][/font_size][/center]"
				% [_camp_hex(CampUiSkin.CAMP_MUTED), _camp_hex(gold_c), ArenaManager.last_match_gold_reward, _camp_hex(token_c), ArenaManager.last_match_token_reward]
			)
		else:
			arena_result_rewards.text = (
				"[center][font_size=24][color=#%s]Streak broken[/color][/font_size]\n[font_size=20][color=#%s]The quartermaster notes your fall — climb again.[/color][/font_size][/center]"
				% [_camp_hex(defeat_c), _camp_hex(CampUiSkin.CAMP_MUTED)]
			)

	var continue_lbl: Label = arena_result_sequence.get_node_or_null("Panel/ClickToContinue") as Label
	if continue_lbl:
		continue_lbl.add_theme_color_override("font_color", CampUiSkin.CAMP_MUTED)
		continue_lbl.add_theme_constant_override("outline_size", 1)
		continue_lbl.add_theme_color_override("font_outline_color", outline)


func _style_arena_rank_progress_bar(rank_data: Dictionary) -> void:
	if arena_result_bar == null:
		return
	var track := StyleBoxFlat.new()
	track.bg_color = CampUiSkin.CAMP_PANEL_BG_SOFT
	track.border_color = CampUiSkin.CAMP_BORDER_SOFT
	track.set_border_width_all(2)
	track.corner_radius_top_left = 10
	track.corner_radius_top_right = 10
	track.corner_radius_bottom_left = 10
	track.corner_radius_bottom_right = 10
	arena_result_bar.add_theme_stylebox_override("background", track)

	var rk: Color = rank_data["color"]
	var fill := StyleBoxFlat.new()
	fill.bg_color = rk.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.12)
	fill.border_color = rk.lightened(0.22)
	fill.set_border_width_all(2)
	fill.corner_radius_top_left = 10
	fill.corner_radius_top_right = 10
	fill.corner_radius_bottom_left = 10
	fill.corner_radius_bottom_right = 10
	arena_result_bar.add_theme_stylebox_override("fill", fill)


func _configure_arena_burst(accent: Color, big: bool) -> void:
	if arena_result_burst == null:
		return
	arena_result_burst.emitting = false
	arena_result_burst.one_shot = true
	arena_result_burst.amount = 88 if big else 44
	arena_result_burst.lifetime = 1.05 if big else 0.75
	arena_result_burst.explosiveness = 0.94 if big else 0.75
	arena_result_burst.direction = Vector2(0.0, -1.0)
	arena_result_burst.spread = 180.0
	arena_result_burst.gravity = Vector2(0.0, 120.0)
	arena_result_burst.initial_velocity_min = 160.0 if big else 100.0
	arena_result_burst.initial_velocity_max = 360.0 if big else 240.0
	arena_result_burst.scale_amount_min = 2.2
	arena_result_burst.scale_amount_max = 5.5 if big else 4.0
	arena_result_burst.color = accent


func _arena_result_reset_fx() -> void:
	var one: Color = Color(1, 1, 1, 1)
	if arena_result_panel:
		arena_result_panel.scale = Vector2.ONE
		arena_result_panel.rotation = 0.0
		arena_result_panel.position = _arena_result_panel_rest_pos
	if arena_result_title:
		arena_result_title.modulate = one
		arena_result_title.scale = Vector2.ONE
	if arena_result_rank_icon:
		arena_result_rank_icon.modulate = one
		arena_result_rank_icon.scale = Vector2.ONE
	if arena_result_rank_name:
		arena_result_rank_name.modulate = one
		arena_result_rank_name.scale = Vector2.ONE
	if arena_result_rating_label:
		arena_result_rating_label.modulate = one
	if arena_result_delta_label:
		arena_result_delta_label.modulate = one
	if arena_result_bar:
		arena_result_bar.modulate = one
	if arena_result_bar_value:
		arena_result_bar_value.modulate = one
	if arena_result_rewards:
		arena_result_rewards.modulate = one
		arena_result_rewards.scale = Vector2.ONE
	if arena_result_stamp:
		arena_result_stamp.scale = Vector2.ONE
		arena_result_stamp.rotation = 0.0
		arena_result_stamp.modulate = one
		arena_result_stamp.offset_top = _arena_stamp_offset_top_default
	if arena_result_dimmer:
		arena_result_dimmer.color = ARENA_EPIC_DIMMER_BASE
		arena_result_dimmer.modulate.a = 0.0
		arena_result_dimmer.hide()
	if arena_result_burst:
		arena_result_burst.emitting = false
	if arena_result_epic_spark:
		arena_result_epic_spark.emitting = false

# ==========================================
# --- TOKEN SHOP CORE LOGIC ---
# ==========================================

func _open_token_shop() -> void:
	arena_panel.hide()
	arena_setup_panel.hide()
	_hide_unit_info_panel_immediate()
	_close_auction_house()
	shop_token_display.text = "Gladiator Tokens: " + str(CampaignManager.gladiator_tokens)
	token_shop_panel.show()
	token_purchase_btn.disabled = true
	
	# --- SMOOTH MUSIC SWAP: City to Shop ---
	_crossfade_music(city_bgm, shop_bgm)
	
	gladiator_portrait.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(gladiator_portrait, "modulate:a", 1.0, 0.4)
	
	_update_gladiator_text("welcome")
	_populate_token_shop()
	
	# --- NEW: BUILD AND ANIMATE ROADMAP ---
	_build_roadmap_ui()
	_animate_roadmap()
		
func _close_token_shop() -> void:
	token_shop_panel.hide()
	
	# --- SMOOTH MUSIC SWAP: Shop back to City ---
	_crossfade_music(shop_bgm, city_bgm)

# ==========================================
# --- AUCTION HOUSE (STEP 2: MULTIPLAYER + UUID) ---
# ==========================================

func _set_auction_status(message: String, color: Color = Color(0.83, 0.85, 0.89, 1.0)) -> void:
	if auction_status_label == null:
		return
	auction_status_label.text = message
	auction_status_label.add_theme_color_override("font_color", color)


func _auction_make_stylebox(
	bg: Color,
	border: Color,
	radius: int = 14,
	shadow_size: int = 6
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
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_size = shadow_size
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _auction_style_label(label: Label, color: Color = AUCTION_THEME_TEXT, font_size: int = 18, outline: int = 2) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.01, 0.96))
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_font_size_override("font_size", font_size)


func _auction_style_button(btn: Button, primary: bool = false, font_size: int = 18, min_height: float = 44.0) -> void:
	if btn == null:
		return
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.custom_minimum_size.y = min_height
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", AUCTION_THEME_TEXT if not primary else Color(0.14, 0.09, 0.04, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1) if not primary else Color(0.11, 0.08, 0.03, 1.0))
	btn.add_theme_color_override("font_pressed_color", AUCTION_THEME_TEXT if not primary else Color(0.11, 0.08, 0.03, 1.0))
	btn.add_theme_color_override("font_focus_color", AUCTION_THEME_TEXT if not primary else Color(0.11, 0.08, 0.03, 1.0))
	var fill_normal: Color = Color(0.22, 0.17, 0.11, 0.97) if not primary else Color(0.75, 0.60, 0.23, 0.98)
	var fill_hover: Color = fill_normal.lightened(0.08)
	var fill_pressed: Color = fill_normal.darkened(0.08)
	var border_normal: Color = AUCTION_THEME_BORDER_SOFT if not primary else AUCTION_THEME_ACCENT
	btn.add_theme_stylebox_override("normal", _auction_make_stylebox(fill_normal, border_normal, 14, 4))
	btn.add_theme_stylebox_override("hover", _auction_make_stylebox(fill_hover, AUCTION_THEME_BORDER, 14, 4))
	btn.add_theme_stylebox_override("pressed", _auction_make_stylebox(fill_pressed, AUCTION_THEME_ACCENT, 14, 4))
	btn.add_theme_stylebox_override("focus", _auction_make_stylebox(fill_hover, AUCTION_THEME_ACCENT, 14, 5))
	btn.add_theme_stylebox_override("disabled", _auction_make_stylebox(fill_normal.darkened(0.14), border_normal.darkened(0.22), 14, 0))


func _auction_style_line_edit(line: LineEdit, font_size: int = 18, min_height: float = 42.0) -> void:
	if line == null:
		return
	line.custom_minimum_size.y = min_height
	line.add_theme_font_size_override("font_size", font_size)
	line.add_theme_color_override("font_color", AUCTION_THEME_TEXT)
	line.add_theme_color_override("font_placeholder_color", AUCTION_THEME_MUTED)
	line.add_theme_color_override("font_selected_color", Color(0.12, 0.09, 0.05, 1.0))
	line.add_theme_color_override("selection_color", Color(0.52, 0.90, 1.0, 0.38))
	line.add_theme_stylebox_override("normal", _auction_make_stylebox(AUCTION_THEME_SURFACE, AUCTION_THEME_BORDER_SOFT, 12, 3))
	line.add_theme_stylebox_override("focus", _auction_make_stylebox(AUCTION_THEME_SURFACE.lightened(0.06), AUCTION_THEME_ACCENT, 12, 3))
	line.add_theme_stylebox_override("read_only", _auction_make_stylebox(AUCTION_THEME_SURFACE.darkened(0.08), AUCTION_THEME_BORDER_SOFT.darkened(0.1), 12, 0))


func _auction_style_option_button(option: OptionButton, font_size: int = 16, min_height: float = 40.0) -> void:
	if option == null:
		return
	option.custom_minimum_size.y = min_height
	option.add_theme_font_size_override("font_size", font_size)
	option.add_theme_color_override("font_color", AUCTION_THEME_TEXT)
	option.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	option.add_theme_color_override("font_pressed_color", AUCTION_THEME_TEXT)
	option.add_theme_stylebox_override("normal", _auction_make_stylebox(Color(0.20, 0.15, 0.10, 0.97), AUCTION_THEME_BORDER_SOFT, 12, 3))
	option.add_theme_stylebox_override("hover", _auction_make_stylebox(Color(0.24, 0.18, 0.11, 0.99), AUCTION_THEME_BORDER, 12, 3))
	option.add_theme_stylebox_override("pressed", _auction_make_stylebox(Color(0.16, 0.12, 0.08, 0.99), AUCTION_THEME_ACCENT, 12, 3))
	option.add_theme_stylebox_override("focus", _auction_make_stylebox(Color(0.24, 0.18, 0.11, 0.99), AUCTION_THEME_ACCENT, 12, 3))
	option.add_theme_stylebox_override("disabled", _auction_make_stylebox(Color(0.14, 0.11, 0.08, 0.92), AUCTION_THEME_BORDER_SOFT.darkened(0.2), 12, 0))


func _auction_style_rich_label(rtl: RichTextLabel, font_size: int = 16) -> void:
	if rtl == null:
		return
	rtl.bbcode_enabled = true
	rtl.fit_content = false
	rtl.scroll_active = true
	rtl.add_theme_font_size_override("normal_font_size", font_size)
	rtl.add_theme_color_override("default_color", AUCTION_THEME_TEXT)
	rtl.add_theme_stylebox_override("normal", _auction_make_stylebox(AUCTION_THEME_SURFACE, AUCTION_THEME_BORDER_SOFT, 14, 2))


func _auction_style_scroll(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	var vbar: VScrollBar = scroll.get_v_scroll_bar()
	if vbar == null:
		return
	vbar.custom_minimum_size.x = 10.0
	vbar.add_theme_stylebox_override("scroll", _auction_make_stylebox(Color(0.10, 0.08, 0.05, 0.78), Color(0, 0, 0, 0), 8, 0))
	vbar.add_theme_stylebox_override("grabber", _auction_make_stylebox(AUCTION_THEME_BORDER_SOFT, AUCTION_THEME_BORDER_SOFT, 8, 0))
	vbar.add_theme_stylebox_override("grabber_highlight", _auction_make_stylebox(AUCTION_THEME_BORDER, AUCTION_THEME_BORDER, 8, 0))
	vbar.add_theme_stylebox_override("grabber_pressed", _auction_make_stylebox(AUCTION_THEME_ACCENT, AUCTION_THEME_ACCENT, 8, 0))


func _set_auction_controls_enabled(enabled: bool) -> void:
	if auction_refresh_button != null:
		auction_refresh_button.disabled = not enabled
	if auction_place_bid_button != null:
		auction_place_bid_button.disabled = not enabled
	if auction_bid_input != null:
		auction_bid_input.editable = enabled
	if auction_create_listing_button != null:
		auction_create_listing_button.disabled = not enabled
	if auction_my_item_option != null:
		auction_my_item_option.disabled = not enabled
	if auction_listing_start_bid_input != null:
		auction_listing_start_bid_input.editable = enabled
	if auction_listing_min_inc_input != null:
		auction_listing_min_inc_input.editable = enabled
	if auction_listing_draft_item_option != null:
		auction_listing_draft_item_option.disabled = not enabled
	if auction_listing_draft_start_bid_input != null:
		auction_listing_draft_start_bid_input.editable = enabled
	if auction_listing_draft_min_inc_input != null:
		auction_listing_draft_min_inc_input.editable = enabled
	if auction_listing_draft_confirm_button != null:
		auction_listing_draft_confirm_button.disabled = not enabled


func _refresh_auction_control_state() -> void:
	var busy: bool = _auction_fetch_in_flight or _auction_bid_in_flight or _auction_listing_in_flight
	if busy:
		_set_auction_controls_enabled(false)
		if auction_search_input != null:
			auction_search_input.editable = false
		if auction_status_filter_option != null:
			auction_status_filter_option.disabled = true
		if auction_sort_option != null:
			auction_sort_option.disabled = true
		if auction_clear_filters_button != null:
			auction_clear_filters_button.disabled = true
		return
	if auction_refresh_button != null:
		auction_refresh_button.disabled = false
	if auction_create_listing_button != null:
		auction_create_listing_button.disabled = false
	if auction_my_item_option != null:
		auction_my_item_option.disabled = false
	if auction_listing_start_bid_input != null:
		auction_listing_start_bid_input.editable = true
	if auction_listing_min_inc_input != null:
		auction_listing_min_inc_input.editable = true
	if auction_listing_draft_item_option != null:
		auction_listing_draft_item_option.disabled = false
	if auction_listing_draft_start_bid_input != null:
		auction_listing_draft_start_bid_input.editable = true
	if auction_listing_draft_min_inc_input != null:
		auction_listing_draft_min_inc_input.editable = true
	if auction_listing_draft_confirm_button != null:
		auction_listing_draft_confirm_button.disabled = false
	if auction_search_input != null:
		auction_search_input.editable = true
	if auction_status_filter_option != null:
		auction_status_filter_option.disabled = false
	if auction_sort_option != null:
		auction_sort_option.disabled = false
	if auction_clear_filters_button != null:
		auction_clear_filters_button.disabled = false


func _setup_auction_filter_controls() -> void:
	if auction_search_input != null:
		auction_search_input.placeholder_text = "Search listing title, seller, summary..."
		auction_search_input.text = _auction_search_query
	if auction_status_filter_option != null:
		auction_status_filter_option.clear()
		auction_status_filter_option.add_item("All Status")
		auction_status_filter_option.add_item("Active")
		auction_status_filter_option.add_item("Ending Soon")
		auction_status_filter_option.add_item("Sold")
		auction_status_filter_option.add_item("Expired/Cancelled")
		auction_status_filter_option.add_item("My Listings")
		auction_status_filter_option.select(clampi(_auction_status_filter_index, 0, auction_status_filter_option.get_item_count() - 1))
	if auction_sort_option != null:
		auction_sort_option.clear()
		auction_sort_option.add_item("Ending Soon")
		auction_sort_option.add_item("Highest Bid")
		auction_sort_option.add_item("Lowest Entry")
		auction_sort_option.add_item("Newest Listings")
		auction_sort_option.add_item("A-Z")
		auction_sort_option.select(clampi(_auction_sort_mode_index, 0, auction_sort_option.get_item_count() - 1))


func _on_auction_search_text_changed(new_text: String) -> void:
	_auction_search_query = new_text.strip_edges()
	_rebuild_auction_listing_buttons()
	_refresh_auction_selected_view()


func _on_auction_status_filter_selected(index: int) -> void:
	_auction_status_filter_index = index
	_rebuild_auction_listing_buttons()
	_refresh_auction_selected_view()


func _on_auction_sort_selected(index: int) -> void:
	_auction_sort_mode_index = index
	_rebuild_auction_listing_buttons()
	_refresh_auction_selected_view()


func _on_auction_clear_filters_pressed() -> void:
	_auction_search_query = ""
	_auction_status_filter_index = 0
	_auction_sort_mode_index = 0
	_setup_auction_filter_controls()
	_rebuild_auction_listing_buttons()
	_refresh_auction_selected_view()


func _listing_matches_status_filter(listing: Dictionary, local_player_id: String) -> bool:
	var status: String = str(listing.get("status", "active")).strip_edges().to_lower()
	var now_unix: int = int(Time.get_unix_time_from_system())
	var end_unix: int = int(listing.get("end_timestamp_unix", 0))
	var is_ending_soon: bool = (status == "active" and end_unix > now_unix and (end_unix - now_unix) <= 7200)
	if _auction_status_filter_index <= 0:
		return true
	if _auction_status_filter_index == 1:
		return status == "active"
	if _auction_status_filter_index == 2:
		return is_ending_soon
	if _auction_status_filter_index == 3:
		return status == "sold"
	if _auction_status_filter_index == 4:
		return status == "expired" or status == "cancelled"
	if _auction_status_filter_index == 5:
		var seller_id: String = str(listing.get("seller_id", "")).strip_edges()
		return local_player_id != "" and seller_id == local_player_id
	return true


func _listing_matches_search_query(listing: Dictionary) -> bool:
	var query: String = _auction_search_query.strip_edges().to_lower()
	if query == "":
		return true
	var haystack: String = (
		str(listing.get("title", "")) + " "
		+ str(listing.get("summary", "")) + " "
		+ str(listing.get("listing_id", "")) + " "
		+ str(listing.get("seller_name", ""))
	).to_lower()
	return haystack.find(query) != -1


func _listing_live_bid_value(listing: Dictionary) -> int:
	var listing_id: String = str(listing.get("listing_id", "")).strip_edges()
	var status: String = str(listing.get("status", "active")).strip_edges().to_lower()
	var start_bid: int = maxi(int(listing.get("starting_bid", 0)), 0)
	if status == "sold":
		return maxi(int(listing.get("final_bid", 0)), start_bid)
	var bid_data: Dictionary = _auction_highest_by_listing.get(listing_id, {})
	var highest_bid: int = int(bid_data.get("bid_amount", -1))
	if highest_bid < 0:
		return start_bid
	return highest_bid


func _auction_listing_sort_value(listing: Dictionary, mode: int) -> Variant:
	var status: String = str(listing.get("status", "active")).strip_edges().to_lower()
	if mode == 0:
		var end_unix: int = int(listing.get("end_timestamp_unix", 0))
		if status != "active":
			return 2147483647
		if end_unix <= 0:
			return 2147483646
		return end_unix
	if mode == 1:
		return _listing_live_bid_value(listing)
	if mode == 2:
		return maxi(int(listing.get("starting_bid", 0)), 0)
	if mode == 3:
		return int(listing.get("created_at", 0))
	return str(listing.get("title", "")).to_lower()


func _auction_sort_filtered_listings(listings: Array[Dictionary]) -> void:
	var mode: int = _auction_sort_mode_index
	listings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var av: Variant = _auction_listing_sort_value(a, mode)
		var bv: Variant = _auction_listing_sort_value(b, mode)
		if mode == 1 or mode == 3:
			if av == bv:
				return str(a.get("title", "")).to_lower() < str(b.get("title", "")).to_lower()
			return av > bv
		if av == bv:
			return str(a.get("title", "")).to_lower() < str(b.get("title", "")).to_lower()
		return av < bv
	)


func _get_filtered_sorted_auction_listings() -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	var local_player_id: String = _get_auction_player_id()
	for listing_variant in _get_active_auction_listings():
		var listing: Dictionary = listing_variant
		if not _listing_matches_status_filter(listing, local_player_id):
			continue
		if not _listing_matches_search_query(listing):
			continue
		filtered.append(listing)
	_auction_sort_filtered_listings(filtered)
	return filtered


func _refresh_auction_market_badge() -> void:
	if auction_market_badge_label == null:
		return
	var listings: Array[Dictionary] = _get_active_auction_listings()
	var total_count: int = listings.size()
	var active_count: int = 0
	var ending_soon_count: int = 0
	var highest_bid_seen: int = 0
	var now_unix: int = int(Time.get_unix_time_from_system())
	for listing_variant in listings:
		var listing: Dictionary = listing_variant
		var status: String = str(listing.get("status", "active")).strip_edges().to_lower()
		if status == "active":
			active_count += 1
			var end_unix: int = int(listing.get("end_timestamp_unix", 0))
			if end_unix > now_unix and (end_unix - now_unix) <= 7200:
				ending_soon_count += 1
		highest_bid_seen = maxi(highest_bid_seen, _listing_live_bid_value(listing))
	var search_tag: String = _auction_search_query.strip_edges()
	if search_tag == "":
		search_tag = "None"
	auction_market_badge_label.bbcode_enabled = true
	auction_market_badge_label.scroll_active = false
	auction_market_badge_label.text = (
		"[b]Grand Exchange Intel[/b]\n"
		+ "[color=#8fe28e]Active:[/color] %d   "
		+ "[color=#ffd87a]Ending Soon:[/color] %d   "
		+ "[color=#9be8ff]Peak Bid:[/color] %dG\n"
		+ "[color=#c4ccd7]Visible Listings:[/color] %d / %d   "
		+ "[color=#c4ccd7]Search:[/color] %s"
	) % [
		active_count,
		ending_soon_count,
		highest_bid_seen,
		_get_filtered_sorted_auction_listings().size(),
		total_count,
		search_tag
	]


func _apply_auction_ui_theme() -> void:
	if _auction_theme_applied:
		return
	_auction_theme_applied = true
	if auction_panel != null:
		auction_panel.add_theme_stylebox_override("panel", _auction_make_stylebox(AUCTION_THEME_PANEL_BG, AUCTION_THEME_BORDER, 20, 10))
	if auction_listing_draft_panel != null:
		auction_listing_draft_panel.add_theme_stylebox_override("panel", _auction_make_stylebox(AUCTION_THEME_PANEL_BG_ALT, AUCTION_THEME_BORDER, 18, 8))
	if auction_listings_container != null:
		auction_listings_container.add_theme_constant_override("separation", 8)
	if auction_notifications_label != null:
		auction_notifications_label.custom_minimum_size.y = 96.0
	if auction_market_badge_label != null:
		auction_market_badge_label.custom_minimum_size.y = 76.0
	if auction_listing_draft_icon != null:
		auction_listing_draft_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		auction_listing_draft_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if auction_selected_listing_icon != null:
		auction_selected_listing_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		auction_selected_listing_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	_auction_style_button(auction_close_button, false, 18, 44.0)
	_auction_style_button(auction_refresh_button, false, 18, 44.0)
	_auction_style_button(auction_place_bid_button, true, 20, 46.0)
	_auction_style_button(auction_clear_filters_button, false, 16, 40.0)
	_auction_style_button(auction_create_listing_button, true, 18, 44.0)
	_auction_style_button(auction_listing_draft_cancel_button, false, 16, 42.0)
	_auction_style_button(auction_listing_draft_confirm_button, true, 16, 42.0)

	_auction_style_line_edit(auction_bid_input, 18, 44.0)
	_auction_style_line_edit(auction_search_input, 16, 40.0)
	_auction_style_line_edit(auction_listing_start_bid_input, 16, 40.0)
	_auction_style_line_edit(auction_listing_min_inc_input, 16, 40.0)
	_auction_style_line_edit(auction_listing_draft_start_bid_input, 16, 40.0)
	_auction_style_line_edit(auction_listing_draft_min_inc_input, 16, 40.0)

	_auction_style_option_button(auction_status_filter_option, 16, 40.0)
	_auction_style_option_button(auction_sort_option, 16, 40.0)
	_auction_style_option_button(auction_my_item_option, 16, 40.0)
	_auction_style_option_button(auction_listing_draft_item_option, 16, 40.0)

	_auction_style_label(auction_status_label, AUCTION_THEME_MUTED, 16, 1)
	_auction_style_label(auction_my_gold_label, AUCTION_THEME_WARN, 24, 2)
	_auction_style_label(auction_listing_draft_title, AUCTION_THEME_WARN, 20, 2)
	_auction_style_label(auction_listing_draft_uid, AUCTION_THEME_ACCENT, 14, 1)

	_auction_style_rich_label(auction_selected_listing_label, 18)
	_auction_style_rich_label(auction_market_badge_label, 13)
	_auction_style_rich_label(auction_notifications_label, 14)
	_auction_style_rich_label(auction_listing_draft_details, 14)

	_auction_style_scroll(get_node_or_null("AuctionPanel/ListingsScroll") as ScrollContainer)
	_auction_style_scroll(get_node_or_null("AuctionPanel/SelectedListingLabel") as ScrollContainer)
	_auction_style_scroll(get_node_or_null("AuctionPanel/ListingDraftPanel/DraftDetailsPanel/DraftDetailsScroll") as ScrollContainer)


func _refresh_auction_notifications_view() -> void:
	if auction_notifications_label == null:
		return
	auction_notifications_label.bbcode_enabled = true
	if _auction_notifications.is_empty():
		auction_notifications_label.text = "[color=#7f8a9a]No auction notifications yet.[/color]"
		return
	auction_notifications_label.text = "\n".join(_auction_notifications)


func _push_auction_notification(message: String, accent_hex: String = "#9be8ff") -> void:
	var clean_message: String = message.strip_edges()
	if clean_message == "":
		return
	var timestamp: String = Time.get_time_string_from_system()
	var line: String = "[color=#6c788a]%s[/color] [color=%s]%s[/color]" % [timestamp, accent_hex, clean_message]
	_auction_notifications.append(line)
	while _auction_notifications.size() > AUCTION_NOTIFICATION_HISTORY_MAX:
		_auction_notifications.pop_front()
	_refresh_auction_notifications_view()


func _has_local_auction_receipt(receipt_id: String) -> bool:
	var key: String = receipt_id.strip_edges()
	if key == "":
		return false
	return bool(CampaignManager.auction_applied_receipts.get(key, false))


func _mark_local_auction_receipt(receipt_id: String) -> void:
	var key: String = receipt_id.strip_edges()
	if key == "":
		return
	var receipts: Dictionary = CampaignManager.auction_applied_receipts
	receipts[key] = true
	CampaignManager.auction_applied_receipts = receipts


func _is_listing_locked_by_other(listing: Dictionary, local_player_id: String, now_unix: int) -> bool:
	var lock_owner: String = str(listing.get("settlement_lock_owner", "")).strip_edges()
	if lock_owner == "":
		return false
	var lock_until: int = int(listing.get("settlement_lock_until", 0))
	if lock_until <= now_unix:
		return false
	var local_id: String = local_player_id.strip_edges()
	if local_id == "":
		return true
	return lock_owner != local_id


func _clear_listing_settlement_lock(listing: Dictionary) -> Dictionary:
	var out: Dictionary = listing.duplicate(true)
	out["settlement_lock_owner"] = ""
	out["settlement_lock_token"] = ""
	out["settlement_lock_until"] = 0
	out["settlement_lock_at"] = 0
	return out


func _try_acquire_listing_settlement_lock_async(listing_id: String, local_player_id: String) -> String:
	if not has_node("/root/SilentWolf"):
		return ""
	var clean_listing_id: String = listing_id.strip_edges()
	var clean_local_id: String = local_player_id.strip_edges()
	if clean_listing_id == "" or clean_local_id == "":
		return ""
	var listing_variant: Variant = _auction_cloud_listings_by_id.get(clean_listing_id, {})
	if not (listing_variant is Dictionary):
		return ""
	var listing: Dictionary = (listing_variant as Dictionary).duplicate(true)
	var now_unix: int = int(Time.get_unix_time_from_system())
	if _is_listing_locked_by_other(listing, clean_local_id, now_unix):
		return ""
	var lock_token: String = _generate_auction_uuid()
	listing["settlement_lock_owner"] = clean_local_id
	listing["settlement_lock_token"] = lock_token
	listing["settlement_lock_until"] = now_unix + AUCTION_SETTLEMENT_LOCK_SECONDS
	listing["settlement_lock_at"] = now_unix
	_auction_cloud_listings_by_id[clean_listing_id] = listing
	var saved: bool = await _save_auction_listings_document_async()
	if not saved:
		return ""
	await _fetch_auction_listings_document_async()
	var verify_variant: Variant = _auction_cloud_listings_by_id.get(clean_listing_id, {})
	if not (verify_variant is Dictionary):
		return ""
	var verify: Dictionary = verify_variant
	var verify_owner: String = str(verify.get("settlement_lock_owner", "")).strip_edges()
	var verify_token: String = str(verify.get("settlement_lock_token", "")).strip_edges()
	var verify_until: int = int(verify.get("settlement_lock_until", 0))
	if verify_owner == clean_local_id and verify_token == lock_token and verify_until > int(Time.get_unix_time_from_system()):
		return lock_token
	return ""


func _listing_needs_cloud_mutation(listing: Dictionary, local_player_id: String, now_unix: int) -> bool:
	var status: String = str(listing.get("status", "active")).strip_edges().to_lower()
	var end_timestamp_unix: int = int(listing.get("end_timestamp_unix", 0))
	if status == "active" and end_timestamp_unix > 0 and now_unix >= end_timestamp_unix:
		return true
	var local_id: String = local_player_id.strip_edges()
	if local_id == "":
		return false
	var seller_id: String = str(listing.get("seller_id", "")).strip_edges()
	var winner_id: String = str(listing.get("winner_id", "")).strip_edges()
	var item_uid: String = str(listing.get("item_uid", "")).strip_edges()
	if status == "sold":
		var needs_winner_delivery: bool = (winner_id == local_id and not bool(listing.get("delivered_to_winner", false)))
		if needs_winner_delivery and (item_uid == "" or _inventory_has_item_uid(item_uid) or _build_auction_item_from_listing(listing) != null):
			return true
		if seller_id == local_id and not bool(listing.get("seller_paid", false)):
			return true
	elif status == "expired" or status == "cancelled":
		var needs_return: bool = (seller_id == local_id and not bool(listing.get("returned_to_seller", false)))
		if needs_return and (item_uid == "" or _inventory_has_item_uid(item_uid) or _build_auction_item_from_listing(listing) != null):
			return true
	return false


func _apply_cloud_mutation_to_listing(listing: Dictionary, local_player_id: String, now_unix: int) -> Dictionary:
	var out: Dictionary = listing.duplicate(true)
	var status: String = str(out.get("status", "active")).strip_edges().to_lower()
	var end_timestamp_unix: int = int(out.get("end_timestamp_unix", 0))
	if status == "active" and end_timestamp_unix > 0 and now_unix >= end_timestamp_unix:
		var listing_id: String = str(out.get("listing_id", "")).strip_edges()
		var top_bid_data: Dictionary = _auction_highest_by_listing.get(listing_id, {})
		var winning_bid: int = maxi(int(top_bid_data.get("bid_amount", 0)), 0)
		var winning_bidder_id: String = str(top_bid_data.get("bidder_id", "")).strip_edges()
		var winning_bidder_name: String = str(top_bid_data.get("bidder", "Unknown Commander")).strip_edges()
		var listing_start_bid: int = maxi(int(out.get("starting_bid", 0)), 0)
		if winning_bidder_id != "" and winning_bid >= listing_start_bid:
			out["status"] = "sold"
			out["winner_id"] = winning_bidder_id
			out["winner_name"] = winning_bidder_name if winning_bidder_name != "" else "Unknown Commander"
			out["final_bid"] = winning_bid
		else:
			out["status"] = "expired"
			out["winner_id"] = ""
			out["winner_name"] = ""
			out["final_bid"] = 0
		out["closed_at"] = now_unix

	status = str(out.get("status", "active")).strip_edges().to_lower()
	var local_id: String = local_player_id.strip_edges()
	if local_id != "":
		var seller_id: String = str(out.get("seller_id", "")).strip_edges()
		var winner_id: String = str(out.get("winner_id", "")).strip_edges()
		var item_uid: String = str(out.get("item_uid", "")).strip_edges()
		if status == "sold":
			if winner_id == local_id and not bool(out.get("delivered_to_winner", false)):
				if item_uid == "" or _inventory_has_item_uid(item_uid) or _build_auction_item_from_listing(out) != null:
					out["delivered_to_winner"] = true
					out["delivered_at"] = now_unix
			if seller_id == local_id and not bool(out.get("seller_paid", false)):
				out["seller_paid"] = true
				out["seller_paid_at"] = now_unix
		elif status == "expired" or status == "cancelled":
			if seller_id == local_id and not bool(out.get("returned_to_seller", false)):
				if item_uid == "" or _inventory_has_item_uid(item_uid) or _build_auction_item_from_listing(out) != null:
					out["returned_to_seller"] = true
					out["returned_at"] = now_unix

	return _clear_listing_settlement_lock(out)


func _setup_auction_poll_timer() -> void:
	if _auction_poll_timer != null:
		return
	_auction_poll_timer = Timer.new()
	_auction_poll_timer.one_shot = false
	_auction_poll_timer.autostart = false
	_auction_poll_timer.wait_time = clampf(auction_refresh_seconds, 3.0, 60.0)
	_auction_poll_timer.timeout.connect(_on_auction_poll_timeout)
	add_child(_auction_poll_timer)


func _ensure_auction_listings() -> void:
	if not auction_listings.is_empty():
		return
	if not auction_use_default_if_empty:
		return
	auction_listings = _build_default_auction_listing_resources()


func _build_default_auction_listing_resources() -> Array[Resource]:
	var resources: Array[Resource] = []
	for listing_variant in DEFAULT_AUCTION_LISTINGS:
		var listing_data: Dictionary = listing_variant
		var res: Resource = AUCTION_LISTING_DATA_SCRIPT.new()
		res.set("listing_id", str(listing_data.get("listing_id", "")))
		res.set("title", str(listing_data.get("title", "Auction Listing")))
		res.set("summary", str(listing_data.get("summary", "")))
		res.set("starting_bid", int(listing_data.get("starting_bid", 100)))
		res.set("min_increment", maxi(int(listing_data.get("min_increment", 5)), 1))
		res.set("end_timestamp_unix", int(listing_data.get("end_timestamp_unix", 0)))
		resources.append(res)
	return resources


func _resource_get(resource: Resource, property_name: String, fallback: Variant = null) -> Variant:
	if resource == null:
		return fallback
	var value: Variant = resource.get(property_name)
	if value == null:
		return fallback
	return value


func _auction_document_name() -> String:
	var value: String = auction_listings_document_name.strip_edges()
	if value == "":
		return AUCTION_LISTINGS_DOCUMENT_FALLBACK
	return value


func _generate_auction_uuid() -> String:
	if AUCTION_UUID != null:
		var uuid_helper: Object = AUCTION_UUID.new()
		if uuid_helper != null and uuid_helper.has_method("generate_uuid_v4"):
			var generated: String = str(uuid_helper.call("generate_uuid_v4")).strip_edges()
			if generated != "":
				return generated
	return "auc_%d_%d" % [int(Time.get_unix_time_from_system()), randi()]


func _get_auction_player_id() -> String:
	if ArenaManager.has_method("get_safe_player_id"):
		var player_id: String = str(ArenaManager.call("get_safe_player_id")).strip_edges()
		if player_id != "":
			return player_id
	var steam_service: Node = get_node_or_null("/root/SteamService")
	if steam_service != null and steam_service.has_method("is_steam_ready") and bool(steam_service.call("is_steam_ready")):
		var api_variant: Variant = steam_service.call("get_api")
		if api_variant is Object:
			var api: Object = api_variant
			if api.has_method("getSteamID"):
				var steam_id: String = str(api.call("getSteamID")).strip_edges()
				if steam_id != "":
					return steam_id
	return "local_%d" % int(Time.get_unix_time_from_system())


func _extract_item_uid(item: Resource) -> String:
	if item == null:
		return ""
	if item.has_meta("uid"):
		var uid: String = str(item.get_meta("uid")).strip_edges()
		if uid != "":
			return uid
	var new_uid: String = _generate_auction_uuid()
	item.set_meta("uid", new_uid)
	return new_uid


func _get_item_display_name(item: Resource) -> String:
	if item == null:
		return "Unknown Item"
	var item_name: Variant = item.get("item_name")
	if item_name != null:
		var item_text: String = str(item_name).strip_edges()
		if item_text != "":
			return item_text
	var weapon_name: Variant = item.get("weapon_name")
	if weapon_name != null:
		var weapon_text: String = str(weapon_name).strip_edges()
		if weapon_text != "":
			return weapon_text
	var resource_name: String = str(item.resource_name).strip_edges()
	if resource_name != "":
		return resource_name
	return "Unnamed Item"


func _format_auction_item_details(item: Resource) -> String:
	if item == null:
		return "[color=#ff8a8a]No item selected.[/color]"
	var lines: Array[String] = []
	var rarity_text: String = str(item.get("rarity") if item.get("rarity") != null else "common").to_upper()
	var value_text: String = str(item.get("gold_cost") if item.get("gold_cost") != null else 0)
	lines.append("[color=#9be8ff]Rarity:[/color] %s    [color=#f8d86a]Value:[/color] %sG" % [rarity_text, value_text])
	var type_text: String = "UNKNOWN"
	if item.has_method("get"):
		if item.get("weapon_type") != null:
			type_text = str(item.get("weapon_type")).to_upper()
		elif item.get("item_type") != null:
			type_text = str(item.get("item_type")).to_upper()
	lines.append("[color=#8fe28e]Type:[/color] %s" % type_text)
	var might: int = int(item.get("might") if item.get("might") != null else 0)
	var hit_bonus: int = int(item.get("hit_bonus") if item.get("hit_bonus") != null else 0)
	var crit_bonus: int = int(item.get("crit_bonus") if item.get("crit_bonus") != null else 0)
	var durability: int = int(item.get("current_durability") if item.get("current_durability") != null else 0)
	var max_durability: int = int(item.get("max_durability") if item.get("max_durability") != null else 0)
	if might != 0 or hit_bonus != 0 or crit_bonus != 0 or max_durability > 0:
		lines.append("[color=#ffb26a]Might:[/color] %d    [color=#c9f57f]Hit:[/color] +%d    [color=#f7a4ff]Crit:[/color] +%d" % [might, hit_bonus, crit_bonus])
		if max_durability > 0:
			lines.append("[color=#9fe7ff]Durability:[/color] %d/%d" % [durability, max_durability])
	var rune_auction: String = WeaponRuneDisplayHelpers.format_runes_bbcode_for_item_variant(item)
	if rune_auction != "":
		lines.append(rune_auction)
	var description_text: String = str(item.get("description") if item.get("description") != null else "").strip_edges()
	if description_text == "":
		description_text = "No description available."
	lines.append("")
	lines.append("[color=#d0d0d0]%s[/color]" % description_text)
	return "\n".join(lines)


func _get_auction_item_icon_texture(item: Resource) -> Texture2D:
	if item == null:
		return null
	var icon_variant: Variant = item.get("icon")
	if icon_variant is Texture2D:
		return icon_variant
	return null


func _get_auction_icon_from_item_data(item_data: Dictionary) -> Texture2D:
	var icon_variant: Variant = item_data.get("icon", null)
	if icon_variant is Texture2D:
		return icon_variant

	var icon_path: String = str(item_data.get("icon_path", "")).strip_edges()
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon_tex: Resource = load(icon_path)
		if icon_tex is Texture2D:
			return icon_tex

	var item_path: String = str(item_data.get("path", "")).strip_edges()
	if item_path != "" and ResourceLoader.exists(item_path):
		var item_res: Resource = load(item_path)
		if item_res != null:
			var loaded_icon: Texture2D = _get_auction_item_icon_texture(item_res)
			if loaded_icon != null:
				return loaded_icon
	return null


func _normalize_auction_icon_key(raw_text: String) -> String:
	var key: String = raw_text.strip_edges().to_lower()
	if key == "":
		return ""
	key = key.replace("_", " ").replace("-", " ").replace(".", " ").replace(":", " ")
	while key.find("  ") >= 0:
		key = key.replace("  ", " ")
	return key.strip_edges()


func _cache_auction_icon_for_item(item: Resource) -> void:
	if item == null:
		return
	var icon_tex: Texture2D = _get_auction_item_icon_texture(item)
	if icon_tex == null:
		return
	var key: String = _normalize_auction_icon_key(_get_item_display_name(item))
	if key != "" and not _auction_icon_lookup_by_title.has(key):
		_auction_icon_lookup_by_title[key] = icon_tex
	var resource_key: String = _normalize_auction_icon_key(str(item.resource_name))
	if resource_key != "" and not _auction_icon_lookup_by_title.has(resource_key):
		_auction_icon_lookup_by_title[resource_key] = icon_tex


func _scan_auction_icon_directory(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var entry_path: String = path.path_join(entry)
		if dir.current_is_dir():
			_scan_auction_icon_directory(entry_path)
		else:
			if entry.to_lower().ends_with(".tres") or entry.to_lower().ends_with(".res"):
				if ResourceLoader.exists(entry_path):
					var res: Resource = load(entry_path)
					_cache_auction_icon_for_item(res)
		entry = dir.get_next()
	dir.list_dir_end()


func _build_auction_icon_lookup_if_needed() -> void:
	if _auction_icon_lookup_built:
		return
	_auction_icon_lookup_built = true
	_auction_icon_lookup_by_title.clear()
	for scan_dir_variant in AUCTION_ICON_SCAN_DIRS:
		var scan_dir: String = str(scan_dir_variant).strip_edges()
		if scan_dir == "":
			continue
		_scan_auction_icon_directory(scan_dir)


func _get_auction_fallback_tag(item_title: String) -> String:
	var clean_title: String = item_title.strip_edges()
	if clean_title == "":
		return "?"
	var words: PackedStringArray = clean_title.split(" ", false)
	if words.size() >= 2:
		var a: String = words[0].substr(0, 1).to_upper()
		var b: String = words[1].substr(0, 1).to_upper()
		return "%s%s" % [a, b]
	return clean_title.substr(0, min(clean_title.length(), 2)).to_upper()


func _get_auction_icon_from_title(item_title: String) -> Texture2D:
	var needle: String = _normalize_auction_icon_key(item_title)
	if needle == "":
		return null

	for item_variant in CampaignManager.global_inventory:
		var inv_item: Resource = item_variant
		if inv_item == null:
			continue
		if _get_item_display_name(inv_item).strip_edges().to_lower() == needle:
			var inv_icon: Texture2D = _get_auction_item_icon_texture(inv_item)
			if inv_icon != null:
				return inv_icon

	if has_node("/root/ItemDatabase"):
		var item_db: Node = get_node("/root/ItemDatabase")
		if item_db != null:
			var pool_variant: Variant = item_db.get("master_item_pool")
			if pool_variant is Array:
				var item_pool: Array = pool_variant
				for db_item_variant in item_pool:
					var db_item: Resource = db_item_variant
					if db_item == null:
						continue
					if _get_item_display_name(db_item).strip_edges().to_lower() == needle:
						var db_icon: Texture2D = _get_auction_item_icon_texture(db_item)
						if db_icon != null:
							return db_icon

	_build_auction_icon_lookup_if_needed()
	if _auction_icon_lookup_by_title.has(needle):
		var cached_variant: Variant = _auction_icon_lookup_by_title.get(needle, null)
		if cached_variant is Texture2D:
			return cached_variant
	return null


func _get_auction_listing_preview_item(listing: Dictionary) -> Resource:
	if listing.is_empty():
		return null
	var item_uid: String = str(listing.get("item_uid", "")).strip_edges()
	if item_uid != "":
		var inventory_item: Resource = _get_inventory_item_by_uid(item_uid)
		if inventory_item != null:
			return inventory_item
	return _build_auction_item_from_listing(listing)


func _get_auction_listing_icon_texture(listing: Dictionary, listing_id: String = "") -> Texture2D:
	var preview_item: Resource = _get_auction_listing_preview_item(listing)
	var tex: Texture2D = _get_auction_item_icon_texture(preview_item)
	if tex != null:
		return tex
	var item_data_variant: Variant = listing.get("item_data", {})
	if item_data_variant is Dictionary:
		var item_data: Dictionary = item_data_variant
		var data_icon: Texture2D = _get_auction_icon_from_item_data(item_data)
		if data_icon != null:
			return data_icon
	var listing_icon_path: String = str(listing.get("item_icon_path", "")).strip_edges()
	if listing_icon_path != "" and ResourceLoader.exists(listing_icon_path):
		var listing_icon_res: Resource = load(listing_icon_path)
		if listing_icon_res is Texture2D:
			return listing_icon_res
	var title_icon: Texture2D = _get_auction_icon_from_title(str(listing.get("title", "")))
	if title_icon != null:
		return title_icon
	if listing_id != "" and auction_selected_listing_icon != null and listing_id == _auction_selected_listing_id:
		if auction_selected_listing_icon.texture is Texture2D:
			return auction_selected_listing_icon.texture
	return null


func _refresh_auction_listing_draft_item_options(preferred_uid: String = "") -> void:
	if auction_listing_draft_item_option == null:
		return
	auction_listing_draft_item_option.clear()
	var preferred_idx: int = -1
	var inventory: Array[Resource] = CampaignManager.global_inventory
	for item_variant in inventory:
		var item: Resource = item_variant
		if item == null:
			continue
		var uid: String = _extract_item_uid(item)
		if uid == "":
			continue
		var short_uid: String = uid.substr(0, min(uid.length(), 8))
		var idx: int = auction_listing_draft_item_option.get_item_count()
		auction_listing_draft_item_option.add_item("%s [%s]" % [_get_item_display_name(item), short_uid])
		auction_listing_draft_item_option.set_item_metadata(idx, uid)
		if preferred_uid != "" and uid == preferred_uid:
			preferred_idx = idx
	if auction_listing_draft_item_option.get_item_count() <= 0:
		auction_listing_draft_item_option.add_item("No inventory item")
		auction_listing_draft_item_option.set_item_disabled(0, true)
		return
	if preferred_idx < 0:
		preferred_idx = 0
	auction_listing_draft_item_option.select(preferred_idx)


func _get_selected_auction_listing_draft_item_uid() -> String:
	if auction_listing_draft_item_option == null:
		return ""
	var idx: int = auction_listing_draft_item_option.selected
	if idx < 0:
		return ""
	var metadata: Variant = auction_listing_draft_item_option.get_item_metadata(idx)
	return str(metadata).strip_edges()


func _refresh_auction_listing_draft_preview() -> void:
	if auction_listing_draft_panel == null:
		return
	var item_uid: String = _get_selected_auction_listing_draft_item_uid()
	var item: Resource = _get_inventory_item_by_uid(item_uid)
	var has_valid_item: bool = item != null and item_uid != ""
	if auction_listing_draft_title != null:
		auction_listing_draft_title.text = _get_item_display_name(item) if item != null else "No item selected"
	if auction_listing_draft_uid != null:
		auction_listing_draft_uid.text = "UID: %s" % (item_uid if item_uid != "" else "--")
	if auction_listing_draft_details != null:
		auction_listing_draft_details.bbcode_enabled = true
		auction_listing_draft_details.text = _format_auction_item_details(item)
	if auction_listing_draft_icon != null:
		auction_listing_draft_icon.texture = _get_auction_item_icon_texture(item)
		auction_listing_draft_icon.modulate = Color(1, 1, 1, 1) if auction_listing_draft_icon.texture != null else Color(0.55, 0.55, 0.55, 0.85)
	if auction_listing_draft_confirm_button != null:
		auction_listing_draft_confirm_button.disabled = not has_valid_item


func _open_auction_listing_draft() -> void:
	if auction_listing_draft_panel == null:
		return
	var preferred_uid: String = ""
	if auction_my_item_option != null:
		var selected_idx: int = auction_my_item_option.selected
		if selected_idx >= 0:
			preferred_uid = str(auction_my_item_option.get_item_metadata(selected_idx)).strip_edges()
	_refresh_auction_listing_draft_item_options(preferred_uid)
	if auction_listing_draft_start_bid_input != null:
		if auction_listing_start_bid_input != null and auction_listing_start_bid_input.text.strip_edges() != "":
			auction_listing_draft_start_bid_input.text = auction_listing_start_bid_input.text.strip_edges()
		elif auction_listing_draft_start_bid_input.text.strip_edges() == "":
			auction_listing_draft_start_bid_input.text = "100"
	if auction_listing_draft_min_inc_input != null:
		if auction_listing_min_inc_input != null and auction_listing_min_inc_input.text.strip_edges() != "":
			auction_listing_draft_min_inc_input.text = auction_listing_min_inc_input.text.strip_edges()
		elif auction_listing_draft_min_inc_input.text.strip_edges() == "":
			auction_listing_draft_min_inc_input.text = "5"
	auction_listing_draft_panel.show()
	_refresh_auction_listing_draft_preview()
	if auction_listing_draft_start_bid_input != null:
		auction_listing_draft_start_bid_input.grab_focus()


func _close_auction_listing_draft() -> void:
	if auction_listing_draft_panel == null:
		return
	auction_listing_draft_panel.hide()


func _on_auction_listing_draft_item_selected(_index: int) -> void:
	_refresh_auction_listing_draft_preview()


func _refresh_auction_my_item_options() -> void:
	if auction_my_item_option == null:
		return
	var previous_draft_uid: String = _get_selected_auction_listing_draft_item_uid()
	auction_my_item_option.clear()
	var inventory: Array[Resource] = CampaignManager.global_inventory
	for item_variant in inventory:
		var item: Resource = item_variant
		if item == null:
			continue
		var uid: String = _extract_item_uid(item)
		if uid == "":
			continue
		var short_uid: String = uid.substr(0, min(uid.length(), 8))
		var idx: int = auction_my_item_option.get_item_count()
		auction_my_item_option.add_item("%s [%s]" % [_get_item_display_name(item), short_uid])
		auction_my_item_option.set_item_metadata(idx, uid)
	if auction_my_item_option.get_item_count() == 0:
		auction_my_item_option.add_item("No inventory item")
		auction_my_item_option.set_item_disabled(0, true)
	else:
		auction_my_item_option.select(0)
	if auction_listing_draft_panel != null and auction_listing_draft_panel.visible:
		_refresh_auction_listing_draft_item_options(previous_draft_uid)
		_refresh_auction_listing_draft_preview()


func _get_inventory_item_by_uid(item_uid: String) -> Resource:
	var target_uid: String = item_uid.strip_edges()
	if target_uid == "":
		return null
	var inventory: Array[Resource] = CampaignManager.global_inventory
	for item_variant in inventory:
		var item: Resource = item_variant
		if item == null:
			continue
		if _extract_item_uid(item) == target_uid:
			return item
	return null


func _get_local_auction_escrow_for_listing(listing_id: String) -> int:
	var clean_listing_id: String = listing_id.strip_edges()
	if clean_listing_id == "":
		return 0
	return maxi(int(CampaignManager.auction_gold_escrow_by_listing.get(clean_listing_id, 0)), 0)


func _set_local_auction_escrow_for_listing(listing_id: String, amount: int) -> void:
	var clean_listing_id: String = listing_id.strip_edges()
	if clean_listing_id == "":
		return
	var escrow_map: Dictionary = CampaignManager.auction_gold_escrow_by_listing
	var clamped_amount: int = maxi(amount, 0)
	if clamped_amount <= 0:
		escrow_map.erase(clean_listing_id)
	else:
		escrow_map[clean_listing_id] = clamped_amount
	CampaignManager.auction_gold_escrow_by_listing = escrow_map


func _inventory_has_item_uid(item_uid: String) -> bool:
	return _get_inventory_item_by_uid(item_uid) != null


func _build_auction_item_from_listing(listing: Dictionary) -> Resource:
	var item_data_variant: Variant = listing.get("item_data", {})
	if not (item_data_variant is Dictionary):
		return null
	var serialized_item: Dictionary = (item_data_variant as Dictionary).duplicate(true)
	var item_uid: String = str(listing.get("item_uid", "")).strip_edges()
	if item_uid != "":
		serialized_item["uid"] = item_uid
	var rebuilt_item: Resource = CampaignManager._deserialize_item(serialized_item)
	if rebuilt_item == null:
		return null
	if item_uid != "":
		rebuilt_item.set_meta("uid", item_uid)
	return rebuilt_item


func _grant_listing_item_to_local_inventory(listing: Dictionary) -> bool:
	var item_uid: String = str(listing.get("item_uid", "")).strip_edges()
	if item_uid != "" and _inventory_has_item_uid(item_uid):
		return true
	var rebuilt_item: Resource = _build_auction_item_from_listing(listing)
	if rebuilt_item == null:
		return false
	CampaignManager.global_inventory.append(rebuilt_item)
	return true


func _settle_closed_auction_listings_async() -> void:
	if _auction_cloud_listings_by_id.is_empty():
		return
	var now_unix: int = int(Time.get_unix_time_from_system())
	var local_player_id: String = _get_auction_player_id()
	var local_bidder_name: String = _get_auction_bidder_name()
	var local_economy_changed: bool = false

	if has_node("/root/SilentWolf"):
		var listing_ids: Array[String] = []
		for listing_key_variant in _auction_cloud_listings_by_id.keys():
			var listing_id_text: String = str(listing_key_variant).strip_edges()
			if listing_id_text != "":
				listing_ids.append(listing_id_text)
		for listing_id in listing_ids:
			var listing_variant: Variant = _auction_cloud_listings_by_id.get(listing_id, {})
			if not (listing_variant is Dictionary):
				continue
			var listing: Dictionary = listing_variant
			if not _listing_needs_cloud_mutation(listing, local_player_id, now_unix):
				continue
			if (await _try_acquire_listing_settlement_lock_async(listing_id, local_player_id)) == "":
				continue
			var fresh_variant: Variant = _auction_cloud_listings_by_id.get(listing_id, {})
			if not (fresh_variant is Dictionary):
				continue
			var fresh_listing: Dictionary = fresh_variant
			var fresh_status: String = str(fresh_listing.get("status", "active")).strip_edges().to_lower()
			var fresh_end: int = int(fresh_listing.get("end_timestamp_unix", 0))
			var closing_now: bool = (fresh_status == "active" and fresh_end > 0 and now_unix >= fresh_end)
			var updated_listing: Dictionary = _apply_cloud_mutation_to_listing(fresh_listing, local_player_id, now_unix)
			var previous_unlocked: Dictionary = _clear_listing_settlement_lock(fresh_listing)
			var cloud_changed: bool = (updated_listing != previous_unlocked) or closing_now
			if not cloud_changed:
				_auction_cloud_listings_by_id[listing_id] = _clear_listing_settlement_lock(fresh_listing)
				await _save_auction_listings_document_async()
				await _fetch_auction_listings_document_async()
				continue
			_auction_cloud_listings_by_id[listing_id] = updated_listing
			var saved: bool = await _save_auction_listings_document_async()
			if saved:
				await _fetch_auction_listings_document_async()

	for listing_variant in _auction_cloud_listings_by_id.values():
		if not (listing_variant is Dictionary):
			continue
		var listing: Dictionary = listing_variant
		if _apply_local_auction_outcomes_from_listing(listing, local_player_id, local_bidder_name):
			local_economy_changed = true

	if local_economy_changed:
		CampaignManager.save_current_progress()


func _apply_local_auction_outcomes_from_listing(listing: Dictionary, local_player_id: String, local_bidder_name: String) -> bool:
	var listing_id: String = str(listing.get("listing_id", "")).strip_edges()
	if listing_id == "":
		return false
	var listing_title: String = str(listing.get("title", "Listing")).strip_edges()
	if listing_title == "":
		listing_title = "Listing"
	var status: String = str(listing.get("status", "active")).strip_edges().to_lower()
	var local_changed: bool = false
	var escrow_amount: int = _get_local_auction_escrow_for_listing(listing_id)

	if status == "active" and escrow_amount > 0:
		var active_top_bid: Dictionary = _auction_highest_by_listing.get(listing_id, {})
		var active_top_bidder_id: String = str(active_top_bid.get("bidder_id", "")).strip_edges()
		var active_top_bidder_name: String = str(active_top_bid.get("bidder", "")).strip_edges()
		var is_local_top_bidder: bool = false
		if local_player_id != "" and active_top_bidder_id != "":
			is_local_top_bidder = (active_top_bidder_id == local_player_id)
		elif local_bidder_name != "" and active_top_bidder_name != "":
			is_local_top_bidder = (active_top_bidder_name == local_bidder_name)
		if not is_local_top_bidder:
			CampaignManager.global_gold += escrow_amount
			_set_local_auction_escrow_for_listing(listing_id, 0)
			local_changed = true
			_push_auction_notification("Outbid on %s (+%dG refunded)." % [listing_title, escrow_amount], "#ffb26a")

	if status == "sold":
		var winner_id: String = str(listing.get("winner_id", "")).strip_edges()
		var seller_id: String = str(listing.get("seller_id", "")).strip_edges()
		var final_bid: int = maxi(int(listing.get("final_bid", 0)), 0)
		if escrow_amount > 0:
			if local_player_id != "" and winner_id == local_player_id:
				_set_local_auction_escrow_for_listing(listing_id, 0)
				local_changed = true
				_push_auction_notification("Winning escrow finalized for %s (%dG)." % [listing_title, escrow_amount], "#8fe28e")
			else:
				CampaignManager.global_gold += escrow_amount
				_set_local_auction_escrow_for_listing(listing_id, 0)
				local_changed = true
				_push_auction_notification("Escrow returned for %s (+%dG)." % [listing_title, escrow_amount], "#9be8ff")

		if local_player_id != "" and seller_id == local_player_id and bool(listing.get("seller_paid", false)):
			var seller_receipt_id: String = "%s:seller_paid" % listing_id
			if not _has_local_auction_receipt(seller_receipt_id):
				if final_bid > 0:
					CampaignManager.global_gold += final_bid
					local_changed = true
				_mark_local_auction_receipt(seller_receipt_id)
				_push_auction_notification("Sold %s for %dG." % [listing_title, final_bid], "#f8d86a")

		if local_player_id != "" and winner_id == local_player_id and bool(listing.get("delivered_to_winner", false)):
			var winner_receipt_id: String = "%s:winner_item" % listing_id
			if not _has_local_auction_receipt(winner_receipt_id):
				if _grant_listing_item_to_local_inventory(listing):
					_mark_local_auction_receipt(winner_receipt_id)
					local_changed = true
					_push_auction_notification("Won %s and item delivered." % listing_title, "#8fe28e")

	elif status == "expired" or status == "cancelled":
		var expired_seller_id: String = str(listing.get("seller_id", "")).strip_edges()
		if escrow_amount > 0:
			CampaignManager.global_gold += escrow_amount
			_set_local_auction_escrow_for_listing(listing_id, 0)
			local_changed = true
			_push_auction_notification("Auction closed on %s (+%dG refunded)." % [listing_title, escrow_amount], "#9be8ff")
		if local_player_id != "" and expired_seller_id == local_player_id and bool(listing.get("returned_to_seller", false)):
			var return_receipt_id: String = "%s:seller_returned" % listing_id
			if not _has_local_auction_receipt(return_receipt_id):
				if _grant_listing_item_to_local_inventory(listing):
					_mark_local_auction_receipt(return_receipt_id)
					local_changed = true
					_push_auction_notification("%s returned to your inventory." % listing_title, "#8fe28e")

	return local_changed


func _build_default_cloud_auction_listings() -> Dictionary:
	var out: Dictionary = {}
	for listing_variant in _get_active_auction_listings():
		var listing: Dictionary = listing_variant
		var listing_id: String = str(listing.get("listing_id", "")).strip_edges()
		if listing_id == "":
			listing_id = _generate_auction_uuid()
		var payload: Dictionary = listing.duplicate(true)
		payload["listing_id"] = listing_id
		payload["status"] = str(payload.get("status", "active")).to_lower()
		payload["seller_name"] = str(payload.get("seller_name", "War Table"))
		payload["seller_id"] = str(payload.get("seller_id", "system"))
		payload["item_uid"] = str(payload.get("item_uid", ""))
		payload["item_data"] = payload.get("item_data", {})
		payload["winner_id"] = str(payload.get("winner_id", ""))
		payload["winner_name"] = str(payload.get("winner_name", ""))
		payload["final_bid"] = maxi(int(payload.get("final_bid", 0)), 0)
		payload["seller_paid"] = bool(payload.get("seller_paid", false))
		payload["delivered_to_winner"] = bool(payload.get("delivered_to_winner", false))
		payload["returned_to_seller"] = bool(payload.get("returned_to_seller", false))
		payload["closed_at"] = int(payload.get("closed_at", 0))
		payload["settlement_lock_owner"] = str(payload.get("settlement_lock_owner", ""))
		payload["settlement_lock_token"] = str(payload.get("settlement_lock_token", ""))
		payload["settlement_lock_until"] = int(payload.get("settlement_lock_until", 0))
		payload["settlement_lock_at"] = int(payload.get("settlement_lock_at", 0))
		payload["pending_local"] = bool(payload.get("pending_local", false))
		out[listing_id] = payload
	return out


func _merge_pending_local_listings(loaded_listings: Dictionary, previous_local: Dictionary) -> Dictionary:
	var merged: Dictionary = loaded_listings.duplicate(true)
	for listing_id_variant in previous_local.keys():
		var listing_id: String = str(listing_id_variant).strip_edges()
		if listing_id == "":
			continue
		var local_listing_variant: Variant = previous_local.get(listing_id_variant, {})
		if not (local_listing_variant is Dictionary):
			continue
		var local_listing: Dictionary = local_listing_variant
		if not bool(local_listing.get("pending_local", false)):
			continue
		merged[listing_id] = local_listing.duplicate(true)
	return merged


func _merge_campaign_pending_local_listings(runtime_listings: Dictionary) -> Dictionary:
	var merged: Dictionary = runtime_listings.duplicate(true)
	var pending_variant: Variant = CampaignManager.auction_pending_local_listings_by_id
	if not (pending_variant is Dictionary):
		return merged
	var pending_map: Dictionary = pending_variant
	for listing_id_variant in pending_map.keys():
		var listing_id: String = str(listing_id_variant).strip_edges()
		if listing_id == "":
			continue
		var payload_variant: Variant = pending_map.get(listing_id_variant, {})
		if not (payload_variant is Dictionary):
			continue
		var payload: Dictionary = (payload_variant as Dictionary).duplicate(true)
		payload["pending_local"] = true
		payload["listing_id"] = listing_id
		merged[listing_id] = payload
	return merged


func _persist_pending_local_listings_to_campaign(save_now: bool = false) -> void:
	var pending_cache: Dictionary = {}
	for listing_id_variant in _auction_cloud_listings_by_id.keys():
		var listing_id: String = str(listing_id_variant).strip_edges()
		if listing_id == "":
			continue
		var listing_variant: Variant = _auction_cloud_listings_by_id.get(listing_id_variant, {})
		if not (listing_variant is Dictionary):
			continue
		var listing: Dictionary = listing_variant
		if not bool(listing.get("pending_local", false)):
			continue
		pending_cache[listing_id] = listing.duplicate(true)
	CampaignManager.auction_pending_local_listings_by_id = pending_cache
	if save_now:
		CampaignManager.save_current_progress()


func _load_shared_auction_listings_cache() -> Dictionary:
	if not FileAccess.file_exists(AUCTION_SHARED_CACHE_PATH):
		return {}
	var file: FileAccess = FileAccess.open(AUCTION_SHARED_CACHE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var raw_text: String = file.get_as_text()
	if raw_text.strip_edges() == "":
		return {}
	var parsed_variant: Variant = JSON.parse_string(raw_text)
	if not (parsed_variant is Dictionary):
		return {}
	var parsed: Dictionary = parsed_variant
	var listings_variant: Variant = parsed.get("listings", {})
	if listings_variant is Dictionary:
		return (listings_variant as Dictionary).duplicate(true)
	return {}


func _save_shared_auction_listings_cache(listings: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(AUCTION_SHARED_CACHE_PATH, FileAccess.WRITE)
	if file == null:
		return
	var payload: Dictionary = {
		"schema": 1,
		"updated_at": int(Time.get_unix_time_from_system()),
		"listings": listings.duplicate(true)
	}
	file.store_string(JSON.stringify(payload))


func _merge_missing_auction_listings(primary_listings: Dictionary, fallback_listings: Dictionary) -> Dictionary:
	var merged: Dictionary = primary_listings.duplicate(true)
	for listing_id_variant in fallback_listings.keys():
		var listing_id: String = str(listing_id_variant).strip_edges()
		if listing_id == "":
			continue
		if merged.has(listing_id):
			continue
		var fallback_variant: Variant = fallback_listings.get(listing_id_variant, {})
		if not (fallback_variant is Dictionary):
			continue
		merged[listing_id] = (fallback_variant as Dictionary).duplicate(true)
	return merged


func _fetch_auction_listings_document_async() -> void:
	var previous_local: Dictionary = _auction_cloud_listings_by_id.duplicate(true)
	var shared_cache: Dictionary = _load_shared_auction_listings_cache()
	if not has_node("/root/SilentWolf"):
		if _auction_cloud_listings_by_id.is_empty():
			if not shared_cache.is_empty():
				_auction_cloud_listings_by_id = shared_cache.duplicate(true)
			elif auction_use_default_if_empty:
				_auction_cloud_listings_by_id = _build_default_cloud_auction_listings()
		_auction_cloud_listings_by_id = _merge_pending_local_listings(_auction_cloud_listings_by_id, previous_local)
		_auction_cloud_listings_by_id = _merge_campaign_pending_local_listings(_auction_cloud_listings_by_id)
		_save_shared_auction_listings_cache(_auction_cloud_listings_by_id)
		return
	var sw_result: Variant = await SilentWolf.Players.get_player_data(_auction_document_name()).sw_get_player_data_complete
	var loaded_listings: Dictionary = {}
	var fetch_success: bool = false
	if sw_result is Dictionary and bool(sw_result.get("success", false)):
		fetch_success = true
		var player_data_variant: Variant = sw_result.get("player_data", {})
		if player_data_variant is Dictionary:
			var player_data: Dictionary = player_data_variant
			var listings_variant: Variant = player_data.get("listings", {})
			if listings_variant is Dictionary:
				var raw_listings: Dictionary = listings_variant
				for listing_id_variant in raw_listings.keys():
					var listing_payload_variant: Variant = raw_listings.get(listing_id_variant, {})
					if listing_payload_variant is Dictionary:
						var listing_payload: Dictionary = listing_payload_variant
						var normalized: Dictionary = listing_payload.duplicate(true)
						var listing_id: String = str(normalized.get("listing_id", listing_id_variant)).strip_edges()
						if listing_id == "":
							listing_id = _generate_auction_uuid()
						normalized["listing_id"] = listing_id
						normalized["status"] = str(normalized.get("status", "active")).to_lower()
						normalized["seller_name"] = str(normalized.get("seller_name", "Unknown Seller"))
						normalized["seller_id"] = str(normalized.get("seller_id", ""))
						normalized["item_uid"] = str(normalized.get("item_uid", ""))
						normalized["item_data"] = normalized.get("item_data", {})
						normalized["winner_id"] = str(normalized.get("winner_id", ""))
						normalized["winner_name"] = str(normalized.get("winner_name", ""))
						normalized["final_bid"] = maxi(int(normalized.get("final_bid", 0)), 0)
						normalized["seller_paid"] = bool(normalized.get("seller_paid", false))
						normalized["delivered_to_winner"] = bool(normalized.get("delivered_to_winner", false))
						normalized["returned_to_seller"] = bool(normalized.get("returned_to_seller", false))
						normalized["closed_at"] = int(normalized.get("closed_at", 0))
						normalized["settlement_lock_owner"] = str(normalized.get("settlement_lock_owner", ""))
						normalized["settlement_lock_token"] = str(normalized.get("settlement_lock_token", ""))
						normalized["settlement_lock_until"] = int(normalized.get("settlement_lock_until", 0))
						normalized["settlement_lock_at"] = int(normalized.get("settlement_lock_at", 0))
						normalized["pending_local"] = false
						normalized["created_at"] = int(normalized.get("created_at", int(Time.get_unix_time_from_system())))
						loaded_listings[listing_id] = normalized
	if fetch_success:
		if not shared_cache.is_empty():
			loaded_listings = _merge_missing_auction_listings(loaded_listings, shared_cache)
		if loaded_listings.is_empty() and auction_use_default_if_empty:
			loaded_listings = _build_default_cloud_auction_listings()
			_auction_cloud_listings_by_id = _merge_pending_local_listings(loaded_listings, previous_local)
			_auction_cloud_listings_by_id = _merge_campaign_pending_local_listings(_auction_cloud_listings_by_id)
			await _save_auction_listings_document_async()
		else:
			_auction_cloud_listings_by_id = _merge_pending_local_listings(loaded_listings, previous_local)
			_auction_cloud_listings_by_id = _merge_campaign_pending_local_listings(_auction_cloud_listings_by_id)
	else:
		if not shared_cache.is_empty():
			_auction_cloud_listings_by_id = shared_cache.duplicate(true)
		elif not previous_local.is_empty():
			_auction_cloud_listings_by_id = previous_local.duplicate(true)
		elif auction_use_default_if_empty:
			_auction_cloud_listings_by_id = _build_default_cloud_auction_listings()
		_auction_cloud_listings_by_id = _merge_campaign_pending_local_listings(_auction_cloud_listings_by_id)
	_save_shared_auction_listings_cache(_auction_cloud_listings_by_id)


func _save_auction_listings_document_async() -> bool:
	if not has_node("/root/SilentWolf"):
		return false
	var cloud_safe_listings: Dictionary = {}
	for listing_id_variant in _auction_cloud_listings_by_id.keys():
		var listing_id: String = str(listing_id_variant).strip_edges()
		if listing_id == "":
			continue
		var listing_variant: Variant = _auction_cloud_listings_by_id.get(listing_id_variant, {})
		if not (listing_variant is Dictionary):
			continue
		var listing_payload: Dictionary = (listing_variant as Dictionary).duplicate(true)
		listing_payload.erase("pending_local")
		cloud_safe_listings[listing_id] = listing_payload
	var payload: Dictionary = {
		"schema": 1,
		"updated_at": int(Time.get_unix_time_from_system()),
		"listings": cloud_safe_listings
	}
	var sw_result: Variant = await SilentWolf.Players.save_player_data(_auction_document_name(), payload, true).sw_save_player_data_complete
	if sw_result is Dictionary and bool(sw_result.get("success", false)):
		_save_shared_auction_listings_cache(_auction_cloud_listings_by_id)
		return true
	return false


func _has_pending_local_auction_entries() -> bool:
	for listing_variant in _auction_cloud_listings_by_id.values():
		if not (listing_variant is Dictionary):
			continue
		var listing: Dictionary = listing_variant
		if bool(listing.get("pending_local", false)):
			return true
	return false


func _sync_pending_local_auction_entries_async() -> void:
	if not has_node("/root/SilentWolf"):
		return
	if not _has_pending_local_auction_entries():
		return
	var saved: bool = await _save_auction_listings_document_async()
	if not saved:
		return
	var changed: bool = false
	for listing_id_variant in _auction_cloud_listings_by_id.keys():
		var listing_variant: Variant = _auction_cloud_listings_by_id.get(listing_id_variant, {})
		if not (listing_variant is Dictionary):
			continue
		var listing: Dictionary = (listing_variant as Dictionary).duplicate(true)
		if bool(listing.get("pending_local", false)):
			listing["pending_local"] = false
			_auction_cloud_listings_by_id[str(listing_id_variant)] = listing
			changed = true
	if changed:
		_push_auction_notification("Pending local listing sync complete.", "#8fe28e")
	_persist_pending_local_listings_to_campaign(changed)


func _get_active_auction_listings() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _auction_cloud_listings_by_id.is_empty():
		for listing_variant in _auction_cloud_listings_by_id.values():
			if listing_variant is Dictionary:
				result.append(listing_variant)
		return result
	for listing_variant in auction_listings:
		var listing_res: Resource = listing_variant
		if listing_res == null:
			continue
		var listing_id: String = str(_resource_get(listing_res, "listing_id", "")).strip_edges()
		if listing_id == "":
			listing_id = "listing_%d" % result.size()
		var title: String = str(_resource_get(listing_res, "title", "")).strip_edges()
		if title == "":
			title = "Auction Listing"
		var summary: String = str(_resource_get(listing_res, "summary", "")).strip_edges()
		var starting_bid: int = maxi(int(_resource_get(listing_res, "starting_bid", 100)), 0)
		var min_increment: int = maxi(int(_resource_get(listing_res, "min_increment", 5)), 1)
		var end_timestamp_unix: int = int(_resource_get(listing_res, "end_timestamp_unix", 0))
		var item_uid: String = str(_resource_get(listing_res, "item_uid", "")).strip_edges()
		var seller_name: String = str(_resource_get(listing_res, "seller_name", "War Table")).strip_edges()
		var seller_id: String = str(_resource_get(listing_res, "seller_id", "system")).strip_edges()
		var status: String = str(_resource_get(listing_res, "status", "active")).strip_edges().to_lower()
		result.append({
			"listing_id": listing_id,
			"title": title,
			"summary": summary,
			"starting_bid": starting_bid,
			"min_increment": min_increment,
			"end_timestamp_unix": end_timestamp_unix,
			"item_uid": item_uid,
			"seller_name": seller_name if seller_name != "" else "War Table",
			"seller_id": seller_id if seller_id != "" else "system",
			"status": status if status != "" else "active",
			"item_data": {},
			"winner_id": "",
			"winner_name": "",
			"final_bid": 0,
			"seller_paid": false,
			"delivered_to_winner": false,
			"returned_to_seller": false,
			"closed_at": 0,
			"settlement_lock_owner": "",
			"settlement_lock_token": "",
			"settlement_lock_until": 0,
			"settlement_lock_at": 0,
			"pending_local": false,
			"created_at": int(Time.get_unix_time_from_system())
		})
	return result


func _get_auction_listing_by_id(listing_id: String) -> Dictionary:
	var listings: Array[Dictionary] = _get_active_auction_listings()
	for listing_variant in listings:
		var listing: Dictionary = listing_variant
		if str(listing.get("listing_id", "")) == listing_id:
			return listing
	return {}


func _parse_auction_metadata(raw_metadata: Variant) -> Dictionary:
	if raw_metadata is Dictionary:
		return raw_metadata
	if raw_metadata is String:
		var parsed: Variant = JSON.parse_string(raw_metadata)
		if parsed is Dictionary:
			return parsed
	return {}


func _format_auction_time_left(end_timestamp_unix: int) -> String:
	if end_timestamp_unix <= 0:
		return "OPEN CYCLE"
	var now_unix: int = int(Time.get_unix_time_from_system())
	var remaining: int = end_timestamp_unix - now_unix
	if remaining <= 0:
		return "CLOSED"
	var days: int = remaining / 86400
	var hours: int = (remaining % 86400) / 3600
	var minutes: int = (remaining % 3600) / 60
	if days > 0:
		return "%dd %dh left" % [days, hours]
	return "%dh %dm left" % [hours, minutes]


func _get_auction_bidder_name() -> String:
	return CampaignManager.get_player_display_name("Commander")


func _open_auction_house() -> void:
	if select_sound:
		select_sound.play()
	if token_shop_panel:
		token_shop_panel.hide()
	if arena_setup_panel:
		arena_setup_panel.hide()
	if arena_panel:
		arena_panel.hide()
	if leaderboard_panel:
		leaderboard_panel.hide()
	_hide_unit_info_panel_immediate()
	if auction_panel == null:
		return
	_apply_auction_ui_theme()
	auction_panel.show()
	_close_auction_listing_draft()
	_setup_auction_filter_controls()
	if auction_my_gold_label != null:
		auction_my_gold_label.text = "Your Gold: %d" % int(CampaignManager.global_gold)
	_refresh_auction_my_item_options()
	_refresh_auction_notifications_view()
	_ensure_auction_listings()
	_rebuild_auction_listing_buttons()
	_refresh_auction_selected_view()
	_refresh_auction_market_badge()
	_refresh_auction_house_async()
	_refresh_auction_control_state()
	if _auction_poll_timer != null:
		_auction_poll_timer.wait_time = clampf(auction_refresh_seconds, 3.0, 60.0)
		_auction_poll_timer.start()


func _close_auction_house() -> void:
	if auction_panel != null:
		auction_panel.hide()
	_close_auction_listing_draft()
	if _auction_poll_timer != null:
		_auction_poll_timer.stop()


func _rebuild_auction_listing_buttons() -> void:
	if auction_listings_container == null:
		return
	_auction_row_icon_by_listing.clear()
	for child_variant in auction_listings_container.get_children():
		var child_node: Node = child_variant
		child_node.queue_free()

	var listings: Array[Dictionary] = _get_filtered_sorted_auction_listings()
	if listings.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No listings match the active filters."
		_auction_style_label(empty_label, AUCTION_THEME_MUTED, 16, 1)
		auction_listings_container.add_child(empty_label)
		_auction_selected_listing_id = ""
		_refresh_auction_market_badge()
		return

	var selected_still_visible: bool = false
	for listing_variant in listings:
		var listing_id_check: String = str(listing_variant.get("listing_id", ""))
		if listing_id_check == _auction_selected_listing_id:
			selected_still_visible = true
			break
	if not selected_still_visible:
		_auction_selected_listing_id = ""
	if _auction_selected_listing_id == "":
		_auction_selected_listing_id = str(listings[0].get("listing_id", ""))

	for listing_variant in listings:
		var listing: Dictionary = listing_variant
		var listing_id: String = str(listing.get("listing_id", ""))
		var bid_data: Dictionary = _auction_highest_by_listing.get(listing_id, {})
		var highest_bid: int = int(bid_data.get("bid_amount", -1))
		if highest_bid < 0:
			highest_bid = int(listing.get("starting_bid", 0))
		var bidder_text: String = str(bid_data.get("bidder", "NO BIDS YET"))
		var status_text: String = str(listing.get("status", "active")).to_upper()
		if status_text == "SOLD":
			highest_bid = maxi(int(listing.get("final_bid", highest_bid)), highest_bid)
			var winner_name: String = str(listing.get("winner_name", "")).strip_edges()
			if winner_name != "":
				bidder_text = winner_name
		var local_player_id: String = _get_auction_player_id()
		var seller_id: String = str(listing.get("seller_id", "")).strip_edges()
		var owner_tag: String = "YOUR LISTING" if (local_player_id != "" and seller_id == local_player_id) else status_text

		var row: HBoxContainer = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 96)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 10)

		var normal_fill: Color = Color(0.12, 0.09, 0.06, 0.95)
		var normal_border: Color = AUCTION_THEME_BORDER_SOFT
		var hover_fill: Color = Color(0.17, 0.13, 0.08, 0.98)
		var hover_border: Color = AUCTION_THEME_BORDER
		if status_text == "SOLD":
			normal_border = AUCTION_THEME_GOOD
			hover_border = AUCTION_THEME_GOOD.lightened(0.08)
		elif status_text == "EXPIRED" or status_text == "CANCELLED":
			normal_border = AUCTION_THEME_DANGER
			hover_border = AUCTION_THEME_DANGER.lightened(0.08)
		elif status_text == "ACTIVE":
			normal_border = AUCTION_THEME_ACCENT
			hover_border = AUCTION_THEME_ACCENT.lightened(0.08)

		var icon_slot: Panel = Panel.new()
		icon_slot.custom_minimum_size = Vector2(66, 66)
		icon_slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		icon_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_slot.add_theme_stylebox_override("panel", _auction_make_stylebox(Color(0.08, 0.06, 0.04, 0.98), normal_border, 10, 2))

		var icon_holder: CenterContainer = CenterContainer.new()
		icon_holder.anchors_preset = Control.PRESET_FULL_RECT
		icon_holder.offset_left = 4
		icon_holder.offset_top = 4
		icon_holder.offset_right = -4
		icon_holder.offset_bottom = -4
		icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_slot.add_child(icon_holder)

		var icon: TextureRect = TextureRect.new()
		icon.custom_minimum_size = Vector2(50, 50)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.z_index = 5
		icon.texture = _get_auction_listing_icon_texture(listing, listing_id)
		icon.modulate = Color(1, 1, 1, 1) if icon.texture != null else Color(0.55, 0.55, 0.55, 0.85)
		icon_holder.add_child(icon)
		if listing_id != "":
			_auction_row_icon_by_listing[listing_id] = icon
		if icon.texture == null:
			var icon_fallback: Label = Label.new()
			icon_fallback.anchors_preset = Control.PRESET_FULL_RECT
			icon_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon_fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			icon_fallback.text = _get_auction_fallback_tag(str(listing.get("title", "")))
			_auction_style_label(icon_fallback, AUCTION_THEME_MUTED.lightened(0.12), 14, 1)
			icon_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_holder.add_child(icon_fallback)

		var listing_button: Button = Button.new()
		listing_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		listing_button.custom_minimum_size = Vector2(0, 96)
		listing_button.text = "%s\nTop Bid: %dG  //  %s  //  %s" % [str(listing.get("title", "Listing")), highest_bid, bidder_text, owner_tag]
		listing_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_auction_style_button(listing_button, false, 16, 96.0)
		listing_button.add_theme_stylebox_override("normal", _auction_make_stylebox(normal_fill, normal_border, 14, 2))
		listing_button.add_theme_stylebox_override("hover", _auction_make_stylebox(hover_fill, hover_border, 14, 4))
		listing_button.add_theme_stylebox_override("pressed", _auction_make_stylebox(hover_fill.darkened(0.08), hover_border, 14, 3))
		listing_button.add_theme_stylebox_override("focus", _auction_make_stylebox(hover_fill, AUCTION_THEME_ACCENT, 14, 4))
		if listing_id == _auction_selected_listing_id:
			listing_button.add_theme_stylebox_override("normal", _auction_make_stylebox(Color(0.18, 0.14, 0.09, 0.98), AUCTION_THEME_ACCENT, 14, 6))
			icon_slot.add_theme_stylebox_override("panel", _auction_make_stylebox(Color(0.12, 0.09, 0.06, 0.98), AUCTION_THEME_ACCENT, 10, 4))
		listing_button.pressed.connect(_select_auction_listing.bind(listing_id))

		row.add_child(icon_slot)
		row.add_child(listing_button)
		auction_listings_container.add_child(row)

	_sync_selected_listing_row_icon()
	_refresh_auction_market_badge()


func _select_auction_listing(listing_id: String) -> void:
	_auction_selected_listing_id = listing_id
	_rebuild_auction_listing_buttons()
	_refresh_auction_selected_view()


func _sync_selected_listing_row_icon() -> void:
	if _auction_selected_listing_id == "":
		return
	if auction_selected_listing_icon == null:
		return
	var selected_tex: Texture2D = auction_selected_listing_icon.texture if (auction_selected_listing_icon.texture is Texture2D) else null
	if selected_tex == null:
		return
	var row_icon_variant: Variant = _auction_row_icon_by_listing.get(_auction_selected_listing_id, null)
	if row_icon_variant is TextureRect:
		var row_icon: TextureRect = row_icon_variant
		row_icon.texture = selected_tex
		row_icon.modulate = Color(1, 1, 1, 1)


func _refresh_auction_selected_view() -> void:
	if auction_selected_listing_label == null:
		return
	var listing: Dictionary = _get_auction_listing_by_id(_auction_selected_listing_id)
	if listing.is_empty():
		auction_selected_listing_label.text = "[center]Select a listing.[/center]"
		if auction_selected_listing_icon != null:
			auction_selected_listing_icon.texture = null
			auction_selected_listing_icon.modulate = Color(0.55, 0.55, 0.55, 0.85)
		if auction_place_bid_button != null:
			auction_place_bid_button.disabled = true
		_refresh_auction_control_state()
		return
	var listing_id: String = str(listing.get("listing_id", ""))
	var status_text: String = str(listing.get("status", "active")).strip_edges().to_lower()
	var bid_data: Dictionary = _auction_highest_by_listing.get(listing_id, {})
	var highest_bid: int = int(bid_data.get("bid_amount", -1))
	var top_bidder: String = str(bid_data.get("bidder", "No bids yet"))
	var starting_bid: int = int(listing.get("starting_bid", 0))
	var min_increment: int = int(listing.get("min_increment", 1))
	if highest_bid < 0:
		highest_bid = starting_bid
		top_bidder = "No bids yet"
	var min_next_bid: int = maxi(starting_bid, highest_bid + min_increment)
	var premium_delta: int = maxi(highest_bid - starting_bid, 0)
	var premium_percent: int = 0
	if starting_bid > 0:
		premium_percent = int(round((float(premium_delta) / float(starting_bid)) * 100.0))
	var end_timestamp_unix: int = int(listing.get("end_timestamp_unix", 0))
	var time_left_text: String = _format_auction_time_left(end_timestamp_unix)
	var item_uid: String = str(listing.get("item_uid", "")).strip_edges()
	var seller_name: String = str(listing.get("seller_name", "Unknown Seller"))
	var local_escrow: int = _get_local_auction_escrow_for_listing(listing_id)
	var local_player_id: String = _get_auction_player_id()
	var seller_id: String = str(listing.get("seller_id", "")).strip_edges()
	var is_own_listing: bool = (local_player_id != "" and seller_id == local_player_id)
	if auction_selected_listing_icon != null:
		auction_selected_listing_icon.texture = _get_auction_listing_icon_texture(listing, listing_id)
		auction_selected_listing_icon.modulate = Color(1, 1, 1, 1) if auction_selected_listing_icon.texture != null else Color(0.55, 0.55, 0.55, 0.85)
	_sync_selected_listing_row_icon()
	if status_text == "sold":
		highest_bid = maxi(int(listing.get("final_bid", highest_bid)), highest_bid)
		top_bidder = str(listing.get("winner_name", top_bidder))
	elif status_text == "expired":
		time_left_text = "CLOSED // EXPIRED"
	auction_selected_listing_label.text = (
		"[b]%s[/b]\n"
		+ "[color=#7cd8ff]%s[/color]\n"
		+ "[color=#8fe28e]Seller: %s[/color]\n"
		+ "[color=#ffd87a]Item UID: %s[/color]\n\n"
		+ "%s\n\n"
		+ "Top Bid: [color=gold]%dG[/color] by %s\n"
		+ "Minimum Next Bid: [color=yellow]%dG[/color]\n"
		+ "Market Premium: [color=#9be8ff]+%dG[/color] (%d%% over entry)\n"
		+ "Your Escrow: [color=#9be8ff]%dG[/color]\n"
		+ "Window: %s"
	) % [
		str(listing.get("title", "Listing")),
		str(listing.get("listing_id", "")),
		seller_name,
		item_uid if item_uid != "" else "--",
		str(listing.get("summary", "")),
		highest_bid,
		top_bidder,
		min_next_bid,
		premium_delta,
		premium_percent,
		local_escrow,
		time_left_text
	]
	var item_data_sel: Variant = listing.get("item_data", {})
	if item_data_sel is Dictionary:
		var rune_sel: String = WeaponRuneDisplayHelpers.format_runes_bbcode_for_item_variant(item_data_sel as Dictionary)
		if rune_sel != "":
			auction_selected_listing_label.text += "\n\n" + rune_sel
	if auction_bid_input != null:
		auction_bid_input.placeholder_text = "Enter %d or more" % min_next_bid
	var can_bid: bool = (status_text == "active" and time_left_text != "CLOSED" and not is_own_listing)
	if auction_place_bid_button != null and not (_auction_fetch_in_flight or _auction_bid_in_flight or _auction_listing_in_flight):
		auction_place_bid_button.disabled = not can_bid
	if auction_bid_input != null:
		auction_bid_input.editable = can_bid and not (_auction_fetch_in_flight or _auction_bid_in_flight or _auction_listing_in_flight)
		if is_own_listing:
			auction_bid_input.placeholder_text = "You cannot bid your own listing"
	_refresh_auction_control_state()


func _refresh_auction_house_async() -> void:
	if _auction_fetch_in_flight:
		_auction_refresh_queued = true
		return
	_auction_fetch_in_flight = true
	_refresh_auction_control_state()
	_set_auction_status("Syncing auction feed...", Color(0.55, 0.86, 1.0, 1.0))
	await _fetch_auction_listings_document_async()

	if not has_node("/root/SilentWolf"):
		await _settle_closed_auction_listings_async()
		_auction_fetch_in_flight = false
		_refresh_auction_control_state()
		if auction_my_gold_label != null:
			auction_my_gold_label.text = "Your Gold: %d" % int(CampaignManager.global_gold)
		_set_auction_status("Offline mode: using local view only.", Color(0.95, 0.75, 0.35, 1.0))
		_rebuild_auction_listing_buttons()
		_refresh_auction_selected_view()
		if _auction_refresh_queued:
			_auction_refresh_queued = false
			call_deferred("_refresh_auction_house_async")
		return

	var sw_result: Variant = await SilentWolf.Scores.get_scores(250, auction_leaderboard_name).sw_get_scores_complete
	var scores: Array = []
	if sw_result is Dictionary:
		var sw_scores_variant: Variant = sw_result.get("scores", [])
		if sw_scores_variant is Array:
			scores = sw_scores_variant
	if scores.is_empty():
		var cached_scores_variant: Variant = SilentWolf.Scores.scores
		if cached_scores_variant is Array:
			scores = cached_scores_variant

	var best_by_listing: Dictionary = {}
	for entry_variant in scores:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var metadata: Dictionary = _parse_auction_metadata(entry.get("metadata", {}))
		var listing_id: String = str(metadata.get("listing_id", "")).strip_edges()
		if listing_id == "":
			continue
		var bid_amount: int = int(entry.get("score", metadata.get("bid_amount", 0)))
		var bidder: String = str(entry.get("player_name", metadata.get("bidder", "Unknown"))).strip_edges()
		var bidder_id: String = str(metadata.get("bidder_id", "")).strip_edges()
		var submitted_at: int = int(metadata.get("submitted_at", 0))
		var current_best: Dictionary = best_by_listing.get(listing_id, {})
		if current_best.is_empty():
			best_by_listing[listing_id] = {
				"bid_amount": bid_amount,
				"bidder": bidder,
				"bidder_id": bidder_id,
				"submitted_at": submitted_at
			}
			continue
		var current_bid: int = int(current_best.get("bid_amount", -1))
		var current_time: int = int(current_best.get("submitted_at", 0))
		if bid_amount > current_bid or (bid_amount == current_bid and submitted_at > current_time):
			best_by_listing[listing_id] = {
				"bid_amount": bid_amount,
				"bidder": bidder,
				"bidder_id": bidder_id,
				"submitted_at": submitted_at
			}

	_auction_highest_by_listing = best_by_listing
	await _settle_closed_auction_listings_async()
	await _sync_pending_local_auction_entries_async()
	_auction_fetch_in_flight = false
	_refresh_auction_control_state()
	_refresh_auction_my_item_options()
	if auction_my_gold_label != null:
		auction_my_gold_label.text = "Your Gold: %d" % int(CampaignManager.global_gold)
	_set_auction_status("Live feed synced at %s." % Time.get_time_string_from_system(), Color(0.56, 0.93, 0.60, 1.0))
	_rebuild_auction_listing_buttons()
	_refresh_auction_selected_view()
	if _auction_refresh_queued:
		_auction_refresh_queued = false
		call_deferred("_refresh_auction_house_async")


func _on_auction_poll_timeout() -> void:
	if auction_panel == null or not auction_panel.visible:
		return
	_refresh_auction_house_async()


func _on_auction_bid_text_submitted(_new_text: String) -> void:
	_on_auction_place_bid_pressed()


func _on_auction_place_bid_pressed() -> void:
	if _auction_bid_in_flight or _auction_listing_in_flight:
		return
	var listing: Dictionary = _get_auction_listing_by_id(_auction_selected_listing_id)
	if listing.is_empty():
		_set_auction_status("Select a listing first.", Color(0.98, 0.52, 0.48, 1.0))
		return
	if str(listing.get("status", "active")).to_lower() != "active":
		_set_auction_status("This listing is no longer active.", Color(0.98, 0.52, 0.48, 1.0))
		return
	var local_player_id: String = _get_auction_player_id()
	var seller_id: String = str(listing.get("seller_id", "")).strip_edges()
	if local_player_id != "" and seller_id == local_player_id:
		_set_auction_status("You cannot bid on your own listing.", Color(0.98, 0.52, 0.48, 1.0))
		return
	if auction_bid_input == null:
		return
	var bid_text: String = auction_bid_input.text.strip_edges().replace(",", "")
	if not bid_text.is_valid_int():
		_set_auction_status("Bid must be a whole number.", Color(0.98, 0.52, 0.48, 1.0))
		return
	var bid_amount: int = int(bid_text)
	if bid_amount <= 0:
		_set_auction_status("Bid must be above zero.", Color(0.98, 0.52, 0.48, 1.0))
		return

	var end_timestamp_unix: int = int(listing.get("end_timestamp_unix", 0))
	if end_timestamp_unix > 0 and int(Time.get_unix_time_from_system()) >= end_timestamp_unix:
		_set_auction_status("This listing is closed.", Color(0.98, 0.52, 0.48, 1.0))
		return

	var listing_id: String = str(listing.get("listing_id", ""))
	var bid_data: Dictionary = _auction_highest_by_listing.get(listing_id, {})
	var starting_bid: int = int(listing.get("starting_bid", 0))
	var min_increment: int = int(listing.get("min_increment", 1))
	var min_next_bid: int = starting_bid
	if not bid_data.is_empty():
		min_next_bid = maxi(starting_bid, int(bid_data.get("bid_amount", 0)) + min_increment)
	if bid_amount < min_next_bid:
		_set_auction_status("Bid too low. Minimum is %dG." % min_next_bid, Color(0.98, 0.52, 0.48, 1.0))
		return

	var previous_escrow: int = _get_local_auction_escrow_for_listing(listing_id)
	var additional_escrow_required: int = maxi(bid_amount - previous_escrow, 0)
	if int(CampaignManager.global_gold) < additional_escrow_required:
		_set_auction_status("Not enough gold to cover escrow (+%dG).", Color(0.98, 0.52, 0.48, 1.0))
		return
	if additional_escrow_required > 0:
		CampaignManager.global_gold -= additional_escrow_required
	_set_local_auction_escrow_for_listing(listing_id, bid_amount)
	if auction_my_gold_label != null:
		auction_my_gold_label.text = "Your Gold: %d" % int(CampaignManager.global_gold)

	var bidder_name: String = _get_auction_bidder_name()
	var payload: Dictionary = {
		"listing_id": listing_id,
		"listing_uuid": listing_id,
		"item_uid": str(listing.get("item_uid", "")),
		"bid_amount": bid_amount,
		"bidder": bidder_name,
		"bidder_id": local_player_id,
		"submitted_at": int(Time.get_unix_time_from_system())
	}

	if not has_node("/root/SilentWolf"):
		_auction_highest_by_listing[listing_id] = {
			"bid_amount": bid_amount,
			"bidder": bidder_name,
			"bidder_id": local_player_id,
			"submitted_at": payload["submitted_at"]
		}
		_set_auction_status("Offline bid staged locally.", Color(0.95, 0.75, 0.35, 1.0))
		_push_auction_notification("Bid staged on %s at %dG." % [str(listing.get("title", "Listing")), bid_amount], "#9be8ff")
		auction_bid_input.clear()
		CampaignManager.save_current_progress()
		_rebuild_auction_listing_buttons()
		_refresh_auction_selected_view()
		return

	_auction_bid_in_flight = true
	_refresh_auction_control_state()
	_set_auction_status("Submitting bid...", Color(0.55, 0.86, 1.0, 1.0))
	var sw_result: Variant = await SilentWolf.Scores.save_score(
		bidder_name,
		bid_amount,
		auction_leaderboard_name,
		payload
	).sw_save_score_complete
	_auction_bid_in_flight = false
	_refresh_auction_control_state()

	var success: bool = false
	if sw_result is Dictionary:
		success = bool(sw_result.get("success", false))
	if not success:
		if additional_escrow_required > 0:
			CampaignManager.global_gold += additional_escrow_required
		_set_local_auction_escrow_for_listing(listing_id, previous_escrow)
		if auction_my_gold_label != null:
			auction_my_gold_label.text = "Your Gold: %d" % int(CampaignManager.global_gold)
		_set_auction_status("Bid not confirmed by cloud.", Color(0.98, 0.52, 0.48, 1.0))
		_refresh_auction_selected_view()
		return

	auction_bid_input.clear()
	CampaignManager.save_current_progress()
	_set_auction_status("Bid submitted. Refreshing feed...", Color(0.56, 0.93, 0.60, 1.0))
	_push_auction_notification("Bid submitted on %s at %dG." % [str(listing.get("title", "Listing")), bid_amount], "#9be8ff")
	_refresh_auction_house_async()


func _on_auction_create_listing_pressed() -> void:
	if _auction_fetch_in_flight or _auction_bid_in_flight or _auction_listing_in_flight:
		return
	if auction_my_item_option != null and auction_my_item_option.get_item_count() <= 0:
		_set_auction_status("No inventory item available to list.", Color(0.98, 0.52, 0.48, 1.0))
		return
	_open_auction_listing_draft()


func _on_auction_confirm_listing_pressed() -> void:
	if _auction_listing_in_flight or _auction_bid_in_flight:
		return
	var item_uid: String = _get_selected_auction_listing_draft_item_uid()
	var start_bid_text: String = "100"
	if auction_listing_draft_start_bid_input != null:
		start_bid_text = auction_listing_draft_start_bid_input.text.strip_edges().replace(",", "")
	var min_inc_text: String = "5"
	if auction_listing_draft_min_inc_input != null:
		min_inc_text = auction_listing_draft_min_inc_input.text.strip_edges().replace(",", "")
	_auction_listing_in_flight = true
	_refresh_auction_control_state()
	var success: bool = await _create_auction_listing_for_item_uid(item_uid, start_bid_text, min_inc_text)
	_auction_listing_in_flight = false
	_refresh_auction_control_state()
	if success:
		_close_auction_listing_draft()


func _create_auction_listing_for_item_uid(item_uid: String, start_bid_text: String, min_inc_text: String) -> bool:
	var clean_item_uid: String = item_uid.strip_edges()
	if clean_item_uid == "":
		_set_auction_status("Selected item has no UUID.", Color(0.98, 0.52, 0.48, 1.0))
		return false
	var source_item: Resource = _get_inventory_item_by_uid(clean_item_uid)
	if source_item == null:
		_set_auction_status("Item not found in inventory.", Color(0.98, 0.52, 0.48, 1.0))
		return false
	if not start_bid_text.is_valid_int() or not min_inc_text.is_valid_int():
		_set_auction_status("Start and min increment must be whole numbers.", Color(0.98, 0.52, 0.48, 1.0))
		return false
	var start_bid: int = maxi(int(start_bid_text), 1)
	var min_inc: int = maxi(int(min_inc_text), 1)

	var serialized_item: Dictionary = CampaignManager._serialize_item(source_item)
	if serialized_item.is_empty():
		_set_auction_status("Could not serialize selected item.", Color(0.98, 0.52, 0.48, 1.0))
		return false

	# Resolve live listings first (async) before touching local inventory.
	if _auction_cloud_listings_by_id.is_empty():
		await _fetch_auction_listings_document_async()

	var removed_index: int = -1
	var inventory_size: int = CampaignManager.global_inventory.size()
	for idx in range(inventory_size):
		var inv_item: Resource = CampaignManager.global_inventory[int(idx)]
		if inv_item == source_item or _extract_item_uid(inv_item) == clean_item_uid:
			removed_index = int(idx)
			break
	if removed_index < 0:
		_set_auction_status("Item escrow failed (inventory sync).", Color(0.98, 0.52, 0.48, 1.0))
		return false
	CampaignManager.global_inventory.remove_at(removed_index)

	var listing_id: String = _generate_auction_uuid()
	var seller_id: String = _get_auction_player_id()
	var now_unix: int = int(Time.get_unix_time_from_system())
	var summary_variant: Variant = source_item.get("description")
	var summary_text: String = str(summary_variant if summary_variant != null else "").strip_edges()
	if summary_text == "":
		summary_text = "Player-listed auction item."
	var item_icon_path: String = ""
	var item_icon_variant: Variant = source_item.get("icon")
	if item_icon_variant is Texture2D:
		var icon_tex: Texture2D = item_icon_variant
		if icon_tex.resource_path != "":
			item_icon_path = icon_tex.resource_path
	var listing_data: Dictionary = {
		"listing_id": listing_id,
		"title": _get_item_display_name(source_item),
		"summary": summary_text,
		"starting_bid": start_bid,
		"min_increment": min_inc,
		"end_timestamp_unix": now_unix + (auction_listing_duration_hours * 3600),
		"item_uid": clean_item_uid,
		"seller_name": _get_auction_bidder_name(),
		"seller_id": seller_id,
		"status": "active",
		"item_icon_path": item_icon_path,
		"item_data": serialized_item,
		"winner_id": "",
		"winner_name": "",
		"final_bid": 0,
		"seller_paid": false,
		"delivered_to_winner": false,
		"returned_to_seller": false,
		"closed_at": 0,
		"settlement_lock_owner": "",
		"settlement_lock_token": "",
		"settlement_lock_until": 0,
		"settlement_lock_at": 0,
		"pending_local": true,
		"created_at": now_unix
		}
	_auction_cloud_listings_by_id[listing_id] = listing_data
	_save_shared_auction_listings_cache(_auction_cloud_listings_by_id)

	# Persist immediately as a pending local listing so closing/reloading cannot restore
	# the removed inventory item while the listing is still waiting cloud confirmation.
	_persist_pending_local_listings_to_campaign(false)
	CampaignManager.save_current_progress()

	if has_node("/root/SilentWolf"):
		var saved: bool = await _save_auction_listings_document_async()
		if not saved:
			_set_auction_status("Cloud unavailable. Listing created locally (pending sync).", Color(0.95, 0.75, 0.35, 1.0))
			_push_auction_notification("Local pending listing created for %s." % _get_item_display_name(source_item), "#ffb26a")
		else:
			var published_variant: Variant = _auction_cloud_listings_by_id.get(listing_id, listing_data)
			var published_listing: Dictionary = listing_data.duplicate(true)
			if published_variant is Dictionary:
				published_listing = (published_variant as Dictionary).duplicate(true)
			published_listing["pending_local"] = false
			_auction_cloud_listings_by_id[listing_id] = published_listing
			_save_shared_auction_listings_cache(_auction_cloud_listings_by_id)
			_set_auction_status("Listing published.", Color(0.56, 0.93, 0.60, 1.0))
	else:
		_set_auction_status("Offline mode: listing created locally.", Color(0.95, 0.75, 0.35, 1.0))
		_push_auction_notification("Offline listing queued for %s." % _get_item_display_name(source_item), "#ffb26a")

	if auction_listing_start_bid_input != null:
		auction_listing_start_bid_input.text = str(start_bid)
	if auction_listing_min_inc_input != null:
		auction_listing_min_inc_input.text = str(min_inc)
	_auction_selected_listing_id = listing_id
	_persist_pending_local_listings_to_campaign(true)
	CampaignManager.save_current_progress()
	_push_auction_notification("Listed %s for %dG start." % [_get_item_display_name(source_item), start_bid], "#8fe28e")
	_refresh_auction_my_item_options()
	_refresh_auction_house_async()
	return true

# =========================================================================
# FUNCTION: _populate_token_shop
# PURPOSE: Dynamically generates a randomized shop inventory based on MMR.
# INPUTS: None
# OUTPUTS: None
# SIDE EFFECTS: Clears the shop grid, instantiates new Button nodes.
# =========================================================================
func _populate_token_shop() -> void:
	for child in shop_items_grid.get_children():
		child.queue_free()
		
	# NON-OBVIOUS LOGIC: Prevent UI Reroll Exploit
	# Only generate a new shop inventory if we don't currently have one.
	if CampaignManager.active_shop_inventory.is_empty():
		var player_rank = _get_current_player_rank()
		var player_rank_level = rank_hierarchy.find(player_rank)
		var shop_capacity = 3 + player_rank_level 
		
		var valid_items = []
		for item in token_shop_items:
			if item == null: continue
			
			var raw_rank = item.get("required_arena_rank")
			var item_rank_req: String = str(raw_rank) if raw_rank != null else "Bronze"
			var item_rank_level = rank_hierarchy.find(item_rank_req)
			
			if player_rank_level >= (item_rank_level if item_rank_level != -1 else 0):
				valid_items.append(item)
				
		valid_items.shuffle()
		CampaignManager.active_shop_inventory.assign(valid_items.slice(0, min(shop_capacity, valid_items.size())))
	
	# Build the UI buttons using the locked inventory
	for item in CampaignManager.active_shop_inventory:
		var item_btn = Button.new()
		item_btn.custom_minimum_size = Vector2(100, 100)
		item_btn.icon = item.get("icon")
		item_btn.expand_icon = true
		item_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_btn.pivot_offset = item_btn.custom_minimum_size / 2.0
		
		item_btn.pressed.connect(func(): _select_shop_item(item))
		item_btn.mouse_entered.connect(func(): create_tween().tween_property(item_btn, "scale", Vector2(1.1, 1.1), 0.1))
		item_btn.mouse_exited.connect(func(): create_tween().tween_property(item_btn, "scale", Vector2(1.0, 1.0), 0.1))
			
		shop_items_grid.add_child(item_btn)
			
# =========================================================================
# FUNCTION: _select_shop_item
# PURPOSE: Updates the UI details panel when a shop item is clicked.
# INPUTS: item (Resource) - The clicked shop item.
# OUTPUTS: None
# SIDE EFFECTS: Updates labels, button states, and plays audio.
# =========================================================================
func _select_shop_item(item: Resource) -> void:
	if select_sound: select_sound.play()
	highlighted_item = item
	large_item_preview.texture = item.get("icon")
	
	var leader = CampaignManager.player_roster[0] if CampaignManager.player_roster.size() > 0 else {}
	
	# SAFEGUARD: Fallback to gold_cost if it is a consumable missing token cost
	var cost_raw = item.get("gladiator_token_cost")
	if cost_raw == null: cost_raw = item.get("gold_cost")
	var cost: int = int(cost_raw) if cost_raw != null else 0
	
	item_stats_label.text = _get_token_item_detailed_info(item, cost, leader)
	token_purchase_btn.disabled = false
	token_purchase_btn.text = "PURCHASE (%d Tokens)" % cost
	
# =========================================================================
# FUNCTION: _on_token_purchase_pressed
# PURPOSE: Handles the transaction logic for buying an item.
# INPUTS: None
# OUTPUTS: None
# SIDE EFFECTS: Deducts tokens, adds item to global inventory, saves progress.
# =========================================================================
func _on_token_purchase_pressed() -> void:
	if highlighted_item == null: return
	
	var cost_raw = highlighted_item.get("gladiator_token_cost")
	if cost_raw == null: cost_raw = highlighted_item.get("gold_cost")
	var cost: int = int(cost_raw) if cost_raw != null else 0
	
	if CampaignManager.gladiator_tokens >= cost:
		CampaignManager.gladiator_tokens -= cost
		var new_item: Resource = CampaignManager.make_unique_item(highlighted_item)
		if new_item != null:
			if not new_item.has_meta("original_path"):
				if highlighted_item.resource_path != "":
					new_item.set_meta("original_path", highlighted_item.resource_path)
				elif highlighted_item.has_meta("original_path"):
					new_item.set_meta("original_path", highlighted_item.get_meta("original_path"))
			CampaignManager.global_inventory.append(new_item)
		shop_token_display.text = "Gladiator Tokens: " + str(CampaignManager.gladiator_tokens)
		
		if token_buy_sound: token_buy_sound.play()
		_on_token_purchase_success()
		CampaignManager.save_current_progress()
	else:
		_update_gladiator_text("poor")
		_shake_shop_portrait()
		
# ==========================================
# --- NPC & UI FEEDBACK ---
# ==========================================

func _update_gladiator_text(category: String) -> void:
	var lines = gladiator_lines[category]
	var full_text = lines[randi() % lines.size()]
	gladiator_label.text = full_text
	gladiator_label.visible_characters = 0
	
	if gladiator_tween: gladiator_tween.kill()
	var duration = full_text.length() * 0.03
	gladiator_tween = create_tween()
	gladiator_tween.tween_method(func(c): 
		if c > gladiator_label.visible_characters:
			if gladiator_blip: gladiator_blip.play()
		gladiator_label.visible_characters = c
	, 0, full_text.length(), duration)

func _on_token_purchase_success() -> void:
	_shake_shop_portrait()
	var flash = create_tween()
	flash.tween_property(gladiator_portrait, "modulate", Color(2, 2, 2, 1), 0.1)
	flash.tween_property(gladiator_portrait, "modulate", Color.WHITE, 0.2)
	_update_gladiator_text("buy")

func _shake_shop_portrait() -> void:
	var original_pos = gladiator_portrait.position
	var shake = create_tween()
	for i in range(4):
		shake.tween_property(gladiator_portrait, "position", original_pos + Vector2(randf_range(-10, 10), 0), 0.05)
	shake.tween_property(gladiator_portrait, "position", original_pos, 0.05)

# =========================================================================
# FUNCTION: _get_token_item_detailed_info
# PURPOSE: Parses item data to generate a formatted UI BBCode description.
# INPUTS: item (Resource), price (int), compare_unit (Dictionary)
# OUTPUTS: String (BBCode formatted text)
# SIDE EFFECTS: None
# =========================================================================
func _get_token_item_detailed_info(item: Resource, price: int, compare_unit: Dictionary = {}) -> String:
	var info = ""
	
	# NON-OBVIOUS LOGIC: Weapons use 'weapon_name', Consumables use 'item_name'. 
	# We must check both to support mixed shop inventories.
	var i_name = item.get("item_name")
	if i_name == null or str(i_name) == "":
		i_name = item.get("weapon_name")
	if i_name == null or str(i_name) == "":
		i_name = "Unknown Artifact"
		
	var rarity = item.get("rarity") if item.get("rarity") != null else "Common"
	var rarity_color = _get_rarity_color_name(rarity)
		
	info += "[center][font_size=28][color=" + rarity_color + "]" + str(i_name).to_upper() + "[/color][/font_size][/center]\n"
	info += "[center][color=gray]" + rarity + "[/color]   |   Cost: [color=orange]" + str(price) + " Tokens[/color][/center]\n"
	info += "[color=gray]------------------------------------------------[/color]\n"
	
	# DIFFERENTIATE OUTPUT BASED ON ITEM TYPE
	if item is ConsumableData:
		if item.heal_amount > 0:
			info += "[color=lime]Restores " + str(item.heal_amount) + " HP[/color]\n"
		
		var boosts = []
		if item.hp_boost > 0: boosts.append("HP +" + str(item.hp_boost))
		if item.str_boost > 0: boosts.append("STR +" + str(item.str_boost))
		if item.mag_boost > 0: boosts.append("MAG +" + str(item.mag_boost))
		if item.def_boost > 0: boosts.append("DEF +" + str(item.def_boost))
		if item.res_boost > 0: boosts.append("RES +" + str(item.res_boost))
		if item.spd_boost > 0: boosts.append("SPD +" + str(item.spd_boost))
		if item.agi_boost > 0: boosts.append("AGI +" + str(item.agi_boost))
		
		if boosts.size() > 0:
			info += "[color=cyan]Permanent Boosts:[/color] " + ", ".join(boosts) + "\n"
			
		if item.is_promotion_item:
			info += "[color=gold]Used to promote units to a higher class.[/color]\n"
			
		if item.unlocked_music_track != null:
			info += "[color=hotpink]Unlocks Music:[/color] " + str(item.track_title) + "\n"
			
	else: # Fallback to standard WeaponData logic
		var might = item.get("might") if item.get("might") != null else 0
		var hit = item.get("hit_bonus") if item.get("hit_bonus") != null else 0
		var min_r = item.get("min_range") if item.get("min_range") != null else 1
		var max_r = item.get("max_range") if item.get("max_range") != null else 1
		
		info += "[color=coral]Might:[/color] " + str(might) + "   [color=khaki]Hit:[/color] +" + str(hit) + "\n"
		info += "[color=palegreen]Range:[/color] " + str(min_r) + "-" + str(max_r) + "\n"
		
		var eq_wpn = compare_unit.get("equipped_weapon")
		if eq_wpn and typeof(eq_wpn) == TYPE_OBJECT:
			var eq_might = eq_wpn.get("might") if eq_wpn.get("might") != null else 0
			var eq_name = eq_wpn.get("weapon_name") if eq_wpn.get("weapon_name") != null else "Weapon"
			var m_diff = might - eq_might
			var m_col = "lime" if m_diff >= 0 else "red"
			info += "\n[color=gray]--- VS Leader (" + str(eq_name) + ") ---[/color]\n"
			info += "Power Shift: [color=" + m_col + "]" + ("+" if m_diff >= 0 else "") + str(m_diff) + " Might[/color]\n"

	info += "[color=gray]------------------------------------------------[/color]\n"
	var d_raw = item.get("description")
	info += "[color=silver][i]\"" + (str(d_raw) if d_raw else "A mysterious artifact.") + "\"[/i][/color]"
	return info
	
func _get_rarity_color_name(rarity: String) -> String:
	match rarity:
		"Uncommon": return "lime"
		"Rare": return "deepskyblue"
		"Epic": return "mediumorchid"
		"Legendary": return "gold"
		_: return "white"

func _get_current_player_rank() -> String:
	var mmr = CampaignManager.arena_mmr
	if mmr >= 2000: return "Grandmaster"
	if mmr >= 1800: return "Diamond"
	if mmr >= 1600: return "Platinum"
	if mmr >= 1400: return "Gold"
	if mmr >= 1200: return "Silver"
	return "Bronze"	

# ==========================================
# --- RANKED RESULTS SEQUENCE ---
# ==========================================

func _play_arena_result_sequence() -> void:
	arena_result_sequence.show()
	arena_result_sequence.modulate.a = 1.0
	await get_tree().process_frame

	if arena_result_sequence.size != Vector2.ZERO:
		var c: Vector2 = arena_result_sequence.size * 0.5
		if arena_result_burst != null:
			arena_result_burst.position = c
		if arena_result_epic_spark != null:
			arena_result_epic_spark.position = c + Vector2(0.0, 24.0)

	var old_mmr: int = ArenaManager.last_match_old_mmr
	var new_mmr: int = ArenaManager.last_match_new_mmr
	var mmr_delta: int = ArenaManager.last_match_mmr_change
	var won: bool = ArenaManager.last_match_result == "VICTORY"

	_apply_arena_result_camp_theme(won, mmr_delta)
	arena_result_delta_label.text = ArenaManager.format_signed(mmr_delta) + " MMR"

	_set_result_meter_from_mmr(float(old_mmr), old_mmr)
	_arena_epic_prime_for_reveal()
	if arena_result_rewards != null:
		arena_result_rewards.modulate.a = 0.0
	if arena_result_stamp != null:
		arena_result_stamp.hide()

	_arena_result_panel_rest_pos = arena_result_panel.position
	arena_result_panel.pivot_offset = arena_result_panel.size * 0.5
	arena_result_panel.scale = Vector2(0.86, 0.86)
	arena_result_panel.modulate.a = 0.0

	if arena_result_dimmer != null:
		arena_result_dimmer.show()
		arena_result_dimmer.color = ARENA_EPIC_DIMMER_BASE
		arena_result_dimmer.modulate.a = 0.0
		var dtw: Tween = create_tween()
		dtw.tween_property(arena_result_dimmer, "modulate:a", 1.0, 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var intro: Tween = create_tween().set_parallel(true)
	intro.tween_property(arena_result_panel, "scale", Vector2.ONE, 0.72).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	intro.tween_property(arena_result_panel, "modulate:a", 1.0, 0.34)
	await intro.finished

	await _arena_epic_stagger_reveal_header(won)

	if won:
		await get_tree().create_timer(0.2).timeout
		await _arena_epic_anticipation_flash()
	else:
		await get_tree().create_timer(0.12).timeout

	var old_rank: Dictionary = ArenaManager.get_rank_data(old_mmr)
	var new_rank: Dictionary = ArenaManager.get_rank_data(new_mmr)

	# --- RANK UP SEQUENCE ---
	if old_rank["index"] < new_rank["index"]:
		var threshold: float = float(old_rank["max"])
		var tw: Tween = create_tween()
		tw.tween_method(func(v: float): _set_result_meter_from_mmr(v, old_mmr), float(old_mmr), threshold, 1.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await tw.finished

		await _play_rank_stamp(threshold, new_mmr, true)

		var tw2: Tween = create_tween()
		tw2.tween_method(func(v: float): _set_result_meter_from_mmr(v, new_mmr), threshold, float(new_mmr), 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await tw2.finished

	# --- RANK DOWN SEQUENCE ---
	elif old_rank["index"] > new_rank["index"]:
		var threshold2: float = float(old_rank["min"])
		var tw3: Tween = create_tween()
		tw3.tween_method(func(v: float): _set_result_meter_from_mmr(v, old_mmr), float(old_mmr), threshold2, 1.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await tw3.finished

		await _play_rank_stamp(threshold2, new_mmr, false)

		var tw4: Tween = create_tween()
		tw4.tween_method(func(v: float): _set_result_meter_from_mmr(v, new_mmr), threshold2, float(new_mmr), 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await tw4.finished

	# --- NORMAL SEQUENCE (No change) ---
	else:
		var tw5: Tween = create_tween()
		tw5.tween_method(func(v: float): _set_result_meter_from_mmr(v, old_mmr), float(old_mmr), float(new_mmr), 1.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await tw5.finished
		await get_tree().create_timer(0.42).timeout

	await _arena_epic_reveal_spoils_finale(won)

	# --- CLICK TO CONTINUE ---
	var continue_lbl = arena_result_sequence.get_node_or_null("Panel/ClickToContinue")
	if continue_lbl:
		continue_lbl.show()
		var f_tw = create_tween().set_loops(9999)
		f_tw.tween_property(continue_lbl, "modulate:a", 0.3, 0.6)
		f_tw.tween_property(continue_lbl, "modulate:a", 1.0, 0.6)

	var clicked = false
	while not clicked:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			clicked = true
	
	var out_tw: Tween = create_tween().set_parallel(true)
	out_tw.tween_property(arena_result_sequence, "modulate:a", 0.0, 0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if arena_result_dimmer != null:
		out_tw.tween_property(arena_result_dimmer, "modulate:a", 0.0, 0.42)
	await out_tw.finished

	if continue_lbl != null:
		continue_lbl.hide()
	arena_result_sequence.hide()
	arena_result_stamp.hide()
	_arena_result_reset_fx()
		
func _set_result_meter_from_mmr(display_mmr: float, forced_rank_mmr: int = -1) -> void:
	var mmr_int: int = int(round(display_mmr))
	var eval_mmr: int = mmr_int if forced_rank_mmr == -1 else forced_rank_mmr
	var rank_data: Dictionary = ArenaManager.get_rank_data(eval_mmr)

	arena_result_rank_name.text = str(rank_data["name"]).to_upper()
	arena_result_rank_name.add_theme_color_override("font_color", rank_data["color"])
	arena_result_rating_label.text = "Rating · %d MMR" % mmr_int

	_style_arena_rank_progress_bar(rank_data)

	var r_min: float = float(rank_data["min"])
	var r_max: float = float(rank_data["max"])
	var span: float = max(1.0, r_max - r_min)
	var ratio: float = clamp((float(mmr_int) - r_min) / span, 0.0, 1.0)

	arena_result_bar.value = ratio * 100.0
	arena_result_bar_value.text = "%d%%" % int(round(ratio * 100.0))

	var icon_tex = ArenaManager.get_rank_icon(eval_mmr)
	if icon_tex:
		arena_result_rank_icon.texture = icon_tex
		
func _play_rank_stamp(current_visual_mmr: float, target_mmr: int, went_up: bool) -> void:
	var rank_data: Dictionary = ArenaManager.get_rank_data(target_mmr)
	var rank_name: String = str(rank_data["name"])
	var rank_color: Color = rank_data["color"]

	arena_result_stamp.custom_minimum_size = Vector2(520, 0)
	arena_result_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena_result_stamp.text = ("RANK UP — " if went_up else "RANK DOWN — ") + rank_name.to_upper()
	arena_result_stamp.add_theme_font_size_override("font_size", 44)
	arena_result_stamp.add_theme_constant_override("outline_size", 4)
	arena_result_stamp.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.015, 0.96))
	arena_result_stamp.add_theme_color_override("font_color", rank_color.lightened(0.08))
	arena_result_stamp.show()
	await get_tree().process_frame
	arena_result_stamp.pivot_offset = Vector2(arena_result_stamp.size.x * 0.5, arena_result_stamp.size.y * 0.5)

	if went_up:
		arena_result_stamp.scale = Vector2(10.0, 10.0)
		arena_result_stamp.modulate.a = 0.0
		arena_result_stamp.rotation = -0.18

		var s_tw: Tween = create_tween()
		s_tw.tween_property(arena_result_stamp, "modulate:a", 1.0, 0.18)
		s_tw.parallel().tween_property(arena_result_stamp, "rotation", 0.06, 0.38).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		s_tw.parallel().tween_property(arena_result_stamp, "scale", Vector2(4.2, 4.2), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		s_tw.tween_property(arena_result_stamp, "scale", Vector2(0.82, 0.82), 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		s_tw.parallel().tween_property(arena_result_stamp, "rotation", 0.0, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

		await get_tree().create_timer(0.56).timeout

		_set_result_meter_from_mmr(current_visual_mmr, target_mmr)
		_arena_epic_dimmer_pulse_rank(rank_color)
		_configure_epic_spark_burst(rank_color)
		if arena_result_epic_spark != null:
			arena_result_epic_spark.emitting = true

		var bounce_tw: Tween = create_tween()
		bounce_tw.set_parallel(true)
		bounce_tw.tween_property(arena_result_stamp, "scale", Vector2(1.0, 1.0), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bounce_tw.tween_property(arena_result_stamp, "rotation", 0.0, 0.28)

		if token_buy_sound != null:
			token_buy_sound.pitch_scale = 1.35
			token_buy_sound.play()

		_configure_arena_burst(rank_color.lerp(CampUiSkin.CAMP_BORDER, 0.35), true)
		if arena_result_burst != null:
			arena_result_burst.emitting = true

		if arena_result_rank_icon != null:
			arena_result_rank_icon.pivot_offset = arena_result_rank_icon.size * 0.5
			var icon_tw: Tween = create_tween()
			icon_tw.tween_property(arena_result_rank_icon, "scale", Vector2(1.65, 1.65), 0.12).set_trans(Tween.TRANS_ELASTIC)
			icon_tw.tween_property(arena_result_rank_icon, "scale", Vector2(1.0, 1.0), 0.55).set_trans(Tween.TRANS_BOUNCE)

		var punch: Tween = create_tween()
		punch.tween_property(arena_result_panel, "scale", Vector2(1.04, 1.04), 0.06)
		punch.tween_property(arena_result_panel, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_ELASTIC)

		var base: Vector2 = _arena_result_panel_rest_pos
		var shake: Tween = create_tween()
		for _i in range(12):
			var offset: Vector2 = Vector2(randf_range(-32.0, 32.0), randf_range(-28.0, 28.0))
			shake.tween_property(arena_result_panel, "position", base + offset, 0.028)
		shake.tween_property(arena_result_panel, "position", base, 0.04)

		await bounce_tw.finished

		if arena_result_flash != null:
			var flash_col: Color = rank_color.lerp(Color(1.0, 0.92, 0.55, 1.0), 0.45)
			arena_result_flash.color = flash_col
			arena_result_flash.show()
			arena_result_flash.modulate.a = 1.0
			var flash_tw: Tween = create_tween()
			flash_tw.tween_property(arena_result_flash, "modulate:a", 0.0, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			await flash_tw.finished
			arena_result_flash.hide()
	else:
		arena_result_stamp.scale = Vector2(3.2, 3.2)
		arena_result_stamp.modulate.a = 0.0
		arena_result_stamp.rotation = 0.12
		var start_top: float = arena_result_stamp.offset_top
		arena_result_stamp.offset_top = start_top - 120.0

		var s_tw2: Tween = create_tween()
		s_tw2.set_parallel(true)
		s_tw2.tween_property(arena_result_stamp, "offset_top", start_top, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		s_tw2.tween_property(arena_result_stamp, "scale", Vector2(1.0, 1.0), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		s_tw2.tween_property(arena_result_stamp, "modulate:a", 1.0, 0.35)
		s_tw2.tween_property(arena_result_stamp, "rotation", -0.04, 0.5).set_trans(Tween.TRANS_ELASTIC)

		await get_tree().create_timer(0.52).timeout

		_set_result_meter_from_mmr(current_visual_mmr, target_mmr)

		if token_buy_sound != null:
			token_buy_sound.pitch_scale = 0.52
			token_buy_sound.play()

		_configure_arena_burst(Color(0.45, 0.55, 0.78, 1.0), false)
		if arena_result_burst != null:
			arena_result_burst.emitting = true

		var base2: Vector2 = _arena_result_panel_rest_pos
		var shake2: Tween = create_tween()
		for _j in range(7):
			var off2: Vector2 = Vector2(randf_range(-14.0, 14.0), randf_range(-12.0, 12.0))
			shake2.tween_property(arena_result_panel, "position", base2 + off2, 0.04)
		shake2.tween_property(arena_result_panel, "position", base2, 0.05)
		await shake2.finished

		if arena_result_flash != null:
			arena_result_flash.color = Color(0.35, 0.42, 0.55, 1.0).lerp(rank_color, 0.25)
			arena_result_flash.show()
			arena_result_flash.modulate.a = 0.85
			var flash2: Tween = create_tween()
			flash2.tween_property(arena_result_flash, "modulate:a", 0.0, 0.65)
			await flash2.finished
			arena_result_flash.hide()
				
# ==========================================
# --- MATCHMAKING & LOBBY ---
# ==========================================

func _on_back_pressed() -> void:
	_hide_unit_info_panel_immediate()
	_close_auction_house()
	SceneTransition.change_scene_to_file("res://Scenes/UI/WorldMap.tscn")


func _layout_arena_setup_feedback_nodes() -> void:
	if arena_setup_panel == null:
		return
	if _arena_setup_instruction_label != null and is_instance_valid(_arena_setup_instruction_label):
		_arena_setup_instruction_label.position = Vector2(20, 56)
		_arena_setup_instruction_label.size = Vector2(600, 44)
	if _arena_setup_identity_label != null and is_instance_valid(_arena_setup_identity_label):
		_arena_setup_identity_label.position = Vector2(20, 102)
		_arena_setup_identity_label.size = Vector2(600, 32)
	if _arena_setup_lock_banner != null and is_instance_valid(_arena_setup_lock_banner):
		_arena_setup_lock_banner.position = Vector2(20, 580)
		_arena_setup_lock_banner.size = Vector2(600, 60)


func _ensure_arena_setup_feedback_nodes() -> void:
	if arena_setup_panel == null:
		return
	if _arena_setup_instruction_label != null and is_instance_valid(_arena_setup_instruction_label):
		_layout_arena_setup_feedback_nodes()
		return
	var inst: Label = Label.new()
	inst.name = "ArenaSetupInstruction"
	inst.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inst.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	inst.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CampUiSkin.style_label(inst, CampUiSkin.CAMP_MUTED, 15, 0)
	arena_setup_panel.add_child(inst)
	_arena_setup_instruction_label = inst

	var ident: Label = Label.new()
	ident.name = "ArenaIdentityLine"
	ident.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ident.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ident.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CampUiSkin.style_label(ident, CampUiSkin.CAMP_ACCENT_CYAN, 13, 0)
	arena_setup_panel.add_child(ident)
	_arena_setup_identity_label = ident

	var ban: Label = Label.new()
	ban.name = "ArenaLockBanner"
	ban.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ban.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ban.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	CampUiSkin.style_label(ban, CampUiSkin.CAMP_TEXT, 16, 0)
	arena_setup_panel.add_child(ban)
	_arena_setup_lock_banner = ban
	_layout_arena_setup_feedback_nodes()


func _open_setup_panel() -> void:
	_close_auction_house()
	selected_team.clear()
	for u in ArenaManager.local_arena_team:
		if u != null:
			selected_team.append(u)
	_refresh_setup_ui()
	arena_setup_panel.show()


func _refresh_setup_ui() -> void:
	_ensure_arena_setup_feedback_nodes()
	if arena_setup_title_label != null:
		arena_setup_title_label.text = "MULTIVERSE ROSTER"
	if _arena_setup_instruction_label != null:
		_arena_setup_instruction_label.text = "Tap units to fill up to three slots. Locking in uploads your roster to the Silent Wolf board so other players can fight your ghost."
	if _arena_setup_identity_label != null and ArenaManager.has_method("get_arena_identity_blurb"):
		_arena_setup_identity_label.text = ArenaManager.get_arena_identity_blurb()

	for child in roster_grid.get_children(): child.queue_free()
	for child in team_grid.get_children(): child.queue_free()
	
	var all_units: Array = []
	all_units.append_array(CampaignManager.player_roster)
	if DragonManager: all_units.append_array(DragonManager.player_dragons)
	
	for unit in all_units:
		if selected_team.has(unit): continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(80, 80)
		var display_name: String = unit.get("unit_name", unit.get("name", "???"))
		btn.text = display_name.substr(0, 4)
		CampUiSkin.style_button(btn, false, 14, 80)
		btn.add_theme_constant_override("outline_size", 1)
		btn.mouse_entered.connect(func(): _update_unit_info(unit))
		btn.mouse_exited.connect(_schedule_unit_info_hide)
		btn.pressed.connect(func():
			if selected_team.size() >= 3:
				return
			if select_sound:
				select_sound.pitch_scale = 1.08
				select_sound.play()
			selected_team.append(unit)
			var new_slot_i: int = selected_team.size() - 1
			_refresh_setup_ui()
			_update_unit_info(unit)
			call_deferred("_arena_setup_animate_team_slot_by_index", new_slot_i)
		)
		roster_grid.add_child(btn)
		
	for i in range(3):
		var b := Button.new()
		b.custom_minimum_size = Vector2(100, 100)
		if i < selected_team.size():
			var chosen_unit = selected_team[i]
			b.text = chosen_unit.get("unit_name", chosen_unit.get("name", "???"))
			CampUiSkin.style_button(b, true, 14, 100)
			b.add_theme_constant_override("outline_size", 1)
			b.mouse_entered.connect(func(): _update_unit_info(chosen_unit))
			b.mouse_exited.connect(_schedule_unit_info_hide)
			b.pressed.connect(func():
				if select_sound:
					select_sound.pitch_scale = 0.94
					select_sound.play()
				selected_team.erase(chosen_unit)
				_refresh_setup_ui()
			)
		else:
			b.text = "Empty"
			b.disabled = true
			CampUiSkin.style_button(b, false, 14, 100)
			b.add_theme_constant_override("outline_size", 1)
			b.mouse_entered.connect(_hide_unit_info_panel_immediate)
		team_grid.add_child(b)

	var n: int = selected_team.size()
	if _arena_setup_lock_banner != null:
		if n <= 0:
			_arena_setup_lock_banner.text = "Pick at least one fighter or dragon, then lock in to publish your team."
			_arena_setup_lock_banner.add_theme_color_override("font_color", Color(0.92, 0.78, 0.42, 1.0))
		elif n < 3:
			_arena_setup_lock_banner.text = "Squad %d/3 — add more for a full trio, or lock in now with a partial team." % n
			_arena_setup_lock_banner.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55, 1.0))
		else:
			_arena_setup_lock_banner.text = "Full squad — lock in to upload and load challengers."
			_arena_setup_lock_banner.add_theme_color_override("font_color", CampUiSkin.CAMP_ACCENT_GREEN)

	if confirm_team_btn != null:
		confirm_team_btn.disabled = selected_team.is_empty()
		if n <= 0:
			confirm_team_btn.text = "LOCK TEAM & FIND CHALLENGERS"
			confirm_team_btn.tooltip_text = "Choose at least one unit from the roster above."
		elif n < 3:
			confirm_team_btn.text = "LOCK IN (%d/3) — FIND CHALLENGERS" % n
			confirm_team_btn.tooltip_text = "Optional: fill all three slots. You can lock now or add more fighters first."
		else:
			confirm_team_btn.text = "LOCK TEAM & FIND CHALLENGERS"
			confirm_team_btn.tooltip_text = "Uploads your snapshot to the Multiverse board and searches for opponents."
		CampUiSkin.style_button(confirm_team_btn, true, 18, 52)
		confirm_team_btn.add_theme_constant_override("outline_size", 1)

	var current_mmr = ArenaManager.get_local_mmr()
	var rank_data = ArenaManager.get_rank_data(current_mmr)
	var current_power = ArenaManager._calculate_combat_power(selected_team)

	var stats_lbl = arena_setup_panel.get_node_or_null("TeamStatsLabel")
	if stats_lbl == null:
		stats_lbl = RichTextLabel.new()
		stats_lbl.name = "TeamStatsLabel"
		stats_lbl.bbcode_enabled = true
		stats_lbl.custom_minimum_size = Vector2(600, 80)
		stats_lbl.position = Vector2(20, 448)
		arena_setup_panel.add_child(stats_lbl)
	CampUiSkin.style_rich_label_flat(stats_lbl, 15, false)
	stats_lbl.add_theme_constant_override("line_separation", 6)
	stats_lbl.add_theme_constant_override("outline_size", 0)
	var stat_panel := CampUiSkin.make_panel_style(CampUiSkin.CAMP_PANEL_BG_SOFT, CampUiSkin.CAMP_BORDER_SOFT, 14, 0)
	stat_panel.content_margin_top = 10
	stat_panel.content_margin_bottom = 10
	stat_panel.content_margin_left = 14
	stat_panel.content_margin_right = 14
	stats_lbl.add_theme_stylebox_override("normal", stat_panel)
	stats_lbl.fit_content = false
	stats_lbl.position = Vector2(20, 448)
	stats_lbl.custom_minimum_size = Vector2(600, 80)

	var hex_color: String = rank_data["color"].to_html(false)
	var muted_hex: String = CampUiSkin.CAMP_MUTED.to_html(false)
	stats_lbl.text = (
		"[center][color=#%s]Rank[/color]  [color=#%s]%s[/color]  ·  %d MMR\n"
		+ "[color=#%s]Power[/color]  %d[/center]"
	) % [muted_hex, hex_color, rank_data["name"], current_mmr, muted_hex, current_power]

	token_display.text = "Gladiator Tokens: %d" % CampaignManager.gladiator_tokens
	CampUiSkin.style_label(token_display, CampUiSkin.CAMP_ACTION_PRIMARY.lightened(0.12), 16, 0)

	call_deferred("_arena_setup_pulse_stats_readout")


func _arena_setup_pulse_stats_readout() -> void:
	if arena_setup_panel == null or not arena_setup_panel.visible:
		return
	var sl: Control = arena_setup_panel.get_node_or_null("TeamStatsLabel") as Control
	if sl == null:
		return
	sl.modulate.a = 0.55
	var tw2: Tween = create_tween()
	tw2.tween_property(sl, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE)


func _update_unit_info(unit) -> void:
	_cancel_unit_info_hide()
	if unit_info_panel:
		unit_info_panel.show()
	
	var u_name = "Unknown"; var u_class = "Unknown"; var u_lvl = 1
	var m_hp = 10; var c_hp = 10
	var u_str = 0; var u_mag = 0; var u_def = 0
	var u_res = 0; var u_spd = 0; var u_agi = 0
	var p_tex = null; var wpn_name = "Unarmed"
	
	if unit is Dictionary:
		u_name = unit.get("unit_name", unit.get("name", "Unknown"))
		u_class = unit.get("unit_class", unit.get("class", "Unknown"))
		u_lvl = unit.get("level", 1)
		
		# --- 1. SAFE DATA FETCHING (Converts Cloud Strings to Resources) ---
		var data_res = unit.get("data")
		if data_res is String and ResourceLoader.exists(data_res):
			data_res = load(data_res)
			
		var res_hp = 10
		if data_res is Resource or typeof(data_res) == TYPE_OBJECT:
			var fetched_hp = data_res.get("max_hp")
			if fetched_hp != null: res_hp = fetched_hp
		elif data_res is Dictionary:
			res_hp = data_res.get("max_hp", 10)
			
		m_hp = unit.get("max_hp", res_hp) if unit.has("max_hp") else res_hp
		c_hp = unit.get("current_hp", m_hp) if unit.has("current_hp") else m_hp
		
		# --- 2. FETCH ALL 6 STATS ---
		u_str = unit.get("strength", 0)
		u_mag = unit.get("magic", 0)
		u_def = unit.get("defense", 0)
		u_res = unit.get("resistance", 0)
		u_spd = unit.get("speed", 0)
		u_agi = unit.get("agility", 0)
		
		# --- 3. SAFE PORTRAIT FETCHING ---
		var p_raw = unit.get("portrait")
		if p_raw is String and ResourceLoader.exists(p_raw):
			p_tex = load(p_raw)
		elif p_raw is Texture2D:
			p_tex = p_raw
		elif data_res != null:
			if data_res is Resource or typeof(data_res) == TYPE_OBJECT:
				p_tex = data_res.get("portrait")
			elif data_res is Dictionary:
				p_tex = data_res.get("portrait")
		
		# --- 4. SAFE WEAPON FETCHING ---
		var wpn = unit.get("equipped_weapon")
		if wpn is String and ResourceLoader.exists(wpn):
			wpn = load(wpn)
			
		if wpn != null:
			if wpn is Dictionary:
				wpn_name = str(wpn.get("weapon_name", "Unarmed"))
			else:
				var w_name_raw = wpn.get("weapon_name")
				if w_name_raw != null and str(w_name_raw) != "":
					wpn_name = str(w_name_raw)
		else:
			wpn_name = unit.get("equipped_weapon_name", "Unarmed")
	
	# --- APPLY TO UI ---
	info_portrait.texture = p_tex
	info_name.text = str(u_name)
	info_class.text = "Class: %s" % str(u_class)
	info_level.text = "Lvl: %d" % u_lvl
	info_hp.text = "HP: %d/%d" % [c_hp, m_hp]
	
	# --- DISPLAY ALL 6 STATS CLEANLY ---
	info_stats.text = "STR:%d | MAG:%d | DEF:%d\nRES:%d | SPD:%d | AGI:%d" % [u_str, u_mag, u_def, u_res, u_spd, u_agi]
	info_weapon.text = "Weapon: %s" % str(wpn_name)
				
func _lock_team_and_search() -> void:
	if selected_team.is_empty():
		return
	ArenaManager.local_arena_team = selected_team.duplicate()
	arena_setup_panel.hide()
	_hide_unit_info_panel_immediate()
	arena_panel.show()
	status_label.text = "Publishing your roster to the Multiverse board…"
	confirm_team_btn.disabled = true
	await ArenaManager.push_team_to_cloud(selected_team)
	CampaignManager.arena_locked_team_identity = ArenaManager.build_arena_team_identity(selected_team)
	if CampaignManager.active_save_slot >= 0:
		CampaignManager.save_game(CampaignManager.active_save_slot, true)
	_fetch_matches()

func _fetch_matches() -> void:
	_hide_arena_opponent_confirm()
	for child in opponent_container.get_children():
		child.queue_free()
	refresh_matches_button.disabled = true
	status_label.text = "Searching for challengers…"

	if not has_node("/root/SilentWolf"):
		refresh_matches_button.disabled = false
		if confirm_team_btn:
			confirm_team_btn.disabled = false
		status_label.text = "Online arena needs Silent Wolf. Check your connection or project autoloads."
		return

	var opponents: Array = await ArenaManager.fetch_arena_opponents()
	refresh_matches_button.disabled = false
	if confirm_team_btn:
		confirm_team_btn.disabled = false

	if opponents.is_empty():
		status_label.text = ArenaManager.last_opponent_fetch_hint if ArenaManager.last_opponent_fetch_hint != "" else "No opponents found. Try Search for Challengers again."
	else:
		status_label.text = "Select an opponent!"
		for opp in opponents:
			_create_opponent_card(opp)


func _hide_arena_opponent_confirm() -> void:
	_arena_opp_confirm_pending.clear()
	if _arena_opp_confirm_panel != null and is_instance_valid(_arena_opp_confirm_panel):
		_arena_opp_confirm_panel.hide()


func _ensure_arena_opponent_confirm_ui() -> void:
	if arena_panel == null:
		return
	if _arena_opp_confirm_panel != null and is_instance_valid(_arena_opp_confirm_panel):
		return
	var p := Panel.new()
	p.name = "ArenaOpponentConfirmPanel"
	p.visible = false
	p.z_index = 14
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	arena_panel.add_child(p)
	p.anchor_left = 0.5
	p.anchor_top = 0.5
	p.anchor_right = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -340.0
	p.offset_top = -210.0
	p.offset_right = 340.0
	p.offset_bottom = 210.0
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	CampUiSkin.style_panel_surface(p, CampUiSkin.CAMP_PANEL_BG_ALT, CampUiSkin.CAMP_BORDER, 20, 10)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	p.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Start this duel?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CampUiSkin.style_label(title, CampUiSkin.CAMP_ACCENT_CYAN, 22, 1)
	vbox.add_child(title)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = false
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.custom_minimum_size = Vector2(560, 140)
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CampUiSkin.style_rich_label_flat(rtl, 15, false)
	rtl.add_theme_constant_override("line_separation", 6)
	rtl.add_theme_constant_override("outline_size", 0)
	vbox.add_child(rtl)
	_arena_opp_confirm_richtext = rtl

	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 18)
	var btn_no := Button.new()
	btn_no.text = "Not yet"
	CampUiSkin.style_button(btn_no, false, 17, 48, 26, 16)
	var btn_yes := Button.new()
	btn_yes.text = "Fight!"
	CampUiSkin.style_button(btn_yes, true, 18, 52, 26, 16)
	h.add_child(btn_no)
	h.add_child(btn_yes)
	vbox.add_child(h)

	btn_no.pressed.connect(_on_arena_opp_confirm_no)
	btn_yes.pressed.connect(_on_arena_opp_confirm_yes)

	_arena_opp_confirm_panel = p


func _show_arena_opponent_confirm(opp_data: Dictionary) -> void:
	_ensure_arena_opponent_confirm_ui()
	if _arena_opp_confirm_panel == null or _arena_opp_confirm_richtext == null:
		return
	var od: Dictionary = opp_data.duplicate(true)
	var meta: Dictionary = od.get("metadata", {})
	var opp_mmr: int = ArenaManager.sanitize_leaderboard_score_mmr(od.get("score", 1000))
	od["score"] = opp_mmr
	var local_mmr: int = ArenaManager.get_local_mmr()
	var mmr_diff: int = opp_mmr - local_mmr
	var detail: Dictionary = ArenaManager.get_opponent_difficulty_detail(mmr_diff)
	var gap_hex: String = detail["color"].to_html(false)
	var m_hex: String = CampUiSkin.CAMP_MUTED.to_html(false)
	var t_hex: String = CampUiSkin.CAMP_TEXT.to_html(false)
	var opp_name: String = str(meta.get("player_name", "Unknown"))
	var abs_gap: int = absi(mmr_diff)
	var summary: String
	if abs_gap <= 50:
		summary = "Similar rating — within 50 MMR."
	elif mmr_diff > 0:
		summary = "They are rated higher than you."
	else:
		summary = "You are rated higher than them."
	var signed_gap: String = ArenaManager.format_signed(mmr_diff)

	_arena_opp_confirm_richtext.text = (
		"[center][color=#%s]%s[/color]\n\n"
		+ "[color=#%s]Your MMR[/color]  %d   ·   [color=#%s]Their MMR[/color]  %d\n\n"
		+ "[color=#%s]%s[/color]\n"
		+ "[color=#%s]MMR gap: %s[/color] [color=#%s](their MMR minus yours)[/color][/center]"
	) % [
		t_hex, opp_name,
		m_hex, local_mmr, m_hex, opp_mmr,
		gap_hex, summary,
		gap_hex, signed_gap, m_hex
	]
	_arena_opp_confirm_pending = od
	_arena_opp_confirm_panel.show()


func _on_arena_opp_confirm_yes() -> void:
	if _arena_opp_confirm_pending.is_empty():
		return
	ArenaManager.current_opponent_data = _arena_opp_confirm_pending.duplicate(true)
	_hide_arena_opponent_confirm()
	SceneTransition.change_scene_to_file("res://Scenes/Levels/ArenaLevel.tscn")


func _on_arena_opp_confirm_no() -> void:
	_hide_arena_opponent_confirm()


# --- AI/Reviewer: Builds a single arena opponent card. Entry: _create_opponent_card(opp_data).
# Uses ArenaManager player-experience API: get_opponent_difficulty_label, get_estimated_rewards, get_rank_data.
# Layout: rank badge, name, MMR/power, difficulty, then win/loss reward estimates.
## Creates a button card for one arena opponent and adds it to opponent_container.
##
## Purpose: Display opponent rank, name, MMR, power, difficulty label, optional power matchup hint
## (ArenaManager.get_power_matchup_hint vs local_power_rating), and estimated win/loss rewards.
## Uses ArenaManager.get_opponent_difficulty_label and ArenaManager.get_estimated_rewards.
##
## Inputs:
##   opp_data (Dictionary): Score entry from fetch_arena_opponents; must have "score" (MMR) and "metadata"
##     with "player_name", "power_rating". May have "metadata" from SilentWolf.
##
## Outputs: None.
##
## Side effects: Adds a clickable PanelContainer card to opponent_container; click loads ArenaLevel.
func _arena_opponent_card_gui_input(event: InputEvent, opp_data: Dictionary) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_show_arena_opponent_confirm(opp_data)


func _create_opponent_card(opp_data: Dictionary) -> void:
	# Panel + RichTextLabel (not a single tinted Button) — readable type, rank color only on tier name.
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	CampUiSkin.style_panel_surface(card, CampUiSkin.CAMP_PANEL_BG_SOFT, CampUiSkin.CAMP_BORDER_SOFT, 16, 0)
	card.gui_input.connect(_arena_opponent_card_gui_input.bind(opp_data))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CampUiSkin.style_rich_label_flat(rtl, 14, false)
	rtl.add_theme_constant_override("line_separation", 5)
	rtl.add_theme_constant_override("outline_size", 0)
	margin.add_child(rtl)

	var meta: Dictionary = opp_data.get("metadata", {})
	var opp_name: String = str(meta.get("player_name", "Unknown"))
	var opp_mmr: int = ArenaManager.sanitize_leaderboard_score_mmr(opp_data.get("score", 1000))
	opp_data["score"] = opp_mmr
	var power: int = int(meta.get("power_rating", 0))
	var local_power: int = int(ArenaManager.local_power_rating)
	var power_hint: String = ArenaManager.get_power_matchup_hint(local_power, power)

	var rank_data: Dictionary = ArenaManager.get_rank_data(opp_mmr)
	var local_mmr: int = ArenaManager.get_local_mmr()
	var mmr_diff: int = opp_mmr - local_mmr
	var difficulty: String = ArenaManager.get_opponent_difficulty_label(mmr_diff)
	var diff_disp: String = difficulty.strip_edges()
	if diff_disp.length() > 0 and diff_disp == diff_disp.to_upper():
		diff_disp = diff_disp.to_lower().capitalize()

	var rewards: Dictionary = ArenaManager.get_estimated_rewards(opp_mmr)
	var win_mmr: int = int(rewards.get("mmr_on_win", 15))
	var loss_mmr: int = int(rewards.get("mmr_on_loss", -5))
	var win_gold: int = int(rewards.get("gold_on_win", 50))
	var win_tokens: int = int(rewards.get("tokens_on_win", 1))
	var win_mmr_str: String = ArenaManager.format_signed(win_mmr)
	var loss_mmr_str: String = ArenaManager.format_signed(loss_mmr)

	var m_hex: String = CampUiSkin.CAMP_MUTED.to_html(false)
	var t_hex: String = CampUiSkin.CAMP_TEXT.to_html(false)
	var rk_hex: String = rank_data["color"].to_html(false)
	var rank_name: String = str(rank_data.get("name", "Unknown"))

	var parts: PackedStringArray = PackedStringArray()
	parts.append("[color=#%s]Rank[/color]  [color=#%s]%s[/color]" % [m_hex, rk_hex, rank_name])
	parts.append("[color=#%s]Gladiator[/color]  [color=#%s]%s[/color]" % [m_hex, t_hex, opp_name])
	parts.append(
		"[color=#%s]MMR[/color]  %d  ·  [color=#%s]Power[/color]  %d  [color=#%s](you %d)[/color]"
		% [m_hex, opp_mmr, m_hex, power, m_hex, local_power]
	)
	parts.append("[color=#%s]Matchup[/color]  %s" % [m_hex, diff_disp])
	var hint_stripped: String = power_hint.strip_edges()
	if not hint_stripped.is_empty():
		var hint_show: String = hint_stripped
		if hint_show == hint_show.to_upper():
			hint_show = hint_show.to_lower().capitalize()
		parts.append("[color=#%s]%s[/color]" % [m_hex, hint_show])
	parts.append(
		"[color=#%s]Win[/color]  %s MMR · +%d gold · +%d tokens    [color=#%s]Loss[/color]  %s MMR"
		% [m_hex, win_mmr_str, win_gold, win_tokens, m_hex, loss_mmr_str]
	)
	rtl.text = "\n".join(parts)

	opponent_container.add_child(card)

func _show_leaderboard() -> void:
	_hide_arena_opponent_confirm()
	leaderboard_panel.show()
	for child in leaderboard_container.get_children(): child.queue_free()
	status_label.text = "Fetching champions..."
	var _sw_result = await SilentWolf.Scores.get_scores(10, "arena").sw_get_scores_complete
	var top_scores = SilentWolf.Scores.scores
	
	if top_scores.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "The Arena is currently empty."
		CampUiSkin.style_label(empty_lbl, CampUiSkin.CAMP_MUTED, 18, 1)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		leaderboard_container.add_child(empty_lbl)
		return

	top_scores.sort_custom(func(a, b): return a.score > b.score)
	for i in range(top_scores.size()):
		_create_leaderboard_row(i + 1, top_scores[i])

func _create_leaderboard_row(rank: int, data: Dictionary) -> void:
	var h_box := HBoxContainer.new()
	h_box.custom_minimum_size.y = 52
	h_box.add_theme_constant_override("separation", 10)
	var rank_lbl := Label.new()
	rank_lbl.text = "#%d" % rank
	rank_lbl.custom_minimum_size.x = 44
	CampUiSkin.style_label(rank_lbl, CampUiSkin.CAMP_TEXT, 17, 1)
	if rank == 1:
		rank_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35, 1.0))

	var name_btn := Button.new()
	name_btn.text = data.metadata.get("player_name", "Anonymous")
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CampUiSkin.style_button(name_btn, false, 16, 44)
	name_btn.add_theme_color_override("font_color", CampUiSkin.CAMP_ACCENT_CYAN)
	name_btn.add_theme_color_override("font_hover_color", CampUiSkin.CAMP_TEXT)
	name_btn.pressed.connect(func(): _inspect_ghost_team(data))

	var mmr_lbl := Label.new()
	var mmr_val: int = int(data.score)
	var rank_info: Dictionary = ArenaManager.get_rank_data(mmr_val)
	mmr_lbl.text = "%d MMR" % mmr_val
	CampUiSkin.style_label(mmr_lbl, rank_info["color"], 16, 1)
	mmr_lbl.custom_minimum_size.x = 120
	mmr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	h_box.add_child(rank_lbl)
	h_box.add_child(name_btn)
	h_box.add_child(mmr_lbl)
	leaderboard_container.add_child(h_box)

func _inspect_ghost_team(data: Dictionary) -> void:
	for child in ghost_team_grid.get_children(): child.queue_free()
	var meta = data.get("metadata", {})
	var full_team = meta.get("roster", []) + meta.get("dragons", [])
	
	ghost_title.text = meta.get("player_name", "Gladiator") + "'s Team"
	for unit_data in full_team:
		var unit_btn := Button.new()
		unit_btn.custom_minimum_size = Vector2(100, 100)
		var u_name: String = unit_data.get("unit_name", unit_data.get("name", "Unknown"))
		unit_btn.text = "%s\nLv.%d" % [u_name.substr(0, 8), unit_data.get("level", 1)]
		CampUiSkin.style_button(unit_btn, false, 13, 100)
		if unit_data.has("portrait_path") and ResourceLoader.exists(unit_data["portrait_path"]):
			unit_btn.icon = load(unit_data["portrait_path"])
			unit_btn.expand_icon = true

		unit_btn.mouse_entered.connect(func(): _update_unit_info(unit_data))
		unit_btn.mouse_exited.connect(_schedule_unit_info_hide)
		ghost_team_grid.add_child(unit_btn)
	ghost_inspect_panel.show()	

func _check_offline_rewards() -> void:
	var rewards = await ArenaManager.check_defense_rewards()
	if rewards.get("gold", 0) > 0 or rewards.get("mmr", 0) != 0:
		defense_label.text = "OFFLINE REPORT\nEarned: %d Gold\nRating: %+d MMR" % [rewards["gold"], rewards["mmr"]]
		defense_popup.show()
		defense_ok_button.pressed.connect(func(): defense_popup.hide(), CONNECT_ONE_SHOT)

func _refresh_gladiator_badge() -> void:
	streak_badge.visible = CampaignManager.arena_win_streak >= 3

func _close_arena() -> void:
	_hide_arena_opponent_confirm()
	arena_setup_panel.hide()
	arena_panel.hide()
	_hide_unit_info_panel_immediate()

	# --- SMOOTH MUSIC SWAP: Arena back to City ---
	_crossfade_music(arena_bgm, city_bgm)

# ==========================================
# --- AUDIO UTILITIES ---
# ==========================================
func _crossfade_music(track_out: AudioStreamPlayer, track_in: AudioStreamPlayer, duration: float = 1.0) -> void:
	var tw = create_tween().set_parallel(true)
	
	# Fade out the old track
	if track_out and track_out.playing:
		tw.tween_property(track_out, "volume_db", -60.0, duration).set_trans(Tween.TRANS_SINE)
		
	# Fade in the new track
	if track_in:
		if not track_in.playing:
			track_in.volume_db = -60.0 # Start silent
			track_in.play()
		tw.tween_property(track_in, "volume_db", 0.0, duration).set_trans(Tween.TRANS_SINE)
		
	# Once the fade is complete, stop the old track completely to save CPU
	tw.chain().tween_callback(func():
		if track_out and track_out.playing and track_out.volume_db <= -59.0:
			track_out.stop()
	)

# =========================================================================
# FUNCTION: _build_roadmap_ui
# PURPOSE: Dynamically generates the rank icons, rank names, and claim buttons.
# =========================================================================
func _build_roadmap_ui() -> void:
	for child in markers_container.get_children():
		child.queue_free()

	var current_player_rank_idx = ArenaManager.get_rank_data(CampaignManager.arena_mmr)["index"]

	for i in range(rank_hierarchy.size()):
		var rank_name_str = rank_hierarchy[i]
		
		var mmr_req = 0
		if i == 1: mmr_req = 1200
		elif i == 2: mmr_req = 1400
		elif i == 3: mmr_req = 1600
		elif i == 4: mmr_req = 1800
		elif i == 5: mmr_req = 2000
		
		var rank_data = ArenaManager.get_rank_data(mmr_req)
		
		var marker_vbox = VBoxContainer.new()
		marker_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		marker_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# 1. The Rank Icon
		var icon_rect = TextureRect.new()
		icon_rect.texture = ArenaManager.get_rank_icon(mmr_req)
		icon_rect.custom_minimum_size = Vector2(50, 50)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		if i > current_player_rank_idx:
			icon_rect.modulate = Color(0.3, 0.3, 0.3, 1.0) 
			
		# 2. The Rank Name Label
		var name_lbl = Label.new()
		name_lbl.text = rank_name_str.to_upper()
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 16)
		
		if i <= current_player_rank_idx:
			name_lbl.add_theme_color_override("font_color", rank_data["color"])
		else:
			name_lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
			
		marker_vbox.add_child(icon_rect)
		marker_vbox.add_child(name_lbl)
		
		# 3. THE REWARD BUTTON / LABEL LOGIC
		if i == 0:
			# Bronze (No reward)
			var r_lbl = Label.new()
			r_lbl.text = "Starting Rank"
			r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			r_lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
			marker_vbox.add_child(r_lbl)
			
		elif CampaignManager.claimed_rank_rewards.has(i):
			# Already Claimed! (Safe from exploiters)
			var r_lbl = Label.new()
			r_lbl.text = "Claimed"
			r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			r_lbl.add_theme_color_override("font_color", Color.GRAY)
			marker_vbox.add_child(r_lbl)
			
		elif i <= current_player_rank_idx:
			# REACHED BUT NOT CLAIMED - SPAWN A BUTTON!
			var claim_btn = Button.new()
			var payout = rank_reward_payouts[i]
			claim_btn.text = "CLAIM\n" + payout["text"]
			claim_btn.add_theme_color_override("font_color", Color.GOLD)
			
			# Pulse animation to draw the player's eye (finite loops to avoid Tween infinite-loop warning)
			var pulse = create_tween().set_loops(9999)
			pulse.tween_property(claim_btn, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.6)
			pulse.tween_property(claim_btn, "modulate", Color.WHITE, 0.6)
			
			claim_btn.pressed.connect(func(): _claim_rank_reward(i, claim_btn))
			marker_vbox.add_child(claim_btn)
			
		else:
			# Locked Future Rank
			var r_lbl = Label.new()
			var payout = rank_reward_payouts[i]
			r_lbl.text = "Reward: " + payout["text"]
			r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			r_lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
			marker_vbox.add_child(r_lbl)
		
		markers_container.add_child(marker_vbox)
			
# =========================================================================
# FUNCTION: _animate_roadmap
# PURPOSE: Smoothly fills the progress bar to the player's current MMR percentage.
# =========================================================================
func _animate_roadmap() -> void:
	var current_mmr = CampaignManager.arena_mmr
	var rank_data = ArenaManager.get_rank_data(current_mmr)
	var rank_idx = rank_data["index"]
	var ratio = ArenaManager.get_rank_fill_ratio(current_mmr)
	
	# NON-OBVIOUS LOGIC: Visual Mapping
	# Because there are 6 ranks, there are 5 visual "segments" between them.
	# We map the player's rank index to these segments so the bar visually 
	# lines up with the evenly spaced HBoxContainer items.
	
	var total_segments = float(rank_hierarchy.size() - 1)
	var segment_size_percent = 100.0 / total_segments
	
	var base_fill = float(rank_idx) * segment_size_percent
	var partial_fill = ratio * segment_size_percent
	
	var target_percentage = min(base_fill + partial_fill, 100.0)
	
	# Start at 0 and tween up for a satisfying juiced effect!
	roadmap_bar.value = 0.0
	
	# Apply dynamic coloring to the bar based on current rank
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = rank_data["color"]
	roadmap_bar.add_theme_stylebox_override("fill", fill_style)
	
	var tw = create_tween()
	tw.tween_property(roadmap_bar, "value", target_percentage, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# =========================================================================
# FUNCTION: _claim_rank_reward (STATE-FIXED STREAMING FOUNTAIN VERSION)
# PURPOSE: Grants the token payout with a continuous stream of flying coins,
#          using a state dictionary to safely sync the math across all tweens.
# =========================================================================
func _claim_rank_reward(rank_idx: int, btn: Button) -> void:
	if CampaignManager.claimed_rank_rewards.has(rank_idx): return
	
	# 1. Lock the transaction
	CampaignManager.claimed_rank_rewards.append(rank_idx)
	btn.disabled = true
	
	var payout = rank_reward_payouts[rank_idx]
	var total_reward = payout["tokens"]
	var old_tokens = CampaignManager.gladiator_tokens
	var new_tokens = old_tokens + total_reward
	
	CampaignManager.gladiator_tokens = new_tokens
	CampaignManager.save_current_progress()
	
	# 2. AUDIO & SCREEN SHAKE
	if token_buy_sound: 
		token_buy_sound.pitch_scale = 1.4
		token_buy_sound.play()
		
	var original_pos = token_shop_panel.position
	var shake = create_tween()
	for i in range(5):
		shake.tween_property(token_shop_panel, "position", original_pos + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 0.04)
	shake.tween_property(token_shop_panel, "position", original_pos, 0.04)
		
	# 3. VISUAL: Button violently pops
	var btn_start_pos = btn.global_position + (btn.size / 2.0)
	btn.pivot_offset = btn.size / 2.0
	var btn_tw = create_tween().set_parallel(true)
	btn_tw.tween_property(btn, "scale", Vector2(1.5, 1.5), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	btn_tw.tween_property(btn, "modulate", Color(2.0, 1.5, 0.5, 0.0), 0.3).set_delay(0.1) 
	
	# 4. THE CONTINUOUS LOOT FOUNTAIN
	var num_coins = clamp(int(total_reward / 3.0), 10, 60)
	var tokens_per_coin = float(total_reward) / float(num_coins)
	var spawn_delay = 1.5 / float(num_coins)
	
	# --- THE FIX: Pack the math into a Dictionary to force Pass-By-Reference ---
	var state = {
		"arrived": 0,
		"visual_total": float(old_tokens)
	}
	# --------------------------------------------------------------------------
	
	for i in range(num_coins):
		var coin = Panel.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color.GOLD
		style.border_color = Color.WHITE
		style.border_width_bottom = 2; style.border_width_top = 2
		style.border_width_left = 2; style.border_width_right = 2
		style.corner_radius_top_left = 15; style.corner_radius_top_right = 15
		style.corner_radius_bottom_left = 15; style.corner_radius_bottom_right = 15
		coin.add_theme_stylebox_override("panel", style)
		
		coin.custom_minimum_size = Vector2(24, 24)
		coin.global_position = btn_start_pos
		token_shop_panel.add_child(coin)
		
		var c_tw = create_tween()
		
		# A. EXPLODE OUTWARD 
		var explode_offset = Vector2(randf_range(-150, 150), randf_range(-100, -250))
		var explode_pos = coin.global_position + explode_offset
		c_tw.tween_property(coin, "global_position", explode_pos, 0.3).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
		
		# B. HANG IN THE AIR 
		c_tw.tween_interval(randf_range(0.0, 0.2))
		
		# C. SUCK INTO THE WALLET
		c_tw.tween_property(coin, "global_position", shop_token_display.global_position + (shop_token_display.size / 2.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		
		# D. IMPACT RESOLUTION
		c_tw.tween_callback(func():
			if not is_instance_valid(shop_token_display): return 
			
			coin.queue_free()
			
			# Modify the dictionary state so every coin shares the exact same tally
			state["arrived"] += 1
			state["visual_total"] += tokens_per_coin
			
			if state["arrived"] == num_coins:
				shop_token_display.text = "Gladiator Tokens: " + str(new_tokens)
				_build_roadmap_ui() 
			else:
				shop_token_display.text = "Gladiator Tokens: " + str(int(round(state["visual_total"])))
				
			shop_token_display.pivot_offset = shop_token_display.size / 2.0
			var bump = create_tween()
			bump.tween_property(shop_token_display, "scale", Vector2(1.3, 1.3), 0.05)
			bump.tween_property(shop_token_display, "scale", Vector2(1.0, 1.0), 0.1)
			
			if gladiator_blip:
				gladiator_blip.pitch_scale = randf_range(1.8, 2.5)
				gladiator_blip.play()
		)

		await get_tree().create_timer(spawn_delay).timeout

# ==========================================
# --- TAVERN TRANSITION ---
# ==========================================
func _open_tavern() -> void:
	if select_sound: select_sound.play()
	_hide_unit_info_panel_immediate()
	_close_auction_house()
	
	# Save progress just in case before swapping scenes
	CampaignManager.save_current_progress()
	
	# Transition to the new scene!
	SceneTransition.change_scene_to_file("res://Scenes/UI/GrandTavern.tscn")

# ==========================================
# --- SCAVENGER NETWORK TRANSITION ---
# ==========================================
func _open_scavenger_network() -> void:
	if select_sound: select_sound.play()
	_hide_unit_info_panel_immediate()
	_close_auction_house()
	
	if scavenger_ui:
		scavenger_ui.open_network()
	else:
		push_error("ScavengerUI node is missing from the CityMenu scene!")
