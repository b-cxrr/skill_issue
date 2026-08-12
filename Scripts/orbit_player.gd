class_name OrbitPlayer
extends Area2D

signal lap_completed(path: PackedFloat32Array,recorded_speed: float)
signal lane_switched(switch_angle: float,from_radius: float,to_radius: float)

@export var angular_speed: float = 1.3
@export var inner_radius: float = 150.0
@export var outer_radius: float = 240.0
@export var lane_switch_duration: float = 0.10

@onready var shift_sound: AudioStreamPlayer = ($ShiftSound)

var angle: float = -PI / 2.0

var is_on_inner_lane: bool = false
var current_radius: float
var target_radius: float
var gilded_skin_enabled: bool = false

var last_switch_time: int = -1000

# Lap recording
var lap_distance: float = 0.0
var lap_number: int = 0
var current_lap_path: PackedFloat32Array = PackedFloat32Array()
var input_locked_until: int = 0


func _ready() -> void:
	# Player occupies collision layer 1.
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true

	current_radius = outer_radius
	target_radius = outer_radius

	position = Vector2.from_angle(angle) * current_radius
	current_lap_path.append(current_radius)

	queue_redraw()


func _process(delta: float) -> void:
	var angular_movement: float = angular_speed * delta

	angle = fposmod(angle + angular_movement, TAU)
	lap_distance += angular_movement

	var lane_distance: float = absf(
		outer_radius - inner_radius
	)

	var lane_speed: float = (
		lane_distance / lane_switch_duration
	)

	current_radius = move_toward(
		current_radius,
		target_radius,
		lane_speed * delta
	)

	position = Vector2.from_angle(angle) * current_radius

	# Record the exact radius occupied during this frame.
	current_lap_path.append(current_radius)

	if lap_distance >= TAU:
		lap_distance -= TAU
		_complete_lap()


func _complete_lap() -> void:
	lap_number += 1

	var completed_path: PackedFloat32Array = (
		current_lap_path.duplicate()
	)

	current_lap_path.clear()
	current_lap_path.append(current_radius)



	lap_completed.emit(
		completed_path,
		angular_speed
	)


func _unhandled_input(event: InputEvent) -> void:
	if Time.get_ticks_msec() < input_locked_until:
		return

	var switch_pressed: bool = false

	if event is InputEventScreenTouch:
		switch_pressed = event.pressed

	elif event is InputEventMouseButton:
		switch_pressed = (
			event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		)

	elif event is InputEventKey:
		switch_pressed = (
			event.keycode == KEY_SPACE
			and event.pressed
			and not event.echo
		)

	if not switch_pressed:
		return

	var current_time: int = Time.get_ticks_msec()

	if current_time - last_switch_time < 80:
		return

	last_switch_time = current_time
	_switch_lane()


func _switch_lane() -> void:
	var previous_radius: float = current_radius

	is_on_inner_lane = not is_on_inner_lane

	if is_on_inner_lane:
		target_radius = inner_radius
	else:
		target_radius = outer_radius

	lane_switched.emit(
		angle,
		previous_radius,
		target_radius
	)

	if shift_sound.stream != null:
		shift_sound.pitch_scale = randf_range(
			0.96,
			1.04
		)
		shift_sound.play()

	SettingsManager.vibrate(18, 0.20)


func _draw() -> void:
	if gilded_skin_enabled:
		_draw_gilded_skin()
	else:
		_draw_default_skin()


func _draw_default_skin() -> void:
	draw_circle(
		Vector2.ZERO,
		26.0,
		Color(0.1, 0.95, 1.0, 0.10)
	)

	draw_circle(
		Vector2.ZERO,
		18.0,
		Color(0.1, 0.95, 1.0, 0.22)
	)

	draw_circle(
		Vector2.ZERO,
		12.0,
		Color("#F7F7FF")
	)

	draw_arc(
		Vector2.ZERO,
		15.0,
		0.0,
		TAU,
		32,
		Color("#35F2E8"),
		3.0,
		true
	)


func _draw_gilded_skin() -> void:
	# Golden outer glow.
	draw_circle(
		Vector2.ZERO,
		30.0,
		Color(1.0, 0.75, 0.12, 0.13)
	)

	# Violet secondary glow distinguishes the skin.
	draw_circle(
		Vector2.ZERO,
		21.0,
		Color(0.65, 0.18, 1.0, 0.18)
	)

	draw_circle(
		Vector2.ZERO,
		12.0,
		Color("#FFF2B2")
	)

	draw_arc(
		Vector2.ZERO,
		16.0,
		0.0,
		TAU,
		32,
		Color("#FFD54A"),
		4.0,
		true
	)

	# Four golden energy points.
	for index: int in range(4):
		var point_angle: float = (
			float(index) * TAU / 4.0
		)

		var direction: Vector2 = (
			Vector2.from_angle(point_angle)
		)

		draw_line(
			direction * 19.0,
			direction * 25.0,
			Color("#FFD54A"),
			3.0,
			true
		)
func lock_lane_switching(duration_ms: int) -> void:
	input_locked_until = (Time.get_ticks_msec() + duration_ms)
	
func set_gilded_skin(enabled: bool) -> void:
	gilded_skin_enabled = enabled
	queue_redraw()
