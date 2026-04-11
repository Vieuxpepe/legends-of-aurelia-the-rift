# Headless runner: godot --headless -s res://Scripts/Debug/run_rune_smithing_debug.gd
# Exit code 0 = pass, 1 = fail.
extends SceneTree


func _init() -> void:
	# Force-run: this entrypoint is explicitly for validation (debug or release template).
	var ok: bool = RuneSmithingDebugTest.run_all(true)
	quit(0 if ok else 1)
