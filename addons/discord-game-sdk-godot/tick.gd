extends Node


func _process(_delta: float):
	if Engine.has_singleton("IDGSCore"):
		var core: Object = Engine.get_singleton("IDGSCore")
		if core != null and core.has_method("tick"):
			core.tick()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		DiscordSDK.Core.destroy()
