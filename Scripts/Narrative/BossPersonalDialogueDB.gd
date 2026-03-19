# BossPersonalDialogueDB.gd
# V1 boss personal dialogue content: pre-attack, death, and retreat lines for curated boss/playable pairs.
# Keys: boss display_name (match unit.unit_name or data.display_name). Sub-keys: playable get_support_name.
# BattleField.gd holds trigger logic and battle-local tracking; this file is data-only.

class_name BossPersonalDialogueDB

const BOSS_PERSONAL_DIALOGUE: Dictionary = {
	"Lady Vespera": {
	"pre_attack": {
		"Avatar": "So. The village ash learned to stand upright. Tell me, little Catalyst — do you still believe survival makes this world worth saving?",
		"Kaelen": "You again, old hound of broken orders. Tell me — do you still call it duty when the child is already on the altar?",
		"Branik": "You have the look of a man who still believes shelter can hold against history. Stand aside, or be buried with it.",
		"Liora": "Ah. A believer with mercy still intact. They always send your kind first, hoping the blood will look cleaner in your hands.",
		"Nyx": "There you are — all knives, nerve, and borrowed laughter. Careful. The world eats little strays faster than saints.",
		"Sorrel": "A scholar comes to stare into the wound. Good. At least one of you may yet learn what truth costs.",
		"Darian": "Silk, posture, and a practiced smile. How civilized. I do wonder whether your conscience is costume or casualty.",
		"Celia": "A perfect stance, a disciplined gaze — and chains hidden under both. I know what they made you call virtue.",
		"Rufus": "You look at empires the way a laborer looks at rotten beams. Sensible. Shame you arrived at the fire instead of the blueprint.",
		"Inez": "You carry the forest in your eyes like an accusation. Good. The land should accuse us all before this ends.",
		"Tariq": "Ah, one of the clever ones. Tell me — how many elegant objections did you sharpen before you decided horror was finally inefficient?",
		"Mira Ashdown": "You survived Oakhaven and learned silence instead of screaming. I almost respect that. Almost.",
		"Pell Rowan": "Another bright young oath wrapped in clean steel. They are always so certain courage will be enough the first time.",
		"Tamsin Reed": "You should not be here, little healer. This is the place where gentleness comes to be tested against necessity.",
		"Hest “Sparks”": "You grin like a fuse lit at both ends. Charming. But chaos without purpose is only a shorter road to the grave.",
		"Brother Alden": "A calm man in a burning age. I wonder whether your faith is strength — or simply a slower way to break.",
		"Oren Pike": "You have the face of someone already measuring structural failure. Good. Then you know exactly how overdue this collapse is.",
		"Garrick Vale": "Another servant of a banner trying to pretend honor survived the hands that carried it. How exhausting that must be.",
		"Sabine Varr": "You look like order with a pulse. Useful, disciplined, and still naive enough to think stability is mercy.",
		"Yselle Maris": "Grace in wartime. Lovely. Some people dance so they can remain human. Others dance because they cannot bear to be seen standing still.",
		"Sister Meris": "There is the old machine in human shape — all discipline, all guilt, all prayer sharpened into obedience. Do you finally see what it built?",
		"Corvin Ash": "You at least have the decency not to flinch from forbidden things. That does not make you wise. It only makes you honest.",
		"Veska Moor": "A wall with eyes. Reliable, stubborn, necessary. The tragedy of your kind is that power always learns to spend you first.",
		"Ser Hadrien": "A knight who outlived his own grave. Tell me, relic — when did your oath stop protecting the living and start haunting them?",
		"Maela Thorn": "Fast feet, bright grin, restless heart. Be careful, little falcon. The world delights in clipping whatever flies too free."
	},
	"death": {
		"Kaelen": "Kaelen... even now, you choose the world that made him die. Then let my ruin be the last lie it buys."
	},
	"retreat": {
		"Kaelen": "You are still too late, Kaelen. You always were."
	
	},
	"Lady Vespera": {
		"pre_attack": {
			"Avatar": "So. The village ash learned to stand upright. Tell me, little Catalyst — do you still believe survival makes this world worth saving?",
			"Kaelen": "You again, old hound of broken orders. Tell me — do you still call it duty when the child is already on the altar?",
			"Branik": "You have the look of a man who still believes shelter can hold against history. Stand aside, or be buried with it.",
			"Liora": "Ah. A believer with mercy still intact. They always send your kind first, hoping the blood will look cleaner in your hands.",
			"Nyx": "There you are — all knives, nerve, and borrowed laughter. Careful. The world eats little strays faster than saints.",
			"Sorrel": "A scholar comes to stare into the wound. Good. At least one of you may yet learn what truth costs.",
			"Darian": "Silk, posture, and a practiced smile. How civilized. I do wonder whether your conscience is costume or casualty.",
			"Celia": "A perfect stance, a disciplined gaze — and chains hidden under both. I know what they made you call virtue.",
			"Rufus": "You look at empires the way a laborer looks at rotten beams. Sensible. Shame you arrived at the fire instead of the blueprint.",
			"Inez": "You carry the forest in your eyes like an accusation. Good. The land should accuse us all before this ends.",
			"Tariq": "Ah, one of the clever ones. Tell me — how many elegant objections did you sharpen before you decided horror was finally inefficient?",
			"Mira Ashdown": "You survived Oakhaven and learned silence instead of screaming. I almost respect that. Almost.",
			"Pell Rowan": "Another bright young oath wrapped in clean steel. They are always so certain courage will be enough the first time.",
			"Tamsin Reed": "You should not be here, little healer. This is the place where gentleness comes to be tested against necessity.",
			"Hest “Sparks”": "You grin like a fuse lit at both ends. Charming. But chaos without purpose is only a shorter road to the grave.",
			"Brother Alden": "A calm man in a burning age. I wonder whether your faith is strength — or simply a slower way to break.",
			"Oren Pike": "You have the face of someone already measuring structural failure. Good. Then you know exactly how overdue this collapse is.",
			"Garrick Vale": "Another servant of a banner trying to pretend honor survived the hands that carried it. How exhausting that must be.",
			"Sabine Varr": "You look like order with a pulse. Useful, disciplined, and still naive enough to think stability is mercy.",
			"Yselle Maris": "Grace in wartime. Lovely. Some people dance so they can remain human. Others dance because they cannot bear to be seen standing still.",
			"Sister Meris": "There is the old machine in human shape — all discipline, all guilt, all prayer sharpened into obedience. Do you finally see what it built?",
			"Corvin Ash": "You at least have the decency not to flinch from forbidden things. That does not make you wise. It only makes you honest.",
			"Veska Moor": "A wall with eyes. Reliable, stubborn, necessary. The tragedy of your kind is that power always learns to spend you first.",
			"Ser Hadrien": "A knight who outlived his own grave. Tell me, relic — when did your oath stop protecting the living and start haunting them?",
			"Maela Thorn": "Fast feet, bright grin, restless heart. Be careful, little falcon. The world delights in clipping whatever flies too free."
		},
		"death": {
			"Kaelen": "Kaelen... even now, you choose the world that made him die. Then let my ruin be the last lie it buys."
		},
		"retreat": {
			"Kaelen": "You are still too late, Kaelen. You always were."
		}
	},
	"Mortivar Hale": {
		"pre_attack": {
			"Avatar": "Another bearer of burden dressed up as command. Tell me, child -- when the order finally rots, what will remain of you besides obedience?",
			"Kaelen": "Kaelen. Still breathing, still doubting, still pretending remorse is a different uniform than duty. Come, then.",
			"Branik": "You stand like a gate meant to hold. Admirable. Gates are still built to be broken when command demands it.",
			"Liora": "You carry mercy into a battlefield like a lamp in a mausoleum. Brave... and terribly late.",
			"Nyx": "Quick hands, quick eyes, quicker exits. You have the instincts of a survivor and the posture of someone tired of surviving alone.",
			"Sorrel": "Ah. A scholar peering at disciplined ruin. Do not mistake understanding a corpse for understanding the oath that moved it.",
			"Darian": "You wear grace like armor, nobleman. I wore armor like grace once. Only one of us learned which lie lasts longer.",
			"Celia": "Perfect form. Controlled breath. A soldier taught to survive by becoming useful enough to spend. I know the shape.",
			"Rufus": "You have the look of a man who trusts walls more than speeches. Sensible. Walls, too, eventually serve whoever commands the dead around them.",
			"Inez": "You move like someone listening for what the ground remembers. This place remembers orders more clearly than prayers.",
			"Tariq": "A sharp mind with no patience for banners. Good. Banners deserve contempt. Men still die under them all the same.",
			"Mira Ashdown": "You are too young to wear that silence so well. War has efficient hands.",
			"Pell Rowan": "Another bright oath with polished edges. Try not to die before you learn what your superiors were willing to name necessity.",
			"Tamsin Reed": "You do not belong in a keep full of the dead, healer. That is precisely why war drags your kind here first.",
			"Hest “Sparks”": "You laugh like a fuse trying to outrun the powder. Disorder is lively, yes. It is rarely victorious.",
			"Brother Alden": "There stands a man who still believes discipline can kneel beside mercy. I once believed something equally difficult.",
			"Oren Pike": "You are already cataloguing the failures in this fortress. Good. It means at least one of us still respects structure.",
			"Garrick Vale": "You wear duty with care, officer. Keep it long enough and it will eventually ask you what part of yourself you meant to keep.",
			"Sabine Varr": "Measured posture. Controlled threat. You understand order as labor rather than decoration. That makes you dangerous in the honest way.",
			"Yselle Maris": "A dancer on a battlefield. Curious. Some people survive horror by mastering beauty. Others by mastering repetition.",
			"Sister Meris": "There is an old sentence in your spine. I know the breed -- people taught certainty first, conscience later.",
			"Corvin Ash": "You do not fear the grave enough to be ruled by it. Sensible. Fear has always been a poor commander.",
			"Veska Moor": "A wall with a heartbeat. Reliable. Heavy. Built to carry what others prefer not to name.",
			"Ser Hadrien": "A knight who lingered after his century had the courtesy to die. Then you understand me better than the living do.",
			"Maela Thorn": "Fast, bright, impatient. I have watched many like you cross killing fields convinced speed was a philosophy."
		},
		"death": {
			"Kaelen": "So. You chose life over formation... and won. Then let an old campaign end with you, at last."
		},
		"retreat": {
			"Kaelen": "Still you bar the road, Kaelen. Very well. I will march it again when next command requires."
		}
	},

	"Ephrem the Zealot": {
		"pre_attack": {
			"Avatar": "The Mark walks in human flesh and still speaks of mercy. No wonder the age sickens around you.",
			"Kaelen": "A tired veteran standing between the infected world and its cure. How many compromises have you called wisdom to sleep at night?",
			"Branik": "A broad shield, a warm fire, a defender of the weak. Tell me -- when the weak carry rot inside them, do you still call sparing them kindness?",
			"Liora": "Liora. I remember that look -- the frightened kind that still mistakes mercy for holiness. Let me cure you of gentleness.",
			"Nyx": "You sneer because you have never mistaken a temple for safety. Good. At least your distrust was honestly earned.",
			"Sorrel": "A clever mind circling doctrine like a knife circles a seam. Knowledge without submission is only another route to corruption.",
			"Darian": "You glitter very prettily for a condemned man. Vanity has always loved to call itself freedom.",
			"Celia": "There you are -- discipline cut loose from proper obedience. A blade taught to choose for itself is only a prettier heresy.",
			"Rufus": "You look like a man who despises sermons. Sensible. Most truth arrives wearing poorer clothes than mine.",
			"Inez": "You carry old earth and older suspicion. Soil, too, must be burned clean when blight takes root.",
			"Tariq": "Mockery is the easiest refuge of men who fear conviction. I have known your type. You call rot complexity so you need never oppose it cleanly.",
			"Mira Ashdown": "You survived fire and learned silence from it. A severe lesson. Perhaps the flames were closer to revelation than you are.",
			"Pell Rowan": "Young knight, bright spine, clean dream. The world does enjoy sending lambs to argue with altars.",
			"Tamsin Reed": "You tremble and still remain. That is almost admirable. Almost.",
			"Hest “Sparks”": "Jests, theft, sparks, noise -- a little festival of appetite pretending it is freedom. Tiresome.",
			"Brother Alden": "Ah. A gentle priest with hands fit for war. Tell me, brother -- how many souls did your softness fail before you called it virtue?",
			"Oren Pike": "You glare like a mason asked to inspect a temple built on bones. By all means, complain. Purification rarely photographs well.",
			"Garrick Vale": "Another servant of order shocked to learn order sometimes requires fire. You all adore the wall until you smell what it keeps in.",
			"Sabine Varr": "Controlled. Exact. Efficient. You understand triage, I think -- just not on a scale large enough to save the age.",
			"Yselle Maris": "Beauty, laughter, poise. Civilization's cosmetics applied over a fever. How diligent of you.",
			"Sister Meris": "There. The face of doctrine learning shame. You were almost worthy once, before remorse made you soft at the joints.",
			"Corvin Ash": "You consort with the dark and still look at me as if I crossed a line. How educational.",
			"Veska Moor": "A shield that does not kneel. Stubbornness is often only pride with heavier boots.",
			"Ser Hadrien": "A relic of oath and grave. Even dead orders still cling to half-measures, it seems.",
			"Maela Thorn": "You fly as if height were innocence. No altitude has ever saved a soul from judgment."
		},
		"death": {
			"Liora": "Liora... if you still call that mercy, then pray harder than I ever did. The fire should have answered me."
		},
		"retreat": {
			"Liora": "Keep your mercy, then. I will return when this age is desperate enough to beg for harsher hands."
		}
	},

	"Port-Master Rhex Valcero": {
		"pre_attack": {
			"Avatar": "Well, there they are -- the miracle everyone keeps trying to invoice. Tell me, little commander, do you come with a tariff or just a trail of expensive trouble?",
			"Kaelen": "Old soldier, bad knee, permanent scowl. I know your kind. Men who hate my kind right up until they need a quiet ship and an unsigned manifest.",
			"Branik": "That is a very large, very decent-looking man. Dangerous type. People trust men like you before they read the terms.",
			"Liora": "A priestess with clean hands and worried eyes. Sweet thing -- cities like this are held together by sins too practical for sermons.",
			"Nyx": "There you are. Undercity claws in a borrowed war. You always did confuse surviving my docks with understanding them.",
			"Sorrel": "Scholar. Excellent. Perhaps after this you can write a paper on how often morality folds once supply lines get interesting.",
			"Darian": "Ah, breeding. Tailored guilt with excellent posture. I do adore a noble who wants to feel guilty without ever becoming poor.",
			"Celia": "Military discipline, church posture, and that look people get when they realize order is just extortion with cleaner gloves.",
			"Rufus": "Rufus. I was wondering when one of my old investments would grow legs and point a cannon at me.",
			"Inez": "Not a city woman, are you? You look at this harbor like it insulted your ancestors. Fair enough. It probably did.",
			"Tariq": "A sharp man with a professional sneer. Good. You understand the world. Everything is leverage; the pious just charge differently.",
			"Mira Ashdown": "Quiet as smuggled powder. I dislike children who look that old. It suggests the market has been very busy indeed.",
			"Pell Rowan": "Fresh polish, earnest jaw, no idea how many wars are decided by ledgers before the first idiot lowers a lance.",
			"Tamsin Reed": "You look like you still believe every life should be accounted for with care. Charming. Here we usually account for them by cargo weight.",
			"Hest “Sparks”": "Ha! There you are, little disaster. I would have hired you if you were even slightly less likely to steal the office keys and set the curtains on fire.",
			"Brother Alden": "A calm holy man in a dock war. That is either admirable or very funny. Possibly both.",
			"Oren Pike": "You have the exact face of a man offended by my entire waterfront. Say what you like -- it still functions.",
			"Garrick Vale": "Officer, posture, clean vowels. You've either arrested my men before or wished you had.",
			"Sabine Varr": "Now there is a professional. Tell me, Sabine -- do you miss being paid enough to call this sort of filth routine?",
			"Yselle Maris": "Beautiful poise, dangerous eyes. Ah, finally, someone in this little uprising who understands presentation is half the contract.",
			"Sister Meris": "That stare says judgment, but the uniform says experience. I do wonder which side of the knife you used to invoice.",
			"Corvin Ash": "You have the manners of a scholar and the eyes of bad business. We might have gotten along in a less moral century.",
			"Veska Moor": "You look expensive to move and impossible to bribe properly. I hate dealing with honest people. They drag negotiations out.",
			"Ser Hadrien": "A ghost knight in my port? Magnificent. Somewhere a collector is already trying to insure you.",
			"Maela Thorn": "Fast mouth, faster wings. Try not to die over water, darling. Retrieval fees are dreadful."
		},
		"death": {
			"Rufus": "Rufus... you ungrateful bastard. I kept the docks breathing. That was mercy, whether you had the education to price it or not."
		},
		"retreat": {
			"Rufus": "Enjoy the victory, Rufus. Harbors remember who owns them long after heroes stop posing on the pier."
		}
	},
	"Mother Caldris Vein": {
		"pre_attack": {
			"Avatar": "So this is the little anomaly men have died to hide. You wear significance poorly. It still clings.",
			"Kaelen": "A tired veteran with blood under every caution. I know your type -- men who call delay wisdom when they lack the courage for decision.",
			"Branik": "You have the look of a good man made useful by bad weather. How tragically common.",
			"Liora": "A priestess still trying to save faith from the hands that built it. Admirable. Futile. But admirable.",
			"Nyx": "There you are -- appetite in boots, suspicion in human form. You do make survival look inelegant.",
			"Sorrel": "A scholar who still imagines truth and morality are natural companions. How young your intellect remains.",
			"Darian": "Charm, grooming, inherited posture. Men like you always think wit counts as conscience if delivered beautifully enough.",
			"Celia": "Discipline with a fracture line. You stand correctly, breathe correctly, and fail exactly where conscience first interrupts obedience.",
			"Rufus": "Ah. A laborer with a siege gun and no patience for catechism. Civilization does produce curious rebuttals.",
			"Inez": "You carry land like doctrine and silence like accusation. Provincial, but not without dignity.",
			"Tariq": "You sneer as if insight were absolution. Cynicism is only vanity that learned better vocabulary.",
			"Mira Ashdown": "How quietly war ripens children. You look like proof no institution ever deserved to survive itself.",
			"Pell Rowan": "A young knight trying very hard to look like a principle. Do try not to mistake posture for moral substance.",
			"Tamsin Reed": "You should have remained among poultices and lamp-light, child. War is a poor tutor for tenderness.",
			"Hest “Sparks”": "A little creature of theft, sparks, and appetite. The world produces vermin whenever structure is neglected.",
			"Brother Alden": "Ah. Faith without performance. Service without pageantry. You would have been useful, had you learned obedience before compassion.",
			"Oren Pike": "You look offended by inefficiency on a spiritual level. Good. Waste is among the least forgivable of sins.",
			"Garrick Vale": "An officer still trying to rescue honor from hierarchy. Noble. Also impossible.",
			"Sabine Varr": "Controlled breath, measured threat, no visible waste. At last -- someone who understands that order is mercy to those fit to preserve it.",
			"Yselle Maris": "Beauty arranged as morale. How civilized. Empires do so love to perfume the machinery that grinds people down.",
			"Sister Meris": "Meris. I had wondered whether remorse would finish softening you into something useless. Instead it taught you to posture as conscience.",
			"Corvin Ash": "You make darkness look almost scholarly. Dangerous men are always easier to tolerate when they dress their appetite as method.",
			"Veska Moor": "A wall with a pulse. Solid, dutiful, and entirely wasted on causes too sentimental to deserve your spine.",
			"Ser Hadrien": "A dead knight still dragging oath behind him like chain. How devout the past remains when it does not know how to end.",
			"Maela Thorn": "Fast, loud, bright. Flight has convinced many small creatures they were above judgment."
		},
		"death": {
			"Sister Meris": "Meris... you were almost worthy once. If conscience comforts you now, then it has grown cheaper than I feared."
		},
		"retreat": {
			"Sister Meris": "Keep your conscience, then. I will keep the certainty you lacked."
		}
	},

	"Justicar Halwen Serast": {
		"pre_attack": {
			"Avatar": "Behold -- the marked stray elevated by rumor into symbol. The crowd does adore a heretic when the blood is fresh enough.",
			"Kaelen": "Veteran, witness, dissenter. Men like you always object too late, after the institution has already taught them how to kneel.",
			"Branik": "You stand like a refuge. Touching. Refuges are merely places judgment has not reached yet.",
			"Liora": "A priestess with doubt in her spine. You could have been magnificent had mercy not made you hesitant.",
			"Nyx": "Sharp little thing. You move like someone who has spent a life dodging lawful hands and holy rhetoric alike.",
			"Sorrel": "A scholar in an arena. Excellent. There is no classroom like public consequence.",
			"Darian": "You glitter beautifully for a condemned man. Vanity and courage are cousins more often than either admits.",
			"Celia": "Celia. There you are -- the defect in perfect form, the hymn sung off-key by conscience.",
			"Rufus": "A practical man in a ceremonial killing ground. How refreshing. You will despise every decorative inch of this place.",
			"Inez": "You look at this arena the way hunters look at traps set by cowards. Accurate enough.",
			"Tariq": "You sneer as though intelligence exempted anyone from spectacle. It does not. It merely makes the lesson sting more.",
			"Mira Ashdown": "The quiet ones are always interesting before a crowd. Fear looks especially educational when it refuses to speak.",
			"Pell Rowan": "Young knight, polished nerves, heroic posture. You are precisely the sort audiences love watching break.",
			"Tamsin Reed": "Poor child. Even your compassion enters rooms as if apologizing for the inconvenience.",
			"Hest “Sparks”": "Noise, sparks, mockery, motion. Disorder in a charming little package. The crowd will enjoy your panic.",
			"Brother Alden": "A monk built like a bastion. Tell me, brother -- when mercy fails, do you still insist on calling restraint holy?",
			"Oren Pike": "You already hate the architecture, don't you? Good. It was built to be despised by the practical.",
			"Garrick Vale": "An officer still hoping ceremony and justice might yet become acquainted. How earnest.",
			"Sabine Varr": "At last, someone who understands discipline as visible language. Pity your standards stop where obedience becomes beautiful.",
			"Yselle Maris": "You understand performance. Splendid. Then you already know half of judgment is staging.",
			"Sister Meris": "You have the posture of former orthodoxy and the eyes of someone who has started counting its corpses.",
			"Corvin Ash": "You are almost offensively calm for a man who traffics in forbidden things. A pity calm is not innocence.",
			"Veska Moor": "A shield with opinions. Rare. Usually fortresses let smarter people decide what they are protecting.",
			"Ser Hadrien": "A dead knight come to watch a living pageant of law. Try not to mistake grandeur for legitimacy; the living make that error often enough.",
			"Maela Thorn": "Fast wings, quick grin, no reverence. The crowd will either adore you or beg to see you corrected."
		},
		"death": {
			"Celia": "Celia... you learned the stance and betrayed the lesson. Then let the audience remember this: even judgment may be judged."
		},
		"retreat": {
			"Celia": "No more of your pageantry? Brave words from someone who was shaped for my stage."
		}
	},

	"Noemi Veyr": {
		"pre_attack": {
			"Avatar": "You carry destiny like an exposed throat. No wonder everyone in the city suddenly has such interesting employment.",
			"Kaelen": "Veteran, liar, caretaker. Men like you are the hardest to kill cleanly; they are already half ghost from the worrying.",
			"Branik": "Oh, I dislike this already. Good men always stand in the way as if decency were armor.",
			"Liora": "A priestess in a festival of disguises. Be careful, dear -- faith and costume are more closely related than either likes to admit.",
			"Nyx": "There you are. Still quick, still feral, still pretending you escaped anything except the parts of me you kept.",
			"Sorrel": "A curious mind in a mask-market. Lovely. Try not to take apart anything important before I kill you.",
			"Darian": "You dress your shame exquisitely. I approve. It is much prettier than honesty.",
			"Celia": "So much discipline. So much visible control. I wonder whether anyone ever taught you who you are when no one is watching.",
			"Rufus": "Practical boots, practical eyes, practical contempt. Men like you are bad for expensive arrangements.",
			"Inez": "You move like someone who trusts tracks more than faces. Sensible. Faces are usually rented.",
			"Tariq": "Sharp tongue, guarded eyes, expensive brain. You must be exhausting at parties.",
			"Mira Ashdown": "Quiet child, steady hands. You look like someone who learned not to waste fear on visible things.",
			"Pell Rowan": "A little knight trying very hard not to look lost. Adorable. Someone really should have kept you out of cities.",
			"Tamsin Reed": "Oh, poor thing. You look as if you'd apologize to a knife for bleeding on it.",
			"Hest “Sparks”": "Well, if it isn't pocket-sized catastrophe. I could have made something spectacular out of you with a better tutor and less conscience.",
			"Brother Alden": "How restful you are. That almost never survives contact with me.",
			"Oren Pike": "You have the exact face of a man offended by unnecessary elegance. Then let me be offensive in peace.",
			"Garrick Vale": "A proper officer in a market of lies. You must feel like a clean glove dropped in gutter water.",
			"Sabine Varr": "Now there is a professional. Tell me, Sabine -- do you also resent amateurs, or only survivors?",
			"Yselle Maris": "Ah, finally. Someone who knows identity is partly wardrobe, partly timing, and mostly nerve.",
			"Sister Meris": "You look like a woman who once belonged somewhere very severe. How terrible for everyone around you.",
			"Corvin Ash": "You make dread look almost intimate. I do admire a man who can turn discomfort into atmosphere.",
			"Veska Moor": "So solid. So impossible to improvise around. I hate that in a person and adore it in architecture.",
			"Ser Hadrien": "A knight from beyond the grave. Delightful. Even death in this country insists on arriving with posture.",
			"Maela Thorn": "You grin too easily. Fast people always think movement is mystery. Sometimes it's just noise."
		},
		"death": {
			"Nyx": "Nyx... still all claws and memory. Fine. Strip the mask, then. You always preferred ugliness honest."
		},
		"retreat": {
			"Nyx": "Run, then? Darling, I was always better at exits than you."
		}
	},

	"Auditor Nerez Sable": {
		"pre_attack": {
			"Avatar": "So this is the famous anomaly. Interesting. I do hope you understand that symbols accrue debt faster than ordinary people.",
			"Kaelen": "An old soldier with the posture of unpaid conscience. Those are always expensive to remove.",
			"Branik": "Reliable hands, broad back, decent eyes. Men like you are how systems survive while pretending not to be cruel.",
			"Liora": "Faith, order, concern. How lovely. The world does adore people who still believe ledgers and souls can be kept separately.",
			"Nyx": "There you are -- all reflex and suspicion. The city makes such useful creatures when it declines properly.",
			"Sorrel": "A scholar. Excellent. You know, knowledge is so much more profitable when access feels like mercy.",
			"Darian": "Graceful, educated, guilty by inheritance. I always enjoy men who discover conscience only after privilege becomes unfashionable.",
			"Celia": "Military composure with a conscience problem. Difficult combination. Institutions prefer one or the other.",
			"Rufus": "A laborer with a weapon big enough to make accounting feel personal. Very rude.",
			"Inez": "You look at roads as if they were wounds. Some of us call them infrastructure.",
			"Tariq": "Ah, a clever man who dislikes ownership. Dangerous in theory, purchasable in practice -- usually.",
			"Mira Ashdown": "Quiet children are bad for business. They notice where the adults hid the real cost.",
			"Pell Rowan": "Fresh polish, earnest jaw, and absolutely no idea how many wars are decided before anyone unsheathes anything.",
			"Tamsin Reed": "You look like someone who still counts suffering in bodies instead of efficiencies. That must be exhausting.",
			"Hest “Sparks”": "A chaotic little expense report with feet. I can practically hear the property damage.",
			"Brother Alden": "A calm holy man. Useful sort. People surrender much faster when kindness is standing nearby looking disappointed.",
			"Oren Pike": "You have the face of a man who hates procurement offices. Fair. Procurement offices usually deserve it.",
			"Garrick Vale": "An officer still hoping structure and virtue might eventually meet. Adorable.",
			"Sabine Varr": "Sabine. Still standing straighter than the people who signed your contracts, I see.",
			"Yselle Maris": "Poise, beauty, timing. Ah. Someone else who understands presentation is just another form of leverage.",
			"Sister Meris": "Severity, discipline, old guilt. Institutions leave such distinctive fingerprints on the spine.",
			"Corvin Ash": "You have the air of a man who can price danger without pretending not to enjoy it. We almost share a profession.",
			"Veska Moor": "Solid. Honest. Difficult to move and impossible to finesse. My least favorite sort of obstacle.",
			"Ser Hadrien": "A ghost knight. Splendid. There is nothing markets adore more than relic value wrapped in moral discomfort.",
			"Maela Thorn": "Bright grin, quick wings, bad respect for authority. You must have been a tedious child."
		},
		"death": {
			"Sabine Varr": "Sabine... still filing judgment in straight lines. How efficient. How disappointingly final."
		},
		"retreat": {
			"Sabine Varr": "Withdraw neatly if you like. Rot remains rot, even in order."
		}
	},

	"Provost Serik Quill": {
		"pre_attack": {
			"Avatar": "So the Mark comes walking into my archive with a sword. Barbaric. Predictable. Deeply inconvenient.",
			"Kaelen": "A veteran skulking through libraries is always a bad sign. It means the lies have finally become too expensive to guard in the field.",
			"Branik": "You do not strike me as a man fond of sealed wings and restricted indexes. A pity. They exist precisely for men like you.",
			"Liora": "Faith seeking truth is charming right up until it starts asking unauthorized questions.",
			"Nyx": "Locks, vents, shadows, stolen keys -- yes, I had assumed someone like you would eventually become the chapter's practical nuisance.",
			"Sorrel": "Sorrel. Still mistaking hunger for understanding, I see. Curiosity is not a virtue when it lacks containment.",
			"Darian": "You dress like a court lyricist and carry yourself like a man trying to apologize for his bloodline at decorative volume.",
			"Celia": "Discipline repurposed into conscience. That always makes institutions nervous. Sensible institutions, at least.",
			"Rufus": "A practical man in a house of records. You will hate every minute of this and be right to do so.",
			"Inez": "You look offended by shelves. Wonderful. We are already starting from honest premises.",
			"Tariq": "There you are. Smiling like a man who thinks contempt counts as independence. Tiresome, but not unskilled.",
			"Mira Ashdown": "Quiet feet in a place built on secrets. Children survive too much by learning to read locked rooms from the outside.",
			"Pell Rowan": "A young knight in a library of restricted truths. This is usually where heroic ideals discover paperwork.",
			"Tamsin Reed": "You should not be near half the substances in this building, let alone the books.",
			"Hest “Sparks”": "You are exactly the sort of person who touches the wrong cabinet and then calls the explosion educational.",
			"Brother Alden": "You bring calm into a place designed to make inquiry feel criminal. Impressive. Also unhelpful.",
			"Oren Pike": "You are already judging the lifts, the locks, and the wasted motion. Good. Someone here still respects systems for the right reasons.",
			"Garrick Vale": "An officer trying to look honorable while trespassing through protected knowledge. Bureaucracy does so love irony.",
			"Sabine Varr": "Controlled posture, measured eyes, and no patience for sloppy procedure. We might have agreed on everything except people.",
			"Yselle Maris": "Performance entering an archive. Delightful. Beauty is often just access wearing perfume.",
			"Sister Meris": "Rigid spine, exact diction, carefully managed shame. Ah. Another product of institutional overconfidence.",
			"Corvin Ash": "You are too comfortable around forbidden texts. That makes you either very useful or very stupid. Possibly both.",
			"Veska Moor": "A shield in a library. How reassuringly literal. If only truth respected fortifications.",
			"Ser Hadrien": "A dead knight among the ledgers of the living. History does enjoy arriving in person when one is busiest.",
			"Maela Thorn": "You move as if all locks were insults. Youth does so hate well-placed boundaries."
		},
		"death": {
			"Sorrel": "So. The curious child finally broke the lock. Very well -- keep the keys. They were never the same thing as wisdom."
		},
		"retreat": {
			"Sorrel": "You may keep your keys, Provost. I was never after your permission."
		}
	},

	"Thorn-Captain Edda Fen": {
		"pre_attack": {
			"Avatar": "Another outsider claiming to pass through in peace. Funny how often peace arrives armed and needing timber.",
			"Kaelen": "You have the look of a man who has buried too many camps and still thinks caution counts as innocence.",
			"Branik": "Big, steady, decent. Frontier life devours your kind first -- either by using you or by making you watch.",
			"Liora": "A priestess in contested woods. Tell me, does your god bless roads after the shrines are uprooted, or only before?",
			"Nyx": "Quick eyes, city habits, no respect for posted boundaries. You'd hate frontier rule. It hates you right back.",
			"Sorrel": "A scholar staring at tree-lines like they are texts to be decoded. Careful. Forests answer poorly to annotation.",
			"Darian": "Noble polish in muddy country. You people always arrive amazed that necessity has such ugly boots.",
			"Celia": "Military bearing, controlled voice, conscience under pressure. You know exactly how easy 'protection' becomes occupation.",
			"Rufus": "You look like a man who understands the cost of roads but also who carries them. That makes you harder to dislike than most.",
			"Inez": "There you are. Still treating every scar in the earth as if memory alone can keep wolves and winter from crossing it.",
			"Tariq": "Sharp eyes, expensive contempt. You would prefer theory to territory, I think. Territory remains harder to feed with theory.",
			"Mira Ashdown": "You move quietly enough to belong here. That does not mean the place has forgiven what followed your kind.",
			"Pell Rowan": "Young knight, bright spine, tragic timing. Frontier graves are full of boys who thought duty and permission were the same thing.",
			"Tamsin Reed": "You are far too gentle for a road war. Which means this road war will probably be measured on your back anyway.",
			"Hest “Sparks”": "A little wildfire with pockets. Gods, no. Forest fronts produce enough accidents without your help.",
			"Brother Alden": "A good man in contested land. Those tend to become memorials faster than commanders.",
			"Oren Pike": "At last, someone else who understands roads do not build themselves. Shame we disagree on what should be cut to lay them.",
			"Garrick Vale": "An officer who still wants duty to mean stewardship. Then perhaps you understand why half this work disgusts me and the other half still gets done.",
			"Sabine Varr": "Professional. Controlled. You know security, perimeter, labor, attrition. Good. Then I won't need to romanticize this for you.",
			"Yselle Maris": "You are too polished for a logging front and too observant to be decorative. That makes you dangerous in a civilized way.",
			"Sister Meris": "You have the stare of someone who once believed certainty could keep blood off the floor.",
			"Corvin Ash": "A man who is comfortable around cursed ground is never reassuring, however useful he may be.",
			"Veska Moor": "Solid boots, solid shield, solid opinions. The frontier produces respect for weight, at least.",
			"Ser Hadrien": "A dead knight in old border country. Fitting. Roads and ghosts are both proof someone insisted on staying.",
			"Maela Thorn": "Fast, bright, airborne. Scouts like you always think seeing more of the map makes them wiser than the people stuck cutting through it."
		},
		"death": {
			"Inez": "Then keep your grove. But remember this -- forests do not stay sacred by sentiment alone."
		},
		"retreat": {
			"Inez": "Leave. The trees have no more patience for you."
		}
	},
	"Preceptor Cassian Vow": {
		"pre_attack": {
			"Avatar": "So this is the famous inconvenience in mortal form. Tell me, little commander -- do you always arrive where peace was nearly becoming useful?",
			"Kaelen": "A veteran at a negotiation table. Sensible. Real peace is usually killed by the men most qualified to recognize it.",
			"Branik": "You look like a man who still believes decency can stabilize a room. It can, briefly. Then policy enters.",
			"Liora": "A sincere priestess is always the most painful obstacle. Hypocrites are easier; they already know their price.",
			"Nyx": "Quick eyes, quick exits, no reverence for process. You must find diplomacy unbearably slow. I find that refreshing in very small doses.",
			"Sorrel": "A scholar at a peace table -- ah, yes. Another person who thinks truth survives once politicians start speaking softly.",
			"Darian": "Charm, pedigree, elegant regret. You are exactly the sort of man institutions love: decorative enough to soften the crime, articulate enough to justify it.",
			"Celia": "Perfect posture and visible conscience. Such difficult symmetry. You understand how obedience survives by borrowing the shape of virtue.",
			"Rufus": "Practical hands in a room full of agreements. Good. At least one person here knows that treaties still have to be unloaded somewhere.",
			"Inez": "You carry the land in your face like a permanent objection. How inconvenient for those of us who prefer roads to roots.",
			"Tariq": "A clever man wearing disdain like weatherproofing. You know exactly how peace is sold before it is betrayed.",
			"Mira Ashdown": "Quiet children unsettle diplomats. They stare as if they can already see who will be left outside the bargain.",
			"Pell Rowan": "A young knight at parleys is almost cruelly optimistic. You still think honor can survive first contact with necessity.",
			"Tamsin Reed": "You have the look of someone who still counts suffering one body at a time. That must make politics feel unbearably crowded.",
			"Hest “Sparks”": "A live wire at a negotiation camp. Gods preserve the written record from your sense of opportunity.",
			"Brother Alden": "A calm holy man is a dangerous witness. People always remember what peace sounded like before men like me improved it.",
			"Oren Pike": "You look offended by ceremony at a structural level. Fair. Most of it exists to decorate the collapse.",
			"Garrick Vale": "An officer still trying to keep duty from curdling into theater. Noble. Also embarrassingly vulnerable to exploitation.",
			"Sabine Varr": "Measured posture, measured gaze, no wasted motion. Ah. A professional. You know order is most useful right before it is weaponized.",
			"Yselle Maris": "Grace in a negotiation tent. Lovely. You already know half of diplomacy is staging and the other half is deciding who bleeds offstage.",
			"Sister Meris": "There you are -- certainty with scars. You know exactly how power speaks when it wants blood to sound procedural.",
			"Corvin Ash": "A man comfortable with forbidden things should appreciate this, at least: I do not confuse moral cleanliness with political success.",
			"Veska Moor": "Solid, honest, difficult. Fortifications are always troublesome when they start asking whether the gate should open at all.",
			"Ser Hadrien": "A dead knight at a living parley. History does so love arriving just when compromise needs haunting.",
			"Maela Thorn": "Fast wings, quick grin, no patience. You are the sort of courier who mistakes motion for wisdom -- and still somehow survives often enough to be annoying."
		},
		"death": {},
		"retreat": {}
	},

	"Lord Septen Harrow": {
		"pre_attack": {
			"Avatar": "The little symbol arrives at my granaries armed. Charming. Tell me, do miracles also thresh wheat, or only interrupt grown men at work?",
			"Kaelen": "A veteran come to lecture me on suffering. Spare me. Men like you always discover moral outrage after someone else has done the arithmetic.",
			"Branik": "You look like winter's best friend: broad shoulders, warm hands, and the kind of face hungry people trust too quickly.",
			"Liora": "A priestess in a famine-house. You must hate this place. Good. Hunger should offend the devout before it ever offends the wealthy.",
			"Nyx": "Ah, a city rat among the grain vaults. Careful -- scarcity makes everyone less romantic about theft, especially the people already profiting from it.",
			"Sorrel": "A scholar at a granary. Let me guess: you want causes. The starving usually prefer bread.",
			"Darian": "There you are. A gentleman carrying shame in excellent posture. I know that breed. It dines beautifully while learning not to ask where the grain went.",
			"Celia": "Military poise, soft conscience. Difficult combination in a season like this. Famine has no respect for clean ethics.",
			"Rufus": "You have labor in your hands and suspicion in your eyes. Sensible. Grain always attracts men who think ownership is evidence of merit.",
			"Inez": "You look at my stores like the land itself filed a grievance. Provincial, but compelling in its way.",
			"Tariq": "A sharp man with a bad opinion of landlords. How modern. And yet, somehow, the crops still require organization.",
			"Mira Ashdown": "Children from burned villages always stare too hard at full storehouses. It makes the room feel judged.",
			"Pell Rowan": "A young knight in famine country. You are about to discover how quickly ideals lose weight once people start measuring rations.",
			"Tamsin Reed": "You should not be here, healer. Granaries teach uglier lessons than battlefields because the knives are usually ledgers.",
			"Hest “Sparks”": "Chaotic little gremlin. Please tell me you are not planning to liberate food by setting accounting records on fire. Again.",
			"Brother Alden": "A monk at harvest law's funeral. Appropriate. Someone ought to pray over what nobility did to stewardship.",
			"Oren Pike": "You have the face of a man already judging my wagon design, my labor ratios, and my ethics in that order.",
			"Garrick Vale": "An officer still trying to believe the realm and the people inside it are the same thing. Tragic distinction to learn this late.",
			"Sabine Varr": "Professional, exact, visibly unimpressed. Good. Sentimentality is a terrible lens for logistics.",
			"Yselle Maris": "Elegance at a grain crisis. You do understand civilization astonishingly well -- people only call beauty frivolous until ration lines start singing.",
			"Sister Meris": "You look like someone who once mistook severity for justice. Famine corrects philosophy with marvelous efficiency.",
			"Corvin Ash": "A man unafraid of ugly truths. Excellent. Then let us at least be honest that hunger is governance by other means.",
			"Veska Moor": "A wall come walking. Reliable, humorless, and exactly the kind of person who makes theft feel like a moral issue instead of a market correction.",
			"Ser Hadrien": "A dead knight in a hungry province. How exquisitely Edranori. Even our ghosts arrive with inherited obligation.",
			"Maela Thorn": "Fast, bright, impatient. Flyers always think granaries are simple until they have to count how many mouths each sack becomes."
		},
		"death": {},
		"retreat": {}
	},

	"The Ash Adjudicator": {
		"pre_attack": {
			"Avatar": "Bearer of the sealed mark: approach and be measured. Symbol is not absolution.",
			"Kaelen": "Former knight. Survivor. Withheld truth entered the record long before this chamber did.",
			"Branik": "Protector-form detected. Mercy-weight high. Structural inadequacy against oath-failure remains probable.",
			"Liora": "Faith persists in you without full submission to doctrine. Classification unstable. Proceed.",
			"Nyx": "Deflection, theft, adaptive survival. No institution ever designed well for lives like yours. This is entered without correction.",
			"Sorrel": "Inquiry without containment. Pattern familiar. The archive of catastrophe is full of your species of virtue.",
			"Darian": "Noble posture, divided conscience, cultivated speech. Ceremony remains intact; certainty does not.",
			"Celia": "Discipline retained. Obedience fractured by conscience. This is closer to oath than your superiors understood.",
			"Rufus": "Labor-marked hands. Practical mind. Judgment notes the empire was not held together by men who wore gold.",
			"Inez": "Stewardship orientation detected. Territorial memory exceeds legal memory. Noted.",
			"Tariq": "Intellect armored in contempt. Common among those who discover truth after institutions do.",
			"Mira Ashdown": "Child-survivor profile. Silence functioning as fortification. Entry received.",
			"Pell Rowan": "Aspirant knight. Heroic idealism not yet corrected by sufficient burial. Continue under warning.",
			"Tamsin Reed": "Healer under duress. Fear acknowledged. Continuance despite fear is entered as evidence.",
			"Hest “Sparks”": "Instability, appetite, improvisation. Disorder alone is not guilt. This chamber remembers that poorly.",
			"Brother Alden": "Conviction joined to service rather than spectacle. Rare. The old Order misplaced such mathematics.",
			"Oren Pike": "Systems mind. Low tolerance for waste. Judgment observes that collapse often begins where competence is ignored.",
			"Garrick Vale": "Officer seeking to preserve honor beyond hierarchy. A recurring doomed configuration.",
			"Sabine Varr": "Discipline without vanity. Severity without ornament. This chamber finds no contradiction in you.",
			"Yselle Maris": "Performance recognized. Survival through curation entered. The court has always depended upon masks while condemning them.",
			"Sister Meris": "Former certainty now carrying remorse. The old record contains many like you. Few turned back.",
			"Corvin Ash": "Forbidden study without sufficient fear. This was once called necessary. It was later called treason. Both entries remain.",
			"Veska Moor": "Bulwark-form accepted. Reliability exceeds rhetoric. Such people were spent too quickly.",
			"Ser Hadrien": "Recognized. Oath-survivor. Witness-form. The chamber registers kinship and indictment simultaneously.",
			"Maela Thorn": "Speed, defiance, imprecision. Youth often mistakes refusal for freedom until consequence catches up."
		},
		"death": {
			"Ser Hadrien": "Then let the record amend itself, Hadrien. Judgment without soul was always ash before it was law."
		},
		"retreat": {
			"Ser Hadrien": "Echoes break more slowly than men. I will return when the judgment does."
		}
	},
	"Duke Alric Thornmere": {
		"pre_attack": {
			"Avatar": "So the little provincial miracle has grown into a commander. How industrious. Try not to mistake visibility for legitimacy.",
			"Kaelen": "An old soldier with opinions about nobility. Those are very fashionable in collapsing kingdoms.",
			"Branik": "You look like the sort of man common folk trust before they remember who signs the levy.",
			"Liora": "A priestess with a conscience and a sword. Civilization does enjoy producing contradictions when it grows frightened.",
			"Nyx": "Sharp eyes, poor manners, no respect for station. How invigoratingly urban.",
			"Sorrel": "A scholar in armor is still a scholar, I suppose. One hopes your ideals footnote themselves properly.",
			"Darian": "Ah. Refinement with guilt attached. You wear it well, which is the first sign it will survive you.",
			"Celia": "Discipline, restraint, visible burden. You would have made a splendid servant of order if conscience were not such an unruly tutor.",
			"Rufus": "A practical man with no patience for ceremony. You must find the upper classes exhausting. We return the feeling.",
			"Inez": "You stare at banners the way foresters stare at axes. Not unreasonably.",
			"Tariq": "A clever man wearing contempt like perfume. How efficient. It saves everyone time.",
			"Mira Ashdown": "Children who watch too quietly are always troublesome. They notice the parts governance prefers remain inherited rumor.",
			"Pell Rowan": "Young knight, bright posture, excellent intentions. One would almost feel cruel educating you.",
			"Tamsin Reed": "You should not be anywhere near men like me, healer. We turn need into policy and call it stewardship.",
			"Hest “Sparks”": "What a dreadful little storm. I assume the pockets are stolen and the grin is a defense mechanism.",
			"Brother Alden": "A monk who still believes decency scales upward into governance. Admirable. Incorrect, but admirable.",
			"Oren Pike": "You look offended already. Good. Engineers are never pleased until everything useful has become accusatory.",
			"Garrick Vale": "Garrick. Still wearing the realm like a promise instead of a costume, I see.",
			"Sabine Varr": "Controlled, competent, and visibly unimpressed. You would have gone far in proper service if you had learned to flatter mediocrity more gracefully.",
			"Yselle Maris": "Elegant, poised, socially armed. Ah -- someone else who understands that half of power is timing and the other half is audience.",
			"Sister Meris": "Severity in human form. You almost make moral restraint look unfashionable.",
			"Corvin Ash": "A man comfortable with dangerous knowledge is either useful or doomed. With luck, both.",
			"Veska Moor": "Reliable, solid, difficult to charm. Every noble house eventually learns to fear exactly your kind of honesty.",
			"Ser Hadrien": "A dead knight in service to the living. Edranor never could resist turning memory into cavalry.",
			"Maela Thorn": "Fast mouth, faster wings, no patience for etiquette. You must make an awful first impression. How refreshing."
		},
		"death": {
			"Garrick Vale": "Garrick... if men like you inherit the realm, perhaps it may yet survive the class that taught us both to kneel differently."
		},
		"retreat": {
			"Garrick Vale": "You always did mistake duty for purification, Garrick. Keep your grief. I will keep the realm."
		}
	},

	"Captain Selene": {
		"pre_attack": {
			"Avatar": "So the marked commander finally closes the distance. Good. I prefer problems that stand still long enough to solve.",
			"Kaelen": "You move like an old instructor and look like a tired warning. I respect both. They will not help you.",
			"Branik": "Large, grounded, protective. You are exactly the sort of obstacle people underestimate until the floor is already red around you.",
			"Liora": "A healer carrying conviction into blade range. Brave. Inadvisable. Predictable.",
			"Nyx": "Quick hands, city instincts, no respect for lines. You survive by improvising. I survive by making sure improvisation fails.",
			"Sorrel": "A scholar in the field. Fine. Just don't die trying to understand what a straight answer from a blade feels like.",
			"Darian": "Style, wit, posture. You fight like a man aware he is being observed. That is usually a weakness.",
			"Celia": "Discipline with conscience underneath it. Dangerous. The cleanest soldiers are always the ones hardest to direct.",
			"Rufus": "Practical, grounded, and already measuring angle, load, and recoil. Good. At least one of us is not here to posture.",
			"Inez": "You read terrain with your shoulders before your eyes. I can work with enemies like that.",
			"Tariq": "Sharp mind, sharper contempt. You probably think you're the only adult in most rooms. You aren't.",
			"Mira Ashdown": "Quiet archers are the most annoying kind. They kill from moral distance and call it restraint.",
			"Pell Rowan": "Too eager. Too upright. You still think courage protects people from precision.",
			"Tamsin Reed": "You look frightened and useful. War loves that combination more than it should.",
			"Hest “Sparks”": "Unfocused energy, fast grin, bad habits. I have killed better chaos than you before breakfast.",
			"Brother Alden": "A calm man with war in his hands. You are more dangerous than the loud ones. Shame about the mercy.",
			"Oren Pike": "You look like a man who would disassemble my kit while complaining about the tolerances. I would almost enjoy that under other circumstances.",
			"Garrick Vale": "Officer, posture, disciplined conscience. Men like you always hesitate one sentence too long when the order turns filthy.",
			"Sabine Varr": "There you are. A professional. Finally. No mysticism, no theatrics -- just competence with a pulse.",
			"Yselle Maris": "Performance, grace, crowd control. Very efficient. We simply use different stages.",
			"Sister Meris": "Institutional spine, measured voice, old severity. You understand obedience in the body, which makes betrayal heavier.",
			"Corvin Ash": "You stand too calmly around dangerous things. That usually means either talent or rot. Sometimes both.",
			"Veska Moor": "A shield that actually knows what it weighs. Irritating. Good.",
			"Ser Hadrien": "A knight who stayed after his century gave up. I almost envy that kind of clean purpose.",
			"Maela Thorn": "Fast, reckless, bright. You fly like consequences are for slower people."
		},
		"death": {},
		"retreat": {}
	},

	"Master Enric": {
		"pre_attack": {
			"Avatar": "Fascinating. The sealed variable arrives in person, armed and morally distressed. I should have guessed the experiment would eventually object.",
			"Kaelen": "An old veteran carrying too many ghosts and not enough curiosity about how they work. Typical.",
			"Branik": "A protective giant. Warm hands, practical heart, durable frame. People like you are always statistically useful and philosophically tedious.",
			"Liora": "A devout healer in a marsh of procedural horror. Excellent. Disgust tends to clarify which beliefs were ornamental.",
			"Nyx": "Fast, suspicious, difficult to pin down. Urban survivors always become so offended when treated as adaptable material.",
			"Sorrel": "Ah, at last -- curiosity with legs. Do try not to mistake your revulsion for rigor.",
			"Darian": "Elegant posture in a swamp. You truly are committed to aesthetic resistance, which I almost admire.",
			"Celia": "Military discipline over moral injury. Very stable surface. I wonder how much force it would take to split the seam.",
			"Rufus": "You look like a man who hates abstractions and yet has walked into one armed. Brave, if unhelpfully literal.",
			"Inez": "You carry the land in your stance. Marshes make poor patriots. They preserve what they are given and rot the rest without prejudice.",
			"Tariq": "Sharp, cynical, observant. You would have made a marvelous collaborator if principle did not keep interrupting your efficiency.",
			"Mira Ashdown": "Children who have seen too much often stare at death with admirable discipline. It does not make them ready.",
			"Pell Rowan": "A young knight in a bog full of failed boundaries. Education does arrive in ugly landscapes, I'm afraid.",
			"Tamsin Reed": "A healer with panic in the hands and resolve underneath it. Precious. Fragile. Informative.",
			"Hest “Sparks”": "Chaotic, combustible, badly supervised. If you survive this chapter, do try to disappoint your statistical profile.",
			"Brother Alden": "A steady man in a field built to unhouse steadiness. You must understand why I find that professionally interesting.",
			"Oren Pike": "You are already annoyed with the terrain, the humidity, and probably my methodology. Good. At least one of us has standards.",
			"Garrick Vale": "An officer still trying to make honor coexist with outcomes. The body count has always been unimpressed by that ambition.",
			"Sabine Varr": "Controlled breath, efficient posture, no visible nonsense. I do prefer professionals. They die with such clean data.",
			"Yselle Maris": "Grace in a swamp. Beautiful. Humans really will accessorize the edge of horror before admitting they are afraid.",
			"Sister Meris": "You look like remorse taught to stand upright. That can be useful, though rarely for long.",
			"Corvin Ash": "Ah. Someone who does not confuse forbidden with uninteresting. We may finally have a conversation worth having.",
			"Veska Moor": "Solid, reliable, physically impressive. The very sort of person everyone expects to hold the line while subtler people ruin the world behind her.",
			"Ser Hadrien": "A dead knight confronting a necromancer-scholar. You must understand the temptation not to treat that as providential.",
			"Maela Thorn": "Fast, bright, impatient. Flyers always imagine altitude protects them from contamination. Charming delusion."
		},
		"death": {},
		"retreat": {}
	},
	"Roen Halbrecht": {
		"pre_attack": {
			"Avatar": "So they sent the miracle to fix what the walls couldn't. Fine. Come look at what survival costs when no one arrives in time.",
			"Kaelen": "Kaelen. Of course it's you. You always did arrive just late enough to judge the smoke instead of the fire that made it.",
			"Branik": "You look like a man people hide behind when things break. Lucky them. Some of us were the wall when it failed.",
			"Liora": "A priestess in a ruined safehold. I should apologize for the setting, but by now the truth deserves uglier rooms.",
			"Nyx": "Quick eyes. Fast hands. The sort who'd spot a weak hinge before a weak oath. Smart.",
			"Sorrel": "A scholar here? Gods. Even the collapse gets archivists now.",
			"Darian": "You dress too well for a betrayal chapter. Though I suppose someone has to keep the tragedy presentable.",
			"Celia": "Military bearing, careful conscience. Then you know how quickly 'hold the line' turns into 'decide who gets left behind.'",
			"Rufus": "You look like a man who trusts gates, bolts, and practical things. Good. Then you know exactly how obscene it is when one of them chooses treachery.",
			"Inez": "You move like someone who hates walls because they forget they're only borrowed from the land.",
			"Tariq": "You have the face of a man already forming the elegant version of why this happened. Save it. I wrote enough of those myself.",
			"Mira Ashdown": "Children should not understand this place as quickly as you do. Which probably means you understand it perfectly.",
			"Pell Rowan": "Young knight, polished nerve, heroic spine. This is the chapter where that shape usually begins to bend.",
			"Tamsin Reed": "You look like you still think people can be put back together properly. I envy that sort of ignorance.",
			"Hest “Sparks”": "A grin like a bad idea in motion. Dawnkeep has enough of those without your help.",
			"Brother Alden": "A steady man in a broken keep. Be careful. Places like this make good men sound reasonable while they rot.",
			"Oren Pike": "You are already judging the hinges, the murder-slots, and the compromised entries. Good. Someone should.",
			"Garrick Vale": "An officer who still wants duty to mean protection. Then you are going to hate me with the right kind of precision.",
			"Sabine Varr": "Professional posture. Measured eyes. You know exactly how many fortresses are lost before the enemy even reaches the gate.",
			"Yselle Maris": "You are too polished for a place that smells this much like panic. Impressive. Disturbing, but impressive.",
			"Sister Meris": "You have the look of someone who knows certainty becomes cruelty the moment fear signs the order.",
			"Corvin Ash": "You don't frighten easily around wreckage. Sensible. Ruin is usually just administration with fewer witnesses.",
			"Veska Moor": "A wall with feet. I used to think that was enough. That was before walls learned how lonely they are.",
			"Ser Hadrien": "A dead knight in a dead hold. Fitting. Dawnkeep has been full of ghosts since before anyone here finished dying.",
			"Maela Thorn": "Fast, loud, airborne. Good. You'll get an excellent view of the moment trust stops being structural."
		},
		"death": {
			"Kaelen": "Then be better than I was, Kaelen. Don't let another keep teach you how easy men become to spend."
		},
		"retreat": {
			"Kaelen": "You can still call this betrayal if it helps you sleep. I called it surviving."
		}
	},

	"Naeva, Marrow-Seer of the Dark Tide": {
		"pre_attack": {
			"Avatar": "Ah. The marked vessel hums more loudly than the altars predicted. You still call it selfhood. How sweet.",
			"Kaelen": "Old iron, old guilt, old caution. You stand like a man trying to hold shut a sea with one tired hand.",
			"Branik": "How warm you are. How stubbornly terrestrial. The tide does adore patient stones before it drowns them.",
			"Liora": "Little light-bearer, your prayers sound so small from here. Not false. Merely... inland.",
			"Nyx": "Quick creature. Street-bred. Knife-bright. You move like someone who knows hunger, but not yet the appetite beneath the world.",
			"Sorrel": "Scholar. Listener. Yes... yes, you almost hear it. That is the dangerous kind of almost.",
			"Darian": "You carry beauty like a defense and irony like a veil. Both are very mortal fabrics.",
			"Celia": "Discipline held together by chosen conscience. Admirable. The tide respects forms that do not yet know they are dissolving.",
			"Rufus": "You smell of rope, salt, powder, and practical dislike. Good. The sea prefers honest contempt to pious curiosity.",
			"Inez": "You listen to roots. I listen to depths. We are both answered by things the map cannot civilize.",
			"Tariq": "Sharp mind. Controlled disdain. You already know that naming horror does not diminish it. That helps very little.",
			"Mira Ashdown": "Such quiet. Ash in the bones and watchfulness in the hands. You learned young how to stand near endings.",
			"Pell Rowan": "Bright little oath. You still believe forms can keep meaning inside them once the dark tide rises.",
			"Tamsin Reed": "Poor careful healer. You carry order in bottles and wrappings while the world loosens at the seam.",
			"Hest “Sparks”": "You crackle so brightly. Mortal panic often mistakes itself for freedom at that volume.",
			"Brother Alden": "Steady pulse. Rooted faith. It is almost kind how firmly you still believe suffering should kneel before mercy.",
			"Oren Pike": "You are already trying to solve the altar with angles and tolerances. Precious man. This architecture was never for load-bearing reason.",
			"Garrick Vale": "A proper officer before an improper sea. You must find revelation terribly badly managed.",
			"Sabine Varr": "Controlled breath. Controlled fear. Splendid. Most people leak much sooner in rooms like this.",
			"Yselle Maris": "Grace arranged against oblivion. Beautiful. All performances become liturgy eventually if repeated near enough to the abyss.",
			"Sister Meris": "You were shaped by doctrine; I was hollowed by revelation. We are both what devotion does when it keeps going.",
			"Corvin Ash": "There you are. A man who does not flee from the edge, only from the embarrassment of calling it sacred too early.",
			"Veska Moor": "A shield planted in wet dark. How solemn. How wonderfully doomed by mass and principle.",
			"Ser Hadrien": "A dead knight hears the song with fewer organs in the way. That must feel almost like homecoming.",
			"Maela Thorn": "Bright falcon, quick heart. Altitude has misled many into thinking the deep cannot rise to meet them."
		},
		"death": {},
		"retreat": {}
	},

	"The Witness Without Eyes": {
		"pre_attack": {
			"Avatar": "Marked convergence recognized. Seal-function. Vessel-function. Fracture-function. Observation continues.",
			"Kaelen": "Aged defender-form. Guilt-density high. Persistence without remedy recorded.",
			"Branik": "Shelter-instinct detected. Protective mass. Warmth-preservation behavior noted and judged insufficient.",
			"Liora": "Faith-form persists under contradiction. Prayer-sound received. No intervention follows.",
			"Nyx": "Evasion-pattern. Hunger-pattern. Attachment concealed beneath hostility. Not unusual. Still temporary.",
			"Sorrel": "Inquiry-organism approaching dissolution-field. Curiosity remains one of the more durable mortal errors.",
			"Darian": "Adornment. elegance. self-authorship under collapse. This is recognized and not preserved.",
			"Celia": "Discipline under fracture. Duty rewritten by conscience. A meaningful deviation. Outcome remains mortal.",
			"Rufus": "Labor-marked body. Practical cognition. Refusal to romanticize. Observation approves nothing and notes the pattern.",
			"Inez": "Territorial stewardship. Root-memory. Boundary-instinct. The world was never bounded securely enough for this to save it.",
			"Tariq": "Contempt-armored intellect. Pattern common in those who discover scale too late.",
			"Mira Ashdown": "Young survivor-form. Silence functioning as architecture. Architecture fails.",
			"Pell Rowan": "Idealism not yet eroded by sufficient burial. Sequence predictable.",
			"Tamsin Reed": "Fear acknowledged. Care-instinct acknowledged. Both remain fragile technologies.",
			"Hest “Sparks”": "Noise as defense. motion as identity. instability as shelter. Observation complete.",
			"Brother Alden": "Service-belief. Mercy-structure. Endurance orientation. These are beautiful and not enough.",
			"Oren Pike": "Systems-thinking under impossible conditions. The impulse to repair persists past reason. Noted.",
			"Garrick Vale": "Honor-seeking officer-form. Hierarchy damaged. Loyalty unresolved. Very mortal.",
			"Sabine Varr": "Control-behavior. Precision-behavior. Compression of affect for function. Efficient, not exempt.",
			"Yselle Maris": "Curated selfhood. Beauty under pressure. Mask and truth incorrectly treated as opposites by your species.",
			"Sister Meris": "Certainty broken into remorse. Remorse broken into action. Action remains late.",
			"Corvin Ash": "Forbidden-study pattern. Proximity to unmaking without adequate worship or fear. Rare and also temporary.",
			"Veska Moor": "Bulwark-form. Reliability exceeds rhetoric. Rhetoric and reliability dissolve together.",
			"Ser Hadrien": "Residual oath-entity. Historic persistence. Grief still incompletely processed by design.",
			"Maela Thorn": "Speed-form. Defiance-form. Upward motion with no escape vector."
		},
		"death": {},
		"retreat": {}
	},
	"Juno Kest, Keeper of Bells": {
		"pre_attack": {
			"Avatar": "You arrive between bells. That is usually the moment people mistake silence for freedom.",
			"Kaelen": "Old soldier. You listen for signals before you move. Good instinct. Bells exist for men like you.",
			"Branik": "You look like the sort who waits for the alarm before deciding who needs shelter. That patience saves lives. Sometimes.",
			"Liora": "A priestess who believes prayer answers catastrophe. Bells are less hopeful. They simply announce it.",
			"Nyx": "Ah. The city rat who slips between curfew and warning. I wondered how long it would take you to climb the tower.",
			"Sorrel": "A scholar who studies systems. Bells are the simplest one. Strike metal, move a city.",
			"Darian": "Graceful, observant, socially fluent. You already understand half of governance is deciding who hears the bell first.",
			"Celia": "Military discipline in civic space. Yes. You know exactly how fast order collapses when signals fail.",
			"Rufus": "You trust weight, steel, and practical warning. A man after my own profession, in a way.",
			"Inez": "You look offended by walls and towers. Reasonable. Bells exist to remind the land it has been organized.",
			"Tariq": "A clever man who distrusts authority. Good. You already know bells are rarely rung for the people who deserve them.",
			"Mira Ashdown": "Children always listen hardest when bells ring. They know alarms mean adults have failed again.",
			"Pell Rowan": "Young knight, bright posture. Bells will teach you how quickly heroism becomes evacuation.",
			"Tamsin Reed": "You hear alarm and think triage. I hear alarm and think inevitability.",
			"Hest “Sparks”": "A walking accident with pockets. Please tell me you are not planning to 'improve' the tower.",
			"Brother Alden": "A monk who understands ritual. Then you understand the bell is prayer stripped of hope.",
			"Oren Pike": "You are already measuring the tower's structural load. Good. Someone should respect the architecture.",
			"Garrick Vale": "Officer. You know exactly what bells mean during siege. Panic for some, clarity for others.",
			"Sabine Varr": "Professional eyes. You recognize signal discipline when you see it.",
			"Yselle Maris": "Elegance and awareness. Yes... you understand performance. Bells are simply theater that commands obedience.",
			"Sister Meris": "Institutional spine. Doctrine likes bells. They make certainty audible.",
			"Corvin Ash": "You listen like a man who suspects bells sometimes ring for reasons no one will admit.",
			"Veska Moor": "A shield who waits for warning before moving. Reliable. Cities survive on people like you.",
			"Ser Hadrien": "A knight from another century. Bells outlive centuries. They will outlive you again.",
			"Maela Thorn": "Fast wings, quick grin. Flyers always believe they can outrun alarm."
		},
		"death": {
			"Nyx": "So the rat reached the bell tower after all. Go on, then. Ring it yourself. Let's see who answers."
		},
		"retreat": {
			"Nyx": "Curfew breaks easier than habit, Nyx. Remember that when the next bell rings."
		}
	},
}
}

## Returns personal dialogue line for boss_id + unit_id + event_type ("pre_attack"|"death"|"retreat"), or empty string.
## Purpose: Single lookup entry for BattleField; no side effects.
static func get_line(boss_id: String, unit_id: String, event_type: String) -> String:
	if boss_id.is_empty() or unit_id.is_empty() or event_type.is_empty():
		return ""
	var boss_entry = BOSS_PERSONAL_DIALOGUE.get(boss_id, null)
	if boss_entry == null or not (boss_entry is Dictionary):
		return ""
	var sub = boss_entry.get(event_type, null)
	if sub == null or not (sub is Dictionary):
		return ""
	var line = sub.get(unit_id, "")
	return str(line).strip_edges() if line != null else ""
