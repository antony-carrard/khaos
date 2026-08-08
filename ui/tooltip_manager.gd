extends Control
class_name TooltipManager

## Tooltip manager component - displays mouse-following tooltips
## Currently handles village sell value tooltip
## Extracted from tile_selector_ui.gd for better code organization

const TOOLTIP_OFFSET: Vector2 = Vector2(20, 20)  # Offset from cursor so it doesn't obscure

var tooltip_panel: PanelContainer = null
var tooltip_label: Label = null
var tooltip_warning_label: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_create_tooltip()


func _process(_delta: float) -> void:
	# Update tooltip position to follow mouse
	if tooltip_panel and tooltip_panel.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		# Offset the tooltip slightly down and to the right of cursor
		tooltip_panel.position = mouse_pos + TOOLTIP_OFFSET


## Creates the tooltip panel
func _create_tooltip() -> void:
	# Create a panel container for nice styling
	tooltip_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)  # Almost opaque dark background
	style.border_color = Color(0.8, 0.6, 0.2)  # Gold border
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	tooltip_panel.add_theme_stylebox_override("panel", style)
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_PASS  # Don't block mouse
	tooltip_panel.visible = false
	add_child(tooltip_panel)

	# Inner margin for padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	tooltip_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	margin.add_child(vbox)

	# Label for the tooltip text
	tooltip_label = Label.new()
	tooltip_label.text = "+2 Resources"
	tooltip_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.3))  # Yellow-green
	tooltip_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(tooltip_label)

	# Extra warning line, shown only when demolishing costs more than 1 action
	# (attacking from a lower tile, or from a village built this same turn).
	tooltip_warning_label = Label.new()
	tooltip_warning_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))  # Red
	tooltip_warning_label.add_theme_font_size_override("font_size", 16)
	tooltip_warning_label.visible = false
	vbox.add_child(tooltip_warning_label)


## Shows or hides the resource-gain tooltip with the refund amount
func show_resource_gain_tooltip(visible_flag: bool, refund_amount: int = 0) -> void:
	if not tooltip_label or not tooltip_panel:
		return
	if visible_flag:
		tooltip_label.text = "Free" if refund_amount == 0 else "+%d Resources" % refund_amount
		tooltip_warning_label.visible = false
		tooltip_panel.visible = true
	else:
		tooltip_panel.visible = false


## Shows or hides the cost tooltip for destroying an enemy village. Adds a red
## warning line when the demolition costs more than 1 action (attacking from a
## lower tile, or from a village built this same turn — rules.md).
func show_village_cost_tooltip(visible_flag: bool, cost_amount: int = 0, action_cost: int = 1) -> void:
	if not tooltip_label or not tooltip_panel:
		return
	if visible_flag:
		tooltip_label.text = "-%d Materials" % cost_amount
		if action_cost > 1:
			tooltip_warning_label.text = "-%d Actions" % action_cost
			tooltip_warning_label.visible = true
		else:
			tooltip_warning_label.visible = false
		tooltip_panel.visible = true
	else:
		tooltip_panel.visible = false
