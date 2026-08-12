extends Node

const SAVE_PATH: String = "user://core_shift_save.dat"

const DEFAULT_SKIN: String = "default"
const GILDED_SKIN: String = "gilded"

var best_score: int = 0
var level_10_skin_unlocked: bool = false
var selected_skin: String = DEFAULT_SKIN

var total_runs: int = 0
var total_laps: int = 0
var total_near_misses: int = 0


func _ready() -> void:
	load_data()


func submit_score(score: int) -> bool:
	if score <= best_score:
		return false

	best_score = score
	save_data()

	return true


func record_completed_run(
	score: int,
	near_misses: int
) -> bool:
	total_runs += 1
	total_laps += score
	total_near_misses += near_misses

	var got_new_best: bool = (
		score > best_score
	)

	if got_new_best:
		best_score = score

	save_data()

	return got_new_best


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
		"best_score": best_score,
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

	best_score = int(
		data.get("best_score", 0)
	)

	level_10_skin_unlocked = bool(
		data.get(
			"level_10_skin_unlocked",
			false
		)
	)

	total_runs = int(
		data.get("total_runs", 0)
	)

	total_laps = int(
		data.get("total_laps", 0)
	)

	total_near_misses = int(
		data.get(
			"total_near_misses",
			0
		)
	)

	# Existing v1.0.1 saves do not contain selected_skin.
	# Players who already unlocked Gilded Core retain it.
	var fallback_skin: String = DEFAULT_SKIN

	if level_10_skin_unlocked:
		fallback_skin = GILDED_SKIN

	selected_skin = str(
		data.get(
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

	# Prevent a locked skin from remaining selected.
	if (
		selected_skin == GILDED_SKIN
		and not level_10_skin_unlocked
	):
		selected_skin = DEFAULT_SKIN
