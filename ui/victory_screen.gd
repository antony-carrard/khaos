extends Control
class_name VictoryScreen

## Victory screen component - displays endgame results and score breakdown
## Extracted from tile_selector_ui.gd for better code organization

# Layout constants
const VICTORY_PLAYER_CARD_SIZE: Vector2 = Vector2(400, 480)
const VICTORY_CARD_SEPARATION: int = 30
const VICTORY_TITLE_FONT_SIZE: int = 48
const VICTORY_WINNER_FONT_SIZE: int = 28
const VICTORY_BUTTON_SIZE: Vector2 = Vector2(180, 50)
const BREAKDOWN_PANEL_MARGIN: int = 15
const TITLE_AREA_HEIGHT: int = 140
const BUTTONS_AREA_HEIGHT: int = 80


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

	# Add to self (victory_screen is still visible at this point)
	add_child(notif)

	# Fade out after 4 seconds
	var tween = create_tween()
	tween.tween_property(notif, "modulate:a", 0.0, 1.0).set_delay(3.0)
	tween.tween_callback(notif.queue_free)


## Shows the victory screen with score breakdown.
## all_scores: Array of {player: Player, scores: Dictionary}
func show_victory_screen(all_scores: Array) -> void:
	# Create victory screen overlay
	var victory_overlay = _create_victory_screen(all_scores)

	# Add to scene root (not parent) to avoid being hidden when tile_selector_ui becomes invisible
	var scene_root = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	if scene_root:
		scene_root.add_child(victory_overlay)


## Creates the victory screen UI overlay.
func _create_victory_screen(all_scores: Array) -> Control:
	# Full-screen semi-transparent overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks to game

	# Block all mouse input including wheel zoom
	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton or event is InputEventMouseMotion:
			overlay.accept_event()
	)

	# Title
	var title = Label.new()
	title.text = "GAME OVER"
	title.add_theme_font_size_override("font_size", VICTORY_TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 15
	title.offset_bottom = 75
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(title)

	# Winner announcement
	var winner_data = _determine_winner(all_scores)
	var winner_label = Label.new()
	if winner_data.is_tie:
		winner_label.text = "TIE between %s!" % winner_data.tied_names
	else:
		winner_label.text = "Winner: %s — %d points" % [winner_data.winner_name, winner_data.winner_score]
	winner_label.add_theme_font_size_override("font_size", VICTORY_WINNER_FONT_SIZE)
	winner_label.add_theme_color_override("font_color", Color.WHITE)
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	winner_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	winner_label.offset_top = 75
	winner_label.offset_bottom = TITLE_AREA_HEIGHT
	winner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(winner_label)

	# Cards area — CenterContainer between title and buttons
	var cards_center = CenterContainer.new()
	cards_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cards_center.offset_top = TITLE_AREA_HEIGHT
	cards_center.offset_bottom = -BUTTONS_AREA_HEIGHT
	cards_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cards_center)

	# HBox for side-by-side player cards
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", VICTORY_CARD_SEPARATION)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards_center.add_child(hbox)

	# Create a card for each player
	var winners: Array = winner_data.winners
	for score_entry in all_scores:
		var is_winner: bool = score_entry.player in winners
		var card = _create_player_breakdown(score_entry.player, score_entry.scores, is_winner)
		hbox.add_child(card)

	# Buttons
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_hbox.add_theme_constant_override("separation", 20)
	button_hbox.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	button_hbox.offset_top = -(BUTTONS_AREA_HEIGHT - 15)
	button_hbox.offset_bottom = -15
	button_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(button_hbox)

	# Return to menu button (disabled — no menu system yet)
	var menu_button = Button.new()
	menu_button.text = "Return to Menu"
	menu_button.disabled = true
	menu_button.custom_minimum_size = VICTORY_BUTTON_SIZE
	button_hbox.add_child(menu_button)

	# New game button
	var new_game_button = Button.new()
	new_game_button.text = "New Game"
	new_game_button.custom_minimum_size = VICTORY_BUTTON_SIZE
	var new_game_style = _create_button_style(Color(0.3, 0.7, 0.3))
	new_game_button.add_theme_stylebox_override("normal", new_game_style)
	new_game_button.add_theme_stylebox_override("hover", _create_button_style(Color(0.4, 0.8, 0.4)))
	new_game_button.add_theme_color_override("font_color", Color.WHITE)
	new_game_button.add_theme_font_size_override("font_size", 18)
	new_game_button.pressed.connect(_on_new_game)
	button_hbox.add_child(new_game_button)

	return overlay


## Creates score breakdown card for a single player.
func _create_player_breakdown(player: Player, scores: Dictionary, is_winner: bool = false) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = VICTORY_PLAYER_CARD_SIZE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	if is_winner:
		style.border_color = Color(0.9, 0.75, 0.2)  # Gold
		style.border_width_left = 4
		style.border_width_right = 4
		style.border_width_top = 4
		style.border_width_bottom = 4
	else:
		style.border_color = Color(0.4, 0.4, 0.5)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", BREAKDOWN_PANEL_MARGIN)
	margin.add_theme_constant_override("margin_right", BREAKDOWN_PANEL_MARGIN)
	margin.add_theme_constant_override("margin_top", BREAKDOWN_PANEL_MARGIN)
	margin.add_theme_constant_override("margin_bottom", BREAKDOWN_PANEL_MARGIN)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Player name
	var name_label = Label.new()
	name_label.text = player.player_name
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color",
		Color(0.9, 0.8, 0.3) if is_winner else Color(0.9, 0.9, 0.9))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# Winner tag
	if is_winner:
		var winner_tag = Label.new()
		winner_tag.text = "* WINNER *"
		winner_tag.add_theme_font_size_override("font_size", 16)
		winner_tag.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
		winner_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(winner_tag)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Score breakdown
	var breakdown_text = """Villages (by terrain):
%s

Resources: %d → %d pts (%d pairs)
Fervor: %d → %d pts (%d pairs)
Glory: %d pts

Territory Bonus: %d pts
%s""" % [
		scores.village_breakdown,
		player.resources, scores.resource_points, int(player.resources / 2.0),
		player.fervor, scores.fervor_points, int(player.fervor / 2.0),
		scores.glory_points,
		scores.territory_points,
		scores.territory_breakdown,
	]

	var breakdown_label = Label.new()
	breakdown_label.text = breakdown_text
	breakdown_label.add_theme_font_size_override("font_size", 16)
	breakdown_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	breakdown_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	breakdown_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(breakdown_label)

	# Separator before total
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Total
	var total_label = Label.new()
	total_label.text = "TOTAL: %d points" % scores.total
	total_label.add_theme_font_size_override("font_size", 18)
	total_label.add_theme_color_override("font_color",
		Color(0.9, 0.8, 0.3) if is_winner else Color(0.8, 0.9, 0.8))
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(total_label)

	return panel


## Determines the winner from all player scores.
## Handles ties. Returns winners array for direct player comparison.
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
		"winner_score": max_score,
		"winners": winners,
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
