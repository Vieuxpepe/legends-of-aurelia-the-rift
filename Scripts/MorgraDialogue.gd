class_name MorgraDialogue
extends RefCounted

# ==========================================
# MORGRA'S MASTER DIALOGUE POOL
# ==========================================
static func get_line(category: String) -> String:
	# --- 1. THE EMOTIONAL OVERRIDES (Highest priority) ---
	if int(CampaignManager.morgra_anger_duration) > 0:
		return _pick_line(_get_anger_lines())

	if int(CampaignManager.morgra_neutral_duration) > 0:
		return _pick_line(_get_neutral_lines())

	# --- 2. BUILD CONTEXT ONCE ---
	var ctx: Dictionary = _build_context()
	var dragons: Array[Dictionary] = ctx.get("dragons", [])
	var dynamic_comments: Array[String] = ctx.get("dynamic_comments", [])

	# --- 3. CATEGORY LOGIC ---
	var lines: Array[String] = []

	match category:
		"welcome":
			if dragons.is_empty():
				lines = dynamic_comments
			else:
				lines = _get_welcome_lines(ctx)
				if randf() > 0.4:
					lines.append_array(dynamic_comments)

		"idle":
			if dragons.is_empty():
				lines = dynamic_comments
			else:
				lines = _get_idle_lines(ctx)
				if randf() > 0.4:
					lines.append_array(dynamic_comments)

		"feed":
			lines = _get_feed_lines(ctx)

		"train":
			lines = _get_train_lines(ctx)

		"breed":
			lines = _get_breed_lines(ctx)

		"hatch":
			lines = _get_hatch_lines(ctx)

		"hunt":
			lines = _get_hunt_lines(ctx)

		_:
			lines = []

	return _pick_line(lines)


# ==========================================
# SAFE PICKER
# ==========================================
static func _pick_line(lines: Array[String], fallback: String = "...") -> String:
	if lines.is_empty():
		return fallback
	return lines[randi() % lines.size()]


# ==========================================
# STATE / CONTEXT BUILDING
# ==========================================
static func _build_context() -> Dictionary:
	var raw_dragons: Array = DragonManager.player_dragons
	var dragons: Array[Dictionary] = []

	var current_favorite_uid: String = str(CampaignManager.morgra_favorite_dragon_uid)
	var favorite_found: bool = false
	var favorite_dragon: Dictionary = {}
	var favorite_name: String = ""

	# Single pass: sanitize roster + find current favorite
	for entry in raw_dragons:
		if typeof(entry) != TYPE_DICTIONARY:
			continue

		var d: Dictionary = entry
		dragons.append(d)

		var uid: String = str(d.get("uid", ""))
		if current_favorite_uid != "" and uid == current_favorite_uid:
			favorite_found = true
			favorite_dragon = d
			favorite_name = str(d.get("name", ""))

	# Favorite rule: only assign when player has more than 2 dragons
	if not favorite_found:
		CampaignManager.morgra_favorite_dragon_uid = ""
		current_favorite_uid = ""
		favorite_dragon = {}
		favorite_name = ""

		if dragons.size() > 2:
			var chosen_index: int = randi() % dragons.size()
			var candidate: Dictionary = dragons[chosen_index]
			current_favorite_uid = str(candidate.get("uid", ""))
			favorite_dragon = candidate
			favorite_name = str(candidate.get("name", ""))
			CampaignManager.morgra_favorite_dragon_uid = current_favorite_uid
			favorite_found = true

	var is_adoring: bool = favorite_found and int(CampaignManager.morgra_favorite_survived_battles) >= 10
	var dynamic_comments: Array[String] = _get_dynamic_dragon_comments(dragons, current_favorite_uid)

	return {
		"dragons": dragons,
		"favorite_uid": current_favorite_uid,
		"has_favorite": favorite_found,
		"favorite_name": favorite_name,
		"favorite_dragon": favorite_dragon,
		"is_adoring": is_adoring,
		"dynamic_comments": dynamic_comments
	}


