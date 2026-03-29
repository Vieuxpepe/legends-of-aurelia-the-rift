extends Node2D
## Draws MP tick marks above path lines (parent BattleField exposes positions).

func _draw() -> void:
	var bf: Node = get_parent()
	if bf == null or not bf.has_method("get_path_preview_tick_positions_for_draw"):
		return
	var pts_variant: Variant = bf.call("get_path_preview_tick_positions_for_draw")
	if pts_variant == null or not pts_variant is Array:
		return
	var pts: Array = pts_variant as Array
	if pts.is_empty():
		return
	for p in pts:
		if not p is Vector2:
			continue
		var pv: Vector2 = p as Vector2
		draw_circle(pv, 3.2, Color(0.08, 0.07, 0.12, 0.85))
		draw_circle(pv, 2.1, Color(1.0, 0.96, 0.82, 0.94))
