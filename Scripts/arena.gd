extends Node2D

@onready var points_label: Label = %PointsLabel
@onready var risk_label: Label = %RiskLabel
@onready var player: OrbitPlayer = $Player
@onready var score_label: Label = (%ScoreLabel)
@onready var game_over_center: CenterContainer = (%GameOverCenter)
@onready var final_score_label: Label = (%FinalScoreLabel)
@onready var best_score_label: Label = (%BestScoreLabel)
@onready var gates_container: Node2D = $Gates
@onready var start_center: CenterContainer = (%StartCenter)
@onready var hit_flash: ColorRect = (%HitFlash)
@onready var lap_sound: AudioStreamPlayer = ($LapSound)
@onready var shift_trail: Line2D = ($ShiftTrail)
@onready var collision_sound: AudioStreamPlayer = ($CollisionSound)
@onready var start_label: Label = (%StartLabel)
@onready var burst_particles: BurstParticles = ($BurstParticles)
@onready var achievement_label: Label = (%AchievementLabel)
@onready var skin_button: Button = (%SkinButton)
@onready var game_over_vbox: VBoxContainer = (%GameOverVBox)
@onready var leaderboards_button: Button = %LeaderboardsButton
@onready var near_miss_label: Label = (%NearMissLabel)
@onready var pause_menu: SkillPauseMenu = (%PauseMenu)
@onready var game_over_overlay: ColorRect = (%GameOverOverlay)
@onready var stats_label: Label = (%StatsLabel)
@onready var visual_controller: Node2D = $VisualController
@onready var power_ups_container: Node2D = $PowerUps
@onready var power_up_hud: Control = %PowerUpHUD
@onready var power_up_name_label: Label = %PowerUpNameLabel
@onready var power_up_timer_fill: ColorRect = %PowerUpTimerFill



@export var maximum_echoes: int = 1
@export var gate_scene: PackedScene
@export var inner_radius: float = 150.0
@export var outer_radius: float = 240.0
@export var echo_scene: PackedScene
@export var power_up_scene: PackedScene

@export_category("Developer Capture")
@export_range(0, 100, 1)
var dev_start_round: int = 0

var ring_colour: Color = Color("#303040")
var inner_glow_colour: Color = Color("#183F46")
var echo_count: int = 0
var is_game_over: bool = false
var restart_allowed_at: int = 0
var current_round: int = 0
var current_points: int = 0
var game_started: bool = false
var run_is_ranked: bool = true
var collision_flash_tween: Tween
var collision_shake_tween: Tween
var shift_trail_tween: Tween
var near_miss_tween: Tween
var risk_tween: Tween
var hazard_close_states: Dictionary = {}
var lap_pulse_tween: Tween
var lap_pulse_radius: float = 0.0
var lap_pulse_alpha: float = 0.0
var score_tween: Tween
var start_prompt_tween: Tween
var game_over_tween: Tween
var achievement_tween: Tween
var current_near_misses: int = 0
var risk_multiplier: float = 1.0
var last_near_miss_time: int = 0
var echo_breaker_active: bool = false
var gate_breaker_active: bool = false

var power_up_time_remaining: float = 0.0
var power_up_duration: float = 0.0

var laps_since_power_up: int = 0
var echoes_destroyed_this_run: int = 0

const LAP_POINTS: int = 100
const NEAR_MISS_POINTS: int = 50
const RISK_MULTIPLIER_STEP: float = 0.5
const MAX_RISK_MULTIPLIER: float = 3.0
const RISK_TIMEOUT_MS: int = 3000
# Phase Gate layout rules.
const GATE_START_SAFE_ANGLE: float = PI / 3.0
const GATE_MIN_SAME_LANE_SEPARATION: float = 0.40
const GATE_MIN_OPPOSITE_LANE_SEPARATION: float = 0.50
const GATE_LAYOUT_ATTEMPTS: int = 40
const GATE_PLACEMENT_ATTEMPTS: int = 20
# Echo-aware Phase Gate safety.
const ECHO_GATE_SAFETY_DISTANCE: float = 46.0
const ECHO_GATE_TIME_MARGIN: float = 0.15
const ECHO_GATE_SAFETY_SAMPLES: int = 5

const ECHO_DESTROY_POINTS: int = 250

const POWER_UP_START_ROUND: int = 7
const POWER_UP_SPAWN_CHANCE: float = 0.40
const POWER_UP_MIN_LAP_GAP: int = 2

const POWER_UP_START_SAFE_ANGLE: float = PI / 3.0
const POWER_UP_GATE_SAFE_DISTANCE: float = 55.0
const POWER_UP_ECHO_SAFE_DISTANCE: float = 70.0

const ECHO_BREAKER_DURATION: float = 5.0
const GATE_BREAKER_DURATION: float = 5.0

const POWER_UP_TIMER_WIDTH: float = 240.0

const ECHO_BREAKER_COLOUR: Color = Color("#B06CFF")
const GATE_BREAKER_COLOUR: Color = Color("#FFD54A")

func _ready() -> void:
	power_up_hud.visible = false
	
	risk_label.visible = false
	near_miss_label.visible = false
	
	player.set_gilded_skin(
		SaveManager.is_gilded_skin_selected()
	)
	game_over_overlay.visible = false
	achievement_label.visible = false
	
	skin_button.pressed.connect(_on_skin_button_pressed)

	leaderboards_button.pressed.connect(
		_on_leaderboards_button_pressed
	)

	_update_skin_button()
	pause_menu.call_deferred("set_gameplay_available",false)
	
	get_viewport().size_changed.connect(_centre_arena)
	player.lap_completed.connect(_on_player_lap_completed)
	player.lane_switched.connect(_on_player_lane_switched)

	game_over_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	game_over_center.visible = false
	_apply_developer_capture_start()
	_update_round_display()
	_update_points_display()
	
	start_center.visible = true
	score_label.visible = false
	points_label.visible = false
	_animate_start_prompt()

	player.set_process(false)
	player.set_process_unhandled_input(false)

	_centre_arena()
	_generate_gates()

	queue_redraw()


