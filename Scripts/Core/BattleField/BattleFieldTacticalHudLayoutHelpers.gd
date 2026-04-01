extends RefCounted

# Full tactical HUD layout pass (viewport resize): rails, bottom panel, unit info, forecast, log, inventory, trade, deploy roster, start battle.

static func apply_tactical_ui_overhaul(field) -> void:
	if not field._tactical_ui_resize_hooked:
		var vp: Viewport = field.get_viewport()
		if vp != null:
			vp.size_changed.connect(field._queue_tactical_ui_overhaul)
		field._tactical_ui_resize_hooked = true
	
	var ui_root: Node = field.get_node_or_null("UI")
	if ui_root == null:
		return
	field._ensure_unit_details_button()
	field._detach_tactical_action_buttons_to_ui_root()
	
	for path in ["UI/BottomBarUI", "UI/ColorRect", "UI/ColorRect2", "UI/FramePortrait", "UI/Panel"]:
		var legacy := field.get_node_or_null(path) as CanvasItem
		if legacy != null:
			legacy.visible = false
	
	var vp_size: Vector2 = field.get_viewport_rect().size
	var hud_scale: float = field.TACTICAL_UI_HUD_SCALE
	var hud_scale_vec := Vector2(hud_scale, hud_scale)
	var bottom_panel_scale: float = hud_scale * field.TACTICAL_UI_BOTTOM_PANEL_SCALE_MULT
	var bottom_panel_scale_vec := Vector2(bottom_panel_scale, bottom_panel_scale)
	var rail_render_w: float = field.TACTICAL_UI_RAIL_WIDTH * hud_scale
	var info_h: float = 258.0
	var bottom_render_h: float = info_h * bottom_panel_scale
	var log_panel_h: float = field.TACTICAL_UI_BOTTOM_HEIGHT * field.TACTICAL_UI_LOG_HEIGHT_RATIO
	var log_render_h: float = log_panel_h * bottom_panel_scale
	var info_w: float = 384.0
	var info_render_w: float = info_w * bottom_panel_scale
	var hud_gap: float = 18.0 * bottom_panel_scale
	var right_x: float = vp_size.x - rail_render_w - field.TACTICAL_UI_MARGIN
	var bottom_y: float = vp_size.y - bottom_render_h - field.TACTICAL_UI_BOTTOM_EDGE_MARGIN
	var log_y: float = bottom_y + (bottom_render_h - log_render_h)
	var log_x: float = field.TACTICAL_UI_MARGIN + info_render_w + hud_gap
	var log_render_w: float = max(372.0 * bottom_panel_scale, right_x - log_x - (hud_gap + (44.0 * bottom_panel_scale)))
	var log_w: float = log_render_w / bottom_panel_scale
	
	var right_rail: Panel = field._ensure_tactical_backdrop("TacticalRightRail")
	var show_deployment_rail: bool = field.current_state == field.pre_battle_state
	var show_battle_hud: bool = not show_deployment_rail
	if right_rail != null:
		right_rail.visible = false
		right_rail.position = Vector2(right_x, field.TACTICAL_UI_MARGIN)
		right_rail.size = Vector2(rail_render_w, vp_size.y - (field.TACTICAL_UI_MARGIN * 2.0))
		field._style_tactical_panel(right_rail, field.TACTICAL_UI_BG, field.TACTICAL_UI_BORDER_MUTED, 1, 12)
	
	var bottom_backdrop: Panel = field._ensure_tactical_backdrop("TacticalBottomBackdrop")
	if bottom_backdrop != null:
		bottom_backdrop.visible = false
	
	var gold_backdrop: Panel = field._ensure_tactical_backdrop("TacticalGoldBackdrop")
	var objective_panel_render_bottom: float = 252.0
	var gold_panel_height: float = 32.0
	var gold_anchor_y: float = vp_size.y - gold_panel_height - field.TACTICAL_UI_BOTTOM_EDGE_MARGIN
	var command_cluster_margin_render: float = 18.0
	var command_button_gap_render: float = 4.0
	var command_button_height: float = 40.0
	var command_cluster_x: float = right_x + command_cluster_margin_render
	var command_cluster_width_render: float = rail_render_w - (command_cluster_margin_render * 2.0)
	var command_button_width: float = (command_cluster_width_render - command_button_gap_render) * 0.5
	var command_buttons_y: float = gold_anchor_y - command_button_height - 10.0
	if gold_backdrop != null:
		gold_backdrop.z_index = 18
		gold_backdrop.scale = Vector2.ONE
		gold_backdrop.position = Vector2(command_cluster_x, gold_anchor_y)
		gold_backdrop.size = Vector2(command_cluster_width_render, gold_panel_height)
		field._style_tactical_panel(gold_backdrop, field.TACTICAL_UI_BG_ALT, field.TACTICAL_UI_BORDER_MUTED, 1, 8)
	
	if field.objective_toggle_btn != null:
		field.objective_toggle_btn.scale = hud_scale_vec
		field.objective_toggle_btn.z_index = 31
		field.objective_toggle_btn.position = Vector2(right_x + rail_render_w - (144.0 * hud_scale) - 10.0, 18.0)
		field.objective_toggle_btn.size = Vector2(144.0, 38.0)
		field.objective_toggle_btn.visible = show_battle_hud
		field.objective_toggle_btn.text = "Hide Goals" if field.is_objective_expanded else "Show Goals"
		field._style_tactical_button(field.objective_toggle_btn, field.objective_toggle_btn.text, false, 18)
	
	if field.objective_panel != null:
		field.objective_panel.scale = hud_scale_vec
		field.objective_panel.z_index = 24
		field.objective_panel.clip_contents = true
		var objective_expanded_pos := Vector2(right_x + 12.0, 18.0 + (38.0 * hud_scale) + 14.0)
		var objective_collapsed_x: float = vp_size.x + 50.0
		field.objective_panel.position = Vector2(objective_expanded_pos.x if field.is_objective_expanded else objective_collapsed_x, objective_expanded_pos.y)
		field.objective_panel.size.x = field.TACTICAL_UI_RAIL_WIDTH - 24.0
		field.objective_panel.pivot_offset = field.objective_panel.size / 2.0
		field.objective_panel.visible = show_battle_hud
		field.objective_panel.set_meta("objective_expanded_x", objective_expanded_pos.x)
		field.objective_panel.set_meta("objective_collapsed_x", objective_collapsed_x)
		field._style_tactical_panel(field.objective_panel, field.TACTICAL_UI_BG_ALT, field.TACTICAL_UI_BORDER, 2, 12)
		objective_panel_render_bottom = field.objective_panel.position.y + (field.objective_panel.size.y * hud_scale) + 18.0
	if field.objective_label != null:
		field.objective_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
		field.objective_label.scroll_active = true
		field._style_tactical_richtext(field.objective_label, 19, 23)
	
	var skip_button := field.get_node_or_null("UI/SkipButton") as Button
	if skip_button != null:
		skip_button.scale = Vector2.ONE
		skip_button.position = Vector2(command_cluster_x, command_buttons_y)
		skip_button.size = Vector2(command_button_width, command_button_height)
		skip_button.visible = show_battle_hud
		field._style_tactical_button(skip_button, "END TURN", true, 20)
		var end_turn_fill: Color = field.TACTICAL_UI_PRIMARY_FILL.lerp(field.TACTICAL_UI_ACCENT, 0.20)
		var end_turn_hover: Color = field.TACTICAL_UI_PRIMARY_HOVER.lerp(field.TACTICAL_UI_ACCENT, 0.28)
		var end_turn_press: Color = field.TACTICAL_UI_PRIMARY_PRESS.lerp(field.TACTICAL_UI_ACCENT, 0.12)
		skip_button.add_theme_stylebox_override("normal", field._make_tactical_panel_style(end_turn_fill, field.TACTICAL_UI_ACCENT, 3, 10))
		skip_button.add_theme_stylebox_override("hover", field._make_tactical_panel_style(end_turn_hover, field.TACTICAL_UI_ACCENT, 3, 10))
		skip_button.add_theme_stylebox_override("pressed", field._make_tactical_panel_style(end_turn_press, field.TACTICAL_UI_ACCENT, 3, 10))
		skip_button.add_theme_stylebox_override("focus", field._make_tactical_panel_style(end_turn_hover, field.TACTICAL_UI_ACCENT_SOFT, 3, 10))
	
	if field.convoy_button != null:
		field.convoy_button.scale = Vector2.ONE
		field.convoy_button.position = Vector2(
			command_cluster_x + command_button_width + command_button_gap_render,
			command_buttons_y
		)
		field.convoy_button.size = Vector2(command_button_width, command_button_height)
		field.convoy_button.visible = show_battle_hud
		field._style_tactical_button(field.convoy_button, "CONVOY", false, 20)
	
	if field.gold_label != null:
		field.gold_label.z_index = 19
		field.gold_label.scale = Vector2.ONE
		field.gold_label.position = Vector2(command_cluster_x + 14.0, gold_anchor_y + 2.0)
		field.gold_label.size = Vector2(command_cluster_width_render - 28.0, 28.0)
		field.gold_label.visible = show_battle_hud
		field.gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		field._style_tactical_label(field.gold_label, field.TACTICAL_UI_ACCENT, 20, 4)
	if gold_backdrop != null:
		gold_backdrop.visible = show_battle_hud
	
	if field.unit_info_panel != null:
		field.unit_info_panel.scale = bottom_panel_scale_vec
		field.unit_info_panel.position = Vector2(field.TACTICAL_UI_MARGIN, bottom_y)
		field.unit_info_panel.size = Vector2(info_w, info_h)
		field.unit_info_panel.clip_contents = true
		field._style_tactical_panel(field.unit_info_panel, field.TACTICAL_UI_BG_ALT, field.TACTICAL_UI_BORDER, 2, 12)
		var portrait_frame := field.unit_info_panel.get_node_or_null("PortraitFrame") as Panel
		if portrait_frame == null:
			portrait_frame = Panel.new()
			portrait_frame.name = "PortraitFrame"
			portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			field.unit_info_panel.add_child(portrait_frame)
			field.unit_info_panel.move_child(portrait_frame, 0)
		portrait_frame.z_index = 0
		portrait_frame.position = Vector2(240, 18)
		portrait_frame.size = Vector2(122, 156)
		field._style_tactical_panel(portrait_frame, field.TACTICAL_UI_BG_SOFT, field.TACTICAL_UI_BORDER_MUTED, 1, 8)
	
	if field.unit_name_label != null:
		field.unit_name_label.position = Vector2(18, 16)
		field.unit_name_label.size = Vector2(208, 30)
		field.unit_name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		field._style_tactical_label(field.unit_name_label, field.TACTICAL_UI_ACCENT, 24, 4)
	if field.unit_hp_label != null:
		field.unit_hp_label.position = Vector2(18, 35)
		field.unit_hp_label.size = Vector2(208, 16)
		field.unit_hp_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		field._style_tactical_label(field.unit_hp_label, field.TACTICAL_UI_ACCENT_SOFT, 14, 3)
		var header_divider := field.unit_info_panel.get_node_or_null("HeaderDivider") as Panel
		if header_divider == null:
			header_divider = Panel.new()
			header_divider.name = "HeaderDivider"
			header_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			field.unit_info_panel.add_child(header_divider)
		header_divider.position = Vector2(18, 53)
		header_divider.size = Vector2(208, 3)
		header_divider.z_index = 1
		field._style_tactical_panel(
			header_divider,
			Color(0.19, 0.16, 0.10, 0.92),
			Color(0.55, 0.48, 0.26, 0.55),
			1,
			4
		)
	if field.unit_stats_label != null:
		field.unit_stats_label.position = Vector2(16, 142)
		field.unit_stats_label.size = Vector2(210, 24)
		field.unit_stats_label.scroll_active = false
		field._style_tactical_richtext(field.unit_stats_label, 11, 12)
	field._ensure_unit_info_primary_widgets()
	field._layout_unit_info_primary_widgets()
	field._ensure_unit_info_stat_widgets()
	field._layout_unit_info_stat_widgets()
	if field.unit_portrait != null:
		field.unit_portrait.z_index = 1
		field.unit_portrait.position = Vector2(244, 22)
		field.unit_portrait.size = Vector2(114, 148)
		field.unit_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		field.unit_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if field.open_inv_button != null:
		field.open_inv_button.top_level = false
		field.open_inv_button.scale = bottom_panel_scale_vec
		field.open_inv_button.position = field.unit_info_panel.position + (Vector2(16, 228) * bottom_panel_scale)
		field.open_inv_button.size = Vector2(92, 28)
		field.open_inv_button.z_index = 20
		field._style_tactical_button(field.open_inv_button, "ITEMS", false, 18)
	if field.support_btn != null:
		field.support_btn.top_level = false
		field.support_btn.scale = bottom_panel_scale_vec
		field.support_btn.position = field.unit_info_panel.position + (Vector2(112, 228) * bottom_panel_scale)
		field.support_btn.size = Vector2(104, 28)
		field.support_btn.z_index = 20
		field._style_tactical_button(field.support_btn, "SUPPORTS", false, 16)
	if field.unit_details_button != null:
		field.unit_details_button.top_level = false
		field.unit_details_button.scale = bottom_panel_scale_vec
		field.unit_details_button.position = field.unit_info_panel.position + (Vector2(238, 228) * bottom_panel_scale)
		field.unit_details_button.size = Vector2(122, 28)
		field.unit_details_button.z_index = 20
		field.unit_details_button.visible = true
		field._style_tactical_button(field.unit_details_button, "UNIT INFO", false, 16)
	
	var battle_log_panel: Panel = null
	if field.battle_log != null:
		battle_log_panel = field.battle_log.get_parent() as Panel
	if battle_log_panel != null:
		var field_log_toggle_gap: float = 8.0 * bottom_panel_scale
		var field_log_toggle_size := Vector2(132.0, 28.0)
		var field_log_toggle_render_size: Vector2 = field_log_toggle_size * bottom_panel_scale
		var field_log_expanded_button_pos := Vector2(
			log_x + log_render_w - field_log_toggle_render_size.x - (12.0 * bottom_panel_scale),
			log_y - field_log_toggle_render_size.y - field_log_toggle_gap
		)
		var field_log_collapsed_panel_y: float = vp_size.y + (6.0 * bottom_panel_scale)
		var field_log_collapsed_button_y: float = field_log_collapsed_panel_y - field_log_toggle_render_size.y - field_log_toggle_gap
		battle_log_panel.scale = bottom_panel_scale_vec
		battle_log_panel.position = Vector2(log_x, log_y)
		battle_log_panel.size = Vector2(log_w, log_panel_h)
		battle_log_panel.set_meta("field_log_expanded_y", log_y)
		battle_log_panel.set_meta("field_log_collapsed_y", field_log_collapsed_panel_y)
		field._style_tactical_panel(battle_log_panel, Color(0.12, 0.11, 0.09, 0.88), Color(0.46, 0.40, 0.28, 0.44), 1, 10)
		var legacy_log_fill := battle_log_panel.get_node_or_null("ColorRect") as ColorRect
		if legacy_log_fill != null:
			legacy_log_fill.visible = false
		var log_header: Label = field._ensure_tactical_header(battle_log_panel, "HeaderLabel", "Field Log")
		if log_header != null:
			field._style_tactical_label(log_header, field.TACTICAL_UI_TEXT_MUTED, 13, 3)
		var field_log_toggle: Button = field._ensure_field_log_toggle_button()
		if field_log_toggle != null:
			field_log_toggle.scale = bottom_panel_scale_vec
			field_log_toggle.size = field_log_toggle_size
			field_log_toggle.position = field_log_expanded_button_pos
			field_log_toggle.z_index = 22
			field_log_toggle.set_meta("field_log_expanded_y", field_log_expanded_button_pos.y)
			field_log_toggle.set_meta("field_log_collapsed_y", field_log_collapsed_button_y)
			field_log_toggle.custom_minimum_size = field_log_toggle_size
			field._set_field_log_toggle_button_text()
			field._apply_field_log_visibility(false)
	elif field.field_log_toggle_btn != null and is_instance_valid(field.field_log_toggle_btn):
		field.field_log_toggle_btn.visible = false
	if field.battle_log != null:
		field.battle_log.position = Vector2(16, 36)
		field.battle_log.size = Vector2(log_w - 32.0, log_panel_h - 50.0)
		field.battle_log.scroll_active = true
		field._style_tactical_richtext(field.battle_log, 13, 15)
	
	if field.forecast_panel != null:
		var forecast_size := Vector2(540.0, 360.0)
		field.forecast_panel.position = Vector2(max(260.0, right_x - forecast_size.x - 20.0), max(120.0, bottom_y - forecast_size.y - 18.0))
		field.forecast_panel.size = forecast_size
		field.forecast_panel.clip_contents = false
		field._style_tactical_panel(field.forecast_panel, field.TACTICAL_UI_BG_ALT, field.TACTICAL_UI_BORDER, 2, 12)
		var forecast_left_tint := field.forecast_panel.get_node_or_null("ForecastLeftTint") as ColorRect
		if forecast_left_tint == null:
			forecast_left_tint = ColorRect.new()
			forecast_left_tint.name = "ForecastLeftTint"
			forecast_left_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			field.forecast_panel.add_child(forecast_left_tint)
		forecast_left_tint.position = Vector2(14.0, 16.0)
		forecast_left_tint.size = Vector2(214.0, 236.0)
		forecast_left_tint.color = Color(0.78, 0.30, 0.18, 0.08)
		var forecast_right_tint := field.forecast_panel.get_node_or_null("ForecastRightTint") as ColorRect
		if forecast_right_tint == null:
			forecast_right_tint = ColorRect.new()
			forecast_right_tint.name = "ForecastRightTint"
			forecast_right_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			field.forecast_panel.add_child(forecast_right_tint)
		forecast_right_tint.position = Vector2(forecast_size.x - 228.0, 16.0)
		forecast_right_tint.size = Vector2(214.0, 236.0)
		forecast_right_tint.color = Color(0.18, 0.35, 0.76, 0.08)
		field.forecast_panel.move_child(forecast_left_tint, 0)
		field.forecast_panel.move_child(forecast_right_tint, 1)
		var center_line_top := field.forecast_panel.get_node_or_null("CenterLineTop") as ColorRect
		if center_line_top == null:
			center_line_top = ColorRect.new()
			center_line_top.name = "CenterLineTop"
			center_line_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
			field.forecast_panel.add_child(center_line_top)
		center_line_top.position = Vector2((forecast_size.x * 0.5) - 1.0, 24.0)
		center_line_top.size = Vector2(2.0, 92.0)
		center_line_top.color = Color(0.73, 0.64, 0.34, 0.68)
		var center_line_bottom := field.forecast_panel.get_node_or_null("CenterLineBottom") as ColorRect
		if center_line_bottom == null:
			center_line_bottom = ColorRect.new()
			center_line_bottom.name = "CenterLineBottom"
			center_line_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
			field.forecast_panel.add_child(center_line_bottom)
		center_line_bottom.position = Vector2((forecast_size.x * 0.5) - 1.0, 164.0)
		center_line_bottom.size = Vector2(2.0, 94.0)
		center_line_bottom.color = Color(0.73, 0.64, 0.34, 0.56)
		var center_badge := field.forecast_panel.get_node_or_null("CenterBadge") as Label
		if center_badge == null:
			center_badge = Label.new()
			center_badge.name = "CenterBadge"
			center_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			field.forecast_panel.add_child(center_badge)
		center_badge.text = "VS"
		center_badge.position = Vector2((forecast_size.x * 0.5) - 24.0, 126.0)
		center_badge.size = Vector2(48.0, 26.0)
		center_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		field._style_tactical_label(center_badge, Color(1.0, 0.90, 0.58), 18, 3)
		field._ensure_forecast_support_labels()
		field._ensure_forecast_hp_bars()
		field._ensure_forecast_weapon_badges()
		field._ensure_forecast_weapon_pair_frames()
		field._ensure_forecast_weapon_icons()
		var atk_weapon_pair_frame := field.forecast_panel.get_node_or_null("AtkWeaponPairFrame") as Panel
		var def_weapon_pair_frame := field.forecast_panel.get_node_or_null("DefWeaponPairFrame") as Panel
		var atk_weapon_badge_panel := field.forecast_panel.get_node_or_null("AtkWeaponBadgePanel") as Panel
		var def_weapon_badge_panel := field.forecast_panel.get_node_or_null("DefWeaponBadgePanel") as Panel
		var atk_weapon_icon_panel := field.forecast_panel.get_node_or_null("AtkWeaponIconPanel") as Panel
		var def_weapon_icon_panel := field.forecast_panel.get_node_or_null("DefWeaponIconPanel") as Panel
		var left_col_x := 24.0
		var right_col_x := forecast_size.x - 214.0
		var col_w := 190.0
		var stat_y := {
			"name": 18.0,
			"hp": 54.0,
			"bar": 78.0,
			"hit": 92.0,
			"dmg": 126.0,
			"crit": 160.0,
			"support": 194.0,
			"weapon": 222.0,
			"footer": 250.0,
			"instruction": 266.0,
			"reaction": 290.0,
			"buttons": 306.0,
		}
		var name_labels: Array = [field.forecast_atk_name, field.forecast_def_name]
		var hp_labels: Array = [field.forecast_atk_hp, field.forecast_def_hp]
		var hit_labels: Array = [field.forecast_atk_hit, field.forecast_def_hit]
		var dmg_labels: Array = [field.forecast_atk_dmg, field.forecast_def_dmg]
		var crit_labels: Array = [field.forecast_atk_crit, field.forecast_def_crit]
		var support_labels: Array = [field.forecast_atk_support_label, field.forecast_def_support_label]
		var weapon_labels: Array = [field.forecast_atk_weapon, field.forecast_def_weapon]
		var adv_labels: Array = [field.forecast_atk_adv, field.forecast_def_adv]
		var double_labels: Array = [field.forecast_atk_double, field.forecast_def_double]
		var col_positions: Array[float] = [left_col_x, right_col_x]
		for idx in range(2):
			var base_x: float = col_positions[idx]
			var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT if idx == 0 else HORIZONTAL_ALIGNMENT_RIGHT
			var name_lbl := name_labels[idx] as Label
			if name_lbl != null:
				name_lbl.position = Vector2(base_x, stat_y["name"])
				name_lbl.size = Vector2(col_w, 28)
				name_lbl.horizontal_alignment = align
				name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
				name_lbl.clip_text = true
				name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			var hp_lbl := hp_labels[idx] as Label
			if hp_lbl != null:
				hp_lbl.position = Vector2(base_x, stat_y["hp"])
				hp_lbl.size = Vector2(col_w, 24)
				hp_lbl.horizontal_alignment = align
			var hp_bar: ProgressBar = field.forecast_atk_hp_bar if idx == 0 else field.forecast_def_hp_bar
			if hp_bar != null:
				hp_bar.position = Vector2(base_x, stat_y["bar"])
				hp_bar.size = Vector2(col_w, 10)
			var hit_lbl := hit_labels[idx] as Label
			if hit_lbl != null:
				hit_lbl.position = Vector2(base_x, stat_y["hit"])
				hit_lbl.size = Vector2(col_w, 22)
				hit_lbl.horizontal_alignment = align
			var dmg_lbl := dmg_labels[idx] as Label
			if dmg_lbl != null:
				dmg_lbl.position = Vector2(base_x, stat_y["dmg"])
				dmg_lbl.size = Vector2(col_w, 22)
				dmg_lbl.horizontal_alignment = align
			var crit_lbl := crit_labels[idx] as Label
			if crit_lbl != null:
				crit_lbl.position = Vector2(base_x, stat_y["crit"])
				crit_lbl.size = Vector2(col_w, 22)
				crit_lbl.horizontal_alignment = align
			var support_lbl := support_labels[idx] as Label
			if support_lbl != null:
				support_lbl.position = Vector2(base_x, stat_y["support"])
				support_lbl.size = Vector2(col_w, 22)
				support_lbl.horizontal_alignment = align
			var weapon_lbl := weapon_labels[idx] as Label
			if weapon_lbl != null:
				if idx == 0:
					weapon_lbl.position = Vector2(base_x + 96.0, stat_y["weapon"])
				else:
					weapon_lbl.position = Vector2(base_x, stat_y["weapon"])
				weapon_lbl.size = Vector2(col_w - 100.0, 22)
				weapon_lbl.horizontal_alignment = align
				weapon_lbl.clip_text = true
				weapon_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			var adv_lbl := adv_labels[idx] as Label
			if adv_lbl != null:
				adv_lbl.position = Vector2(base_x, stat_y["footer"])
				adv_lbl.size = Vector2(110.0, 22)
				adv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if idx == 0 else HORIZONTAL_ALIGNMENT_RIGHT
			var double_lbl := double_labels[idx] as Label
			if double_lbl != null:
				var double_x := base_x + 118.0 if idx == 0 else base_x + 118.0
				double_lbl.position = Vector2(double_x, stat_y["dmg"])
				double_lbl.size = Vector2(60.0, 22)
				double_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if atk_weapon_badge_panel != null:
			atk_weapon_badge_panel.position = Vector2(left_col_x, stat_y["weapon"] - 4.0)
			atk_weapon_badge_panel.size = Vector2(56.0, 26.0)
			var atk_badge_label := atk_weapon_badge_panel.get_node_or_null("Text") as Label
			if atk_badge_label != null:
				atk_badge_label.size = atk_weapon_badge_panel.size
		if atk_weapon_pair_frame != null:
			atk_weapon_pair_frame.position = Vector2(left_col_x - 6.0, stat_y["weapon"] - 6.0)
			atk_weapon_pair_frame.size = Vector2(96.0, 30.0)
			var atk_bevel_top := atk_weapon_pair_frame.get_node_or_null("BevelTop") as ColorRect
			if atk_bevel_top != null:
				atk_bevel_top.position = Vector2(4, 3)
				atk_bevel_top.size = Vector2(atk_weapon_pair_frame.size.x - 8.0, 2.0)
			var atk_bevel_bottom := atk_weapon_pair_frame.get_node_or_null("BevelBottom") as ColorRect
			if atk_bevel_bottom != null:
				atk_bevel_bottom.position = Vector2(4, atk_weapon_pair_frame.size.y - 5.0)
				atk_bevel_bottom.size = Vector2(atk_weapon_pair_frame.size.x - 8.0, 2.0)
		if atk_weapon_icon_panel != null:
			atk_weapon_icon_panel.position = Vector2(left_col_x + 62.0, stat_y["weapon"] - 4.0)
			atk_weapon_icon_panel.size = Vector2(26.0, 26.0)
			var atk_glow := atk_weapon_icon_panel.get_node_or_null("Glow") as Panel
			if atk_glow != null:
				atk_glow.position = Vector2(2, 2)
				atk_glow.size = Vector2(22, 22)
		if def_weapon_badge_panel != null:
			def_weapon_badge_panel.position = Vector2(right_col_x + col_w - 56.0, stat_y["weapon"] - 4.0)
			def_weapon_badge_panel.size = Vector2(56.0, 26.0)
			var def_badge_label := def_weapon_badge_panel.get_node_or_null("Text") as Label
			if def_badge_label != null:
				def_badge_label.size = def_weapon_badge_panel.size
		if def_weapon_pair_frame != null:
			def_weapon_pair_frame.position = Vector2(right_col_x + col_w - 90.0, stat_y["weapon"] - 6.0)
			def_weapon_pair_frame.size = Vector2(96.0, 30.0)
			var def_bevel_top := def_weapon_pair_frame.get_node_or_null("BevelTop") as ColorRect
			if def_bevel_top != null:
				def_bevel_top.position = Vector2(4, 3)
				def_bevel_top.size = Vector2(def_weapon_pair_frame.size.x - 8.0, 2.0)
			var def_bevel_bottom := def_weapon_pair_frame.get_node_or_null("BevelBottom") as ColorRect
			if def_bevel_bottom != null:
				def_bevel_bottom.position = Vector2(4, def_weapon_pair_frame.size.y - 5.0)
				def_bevel_bottom.size = Vector2(def_weapon_pair_frame.size.x - 8.0, 2.0)
		if def_weapon_icon_panel != null:
			def_weapon_icon_panel.position = Vector2(right_col_x + col_w - 88.0, stat_y["weapon"] - 4.0)
			def_weapon_icon_panel.size = Vector2(26.0, 26.0)
			var def_glow := def_weapon_icon_panel.get_node_or_null("Glow") as Panel
			if def_glow != null:
				def_glow.position = Vector2(2, 2)
				def_glow.size = Vector2(22, 22)
	for lbl in [field.forecast_atk_name, field.forecast_atk_hp, field.forecast_atk_dmg, field.forecast_atk_hit, field.forecast_atk_crit, field.forecast_atk_weapon, field.forecast_atk_adv, field.forecast_atk_double, field.forecast_def_name, field.forecast_def_hp, field.forecast_def_dmg, field.forecast_def_hit, field.forecast_def_crit, field.forecast_def_weapon, field.forecast_def_adv, field.forecast_def_double]:
		if lbl is Label:
			field._style_tactical_label(lbl as Label, field.TACTICAL_UI_TEXT, 23, 3)
	for name_lbl in [field.forecast_atk_name, field.forecast_def_name]:
		if name_lbl is Label:
			field._style_tactical_label(name_lbl as Label, Color(1.0, 0.90, 0.54), 24, 4)
	if field.forecast_atk_name != null:
		field.forecast_atk_name.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52))
	if field.forecast_def_name != null:
		field.forecast_def_name.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	for hp_lbl in [field.forecast_atk_hp, field.forecast_def_hp]:
		if hp_lbl is Label:
			field._style_tactical_label(hp_lbl as Label, Color(0.90, 0.96, 0.92), 21, 3)
	for hit_lbl in [field.forecast_atk_hit, field.forecast_def_hit]:
		if hit_lbl is Label:
			field._style_tactical_label(hit_lbl as Label, Color(0.57, 0.94, 1.0), 20, 3)
	if field.forecast_atk_dmg != null:
		field._style_tactical_label(field.forecast_atk_dmg, Color(1.0, 0.72, 0.49), 20, 3)
	if field.forecast_def_dmg != null:
		field._style_tactical_label(field.forecast_def_dmg, Color(0.67, 0.87, 1.0), 20, 3)
	for crit_lbl in [field.forecast_atk_crit, field.forecast_def_crit]:
		if crit_lbl is Label:
			field._style_tactical_label(crit_lbl as Label, Color(1.0, 0.84, 0.38), 20, 3)
	for weapon_lbl in [field.forecast_atk_weapon, field.forecast_def_weapon]:
		if weapon_lbl is Label:
			field._style_tactical_label(weapon_lbl as Label, Color(0.93, 0.91, 0.80), 20, 3)
	if field.forecast_atk_weapon != null:
		field.forecast_atk_weapon.add_theme_color_override("font_color", Color(1.0, 0.84, 0.68))
	if field.forecast_def_weapon != null:
		field.forecast_def_weapon.add_theme_color_override("font_color", Color(0.78, 0.90, 1.0))
	for adv_lbl in [field.forecast_atk_adv, field.forecast_def_adv]:
		if adv_lbl is Label:
			field._style_tactical_label(adv_lbl as Label, Color(0.76, 0.96, 0.62), 19, 3)
	for dbl in [field.forecast_atk_double, field.forecast_def_double]:
		if dbl is Label:
			field._style_tactical_label(dbl as Label, Color(0.48, 0.90, 1.0), 23, 3)
	var forecast_confirm := field.get_node_or_null("UI/CombatForecastPanel/ConfirmButton") as Button
	var forecast_cancel := field.get_node_or_null("UI/CombatForecastPanel/CancelButton") as Button
	if forecast_confirm != null:
		field._style_tactical_button(forecast_confirm, "ATTACK", true, 22)
	if forecast_cancel != null:
		field._style_tactical_button(forecast_cancel, "BACK", false, 22)
	if field.forecast_talk_btn != null:
		field._style_tactical_button(field.forecast_talk_btn, "TALK", false, 20)
	if field.forecast_ability_btn != null:
		field._style_tactical_button(field.forecast_ability_btn, "ABILITY", false, 20)
	if field.forecast_instruction_label != null:
		field.forecast_instruction_label.position = Vector2(24, 262)
		field.forecast_instruction_label.size = Vector2(492, 20)
		field.forecast_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		field.forecast_instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		field._style_tactical_label(field.forecast_instruction_label, Color(0.84, 0.84, 0.90), 14, 2)
	if field.forecast_reaction_label != null:
		field.forecast_reaction_label.position = Vector2(24, 284)
		field.forecast_reaction_label.size = Vector2(492, 18)
		field.forecast_reaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		field.forecast_reaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		field._style_tactical_label(field.forecast_reaction_label, Color(0.96, 0.85, 0.57), 13, 2)
	if forecast_confirm != null:
		forecast_confirm.position = Vector2(110, 306)
		forecast_confirm.size = Vector2(158, 42)
	if forecast_cancel != null:
		forecast_cancel.position = Vector2(282, 306)
		forecast_cancel.size = Vector2(158, 42)
	if field.forecast_talk_btn != null and field.forecast_ability_btn != null:
		field.forecast_talk_btn.position = Vector2(24, 372)
		field.forecast_talk_btn.size = Vector2(96, 42)
		field.forecast_ability_btn.position = Vector2(126, 372)
		field.forecast_ability_btn.size = Vector2(96, 42)
	elif field.forecast_talk_btn != null:
		field.forecast_talk_btn.position = Vector2(24, 372)
		field.forecast_talk_btn.size = Vector2(96, 42)
	elif field.forecast_ability_btn != null:
		field.forecast_ability_btn.position = Vector2(24, 372)
		field.forecast_ability_btn.size = Vector2(96, 42)
	
	if field.inventory_panel != null:
		field._style_tactical_panel(field.inventory_panel, field.TACTICAL_UI_BG_ALT, field.TACTICAL_UI_BORDER, 2, 12)
		var inv_item_info := field.inventory_panel.get_node_or_null("Panel") as Panel
		field._style_inventory_item_info_backdrop(inv_item_info)
	if field.inv_desc_label != null:
		field._style_tactical_richtext(field.inv_desc_label, 21, 26)
		field.inv_desc_label.add_theme_constant_override("line_separation", 7)
		field.inv_desc_label.scroll_active = false
		field.inv_desc_label.z_index = 2
	field._style_tactical_button(field.equip_button, "EQUIP", false, 18)
	field._style_tactical_button(field.use_button, "USE", false, 18)
	var inv_close := field.get_node_or_null("UI/InventoryPanel/CloseButton") as Button
	if inv_close != null:
		field._style_tactical_button(inv_close, "CLOSE", false, 18)
	var inv_item_list := field.get_node_or_null("UI/InventoryPanel/ItemList") as ItemList
	field._style_tactical_item_list(inv_item_list)
	field._apply_inventory_panel_item_list_extra_margins(inv_item_list)
	field._style_tactical_item_list(field.get_node_or_null("UI/RosterPanel/RosterList") as ItemList)
	field._style_tactical_item_list(field.loot_item_list)
	
	if field.loot_window != null:
		field._style_tactical_panel(field.loot_window, field.TACTICAL_UI_BG_ALT, field.TACTICAL_UI_BORDER, 2, 12)
		field._ensure_loot_item_info_ui()
	if field.loot_desc_label != null:
		field._style_tactical_richtext(field.loot_desc_label, 21, 26)
		field.loot_desc_label.add_theme_constant_override("line_separation", 7)
	if field.close_loot_button != null:
		field._style_tactical_button(field.close_loot_button, "CLAIM ALL", true, 20)
	
	if field.support_tracker_panel != null:
		field._style_tactical_panel(field.support_tracker_panel, field.TACTICAL_UI_BG_ALT, field.TACTICAL_UI_BORDER, 2, 12)
	if field.support_list_text != null:
		field._style_tactical_richtext(field.support_list_text, 18, 20)
	if field.close_support_btn != null:
		field._style_tactical_button(field.close_support_btn, "CLOSE", false, 18)
	
	if field.trade_popup != null:
		field._style_tactical_panel(field.trade_popup, field.TACTICAL_UI_BG_ALT, field.TACTICAL_UI_BORDER, 2, 12)
	if field.trade_popup_btn != null:
		field._style_tactical_button(field.trade_popup_btn, "TRADE", false, 18)
	if field.popup_talk_btn != null:
		field._style_tactical_button(field.popup_talk_btn, "SUPPORT TALK", false, 16)
	
	if field.trade_window != null:
		field._style_tactical_panel(field.trade_window, field.TACTICAL_UI_BG_ALT, field.TACTICAL_UI_BORDER, 2, 12)
	for lbl in [field.trade_left_name, field.trade_right_name]:
		if lbl is Label:
			field._style_tactical_label(lbl as Label, field.TACTICAL_UI_ACCENT, 20, 3)
	if field.trade_close_btn != null:
		field._style_tactical_button(field.trade_close_btn, "CLOSE", false, 18)
	field._style_tactical_item_list(field.trade_left_list)
	field._style_tactical_item_list(field.trade_right_list)
	
	var talk_panel_w: float = clampf(vp_size.x - 56.0, 560.0, 980.0)
	var talk_panel_h: float = 268.0
	var talk_panel_x: float = (vp_size.x - talk_panel_w) * 0.5
	var talk_panel_y: float = maxf(36.0, vp_size.y - talk_panel_h - 42.0)
	var talk_portrait_size := Vector2(150.0, 184.0)
	var talk_portrait_margin_x: float = 16.0
	var talk_portrait_margin_y: float = 16.0
	var talk_center_left: float = talk_portrait_margin_x + talk_portrait_size.x + 18.0
	var talk_center_right_margin: float = talk_portrait_margin_x + talk_portrait_size.x + 18.0
	var talk_footer_h: float = 46.0
	var talk_text_bottom_margin: float = 14.0
	if field.talk_panel != null:
		field.talk_panel.scale = Vector2.ONE
		field.talk_panel.position = Vector2(talk_panel_x, talk_panel_y)
		field.talk_panel.size = Vector2(talk_panel_w, talk_panel_h)
		field.talk_panel.clip_contents = true
		field._style_tactical_panel(field.talk_panel, field.TACTICAL_UI_BG_ALT, field.TACTICAL_UI_BORDER, 2, 12)
	if field.talk_left_portrait != null:
		field.talk_left_portrait.position = Vector2(talk_portrait_margin_x, talk_portrait_margin_y)
		field.talk_left_portrait.size = talk_portrait_size
		field.talk_left_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		field.talk_left_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if field.talk_right_portrait != null and field.talk_panel != null:
		field.talk_right_portrait.position = Vector2(field.talk_panel.size.x - talk_portrait_margin_x - talk_portrait_size.x, talk_portrait_margin_y)
		field.talk_right_portrait.size = talk_portrait_size
		field.talk_right_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		field.talk_right_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if field.talk_name != null:
		if field.talk_panel != null:
			field.talk_name.position = Vector2(talk_center_left, 16.0)
			field.talk_name.size = Vector2(field.talk_panel.size.x - talk_center_left - talk_center_right_margin, 30.0)
			field.talk_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			field.talk_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		field._style_tactical_label(field.talk_name, field.TACTICAL_UI_ACCENT, 22, 4)
	if field.talk_text != null:
		if field.talk_panel != null:
			field.talk_text.position = Vector2(talk_center_left, 54.0)
			field.talk_text.size = Vector2(
				field.talk_panel.size.x - talk_center_left - talk_center_right_margin,
				field.talk_panel.size.y - 54.0 - talk_footer_h - talk_text_bottom_margin
			)
			field.talk_text.scroll_active = false
		field._style_tactical_richtext(field.talk_text, 19, 21)
	if field.talk_next_btn != null:
		if field.talk_panel != null:
			field.talk_next_btn.position = Vector2(field.talk_panel.size.x - 16.0 - 152.0, field.talk_panel.size.y - 16.0 - 38.0)
			field.talk_next_btn.size = Vector2(152.0, 38.0)
			field.talk_next_btn.z_index = 2
		field._style_tactical_button(field.talk_next_btn, "CONTINUE", true, 18)
	
	if field.level_up_panel != null:
		field._style_tactical_panel(field.level_up_panel, field.TACTICAL_UI_BG_ALT, field.TACTICAL_UI_BORDER, 2, 14)
	if field.level_up_title != null:
		field._style_tactical_label(field.level_up_title, field.TACTICAL_UI_ACCENT, 30, 5)
	if field.level_up_stats != null:
		field._style_tactical_richtext(field.level_up_stats, 18, 20)
	
	if field.game_over_panel != null:
		field._style_tactical_panel(field.game_over_panel, Color(0.06, 0.05, 0.04, 0.96), field.TACTICAL_UI_BORDER, 3, 16)
	if field.result_label != null:
		field._style_tactical_label(field.result_label, field.TACTICAL_UI_ACCENT, 66, 6)
	field._style_tactical_button(field.restart_button, field.restart_button.text if field.restart_button != null else "PLAY AGAIN", true, 24)
	field._style_tactical_button(field.continue_button, field.continue_button.text if field.continue_button != null else "CONTINUE", false, 24)
	
	var roster_panel := field.get_node_or_null("UI/RosterPanel") as Panel
	var count_text := field.get_node_or_null("UI/RosterPanel/DeployCountLabel") as Label
	var roster_items := field.get_node_or_null("UI/RosterPanel/RosterList") as ItemList
	var build_button := field.get_node_or_null("UI/RosterPanel/BuildButton") as Button
	var deploy_bond_panel: Panel = field.get_node_or_null("UI/RosterPanel/DeployBondPanel") as Panel
	var deploy_bond_block_h: float = field.TACTICAL_DEPLOY_ROSTER_BONDS_H
	if roster_panel != null and show_deployment_rail and roster_panel.get_meta("deploy_bond_hidden", false):
		deploy_bond_block_h = 0.0
	if roster_panel != null:
		if show_deployment_rail:
			if field.deploy_roster_toggle_tween != null:
				field.deploy_roster_toggle_tween.kill()
				field.deploy_roster_toggle_tween = null
		roster_panel.visible = show_deployment_rail
		roster_panel.scale = hud_scale_vec
		# Pre-battle: objective HUD is hidden â€” don't force the 252px floor; use full-height column.
		var roster_top: float = (field.TACTICAL_UI_MARGIN if show_deployment_rail else maxf(252.0, objective_panel_render_bottom))
		var roster_w: float = field.TACTICAL_DEPLOY_ROSTER_PANEL_WIDTH if show_deployment_rail else (field.TACTICAL_UI_RAIL_WIDTH - 24.0)
		var roster_bottom_px: float = (108.0 * hud_scale) if not show_deployment_rail else (field.TACTICAL_DEPLOY_ROSTER_VIEWPORT_BOTTOM_RESERVE * hud_scale)
		var roster_base_h: float = max(180.0, (vp_size.y - roster_top - roster_bottom_px) / hud_scale)
		if show_deployment_rail:
			var min_deploy_h: float = 124.0 + deploy_bond_block_h + field.TACTICAL_DEPLOY_ROSTER_MIN_LIST_H
			roster_base_h = maxf(roster_base_h, min_deploy_h)
		roster_panel.size = Vector2(roster_w, roster_base_h)
		var roster_visual_w: float = roster_w * hud_scale
		var roster_left: float = clampf(right_x + 12.0, 8.0, maxf(8.0, vp_size.x - roster_visual_w - 8.0))
		roster_panel.position.y = roster_top
		roster_panel.set_meta("deploy_rail_expanded_x", roster_left)
		roster_panel.set_meta("deploy_rail_collapsed_x", vp_size.x + 24.0)
		field._style_tactical_panel(roster_panel, field.TACTICAL_UI_BG_ALT, field.TACTICAL_UI_BORDER, 2, 12)
		# Pre-battle: let the player hide the deploy column for an unobstructed map view (slide + tween, same feel as field log).
		var d_toggle: Button = field._ensure_deploy_roster_toggle_button()
		if d_toggle != null and show_deployment_rail:
			d_toggle.visible = true
			d_toggle.scale = hud_scale_vec
			d_toggle.z_index = 28
			var tog_w: float = 132.0 * hud_scale
			var tog_h: float = 38.0 * hud_scale
			d_toggle.size = Vector2(tog_w, tog_h)
			d_toggle.position.y = roster_top
			d_toggle.set_meta("deploy_rail_btn_expanded_x", maxf(8.0, roster_left - tog_w - 10.0))
			d_toggle.set_meta("deploy_rail_btn_collapsed_x", vp_size.x - tog_w - field.TACTICAL_UI_MARGIN)
			field._apply_deployment_rail_visibility(false)
		elif d_toggle != null:
			if field.deploy_roster_toggle_tween != null:
				field.deploy_roster_toggle_tween.kill()
				field.deploy_roster_toggle_tween = null
			d_toggle.visible = false
	if count_text != null and roster_panel != null:
		count_text.position = Vector2(16, 16)
		count_text.size = Vector2(roster_panel.size.x - 32.0, 24.0)
		count_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		field._style_tactical_label(count_text, field.TACTICAL_UI_ACCENT, 21, 4)
	if roster_items != null and roster_panel != null:
		roster_items.position = Vector2(12, 50)
		if show_deployment_rail:
			# Multi-line rows: default ItemList uses trim+ellipsis (one line); that hides Lv/class/weapon/stats.
			roster_items.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			roster_items.icon_mode = ItemList.ICON_MODE_TOP
			roster_items.max_text_lines = 4
			roster_items.fixed_icon_size = Vector2i(40, 40)
			roster_items.add_theme_font_size_override("font_size", 17)
			roster_items.add_theme_constant_override("line_separation", 2)
			roster_items.add_theme_constant_override("v_separation", 8)
		else:
			roster_items.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			roster_items.icon_mode = ItemList.ICON_MODE_LEFT
			roster_items.max_text_lines = 1
			roster_items.fixed_icon_size = Vector2i(40, 40)
			roster_items.add_theme_font_size_override("font_size", 19)
			roster_items.remove_theme_constant_override("line_separation")
			roster_items.remove_theme_constant_override("v_separation")
		if show_deployment_rail:
			var btn_top_r: float = roster_panel.size.y - 58.0
			var readout_top_r: float = btn_top_r - 8.0 - deploy_bond_block_h
			# Must not use min height larger than free space or the list draws over the bond panel.
			var list_h_r: float = readout_top_r - 50.0 - 8.0
			roster_items.size = Vector2(roster_panel.size.x - 24.0, maxf(40.0, list_h_r))
			roster_items.z_index = 0
		else:
			roster_items.size = Vector2(roster_panel.size.x - 24.0, max(180.0, roster_panel.size.y - 122.0))
	if build_button != null and roster_panel != null:
		build_button.position = Vector2(12, roster_panel.size.y - 58.0)
		build_button.size = Vector2(roster_panel.size.x - 24.0, 46.0)
		field._style_tactical_button(build_button, build_button.text if build_button.text != "" else "BUILD DEFENSES", false, 20)
	# Nested under RosterPanel (CanvasLayer cannot lay out Control children reliably). PreBattleState toggles visibility.
	if deploy_bond_panel != null and roster_panel != null and roster_panel.visible and show_deployment_rail:
		if deploy_bond_block_h <= 0.01:
			deploy_bond_panel.visible = false
		else:
			deploy_bond_panel.visible = true
			deploy_bond_panel.scale = Vector2.ONE
			deploy_bond_panel.clip_contents = true
			deploy_bond_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
			deploy_bond_panel.anchor_right = 0.0
			deploy_bond_panel.anchor_bottom = 0.0
			var btn_top_b: float = roster_panel.size.y - 58.0
			var readout_top_b: float = btn_top_b - 8.0 - deploy_bond_block_h
			deploy_bond_panel.position = Vector2(12, readout_top_b)
			deploy_bond_panel.size = Vector2(roster_panel.size.x - 24.0, deploy_bond_block_h)
			deploy_bond_panel.z_index = 2
			# Opaquer than field.TACTICAL_UI_BG_SOFT so list text cannot show through when stacking.
			field._style_tactical_panel(deploy_bond_panel, field.TACTICAL_UI_BG_ALT, field.TACTICAL_UI_BORDER_MUTED, 1, 8)
	var start_button := field.get_node_or_null("UI/StartBattleButton") as Button
	if start_button != null:
		start_button.z_index = 26
		start_button.scale = hud_scale_vec
		var start_button_y: float = vp_size.y - (78.0 * hud_scale) - field.TACTICAL_UI_BOTTOM_EDGE_MARGIN - (12.0 * hud_scale)
		start_button_y = maxf(110.0, start_button_y)
		# When the roster is hidden, sit lower than dead-center so the map reads clearer (~200px at 1:1 HUD scale).
		var start_button_mid_y: float = (vp_size.y - (78.0 * hud_scale)) * 0.5
		start_button_mid_y += 200.0 * hud_scale
		start_button_mid_y = minf(
			start_button_mid_y,
			vp_size.y - (78.0 * hud_scale) - field.TACTICAL_UI_BOTTOM_EDGE_MARGIN - (8.0 * hud_scale)
		)
		var start_button_x: float = ((vp_size.x - (460.0 * hud_scale)) * 0.5) + (24.0 * hud_scale)
		start_button.position = Vector2(start_button_x, start_button_y)
		start_button.size = Vector2(460.0, 78.0)
		start_button.visible = show_deployment_rail
		start_button.set_meta("deploy_start_expanded_y", start_button_y)
		start_button.set_meta("deploy_start_collapsed_y", start_button_mid_y)
		field._style_tactical_button(start_button, start_button.text if start_button.text != "" else "START BATTLE", true, 42)
	
