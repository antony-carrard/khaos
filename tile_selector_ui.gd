extends Control

# Constants
const HAND_SIZE: int = 3  # Number of tiles in hand

# Signals
signal tile_type_selected(tile_type: int)
signal tile_selected_from_hand(hand_index: int)
signal tile_sold_from_hand(hand_index: int)
signal setup_tile_selected(setup_index: int)
signal village_place_selected()
signal village_remove_selected()

var tile_type_colors: Dictionary = {}
var buttons: Array[Button] = []
var hand_container: HBoxContainer = null
var setup_tiles_container: HBoxContainer = null  # Container for setup phase tiles
var setup_title_label: Label = null  # "Setup Phase" title
var board_manager = null  # Reference to get hand data
var tile_count_label: Label = null  # Shows remaining tiles in bag

# Resource display
var resource_label: Label = null
var fervor_label: Label = null
var glory_label: Label = null

# Turn system UI
var harvest_buttons_container: HBoxContainer = null
var actions_label: Label = null
var end_turn_button: Button = null
var turn_phase_container: Control = null
var village_place_button: Button = null
var village_remove_button: Button = null

var debug_buttons_container: HBoxContainer = null

# Mouse-following tooltip for village sell value
var village_sell_tooltip: Label = null
var village_sell_tooltip_panel: PanelContainer = null


