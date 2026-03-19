# ==============================================================================
# Script Name: PersonalEncounterArcDB.gd
# Purpose: Lightweight data layer for playable-character personal encounter arcs.
# Overall Goal: Make units feel rooted in the world via setup/echo/payoff encounters
#   without a separate quest system. Used by EncounterDatabase for roster-based weighting.
# Project Fit: Narrative extension; no autoload. EncounterDatabase calls get_encounter_ids_preferred_for_roster().
# Dependencies: None (CampaignManager not required for lookups).
# AI/Code Reviewer Guidance:
#   - Entry: get_encounter_ids_preferred_for_roster(roster_unit_names).
#   - Arcs are content-only; encounter payloads (bonus_unit_name, flag_variants) live in EncounterDatabase.
# ==============================================================================

class_name PersonalEncounterArcDB
extends RefCounted

## Personal arc entry: unit_name, arc_id, encounter_ids (all; used for weight boost). Optional setup/echo/payoff_encounter_ids for legible arc structure (same IDs, no extra logic).
const PERSONAL_ARCS: Array[Dictionary] = [
	# Kaelen: old order guilt, ruined fortresses, veterans who remember.
	{
		"unit_name": "Kaelen",
		"arc_id": "kaelen_veterans",
		"encounter_ids": ["bell_tower_of_ashes", "iron_mine_cavein", "the_ashen_waystation", "collapsed_watchtower_store"]
	},
	# Liora: setup = Feast (vigil); echo = Abbey preferred when vigil kept; payoff = Abbey "Bow once" (recognized as rebuilding faith).
	{
		"unit_name": "Liora",
		"arc_id": "liora_faith_reform",
		"encounter_ids": ["feast_of_hollow_masks", "sealed_crypt_door", "broken_abbey_reliquary", "charred_wayfarer_shrine", "salt_road_hangings"],
		"setup_encounter_ids": ["feast_of_hollow_masks"],
		"echo_encounter_ids": ["sealed_crypt_door", "broken_abbey_reliquary"],
		"payoff_encounter_ids": ["broken_abbey_reliquary"]
	},
	# Nyx: setup = Smugglers Cistern (deal); echo = Vermin Cellar (contact); payoff = Cistern + Vermin (deniable trust, docks remember).
	{
		"unit_name": "Nyx",
		"arc_id": "nyx_undercity",
		"encounter_ids": ["vermin_cellar_below_inn", "smugglers_cistern", "chains_in_the_marsh", "feast_of_hollow_masks"],
		"setup_encounter_ids": ["smugglers_cistern"],
		"echo_encounter_ids": ["vermin_cellar_below_inn"],
		"payoff_encounter_ids": ["smugglers_cistern", "vermin_cellar_below_inn"]
	},
	# Rufus: setup = Shattered Aqueduct (repair); echo = Ashen Waystation when repaired; payoff = Aqueduct (labor trust).
	{
		"unit_name": "Rufus",
		"arc_id": "rufus_docks_labor",
		"encounter_ids": ["shattered_aqueduct", "the_ashen_waystation", "vermin_cellar_below_inn", "roadside_gallows_feast", "widows_at_the_forge"],
		"setup_encounter_ids": ["shattered_aqueduct"],
		"echo_encounter_ids": ["the_ashen_waystation"],
		"payoff_encounter_ids": ["shattered_aqueduct"]
	},
	# Celia: discipline, obedience, Valeron defector, chosen conscience.
	{
		"unit_name": "Celia",
		"arc_id": "celia_duty_conscience",
		"encounter_ids": ["purifier_checkpoint_ruin", "broken_abbey_reliquary", "feast_of_hollow_masks", "charred_wayfarer_shrine"]
	},
	# Garrick Vale: honor, hierarchy, Edranor officer, reform.
	{
		"unit_name": "Garrick Vale",
		"arc_id": "garrick_honor_reform",
		"encounter_ids": ["iron_mine_cavein", "widows_at_the_forge", "famine_wagon_at_dusk", "the_hunger_tithe"]
	},
	# Inez: setup = Ghosts of the Ferry (lay dead to rest); echo = Weeping Marsh when ferry laid; payoff = Ferry + Marsh (land remembers who tends it).
	{
		"unit_name": "Inez",
		"arc_id": "inez_stewardship",
		"encounter_ids": ["ghosts_of_the_ferry", "lanterns_on_the_grave_road", "weeping_marsh_reedfield", "charred_wayfarer_shrine", "bridge_of_rotten_planks"],
		"setup_encounter_ids": ["ghosts_of_the_ferry"],
		"echo_encounter_ids": ["weeping_marsh_reedfield"],
		"payoff_encounter_ids": ["ghosts_of_the_ferry", "weeping_marsh_reedfield"]
	},
	# Sister Meris: institutional severity, remorse, redemption vs purity.
	{
		"unit_name": "Sister Meris",
		"arc_id": "meris_redemption",
		"encounter_ids": ["purifier_checkpoint_ruin", "broken_abbey_reliquary", "feast_of_hollow_masks", "salt_road_hangings"]
	},
	# Branik: setup = Black Briar or Famine Wagon (refugees/labor); echo = Ashen Waystation; payoff = practical mercy, shelter, carrying weight.
	{
		"unit_name": "Branik",
		"arc_id": "branik_shelter",
		"encounter_ids": ["black_briar_refugee_camp", "famine_wagon_at_dusk", "the_ashen_waystation", "flooded_mill_ruins", "collapsed_bridge_crossing"],
		"setup_encounter_ids": ["black_briar_refugee_camp", "famine_wagon_at_dusk"],
		"echo_encounter_ids": ["the_ashen_waystation"],
		"payoff_encounter_ids": ["black_briar_refugee_camp", "the_ashen_waystation"]
	},
	# Brother Alden: setup = Plague Cart or Marrow Pit (rites, sick, dead); echo = shrine/abbey; payoff = faith as service, steadiness.
	{
		"unit_name": "Brother Alden",
		"arc_id": "alden_service",
		"encounter_ids": ["plague_cart_procession", "whispering_marrow_pit", "charred_wayfarer_shrine", "broken_abbey_reliquary", "feast_of_hollow_masks"],
		"setup_encounter_ids": ["plague_cart_procession", "whispering_marrow_pit"],
		"echo_encounter_ids": ["charred_wayfarer_shrine", "broken_abbey_reliquary"],
		"payoff_encounter_ids": ["plague_cart_procession", "whispering_marrow_pit"]
	},
	# Sabine Varr: setup = Smugglers or Vermin Cellar (League, docks); echo = the other; payoff = competence, order, no panic.
	{
		"unit_name": "Sabine Varr",
		"arc_id": "sabine_control",
		"encounter_ids": ["vermin_cellar_below_inn", "smugglers_cistern", "purifier_checkpoint_ruin", "chains_in_the_marsh"],
		"setup_encounter_ids": ["smugglers_cistern"],
		"echo_encounter_ids": ["vermin_cellar_below_inn"],
		"payoff_encounter_ids": ["vermin_cellar_below_inn", "smugglers_cistern"]
	},
	# Darian: setup = Gallows (class/conscience); echo = aqueduct or gentry; payoff = performance dropped, choosing decency.
	{
		"unit_name": "Darian",
		"arc_id": "darian_conscience",
		"encounter_ids": ["roadside_gallows_feast", "shattered_aqueduct", "feast_of_hollow_masks", "purifier_checkpoint_ruin"],
		"setup_encounter_ids": ["roadside_gallows_feast"],
		"echo_encounter_ids": ["shattered_aqueduct", "feast_of_hollow_masks"],
		"payoff_encounter_ids": ["roadside_gallows_feast"]
	},
	# Mira Ashdown: setup = ruin/rescue; echo = waystation or watchfire; payoff = survivor recognition, memory carried correctly.
	{
		"unit_name": "Mira Ashdown",
		"arc_id": "mira_survivor",
		"encounter_ids": ["the_ashen_waystation", "collapsed_bridge_crossing", "ravens_at_the_watchfire", "black_briar_refugee_camp"],
		"setup_encounter_ids": ["collapsed_bridge_crossing", "black_briar_refugee_camp"],
		"echo_encounter_ids": ["the_ashen_waystation", "ravens_at_the_watchfire"],
		"payoff_encounter_ids": ["collapsed_bridge_crossing", "the_ashen_waystation"]
	},
	# Tamsin Reed: setup = plague/famine care; echo = village gratitude; payoff = practical care, who stayed.
	{
		"unit_name": "Tamsin Reed",
		"arc_id": "tamsin_care",
		"encounter_ids": ["plague_cart_procession", "famine_wagon_at_dusk", "black_briar_refugee_camp", "widows_at_the_forge"],
		"setup_encounter_ids": ["plague_cart_procession", "famine_wagon_at_dusk"],
		"echo_encounter_ids": ["widows_at_the_forge"],
		"payoff_encounter_ids": ["famine_wagon_at_dusk", "plague_cart_procession"]
	},
	# Hest Sparks: setup = cistern/undercity; echo = vermin cellar contact; payoff = streets remember sideways.
	# unit_name "Hest Sparks" and "Hest \"Sparks\"" both map to same arc (roster may store display_name with quotes).
	{
		"unit_name": "Hest Sparks",
		"arc_id": "hest_streets",
		"encounter_ids": ["smugglers_cistern", "vermin_cellar_below_inn", "chains_in_the_marsh", "feast_of_hollow_masks"],
		"setup_encounter_ids": ["smugglers_cistern"],
		"echo_encounter_ids": ["vermin_cellar_below_inn"],
		"payoff_encounter_ids": ["vermin_cellar_below_inn", "smugglers_cistern"]
	},
	{
		"unit_name": "Hest \"Sparks\"",
		"arc_id": "hest_streets",
		"encounter_ids": ["smugglers_cistern", "vermin_cellar_below_inn", "chains_in_the_marsh", "feast_of_hollow_masks"],
		"setup_encounter_ids": ["smugglers_cistern"],
		"echo_encounter_ids": ["vermin_cellar_below_inn"],
		"payoff_encounter_ids": ["vermin_cellar_below_inn", "smugglers_cistern"]
	},
	# Ser Hadrien: setup = oath/order ruins; echo = grave road or abbey; payoff = memory, reverence, oath that outlived its era.
	{
		"unit_name": "Ser Hadrien",
		"arc_id": "hadrien_oath",
		"encounter_ids": ["broken_abbey_reliquary", "cairn_of_the_oathbreaker", "lanterns_on_the_grave_road", "purifier_checkpoint_ruin", "whispering_marrow_pit"],
		"setup_encounter_ids": ["cairn_of_the_oathbreaker", "whispering_marrow_pit"],
		"echo_encounter_ids": ["broken_abbey_reliquary", "lanterns_on_the_grave_road"],
		"payoff_encounter_ids": ["cairn_of_the_oathbreaker", "lanterns_on_the_grave_road"]
	},
	# Oren Pike: setup = aqueduct/mine/mill; echo = waystation or repair; payoff = structure, consequence-awareness, what to brace or not touch.
	{
		"unit_name": "Oren Pike",
		"arc_id": "oren_infrastructure",
		"encounter_ids": ["shattered_aqueduct", "flooded_mill_ruins", "iron_mine_cavein", "collapsed_bridge_crossing", "the_ashen_waystation"],
		"setup_encounter_ids": ["shattered_aqueduct", "iron_mine_cavein"],
		"echo_encounter_ids": ["flooded_mill_ruins", "the_ashen_waystation"],
		"payoff_encounter_ids": ["shattered_aqueduct", "iron_mine_cavein"]
	},
	# Yselle Maris: setup = feast/gallows; echo = refugee camp or procession; payoff = poise, morale, room-reading, keeping people human.
	{
		"unit_name": "Yselle Maris",
		"arc_id": "yselle_morale",
		"encounter_ids": ["feast_of_hollow_masks", "roadside_gallows_feast", "black_briar_refugee_camp", "plague_cart_procession"],
		"setup_encounter_ids": ["feast_of_hollow_masks", "roadside_gallows_feast"],
		"echo_encounter_ids": ["black_briar_refugee_camp"],
		"payoff_encounter_ids": ["feast_of_hollow_masks", "black_briar_refugee_camp"]
	},
	# Corvin Ash: setup = crypt/marrow; echo = ravens/lanterns/ferry; payoff = occult literacy, truth over comfort, understanding what the dead want.
	{
		"unit_name": "Corvin Ash",
		"arc_id": "corvin_occult",
		"encounter_ids": ["whispering_marrow_pit", "sealed_crypt_door", "ravens_at_the_watchfire", "lanterns_on_the_grave_road", "ghosts_of_the_ferry", "grave_pit_after_rain"],
		"setup_encounter_ids": ["whispering_marrow_pit", "sealed_crypt_door"],
		"echo_encounter_ids": ["ravens_at_the_watchfire", "grave_pit_after_rain"],
		"payoff_encounter_ids": ["sealed_crypt_door", "whispering_marrow_pit"]
	},
	# Maela Thorn: setup = bridge/crossing; echo = scout post or rotten bridge; payoff = speed, nerve, daring route, proving she can get there first.
	{
		"unit_name": "Maela Thorn",
		"arc_id": "maela_motion",
		"encounter_ids": ["collapsed_bridge_crossing", "bridge_of_rotten_planks", "black_briar_refugee_camp", "ravens_at_the_watchfire"],
		"setup_encounter_ids": ["collapsed_bridge_crossing", "bridge_of_rotten_planks"],
		"echo_encounter_ids": ["ravens_at_the_watchfire"],
		"payoff_encounter_ids": ["bridge_of_rotten_planks", "collapsed_bridge_crossing"]
	},
	# Sorrel: setup = crypt/abbey/archive; echo = relic or grave; payoff = correctly reading sites, knowledge rescuing from fear.
	{
		"unit_name": "Sorrel",
		"arc_id": "sorrel_lore",
		"encounter_ids": ["sealed_crypt_door", "whispering_marrow_pit", "broken_abbey_reliquary", "crypt_gargoyle_perch", "grave_pit_after_rain"],
		"setup_encounter_ids": ["sealed_crypt_door", "crypt_gargoyle_perch"],
		"echo_encounter_ids": ["broken_abbey_reliquary", "grave_pit_after_rain"],
		"payoff_encounter_ids": ["crypt_gargoyle_perch", "broken_abbey_reliquary"]
	},
	# Tariq: setup = checkpoint/cistern; echo = gallows or aqueduct; payoff = seeing real leverage, precise reading of power.
	{
		"unit_name": "Tariq",
		"arc_id": "tariq_leverage",
		"encounter_ids": ["purifier_checkpoint_ruin", "smugglers_cistern", "roadside_gallows_feast", "shattered_aqueduct", "vermin_cellar_below_inn"],
		"setup_encounter_ids": ["purifier_checkpoint_ruin", "smugglers_cistern"],
		"echo_encounter_ids": ["roadside_gallows_feast", "shattered_aqueduct"],
		"payoff_encounter_ids": ["purifier_checkpoint_ruin", "smugglers_cistern"]
	},
	# Pell Rowan: setup = salt road/rescue; echo = refugee camp or mill; payoff = courage becoming real, stepping up before feeling ready.
	{
		"unit_name": "Pell Rowan",
		"arc_id": "pell_aspiration",
		"encounter_ids": ["salt_road_hangings", "collapsed_bridge_crossing", "black_briar_refugee_camp", "flooded_mill_ruins", "iron_mine_cavein"],
		"setup_encounter_ids": ["salt_road_hangings", "collapsed_bridge_crossing"],
		"echo_encounter_ids": ["black_briar_refugee_camp"],
		"payoff_encounter_ids": ["salt_road_hangings", "collapsed_bridge_crossing"]
	},
	# Veska Moor: setup = bridge/camp; echo = waystation or mill; payoff = holding the line, presence that doesn't break.
	{
		"unit_name": "Veska Moor",
		"arc_id": "veska_steadfast",
		"encounter_ids": ["collapsed_bridge_crossing", "black_briar_refugee_camp", "the_ashen_waystation", "flooded_mill_ruins", "bridge_of_rotten_planks"],
		"setup_encounter_ids": ["collapsed_bridge_crossing", "black_briar_refugee_camp"],
		"echo_encounter_ids": ["the_ashen_waystation", "flooded_mill_ruins"],
		"payoff_encounter_ids": ["flooded_mill_ruins", "collapsed_bridge_crossing"]
	},
	# Avatar: narrative centerpiece; world names them, waits for their word, reads them as symbol/shelter/danger. Uses neutral AVATAR_SENTINEL "Avatar" for weighting; roster_names injected by world_map when avatar present.
	{
		"unit_name": "Avatar",
		"arc_id": "avatar_centerpiece",
		"encounter_ids": ["black_briar_refugee_camp", "collapsed_bridge_crossing", "plague_cart_procession", "roadside_gallows_feast", "shattered_aqueduct", "bell_tower_of_ashes", "purifier_checkpoint_ruin", "ravens_at_the_watchfire", "lanterns_on_the_grave_road", "broken_abbey_reliquary", "the_ashen_waystation", "sealed_crypt_door", "feast_of_hollow_masks"],
		"setup_encounter_ids": ["black_briar_refugee_camp", "collapsed_bridge_crossing", "feast_of_hollow_masks"],
		"echo_encounter_ids": ["plague_cart_procession", "the_ashen_waystation", "shattered_aqueduct"],
		"payoff_encounter_ids": ["roadside_gallows_feast", "purifier_checkpoint_ruin", "ravens_at_the_watchfire", "lanterns_on_the_grave_road", "broken_abbey_reliquary"]
	}
]

## Returns encounter IDs that should receive a weight boost when any of the given roster unit names has a personal arc. Used by EncounterDatabase.pick_random_encounter_for_region.
## Inputs: roster_unit_names (Array of String, e.g. from CampaignManager.player_roster unit_name).
## Outputs: Array of encounter id strings (may contain duplicates; caller may dedupe if needed).
static func get_encounter_ids_preferred_for_roster(roster_unit_names: Array) -> Array:
	if roster_unit_names.is_empty():
		return []
	var names_set: Dictionary = {}
	for n in roster_unit_names:
		var s: String = str(n).strip_edges()
		if s.is_empty():
			continue
		names_set[s] = true
	var out: Array = []
	for arc in PERSONAL_ARCS:
		var u: String = str(arc.get("unit_name", "")).strip_edges()
		if u.is_empty() or not names_set.get(u, false):
			continue
		var ids = arc.get("encounter_ids")
		if ids is Array:
			for id_val in ids:
				var id_str: String = str(id_val).strip_edges()
				if not id_str.is_empty():
					out.append(id_str)
	return out
