import os
import re

classes_root = "Resources/Classes"
results = []

# Regex patterns
job_re = re.compile(r'job_name\s*=\s*"([^"]+)"')
ability_a_re = re.compile(r'class_combat_ability\s*=\s*"([^"]+)"')
ability_b_re = re.compile(r'class_combat_ability_b\s*=\s*"([^"]+)"')

for root, dirs, files in os.walk(classes_root):
    for file in files:
        if file.endswith(".tres"):
            path = os.path.join(root, file)
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    job = job_re.search(content)
                    ab_a = ability_a_re.search(content)
                    ab_b = ability_b_re.search(content)
                    
                    if job:
                        results.append({
                            "path": os.path.relpath(path, classes_root),
                            "job": job.group(1),
                            "a": ab_a.group(1) if ab_a else "",
                            "b": ab_b.group(1) if ab_b else ""
                        })
            except:
                pass

results.sort(key=lambda x: x["path"])

with open("ability_audit_final.txt", "w", encoding="utf-8") as out:
    out.write(f"{'PATH':<40} | {'JOB':<15} | {'ABILITY A':<20} | {'ABILITY B'}\n")
    out.write("-" * 100 + "\n")
    for r in results:
        out.write(f"{r['path']:<40} | {r['job']:<15} | {r['a']:<20} | {r['b']}\n")
