# ==============================================================================
# Script Name: TavernNoticeBoard.gd
# Purpose: Handles fetching and updating the SilentWolf Message of the Day.
# Overall Goal: Provide a dedicated, non-NPC interaction point for server news.
# Project Fit: Attached to a Button or TextureRect in the Grand Tavern scene.
# Dependencies: Requires SilentWolf to be initialized. Relies on the parent UI
#               for dialogue panel rendering.
# AI/Code Reviewer Guidance:
#   - Entry Point: interact() triggers the network fetch.
#   - Core Logic Sections: _fetch_silentwolf_motd handles the GET request.
#   - Admin Logic: _input intercepts the 'U' key to open the MOTD update field.
# ==============================================================================
extends Node

@onready var parent_ui: Control = get_parent()
var admin_input_box: LineEdit = null

# Purpose: Public entry point called when the player clicks the notice board.
# Inputs: None.
# Outputs: None.
# Side effects: Triggers network request and alters UI state.
func interact() -> void:
	_fetch_silentwolf_motd()

# Purpose: Retrieves the latest message from the SilentWolf 'motd' leaderboard.
# Inputs: None.
# Outputs: None.
# Side effects: Modifies the dialogue panel text to display network results.
func _fetch_silentwolf_motd() -> void:
	parent_ui.dialogue_panel.show()
	parent_ui.choice_container.hide()
	parent_ui.speaker_name.text = "Notice Board"
	parent_ui.dialogue_text.text = "[color=gray][i]Checking the notice board...[/i][/color]"
	
	# Fetch the single highest score to get the most recent message
	var _sw_result = await SilentWolf.Scores.get_scores(1, "motd").sw_get_scores_complete
	var scores = SilentWolf.Scores.scores
	
	if not scores.is_empty():
		parent_ui.dialogue_text.text = scores[0].get("metadata", {}).get("message", "The notice is blank.")
	else:
		parent_ui.dialogue_text.text = "No new messages from the capital."
		
	parent_ui.next_btn.show()
	
	# Clear character portraits for inanimate objects
	parent_ui.active_character_a = {}
	parent_ui.active_character_b = {}
	
	# Set to an index that forces the dialogue manager to close on 'Next'
	parent_ui.current_dialogue_index = 999 

# ==============================================================================
# ADMIN CONSOLE LOGIC
# ==============================================================================

# Purpose: Listens for the 'U' key to open the MOTD input field.
# Inputs: event (InputEvent)
# Outputs: None.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_U:
		_show_admin_input()

# Purpose: Spawns a LineEdit in the center of the screen for MOTD updates.
# Inputs: None.
# Outputs: None.
# Side effects: Instantiates a UI node as a child of parent_ui.
func _show_admin_input() -> void:
	if admin_input_box != null: 
		return 
		
	admin_input_box = LineEdit.new()
	admin_input_box.placeholder_text = "Type new MOTD and press Enter..."
	admin_input_box.alignment = HORIZONTAL_ALIGNMENT_CENTER
	admin_input_box.custom_minimum_size = Vector2(800, 60)
	
	parent_ui.add_child(admin_input_box)
	admin_input_box.set_anchors_preset(Control.PRESET_CENTER)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.95)
	style.set_border_width_all(3)
	style.border_color = Color.CYAN
	style.set_content_margin_all(10)
	admin_input_box.add_theme_stylebox_override("normal", style)
	admin_input_box.add_theme_font_size_override("font_size", 24)
	
	admin_input_box.grab_focus()
	admin_input_box.text_submitted.connect(_on_motd_submitted)
	admin_input_box.focus_exited.connect(_cleanup_admin_input)

# Purpose: Processes the typed message and pushes it to the SilentWolf backend.
# Inputs: new_text (String) - The text entered by the developer.
# Outputs: None.
# Side effects: Sends a POST request to SilentWolf.
func _on_motd_submitted(new_text: String) -> void:
	if new_text.strip_edges() != "":
		if parent_ui.has_method("_show_system_message"):
			parent_ui._show_system_message("Syncing with Cloud...", Color.CYAN)
			
		var metadata = {"message": new_text}
		var fresh_score = int(Time.get_unix_time_from_system())
		
		await SilentWolf.Scores.save_score("SYSTEM", fresh_score, "motd", metadata).sw_save_score_complete
		
		if parent_ui.has_method("_show_system_message"):
			parent_ui._show_system_message("MOTD updated.", Color.GREEN)
			
	_cleanup_admin_input()

# Purpose: Removes the LineEdit node from the scene tree.
# Inputs: None.
# Outputs: None.
func _cleanup_admin_input() -> void:
	if admin_input_box: 
		admin_input_box.queue_free()
		admin_input_box = null
