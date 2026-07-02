class_name ActionResolver
extends RefCounted

## which trait most strongly (positively or negatively) shaped this action choice —
## used by the Chronicle to pick the right sentence flavor. "default" if none apply.
static func _dominant_trait(agent: Agent, action: String) -> String:
	var best_trait := "default"
	var best_abs := 0.0
	for t in agent.traits:
		var w: float = TraitData.TRAIT_ACTION_WEIGHTS.get(t, {}).get(action, 0.0)
		if absf(w) > best_abs:
			best_abs = absf(w)
			best_trait = t
	return best_trait

static func _pick_target(agent: Agent, present: Array[Agent], prefer_highest_affinity: bool) -> Agent:
	var best: Agent = present[0]
	var best_affinity := agent.get_relationship(best.id)
	for other in present:
		var a := agent.get_relationship(other.id)
		if (prefer_highest_affinity and a > best_affinity) or (not prefer_highest_affinity and a < best_affinity):
			best_affinity = a
			best = other
	return best

static func _base_event(agent: Agent, action: String) -> Dictionary:
	return {
		"actor": agent.species,
		"target": "",
		"location": agent.location,
		"action": action,
		"outcome": "success",
		"dominant_trait": _dominant_trait(agent, action),
		"actor_poss": "their",
		"relationship_delta": 0.0,
	}

static func execute(agent: Agent, action: String, world: World) -> Dictionary:
	var event := _base_event(agent, action)
	match action:
		"Forage":
			_resolve_forage(agent, world, event)
		"Rest":
			_resolve_rest(agent, world, event)
		"Socialize":
			_resolve_socialize(agent, world, event)
		"Share":
			_resolve_share(agent, world, event)
		"Steal":
			_resolve_steal(agent, world, event)
		"Confront":
			_resolve_confront(agent, world, event)
		"Boast":
			_resolve_boast(agent, world, event)
		"Travel":
			_resolve_travel(agent, world, event)
		_:
			event["outcome"] = "failure"
	return event

static func _resolve_forage(agent: Agent, world: World, event: Dictionary) -> void:
	var loc: Dictionary = world.location_state[agent.location]
	var amount := minf(loc.get("forage_yield", 0.0), loc.get("forage_pool", 0.0))
	if amount > 0.0:
		agent.adjust_need("Hunger", amount)
		loc["forage_pool"] -= amount
		event["outcome"] = "success"
	else:
		event["outcome"] = "failure"

static func _resolve_rest(agent: Agent, world: World, event: Dictionary) -> void:
	var loc: Dictionary = world.location_state[agent.location]
	agent.adjust_need("Rest", 20.0 * (1.0 + loc.get("rest_bonus", 0.0)))
	event["outcome"] = "success"

static func _resolve_socialize(agent: Agent, world: World, event: Dictionary) -> void:
	var present := world.agents_at(agent.location, agent)
	if present.is_empty():
		## a lesser substitute for real company, but real enough that visiting an
		## empty social spot isn't a wasted trip — without this, a location whose
		## only draw is "other agents" can never be the first agent's destination,
		## since nobody's ever there to be social with
		agent.adjust_need("Social", 6.0)
		event["outcome"] = "solo"
		return
	var target := _pick_target(agent, present, true)
	event["target"] = target.species
	agent.adjust_need("Social", 15.0)
	target.adjust_need("Social", 15.0)
	agent.adjust_relationship(target.id, 5.0)
	target.adjust_relationship(agent.id, 5.0)
	event["relationship_delta"] = 5.0
	event["outcome"] = "success"

static func _resolve_share(agent: Agent, world: World, event: Dictionary) -> void:
	var present := world.agents_at(agent.location, agent)
	var target := _pick_target(agent, present, true)
	event["target"] = target.species
	if agent.needs["Hunger"] >= 10.0:
		agent.adjust_need("Hunger", -10.0)
		target.adjust_need("Hunger", 10.0)
		agent.adjust_relationship(target.id, 10.0)
		target.adjust_relationship(agent.id, 10.0)
		event["relationship_delta"] = 10.0
		event["outcome"] = "success"
	else:
		event["outcome"] = "failure"

## worth stealing from, not just disliked — picking by lowest affinity alone
## can lock an agent onto a target that's already been picked clean
static func _pick_steal_target(present: Array[Agent]) -> Agent:
	var best: Agent = present[0]
	for other in present:
		if other.needs["Hunger"] > best.needs["Hunger"]:
			best = other
	return best

static func _resolve_steal(agent: Agent, world: World, event: Dictionary) -> void:
	var present := world.agents_at(agent.location, agent)
	var target := _pick_steal_target(present)
	event["target"] = target.species
	var amount := minf(15.0, target.needs["Hunger"])
	if amount > 0.0:
		target.adjust_need("Hunger", -amount)
		agent.adjust_need("Hunger", amount)
		target.adjust_relationship(agent.id, -25.0)
		agent.adjust_relationship(target.id, -5.0)
		event["relationship_delta"] = -25.0
		event["outcome"] = "success"
	else:
		event["outcome"] = "failure"

static func _resolve_confront(agent: Agent, world: World, event: Dictionary) -> void:
	var present := world.agents_at(agent.location, agent)
	var target := _pick_target(agent, present, false)
	event["target"] = target.species
	var actor_score := (1.0 if agent.has_trait("Brave") else 0.0) - (1.0 if agent.has_trait("Timid") else 0.0) + world.rng.randf() * 0.5
	var target_score := (1.0 if target.has_trait("Brave") else 0.0) - (1.0 if target.has_trait("Timid") else 0.0) + world.rng.randf() * 0.5
	agent.adjust_relationship(target.id, -15.0)
	target.adjust_relationship(agent.id, -15.0)
	event["relationship_delta"] = -15.0
	if actor_score >= target_score:
		agent.adjust_need("Ambition", 15.0)
		target.adjust_need("Rest", -10.0)
		event["outcome"] = "success"
	else:
		target.adjust_need("Ambition", 10.0)
		agent.adjust_need("Rest", -10.0)
		event["outcome"] = "failure"

static func _resolve_boast(agent: Agent, world: World, event: Dictionary) -> void:
	var present := world.agents_at(agent.location, agent)
	agent.adjust_need("Ambition", 12.0)
	if present.is_empty():
		event["outcome"] = "failure"
		return
	for other in present:
		other.adjust_relationship(agent.id, 3.0 if other.has_trait("Vain") else -2.0)
	event["outcome"] = "success"

static func _resolve_travel(agent: Agent, world: World, event: Dictionary) -> void:
	var origin := agent.location
	var destination := world.best_travel_destination(agent)
	agent.location = destination
	event["location"] = origin
	event["target"] = destination
	event["outcome"] = "success"
