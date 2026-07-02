class_name Agent
extends RefCounted

const NEED_KEYS: Array[String] = ["Hunger", "Rest", "Social", "Ambition"]

var id: String
var species: String
var traits: Array[String] = []
var needs: Dictionary = {}
var relationships: Dictionary = {} ## other agent id -> float affinity, -100..100
var location: String = "Den"
var last_action: String = ""
var action_streak: int = 0 ## consecutive ticks `last_action` has been repeated
var generation: int = 1
var starved_ticks: int = 0 ## consecutive ticks at 0 Hunger; see World.STARVATION_LIMIT

func _init(p_id: String, p_species: String, p_traits: Array[String], rng: RandomNumberGenerator) -> void:
	id = p_id
	species = p_species
	traits = p_traits
	for key in NEED_KEYS:
		needs[key] = rng.randf_range(60.0, 90.0)

func get_relationship(other_id: String) -> float:
	return relationships.get(other_id, 0.0)

func adjust_relationship(other_id: String, delta: float) -> void:
	relationships[other_id] = clampf(get_relationship(other_id) + delta, -100.0, 100.0)

func adjust_need(key: String, delta: float) -> void:
	needs[key] = clampf(needs.get(key, 0.0) + delta, 0.0, 100.0)

func has_trait(t: String) -> bool:
	return traits.has(t)
