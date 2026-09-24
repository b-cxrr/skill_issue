class_name PlayerStatsMenu
extends Control

signal closed


const BUTTON_NORMAL = preload(
	"res://Scenes/UI_template.tres"
)

const BUTTON_PRESSED = preload(
	"res://Scenes/UI_template_pressed.tres"
)

const BUTTON_HOVER = preload(
	"res://Scenes/UI_template_hover.tres"
)


var value_labels: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_ui()

	SaveManager.profile_recovered.connect(
		_on_profile_recovered
	)

	visible = false


func open_menu() -> void:
	

	refresh_menu()
	visible = true




func close_menu() -> void:
	visible = false
	closed.emit()


func refresh_menu() -> void:
	_set_value(
		"high_score",
		SaveManager.best_points
	)

	_set_value(
		"highest_round",
		SaveManager.best_round
	)

	_set_value(
		"lifetime_runs",
		SaveManager.total_runs
	)

	_set_value(
		"lifetime_laps",
		SaveManager.total_laps
	)

	_set_value(
		"lifetime_tokens",
		SaveManager.total_tokens_collected
	)

	_set_value(
		"echoes_destroyed",
		SaveManager.total_echoes_destroyed
	)

	_set_value(
		"gates_destroyed",
		SaveManager.total_gates_destroyed
	)


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

	title_label.text = "PLAYER STATS"

	title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title_label.add_theme_font_size_override(
		"font_size",
		36
	)

	main_vbox.add_child(title_label)


	var subtitle_label: Label = Label.new()

	subtitle_label.text = "LIFETIME RECORD"

	subtitle_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	subtitle_label.add_theme_font_size_override(
		"font_size",
		15
	)

	subtitle_label.add_theme_color_override(
		"font_color",
		Color("#A8B0C2")
	)

	main_vbox.add_child(subtitle_label)


	var separator: HSeparator = (
		HSeparator.new()
	)

	main_vbox.add_child(separator)


	_create_stat_row(
		main_vbox,
		"HIGH SCORE",
		"high_score"
	)

	_create_stat_row(
		main_vbox,
		"HIGHEST ROUND",
		"highest_round"
	)

	_create_stat_row(
		main_vbox,
		"LIFETIME RUNS",
		"lifetime_runs"
	)

	_create_stat_row(
		main_vbox,
		"LIFETIME LAPS",
		"lifetime_laps"
	)

	_create_stat_row(
		main_vbox,
		"LIFETIME TOKENS",
		"lifetime_tokens"
	)

	_create_stat_row(
		main_vbox,
		"ECHOES DESTROYED",
		"echoes_destroyed"
	)

	_create_stat_row(
		main_vbox,
		"GATES DESTROYED",
		"gates_destroyed"
	)


	var bottom_separator: HSeparator = (
		HSeparator.new()
	)

	main_vbox.add_child(
		bottom_separator
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
		close_button
	)

	close_button.pressed.connect(
		close_menu
	)

	main_vbox.add_child(
		close_button
	)


func _create_stat_row(
	parent: VBoxContainer,
	label_text: String,
	key: String
) -> void:
	var row: HBoxContainer = (
		HBoxContainer.new()
	)

	row.custom_minimum_size = Vector2(
		0.0,
		42.0
	)

	parent.add_child(row)


	var name_label: Label = Label.new()

	name_label.text = label_text

	name_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	name_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	name_label.add_theme_font_size_override(
		"font_size",
		18
	)

	name_label.add_theme_color_override(
		"font_color",
		Color("#A8B0C2")
	)

	row.add_child(name_label)


	var value_label: Label = Label.new()

	value_label.text = "0"

	value_label.custom_minimum_size = Vector2(
		120.0,
		0.0
	)

	value_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	value_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	value_label.add_theme_font_size_override(
		"font_size",
		21
	)

	value_label.add_theme_color_override(
		"font_color",
		Color("#F7F7FF")
	)

	row.add_child(value_label)

	value_labels[key] = value_label


func _set_value(
	key: String,
	value: int
) -> void:
	if not value_labels.has(key):
		return

	var value_label: Label = (
		value_labels[key] as Label
	)

	value_label.text = str(value)


func _apply_button_style(
	button: Button
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

	var font_colour: Color = Color(
		"#F7F7FF"
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


func _on_profile_recovered() -> void:
	if visible:
		refresh_menu()
