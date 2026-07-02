class_name UtilityScorer
extends RefCounted

const ACTIONS: Array[String] = [
	"Forage", "Rest", "Socialize", "Confront", "Share", "Steal", "Boast", "Travel",
]

## how strongly each action satisfies its associated need's deficit (100 - current)
static func _need_deficit_term(agent: Agent, action: String) -> float:
	match action:
		"Forage": return (100.0 - agent.needs["Hunger"]) * 0.04
		"Rest": return (100.0 - agent.needs["Rest"]) * 0.04
		"Socialize": return (100.0 - agent.needs["Social"]) * 0.03
		"Share": return (100.0 - agent.needs["Social"]) * 0.015
		"Boast": return (100.0 - agent.needs["Ambition"]) * 0.03
		"Confront": return (100.0 - agent.needs["Ambition"]) * 0.02
		"Steal": return (100.0 - agent.needs["Hunger"]) * 0.02 + (100.0 - agent.needs["Ambition"]) * 0.01
		"Travel": return 0.05 ## small constant wanderlust so agents don't get stuck
		_: return 0.0

static func _trait_term(agent: Agent, action: String) -> float:
	var s := 0.0
	for t in agent.traits:
		s += TraitData.TRAIT_ACTION_WEIGHTS.get(t, {}).get(action, 0.0)
	return s

## bonus/penalty from the affinity of other agents present at the agent's location
static func _relationship_term(agent: Agent, action: String, world: World) -> float:
	var present := world.agents_at(agent.location, agent)
	if present.is_empty():
		return 0.0
	match action:
		"Confront":
			var lowest := 0.0
			for other in present:
				lowest = minf(lowest, agent.get_relationship(other.id))
			return -lowest / 40.0 ## rivalry (negative affinity) makes Confront more appealing
		"Share", "Socialize":
			var highest := 0.0
			for other in present:
				highest = maxf(highest, agent.get_relationship(other.id))
			return highest / 40.0
		"Steal":
			var lowest2 := 0.0
			for other in present:
				lowest2 = minf(lowest2, agent.get_relationship(other.id))
			return -lowest2 / 60.0
		_:
			return 0.0

## Location bonuses (rest_bonus/social_bonus/boast_bonus) previously only fed
## World._travel_desirability — Travel promised they mattered, but Rest/
## Socialize/Share/Boast never actually scored higher for being at the
## location that promise pointed to. Result, confirmed empirically: 86% of all
## agent-time spent at the Meadow, Grove visited 0% over 500 ticks — nothing
## ever converted the travel pull into a reason to arrive somewhere and stay.
## Mirroring the same bonus fields here closes that loop.
const _LOCATION_BONUS_WEIGHT := 0.5

static func _opportunity_term(agent: Agent, action: String, world: World) -> float:
	var loc: Dictionary = world.location_state.get(agent.location, {})
	match action:
		"Forage":
			var max_pool: float = loc.get("forage_pool_max", 1.0)
			return (loc.get("forage_pool", 0.0) / max_pool) * 0.5
		"Rest":
			return loc.get("rest_bonus", 0.0) * _LOCATION_BONUS_WEIGHT
		"Socialize", "Share":
			return loc.get("social_bonus", 0.0) * _LOCATION_BONUS_WEIGHT
		"Boast":
			var audience := 0.5 if not world.agents_at(agent.location, agent).is_empty() else 0.0
			return audience + loc.get("boast_bonus", 0.0) * _LOCATION_BONUS_WEIGHT
		"Travel":
			return world.best_travel_score(agent)
		_:
			return 0.0

static func is_feasible(agent: Agent, action: String, world: World) -> bool:
	match action:
		"Forage":
			var loc: Dictionary = world.location_state.get(agent.location, {})
			return loc.get("has_forage", false) and loc.get("forage_pool", 0.0) > 0.0
		"Rest", "Boast", "Travel", "Socialize":
			## Socialize alone falls back to quiet reflection (action_resolver.gd)
			## rather than being infeasible — a location whose only draw is other
			## agents can never be anyone's first destination if going there solo
			## is a hard no; see the location-occupancy note on _opportunity_term.
			return true
		"Confront":
			return not world.agents_at(agent.location, agent).is_empty()
		"Share":
			## can't give what you don't have — without this an agent can get
			## stuck endlessly "choosing" to share while too hungry to afford it
			return agent.needs["Hunger"] >= 10.0 and not world.agents_at(agent.location, agent).is_empty()
		"Steal":
			## without this an agent can get stuck endlessly "choosing" to steal
			## from someone already picked clean — scoring rewards the actor's own
			## hunger regardless of whether the attempt could ever succeed
			for other in world.agents_at(agent.location, agent):
				if other.needs["Hunger"] > 0.0:
					return true
			return false
		_:
			return false

const REPETITION_PENALTY := 0.4

## once needs/relationships hit a steady state, an agent can lock onto the same
## optimal action forever — this grows a penalty the longer `action` has been
## repeated, so a stable rivalry/friendship still recurs but isn't a frozen
## one-line loop every single tick.
static func _repetition_penalty(agent: Agent, action: String) -> float:
	if action == agent.last_action:
		return agent.action_streak * REPETITION_PENALTY
	return 0.0

static func score_action(agent: Agent, action: String, world: World) -> float:
	if not is_feasible(agent, action, world):
		return -INF
	return _need_deficit_term(agent, action) \
		+ _trait_term(agent, action) \
		+ _relationship_term(agent, action, world) \
		+ _opportunity_term(agent, action, world) \
		- _repetition_penalty(agent, action)

static func pick_action(agent: Agent, world: World, rng: RandomNumberGenerator) -> String:
	var best := "Rest"
	var best_score := -INF
	for action in ACTIONS:
		var s := score_action(agent, action, world) + rng.randf() * 0.01 ## tie-break jitter
		if s > best_score:
			best_score = s
			best = action
	return best