func _apply_developer_capture_start() -> void:
	run_is_ranked = true

	# Round skipping is intentionally available only in debug builds.
	# Leaving dev_start_round above 0 cannot affect a release build.
	if not OS.is_debug_build():
		return

	if dev_start_round <= 0:
		return

	current_round = dev_start_round
	current_points = dev_start_round * LAP_POINTS
	run_is_ranked = false

	# Match the late-game visual state immediately without firing a
	# milestone shockwave before the player has actually completed a lap.
	visual_controller.update_intensity(current_round)

	print(
		"DEV CAPTURE MODE - ROUND %d - RECORDS DISABLED"
		% current_round
	)


func _centre_arena() -> void:
	position = get_viewport_rect().size * 0.5


func _on_player_lap_completed(
	path: PackedFloat32Array,
	recorded_speed: float
) -> void:
	current_round += 1
	current_points += LAP_POINTS

	visual_controller.lap_completed(
		current_round
	)

	_update_round_display()
	_update_points_display()
	_check_level_10_achievement()
	_animate_score()

	if lap_sound.stream != null:
		lap_sound.play()

	SettingsManager.vibrate(
		35,
		0.35
	)

	# Before Echoes begin, gates can be generated normally.
	if current_round < 7:
		_generate_gates()
		return

	if echo_scene == null:
		push_warning(
			"No Echo scene assigned to Arena."
		)
		_generate_gates()
		_try_spawn_power_up()
		return

	echo_count += 1

	var echo: OrbitEcho = (
		echo_scene.instantiate() as OrbitEcho
	)

	if echo == null:
		push_warning(
			"The assigned scene is not an OrbitEcho."
		)
		_generate_gates()
		_try_spawn_power_up()
		return

	var phase_offset: float = (
		float(echo_count) * 0.35
	)

	echo.setup(
		path,
		recorded_speed,
		phase_offset,
		_get_echo_speed_multiplier(),
		_get_echo_warning_time(),
		_get_echo_collision_radius()
	)

	add_child(echo)

	echo.player_hit.connect(
		_on_hazard_hit_player
	)

	_limit_active_echoes()

	# Now generate the new lap's gates while taking
	# the active Echo into account.
	_generate_gates(echo)
	_try_spawn_power_up()

func _draw() -> void:
	draw_arc(Vector2.ZERO,inner_radius,0.0,TAU,128,inner_glow_colour,12.0,true)

	draw_arc(Vector2.ZERO,inner_radius,0.0,TAU,128,ring_colour,4.0,true)

	draw_arc(Vector2.ZERO,outer_radius,0.0,TAU,128,ring_colour,4.0,true)
	
	if lap_pulse_alpha > 0.0:
		draw_arc(Vector2.ZERO,lap_pulse_radius,0.0,TAU,128,Color(0.2,0.95,0.9,lap_pulse_alpha),7.0,true)

func _on_hazard_hit_player(
	hazard: Node2D
) -> void:
	if is_game_over:
		return

	if (
		echo_breaker_active
		and hazard is OrbitEcho
	):
		_destroy_echo_with_power_up(
			hazard as OrbitEcho
		)
		return

	if (
		gate_breaker_active
		and hazard is PhaseGate
	):
		_destroy_gate_with_power_up(
			hazard as PhaseGate
		)
		return

	is_game_over = true

	_deactivate_power_up()
	_highlight_hazard(hazard)
	pause_menu.set_gameplay_available(false)
	_play_collision_effect()
	burst_particles.create_burst(
		player.position,
		Color("#FF315F"),
		28,
		90.0,
		230.0,
		0.55
	)

	burst_particles.create_burst(
		player.position,
		Color("#35F2E8"),
		14,
		65.0,
		180.0,
		0.42
	)
	
	if collision_sound.stream != null:
		collision_sound.play()

	SettingsManager.vibrate(160, 0.85)
	restart_allowed_at = Time.get_ticks_msec() + 350

	var run_results: Dictionary = {}

	if run_is_ranked:
		run_results = SaveManager.record_completed_run(
			current_round,
			current_points,
			current_near_misses
		)

		LeaderboardManager.sync_saved_records()
	else:
		print(
			"DEV CAPTURE MODE - RUN NOT SAVED OR SUBMITTED"
		)

	var got_new_best_round: bool = bool(
		run_results.get(
			"new_best_round",
			false
		)
	)

	var got_new_best_points: bool = bool(
		run_results.get(
			"new_best_points",
			false
		)
	)

	final_score_label.text = (
		"ROUND %d\nSCORE %d"
		% [
			current_round,
			current_points
		]
	)

	best_score_label.text = (
		"BEST SCORE %d\nHIGHEST ROUND %d"
		% [
			SaveManager.best_points,
			SaveManager.best_round
		]
	)

	if (
		got_new_best_points
		and got_new_best_round
	):
		best_score_label.text += (
			"\nNEW SCORE + ROUND RECORD"
		)

	elif got_new_best_points:
		best_score_label.text += (
			"\nNEW HIGH SCORE"
		)

	elif got_new_best_round:
		best_score_label.text += (
			"\nNEW BEST ROUND"
		)

	stats_label.text = (
	"NEAR MISSES %d  |  TOTAL %d\n"
	+ "ECHOES DESTROYED %d  |  TOTAL %d\n"
	+ "RUNS %d  |  LAPS %d"
) % [
	current_near_misses,
	SaveManager.total_near_misses,
	echoes_destroyed_this_run,
	SaveManager.total_echoes_destroyed,
	SaveManager.total_runs,
	SaveManager.total_laps
]

	_show_game_over()
	score_label.visible = false
	points_label.visible = false
	risk_label.visible = false

	player.set_process(false)
	player.set_process_unhandled_input(false)

	player.modulate = Color("#FF315F")
	player.scale = Vector2(1.35, 1.35)

	for child: Node in get_children():
		if child is OrbitEcho:
			child.set_process(false)
			child.set_deferred("monitoring", false)

