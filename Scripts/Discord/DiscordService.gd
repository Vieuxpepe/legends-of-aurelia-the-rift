extends Node
## Autoload: Discord Rich Presence bridge with graceful fallback.
## - Reads project settings under [discord]/presence/*
## - Tries common Discord backend singleton names from GDExtension plugins
## - Updates presence from active scene + battle phase context
## - Never hard-crashes if Discord backend is missing/unavailable

const GAME_DISPLAY_NAME: String = "Legends of Aurelia : The Rift"
const DISCORD_GDEXTENSION_PATH: String = "res://addons/discord-game-sdk-godot/libdgs.gdextension"
const DISCORDSDK_WRAPPER_SCRIPT_PATH: String = "res://addons/discord-game-sdk-godot/discordsdk.gd"
const DISCORD_ACTIVITY_DATA_SCRIPT_PATH: String = "res://addons/discord-game-sdk-godot/data/DiscordActivityData.gd"
const BACKEND_SINGLETON_CANDIDATES: Array = [
	"DiscordSDK",
	"DiscordRPC",
	"Discord",
	"DiscordGameSDK",
	"discord_rpc",
]
const PRESENCE_UPDATE_INTERVAL_FALLBACK: float = 1.0
const MODE_NONE: int = 0
const MODE_DISCORDSDK_WRAPPER: int = 1
const MODE_GENERIC_BACKEND: int = 2

var _backend: Object = null
var _backend_singleton_name: String = ""
var _ready_for_presence: bool = false
var _client_id: int = 0
var _integration_mode: int = MODE_NONE
var _discordsdk = null
var _discord_activity_data_script: Script = null

var _large_image_key: String = "loa_logo"
var _large_image_text: String = GAME_DISPLAY_NAME
var _small_image_key_default: String = ""
var _small_image_text_default: String = ""
var _update_interval_sec: float = PRESENCE_UPDATE_INTERVAL_FALLBACK

var _presence_tick_accum: float = 0.0
var _last_presence_signature: String = ""
var _manual_presence_active: bool = false
var _manual_presence_payload: Dictionary = {}


func _ready() -> void:
	# Runtime-only safeguard: never initialize Discord presence while editing the project.
	if Engine.is_editor_hint():
		return
	_load_presence_settings()
	if _client_id <= 0:
		push_warning(
			"DiscordService: disabled (discord/presence/client_id is 0). Set your Discord App ID in project.godot."
		)
		return
	if _try_setup_discordsdk_wrapper():
		_ready_for_presence = true
		print("DiscordService: initialized via DiscordSDK wrapper (client_id=%d)." % _client_id)
		_update_presence_from_context(true)
		return
	if not _resolve_backend_singleton():
		push_warning(
			"DiscordService: no Discord backend singleton found. Install a Discord Godot plugin and expose one of: %s"
			% [", ".join(PackedStringArray(BACKEND_SINGLETON_CANDIDATES))]
		)
		return

	_ready_for_presence = _try_initialize_backend()
	if not _ready_for_presence:
		push_warning("DiscordService: backend '%s' failed to initialize." % _backend_singleton_name)
		return
	_integration_mode = MODE_GENERIC_BACKEND
	print("DiscordService: initialized via backend '%s' (client_id=%d)." % [_backend_singleton_name, _client_id])

	_update_presence_from_context(true)


func _process(delta: float) -> void:
	if not _ready_for_presence:
		return
	if _integration_mode == MODE_DISCORDSDK_WRAPPER:
		_discordsdk_tick()
	else:
		_run_backend_callbacks()
	_presence_tick_accum += delta
	if _presence_tick_accum < _update_interval_sec:
		return
	_presence_tick_accum = 0.0
	_update_presence_from_context(false)


func _exit_tree() -> void:
	if not _ready_for_presence:
		return
	if _integration_mode == MODE_DISCORDSDK_WRAPPER:
		if _discordsdk != null and _discordsdk.Core != null:
			_discordsdk.Core.destroy()
		return
	_safe_backend_call_any(PackedStringArray(["shutdown", "stop", "dispose", "close"]), [])


