extends Node3D

# Hexagonal grid orchestrator
# Reference: https://www.redblobgames.com/grids/hexagons/

# Configuration
@export var hex_tile_scene: PackedScene = preload("res://hex_tile.tscn")
@export var hex_size: float = 1.0  # Distance from center to corner
@export var tile_height: float = 0.3  # Height of each tile level
@export var max_stack_height: int = 3  # Maximum tiles that can be stacked
@export var test_mode: bool = false  # Test mode: unlimited resources/actions for testing

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

# Player (for now, single player)
var current_player: Player = null


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
	# Test mode: unlimited resources for design/testing. Normal: start with 0
	var starting_resources = 999 if test_mode else 0
	var starting_fervor = 999 if test_mode else 0
	current_player.initialize("Player 1", starting_resources, starting_fervor)

	# Create and initialize turn manager
	turn_manager = TurnManager.new()
	add_child(turn_manager)
	turn_manager.initialize(current_player, village_manager, tile_manager, tile_pool, self)

	# Create god manager
	god_manager = GodManager.new()
	add_child(god_manager)

	# Connect turn manager signals
	turn_manager.phase_changed.connect(_on_phase_changed)
	turn_manager.turn_ended.connect(_on_turn_ended)

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

	# Don't draw initial hand yet - happens after setup phase
	# Don't place any tiles automatically - player places them in setup
	print("Tile pool count at start: %d" % tile_pool.get_remaining_count())

	# Test mode: unlimited actions for placing many tiles
	if test_mode:
		current_player.set_actions(999)

	# Show god selection UI before starting game
	await show_god_selection()

	# Start in SETUP phase (not harvest!)
	turn_manager.start_setup_phase()

	# Create UI
	setup_ui()

	# Update god display in UI
	if current_player.god:
		ui.update_god_display(current_player.god, god_manager)


## Show god selection screen and wait for player to choose
func show_god_selection() -> void:
	# Create canvas layer for god selection UI
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)

	# Create god selection UI
	var god_selection_script = load("res://god_selection_ui.gd")
	var god_selection_ui = god_selection_script.new()
	god_selection_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(god_selection_ui)

	# Wait for god selection
	var selected_god = await god_selection_ui.god_selected
	current_player.god = selected_god
	print("Player selected: %s" % selected_god.god_name)

	# Remove canvas layer (god selection UI will queue_free itself)
	canvas_layer.queue_free()


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
	ui.setup_tile_selected.connect(_on_setup_tile_selected)
	ui.village_place_selected.connect(placement_controller.select_village_place_mode)
	ui.village_remove_selected.connect(placement_controller.select_village_remove_mode)

	# Connect player signals to UI
	current_player.resources_changed.connect(ui.update_resources)
	current_player.fervor_changed.connect(ui.update_fervor)
	current_player.glory_changed.connect(ui.update_glory)
	current_player.actions_changed.connect(ui.update_actions)

	# Set UI reference in turn_manager
	turn_manager.set_ui(ui)

	# Update displays
	ui.update_hand_display()
	ui.update_turn_phase(turn_manager.current_phase)  # Show/hide phase-specific UI
	# Trigger initial signal emissions to update UI
	current_player.resources_changed.emit(current_player.resources)
	current_player.fervor_changed.emit(current_player.fervor)
	current_player.glory_changed.emit(current_player.glory)
	current_player.actions_changed.emit(current_player.actions_remaining)


## Handle setup tile selection during setup phase
func _on_setup_tile_selected(setup_index: int) -> void:
	if setup_index < 0 or setup_index >= current_player.setup_tiles.size():
		return

	var tile_def = current_player.setup_tiles[setup_index]
	if tile_def == null:
		print("No setup tile in this slot!")
		return

	print("Selected setup tile %d: %s %s (yield=%d, village_cost=%d)" % [
		setup_index + 1,
		TileManager.TileType.keys()[tile_def.tile_type],
		TileManager.ResourceType.keys()[tile_def.resource_type],
		tile_def.yield_value,
		tile_def.village_building_cost
	])

	# Enter placement mode with this setup tile
	placement_controller.select_tile_from_hand(setup_index, tile_def)


