extends RefCounted

const BattleFieldSpecialModeSetupHelpers = preload("res://Scripts/Core/BattleField/BattleFieldSpecialModeSetupHelpers.gd")

# `_ready()` orchestration, shared bootstrap, mock co-op charter UX, fog init, and post-setup grid/UI/intro wiring.
# Special skirmish / expedition / arena / VIP / base-defense branches live in `BattleFieldSpecialModeSetupHelpers.gd`.


static func present_mock_coop_joint_expedition_charter(field) -> void:
	if field._mock_coop_battle_context == null or not field._mock_coop_battle_context.active:
		return
	var ctx: MockCoopBattleContext = field._mock_coop_battle_context
	var exp_title: String = ctx.get_expedition_display_title()
	var loc: String = ctx.get_local_participant_label()
	var rem: String = ctx.get_remote_participant_label()
	var role_cap: String = ctx.local_role.capitalize()
	if ctx.context_valid:
		field.add_combat_log("â”€â”€â”€â”€â”€â”€â”€â”€ Joint Expedition Charter (Mock Co-op) â”€â”€â”€â”€â”€â”€â”€â”€", "gold")
		field.add_combat_log("Expedition: %s" % exp_title, "cyan")
		field.add_combat_log("Commanders: %s  Â·  %s" % [loc, rem], "cyan")
		field.add_combat_log("Your role: %s" % role_cap, "cyan")
		field.add_combat_log("Shared contract â€” this sortie is fought together.", "gray")
	else:
		field.add_combat_log("â”€â”€â”€â”€â”€â”€â”€â”€ Joint Expedition Charter (incomplete data) â”€â”€â”€â”€â”€â”€â”€â”€", "orange")
		field.add_combat_log("Expedition: %s â€” verify session before relying on co-op data." % exp_title, "yellow")
		field.add_combat_log("Commanders: %s  Â·  %s  |  Your role: %s" % [loc, rem, role_cap], "yellow")
		field.add_combat_log("Issues: %s" % str(ctx.validation_errors), "orange")


