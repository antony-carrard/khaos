extends Node3D

# Hexagonal grid orchestrator
# Reference: https://www.redblobgames.com/grids/hexagons/

# Configuration
@export var hex_tile_scene: PackedScene = preload("res://hex_tile.tscn")
@export var max_stack_height: int = 3  # Maximum tiles that can be stacked
@export var test_mode: bool = false   # Unlimited resources/actions every turn for testing
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
var ui: Control = null

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
	turn_manager.initialize(village_manager, tile_manager, tile_pool)

	# Create god manager
	god_manager = GodManager.new()
	add_child(god_manager)

	turn_manager.turn_ended.connect(_on_turn_ended)

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

	# Deal starting hands to all players
	for player in players:
		player.refresh_hand(tile_pool)

	# Create persistent status header
	var header_canvas = CanvasLayer.new()
	add_child(header_canvas)
	status_header = PlayerStatusHeader.new()
	status_header.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_canvas.add_child(status_header)
	status_header.initialize(self)
	active_player_switched.connect(status_header.on_player_changed)
	for i in range(players.size()):
		players[i].resources_changed.connect(status_header.on_resources_changed.bind(i))
		players[i].fervor_changed.connect(status_header.on_fervor_changed.bind(i))
		players[i].glory_changed.connect(status_header.on_glory_changed.bind(i))

	# Create "not your turn" lock overlay (hidden by default; shown in network mode on other players' turns)
	var overlay_canvas := CanvasLayer.new()
	overlay_canvas.layer = 10
	add_child(overlay_canvas)
	not_your_turn_overlay = NotYourTurnOverlay.new()
	not_your_turn_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_canvas.add_child(not_your_turn_overlay)
	if OS.is_debug_build():
		not_your_turn_overlay.debug_end_turn_requested.connect(_on_debug_end_opponent_turn)

	# Connect network disconnect handler (no-op in hot-seat since signal never fires)
	NetworkManager.peer_disconnected.connect(_on_network_peer_disconnected)

	_switch_to_player(0)

	active_player_switched.connect(_on_active_player_changed)

	# Network mode: bind APV stat signals to the local player once and permanently.
	if GameConfig.initialized and GameConfig.mode == GameConfig.GameMode.NETWORK:
		active_player_view.bind(players[local_player_index])

	setup_ui()
	turn_manager.begin_player_turn()


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

	active_player_switched.emit(current_player)

	# Show or hide the lock overlay based on whose turn it is
	if not_your_turn_overlay:
		if is_network and index != local_player_index:
			not_your_turn_overlay.show_for_player(current_player)
		else:
			not_your_turn_overlay.hide_overlay()


## Called by active_player_switched → rebuilds player-specific UI sections.
func _on_active_player_changed(player: Player) -> void:
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
	ui.village_place_selected.connect(placement_controller.select_village_place_mode)
	ui.village_remove_selected.connect(placement_controller.select_village_remove_mode)

	# Connect active_player_view signals to UI (once — never rewired on player switch)
	active_player_view.resources_changed.connect(ui.update_resources)
	active_player_view.fervor_changed.connect(ui.update_fervor)
	active_player_view.glory_changed.connect(ui.update_glory)
	active_player_view.actions_changed.connect(ui.update_actions)

	# Re-bind APV so freshly-connected UI stat signals fire immediately with current values.
	# Network mode: always bind to local player (UI always shows local player's stats).
	# Hot-seat: bind to current_player (active player owns the UI this turn).
	var _is_network: bool = GameConfig.initialized and GameConfig.mode == GameConfig.GameMode.NETWORK
	if _is_network:
		active_player_view.bind(players[local_player_index])
	else:
		active_player_view.bind(current_player)

	ui.update_current_player(current_player)
	if ui_player.god:
		ui.update_god_display(ui_player.god, god_manager)
	ui.update_hand_display()
	ui.set_actions_interactive(ui_player == current_player)

	power_executor = PowerExecutor.new()
	add_child(power_executor)
	power_executor.initialize(current_player, tile_manager, village_manager, god_manager, placement_controller, ui, self)
	power_executor.power_executed.connect(_on_power_executed)



