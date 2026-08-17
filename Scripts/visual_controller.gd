extends Node2D


@onready var geometry_field: GeometryField = $GeometryField

@export var shockwave_scene: PackedScene

var current_score: int = 0
var intensity: float = 0.0


func update_intensity(score: int) -> void:
	current_score = max(score, 0)

	# Visual intensity reaches maximum around score 30.
	intensity = clamp(
		float(current_score) / 30.0,
		0.0,
		1.0
	)

	geometry_field.set_visual_state(
		current_score,
		intensity
	)


func lap_completed(score: int) -> void:
	update_intensity(score)

	# Normal geometry reaction on every completed lap.
	geometry_field.trigger_lap_reaction()

	# Check whether we've reached a major visual milestone.
	var phase: int = _get_phase_transition(score)

	if phase > 0:
		geometry_field.trigger_phase_transition(phase)

		# Major milestones receive a stronger shockwave.
		_spawn_lap_shockwave(
			1.0 + float(phase) * 0.25
		)
	else:
		_spawn_lap_shockwave()


func _get_phase_transition(score: int) -> int:
	if score == 30:
		return 3

	if score == 20:
		return 2

	if score == 10:
		return 1

	return 0


func _spawn_lap_shockwave(
	strength: float = 1.0
) -> void:
	if shockwave_scene == null:
		push_warning(
			"VisualController: No shockwave scene assigned."
		)
		return

	var wave = shockwave_scene.instantiate()

	#
	# Normal shockwave properties.
	#
	# These continuously increase as the player's
	# score/intensity rises.
	#

	var start_scale: float = lerpf(
		0.65,
		0.50,
		intensity
	)

	var end_scale: float = lerpf(
		2.75,
		4.25,
		intensity
	)

	var wave_duration: float = lerpf(
		0.45,
		0.30,
		intensity
	)

	var wave_thickness: float = lerpf(
		2.5,
		5.0,
		intensity
	)

	var wave_alpha: float = lerpf(
		0.35,
		0.80,
		intensity
	)

	#
	# Major phase transitions at scores
	# 10, 20 and 30 receive a stronger wave.
	#
	if strength > 1.0:
		var boost: float = strength - 1.0

		end_scale += boost * 1.5

		wave_duration *= lerpf(
			1.0,
			0.78,
			boost
		)

		wave_thickness += boost * 3.0

		wave_alpha = minf(
			1.0,
			wave_alpha + boost * 0.45
		)

	#
	# Configure the newly-created shockwave
	# before adding it to the scene.
	#
	wave.configure(
		start_scale,
		end_scale,
		wave_duration,
		wave_thickness,
		wave_alpha
	)

	add_child(wave)