## Optional override for scripted moments/cinematics. Call clear_manual_presence() to return to scene-driven presence.
func set_manual_presence(details: String, state: String = "", small_key: String = "", small_text: String = "") -> void:
	_manual_presence_active = true
	_manual_presence_payload = {
		"details": details.strip_edges(),
		"state": state.strip_edges(),
		"small_image_key": small_key.strip_edges(),
		"small_image_text": small_text.strip_edges(),
	}
	_update_presence_from_context(true)


func clear_manual_presence() -> void:
	_manual_presence_active = false
	_manual_presence_payload.clear()
	_update_presence_from_context(true)


func _load_presence_settings() -> void:
	_client_id = _setting_as_int("discord/presence/client_id", 0)
	_large_image_key = _setting_as_string("discord/presence/large_image_key", "loa_logo")
	_large_image_text = _setting_as_string("discord/presence/large_image_text", GAME_DISPLAY_NAME)
	_small_image_key_default = _setting_as_string("discord/presence/small_image_key_default", "")
	_small_image_text_default = _setting_as_string("discord/presence/small_image_text_default", "")
	_update_interval_sec = clampf(
		_setting_as_float("discord/presence/update_interval_sec", PRESENCE_UPDATE_INTERVAL_FALLBACK),
		0.5,
		5.0
	)


func _resolve_backend_singleton() -> bool:
	for singleton_name in BACKEND_SINGLETON_CANDIDATES:
		if not Engine.has_singleton(singleton_name):
			continue
		var singleton_obj: Object = Engine.get_singleton(singleton_name)
		if singleton_obj == null:
			continue
		_backend = singleton_obj
		_backend_singleton_name = singleton_name
		return true
	for singleton_name in BACKEND_SINGLETON_CANDIDATES:
		var root_path: String = "/root/%s" % singleton_name
		var node_backend: Node = get_node_or_null(root_path)
		if node_backend == null:
			continue
		_backend = node_backend
		_backend_singleton_name = singleton_name
		return true
	return false


func _try_setup_discordsdk_wrapper() -> bool:
	_try_load_discord_gdextension()
	if not ResourceLoader.exists(DISCORDSDK_WRAPPER_SCRIPT_PATH):
		return false
	if not ResourceLoader.exists(DISCORD_ACTIVITY_DATA_SCRIPT_PATH):
		return false
	_discordsdk = load(DISCORDSDK_WRAPPER_SCRIPT_PATH)
	if _discordsdk == null:
		return false
	var activity_script: Variant = load(DISCORD_ACTIVITY_DATA_SCRIPT_PATH)
	if activity_script == null or not (activity_script is Script):
		return false
	_discord_activity_data_script = activity_script as Script
	if _discordsdk.Core == null:
		return false
	var create_res: Variant = _discordsdk.Core.create(_client_id, _discordsdk.Core.CreateFlags.NoRequireDiscord)
	if _discordsdk.is_error(create_res):
		var result_text: String = str(create_res)
		if _discordsdk.has_method("result_str"):
			result_text = str(_discordsdk.result_str(create_res))
		push_warning("DiscordService: DiscordSDK wrapper init failed (%s)." % result_text)
		return false
	_connect_discordsdk_signals()
	_backend_singleton_name = "DiscordSDK wrapper"
	_integration_mode = MODE_DISCORDSDK_WRAPPER
	return true


func _try_load_discord_gdextension() -> void:
	if not ResourceLoader.exists(DISCORD_GDEXTENSION_PATH):
		return
	# Explicit runtime load so Discord presence can work without enabling the editor plugin.
	load(DISCORD_GDEXTENSION_PATH)


func _connect_discordsdk_signals() -> void:
	if _discordsdk == null:
		return
	if _discordsdk.Activity == null:
		return
	var activity_inst = _discordsdk.Activity.get_instance()
	if activity_inst == null:
		return
	var cb := Callable(self, "_on_discordsdk_update_activity_cb")
	if activity_inst.has_signal("update_activity_cb") and not activity_inst.is_connected("update_activity_cb", cb):
		activity_inst.connect("update_activity_cb", cb)


