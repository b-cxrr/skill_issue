extends Node

const SAVE_PATH: String = "user://core_shift_save.dat"

var best_score: int = 0
var level_10_skin_unlocked: bool = false


func _ready() -> void:
	load_data()


func submit_score(score: int) -> bool:
	if score <= best_score:
		return false

	best_score = score
	save_data()

	return true


func save_data() -> void:
	var file: FileAccess = FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		return

	file.store_var({
		"best_score": best_score,
		"level_10_skin_unlocked": level_10_skin_unlocked
	})


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file: FileAccess = FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		return

	var data: Variant = file.get_var()

	if data is Dictionary:
		best_score = int(
			data.get("best_score", 0)
		)

		level_10_skin_unlocked = bool(
			data.get(
				"level_10_skin_unlocked",
				false
			)
		)
	
func unlock_level_10_skin() -> bool:
	if level_10_skin_unlocked:
		return false

	level_10_skin_unlocked = true
	save_data()

	return true
