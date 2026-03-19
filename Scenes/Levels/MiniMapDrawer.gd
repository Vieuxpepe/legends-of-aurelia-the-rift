# MiniMapDrawer.gd
# Draws a tactical mini-map from the BattleField grid: units (player/ally/enemy), destructibles, obstacles.
# Optional: cursor/selection highlight, FOW dimming, throttled redraws. Find BattleField via find_parent().

extends Control

# --- DEFAULTS (exported so you can tune in editor) ---
@export var color_player: Color = Color(0.22, 0.58, 1.0)
@export var color_ally: Color = Color(0.2, 0.85, 0.35)
@export var color_enemy: Color = Color(0.95, 0.25, 0.25)
@export var color_obstacle: Color = Color(0.35, 0.35, 0.4)
@export var color_destructible: Color = Color(0.95, 0.75, 0.2)
@export var color_grid: Color = Color(1.0, 1.0, 1.0, 0.08)
@export var color_background: Color = Color(0.06, 0.06, 0.1, 0.92)
@export var color_cursor: Color = Color(1.0, 1.0, 1.0, 0.7)
@export var color_selection: Color = Color(0.4, 0.9, 1.0, 0.5)

@export var draw_grid_lines: bool = true
@export var draw_background: bool = true
@export var draw_cursor_highlight: bool = true
@export var draw_selection_highlight: bool = true
@export var use_fow_dimming: bool = true

## Redraw interval in seconds when visible. Higher = better performance, lower = snappier updates.
@export var redraw_interval: float = 0.08

var battlefield_ref: Node2D = null
var _redraw_timer: float = 0.0

func _ready() -> void:
	battlefield_ref = _find_battlefield(self)
	if battlefield_ref == null:
		battlefield_ref = find_parent("BattleField")

func _find_battlefield(node: Node) -> Node2D:
	if node == null:
		return null
	if node.get("GRID_SIZE") != null and node.get("get_occupant_at") != null:
		return node as Node2D
	var p = node.get_parent()
	return _find_battlefield(p) if p else null

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = redraw_interval
		queue_redraw()

func _draw() -> void:
	if battlefield_ref == null:
		return
	var grid_size = battlefield_ref.get("GRID_SIZE")
	if grid_size == null:
		return
	var grid_w: int = int(grid_size.x)
	var grid_h: int = int(grid_size.y)
	if grid_w <= 0 or grid_h <= 0:
		return

	var cell_w: float = size.x / float(grid_w)
	var cell_h: float = size.y / float(grid_h)
	var player_container = battlefield_ref.get("player_container")
	var enemy_container = battlefield_ref.get("enemy_container")
	var ally_container = battlefield_ref.get("ally_container")
	var destructibles_container = battlefield_ref.get("destructibles_container")
	var astar = battlefield_ref.get("astar")
	var use_fow: bool = use_fow_dimming and battlefield_ref.get("use_fog_of_war") == true
	var _fow = battlefield_ref.get("fow_grid") if use_fow else null
	var fow_grid: Dictionary = _fow if (_fow != null and _fow is Dictionary) else {}

	# --- BACKGROUND ---
	if draw_background:
		draw_rect(Rect2(Vector2.ZERO, size), color_background)

	# --- TILES ---
	var margin: float = 1.0
	var cell_size: Vector2 = Vector2(maxf(1.0, cell_w - margin * 2), maxf(1.0, cell_h - margin * 2))
	var show_grid: bool = draw_grid_lines and cell_w >= 3.0 and cell_h >= 3.0

	for x in range(grid_w):
		for y in range(grid_h):
			var grid_pos := Vector2i(x, y)
			var draw_pos := Vector2(x * cell_w + margin, y * cell_h + margin)
			var rect := Rect2(draw_pos, cell_size)

			var visible_alpha: float = 1.0
			if use_fow and fow_grid.has(grid_pos):
				var state = fow_grid[grid_pos]
				if state == 0:
					visible_alpha = 0.15
				elif state == 1:
					visible_alpha = 0.45

			var occupant = battlefield_ref.get_occupant_at(grid_pos) if battlefield_ref.has_method("get_occupant_at") else null
			var fill_color: Color
			var draw_cell := true

			if occupant != null:
				var parent = occupant.get_parent()
				if parent == player_container:
					fill_color = color_player
				elif parent == enemy_container:
					fill_color = color_enemy
				elif parent == ally_container:
					fill_color = color_ally
				elif parent == destructibles_container:
					fill_color = color_destructible
				else:
					draw_cell = false
				if draw_cell:
					fill_color.a *= visible_alpha
					draw_rect(rect, fill_color, true)
			elif astar != null and astar.is_point_solid(grid_pos):
				fill_color = color_obstacle
				fill_color.a *= visible_alpha
				draw_rect(rect, fill_color, true)

	# --- GRID LINES (on top of tiles, faint) ---
	if show_grid:
		var grid_color: Color = color_grid
		for x in range(grid_w + 1):
			var px: float = x * cell_w
			draw_line(Vector2(px, 0), Vector2(px, size.y), grid_color, 1.0)
		for y in range(grid_h + 1):
			var py: float = y * cell_h
			draw_line(Vector2(0, py), Vector2(size.x, py), grid_color, 1.0)

	# --- CURSOR / SELECTION HIGHLIGHT ---
	if draw_cursor_highlight or draw_selection_highlight:
		var cursor_pos = battlefield_ref.get("cursor_grid_pos")
		var selection_pos: Vector2i = Vector2i(-99, -99)
		var player_state = battlefield_ref.get("player_state")
		if player_state != null and player_state.get("active_unit") != null:
			var active_unit = player_state.active_unit
			if active_unit != null and is_instance_valid(active_unit) and battlefield_ref.has_method("get_grid_pos"):
				selection_pos = battlefield_ref.get_grid_pos(active_unit)

		if draw_cursor_highlight and cursor_pos != null:
			var cx: int = int(cursor_pos.x)
			var cy: int = int(cursor_pos.y)
			if cx >= 0 and cx < grid_w and cy >= 0 and cy < grid_h:
				var r := Rect2(cx * cell_w, cy * cell_h, cell_w, cell_h)
				draw_rect(r, color_cursor, false)
				draw_rect(r.grow(-1), color_cursor, false)

		if draw_selection_highlight and selection_pos.x >= 0 and selection_pos.x < grid_w and selection_pos.y >= 0 and selection_pos.y < grid_h:
			var r := Rect2(selection_pos.x * cell_w, selection_pos.y * cell_h, cell_w, cell_h)
			draw_rect(r, color_selection, false)
			draw_rect(r.grow(-1), color_selection, false)
