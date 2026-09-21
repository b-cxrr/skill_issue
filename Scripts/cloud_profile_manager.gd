extends Node


const PRODUCTION_PACKAGE: String = "com.bcxrr.skillissue"
const PROFILE_SNAPSHOT_NAME: String = "skill_issue_profile"

const POLL_SECONDS: float = 0.25
const TASK_TIMEOUT_SECONDS: float = 30.0


var _android_runtime = null
var _activity = null
var _snapshots_client = null
var _snapshot_helper = null

var _tasks: Array[Dictionary] = []

var _poll_elapsed: float = 0.0
var _cloud_flow_started: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if OS.get_name() != "Android":
		return

	LeaderboardManager.service_ready_changed.connect(
		_on_service_ready_changed
	)

	LeaderboardManager.records_sync_finished.connect(
		_on_records_sync_finished
	)

	if LeaderboardManager.is_service_ready():
		call_deferred(
			"_try_start_cloud_flow"
		)


func _process(delta: float) -> void:
	if OS.get_name() != "Android":
		return

	_poll_elapsed += delta

	if _poll_elapsed >= POLL_SECONDS:
		_poll_elapsed = 0.0
		_poll_tasks()


func _on_service_ready_changed(
	is_ready: bool
) -> void:
	if not is_ready:
		return

	_try_start_cloud_flow()


func _on_records_sync_finished(
	_records: Dictionary,
	_changed_local_save: bool
) -> void:
	_try_start_cloud_flow()


func _try_start_cloud_flow() -> void:
	if _cloud_flow_started:
		return

	if not _build_allows_cloud():
		return

	if not LeaderboardManager.is_service_ready():
		return

	if not (
		LeaderboardManager
		.has_finished_record_sync_for_current_player()
	):
		print(
			"CLOUD TEST: waiting for "
			+ "leaderboard reconciliation"
		)
		return

	if not LeaderboardManager.is_current_player_save_owner():
		print(
			"CLOUD TEST: blocked - "
			+ "current player does not own local save"
		)
		return

	if SaveManager.leaderboard_owner_id.is_empty():
		print(
			"CLOUD TEST: blocked - "
			+ "save owner is empty"
		)
		return

	if not _initialise_snapshots_client():
		return

	_cloud_flow_started = true

	print(
		"CLOUD TEST: leaderboard reconciliation "
		+ "finished; starting cloud profile flow"
	)

	print(
		"CLOUD TEST: local_save_existed_at_startup=",
		SaveManager.started_with_local_save()
	)

	_run_initial_listing()


func _build_allows_cloud() -> bool:
	if OS.get_name() != "Android":
		return false

	if OS.is_debug_build():
		return false

	return true


func _initialise_snapshots_client() -> bool:
	if (
		_snapshots_client != null
		and _snapshot_helper != null
	):
		return true

	_android_runtime = Engine.get_singleton(
		"AndroidRuntime"
	)

	if _android_runtime == null:
		push_warning(
			"CloudProfileManager: AndroidRuntime unavailable."
		)
		return false

	_activity = _android_runtime.getActivity()

	if _activity == null:
		push_warning(
			"CloudProfileManager: Android Activity unavailable."
		)
		return false

	if str(
		_activity.getPackageName()
	) != PRODUCTION_PACKAGE:
		return false

	var games = JavaClassWrapper.wrap(
		"com.google.android.gms.games.PlayGames"
	)

	if games == null:
		push_warning(
			"CloudProfileManager: Play Games unavailable."
		)
		return false

	_snapshots_client = games.getSnapshotsClient(
		_activity
	)

	if _snapshots_client == null:
		push_warning(
			"CloudProfileManager: Snapshots client unavailable."
		)
		return false

	_snapshot_helper = JavaClassWrapper.wrap(
		"com.bcxrr.skillissue.SavedGameSnapshotHelper"
	)

	if _snapshot_helper == null:
		push_warning(
			"CloudProfileManager: Snapshot helper unavailable."
		)
		return false

	return true


func _run_initial_listing() -> void:
	print(
		"CLOUD TEST: loading current snapshot list"
	)

	var task = _snapshots_client.load(true)

	_watch_task(
		task,
		func(result, error: String) -> void:
			if not error.is_empty():
				print(
					"CLOUD TEST: listing error=",
					error
				)
				return

			if result == null:
				print(
					"CLOUD TEST: listing error=null_result"
				)
				return

			var summary_result = (
				_snapshot_helper.summarizeSnapshots(
					result
				)
			)

			var java_exception = (
				JavaClassWrapper.get_exception()
			)

			if java_exception != null:
				print(
					"CLOUD TEST: listing helper exception=",
					java_exception
				)
				return

			var summary: String = str(
				summary_result
			)

			print(
				"CLOUD TEST: initial ",
				summary
			)

			if summary == "count=0|files=":
				print(
					"CLOUD TEST: no cloud profile exists; "
					+ "creating current profile"
				)

				_write_current_profile_to_cloud(
					"initial_create"
				)
				return

			if summary.contains(
				PROFILE_SNAPSHOT_NAME
			):
				_read_profile_snapshot()
				return

			print(
				"CLOUD TEST: unexpected snapshot state; "
				+ "cloud flow aborted"
			)
	)


