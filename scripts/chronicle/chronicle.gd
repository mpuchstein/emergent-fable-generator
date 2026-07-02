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

func event_to_sentence(event: Dictionary) -> String:
	return ChronicleTemplates.render(event)

## scans a day's raw events for the single most consequential one and turns it
## into a one-line moral — "story sifting": pick the pattern worth telling
## rather than narrating everything that happened. A death always wins this
## scan outright — nothing in a day is more consequential than who didn't
## survive it — otherwise the biggest relationship swing is used.
func synthesize_moral(day_events: Array) -> String:
	var notable: Dictionary = {}
	var notable_abs := 0.0
	for event in day_events:
		if event["action"] == "Die":
			notable = event
			break
		var d: float = absf(event.get("relationship_delta", 0.0))
		if d > notable_abs:
			notable_abs = d
			notable = event
	if notable.is_empty():
		return MORALS["default"][0]
	var bucket: Array = MORALS.get(notable["action"], MORALS["default"])
	var idx := randi() % bucket.size()
	return String(bucket[idx]).format(notable)
