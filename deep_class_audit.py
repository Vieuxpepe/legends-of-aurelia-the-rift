import os
import re

classes_root = "Resources/Classes"
results = []

# Regex to find job_name and combat abilities in .tres files
job_re = re.compile(r'job_name\s*=\s*"(.*?)"')
ability_re = re.compile(r'class_combat_ability\s*=\s*"(.*?)"')
ability_b_re = re.compile(r'class_combat_ability_b\s*=\s*"(.*?)"')

for root, dirs, files in os.walk(classes_root):
    for file in files:
        if file.endswith(".tres"):
            path = os.path.join(root, file)
            try:
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read()
                    
                    job = job_re.search(content)
                    ab1 = ability_re.search(content)
                    ab2 = ability_b_re.search(content)
                    
                    job_name = job.group(1) if job else "Unknown Class"
                    a1 = ab1.group(1) if ab1 else ""
                    a2 = ab2.group(1) if ab2 else ""
                    
                    if a1 or a2:
                        relative_path = os.path.relpath(path, classes_root)
                        results.append({
                            "path": relative_path,
                            "job": job_name,
                            "ability_a": a1,
                            "ability_b": a2
                        })
            except Exception as e:
                pass

# Sort by path for readability
results.sort(key=lambda x: x["path"])

print(f"{'CLASS PATH':<40} | {'JOB NAME':<20} | {'ABILITY A':<20} | {'ABILITY B'}")
print("-" * 100)
for r in results:
    print(f"{r['path']:<40} | {r['job']:<20} | {r['ability_a']:<20} | {r['ability_b']}")

with open("full_class_audit.txt", "w", encoding="utf-8") as f:
    f.write(f"{'CLASS PATH':<40} | {'JOB NAME':<20} | {'ABILITY A':<20} | {'ABILITY B'}\n")
    f.write("-" * 100 + "\n")
    for r in results:
        f.write(f"{r['path']:<40} | {r['job']:<20} | {r['ability_a']:<20} | {r['ability_b']}\n")
