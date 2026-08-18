extends Node


const SAVE_PATH: String = "user://core_shift_save.dat"

const DEFAULT_SKIN: String = "default"
const GILDED_SKIN: String = "gilded"


var best_points: int = 0
var best_round: int = 0

var level_10_skin_unlocked: bool = false
var selected_skin: String = DEFAULT_SKIN

var total_runs: int = 0
var total_laps: int = 0
var total_near_misses: int = 0


func _ready() -> void:
	load_data()


func submit_points(points: int) -> bool:
	if points <= best_points:
		return false

	best_points = points
	save_data()

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

	return {
		"new_best_round": got_new_best_round,
		"new_best_points": got_new_best_points
	}


func select_skin(skin_name: String) -> bool:
	if skin_name == GILDED_SKIN:
		if not level_10_skin_unlocked:
			return false

	elif skin_name != DEFAULT_SKIN:
		return false

	selected_skin = skin_name
	save_data()

	return true


func is_gilded_skin_selected() -> bool:
	return (
		selected_skin == GILDED_SKIN
		and level_10_skin_unlocked
	)


func unlock_level_10_skin() -> bool:
	if level_10_skin_unlocked:
		return false

	level_10_skin_unlocked = true
	selected_skin = GILDED_SKIN
	save_data()

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
		"best_points": best_points,
		"best_round": best_round,
		"level_10_skin_unlocked": level_10_skin_unlocked,
		"selected_skin": selected_skin,
		"total_runs": total_runs,
		"total_laps": total_laps,
		"total_near_misses": total_near_misses
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


	total_near_misses = int(
		save_dictionary.get(
			"total_near_misses",
			0
		)
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


	# Repair unknown skin values.
	if (
		selected_skin != DEFAULT_SKIN
		and selected_skin != GILDED_SKIN
	):
		selected_skin = DEFAULT_SKIN


	# Prevent a locked skin from being selected.
	if (
		selected_skin == GILDED_SKIN
		and not level_10_skin_unlocked
	):
		selected_skin = DEFAULT_SKIN


	# Convert old saves to the new format
	# after they have loaded successfully.
	if migrated_old_save:
		save_data()
