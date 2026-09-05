class_name CosmeticsMenu
extends Control

signal closed
signal skin_changed(skin_name: String)


const BUTTON_NORMAL = preload(
	"res://Scenes/UI_template.tres"
)

const BUTTON_PRESSED = preload(
	"res://Scenes/UI_template_pressed.tres"
)

const BUTTON_HOVER = preload(
	"res://Scenes/UI_template_hover.tres"
)


const SKIN_ORDER: Array[String] = [
	SaveManager.DEFAULT_SKIN,
	SaveManager.GILDED_SKIN,
	SaveManager.CRIMSON_SKIN,
	SaveManager.VOLTAGE_SKIN,
	SaveManager.GLITCH_SKIN
]
const TOKEN_COLOUR: Color = Color("#7CFFB2")
const STATUS_COLOUR: Color = Color("#F7F7FF")
const LOCKED_COLOUR: Color = Color("#7D8494")

var token_label: Label
var preview_name_label: Label
var feedback_label: Label
var preview_frame: Control
var preview_player: OrbitPlayer

var skin_buttons: Dictionary = {}
var skin_status_labels: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_ui()

	visible = false


func open_menu() -> void:
	feedback_label.text = (
		"SELECT OR UNLOCK A SKIN"
	)

	_refresh_menu()

	visible = true


func close_menu() -> void:
	visible = false
	closed.emit()


func _build_ui() -> void:
	var overlay: ColorRect = ColorRect.new()

	overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	overlay.color = Color(
		0.0,
		0.0,
		0.0,
		0.88
	)

	overlay.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	add_child(overlay)


	var centre: CenterContainer = (
		CenterContainer.new()
	)

	centre.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	add_child(centre)


	var panel: PanelContainer = (
		PanelContainer.new()
	)

	panel.custom_minimum_size = Vector2(
		440.0,
		0.0
	)

	centre.add_child(panel)


	var panel_style: StyleBoxFlat = (
		StyleBoxFlat.new()
	)

	panel_style.bg_color = Color(
		0.04,
		0.05,
		0.09,
		0.96
	)

	panel_style.border_color = Color(
		"#35F2E8"
	)

	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2

	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.corner_radius_bottom_right = 18

	panel_style.content_margin_left = 24.0
	panel_style.content_margin_top = 22.0
	panel_style.content_margin_right = 24.0
	panel_style.content_margin_bottom = 22.0

	panel.add_theme_stylebox_override(
		"panel",
		panel_style
	)


	var main_vbox: VBoxContainer = (
		VBoxContainer.new()
	)

	main_vbox.add_theme_constant_override(
		"separation",
		10
	)

	panel.add_child(main_vbox)


	var title_label: Label = Label.new()

	title_label.text = "COSMETICS"

	title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title_label.add_theme_font_size_override(
		"font_size",
		36
	)

	main_vbox.add_child(title_label)


	token_label = Label.new()

	token_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	token_label.add_theme_font_size_override(
		"font_size",
		21
	)

	token_label.add_theme_color_override(
		"font_color",
		Color("#7CFFB2")
	)

	main_vbox.add_child(token_label)


	preview_frame = Control.new()

	preview_frame.custom_minimum_size = (
		Vector2(
			0.0,
			115.0
		)
	)

	preview_frame.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	main_vbox.add_child(preview_frame)

	_create_preview_player()

	preview_frame.resized.connect(
		_position_preview_player
	)


	preview_name_label = Label.new()

	preview_name_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	preview_name_label.add_theme_font_size_override(
		"font_size",
		20
	)

	main_vbox.add_child(
		preview_name_label
	)


	feedback_label = Label.new()

	feedback_label.custom_minimum_size = (
		Vector2(
			0.0,
			28.0
		)
	)

	feedback_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	feedback_label.add_theme_font_size_override(
		"font_size",
		15
	)

	feedback_label.add_theme_color_override(
		"font_color",
		Color("#A8B0C2")
	)

	main_vbox.add_child(feedback_label)


	var separator: HSeparator = (
		HSeparator.new()
	)

	main_vbox.add_child(separator)


	for skin_name: String in SKIN_ORDER:
		_create_skin_button(
			main_vbox,
			skin_name
		)


	var close_button: Button = Button.new()

	close_button.custom_minimum_size = (
		Vector2(
			0.0,
			54.0
		)
	)

	close_button.text = "BACK"

	_apply_button_style(
		close_button,
		Color("#F7F7FF")
	)

	close_button.pressed.connect(
		close_menu
	)

	main_vbox.add_child(
		close_button
	)


func _create_preview_player() -> void:
	preview_player = OrbitPlayer.new()

	preview_player.name = (
		"CosmeticPreviewPlayer"
	)

	# OrbitPlayer expects this child to exist
	# when its @onready variables initialise.
	var silent_shift_sound: AudioStreamPlayer = (
		AudioStreamPlayer.new()
	)

	silent_shift_sound.name = "ShiftSound"

	preview_player.add_child(
		silent_shift_sound
	)

	preview_frame.add_child(
		preview_player
	)

	preview_player.set_preview_mode(
		true
	)

	preview_player.set_process(
		true
	)

	preview_player.set_process_unhandled_input(
		false
	)

	preview_player.monitoring = false
	preview_player.monitorable = false

	preview_player.scale = Vector2(
		1.55,
		1.55
	)

	preview_player.set_skin(
		SaveManager.selected_skin
	)

	call_deferred(
		"_position_preview_player"
	)


