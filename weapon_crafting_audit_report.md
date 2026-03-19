# Weapon Crafting Coverage Audit Report

**Date:** Audit pass (V1).  
**Scope:** Recipe source of truth, all weapon resources, recipe integrity, and classification of craftable vs non-craftable.

---

## 1. Files Inspected

| File / Location | Purpose |
|-----------------|---------|
| `Scripts/RecipeDatabase.gd` | Single source of truth for all recipes (autoload). |
| `Scenes/camp_menu.gd` | Blacksmith UI; uses `RecipeDatabase.master_recipes` by recipe `name`, loads `recipe["result"]` path. |
| `Scripts/WeaponAuditReport.gd` | Existing weapon duplicate/name audit (EditorScript); does not check recipes. |
| `Scripts/BossUnitDataGenerator.gd` | Boss weapon_name → path mapping (WEAPON_PATHS); identifies boss-signature weapons. |
| `Resources/GeneratedItems/Weapon_*.tres` | 84 current weapon resources. |
| `Resources/Weapons/*.tres` | 11 legacy weapon resources. |

---

## 2. Source of Truth for Crafting Recipes

- **Location:** `RecipeDatabase.gd` (autoload `RecipeDatabase`).
- **Structure:** `master_recipes: Array[Dictionary]`. Each recipe has:
  - `name`: Display name (used for unlock matching and recipe book).
  - `ingredients`: Array of material display names.
  - `result`: **Resource path string** (e.g. `res://Resources/GeneratedItems/Weapon_Rusty_Sword.tres`).
  - Optional: `is_structure`, `is_smelt`, `structure_type`, `icon_path`.
- **Matching:** Camp checks `CampaignManager.unlocked_recipes.has(recipe["name"])`. Crafting loads the item with `load(recipe["result"])`. No other recipe sources found; all weapon recipes live in `RecipeDatabase.gd`.

---

## 3. Total Weapons Found

| Source | Count |
|--------|-------|
| `Resources/GeneratedItems/Weapon_*.tres` | 84 |
| `Resources/Weapons/*.tres` (legacy) | 11 |
| **Total unique weapon files** | **95** |

