import os
import re

file_path = "Scripts/Core/BattleField/BattleFieldQteMinigameHelpers.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

pattern = r"static func run_focused_strike_minigame\(field, attacker: Node2D\) -> int:.*?(?=\nstatic func run_bloodthirster_minigame\(field, attacker|\Z)"
match = re.search(pattern, content, re.DOTALL)

new_code = """static func run_focused_strike_minigame(field, attacker: Node2D) -> int:
	if attacker == null or not is_instance_valid(attacker): return 0
	
	field.screen_shake(5.0, 0.2)
	var clang = field.get_node_or_null("ClangSound")
	if clang != null and clang.stream != null:
		clang.pitch_scale = 0.5
		clang.play()
	field.spawn_loot_text("FOCUS STRIKE!", Color(1.0, 0.5, 0.0), attacker.global_position + Vector2(32, -48), {"stack_anchor": attacker})
	await field.get_tree().create_timer(0.6).timeout
	
	var qte = QTEHoldReleaseBar.run(field, "FOCUS STRIKE!", "HOLD SPACE... RELEASE IN GREEN!", 1200)
	var res = await qte.qte_finished
	return res
"""

if match:
    content = content[:match.start()] + new_code + "\n" + content[match.end():]
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"Replaced run_focused_strike_minigame")
else:
    print(f"Could not find run_focused_strike_minigame")

