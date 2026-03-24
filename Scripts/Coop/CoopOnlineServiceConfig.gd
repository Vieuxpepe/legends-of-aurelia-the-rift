class_name CoopOnlineServiceConfig
extends RefCounted

const SILENT_WOLF_API_KEY: String = "9nUCdzXpftaLyust60GNQ62GDKSzbzqM1xQtJHgn"
const SILENT_WOLF_GAME_ID: String = "tacticalrpgmultiplayer"


static func ensure_silent_wolf_ready() -> bool:
	if SilentWolf == null:
		return false
	var current_cfg: Variant = SilentWolf.get("config")
	var log_level: int = 0
	if current_cfg is Dictionary:
		log_level = int((current_cfg as Dictionary).get("log_level", 0))
	var current_key: String = ""
	var current_game_id: String = ""
	if current_cfg is Dictionary:
		var cfg: Dictionary = current_cfg as Dictionary
		current_key = str(cfg.get("api_key", "")).strip_edges()
		current_game_id = str(cfg.get("game_id", "")).strip_edges()
	var needs_config: bool = (
		current_key == ""
		or current_key.contains("YOURAPIKEY")
		or current_game_id == ""
		or current_game_id == "YOURGAMEID"
		or current_key != SILENT_WOLF_API_KEY
		or current_game_id != SILENT_WOLF_GAME_ID
	)
	if needs_config:
		SilentWolf.configure({
			"api_key": SILENT_WOLF_API_KEY,
			"game_id": SILENT_WOLF_GAME_ID,
			"log_level": log_level,
		})
	return true


static func get_logged_in_player_name() -> String:
	if SilentWolf == null:
		return ""
	var auth_node: Variant = SilentWolf.get("Auth")
	if auth_node == null:
		return ""
	var logged_in: Variant = auth_node.get("logged_in_player")
	return str(logged_in).strip_edges()
