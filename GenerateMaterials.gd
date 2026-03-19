# ==============================================================================
# Script Name: GenerateMaterials.gd
# Purpose: Editor tool to bulk-generate MaterialData .tres files from an array
#          and assign a shared category icon to each generated resource.
# Overall Goal: Save time manually creating resource files while keeping each
#               material visually categorized in the inventory/crafting UI.
# Project Fit: Supports the content pipeline by converting plain dictionary data
#              into fully populated MaterialData resources used by the game.
# Dependencies:
#   - Requires MaterialData.gd to exist in the project.
#   - Requires these icon files to exist:
#       res://Resources/Materials/GeneratedMaterials/Icons/cooking.png
#       res://Resources/Materials/GeneratedMaterials/Icons/crafting.png
#       res://Resources/Materials/GeneratedMaterials/Icons/lore_and_misc.png
# AI/Code Reviewer Guidance:
#   - Entry Point: _run() executes automatically when run from the File -> Run menu.
#   - Configuration Areas:
#       * BASE_SAVE_PATH
#       * CATEGORY_ICONS
#   - Core Logic Sections:
#       * _run()
#       * _normalize_category()
#       * _get_icon_for_category()
#       * _make_safe_file_name()
# ==============================================================================

@tool
extends EditorScript

const BASE_SAVE_PATH: String = "res://Resources/Materials/GeneratedMaterials/"

const VALID_CATEGORIES: Array[String] = [
	"Cooking",
	"Crafting",
	"Lore_And_Misc"
]

const CATEGORY_ICONS: Dictionary = {
	"Cooking": "res://Resources/Materials/GeneratedMaterials/Icons/cooking.png",
	"Crafting": "res://Resources/Materials/GeneratedMaterials/Icons/crafting.png",
	"Lore_And_Misc": "res://Resources/Materials/GeneratedMaterials/Icons/lore_and_misc.png"
}


