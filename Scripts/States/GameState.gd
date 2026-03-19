extends Node
class_name GameState

var battlefield: Node2D

func enter(p_battlefield: Node2D) -> void:
	battlefield = p_battlefield

func exit() -> void:
	battlefield = null

func update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass
