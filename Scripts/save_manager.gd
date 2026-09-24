extends Node

signal profile_recovered
signal profile_changed(
	reason: String,
	urgent: bool
)

const SAVE_PATH: String = "user://core_shift_save.dat"
const PROFILE_SCHEMA_VERSION: int = 2
const PROFILE_DIAGNOSTICS: bool = true

const DEFAULT_SKIN: String = "default"
const GILDED_SKIN: String = "gilded"
const CRIMSON_SKIN: String = "crimson"
const VOLTAGE_SKIN: String = "voltage"
const GLITCH_SKIN: String = "glitch"

const CRIMSON_SKIN_PRICE: int = 25
const VOLTAGE_SKIN_PRICE: int = 50
const GLITCH_SKIN_PRICE: int = 75


var leaderboard_owner_id: String = ""
var leaderboard_pending_scores: Dictionary = {}

var best_points: int = 0
var best_round: int = 0

var level_10_skin_unlocked: bool = false
var selected_skin: String = DEFAULT_SKIN
var purchased_skins: Array[String] = []

var total_runs: int = 0
var total_laps: int = 0
var total_near_misses: int = 0
var total_echoes_destroyed: int = 0
var total_gates_destroyed: int = 0
var token_balance: int = 0
var total_tokens_collected: int = 0
var last_profile_validation_error: String = ""
var valid_local_save_loaded_at_startup: bool = false


func _ready() -> void:
	load_data()

	if PROFILE_DIAGNOSTICS:
		call_deferred("_run_profile_diagnostics")
		

func build_profile() -> Dictionary:
	return {
		"schema_version": PROFILE_SCHEMA_VERSION,
		"owner_player_id": leaderboard_owner_id,

		"progression": {
			"best_points": best_points,
			"best_round": best_round,
			"total_runs": total_runs,
			"total_laps": total_laps
		},

		"stats": {
			"total_near_misses": total_near_misses,
			"total_echoes_destroyed": total_echoes_destroyed,
			"total_gates_destroyed": total_gates_destroyed,
			"total_tokens_collected": total_tokens_collected
			
		},

		"economy": {
			"token_balance": token_balance
		},

		"cosmetics": {
			"level_10_skin_unlocked": level_10_skin_unlocked,
			"purchased_skins": purchased_skins.duplicate(),
			"selected_skin": selected_skin
		}
	}
