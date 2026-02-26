extends Node3D

# Hexagonal grid orchestrator
# Reference: https://www.redblobgames.com/grids/hexagons/

# Configuration
@export var hex_tile_scene: PackedScene = preload("res://hex_tile.tscn")
@export var max_stack_height: int = 3  # Maximum tiles that can be stacked
@export var test_mode: bool = false   # Unlimited resources/actions every turn for testing
@export var skip_setup: bool = false  # Auto-place setup tiles and skip to gameplay immediately
@export var player_count: int = 2    # Number of players (1–4)

# Emitted whenever the active player changes (both hot-seat and network modes).
# UI elements that need to know who is currently taking a turn connect here.
# In network mode, active_player_view stat signals stay bound to local player only,
# so this separate signal is the reliable way to track turn changes.
signal active_player_switched(player: Player)

# Internal: fires on each remote god-selection RPC receipt (network mode sequential flow)
signal _god_choice_received

# Player colors assigned in order
const PLAYER_COLORS: Array[Color] = [
	Color(0.2, 0.4, 1.0),  # Blue   — P1
	Color(1.0, 0.3, 0.2),  # Red    — P2
	Color(0.2, 0.8, 0.3),  # Green  — P3
	Color(1.0, 0.8, 0.2),  # Yellow — P4
]

# Manager components
var tile_manager: TileManager
var village_manager: VillageManager
var placement_controller: PlacementController
var tile_pool: TilePool
var turn_manager: TurnManager
var god_manager: GodManager

# UI
var ui: Control = null                   # Main game UI — null during setup phase
var setup_phase_ui: SetupPhaseUI = null  # Setup-only overlay — freed when setup completes

# Camera reference
var camera: Camera3D = null

# Players
var players: Array[Player] = []
var current_player_index: int = 0
var current_player: Player = null   # always == players[current_player_index]

var power_executor: PowerExecutor = null
var active_player_view: ActivePlayerView = null
var status_header: PlayerStatusHeader = null
var not_your_turn_overlay: NotYourTurnOverlay = null

# The player whose data the UI displays.
# Hot-seat: updated to current_player on every turn switch.
# Network:  set once to players[local_player_index] and never changed.
var ui_player: Player = null

# Index of the player that runs on this machine.
# 0 in hot-seat (all players are local); set from GameConfig.local_player_index in network mode.
var local_player_index: int = 0

# Final round tracking
var final_round_triggered: bool = false
var triggering_player: Player = null

# Setup tracking
var setup_round: int = 1       # 1, 2 = tile placement rounds; 3 = village placement
var setup_players_done: int = 0


# True when running in NETWORK mode (shorthand property)
var _is_network: bool:
	get: return GameConfig.initialized and GameConfig.mode == GameConfig.GameMode.NETWORK


