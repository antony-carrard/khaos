extends Control

## Main menu — shown before the game scene loads.
## Flow:
##   Main (Local | Host | Join)
##   ├─ Local → count picker → Start Game
##   ├─ Host  → name + port → Create Server → Lobby (host sees Start Game)
##   └─ Join  → name + IP + port → Connect → Lobby (client sees waiting label)

# Layout constants
const TITLE_FONT_SIZE: int = 120
const TAGLINE_FONT_SIZE: int = 28
const COUNT_BTN_SIZE: Vector2 = Vector2(100, 100)
const COUNT_BTN_FONT_SIZE: int = 48
const COUNT_BTN_CORNER_RADIUS: int = 10
const START_BTN_FONT_SIZE: int = 36
const TITLE_BOTTOM_Y: float = 320.0

const COLOR_BG: Color = Color(0.04, 0.04, 0.08)
const COLOR_CARD_BG: Color = Color(0.12, 0.10, 0.20)
const COLOR_CARD_BORDER: Color = Color(0.45, 0.35, 0.75)
const COLOR_COUNT_SELECTED_BG: Color = Color(0.45, 0.30, 0.75)
const COLOR_COUNT_SELECTED_BORDER: Color = Color(0.70, 0.50, 1.00)
const COLOR_COUNT_NORMAL_BG: Color = Color(0.12, 0.10, 0.20)
const COLOR_COUNT_NORMAL_BORDER: Color = Color(0.30, 0.25, 0.45)
const COLOR_TITLE_OUTLINE: Color = Color(0.30, 0.10, 0.55)
const COLOR_TAGLINE: Color = Color(0.55, 0.50, 0.75)

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "player"
const SETTINGS_KEY_NAME := "name"

var _current_container: CenterContainer = null
var _count_buttons: Array[Button] = []
var _selected_count: int = 2
var _lobby_refresh: Callable  # stored so it can be disconnected when leaving the lobby


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_title()
	_show_main_section()


func _exit_tree() -> void:
	_disconnect_lobby_refresh()


## ─── TITLE ──────────────────────────────────────────────────────────────────

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


## ─── SCREEN MANAGEMENT ──────────────────────────────────────────────────────

func _set_screen(container: CenterContainer) -> void:
	_disconnect_lobby_refresh()
	if _current_container:
		_current_container.queue_free()
	_current_container = container
	add_child(_current_container)


## Creates a fresh full-screen CenterContainer + VBoxContainer, sets it as the active screen.
func _make_screen_vbox() -> VBoxContainer:
	var container := CenterContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.offset_top = TITLE_BOTTOM_Y
	_set_screen(container)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 36)
	container.add_child(vbox)
	return vbox


func _disconnect_lobby_refresh() -> void:
	if _lobby_refresh.is_valid() and NetworkManager.lobby_updated.is_connected(_lobby_refresh):
		NetworkManager.lobby_updated.disconnect(_lobby_refresh)
	_lobby_refresh = Callable()


## ─── PERSISTENCE ────────────────────────────────────────────────────────────

func _load_saved_name() -> String:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		return config.get_value(SETTINGS_SECTION, SETTINGS_KEY_NAME, "")
	return ""


func _save_name(name: String) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY_NAME, name)
	config.save(SETTINGS_PATH)


## ─── SHARED BUILDERS ────────────────────────────────────────────────────────

func _build_screen_title(vbox: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)


func _build_name_field(vbox: VBoxContainer) -> LineEdit:
	var field := LineEdit.new()
	field.text = _load_saved_name()
	field.placeholder_text = "Your name"
	field.add_theme_font_size_override("font_size", 28)
	field.custom_minimum_size = Vector2(300, 52)
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.max_length = 24
	vbox.add_child(field)
	return field


func _build_status_label(vbox: VBoxContainer) -> Label:
	var lbl := Label.new()
	lbl.text = ""
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)
	return lbl