func _destroy_echo_with_power_up(
	echo: OrbitEcho
) -> void:
	if not is_instance_valid(echo):
		return

	hazard_close_states.erase(
		echo.get_instance_id()
	)

	current_points += ECHO_DESTROY_POINTS
	echoes_destroyed_this_run += 1

	if run_is_ranked:
		SaveManager.record_echo_destroyed()

	_update_points_display()
	_animate_score()

	burst_particles.create_burst(
		echo.position,
		ECHO_BREAKER_COLOUR,
		30,
		90.0,
		240.0,
		0.50
	)

	burst_particles.create_burst(
		echo.position,
		Color.WHITE,
		12,
		55.0,
		160.0,
		0.30
	)

	SettingsManager.vibrate(
		60,
		0.60
	)

	echo.set_deferred(
		"monitoring",
		false
	)

	echo.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = false

	if event is InputEventScreenTouch:
		pressed = event.pressed

	elif event is InputEventMouseButton:
		pressed = (
			event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		)

	elif event is InputEventKey:
		pressed = (
			event.keycode == KEY_SPACE
			and event.pressed
			and not event.echo
		)

	if not pressed:
		return

	if not game_started:
		_start_game()

		# Prevent the starting tap from also switching lanes.
		get_viewport().set_input_as_handled()
		return

	if not is_game_over:
		return

	if Time.get_ticks_msec() < restart_allowed_at:
		return

	get_tree().reload_current_scene()
		
func _update_round_display() -> void:
	score_label.text = "ROUND %d" % current_round


func _update_points_display() -> void:
	points_label.text = "SCORE: %d" % current_points

func _generate_gates(
	active_echo: OrbitEcho = null
) -> void:
	if gate_scene == null:
		push_warning("No PhaseGate scene assigned.")
		return

	# Remove the previous lap's gates.
	for child: Node in gates_container.get_children():
		hazard_close_states.erase(
			child.get_instance_id()
		)

		if child is Area2D:
			var old_gate: Area2D = child as Area2D
			old_gate.set_deferred(
				"monitoring",
				false
			)

		child.queue_free()

	var gate_total: int = _get_gate_total()

	if gate_total <= 0:
		return

	var layout: Array[Dictionary] = (
		_build_gate_layout(
			gate_total,
			active_echo
		)
	)

	for gate_data: Dictionary in layout:
		var gate_angle: float = float(
			gate_data["angle"]
		)

		var blocks_inner: bool = bool(
			gate_data["blocks_inner"]
		)

		var gate_radius: float

		if blocks_inner:
			gate_radius = inner_radius
		else:
			gate_radius = outer_radius

		var gate: PhaseGate = (
			gate_scene.instantiate() as PhaseGate
		)

		if gate == null:
			push_warning(
				"The assigned gate scene is not a PhaseGate."
			)
			return

		gates_container.add_child(gate)

		gate.configure_gate(
			gate_angle,
			gate_radius,
			blocks_inner
		)

		gate.player_hit.connect(
			_on_hazard_hit_player
		)
func _build_gate_layout(
	gate_total: int,
	active_echo: OrbitEcho = null
) -> Array[Dictionary]:
	for layout_attempt: int in range(
		GATE_LAYOUT_ATTEMPTS
	):
		var layout: Array[Dictionary] = []
		var layout_valid: bool = true

		for index: int in range(gate_total):
			var placement_found: bool = false

			for placement_attempt: int in range(
				GATE_PLACEMENT_ATTEMPTS
			):
				# Pick a genuinely random position anywhere
				# outside the protected player-start zone.
				var candidate_offset: float = randf_range(
					GATE_START_SAFE_ANGLE,
					TAU - GATE_START_SAFE_ANGLE
				)

				var candidate_angle: float = fposmod(
					player.angle + candidate_offset,
					TAU
				)

				var candidate_blocks_inner: bool = (
					randi_range(0, 1) == 0
				)

				if not _is_gate_candidate_valid(
					candidate_angle,
					candidate_blocks_inner,
					layout,
					active_echo
				):
					continue

				layout.append(
					{
						"angle": candidate_angle,
						"blocks_inner":
							candidate_blocks_inner
					}
				)

				placement_found = true
				break

			if not placement_found:
				layout_valid = false
				break

		# With 3+ gates, make sure both tracks
		# actually participate in the layout.
		if (
			layout_valid
			and gate_total >= 3
			and not _layout_uses_both_lanes(layout)
		):
			layout_valid = false

		if layout_valid:
			return layout

	return _build_safe_gate_layout(
	gate_total,
	active_echo
)
		
		
	


