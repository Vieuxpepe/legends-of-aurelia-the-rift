# Ability system verification — passive vs active (and why it can feel “flaky”)

This document reflects a **read-only audit** of `Scripts/Core`, `Scripts/Core/BattleField`, and `Resources/CombatActives` / `Resources/CombatPassives` as of the audit date. Use it when designing **raid bosses** or **co-op** so you know which hooks are authoritative.

---

## 1. Formal split on `UnitData` (authoritative for *data-driven* combat extras)

| Field | Resource type | Role |
|--------|----------------|------|
| `passive_combat_abilities` | `Array[PassiveCombatAbilityData]` | Always-on / event-driven rules (hit bonuses, on-hit status, bone pile reform, map01-style kits, etc.). |
| `active_combat_abilities` | `Array[ActiveCombatAbilityData]` | Cooldown-gated abilities. Runtime state: `Unit.active_ability_cooldowns`. Tick: `ActiveCombatAbilityHelpers.tick_all_units_phase` (via turn orchestration). |

**Sources:** `Scripts/Core/UnitData.gd` (categories “Passive combat abilities” / “Active combat abilities”), `Resources/CombatPassives/PassiveCombatAbilityData.gd`, `Resources/CombatActives/ActiveCombatAbilityData.gd`.

**Verdict:** For *these two arrays*, passive vs active **is** clearly separated: different types, different execution helpers (`CombatPassiveAbilityHelpers` vs `ActiveCombatAbilityHelpers` / `ActiveCombatAbilityExecutionHelpers`).

---

## 2. Passive pipeline (where it runs)

- **Merge:** `CombatPassiveAbilityHelpers.collect_passives(unit)` merges:
  - Authored `UnitData.passive_combat_abilities`
  - Presets from `UnitData.map01_enemy_kit` (`_kit_preset_resources`)
  - Dedupes by `PassiveCombatAbilityData.EffectKind` (first wins; kit fills gaps).
- **Consumers (non-exhaustive):** forecast extra lines + hit bonus (`BattleFieldCombatForecastFlowHelpers`), weapon-hit hooks (`BattleFieldAttackResolutionHelpers`), bone pile / skeleton flow, end-turn scorched tick (`BattleField` → `CombatPassiveAbilityHelpers.on_unit_finished_turn_scorched_tick`), beastiary display, spawner / startup `ensure_finished_turn_hook`.

**Verdict:** Passives in this system are **real, centralized, and mostly data-driven** once they live in `PassiveCombatAbilityData`.

---

## 3. Active pipeline (where it runs)

- **Definitions:** `ActiveCombatAbilityHelpers` reads `UnitData.active_combat_abilities`, matches `ability_id` to cooldown dict keys.
- **Player use:** `BattleFieldCombatTurnHelpers.resolve_player_active_ability_after_forecast` → `ActiveCombatAbilityExecutionHelpers.execute_async` (after forecast confirm; not the same code path as a normal “Attack” strike).
- **AI use:** `ActiveCombatAbilityExecutionHelpers` contains targeting / value estimates for enemy-side use.
- **Effect kinds today:** `TARGETED_SCRIPT`, `SELF_CENTERED` (`ActiveCombatAbilityData.EffectKind`).

**Verdict:** Actives are **a second, resource-based** system, parallel to legacy string abilities (below).

---

## 4. Legacy / parallel systems (main source of “flaky” *feel*)

These are **not** the same as `PassiveCombatAbilityData` / `ActiveCombatAbilityData`, but they still drive combat and UI.

| Mechanism | Where | Notes |
|-----------|--------|--------|
| `UnitData.ability` (`String`) | `Unit`, bosses, avatar | Large procedural combat in strike / orchestration (e.g. `BattleFieldStrikeSequenceHelpers`). Boss `BossUnitDataGenerator` sets `ability` string ids. |
| `ClassData.class_tactical_ability` | Class `.tres` | “Forecast tactical” slot when unit has no personal `ability` (Shove/Grapple-style); comments in `BattleField.gd` tie it to same UI slot as forced movement. |
| `ClassData.class_combat_ability` (+ `_b`) | Class `.tres` | Phase-B / QTE-linked proc skills; comments say first matching `elif` in BattleField wins vs personal `ability`. |
| Rookie / creation “passives” | `BattleField` helpers | e.g. `_compute_rookie_class_passive_mods` — **not** necessarily mirrored as `PassiveCombatAbilityData`. |
| Support combat | `BattleField` | Passive **bonuses** from adjacency; separate from `PassiveCombatAbilityData`. |

**Verdict:** The game has **more than two** notions of “ability”: data-driven passives/actives **plus** string-scripted kit **plus** class tactics **plus** support. That is **correct for legacy SRPG depth** but **easy to confuse** when debugging (“why didn’t my passive fire?” — which passive?).

---

## 5. Co-op guest + data-driven actives (host-authoritative path)

When `coop_enet_should_delegate_player_combat_to_host()` is true, the guest **does not** run `ActiveCombatAbilityExecutionHelpers.execute_async` locally. Instead:

- `resolve_player_active_ability_after_forecast` awaits `coop_enet_guest_delegate_player_combat_to_host(attacker_id, defender_id, false, active_ability_id)` so `player_combat_request` carries **`active_ability_id`**.
- The **host** resolves the cast in `BattleFieldCoopCombatRequestHelpers.coop_host_resolve_guest_data_driven_active_async` (same `execute_async` as solo), then `coop_enet_sync_local_combat_done` merges **`active_ability_only: true`** into the combat payload.
- On the guest, `coop_remote_sync_player_combat` treats **`active_ability_only`** as “no weapon strike replay”: it applies **`auth_snapshot`** (and loot events) only, avoiding bogus `execute_combat` replay when RNG was packed for a different path.

**Implication:** `ActiveCombatAbilityData` confirms from a guest-owned unit are **supported** in ENet delegation mode, but simulation remains **host-owned**; regression-test targeted + self-centered actives, canto, and death-after-cast edge cases in two-instance co-op.

---

## 6. Display vs simulation

- `Unit.gd` notes stacked passive labels as **display-oriented** until combat hooks read them — risk of **UI showing text** that doesn’t map 1:1 to `PassiveCombatAbilityData` if content authors mix systems.

---

## 7. Summary answers to “verify passive vs active”

1. **Are passives and actives formally separated?**  
   **Yes** for `UnitData.passive_combat_abilities` vs `UnitData.active_combat_abilities` (different resources, different helper entry points).

2. **Is everything passive/active *only* those arrays?**  
   **No.** Major gameplay still lives in **string `ability`**, **class tactics / class combat strings**, **support**, and **strike-sequence** branches.

3. **Why “flaky”?**  
   - Multiple parallel systems without one registry.  
   - Co-op guests **delegate** data-driven actives to the host (correct), but any new active effect must still be **snapshot-safe** for `auth_snapshot` apply.  
   - Precedence (personal vs class vs first `elif`) is code-order dependent for legacy strings.

---

## 8. Recommendations (for raids / bosses / future cleanup)

- **New raid boss effects:** Prefer **`PassiveCombatAbilityData` + `ActiveCombatAbilityData`** for anything you want documented, forecasted consistently, and (eventually) synced — **or** accept you are adding another `elif` branch to strike code.
- **Co-op raids:** After changing actives, smoke-test **guest confirm → host apply → guest mirror** (two clients); ensure new effects serialize into the combat **auth snapshot** path.
- **Optional consolidation doc:** A single table “effect X → implemented in [file:symbol]” would reduce author confusion (out of scope here unless you want a follow-up pass).

---

*End of ability verification.*
