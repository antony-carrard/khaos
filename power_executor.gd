extends Node

class_name PowerExecutor

## Handles all god power execution callbacks.
## Receives validated clicks from placement strategies and applies their effects.

## Emitted after a targeted power successfully executes.
## board_manager connects this to broadcast the action to remote peers.
signal power_executed(power_type: int, q: int, r: int, extra: int)

var current_player: Player = null
var tile_manager: TileManager = null
var village_manager: VillageManager = null
var god_manager: GodManager = null
var placement_controller: PlacementController = null
var ui: Control = null
var board_manager: Node3D = null

# Deferred (selection-based) power waiting for a target click. Set by
# GodManager.activate_power()/board_manager._rpc_power_target(), cleared here
# once resolved or cancelled.
var pending_power: GodPower = null


func initialize(
	_player: Player,
	_tile_manager: TileManager,
	_village_manager: VillageManager,
	_god_manager: GodManager,
	_placement_controller: PlacementController,
	_ui: Control,
	_board_manager: Node3D
) -> void:
	current_player = _player
	tile_manager = _tile_manager
	village_manager = _village_manager
	god_manager = _god_manager
	placement_controller = _placement_controller
	ui = _ui
	board_manager = _board_manager


## Handle steal harvest from enemy village (Rakun's power)
## Adds the tile's yield to the player's resources/fervor/glory
func on_steal_harvest(q: int, r: int) -> bool:
	var village = village_manager.get_village_at(q, r)
	if not village:
		Log.warn("No village at position (%d, %d)" % [q, r])
		pending_power = null
		return false

	if village.player_owner == current_player:
		Log.warn("Cannot steal from your own village!")
		pending_power = null
		return false

	var tile = tile_manager.get_tile_at(q, r)
	if not tile:
		Log.error("PowerExecutor: Village at (%d,%d) has no tile" % [q, r])
		pending_power = null
		return false

	god_manager.complete_deferred_power(current_player, self)

	for res_type in tile.yields:
		var amount = tile.yields[res_type]
		match res_type:
			TileDefinition.ResourceType.MATERIALS:
				current_player.materials += amount
				Log.info("Stole %d materials from enemy village" % amount)
			TileDefinition.ResourceType.FERVOR:
				current_player.fervor += amount
				Log.info("Stole %d fervor from enemy village" % amount)
			TileDefinition.ResourceType.GLORY:
				current_player.glory += amount
				Log.info("Stole %d glory from enemy village" % amount)

	power_executed.emit(GodPower.PowerType.STEAL_HARVEST, q, r, -1)
	return true


## Handle free village destruction (Le Bâtisseur's power)
## Destroys enemy village without paying compensation
func on_destroy_village_free(q: int, r: int) -> bool:
	var village = village_manager.get_village_at(q, r)
	if not village:
		Log.warn("No village at position (%d, %d)" % [q, r])
		pending_power = null
		return false

	if village.player_owner == current_player:
		Log.warn("Cannot destroy your own village with this power!")
		pending_power = null
		return false

	god_manager.complete_deferred_power(current_player, self)

	var success = village_manager.remove_village(q, r)
	if success:
		Log.info("Destroyed enemy village at (%d, %d) with DESTROY_VILLAGE_FREE power" % [q, r])
		power_executed.emit(GodPower.PowerType.DESTROY_VILLAGE_FREE, q, r, -1)

	return success


## Handle tile upgrade (Augia's power)
## Upgrades the tile at the given position while preserving the village
func on_upgrade_tile(q: int, r: int) -> bool:
	var village = village_manager.get_village_at(q, r)
	if not village:
		Log.warn("No village at position (%d, %d)" % [q, r])
		pending_power = null
		return false

	if village.player_owner != current_player:
		Log.warn("Can only upgrade your own villages!")
		pending_power = null
		return false

	var tile = tile_manager.get_tile_at(q, r)
	if not tile:
		Log.error("PowerExecutor: Village at (%d,%d) has no tile" % [q, r])
		pending_power = null
		return false

	if tile.tile_type == TileDefinition.TileType.MOUNTAIN:
		Log.warn("Cannot upgrade MOUNTAIN - already at max level")
		pending_power = null
		return false

	god_manager.complete_deferred_power(current_player, self)

	var success = tile_manager.upgrade_tile(q, r)
	if success:
		var new_height = tile_manager.get_top_height(q, r)
		var world_pos = HexGridUtils.axial_to_world(q, r, new_height)
		village.global_position = world_pos + Vector3(0, HexGridUtils.TILE_HEIGHT / 2, 0)
		Log.info("Upgraded tile at (%d, %d) with UPGRADE_TILE_KEEP_VILLAGE power" % [q, r])
		power_executed.emit(GodPower.PowerType.UPGRADE_TILE_KEEP_VILLAGE, q, r, -1)

	return success


