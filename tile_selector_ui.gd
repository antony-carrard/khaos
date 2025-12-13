extends Control

# Signals
signal tile_type_selected(tile_type: int)
signal village_place_selected()
signal village_remove_selected()

var tile_type_colors: Dictionary = {}
var buttons: Array[Button] = []


func _ready() -> void:
	# Full screen overlay that doesn't block mouse input to 3D scene
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func initialize(colors: Dictionary) -> void:
	tile_type_colors = colors

	# Container anchored to bottom of screen
	var margin = MarginContainer.new()
	margin.anchor_left = 0.0
	margin.anchor_right = 1.0
	margin.anchor_top = 1.0
	margin.anchor_bottom = 1.0
	margin.offset_top = -90  # Height for buttons (50px) + margins (40px)
	margin.offset_bottom = -20  # Bottom spacing from screen edge
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	# Horizontal container to center buttons
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 15)
	margin.add_child(hbox)

	# Create tile selection buttons
	create_button(hbox, "Plains", tile_type_colors[0], 120, _on_tile_button_pressed.bind(0))
	create_button(hbox, "Hills", tile_type_colors[1], 120, _on_tile_button_pressed.bind(1))
	create_button(hbox, "Mountain", tile_type_colors[2], 120, _on_tile_button_pressed.bind(2))

	# Add separator
	var separator = Control.new()
	separator.custom_minimum_size = Vector2(30, 0)
	hbox.add_child(separator)

	# Create village buttons
	create_button(hbox, "Place Village", Color(0.8, 0.5, 0.2), 140, _on_village_place_pressed)
	create_button(hbox, "Remove Village", Color(0.7, 0.3, 0.2), 140, _on_village_remove_pressed)


func create_button(parent: Control, label: String, base_color: Color, width: int, callback: Callable) -> void:
	var button = Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(width, 50)

	# Create button styles with color variations
	var style_normal = create_button_style(base_color)
	var style_hover = create_button_style(base_color.lightened(0.2))
	var style_pressed = create_button_style(base_color.darkened(0.2))

	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)

	# Text styling
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 18 if width == 120 else 16)

	button.pressed.connect(callback)

	parent.add_child(button)
	buttons.append(button)


func create_button_style(bg_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _on_tile_button_pressed(tile_type: int) -> void:
	tile_type_selected.emit(tile_type)


func _on_village_place_pressed() -> void:
	village_place_selected.emit()


func _on_village_remove_pressed() -> void:
	village_remove_selected.emit()
