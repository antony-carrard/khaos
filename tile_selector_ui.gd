extends Control

# Signals
signal tile_type_selected(tile_type: int)
signal tile_selected_from_hand(hand_index: int)
signal village_place_selected()
signal village_remove_selected()

var tile_type_colors: Dictionary = {}
var buttons: Array[Button] = []
var hand_container: HBoxContainer = null
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

# UI mode: "test" or "game"
var ui_mode: String = "game"  # Default to game UI
var debug_buttons_container: HBoxContainer = null


func _ready() -> void:
	# Full screen overlay that doesn't block mouse input to 3D scene
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func initialize(colors: Dictionary, _board_manager = null, mode: String = "game") -> void:
	tile_type_colors = colors
	board_manager = _board_manager
	ui_mode = mode

	# Container anchored to bottom of screen
	var margin = MarginContainer.new()
	margin.anchor_left = 0.0
	margin.anchor_right = 1.0
	margin.anchor_top = 1.0
	margin.anchor_bottom = 1.0
	margin.offset_top = -140  # Taller for tile cards
	margin.offset_bottom = -20
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	# Main horizontal container
	var main_hbox = HBoxContainer.new()
	main_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_theme_constant_override("separation", 20)
	margin.add_child(main_hbox)

	if ui_mode == "game":
		# GAME UI - Resource display on left
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
		tile_count_label.add_theme_font_size_override("font_size", 14)
		tile_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hand_vbox.add_child(tile_count_label)

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

		create_button(village_hbox, "Place Village", Color(0.8, 0.5, 0.2), 130, _on_village_place_pressed)
		create_button(village_hbox, "Remove Village", Color(0.7, 0.3, 0.2), 130, _on_village_remove_pressed)

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

	elif ui_mode == "test":
		# TEST UI - Debug tile placement buttons
		debug_buttons_container = HBoxContainer.new()
		debug_buttons_container.add_theme_constant_override("separation", 15)
		main_hbox.add_child(debug_buttons_container)

		create_button(debug_buttons_container, "Plains", tile_type_colors[0], 120, _on_tile_button_pressed.bind(0))
		create_button(debug_buttons_container, "Hills", tile_type_colors[1], 120, _on_tile_button_pressed.bind(1))
		create_button(debug_buttons_container, "Mountain", tile_type_colors[2], 120, _on_tile_button_pressed.bind(2))

		# Separator
		var separator = Control.new()
		separator.custom_minimum_size = Vector2(30, 0)
		debug_buttons_container.add_child(separator)

		create_button(debug_buttons_container, "Place Village", Color(0.8, 0.5, 0.2), 140, _on_village_place_pressed)
		create_button(debug_buttons_container, "Remove Village", Color(0.7, 0.3, 0.2), 140, _on_village_remove_pressed)


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


## Update the hand display with current tiles
func update_hand_display() -> void:
	if not hand_container or not board_manager:
		return

	# Clear existing hand cards
	for child in hand_container.get_children():
		child.queue_free()

	# Get current hand from board manager
	var hand = board_manager.get_hand()

	# Create a card for each tile in hand
	for i in range(hand.size()):
		var tile_def = hand[i]
		create_hand_card(i, tile_def)

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


## Create a visual card for a tile in the hand
func create_hand_card(hand_index: int, tile_def) -> void:
	# Check if player can afford this tile
	var can_afford = true
	if board_manager and board_manager.current_player:
		can_afford = board_manager.current_player.can_afford_tile(tile_def)

	# Card container
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	var tile_color = tile_type_colors[tile_def.tile_type]

	# Gray out if can't afford
	if can_afford:
		card_style.bg_color = tile_color.darkened(0.3)
		card_style.border_color = tile_color.lightened(0.3)
	else:
		card_style.bg_color = tile_color.darkened(0.6)  # Much darker
		card_style.border_color = Color.RED  # Red border for unaffordable

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
	hand_container.add_child(card)

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

	vbox.add_child(icon_texture_rect)

	# Yield value
	var yield_label = Label.new()
	yield_label.text = "Yield: %d" % tile_def.yield_value
	yield_label.add_theme_color_override("font_color", Color.WHITE)
	yield_label.add_theme_font_size_override("font_size", 11)
	yield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(yield_label)

	# Buy price
	var buy_label = Label.new()
	buy_label.text = "Cost: %d" % tile_def.buy_price
	# Red if can't afford, yellow if can
	if can_afford:
		buy_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		buy_label.add_theme_color_override("font_color", Color.RED)
	buy_label.add_theme_font_size_override("font_size", 10)
	buy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(buy_label)

	# Make card clickable (invisible button overlay)
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(_on_hand_card_pressed.bind(hand_index))
	card.add_child(button)


func _on_hand_card_pressed(hand_index: int) -> void:
	tile_selected_from_hand.emit(hand_index)


func _on_end_turn_pressed() -> void:
	if board_manager:
		board_manager.end_turn()


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
		board_manager.harvest(resource_type)


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
	if phase == 0:  # HARVEST phase
		if harvest_buttons_container:
			harvest_buttons_container.visible = true
		if actions_label:
			actions_label.visible = false
	else:  # ACTIONS phase
		if harvest_buttons_container:
			harvest_buttons_container.visible = false
		if actions_label:
			actions_label.visible = true


## Updates the actions display
func update_actions(remaining: int) -> void:
	if actions_label:
		actions_label.text = "Actions: %d/3" % remaining

		# Color feedback
		if remaining == 0:
			actions_label.add_theme_color_override("font_color", Color.RED)
		elif remaining == 1:
			actions_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			actions_label.add_theme_color_override("font_color", Color.WHITE)

	# Update hand cards affordability (they might be grayed if no actions)
	update_hand_display()