func _ready() -> void:
	# Create active player view (signal bridge)
	active_player_view = ActivePlayerView.new()
	add_child(active_player_view)

	# Create and initialize managers
	tile_manager = TileManager.new()
	add_child(tile_manager)
	tile_manager.initialize(hex_tile_scene)
	tile_manager.max_stack_height = max_stack_height

	village_manager = VillageManager.new()
	add_child(village_manager)

	# Initialize tile pool — use shared seed in network mode for deterministic bag order
	tile_pool = TilePool.new()
	add_child(tile_pool)
	var tile_seed := -1
	if GameConfig.initialized and GameConfig.mode == GameConfig.GameMode.NETWORK:
		tile_seed = GameConfig.network_rng_seed
	tile_pool.initialize(tile_seed)
	tile_manager.tile_pool = tile_pool

	# Create N players — prefer GameConfig when coming from the main menu
	var count = clampi(GameConfig.player_count if GameConfig.initialized else player_count, 1, 4)
	for i in range(count):
		var player = Player.new()
		add_child(player)
		var starting_resources = Player.TEST_MODE_AMOUNT if test_mode else 0
		var starting_fervor = Player.TEST_MODE_AMOUNT if test_mode else 0
		var pname := GameConfig.player_names[i] if i < GameConfig.player_names.size() else "Player %d" % (i + 1)
		player.initialize(pname, starting_resources, starting_fervor)
		player.player_color = PLAYER_COLORS[i]
		player.test_mode = test_mode
		if test_mode:
			player.actions_remaining = Player.TEST_MODE_AMOUNT
			player.max_actions_this_turn = Player.TEST_MODE_AMOUNT
		players.append(player)

	# In network mode, record which player index belongs to this machine
	if GameConfig.initialized and GameConfig.mode == GameConfig.GameMode.NETWORK:
		local_player_index = clampi(GameConfig.local_player_index, 0, players.size() - 1)

	# Create and initialize turn manager
	turn_manager = TurnManager.new()
	add_child(turn_manager)
	turn_manager.initialize(village_manager, tile_manager, tile_pool, self)

	# Create god manager
	god_manager = GodManager.new()
	add_child(god_manager)

	# Connect turn manager signals
	turn_manager.phase_changed.connect(_on_phase_changed)
	turn_manager.turn_ended.connect(_on_turn_ended)
	turn_manager.setup_action_done.connect(_on_setup_action_done)

	# Cross-reference managers (for validation)
	tile_manager.village_manager = village_manager
	village_manager.tile_manager = tile_manager

	# Get camera reference (sibling in scene tree)
	var parent = get_parent()
	if not parent:
		Log.error("BoardManager: No parent node found! BoardManager must be a child of Main scene.")
		return

	camera = parent.get_node_or_null("Camera3D")
	if not camera:
		Log.error("BoardManager: Camera3D not found! Make sure a Camera3D node exists as a sibling of BoardManager.")
		return

	placement_controller = PlacementController.new()
	add_child(placement_controller)
	await placement_controller.initialize(tile_manager, village_manager, camera, self)

	# God selection: network shows local player's UI and waits for all choices via RPC;
	# hot-seat shows UI per player sequentially with taken-god greying.
	if _is_network:
		await _select_god_networked()
	else:
		var selected_so_far: Array[God] = []
		for player in players:
			await show_god_selection(player, selected_so_far)
			selected_so_far.append(player.god)

	# Deal both setup tiles to every player upfront (they choose which to place each round)
	for player in players:
		player.initialize_setup_tiles(tile_pool)

	Log.info("Tile pool count after setup deal: %d" % tile_pool.get_remaining_count())

	# Create persistent status header — lives through setup and gameplay phases.
	# Must be created before _switch_to_player(0) so bind() auto-seeds it via signal.
	var header_canvas = CanvasLayer.new()
	add_child(header_canvas)
	status_header = PlayerStatusHeader.new()
	status_header.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_canvas.add_child(status_header)
	status_header.initialize(self)
	# active_player_switched drives who-is-active display in the header.
	# Each player's stat signals are connected directly (not via APV) so the header updates
	# for all players in real-time regardless of whose turn it is or the network mode.
	active_player_switched.connect(status_header.on_player_changed)
	for i in range(players.size()):
		players[i].resources_changed.connect(status_header.on_resources_changed.bind(i))
		players[i].fervor_changed.connect(status_header.on_fervor_changed.bind(i))
		players[i].glory_changed.connect(status_header.on_glory_changed.bind(i))

	# Create "not your turn" lock overlay (hidden by default; shown in network mode on other players' turns)
	var overlay_canvas := CanvasLayer.new()
	overlay_canvas.layer = 10  # render above all other CanvasLayers
	add_child(overlay_canvas)
	not_your_turn_overlay = NotYourTurnOverlay.new()
	not_your_turn_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_canvas.add_child(not_your_turn_overlay)
	if OS.is_debug_build():
		not_your_turn_overlay.debug_end_turn_requested.connect(_on_debug_end_opponent_turn)

	# Connect network disconnect handler (no-op in hot-seat since signal never fires)
	NetworkManager.peer_disconnected.connect(_on_network_peer_disconnected)

	# Bind first player (main game UI not created yet — setup_ui() is called after setup)
	_switch_to_player(0)

	# active_player_switched drives setup_phase_ui and main game UI rebuilds on player change
	active_player_switched.connect(_on_active_player_changed)

	# Create the dedicated setup UI (replaces all setup hacks in tile_selector_ui)
	var setup_canvas_layer = CanvasLayer.new()
	add_child(setup_canvas_layer)
	setup_phase_ui = SetupPhaseUI.new()
	setup_phase_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	setup_canvas_layer.add_child(setup_phase_ui)
	setup_phase_ui.initialize(TileManager.TILE_TYPE_COLORS, god_manager, self)
	setup_phase_ui.setup_tile_selected.connect(_on_setup_tile_selected)

	# Network mode: bind APV stat signals to the local player once and permanently.
	# Hot-seat: _switch_to_player() already called bind() on players[0].
	if GameConfig.initialized and GameConfig.mode == GameConfig.GameMode.NETWORK:
		active_player_view.bind(players[local_player_index])

	# Manually push the first player since active_player_switched already fired before connection
	var is_my_turn := not _is_network or current_player_index == local_player_index
	setup_phase_ui.update_for_player(current_player, setup_round, is_my_turn)

	# Start setup phase (or skip it entirely in skip_setup mode)
	turn_manager.start_setup_phase()
	if skip_setup:
		call_deferred("_auto_complete_setup")


