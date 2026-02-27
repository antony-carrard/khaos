extends Control
class_name ResourceTypePicker

## Resource type picker modal for CHANGE_TILE_TYPE power
## Shows overlay with buttons to select resource type
## Extracted from tile_selector_ui.gd for better code organization

const PICKER_PANEL_SIZE: Vector2 = Vector2(400, 250)
const PICKER_PANEL_CORNER_RADIUS: int = 15
const PICKER_PANEL_BORDER_WIDTH: int = 4
const PICKER_PANEL_MARGIN: int = 30
const RESOURCE_BUTTON_HEIGHT: int = 50
const CANCEL_BUTTON_HEIGHT: int = 40
const PICKER_TITLE_FONT_SIZE: int = 22

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
## available_types: resource types that exist in the bag; others shown greyed out
func show_picker(q: int, r: int, current_type: int, tile_type: int, available_types: Array[int]) -> void:
	# If an overlay already exists, force close it first
	if overlay:
		_close_picker()

	# Store tile position
	tile_q = q
	tile_r = r

	# Enable input handling on root while overlay is shown
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Use a dedicated high-layer CanvasLayer so the picker renders above all other UI
	# (status header, hand display, etc.) regardless of node tree order.
	var picker_canvas := CanvasLayer.new()
	picker_canvas.layer = 5
	add_child(picker_canvas)

	# Create full-screen overlay
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)  # Semi-transparent black
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks from reaching 3D scene

	picker_canvas.add_child(overlay)

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
	style.border_width_left = PICKER_PANEL_BORDER_WIDTH
	style.border_width_right = PICKER_PANEL_BORDER_WIDTH
	style.border_width_top = PICKER_PANEL_BORDER_WIDTH
	style.border_width_bottom = PICKER_PANEL_BORDER_WIDTH
	style.corner_radius_top_left = PICKER_PANEL_CORNER_RADIUS
	style.corner_radius_top_right = PICKER_PANEL_CORNER_RADIUS
	style.corner_radius_bottom_left = PICKER_PANEL_CORNER_RADIUS
	style.corner_radius_bottom_right = PICKER_PANEL_CORNER_RADIUS
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = PICKER_PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	# Inner margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", PICKER_PANEL_MARGIN)
	margin.add_theme_constant_override("margin_right", PICKER_PANEL_MARGIN)
	margin.add_theme_constant_override("margin_top", PICKER_PANEL_MARGIN)
	margin.add_theme_constant_override("margin_bottom", PICKER_PANEL_MARGIN)
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
	title.add_theme_font_size_override("font_size", PICKER_TITLE_FONT_SIZE)
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
	_create_resource_type_button(button_container, TileManager.ResourceType.RESOURCES, "Resources", Color(0.6, 0.4, 0.2), available_types.has(TileManager.ResourceType.RESOURCES), current_type == TileManager.ResourceType.RESOURCES)
	_create_resource_type_button(button_container, TileManager.ResourceType.FERVOR, "Fervor", Color(0.4, 0.3, 0.6), available_types.has(TileManager.ResourceType.FERVOR), current_type == TileManager.ResourceType.FERVOR)

	# Glory only available on Hills and Mountains
	if tile_type != TileManager.TileType.PLAINS:
		_create_resource_type_button(button_container, TileManager.ResourceType.GLORY, "Glory", Color(0.7, 0.6, 0.2), available_types.has(TileManager.ResourceType.GLORY), current_type == TileManager.ResourceType.GLORY)

	# Cancel button
	var cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(0, CANCEL_BUTTON_HEIGHT)
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
## available: whether this type exists in the tile bag
## is_current: whether this is the tile's current resource type
## Both available=false and is_current=true produce a greyed-out disabled button
func _create_resource_type_button(container: VBoxContainer, resource_type: int, type_name: String, color: Color, available: bool, is_current: bool) -> void:
	var button = Button.new()
	if is_current:
		button.text = type_name + " (current)"
	elif not available:
		button.text = type_name + " (bag empty)"
	else:
		button.text = type_name
	button.custom_minimum_size = Vector2(0, RESOURCE_BUTTON_HEIGHT)
	button.disabled = is_current or not available

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = color if (available and not is_current) else Color(0.35, 0.35, 0.35)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", btn_style)

	if available and not is_current:
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
		overlay.get_parent().queue_free()  # frees CanvasLayer + its whole subtree
		overlay = null
	mouse_filter = Control.MOUSE_FILTER_IGNORE
