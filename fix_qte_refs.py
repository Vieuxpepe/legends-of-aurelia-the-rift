import re

with open("QTEManager.gd", "r", encoding="utf-8") as f:
    content = f.read()

# Pattern to find: QTE[Name].run(...)
# We want to catch things like QTEShrinkingRing.run, QTEMashMeter.run, etc.
# But avoid qte_script.run (which we already fixed)

# First, let's find all the unique QTE class names used with .run()
qte_classes = set(re.findall(r"(QTE[A-Za-z]+)\.run\(", content))

print(f"Found QTE classes: {qte_classes}")

for cls in qte_classes:
    # Pattern to replace:
    # var qte = QTESomething.run(...)
    # with:
    # var qte_script = load("res://Scripts/Core/QTESomething.gd")
    # var qte = qte_script.run(...)
    
    # We need to be careful with indentation.
    # We'll use a regex that captures the indentation.
    
    pattern = r"(\t+)var qte = " + re.escape(cls) + r"\.run\("
    replacement = r"\1var qte_script = load(\"res://Scripts/Core/" + cls + r".gd\")\n\1var qte = qte_script.run("
    
    content = re.sub(pattern, replacement, content)

# Special case for those I already changed to 'qte_script = load(...)' but maybe with direct class name somewhere else?
# Let's just do a generic "any instance of QTE[Name] used as a static caller"

with open("QTEManager.gd", "w", encoding="utf-8") as f:
    f.write(content)

print("Comprehensive QTE load() conversion complete.")
