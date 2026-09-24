extends Node

signal service_ready_changed(is_ready: bool)
signal submission_finished(leaderboard_key: String, value: int, successful: bool, new_all_time_best: bool)
signal records_sync_finished(
	records: Dictionary,
	changed_local_save: bool
)

const LEADERBOARD_TIME_SPAN_ALL_TIME: int = 2
const LEADERBOARD_COLLECTION_PUBLIC: int = 0
const HIGH_SCORE: String = "highest_score"
const HIGHEST_ROUND: String = "highest_round"
const LIFETIME_RUNS: String = "lifetime_runs"
const LIFETIME_LAPS: String = "lifetime_laps"
const HIGH_SCORE_ID: String = "CgkIu8X556UYEAIQAQ"
const HIGHEST_ROUND_ID: String = "CgkIu8X556UYEAIQAg"
const LIFETIME_LAPS_ID: String = "CgkIu8X556UYEAIQAw"
const LIFETIME_RUNS_ID: String = "CgkIu8X556UYEAIQBA"
const PRODUCTION_PACKAGE: String = "com.bcxrr.skillissue"
const RC_LEADERBOARDS: int = 9004
const POLL_SECONDS: float = 0.25
const TASK_TIMEOUT_SECONDS: float = 30.0
const RETRY_SECONDS: float = 30.0

var service_ready: bool = false
var debug_logging: bool = false
var pending_scores: Dictionary = {}
# Available in Godot's remote inspector; no success is inferred from dispatch.
var last_submission_results: Dictionary = {}
var last_error: String = ""

var _record_sync_pending: bool = false
var _record_sync_remaining: int = 0
var _record_sync_had_error: bool = false
var _record_sync_values: Dictionary = {}
var _record_sync_player_id: String = ""
var _records_synced_player_id: String = ""
var _android_runtime = null
var _activity = null
var _games_sign_in_client = null
var _leaderboards_client = null
var _players_client = null
var _production_package: bool = false
var _active_player_id: String = ""
var _authentication_pending: bool = false
var _auth_revision: int = 0
var _requested_board: String = ""
var _ui_pending: bool = false
var _ui_launcher = null
var _tasks: Array[Dictionary] = []
var _inflight_scores: Dictionary = {}
var _poll_elapsed: float = 0.0
var _retry_elapsed: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pending_scores = SaveManager.leaderboard_pending_scores.duplicate()
	if OS.get_name() == "Android":
		call_deferred("_initialise_android_bridge")


func _initialise_android_bridge() -> void:
	_android_runtime = Engine.get_singleton("AndroidRuntime")
	if _android_runtime == null:
		_report_error("AndroidRuntime unavailable.")
		return
	_activity = _android_runtime.getActivity()
	if _activity == null:
		_report_error("Android Activity unavailable.")
		return
	_production_package = str(_activity.getPackageName()) == PRODUCTION_PACKAGE
	if not _production_package:
		_report_error("Ranked leaderboards are disabled for this app package.")
		return
	var sdk = JavaClassWrapper.wrap("com.google.android.gms.games.PlayGamesSdk")
	var games = JavaClassWrapper.wrap("com.google.android.gms.games.PlayGames")
	if sdk == null or games == null:
		_report_error("Play Games classes unavailable.")
		return
	sdk.initialize(_activity)
	_games_sign_in_client = games.getGamesSignInClient(_activity)
	_leaderboards_client = games.getLeaderboardsClient(_activity)
	_players_client = games.getPlayersClient(_activity)
	if _games_sign_in_client == null or _leaderboards_client == null or _players_client == null:
		_report_error("Could not create Play Games clients.")
		return
	_check_authentication()


func _notification(what: int) -> void:
	if OS.get_name() != "Android":
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		# Invalidate authentication work started before a possible account change.
		_auth_revision += 1
		_authentication_pending = false
		_active_player_id = ""
		set_service_ready(false)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		call_deferred("_check_authentication")


func _process(delta: float) -> void:
	if OS.get_name() != "Android":
		return
	_poll_elapsed += delta
	_retry_elapsed += delta
	if _poll_elapsed >= POLL_SECONDS:
		_poll_elapsed = 0.0
		_poll_tasks()
	if _retry_elapsed >= RETRY_SECONDS:
		_retry_elapsed = 0.0
		# Authentication is refreshed before retrying; never prompt periodically.
		_check_authentication()


func _check_authentication() -> void:
	_begin_authentication(false)


func request_sign_in(open_all_leaderboards_after: bool = false) -> void:
	if open_all_leaderboards_after:
		_requested_board = "all"
	_begin_authentication(true)