func _on_discordsdk_update_activity_cb(result: Variant) -> void:
	if _discordsdk == null:
		return
	if not _discordsdk.is_error(result):
		return
	var result_text: String = str(result)
	if _discordsdk.has_method("result_str"):
		result_text = str(_discordsdk.result_str(result))
	push_warning("DiscordService: update_activity failed (%s)." % result_text)


func _discordsdk_tick() -> void:
	if get_node_or_null("/root/Discord_tick") != null:
		return
	if _discordsdk == null or _discordsdk.Core == null:
		return
	var core_inst = _discordsdk.Core.get_instance()
	if core_inst != null and core_inst.has_method("tick"):
		core_inst.tick()


func _try_initialize_backend() -> bool:
	# Keep this permissive because wrappers expose different init APIs.
	var init_result: Variant = _safe_backend_call_any(
		PackedStringArray(["initialize", "init", "start", "create_core", "create"]),
		[_client_id]
	)
	if init_result == null:
		init_result = _safe_backend_call_any(PackedStringArray(["initialize", "init", "start"]), [])
	if _result_is_success(init_result):
		return true
	# Some wrappers require no explicit init and are ready as soon as singleton exists.
	return _backend_has_any(PackedStringArray([
		"setRichPresence",
		"set_presence",
		"setPresence",
		"set_details",
		"set_state",
	]))


func _run_backend_callbacks() -> void:
	_safe_backend_call_any(PackedStringArray(["run_callbacks", "runCallbacks", "callbacks", "poll"]), [])


func _update_presence_from_context(force: bool) -> void:
	var payload: Dictionary = _build_presence_payload()
	var signature: String = _presence_signature(payload)
	if not force and signature == _last_presence_signature:
		return
	_last_presence_signature = signature
	_apply_presence_payload(payload)


func _build_presence_payload() -> Dictionary:
	if _manual_presence_active:
		return {
			"details": str(_manual_presence_payload.get("details", "Playing")).strip_edges(),
			"state": str(_manual_presence_payload.get("state", "")).strip_edges(),
			"small_image_key": str(_manual_presence_payload.get("small_image_key", _small_image_key_default)).strip_edges(),
			"small_image_text": str(_manual_presence_payload.get("small_image_text", _small_image_text_default)).strip_edges(),
		}

	var tree: SceneTree = get_tree()
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return {"details": "Launching", "state": GAME_DISPLAY_NAME}

	var scene_path: String = str(scene.scene_file_path).to_lower()
	var scene_name: String = str(scene.name).to_lower()

	if _is_battle_scene(scene, scene_path, scene_name):
		return _build_battle_payload(scene)
	if scene_path.contains("camp_menu") or scene_path.contains("campexplore"):
		return {"details": "At Camp", "state": "Managing roster and upgrades", "small_image_key": "camp", "small_image_text": "Camp"}
	if scene_path.contains("worldmap"):
		return {"details": "World Map", "state": "Choosing the next route", "small_image_key": "map", "small_image_text": "World Map"}
	if scene_path.contains("main_menu"):
		return {"details": "Main Menu", "state": GAME_DISPLAY_NAME}
	if scene_path.contains("settings_menu"):
		return {"details": "Settings", "state": "Adjusting interface and controls"}
	if scene_path.contains("arena"):
		return {"details": "Arena", "state": "Testing team strength", "small_image_key": "arena", "small_image_text": "Arena"}

	var pretty_name: String = _scene_name_to_label(scene_path, scene_name)
	return {"details": "Playing", "state": pretty_name}


func _is_battle_scene(scene: Node, scene_path: String, scene_name: String) -> bool:
	if scene_path.contains("battle_field"):
		return true
	if scene_name == "battlefield":
		return true
	# Fallback: script class name check by method footprint.
	return scene.has_method("change_state") and scene.has_method("_on_start_battle_pressed") and scene.has_method("get_grid_pos")


