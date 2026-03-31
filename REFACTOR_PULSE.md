# BattleField Refactor Pulse (Eye / Tracking Doc)

## Purpose
This document tracks the ongoing “heavy refactor” work inside `Scripts/Core/BattleField.gd` by:
1. Tracing each extraction we completed (what moved where).
2. Recording parity / correctness checks we ran (lint + targeted behavior notes).
3. Listing the next high-risk refactor targets with clear checkpoints so we can maintain an “eye on drift”.

**Convention:** Every completed extraction is recorded as a numbered milestone under **Completed Refactor Milestones**, and a short entry is appended to **Verification log** when checks are run for that milestone.

## Ground rules (parity-first)
- Extract by delegation: helper scripts call back into the *existing* `BattleField` instance for internal state, so scene wiring / call sites remain stable.
- Keep function signatures and call patterns the same where practical.
- After each milestone: run static `ReadLints` and execute at least one in-engine smoke path for awaited/visual sections.

---

## Completed Refactor Milestones

### 1) Co-op extraction (authoritative snapshot + wire item serialization)
- Moved to: `Scripts/Core/BattleField/BattleFieldCoopHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Key extracted methods:
  - `coop_wire_serialize_items(...)`
  - `coop_wire_deserialize_items(...)`
  - `coop_wire_resource_path(...)`
  - `coop_wire_serialize_item_single(...)`
  - `coop_wire_deserialize_item_single(...)`
  - `coop_net_build_authoritative_combat_snapshot(...)`
  - `coop_apply_authoritative_combat_snapshot(...)`
- Parity notes:
  - Snapshot version gating (`COOP_AUTH_BATTLE_SNAPSHOT_VER`) preserved.
  - Post-snapshot application order preserved (`rebuild_grid()`, fog/objective updates, validation).

### 2) Support / relationship Phase 2 extraction
- Moved to: `Scripts/Core/BattleField/BattleFieldSupportHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Key extracted methods:
  - `normalize_support_rank(field, bond)`
  - `get_support_combat_bonus(field, unit)`
  - `apply_hit_with_support_reactions(field, victim, damage, source, exp_tgt, is_redirected)`
- Lint fix:
  - Explicit boolean typing for `is_allied` to satisfy GDScript static analysis.

### 3) Inventory / loot UI helpers extraction (spacing + loot window flow)
- Moved to: `Scripts/Core/BattleField/BattleFieldInventoryUiHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Key extracted methods:
  - `apply_inventory_panel_spacing(field)`
  - `populate_unit_inventory_list(field)`
  - `wait_for_loot_window_close(field)`
  - `show_loot_window(field)` (async tween + item processing)
- Parity notes:
  - Async behavior preserved by keeping `await` behavior at the same call sites.

### 4) `_draw()` overlay delegation (pre-battle + danger/reachable/attackable + threat + reinforcement)
- Moved to: `Scripts/Core/BattleField/BattleFieldDrawHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Parity-sensitive fix:
  - Pre-battle deployment overlay parity was tuned to remove drift:
    - removed overlay gate
    - restored original alpha values + border width
    - removed unintended snap-highlight rendering in that helper path

### 5) Cursor / path preview extraction (this session, refactor 1 of 2)
- Moved to: `Scripts/Core/BattleField/BattleFieldPathfindingCursorHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Delegated wrappers:
  - `update_cursor_pos()`
  - `update_cursor_color()`
  - `_update_locked_inspect_cursor()`
  - `_get_inspect_cursor_tint(unit)`
  - `_set_cursor_state(cursor_node, state_name)`
  - `_apply_cursor_accessibility_settings()`
  - `_is_neutral_inspect_unit(unit)`
  - `draw_preview_path()`
  - `get_path_preview_tick_positions_for_draw()`
- Parity-sensitive areas:
  - Ghost/invalid/valid path styling + endpoint marker + tick update.
  - Locked inspect cursor tinting + occlusion behavior.

### 6) Trade / inventory / loot logic + grid rebuild extraction (this session, refactor 2 of 2)
- Moved to: `Scripts/Core/BattleField/BattleFieldTradeInventoryHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Delegated wrappers:
  - `_populate_convoy_list()`
  - `_clear_grids()`
  - `_build_grid_items(...)`
  - `_execute_trade_swap(...)`
  - `_on_close_loot_pressed()` (async loot distribution + flying icon animation + exact matching to UI buttons)
