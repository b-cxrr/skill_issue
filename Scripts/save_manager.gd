extends Node


const SAVE_PATH: String = "user://core_shift_save.dat"

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
var token_balance: int = 0
var total_tokens_collected: int = 0


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

func record_echo_destroyed() -> void:
	total_echoes_destroyed += 1
	save_data()


func add_tokens(amount: int) -> void:
	if amount <= 0:
		return

	token_balance += amount
	total_tokens_collected += amount

	save_data()


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

	return true
