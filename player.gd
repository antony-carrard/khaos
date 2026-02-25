extends Node

class_name Player

# Player identity
var player_name: String = "Player 1"
var god: God = null  # Selected god with powers
var player_color: Color = Color.BLUE

# Resources (core game currencies)
var resources: int = 0    # For building villages & buying tiles
var fervor: int = 0       # For divine powers
var glory: int = 0        # Victory points

# Player's hand of tiles (fixed size array with null for empty slots)
const HAND_SIZE: int = 3
const BASE_ACTIONS: int = 3          # Default actions per turn (before bonuses)
const SETUP_TILE_COUNT: int = 2       # Plains tiles dealt at game start (player chooses order of placement)
var hand: Array = [null, null, null]  # Array of TilePool.TileDefinition or null

# Setup phase tiles (1 PLAINS tile drawn per setup round)
var setup_tiles: Array = []  # Array of TilePool.TileDefinition
var setup_tiles_placed: int = 0  # Track how many setup tiles have been placed this round
var setup_tile_positions: Array[Vector2i] = []  # Board positions placed during setup rounds 1 & 2

# Placed villages (for later scoring/tracking)
var placed_villages: Array = []

# Turn tracking
var actions_remaining: int = 3  # For later: 3 actions per turn
var max_actions_this_turn: int = 3  # Track max actions for display (includes bonuses)
var next_turn_bonus_actions: int = 0  # For Bicéphallès' extra action power
var used_powers_this_turn: Array[int] = []  # Track used powers (PowerType enums)
var pending_power: GodPower = null  # Stores GodPower for deferred payment (selection-based powers)

# Signals
signal resources_changed(new_amount: int)
signal fervor_changed(new_amount: int)
signal glory_changed(new_amount: int)
signal actions_changed(new_amount: int)
signal power_used(power_type: int)  # Emitted when a power is used


## Initialize player with starting resources
func initialize(p_name: String = "Player 1", starting_resources: int = 0, starting_fervor: int = 0) -> void:
	player_name = p_name
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
	Log.debug("%s: Spent %d resources. Remaining: %d" % [player_name, amount, resources])
	return true


## Add resources (from harvest, turn start, selling, etc.)
func add_resources(amount: int) -> void:
	resources += amount
	resources_changed.emit(resources)
	Log.debug("%s: Gained %d resources. Total: %d" % [player_name, amount, resources])


## Spend fervor (for divine powers)
func spend_fervor(amount: int) -> bool:
	if fervor < amount:
		return false
	fervor -= amount
	fervor_changed.emit(fervor)
	Log.debug("%s: Spent %d fervor. Remaining: %d" % [player_name, amount, fervor])
	return true


## Add fervor (from harvest, turn start)
func add_fervor(amount: int) -> void:
	fervor += amount
	fervor_changed.emit(fervor)
	Log.debug("%s: Gained %d fervor. Total: %d" % [player_name, amount, fervor])


## Add glory (from harvest)
func add_glory(amount: int) -> void:
	glory += amount
	glory_changed.emit(glory)
	Log.debug("%s: Gained %d glory. Total: %d" % [player_name, amount, glory])


## Discard all tiles in hand and draw a full hand from the pool
func refresh_hand(tile_pool: TilePool) -> void:
	for i in range(HAND_SIZE):
		hand[i] = null
	draw_tiles(tile_pool, HAND_SIZE)


## Draw tiles into hand from tile pool
## Fills empty slots (null values) in the hand
func draw_tiles(tile_pool: TilePool, count: int) -> void:
	var drawn = tile_pool.draw_tiles(count)
	var drawn_count = 0

	for tile_def in drawn:
		# Find first empty slot
		for i in range(HAND_SIZE):
			if hand[i] == null:
				hand[i] = tile_def
				drawn_count += 1
				break

	Log.debug("%s: Drew %d tiles into hand" % [player_name, drawn_count])


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

	# Apply bonus actions (e.g., Bicéphallès' power)
	var total_actions: int = BASE_ACTIONS + next_turn_bonus_actions
	next_turn_bonus_actions = 0  # Reset bonus for next turn
	max_actions_this_turn = total_actions  # Track max for display
	set_actions(total_actions)

	# Reset used powers for new turn
	used_powers_this_turn.clear()

	Log.info("%s: Started turn. +1 resource, +1 fervor, %d actions" % [player_name, total_actions])


## Set actions remaining and emit signal
func set_actions(amount: int) -> void:
	actions_remaining = amount
	max_actions_this_turn = amount
	actions_changed.emit(actions_remaining)


## Consume one action and emit signal
func consume_action() -> bool:
	if actions_remaining <= 0:
		return false
	actions_remaining -= 1
	actions_changed.emit(actions_remaining)
	return true


## Get the actual village building cost for a tile, accounting for god abilities
func get_village_cost(base_cost: int) -> int:
	return GodManager.get_village_cost(god, base_cost)


## Check if a power has been used this turn
func has_used_power(power_type: int) -> bool:
	return used_powers_this_turn.has(power_type)


## Mark a power as used this turn
func mark_power_used(power_type: int) -> void:
	if not used_powers_this_turn.has(power_type):
		used_powers_this_turn.append(power_type)
		power_used.emit(power_type)
		Log.debug("%s: Marked power %d as used this turn" % [player_name, power_type])


## Get current hand
func get_hand() -> Array:
	return hand


## Initialize setup tiles: one PLAINS/Resources tile and one PLAINS/Fervor tile
## Called at the start of the setup phase
func initialize_setup_tiles(tile_pool: TilePool) -> void:
	setup_tiles.clear()
	setup_tiles_placed = 0
	# Note: setup_tile_positions is NOT cleared here — it accumulates across rounds 1 & 2

	var resources_tile = tile_pool.draw_plains_tile(TileManager.ResourceType.RESOURCES)
	if resources_tile:
		setup_tiles.append(resources_tile)
	else:
		Log.error("%s: Could not draw PLAINS/Resources tile for setup!" % player_name)

	var fervor_tile = tile_pool.draw_plains_tile(TileManager.ResourceType.FERVOR)
	if fervor_tile:
		setup_tiles.append(fervor_tile)
	else:
		Log.error("%s: Could not draw PLAINS/Fervor tile for setup!" % player_name)

	Log.info("%s: Setup tiles initialized (%d tiles)" % [player_name, setup_tiles.size()])
