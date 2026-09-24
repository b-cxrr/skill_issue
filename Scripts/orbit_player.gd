class_name OrbitPlayer
extends Area2D

signal lap_completed(path: PackedFloat32Array,recorded_speed: float)
signal lane_switched(switch_angle: float,from_radius: float,to_radius: float)

@export var angular_speed: float = 1.3
@export var inner_radius: float = 150.0
@export var outer_radius: float = 240.0
@export var lane_switch_duration: float = 0.10

@onready var shift_sound: AudioStreamPlayer = ($ShiftSound)

const STARTING_ANGLE: float = -PI / 2.0
const PATH_SEGMENTS: int = 360

var angle: float = STARTING_ANGLE

var is_on_inner_lane: bool = false
var current_radius: float
var target_radius: float
var active_skin: String = (
	SaveManager.DEFAULT_SKIN
)

var last_switch_time: int = -1000

# Lap recording
var lap_distance: float = 0.0
var lap_number: int = 0
var current_lap_path: PackedFloat32Array = PackedFloat32Array()
var input_locked_until: int = 0

var power_up_visual_active: bool = false
var power_up_visual_colour: Color = Color.WHITE
var power_up_visual_time: float = 0.0
var power_up_remaining_ratio: float = 1.0
var skin_visual_time: float = 0.0
var preview_mode: bool = false


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
	skin_visual_time += delta

	if _skin_has_dynamic_effect():
		queue_redraw()

	# Cosmetic previews animate their appearance,
	# but must not orbit or record gameplay.
	if preview_mode:
		return

	if power_up_visual_active:
		power_up_visual_time += delta
		queue_redraw()


func _physics_process(delta: float) -> void:
	if preview_mode or angular_speed <= 0.0:
		return
	var completed_paths: Array[PackedFloat32Array] = []
	var remaining: float = delta
	var lane_speed: float = absf(outer_radius - inner_radius) / maxf(lane_switch_duration, 0.001)
	while remaining > 0.000001:
		# Split exactly at the lap seam; neither recording inherits an overshoot.
		var seconds_to_seam: float = (TAU - lap_distance) / angular_speed
		var step: float = minf(remaining, seconds_to_seam)
		var old_distance: float = lap_distance
		var old_radius: float = current_radius
		lap_distance += angular_speed * step
		current_radius = move_toward(current_radius, target_radius, lane_speed * step)
		# Uniform angular samples, regardless of render FPS or physics tick rate.
		while current_lap_path.size() <= PATH_SEGMENTS:
			var sample_angle: float = float(current_lap_path.size()) * TAU / float(PATH_SEGMENTS)
			if sample_angle > lap_distance + 0.000001:
				break
			var sample_time: float = maxf(0.0, (sample_angle - old_distance) / angular_speed)
			current_lap_path.append(move_toward(old_radius, target_radius, lane_speed * sample_time))
		angle = fposmod(STARTING_ANGLE + lap_distance, TAU)
		position = Vector2.from_angle(angle) * current_radius
		remaining -= step
		if step >= seconds_to_seam:
			lap_distance = 0.0
			angle = fposmod(STARTING_ANGLE, TAU)
			position = Vector2.from_angle(angle) * current_radius
			completed_paths.append(_complete_lap())
	# Spawn hazards after the entire physics step, using the actual current position.
	for path: PackedFloat32Array in completed_paths:
		lap_completed.emit(path, angular_speed)


