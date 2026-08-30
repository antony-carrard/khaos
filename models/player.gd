extends Node

class_name Player

# Player identity
var player_name: String
var god: God
var color: Color

# Base number of hand slots granted by the player's god; hand.size() is the
# CURRENT capacity, which may temporarily exceed this (e.g. a stolen tile
# pushed into a full hand). empty_hand() resets capacity back down to this.
var base_hand_size: int
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
	base_hand_size = god.hand_size

	if test_mode:
		total_actions = TEST_VALUE
		materials = TEST_VALUE
		fervor = TEST_VALUE
	else:
		total_actions = god.total_actions
		materials = 0
		fervor = 0

	glory = 0
	hand.resize(base_hand_size)
	for i in range(base_hand_size):
		hand[i] = null

func start_turn():
	actions_remaining = total_actions

func remove_from_hand(index: int):
	assert(index >= 0 and index < hand.size(), "Invalid hand index: %d" % index)
	assert(hand[index] != null, "Slot %d is already empty" % index)
	hand[index] = null
	if hand.size() > base_hand_size:
		hand.remove_at(index)

func add_to_hand(tile: TileDefinition):
	for i in range(hand.size()):
		if hand[i] == null:
			hand[i] = tile
			return
	assert(false, "the hand is already full")

## Writes directly into a hand slot, replacing whatever is there. Used for
## powers that swap a hand tile for another tile (e.g. Augia's Transformation).
func replace_hand_tile(index: int, tile: TileDefinition):
	assert(index >= 0 and index < hand.size(), "Invalid hand index: %d" % index)
	assert(hand[index] != null, "Slot %d is empty, cannot replace" % index)
	hand[index] = tile

## Adds one extra hand slot beyond base_hand_size. Called explicitly by powers
## that force a tile into an already-full hand (e.g. Rakun stealing a tile).
## Temporary: the next empty_hand() call discards it back to base_hand_size.
func grow_hand(amount: int = 1):
	assert(amount > 0, "grow_hand amount must be positive")
	var new_size := hand.size() + amount
	hand.resize(new_size)
	for i in range(new_size - amount, new_size):
		hand[i] = null

## Clears the hand and resets its capacity back to base_hand_size, discarding
## any temporary slots granted by grow_hand().
func empty_hand():
	hand.resize(base_hand_size)
	for i in range(base_hand_size):
		hand[i] = null

## Grants resources described by a tile's yields dict (materials/fervor/glory
## by TileDefinition.ResourceType). Shared by placement bounties, harvest-style
## powers (steal, bonus harvest), so the type match isn't duplicated per call site.
func receive_yields(tile_yields: Dictionary) -> void:
	for res_type in tile_yields:
		var amount: int = tile_yields[res_type]
		match res_type:
			TileDefinition.ResourceType.MATERIALS:
				materials += amount
			TileDefinition.ResourceType.FERVOR:
				fervor += amount
			TileDefinition.ResourceType.GLORY:
				glory += amount

func has_tile_in_hand() -> bool:
	for tile in hand:
		if tile != null:
			return true
	return false

func has_free_hand_slot() -> bool:
	for tile in hand:
		if tile == null:
			return true
	return false


# ==================== SERIALIZATION ====================

## Flat snapshot of this player. The god is recorded by its stable id rather than
## by reference; empty hand slots are stored as null so capacity survives intact.
func to_dict() -> Dictionary:
	var hand_data: Array = []
	for tile in hand:
		hand_data.append(tile.to_dict() if tile != null else null)
	return {
		"player_name": player_name,
		"color": color,
		"god_id": god.get_id() if god != null else "",
		"base_hand_size": base_hand_size,
		"total_actions": total_actions,
		"materials": materials,
		"fervor": fervor,
		"glory": glory,
		"actions_remaining": actions_remaining,
		"hand": hand_data,
	}


## Rebuilds this player from to_dict() output. Deliberately does not go through
## initialize_game_start(): that derives the hand from the god and wipes it, while
## a restore has to reinstate the hand exactly as it was. Resources are assigned
## through their setters so the UI's stat signals fire as usual.
func from_dict(data: Dictionary) -> void:
	player_name = data["player_name"]
	color = data["color"]
	god = God.from_id(data["god_id"])
	if god == null:
		Log.error("Player: unknown god id '%s' restoring %s" % [data["god_id"], player_name])
	base_hand_size = data["base_hand_size"]
	total_actions = data["total_actions"]

	# Capacity comes from the snapshot, not base_hand_size: grow_hand() lets the
	# hand temporarily hold more than the god grants (e.g. Rakun's stolen tile).
	var hand_data: Array = data["hand"]
	hand.resize(hand_data.size())
	for i in range(hand_data.size()):
		hand[i] = TileDefinition.from_dict(hand_data[i]) if hand_data[i] != null else null

	materials = data["materials"]
	fervor = data["fervor"]
	glory = data["glory"]
	actions_remaining = data["actions_remaining"]
