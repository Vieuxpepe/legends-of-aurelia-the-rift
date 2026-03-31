extends RefCounted


static func animate_shield_drop(field, unit: Node2D) -> void:
	var shield_icon = unit.get_node_or_null("DefendIcon")
	if shield_icon != null:
		# Capture designed position
		var target_pos = shield_icon.position

		# Reset for animation
		shield_icon.position = target_pos + Vector2(0, -60)
		shield_icon.modulate.a = 0.0
		shield_icon.visible = true

		# The satisfying bounce!
		var drop_tween = field.create_tween().set_parallel(true)
		drop_tween.tween_property(shield_icon, "position", target_pos, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		drop_tween.tween_property(shield_icon, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)