func _complete_lap() -> PackedFloat32Array:
	lap_number += 1

	var completed_path: PackedFloat32Array = (
		current_lap_path.duplicate()
	)

	current_lap_path.clear()
	current_lap_path.append(current_radius)



	return completed_path


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
	match active_skin:
		SaveManager.GILDED_SKIN:
			_draw_gilded_skin()

		SaveManager.CRIMSON_SKIN:
			_draw_crimson_skin()

		SaveManager.VOLTAGE_SKIN:
			_draw_voltage_skin()

		SaveManager.GLITCH_SKIN:
			_draw_glitch_skin()

		_:
			_draw_default_skin()

	if power_up_visual_active:
		_draw_power_up_visual()


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
	var gold: Color = Color("#FFD54A")
	var violet: Color = Color("#A62EFF")

	var shimmer: float = (
		sin(skin_visual_time * 3.0)
		+ 1.0
	) * 0.5

	draw_circle(
		Vector2.ZERO,
		30.0 + shimmer * 2.0,
		Color(
			1.0,
			0.75,
			0.12,
			0.10 + shimmer * 0.06
		)
	)

	draw_circle(
		Vector2.ZERO,
		21.0,
		Color(
			violet.r,
			violet.g,
			violet.b,
			0.14 + shimmer * 0.08
		)
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
		gold,
		4.0,
		true
	)

	var rotation_offset: float = (
		skin_visual_time * 0.8
	)

	for index: int in range(4):
		var point_angle: float = (
			rotation_offset
			+ float(index) * TAU / 4.0
		)

		var direction: Vector2 = (
			Vector2.from_angle(
				point_angle
			)
		)

		draw_line(
			direction * 19.0,
			direction * 25.0,
			gold,
			3.0,
			true
		)
func _draw_crimson_skin() -> void:
	var crimson: Color = Color("#FF315F")

	var beat_cycle: float = fposmod(
		skin_visual_time,
		1.15
	)

	var heartbeat: float = 0.0

	if beat_cycle < 0.12:
		heartbeat = sin(
			(beat_cycle / 0.12) * PI
		)

	elif (
		beat_cycle >= 0.20
		and beat_cycle < 0.31
	):
		heartbeat = (
			sin(
				(
					(beat_cycle - 0.20)
					/ 0.11
				) * PI
			)
			* 0.55
		)

	draw_circle(
		Vector2.ZERO,
		28.0 + heartbeat * 4.0,
		Color(
			1.0,
			0.10,
			0.24,
			0.10 + heartbeat * 0.09
		)
	)

	draw_circle(
		Vector2.ZERO,
		19.0 + heartbeat * 1.5,
		Color(
			1.0,
			0.10,
			0.24,
			0.18
		)
	)

	draw_circle(
		Vector2.ZERO,
		12.0,
		Color("#FFF2F5")
	)

	draw_arc(
		Vector2.ZERO,
		16.0 + heartbeat,
		0.0,
		TAU,
		32,
		crimson,
		3.5,
		true
	)

	draw_arc(
		Vector2.ZERO,
		22.0 + heartbeat * 3.0,
		-PI * 0.75,
		PI * 0.15,
		20,
		Color(
			crimson.r,
			crimson.g,
			crimson.b,
			0.25 + heartbeat * 0.40
		),
		2.0,
		true
	)

	draw_line(
		Vector2(-6.0, 0.0),
		Vector2(6.0, 0.0),
		crimson,
		2.0,
		true
	)
