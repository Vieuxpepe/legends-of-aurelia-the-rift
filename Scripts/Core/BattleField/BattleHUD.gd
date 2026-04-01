extends CanvasLayer
class_name BattleHUD

## Gold readout on the UI CanvasLayer. Phase banner lives on BattleField (`show_phase_banner`).

@onready var gold_label: Label = $GoldLabel


func set_gold_display(amount: int) -> void:
	if gold_label != null:
		gold_label.text = "Gold: " + str(amount)
