@tool
extends EditorScript

const GENERATED_DIR: String = "res://Resources/GeneratedItems/"
const LEGACY_DIR: String = "res://Resources/Weapons/"
const DEPRECATED_DIR: String = "res://Resources/Weapons/_Deprecated/"
const REPORT_PATH: String = "res://weapon_cleanup_report.txt"

# Safety first:
# - true  = only print / write report
# - false = actually move files
const DRY_RUN: bool = true

const SUSPICIOUS_LEGACY_FILES: Array[String] = [
	"res://Resources/Weapons/Crude Bow.tres",
	"res://Resources/Weapons/Legendary TEST Sword.tres",
	"res://Resources/Weapons/SteelAxe.tres",
	"res://Resources/Weapons/TomeOfFireBeam.tres"
]

func _run() -> void:
	_ensure_dir(DEPRECATED_DIR)

	var generated_entries: Array[Dictionary] = _load_weapon_entries_from_dir(GENERATED_DIR)
	var legacy_entries: Array[Dictionary] = _load_weapon_entries_from_dir(LEGACY_DIR)

	var generated_by_name: Dictionary = {}
	for raw_entry in generated_entries:
		var entry: Dictionary = raw_entry
		var weapon_name: String = String(entry["weapon_name"]).strip_edges()
		if weapon_name == "":
			continue
		if not generated_by_name.has(weapon_name):
			generated_by_name[weapon_name] = []
		generated_by_name[weapon_name].append(entry)

	var actions: Array[Dictionary] = []
	var seen_paths: Dictionary = {}

	# -------------------------------------------------------------------------
	# 1. Move exact legacy duplicates if a GeneratedItems version exists
	# -------------------------------------------------------------------------
	for raw_entry in legacy_entries:
		var entry: Dictionary = raw_entry
		var weapon_name: String = String(entry["weapon_name"]).strip_edges()
		if weapon_name == "":
			continue

		if generated_by_name.has(weapon_name):
			var src_path: String = String(entry["path"])
			if not seen_paths.has(src_path):
				actions.append({
					"src": src_path,
					"dst": _build_backup_path(src_path),
					"reason": "Legacy duplicate of generated weapon_name: " + weapon_name
				})
				seen_paths[src_path] = true

	# -------------------------------------------------------------------------
	# 2. Move explicit suspicious legacy files
	# -------------------------------------------------------------------------
	for suspicious_path in SUSPICIOUS_LEGACY_FILES:
		if ResourceLoader.exists(suspicious_path):
			if not seen_paths.has(suspicious_path):
				actions.append({
					"src": suspicious_path,
					"dst": _build_backup_path(suspicious_path),
					"reason": "Suspicious legacy file flagged by audit"
				})
				seen_paths[suspicious_path] = true

	# -------------------------------------------------------------------------
	# 3. Execute or preview
	# -------------------------------------------------------------------------
	var lines: Array[String] = []
	lines.append("WEAPON SOFT CLEANUP REPORT")
	lines.append("==================================================")
	lines.append("Mode: " + ("DRY RUN" if DRY_RUN else "LIVE MOVE"))
	lines.append("Generated weapons scanned: %d" % generated_entries.size())
	lines.append("Legacy weapons scanned: %d" % legacy_entries.size())
	lines.append("Planned actions: %d" % actions.size())
	lines.append("")

	if actions.is_empty():
		lines.append("No actions to perform.")
	else:
		for raw_action in actions:
			var action: Dictionary = raw_action
			var src: String = String(action["src"])
			var dst: String = String(action["dst"])
			var reason: String = String(action["reason"])

			lines.append("MOVE")
			lines.append("  FROM: " + src)
			lines.append("  TO:   " + dst)
			lines.append("  WHY:  " + reason)
			lines.append("")

			if not DRY_RUN:
				var ok: bool = _move_file(src, dst)
				if not ok:
					lines.append("  !! FAILED TO MOVE: " + src)
					lines.append("")

	var report_text: String = "\n".join(lines)
	print(report_text)

	var report_file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(report_text)
		report_file.close()
		print("✅ Saved cleanup report to: " + REPORT_PATH)
	else:
		push_error("Failed to write cleanup report: " + REPORT_PATH)

	if DRY_RUN:
		print("🛡 Dry run complete. Set DRY_RUN to false to actually move files.")
	else:
		print("🎉 Soft cleanup complete.")


func _load_weapon_entries_from_dir(dir_path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var files: Array[String] = []
	_collect_tres_files(dir_path, files)

	for file_path in files:
		var res = load(file_path)
		if res == null:
			continue

		var has_weapon_name := false
		for prop in res.get_property_list():
			if String(prop.name) == "weapon_name":
				has_weapon_name = true
				break

		if not has_weapon_name:
			continue

		var weapon_name: String = ""
		if res.get("weapon_name") != null:
			weapon_name = String(res.weapon_name).strip_edges()

		out.append({
			"path": file_path,
			"weapon_name": weapon_name,
			"file_name": file_path.get_file()
		})

	return out


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


func _build_backup_path(src_path: String) -> String:
	var file_name: String = src_path.get_file()
	var target: String = DEPRECATED_DIR + file_name

	if not ResourceLoader.exists(target):
		return target

	var base_name: String = file_name.get_basename()
	var ext: String = file_name.get_extension()
	var counter: int = 1

	while true:
		var candidate: String = DEPRECATED_DIR + base_name + "_old_" + str(counter) + "." + ext
		if not ResourceLoader.exists(candidate):
			return candidate
		counter += 1

	return target


func _move_file(src_res_path: String, dst_res_path: String) -> bool:
	var src_abs: String = ProjectSettings.globalize_path(src_res_path)
	var dst_abs: String = ProjectSettings.globalize_path(dst_res_path)

	var dst_parent_abs: String = dst_abs.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dst_parent_abs)

	var err: int = DirAccess.rename_absolute(src_abs, dst_abs)
	if err != OK:
		push_error("Failed to move file from %s to %s" % [src_res_path, dst_res_path])
		return false

	return true


func _ensure_dir(res_dir: String) -> void:
	var abs_dir: String = ProjectSettings.globalize_path(res_dir.trim_suffix("/"))
	DirAccess.make_dir_recursive_absolute(abs_dir)
