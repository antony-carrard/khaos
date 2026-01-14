extends Control

## God selection screen shown at game start
## Displays all 4 gods and lets player choose one

signal god_selected(god: God)

var gods: Array[God] = []

func _ready() -> void:
	# Load all gods
	gods = GodManager.create_all_gods()

	# Create full-screen dark overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.9)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow clicks to pass through
	add_child(overlay)

	# Title
	var title = Label.new()
	title.text = "Choisissez votre Dieu"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 50)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow clicks to pass through
	add_child(title)

	# Create god cards container (2x2 grid)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 40)
	grid.anchor_left = 0.5
	grid.anchor_top = 0.5
	grid.anchor_right = 0.5
	grid.anchor_bottom = 0.5
	grid.offset_left = -500  # Center (grid is 1000px wide: 2 cards × 460 + 40 gap)
	grid.offset_top = -350   # Center (grid is 700px tall: 2 cards × 600 + 40 gap)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow clicks to pass through to cards
	add_child(grid)

	# Create card for each god
	for god in gods:
		var card = create_god_card(god)
		grid.add_child(card)

## Create a clickable god card
func create_god_card(god: God) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 600)

	# Style panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.5, 0.5, 0.6)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	card.add_theme_stylebox_override("panel", style)

	# Make card clickable
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

	# God name
	var name_label = Label.new()
	name_label.text = god.god_name
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# God portrait
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(420, 280)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Load portrait texture
	if ResourceLoader.exists(god.image_path):
		portrait.texture = load(god.image_path)
	else:
		push_warning("God portrait not found: %s" % god.image_path)

	vbox.add_child(portrait)

	# Powers section
	var powers_label = Label.new()
	powers_label.text = "Pouvoirs:"
	powers_label.add_theme_font_size_override("font_size", 20)
	powers_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	powers_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		vbox.add_child(power_label)

		# Power description
		var desc_label = Label.new()
		desc_label.text = "  " + power.description
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(desc_label)

	return card

## Handle god card click
func _on_god_card_clicked(god: God) -> void:
	print("Selected god: %s" % god.god_name)
	god_selected.emit(god)
	queue_free()  # Remove UI after selection