# ==========================================
# OVERRIDES
# ==========================================
static func _get_anger_lines() -> Array[String]:
	return [
		"Don't speak to me. You let them die.",
		"You think bringing me meat fixes what you let happen out there? Walk away.",
		"I trusted you with them. Never again.",
		"Get out of my sight before I test this butchering knife on your neck.",
		"They were magnificent... and you let them fall. Disgusting.",
		"I'm only tending to these beasts because I love them. I have nothing but contempt for you right now.",
		"Every time I look at you, I remember the wings we lost. Leave.",
		"You play at being a commander. You're just a butcher who can't protect their own.",
		"I can still smell the blood in their scales. Don't ask me to smile for you.",
		"You had one duty: bring them back alive. You failed, and now this pen is emptier for it.",
		"Careful, boss. Grief makes my hands shake, and I only know one cure for shaking hands.",
		"Do not touch me. Do not charm me. Do not pretend you understand what was taken.",
		"They trusted you enough to follow you into fire. I was a fool to do the same.",
		"I've buried beasts worth more than half this camp, and you want me civil? No.",
		"Take one more step and I'll remind you that Orcs mourn with teeth.",
		"The dragons are quieter today. That's your doing. Sit with that.",
		"I named them. I raised them. I loved them. You lost them.",
		"Not today, Commander. Not your voice, not your excuses, not that face.",
		"You want my cooperation? Dig up the dead and ask them for it.",
		"I don't care how many battles you've won. Out there, when it mattered, you failed my child.",
		"I keep seeing the empty space in the pen. It makes me want to break something with a pulse.",
		"If you came for forgiveness, you're a braver fool than I thought.",
		"The others still need me, so breathe carefully and thank the ancestors I'm busy.",
		"You're lucky the dragons still need feeding. Otherwise I'd have time to finish this conversation properly."
	]


static func _get_neutral_lines() -> Array[String]:
	return [
		"Just put the meat in the trough. I'll handle the rest.",
		"The beasts are fine. I'm doing my job. Don't ask for more than that today.",
		"I'm keeping my distance from them today. It's safer that way.",
		"No jokes today, Commander. Just work.",
		"They're weapons, right? That's what you want. I'm sharpening your weapons.",
		"Don't loiter. The dragons need sleep and I need quiet.",
		"I fed them. I cleaned the pens. We have nothing else to discuss.",
		"I'm not in the mood for camp banter. Leave the supplies and go.",
		"They'll survive. So will we. Let's just leave it at that.",
		"I don't have the energy to be charming today, boss.",
		"The saddles are mended. The troughs are full. The rest isn't your concern.",
		"I'm speaking because the ranch requires it. Don't make me say more.",
		"Stand where I can see you and keep your hands out of the pen.",
		"The beasts are calmer than I am. That should tell you enough.",
		"You need results, you'll get results. Spare me the soft concern.",
		"I'm protecting what's left. That's the only conversation I'm having today.",
		"You can stay if you're useful. Otherwise, the gate works both ways.",
		"I remember my duty. I'm trying not to remember everything else.",
		"The dragons still trust me. That's more than I can say for people.",
		"Talk less. Listen more. Hear that breathing? That's what matters.",
		"I'm not angry anymore. That doesn't mean I'm open.",
		"I know how to do my job without being comforted through it.",
		"Bring clean meat, sharp tools, and silence. We'll get along fine.",
		"The ranch still stands. I still work. That's enough for now."
	]