## Show god selection screen for a specific player, greying out already-taken gods.
## Returns after the player selects a god.
func show_god_selection(player: Player, taken_gods: Array[God]) -> void:
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)

	var god_selection_script = load("res://god_selection_ui.gd")
	var god_selection_ui = god_selection_script.new()
	god_selection_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Set data before add_child so _ready() picks them up
	god_selection_ui.selecting_player_name = player.player_name
	god_selection_ui.selecting_player_color = player.player_color
	god_selection_ui.taken_gods = taken_gods
	canvas_layer.add_child(god_selection_ui)

	var selected_god = await god_selection_ui.god_selected
	player.god = selected_god
	Log.info("%s selected: %s" % [player.player_name, selected_god.god_name])

	canvas_layer.queue_free()


## Skips the setup phase by auto-placing each player's tiles and village at spread-out
## positions, then immediately calls _complete_setup() to begin normal gameplay.
## Only used when skip_setup = true (editor testing convenience).
func _auto_complete_setup() -> void:
	Log.info("=== SETUP SKIPPED (auto-placing tiles) ===")
	# Well-spaced starting positions for up to 4 players
	const ORIGINS: Array[Vector2i] = [
		Vector2i( 0, -4),
		Vector2i(-4,  0),
		Vector2i( 4,  0),
		Vector2i( 0,  4),
	]
	for i in range(players.size()):
		var origin := ORIGINS[i % ORIGINS.size()]
		var player := players[i]
		for j in range(player.setup_tiles.size()):
			var td = player.setup_tiles[j]
			if td == null:
				continue
			var pos := Vector2i(origin.x + j, origin.y)
			tile_manager.place_tile(pos.x, pos.y, td.tile_type, td.resource_type,
					td.yield_value, td.village_building_cost, td.sell_price)
			player.setup_tile_positions.append(pos)
		# Place a free village on the first tile
		if not player.setup_tile_positions.is_empty():
			var vpos := player.setup_tile_positions[0]
			village_manager.place_village(vpos.x, vpos.y, player)
	_complete_setup()


## Network god selection: sequential, one player at a time (mirrors hot-seat flow).
## On our turn we show the interactive UI; on others' turns we show a waiting overlay
## and block until their RPC arrives.
func _select_god_networked() -> void:
	var taken: Array[God] = []
	for i in range(players.size()):
		if i == local_player_index:
			# Our turn: interactive selection, then broadcast the choice
			await show_god_selection(players[i], taken)
			var all_gods := GodManager.create_all_gods()
			var chosen_index := 0
			for j in range(all_gods.size()):
				if all_gods[j].god_name == players[i].god.god_name:
					chosen_index = j
					break
			Log.info("Player %d selected god: %s" % [i + 1, players[i].god.god_name])
			rpc("_rpc_god_selected", i, chosen_index)
		else:
			# Their turn: show god selection as read-only backdrop, block until RPC arrives
			var waiting_canvas := _show_god_waiting_ui(players[i], taken)
			await _god_choice_received
			waiting_canvas.queue_free()
		taken.append(players[i].god)


## Shows the god selection screen as a read-only backdrop for spectating players,
## with a transparent input-blocking overlay and a "waiting" banner at the bottom.
## Returns the CanvasLayer so the caller can free it when the choice arrives.
func _show_god_waiting_ui(picking_player: Player, taken: Array[God]) -> CanvasLayer:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	# Show the god selection cards so all players can see what's available
	var god_selection_script = load("res://god_selection_ui.gd")
	var spectator_ui = god_selection_script.new()
	spectator_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	spectator_ui.selecting_player_name = picking_player.player_name
	spectator_ui.selecting_player_color = picking_player.player_color
	spectator_ui.taken_gods = taken
	canvas.add_child(spectator_ui)
	# Safety: discard any click that somehow slips through the overlay
	spectator_ui.god_selected.connect(func(_g: God) -> void: pass)

	# Transparent overlay blocks all mouse input so cards can't be clicked
	var blocker := ColorRect.new()
	blocker.color = Color(0, 0, 0, 0.25)
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(blocker)

	# Centered banner floating over the cards
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(center)

	var banner := PanelContainer.new()
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color(0.05, 0.05, 0.1, 0.88)
	banner_style.border_color = picking_player.player_color
	banner_style.border_width_left = 2
	banner_style.border_width_right = 2
	banner_style.border_width_top = 2
	banner_style.border_width_bottom = 2
	banner_style.set_corner_radius_all(12)
	banner_style.content_margin_left = 48
	banner_style.content_margin_right = 48
	banner_style.content_margin_top = 20
	banner_style.content_margin_bottom = 20
	banner.add_theme_stylebox_override("panel", banner_style)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(banner)

	var msg := Label.new()
	msg.text = "%s is choosing their god…" % picking_player.player_name
	msg.add_theme_font_size_override("font_size", 32)
	msg.add_theme_color_override("font_color", picking_player.player_color)
	msg.add_theme_color_override("font_outline_color", Color.BLACK)
	msg.add_theme_constant_override("outline_size", 3)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(msg)

	return canvas