- Parity-sensitive areas:
  - Convoy stacking rules (stack only in convoy, not personal grids).
  - Exact “looted item refs” matched to exact UI buttons in order (including stackable matching).
  - Await ordering (tween finished + process frame delays) and closure capture in flying icon impacts.

### 7) Combat orchestration extraction (quotes -> strike -> dual strike -> retaliation)
- Moved to: `Scripts/Core/BattleField/BattleFieldCombatOrchestrationHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Delegated wrapper:
  - `execute_combat(attacker, defender, trigger_active_ability)` now delegates to the helper (with `await` to preserve coroutine sequencing).
- Verification performed:
  - `ReadLints` on both `BattleField.gd` and the new combat helper: clean.
- Parity-sensitive areas:
  - Boss/pre-attack quote flow ordering (staff bypass preserved).
  - Dual strike chance math + timer ordering + re-validation before the partner strike.
  - Retaliation stagger timing and counter gating (`is_in_range`, staff bypass).

### 8) Inventory action extraction (equip/use logic + promotion await path)
- Moved to: `Scripts/Core/BattleField/BattleFieldInventoryActionHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Delegated wrappers:
  - `_on_equip_pressed()` now delegates to helper.
  - `_on_use_pressed()` now delegates to helper with `await` to preserve async promotion choice flow.
- Verification performed:
  - `ReadLints` on `BattleField.gd` and the new inventory action helper: clean.
- Parity-sensitive areas:
  - Promotion-item `await _ask_for_promotion_choice(...)` continuation still resumes on the same frames.
  - Cancel path returns to `_on_open_inv_pressed()` exactly as before.
  - Gain application: HP/stats, `run_theatrical_stat_reveal` awaiting, then `finish_turn()` + `rebuild_grid()` + `clear_ranges()` ordering.

### 9) Promotion choice UI extraction (branching class cards + cancel)
- Moved to: `Scripts/Core/BattleField/BattleFieldPromotionChoiceUiHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Delegated wrapper:
  - `_ask_for_promotion_choice(options)` now delegates to helper (with `await` preserved).
- Verification performed:
  - `ReadLints` on `BattleField.gd` + promotion UI helper: clean.
- Parity-sensitive areas:
  - Signal semantics: helper uses `field.emit_signal("promotion_chosen", ...)` and awaits `field.promotion_chosen` (must match old `await self.promotion_chosen` behavior).
  - Cancel path emits `null` exactly as before.
  - Ensure promo `CanvasLayer` is freed after a selection/cancel (no lingering overlay).

### 10) Promotion VFX helpers extraction (buildup/burst particle constructors)
- Moved to: `Scripts/Core/BattleField/BattleFieldPromotionVfxHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Delegated wrappers:
  - `_create_evolution_buildup_vfx(target_pos)`
  - `_create_evolution_burst_vfx(target_pos)`
- Verification performed:
  - `ReadLints` on `BattleField.gd` + promotion VFX helper: clean.
- Parity-sensitive areas:
  - Node ownership: particles still attach to the same `BattleField` parent (`field.add_child(vfx)`), so transforms/lifetime match.
  - Property parity: amount/lifetime/preprocess/velocity/scale/gradients unchanged.

### 11) Objective UI system extraction (setup + toggle + update)
- Moved to: `Scripts/Core/BattleField/BattleFieldObjectiveUiHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Delegated wrappers:
  - `_setup_objective_ui()`
  - `_on_objective_toggle_pressed()`
  - `update_objective_ui(skip_animation := false)`
- Helper dependencies (kept in `BattleField.gd`):
  - `_build_enemy_reinforcement_objective_bbcode()`
  - `_build_mock_coop_player_phase_readiness_bbcode_suffix()`
- Verification performed:
  - `ReadLints` on `BattleField.gd` + objective UI helper: clean.
- Parity-sensitive areas:
  - UI node wiring: `objective_toggle_btn.pressed.connect(_on_objective_toggle_pressed)` preserved (connects to the delegating wrapper).
  - Tween ownership: tweens still created by `BattleField` via `field.create_tween()`.
  - Quest/bounty objective height logic + tick sound playback preserved.

### 12) Cinematic dialogue overlay extraction (pause + UI snapshot + overlay)
- Moved to: `Scripts/Core/BattleField/BattleFieldCinematicDialogueHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Delegated wrappers:
  - `play_cinematic_dialogue(...)` now delegates with `await` preserved.
  - `_capture_ui_visibility_snapshot()`
  - `_set_ui_children_visible(visible)`
  - `_restore_ui_visibility_snapshot(snapshot)`