func _build_back_button(vbox: VBoxContainer, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = "← Back"
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(callback)
	vbox.add_child(btn)


## ─── MAIN SECTION ───────────────────────────────────────────────────────────

func _show_main_section() -> void:
	var vbox := _make_screen_vbox()

	for pair in [["Local", _show_local_section], ["Host", _show_host_section], ["Join", _show_join_section]]:
		var btn := Button.new()
		btn.text = pair[0]
		btn.add_theme_font_size_override("font_size", START_BTN_FONT_SIZE)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.custom_minimum_size = Vector2(240, 64)
		var style_normal := StyleBoxFlat.new()
		style_normal.bg_color = COLOR_COUNT_SELECTED_BG
		style_normal.border_color = COLOR_COUNT_SELECTED_BORDER
		style_normal.border_width_left = 2
		style_normal.border_width_right = 2
		style_normal.border_width_top = 2
		style_normal.border_width_bottom = 2
		style_normal.set_corner_radius_all(COUNT_BTN_CORNER_RADIUS)
		var style_hover := StyleBoxFlat.new()
		style_hover.bg_color = COLOR_COUNT_SELECTED_BG.lightened(0.15)
		style_hover.border_color = COLOR_COUNT_SELECTED_BORDER
		style_hover.border_width_left = 2
		style_hover.border_width_right = 2
		style_hover.border_width_top = 2
		style_hover.border_width_bottom = 2
		style_hover.set_corner_radius_all(COUNT_BTN_CORNER_RADIUS)
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_normal)
		btn.pressed.connect(pair[1])
		vbox.add_child(btn)


## ─── LOCAL SECTION ──────────────────────────────────────────────────────────

func _show_local_section() -> void:
	var vbox := _make_screen_vbox()
	_build_screen_title(vbox, "Number of Players")

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(hbox)

	_count_buttons.clear()
	for i in range(1, 5):
		var btn := Button.new()
		btn.text = str(i)
		btn.add_theme_font_size_override("font_size", COUNT_BTN_FONT_SIZE)
		btn.custom_minimum_size = COUNT_BTN_SIZE
		var count := i
		btn.pressed.connect(func() -> void: _select_count(count))
		hbox.add_child(btn)
		_count_buttons.append(btn)

	var start_btn := Button.new()
	start_btn.text = "Start Game"
	start_btn.add_theme_font_size_override("font_size", START_BTN_FONT_SIZE)
	start_btn.custom_minimum_size = Vector2(240, 64)
	start_btn.pressed.connect(func() -> void:
		GameConfig.mode = GameConfig.GameMode.HOT_SEAT
		GameConfig.player_count = _selected_count
		GameConfig.player_names = []
		GameConfig.initialized = true
		get_tree().change_scene_to_file("res://main.tscn"))
	vbox.add_child(start_btn)

	_build_back_button(vbox, _show_main_section)
	_select_count(2)


func _select_count(count: int) -> void:
	_selected_count = count
	for i in range(_count_buttons.size()):
		var btn: Button = _count_buttons[i]
		var selected: bool = (i + 1 == count)

		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(COUNT_BTN_CORNER_RADIUS)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		if selected:
			style.bg_color = COLOR_COUNT_SELECTED_BG
			style.border_color = COLOR_COUNT_SELECTED_BORDER
		else:
			style.bg_color = COLOR_COUNT_NORMAL_BG
			style.border_color = COLOR_COUNT_NORMAL_BORDER

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_color_override("font_color",
			Color.WHITE if selected else Color(0.60, 0.60, 0.70))


## ─── HOST SECTION ───────────────────────────────────────────────────────────

func _show_host_section() -> void:
	var vbox := _make_screen_vbox()
	_build_screen_title(vbox, "Host a Game")

	var name_edit := _build_name_field(vbox)

	var port_edit := LineEdit.new()
	port_edit.text = str(NetworkManager.DEFAULT_PORT)
	port_edit.placeholder_text = "Port"
	port_edit.add_theme_font_size_override("font_size", 28)
	port_edit.custom_minimum_size = Vector2(200, 52)
	port_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(port_edit)

	var status_lbl := _build_status_label(vbox)

	var create_btn := Button.new()
	create_btn.text = "Create Server"
	create_btn.add_theme_font_size_override("font_size", START_BTN_FONT_SIZE)
	create_btn.custom_minimum_size = Vector2(240, 64)
	create_btn.pressed.connect(func() -> void:
		var player_name := name_edit.text.strip_edges()
		if player_name.is_empty():
			status_lbl.text = "Please enter your name"
			return
		var port := int(port_edit.text) if port_edit.text.is_valid_int() else NetworkManager.DEFAULT_PORT
		var err := NetworkManager.create_server(port)
		if err != OK:
			status_lbl.text = "Failed to create server (error %d)" % err
			return
		_save_name(player_name)
		NetworkManager.register_host_name(player_name)
		_show_lobby_section())
	vbox.add_child(create_btn)

	_build_back_button(vbox, _show_main_section)


## ─── JOIN SECTION ───────────────────────────────────────────────────────────