# ==========================================
# CATEGORY POOLS
# ==========================================
static func _get_welcome_lines(ctx: Dictionary) -> Array[String]:
	var favorite_name: String = ctx.get("favorite_name", "")
	var has_favorite: bool = ctx.get("has_favorite", false)
	var is_adoring: bool = ctx.get("is_adoring", false)

	var lines: Array[String] = []

	if is_adoring:
		lines = [
			"You brought them back without a scratch again. You're remarkable, Commander.",
			"I used to think you were just another soft human playing at war. I've never been happier to be wrong.",
			"Most commanders spend dragons like cheap arrows. You treat them like partners. I notice.",
			"Ten battles. Ten times you walked one of mine into hell and brought them back. You have my absolute loyalty.",
			"Come here, boss. Let me look at you. If you ever need someone watching your back, I'm already there.",
			"The beasts adore you. I'm starting to understand why.",
			"You fight like an Orc, Commander. Fierce, protective, and brilliant. Welcome home.",
			"I sleep easier when you're the one leading them out. That's not something I say lightly.",
			"You've earned more than my respect. You've earned the trust of my children.",
			"When your banner moves, the pen settles. They know you're bringing them back.",
			"I don't praise people often. You're making a bad habit of forcing it out of me.",
			"Walk in closer, boss. I like seeing a commander who keeps their promises.",
			"The ranch feels proud when you return. So do I.",
			"Every scar on you tells me you stood where the danger was. Good.",
			"You guard what's mine like it's yours. That's a dangerous way to make me loyal.",
			"If anyone says you got lucky, I'll feed them to the drakes for insulting my judgment.",
			"You bring back dragons and victories. That's a rare kind of beauty.",
			"I trust your hands on reins, steel, and fate. That's rare enough to matter.",
			"I've watched warlords with twice your ego and half your heart. None of them deserved my respect. You do.",
			"If you told me to saddle every beast in this pen tonight, I'd do it before you finished the sentence.",
			"Welcome back, Commander. The dragons are fed, the pen is ready, and so am I.",
			"You're the only commander who walks in here and makes me feel less alone with this burden.",
			"I used to fear for the brood every time the horns blew. Not anymore.",
			"You keep bringing my pack home alive. That's the kind of thing I don't forget."
		]

		if has_favorite and favorite_name != "":
			lines.append("The day I started believing in you was the day I stopped fearing for %s every battle." % favorite_name)
			lines.append("%s comes back calmer when you ride with them. That's not chance. That's bond." % favorite_name)
			lines.append("I used to guard my heart with teeth. Then you kept %s alive ten times over." % favorite_name)
			lines.append("Ten battles, and %s is still breathing. You have my loyalty." % favorite_name)
	else:
		lines = [
			"I was wondering when you'd wander back to my corner of the camp.",
			"The beasts missed you, Commander. I might have missed you a little too. Don't strut about it.",
			"Keep looking at me like that, boss, and I might toss you into the pen just to see who blushes first.",
			"Ah, the boss is back. Don't worry, I kept the fire-breathers entertained and the idiots mostly alive.",
			"They're growing fast. Almost as handsome as you. Almost.",
			"Watch your fingers today. The green one is feeling extra bitey, and I hate wasting good hands.",
			"More scales, more smoke, more noise. Just the way I like it.",
			"You smell like steel, mud, and bad decisions. Means you're right where you belong.",
			"The ranch has been loud, hungry, and perfect. Thought you'd appreciate that.",
			"You here to help, flirt, or get in the way? Pick fast.",
			"I kept your precious dragon-food soldiers from wandering into the pens. You're welcome.",
			"Step carefully, boss. Some of the little ones are testing their bite strength.",
			"I've got claw marks on the posts, blood in the straw, and a commander at my gate. Fine day.",
			"You took your time getting here. I was one minute from sending a drake to fetch you.",
			"The beasts perk up when your boots hit the yard. Either they like you or they think you're bringing meat.",
			"You always show up when the smoke looks good on me. Suspicious timing.",
			"If you've come to complain about the smell, leave. If you've come to watch dragons feed, come closer.",
			"Careful where you stand. My babies have no respect for polished armor.",
			"The hatchlings were restless. Lucky for you, I like having something strong to look at between chores.",
			"You're late, boss. I was starting to think a horse had kicked sense into you.",
			"I've had three recruits faint, one merchant cry, and one drake chew a bucket today. Camp's thriving.",
			"Walk in with that face and these beasts stop pacing. Annoying how useful you are.",
			"The pen's hot, the dragons are louder than ever, and you've finally decided to visit. Good.",
			"I saved you the safest spot to stand. That's me being generous, so don't waste it.",
			"If you came empty-handed, at least bring a decent attitude and both your hands.",
			"I've got work to do and monsters to love. You can help with one of those."
		]

		if has_favorite and favorite_name != "":
			lines.append("%s's been staring at the gate since dawn. Looks like my favorite expected you." % favorite_name)

	return lines


