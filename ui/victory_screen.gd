extends Control
class_name VictoryScreen

## Victory screen component - displays endgame results and score breakdown
## Extracted from tile_selector_ui.gd for better code organization

# References to game data (needed for scoring display)
var player_class = preload("res://player.gd")
var tile_manager_class = preload("res://tile_manager.gd")


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
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks to game

	# Block all mouse input including wheel zoom
	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton or event is InputEventMouseMotion:
			overlay.accept_event()
	)

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
func _create_player_breakdown(player, scores: Dictionary) -> Control:
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
