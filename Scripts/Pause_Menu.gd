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

@onready var volume_label: Label = (
	$PauseOverlay/PauseCenter/PauseVBox/VolumeLabel
)

@onready var volume_slider: HSlider = (
	$PauseOverlay/PauseCenter/PauseVBox/VolumeSlider
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
@onready var power_up_hud: Control = (
	%PowerUpHUD
)
@onready var arena: Node = (
	get_node("../../Arena")
)


var gameplay_available: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	pause_overlay.visible = false
	pause_button.visible = false

	sound_button.toggle_mode = true
	vibration_button.toggle_mode = true

	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 5.0

	volume_slider.set_value_no_signal(
		SettingsManager.get_master_volume_percent()
	)

	pause_button.pressed.connect(
		_pause_game
	)

	resume_button.pressed.connect(
		_resume_game
	)

	volume_slider.value_changed.connect(
		_on_volume_changed
	)

	sound_button.pressed.connect(
		_toggle_sound
	)

	vibration_button.pressed.connect(
		_toggle_vibration
	)

	restart_button.pressed.connect(
		_restart_game
	)

	_update_setting_labels()


func set_gameplay_available(
	value: bool
) -> void:
	gameplay_available = value

	if (
		not value
		and get_tree().paused
	):
		get_tree().paused = false
		pause_overlay.visible = false

	pause_button.visible = value


func _pause_game() -> void:
	if not gameplay_available:
		return

	_update_setting_labels()

	pause_overlay.visible = true
	pause_button.visible = false

	power_up_hud.visible = false
	get_tree().paused = true


func _resume_game() -> void:
	pause_overlay.visible = false
	get_tree().paused = false
	if arena.has_method(
		"is_power_up_active"
	):
		power_up_hud.visible = (
			arena.is_power_up_active()
		)

	pause_button.visible = (
		gameplay_available
	)


func _on_volume_changed(
	value: float
) -> void:
	SettingsManager.set_master_volume(
		value / 100.0
	)

	_update_setting_labels()


func _toggle_sound() -> void:
	SettingsManager.toggle_sound()

	_update_setting_labels()

	sound_button.release_focus()


func _toggle_vibration() -> void:
	SettingsManager.toggle_vibration()

	_update_setting_labels()

	vibration_button.release_focus()


func _update_setting_labels() -> void:
	var volume_percent: int = int(
		round(
			SettingsManager.get_master_volume_percent()
		)
	)

	volume_label.text = (
		"VOLUME: %d%%"
		% volume_percent
	)

	volume_slider.set_value_no_signal(
		float(volume_percent)
	)

	#
	# MUTE
	#
	if SettingsManager.sound_enabled:
		sound_button.text = "MUTE: OFF"

		sound_button.set_pressed_no_signal(
			false
		)
	else:
		sound_button.text = "MUTE: ON"

		sound_button.set_pressed_no_signal(
			true
		)

	#
	# VIBRATION
	#
	if SettingsManager.vibration_enabled:
		vibration_button.text = (
			"VIBRATION: ON"
		)

		vibration_button.set_pressed_no_signal(
			true
		)
	else:
		vibration_button.text = (
			"VIBRATION: OFF"
		)

		vibration_button.set_pressed_no_signal(
			false
		)


func _restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _unhandled_input(
	event: InputEvent
) -> void:
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


func _notification(
	what: int
) -> void:
	if not is_node_ready():
		return

	if (
		what
		== NOTIFICATION_WM_GO_BACK_REQUEST
	):
		if get_tree().paused:
			_resume_game()

		elif gameplay_available:
			_pause_game()

		else:
			get_tree().quit()

	elif (
		what
		== NOTIFICATION_APPLICATION_PAUSED
	):
		if (
			gameplay_available
			and not get_tree().paused
		):
			_pause_game()