func _draw_voltage_skin() -> void:
	var voltage: Color = Color("#B8FF3D")
	var hot_core: Color = Color("#F5FFD9")

	# Quantised time makes the electricity snap between
	# states rather than smoothly rotating.
	var electric_tick: int = int(
		skin_visual_time * 22.0
	)

	var flicker: float = (
		sin(float(electric_tick) * 3.71)
		+ 1.0
	) * 0.5

	var core_radius: float = (
		11.0 + flicker * 2.0
	)

	# Unstable outer electrical glow.
	draw_circle(
		Vector2.ZERO,
		30.0 + flicker * 5.0,
		Color(
			voltage.r,
			voltage.g,
			voltage.b,
			0.07 + flicker * 0.09
		)
	)

	draw_circle(
		Vector2.ZERO,
		core_radius,
		hot_core
	)

	draw_arc(
		Vector2.ZERO,
		16.0,
		0.0,
		TAU,
		32,
		voltage,
		3.5,
		true
	)

	# Draw several independently flickering lightning bolts.
	for bolt_index: int in range(5):
		var bolt_seed: float = (
			float(
				electric_tick * 17
				+ bolt_index * 43
			)
		)

		var bolt_angle: float = fposmod(
			sin(bolt_seed * 0.173) * 17.0
			+ float(bolt_index) * TAU / 5.0,
			TAU
		)

		var direction: Vector2 = (
			Vector2.from_angle(
				bolt_angle
			)
		)

		var perpendicular: Vector2 = Vector2(
			-direction.y,
			direction.x
		)

		var jitter_1: float = (
			sin(bolt_seed * 1.91) * 5.0
		)

		var jitter_2: float = (
			sin(bolt_seed * 2.73) * 6.0
		)

		var bolt_length: float = (
			31.0
			+ absf(
				sin(bolt_seed * 0.83)
			) * 10.0
		)

		var bolt_points: PackedVector2Array = (
			PackedVector2Array()
		)

		bolt_points.append(
			direction * 17.0
		)

		bolt_points.append(
			direction * 22.0
			+ perpendicular * jitter_1
		)

		bolt_points.append(
			direction * 27.0
			+ perpendicular * jitter_2
		)

		bolt_points.append(
			direction * bolt_length
		)

		# Bright electrical under-layer.
		draw_polyline(
			bolt_points,
			Color(
				1.0,
				1.0,
				0.85,
				0.75
			),
			3.5,
			true
		)

		# Green electrical core.
		draw_polyline(
			bolt_points,
			voltage,
			1.8,
			true
		)

	# Brief random-looking corona sparks.
	for spark_index: int in range(4):
		var spark_seed: float = float(
			electric_tick * 29
			+ spark_index * 61
		)

		var spark_angle: float = fposmod(
			sin(spark_seed * 0.37)
				* 13.0,
			TAU
		)

		var spark_direction: Vector2 = (
			Vector2.from_angle(
				spark_angle
			)
		)

		var spark_start: float = (
			21.0
			+ absf(
				sin(spark_seed)
			) * 5.0
		)

		draw_line(
			spark_direction * spark_start,
			spark_direction
				* (spark_start + 5.0),
			hot_core,
			2.0,
			true
		)

func _draw_glitch_skin() -> void:
	var cyan: Color = Color("#35F2E8")
	var magenta: Color = Color("#FF4FD8")
	var core_colour: Color = Color("#F7F7FF")

	# Glitch state changes abruptly rather than
	# interpolating smoothly.
	var glitch_tick: int = int(
		skin_visual_time * 20.0
	)

	var state: int = (
		glitch_tick % 17
	)

	var major_glitch: bool = (
		state == 3
		or state == 4
		or state == 11
	)

	var minor_glitch: bool = (
		major_glitch
		or state == 7
		or state == 14
	)

	var split_x: float = 2.0
	var split_y: float = 0.0

	if minor_glitch:
		split_x = (
			4.0
			+ absf(
				sin(
					float(glitch_tick) * 2.71
				)
			) * 4.0
		)

		split_y = (
			sin(
				float(glitch_tick) * 4.13
			) * 3.0
		)

	if major_glitch:
		split_x += 5.0
		split_y *= 1.8

	# Background chromatic ghosts.
	draw_circle(
		Vector2(
			-split_x,
			split_y
		),
		13.0,
		Color(
			cyan.r,
			cyan.g,
			cyan.b,
			0.28
		)
	)

	draw_circle(
		Vector2(
			split_x,
			-split_y
		),
		13.0,
		Color(
			magenta.r,
			magenta.g,
			magenta.b,
			0.28
		)
	)

	# During a major glitch, briefly displace
	# the actual white core too.
	var core_offset: Vector2 = Vector2.ZERO

	if major_glitch:
		core_offset = Vector2(
			sin(
				float(glitch_tick) * 7.3
			) * 4.0,
			sin(
				float(glitch_tick) * 3.9
			) * 2.0
		)

	draw_circle(
		core_offset,
		12.0,
		core_colour
	)

	# Misregistered ring halves.
	draw_arc(
		Vector2(
			-split_x,
			split_y
		),
		16.0,
		-PI * 0.48,
		PI * 0.48,
		18,
		cyan,
		3.5,
		true
	)

	draw_arc(
		Vector2(
			split_x,
			-split_y
		),
		16.0,
		PI * 0.52,
		PI * 1.48,
		18,
		magenta,
		3.5,
		true
	)

	# Horizontal digital tearing.
	for slice_index: int in range(4):
		var slice_seed: float = float(
			glitch_tick * 31
			+ slice_index * 47
		)

		var slice_y: float = (
			-10.0
			+ float(slice_index) * 7.0
		)

		var tear_amount: float = 0.0

		if minor_glitch:
			tear_amount = (
				sin(slice_seed * 0.83)
				* (
					6.0
					if major_glitch
					else 3.5
				)
			)

		draw_line(
			Vector2(
				-22.0 + tear_amount,
				slice_y
			),
			Vector2(
				-8.0 + tear_amount,
				slice_y
			),
			magenta,
			2.0,
			true
		)

		draw_line(
			Vector2(
				8.0 - tear_amount,
				slice_y + 2.0
			),
			Vector2(
				22.0 - tear_amount,
				slice_y + 2.0
			),
			cyan,
			2.0,
			true
		)

	# Occasional vertical corruption spike.
	if major_glitch:
		var spike_x: float = (
			sin(
				float(glitch_tick) * 5.37
			) * 14.0
		)

		draw_line(
			Vector2(
				spike_x,
				-25.0
			),
			Vector2(
				spike_x + 3.0,
				25.0
			),
			Color(
				cyan.r,
				cyan.g,
				cyan.b,
				0.65
			),
			1.5,
			true
		)

		draw_line(
			Vector2(
				spike_x + 4.0,
				-21.0
			),
			Vector2(
				spike_x + 1.0,
				21.0
			),
			Color(
				magenta.r,
				magenta.g,
				magenta.b,
				0.65
			),
			1.5,
			true
		)

