extends Control

## Full-screen multi-page journal (Game Menu). See [PersonalJournalStore].

const NOTE_DIVIDER_DASH_COUNT := 80
## Default note ink (matches BodyEdit theme); used for “Plain” marks and preview base color.
const NOTES_BODY_DEFAULT_COLOR := Color(0.93, 0.91, 0.86, 1.0)

const BUILDS_TITLE := "Builds"
const BUILDS_BODY := """Party & build notes
---
Unit:
Role / plan:
Weapons & gear:
Skills to try:
Notes:
"""

var _pages: Array = []
var _selected: int = -1
var _suppress_ui: bool = false
var _save_timer: Timer = null
var _journal_font_size: int = PersonalJournalStore.JOURNAL_FONT_SIZE_DEFAULT
var _font_slider_suppress: bool = false

var _search_matches: Array = []
var _search_query_cached: String = ""
var _search_idx: int = -1

var _word_regex: RegEx = null
var _delete_confirm: ConfirmationDialog = null
var _backup_dialog: FileDialog = null
var _image_import_dialog: FileDialog = null
var _preview_win: Window = null
var _preview_tex: TextureRect = null
var _preview_att_id: String = ""
var _preview_filename: String = ""

@onready var _save_status_label: Label = $RootPanel/Margin/VBox/HeaderRow/SaveStatusLabel
@onready var _page_list: ItemList = $RootPanel/Margin/VBox/MainRow/Sidebar/SidebarListCard/PageList
@onready var _move_up_btn: Button = $RootPanel/Margin/VBox/MainRow/Sidebar/ReorderRow/MoveUpButton
@onready var _move_down_btn: Button = $RootPanel/Margin/VBox/MainRow/Sidebar/ReorderRow/MoveDownButton
@onready var _delete_page_btn: Button = $RootPanel/Margin/VBox/MainRow/Sidebar/ReorderRow/DeletePageButton
@onready var _add_page_btn: Button = $RootPanel/Margin/VBox/MainRow/Sidebar/SidebarButtons/AddPageButton
@onready var _pages_count_label: Label = $RootPanel/Margin/VBox/MainRow/Sidebar/SidebarButtons/PagesCountLabel
@onready var _search_edit: LineEdit = $RootPanel/Margin/VBox/SearchCard/SearchMargin/SearchRow/SearchEdit
@onready var _search_next_btn: Button = $RootPanel/Margin/VBox/SearchCard/SearchMargin/SearchRow/SearchNextButton
@onready var _root_panel: PanelContainer = $RootPanel
@onready var _title_edit: LineEdit = $RootPanel/Margin/VBox/MainRow/EditorColumn/PageTitleRow/PageTitleEdit
@onready var _body_preview: RichTextLabel = $RootPanel/Margin/VBox/MainRow/EditorColumn/BodyCard/BodyMargin/BodyInnerVBox/BodyPreview
@onready var _body_edit: TextEdit = $RootPanel/Margin/VBox/MainRow/EditorColumn/BodyCard/BodyMargin/BodyInnerVBox/BodyEdit
@onready var _last_edited_label: Label = $RootPanel/Margin/VBox/MainRow/EditorColumn/MetaRow/LastEditedLabel
@onready var _counts_label: Label = $RootPanel/Margin/VBox/MainRow/EditorColumn/MetaRow/CountsLabel
@onready var _font_slider: HSlider = $RootPanel/Margin/VBox/MainRow/EditorColumn/QuickToolsCard/QuickToolsMargin/QuickToolsVBox/ToolsRow/FontSizeSlider
@onready var _sel_color_picker: ColorPickerButton = $RootPanel/Margin/VBox/MainRow/EditorColumn/QuickToolsCard/QuickToolsMargin/QuickToolsVBox/SelectionRow/SelectionColorPicker
@onready var _apply_mark_color_btn: Button = $RootPanel/Margin/VBox/MainRow/EditorColumn/QuickToolsCard/QuickToolsMargin/QuickToolsVBox/SelectionRow/ApplyMarkColorButton
@onready var _mark_plain_btn: Button = $RootPanel/Margin/VBox/MainRow/EditorColumn/QuickToolsCard/QuickToolsMargin/QuickToolsVBox/SelectionRow/MarkPlainButton
@onready var _paste_image_btn: Button = $RootPanel/Margin/VBox/MainRow/EditorColumn/AttachmentsCard/AttachmentsMargin/AttachmentsVBox/AttachmentsToolbar/PasteImageButton
@onready var _import_image_btn: Button = $RootPanel/Margin/VBox/MainRow/EditorColumn/AttachmentsCard/AttachmentsMargin/AttachmentsVBox/AttachmentsToolbar/ImportImageButton
@onready var _capture_screen_btn: Button = $RootPanel/Margin/VBox/MainRow/EditorColumn/AttachmentsCard/AttachmentsMargin/AttachmentsVBox/AttachmentsToolbar/CaptureScreenButton
@onready var _attachments_scroll: ScrollContainer = $RootPanel/Margin/VBox/MainRow/EditorColumn/AttachmentsCard/AttachmentsMargin/AttachmentsVBox/AttachmentsScroll
@onready var _attachments_strip: HBoxContainer = $RootPanel/Margin/VBox/MainRow/EditorColumn/AttachmentsCard/AttachmentsMargin/AttachmentsVBox/AttachmentsScroll/AttachmentsStrip
@onready var _attachments_empty_hint: Label = $RootPanel/Margin/VBox/MainRow/EditorColumn/AttachmentsCard/AttachmentsMargin/AttachmentsVBox/AttachmentsEmptyHint
@onready var _close_button: Button = $RootPanel/Margin/VBox/CloseRow/CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 1000
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_word_regex = RegEx.new()
	_word_regex.compile("\\S+")
	if _close_button:
		_close_button.pressed.connect(_on_close_pressed)
	if _add_page_btn:
		_add_page_btn.pressed.connect(_on_add_page_pressed)
	if _move_up_btn:
		_move_up_btn.pressed.connect(_on_move_page_up)
	if _move_down_btn:
		_move_down_btn.pressed.connect(_on_move_page_down)
	if _delete_page_btn:
		_delete_page_btn.pressed.connect(_on_delete_page_pressed)
	if _page_list:
		_page_list.item_selected.connect(_on_page_list_selected)
	if _title_edit:
		_title_edit.text_submitted.connect(_on_title_submitted)
		_title_edit.focus_exited.connect(_on_title_focus_exited)
	if _search_edit:
		_search_edit.text_changed.connect(_on_search_text_changed)
		_search_edit.text_submitted.connect(func(_t: String) -> void: _on_search_next_pressed())
	if _search_next_btn:
		_search_next_btn.pressed.connect(_on_search_next_pressed)
	if _font_slider:
		_font_slider.min_value = float(PersonalJournalStore.JOURNAL_FONT_SIZE_MIN)
		_font_slider.max_value = float(PersonalJournalStore.JOURNAL_FONT_SIZE_MAX)
		_font_slider.step = 1.0
		_font_slider.value_changed.connect(_on_font_slider_changed)
	if _sel_color_picker:
		_sel_color_picker.color = Color(1.0, 0.88, 0.45, 1.0)
	if _apply_mark_color_btn:
		_apply_mark_color_btn.pressed.connect(_on_apply_mark_color_pressed)
	if _mark_plain_btn:
		_mark_plain_btn.pressed.connect(_on_mark_plain_pressed)
	_connect_template_buttons()
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.55
	add_child(_save_timer)
	_save_timer.timeout.connect(_on_save_timer_timeout)
	if _body_edit:
		_body_edit.text_changed.connect(_on_body_changed)
	_delete_confirm = ConfirmationDialog.new()
	_delete_confirm.title = "Delete page"
	_delete_confirm.dialog_text = "Delete this page and all of its notes? This cannot be undone."
	_delete_confirm.ok_button_text = "Delete"
	add_child(_delete_confirm)
	_delete_confirm.confirmed.connect(_on_delete_confirmed)
	_backup_dialog = FileDialog.new()
	_backup_dialog.title = "Save journal backup"
	_backup_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_backup_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_backup_dialog.add_filter("*.json", "JSON")
	_backup_dialog.current_file = "journal_backup.json"
	add_child(_backup_dialog)
	_backup_dialog.file_selected.connect(_on_backup_file_selected)
	_image_import_dialog = FileDialog.new()
	_image_import_dialog.title = "Import image"
	_image_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_image_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_image_import_dialog.add_filter("*.png", "PNG")
	_image_import_dialog.add_filter("*.jpg,*.jpeg", "JPEG")
	_image_import_dialog.add_filter("*.webp", "WebP")
	add_child(_image_import_dialog)
	_image_import_dialog.file_selected.connect(_on_import_image_selected)
	if _paste_image_btn:
		_paste_image_btn.pressed.connect(_on_paste_image_pressed)
	if _import_image_btn:
		_import_image_btn.pressed.connect(func() -> void: _image_import_dialog.popup_centered())
	if _capture_screen_btn:
		_capture_screen_btn.pressed.connect(_on_capture_screen_pressed)
	if _body_edit:
		# Keep selection when clicking Apply / color picker (otherwise wrap sees no selection).
		_body_edit.deselect_on_focus_loss_enabled = false
	_build_attachment_preview_window()


