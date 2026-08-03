extends Node3D

class_name TileManager

# Map tile types to their required height level
const TILE_TYPE_TO_HEIGHT = {
	TileDefinition.TileType.PLAINS: 0,
	TileDefinition.TileType.HILLS: 1,
	TileDefinition.TileType.MOUNTAIN: 2
}

# Visual colors for each tile type
const TILE_TYPE_COLORS = {
	TileDefinition.TileType.PLAINS: Color(0.4, 0.7, 0.3),
	TileDefinition.TileType.HILLS: Color(0.6, 0.5, 0.3),
	TileDefinition.TileType.MOUNTAIN: Color(0.5, 0.5, 0.5)
}

# Icon paths for resource types
const RESOURCE_TYPE_ICONS = {
	TileDefinition.ResourceType.MATERIALS: "res://assets/icons/wood.svg",
	TileDefinition.ResourceType.FERVOR: "res://assets/icons/pray.svg",
	TileDefinition.ResourceType.GLORY: "res://assets/icons/star.svg"
}

# Signals
signal tile_placed(q: int, r: int, height: int, tile_type: int)

# Configuration (set by board_manager)
var hex_tile_scene: PackedScene
var max_stack_height: int = 3

# Grid storage: Dictionary with Vector3i(q, r, height) as key
var placed_tiles: Dictionary = {}

# Reference to village manager (for validation)
var village_manager: VillageManager = null


## Initializes the TileManager with required configuration.
## Call this once after instantiation before using other methods.
func initialize(tile_scene: PackedScene) -> void:
	hex_tile_scene = tile_scene


## Places a tile at the specified hex coordinates with resource properties.
## Returns true if placement succeeded, false if invalid placement.
## Emits tile_placed signal on success.
func place_tile(q: int, r: int, tile_type: int, tile_yields: Dictionary = {},
				village_cost: int = 0) -> bool:
	var height = TILE_TYPE_TO_HEIGHT[tile_type]

	if not is_valid_placement(q, r, tile_type):
		return false

	var tile = hex_tile_scene.instantiate() as HexTile
	add_child(tile)
	tile.set_grid_position(q, r, height)
	tile.set_tile_type(tile_type, TILE_TYPE_COLORS[tile_type])
	tile.global_position = HexGridUtils.axial_to_world(q, r, height)

	tile.set_resource_properties(tile_yields, village_cost)

	var key = Vector3i(q, r, height)
	placed_tiles[key] = tile

	Log.debug("Placed %s tile at q=%d, r=%d, height=%d (yields=%s, village_cost=%d)" % [
		TileDefinition.TileType.keys()[tile_type], q, r, height,
		TileDefinition.format_yields(tile_yields), village_cost])
	tile_placed.emit(q, r, height, tile_type)
	return true


## Checks if a tile placement would be valid according to game rules.
## Does not modify game state - safe to call for preview validation.
## Checks: position occupied, height limits, village blocking, tile-specific rules.
func is_valid_placement(q: int, r: int, tile_type: int) -> bool:
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
	if tile_type == TileDefinition.TileType.PLAINS:
		# First tile can be placed anywhere
		if placed_tiles.is_empty():
			return true
		# Otherwise must be adjacent to at least one existing PLAINS tile
		var neighbors = HexGridUtils.get_axial_neighbors(q, r)
		for neighbor in neighbors:
			var neighbor_key = Vector3i(neighbor.x, neighbor.y, 0)
			if placed_tiles.has(neighbor_key):
				return true
		return false

	# HILLS (height 1) rules
	elif tile_type == TileDefinition.TileType.HILLS:
		# Must have a PLAINS tile directly below
		var below_key = Vector3i(q, r, 0)
		if not placed_tiles.has(below_key):
			return false
		# Verify it's a PLAINS tile
		var below_tile = placed_tiles[below_key] as HexTile
		return below_tile.tile_type == TileDefinition.TileType.PLAINS

	# MOUNTAIN (height 2) rules
	elif tile_type == TileDefinition.TileType.MOUNTAIN:
		# Must have a HILLS tile directly below
		var below_key = Vector3i(q, r, 1)
		if not placed_tiles.has(below_key):
			return false
		# Verify it's a HILLS tile
		var below_tile = placed_tiles[below_key] as HexTile
		return below_tile.tile_type == TileDefinition.TileType.HILLS

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


