extends PanelContainer
class_name GodPanel

## God panel component - displays god portrait and divine powers
## Extracted from tile_selector_ui.gd for better code organization

# Layout constants
const PANEL_SIZE: Vector2 = Vector2(350, 140)
const PANEL_MARGIN: int = 10
const PANEL_BORDER_WIDTH: int = 2
const PANEL_CORNER_RADIUS: int = 10
const PORTRAIT_SIZE: Vector2 = Vector2(105, 105)
const POWER_BUTTON_SIZE: Vector2 = Vector2(220, 40)
const POWER_BUTTON_CORNER_RADIUS: int = 6
const FERVOR_ICON_SIZE: Vector2 = Vector2(14, 14)

signal power_activated(power: GodPower)

var god_portrait: TextureRect = null
var god_name_label: Label = null
var passive_label: Label = null
var minor_button: Button = null
var major_button: Button = null
var displayed_god: God = null
var board_manager_ref = null  # Reference to board manager for signals


func _ready() -> void:
	_create_panel()


## Creates the god panel UI
func _create_panel() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.corner_radius_top_left = PANEL_CORNER_RADIUS
	style.corner_radius_top_right = PANEL_CORNER_RADIUS
	style.corner_radius_bottom_left = PANEL_CORNER_RADIUS
	style.corner_radius_bottom_right = PANEL_CORNER_RADIUS
	style.border_width_left = PANEL_BORDER_WIDTH
	style.border_width_top = PANEL_BORDER_WIDTH
	style.border_width_right = PANEL_BORDER_WIDTH
	style.border_width_bottom = PANEL_BORDER_WIDTH
	style.border_color = Color(0.6, 0.5, 0.3)  # Gold border
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS  # Allow camera input while buttons still work

	# Inner margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", PANEL_MARGIN)
	margin.add_theme_constant_override("margin_right", PANEL_MARGIN)
	margin.add_theme_constant_override("margin_top", PANEL_MARGIN)
	margin.add_theme_constant_override("margin_bottom", PANEL_MARGIN)
	add_child(margin)

	# Horizontal layout: portrait+name on left, powers on right
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER  # Center vertically
	margin.add_child(hbox)

	# Left side: portrait with name on top
	var left_vbox = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 5)
	left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER  # Center content
	hbox.add_child(left_vbox)

	# God name (above portrait)
	god_name_label = Label.new()
	god_name_label.text = "No God"
	god_name_label.add_theme_font_size_override("font_size", 13)
	god_name_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	god_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	god_name_label.add_theme_constant_override("outline_size", 2)
	god_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(god_name_label)

	# God portrait
	god_portrait = TextureRect.new()
	god_portrait.custom_minimum_size = PORTRAIT_SIZE
	god_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	god_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left_vbox.add_child(god_portrait)

	# Right side: Power buttons container
	var powers_container = VBoxContainer.new()
	powers_container.name = "PowersContainer"
	powers_container.add_theme_constant_override("separation", 5)
	powers_container.alignment = BoxContainer.ALIGNMENT_CENTER  # Center power buttons
	powers_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(powers_container)


## Update god display when player selects a god
func update_god_display(god: God, board_manager) -> void:
	if not god:
		return

	# Store reference
	board_manager_ref = board_manager

	# Update portrait
	if god_portrait and ResourceLoader.exists(god.image_path):
		god_portrait.texture = load(god.image_path)

	# Update name
	if god_name_label:
		god_name_label.text = god.god_name

	# Find powers container
	var powers_container = null
	var left_vbox = god_name_label.get_parent()  # left_vbox
	var hbox = left_vbox.get_parent()  # hbox
	if hbox:
		for child in hbox.get_children():
			if child.name == "PowersContainer":
				powers_container = child
				break

	if not powers_container:
		Log.error("PowersContainer not found in god panel")
		return

	# Rebuild: one passive line plus exactly two power buttons — the god's
	# slots are fixed, so there's nothing to discover here.
	displayed_god = god
	for child in powers_container.get_children():
		child.queue_free()

	passive_label = _create_passive_label(god)
	powers_container.add_child(passive_label)

	minor_button = _create_power_button(god.minor)
	powers_container.add_child(minor_button)

	major_button = _create_power_button(god.major)
	powers_container.add_child(major_button)

	# Connect to active_player_view signals for dynamic updates (connect once — never rewire)
	if board_manager and board_manager.active_player_view:
		var apv = board_manager.active_player_view
		if not apv.fervor_changed.is_connected(update_power_buttons):
			apv.fervor_changed.connect(update_power_buttons.bind())
		if not apv.actions_changed.is_connected(update_power_buttons):
			apv.actions_changed.connect(update_power_buttons.bind())

	# Initial update
	update_power_buttons()

	Log.debug("God display updated: %s" % god.god_name)