static func _get_idle_lines(ctx: Dictionary) -> Array[String]:
	var favorite_name: String = ctx.get("favorite_name", "")
	var has_favorite: bool = ctx.get("has_favorite", false)
	var is_adoring: bool = ctx.get("is_adoring", false)

	var lines: Array[String] = []

	if is_adoring:
		lines = [
			"I've never met anyone who respects these creatures the way you do.",
			"If anyone in this camp speaks ill of the Commander, I'm feeding them to the drakes.",
			"You've proven yourself out there. To them, and to me.",
			"*Morgra smiles as she watches the dragons sleep.*",
			"I don't worry the same way when you're the one leading them. That's a gift you gave me.",
			"You know what trust smells like? Smoke, leather, rain, and a commander who comes back alive.",
			"I sharpen blades for soldiers. I save my gentleness for dragons and, apparently, you.",
			"I used to laugh at people who talked about loyalty like it was sacred. Then you proved it could be.",
			"Strange thing, boss. The ranch feels safer when you're nearby, and it has nothing to do with walls.",
			"You brought my favorite through ten battles. You could ask for my life and I'd at least hear you out.",
			"Look at them sleeping easy. They know you won't waste them.",
			"I've started listening for your footsteps without meaning to. Irritating habit.",
			"Every war camp reeks of fear. Ours smells different when you're here. Stronger.",
			"The recruits think I'm less terrifying these days. They're wrong. I'm just proud.",
			"I'd rather stand beside you in a losing fight than behind most commanders in a winning one.",
			"I don't hand out devotion. You dragged it out of me battle by battle.",
			"If the camp burns tonight, grab the dragons and get behind me. I'll handle the rest.",
			"You gave me something rare, Commander. Not hope. Proof.",
			"I still threaten people for fun. I just do it in your defense more often now.",
			"The strongest thing in this pen used to be me. Now it might be what you've built with them.",
			"Ancestors help the fool who makes me choose between you and the rest of camp.",
			"I could watch you walk the lines with these beasts all evening and never tire of it.",
			"You keep the brood alive. That buys a kind of loyalty steel never could."
		]

		if has_favorite and favorite_name != "":
			lines.append("If %s ever throws you from the saddle, I'll assume you had a good reason." % favorite_name)
			lines.append("The way %s leans into your hand... that's earned, not taught." % favorite_name)
			lines.append("When you touch the harness on %s, your hands are steady. That's why I trust you." % favorite_name)
			lines.append("%s struts more after a battle with you. Looks proud to be yours for the day." % favorite_name)
	else:
		lines = [
			"Hey, rookie! Stop staring at my belt and get back to scrubbing the dung!",
			"Don't chew on that, it's a shield. Spit it out. Spit.",
			"Who's mama's favorite little apex predator? Yes, you are.",
			"*Scrapes a massive knife across a whetstone.*",
			"If one more merchant complains about the smell, I'm putting them on muck duty.",
			"No, you can't pet that one. You can admire it from a safer distance.",
			"Easy, sweetheart. That's a boot, not breakfast.",
			"I swear these beasts have better manners than half the soldiers in camp.",
			"If the blacksmith asks, I did not let the hatchlings near his coal again.",
			"Back off, stable boy. They smell your nerves and it annoys me.",
			"Some people collect flowers. I collect scaled nightmares and call them adorable.",
			"Hold still, you wriggling menace. I'm checking that wing joint, not stealing your pride.",
			"The next fool who says dragons are just oversized lizards gets handed a shovel and a warning.",
			"Quiet now. Hear that rumble? That's contentment. Or indigestion. Hard to tell sometimes.",
			"I could live in this heat forever. Smoke, leather, scales, and honest work.",
			"That recruit fainted again. I barely even raised my voice.",
			"Come here, my vicious darling. Let me clean the blood off your snout before the commander sees.",
			"Camp politics are dull. Dragons never lie about wanting to bite someone.",
			"Look at that tail twitch. That's either affection or murder brewing.",
			"I told them not to run through the pen. Prey behavior invites consequences.",
			"The little one stole my glove again. Clever beast. Better than most thieves I've met.",
			"If I hear one more soldier ask which end bites, I'm throwing him in to learn firsthand.",
			"I keep the pens clean, the beasts sharp, and the fools outside the fence. That's enough purpose for me.",
			"Easy there, my beauty. The commander likes his boots unchewed.",
			"Sometimes I think these dragons understand me better than people. Then a hatchling steals a bucket and proves it."
		]

		if has_favorite and favorite_name != "":
			lines.append("%s's been getting the best cuts again. Don't look at me like that. They earned it." % favorite_name)

	return lines


static func _get_feed_lines(ctx: Dictionary) -> Array[String]:
	var favorite_name: String = ctx.get("favorite_name", "")
	var has_favorite: bool = ctx.get("has_favorite", false)

	var lines: Array[String] = [
		"Good meat. They'll sleep heavy tonight.",
		"Look at them tear into that. Beautiful, aren't they?",
		"Oh, they love that. Hear the crunch? That's a healthy appetite.",
		"Good. Tear it apart. I was talking to the dragon, Commander, but you're doing fine too.",
		"Blood on the scales, meat in the belly. A fine afternoon.",
		"Keep them fed, keep them happy. Same rule applies to me, by the way.",
		"That's the spot. A fed dragon is a loyal dragon.",
		"See those eyes brighten? That's trust, boss. Simple as meat and patience.",
		"Never rush feeding time. Even love has teeth in this pen.",
		"They know the sound of a full bucket better than any war horn.",
		"Easy there, little monster. Plenty for everyone unless somebody loses a hand.",
		"Fresh cuts, warm breath, wagging tails. That's ranch life.",
		"You bring decent feed, and suddenly they stop trying to eat the stable boys. Improvement.",
		"Nothing calms a restless drake faster than a full gut and a familiar voice.",
		"Hold steady. If they smell fear on your hands, they'll start testing you.",
		"Look at that one guard the scraps. Sharp instincts. I could kiss that scaly head.",
		"When they chew slow, they're content. When they tear fast, something's got them worked up.",
		"Good haul, Commander. You keep bringing me quality meat and I might keep being nice.",
		"Mind the fingers. Hunger turns even my sweet ones into little gods of violence.",
		"A dragon remembers who feeds it well. Same as any creature worth loving.",
		"Listen to that rumble in the throat. That's satisfaction, and I worked for it.",
		"I'd rather smell fresh blood and warm meat than perfume and lies."
	]

	if has_favorite and favorite_name != "":
		lines.append("%s always gets one extra strip when I'm in a generous mood. Which is often." % favorite_name)
		lines.append("Careful with the bucket. Once %s locks those jaws, only one of you is winning." % favorite_name)

	return lines


