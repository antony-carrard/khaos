extends Node

class_name PowerExecutor

## Handles all god power execution callbacks.
## Receives validated clicks from placement strategies and applies their effects.

var current_player: Player = null
var tile_manager: TileManager = null
var village_manager: VillageManager = null
var god_manager: GodManager = null
var placement_controller: PlacementController = null
var ui: Control = null
var board_manager: Node3D = null


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
		current_player.pending_power = null
		return false

	if village.player_owner == current_player:
		Log.warn("Cannot steal from your own village!")
		current_player.pending_power = null
		return false

	var tile = tile_manager.get_tile_at(q, r)
	if not tile:
		Log.error("PowerExecutor: Village at (%d,%d) has no tile" % [q, r])
		current_player.pending_power = null
		return false

	god_manager.complete_deferred_power(current_player)

	var harvest_value = tile.yield_value
	match tile.resource_type:
		TileManager.ResourceType.RESOURCES:
			current_player.add_resources(harvest_value)
			Log.info("Stole %d resources from enemy village" % harvest_value)
		TileManager.ResourceType.FERVOR:
			current_player.add_fervor(harvest_value)
			Log.info("Stole %d fervor from enemy village" % harvest_value)
		TileManager.ResourceType.GLORY:
			current_player.add_glory(harvest_value)
			Log.info("Stole %d glory from enemy village" % harvest_value)

	return true


## Handle free village destruction (Le Bâtisseur's power)
## Destroys enemy village without paying compensation
func on_destroy_village_free(q: int, r: int) -> bool:
	var village = village_manager.get_village_at(q, r)
	if not village:
		Log.warn("No village at position (%d, %d)" % [q, r])
		current_player.pending_power = null
		return false

	if village.player_owner == current_player:
		Log.warn("Cannot destroy your own village with this power!")
		current_player.pending_power = null
		return false

	god_manager.complete_deferred_power(current_player)

	var success = village_manager.remove_village(q, r)
	if success:
		Log.info("Destroyed enemy village at (%d, %d) with DESTROY_VILLAGE_FREE power" % [q, r])

	return success


## Handle tile upgrade (Augia's power)
## Upgrades the tile at the given position while preserving the village
func on_upgrade_tile(q: int, r: int) -> bool:
	var village = village_manager.get_village_at(q, r)
	if not village:
		Log.warn("No village at position (%d, %d)" % [q, r])
		current_player.pending_power = null
		return false

	if village.player_owner != current_player:
		Log.warn("Can only upgrade your own villages!")
		current_player.pending_power = null
		return false

	var tile = tile_manager.get_tile_at(q, r)
	if not tile:
		Log.error("PowerExecutor: Village at (%d,%d) has no tile" % [q, r])
		current_player.pending_power = null
		return false

	if tile.tile_type == TileManager.TileType.MOUNTAIN:
		Log.warn("Cannot upgrade MOUNTAIN - already at max level")
		current_player.pending_power = null
		return false

	god_manager.complete_deferred_power(current_player)

	var success = tile_manager.upgrade_tile(q, r)
	if success:
		var new_height = tile_manager.get_top_height(q, r)
		var world_pos = HexGridUtils.axial_to_world(q, r, new_height)
		village.global_position = world_pos + Vector3(0, HexGridUtils.TILE_HEIGHT / 2, 0)
		Log.info("Upgraded tile at (%d, %d) with UPGRADE_TILE_KEEP_VILLAGE power" % [q, r])

	return success


