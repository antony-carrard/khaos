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
		# GAME UI - Hand display on left
		var hand_panel = PanelContainer.new()
		var hand_style = StyleBoxFlat.new()
		hand_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		hand_style.corner_radius_top_left = 10
		hand_style.corner_radius_top_right = 10
		hand_style.corner_radius_bottom_left = 10
		hand_style.corner_radius_bottom_right = 10
		hand_panel.add_theme_stylebox_override("panel", hand_style)
		main_hbox.add_child(hand_panel)

		hand_container = HBoxContainer.new()
		hand_container.add_theme_constant_override("separation", 10)
		hand_panel.add_child(hand_container)

		# Separator
		var separator = Control.new()
		separator.custom_minimum_size = Vector2(30, 0)
		main_hbox.add_child(separator)

		# Village buttons container (right side)
		var village_hbox = HBoxContainer.new()
		village_hbox.add_theme_constant_override("separation", 15)
		main_hbox.add_child(village_hbox)

		create_button(village_hbox, "Place Village", Color(0.8, 0.5, 0.2), 140, _on_village_place_pressed)
		create_button(village_hbox, "Remove Village", Color(0.7, 0.3, 0.2), 140, _on_village_remove_pressed)

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


## Create a visual card for a tile in the hand
func create_hand_card(hand_index: int, tile_def) -> void:
	# Card container
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	var tile_color = tile_type_colors[tile_def.tile_type]
	card_style.bg_color = tile_color.darkened(0.3)
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_color = tile_color.lightened(0.3)
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
	buy_label.add_theme_color_override("font_color", Color.YELLOW)
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
