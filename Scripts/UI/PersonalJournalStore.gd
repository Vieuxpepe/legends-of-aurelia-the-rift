extends Node

## Multi-page personal journal under [code]user://[/code]. Legacy [code]personal_journal.txt[/code] migrates once to JSON.

const DetailedUnitInfoHelpers = preload("res://Scripts/Core/BattleField/BattleFieldDetailedUnitInfoHelpers.gd")

const SAVE_JSON: String = "user://personal_journal.json"
const LEGACY_TXT: String = "user://personal_journal.txt"
const FORMAT_VERSION: int = 4
const MAX_PAGES: int = 10
const MAX_BODY_PER_PAGE: int = 50000
const MAX_TITLE_LEN: int = 64
const JOURNAL_IMAGES_ROOT: String = "user://journal_images"
const MAX_ATTACHMENTS_PER_PAGE: int = 8
## Longest edge in pixels (images are scaled down before save).
const MAX_ATTACHMENT_EDGE: int = 4096
const JOURNAL_FONT_SIZE_MIN: int = 12
const JOURNAL_FONT_SIZE_MAX: int = 28
const JOURNAL_FONT_SIZE_DEFAULT: int = 17

## Runtime only: last tactical inspect name (see [method note_inspected_unit_for_journal]). Not saved.
var last_inspected_unit_display_name: String = ""


func _random_page_id() -> String:
	return "p_%d_%d" % [Time.get_ticks_usec(), randi() % 1_000_000]


func _random_attachment_id() -> String:
	return "a_%d_%d" % [Time.get_ticks_usec(), randi() % 1_000_000]


func page_images_folder(page_id: String) -> String:
	return "%s/%s" % [JOURNAL_IMAGES_ROOT, page_id.strip_edges()]


func attachment_file_path(page_id: String, filename: String) -> String:
	return "%s/%s" % [page_images_folder(page_id), filename]


