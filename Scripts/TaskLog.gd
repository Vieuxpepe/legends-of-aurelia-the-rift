extends Control

class_name TaskLog

@onready var title_label: Label = Label.new()
@onready var giver_label: Label = Label.new()
@onready var depth_label: Label = Label.new()
@onready var type_label: Label = Label.new()
@onready var status_label: Label = Label.new()
@onready var objective_label: Label = Label.new()
@onready var progress_label: Label = Label.new()
@onready var reward_label: Label = Label.new()
@onready var relationship_label: Label = Label.new()
@onready var hint_label: Label = Label.new()
@onready var close_button: Button = Button.new()
@onready var leads_header: Label = Label.new()
@onready var leads_label: RichTextLabel = RichTextLabel.new()

func _ready() -> void:
	# Fullscreen, lightweight overlay
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 1000
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.7)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	var root_panel := PanelContainer.new()
	root_panel.name = "TaskLogPanel"
	root_panel.anchor_left = 0.22
	root_panel.anchor_right = 0.78
	root_panel.anchor_top = 0.25
	root_panel.anchor_bottom = 0.75
	root_panel.offset_left = 0
	root_panel.offset_right = 0
	root_panel.offset_top = 0
	root_panel.offset_bottom = 0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.09, 0.96)
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.85, 0.75, 0.45, 1.0)
	root_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(root_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	root_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	title_label.text = "Tasks"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8, 1.0))
	vbox.add_child(title_label)

	var header_sep := HSeparator.new()
	vbox.add_child(header_sep)

	var meta_block := VBoxContainer.new()
	meta_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_block.add_theme_constant_override("separation", 4)
	vbox.add_child(meta_block)

	var meta_color := Color(0.9, 0.9, 0.9, 1.0)

	giver_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	giver_label.add_theme_color_override("font_color", meta_color)
	meta_block.add_child(giver_label)

	status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_label.add_theme_color_override("font_color", meta_color)
	meta_block.add_child(status_label)

	depth_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	depth_label.add_theme_color_override("font_color", meta_color)
	meta_block.add_child(depth_label)

	type_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	type_label.add_theme_color_override("font_color", meta_color)
	meta_block.add_child(type_label)

	var sep_top := HSeparator.new()
	vbox.add_child(sep_top)

	vbox.add_spacer(false)

	var objective_header := Label.new()
	objective_header.text = "Objective"
	objective_header.add_theme_font_size_override("font_size", 22)
	objective_header.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8, 1.0))
	vbox.add_child(objective_header)

	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_size_override("font_size", 20)
	objective_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	vbox.add_child(objective_label)

	vbox.add_spacer(false)

	var progress_header := Label.new()
	progress_header.text = "Progress"
	progress_header.add_theme_font_size_override("font_size", 22)
	progress_header.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8, 1.0))
	vbox.add_child(progress_header)

	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_label.add_theme_font_size_override("font_size", 20)
	progress_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	vbox.add_child(progress_label)

	vbox.add_spacer(false)

	var sep_mid := HSeparator.new()
	vbox.add_child(sep_mid)

	var reward_header := Label.new()
	reward_header.text = "Reward"
	reward_header.add_theme_font_size_override("font_size", 22)
	reward_header.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8, 1.0))
	vbox.add_child(reward_header)

	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_label.add_theme_font_size_override("font_size", 20)
	reward_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	vbox.add_child(reward_label)

	vbox.add_spacer(false)

	var relationship_header := Label.new()
	relationship_header.text = "Relationship"
	relationship_header.add_theme_font_size_override("font_size", 22)
	relationship_header.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8, 1.0))
	vbox.add_child(relationship_header)

	relationship_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	relationship_label.add_theme_font_size_override("font_size", 20)
	relationship_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	vbox.add_child(relationship_label)

	vbox.add_spacer(false)

	leads_header.text = "Available Leads"
	leads_header.add_theme_font_size_override("font_size", 22)
	leads_header.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8, 1.0))
	vbox.add_child(leads_header)

	leads_label.bbcode_enabled = false
	leads_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	leads_label.add_theme_font_size_override("font_size", 19)
	leads_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	vbox.add_child(leads_label)

	var sep_bottom := HSeparator.new()
	vbox.add_child(sep_bottom)

	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	vbox.add_child(hint_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(button_row)

	close_button.text = "Close"
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button_row.add_child(close_button)

	close_button.pressed.connect(_on_close_pressed)

	visible = false
	_refresh()

	print("TASKLOG_READY_ROOT =", self, " parent =", get_parent(), " visible =", visible)
	var panel := get_node_or_null("TaskLogPanel")
	if panel and panel is Control:
		var pc := panel as Control
		print("TASKLOG_PANEL_STATE name =", pc.name, " visible =", pc.visible, " rect =", pc.get_global_rect(), " size =", pc.size, " z =", pc.z_index, " modulate =", pc.modulate)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J:
		_on_close_pressed()

func open_and_refresh() -> void:
	_refresh()
	visible = true
	close_button.grab_focus()

func _on_close_pressed() -> void:
	visible = false

func _refresh() -> void:
	if not CampaignManager:
		title_label.text = "No active camp request."
		giver_label.text = ""
		depth_label.text = ""
		type_label.text = ""
		status_label.text = ""
		objective_label.text = ""
		progress_label.text = ""
		reward_label.text = ""
		relationship_label.text = ""
		leads_label.text = "No additional leads right now."
		hint_label.text = "Explore camp and speak to your allies. Higher bonds unlock deeper requests."
		return

	var cm := CampaignManager
	var data: Dictionary = {}
	if cm != null and cm.has_method("get_camp_request_display_data"):
		data = cm.get_camp_request_display_data()

	var has_active: bool = bool(data.get("has_active", false))
	if has_active:
		var title: String = str(data.get("title", "")).strip_edges()
		if title.is_empty():
			title = "Current Camp Request"
		title_label.text = title

		var giver: String = str(data.get("giver", "")).strip_edges()
		giver_label.text = giver if giver.is_empty() else "Giver: %s" % giver

		var depth: String = str(data.get("request_depth", "normal")).strip_edges().to_lower()
		match depth:
			"personal":
				depth_label.text = "Depth: Personal"
			"deep":
				depth_label.text = "Depth: Deep"
			_:
				depth_label.text = "Depth: Normal"

		var type_str: String = str(data.get("type", "")).strip_edges()
		var type_human: String = ""
		match type_str:
			"item_delivery":
				type_human = "Item delivery"
			"talk_to_unit":
				type_human = "Talk to unit"
			_:
				type_human = type_str.capitalize()
		type_label.text = "Type: %s" % type_human if type_human != "" else ""

		var status: String = str(data.get("status", "")).strip_edges().to_lower()
		var status_human: String = ""
		match status:
			"active":
				status_human = "Active"
			"ready_to_turn_in":
				status_human = "Ready to turn in"
			"failed":
				status_human = "Failed"
			_:
				status_human = status.capitalize()
		status_label.text = "Status: %s" % status_human if status_human != "" else ""

		objective_label.text = str(data.get("objective", "")).strip_edges()
		progress_label.text = str(data.get("progress", "")).strip_edges()
		reward_label.text = str(data.get("reward", "")).strip_edges()

		var tier: String = str(data.get("relationship_tier", "")).strip_edges()
		if tier != "":
			relationship_label.text = "Relationship: %s" % tier.capitalize()
		else:
			relationship_label.text = ""

		hint_label.text = ""
	else:
		title_label.text = str(data.get("no_active_message", "No active camp request."))
		giver_label.text = ""
		depth_label.text = ""
		type_label.text = ""
		status_label.text = ""
		objective_label.text = ""
		progress_label.text = ""
		reward_label.text = ""
		relationship_label.text = ""
		hint_label.text = str(data.get("no_active_hint", "Explore camp and speak to your allies. Higher bonds unlock deeper requests."))

	# Available Leads (always evaluated, even when there is no active task)
	var leads_text: String = ""
	if cm != null and cm.has_method("get_available_task_leads"):
		var leads: Array = cm.get_available_task_leads(5)
		var lines: Array[String] = []
		for entry in leads:
			if not (entry is Dictionary):
				continue
			var d: Dictionary = entry
			var t: String = str(d.get("text", "")).strip_edges()
			if t == "":
				continue
			lines.append("- " + t)
		if lines.is_empty():
			leads_text = "No additional leads right now."
		else:
			leads_text = "\n".join(lines)
	else:
		leads_text = "No additional leads right now."

	leads_label.text = leads_text
