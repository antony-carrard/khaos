extends Control
class_name HarvestPicker

## Harvest type picker modal — shown at the start of each turn's harvest phase.
## Replaces the old HarvestUI inline buttons with a full-screen modal that
## naturally blocks all underlying UI input. No cancel: harvest is mandatory.

const PICKER_PANEL_SIZE: Vector2 = Vector2(380, 220)
const PICKER_PANEL_CORNER_RADIUS: int = 15
const PICKER_PANEL_BORDER_WIDTH: int = 4
const PICKER_PANEL_MARGIN: int = 30
const RESOURCE_BUTTON_HEIGHT: int = 50
const PICKER_TITLE_FONT_SIZE: int = 22

signal harvest_selected(resource_type: int)

var overlay: ColorRect = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_picker(available_types: Array[int]) -> void:
	if overlay:
		_close_picker()

	mouse_filter = Control.MOUSE_FILTER_PASS

	var picker_canvas := CanvasLayer.new()
	picker_canvas.layer = 5
	add_child(picker_canvas)

	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	picker_canvas.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.border_color = Color(0.7, 0.5, 0.15)  # Gold accent for harvest
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

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", PICKER_PANEL_MARGIN)
	margin.add_theme_constant_override("margin_right", PICKER_PANEL_MARGIN)
	margin.add_theme_constant_override("margin_top", PICKER_PANEL_MARGIN)
	margin.add_theme_constant_override("margin_bottom", PICKER_PANEL_MARGIN)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Choose Harvest Type"
	title.add_theme_font_size_override("font_size", PICKER_TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var button_container := VBoxContainer.new()
	button_container.add_theme_constant_override("separation", 12)
	button_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(button_container)

	for res_type in available_types:
		_create_harvest_button(button_container, res_type)


func _create_harvest_button(container: VBoxContainer, resource_type: int) -> void:
	var type_name: String = TileManager.ResourceType.keys()[resource_type]
	var color := _get_resource_color(resource_type)

	var button := Button.new()
	button.text = "Harvest %s" % type_name
	button.custom_minimum_size = Vector2(0, RESOURCE_BUTTON_HEIGHT)
	button.add_theme_stylebox_override("normal", _create_style(color))
	button.add_theme_stylebox_override("hover", _create_style(color.lightened(0.2)))
	button.add_theme_stylebox_override("pressed", _create_style(color.darkened(0.2)))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(_on_harvest_button_pressed.bind(resource_type))
	container.add_child(button)


func _on_harvest_button_pressed(resource_type: int) -> void:
	_close_picker()
	harvest_selected.emit(resource_type)


func _close_picker() -> void:
	if overlay:
		overlay.get_parent().queue_free()  # frees CanvasLayer + its whole subtree
		overlay = null
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _get_resource_color(res_type: int) -> Color:
	match res_type:
		TileManager.ResourceType.RESOURCES:
			return Color(0.6, 0.4, 0.2)
		TileManager.ResourceType.FERVOR:
			return Color(0.8, 0.4, 0.1)
		TileManager.ResourceType.GLORY:
			return Color(0.8, 0.7, 0.2)
		_:
			return Color(0.5, 0.5, 0.5)


func _create_style(bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
