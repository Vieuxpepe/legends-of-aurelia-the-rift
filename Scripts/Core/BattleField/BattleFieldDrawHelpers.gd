extends RefCounted

# Visual-only draw helpers extracted from `BattleField.gd`.
# These functions call `field.draw_*` to keep draw ordering identical.

static func draw_pre_battle_deployment_overlay_and_snap(field, pbs) -> void:
	if pbs == null:
		return

	# Must match the pre-delegation inline `_draw()` branch exactly:
	# - Always draws `valid_deployment_slots`
	# - Uses legacy opacities (0.4 / 0.8)
	# - Does NOT render snap-highlight here
	for pos in pbs.valid_deployment_slots:
		field.draw_rect(
			Rect2(pos.x * field.CELL_SIZE.x, pos.y * field.CELL_SIZE.y, field.CELL_SIZE.x, field.CELL_SIZE.y),
			Color(0.2, 0.8, 0.2, 0.4)
		)
		field.draw_rect(
			Rect2(pos.x * field.CELL_SIZE.x, pos.y * field.CELL_SIZE.y, field.CELL_SIZE.x, field.CELL_SIZE.y),
			Color(0.2, 1.0, 0.2, 0.8),
			false,
			2.0
		)


static func draw_danger_reachable_attackable(field, action_color: Color) -> void:
	if field.show_danger_zone:
		for pos in field.danger_zone_move_tiles:
			if field._danger_overlay_cell_drawable(pos):
				field.draw_rect(
					Rect2(pos.x * field.CELL_SIZE.x, pos.y * field.CELL_SIZE.y, field.CELL_SIZE.x, field.CELL_SIZE.y),
					Color(0.5, 0.0, 0.5, 0.4)
				)
		for pos in field.danger_zone_attack_tiles:
			if field._danger_overlay_cell_drawable(pos):
				field.draw_rect(
					Rect2(pos.x * field.CELL_SIZE.x, pos.y * field.CELL_SIZE.y, field.CELL_SIZE.x, field.CELL_SIZE.y),
					Color(1.0, 0.4, 0.0, 0.5)
				)

	for pos in field.reachable_tiles:
		field.draw_rect(
			Rect2(pos.x * field.CELL_SIZE.x, pos.y * field.CELL_SIZE.y, field.CELL_SIZE.x, field.CELL_SIZE.y),
			Color(0.3, 0.5, 0.9, 0.5)
		)

	for pos in field.attackable_tiles:
		field.draw_rect(
			Rect2(pos.x * field.CELL_SIZE.x, pos.y * field.CELL_SIZE.y, field.CELL_SIZE.x, field.CELL_SIZE.y),
			action_color
		)

static func draw_enemy_threat(field) -> void:
	if not CampaignManager.battle_show_enemy_threat:
		return
	for pos in field.enemy_reachable_tiles:
		if field._danger_overlay_cell_drawable(pos):
			field.draw_rect(
				Rect2(pos.x * field.CELL_SIZE.x, pos.y * field.CELL_SIZE.y, field.CELL_SIZE.x, field.CELL_SIZE.y),
				Color(0.5, 0.0, 0.5, 0.4)
			)

	for pos in field.enemy_attackable_tiles:
		if field._danger_overlay_cell_drawable(pos):
			field.draw_rect(
				Rect2(pos.x * field.CELL_SIZE.x, pos.y * field.CELL_SIZE.y, field.CELL_SIZE.x, field.CELL_SIZE.y),
				Color(1.0, 0.4, 0.0, 0.5)
			)


static func draw_reinforcement_telegraph_overlays(field) -> void:
	var reinforcement_snapshot: Dictionary = field._build_enemy_reinforcement_telegraph_snapshot()

	for pos in reinforcement_snapshot.get("later_tiles", []):
		field.draw_rect(
			Rect2(pos.x * field.CELL_SIZE.x, pos.y * field.CELL_SIZE.y, field.CELL_SIZE.x, field.CELL_SIZE.y),
			field.REINFORCEMENT_OVERLAY_LATER_FILL
		)
		field.draw_rect(
			Rect2(pos.x * field.CELL_SIZE.x, pos.y * field.CELL_SIZE.y, field.CELL_SIZE.x, field.CELL_SIZE.y),
			field.REINFORCEMENT_OVERLAY_LATER_BORDER,
			false,
			2.0
		)

	for pos in reinforcement_snapshot.get("soon_tiles", []):
		field.draw_rect(
			Rect2(pos.x * field.CELL_SIZE.x, pos.y * field.CELL_SIZE.y, field.CELL_SIZE.x, field.CELL_SIZE.y),
			field.REINFORCEMENT_OVERLAY_SOON_FILL
		)
		field.draw_rect(
			Rect2(pos.x * field.CELL_SIZE.x, pos.y * field.CELL_SIZE.y, field.CELL_SIZE.x, field.CELL_SIZE.y),
			field.REINFORCEMENT_OVERLAY_SOON_BORDER,
			false,
			4.0
		)