func _begin_authentication(manual: bool) -> void:
	if _games_sign_in_client == null or _authentication_pending:
		return
	_authentication_pending = true
	_auth_revision += 1
	var revision: int = _auth_revision
	set_service_ready(false)
	var task = _games_sign_in_client.signIn() if manual else _games_sign_in_client.isAuthenticated()
	_watch_task(task, func(result, error: String) -> void:
		if revision != _auth_revision:
			return
		if not error.is_empty() or result == null or not bool(result.isAuthenticated()):
			_authentication_pending = false
			_active_player_id = ""
			if not error.is_empty():
				_report_error("Sign-in: " + error)
			return
		_watch_task(_players_client.getCurrentPlayerId(), func(player_id, identity_error: String) -> void:
			if revision != _auth_revision:
				return
			_authentication_pending = false
			if not identity_error.is_empty() or player_id == null or str(player_id).is_empty():
				_report_error("Could not verify the signed-in player: " + identity_error)
				return
			_apply_player_identity(str(player_id))
		)
	)


func _apply_player_identity(player_id: String) -> void:
	_active_player_id = player_id
	if _build_allows_submissions() and SaveManager.leaderboard_owner_id.is_empty():
		# Legacy saves have no verified owner. Bind once, without queuing old bests.
		SaveManager.leaderboard_owner_id = player_id
		SaveManager.save_data()
	set_service_ready(true)

	if not _owner_matches() and _build_allows_submissions():
		_report_error(
			"This save belongs to another Play Games account. "
			+ "Score uploads are on hold; sign back into its account."
		)

	_sync_online_records()
	_flush_pending_scores()

	if not _requested_board.is_empty():
		var requested: String = _requested_board
		_requested_board = ""
		_open_board(requested)

func _build_allows_submissions() -> bool:
	# Internal Play testing uses a release export of the production package.
	# Editor, debug, .dev and .itch builds cannot queue or upload ranked scores.
	return OS.get_name() == "Android" and _production_package and not OS.is_debug_build()


func _owner_matches() -> bool:
	return not _active_player_id.is_empty() and _active_player_id == SaveManager.leaderboard_owner_id

func _sync_online_records() -> void:
	if not _build_allows_submissions():
		return

	if not service_ready:
		return

	if not _owner_matches():
		return

	if _record_sync_pending:
		return

	if _records_synced_player_id == _active_player_id:
		return

	_record_sync_pending = true
	_record_sync_remaining = 4
	_record_sync_had_error = false
	_record_sync_values.clear()
	_record_sync_player_id = _active_player_id
	print("SYNC TEST: reached before first leaderboard load")
	_load_online_record(HIGH_SCORE)
	_load_online_record(HIGHEST_ROUND)
	_load_online_record(LIFETIME_RUNS)
	_load_online_record(LIFETIME_LAPS)
	
	
func _load_online_record(
	key: String
) -> void:
	if _leaderboards_client == null:
		_finish_online_record_load(
			key,
			0,
			false,
			"Leaderboards client unavailable."
		)
		return

	var leaderboard_id: String = _get_leaderboard_id(key)

	if leaderboard_id.is_empty():
		_finish_online_record_load(
			key,
			0,
			false,
			"Leaderboard ID unavailable."
		)
		return

	print(
		"SYNC TEST: immediately before Java leaderboard call for ",
		key
	)

	var task = (
		_leaderboards_client
		.loadCurrentPlayerLeaderboardScore(
			leaderboard_id,
			LEADERBOARD_TIME_SPAN_ALL_TIME,
			LEADERBOARD_COLLECTION_PUBLIC
		)
	)

	print(
		"SYNC TEST: returned from Java leaderboard call for ",
		key
	)

	_watch_task(
		task,
		func(result, error: String) -> void:
			print(
				"SYNC TEST: task callback fired for ",
				key
			)

			if not error.is_empty():
				_finish_online_record_load(
					key,
					0,
					false,
					error
				)
				return

			if result == null:
				_finish_online_record_load(
					key,
					0,
					false,
					"Leaderboard result unavailable."
				)
				return

			var score_helper = JavaClassWrapper.wrap(
				"com.bcxrr.skillissue.LeaderboardScoreHelper"
			)

			if score_helper == null:
				_finish_online_record_load(
					key,
					0,
					false,
					"Leaderboard score helper unavailable."
				)
				return

			print(
				"SYNC TEST: immediately before Java helper for ",
				key
			)

			var raw_score_result = score_helper.getRawScore(result)

			var java_exception = JavaClassWrapper.get_exception()

			if java_exception != null:
				_finish_online_record_load(
					key,
					0,
					false,
					"Leaderboard score helper failed: "
					+ str(java_exception)
				)
				return

			var raw_score: int = int(raw_score_result)

			print(
				"SYNC TEST: ",
				key,
				" = ",
				raw_score
			)

			if raw_score < 0:
				print(
					"SYNC TEST: no existing score for ",
					key,
					"; treating as zero"
				)

				_finish_online_record_load(
					key,
					0,
					true,
					""
				)
				return

			_finish_online_record_load(
				key,
				raw_score,
				true,
				""
			)
	)

	


