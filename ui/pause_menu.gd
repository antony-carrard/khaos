extends Control
class_name PauseMenu

## In-game Esc menu: Resume / Quit to menu, with Quit asking for confirmation.
## The game keeps running underneath (a network game must keep receiving
## snapshots); the menu only blocks this machine's input while it's open.

const TITLE_FONT_SIZE: int = 40
const BODY_FONT_SIZE: int = 22
const BUTTON_FONT_SIZE: int = 24
const BUTTON_SIZE: Vector2 = Vector2(260, 56)
const DIM_COLOR: Color = Color(0, 0, 0, 0.6)

signal quit_requested

## Shown under "Quit?" — set by board_manager, since it depends on the game mode.
var quit_warning: String = ""

var _main_box: VBoxContainer
var _confirm_box: VBoxContainer
var _warning_label: Label
var _resume_button: Button
var _cancel_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Swallows clicks so nothing behind the menu (board or UI) reacts.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_main_box = _make_box("Paused")
	_resume_button = _make_button(_main_box, "Resume", close)
	_make_button(_main_box, "Quit to Menu", _show_confirm)
	center.add_child(_main_box)

	_confirm_box = _make_box("Quit?")
	_warning_label = Label.new()
	_warning_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_box.add_child(_warning_label)
	_make_button(_confirm_box, "Quit", func() -> void: quit_requested.emit())
	_cancel_button = _make_button(_confirm_box, "Cancel", _show_main)
	center.add_child(_confirm_box)


func open() -> void:
	visible = true
	_show_main()


func close() -> void:
	visible = false


## Esc steps back one screen: confirmation → main → closed.
func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if _confirm_box.visible:
			_show_main()
		else:
			close()
		get_viewport().set_input_as_handled()


## Any key the menu's own buttons didn't use stops here, so game shortcuts
## (end turn, hand slots, powers) can't fire behind it.
func _unhandled_key_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func _show_main() -> void:
	_main_box.visible = true
	_confirm_box.visible = false
	_resume_button.grab_focus()


func _show_confirm() -> void:
	_warning_label.text = quit_warning
	_warning_label.visible = not quit_warning.is_empty()
	_main_box.visible = false
	_confirm_box.visible = true
	_cancel_button.grab_focus()


func _make_box(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	return box


func _make_button(box: VBoxContainer, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.custom_minimum_size = BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(on_pressed)
	box.add_child(button)
	return button
