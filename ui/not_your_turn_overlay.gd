extends Control
class_name NotYourTurnOverlay

## Shown in network mode when it is not the local player's turn.
## Visual: subtle full-screen tint + compact bottom banner (game stays fully readable).
## Input: blocks left/right mouse clicks so the local player can't interact with the board;
##        middle-mouse (camera pan) and mouse motion pass through freely.

const TINT_ALPHA: float = 0.12
const BANNER_HEIGHT: int = 68
const MESSAGE_FONT_SIZE: int = 26
const DEBUG_BTN_FONT_SIZE: int = 18

var _message_label: Label = null

signal debug_end_turn_requested


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # _input() handles selective blocking
	visible = false

	# Very subtle full-screen tint — game is still clearly readable
	var tint := ColorRect.new()
	tint.color = Color(0.0, 0.0, 0.05, TINT_ALPHA)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)

	# Compact bottom banner
	var banner := PanelContainer.new()
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.anchor_top = 1.0
	banner.anchor_bottom = 1.0
	banner.offset_top = -BANNER_HEIGHT
	banner.offset_bottom = 0
	banner.mouse_filter = Control.MOUSE_FILTER_STOP  # banner itself catches any stray clicks
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.12, 0.92)
	style.border_color = Color(0.30, 0.22, 0.50)
	style.border_width_top = 1
	banner.add_theme_stylebox_override("panel", style)
	add_child(banner)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(center)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 40)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(hbox)

	_message_label = Label.new()
	_message_label.add_theme_font_size_override("font_size", MESSAGE_FONT_SIZE)
	_message_label.add_theme_color_override("font_color", Color.WHITE)
	_message_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.12))
	_message_label.add_theme_constant_override("outline_size", 3)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_message_label)

	if OS.is_debug_build():
		var btn := Button.new()
		btn.text = "[DEBUG] End Opponent Turn"
		btn.add_theme_font_size_override("font_size", DEBUG_BTN_FONT_SIZE)
		btn.custom_minimum_size = Vector2(260, 44)
		btn.pressed.connect(func() -> void: debug_end_turn_requested.emit())
		hbox.add_child(btn)


## Block left/right mouse clicks on the game board while the overlay is visible.
## Exceptions that pass through freely:
##   - Middle-mouse button (camera pan)
##   - Clicks in the bottom banner area (so the debug button works)
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			return  # always let camera pan through
		# Let clicks in the banner strip through so the debug button can fire
		var viewport_height: float = get_viewport().get_visible_rect().size.y
		if mb.position.y >= viewport_height - BANNER_HEIGHT:
			return
		get_viewport().set_input_as_handled()


## Show the overlay for the given active player (who is NOT the local player).
func show_for_player(player: Player) -> void:
	_message_label.text = "%s's Turn — Waiting…" % player.player_name
	_message_label.add_theme_color_override("font_color", player.player_color.lightened(0.2))
	visible = true


## Hide the overlay (local player's turn).
func hide_overlay() -> void:
	visible = false
