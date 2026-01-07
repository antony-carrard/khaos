extends Node3D

# Hexagonal grid orchestrator
# Reference: https://www.redblobgames.com/grids/hexagons/

# Configuration
@export var hex_tile_scene: PackedScene = preload("res://hex_tile.tscn")
@export var hex_size: float = 1.0  # Distance from center to corner
@export var tile_height: float = 0.3  # Height of each tile level
@export var max_stack_height: int = 3  # Maximum tiles that can be stacked
@export_enum("test", "game") var ui_mode: String = "game"  # UI mode: test (debug) or game (full)

# Manager components
var tile_manager: TileManager
var village_manager: VillageManager
var placement_controller: PlacementController
var tile_pool: TilePool

# UI
var ui: Control = null

# Camera reference
var camera: Camera3D = null

# Player (for now, single player)
var current_player: Player = null

# ========== TURN SYSTEM (Extract to TurnManager later) ==========
enum TurnPhase { HARVEST, ACTIONS }
var current_phase: TurnPhase = TurnPhase.HARVEST

# Game end state
var game_ended: bool = false
var final_round_triggered: bool = false
var triggering_player: Player = null


func _ready() -> void:
	# Create and initialize managers
	tile_manager = TileManager.new()
	add_child(tile_manager)
	tile_manager.initialize(hex_tile_scene, hex_size, tile_height)
	tile_manager.max_stack_height = max_stack_height

	village_manager = VillageManager.new()
	add_child(village_manager)
	village_manager.initialize(tile_height)

	# Initialize tile pool
	tile_pool = TilePool.new()
	add_child(tile_pool)
	tile_pool.initialize()

	# Create player
	current_player = Player.new()
	add_child(current_player)
	current_player.initialize("Player 1", 10, 10)  # Start with 0 resources/fervor

	# Cross-reference managers (for validation)
	tile_manager.village_manager = village_manager
	village_manager.tile_manager = tile_manager

	# Get camera reference (sibling in scene tree)
	var parent = get_parent()
	if not parent:
		push_error("BoardManager: No parent node found! BoardManager must be a child of Main scene.")
		return

	camera = parent.get_node_or_null("Camera3D")
	if not camera:
		push_error("BoardManager: Camera3D not found! Make sure a Camera3D node exists as a sibling of BoardManager.")
		return

	placement_controller = PlacementController.new()
	add_child(placement_controller)
	await placement_controller.initialize(tile_manager, village_manager, camera, self)

	# Draw initial hand (3 tiles as per rules.md line 65)
	print("Tile pool count before drawing hand: %d" % tile_pool.get_remaining_count())
	current_player.draw_tiles(tile_pool, 3)
	print("Tile pool count after drawing hand: %d" % tile_pool.get_remaining_count())
	print("Player hand size: %d" % current_player.hand.size())

	# Place first tile from pool as a starting tile (must be PLAINS)
	var first_tile = null
	var attempts = 0
	while first_tile == null or first_tile.tile_type != TileManager.TileType.PLAINS:
		if first_tile != null:
			# Put non-PLAINS tile back and shuffle
			tile_pool.return_tile(first_tile)
		first_tile = tile_pool.draw_tile()
		attempts += 1
		if attempts > 100:  # Safety check
			push_error("Could not find PLAINS tile for starting position!")
			break

	print("Tile pool count after drawing starting tile: %d" % tile_pool.get_remaining_count())
	if first_tile and first_tile.tile_type == TileManager.TileType.PLAINS:
		print("Placing initial tile at (0,0): %s %s" % [
			TileManager.TileType.keys()[first_tile.tile_type],
			TileManager.ResourceType.keys()[first_tile.resource_type]
		])
		var success = tile_manager.place_tile(0, 0, first_tile.tile_type, first_tile.resource_type,
								first_tile.yield_value, first_tile.buy_price, first_tile.sell_price)
		print("Initial tile placement success: %s" % success)
	else:
		push_error("Failed to draw PLAINS tile from pool!")

	# Give player starting turn bonus and start harvest phase
	current_player.start_turn()
	start_harvest_phase()

	# Create UI
	setup_ui()


