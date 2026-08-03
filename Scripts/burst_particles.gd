class_name BurstParticles
extends Node2D

var particle_positions: Array[Vector2] = []
var particle_velocities: Array[Vector2] = []
var particle_colours: Array[Color] = []

var particle_remaining: PackedFloat32Array = (
	PackedFloat32Array()
)

var particle_lifetimes: PackedFloat32Array = (
	PackedFloat32Array()
)

var particle_sizes: PackedFloat32Array = (
	PackedFloat32Array()
)


func _ready() -> void:
	z_index = 10
	set_process(false)


func create_burst(
	burst_position: Vector2,
	burst_colour: Color,
	particle_count: int,
	minimum_speed: float,
	maximum_speed: float,
	lifetime: float
) -> void:
	for index: int in range(particle_count):
		var particle_angle: float = randf_range(
			0.0,
			TAU
		)

		var particle_speed: float = randf_range(
			minimum_speed,
			maximum_speed
		)

		var direction: Vector2 = Vector2.from_angle(
			particle_angle
		)

		particle_positions.append(burst_position)

		particle_velocities.append(
			direction * particle_speed
		)

		particle_colours.append(burst_colour)
		particle_remaining.append(lifetime)
		particle_lifetimes.append(lifetime)

		particle_sizes.append(
			randf_range(1.8, 4.0)
		)

	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	for index: int in range(
		particle_positions.size() - 1,
		-1,
		-1
	):
		particle_remaining[index] -= delta

		if particle_remaining[index] <= 0.0:
			particle_positions.remove_at(index)
			particle_velocities.remove_at(index)
			particle_colours.remove_at(index)
			particle_remaining.remove_at(index)
			particle_lifetimes.remove_at(index)
			particle_sizes.remove_at(index)
			continue

		particle_positions[index] += (
			particle_velocities[index] * delta
		)

		particle_velocities[index] = (
			particle_velocities[index].move_toward(
				Vector2.ZERO,
				180.0 * delta
			)
		)

	if particle_positions.is_empty():
		set_process(false)

	queue_redraw()


func _draw() -> void:
	for index: int in range(
		particle_positions.size()
	):
		var life_ratio: float = (
			particle_remaining[index]
			/ particle_lifetimes[index]
		)

		var particle_colour: Color = (
			particle_colours[index]
		)

		particle_colour.a *= life_ratio

		var velocity: Vector2 = (
			particle_velocities[index]
		)

		var trail_length: float = minf(
			velocity.length() * 0.045,
			9.0
		)

		var trail_direction: Vector2 = Vector2.ZERO

		if velocity.length() > 0.0:
			trail_direction = velocity.normalized()

		var particle_size: float = maxf(
			particle_sizes[index] * life_ratio,
			0.8
		)

		draw_line(
			particle_positions[index],
			particle_positions[index]
				- trail_direction * trail_length,
			particle_colour,
			particle_size,
			true
		)

		draw_circle(
			particle_positions[index],
			particle_size * 0.65,
			particle_colour
		)