func _ready() -> void:
	# Full screen overlay that doesn't block mouse input to 3D scene
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func initialize(colors: Dictionary, _board_manager = null) -> void:
	tile_type_colors = colors
	board_manager = _board_manager

	# Container anchored to bottom of screen
	var margin = MarginContainer.new()
	margin.anchor_left = 0.0
	margin.anchor_right = 1.0
	margin.anchor_top = 1.0
	margin.anchor_bottom = 1.0
	margin.offset_top = -200  # Positions UI vertically (negative = up from bottom anchor)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 25)  # Gap from screen bottom (>20px to avoid camera pan zone)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	# Main horizontal container
	var main_hbox = HBoxContainer.new()
	main_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_theme_constant_override("separation", 20)
	margin.add_child(main_hbox)

	# Resource display on left
	var resource_panel = create_resource_panel()
	main_hbox.add_child(resource_panel)

	# Separator
	var sep1 = Control.new()
	sep1.custom_minimum_size = Vector2(15, 0)
	main_hbox.add_child(sep1)

	# Hand display in center
	var hand_vbox = VBoxContainer.new()
	hand_vbox.add_theme_constant_override("separation", 5)
	main_hbox.add_child(hand_vbox)

	# Tile count label (above hand)
	tile_count_label = Label.new()
	tile_count_label.text = "Tiles: 63"
	tile_count_label.add_theme_color_override("font_color", Color.WHITE)
	tile_count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	tile_count_label.add_theme_constant_override("outline_size", 4)
	tile_count_label.add_theme_font_size_override("font_size", 14)
	tile_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hand_vbox.add_child(tile_count_label)

	# Setup phase title (hidden by default)
	setup_title_label = Label.new()
	setup_title_label.text = "Setup Phase - Place Your Starting Tiles"
	setup_title_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))  # Gold
	setup_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	setup_title_label.add_theme_constant_override("outline_size", 4)
	setup_title_label.add_theme_font_size_override("font_size", 16)
	setup_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_title_label.visible = false
	hand_vbox.add_child(setup_title_label)

	# Setup tiles panel (hidden by default)
	var setup_panel = PanelContainer.new()
	var setup_style = StyleBoxFlat.new()
	setup_style.bg_color = Color(0.15, 0.12, 0.05, 0.9)  # Darker brown for special tiles
	setup_style.border_color = Color(0.9, 0.8, 0.3)  # Gold border
	setup_style.border_width_left = 3
	setup_style.border_width_right = 3
	setup_style.border_width_top = 3
	setup_style.border_width_bottom = 3
	setup_style.corner_radius_top_left = 10
	setup_style.corner_radius_top_right = 10
	setup_style.corner_radius_bottom_left = 10
	setup_style.corner_radius_bottom_right = 10
	setup_panel.add_theme_stylebox_override("panel", setup_style)
	setup_panel.visible = false
	hand_vbox.add_child(setup_panel)

	setup_tiles_container = HBoxContainer.new()
	setup_tiles_container.add_theme_constant_override("separation", 10)
	setup_tiles_container.alignment = BoxContainer.ALIGNMENT_CENTER  # Center the tiles
	setup_panel.add_child(setup_tiles_container)

	# Hand panel
	var hand_panel = PanelContainer.new()
	var hand_style = StyleBoxFlat.new()
	hand_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	hand_style.corner_radius_top_left = 10
	hand_style.corner_radius_top_right = 10
	hand_style.corner_radius_bottom_left = 10
	hand_style.corner_radius_bottom_right = 10
	hand_panel.add_theme_stylebox_override("panel", hand_style)
	hand_vbox.add_child(hand_panel)

	hand_container = HBoxContainer.new()
	hand_container.add_theme_constant_override("separation", 10)
	hand_panel.add_child(hand_container)

	# Separator
	var separator = Control.new()
	separator.custom_minimum_size = Vector2(30, 0)
	main_hbox.add_child(separator)

	# Turn phase and actions panel (right side)
	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	main_hbox.add_child(right_vbox)

	# Turn phase container (harvest buttons or actions display)
	turn_phase_container = VBoxContainer.new()
	turn_phase_container.add_theme_constant_override("separation", 8)
	right_vbox.add_child(turn_phase_container)

	# Actions display (shown during actions phase)
	actions_label = Label.new()
	actions_label.text = "Actions: 3/3"
	actions_label.add_theme_color_override("font_color", Color.WHITE)
	actions_label.add_theme_color_override("font_outline_color", Color.BLACK)
	actions_label.add_theme_constant_override("outline_size", 5)
	actions_label.add_theme_font_size_override("font_size", 16)
	actions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	actions_label.visible = false
	turn_phase_container.add_child(actions_label)

	# Harvest buttons container (shown during harvest phase)
	harvest_buttons_container = HBoxContainer.new()
	harvest_buttons_container.add_theme_constant_override("separation", 10)
	harvest_buttons_container.visible = false
	turn_phase_container.add_child(harvest_buttons_container)

	# Village buttons
	var village_hbox = HBoxContainer.new()
	village_hbox.add_theme_constant_override("separation", 10)
	right_vbox.add_child(village_hbox)

	village_place_button = create_button_ref(village_hbox, "Place Village", Color(0.8, 0.5, 0.2), 130, _on_village_place_pressed)
	village_remove_button = create_button_ref(village_hbox, "Remove Village", Color(0.7, 0.3, 0.2), 130, _on_village_remove_pressed)

	# End turn button
	end_turn_button = Button.new()
	end_turn_button.text = "End Turn"
	end_turn_button.custom_minimum_size = Vector2(270, 40)
	var end_turn_style = create_button_style(Color(0.2, 0.6, 0.8))
	end_turn_button.add_theme_stylebox_override("normal", end_turn_style)
	end_turn_button.add_theme_stylebox_override("hover", create_button_style(Color(0.3, 0.7, 0.9)))
	end_turn_button.add_theme_stylebox_override("pressed", create_button_style(Color(0.15, 0.5, 0.7)))
	end_turn_button.add_theme_color_override("font_color", Color.WHITE)
	end_turn_button.add_theme_font_size_override("font_size", 18)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	right_vbox.add_child(end_turn_button)

	# Create mouse-following village sell tooltip (works in both modes)
	create_village_sell_tooltip()


func create_village_sell_tooltip() -> void:
	# Create a panel container for nice styling
	village_sell_tooltip_panel = PanelContainer.new()
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
	village_sell_tooltip_panel.add_theme_stylebox_override("panel", style)
	village_sell_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block mouse
	village_sell_tooltip_panel.visible = false
	add_child(village_sell_tooltip_panel)

	# Inner margin for padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	village_sell_tooltip_panel.add_child(margin)

	# Label for the sell value
	village_sell_tooltip = Label.new()
	village_sell_tooltip.text = "+2 Resources"
	village_sell_tooltip.add_theme_color_override("font_color", Color(0.8, 0.9, 0.3))  # Yellow-green
	village_sell_tooltip.add_theme_font_size_override("font_size", 16)
	margin.add_child(village_sell_tooltip)


func _process(_delta: float) -> void:
	# Update tooltip position to follow mouse
	if village_sell_tooltip_panel and village_sell_tooltip_panel.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		# Offset the tooltip slightly down and to the right of cursor
		village_sell_tooltip_panel.position = mouse_pos + Vector2(20, 20)


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


