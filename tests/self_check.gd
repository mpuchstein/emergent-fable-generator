extends SceneTree

## Headless self-check for the simulation core. Run with:
##   godot --headless --script res://tests/self_check.gd
## Asserts the invariants that matter: needs stay clamped, the shared forage
## pool never goes negative, the roster size and agent generations stay sane
## through any deaths/successions, the population actually spreads across
## locations instead of clustering at one (the bug the user caught by
## watching the game — no individual-line or per-need assertion here would
## ever have caught it; only tallying the aggregate does), the chronicle
## produces varied non-empty lines, and at least one day-moral synthesizes
## over a multi-day run.

func _init() -> void:
	var world := World.new(12345)
	var chronicle := Chronicle.new()
	var lines: Array[String] = []
	var unique := {}
	var morals: Array[String] = []
	var roster_size := world.agents.size()
	var counters := {"deaths": 0} ## Dictionary, not a bare int — see note in _check_forced_mortality
	var location_ticks := {}
	for loc in LocationData.LOCATIONS:
		location_ticks[loc] = 0

	world.event_happened.connect(func(ev: Dictionary) -> void:
		var line := chronicle.event_to_sentence(ev)
		assert(line != "")
		lines.append(line)
		unique[line] = true
		if ev["action"] == "Die":
			counters["deaths"] += 1
	)
	world.day_ended.connect(func(day: int, day_events: Array) -> void:
		var moral := chronicle.synthesize_moral(day_events)
		if moral != "":
			morals.append(moral)
	)

	for i in range(1000): # ~40 sim days at 25 ticks/day — long enough to plausibly exercise mortality
		world.tick()
		assert(world.agents.size() == roster_size) ## deaths must be replaced 1:1, never just removed
		for a in world.agents:
			assert(a.generation >= 1)
			for v in a.needs.values():
				assert(v >= 0.0 and v <= 100.0)
			location_ticks[a.location] += 1
		for loc in world.location_state.values():
			if loc.has("forage_pool"):
				assert(loc["forage_pool"] >= 0.0)
				assert(loc["forage_pool"] <= loc["forage_pool_max"])

	assert(lines.size() >= 50)
	assert(unique.size() >= 20)
	assert(morals.size() >= 1)

	var total_agent_ticks: int = roster_size * 1000
	for loc in LocationData.LOCATIONS:
		var share: float = float(location_ticks[loc]) / total_agent_ticks
		assert(share > 0.0) ## every location must be reachable at all — no cold-start deadlock
		assert(share < 0.6) ## no single location may dominate the whole population's time
	print("self_check OK: %d lines (%d distinct), %d morals, %d deaths over %d ticks" % [lines.size(), unique.size(), morals.size(), counters["deaths"], 1000])

	_check_forced_mortality()
	_check_lineage_moral()
	quit()

## the balanced economy rarely-to-never produces a natural starvation death
## (confirmed empirically: 0 deaths across 6 seeds x 40 sim days each) — that's
## a property of the tuning, not evidence the mechanism works. This forces one
## agent to starve regardless of what it does, to verify Die -> Succeed
## directly: roster size preserved, generation incremented, reputation carried
## over via inheritance, independent of whether nature ever triggers it.
func _check_forced_mortality() -> void:
	var world := World.new(12345)
	var chronicle := Chronicle.new()
	var roster_size := world.agents.size()
	var victim: Agent = world.agents[0]
	var victim_species := victim.species
	var victim_generation := victim.generation
	# give the victim a rival relationship worth inheriting
	var rival: Agent = world.agents[1]
	victim.relationships[rival.id] = -60.0
	rival.relationships[victim.id] = -60.0

	## a bare bool reassigned inside a lambda is captured by value in GDScript —
	## the reassignment never reaches this outer scope. A Dictionary mutates by
	## reference instead, same pattern as `lines`/`morals` above.
	var seen := {"die": false, "succeed": false}
	world.event_happened.connect(func(ev: Dictionary) -> void:
		if ev["actor"] == victim_species and ev["action"] == "Die":
			seen["die"] = true
			assert(chronicle.event_to_sentence(ev) != "")
		if ev["actor"] == victim_species and ev["action"] == "Succeed" and seen["die"]:
			seen["succeed"] = true
			assert(chronicle.event_to_sentence(ev) != "")
	)

	## drive mortality directly rather than through tick() — going through tick()
	## lets the victim's own successful Forage/a friend's Share undo the forced
	## 0 before _process_mortality ever reads it, which defeats the point of
	## forcing it in the first place
	for i in World.STARVATION_LIMIT + 2:
		victim.needs["Hunger"] = 0.0
		world._process_mortality()
		if seen["succeed"]:
			break

	assert(seen["die"])
	assert(seen["succeed"])
	assert(world.agents.size() == roster_size)
	var successor: Agent = world.agents.filter(func(a): return a.species == victim_species)[0]
	assert(successor.generation == victim_generation + 1)
	assert(absf(successor.get_relationship(rival.id)) > 0.0) ## reputation inherited, not reset to neutral
	assert(absf(successor.get_relationship(rival.id)) < 60.0) ## but diluted, not copied verbatim
	print("forced_mortality_check OK: generation %d -> %d, inherited relationship %.1f" % [victim_generation, successor.generation, successor.get_relationship(rival.id)])

## a death within a single day only ever gets the generic "Die" moral —
## the lineage-aware moral ("the third Fox in a row to die at the Market")
## requires the same species dying at the same location across *multiple*
## deaths, which forces three separate successions in sequence and checks
## the resulting moral text, not just that a moral fired.
func _check_lineage_moral() -> void:
	var world := World.new(12345)
	var chronicle := Chronicle.new()
	var species: String = world.agents[0].species
	var target_location := "Market"
	var death_count := {"n": 0}

	world.event_happened.connect(func(ev: Dictionary) -> void:
		if ev["actor"] == species and ev["action"] == "Die":
			death_count["n"] += 1
	)

	for death_num in 3:
		var current: Agent = world.agents.filter(func(a): return a.species == species)[0]
		current.location = target_location
		for i in World.STARVATION_LIMIT + 2:
			current.needs["Hunger"] = 0.0
			world._process_mortality()
			if death_count["n"] > death_num:
				break

	assert(death_count["n"] == 3)
	var moral := chronicle.synthesize_moral(world._day_events)
	assert(moral.contains("third"))
	assert(moral.contains(target_location))
	assert(not moral.contains(species + "s ")) ## catches "Foxs" instead of "Foxes" — this roster's chosen species is the one irregular case
	print("lineage_moral_check OK: %s" % moral)
