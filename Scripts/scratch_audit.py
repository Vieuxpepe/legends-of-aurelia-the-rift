import sys
import re

def audit_file(filepath, list_var):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    match = re.search(f'const {list_var} := \\[(.*?)\\]', content, re.DOTALL)
    if not match:
        return
    text = match.group(1)

    dicts = []
    depth = 0
    current_dict = ""
    for char in text:
        if char == '{':
            depth += 1
            current_dict += char
        elif char == '}':
            depth -= 1
            current_dict += char
            if depth == 0:
                dicts.append(current_dict)
                current_dict = ""
        elif depth > 0:
            current_dict += char

    print(f"\n--- FILE: {filepath} ({len(dicts)} units) ---")
    issues_found = False
    for d in dicts:
        id_m = re.search(r'\"id\":\s*\"(.*?)\"', d)
        uid = id_m.group(1) if id_m else 'Unknown'
        
        stats_match = re.search(r'\"stats\":\s*\{(.*?)\}', d)
        if stats_match:
            stats_str = stats_match.group(1)
            try:
                hp = int(re.search(r'\"hp\":\s*(\d+)', stats_str).group(1))
                st = int(re.search(r'\"str\":\s*(\d+)', stats_str).group(1))
                mag = int(re.search(r'\"mag\":\s*(\d+)', stats_str).group(1))
                defense = int(re.search(r'\"def\":\s*(\d+)', stats_str).group(1))
                res = int(re.search(r'\"res\":\s*(\d+)', stats_str).group(1))
                spd = int(re.search(r'\"spd\":\s*(\d+)', stats_str).group(1))
                agi = int(re.search(r'\"agi\":\s*(\d+)', stats_str).group(1))
                
                total_stats = hp + st + mag + defense + res + spd + agi
                tier_m = re.search(r'\"tier\":\s*(\d+)', d)
                tier = int(tier_m.group(1)) if tier_m else 1
                stats_target = {1: 45, 2: 60, 3: 75, 4: 110}.get(tier, 50)
                if total_stats < stats_target - 5: # Small threshold
                    print(f"[{uid}] STILL LOW total stats for tier {tier}: {total_stats}")
                    issues_found = True
            except Exception as e:
                pass
    if not issues_found:
        print("All units scaled correctly.")

audit_file('Scripts/GenericEnemyDataGenerator.gd', 'ENEMIES')
