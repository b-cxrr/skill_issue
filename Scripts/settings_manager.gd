extends Node

const SAVE_PATH: String = (
	"user://skill_issue_settings.dat"
)

var sound_enabled: bool = true
var vibration_enabled: bool = true


func _ready() -> void:
	load_settings()
	_apply_sound_setting()


func toggle_sound() -> bool:
	sound_enabled = not sound_enabled

	_apply_sound_setting()
	save_settings()

	return sound_enabled


func toggle_vibration() -> bool:
	vibration_enabled = not vibration_enabled

	save_settings()

	return vibration_enabled


func vibrate(
	duration_ms: int,
	amplitude: float
) -> void:
	if not vibration_enabled:
		return

	Input.vibrate_handheld(
		duration_ms,
		amplitude
	)


func _apply_sound_setting() -> void:
	var master_bus: int = AudioServer.get_bus_index(
		"Master"
	)

	AudioServer.set_bus_mute(
		master_bus,
		not sound_enabled
	)


func save_settings() -> void:
	var file: FileAccess = FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		push_warning("Could not save settings.")
		return

	file.store_var({
		"sound_enabled": sound_enabled,
		"vibration_enabled": vibration_enabled
	})


func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file: FileAccess = FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		push_warning("Could not load settings.")
		return

	var data: Variant = file.get_var()

	if data is Dictionary:
		sound_enabled = bool(
			data.get("sound_enabled", true)
		)

		vibration_enabled = bool(
			data.get("vibration_enabled", true)
		)