func _build_attachment_preview_window() -> void:
	_preview_win = Window.new()
	_preview_win.title = "Screenshot"
	_preview_win.size = Vector2i(560, 480)
	_preview_win.visible = false
	_preview_win.close_requested.connect(func() -> void: _preview_win.hide())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_preview_win.add_child(margin)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(vb)
	_preview_tex = TextureRect.new()
	_preview_tex.custom_minimum_size = Vector2(520, 360)
	_preview_tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(_preview_tex)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_END
	var del_btn := Button.new()
	del_btn.text = "Remove from page"
	del_btn.pressed.connect(_on_preview_remove_pressed)
	hb.add_child(del_btn)
	vb.add_child(hb)
	add_child(_preview_win)


func _connect_template_buttons() -> void:
	var base := "RootPanel/Margin/VBox/MainRow/EditorColumn/QuickToolsCard/QuickToolsMargin/QuickToolsVBox/InsertRow/"
	var map := {
		"InsertEnemyButton": "Enemy: ",
		"InsertLootButton": "Loot: ",
		"InsertQuestButton": "Quest: ",
	}
	for node_name in map:
		var b: Button = get_node_or_null(base + node_name) as Button
		if b:
			var ins: String = map[node_name]
			b.pressed.connect(func() -> void: _insert_at_caret(ins))
	var stamp_btn: Button = get_node_or_null(base + "InsertStampButton") as Button
	if stamp_btn:
		stamp_btn.pressed.connect(_on_insert_stamp_pressed)
	var unit_btn: Button = get_node_or_null(base + "InsertUnitNameButton") as Button
	if unit_btn:
		unit_btn.pressed.connect(_on_insert_unit_name_pressed)
	var builds_btn: Button = get_node_or_null(base + "InsertBuildsButton") as Button
	if builds_btn:
		builds_btn.pressed.connect(_on_insert_builds_page_pressed)
	var div_btn: Button = get_node_or_null(base + "InsertDividerButton") as Button
	if div_btn:
		div_btn.pressed.connect(func() -> void: _insert_at_caret("-".repeat(NOTE_DIVIDER_DASH_COUNT) + "\n"))
	var copy_btn: Button = get_node_or_null("RootPanel/Margin/VBox/MainRow/EditorColumn/QuickToolsCard/QuickToolsMargin/QuickToolsVBox/ToolsRow/CopyJsonButton") as Button
	if copy_btn:
		copy_btn.pressed.connect(_on_copy_json_pressed)
	var backup_btn: Button = get_node_or_null("RootPanel/Margin/VBox/MainRow/EditorColumn/QuickToolsCard/QuickToolsMargin/QuickToolsVBox/ToolsRow/SaveBackupButton") as Button
	if backup_btn:
		backup_btn.pressed.connect(_on_save_backup_pressed)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _preview_win != null and _preview_win.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event as InputEventKey
		if k.keycode == KEY_V and k.ctrl_pressed and k.shift_pressed:
			var clip_img: Image = DisplayServer.clipboard_get_image()
			if _clipboard_image_is_usable(clip_img):
				_try_add_image_to_page(clip_img)
				get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event as InputEventKey
		if k.keycode == KEY_TAB and k.ctrl_pressed:
			_cycle_page(1)
			get_viewport().set_input_as_handled()