func setup_ui() -> void:
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)

	var ui_script = load("res://tile_selector_ui.gd")
	ui = ui_script.new()
	canvas_layer.add_child(ui)
	ui.initialize(TileManager.TILE_TYPE_COLORS, self, ui_mode)

	# Connect UI signals to placement controller
	ui.tile_type_selected.connect(placement_controller.select_tile_type)
	ui.tile_selected_from_hand.connect(_on_tile_selected_from_hand)
	ui.tile_sold_from_hand.connect(sell_tile)
	ui.village_place_selected.connect(placement_controller.select_village_place_mode)
	ui.village_remove_selected.connect(placement_controller.select_village_remove_mode)

	# Connect player signals to UI
	if ui_mode == "game":
		current_player.resources_changed.connect(ui.update_resources)
		current_player.fervor_changed.connect(ui.update_fervor)
		current_player.glory_changed.connect(ui.update_glory)
		current_player.actions_changed.connect(ui.update_actions)

	# Update displays (only in game mode)
	if ui_mode == "game":
		ui.update_hand_display()
		ui.update_turn_phase(current_phase)  # Show/hide phase-specific UI
		# Trigger initial signal emissions to update UI
		current_player.resources_changed.emit(current_player.resources)
		current_player.fervor_changed.emit(current_player.fervor)
		current_player.glory_changed.emit(current_player.glory)
		current_player.actions_changed.emit(current_player.actions_remaining)


## Handle tile selection from hand
func _on_tile_selected_from_hand(hand_index: int) -> void:
	if hand_index < 0 or hand_index >= current_player.HAND_SIZE:
		return

	var tile_def = current_player.hand[hand_index]
	if tile_def == null:
		print("No tile in this slot!")
		return

	# Check if player can afford and place it
	var in_actions_phase = (current_phase == TurnPhase.ACTIONS)
	if not current_player.can_place_tile(tile_def, ui_mode == "game", in_actions_phase):
		if not current_player.can_afford_tile(tile_def):
			print("Cannot afford tile! Need %d resources, have %d" % [
				tile_def.buy_price, current_player.resources
			])
		elif ui_mode == "game" and in_actions_phase and current_player.actions_remaining <= 0:
			print("No actions remaining to place tile!")
		return

	print("Selected tile from hand: %s %s (yield=%d, cost=%d)" % [
		TileManager.TileType.keys()[tile_def.tile_type],
		TileManager.ResourceType.keys()[tile_def.resource_type],
		tile_def.yield_value,
		tile_def.buy_price
	])

	# Enter placement mode with this specific tile
	placement_controller.select_tile_from_hand(hand_index, tile_def)


## Called by placement_controller when a tile from hand is successfully placed
func on_tile_placed_from_hand(hand_index: int) -> void:
	if hand_index < 0 or hand_index >= current_player.HAND_SIZE:
		return

	var placed_tile = current_player.hand[hand_index]
	if placed_tile == null:
		print("ERROR: No tile in this slot!")
		return

	# Spend resources
	if not current_player.spend_resources(placed_tile.buy_price):
		print("ERROR: Placed tile but couldn't afford it!")
		return

	# Consume action (only in game mode during actions phase)
	if ui_mode == "game" and current_phase == TurnPhase.ACTIONS:
		if not consume_action():
			print("ERROR: Placed tile but had no actions!")
			return

	print("Consumed tile from hand: %s %s" % [
		TileManager.TileType.keys()[placed_tile.tile_type],
		TileManager.ResourceType.keys()[placed_tile.resource_type]
	])

	# Remove tile from hand (sets slot to null)
	current_player.remove_from_hand(hand_index)

	# Note: In the current game design, tiles are only refilled at end of turn
	# Not drawing a replacement tile here

	# Check if hand is completely empty and no tiles left
	var hand_has_tiles = false
	for tile in current_player.hand:
		if tile != null:
			hand_has_tiles = true
			break

	if tile_pool.get_remaining_count() == 0 and not hand_has_tiles:
		print("Game Over! No tiles left in bag or hand.")

	# Update UI to reflect hand changes
	if ui and ui_mode == "game":
		ui.update_hand_display()