## Switch the active player to the given index.
## Updates current_player, turn_manager, power_executor, and (in hot-seat) the APV signal bridge.
## In network mode APV stays permanently bound to the local player; only active_player_switched fires.
func _switch_to_player(index: int) -> void:
	current_player_index = index
	current_player = players[index]
	turn_manager.current_player = current_player
	if power_executor:
		power_executor.current_player = current_player

	var is_network: bool = GameConfig.initialized and GameConfig.mode == GameConfig.GameMode.NETWORK
	if not is_network:
		# Hot-seat: rebind APV so its stat signals track the new player and seed the UI
		active_player_view.bind(current_player)
		ui_player = current_player
	else:
		ui_player = players[local_player_index]

	# Always notify status header and setup_phase_ui / game UI about the active player change
	active_player_switched.emit(current_player)

	# Show or hide the lock overlay based on whose turn it is
	if not_your_turn_overlay:
		if is_network and index != local_player_index:
			not_your_turn_overlay.show_for_player(current_player)
		else:
			not_your_turn_overlay.hide_overlay()


## Called by active_player_view.player_changed → rebuilds player-specific UI sections.
func _on_active_player_changed(player: Player) -> void:
	if setup_phase_ui != null:
		# During setup: delegate entirely to the dedicated setup UI
		var is_my_turn := not _is_network or current_player_index == local_player_index
		setup_phase_ui.update_for_player(player, setup_round, is_my_turn)
		return

	# Gameplay: update main game UI
	if ui:
		ui.update_current_player(player)
		if ui_player.god:
			ui.update_god_display(ui_player.god, god_manager)
		ui.update_hand_display()
		ui.set_actions_interactive(ui_player == current_player)


func setup_ui() -> void:
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)

	var ui_script = load("res://tile_selector_ui.gd")
	ui = ui_script.new()
	canvas_layer.add_child(ui)
	ui.initialize(TileManager.TILE_TYPE_COLORS, self)

	# Connect UI signals to placement controller
	ui.tile_type_selected.connect(placement_controller.select_tile_type)
	ui.tile_selected_from_hand.connect(_on_tile_selected_from_hand)
	ui.tile_sold_from_hand.connect(sell_tile)
	ui.village_place_selected.connect(placement_controller.select_village_place_mode)
	ui.village_remove_selected.connect(placement_controller.select_village_remove_mode)

	# Connect active_player_view signals to UI (once — never rewired on player switch)
	# Note: player_changed is connected once in _ready() and routes to setup_phase_ui or ui
	active_player_view.resources_changed.connect(ui.update_resources)
	active_player_view.fervor_changed.connect(ui.update_fervor)
	active_player_view.glory_changed.connect(ui.update_glory)
	active_player_view.actions_changed.connect(ui.update_actions)

	# Set UI reference in turn_manager
	turn_manager.set_ui(ui)

	# Re-bind APV so freshly-connected UI stat signals fire immediately with current values.
	# Network mode: always bind to local player (UI always shows local player's stats).
	# Hot-seat: bind to current_player (active player owns the UI this turn).
	var _is_network: bool = GameConfig.initialized and GameConfig.mode == GameConfig.GameMode.NETWORK
	if _is_network:
		active_player_view.bind(players[local_player_index])
	else:
		active_player_view.bind(current_player)

	# Seed player-specific displays.
	# active_player_switched already fired during _switch_to_player(0) in _complete_setup(),
	# but ui was null at that point so _on_active_player_changed() skipped the god/player update.
	ui.update_current_player(current_player)
	if ui_player.god:
		ui.update_god_display(ui_player.god, god_manager)
	ui.update_hand_display()
	ui.set_actions_interactive(ui_player == current_player)
	ui.update_turn_phase(turn_manager.current_phase)

	power_executor = PowerExecutor.new()
	add_child(power_executor)
	power_executor.initialize(current_player, tile_manager, village_manager, god_manager, placement_controller, ui, self)
	power_executor.power_executed.connect(_on_power_executed)


