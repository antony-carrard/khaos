extends Control
class_name NotYourTurnOverlay

## Shown during another player's turn in network mode. Never blocks input.
## Host only: a "Skip turn" button while the player to move has disconnected.
## Debug builds also get an "End Opponent Turn" button for solo testing.

const DEBUG_BTN_FONT_SIZE: int = 18
const SKIP_BTN_FONT_SIZE: int = 20

signal debug_end_turn_requested
signal skip_turn_requested

var _skip_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	if OS.is_debug_build():
		var btn := Button.new()
		btn.text = "[DEBUG] End Opponent Turn"
		btn.add_theme_font_size_override("font_size", DEBUG_BTN_FONT_SIZE)
		btn.custom_minimum_size = Vector2(260, 44)
		btn.anchor_left = 0.5
		btn.anchor_right = 0.5
		btn.anchor_top = 1.0
		btn.anchor_bottom = 1.0
		btn.offset_left = -130
		btn.offset_right = 130
		btn.offset_top = -60
		btn.offset_bottom = -16
		btn.pressed.connect(func() -> void: debug_end_turn_requested.emit())
		add_child(btn)

	# Sits just above the debug button.
	_skip_button = Button.new()
	_skip_button.add_theme_font_size_override("font_size", SKIP_BTN_FONT_SIZE)
	_skip_button.anchor_left = 0.5
	_skip_button.anchor_right = 0.5
	_skip_button.anchor_top = 1.0
	_skip_button.anchor_bottom = 1.0
	_skip_button.offset_left = -180
	_skip_button.offset_right = 180
	_skip_button.offset_top = -124
	_skip_button.offset_bottom = -72
	_skip_button.visible = false
	_skip_button.pressed.connect(func() -> void: skip_turn_requested.emit())
	add_child(_skip_button)


## Shows the skip button for `player`'s turn, or hides it when null.
func set_skip_target(player: Player) -> void:
	_skip_button.visible = player != null
	if player:
		_skip_button.text = "Skip %s's turn (disconnected)" % player.player_name


## Show the overlay (opponent's turn). _player is unused visually but kept for API compatibility.
func show_for_player(_player: Player) -> void:
	visible = true


## Hide the overlay (local player's turn).
func hide_overlay() -> void:
	visible = false
