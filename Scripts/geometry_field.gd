class_name GeometryField
extends Node2D


@export var primary_colour: Color = Color("#35F2E8")
@export var secondary_colour: Color = Color("#B85CFF")

var current_score: int = 0
var intensity: float = 0.0
var elapsed_time: float = 0.0

# Normal lap reaction.
var lap_kick: float = 0.0
var lap_flash: float = 0.0
var lap_twist: float = 0.0

# Major phase transition reaction.
var phase_burst: float = 0.0
var phase_flash: float = 0.0
var phase_twist: float = 0.0
var current_phase: int = 0

var lap_reaction_tween: Tween
var phase_effect_tween: Tween
var phase_scale_tween: Tween


func _ready() -> void:
	z_index = -20
	queue_redraw()


func _process(delta: float) -> void:
	elapsed_time += delta
	queue_redraw()


func set_visual_state(
	score: int,
	new_intensity: float
) -> void:
	current_score = max(score, 0)
	intensity = clamp(new_intensity, 0.0, 1.0)

	queue_redraw()


func trigger_lap_reaction() -> void:
	if lap_reaction_tween != null:
		lap_reaction_tween.kill()

	lap_kick = 1.0
	lap_flash = 1.0
	lap_twist = 1.0

	lap_reaction_tween = create_tween()
	lap_reaction_tween.set_parallel(true)

	lap_reaction_tween.tween_property(
		self,
		"lap_kick",
		0.0,
		0.42
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	lap_reaction_tween.tween_property(
		self,
		"lap_flash",
		0.0,
		0.30
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	lap_reaction_tween.tween_property(
		self,
		"lap_twist",
		0.0,
		0.50
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)


func trigger_phase_transition(phase: int) -> void:
	current_phase = phase

	if phase_effect_tween != null:
		phase_effect_tween.kill()

	if phase_scale_tween != null:
		phase_scale_tween.kill()

	#
	# Each later phase becomes more violent.
	#
	var phase_strength: float = (
		1.0 + float(phase - 1) * 0.25
	)

	phase_burst = phase_strength
	phase_flash = phase_strength
	phase_twist = phase_strength

	#
	# Snap inward very briefly...
	#
	scale = Vector2.ONE * 0.95

	#
	# ...then explode outward and settle.
	#
	phase_scale_tween = create_tween()

	phase_scale_tween.tween_property(
		self,
		"scale",
		Vector2.ONE * (1.07 + float(phase) * 0.01),
		0.11
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	phase_scale_tween.tween_property(
		self,
		"scale",
		Vector2.ONE,
		0.48
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	#
	# Radius / brightness / rotational punch.
	#
	phase_effect_tween = create_tween()
	phase_effect_tween.set_parallel(true)

	phase_effect_tween.tween_property(
		self,
		"phase_burst",
		0.0,
		0.75
	).set_trans(
		Tween.TRANS_EXPO
	).set_ease(
		Tween.EASE_OUT
	)

	phase_effect_tween.tween_property(
		self,
		"phase_flash",
		0.0,
		0.55
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	phase_effect_tween.tween_property(
		self,
		"phase_twist",
		0.0,
		0.85
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)


func _draw() -> void:
	var layer_count: int = _get_layer_count()
	var base_sides: int = _get_base_side_count()

	for layer_index: int in range(layer_count):
		_draw_geometry_layer(
			layer_index,
			base_sides
		)


func _draw_geometry_layer(
	layer_index: int,
	base_sides: int
) -> void:

	var sides: int = (
		base_sides
		+ ((layer_index % 2) * 2)
	)

	var radius: float = (
		290.0
		+ float(layer_index) * 38.0
	)

	#
	# Continuous breathing.
	#
	var breathing_strength: float = lerpf(
		0.003,
		0.016,
		intensity
	)

	var breathing_speed: float = lerpf(
		0.6,
		1.8,
		intensity
	)

	var breathing: float = (
		sin(
			elapsed_time * breathing_speed
			+ float(layer_index) * 0.7
		)
		* breathing_strength
	)

	radius *= 1.0 + breathing

	#
	# Normal lap punch.
	#
	var kick_distance: float = lerpf(
		18.0,
		48.0,
		intensity
	)

	radius += (
		kick_distance
		* lap_kick
		* (
			1.0
			+ float(layer_index) * 0.12
		)
	)

	#
	# Major phase-change explosion.
	#
	var phase_distance: float = (
		48.0
		+ float(current_phase) * 14.0
	)

	radius += (
		phase_distance
		* phase_burst
		* (
			1.0
			+ float(layer_index) * 0.14
		)
	)

	#
	# Continuous rotation.
	#
	var rotation_speed: float = lerpf(
		0.025,
		0.18,
		intensity
	)

	rotation_speed *= (
		1.0
		+ float(layer_index) * 0.16
	)

	var direction: float = 1.0

	if layer_index % 2 == 1:
		direction = -1.0

	var rotation_angle: float = (
		elapsed_time
		* rotation_speed
		* direction
	)

	#
	# Normal lap twist.
	#
	var twist_strength: float = lerpf(
		0.07,
		0.18,
		intensity
	)

	rotation_angle += (
		lap_twist
		* twist_strength
		* direction
		* (
			1.0
			+ float(layer_index) * 0.12
		)
	)

	#
	# Much stronger milestone twist.
	#
	rotation_angle += (
		phase_twist
		* 0.16
		* direction
		* (
			1.0
			+ float(layer_index) * 0.18
		)
	)

	#
	# Offset individual layers.
	#
	rotation_angle += (
		float(layer_index)
		* PI
		/ float(sides)
	)

	var points: PackedVector2Array = (
		_create_polygon_points(
			sides,
			radius,
			rotation_angle
		)
	)

	var colour: Color

	if layer_index % 2 == 0:
		colour = primary_colour
	else:
		colour = secondary_colour

	#
	# Base visibility.
	#
	var alpha: float = lerpf(
		0.10,
		0.34,
		intensity
	)

	#
	# Normal lap flash.
	#
	alpha += (
		lerpf(
			0.10,
			0.22,
			intensity
		)
		* lap_flash
	)

	#
	# Major transition flash.
	#
	alpha += (
		0.24
		* phase_flash
	)

	alpha *= maxf(
		0.65,
		1.0 - float(layer_index) * 0.08
	)

	#
	# During a phase transition, briefly pull the
	# polygon colours toward white.
	#
	var white_mix: float = clampf(
		phase_flash * 0.38,
		0.0,
		0.65
	)

	colour = colour.lerp(
		Color.WHITE,
		white_mix
	)

	#
	# Glow pass.
	#
	var glow_colour: Color = colour
	glow_colour.a = alpha * 0.30

	var glow_width: float = (
		lerpf(
			6.0,
			11.0,
			intensity
		)
		+ phase_flash * 3.5
	)

	draw_polyline(
		points,
		glow_colour,
		glow_width,
		true
	)

	#
	# Crisp geometry.
	#
	colour.a = clampf(
		alpha,
		0.0,
		1.0
	)

	var line_width: float = (
		lerpf(
			1.8,
			3.8,
			intensity
		)
		+ phase_flash * 0.8
	)

	draw_polyline(
		points,
		colour,
		line_width,
		true
	)


func _create_polygon_points(
	sides: int,
	radius: float,
	rotation_angle: float
) -> PackedVector2Array:

	var points := PackedVector2Array()

	for index: int in range(sides):
		var angle: float = (
			TAU
			* float(index)
			/ float(sides)
			+ rotation_angle
		)

		points.append(
			Vector2.from_angle(angle)
			* radius
		)

	if not points.is_empty():
		points.append(points[0])

	return points


func _get_layer_count() -> int:
	if current_score >= 30:
		return 5

	if current_score >= 20:
		return 4

	if current_score >= 10:
		return 3

	if current_score >= 5:
		return 2

	return 1


func _get_base_side_count() -> int:
	if current_score >= 30:
		return 12

	if current_score >= 20:
		return 10

	if current_score >= 10:
		return 8

	return 6