## Handle tile selection from hand
func _on_tile_selected_from_hand(hand_index: int) -> void:
	if hand_index < 0 or hand_index >= current_player.HAND_SIZE:
		return

	var tile_def = current_player.hand[hand_index]
	if tile_def == null:
		print("No tile in this slot!")
		return

	# Can only place tiles during actions phase
	if not turn_manager.is_actions_phase():
		print("Can only place tiles during actions phase!")
		return

	# Check if player has actions remaining
	if current_player.actions_remaining <= 0:
		print("No actions remaining to place tile!")
		return

	print("Selected tile from hand: %s %s (yield=%d, village_cost=%d)" % [
		TileManager.TileType.keys()[tile_def.tile_type],
		TileManager.ResourceType.keys()[tile_def.resource_type],
		tile_def.yield_value,
		tile_def.village_building_cost
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

	# Validate phase - can only place tiles during actions phase (setup uses different flow)
	if not turn_manager.is_actions_phase():
		print("ERROR: Can only place tiles during actions phase!")
		return

	# Consume action
	if not turn_manager.consume_action("place tile"):
		print("ERROR: Placed tile but had no actions!")
		return

	print("Placed tile from hand: %s %s" % [
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
	if ui:
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

	# Consume 1 action (validates phase and action count)
	if not turn_manager.consume_action("sell tile"):
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
	if ui:
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

	# Get building cost from tile (with god ability modification)
	var cost = current_player.get_village_cost(tile.village_building_cost)

	# Check if player can afford it
	if current_player.resources < cost:
		print("Cannot afford village! Need %d resources, have %d" % [cost, current_player.resources])
		return false

	# Consume 1 action (validates phase and action count)
	if not turn_manager.consume_action("build village"):
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

	print("Built village for %d resources" % cost)

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

	# Calculate refund (half the building cost, with god ability modification)
	var building_cost = current_player.get_village_cost(tile.village_building_cost)
	var refund = building_cost / 2

	# Consume 1 action (validates phase and action count)
	if not turn_manager.consume_action("remove village"):
		return false

	# Remove the village
	var success = village_manager.remove_village(q, r)
	if not success:
		return false

	# Give refund
	current_player.add_resources(refund)

	print("Removed village, received %d resources refund" % refund)

	return true


## Handle steal harvest from enemy village (Rakun's power)
## Adds the tile's yield to the player's resources/fervor/glory
func on_steal_harvest(q: int, r: int) -> bool:
	# Check if there's a village at this position
	var village = village_manager.get_village_at(q, r)
	if not village:
		print("No village at position (%d, %d)" % [q, r])
		return false

	# Check if it's an enemy village (not owned by current player)
	if village.player_owner == current_player:
		print("Cannot steal from your own village!")
		return false

	# Get the tile to determine yield and resource type
	var tile = tile_manager.get_tile_at(q, r)
	if not tile:
		print("ERROR: No tile at village position!")
		return false

	# Steal the harvest (add yield to player)
	var harvest_value = tile.yield_value
	match tile.resource_type:
		TileManager.ResourceType.RESOURCES:
			current_player.add_resources(harvest_value)
			print("Stole %d resources from enemy village" % harvest_value)
		TileManager.ResourceType.FERVOR:
			current_player.add_fervor(harvest_value)
			print("Stole %d fervor from enemy village" % harvest_value)
		TileManager.ResourceType.GLORY:
			current_player.add_glory(harvest_value)
			print("Stole %d glory from enemy village" % harvest_value)

	return true


## Handle free village destruction (Le Bâtisseur's power)
## Destroys enemy village without paying compensation
func on_destroy_village_free(q: int, r: int) -> bool:
	# Check if there's a village at this position
	var village = village_manager.get_village_at(q, r)
	if not village:
		print("No village at position (%d, %d)" % [q, r])
		return false

	# Check if it's an enemy village (not owned by current player)
	if village.player_owner == current_player:
		print("Cannot destroy your own village with this power!")
		return false

	# Remove the village (no compensation - that's the power!)
	var success = village_manager.remove_village(q, r)
	if success:
		print("Destroyed enemy village at (%d, %d) with DESTROY_VILLAGE_FREE power" % [q, r])

	return success


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


# Signal handlers for turn manager events

## Called when turn phase changes (e.g., HARVEST -> ACTIONS)
func _on_phase_changed(new_phase: int) -> void:
	# Cancel any active placement when phase changes
	if placement_controller:
		placement_controller.cancel_placement()


## Called when turn ends (before discarding/drawing)
func _on_turn_ended() -> void:
	# Cancel any active placement when turn ends
	if placement_controller:
		placement_controller.cancel_placement()
