class_name SkillToken
extends Area2D

signal collected(token: SkillToken)

var visual_time: float = 0.0
var already_collected: bool = false


func _ready() -> void:
	z_index = 4

	collision_layer = 0
	collision_mask = 1

	monitoring = true
	monitorable = false

	area_entered.connect(
		_on_area_entered
	)

	queue_redraw()


func _process(delta: float) -> void:
	visual_time += delta
	queue_redraw()


func _on_area_entered(
	area: Area2D
) -> void:
	if already_collected:
		return

	if not area is OrbitPlayer:
		return

	already_collected = true

	set_deferred(
		"monitoring",
		false
	)

	collected.emit(self)


func _draw() -> void:
	var pulse: float = (
		sin(visual_time * 6.0)
		+ 1.0
	) * 0.5

	var token_colour: Color = Color(
		"#7CFFB2"
	)

	# Soft glow.
	draw_circle(
		Vector2.ZERO,
		18.0 + pulse * 3.0,
		Color(
			token_colour.r,
			token_colour.g,
			token_colour.b,
			0.08 + pulse * 0.08
		)
	)

	# Outer ring.
	draw_arc(
		Vector2.ZERO,
		13.0,
		0.0,
		TAU,
		32,
		token_colour,
		2.5,
		true
	)

	# Dark centre.
	draw_circle(
		Vector2.ZERO,
		9.0,
		Color("#101018")
	)

	# Diamond symbol.
	var top: Vector2 = Vector2(0.0, -7.0)
	var right: Vector2 = Vector2(6.0, 0.0)
	var bottom: Vector2 = Vector2(0.0, 7.0)
	var left: Vector2 = Vector2(-6.0, 0.0)

	draw_line(
		top,
		right,
		token_colour,
		2.5,
		true
	)

	draw_line(
		right,
		bottom,
		token_colour,
		2.5,
		true
	)

	draw_line(
		bottom,
		left,
		token_colour,
		2.5,
		true
	)

	draw_line(
		left,
		top,
		token_colour,
		2.5,
		true
	)
