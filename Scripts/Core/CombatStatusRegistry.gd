extends RefCounted
class_name CombatStatusRegistry

static var _by_id: Dictionary = {}
static var _loaded: bool = false

## Explicit registrations so statuses resolve even if folder scanning fails.
const _BUILTIN: Array[String] = [
	"res://Resources/CombatStatuses/Status_Burning.tres",
	"res://Resources/CombatStatuses/Status_Map01_Scorched.tres",
	"res://Resources/CombatStatuses/Status_BoneToxin.tres",
	"res://Resources/CombatStatuses/Status_Resolve.tres",
]


static func reload() -> void:
	_loaded = false
	_by_id.clear()
	ensure_loaded()


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for p: String in _BUILTIN:
		_try_register_path(p)
	var dir := DirAccess.open("res://Resources/CombatStatuses/")
	if dir == null:
		return
	dir.list_dir_begin()
	var fn: String = dir.get_next()
	while fn != "":
		if not dir.current_is_dir() and fn.ends_with(".tres"):
			_try_register_path("res://Resources/CombatStatuses/" + fn)
		fn = dir.get_next()
	dir.list_dir_end()


static func _try_register_path(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var res: Resource = load(path) as Resource
	if res == null:
		return
	if not (res is CombatStatusData):
		return
	var d: CombatStatusData = res as CombatStatusData
	if d.status_id.strip_edges() == "":
		return
	_by_id[d.status_id] = d


static func get_optional(status_id: String) -> CombatStatusData:
	ensure_loaded()
	var key: String = status_id.strip_edges()
	if key == "":
		return null
	return _by_id.get(key) as CombatStatusData


static func get_display_name(status_id: String) -> String:
	var d: CombatStatusData = get_optional(status_id)
	if d != null and d.display_name.strip_edges() != "":
		return d.display_name.strip_edges()
	return _fallback_label(status_id)


static func _fallback_label(status_id: String) -> String:
	var clean_id: String = status_id.strip_edges()
	if clean_id == "":
		return ""
	var raw_words: PackedStringArray = clean_id.replace("_", " ").replace("-", " ").split(" ", false)
	var out_words: Array[String] = []
	for w in raw_words:
		var ws: String = str(w).strip_edges()
		if ws == "":
			continue
		out_words.append(ws.capitalize())
	if out_words.is_empty():
		return clean_id
	return " ".join(out_words)
