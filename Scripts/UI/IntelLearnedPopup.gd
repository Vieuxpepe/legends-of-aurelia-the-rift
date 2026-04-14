extends RefCounted
class_name IntelLearnedPopup

## Dismissible BBCode popup after reading a knowledge scroll (camp or battle).


static func show_at(parent: Node, bbcode: String) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var panel := PopupPanel.new()
	panel.name = "IntelLearnedPopup"
	panel.exclusive = true
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	margin.add_child(vb)
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.selection_enabled = true
	rtl.fit_content = false
	rtl.custom_minimum_size = Vector2(460, 220)
	rtl.scroll_active = true
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rtl.text = bbcode
	vb.add_child(rtl)
	var btn := Button.new()
	btn.text = "Close"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = Vector2(120, 36)
	vb.add_child(btn)
	btn.pressed.connect(func() -> void: panel.hide())
	panel.popup_hide.connect(func() -> void:
		if is_instance_valid(panel):
			panel.queue_free()
	)
	parent.add_child(panel)
	panel.popup_centered(Vector2i(540, 320))
	btn.call_deferred("grab_focus")