func _build_battle_payload(scene: Node) -> Dictionary:
	var phase_label: String = _battle_phase_label(scene)
	var turn_label: String = ""
	var turn_variant: Variant = scene.get("current_turn")
	if turn_variant != null:
		var turn_num: int = int(turn_variant)
		if turn_num > 0:
			turn_label = "Turn %d" % turn_num
	var state_text: String = phase_label if turn_label == "" else ("%s - %s" % [turn_label, phase_label])
	var small_key: String = _battle_phase_icon_key(phase_label)
	return {
		"details": "In Battle",
		"state": state_text,
		"small_image_key": small_key,
		"small_image_text": phase_label,
	}


func _battle_phase_label(scene: Node) -> String:
	if not scene.has_method("get"):
		return "Battle"
	var cs: Variant = scene.get("current_state")
	if cs == null:
		return "Battle"
	if cs == scene.get("pre_battle_state"):
		return "Deployment"
	if cs == scene.get("player_state"):
		return "Player Phase"
	if cs == scene.get("ally_state"):
		return "Ally Phase"
	if cs == scene.get("enemy_state"):
		return "Enemy Phase"
	return "Battle"


func _battle_phase_icon_key(phase_label: String) -> String:
	match phase_label:
		"Deployment":
			return "deploy"
		"Player Phase":
			return "player_phase"
		"Ally Phase":
			return "ally_phase"
		"Enemy Phase":
			return "enemy_phase"
		_:
			return _small_image_key_default


func _scene_name_to_label(scene_path: String, scene_name: String) -> String:
	var src: String = scene_name
	if src.strip_edges() == "":
		src = scene_path.get_file().get_basename()
	src = src.replace("_", " ").strip_edges()
	if src == "":
		return GAME_DISPLAY_NAME
	var words: PackedStringArray = src.split(" ", false)
	for i in range(words.size()):
		var w: String = words[i]
		if w.length() <= 1:
			words[i] = w.to_upper()
		else:
			words[i] = w.substr(0, 1).to_upper() + w.substr(1)
	return "In %s" % " ".join(words)


func _presence_signature(payload: Dictionary) -> String:
	return "|".join([
		str(payload.get("details", "")),
		str(payload.get("state", "")),
		str(payload.get("small_image_key", "")),
		str(payload.get("small_image_text", "")),
	])


func _apply_presence_payload(payload: Dictionary) -> void:
	var details: String = str(payload.get("details", "Playing")).strip_edges()
	var state: String = str(payload.get("state", "")).strip_edges()
	var small_image_key: String = str(payload.get("small_image_key", _small_image_key_default)).strip_edges()
	var small_image_text: String = str(payload.get("small_image_text", _small_image_text_default)).strip_edges()
	var large_image_key: String = _large_image_key.strip_edges()
	var large_image_text: String = _large_image_text.strip_edges()

	if _integration_mode == MODE_DISCORDSDK_WRAPPER:
		if _discordsdk == null or _discord_activity_data_script == null:
			return
		var activity: Object = _discord_activity_data_script.new()
		activity.application_id = _client_id
		activity.type = _discordsdk.Activity.ActivityType.Playing
		activity.details = details
		activity.state = state
		activity.asset_large_image = large_image_key
		activity.asset_large_text = large_image_text
		activity.asset_small_image = small_image_key
		activity.asset_small_text = small_image_text
		_discordsdk.Activity.update_activity(activity)
		return

	# Wrapper style A: Steam-like key/value API.
	if _backend_has("setRichPresence"):
		_safe_backend_call("setRichPresence", ["details", details])
		_safe_backend_call("setRichPresence", ["state", state])
		_safe_backend_call("setRichPresence", ["large_image", large_image_key])
		_safe_backend_call("setRichPresence", ["large_text", large_image_text])
		_safe_backend_call("setRichPresence", ["small_image", small_image_key])
		_safe_backend_call("setRichPresence", ["small_text", small_image_text])
		_safe_backend_call_any(PackedStringArray(["refresh", "update", "commit_activity"]), [])
		return

	# Wrapper style B: field mutators.
	if _backend_has("set_details") or _backend_has("set_state"):
		_safe_backend_call("set_details", [details])
		_safe_backend_call("set_state", [state])
		_safe_backend_call("set_large_image", [large_image_key])
		_safe_backend_call("set_large_image_text", [large_image_text])
		_safe_backend_call("set_small_image", [small_image_key])
		_safe_backend_call("set_small_image_text", [small_image_text])
		_safe_backend_call_any(PackedStringArray(["refresh", "update", "run_callbacks"]), [])
		return

	# Wrapper style C: one-shot presence call.
	if _backend_has_any(PackedStringArray(["set_presence", "setPresence", "update_presence"])):
		_safe_backend_call_any(
			PackedStringArray(["set_presence", "setPresence", "update_presence"]),
			[details, state, large_image_key, large_image_text, small_image_key, small_image_text]
		)
		_safe_backend_call_any(PackedStringArray(["refresh", "update"]), [])
		return

	# Wrapper style D: activity dictionary call.
	if _backend_has_any(PackedStringArray(["update_activity", "set_activity"])):
		var activity: Dictionary = {
			"details": details,
			"state": state,
			"large_image": large_image_key,
			"large_text": large_image_text,
			"small_image": small_image_key,
			"small_text": small_image_text,
		}
		_safe_backend_call_any(PackedStringArray(["update_activity", "set_activity"]), [activity])


