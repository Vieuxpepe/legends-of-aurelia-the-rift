extends AnimatedSprite2D

func _ready() -> void:
	# Automatically play the animation the moment it spawns
	play("dash")
	# Delete the node from the game the exact millisecond the animation finishes
	animation_finished.connect(queue_free)