func open_journal() -> void:
	if PersonalJournalStore == null:
		return
	_apply_journal_window_size()
	var doc: Dictionary = PersonalJournalStore.load_journal_data()
	_pages = _clone_pages_from_doc(doc)
	_journal_font_size = int(doc.get("journal_font_size", PersonalJournalStore.JOURNAL_FONT_SIZE_DEFAULT))
	_journal_font_size = PersonalJournalStore.clamp_journal_font_size(_journal_font_size)
	if _pages.is_empty():
		_pages.append(PersonalJournalStore.make_page("Notes", ""))
	_selected = clampi(_selected, 0, _pages.size() - 1)
	_reset_search_state()
	_font_slider_suppress = true
	if _font_slider:
		_font_slider.value = float(_journal_font_size)
	_font_slider_suppress = false
	_apply_journal_font_size(_journal_font_size)
	_refresh_page_list()
	_apply_selected_page_to_ui(false)
	_update_add_button_and_count()
	_update_reorder_buttons()
	_update_last_edited_label()
	_update_counts_label()
	_refresh_attachments_strip()
	_update_attachment_toolbar()
	_set_save_status_saved()
	visible = true
	if _body_edit:
		_body_edit.grab_focus()


func close_and_save() -> void:
	if not visible:
		return
	_on_close_pressed()


func _apply_journal_window_size() -> void:
	if _root_panel == null:
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var sz: Vector2 = vp.get_visible_rect().size
	var w: float = clampf(sz.x * 0.90, 1080.0, 1780.0)
	var h: float = clampf(sz.y * 0.88, 620.0, 1020.0)
	var half: Vector2 = Vector2(w, h) * 0.5
	_root_panel.offset_left = -half.x
	_root_panel.offset_top = -half.y
	_root_panel.offset_right = half.x
	_root_panel.offset_bottom = half.y


func _clone_pages_from_doc(doc: Dictionary) -> Array:
	var out: Array = []
	var raw: Variant = doc.get("pages", [])
	if raw is Array:
		for row in (raw as Array):
			if row is Dictionary:
				out.append((row as Dictionary).duplicate(true))
	return out


func _refresh_page_list() -> void:
	if _page_list == null:
		return
	var prev_suppress: bool = _suppress_ui
	_suppress_ui = true
	_page_list.clear()
	for i in range(_pages.size()):
		var p: Dictionary = _pages[i] as Dictionary
		_page_list.add_item(str(p.get("title", "Page")))
		var tip: String = _tooltip_for_page_row(p)
		_page_list.set_item_tooltip(i, tip)
	if _selected >= 0 and _selected < _page_list.item_count:
		_page_list.select(_selected)
	_page_list.queue_redraw()
	_suppress_ui = prev_suppress


func _tooltip_for_page_row(row: Dictionary) -> String:
	var ux: int = int(row.get("edited_at", 0))
	var ac: int = _attachments_count(row)
	var time_s: String = "Last edited: (not yet saved)" if ux <= 0 else "Last edited: %s" % _format_unix(ux)
	return "%s\n%d screenshot(s)" % [time_s, ac]


func _format_unix(ux: int) -> String:
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(ux)
	return "%04d-%02d-%02d  %02d:%02d" % [int(d.year), int(d.month), int(d.day), int(d.hour), int(d.minute)]


func _commit_body_to_selected() -> void:
	if _selected < 0 or _selected >= _pages.size():
		return
	if _body_edit == null:
		return
	var row: Dictionary = _pages[_selected] as Dictionary
	var b: String = _body_edit.text
	if b.length() > PersonalJournalStore.MAX_BODY_PER_PAGE:
		b = b.substr(0, PersonalJournalStore.MAX_BODY_PER_PAGE)
	row["body"] = b


func _apply_selected_page_to_ui(from_list_click: bool) -> void:
	if _selected < 0 or _selected >= _pages.size():
		return
	_suppress_ui = true
	var row: Dictionary = _pages[_selected] as Dictionary
	if _body_edit:
		_body_edit.text = str(row.get("body", ""))
	if _title_edit:
		_title_edit.text = str(row.get("title", ""))
	_suppress_ui = false
	_sync_body_preview_from_edit()
	_update_add_button_and_count()
	_update_reorder_buttons()
	_update_last_edited_label()
	_update_counts_label()
	_refresh_attachments_strip()
	_update_attachment_toolbar()


func _on_page_list_selected(index: int) -> void:
	if _suppress_ui:
		return
	if index < 0 or index >= _pages.size():
		return
	if index == _selected:
		return
	_commit_body_to_selected()
	_selected = index
	_apply_selected_page_to_ui(true)


func _on_title_submitted(_new_text: String) -> void:
	_apply_title_from_field()
	if _title_edit:
		_title_edit.release_focus()


func _on_title_focus_exited() -> void:
	_apply_title_from_field()


func _apply_title_from_field() -> void:
	if _suppress_ui:
		return
	if _selected < 0 or _selected >= _pages.size() or _title_edit == null:
		return
	var t: String = _title_edit.text.strip_edges()
	if t.is_empty():
		t = "Page %d" % (_selected + 1)
	t = t.substr(0, PersonalJournalStore.MAX_TITLE_LEN)
	var row: Dictionary = _pages[_selected] as Dictionary
	row["title"] = t
	if _page_list != null and _selected < _page_list.item_count:
		_page_list.set_item_text(_selected, t)
		_page_list.set_item_tooltip(_selected, _tooltip_for_page_row(row))
	_touch_edited_timestamp_for_selected()
	_schedule_save()


func _on_add_page_pressed() -> void:
	if PersonalJournalStore == null:
		return
	if _pages.size() >= PersonalJournalStore.MAX_PAGES:
		return
	_commit_body_to_selected()
	var n: int = _pages.size() + 1
	var new_page: Dictionary = PersonalJournalStore.make_page("Page %d" % n, "")
	_pages.append(new_page)
	_selected = _pages.size() - 1
	_refresh_page_list()
	_apply_selected_page_to_ui(false)
	if _page_list:
		_page_list.select(_selected)
	_update_add_button_and_count()
	_update_reorder_buttons()
	_schedule_save()


func _on_move_page_up() -> void:
	if _selected <= 0:
		return
	_commit_body_to_selected()
	var t: Variant = _pages[_selected]
	_pages[_selected] = _pages[_selected - 1]
	_pages[_selected - 1] = t
	_selected -= 1
	_refresh_page_list()
	if _page_list:
		_page_list.select(_selected)
	_update_reorder_buttons()
	_schedule_save()


func _on_move_page_down() -> void:
	if _selected < 0 or _selected >= _pages.size() - 1:
		return
	_commit_body_to_selected()
	var t: Variant = _pages[_selected]
	_pages[_selected] = _pages[_selected + 1]
	_pages[_selected + 1] = t
	_selected += 1
	_refresh_page_list()
	if _page_list:
		_page_list.select(_selected)
	_update_reorder_buttons()
	_schedule_save()


