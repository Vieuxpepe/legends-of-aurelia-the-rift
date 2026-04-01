extends RefCounted

# Game-over / score / fame UI and loot-window description layout — presentation only.

static func present_game_over_panel(field, normalized_result: String) -> void:
	field.result_label.text = normalized_result
	var coop_defeat_return_to_charter: bool = (
		normalized_result != "VICTORY"
		and CoopExpeditionSessionManager.uses_runtime_network_coop_transport()
		and CoopExpeditionSessionManager.phase != CoopExpeditionSessionManager.Phase.NONE
	)
	if normalized_result == "VICTORY":
		field.result_label.modulate = Color(0.2, 0.8, 0.2)
		field.continue_button.visible = true
		field.restart_button.visible = false
		if field.is_arena_match:
			field.continue_button.text = "Return to City"
		else:
			field.continue_button.text = "Continue"
	else:
		field.result_label.modulate = Color(0.8, 0.2, 0.2)
		field.continue_button.visible = coop_defeat_return_to_charter
		field.restart_button.visible = not coop_defeat_return_to_charter
		if coop_defeat_return_to_charter:
			field.continue_button.text = "Return to Charter"
		elif field.is_arena_match:
			field.restart_button.text = "Leave Arena"

	var base_clear = 500 if normalized_result == "VICTORY" else 0
	var ability_pts = field.ability_triggers_count * 50
	var kill_pts = field.enemy_kills_count * 25
	var p_death_pen = field.player_deaths_count * -250
	var a_death_pen = field.ally_deaths_count * -100

	var raw_score = base_clear + ability_pts + kill_pts + p_death_pen + a_death_pen

	var hero_level = 1
	for u in field.player_container.get_children():
		if u.get("is_custom_avatar") == true:
			hero_level = u.level
			break

	var max_allowed = hero_level * 1000

	var final_score = clamp(raw_score, 1, max_allowed)

	CampaignManager.global_fame += final_score

	var score_label = field.game_over_panel.get_node_or_null("ScoreBreakdown")
	if score_label == null:
		score_label = RichTextLabel.new()
		score_label.name = "ScoreBreakdown"
		score_label.bbcode_enabled = true

		score_label.add_theme_font_size_override("normal_font_size", 32)
		score_label.add_theme_font_size_override("bold_font_size", 32)

		score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		score_label.custom_minimum_size = Vector2(800, 500)
		score_label.position = Vector2((field.game_over_panel.size.x - 800) / 2.0, field.result_label.position.y + 70)
		field.game_over_panel.add_child(score_label)

	var txt = "[center]"
	if base_clear > 0: txt += "Map Clear: [color=lime]+500[/color]\n"
	if kill_pts > 0: txt += "Enemies Defeated (" + str(field.enemy_kills_count) + "): [color=lime]+" + str(kill_pts) + "[/color]\n"
	if ability_pts > 0: txt += "Abilities Executed (" + str(field.ability_triggers_count) + "): [color=lime]+" + str(ability_pts) + "[/color]\n"

	if p_death_pen < 0: txt += "Player Units Lost (" + str(field.player_deaths_count) + "): [color=red]" + str(p_death_pen) + "[/color]\n"
	if a_death_pen < 0: txt += "Allies Lost (" + str(field.ally_deaths_count) + "): [color=orange]" + str(a_death_pen) + "[/color]\n"

	txt += "------------------\n"
	txt += "Total Score: " + str(final_score) + "\n"

	if raw_score > max_allowed:
		txt += "[color=yellow](Capped at Hero Level Limit: " + str(max_allowed) + ")[/color]\n"

	txt += "\n[color=gold]GLOBAL FAME: " + str(CampaignManager.global_fame) + "[/color][/center]"

	score_label.text = txt
	field.game_over_panel.visible = true


static func resolve_loot_ui_nodes(field) -> void:
	if field.loot_window == null:
		return
	field.loot_desc_label = field.loot_window.get_node_or_null("ItemDescLabel") as RichTextLabel
	field.loot_item_info_panel = field.loot_window.get_node_or_null("LootItemInfoBackdrop") as Panel