func validate_profile(profile: Variant) -> bool:
	last_profile_validation_error = ""

	if not profile is Dictionary:
		return _profile_validation_failed(
			"Profile root is not a Dictionary."
		)

	var profile_dictionary: Dictionary = (
		profile as Dictionary
	)

	if not profile_dictionary.has("schema_version"):
		return _profile_validation_failed(
			"Profile is missing schema_version."
		)

	if not _is_non_negative_integer_value(
		profile_dictionary["schema_version"]
	):
		return _profile_validation_failed(
			"schema_version is invalid."
		)

	if int(
		profile_dictionary["schema_version"]
	) != PROFILE_SCHEMA_VERSION:
		return _profile_validation_failed(
			"Unsupported profile schema version."
		)

	if not profile_dictionary.has("owner_player_id"):
		return _profile_validation_failed(
			"Profile is missing owner_player_id."
		)

	if typeof(
		profile_dictionary["owner_player_id"]
	) != TYPE_STRING:
		return _profile_validation_failed(
			"owner_player_id is invalid."
		)

	var progression_value: Variant = (
		profile_dictionary.get(
			"progression"
		)
	)

	if not progression_value is Dictionary:
		return _profile_validation_failed(
			"Profile progression section is invalid."
		)

	var progression: Dictionary = (
		progression_value as Dictionary
	)

	if not _validate_non_negative_integer_field(
		progression,
		"best_points",
		"progression.best_points"
	):
		return false

	if not _validate_non_negative_integer_field(
		progression,
		"best_round",
		"progression.best_round"
	):
		return false

	if not _validate_non_negative_integer_field(
		progression,
		"total_runs",
		"progression.total_runs"
	):
		return false

	if not _validate_non_negative_integer_field(
		progression,
		"total_laps",
		"progression.total_laps"
	):
		return false

	var stats_value: Variant = (
		profile_dictionary.get(
			"stats"
		)
	)

	if not stats_value is Dictionary:
		return _profile_validation_failed(
			"Profile stats section is invalid."
		)

	var stats: Dictionary = (
		stats_value as Dictionary
	)

	if not _validate_non_negative_integer_field(
		stats,
		"total_near_misses",
		"stats.total_near_misses"
	):
		return false

	if not _validate_non_negative_integer_field(
		stats,
		"total_echoes_destroyed",
		"stats.total_echoes_destroyed"
	):
		return false

	if not _validate_non_negative_integer_field(
		stats,
		"total_gates_destroyed",
		"stats.total_gates_destroyed"
	):
		return false

	if not _validate_non_negative_integer_field(
		stats,
		"total_tokens_collected",
		"stats.total_tokens_collected"
	):
		return false

	var economy_value: Variant = (
		profile_dictionary.get(
			"economy"
		)
	)

	if not economy_value is Dictionary:
		return _profile_validation_failed(
			"Profile economy section is invalid."
		)

	var economy: Dictionary = (
		economy_value as Dictionary
	)

	if not _validate_non_negative_integer_field(
		economy,
		"token_balance",
		"economy.token_balance"
	):
		return false

	var cosmetics_value: Variant = (
		profile_dictionary.get(
			"cosmetics"
		)
	)

	if not cosmetics_value is Dictionary:
		return _profile_validation_failed(
			"Profile cosmetics section is invalid."
		)

	var cosmetics: Dictionary = (
		cosmetics_value as Dictionary
	)

	if not cosmetics.has(
		"level_10_skin_unlocked"
	):
		return _profile_validation_failed(
			"cosmetics.level_10_skin_unlocked is missing."
		)

	if typeof(
		cosmetics["level_10_skin_unlocked"]
	) != TYPE_BOOL:
		return _profile_validation_failed(
			"cosmetics.level_10_skin_unlocked is invalid."
		)

	var purchased_value: Variant = (
		cosmetics.get(
			"purchased_skins"
		)
	)

	if not purchased_value is Array:
		return _profile_validation_failed(
			"cosmetics.purchased_skins is invalid."
		)

	var purchased: Array = (
		purchased_value as Array
	)

	var seen_skins: Dictionary = {}

	for skin_value: Variant in purchased:
		if typeof(skin_value) != TYPE_STRING:
			return _profile_validation_failed(
				"purchased_skins contains a non-string value."
			)

		var skin_name: String = str(
			skin_value
		)

		if not _is_purchasable_skin(
			skin_name
		):
			return _profile_validation_failed(
				"purchased_skins contains an unknown skin."
			)

		if seen_skins.has(skin_name):
			return _profile_validation_failed(
				"purchased_skins contains a duplicate skin."
			)

		seen_skins[skin_name] = true

	if not cosmetics.has("selected_skin"):
		return _profile_validation_failed(
			"cosmetics.selected_skin is missing."
		)

	if typeof(
		cosmetics["selected_skin"]
	) != TYPE_STRING:
		return _profile_validation_failed(
			"cosmetics.selected_skin is invalid."
		)

	var selected: String = str(
		cosmetics["selected_skin"]
	)

	if not _is_known_skin(selected):
		return _profile_validation_failed(
			"selected_skin is unknown."
		)

	var gilded_unlocked: bool = bool(
		cosmetics["level_10_skin_unlocked"]
	)

	if (
		selected == GILDED_SKIN
		and not gilded_unlocked
	):
		return _profile_validation_failed(
			"selected_skin is Gilded but Gilded is locked."
		)

	if (
		_is_purchasable_skin(selected)
		and not purchased.has(selected)
	):
		return _profile_validation_failed(
			"selected_skin is not owned."
		)

	return true