func _on_delete_page_pressed() -> void:
	if _pages.size() <= 1:
		return
	if _delete_confirm:
		_delete_confirm.popup_centered()


func _on_delete_confirmed() -> void:
	if _pages.size() <= 1:
		return
	if _selected < 0 or _selected >= _pages.size():
		return
	var removed: Dictionary = _pages[_selected] as Dictionary
	var del_pid: String = str(removed.get("id", ""))
	_pages.remove_at(_selected)
	if PersonalJournalStore and not del_pid.is_empty():
		PersonalJournalStore.delete_journal_page_images_folder(del_pid)
	_selected = mini(_selected, _pages.size() - 1)
	_refresh_page_list()
	_apply_selected_page_to_ui(false)
	if _page_list:
		_page_list.select(_selected)
	_update_add_button_and_count()
	_update_reorder_buttons()
	_schedule_save()


func _update_add_button_and_count() -> void:
	var n: int = _pages.size()
	if _pages_count_label:
		_pages_count_label.text = "%d / %d" % [n, PersonalJournalStore.MAX_PAGES]
	if _add_page_btn:
		_add_page_btn.disabled = n >= PersonalJournalStore.MAX_PAGES
	if _delete_page_btn:
		_delete_page_btn.disabled = n <= 1


func _update_reorder_buttons() -> void:
	var n: int = _pages.size()
	if _move_up_btn:
		_move_up_btn.disabled = _selected <= 0 or n <= 1
	if _move_down_btn:
		_move_down_btn.disabled = _selected < 0 or _selected >= n - 1 or n <= 1


func _on_body_changed() -> void:
	if _suppress_ui:
		return
	_update_counts_label()
	_sync_body_preview_from_edit()
	_schedule_save()


func _touch_edited_timestamp_for_selected() -> void:
	if _selected < 0 or _selected >= _pages.size():
		return
	var row: Dictionary = _pages[_selected] as Dictionary
	row["edited_at"] = int(Time.get_unix_time_from_system())
	_update_last_edited_label()
	if _page_list != null and _selected < _page_list.item_count:
		_page_list.set_item_tooltip(_selected, _tooltip_for_page_row(row))


func _schedule_save() -> void:
	_touch_edited_timestamp_for_selected()
	_set_save_status_unsaved()
	if _save_timer != null:
		_save_timer.start()


func _on_save_timer_timeout() -> void:
	_set_save_status_saving()
	_persist_full_to_store()
	_set_save_status_saved()


func _build_doc_for_save() -> Dictionary:
	_commit_body_to_selected()
	var arr: Array = []
	for p in _pages:
		if p is Dictionary:
			arr.append((p as Dictionary).duplicate(true))
	return {
		"v": PersonalJournalStore.FORMAT_VERSION,
		"journal_font_size": _journal_font_size,
		"pages": arr,
	}


func _persist_full_to_store() -> void:
	if PersonalJournalStore == null:
		return
	var doc: Dictionary = _build_doc_for_save()
	PersonalJournalStore.save_journal_data(doc)


func _on_close_pressed() -> void:
	if _save_timer != null and not _save_timer.is_stopped():
		_save_timer.stop()
	_set_save_status_saving()
	_persist_full_to_store()
	_set_save_status_saved()
	visible = false


func _set_save_status_unsaved() -> void:
	if _save_status_label:
		_save_status_label.text = "Unsaved…"
		_save_status_label.modulate = Color(1.0, 0.82, 0.45, 1.0)


func _set_save_status_saving() -> void:
	if _save_status_label:
		_save_status_label.text = "Saving…"
		_save_status_label.modulate = Color(0.65, 0.85, 1.0, 1.0)


func _set_save_status_saved() -> void:
	if _save_status_label:
		_save_status_label.text = "All changes saved"
		_save_status_label.modulate = Color(0.62, 0.72, 0.58, 1.0)


func _update_last_edited_label() -> void:
	if _last_edited_label == null or _selected < 0 or _selected >= _pages.size():
		return
	var row: Dictionary = _pages[_selected] as Dictionary
	var ux: int = int(row.get("edited_at", 0))
	if ux <= 0:
		_last_edited_label.text = "Last edited: —"
	else:
		_last_edited_label.text = "Last edited: %s" % _format_unix(ux)


func _update_counts_label() -> void:
	if _counts_label == null or _body_edit == null:
		return
	var s: String = _body_edit.text
	var chars: int = s.length()
	var words: int = 0
	if _word_regex != null:
		words = _word_regex.search_all(s).size()
	_counts_label.text = "%d words · %d characters" % [words, chars]


func _bbcode_hex_for_color(c: Color) -> String:
	if c.a >= 0.999:
		return c.to_html(false)
	return c.to_html(true)


