extends Node2D


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
@onready var near_miss_label: Label = (%NearMissLabel)
@onready var pause_menu: SkillPauseMenu = (%PauseMenu)
@onready var game_over_overlay: ColorRect = (%GameOverOverlay)
@onready var stats_label: Label = (%StatsLabel)
@export var maximum_echoes: int = 1
@export var gate_scene: PackedScene
@export var inner_radius: float = 150.0
@export var outer_radius: float = 240.0
@export var echo_scene: PackedScene

var ring_colour: Color = Color("#303040")
var inner_glow_colour: Color = Color("#183F46")
var echo_count: int = 0
var is_game_over: bool = false
var restart_allowed_at: int = 0
var current_score: int = 0
var game_started: bool = false
var collision_flash_tween: Tween
var collision_shake_tween: Tween
var shift_trail_tween: Tween
var near_miss_tween: Tween
var hazard_close_states: Dictionary = {}
var lap_pulse_tween: Tween
var lap_pulse_radius: float = 0.0
var lap_pulse_alpha: float = 0.0
var score_tween: Tween
var start_prompt_tween: Tween
var game_over_tween: Tween
var achievement_tween: Tween
var current_near_misses: int = 0


func _ready() -> void:
	
	near_miss_label.visible = false
	
	player.set_gilded_skin(
		SaveManager.is_gilded_skin_selected()
	)
	game_over_overlay.visible = false
	achievement_label.visible = false
	
	skin_button.pressed.connect(_on_skin_button_pressed)
	_update_skin_button()
	pause_menu.call_deferred("set_gameplay_available",false)
	
	get_viewport().size_changed.connect(_centre_arena)
	player.lap_completed.connect(_on_player_lap_completed)
	player.lane_switched.connect(_on_player_lane_switched)

	game_over_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	game_over_center.visible = false
	_update_score_display()
	
	start_center.visible = true
	score_label.visible = false
	_animate_start_prompt()

	player.set_process(false)
	player.set_process_unhandled_input(false)

	_centre_arena()
	_generate_gates()

	queue_redraw()


func _centre_arena() -> void:
	position = get_viewport_rect().size * 0.5


func _on_player_lap_completed(
	
	path: PackedFloat32Array,
	recorded_speed: float
) -> void:
	current_score += 1
	_update_score_display()
	_check_level_10_achievement()
	_animate_score()
	_play_lap_pulse()

	if lap_sound.stream != null:
		lap_sound.play()

	SettingsManager.vibrate(35, 0.35)
	_generate_gates()
	if current_score < 4:
		return
	if echo_scene == null:
		push_warning("No Echo scene assigned to Arena.")
		return

	echo_count += 1

	var echo: OrbitEcho = (
		echo_scene.instantiate() as OrbitEcho
	)

	if echo == null:
		push_warning("The assigned scene is not an OrbitEcho.")
		return

	# Each new echo begins slightly further around the circle.
	# This prevents all echoes from permanently overlapping.
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
	
	echo.player_hit.connect(_on_hazard_hit_player)

	_limit_active_echoes()

func _draw() -> void:
	draw_arc(Vector2.ZERO,inner_radius,0.0,TAU,128,inner_glow_colour,12.0,true)

	draw_arc(Vector2.ZERO,inner_radius,0.0,TAU,128,ring_colour,4.0,true)

	draw_arc(Vector2.ZERO,outer_radius,0.0,TAU,128,ring_colour,4.0,true)
	
	if lap_pulse_alpha > 0.0:
		draw_arc(Vector2.ZERO,lap_pulse_radius,0.0,TAU,128,Color(0.2,0.95,0.9,lap_pulse_alpha),7.0,true)

