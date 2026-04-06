import os
import re

classes_dir = "Resources/Classes"
results = []

for root, dirs, files in os.walk(classes_dir):
    for file in files:
        if file.endswith(".tres"):
            path = os.path.join(root, file)
            content = open(path, "r", encoding="utf-8").read()
            
            job_name = ""
            ability = ""
            ability_b = ""
            
            # Look for job_name = "..."
            job_match = re.search(r'job_name\s*=\s*"(.*?)"', content)
            if job_match:
                job_name = job_match.group(1)
            
            # Look for class_combat_ability = "..."
            ability_match = re.search(r'class_combat_ability\s*=\s*"(.*?)"', content)
            if ability_match:
                ability = ability_match.group(1)

            ability_b_match = re.search(r'class_combat_ability_b\s*=\s*"(.*?)"', content)
            if ability_b_match:
                ability_b = ability_b_match.group(1)
            
            if job_name or ability:
                results.append({
                    "file": file,
                    "job": job_name,
                    "ability": ability,
                    "ability_b": ability_b
                })

print("CLASS AUDIT RESULTS:")
for r in results:
    print(f"File: {r['file']} | Job: {r['job']} | Ability: {r['ability']} | Ability B: {r['ability_b']}")
