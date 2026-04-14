extends RefCounted
class_name BeastiaryMapIndex

## Builds [code]UnitData .tres path → map display names[/code] by scanning [code]res://Scenes/Levels/*.tscn[/code].
## Picks up [code]data = ExtResource[/code] (hand-placed [Unit] nodes), [code]unit_data[/code] / [code]enemy_data[/code] / spawner fields, and [code]override_unit_data[/code] arrays.
## Map labels use [code]Level N[/code] plus [member BattleField.level_display_name] when set on the battlefield root (e.g. [code]Level 1 — Prologue: The Razed Village[/code]).

static var _unit_path_to_maps: Dictionary = {} # String -> Array[String]
static var _built: bool = false


static func maps_for_unit_data_path(unit_data_path: String) -> PackedStringArray:
	_ensure_built()
	var k: String = _norm_path(unit_data_path)
	var arr: Variant = _maps_array_for_key(k)
	if arr == null and ResourceLoader.exists(k):
		var r: Resource = load(k) as Resource
		if r != null:
			var rp: String = _norm_path(str(r.resource_path))
			if not rp.is_empty() and rp != k:
				arr = _maps_array_for_key(rp)
	if arr == null:
		return PackedStringArray()
	var out := PackedStringArray()
	for s in (arr as Array):
		out.append(str(s))
	return out


static func _maps_array_for_key(k: String) -> Variant:
	if k.is_empty() or not _unit_path_to_maps.has(k):
		return null
	return _unit_path_to_maps[k]


static func _norm_path(p: String) -> String:
	return str(p).strip_edges().replace("\\", "/")


static func _ensure_built() -> void:
	if _built:
		return
	_built = true
	_unit_path_to_maps.clear()
	_scan_directory("res://Scenes/Levels")


static func _scan_directory(dir_path: String) -> void:
	var base: String = dir_path.rstrip("/")
	var d: DirAccess = DirAccess.open(base)
	if d == null:
		return
	d.list_dir_begin()
	var entry: String = d.get_next()
	while entry != "":
		if not d.current_is_dir() and entry.ends_with(".tscn"):
			_process_level_scene_file(base.path_join(entry))
		entry = d.get_next()
	d.list_dir_end()


static func _parse_level_display_name_from_scene_text(text: String) -> String:
	## Serialized on the battlefield root from [member BattleField.level_display_name].
	var rx := RegEx.new()
	if rx.compile("(?m)^level_display_name\\s*=\\s*\"([^\"]*)\"") != OK:
		return ""
	var m: RegExMatch = rx.search(text)
	if m == null:
		return ""
	return m.get_string(1).strip_edges()


static func _display_name_for_level_file(file_path: String, level_subtitle: String = "") -> String:
	var stem: String = file_path.get_file().get_basename()
	var sub: String = level_subtitle.strip_edges()
	var rx := RegEx.new()
	if rx.compile("^Level(\\d+)$") == OK:
		var m: RegExMatch = rx.search(stem)
		if m != null:
			var num_lbl: String = "Level %s" % m.get_string(1)
			if sub != "":
				return "%s — %s" % [num_lbl, sub]
			return num_lbl
	if stem == "ArenaLevel":
		if sub != "":
			return "Arena — %s" % sub
		return "Arena"
	if sub != "":
		return "%s — %s" % [stem.replace("_", " "), sub]
	return stem.replace("_", " ")


static func _parse_ext_resource_tres_paths(text: String) -> Dictionary:
	## Godot 4+ lines look like: [ext_resource type="…" uid="uid://…" path="…" id="6_e1ibw"].
	## A naive [code]find("id=")[/code] matches inside [code]uid="uid://…"[/code] (the [code]id=[/code] in [code]uid[/code]).
	var id_to_path: Dictionary = {}
	var rx_id := RegEx.new()
	if rx_id.compile("\\bid=\"([^\"]+)\"") != OK:
		return id_to_path
	for line in text.split("\n"):
		var t: String = line.strip_edges()
		if not t.begins_with("[ext_resource"):
			continue
		var path := ""
		var p0: int = t.find("path=\"")
		if p0 >= 0:
			var p1: int = t.find("\"", p0 + 6)
			if p1 > p0:
				path = t.substr(p0 + 6, p1 - p0 - 6)
		var res_id := ""
		for m in rx_id.search_all(t):
			res_id = m.get_string(1)
		if res_id != "" and path.begins_with("res://") and path.ends_with(".tres"):
			id_to_path[res_id] = path
	return id_to_path


static func _looks_like_unit_data_resource_path(path: String) -> bool:
	var n: String = _norm_path(path)
	return n.contains("Resources/Units/") or n.contains("Resources/EnemyUnitData/")


static func _gather_ext_resource_ids_for_unit_slots(text: String) -> Array[String]:
	var out: Array[String] = []
	var rx := RegEx.new()
	if rx.compile("(unit_data|enemy_data|default_enemy_data)\\s*=\\s*ExtResource\\(\"([^\"]+)\"\\)") == OK:
		for m in rx.search_all(text):
			out.append(m.get_string(2))
	var rx_ov := RegEx.new()
	if rx_ov.compile("override_unit_data\\s*=\\s*Array\\[Resource\\]\\(\\[([\\s\\S]*?)\\]\\)") == OK:
		for mm in rx_ov.search_all(text):
			var inner: String = mm.get_string(1)
			var rx2 := RegEx.new()
			if rx2.compile("ExtResource\\(\"([^\"]+)\"\\)") == OK:
				for m2 in rx2.search_all(inner):
					out.append(m2.get_string(1))
	# Hand-placed Unit nodes in the editor use exported [member Unit.data].
	var rx_data := RegEx.new()
	if rx_data.compile("\\bdata\\s*=\\s*ExtResource\\(\"([^\"]+)\"\\)") == OK:
		for m3 in rx_data.search_all(text):
			out.append(m3.get_string(1))
	return out


static func _add_map_for_unit_path(unit_path: String, map_label: String) -> void:
	var k: String = _norm_path(unit_path)
	if k.is_empty() or map_label.is_empty():
		return
	if not _unit_path_to_maps.has(k):
		_unit_path_to_maps[k] = []
	var arr: Array = _unit_path_to_maps[k] as Array
	if not arr.has(map_label):
		arr.append(map_label)
		arr.sort()


static func _process_level_scene_file(scene_path: String) -> void:
	var f: FileAccess = FileAccess.open(scene_path, FileAccess.READ)
	if f == null:
		return
	var text: String = f.get_as_text()
	f.close()
	var id_to_path: Dictionary = _parse_ext_resource_tres_paths(text)
	var slot_ids: Array[String] = _gather_ext_resource_ids_for_unit_slots(text)
	var map_label: String = _display_name_for_level_file(scene_path, _parse_level_display_name_from_scene_text(text))
	for sid in slot_ids:
		var p: String = str(id_to_path.get(sid, ""))
		if p.is_empty() or not _looks_like_unit_data_resource_path(p):
			continue
		if not ResourceLoader.exists(p):
			continue
		var loaded: Resource = load(p) as Resource
		if loaded == null or not (loaded is UnitData):
			continue
		var raw_key: String = _norm_path(p)
		_add_map_for_unit_path(raw_key, map_label)
		# Alias canonical resource_path so we match [member Resource.resource_path] from live units / saves.
		var rp: String = _norm_path(str(loaded.resource_path))
		if not rp.is_empty() and rp != raw_key:
			_add_map_for_unit_path(rp, map_label)
