class_name DiscoverableCards
## Hidden evidence cards scattered on the parcel. Campers can collect them
## when finishing a walk or inspect near the cell; success chance depends
## on activity (inspect / roam / move).
##
## All `name` and `stories` strings are translation msgids — keep them in
## i18n/translations.csv (en/fr) and display via localize() or tr().

const KIND_DEAD_BIRD := "dead_bird"
const KIND_DEAD_BEAVER := "dead_beaver"
const KIND_FORBIDDEN_CUT := "forbidden_cut"
const KIND_ANIMAL_TRAP := "animal_trap"
const KIND_WOUNDED_ANIMAL := "wounded_animal"
const KIND_BERRIES := "berries"
const KIND_BIRD_NEST_REMNANTS := "bird_nest_remnants"
const KIND_DRIED_GROUND := "dried_ground"
const KIND_FISHING_LINE := "fishing_line"
const KIND_LEFTOVER_FOOD := "leftover_food"
const KIND_DANDELION := "dandelion"
const KIND_NETTLE := "nettle"
const KIND_RIBWORT_PLANTAIN := "ribwort_plantain"
const KIND_CLOVER := "clover"
const KIND_PRIMROSE := "primrose"
const KIND_WHITE_DEADNETTLE := "white_deadnettle"
const KIND_YARROW := "yarrow"
const KIND_EUROPEAN_ROBIN := "european_robin"
const KIND_COMMON_BLACKBIRD := "common_blackbird"
const KIND_GREAT_TIT := "great_tit"
const KIND_BLUE_TIT := "blue_tit"
const KIND_WOOD_PIGEON := "wood_pigeon"
const KIND_EURASIAN_JAY := "eurasian_jay"
const KIND_SONG_THRUSH := "song_thrush"
const KIND_BLACKCAP := "blackcap"
const KIND_GREEN_WOODPECKER := "green_woodpecker"

## Botanist plant finds — observational cards with stories, no Solve actions.
const PLANT_KINDS := [
	KIND_DANDELION, KIND_NETTLE, KIND_RIBWORT_PLANTAIN, KIND_CLOVER,
	KIND_PRIMROSE, KIND_WHITE_DEADNETTLE, KIND_YARROW,
]

## Ornithologist bird sightings — observational cards with stories, no Solve actions.
const BIRD_SPECIES_KINDS := [
	KIND_EUROPEAN_ROBIN, KIND_COMMON_BLACKBIRD, KIND_GREAT_TIT, KIND_BLUE_TIT,
	KIND_WOOD_PIGEON, KIND_EURASIAN_JAY, KIND_SONG_THRUSH, KIND_BLACKCAP,
	KIND_GREEN_WOODPECKER,
]

## Some finds only register for a matching camper role.
const REQUIRED_ROLES := {
	KIND_BIRD_NEST_REMNANTS: "Ornithologist",
	KIND_DANDELION: "Botanist",
	KIND_NETTLE: "Botanist",
	KIND_RIBWORT_PLANTAIN: "Botanist",
	KIND_CLOVER: "Botanist",
	KIND_PRIMROSE: "Botanist",
	KIND_WHITE_DEADNETTLE: "Botanist",
	KIND_YARROW: "Botanist",
	KIND_EUROPEAN_ROBIN: "Ornithologist",
	KIND_COMMON_BLACKBIRD: "Ornithologist",
	KIND_GREAT_TIT: "Ornithologist",
	KIND_BLUE_TIT: "Ornithologist",
	KIND_WOOD_PIGEON: "Ornithologist",
	KIND_EURASIAN_JAY: "Ornithologist",
	KIND_SONG_THRUSH: "Ornithologist",
	KIND_BLACKCAP: "Ornithologist",
	KIND_GREEN_WOODPECKER: "Ornithologist",
}