func _finish_online_record_load(
	key: String,
	value: int,
	successful: bool,
	error: String
) -> void:
	if successful:
		_record_sync_values[key] = value
	else:
		_record_sync_had_error = true

		if not error.is_empty():
			_report_error(
				"Could not load %s: %s"
				% [
					key,
					error
				]
			)

	_record_sync_remaining -= 1

	if _record_sync_remaining > 0:
		return

	var sync_player_id: String = (
		_record_sync_player_id
	)

	_record_sync_pending = false
	_record_sync_player_id = ""

	if sync_player_id != _active_player_id:
		return

	if not _owner_matches():
		return

	var changed_local_save: bool = (
		SaveManager.reconcile_online_records(
			int(
				_record_sync_values.get(
					HIGH_SCORE,
					0
				)
			),
			int(
				_record_sync_values.get(
					HIGHEST_ROUND,
					0
				)
			),
			int(
				_record_sync_values.get(
					LIFETIME_RUNS,
					0
				)
			),
			int(
				_record_sync_values.get(
					LIFETIME_LAPS,
					0
				)
			)
		)
	)

	print(
		"SYNC TEST: reconciliation complete"
		+ " | changed_local_save=",
		changed_local_save,
		" | high_score=",
		SaveManager.best_points,
		" | highest_round=",
		SaveManager.best_round,
		" | lifetime_runs=",
		SaveManager.total_runs,
		" | lifetime_laps=",
		SaveManager.total_laps
	)

	if not _record_sync_had_error:
		_records_synced_player_id = (
			sync_player_id
		)


	records_sync_finished.emit(
		_record_sync_values.duplicate(),
		changed_local_save
	)



func submit_completed_run(points: int, round_reached: int, total_runs: int, total_laps: int) -> void:
	if not _build_allows_submissions():
		return
	if not _active_player_id.is_empty() and not SaveManager.leaderboard_owner_id.is_empty() and not _owner_matches():
		_report_error("Score uploads are on hold for a different Play Games account.")
		return
	# Only this completed run supplies score/round; historical bests stay local.
	_queue_score(HIGH_SCORE, points)
	_queue_score(HIGHEST_ROUND, round_reached)
	_queue_score(LIFETIME_RUNS, total_runs)
	_queue_score(LIFETIME_LAPS, total_laps)
	_persist_pending_scores()
	_flush_pending_scores()


# Compatibility entry points, with the same build/account policy.
func submit_high_score(score: int) -> void:
	_submit_or_queue(HIGH_SCORE, score)


func submit_highest_round(round_reached: int) -> void:
	_submit_or_queue(HIGHEST_ROUND, round_reached)


func submit_lifetime_runs(run_count: int) -> void:
	_submit_or_queue(LIFETIME_RUNS, run_count)


func submit_lifetime_laps(lap_count: int) -> void:
	_submit_or_queue(LIFETIME_LAPS, lap_count)


func sync_saved_records() -> void:
	# Retry only explicitly queued ranked results, never every saved best on login.
	_flush_pending_scores()


func _submit_or_queue(key: String, value: int) -> void:
	if not _build_allows_submissions():
		return
	if not _active_player_id.is_empty() and not SaveManager.leaderboard_owner_id.is_empty() and not _owner_matches():
		return
	_queue_score(key, value)
	_persist_pending_scores()
	_flush_pending_scores()


func _queue_score(key: String, value: int) -> void:
	if value <= 0 or _get_leaderboard_id(key).is_empty():
		return
	if value > int(pending_scores.get(key, 0)):
		pending_scores[key] = value


func _persist_pending_scores() -> void:
	SaveManager.leaderboard_pending_scores = pending_scores.duplicate()
	SaveManager.save_data()


func _flush_pending_scores() -> void:
	if not _build_allows_submissions() or not service_ready or not _owner_matches():
		return
	for key: String in pending_scores.keys():
		if not _inflight_scores.has(key):
			_submit_to_platform(key, int(pending_scores[key]))


func _submit_to_platform(key: String, value: int) -> void:
	if _leaderboards_client == null:
		return
	var submission_owner_id: String = _active_player_id
	_inflight_scores[key] = value
	var task = _leaderboards_client.submitScoreImmediate(_get_leaderboard_id(key), value)
	_watch_task(task, func(result, error: String) -> void:
		_finish_submission(key, value, submission_owner_id, result, error)
	)


