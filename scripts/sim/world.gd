class_name World
extends RefCounted

signal event_happened(event: Dictionary)
signal day_ended(day: int, day_events: Array)

const TICKS_PER_DAY := 25
const NEED_DECAY := 1.5

## relationships were a pure ratchet before this: Confront/Steal could only push
## affinity down and Share/Socialize could only push it up, with nothing ever
## pulling back toward neutral. Slow on purpose — a single day's rivalry should
## still dominate same-day behavior; only sustained silence between two agents
## should let an old grudge or friendship actually fade.
const RELATIONSHIP_DRIFT := 0.08

## consecutive ticks of zero Hunger before an agent starves — deliberately high
## (most of a day) so death is a rare consequence of sustained neglect or being
## preyed on, not routine background noise
const STARVATION_LIMIT := 20

## how much of a dead agent's relationships (both directions) carry over to
## their successor — reputation outliving the individual, diluted, not erased
const INHERITANCE_FACTOR := 0.35

var agents: Array[Agent] = []
var location_state: Dictionary = {} ## location name -> mutable copy of LocationData.LOCATION_DEFS entry
var rng := RandomNumberGenerator.new()

var tick_count := 0
var day_count := 0
var _day_events: Array = []

func _init(p_seed: int = -1) -> void:
	if p_seed >= 0:
		rng.seed = p_seed
	else:
		rng.randomize()
	_init_locations()
	_init_roster()

func _init_locations() -> void:
	for loc_name in LocationData.LOCATIONS:
		var state: Dictionary = LocationData.LOCATION_DEFS[loc_name].duplicate()
		if state.get("has_forage", false):
			state["forage_pool"] = state["forage_pool_max"]
		location_state[loc_name] = state

func _init_roster() -> void:
	var species_names := TraitData.SPECIES_TRAITS.keys()
	for i in species_names.size():
		var species: String = species_names[i]
		var traits: Array[String] = []
		traits.assign(TraitData.SPECIES_TRAITS[species])
		var agent := Agent.new("%s_%d" % [species, i], species, traits, rng)
		agent.location = LocationData.LOCATIONS[i % LocationData.LOCATIONS.size()]
		agents.append(agent)
	for a in agents:
		for b in agents:
			if a != b:
				a.relationships[b.id] = 0.0

func agents_at(location_name: String, exclude: Agent = null) -> Array[Agent]:
	var result: Array[Agent] = []
	for a in agents:
		if a.location == location_name and a != exclude:
			result.append(a)
	return result

## Travel's coefficients are deliberately weaker than the matching in-place
## action's own need_deficit_term in UtilityScorer (e.g. Forage's 0.04) — this
## constant enforces that gap. Without it, "travel toward the place that helps"
## can outscore "do the thing right here," and agents chase a moving target
## forever instead of ever committing to Forage/Rest/Boast once they arrive.
const _TRAVEL_DESIRABILITY_SCALE := 1.0

## how appealing it is for `agent` to travel to each other location, given need deficits
func _travel_desirability(agent: Agent, loc_name: String) -> float:
	if loc_name == agent.location:
		return 0.0
	var loc: Dictionary = location_state[loc_name]
	var d := 0.0
	if loc.get("has_forage", false):
		d += (100.0 - agent.needs["Hunger"]) * 0.05
	d += (100.0 - agent.needs["Rest"]) * 0.03 * loc.get("rest_bonus", 0.0)
	d += (100.0 - agent.needs["Social"]) * 0.03 * loc.get("social_bonus", 0.0)
	d += (100.0 - agent.needs["Ambition"]) * 0.02 * loc.get("boast_bonus", 0.0)
	return d * _TRAVEL_DESIRABILITY_SCALE

func best_travel_score(agent: Agent) -> float:
	var best := 0.0
	for loc_name in LocationData.LOCATIONS:
		best = maxf(best, _travel_desirability(agent, loc_name))
	return best

## always returns a *different* location — Travel is a decision to move, so it
## shouldn't be able to resolve to a no-op "travel to where you already are"
func best_travel_destination(agent: Agent) -> String:
	var best_loc := agent.location
	var best_score := -INF
	for loc_name in LocationData.LOCATIONS:
		if loc_name == agent.location:
			continue
		var d := _travel_desirability(agent, loc_name)
		if d > best_score:
			best_score = d
			best_loc = loc_name
	return best_loc