## Journal msgid when a camper discovers this kind (one `%s` = camper name).
const JOURNAL_MSGIDS := {
	KIND_DEAD_BIRD: "%s found a dead bird",
	KIND_DEAD_BEAVER: "%s found a dead beaver",
	KIND_FORBIDDEN_CUT: "%s found a forbidden cut",
	KIND_ANIMAL_TRAP: "%s found an animal trap",
	KIND_WOUNDED_ANIMAL: "%s found a wounded animal",
	KIND_BIRD_NEST_REMNANTS: "%s found bird's nest remnants",
	KIND_BERRIES: "%s found berries",
	KIND_DRIED_GROUND: "%s found dried ground",
	KIND_FISHING_LINE: "%s found discarded fishing line",
	KIND_LEFTOVER_FOOD: "%s found leftover food",
	KIND_DANDELION: "%s found a dandelion",
	KIND_NETTLE: "%s found nettle",
	KIND_RIBWORT_PLANTAIN: "%s found ribwort plantain",
	KIND_CLOVER: "%s found clover",
	KIND_PRIMROSE: "%s found a primrose",
	KIND_WHITE_DEADNETTLE: "%s found white deadnettle",
	KIND_YARROW: "%s found yarrow",
	KIND_EUROPEAN_ROBIN: "%s spotted a European robin",
	KIND_COMMON_BLACKBIRD: "%s spotted a common blackbird",
	KIND_GREAT_TIT: "%s spotted a great tit",
	KIND_BLUE_TIT: "%s spotted a blue tit",
	KIND_WOOD_PIGEON: "%s spotted a wood pigeon",
	KIND_EURASIAN_JAY: "%s spotted a Eurasian jay",
	KIND_SONG_THRUSH: "%s spotted a song thrush",
	KIND_BLACKCAP: "%s spotted a blackcap",
	KIND_GREEN_WOODPECKER: "%s spotted a green woodpecker",
}

## Role responses when Solve runs on untreated journal events.
## Each rule: role msgid, event kinds it applies to, action msgid (`%s` = actor).
const SOLVE_RULES := [
	{
		"role": "Activist",
		"kinds": [
			KIND_FORBIDDEN_CUT, KIND_ANIMAL_TRAP, KIND_BIRD_NEST_REMNANTS,
			KIND_DRIED_GROUND, KIND_FISHING_LINE, KIND_LEFTOVER_FOOD,
		],
		"action": "%s contacted an NGO",
	},
	{
		"role": "Journalist",
		"kinds": [
			KIND_FORBIDDEN_CUT, KIND_DEAD_BIRD, KIND_DEAD_BEAVER,
			KIND_ANIMAL_TRAP, KIND_WOUNDED_ANIMAL, KIND_BIRD_NEST_REMNANTS,
			KIND_DRIED_GROUND, KIND_FISHING_LINE, KIND_LEFTOVER_FOOD,
		],
		"action": "%s wrote an article",
	},
	{
		"role": "Ornithologist",
		"kinds": [KIND_DEAD_BIRD, KIND_BIRD_NEST_REMNANTS],
		"action": "%s checked the bird's status in the region",
	},
	{
		"role": "Hydrologist",
		"kinds": [KIND_DRIED_GROUND],
		"action": "%s measured the drought in the soil",
	},
]