## Create a button and return reference (for buttons we need to enable/disable later)
func create_button_ref(parent: Control, label: String, base_color: Color, width: int, callback: Callable) -> Button:
	var button = Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(width, 50)

	# Create button styles with color variations
	var style_normal = create_button_style(base_color)
	var style_hover = create_button_style(base_color.lightened(0.2))
	var style_pressed = create_button_style(base_color.darkened(0.2))
	var style_disabled = create_button_style(base_color.darkened(0.5))

	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_stylebox_override("disabled", style_disabled)

	# Text styling
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 18 if width == 120 else 16)

	button.pressed.connect(callback)

	parent.add_child(button)
	buttons.append(button)

	return button


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


## Create resource display panel with icons
func create_resource_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(120, 100)

	# Inner margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Resources row
	resource_label = create_resource_row(vbox, "res://icons/wood.svg", "0")

	# Fervor row
	fervor_label = create_resource_row(vbox, "res://icons/pray.svg", "0")

	# Glory row
	glory_label = create_resource_row(vbox, "res://icons/star.svg", "0")

	return panel


## Create a row with icon + label
func create_resource_row(parent: VBoxContainer, icon_path: String, initial_value: String) -> Label:
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


## Update resource display (called via signal)
func update_resources(amount: int) -> void:
	if resource_label:
		resource_label.text = str(amount)


## Update fervor display (called via signal)
func update_fervor(amount: int) -> void:
	if fervor_label:
		fervor_label.text = str(amount)


## Update glory display (called via signal)
func update_glory(amount: int) -> void:
	if glory_label:
		glory_label.text = str(amount)


func _on_village_place_pressed() -> void:
	village_place_selected.emit()


func _on_village_remove_pressed() -> void:
	village_remove_selected.emit()


## Shows the setup phase UI with setup tiles
## Hides normal hand display and shows setup tiles instead
func show_setup_phase(setup_tiles: Array) -> void:
	# Hide normal hand display
	if hand_container:
		hand_container.get_parent().visible = false

	# Show setup title and container
	if setup_title_label:
		setup_title_label.visible = true
	if setup_tiles_container:
		setup_tiles_container.get_parent().visible = true
		update_setup_tiles_display(setup_tiles)

	# Hide harvest/actions UI
	if harvest_buttons_container:
		harvest_buttons_container.visible = false
	if actions_label:
		actions_label.visible = false

	print("Setup phase UI displayed")


## Updates the setup tiles display
func update_setup_tiles_display(setup_tiles: Array) -> void:
	if not setup_tiles_container:
		return

	# Clear existing
	for child in setup_tiles_container.get_children():
		child.queue_free()

	# Create cards for each setup tile (or placeholder if already placed)
	for i in range(setup_tiles.size()):
		if setup_tiles[i] != null:
			create_setup_tile_card(i, setup_tiles[i])
		else:
			create_placed_setup_tile_placeholder()


## Create a visual card for a setup tile (similar to hand card but with gold border)
func create_setup_tile_card(setup_index: int, tile_def) -> void:
	# Container for card (no sell button for setup tiles)
	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 5)
	setup_tiles_container.add_child(card_vbox)

	# Card container with gold border
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	var tile_color = tile_type_colors[tile_def.tile_type]

	card_style.bg_color = tile_color.darkened(0.3)
	card_style.border_color = Color(0.9, 0.8, 0.3)  # Gold border for special setup tiles
	card_style.border_width_left = 3
	card_style.border_width_right = 3
	card_style.border_width_top = 3
	card_style.border_width_bottom = 3
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = Vector2(100, 110)
	card_vbox.add_child(card)

	# Inner margin for padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	# Card content (vertical layout)
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	# Tile type label
	var type_label = Label.new()
	type_label.text = TileManager.TileType.keys()[tile_def.tile_type]
	type_label.add_theme_color_override("font_color", Color.WHITE)
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_label)

	# Resource type icon
	var icon_texture_rect = TextureRect.new()
	icon_texture_rect.custom_minimum_size = Vector2(32, 32)
	icon_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var icon_path = TileManager.RESOURCE_TYPE_ICONS[tile_def.resource_type]
	var icon_texture = load(icon_path) as Texture2D
	if icon_texture:
		icon_texture_rect.texture = icon_texture

	vbox.add_child(icon_texture_rect)

	# "FREE" label (no resource cost during setup)
	var free_label = Label.new()
	free_label.text = "FREE"
	free_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))  # Bright green
	free_label.add_theme_font_size_override("font_size", 14)
	free_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(free_label)

	# Make card clickable
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(_on_setup_tile_pressed.bind(setup_index))
	card.add_child(button)


