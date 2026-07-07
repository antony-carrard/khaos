class_name ChangeTileTypePower
extends TargetedGodPower

## Augia minor power — change the resource type of an own tile.
## Two-step flow: click own village -> resource-type picker -> resolve.
## Requires a matching tile in the bag; blocked if unavailable. Validity of
## the chosen resource type depends on `extra`, which isn't known until the
## picker responds — so unlike other targeted powers, cost is only paid once
## resolve_effect (which needs `extra`) actually succeeds.

func _init():
	super("Transformation", "Changer le type de ses propres Tuiles", 2)


func is_valid_target(board_manager: Node3D, q: int, r: int) -> bool:
	var village = board_manager.village_manager.get_village_at(q, r)
	return village != null and village.player_owner == board_manager.current_player


## First click: show the resource-type picker instead of resolving immediately.
## Stays in targeting mode (returns false) until the picker responds.
func on_target_selected(board_manager: Node3D, q: int, r: int) -> bool:
	var tile = board_manager.tile_manager.get_tile_at(q, r)
	if not tile:
		Log.error("ChangeTileTypePower: village at (%d,%d) has no tile" % [q, r])
		return false

	var available_types: Array[int] = []
	for res_type in TileDefinition.ResourceType.values():
		if board_manager.tile_pool.has_tile_of_type_and_resource(tile.tile_type, res_type):
			available_types.append(res_type)

	if board_manager.ui:
		board_manager.ui.show_resource_type_picker(q, r, tile.primary_resource_type(), tile.tile_type, available_types)
	return false


## Overridden: pay cost only if resolve_effect (which validates the chosen
## resource type) actually succeeds — see class doc above.
func resolve(board_manager: Node3D, q: int, r: int, extra: int) -> bool:
	if not is_valid_target(board_manager, q, r):
		return false
	var success := resolve_effect(board_manager, q, r, extra)
	if success:
		pay_cost(board_manager.current_player)
		Log.info("Activated power: %s" % power_name)
	return success


func resolve_effect(board_manager: Node3D, q: int, r: int, new_resource_type: int) -> bool:
	var tile = board_manager.tile_manager.get_tile_at(q, r)

	if tile.yields.has(new_resource_type) and tile.yields.size() == 1:
		Log.warn("Tile is already %s type!" % TileDefinition.ResourceType.keys()[new_resource_type])
		board_manager.placement_controller.cancel_placement()
		return false

	if not _is_valid_resource_type_for_tile(tile.tile_type, new_resource_type):
		Log.warn("Cannot change to %s on a %s tile!" % [
			TileDefinition.ResourceType.keys()[new_resource_type],
			TileDefinition.TileType.keys()[tile.tile_type]
		])
		board_manager.placement_controller.cancel_placement()
		return false

	var bag_tile = board_manager.tile_pool.draw_tile_of_type_and_resource(tile.tile_type, new_resource_type)
	if not bag_tile:
		Log.warn("No %s tile with %s in bag — transformation blocked" % [
			TileDefinition.TileType.keys()[tile.tile_type],
			TileDefinition.ResourceType.keys()[new_resource_type]
		])
		board_manager.placement_controller.cancel_placement()
		return false

	var old_yields = tile.yields.duplicate()
	tile.set_resource_properties(bag_tile.yields, bag_tile.village_building_cost)
	Log.info("Changed tile at (%d, %d) from %s to %s" % [
		q, r,
		TileDefinition.format_yields(old_yields),
		TileDefinition.format_yields(bag_tile.yields)
	])
	return true


## Glory only exists on Hills and Mountains, not on Plains.
func _is_valid_resource_type_for_tile(tile_type: int, resource_type: int) -> bool:
	if tile_type == TileDefinition.TileType.PLAINS and resource_type == TileDefinition.ResourceType.GLORY:
		return false
	return true
