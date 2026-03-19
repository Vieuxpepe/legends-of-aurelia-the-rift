# CampBubbleController.gd
# Ambient speech bubble + fallback rumor label positioning and visibility.

class_name CampBubbleController
extends RefCounted

const AMBIENT_BUBBLE_WORLD_Y_OFFSET: float = 54.0

var _explore: Node2D
var _ambient_bubble_speaker: CampRosterWalker = null

var ambient_speech_bubble: PanelContainer
var ambient_speech_name: Label
var ambient_speech_text: Label
var rumor_label: Label


func _init(explore: Node2D) -> void:
	_explore = explore


func bind_nodes(
	bubble: PanelContainer,
	speaker_label: Label,
	text_label: Label,
	rumor_lbl: Label
) -> void:
	ambient_speech_bubble = bubble
	ambient_speech_name = speaker_label
	ambient_speech_text = text_label
	rumor_label = rumor_lbl


func show_ambient_bubble(text: String, speaker_walker: CampRosterWalker, speaker_name: String = "") -> void:
	var bubble_text: String = str(text).strip_edges()
	if bubble_text == "":
		hide_ambient_bubble()
		return
	var debug_speaker_name: String = str(speaker_name).strip_edges()
	if ambient_speech_bubble != null and ambient_speech_text != null:
		if not is_instance_valid(speaker_walker):
			if rumor_label != null:
				var prefix_no_speaker: String = ""
				if debug_speaker_name != "":
					prefix_no_speaker = "%s: " % debug_speaker_name
				rumor_label.text = prefix_no_speaker + bubble_text
				rumor_label.visible = true
			_ambient_bubble_speaker = null
			ambient_speech_bubble.visible = false
			return
		ambient_speech_text.text = bubble_text
		if ambient_speech_name != null:
			ambient_speech_name.text = debug_speaker_name
			ambient_speech_name.visible = debug_speaker_name != ""
		_ambient_bubble_speaker = speaker_walker
		ambient_speech_bubble.visible = true
		update_ambient_bubble_position()
		if rumor_label != null:
			rumor_label.visible = false
			rumor_label.text = ""
		return
	if rumor_label != null:
		var prefix: String = ""
		var fallback_name: String = str(speaker_name).strip_edges()
		if fallback_name != "":
			prefix = "%s: " % fallback_name
		rumor_label.text = prefix + bubble_text
		rumor_label.visible = true
	_ambient_bubble_speaker = null


func hide_ambient_bubble() -> void:
	_ambient_bubble_speaker = null
	if ambient_speech_bubble != null:
		ambient_speech_bubble.visible = false
	if rumor_label != null:
		rumor_label.visible = false
		rumor_label.text = ""


func update_ambient_bubble_position() -> void:
	if ambient_speech_bubble == null or not ambient_speech_bubble.visible:
		return
	if not is_instance_valid(_ambient_bubble_speaker):
		hide_ambient_bubble()
		return
	var world_pos: Vector2 = _ambient_bubble_speaker.global_position + Vector2(0.0, -AMBIENT_BUBBLE_WORLD_Y_OFFSET)
	var screen_pos: Vector2 = _explore.get_viewport().get_canvas_transform() * world_pos
	var bubble_size: Vector2 = ambient_speech_bubble.size
	if bubble_size.x <= 1.0 or bubble_size.y <= 1.0:
		bubble_size = ambient_speech_bubble.get_combined_minimum_size()
	var target: Vector2 = screen_pos - Vector2(bubble_size.x * 0.5, bubble_size.y)
	var view_size: Vector2 = _explore.get_viewport_rect().size
	target.x = clampf(target.x, 8.0, maxf(8.0, view_size.x - bubble_size.x - 8.0))
	target.y = clampf(target.y, 8.0, maxf(8.0, view_size.y - bubble_size.y - 8.0))
	ambient_speech_bubble.position = target


func get_ambient_bubble_speaker() -> CampRosterWalker:
	return _ambient_bubble_speaker