func serialize_profile(
	profile: Dictionary
) -> String:
	if not validate_profile(profile):
		return ""

	var normalised_profile: Dictionary = (
		_normalise_profile(profile)
	)

	return JSON.stringify(
		normalised_profile
	)

func _migrate_profile_to_current(
	profile: Dictionary
) -> Dictionary:
	if not profile.has("schema_version"):
		_profile_validation_failed(
			"Profile is missing schema_version."
		)
		return {}

	var schema_value: Variant = (
		profile["schema_version"]
	)

	if not _is_non_negative_integer_value(
		schema_value
	):
		_profile_validation_failed(
			"schema_version is invalid."
		)
		return {}

	var schema_version: int = int(
		schema_value
	)

	if schema_version == PROFILE_SCHEMA_VERSION:
		return profile.duplicate(true)

	if schema_version == 1:
		var migrated_profile: Dictionary = (
			profile.duplicate(true)
		)

		var stats_value: Variant = (
			migrated_profile.get(
				"stats"
			)
		)

		if not stats_value is Dictionary:
			_profile_validation_failed(
				"Profile stats section is invalid."
			)
			return {}

		var migrated_stats: Dictionary = (
			(stats_value as Dictionary).duplicate(true)
		)

		migrated_stats[
			"total_gates_destroyed"
		] = 0

		migrated_profile["stats"] = (
			migrated_stats
		)

		migrated_profile["schema_version"] = (
			PROFILE_SCHEMA_VERSION
		)

		return migrated_profile

	_profile_validation_failed(
		"Unsupported profile schema version."
	)

	return {}

func deserialize_profile(
	serialized_profile: String
) -> Dictionary:
	if serialized_profile.is_empty():
		_profile_validation_failed(
			"Serialized profile is empty."
		)
		return {}

	var parsed_profile: Variant = (
		JSON.parse_string(
			serialized_profile
		)
	)
	if not parsed_profile is Dictionary:
		_profile_validation_failed(
			"Profile root is not a Dictionary."
		)
		return {}

	var migrated_profile: Dictionary = (
		_migrate_profile_to_current(
			parsed_profile as Dictionary
		)
	)

	if migrated_profile.is_empty():
		return {}

	if not validate_profile(
		migrated_profile
	):
		return {}

	return _normalise_profile(
		migrated_profile
	)


func _normalise_profile(
	profile: Dictionary
) -> Dictionary:
	var progression: Dictionary = (
		profile["progression"] as Dictionary
	)

	var stats: Dictionary = (
		profile["stats"] as Dictionary
	)

	var economy: Dictionary = (
		profile["economy"] as Dictionary
	)

	var cosmetics: Dictionary = (
		profile["cosmetics"] as Dictionary
	)

	var normalised_purchased: Array[String] = []

	for skin_value: Variant in cosmetics["purchased_skins"]:
		normalised_purchased.append(
			str(skin_value)
		)

	return {
		"schema_version": int(
			profile["schema_version"]
		),
		"owner_player_id": str(
			profile["owner_player_id"]
		),

		"progression": {
			"best_points": int(
				progression["best_points"]
			),
			"best_round": int(
				progression["best_round"]
			),
			"total_runs": int(
				progression["total_runs"]
			),
			"total_laps": int(
				progression["total_laps"]
			)
		},

		"stats": {
			"total_near_misses": int(
				stats["total_near_misses"]
			),
			"total_echoes_destroyed": int(
				stats["total_echoes_destroyed"]
			),
			"total_gates_destroyed": int(
				stats["total_gates_destroyed"]
			),
			"total_tokens_collected": int(
				stats["total_tokens_collected"]
			)
		},

		"economy": {
			"token_balance": int(
				economy["token_balance"]
			)
		},

		"cosmetics": {
			"level_10_skin_unlocked": bool(
				cosmetics["level_10_skin_unlocked"]
			),
			"purchased_skins": normalised_purchased,
			"selected_skin": str(
				cosmetics["selected_skin"]
			)
		}
	}