## Handle tile downgrade (Rakun's power)
## Downgrades the tile at the given position while preserving the village
func on_downgrade_tile(q: int, r: int) -> bool:
	var village = village_manager.get_village_at(q, r)
	if not village:
		Log.warn("No village at position (%d, %d)" % [q, r])
		pending_power = null
		return false

	if village.player_owner == current_player:
		Log.warn("Cannot downgrade your own villages!")
		pending_power = null
		return false

	var tile = tile_manager.get_tile_at(q, r)
	if not tile:
		Log.error("PowerExecutor: Village at (%d,%d) has no tile" % [q, r])
		pending_power = null
		return false

	if tile.tile_type == TileDefinition.TileType.PLAINS:
		Log.warn("Cannot downgrade PLAINS - already at min level")
		pending_power = null
		return false

	god_manager.complete_deferred_power(current_player, self)

	var success = tile_manager.downgrade_tile(q, r)
	if success:
		var new_height = tile_manager.get_top_height(q, r)
		var world_pos = HexGridUtils.axial_to_world(q, r, new_height)
		village.global_position = world_pos + Vector3(0, HexGridUtils.TILE_HEIGHT / 2, 0)
		Log.info("Downgraded tile at (%d, %d) with DOWNGRADE_TILE_KEEP_VILLAGE power" % [q, r])
		power_executed.emit(GodPower.PowerType.DOWNGRADE_TILE_KEEP_VILLAGE, q, r, -1)

	return success


## Show resource type selection UI for CHANGE_TILE_TYPE power
## Displays UI with 3 buttons (MATERIALS, FERVOR, GLORY) to pick new type.
## Buttons for types not present in the bag are shown greyed out.
func show_resource_type_selection(q: int, r: int) -> void:
	var village = village_manager.get_village_at(q, r)
	if not village or village.player_owner != current_player:
		Log.warn("Can only change tile type on your own villages!")
		return

	var tile = tile_manager.get_tile_at(q, r)
	if not tile:
		Log.error("PowerExecutor: Village at (%d,%d) has no tile" % [q, r])
		return

	var tile_pool = board_manager.tile_pool
	var available_types: Array[int] = []
	for res_type in TileDefinition.ResourceType.values():
		if tile_pool.has_tile_of_type_and_resource(tile.tile_type, res_type):
			available_types.append(res_type)

	if ui:
		ui.show_resource_type_picker(q, r, tile.primary_resource_type(), tile.tile_type, available_types)


## Handle tile resource type change (Augia's power)
## Changes the resource type of the tile at the given position.
## Requires a matching tile in the bag — blocked if unavailable.
## NOTE: To also return the current board tile to the bag (full board-game fidelity),
## create a TileDefinition from tile's properties and call board_manager.tile_pool.return_tile()
## before the draw below.
func on_change_tile_type(q: int, r: int, new_resource_type: int) -> bool:
	var village = village_manager.get_village_at(q, r)
	if not village or village.player_owner != current_player:
		Log.warn("Can only change tile type on your own villages!")
		pending_power = null
		placement_controller.cancel_placement()
		return false

	var tile = tile_manager.get_tile_at(q, r)
	if not tile:
		Log.error("PowerExecutor: Village at (%d,%d) has no tile" % [q, r])
		pending_power = null
		placement_controller.cancel_placement()
		return false

	if tile.yields.has(new_resource_type) and tile.yields.size() == 1:
		Log.warn("Tile is already %s type!" % TileDefinition.ResourceType.keys()[new_resource_type])
		pending_power = null
		placement_controller.cancel_placement()
		return false

	if not _is_valid_resource_type_for_tile(tile.tile_type, new_resource_type):
		Log.warn("Cannot change to %s on a %s tile!" % [
			TileDefinition.ResourceType.keys()[new_resource_type],
			TileDefinition.TileType.keys()[tile.tile_type]
		])
		pending_power = null
		placement_controller.cancel_placement()
		return false

	var bag_tile = board_manager.tile_pool.draw_tile_of_type_and_resource(tile.tile_type, new_resource_type)
	if not bag_tile:
		Log.warn("No %s tile with %s in bag — transformation blocked" % [
			TileDefinition.TileType.keys()[tile.tile_type],
			TileDefinition.ResourceType.keys()[new_resource_type]
		])
		pending_power = null
		placement_controller.cancel_placement()
		return false

	god_manager.complete_deferred_power(current_player, self)

	var old_yields = tile.yields.duplicate()
	tile.set_resource_properties(bag_tile.yields, bag_tile.village_building_cost)

	Log.info("Changed tile at (%d, %d) from %s to %s" % [
		q, r,
		TileDefinition.format_yields(old_yields),
		TileDefinition.format_yields(bag_tile.yields)
	])

	placement_controller.cancel_placement()

	power_executed.emit(GodPower.PowerType.CHANGE_TILE_TYPE, q, r, new_resource_type)
	return true


## Check if a resource type is valid for a tile type
## Glory only exists on Hills and Mountains, not on Plains
func _is_valid_resource_type_for_tile(tile_type: int, resource_type: int) -> bool:
	if tile_type == TileDefinition.TileType.PLAINS and resource_type == TileDefinition.ResourceType.GLORY:
		return false
	return true