(Some legacy and generated weapons may represent the same logical weapon; e.g. Knight's Halberd exists in both recipe → GeneratedItems and boss → same file.)

---

## 4. Craftable Weapons Already Covered

These **32 weapon recipes** in `RecipeDatabase.gd` point to an existing resource and are used by the blacksmith:

**Early game (10):**  
Bone Sword → `Weapons/BoneSword.tres`, Savage Axe → `GeneratedItems/Weapon_Bronze_Axe.tres` (fixed from missing IronAxe.tres), Rusty Sword, Traveler's Blade, Old Spear, Wooden Pike, Hatchet, Bronze Axe, Apprentice Tome, Beginner's Staff.

**Mid game (8):**  
Steel Sword, Heavy Blade, Pike of Valor, Knight's Halberd, Steel Axe, War Axe, Arcane Grimoire, Healing Staff.

**Late game (8):**  
Silver Sword, Flame Blade, Silver Lance, Thunder Pike, Great Axe, Wind Cleaver, Flame Tome, Thunder Staff.

**End game (8):**  
Excalibur, Dragonfang, Holy Lance, Dragon Spear, Doom Hammer, Windslayer Axe, Celestial Tome, Elysian Staff.

All except Savage Axe use either `Resources/Weapons/` (Bone Sword only) or `Resources/GeneratedItems/Weapon_*.tres`; those paths exist.

---

## 5. Missing Recipes (Likely Intended to Be Craftable)

GeneratedItems weapons that look like normal player progression arms and have **no recipe**:

- **Swords:** Iron Sword, Sunsteel Brand, Oathcutter.
- **Bows:** Crude Bow, Ash Shortbow, Hunter's Bow, Longbow, Reinforced Bow, Storm Bow.
- **Lances / pikes:** Bronze Pike (only Old Spear / Wooden Pike / Pike of Valor have recipes).
- **Axes:** Raider's Splitter, Forgemaw Axe, Titan Breaker.
- **Knives / daggers:** Scrap Knife, Street Dirk, Sparkknife (Bellhook has boss use but is also a generic knife; no recipe).
- **Guns / cannons:** Militia Handgonne, Rustlock Pistol, Ramshackle Culverin, Siege Repeater (only Broker's Handgonne exists as boss; no generic craft).
- **Tomes:** Fire Tome (recipe exists), Gale Lexicon, Prism Tome, Starfire Codex, Gloam Primer, Hexleaf Codex.
- **Staffs:** Heal Staff (legacy exists), Protect Staff, Censure Staff (Censer Rod boss fallback).
- **Knuckles:** Pilgrim's Knuckles, Wrapped Cestus, Ironbound Cestus, Temple Gauntlets, Meteor Knuckles.

**Conservative “missing recipe” list (high confidence):**  
Iron Sword, Sunsteel Brand, Oathcutter, Crude Bow, Ash Shortbow, Hunter's Bow, Longbow, Reinforced Bow, Storm Bow, Bronze Pike, Raider's Splitter, Forgemaw Axe, Titan Breaker, Scrap Knife, Street Dirk, Sparkknife, Militia Handgonne, Rustlock Pistol, Ramshackle Culverin, Siege Repeater, Gale Lexicon, Prism Tome, Starfire Codex, Gloam Primer, Hexleaf Codex, Protect Staff, Censure Staff, Pilgrim's Knuckles, Wrapped Cestus, Ironbound Cestus, Temple Gauntlets, Meteor Knuckles.

(Exact count depends on how many of these you consider “must have” recipes; the list above is the set that fits current progression patterns.)

---

## 6. Likely Non-Craftable Weapons

- **Boss-signature (BossUnitDataGenerator WEAPON_PATHS / ENCOUNTERS):**  
  Rift Rite Tome, Grave Thesis, Shadowglass Knives, Silence Staff, Broker's Handgonne, Blackened Lance, Edict Staff, Bellhook Knife, Judgment Pike, Chain-Key Staff, Verdict Blade, Dark Tide Grimoire, Null Hymn.  
  (Knight's Halberd, Steel Axe, Pike of Valor, Silver Lance are both craftable and used by bosses; leave as-is.)

- **Boss fallbacks only (no canonical player version):**  
  Censer Rod → Censure Staff fallback; Ledger Needle / Masquerade Needle → Sparkknife/Bellhook fallbacks. No need to add recipes for “Ledger Needle” or “Masquerade Needle” as separate weapons.

- **Support / music / ritual:**  
  Dawn Harp, Veil Tambour, Court Lute, Festival Bell, Silken Fan (weapon_type 9 / support). Treat as non-craftable unless design says otherwise.

- **Legacy / test:**  
  Legendary TEST Sword, legacy FireTome/HellfireTome/TomeOfFireBeam, Protect Staff.tres / Heal Staff.tres in `Weapons/` (duplicates of GeneratedItems naming). Prefer not adding recipes pointing at legacy paths; use GeneratedItems where possible.

- **Dragon / endgame unique:**  
  Dragonfang, Dragon Spear, etc. already have recipes. No additional “dragon-only” weapon without a recipe was found.

---

## 7. Suspicious Recipe Path Mismatches / Legacy Issues

- **Savage Axe → (was) `res://Resources/Weapons/IronAxe.tres`**  
  **Fixed during audit:** `IronAxe.tres` did not exist. Recipe `result` was updated to `res://Resources/GeneratedItems/Weapon_Bronze_Axe.tres` so the recipe no longer fails at craft time.

- **Bone Sword → `res://Resources/Weapons/BoneSword.tres`**  
  Path exists. Optional later: consider moving to GeneratedItems and updating recipe for consistency.

- All other weapon recipes use `res://Resources/GeneratedItems/Weapon_*.tres` and the referenced files exist; no other path mismatches found.

---

## 8. Duplicate / Legacy Issues

- **WeaponAuditReport.gd** already flags duplicates by `weapon_name` and normalized name; it prefers GeneratedItems over `Resources/Weapons/`. No duplicate *recipes* for the same weapon (same result path or same logical weapon) were found.
- **Legacy weapons** (e.g. Heal Staff.tres, Protect Staff.tres, Crude Bow.tres, FireTome.tres) live in `Resources/Weapons/`. Recipes correctly point to GeneratedItems where present; only Bone Sword and Savage Axe point to `Weapons/`. Recommendation: keep recipes on GeneratedItems; add new recipes only for GeneratedItems paths.

---

## 9. Recommended Next Patch Actions

1. **Broken recipe (fixed during audit):**  
   Savage Axe in `RecipeDatabase.gd` now points to `res://Resources/GeneratedItems/Weapon_Bronze_Axe.tres`. No further change required unless you prefer a different axe or a dedicated Iron Axe resource.

2. **Add missing recipes (optional, tiered):**  
   - **High priority (common progression):** Iron Sword, Crude Bow, Longbow, Hunter's Bow, Ash Shortbow, Bronze Pike, Scrap Knife, Street Dirk, Militia Handgonne, Heal Staff (if desired; Heal Staff already has a recipe → Healing Staff – confirm naming), Protect Staff, Censure Staff, Pilgrim's Knuckles, Wrapped Cestus.  
   - **Mid priority:** Reinforced Bow, Storm Bow, Raider's Splitter, Forgemaw Axe, Titan Breaker, Sparkknife, Rustlock Pistol, Ramshackle Culverin, Siege Repeater, Gale Lexicon, Prism Tome, Starfire Codex, Gloam Primer, Hexleaf Codex, Ironbound Cestus, Temple Gauntlets, Meteor Knuckles.  
   - **Lower / flavor:** Sunsteel Brand, Oathcutter.

3. **Do not add recipes for:**  
   Boss-signature weapons (Rift Rite Tome, Grave Thesis, Shadowglass Knives, etc.), support/music weapons (Dawn Harp, Court Lute, etc.), or legacy-only assets until migrated to GeneratedItems.

4. **Consistency:**  
   New recipes should use `res://Resources/GeneratedItems/Weapon_<Name>.tres` and follow existing tier/ingredient patterns in `RecipeDatabase.gd`.

---

## 10. Summary Table

| Category | Count |
|----------|--------|
| Weapon recipe entries (weapons) in RecipeDatabase | 32 |
| Recipe result paths that exist | 32 (Savage Axe fixed → Weapon_Bronze_Axe.tres) |
| Recipe result paths missing (broken) | 0 |
| GeneratedItems weapons total | 84 |
| GeneratedItems with recipe | 30 |
| GeneratedItems without recipe (candidate for new recipes) | 54 |
| Boss/signature + support (do not add recipe) | ~18 |
| Legacy Weapons .tres files | 11 |
