# ==============================================================================
# SCRIPT: TavernChat.gd
# PURPOSE: Manages a live-polling chat interface using SilentWolf.
# GOAL: Provide real-time (asynchronous) communication for players in the Tavern.
# DEPENDENCIES: 
#   - SilentWolf (Backend service for message storage on 'tavern_chat' board)
#   - CampaignManager (Provides custom_avatar name)
# AI/CODE REVIEWER GUIDANCE:
#   - Entry Point: _ready() starts the polling timer and initial fetch.
#   - Core Logic: _on_send_pressed() pushes data; _fetch_latest_messages() pulls data.
#   - Non-obvious logic: We use Unix timestamps as the 'score' so SilentWolf 
#     naturally returns the most recent messages when querying the top scores.
# ==============================================================================

extends Control

@onready var chat_scroll: ScrollContainer = $ChatScroll
@onready var message_list: VBoxContainer = $ChatScroll/MessageList
@onready var chat_input: LineEdit = $ChatInput
@onready var send_btn: Button = $SendButton
@onready var polling_timer: Timer = $PollingTimer

var is_fetching: bool = false
var last_known_message_count: int = 0

# Purpose: Initializes UI connections and starts the chat loop.
# Inputs: None.
# Outputs: None.
func _ready() -> void:
	if send_btn: send_btn.pressed.connect(_on_send_pressed)
	if chat_input: chat_input.text_submitted.connect(_on_text_submitted)
	if polling_timer: polling_timer.timeout.connect(_on_timer_timeout)
	
	_fetch_latest_messages()

# Purpose: Wrapper to allow pressing 'Enter' to send a message.
# Inputs: new_text (String) - The text from the LineEdit.
# Outputs: None.
func _on_text_submitted(_new_text: String) -> void:
	_on_send_pressed()

# Purpose: Packages the chat message and pushes it to the SilentWolf database.
# Inputs: None.
# Outputs: None.
# Side effects: Disables input temporarily, sends network request, updates UI.
func _on_send_pressed() -> void:
	var msg_text = chat_input.text.strip_edges()
	if msg_text == "": 
		return
		
	chat_input.clear()
	send_btn.disabled = true
	
	var player_name = CampaignManager.get_player_display_name("Traveler")
	var current_time = int(Time.get_unix_time_from_system())
	
	# 1. Pack the message into metadata (Keep it as a Dictionary)
	var metadata_dict = {
		"message": msg_text,
		"timestamp": Time.get_time_string_from_system()
	}
	
	# 2. Correct parameter order: name, score, leaderboard_name, metadata
	var _sw_result = await SilentWolf.Scores.save_score(
		player_name, 
		current_time, 
		"tavern_chat", 
		metadata_dict
	).sw_save_score_complete
	
	send_btn.disabled = false
	chat_input.grab_focus()
	
	# Immediately fetch to show the player's own message
	_fetch_latest_messages()
	
# Purpose: Timer callback to trigger periodic silent updates.
func _on_timer_timeout() -> void:
	if is_inside_tree():
		_fetch_latest_messages()
		
# Purpose: Retrieves the most recent messages and updates the UI.
# Inputs: None.
# Outputs: None.
# Side effects: Instantiates new Label nodes in the message_list VBox.
# Purpose: Retrieves the most recent messages from the correct custom leaderboard.
func _fetch_latest_messages() -> void:
	# 1. SAFETY CHECK: Abort if the scene is closing or not fully loaded
	if not is_inside_tree() or is_fetching: 
		return
		
	is_fetching = true
	
	var _sw_result = await SilentWolf.Scores.get_scores(20, "tavern_chat").sw_get_scores_complete
	
	# 2. SAFETY CHECK: Abort if the player closed the scene while the cloud was processing
	if not is_inside_tree():
		return
		
	var raw_scores = SilentWolf.Scores.leaderboards.get("tavern_chat", [])
	var scores = raw_scores.duplicate() 
	
	is_fetching = false
	
	if scores.is_empty():
		return
	
	for child in message_list.get_children():
		child.queue_free()
		
	scores.reverse()
	
	for entry in scores:
		_create_chat_bubble(entry)
		
	await get_tree().process_frame
	
	# 3. SAFETY CHECK: Ensure the scroll node still exists before manipulating it
	if is_inside_tree() and chat_scroll.get_v_scroll_bar() != null:
		chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)
		
# Purpose: Parses the message data and creates a formatted UI element.
# Inputs: entry (Dictionary) - A single score entry from SilentWolf.
# Outputs: None.
func _create_chat_bubble(entry: Dictionary) -> void:
	var raw_metadata = entry.get("metadata", "{}")
	var data = {}
	if raw_metadata is String:
		data = JSON.parse_string(raw_metadata)
	else:
		data = raw_metadata
		
	if data == null: data = {"message": "[Corrupted scroll]"}
	
	var sender = entry.get("player_name", "Unknown")
	var msg = data.get("message", "...")
	var time_str = data.get("timestamp", "")
	
	var msg_label = RichTextLabel.new()
	msg_label.bbcode_enabled = true
	msg_label.fit_content = true
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.custom_minimum_size = Vector2(0, 24)
	
	# Format: [Time] PlayerName: Message
	msg_label.text = "[color=gray][" + time_str + "][/color] [color=cyan]" + sender + ":[/color] " + msg
	
	message_list.add_child(msg_label)
