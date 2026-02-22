extends Control
class_name HandDisplay

## Hand display component - displays player hand cards during gameplay
## Setup tiles are handled by the dedicated SetupPhaseUI overlay

signal tile_selected_from_hand(hand_index: int)
signal tile_sold_from_hand(hand_index: int)

const HAND_SIZE: int = 3  # Number of tiles in hand
const CARD_SIZE: Vector2 = Vector2(100, 110)
const CARD_MARGIN: int = 8
const CARD_CORNER_RADIUS: int = 8
const SELL_BUTTON_SIZE: Vector2 = Vector2(100, 25)

var tile_type_colors: Dictionary = {}
var hand_container: HBoxContainer = null
var tile_count_label: Label = null
var board_manager_ref = null  # Reference to board manager for hand data


func _ready() -> void:
	# Don't block mouse input to 3D scene
	mouse_filter = Control.MOUSE_FILTER_PASS


## Initialize with colors and board manager reference
func initialize(colors: Dictionary, board_manager) -> void:
	tile_type_colors = colors
	board_manager_ref = board_manager


## Set hand container reference (created by parent)
func set_hand_container(container: HBoxContainer) -> void:
	hand_container = container


## Set tile count label reference (created by parent)
func set_tile_count_label(label: Label) -> void:
	tile_count_label = label


## Update the hand display with current tiles
func update_hand_display() -> void:
	if not hand_container or not board_manager_ref:
		return

	# Clear existing hand cards
	for child in hand_container.get_children():
		child.queue_free()

	# Get current hand from board manager
	var hand = board_manager_ref.current_player.hand

	# Always show HAND_SIZE slots (with placeholders for empty slots)
	for i in range(HAND_SIZE):
		if i < hand.size() and hand[i] != null:
			var tile_def = hand[i]
			_create_hand_card(i, tile_def)
		else:
			_create_empty_card_placeholder()

	# Update tile count label
	if tile_count_label and board_manager_ref.tile_pool:
		var remaining = board_manager_ref.tile_pool.get_remaining_count()
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
func _create_empty_card_placeholder() -> void:
	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 5)
	hand_container.add_child(card_vbox)

	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.2, 0.2, 0.2, 0.3)
	card_style.border_color = Color(0.3, 0.3, 0.3, 0.5)
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = CARD_CORNER_RADIUS
	card_style.corner_radius_top_right = CARD_CORNER_RADIUS
	card_style.corner_radius_bottom_left = CARD_CORNER_RADIUS
	card_style.corner_radius_bottom_right = CARD_CORNER_RADIUS
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = CARD_SIZE
	card_vbox.add_child(card)

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
	sell_button.focus_mode = Control.FOCUS_NONE
	sell_button.custom_minimum_size = SELL_BUTTON_SIZE
	var disabled_style = _create_button_style(Color(0.25, 0.25, 0.25, 0.4))
	sell_button.add_theme_stylebox_override("normal", disabled_style)
	sell_button.add_theme_stylebox_override("disabled", disabled_style)
	sell_button.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	sell_button.add_theme_font_size_override("font_size", 10)
	card_vbox.add_child(sell_button)


## Create a visual card for a tile in the hand
func _create_hand_card(hand_index: int, tile_def) -> void:
	# Check action availability
	var can_place = false
	var has_actions = false
	if board_manager_ref and board_manager_ref.current_player:
		var in_actions_phase = board_manager_ref.turn_manager.is_actions_phase()
		if in_actions_phase:
			can_place = board_manager_ref.current_player.actions_remaining > 0
			has_actions = board_manager_ref.current_player.actions_remaining > 0

	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 5)
	hand_container.add_child(card_vbox)

	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	var tile_color = tile_type_colors[tile_def.tile_type]

	# Visual feedback based on actions
	if not can_place:
		card_style.bg_color = tile_color.darkened(0.5)
		card_style.border_color = tile_color.darkened(0.2)
	else:
		card_style.bg_color = tile_color.darkened(0.3)
		card_style.border_color = tile_color.lightened(0.3)

	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = CARD_CORNER_RADIUS
	card_style.corner_radius_top_right = CARD_CORNER_RADIUS
	card_style.corner_radius_bottom_left = CARD_CORNER_RADIUS
	card_style.corner_radius_bottom_right = CARD_CORNER_RADIUS
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = CARD_SIZE
	card_vbox.add_child(card)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CARD_MARGIN)
	margin.add_theme_constant_override("margin_right", CARD_MARGIN)
	margin.add_theme_constant_override("margin_top", CARD_MARGIN)
	margin.add_theme_constant_override("margin_bottom", CARD_MARGIN)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	# Tile type label
	var type_label = Label.new()
	type_label.text = TileManager.TileType.keys()[tile_def.tile_type]
	if can_place:
		type_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		type_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
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

	if not can_place:
		icon_texture_rect.modulate = Color(0.4, 0.4, 0.4)

	vbox.add_child(icon_texture_rect)

	# Yield value
	var yield_label = Label.new()
	yield_label.text = "Yield: %d" % tile_def.yield_value
	if can_place:
		yield_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		yield_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	yield_label.add_theme_font_size_override("font_size", 11)
	yield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(yield_label)

	# Make card clickable
	var button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not can_place
	button.pressed.connect(_on_hand_card_pressed.bind(hand_index))
	card.add_child(button)

	# Sell button
	var sell_button = Button.new()
	sell_button.custom_minimum_size = SELL_BUTTON_SIZE

	if tile_def.sell_price > 0:
		sell_button.text = "Sell (%d)" % tile_def.sell_price
		var sell_style = _create_button_style(Color(0.3, 0.6, 0.3))
		var sell_disabled_style = _create_button_style(Color(0.2, 0.4, 0.2))
		sell_button.add_theme_stylebox_override("normal", sell_style)
		sell_button.add_theme_stylebox_override("hover", _create_button_style(Color(0.4, 0.7, 0.4)))
		sell_button.add_theme_stylebox_override("pressed", _create_button_style(Color(0.2, 0.5, 0.2)))
		sell_button.add_theme_stylebox_override("disabled", sell_disabled_style)
		sell_button.add_theme_color_override("font_color", Color.WHITE)
		sell_button.disabled = not has_actions
		sell_button.pressed.connect(_on_sell_button_pressed.bind(hand_index))
	else:
		sell_button.text = "Sell (-)"
		sell_button.disabled = true
		sell_button.focus_mode = Control.FOCUS_NONE
		var disabled_style = _create_button_style(Color(0.3, 0.3, 0.3))
		sell_button.add_theme_stylebox_override("normal", disabled_style)
		sell_button.add_theme_stylebox_override("disabled", disabled_style)
		sell_button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

	sell_button.add_theme_font_size_override("font_size", 10)
	card_vbox.add_child(sell_button)


## Create button style
func _create_button_style(bg_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


## Handle hand card press
func _on_hand_card_pressed(hand_index: int) -> void:
	tile_selected_from_hand.emit(hand_index)


## Handle sell button press
func _on_sell_button_pressed(hand_index: int) -> void:
	tile_sold_from_hand.emit(hand_index)