func _is_gate_candidate_valid(
	candidate_angle: float,
	candidate_blocks_inner: bool,
	existing_layout: Array[Dictionary],
	active_echo: OrbitEcho = null
) -> bool:
	# Keep a clear safety zone on BOTH sides of the player's
	# current position. This also catches gates that wrap around
	# from the end of the circle and appear just behind the player.
	var player_separation: float = (
		_circular_angle_distance(
			candidate_angle,
			player.angle
		)
	)

	if player_separation < GATE_START_SAFE_ANGLE:
		return false

	for gate_data: Dictionary in existing_layout:
		var existing_angle: float = float(
			gate_data["angle"]
		)

		var existing_blocks_inner: bool = bool(
			gate_data["blocks_inner"]
		)

		var separation: float = (
			_circular_angle_distance(
				candidate_angle,
				existing_angle
			)
		)

		var same_lane: bool = (
			candidate_blocks_inner
			== existing_blocks_inner
		)

		if same_lane:
			# Same-lane gates are allowed to sit fairly
			# close together because the opposite lane
			# remains completely open.
			if (
				separation
				< GATE_MIN_SAME_LANE_SEPARATION
			):
				return false

		else:
			# Opposite-lane gates need a larger gap so
			# they can never form a parallel double wall.
			if (
				separation
				< GATE_MIN_OPPOSITE_LANE_SEPARATION
			):
				return false
		if not _is_gate_echo_safe(
		candidate_angle,
		candidate_blocks_inner,
		active_echo
	):
			return false
	return true
func _is_gate_echo_safe(
	candidate_angle: float,
	candidate_blocks_inner: bool,
	active_echo: OrbitEcho
) -> bool:
	if active_echo == null:
		return true

	if not is_instance_valid(active_echo):
		return true

	# Because the Player moves clockwise, calculate how
	# much angular distance remains before reaching the gate.
	var forward_angle: float = fposmod(
		candidate_angle - player.angle,
		TAU
	)

	var player_speed: float = maxf(
		absf(player.angular_speed),
		0.001
	)

	var arrival_time: float = (
		forward_angle / player_speed
	)

	# A gate blocking inner forces the player onto outer,
	# and vice versa.
	var required_radius: float

	if candidate_blocks_inner:
		required_radius = outer_radius
	else:
		required_radius = inner_radius

	# Check a short window around the actual crossing.
	# This accounts for movement and lane-switch timing,
	# rather than testing one perfect instant.
	for sample_index: int in range(
		ECHO_GATE_SAFETY_SAMPLES
	):
		var sample_ratio: float = 0.5

		if ECHO_GATE_SAFETY_SAMPLES > 1:
			sample_ratio = (
				float(sample_index)
				/ float(
					ECHO_GATE_SAFETY_SAMPLES - 1
				)
			)

		var time_offset: float = lerpf(
			-ECHO_GATE_TIME_MARGIN,
			ECHO_GATE_TIME_MARGIN,
			sample_ratio
		)

		var sample_time: float = maxf(
			arrival_time + time_offset,
			0.0
		)

		var player_angle_at_sample: float = fposmod(
			player.angle
			+ player.angular_speed * sample_time,
			TAU
		)

		var required_player_position: Vector2 = (
			Vector2.from_angle(
				player_angle_at_sample
			)
			* required_radius
		)

		var predicted_echo_position: Vector2 = (
			active_echo.get_predicted_position(
				sample_time
			)
		)

		if (
			required_player_position.distance_to(
				predicted_echo_position
			)
			< ECHO_GATE_SAFETY_DISTANCE
		):
			return false

	return true

func _layout_uses_both_lanes(
	layout: Array[Dictionary]
) -> bool:
	var has_inner: bool = false
	var has_outer: bool = false

	for gate_data: Dictionary in layout:
		if bool(gate_data["blocks_inner"]):
			has_inner = true
		else:
			has_outer = true

	return has_inner and has_outer


func _build_safe_gate_layout(
	gate_total: int,
	active_echo: OrbitEcho = null
) -> Array[Dictionary]:
	var layout: Array[Dictionary] = []

	var usable_arc: float = (
		TAU
		- GATE_START_SAFE_ANGLE * 2.0
	)

	var spacing: float = (
		usable_arc / float(gate_total + 1)
	)

	for index: int in range(gate_total):
		var gate_angle: float = fposmod(
			player.angle
			+ GATE_START_SAFE_ANGLE
			+ spacing * float(index + 1),
			TAU
		)

		var preferred_blocks_inner: bool = (
			index % 2 == 0
		)

		if _is_gate_candidate_valid(
			gate_angle,
			preferred_blocks_inner,
			layout,
			active_echo
		):
			layout.append(
				{
					"angle": gate_angle,
					"blocks_inner":
						preferred_blocks_inner
				}
			)

			continue

		var opposite_blocks_inner: bool = (
			not preferred_blocks_inner
		)

		if _is_gate_candidate_valid(
			gate_angle,
			opposite_blocks_inner,
			layout,
			active_echo
		):
			layout.append(
				{
					"angle": gate_angle,
					"blocks_inner":
						opposite_blocks_inner
				}
			)

		# If neither lane can be made fair here,
		# deliberately omit this gate.
		# Fewer hazards beats an unavoidable death.

	return layout


func _circular_angle_distance(
	first_angle: float,
	second_angle: float
) -> float:
	return absf(
		wrapf(
			first_angle - second_angle,
			-PI,
			PI
		)
	)






