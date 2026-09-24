extends RefCounted
## Searches for a real sequence of stays and complete lane switches.
## Power-ups are deliberately excluded: a layout must be survivable unaided.

const MAX_STEP: float = 1.0 / 60.0
const REACTION_TIME: float = 0.20
const SWITCH_REST: float = 0.10
const CLEARANCE: float = 4.0

var step_seconds: float
var step_count: int
var _start_angle: float
var _speed: float
var _inner: float
var _outer: float
var _start_radius: float
var _target_radius: float
var _switch_duration: float
var _radial_speed: float
var _player_radius: float
var _gate_half_size: Vector2
var _echoes: Array[OrbitEcho] = []
var _echo_positions: Array[PackedVector2Array] = []
var _echo_clearances: Array[PackedFloat32Array] = []
var _echo_edge_cache: Dictionary = {}


func configure(
	player: OrbitPlayer,
	echoes: Array[OrbitEcho],
	gate_size: Vector2
) -> void:
	_start_angle = player.angle
	_speed = absf(player.angular_speed)
	_inner = player.inner_radius
	_outer = player.outer_radius
	_start_radius = player.current_radius
	_target_radius = player.target_radius
	_switch_duration = maxf(player.lane_switch_duration, 0.001)
	_radial_speed = absf(_outer - _inner) / _switch_duration
	var player_shape: CircleShape2D = player.get_node("CollisionShape2D").shape
	_player_radius = player_shape.radius
	_gate_half_size = gate_size * 0.5
	var horizon: float = (TAU - player.lap_distance) / maxf(_speed, 0.001)
	step_count = maxi(1, ceili(horizon / MAX_STEP))
	step_seconds = horizon / float(step_count)
	_echoes = echoes.duplicate()
	_echo_positions.clear()
	_echo_clearances.clear()
	_echo_edge_cache.clear()

	# Reused for every candidate layout in this lap.
	for echo: OrbitEcho in _echoes:
		var positions: PackedVector2Array = PackedVector2Array()
		var clearances: PackedFloat32Array = PackedFloat32Array()
		var shape: CircleShape2D = echo.get_node("CollisionShape2D").shape
		var speed_bound: float = echo.get_motion_speed_bound()
		for tick: int in range(step_count):
			var time: float = (float(tick) + 0.5) * step_seconds
			positions.append(echo.get_predicted_position(time))
			var movement_margin: float = speed_bound * step_seconds * 0.5
			# A non-closed recording can jump radially at its replay seam.
			var before_cycle: int = floori(
				(echo.travelled_angle + echo.angular_speed * float(tick) * step_seconds) / TAU
			)
			var after_cycle: int = floori(
				(echo.travelled_angle + echo.angular_speed * float(tick + 1) * step_seconds) / TAU
			)
			if before_cycle != after_cycle and echo.recorded_path.size() >= 2:
				movement_margin += absf(echo.recorded_path[0] - echo.recorded_path[-1])
			clearances.append(shape.radius + movement_margin)
		_echo_positions.append(positions)
		_echo_clearances.append(clearances)


func find_route(layout: Array[Dictionary]) -> PackedFloat32Array:
	var parents: Array[Vector2i] = []
	parents.resize((step_count + 1) * 2)
	parents.fill(Vector2i(-1, -1))
	var initial_lane: int = 0 if is_equal_approx(_target_radius, _inner) else 1
	var settle_time: float = absf(_target_radius - _start_radius) / maxf(_radial_speed, 0.001)
	var initial_tick: int = mini(step_count, ceili(maxf(REACTION_TIME, settle_time) / step_seconds))
	if not _motion_is_safe(0, initial_tick, _start_radius, _target_radius, layout, -1):
		return PackedFloat32Array()
	parents[initial_tick * 2 + initial_lane] = Vector2i(-2, -2)

	for tick: int in range(initial_tick, step_count):
		for lane: int in range(2):
			if parents[tick * 2 + lane].x == -1:
				continue
			for next_lane: int in range(2):
				var is_switch: bool = next_lane != lane
				var duration_ticks: int = ceili((_switch_duration + SWITCH_REST) / step_seconds) if is_switch else 1
				var end_tick: int = mini(step_count, tick + duration_ticks)
				if parents[end_tick * 2 + next_lane].x != -1:
					continue
				var edge_key: int = tick * 4 + lane * 2 + next_lane
				if _motion_is_safe(tick, end_tick, _lane_radius(lane), _lane_radius(next_lane), layout, edge_key):
					parents[end_tick * 2 + next_lane] = Vector2i(tick, lane)

	for lane: int in range(2):
		if parents[step_count * 2 + lane].x != -1:
			return _reconstruct_route(parents, initial_tick, lane)
	return PackedFloat32Array()


func _motion_is_safe(
	start_tick: int,
	end_tick: int,
	from_radius: float,
	to_radius: float,
	layout: Array[Dictionary],
	edge_key: int
) -> bool:
	if _echo_edge_cache.has(edge_key) and not bool(_echo_edge_cache[edge_key]):
		return false
	var check_echoes: bool = not _echo_edge_cache.has(edge_key)
	for tick: int in range(start_tick, end_tick):
		var elapsed: float = (float(tick - start_tick) + 0.5) * step_seconds
		var radius: float = move_toward(from_radius, to_radius, _radial_speed * elapsed)
		var time: float = (float(tick) + 0.5) * step_seconds
		var point: Vector2 = Vector2.from_angle(_start_angle + _speed * time) * radius
		var speed_bound: float = _speed * maxf(_inner, _outer)
		if absf(from_radius - to_radius) > _radial_speed * float(tick - start_tick) * step_seconds:
			speed_bound += _radial_speed
		# A speed bound covers both ends and the interior of each time slice.
		var clearance: float = _player_radius + CLEARANCE + speed_bound * step_seconds * 0.5
		if check_echoes:
			for index: int in range(_echoes.size()):
				if point.distance_to(_echo_positions[index][tick]) <= clearance + _echo_clearances[index][tick]:
					_echo_edge_cache[edge_key] = false
					return false
		for gate: Dictionary in layout:
			var gate_radius: float = _inner if bool(gate["blocks_inner"]) else _outer
			var local: Vector2 = point.rotated(-float(gate["angle"])) - Vector2(gate_radius, 0.0)
			var nearest: Vector2 = local.clamp(-_gate_half_size, _gate_half_size)
			if local.distance_to(nearest) <= clearance:
				return false
	# Only cache success after every slice was checked (a gate may stop us early).
	_echo_edge_cache[edge_key] = true
	return true


func _lane_radius(lane: int) -> float:
	return _inner if lane == 0 else _outer


func _reconstruct_route(
	parents: Array[Vector2i],
	initial_tick: int,
	end_lane: int
) -> PackedFloat32Array:
	var route: PackedFloat32Array = PackedFloat32Array()
	route.resize(step_count + 1)
	for tick: int in range(initial_tick + 1):
		route[tick] = move_toward(_start_radius, _target_radius, _radial_speed * float(tick) * step_seconds)
	var end_tick: int = step_count
	var lane: int = end_lane
	while end_tick > initial_tick:
		var parent: Vector2i = parents[end_tick * 2 + lane]
		for tick: int in range(parent.x, end_tick + 1):
			route[tick] = move_toward(_lane_radius(parent.y), _lane_radius(lane), _radial_speed * float(tick - parent.x) * step_seconds)
		end_tick = parent.x
		lane = parent.y
	return route
