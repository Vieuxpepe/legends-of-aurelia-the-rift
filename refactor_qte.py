import sys
import re

try:
    with open('QTEManager.gd', 'r', encoding='utf-8') as f:
        content = f.read()

    # Deadeye
    content = re.sub(r'func run_deadeye_shot_minigame.*?return result',
        '''func run_deadeye_shot_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker):
		return 0

	var qte_bar = load("res://Scripts/Core/QTETimingBar.gd")
	var qte = qte_bar.run(bf, "DEADEYE SHOT", "PRESS SPACE INSIDE THE CENTER", 920)
	var result: int = await qte.qte_finished
	return result''', content, count=1, flags=re.DOTALL)

    # Volley
    content = re.sub(r'func run_volley_minigame.*?return result',
        '''func run_volley_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker):
		return 0

	var qte_mash = load("res://Scripts/Core/QTEMashMeter.gd")
	var qte = qte_mash.run(bf, "VOLLEY", "MASH SPACE TO LOOSE MORE ARROWS", 2200, 28.0)
	var result: int = await qte.qte_finished
	return result''', content, count=1, flags=re.DOTALL)

    # Rain of Arrows
    content = re.sub(r'func run_rain_of_arrows_minigame.*?return result',
        '''func run_rain_of_arrows_minigame(bf: Node2D, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0

	var qte_seq = load("res://Scripts/Core/QTESequenceMemory.gd")
	var qte = qte_seq.run(bf, "RAIN OF ARROWS", "MEMORIZE THEN REPEAT THE PATTERN", 5)
	var result: int = await qte.qte_finished
	return result''', content, count=1, flags=re.DOTALL)

    with open('QTEManager.gd', 'w', encoding='utf-8') as f:
        f.write(content)

    print('Replaced functions successfully')
except Exception as e:
    print(f"Error: {e}")