## Handle setup tile selection during setup phase
func _on_setup_tile_selected(setup_index: int) -> void:
	if setup_index < 0 or setup_index >= current_player.setup_tiles.size():
		return

	var tile_def = current_player.setup_tiles[setup_index]
	if tile_def == null:
		Log.warn("No setup tile in this slot!")
		return

	Log.debug("Selected setup tile %d: %s %s (yield=%d, village_cost=%d)" % [
		setup_index + 1,
		TileManager.TileType.keys()[tile_def.tile_type],
		TileManager.ResourceType.keys()[tile_def.resource_type],
		tile_def.yield_value,
		tile_def.village_building_cost
	])

	placement_controller.select_tile_from_hand(setup_index, tile_def)


## Handle tile selection from hand
func _on_tile_selected_from_hand(hand_index: int) -> void:
	if hand_index < 0 or hand_index >= current_player.HAND_SIZE:
		return

	var tile_def = current_player.hand[hand_index]
	if tile_def == null:
		Log.warn("No tile in this slot!")
		return

	# Can only place tiles during actions phase
	if not turn_manager.is_actions_phase():
		Log.warn("Can only place tiles during actions phase!")
		return

	# Check if player has actions remaining
	if current_player.actions_remaining <= 0:
		Log.warn("No actions remaining to place tile!")
		return

	Log.debug("Selected tile from hand: %s %s (yield=%d, village_cost=%d)" % [
		TileManager.TileType.keys()[tile_def.tile_type],
		TileManager.ResourceType.keys()[tile_def.resource_type],
		tile_def.yield_value,
		tile_def.village_building_cost
	])

	placement_controller.select_tile_from_hand(hand_index, tile_def)


## Called by TilePlacementStrategy (gameplay path) after placing a tile.
## q, r are the hex coords of the placement for network broadcasting.
func on_tile_placed_from_hand(hand_index: int, q: int, r: int) -> void:
	if hand_index < 0 or hand_index >= current_player.HAND_SIZE:
		return

	var placed_tile = current_player.hand[hand_index]
	if placed_tile == null:
		Log.warn("BoardManager: No tile in hand slot %d" % hand_index)
		return

	# Validate phase - can only place tiles during actions phase (setup uses different flow)
	if not turn_manager.is_actions_phase():
		Log.warn("BoardManager: Cannot place tile outside actions phase")
		return

	# Consume action
	if not turn_manager.consume_action("place tile"):
		Log.error("BoardManager: consume_action failed despite passing phase/action checks")
		return

	Log.info("Placed tile from hand: %s %s" % [
		TileManager.TileType.keys()[placed_tile.tile_type],
		TileManager.ResourceType.keys()[placed_tile.resource_type]
	])

	current_player.remove_from_hand(hand_index)

	if ui:
		ui.update_hand_display()

	if _is_network:
		rpc("_rpc_place_tile", hand_index, q, r)


## Sell a tile from hand for resources
func sell_tile(hand_index: int) -> void:
	if hand_index < 0 or hand_index >= current_player.HAND_SIZE:
		Log.error("BoardManager: Invalid hand index for selling: %d" % hand_index)
		return

	var tile = current_player.hand[hand_index]
	if tile == null:
		Log.warn("BoardManager: No tile in hand slot %d to sell" % hand_index)
		return

	# Check if tile can be sold (Glory tiles have sell_price = 0)
	if tile.sell_price <= 0:
		Log.warn("BoardManager: Cannot sell Glory tile")
		return

	# Consume 1 action (validates phase and action count)
	if not turn_manager.consume_action("sell tile"):
		return

	match tile.resource_type:
		TileManager.ResourceType.FERVOR:
			current_player.add_fervor(tile.sell_price)
		_:
			current_player.add_resources(tile.sell_price)

	Log.info("Sold %s %s tile for %d %s" % [
		TileManager.ResourceType.keys()[tile.resource_type],
		TileManager.TileType.keys()[tile.tile_type],
		tile.sell_price,
		TileManager.ResourceType.keys()[tile.resource_type].to_lower()
	])

	current_player.remove_from_hand(hand_index)

	# Cancel placement mode if this tile was selected for placement
	if placement_controller and placement_controller.selected_hand_index == hand_index:
		placement_controller.cancel_placement()

	if ui:
		ui.update_hand_display()

	if _is_network:
		rpc("_rpc_sell_tile", hand_index)


## Called when player attempts to place a village
func on_village_placed(q: int, r: int) -> bool:
	var tile = tile_manager.get_tile_at(q, r)
	if not tile:
		Log.error("BoardManager: No tile at (%d,%d) for village placement" % [q, r])
		return false

	var cost = current_player.get_village_cost(tile.village_building_cost)

	if current_player.resources < cost:
		Log.warn("BoardManager: Cannot afford village — need %d, have %d" % [cost, current_player.resources])
		return false

	if not turn_manager.consume_action("build village"):
		return false

	var success = village_manager.place_village(q, r, current_player)
	if not success:
		return false

	if not current_player.spend_resources(cost):
		Log.error("BoardManager: spend_resources failed after affordability check passed — rolling back")
		village_manager.remove_village(q, r)
		return false

	Log.info("Built village for %d resources" % cost)

	if _is_network:
		rpc("_rpc_place_village", q, r)

	return true