## Called when a setup tile card is clicked
func _on_setup_tile_pressed(setup_index: int) -> void:
	setup_tile_selected.emit(setup_index)


## Create a placeholder for a setup tile that has been placed
func create_placed_setup_tile_placeholder() -> void:
	# Same size as tile cards to prevent layout shift
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.15, 0.15, 0.15, 0.5)  # Dark and transparent
	card_style.border_color = Color(0.4, 0.4, 0.4, 0.6)
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = Vector2(100, 110)  # Same width as tile cards
	setup_tiles_container.add_child(card)

	# Margin for padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	# Center label "Placed"
	var label = Label.new()
	label.text = "✓\nPlaced"
	label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.3))  # Green
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(label)


## Update the hand display with current tiles
func update_hand_display() -> void:
	if not hand_container or not board_manager:
		return

	# Clear existing hand cards
	for child in hand_container.get_children():
		child.queue_free()

	# Get current hand from board manager
	var hand = board_manager.get_hand()

	# Always show HAND_SIZE slots (with placeholders for empty slots)
	for i in range(HAND_SIZE):
		if i < hand.size() and hand[i] != null:
			var tile_def = hand[i]
			create_hand_card(i, tile_def)
		else:
			create_empty_card_placeholder()

	# Update tile count label
	if tile_count_label and board_manager.tile_pool:
		var remaining = board_manager.tile_pool.get_remaining_count()
		tile_count_label.text = "Tiles: %d" % remaining
		if remaining == 0:
			tile_count_label.add_theme_color_override("font_color", Color.RED)
		elif remaining < 10:
			tile_count_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			tile_count_label.add_theme_color_override("font_color", Color.WHITE)
		# Maintain outline
		tile_count_label.add_theme_color_override("font_outline_color", Color.BLACK)
		tile_count_label.add_theme_constant_override("outline_size", 4)


## Create an empty placeholder for an empty hand slot
func create_empty_card_placeholder() -> void:
	# Container for placeholder
	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 5)
	hand_container.add_child(card_vbox)

	# Empty card placeholder
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.2, 0.2, 0.2, 0.3)  # Very dark and transparent
	card_style.border_color = Color(0.3, 0.3, 0.3, 0.5)
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = Vector2(100, 110)
	card_vbox.add_child(card)

	# Center label "Empty"
	var label = Label.new()
	label.text = "Empty"
	label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(label)

	# Disabled sell button (for visual consistency)
	var sell_button = Button.new()
	sell_button.text = "Sell (-)"
	sell_button.disabled = true
	sell_button.focus_mode = Control.FOCUS_NONE  # Prevent focus indicator on disabled button
	sell_button.custom_minimum_size = Vector2(100, 25)
	var disabled_style = create_button_style(Color(0.25, 0.25, 0.25, 0.4))
	sell_button.add_theme_stylebox_override("normal", disabled_style)
	sell_button.add_theme_stylebox_override("disabled", disabled_style)
	sell_button.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	sell_button.add_theme_font_size_override("font_size", 10)
	card_vbox.add_child(sell_button)