static func _get_train_lines(ctx: Dictionary) -> Array[String]:
	var favorite_name: String = ctx.get("favorite_name", "")
	var has_favorite: bool = ctx.get("has_favorite", false)

	var lines: Array[String] = [
		"Push them hard, boss. A soft dragon is a dead dragon.",
		"They're learning to bite exactly where it hurts. Makes a girl proud.",
		"You've got a decent whip-hand, Commander. Careful, or I'll start expecting more.",
		"Good form. The beasts respect strength, and you've got enough to keep my interest.",
		"Nothing like sweat, dust, and scales to start the day.",
		"Again. Faster. Hesitation gets riders killed and dragons angry.",
		"Let them snarl. Training isn't pretty, and that's why it works.",
		"See that turn? Clean, brutal, efficient. That's a proper war beast.",
		"Don't coddle them. They need discipline, not lullabies.",
		"They learn your heartbeat before they learn your commands. Keep it steady.",
		"Nice strike. Another inch and that dummy would've needed burial rites.",
		"Make them earn the praise. Handing it out cheap ruins the whole breed.",
		"Good. They're tired, sharp, and listening. That's the sweet spot.",
		"The recruits call this cruel. The recruits also cry when a saddle strap snaps.",
		"Every scar they earn in training saves blood on the battlefield.",
		"If a dragon won't obey under pressure, it doesn't belong near my pen or your war.",
		"Look at that stance. Mean little brute. I could watch this all day.",
		"You handle them better every time you come through here, boss. Dangerous habit.",
		"Drive them through the turn again. Balance first, savagery second.",
		"A war dragon should know three things: bite, break, and come back when called.",
		"Push until the lungs burn. Then praise. That's how you build monsters that listen.",
		"If the saddle squeaks, fix it. If the dragon squeals, duck.",
		"I want them fast, mean, and impossible to forget. Looks like we're on schedule."
	]

	if has_favorite and favorite_name != "":
		lines.append("%s is learning your rhythm. That's where real control starts." % favorite_name)

	return lines


static func _get_breed_lines(ctx: Dictionary) -> Array[String]:
	var favorite_name: String = ctx.get("favorite_name", "")
	var has_favorite: bool = ctx.get("has_favorite", false)

	var lines: Array[String] = [
		"Putting the big ones together, huh? I'll set the mood and reinforce the fence.",
		"Good bloodlines there. Let's see what kind of beautiful terror comes from it.",
		"Ah, the miracle of life. Usually announced by roaring and broken timber.",
		"If only finding a worthy mate was this straightforward for the rest of us.",
		"I'll give them privacy. By privacy, I mean thick chains and a stone barrier.",
		"Strong lungs, sharp instincts, clean scales. That's a pairing worth betting on.",
		"Don't get squeamish on me now, Commander. Creation is messy work.",
		"Those two have been circling each other for days. About time we let nature bite.",
		"With luck, we'll get a clutch mean enough to make the cavalry pray.",
		"Temperament matters as much as teeth. A stupid dragon is just expensive trouble.",
		"Watch the posture, the growl, the eyes. They choose faster than people ever do.",
		"Some pairings make legends. Some make disasters. Either way, it's entertaining.",
		"If this works, we'll have hatchlings with wings like razors and attitude to match.",
		"Love isn't the word I'd use for dragons. Possession, challenge, hunger... closer.",
		"Stand back unless you want to get flattened by six hundred pounds of courtship.",
		"I like this match. Brutal, proud, and stubborn. Reminds me of someone.",
		"Good lungs, broad chest, bright eyes, vicious spirit. That's how a line stays strong.",
		"If their first instinct is to dominate the space, that's a good sign.",
		"I've seen worse pairings among nobles, and with far less fire involved.",
		"Once they decide, the whole yard feels it. Nature never does anything quietly here.",
		"Breeding isn't romance. It's selecting which nightmares deserve to continue.",
		"Keep your distance, boss. Courtship makes even the gentle ones stupid-dangerous.",
		"When this clutch hatches, I expect teeth, lungs, and personalities bad enough to matter."
	]

	if has_favorite and favorite_name != "":
		lines.append("%s had better pass on those gorgeous scales, or I'm lodging a complaint with the ancestors." % favorite_name)

	return lines


static func _get_hatch_lines(_ctx: Dictionary) -> Array[String]:
	return [
		"A new set of wings. Beautiful little menace.",
		"Well, look at that. Fresh out of the shell and already looking for something to bite.",
		"Welcome to the world, little terror. I'm Morgra, and you're mine to protect.",
		"Another mouth to feed. Good thing you're rich, boss.",
		"Easy, little one. Breathe first, threaten the world second.",
		"Look at those claws. Tiny now, deadly soon.",
		"The first cry is always my favorite. Sounds like trouble with lungs.",
		"Shell on the ground, fire in the eyes. Perfect beginning.",
		"Careful, Commander. Hatchlings imprint fast, and I don't share affection easily.",
		"This one came out angry. Good. Anger keeps the heart hot.",
		"See how it looks around already? Smart. Curious. Dangerous enough to matter.",
		"Every hatching feels like a promise and a warning in the same breath.",
		"Come on, little fang. Stretch those wings for me.",
		"Nothing prettier than new scales in the firelight.",
		"It hasn't even stood up yet and I'm already proud of it.",
		"Another child for the ranch. Try not to smile too much, boss, it softens your face.",
		"Listen to that hiss. Strong lungs. Strong will. Ancestors, I love this part.",
		"Easy now, little killer. The world will still be here after your first nap.",
		"Fresh hatched and already judging us. Good instincts.",
		"That shell barely had time to cool before the attitude came out swinging.",
		"If it bites me first, I know we're going to get along beautifully.",
		"Wrap it warm, keep the light low, and let it decide when the world gets too close.",
		"Look at those eyes. Already hungry. Already thinking.",
		"Every hatchling reminds me why I put up with the rest of this camp."
	]