func _wrap_selection_with_color_tag(c: Color) -> void:
	if _body_edit == null:
		return
	if _body_edit.get_caret_count() != 1:
		return
	if not _body_edit.has_selection():
		return
	var sel_text: String = _body_edit.get_selected_text()
	if sel_text.is_empty():
		return
	var hex: String = _bbcode_hex_for_color(c)
	var wrapped: String = "[color=#%s]%s[/color]" % [hex, sel_text]
	_suppress_ui = true
	_body_edit.begin_complex_operation()
	_body_edit.delete_selection()
	_body_edit.insert_text_at_caret(wrapped)
	_body_edit.end_complex_operation()
	_suppress_ui = false
	_sync_body_preview_from_edit()
	_update_counts_label()
	_schedule_save()
	_body_edit.grab_focus()


func _sync_body_preview_from_edit() -> void:
	if _body_preview == null or _body_edit == null:
		return
	var t: String = _body_edit.text
	if _body_preview.bbcode_enabled:
		_body_preview.parse_bbcode(t)
	else:
		_body_preview.text = t


func _on_apply_mark_color_pressed() -> void:
	if _sel_color_picker == null:
		return
	_wrap_selection_with_color_tag(_sel_color_picker.color)


func _on_mark_plain_pressed() -> void:
	_wrap_selection_with_color_tag(NOTES_BODY_DEFAULT_COLOR)


func _apply_journal_font_size(px: int) -> void:
	px = PersonalJournalStore.clamp_journal_font_size(px)
	if _body_edit:
		_body_edit.add_theme_font_size_override("font_size", px)
	if _body_preview:
		_body_preview.add_theme_font_size_override("normal_font_size", px)
	if _title_edit:
		_title_edit.add_theme_font_size_override("font_size", mini(px + 1, PersonalJournalStore.JOURNAL_FONT_SIZE_MAX))
	if _search_edit:
		_search_edit.add_theme_font_size_override("font_size", clampi(px - 2, PersonalJournalStore.JOURNAL_FONT_SIZE_MIN, PersonalJournalStore.JOURNAL_FONT_SIZE_MAX))
	if _page_list:
		_page_list.add_theme_font_size_override("font_size", clampi(px - 3, PersonalJournalStore.JOURNAL_FONT_SIZE_MIN, PersonalJournalStore.JOURNAL_FONT_SIZE_MAX))


func _on_font_slider_changed(v: float) -> void:
	if _font_slider_suppress:
		return
	_journal_font_size = int(round(v))
	_apply_journal_font_size(_journal_font_size)
	_schedule_save()


func _reset_search_state() -> void:
	_search_matches.clear()
	_search_query_cached = ""
	_search_idx = -1


func _on_search_text_changed(_new_text: String) -> void:
	_reset_search_state()


func _collect_matches(query: String) -> Array:
	var out: Array = []
	if query.length() < 1:
		return out
	var ql: String = query.to_lower()
	for pi in range(_pages.size()):
		var body: String = str((_pages[pi] as Dictionary).get("body", ""))
		var lines: PackedStringArray = body.split("\n")
		for li in range(lines.size()):
			var line: String = lines[li]
			var lower: String = line.to_lower()
			var from: int = 0
			while true:
				var pos: int = lower.find(ql, from)
				if pos < 0:
					break
				out.append({"p": pi, "l": li, "a": pos, "b": pos + query.length()})
				from = pos + 1
	return out


func _on_search_next_pressed() -> void:
	var q: String = _search_edit.text.strip_edges() if _search_edit else ""
	if q.is_empty():
		return
	if _search_query_cached != q or _search_matches.is_empty():
		_search_query_cached = q
		_search_matches = _collect_matches(q)
		_search_idx = -1
	if _search_matches.is_empty():
		return
	_search_idx = (_search_idx + 1) % _search_matches.size()
	var m: Dictionary = _search_matches[_search_idx] as Dictionary
	_go_to_match(m)


func _go_to_match(m: Dictionary) -> void:
	var pi: int = int(m.get("p", 0))
	var li: int = int(m.get("l", 0))
	var a: int = int(m.get("a", 0))
	var b: int = int(m.get("b", 0))
	if pi < 0 or pi >= _pages.size():
		return
	if pi != _selected:
		_commit_body_to_selected()
		_selected = pi
		_refresh_page_list()
		_apply_selected_page_to_ui(false)
		if _page_list:
			_page_list.select(_selected)
	_update_reorder_buttons()
	if _body_edit == null:
		return
	_suppress_ui = true
	# TextEdit has no scroll_to_line(); adjust_viewport brings the caret row into view.
	_body_edit.set_caret_line(li, true)
	_body_edit.set_caret_column(b)
	_body_edit.select(li, a, li, b)
	_body_edit.set_caret_line(li, true)
	if _body_edit.has_method("center_viewport_to_caret"):
		_body_edit.center_viewport_to_caret()
	_suppress_ui = false