## Called when player attempts to remove/sell a village
func on_village_removed(q: int, r: int) -> bool:
	var village = village_manager.get_village_at(q, r)
	if not village:
		Log.warn("BoardManager: No village at (%d,%d) to remove" % [q, r])
		return false

	if village.player_owner != current_player:
		Log.warn("BoardManager: Cannot remove another player's village")
		return false

	var tile = tile_manager.get_tile_at(q, r)
	if not tile:
		Log.error("BoardManager: Village exists at (%d,%d) but no tile found" % [q, r])
		return false

	var building_cost: int = current_player.get_village_cost(tile.village_building_cost)
	var refund: int = int(building_cost / 2.0)

	if not turn_manager.consume_action("remove village"):
		return false

	var success = village_manager.remove_village(q, r)
	if not success:
		return false

	current_player.add_resources(refund)
	Log.info("Removed village, received %d resources refund" % refund)

	if _is_network:
		rpc("_rpc_remove_village", q, r)

	return true


# ==================== SETUP FLOW ====================

## Called each time a setup action completes (tile placed in rounds 1/2, or village in round 3).
## Advances to the next player or the next setup round.
func _on_setup_action_done() -> void:
	setup_players_done += 1

	if setup_players_done >= players.size():
		# All players done with this round — advance
		setup_players_done = 0
		setup_round += 1

		if setup_round <= 2:
			# Start next tile-placement round from player 0 (tiles already in hand)
			_switch_to_player(0)
		elif setup_round == 3:
			# Village placement round — start from player 0
			_switch_to_player(0)
			_start_setup_village_for_player()
		else:
			# All 3 rounds done
			_complete_setup()
	else:
		# More players in this round
		var next_index = (current_player_index + 1) % players.size()
		_switch_to_player(next_index)
		if setup_round == 3:
			_start_setup_village_for_player()
		# setup_round <= 2: _on_active_player_changed() updates setup_phase_ui automatically


## Enter setup village placement mode for the current player.
## The setup_phase_ui already shows the round 3 prompt via _on_active_player_changed().
## In network mode, only the local machine enters placement mode when it is their turn.
func _start_setup_village_for_player() -> void:
	if _is_network and current_player_index != local_player_index:
		return
	placement_controller.select_setup_village_mode()
	Log.info("%s: Place your village on one of your tiles" % current_player.player_name)


## Called when all 3 setup rounds are done. Draws starting hands and begins play.
func _complete_setup() -> void:
	Log.info("=== SETUP COMPLETE ===")

	# Destroy the dedicated setup UI — main game UI is created next
	if setup_phase_ui:
		setup_phase_ui.get_parent().queue_free()  # frees CanvasLayer + SetupPhaseUI
		setup_phase_ui = null

	for player in players:
		player.refresh_hand(tile_pool)

	_switch_to_player(0)
	setup_ui()  # Creates tile_selector_ui, connects APV → UI signals, creates power_executor
	turn_manager.begin_player_turn()


# ==================== TURN FLOW ====================

## Called when turn phase changes (e.g., HARVEST -> ACTIONS)
func _on_phase_changed(_new_phase: int) -> void:
	placement_controller.cancel_placement()


## Called when current player ends their turn.
## Handles final round detection, player switching, and starting the next turn.
func _on_turn_ended() -> void:
	placement_controller.cancel_placement()

	# Check if tile pool just became empty — trigger final round
	if tile_pool.is_empty() and not final_round_triggered:
		final_round_triggered = true
		triggering_player = current_player
		Log.info("=== FINAL ROUND TRIGGERED by %s ===" % current_player.player_name)
		if ui:
			ui.show_final_round_notification()

	var next_index = (current_player_index + 1) % players.size()

	# If the next player is the one who triggered the final round, game ends
	if final_round_triggered and players[next_index] == triggering_player:
		_trigger_game_end()
		return

	_switch_to_player(next_index)
	turn_manager.begin_player_turn()
	if ui:
		ui.update_hand_display()


