## Single source of truth for client version strings (UI, feedback metadata).
## - application/config/version: semantic version (Project Settings → Application → Config → Version)
## - legends_of_aurelia/build: optional label (branch, CI id, store sku) in project.godot
## Godot engine version comes from Engine.get_version_info() at runtime (matches the running binary).
class_name GameVersion

## Legal / copyright holder name (splash, footers, credits summaries).
const STUDIO_LEGAL_NAME := "Korvain Games"


static func get_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


static func get_build_label() -> String:
	return str(ProjectSettings.get_setting("legends_of_aurelia/build", "")).strip_edges()


static func get_display_string() -> String:
	var v := get_version()
	var b := get_build_label()
	if b.is_empty():
		return v
	return "%s · %s" % [v, b]


static func get_report_metadata_version() -> String:
	var v := get_version()
	var b := get_build_label()
	if b.is_empty():
		return v
	return "%s (%s)" % [v, b]


static func get_godot_version_number_string() -> String:
	var info: Dictionary = Engine.get_version_info()
	var major: int = int(info.get("major", 0))
	var minor: int = int(info.get("minor", 0))
	var patch: int = int(info.get("patch", 0))
	var status: String = str(info.get("status", "")).strip_edges()
	var s := "%d.%d.%d" % [major, minor, patch]
	if not status.is_empty():
		s += ".%s" % status
	return s


static func get_godot_version_label() -> String:
	return "Godot %s" % get_godot_version_number_string()


static func _copyright_year() -> int:
	var t: Dictionary = Time.get_datetime_dict_from_system()
	return int(t.get("year", 2026))


static func get_game_copyright_line() -> String:
	return "© %d %s. All rights reserved." % [_copyright_year(), STUDIO_LEGAL_NAME]


## One-line footer / alongside version (Godot Foundation naming kept short for UI).
static func get_godot_attribution_short() -> String:
	return "Godot Engine © 2014–present contributors · MIT License"


## Longer credits / legal screen (not the full MIT legal text).
static func get_godot_credits_body() -> String:
	return (
		"This game was built with %s (the running editor or export template).\n\n"
		+ "Godot Engine — Copyright © 2014-present Godot Engine contributors (see the engine AUTHORS.md). "
		+ "Copyright © 2007-2014 Juan Linietsky, Ariel Manzur.\n\n"
		+ "Godot® is a registered trademark of the Godot Foundation. The engine is free and open source software released under the MIT License. "
		+ "See https://godotengine.org for notices and third-party licenses shipped with the engine."
	) % get_godot_version_label()


static func get_game_legal_summary() -> String:
	var title: String = str(ProjectSettings.get_setting("application/config/name", "This game"))
	return (
		"%s — client version %s.\n\n"
		+ "%s\n\n"
		+ "Original characters, narrative, art, audio, and game-specific rules are owned by %s unless otherwise noted in-game. "
		+ "Third-party trademarks and content remain property of their respective owners."
	) % [title, get_display_string(), get_game_copyright_line(), STUDIO_LEGAL_NAME]
