extends PanelContainer
class_name ResourcePanel

## Resource panel component - displays resources, fervor, and glory
## Extracted from tile_selector_ui.gd for better code organization

var resource_label: Label = null
var fervor_label: Label = null
var glory_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS  # Allow camera input to pass through
	_create_panel()


## Creates the resource panel UI
func _create_panel() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(120, 100)

	# Inner margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Resources row
	resource_label = _create_resource_row(vbox, "res://icons/wood.svg", "0")

	# Fervor row
	fervor_label = _create_resource_row(vbox, "res://icons/pray.svg", "0")

	# Glory row
	glory_label = _create_resource_row(vbox, "res://icons/star.svg", "0")


## Create a row with icon + label
func _create_resource_row(parent: VBoxContainer, icon_path: String, initial_value: String) -> Label:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	# Icon
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var texture = load(icon_path) as Texture2D
	if texture:
		icon.texture = texture
	hbox.add_child(icon)

	# Label
	var label = Label.new()
	label.text = initial_value
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	return label


## Update resource display
func update_resources(amount: int) -> void:
	if resource_label:
		resource_label.text = str(amount)


## Update fervor display
func update_fervor(amount: int) -> void:
	if fervor_label:
		fervor_label.text = str(amount)


## Update glory display
func update_glory(amount: int) -> void:
	if glory_label:
		glory_label.text = str(amount)
