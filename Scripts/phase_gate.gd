class_name PhaseGate
extends Area2D

signal player_hit(hazard: Node2D)

@export var gate_size: Vector2 = Vector2(52.0, 22.0)

var blocks_inner_lane: bool = false
var visual_time: float = 0.0


func _ready() -> void:
	
	visual_time = randf_range(0.0, TAU)
	
	z_index = 2

	# Gates occupy layer 3 and detect the Player on layer 1.
	collision_layer = 4
	collision_mask = 1
	monitoring = true
	monitorable = false

	area_entered.connect(_on_area_entered)

	var collision_shape: CollisionShape2D = (
		$CollisionShape2D
	)

	var rectangle: RectangleShape2D = (
		collision_shape.shape as RectangleShape2D
	)

	if rectangle != null:
		rectangle.size = gate_size

	queue_redraw()


func configure_gate(
	gate_angle: float,
	lane_radius: float,
	is_inner: bool
) -> void:
	blocks_inner_lane = is_inner

	position = (
		Vector2.from_angle(gate_angle)
		* lane_radius
	)

	# Rotate the rectangle so it follows the ring.
	rotation = gate_angle + PI / 2.0

	queue_redraw()


func _on_area_entered(area: Area2D) -> void:
	if area is OrbitPlayer:
		player_hit.emit(self)


func _draw() -> void:
	var gate_colour: Color = Color("#FF315F")
	var bright_colour: Color = Color("#FF9BC4")

	var pulse: float = (
		sin(visual_time * 6.0) + 1.0
	) * 0.5

	var half_size: Vector2 = gate_size * 0.5
	var bevel: float = 7.0

	# Pulsing outer glow.
	var glow_colour: Color = gate_colour
	glow_colour.a = 0.12 + pulse * 0.12

	var glow_amount: float = 5.0 + pulse * 4.0

	draw_rect(
		Rect2(
			-half_size - Vector2.ONE * glow_amount,
			gate_size + Vector2.ONE * glow_amount * 2.0
		),
		glow_colour,
		true
	)

	# Bevelled barrier shape.
	var body_points: PackedVector2Array = PackedVector2Array([
		Vector2(-half_size.x + bevel, -half_size.y),
		Vector2(half_size.x - bevel, -half_size.y),
		Vector2(half_size.x, -half_size.y + bevel),
		Vector2(half_size.x, half_size.y - bevel),
		Vector2(half_size.x - bevel, half_size.y),
		Vector2(-half_size.x + bevel, half_size.y),
		Vector2(-half_size.x, half_size.y - bevel),
		Vector2(-half_size.x, -half_size.y + bevel)
	])

	draw_colored_polygon(
		body_points,
		gate_colour
	)

	var outline_points: PackedVector2Array = (
		body_points.duplicate()
	)

	outline_points.append(body_points[0])

	draw_polyline(
		outline_points,
		bright_colour,
		2.0,
		true
	)

	# Moving scanner line.
	var scan_progress: float = fposmod(
		visual_time * 0.7,
		1.0
	)

	var scan_x: float = lerpf(
		-half_size.x + bevel,
		half_size.x - bevel,
		scan_progress
	)

	draw_line(
		Vector2(scan_x, -half_size.y + 3.0),
		Vector2(scan_x, half_size.y - 3.0),
		Color(1.0, 1.0, 1.0, 0.85),
		3.0,
		true
	)

	# Bright central energy channel.
	draw_line(
		Vector2(-half_size.x + bevel, 0.0),
		Vector2(half_size.x - bevel, 0.0),
		bright_colour,
		3.0,
		true
	)

func _process(delta: float) -> void:
	visual_time = fposmod(visual_time + delta, TAU)
	queue_redraw()
