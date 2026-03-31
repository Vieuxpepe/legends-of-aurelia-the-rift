extends RefCounted


static func toggle_minimap(field) -> void:
	if field.minimap_container == null:
		return

	field.minimap_container.visible = not field.minimap_container.visible

	if field.minimap_container.visible:
		# Play a cool high-tech open sound if you have one!
		if field.select_sound:
			field.select_sound.pitch_scale = 1.2
			field.select_sound.play()
		# Force the drawer to update its visuals based on the current grid state
		field.map_drawer.queue_redraw()
	else:
		# Play a close sound
		if field.select_sound:
			field.select_sound.pitch_scale = 0.8
			field.select_sound.play()

