extends Node

class_name Player

# Player identity
var player_name: String = "Player 1"
var god_type: int = 0  # For later: Bicéphales, Augia, Rakun, Le Bâtisseur
var player_color: Color = Color.BLUE

# Resources (core game currencies)
var resources: int = 0    # For building villages & buying tiles
var fervor: int = 0       # For divine powers
var glory: int = 0        # Victory points

# Player's hand of tiles
var hand: Array = []  # Array of TilePool.TileDefinition

# Placed villages (for later scoring/tracking)
var placed_villages: Array = []

# Turn tracking
var actions_remaining: int = 3  # For later: 3 actions per turn

# Signals
signal resources_changed(new_amount: int)
signal fervor_changed(new_amount: int)
signal glory_changed(new_amount: int)


## Initialize player with starting resources
func initialize(name: String = "Player 1", starting_resources: int = 0, starting_fervor: int = 0) -> void:
	player_name = name
	resources = starting_resources
	fervor = starting_fervor
	glory = 0


## Check if player can afford a tile
func can_afford_tile(tile_def) -> bool:
	return resources >= tile_def.buy_price


## Spend resources (returns false if can't afford)
func spend_resources(amount: int) -> bool:
	if resources < amount:
		return false
	resources -= amount
	resources_changed.emit(resources)
	print("%s: Spent %d resources. Remaining: %d" % [player_name, amount, resources])
	return true


## Add resources (from harvest, turn start, selling, etc.)
func add_resources(amount: int) -> void:
	resources += amount
	resources_changed.emit(resources)
	print("%s: Gained %d resources. Total: %d" % [player_name, amount, resources])


## Spend fervor (for divine powers)
func spend_fervor(amount: int) -> bool:
	if fervor < amount:
		return false
	fervor -= amount
	fervor_changed.emit(fervor)
	print("%s: Spent %d fervor. Remaining: %d" % [player_name, amount, fervor])
	return true


## Add fervor (from harvest, turn start)
func add_fervor(amount: int) -> void:
	fervor += amount
	fervor_changed.emit(fervor)
	print("%s: Gained %d fervor. Total: %d" % [player_name, amount, fervor])


## Add glory (from harvest)
func add_glory(amount: int) -> void:
	glory += amount
	glory_changed.emit(glory)
	print("%s: Gained %d glory. Total: %d" % [player_name, amount, glory])


## Draw tiles into hand from tile pool
func draw_tiles(tile_pool, count: int) -> void:
	var drawn = tile_pool.draw_tiles(count)
	hand.append_array(drawn)
	print("%s: Drew %d tiles. Hand size: %d" % [player_name, drawn.size(), hand.size()])


## Remove tile from hand (after placement/selling)
func remove_from_hand(index: int) -> bool:
	if index < 0 or index >= hand.size():
		return false
	hand.remove_at(index)
	return true


## Start new turn (gain passive resources/fervor)
func start_turn() -> void:
	add_resources(1)
	add_fervor(1)
	actions_remaining = 3
	print("%s: Started turn. +1 resource, +1 fervor" % player_name)


## Get current hand
func get_hand() -> Array:
	return hand