const CARDS := {
	KIND_BERRIES: {
		"icon": "🫐",
		"name": "Card: Berries",
		"stories": [
			"A handful of wild berries from the undergrowth. Sweet, tart, and shared among the crew.",
			"Foraged fruit from the parcel. Small rewards like these keep spirits up on a long walk.",
			"Ripe berries tucked along the trail — free food the forest still offers freely.",
		],
	},
	KIND_BIRD_NEST_REMNANTS: {
		"icon": "🪺",
		"name": "Card: Bird's nest remnants",
		"stories": [
			"Twigs and feathers beside a cut log — a nest torn down with the tree. Cutting where a protected bird species nests is forbidden.",
			"Nest scraps in the sawdust. Protected birds bred here; felling these trees breaks the law that guards them.",
			"What's left of a nest after the cut. Trees hosting protected bird species must not be cut — this one was.",
		],
	},
	KIND_DEAD_BIRD: {
		"icon": "🐦",
		"name": "Card: Dead bird",
		"stories": [
			"Roads are responsible for millions of dead birds each year. This bird was not from an invasive species.",
			"A small body by the asphalt. Roads kill millions of birds yearly; this one belonged here.",
			"Hunted animals are rarely left in nature — hunters take them. A bird lying here was probably not killed by hunting.",
		],
	},
	KIND_DEAD_BEAVER: {
		"icon": "🦫",
		"name": "Card: Dead beaver",
		"stories": [
			"Roads fragment wetlands and kill wildlife that must cross them. This beaver never made it home.",
			"Found beside the pavement. Habitat cut by roads leaves beavers with nowhere safe to go.",
			"Hunted animals are generally not left in the wild. A carcass abandoned here is unlikely to be from a hunt.",
		],
	},
	KIND_FORBIDDEN_CUT: {
		"icon": "🪓",
		"name": "Card: Forbidden cut",
		"stories": [
			"Fresh saw marks on a fallen log — cutting here is not allowed. The wood may have been destined for furniture.",
			"Illegal cut on protected ground. Timber like this often feeds the energy industry — pellets, fuel, biomass.",
			"Someone took timber they had no right to. Paper mills and pulp demand still pull trees from places like this.",
		],
	},
	KIND_ANIMAL_TRAP: {
		"icon": "🪤",
		"name": "Card: Animal trap",
		"stories": [
			"A hidden snare near the fence. Traps wound and kill without choosing carefully — native animals walk these paths too.",
			"Wire and bait tucked by the trees. Illegal traps wound more than they feed.",
			"A trap left along the barrier line. Unlike a legal hunt, what dies here is often left where it falls.",
		],
	},
	KIND_WOUNDED_ANIMAL: {
		"icon": "🩹",
		"name": "Card: Wounded animal",
		"stories": [
			"This animal carries an old injury — likely from a trap or a glancing shot. Hunting and traps leave survivors marked.",
			"Limping, wary, still alive. A clean hunt rarely leaves animals behind; wounds like this often come from traps.",
			"A wound that never healed cleanly. This is a native animal, not an invasive species — and still a target.",
		],
	},
	KIND_DRIED_GROUND: {
		"icon": "🏜️",
		"name": "Card: Dried ground",
		"stories": [
			"Cracked earth under a clear sky. Climate change may have an impact here, but it's nothing compared to countries of the South.",
			"The soil has split from drought. What we see here is a mild warning — southern countries already live with far worse.",
			"Parched ground where grass used to hold. Climate pressure shows, yet the burden falls hardest on the South.",
		],
	},
	KIND_FISHING_LINE: {
		"icon": "🎣",
		"name": "Card: Fishing line",
		"stories": [
			"Someone forgot this fishing line. Monofilament doesn't disappear — it can become a trap for animals.",
			"A tangle of clear line snagged near the water. Invisible once wet, it still cuts wings, fins, and feet for years.",
			"Discarded monofilament on the bank. It never truly goes away, and wildlife that swims or drinks here can die in it.",
		],
	},
	KIND_LEFTOVER_FOOD: {
		"icon": "🥪",
		"name": "Card: Leftover food",
		"stories": [
			"Scraps left on the ground. Animals that learn to associate humans with food may become bold — and bold animals are often euthanized.",
			"A half-eaten meal abandoned in the grass. Once wildlife expects handouts, conflict follows, and managers may kill the animals that approach people.",
			"Food waste where someone sat and left. Teaching animals that humans mean easy meals can cost them their lives.",
		],
	},
	KIND_DANDELION: {
		"icon": "🌼",
		"name": "Card: Dandelion",
		"stories": [
			"A bright yellow head in the grass — every part edible if you know it. Leaves bitter, roots roasted, clocks of seed waiting on the wind.",
			"Dandelion punches through compacted soil. What some call a weed is a first meal for bees and a free salad for those who look.",
			"Lion's tooth leaves and a hollow stem of milky sap. A common plant, and still a lesson: the parcel feeds more than timber.",
		],
	},
	KIND_NETTLE: {
		"icon": "🌿",
		"name": "Card: Nettle",
		"stories": [
			"Stinging hairs guard soft green leaves. Gloves or a careful pinch, then soup, tea, or fibre — nettle gives back what it takes.",
			"A patch of nettle means rich soil and butterflies nearby. The sting fades; the broth stays warm on a cold evening.",
			"Young shoots in spring are tender; older stalks toughen into cord. The botanist notes both the hazard and the gift.",
		],
	},
	KIND_RIBWORT_PLANTAIN: {
		"icon": "🌱",
		"name": "Card: Ribwort plantain",
		"stories": [
			"Ribbed leaves in a low rosette, a slender spike of seeds. Folk pressed them on cuts; the veins still run clear under the thumb.",
			"Plantain hugs paths and camp clearings. Where feet pass, this quiet green follows — a roadside healer in plain sight.",
			"Not the banana kind. Narrow leaves, parallel ribs, and a story of poultice and patience written in every leaf.",
		],
	},
	KIND_CLOVER: {
		"icon": "🍀",
		"name": "Card: Clover",
		"stories": [
			"Trifoliate leaves carpet the meadow. Roots fix nitrogen; flowers feed bees. Luck is optional — ecology is not.",
			"Pink or white heads nod in the breeze. Clover knits soil together and invites pollinators back after the cut.",
			"A soft carpet underfoot. Farmers once sowed it on purpose; here it volunteers where the ground still breathes.",
		],
	},
	KIND_PRIMROSE: {
		"icon": "🌸",
		"name": "Card: Primrose",
		"stories": [
			"Pale petals at the wood's edge — first colour after winter. Primrose marks damp banks and patient springs.",
			"A soft yellow cluster low to the ground. Old songs named it for early bloom; the botanist names the habitat it prefers.",
			"Leaves in a gentle rosette, flowers like a quiet lantern. Where primrose thrives, the understory still has room to speak.",
		],
	},
	KIND_WHITE_DEADNETTLE: {
		"icon": "🤍",
		"name": "Card: White deadnettle",
		"stories": [
			"Looks like nettle, stings like nothing. White hooded flowers hide nectar for long-tongued bees — a mimic without the bite.",
			"Square stem, soft leaves, no sting. Deadnettle teaches looking twice: resemblance is not identity.",
			"A white bloom in the verge. Children once sucked the sweet base of each flower; the botanist counts the visitors instead.",
		],
	},
	KIND_YARROW: {
		"icon": "🌾",
		"name": "Card: Yarrow",
		"stories": [
			"Feathery leaves and a flat cluster of tiny flowers. Achilles' herb — named for wounds, used for centuries along trails.",
			"Yarrow holds dry banks and meadow edges. Aromatic, tough, and always ready with a story of field medicine.",
			"White or pink umbels above fern-like foliage. Soldiers and shepherds knew it; the parcel still grows it without asking.",
		],
	},
	KIND_EUROPEAN_ROBIN: {
		"icon": "🧡",
		"name": "Card: European robin",
		"stories": [
			"A flash of orange breast on a low branch. Robins follow diggers and campers alike — bold, territorial, never far from cover.",
			"Thin song from the understory. The robin holds a winter territory too; this parcel is claimed year-round.",
			"Perched close, unafraid. A European robin treats people as noisy wild boars that turn soil — and that is a compliment.",
		],
	},
	KIND_COMMON_BLACKBIRD: {
		"icon": "⚫",
		"name": "Card: Common blackbird",
		"stories": [
			"A black cock with a yellow bill turns leaf litter. Blackbirds own the dawn chorus here when the wood still breathes.",
			"Fluting phrases from a high perch. The common blackbird sings as if the cut never came — then drops to feed on the edge.",
			"A female in brown slips through the brambles. Same species, quieter coat; both know every worm under this soil.",
		],
	},
	KIND_GREAT_TIT: {
		"icon": "🟡",
		"name": "Card: Great tit",
		"stories": [
			"Black cap, white cheeks, yellow belly — a great tit scolds from the oak. The loudest small voice in the canopy.",
			"Tee-cher, tee-cher from the crown. Great tits invent new calls; this one has already named the camp.",
			"A bold acrobat among the twigs. Where insects hide under bark, the great tit finds breakfast first.",
		],
	},
	KIND_BLUE_TIT: {
		"icon": "💙",
		"name": "Card: Blue tit",
		"stories": [
			"A blue crown and a yellow vest hang upside-down on a twig. Blue tits empty caterpillar nests one leaf at a time.",
			"High, thin calls stitch the canopy together. A blue tit pair may raise a dozen chicks when the oaks leaf out right.",
			"Tiny, restless, electric blue. Blue tits prefer cavities and old wood — another reason standing trees still matter.",
		],
	},
	KIND_WOOD_PIGEON: {
		"icon": "🕊️",
		"name": "Card: Wood pigeon",
		"stories": [
			"A heavy clap of wings from the canopy — wood pigeon leaving late. White neck patches flash like signals in the green.",
			"Coo-COO-coo, coo-coo from deep cover. Wood pigeons eat buds, grain, and mast; a full belly keeps them circling the parcel.",
			"Large, soft grey, always watching. When the wood pigeon flushes, half the forest knows something moved.",
		],
	},
	KIND_EURASIAN_JAY: {
		"icon": "🔵",
		"name": "Card: Eurasian jay",
		"stories": [
			"A harsh scream and a blue wing-flash — jay on watch. They bury acorns and forget just enough to plant the next oaks.",
			"Pink-brown body, bold black moustache. The Eurasian jay is the forest's alarm: one call and every deer freezes.",
			"Hiding nuts along the ridge. Jays reshape woods one forgotten acorn at a time; this ridge may owe them trees.",
		],
	},
	KIND_SONG_THRUSH: {
		"icon": "🎵",
		"name": "Card: Song thrush",
		"stories": [
			"Phrases repeated two or three times from a high song-post. The song thrush writes the same line until the wood learns it.",
			"Spotted breast among the leaf litter, hunting snails. An anvil stone nearby still holds broken shells from last week.",
			"Clear, loud, methodical. Where blackbirds flute, the song thrush drills — and the parcel answers in echo.",
		],
	},
	KIND_BLACKCAP: {
		"icon": "🎩",
		"name": "Card: Blackcap",
		"stories": [
			"A neat black cap and a rich warble from dense scrub. Blackcaps favour thickets the cut has not yet opened.",
			"Often called the northern nightingale. This blackcap's song pours from cover without ever showing the singer.",
			"Grey body, jet crown, restless in the hedge. Migrants and residents share these lanes when berries still hang.",
		],
	},
	KIND_GREEN_WOODPECKER: {
		"icon": "💚",
		"name": "Card: Green woodpecker",
		"stories": [
			"A laughing call rolls across the clearing — yaffle on the move. Green woodpeckers hunt ants on the ground more than bark.",
			"Olive green, red crown, undulating flight. The green woodpecker needs open lawns and old trees; both still linger here.",
			"Strong bill, longer tongue, ant hills in its sights. Hearing one means the meadow edge still feeds the wood.",
		],
	},
}


