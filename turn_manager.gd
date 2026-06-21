extends Node

class_name TurnManager

# Player reference — updated by board_manager._switch_to_player() on every switch
var current_player: Player = null

var village_manager: VillageManager = null
var tile_manager: TileManager = null
var tile_pool: TilePool = null

# Signals
signal turn_started()
signal turn_ended()


## Initialize the turn manager with required references.
## current_player is set later via board_manager._switch_to_player().
func initialize(v_manager: VillageManager, t_manager: TileManager, t_pool: TilePool) -> void:
	village_manager = v_manager
	tile_manager = t_manager
	tile_pool = t_pool


## Validation helper: Check if an action can be performed
func can_perform_action(action_name: String = "action") -> bool:
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


## Harvests all resources from all current player's villages (all types at once).
func harvest_all() -> void:
	var villages = village_manager.get_villages_for_player(current_player)
	var totals: Dictionary = {
		TileDefinition.ResourceType.MATERIALS: 0,
		TileDefinition.ResourceType.FERVOR: 0,
		TileDefinition.ResourceType.GLORY: 0
	}

	for village in villages:
		var tile = tile_manager.get_tile_at(village.q, village.r)
		if tile:
			for res_type in tile.yields:
				totals[res_type] = totals.get(res_type, 0) + tile.yields[res_type]

	if totals[TileDefinition.ResourceType.MATERIALS] > 0:
		current_player.add_resources(totals[TileDefinition.ResourceType.MATERIALS])
	if totals[TileDefinition.ResourceType.FERVOR] > 0:
		current_player.add_fervor(totals[TileDefinition.ResourceType.FERVOR])
	if totals[TileDefinition.ResourceType.GLORY] > 0:
		current_player.add_glory(totals[TileDefinition.ResourceType.GLORY])

	Log.debug("Harvested: materials=%d fervor=%d glory=%d" % [
		totals[TileDefinition.ResourceType.MATERIALS],
		totals[TileDefinition.ResourceType.FERVOR],
		totals[TileDefinition.ResourceType.GLORY]
	])


## Triggers a second harvest (for Bicéphallès' power) — harvests all types again.
func trigger_second_harvest() -> void:
	harvest_all()
	Log.info("Second harvest triggered!")


## Ends the current turn: discards hand, draws new tiles, emits turn_ended.
## board_manager handles player switching and final round detection.
func end_turn() -> void:
	Log.info("=== END TURN ===")

	# Discard and draw for the finishing player
	current_player.refresh_hand(tile_pool)

	turn_ended.emit()   # board_manager._on_turn_ended() handles switch + final round check


## Called by board_manager after switching to a new player.
func begin_player_turn() -> void:
	current_player.start_turn()
	harvest_all()
	turn_started.emit()
