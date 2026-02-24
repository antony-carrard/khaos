extends Control

## Main menu — shown before the game scene loads.
## Flow: mode cards → (Hot-Seat) player count picker → start game
##                  → (Network) disabled / coming soon

# Layout constants
const TITLE_FONT_SIZE: int = 120
const TAGLINE_FONT_SIZE: int = 28
const CARD_TITLE_FONT_SIZE: int = 42
const CARD_SUBTITLE_FONT_SIZE: int = 22
const CARD_PLAY_BTN_FONT_SIZE: int = 28
const CARD_MIN_SIZE: Vector2 = Vector2(380, 260)
const CARD_SEPARATION: int = 80
const CARD_CORNER_RADIUS: int = 16
const COUNT_BTN_SIZE: Vector2 = Vector2(100, 100)
const COUNT_BTN_FONT_SIZE: int = 48
const COUNT_BTN_CORNER_RADIUS: int = 10
const START_BTN_FONT_SIZE: int = 36
const TITLE_BOTTOM_Y: float = 320.0  # vertical offset below which mode/count sections sit

const COLOR_BG: Color = Color(0.04, 0.04, 0.08)
const COLOR_CARD_BG: Color = Color(0.12, 0.10, 0.20)
const COLOR_CARD_BORDER: Color = Color(0.45, 0.35, 0.75)
const COLOR_CARD_DISABLED_BG: Color = Color(0.08, 0.08, 0.12)
const COLOR_CARD_DISABLED_BORDER: Color = Color(0.25, 0.25, 0.35)
const COLOR_COUNT_SELECTED_BG: Color = Color(0.45, 0.30, 0.75)
const COLOR_COUNT_SELECTED_BORDER: Color = Color(0.70, 0.50, 1.00)
const COLOR_COUNT_NORMAL_BG: Color = Color(0.12, 0.10, 0.20)
const COLOR_COUNT_NORMAL_BORDER: Color = Color(0.30, 0.25, 0.45)
const COLOR_TITLE_OUTLINE: Color = Color(0.30, 0.10, 0.55)
const COLOR_TAGLINE: Color = Color(0.55, 0.50, 0.75)

var _mode_container: CenterContainer = null
var _count_container: CenterContainer = null
var _count_start_btn: Button = null  # stored so text can be updated ("Start Game" vs "Next →")
var _count_buttons: Array[Button] = []
var _selected_count: int = 2

var _index_container: CenterContainer = null  # "which player are you?" section (network only)
var _index_buttons: Array[Button] = []
var _selected_index: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_mode_section()
	_build_count_section()
	_build_title()  # added last so it renders on top


func _build_title() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	vbox.position.y = 80.0
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	var title := Label.new()
	title.text = "CHAOS"
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", COLOR_TITLE_OUTLINE)
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	var tagline := Label.new()
	tagline.text = "A divine strategy game"
	tagline.add_theme_font_size_override("font_size", TAGLINE_FONT_SIZE)
	tagline.add_theme_color_override("font_color", COLOR_TAGLINE)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(tagline)


func _build_mode_section() -> void:
	_mode_container = CenterContainer.new()
	_mode_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mode_container.offset_top = TITLE_BOTTOM_Y
	add_child(_mode_container)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", CARD_SEPARATION)
	_mode_container.add_child(hbox)

	_build_mode_card(hbox, "Hot-Seat", "1–4 players\nOne machine", false, _on_hot_seat_pressed)
	_build_mode_card(hbox, "Network", "1–4 players\nSame machine (stub)", false, _on_network_pressed)


func _build_mode_card(parent: Control, title: String, subtitle: String,
		disabled: bool, callback: Callable) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_MIN_SIZE

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CARD_DISABLED_BG if disabled else COLOR_CARD_BG
	style.border_color = COLOR_CARD_DISABLED_BORDER if disabled else COLOR_CARD_BORDER
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.set_corner_radius_all(CARD_CORNER_RADIUS)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)

	if disabled:
		panel.modulate.a = 0.4

	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", CARD_TITLE_FONT_SIZE)
	title_lbl.add_theme_color_override("font_color",
		Color(0.5, 0.5, 0.6) if disabled else Color.WHITE)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = subtitle
	sub_lbl.add_theme_font_size_override("font_size", CARD_SUBTITLE_FONT_SIZE)
	sub_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.70))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub_lbl)

	if not disabled:
		var btn := Button.new()
		btn.text = "Play"
		btn.add_theme_font_size_override("font_size", CARD_PLAY_BTN_FONT_SIZE)
		btn.custom_minimum_size = Vector2(160, 52)
		if callback.is_valid():
			btn.pressed.connect(callback)
		vbox.add_child(btn)


func _build_count_section() -> void:
	_count_container = CenterContainer.new()
	_count_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_count_container.offset_top = TITLE_BOTTOM_Y
	_count_container.visible = false
	add_child(_count_container)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 36)
	_count_container.add_child(vbox)

	var prompt := Label.new()
	prompt.text = "Number of Players"
	prompt.add_theme_font_size_override("font_size", 36)
	prompt.add_theme_color_override("font_color", Color.WHITE)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(prompt)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(hbox)

	for i in range(1, 5):
		var btn := Button.new()
		btn.text = str(i)
		btn.add_theme_font_size_override("font_size", COUNT_BTN_FONT_SIZE)
		btn.custom_minimum_size = COUNT_BTN_SIZE
		var count := i  # capture for lambda
		btn.pressed.connect(func() -> void: _select_count(count))
		hbox.add_child(btn)
		_count_buttons.append(btn)

	var start_btn := Button.new()
	start_btn.text = "Start Game"
	start_btn.add_theme_font_size_override("font_size", START_BTN_FONT_SIZE)
	start_btn.custom_minimum_size = Vector2(240, 64)
	start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(start_btn)
	_count_start_btn = start_btn

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.pressed.connect(_on_back_pressed)
	vbox.add_child(back_btn)

	_select_count(2)  # default selection


