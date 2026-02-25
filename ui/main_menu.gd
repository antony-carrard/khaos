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

var _network_container: CenterContainer = null  # current active network screen


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
		_show_host_join_section()
	else:
		GameConfig.player_count = _selected_count
		GameConfig.initialized = true
		get_tree().change_scene_to_file("res://main.tscn")


func _on_back_pressed() -> void:
	_count_container.visible = false
	_mode_container.visible = true


## ─── NETWORK LOBBY ─────────────────────────────────────────────────────────

func _clear_network_container() -> void:
	if _network_container:
		_network_container.queue_free()
		_network_container = null


func _make_network_container() -> VBoxContainer:
	_clear_network_container()
	_network_container = CenterContainer.new()
	_network_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_network_container.offset_top = TITLE_BOTTOM_Y
	add_child(_network_container)
	_count_container.visible = false

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 36)
	_network_container.add_child(vbox)
	return vbox


func _show_host_join_section() -> void:
	var vbox := _make_network_container()

	var prompt := Label.new()
	prompt.text = "Network Game"
	prompt.add_theme_font_size_override("font_size", 36)
	prompt.add_theme_color_override("font_color", Color.WHITE)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(prompt)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", CARD_SEPARATION)
	vbox.add_child(hbox)

	_build_mode_card(hbox, "Host", "Create a server\nfor others to join", false,
		_show_host_section)
	_build_mode_card(hbox, "Join", "Connect to\nan existing server", false,
		_show_join_section)

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.pressed.connect(func() -> void:
		_clear_network_container()
		_count_container.visible = true)
	vbox.add_child(back_btn)


func _show_host_section() -> void:
	var vbox := _make_network_container()

	var prompt := Label.new()
	prompt.text = "Host a Server"
	prompt.add_theme_font_size_override("font_size", 36)
	prompt.add_theme_color_override("font_color", Color.WHITE)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(prompt)

	var port_edit := LineEdit.new()
	port_edit.text = str(NetworkManager.DEFAULT_PORT)
	port_edit.placeholder_text = "Port"
	port_edit.add_theme_font_size_override("font_size", 28)
	port_edit.custom_minimum_size = Vector2(200, 52)
	port_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(port_edit)

	var status_lbl := Label.new()
	status_lbl.text = ""
	status_lbl.add_theme_font_size_override("font_size", 22)
	status_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status_lbl)

	var create_btn := Button.new()
	create_btn.text = "Create Server"
	create_btn.add_theme_font_size_override("font_size", START_BTN_FONT_SIZE)
	create_btn.custom_minimum_size = Vector2(240, 64)
	create_btn.pressed.connect(func() -> void:
		var port := int(port_edit.text) if port_edit.text.is_valid_int() else NetworkManager.DEFAULT_PORT
		var err := NetworkManager.create_server(port)
		if err != OK:
			status_lbl.text = "Failed to create server (error %d)" % err
		else:
			_show_lobby_section())
	vbox.add_child(create_btn)

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.pressed.connect(func() -> void:
		NetworkManager.disconnect_network()
		_show_host_join_section())
	vbox.add_child(back_btn)