## Debug only: skip the opponent's current action (setup or normal turn) without them doing anything.
## Called by the NotYourTurnOverlay debug button for single-machine stub testing.
func _on_debug_end_opponent_turn() -> void:
	Log.info("Debug overlay: skipping action for %s" % current_player.player_name)
	# Cancel any placement mode the opponent may have entered (tile selected but not placed,
	# or village placement mode in setup round 3).  Must happen before advancing the turn so
	# the new active player starts with a clean placement state.
	placement_controller.cancel_placement()
	if turn_manager.is_setup_phase():
		# Advance past this player's setup slot without placing a tile/village.
		# The tile stays unplaced in setup_tiles (minor board gap — acceptable for a debug stub).
		turn_manager.setup_action_done.emit()
	else:
		turn_manager.end_turn()


## Called by TilePlacementStrategy (setup path).
## Records position and notifies turn_manager; broadcasts in network mode.
func on_setup_tile_placed(setup_index: int, q: int, r: int) -> void:
	current_player.setup_tile_positions.append(Vector2i(q, r))
	turn_manager.on_setup_tile_placed(setup_index)
	# turn_manager.on_setup_tile_placed already emits setup_action_done
	if _is_network:
		rpc("_rpc_setup_tile_placed", setup_index, q, r)


## Called by SetupVillagePlaceStrategy (setup Round 3).
## Notifies turn_manager; broadcasts in network mode.
func on_setup_village_placed(q: int, r: int) -> void:
	turn_manager.on_setup_village_placed()
	# turn_manager.on_setup_village_placed already emits setup_action_done
	if _is_network:
		rpc("_rpc_setup_village_placed", q, r)


## Called by tile_selector_ui when the player chooses a harvest type.
func on_harvest_selected(resource_type: int) -> void:
	turn_manager.harvest(resource_type)
	if _is_network:
		rpc("_rpc_harvest", resource_type)


## Called by tile_selector_ui when the player presses End Turn.
func on_end_turn_requested() -> void:
	turn_manager.end_turn()
	if _is_network:
		rpc("_rpc_end_turn")


## Called by tile_selector_ui._on_power_activated.
## Executes the power locally and broadcasts instant powers to remote peers.
func on_power_activated(power: GodPower, player: Player) -> void:
	var success := god_manager.activate_power(power, player, self)
	if not success:
		return
	# Targeted (deferred) powers broadcast via power_executor.power_executed signal.
	# Instant powers (no target selection) broadcast here.
	if _is_network:
		match power.power_type:
			GodPower.PowerType.EXTRA_ACTION, GodPower.PowerType.SECOND_HARVEST:
				rpc("_rpc_power_instant", power.power_type)


## Connected to power_executor.power_executed — broadcasts targeted power results to remotes.
func _on_power_executed(power_type: int, q: int, r: int, extra: int) -> void:
	# Only broadcast if this is the local player's turn (prevents re-broadcast on remotes)
	if _is_network and current_player_index == local_player_index:
		rpc("_rpc_power_target", power_type, q, r, extra)


## Called when a remote peer disconnects during a game session.
func _on_network_peer_disconnected(_id: int) -> void:
	Log.warn("Network: A peer disconnected — returning to main menu")
	NetworkManager.disconnect_network()
	get_tree().change_scene_to_file("res://main_menu.tscn")


## Validates that an incoming RPC comes from the peer whose turn it currently is.
func _validate_rpc_sender() -> bool:
	var sender_id := multiplayer.get_remote_sender_id()
	var sender_player := NetworkManager.get_player_index(sender_id)
	if sender_player != current_player_index:
		push_warning("RPC from wrong player (got player %d, expected player %d)" % [sender_player, current_player_index])
		return false
	return true


# ==================== RPC HANDLERS ====================

