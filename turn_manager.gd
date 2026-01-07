extends Node

class_name TurnManager

# Turn phase management
enum Phase {
	SETUP,    # TODO: Initial tile/village placement (not implemented yet)
	HARVEST,
	ACTIONS
}

var current_phase: Phase = Phase.HARVEST

# Player reference
var current_player: Player = null

# References needed for harvest logic
var village_manager: VillageManager = null
var tile_manager: TileManager = null
var tile_pool: TilePool = null
var board_manager = null  # For VictoryManager (needs get_axial_neighbors)
var ui = null

# Game end state
var has_game_ended: bool = false
var final_round_triggered: bool = false
var triggering_player: Player = null

# Signals
signal phase_changed(new_phase: Phase)
signal turn_started()
signal turn_ended()
signal game_ended()


## Initialize the turn manager with required references
func initialize(player: Player, v_manager: VillageManager, t_manager: TileManager,
				t_pool: TilePool, b_manager) -> void:
	current_player = player
	village_manager = v_manager
	tile_manager = t_manager
	tile_pool = t_pool
	board_manager = b_manager


## Set UI reference (called after UI is created)
func set_ui(ui_instance) -> void:
	ui = ui_instance


## Validation helper: Check if an action can be performed
## Returns true if in actions phase and player has actions remaining
func can_perform_action(action_name: String = "action") -> bool:
	if current_phase != Phase.ACTIONS:
		print("Can only %s during actions phase!" % action_name)
		return false

	if current_player.actions_remaining <= 0:
		print("No actions remaining to %s!" % action_name)
		return false

	return true


## Consume one action with validation
## Returns true if action was consumed, false otherwise
func consume_action(action_name: String = "action") -> bool:
	if not can_perform_action(action_name):
		return false

	if not current_player.consume_action():
		print("ERROR: Failed to consume action for %s" % action_name)
		return false

	print("Action consumed for %s. Remaining: %d" % [action_name, current_player.actions_remaining])
	return true


## Phase query helpers
func is_setup_phase() -> bool:
	return current_phase == Phase.SETUP


func is_harvest_phase() -> bool:
	return current_phase == Phase.HARVEST


func is_actions_phase() -> bool:
	return current_phase == Phase.ACTIONS


## Starts the harvest phase of the turn.
## Determines available harvest types and shows UI or auto-harvests if only one option.
func start_harvest_phase() -> void:
	current_phase = Phase.HARVEST
	phase_changed.emit(current_phase)

	var harvest_types = _get_available_harvest_types()

	print("=== HARVEST PHASE ===")
	print("Available harvest types: %s" % [harvest_types])

	if harvest_types.is_empty():
		print("No villages to harvest from! Skipping to actions phase.")
		current_phase = Phase.ACTIONS
		phase_changed.emit(current_phase)
		if ui:
			ui.update_turn_phase(current_phase)
		return

	if harvest_types.size() == 1:
		# Auto-harvest the only available type
		print("Auto-harvesting %s (only option)" % TileManager.ResourceType.keys()[harvest_types[0]])
		harvest(harvest_types[0])
	else:
		# Show harvest UI for player choice
		if ui:
			ui.show_harvest_options(harvest_types)


## Gets the available harvest types based on player's villages.
## Returns array of ResourceType enums that have at least one village.
func _get_available_harvest_types() -> Array[int]:
	var types: Array[int] = []
	var villages = village_manager.get_villages_for_player(current_player)

	# Count villages on each resource type
	var type_counts = {
		TileManager.ResourceType.RESOURCES: 0,
		TileManager.ResourceType.FERVOR: 0,
		TileManager.ResourceType.GLORY: 0
	}

	for village in villages:
		var tile = tile_manager.get_tile_at(village.q, village.r)
		if tile:
			type_counts[tile.resource_type] += 1

	# Add types that have at least one village
	for type in type_counts:
		if type_counts[type] > 0:
			types.append(type)

	return types


## Harvests resources of the specified type from all player villages.
## Adds the total yield to the player's resources/fervor/glory.
## Transitions to actions phase after harvesting.
func harvest(resource_type: int) -> void:
	var villages = village_manager.get_villages_for_player(current_player)
	var total = 0
	var village_count = 0

	for village in villages:
		var tile = tile_manager.get_tile_at(village.q, village.r)
		if tile and tile.resource_type == resource_type:
			total += tile.yield_value
			village_count += 1

	# Add to player resources
	match resource_type:
		TileManager.ResourceType.RESOURCES:
			current_player.add_resources(total)
		TileManager.ResourceType.FERVOR:
			current_player.add_fervor(total)
		TileManager.ResourceType.GLORY:
			current_player.add_glory(total)

	print("Harvested %d %s from %d villages" % [
		total,
		TileManager.ResourceType.keys()[resource_type],
		village_count
	])

	# Transition to actions phase
	current_phase = Phase.ACTIONS
	phase_changed.emit(current_phase)
	print("=== ACTIONS PHASE ===")
	print("Actions remaining: %d" % current_player.actions_remaining)

	if ui:
		ui.update_turn_phase(current_phase)


## Ends the current turn and starts a new one.
## Discards hand, draws new tiles, resets actions, and starts harvest phase.
func end_turn() -> void:
	print("=== END TURN ===")

	turn_ended.emit()

	# Check for game end BEFORE discarding/drawing tiles
	if tile_pool.is_empty() and not final_round_triggered:
		final_round_triggered = true
		triggering_player = current_player
		print("=== FINAL ROUND TRIGGERED ===")
		print("Tile bag is empty. This is the last turn.")
		if ui:
			ui.show_final_round_notification()

	# Discard current hand (reset to empty slots)
	for i in range(current_player.HAND_SIZE):
		current_player.hand[i] = null

	# Draw 3 new tiles (fills empty slots, if any remain)
	current_player.draw_tiles(tile_pool, 3)

	# Start new turn (gives +1 resource, +1 fervor, resets actions to 3)
	current_player.start_turn()

	# Reset to harvest phase
	start_harvest_phase()

	# Update UI (hand display only - signals handle the rest)
	if ui:
		ui.update_hand_display()

	# Check if final round is complete (single player: end immediately after final turn)
	if final_round_triggered:
		_trigger_game_end()
		return  # Don't print "New turn started" if game is over

	print("New turn started!")
	turn_started.emit()


## Triggers game end and displays victory screen.
## Called when final round is complete.
func _trigger_game_end() -> void:
	has_game_ended = true
	print("=== GAME OVER ===")

	game_ended.emit()

	# Calculate final scores
	var victory_mgr = VictoryManager.new()
	var score_data = victory_mgr.calculate_player_score(
		current_player, village_manager, tile_manager, board_manager
	)

	# Show victory screen (array format for future multiplayer support)
	if ui:
		ui.show_victory_screen([{
			"player": current_player,
			"scores": score_data
		}])