static func _get_hunt_lines(ctx: Dictionary) -> Array[String]:
	var favorite_name: String = ctx.get("favorite_name", "")
	var has_favorite: bool = ctx.get("has_favorite", false)

	var lines: Array[String] = [
		"Fast little thing, isn't it? Bet on the dragon, though.",
		"Good throw, Commander. Let's see if they actually catch it or just play with it.",
		"Nothing sharpens the instincts like live prey. Watch the footwork.",
		"That's fifteen gold well spent. The recruits usually run slower.",
		"You always spoil them with the fresh ones. I usually make them dig up moles.",
		"Look at that burst of speed! Ancestors, they are beautiful when they hunt.",
		"A little blood sport to keep the morale up. I approve.",
		"They needed to stretch their legs anyway. Good call.",
		"Careful, if they miss that rabbit they might come looking for your boots instead.",
		"See how it cuts off the escape route? Pure, deadly instinct.",
		"Prey makes the eyes light up different. More honest. More ancient.",
		"Throw another one. I want to see who lunges first and who thinks first.",
		"The pounce matters more than the kill. Every good hunter knows that.",
		"Watch the shoulders, boss. The moment they dip, the rabbit's already dead.",
		"I don't raise pampered ornaments. I raise creatures that know how to take life cleanly.",
		"Good chase. Better finish. That's how I like a lesson delivered.",
		"There's joy in a proper hunt. Teeth, speed, decision. No lies in any of it.",
		"If a dragon loses interest in chasing, something's wrong. Or it's plotting something worse.",
		"That rabbit ran well. Shame. Wrong yard.",
		"See the patience before the spring? That's what separates instinct from panic."
	]

	if has_favorite and favorite_name != "":
		lines.append("%s loves the chase more than the meal. That's predator royalty." % favorite_name)
		lines.append("I swear %s smiles after a clean catch. Disturbing. Adorable." % favorite_name)

	return lines


