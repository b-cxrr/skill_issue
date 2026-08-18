extends Node


signal service_ready_changed(is_ready: bool)


const HIGH_SCORE_ID: String = "CgkIu8X556UYEAIQAQ"
const HIGHEST_ROUND_ID: String = "CgkIu8X556UYEAIQAg"
const LIFETIME_LAPS_ID: String = "CgkIu8X556UYEAIQAw"
const LIFETIME_RUNS_ID: String = "CgkIu8X556UYEAIQBA"


var service_ready: bool = false
var debug_logging: bool = true

# Scores submitted before the platform service is available
# are held here temporarily.
#
# SaveManager remains the permanent local source of truth.
var pending_scores: Dictionary = {}


func _ready() -> void:
	# Wait until the other autoloads have initialised.
	call_deferred("sync_saved_records")


# ---------------------------------------------------------
# PUBLIC SUBMISSION FUNCTIONS
# ---------------------------------------------------------

func submit_high_score(score: int) -> void:
	_submit_or_queue(
		HIGH_SCORE,
		score
	)


func submit_highest_round(round_reached: int) -> void:
	_submit_or_queue(
		HIGHEST_ROUND,
		round_reached
	)


func submit_lifetime_runs(run_count: int) -> void:
	_submit_or_queue(
		LIFETIME_RUNS,
		run_count
	)


func submit_lifetime_laps(lap_count: int) -> void:
	_submit_or_queue(
		LIFETIME_LAPS,
		lap_count
	)


func sync_saved_records() -> void:
	# SaveManager is the authoritative local record.
	#
	# This can safely run after every completed run and
	# again whenever the platform service becomes ready.

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


# ---------------------------------------------------------
# LEADERBOARD DISPLAY FUNCTIONS
# ---------------------------------------------------------

func show_high_score_leaderboard() -> void:
	_show_leaderboard(
		HIGH_SCORE
	)


func show_highest_round_leaderboard() -> void:
	_show_leaderboard(
		HIGHEST_ROUND
	)


func show_lifetime_runs_leaderboard() -> void:
	_show_leaderboard(
		LIFETIME_RUNS
	)


func show_lifetime_laps_leaderboard() -> void:
	_show_leaderboard(
		LIFETIME_LAPS
	)


# ---------------------------------------------------------
# SERVICE STATE
# ---------------------------------------------------------

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
		# Re-submit the permanent local records.
		#
		# This is safer than relying only on the temporary
		# in-memory queue because the game may previously
		# have been closed while offline.
		sync_saved_records()
		_flush_pending_scores()


func is_service_ready() -> bool:
	return service_ready


# ---------------------------------------------------------
# INTERNAL SUBMISSION
# ---------------------------------------------------------

func _submit_or_queue(
	leaderboard_key: String,
	value: int
) -> void:

	if value < 0:
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


# ---------------------------------------------------------
# PLATFORM INTEGRATION
# ---------------------------------------------------------

func _submit_to_platform(
	leaderboard_key: String,
	value: int
) -> bool:

	#
	# GOOGLE PLAY GAMES WILL BE CONNECTED HERE.
	#
	# For now this deliberately does nothing.
	#

	if debug_logging:
		print(
			"Would submit ",
			value,
			" to ",
			leaderboard_key
		)

	return false


func _show_leaderboard(
	leaderboard_key: String
) -> void:

	if not service_ready:
		if debug_logging:
			print(
				"Leaderboard unavailable: ",
				leaderboard_key
			)

		return

	#
	# GOOGLE PLAY GAMES LEADERBOARD UI
	# WILL BE OPENED HERE LATER.
	#

	if debug_logging:
		print(
			"Would open leaderboard: ",
			leaderboard_key
		)
