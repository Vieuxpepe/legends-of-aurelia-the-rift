# Read-only BBCode snippets for weapon rune persistence fields (Pass 3 visibility).
# No gameplay; safe tokens only for display.
class_name WeaponRuneDisplayHelpers
extends RefCounted

## Display-only: stored primitive ids are unchanged; keys are normalized lowercase for lookup.
const _RUNE_ID_DISPLAY_LABELS: Dictionary = {
	"ember": "Ember Rune",
	"ember_rune": "Ember Rune",
	"swift": "Swift Rune",
	"swift_rune": "Swift Rune",
	"flux": "Flux Rune",
	"flux_rune": "Flux Rune",
	"ward": "Ward Rune",
	"ward_rune": "Ward Rune",
}

## Elder Futhark (Unicode Runic U+16A0–U+16FF) for UI flavor — thematic, not historical spellings.
const BLACKSMITH_POP_GLYPH: String = "ᛏ"  # Tiwaz
const _RUNE_VIKING_GLYPH_BY_KEY: Dictionary = {
	"ember": "ᛊ",
	"ember_rune": "ᛊ",  # Sowilo — sun / flame
	"swift": "ᚱ",
	"swift_rune": "ᚱ",  # Raidho — rhythm / journey
	"flux": "ᛞ",
	"flux_rune": "ᛞ",  # Dagaz — daybreak / turning point
	"ward": "ᛉ",
	"ward_rune": "ᛉ",  # Algiz branch — shelter / ward
}


static func normalized_rune_id_key(stored_id: String) -> String:
	return str(stored_id).strip_edges().to_lower().replace(" ", "_")


static func viking_rune_glyph_for_key(key: String) -> String:
	var k: String = normalized_rune_id_key(key)
	if _RUNE_VIKING_GLYPH_BY_KEY.has(k):
		return str(_RUNE_VIKING_GLYPH_BY_KEY[k])
	return ""


static func blacksmith_rune_button_glyph_for_id(rune_id_raw: String) -> String:
	return viking_rune_glyph_for_key(rune_id_raw)


## Short catalog name without Elder Futhark prefix (for forge previews / logs).
static func catalog_name_for_rune_id(stored_id: String) -> String:
	var key: String = normalized_rune_id_key(stored_id)
	if _RUNE_ID_DISPLAY_LABELS.has(key):
		return str(_RUNE_ID_DISPLAY_LABELS[key])
	return _sanitize_token(str(stored_id))


static func _sanitize_token(s: String) -> String:
	return str(s).strip_edges().replace("[", "(").replace("]", ")").substr(0, 64)


static func _display_label_for_stored_rune_id(stored_id: String) -> String:
	var raw: String = str(stored_id).strip_edges()
	if raw == "":
		return ""
	var key: String = raw.to_lower().replace(" ", "_")
	if _RUNE_ID_DISPLAY_LABELS.has(key):
		var base: String = str(_RUNE_ID_DISPLAY_LABELS[key])
		var g: String = viking_rune_glyph_for_key(key)
		if g != "":
			return "%s %s" % [g, base]
		return base
	return _sanitize_token(raw)


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
			var seg: String = _display_label_for_stored_rune_id(rid)
			var rk: int = int(e.get("rank", 0))
			if rk != 0:
				seg += " · r%d" % clampi(rk, 0, 999)
			if e.has("charges"):
				var ch: int = int(e.get("charges", 0))
				if ch != 0:
					seg += " · ×%d" % clampi(ch, 0, 999999)
			id_parts.append(seg)

	if slot_count <= 0 and id_parts.is_empty():
		return ""

	var lines: Array[String] = []
	if slot_count > 0:
		lines.append("[color=#c4a8f0]Rune sockets[/color] [color=#8a7868](%d max)[/color]" % slot_count)
	if not id_parts.is_empty():
		if id_parts.size() == 1:
			lines.append("[color=#c4a8f0]Inscribed:[/color] %s" % id_parts[0])
		else:
			lines.append("[color=#c4a8f0]Inscribed[/color]")
			var idx: int = 0
			for part in id_parts:
				idx += 1
				lines.append("  [color=#a090c0]%d.[/color] %s" % [idx, part])
	elif slot_count > 0:
		lines.append("[color=#888888][i]No runes yet — use SOCKET (stone) or the glyph row (materials).[/i][/color]")

	return "\n".join(lines)
