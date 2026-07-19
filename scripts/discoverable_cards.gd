class_name DiscoverableCards
## Hidden evidence cards scattered on the parcel. Campers only collect them
## by finishing an inspect task on or next to the cell.
##
## All `name` and `stories` strings are translation msgids — keep them in
## i18n/translations.csv (en/fr) and display via localize() or tr().

const KIND_DEAD_BIRD := "dead_bird"
const KIND_DEAD_BEAVER := "dead_beaver"
const KIND_FORBIDDEN_CUT := "forbidden_cut"
const KIND_ANIMAL_TRAP := "animal_trap"
const KIND_WOUNDED_ANIMAL := "wounded_animal"

const CARDS := {
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
}


static func pick_detail(kind: String, rng: RandomNumberGenerator) -> String:
	var stories: Array = CARDS[kind].stories
	return stories[rng.randi() % stories.size()]


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
