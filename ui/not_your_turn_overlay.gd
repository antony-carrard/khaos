extends Control
class_name NotYourTurnOverlay

## Debug helper shown during another player's turn in network mode.
## In release builds this node is a no-op (invisible, no input blocking).
## In debug builds it shows an "End Opponent Turn" button for solo testing.

const DEBUG_BTN_FONT_SIZE: int = 18

signal debug_end_turn_requested


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


## Show the overlay (opponent's turn). _player is unused visually but kept for API compatibility.
func show_for_player(_player: Player) -> void:
	visible = true


## Hide the overlay (local player's turn).
func hide_overlay() -> void:
	visible = false
