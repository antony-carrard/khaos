extends PanelContainer
class_name GodPanel

## God panel component - displays god portrait and divine powers
## Extracted from tile_selector_ui.gd for better code organization

signal power_activated(power: GodPower, god_manager: GodManager)

var god_portrait: TextureRect = null
var god_name_label: Label = null
var god_power_buttons: Array[Button] = []
var god_power_mapping: Dictionary = {}  # Maps Button -> GodPower
var god_manager_ref: GodManager = null
var board_manager_ref = null  # Reference to board manager for signals


func _ready() -> void:
	_create_panel()


## Creates the god panel UI
func _create_panel() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.5, 0.3)  # Gold border
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(350, 120)
	mouse_filter = Control.MOUSE_FILTER_PASS  # Allow camera input while buttons still work

	# Inner margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
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
	god_portrait.custom_minimum_size = Vector2(80, 80)
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
func update_god_display(god: God, god_manager: GodManager, board_manager) -> void:
	if not god:
		return

	# Store references
	god_manager_ref = god_manager
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
		push_error("PowersContainer not found in god panel")
		return

	# Clear existing power buttons and mappings
	for button in god_power_buttons:
		button.queue_free()
	god_power_buttons.clear()
	god_power_mapping.clear()

	# Add power buttons for all powers (active and passive)
	for power in god.powers:
		var button = _create_power_button(power, god_manager)
		powers_container.add_child(button)
		god_power_buttons.append(button)
		god_power_mapping[button] = power

	# Connect to player signals for dynamic updates
	if board_manager and board_manager.current_player:
		var player = board_manager.current_player
		if not player.fervor_changed.is_connected(update_power_buttons):
			player.fervor_changed.connect(update_power_buttons.bind())
		if not player.power_used.is_connected(update_power_buttons):
			player.power_used.connect(update_power_buttons.bind())
		if not player.actions_changed.is_connected(update_power_buttons):
			player.actions_changed.connect(update_power_buttons.bind())

		# Also connect to phase changes
		if board_manager.turn_manager:
			if not board_manager.turn_manager.phase_changed.is_connected(update_power_buttons):
				board_manager.turn_manager.phase_changed.connect(update_power_buttons.bind())

	# Initial update
	update_power_buttons()

	print("God display updated: %s" % god.god_name)


## Create a power button with icon and styling
func _create_power_button(power: GodPower, god_manager: GodManager) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(220, 40)
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	# Style based on power type
	var style = StyleBoxFlat.new()
	if power.is_passive:
		# Passive - gray, disabled
		style.bg_color = Color(0.3, 0.3, 0.3, 0.8)
		button.disabled = true
	else:
		# Active - purple
		style.bg_color = Color(0.3, 0.2, 0.5, 0.9)
		button.pressed.connect(_on_power_button_pressed.bind(power, god_manager))

	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
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
	name_label.text = power.power_name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_vbox.add_child(name_label)

	# Cost row (icon + number) if not passive
	if power.fervor_cost > 0:
		var cost_hbox = HBoxContainer.new()
		cost_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		cost_hbox.add_theme_constant_override("separation", 4)
		cost_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_vbox.add_child(cost_hbox)

		# Fervor icon
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(14, 14)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var texture = load("res://icons/pray.svg") as Texture2D
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
	if not board_manager_ref or not board_manager_ref.current_player or not god_manager_ref:
		return

	var player = board_manager_ref.current_player
	var turn_manager = board_manager_ref.turn_manager

	for button in god_power_buttons:
		var power: GodPower = god_power_mapping.get(button)
		if not power or power.is_passive:
			continue

		# Check if power can be activated
		var can_activate = god_manager_ref.can_activate_power(power, player, turn_manager)

		# Update button state
		if can_activate:
			# Enabled - bright purple
			button.disabled = false
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.4, 0.25, 0.6, 0.95)  # Brighter purple
			style.corner_radius_top_left = 6
			style.corner_radius_top_right = 6
			style.corner_radius_bottom_left = 6
			style.corner_radius_bottom_right = 6
			button.add_theme_stylebox_override("normal", style)
		else:
			# Disabled - dark gray
			button.disabled = true
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.2, 0.2, 0.7)  # Dark gray
			style.corner_radius_top_left = 6
			style.corner_radius_top_right = 6
			style.corner_radius_bottom_left = 6
			style.corner_radius_bottom_right = 6
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_stylebox_override("disabled", style)


## Handle power button press
func _on_power_button_pressed(power: GodPower, god_manager: GodManager) -> void:
	print("Attempting to activate power: %s" % power.power_name)

	# Emit signal for parent to handle
	power_activated.emit(power, god_manager)

	# Update button states immediately
	update_power_buttons()
