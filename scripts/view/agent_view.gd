class_name AgentView
extends Node2D

@onready var shape: ColorRect = $Shape
@onready var label: Label = $Label

var _travel_tween: Tween

func setup(species: String, color: Color) -> void:
	label.text = species
	shape.color = color

func travel_to(target: Vector2, duration := 0.4) -> void:
	if _travel_tween and _travel_tween.is_running():
		_travel_tween.kill()
	_travel_tween = create_tween()
	_travel_tween.tween_property(self, "global_position", target, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