func _read_profile_snapshot() -> void:
	print(
		"CLOUD TEST: opening cloud profile"
	)

	var task = _snapshots_client.open(
		PROFILE_SNAPSHOT_NAME,
		false
	)

	_watch_task(
		task,
		func(result, error: String) -> void:
			if not error.is_empty():
				print(
					"CLOUD TEST: read open error=",
					error
				)
				return

			if result == null:
				print(
					"CLOUD TEST: read error=null_result"
				)
				return

			var open_status: String = str(
				_snapshot_helper.inspectOpenResult(
					result
				)
			)

			var java_exception = (
				JavaClassWrapper.get_exception()
			)

			if java_exception != null:
				print(
					"CLOUD TEST: read inspection exception=",
					java_exception
				)
				return

			if open_status == "conflict":
				print(
					"CLOUD TEST: cloud conflict detected; "
					+ "recovery aborted"
				)
				return

			if open_status != "ok":
				print(
					"CLOUD TEST: read ",
					open_status
				)
				return

			var payload_result = (
				_snapshot_helper.readPayload(
					result
				)
			)

			java_exception = (
				JavaClassWrapper.get_exception()
			)

			if java_exception != null:
				print(
					"CLOUD TEST: read payload exception=",
					java_exception
				)

				_discard_open_snapshot(
					result,
					false,
					""
				)
				return

			var payload: String = str(
				payload_result
			)

			var cloud_profile: Dictionary = (
				SaveManager.deserialize_profile(
					payload
				)
			)

			var profile_valid: bool = (
				not cloud_profile.is_empty()
			)

			var owner_matches: bool = false

			if profile_valid:
				owner_matches = (
					str(
						cloud_profile.get(
							"owner_player_id",
							""
						)
					)
					== SaveManager.leaderboard_owner_id
				)

			print(
				"CLOUD TEST: cloud_profile_valid=",
				profile_valid,
				" | owner_matches=",
				owner_matches,
				" | bytes=",
				payload.to_utf8_buffer().size()
			)

			if not profile_valid:
				print(
					"CLOUD TEST: invalid cloud profile; "
					+ "local save untouched"
				)

				_discard_open_snapshot(
					result,
					false,
					""
				)
				return

			if not owner_matches:
				print(
					"CLOUD TEST: cloud owner mismatch; "
					+ "local save untouched"
				)

				_discard_open_snapshot(
					result,
					false,
					""
				)
				return

			if SaveManager.started_with_local_save():
				print(
					"CLOUD TEST: existing local save kept; "
					+ "cloud mutable state not applied"
				)

				_discard_open_snapshot(
					result,
					true,
					"existing_local_refresh"
				)
				return

			var recovery_applied: bool = (
				SaveManager.apply_cloud_recovery_profile(
					cloud_profile
				)
			)

			print(
				"CLOUD TEST: fresh-install recovery_applied=",
				recovery_applied,
				" | tokens=",
				SaveManager.token_balance,
				" | selected_skin=",
				SaveManager.selected_skin,
				" | purchased_skins=",
				SaveManager.purchased_skins
			)

			_discard_open_snapshot(
				result,
				recovery_applied,
				"post_recovery_refresh"
			)
	)


func _write_current_profile_to_cloud(
	reason: String
) -> void:
	if not LeaderboardManager.is_current_player_save_owner():
		print(
			"CLOUD TEST: cloud write blocked - "
			+ "owner changed"
		)
		return

	var payload: String = (
		SaveManager.serialize_profile(
			SaveManager.build_profile()
		)
	)

	if payload.is_empty():
		print(
			"CLOUD TEST: cloud write aborted - "
			+ "profile serialization failed"
		)
		return

	print(
		"CLOUD TEST: opening profile for write"
		+ " | reason=",
		reason
	)

	var task = _snapshots_client.open(
		PROFILE_SNAPSHOT_NAME,
		true
	)

	_watch_task(
		task,
		func(result, error: String) -> void:
			if not error.is_empty():
				print(
					"CLOUD TEST: write open error=",
					error
				)
				return

			if result == null:
				print(
					"CLOUD TEST: write open error=null_result"
				)
				return

			var open_status: String = str(
				_snapshot_helper.inspectOpenResult(
					result
				)
			)

			var java_exception = (
				JavaClassWrapper.get_exception()
			)

			if java_exception != null:
				print(
					"CLOUD TEST: write inspection exception=",
					java_exception
				)
				return

			if open_status == "conflict":
				print(
					"CLOUD TEST: cloud conflict detected; "
					+ "write aborted"
				)
				return

			if open_status != "ok":
				print(
					"CLOUD TEST: write ",
					open_status
				)
				return

			var commit_task = (
				_snapshot_helper.commitPayload(
					_snapshots_client,
					result,
					payload
				)
			)

			java_exception = (
				JavaClassWrapper.get_exception()
			)

			if java_exception != null:
				print(
					"CLOUD TEST: commit preparation exception=",
					java_exception
				)
				return

			if commit_task == null:
				print(
					"CLOUD TEST: commit task is null"
				)
				return

			_watch_task(
				commit_task,
				func(
					commit_result,
					commit_error: String
				) -> void:
					if not commit_error.is_empty():
						print(
							"CLOUD TEST: commit error=",
							commit_error
						)
						return

					if commit_result == null:
						print(
							"CLOUD TEST: commit error=null_result"
						)
						return

					print(
						"CLOUD TEST: commit_success=true"
						+ " | reason=",
						reason,
						" | bytes=",
						payload.to_utf8_buffer().size()
					)

					_verify_cloud_payload(
						payload
					)
			)
	)