@rpc("any_peer", "call_remote", "reliable")
func _rpc_god_selected(player_index: int, god_index: int) -> void:
	var all_gods := GodManager.create_all_gods()
	players[player_index].god = all_gods[god_index % all_gods.size()]
	Log.info("Player %d selected god: %s" % [player_index + 1, players[player_index].god.god_name])
	_god_choice_received.emit()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_setup_tile_placed(setup_index: int, q: int, r: int) -> void:
	if not _validate_rpc_sender(): return
	var td = current_player.setup_tiles[setup_index]
	if td == null:
		push_warning("_rpc_setup_tile_placed: setup_tiles[%d] is null" % setup_index)
		return
	tile_manager.place_tile(q, r, td.tile_type, td.resource_type, td.yield_value, td.village_building_cost, td.sell_price)
	current_player.setup_tile_positions.append(Vector2i(q, r))
	turn_manager.on_setup_tile_placed(setup_index)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_setup_village_placed(q: int, r: int) -> void:
	if not _validate_rpc_sender(): return
	village_manager.place_village(q, r, current_player)
	turn_manager.on_setup_village_placed()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_place_tile(hand_index: int, q: int, r: int) -> void:
	if not _validate_rpc_sender(): return
	var td = current_player.hand[hand_index]
	if td == null:
		push_warning("_rpc_place_tile: hand[%d] is null" % hand_index)
		return
	tile_manager.place_tile(q, r, td.tile_type, td.resource_type, td.yield_value, td.village_building_cost, td.sell_price)
	current_player.remove_from_hand(hand_index)
	turn_manager.consume_action("place tile")
	if ui:
		ui.update_hand_display()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_sell_tile(hand_index: int) -> void:
	if not _validate_rpc_sender(): return
	var tile = current_player.hand[hand_index]
	if tile == null:
		push_warning("_rpc_sell_tile: hand[%d] is null" % hand_index)
		return
	turn_manager.consume_action("sell tile")
	match tile.resource_type:
		TileManager.ResourceType.FERVOR:
			current_player.add_fervor(tile.sell_price)
		_:
			current_player.add_resources(tile.sell_price)
	current_player.remove_from_hand(hand_index)
	if ui:
		ui.update_hand_display()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_place_village(q: int, r: int) -> void:
	if not _validate_rpc_sender(): return
	var tile = tile_manager.get_tile_at(q, r)
	if not tile:
		push_warning("_rpc_place_village: no tile at (%d,%d)" % [q, r])
		return
	var cost := current_player.get_village_cost(tile.village_building_cost)
	village_manager.place_village(q, r, current_player)
	current_player.spend_resources(cost)
	turn_manager.consume_action("build village")


@rpc("any_peer", "call_remote", "reliable")
func _rpc_remove_village(q: int, r: int) -> void:
	if not _validate_rpc_sender(): return
	var tile = tile_manager.get_tile_at(q, r)
	if not tile:
		push_warning("_rpc_remove_village: no tile at (%d,%d)" % [q, r])
		return
	var building_cost := current_player.get_village_cost(tile.village_building_cost)
	var refund := int(building_cost / 2.0)
	village_manager.remove_village(q, r)
	current_player.add_resources(refund)
	turn_manager.consume_action("remove village")


@rpc("any_peer", "call_remote", "reliable")
func _rpc_harvest(resource_type: int) -> void:
	if not _validate_rpc_sender(): return
	turn_manager.harvest(resource_type)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_end_turn() -> void:
	if not _validate_rpc_sender(): return
	turn_manager.end_turn()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_power_instant(power_type: int) -> void:
	if not _validate_rpc_sender(): return
	var power := god_manager.get_power_by_type(current_player, power_type)
	if not power:
		push_warning("_rpc_power_instant: power type %d not found for player" % power_type)
		return
	# Apply bookkeeping without UI side effects
	if power.fervor_cost > 0:
		current_player.spend_fervor(power.fervor_cost)
	match power_type:
		GodPower.PowerType.EXTRA_ACTION:
			current_player.consume_action()
			current_player.next_turn_bonus_actions = 1
		GodPower.PowerType.SECOND_HARVEST:
			pass  # Free action; actual harvest type arrives via _rpc_harvest
	current_player.mark_power_used(power_type)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_power_target(power_type: int, q: int, r: int, extra: int) -> void:
	if not _validate_rpc_sender(): return
	# Set pending_power so power_executor.complete_deferred_power() can finalize it
	current_player.pending_power = god_manager.get_power_by_type(current_player, power_type)
	match power_type:
		GodPower.PowerType.UPGRADE_TILE_KEEP_VILLAGE:
			power_executor.on_upgrade_tile(q, r)
		GodPower.PowerType.DOWNGRADE_TILE_KEEP_VILLAGE:
			power_executor.on_downgrade_tile(q, r)
		GodPower.PowerType.STEAL_HARVEST:
			power_executor.on_steal_harvest(q, r)
		GodPower.PowerType.DESTROY_VILLAGE_FREE:
			power_executor.on_destroy_village_free(q, r)
		GodPower.PowerType.CHANGE_TILE_TYPE:
			power_executor.on_change_tile_type(q, r, extra)
		_:
			push_warning("_rpc_power_target: unknown power type %d" % power_type)
			current_player.pending_power = null


## Calculates scores for all players and shows the victory screen.
func _trigger_game_end() -> void:
	Log.info("=== GAME OVER ===")
	if status_header:
		status_header.visible = false
	if not_your_turn_overlay:
		not_your_turn_overlay.hide_overlay()

	var victory_mgr = VictoryManager.new()
	var results = []
	for player in players:
		results.append({
			"player": player,
			"scores": victory_mgr.calculate_player_score(player, village_manager, tile_manager)
		})

	if ui:
		ui.show_victory_screen(results)
