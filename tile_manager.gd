extends Node3D

class_name TileManager

# Tile type definitions
enum TileType {
	PLAINS,    # Height 0 - ground level
	HILLS,     # Height 1 - built on plains
	MOUNTAIN   # Height 2 - built on hills
}

# Resource type definitions (what the tile produces)
enum ResourceType {
	RESOURCES,  # Building materials (wood icon)
	FERVOR,     # Divine energy (pray icon)
	GLORY       # Victory points (star icon)
}

# Map tile types to their required height level
const TILE_TYPE_TO_HEIGHT = {
	TileType.PLAINS: 0,
	TileType.HILLS: 1,
	TileType.MOUNTAIN: 2
}

# Visual colors for each tile type
const TILE_TYPE_COLORS = {
	TileType.PLAINS: Color(0.4, 0.7, 0.3),    # Green
	TileType.HILLS: Color(0.6, 0.5, 0.3),     # Brown
	TileType.MOUNTAIN: Color(0.5, 0.5, 0.5)   # Gray
}

# Icon paths for resource types
const RESOURCE_TYPE_ICONS = {
	ResourceType.RESOURCES: "res://icons/wood.svg",
	ResourceType.FERVOR: "res://icons/pray.svg",
	ResourceType.GLORY: "res://icons/star.svg"
}

# Signals
signal tile_placed(q: int, r: int, height: int, tile_type: TileType)

# Configuration (set by board_manager)
var hex_tile_scene: PackedScene
var hex_size: float = 1.0
var tile_height: float = 0.3
var max_stack_height: int = 3

# Grid storage: Dictionary with Vector3i(q, r, height) as key
var placed_tiles: Dictionary = {}

# Reference to village manager (for validation)
var village_manager = null


## Initializes the TileManager with required configuration.
## Call this once after instantiation before using other methods.
func initialize(tile_scene: PackedScene, _hex_size: float, _tile_height: float) -> void:
	hex_tile_scene = tile_scene
	hex_size = _hex_size
	tile_height = _tile_height


## Places a tile at the specified hex coordinates with resource properties.
## Returns true if placement succeeded, false if invalid placement.
## Emits tile_placed signal on success.
func place_tile(q: int, r: int, tile_type: TileType, res_type: ResourceType = ResourceType.RESOURCES,
				yield_val: int = 1, buy_val: int = 0, sell_val: int = 0) -> bool:
	var height = TILE_TYPE_TO_HEIGHT[tile_type]

	if not is_valid_placement(q, r, tile_type):
		return false

	var tile = hex_tile_scene.instantiate() as HexTile
	add_child(tile)
	tile.set_grid_position(q, r, height)
	tile.set_tile_type(tile_type, TILE_TYPE_COLORS[tile_type])
	tile.global_position = get_parent().axial_to_world(q, r, height)

	# Set resource properties with icon
	var icon_path = RESOURCE_TYPE_ICONS[res_type]
	tile.set_resource_properties(res_type, yield_val, buy_val, sell_val, icon_path)

	var key = Vector3i(q, r, height)
	placed_tiles[key] = tile

	print("Placed %s tile at q=%d, r=%d, height=%d (Resource: %s, Yield: %d)" %
		  [TileType.keys()[tile_type], q, r, height, ResourceType.keys()[res_type], yield_val])
	tile_placed.emit(q, r, height, tile_type)
	return true


## Checks if a tile placement would be valid according to game rules.
## Does not modify game state - safe to call for preview validation.
## Checks: position occupied, height limits, village blocking, tile-specific rules.
func is_valid_placement(q: int, r: int, tile_type: TileType) -> bool:
	var height = TILE_TYPE_TO_HEIGHT[tile_type]
	var key = Vector3i(q, r, height)

	# Check if position is already occupied
	if placed_tiles.has(key):
		return false

	# Check if height is within limits
	if height < 0 or height >= max_stack_height:
		return false

	# Check if there's a village on this tile position (blocks stacking)
	if village_manager and village_manager.has_village_at(q, r) and height > 0:
		return false

	# PLAINS (height 0) rules
	if tile_type == TileType.PLAINS:
		# First tile can be placed anywhere
		if placed_tiles.is_empty():
			return true
		# Otherwise must be adjacent to at least one existing PLAINS tile
		var neighbors = get_parent().get_axial_neighbors(q, r)
		for neighbor in neighbors:
			var neighbor_key = Vector3i(neighbor.x, neighbor.y, 0)
			if placed_tiles.has(neighbor_key):
				return true
		return false

	# HILLS (height 1) rules
	elif tile_type == TileType.HILLS:
		# Must have a PLAINS tile directly below
		var below_key = Vector3i(q, r, 0)
		if not placed_tiles.has(below_key):
			return false
		# Verify it's a PLAINS tile
		var below_tile = placed_tiles[below_key] as HexTile
		return below_tile.tile_type == TileType.PLAINS

	# MOUNTAIN (height 2) rules
	elif tile_type == TileType.MOUNTAIN:
		# Must have a HILLS tile directly below
		var below_key = Vector3i(q, r, 1)
		if not placed_tiles.has(below_key):
			return false
		# Verify it's a HILLS tile
		var below_tile = placed_tiles[below_key] as HexTile
		return below_tile.tile_type == TileType.HILLS

	return false


## Checks if any tile exists at the given hex position (at any height).
## Returns true if at least one tile exists in the vertical stack.
func has_tile_at(q: int, r: int) -> bool:
	# Check if any tile exists at this position (any height)
	for height in range(max_stack_height):
		if placed_tiles.has(Vector3i(q, r, height)):
			return true
	return false


## Returns the height of the topmost tile at the given hex position.
## Returns -1 if no tile exists at this position.
func get_top_height(q: int, r: int) -> int:
	# Get the height of the topmost tile at this position
	var top_height = -1
	for height in range(max_stack_height):
		if placed_tiles.has(Vector3i(q, r, height)):
			top_height = height
	return top_height