## Create a visual card for a tile in the hand
func create_hand_card(hand_index: int, tile_def) -> void:
	# Check action availability
	var can_place = false
	var has_actions = false
	if board_manager and board_manager.current_player:
		var in_actions_phase = board_manager.turn_manager.is_actions_phase()
		# Can only place/sell tiles during actions phase
		if in_actions_phase:
			can_place = board_manager.current_player.actions_remaining > 0
			has_actions = board_manager.current_player.actions_remaining > 0

	# Container for card + sell button
	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 5)
	hand_container.add_child(card_vbox)

	# Card container
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	var tile_color = tile_type_colors[tile_def.tile_type]

	# Visual feedback based on actions
	if not can_place:
		# No actions - darker
		card_style.bg_color = tile_color.darkened(0.5)
		card_style.border_color = tile_color.darkened(0.2)
	else:
		# Can place - normal colors
		card_style.bg_color = tile_color.darkened(0.3)
		card_style.border_color = tile_color.lightened(0.3)

	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = Vector2(100, 110)
	card_vbox.add_child(card)

	# Inner margin for padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	# Card content (vertical layout)
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	# Tile type label
	var type_label = Label.new()
	type_label.text = TileManager.TileType.keys()[tile_def.tile_type]
	# Dim text when disabled
	if can_place:
		type_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		type_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_label)

	# Resource type icon (using actual icon files)
	var icon_texture_rect = TextureRect.new()
	icon_texture_rect.custom_minimum_size = Vector2(32, 32)
	icon_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Load the appropriate icon
	var icon_path = TileManager.RESOURCE_TYPE_ICONS[tile_def.resource_type]
	var icon_texture = load(icon_path) as Texture2D
	if icon_texture:
		icon_texture_rect.texture = icon_texture

	# Desaturate and dim icon when disabled
	if not can_place:
		icon_texture_rect.modulate = Color(0.4, 0.4, 0.4)

	vbox.add_child(icon_texture_rect)

	# Yield value
	var yield_label = Label.new()
	yield_label.text = "Yield: %d" % tile_def.yield_value
	# Dim text when disabled
	if can_place:
		yield_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		yield_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	yield_label.add_theme_font_size_override("font_size", 11)
	yield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(yield_label)

	# Make card clickable (invisible button overlay)
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE  # Prevent focus indicator
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.disabled = not can_place  # Disable if no actions
	button.pressed.connect(_on_hand_card_pressed.bind(hand_index))
	card.add_child(button)

	# Sell button BELOW the card (always present for consistency)
	var sell_button = Button.new()
	sell_button.custom_minimum_size = Vector2(100, 25)

	if tile_def.sell_price > 0:
		# Sellable tile - green button
		sell_button.text = "Sell (%d)" % tile_def.sell_price
		var sell_style = create_button_style(Color(0.3, 0.6, 0.3))
		var sell_disabled_style = create_button_style(Color(0.2, 0.4, 0.2))
		sell_button.add_theme_stylebox_override("normal", sell_style)
		sell_button.add_theme_stylebox_override("hover", create_button_style(Color(0.4, 0.7, 0.4)))
		sell_button.add_theme_stylebox_override("pressed", create_button_style(Color(0.2, 0.5, 0.2)))
		sell_button.add_theme_stylebox_override("disabled", sell_disabled_style)
		sell_button.add_theme_color_override("font_color", Color.WHITE)
		sell_button.disabled = not has_actions  # Disable only if no actions (not if can't afford)
		sell_button.pressed.connect(_on_sell_button_pressed.bind(hand_index))
	else:
		# Glory tile - grayed out disabled button
		sell_button.text = "Sell (-)"
		sell_button.disabled = true
		sell_button.focus_mode = Control.FOCUS_NONE  # Prevent focus indicator on disabled button
		var disabled_style = create_button_style(Color(0.3, 0.3, 0.3))
		sell_button.add_theme_stylebox_override("normal", disabled_style)
		sell_button.add_theme_stylebox_override("disabled", disabled_style)
		sell_button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

	sell_button.add_theme_font_size_override("font_size", 10)
	card_vbox.add_child(sell_button)


func _on_hand_card_pressed(hand_index: int) -> void:
	tile_selected_from_hand.emit(hand_index)


func _on_sell_button_pressed(hand_index: int) -> void:
	tile_sold_from_hand.emit(hand_index)


func _on_end_turn_pressed() -> void:
	if board_manager:
		board_manager.turn_manager.end_turn()


## Shows harvest option buttons based on available types
func show_harvest_options(available_types: Array[int]) -> void:
	if not harvest_buttons_container:
		return

	# Clear existing buttons
	for child in harvest_buttons_container.get_children():
		child.queue_free()

	# Create button for each available type
	for res_type in available_types:
		var type_name = TileManager.ResourceType.keys()[res_type]
		var icon_path = TileManager.RESOURCE_TYPE_ICONS[res_type]

		var button = Button.new()
		button.text = "Harvest %s" % type_name
		button.custom_minimum_size = Vector2(130, 35)

		var button_color = _get_resource_color(res_type)
		button.add_theme_stylebox_override("normal", create_button_style(button_color))
		button.add_theme_stylebox_override("hover", create_button_style(button_color.lightened(0.2)))
		button.add_theme_stylebox_override("pressed", create_button_style(button_color.darkened(0.2)))
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_font_size_override("font_size", 14)

		button.pressed.connect(_on_harvest_button_pressed.bind(res_type))
		harvest_buttons_container.add_child(button)

	harvest_buttons_container.visible = true
	if actions_label:
		actions_label.visible = false