# Paste the array generated inside these brackets:
var generated_materials: Array[Dictionary] = [
	{
		"item_name": "Rock Salt",
		"description": "Coarse white crystals chipped from dry earth and old brine pits. It keeps meat from turning and stings open cuts with ruthless honesty.",
		"rarity": "Common",
		"gold_cost": 8,
		"category": "Cooking"
	},
	{
		"item_name": "Butter Crock",
		"description": "A sealed clay pot filled with pale, rich butter. It smells of clean fat and smoke-warmed bread.",
		"rarity": "Common",
		"gold_cost": 7,
		"category": "Cooking"
	},
	{
		"item_name": "Iron Nails",
		"description": "A fistful of blackened nails, rough at the head and sharp at the tip. Essential for patching doors, wagons, and coffins alike.",
		"rarity": "Common",
		"gold_cost": 10,
		"category": "Crafting"
	},
	{
		"item_name": "Linen Roll",
		"description": "A tightly wound strip of woven cloth, soft but durable. It serves as bandage, wick, or humble trade good in lean times.",
		"rarity": "Common",
		"gold_cost": 11,
		"category": "Crafting"
	},
	{
		"item_name": "Wheat Sheaf",
		"description": "A bound cluster of dried grain stalks, dusty with chaff. Ground fine, it becomes bread enough to quiet a camp for a night.",
		"rarity": "Common",
		"gold_cost": 6,
		"category": "Cooking"
	},
	{
		"item_name": "Tallow Lump",
		"description": "A greasy block of rendered animal fat wrapped in stained paper. It burns with a sour odor, but it burns all the same.",
		"rarity": "Common",
		"gold_cost": 5,
		"category": "Crafting"
	},
	{
		"item_name": "Barley Sack",
		"description": "A rough sack of pale grain that rattles softly when shifted. It feeds livestock, brews cheap ale, and stretches a poor stew.",
		"rarity": "Common",
		"gold_cost": 9,
		"category": "Cooking"
	},
	{
		"item_name": "Dried Beans",
		"description": "Hard little kernels in mottled browns and reds, dry as teeth. Plain food, but dependable when roads go bad.",
		"rarity": "Common",
		"gold_cost": 7,
		"category": "Cooking"
	},
	{
		"item_name": "Lamp Oil",
		"description": "A stoppered bottle of cloudy oil with a bitter, fishy scent. It feeds lanterns and firepots with equal obedience.",
		"rarity": "Common",
		"gold_cost": 12,
		"category": "Crafting"
	},
	{
		"item_name": "Wool Bundle",
		"description": "A bundle of raw wool, still carrying the smell of lanolin and rain-soaked fields. Useful for padding, weaving, or barter.",
		"rarity": "Common",
		"gold_cost": 9,
		"category": "Crafting"
	},
	{
		"item_name": "Torchwood",
		"description": "Split lengths of resin-heavy wood that catch flame quickly. Their smoke is thick, bitter, and comforting in a ruin's dark throat.",
		"rarity": "Common",
		"gold_cost": 6,
		"category": "Crafting"
	},
	{
		"item_name": "Medicinal Herbs",
		"description": "A dried cluster of bitter leaves and pale stems tied with string. Crushed into poultice, they smell green and sharply clean.",
		"rarity": "Common",
		"gold_cost": 13,
		"category": "Crafting"
	},
	{
		"item_name": "Leather Straps",
		"description": "Cured strips of hide cut for repairs and bindings. They smell of smoke, tannin, and old stables.",
		"rarity": "Common",
		"gold_cost": 14,
		"category": "Crafting"
	},
	{
		"item_name": "Soap Brick",
		"description": "A dull grey bar stamped with a faded maker's mark. It carries the faint scent of ash and herbs, a small defense against filth.",
		"rarity": "Common",
		"gold_cost": 5,
		"category": "Crafting"
	},
	{
		"item_name": "Vinegar Flask",
		"description": "A squat bottle of sour, clear liquid that bites at the nose. It preserves food, cleans wounds, and improves little else.",
		"rarity": "Common",
		"gold_cost": 8,
		"category": "Cooking"
	},
	{
		"item_name": "Copper Wire",
		"description": "A coil of reddish wire, soft enough to twist and stubborn enough to hold. Favored by tinkers, trappers, and grave robbers with patience.",
		"rarity": "Uncommon",
		"gold_cost": 22,
		"category": "Crafting"
	},
	{
		"item_name": "Beeswax",
		"description": "Golden cakes of wax, warm-smelling and faintly sweet. Used for candles, seals, and the careful waterproofing of gear.",
		"rarity": "Uncommon",
		"gold_cost": 24,
		"category": "Crafting"
	},
	{
		"item_name": "Oak Resin",
		"description": "Dark, sticky resin scraped from ancient bark and stored in a horn vial. It smells sharp and earthy, perfect for pitch and binding compounds.",
		"rarity": "Uncommon",
		"gold_cost": 27,
		"category": "Crafting"
	},
	{
		"item_name": "Charcoal Sack",
		"description": "A soot-black sack of brittle charcoal chunks that mark anything they touch. It serves smiths, alchemists, and mapmakers in equal measure.",
		"rarity": "Uncommon",
		"gold_cost": 20,
		"category": "Crafting"
	},
	{
		"item_name": "Silver Thread",
		"description": "Spools of fine metallic thread that catch candlelight in cold little flashes. Sewn into vestments, wards, and noble burial cloths.",
		"rarity": "Uncommon",
		"gold_cost": 34,
		"category": "Crafting"
	},
	{
		"item_name": "Quicksilver Vial",
		"description": "A glass vial holding a restless pool of liquid metal. It shivers at the slightest touch like something half alive.",
		"rarity": "Uncommon",
		"gold_cost": 42,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Bog Myrrh",
		"description": "Clots of dark resin gathered from drowned groves and wrapped in moss. Burned slowly, it masks rot with a solemn, temple-like perfume.",
		"rarity": "Uncommon",
		"gold_cost": 30,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Grave-Lichen",
		"description": "Pale grey lichen peeled from old headstones and crypt walls. It feels cold even in warm hands and powders easily for occult brews.",
		"rarity": "Uncommon",
		"gold_cost": 38,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Marrow Fungus",
		"description": "A fleshy cave mushroom streaked with ivory veins. When cut open, it smells damp and faintly meaty.",
		"rarity": "Uncommon",
		"gold_cost": 26,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Bat Guano",
		"description": "A crumbling, foul-smelling heap dried into manageable pellets. Alchemists prize it far more than any sane nose would allow.",
		"rarity": "Uncommon",
		"gold_cost": 21,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Wolf Pelt",
		"description": "A heavy hide with coarse fur and a lingering wild scent. It warms the living and decorates the cruel.",
		"rarity": "Uncommon",
		"gold_cost": 35,
		"category": "Crafting"
	},
	{
		"item_name": "Black Feather",
		"description": "A long feather glossy as spilled ink, often taken from carrion birds near battlefields. Superstitious soldiers keep them for luck and regret it later.",
		"rarity": "Uncommon",
		"gold_cost": 23,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Ghoul Ichor",
		"description": "A tar-thick secretion sealed in waxed glass, green-brown and sluggish. Its smell is sweet at first, then horrifying.",
		"rarity": "Rare",
		"gold_cost": 68,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Gargoyle Talon",
		"description": "A chipped claw of black stone veined with iron-like sheen. It is colder than granite and heavier than it has any right to be.",
		"rarity": "Rare",
		"gold_cost": 95,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Moonsteel Shard",
		"description": "A crescent sliver of pale metal that gleams blue beneath the night sky. Smiths whisper that it takes an edge meant for unholy flesh.",
		"rarity": "Rare",
		"gold_cost": 110,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Ashen Pearl",
		"description": "A dull grey pearl with a smoke-like swirl trapped at its center. It feels smooth, lifeless, and strangely warm.",
		"rarity": "Rare",
		"gold_cost": 84,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Nightbloom Petal",
		"description": "A velvety black petal that releases a narcotic floral scent when bruised. It wilts by dawn unless stored with care.",
		"rarity": "Rare",
		"gold_cost": 72,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Basilisk Eye",
		"description": "A preserved yellow eye floating in brine, slit-pupiled and hateful even in death. The jar clouds around it as if refusing to look directly.",
		"rarity": "Rare",
		"gold_cost": 118,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Wyrm Scale",
		"description": "A palm-sized scale hard as fired tile, dark green with bronze edges. It smells faintly of sulfur and old blood when heated.",
		"rarity": "Rare",
		"gold_cost": 102,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Crypt Key",
		"description": "A long iron key etched with funerary marks and black wax residue. It opens no common lock and fits nowhere innocent.",
		"rarity": "Rare",
		"gold_cost": 76,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Abyssal Amber",
		"description": "A chunk of pitch-dark amber with tiny pale shapes trapped inside. Held to flame, it seems to swallow the light instead of reflecting it.",
		"rarity": "Epic",
		"gold_cost": 185,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Saint's Ash",
		"description": "A silver casket of fine white ash smelling faintly of incense and rain. Priests call it holy; grave thieves call it profitable.",
		"rarity": "Epic",
		"gold_cost": 220,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Heartroot Core",
		"description": "A blood-red knot from the center of an ancient cursed tree. It pulses with slow warmth when pressed to the palm.",
		"rarity": "Epic",
		"gold_cost": 260,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Phoenix Cinder",
		"description": "A coal-red fragment that glows from within and never fully cools. Even sealed in lead, it leaves the scent of a just-doused fire.",
		"rarity": "Legendary",
		"gold_cost": 520,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Starforged Relic",
		"description": "A broken fragment of metal not born from any earthly vein, smooth and dark with points of captive light. It hums softly when night falls and old things wake.",
		"rarity": "Legendary",
		"gold_cost": 690,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Flour Sack",
		"description": "A stout sack of pale flour that clings to fingers and sleeves alike. It smells faintly sweet and forms the backbone of every humble loaf.",
		"rarity": "Common",
		"gold_cost": 7,
		"category": "Cooking"
	},
	{
		"item_name": "Cooking Salt",
		"description": "Fine white salt kept in a waxed pouch against damp. Plain and necessary, it sharpens flavor and lengthens the life of butchered meat.",
		"rarity": "Common",
		"gold_cost": 6,
		"category": "Cooking"
	},
	{
		"item_name": "Dried Apples",
		"description": "Wrinkled slices of apple, tart and leathery with a touch of sweetness. They keep well on long roads and soften nicely in porridge.",
		"rarity": "Common",
		"gold_cost": 8,
		"category": "Cooking"
	},
	{
		"item_name": "Onion Braid",
		"description": "A hanging braid of pungent onions with papery skins. Their sharp scent lingers on hands, knives, and cutting boards for hours.",
		"rarity": "Common",
		"gold_cost": 7,
		"category": "Cooking"
	},
	{
		"item_name": "Garlic Bulb",
		"description": "A cluster of white cloves wrapped in thin, brittle skin. Its smell is strong, earthy, and welcome in any poor kitchen.",
		"rarity": "Common",
		"gold_cost": 6,
		"category": "Cooking"
	},
	{
		"item_name": "Turnip Crate",
		"description": "A crate of dirt-dusted turnips with cracked purple tops. Sturdy fare for stew pots, cellars, and winter tables.",
		"rarity": "Common",
		"gold_cost": 9,
		"category": "Cooking"
	},
	{
		"item_name": "Carrot Bundle",
		"description": "A tied bundle of crooked carrots with green tops still attached. Sweet enough for soup, roast pans, or a hungry mule.",
		"rarity": "Common",
		"gold_cost": 8,
		"category": "Cooking"
	},
	{
		"item_name": "Cabbage Head",
		"description": "A dense green cabbage wrapped in cool, waxy leaves. It keeps well in storage and stretches a meal farther than most vegetables.",
		"rarity": "Common",
		"gold_cost": 7,
		"category": "Cooking"
	},
	{
		"item_name": "Potato Basket",
		"description": "A basket of knobby potatoes still carrying the scent of damp soil. Ugly, filling, and indispensable to any working household.",
		"rarity": "Common",
		"gold_cost": 10,
		"category": "Cooking"
	},
	{
		"item_name": "Leek Stalks",
		"description": "Long pale stalks with green tops and a mild onion scent. They soften into broth and lend sweetness to otherwise tired meals.",
		"rarity": "Common",
		"gold_cost": 8,
		"category": "Cooking"
	},
	{
		"item_name": "Goat Cheese",
		"description": "A small round of crumbly white cheese wrapped in cloth. It smells tangy and sharp, with a richness that survives long travel.",
		"rarity": "Common",
		"gold_cost": 11,
		"category": "Cooking"
	},
	{
		"item_name": "Buttermilk Jug",
		"description": "A glazed jug of thin, sour buttermilk with a cool clean smell. Useful in baking, marinating, or drinking when nothing fresher remains.",
		"rarity": "Common",
		"gold_cost": 9,
		"category": "Cooking"
	},
	{
		"item_name": "Egg Basket",
		"description": "A straw-lined basket of fragile eggs in pale brown and cream. Delicate cargo, but one of the most useful things a kitchen can keep.",
		"rarity": "Common",
		"gold_cost": 10,
		"category": "Cooking"
	},
	{
		"item_name": "Honey Jar",
		"description": "A clay-sealed jar of amber honey that pours slowly in golden threads. It smells of summer flowers and old wooden hives.",
		"rarity": "Common",
		"gold_cost": 12,
		"category": "Cooking"
	},
	{
		"item_name": "Barley Flour",
		"description": "A coarse, darker flour with a nutty smell and gritty feel. It makes hearty bread fit for laborers and long marches.",
		"rarity": "Common",
		"gold_cost": 8,
		"category": "Cooking"
	},
	{
		"item_name": "Oat Groats",
		"description": "Pale kernels of oats dried for storage in a cloth pouch. They cook into thick porridge and keep a camp fed on bitter mornings.",
		"rarity": "Common",
		"gold_cost": 7,
		"category": "Cooking"
	},
	{
		"item_name": "Dried Peas",
		"description": "Small green peas hardened by drying and age. Plain to look at, but they swell into hearty soup with time and patience.",
		"rarity": "Common",
		"gold_cost": 6,
		"category": "Cooking"
	},
	{
		"item_name": "Rendered Lard",
		"description": "A crock of white cooking fat, smooth and dense beneath its lid. It smells faintly porky and turns humble dough into something worth eating.",
		"rarity": "Common",
		"gold_cost": 9,
		"category": "Cooking"
	},
	{
		"item_name": "Mead Vinegar",
		"description": "A bottle of pale vinegar with a sweet edge beneath its sour bite. Used for pickling, cleaning, and reviving tired sauces.",
		"rarity": "Common",
		"gold_cost": 8,
		"category": "Cooking"
	},
	{
		"item_name": "Peppercorn Pouch",
		"description": "A small pouch of dark, fragrant peppercorns that rattle when shaken. A modest luxury that transforms bland food into something memorable.",
		"rarity": "Uncommon",
		"gold_cost": 21,
		"category": "Cooking"
	},
	{
		"item_name": "Mustard Seed",
		"description": "Tiny yellow-brown seeds with a sharp, nose-pricking aroma when crushed. They lend bite to sauces, brines, and roasted meats.",
		"rarity": "Common",
		"gold_cost": 12,
		"category": "Cooking"
	},
	{
		"item_name": "Dried Dill",
		"description": "A brittle bundle of feathery herbs tied with twine. It smells fresh even in death and pairs well with fish, roots, and pickles.",
		"rarity": "Common",
		"gold_cost": 9,
		"category": "Cooking"
	},
	{
		"item_name": "Rosemary Sprig",
		"description": "A pine-scented herb bundle with woody stems and narrow leaves. It perfumes kitchens, roast pans, and smoky stew pots alike.",
		"rarity": "Common",
		"gold_cost": 10,
		"category": "Cooking"
	},
	{
		"item_name": "Bay Leaves",
		"description": "Flat dried leaves with a warm, bitter fragrance that deepens in hot broth. One or two is enough to make a pot smell richer than it is.",
		"rarity": "Common",
		"gold_cost": 9,
		"category": "Cooking"
	},
	{
		"item_name": "Cinnamon Bark",
		"description": "Curled strips of fragrant bark, dry and reddish-brown. Sweet, woody, and a little rare in rougher markets.",
		"rarity": "Uncommon",
		"gold_cost": 24,
		"category": "Cooking"
	},
	{
		"item_name": "Clove Packet",
		"description": "A tiny wrapped packet of dark flower buds with an intense, medicinal spice. Strong enough that a few pieces can scent an entire kitchen.",
		"rarity": "Uncommon",
		"gold_cost": 26,
		"category": "Cooking"
	},
	{
		"item_name": "Rice Pouch",
		"description": "A cloth pouch of pale rice grains, dry and faintly nutty. It cooks cleanly and fills bowls with little waste.",
		"rarity": "Uncommon",
		"gold_cost": 22,
		"category": "Cooking"
	},
	{
		"item_name": "Rye Grain",
		"description": "Dark grains with a sharp, earthy scent and a harder bite than wheat. Ground or boiled, it feeds folk who work for every meal.",
		"rarity": "Common",
		"gold_cost": 8,
		"category": "Cooking"
	},
	{
		"item_name": "Yeast Cake",
		"description": "A damp cake of living starter wrapped in parchment and cloth. It smells warm, sour, and faintly alive when broken apart.",
		"rarity": "Common",
		"gold_cost": 11,
		"category": "Cooking"
	},
	{
		"item_name": "Dried Sausage",
		"description": "A smoked length of preserved sausage hung to harden in cool air. Rich with fat, spice, and enough salt to survive the road.",
		"rarity": "Common",
		"gold_cost": 13,
		"category": "Cooking"
	},
	{
		"item_name": "Smoked Herring",
		"description": "A bundle of thin smoked fish with silvery skin and a strong briny smell. Salty, oily, and far better than an empty pot.",
		"rarity": "Common",
		"gold_cost": 12,
		"category": "Cooking"
	},
	{
		"item_name": "Apple Cider",
		"description": "A corked bottle of cloudy cider with a tart orchard scent. Good for drinking, glazing, or lifting the flavor of stew.",
		"rarity": "Common",
		"gold_cost": 10,
		"category": "Cooking"
	},
	{
		"item_name": "Molasses Jug",
		"description": "A heavy jug of dark syrup that pours slow as tar. Bitter-sweet and rich, it is prized for baking and brewing alike.",
		"rarity": "Uncommon",
		"gold_cost": 23,
		"category": "Cooking"
	},
	{
		"item_name": "Canvas Patch",
		"description": "A stack of rough canvas squares cut for aprons, sacks, or repairs. Stiff at first, but durable once stitched in place.",
		"rarity": "Common",
		"gold_cost": 10,
		"category": "Crafting"
	},
	{
		"item_name": "Twine Spool",
		"description": "A spool of coarse plant-fiber twine, scratchy and dependable. It ties herbs, binds parcels, and fixes more than it ought to.",
		"rarity": "Common",
		"gold_cost": 6,
		"category": "Crafting"
	},
	{
		"item_name": "Sewing Needles",
		"description": "A little roll of steel needles kept in oiled cloth against rust. Plain tools, but they keep clothes, sacks, and linens alive.",
		"rarity": "Common",
		"gold_cost": 12,
		"category": "Crafting"
	},
	{
		"item_name": "Copper Pot",
		"description": "A dented but serviceable pot with soot darkening its underside. It heats evenly and carries the smell of a hundred past suppers.",
		"rarity": "Uncommon",
		"gold_cost": 30,
		"category": "Crafting"
	},
	{
		"item_name": "Wooden Ladle",
		"description": "A long ladle carved from smooth hardwood and darkened by use. It bears old stew stains and the shine of many hands.",
		"rarity": "Common",
		"gold_cost": 7,
		"category": "Crafting"
	},
	{
		"item_name": "Clay Crock",
		"description": "A thick-walled crock meant for brining, storage, or fermenting. Its inside smells faintly of salt, dill, and old kitchens.",
		"rarity": "Common",
		"gold_cost": 13,
		"category": "Crafting"
	},
	{
		"item_name": "Pickling Brine",
		"description": "A sealed jug of salty, spiced brine ready for vegetables or fish. Sour on the nose and invaluable when winter draws near.",
		"rarity": "Uncommon",
		"gold_cost": 20,
		"category": "Cooking"
	},
	{
		"item_name": "Torch Bundle",
		"description": "A bundle of resin-soaked torches wrapped in twine. They burn hot, smoke thickly, and keep the dark at a respectful distance.",
		"rarity": "Common",
		"gold_cost": 9,
		"category": "Crafting"
	},
	{
		"item_name": "Rope Coil",
		"description": "A sturdy coil of hemp rope, rough on the palms and smelling faintly of tar. Useful for climbing, binding, hauling, and surviving bad decisions.",
		"rarity": "Common",
		"gold_cost": 12,
		"category": "Crafting"
	},
	{
		"item_name": "Bedroll",
		"description": "A rolled blanket and canvas wrap tied with worn leather straps. It keeps a traveler off the cold ground, though not always away from its teeth.",
		"rarity": "Common",
		"gold_cost": 14,
		"category": "Crafting"
	},
	{
		"item_name": "Waterskin",
		"description": "A cured leather flask with a cork stopper and a faint animal scent. Plain, durable, and precious once the road grows dry.",
		"rarity": "Common",
		"gold_cost": 11,
		"category": "Crafting"
	},
	{
		"item_name": "Travel Rations",
		"description": "A packed assortment of hard bread, dried meat, and coarse cheese. Not pleasant fare, but it keeps a body moving.",
		"rarity": "Common",
		"gold_cost": 10,
		"category": "Cooking"
	},
	{
		"item_name": "Flint Kit",
		"description": "A pouch holding flint, steel, and dry tinder scraps. The contents are humble until a wet night makes them priceless.",
		"rarity": "Common",
		"gold_cost": 8,
		"category": "Crafting"
	},
	{
		"item_name": "Lantern",
		"description": "A metal lantern with smoked glass panes and a wire handle. It throws a steadier light than a torch and makes fewer promises than the sun.",
		"rarity": "Common",
		"gold_cost": 15,
		"category": "Crafting"
	},
	{
		"item_name": "Tent Cloth",
		"description": "Folded waxed canvas with loops for staking and tying. Heavy when wet, but welcome when the skies break open.",
		"rarity": "Common",
		"gold_cost": 13,
		"category": "Crafting"
	},
	{
		"item_name": "Mess Tin",
		"description": "A dented little tin pot blackened by past fires. It boils water, warms stew, and rattles loudly in careless packs.",
		"rarity": "Common",
		"gold_cost": 9,
		"category": "Crafting"
	},
	{
		"item_name": "Tin Cup",
		"description": "A simple metal cup with a bent handle and old scratch marks. It serves for broth, ale, medicine, or whatever the road allows.",
		"rarity": "Common",
		"gold_cost": 6,
		"category": "Crafting"
	},
	{
		"item_name": "Bandage Roll",
		"description": "A clean roll of cloth meant for wrapping wounds and splinting limbs. It smells of soap, linen, and quiet hope.",
		"rarity": "Common",
		"gold_cost": 12,
		"category": "Crafting"
	},
	{
		"item_name": "Whetstone",
		"description": "A flat sharpening stone wrapped in oiled cloth against cracking. It leaves steel cleaner, keener, and more honest.",
		"rarity": "Common",
		"gold_cost": 10,
		"category": "Crafting"
	},
	{
		"item_name": "Oil Flask",
		"description": "A small flask of lamp oil with a bitter, greasy scent. It feeds lanterns, slicks hinges, and turns fire into a louder argument.",
		"rarity": "Common",
		"gold_cost": 8,
		"category": "Crafting"
	},
	{
		"item_name": "Fishing Line",
		"description": "A spool of line with hooks tucked into a scrap of cork. Light to carry and often the difference between hunger and supper.",
		"rarity": "Common",
		"gold_cost": 7,
		"category": "Crafting"
	},
	{
		"item_name": "Trap Spikes",
		"description": "A bundle of iron stakes meant for securing lines, tents, or less merciful devices. Cold, plain, and undeniably useful.",
		"rarity": "Common",
		"gold_cost": 11,
		"category": "Crafting"
	},
	{
		"item_name": "Crowbar",
		"description": "A thick iron bar with one end flattened for prying. It opens crates, stubborn doors, and sometimes tombs best left shut.",
		"rarity": "Uncommon",
		"gold_cost": 24,
		"category": "Crafting"
	},
	{
		"item_name": "Grappling Hook",
		"description": "A four-pronged hook of forged iron with a ring for rope. It clatters loudly, bites hard, and inspires risky confidence.",
		"rarity": "Uncommon",
		"gold_cost": 28,
		"category": "Crafting"
	},
	{
		"item_name": "Chalk Sticks",
		"description": "A packet of white chalk wrapped in cloth to keep it from crumbling. Ideal for marking tunnels, trails, and poor choices.",
		"rarity": "Common",
		"gold_cost": 5,
		"category": "Crafting"
	},
	{
		"item_name": "Shovel",
		"description": "A short travel shovel with a wood handle and iron blade. Good for campfires, graves, and anything that starts with digging.",
		"rarity": "Common",
		"gold_cost": 14,
		"category": "Crafting"
	},
	{
		"item_name": "Pick Hammer",
		"description": "A compact hammer with a wedge-shaped beak for stone and packed earth. It rings sharply when used in crypts and caves.",
		"rarity": "Uncommon",
		"gold_cost": 26,
		"category": "Crafting"
	},
	{
		"item_name": "Map Case",
		"description": "A leather tube meant to keep parchment dry and mostly flat. It smells of oil, dust, and expensive directions.",
		"rarity": "Common",
		"gold_cost": 13,
		"category": "Crafting"
	},
	{
		"item_name": "Compass",
		"description": "A brass compass with a scratched lid and a nervous needle. Tiny, silent, and deeply comforting when landmarks vanish.",
		"rarity": "Uncommon",
		"gold_cost": 32,
		"category": "Crafting"
	},
	{
		"item_name": "Signal Whistle",
		"description": "A small metal whistle that shrieks sharply enough to cut through wind and panic. Subtle it is not.",
		"rarity": "Common",
		"gold_cost": 7,
		"category": "Crafting"
	},
	{
		"item_name": "Trail Flags",
		"description": "Bright scraps of cloth tied to little wooden pegs. They mark safe paths, campsites, and the route back out.",
		"rarity": "Common",
		"gold_cost": 6,
		"category": "Crafting"
	},
	{
		"item_name": "Caltrop Pouch",
		"description": "A pouch of sharp little iron jacks, each designed to leave one point upward. Crude tools, but persuasive to pursuers.",
		"rarity": "Uncommon",
		"gold_cost": 22,
		"category": "Crafting"
	},
	{
		"item_name": "Spare Buckles",
		"description": "A handful of metal buckles and rivets for repairing straps and harnesses. Small pieces that save large headaches.",
		"rarity": "Common",
		"gold_cost": 9,
		"category": "Crafting"
	},
	{
		"item_name": "Saddle Blanket",
		"description": "A folded wool blanket meant for pack animals or cold sleepers. It carries the scent of dust, sweat, and long miles.",
		"rarity": "Common",
		"gold_cost": 12,
		"category": "Crafting"
	},
	{
		"item_name": "Pack Harness",
		"description": "A leather harness rigged with rings and adjustable straps for carrying burden across beasts or backs. It creaks softly with every step.",
		"rarity": "Uncommon",
		"gold_cost": 27,
		"category": "Crafting"
	},
	{
		"item_name": "Rain Cloak",
		"description": "A waxed traveling cloak that sheds water and keeps the worst of the wind off. It smells faintly of oil, wool, and road mud.",
		"rarity": "Common",
		"gold_cost": 15,
		"category": "Crafting"
	},
	{
		"item_name": "Snow Goggles",
		"description": "Simple slitted eye shields of wood and leather used against glare and blowing frost. Crude to behold, but kind to the eyes.",
		"rarity": "Uncommon",
		"gold_cost": 21,
		"category": "Crafting"
	},
	{
		"item_name": "Insect Salve",
		"description": "A pungent herbal grease stored in a small tin. It smells awful, works well, and leaves the skin shiny and bitter.",
		"rarity": "Common",
		"gold_cost": 11,
		"category": "Crafting"
	},
	{
		"item_name": "Needle Kit",
		"description": "A travel roll of needles, awls, and heavy thread for field repairs. Torn packs and split seams rarely wait for town.",
		"rarity": "Common",
		"gold_cost": 10,
		"category": "Crafting"
	},
	{
		"item_name": "Mortar Cup",
		"description": "A small stone cup with a matching pestle for grinding herbs and powders. Heavy for its size, but invaluable to practical hands.",
		"rarity": "Uncommon",
		"gold_cost": 23,
		"category": "Crafting"
	},
	{
		"item_name": "Lock Picks",
		"description": "A wrap of thin steel tools tucked in waxed leather. Delicate little instruments meant for quiet entries and bad manners.",
		"rarity": "Uncommon",
		"gold_cost": 35,
		"category": "Crafting"
	},
	{
		"item_name": "Signal Mirror",
		"description": "A polished hand mirror with a notch for aiming reflected light. Useless in darkness, excellent when the sky cooperates.",
		"rarity": "Common",
		"gold_cost": 12,
		"category": "Crafting"
	},
	{
		"item_name": "Tar Pot",
		"description": "A sealed clay pot of thick black tar that softens over heat. Used for patching boots, sealing seams, and weatherproofing gear.",
		"rarity": "Uncommon",
		"gold_cost": 20,
		"category": "Crafting"
	},
	{
		"item_name": "Chain Links",
		"description": "A short length of repair chain, cold and heavy in the hand. Good for securing gates, wagons, prisoners, or suspicious chests.",
		"rarity": "Uncommon",
		"gold_cost": 25,
		"category": "Crafting"
	},
	{
		"item_name": "Folded Stretcher",
		"description": "A collapsible frame of wood and canvas for carrying the injured. Awkward to pack, but merciful when the march turns ugly.",
		"rarity": "Uncommon",
		"gold_cost": 30,
		"category": "Crafting"
	},
	{
		"item_name": "Ration Box",
		"description": "A hard-sided travel box fitted for dried food, crumbs, and precious leftovers. It keeps supplies drier than a sack and safer than hope.",
		"rarity": "Common",
		"gold_cost": 14,
		"category": "Crafting"
	},
	{
		"item_name": "Tinder Fungus",
		"description": "A dry, fibrous shelf fungus cut for catching sparks quickly. Light as bark, brittle as old parchment, and wonderful in rain-soaked lands.",
		"rarity": "Common",
		"gold_cost": 6,
		"category": "Crafting"
	},
	{
		"item_name": "Dawn Sigil",
		"description": "A bronze insignia once worn by the Order of the Dawn during the last years before the Shattering War. Its sunburst edge is dulled by age, but the creed of Greyspire's wardens is still etched into the back.",
		"rarity": "Uncommon",
		"gold_cost": 44,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Oath Parchment",
		"description": "A brittle vow-scroll signed by knights of the Order of the Dawn before riding into the Shattering War. The wax seal bears the old mark of Greyspire and a warning about the Veil.",
		"rarity": "Rare",
		"gold_cost": 96,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Sunsteel Rivet",
		"description": "A radiant fastening pin salvaged from shattered Dawn plate recovered near Greyspire. It was forged for armor meant to stand against horrors that slipped through cracks in the Veil.",
		"rarity": "Rare",
		"gold_cost": 82,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Trial Lens",
		"description": "A polished crystal used in the old virtue trials of the Order of the Dawn. When held to candlelight, faint script from before the Shattering War blooms across its face.",
		"rarity": "Epic",
		"gold_cost": 214,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Hadrien's Spur",
		"description": "A silvered riding spur from a fallen Dawn captain whose grave was never properly closed after the Shattering War. Its edge is engraved with a prayer asking the Veil to hold one night longer.",
		"rarity": "Rare",
		"gold_cost": 118,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Greyspire Reliquary",
		"description": "A small reliquary box stolen from the ruined chapels of Greyspire after necromancy defiled the stronghold. Ash and old incense cling to it beneath the smell of opened crypts.",
		"rarity": "Epic",
		"gold_cost": 248,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Veilkeeper Plate",
		"description": "A ceremonial chestplate fragment hammered with the doctrine that the Order of the Dawn kept hidden from Aurelia. It was crafted to honor those who died preserving the lie surrounding the Veil.",
		"rarity": "Epic",
		"gold_cost": 301,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Veilbreaker Shard",
		"description": "A broken piece of the Veilbreaker blade sought in the ruins of the Order of the Dawn. The metal hums whenever Vel'golath's influence presses thin against the Veil.",
		"rarity": "Legendary",
		"gold_cost": 760,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Purifier Seal",
		"description": "A stamped brass token issued to Valeron Purifiers for unsanctioned arrests and holy burnings. Moderates in Valeron deny such seals exist, which only increases their price.",
		"rarity": "Rare",
		"gold_cost": 101,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Sun-Gold Phial",
		"description": "A contraband flask of concentrated sacramental oil refined for elite rites in Valeron. It burns with unnaturally clear flame and is rumored to be used in interrogations by the Purifiers.",
		"rarity": "Epic",
		"gold_cost": 226,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "League Cipher",
		"description": "A rotating brass code wheel used by Vharian Merchant League brokers tied to the Luminous Table. Its notches conceal shipping routes, debt markers, and smuggling contacts along the Black Coast.",
		"rarity": "Rare",
		"gold_cost": 124,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Smuggler Lens",
		"description": "A compact optical lens traded among Vharian Merchant League runners moving forbidden cargo at night. It carries a maker's stamp scratched away by order of the Luminous Table.",
		"rarity": "Uncommon",
		"gold_cost": 48,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Edran Grain Writ",
		"description": "A sealed transport charter authorizing hidden grain diversion from famine-starved Edranor estates. Noble stewards hoard these under false names while villages go hungry.",
		"rarity": "Rare",
		"gold_cost": 88,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Knight Tax Roll",
		"description": "A coded levy record from the Kingdom of Edranor listing lands stripped to fund crumbling chivalric banners. Mud and old wax stain the names of peasants who paid with their winter stores.",
		"rarity": "Uncommon",
		"gold_cost": 37,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Luminous Ledger",
		"description": "A hidden account book maintained for the Luminous Table of the Vharian Merchant League. Every page ties respectable merchants to war profiteering, embargo fraud, and relic trafficking.",
		"rarity": "Epic",
		"gold_cost": 287,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Solar Edict",
		"description": "An unpublished Valeron decree authorizing seizure of marked children in the name of containment and sacred order. Its signatures implicate both Purifiers and cautious Moderates who chose silence.",
		"rarity": "Legendary",
		"gold_cost": 680,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Vespera's Ink",
		"description": "A black-red ritual ink brewed for the Obsidian Circle under Lady Vespera's supervision. It dries with a metallic sheen and is used to bind names into blood rites.",
		"rarity": "Rare",
		"gold_cost": 112,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Enric's Salts",
		"description": "Grey crystallized salts prepared by Master Enric for corpse preservation and soul-binding calculations. They smell faintly medicinal until moisture wakes the rot beneath.",
		"rarity": "Rare",
		"gold_cost": 93,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Soulwire Coil",
		"description": "A thin spool of silver-black filament used by Obsidian Circle necromancers to anchor spirits during dissection rites. It was found in field laboratories hidden beyond Greyspire's crypts.",
		"rarity": "Epic",
		"gold_cost": 233,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Ash Catechism",
		"description": "A soot-smeared handbook copied among junior warlocks of the Obsidian Circle. Its lessons praise Lady Vespera while quietly teaching how to survive failed communion with Vel'golath.",
		"rarity": "Uncommon",
		"gold_cost": 41,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Widow Resin",
		"description": "A dark resin burned by Obsidian Circle mourners before battlefield harvests. The smoke is sweet at first, then leaves the tongue bitter with grave dust.",
		"rarity": "Uncommon",
		"gold_cost": 52,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Marena's Locket",
		"description": "A small silver locket once belonging to Marena before she became Lady Vespera. The inside contains a faded scrap tied to Lyell and the first whispers of rebellion against those who guarded the Veil.",
		"rarity": "Epic",
		"gold_cost": 318,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Binder's Phial",
		"description": "A stoppered phial of pale fluid used by Master Enric to suspend soul residue between death and command. It is traded only among the most trusted necromancers of the Obsidian Circle.",
		"rarity": "Rare",
		"gold_cost": 131,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Obsidian Grimoire",
		"description": "A chained ritual book carried by senior circle adepts when preparing a breach near the Veil. Its margins contain Lady Vespera's revisions correcting older doctrines about Vel'golath.",
		"rarity": "Legendary",
		"gold_cost": 820,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Veil Glass",
		"description": "A translucent shard formed where the Veil thinned and sealed again. Looking through it makes the edges of Aurelia seem fractionally misaligned.",
		"rarity": "Rare",
		"gold_cost": 136,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Entropy Pearl",
		"description": "A smooth dark sphere recovered from sites touched by Vel'golath's pressure. It grows colder in crowded rooms, as if resenting the persistence of living things.",
		"rarity": "Epic",
		"gold_cost": 269,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Voidfilament",
		"description": "A trembling strand of matter that appears where reality frays near the Sunken Spire. It reflects no light, yet its outline stings the eye like a remembered wound.",
		"rarity": "Epic",
		"gold_cost": 241,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Night of Cinders",
		"description": "A vial of black dust gathered from a breach-scored ruin and named for the old Night of Unknowing. Scholars at the College of Seekers pay richly for even a pinch, though many later regret touching it.",
		"rarity": "Rare",
		"gold_cost": 107,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Rift Amber",
		"description": "A lump of fossil-like amber containing suspended motes that drift when no hand moves it. College of Seekers records claim it forms only where Vel'golath brushes the Veil without fully passing through.",
		"rarity": "Epic",
		"gold_cost": 336,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Hush Stone",
		"description": "A polished stone from a Veil-disturbed cavern that deadens nearby sound for a few breaths. It is prized by spies, heretics, and terrified scholars of forbidden lore.",
		"rarity": "Uncommon",
		"gold_cost": 46,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Memory Splinter",
		"description": "A crystalline sliver that induces flashes of lives not entirely one's own. The College of Seekers believes these form where the Veil rubs against buried grief left from the Shattering War.",
		"rarity": "Rare",
		"gold_cost": 138,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Vel'golath Core",
		"description": "A pulsing anomaly recovered only from the deepest ritual scars near the Sunken Spire. Its surface shows impossible depth, and every witness describes a different shape within.",
		"rarity": "Legendary",
		"gold_cost": 900,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Emberwood Resin",
		"description": "A glowing orange resin tapped from trees that survived the long burn of Emberwood. It smells like smoke, pine, and a campfire that never truly goes out.",
		"rarity": "Uncommon",
		"gold_cost": 39,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Cinder Bloom",
		"description": "A black-petaled flower that opens only in the ash beds of Emberwood after violent heat. Apothecaries prize it for stimulants, and cultists for less merciful infusions.",
		"rarity": "Rare",
		"gold_cost": 84,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Marsh Wisp Reed",
		"description": "A pale reed harvested in the Weeping Marsh where trapped souls gather over dark water. When dried, it emits faint tones like distant voices in prayer.",
		"rarity": "Uncommon",
		"gold_cost": 33,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Weeping Lily",
		"description": "A marsh flower with translucent petals gathered from ritual pools in the Weeping Marsh. The stem leaks saline droplets said to carry the sorrow of bound spirits.",
		"rarity": "Rare",
		"gold_cost": 99,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Saltglass Coral",
		"description": "A razor-edged white coral dredged from reefs below the Black Coast and traded through dangerous channels. Vharian divers claim it grows fastest near drowned altars linked to the Sunken Spire.",
		"rarity": "Rare",
		"gold_cost": 117,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Tideglass Ore",
		"description": "A blue-black mineral mined from sea caves battered by storms along the Black Coast. The Vharian Merchant League uses it in experimental devices descended from forgotten technology.",
		"rarity": "Epic",
		"gold_cost": 207,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Oakhaven Charm",
		"description": "A scorched household charm found in the ruins of Oakhaven after Lady Vespera's assault. Though humble in origin, survivors treat intact ones as sacred proof that the village once lived.",
		"rarity": "Rare",
		"gold_cost": 72,
		"category": "Lore_And_Misc"
	},
	{
		"item_name": "Spire Barnacle",
		"description": "A hard, iridescent growth scraped from the flooded lower stones of the Sunken Spire. It reeks of salt and sacrament, and sometimes twitches when placed near Veil-touched artifacts.",
		"rarity": "Epic",
		"gold_cost": 191,
		"category": "Lore_And_Misc"
	}
]
func _run() -> void:
	print("Starting material generation...")

	var success_count: int = 0
	var failure_count: int = 0
	var ensured_directories: Dictionary = {}

	for data in generated_materials:
		var mat := MaterialData.new()

		mat.item_name = String(data.get("item_name", "Unknown Material"))
		mat.description = String(data.get("description", ""))
		mat.rarity = String(data.get("rarity", "Common"))
		mat.gold_cost = int(data.get("gold_cost", 10))

		var category: String = _normalize_category(String(data.get("category", "")))
		mat.category = category
		mat.icon = _get_icon_for_category(category)

		var category_directory: String = BASE_SAVE_PATH + category + "/"

		if not ensured_directories.has(category_directory):
			var absolute_dir: String = ProjectSettings.globalize_path(category_directory)
			var dir_error: Error = DirAccess.make_dir_recursive_absolute(absolute_dir)

			if dir_error != OK and not DirAccess.dir_exists_absolute(absolute_dir):
				push_error("Failed to create directory: %s" % category_directory)
				failure_count += 1
				continue

			ensured_directories[category_directory] = true

		var file_name: String = _make_safe_file_name(mat.item_name)
		var save_path: String = category_directory + file_name + ".tres"

		var save_error: Error = ResourceSaver.save(mat, save_path)
		if save_error == OK:
			print("Created: %s" % save_path)
			success_count += 1
		else:
			push_error("Failed to save: %s" % save_path)
			failure_count += 1

	print("====================================")
	print("SUCCESS: Generated %d new material resources." % success_count)
	print("FAILED: %d material resources." % failure_count)
	print("====================================")


