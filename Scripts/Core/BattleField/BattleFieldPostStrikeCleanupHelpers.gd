extends RefCounted

static func process_phase_f_durability_and_return(
	field,
	attacker: Node2D,
	wpn
	,
	did_melee_normal_animation: bool,
	orig_pos: Vector2
) -> void:
	if is_instance_valid(attacker):
		if not did_melee_normal_animation:
			var return_tween: Tween = field.create_tween()
			return_tween.tween_property(attacker, "global_position", orig_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await return_tween.finished

		# --- DEGRADE WEAPON AFTER STRIKE ---
		if wpn and wpn.get("current_durability") != null and wpn.current_durability > 0:
			wpn.current_durability -= 1
			if wpn.current_durability <= 0:
				field.spawn_loot_text("BROKEN!", Color.RED, attacker.global_position + Vector2(32, -40))
				field.screen_shake(15.0, 0.3) # Heavy shake for impact
				if field.miss_sound.stream != null: field.miss_sound.play() # Play a negative sound