## Every (q, r) column that has at least one tile, each listed once regardless
## of stack height. For callers that need to sweep the board rather than probe
## a known position.
func get_occupied_hexes() -> Array[Vector2i]:
	var hexes: Array[Vector2i] = []
	for key in placed_tiles:
		var hex := Vector2i(key.x, key.y)
		if not hexes.has(hex):
			hexes.append(hex)
	return hexes


## Gets the topmost tile at the given hex position.
## Returns the HexTile node, or null if no tile exists.
func get_tile_at(q: int, r: int) -> HexTile:
	var top_height = get_top_height(q, r)
	if top_height == -1:
		return null
	var key = Vector3i(q, r, top_height)
	return placed_tiles.get(key, null)


## Instantiates and registers a tile stacked on top of (q, r), at the height
## implied by tile_type. Returns the new HexTile, or null if that height slot
## is already occupied. Used by upgrade_tile_with().
## Note: This bypasses village blocking - callers (upgrade powers) specifically allow this.
func _place_tile_on_top(q: int, r: int, tile_type: int, tile_yields: Dictionary,
		village_cost: int) -> HexTile:
	var new_height = TILE_TYPE_TO_HEIGHT[tile_type]
	var new_key = Vector3i(q, r, new_height)

	if placed_tiles.has(new_key):
		Log.warn("Cannot upgrade - tile already exists at height %d" % new_height)
		return null

	var tile = hex_tile_scene.instantiate() as HexTile
	add_child(tile)
	tile.set_grid_position(q, r, new_height)
	tile.set_tile_type(tile_type, TILE_TYPE_COLORS[tile_type])
	tile.global_position = HexGridUtils.axial_to_world(q, r, new_height)
	tile.set_resource_properties(tile_yields, village_cost)

	placed_tiles[new_key] = tile
	return tile


## Upgrades the tile at the given position to the next level using a specific
## tile definition instead of drawing from the bag. Used by powers that source
## the upgrade tile from a player's hand (e.g. Augia's Élévation divine).
## tile_def.tile_type must be exactly one level above the current tile.
## Returns true on success, false if upgrade is not possible.
func upgrade_tile_with(q: int, r: int, tile_def: TileDefinition) -> bool:
	var current_tile = get_tile_at(q, r)
	if not current_tile:
		Log.warn("No tile found at (%d, %d) to upgrade" % [q, r])
		return false

	if tile_def.tile_type != current_tile.tile_type + 1:
		Log.warn("Hand tile level does not directly follow the tile at (%d, %d)" % [q, r])
		return false

	var old_tile_type = current_tile.tile_type
	var tile = _place_tile_on_top(q, r, tile_def.tile_type, tile_def.yields, tile_def.village_building_cost)
	if not tile:
		return false

	Log.info("Upgraded tile at (%d, %d) from %s to %s using a hand tile" %
		  [q, r, TileDefinition.TileType.keys()[old_tile_type], TileDefinition.TileType.keys()[tile_def.tile_type]])

	return true


## Downgrades the tile at the given position to the previous level.
## MOUNTAIN → HILLS, HILLS → PLAINS, PLAINS → removed entirely (nothing below it).
## Removes the top tile, revealing the one below (if any).
## Returns a TileDefinition describing the removed tile (e.g. for Rakun's
## major power, which returns it to hand), or null if downgrade is not possible.
func downgrade_tile(q: int, r: int) -> TileDefinition:
	# Get the current top tile
	var current_tile = get_tile_at(q, r)
	if not current_tile:
		Log.warn("No tile found at (%d, %d) to downgrade" % [q, r])
		return null

	var old_tile_type = current_tile.tile_type

	var removed_tile_def := TileDefinition.new(
		current_tile.tile_type, current_tile.yields, current_tile.village_building_cost)

	# Remove the top tile (this reveals the tile below, if any)
	var old_height = current_tile.height_level
	var old_key = Vector3i(q, r, old_height)
	placed_tiles.erase(old_key)
	current_tile.queue_free()

	# PLAINS has nothing below it - the position is now fully cleared.
	if old_tile_type == TileDefinition.TileType.PLAINS:
		Log.info("Removed PLAINS tile at (%d, %d)" % [q, r])
		return removed_tile_def

	# Get the new top tile (which was below)
	var new_top_tile = get_tile_at(q, r)
	if not new_top_tile:
		Log.error("No tile below after downgrade at (%d, %d)!" % [q, r])
		return null

	Log.info("Downgraded tile at (%d, %d) from %s to %s" %
		  [q, r, TileDefinition.TileType.keys()[old_tile_type], TileDefinition.TileType.keys()[new_top_tile.tile_type]])

	return removed_tile_def