static func layout_loot_item_info_backdrop(field) -> void:
	if field.loot_window == null or field.loot_item_info_panel == null or field.loot_desc_label == null:
		return
	if not field.loot_desc_label.has_meta(field.META_LOOT_DESC_LAYOUT_BASE):
		field.loot_desc_label.set_meta(field.META_LOOT_DESC_LAYOUT_BASE, Rect2(field.loot_desc_label.position, field.loot_desc_label.size))
	var base_rect: Rect2 = field.loot_desc_label.get_meta(field.META_LOOT_DESC_LAYOUT_BASE)
	var outer := float(field.LOOT_INFO_BACKDROP_OUTER_PAD)
	var inner := float(field.LOOT_INFO_DESC_INNER_PAD)
	field.loot_item_info_panel.position = base_rect.position - Vector2(outer, outer)
	field.loot_item_info_panel.size = base_rect.size + Vector2(outer * 2.0, outer * 2.0)
	field.loot_item_info_panel.z_index = -1
	field.loot_desc_label.position = base_rect.position + Vector2(inner, inner)
	field.loot_desc_label.size = base_rect.size - Vector2(inner * 2.0, inner * 2.0)
	field.loot_desc_label.z_index = 2


static func ensure_loot_item_info_ui(field) -> void:
	if field.loot_window == null:
		return
	resolve_loot_ui_nodes(field)
	if field.loot_desc_label == null:
		var rtl := RichTextLabel.new()
		rtl.name = "ItemDescLabel"
		rtl.layout_mode = 0
		rtl.offset_left = 770.0
		rtl.offset_top = 100.0
		rtl.offset_right = 1248.0
		rtl.offset_bottom = 392.0
		rtl.bbcode_enabled = true
		rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rtl.scroll_active = false
		rtl.fit_content = false
		rtl.mouse_filter = Control.MOUSE_FILTER_STOP
		rtl.process_mode = Node.PROCESS_MODE_ALWAYS
		field.loot_window.add_child(rtl)
		field.loot_desc_label = rtl
	if field.loot_item_info_panel == null:
		var bp := Panel.new()
		bp.name = "LootItemInfoBackdrop"
		bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		field.loot_window.add_child(bp)
		field.loot_item_info_panel = bp
		field.loot_window.move_child(field.loot_item_info_panel, 0)
	field._style_tactical_panel(field.loot_item_info_panel, field.TACTICAL_UI_BG_ALT, field.TACTICAL_UI_BORDER, 2, 12)
	field.loot_item_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout_loot_item_info_backdrop(field)
	var loot_title := field.loot_window.get_node_or_null("Label") as Label
	if loot_title != null:
		field._style_tactical_label(loot_title, field.TACTICAL_UI_ACCENT, 22, 4)
		loot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if field.loot_desc_label != null:
		field.loot_desc_label.focus_mode = Control.FOCUS_NONE
		field.loot_desc_label.remove_theme_stylebox_override("focus")
		field.loot_desc_label.scroll_active = false
		field.loot_desc_label.process_mode = Node.PROCESS_MODE_ALWAYS


static func refit_loot_description_panel_height(field) -> void:
	if field.loot_desc_label == null or field.loot_item_info_panel == null:
		return
	if not field.loot_desc_label.has_meta(field.META_LOOT_DESC_LAYOUT_BASE):
		return
	field.loot_desc_label.scroll_active = false
	var base_rect: Rect2 = field.loot_desc_label.get_meta(field.META_LOOT_DESC_LAYOUT_BASE)
	var inner := float(field.LOOT_INFO_DESC_INNER_PAD)
	var outer := float(field.LOOT_INFO_BACKDROP_OUTER_PAD)
	var text_w: float = maxf(48.0, base_rect.size.x - inner * 2.0)
	field.loot_desc_label.position = base_rect.position + Vector2(inner, inner)
	field.loot_desc_label.size.x = text_w
	field.loot_desc_label.size.y = maxf(field.ITEM_DESC_RICHTEXT_MIN_H, 32.0)
	var ch: float = field.loot_desc_label.get_content_height()
	var th: float = clampf(ch + field.ITEM_DESC_RICHTEXT_EXTRA_PAD, field.ITEM_DESC_RICHTEXT_MIN_H, field.ITEM_DESC_RICHTEXT_MAX_H)
	field.loot_desc_label.size.y = th
	var block_h: float = th + inner * 2.0
	field.loot_item_info_panel.position = base_rect.position - Vector2(outer, outer)
	field.loot_item_info_panel.size = Vector2(base_rect.size.x + outer * 2.0, block_h + outer * 2.0)