- Verification performed:
  - `ReadLints` on `BattleField.gd` + cinematic dialogue helper: clean.
- Parity-sensitive areas:
  - Pause semantics: helper uses `field.get_tree().paused = true/false` with `Tween.TWEEN_PAUSE_PROCESS`.
  - UI hiding: snapshot/restore still uses `field.ui_root` children and `CanvasItem.visible`.
  - Dialogue advance: helper emits `field.emit_signal("dialogue_advanced")` and awaits `field.dialogue_advanced` exactly like before.
  - Camera wake: `field.main_camera.process_mode = Node.PROCESS_MODE_ALWAYS` preserved.

### 13) Minimap toggle extraction
- Moved to: `Scripts/Core/BattleField/BattleFieldMinimapHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Delegated wrapper:
  - `_toggle_minimap()` now delegates to helper.
- Verification performed:
  - `ReadLints` on `BattleField.gd` + minimap helper: clean.
- Parity-sensitive areas:
  - Open/close SFX pitch changes preserved (1.2 open, 0.8 close).
  - Redraw on open preserved (`map_drawer.queue_redraw()`).

### 14) Status icon VFX extraction (shield drop)
- Moved to: `Scripts/Core/BattleField/BattleFieldStatusIconVfxHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Delegated wrapper:
  - `animate_shield_drop(unit)` now delegates to helper.
- Forward intent:
  - This helper is intended to become the centralized home for **other status icon animations** later (e.g., buffs/debuffs, stance icons), not just the shield/defend drop.
- Verification performed:
  - `ReadLints` on `BattleField.gd` + status icon VFX helper: clean.
- Parity-sensitive areas:
  - `DefendIcon` node lookup preserved via `unit.get_node_or_null("DefendIcon")`.
  - Tween settings preserved (bounce drop position + alpha fade-in).

### 15) Combat VFX spawners extraction (dash/slash/level-up/blood)
- Moved to: `Scripts/Core/BattleField/BattleFieldCombatVfxHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Delegated wrappers:
  - `spawn_dash_effect(start_pos, target_pos)`
  - `spawn_slash_effect(target_pos, attacker_pos, is_crit := false)`
  - `spawn_level_up_effect(target_pos)`
  - `spawn_blood_splatter(target_unit, attacker_pos, is_crit := false)`
- Verification performed:
  - `ReadLints` on `BattleField.gd` + combat VFX helper: clean.
- Parity-sensitive areas:
  - Scene instantiation + `z_index` + transforms preserved.
  - `process_mode` override for level-up FX preserved.
  - Blood particle parameters + timer cleanup preserved.

### 16) Gold VFX extraction (coin fountain + label tick-up)
- Moved to: `Scripts/Core/BattleField/BattleFieldGoldVfxHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Delegated wrapper:
  - `animate_flying_gold(world_pos, amount)` now delegates to helper.
- Verification performed:
  - `ReadLints` on `BattleField.gd` + gold VFX helper: clean.
- Parity-sensitive areas:
  - UI parenting: coins still spawn under `UI` (helper uses `field.get_node("UI")`).
  - Coin tween phases (burst -> stagger -> fly -> impact callback) preserved.
  - Gold label tick-up + micro-bounce + clink SFX preserved.

### 17) Turn/state orchestration extraction (spine: process + phase transitions + mock-coop gates)
- Moved to: `Scripts/Core/BattleField/BattleFieldTurnOrchestrationHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Delegated wrappers:
  - `_process(delta)` now delegates to helper.
  - `change_state(new_state)` now delegates to helper with `await` preserved.
  - `_process_spawners(faction_id)` now delegates to helper with `await` preserved.
  - `_on_skip_button_pressed()`, `_on_ally_turn_finished()`, `_on_enemy_turn_finished()` now delegate to helper (and keep prior await/non-await behavior: only enemy-finish awaits).
  - Mock co-op readiness helpers now delegate to helper:
    - `_sanitize_player_phase_active_unit_for_mock_coop_ownership()`
    - `_mock_coop_player_phase_ready_sync_active()`
    - `_reset_mock_coop_player_phase_ready_state()`
    - `_mock_coop_try_advance_player_phase_after_ready_sync()`
    - `_mock_coop_set_local_player_phase_ready(send_sync := true)`
    - `_process_mock_partner_placeholder_frame()`
    - `_local_player_fielded_commandable_units_all_exhausted()`
    - `_should_pulse_skip_button_end_turn_nudge()`
- Verification performed:
  - `ReadLints` on `BattleField.gd` + turn orchestration helper: clean.
- Parity-sensitive areas:
  - **Async call semantics preserved**: sites that previously called `change_state(...)` without `await` still call the delegating `field.change_state(...)` without `await` inside the helper, preserving coroutine fire-and-forget behavior where it already existed.
  - **Phase banners + spawner processing** ordering preserved (awaited inside `change_state`).
  - **Escort convoy** path preserved including host/guest gates and early victory `return`.
  - **Skip button** auto-defend + co-op ready gating preserved before transitioning to ally/enemy.
  - **Enemy turn finish** preserves burn tick timing, turn increment, survive/defend victory check, then returns to player phase.

### 18) Defensive reaction QTE extraction (parry + shield clash + last stand)
- Moved to: `Scripts/Core/BattleField/BattleFieldDefensiveReactionHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Delegated wrappers:
  - `_run_parry_minigame(defender)`
  - `_run_shield_clash_minigame(defender, attacker)`
  - `_run_last_stand_minigame(defender)`
