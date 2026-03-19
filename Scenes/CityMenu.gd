extends Control

# CityMenu.gd – Arena 2.0 (Juiced, Ranked, & Token Shop)
@onready var back_button: Button = $BackButton

@onready var shop_desc_label: RichTextLabel = $TokenShopPanel/ShopDescription
@onready var shop_item_preview: TextureRect = $TokenShopPanel/ShopItemPreview

# --- Scavenger Network References ---
@onready var scavenger_button: Button = get_node_or_null("ScavengerButton")
@onready var scavenger_ui: Control = get_node_or_null("ScavengerUI")

var active_shop_inventory: Array[Resource] = []

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
var highlighted_item: Resource = null
var gladiator_tween: Tween

# The exact payouts for reaching each rank index
var rank_reward_payouts = [
	{"tokens": 0, "text": "Starting Rank"},       # 0 - Bronze
	{"tokens": 25, "text": "25 Tokens"},          # 1 - Silver
	{"tokens": 50, "text": "50 Tokens"},          # 2 - Gold
	{"tokens": 100, "text": "100 Tokens"},        # 3 - Platinum
	{"tokens": 250, "text": "250 Tokens"},        # 4 - Diamond
	{"tokens": 500, "text": "500 Tokens"}         # 5 - Grandmaster
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

# --- Team Setup References ---
@onready var arena_setup_panel: Control = $ArenaSetupPanel
@onready var roster_grid: GridContainer = $ArenaSetupPanel/RosterGrid
@onready var team_grid: GridContainer = $ArenaSetupPanel/TeamGrid
@onready var confirm_team_btn: Button = $ArenaSetupPanel/ConfirmTeamButton
@onready var close_setup_btn: Button = $ArenaSetupPanel/CloseSetupButton

# --- Unit Info Panel References ---
@onready var unit_info_panel: Control = $UnitInfoPanel
@onready var info_portrait: TextureRect = $UnitInfoPanel/PortraitRect
@onready var info_name: Label = $UnitInfoPanel/NameLabel
@onready var info_class: Label = $UnitInfoPanel/ClassLabel
@onready var info_level: Label = $UnitInfoPanel/LevelLabel
@onready var info_hp: Label = $UnitInfoPanel/HPLabel
@onready var info_stats: Label = $UnitInfoPanel/StatsLabel
@onready var info_weapon: Label = $UnitInfoPanel/WeaponLabel

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

@onready var streak_badge: Control = $GladiatorStreakBadge
@onready var streak_label: Label = $GladiatorStreakBadge/Label
@onready var streak_sub_label: Label = $GladiatorStreakBadge/SubLabel
@onready var streak_flame_particles: CPUParticles2D = $GladiatorStreakBadge/FlameParticles

var selected_team: Array = []
var rank_hierarchy: Array[String] = ["Bronze", "Silver", "Gold", "Platinum", "Diamond", "Grandmaster"]

@onready var tavern_button: Button = $TavernButton

# ==========================================
# --- INITIALIZATION ---
# ==========================================

func _ready() -> void:
	# =========================================================================
	# GUIDANCE FOR AI/REVIEWERS: TEST CHEAT BLOCK
	# PURPOSE: Temporarily overrides CampaignManager variables to test the 
	# one-time rank reward logic in the Token Shop roadmap.
	# NON-OBVIOUS LOGIC: By setting MMR to 2100, we force the UI to render all 
	# 5 claimable buttons simultaneously to verify the loop works.
	# =========================================================================
	CampaignManager.arena_mmr = 2100 # Forces Grandmaster Rank
	CampaignManager.claimed_rank_rewards.clear() # Erases claim history
	CampaignManager.gladiator_tokens = 0 # Resets wallet to 0 for easy reading
	# =========================================================================
	
	# ==========================================
	# --- TEST CHEAT: FORCE RANK UP ANIMATION ---
	# (Delete this block after you test it!)
	# ==========================================
	ArenaManager.last_match_result = "VICTORY"
	ArenaManager.last_match_old_mmr = 1180  # High Bronze
	ArenaManager.last_match_new_mmr = 1210  # Low Silver (Triggers the Rank Up!)
	ArenaManager.last_match_mmr_change = 30
	ArenaManager.last_match_gold_reward = 150
	ArenaManager.last_match_token_reward = 5
	# ==========================================
	if back_button: back_button.pressed.connect(_on_back_pressed)
	if arena_button: arena_button.pressed.connect(_open_setup_panel)
	if close_arena_button: close_arena_button.pressed.connect(_close_arena)
	if refresh_matches_button: refresh_matches_button.pressed.connect(_fetch_matches)
	if confirm_team_btn: confirm_team_btn.pressed.connect(_lock_team_and_search)
	if close_setup_btn: close_setup_btn.pressed.connect(_close_arena)
	if leaderboard_btn: leaderboard_btn.pressed.connect(_show_leaderboard)
	if close_leaderboard_btn: close_leaderboard_btn.pressed.connect(func(): leaderboard_panel.hide())
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
	if unit_info_panel: unit_info_panel.hide()
	if defense_popup: defense_popup.hide()
	if arena_result_sequence: arena_result_sequence.hide()
	if ghost_inspect_panel: ghost_inspect_panel.hide()
	
	$ArenaPanel/LeaderboardPanel/GhostInspectPanel/CloseButton.pressed.connect(func(): 
		ghost_inspect_panel.hide()
		if unit_info_panel: unit_info_panel.hide()
	)
	
	ArenaManager.current_opponent_data = {}
	ArenaManager.local_arena_team.clear()
	
	_configure_arena_ui_fx()
	_refresh_gladiator_badge()

	if ArenaManager.last_match_result != "":
		# The player just finished a match! Clear the shop so it rerolls next time they open it.
		active_shop_inventory.clear() 
		await _play_arena_result_sequence()
		ArenaManager.last_match_result = ""
	
	call_deferred("_check_offline_rewards")

func _configure_arena_ui_fx() -> void:
	if arena_result_bar:
		arena_result_bar.min_value = 0.0
		arena_result_bar.max_value = 100.0

# ==========================================
# --- TOKEN SHOP CORE LOGIC ---
# ==========================================

func _open_token_shop() -> void:
	arena_panel.hide()
	arena_setup_panel.hide()
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
	if active_shop_inventory.is_empty():
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
	
	var old_mmr = ArenaManager.last_match_old_mmr
	var new_mmr = ArenaManager.last_match_new_mmr
	var mmr_delta = ArenaManager.last_match_mmr_change
	var won = ArenaManager.last_match_result == "VICTORY"
	
	var old_rank = ArenaManager.get_rank_data(old_mmr)
	var new_rank = ArenaManager.get_rank_data(new_mmr)
	
	arena_result_title.text = "ARENA VICTORY" if won else "ARENA DEFEAT"
	arena_result_title.add_theme_color_override("font_color", Color.LIME if won else Color.RED)
	arena_result_delta_label.text = ArenaManager.format_signed(mmr_delta) + " MMR"

	if won:
		arena_result_rewards.text = "[center][color=gold]+%d Gold[/color]  [color=orange]+%d Tokens[/color][/center]" % [ArenaManager.last_match_gold_reward, ArenaManager.last_match_token_reward]
	else:
		arena_result_rewards.text = "[center][color=tomato]Streak Broken[/color][/center]"

	# Initialize locked to the old rank
	_set_result_meter_from_mmr(float(old_mmr), old_mmr)

	# --- RANK UP SEQUENCE ---
	if old_rank["index"] < new_rank["index"]:
		var threshold = float(old_rank["max"]) # Hit the ceiling of the old rank
		var tw = create_tween()
		tw.tween_method(func(v: float): _set_result_meter_from_mmr(v, old_mmr), float(old_mmr), threshold, 1.0).set_trans(Tween.TRANS_CUBIC)
		await tw.finished
		
		# Wait for the epic slam. It will swap visuals at the moment of impact!
		await _play_rank_stamp(threshold, new_mmr, true)
		
		# Fill the rest of the bar in the new rank
		var tw2 = create_tween()
		tw2.tween_method(func(v: float): _set_result_meter_from_mmr(v, new_mmr), threshold, float(new_mmr), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await tw2.finished

	# --- RANK DOWN SEQUENCE ---
	elif old_rank["index"] > new_rank["index"]:
		var threshold = float(old_rank["min"]) # Hit the floor of the old rank
		var tw = create_tween()
		tw.tween_method(func(v: float): _set_result_meter_from_mmr(v, old_mmr), float(old_mmr), threshold, 1.0).set_trans(Tween.TRANS_CUBIC)
		await tw.finished
		
		await _play_rank_stamp(threshold, new_mmr, false)
		
		var tw2 = create_tween()
		tw2.tween_method(func(v: float): _set_result_meter_from_mmr(v, new_mmr), threshold, float(new_mmr), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await tw2.finished

	# --- NORMAL SEQUENCE (No change) ---
	else:
		var tw = create_tween()
		tw.tween_method(func(v: float): _set_result_meter_from_mmr(v, old_mmr), float(old_mmr), float(new_mmr), 1.5).set_trans(Tween.TRANS_CUBIC)
		await tw.finished
		await get_tree().create_timer(0.5).timeout

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
	
	var out_tw = create_tween()
	out_tw.tween_property(arena_result_sequence, "modulate:a", 0.0, 0.4)
	await out_tw.finished
	
	if continue_lbl: continue_lbl.hide()
	arena_result_sequence.hide()
	arena_result_stamp.hide()
		
func _set_result_meter_from_mmr(display_mmr: float, forced_rank_mmr: int = -1) -> void:
	var mmr_int = int(round(display_mmr))
	
	# Lock the visuals to a specific rank if requested
	var eval_mmr = mmr_int if forced_rank_mmr == -1 else forced_rank_mmr
	var rank_data = ArenaManager.get_rank_data(eval_mmr)

	arena_result_rank_name.text = str(rank_data["name"]).to_upper()
	arena_result_rank_name.add_theme_color_override("font_color", rank_data["color"])
	arena_result_rating_label.text = "RATING %d MMR" % mmr_int
	
	# --- NEW: APPLY COLOR TO STANDARD PROGRESS BAR ---
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = rank_data["color"]
	# Optional: Give it slightly rounded corners so it looks nicer!
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	arena_result_bar.add_theme_stylebox_override("fill", fill_style)
	# -------------------------------------------------

	# Calculate the percentage based on the locked rank's boundaries
	var r_min = float(rank_data["min"])
	var r_max = float(rank_data["max"])
	var span = max(1.0, r_max - r_min)
	var ratio = clamp((float(mmr_int) - r_min) / span, 0.0, 1.0)
	
	arena_result_bar.value = ratio * 100.0
	arena_result_bar_value.text = "%d%%" % int(round(ratio * 100.0))
	
	var icon = ArenaManager.get_rank_icon(eval_mmr)
	if icon: arena_result_rank_icon.texture = icon
		
func _play_rank_stamp(current_visual_mmr: float, target_mmr: int, went_up: bool) -> void:
	var rank_data = ArenaManager.get_rank_data(target_mmr)
	var rank_name = rank_data["name"]
	var rank_color = rank_data["color"]
	
	arena_result_stamp.text = ("RANK UP! " if went_up else "RANK DOWN! ") + rank_name.to_upper()
	arena_result_stamp.add_theme_color_override("font_color", rank_color)
	arena_result_stamp.show()
	
	if went_up:
		arena_result_stamp.scale = Vector2(8, 8)
		arena_result_stamp.modulate.a = 0.0
		
		var s_tw = create_tween()
		# Anticipation Hover
		s_tw.tween_property(arena_result_stamp, "modulate:a", 1.0, 0.2)
		s_tw.parallel().tween_property(arena_result_stamp, "scale", Vector2(4, 4), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		# The Slam Down
		s_tw.tween_property(arena_result_stamp, "scale", Vector2(0.9, 0.9), 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		
		# --- THE IMPACT FIX ---
		# Wait exactly 0.55s (0.4 hover + 0.15 slam) for the stamp to hit the UI!
		await get_tree().create_timer(0.55).timeout
		
		# SWAP THE ICON & COLORS EXACTLY ON IMPACT
		_set_result_meter_from_mmr(current_visual_mmr, target_mmr)
		
		# Bounce the stamp back up to normal size
		var bounce_tw = create_tween()
		bounce_tw.tween_property(arena_result_stamp, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

		if token_buy_sound: 
			token_buy_sound.pitch_scale = 1.3 
			token_buy_sound.play()
			
		if arena_result_burst: 
			arena_result_burst.emitting = true
			
		# Bounce the new Rank Icon
		if arena_result_rank_icon:
			arena_result_rank_icon.pivot_offset = arena_result_rank_icon.size / 2.0
			var icon_tw = create_tween()
			icon_tw.tween_property(arena_result_rank_icon, "scale", Vector2(1.5, 1.5), 0.1).set_trans(Tween.TRANS_ELASTIC)
			icon_tw.tween_property(arena_result_rank_icon, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BOUNCE)

		# Screen Shake
		var original_pos = arena_result_panel.position
		var shake = create_tween()
		for i in range(8):
			var offset = Vector2(randf_range(-25, 25), randf_range(-25, 25))
			shake.tween_property(arena_result_panel, "position", original_pos + offset, 0.03)
		shake.tween_property(arena_result_panel, "position", original_pos, 0.03)
		
		# Golden Flash
		if arena_result_flash:
			arena_result_flash.color = Color(1.0, 0.9, 0.5, 1.0)
			arena_result_flash.show()
			arena_result_flash.modulate.a = 1.0
			var flash_tw = create_tween()
			flash_tw.tween_property(arena_result_flash, "modulate:a", 0.0, 0.8)
			await flash_tw.finished
			arena_result_flash.hide()
			
	else:
		# Sad Rank Down Sequence
		arena_result_stamp.scale = Vector2(2.5, 2.5)
		arena_result_stamp.modulate.a = 0.0
		
		var s_tw = create_tween().set_parallel(true)
		s_tw.tween_property(arena_result_stamp, "scale", Vector2(1,1), 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		s_tw.tween_property(arena_result_stamp, "modulate:a", 1.0, 0.3)
		
		await get_tree().create_timer(0.5).timeout
		
		# Swap Icon on impact
		_set_result_meter_from_mmr(current_visual_mmr, target_mmr)
		
		if token_buy_sound: 
			token_buy_sound.pitch_scale = 0.5 
			token_buy_sound.play()
		
		var original_pos = arena_result_panel.position
		var shake = create_tween()
		for i in range(3):
			var offset = Vector2(randf_range(-5, 5), randf_range(-5, 5))
			shake.tween_property(arena_result_panel, "position", original_pos + offset, 0.05)
		shake.tween_property(arena_result_panel, "position", original_pos, 0.05)
		await shake.finished
				
# ==========================================
# --- MATCHMAKING & LOBBY ---
# ==========================================

func _on_back_pressed() -> void:
	SceneTransition.change_scene_to_file("res://Scenes/UI/WorldMap.tscn")

func _open_setup_panel() -> void:
	selected_team.clear()
	_refresh_setup_ui()
	arena_setup_panel.show()
	

func _refresh_setup_ui() -> void:
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
		btn.mouse_entered.connect(func(): _update_unit_info(unit))
		btn.pressed.connect(func():
			if selected_team.size() < 3:
				selected_team.append(unit)
				_refresh_setup_ui()
		)
		roster_grid.add_child(btn)
		
	for i in range(3):
		var b := Button.new()
		b.custom_minimum_size = Vector2(100, 100)
		if i < selected_team.size():
			var chosen_unit = selected_team[i]
			b.text = chosen_unit.get("unit_name", chosen_unit.get("name", "???"))
			b.modulate = Color(0.4, 0.8, 1.0, 1.0)
			b.mouse_entered.connect(func(): _update_unit_info(chosen_unit))
			b.pressed.connect(func():
				selected_team.erase(chosen_unit)
				_refresh_setup_ui()
			)
		else:
			b.text = "Empty"
			b.disabled = true
		team_grid.add_child(b)
		
	confirm_team_btn.disabled = selected_team.is_empty()
	var current_mmr = ArenaManager.get_local_mmr()
	var rank_data = ArenaManager.get_rank_data(current_mmr)
	var current_power = ArenaManager._calculate_combat_power(selected_team)
	
	var stats_lbl = arena_setup_panel.get_node_or_null("TeamStatsLabel")
	if stats_lbl == null:
		stats_lbl = RichTextLabel.new()
		stats_lbl.name = "TeamStatsLabel"
		stats_lbl.bbcode_enabled = true
		stats_lbl.custom_minimum_size = Vector2(400, 80)
		stats_lbl.add_theme_font_size_override("normal_font_size", 22)
		stats_lbl.position = Vector2(confirm_team_btn.position.x, confirm_team_btn.position.y - 80)
		arena_setup_panel.add_child(stats_lbl)
		
	var hex_color = rank_data["color"].to_html(false)
	stats_lbl.text = "[center][b]Rank:[/b] [color=#%s]%s[/color] (%d MMR)\n[b]Power:[/b] %d[/center]" % [hex_color, rank_data["name"], current_mmr, current_power]
	
	token_display.text = "Gladiator Tokens: %d" % CampaignManager.gladiator_tokens
	token_display.add_theme_color_override("font_color", Color(1.0, 0.65, 0.0))

func _update_unit_info(unit) -> void:
	if unit_info_panel: unit_info_panel.show()
	
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
	if selected_team.is_empty(): return
	ArenaManager.local_arena_team = selected_team.duplicate()
	arena_setup_panel.hide()
	arena_panel.show()
	status_label.text = "Uploading team..."
	confirm_team_btn.disabled = true
	await ArenaManager.push_team_to_cloud(selected_team)
	_fetch_matches()

func _fetch_matches() -> void:
	for child in opponent_container.get_children(): child.queue_free()
	refresh_matches_button.disabled = true
	var opponents = await ArenaManager.fetch_arena_opponents()
	refresh_matches_button.disabled = false
	status_label.text = "Select an opponent!"
	for opp in opponents: _create_opponent_card(opp)

# --- AI/Reviewer: Builds a single arena opponent card. Entry: _create_opponent_card(opp_data).
# Uses ArenaManager player-experience API: get_opponent_difficulty_label, get_estimated_rewards, get_rank_data.
# Layout: rank badge, name, MMR/power, difficulty, then win/loss reward estimates.
## Creates a button card for one arena opponent and adds it to opponent_container.
##
## Purpose: Display opponent rank, name, MMR, power, difficulty label, and estimated win/loss rewards
## so the player can choose who to fight with full context. Uses ArenaManager.get_opponent_difficulty_label
## and ArenaManager.get_estimated_rewards for the new player-experience data.
##
## Inputs:
##   opp_data (Dictionary): Score entry from fetch_arena_opponents; must have "score" (MMR) and "metadata"
##     with "player_name", "power_rating". May have "metadata" from SilentWolf.
##
## Outputs: None.
##
## Side effects: Adds a new Button to opponent_container; connects pressed to set current_opponent_data
## and change scene to ArenaLevel.
func _create_opponent_card(opp_data: Dictionary) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 120)

	# Resolve opponent identity and MMR from leaderboard payload.
	var meta: Dictionary = opp_data.get("metadata", {})
	var opp_name: String = meta.get("player_name", "Unknown")
	var opp_mmr: int = int(opp_data.get("score", 1000))
	var power: int = int(meta.get("power_rating", 0))

	# Rank display: same tier badge and color as elsewhere (get_rank_data from ArenaManager).
	var rank_data: Dictionary = ArenaManager.get_rank_data(opp_mmr)
	var rank_label: String = rank_data["name"].to_upper()

	# Difficulty: from local player's perspective (positive diff = opponent stronger).
	var local_mmr: int = ArenaManager.get_local_mmr()
	var mmr_diff: int = opp_mmr - local_mmr
	var difficulty: String = ArenaManager.get_opponent_difficulty_label(mmr_diff)

	# Estimated rewards for win/loss so the player knows what they're playing for.
	var rewards: Dictionary = ArenaManager.get_estimated_rewards(opp_mmr)
	var win_mmr: int = rewards.get("mmr_on_win", 15)
	var loss_mmr: int = rewards.get("mmr_on_loss", -5)
	var win_gold: int = rewards.get("gold_on_win", 50)
	# Format signed MMR for display (e.g. "+15", "-5").
	var win_mmr_str: String = ArenaManager.format_signed(win_mmr)
	var loss_mmr_str: String = ArenaManager.format_signed(loss_mmr)

	# Assemble card text: rank, name, MMR/power, difficulty, then win | loss rewards.
	btn.text = "[ %s ] %s\nMMR: %d | Power: %d\nDifficulty: %s\nWin: %s MMR, +%d Gold | Loss: %s MMR" % [
		rank_label, opp_name, opp_mmr, power, difficulty,
		win_mmr_str, win_gold, loss_mmr_str
	]
	btn.add_theme_color_override("font_color", rank_data["color"])

	btn.pressed.connect(func():
		ArenaManager.current_opponent_data = opp_data
		SceneTransition.change_scene_to_file("res://Scenes/Levels/ArenaLevel.tscn")
	)
	opponent_container.add_child(btn)

func _show_leaderboard() -> void:
	leaderboard_panel.show()
	for child in leaderboard_container.get_children(): child.queue_free()
	status_label.text = "Fetching champions..."
	var _sw_result = await SilentWolf.Scores.get_scores(10, "arena").sw_get_scores_complete
	var top_scores = SilentWolf.Scores.scores
	
	if top_scores.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "The Arena is currently empty."
		leaderboard_container.add_child(empty_lbl)
		return

	top_scores.sort_custom(func(a, b): return a.score > b.score)
	for i in range(top_scores.size()):
		_create_leaderboard_row(i + 1, top_scores[i])

func _create_leaderboard_row(rank: int, data: Dictionary) -> void:
	var h_box = HBoxContainer.new()
	h_box.custom_minimum_size.y = 50
	var rank_lbl = Label.new()
	rank_lbl.text = "#%d " % rank
	rank_lbl.custom_minimum_size.x = 50
	if rank == 1: rank_lbl.add_theme_color_override("font_color", Color.GOLD)
	
	var name_btn = Button.new()
	name_btn.text = data.metadata.get("player_name", "Anonymous")
	name_btn.flat = true; name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_btn.add_theme_color_override("font_color", Color.CYAN)
	name_btn.pressed.connect(func(): _inspect_ghost_team(data))
	
	var mmr_lbl = Label.new()
	var mmr_val = int(data.score)
	var rank_info = ArenaManager.get_rank_data(mmr_val)
	mmr_lbl.text = "%d MMR" % mmr_val
	mmr_lbl.add_theme_color_override("font_color", rank_info["color"])
	
	h_box.add_child(rank_lbl); h_box.add_child(name_btn); h_box.add_child(mmr_lbl)
	leaderboard_container.add_child(h_box)

func _inspect_ghost_team(data: Dictionary) -> void:
	for child in ghost_team_grid.get_children(): child.queue_free()
	var meta = data.get("metadata", {})
	var full_team = meta.get("roster", []) + meta.get("dragons", [])
	
	ghost_title.text = meta.get("player_name", "Gladiator") + "'s Team"
	for unit_data in full_team:
		var unit_btn = Button.new()
		unit_btn.custom_minimum_size = Vector2(100, 100)
		var u_name = unit_data.get("unit_name", unit_data.get("name", "Unknown"))
		unit_btn.text = "%s\nLv.%d" % [u_name.substr(0,8), unit_data.get("level", 1)]
		
		if unit_data.has("portrait_path") and ResourceLoader.exists(unit_data["portrait_path"]):
			unit_btn.icon = load(unit_data["portrait_path"]); unit_btn.expand_icon = true
		
		unit_btn.mouse_entered.connect(func(): _update_unit_info(unit_data))
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
	arena_setup_panel.hide()
	arena_panel.hide()
	
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
	
	# Save progress just in case before swapping scenes
	CampaignManager.save_current_progress()
	
	# Transition to the new scene!
	SceneTransition.change_scene_to_file("res://Scenes/UI/GrandTavern.tscn")

# ==========================================
# --- SCAVENGER NETWORK TRANSITION ---
# ==========================================
func _open_scavenger_network() -> void:
	if select_sound: select_sound.play()
	
	if scavenger_ui:
		scavenger_ui.open_network()
	else:
		push_error("ScavengerUI node is missing from the CityMenu scene!")
