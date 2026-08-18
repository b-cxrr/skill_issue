extends Node

signal service_ready_changed(is_ready: bool)

const HIGH_SCORE: String = "highest_score"
const HIGHEST_ROUND: String = "highest_round"
const LIFETIME_RUNS: String = "lifetime_runs"
const LIFETIME_LAPS: String = "lifetime_laps"

const HIGH_SCORE_ID: String = "CgkIu8X556UYEAIQAQ"
const HIGHEST_ROUND_ID: String = "CgkIu8X556UYEAIQAg"
const LIFETIME_LAPS_ID: String = "CgkIu8X556UYEAIQAw"
const LIFETIME_RUNS_ID: String = "CgkIu8X556UYEAIQBA"

const RC_LEADERBOARDS: int = 9004

var service_ready: bool = false
var debug_logging: bool = false

var pending_scores: Dictionary = {}

var _android_runtime = null
var _activity = null
var _games_sign_in_client = null
var _leaderboards_client = null

var _auth_listener = null
var _sign_in_listener = null
var _leaderboard_intent_listener = null
var _leaderboard_failure_listener = null

var _open_all_after_sign_in: bool = false


func _ready() -> void:
	if OS.get_name() != "Android":
		if debug_logging:
			print(
				"LeaderboardManager: Android bridge inactive "
				+ "outside Android."
			)

		call_deferred("sync_saved_records")
		return

	call_deferred("_initialise_android_bridge")


func _initialise_android_bridge() -> void:
	_android_runtime = Engine.get_singleton(
		"AndroidRuntime"
	)

	if _android_runtime == null:
		push_warning(
			"LeaderboardManager: AndroidRuntime unavailable."
		)
		return

	_activity = _android_runtime.getActivity()

	if _activity == null:
		push_warning(
			"LeaderboardManager: Android Activity unavailable."
		)
		return

	var PlayGames = JavaClassWrapper.wrap(
		"com.google.android.gms.games.PlayGames"
	)

	_games_sign_in_client = (
		PlayGames.getGamesSignInClient(
			_activity
		)
	)

	_leaderboards_client = (
		PlayGames.getLeaderboardsClient(
			_activity
		)
	)

	if (
		_games_sign_in_client == null
		or _leaderboards_client == null
	):
		push_warning(
			"LeaderboardManager: Could not create "
			+ "Play Games clients."
		)
		return

	if debug_logging:
		print(
			"LeaderboardManager: Play Games clients created."
		)

	_check_authentication()


func _check_authentication() -> void:
	if _games_sign_in_client == null:
		return

	var auth_task = (
		_games_sign_in_client.isAuthenticated()
	)

	var auth_callable: Callable = func(task) -> void:
		_handle_authentication_task(
			task,
			false
		)

	_auth_listener = (
		JavaClassWrapper.create_sam_callback(
			"com.google.android.gms.tasks.OnCompleteListener",
			auth_callable
		)
	)

	auth_task.addOnCompleteListener(
		_auth_listener
	)


func request_sign_in(
	open_all_leaderboards_after: bool = false
) -> void:
	if _games_sign_in_client == null:
		if debug_logging:
			print(
				"LeaderboardManager: Sign-in client unavailable."
			)
		return

	_open_all_after_sign_in = (
		open_all_leaderboards_after
	)

	var sign_in_task = (
		_games_sign_in_client.signIn()
	)

	var sign_in_callable: Callable = func(task) -> void:
		_handle_authentication_task(
			task,
			true
		)

	_sign_in_listener = (
		JavaClassWrapper.create_sam_callback(
			"com.google.android.gms.tasks.OnCompleteListener",
			sign_in_callable
		)
	)

	sign_in_task.addOnCompleteListener(
		_sign_in_listener
	)


func _handle_authentication_task(
	task,
	was_manual_sign_in: bool
) -> void:
	var authenticated: bool = false

	if (
		task != null
		and task.isSuccessful()
	):
		var result = task.getResult()

		if result != null:
			authenticated = bool(
				result.isAuthenticated()
			)

	# Google Task callbacks may arrive on a non-Godot thread.
	# Defer all scene-tree and signal work back to Godot safely.
	call_deferred(
		"_apply_authentication_result",
		authenticated,
		was_manual_sign_in
	)


func _apply_authentication_result(
	authenticated: bool,
	was_manual_sign_in: bool
) -> void:
	set_service_ready(
		authenticated
	)

	if debug_logging:
		if authenticated:
			print(
				"LeaderboardManager: "
				+ "Play Games authenticated."
			)
		else:
			print(
				"LeaderboardManager: "
				+ "Play Games authentication unavailable."
			)

	if (
		was_manual_sign_in
		and authenticated
		and _open_all_after_sign_in
	):
		_open_all_after_sign_in = false

		call_deferred(
			"_open_all_leaderboards"
		)

	elif was_manual_sign_in:
		_open_all_after_sign_in = false


func submit_high_score(score: int) -> void:
	_submit_or_queue(
		HIGH_SCORE,
		score
	)


func submit_highest_round(
	round_reached: int
) -> void:
	_submit_or_queue(
		HIGHEST_ROUND,
		round_reached
	)


func submit_lifetime_runs(
	run_count: int
) -> void:
	_submit_or_queue(
		LIFETIME_RUNS,
		run_count
	)


func submit_lifetime_laps(
	lap_count: int
) -> void:
	_submit_or_queue(
		LIFETIME_LAPS,
		lap_count
	)


func sync_saved_records() -> void:
	submit_high_score(
		SaveManager.best_points
	)

	submit_highest_round(
		SaveManager.best_round
	)

	submit_lifetime_runs(
		SaveManager.total_runs
	)

	submit_lifetime_laps(
		SaveManager.total_laps
	)


