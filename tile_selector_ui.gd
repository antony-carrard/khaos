extends Control

# Preload UI components
const VictoryScreenScene = preload("res://ui/victory_screen.gd")
const ResourceTypePickerScene = preload("res://ui/resource_type_picker.gd")
const GodPanelScene = preload("res://ui/god_panel.gd")
const ResourcePanelScene = preload("res://ui/resource_panel.gd")
const HarvestUIScene = preload("res://ui/harvest_ui.gd")
const HandDisplayScene = preload("res://ui/hand_display.gd")
const TooltipManagerScene = preload("res://ui/tooltip_manager.gd")

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
var board_manager = null  # Reference to get hand data

# Turn system UI (still managed here)
var actions_label: Label = null
var end_turn_button: Button = null
var turn_phase_container: Control = null
var village_place_button: Button = null
var village_remove_button: Button = null

# UI Components
var victory_screen: VictoryScreen = null
var resource_type_picker: ResourceTypePicker = null
var god_panel: GodPanel = null
var resource_panel: ResourcePanel = null
var harvest_ui: HarvestUI = null
var hand_display: HandDisplay = null
var tooltip_manager: TooltipManager = null

# Container references (for hand display)
var hand_container: HBoxContainer = null
var setup_tiles_container: HBoxContainer = null
var setup_title_label: Label = null
var tile_count_label: Label = null


func _ready() -> void:
	# Full screen overlay that doesn't block mouse input to 3D scene
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Create UI components
	victory_screen = VictoryScreenScene.new()
	victory_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(victory_screen)

	tooltip_manager = TooltipManagerScene.new()
	add_child(tooltip_manager)

	hand_display = HandDisplayScene.new()
	add_child(hand_display)
	hand_display.tile_selected_from_hand.connect(_on_hand_card_pressed)
	hand_display.tile_sold_from_hand.connect(_on_sell_button_pressed)
	hand_display.setup_tile_selected.connect(_on_setup_tile_pressed)

	# Add resource_type_picker last so it appears on top when shown
	resource_type_picker = ResourceTypePickerScene.new()
	resource_type_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(resource_type_picker)
	resource_type_picker.resource_type_selected.connect(_on_resource_type_selected)
	resource_type_picker.picker_cancelled.connect(_on_resource_type_picker_cancelled)

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
	add_child(margin)

	# Main horizontal container
	var main_hbox = HBoxContainer.new()
	main_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_theme_constant_override("separation", 20)
	margin.add_child(main_hbox)

	# God display on far left
	god_panel = GodPanelScene.new()
	main_hbox.add_child(god_panel)

	# Separator
	var sep_god = Control.new()
	sep_god.custom_minimum_size = Vector2(15, 0)
	main_hbox.add_child(sep_god)

	# Resource display on left
	resource_panel = ResourcePanelScene.new()
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
	harvest_ui = HarvestUIScene.new()
	harvest_ui.harvest_selected.connect(_on_harvest_button_pressed)
	turn_phase_container.add_child(harvest_ui)

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
	
	hand_display.initialize(tile_type_colors, board_manager)
	hand_display.set_hand_container(hand_container)
	hand_display.set_setup_container(setup_tiles_container)
	hand_display.set_setup_title_label(setup_title_label)
	hand_display.set_tile_count_label(tile_count_label)


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


## Update resource display (called via signal)
func update_resources(amount: int) -> void:
	if resource_panel:
		resource_panel.update_resources(amount)


## Update fervor display (called via signal)
func update_fervor(amount: int) -> void:
	if resource_panel:
		resource_panel.update_fervor(amount)


## Update glory display (called via signal)
func update_glory(amount: int) -> void:
	if resource_panel:
		resource_panel.update_glory(amount)


func _on_village_place_pressed() -> void:
	village_place_selected.emit()


func _on_village_remove_pressed() -> void:
	village_remove_selected.emit()


