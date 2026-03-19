@tool
extends EditorScript

const WEAPON_DATA_SCRIPT = preload("res://Resources/WeaponData.gd")

const SEARCH_DIRS: Array[String] = [
	"res://Resources/GeneratedItems/",
	"res://Resources/Weapons/"
]

const REPORT_PATH: String = "res://weapon_audit_report.txt"

func _run() -> void:
	var all_weapon_files: Array[String] = []
	for dir_path in SEARCH_DIRS:
		_collect_tres_files(dir_path, all_weapon_files)

	var weapon_entries: Array[Dictionary] = []
	for file_path in all_weapon_files:
		var res = load(file_path)
		if res == null:
			continue
		if not (res is WeaponData):
			continue

		var weapon_name: String = ""
		if res.get("weapon_name") != null:
			weapon_name = String(res.weapon_name).strip_edges()

		var file_name: String = file_path.get_file().get_basename()
		var normalized_name: String = _normalize_name(weapon_name if weapon_name != "" else file_name)
		var normalized_file: String = _normalize_name(file_name)

		weapon_entries.append({
			"path": file_path,
			"weapon_name": weapon_name,
			"file_name": file_name,
			"normalized_name": normalized_name,
			"normalized_file": normalized_file,
			"is_generated": file_path.contains("Resources/GeneratedItems/"),
			"is_legacy": file_path.contains("Resources/Weapons/"),
			"is_testy": file_name.to_lower().contains("test")
		})

	var by_display_name: Dictionary = {}
	var by_normalized_name: Dictionary = {}

	for entry in weapon_entries:
		var display_key: String = String(entry["weapon_name"]).strip_edges()
		if display_key == "":
			display_key = "[EMPTY_WEAPON_NAME]"

		if not by_display_name.has(display_key):
			by_display_name[display_key] = []
		by_display_name[display_key].append(entry)

		var normalized_key: String = String(entry["normalized_name"])
		if not by_normalized_name.has(normalized_key):
			by_normalized_name[normalized_key] = []
		by_normalized_name[normalized_key].append(entry)

	var lines: Array[String] = []
	lines.append("WEAPON AUDIT REPORT")
	lines.append("==================================================")
	lines.append("")
	lines.append("Total WeaponData resources found: %d" % weapon_entries.size())
	lines.append("")

	lines.append("EXACT DUPLICATES BY weapon_name")
	lines.append("--------------------------------------------------")
	var exact_found := false
	for key in by_display_name.keys():
		var group: Array = by_display_name[key]
		if group.size() > 1:
			exact_found = true
			lines.append("")
			lines.append("Name: %s" % key)
			for raw_entry in group:
				var entry: Dictionary = raw_entry
				lines.append("  - %s" % String(entry["path"]))
			var preferred_path: String = _pick_preferred(group)
			lines.append("  -> Preferred keep: %s" % preferred_path)
	if not exact_found:
		lines.append("None")
	lines.append("")

	lines.append("SUSPICIOUS / NEAR DUPLICATES BY NORMALIZED NAME")
	lines.append("--------------------------------------------------")
	var near_found := false
	for key in by_normalized_name.keys():
		var group: Array = by_normalized_name[key]
		if group.size() > 1:
			near_found = true
			lines.append("")
			lines.append("Normalized key: %s" % key)
			for raw_entry in group:
				var entry: Dictionary = raw_entry
				lines.append("  - %s | weapon_name='%s'" % [String(entry["path"]), String(entry["weapon_name"])])
			var preferred_path: String = _pick_preferred(group)
			lines.append("  -> Preferred keep: %s" % preferred_path)
	if not near_found:
		lines.append("None")
	lines.append("")

	lines.append("SUSPICIOUS FILES")
	lines.append("--------------------------------------------------")
	var suspicious_found := false
	for raw_entry in weapon_entries:
		var entry: Dictionary = raw_entry
		var weapon_name: String = String(entry["weapon_name"])
		var file_name: String = String(entry["file_name"])
		var path: String = String(entry["path"])

		if weapon_name == "":
			suspicious_found = true
			lines.append("Missing weapon_name: %s" % path)

		if bool(entry["is_testy"]):
			suspicious_found = true
			lines.append("Test-like file: %s" % path)

		if _normalize_name(weapon_name) != _normalize_name(file_name) and weapon_name != "":
			lines.append("Name/file mismatch: %s | weapon_name='%s'" % [path, weapon_name])

	if not suspicious_found:
		lines.append("None")
	lines.append("")

	lines.append("RECOMMENDED CLEANUP RULES")
	lines.append("--------------------------------------------------")
	lines.append("1. Prefer GeneratedItems versions over legacy Weapons versions when both represent the same weapon.")
	lines.append("2. Keep files whose weapon_name is filled in and matches the intended design.")
	lines.append("3. Review test assets manually before deletion.")
	lines.append("4. Never delete until references are checked in units, shops, loot tables, and enemy loadouts.")
	lines.append("")

	var report_text: String = "\n".join(lines)
	print(report_text)

	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(report_text)
		file.close()
		print("")
		print("✅ Saved report to: " + REPORT_PATH)
	else:
		push_error("Failed to write report to: " + REPORT_PATH)


func _collect_tres_files(dir_path: String, out_files: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("Could not open directory: " + dir_path)
		return

	dir.list_dir_begin()
	var name: String = dir.get_next()

	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue

		var full_path: String = dir_path.path_join(name)

		if dir.current_is_dir():
			_collect_tres_files(full_path, out_files)
		elif name.ends_with(".tres"):
			out_files.append(full_path)

		name = dir.get_next()

	dir.list_dir_end()


func _normalize_name(raw: String) -> String:
	var s: String = raw.to_lower().strip_edges()
	s = s.replace("weapon_", "")
	s = s.replace("item_", "")
	s = s.replace("_", "")
	s = s.replace("-", "")
	s = s.replace(" ", "")
	s = s.replace("'", "")
	s = s.replace(".", "")
	return s


func _pick_preferred(group: Array) -> String:
	var best_score: int = -999999
	var best_path: String = ""

	for raw_entry in group:
		var entry: Dictionary = raw_entry
		var score: int = 0

		if bool(entry["is_generated"]):
			score += 20
		if bool(entry["is_legacy"]):
			score -= 5
		if String(entry["weapon_name"]).strip_edges() != "":
			score += 10
		if not bool(entry["is_testy"]):
			score += 5
		if String(entry["file_name"]).begins_with("Weapon_"):
			score += 3

		if score > best_score:
			best_score = score
			best_path = String(entry["path"])

	return best_path
