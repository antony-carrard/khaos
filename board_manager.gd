extends Node3D

# Hexagonal grid orchestrator
# Reference: https://www.redblobgames.com/grids/hexagons/

# Configuration
@export var hex_tile_scene: PackedScene = preload("res://hex_tile.tscn")
@export var max_stack_height: int = 3  # Maximum tiles that can be stacked
@export var test_mode: bool = false  # Test mode: unlimited resources/actions for testing
@export var player_count: int = 2    # Number of players (1–4)

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

# Final round tracking
var final_round_triggered: bool = false
var triggering_player: Player = null

# Setup tracking
var setup_round: int = 1       # 1, 2 = tile placement rounds; 3 = village placement
var setup_players_done: int = 0


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

	# Initialize tile pool
	tile_pool = TilePool.new()
	add_child(tile_pool)
	tile_pool.initialize()
	tile_manager.tile_pool = tile_pool

	# Create N players — prefer GameConfig when coming from the main menu
	var count = clampi(GameConfig.player_count if GameConfig.initialized else player_count, 1, 4)
	for i in range(count):
		var player = Player.new()
		add_child(player)
		var starting_resources = 999 if test_mode else 0
		var starting_fervor = 999 if test_mode else 0
		player.initialize("Player %d" % (i + 1), starting_resources, starting_fervor)
		player.player_color = PLAYER_COLORS[i]
		if test_mode:
			player.set_actions(999)
		players.append(player)

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

	# God selection for each player (in order; later players can't pick taken gods)
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
	active_player_view.player_changed.connect(status_header.on_player_changed)
	active_player_view.resources_changed.connect(status_header.on_active_resources_changed)
	active_player_view.fervor_changed.connect(status_header.on_active_fervor_changed)
	active_player_view.glory_changed.connect(status_header.on_active_glory_changed)

	# Bind first player (main game UI not created yet — setup_ui() is called after setup)
	_switch_to_player(0)

	# Connect player_changed once here so both setup and gameplay phases are covered
	active_player_view.player_changed.connect(_on_active_player_changed)

	# Create the dedicated setup UI (replaces all setup hacks in tile_selector_ui)
	var setup_canvas_layer = CanvasLayer.new()
	add_child(setup_canvas_layer)
	setup_phase_ui = SetupPhaseUI.new()
	setup_phase_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	setup_canvas_layer.add_child(setup_phase_ui)
	setup_phase_ui.initialize(TileManager.TILE_TYPE_COLORS, god_manager, self)
	setup_phase_ui.setup_tile_selected.connect(_on_setup_tile_selected)
	# Manually push the first player since player_changed already fired before connection
	setup_phase_ui.update_for_player(current_player, setup_round)

	# Start setup phase
	turn_manager.start_setup_phase()


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


## Switch the active player to the given index.
## Updates current_player, turn_manager, power_executor, and the active_player_view signal bridge.
func _switch_to_player(index: int) -> void:
	current_player_index = index
	current_player = players[index]
	turn_manager.current_player = current_player
	if power_executor:
		power_executor.current_player = current_player
	active_player_view.bind(current_player)


## Called by active_player_view.player_changed → rebuilds player-specific UI sections.
func _on_active_player_changed(player: Player) -> void:
	if setup_phase_ui != null:
		# During setup: delegate entirely to the dedicated setup UI
		setup_phase_ui.update_for_player(player, setup_round)
		return

	# Gameplay: update main game UI
	if ui:
		ui.update_current_player(player)
		if player.god:
			ui.update_god_display(player.god, god_manager)
		ui.update_hand_display()


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

	# Re-bind active_player_view so freshly-connected UI signals fire immediately
	active_player_view.bind(current_player)

	# Update initial display
	ui.update_hand_display()
	ui.update_turn_phase(turn_manager.current_phase)

	power_executor = PowerExecutor.new()
	add_child(power_executor)
	power_executor.initialize(current_player, tile_manager, village_manager, god_manager, placement_controller, ui, self)


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


## Called by placement_controller when a tile from hand is successfully placed
func on_tile_placed_from_hand(hand_index: int) -> void:
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
func _start_setup_village_for_player() -> void:
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


## Calculates scores for all players and shows the victory screen.
func _trigger_game_end() -> void:
	Log.info("=== GAME OVER ===")
	if status_header:
		status_header.visible = false

	var victory_mgr = VictoryManager.new()
	var results = []
	for player in players:
		results.append({
			"player": player,
			"scores": victory_mgr.calculate_player_score(player, village_manager, tile_manager)
		})

	if ui:
		ui.show_victory_screen(results)
