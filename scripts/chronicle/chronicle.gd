class_name Chronicle
extends RefCounted

## day-level "moral" lines, keyed by the action of the day's most consequential
## event. Kept here (not in templates.gd) — day-summary concern, not per-event flavor.
const MORALS := {
	"Steal": [
		"And so it was that {actor}'s greed cost them {target}'s trust.",
		"{actor} gained a meal, but lost a friend in {target}.",
	],
	"Share": ["Kindness repaid kindness, and {actor} and {target} grew closer for it."],
	"Confront": ["Pride met pride at the {location}, and neither {actor} nor {target} yielded easily."],
	"Socialize": ["A little warmth at the {location} went further than either {actor} or {target} expected."],
	"Boast": ["{actor}'s boasting won laughter, not respect."],
	"Die": [
		"And so the forest keeps its balance, one way or another.",
		"{actor}'s tale ends here — but the name, and the place, goes on.",
	],
	"default": ["The day passed, and the forest kept its secrets."],
}

## fires instead of the plain "Die" bucket when World reports 3+ consecutive
## same-species deaths at the same location (event["location_streak"]) — the
## multi-day "story sifting" this project's design was named after: some
## patterns only exist across days, not within any single one.
const MORALS_LINEAGE := [
	"The {location_streak_ordinal} {actor} in a row to die at the {location} — some places are simply unlucky for {actor_plural}.",
	"{actor} after {actor}, the {location} has claimed {location_streak_ordinal} in a row now. The forest does not forget a place like that.",
]

const _ORDINALS := {2: "second", 3: "third", 4: "fourth", 5: "fifth", 6: "sixth", 7: "seventh", 8: "eighth"}

static func _ordinal(n: int) -> String:
	return _ORDINALS.get(n, "%dth" % n)

## naive "{actor}s" breaks on English's -x/-s/-sh/-ch irregulars (Fox -> Foxs,
## not Foxes) — every current species is one word, so this simple suffix rule
## covers the whole roster; would need a real exceptions list for anything
## with a genuinely irregular plural (e.g. Mouse -> Mice).
static func _pluralize(species: String) -> String:
	var lower := species.to_lower()
	if lower.ends_with("x") or lower.ends_with("s") or lower.ends_with("sh") or lower.ends_with("ch"):
		return species + "es"
	return species + "s"

func event_to_sentence(event: Dictionary) -> String:
	return ChronicleTemplates.render(event)

## scans a day's raw events for the single most consequential one and turns it
## into a one-line moral — "story sifting": pick the pattern worth telling
## rather than narrating everything that happened. A death always wins this
## scan outright — nothing in a day is more consequential than who didn't
## survive it — otherwise the biggest relationship swing is used. A death that
## is itself part of a same-location pattern (3+ in a row) gets the
## lineage-aware moral instead of the generic one-death moral.
func synthesize_moral(day_events: Array) -> String:
	var notable: Dictionary = {}
	var notable_abs := 0.0
	var saw_death := false
	for event in day_events:
		if event["action"] == "Die":
			## most recent death wins if a day somehow has more than one —
			## in normal play a day is too short to fit two, but always
			## preferring the latest keeps this correct if that changes
			notable = event
			saw_death = true
			continue
		if saw_death:
			continue
		var d: float = absf(event.get("relationship_delta", 0.0))
		if d > notable_abs:
			notable_abs = d
			notable = event
	if notable.is_empty():
		return MORALS["default"][0]

	if notable["action"] == "Die" and notable.get("location_streak", 1) >= 3:
		var lineage_event := notable.duplicate()
		lineage_event["location_streak_ordinal"] = _ordinal(notable["location_streak"])
		lineage_event["actor_plural"] = _pluralize(notable["actor"])
		var lineage_idx := randi() % MORALS_LINEAGE.size()
		return String(MORALS_LINEAGE[lineage_idx]).format(lineage_event)

	var bucket: Array = MORALS.get(notable["action"], MORALS["default"])
	var idx := randi() % bucket.size()
	return String(bucket[idx]).format(notable)
