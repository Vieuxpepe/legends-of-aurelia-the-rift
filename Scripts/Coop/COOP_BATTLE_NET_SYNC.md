# ENet mock co-op — battle sync audit

Scope: **mock co-op unit ownership** + **`CoopExpeditionSessionManager.uses_enet_coop_transport()`** + battle `coop_battle_sync` messages.  
Loopback / single-machine mock co-op is separate (no wire).

## Wire actions (see `CoopExpeditionSessionManager._enet_apply_incoming_coop_battle_sync`)

| Action | Direction | Applied via | Notes |
|--------|-----------|-------------|--------|
| `battle_rng_seed` | Host → guest | Immediate | Locks global `seed()` + combat seq for packed IDs. |
| `player_combat_request` | Guest → host | Immediate → `BattleField` | Host-only resolution for **guest** player strikes/heals. Optional `active_ability_id` for `ActiveCombatAbilityData` (host runs `execute_async`, then `player_combat` includes `active_ability_only`). Host serializes overlapping requests (busy → `player_combat_request_nack`); guest wait has a **45s** timeout so UI cannot soft-lock. |
| `player_combat_request_nack` | Host → guest | Immediate | Unblocks guest if request invalid. |
| `enemy_combat` | Host → guest | Buffered FIFO | AI/enemy strikes; snapshot preferred. |
| `player_move` | Either | Remote queue | Partner unit mirror only (`MOCK_COOP_OWNER_REMOTE`). |
| `player_defend` | Either | Remote queue | Same. |
| `player_combat` | Either | Remote queue | Partner mirror **or** guest `host_authority` + `auth_snapshot`. `active_ability_only` skips strike replay for data-driven actives. |
| `full_battle_resync` | Host → guest | Immediate | After ENet **reconnect** while a battle is registered: host sends `resync_schema` **1** + `units[]` (runtime wire rows + `parent_kind`) + counters + optional `battle_seed`. Guest applies via `BattleFieldCoopBattleRuntimeHelpers.apply_full_battle_resync_from_host` then re-applies mock ownership from the existing handoff. Large maps may hit packet-size limits (host emits a debug warning when serialized JSON exceeds ~32k characters). |
| `player_post_combat` | Either | Remote queue | Canto / finish mirror; `host_authority` for guest’s own unit. |
| `player_finish_turn` | Either | Remote queue | Partner unit only. |

Anything **not** in this table is **not** replicated on the wire today.

### Peer disconnect (ENet)

- `ENetCoopTransport` notifies `CoopExpeditionSessionManager` (`_enet_host_on_client_disconnected` / `_enet_guest_on_transport_disconnected`). Staging clears remote payload; **battle** registration stays until `BattleField` exits and unregisters.
- While unwired, `enet_send_coop_battle_sync_action` **drops** outbound `coop_battle_sync` (see `is_runtime_coop_session_wired()`), so neither side can complete authoritative sync until the session is restored.
- `notify_runtime_coop_battle_transport_peer_lost()` → `BattleField.coop_enet_on_transport_peer_lost()` clears guest combat wait + host busy flag (no combat log here; grace / solo messages own the UX).
- **Reconnect grace (in battle, ENet):** `CoopExpeditionSessionManager.RUNTIME_COOP_RECONNECT_GRACE_SEC` (default **90s**) and `RUNTIME_COOP_RECONNECT_USE_TREE_PAUSE` (default **false** = battle-only soft-freeze).
  - **Tree pause (`USE_TREE_PAUSE` true):** `get_tree().paused = true` during grace. `CoopExpeditionSessionManager` still ticks (`PROCESS_MODE_ALWAYS`) and refreshes the on-battle **overlay** (`get_runtime_coop_reconnect_grace_remaining_sec()`).
  - **Soft pause (default):** `BattleField.coop_reconnect_grace_blocks_gameplay()` gates `TurnOrchestrationHelpers.process` and `BattleField._unhandled_input` so the battle does not advance, while global UI/menus can remain usable.
  - **Overlay:** top-of-screen countdown + short mode hint; driven from `CoopExpeditionSessionManager._process` whenever grace is active (so it updates even under tree pause).
- If the peer **reconnects** in time: grace cleared, unpaused / soft-freeze cleared, host calls `enet_send_runtime_full_battle_resync_to_guest()` ( **`full_battle_resync`** wire) so the guest can realign to host state.
- If **not**:
  - **Host:** `runtime_coop_host_solo_after_partner_dropout` becomes true → outbound runtime battle sync stops; partner-owned units are promoted to **local** command on the host battlefield until the battle ends.
  - **Guest:** grace expiry calls `leave_session()` after unpause / overlay hide.

