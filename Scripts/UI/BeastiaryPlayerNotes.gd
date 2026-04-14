extends Node

## Player-written Field Notes per enemy [UnitData] resource path. Stored under [code]user://[/code] so it persists across new campaigns on this device.

const SAVE_PATH: String = "user://beastiary_player_notes.json"
const MAX_NOTE_CHARS: int = 8000

var _notes_by_path: Dictionary = {}


func _ready() -> void:
	_load_from_disk()


func _load_from_disk() -> void:
	_notes_by_path.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var txt: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		for k in (parsed as Dictionary):
			var key: String = str(k).strip_edges()
			if key == "":
				continue
			_notes_by_path[key] = str((parsed as Dictionary)[k])


func save_to_disk() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("BeastiaryPlayerNotes: could not write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(_notes_by_path, "\t"))
	f.close()


func get_note(unit_data_path: String) -> String:
	var k: String = unit_data_path.strip_edges()
	if k == "":
		return ""
	return str(_notes_by_path.get(k, ""))


func set_note(unit_data_path: String, note_text: String) -> void:
	var k: String = unit_data_path.strip_edges()
	if k == "":
		return
	var t: String = note_text
	if t.length() > MAX_NOTE_CHARS:
		t = t.substr(0, MAX_NOTE_CHARS)
	var trimmed: String = t.strip_edges()
	if trimmed.is_empty():
		if _notes_by_path.has(k):
			_notes_by_path.erase(k)
			save_to_disk()
		return
	_notes_by_path[k] = t
	save_to_disk()
