extends Node

class_name Player

# Player identity
var player_name: String
var god: God
var color: Color

# Number of tiles and actions a player has when initialized
var hand_size: int
var total_actions: int
const TEST_VALUE: int = 999

# Tiles and actions tracking
var hand: Array[TileDefinition]

# resources (core game currencies)
var materials: int:
	set(value):
		assert(value >= 0, "Can't set a negative value for the materials")
		materials = value
		Log.debug("%s: set materials value to: %d." % [player_name, value])
		materials_changed.emit(value)

var fervor: int:
	set(value):
		assert(value >= 0, "Can't set a negative value for the fervor")
		fervor = value
		Log.debug("%s: set fervor value to: %d." % [player_name, value])
		fervor_changed.emit(value)

var glory: int:
	set(value):
		assert(value >= 0, "Can't set a negative value for the glory")
		glory = value
		Log.debug("%s: set glory value to: %d." % [player_name, value])
		glory_changed.emit(value)

var actions_remaining: int:
	set(value):
		assert(value >= 0, "Can't set a negative value for the actions_remaining")
		actions_remaining = value
		Log.debug("%s: set number of actions to: %d." % [player_name, value])
		actions_changed.emit(value)

# Signals
signal materials_changed(new_value: int)
signal fervor_changed(new_value: int)
signal glory_changed(new_value: int)
signal actions_changed(new_value: int)
# TODO add some signals for the tiles?

## Initialize player with starting materials
func initialize(player_name: String, color: Color):
	self.player_name = player_name
	self.color = color

func initialize_game_start(god: God, test_mode: bool):
	self.god = god
	hand_size = god.hand_size
	
	if test_mode:
		total_actions = TEST_VALUE
		materials = TEST_VALUE
		fervor = TEST_VALUE
	else:
		total_actions = god.total_actions
		materials = 0
		fervor = 0
		
	glory = 0
	hand.resize(hand_size)
	for i in range(hand_size):
		hand[i] = null

func start_turn():
	actions_remaining = total_actions

func remove_from_hand(index: int):
	assert(index >= 0 and index < hand_size, "Invalid hand index: %d" % index)
	assert(hand[index] != null, "Slot %d is already empty" % index)
	hand[index] = null

func add_to_hand(tile: TileDefinition):
	for i in range(hand_size):
		if hand[i] == null:
			hand[i] = tile
			return
	assert(false, "the hand is already full")

## Writes directly into a hand slot, replacing whatever is there. Used for
## powers that swap a hand tile for another tile (e.g. Augia's Transformation).
func replace_hand_tile(index: int, tile: TileDefinition):
	assert(index >= 0 and index < hand_size, "Invalid hand index: %d" % index)
	assert(hand[index] != null, "Slot %d is empty, cannot replace" % index)
	hand[index] = tile

func empty_hand():
	for i in range(hand_size):
		hand[i] = null

func has_tile_in_hand() -> bool:
	for tile in hand:
		if tile != null:
			return true
	return false