func show_all_leaderboards() -> void:
	if OS.get_name() != "Android":
		if debug_logging:
			print(
				"LeaderboardManager: Leaderboard UI "
				+ "is Android-only."
			)
		return

	if not service_ready:
		if debug_logging:
			print(
				"LeaderboardManager: Requesting "
				+ "Play Games sign-in."
			)

		request_sign_in(
			true
		)
		return

	_open_all_leaderboards()


func show_high_score_leaderboard() -> void:
	_show_specific_leaderboard(
		HIGH_SCORE
	)


func show_highest_round_leaderboard() -> void:
	_show_specific_leaderboard(
		HIGHEST_ROUND
	)


func show_lifetime_runs_leaderboard() -> void:
	_show_specific_leaderboard(
		LIFETIME_RUNS
	)


func show_lifetime_laps_leaderboard() -> void:
	_show_specific_leaderboard(
		LIFETIME_LAPS
	)


func _open_all_leaderboards() -> void:
	if (
		_leaderboards_client == null
		or _activity == null
	):
		return

	var intent_task = (
		_leaderboards_client
		.getAllLeaderboardsIntent()
	)

	_attach_leaderboard_intent_callbacks(
		intent_task
	)


func _show_specific_leaderboard(
	leaderboard_key: String
) -> void:
	if not service_ready:
		request_sign_in(
			false
		)
		return

	if (
		_leaderboards_client == null
		or _activity == null
	):
		return

	var leaderboard_id: String = (
		_get_leaderboard_id(
			leaderboard_key
		)
	)

	if leaderboard_id.is_empty():
		push_warning(
			"LeaderboardManager: Unknown leaderboard key: "
			+ leaderboard_key
		)
		return

	var intent_task = (
		_leaderboards_client
		.getLeaderboardIntent(
			leaderboard_id
		)
	)

	_attach_leaderboard_intent_callbacks(
		intent_task
	)


func _attach_leaderboard_intent_callbacks(
	intent_task
) -> void:
	var success_callable: Callable = func(intent) -> void:
		if (
			intent == null
			or _activity == null
		):
			return

		_activity.startActivityForResult(
			intent,
			RC_LEADERBOARDS
		)

	var failure_callable: Callable = func(exception) -> void:
		if debug_logging:
			print(
				"LeaderboardManager: Could not "
				+ "open leaderboard UI: ",
				exception
			)

	_leaderboard_intent_listener = (
		JavaClassWrapper.create_sam_callback(
			"com.google.android.gms.tasks.OnSuccessListener",
			success_callable
		)
	)

	_leaderboard_failure_listener = (
		JavaClassWrapper.create_sam_callback(
			"com.google.android.gms.tasks.OnFailureListener",
			failure_callable
		)
	)

	intent_task.addOnSuccessListener(
		_leaderboard_intent_listener
	)

	intent_task.addOnFailureListener(
		_leaderboard_failure_listener
	)


func set_service_ready(value: bool) -> void:
	if service_ready == value:
		return

	service_ready = value

	service_ready_changed.emit(
		service_ready
	)

	if debug_logging:
		print(
			"Leaderboard service ready: ",
			service_ready
		)

	if service_ready:
		sync_saved_records()
		_flush_pending_scores()


func is_service_ready() -> bool:
	return service_ready


func _submit_or_queue(
	leaderboard_key: String,
	value: int
) -> void:
	if value <= 0:
		return

	if not service_ready:
		_queue_score(
			leaderboard_key,
			value
		)

		if debug_logging:
			print(
				"Leaderboard queued: ",
				leaderboard_key,
				" = ",
				value
			)

		return

	var submitted: bool = (
		_submit_to_platform(
			leaderboard_key,
			value
		)
	)

	if not submitted:
		_queue_score(
			leaderboard_key,
			value
		)


func _queue_score(
	leaderboard_key: String,
	value: int
) -> void:
	var previous_value: int = int(
		pending_scores.get(
			leaderboard_key,
			0
		)
	)

	if value > previous_value:
		pending_scores[
			leaderboard_key
		] = value


func _flush_pending_scores() -> void:
	if not service_ready:
		return

	if pending_scores.is_empty():
		return

	var queued_copy: Dictionary = (
		pending_scores.duplicate()
	)

	pending_scores.clear()

	for leaderboard_key: String in queued_copy:
		var value: int = int(
			queued_copy[
				leaderboard_key
			]
		)

		var submitted: bool = (
			_submit_to_platform(
				leaderboard_key,
				value
			)
		)

		if not submitted:
			_queue_score(
				leaderboard_key,
				value
			)


func _submit_to_platform(
	leaderboard_key: String,
	value: int
) -> bool:
	if (
		not service_ready
		or _leaderboards_client == null
	):
		return false

	var leaderboard_id: String = (
		_get_leaderboard_id(
			leaderboard_key
		)
	)

	if leaderboard_id.is_empty():
		push_warning(
			"LeaderboardManager: Unknown leaderboard key: "
			+ leaderboard_key
		)
		return false

	_leaderboards_client.submitScore(
		leaderboard_id,
		value
	)

	if debug_logging:
		print(
			"Leaderboard submitted: ",
			leaderboard_key,
			" = ",
			value
		)

	return true


func _get_leaderboard_id(
	leaderboard_key: String
) -> String:
	match leaderboard_key:
		HIGH_SCORE:
			return HIGH_SCORE_ID

		HIGHEST_ROUND:
			return HIGHEST_ROUND_ID

		LIFETIME_RUNS:
			return LIFETIME_RUNS_ID

		LIFETIME_LAPS:
			return LIFETIME_LAPS_ID

	return ""