func _on_harvest_button_pressed(resource_type: int) -> void:
	if board_manager:
		board_manager.turn_manager.harvest(resource_type)


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


## Updates UI based on current turn phase
func update_turn_phase(phase: int) -> void:
	match phase:
		TurnManager.Phase.SETUP:
			# Setup phase: show setup tiles, hide normal game UI
			if board_manager and board_manager.current_player:
				show_setup_phase(board_manager.current_player.setup_tiles)
		TurnManager.Phase.HARVEST:
			# Show harvest buttons, hide actions label
			# Restore normal hand display (hide setup UI)
			if hand_container:
				hand_container.get_parent().visible = true
			if setup_title_label:
				setup_title_label.visible = false
			if setup_tiles_container:
				setup_tiles_container.get_parent().visible = false
			if harvest_buttons_container:
				harvest_buttons_container.visible = true
			if actions_label:
				actions_label.visible = false
			# Disable village buttons during harvest phase
			if village_place_button:
				village_place_button.disabled = true
			if village_remove_button:
				village_remove_button.disabled = true
			# Refresh hand display to disable tile cards and sell buttons
			update_hand_display()
		TurnManager.Phase.ACTIONS:
			# Show actions label, hide harvest buttons
			if harvest_buttons_container:
				harvest_buttons_container.visible = false
			if actions_label:
				actions_label.visible = true
			# Re-enable village buttons during actions phase (will be disabled if no actions)
			if village_place_button:
				village_place_button.disabled = false
			if village_remove_button:
				village_remove_button.disabled = false
			# Refresh hand display to re-enable tile cards and sell buttons
			update_hand_display()


## Updates the actions display
func update_actions(remaining: int) -> void:
	if actions_label:
		actions_label.text = "Actions: %d/3" % remaining

		# Color feedback with consistent outline
		if remaining == 0:
			actions_label.add_theme_color_override("font_color", Color.RED)
		elif remaining == 1:
			actions_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			actions_label.add_theme_color_override("font_color", Color.WHITE)
		# Maintain outline
		actions_label.add_theme_color_override("font_outline_color", Color.BLACK)
		actions_label.add_theme_constant_override("outline_size", 5)

	# Disable village buttons when no actions remaining
	if village_place_button:
		village_place_button.disabled = (remaining <= 0)
	if village_remove_button:
		village_remove_button.disabled = (remaining <= 0)

	# Update hand cards affordability (they might be grayed if no actions)
	update_hand_display()


## Shows or hides the village sell tooltip with the refund amount
func show_village_sell_tooltip(visible: bool, refund_amount: int = 0) -> void:
	if not village_sell_tooltip or not village_sell_tooltip_panel:
		return

	if visible and refund_amount > 0:
		village_sell_tooltip.text = "+%d Resources" % refund_amount
		village_sell_tooltip_panel.visible = true
	else:
		village_sell_tooltip_panel.visible = false


# ========== ENDGAME UI ==========


## Shows a notification that the final round has started.
## Notification fades out after 4 seconds.
func show_final_round_notification() -> void:
	var notif = Label.new()
	notif.text = "FINAL ROUND! Tile bag is empty."
	notif.add_theme_font_size_override("font_size", 24)
	notif.add_theme_color_override("font_color", Color.ORANGE)
	notif.add_theme_color_override("font_outline_color", Color.BLACK)
	notif.add_theme_constant_override("outline_size", 6)
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Position at top center
	notif.anchor_left = 0.0
	notif.anchor_right = 1.0
	notif.anchor_top = 0.0
	notif.anchor_bottom = 0.0
	notif.offset_top = 50
	notif.offset_bottom = 100

	add_child(notif)

	# Fade out after 4 seconds
	var tween = create_tween()
	tween.tween_property(notif, "modulate:a", 0.0, 1.0).set_delay(3.0)
	tween.tween_callback(notif.queue_free)


## Shows the victory screen with score breakdown.
## all_scores: Array of {player: Player, scores: Dictionary}
func show_victory_screen(all_scores: Array) -> void:
	# Hide game UI
	visible = false

	# Create victory screen overlay
	var victory_overlay = _create_victory_screen(all_scores)
	get_parent().add_child(victory_overlay)