# ==========================================
# DYNAMIC CONTEXT SCANNER
# ==========================================
static func _get_dynamic_dragon_comments(dragons: Array[Dictionary], favorite_uid: String) -> Array[String]:
	if dragons.is_empty():
		return [
			"Empty pens make me mean. Bring me an egg to fuss over, boss.",
			"No scales, no smoke, no trouble worth loving. Fix that.",
			"This ranch sounds wrong without claws on timber. Bring me something to raise.",
			"I've got clean troughs and no one to spoil. I hate it.",
			"Bring me an egg before I start glaring at soldiers for sport."
		]

	var dynamic_lines: Array[String] = []
	var sample: Array[Dictionary] = []
	for d in dragons:
		sample.append(d)
	sample.shuffle()

	var sample_size: int = min(sample.size(), 2)

	for i in range(sample_size):
		var d: Dictionary = sample[i]
		var d_name: String = str(d.get("name", "that one"))
		var d_elem: String = str(d.get("element", "Fire"))
		var d_stage: int = int(d.get("stage", 0))
		var traits: Array = d.get("traits", [])
		var is_favorite: bool = str(d.get("uid", "")) == favorite_uid

		# --- FAVORITE DRAGON LINES ---
		if is_favorite:
			dynamic_lines.append("Look at %s... the rest are fine, but this one? Perfection." % d_name)
			dynamic_lines.append("I slip %s the best cuts when you aren't looking. Perks of the job." % d_name)
			dynamic_lines.append("%s has that proper killer's posture. Makes me proud." % d_name)
			dynamic_lines.append("I'd bite a man's hand off for touching %s without permission." % d_name)
			dynamic_lines.append("%s knows they're my favorite. Spoiled thing struts like a queen." % d_name)

		# --- STAGE: 5 VARIATIONS EACH ---
		if d_stage == 3:
			dynamic_lines.append("%s is getting massive. We're gonna need a bigger enclosure soon." % d_name)
			dynamic_lines.append("I caught %s eyeing the cavalry horses earlier. Might want to double their rations." % d_name)
			dynamic_lines.append("%s has started pacing the fence like they own the whole camp. Frankly, they nearly do." % d_name)
			dynamic_lines.append("When %s spreads those wings, half the recruits forget how to breathe." % d_name)
			dynamic_lines.append("%s carries adulthood like a blade: heavy, beautiful, and made for harm." % d_name)
		elif d_stage == 2:
			dynamic_lines.append("%s is in that awkward stage: too big to cuddle, too young to stop causing trouble." % d_name)
			dynamic_lines.append("%s spent the morning testing every latch in the pen. Smart beast." % d_name)
			dynamic_lines.append("%s has been picking fights with shadows, barrels, and one very unlucky bucket." % d_name)
			dynamic_lines.append("%s is all limbs, temper, and ambition right now. Promising combination." % d_name)
			dynamic_lines.append("%s keeps acting offended when the adults ignore them. Good. Let that pride grow teeth." % d_name)
		elif d_stage == 1:
			dynamic_lines.append("%s nearly bit my thumb off this morning. Perfect instincts." % d_name)
			dynamic_lines.append("Little %s fell asleep on my boots last night. Don't tell the men, it ruins my reputation." % d_name)
			dynamic_lines.append("%s keeps trying to roar like the adults. Comes out more adorable than threatening." % d_name)
			dynamic_lines.append("%s still trips over those oversized claws, then acts offended when I laugh." % d_name)
			dynamic_lines.append("%s follows me around like a murderous duckling. I pretend not to enjoy it." % d_name)
		elif d_stage == 0:
			dynamic_lines.append("I've been keeping the %s egg warm. I can feel it kicking." % d_elem)
			dynamic_lines.append("The %s egg rattled twice this morning. Strong little brute in there." % d_elem)
			dynamic_lines.append("That %s shell is holding heat nicely. Won't be quiet for much longer." % d_elem)
			dynamic_lines.append("I've got the %s egg tucked near the coals. It twitches whenever I hum at it." % d_elem)
			dynamic_lines.append("This %s egg's got a fierce little pulse to it. Makes me smile." % d_elem)

		# --- ELEMENT: 5 VARIATIONS EACH ---
		if d_elem == "Fire" and d_stage > 0:
			dynamic_lines.append("%s sneezed and torched a target dummy. Highly impressive." % d_name)
			dynamic_lines.append("I use %s to light the campfires now. Very efficient." % d_name)
			dynamic_lines.append("%s keeps turning the feeding trough warm enough to steam. Saves me work." % d_name)
			dynamic_lines.append("When %s yawns, the whole pen glows like a forge mouth." % d_name)
			dynamic_lines.append("%s has that lovely habit of making the dark itself back away." % d_name)
		elif d_elem == "Ice" and d_stage > 0:
			dynamic_lines.append("Keep %s away from the forge, they're freezing the blacksmith's anvil." % d_name)
			dynamic_lines.append("I had to chip frost off my armor after brushing %s today." % d_name)
			dynamic_lines.append("%s leaves little white crystals on the straw wherever they curl up." % d_name)
			dynamic_lines.append("The water trough turns to slush every time %s gets moody." % d_name)
			dynamic_lines.append("%s exhales and the whole pen feels like winter sharpening its teeth." % d_name)
		elif d_elem == "Lightning" and d_stage > 0:
			dynamic_lines.append("%s gave me quite the shock earlier. Literally." % d_name)
			dynamic_lines.append("The air smells like ozone whenever %s gets excited." % d_name)
			dynamic_lines.append("%s sparked against the fence again. Singed three ropes and one fool's eyebrows." % d_name)
			dynamic_lines.append("Every scale on %s crackles before a tantrum. Handy warning, that." % d_name)
			dynamic_lines.append("%s moves like thunder thinking out loud. Hard not to admire that." % d_name)
		elif d_elem == "Wind" and d_stage > 0:
			dynamic_lines.append("%s keeps trying to blow the mess tent over. The cooks are furious." % d_name)
			dynamic_lines.append("%s beat their wings once and sent straw halfway across the yard." % d_name)
			dynamic_lines.append("Trying to groom %s is miserable. One gust and my tools are in the next pen." % d_name)
			dynamic_lines.append("%s gets playful and suddenly the whole ranch sounds like a storm front." % d_name)
			dynamic_lines.append("%s hates being still. Even their breathing feels like weather." % d_name)
		elif d_elem == "Earth" and d_stage > 0:
			dynamic_lines.append("%s dug a trench right through the latrines. It's a mess, but I admire the work ethic." % d_name)
			dynamic_lines.append("%s stomps when annoyed, and the whole pen shivers with it." % d_name)
			dynamic_lines.append("I found %s half-buried in the dirt again. Calm as a king in a grave." % d_name)
			dynamic_lines.append("%s scratches stone like it's soft bark. Strong little monster." % d_name)
			dynamic_lines.append("There's something comforting about how %s makes the ground answer back." % d_name)

		# --- TRAITS: 5 VARIATIONS EACH GROUP ---
		if "Vicious" in traits or "Savage" in traits:
			dynamic_lines.append("I have to feed %s with a long pole today. Nasty mood." % d_name)
			dynamic_lines.append("%s snapped clean through a practice post just because it leaned the wrong way." % d_name)
			dynamic_lines.append("There's mean, then there's %s staring at something until it regrets existing." % d_name)
			dynamic_lines.append("%s likes the sound armor makes when it dents. I respect that." % d_name)
			dynamic_lines.append("You don't correct a vicious dragon by scolding. You survive it until the lesson sticks." % d_name)

		if "Swift" in traits or "Lightning Reflexes" in traits:
			dynamic_lines.append("Trying to catch %s to brush those scales is a nightmare. Too damn fast." % d_name)
			dynamic_lines.append("%s slipped past me, stole a strip of jerky, and vanished under the rail in a blink." % d_name)
			dynamic_lines.append("You don't handle %s by chasing. You stand still and wait for them to make a mistake." % d_name)
			dynamic_lines.append("%s moves like a thrown knife. Blink wrong and they're somewhere else." % d_name)
			dynamic_lines.append("I've seen assassins with slower feet than %s on a lazy morning." % d_name)

		if "Gentle Soul" in traits:
			dynamic_lines.append("I swear %s acts more like a lapdog than an apex predator." % d_name)
			dynamic_lines.append("%s nudged a crying recruit until he stopped shaking. Strange little sweetheart." % d_name)
			dynamic_lines.append("For all those teeth, %s handles hatchlings softer than most people handle babies." % d_name)
			dynamic_lines.append("%s keeps resting that big head on my shoulder like they think I'm a nest." % d_name)
			dynamic_lines.append("There's kindness in %s that makes the rest of their bite feel almost unfair." % d_name)

		if "Voracious" in traits:
			dynamic_lines.append("I think %s ate a whole barrel of apples. Wood and all." % d_name)
			dynamic_lines.append("If I turn my back on supper for a heartbeat, %s starts negotiating with the bucket." % d_name)
			dynamic_lines.append("%s chewed through today's feed, then looked at me like appetizers had just ended." % d_name)
			dynamic_lines.append("I've seen wolves with better restraint than %s near a full trough." % d_name)
			dynamic_lines.append("There are hungry dragons, and then there's %s looking at the feed cart like a love letter." % d_name)

		if "Loyal" in traits or "Heartbound" in traits:
			dynamic_lines.append("%s won't stop staring at your command tent. Missing you, I think." % d_name)
			dynamic_lines.append("%s calms the second your scent hits the yard. Spoiled thing." % d_name)
			dynamic_lines.append("I could bark orders all day, but %s still listens hardest for your voice." % d_name)
			dynamic_lines.append("%s guards anything that smells like you. Nearly bit a quartermaster over a cloak." % d_name)
			dynamic_lines.append("The bond on %s is so fierce it almost makes me jealous, and I raised the beast." % d_name)

		if "Cunning" in traits or "Mastermind" in traits:
			dynamic_lines.append("Count your coin purses. %s figured out how to undo steel latches today." % d_name)
			dynamic_lines.append("%s watched me open the feed lock once. Once. That was enough." % d_name)
			dynamic_lines.append("There's too much thinking behind %s eyes. I like it, but it keeps me alert." % d_name)
			dynamic_lines.append("%s arranged bones in a neat little pile by the gate. Felt deliberate." % d_name)
			dynamic_lines.append("I don't mind a clever dragon. I mind clever dragons pretending to nap. Like %s." % d_name)

		if "Regenerative" in traits or "Everlasting" in traits:
			dynamic_lines.append("%s scraped a wing on the palisade. Healed before the blood even hit the dirt." % d_name)
			dynamic_lines.append("I checked %s's old scar this morning. Gone like it never happened." % d_name)
			dynamic_lines.append("You patch %s up out of habit, then remember the beast barely needs you." % d_name)
			dynamic_lines.append("%s recovers faster than some soldiers complain. That's saying plenty." % d_name)
			dynamic_lines.append("It's unsettling how quickly %s knits back together. Useful, though." % d_name)

		if "Sky Dancer" in traits or "Zephyr Lord" in traits:
			dynamic_lines.append("Good luck keeping %s grounded. Been doing loops around the watchtower all morning." % d_name)
			dynamic_lines.append("%s treats fences like insults and rooftops like invitations." % d_name)
			dynamic_lines.append("The moment I unclip a chain, %s is already carving circles into the clouds." % d_name)
			dynamic_lines.append("%s lands light as ash for something with that much wing and ego." % d_name)
			dynamic_lines.append("When %s takes to the sky, even the other dragons stop to watch." % d_name)

	return dynamic_lines
