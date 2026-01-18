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
				yield_val: int = 1, village_cost: int = 0, sell_val: int = 0) -> bool:
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
	tile.set_resource_properties(res_type, yield_val, village_cost, sell_val, icon_path)

	var key = Vector3i(q, r, height)
	placed_tiles[key] = tile

	print("Placed %s tile at q=%d, r=%d, height=%d (Resource: %s, Yield: %d, Village Cost: %d)" %
		  [TileType.keys()[tile_type], q, r, height, ResourceType.keys()[res_type], yield_val, village_cost])
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


## Gets the topmost tile at the given hex position.
## Returns the HexTile node, or null if no tile exists.
func get_tile_at(q: int, r: int) -> HexTile:
	var top_height = get_top_height(q, r)
	if top_height == -1:
		return null
	var key = Vector3i(q, r, top_height)
	return placed_tiles.get(key, null)


## Upgrades the tile at the given position to the next level.
## PLAINS → HILLS, HILLS → MOUNTAIN
## Adds a new tile on top, preserving the tile's resource properties.
## Returns true on success, false if upgrade is not possible.
func upgrade_tile(q: int, r: int) -> bool:
	# Get the current top tile
	var current_tile = get_tile_at(q, r)
	if not current_tile:
		print("No tile found at (%d, %d) to upgrade" % [q, r])
		return false

	# Determine the new tile type
	var new_tile_type: TileType
	match current_tile.tile_type:
		TileType.PLAINS:
			new_tile_type = TileType.HILLS
		TileType.HILLS:
			new_tile_type = TileType.MOUNTAIN
		TileType.MOUNTAIN:
			print("Cannot upgrade MOUNTAIN - already at max level")
			return false
		_:
			return false

	# Copy resource properties from current tile to carry forward
	var res_type = current_tile.resource_type
	var yield_val = current_tile.yield_value
	var village_cost = current_tile.village_building_cost
	var sell_val = current_tile.sell_price
	var old_tile_type = current_tile.tile_type

	# Place new tile on top (stacking)
	# Note: This bypasses village blocking - the power specifically allows this
	var new_height = TILE_TYPE_TO_HEIGHT[new_tile_type]
	var new_key = Vector3i(q, r, new_height)

	# Check if position is already occupied at new height
	if placed_tiles.has(new_key):
		print("Cannot upgrade - tile already exists at height %d" % new_height)
		return false

	var tile = hex_tile_scene.instantiate() as HexTile
	add_child(tile)
	tile.set_grid_position(q, r, new_height)
	tile.set_tile_type(new_tile_type, TILE_TYPE_COLORS[new_tile_type])
	tile.global_position = get_parent().axial_to_world(q, r, new_height)

	# Set resource properties with icon
	var icon_path = RESOURCE_TYPE_ICONS[res_type]
	tile.set_resource_properties(res_type, yield_val, village_cost, sell_val, icon_path)

	placed_tiles[new_key] = tile

	print("Upgraded tile at (%d, %d) from %s to %s" %
		  [q, r, TileType.keys()[old_tile_type], TileType.keys()[new_tile_type]])

	return true


## Downgrades the tile at the given position to the previous level.
## MOUNTAIN → HILLS, HILLS → PLAINS
## Removes the top tile, revealing the one below.
## Returns true on success, false if downgrade is not possible.
func downgrade_tile(q: int, r: int) -> bool:
	# Get the current top tile
	var current_tile = get_tile_at(q, r)
	if not current_tile:
		print("No tile found at (%d, %d) to downgrade" % [q, r])
		return false

	# Check if can be downgraded
	var old_tile_type = current_tile.tile_type
	match current_tile.tile_type:
		TileType.PLAINS:
			print("Cannot downgrade PLAINS - already at min level")
			return false
		TileType.HILLS, TileType.MOUNTAIN:
			# Can downgrade
			pass
		_:
			return false

	# Remove the top tile (this reveals the tile below)
	var old_height = current_tile.height_level
	var old_key = Vector3i(q, r, old_height)
	placed_tiles.erase(old_key)
	current_tile.queue_free()

	# Get the new top tile (which was below)
	var new_top_tile = get_tile_at(q, r)
	if not new_top_tile:
		print("ERROR: No tile below after downgrade!")
		return false

	print("Downgraded tile at (%d, %d) from %s to %s" %
		  [q, r, TileType.keys()[old_tile_type], TileType.keys()[new_top_tile.tile_type]])

	return true