- Parity-sensitive areas:
  - Pause semantics preserved for Parry + Last Stand (`field.get_tree().paused = true` + `CanvasLayer.process_mode = ALWAYS` + pause-safe timers).
  - Shield Clash keeps its original non-paused timing loop (uses `field.get_process_delta_time()` and `field.create_tween()` flashes).
  - Calls into existing `BattleField` utilities preserved (`spawn_loot_text`, `screen_shake`, `_apply_battlefield_qte_ui_polish`, `miss_sound`).

### 19) Defensive reaction flow extraction (orchestration glue: mirror + outcomes)
- Moved to: `Scripts/Core/BattleField/BattleFieldDefensiveReactionFlowHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Extracted orchestration:
  - Shield Clash: co-op QTE mirror read/write + heal + perfect counter damage + combat log + floaters.
  - Universal Parry: co-op QTE mirror read/write + counter damage + combat log + floater.
  - Last Stand: co-op QTE mirror read/write + lethal override (`final_dmg = 0`, `is_crit = false`) + trigger counts/log/floater.
- Parity-sensitive areas:
  - RNG ordering preserved (Shield Clash roll only when ability is Shield Clash; Parry roll performed when reaching that branch).
  - Local state updates preserved via helper return dict (`defense_resolved_and_won`, `ability_triggers_count`, `death_defied`, `final_dmg`, `is_crit`).

### 20) Phase D defensive abilities extraction (full ladder)
- Moved to: `Scripts/Core/BattleField/BattleFieldDefensiveAbilityFlowHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Extracted ladder (Phase D):
  - Weapon Shatter, Celestial Choir, Phalanx, Divine Protection (stacking `if`), Arcane Shift, Shield Bash, Unbreakable Bastion, Inner Peace, Holy Ward, Blink Step, then fallback Shield Clash / Universal Parry (via `BattleFieldDefensiveReactionFlowHelpers.gd`).
- Returned state (parity-first):
  - `incoming_damage_multiplier`, `defense_resolved_and_won`, `ability_triggers_count`, `_weapon_shatter_triggered`, `celestial_choir_hits`.
- Parity-sensitive areas:
  - Preserved the original `if` vs `elif` shape (Divine Protection can still stack after Weapon Shatter / Celestial Choir / Phalanx).
  - Preserved co-op QTE mirror read/write event ordering inside each branch.

### 21) Phase E normal attack resolution extraction (damage application pipeline)
- Moved to: `Scripts/Core/BattleField/BattleFieldAttackResolutionHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Extracted (Phase E):
  - Defensive multiplier application to `damage`
  - Impact juice sequencing (`_play_critical_impact`, guard-break impact, hit-stop)
  - Poise reduction + guard-break visuals
  - No-damage handling
  - Lethal detection + Miracle + Last Stand (via `BattleFieldDefensiveReactionFlowHelpers.gd`)
  - Hit application + follow-up hit/splash chains + miss logic
- Parity-sensitive areas:
  - Context-driven extraction: Phase E relies on many locals; helper receives them via a `Dictionary` so ordering/await behavior remains identical.
  - Co-op QTE mirror event ordering for Miracle/Last Stand remains intact inside Phase E.

### 22) Phase F+G extraction (post-strike cleanup + forced movement tactics)
- Moved to:
  - Phase F: `Scripts/Core/BattleField/BattleFieldPostStrikeCleanupHelpers.gd`
  - Phase G: `Scripts/Core/BattleField/BattleFieldForcedMovementTacticalHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Extracted:
  - Phase F: attacker return tween + weapon durability decrement + broken feedback (floater + shake + SFX)
  - Phase G: Fire Trap + Shove/Grapple Hook forced movement, including co-op QTE mirror read/write and crash damage application