static func pick_detail(kind: String, rng: RandomNumberGenerator) -> String:
	var stories: Array = CARDS[kind].stories
	return stories[rng.randi() % stories.size()]


## Empty string if any role can find this kind; otherwise the required role msgid.
static func required_role(kind: String) -> String:
	return str(REQUIRED_ROLES.get(kind, ""))


## Journal msgid for a discovered kind, or empty if it is not journalled.
static func journal_msgid(kind: String) -> String:
	return str(JOURNAL_MSGIDS.get(kind, ""))


## True when Solve can attempt a response for this evidence kind.
static func is_solvable(kind: String) -> bool:
	if kind.is_empty() or kind == KIND_BERRIES \
			or PLANT_KINDS.has(kind) or BIRD_SPECIES_KINDS.has(kind):
		return false
	return CARDS.has(kind)


## Picks a random bird-species kind id (for flying birds / tree finds).
static func pick_bird_species(rng: RandomNumberGenerator) -> String:
	return BIRD_SPECIES_KINDS[rng.randi() % BIRD_SPECIES_KINDS.size()]


## Builds action dicts `{msgid, camper}` for roles present in `role_holders`
## (role msgid → camper display name) that match `kind`.
static func solve_actions_for(kind: String, role_holders: Dictionary) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if not is_solvable(kind):
		return actions
	for rule in SOLVE_RULES:
		var role: String = rule.role
		if not role_holders.has(role):
			continue
		var kinds: Array = rule.kinds
		if not kinds.has(kind):
			continue
		actions.append({
			"msgid": rule.action,
			"camper": str(role_holders[role]),
		})
	return actions


## Stores English msgids so the card can be re-localized when the UI draws.
static func make_item(kind: String, detail: String = "") -> Dictionary:
	var def: Dictionary = CARDS[kind]
	return {
		"icon": def.icon,
		"name": def.name,
		"detail": detail if not detail.is_empty() else def.stories[0],
		"kind": "card",
		"id": kind,
	}


## Returns a copy with name/detail passed through TranslationServer.
static func localize(item: Dictionary) -> Dictionary:
	return {
		"icon": item.icon,
		"name": TranslationServer.translate(item.name),
		"detail": TranslationServer.translate(item.detail) if item.has("detail") else "",
		"kind": item.get("kind", "card"),
		"id": item.get("id", ""),
	}