## Handle tile downgrade (Rakun's power)
## Downgrades the tile at the given position while preserving the village
func on_downgrade_tile(q: int, r: int) -> bool:
	var village = village_manager.get_village_at(q, r)
	if not village:
		Log.warn("No village at position (%d, %d)" % [q, r])
		current_player.pending_power = null
		return false

	if village.player_owner != current_player:
		Log.warn("Can only downgrade your own villages!")
		current_player.pending_power = null
		return false

	var tile = tile_manager.get_tile_at(q, r)
	if not tile:
		Log.error("PowerExecutor: Village at (%d,%d) has no tile" % [q, r])
		current_player.pending_power = null
		return false

	if tile.tile_type == TileManager.TileType.PLAINS:
		Log.warn("Cannot downgrade PLAINS - already at min level")
		current_player.pending_power = null
		return false

	god_manager.complete_deferred_power(current_player)

	var success = tile_manager.downgrade_tile(q, r)
	if success:
		var new_height = tile_manager.get_top_height(q, r)
		var world_pos = HexGridUtils.axial_to_world(q, r, new_height)
		village.global_position = world_pos + Vector3(0, HexGridUtils.TILE_HEIGHT / 2, 0)
		Log.info("Downgraded tile at (%d, %d) with DOWNGRADE_TILE_KEEP_VILLAGE power" % [q, r])

	return success


## Show resource type selection UI for CHANGE_TILE_TYPE power
## Displays UI with 3 buttons (RESOURCES, FERVOR, GLORY) to pick new type
func show_resource_type_selection(q: int, r: int) -> void:
	var village = village_manager.get_village_at(q, r)
	if not village or village.player_owner != current_player:
		Log.warn("Can only change tile type on your own villages!")
		return

	var tile = tile_manager.get_tile_at(q, r)
	if not tile:
		Log.error("PowerExecutor: Village at (%d,%d) has no tile" % [q, r])
		return

	if ui:
		ui.show_resource_type_picker(q, r, tile.resource_type, tile.tile_type)


## Handle tile resource type change (Augia's power)
## Changes the resource type of the tile at the given position
##
## DESIGN NOTE: This power does NOT check if tiles of the target type exist in the tile pool.
## This is an intentional digital convenience - the power always works after paying its cost
## (2 fervor + 1 action). In the physical game, you would swap tiles from the bag, but requiring
## tile pool checks here would create frustrating "paid but failed" scenarios. The power is
## already balanced by its once-per-turn limitation and fervor cost.
func on_change_tile_type(q: int, r: int, new_resource_type: int) -> bool:
	var village = village_manager.get_village_at(q, r)
	if not village or village.player_owner != current_player:
		Log.warn("Can only change tile type on your own villages!")
		current_player.pending_power = null
		placement_controller.cancel_placement()
		return false

	var tile = tile_manager.get_tile_at(q, r)
	if not tile:
		Log.error("PowerExecutor: Village at (%d,%d) has no tile" % [q, r])
		current_player.pending_power = null
		placement_controller.cancel_placement()
		return false

	if tile.resource_type == new_resource_type:
		Log.warn("Tile is already %s type!" % TileManager.ResourceType.keys()[new_resource_type])
		current_player.pending_power = null
		placement_controller.cancel_placement()
		return false

	if not _is_valid_resource_type_for_tile(tile.tile_type, new_resource_type):
		Log.warn("Cannot change to %s on a %s tile!" % [
			TileManager.ResourceType.keys()[new_resource_type],
			TileManager.TileType.keys()[tile.tile_type]
		])
		current_player.pending_power = null
		placement_controller.cancel_placement()
		return false

	god_manager.complete_deferred_power(current_player)

	var old_type = tile.resource_type
	var icon_path = TileManager.RESOURCE_TYPE_ICONS[new_resource_type]
	tile.set_resource_properties(
		new_resource_type,
		tile.yield_value,
		tile.village_building_cost,
		tile.sell_price,
		icon_path
	)

	Log.info("Changed tile at (%d, %d) from %s to %s" % [
		q, r,
		TileManager.ResourceType.keys()[old_type],
		TileManager.ResourceType.keys()[new_resource_type]
	])

	placement_controller.cancel_placement()

	return true


## Check if a resource type is valid for a tile type
## Glory only exists on Hills and Mountains, not on Plains
func _is_valid_resource_type_for_tile(tile_type: int, resource_type: int) -> bool:
	if tile_type == TileManager.TileType.PLAINS and resource_type == TileManager.ResourceType.GLORY:
		return false
	return true
