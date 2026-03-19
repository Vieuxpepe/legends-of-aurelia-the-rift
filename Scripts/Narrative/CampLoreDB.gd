class_name CampLoreDB

const LORE_BY_UNIT: Dictionary = {
	# Core mentor and early join
	"Kaelen": [
		{
			"id": "kaelen_lore_oath_chain",
			"threshold": "trusted",
			"type": "camp_lore",
			"title": "Chain of Oaths",
			"text": "Kaelen is oiling his blade, motions sparse and exact. \"You keep staring at the sigils,\" he says without looking up. \"They’re not medals. They’re debts. Every mark is a promise I failed to keep in time.\" He finally meets your eyes. \"This campaign is just another link in the chain. I intend to make this one hold.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
		{
			"id": "kaelen_lore_greyspire_walls",
			"threshold": "trusted",
			"type": "camp_lore",
			"title": "Greyspire Walls",
			"text": "Kaelen stands at the edge of camp, watching Greyspire’s silhouette cut the sky. \"First time I saw those walls,\" he says, \"I thought they looked like an answer. Stone that high makes you believe in safety you haven’t earned yet.\" He exhales. \"Turns out you can stack rock to the heavens and still drag all the same rot in through the gate.\"",
			"requires_flags": ["greyspire_hub_established"],
			"forbidden_flags": [],
		},
		{
			"id": "kaelen_lore_dawnkeep_night",
			"threshold": "close",
			"type": "camp_lore",
			"title": "The Night at Dawnkeep",
			"text": "The fire has burned low when Kaelen finally speaks. \"At Dawnkeep,\" he says, \"we signed an order to seal a rift breach we barely understood. I argued we needed more time. They argued the world didn’t have it.\" His hands flex as if remembering weight. \"We saved the border and lost three villages the report never named. I have been trying, ever since, to do one thing that matters without paying for it in ghosts.\"",
			"requires_flags": ["dawnkeep_siege_cleared"],
			"forbidden_flags": [],
		},
	],

	# Streetwise saboteur
	"Nyx": [
		{
			"id": "nyx_lore_shadow_letters",
			"threshold": "trusted",
			"type": "camp_lore",
			"title": "Shadow Letters",
			"text": "Nyx watches the firelight crawl over the tents.\n\n\"You ever notice how quiet it gets when the messengers come?\" she asks. \"Good news is shouted. Bad news is whispered. The worst news never makes it to the loud places at all. It just… arrives.\" She taps the side of her satchel. \"I used to be one of those arrivals. Still am, some days.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
		{
			"id": "nyx_lore_market_masks",
			"threshold": "trusted",
			"type": "camp_lore",
			"title": "Market Faces",
			"text": "Nyx flips a cheap festival mask between their fingers. \"Market of Masks, huh,\" they smirk. \"City like that teaches you early: nobody lies better than a man who thinks the costume makes him honest.\" Their voice drops. \"I used to run messages through those alleys. Same nobles who bought silks from the stalls bought blood from the alleys behind them. Different coin, same ledger.\"",
			"requires_flags": ["market_of_masks_cleared"],
			"forbidden_flags": [],
		},
		{
			"id": "nyx_lore_burned_bridge",
			"threshold": "close",
			"type": "camp_lore",
			"title": "Burned Bridge",
			"text": "Later than anyone should be awake, Nyx sits alone, staring at the camp road. \"I had a crew once,\" they say quietly. \"We weren’t heroes. We just tried to steal from people who could afford to bleed a little.\" A bitter laugh. \"Then I sold them a job I thought was safe. Turned out the League was waiting on the other side. I lived because I saw the net first.\" They finally look at you. \"You keep wondering why I bolt when things get too warm? That’s why. I am not built to watch another family die because I picked the wrong door.\"",
			"requires_flags": ["gathering_storms_cleared"],
			"forbidden_flags": [],
		},
	],

	# Camp hearth bruiser
	"Branik": [
		{
			"id": "branik_lore_graveyard_humor",
			"threshold": "known",
			"type": "camp_lore",
			"title": "Graveyard Humor",
			"text": "Branik chuckles to himself as he stirs the pot over the coals. \"You know what they called my last squad?\" he asks. \"The Lucky Ones. Because we got to walk away.\" His smile frays at the edges. \"Funny thing about nicknames. The dead don’t get to argue with them.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
	],

	# Light-cleric moral conscience
	"Liora": [
		{
			"id": "liora_lore_mended_prayers",
			"threshold": "trusted",
			"type": "camp_lore",
			"title": "Mended Prayers",
			"text": "Liora smooths a worn prayer ribbon between her fingers. \"When I was small,\" she says, \"I thought every word the priest spoke was clean. Like light through glass.\" She looks toward the tents where the wounded sleep. \"It took me too long to learn that some prayers are written to keep people quiet, not to keep them safe. I still use the old words sometimes. I just aim them differently now.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
		{
			"id": "liora_lore_sanctum_smoke",
			"threshold": "trusted",
			"type": "camp_lore",
			"title": "Sanctum Smoke",
			"text": "Liora wipes soot from a cracked holy symbol salvaged from the Sanctum. \"We used to light incense here for the sick,\" she says. \"Now the stone still smells of burned parchment and fear.\" Her fingers tighten. \"I keep thinking of the sermons about purification. How clean it all sounded from the pulpit. How filthy it felt when the flames were ours.\"",
			"requires_flags": ["greyspire_hub_established"],
			"forbidden_flags": [],
		},
		{
			"id": "liora_lore_last_benediction",
			"threshold": "close",
			"type": "camp_lore",
			"title": "Last Benediction",
			"text": "Much later, under a sky that refuses to be fully dark, Liora speaks without looking at you. \"If we live through this,\" she says, \"I don’t know if I will ever stand at an altar again.\" She lets out a thin breath. \"But I think I will keep a small space somewhere—a table, a candle, a place where people can bring the kind of hurt no doctrine ever wrote about. That might be all the church I have left in me.\"",
			"requires_flags": ["gathering_storms_cleared"],
			"forbidden_flags": [],
		},
	],

	# Scholar-mage
	"Sorrel": [
		{
			"id": "sorrel_lore_redacted_pages",
			"threshold": "known",
			"type": "camp_lore",
			"title": "Redacted Pages",
			"text": "Sorrel sits with a battered codex in their lap, the margins full of careful notes. \"You can tell what frightened an age by what it tried to erase,\" they murmur. \"Look here—entire decades reduced to 'unrest' in the official record. Yet the ink still bleeds on the pages they tried to burn.\" They glance up. \"History is just censorship with better handwriting, unless someone bothers to look underneath.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
		{
			"id": "sorrel_lore_greyspire_stacks",
			"threshold": "trusted",
			"type": "camp_lore",
			"title": "Greyspire Stacks",
			"text": "Sorrel returns from Greyspire’s archives with dust in their hair and ink on their fingers. \"They built shelves up to the rafters to hold everything they didn’t want to think about,\" they say. \"Some of the bindings haven’t been touched since the last war. Whole shelves of ‘classified incidents’ that read like the same mistake rewritten with nicer margins.\"",
			"requires_flags": ["greyspire_hub_established"],
			"forbidden_flags": [],
		},
		{
			"id": "sorrel_lore_rift_annotations",
			"threshold": "close",
			"type": "camp_lore",
			"title": "Rift Annotations",
			"text": "Sorrel stares at a map overlaid with their own frantic notes. \"I used to believe that if I understood the pattern—every breach, every lie, every sealed report—I could keep us from repeating it,\" they confess. \"Now I’m starting to accept that knowing still won’t be enough. We have to choose differently even when the pattern screams at us to do what’s efficient.\" They glance at you. \"I find that far more frightening than any forbidden text.\"",
			"requires_flags": ["echoes_of_the_order_cleared"],
			"forbidden_flags": [],
		},
	],

	# Disgraced noble duelist
	"Darian": [
		{
			"id": "darian_lore_edranor_mask",
			"threshold": "known",
			"type": "camp_lore",
			"title": "The Masquerade",
			"text": "Darian studies the camp from a distance, cloak catching the firelight just so. \"In Edranor,\" he says lightly, \"we held a winter masquerade while three villages starved along the river. The musicians were excellent.\" His smile tilts, pretty and tired. \"The trick is realizing the mask was never the problem. It was the people who forgot to take it off when they counted the dead.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
		{
			"id": "darian_lore_market_debts",
			"threshold": "trusted",
			"type": "camp_lore",
			"title": "Market Debts",
			"text": "Darian toys with a signet ring he no longer wears. \"The Market of Masks was always very educational,\" he says. \"You could watch a lord haggle over a performer’s fee with the same voice he used to discuss grain tariffs.\" His gaze hardens. \"I used to think I’d be the noble who did it better. Then I realized I’d already learned how to step over hungry men without seeing them at all.\"",
			"requires_flags": ["market_of_masks_cleared"],
			"forbidden_flags": [],
		},
		{
			"id": "darian_lore_edranor_reckoning",
			"threshold": "close",
			"type": "camp_lore",
			"title": "Edranor Reckoning",
			"text": "Much later, Darian’s usual composure is thinner at the edges. \"If Edranor survives this,\" he says quietly, \"it will be because people like you forced it to look at the bodies it built its banquets on.\" He exhales a humorless laugh. \"If I survive, it will be as a man who helped write the bill. Perhaps that is the only honest nobility I’ll ever have—standing in the open when the ledger is finally read.\"",
			"requires_flags": ["gathering_storms_cleared"],
			"forbidden_flags": [],
		},
	],

	# Disciplined lancer / ex-Valeron soldier
	"Celia": [
		{
			"id": "celia_lore_drills_and_doubts",
			"threshold": "known",
			"type": "camp_lore",
			"title": "Drills and Doubts",
			"text": "Celia adjusts a recruit’s stance with precise, gloved hands. \"They taught us that a straight back and a steady spear could make any order righteous,\" she says. Her gaze drifts past the training yard toward the dark horizon. \"It turns out a perfectly-formed line can march just as neatly into atrocity as into defense. No one mentioned that in the manuals.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
	],

	# Dock-born cannoneer
	"Rufus": [
		{
			"id": "rufus_lore_drowned_ledgers",
			"threshold": "known",
			"type": "camp_lore",
			"title": "Drowned Ledgers",
			"text": "Rufus sharpens a chisel, the scrape punctuating his words. \"Back home, a man could drown in three inches of seawater and a bad contract,\" he says. \"Boss would shrug, mark the crate as 'lost to weather,' and bill the family for the damages.\" He snorts. \"That’s what I like about cannons. At least when they speak, everyone hears the cost at once.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
	],

	# Beastmaster from the wild margins
	"Inez": [
		{
			"id": "inez_lore_cut_lines",
			"threshold": "trusted",
			"type": "camp_lore",
			"title": "Cut Lines",
			"text": "Inez traces a scar along a tree just beyond the firelight. \"This grove used to mark the edge of something sacred,\" she says quietly. \"Then men with maps arrived and decided the line was inconvenient.\" Her eyes follow the camp perimeter. \"They always call it progress when they move a boundary. Funny how the land and the people on it are the ones that bleed.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
	],

	# Arcane sniper / cynic
	"Tariq": [
		{
			"id": "tariq_lore_ink_and_blood",
			"threshold": "trusted",
			"type": "camp_lore",
			"title": "Ink and Blood",
			"text": "Tariq flips through a notebook of sigils and annotations, each line immaculate. \"You’d be amazed how many wars start as footnotes,\" he says. \"Some patron decides a truth is too dangerous to print, so it gets moved to the margins. Then someone like me gets hired to make sure the man who remembers it doesn’t live to give a lecture.\" He closes the book. \"Scholars like to call that 'curating knowledge.' I’ve seen neater murders.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
	],

	# Oakhaven archer
	"Mira Ashdown": [
		{
			"id": "mira_lore_silent_accounts",
			"threshold": "known",
			"type": "camp_lore",
			"title": "Silent Accounts",
			"text": "Mira watches the sparks drift up from the fire, bow unstrung across her knees. \"People keep trying to tell stories about Oakhaven,\" she says. \"They always start with how it burned, or how it ‘forged’ us.\" Her jaw tightens. \"No one ever asks what the village smelled like on a normal morning. Or which roof leaked. Or who always sang off key.\" She shrugs. \"If they’re going to remember it, they should remember it right.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
	],

	# Earnest young lancer
	"Pell Rowan": [
		{
			"id": "pell_lore_unpolished_oath",
			"threshold": "stranger",
			"type": "camp_lore",
			"title": "Unpolished Oath",
			"text": "Pell grips his spear a little too tightly as he talks. \"Back home, I used to practice speeches in the mirror,\" he admits, flushing. \"You know—the kind where the hero says something brilliant before the charge.\" He glances at the scarred camp. \"Turns out, out here, most of the time you just… run. Or you help someone stand up. Or you don’t die. Feels less like a speech and more like not looking away.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
	],

	# Anxious healer
	"Tamsin Reed": [
		{
			"id": "tamsin_lore_ledger_of_breaths",
			"threshold": "known",
			"type": "camp_lore",
			"title": "Ledger of Breaths",
			"text": "Tamsin sorts bandages into painfully neat stacks. \"I used to keep a ledger in the infirmary,\" she says, almost apologetically. \"Not of medicine used—of breaths. In, out, in, out… whose got shallow, whose steadied, whose stopped.\" She gives a small, crooked smile. \"Numbers help when the rest is screaming. If the column keeps growing, it means I didn’t fail everyone.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
	],

	# Chaotic tinkerer
	"Hest \"Sparks\"": [
		{
			"id": "hest_lore_broken_toys",
			"threshold": "stranger",
			"type": "camp_lore",
			"title": "Broken Toys",
			"text": "Hest sits cross-legged by the fire, disassembling a League trinket with far too much enthusiasm. \"Grown-ups always said I broke things,\" they grin. \"What they meant was I found out what they were actually for.\" They flick a scrap of metal into the flames. \"Turns out most ‘useful’ devices in this world are just prettier ways to hurt people. I like it better when something dangerous forgets who it’s supposed to serve.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
	],

	# Gentle warrior-monk
	"Brother Alden": [
		{
			"id": "alden_lore_weight_of_hands",
			"threshold": "known",
			"type": "camp_lore",
			"title": "The Weight of Hands",
			"text": "Alden wraps his knuckles with practiced care. \"In the cloister,\" he says, \"they taught us that strong hands were for carrying burdens, not making them.\" He looks at his scars without flinching. \"Somewhere along the way, I started doing both. Fists for the righteous, they called it.\" His voice softens. \"These days, I try to remember that every blow lands on someone loved by someone else.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
	],

	# Irritable engineer
	"Oren Pike": [
		{
			"id": "oren_lore_load_bearing_lies",
			"threshold": "known",
			"type": "camp_lore",
			"title": "Load-Bearing Lies",
			"text": "Oren glares at a crooked support beam near the supply tent. \"You know what keeps most cities standing?\" he asks. \"Not faith. Not oaths. Bracing.\" He raps his knuckles against the wood. \"Then some lord cuts corners on materials and calls it efficiency. Couple of years later, the roof collapses and everyone swears it was an act of the gods.\" He snorts. \"Funny how people only believe in consequence when it’s convenient.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
	],

	# Edranori cavalryman
	"Garrick Vale": [
		{
			"id": "garrick_lore_cracked_standard",
			"threshold": "trusted",
			"type": "camp_lore",
			"title": "Cracked Standard",
			"text": "Garrick straightens the edge of a tattered banner, fingers lingering on a faded crest. \"We used to polish these before every parade,\" he says. \"You could see your face in the gold, if you wanted.\" His mouth hardens. \"Out on the famine roads, that same standard meant ration cuts and broken promises. Funny thing about symbols—they don’t change when the people under them start starving.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
	],

	# Severe tactician
	"Sabine Varr": [
		{
			"id": "sabine_lore_aftermath_rooms",
			"threshold": "known",
			"type": "camp_lore",
			"title": "Aftermath Rooms",
			"text": "Sabine studies the camp map long after everyone else has turned in. \"Command posts always look the same the morning after,\" she says. \"Cold ink, stale bread, chairs a little too close to where the shouting happened.\" Her gaze flicks to you. \"You can tell who lost by who cleans up. The ones who cared are still moving bodies. The ones who didn’t are already drafting the report.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
	],

	# Performer / morale support
	"Yselle Maris": [
		{
			"id": "yselle_lore_stage_lights",
			"threshold": "known",
			"type": "camp_lore",
			"title": "Stage Lights",
			"text": "Yselle adjusts a lantern so the light falls just right over the makeshift mess tent. \"I once played to a hall where no one knew the city outside was rioting,\" she says. \"They applauded like the world wasn’t cracking under their feet.\" She smiles, small and wry. \"Turns out a song can hold people together for one more night. I just try to be choosier now about whose nights I’m buying.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
	],

	# Inquisitorial defector
	"Sister Meris": [
		{
			"id": "meris_lore_burnt_confessions",
			"threshold": "trusted",
			"type": "camp_lore",
			"title": "Burnt Confessions",
			"text": "Meris stares into the embers, jaw clenched. \"In the archives,\" she says quietly, \"we kept a shelf of confessions signed under ‘proper guidance.’\" Her fingers tighten on her rosary. \"They smelled of ink and smoke. Some of them were true. Most were simply… compliant.\" She exhales. \"I used to believe that was justice. Now I know silence has a taste, and it is always of someone else’s fear.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
		{
			"id": "meris_lore_sanctum_cells",
			"threshold": "trusted",
			"type": "camp_lore",
			"title": "Sanctum Cells",
			"text": "Meris’ eyes follow the line of the camp’s ward-stakes as if they were bars. \"The Sanctum had lower halls no sermon mentioned,\" she says. \"Cold rooms. No windows. We told ourselves we were protecting souls from corruption.\" Her voice roughens. \"We were really protecting the institution from questions it didn’t want to answer.\"",
			"requires_flags": ["greyspire_hub_established"],
			"forbidden_flags": [],
		},
		{
			"id": "meris_lore_last_inquisition",
			"threshold": "close",
			"type": "camp_lore",
			"title": "Last Inquisition",
			"text": "Later, when the camp is almost asleep, Meris speaks without preface. \"There is a list,\" she says. \"Names of those I broke in the name of order. I used to read it before bed, convinced it would keep me vigilant.\" She lets out a small, bitter breath. \"Now I read it so I remember exactly what I am trying not to be, here. If I ever start sounding like the woman who signed those warrants, you have my permission to drag me back to the fire and make me listen.\"",
			"requires_flags": ["echoes_of_the_order_cleared"],
			"forbidden_flags": [],
		},
	],

	# Occult scholar
	"Corvin Ash": [
		{
			"id": "corvin_lore_residual_echoes",
			"threshold": "trusted",
			"type": "camp_lore",
			"title": "Residual Echoes",
			"text": "Corvin watches mist coil around the ward-stakes at camp’s edge. \"People assume horrors announce themselves with trumpets,\" he muses. \"In practice, it’s usually just… a room that feels wrong three days after something happened there.\" He tilts his head. \"The Veil is less a wall and more a bruise. You can ignore it, if you like. But bruises do not heal faster because you refuse to look.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
		{
			"id": "corvin_lore_order_experiments",
			"threshold": "trusted",
			"type": "camp_lore",
			"title": "Order’s Experiments",
			"text": "Corvin rolls a fragment of Dawnkeep masonry between his fingers, watching the faint shimmer of old wards. \"The Order liked to tell itself it was sealing horrors away,\" he says. \"It did that, sometimes. Other times it just moved them into better-lit rooms with more obedient witnesses.\" He looks up. \"Containment and collaboration are distressingly easy to confuse when the results look the same on a ledger.\"",
			"requires_flags": ["dawnkeep_siege_cleared"],
			"forbidden_flags": [],
		},
		{
			"id": "corvin_lore_rift_mirror",
			"threshold": "close",
			"type": "camp_lore",
			"title": "Rift Mirror",
			"text": "After a long patrol near an active rift, Corvin’s tone is unusually soft. \"People think the Veil is a wound in the world,\" he says. \"They never ask what it does to the people who keep staring at it.\" He offers you a faint, wry smile. \"If I ever start sounding more like the breach than the man, tell me. I would rather be corrected than become another well-intentioned disaster.\"",
			"requires_flags": ["gathering_storms_cleared"],
			"forbidden_flags": [],
		},
	],

	# Shield knight
	"Veska Moor": [
		{
			"id": "veska_lore_wall_with_a_heartbeat",
			"threshold": "known",
			"type": "camp_lore",
			"title": "Wall with a Heartbeat",
			"text": "Veska leans her shield against a post, the metal still humming faintly from the last battle. \"They used to call me ‘the Wall’,\" she says. \"Nice, simple. Easy to forget a wall is just a person someone put between danger and everything else.\" She shrugs. \"I stayed anyway. Better me than someone who thought it was glorious.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
	],

	# Ghost knight of the Dawn
	"Ser Hadrien": [
		{
			"id": "hadrien_lore_dawnlight_dust",
			"threshold": "bonded",
			"type": "camp_lore",
			"title": "Dawnlight and Dust",
			"text": "Hadrien’s spectral fingers trace the hilt of a sword that no longer weighs anything. \"There was a morning,\" he says softly, \"when the Order of the Dawn rode out believing we were history’s answer, not its cautionary tale.\" He looks toward Greyspire’s silhouette. \"We sealed things we did not understand and called it duty. Centuries later, I am still here to watch you decide whether we were wrong to try… or wrong to think we were the only ones who could.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
		{
			"id": "hadrien_lore_echoes_of_order",
			"threshold": "close",
			"type": "camp_lore",
			"title": "Echoes of the Order",
			"text": "Hadrien stands watch where the firelight thins. \"When you walked the old halls,\" he says, \"I felt the stones remember me. Not my name—the pattern of my oath.\" His gaze is distant. \"It is a strange thing, to realize an institution can love the idea of you and care nothing for the man. The Order of the Dawn mourns itself more easily than it mourns the villages it failed.\"",
			"requires_flags": ["echoes_of_the_order_cleared"],
			"forbidden_flags": [],
		},
		{
			"id": "hadrien_lore_after_dawn",
			"threshold": "bonded",
			"type": "camp_lore",
			"title": "After the Dawn",
			"text": "On a rare quiet night, Hadrien’s voice is almost gentle. \"If this ends with the veils mended and the orders remade,\" he says, \"promise me something.\" His fading eyes find yours. \"Do not rebuild my Order as it was. Let the dead remain a warning, not a blueprint. The world does not need another Dawn that blinds itself to the shadows it casts.\"",
			"requires_flags": ["gathering_storms_cleared"],
			"forbidden_flags": [],
		},
	],

	# Fast aerial scout
	"Maela Thorn": [
		{
			"id": "maela_lore_skyline",
			"threshold": "known",
			"type": "camp_lore",
			"title": "Skyline",
			"text": "Maela sits on a wagon roof, boots swinging as she watches the stars. \"On the ground,\" she says, \"everyone’s always arguing about borders and whose line is older.\" She grins, sharp and bright. \"From up there, it all just looks like people trying not to fall off the same piece of rock.\" Her gaze softens. \"Don’t tell the nobles. They get nervous when the sky doesn’t salute.\"",
			"requires_flags": [],
			"forbidden_flags": [],
		},
	],
}

static func get_lore_entries_for_unit(unit_name: String) -> Array:
	var key: String = str(unit_name).strip_edges()
	if key.is_empty():
		return []
	var entries: Variant = LORE_BY_UNIT.get(key, null)
	if entries == null or not (entries is Array):
		return []
	return entries as Array