func started_with_local_save() -> bool:
	return valid_local_save_loaded_at_startup


func apply_cloud_recovery_profile(
	profile: Dictionary
	) -> bool:
	if valid_local_save_loaded_at_startup:
		return false

	if not validate_profile(profile):
		return false

	var cloud_owner: String = str(
		profile.get(
			"owner_player_id",
			""
		)
	)

	if (
		cloud_owner.is_empty()
		or cloud_owner != leaderboard_owner_id
	):
		return false

	var progression: Dictionary = (
		profile.get(
			"progression",
			{}
		)
	)

	var stats: Dictionary = (
		profile.get(
			"stats",
			{}
		)
	)

	var economy: Dictionary = (
		profile.get(
			"economy",
			{}
		)
	)

	var cosmetics: Dictionary = (
		profile.get(
			"cosmetics",
			{}
		)
	)

	# Leaderboard-backed fields may already have been
	# recovered from Google Play Games. Never lower them.
	best_points = max(
		best_points,
		int(
			progression.get(
				"best_points",
				0
			)
		)
	)

	best_round = max(
		best_round,
		int(
			progression.get(
				"best_round",
				0
			)
		)
	)

	total_runs = max(
		total_runs,
		int(
			progression.get(
				"total_runs",
				0
			)
		)
	)

	total_laps = max(
		total_laps,
		int(
			progression.get(
				"total_laps",
				0
			)
		)
	)

	# These are monotonic lifetime counters.
	total_near_misses = max(
		total_near_misses,
		int(
			stats.get(
				"total_near_misses",
				0
			)
		)
	)

	total_echoes_destroyed = max(
		total_echoes_destroyed,
		int(
			stats.get(
				"total_echoes_destroyed",
				0
			)
		)
	)

	total_gates_destroyed = max(
		total_gates_destroyed,
		int(
			stats.get(
				"total_gates_destroyed",
				0
			)
		)
	)

	total_tokens_collected = max(
		total_tokens_collected,
		int(
			stats.get(
				"total_tokens_collected",
				0
			)
		)
	)

	# Token balance is NOT monotonic.
	# This assignment is permitted only because this
	# process started without a local save.
	token_balance = int(
		economy.get(
			"token_balance",
			0
		)
	)

	level_10_skin_unlocked = bool(
		cosmetics.get(
			"level_10_skin_unlocked",
			false
		)
	)

	purchased_skins.clear()

	var cloud_purchased_skins: Array = (
		cosmetics.get(
			"purchased_skins",
			[]
		)
	)

	for skin_name: Variant in cloud_purchased_skins:
		purchased_skins.append(
			str(skin_name)
		)

	selected_skin = str(
		cosmetics.get(
			"selected_skin",
			DEFAULT_SKIN
		)
	)

	save_data()
	profile_recovered.emit()

	return true

func _validate_non_negative_integer_field(
	section: Dictionary,
	key: String,
	label: String
) -> bool:
	if not section.has(key):
		return _profile_validation_failed(
			label + " is missing."
		)

	if not _is_non_negative_integer_value(
		section[key]
	):
		return _profile_validation_failed(
			label + " is invalid."
		)

	return true


func _is_non_negative_integer_value(
	value: Variant
) -> bool:
	var value_type: int = typeof(value)

	if (
		value_type != TYPE_INT
		and value_type != TYPE_FLOAT
	):
		return false

	var numeric_value: float = float(value)

	return (
		numeric_value >= 0.0
		and numeric_value == floor(numeric_value)
	)


func _is_known_skin(
	skin_name: String
) -> bool:
	return (
		skin_name == DEFAULT_SKIN
		or skin_name == GILDED_SKIN
		or skin_name == CRIMSON_SKIN
		or skin_name == VOLTAGE_SKIN
		or skin_name == GLITCH_SKIN
	)