func _show_join_section() -> void:
	var vbox := _make_screen_vbox()
	_build_screen_title(vbox, "Join a Game")

	var name_edit := _build_name_field(vbox)

	var ip_edit := LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "Server IP"
	ip_edit.add_theme_font_size_override("font_size", 28)
	ip_edit.custom_minimum_size = Vector2(300, 52)
	ip_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(ip_edit)

	var port_edit := LineEdit.new()
	port_edit.text = str(NetworkManager.DEFAULT_PORT)
	port_edit.placeholder_text = "Port"
	port_edit.add_theme_font_size_override("font_size", 28)
	port_edit.custom_minimum_size = Vector2(200, 52)
	port_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(port_edit)

	var status_lbl := _build_status_label(vbox)

	var connect_btn := Button.new()
	connect_btn.text = "Connect"
	connect_btn.add_theme_font_size_override("font_size", START_BTN_FONT_SIZE)
	connect_btn.custom_minimum_size = Vector2(240, 64)
	connect_btn.pressed.connect(func() -> void:
		var player_name := name_edit.text.strip_edges()
		if player_name.is_empty():
			status_lbl.text = "Please enter your name"
			return
		status_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
		status_lbl.text = "Connecting…"
		connect_btn.disabled = true
		var port := int(port_edit.text) if port_edit.text.is_valid_int() else NetworkManager.DEFAULT_PORT
		var err := NetworkManager.join_server(ip_edit.text.strip_edges(), port)
		if err != OK:
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
			status_lbl.text = "Failed to connect (error %d)" % err
			connect_btn.disabled = false
			return
		var on_success := func() -> void:
			_save_name(player_name)
			# Optimistic local update so the player sees their own name immediately
			NetworkManager.peer_names[multiplayer.get_unique_id()] = player_name
			NetworkManager.rpc_id(1, "register_name", player_name)
			_show_lobby_section()
		var on_failure := func() -> void:
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
			status_lbl.text = "Connection failed"
			connect_btn.disabled = false
		NetworkManager.connection_succeeded.connect(on_success, CONNECT_ONE_SHOT)
		NetworkManager.connection_failed.connect(on_failure, CONNECT_ONE_SHOT))
	vbox.add_child(connect_btn)

	_build_back_button(vbox, func() -> void:
		NetworkManager.disconnect_network()
		_show_main_section())


## ─── LOBBY SECTION ──────────────────────────────────────────────────────────

func _show_lobby_section() -> void:
	var vbox := _make_screen_vbox()
	_build_screen_title(vbox, "Lobby")

	var player_list := VBoxContainer.new()
	player_list.add_theme_constant_override("separation", 12)
	vbox.add_child(player_list)

	if NetworkManager.is_host:
		var start_btn := Button.new()
		start_btn.text = "Start Game"
		start_btn.add_theme_font_size_override("font_size", START_BTN_FONT_SIZE)
		start_btn.custom_minimum_size = Vector2(240, 64)
		start_btn.pressed.connect(func() -> void:
			var all_peers: Array[int] = []
			all_peers.assign(NetworkManager.peer_names.keys())
			all_peers.sort()
			var count := all_peers.size()
			var peer_map: Dictionary = {}
			for i in range(count):
				peer_map[all_peers[i]] = i
			var rng_seed := randi()
			NetworkManager.rpc("start_game", count, peer_map, rng_seed))
		vbox.add_child(start_btn)
	else:
		var waiting_lbl := Label.new()
		waiting_lbl.text = "Waiting for the host to start…"
		waiting_lbl.add_theme_font_size_override("font_size", 24)
		waiting_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		waiting_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(waiting_lbl)

	_build_back_button(vbox, func() -> void:
		NetworkManager.disconnect_network()
		_show_main_section())

	# Rebuild player list from current peer_names (authoritative on all machines)
	var refresh := func() -> void:
		if not is_instance_valid(player_list):
			return
		for child in player_list.get_children():
			child.queue_free()
		var all_peers: Array[int] = []
		all_peers.assign(NetworkManager.peer_names.keys())
		all_peers.sort()  # host (1) always first, then clients in join order
		var my_id := multiplayer.get_unique_id()
		for pid in all_peers:
			var player_name: String = NetworkManager.peer_names.get(pid, "…")
			var host_tag := " (host)" if pid == 1 else ""
			var me_tag := " ← you" if pid == my_id else ""
			var lbl := Label.new()
			lbl.text = "%s%s%s" % [player_name, host_tag, me_tag]
			lbl.add_theme_font_size_override("font_size", 26)
			lbl.add_theme_color_override("font_color", Color.WHITE)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			player_list.add_child(lbl)

	_lobby_refresh = refresh
	NetworkManager.lobby_updated.connect(refresh)
	refresh.call()