---

## System-by-system

### Combat (weapon attacks, staves, abilities in `execute_combat`)

- **Host local units**: Runs on host; guest applies snapshot / mirror path. **Good.**
- **Guest local units**: Delegated to host (`player_combat_request`); guest applies `auth_snapshot`. **Good.**
- **Residual risk**: `get_relationship_id` collisions; snapshot not replaying every `_on_unit_died` side effect (loot/counters) unless encoded in snapshot.

### Healing / buff staves

- Same forecast → `execute_combat` path as attacks → **covered** by the same co-op combat flow (including guest delegation).

### Player move / defend / finish turn

- **Synced** for commands on **eligible local-owned** units (`coop_enet_sync_*` + partner mirror).  
- Ordering is FIFO + small timer between packets; extreme lag could theoretically reorder perception, not separate sim.

### AI / enemy phase

- **Host-led** with `enemy_combat` + authoritative snapshot when available. **Good.**

### Chests (`BattleField._on_chest_opened` → `_process_loot`)

- **Not synced.** Uses **`randf()`** per loot row (`Scripts/Core/BattleField.gd`).  
- **Effect**: Opener’s machine grants items / keys; partner sees no matching packet → **inventory & log desync**.

### Trade (`open_trade_window` / swaps)

- **Not synced.** Inventory changes are local only.  
- **Effect**: Partner sees stale inventories and wrong combat stats until something else resyncs (nothing automatic).

### Talk / recruit (`execute_talk`)

- **Not synced.** Moves unit to `player_container`, sets flags, campaign hooks.  
- **Effect**: **Hard desync** if only one peer runs it.

### Support talk (`play_support_dialogue` / `_on_support_talk_pressed`)

- **Not synced.** Mutates support bonds / dialogue state.  
- **Effect**: Campaign/support data diverges between peers.

### Environmental / tile damage (e.g. fire on move)

- **Not explicitly synced**, but if **both** follow the **same move packets** and **same combat snapshots**, tile triggers should usually match.  
- **Risk**: Any hazard that rolls RNG outside `execute_combat` without a shared seed step can diverge (audit per hazard).

### Level-up, promotion, item rewards UI mid-battle

- **Not audited per UI**; anything that uses **local-only** `randf`/`randi` or writes **CampaignManager** without a wire step can diverge.

### Victory / defeat / battle exit

- Driven by local battle state. If prior steps desynced, **end state can disagree** (chest/trade/talk are the usual culprits).

### Fog of war

- Derived locally from units/tiles. Should match if **unit positions and vision rules** match; not a separate net layer.

---

## Suggested priority for follow-up work

1. **Chest open** — Host-authoritative: opener sends `chest_opened` with `chest_id`, `resolved_loot[]` (or seed index); guest applies same items / key consumption.  
2. **Trade** — Serialize a trade “commit” (unit A/B ids + slot indices or item ids) from initiator; mirror on peer.  
3. **Recruit / support talk** — Single “authoritative” peer (host) runs mutation; send compact result payload for guest to apply (or forbid action on guest until host confirms).  
4. **Hardening** — Reject guest-originated `player_combat` for **local** attacker when `host_authority` is false (prevents double simulation if something bypasses delegate).  
5. **IDs** — Stabilize unit/chest identity (not display names) for all wire payloads.

---

## Related code entry points

- `CoopExpeditionSessionManager.enet_send_coop_battle_sync_action` / `_enet_apply_incoming_coop_battle_sync`  
- `BattleField.apply_remote_coop_enet_sync` → `_coop_run_one_remote_sync_async`  
- `BattleField.coop_enet_*` combat helpers  
- `PlayerTurnState._handle_action_target_click` (combat + chest + trade entry)

## Player-facing connection (no debug hotkey required)

- **World map** → co-op expedition node → **Expedition Charter** opens `ExpeditionCharterStagingUI` with **Host LAN game**, **Join LAN game**, and **Same-PC rehearsal** (loopback).  
- **Join friend's LAN (co-op)** on the expedition prompt connects as ENet guest, then opens the charter (avoids becoming a loopback host first).  
- **Ctrl+Shift+P** debug panel on the world map remains optional for developers.
