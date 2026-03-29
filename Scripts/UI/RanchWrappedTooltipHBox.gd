extends HBoxContainer

const _CampUiSkin = preload("res://Scripts/UI/CampUiSkin.gd")


func _make_custom_tooltip(for_text: String) -> Object:
	if str(for_text).strip_edges().is_empty():
		return null
	return _CampUiSkin.make_wrapped_tooltip_panel(for_text, _CampUiSkin.RANCH_TOOLTIP_MAX_WIDTH)
