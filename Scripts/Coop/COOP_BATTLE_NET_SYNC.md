# ENet mock co-op — battle sync audit

Scope: **mock co-op unit ownership** + **`CoopExpeditionSessionManager.uses_enet_coop_transport()`** + battle `coop_battle_sync` messages.  
Loopback / single-machine mock co-op is separate (no wire).

## Wire actions (see `CoopExpeditionSessionManager._enet_apply_incoming_coop_battle_sync`)

| Action | Direction | Applied via | Notes |
|--------|-----------|-------------|--------|
| `battle_rng_seed` | Host → guest | Immediate | Locks global `seed()` + combat seq for packed IDs. |
| `player_combat_request` | Guest → host | Immediate → `BattleField` | Host-only resolution for **guest** player strikes/heals. |
| `player_combat_request_nack` | Host → guest | Immediate | Unblocks guest if request invalid. |
| `enemy_combat` | Host → guest | Buffered FIFO | AI/enemy strikes; snapshot preferred. |
| `player_move` | Either | Remote queue | Partner unit mirror only (`MOCK_COOP_OWNER_REMOTE`). |
| `player_defend` | Either | Remote queue | Same. |
| `player_combat` | Either | Remote queue | Partner mirror **or** guest `host_authority` + `auth_snapshot`. |
| `player_post_combat` | Either | Remote queue | Canto / finish mirror; `host_authority` for guest’s own unit. |
| `player_finish_turn` | Either | Remote queue | Partner unit only. |

Anything **not** in this table is **not** replicated on the wire today.

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
