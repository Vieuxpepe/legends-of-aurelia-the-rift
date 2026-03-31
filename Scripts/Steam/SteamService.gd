extends Node
## Autoload: Steam API bootstrap for GodotSteam (Engine singleton `"Steam"`).
## - Calls `steamInitEx` / `steamInit` with AppID **4555530**.
## - Runs `run_callbacks()` every frame when initialized.
## - Sets Rich Presence: `status` (plain title) and `steam_display` (localization token).
##
## Setup you must do in Steamworks (partner site):
## Upload a Rich Presence localization `.vdf` that defines the token below, e.g.:
## ```
## "lang" {
##   "Language" "english"
##   "Tokens" {
##     "#LOA_Playing"  "Legends of Aurelia : The Rift"
##   }
## }
## ```
## Publish the localization before expecting `steam_display` to show for friends.
##
## Requires a GodotSteam build matching your engine (e.g. Godot 4.6). Without it,
## this node logs a warning and skips Steam calls.

const STEAM_APP_ID: int = 4555530
const GAME_DISPLAY_NAME: String = "Legends of Aurelia : The Rift"
## Must match a token in your Steamworks Rich Presence localization file.
const RICH_PRESENCE_STEAM_DISPLAY: String = "#LOA_Playing"

var steam_initialized: bool = false
var _api: Object = null
var _avatar_signal_connected: bool = false
var _awaiting_local_avatar: bool = false

## Fired when `request_local_player_avatar()` finishes; argument is null if Steam is off or avatar data is missing.
signal player_avatar_loaded(texture)


func _init() -> void:
	# Helps editor / non-Steam launches find the app until `steam_appid.txt` or Steam client supplies it.
	if str(OS.get_environment("SteamAppId")).strip_edges() == "":
		OS.set_environment("SteamAppId", str(STEAM_APP_ID))
		OS.set_environment("SteamGameId", str(STEAM_APP_ID))


func _ready() -> void:
	if not Engine.has_singleton("Steam"):
		push_warning(
			"SteamService: singleton 'Steam' not found. Add GodotSteam (GDExtension) for your Godot version."
		)
		return
	_api = Engine.get_singleton("Steam")
	var response: Dictionary = _initialize_steam()
	var status: int = int(response.get("status", -1))
	# GodotSteam: 0 = OK (see Initializing Steam tutorial on godotsteam.com).
	if status != 0:
		push_warning("SteamService: init failed (status=%s): %s" % [status, response])
		return
	steam_initialized = true
	# status 0 = OK (GodotSteam). Check Output when verifying friends-list / Rich Presence setup.
	print("SteamService: Steam initialized OK — status=%s full_response=%s" % [status, response])
	_apply_default_presence()


func _initialize_steam() -> Dictionary:
	if _api == null:
		return {"status": -1}
	if _api.has_method("steamInitEx"):
		return _api.steamInitEx(STEAM_APP_ID, false)
	if _api.has_method("steamInit"):
		var ok: bool = _api.steamInit(STEAM_APP_ID, false)
		return {"status": 0 if ok else 1}
	return {"status": -1}


func _process(_delta: float) -> void:
	if not steam_initialized or _api == null:
		return
	if _api.has_method("run_callbacks"):
		_api.run_callbacks()


func _apply_default_presence() -> void:
	if _api == null or not _api.has_method("setRichPresence"):
		return
	_api.setRichPresence("status", GAME_DISPLAY_NAME)
	_api.setRichPresence("steam_display", RICH_PRESENCE_STEAM_DISPLAY)


## Optional: update the secondary line (e.g. "In menu", "Campaign — Act II").
func set_status_line(line: String) -> void:
	if not steam_initialized or _api == null or not _api.has_method("setRichPresence"):
		return
	var text: String = line.strip_edges()
	if text == "":
		text = GAME_DISPLAY_NAME
	_api.setRichPresence("status", text)


## Switch `steam_display` to a different **localization token** from Steamworks.
func set_display_token(localization_token: String) -> void:
	if not steam_initialized or _api == null or not _api.has_method("setRichPresence"):
		return
	var tok: String = localization_token.strip_edges()
	if tok == "":
		tok = RICH_PRESENCE_STEAM_DISPLAY
	_api.setRichPresence("steam_display", tok)


func get_api() -> Object:
	return _api


func is_steam_ready() -> bool:
	return steam_initialized