func _decay_needs() -> void:
	for a in agents:
		for key in Agent.NEED_KEYS:
			a.adjust_need(key, -NEED_DECAY)

func _regen_locations() -> void:
	for loc_name in LocationData.LOCATIONS:
		var loc: Dictionary = location_state[loc_name]
		if loc.get("has_forage", false):
			loc["forage_pool"] = clampf(loc["forage_pool"] + loc["forage_regen"], 0.0, loc["forage_pool_max"])

func _drift_relationships() -> void:
	for a in agents:
		for other_id in a.relationships.keys():
			a.relationships[other_id] = move_toward(a.relationships[other_id], 0.0, RELATIONSHIP_DRIFT)

## a dead agent's replacement — same species/traits (species defines the fixed
## archetype), fresh needs, but not a stranger: they inherit a diluted share of
## the dead agent's relationships in both directions, so reputation outlives
## the individual without simply repeating them
func _succeed(dead: Agent) -> Agent:
	var successor := Agent.new("%s_g%d_%d" % [dead.species, dead.generation + 1, tick_count], dead.species, dead.traits.duplicate(), rng)
	successor.generation = dead.generation + 1
	successor.location = "Den"
	for a in agents:
		if a == dead:
			continue
		var inherited := dead.get_relationship(a.id) * INHERITANCE_FACTOR
		successor.relationships[a.id] = inherited
		a.relationships[successor.id] = inherited
	return successor

func _die_flavor_trait(agent: Agent) -> String:
	for t in ["Greedy", "Proud", "Timid"]:
		if agent.has_trait(t):
			return t
	return "default"

## checks the day's starvation streaks and replaces anyone who's crossed
## STARVATION_LIMIT — run after actions resolve so a last-second successful
## Forage can still save an agent that tick
func _process_mortality() -> void:
	var died: Array[Agent] = []
	for a in agents:
		if a.needs["Hunger"] <= 0.0:
			a.starved_ticks += 1
		else:
			a.starved_ticks = 0
		if a.starved_ticks >= STARVATION_LIMIT:
			died.append(a)
	for dead in died:
		var death_event := {
			"actor": dead.species, "target": "", "location": dead.location, "action": "Die",
			"outcome": "success", "dominant_trait": _die_flavor_trait(dead),
			"actor_poss": "their", "relationship_delta": 0.0, "tick": tick_count,
		}
		_day_events.append(death_event)
		event_happened.emit(death_event)

		var successor := _succeed(dead)
		var idx := agents.find(dead)
		agents[idx] = successor

		var birth_event := {
			"actor": successor.species, "target": "", "location": successor.location, "action": "Succeed",
			"outcome": "success", "dominant_trait": "default",
			"actor_poss": "their", "relationship_delta": 0.0, "tick": tick_count,
		}
		_day_events.append(birth_event)
		event_happened.emit(birth_event)

## Array.shuffle() draws from Godot's *global* RNG, not this World's seeded
## `rng` — using it here would make World.new(seed) not actually reproducible
## despite taking a seed. Plain seeded Fisher-Yates instead.
func _shuffled(arr: Array) -> Array:
	var result := arr.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = result[i]
		result[i] = result[j]
		result[j] = tmp
	return result

func tick() -> void:
	_decay_needs()
	_regen_locations()
	_drift_relationships()
	## fixed iteration order gave whoever's first (always Fox, always last Wren)
	## permanent first dibs on a shared, contested resource like the Meadow's
	## forage pool — diagnosed via a real agent (Wren) locked at Hunger=0 for
	## 220+ consecutive ticks while standing at the food source. `agents` itself
	## stays in stable insertion order (nothing else depends on turn order); only
	## the per-tick acting order is randomized.
	for agent in _shuffled(agents):
		var action := UtilityScorer.pick_action(agent, self, rng)
		if action == agent.last_action:
			agent.action_streak += 1
		else:
			agent.last_action = action
			agent.action_streak = 0
		var event := ActionResolver.execute(agent, action, self)
		event["tick"] = tick_count
		_day_events.append(event)
		event_happened.emit(event)
	_process_mortality()
	tick_count += 1
	if tick_count % TICKS_PER_DAY == 0:
		day_count += 1
		day_ended.emit(day_count, _day_events)
		_day_events = []