func _cycle_page(delta: int) -> void:
	if _pages.is_empty():
		return
	_commit_body_to_selected()
	_selected = (_selected + delta) % _pages.size()
	if _selected < 0:
		_selected += _pages.size()
	_refresh_page_list()
	_apply_selected_page_to_ui(false)
	if _page_list:
		_page_list.select(_selected)
	_update_reorder_buttons()


func _insert_at_caret(chunk: String) -> void:
	if _body_edit == null:
		return
	_body_edit.insert_text_at_caret(chunk)
	_body_edit.grab_focus()


func _on_insert_stamp_pressed() -> void:
	if PersonalJournalStore == null:
		return
	var stamp: String = "[%s]\n" % PersonalJournalStore.get_context_stamp_line()
	_insert_at_caret(stamp)


func _on_insert_unit_name_pressed() -> void:
	if PersonalJournalStore == null:
		return
	var chunk: String = PersonalJournalStore.get_journal_unit_insert_text()
	if chunk.is_empty():
		_insert_at_caret("(no unit — inspect or target a unit on the map first)\n")
		return
	_insert_at_caret(chunk)


func _on_insert_builds_page_pressed() -> void:
	if PersonalJournalStore == null:
		return
	if _pages.size() >= PersonalJournalStore.MAX_PAGES:
		return
	_commit_body_to_selected()
	var pg: Dictionary = PersonalJournalStore.make_page(BUILDS_TITLE, BUILDS_BODY)
	_pages.append(pg)
	_selected = _pages.size() - 1
	_refresh_page_list()
	_apply_selected_page_to_ui(false)
	if _page_list:
		_page_list.select(_selected)
	_update_add_button_and_count()
	_update_reorder_buttons()
	_schedule_save()
	if _body_edit:
		_body_edit.grab_focus()


func _on_copy_json_pressed() -> void:
	if _save_timer != null and not _save_timer.is_stopped():
		_save_timer.stop()
	_commit_body_to_selected()
	var doc: Dictionary = _build_doc_for_save()
	DisplayServer.clipboard_set(JSON.stringify(doc, "\t"))
	_set_save_status_saved()
	_persist_full_to_store()


func _on_save_backup_pressed() -> void:
	if _backup_dialog:
		_backup_dialog.popup_centered()


func _on_backup_file_selected(path: String) -> void:
	if path.is_empty():
		return
	if _save_timer != null and not _save_timer.is_stopped():
		_save_timer.stop()
	_commit_body_to_selected()
	var doc: Dictionary = _build_doc_for_save()
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("PersonalJournal: could not write backup %s" % path)
		return
	f.store_string(JSON.stringify(doc, "\t"))
	f.close()
	_persist_full_to_store()
	_set_save_status_saved()


func _attachments_count(row: Dictionary) -> int:
	_ensure_attachments(row)
	return (row["attachments"] as Array).size()


func _ensure_attachments(row: Dictionary) -> void:
	var v: Variant = row.get("attachments", [])
	if v is Array:
		row["attachments"] = v
	else:
		row["attachments"] = []


func _selected_page_id() -> String:
	if _selected < 0 or _selected >= _pages.size():
		return ""
	return str((_pages[_selected] as Dictionary).get("id", "")).strip_edges()


func _clipboard_image_is_usable(img: Image) -> bool:
	return img != null and img.get_width() > 0 and img.get_height() > 0