## Local user's Steam display name when Steam is running and initialized; empty otherwise.
func get_steam_persona_name() -> String:
	if not steam_initialized or _api == null:
		return ""
	for method in ["getPersonaName", "get_persona_name"]:
		if _api.has_method(method):
			var n: Variant = _api.call(method)
			if n is String:
				var s: String = str(n).strip_edges()
				if s != "":
					return s
	var sid: Variant = null
	if _api.has_method("getSteamID"):
		sid = _api.getSteamID()
	elif _api.has_method("get_steam_id"):
		sid = _api.get_steam_id()
	for fname in ["getFriendPersonaName", "get_friend_persona_name"]:
		if sid != null and _api.has_method(fname):
			var n2: Variant = _api.call(fname, sid)
			if n2 is String:
				var s2: String = str(n2).strip_edges()
				if s2 != "":
					return s2
	return ""


func _resolve_local_steam_id64() -> int:
	if _api == null:
		return 0
	var v: Variant = null
	if _api.has_method("getSteamID"):
		v = _api.call("getSteamID")
	elif _api.has_method("get_steam_id"):
		v = _api.call("get_steam_id")
	if v is int:
		return v
	if v is float:
		return int(v)
	var as_text: String = str(v).strip_edges()
	if as_text.is_valid_int():
		return int(as_text)
	return 0


## Stable string id for online features (arena leaderboard row key, etc.). Empty if Steam is not ready.
func get_local_steam_id_string() -> String:
	var id64: int = _resolve_local_steam_id64()
	if id64 > 0:
		return str(id64)
	return ""


func _ensure_avatar_loaded_signal() -> void:
	if _api == null or _avatar_signal_connected:
		return
	for sig_name in ["avatar_loaded", "avatarLoaded"]:
		if _api.has_signal(sig_name):
			var cb := Callable(self, "_on_steam_singleton_avatar_loaded")
			if not _api.is_connected(sig_name, cb):
				_api.connect(sig_name, cb)
			_avatar_signal_connected = true
			return


func _on_steam_singleton_avatar_loaded(user_id: Variant, avatar_size: Variant, avatar_buffer: Variant) -> void:
	if not _awaiting_local_avatar:
		return
	var uid: int = int(user_id)
	var my_id: int = _resolve_local_steam_id64()
	if my_id != 0 and uid != my_id:
		return
	_awaiting_local_avatar = false
	var asize: int = int(avatar_size)
	if not avatar_buffer is PackedByteArray:
		player_avatar_loaded.emit(null)
		return
	var buf: PackedByteArray = avatar_buffer
	if buf.is_empty() or asize <= 0:
		player_avatar_loaded.emit(null)
		return
	var img: Image = Image.create_from_data(asize, asize, false, Image.FORMAT_RGBA8, buf)
	player_avatar_loaded.emit(ImageTexture.create_from_image(img))


## Requests the local user's avatar; result arrives on `player_avatar_loaded` (may be the same frame or later after callbacks).
func request_local_player_avatar(use_large: bool = false) -> void:
	if not steam_initialized or _api == null:
		player_avatar_loaded.emit(null)
		return
	_ensure_avatar_loaded_signal()
	if not _avatar_signal_connected:
		player_avatar_loaded.emit(null)
		return
	_awaiting_local_avatar = true
	# GodotSteam: 1 = small, 2 = medium (64), 3 = large (128+)
	var size_arg: int = 3 if use_large else 2
	if _api.has_method("getPlayerAvatar"):
		_api.call("getPlayerAvatar", size_arg)
	elif _api.has_method("get_player_avatar"):
		_api.call("get_player_avatar", size_arg)
	else:
		_awaiting_local_avatar = false
		player_avatar_loaded.emit(null)


## Opens the local user's Steam community profile (Steam overlay when available, otherwise default browser).
func open_local_player_steam_profile() -> void:
	var sid: int = _resolve_local_steam_id64()
	if sid == 0:
		return
	if steam_initialized and _api != null:
		if _api.has_method("activateGameOverlayToUser"):
			_api.call("activateGameOverlayToUser", "steamid", sid)
			return
		if _api.has_method("activate_game_overlay_to_user"):
			_api.call("activate_game_overlay_to_user", "steamid", sid)
			return
	OS.shell_open("https://steamcommunity.com/profiles/%d" % sid)

