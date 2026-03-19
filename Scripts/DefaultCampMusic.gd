# DefaultCampMusic.gd
# Single source of truth for default camp music tracks. Used by camp_menu and CampExplore
# so both share the same pool without duplicating track lists or logic.

class_name DefaultCampMusic

static func get_default_camp_music_tracks() -> Array[AudioStream]:
	return [
		preload("res://SoundEffects/Music/Camp V3.wav"),
		preload("res://SoundEffects/Music/Camp Music.wav"),
		preload("res://SoundEffects/Music/Camp V4.wav"),
		preload("res://SoundEffects/Music/Camp V5.wav"),
		preload("res://SoundEffects/Music/Camp V6.wav"),
	]