func _limit_active_echoes() -> void:
	var active_echoes: Array[OrbitEcho] = []

	for child: Node in get_children():
		if child is OrbitEcho:
			active_echoes.append(
				child as OrbitEcho
			)

	while active_echoes.size() > maximum_echoes:
		var oldest_echo: OrbitEcho = active_echoes[0]

		oldest_echo.queue_free()
		active_echoes.remove_at(0)
func _start_game() -> void:
	
	pause_menu.set_gameplay_available(true)
	
	if start_prompt_tween != null:
		start_prompt_tween.kill()
	
	game_started = true

	start_center.visible = false
	score_label.visible = true
	points_label.visible = true

	# Blocks Android's emulated mouse event from the starting tap.
	player.lock_lane_switching(200)

	player.set_process(true)
	player.set_process_unhandled_input(true)
	
func _play_collision_effect() -> void:
	if collision_flash_tween != null:
		collision_flash_tween.kill()

	if collision_shake_tween != null:
		collision_shake_tween.kill()

	# Full-screen red flash.
	hit_flash.color = Color(
		1.0,
		0.05,
		0.25,
		0.0
	)

	collision_flash_tween = create_tween()

	collision_flash_tween.tween_property(
		hit_flash,
		"color",
		Color(1.0, 0.05, 0.25, 0.45),
		0.05
	)

	collision_flash_tween.tween_property(
		hit_flash,
		"color",
		Color(1.0, 0.05, 0.25, 0.0),
		0.22
	)

	# Shake only the arena, leaving the UI steady.
	var centre_position: Vector2 = (
		get_viewport_rect().size * 0.5
	)

	collision_shake_tween = create_tween()

	collision_shake_tween.tween_property(
		self,
		"position",
		centre_position + Vector2(12.0, -7.0),
		0.035
	)

	collision_shake_tween.tween_property(
		self,
		"position",
		centre_position + Vector2(-10.0, 6.0),
		0.035
	)

	collision_shake_tween.tween_property(
		self,
		"position",
		centre_position + Vector2(7.0, -4.0),
		0.035
	)

	collision_shake_tween.tween_property(
		self,
		"position",
		centre_position + Vector2(-4.0, 2.0),
		0.035
	)

	collision_shake_tween.tween_property(
		self,
		"position",
		centre_position,
		0.05
	)
func _on_player_lane_switched(
	switch_angle: float,
	from_radius: float,
	to_radius: float
) -> void:
	if shift_trail_tween != null:
		shift_trail_tween.kill()

	var direction: Vector2 = Vector2.from_angle(
		switch_angle
	)

	shift_trail.clear_points()

	shift_trail.add_point(
		direction * from_radius
	)

	shift_trail.add_point(
		direction * to_radius
	)

	shift_trail.width = 11.0
	shift_trail.modulate = Color.WHITE
	shift_trail.visible = true

	shift_trail_tween = create_tween()

	shift_trail_tween.tween_property(shift_trail,"modulate:a",0.0 ,0.24)

	shift_trail_tween.parallel().tween_property(shift_trail, "width", 1.0, 0.24)

	shift_trail_tween.tween_callback(func() -> void: shift_trail.visible = false)

	var burst_position: Vector2 = (
		direction * from_radius
	)

	burst_particles.create_burst(
		burst_position,
		Color("#35F2E8"),
		9,
		45.0,
		110.0,
		0.25
	)

func _play_lap_pulse() -> void:

	if lap_pulse_tween != null:
		lap_pulse_tween.kill()

	lap_pulse_radius = inner_radius
	lap_pulse_alpha = 0.9

	lap_pulse_tween = create_tween()
	lap_pulse_tween.set_parallel(true)

	lap_pulse_tween.tween_method(_set_lap_pulse_radius,inner_radius,outer_radius + 55.0,0.38)

	lap_pulse_tween.tween_method(_set_lap_pulse_alpha,0.9,0.0,0.38)


func _set_lap_pulse_radius(value: float) -> void:
	lap_pulse_radius = value
	queue_redraw()


func _set_lap_pulse_alpha(value: float) -> void:
	lap_pulse_alpha = value
	queue_redraw()
	
func _animate_start_prompt() -> void:
	if start_prompt_tween != null:
		start_prompt_tween.kill()

	start_label.modulate = Color.WHITE

	start_prompt_tween = create_tween()
	start_prompt_tween.set_loops()

	start_prompt_tween.tween_property(
		start_label,
		"modulate:a",
		0.35,
		0.65
	)

	start_prompt_tween.tween_property(
		start_label,
		"modulate:a",
		1.0,
		0.65
	)

