extends Node

class_name TurnManager

# Turn phase management
enum Phase {
	SETUP,
	HARVEST,
	ACTIONS
}

var current_phase: Phase = Phase.HARVEST

# Player reference — updated by board_manager._switch_to_player() on every switch
var current_player: Player = null

# References needed for harvest logic
var village_manager: VillageManager = null
var tile_manager: TileManager = null
var tile_pool: TilePool = null
var board_manager: Node3D = null
var ui: Control = null

# Signals
signal phase_changed(new_phase: Phase)
signal turn_started()
signal turn_ended()
signal setup_action_done()   # emitted after each setup tile or village placement


## Initialize the turn manager with required references.
## current_player is set later via board_manager._switch_to_player().
func initialize(v_manager: VillageManager, t_manager: TileManager,
				t_pool: TilePool, b_manager: Node3D) -> void:
	village_manager = v_manager
	tile_manager = t_manager
	tile_pool = t_pool
	board_manager = b_manager


## Set UI reference (called after UI is created)
func set_ui(ui_instance: Control) -> void:
	ui = ui_instance


## Validation helper: Check if an action can be performed
## Returns true if in actions phase and player has actions remaining
func can_perform_action(action_name: String = "action") -> bool:
	if current_phase != Phase.ACTIONS:
		Log.warn("Can only %s during actions phase!" % action_name)
		return false

	if current_player.actions_remaining <= 0:
		Log.warn("No actions remaining to %s!" % action_name)
		return false

	return true


## Consume one action with validation
## Returns true if action was consumed, false otherwise
func consume_action(action_name: String = "action") -> bool:
	if not can_perform_action(action_name):
		return false

	if not current_player.consume_action():
		Log.error("Failed to consume action for %s" % action_name)
		return false

	Log.debug("Action consumed for %s. Remaining: %d" % [action_name, current_player.actions_remaining])
	return true


## Phase query helpers
func is_setup_phase() -> bool:
	return current_phase == Phase.SETUP


func is_harvest_phase() -> bool:
	return current_phase == Phase.HARVEST


func is_actions_phase() -> bool:
	return current_phase == Phase.ACTIONS


## Starts the setup phase of the game.
## All players have already been dealt their setup tiles in board_manager._ready().
## The setup_phase_ui (created by board_manager) handles display.
func start_setup_phase() -> void:
	current_phase = Phase.SETUP
	phase_changed.emit(current_phase)
	Log.info("=== SETUP PHASE ===")


## Called when a setup tile is placed during setup phase.
## Records are kept in tile_placement_strategy; this just signals completion.
func on_setup_tile_placed(setup_index: int) -> void:
	if not is_setup_phase():
		Log.error("on_setup_tile_placed called outside of setup phase!")
		return

	# Remove the placed tile from setup tiles array
	if setup_index >= 0 and setup_index < current_player.setup_tiles.size():
		current_player.setup_tiles[setup_index] = null

	current_player.setup_tiles_placed += 1
	Log.info("%s: Setup tile placed" % current_player.player_name)

	setup_action_done.emit()


## Called when a setup village is placed during setup Round 3.
func on_setup_village_placed() -> void:
	if not is_setup_phase():
		Log.error("on_setup_village_placed called outside of setup phase!")
		return

	Log.info("%s: Setup village placed" % current_player.player_name)
	setup_action_done.emit()


## Starts harvest phase for the current player.
## Determines available harvest types and shows UI or auto-harvests if only one option.
func start_harvest_phase() -> void:
	current_phase = Phase.HARVEST
	phase_changed.emit(current_phase)

	# Update UI to show harvest phase display (hides setup UI, shows hand)
	if ui:
		ui.update_turn_phase(current_phase)

	var harvest_types = _get_available_harvest_types()

	Log.info("=== HARVEST PHASE ===")
	Log.debug("Available harvest types: %s" % [harvest_types])

	if harvest_types.is_empty():
		Log.info("No villages to harvest from! Skipping to actions phase.")
		current_phase = Phase.ACTIONS
		phase_changed.emit(current_phase)
		if ui:
			ui.update_turn_phase(current_phase)
		return

	if harvest_types.size() == 1:
		# Auto-harvest the only available type
		Log.info("Auto-harvesting %s (only option)" % TileManager.ResourceType.keys()[harvest_types[0]])
		harvest(harvest_types[0])
	else:
		# Show harvest UI for player choice
		if ui:
			ui.show_harvest_options(harvest_types)


## Gets the available harvest types based on the current player's villages.
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


## Harvests resources of the specified type from all current player villages.
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

	Log.info("Harvested %d %s from %d villages" % [
		total,
		TileManager.ResourceType.keys()[resource_type],
		village_count
	])

	# Transition to actions phase
	current_phase = Phase.ACTIONS
	phase_changed.emit(current_phase)
	Log.info("=== ACTIONS PHASE ===")
	Log.debug("Actions remaining: %d" % current_player.actions_remaining)

	if ui:
		ui.update_turn_phase(current_phase)


## Triggers a second harvest (for Bicéphallès' power)
## Shows harvest UI again without changing phase
func trigger_second_harvest() -> void:
	var harvest_types = _get_available_harvest_types()

	if harvest_types.is_empty():
		Log.info("No villages to harvest from!")
		return

	if harvest_types.size() == 1:
		# Auto-harvest the only available type
		Log.info("Auto-harvesting %s (only option)" % TileManager.ResourceType.keys()[harvest_types[0]])
		harvest(harvest_types[0])
	else:
		# Show harvest UI for player choice
		if ui:
			ui.show_harvest_options(harvest_types)
			Log.info("Second harvest: Choose resource type to harvest")


## Ends the current turn: discards hand, draws new tiles, emits turn_ended.
## board_manager handles player switching and final round detection.
func end_turn() -> void:
	Log.info("=== END TURN ===")

	# Discard and draw for the finishing player
	for i in range(current_player.HAND_SIZE):
		current_player.hand[i] = null
	current_player.draw_tiles(tile_pool, 3)

	turn_ended.emit()   # board_manager._on_turn_ended() handles switch + final round check


## Called by board_manager after switching to a new player.
## Gives the new player +1 resource/fervor, resets actions, starts harvest.
func begin_player_turn() -> void:
	current_player.start_turn()
	start_harvest_phase()
	turn_started.emit()