func _select_count(count: int) -> void:
	_selected_count = count
	for i in range(_count_buttons.size()):
		var btn: Button = _count_buttons[i]
		var selected: bool = (i + 1 == count)

		var style_normal := StyleBoxFlat.new()
		style_normal.set_corner_radius_all(COUNT_BTN_CORNER_RADIUS)
		style_normal.border_width_left = 2
		style_normal.border_width_right = 2
		style_normal.border_width_top = 2
		style_normal.border_width_bottom = 2
		if selected:
			style_normal.bg_color = COLOR_COUNT_SELECTED_BG
			style_normal.border_color = COLOR_COUNT_SELECTED_BORDER
		else:
			style_normal.bg_color = COLOR_COUNT_NORMAL_BG
			style_normal.border_color = COLOR_COUNT_NORMAL_BORDER

		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_normal)
		btn.add_theme_color_override("font_color",
			Color.WHITE if selected else Color(0.60, 0.60, 0.70))


func _on_hot_seat_pressed() -> void:
	GameConfig.mode = GameConfig.GameMode.HOT_SEAT
	_mode_container.visible = false
	_count_container.visible = true
	if _count_start_btn:
		_count_start_btn.text = "Start Game"


func _on_network_pressed() -> void:
	GameConfig.mode = GameConfig.GameMode.NETWORK
	_mode_container.visible = false
	_count_container.visible = true
	if _count_start_btn:
		_count_start_btn.text = "Next →"


func _on_start_pressed() -> void:
	if GameConfig.mode == GameConfig.GameMode.NETWORK:
		# Network: show player index picker before starting
		_show_index_section()
	else:
		GameConfig.player_count = _selected_count
		GameConfig.initialized = true
		get_tree().change_scene_to_file("res://main.tscn")


func _on_back_pressed() -> void:
	_count_container.visible = false
	_mode_container.visible = true


## Show "which player are you?" screen for network mode.
## Dynamically built based on _selected_count so the buttons match the chosen player count.
func _show_index_section() -> void:
	if _index_container:
		_index_container.queue_free()
		_index_container = null
	_index_buttons.clear()

	GameConfig.player_count = _selected_count
	_selected_index = 0

	_index_container = CenterContainer.new()
	_index_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_index_container.offset_top = TITLE_BOTTOM_Y
	add_child(_index_container)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 36)
	_index_container.add_child(vbox)

	var prompt := Label.new()
	prompt.text = "Which player are you?"
	prompt.add_theme_font_size_override("font_size", 36)
	prompt.add_theme_color_override("font_color", Color.WHITE)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(prompt)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(hbox)

	for i in range(_selected_count):
		var btn := Button.new()
		btn.text = "Player %d" % (i + 1)
		btn.add_theme_font_size_override("font_size", COUNT_BTN_FONT_SIZE)
		btn.custom_minimum_size = COUNT_BTN_SIZE
		var idx := i  # capture for lambda
		btn.pressed.connect(func() -> void: _select_index(idx))
		hbox.add_child(btn)
		_index_buttons.append(btn)

	var start_btn := Button.new()
	start_btn.text = "Start Game"
	start_btn.add_theme_font_size_override("font_size", START_BTN_FONT_SIZE)
	start_btn.custom_minimum_size = Vector2(240, 64)
	start_btn.pressed.connect(_on_index_start_pressed)
	vbox.add_child(start_btn)

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.pressed.connect(_on_index_back_pressed)
	vbox.add_child(back_btn)

	_count_container.visible = false
	_select_index(0)


func _select_index(idx: int) -> void:
	_selected_index = idx
	for i in range(_index_buttons.size()):
		var btn: Button = _index_buttons[i]
		var selected: bool = (i == idx)

		var style_normal := StyleBoxFlat.new()
		style_normal.set_corner_radius_all(COUNT_BTN_CORNER_RADIUS)
		style_normal.border_width_left = 2
		style_normal.border_width_right = 2
		style_normal.border_width_top = 2
		style_normal.border_width_bottom = 2
		if selected:
			style_normal.bg_color = COLOR_COUNT_SELECTED_BG
			style_normal.border_color = COLOR_COUNT_SELECTED_BORDER
		else:
			style_normal.bg_color = COLOR_COUNT_NORMAL_BG
			style_normal.border_color = COLOR_COUNT_NORMAL_BORDER

		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_normal)
		btn.add_theme_color_override("font_color",
			Color.WHITE if selected else Color(0.60, 0.60, 0.70))


func _on_index_start_pressed() -> void:
	GameConfig.local_player_index = _selected_index
	GameConfig.initialized = true
	get_tree().change_scene_to_file("res://main.tscn")


func _on_index_back_pressed() -> void:
	if _index_container:
		_index_container.queue_free()
		_index_container = null
	_count_container.visible = true
