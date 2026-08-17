class_name SkillPauseMenu
extends Control


@onready var pause_button: Button = (
	$PauseButton
)

@onready var pause_overlay: ColorRect = (
	$PauseOverlay
)

@onready var resume_button: Button = (
	$PauseOverlay/PauseCenter/PauseVBox/ResumeButton
)

@onready var sound_button: Button = (
	$PauseOverlay/PauseCenter/PauseVBox/SoundButton
)

@onready var vibration_button: Button = (
	$PauseOverlay/PauseCenter/PauseVBox/VibrationButton
)

@onready var restart_button: Button = (
	$PauseOverlay/PauseCenter/PauseVBox/RestartButton
)


var gameplay_available: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	pause_overlay.visible = false
	pause_button.visible = false

	#
	# Sound and vibration behave as ON/OFF toggle buttons.
	#
	sound_button.toggle_mode = true
	vibration_button.toggle_mode = true

	pause_button.pressed.connect(_pause_game)
	resume_button.pressed.connect(_resume_game)
	sound_button.pressed.connect(_toggle_sound)
	vibration_button.pressed.connect(_toggle_vibration)
	restart_button.pressed.connect(_restart_game)

	_update_setting_labels()


func set_gameplay_available(value: bool) -> void:
	gameplay_available = value

	if not value and get_tree().paused:
		get_tree().paused = false
		pause_overlay.visible = false

	pause_button.visible = value


func _pause_game() -> void:
	if not gameplay_available:
		return

	pause_overlay.visible = true
	pause_button.visible = false

	get_tree().paused = true


func _resume_game() -> void:
	pause_overlay.visible = false
	get_tree().paused = false

	pause_button.visible = gameplay_available


func _toggle_sound() -> void:
	SettingsManager.toggle_sound()
	_update_setting_labels()
	sound_button.release_focus()


func _toggle_vibration() -> void:
	SettingsManager.toggle_vibration()
	_update_setting_labels()
	sound_button.release_focus()

func _update_setting_labels() -> void:
	#
	# SOUND
	#
	if SettingsManager.sound_enabled:
		sound_button.text = "SOUND: ON"

		sound_button.set_pressed_no_signal(true)
	else:
		sound_button.text = "SOUND: OFF"

		sound_button.set_pressed_no_signal(false)

	#
	# VIBRATION
	#
	if SettingsManager.vibration_enabled:
		vibration_button.text = "VIBRATION: ON"

		vibration_button.set_pressed_no_signal(true)
	else:
		vibration_button.text = "VIBRATION: OFF"

		vibration_button.set_pressed_no_signal(false)


func _restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if not gameplay_available:
		return

	if event is InputEventKey:
		if (
			event.keycode == KEY_ESCAPE
			and event.pressed
			and not event.echo
		):
			if get_tree().paused:
				_resume_game()
			else:
				_pause_game()

			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if not is_node_ready():
		return

	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if get_tree().paused:
			_resume_game()

		elif gameplay_available:
			_pause_game()

		else:
			get_tree().quit()

	elif what == NOTIFICATION_APPLICATION_PAUSED:
		if gameplay_available and not get_tree().paused:
			_pause_game()