func _show_join_section() -> void:
	var vbox := _make_network_container()

	var prompt := Label.new()
	prompt.text = "Join a Server"
	prompt.add_theme_font_size_override("font_size", 36)
	prompt.add_theme_color_override("font_color", Color.WHITE)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(prompt)

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

	var status_lbl := Label.new()
	status_lbl.text = ""
	status_lbl.add_theme_font_size_override("font_size", 22)
	status_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status_lbl)

	var connect_btn := Button.new()
	connect_btn.text = "Connect"
	connect_btn.add_theme_font_size_override("font_size", START_BTN_FONT_SIZE)
	connect_btn.custom_minimum_size = Vector2(240, 64)
	connect_btn.pressed.connect(func() -> void:
		var port := int(port_edit.text) if port_edit.text.is_valid_int() else NetworkManager.DEFAULT_PORT
		status_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
		status_lbl.text = "Connecting…"
		connect_btn.disabled = true
		var err := NetworkManager.join_server(ip_edit.text.strip_edges(), port)
		if err != OK:
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
			status_lbl.text = "Failed to connect (error %d)" % err
			connect_btn.disabled = false
			return
		# Bind one-shot signals (store in vars so CONNECT_ONE_SHOT can be passed cleanly)
		var on_success := func() -> void: _show_waiting_section()
		var on_failure := func() -> void:
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
			status_lbl.text = "Connection failed"
			connect_btn.disabled = false
		NetworkManager.connection_succeeded.connect(on_success, CONNECT_ONE_SHOT)
		NetworkManager.connection_failed.connect(on_failure, CONNECT_ONE_SHOT))
	vbox.add_child(connect_btn)

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.pressed.connect(func() -> void:
		NetworkManager.disconnect_network()
		_show_host_join_section())
	vbox.add_child(back_btn)


func _show_waiting_section() -> void:
	var vbox := _make_network_container()

	var lbl := Label.new()
	lbl.text = "Connected!\nWaiting for the host to start the game…"
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)

	var back_btn := Button.new()
	back_btn.text = "← Disconnect"
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.pressed.connect(func() -> void:
		NetworkManager.disconnect_network()
		_clear_network_container()
		_count_container.visible = true)
	vbox.add_child(back_btn)


func _show_lobby_section() -> void:
	var vbox := _make_network_container()

	var prompt := Label.new()
	prompt.text = "Lobby"
	prompt.add_theme_font_size_override("font_size", 36)
	prompt.add_theme_color_override("font_color", Color.WHITE)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(prompt)

	# Player list (rebuilt on peer connect/disconnect)
	var player_list := VBoxContainer.new()
	player_list.add_theme_constant_override("separation", 12)
	vbox.add_child(player_list)

	var start_btn := Button.new()
	start_btn.text = "Start Game"
	start_btn.add_theme_font_size_override("font_size", START_BTN_FONT_SIZE)
	start_btn.custom_minimum_size = Vector2(240, 64)
	start_btn.visible = NetworkManager.is_host
	vbox.add_child(start_btn)

	var back_btn := Button.new()
	back_btn.text = "← Disconnect"
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.pressed.connect(func() -> void:
		NetworkManager.disconnect_network()
		_clear_network_container()
		_count_container.visible = true)
	vbox.add_child(back_btn)

	# Rebuild player list helper
	var refresh := func() -> void:
		if not is_instance_valid(player_list):
			return
		for child in player_list.get_children():
			child.queue_free()
		var all_peers: Array[int] = [1]  # host is always peer 1
		for p in NetworkManager.get_connected_peers():
			if not all_peers.has(p):
				all_peers.append(p)
		var my_id := multiplayer.get_unique_id()
		for i in range(all_peers.size()):
			var lbl := Label.new()
			var pid := all_peers[i]
			var suffix := " (host)" if pid == 1 else ""
			var me_tag := " ← you" if pid == my_id else ""
			lbl.text = "Player %d%s%s" % [i + 1, suffix, me_tag]
			lbl.add_theme_font_size_override("font_size", 26)
			lbl.add_theme_color_override("font_color", Color.WHITE)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			player_list.add_child(lbl)

	refresh.call()

	# Wire peer connect/disconnect to refresh (disconnect when lobby is freed)
	NetworkManager.peer_connected.connect(func(_id: int) -> void: refresh.call())
	NetworkManager.peer_disconnected.connect(func(_id: int) -> void: refresh.call())

	start_btn.pressed.connect(func() -> void:
		var all_peers: Array[int] = [1]
		for p in NetworkManager.get_connected_peers():
			if not all_peers.has(p):
				all_peers.append(p)
		var count := mini(all_peers.size(), _selected_count)
		var peer_map: Dictionary = {}
		for i in range(count):
			peer_map[all_peers[i]] = i
		var rng_seed := randi()
		NetworkManager.rpc("start_game", count, peer_map, rng_seed))
