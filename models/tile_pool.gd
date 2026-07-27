extends Node

class_name TilePool

## Manages the bag of tiles and player hands.
## Tile definitions live in TileDefinition (tile_definition.gd).

var tile_bag: Array[TileDefinition] = []
var removed_tiles: Array[TileDefinition] = []


## Initialize the tile pool with all 64 tiles from rules.md.
## Pass rng_seed >= 0 for deterministic shuffling (network mode); -1 uses random seed.
func initialize(rng_seed: int = -1) -> void:
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	tile_bag.clear()
	removed_tiles.clear()

	const M = TileDefinition.ResourceType.MATERIALS
	const F = TileDefinition.ResourceType.FERVOR
	const G = TileDefinition.ResourceType.GLORY
	const PLAINS   = TileDefinition.TileType.PLAINS
	const HILLS    = TileDefinition.TileType.HILLS
	const MOUNTAIN = TileDefinition.TileType.MOUNTAIN

	# PLAINS (32 total), village_cost = 2
	for i in 12: tile_bag.append(TileDefinition.new(PLAINS, {M: 1}, 2))
	for i in  4: tile_bag.append(TileDefinition.new(PLAINS, {M: 2}, 2))
	for i in 12: tile_bag.append(TileDefinition.new(PLAINS, {F: 1}, 2))
	for i in  4: tile_bag.append(TileDefinition.new(PLAINS, {F: 2}, 2))

	# HILLS (20 total), village_cost = 4
	for i in 6: tile_bag.append(TileDefinition.new(HILLS, {M: 2}, 4))
	for i in 2: tile_bag.append(TileDefinition.new(HILLS, {M: 3}, 4))
	for i in 6: tile_bag.append(TileDefinition.new(HILLS, {F: 2}, 4))
	for i in 2: tile_bag.append(TileDefinition.new(HILLS, {F: 3}, 4))
	for i in 4: tile_bag.append(TileDefinition.new(HILLS, {G: 2}, 4))

	# MOUNTAINS (12 total), village_cost = 6
	for i in 2: tile_bag.append(TileDefinition.new(MOUNTAIN, {M: 3, G: 1}, 6))
	tile_bag.append(      TileDefinition.new(MOUNTAIN, {M: 3, G: 2}, 6))
	tile_bag.append(      TileDefinition.new(MOUNTAIN, {M: 4, G: 1}, 6))
	for i in 2: tile_bag.append(TileDefinition.new(MOUNTAIN, {F: 3, G: 1}, 6))
	tile_bag.append(      TileDefinition.new(MOUNTAIN, {F: 3, G: 2}, 6))
	tile_bag.append(      TileDefinition.new(MOUNTAIN, {F: 4, G: 1}, 6))
	for i in 2: tile_bag.append(TileDefinition.new(MOUNTAIN, {G: 3}, 6))
	for i in 2: tile_bag.append(TileDefinition.new(MOUNTAIN, {M: 2, F: 2, G: 2}, 6))

	# Fisher-Yates shuffle using seeded RNG for deterministic ordering
	for i in range(tile_bag.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = tile_bag[i]
		tile_bag[i] = tile_bag[j]
		tile_bag[j] = tmp

	Log.info("TilePool initialized: %d tiles in bag" % tile_bag.size())
	assert(tile_bag.size() == 64, "TilePool: Expected 64 tiles, got %d" % tile_bag.size())


## Draw a random tile from the bag. Returns TileDefinition or null if bag is empty.
func draw_tile() -> TileDefinition:
	if tile_bag.is_empty():
		Log.warn("TilePool: Bag is empty!")
		return null

	var tile = tile_bag.pop_back()
	removed_tiles.append(tile)
	Log.debug("TilePool: Drew %s tile (yields=%s). Remaining: %d" % [
		TileDefinition.TileType.keys()[tile.tile_type],
		TileDefinition.format_yields(tile.yields),
		tile_bag.size()
	])
	return tile


## Draw multiple tiles at once. Returns array of TileDefinitions.
func draw_tiles(count: int) -> Array[TileDefinition]:
	var tiles: Array[TileDefinition] = []
	for i in range(count):
		var tile = draw_tile()
		if tile:
			tiles.append(tile)
		else:
			break
	return tiles


func get_remaining_count() -> int:
	return tile_bag.size()


func is_empty() -> bool:
	return tile_bag.is_empty()


## Check if the bag has at least one tile of the given tile type.
func has_tile_of_type(tile_type: int) -> bool:
	for tile in tile_bag:
		if tile.tile_type == tile_type:
			return true
	return false


## Draw any tile of the given tile type from the bag.
## Returns TileDefinition or null if none available.
func draw_tile_of_type(tile_type: int) -> TileDefinition:
	for i in range(tile_bag.size()):
		if tile_bag[i].tile_type == tile_type:
			var tile = tile_bag[i]
			tile_bag.remove_at(i)
			removed_tiles.append(tile)
			Log.debug("TilePool: Drew %s tile from bag. Remaining: %d" % [
				TileDefinition.TileType.keys()[tile.tile_type],
				tile_bag.size()
			])
			return tile
	Log.warn("TilePool: No %s tile available in bag!" % TileDefinition.TileType.keys()[tile_type])
	return null


## Return a tile to the bag and shuffle.
func return_tile(tile: TileDefinition) -> void:
	var idx = removed_tiles.find(tile)
	if idx != -1:
		removed_tiles.remove_at(idx)

	tile_bag.append(tile)
	tile_bag.shuffle()
	Log.debug("TilePool: Returned tile to bag. Total: %d" % tile_bag.size())