func _normalize_category(raw_category: String) -> String:
	if raw_category in VALID_CATEGORIES:
		return raw_category

	push_warning("Missing or invalid category '%s'. Falling back to Lore_And_Misc." % raw_category)
	return "Lore_And_Misc"


func _get_icon_for_category(category: String) -> Texture2D:
	var icon_path: String = String(CATEGORY_ICONS.get(category, ""))

	if icon_path.is_empty():
		push_warning("No icon path mapped for category: %s" % category)
		return null

	var texture: Texture2D = load(icon_path) as Texture2D
	if texture == null:
		push_warning("Failed to load icon at path: %s" % icon_path)

	return texture


func _make_safe_file_name(raw_name: String) -> String:
	var cleaned_name: String = raw_name.strip_edges().to_lower()

	cleaned_name = cleaned_name.replace(" ", "_")
	cleaned_name = cleaned_name.replace("-", "_")
	cleaned_name = cleaned_name.replace("'", "")
	cleaned_name = cleaned_name.replace("\"", "")
	cleaned_name = cleaned_name.replace(":", "")
	cleaned_name = cleaned_name.replace(",", "")
	cleaned_name = cleaned_name.replace(".", "")

	while cleaned_name.contains("__"):
		cleaned_name = cleaned_name.replace("__", "_")

	return cleaned_name
