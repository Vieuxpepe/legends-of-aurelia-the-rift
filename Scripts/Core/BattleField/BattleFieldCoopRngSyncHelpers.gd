extends RefCounted

# ENet mock co-op: battle RNG seed + packed combat id reseed — extracted from `BattleField.gd`.
# State remains on the field: `_coop_net_have_battle_seed`, `_coop_net_stored_battle_seed`, `_coop_net_local_combat_seq`.


static func _seed_global_for_packed_combat_id(field, packed_id: int) -> void:
	if not field._coop_net_have_battle_seed:
		return
	seed(hash(str(field._coop_net_stored_battle_seed) + "#" + str(packed_id)))


## Called on host + guest when the session locks RNG for this battle ([method CoopExpeditionSessionManager.enet_try_publish_coop_battle_rng_seed]).
static func apply_coop_battle_net_rng_seed(field, s: int) -> void:
	field._coop_net_stored_battle_seed = s
	field._coop_net_have_battle_seed = true
	field._coop_net_local_combat_seq = 0
	seed(s)
	if OS.is_debug_build():
		print("[CoopBattleRNG] Global seed locked (base=%d)." % s)


static func coop_net_rng_sync_ready(field) -> bool:
	return field._coop_net_have_battle_seed


## Call immediately before [method execute_combat] on the attacker's machine. Returns packed id for the wire (guest vs host ranges avoid collisions).
static func coop_enet_begin_synchronized_combat_round(field) -> int:
	if not field._coop_net_have_battle_seed:
		return -1
	if field._mock_coop_ownership_assignments.is_empty():
		return -1
	if not CoopExpeditionSessionManager.uses_runtime_network_coop_transport():
		return -1
	if CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.NONE:
		return -1
	field._coop_net_local_combat_seq += 1
	var hi: int = 1 if CoopExpeditionSessionManager.phase == CoopExpeditionSessionManager.Phase.HOST else 0
	var packed: int = hi * 1_000_000_000 + field._coop_net_local_combat_seq
	_seed_global_for_packed_combat_id(field, packed)
	return packed


static func coop_enet_apply_remote_combat_packed_id(field, packed: int) -> void:
	if packed < 0:
		return
	_seed_global_for_packed_combat_id(field, packed)