## Sell a tile from hand for resources
## Returns resources equal to tile's sell_price
## Consumes 1 action (in game mode during actions phase)
func sell_tile(hand_index: int) -> void:
	if hand_index < 0 or hand_index >= current_player.HAND_SIZE:
		print("ERROR: Invalid hand index for selling: %d" % hand_index)
		return

	var tile = current_player.hand[hand_index]
	if tile == null:
		print("ERROR: No tile in this slot to sell!")
		return

	# Check if tile can be sold (Glory tiles have sell_price = 0)
	if tile.sell_price <= 0:
		print("Cannot sell this tile! Glory tiles cannot be sold.")
		return

	# In game mode, check phase and consume action
	if ui_mode == "game":
		# Can only sell during actions phase
		if current_phase != TurnPhase.ACTIONS:
			print("Can only sell tiles during the actions phase!")
			return

		# Check if player has actions remaining
		if current_player.actions_remaining <= 0:
			print("No actions remaining to sell tile!")
			return

		# Consume 1 action
		if not consume_action():
			print("ERROR: Failed to consume action for selling tile!")
			return

	# Give player resources
	current_player.add_resources(tile.sell_price)

	print("Sold %s %s tile for %d resources" % [
		TileManager.ResourceType.keys()[tile.resource_type],
		TileManager.TileType.keys()[tile.tile_type],
		tile.sell_price
	])

	# Remove tile from hand (no replacement drawn when selling)
	current_player.remove_from_hand(hand_index)

	# Cancel placement mode if this tile was selected for placement
	if placement_controller and placement_controller.selected_hand_index == hand_index:
		placement_controller.cancel_placement()

	# Update UI to reflect hand changes
	if ui and ui_mode == "game":
		ui.update_hand_display()


## Called when player attempts to place a village
## Validates affordability, consumes resources and action, then places village
## Returns true if placement succeeded, false otherwise
func on_village_placed(q: int, r: int) -> bool:
	# Get the tile at this position to determine cost
	var tile = tile_manager.get_tile_at(q, r)
	if not tile:
		print("ERROR: No tile at position for village placement!")
		return false

	# Get building cost based on tile type
	var cost = TileManager.VILLAGE_BUILDING_COSTS[tile.tile_type]

	# Check if player can afford it
	if current_player.resources < cost:
		print("Cannot afford village! Need %d resources, have %d" % [cost, current_player.resources])
		return false

	# In game mode, check phase and consume action
	if ui_mode == "game":
		# Can only build during actions phase
		if current_phase != TurnPhase.ACTIONS:
			print("Can only build villages during the actions phase!")
			return false

		# Check if player has actions remaining
		if current_player.actions_remaining <= 0:
			print("No actions remaining to build village!")
			return false

	# Attempt to place the village
	var success = village_manager.place_village(q, r, current_player)
	if not success:
		return false

	# Spend resources
	if not current_player.spend_resources(cost):
		print("ERROR: Placed village but couldn't afford it!")
		# This shouldn't happen since we checked above, but handle it anyway
		# Remove the village we just placed
		village_manager.remove_village(q, r)
		return false

	# Consume action (only in game mode during actions phase)
	if ui_mode == "game" and current_phase == TurnPhase.ACTIONS:
		if not consume_action():
			print("ERROR: Placed village but had no actions!")
			return false

	print("Built village on %s tile for %d resources" % [
		TileManager.TileType.keys()[tile.tile_type],
		cost
	])

	return true


## Called when player attempts to remove/sell a village
## Validates ownership, consumes action, removes village, and refunds half the building cost
## Returns true if removal succeeded, false otherwise
func on_village_removed(q: int, r: int) -> bool:
	# Check if village exists at this position
	var village = village_manager.get_village_at(q, r)
	if not village:
		print("ERROR: No village at position to remove!")
		return false

	# Check ownership - can only remove your own villages
	if village.player_owner != current_player:
		print("Cannot remove another player's village!")
		return false

	# Get the tile to determine refund
	var tile = tile_manager.get_tile_at(q, r)
	if not tile:
		print("ERROR: No tile at village position!")
		return false

	# Calculate refund (half the building cost)
	var building_cost = TileManager.VILLAGE_BUILDING_COSTS[tile.tile_type]
	var refund = building_cost / 2

	# In game mode, check phase and consume action
	if ui_mode == "game":
		# Can only remove during actions phase
		if current_phase != TurnPhase.ACTIONS:
			print("Can only remove villages during the actions phase!")
			return false

		# Check if player has actions remaining
		if current_player.actions_remaining <= 0:
			print("No actions remaining to remove village!")
			return false

	# Remove the village
	var success = village_manager.remove_village(q, r)
	if not success:
		return false

	# Give refund
	current_player.add_resources(refund)

	# Consume action (only in game mode during actions phase)
	if ui_mode == "game" and current_phase == TurnPhase.ACTIONS:
		if not consume_action():
			print("ERROR: Removed village but had no actions!")
			return false

	print("Removed village from %s tile, received %d resources refund" % [
		TileManager.TileType.keys()[tile.tile_type],
		refund
	])

	return true