## Handle tile selection from hand
func _on_tile_selected_from_hand(hand_index: int) -> void:
	if hand_index < 0 or hand_index >= current_player.HAND_SIZE:
		return

	var tile_def = current_player.hand[hand_index]
	if tile_def == null:
		Log.warn("No tile in this slot!")
		return

	# Check if player has actions remaining
	if current_player.actions_remaining <= 0:
		Log.warn("No actions remaining to place tile!")
		return

	Log.debug("Selected tile from hand: %s yields=%s (village_cost=%d)" % [
		TileDefinition.TileType.keys()[tile_def.tile_type],
		TileDefinition.format_yields(tile_def.yields),
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

	# Consume action
	if not turn_manager.consume_action("place tile"):
		Log.error("BoardManager: consume_action failed despite passing phase/action checks")
		return

	Log.info("Placed tile from hand: %s yields=%s" % [
		TileDefinition.TileType.keys()[placed_tile.tile_type],
		TileDefinition.format_yields(placed_tile.yields)
	])

	_grant_placement_bounty(current_player, placed_tile.yields)
	current_player.remove_from_hand(hand_index)

	if ui:
		ui.update_hand_display()

	if _is_network:
		rpc("_rpc_place_tile", hand_index, q, r)



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

	var glory = tile.height_level + 1
	current_player.add_glory(glory)
	Log.info("Built village for %d resources, gained %d glory" % [cost, glory])

	if _is_network:
		rpc("_rpc_place_village", q, r)

	return true


## Returns the highest height_level of an adjacent own village, or -1 if none.
func get_best_adjacent_own_height(q: int, r: int) -> int:
	var best := -1
	for neighbor in HexGridUtils.get_axial_neighbors(q, r):
		var own_village := village_manager.get_village_at(neighbor.x, neighbor.y)
		if not own_village or own_village.player_owner != current_player:
			continue
		var own_tile := tile_manager.get_tile_at(neighbor.x, neighbor.y)
		if own_tile and own_tile.height_level > best:
			best = own_tile.height_level
	return best


## Resource cost to demolish an enemy village. Base: enemy_height+2. Surcharge if attacking from below.
func get_demolition_resources_cost(enemy_height: int, best_own_height: int) -> int:
	var surcharge: int = max(0, enemy_height - best_own_height)
	return (enemy_height + 2) + surcharge


## Action cost to demolish an enemy village. Base: 1. Surcharge if attacking from below.
func get_demolition_action_cost(enemy_height: int, best_own_height: int) -> int:
	var surcharge: int = max(0, enemy_height - best_own_height)
	return 1 + surcharge


## Returns true if the current player can legally destroy the enemy village at (q, r).
## Requires an adjacent own village. Cost scales with tile height and height disadvantage.
func can_destroy_enemy_village(q: int, r: int) -> bool:
	var enemy_village := village_manager.get_village_at(q, r)
	if not enemy_village or enemy_village.player_owner == current_player:
		return false
	var enemy_tile := tile_manager.get_tile_at(q, r)
	if not enemy_tile:
		return false
	var best_own_height := get_best_adjacent_own_height(q, r)
	if best_own_height < 0:
		return false
	var res_cost := get_demolition_resources_cost(enemy_tile.height_level, best_own_height)
	var act_cost := get_demolition_action_cost(enemy_tile.height_level, best_own_height)
	if current_player.resources < res_cost:
		return false
	if current_player.actions_remaining < act_cost:
		return false
	return true


## Called when player attempts to remove/sell a village.
## Own village: costs 1 action, free (no resource cost or refund).
## Enemy village: requires adjacent own village; costs resources + actions per rules.
func on_village_removed(q: int, r: int) -> bool:
	var village = village_manager.get_village_at(q, r)
	if not village:
		Log.warn("BoardManager: No village at (%d,%d) to remove" % [q, r])
		return false

	var tile = tile_manager.get_tile_at(q, r)
	if not tile:
		Log.error("BoardManager: Village exists at (%d,%d) but no tile found" % [q, r])
		return false

	if village.player_owner == current_player:
		if not turn_manager.consume_action("remove village"):
			return false
		if not village_manager.remove_village(q, r):
			return false
		Log.info("Removed own village at (%d,%d)" % [q, r])
	else:
		if not can_destroy_enemy_village(q, r):
			Log.warn("BoardManager: Cannot destroy enemy village at (%d,%d) — conditions not met" % [q, r])
			return false
		var best_own_height := get_best_adjacent_own_height(q, r)
		var res_cost := get_demolition_resources_cost(tile.height_level, best_own_height)
		var act_cost := get_demolition_action_cost(tile.height_level, best_own_height)
		for i in act_cost:
			if not turn_manager.consume_action("destroy enemy village"):
				return false
		if not village_manager.remove_village(q, r):
			return false
		current_player.spend_resources(res_cost)
		var glory: int = tile.height_level + 1
		current_player.add_glory(glory)
		Log.info("Destroyed enemy village at (%d,%d), paid %d resources, %d actions, gained %d glory" % [q, r, res_cost, act_cost, glory])

	if _is_network:
		rpc("_rpc_remove_village", q, r)

	return true



# ==================== TURN FLOW ====================

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


## Debug only: skip the opponent's current turn without them doing anything.
## Called by the NotYourTurnOverlay debug button for single-machine stub testing.
func _on_debug_end_opponent_turn() -> void:
	Log.info("Debug overlay: skipping action for %s" % current_player.player_name)
	placement_controller.cancel_placement()
	turn_manager.end_turn()



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
	# Disconnect self first to prevent re-entrant calls: disconnect_network() nulls
	# the ENet peer which can flush pending events and re-fire peer_disconnected.
	NetworkManager.peer_disconnected.disconnect(_on_network_peer_disconnected)
	NetworkManager.disconnect_network()
	# Defer so the current frame finishes before the scene tree tears down this node.
	get_tree().call_deferred("change_scene_to_file", "res://main_menu.tscn")


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



func _grant_placement_bounty(player: Player, tile_yields: Dictionary) -> void:
	for res_type in tile_yields:
		var amount: int = tile_yields[res_type]
		match res_type:
			TileDefinition.ResourceType.MATERIALS:
				player.add_resources(amount)
			TileDefinition.ResourceType.FERVOR:
				player.add_fervor(amount)
			TileDefinition.ResourceType.GLORY:
				player.add_glory(amount)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_place_tile(hand_index: int, q: int, r: int) -> void:
	if not _validate_rpc_sender(): return
	var td = current_player.hand[hand_index]
	if td == null:
		push_warning("_rpc_place_tile: hand[%d] is null" % hand_index)
		return
	tile_manager.place_tile(q, r, td.tile_type, td.yields, td.village_building_cost)
	_grant_placement_bounty(current_player, td.yields)
	current_player.remove_from_hand(hand_index)
	turn_manager.consume_action("place tile")
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
	var village := village_manager.get_village_at(q, r)
	var tile := tile_manager.get_tile_at(q, r)
	if not village or not tile:
		push_warning("_rpc_remove_village: missing village or tile at (%d,%d)" % [q, r])
		return
	if village.player_owner == current_player:
		village_manager.remove_village(q, r)
		turn_manager.consume_action("remove village")
	else:
		var best_own_height := get_best_adjacent_own_height(q, r)
		var res_cost := get_demolition_resources_cost(tile.height_level, best_own_height)
		var act_cost := get_demolition_action_cost(tile.height_level, best_own_height)
		village_manager.remove_village(q, r)
		current_player.spend_resources(res_cost)
		for i in act_cost:
			turn_manager.consume_action("destroy enemy village")


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
			turn_manager.trigger_second_harvest()
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
			"scores": victory_mgr.calculate_player_score(player, village_manager)
		})

	if ui:
		ui.show_victory_screen(results)
