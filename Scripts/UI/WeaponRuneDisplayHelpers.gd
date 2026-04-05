# Read-only BBCode snippets for weapon rune persistence fields (Pass 3 visibility).
# No gameplay; safe tokens only for display.
class_name WeaponRuneDisplayHelpers
extends RefCounted


static func _sanitize_token(s: String) -> String:
	return str(s).strip_edges().replace("[", "(").replace("]", ")").substr(0, 64)


static func format_runes_bbcode_for_item_variant(item: Variant) -> String:
	var slot_count: int = 0
	var runes_raw: Variant = null

	if item is Dictionary:
		var d: Dictionary = item as Dictionary
		if not d.has("rune_slot_count") and not d.has("socketed_runes"):
			return ""
		slot_count = clampi(int(d.get("rune_slot_count", 0)), 0, 8)
		runes_raw = d.get("socketed_runes", [])
	elif item is WeaponData:
		var w: WeaponData = item as WeaponData
		slot_count = clampi(w.rune_slot_count, 0, 8)
		runes_raw = w.socketed_runes
	else:
		return ""

	var id_parts: Array[String] = []
	if runes_raw is Array:
		for entry in runes_raw as Array:
			if not (entry is Dictionary):
				continue
			var e: Dictionary = entry as Dictionary
			var rid: String = str(e.get("id", "")).strip_edges()
			if rid == "":
				continue
			var seg: String = _sanitize_token(rid)
			var rk: int = int(e.get("rank", 0))
			if rk != 0:
				seg += " r%d" % clampi(rk, 0, 999)
			if e.has("charges"):
				var ch: int = int(e.get("charges", 0))
				if ch != 0:
					seg += " ×%d" % clampi(ch, 0, 999999)
			id_parts.append(seg)

	if slot_count <= 0 and id_parts.is_empty():
		return ""

	var lines: Array[String] = []
	if slot_count > 0:
		lines.append("[color=#c4a8f0]Rune slots:[/color] %d" % slot_count)
	if not id_parts.is_empty():
		lines.append("[color=#c4a8f0]Socketed:[/color] %s" % ", ".join(id_parts))
	elif slot_count > 0:
		lines.append("[color=#888888](none socketed)[/color]")

	return "\n".join(lines)