func _is_purchasable_skin(
	skin_name: String
) -> bool:
	return (
		skin_name == CRIMSON_SKIN
		or skin_name == VOLTAGE_SKIN
		or skin_name == GLITCH_SKIN
	)


func _profile_validation_failed(
	message: String
) -> bool:
	last_profile_validation_error = message
	return false

func run_profile_round_trip_test() -> bool:
	var original_profile: Dictionary = (
		build_profile()
	)

	var serialized_profile: String = (
		serialize_profile(
			original_profile
		)
	)

	if serialized_profile.is_empty():
		return false

	var restored_profile: Dictionary = (
		deserialize_profile(
			serialized_profile
		)
	)

	if restored_profile.is_empty():
		return false

	var expected_profile: Dictionary = (
		_normalise_profile(
			original_profile
		)
	)

	if expected_profile != restored_profile:
		return _profile_validation_failed(
			"Profile changed during serialization round-trip."
		)

	return true

func run_profile_v1_migration_test() -> bool:
	var legacy_profile: Dictionary = (
		build_profile()
	)

	legacy_profile["schema_version"] = 1

	var legacy_stats: Dictionary = (
		legacy_profile["stats"] as Dictionary
	)

	legacy_stats.erase(
		"total_gates_destroyed"
	)

	var serialized_legacy: String = (
		JSON.stringify(
			legacy_profile
		)
	)

	var migrated_profile: Dictionary = (
		deserialize_profile(
			serialized_legacy
		)
	)

	if migrated_profile.is_empty():
		return false

	if int(
		migrated_profile["schema_version"]
	) != PROFILE_SCHEMA_VERSION:
		return _profile_validation_failed(
			"Profile v1 migration did not update schema."
		)

	var migrated_stats: Dictionary = (
		migrated_profile["stats"] as Dictionary
	)

	if int(
		migrated_stats.get(
			"total_gates_destroyed",
			-1
		)
	) != 0:
		return _profile_validation_failed(
			"Profile v1 migration produced invalid gate count."
		)

	return true

func _run_profile_diagnostics() -> void:
	var profile_valid: bool = (
		validate_profile(
			build_profile()
		)
	)

	var round_trip_valid: bool = false
	var migration_valid: bool = false

	if profile_valid:
		round_trip_valid = (
			run_profile_round_trip_test()
		)

	migration_valid = (
		run_profile_v1_migration_test()
	)

	print(
		"PROFILE TEST: validation=",
		profile_valid,
		" | round_trip=",
		round_trip_valid,
		" | migration_v1=",
		migration_valid,
		" | schema=",
		PROFILE_SCHEMA_VERSION
	)

	if (
		not profile_valid
		or not round_trip_valid
		or not migration_valid
	):
		print(
			"PROFILE TEST: error=",
			last_profile_validation_error
		)

func submit_points(points: int) -> bool:
	if points <= best_points:
		return false

	best_points = points
	save_data()
	profile_changed.emit(
		"high_score",
		false
	)
	return true


# Compatibility helper.
# From this version onward, "score" means points.
func submit_score(score: int) -> bool:
	return submit_points(score)


func record_completed_run(
	round_reached: int,
	points_earned: int,
	near_misses: int
) -> Dictionary:

	total_runs += 1
	total_laps += round_reached
	total_near_misses += near_misses

	var got_new_best_round: bool = (
		round_reached > best_round
	)

	var got_new_best_points: bool = (
		points_earned > best_points
	)

	if got_new_best_round:
		best_round = round_reached

	if got_new_best_points:
		best_points = points_earned

	save_data()
	profile_changed.emit(
	"completed_run",
	true
)
	return {
		"new_best_round": got_new_best_round,
		"new_best_points": got_new_best_points
	}