# ========== TURN SYSTEM METHODS (Extract to TurnManager later) ==========

## Starts the harvest phase of the turn.
## Determines available harvest types and shows UI or auto-harvests if only one option.
func start_harvest_phase() -> void:
	current_phase = TurnPhase.HARVEST

	# Cancel any active placement mode when entering harvest phase
	if placement_controller:
		placement_controller.cancel_placement()

	var harvest_types = _get_available_harvest_types()

	print("=== HARVEST PHASE ===")
	print("Available harvest types: %s" % [harvest_types])

	if harvest_types.is_empty():
		print("No villages to harvest from! Skipping to actions phase.")
		current_phase = TurnPhase.ACTIONS
		if ui and ui_mode == "game":
			ui.update_turn_phase(current_phase)
		return

	if harvest_types.size() == 1:
		# Auto-harvest the only available type
		print("Auto-harvesting %s (only option)" % TileManager.ResourceType.keys()[harvest_types[0]])
		harvest(harvest_types[0])
	else:
		# Show harvest UI for player choice
		if ui and ui_mode == "game":
			ui.show_harvest_options(harvest_types)


## Gets the available harvest types based on player's villages.
## Returns array of ResourceType enums that have at least one village.
func _get_available_harvest_types() -> Array[int]:
	var types: Array[int] = []
	var villages = village_manager.get_villages_for_player(current_player)

	# Count villages on each resource type
	var type_counts = {
		TileManager.ResourceType.RESOURCES: 0,
		TileManager.ResourceType.FERVOR: 0,
		TileManager.ResourceType.GLORY: 0
	}

	for village in villages:
		var tile = tile_manager.get_tile_at(village.q, village.r)
		if tile:
			type_counts[tile.resource_type] += 1

	# Add types that have at least one village
	for type in type_counts:
		if type_counts[type] > 0:
			types.append(type)

	return types


## Harvests resources of the specified type from all player villages.
## Adds the total yield to the player's resources/fervor/glory.
## Transitions to actions phase after harvesting.
func harvest(resource_type: int) -> void:
	var villages = village_manager.get_villages_for_player(current_player)
	var total = 0
	var village_count = 0

	for village in villages:
		var tile = tile_manager.get_tile_at(village.q, village.r)
		if tile and tile.resource_type == resource_type:
			total += tile.yield_value
			village_count += 1

	# Add to player resources
	match resource_type:
		TileManager.ResourceType.RESOURCES:
			current_player.add_resources(total)
		TileManager.ResourceType.FERVOR:
			current_player.add_fervor(total)
		TileManager.ResourceType.GLORY:
			current_player.add_glory(total)

	print("Harvested %d %s from %d villages" % [
		total,
		TileManager.ResourceType.keys()[resource_type],
		village_count
	])

	# Transition to actions phase
	current_phase = TurnPhase.ACTIONS
	print("=== ACTIONS PHASE ===")
	print("Actions remaining: %d" % current_player.actions_remaining)

	if ui and ui_mode == "game":
		ui.update_turn_phase(current_phase)


## Consumes one action from the current player.
## Returns true if action was consumed, false if no actions remaining.
func consume_action() -> bool:
	var success = current_player.consume_action()
	if not success:
		print("No actions remaining!")
	else:
		print("Action consumed. Remaining: %d" % current_player.actions_remaining)
	return success