func _sanitize_attachment_filename(raw: String) -> String:
	var s: String = raw.get_file().strip_edges()
	if s.is_empty():
		return ""
	if s.contains("..") or s.contains("/") or s.contains("\\"):
		return ""
	if not s.ends_with(".png") and not s.ends_with(".jpg") and not s.ends_with(".jpeg") and not s.ends_with(".webp"):
		return ""
	for i in range(s.length()):
		var c: String = s.substr(i, 1)
		var ok: bool = (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9") or c == "_" or c == "-" or c == "."
		if not ok:
			return ""
	return s


func _sanitize_attachments_for_page(page_id: String, raw: Variant) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	for item in raw as Array:
		if out.size() >= MAX_ATTACHMENTS_PER_PAGE:
			break
		if not (item is Dictionary):
			continue
		var d: Dictionary = item as Dictionary
		var fn: String = _sanitize_attachment_filename(str(d.get("file", "")))
		if fn.is_empty():
			continue
		var full: String = attachment_file_path(page_id, fn)
		if not FileAccess.file_exists(full):
			continue
		var aid: String = str(d.get("id", "")).strip_edges()
		if aid.is_empty():
			aid = _random_attachment_id()
		out.append({"id": aid, "file": fn})
	return out


func _normalize_journal_image(img: Image) -> void:
	if img == null:
		return
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w <= 0 or h <= 0:
		return
	var mx: int = maxi(w, h)
	if mx > MAX_ATTACHMENT_EDGE:
		var sc: float = float(MAX_ATTACHMENT_EDGE) / float(mx)
		var nw: int = maxi(1, int(floor(w * sc)))
		var nh: int = maxi(1, int(floor(h * sc)))
		img.resize(nw, nh, Image.INTERPOLATE_LANCZOS)


## Saves PNG under [code]user://journal_images/{page_id}/[/code]. Returns filename only, or empty string on failure.
func save_journal_attachment_image(page_id: String, image: Image) -> String:
	if page_id.strip_edges().is_empty() or image == null:
		return ""
	var img: Image = image.duplicate()
	_normalize_journal_image(img)
	if img.get_width() <= 0 or img.get_height() <= 0:
		return ""
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var folder: String = page_images_folder(page_id)
	var rel_images: String = "journal_images/%s" % page_id.strip_edges()
	var user_da: DirAccess = DirAccess.open("user://")
	if user_da == null:
		push_warning("PersonalJournalStore: could not open user:// for journal images")
		return ""
	user_da.make_dir_recursive(rel_images)
	var fname: String = "shot_%d_%d.png" % [Time.get_ticks_msec(), randi() % 1_000_000]
	var full: String = "%s/%s" % [folder, fname]
	var err_wr: Error = img.save_png(full)
	if err_wr != OK:
		push_warning("PersonalJournalStore: save_png %s failed: %d" % [full, err_wr])
		return ""
	return fname


func make_attachment_entry(saved_filename: String) -> Dictionary:
	return {"id": _random_attachment_id(), "file": str(saved_filename)}


func delete_journal_attachment_file(page_id: String, filename: String) -> void:
	var fn: String = _sanitize_attachment_filename(filename)
	if fn.is_empty():
		return
	var full: String = attachment_file_path(page_id, fn)
	if FileAccess.file_exists(full):
		DirAccess.remove_absolute(full)


func _erase_directory_recursive(abs_path: String) -> void:
	var d: DirAccess = DirAccess.open(abs_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry: String = d.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = d.get_next()
			continue
		var sub: String = "%s/%s" % [abs_path, entry]
		if d.current_is_dir():
			_erase_directory_recursive(sub)
			DirAccess.remove_absolute(sub)
		else:
			DirAccess.remove_absolute(sub)
		entry = d.get_next()
	d.list_dir_end()
	DirAccess.remove_absolute(abs_path)


func delete_journal_page_images_folder(page_id: String) -> void:
	var pid: String = page_id.strip_edges()
	if pid.is_empty():
		return
	var folder: String = page_images_folder(pid)
	if DirAccess.open(folder) == null:
		return
	_erase_directory_recursive(folder)


func _default_page(title: String, body: String) -> Dictionary:
	var ux: int = int(Time.get_unix_time_from_system())
	return {"id": _random_page_id(), "title": title, "body": body, "edited_at": ux, "attachments": []}


## New tab for the journal UI (unique id, trimmed title).
func make_page(title: String, body: String = "") -> Dictionary:
	var t: String = str(title).strip_edges()
	if t.is_empty():
		t = "New page"
	t = t.substr(0, MAX_TITLE_LEN)
	var b: String = str(body)
	if b.length() > MAX_BODY_PER_PAGE:
		b = b.substr(0, MAX_BODY_PER_PAGE)
	var ux: int = int(Time.get_unix_time_from_system())
	return {"id": _random_page_id(), "title": t, "body": b, "edited_at": ux, "attachments": []}


func _default_document() -> Dictionary:
	return {
		"v": FORMAT_VERSION,
		"journal_font_size": JOURNAL_FONT_SIZE_DEFAULT,
		"pages": [_default_page("Notes", "")]
	}


func _migrate_legacy_txt_if_needed() -> void:
	if FileAccess.file_exists(SAVE_JSON):
		return
	if not FileAccess.file_exists(LEGACY_TXT):
		return
	var f: FileAccess = FileAccess.open(LEGACY_TXT, FileAccess.READ)
	if f == null:
		return
	var legacy_body: String = f.get_as_text()
	f.close()
	var doc: Dictionary = _default_document()
	var pages: Array = doc["pages"] as Array
	if pages.size() > 0 and pages[0] is Dictionary:
		(pages[0] as Dictionary)["body"] = legacy_body
	save_journal_data(doc)


func load_journal_data() -> Dictionary:
	_migrate_legacy_txt_if_needed()
	if not FileAccess.file_exists(SAVE_JSON):
		return _default_document()
	var f: FileAccess = FileAccess.open(SAVE_JSON, FileAccess.READ)
	if f == null:
		return _default_document()
	var raw: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		var d: Dictionary = parsed as Dictionary
		var pages: Variant = d.get("pages", [])
		if pages is Array and (pages as Array).size() > 0:
			return _sanitize_document(d)
	return _default_document()


func _sanitize_document(d: Dictionary) -> Dictionary:
	var out_pages: Array = []
	var pages: Array = d.get("pages", []) as Array
	var n: int = mini(MAX_PAGES, pages.size())
	for i in range(n):
		var row: Variant = pages[i]
		if not (row is Dictionary):
			continue
		var r: Dictionary = row as Dictionary
		var title: String = str(r.get("title", "Page %d" % (out_pages.size() + 1))).strip_edges()
		if title.is_empty():
			title = "Page %d" % (out_pages.size() + 1)
		title = title.substr(0, MAX_TITLE_LEN)
		var pid: String = str(r.get("id", "")).strip_edges()
		if pid.is_empty():
			pid = _random_page_id()
		var body: String = str(r.get("body", ""))
		if body.length() > MAX_BODY_PER_PAGE:
			body = body.substr(0, MAX_BODY_PER_PAGE)
		var edited_at: int = int(r.get("edited_at", 0))
		if edited_at < 0:
			edited_at = 0
		var attachments: Array = _sanitize_attachments_for_page(pid, r.get("attachments", []))
		out_pages.append({"id": pid, "title": title, "body": body, "edited_at": edited_at, "attachments": attachments})
	if out_pages.is_empty():
		return _default_document()
	var fs: int = int(d.get("journal_font_size", JOURNAL_FONT_SIZE_DEFAULT))
	fs = clampi(fs, JOURNAL_FONT_SIZE_MIN, JOURNAL_FONT_SIZE_MAX)
	return {"v": FORMAT_VERSION, "journal_font_size": fs, "pages": out_pages}


func save_journal_data(doc: Dictionary) -> void:
	var clean: Dictionary = _sanitize_document(doc)
	var f: FileAccess = FileAccess.open(SAVE_JSON, FileAccess.WRITE)
	if f == null:
		push_warning("PersonalJournalStore: could not write %s" % SAVE_JSON)
		return
	f.store_string(JSON.stringify(clean, "\t"))
	f.close()


func clamp_journal_font_size(px: int) -> int:
	return clampi(px, JOURNAL_FONT_SIZE_MIN, JOURNAL_FONT_SIZE_MAX)


func _journal_display_name_from_unit(unit: Node2D) -> String:
	if unit == null or not is_instance_valid(unit):
		return ""
	if unit is Unit:
		var u: Unit = unit as Unit
		var un: String = str(u.unit_name).strip_edges()
		if not un.is_empty():
			return un
	var v: Variant = unit.get("unit_name")
	if v != null:
		var from_unit_name: String = str(v).strip_edges()
		if not from_unit_name.is_empty():
			return from_unit_name
	v = unit.get("display_name")
	if v != null:
		var from_display: String = str(v).strip_edges()
		if not from_display.is_empty():
			return from_display
	var node_nm: String = str(unit.name)
	if not node_nm.is_empty() and node_nm != "Unit" and not node_nm.begins_with("@"):
		return node_nm.replace("_", " ").strip_edges()
	return ""


## Remember last tactical unit (inspect, details panel, or forecast target) for the journal “Unit” snippet.
func note_inspected_unit_for_journal(unit: Node2D) -> void:
	var nm: String = _journal_display_name_from_unit(unit)
	if nm.is_empty():
		return
	last_inspected_unit_display_name = nm


func _resolve_tactics_unit_node() -> Node2D:
	var bf: BattleField = _find_battlefield()
	if bf == null:
		return null
	var ps: Node = bf.player_state
	if ps != null and ps.get("targeted_enemy") != null:
		var te: Variant = ps.targeted_enemy
		if te is Node2D and is_instance_valid(te):
			return te as Node2D
	if bf.inspected_unit != null and is_instance_valid(bf.inspected_unit):
		return bf.inspected_unit
	return DetailedUnitInfoHelpers.get_unit_target_for_details(bf)


## Re-read the current battle context when the player presses “Unit” (forecast target, inspect, cursor, or active unit).
func refresh_last_unit_from_tactics_if_possible() -> void:
	var u: Node2D = _resolve_tactics_unit_node()
	if u != null:
		note_inspected_unit_for_journal(u)


## Plain-text block: name, level/class, HP, core stats, weapon (for [Unit] journal insert).
func format_journal_unit_block(unit: Node2D) -> String:
	if unit == null or not is_instance_valid(unit):
		return ""
	var title: String = _journal_display_name_from_unit(unit)
	if title.is_empty():
		return ""
	if not (unit is Unit):
		return title + "\n"
	var u: Unit = unit as Unit
	var cls: String = str(u.unit_class_name).strip_edges()
	if cls.is_empty():
		cls = "?"
	var lines: PackedStringArray = PackedStringArray()
	lines.append(title)
	lines.append("Lv %d %s · HP %d / %d" % [u.level, cls, u.current_hp, u.max_hp])
	lines.append(
		"STR %d · MAG %d · DEF %d · RES %d · SPD %d · AGI %d"
		% [u.strength, u.magic, u.defense, u.resistance, u.speed, u.agility]
	)
	if u.equipped_weapon != null:
		var wn: String = str(u.equipped_weapon.get("weapon_name")).strip_edges()
		if not wn.is_empty():
			lines.append("Weapon: %s" % wn)
	return "\n".join(Array(lines)) + "\n"


## Resolve current tactics unit and return text for the journal (stats if [Unit], else name only).
func get_journal_unit_insert_text() -> String:
	var u: Node2D = _resolve_tactics_unit_node()
	if u != null and is_instance_valid(u):
		note_inspected_unit_for_journal(u)
		return format_journal_unit_block(u)
	var nm: String = last_inspected_unit_display_name.strip_edges()
	if not nm.is_empty():
		return "%s\n(no live stats — not in battle or unit no longer available)\n" % nm
	return ""


func _find_battlefield() -> BattleField:
	var st: SceneTree = get_tree()
	if st == null or st.root == null:
		return null
	var scene: Node = st.current_scene
	if scene == null:
		return null
	return _find_battlefield_recursive(scene) as BattleField


func _find_battlefield_recursive(node: Node) -> Node:
	if node is BattleField:
		return node
	for c in node.get_children():
		var r: Node = _find_battlefield_recursive(c)
		if r != null:
			return r
	return null


## One-line context for template inserts (battle turn, story index, camp time when not in battle).
func get_context_stamp_line() -> String:
	var parts: PackedStringArray = []
	var bf: BattleField = _find_battlefield()
	var cm: Node = get_node_or_null("/root/CampaignManager")
	if bf != null:
		parts.append("Battle turn %d" % int(bf.current_turn))
	if cm != null and cm.get("current_level_index") != null:
		parts.append("Story stage %d" % (int(cm.current_level_index) + 1))
	if bf == null and cm != null and cm.get("camp_time_of_day") != null:
		parts.append("Camp: %s" % str(cm.camp_time_of_day))
	if parts.is_empty():
		return "—"
	return " · ".join(parts)
