extends Node

class_name TilePool

## Manages the bag of tiles and player hands
## Based on rules.md material counts

# Tile definition (blueprint for creating tiles)
class TileDefinition:
	var tile_type: int  # TileManager.TileType
	var resource_type: int  # TileManager.ResourceType
	var yield_value: int
	var buy_price: int
	var sell_price: int

	func _init(t_type: int, r_type: int, yield_val: int, buy_val: int, sell_val: int):
		tile_type = t_type
		resource_type = r_type
		yield_value = yield_val
		buy_price = buy_val
		sell_price = sell_val

# The tile bag (pool of available tiles)
var tile_bag: Array[TileDefinition] = []

# Removed tiles (drawn or used)
var removed_tiles: Array[TileDefinition] = []


## Initialize the tile pool with all 63 tiles from rules.md
func initialize() -> void:
	tile_bag.clear()
	removed_tiles.clear()

	# PLAINS (28 total): 14 Resources + 14 Fervor
	# yield=1, buy=2, sell=1
	for i in range(14):
		tile_bag.append(TileDefinition.new(
			TileManager.TileType.PLAINS,
			TileManager.ResourceType.RESOURCES,
			1, 2, 1
		))
	for i in range(14):
		tile_bag.append(TileDefinition.new(
			TileManager.TileType.PLAINS,
			TileManager.ResourceType.FERVOR,
			1, 2, 1
		))

	# HILLS (21 total): 9 Resources + 9 Fervor + 3 Glory
	# yield=2, buy=4, sell=2 (glory sell=0)
	for i in range(9):
		tile_bag.append(TileDefinition.new(
			TileManager.TileType.HILLS,
			TileManager.ResourceType.RESOURCES,
			2, 4, 2
		))
	for i in range(9):
		tile_bag.append(TileDefinition.new(
			TileManager.TileType.HILLS,
			TileManager.ResourceType.FERVOR,
			2, 4, 2
		))
	for i in range(3):
		tile_bag.append(TileDefinition.new(
			TileManager.TileType.HILLS,
			TileManager.ResourceType.GLORY,
			2, 4, 0  # Glory can't be sold
		))

	# MOUNTAINS (14 total): 4 Resources + 4 Fervor + 6 Glory
	# yield=4, buy=8, sell=4 (glory sell=0)
	for i in range(4):
		tile_bag.append(TileDefinition.new(
			TileManager.TileType.MOUNTAIN,
			TileManager.ResourceType.RESOURCES,
			4, 8, 4
		))
	for i in range(4):
		tile_bag.append(TileDefinition.new(
			TileManager.TileType.MOUNTAIN,
			TileManager.ResourceType.FERVOR,
			4, 8, 4
		))
	for i in range(6):
		tile_bag.append(TileDefinition.new(
			TileManager.TileType.MOUNTAIN,
			TileManager.ResourceType.GLORY,
			4, 8, 0  # Glory can't be sold
		))

	# Shuffle the bag
	tile_bag.shuffle()

	print("TilePool initialized: %d tiles in bag" % tile_bag.size())


## Draw a random tile from the bag
## Returns TileDefinition or null if bag is empty
func draw_tile() -> TileDefinition:
	if tile_bag.is_empty():
		print("TilePool: Bag is empty!")
		return null

	var tile = tile_bag.pop_back()
	removed_tiles.append(tile)
	print("TilePool: Drew %s %s tile (yield=%d, buy=%d, sell=%d). Remaining: %d" % [
		TileManager.ResourceType.keys()[tile.resource_type],
		TileManager.TileType.keys()[tile.tile_type],
		tile.yield_value,
		tile.buy_price,
		tile.sell_price,
		tile_bag.size()
	])
	return tile


## Draw multiple tiles at once
## Returns array of TileDefinitions
func draw_tiles(count: int) -> Array[TileDefinition]:
	var tiles: Array[TileDefinition] = []
	for i in range(count):
		var tile = draw_tile()
		if tile:
			tiles.append(tile)
		else:
			break
	return tiles


## Get number of tiles remaining in bag
func get_remaining_count() -> int:
	return tile_bag.size()


## Check if bag is empty
func is_empty() -> bool:
	return tile_bag.is_empty()
