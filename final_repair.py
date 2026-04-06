import os

# 1. Fix QTEManager.gd
mgr_path = "QTEManager.gd"
if os.path.exists(mgr_path):
    content = open(mgr_path, "r", encoding="utf-8").read()
    content = content.replace('\\"', '"')
    with open(mgr_path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Fixed QTEManager.gd syntax.")

# 2. Fix Templates internal references
templates = {
    "Scripts/Core/QTEWhackAMole.gd": "QTEWhackAMole",
    "Scripts/Core/QTEScratchLine.gd": "QTEScratchLine",
    "Scripts/Core/QTEGlideBox.gd": "QTEGlideBox",
    "Scripts/Core/QTEReactionFlash.gd": "QTEReactionFlash",
    "Scripts/Core/QTECollisionRush.gd": "QTECollisionRush"
}

for path, cls in templates.items():
    if os.path.exists(path):
        content = open(path, "r", encoding="utf-8").read()
        # Replace return type hint in static func run
        content = content.replace(f"-> {cls}:", "-> CanvasLayer:")
        # Replace .new() call
        content = content.replace(f"{cls}.new()", "load(\"res://\" + get_script().resource_path.trim_prefix(\"res://\")).new()")
        # Alternatively, just use .new() on the script itself if possible, but in static func we don't have self.
        # Let's just use a direct load of its own path to be safe.
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Modularized {path}")