func _verify_cloud_payload(
	expected_payload: String
) -> void:
	print(
		"CLOUD TEST: opening profile for verification"
	)

	var task = _snapshots_client.open(
		PROFILE_SNAPSHOT_NAME,
		false
	)

	_watch_task(
		task,
		func(result, error: String) -> void:
			if not error.is_empty():
				print(
					"CLOUD TEST: verify open error=",
					error
				)
				return

			if result == null:
				print(
					"CLOUD TEST: verify error=null_result"
				)
				return

			var open_status: String = str(
				_snapshot_helper.inspectOpenResult(
					result
				)
			)

			if open_status != "ok":
				print(
					"CLOUD TEST: verify ",
					open_status
				)
				return

			var payload_result = (
				_snapshot_helper.readPayload(
					result
				)
			)

			var java_exception = (
				JavaClassWrapper.get_exception()
			)

			if java_exception != null:
				print(
					"CLOUD TEST: verify payload exception=",
					java_exception
				)

				_discard_open_snapshot(
					result,
					false,
					""
				)
				return

			var payload: String = str(
				payload_result
			)

			var verified_profile: Dictionary = (
				SaveManager.deserialize_profile(
					payload
				)
			)

			var valid: bool = (
				not verified_profile.is_empty()
			)

			var owner_matches: bool = false

			if valid:
				owner_matches = (
					str(
						verified_profile.get(
							"owner_player_id",
							""
						)
					)
					== SaveManager.leaderboard_owner_id
				)

			print(
				"CLOUD TEST: verify_valid=",
				valid,
				" | payload_matches=",
				payload == expected_payload,
				" | owner_matches=",
				owner_matches,
				" | bytes=",
				payload.to_utf8_buffer().size()
			)

			_discard_open_snapshot(
				result,
				false,
				""
			)
	)


func _discard_open_snapshot(
	open_result,
	refresh_after_close: bool,
	refresh_reason: String
) -> void:
	var discard_task = (
		_snapshot_helper.discardOpenSnapshot(
			_snapshots_client,
			open_result
		)
	)

	var java_exception = (
		JavaClassWrapper.get_exception()
	)

	if java_exception != null:
		print(
			"CLOUD TEST: discard exception=",
			java_exception
		)
		return

	if discard_task == null:
		print(
			"CLOUD TEST: discard task is null"
		)
		return

	_watch_task(
		discard_task,
		func(_result, error: String) -> void:
			if not error.is_empty():
				print(
					"CLOUD TEST: discard error=",
					error
				)
				return

			print(
				"CLOUD TEST: read snapshot closed=true"
			)

			if refresh_after_close:
				_write_current_profile_to_cloud(
					refresh_reason
				)
	)


func _watch_task(
	task,
	callback: Callable
) -> void:
	if task == null:
		var exception = (
			JavaClassWrapper.get_exception()
		)

		callback.call(
			null,
			"No Google Task returned. "
			+ str(exception)
		)
		return

	_tasks.append({
		"task": task,
		"callback": callback,
		"started": Time.get_ticks_msec()
	})


func _poll_tasks() -> void:
	var snapshot: Array[Dictionary] = (
		_tasks.duplicate()
	)

	for entry: Dictionary in snapshot:
		var task = entry["task"]

		var complete: bool = bool(
			task.isComplete()
		)

		var timed_out: bool = (
			float(
				Time.get_ticks_msec()
				- int(entry["started"])
			)
			/ 1000.0
			>= TASK_TIMEOUT_SECONDS
		)

		if not complete and not timed_out:
			continue

		_tasks.erase(entry)

		var callback: Callable = (
			entry["callback"]
		)

		if not complete:
			callback.call(
				null,
				"Request timed out."
			)

		elif task.isSuccessful():
			callback.call(
				task.getResult(),
				""
			)

		else:
			callback.call(
				null,
				str(task.getException())
			)