static func on_ready(field) -> void:
	if field.has_node("LevelMusic"):
		var level_music := field.get_node("LevelMusic") as AudioStreamPlayer
		if level_music != null:
			level_music.bus = "Music"

	field.astar.region = Rect2i(0, 0, field.GRID_SIZE.x, field.GRID_SIZE.y)
	field.astar.cell_size = field.CELL_SIZE
	field.astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	field.astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	field.astar.update()

	field.flying_astar.region = Rect2i(0, 0, field.GRID_SIZE.x, field.GRID_SIZE.y)
	field.flying_astar.cell_size = field.CELL_SIZE
	field.flying_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	field.flying_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	field.flying_astar.update()

	field.player_state = PlayerTurnState.new()
	field.ally_state = AITurnState.new("ally")
	field.enemy_state = AITurnState.new("enemy")
	field.pre_battle_state = PreBattleState.new()

	field.ally_state.turn_finished.connect(field._on_ally_turn_finished)
	field.enemy_state.turn_finished.connect(field._on_enemy_turn_finished)

	if field.player_container:
		for u in field.player_container.get_children():
			u.died.connect(field._on_unit_died)
			u.leveled_up.connect(field._on_unit_leveled_up)

	if field.ally_container:
		for a in field.ally_container.get_children():
			a.died.connect(field._on_unit_died)
			a.leveled_up.connect(field._on_unit_leveled_up)

	if field.enemy_container:
		for e in field.enemy_container.get_children():
			e.died.connect(field._on_unit_died)
			e.leveled_up.connect(field._on_unit_leveled_up)

	field.trade_popup_btn.pressed.connect(field._on_trade_popup_confirm)
	field.trade_close_btn.pressed.connect(field._on_trade_window_close)
	field.trade_left_list.item_selected.connect(func(idx): field._on_trade_item_clicked(idx, "left"))
	field.trade_right_list.item_selected.connect(func(idx): field._on_trade_item_clicked(idx, "right"))
	field.get_node("UI/CombatForecastPanel/ConfirmButton").pressed.connect(field._on_forecast_confirm)
	field.get_node("UI/CombatForecastPanel/CancelButton").pressed.connect(field._on_forecast_cancel)
	if field.forecast_talk_btn:
		field.forecast_talk_btn.pressed.connect(field._on_forecast_talk)
	if field.forecast_ability_btn:
		field.forecast_ability_btn.pressed.connect(field._on_forecast_ability_pressed)
	field.convoy_button.pressed.connect(field._on_convoy_pressed)
	field.open_inv_button.pressed.connect(field._on_open_inv_pressed)
	field.get_node("UI/InventoryPanel/EquipButton").pressed.connect(field._on_equip_pressed)
	field.get_node("UI/InventoryPanel/CloseButton").pressed.connect(field._on_close_inv_pressed)
	field.get_node("UI/InventoryPanel/UseButton").pressed.connect(field._on_use_pressed)
	field.close_loot_button.pressed.connect(field._on_close_loot_pressed)
	field.loot_item_list.fixed_icon_size = Vector2i(64, 64)
	field.trade_left_list.fixed_icon_size = Vector2i(32, 32)
	field.trade_right_list.fixed_icon_size = Vector2i(32, 32)
	field.loot_item_list.item_selected.connect(field._on_loot_item_selected)
	if field.popup_talk_btn:
		field.popup_talk_btn.pressed.connect(field._on_support_talk_pressed)
	if field.talk_next_btn:
		field.talk_next_btn.pressed.connect(func(): field.emit_signal("dialogue_advanced"))
	if field.support_btn:
		field.support_btn.pressed.connect(field._on_support_btn_pressed)
	if field.unit_details_button and not field.unit_details_button.pressed.is_connected(field._on_unit_details_button_pressed):
		field.unit_details_button.pressed.connect(field._on_unit_details_button_pressed)
	if field.close_support_btn:
		field.close_support_btn.pressed.connect(func(): field.support_tracker_panel.visible = false)
	if field.main_camera != null:
		field._camera_zoom_target = field.main_camera.zoom.x

	field._ensure_forecast_support_labels()
	field._apply_inventory_panel_spacing()

	field._defy_death_used.clear()
	field._grief_units.clear()
	field._relationship_event_awarded.clear()
	field._enemy_damagers.clear()
	field._boss_personal_dialogue_played.clear()

	if field.destructibles_container:
		for d in field.destructibles_container.get_children():
			if d.has_signal("died"):
				d.died.connect(field._on_destructible_died)

	if field.chests_container:
		for c in field.chests_container.get_children():
			if not c.is_queued_for_deletion() and c.is_locked:
				field.astar.set_point_solid(field.get_grid_pos(c), true)

	if field.select_sound:
		field.select_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	if field.epic_level_up_sound:
		field.epic_level_up_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	if field.level_up_sound:
		field.level_up_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	if field.crit_sound:
		field.crit_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	if field.miss_sound:
		field.miss_sound.process_mode = Node.PROCESS_MODE_ALWAYS

	if CampaignManager.player_roster.is_empty():
		var test_path = CampaignManager.get_save_path(1)
		if FileAccess.file_exists(test_path):
			print("Direct Scene Start detected. Loading existing save data from Slot 1...")
			CampaignManager.load_game(1)

	field._consumed_mock_coop_battle_handoff = CampaignManager.consume_pending_mock_coop_battle_handoff()
	field.load_campaign_data()
	field._init_path_preview_nodes()
	field.apply_campaign_settings()
	field._seed_mock_coop_command_ids_for_live_battle_nodes()

	field._mock_coop_battle_context = null
	field._mock_coop_ownership_assignments.clear()
	field._reset_mock_coop_prebattle_ready_state()
	field._reset_mock_coop_player_phase_ready_state()
	var has_live_runtime_coop_phase: bool = (
			CoopExpeditionSessionManager.uses_runtime_network_coop_transport()
			and CoopExpeditionSessionManager.phase != CoopExpeditionSessionManager.Phase.NONE
	)
	if has_live_runtime_coop_phase:
		CoopExpeditionSessionManager.register_runtime_coop_battle_sync_target(field)
	if not field._consumed_mock_coop_battle_handoff.is_empty():
		field._mock_coop_battle_context = MockCoopBattleContext.from_consumed_handoff(field._consumed_mock_coop_battle_handoff)
		if field._mock_coop_battle_context != null:
			var ctx_line: String = field._mock_coop_battle_context.get_debug_summary_line()
			print("[MockCoopBattleContext] %s snapshot=%s" % [ctx_line, str(field._mock_coop_battle_context.get_snapshot())])
		print("[MockCoopHandoff] battle start keys=%s" % str(field._consumed_mock_coop_battle_handoff.keys()))
		present_mock_coop_joint_expedition_charter(field)
		field._assign_mock_coop_unit_ownership_from_context()
		if field.is_mock_coop_unit_ownership_active() and has_live_runtime_coop_phase:
			CoopExpeditionSessionManager.try_publish_runtime_coop_battle_rng_seed()
	elif has_live_runtime_coop_phase and OS.is_debug_build():
		push_warning("BattleField: network co-op battle loaded without a pending mock handoff; battle sync is registered, but ownership is inactive.")
	if has_live_runtime_coop_phase and not field.is_mock_coop_unit_ownership_active() and OS.is_debug_build():
		push_warning("BattleField: network co-op battle has no active mock ownership assignment; local player moves will not mirror until the handoff/ownership path is valid.")

	if field.use_fog_of_war:
		field.fog_drawer = Node2D.new()
		field.fog_drawer.z_index = 80
		field.fog_drawer.name = "FogDrawer"

		field.fog_drawer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

		field.fog_drawer.draw.connect(field._on_fog_draw)
		field.add_child(field.fog_drawer)

		field.fow_image = Image.create(field.GRID_SIZE.x, field.GRID_SIZE.y, false, Image.FORMAT_RGBA8)

		for x in range(field.GRID_SIZE.x):
			for y in range(field.GRID_SIZE.y):
				var p = Vector2i(x, y)
				field.fow_grid[p] = 0
				field.fow_display_alphas[p] = 0.85
				field.fow_image.set_pixel(x, y, Color(0.05, 0.05, 0.1, 0.85))

		field.fow_texture = ImageTexture.create_from_image(field.fow_image)

	BattleFieldSpecialModeSetupHelpers.apply_special_modes_after_fog(field)

	field.rebuild_grid()
	field._setup_objective_ui()
	field._queue_tactical_ui_overhaul()
	field.update_fog_of_war()

	field.get_node("UI/StartBattleButton").pressed.connect(field._on_start_battle_pressed)

	field.get_tree().create_timer(0.6).timeout.connect(field._start_intro_sequence)