func _position_preview_player() -> void:
	if preview_player == null:
		return

	if not is_instance_valid(
		preview_player
	):
		return

	preview_player.position = (
		preview_frame.size * 0.5
	)


func _create_skin_button(
	parent: VBoxContainer,
	skin_name: String
) -> void:
	var button: Button = Button.new()

	button.custom_minimum_size = Vector2(
		0.0,
		54.0
	)

	button.alignment = (
		HORIZONTAL_ALIGNMENT_LEFT
	)

	_apply_button_style(
		button,
		_get_skin_colour(
			skin_name
		)
	)

	button.pressed.connect(
		_on_skin_button_pressed.bind(
			skin_name
		)
	)

	var status_label: Label = Label.new()

	status_label.set_anchors_preset(
		Control.PRESET_CENTER_RIGHT
	)

	status_label.position = Vector2(
		-175.0,
		-15.0
	)

	status_label.size = Vector2(
		155.0,
		30.0
	)

	status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	status_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	status_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	status_label.add_theme_font_size_override(
		"font_size",
		17
	)

	button.add_child(
		status_label
	)

	parent.add_child(
		button
	)

	skin_buttons[skin_name] = button
	skin_status_labels[skin_name] = status_label


func _apply_button_style(
	button: Button,
	font_colour: Color
) -> void:
	button.add_theme_stylebox_override(
		"normal",
		BUTTON_NORMAL
	)

	button.add_theme_stylebox_override(
		"pressed",
		BUTTON_PRESSED
	)

	button.add_theme_stylebox_override(
		"hover",
		BUTTON_HOVER
	)

	button.add_theme_stylebox_override(
		"hover_pressed",
		BUTTON_HOVER
	)

	button.add_theme_font_size_override(
		"font_size",
		18
	)

	button.add_theme_color_override(
		"font_color",
		font_colour
	)

	button.add_theme_color_override(
		"font_hover_color",
		font_colour
	)

	button.add_theme_color_override(
		"font_pressed_color",
		font_colour
	)

	button.add_theme_color_override(
		"font_disabled_color",
		Color(
			font_colour.r,
			font_colour.g,
			font_colour.b,
			0.45
		)
	)


func _refresh_menu() -> void:
	token_label.text = (
		"TOKENS   ◆ %d"
		% SaveManager.token_balance
	)

	preview_name_label.text = (
		SaveManager.get_skin_display_name(
			SaveManager.selected_skin
		)
	)

	preview_player.set_skin(
		SaveManager.selected_skin
	)

	for skin_name: String in SKIN_ORDER:
		_refresh_skin_button(
			skin_name
		)


func _refresh_skin_button(
	skin_name: String
) -> void:
	if not skin_buttons.has(
		skin_name
	):
		return

	var button: Button = (
		skin_buttons[skin_name]
		as Button
	)

	var status_label: Label = (
		skin_status_labels[skin_name]
		as Label
	)

	var display_name: String = (
		SaveManager.get_skin_display_name(
			skin_name
		)
	)

	button.text = (
		"  %s"
		% display_name
	)

	if SaveManager.is_skin_owned(
		skin_name
	):
		if (
			SaveManager.selected_skin
			== skin_name
		):
			status_label.text = "EQUIPPED"
			status_label.modulate = STATUS_COLOUR

			button.disabled = true

		else:
			status_label.text = "EQUIP"
			status_label.modulate = STATUS_COLOUR

			button.disabled = false

		return

	if skin_name == SaveManager.GILDED_SKIN:
		status_label.text = "LOCKED · ROUND 10"
		status_label.modulate = LOCKED_COLOUR

		button.disabled = true
		return

	var price: int = (
		SaveManager.get_skin_price(
			skin_name
		)
	)

	if SaveManager.token_balance >= price:
		status_label.text = (
			"BUY  ◆ %d"
			% price
		)

		status_label.modulate = TOKEN_COLOUR

		button.disabled = false

	else:
		status_label.text = (
			"NEED  ◆ %d"
			% price
		)

		status_label.modulate = TOKEN_COLOUR

		button.disabled = true


func _on_skin_button_pressed(
	skin_name: String
) -> void:
	if SaveManager.is_skin_owned(
		skin_name
	):
		if SaveManager.select_skin(
			skin_name
		):
			_refresh_menu()

			feedback_label.text = (
				"%s EQUIPPED"
				% SaveManager.get_skin_display_name(
					skin_name
				)
			)

			skin_changed.emit(
				skin_name
			)

		return


	var price: int = (
		SaveManager.get_skin_price(
			skin_name
		)
	)

	if SaveManager.purchase_skin(
		skin_name
	):
		_refresh_menu()

		feedback_label.text = (
			"%s UNLOCKED + EQUIPPED"
			% SaveManager.get_skin_display_name(
				skin_name
			)
		)

		skin_changed.emit(
			SaveManager.selected_skin
		)

		return


	feedback_label.text = (
		"NOT ENOUGH TOKENS · NEED ◆%d"
		% price
	)


func _get_skin_colour(
	skin_name: String
) -> Color:
	match skin_name:
		SaveManager.GILDED_SKIN:
			return Color("#FFD54A")

		SaveManager.CRIMSON_SKIN:
			return Color("#FF315F")

		SaveManager.VOLTAGE_SKIN:
			return Color("#B8FF3D")

		SaveManager.GLITCH_SKIN:
			return Color("#FF4FD8")

		_:
			return Color("#35F2E8")
