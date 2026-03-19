@tool
extends EditorScript

# INSTRUCTIONS: 
# 1. Edit the 'new_message' variable below.
# 2. Press 'File -> Run' or 'Ctrl + Shift + X' while this script is open.
# 3. Check the output console to confirm success.

func _run() -> void:
	var new_message = "A mysterious scavenger was spotted near the Iron Peaks. Check the network for rare ores."
	
	var metadata = {
		"message": new_message
	}
	
	print("Attempting to update MOTD...")
	
	# We use a score of 1 because "Best only" is enabled on the dashboard.
	# The player name "SYSTEM" identifies the source.
	var sw_result = await SilentWolf.Scores.save_score("SYSTEM", 1, "motd", metadata).sw_save_score_complete
	
	print("MOTD successfully updated in the cloud.")
