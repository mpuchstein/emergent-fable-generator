class_name TraitData
extends RefCounted

const VALID_TRAITS: Array[String] = [
	"Greedy", "Kind", "Vain", "Cunning", "Timid", "Brave", "Proud", "Loyal",
]

## trait -> action -> score bonus/penalty applied in UtilityScorer.score_action()
const TRAIT_ACTION_WEIGHTS := {
	"Greedy": {"Steal": 1.5, "Forage": 1.2, "Share": -1.5},
	"Kind": {"Share": 1.5, "Socialize": 0.5, "Steal": -1.5, "Confront": -1.0},
	"Vain": {"Boast": 1.8, "Socialize": 0.3, "Share": -0.5},
	"Cunning": {"Steal": 1.2, "Confront": 0.5, "Boast": 0.3},
	"Timid": {"Confront": -1.8, "Rest": 0.5, "Travel": 0.3},
	"Brave": {"Confront": 1.5, "Travel": 0.2},
	"Proud": {"Boast": 1.2, "Share": -0.8, "Confront": 0.6},
	"Loyal": {"Share": 1.0, "Socialize": 0.5, "Steal": -1.0},
}

## fixed thematic roster: species -> 2 traits. Small, closed cast — Aesop-style archetypes.
const SPECIES_TRAITS := {
	"Fox": ["Cunning", "Greedy"],
	"Owl": ["Proud", "Vain"],
	"Hare": ["Timid", "Kind"],
	"Bear": ["Brave", "Greedy"],
	"Crow": ["Cunning", "Vain"],
	"Mole": ["Timid", "Loyal"],
	"Badger": ["Brave", "Loyal"],
	"Wren": ["Kind", "Proud"],
}
