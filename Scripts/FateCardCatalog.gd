## Fate card catalog and UI metadata for the Tavern Gambler system.
## Keeps card definitions out of UI/controller scripts so future gameplay hooks
## can read one source of truth.
extends RefCounted

const MAX_ACTIVE_CARDS: int = 3
const DRAW_CHIP_COST: int = 3
const STARTER_CARD_ID: String = "iron_route"

const CARDS: Array[Dictionary] = [
	{
		"id": "iron_route",
		"name": "Iron Route",
		"rarity": "common",
		"summary": "+5% post-battle iron income.",
		"description": "Scouts secure old mining roads. After battle victory, gain bonus iron from salvage routes.",
		"portrait_path": "res://Assets/Portraits/Branik Portrait.png"
	},
	{
		"id": "ash_watch",
		"name": "Ash Watch",
		"rarity": "common",
		"summary": "Reveal 1 extra enemy at start.",
		"description": "A smoke-marked watchpost reports first movement. In fog-heavy maps, start with extra enemy intel.",
		"portrait_path": "res://Assets/Portraits/Portrait Hero 1.png"
	},
	{
		"id": "ember_tithe",
		"name": "Ember Tithe",
		"rarity": "rare",
		"summary": "+1 random consumable after map clear.",
		"description": "The Ember Brokers always collect. On battle clear, one bonus consumable is added to rewards.",
		"portrait_path": "res://Assets/Portraits/Noemi Veyr Portrait.png"
	},
	{
		"id": "storm_compass",
		"name": "Storm Compass",
		"rarity": "rare",
		"summary": "+1 move for first player phase turn.",
		"description": "A chart that predicts lethal wind lanes. One allied unit can move farther on the opening push.",
		"portrait_path": "res://Assets/Portraits/Sorrel Portrait.png"
	},
	{
		"id": "void_tax",
		"name": "Void Tax",
		"rarity": "epic",
		"summary": "Elite enemies drop +1 void shard.",
		"description": "The house claims a piece of every anomaly. Enhanced enemies yield extra void shards when defeated.",
		"portrait_path": "res://Assets/Portraits/Portrait Malakor.png"
	},
	{
		"id": "wyrm_oath",
		"name": "Wyrm Oath",
		"rarity": "legendary",
		"summary": "Dragon units start with +10 poise.",
		"description": "Ancient drake compacts harden scales before battle. Dragon allies enter combat with bonus poise.",
		"portrait_path": "res://Assets/Portraits/Morgra Portrait.png"
	}
]


static func get_all_cards() -> Array[Dictionary]:
	return CARDS.duplicate(true)


static func get_card(card_id: String) -> Dictionary:
	var wanted: String = card_id.strip_edges().to_lower()
	for card_any in CARDS:
		var card: Dictionary = card_any
		if str(card.get("id", "")).strip_edges().to_lower() == wanted:
			return card.duplicate(true)
	return {}


static func get_rarity_rank(rarity: String) -> int:
	match rarity.strip_edges().to_lower():
		"legendary":
			return 4
		"epic":
			return 3
		"rare":
			return 2
		"common":
			return 1
		_:
			return 0


static func get_rarity_color(rarity: String) -> Color:
	match rarity.strip_edges().to_lower():
		"legendary":
			return Color(0.94, 0.74, 0.26, 1.0)
		"epic":
			return Color(0.78, 0.48, 0.98, 1.0)
		"rare":
			return Color(0.36, 0.72, 0.98, 1.0)
		"common":
			return Color(0.72, 0.74, 0.76, 1.0)
		_:
			return Color(0.70, 0.70, 0.70, 1.0)
