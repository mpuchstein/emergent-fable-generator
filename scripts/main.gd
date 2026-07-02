extends Node2D

const AGENT_VIEW_SCENE := preload("res://scenes/agent_view.tscn")
const BASE_TICK_SECONDS := 0.4

## accent color per trait — used for both the agent's marker and its chronicle lines
const TRAIT_COLOR := {
	"Greedy": "e07b39", "Kind": "6fbf73", "Vain": "c77dff", "Cunning": "9d8189",
	"Timid": "8ecae6", "Brave": "e63946", "Proud": "f4a261", "Loyal": "4361ee",
}
const DEFAULT_COLOR := "d9d9d9"

@onready var tick_timer: Timer = $TickTimer
@onready var agents_root: Node2D = $Agents
@onready var chronicle_log: ChronicleLog = $UI/ChronicleScroll/ChronicleLog
@onready var pause_button: Button = $UI/Controls/PauseButton
@onready var speed_button: Button = $UI/Controls/SpeedButton
@onready var day_label: Label = $UI/Controls/DayLabel

var world: World
var chronicle := Chronicle.new()
var agent_views: Dictionary = {} ## species name -> AgentView (species is unique in this fixed roster)
var location_positions: Dictionary = {} ## location name -> Vector2
var agent_offsets: Dictionary = {} ## species -> Vector2, so agents sharing a location don't stack invisibly
var _speed_multiplier := 1

const SLOT_RADIUS := 30.0

func _ready() -> void:
	for loc_name in LocationData.LOCATIONS:
		var marker: Marker2D = $Map.get_node(loc_name)
		location_positions[loc_name] = marker.global_position

	world = World.new()

	for i in world.agents.size():
		var angle := TAU * i / world.agents.size()
		agent_offsets[world.agents[i].species] = Vector2(cos(angle), sin(angle)) * SLOT_RADIUS

	for agent in world.agents:
		var view: AgentView = AGENT_VIEW_SCENE.instantiate()
		agents_root.add_child(view)
		view.global_position = _slot_position(agent.location, agent.species)
		view.setup(agent.species, _agent_color(agent))
		agent_views[agent.species] = view

	world.event_happened.connect(_on_event_happened)
	world.day_ended.connect(_on_day_ended)

	tick_timer.wait_time = BASE_TICK_SECONDS
	tick_timer.timeout.connect(world.tick)

	pause_button.pressed.connect(_on_pause_pressed)
	speed_button.pressed.connect(_on_speed_pressed)
	day_label.text = "Day 1"

func _slot_position(loc_name: String, species: String) -> Vector2:
	return location_positions[loc_name] + agent_offsets.get(species, Vector2.ZERO)

func _agent_color(agent: Agent) -> Color:
	for t in agent.traits:
		if TRAIT_COLOR.has(t):
			return Color(TRAIT_COLOR[t])
	return Color(DEFAULT_COLOR)

func _on_event_happened(event: Dictionary) -> void:
	var line := chronicle.event_to_sentence(event)
	var color: String = TRAIT_COLOR.get(event["dominant_trait"], DEFAULT_COLOR)
	chronicle_log.add_line(line, color)
	if event["action"] == "Travel":
		var view: AgentView = agent_views.get(event["actor"])
		if view:
			view.travel_to(_slot_position(event["target"], event["actor"]))
	elif event["action"] == "Succeed":
		## a new generation, not a walk — teleport straight to the Den, don't tween
		var view: AgentView = agent_views.get(event["actor"])
		if view:
			view.global_position = _slot_position(event["location"], event["actor"])

func _on_day_ended(day: int, day_events: Array) -> void:
	var moral := chronicle.synthesize_moral(day_events)
	chronicle_log.finish_day(day, moral)
	day_label.text = "Day %d" % (day + 1)

func _on_pause_pressed() -> void:
	get_tree().paused = not get_tree().paused
	pause_button.text = "Resume" if get_tree().paused else "Pause"

func _on_speed_pressed() -> void:
	_speed_multiplier = 4 if _speed_multiplier == 1 else 1
	tick_timer.wait_time = BASE_TICK_SECONDS / _speed_multiplier
	speed_button.text = "%dx" % _speed_multiplier
