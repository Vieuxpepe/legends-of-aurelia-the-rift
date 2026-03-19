# ==============================================================================
# Script Name: ScavengerManager.gd
# Purpose: Handles asynchronous salvage-network sharing via SilentWolf (circulating relics, grey-market recovery).
# Dependencies: SilentWolf, CampaignManager, ArenaManager.
# ==============================================================================

extends Node

var current_scavenger_stock: Array[Dictionary] = []
## After fetch_network_items: "ok" = items loaded; "empty" = no items surfaced; "error" = request failed.
var last_fetch_status: String = "ok"
const DEBUG_SCAVENGER: bool = false

## Donates an item to the network; quantity defaults to 1 (stackables can pass more). Returns total gold reward.
func donate_item(item: Resource, player_name: String, quantity: int = 1) -> int:
	if quantity <= 0: return 0
	var serialized_item: Dictionary = CampaignManager._serialize_item(item)
	if serialized_item.is_empty(): return 0

	var player_id: String = ArenaManager.get_safe_player_id()
	serialized_item["player_id"] = player_id
	serialized_item["donor_name"] = player_name
	serialized_item["scavenger_quantity"] = clampi(quantity, 1, 999)

	var random_sort_value: int = randi_range(1, 100000)
	SilentWolf.Scores.save_score(player_id, random_sort_value, "scavenger_network", serialized_item)

	var base_cost = item.get("gold_cost") if item.get("gold_cost") != null else 10
	var per_unit: int = max(1, int(base_cost * 0.25))
	return per_unit * quantity
	
func fetch_network_items(count: int = 5) -> void:
	current_scavenger_stock.clear()
	last_fetch_status = "ok"

	var _sw_result = await SilentWolf.Scores.get_scores(50, "scavenger_network").sw_get_scores_complete
	var cloud_items = SilentWolf.Scores.scores

	if cloud_items == null:
		last_fetch_status = "error"
		return
	if cloud_items.is_empty():
		last_fetch_status = "empty"
		return

	cloud_items.shuffle()
	
	# Get the current device ID to prevent self-trading
	var local_player_id = ArenaManager.get_safe_player_id()
	
	var items_added = 0
	for data in cloud_items:
		if items_added >= count:
			break
			
		var meta = data.get("metadata", {})
		if meta.is_empty(): continue

		# Filter out our own donations so we never see or buy back our own items.
		if str(meta.get("player_id", "")) == local_player_id:
			continue
		
		var donor = meta.get("donor_name", "")
		if str(donor).strip_edges().is_empty():
			donor = "Origin obscured"
		var rebuilt_item = CampaignManager._deserialize_item(meta)
		
		if rebuilt_item != null:
			var score_id: String = str(data.get("score_id", ""))
			var qty: int = int(meta.get("scavenger_quantity", 1))
			if qty <= 0: qty = 1
			# Subtract already-claimed quantity for this player so refresh does not resurface claimed items.
			var already_claimed: int = CampaignManager.get_claimed_scavenger_quantity(score_id)
			var remaining: int = qty - already_claimed
			if remaining <= 0:
				if DEBUG_SCAVENGER:
					push_warning("Scavenger fetch: skip score_id %s (remaining %d)" % [score_id, remaining])
				continue
			current_scavenger_stock.append({
				"item": rebuilt_item,
				"donor": str(donor),
				"score_id": score_id,
				"quantity": remaining
			})
			items_added += 1

## Removes the whole entry from session (legacy single-item claim).
func remove_item_from_network(score_id: String) -> void:
	for i in range(current_scavenger_stock.size() - 1, -1, -1):
		if current_scavenger_stock[i].get("score_id") == score_id:
			current_scavenger_stock.remove_at(i)
			break

## Reduces session entry quantity by amount; removes entry when quantity reaches 0. Returns true if entry was removed.
func reduce_network_entry_quantity(score_id: String, amount: int) -> bool:
	for i in range(current_scavenger_stock.size()):
		if current_scavenger_stock[i].get("score_id") != score_id:
			continue
		var entry: Dictionary = current_scavenger_stock[i]
		var qty: int = int(entry.get("quantity", 1))
		qty -= amount
		if qty <= 0:
			current_scavenger_stock.remove_at(i)
			return true
		entry["quantity"] = qty
		return false
	return false
			
	# Note: We do not actively delete the score from SilentWolf. 
	# Leaving it in the cloud allows multiple players to "find" the same discarded legendary item,
	# which fits the Dark Fantasy vibe perfectly (like finding bloodstains/remnants in Dark Souls).
	# Old items will naturally fall off the list as new ones are donated!