func reconcile_online_records(
	online_best_points: int,
	online_best_round: int,
	online_total_runs: int,
	online_total_laps: int
) -> bool:
	var changed: bool = false

	if online_best_points > best_points:
		best_points = online_best_points
		changed = true

	if online_best_round > best_round:
		best_round = online_best_round
		changed = true

	if online_total_runs > total_runs:
		total_runs = online_total_runs
		changed = true

	if online_total_laps > total_laps:
		total_laps = online_total_laps
		changed = true

	if changed:
		save_data()
		profile_changed.emit(
			"leaderboard_reconcile",
			false
		)
			

	return changed

func select_skin(skin_name: String) -> bool:
	if not is_skin_owned(skin_name):
		return false

	selected_skin = skin_name
	save_data()

	return true


func is_gilded_skin_selected() -> bool:
	return (
		selected_skin == GILDED_SKIN
		and level_10_skin_unlocked
	)


func is_skin_owned(skin_name: String) -> bool:
	if skin_name == DEFAULT_SKIN:
		return true

	if skin_name == GILDED_SKIN:
		return level_10_skin_unlocked

	return purchased_skins.has(skin_name)


func get_skin_price(skin_name: String) -> int:
	match skin_name:
		CRIMSON_SKIN:
			return CRIMSON_SKIN_PRICE

		VOLTAGE_SKIN:
			return VOLTAGE_SKIN_PRICE

		GLITCH_SKIN:
			return GLITCH_SKIN_PRICE

	return 0


func get_skin_display_name(
	skin_name: String
) -> String:
	match skin_name:
		DEFAULT_SKIN:
			return "DEFAULT"

		GILDED_SKIN:
			return "GILDED CORE"

		CRIMSON_SKIN:
			return "CRIMSON"

		VOLTAGE_SKIN:
			return "VOLTAGE"

		GLITCH_SKIN:
			return "GLITCH"

	return "UNKNOWN"



func unlock_level_10_skin() -> bool:
	if level_10_skin_unlocked:
		return false

	level_10_skin_unlocked = true
	selected_skin = GILDED_SKIN
	save_data()

	profile_changed.emit(
	"gilded_unlocked",
	true
)
	return true