func _setting_as_string(path: String, fallback: String) -> String:
	if not ProjectSettings.has_setting(path):
		return fallback
	return str(ProjectSettings.get_setting(path, fallback))


func _setting_as_int(path: String, fallback: int) -> int:
	if not ProjectSettings.has_setting(path):
		return fallback
	var v: Variant = ProjectSettings.get_setting(path, fallback)
	if v is int:
		return int(v)
	if v is float:
		return int(v)
	var as_text: String = str(v).strip_edges()
	return int(as_text) if as_text.is_valid_int() else fallback


func _setting_as_float(path: String, fallback: float) -> float:
	if not ProjectSettings.has_setting(path):
		return fallback
	var v: Variant = ProjectSettings.get_setting(path, fallback)
	if v is float:
		return float(v)
	if v is int:
		return float(v)
	var as_text: String = str(v).strip_edges()
	return as_text.to_float() if as_text.is_valid_float() else fallback


func _backend_has(method_name: String) -> bool:
	return _backend != null and _backend.has_method(method_name)


func _backend_has_any(method_names: PackedStringArray) -> bool:
	for method_name in method_names:
		if _backend_has(method_name):
			return true
	return false


func _safe_backend_call(method_name: String, args: Array) -> Variant:
	if not _backend_has(method_name):
		return null
	var argc: int = _backend_method_arg_count(method_name)
	if argc >= 0 and args.size() != argc:
		if args.size() < argc:
			return null
		return _backend.callv(method_name, args.slice(0, argc))
	return _backend.callv(method_name, args)


func _safe_backend_call_any(method_names: PackedStringArray, args: Array) -> Variant:
	for method_name in method_names:
		if not _backend_has(method_name):
			continue
		var out: Variant = _safe_backend_call(method_name, args)
		return out
	return null


func _backend_method_arg_count(method_name: String) -> int:
	if _backend == null:
		return -1
	var methods: Array = _backend.get_method_list()
	for method_info in methods:
		if str(method_info.get("name", "")) != method_name:
			continue
		var args: Variant = method_info.get("args", [])
		return (args as Array).size() if args is Array else -1
	return -1


func _result_is_success(result: Variant) -> bool:
	if result == null:
		return false
	if result is bool:
		return bool(result)
	if result is int:
		return int(result) == 0
	if result is float:
		return int(result) == 0
	if result is Dictionary:
		var dict: Dictionary = result
		if dict.has("status"):
			return int(dict.get("status", 1)) == 0
		if dict.has("ok"):
			return bool(dict.get("ok", false))
		return not dict.is_empty()
	if result is String:
		var s: String = str(result).strip_edges().to_lower()
		return s == "ok" or s == "success" or s == "ready"
	return true