func lock_lane_switching(duration_ms: int) -> void:
	input_locked_until = (Time.get_ticks_msec() + duration_ms)

func set_skin(
	skin_name: String
) -> void:
	active_skin = skin_name
	skin_visual_time = 0.0
	queue_redraw()

func get_skin_effect_colour() -> Color:
	match active_skin:
		SaveManager.GILDED_SKIN:
			return Color("#FFD54A")

		SaveManager.CRIMSON_SKIN:
			return Color("#FF315F")

		SaveManager.VOLTAGE_SKIN:
			return Color("#B8FF3D")

		SaveManager.GLITCH_SKIN:
			return Color("#FF4FD8")

		_:
			return Color("#35F2E8")

# Compatibility helper for any older calls.
func set_gilded_skin(
	enabled: bool
) -> void:
	if enabled:
		set_skin(
			SaveManager.GILDED_SKIN
		)
	else:
		set_skin(
			SaveManager.DEFAULT_SKIN
		)
func _draw_power_up_visual() -> void:
	var pulse_speed: float = 7.0

	# Become increasingly frantic shortly before expiry.
	if power_up_remaining_ratio <= 0.25:
		pulse_speed = 15.0

	var pulse: float = (
		sin(power_up_visual_time * pulse_speed)
		+ 1.0
	) * 0.5

	var glow_colour: Color = Color(
		power_up_visual_colour.r,
		power_up_visual_colour.g,
		power_up_visual_colour.b,
		0.10 + pulse * 0.10
	)

	draw_circle(
		Vector2.ZERO,
		34.0 + pulse * 4.0,
		glow_colour
	)

	draw_arc(
		Vector2.ZERO,
		29.0 + pulse * 2.0,
		0.0,
		TAU,
		40,
		Color(
			power_up_visual_colour.r,
			power_up_visual_colour.g,
			power_up_visual_colour.b,
			0.60 + pulse * 0.30
		),
		3.0,
		true
	)
func set_power_up_visual(
	active: bool,
	colour: Color = Color.WHITE
) -> void:
	power_up_visual_active = active
	power_up_visual_colour = colour

	if active:
		power_up_visual_time = 0.0
		power_up_remaining_ratio = 1.0

	queue_redraw()


func set_power_up_visual_ratio(
	ratio: float
) -> void:
	power_up_remaining_ratio = clampf(
		ratio,
		0.0,
		1.0
	)
func _skin_has_dynamic_effect() -> bool:
	match active_skin:
		SaveManager.GILDED_SKIN:
			return true

		SaveManager.CRIMSON_SKIN:
			return true

		SaveManager.VOLTAGE_SKIN:
			return true

		SaveManager.GLITCH_SKIN:
			return true

	return false


func set_preview_mode(
	enabled: bool
) -> void:
	preview_mode = enabled
	skin_visual_time = 0.0
	queue_redraw()