func save_data() -> void:
	var file: FileAccess = FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		push_warning("Could not save game data.")
		return

	file.store_var({
		"leaderboard_owner_id": leaderboard_owner_id,
		"leaderboard_pending_scores": leaderboard_pending_scores,
		"best_points": best_points,
		"best_round": best_round,
		"level_10_skin_unlocked": level_10_skin_unlocked,
		"selected_skin": selected_skin,
		"total_runs": total_runs,
		"total_laps": total_laps,
		"total_near_misses": total_near_misses,
		"total_echoes_destroyed": total_echoes_destroyed,
		"total_gates_destroyed": total_gates_destroyed,
		"token_balance": token_balance,
		"total_tokens_collected": total_tokens_collected,
		"purchased_skins": purchased_skins
	})


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file: FileAccess = FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		push_warning("Could not load game data.")
		return

	var data: Variant = file.get_var()

	if not data is Dictionary:
		push_warning("Save data is invalid.")
		return

	var save_dictionary: Dictionary = (
		data as Dictionary
	)

	if not (
		save_dictionary.has("best_round")
		or save_dictionary.has("best_score")
	):
		push_warning(
			"Save data is missing core progression data."
		)
		return

	leaderboard_owner_id = str(save_dictionary.get("leaderboard_owner_id", ""))
	var saved_pending: Variant = save_dictionary.get("leaderboard_pending_scores", {})
	leaderboard_pending_scores = saved_pending.duplicate() if saved_pending is Dictionary else {}

	var migrated_old_save: bool = false


	# New save format.
	if save_dictionary.has("best_round"):
		best_round = int(
			save_dictionary.get(
				"best_round",
				0
			)
		)

	else:
		# Old saves used best_score to represent
		# the highest round reached.
		best_round = int(
			save_dictionary.get(
				"best_score",
				0
			)
		)

		migrated_old_save = true


	# Old saves never had a points-based score.
	best_points = int(
		save_dictionary.get(
			"best_points",
			0
		)
	)


	level_10_skin_unlocked = bool(
		save_dictionary.get(
			"level_10_skin_unlocked",
			false
		)
	)


	total_runs = int(
		save_dictionary.get(
			"total_runs",
			0
		)
	)


	total_laps = int(
		save_dictionary.get(
			"total_laps",
			0
		)
	)

	total_echoes_destroyed = int(
		save_dictionary.get(
			"total_echoes_destroyed",
			0
		)
	)
	
	total_gates_destroyed = int(
		save_dictionary.get(
			"total_gates_destroyed",
			0
		)
	)
	
	token_balance = int(
	save_dictionary.get(
		"token_balance",
		0
		)
	)

	total_tokens_collected = int(
		save_dictionary.get(
			"total_tokens_collected",
			0
		)
	)

	total_near_misses = int(
		save_dictionary.get(
			"total_near_misses",
			0
		)
	)
	purchased_skins.clear()

	var saved_purchased_skins: Array = (
		save_dictionary.get(
			"purchased_skins",
			[]
		)
	)

	for skin_name: Variant in saved_purchased_skins:
		var skin_string: String = str(
			skin_name
		)

		if (
			skin_string == CRIMSON_SKIN
			or skin_string == VOLTAGE_SKIN
			or skin_string == GLITCH_SKIN
		):
			if not purchased_skins.has(
				skin_string
			):
				purchased_skins.append(
					skin_string
				)

	# Older saves may not contain selected_skin.
	# If Gilded was already unlocked, preserve it.
	var fallback_skin: String = DEFAULT_SKIN

	if level_10_skin_unlocked:
		fallback_skin = GILDED_SKIN


	selected_skin = str(
		save_dictionary.get(
			"selected_skin",
			fallback_skin
		)
	)


	if not (
		selected_skin == DEFAULT_SKIN
		or selected_skin == GILDED_SKIN
		or selected_skin == CRIMSON_SKIN
		or selected_skin == VOLTAGE_SKIN
		or selected_skin == GLITCH_SKIN
	):
		selected_skin = DEFAULT_SKIN


	# Prevent a locked skin from being selected.
	if (
		selected_skin == GILDED_SKIN
		and not level_10_skin_unlocked
	):
		selected_skin = DEFAULT_SKIN
	if not is_skin_owned(selected_skin):
		selected_skin = DEFAULT_SKIN


	# Convert old saves to the new format
	# after they have loaded successfully.
	if migrated_old_save:
		save_data()
	valid_local_save_loaded_at_startup = true

func record_echo_destroyed() -> void:
	total_echoes_destroyed += 1
	save_data()

	profile_changed.emit(
		"echo_destroyed",
		false
	)


func record_gate_destroyed() -> void:
	total_gates_destroyed += 1
	save_data()

	profile_changed.emit(
		"gate_destroyed",
		false
	)


func add_tokens(amount: int) -> void:
	if amount <= 0:
		return

	token_balance += amount
	total_tokens_collected += amount

	save_data()

	profile_changed.emit(
		"tokens_added",
		false
	)


func spend_tokens(amount: int) -> bool:
	if amount <= 0:
		return false

	if token_balance < amount:
		return false

	token_balance -= amount
	save_data()

	return true

func purchase_skin(skin_name: String) -> bool:
	if is_skin_owned(skin_name):
		return false

	var price: int = get_skin_price(
		skin_name
	)

	if price <= 0:
		return false

	if token_balance < price:
		return false

	token_balance -= price
	purchased_skins.append(
		skin_name
	)

	# Buying automatically equips it.
	selected_skin = skin_name

	save_data()

	profile_changed.emit(
		"skin_purchased",
		true
	)

	profile_changed.emit(
		"tokens_spent",
		true
	)
	return true