func _animate_score() -> void:
	if score_tween != null:
		score_tween.kill()

	score_label.pivot_offset = (
		score_label.size * 0.5
	)

	score_label.scale = Vector2(1.4, 1.4)
	score_label.modulate = Color("#35F2E8")

	score_tween = create_tween()
	score_tween.set_parallel(true)

	score_tween.tween_property(
		score_label,
		"scale",
		Vector2.ONE,
		0.24
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	score_tween.tween_property(
		score_label,
		"modulate",
		Color.WHITE,
		0.30
	)
func _show_game_over() -> void:
	if game_over_tween != null:
		game_over_tween.kill()
	game_over_overlay.visible = true
	game_over_center.visible = true

	game_over_vbox.pivot_offset = (
		game_over_vbox.size * 0.5
	)

	game_over_vbox.scale = Vector2(0.72, 0.72)
	game_over_vbox.modulate = Color(
		1.0,
		1.0,
		1.0,
		0.0
	)

	game_over_tween = create_tween()
	game_over_tween.set_parallel(true)

	game_over_tween.tween_property(
		game_over_vbox,
		"scale",
		Vector2.ONE,
		0.30
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	game_over_tween.tween_property(
		game_over_vbox,
		"modulate:a",
		1.0,
		0.18
	)

func _check_level_10_achievement() -> void:
	if not run_is_ranked:
		return

	if current_round < 10:
		return

	var newly_unlocked: bool = (
		SaveManager.unlock_level_10_skin()
	)

	if not newly_unlocked:
		return

	player.set_gilded_skin(true)
	burst_particles.create_burst(
		player.position,
		Color("#FFD54A"),
		36,
		120.0,
		260.0,
		0.75
	)

	burst_particles.create_burst(
		player.position,
		Color("#B85CFF"),
		18,
		70.0,
		180.0,
		0.65
	)
	_show_achievement()

	SettingsManager.vibrate(100, 0.70)


func _show_achievement() -> void:
	if achievement_tween != null:
		achievement_tween.kill()

	achievement_label.visible = true

	achievement_label.pivot_offset = (
		achievement_label.size * 0.5
	)

	achievement_label.scale = Vector2(0.75, 0.75)
	achievement_label.modulate = Color(
		1.0,
		0.84,
		0.35,
		0.0
	)

	achievement_tween = create_tween()

	achievement_tween.tween_property(
		achievement_label,
		"modulate:a",
		1.0,
		0.20
	)

	achievement_tween.parallel().tween_property(
		achievement_label,
		"scale",
		Vector2.ONE,
		0.28
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	achievement_tween.tween_interval(2.4)

	achievement_tween.tween_property(
		achievement_label,
		"modulate:a",
		0.0,
		0.40
	)

	achievement_tween.tween_callback(
		func() -> void:
			achievement_label.visible = false
	)
func _get_echo_speed_multiplier() -> float:
	if current_round <= 10:
		return 0.66

	if current_round <= 15:
		return 0.70

	if current_round <= 20:
		return 0.75

	if current_round <= 30:
		return 0.80

	return 0.85


func _get_echo_warning_time() -> float:
	if current_round <= 10:
		return 0.52

	if current_round <= 15:
		return 0.47

	if current_round <= 20:
		return 0.42
	if current_round <= 30:
		return 0.38
	return 0.34


func _get_echo_collision_radius() -> float:
	if current_round <= 10:
		return 9

	if current_round <= 15:
		return 9.5

	if current_round <= 20:
		return 10.5
	if current_round <= 30:
		return 11.5
		
	return 12.0

func _highlight_hazard(
	hazard: Node2D
) -> void:
	if not is_instance_valid(hazard):
		return

	var original_scale: Vector2 = hazard.scale

	# Create a separate golden ring around the hazard.
	var impact_ring: Line2D = Line2D.new()

	impact_ring.width = 4.0
	impact_ring.default_color = Color("#FFD85A")
	impact_ring.closed = true
	impact_ring.antialiased = true
	impact_ring.z_index = 100

	var point_count: int = 40

	for index: int in range(point_count):
		var point_angle: float = (
			TAU * float(index) / float(point_count)
		)

		impact_ring.add_point(
			Vector2.from_angle(point_angle) * 25.0
		)

	impact_ring.position = to_local(
		hazard.global_position
	)

	impact_ring.scale = Vector2(0.65, 0.65)

	add_child(impact_ring)

	# Enlarge the colliding hazard.
	var highlight_tween: Tween = create_tween()

	highlight_tween.tween_property(
		hazard,
		"scale",
		original_scale * 1.55,
		0.07
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	# Expand and fade the independent golden ring.
	highlight_tween.parallel().tween_property(
		impact_ring,
		"scale",
		Vector2(1.9, 1.9),
		0.32
	)

	highlight_tween.parallel().tween_property(
		impact_ring,
		"modulate",
		Color(1.0, 1.0, 1.0, 0.0),
		0.32
	)

	highlight_tween.tween_property(
		hazard,
		"scale",
		original_scale,
		0.14
	)

	highlight_tween.tween_callback(
		impact_ring.queue_free
	)
func _on_leaderboards_button_pressed() -> void:
	LeaderboardManager.show_all_leaderboards()


func _on_skin_button_pressed() -> void:
	if not SaveManager.level_10_skin_unlocked:
		return

	var select_gilded: bool = (
		not SaveManager.is_gilded_skin_selected()
	)

	if select_gilded:
		SaveManager.select_skin(
			SaveManager.GILDED_SKIN
		)
	else:
		SaveManager.select_skin(
			SaveManager.DEFAULT_SKIN
		)

	player.set_gilded_skin(
		SaveManager.is_gilded_skin_selected()
	)

	_update_skin_button()


func _update_skin_button() -> void:
	if not SaveManager.level_10_skin_unlocked:
		skin_button.text = (
			"SKIN: DEFAULT\n"
			+ "GILDED UNLOCKS AT 10"
		)

		skin_button.disabled = true
		return

	skin_button.disabled = false

	if SaveManager.is_gilded_skin_selected():
		skin_button.text = (
			"SKIN: GILDED\n"
			+ "TAP TO CHANGE"
		)
	else:
		skin_button.text = (
			"SKIN: DEFAULT\n"
			+ "TAP TO CHANGE"
		)
func _get_gate_total() -> int:
	if current_round >= 32:
		return 5

	if current_round >= 22:
		return 4

	if current_round >= 12:
		return 3

	if current_round >= 5:
		return 2

	return 1

func _process(delta: float) -> void:
	if not game_started or is_game_over:
		return

	_update_power_up_timer(delta)

	_check_gate_near_misses()
	_check_echo_near_misses()
	_update_risk_multiplier()
	
func _check_gate_near_misses() -> void:
	for child: Node in gates_container.get_children():
		if not child is PhaseGate:
			continue

		var gate: PhaseGate = child as PhaseGate
		var local_player_position: Vector2 = (
			gate.to_local(player.global_position)
		)

		var half_size: Vector2 = (
			gate.gate_size * 0.5
		)

		var closest_point: Vector2 = Vector2(
			clampf(
				local_player_position.x,
				-half_size.x,
				half_size.x
			),
			clampf(
				local_player_position.y,
				-half_size.y,
				half_size.y
			)
		)

		var edge_distance: float = (
			local_player_position.distance_to(
				closest_point
			)
		)

		_update_near_miss_state(
			gate,
			edge_distance <= 32.0
		)


func _check_echo_near_misses() -> void:
	for child: Node in get_children():
		if not child is OrbitEcho:
			continue

		var echo: OrbitEcho = child as OrbitEcho

		var centre_distance: float = (
			player.global_position.distance_to(
				echo.global_position
			)
		)

		_update_near_miss_state(
			echo,
			centre_distance <= 42.0
		)
func _update_near_miss_state(
	hazard: Node2D,
	is_close: bool
) -> void:
	var hazard_id: int = hazard.get_instance_id()

	var was_close: bool = bool(
		hazard_close_states.get(
			hazard_id,
			false
		)
	)

	if was_close and not is_close:
		hazard_close_states[hazard_id] = false
		_show_near_miss()
		return

	hazard_close_states[hazard_id] = is_close
	
func _show_near_miss() -> void:
	if is_game_over:
		return

	current_near_misses += 1

	# Award points using the multiplier that was active
	# when this near miss was achieved.
	var bonus_points: int = roundi(
		float(NEAR_MISS_POINTS) * risk_multiplier
	)

	current_points += bonus_points
	_update_points_display()

	last_near_miss_time = Time.get_ticks_msec()

	# Increase the risk multiplier for the NEXT near miss.
	risk_multiplier = minf(
		risk_multiplier + RISK_MULTIPLIER_STEP,
		MAX_RISK_MULTIPLIER
	)

	_update_risk_display()

	if near_miss_tween != null:
		near_miss_tween.kill()

	near_miss_label.visible = true
	near_miss_label.text = (
		"NEAR MISS!\n+%d"
		% bonus_points
	)

	near_miss_label.pivot_offset = (
		near_miss_label.size * 0.5
	)

	near_miss_label.scale = Vector2(
		1.35,
		1.35
	)

	near_miss_label.modulate = _get_risk_colour()

	burst_particles.create_burst(
		player.position,
		_get_risk_colour(),
		8,
		35.0,
		90.0,
		0.24
	)

	near_miss_tween = create_tween()

	near_miss_tween.tween_property(
		near_miss_label,
		"scale",
		Vector2.ONE,
		0.16
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	near_miss_tween.tween_interval(0.35)

	near_miss_tween.tween_property(
		near_miss_label,
		"modulate:a",
		0.0,
		0.22
	)

	near_miss_tween.tween_callback(
		func() -> void:
			near_miss_label.visible = false
	)


func _update_risk_display() -> void:
	if risk_multiplier <= 1.0:
		risk_label.visible = false
		return

	risk_label.visible = true
	risk_label.text = (
		"RISK x%.1f"
		% risk_multiplier
	)

	risk_label.modulate = _get_risk_colour()

	risk_label.pivot_offset = (
		risk_label.size * 0.5
	)

	risk_label.scale = Vector2(
		1.25,
		1.25
	)

	if risk_tween != null:
		risk_tween.kill()

	risk_tween = create_tween()

	risk_tween.tween_property(
		risk_label,
		"scale",
		Vector2.ONE,
		0.18
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)


func _get_risk_colour() -> Color:
	if risk_multiplier >= 3.0:
		return Color("#FF315F")

	if risk_multiplier >= 2.5:
		return Color("#FFD54A")

	if risk_multiplier >= 2.0:
		return Color("#B85CFF")

	return Color("#35F2E8")


func _update_risk_multiplier() -> void:
	if risk_multiplier <= 1.0:
		return

	var time_since_near_miss: int = (
		Time.get_ticks_msec() - last_near_miss_time
	)

	if time_since_near_miss >= RISK_TIMEOUT_MS:
		risk_multiplier = 1.0
		_update_risk_display()
func _try_spawn_power_up() -> void:
	_clear_uncollected_power_ups()
	
	if echo_breaker_active or gate_breaker_active:
		return
	
	if power_up_scene == null:
		return

	if current_round < POWER_UP_START_ROUND:
		return


	laps_since_power_up += 1

	if laps_since_power_up < POWER_UP_MIN_LAP_GAP:
		return

	if randf() > POWER_UP_SPAWN_CHANCE:
		return

	var spawn_position: Vector2 = Vector2.ZERO
	var placement_found: bool = false

	for attempt: int in range(20):
		var angle_offset: float = randf_range(
			POWER_UP_START_SAFE_ANGLE,
			TAU - POWER_UP_START_SAFE_ANGLE
		)

		var spawn_angle: float = fposmod(
			player.angle + angle_offset,
			TAU
		)

		var spawn_radius: float

		if randi_range(0, 1) == 0:
			spawn_radius = inner_radius
		else:
			spawn_radius = outer_radius

		var candidate_position: Vector2 = (
			Vector2.from_angle(spawn_angle)
			* spawn_radius
		)

		if _is_power_up_position_safe(
			candidate_position
		):
			spawn_position = candidate_position
			placement_found = true
			break

	if not placement_found:
		return

	var power_up: SkillPowerUp = (
		power_up_scene.instantiate()
		as SkillPowerUp
	)

	if power_up == null:
		return

	if randf() < 0.5:
		power_up.power_up_type = (
			SkillPowerUp.PowerUpType.ECHO_BREAKER
	)
	else:
		power_up.power_up_type = (
			SkillPowerUp.PowerUpType.GATE_BREAKER
		)

	power_up.position = spawn_position

	power_ups_container.add_child(power_up)

	power_up.collected.connect(
		_on_power_up_collected
	)

	laps_since_power_up = 0
	
func _is_power_up_position_safe(
	candidate_position: Vector2
) -> bool:
	for child: Node in gates_container.get_children():
		if not child is PhaseGate:
			continue

		var gate: PhaseGate = (
			child as PhaseGate
		)

		if (
			candidate_position.distance_to(
				gate.position
			)
			< POWER_UP_GATE_SAFE_DISTANCE
		):
			return false

	for child: Node in get_children():
		if not child is OrbitEcho:
			continue

		var echo: OrbitEcho = (
			child as OrbitEcho
		)

		if (
			candidate_position.distance_to(
				echo.position
			)
			< POWER_UP_ECHO_SAFE_DISTANCE
		):
			return false

	return true
	
func _on_power_up_collected(
	power_up: SkillPowerUp
) -> void:
	match power_up.power_up_type:
		SkillPowerUp.PowerUpType.ECHO_BREAKER:
			_activate_power_up(
				SkillPowerUp.PowerUpType.ECHO_BREAKER
			)

		SkillPowerUp.PowerUpType.GATE_BREAKER:
			_activate_power_up(
				SkillPowerUp.PowerUpType.GATE_BREAKER
			)

	power_up.queue_free()
	
func _activate_power_up(
	power_up_type: int
) -> void:
	echo_breaker_active = (
		power_up_type
		== SkillPowerUp.PowerUpType.ECHO_BREAKER
	)

	gate_breaker_active = (
		power_up_type
		== SkillPowerUp.PowerUpType.GATE_BREAKER
	)

	var power_up_colour: Color

	if echo_breaker_active:
		power_up_duration = ECHO_BREAKER_DURATION
		power_up_colour = ECHO_BREAKER_COLOUR
	else:
		power_up_duration = GATE_BREAKER_DURATION
		power_up_colour = GATE_BREAKER_COLOUR

	power_up_time_remaining = power_up_duration

	power_up_hud.visible = true

	player.set_power_up_visual(
		true,
		power_up_colour
	)

	_refresh_power_up_hud()

	burst_particles.create_burst(
		player.position,
		power_up_colour,
		22,
		75.0,
		190.0,
		0.40
	)

	SettingsManager.vibrate(
		45,
		0.45
	)
func _deactivate_power_up() -> void:
	echo_breaker_active = false
	gate_breaker_active = false

	power_up_time_remaining = 0.0
	power_up_duration = 0.0

	power_up_hud.visible = false

	player.set_power_up_visual(
		false
	)
func _refresh_power_up_hud() -> void:
	if (
		not echo_breaker_active
		and not gate_breaker_active
	):
		power_up_hud.visible = false
		return

	var ratio: float = 0.0

	if power_up_duration > 0.0:
		ratio = clampf(
			power_up_time_remaining
			/ power_up_duration,
			0.0,
			1.0
		)

	power_up_timer_fill.size.x = (
		POWER_UP_TIMER_WIDTH * ratio
	)

	player.set_power_up_visual_ratio(
		ratio
	)

	if echo_breaker_active:
		power_up_name_label.text = (
			"ECHO BREAKER  %.1fs"
			% power_up_time_remaining
		)

		power_up_name_label.modulate = (
			ECHO_BREAKER_COLOUR
		)

		power_up_timer_fill.color = (
			ECHO_BREAKER_COLOUR
		)

	else:
		power_up_name_label.text = (
			"GATE BREAKER  %.1fs"
			% power_up_time_remaining
		)

		power_up_name_label.modulate = (
			GATE_BREAKER_COLOUR
		)

		power_up_timer_fill.color = (
			GATE_BREAKER_COLOUR
		)
		
func _update_power_up_timer(
	delta: float
) -> void:
	if (
		not echo_breaker_active
		and not gate_breaker_active
	):
		return

	power_up_time_remaining = maxf(
		power_up_time_remaining - delta,
		0.0
	)

	_refresh_power_up_hud()

	if power_up_time_remaining <= 0.0:
		_deactivate_power_up()
		
func _destroy_gate_with_power_up(
	gate: PhaseGate
) -> void:
	if not is_instance_valid(gate):
		return

	hazard_close_states.erase(
		gate.get_instance_id()
	)

	burst_particles.create_burst(
		gate.position,
		GATE_BREAKER_COLOUR,
		28,
		80.0,
		210.0,
		0.45
	)

	burst_particles.create_burst(
		gate.position,
		Color.WHITE,
		10,
		50.0,
		140.0,
		0.28
	)

	SettingsManager.vibrate(
		45,
		0.45
	)

	gate.set_deferred(
		"monitoring",
		false
	)

	gate.queue_free()
	
func _clear_uncollected_power_ups() -> void:
	for child: Node in power_ups_container.get_children():
		if child is Area2D:
			var power_up_area: Area2D = (
				child as Area2D
			)

			power_up_area.set_deferred(
				"monitoring",
				false
			)

		child.queue_free()
