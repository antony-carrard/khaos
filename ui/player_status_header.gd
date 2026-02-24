extends Control
class_name PlayerStatusHeader

## Persistent top-of-screen header showing all players' current state.
## Read-only status strip — wired to existing signals, no architectural changes needed.

const CARD_MIN_WIDTH: int = 195
const CARD_HEIGHT: int = 80
const CARD_PADDING: int = 8
const HEADER_HEIGHT: int = 90
const PORTRAIT_SIZE: Vector2 = Vector2(40, 40)
const ICON_SIZE: Vector2 = Vector2(18, 18)

var _board_manager = null
var _active_index: int = 0
var _cards: Array[Dictionary] = []


func initialize(p_board_manager) -> void:
	_board_manager = p_board_manager
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui(p_board_manager.players)


func _build_ui(players: Array[Player]) -> void:
	# Transparent top strip — no background, cards float against the game world
	var top_strip = Control.new()
	top_strip.anchor_left = 0.0
	top_strip.anchor_right = 1.0
	top_strip.anchor_top = 0.0
	top_strip.anchor_bottom = 0.0
	top_strip.offset_bottom = HEADER_HEIGHT
	top_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(top_strip)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	top_strip.add_child(center)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	center.add_child(hbox)

	for i in range(players.size()):
		_create_player_card(players[i], i, hbox)


func _create_player_card(player: Player, index: int, parent: HBoxContainer) -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_MIN_WIDTH, CARD_HEIGHT)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_apply_card_style(panel, false, player.player_color)
	parent.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CARD_PADDING)
	margin.add_theme_constant_override("margin_right", CARD_PADDING)
	margin.add_theme_constant_override("margin_top", CARD_PADDING)
	margin.add_theme_constant_override("margin_bottom", CARD_PADDING)
	panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)

	# Portrait
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if player.god and ResourceLoader.exists(player.god.image_path):
		portrait.texture = load(player.god.image_path)
	hbox.add_child(portrait)

	# Right column: name row + stats
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	# Name row: triangle indicator + name label
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	vbox.add_child(name_row)

	var triangle_label = Label.new()
	triangle_label.text = "▶"
	triangle_label.add_theme_font_size_override("font_size", 11)
	triangle_label.add_theme_color_override("font_color", Color.WHITE)
	triangle_label.visible = false
	name_row.add_child(triangle_label)

	var name_label = Label.new()
	name_label.text = player.player_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", player.player_color.lightened(0.25))
	name_row.add_child(name_label)

	var stats_hbox = HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 5)
	vbox.add_child(stats_hbox)

	var glory_label = _create_stat_label(stats_hbox, "res://icons/star.svg", str(player.glory))
	var resources_label = _create_stat_label(stats_hbox, "res://icons/wood.svg", str(player.resources))
	var fervor_label = _create_stat_label(stats_hbox, "res://icons/pray.svg", str(player.fervor))

	_cards.append({
		"panel": panel,
		"name_label": name_label,
		"triangle_label": triangle_label,
		"glory_label": glory_label,
		"resources_label": resources_label,
		"fervor_label": fervor_label,
		"portrait": portrait,
		"player_color": player.player_color,
	})


func _create_stat_label(parent: HBoxContainer, icon_path: String, initial_value: String) -> Label:
	var icon = TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var texture = load(icon_path) as Texture2D
	if texture:
		icon.texture = texture
	parent.add_child(icon)

	var label = Label.new()
	label.text = initial_value
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color.WHITE)
	parent.add_child(label)

	return label


## Fires on every turn switch (and at startup via bind()).
## Refreshes ALL cards so non-active player stats stay accurate after harvest.
func on_player_changed(player: Player) -> void:
	for i in range(_board_manager.players.size()):
		if _board_manager.players[i] == player:
			_active_index = i
			break

	for i in range(_cards.size()):
		var p: Player = _board_manager.players[i]
		var card: Dictionary = _cards[i]
		card.resources_label.text = str(p.resources)
		card.fervor_label.text = str(p.fervor)
		card.glory_label.text = str(p.glory)
		if p.god and ResourceLoader.exists(p.god.image_path):
			(card.portrait as TextureRect).texture = load(p.god.image_path)
		_set_card_active(i, i == _active_index)


## Fires during a turn when the active player's resources change.
func on_active_resources_changed(amount: int) -> void:
	if _active_index < _cards.size():
		_cards[_active_index].resources_label.text = str(amount)


## Fires during a turn when the active player's fervor changes.
func on_active_fervor_changed(amount: int) -> void:
	if _active_index < _cards.size():
		_cards[_active_index].fervor_label.text = str(amount)


## Fires during a turn when the active player's glory changes.
func on_active_glory_changed(amount: int) -> void:
	if _active_index < _cards.size():
		_cards[_active_index].glory_label.text = str(amount)


func _set_card_active(index: int, is_active: bool) -> void:
	if index >= _cards.size():
		return
	var card: Dictionary = _cards[index]
	(card.triangle_label as Label).visible = is_active
	var name_color := Color.WHITE if is_active else (card.player_color as Color).lightened(0.25)
	(card.name_label as Label).add_theme_color_override("font_color", name_color)
	_apply_card_style(card.panel as PanelContainer, is_active, card.player_color)


func _apply_card_style(panel: PanelContainer, is_active: bool, player_color: Color) -> void:
	var pc := player_color
	var style = StyleBoxFlat.new()
	if is_active:
		# Player color floods in — saturated but slightly darkened for text readability
		style.bg_color = pc.darkened(0.35)
		style.bg_color.a = 0.97
		style.border_color = pc.darkened(0.55)
	else:
		# Neutral dark — color identity comes from the name only
		style.bg_color = Color(0.12, 0.12, 0.14, 0.92)
		style.border_color = Color(0.06, 0.06, 0.07, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