func _make_thumb_texture(source: Image) -> Texture2D:
	var dup: Image = source.duplicate()
	var w: int = dup.get_width()
	var h: int = dup.get_height()
	var tmax: int = 72
	if w > tmax or h > tmax:
		var mx: float = maxf(float(w), float(h))
		var sc: float = float(tmax) / mx
		dup.resize(maxi(1, int(floor(w * sc))), maxi(1, int(floor(h * sc))), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(dup)


func _try_add_image_to_page(img: Image) -> bool:
	if PersonalJournalStore == null or img == null:
		return false
	_commit_body_to_selected()
	if _selected < 0 or _selected >= _pages.size():
		return false
	var row: Dictionary = _pages[_selected] as Dictionary
	_ensure_attachments(row)
	var att: Array = row["attachments"] as Array
	if att.size() >= PersonalJournalStore.MAX_ATTACHMENTS_PER_PAGE:
		return false
	var pid: String = str(row.get("id", "")).strip_edges()
	if pid.is_empty():
		return false
	var fname: String = PersonalJournalStore.save_journal_attachment_image(pid, img)
	if fname.is_empty():
		return false
	att.append(PersonalJournalStore.make_attachment_entry(fname))
	_refresh_attachments_strip()
	_update_attachment_toolbar()
	if _page_list != null and _selected >= 0 and _selected < _page_list.item_count:
		_page_list.set_item_tooltip(_selected, _tooltip_for_page_row(row))
	_schedule_save()
	return true


func _refresh_attachments_strip() -> void:
	if _attachments_strip == null:
		return
	for c in _attachments_strip.get_children():
		_attachments_strip.remove_child(c)
		c.free()
	if _selected < 0 or _selected >= _pages.size():
		if _attachments_empty_hint:
			_attachments_empty_hint.visible = true
		if _attachments_scroll:
			_attachments_scroll.visible = false
		return
	var row: Dictionary = _pages[_selected] as Dictionary
	_ensure_attachments(row)
	var att: Array = row["attachments"] as Array
	var has_att: bool = not att.is_empty()
	if _attachments_empty_hint:
		_attachments_empty_hint.visible = not has_att
	if _attachments_scroll:
		_attachments_scroll.visible = has_att
	var pid: String = str(row.get("id", ""))
	for item in att:
		if not item is Dictionary:
			continue
		var d: Dictionary = item as Dictionary
		var fn: String = str(d.get("file", ""))
		var aid: String = str(d.get("id", ""))
		var abs_path: String = ProjectSettings.globalize_path(PersonalJournalStore.attachment_file_path(pid, fn))
		var base_img := Image.new()
		if base_img.load(abs_path) != OK:
			continue
		var tb := TextureButton.new()
		tb.custom_minimum_size = Vector2(76, 76)
		tb.ignore_texture_size = true
		tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		tb.texture_normal = _make_thumb_texture(base_img)
		var id_copy: String = aid
		var fn_copy: String = fn
		tb.pressed.connect(func() -> void: _open_attachment_preview(id_copy, fn_copy))
		_attachments_strip.add_child(tb)


func _update_attachment_toolbar() -> void:
	var full: bool = false
	if _selected >= 0 and _selected < _pages.size():
		var row: Dictionary = _pages[_selected] as Dictionary
		_ensure_attachments(row)
		full = (row["attachments"] as Array).size() >= PersonalJournalStore.MAX_ATTACHMENTS_PER_PAGE
	if _paste_image_btn:
		_paste_image_btn.disabled = full
	if _import_image_btn:
		_import_image_btn.disabled = full
	if _capture_screen_btn:
		_capture_screen_btn.disabled = full


func _open_attachment_preview(att_id: String, filename: String) -> void:
	_preview_att_id = att_id
	_preview_filename = filename
	var pid: String = _selected_page_id()
	if pid.is_empty() or _preview_tex == null or _preview_win == null:
		return
	var abs_path: String = ProjectSettings.globalize_path(PersonalJournalStore.attachment_file_path(pid, filename))
	var img := Image.new()
	if img.load(abs_path) != OK:
		return
	_preview_tex.texture = ImageTexture.create_from_image(img)
	_preview_win.popup_centered()


func _on_preview_remove_pressed() -> void:
	if _preview_win != null:
		_preview_win.hide()
	_remove_attachment_entry(_preview_att_id, _preview_filename)


func _remove_attachment_entry(att_id: String, filename: String) -> void:
	if _selected < 0 or _selected >= _pages.size():
		return
	var row: Dictionary = _pages[_selected] as Dictionary
	var pid: String = str(row.get("id", ""))
	_ensure_attachments(row)
	var att: Array = row["attachments"] as Array
	for i in range(att.size() - 1, -1, -1):
		var d: Dictionary = att[i] as Dictionary
		if str(d.get("id", "")) == att_id and str(d.get("file", "")) == filename:
			if PersonalJournalStore:
				PersonalJournalStore.delete_journal_attachment_file(pid, str(d.get("file", "")))
			att.remove_at(i)
			break
	row["attachments"] = att
	_refresh_attachments_strip()
	_update_attachment_toolbar()
	if _page_list != null and _selected >= 0 and _selected < _page_list.item_count:
		_page_list.set_item_tooltip(_selected, _tooltip_for_page_row(row))
	_schedule_save()


func _on_paste_image_pressed() -> void:
	var clip_img: Image = DisplayServer.clipboard_get_image()
	if not _clipboard_image_is_usable(clip_img):
		return
	if not _try_add_image_to_page(clip_img):
		pass


func _on_import_image_selected(path: String) -> void:
	if path.is_empty():
		return
	var img := Image.new()
	if img.load(path) != OK:
		push_warning("PersonalJournal: could not load image %s" % path)
		return
	_try_add_image_to_page(img)


func _on_capture_screen_pressed() -> void:
	_capture_viewport_async()


func _capture_viewport_async() -> void:
	if not visible:
		return
	_commit_body_to_selected()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var vp: Viewport = get_viewport()
	var shot: Image = null
	if vp != null:
		var tex: Texture2D = vp.get_texture()
		if tex != null:
			shot = tex.get_image()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if shot == null or shot.get_width() <= 0:
		return
	shot.flip_y()
	_try_add_image_to_page(shot)
