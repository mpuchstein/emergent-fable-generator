class_name ChronicleTemplates
extends RefCounted

## action -> outcome -> trait (or "default") -> array of sentence templates.
## String.format() fills {actor}/{target}/{location} etc. from the event dict.
## Lookup falls back: specific trait -> "default" for that outcome -> a single
## generic line. Deliberately not a full action x outcome x trait matrix — most
## cells would be empty, this covers only where trait flavor actually matters.
const TEMPLATES := {
	"Forage": {
		"success": {
			"Greedy": [
				"{actor} gorged at the {location}, leaving little for the rest.",
				"{actor}'s greed thinned the {location}'s stores.",
			],
			"default": ["{actor} foraged quietly at the {location}."],
		},
		"failure": {"default": ["{actor} searched the {location} and found nothing."]},
	},
	"Rest": {
		"success": {
			"default": [
				"{actor} settled in to rest at the {location}.",
				"{actor} curled up and rested a while.",
			],
		},
	},
	"Socialize": {
		"success": {
			"Kind": ["{actor} shared warm words with {target} at the {location}."],
			"Loyal": ["{actor} and {target} caught up like old friends at the {location}."],
			"default": ["{actor} and {target} passed the time together at the {location}."],
		},
		"solo": {
			"default": [
				"{actor} sat alone at the {location}, listening to the quiet.",
				"{actor} wandered the {location}, hoping for company that never came.",
			],
		},
	},
	"Share": {
		"success": {
			"Kind": [
				"{actor}, ever generous, shared food with {target}.",
				"{actor} gave freely to {target}, expecting nothing back.",
			],
			"Loyal": ["{actor} made sure {target} had enough to eat."],
			"default": ["{actor} shared a meal with {target}."],
		},
		"failure": {"default": ["{actor} wished to share with {target}, but had nothing to give."]},
	},
	"Steal": {
		"success": {
			"Greedy": [
				"{actor}'s greed got the better of them — they stole from {target} at the {location}.",
				"{actor} crept off with what belonged to {target}.",
			],
			"Cunning": ["{actor} slipped away with {target}'s stores, unseen until it was too late."],
			"default": ["{actor} took from {target} at the {location}."],
		},
		"failure": {"default": ["{actor} tried to steal from {target}, but found nothing worth taking."]},
	},
	"Confront": {
		"success": {
			"Brave": ["{actor} stood tall and faced down {target} at the {location}."],
			"Proud": ["{actor}'s pride would not let {target}'s insult stand."],
			"default": ["{actor} confronted {target} at the {location}."],
		},
		"failure": {
			"Timid": ["{actor} tried to stand up to {target}, but their nerve failed them."],
			"default": ["{actor} backed down from {target}."],
		},
	},
	"Boast": {
		"success": {
			"Vain": ["{actor} preened and boasted before the gathered crowd at the {location}."],
			"Proud": ["{actor} spoke loudly of their own deeds at the {location}."],
			"default": ["{actor} boasted at the {location}."],
		},
		"failure": {"default": ["{actor} boasted to an empty {location}, and no one was there to hear it."]},
	},
	"Travel": {
		"success": {
			"default": [
				"{actor} set off from the {location} toward the {target}.",
				"{actor} made their way from the {location} to the {target}.",
			],
		},
	},
	"Die": {
		"success": {
			"Greedy": [
				"Even {actor}'s greed could not fill an empty belly, and so the forest lost them.",
				"{actor} had taken so much, and still it was not enough to save them.",
			],
			"Proud": ["{actor} would not beg for scraps, and so {actor} went hungry to the end."],
			"Timid": ["{actor} had always kept to the edges, and in the end the forest simply forgot to feed them."],
			"default": ["{actor}'s hunger went unanswered too long, and the forest was quieter for it."],
		},
	},
	"Succeed": {
		"success": {
			"default": [
				"A new {actor} came of age at the {location}, inheriting a place in the forest — and, unknowing, some of what came before.",
			],
		},
	},
}

const FALLBACK_LINE := "{actor} did something at the {location}."

static var _last_index: Dictionary = {}

static func render(event: Dictionary) -> String:
	var action_bank: Dictionary = TEMPLATES.get(event["action"], {})
	var outcome_bank: Dictionary = action_bank.get(event["outcome"], action_bank.get("success", {}))
	var bucket: Array = outcome_bank.get(event["dominant_trait"], outcome_bank.get("default", []))
	if bucket.is_empty():
		return FALLBACK_LINE.format(event)

	var key := "%s|%s|%s" % [event["action"], event["outcome"], event["dominant_trait"]]
	var idx := randi() % bucket.size()
	if bucket.size() > 1 and _last_index.get(key, -1) == idx:
		idx = (idx + 1) % bucket.size()
	_last_index[key] = idx
	return String(bucket[idx]).format(event)