## The passive is display-only here — its behaviour lives in God's hooks.
func _create_passive_label(god: God) -> Label:
	var label = Label.new()
	label.text = ("%s (passif)" % god.passive_name) if god.passive_name != "" else "—"
	label.tooltip_text = god.passive_description
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Create a power button with icon and styling. A null power means the god has
## no power in that slot yet — render an inert placeholder so the panel keeps
## its shape.
func _create_power_button(power: GodPower) -> Button:
	var button = Button.new()
	button.custom_minimum_size = POWER_BUTTON_SIZE
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	var style = StyleBoxFlat.new()
	if power == null:
		style.bg_color = Color(0.3, 0.3, 0.3, 0.8)
		button.disabled = true
	else:
		style.bg_color = Color(0.3, 0.2, 0.5, 0.9)
		button.pressed.connect(_on_power_button_pressed.bind(power))

	style.corner_radius_top_left = POWER_BUTTON_CORNER_RADIUS
	style.corner_radius_top_right = POWER_BUTTON_CORNER_RADIUS
	style.corner_radius_bottom_left = POWER_BUTTON_CORNER_RADIUS
	style.corner_radius_bottom_right = POWER_BUTTON_CORNER_RADIUS
	button.add_theme_stylebox_override("normal", style)

	# Create content container (vbox for name + cost row)
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through to button
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	button.add_child(vbox)

	# Add some margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(margin)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 4)
	content_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content_vbox)

	# Power name
	var name_label = Label.new()
	name_label.text = power.power_name if power else "—"
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_vbox.add_child(name_label)

	# Cost row (icon + number)
	if power and power.fervor_cost > 0:
		var cost_hbox = HBoxContainer.new()
		cost_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		cost_hbox.add_theme_constant_override("separation", 4)
		cost_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_vbox.add_child(cost_hbox)

		# Fervor icon
		var icon = TextureRect.new()
		icon.custom_minimum_size = FERVOR_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var texture = load(TileManager.RESOURCE_TYPE_ICONS[TileDefinition.ResourceType.FERVOR]) as Texture2D
		if texture:
			icon.texture = texture
		cost_hbox.add_child(icon)

		# Cost number
		var cost_label = Label.new()
		cost_label.text = str(power.fervor_cost)
		cost_label.add_theme_font_size_override("font_size", 11)
		cost_label.add_theme_color_override("font_color", Color.WHITE)
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_hbox.add_child(cost_label)

	return button


## Update power button states based on current player resources/usage
func update_power_buttons(_unused = null) -> void:
	if not board_manager_ref or not board_manager_ref.current_player or not displayed_god:
		return

	var is_my_turn: bool = board_manager_ref.ui_player == board_manager_ref.current_player
	var player = board_manager_ref.ui_player

	_apply_button_state(minor_button, displayed_god.minor, is_my_turn, player)
	_apply_button_state(major_button, displayed_god.major, is_my_turn, player)


func _apply_button_state(button: Button, power: GodPower, is_my_turn: bool, player) -> void:
	if button == null:
		return

	var can_activate: bool = power != null and is_my_turn and power.can_afford(player)

	var style = StyleBoxFlat.new()
	if can_activate:
		button.disabled = false
		style.bg_color = Color(0.4, 0.25, 0.6, 0.95)  # Brighter purple
	else:
		button.disabled = true
		style.bg_color = Color(0.2, 0.2, 0.2, 0.7)  # Dark gray
	style.corner_radius_top_left = POWER_BUTTON_CORNER_RADIUS
	style.corner_radius_top_right = POWER_BUTTON_CORNER_RADIUS
	style.corner_radius_bottom_left = POWER_BUTTON_CORNER_RADIUS
	style.corner_radius_bottom_right = POWER_BUTTON_CORNER_RADIUS
	button.add_theme_stylebox_override("normal", style)
	if not can_activate:
		button.add_theme_stylebox_override("disabled", style)


## Handle power button press
func _on_power_button_pressed(power: GodPower) -> void:
	Log.debug("Attempting to activate power: %s" % power.power_name)

	# Emit signal for parent to handle
	power_activated.emit(power)

	# Update button states immediately
	update_power_buttons()
