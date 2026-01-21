extends HBoxContainer
class_name HarvestUI

## Harvest UI component - displays harvest phase buttons
## Extracted from tile_selector_ui.gd for better code organization

signal harvest_selected(resource_type: int)


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS  # Allow camera input while buttons still work


## Shows harvest option buttons based on available resource types
func show_harvest_options(available_types: Array[int]) -> void:
	# Clear existing buttons
	for child in get_children():
		child.queue_free()

	# Create button for each available type
	for res_type in available_types:
		var type_name = TileManager.ResourceType.keys()[res_type]
		var button = Button.new()
		button.text = "Harvest %s" % type_name
		button.custom_minimum_size = Vector2(130, 35)

		var button_color = _get_resource_color(res_type)
		button.add_theme_stylebox_override("normal", _create_button_style(button_color))
		button.add_theme_stylebox_override("hover", _create_button_style(button_color.lightened(0.2)))
		button.add_theme_stylebox_override("pressed", _create_button_style(button_color.darkened(0.2)))
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_font_size_override("font_size", 14)

		button.pressed.connect(_on_harvest_button_pressed.bind(res_type))
		add_child(button)

	visible = true


## Hide harvest buttons
func hide_harvest_options() -> void:
	visible = false


## Handle harvest button press
func _on_harvest_button_pressed(resource_type: int) -> void:
	harvest_selected.emit(resource_type)


## Get color for resource type
func _get_resource_color(res_type: int) -> Color:
	match res_type:
		TileManager.ResourceType.RESOURCES:
			return Color(0.6, 0.4, 0.2)  # Brown
		TileManager.ResourceType.FERVOR:
			return Color(0.8, 0.4, 0.1)  # Orange
		TileManager.ResourceType.GLORY:
			return Color(0.8, 0.7, 0.2)  # Gold
		_:
			return Color(0.5, 0.5, 0.5)  # Gray


## Create button style
func _create_button_style(bg_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