- Parity-sensitive areas:
  - Phase G keeps the trailing `await create_timer(0.25).timeout` regardless of whether an ability was forced (helper preserves this).
  - Co-op QTE event ids are explicitly typed (`int`) in the helper to satisfy static analysis and preserve mirror ordering.

### 23) Phase H combat cleanup extraction (temp-meta teardown)
- Moved to: `Scripts/Core/BattleField/BattleFieldCombatCleanupHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Extracted:
  - End-of-strike temp-meta removals for both `attacker` and `defender` (Inner Peace, Frenzy, Holy Ward, etc.)
- Parity-sensitive areas:
  - Keeps the same “iterate attacker+defender, null/valid guard, remove metas if present” pattern.

### 24) Strike sequence routing extraction (shim + seam)
- Moved to: `Scripts/Core/BattleField/BattleFieldStrikeSequenceHelpers.gd`
- Delegated from: `Scripts/Core/BattleField.gd`
- Change:
  - `BattleField.gd` now delegates `_run_strike_sequence(...)` to the helper.
  - The original implementation body was renamed to `_run_strike_sequence_impl(...)` and is invoked by the helper.
- Purpose:
  - Establishes a clean seam so the full strike-sequence body can be moved out next without touching call sites again.

### 25) Full `_run_strike_sequence_impl(...)` relocation — Codex audit checklist (reference)
- Use this list when reviewing the strike-sequence helper diff (see milestone **#26** below).

### 26) Strike sequence full body relocation (atomic overwrite) — **completed**
- **Moved to:** `Scripts/Core/BattleField/BattleFieldStrikeSequenceHelpers.gd` — full static `run_strike_sequence(field, ...)` body (~1627 lines), with preloads for Phase D–H helpers already used by the sequence.
- **Removed from:** `Scripts/Core/BattleField.gd` — `_run_strike_sequence_impl(...)` deleted; only `_run_strike_sequence(...)` → `StrikeSequenceHelpers.run_strike_sequence(self, ...)` remains.
- **Mechanical generation:** `tools/gen_strike_sequence_helper.py` implemented the extraction + `field.*` pass (fix: member regex must use concatenated `r\"\\b\"`, not `rf\"...\\\\b...\"`, or word boundaries silently fail). The script is **historical** after this move (see file header); re-run only if you restore `_run_strike_sequence_impl` from git.
- **Codex review checklist (same as former #25):**
  - Helper contains the full strike body (no truncation / no TODO markers).
  - Scan for stray unqualified BattleField members (examples: `create_tween`, `add_child`, `player_container`, `enemy_container`, `_coop_qte_*`, `ability_triggers_count`, `loot_recipient`).
  - External singletons/constants unchanged (`WeaponData`, `FloatingCombatText`, `QTEManager`); first arg to QTE minigames is `field` not `self`.
  - Phase D → E → F → G → H order and `await` usage unchanged.
- **Verification:** `ReadLints` on `BattleField.gd` + `BattleFieldStrikeSequenceHelpers.gd` — clean after this pass.

### 27) ENet co-op runtime sync queue + QTE mirror utilities extraction — **completed**
- **Moved to:** `Scripts/Core/BattleField/BattleFieldCoopRuntimeSyncHelpers.gd`
- **Delegated from:** `Scripts/Core/BattleField.gd`
- **Extracted:**
  - QTE mirror/capture utility surface:
    - `_coop_qte_tick_reset_for_execute_combat()`
    - `coop_net_begin_local_combat_qte_capture()`, `coop_net_end_local_combat_qte_capture()`
    - `coop_net_begin_local_combat_loot_capture()`, `coop_net_end_local_combat_loot_capture()`
    - `coop_net_apply_remote_combat_qte_snapshot()`, `coop_net_clear_remote_combat_qte_snapshot()`
    - `_coop_qte_alloc_event_id()`, `_coop_qte_mirror_read_int()`, `_coop_qte_mirror_read_bool()`, `_coop_qte_capture_write()`
  - Remote sync queue pump/dispatch seam:
    - `apply_remote_coop_enet_sync(body)`
    - `_coop_enet_pump_remote_sync_queue()`
- **Parity-sensitive areas:**
  - The queue still schedules `_coop_run_one_remote_sync_async(next_body)` via a pause-safe timer (`create_timer(0.0, true, true, true)`) and preserves the same `CONNECT_ONE_SHOT` hookup.
  - All state (queue, busy flag, mirror/capture dictionaries) remains owned by `BattleField`; helper only manipulates it via delegation.
- **Verification:** `ReadLints` on `BattleField.gd` + `BattleFieldCoopRuntimeSyncHelpers.gd` — clean.

### 28) Player combat-turn confirm orchestration extraction — **completed**
- **Moved to:** `Scripts/Core/BattleField/BattleFieldCombatTurnHelpers.gd`
- **Delegated from:** `Scripts/States/PlayerTurnState.gd`
- **Extracted (post-forecast confirm):**
  - Guest host-delegated combat request path (wait for host, handle canto return, clear selection).
  - Local combat path: synchronized RNG packed id, QTE + loot capture snapshots, `await execute_combat`, pause-wait loop, authoritative snapshot build, canto vs finish-turn resolution, and optional `coop_enet_sync_local_combat_done(...)`.
- **Parity-sensitive areas:**
  - Maintains the exact `await` boundaries (forecast → combat → pause drain) and keeps all state owned by `PlayerTurnState` (`active_unit`, `clear_active_unit()`), with helper only mutating the same fields the old inline block did.
- **Verification:** `ReadLints` on `PlayerTurnState.gd` + `BattleFieldCombatTurnHelpers.gd` — clean.

### 29) Combat forecast panel extraction — **completed**
- **Moved to:** `Scripts/Core/BattleField/BattleFieldCombatForecastHelpers.gd`
- **Delegated from:** `Scripts/Core/BattleField.gd`
- **Extracted:**
  - `show_combat_forecast(attacker, defender)` — full math + UI + `await forecast_resolved` + cleanup (same `field.*` delegation pattern).
- **Parity-sensitive areas:**
  - Signal await remains `await field.forecast_resolved`; UI node references use `field.forecast_*` / `field.target_cursor` etc.
- **Verification:** `ReadLints` on `BattleField.gd` + `BattleFieldCombatForecastHelpers.gd` — clean.

### 30) ENet co-op `player_combat_request` host/guest extraction — **completed**
- **Moved to:** `Scripts/Core/BattleField/BattleFieldCoopCombatRequestHelpers.gd`
- **Delegated from:** `Scripts/Core/BattleField.gd`
- **Extracted:**
  - `coop_enet_guest_delegate_player_combat_to_host(...)`
  - `coop_enet_guest_receive_combat_request_nack(body)`
  - `_coop_host_send_player_combat_request_nack(attacker_id)` (host nack wire)
  - Host resolution coroutine formerly `_coop_host_resolve_player_combat_request_async` → `coop_host_resolve_player_combat_request_async(field, body)` (kept `_coop_host_start_player_combat_request` as `call_deferred` entry + `await` helper).
- **Parity-sensitive areas:**
  - Guest wait loop still `await field.coop_guest_host_combat_resolved`; host path still `await execute_combat` → loot → snapshot → `coop_enet_sync_local_combat_done` with `host_authority` semantics preserved via `true` flag in sync call.
- **Verification:** `ReadLints` on `BattleField.gd` + `BattleFieldCoopCombatRequestHelpers.gd` — clean.

### 31) ENet mock co-op remote sync action dispatch — **completed**
- **Moved to:** `Scripts/Core/BattleField/BattleFieldCoopRemoteSyncActionHelpers.gd`
- **Delegated from:** `Scripts/Core/BattleField.gd`
- **Extracted:**
  - `coop_run_one_remote_sync_async(field, body)` — `match action` dispatch, busy flag, queue pump.
  - Per-action handlers: enemy phase setup, battle result, escort turn, enemy turn move/combat/finish/chest/escape/end/batch move, prebattle layout/ready, player move/defend/combat/post-combat/finish turn, player phase ready.
  - Batch enemy moves use `coop_do_batch_unit_move_async(...)` only inside the helper (removed duplicate from `BattleField`).
- **Parity-sensitive areas:**
  - `_coop_wait_for_enemy_state_ready()` remains on `BattleField`; helper awaits `field._coop_wait_for_enemy_state_ready()` where the inline code did.
  - `await` preserved on wrappers for async paths (battle result, escort, enemy turns, batch move, player move/combat).
- **Verification:** `ReadLints` on `BattleField.gd` + `BattleFieldCoopRemoteSyncActionHelpers.gd` — clean.

### 32) ENet co-op enemy / AI combat net execution — **completed**
- **Moved to:** `Scripts/Core/BattleField/BattleFieldCoopEnemyCombatNetHelpers.gd`
- **Delegated from:** `Scripts/Core/BattleField.gd`
- **Extracted:**
  - `coop_enet_buffer_incoming_enemy_combat(field, body)` — guest FIFO buffer for host-led enemy strike packets.
  - `coop_enet_ai_execute_combat(field, attacker, defender, used_ability)` — non-network fall-through, host-authority enemy turn (`enemy_turn_combat` + destructible spoils), generic host (`enemy_combat`), guest FIFO wait + `_coop_execute_remote_combat_replay` + auth snapshot + loot events.
- **Parity-sensitive areas:**
  - Order of operations preserved: `execute_combat` → loot window wait → end QTE/loot capture where applicable; `auth_v` / packet keys unchanged.
  - Host-authority payload dict kept separate from parameter name (`combat_body` vs `body`) to avoid shadowing in the helper.
- **Verification:** `ReadLints` on `BattleField.gd` + `BattleFieldCoopEnemyCombatNetHelpers.gd`; Godot Level1 smoke — clean load (no parser/runtime errors from this change).

### 33) ENet co-op outbound wire actions (host authority + local player) — **completed**
- **Moved to:** `Scripts/Core/BattleField/BattleFieldCoopOutboundSyncHelpers.gd`
- **Delegated from:** `Scripts/Core/BattleField.gd`
- **Extracted (host → peer):**
  - `coop_enet_sync_after_host_authority_enemy_move/finish_turn/escape/chest_open/enemy_turn_end`
  - `coop_enet_sync_enemy_turn_batch_move`
  - `coop_enet_sync_after_host_authority_enemy_phase_setup`
  - `coop_enet_sync_after_host_authoritative_battle_result` → delegates `field._coop_send_host_authoritative_battle_result`
  - `coop_enet_sync_after_host_authority_escort_turn`
- **Extracted (local player → peer):**
  - Internal: `_coop_enet_sync_eligible_command_unit`, `_build_local_mock_coop_prebattle_layout_snapshot` (no longer on `BattleField`; only referenced from this helper).
  - `coop_enet_sync_after_local_prebattle_layout_change`, `coop_enet_sync_after_local_player_move`, `coop_enet_sync_after_local_defend`, `coop_enet_sync_local_combat_done`, `coop_enet_sync_after_local_finish_turn`
- **Parity-sensitive areas:**
  - Payload keys, `auth_v`, path serialization, escort convoy fields, destructible chest `stolen_items` wire format unchanged.
  - Public `BattleField` method names unchanged for `has_method` / turn-state callers.
- **Verification:** `ReadLints` on `BattleField.gd` + `BattleFieldCoopOutboundSyncHelpers.gd`; Godot Level1 smoke — clean load.

### 34) Co-op battle RNG sync + mock session (command IDs / camera / prebattle) — **completed**
- **Moved to:**
  - `Scripts/Core/BattleField/BattleFieldCoopRngSyncHelpers.gd` — `apply_coop_battle_net_rng_seed`, `coop_net_rng_sync_ready`, `coop_enet_begin_synchronized_combat_round`, `coop_enet_apply_remote_combat_packed_id` (packed-id reseed kept internal to helper).
  - `Scripts/Core/BattleField/BattleFieldCoopMockSessionHelpers.gd` — mock handoff/ownership API, command-id pipeline, `_coop_focus_camera_*` tweens, prebattle ready/start button + `_mock_coop_set_local_prebattle_ready` / `_mock_coop_clear_local_prebattle_ready`.
- **Delegated from:** `Scripts/Core/BattleField.gd` (thin wrappers; mock `var` / `MOCK_*` / camera margin consts remain on the field).
- **Parity-sensitive areas:**
  - Helpers avoid calling `field.is_mock_coop_unit_ownership_active()` from inside RNG begin path; use `field._mock_coop_ownership_assignments.is_empty()` so public delegates do not recurse.
  - `_coop_wait_for_enemy_state_ready()` unchanged on `BattleField` per plan.
  - Public `BattleField` names preserved for `has_method` / external `field._get_mock_coop_command_id` / camera callers.
- **Verification:** `ReadLints` on `BattleField.gd` + both new helpers — clean. Godot Level1 smoke — see log.

---

## Verification log
- `ReadLints` runs:
  - `BattleField.gd` + cursor helper: clean
  - `BattleField.gd` + trade helper: clean
- `ReadLints` runs:
  - `BattleField.gd` + combat orchestration helper: clean
- **Milestone #32 (2026-03-30):** `ReadLints` on `BattleField.gd` + `BattleFieldCoopEnemyCombatNetHelpers.gd` — clean. Godot 4.6 run `res://Scenes/Levels/Level1.tscn` — scripts reload, level boots past save load; no `Parser Error` / `ERROR:` from this change (pre-existing GDScript warnings only).
- **Re-verified (2026-03-31):** Godot 4.6 `res://Scenes/Levels/Level1.tscn` smoke boot boots clean again (only pre-existing warnings; no new parser/runtime errors observed from the enemy-combat helper wiring).
- **Milestone #33 (2026-03-30):** `ReadLints` on `BattleField.gd` + `BattleFieldCoopOutboundSyncHelpers.gd` — clean. Godot 4.6 Level1 smoke — same (no new hard errors).
- **Milestone #34 (2026-03-30):** `ReadLints` on `BattleField.gd` + `BattleFieldCoopRngSyncHelpers.gd` + `BattleFieldCoopMockSessionHelpers.gd` — clean. Godot 4.6 run `res://Scenes/Levels/Level1.tscn` — scripts reload, level boots; no new `Parser Error` / `ERROR:` attributable to this extraction (pre-existing warnings only).
- Visual parity checks:
  - `_draw()` pre-battle deployment overlay drift was corrected in `BattleFieldDrawHelpers.gd` and verified.
  - Cursor/path preview + loot-close still require runtime smoke confirmation for final “no drift” proof (lint does not validate visuals).

---

## Next Heavy Refactor Targets (proposed)
These are the next subsystems that are likely to be large and parity-sensitive.

### A) Combat turn orchestration extraction
- Target area in `BattleField.gd`:
  - turn-state transitions
  - `execute_combat` / main turn execution flow
  - QTE hooks timing with awaited UI/callback boundaries
- Proposed helper:
  - `Scripts/Core/BattleField/BattleFieldCombatTurnHelpers.gd`
- Checkpoints:
  1. No change in awaited sequencing (combat->UI->turn end).
  2. QTE start/finish still gates the same transitions.
  3. All grid rebuild / fog / objective updates occur at the same points.

### B) Remaining co-op sync extraction
- Target area:
  - any other co-op ENet runtime replay bits and sync calls not yet moved into `BattleFieldCoopHelpers.gd`
- Proposed helper:
  - either extend `BattleFieldCoopHelpers.gd` or introduce `BattleFieldCoopReplayHelpers.gd`
- Checkpoints:
  1. snapshot version handling preserved
  2. remote replay ordering preserved
  3. serialization/deserialization matches wire format expectations

### C) Promotion choice UI (now completed — keep for review)
- Target area:
  - `_ask_for_promotion_choice(options)` UI construction + button signal handlers
- Proposed helper:
  - `Scripts/Core/BattleField/BattleFieldPromotionChoiceUiHelpers.gd`
- Checkpoints:
  1. `promotion_chosen` emission still resolves the same `await` continuation from `_on_use_pressed()`
  2. cancel behavior still returns to the prior inventory panel
  3. no UI layers/tweens linger after the promo layer closes
- Status:
  - Completed in milestone **#9** above (left here intentionally so Codex can review what changed vs. the previously planned target).

### D) Promotion VFX helpers (buildup/burst) extraction
- Target area:
  - `_create_evolution_buildup_vfx(target_pos)`
  - `_create_evolution_burst_vfx(target_pos)`
- Proposed helper:
  - `Scripts/Core/BattleField/BattleFieldPromotionVfxHelpers.gd`
- Checkpoints:
  1. Node ownership: particles still attach to the same `BattleField` parent and position identically.
  2. Timings and one-shot behavior unchanged (no linger / no missing emission).
  3. No accidental property drift (amount/lifetime/velocity/scale/gradient).

---

## “Eye” checklist for each next milestone
When we do the next extraction, make sure we answer these before calling it done:
- Did we preserve `await` sequencing for user-visible transitions?
- Are all helper->field internal calls valid (no missing private methods / renamed members)?
- For UI-heavy logic: do we have at least one targeted runtime check (cursor preview, loot close, flying icon landing, etc.)?
- Do lints stay clean after each helper addition?