## Shows the setup phase UI with setup tiles
## Hides normal hand display and shows setup tiles instead
func show_setup_phase(setup_tiles: Array) -> void:
	if hand_display:
		hand_display.show_setup_phase(setup_tiles)
	if harvest_ui:
		harvest_ui.hide_harvest_options()
	if actions_label:
		actions_label.visible = false


## Updates the setup tiles display
func update_setup_tiles_display(setup_tiles: Array) -> void:
	if hand_display:
		hand_display.update_setup_tiles_display(setup_tiles)


## Called when a setup tile card is clicked
func _on_setup_tile_pressed(setup_index: int) -> void:
	setup_tile_selected.emit(setup_index)


## Update the hand display with current tiles
func update_hand_display() -> void:
	if hand_display:
		hand_display.update_hand_display()


func show_harvest_options(available_types: Array[int]) -> void:
	if harvest_ui:
		harvest_ui.show_harvest_options(available_types)
	if actions_label:
		actions_label.visible = false


func _on_hand_card_pressed(hand_index: int) -> void:
	tile_selected_from_hand.emit(hand_index)


func _on_sell_button_pressed(hand_index: int) -> void:
	tile_sold_from_hand.emit(hand_index)


func _on_end_turn_pressed() -> void:
	if board_manager:
		board_manager.turn_manager.end_turn()


func _on_harvest_button_pressed(resource_type: int) -> void:
	if board_manager:
		board_manager.turn_manager.harvest(resource_type)


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
			if hand_display:
				hand_display.hide_setup_phase()
			if harvest_ui:
				harvest_ui.visible = true
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
			if harvest_ui:
				harvest_ui.visible = false
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
	if actions_label and board_manager and board_manager.current_player:
		var player = board_manager.current_player
		var max_actions = player.max_actions_this_turn
		actions_label.text = "Actions: %d/%d" % [remaining, max_actions]

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
func show_village_sell_tooltip(visible_flag: bool, refund_amount: int = 0) -> void:
	if tooltip_manager:
		tooltip_manager.show_village_sell_tooltip(visible_flag, refund_amount)


# ========== ENDGAME UI (Delegated to VictoryScreen) ==========


## Shows a notification that the final round has started.
## Delegates to victory_screen component.
func show_final_round_notification() -> void:
	if victory_screen:
		victory_screen.show_final_round_notification()


## Shows the victory screen with score breakdown.
## Delegates to victory_screen component.
## all_scores: Array of {player: Player, scores: Dictionary}
func show_victory_screen(all_scores: Array) -> void:
	# Hide game UI
	visible = false

	# Show victory screen
	if victory_screen:
		victory_screen.show_victory_screen(all_scores)


## Update god display when player selects a god
func update_god_display(god: God, god_manager: GodManager) -> void:
	if god_panel:
		god_panel.update_god_display(god, god_manager, board_manager)
		god_panel.power_activated.connect(_on_power_activated)


func _on_power_activated(power: GodPower, god_manager: GodManager) -> void:
	if board_manager and board_manager.current_player:
		god_manager.activate_power(power, board_manager.current_player, board_manager)


## Shows the resource type picker UI for CHANGE_TILE_TYPE power
## Delegates to resource_type_picker component.
func show_resource_type_picker(q: int, r: int, current_type: int, tile_type: int) -> void:
	if resource_type_picker:
		resource_type_picker.show_picker(q, r, current_type, tile_type)


## Handle resource type selection from picker
func _on_resource_type_selected(q: int, r: int, resource_type: int) -> void:
	# Trigger the tile type change
	if board_manager:
		board_manager.on_change_tile_type(q, r, resource_type)


## Handle picker cancellation
func _on_resource_type_picker_cancelled() -> void:
	# Cancel placement mode
	if board_manager and board_manager.placement_controller:
		board_manager.placement_controller.cancel_placement()
		

## Consume all input events on the overlay to prevent click-through
func _on_overlay_gui_input(event: InputEvent) -> void:
	# Accept and consume all mouse button events to prevent click-through to 3D scene
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
