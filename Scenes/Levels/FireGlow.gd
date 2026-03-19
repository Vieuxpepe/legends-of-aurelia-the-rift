extends PointLight2D

var base_energy: float = 1.2
var flicker_speed: float = 0.15 # How fast the fire pulses
var timer: float = 0.0

func _ready() -> void:
	base_energy = energy

func _process(delta: float) -> void:
	timer += delta
	
	if timer >= flicker_speed:
		timer = 0.0
		
		# Pick a random intensity and slightly random size
		var target_energy = base_energy + randf_range(-0.4, 0.4)
		var target_scale = texture_scale + randf_range(-0.1, 0.1)
		
		# Clamp the scale so it doesn't infinitely grow or shrink
		target_scale = clamp(target_scale, 1.8, 2.2) 
		
		# Smoothly slide to the new values
		var tween = create_tween()
		tween.tween_property(self, "energy", target_energy, flicker_speed).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(self, "texture_scale", target_scale, flicker_speed).set_trans(Tween.TRANS_SINE)
