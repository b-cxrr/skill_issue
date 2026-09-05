extends Node

const SAVE_PATH: String = (
	"user://skill_issue_settings.dat"
)

var sound_enabled: bool = true
var vibration_enabled: bool = true

# Stored as 0.0–1.0.
# This is independent from the mute state.
var master_volume: float = 1.0


func _ready() -> void:
	load_settings()
	_apply_sound_setting()


func toggle_sound() -> bool:
	sound_enabled = not sound_enabled

	_apply_sound_setting()
	save_settings()

	return sound_enabled


func set_master_volume(
	value: float
) -> void:
	master_volume = clampf(
		value,
		0.0,
		1.0
	)

	_apply_sound_setting()
	save_settings()


func get_master_volume_percent() -> float:
	return master_volume * 100.0


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
	var master_bus: int = (
		AudioServer.get_bus_index(
			"Master"
		)
	)

	if master_bus < 0:
		return

	var volume_db: float

	if master_volume <= 0.0:
		volume_db = -80.0
	else:
		volume_db = linear_to_db(
			master_volume
		)

	AudioServer.set_bus_volume_db(
		master_bus,
		volume_db
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
		push_warning(
			"Could not save settings."
		)
		return

	file.store_var({
		"sound_enabled": sound_enabled,
		"vibration_enabled": vibration_enabled,
		"master_volume": master_volume
	})


func load_settings() -> void:
	if not FileAccess.file_exists(
		SAVE_PATH
	):
		return

	var file: FileAccess = FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		push_warning(
			"Could not load settings."
		)
		return

	var data: Variant = file.get_var()

	if data is Dictionary:
		sound_enabled = bool(
			data.get(
				"sound_enabled",
				true
			)
		)

		vibration_enabled = bool(
			data.get(
				"vibration_enabled",
				true
			)
		)

		master_volume = clampf(
			float(
				data.get(
					"master_volume",
					1.0
				)
			),
			0.0,
			1.0
		)