func _on_hazard_hit_player(hazard: Node2D) -> void:
	if is_game_over:
		return

	is_game_over = true
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

	var got_new_best: bool = (
		SaveManager.record_completed_run(
			current_score,
			current_near_misses
		)
	)

	final_score_label.text = (
		"SCORE %03d" % current_score
	)

	best_score_label.text = (
		"BEST %03d" % SaveManager.best_score
	)

	if got_new_best:
		best_score_label.text += "  NEW"

	stats_label.text = (
		"NEAR MISSES %03d  |  TOTAL %03d\n"
		+ "RUNS %03d  |  LAPS %03d"
	) % [
		current_near_misses,
		SaveManager.total_near_misses,
		SaveManager.total_runs,
		SaveManager.total_laps
	]

	_show_game_over()
	score_label.visible = false

	player.set_process(false)
	player.set_process_unhandled_input(false)

	player.modulate = Color("#FF315F")
	player.scale = Vector2(1.35, 1.35)

	for child: Node in get_children():
		if child is OrbitEcho:
			child.set_process(false)
			child.set_deferred("monitoring", false)


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
		
func _update_score_display() -> void:
	score_label.text = "%03d" % current_score

func _generate_gates() -> void:
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

	# Spread gates evenly around the complete orbit.
	var spacing: float = (
		TAU / float(gate_total)
	)

	# Position the first gate halfway through its section.
	var first_gate_offset: float = (
		spacing * 0.5
	)

	# Randomly rotate the pattern while preserving
	# a safe area around the player's lap position.
	var preferred_safe_angle: float = 0.70

	var available_rotation: float = maxf(
		0.0,
		spacing * 0.5 - preferred_safe_angle
	)

	var rotation_limit: float = minf(
		0.18,
		available_rotation
	)

	var pattern_rotation: float = randf_range(
		-rotation_limit,
		rotation_limit
	)

	# Randomise which lane is blocked first.
	var pattern_offset: int = randi_range(0, 1)

	for index: int in range(gate_total):
		var gate_angle: float = fposmod(
			-PI / 2.0
			+ first_gate_offset
			+ spacing * float(index)
			+ pattern_rotation,
			TAU
		)

		var blocks_inner: bool

		# The tutorial gate always blocks the player's
		# starting outer lane.
		if current_score == 0:
			blocks_inner = false
		else:
			blocks_inner = (
				(index + pattern_offset) % 2 == 0
			)

		var gate_radius: float

		if blocks_inner:
			gate_radius = inner_radius
		else:
			gate_radius = outer_radius

		var gate: PhaseGate = (gate_scene.instantiate() as PhaseGate)

		if gate == null:
			push_warning("The assigned gate scene is not a PhaseGate.")
			return

		gates_container.add_child(gate)

		gate.configure_gate(gate_angle,gate_radius,blocks_inner)

		gate.player_hit.connect(_on_hazard_hit_player)
		
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
	if current_score < 10:
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
	if current_score <= 7:
		return 0.72

	if current_score <= 11:
		return 0.76

	if current_score <= 15:
		return 0.80

	if current_score <= 19:
		return 0.83

	return 0.85


func _get_echo_warning_time() -> float:
	if current_score <= 7:
		return 0.46

	if current_score <= 11:
		return 0.42

	if current_score <= 15:
		return 0.38

	return 0.34


func _get_echo_collision_radius() -> float:
	if current_score <= 7:
		return 9.5

	if current_score <= 11:
		return 10.5

	if current_score <= 15:
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
			+ "GILDED UNLOCKS AT 010"
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
	if current_score >= 22:
		return 5

	if current_score >= 14:
		return 4

	if current_score >= 8:
		return 3

	if current_score >= 2:
		return 2

	return 1
func _process(_delta: float) -> void:
	if not game_started or is_game_over:
		return

	_check_gate_near_misses()
	_check_echo_near_misses()
	
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

	if near_miss_tween != null:
		near_miss_tween.kill()

	near_miss_label.visible = true
	near_miss_label.text = "NEAR MISS"
	near_miss_label.pivot_offset = (
		near_miss_label.size * 0.5
	)

	near_miss_label.scale = Vector2(
		1.35,
		1.35
	)

	near_miss_label.modulate = Color(
		0.21,
		0.95,
		0.91,
		1.0
	)

	burst_particles.create_burst(
		player.position,
		Color("#35F2E8"),
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
