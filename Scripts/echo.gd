class_name OrbitEcho
extends Area2D

signal player_hit(hazard: Node2D)

@export var warning_lead_time: float = 0.32
@export var warning_radius_difference: float = 18.0

var recorded_path: PackedFloat32Array = (
	PackedFloat32Array()
)

var angular_speed: float = 2.0
var travelled_angle: float = 0.0
var starting_angle: float = -PI / 2.0

var visual_time: float = 0.0
var lane_switch_warning: bool = false


func setup(
	path: PackedFloat32Array,
	speed: float,
	phase_offset: float,
	speed_multiplier: float,
	warning_time: float,
	collision_radius: float
) -> void:
	recorded_path = path.duplicate()

	angular_speed = (
		absf(speed) * speed_multiplier
	)

	warning_lead_time = warning_time
	travelled_angle = phase_offset

	var collision_shape: CollisionShape2D = (
		$CollisionShape2D
	)

	var circle_shape: CircleShape2D = (
		collision_shape.shape.duplicate()
		as CircleShape2D
	)

	if circle_shape != null:
		circle_shape.radius = collision_radius
		collision_shape.shape = circle_shape

	_update_echo_position()


func _ready() -> void:
	visual_time = randf_range(0.0, TAU)
	z_index = 5

	# Echoes occupy layer 2 and detect layer 1.
	collision_layer = 2
	collision_mask = 1
	monitoring = true
	monitorable = false

	area_entered.connect(_on_area_entered)

	queue_redraw()


func _process(delta: float) -> void:
	if recorded_path.size() < 2:
		return

	travelled_angle += angular_speed * delta

	visual_time = fposmod(
		visual_time + delta,
		TAU
	)

	_update_echo_position()
	queue_redraw()


func _sample_recorded_radius(
	cycle_angle: float
) -> float:
	if recorded_path.size() < 2:
		return 0.0

	var playback_ratio: float = (
		cycle_angle / TAU
	)

	# Echoes replay the path backwards.
	var reversed_ratio: float = (
		1.0 - playback_ratio
	)

	var final_index: int = (
		recorded_path.size() - 1
	)

	var sample_position: float = (
		reversed_ratio * float(final_index)
	)

	var lower_index: int = floori(
		sample_position
	)

	var upper_index: int = mini(
		lower_index + 1,
		final_index
	)

	var interpolation_weight: float = (
		sample_position - float(lower_index)
	)

	return lerpf(
		recorded_path[lower_index],
		recorded_path[upper_index],
		interpolation_weight
	)


func _update_echo_position() -> void:
	if recorded_path.size() < 2:
		return

	var cycle_angle: float = fposmod(
		travelled_angle,
		TAU
	)

	var replayed_radius: float = (
		_sample_recorded_radius(cycle_angle)
	)

	# Examine where the Echo will be shortly.
	var warning_angle: float = fposmod(
		cycle_angle
			+ angular_speed * warning_lead_time,
		TAU
	)

	var upcoming_radius: float = (
		_sample_recorded_radius(warning_angle)
	)

	lane_switch_warning = (
		absf(upcoming_radius - replayed_radius)
		>= warning_radius_difference
	)

	var echo_angle: float = (
		starting_angle - cycle_angle
	)

	position = (
		Vector2.from_angle(echo_angle)
		* replayed_radius
	)


func _draw() -> void:
	var pulse: float = (
		sin(visual_time * 7.0) + 1.0
	) * 0.5

	# Unstable outer glow.
	draw_circle(
		Vector2.ZERO,
		27.0 + pulse * 4.0,
		Color(
			1.0,
			0.08,
			0.8,
			0.08 + pulse * 0.06
		)
	)

	draw_circle(
		Vector2.ZERO,
		18.0 + pulse * 2.0,
		Color(1.0, 0.08, 0.8, 0.18)
	)

	# Empty black core.
	draw_circle(
		Vector2.ZERO,
		11.0,
		Color("#100512")
	)

	# Three rotating broken segments.
	for index: int in range(3):
		var segment_start: float = (
			-visual_time * 1.8
			+ float(index) * TAU / 3.0
		)

		draw_arc(
			Vector2.ZERO,
			15.0,
			segment_start,
			segment_start + 0.65,
			10,
			Color("#FF35CE"),
			3.5,
			true
		)

	# Small corrupted centre.
	draw_circle(
		Vector2.ZERO,
		3.5 + pulse,
		Color("#FF35CE")
	)

	if lane_switch_warning:
		var warning_pulse: float = (
			sin(visual_time * 16.0) + 1.0
		) * 0.5

		var warning_colour: Color = Color(
			1.0,
			0.78,
			0.15,
			0.55 + warning_pulse * 0.45
		)

		draw_arc(
			Vector2.ZERO,
			23.0 + warning_pulse * 5.0,
			0.0,
			TAU,
			32,
			warning_colour,
			3.0,
			true
		)

		var marker_points: PackedVector2Array = (
			PackedVector2Array([
				Vector2(-5.0, -31.0),
				Vector2(5.0, -31.0),
				Vector2(0.0, -22.0)
			])
		)

		draw_colored_polygon(
			marker_points,
			warning_colour
		)


func _on_area_entered(area: Area2D) -> void:
	if area is OrbitPlayer:
		player_hit.emit(self)