## Creates the victory screen UI overlay.
func _create_victory_screen(all_scores: Array) -> Control:
	# Full-screen semi-transparent overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks to game

	# Center container
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	# Main panel
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.border_color = Color(0.8, 0.7, 0.3)  # Gold border
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(600, 500)
	center.add_child(panel)

	# Inner margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	# Vertical layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "GAME OVER"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Determine winner
	var winner_data = _determine_winner(all_scores)

	# Winner announcement
	var winner_label = Label.new()
	if winner_data.is_tie:
		winner_label.text = "TIE between %s!" % winner_data.tied_names
	else:
		winner_label.text = "Winner: %s" % winner_data.winner_name
	winner_label.add_theme_font_size_override("font_size", 24)
	winner_label.add_theme_color_override("font_color", Color.WHITE)
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(winner_label)

	# Score display
	var score_label = Label.new()
	score_label.text = "Final Score: %d points" % winner_data.winner_score
	score_label.add_theme_font_size_override("font_size", 20)
	score_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_label)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 20)
	vbox.add_child(sep)

	# Scrollable breakdown
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	vbox.add_child(scroll)

	var breakdown_vbox = VBoxContainer.new()
	breakdown_vbox.add_theme_constant_override("separation", 20)
	scroll.add_child(breakdown_vbox)

	# Create breakdown for each player
	for score_entry in all_scores:
		var player_breakdown = _create_player_breakdown(score_entry.player, score_entry.scores)
		breakdown_vbox.add_child(player_breakdown)

	# Buttons
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(button_hbox)

	# Return to menu button (disabled - no menu system yet)
	var menu_button = Button.new()
	menu_button.text = "Return to Menu"
	menu_button.disabled = true
	menu_button.custom_minimum_size = Vector2(180, 50)
	button_hbox.add_child(menu_button)

	# New game button
	var new_game_button = Button.new()
	new_game_button.text = "New Game"
	new_game_button.custom_minimum_size = Vector2(180, 50)
	var new_game_style = _create_button_style(Color(0.3, 0.7, 0.3))
	new_game_button.add_theme_stylebox_override("normal", new_game_style)
	new_game_button.add_theme_stylebox_override("hover", _create_button_style(Color(0.4, 0.8, 0.4)))
	new_game_button.add_theme_color_override("font_color", Color.WHITE)
	new_game_button.add_theme_font_size_override("font_size", 18)
	new_game_button.pressed.connect(_on_new_game)
	button_hbox.add_child(new_game_button)

	return overlay


## Creates score breakdown panel for a single player.
func _create_player_breakdown(player: Player, scores: Dictionary) -> Control:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 0.6)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Player name
	var name_label = Label.new()
	name_label.text = player.player_name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vbox.add_child(name_label)

	# Score breakdown
	var breakdown_text = """Villages (by terrain):
%s

Resources: %d → %d pts (%d pairs)
Fervor: %d → %d pts (%d pairs)
Glory: %d pts

Territory Bonus: %d pts
%s

TOTAL: %d points""" % [
		scores.village_breakdown,
		player.resources, scores.resource_points, player.resources / 2,
		player.fervor, scores.fervor_points, player.fervor / 2,
		scores.glory_points,
		scores.territory_points,
		scores.territory_breakdown,
		scores.total
	]

	var breakdown_label = Label.new()
	breakdown_label.text = breakdown_text
	breakdown_label.add_theme_font_size_override("font_size", 14)
	breakdown_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(breakdown_label)

	return panel


## Determines the winner from all player scores.
## Handles ties.
func _determine_winner(all_scores: Array) -> Dictionary:
	var max_score = -1
	var winners = []

	for entry in all_scores:
		var score = entry.scores.total
		if score > max_score:
			max_score = score
			winners = [entry.player]
		elif score == max_score:
			winners.append(entry.player)

	var is_tie = winners.size() > 1
	var winner_name = winners[0].player_name if not is_tie else ""
	var tied_names = ", ".join(winners.map(func(p): return p.player_name)) if is_tie else ""

	return {
		"is_tie": is_tie,
		"winner_name": winner_name,
		"tied_names": tied_names,
		"winner_score": max_score
	}


## Creates a styled button background.
func _create_button_style(bg_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


## Called when New Game button is pressed.
func _on_new_game() -> void:
	get_tree().reload_current_scene()
