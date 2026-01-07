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

# Player's hand of tiles (fixed size array with null for empty slots)
const HAND_SIZE: int = 3
var hand: Array = [null, null, null]  # Array of TilePool.TileDefinition or null

# Placed villages (for later scoring/tracking)
var placed_villages: Array = []

# Turn tracking
var actions_remaining: int = 3  # For later: 3 actions per turn

# Signals
signal resources_changed(new_amount: int)
signal fervor_changed(new_amount: int)
signal glory_changed(new_amount: int)
signal actions_changed(new_amount: int)


## Initialize player with starting resources
func initialize(name: String = "Player 1", starting_resources: int = 0, starting_fervor: int = 0) -> void:
	player_name = name
	resources = starting_resources
	fervor = starting_fervor
	glory = 0


## Check if player can place a tile (only checks actions during actions phase)
func can_place_tile(in_actions_phase: bool) -> bool:
	if in_actions_phase and actions_remaining <= 0:
		return false
	return true


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
## Fills empty slots (null values) in the hand
func draw_tiles(tile_pool, count: int) -> void:
	var drawn = tile_pool.draw_tiles(count)
	var drawn_count = 0

	for tile_def in drawn:
		# Find first empty slot
		for i in range(HAND_SIZE):
			if hand[i] == null:
				hand[i] = tile_def
				drawn_count += 1
				break

	print("%s: Drew %d tiles into hand" % [player_name, drawn_count])


## Remove tile from hand (sets slot to null instead of removing)
func remove_from_hand(index: int) -> bool:
	if index < 0 or index >= HAND_SIZE:
		return false
	if hand[index] == null:
		return false
	hand[index] = null
	return true


## Start new turn (gain passive resources/fervor)
func start_turn() -> void:
	add_resources(1)
	add_fervor(1)
	set_actions(3)
	print("%s: Started turn. +1 resource, +1 fervor" % player_name)


## Set actions remaining and emit signal
func set_actions(amount: int) -> void:
	actions_remaining = amount
	actions_changed.emit(actions_remaining)


## Consume one action and emit signal
func consume_action() -> bool:
	if actions_remaining <= 0:
		return false
	actions_remaining -= 1
	actions_changed.emit(actions_remaining)
	return true


## Get current hand
func get_hand() -> Array:
	return hand
