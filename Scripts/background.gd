extends Node2D

var elapsed_time: float = 0.0
var viewport_size: Vector2

var particles: Array[Vector2] = []
var particle_sizes: PackedFloat32Array = (
	PackedFloat32Array()
)

const GRID_SPACING: float = 54.0
const PARTICLE_COUNT: int = 45


func _ready() -> void:
	z_index = -100

	get_viewport().size_changed.connect(
		_refresh_background
	)

	_refresh_background()


func _process(delta: float) -> void:
	elapsed_time += delta
	queue_redraw()


func _refresh_background() -> void:
	viewport_size = get_viewport_rect().size
	_generate_particles()
	queue_redraw()


func _generate_particles() -> void:
	particles.clear()
	particle_sizes.clear()

	var random: RandomNumberGenerator = (
		RandomNumberGenerator.new()
	)

	# Fixed seed keeps the background consistent.
	random.seed = 73421

	for index: int in range(PARTICLE_COUNT):
		particles.append(
			Vector2(
				random.randf_range(
					0.0,
					viewport_size.x
				),
				random.randf_range(
					0.0,
					viewport_size.y
				)
			)
		)

		particle_sizes.append(
			random.randf_range(0.7, 1.8)
		)


func _draw() -> void:
	# Main background colour.
	draw_rect(
		Rect2(Vector2.ZERO, viewport_size),
		Color("#070811"),
		true
	)

	var centre: Vector2 = viewport_size * 0.5

	_draw_arena_glow(centre)
	_draw_grid()
	_draw_particles()


func _draw_arena_glow(centre: Vector2) -> void:
	var pulse: float = (
		sin(elapsed_time * 0.7) * 6.0
	)

	# Draw largest circles first to imitate a gradient.
	for index: int in range(7, 0, -1):
		var radius: float = (
			120.0
			+ float(index) * 48.0
			+ pulse
		)

		var glow_strength: float = (
			float(8 - index) * 0.006
		)

		draw_circle(
			centre,
			radius,
			Color(
				0.03,
				0.70,
				0.72,
				glow_strength
			)
		)

	# Extremely faint magenta secondary glow.
	draw_circle(
		centre + Vector2(-90.0, 70.0),
		230.0,
		Color(0.8, 0.03, 0.55, 0.025)
	)


func _draw_grid() -> void:
	var grid_colour: Color = Color(
		0.25,
		0.75,
		0.78,
		0.035
	)

	var horizontal_count: int = (
		int(ceil(viewport_size.y / GRID_SPACING)) + 2
	)

	var vertical_count: int = (
		int(ceil(viewport_size.x / GRID_SPACING)) + 2
	)

	var horizontal_offset: float = fposmod(
		elapsed_time * 2.0,
		GRID_SPACING
	)

	var vertical_offset: float = fposmod(
		elapsed_time * 3.0,
		GRID_SPACING
	)

	for index: int in range(vertical_count):
		var x_position: float = (
			float(index) * GRID_SPACING
			+ vertical_offset
			- GRID_SPACING
		)

		draw_line(
			Vector2(x_position, 0.0),
			Vector2(x_position, viewport_size.y),
			grid_colour,
			1.0
		)

	for index: int in range(horizontal_count):
		var y_position: float = (
			float(index) * GRID_SPACING
			+ horizontal_offset
			- GRID_SPACING
		)

		draw_line(
			Vector2(0.0, y_position),
			Vector2(viewport_size.x, y_position),
			grid_colour,
			1.0
		)


func _draw_particles() -> void:
	for index: int in range(particles.size()):
		var original_position: Vector2 = particles[index]

		var movement_speed: float = (
			2.0 + float(index % 4)
		)

		var particle_position: Vector2 = Vector2(
			original_position.x,
			fposmod(
				original_position.y
				+ elapsed_time * movement_speed,
				viewport_size.y
			)
		)

		var flicker: float = (
			sin(
				elapsed_time * 1.5
				+ float(index)
			)
			+ 1.0
		) * 0.5

		var particle_colour: Color

		if index % 5 == 0:
			particle_colour = Color(
				1.0,
				0.15,
				0.75,
				0.12 + flicker * 0.12
			)
		else:
			particle_colour = Color(
				0.2,
				0.95,
				0.9,
				0.10 + flicker * 0.10
			)

		draw_circle(
			particle_position,
			particle_sizes[index],
			particle_colour
		)
