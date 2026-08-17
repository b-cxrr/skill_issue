extends Node2D

@onready var ring: Line2D = $Ring

@export var base_radius: float = 120.0
@export var segments: int = 96

var start_scale: float = 0.65
var end_scale: float = 3.0
var duration: float = 0.4
var thickness: float = 3.0
var starting_alpha: float = 0.5
var wave_colour: Color = Color.WHITE


func configure(
	new_start_scale: float,
	new_end_scale: float,
	new_duration: float,
	new_thickness: float,
	new_alpha: float,
	new_colour: Color = Color.WHITE
) -> void:
	start_scale = new_start_scale
	end_scale = new_end_scale
	duration = new_duration
	thickness = new_thickness
	starting_alpha = new_alpha
	wave_colour = new_colour


func _ready() -> void:
	_build_ring()

	scale = Vector2.ONE * start_scale
	modulate.a = starting_alpha

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		self,
		"scale",
		Vector2.ONE * end_scale,
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"modulate:a",
		0.0,
		duration
	)

	tween.finished.connect(queue_free)


func _build_ring() -> void:
	var points := PackedVector2Array()

	for i in range(segments + 1):
		var angle := TAU * float(i) / float(segments)

		points.append(
			Vector2(
				cos(angle),
				sin(angle)
			) * base_radius
		)

	ring.points = points
	ring.width = thickness
	ring.default_color = wave_colour
	ring.closed = true
	ring.antialiased = true
