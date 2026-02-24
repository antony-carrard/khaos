extends Control

## God selection screen shown at game start for each player.
## Displays all 4 gods — gods already chosen by other players are greyed out.

# Layout constants
const GOD_CARD_SIZE: Vector2 = Vector2(400, 500)
const GOD_PORTRAIT_SIZE: Vector2 = Vector2(360, 240)
const GOD_CARD_SEPARATION: int = 30
const GOD_SELECTION_FONT_SIZE: int = 48
const PLAYER_HEADER_FONT_SIZE: int = 36
# Offset = -(4 × GOD_CARD_SIZE.x + 3 × GOD_CARD_SEPARATION) / 2
const HBOX_OFFSET_LEFT: float = -845.0
const HBOX_OFFSET_TOP: float = -280.0  # Half of GOD_CARD_SIZE.y minus title space

signal god_selected(god: God)

var gods: Array[God] = []

# Set these before add_child so _ready() can use them
var selecting_player_name: String = ""
var selecting_player_color: Color = Color.WHITE
var taken_gods: Array[God] = []


func _ready() -> void:
	# Load all gods
	gods = GodManager.create_all_gods()

	# Create full-screen dark overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.9)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow clicks to pass through
	add_child(overlay)

	# Player header: show player name in their color above the title
	if selecting_player_name != "":
		var player_header = Label.new()
		player_header.text = selecting_player_name
		player_header.add_theme_font_size_override("font_size", PLAYER_HEADER_FONT_SIZE)
		player_header.add_theme_color_override("font_color", selecting_player_color)
		player_header.add_theme_color_override("font_outline_color", Color.BLACK)
		player_header.add_theme_constant_override("outline_size", 4)
		player_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		player_header.position = Vector2(0, 10)
		player_header.set_anchors_preset(Control.PRESET_TOP_WIDE)
		player_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(player_header)

	# Title
	var title = Label.new()
	title.text = "Choisissez votre Dieu"
	title.add_theme_font_size_override("font_size", GOD_SELECTION_FONT_SIZE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 50)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow clicks to pass through
	add_child(title)

	# Create god cards container (1x4 horizontal row)
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", GOD_CARD_SEPARATION)
	hbox.anchor_left = 0.5
	hbox.anchor_top = 0.5
	hbox.anchor_right = 0.5
	hbox.anchor_bottom = 0.5
	hbox.offset_left = HBOX_OFFSET_LEFT
	hbox.offset_top = HBOX_OFFSET_TOP
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow clicks to pass through to cards
	add_child(hbox)

	# Create card for each god
	for god in gods:
		var is_taken = _is_god_taken(god)
		var card = create_god_card(god, is_taken)
		hbox.add_child(card)


## Check if a god has already been selected by another player
func _is_god_taken(god: God) -> bool:
	for taken in taken_gods:
		if taken.god_name == god.god_name:
			return true
	return false


## Create a clickable god card (greyed out and disabled if taken)
func create_god_card(god: God, is_taken: bool = false) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = GOD_CARD_SIZE

	# Style panel — dimmed if taken
	var style = StyleBoxFlat.new()
	if is_taken:
		style.bg_color = Color(0.08, 0.08, 0.1)
		style.border_color = Color(0.3, 0.3, 0.35)
	else:
		style.bg_color = Color(0.15, 0.15, 0.2)
		style.border_color = Color(0.5, 0.5, 0.6)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	card.add_theme_stylebox_override("panel", style)

	# Make card clickable (disabled if taken)
	if not is_taken:
		var button = Button.new()
		button.set_anchors_preset(Control.PRESET_FULL_RECT)
		button.flat = true
		button.pressed.connect(_on_god_card_clicked.bind(god))
		card.add_child(button)

	# Card content (VBoxContainer for vertical layout)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow clicks to pass through to button
	card.add_child(vbox)

	# God name (dimmed if taken)
	var name_label = Label.new()
	name_label.text = god.god_name
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_taken:
		name_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	vbox.add_child(name_label)

	# God portrait (dimmed if taken)
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = GOD_PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_taken:
		portrait.modulate = Color(0.4, 0.4, 0.4, 1.0)

	# Load portrait texture
	if ResourceLoader.exists(god.image_path):
		portrait.texture = load(god.image_path)
	else:
		Log.warn("God portrait not found: %s" % god.image_path)

	vbox.add_child(portrait)

	# Powers section
	var powers_label = Label.new()
	powers_label.text = "Pouvoirs:"
	powers_label.add_theme_font_size_override("font_size", 20)
	powers_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	powers_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_taken:
		powers_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	vbox.add_child(powers_label)

	# List each power
	for power in god.powers:
		var power_label = Label.new()
		var power_text = power.power_name
		if power.fervor_cost > 0:
			power_text += " (%d ferveur)" % power.fervor_cost
		if power.is_passive:
			power_text += " [Passif]"
		power_label.text = "• " + power_text
		power_label.add_theme_font_size_override("font_size", 16)
		power_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		power_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_taken:
			power_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		vbox.add_child(power_label)

		# Power description
		var desc_label = Label.new()
		desc_label.text = "  " + power.description
		desc_label.add_theme_font_size_override("font_size", 14)
		if is_taken:
			desc_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
		else:
			desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(desc_label)

	return card


## Handle god card click
func _on_god_card_clicked(god: God) -> void:
	Log.info("Selected god: %s" % god.god_name)
	god_selected.emit(god)
	queue_free()  # Remove UI after selection
