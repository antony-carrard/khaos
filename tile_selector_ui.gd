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
	create_tile_button(hbox, 0, "Plains")
	create_tile_button(hbox, 1, "Hills")
	create_tile_button(hbox, 2, "Mountain")

	# Add separator
	var separator = Control.new()
	separator.custom_minimum_size = Vector2(30, 0)
	hbox.add_child(separator)

	# Create village buttons
	create_village_button(hbox, "Place Village", true)
	create_village_button(hbox, "Remove Village", false)


func create_tile_button(parent: Control, tile_type: int, label: String) -> void:
	var button = Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(120, 50)

	var base_color = tile_type_colors[tile_type]

	# Normal state
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = base_color
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_left = 8
	style_normal.corner_radius_bottom_right = 8

	# Hover state (lighter)
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = base_color.lightened(0.2)
	style_hover.corner_radius_top_left = 8
	style_hover.corner_radius_top_right = 8
	style_hover.corner_radius_bottom_left = 8
	style_hover.corner_radius_bottom_right = 8

	# Pressed state (darker)
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = base_color.darkened(0.2)
	style_pressed.corner_radius_top_left = 8
	style_pressed.corner_radius_top_right = 8
	style_pressed.corner_radius_bottom_left = 8
	style_pressed.corner_radius_bottom_right = 8

	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)

	# Text styling
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 18)

	button.pressed.connect(_on_tile_button_pressed.bind(tile_type))

	parent.add_child(button)
	buttons.append(button)


func _on_tile_button_pressed(tile_type: int) -> void:
	tile_type_selected.emit(tile_type)


func create_village_button(parent: Control, label: String, is_place: bool) -> void:
	var button = Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(140, 50)

	# Village buttons use orange/red colors
	var base_color = Color(0.8, 0.5, 0.2) if is_place else Color(0.7, 0.3, 0.2)

	# Normal state
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = base_color
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_left = 8
	style_normal.corner_radius_bottom_right = 8

	# Hover state (lighter)
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = base_color.lightened(0.2)
	style_hover.corner_radius_top_left = 8
	style_hover.corner_radius_top_right = 8
	style_hover.corner_radius_bottom_left = 8
	style_hover.corner_radius_bottom_right = 8

	# Pressed state (darker)
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = base_color.darkened(0.2)
	style_pressed.corner_radius_top_left = 8
	style_pressed.corner_radius_top_right = 8
	style_pressed.corner_radius_bottom_left = 8
	style_pressed.corner_radius_bottom_right = 8

	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)

	# Text styling
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 16)

	if is_place:
		button.pressed.connect(_on_village_place_pressed)
	else:
		button.pressed.connect(_on_village_remove_pressed)

	parent.add_child(button)
	buttons.append(button)


func _on_village_place_pressed() -> void:
	village_place_selected.emit()


func _on_village_remove_pressed() -> void:
	village_remove_selected.emit()
