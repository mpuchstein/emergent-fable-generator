class_name LocationData
extends RefCounted

const LOCATIONS: Array[String] = ["Den", "Meadow", "River", "Grove", "Market"]

## static per-location properties. "forage_pool_max"/"forage_regen"/"forage_yield"
## are only meaningful where has_forage is true; current pool level lives in
## World.location_state (a mutable runtime copy), not here.
const LOCATION_DEFS := {
	"Den": {"has_forage": false, "rest_bonus": 1.5, "social_bonus": 0.0},
	## forage_regen must roughly cover aggregate Hunger decay across the whole
	## roster (8 agents x World.NEED_DECAY 1.5/tick =~ 12/tick) or Meadow is a
	## structural famine regardless of any per-agent starvation threshold — this
	## was diagnosed empirically (an agent locked at Hunger=0 for 220+ ticks
	## while standing at the food source) at the old regen of 3.0.
	"Meadow": {
		"has_forage": true, "forage_pool_max": 140.0, "forage_regen": 11.0, "forage_yield": 18.0,
		"rest_bonus": 0.0, "social_bonus": 0.0,
	},
	"River": {"has_forage": false, "rest_bonus": 0.5, "social_bonus": 0.2},
	"Grove": {"has_forage": false, "rest_bonus": 0.0, "social_bonus": 1.3},
	"Market": {"has_forage": false, "rest_bonus": 0.0, "social_bonus": 1.0, "boast_bonus": 1.5},
}