func _finish_submission(key: String, value: int, submission_owner_id: String, result, error: String) -> void:
	_inflight_scores.erase(key)
	var successful: bool = error.is_empty() and result != null
	var spans: Dictionary = {}
	if successful:
		for span: int in range(3):
			var score_result = result.getScoreResult(span)
			if score_result != null:
				spans[span] = {"raw_score": int(score_result.rawScore), "new_best": bool(score_result.newBest)}
		# An older acknowledgement must never erase a newer run queued meanwhile.
		if submission_owner_id == SaveManager.leaderboard_owner_id and int(pending_scores.get(key, 0)) <= value:
			pending_scores.erase(key)
			_persist_pending_scores()
	else:
		_report_error("Score sync failed for %s (%d): %s" % [key, value, error])
		# Leave the persisted value queued. The bounded retry checks auth first.
	last_submission_results[key] = {"value": value, "successful": successful, "spans": spans, "error": error}
	var all_time: Dictionary = spans.get(2, {})
	var new_best: bool = bool(all_time.get("new_best", false))
	if debug_logging:
		print("Leaderboard result: ", key, " value=", value, " accepted=", successful, " spans=", spans)
	submission_finished.emit(key, value, successful, new_best)
	if successful and int(pending_scores.get(key, 0)) > value:
		call_deferred("_flush_pending_scores")


func show_all_leaderboards() -> void:
	_show_specific_leaderboard("all")


func show_high_score_leaderboard() -> void:
	_show_specific_leaderboard(HIGH_SCORE)


func show_highest_round_leaderboard() -> void:
	_show_specific_leaderboard(HIGHEST_ROUND)


func show_lifetime_runs_leaderboard() -> void:
	_show_specific_leaderboard(LIFETIME_RUNS)


func show_lifetime_laps_leaderboard() -> void:
	_show_specific_leaderboard(LIFETIME_LAPS)


func _show_specific_leaderboard(key: String) -> void:
	if OS.get_name() != "Android":
		return
	if not service_ready:
		_requested_board = key
		request_sign_in()
		return
	_open_board(key)


func _open_all_leaderboards() -> void:
	_open_board("all")


func _open_board(key: String) -> void:
	if _leaderboards_client == null or _activity == null or _ui_pending:
		return
	_ui_pending = true
	var task = _leaderboards_client.getAllLeaderboardsIntent() if key == "all" else _leaderboards_client.getLeaderboardIntent(_get_leaderboard_id(key))
	_watch_task(task, func(intent, error: String) -> void:
		_ui_pending = false
		if intent == null or not error.is_empty():
			_report_error("Could not open leaderboards: " + error)
			return
		# Android UI work stays on Android's UI thread.
		var activity = _activity
		_ui_launcher = JavaClassWrapper.create_sam_callback("java.lang.Runnable", func() -> void:
			activity.startActivityForResult(intent, RC_LEADERBOARDS)
		)
		if _ui_launcher != null:
			_activity.runOnUiThread(_ui_launcher)
		else:
			_report_error("Could not create leaderboard UI callback.")
	)


func _watch_task(task, callback: Callable) -> void:
	# Poll Google Tasks on Godot's main thread. No scene/save work runs in JNI callbacks.
	if task == null:
		var exception = JavaClassWrapper.get_exception()
		callback.call(null, "No Google Task returned. " + str(exception))
		return
	_tasks.append({"task": task, "callback": callback, "started": Time.get_ticks_msec()})


func _poll_tasks() -> void:
	# Snapshot first; a completed callback can register another task.
	var snapshot: Array[Dictionary] = _tasks.duplicate()
	for entry: Dictionary in snapshot:
		var task = entry["task"]
		var complete: bool = bool(task.isComplete())
		var timed_out: bool = float(Time.get_ticks_msec() - int(entry["started"])) / 1000.0 >= TASK_TIMEOUT_SECONDS
		if not complete and not timed_out:
			continue
		_tasks.erase(entry)
		var callback: Callable = entry["callback"]
		if not complete:
			callback.call(null, "Request timed out; it remains eligible for retry.")
		elif task.isSuccessful():
			callback.call(task.getResult(), "")
		else:
			callback.call(null, str(task.getException()))


func set_service_ready(value: bool) -> void:
	if service_ready == value:
		return
	service_ready = value
	service_ready_changed.emit(value)


func is_service_ready() -> bool:
	return service_ready

func is_current_player_save_owner() -> bool:
	return _owner_matches()

func has_finished_record_sync_for_current_player() -> bool:
	return (
		not _active_player_id.is_empty()
		and _records_synced_player_id
		== _active_player_id
	)

func _report_error(message: String) -> void:
	if message != last_error:
		push_warning("LeaderboardManager: " + message)
	last_error = message


func _get_leaderboard_id(key: String) -> String:
	match key:
		HIGH_SCORE:
			return HIGH_SCORE_ID
		HIGHEST_ROUND:
			return HIGHEST_ROUND_ID
		LIFETIME_RUNS:
			return LIFETIME_RUNS_ID
		LIFETIME_LAPS:
			return LIFETIME_LAPS_ID
	return ""
