import os
import re

classes_dir = "Resources/Classes"
abilities = set()

# Pattern for class_combat_ability = "..." or class_combat_ability_b = "..."
pattern = re.compile(r'class_combat_ability(_b)?\s*=\s*"(.*?)"')

for root, dirs, files in os.walk(classes_dir):
    for file in files:
        if file.endswith(".tres"):
            path = os.path.join(root, file)
            try:
                content = open(path, "r", encoding="utf-8").read()
                matches = pattern.findall(content)
                for _, ab in matches:
                    if ab.strip():
                        abilities.add(ab.strip())
            except Exception as e:
                pass

print("UNIQUE COMBAT ABILITIES FOUND:")
for ab in sorted(list(abilities)):
    # Standardize name for hook check: run_[lowercase_with_underscores]_minigame
    hook_name = "run_" + ab.lower().replace(" ", "_").replace("'", "") + "_minigame"
    print(f"- {ab} (Expected hook: {hook_name})")
