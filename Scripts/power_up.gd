class_name SkillPowerUp
extends Area2D

signal collected(power_up: SkillPowerUp)

enum PowerUpType {
	ECHO_BREAKER,
	GATE_BREAKER
}

@export var power_up_type: PowerUpType = PowerUpType.ECHO_BREAKER

var visual_time: float = 0.0


func _ready() -> void:
	z_index = 4

	collision_layer = 8
	collision_mask = 1

	monitoring = true
	monitorable = false

	area_entered.connect(_on_area_entered)

	queue_redraw()


func _process(delta: float) -> void:
	visual_time += delta
	queue_redraw()


func _on_area_entered(area: Area2D) -> void:
	if not area is OrbitPlayer:
		return

	set_deferred("monitoring",false)
	collected.emit(self)


func _draw() -> void:
	var pulse: float = (
		sin(visual_time * 7.0) + 1.0
	) * 0.5

	var main_colour: Color

	if power_up_type == PowerUpType.ECHO_BREAKER:
		main_colour = Color("#8B5CFF")
	else:
		main_colour = Color("#FFD54A")

	# Outer energy glow.
	draw_circle(
		Vector2.ZERO,
		22.0 + pulse * 4.0,
		Color(
			main_colour.r,
			main_colour.g,
			main_colour.b,
			0.10 + pulse * 0.08
		)
	)

	draw_circle(
		Vector2.ZERO,
		15.0,
		Color(
			main_colour.r,
			main_colour.g,
			main_colour.b,
			0.22
		)
	)

	# Dark centre.
	draw_circle(
		Vector2.ZERO,
		10.0,
		Color("#101018")
	)

	# Rotating segmented ring.
	for index: int in range(4):
		var segment_start: float = (
			visual_time * 1.8
			+ float(index) * TAU / 4.0
		)

		draw_arc(
			Vector2.ZERO,
			13.0,
			segment_start,
			segment_start + 0.55,
			8,
			main_colour,
			3.0,
			true
		)

	# Central symbol.
	if power_up_type == PowerUpType.ECHO_BREAKER:
		draw_line(
			Vector2(-5.0, -5.0),
			Vector2(5.0, 5.0),
			main_colour,
			3.0,
			true
		)

		draw_line(
			Vector2(5.0, -5.0),
			Vector2(-5.0, 5.0),
			main_colour,
			3.0,
			true
		)

	else:
		# Broken Phase Gate symbol.
		draw_line(
			Vector2(0.0, -8.0),
			Vector2(0.0, -2.5),
			main_colour,
			3.5,
			true
		)

		draw_line(
			Vector2(0.0, 2.5),
			Vector2(0.0, 8.0),
			main_colour,
			3.5,
			true
		)

		draw_line(
			Vector2(-5.0, 3.0),
			Vector2(5.0, -3.0),
			main_colour,
			2.0,
			true
		)
