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
	current_player.draw_tiles(tile_pool, 3)

	# Place first tile from pool as a starting tile
	var first_tile = tile_pool.draw_tile()
	if first_tile:
		tile_manager.place_tile(0, 0, first_tile.tile_type, first_tile.resource_type,
								first_tile.yield_value, first_tile.buy_price, first_tile.sell_price)

	# Give player starting turn bonus
	current_player.start_turn()

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
	ui.village_place_selected.connect(placement_controller.select_village_place_mode)
	ui.village_remove_selected.connect(placement_controller.select_village_remove_mode)

	# Connect player signals to UI
	if ui_mode == "game":
		current_player.resources_changed.connect(ui.update_resources)
		current_player.fervor_changed.connect(ui.update_fervor)
		current_player.glory_changed.connect(ui.update_glory)

	# Update displays (only in game mode)
	if ui_mode == "game":
		ui.update_hand_display()
		ui.update_resources(current_player.resources)
		ui.update_fervor(current_player.fervor)
		ui.update_glory(current_player.glory)


## Handle tile selection from hand
func _on_tile_selected_from_hand(hand_index: int) -> void:
	if hand_index < 0 or hand_index >= current_player.hand.size():
		return

	var tile_def = current_player.hand[hand_index]

	# Check if player can afford it
	if not current_player.can_afford_tile(tile_def):
		print("Cannot afford tile! Need %d resources, have %d" % [
			tile_def.buy_price, current_player.resources
		])
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
	if hand_index < 0 or hand_index >= current_player.hand.size():
		return

	var placed_tile = current_player.hand[hand_index]

	# Spend resources
	if not current_player.spend_resources(placed_tile.buy_price):
		print("ERROR: Placed tile but couldn't afford it!")
		return

	print("Consumed tile from hand: %s %s" % [
		TileManager.TileType.keys()[placed_tile.tile_type],
		TileManager.ResourceType.keys()[placed_tile.resource_type]
	])

	# Remove tile from hand
	current_player.remove_from_hand(hand_index)

	# Draw replacement tile to refill hand
	current_player.draw_tiles(tile_pool, 1)

	if tile_pool.get_remaining_count() == 0 and current_player.hand.size() == 0:
		print("Game Over! No tiles left in bag or hand.")

	# Update UI to reflect hand changes
	if ui and ui_mode == "game":
		ui.update_hand_display()


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