## Ends the current turn and starts a new one.
## Discards hand, draws new tiles, resets actions, and starts harvest phase.
func end_turn() -> void:
	print("=== END TURN ===")

	# Cancel any active placement mode when ending turn
	if placement_controller:
		placement_controller.cancel_placement()

	# Check for game end BEFORE discarding/drawing tiles
	if tile_pool.is_empty() and not final_round_triggered:
		final_round_triggered = true
		triggering_player = current_player
		print("=== FINAL ROUND TRIGGERED ===")
		print("Tile bag is empty. This is the last turn.")
		if ui:
			ui.show_final_round_notification()

	# Discard current hand (reset to empty slots)
	for i in range(current_player.HAND_SIZE):
		current_player.hand[i] = null

	# Draw 3 new tiles (fills empty slots, if any remain)
	current_player.draw_tiles(tile_pool, 3)

	# Start new turn (gives +1 resource, +1 fervor, resets actions to 3)
	current_player.start_turn()

	# Reset to harvest phase
	start_harvest_phase()

	# Update UI (hand display only - signals handle the rest)
	if ui and ui_mode == "game":
		ui.update_hand_display()

	# Check if final round is complete (single player: end immediately after final turn)
	if final_round_triggered:
		_trigger_game_end()
		return  # Don't print "New turn started" if game is over

	print("New turn started!")


## Triggers game end and displays victory screen.
## Called when final round is complete.
func _trigger_game_end() -> void:
	game_ended = true
	print("=== GAME OVER ===")

	# Calculate final scores
	var victory_mgr = VictoryManager.new()
	var score_data = victory_mgr.calculate_player_score(
		current_player, village_manager, tile_manager, self
	)

	# Show victory screen (array format for future multiplayer support)
	if ui:
		ui.show_victory_screen([{
			"player": current_player,
			"scores": score_data
		}])

# ========== END TURN SYSTEM ==========


# Hexagonal coordinate conversion utilities

## Converts axial hex coordinates (q, r) and height to 3D world position.
## Uses flat-top hexagon orientation.
func axial_to_world(q: int, r: int, height: int = 0) -> Vector3:
	# Convert axial coordinates to world position
	# Using flat-top hexagon orientation
	var x = hex_size * (sqrt(3.0) * q + sqrt(3.0) / 2.0 * r)
	var z = hex_size * (3.0 / 2.0 * r)
	var y = height * tile_height

	return Vector3(x, y, z)


## Converts 3D world position to axial hex coordinates (q, r).
## Returns the hex grid cell containing the world position.
func world_to_axial(world_pos: Vector3) -> Vector2i:
	# Convert world position to axial coordinates
	# Using flat-top hexagon orientation
	var q = (sqrt(3.0) / 3.0 * world_pos.x - 1.0 / 3.0 * world_pos.z) / hex_size
	var r = (2.0 / 3.0 * world_pos.z) / hex_size

	# Round to nearest hex using cube coordinates
	return axial_round(q, r)


func axial_round(q: float, r: float) -> Vector2i:
	# Convert to cube coordinates for rounding
	var s = -q - r

	var rq = round(q)
	var rr = round(r)
	var rs = round(s)

	var q_diff = abs(rq - q)
	var r_diff = abs(rr - r)
	var s_diff = abs(rs - s)

	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs

	return Vector2i(int(rq), int(rr))


## Returns the 6 adjacent hex positions around the given hex coordinate.
## Order: East, Northeast, Northwest, West, Southwest, Southeast.
func get_axial_neighbors(q: int, r: int) -> Array[Vector2i]:
	# Six directions in axial coordinates
	var directions = [
		Vector2i(+1, 0), Vector2i(+1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, +1), Vector2i(0, +1)
	]

	var neighbors: Array[Vector2i] = []
	for dir in directions:
		neighbors.append(Vector2i(q + dir.x, r + dir.y))

	return neighbors


## Get the player's current hand
func get_hand() -> Array:
	return current_player.hand if current_player else []


## Gets the hex coordinates at the mouse cursor position via raycast.
## Returns Vector2i(-999, -999) if no valid position found (no camera or raycast miss).
func get_axial_at_mouse(mouse_pos: Vector2) -> Vector2i:
	# Helper function to get axial coordinates from mouse position
	if not camera:
		return Vector2i(-999, -999)

	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000

	var world_3d = get_world_3d()
	if not world_3d:
		return Vector2i(-999, -999)

	var space_state = world_3d.direct_space_state
	if not space_state:
		return Vector2i(-999, -999)

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 0b11  # Layers 1 and 2
	var result = space_state.intersect_ray(query)

	if result:
		var hit_position = result.position
		return world_to_axial(hit_position)

	return Vector2i(-999, -999)
