extends Control
class_name ResourceTypePicker

## Resource type picker modal for CHANGE_TILE_TYPE power
## Shows overlay with buttons to select resource type
## Extracted from tile_selector_ui.gd for better code organization

signal resource_type_selected(q: int, r: int, resource_type: int)
signal picker_cancelled()

var overlay: ColorRect = null
var tile_q: int = 0
var tile_r: int = 0


func _ready() -> void:
	# This root control should ignore input when no overlay is shown
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows the resource type picker modal
## q, r: tile position to change
## current_type: current resource type (for display)
## tile_type: terrain type (affects whether Glory is available)
func show_picker(q: int, r: int, current_type: int, tile_type: int) -> void:
	# If an overlay already exists, force close it first
	if overlay:
		_close_picker()

	# Store tile position
	tile_q = q
	tile_r = r

	# Enable input handling on root while overlay is shown
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Create full-screen overlay
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)  # Semi-transparent black
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks from reaching 3D scene

	add_child(overlay)

	# Center container
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	# Main panel
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.border_color = Color(0.4, 0.25, 0.6)  # Purple border (Augia's color)
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(400, 250)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	# Inner margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	# Vertical layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Choose New Resource Type"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	# Subtitle showing current type
	var subtitle = Label.new()
	subtitle.text = "Current: %s" % TileManager.ResourceType.keys()[current_type]
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(subtitle)

	# Button container
	var button_container = VBoxContainer.new()
	button_container.add_theme_constant_override("separation", 12)
	button_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(button_container)

	# Create buttons for each valid resource type
	# Plains can only be Resources or Fervor (no Glory on Plains!)
	_create_resource_type_button(button_container, TileManager.ResourceType.RESOURCES, "Resources", Color(0.6, 0.4, 0.2))
	_create_resource_type_button(button_container, TileManager.ResourceType.FERVOR, "Fervor", Color(0.4, 0.3, 0.6))

	# Glory only available on Hills and Mountains
	if tile_type != TileManager.TileType.PLAINS:
		_create_resource_type_button(button_container, TileManager.ResourceType.GLORY, "Glory", Color(0.7, 0.6, 0.2))

	# Cancel button
	var cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(0, 40)
	var cancel_style = StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.3, 0.3, 0.3)
	cancel_style.corner_radius_top_left = 8
	cancel_style.corner_radius_top_right = 8
	cancel_style.corner_radius_bottom_left = 8
	cancel_style.corner_radius_bottom_right = 8
	cancel_button.add_theme_stylebox_override("normal", cancel_style)
	cancel_button.pressed.connect(_on_cancel_pressed)
	button_container.add_child(cancel_button)


## Helper to create a resource type button
func _create_resource_type_button(container: VBoxContainer, resource_type: int, type_name: String, color: Color) -> void:
	var button = Button.new()
	button.text = type_name
	button.custom_minimum_size = Vector2(0, 50)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = color
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", btn_style)

	button.pressed.connect(_on_resource_type_button_pressed.bind(resource_type))
	container.add_child(button)


## Handle resource type button press
func _on_resource_type_button_pressed(resource_type: int) -> void:
	# Emit signal with selection
	resource_type_selected.emit(tile_q, tile_r, resource_type)

	# Close the picker
	_close_picker()


## Handle cancel button press
func _on_cancel_pressed() -> void:
	# Emit cancel signal
	picker_cancelled.emit()

	# Close the picker
	_close_picker()


## Close and cleanup the picker overlay
func _close_picker() -> void:
	if overlay:
		overlay.visible = false
		overlay.queue_free()
		overlay = null

	# Disable input handling on root when no overlay
	mouse_filter = Control.MOUSE_FILTER_IGNORE
