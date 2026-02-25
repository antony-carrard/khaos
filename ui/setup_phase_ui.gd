extends Control
class_name SetupPhaseUI

## Dedicated setup phase overlay — replaces all setup hacks in tile_selector_ui.
## Shown during setup rounds 1–3; freed when setup completes.
## Rounds 1 and 2: tile card selection. Round 3: village placement prompt.

signal setup_tile_selected(setup_index: int)

# Layout constants
const PANEL_PADDING: int = 25
const CARD_SIZE: Vector2 = Vector2(115, 130)
const CARD_MARGIN: int = 10
const CARD_CORNER_RADIUS: int = 10
const PLAYER_FONT_SIZE: int = 18
const TITLE_FONT_SIZE: int = 20
const INSTRUCTION_FONT_SIZE: int = 15

var tile_type_colors: Dictionary = {}
var _god_manager_ref: GodManager = null
var _board_manager_ref = null

var _god_panel: GodPanel = null
var _player_label: Label = null
var _round_label: Label = null
var _instruction_label: Label = null
var _cards_container: HBoxContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Call once after instantiation to supply tile colors and build the UI hierarchy.
func initialize(colors: Dictionary, god_manager: GodManager, board_manager) -> void:
	tile_type_colors = colors
	_god_manager_ref = god_manager
	_board_manager_ref = board_manager
	_build_ui()


func _build_ui() -> void:
	# Anchor to bottom of screen, matching the main hand UI position
	var anchor = Control.new()
	anchor.anchor_left = 0.0
	anchor.anchor_right = 1.0
	anchor.anchor_top = 1.0
	anchor.anchor_bottom = 1.0
	anchor.offset_top = -240
	anchor.offset_bottom = -25
	add_child(anchor)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anchor.add_child(center)

	# Side-by-side layout mirroring regular game: god panel left, setup info right
	var main_hbox = HBoxContainer.new()
	main_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_theme_constant_override("separation", 20)
	center.add_child(main_hbox)

	# God panel (left) — same component as regular game; power buttons show as disabled
	_god_panel = GodPanel.new()
	main_hbox.add_child(_god_panel)

	# Setup info panel (center)
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.04, 0.93)
	style.border_color = Color(0.90, 0.80, 0.30)  # Gold border
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	main_hbox.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", PANEL_PADDING)
	margin.add_theme_constant_override("margin_right", PANEL_PADDING)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Player name header (colored by player)
	_player_label = Label.new()
	_player_label.text = ""
	_player_label.add_theme_font_size_override("font_size", PLAYER_FONT_SIZE)
	_player_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_player_label.add_theme_constant_override("outline_size", 4)
	_player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_player_label)

	# Round instruction (gold)
	_round_label = Label.new()
	_round_label.text = "Setup Phase"
	_round_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_round_label.add_theme_color_override("font_color", Color(0.90, 0.80, 0.30))
	_round_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_round_label.add_theme_constant_override("outline_size", 4)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_round_label)

	# Instruction text for round 3 (village placement)
	_instruction_label = Label.new()
	_instruction_label.text = ""
	_instruction_label.add_theme_font_size_override("font_size", INSTRUCTION_FONT_SIZE)
	_instruction_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_instruction_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_instruction_label.add_theme_constant_override("outline_size", 3)
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction_label.visible = false
	vbox.add_child(_instruction_label)

	# Tile cards row
	_cards_container = HBoxContainer.new()
	_cards_container.add_theme_constant_override("separation", 14)
	_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_cards_container)

	# Balancing spacer (right) — mirrors god panel width so setup panel is visually centered
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(GodPanel.PANEL_SIZE.x, 0)
	main_hbox.add_child(spacer)


## Refreshes the UI for the given player and setup round.
## Called from board_manager._on_active_player_changed() on every player switch.
## player = active player (shown in the label); ui_player = local player (god + tiles).
func update_for_player(player: Player, setup_round: int) -> void:
	var ui_player: Player = _board_manager_ref.ui_player
	if ui_player.god and _god_panel:
		_god_panel.update_god_display(ui_player.god, _god_manager_ref, _board_manager_ref)

	_player_label.text = player.player_name
	_player_label.add_theme_color_override("font_color", player.player_color)

	match setup_round:
		1:
			_round_label.text = "Setup Round 1 — Choose your first tile to place"
		2:
			_round_label.text = "Setup Round 2 — Choose your second tile to place"
		_:
			_round_label.text = "Setup Round 3 — Place your village"

	if setup_round <= 2:
		_instruction_label.visible = false
		_show_tile_cards(ui_player.setup_tiles)
	else:
		_clear_cards()
		_instruction_label.text = "Click on one of your placed tiles to build your village"
		_instruction_label.visible = true


func _show_tile_cards(setup_tiles: Array) -> void:
	_clear_cards()
	for i in range(setup_tiles.size()):
		if setup_tiles[i] != null:
			_create_tile_card(i, setup_tiles[i])
		else:
			_create_placed_placeholder()


func _clear_cards() -> void:
	for child in _cards_container.get_children():
		child.queue_free()


## A clickable tile card for a remaining setup tile.
func _create_tile_card(setup_index: int, tile_def) -> void:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	var tile_color: Color = tile_type_colors.get(tile_def.tile_type, Color.GRAY)
	style.bg_color = tile_color.darkened(0.3)
	style.border_color = Color(0.90, 0.80, 0.30)  # Gold
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = CARD_CORNER_RADIUS
	style.corner_radius_top_right = CARD_CORNER_RADIUS
	style.corner_radius_bottom_left = CARD_CORNER_RADIUS
	style.corner_radius_bottom_right = CARD_CORNER_RADIUS
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = CARD_SIZE
	_cards_container.add_child(card)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CARD_MARGIN)
	margin.add_theme_constant_override("margin_right", CARD_MARGIN)
	margin.add_theme_constant_override("margin_top", CARD_MARGIN)
	margin.add_theme_constant_override("margin_bottom", CARD_MARGIN)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	# Tile type name
	var type_label = Label.new()
	type_label.text = TileManager.TileType.keys()[tile_def.tile_type]
	type_label.add_theme_color_override("font_color", Color.WHITE)
	type_label.add_theme_font_size_override("font_size", 13)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(type_label)

	# Resource icon
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(36, 36)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path: String = TileManager.RESOURCE_TYPE_ICONS[tile_def.resource_type]
	var icon := load(icon_path) as Texture2D
	if icon:
		icon_rect.texture = icon
	vbox.add_child(icon_rect)

	# FREE label
	var free_label = Label.new()
	free_label.text = "FREE"
	free_label.add_theme_color_override("font_color", Color(0.30, 0.90, 0.30))
	free_label.add_theme_font_size_override("font_size", 14)
	free_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(free_label)

	# Invisible click-catcher button over the whole card
	var btn = Button.new()
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(setup_tile_selected.emit.bind(setup_index))
	card.add_child(btn)


## A greyed-out placeholder for an already-placed setup tile.
func _create_placed_placeholder() -> void:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.5)
	style.border_color = Color(0.40, 0.40, 0.40, 0.6)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = CARD_CORNER_RADIUS
	style.corner_radius_top_right = CARD_CORNER_RADIUS
	style.corner_radius_bottom_left = CARD_CORNER_RADIUS
	style.corner_radius_bottom_right = CARD_CORNER_RADIUS
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = CARD_SIZE
	_cards_container.add_child(card)

	var label = Label.new()
	label.text = "✓ Placed"
	label.add_theme_color_override("font_color", Color(0.50, 0.80, 0.30))
	label.add_theme_font_size_override("font_size", 13)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(label)
